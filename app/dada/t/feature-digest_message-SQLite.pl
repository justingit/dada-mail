#!/usr/bin/perl
use strict; 
use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ./t); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 



use Test::More; 
unless(dada_test_config::SQLite_test_enabled()  ) {
    plan skip_all => 'SQLite testing is not enabled...';
}
else {
   plan 'no_plan'; 
}

SKIP: {

        eval { require DBD::SQLite };

        skip "DBD::SQLite not installed", 2 if $@;

    
    
    my $file;     
    dada_test_config::create_SQLite_db(); 
        require DADA::Config; 

    
    open(FILE, "t/feature-digest_message.pl") or die $!; 
    
    {
        local $/ = undef; 
        $file = <FILE>; 
    }
    close(FILE); 
    
    eval $file;
    
    if ($@){ 
        diag $@; 
    } 
    
    dada_test_config::destroy_SQLite_db();

}
