#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}

use dada_test_config; 
my $list = dada_test_config::create_test_list;

do "plugins/password_protect_directories.cgi";




ok(password_protect_directories->test_sub() eq q{Hello, World!});




dada_test_config::remove_test_list;
dada_test_config::wipe_out;