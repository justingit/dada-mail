#!/usr/bin/perl
use strict; 

use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
./t
); 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use Test::More qw(no_plan); 
    use DADA::Config; 
    	$DADA::Config::BACKEND_DB_TYPE    = 'Default'; 
	    $DADA::Config::SUBSCRIBER_DB_TYPE       = 'PlainText';
	    $DADA::Config::ARCHIVE_DB_TYPE          = 'Db';
	    $DADA::Config::SETTINGS_DB_TYPE         = 'Db';
	    $DADA::Config::SESSION_DB_TYPE          = 'Db';
	    $DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'Db';
	    $DADA::Config::CLICKTHROUGH_DB_TYPE     = 'Db';
      
 my $file; 
    
    require dada_test_config; 
    
    
    
    open(FILE, "t/DADA_App_Subscriptions_ConfirmationTokens.pl") or die $!; 
    
    {
        local $/ = undef; 
        $file = <FILE>; 
    }
    close(FILE); 
    
    eval $file;
    
    if ($@){ 
        diag $@; 
    } 
