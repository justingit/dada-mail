package dada_test_config;

use Carp qw(croak carp); 
#$Carp::Verbose = 1; 
use lib '/Users/justin/Documents/DadaMail/git/dada-mail/dada/t'; 

BEGIN { 
    
    use FindBin '$Bin';
    use lib "$Bin/../ $Bin/";
	use DADA::Config; 
	$DADA::Config::FILES = './test_only_dada_files'; 

#---------------------------------------------------------------------#
$DADA::Config::ARCHIVES                 = $DADA::Config::FILES;
$DADA::Config::BACKUPS                  = $DADA::Config::FILES;
$DADA::Config::LOGS                     = $DADA::Config::FILES;
$DADA::Config::TEMPLATES                = $DADA::Config::FILES;
$DADA::Config::TMP                      = $DADA::Config::FILES;
$DADA::Config::PROGRAM_USAGE_LOG        = $DADA::Config::FILES . '/dada.txt'; 


#------------------	
	if(! -e './test_only_dada_files'){ 
		# carp "no ./test_only_dada_files exists... (making one!)"; 
		mkdir './test_only_dada_files'; 
		if(! -e './test_only_dada_files'){ 
				croak "I couldn't make a tmp directory - heavens!"; 
		}		
	}
	

}

use __Test_Config_Vars; 

use lib "$Bin/../DADA/perllib";
use Params::Validate ':all';

use DADA::MailingList; 

require Exporter; 
@ISA = qw(Exporter); 



@EXPORT = qw(

create_test_list
remove_test_list

create_SQLite_db
destroy_SQLite_db


create_MySQL_db
destroy_MySQL_db


MySQL_test_enabled
PostgreSQL_test_enabled
SQLite_test_enabled

slurp

);



 
use vars qw(@EXPORT $UTF8_STR); 

@EXPORT_OK = qw($UTF8_STR);

$UTF8_STR = "\x{a1}\x{2122}\x{a3}\x{a2}\x{221e}\x{a7}\x{b6}\x{2022}\x{aa}\x{ba}";


use strict;

sub test_list_vars { 


    my $foo = { 
    
            list             => 'dadatest', 
            list_name        => 'Dada Test List' . $UTF8_STR, 
            list_owner_email => 'test@example.com',  
            password         => 'password', 
            retype_password  => 'password', 
            info             => 'list information' . $UTF8_STR, 
            privacy_policy   => 'Privacy Policy' . $UTF8_STR,
            physical_address => 'Physical Address' . $UTF8_STR, 
    
    };

    return $foo; 

}



sub create_test_list { 
    my $local_test_list_vars = test_list_vars(); 
    delete($local_test_list_vars->{retype_password});

    my %args = validate(@_,{
        '-name'                     => { default => $local_test_list_vars->{list} },
        '-list_name'                     => { default => $local_test_list_vars->{list_name} },
        '-remove_existing_list'     => { default => 0 },
        '-remove_subscriber_fields' => { default => 0 },
    });

    my $list_name = $args{-name};

	$local_test_list_vars->{list_name} = $args{-list_name};
	
    if($args{-remove_existing_list} == 1){ 
        require DADA::App::Guts; 
        if(DADA::App::Guts::check_if_list_exists(-List => $list_name) == 1){ 
            #carp 'list: ' . $local_test_list_vars->{list} . ' already exists. Removing...';
            remove_test_list({-name => $list_name}); 
        }
    }
    
    my $ls = DADA::MailingList::Create(
		{
			-list     => $list_name,
			-settings => $local_test_list_vars,
			-test     => 0, 
		}
	); 
   
    if($args{-remove_subscriber_fields} == 1){ 
        #carp 'Removing extraneous Profile Fields....'; 
        require DADA::MailingList::Subscribers; 
        my $lh = DADA::MailingList::Subscribers->new({-list => $list_name}); 
        my $fields = $lh->subscriber_fields;
        for(@$fields){ 
           # carp 'Removing Field: ' . $_; 
            $lh->remove_subscriber_field({-field => $_}); 
        }
    }
   
    undef $ls; 
    return $list_name;
}


sub remove_test_list { 

  my ($args) = @_; 
  
    
    if(exists($args->{-name})){ 
        
       # carp "yes. " . $args->{-name}; 


        DADA::MailingList::Remove({ -name => $args->{-name}});

    }
    else { 
       # carp 'removing: ' . test_list_vars()->{list}; 
        DADA::MailingList::Remove({ -name => test_list_vars()->{list}});

    }
    
    

    
    
}


sub create_SQLite_db { 


    use DADA::Config; 
	#$DADA::Config::DBI_PARAMS->{dada_connection_method} = 'connect';  

	$DADA::Config::BACKEND_DB_TYPE          = 'SQL'; 
	$DADA::Config::SETTINGS_DB_TYPE         = 'SQL'; 
	$DADA::Config::ARCHIVE_DB_TYPE          = 'SQL'; 
	$DADA::Config::SUBSCRIBER_DB_TYPE       = 'SQL'; 
	$DADA::Config::SESSIONS_DB_TYPE         = 'SQL'; 
	$DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'SQL'; 
	$DADA::Config::CLICKTHROUGH_DB_TYPE     = 'SQL';
	
#carp q{$__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{dbtype}} . $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{dbtype}; 

     %DADA::Config::SQL_PARAMS = %{$__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}};
for(keys  %DADA::Config::SQL_PARAMS){ 
	#print $_ . ' => ' . $DADA::Config::SQL_PARAMS{$_} . "\n"; 
}

    require DADA::App::DBIHandle; 
    my $dbi_handle = DADA::App::DBIHandle->new; 
    
    my $sql; 
    
    open(SQL, "extras/SQL/sqlite_schema.sql") or croak $!; 
    
    {
    local $/ = undef; 
    $sql = <SQL>; 
    
}

close(SQL) or croak $!; 

my @statements = split(';', $sql); 

    my $dbh = $dbi_handle->dbh_obj;
    
    for(@statements){ 
			
    	my $settings_table                      = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{settings_table}; 
		my $subscribers_table    	            = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{subscriber_table}; 
		my $archives_table          		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{archives_table}; 
		my $session_table           		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{session_table};
		my $bounce_scores_table     		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{bounce_scores_table};
		my $profile_table            		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{profile_table};  
		my $profile_fields_table                = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{profile_fields_table};
		my $profile_fields_attributes_table     = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{profile_fields_attributes_table};
		my $profile_settings_table              = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{profile_settings_table};
		my $clickthrough_urls_table             = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{clickthrough_urls_table};
		my $clickthrough_url_log_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{clickthrough_url_log_table};
		my $mass_mailing_event_log_table        = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{mass_mailing_event_log_table};
		my $password_protect_directories_table  = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{password_protect_directories_table};
		my $confirmation_tokens_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{confirmation_tokens_table};
		my $message_drafts_table                = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{message_drafts_table};

						
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_settings}{CREATE TABLE IF NOT EXISTS $settings_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_subscribers}{CREATE TABLE IF NOT EXISTS $subscribers_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_archives}{CREATE TABLE IF NOT EXISTS $archives_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_sessions}{CREATE TABLE IF NOT EXISTS $session_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_bounce_scores}{CREATE TABLE IF NOT EXISTS $bounce_scores_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profiles}{CREATE TABLE IF NOT EXISTS $profile_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_fields}{CREATE TABLE IF NOT EXISTS $profile_fields_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes}{CREATE TABLE IF NOT EXISTS $profile_fields_attributes_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_settings}{CREATE TABLE $profile_settings_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_clickthrough_urls}{CREATE TABLE IF NOT EXISTS $clickthrough_urls_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_clickthrough_url_log}{CREATE TABLE IF NOT EXISTS $clickthrough_url_log_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_mass_mailing_event_log}{CREATE TABLE IF NOT EXISTS $mass_mailing_event_log_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_password_protect_directories}{CREATE TABLE IF NOT EXISTS $password_protect_directories_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_confirmation_tokens}{CREATE TABLE IF NOT EXISTS $confirmation_tokens_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_message_drafts}{CREATE TABLE IF NOT EXISTS $message_drafts_table};	
		
		print 'query: ' . $_ . "\n\n"; 
        my $sth = $dbh->prepare($_) or croak $DBI::errstr; 

       $sth->execute
			or croak "cannot do statement $DBI::errstr\n"; 
			#sleep(1);
    }
	# print "Sleepin!"; 
	# sleep(60); 
	
}

sub destroy_SQLite_db { 

	chmod($DADA::Config::DIR_CHMOD, './test_only_dada_files/test_dada');
	unlink './test_only_dada_files/test_dada';
#	if(-e './test_only_dada_files/test_dada'){ 
#		die "YEAH, IT'S THERE!"; 
#	}
#	else { 
#		die "NO IT AIN'T THERE"; 
#	}
#
	
}




sub create_MySQL_db { 


    use DADA::Config; 
	$DADA::Config::BACKEND_DB_TYPE          = 'SQL'; 
	$DADA::Config::SETTINGS_DB_TYPE         = 'SQL'; 
	$DADA::Config::ARCHIVE_DB_TYPE          = 'SQL'; 
	$DADA::Config::SUBSCRIBER_DB_TYPE       = 'SQL'; 
	$DADA::Config::SESSIONS_DB_TYPE         = 'SQL'; 
	$DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'SQL';
	$DADA::Config::CLICKTHROUGH_DB_TYPE     = 'SQL';
   
    %DADA::Config::SQL_PARAMS = %{$__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}};
    
    
    require DADA::App::DBIHandle; 
    my $dbi_handle = DADA::App::DBIHandle->new; 
    
    my $sql; 
    
    open(SQL, "extras/SQL/mysql_schema.sql") or croak $!; 
    
    {
    local $/ = undef; 
    $sql = <SQL>; 
    
}

close(SQL) or croak $!; 

my @statements = split(';', $sql); 

    my $dbh = $dbi_handle->dbh_obj;
    
    for(@statements){ 
	
    	my $settings_table                      = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{settings_table}; 
		my $subscribers_table    	            = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{subscriber_table}; 
		my $archives_table          		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{archives_table}; 
		my $session_table           		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{session_table};
		my $bounce_scores_table     		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{bounce_scores_table};
		my $profile_table            		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{profile_table};  
		my $profile_fields_table                = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{profile_fields_table};
		my $profile_fields_attributes_table     = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{profile_fields_attributes_table};
		my $profile_settings_table              = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{profile_settings_table};
		my $clickthrough_urls_table             = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{clickthrough_urls_table};
		my $clickthrough_url_log_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{clickthrough_url_log_table};
		my $mass_mailing_event_log_table        = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{mass_mailing_event_log_table};
		my $password_protect_directories_table  = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{password_protect_directories_table};
		my $confirmation_tokens_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{confirmation_tokens_table};
		my $message_drafts_table                = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{message_drafts_table};
		
		
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_settings}{CREATE TABLE $settings_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_subscribers}{CREATE TABLE $subscribers_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_archives}{CREATE TABLE $archives_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_sessions}{CREATE TABLE $session_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_bounce_scores}{CREATE TABLE $bounce_scores_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profiles}{CREATE TABLE $profile_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_fields}{CREATE TABLE $profile_fields_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes}{CREATE TABLE $profile_fields_attributes_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_settings}{CREATE TABLE $profile_settings_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_clickthrough_urls}{CREATE TABLE $clickthrough_urls_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_settings}{CREATE TABLE IF NOT EXISTS $settings_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_subscribers}{CREATE TABLE IF NOT EXISTS $subscribers_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_archives}{CREATE TABLE IF NOT EXISTS $archives_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_sessions}{CREATE TABLE IF NOT EXISTS $session_table}; 
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_bounce_scores}{CREATE TABLE IF NOT EXISTS $bounce_scores_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profiles}{CREATE TABLE IF NOT EXISTS $profile_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_fields}{CREATE TABLE IF NOT EXISTS $profile_fields_table};
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes}{CREATE TABLE IF NOT EXISTS $profile_fields_attributes_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_clickthrough_url_log}{CREATE TABLE IF NOT EXISTS $clickthrough_url_log_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_mass_mailing_event_log}{CREATE TABLE IF NOT EXISTS $mass_mailing_event_log_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_password_protect_directories}{CREATE TABLE IF NOT EXISTS $password_protect_directories_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_confirmation_tokens}{CREATE TABLE IF NOT EXISTS $confirmation_tokens_table};	
		$_ =~ s{CREATE TABLE IF NOT EXISTS dada_message_drafts}{CREATE TABLE IF NOT EXISTS $message_drafts_table};	

		#print 'query: ' . $_; 
			
		if(length($_) > 10){ 

			#warn 'QUERY: ' . $_; 
			
			my $sth = $dbh->prepare($_); 
	       	$sth->execute; 
	    }
    
    }
    
    
}

sub destroy_MySQL_db { 

 #	carp 'destroy_MySQL_db1'; 
#	warn 'destroy_MySQL_db2';
	 
  require DADA::App::DBIHandle;
    my $dbi_handle = DADA::App::DBIHandle->new; 

    my $dbh = $dbi_handle->dbh_obj;

	 for(qw(
		subscriber_table
		archives_table
		settings_table
		session_table
		bounce_scores_table
		profile_table
		profile_fields_table
		profile_settings_table
		profile_fields_attributes_table
		clickthrough_urls_table
		clickthrough_url_log_table
		mass_mailing_event_log_table
		password_protect_directories_table
		confirmation_tokens_table
		message_drafts_table
		)){ 
			
#			carp "removing: " . $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{$_}; 
		 
		
	        $dbh->do('DROP TABLE ' . $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{$_})
	            or carp "cannot do statement! $DBI::errstr\n";  
		}
}





sub create_PostgreSQL_db { 


   use DADA::Config; 
	$DADA::Config::BACKEND_DB_TYPE          = 'SQL'; 
	$DADA::Config::SETTINGS_DB_TYPE         = 'SQL'; 
	$DADA::Config::ARCHIVE_DB_TYPE          = 'SQL'; 
	$DADA::Config::SUBSCRIBER_DB_TYPE       = 'SQL'; 
	$DADA::Config::SESSIONS_DB_TYPE         = 'SQL'; 
	$DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'SQL';
    $DADA::Config::CLICKTHROUGH_DB_TYPE     = 'SQL';
	
     %DADA::Config::SQL_PARAMS = %{$__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}};
    
    
    

    require DADA::App::DBIHandle; 
    my $dbi_handle = DADA::App::DBIHandle->new; 
    
    my $sql; 
    
    open(SQL, "extras/SQL/postgres_schema.sql") or croak $!; 
    
    {
    local $/ = undef; 
    $sql = <SQL>; 
    
}

close(SQL) or croak $!; 

my @statements = split(';', $sql); 

    my $dbh = $dbi_handle->dbh_obj;
    
	
    for(@statements){ 
   

	   	my $settings_table                      = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{settings_table}; 
		my $subscribers_table    	            = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{subscriber_table}; 
		my $archives_table          		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{archives_table}; 
		my $session_table                       = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{session_table};
		my $bounce_scores_table     		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{bounce_scores_table};
		my $profile_table            		    = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{profile_table};  
		my $profile_fields_table                = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{profile_fields_table};
		my $profile_fields_attributes_table     = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{profile_fields_attributes_table};
	    my $profile_settings_table              = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{profile_settings_table};
		my $clickthrough_urls_table             = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{clickthrough_urls_table};
		my $clickthrough_url_log_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{clickthrough_url_log_table};
		my $mass_mailing_event_log_table        = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{mass_mailing_event_log_table};
		my $password_protect_directories_table  = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{password_protect_directories_table};
		my $confirmation_tokens_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{confirmation_tokens_table};
		my $message_drafts_table                = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{message_drafts_table};
	
		
		
		
		$_ =~ s{CREATE TABLE dada_settings}{CREATE TABLE $settings_table}; 
		$_ =~ s{CREATE TABLE dada_subscribers}{CREATE TABLE $subscribers_table}; 
		$_ =~ s{CREATE TABLE dada_archives}{CREATE TABLE $archives_table}; 
		$_ =~ s{CREATE TABLE dada_sessions}{CREATE TABLE $session_table}; 
		$_ =~ s{CREATE TABLE dada_bounce_scores}{CREATE TABLE $bounce_scores_table};
		$_ =~ s{CREATE TABLE dada_profiles}{CREATE TABLE $profile_table};
		$_ =~ s{CREATE TABLE dada_profile_fields}{CREATE TABLE $profile_fields_table};
		$_ =~ s{CREATE TABLE dada_profile_fields_attributes}{CREATE TABLE $profile_fields_attributes_table};
		$_ =~ s{CREATE TABLE dada_profile_settings}{CREATE TABLE $profile_settings_table};	
		$_ =~ s{CREATE TABLE dada_clickthrough_urls}{CREATE TABLE $clickthrough_urls_table};	
		$_ =~ s{CREATE TABLE dada_clickthrough_url_log}{CREATE TABLE $clickthrough_url_log_table};	
		$_ =~ s{CREATE TABLE dada_mass_mailing_event_log}{CREATE TABLE $mass_mailing_event_log_table};	
		$_ =~ s{CREATE TABLE dada_password_protect_directories}{CREATE TABLE $password_protect_directories_table};	
		$_ =~ s{CREATE TABLE dada_confirmation_tokens}{CREATE TABLE IF NOT EXISTS $confirmation_tokens_table};	
		$_ =~ s{CREATE TABLE dada_message_drafts}{CREATE TABLE IF NOT EXISTS $message_drafts_table};	

		print "query: $_"; 


	    my $sth = $dbh->prepare($_); #  or croak $DBI::errstr; 
	       $sth->execute or carp $DBI::errstr; 
		
    }
    
    
}

sub destroy_PostgreSQL_db { 

 require DADA::App::DBIHandle;
    my $dbi_handle = DADA::App::DBIHandle->new; 

    my $dbh = $dbi_handle->dbh_obj;

	 for(qw(
		subscriber_table
		archives_table
		settings_table
		session_table
		bounce_scores_table
		profile_table
		profile_fields_table
		profile_fields_attributes_table
		profile_settings_table
		clickthrough_urls_table
		clickthrough_url_log_table
		mass_mailing_event_log_table
		password_protect_directories_table
		confirmation_tokens_table
		message_drafts_table
		)){ 
	        $dbh->do('DROP TABLE ' . $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{$_})
	            or carp "cannot do statement! $DBI::errstr\n";  
		}	
}




sub wipe_out { 
	
	if(-e './test_only_dada_files'){ 
		`rm -Rf ./test_only_dada_files`;
	}	
	if(-e './test_only_dada_files'){ 
		warn "wiping out didn't work!"; 
	}
}

sub MySQL_test_enabled { 
	return $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{test_enabled}; 
}
sub PostgreSQL_test_enabled { 
	return $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{test_enabled}; 
}
sub SQLite_test_enabled { 
	return $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{test_enabled}; 
}


sub slurp { 
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}


1;
