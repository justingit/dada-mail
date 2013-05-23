#!/usr/bin/perl
use strict; 

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

dada_test_config::remove_test_list;
dada_test_config::remove_test_list({-name => 'test2'});

dada_test_config::wipe_out;


