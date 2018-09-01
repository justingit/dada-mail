package __Test_Config_Vars; 
use strict; 

require Exporter; 
use vars qw($TEST_SQL_PARAMS @EXPORT_OK @ISA);  

@ISA = qw(Exporter);
@EXPORT_OK = qw($TEST_SQL_PARAMS); 

my $shared_params = { 
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
	rate_limit_hits_table              => 'test_dada_rate_limit_hits',
	email_message_previews_table       => 'test_dada_email_message_previews', 
	privacy_policies_table             => 'test_dada_privacy_policies',
	consents_table                     => 'test_dada_consents',
	consent_activity_table             => 'test_dada_consent_activity',
};

$TEST_SQL_PARAMS = { 

	MySQL => { 
	
		test_enabled     => 0, 
	    database         => 'test',
	    dbserver         => 'localhost',
	    port             => '3306',     
	    dbtype           => 'mysql',   
	    user             => 'test',          
	    pass             => '',
		%{$shared_params},
	}, 

	PostgreSQL => { 
		test_enabled     => 0, 
		database         => 'dadademo_test',
	    dbserver         => 'localhost', 
	    port             => '5432',     
	    dbtype           => 'Pg',    
	    user             => 'test',          
	    pass             => 'test',
		%{$shared_params},

	}, 

	SQLite => {
		test_enabled     		=> 1, 
	    dbtype    		        => 'SQLite',  
		database         		=> 'test_dada',
		%{$shared_params},
	},

};


1;
