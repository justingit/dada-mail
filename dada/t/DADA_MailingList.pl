#!/usr/bin/perl 

use strict; 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 


use DADA::MailingList; 
use DADA::App::Guts; 


eval { DADA::MailingList::Create() }; 
ok($@, "calling DADA::MailingList::Create() without any paramaters causes an error!: $@");     

my $list = dada_test_config::create_test_list(); 

eval { DADA::MailingList::Create({list => $list}) }; 
ok($@, "calling DADA::MailingList::Create() with the list paramater containing a list that exists causes an error!: $@");     

dada_test_config::remove_test_list(); 

# This is weird, since we're testing the test suite... but... whatever...
ok(DADA::App::Guts::check_if_list_exists(-List => $list) == 0, "The Test List has been removed successfully."); 


my $ls = DADA::MailingList::Create({list => 'mytestlist'});
ok($ls->isa('DADA::MailingList::Settings')); 


DADA::MailingList::Remove({-name => 'mytestlist'});



eval { DADA::MailingList::Remove({-name => 'mytestlist'})  }; 
ok($@, "calling DADA::MailingList::Remove() with a non-existant causes an error!: $@");     


dada_test_config::wipe_out;
