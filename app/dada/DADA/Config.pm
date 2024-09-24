package DADA::Config;
use v5.10.1;
#----------------------------------------------------------------------------#
# This file holds default values for the global configuration variables 
# in Dada Mail. See:
#
#          https://dadamailproject.com/d/global_variables.pod.html
# 
# for more information. 
#
#----------------------------------------------------------------------------#

require Exporter;
our @ISA = qw(Exporter);

use vars qw($PROGRAM_ROOT_PASSWORD $MAILPROG $DIR $FILES $PROGRAM_URL $S_PROGRAM_URL $RUNNING_UNDER $ADDITIONAL_PERLLIBS $PLUGIN_CONFIGS $PLUGINS_ENABLED $MAIL_SETTINGS $MASS_MAIL_SETTINGS $LIST_TYPES $AMAZON_SES_OPTIONS $MAILGUN_OPTIONS $WWW_ENGINE_OPTIONS $FIRST_SUB $SEC_SUB @C $SALT $ENABLE_CSRF_PROTECTION $FILE_CHMOD $DIR_CHMOD $GIVE_PROPS_IN_EMAIL $GIVE_PROPS_IN_HTML $GIVE_PROPS_IN_ADMIN $GIVE_PROPS_IN_SUBSCRIBE_FORM $PROGRAM_IMG_FILENAME $SUBSCRIBED_MESSAGE $ARCHIVES $TEMPLATES $ALTERNATIVE_HTML_TEMPLATE_PATH $TMP $LOGS $BACKUPS %BACKUP_HISTORY  $ENFORCE_CLOSED_LOOP_OPT_IN $SUPPORT_FILES $WYSIWYG_EDITOR_OPTIONS $FILE_BROWSER_OPTIONS $SCHEDULED_JOBS_OPTIONS $SCREEN_CACHE $DATA_CACHE $GLOBAL_BLACK_LIST $GLOBAL_UNSUBSCRIBE $HIDDEN_SUBSCRIBER_FIELDS_PREFIX @PING_URLS $CONFIRMATION_TOKEN_OPTIONS $SUBSCRIPTION_SUCCESSFUL_COPY $PIN_WORD $PIN_NUM $TEXT_CSV_PARAMS $ALLOW_ROOT_LOGIN  @CHARSETS @CONTENT_TYPES %LIST_SETUP_DEFAULTS %LIST_SETUP_INCLUDE %LIST_SETUP_OVERRIDES @LIST_SETUP_DONT_CLONE %PRIORITIES $ATTACHMENT_TEMPFILE $MAIL_VERP_SEPARATOR %MIME_TYPES $DEFAULT_MIME_TYPE $MIME_PARANOID $MIME_HUSH $MIME_OPTIMIZE $MIME_TOOLS_PARAMS $NPH $PROGRAM_USAGE_LOG $ROOT_PASS_IS_ENCRYPTED $SHOW_ADMIN_LINK $LIST_PASSWORD_RESET $ADMIN_FLAVOR_NAME $SIGN_IN_FLAVOR_NAME $DISABLE_OUTSIDE_LOGINS %LOG $DEBUG_TRACE %CPAN_DEBUG_SETTINGS $ADMIN_MENU $EMAIL_CASE @EMAIL_EXCEPTIONS $LIST_IN_ORDER $ADMIN_TEMPLATE $USER_TEMPLATE $BACKEND_DB_TYPE $SUBSCRIBER_DB_TYPE $ARCHIVE_DB_TYPE $SETTINGS_DB_TYPE $SESSION_DB_TYPE $BOUNCE_SCORECARD_DB_TYPE $CLICKTHROUGH_DB_TYPE %SQL_PARAMS $DBI_PARAMS $PROFILE_OPTIONS $PII_OPTIONS $GLOBAL_API_OPTIONS $PLUGIN_RUNMODES $PROGRAM_ERROR_LOG $SHOW_HELP_LINKS $HELP_LINKS_URL $VER $VERSION  $PROGRAM_NAME @CONTENT_TRANSFER_ENCODINGS $CONFIG_FILE $PROGRAM_CONFIG_FILE_DIR $OS $DEFAULT_ADMIN_SCREEN $DEFAULT_LOGOUT_SCREEN $DEFAULT_SCREEN $HTML_CHARSET $SEND_ARCHIVED_MESSAGE $CAPTCHA_TYPE $GOOGLE_MAPS_PARAMS $RECAPTCHA_PARAMS $RECAPTHCA_MAILHIDE_PARAMS  $LOGIN_COOKIE_NAME %COOKIE_PARAMS $CP_SESSION_PARAMS $GOOGLE_MAPS_API_PARAMS $RATE_LIMITING $HTML_TEXTTOHTML_OPTIONS $HTML_SCRUBBER_OPTIONS $TEMPLATE_SETTINGS $TEMPLATE_OPTIONS $LOGIN_WIDGET $NULL_DEVICE $LIST_QUOTA $SUBSCRIPTION_QUOTA $MAILOUT_AT_ONCE_LIMIT $MAILOUT_STALE_AFTER %EMAIL_HEADERS @EMAIL_HEADERS_ORDER $LIST_HEADERS);

@EXPORT_OK = qw($PROGRAM_ROOT_PASSWORD $MAILPROG $DIR $FILES $PROGRAM_URL $S_PROGRAM_URL $RUNNING_UNDER $ADDITIONAL_PERLLIBS $PLUGIN_CONFIGS $PLUGINS_ENABLED $MAIL_SETTINGS $MASS_MAIL_SETTINGS $LIST_TYPES $AMAZON_SES_OPTIONS $MAILGUN_OPTIONS $WWW_ENGINE_OPTIONS $FIRST_SUB $SEC_SUB @C $SALT $ENABLE_CSRF_PROTECTION $FILE_CHMOD $DIR_CHMOD $GIVE_PROPS_IN_EMAIL $GIVE_PROPS_IN_HTML $GIVE_PROPS_IN_ADMIN $GIVE_PROPS_IN_SUBSCRIBE_FORM $PROGRAM_IMG_FILENAME $SUBSCRIBED_MESSAGE     $ARCHIVES $TEMPLATES $ALTERNATIVE_HTML_TEMPLATE_PATH $TMP $LOGS $BACKUPS %BACKUP_HISTORY  $ENFORCE_CLOSED_LOOP_OPT_IN $SUPPORT_FILES $WYSIWYG_EDITOR_OPTIONS $FILE_BROWSER_OPTIONS $SCHEDULED_JOBS_OPTIONS $SCREEN_CACHE $DATA_CACHE $GLOBAL_BLACK_LIST $GLOBAL_UNSUBSCRIBE $HIDDEN_SUBSCRIBER_FIELDS_PREFIX @PING_URLS $CONFIRMATION_TOKEN_OPTIONS $SUBSCRIPTION_SUCCESSFUL_COPY $PIN_WORD $PIN_NUM $TEXT_CSV_PARAMS $ALLOW_ROOT_LOGIN  @CHARSETS @CONTENT_TYPES %LIST_SETUP_DEFAULTS %LIST_SETUP_INCLUDE %LIST_SETUP_OVERRIDES @LIST_SETUP_DONT_CLONE %PRIORITIES $ATTACHMENT_TEMPFILE $MAIL_VERP_SEPARATOR %MIME_TYPES $DEFAULT_MIME_TYPE $MIME_PARANOID $MIME_HUSH $MIME_OPTIMIZE $MIME_TOOLS_PARAMS $NPH $PROGRAM_USAGE_LOG $ROOT_PASS_IS_ENCRYPTED $SHOW_ADMIN_LINK $LIST_PASSWORD_RESET $ADMIN_FLAVOR_NAME $SIGN_IN_FLAVOR_NAME $DISABLE_OUTSIDE_LOGINS %LOG $DEBUG_TRACE %CPAN_DEBUG_SETTINGS $ADMIN_MENU $EMAIL_CASE @EMAIL_EXCEPTIONS $LIST_IN_ORDER $ADMIN_TEMPLATE $USER_TEMPLATE $BACKEND_DB_TYPE $SUBSCRIBER_DB_TYPE $ARCHIVE_DB_TYPE $SETTINGS_DB_TYPE $SESSION_DB_TYPE $BOUNCE_SCORECARD_DB_TYPE $CLICKTHROUGH_DB_TYPE %SQL_PARAMS $DBI_PARAMS $PROFILE_OPTIONS $PII_OPTIONS $GLOBAL_API_OPTIONS $PLUGIN_RUNMODES $PROGRAM_ERROR_LOG $SHOW_HELP_LINKS $HELP_LINKS_URL $VER $VERSION  $PROGRAM_NAME @CONTENT_TRANSFER_ENCODINGS $CONFIG_FILE $PROGRAM_CONFIG_FILE_DIR $OS $DEFAULT_ADMIN_SCREEN $DEFAULT_LOGOUT_SCREEN $DEFAULT_SCREEN $HTML_CHARSET $SEND_ARCHIVED_MESSAGE $CAPTCHA_TYPE $GOOGLE_MAPS_PARAMS $RECAPTCHA_PARAMS $RECAPTHCA_MAILHIDE_PARAMS  $LOGIN_COOKIE_NAME %COOKIE_PARAMS $CP_SESSION_PARAMS GOOGLE_MAPS_API_PARAMS $RATE_LIMITING $HTML_TEXTTOHTML_OPTIONS $HTML_SCRUBBER_OPTIONS $TEMPLATE_SETTINGS $TEMPLATE_OPTIONS $LOGIN_WIDGET $NULL_DEVICE $LIST_QUOTA $SUBSCRIPTION_QUOTA $MAILOUT_AT_ONCE_LIMIT $MAILOUT_STALE_AFTER %EMAIL_HEADERS @EMAIL_HEADERS_ORDER $LIST_HEADERS);

#
#
#
#

$PROGRAM_CONFIG_FILE_DIR = '/home/maximilian/dada/.dada_files/.configs';

#
#
#
#
#

#--------------------------------#
# Leave the below line, alone!
_config_import(); #  Leave alone!
# Leave the above line, alone!
#--------------------------------#

BEGIN {




#
#
#
#
#

$PROGRAM_ERROR_LOG = '/home/maximilian/dada/.dada_files/.logs/errors.txt';

#
#
#
#
#

    # Keep this next bit as-is; it's just opening the error file for writing.
    if (
		$PROGRAM_ERROR_LOG 
		&& (!$ENV{NO_DADA_MAIL_CONFIG_IMPORT})
	) {
        open( STDERR, ">>$PROGRAM_ERROR_LOG" )
          || warn
"$PROGRAM_NAME Error: Cannot redirect STDERR, it's possible that Dada Mail does not have write permissions to this file ($PROGRAM_ERROR_LOG) or it doesn't exist! If Dada Mail cannot make this file for you, create it yourself and give it enough permissions so it may write to it: $!";
    }

    # chmod(0777, $PROGRAM_ERROR_LOG);
}




$PROGRAM_ROOT_PASSWORD  //= 'root_password';
$ROOT_PASS_IS_ENCRYPTED //= 0;




($DIR) //= $PROGRAM_CONFIG_FILE_DIR =~ m/^(.*?)\/\.configs$/;
$ARCHIVES          //= $DIR . '/.archives';
$BACKUPS           //= $DIR . '/.backups';
$FILES             //= $DIR . '/.lists';
$LOGS              //= $DIR . '/.logs';
$PROGRAM_USAGE_LOG //= $LOGS . '/dada.txt';
$TEMPLATES         //= $DIR . '/.templates';
$TMP               //= $DIR . '/.tmp';




$PROGRAM_URL   //= 'https://www.changetoyoursite.com/cgi-bin/dada/mail.cgi';
$S_PROGRAM_URL //= $PROGRAM_URL;

$RUNNING_UNDER //= 'CGI'; 
$ADDITIONAL_PERLLIBS //= [qw()];


$SUPPORT_FILES //= {
    dir => '',
    url => '',
};

$WYSIWYG_EDITOR_OPTIONS //= {
    ckeditor => {
        enabled => 0,
        url     => '',
    },
    tiny_mce => {
        enabled => 0,
        url     => '',
    },
};

$FILE_BROWSER_OPTIONS //= {
	rich_filemanager  => { 
		enabled      => 0,
		url          => '',
		upload_dir   => '',
		upload_url   => '',
		connector    => 'php', 
		session_name => 'PHPSESSID', 
		session_dir  => '',
	},
	core5_filemanager  => { 
		enabled      => 0, 
		url          => '', 
		upload_dir   => '', 
		upload_url   => '',
		connector    => '', 
	},
	fileselect => {
		enabled => 0,
		upload_dir => '',
	},
	none => { 
		enabled      => 1,
	}
};


$SCHEDULED_JOBS_OPTIONS //= { 
#   enabled               => 1, 
   scheduled_jobs_flavor => '_schedules', 
   log                   => 0, 
   run_at_teardown       => 1, 
   
};



$BACKEND_DB_TYPE          //= 'SQL';
$SUBSCRIBER_DB_TYPE       //= 'SQL';
$ARCHIVE_DB_TYPE          //= 'SQL';
$SETTINGS_DB_TYPE         //= 'SQL';
$SESSION_DB_TYPE          = undef; #noop
$BOUNCE_SCORECARD_DB_TYPE //= 'SQL';
$CLICKTHROUGH_DB_TYPE     //= 'SQL';

%SQL_PARAMS = (

    # May just be, "localhost"
    dbserver => 'localhost',

    database => '',

    # MySQL:      3306
    # PostgreSQL: 5432
    port => '3306',

    # MySQL:      mysql
    # PostgreSQL: Pg
    # SQLite:     SQLite
    dbtype => 'mysql',

    user => '',
    pass => '',

) unless keys %SQL_PARAMS;




$DBI_PARAMS //= {

    InactiveDestroy      => 0,
    pg_server_prepare    => 0,
    mysql_auto_reconnect => 1,

# this only works if you have autocommit => 1 ? (or is it, AutoCommit)
# This would probably be fine, since we don't commit, anyways, but
# will be problematic, if we ever put in transaction support. Hmm...
# But wait, there's more :
#TRANSACTION SUPPORT ^
#
#Beginning with DBD::mysql 2.0416, transactions are supported. The transaction support works as follows:
#
#   * By default AutoCommit mode is on, following the DBI specifications.

    dada_connection_method => 'connect_cached',

    # UTF-8

    # MySQL specific attribute:
    #
    mysql_enable_utf8 => 1,

    #
    # You will also need to ensure that your database / table / column is
    # configured to use UTF8. See Chapter 10 of the mysql manual for details.

    # DBD::Pg specific attribute. If true, then the utf8 flag will be turned on
    # for returned character data (if the data is valid UTF-8). For details
    # about the utf8 flag, see the Encode module. This attribute is only
    # relevant under perl 5.8 and later.
    #
    pg_enable_utf8 => 1,

    # SQLite
    # If set to a true value, DBD::SQLite will turn the UTF-8 flag on for all
    # text strings coming out of the database (this feature is currently
    # disabled for perl < 5.8.5). For more details on the UTF-8 flag see
    # perlunicode. The default is for the UTF-8 flag to be turned off.
    #
    sqlite_unicode => 1,
	
	AutoInactiveDestroy => 1, 

};




$PROFILE_OPTIONS //= {

    enabled                         => 1,
    profile_email                   => '',
    enable_captcha                  => 1,
    update_email_options => {
        send_notification_to_profile_email => 0,
        subscription_check_skip            => 'auto',
    },

    gravatar_options => {
        enable_gravators     => 1,
        default_gravatar_url => undef,
    },

    features => {
        register                   => 0,
        password_reset             => 1,
        profile_fields             => 0,
        mailing_list_subscriptions => 1,
        protected_directories      => 0,
        update_email_address       => 0,
        change_password            => 1,
        delete_profile             => 0,
    },
    cookie_params => {
        -name     => 'dada_profile',
        -path     => '/',
        -expires  => '+1y',
		-SameSite => 'Lax',
    },

};

$PII_OPTIONS //= { 
	allow_logging_emails_in_analytics => 0, 
	ip_address_logging_style          => 'anonymized', 
};

$GLOBAL_API_OPTIONS //= { 
	enabled     => 0, 
	public_key  => undef, 
	private_key => undef, 
};


$PLUGIN_RUNMODES //= { 
    boilerplate_plugin           => {run => \&boilerplate_plugin::run},
    tracker                      => {run => \&tracker::run}, 
    bounce_handler               => {run       => \&bounce_handler::run, 
	                                 sched_run => \&bounce_handler::scheduled_task},
    bridge                       => {run       => \&bridge::run,         
	                                 sched_run => \&bridge::scheduled_task},
    change_root_password         => {run => \&change_root_password::run}, 
    change_list_shortname        => {run => \&change_list_shortname::run},  
    password_protect_directories => {run       => \&password_protect_directories::run,
	                                 sched_run => \&password_protect_directories::scheduled_task},   
    log_viewer                   => {run => \&log_viewer::run},
    screen_cache                 => {run => \&screen_cache::run},
    global_config                => {run => \&global_config::run}, 
    view_list_settings           => {run => \&view_list_settings::run},
	usage_log_to_consent_activity =>  {run => \&usage_log_to_consent_activity::run},
	
};

$PLUGINS_ENABLED //= {
    boilerplate_plugin            => 0,
    tracker                       => 0,
    bounce_handler                => 0,
    bridge                        => 0,
    change_root_password          => 0,
    change_list_shortname         => 0,
    password_protect_directories  => 0,
    log_viewer                    => 0,
    screen_cache                  => 0,
    global_config                 => 0,
    view_list_settings            => 0,
    usage_log_to_consent_activity => 0,
	
};

$PLUGIN_CONFIGS //= { 

	Bounce_Handler => {
		Server                      => undef,
		Address                     => undef,
		Username                    => undef,
		Password                    => undef,
		Port                        => undef,
		USESSL                      => undef,
		starttls                    => undef,
		SSL_verify_mode             => undef,
		AUTH_MODE                   => undef,
		Plugin_Name                 => undef,
		Plugin_URL                  => undef,
		Allow_Manual_Run            => undef,
		Manual_Run_Passcode         => undef,
		Enable_POP3_File_Locking    => undef, 
		Log                         => undef,
		MessagesAtOnce              => undef,
		Max_Size_Of_Any_Message     => undef,
		Rules                       => undef,

	},
	Bridge => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Allow_Manual_Run                    => undef,
		Manual_Run_Passcode                 => undef,
		MessagesAtOnce                      => undef,
		Room_For_One_More_Check             => undef,
		Enable_POP3_File_Locking            => undef,
		Check_List_Owner_Return_Path_Header => undef,
		Check_Multiple_Return_Path_Headers  => undef,

    },

	Tracker => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Geo_IP_Db                           => undef,
		
	},

	Mailing_Monitor => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Allow_Manual_Run                    => undef,
		Manual_Run_Passcode                 => undef,

	},

    log_viewer => {	

		Plugin_URL                          => undef,
		tail_command                        => undef,

	},

	default_mass_mailing_messages => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,

	},

	password_protect_directories => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Allow_Manual_Run                    => undef,
		Manual_Run_Passcode                 => undef,
		Base_Absolute_Path                  => undef, 
		Base_URL                            => undef, 

	},

    blog_index => {

		Default_List                        => undef,
		Entries                             => undef,
		Style                               => undef,
		Allow_QS_Overrides                  => undef,

	}, 

	multiple_subscribe => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,

	},

	Global_Config => {

		Plugin_Name                         => undef,

	},

};



$MAILPROG           //= '/usr/sbin/sendmail';
$MAIL_SETTINGS      //= "|$MAILPROG -t";
$MASS_MAIL_SETTINGS //= "|$MAILPROG -t";


$LIST_TYPES //= {
	
    list                => 'Subscribers',
    black_list          => 'Black Listed',
    white_list          => 'White Listed',     
    
	authorized_senders  => 'Authorized Senders',
    moderators          => 'Moderators',
	requires_moderation => 'Requires Moderation',
	
	
	sub_request_list    => 'Subscription Requests',
    unsub_request_list  => 'Unsubscription Requests',
    
	bounced_list        => 'Bouncing Addresses',
	ignore_bounces_list => 'Ignore Bounces',
	
	
	sub_confirm_list    => 'Unconfirmed Subscribers',
	unsub_confirm_list  => 'Unconfirmed Removals',
	
	invite_list         => 'Invitees',
	invited_list		=> 'Invited',
	
	test_list           => 'Testers',
	
};

$AMAZON_SES_OPTIONS //= { 
    AWS_endpoint                     => undef,
	AWSAccessKeyId                   => undef,
	AWSSecretKey                     => undef,
	Allowed_Sending_Quota_Percentage => 90,
};

$MAILGUN_OPTIONS //= { 
	region  => 'us',
	api_key => undef, 
	domain  => undef,
};


$MANDRILL_OPTIONS = undef;

$WWW_ENGINE_OPTIONS //= {
	engine          => 'LWP', # curl
	user_agent      =>  'Mozilla/5.0 (compatible; ' . $PROGRAM_NAME . ')',  # 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:94.0) Gecko/20100101 Firefox/94.0'
	verify_hostname => 1,
}; 




$SHOW_ADMIN_LINK        //= 1;
$LIST_PASSWORD_RESET    //= 1; 
$ADMIN_FLAVOR_NAME      //= 'admin';
$SIGN_IN_FLAVOR_NAME    //= 'sign_in';
$DEFAULT_SCREEN         //= '';
$DEFAULT_ADMIN_SCREEN   //= $S_PROGRAM_URL . '?flavor=drafts';
$DEFAULT_LOGOUT_SCREEN  //= $S_PROGRAM_URL . '?flavor=' . $ADMIN_FLAVOR_NAME . '&logged_out=1';
$DISABLE_OUTSIDE_LOGINS //= 1;
$LOGIN_WIDGET           //= 'popup_menu';
$ALLOW_ROOT_LOGIN       //= 1;
  
$LOGIN_COOKIE_NAME //= 'dadalogin';

%COOKIE_PARAMS = (
	-path     => '/',
	-expires  => '+7d',
	-samesite => 'Lax',
) unless keys %COOKIE_PARAMS; 

$CP_SESSION_PARAMS //= { 
	check_matching_ip_addresses => 1, 
};

$RATE_LIMITING //= { 
	enabled   => 1, 
	max_hits  => 10, 
	timeframe => 5, 
};

$GOOGLE_MAPS_API_PARAMS //= {
	api_key =>  '',
};



$CAPTCHA_TYPE = undef; # noop #

$RECAPTCHA_PARAMS //= {

	recaptcha_type    =>  'v2',
	on_subscribe_form =>  1,
	
	v2 => {
	    public_key        =>  undef,
	    private_key       =>  undef,
	}, 
	v3 => {
	    public_key        =>  undef,
	    private_key       =>  undef,
		hide_badge        =>  1,
		
	},
};


# NOOP
$RECAPTHCA_MAILHIDE_PARAMS //= {};



$SHOW_HELP_LINKS //= 1;
$HELP_LINKS_URL  //= 'https://dadamailproject.com/pro_dada/11.0.0';
$NPH //= 0;





%LOG = (
    subscriptions        => 0,
    mailings             => 0,
    mass_mailings        => 1,
    mass_mailing_batches => 1,
    logins               => 1,
    list_lives           => 1,

) unless keys %LOG;




$DEBUG_TRACE //= {

    DADA_App_BounceHandler             => 0,
    DADA_App_DBIHandle                 => 0,
    DADA_App_Digests                   => 0, 
    DADA_App_FormatMessages            => 0,
	DADA_App_HTMLtoMIMEMessage         => 0, 
    DADA_App_Subscriptions             => 0,
    DADA_App_WebServices               => 0,
	DADA_Template_HTML                 => 0,
	DADA_Logging_Clickthrough          => 0,
    DADA_Mail_MailOut                  => 0,
    DADA_Mail_Send                     => 0,
    DADA_MailingList                   => 0,
	DADA_MailingList_Archives          => 0, 
	DADA_MailingList_MessageDrafts     => 0, 
	DADA_MailingList_Settings          => 0,
    DADA_Profile                       => 0,
    DADA_Profile_Fields                => 0,
    DADA_Profile_Session               => 0,

};

%CPAN_DEBUG_SETTINGS = (

    # DBI, handles all SQL database calls.
    # More Information:
    # https://search.cpan.org/~timb/DBI/DBI.pm#TRACING
    # As noted in these docs, you can set the trace level as far 15

    DBI => 0,

    # HTML::Template, used for generating HTML screens
    # More information:
    # https://search.cpan.org/~samtregar/HTML-Template/Template.pm

    HTML_TEMPLATE => 0,

    #  Net::POP3, used for checking awaiting messages on a POP3 Server
    #  More Information:
    #  https://search.cpan.org/~gbarr/libnet/Net/POP3.pm
       NET_POP3 => 0,

    # Net::SMTP, used for sending messages via SMTP:
    # more information:
    # https://search.cpan.org/~gbarr/libnet/Net/SMTP.pm

    NET_SMTP => 0,

) unless keys %CPAN_DEBUG_SETTINGS;

$ADMIN_TEMPLATE                 = undef; #noop
$USER_TEMPLATE                  = undef; #noop
$ALTERNATIVE_HTML_TEMPLATE_PATH //= undef;

$TEMPLATE_SETTINGS              //= {
    engine                           => 'Best',
};

$TEMPLATE_OPTIONS //= {
    user => { 
            enabled        => 0,
            mode           => undef,
            manual_options => { 
                template_url => undef,
            },
            magic_options  => { 
                template_url          => undef, 
                add_base_href         => 0,
                base_href_url         => undef, 
                replace_content_from  => undef,
                replace_id            => undef, 
                replace_class         => undef, 
                add_app_css           => 0,
                add_custom_css        => 0,
                custom_css_url        => undef, 
                include_jquery_lib    => 1,
                include_app_user_js   => 1,
                head_content_added_by => 'push', 
            }
    }, 
};

# Mostly a noop these days... 
%BACKUP_HISTORY = (
    settings  => 3,
    archives  => 3,
    schedules => 3,
) unless keys %BACKUP_HISTORY;


$ENFORCE_CLOSED_LOOP_OPT_IN             //= 0;
$GLOBAL_BLACK_LIST                      //= 0;
$GLOBAL_UNSUBSCRIBE                     //= 0;
$HIDDEN_SUBSCRIBER_FIELDS_PREFIX        //= '_';


$SCREEN_CACHE                           //= 1;
$DATA_CACHE                             //= 1;

@PING_URLS = qw(
  https://rpc.pingomatic.com/
) unless scalar @PING_URLS;


$CONFIRMATION_TOKEN_OPTIONS //= { 
	expires => 60,
};


# If you do put the $ADMIN_MENU variable in the outside config file,
# make sure to also! put the below line (uncommented):
#
#  $S_PROGRAM_URL = $PROGRAM_URL
#
# Before the $ADMIN_URL variable, as well as the below 5 lines of code:

$S_PROGRAM_URL = $PROGRAM_URL;
my $EXT_URL = $S_PROGRAM_URL;
   $EXT_URL =~ s/\/(\w+)\.(cgi|pl)$/\//;
   $EXT_URL .= 'extensions';
   
$ADMIN_MENU //= [

{-Title      => 'Mass Mailing',
 -Activated  => 1,
 -Submenu    => [
				{
				-Title     => 'All Drafts/Stationery/Schedules',
				-Title_URL => "$S_PROGRAM_URL?flavor=drafts",
				-Function  => 'drafts',
				-Activated => 1,
				},
			
				{ 
				-Title      => '+ New Draft Message',
				-Title_URL  => "$S_PROGRAM_URL?flavor=send_email&draft_role=draft",
				-Function   => 'send_email',
				-Activated  => 1,
				},

				{
				-Title      => 'Monitor',
				-Title_URL  => "$S_PROGRAM_URL?flavor=sending_monitor",
				-Function   => 'sending_monitor',
				-Activated  => 1,
				},

				{
				-Title     => 'Options',
				-Title_URL => "$S_PROGRAM_URL?flavor=mass_mailing_options",
				-Function  => 'mass_mailing_options',
				-Activated => 1,
				},
		]
},

{-Title      => 'Mailing List',
 -Activated  => 1,
 -Submenu    => [
				{
				-Title      => 'List Information',
				-Title_URL  => "$S_PROGRAM_URL?flavor=change_info",
				-Function   => 'change_info',
				-Activated  => 1,
				},
				
				{
				-Title      => 'Privacy Policy',
				-Title_URL  => "$S_PROGRAM_URL?flavor=manage_privacy_policy",
				-Function   => 'manage_privacy_policy',
				-Activated  => 0,
				},
				
				{
				-Title      => 'List Consents',
				-Title_URL  => "$S_PROGRAM_URL?flavor=manage_list_consent",
				-Function   => 'manage_list_consent',
				-Activated  => 0,
				},

				{
				-Title      => 'List Password',
				-Title_URL  => "$S_PROGRAM_URL?flavor=change_password",
				-Function   => 'change_password',
				-Activated  => 1,
				},

				{
				-Title      => 'Options',
				-Title_URL  => "$S_PROGRAM_URL?flavor=list_options",
				-Function   => 'list_options',
				-Activated  => 1,
				},
				
			    {
                       -Title     => 'Web Services API',
                       -Title_URL => "$S_PROGRAM_URL?flavor=web_services",
                       -Function  => 'web_services',
                       -Activated => 1,
                   },
            
				{
				-Title      => 'Delete This Mailing List',
				-Title_URL  => "$S_PROGRAM_URL?flavor=delete_list",
				-Function   => 'delete_list',
				-Activated  => 0,
				},
		]
},

{-Title      => 'Membership',
 -Activated  => 1,
 -Submenu    => [
				{
				-Title      => 'View',
				-Title_URL  => "$S_PROGRAM_URL?flavor=view_list",
				-Function   => 'view_list',
				-Activated  => 1,
				},
				
				{
				-Title      => 'Recent Activity',
				-Title_URL  => "$S_PROGRAM_URL?flavor=list_activity",
				-Function   => 'list_activity',
				-Activated  => 1,
				},

				{
				-Title      => 'Invite<!-- tmpl_var LT_CHAR -->!-- tmpl_if list_settings.enable_mass_subscribe --<!-- tmpl_var GT_CHAR -->/Subscribe<!-- tmpl_var LT_CHAR -->!-- /tmpl_if --<!-- tmpl_var GT_CHAR -->/Add',
				-Title_URL  => "$S_PROGRAM_URL?flavor=add",
				-Function   => 'add',
				-Activated  => 1,
				},

				{
				-Title      => 'Remove',
				-Title_URL  => "$S_PROGRAM_URL?flavor=delete_email",
				-Function   => 'delete_email',
				-Activated  => 1,
				},

				{
				-Title      => 'Options', 
				-Title_URL  =>  "$S_PROGRAM_URL?flavor=subscription_options",
				-Function   => 'subscription_options',
				-Activated  => 0,
				},
		]
},

{
-Title      => 'Sending',
-Activated  => 1,
-Submenu    => [
			
				{
				-Title      => 'Options',
				-Title_URL  => "$S_PROGRAM_URL?flavor=mail_sending_options",
				-Function   => 'mail_sending_options',
				-Activated  => 1,
				},

				{
				-Title      => 'Advanced Options',
				-Title_URL  => "$S_PROGRAM_URL?flavor=mail_sending_advanced_options",
				-Function   => 'mail_sending_advanced_options',
				-Activated  => 1,
				},
				{
				-Title      => 'Mass Mailing Options',
				-Title_URL  => "$S_PROGRAM_URL?flavor=mailing_sending_mass_mailing_options",
				-Function   => 'mailing_sending_mass_mailing_options',
				-Activated  => 1,
				},
		]
},

{-Title     => 'Archives',
 -Activated => 1,
 -Submenu   => [
				{
				-Title      => 'View',
				-Title_URL  => "$S_PROGRAM_URL?flavor=view_archive",
				-Function   => 'view_archive',
				-Activated  => 1,
				},

				{
				-Title      => 'Options',
				-Title_URL  => "$S_PROGRAM_URL?flavor=archive_options",
				-Function   => 'archive_options',
				-Activated  => 1,
				},
				
				{
				-Title      => 'Advanced Options',
				-Title_URL  => "$S_PROGRAM_URL?flavor=adv_archive_options",
				-Function   => 'adv_archive_options',
				-Activated  => 1,
				},
		]
},


{-Title      => 'Appearance',
 -Activated  => 1,
 -Submenu    => [
				{
				-Title      => 'Your Mailing List Template',
				-Title_URL  => "$S_PROGRAM_URL?flavor=edit_template",
				-Function   => 'edit_template',
				-Activated  => 1,
				},

				{
				-Title      => 'Email Themes',
				-Title_URL  => "$S_PROGRAM_URL?flavor=email_themes",
				-Function   => 'email_themes',
				-Activated  => 1,
				},

				{
				-Title      => 'Custom Mass Mailing Layout',
				-Title_URL  => "$S_PROGRAM_URL?flavor=edit_type",
				-Function   => 'edit_type',
				-Activated  => 1,
				},
				
				{
				-Title      => 'HTML Screen Templates',
				-Title_URL  => "$S_PROGRAM_URL?flavor=edit_html_type",
				-Function   => 'edit_html_type',
				-Activated  => 1,
				},

				{
				-Title      => 'Subscription Form HTML',
				-Title_URL  => "$S_PROGRAM_URL?flavor=html_code",
				-Function   => 'html_code',
				-Activated  => 1,
				},

				{
				-Title      => 'Create a Back Link',
				-Title_URL  => "$S_PROGRAM_URL?flavor=back_link",
				-Function   => 'back_link',
				-Activated  => 1,
				},



		]
},


{
-Title     => 'Profiles',
-Activated => 1,
-Submenu   => [
			     {
			     -Title      => 'Profile Fields',
			     -Title_URL  => "$S_PROGRAM_URL?flavor=profile_fields",
			     -Function   => 'profile_fields',
			     -Activated  => 1,
			     },
		]
},

{
-Title      => 'Plugins/Extensions',
-Activated  => 1,
-Submenu    => [

#					# These are plugins. Make sure you install them 
#					# if you want to use them! 

#					{
#					-Title      => 'Tracker',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/tracker",
#					-Function   => 'tracker',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'Bounce Handler',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/bounce_handler",
#					-Function   => 'bounce_handler',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'Bridge',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/bridge",
#					-Function   => 'bridge',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'Change the Program Root Password',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/change_root_password",
#					-Function   => 'change_root_password',
#					-Activated  => 0,
#					},

#					{
#					-Title      => 'Change Your List Short Name',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/change_list_shortname",
#					-Function   => 'change_list_shortname',
#					-Activated  => 0,
#					},

#					{
#					-Title      => 'Password Protect Directories',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/password_protect_directories",
#					-Function   => 'password_protect_directories',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'View Logs',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/log_viewer",
#					-Function   => 'log_viewer',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'Screen Cache',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/screen_cache",
#					-Function   => 'screen_cache',
#					-Activated  => 0,
#					},

#					{
#					-Title      => 'Global Configuration',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/global_config",
#					-Function   => 'global_config',
#					-Activated  => 0,
#					},

#					{
#					-Title      => 'Boilerplate Example',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/boilerplate_plugin",
#					-Function   => 'boilerplate',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'View List Settings',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/view_list_settings",
#					-Function   => 'view_list_settings',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'usage_log_to_consent_activity',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/usage_log_to_consent_activity",
#					-Function   => 'usage_log_to_consent_activity',
#					-Activated  => 0,
#					},

#					{
#					-Title      => 'Multiple Subscribe',
#					-Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
#					-Function   => 'multiple_subscribe',
#					-Activated  => 1,
#					},

#					{
#					-Title      => 'Archive Blog Index',
#					-Title_URL  => $EXT_URL."/blog_index.cgi?mode=html&list=<!-- tmpl_var LT_CHAR -->!-- tmpl_var list_settings.list --<!-- tmpl_var GT_CHAR -->",
#					-Function   => 'blog_index',
#					-Activated  => 1,
#					},

			],
		},



	{
	-Title      => '<i class="fi-widget"></i> Control Panel Settings',
	-Activated  => 0,
	-Submenu    => [
				{
				-Title      => 'Enable/Disable Features',
				-Title_URL  => "$S_PROGRAM_URL?flavor=feature_set",
				-Function   => 'feature_set',
				-Activated  => 0,
				},
				
				{
				-Title      => 'Scheduled Jobs',
				-Title_URL  => "$S_PROGRAM_URL?flavor=scheduled_jobs",
				-Function   => 'scheduled_jobs',
				-Activated  => 1,
				},
				
				{
				-Title      => 'App Configuration',
				-Title_URL  => "$S_PROGRAM_URL?flavor=setup_info",
				-Function   => 'setup_info',
				-Activated  => 1,
				},
				
				{
				-Title      => 'About Dada Mail',
				-Title_URL  => "$S_PROGRAM_URL?flavor=manage_script",
				-Function   => 'manage_script',
				-Activated  => 1,
				},
				
			], 
	},

];

$LIST_QUOTA //= 3;
$SUBSCRIPTION_QUOTA //= 100;
$MAILOUT_AT_ONCE_LIMIT //= 1;
$MAILOUT_STALE_AFTER   //= 86400;

$EMAIL_CASE //= 'lc_all';

@EMAIL_EXCEPTIONS = qw()
  unless scalar @EMAIL_EXCEPTIONS;

$LIST_IN_ORDER //= 0;

$FILE_CHMOD //= 0644;
$DIR_CHMOD  //= 0755;

$HTML_CHARSET //= 'UTF-8';

# https://www.w3.org/International/O-charset.html
# https://www.w3.org/International/O-HTTP-charset

@CHARSETS = (
    'UTF-8	UTF-8',
    'Afrikaans (af)	 iso-8859-1',
    'Afrikaans (af)	windows-1252',
    'Albanian (sq)	 iso-8859-1',
    'Albanian (sq)	 windows-1252',
    'Arabic (ar)	iso-8859-6',
    'Basque (eu)	iso-8859-1',
    'Basque (eu)	windows-1252',
    'Bulgarian (bg)	 iso-8859-5',
    'Byelorussian (be)	 iso-8859-5',
    'Catalan (ca)	iso-8859-1',
    'Catalan (ca)	windows-1252',
    'Croatian (hr)	 iso-8859-2',
    'Czech (cs)	 iso-8859-2',
    'Danish (da)	iso-8859-1',
    'Danish (da)	windows-1252',
    'Dutch (nl)	 iso-8859-1',
    'Dutch (nl)	 windows-1252',
    'English (en)	iso-8859-1',
    'English (en)	windows-1252',
    'Esperanto (eo)	 iso-8859-3',
    'Estonian (et)	 iso-8859-15',
    'Faroese (fo)	iso-8859-1',
    'Faroese (fo)	windows-1252',
    'Finnish (fi)	iso-8859-1',
    'Finnish (fi)	windows-1252',
    'French (fr)	iso-8859-1',
    'French (fr)	windows-1252',
    'Galician (gl)	 iso-8859-1',
    'Galician (gl)	 windows-1252',
    'German (de)	iso-8859-1',
    'German (de)	windows-1252',
    'Greek (el)	 iso-8859-7',
    'Hebrew (iw)	iso-8859-8',
    'Hungarian (hu)	 iso-8859-2',
    'Icelandic (is)	 iso-8859-1',
    'Icelandic (is)	 windows-1252',
    'Inuit (Eskimo)	 iso-8859-10',
    'Irish (ga)	 iso-8859-1',
    'Irish (ga)	 windows-1252',
    'Italian (it)	iso-8859-1',
    'Italian (it)	windows-1252',
    'Japanese (ja)	 shift_jis',
    'Japanese (ja)	iso-2022-jp',
    'Japanese (ja)	 euc-jp',
    'Lapp()	iso-8859-10',
    'Latvian (lv)	iso-8859-13',
    'Latvian (lv)	windows-1257',
    'Lithuanian (lt)	iso-8859-13',
    'Lithuanian (lt)	windows-1257',
    'Macedonian (mk)	iso-8859-5',
    'Maltese (mt)	iso-8859-3',
    'Norwegian (no)	 iso-8859-1',
    'Norwegian (no)	 windows-1252',
    'Polish (pl)	iso-8859-2',
    'Portuguese (pt)	iso-8859-1',
    'Portuguese (pt)	windows-1252',
    'Romanian (ro)	 iso-8859-2',
    'Russian (ru)	koi8-r',
    'Russian (ru)	iso-8859-5',
    'Scottish (gd)	 iso-8859-1',
    'Scottish (gd)	 windows-1252',
    'Serbian (sr)	iso-8859-5',
    'Slovak (sk)	iso-8859-2',
    'Slovenian (sl)	 iso-8859-2',
    'Spanish (es)	iso-8859-1',
    'Spanish (es)	windows-1252',
    'Swedish (sv)	iso-8859-1',
    'Swedish (sv)	windows-1252',
    'Thai (th)	windows-874',
    'Turkish (tr)	iso-8859-9',
    'Turkish (tr)	windows-1254',
    'Ukrainian (uk)	 iso-8859-5'
) unless scalar @CHARSETS;

@CONTENT_TYPES = qw(
  text/plain
  text/html
  ) unless scalar @CONTENT_TYPES;

%PRIORITIES = (
    'none' => 'Do not set a, "X-Priority" Header.',
    5      => 'lowest',
    4      => 'low',
    3      => 'normal',
    2      => 'high',
    1      => 'highest',
) unless keys %PRIORITIES;

@CONTENT_TRANSFER_ENCODINGS = qw(
  7bit
  8bit
  quoted-printable
  base64
  binary
  ) unless scalar @CONTENT_TRANSFER_ENCODINGS;

$HTML_TEXTTOHTML_OPTIONS //= {
    escape_HTML_chars => 0,    # This will also be overridden to, 0 by Dada Mail
                               # BUT! Dada Mail will provide it's own
                               # escape_HTML_chars-like routine

};

$HTML_SCRUBBER_OPTIONS //= {
    rules   => [ 
        script => 0, 
        style  => 1, 
    ],
    default => [
        1 => {
            '*'        => 1,          # default rule, allow all attributes
            'href'     => qr{^(?!(?:java)?script)}i,
            'src'      => qr{^(?!(?:java)?script)}i,
            'cite'     => '(?i-xsm:^(?!(?:java)?script))',
            'language' => 0,
            'name'        => 1,    # could be sneaky, but hey ;)
            'onblur'      => 0,
            'onchange'    => 0,
            'onclick'     => 0,
            'ondblclick'  => 0,
            'onerror'     => 0,
            'onfocus'     => 0,
            'onkeydown'   => 0,
            'onkeypress'  => 0,
            'onkeyup'     => 0,
            'onload'      => 0,
            'onmousedown' => 0,
            'onmousemove' => 0,
            'onmouseout'  => 0,
            'onmouseover' => 0,
            'onmouseup'   => 0,
            'onreset'     => 0,
            'onselect'    => 0,
            'onsubmit'    => 0,
            'onunload'    => 0,

            #'src'        => 0, # borks images?
            'type' => 0,
        },
    ],
    deny => [
        qw(
          embed
          object
          frame
          iframe
          meta
          )
    ],
    comment => 1,
    process => 0,
};


%MIME_TYPES = (
    '.gif'  => 'image/gif',
    '.jpg'  => 'image/jpg',
    '.png'  => 'image/png',
    '.jpeg' => 'image/jpeg',

    '.pdf' => 'application/pdf',
    '.psd' => 'application/psd',

    '.html' => 'text/html',
    '.txt'  => 'text/plain',

    '.doc' => 'application/msword',
    '.xls' => 'application/x-msexcel',
    '.ppt' => 'application/x-mspowerpoint',

    '.mp3' => 'application/octet-stream',
    '.mov' => 'video/quicktime',

) unless keys %MIME_TYPES;

$DEFAULT_MIME_TYPE //= 'application/octet-stream';
$MIME_PARANOID     //= 0;
$MIME_HUSH         //= 0;
$MIME_OPTIMIZE     = undef; #noop
$MIME_TOOLS_PARAMS //= { 
	tmp_to_core    => 1, 
	tmp_dir        => 'app_default', #server_default, #app_default
};

%LIST_SETUP_DEFAULTS = (

    # Mailing List >> List Information
    
    list             => '',    # don't default...
    list_name        => '',
    list_owner_email => '',
    admin_email      => undef,
    info             => '',    
    privacy_policy   => '',
    physical_address => '',
        # (Dummy)
        list_info => undef,
		
	list_phone_number    => undef, 
	
	list_consent_ids     => '',

	logo_image_url       => undef,
	website_url          => undef,
	facebook_page_url    => undef,
	twitter_url          => undef,
	instagram_url        => undef,
	youtube_url          => undef, 
	whatsapp_number      => undef,
	custom_url_color     => '#666666',
	custom_url_label     => undef,
	custom_url           => undef, 
	
    # Mailing List >> List Password
    password         => '',      # you'll need to encrypt it to use this...
    cipher_key       => undef,

    # Mailing List >> Options
    private_list     => 0,
    
    #mailing list options
    mx_check                   => 0,
    closed_list                => 0,
    invite_only_list           => 0,
    show_hidden                => 0,
    hide_list                  => 0,
    show_request_removal_links => 1, 
    
	show_subscription_form     => 1, 
	
	

    # Mass Mailing Options
    mass_mailing_convert_plaintext_to_html      => 1,
    mass_mailing_block_css_to_inline_css        => 1,
	email_embed_images_as_attachments           => 1, 
	email_image_width_limit                     => 580,
	
	email_limit_message_size                    => 1, 
	email_message_size_limit                    => 10, 
	
	resize_drag_and_drop_images                 => 1,
	enable_file_attachments_in_editor           => 1,  
	email_resize_embedded_images                => 1,
	mass_mailing_remove_javascript              => 1, 
	mass_mailing_save_sent_drafts_as_stationery => 0, 
	mass_mailing_default_layout                 => undef, 
	mass_mailing_show_by_default_type           => 'html',
	mass_mailing_use_list_headers               => 1,
	mass_mailing_use_list_unsubscribe_headers   => 1, 
	
	mass_mailing_show_previews_in               => 'modal_window',
	
    #quotas
    use_subscription_quota => 0,
    subscription_quota     => 0,

    
    email_your_subscribed_msg        => 1,    # Notice the incorrect, "your" instead of, "you're" - doh!
    email_you_are_not_subscribed_msg => 0,

    send_unsub_success_email => 1,
    send_sub_success_email   => 1,

    get_sub_notice                  => 1,
    send_subscription_notice_to     => 'list_owner',
    alt_send_subscription_notice_to => '' ,

    unsub_show_email_hint             => 1,
	
	# Not used anymore -  "completing_the_unsubscription" should be set to, "one_click_unsubscribe_no_confirm_screen"
	one_click_unsubscribe             => 0,
	
	completing_the_unsubscription     => 'click_link_on_confirm_screen', 
    get_unsub_notice                  => 1,
    send_unsubscription_notice_to     => 'list_owner',
    alt_send_unsubscription_notice_to => '', 

    enable_closed_loop_opt_in                => 1,    # Closed-Loop Opt-In
	enable_captcha_on_initial_subscribe_form => 1, 
    limit_sub_confirm                        => 1,
    limit_sub_confirm_use_captcha            => 1,
	
	enable_sub_confirm_stopforumspam_protection => 0, 
	enable_sub_confirm_suspicious_activity_by_ip_protection => 1,

    use_alt_url_sub_confirm_success                  => 0,
    alt_url_sub_confirm_success                      => '',
    alt_url_sub_confirm_success_w_qs                 => 0,
	alt_url_sub_confirm_success_show_in_modal_window => 0, 

    use_alt_url_sub_confirm_failed                   => 0,
    alt_url_sub_confirm_failed_w_qs                  => 0,
    alt_url_sub_confirm_failed                       => '',
	alt_url_sub_confirm_failed_show_in_modal_window  => 0,

    use_alt_url_sub_success  => 0,
    alt_url_sub_success_w_qs => 0,
    alt_url_sub_success      => '',

    use_alt_url_sub_failed  => 0,
    alt_url_sub_failed_w_qs => 0,
    alt_url_sub_failed      => '',

    use_alt_url_unsub_success  => 0,
    alt_url_unsub_success_w_qs => 0,
    alt_url_unsub_success      => '',

    use_alt_url_subscription_approval_step  => 0,
    alt_url_subscription_approval_step      => '',
    alt_url_subscription_approval_step_w_qs => 0,

    enable_subscription_approval_step => 0,
    captcha_sub                       => 0,

    send_subscribed_by_list_owner_message   => 0,
    send_unsubscribed_by_list_owner_message => 0,

    send_last_archived_msg_mass_mailing => 0,

    send_admin_unsubscription_notice        => 0, 
    send_admin_unsubscription_notice_to     => 'list_owner', 
    alt_send_admin_unsubscription_notice_to => '', 



    # SMTP Options

    smtp_server => undef,
    smtp_port   => 25,

    use_smtp_ssl        => 0,
	smtp_starttls       => 0, 
	smtp_ssl_verify_mode => 0, 
    set_smtp_sender => 1,
    use_sasl_smtp_auth  => 0,
    sasl_auth_mechanism => 'AUTO',
    sasl_smtp_username  => undef,
    sasl_smtp_password  => undef,

    smtp_max_messages_per_connection => undef,

    # Sending Options

    # Enable Batch Sending
    enable_bulk_batching => 1,

    # adjust_batch_sleep_time
    adjust_batch_sleep_time => 1,

    # Receive Finishing Message
    get_finished_notification => 1,

    # Send: [x] message(s) per batch
    mass_send_amount => 1,

    # and then wait: [x] seconds, before the next
    bulk_sleep_amount => 8,

    # Auto-Pickup Dropped Mass Mailings
    auto_pickup_dropped_mailings => 1,

    # sendmail, smtp, amazon_ses
    sending_method => 'sendmail',

    # Send a copy to the List Owner
    mass_mailing_send_to_list_owner => 1,
	mass_mailing_save_logs          => 0,

    amazon_ses_auto_batch_settings  => 1,

    # For mass mailings, connect only once per batch?
    # 0 = no
    # 1 = yes!
    smtp_connection_per_batch => 0,

    # adv sending options

    precedence => undef,
    charset    => 'UTF-8	UTF-8',

    # (Dummy)
    charset_value => 'UTF-8',
    priority      => 3,

    plaintext_encoding                     => 'quoted-printable',
    html_encoding                          => 'quoted-printable',
    add_sendmail_f_flag                    => 1,
    verp_return_path                       => 0,

    # view list prefs

    view_list_subscriber_number            => 100,
    view_list_show_timestamp_col           => 1, 
	view_list_show_sub_confirm_list        => 1, 
	view_list_enable_delete_all_button     => 0,
    view_list_order_by                     => 'timestamp', 
    view_list_order_by_direction           => 'DESC', 

    # add list prefs
    use_add_list_import_limit              => 1, 
    add_list_import_limit                  => 5000, 
    allow_profile_editing => 0, 
    
    # archive prefs

    archive_messages                       => 1,
    show_archives                          => 1,
    archives_available_only_to_subscribers => 0,
    archive_subscribe_form                 => 1,
    archive_search_form                    => 1,
    captcha_archive_send_form              => 0,
    archive_send_form                      => 0,
    send_newest_archive                    => 0,
                                          
    archive_show_second                    => 0,
    archive_show_hour_and_minute           => 0,
    archive_show_month                     => 1,
    archive_show_day                       => 1,
    archive_show_year                      => 1,
    archive_index_count                    => 10,
                                          
    sort_archives_in_reverse              => 1,
    disable_archive_js                    => 1,
    style_quoted_archive_text             => 1,
    publish_archives_rss                  => 1,
    ping_archives_rss                     => 0,
    html_archives_in_iframe               => 0,
    display_attachments                   => 1,
    add_subscribe_form_to_feeds           => 1,
    add_social_bookmarking_badges         => 1,
	
	archive_auto_remove                   => 0,
	archive_auto_remove_after_timespan    => '1y', 

    # Can be set to, "none","break", "spam_me_not"
    archive_protect_email => 'break',

    enable_gravatars     => 0,
    default_gravatar_url => undef,

    # archive editing prefs

    editable_headers => 'Subject',

    #blacklist
    black_list                           => 1,
    add_unsubs_to_black_list             => 1,
    allow_blacklisted_to_subscribe       => 1,
    allow_admin_to_subscribe_blacklisted => 0,

    # White List Prefs
    enable_white_list => 0,
	
	# Testers List Prefs
	enable_test_list               => 0,
	enable_test_list_address_limit => 1, 
	test_list_address_limit        => 10, 
	
    # List Invite Prefs

    invites_check_for_already_invited                => 1,
    invites_prohibit_reinvites                       => 1,
	invites_show_profile_fields_in_subscription_form => 0,


	email_theme_name => undef, 
    #  Mailing List Template Prefs

    get_template_data => 'from_default_template',
    url_template      => '',

    mailing_list_message_from_phrase => '<!-- tmpl_var list_settings.list_name -->', 
    mailing_list_message_to_phrase   => '<!-- tmpl_var list_settings.list_name --> Subscriber',
    mailing_list_message_subject     => '<!-- tmpl_var list_settings.list_name --> Message',
    mailing_list_message_html        => qq{<!-- tmpl_var message_body -->\n\n<p><strong><a href="<!-- tmpl_var list_unsubscribe_link -->">Unsubscribe Automatically &#187;</a></strong></p>},
    mailing_list_message             => qq{<!-- tmpl_var message_body -->\n\nUnsubscribe Automatically:\n<!-- tmpl_var list_unsubscribe_link -->},
	
	
    # Create a Back Link prefs
    back_link_website_name => '',
    back_link_website_url  => '',

    #SQL stuff

    # I don't think this is honored...
    # Don't change.
    subscription_table => 'dada_subscribers',

    # Not used?
    hard_remove => 1,

    # Not used?
    merge_fields => '',

    fallback_field_values => '',

    # HTML Screen Templates

    html_confirmation_message         => undef,
    html_subscribed_message           => undef,
    html_unsubscribed_message         => undef,
    html_subscription_request_message => undef,

    # Features
    admin_menu               => undef,
    disabled_screen_view     => 'hide',
	list_control_panel_style => 'top_bar',

    # List CP -> Options

    use_wysiwyg_editor                      => 'ckeditor',
    enable_mass_subscribe                   => 1,
    enable_mass_subscribe_only_w_root_login => 1,

    # Send me the list password.
    pass_auth_id => undef,

### Plugins

    # Bridge Plugin:

    group_list                     => 0,
#	group_list_pp_mode             => 1, 
	group_list_pp_mode_from_phrase => '<!-- tmpl_var original_from_phrase default="Subscriber" --> <!-- tmpl_var subscriber.email --> [<!-- tmpl_var list_settings.list_name -->]',  
	                                    
    open_discussion_list => 0,

    discussion_template_defang   => 1,
    only_allow_group_plain_text  => 0,
    mail_group_message_to_poster => 1,
    prefix_list_name_to_subject  => 1,
    no_prefix_list_name_to_subject_in_archives => 1,

	bridge_mention_original_sender => 1, 
    set_to_header_to_list_address        => 0,
    prefix_discussion_list_subjects_with => 'list_shortname',
    send_received_msg                    => 1, 
    send_msgs_to_list                    => 1,
    disable_discussion_sending           => 1,
    mail_discussion_message_to_poster    => 1,

    ignore_spam_messages                => 0,
    find_spam_assassin_score_by         => 'looking_for_embedded_headers',
    ignore_spam_messages_with_status_of => 6,
    rejected_spam_messages              => 'ignore_spam',

    enable_moderation              => 0,
    moderate_discussion_lists_with => 'list_owner_email',
	bridge_use_moderation_for      => 'everyone',
	bridge_recently_added_subscribers_timeframe => '1',
    send_moderation_msg            => 0,
    send_moderation_accepted_msg   => 0,
    send_moderation_rejection_msg  => 0,
	bridge_auto_reject_awaiting_moderation_messages           => 1, 
	bridge_auto_reject_awaiting_moderation_messages_timeframe => 1, 


    send_msg_copy_address          => '',


    enable_authorized_sending        => 0,

    authorized_sending_no_moderation => 0,
    subscriber_sending_no_moderation => 0,

    strip_file_attachments    => 0,
    file_attachments_to_strip => '',
    discussion_pop_server     => '',
	discussion_pop_port       => 'AUTO',
    discussion_pop_username   => '',
    discussion_pop_email      => '',
    bridge_list_email_type    => 'pop3_account',
    discussion_pop_password   => '',

    discussion_pop_auth_mode       => 'POP',
    discussion_pop_use_ssl         => 0,
	discussion_pop_starttls        =>  0,
	discussion_pop_ssl_verify_mode => 0, 

    bridge_announce_reply_to                      => 'none', 
	bridge_announce_reply_to_custom_email_address => undef, 
    send_not_allowed_to_post_msg                  => 1,
    send_invalid_msgs_to_owner                    => 1,
    send_msg_copy_to                              => 0,
    rewrite_anounce_from_header                   => 1,
	announce_from_header_allowed_domains          => '',

    msg_soft_size_limit      => 5242880, 
    msg_hard_size_limit      => 7340032, 

    digest_enable               => 0, 
    digest_schedule             => 86400, 
    digest_last_archive_id_sent => undef, 
	
	delivery_prefs_set_default => 0, 
	delivery_prefs_default     => 'individual',
	
	bridge_send_internal_problem_to_list_owner => 1, 
	
	

    # Tracker
    tracker_record_view_count                       => 5,
    tracker_auto_parse_links                        => 1,
    tracker_auto_parse_mailto_links                 => 0,
    tracker_track_opens_method                      => 'directly',
    tracker_track_email                             => 0,
	tracker_track_anonymously                       => 1, 
	tracker_show_location_data                      => 1,
	tracker_show_maps_in_reports                    => 1,
    tracker_clean_up_reports                        => 1,
    tracker_show_message_reports_in_mailing_monitor => 0,

	tracker_protect_tracked_links_from_prefetching  => 1, 
    tracker_update_profiles_w_geo_ip_data           => 0,
    tracker_update_profile_fields_ip_dada_meta      => undef, 

	tracker_send_analytics_email_notification       => 1, 
	tracker_data_auto_remove                        => 0,
	tracker_data_auto_remove_after_timespan         => '1y', 

    #	tracker_enable_data_cache                           => 1,
    #	tracker_dada_cache_expires                          => 1, # in hours

    # Bounce Handler

    bounce_handler_threshold_score                         => 10,
    bounce_handler_hardbounce_score                        => 4,
    bounce_handler_softbounce_score                        => 1,
    bounce_handler_decay_score                             => 1,
    bounce_handler_forward_msgs_to_list_owner              => 0,
	bounce_handler_forward_abuse_report_msgs_to_list_owner => 1, 
	bounce_handler_send_unsub_notification                 => 0, 
    bounce_handler_when_threshold_reached                  => 'move_to_bounced_sublist',
	
	enable_ignore_bounces_list                             => 0, 
        
    public_api_key   =>  undef, 
    private_api_key  => undef, 
    
    
    schedule_last_checked_time => undef, 

    scheduled_jobs_last_ran => undef, 

) unless keys %LIST_SETUP_DEFAULTS;

%LIST_SETUP_INCLUDE = ()
  unless keys %LIST_SETUP_INCLUDE;

%LIST_SETUP_DEFAULTS = ( %LIST_SETUP_DEFAULTS, %LIST_SETUP_INCLUDE );

%LIST_SETUP_OVERRIDES = ()
  unless keys %LIST_SETUP_OVERRIDES;

@LIST_SETUP_DONT_CLONE = qw(

  list
  list_name
  info
  list_info
  list_owner_email
  privacy_policy
  physical_address
  password
  
  list_consent_ids

  bridge_list_email_type

  disable_discussion_sending
  discussion_pop_server
  discussion_pop_username
  discussion_pop_email
  discussion_pop_password
  discussion_pop_auth_mode
  discussion_pop_use_ssl

)  unless scalar @LIST_SETUP_DONT_CLONE;
 
$OS //= $^O;

$NULL_DEVICE //= '/dev/null';

srand( time() ^ ( $$ + ( $$ << 15 ) ) );

$FIRST_SUB //= 0;
$SEC_SUB   //= 2;

@C = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.' );
$SALT = $C[ rand(@C) ] . $C[ rand(@C) ];

$ENABLE_CSRF_PROTECTION //= 1; 

# Pick a word. It really doesn't matter what the word is - a longer
# word doesn't necessarily mean a better pin number.

if ( !defined($PIN_WORD) ) {
    $PIN_WORD =
      ( $ROOT_PASS_IS_ENCRYPTED == 1 ) ? ($PROGRAM_ROOT_PASSWORD) : ('dada');
}

# Pick a number. I would keep it between 1 and 9.
$PIN_NUM //= unpack( "%32C*", $FILES );

$TEXT_CSV_PARAMS //= {
    binary              => 1,
  #  allow_loose_escapes => 1,
    always_quote        => 1,
  #  auto_diag           => 1,
};

BEGIN { @AnyDBM_File::ISA = qw(DB_File GDBM_File) }


# I don't believe this does anything, and should be removed: 
$ATTACHMENT_TEMPFILE //= 0;




$MAIL_VERP_SEPARATOR //= '-';


$VERSION = 11.22.0;
$VER = 'v11.22.0 stable 2023-09-18';

#
#
#
#####################################################################

$PROGRAM_NAME //= "Dada Mail";

%EMAIL_HEADERS = (

    Date                        => undef,
    From                        => undef,
    To                          => undef,
    Cc                          => undef,
    Bcc                         => undef,
    Sender                      => undef,
    'Return-Path'               => undef,
    'Reply-To'                  => undef,
    'In-Reply-To'               => undef,
    References                  => undef,
    'X-Priority'                => undef,
    'X-Original-From'           => undef,
    'Content-Base'              => undef,
    List                        => undef,
    'List-Archive'              => undef,
    'List-Digest'               => undef,
    'List-Help'                 => undef,
    'List-ID'                   => undef,
    'List-Owner'                => undef,
    'List-Post'                 => undef,
    'List-Subscribe'            => undef,
    'List-Unsubscribe'          => undef,
    'List-Unsubscribe'          => undef,
	'List-Unsubscribe-Post'     => undef, 
    'List-URL'                  => undef,
    'X-BeenThere'               => undef,
	'X-Beenthere'               => undef,
    'Message-ID'                => undef,
    'Precedence'                => 'list',
    'X-Mailer'                  => "$PROGRAM_NAME $VER ",
    'X-Cc'                      => undef,
    'Content-type'              => undef,
    'Content-Transfer-Encoding' => undef,
    'Content-Disposition'       => undef,
    'MIME-Version'              => undef,
    Subject                     => '(no subject)',
	'X-Preheader'               => undef,
    Body                        => 'blank',
) unless keys %EMAIL_HEADERS;


@EMAIL_HEADERS_ORDER = qw(
  Date
  From
  To
  Cc
  Bcc
  Sender
  Return-Path
  Reply-To
  In-Reply-To
  References
  X-Priority
  X-Original-From
  
  Precedence

  List
  X-List
  List-Archive
  List-Digest
  List-Help
  List-ID
  List-Owner
  List-Post
  List-Subscribe
  List-Unsubscribe
  List-Unsubscribe-Post
  List-URL
  X-BeenThere
  X-Beenthere
  
  X-Message-ID
  Message-ID

  X-Mailer
  X-Cc

  Content-type
  Content-Transfer-Encoding
  Content-Disposition
  Content-Base

  MIME-Version
  X-Preheader
  Subject
  ) unless scalar @EMAIL_HEADERS_ORDER;
  

$LIST_HEADERS //= { 
	'Precedence'                => undef,
	'List'                      => undef,
	'List-Archive'              => undef,
	'List-Digest'               => undef,
	'List-Help'                 => undef,
	'List-ID'                   => undef,
	'List-Owner'                => undef,
	'List-Post'                 => undef,
	'List-Subscribe'            => undef,
	'List-Unsubscribe'          => undef,
	'List-Unsubscribe'          => undef,
	'List-Unsubscribe-Post'     => undef, 
	'List-URL'                  => undef,
	'X-Mailer'                  => undef, 
};
  

######################################################################

# https://dadamailproject.com/purchase/pro.html
#
#
#
#

$GIVE_PROPS_IN_EMAIL //= 1;
$GIVE_PROPS_IN_HTML //= 1;
$GIVE_PROPS_IN_ADMIN //= 1;
$GIVE_PROPS_IN_SUBSCRIBE_FORM //= 1;
$PROGRAM_IMG_FILENAME //= 'dada_mail_logo.png';
##########################################

#

# my $imported_config = 0; 
sub _config_import {

#	if ($imported_config == 1){
#		warn 'skipping opening .dada_config - already imported.'; 
#		return; 
#	}	
#	else { 
#		warn 'opening .dada_config' ; 
#	}


# There's no user-servicable parts in the subroutine, so don't make any changes,
# unless you're customizing Dada Mail or debugging something interesting.
#
    if ( exists( $ENV{NO_DADA_MAIL_CONFIG_IMPORT} ) ) {
        if ( $ENV{NO_DADA_MAIL_CONFIG_IMPORT} == 1 ) {
            return;
        }
    }

    # Keep this as, 'https://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'
    # What we're doing is, seeing if you've actually changed the variable from
    # it's default, and if not, we take a best guess.

    my $CONFIG_FILE_DIR = undef;

    if ( defined($OS) !~ m/^Win|^MSWin/i ) {
        my $getpwuid_call;
        my $good_getpwuid;
        eval { $getpwuid_call = ( getpwuid $> )[7]; };
        if ( !$@ ) {
            $good_getpwuid = $getpwuid_call;
        }
        if ( $PROGRAM_CONFIG_FILE_DIR eq 'auto' ) {
			$good_getpwuid =~ s/\/$//; 
            $CONFIG_FILE_DIR = $good_getpwuid . '/.dada_files/.configs';
        }
        else {
            $CONFIG_FILE_DIR = $PROGRAM_CONFIG_FILE_DIR;
        }
    }

    $CONFIG_FILE = $CONFIG_FILE_DIR . '/.dada_config';

    # yes, shooting yourself in the foot, RTM
    $CONFIG_FILE =~ /(.*)/;
    $CONFIG_FILE = $1;

    if ( -e $CONFIG_FILE && -f $CONFIG_FILE && -s $CONFIG_FILE ) {
        open( CONFIG, '<:encoding(UTF-8)', $CONFIG_FILE )
          or warn
          "could not open outside config file, '$CONFIG_FILE' because: $!";
        my $conf;
        $conf = do { local $/; <CONFIG> };

        # shooting again,
        $conf =~ m/(.*)/ms;
        $conf = $1;
        eval $conf;
        if ($@) {
            die
"$PROGRAM_NAME $VER ERROR - Outside config file '$CONFIG_FILE' contains errors:\n\n$@\n\n";
        }
        if ( $PROGRAM_CONFIG_FILE_DIR eq 'auto' ) {
            if ( !defined $PROGRAM_ERROR_LOG ) {
                $PROGRAM_ERROR_LOG = $LOGS . '/errors.txt';
                open( STDERR, ">>$PROGRAM_ERROR_LOG" )
                  || warn
"$PROGRAM_NAME Error: Cannot redirect STDERR, it's possible that Dada Mail does not have write permissions to this file ($PROGRAM_ERROR_LOG) or it doesn't exist! If Dada Mail cannot make this file for you, create it yourself and give it enough permissions so it may write to it: $!";
            }
        }
    }

    if ( $PROGRAM_URL eq
        'https://www.changetoyoursite.com/cgi-bin/dada/mail.cgi' )
    {
        require CGI;
        $PROGRAM_URL = CGI::url();
    }

   # I really DO NOT think this is the place to massage Config variables if they
   # aren't set right, but it will save people headaches, in the long run:

    my %default_table_names = (
        subscriber_table                   => 'dada_subscribers',
        profile_table                      => 'dada_profiles',
        profile_fields_table               => 'dada_profile_fields',
        profile_fields_attributes_table    => 'dada_profile_fields_attributes',
        profile_settings_table             => 'dada_profile_settings',
        archives_table                     => 'dada_archives',
        settings_table                     => 'dada_settings',
        session_table                      => 'dada_sessions',
        bounce_scores_table                => 'dada_bounce_scores',
        clickthrough_urls_table            => 'dada_clickthrough_urls',
        clickthrough_url_log_table         => 'dada_clickthrough_url_log',
        mass_mailing_event_log_table       => 'dada_mass_mailing_event_log',
        password_protect_directories_table => 'dada_password_protect_directories',
        confirmation_tokens_table          => 'dada_confirmation_tokens',
		message_drafts_table               => 'dada_message_drafts', 
		rate_limit_hits_table              => 'dada_rate_limit_hits',
		email_message_previews_table       => 'dada_email_message_previews',
		
		privacy_policies_table             => 'dada_privacy_policies',
		consents_table                     => 'dada_consents',
		consent_activity_table             => 'dada_consent_activity',
		
		simple_auth_str_table              => 'dada_simple_auth_str',
		
		dbtype => 'SQLite',
		database => 'dadamail',
        
		
    );
    for ( keys %default_table_names ) {
        if ( !exists( $SQL_PARAMS{$_} ) ) {
            $SQL_PARAMS{$_} = $default_table_names{$_};
        }
    }

}

=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2023 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut

# Don't remove the '1'. It lives here at the bottom. It likes it there.

1;

__END__
