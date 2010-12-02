#!/usr/bin/perl 

use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use DADA::Config; 
use DADA::App::Guts; 

ok($DADA::Config::GLOBAL_UNSUBSCRIBE == 0, "Defaults to, '0'");
$DADA::Config::GLOBAL_UNSUBSCRIBE = 1;
ok($DADA::Config::GLOBAL_UNSUBSCRIBE == 1, "And, now it's '1'");



my $list  = dada_test_config::create_test_list;
my $list2  = dada_test_config::create_test_list({-name => 'list2'});
my $list3  = dada_test_config::create_test_list({-name => 'list3'});

use DADA::MailingList::Subscribers; 
my $lh  = DADA::MailingList::Subscribers->new({-list => $list});
my $lh2 = DADA::MailingList::Subscribers->new({-list => $list2});
my $lh3 = DADA::MailingList::Subscribers->new({-list => $list3});

my @lh_s = ($lh, $lh2, $lh3);

my @subscribers = (
	'user@example.com',
	'user2@example.com',
	'user3@example.com',
); 


for my $local_lh(@lh_s){
	for my $sub(@subscribers){ 
		$local_lh->add_subscriber({-email => $sub});
	}
}


# This is to just check we've actually subscribed them: 
ok($lh->num_subscribers == 3,  "Three in #1"); 
ok($lh2->num_subscribers == 3, "Three in #2"); 
ok($lh3->num_subscribers == 3, "Three in #3"); 


# Now, let's remove someone from ONE list: 
$lh->remove_subscriber({-email => 'user@example.com'}); 

ok($lh->num_subscribers == 2,  "Two in #1"); 
ok($lh2->num_subscribers == 2, "Two in #2"); 
ok($lh3->num_subscribers == 2, "Two in #3");


# Now, let's remove someone from ONE list: 
# Note as well this is the old API: 

$lh2->remove_from_list(
	-Email_List =>['user2@example.com'], 
    -Type       => 'list',
);


ok($lh->num_subscribers == 1,  "One in #1"); 
ok($lh2->num_subscribers == 1, "One in #2"); 
ok($lh3->num_subscribers == 1, "One in #3");

# And this time, we're actually going to go through the unsubscription proces... kinda. 
# I'm doing this, just to speed things up: 
# This'll stop confirmations from needing to be done

require DADA::MailingList::Settings; 
my $das = DADA::App::Subscriptions->new; 
my $ls3 = DADA::MailingList::Settings->new({-list => $list3});
$ls3->param('unsub_confirm_email', 0); 

use DADA::App::Subscriptions; 
my $dap = DADA::App::Subscriptions->new; 
   $dap->test(1);
ok($dap->test == 1, "Testing is on..."); 


require CGI; 
my $q = new CGI; 
   $q = decode_cgi_obj($q);

$q->param('email', 'user3@example.com'); 
$q->param('list',   $list3); 
$q->param('f',      'u'); 
diag $dap->unsubscribe({-cgi_obj => $q,}); 
	

ok($lh->num_subscribers == 0,  "Zero in #1"); 
ok($lh2->num_subscribers == 0, "Zero in #2"); 
ok($lh3->num_subscribers == 0, "Zero in #3");

# There's still a potential problem with the above method, if BOTH global unsub 
# and global black list is on - it's fixed in code, but there's presently, no 
# test for it. Yet. 




dada_test_config::remove_test_list;
dada_test_config::remove_test_list({-name => $list2});
dada_test_config::remove_test_list({-name => $list3});

dada_test_config::wipe_out;