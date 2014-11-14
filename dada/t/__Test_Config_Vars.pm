package __Test_Config_Vars; 
use strict; 

require Exporter; 
use vars qw($TEST_SQL_PARAMS @EXPORT_OK @ISA);  

@ISA = qw(Exporter);
@EXPORT_OK = qw($TEST_SQL_PARAMS); 

$TEST_SQL_PARAMS = { 

	MySQL => { 
	
		test_enabled     => 1, 
	    database         => 'test',
	    dbserver         => 'localhost', # may just be, "localhost"   	   
	    port             => '3306',      # mysql: 3306, Postgres: 5432   	   
	    dbtype           => 'mysql',     # 'mysql' for 'MySQL', 'Pg' for 'PostgreSQL', and 'SQLite' for SQLite  
	    user             => 'test',          
	    pass             => '',
    
	    subscriber_table 				   => 'test_dada_subscribers',
		profile_table                      => 'test_dada_profiles', 
		profile_fields_table 	           => 'test_dada_profile_fields', 
		profile_fields_attributes_table    => 'test_dada_profile_fields_attributes',
		profile_settings_table             => 'test_dada_profile_settings', 
	    archives_table   				   => 'test_dada_archives', 
	    settings_table   				   => 'test_dada_settings', 
	    session_table    				   => 'test_dada_sessions',
		bounce_scores_table 			   => 'test_dada_bounce_scores',
		clickthrough_urls_table            => 'test_dada_clickthrough_urls', 
		clickthrough_url_log_table         => 'test_dada_clickthrough_url_log', 		
		mass_mailing_event_log_table       => 'test_dada_mass_mailing_event_log', 
		password_protect_directories_table => 'test_dada_password_protect_directories', 
		confirmation_tokens_table          => 'test_dada_confirmation_tokens',
		message_drafts_table               => 'test_dada_message_drafts',
		
		
	}, 

	PostgreSQL => { 
		test_enabled     => 1, 
		database         => 'dadademo_test',
	    dbserver         => 'localhost', # may just be, "localhost"   	   
	    port             => '5432',      # mysql: 3306, Postgres: 5432   	   
	    dbtype           => 'Pg',     # 'mysql' for 'MySQL', 'Pg' for 'PostgreSQL', and 'SQLite' for SQLite  
	    user             => 'test',          
	    pass             => 'test',
    
	    subscriber_table 		=> 'test_dada_subscribers',
		profile_table           => 'test_dada_profiles', 
		profile_fields_table 	=> 'test_dada_profile_fields', 
		profile_fields_attributes_table => 'test_dada_profile_fields_attributes',
		profile_settings_table             => 'test_dada_profile_settings', 
	    archives_table   		=> 'test_dada_archives', 
	    settings_table   		=> 'test_dada_settings', 
	    session_table    		=> 'test_dada_sessions',
		bounce_scores_table 	=> 'test_dada_bounce_scores',
		clickthrough_urls_table         => 'test_dada_clickthrough_urls', 
		clickthrough_url_log_table       => 'test_dada_clickthrough_url_log', 		

		mass_mailing_event_log_table    => 'test_dada_mass_mailing_event_log', 
		password_protect_directories_table    => 'test_dada_password_protect_directories', 
		confirmation_tokens_table             => 'test_dada_confirmation_tokens',
		message_drafts_table               => 'test_dada_message_drafts',
		


	}, 

	SQLite => {
		test_enabled     		=> 1, 
	    dbtype    		        => 'SQLite',     # 'mysql' for 'MySQL', 'Pg' for 'PostgreSQL', and 'SQLite' for SQLite  
		database         		=> 'test_dada',

	    subscriber_table 		        => 'test_dada_subscribers',
		profile_table                   => 'test_dada_profiles', 
		profile_fields_table 	        => 'test_dada_profile_fields', 
		profile_fields_attributes_table => 'test_dada_profile_fields_attributes',
		profile_settings_table          => 'test_dada_profile_settings', 
	    archives_table   		        => 'test_dada_archives', 
	    settings_table   		        => 'test_dada_settings', 
	    session_table    		        => 'test_dada_sessions',
		bounce_scores_table 	        => 'test_dada_bounce_scores', 
		clickthrough_urls_table         => 'test_dada_clickthrough_urls', 
		clickthrough_url_log_table      => 'test_dada_clickthrough_url_log', 		
		mass_mailing_event_log_table    => 'test_dada_mass_mailing_event_log', 
		password_protect_directories_table    => 'test_dada_password_protect_directories', 
		confirmation_tokens_table          => 'test_dada_confirmation_tokens',
		message_drafts_table               => 'test_dada_message_drafts',
				
	},
	

};


1;
