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
my $email = 'user@example.com'; 

use DADA::App::Subscriptions::ConfirmationTokens; 
my $ct = DADA::App::Subscriptions::ConfirmationTokens->new; 
ok($ct->isa('DADA::App::Subscriptions::ConfirmationTokens'));

ok($ct->exists('doesntexist') == 0); 

ok($ct->exists('doesntexist') == 0); 

my $token = $ct->save(
	{
		-list  => $list, 
		-email => $email,
		-data  => {
			flavor => 'sub_confirm', 
		}
	}
);
ok(length($token) == 40); 
ok($ct->exists($token) == 1);

my $data = $ct->fetch($token); 

ok($data->{email} eq $email); 
ok($data->{list}  eq $list); 
ok($data->{data}->{flavor} eq 'sub_confirm'); 
ok($ct->remove_by_token($token) == 1); 
ok($ct->exists($token) == 0);


dada_test_config::remove_test_list;
dada_test_config::wipe_out;


