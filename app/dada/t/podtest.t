#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
use dada_test_config; 

use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

#system('mv', 'DADA/perllib', 'perllib'); 

my @poddirs = qw(extras/documentation/pod_source
                 extras/developers
                 extras/scripts
                 DADA
                 plugins
                 extensions
);

my @pod_files = all_pod_files( @poddirs ); 
my @screen_pod_files = (); 
foreach(@pod_files){ 
	if($_ !~ m/DADA\/perllib/ && $_ !~ m/DADA\/App\/Support/){ 
		push(@screen_pod_files, $_); 
	}
}
all_pod_files_ok( @screen_pod_files );


#system('mv', 'perllib', 'DADA/perllib'); 


dada_test_config::wipe_out;