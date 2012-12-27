#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 

use Test::More qw(no_plan); 


BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}

use dada_test_config; 
my $list = dada_test_config::create_test_list;

do "plugins/default_mass_mailing_messages.cgi";




ok(default_mass_mailing_messages->test_sub() eq q{Hello, World!});




dada_test_config::remove_test_list;
dada_test_config::wipe_out;