#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 

use dada_test_config;

use Test::Simple qw(no_plan); 

ok(1 == 1, "hey! We're alive! aaahhh!!!"); 

