package dada_test_config;


use lib qw (../ ./); 

use __Test_Config_Vars; 
use Carp qw(croak carp); 

BEGIN { 
	

	use DADA::Config; 
	$DADA::Config::FILES = './test_only_dada_files'; 

#---------------------------------------------------------------------#
$DADA::Config::ARCHIVES                 = $DADA::Config::FILES;
$DADA::Config::BACKUPS                  = $DADA::Config::FILES;
$DADA::Config::LOGS                     = $DADA::Config::FILES;
$DADA::Config::TEMPLATES                = $DADA::Config::FILES;
$DADA::Config::TMP                      = $DADA::Config::FILES;

#------------------	
	if(! -e './test_only_dada_files'){ 
		carp "no ./test_only_dada_files exists... (making one!)"; 
		mkdir './test_only_dada_files'; 
		if(! -e './test_only_dada_files'){ 
				croak "I couldn't make a tmp directory - heavens!"; 
		}		
	}
	

}


use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 

use DADA::MailingList; 

require Exporter; 
@ISA = qw(Exporter); 

sub test_list_vars { 


    my $foo = { 
    
            list             => 'dadatest', 
            list_name        => 'Dada Test List', 
            list_owner_email => 'test@example.com',  
            password         => 'password', 
            retype_password  => 'password', 
            info             => 'list information', 
            privacy_policy   => 'Privacy Policy',
            physical_address => 'Physical Address', 
    
    };

    return $foo; 

}

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

);




use strict; 
use vars qw(@EXPORT); 


sub create_test_list { 

    my ($args) = @_; 
    
    
    my $local_test_list_vars = test_list_vars(); 
    
    if(exists($args->{-name})){ 
        $local_test_list_vars->{list} = $args->{-name}; 
    }
    if(!exists($args->{-remove_existing_list})){ 
        $args->{-remove_existing_list} = 0; 
    }

    if(!exists($args->{-remove_subscriber_fields})){ 
        $args->{-remove_subscriber_fields} = 0; 
    }
    
    delete($local_test_list_vars->{retype_password});

    if($args->{-remove_existing_list} == 1){ 
    
        require DADA::App::Guts; 
        
        if(DADA::App::Guts::check_if_list_exists(-List => $local_test_list_vars->{list}) == 1){ 
            #carp 'list: ' . $local_test_list_vars->{list} . ' already exists. Removing...';
            remove_test_list({-name => $local_test_list_vars->{list}}); 
        }
    
    }
    
    my $ls = DADA::MailingList::Create(
		{
			-list     => $local_test_list_vars->{list}, 
			-settings => $local_test_list_vars,
			-test     => 0, 
		}
	); 
   
   
    if($args->{-remove_subscriber_fields} == 1){ 
        #carp 'Removing extraneous subscriber fields....'; 
        require DADA::MailingList::Subscribers; 
        my $lh = DADA::MailingList::Subscribers->new({-list => $local_test_list_vars->{list}}); 
        my $fields = $lh->subscriber_fields;
        foreach(@$fields){ 
           # carp 'Removing Field: ' . $_; 
            $lh->remove_subscriber_field({-field => $_}); 
        }
    }
   
    undef $ls; 
    
    return $local_test_list_vars->{list};
    
    
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

	$DADA::Config::SETTINGS_DB_TYPE         = 'SQL'; 
	$DADA::Config::ARCHIVE_DB_TYPE          = 'SQL'; 
	$DADA::Config::SUBSCRIBER_DB_TYPE       = 'SQL'; 
	$DADA::Config::SESSIONS_DB_TYPE         = 'SQL'; 
	$DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'SQL'; 
	
#carp q{$__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{dbtype}} . $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{dbtype}; 

     %DADA::Config::SQL_PARAMS = %{$__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}};
foreach(keys  %DADA::Config::SQL_PARAMS){ 
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

my @statements = split(';', $sql,4); 

    my $dbh = $dbi_handle->dbh_obj;
    
    foreach(@statements){ 

		my $settings_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{settings_table}; 
		my $subscribers_table        = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{subscriber_table}; 
		my $archives_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{archives_table}; 
		my $session_table            = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{session_table};
		my $bounce_scores_table      = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{bounce_scores_table};
		my $profile_fields_table  = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{profile_fields_table};
		my $subscriber_profile_table = $__Test_Config_Vars::TEST_SQL_PARAMS->{SQLite}->{subscriber_profile_table};
		$_ =~ s{CREATE TABLE dada_settings}{CREATE TABLE $settings_table}; 
		$_ =~ s{CREATE TABLE dada_subscribers}{CREATE TABLE $subscribers_table}; 
		$_ =~ s{CREATE TABLE dada_archives}{CREATE TABLE $archives_table}; 
		$_ =~ s{CREATE TABLE dada_sessions}{CREATE TABLE $session_table}; 
		$_ =~ s{CREATE TABLE dada_bounce_scores}{CREATE TABLE $bounce_scores_table}; 
		$_ =~ s{CREATE TABLE dada_profile_fields}{CREATE TABLE $profile_fields_table};
		$_ =~ s{CREATE TABLE dada_profile}{CREATE TABLE $subscriber_profile_table};
        #print "query: " . $_ . "\n"; 
        my $sth = $dbh->prepare($_); 



       $sth->execute; 
    
    
    }
    
    
}

sub destroy_SQLite_db { 

=cut
   
    require DADA::App::DBIHandle;
    my $dbi_handle = DADA::App::DBIHandle->new; 
    
    my $dbh = $dbi_handle->dbh_obj;
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{subscriber_table})
            or croak "cannot do statement! $DBI::errstr\n";  
        
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{archives_table})
                    or croak "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{settings_table})
                    or croak "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{session_table})
                    or croak "cannot do statement! $DBI::errstr\n";  
   
=cut


}




sub create_MySQL_db { 


    use DADA::Config; 
	$DADA::Config::SETTINGS_DB_TYPE         = 'SQL'; 
	$DADA::Config::ARCHIVE_DB_TYPE          = 'SQL'; 
	$DADA::Config::SUBSCRIBER_DB_TYPE       = 'SQL'; 
	$DADA::Config::SESSIONS_DB_TYPE         = 'SQL'; 
	$DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'SQL';
  
   
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
    
    foreach(@statements){ 
    	my $settings_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{settings_table}; 
		my $subscribers_table       = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{subscriber_table}; 
		my $archives_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{archives_table}; 
		my $session_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{session_table};
		my $bounce_scores_table     = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{bounce_scores_table};
		my $profile_fields_table = $__Test_Config_Vars::TEST_SQL_PARAMS->{MySQL}->{profile_fields_table};
		
		$_ =~ s{CREATE TABLE dada_settings}{CREATE TABLE $settings_table}; 
		$_ =~ s{CREATE TABLE dada_subscribers}{CREATE TABLE $subscribers_table}; 
		$_ =~ s{CREATE TABLE dada_archives}{CREATE TABLE $archives_table}; 
		$_ =~ s{CREATE TABLE dada_sessions}{CREATE TABLE $session_table}; 
		$_ =~ s{CREATE TABLE dada_bounce_scores}{CREATE TABLE $bounce_scores_table};
		$_ =~ s{CREATE TABLE dada_profile_fields}{CREATE TABLE $profile_fields_table};
		
#
#		$_ =~ s{CREATE INDEX dada_settings}{CREATE INDEX $settings_table}g; 
#		$_ =~ s{CREATE INDEX dada_subscribers}{CREATE INDEX $subscribers_table}g; 
#		$_ =~ s{CREATE INDEX dada_archives}{CREATE INDEX $archives_table}g; 
#		$_ =~ s{CREATE INDEX dada_sessions}{CREATE INDEX $session_table}g;
		
		#?
		#$_ =~ s/dada_settings/$settings_table/g; 
		#$_ =~ s/dada_subscribers/$subscribers_table/g; 
		#$_ =~ s/dada_archives/$archives_table/g; 
		#$_ =~ s/dada_sessions/$session_table/g; 
						
		if(length($_) > 10){ 
	    	carp 'query: ' . $_; 
			my $sth = $dbh->prepare($_); 
	       	$sth->execute; 
	    }
    
    }
    
    
}

sub destroy_MySQL_db { 

  require DADA::App::DBIHandle;
    my $dbi_handle = DADA::App::DBIHandle->new; 

    my $dbh = $dbi_handle->dbh_obj;
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{subscriber_table})
            or carp "cannot do statement! $DBI::errstr\n";  

        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{archives_table})
                    or carp "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{settings_table})
                    or carp "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{session_table})
                    or carp "cannot do statement! $DBI::errstr\n";  

		$dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{bounce_scores_table})
                    or carp "cannot do statement! $DBI::errstr\n";

		$dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{profile_fields_table})
                    or carp "cannot do statement! $DBI::errstr\n";

		$dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{subscriber_profile_table})
                    or carp "cannot do statement! $DBI::errstr\n";
			
}





sub create_PostgreSQL_db { 


   use DADA::Config; 
	$DADA::Config::SETTINGS_DB_TYPE         = 'SQL'; 
	$DADA::Config::ARCHIVE_DB_TYPE          = 'SQL'; 
	$DADA::Config::SUBSCRIBER_DB_TYPE       = 'SQL'; 
	$DADA::Config::SESSIONS_DB_TYPE         = 'SQL'; 
	$DADA::Config::BOUNCE_SCORECARD_DB_TYPE = 'SQL';
    
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
    
	
    foreach(@statements){ 
    

		my $settings_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{settings_table}; 
		my $subscribers_table       = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{subscriber_table}; 
		my $archives_table          = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{archives_table}; 
		my $session_table           = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{session_table};
		my $bounce_scores_table     = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{bounce_scores_table};		
		my $profile_fields_table = $__Test_Config_Vars::TEST_SQL_PARAMS->{PostgreSQL}->{profile_fields_table};
				
		$_ =~ s{CREATE TABLE dada_settings}{CREATE TABLE $settings_table}; 
		$_ =~ s{CREATE TABLE dada_subscribers}{CREATE TABLE $subscribers_table}; 
		$_ =~ s{CREATE TABLE dada_archives}{CREATE TABLE $archives_table}; 
		$_ =~ s{CREATE TABLE dada_sessions}{CREATE TABLE $session_table}; 
		$_ =~ s{CREATE TABLE dada_bounce_scores}{CREATE TABLE $bounce_scores_table};
		$_ =~ s{CREATE TABLE dada_profile_fields}{CREATE TABLE $profile_fields_table};

    my $sth = $dbh->prepare($_); #  or croak $DBI::errstr; 
       $sth->execute or carp $DBI::errstr; 
    
    
    }
    
    
}

sub destroy_PostgreSQL_db { 

  require DADA::App::DBIHandle;
    my $dbi_handle = DADA::App::DBIHandle->new; 

    my $dbh = $dbi_handle->dbh_obj;
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{subscriber_table})
			or carp "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{archives_table})
			or carp "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{settings_table})
			or carp "cannot do statement! $DBI::errstr\n";  
        $dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{session_table})
			or carp "cannot do statement! $DBI::errstr\n";  
		$dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{bounce_scores_table})
        	or carp "cannot do statement! $DBI::errstr\n";
		$dbh->do('DROP TABLE ' . $DADA::Config::SQL_PARAMS{profile_fields_table})
        	or carp "cannot do statement! $DBI::errstr\n";

}




sub wipe_out { 
	
	if(-e './test_only_dada_files'){ 
		`rm -Rf ./test_only_dada_files`;
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


