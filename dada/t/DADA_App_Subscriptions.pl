#!/usr/bin/perl
use strict; 

use Data::Dumper; 
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

$ls->save(
    {
        use_alt_url_sub_confirm_failed  => 1,
        alt_url_sub_confirm_failed_w_qs => 1,
        alt_url_sub_confirm_failed =>
          'http://example.com/alt_url_sub_confirm_failed.html',
        use_alt_url_sub_confirm_success  => 1,
        alt_url_sub_confirm_success_w_qs => 1,
        alt_url_sub_confirm_success =>
          'http://example.com/alt_url_sub_confirm_success.html',
        use_alt_url_sub_failed  => 1,
        alt_url_sub_failed_w_qs => 1,
        alt_url_sub_failed      => 'http://example.com/alt_url_sub_failed.html',
        use_alt_url_sub_success => 1,
        alt_url_sub_success_w_qs => 1,
        alt_url_sub_success => 'http://example.com/alt_url_sub_success.html',
    }
);




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
   $das->test(1); 



# invalid_list
$r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{invalid_list} == 1);
ok($r->{redirect}->{url}   eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi?error_invalid_list=1');
ok($r->{redirect}->{query} eq 'list=&email=errors[]=invalid_list');
ok($r->{redirect_required} eq 'invalid_list');
ok(! defined($r->{list})); 

# diag Dumper($r); 
undef $r;
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi?error_invalid_list=1\r\n\r\n";
ok($r eq $redirect); 
undef $r;



# invalid_email
$q->param('list', $list); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{status} == 0);
ok($r->{errors}->{invalid_email} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=&status=0&rm=sub_confirm&errors[]=invalid_email');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
#diag Dumper($r); 
undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=&status=0&rm=sub_confirm&errors[]=invalid_email\r\n\r\n";
ok($r eq $redirect); 
$q->delete_all; 
undef $r;




# Status is OK!
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{status} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_success.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=1&rm=sub_confirm');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
# diag Dumper($r); 
undef $r; 
$lh->remove_subscriber(
    {
        -email => $email,
        -type  => 'sub_confirm_list',
    }
);
$ct->remove_all_tokens; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_success.html?list=dadatest&email=user%40example.com&status=1&rm=sub_confirm\r\n\r\n";
ok($r eq $redirect); 
undef $r; 
$q->delete_all; 
# Don't remove the email from sub_confirm_list, as we'll use it for the next test: 



# already_sent_sub_confirmation
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
diag(Dumper($r)); 
ok($r->{email} eq 'user@example.com');
ok($r->{errors}->{already_sent_sub_confirmation} == 1);
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=already_sent_sub_confirmation');
ok($r->{redirect}->{url}   eq 'http://localhost?f=show_error&email=user%40example.com&list=dadatest&error=already_sent_sub_confirmation');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok($r->{status} == 0);
ok($r->{redirect_required} eq 'subscription_requires_captcha');
ok($r->{error_descriptions}->{already_sent_sub_confirmation} eq 'use redirect');
ok($r->{list} eq $list);


undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=already_sent_sub_confirmation\r\n\r\n";
ok($r eq $redirect); 
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
    	-return_json => 0, 
	}
);
# diag Dumper($r); 
ok($r->{email} eq $email);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_success.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=1&rm=sub_confirm');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok($r->{status} == 1);
ok(exists($r->{success_message}));
ok($r->{list} eq $list);
undef $r; 
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
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_success.html?list=dadatest&email=user%40example.com&status=1&rm=sub_confirm\r\n\r\n";
ok($r eq $redirect); 
undef $r;
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
$q->delete_all;



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
    	-return_json => 0, 
	}
);

ok($r->{email} eq $email);
ok($r->{errors}->{black_listed} == 1);
ok($r->{status} == 0);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=black_listed');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{error_descriptions}->{black_listed})); 
ok($r->{list} eq $list);
#diag Dumper($r); 
undef $r; 
$ct->remove_all_tokens;

my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=black_listed\r\n\r\n";
ok($r eq $redirect); 
undef $r;
$lh->remove_subscriber(
    {
        -email => $email,
        -type  => 'black_list',
    }
);
$q->delete_all;






# closed_list 
$ls->save({closed_list => 1}); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 0);
ok($r->{errors}->{closed_list} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=closed_list');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{error_descriptions}->{closed_list})); 
undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=closed_list\r\n\r\n";
ok($r eq $redirect); 
$q->delete_all;
$ls->save({closed_list => 0});  
undef $r; 


# invite_only_list 
$ls->save({invite_only_list => 1}); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);

ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 0);
ok($r->{errors}->{invite_only_list} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=invite_only_list');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{error_descriptions}->{invite_only_list})); 

#diag Dumper($r); 
undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=invite_only_list\r\n\r\n";
ok($r eq $redirect); 
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
    	-return_json => 0, 
	}
);
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 0);
ok($r->{errors}->{over_subscription_quota} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=over_subscription_quota');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{error_descriptions}->{over_subscription_quota})); 
#diag Dumper($r); 
undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=over_subscription_quota\r\n\r\n";
ok($r eq $redirect); 
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
    	-return_json => 0, 
	}
);
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 0);
ok($r->{errors}->{over_subscription_quota} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=over_subscription_quota');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{error_descriptions}->{over_subscription_quota})); 
#diag Dumper($r);
undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=over_subscription_quota\r\n\r\n";
ok($r eq $redirect);  
undef $r; 
$q->delete_all;
$DADA::Config::SUBSCRIPTION_QUOTA = undef; 




# Closed Loop Opt-in DISABLED
$ls->save(
    {
        enable_closed_loop_opt_in         => 0,
    }
);

$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
#diag(Dumper($r)); 

ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 1);

ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_success.html');
ok($r->{redirect}->{query} eq 'list=dadatest&rm=sub&status=1&email=user%40example.com');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{success_message})); 

$lh->remove_subscriber( { -email => $email, -type  => 'list', } );
undef $r; 
$q->delete_all;
$ls->save(
    {
        enable_closed_loop_opt_in         => 1,
    }
);




# Closed Loop Opt-in DISABLED
# Subscription Requests ENABLED
$ls->save(
    {
        enable_closed_loop_opt_in         => 0,
        enable_subscription_approval_step => 1, 
    }
);

$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 1);
ok($r->{redirect}->{url}   eq '');
ok($r->{redirect}->{query} eq 'list=dadatest&rm=sub&subscription_requires_approval=1&status=1&email=user%40example.com');
ok($r->{redirect}->{using} == 0); 
ok($r->{redirect}->{using_with_query} == 0);
ok(exists($r->{success_message})); 
#diag Dumper($r);

$lh->remove_subscriber( { -email => $email, -type  => 'sub_confirm_list', } );
undef $r; 
$q->delete_all;
$ls->save(
    {
        enable_closed_loop_opt_in         => 1,
        enable_subscription_approval_step => 0, 
    }
);














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
    	-return_json => 0, 
	}
);
# Again, we're lying
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_success.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=1&rm=sub_confirm');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{success_message})); 

#diag Dumper($r);
$lh->remove_subscriber( { -email => $email, -type  => 'list', } );
$lh->remove_subscriber( { -email => $email, -type  => 'sub_confirm_list', } );
undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_success.html?list=dadatest&email=user%40example.com&status=1&rm=sub_confirm\r\n\r\n";
ok($r eq $redirect); 
undef $r; 
$q->delete_all;
$lh->remove_subscriber( { -email => $email, -type  => 'list', } );
$lh->remove_subscriber( { -email => $email, -type  => 'sub_confirm_list', } );




# Subscribed - with email_your_subscribed_msg DISABLED
$lh->add_subscriber( { -email => $email, -type  => 'list', } );
$ls->save({ email_your_subscribed_msg => 0 }); 
$q->param('list',  $list); 
$q->param('email', $email); 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 0);
ok($r->{errors}->{subscribed} == 1);
ok($r->{redirect}->{url}   eq 'http://example.com/alt_url_sub_confirm_failed.html');
ok($r->{redirect}->{query} eq 'list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=subscribed');
ok($r->{redirect}->{using} == 1); 
ok($r->{redirect}->{using_with_query} == 1);
ok(exists($r->{error_descriptions}->{subscribed})); 


undef $r; 
my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 1,
    	-return_json => 0, 
	}
);
my $redirect = "Status: 302 Found\r\nLocation: http://example.com/alt_url_sub_confirm_failed.html?list=dadatest&email=user%40example.com&status=0&rm=sub_confirm&errors[]=subscribed\r\n\r\n";
ok($r eq $redirect); 
undef $r; 
$lh->remove_subscriber( { -email => $email, -type  => 'list', } );
$q->delete_all;

$ls->save(
	{ 
		enable_closed_loop_opt_in         => 0, 
		captcha_sub                       => 1, 
		enable_subscription_approval_step => 0, 
		
	}
); 
$q->param('list',  $list); 
$q->param('email', $email); 

my $r = $das->subscribe(
    {
        -cgi_obj     => $q,
        -html_output => 0,
    	-return_json => 0, 
	}
);
ok($r->{email} eq $email);
ok($r->{list} eq $list);
ok($r->{status} == 1);
ok($r->{redirect}->{url}   eq 'http://localhost?f=subscribe&email=user%40example.com&list=dadatest');
ok($r->{redirect_required} eq 'subscription_requires_captcha'); 
ok($r->{success_message} eq 'use redirect'); 
undef $r; 
$q->delete_all;



SKIP: {
    skip "Profile Fields is not supported with this current backend." 
    if $lh->can_have_subscriber_fields == 0; 

    # Profile Fields

    require DADA::ProfileFieldsManager;
    my $pfm = DADA::ProfileFieldsManager->new;
    $pfm->add_field(
        {
            -field          => 'first_name',
            -required       => 1,
        }
    );
    $pfm->add_field(
        {
            -field          => 'last_name',
            -required       => 0,
        }
    );

    $q->param('list',  $list); 
    $q->param('email', $email); 
    my $r = $das->subscribe(
        {
            -cgi_obj     => $q,
            -html_output => 0,
        	-return_json => 0, 
    	}
    );
    #diag Dumper($r);
    ok($r->{email} eq $email);
    ok($r->{list} eq $list);
    ok($r->{status} == 0);
    #ok($r->{redirect}->{url}   eq '');
    #ok($r->{redirect}->{query} eq 'list=dadatest&rm=sub&subscription_requires_approval=1&status=1&email=user%40example.com');
    #ok($r->{redirect}->{using} == 0); 
    #ok($r->{redirect}->{using_with_query} == 0);
    ok(exists($r->{error_descriptions}->{invalid_profile_fields})); 
    ok($r->{profile_errors}->{first_name}->{required} == 1); 
    undef $r;
    $q->delete_all;
    $lh->remove_subscriber(
        {
            -email => $email,
            -type  => 'sub_confirm_list',
        }
    );
    $ct->remove_all_tokens; 



    # This one, we just make sure it works, with profile fields, and those FIELDS ARE SAVED!!! 
    undef $lh; 
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 

    $ls->save(
    	{ 
    		enable_closed_loop_opt_in         => 1, 
    		captcha_sub                       => 0, 
    		enable_subscription_approval_step => 0, 		
    	}
    ); 

    $q->param('list',  $list); 
    $q->param('email', $email); 
    $q->param('first_name', 'First Name!'); 
    $q->param('last_name', 'Last Name!'); 

    my $r = $das->subscribe(
        {
            -cgi_obj     => $q,
            -html_output => 0,
        	-return_json => 0, 
    	}
    );
    #diag Dumper($r);
    ok($r->{email} eq $email);
    ok($r->{list} eq $list);
    ok($r->{status} == 1);
    #ok($r->{redirect}->{url}   eq '');
    #ok($r->{redirect}->{query} eq 'list=dadatest&rm=sub&subscription_requires_approval=1&status=1&email=user%40example.com');
    #ok($r->{redirect}->{using} == 0); 
    #ok($r->{redirect}->{using_with_query} == 0);

    #sleep(30); 

    my $sub_info = $lh->get_subscriber(
    		{
    			-email => '*' . $email, 
    			-type  => 'sub_confirm_list', 
    		}
    	);
    ok($sub_info->{'first_name'} eq 'First Name!');
    ok($sub_info->{'last_name'}  eq 'Last Name!');

    undef $r; 
    $q->delete_all;

};





dada_test_config::remove_test_list;
dada_test_config::remove_test_list({-name => 'test2'});
dada_test_config::wipe_out;