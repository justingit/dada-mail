#!/usr/bin/perl 
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


use Test::More qw( no_plan ); 

use DADA::App::Guts; 
use DADA::MailingList; 

my $different_lists = { 

    normal => { 
        list             => 'justin', 
        list_name        => 'Justin!', 
        list_owner_email => 'justin@skazat.com',  
        password         => 'abcd', 
        retype_password  => 'abcd', 
        info             => 'info', 
        privacy_policy   => 'privacy_policy',
        physical_address => 'physical_address', 
    }, 
    
    missing_everything => { 
    }, 
    
    
    list_name_bad_characters => { 
        list_name             => '<whacka whacka>', 
    }, 

    list_utf8_characters => { 
        list             => $dada_test_config::UTF8_STR, 
    },
    
    

    shortname_too_long => { 
        list             => 'thisshortnameistoolongitisitisitis', 
    }, 

    password_ne_retype_password => { 
    
        password => 'this', 
        retype_password => 'that', 
    
    },

    reserved_word => { 
        list             => '_screen_cache', 
        list_name        => 'Justin!', 
        list_owner_email => 'justin@skazat.com',  
        password         => 'abcd', 
        retype_password  => 'abcd', 
        info             => 'info', 
        privacy_policy   => 'privacy_policy',
        physical_address => 'physical_address', 
    },


};
my $list_errors = 0; 
my $flags       = {};
    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{normal});
    ok($list_errors == 0); 
    undef($list_errors); 
    undef($flags); 
 	   
    
    
    
    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{missing_everything});
    ok($list_errors               >= 1); 
    ok($flags->{list}             == 1); 
    ok($flags->{list_name}        == 1); 
    ok($flags->{password}         == 1); 
    ok($flags->{retype_password}  == 1); 
    ok($flags->{list_info}        == 1); 
    ok($flags->{privacy_policy}   == 1); 
    ok($flags->{physical_address} == 1); 

    undef($list_errors); 
    undef($flags); 
    
    
    
    
    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{list_name_bad_characters});
    ok($list_errors >= 1); 
    ok($flags->{list_name_bad_characters} == 1); 
    undef($list_errors); 
    undef($flags); 


 
 
    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{password_ne_retype_password});
    ok($list_errors >= 1); 
    ok($flags->{password_ne_retype_password} == 1); 
    undef($list_errors); 
    undef($flags);


    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{shortname_too_long});
    ok($list_errors >= 1); 
    ok($flags->{shortname_too_long} == 1); 
    undef($list_errors); 
    undef($flags); 

    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{list_utf8_characters});
    ok($list_errors >= 1); 
    ok($flags->{weird_characters} == 1); 
    undef($list_errors); 
    undef($flags);

	# reserved word is piggy backing weird_characters right now... 
    ($list_errors,$flags) = check_list_setup(-fields => $different_lists->{reserved_word});
    ok($list_errors >= 1); 
    ok($flags->{weird_characters} == 1); 
    undef($list_errors); 
    undef($flags); 


    my $test_copy = $different_lists->{normal};
    delete($test_copy->{retype_password});
    my $ls = DADA::MailingList::Create(
		{
			-list     => $test_copy->{list}, 
			-settings => $test_copy,
			-test     => 0, 
		}
	); 
    ok($ls->isa('DADA::MailingList::Settings'), "name list isa DADA::MailingList::Settings!"); 
    
  
    my $Remove = DADA::MailingList::Remove({ -name => $different_lists->{normal}->{list}});
    
    ok($Remove == 1, "Remove returned a status of, '1'");
    
    
# This has to be continued, but you get the idea...


dada_test_config::wipe_out;

