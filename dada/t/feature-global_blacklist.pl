#!/usr/bin/perl 

use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use DADA::Config; 
ok($DADA::Config::GLOBAL_BLACK_LIST == 0, "Defaults to, '0'");
$DADA::Config::GLOBAL_BLACK_LIST = 1;
ok($DADA::Config::GLOBAL_BLACK_LIST == 1, "And, now it's '1'");


my $black_listed = 'black_listed@example.com'; 

my $list  = dada_test_config::create_test_list;
my $list2  = dada_test_config::create_test_list({-name => 'list2'});
my $list3  = dada_test_config::create_test_list({-name => 'list3'});



use DADA::MailingList::Subscribers; 
my $lh  = DADA::MailingList::Subscribers->new({-list => $list});
my $lh2 = DADA::MailingList::Subscribers->new({-list => $list2});
my $lh3 = DADA::MailingList::Subscribers->new({-list => $list3});

# Remember, to turn it on! 
use DADA::MailingList::Settings; 
my $ls = DADA::MailingList::Settings->new({-list => $list});
my $ls2 = DADA::MailingList::Settings->new({-list => $list2});
my $ls3 = DADA::MailingList::Settings->new({-list => $list3});
$ls->param('black_list', 1); 
$ls2->param('black_list', 1); 
$ls3->param('black_list', 1); 


my @lh_s = ($lh, $lh2, $lh3);

# Set 'em up: 
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


# Let's add someone to the black list: 
$lh->add_subscriber(
	{ 
		-email => $black_listed, 
		-type  => 'black_list', 
	},
);


ok($lh->num_subscribers({-type => 'black_list'}) == 1,  "We have one black listed subscriber in #1"); 
ok($lh2->num_subscribers({-type => 'black_list'}) == 1, "We have one black listed subscriber in #2"); 
ok($lh3->num_subscribers({-type => 'black_list'}) == 1, "We have one black listed subscriber in #3"); 




# Now, let's verify attempting to subscribe the black_listed address: 
for my $local_lh( @lh_s){ 
	my ($status, $errors) = $lh->subscription_check({-email => $black_listed}); 
	ok($errors->{black_listed} == 1, "Black Listed for List: " . $lh->{list}); 
}

# This is a fairly bizarre method: 
# I'm going to force a subscription, anyways! 
$lh3->add_subscriber(
	{ 
		-email => $black_listed, 
	},
);
my $filtered = $lh3->filter_list_through_blacklist; 

ok($filtered->[0]->{email} eq $black_listed, "Found our black listed address from list #1 in list #3.");

$lh3->remove_subscriber(
	{
		-email => $black_listed, 
		-type  => 'list'
	},
); 


# Another fairly magical method THIRD LIST
# Changed what's usually, "$black_listed" to, " $bl" since we're already
# using that variable... 
my ($subscribed, $not_subscribed, $bl, $not_white_listed, $invalid) 
	= $lh3->filter_subscribers(
		{
			-emails => [$black_listed], 
		}
	);
	
use Data::Dumper; 
diag Dumper([$subscribed, $not_subscribed, $bl, $not_white_listed, $invalid]); 

ok($bl->[0] eq $black_listed, "filter_subscribers has black listed subscriber from list #1"); 





dada_test_config::remove_test_list;
dada_test_config::remove_test_list({-name => $list2});
dada_test_config::remove_test_list({-name => $list3});

dada_test_config::wipe_out;