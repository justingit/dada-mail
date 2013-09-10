#!/usr/bin/perl
use strict; 


# use Data::Dumper; 



use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

#use Test::More qw(no_plan); 

use DADA::Config qw(!:DEFAULT); 
$DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions} = 1; 


my $list = dada_test_config::create_test_list;
my $list2 = dada_test_config::create_test_list({-name => 'test2'});

my $email = 'user@example.com'; 


use DADA::App::Subscriptions::ConfirmationTokens; 
use DADA::App::Subscriptions; 
use DADA::MailingList::Settings; 
use DADA::MailingList::Subscribers; 
my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 

my $ct = DADA::App::Subscriptions::ConfirmationTokens->new; 
ok($ct->isa('DADA::App::Subscriptions::ConfirmationTokens'));

ok($ct->exists('doesntexist') == 0); 

ok($ct->exists('doesntexist') == 0); 

my $token = $ct->save(
	{ 
		-email => $email,
		-data  => {
			list        => $list,
			type        => 'list', 
			flavor      => 'sub_confirm', 
			remote_addr => $ENV{REMOTE_ADDR}, 
		}
	}
);
ok(length($token) == 40); 
ok($ct->exists($token) == 1);
ok($ct->num_tokens == 1); 

my $data = $ct->fetch($token); 
ok($data->{email}          eq $email); 
ok($data->{data}->{list}   eq $list); 
ok($data->{data}->{flavor} eq 'sub_confirm'); 
ok($ct->remove_by_token($token) == 1); 
ok($ct->exists($token) == 0);
undef $token; 


# This makes sure removing one token, doesn't remove both tokens (by list) 
#
my $token = $ct->save(
	{ 
		-email => $email,
		-data  => {
			list        => $list,
			type        => 'list', 
			flavor      => 'sub_confirm', 
			remote_addr => $ENV{REMOTE_ADDR}, 
		}
	}
);
ok(length($token) == 40); 
ok($ct->exists($token) == 1);
ok($ct->num_tokens == 1); 
# This makes sure removing one token, doesn't remove both tokens (by list) 
#
my $token2 = $ct->save(
	{ 
		-email => $email,
		-data  => {
			list        => $list2,
			type        => 'list', 
			flavor      => 'sub_confirm', 
		}
	}
);
ok(length($token2) == 40); 
ok($ct->exists($token2) == 1);
ok($ct->num_tokens == 2); 

my $n = $ct->remove_by_metadata(
	{ 
		-email    => $email,
		-metadata => {
			list        => $list,
			type        => 'list', 
			flavor      => 'sub_confirm', 
			remote_addr => $ENV{REMOTE_ADDR},			
		} 
	}
);

ok($n == 1); 
ok($ct->num_tokens == 1); 
ok($ct->exists($token)  == 0);
ok($ct->exists($token2) == 1);
$ct->remove_all_tokens; 
ok($ct->num_tokens == 0); 


my $q = CGI->new; 
my $r;

my $das = DADA::App::Subscriptions->new; 




# invalid_list
$r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{invalid_list} == 1);
# diag Dumper($r); 
undef $r;




# invalid_email
$q->param('list', $list); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{invalid_email} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all; 




# Status is OK!
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all; 



# already_sent_sub_confirmation
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{already_sent_sub_confirmation} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all;
$lh->remove_subscriber(
    {
        -email => $email,
        -type  => 'sub_confirm_list',
    }
);
$ct->remove_all_tokens; 




# Black Listed, but OK for subscriber to re-subscribe: 
$ls->save({black_list => 1}); 
$ls->save({allow_blacklisted_to_subscribe => 1}); 
$lh->add_subscriber( { -email => $email, -type  => 'black_list', } );
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all;
$ct->remove_all_tokens; 
$lh->remove_subscriber(
    {
        -email => $email,
        -type  => 'sub_confirm_list',
    }
);
$lh->remove_subscriber(
    {
        -email => $email,
        -type  => 'black_list',
    }
);




# black_listed
$ls->save({black_list => 1}); 
$ls->save({allow_blacklisted_to_subscribe => 0}); 
$lh->add_subscriber( { -email => $email, -type  => 'black_list', } );

$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{black_listed} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all;
$ct->remove_all_tokens; 
$lh->remove_subscriber(
    {
        -email => $email,
        -type  => 'black_list',
    }
);




# closed_list 
$ls->save({closed_list => 1}); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{closed_list} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all; 
$ls->save({closed_list => 0}); 




# invite_only_list 
$ls->save({invite_only_list => 1}); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{invite_only_list} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all; 
$ls->save({invite_only_list => 0}); 




# Over Subscription Quota 
$ls->save({use_subscription_quota => 1}); 
$ls->save({subscription_quota     => 0}); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{over_subscription_quota} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all; 
$ls->save({use_subscription_quota => 0});




# Over Subscription Quota (GLOBAL) 
# I kinda have to fudge this, since the global Subscription Quota has to be greater than 0...
$lh->add_subscriber( { -email => 'someone.else@example.com', -type  => 'list', } );
$DADA::Config::SUBSCRIPTION_QUOTA = 1; 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{over_subscription_quota} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all;
$DADA::Config::SUBSCRIPTION_QUOTA = undef; 



# Subscribed - w/o email_your_subscribed_msg enabled
# This is tricky, since by default, DM lies about subscriptions list this: 
$ls->save({ email_your_subscribed_msg => 1 }); 
$lh->add_subscriber( { -email => $email, -type  => 'list', } );
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
# Again, we're lying. 
ok($r->{status} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all;
$lh->remove_subscriber( { -email => $email, -type  => 'list', } );
$lh->remove_subscriber( { -email => $email, -type  => 'sub_confirm_list', } );




# Subscribed - with email_your_subscribed_msg DISABLED
# Again, we LIE
$lh->add_subscriber( { -email => $email, -type  => 'list', } );
$ls->save({ email_your_subscribed_msg => 0 }); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-json_output => 0, 
		-test        => 1, 
	}
);
# Again, we're lying. 
ok($r->{status} == 0);
ok($r->{errors}->{subscribed} == 1);
# diag Dumper($r); 
undef $r; 
$q->delete_all;
$lh->remove_subscriber( { -email => $email, -type  => 'list', } );









dada_test_config::remove_test_list;
dada_test_config::remove_test_list({-name => 'test2'});
dada_test_config::wipe_out;


