#!/usr/bin/perl
use strict; 

use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
./t

); 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


use Test::More qw(no_plan); 

my $file; 

do "t/DADA_MailingList_Settings.pl";
