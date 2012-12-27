#!/usr/bin/perl
use strict; 

use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib

/Users/justin/Documents/DadaMail/build/bundle/perllib

./t
); 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
use Test::More; 
unless(dada_test_config::PostgreSQL_test_enabled()  ) {
    plan skip_all => 'PostgreSQL testing is not enabled...';
}
else {
   plan 'no_plan'; 
}

SKIP: {
        eval { require DBD::Pg };

        skip "DBD::Pg not installed", 2 if $@;

    my $file; 
    
    require dada_test_config; 
    
    dada_test_config::create_PostgreSQL_db(); 

    require DADA::Config; 
 
    
    open(FILE, "t/DADA_MailingList_Settings.pl") or die $!; 
    
    {
        local $/ = undef; 
        $file = <FILE>; 
    }
    close(FILE); 
    
    eval $file;
    
    if ($@){ 
        diag $@; 
    } 

    dada_test_config::destroy_PostgreSQL_db();

}
