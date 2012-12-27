#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
use dada_test_config; 

use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

system('mv', 'DADA/perllib', 'perllib'); 

my @poddirs = qw(extras/documentation/pod_source
                 extras/developers
                 extras/Flash
                 extras/scripts
                 DADA
                 plugins
                 extensions
);
all_pod_files_ok( all_pod_files( @poddirs ) );


system('mv', 'perllib', 'DADA/perllib'); 


dada_test_config::wipe_out;