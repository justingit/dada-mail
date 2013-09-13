#!/usr/bin/perl 

use strict; 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 


use DADA::MailingList; 
use DADA::App::Guts; 


eval { DADA::MailingList::Create() }; 
ok($@, "calling DADA::MailingList::Create() without any parameters causes an error!: $@");     

my $list = dada_test_config::create_test_list(); 

eval { DADA::MailingList::Create({-list => $list}) }; 
ok($@, "calling DADA::MailingList::Create() with the list parameter containing a list that exists causes an error!: $@");     

dada_test_config::remove_test_list(); 

# This is weird, since we're testing the test suite... but... whatever...
ok(DADA::App::Guts::check_if_list_exists(-List => $list) == 0, "The Test List has been removed successfully."); 

my $ls; 

eval{ $ls = DADA::MailingList::Create({-list => 'mytestlist'}); };
#ok($ls->isa('DADA::MailingList::Settings')); 
ok($@, "calling DADA::MailingList::Create() with only the list parameter  causes an error!: $@");     


$ls = DADA::MailingList::Create(
	{
		-list => 'mytestlist',
		-settings => {}, 
		-test     => 0, 
	}
);
#ok($ls->isa('DADA::MailingList::Settings')); 

ok($ls->isa('DADA::MailingList::Settings'), "calling DADA::MailingList::Create() with the -list and -settings parameter worked.");     
undef $ls; 


DADA::MailingList::Remove({-name => 'mytestlist'});



eval { DADA::MailingList::Remove({-name => 'mytestlist'})  }; 
ok($@, "calling DADA::MailingList::Remove() with a non-existent causes an error!: $@");     



# This is to test the cloning stuff works. 

$ls = DADA::MailingList::Create(
	{
		-list     => 'to_clone',
		-settings => {
			alt_url_sub_confirm_success => 'http://example.com/success.html', 
		}, 
		-test    => 0, 
	}
);
my $ls2 = DADA::MailingList::Create(
	{
		-list     => 'cloned',
		-settings => {}, 
		-clone    => 'to_clone', 
		-test     => 0, 
	}
);

ok($ls2->param('alt_url_sub_confirm_success') eq 'http://example.com/success.html', "cloning seems successfuL!"); 



DADA::MailingList::Remove({-name => 'to_clone'});
DADA::MailingList::Remove({-name => 'cloned'}); 
















dada_test_config::wipe_out;
