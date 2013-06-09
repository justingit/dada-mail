package DADA::Config;

#----------------------------------------------------------------------------#
# This file holds default values for the global configuration variables 
# in Dada Mail. See:
#
#          http://dadamailproject.com/d/global_variables.pod.html
# 
# for more information. 
#
#----------------------------------------------------------------------------#

require Exporter;
our @ISA = qw(Exporter);
use vars
  qw($PROGRAM_ROOT_PASSWORD $MAILPROG $DIR $FILES $PROGRAM_URL $S_PROGRAM_URL $PLUGIN_CONFIGS $MAIL_SETTINGS $MASS_MAIL_SETTINGS $AMAZON_SES_OPTIONS $FIRST_SUB $SEC_SUB @C $SALT $FILE_CHMOD $DIR_CHMOD $GIVE_PROPS_IN_EMAIL $GIVE_PROPS_IN_HTML $GIVE_PROPS_IN_ADMIN $GIVE_PROPS_IN_SUBSCRIBE_FORM $SUBSCRIBED_MESSAGE $SUBSCRIBED_BY_LIST_OWNER_MESSAGE $UNSUBSCRIBED_BY_LIST_OWNER_MESSAGE $SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE $SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE $SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT $SUBSCRIPTION_NOTICE_MESSAGE $UNSUBSCRIPTION_NOTICE_MESSAGE_SUBJECT $UNSUBSCRIPTION_NOTICE_MESSAGE $UNSUBSCRIBED_MESSAGE $CONFIRMATION_MESSAGE  $HTML_CONFIRMATION_MESSAGE $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE $YOU_ARE_NOT_SUBSCRIBED_MESSAGE $HTML_UNSUBSCRIPTION_REQUEST_MESSAGE $HTML_SUBSCRIBED_MESSAGE $HTML_UNSUBSCRIBED_MESSAGE $HTML_SUBSCRIPTION_REQUEST_MESSAGE $ARCHIVES $TEMPLATES $ALTERNATIVE_HTML_TEMPLATE_PATH $TMP $LOGS $BACKUPS %BACKUP_HISTORY $MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION $ENFORCE_CLOSED_LOOP_OPT_IN $FCKEDITOR_URL $CKEDITOR_URL $SUPPORT_FILES $WYSIWYG_EDITOR_OPTIONS  $FILE_BROWSER_OPTIONS  $SCREEN_CACHE $DATA_CACHE $GLOBAL_BLACK_LIST $GLOBAL_UNSUBSCRIBE $MULTIPLE_LIST_SENDING $MULTIPLE_LIST_SENDING_TYPE $HIDDEN_SUBSCRIBER_FIELDS_PREFIX @PING_URLS $SUBSCRIPTION_SUCCESSFUL_COPY $MAILING_LIST_MESSAGE $MAILING_LIST_MESSAGE_HTML $MODERATION_MSG $AWAIT_MODERATION_MSG $ACCEPT_MSG $REJECTION_MSG $MSG_TOO_BIG_MSG $MSG_LABELED_AS_SPAM_MSG $NOT_ALLOWED_TO_POST_MSG $NOT_ALLOWED_TO_POST_NOTICE_MSG $MAILING_FINISHED_MESSAGE $MAILING_FINISHED_MESSAGE_SUBJECT $PIN_WORD $PIN_NUM $TEXT_CSV_PARAMS $ALLOW_ROOT_LOGIN $UNSUBSCRIPTION_REQUEST_MESSAGE  $UNSUBSCRIPTION_REQUEST_MESSAGE_SUBJECT $SUBSCRIPTION_REQUEST_APPROVED_MESSAGE $SUBSCRIPTION_REQUEST_DENIED_MESSAGE @CHARSETS @CONTENT_TYPES %LIST_SETUP_DEFAULTS %LIST_SETUP_INCLUDE %LIST_SETUP_OVERRIDES @LIST_SETUP_DONT_CLONE %PRIORITIES $ATTACHMENT_TEMPFILE $MAIL_VERP_SEPARATOR %MIME_TYPES $DEFAULT_MIME_TYPE $TEXT_INVITE_MESSAGE $PROFILE_ACTIVATION_MESSAGE_SUBJECT $PROFILE_ACTIVATION_MESSAGE $PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT $PROFILE_RESET_PASSWORD_MESSAGE $PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT $PROFILE_UPDATE_EMAIL_MESSAGE $PROFILE_EMAIL_UPDATED_NOTIFICATION_MESSAGE_SUBJECT $PROFILE_EMAIL_UPDATED_NOTIFICATION_MESSAGE $LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT $LIST_CONFIRM_PASSWORD_MESSAGE $LIST_RESET_PASSWORD_MESSAGE_SUBJECT $LIST_RESET_PASSWORD_MESSAGE $HTML_INVITE_MESSAGE $SENDING_PREFS_MESSAGE_SUBJECT $SENDING_PREFS_MESSAGE $MIME_PARANOID $MIME_HUSH $MIME_OPTIMIZE $NPH $PROGRAM_USAGE_LOG $ROOT_PASS_IS_ENCRYPTED @ALLOWED_IP_ADDRESSES $SHOW_ADMIN_LINK $ADMIN_FLAVOR_NAME $SIGN_IN_FLAVOR_NAME $DISABLE_OUTSIDE_LOGINS %LOG $DEBUG_TRACE %CPAN_DEBUG_SETTINGS $ADMIN_MENU $EMAIL_CASE @EMAIL_EXCEPTIONS $LIST_IN_ORDER $ADMIN_TEMPLATE $USER_TEMPLATE $BACKEND_DB_TYPE $SUBSCRIBER_DB_TYPE $ARCHIVE_DB_TYPE $SETTINGS_DB_TYPE $SESSION_DB_TYPE $BOUNCE_SCORECARD_DB_TYPE $CLICKTHROUGH_DB_TYPE %SQL_PARAMS $DBI_PARAMS $PROFILE_OPTIONS $PROGRAM_ERROR_LOG $SHOW_HELP_LINKS $HELP_LINKS_URL $VER $VERSION  $PROGRAM_NAME @CONTENT_TRANSFER_ENCODINGS $CONFIG_FILE $PROGRAM_CONFIG_FILE_DIR $OS $DEFAULT_ADMIN_SCREEN $DEFAULT_LOGOUT_SCREEN $DEFAULT_SCREEN $HTML_CHARSET $HTML_SEND_ARCHIVED_MESSAGE $SEND_ARCHIVED_MESSAGE $REFERER_CHECK $CAPTCHA_TYPE $RECAPTCHA_PARAMS $RECAPTHCA_MAILHIDE_PARAMS $GD_SECURITYIMAGE_PARAMS $LOGIN_COOKIE_NAME %COOKIE_PARAMS $HTML_TEXTTOHTML_OPTIONS $HTML_SCRUBBER_OPTIONS $TEMPLATE_SETTINGS $LOGIN_WIDGET $NULL_DEVICE $LIST_QUOTA $SUBSCRIPTION_QUOTA $MAILOUT_AT_ONCE_LIMIT $MAILOUT_STALE_AFTER %EMAIL_HEADERS @EMAIL_HEADERS_ORDER);

@EXPORT_OK =
  qw($PROGRAM_ROOT_PASSWORD $MAILPROG $DIR $FILES $PROGRAM_URL $S_PROGRAM_URL $PLUGIN_CONFIGS $MAIL_SETTINGS $MASS_MAIL_SETTINGS $AMAZON_SES_OPTIONS $FIRST_SUB $SEC_SUB @C $SALT $FILE_CHMOD $DIR_CHMOD $GIVE_PROPS_IN_EMAIL $GIVE_PROPS_IN_HTML $GIVE_PROPS_IN_ADMIN $GIVE_PROPS_IN_SUBSCRIBE_FORM $SUBSCRIBED_MESSAGE $SUBSCRIBED_BY_LIST_OWNER_MESSAGE $UNSUBSCRIBED_BY_LIST_OWNER_MESSAGE $SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE $SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE $SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT $SUBSCRIPTION_NOTICE_MESSAGE $UNSUBSCRIPTION_NOTICE_MESSAGE_SUBJECT $UNSUBSCRIPTION_NOTICE_MESSAGE $UNSUBSCRIBED_MESSAGE $CONFIRMATION_MESSAGE  $HTML_CONFIRMATION_MESSAGE $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE $YOU_ARE_NOT_SUBSCRIBED_MESSAGE $HTML_UNSUBSCRIPTION_REQUEST_MESSAGE $HTML_SUBSCRIBED_MESSAGE $HTML_UNSUBSCRIBED_MESSAGE $HTML_SUBSCRIPTION_REQUEST_MESSAGE $ARCHIVES $TEMPLATES $ALTERNATIVE_HTML_TEMPLATE_PATH $TMP $LOGS $BACKUPS %BACKUP_HISTORY $MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION $ENFORCE_CLOSED_LOOP_OPT_IN $FCKEDITOR_URL $CKEDITOR_URL $SUPPORT_FILES $WYSIWYG_EDITOR_OPTIONS $FILE_BROWSER_OPTIONS $SCREEN_CACHE $DATA_CACHE $GLOBAL_BLACK_LIST $GLOBAL_UNSUBSCRIBE $MULTIPLE_LIST_SENDING $MULTIPLE_LIST_SENDING_TYPE $HIDDEN_SUBSCRIBER_FIELDS_PREFIX @PING_URLS $SUBSCRIPTION_SUCCESSFUL_COPY $MAILING_LIST_MESSAGE $MAILING_LIST_MESSAGE_HTML  $MODERATION_MSG $AWAIT_MODERATION_MSG $ACCEPT_MSG $REJECTION_MSG $MSG_TOO_BIG_MSG $MSG_LABELED_AS_SPAM_MSG $NOT_ALLOWED_TO_POST_MSG $NOT_ALLOWED_TO_POST_NOTICE_MSG $MAILING_FINISHED_MESSAGE $MAILING_FINISHED_MESSAGE_SUBJECT $PIN_WORD $PIN_NUM $TEXT_CSV_PARAMS $ALLOW_ROOT_LOGIN $UNSUBSCRIPTION_REQUEST_MESSAGE $UNSUBSCRIPTION_REQUEST_MESSAGE_SUBJECT $SUBSCRIPTION_REQUEST_APPROVED_MESSAGE $SUBSCRIPTION_REQUEST_DENIED_MESSAGE @CHARSETS @CONTENT_TYPES %LIST_SETUP_DEFAULTS %LIST_SETUP_INCLUDE %LIST_SETUP_OVERRIDES @LIST_SETUP_DONT_CLONE %PRIORITIES $ATTACHMENT_TEMPFILE $MAIL_VERP_SEPARATOR %MIME_TYPES $DEFAULT_MIME_TYPE $TEXT_INVITE_MESSAGE $PROFILE_ACTIVATION_MESSAGE_SUBJECT $PROFILE_ACTIVATION_MESSAGE $PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT $PROFILE_RESET_PASSWORD_MESSAGE $PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT $PROFILE_UPDATE_EMAIL_MESSAGE $PROFILE_EMAIL_UPDATED_NOTIFICATION_MESSAGE_SUBJECT $PROFILE_EMAIL_UPDATED_NOTIFICATION_MESSAGE $LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT $LIST_CONFIRM_PASSWORD_MESSAGE $LIST_RESET_PASSWORD_MESSAGE_SUBJECT $LIST_RESET_PASSWORD_MESSAGE $HTML_INVITE_MESSAGE $SENDING_PREFS_MESSAGE_SUBJECT $SENDING_PREFS_MESSAGE $MIME_PARANOID $MIME_HUSH $MIME_OPTIMIZE $NPH $PROGRAM_USAGE_LOG $ROOT_PASS_IS_ENCRYPTED @ALLOWED_IP_ADDRESSES $SHOW_ADMIN_LINK $ADMIN_FLAVOR_NAME $SIGN_IN_FLAVOR_NAME $DISABLE_OUTSIDE_LOGINS %LOG $DEBUG_TRACE %CPAN_DEBUG_SETTINGS $ADMIN_MENU $EMAIL_CASE @EMAIL_EXCEPTIONS $LIST_IN_ORDER $ADMIN_TEMPLATE $USER_TEMPLATE $BACKEND_DB_TYPE $SUBSCRIBER_DB_TYPE $ARCHIVE_DB_TYPE $SETTINGS_DB_TYPE $SESSION_DB_TYPE $BOUNCE_SCORECARD_DB_TYPE $CLICKTHROUGH_DB_TYPE %SQL_PARAMS $DBI_PARAMS $PROFILE_OPTIONS $PROGRAM_ERROR_LOG $SHOW_HELP_LINKS $HELP_LINKS_URL $VER $VERSION  $PROGRAM_NAME @CONTENT_TRANSFER_ENCODINGS $CONFIG_FILE $PROGRAM_CONFIG_FILE_DIR $OS $DEFAULT_ADMIN_SCREEN $DEFAULT_LOGOUT_SCREEN $DEFAULT_SCREEN $HTML_CHARSET $HTML_SEND_ARCHIVED_MESSAGE $SEND_ARCHIVED_MESSAGE $REFERER_CHECK $CAPTCHA_TYPE $RECAPTCHA_PARAMS $RECAPTHCA_MAILHIDE_PARAMS $GD_SECURITYIMAGE_PARAMS $LOGIN_COOKIE_NAME %COOKIE_PARAMS $HTML_TEXTTOHTML_OPTIONS $HTML_SCRUBBER_OPTIONS $TEMPLATE_SETTINGS $LOGIN_WIDGET $NULL_DEVICE $LIST_QUOTA $SUBSCRIPTION_QUOTA $MAILOUT_AT_ONCE_LIMIT $MAILOUT_STALE_AFTER %EMAIL_HEADERS @EMAIL_HEADERS_ORDER);
#
#
#
#
#

$PROGRAM_CONFIG_FILE_DIR = 'auto';

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

$PROGRAM_ERROR_LOG = undef;

#
#
#
#
#

    # Keep this next bit as-is; it's just opening the error file for writing.
    if ($PROGRAM_ERROR_LOG) {
        open( STDERR, ">>$PROGRAM_ERROR_LOG" )
          || warn
"$PROGRAM_NAME Error: Cannot redirect STDERR, it's possible that Dada Mail does not have write permissions to this file ($PROGRAM_ERROR_LOG) or it doesn't exist! If Dada Mail cannot make this file for you, create it yourself and give it enough permissions so it may write to it: $!";
    }

    # chmod(0777, $PROGRAM_ERROR_LOG);
}




$PROGRAM_ROOT_PASSWORD  ||= 'root_password';
$ROOT_PASS_IS_ENCRYPTED ||= 0;




($DIR) ||= $PROGRAM_CONFIG_FILE_DIR =~ m/^(.*?)\/\.configs$/;
$ARCHIVES          ||= $DIR . '/.archives';
$BACKUPS           ||= $DIR . '/.backups';
$FILES             ||= $DIR . '/.lists';
$LOGS              ||= $DIR . '/.logs';
$PROGRAM_USAGE_LOG ||= $LOGS . '/dada.txt';
$TEMPLATES         ||= $DIR . '/.templates';
$TMP               ||= $DIR . '/.tmp';




$PROGRAM_URL   ||= 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi';
$S_PROGRAM_URL ||= $PROGRAM_URL;




$SUPPORT_FILES ||= {
    dir => '',
    url => '',
};

$WYSIWYG_EDITOR_OPTIONS ||= {
    fckeditor => {
        enabled => 0,
        url     => '',
    },
    ckeditor => {
        enabled => 0,
        url     => '',
    },
    tiny_mce => {
        enabled => 0,
        url     => '',
    },
};

$FILE_BROWSER_OPTIONS ||= {
    kcfinder => {
        enabled      => 0,
        url          => '',
        upload_dir   => '',
        upload_url   => '',
        session_name => 'PHPSESSID',
        session_dir  => '/tmp',
    },
};





# Here are the four variables that are talked about, above:
$BACKEND_DB_TYPE ||= 'Default';

if ( $BACKEND_DB_TYPE eq 'Default' ) {
    $SUBSCRIBER_DB_TYPE       ||= 'PlainText';
    $ARCHIVE_DB_TYPE          ||= 'Db';
    $SETTINGS_DB_TYPE         ||= 'Db';
    $SESSION_DB_TYPE          ||= 'Db';
    $BOUNCE_SCORECARD_DB_TYPE ||= 'Db';
    $CLICKTHROUGH_DB_TYPE     ||= 'Db';
}
elsif ( $BACKEND_DB_TYPE eq 'SQL' ) {
    $SUBSCRIBER_DB_TYPE       ||= 'SQL';
    $ARCHIVE_DB_TYPE          ||= 'SQL';
    $SETTINGS_DB_TYPE         ||= 'SQL';
    $SESSION_DB_TYPE          ||= 'SQL';
    $BOUNCE_SCORECARD_DB_TYPE ||= 'SQL';
    $CLICKTHROUGH_DB_TYPE     ||= 'SQL';
}




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




$DBI_PARAMS ||= {

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

};




$PROFILE_OPTIONS ||= {

    enabled                         => 1,
    profile_email                   => '',
    enable_captcha                  => 1,
    enable_magic_subscription_forms => 1,

    update_email_options => {
        send_notification_to_profile_email => 0,
        subscription_check_skip            => 'auto',

    },

    gravatar_options => {
        enable_gravators     => 1,
        default_gravatar_url => undef,
    },

    features => {
        help                       => 1,
        login                      => 1,
        register                   => 1,
        password_reset             => 1,
        profile_fields             => 1,
        mailing_list_subscriptions => 1,
        protected_directories      => 1,
        update_email_address       => 1,
        change_password            => 1,
        delete_profile             => 1,
    },
    cookie_params => {
        -name    => 'dada_profile',
        -path    => '/',
        -expires => '+1y',
    },

};




$PLUGIN_CONFIGS ||= { 

	Bounce_Handler => {
		Server                      => undef,
		Username                    => undef,
		Password                    => undef,
		Port                        => undef,
		USESSL                      => undef,
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

	Beatitude => {

		Plugin_Name                 => undef,
		Plugin_URL                  => undef,
		Allow_Manual_Run            => undef,
		Manual_Run_Passcode         => undef,
		Log                         => undef,

	},
	
	Bridge => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Allow_Manual_Run                    => undef,
		Manual_Run_Passcode                 => undef,
		MessagesAtOnce                      => undef,
		Soft_Max_Size_Of_Any_Message        => undef,
		Max_Size_Of_Any_Message             => undef,
		Allow_Open_Discussion_List          => undef,
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

};



$MAILPROG           ||= '/usr/sbin/sendmail';
$MAIL_SETTINGS      ||= "|$MAILPROG -t";
$MASS_MAIL_SETTINGS ||= "|$MAILPROG -t";

$AMAZON_SES_OPTIONS ||= { 
	AWSAccessKeyId => undef, 
	AWSSecretKey   => undef, 
};



$SHOW_ADMIN_LINK        ||= 1;
$ADMIN_FLAVOR_NAME      ||= 'admin';
$SIGN_IN_FLAVOR_NAME    ||= 'sign_in';
$DEFAULT_SCREEN         ||= '';
$DEFAULT_ADMIN_SCREEN   ||= $S_PROGRAM_URL . '?f=send_email';
$DEFAULT_LOGOUT_SCREEN  ||= $S_PROGRAM_URL . '?f=' . $ADMIN_FLAVOR_NAME;
$DISABLE_OUTSIDE_LOGINS ||= 0;
$LOGIN_WIDGET           ||= 'popup_menu';
$ALLOW_ROOT_LOGIN       ||= 1;
$REFERER_CHECK          ||= 0;
@ALLOWED_IP_ADDRESSES = qw()
  unless scalar @ALLOWED_IP_ADDRESSES;



# Set to Either, "Default" or, "reCAPTCHA";
$CAPTCHA_TYPE ||= 'Default';
$GD_SECURITYIMAGE_PARAMS ||= {
    'rand_string_from' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZaeiouy',
    'rand_string_size' => 6,
    'new' => {
        width  => 250,
        height => 125,
        lines  => 10,
        #gd_font    => 'Giant',
        send_ctobg => 1,
        # There's some magic here,
        # If the font is located in the,
        # dada/templates directory,
        # You don't have to put the absolute path,
        # just the filename.
        font    => 'StayPuft.ttf',
        bgcolor => "#CCFFCC",
        angle   => 13,
        ptsize  => 30,
    },
    create => {
        ttf => 'circle',
        # normal => 'circle',
    },
    particle => [ 500, undef ],
};
$RECAPTCHA_PARAMS ||= {
    remote_address => $ENV{'REMOTE_ADDR'},
    public_key     => undef,
    private_key    => undef,
};
$RECAPTHCA_MAILHIDE_PARAMS ||= {
    public_key  => '',
    private_key => '',
};



$SHOW_HELP_LINKS ||= 1;
$HELP_LINKS_URL  ||= 'http://dadamailproject.com/pro_dada/6.4.0';


$LOGIN_COOKIE_NAME ||= 'dadalogin';

%COOKIE_PARAMS = (
    -path    => '/',
    -expires => '+7d',
) unless keys %COOKIE_PARAMS;


$NPH ||= 0;





%LOG = (
    subscriptions        => 1,
    mailings             => 0,
    mass_mailings        => 1,
    mass_mailing_batches => 1,
    logins               => 1,
    list_lives           => 1,

) unless keys %LOG;




$DEBUG_TRACE ||= {

    DADA_App_DBIHandle                 => 0,
    DADA_App_Subscriptions             => 0,
    DADA_Logging_Clickthrough          => 0,
    DADA_Profile                       => 0,
    DADA_Profile_Fields                => 0,
    DADA_Profile_Session               => 0,
    DADA_Mail_MailOut                  => 0,
    DADA_Mail_Send                     => 0,
    DADA_App_BounceHandler_ScoreKeeper => 0,
    DADA_MailingList_baseSQL           => 0,

};

%CPAN_DEBUG_SETTINGS = (

    # DBI, handles all SQL database calls.
    # More Information:
    # http://search.cpan.org/~timb/DBI/DBI.pm#TRACING
    # As noted in these docs, you can set the trace level as far 15

    DBI => 0,

    # HTML::Template, used for generating HTML screens
    # More information:
    # http://search.cpan.org/~samtregar/HTML-Template/Template.pm

    HTML_TEMPLATE => 0,

    # MIME::Lite::HTML, used for the, "Send a Webpage" screen
    # More information:
    # http://search.cpan.org/~alian/MIME-Lite-HTML/HTML.pm

    MIME_LITE_HTML => 0,

    #  Net::POP3, used for checking awaiting messages on a POP3 Server
    #  More Information:
    #  http://search.cpan.org/~gbarr/libnet/Net/POP3.pm
    #  NET_POP3 => 0,

    # http://search.cpan.org/~sdowd/Mail-POP3Client/POP3Client.pm
    MAIL_POP3CLIENT => 0,

    # Net::SMTP, used for sending messages via SMTP:
    # more information:
    # http://search.cpan.org/~gbarr/libnet/Net/SMTP.pm

    NET_SMTP => 0,

) unless keys %CPAN_DEBUG_SETTINGS;

$ADMIN_TEMPLATE                 ||= '';
$USER_TEMPLATE                  ||= '';
$ALTERNATIVE_HTML_TEMPLATE_PATH ||= undef;
$TEMPLATE_SETTINGS              ||= {
    oldstyle_backwards_compatibility => 1,
    engine                           => 'Best',
};



%BACKUP_HISTORY = (
    settings  => 3,
    archives  => 3,
    schedules => 3,
) unless keys %BACKUP_HISTORY;


$MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION ||= 0;
$ENFORCE_CLOSED_LOOP_OPT_IN             ||= 0;
$MULTIPLE_LIST_SENDING                  ||= 0;
$MULTIPLE_LIST_SENDING_TYPE             ||= 'merged';    # individual
$GLOBAL_BLACK_LIST                      ||= 0;
$GLOBAL_UNSUBSCRIBE                     ||= 0;
$HIDDEN_SUBSCRIBER_FIELDS_PREFIX        ||= '_';

$SCREEN_CACHE                           ||= 1;
$DATA_CACHE                             ||= 1;

@PING_URLS = qw(
  http://rpc.pingomatic.com/
  http://rpc.weblogs.com/RPC2
  http://ping.blo.gs/
  ) unless scalar @PING_URLS;



# If you do put the $ADMIN_MENU variable in the outside config file,
# make sure to also! put the below line (uncommented):
#
#  $S_PROGRAM_URL = $PROGRAM_URL
#
# Before the $ADMIN_URL variable, as well as the below 5 lines of code:

$S_PROGRAM_URL = $PROGRAM_URL;
my $PLUGIN_URL = $S_PROGRAM_URL;
   $PLUGIN_URL =~ s/\/(\w+)\.(cgi|pl)$/\//;
   $PLUGIN_URL .= 'plugins';
my $EXT_URL     = $PLUGIN_URL;
   $EXT_URL     =~ s/plugins/extensions/;

$ADMIN_MENU ||= [

    {
        -Title     => 'Mass Mailing',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'Send a Message',
                -Title_URL => "$S_PROGRAM_URL?f=send_email",
                -Function  => 'send_email',
                -Activated => 1,
            },

            {
                -Title     => 'Send a Webpage',
                -Title_URL => "$S_PROGRAM_URL?f=send_url_email",
                -Function  => 'send_url_email',
                -Activated => 1,
            },

            {
                -Title => 'Monitor Your Mailings',
                -Title_URL => "$S_PROGRAM_URL?f=sending_monitor",
                -Function  => 'sending_monitor',
                -Activated => 1,
            },

            {
                -Title     => 'Options',
                -Title_URL => "$S_PROGRAM_URL?f=mass_mailing_options",
                -Function  => 'mass_mailing_options',
                -Activated => 1,
            },

        ]
    },

    {
        -Title     => 'Membership',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'View',
                -Title_URL => "$S_PROGRAM_URL?f=view_list",
                -Function  => 'view_list',
                -Activated => 1,
            },

            {
                -Title     => 'Recent Activity',
                -Title_URL => "$S_PROGRAM_URL?f=list_activity",
                -Function  => 'list_activity',
                -Activated => 1,
            },

            {
                -Title =>
'Invite<!-- tmpl_if list_settings.enable_mass_subscribe -->/Subscribe<!-- /tmpl_if -->/Add',
                -Title_URL => "$S_PROGRAM_URL?f=add",
                -Function  => 'add',
                -Activated => 1,
            },

            {
                -Title     => 'Remove',
                -Title_URL => "$S_PROGRAM_URL?f=delete_email",
                -Function  => 'delete_email',
                -Activated => 1,
            },

            {
                -Title     => 'Options',
                -Title_URL => "$S_PROGRAM_URL?f=subscription_options",
                -Function  => 'subscription_options',
                -Activated => 0,
            },
        ]
    },

    {
        -Title     => 'Your Mailing List',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'List Information',
                -Title_URL => "$S_PROGRAM_URL?f=change_info",
                -Function  => 'change_info',
                -Activated => 1,
            },

            {
                -Title     => 'List Password',
                -Title_URL => "$S_PROGRAM_URL?f=change_password",
                -Function  => 'change_password',
                -Activated => 1,
            },

            {
                -Title     => 'Options',
                -Title_URL => "$S_PROGRAM_URL?f=list_options",
                -Function  => 'list_options',
                -Activated => 1,
            },

            {
                -Title     => 'Delete This Mailing List',
                -Title_URL => "$S_PROGRAM_URL?f=delete_list",
                -Function  => 'delete_list',
                -Activated => 0,
            },
        ]
    },

    {
        -Title     => 'Mail Sending',
        -Activated => 1,
        -Submenu   => [

            {
                -Title     => 'Options',
                -Title_URL => "$S_PROGRAM_URL?f=sending_preferences",
                -Function  => 'sending_preferences',
                -Activated => 1,
            },

            {
                -Title     => 'Advanced Options',
                -Title_URL => "$S_PROGRAM_URL?f=adv_sending_preferences",
                -Function  => 'adv_sending_preferences',
                -Activated => 1,
            },
            {
                -Title     => 'Mass Mailing Options',
                -Title_URL => "$S_PROGRAM_URL?f=mass_mailing_preferences",
                -Function  => 'mass_mailing_preferences',
                -Activated => 1,
            },
        ]
    },

    {
        -Title     => 'Message Archives',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'View',
                -Title_URL => "$S_PROGRAM_URL?f=view_archive",
                -Function  => 'view_archive',
                -Activated => 1,
            },

            {
                -Title     => 'Options',
                -Title_URL => "$S_PROGRAM_URL?f=archive_options",
                -Function  => 'archive_options',
                -Activated => 1,
            },

            {
                -Title     => 'Advanced Options',
                -Title_URL => "$S_PROGRAM_URL?f=adv_archive_options",
                -Function  => 'adv_archive_options',
                -Activated => 1,
            },
        ]
    },

    {
        -Title     => 'Appearance and Templates',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'Your Mailing List Template',
                -Title_URL => "$S_PROGRAM_URL?f=edit_template",
                -Function  => 'edit_template',
                -Activated => 1,
            },

            {
                -Title     => 'Email Message Templates',
                -Title_URL => "$S_PROGRAM_URL?f=edit_type",
                -Function  => 'edit_type',
                -Activated => 1,
            },

            {
                -Title     => 'HTML Screen Templates',
                -Title_URL => "$S_PROGRAM_URL?f=edit_html_type",
                -Function  => 'edit_html_type',
                -Activated => 1,
            },

            {
                -Title     => 'Subscription Form HTML',
                -Title_URL => "$S_PROGRAM_URL?f=html_code",
                -Function  => 'html_code',
                -Activated => 1,
            },

            {
                -Title     => 'Create a Back Link',
                -Title_URL => "$S_PROGRAM_URL?f=back_link",
                -Function  => 'back_link',
                -Activated => 1,
            },

        ]
    },

    {
        -Title     => 'Profiles',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'Profile Fields',
                -Title_URL => "$S_PROGRAM_URL?f=profile_fields",
                -Function  => 'profile_fields',
                -Activated => 1,
            },
        ]
    },
    {
        -Title     => 'Plugins',
        -Activated => 1,
        -Submenu   => [

            #					# These are plugins. Make sure you install them
            #					# if you want to use them!

            #					{
            #					-Title      => 'Mailing Monitor',
            #					-Title_URL  => $PLUGIN_URL."/mailing_monitor.cgi",
            #					-Function   => 'mailing_monitor',
            #					-Activated  => 0,
            #					},

            #					{
            #					-Title      => 'Tracker',
            #					-Title_URL  => $PLUGIN_URL."/tracker.cgi",
            #					-Function   => 'tracker',
            #					-Activated  => 1,
            #					},

            #					{
            #					-Title      => 'Bounce Handler',
            #					-Title_URL  => $PLUGIN_URL."/bounce_handler.cgi",
            #					-Function   => 'bounce_handler',
            #					-Activated  => 1,
            #					},

            #					{
            #					-Title      => 'Bridge',
            #					-Title_URL  => $PLUGIN_URL."/bridge.cgi",
            #					-Function   => 'bridge',
            #					-Activated  => 1,
            #					},

            #					{
            #					-Title      => 'Scheduled Mailings',
            #					-Title_URL  => $PLUGIN_URL."/scheduled_mailings.pl",
            #					-Function   => 'scheduled_mailings',
            #					-Activated  => 1,
            #					},

            #					{
            #					-Title      => 'Change the Program Root Password',
            #					-Title_URL  => $PLUGIN_URL."/change_root_password.cgi",
            #					-Function   => 'change_root_password',
            #					-Activated  => 0,
            #					},

            #					{
            #					-Title      => 'Change Your List Short Name',
            #					-Title_URL  => $PLUGIN_URL."/change_list_shortname.cgi",
            #					-Function   => 'change_list_shortname',
            #					-Activated  => 0,
            #					},

          #					{
          #					-Title      => 'Default Mass Mailing Messages',
          #					-Title_URL  => $PLUGIN_URL."/default_mass_mailing_messages.cgi",
          #					-Function   => 'default_mass_mailing_messages',
          #					-Activated  => 1,
          #					},

           #					{
           #					-Title      => 'Password Protect Directories',
           #					-Title_URL  => $PLUGIN_URL."/password_protect_directories.cgi",
           #					-Function   => 'password_protect_directories',
           #					-Activated  => 1,
           #					},

            #					{
            #					-Title      => 'View Logs',
            #					-Title_URL  => $PLUGIN_URL."/log_viewer.cgi",
            #					-Function   => 'log_viewer',
            #					-Activated  => 1,
            #					},


            #					{
            #					-Title      => 'Screen Cache',
            #					-Title_URL  => $PLUGIN_URL."/screen_cache.cgi",
            #					-Function   => 'screen_cache',
            #					-Activated  => 0,
            #					},


            #					{
            #					-Title      => 'Boilerplate Example',
            #					-Title_URL  => $PLUGIN_URL."/boilerplate_plugin.cgi",
            #					-Function   => 'boilerplate',
            #					-Activated  => 1,
            #					},


            #					{
            #					-Title      => 'View List Settings',
            #					-Title_URL  => $PLUGIN_URL."/view_list_settings.cgi",
            #					-Function   => 'view_list_settings',
            #					-Activated  => 1,
            #					},





        ],
    },

    # Shortcut to the Extensions. Make sure you install them
    # if you want to use them!

    {
        -Title     => 'Extensions',
        -Activated => 1,
        -Submenu   => [

            #					{
            #					-Title      => 'Multiple Subscribe',
            #					-Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
            #					-Function   => 'multiple_subscribe',
            #					-Activated  => 1,
            #					},

#					{
#					-Title      => 'Archive Blog Index',
#					-Title_URL  => $EXT_URL."/blog_index.cgi?mode=html&list=<!-- tmpl_var list_settings.list -->",
#					-Function   => 'blog_index',
#					-Activated  => 1,
#					},

        ],
    },

    {
        -Title     => 'Your List Control Panel',
        -Activated => 0,
        -Submenu   => [
            {
                -Title     => 'Customize Feature Set',
                -Title_URL => "$S_PROGRAM_URL?f=feature_set",
                -Function  => 'feature_set',
                -Activated => 0,
            },

            {
                -Title     => 'Options',
                -Title_URL => "$S_PROGRAM_URL?f=list_cp_options",
                -Function  => 'list_cp_options',
                -Activated => 0,
            }
        ],
    },

    {
        -Title     => 'App Information',
        -Activated => 1,
        -Submenu   => [
            {
                -Title     => 'Configuration',
                -Title_URL => "$S_PROGRAM_URL?f=setup_info",
                -Function  => 'setup_info',
                -Activated => 1,
            },

            {
                -Title     => 'About Dada Mail',
                -Title_URL => "$S_PROGRAM_URL?f=manage_script",
                -Function  => 'manage_script',
                -Activated => 1,
            },

        ],
    },
];

$LIST_QUOTA            ||= undef;
$SUBSCRIPTION_QUOTA    ||= undef;
$MAILOUT_AT_ONCE_LIMIT ||= 1;
$MAILOUT_STALE_AFTER   ||= 86400;

$EMAIL_CASE ||= 'lc_all';

@EMAIL_EXCEPTIONS = qw()
  unless scalar @EMAIL_EXCEPTIONS;

$LIST_IN_ORDER ||= 0;

$FILE_CHMOD ||= 0666;
$DIR_CHMOD  ||= 0755;

$HTML_CHARSET ||= 'UTF-8';

# http://www.w3.org/International/O-charset.html
# http://www.w3.org/International/O-HTTP-charset

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

$HTML_TEXTTOHTML_OPTIONS ||= {
    escape_HTML_chars => 0,    # This will also be overridden to, 0 by Dada Mail
                               # BUT! Dada Mail will provide it's own
                               # escape_HTML_chars-like routine

};

$HTML_SCRUBBER_OPTIONS ||= {
    rules   => [ script => 0, ],
    default => [
        1 => {
            '*' => 1,          # default rule, allow all attributes
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

$DEFAULT_MIME_TYPE ||= 'application/octet-stream';
$MIME_PARANOID     ||= 0;
$MIME_HUSH         ||= 0;
$MIME_OPTIMIZE     ||= 'no tmp files';

$SUBSCRIBED_MESSAGE ||= <<EOF
Hello!

Your mailing list subscription for the address, 

	<!-- tmpl_var subscriber.email -->
	
to the mailing list: 

	<!-- tmpl_var list_settings.list_name -->

is complete. Thanks for subscribing! 

<!-- tmpl_if list_settings.group_list --> 
* This mailing list is a group discussion list <!-- tmpl_if list_settings.enable_moderation -->(moderated)<!-- tmpl_else -->(unmoderated)<!-- /tmpl_if -->. You can start a new thread, by sending an email message to, <!-- tmpl_var list_settings.discussion_pop_email --> 
<!-- tmpl_else --> 
* This mailing list is an announce-only mailing list. 
<!-- /tmpl_if -->

Please save this email message for future reference. 

* Date of this subscription: 
<!-- tmpl_var date -->

* Need Help? Contact: 
<!-- tmpl_var list_settings.list_owner_email -->

* Unsubscribe at any time, by visiting: 
<!-- tmpl_var list_unsubscribe_link --> 

<!-- tmpl_if PROFILE_ENABLED --><!-- tmpl_if new_profile --> 
* Check out your Profile to update your subscription information: 

	Profile Login: <!-- tmpl_var PROGRAM_URL -->/profile_login/<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/
	Username: <!-- tmpl_var profile.email --> 
	Password: <!-- tmpl_var profile.password --> 
<!-- /tmpl_if --><!-- /tmpl_if --> 

* Privacy Policy: 
<!-- tmpl_var list_settings.privacy_policy -->

* Physical Address:
<!-- tmpl_var list_settings.physical_address -->

Thanks! 
- <!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$SUBSCRIBED_BY_LIST_OWNER_MESSAGE ||= <<EOF
Hello!

Your email address

	<!-- tmpl_var subscriber.email -->
	
has just been subscribed to the mailing list: 

	<!-- tmpl_var list_settings.list_name -->

<!-- tmpl_if list_settings.group_list --> 
* This mailing list is a group discussion list <!-- tmpl_if list_settings.enable_moderation -->(moderated)<!-- tmpl_else -->(unmoderated)<!-- /tmpl_if -->. You can start a new thread, by sending an email message to, <!-- tmpl_var list_settings.discussion_pop_email --> 
<!-- tmpl_else --> 
* This mailing list is an announce-only mailing list. 
<!-- /tmpl_if -->

Please save this email message for future reference. 

* Date of this subscription: 
<!-- tmpl_var date -->

* Need Help? Contact: 
<!-- tmpl_var list_settings.list_owner_email -->

<!-- tmpl_if PROFILE_ENABLED --><!-- tmpl_if new_profile --> 
* Check out your Profile to update your subscription information: 

	Profile Login: <!-- tmpl_var PROGRAM_URL -->/profile_login/<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/
<!-- /tmpl_if --><!-- /tmpl_if --> 

* Privacy Policy: 
<!-- tmpl_var list_settings.privacy_policy -->

* Physical Address:
<!-- tmpl_var list_settings.physical_address -->

Thanks! 
- <!-- tmpl_var list_settings.list_owner_email -->
EOF
  ;

$UNSUBSCRIBED_BY_LIST_OWNER_MESSAGE ||= <<EOF
Hello, 

Your email address, 

	<!-- tmpl_var subscriber.email -->
	
has been removed from the mailing list: 

	<!-- tmpl_var list_settings.list_name --> 

Date of this removal: <!-- tmpl_var date --> 

- mailto:<!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE ||= <<EOF

Hello, 

The following email address:

	<!-- tmpl_var subscriber.email -->

Would like to subscribe to: 

	<!-- tmpl_var list_settings.list_name -->
	
If you haven't yet, log into your list:

<!-- tmpl_var S_PROGRAM_URL -->?f=sign_in&list=<!-- tmpl_var list_settings.list -->

-----------------------------------------------------------------------------

To approve this subscription, follow this link: 
	
	<!-- tmpl_var S_PROGRAM_URL -->?f=subscription_requests&process=approve&address=<!-- tmpl_var subscriber.email -->&list=<!-- tmpl_var list_settings.list -->

To deny this subscription, follow this link: 

	<!-- tmpl_var S_PROGRAM_URL -->?f=subscription_requests&process=deny&address=<!-- tmpl_var subscriber.email -->&list=<!-- tmpl_var list_settings.list -->

To view all addresses awaiting approval for subscription, please visit: 

	<!-- tmpl_var S_PROGRAM_URL -->?f=view_list&type=sub_request_list&list=<!-- tmpl_var list_settings.list -->

-- <!-- tmpl_var PROGRAM_NAME -->		

EOF
  ;

$SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE = undef;

$SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT ||=
  'Subscribed <!-- tmpl_var subscriber.email -->';
$SUBSCRIPTION_NOTICE_MESSAGE ||= <<EOF
<!-- tmpl_var subscriber.email --> has subscribed to:

	<!-- tmpl_var list_settings.list_name -->

Server Time: <!-- tmpl_var date -->
IP Logged:   <!-- tmpl_var REMOTE_ADDR -->
<!-- tmpl_var note -->

<!-- tmpl_if subscriber -->Extra Subscriber information: 
-----------------------------
<!-- tmpl_loop subscriber --> 
<!-- tmpl_var name -->: <!-- tmpl_var value -->

<!-- /tmpl_loop -->-----------------------------<!--/tmpl_if-->

There are now a total of: <!-- tmpl_var num_subscribers --> subscribers.

-<!-- tmpl_var PROGRAM_NAME -->

EOF
  ;
$UNSUBSCRIPTION_NOTICE_MESSAGE_SUBJECT ||= 'Unsubscribed <!-- tmpl_var subscriber.email -->';
$UNSUBSCRIPTION_NOTICE_MESSAGE ||= <<EOF
<!-- tmpl_var subscriber.email --> has been unsubscribed from:

	<!-- tmpl_var list_settings.list_name -->

Server Time: <!-- tmpl_var date -->
IP Logged:   <!-- tmpl_var REMOTE_ADDR -->
<!-- tmpl_var note -->

There are now a total of: <!-- tmpl_var num_subscribers --> subscribers.

-<!-- tmpl_var PROGRAM_NAME -->

EOF
  ;

$UNSUBSCRIBED_MESSAGE ||= <<EOF

The removal of the email address:

	<!-- tmpl_var subscriber.email -->
	
from the mailing list: 

	<!-- tmpl_var list_settings.list_name --> 

is complete.

You may wish to save this email message for future reference.

-----------------------------------------------------------------------

Date of this removal: <!-- tmpl_var date --> 

You may re-subscribe to this list at any time by 
visiting the following URL:

<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->

If you're still having trouble, please contact the List Owner at: 

	mailto:<!-- tmpl_var list_settings.list_owner_email -->

The following physical address is associated with this mailing list: 

<!-- tmpl_var list_settings.physical_address -->

- mailto:<!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$CONFIRMATION_MESSAGE ||= <<EOF
Hello! 

This message has been sent to you as the final step to confirm your
email list subscription for the following list: 

<!-- tmpl_var list_settings.list_name -->

To confirm this subscription, please follow the URL below:

<!-- tmpl_var list_confirm_subscribe_link -->

(Click the URL above, or copy and paste the URL into your browser. 
Doing so will subscribe you to this list.)

-----------------------------------------------------------------------

The following is the description given for this list: 

<!-- tmpl_var list_settings.info -->

-----------------------------------------------------------------------

This email is part of a Closed-Loop Opt-In system and was sent to protect 
the privacy of the owner of this email address. Closed-Loop Opt-In confirmation 
guarantees that only the owner of an email address can subscribe themselves
to this mailing list.

Furthermore, the following privacy policy is associated with this list: 

<!-- tmpl_var list_settings.privacy_policy -->

Please read and understand this privacy policy. Other mechanisms may 
have been enacted to subscribe email addresses to this list, such as
physical guestbook registrations, verbal agreements, etc.

If you did not ask to be subscribed to this particular list, please
do not visit the confirmation URL above. The confirmation for 
subscription will not go through and no other action on your part 
will be needed.

To contact the owner of this email list, please use the address below: 

mailto:<!-- tmpl_var list_settings.list_owner_email -->

The following physical address is associated with this mailing list: 

<!-- tmpl_var list_settings.physical_address -->

- <!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;
$UNSUBSCRIPTION_REQUEST_MESSAGE_SUBJECT ||= 'Unsubscribe from: <!-- tmpl_var list_settings.list_name -->';
$UNSUBSCRIPTION_REQUEST_MESSAGE ||= <<EOF
Hello, 

Please use this link:

	<!-- tmpl_var list_unsubscribe_link -->

to remove: 

	<!-- tmpl_var subscriber.email -->

 from the following list: 

	<!-- tmpl_var list_settings.list_name -->

To contact the owner of this email list, please use the address below: 

mailto:<!-- tmpl_var list_settings.list_owner_email -->

The following physical address is associated with this mailing list: 

<!-- tmpl_var list_settings.physical_address -->


- mailto:<!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$SUBSCRIPTION_REQUEST_APPROVED_MESSAGE ||= $SUBSCRIBED_MESSAGE;
$SUBSCRIPTION_REQUEST_DENIED_MESSAGE   ||= <<EOF
Hello! 

You've recently have asked to be subscribed to: 

	<!-- tmpl_var list_settings.list_name --> 
	
This subscription request has been denied by the List Owner. 

-- mailto:<!-- tmpl_var list_settings.list_owner_email --> 

EOF
  ;

$MAILING_LIST_MESSAGE ||= <<EOF
(Mailing list information, including how to remove yourself, is located at the end of this message.)
__ 

<!-- tmpl_var message_body -->

-- 
<!-- tmpl_if list_settings.show_archives --><!-- tmpl_if list_settings.archive_send_form --> 
Forward this Message to a Friend:
<!-- tmpl_var forward_to_a_friend_link -->
<!-- /tmpl_if --><!-- /tmpl_if -->
Subscription Reminder: You're Subscribed to, <!-- tmpl_var list_settings.list_name --> 
Using the address: <!-- tmpl_var subscriber.email -->

From: <!-- tmpl_var list_settings.list_owner_email -->
<!-- tmpl_var list_settings.physical_address -->

Unsubscribe Automatically:
<!-- tmpl_var list_unsubscribe_link -->

EOF
  ;

$MAILING_LIST_MESSAGE_HTML ||= <<EOF
<!--opening-->
<p style="font:.8em/1.6em Helvetica,Verdana,'Sans-serif'">
 <em>
  (Mailing list information, including how to remove yourself, 
is located at the end of this message.)
  </em>
</p>
<!--/opening-->


<!-- tmpl_var message_body -->


<!--signature-->

<!-- tmpl_if list_settings.show_archives --> 
	<!-- tmpl_if list_settings.archive_send_form --> 
	
		<p style="font:.8em/1.6em Helvetica,Verdana,'Sans-serif'">
		 <strong>
		  <a href="<!-- tmpl_var forward_to_a_friend_link -->">
		   Forward this Message to a Friend &#187;
		  </a>
		 </strong>
		</p>
		
	<!-- /tmpl_if --> 
<!-- /tmpl_if --> 

<p style="font:.8em/1.6em Helvetica,Verdana,'Sans-serif'">
 <strong>
  Subscription Reminder:</strong> You're Subscribed to:
 <strong>
  <a href="<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/"> 
  <!-- tmpl_var list_settings.list_name -->
 </a>
 </strong> 
 using the address: 
 <strong>
  <!-- tmpl_var subscriber.email --> 
 </strong>
</p>

<p style="font:.8em/1.6em Helvetica,Verdana,'Sans-serif'">
 From: 
 <strong>
  <!-- tmpl_var list_settings.list_owner_email -->
 </strong>
<br />
<!-- tmpl_var list_settings.physical_address -->
</p>

<p style="font:.8em/1.6em Helvetica,Verdana,'Sans-serif'">

<!-- tmpl_if PROFILE_ENABLED --> 
<strong>
 <a href="<!-- tmpl_var PROGRAM_URL -->/profile_login/<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/">Manage Your Subscription &#187;</a>
 </strong>
 
 or, 
<!-- /tmpl_if --> 

<strong>
 <a href="<!-- tmpl_var list_unsubscribe_link -->">
  Unsubscribe Automatically &#187;
 </a>
</strong> </p> 

<!--/signature-->

EOF
  ;

$MODERATION_MSG ||= <<EOF

The attached message needs to be moderated:

    List:    <!-- tmpl_var list_settings.list_name -->
    From:    <!-- tmpl_var subscriber.email -->
    Subject: <!-- tmpl_var message_subject -->

To send this message to the list, click here: 

    <!-- tmpl_var moderation_confirmation_link -->
    
To deny sending this message to the list, click here: 

    <!-- tmpl_var moderation_deny_link -->

-- <!-- tmpl_var Plugin_Name --> 

EOF
  ;
$AWAIT_MODERATION_MSG ||= <<EOF

Hello, 

Your recent message to <!-- tmpl_var list_settings.list_name --> with the subject of: 

    <!-- tmpl_var message_subject --> 
  
is awaiting approval. 

-- <!-- tmpl_var Plugin_Name -->

EOF
  ;

$ACCEPT_MSG ||= <<EOF

Hello, 

Your recent message to <!-- tmpl_var list_settings.list_name --> with the subject of: 

    <!-- tmpl_var message_subject -->
    
was accepted by the List Owner. It will be forwarded to the list soon. 

-- <!-- tmpl_var Plugin_Name -->

EOF
  ;

$REJECTION_MSG ||= <<EOF

Hello, 

Your recent message to <!-- tmpl_var list_settings.list_name --> with the subject of: 

    <!-- tmpl_var message_subject -->
    
was rejected by the List Owner. You may email the List Owner at: 

    <!-- tmpl_var list_settings.list_owner_email -->
    
for more details. 

-- <!-- tmpl_var Plugin_Name -->

EOF
  ;

$MSG_TOO_BIG_MSG ||= <<EOF

Hello, <!-- tmpl_var subscriber.email -->, 

We've received a message from you with the Subject,

	<!-- tmpl_var original_subject -->
		
but couldn't deliver it to the mailing list because the size of the message, 

	<!-- tmpl_var size_of_original_message --> kilobytes

is larger than the maximum allowed: 

	<!-- tmpl_var Soft_Max_Size_Of_Any_Message --> kilobytes

Please try to resend the message again, but within the maximum size allowed, 

-- <!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$MSG_LABELED_AS_SPAM_MSG = <<EOF

Hello, <!-- tmpl_var subscriber.email -->, 

We've received a message from you with the Subject,

	<!-- tmpl_var original_subject -->
		
but couldn't deliver it to the mailing list because it hit the spam filters and seems 
suspicious. 

If you did not send a message with this subject, please disregard this message. 

-- <!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$NOT_ALLOWED_TO_POST_MSG ||= <<EOF

Hello, 

You recently sent a message to, 

	<!-- tmpl_var list_settings.list_name --> (<!-- tmpl_var list_settings.discussion_pop_email -->)
	
with the email address: 

    <!-- tmpl_var subscriber.email -->

But, it doesn't seem that you currently have permission to do so. 

This may be because you have to first Subscribe to this Mailing List before
sending messages to it.

Please see: 

	<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->

for more information. 

You may email the List Owner at: 

	mailto:<!-- tmpl_var list_settings.list_owner_email -->

	-- <!-- tmpl_var PROGRAM_NAME -->

EOF
  ;

$NOT_ALLOWED_TO_POST_NOTICE_MSG ||= <<EOF

The attached message was sent to your Mailing List, 

	<!-- tmpl_var list_settings.list_name -->
	
but was not sent from an address that has permission to do so. 

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
  ;

$YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE ||= <<EOF

Hello, 

This message has been sent to you because a request to subscribe: 

<!-- tmpl_var subscriber.email -->

to the list: 

<!-- tmpl_var list_settings.list_name -->

was just made. This email address is actually already subscribed, 
so you do not have to subscribe again. This message has been sent 
to protect your privacy and only allow this information to be 
available to you. 

To contact the owner of this email list, please use the address below: 

mailto:<!-- tmpl_var list_settings.list_owner_email -->


- <!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$YOU_ARE_NOT_SUBSCRIBED_MESSAGE ||= <<EOF

Hello, 

This message has been sent to you because a request to remove: 

<!-- tmpl_var subscriber.email -->

from the list: 

<!-- tmpl_var list_settings.list_name -->

was just made. This email address is actually not currently subscribed.

This message has been sent to protect your privacy and only allow this information to be 
available to you. 

To contact the owner of this email list, please use the address below: 

mailto:<!-- tmpl_var list_settings.list_owner_email -->

EOF
  ;

$MAILING_FINISHED_MESSAGE_SUBJECT ||=
'<!-- tmpl_var list_settings.list_name -->  Mailing Complete - <!-- tmpl_var message_subject -->';
$MAILING_FINISHED_MESSAGE ||= <<EOF
Your mailing list's mass mailing has completed. 
-----------------------------------------------------------------------
This mass mailing has reached: <!-- tmpl_var addresses_sent_to --> e-mail address(es)

Mailing Started:    <!-- tmpl_var mailing_start_time -->
Mailing Ended:      <!-- tmpl_var mailing_finish_time -->
Total Mailing Time: <!-- tmpl_var total_mailing_time -->
Last Email Sent to: <!-- tmpl_var last_email_send_to -->

A copy of the mailing list message has been attached.

-<!-- tmpl_var PROGRAM_NAME -->

EOF
  ;

$TEXT_INVITE_MESSAGE ||= <<EOF
Hello!

The List Owner of, "<!-- tmpl_var list_settings.list_name -->" (<!-- tmpl_var list_settings.list_owner_email -->) has invited you to Subscribe!
 
* Here's a brief description of this mailing list: 

<!-- tmpl_var list_settings.info --> 

* If you'd like to subscribe, just click the link below: 
<!-- tmpl_var list_confirm_subscribe_link --> 

<!-- tmpl_if list_settings.group_list --> 
* This mailing list is a group discussion list <!-- tmpl_if list_settings.enable_moderation -->(moderated)<!-- tmpl_else -->(unmoderated)<!-- /tmpl_if -->. Once subscribed, you can start a new thread, by sending an email message to, <!-- tmpl_var list_settings.discussion_pop_email --> 
<!-- tmpl_else --> 
* This mailing list is an announce-only mailing list. 
<!-- /tmpl_if --> 

* Want more information? Visit:
<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/

* Privacy Policy: 
<!-- tmpl_var list_settings.privacy_policy -->

* Physical Address:
<!-- tmpl_var list_settings.physical_address -->

Thanks! 

- <!-- tmpl_var list_settings.list_owner_email -->
EOF
;

$PROFILE_ACTIVATION_MESSAGE_SUBJECT ||=
  'Profile Authorization Code for, <!-- tmpl_var profile.email -->';
$PROFILE_ACTIVATION_MESSAGE ||= <<EOF

Hello, here's the authorization link to activate your <!-- tmpl_var PROGRAM_NAME --> Profile: 

<!-- tmpl_var app.profile_activation_link --> 

-- <!-- tmpl_var PROGRAM_NAME --> 

EOF
;

$PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT ||=
  'Profile Authorization Code for, <!-- tmpl_var profile.email -->';
$PROFILE_RESET_PASSWORD_MESSAGE ||= <<EOF
Hello, here's the authorization link to reset your <!-- tmpl_var PROGRAM_NAME --> Profile Password:

<!-- tmpl_var app.profile_reset_password_link -->

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
;

$PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT ||=
'Profile Update Email Authorization Code for, <!-- tmpl_var profile.email -->';
$PROFILE_UPDATE_EMAIL_MESSAGE ||= <<EOF

Hello, here's the authorization link to update your <!-- tmpl_var PROGRAM_NAME --> Profile email address from: 

	<!-- tmpl_var profile.email --> 
	
to: 

	<!-- tmpl_var profile.updated_email --> 
	
Please click the link below to make this update: 	

<!-- tmpl_var app.profile_update_email_link -->

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
;

$PROFILE_EMAIL_UPDATED_NOTIFICATION_MESSAGE_SUBJECT ||=
'Profile Email Update Notification, From: <!-- tmpl_var profile.prev_email -->, To: <!-- tmpl_var profile.email -->';
$PROFILE_EMAIL_UPDATED_NOTIFICATION_MESSAGE ||= <<EOF

Hello, a Profile's address has been updated from: 

	<!-- tmpl_var profile.prev_email -->
	
to: 

	<!-- tmpl_var profile.email -->

This change will have affected all mailing lists that this is allowed, 

-- <!-- tmpl_var PROGRAM_NAME -->


EOF
  ;

$LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT ||=
'<!-- tmpl_var list_settings.list_name --> Mailing List Confirmation Password Reset';
$LIST_CONFIRM_PASSWORD_MESSAGE ||= <<EOF
Hello, 

Someone has asked for the <!-- tmpl_var PROGRAM_NAME --> Mailing List Password for:

	<!-- tmpl_var list_settings.list_name -->
 
to be reset and emailed to this address. 

To confirm this List Password Rest, please visit this URL: 

<!-- tmpl_var S_PROGRAM_URL -->?f=email_password&l=<!-- tmpl_var list_settings.list -->&pass_auth_id=<!-- tmpl_var random_string -->

A new, automatically generated Mailing List Password will then be emailed to you. 

If you do not want this to happen, do not visit this URL. 

This request for the password change was done from:

    Remote Host:<!-- tmpl_var REMOTE_HOST --> 
    IP Address: <!-- tmpl_var REMOTE_ADDR --> 
  

-<!-- tmpl_var PROGRAM_NAME --> 

EOF
  ;

$LIST_RESET_PASSWORD_MESSAGE_SUBJECT ||=
  '<!-- tmpl_var list_settings.list_name --> Mailing List Password Reset';
$LIST_RESET_PASSWORD_MESSAGE ||= <<EOF

The Mailing List Password for, 

	<!-- tmpl_var list_settings.list_name --> 
 
has been reset to: 

	<!-- tmpl_var new_password -->

You may change this automatically generated password to a more memorable 
password in the List Control Panel. 

Please be sure to delete this email for security reasons. 

-<!-- tmpl_var PROGRAM_NAME --> 

EOF
  ;

$HTML_INVITE_MESSAGE ||= <<EOF
<p>
 Hello!
</p>

<p>
 The List Owner of, &quot;
  <strong>
   <!-- tmpl_var list_settings.list_name -->
  </strong>
  &quot; (
  <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
   <!-- tmpl_var list_settings.list_owner_email -->
  </a>
 ) has invited you to Subscribe!
</p>

<ul> 
 <li>
  <p>
   Here's a brief description of this mailing list: 
  </p>

<blockquote> 
<!-- tmpl_var list_settings.info --> 
</blockquote> 

</li> 

<li> 
 <p>
  <strong> 
   If you'd like to subscribe, just click the link below: 
  </strong>
 </p> 
 <p>
  <strong> 
   <a href="<!-- tmpl_var list_confirm_subscribe_link -->">
    <!-- tmpl_var list_confirm_subscribe_link -->
   </a>
  </strong>
 </p>
</li>

<li>

<!-- tmpl_if list_settings.group_list --> 

	<p>
	 This mailing list is a group discussion list 
	<!-- tmpl_if list_settings.enable_moderation -->
		(moderated)
	<!-- tmpl_else -->
		(unmoderated)
	<!-- /tmpl_if -->.
		Once subscribed, you can start a new thread, by sending an email message to,</p>
		<ul> 
		 <li> 
		  <a href="mailto:<!-- tmpl_var list_settings.discussion_pop_email -->">
		   <!-- tmpl_var list_settings.discussion_pop_email -->
		  </a>
		 </li>
		</ul>
<!-- tmpl_else -->
	<p>This mailing list is an announce-only mailing list.</p>
<!-- /tmpl_if --> 
</li>

<li>
 <p>
  <strong>
   Want more information? Visit:
  </strong>
 </p>
  <a href="<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/">
   <!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/
  </a> 
 </p> 
</li>

<li>
 <p>
  <strong>
   Privacy Policy:
  </strong>
 </p>

 <blockquote> 
  <!-- tmpl_var list_settings.privacy_policy -->
 </blockquote> 
</li>

<li>
 <p>
  <strong>
   Physical Address:
  </strong>
 </p>
 <blockquote> 
  <!-- tmpl_var list_settings.physical_address -->
 </blockquote> 
</li>

</ul> 

<p>
 <strong>
  Thanks!
 </strong>
</p>


<p>-<a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->"><!-- tmpl_var list_settings.list_owner_email --></a></p> 

EOF
  ;

$SENDING_PREFS_MESSAGE_SUBJECT ||=
'Sending Preference Test Email for, <!-- tmpl_var list_settings.list_name -->';
$SENDING_PREFS_MESSAGE ||= <<EOF
Hello, <!-- tmpl_var list_settings.list_owner_email -->, 

This message was sent out by <!-- tmpl_var PROGRAM_NAME --> to test out mail sending for the mailing list, 

		<!-- tmpl_var list_settings.list_name --> 
		
If you've received this message, it looks like mail sending is working. 

<!-- tmpl_if expr="(list_settings.sending_method eq 'sendmail')" --> 
	* Mail is being sent via the sendmail command
<!--/tmpl_if -->
<!-- tmpl_if expr="(list_settings.sending_method eq 'smtp')" --> 
	* Mail is being sent via SMTP
<!--/tmpl_if --> 
<!-- tmpl_if expr="(list_settings.sending_method eq 'amazon_ses')" --> 
	* Mail is being sent via Amazon Simple Email Service
<!--/tmpl_if -->

-- <!-- tmpl_var PROGRAM_NAME --> 
EOF
  ;

$SEND_ARCHIVED_MESSAGE ||= <<EOF

Hello, 

On behalf of: <!-- tmpl_var from_email -->, the following archived message from: 

<!-- tmpl_var list_settings.list_name --> 

has been sent to you. They wrote: 

<!-- tmpl_var note -->

The archived message is below. 

You can subscribe to <!-- tmpl_var list_settings.list_name --> by following this link:

<!-- tmpl_var list_subscribe_link -->

If you cannot view the archived message, please visit: 

<!-- tmpl_var archive_message_url -->

EOF
  ;

$HTML_SEND_ARCHIVED_MESSAGE ||= <<EOF

<p>Hello,</p> 

<p>On behalf of: <!-- tmpl_var from_email -->, the following archived message 
from:</p>

<p><!-- tmpl_var list_settings.list_name --></p>

<p>has been sent to you. They wrote:</p> 

<p>
 <em> 
  <!-- tmpl_var note -->
 </em> 
</p>

<p>The archived message is below.</p> 

<p>You can subscribe to <!-- tmpl_var list_settings.list_name --> by following this link:</p>

<p>
 <a href="<!-- tmpl_var list_subscribe_link -->">
  <!-- tmpl_var list_subscribe_link -->
 </a>.
</p>

<p>If you cannot view the archived message, please visit:</p>

<p><a href="<!-- tmpl_var archive_message_url -->"><!-- tmpl_var archive_message_url --></a></p>

EOF
  ;

$HTML_CONFIRMATION_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Please Confirm Your Mailing List Subscription" --> 

<p>An email message has been sent to the following address:</p>

<blockquote>
 <p>
  <strong>
  <!-- tmpl_var subscriber.email -->
  </strong>
 </p>
</blockquote>
 
<p>to confirm the subscription to the following list: </p>

<blockquote>
 <p>
  <strong>
  <!-- tmpl_var list_settings.list_name -->
  </strong>
 </p>
</blockquote>

<p>Upon receiving this message, you will need to follow a confirmation 
URL, located in the message itself.</p>

<p>This confirmation process, known as Closed-Loop Opt-In Confirmation, has 
been put into place to protect the privacy of the owner of this email 
address.</p>

<p>If you do not receive this confirmation, make sure that this email 
address: </p>

 <blockquote>
 <p>
  <strong>
   <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
    <!-- tmpl_var list_settings.list_owner_email -->
   </a>
  </strong>
 </p>
</blockquote>


<p>is in your 
 <strong> 
  address book
 </strong> 
 or 
 <strong> 
  whitelist
 </strong>
 .
</p>

<p>
 <strong> 
  <a href="<!-- tmpl_var PROGRAM_URL -->/subscriber_help/<!-- tmpl_var list_settings.list -->/">
   How to add <!-- tmpl_var list_settings.list_owner_email --> to your address book/white list
  </a>
 </strong> 
</p>

<p>If you still do not receive a confirmation for subscription in 
the next twenty-four hours or you have any other questions regarding 
this mailing list, please contact the List Owner at: </p>

<p style="text-align:center">
 <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
  <!-- tmpl_var list_settings.list_owner_email -->
 </a>
</p>

EOF
  ;

$HTML_UNSUBSCRIPTION_REQUEST_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Unsubscription Confirmation Sent" -->
<!-- tmpl_set name="show_profile_widget" value="0" --> 

<p>An email message has been sent to the following address:</p>

<blockquote>
 <p>
  <strong>
  <!-- tmpl_var subscriber.email -->
  </strong>
 </p>
</blockquote>
 
<p>to confirm that address's <em>removal</em> from the following list: </p>

<blockquote>
 <p>
  <strong>
  <!-- tmpl_var list_settings.list_name -->
  </strong>
 </p>
</blockquote>

<p>Upon receiving this message, you will need to follow a confirmation 
URL, located in the message itself.</p>

<p style="text-align:center">
 <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
  <!-- tmpl_var list_settings.list_owner_email -->
 </a>
</p>

EOF
  ;

$HTML_SUBSCRIBED_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Your Mailing List Subscription is Successful" -->

<p>You are now subscribed to the following mailing list:</p>

<blockquote>
 <p>
  <strong>
   <!-- tmpl_var list_settings.list_name -->
  </strong>
 </p>
</blockquote>

<p>using the following email address:</p>

<blockquote>  
 <p>
  <strong>
  <!-- tmpl_var subscriber.email -->
  </strong>
 </p>
</blockquote> 

EOF
  ;

$HTML_SUBSCRIPTION_REQUEST_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Your Request For Subscription is Complete" -->

<p>The List Owner for:</p>

<blockquote>
 <p>
  <strong>
   <!-- tmpl_var list_settings.list_name -->
  </strong>
 </p>
</blockquote>

<p>has been notified that you have requested a subscription for:</p>

<blockquote>  
 <p>
  <strong>
  <!-- tmpl_var subscriber.email -->
  </strong>
 </p>
</blockquote> 

<p>An email message will be sent to your address when you have been approved or denied a subscription</p>

EOF
  ;

$HTML_UNSUBSCRIBED_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Unsubscription is Successful" --> 

<p>The email address:</p>

<ul>
 <li>
  <!-- tmpl_var subscriber.email -->
 </li>
</ul> 

<p>
 Is no longer a part of: 
<p>

<ul>
 <li>
  <a href="<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/">
	<!-- tmpl_var list_settings.list_name -->
 </a>
 </li>
</ul> 

<p>
 Thanks for having been a subscriber.
</p> 

EOF
  ;

%LIST_SETUP_DEFAULTS = (

    list => '',    # don't default...
    info => '',

    # (Dummy)
    list_info => undef,

    admin_email      => undef,
    list_owner_email => '',
    privacy_policy   => '',
    list_name        => '',
    physical_address => '',
    password         => '',      # you'll need to encrypt it to use this...

    # Misc...

    cipher_key => undef,
    admin_menu => undef,

	# Mass Mailing Options
	mass_mailing_convert_plaintext_to_html => 0, 
	mass_mailing_block_css_to_inline_css   => 0, 
	
    #quotas
    use_subscription_quota => 0,
    subscription_quota     => 0,

    #mailing list options
    mx_check         => 0,
    closed_list      => 0,
    invite_only_list => 0,
    show_hidden      => 0,
    hide_list        => 0,

    email_your_subscribed_msg =>
      1,    # Notice the incorrect, "your" instead of, "you're" - doh!
    email_you_are_not_subscribed_msg => 0,

    send_unsub_success_email => 1,
    send_sub_success_email   => 1,

    get_sub_notice                => 1,
    send_subscription_notice_to   => 'list_owner',

	unsub_show_email_hint         => 1, 
    get_unsub_notice              => 1,
    send_unsubscription_notice_to => 'list_owner',

    enable_closed_loop_opt_in       => 1,    # Closed-Loop Opt-In
    skip_sub_confirm_if_logged_in   => 0,

    limit_sub_confirm                 => 1,
    limit_sub_confirm_use_captcha     => 1,

    use_alt_url_sub_confirm_success  => 0,
    alt_url_sub_confirm_success_w_qs => 0,
    alt_url_sub_confirm_success      => '',

    use_alt_url_sub_confirm_failed  => 0,
    alt_url_sub_confirm_failed_w_qs => 0,
    alt_url_sub_confirm_failed      => '',

    use_alt_url_sub_success  => 0,
    alt_url_sub_success_w_qs => 0,
    alt_url_sub_success      => '',

    use_alt_url_sub_failed  => 0,
    alt_url_sub_failed_w_qs => 0,
    alt_url_sub_failed      => '',

    use_alt_url_unsub_success  => 0,
    alt_url_unsub_success_w_qs => 0,
    alt_url_unsub_success      => '',

    enable_subscription_approval_step => 0,
    captcha_sub                       => 0,


    send_subscribed_by_list_owner_message   => 0,
    send_unsubscribed_by_list_owner_message => 0,

    send_last_archived_msg_mass_mailing => 0,

    # SMTP Options

    smtp_server => undef,
    smtp_port   => 25,

    use_smtp_ssl        => 0,
    use_pop_before_smtp => 0,

    pop3_server   => undef,
    pop3_username => undef,
    pop3_password => undef,
    pop3_use_ssl  => undef,

    # Can be set to,
    # BEST, PASS, APOP, or CRAM-MD5
    pop3_auth_mode => 'BEST',

    set_smtp_sender => 1,

    use_sasl_smtp_auth  => 0,
    sasl_auth_mechanism => 'PLAIN',
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

    # Auto-Pickup Dropped List Message Mailings
    auto_pickup_dropped_mailings => 1,

# Restart Mailings After Each Batch
# TODO - this variable should really be called, "reload_mailings_after_each_batch"
    restart_mailings_after_each_batch => 0,

    # sendmail, smtp, amazon_ses
    sending_method => 'sendmail',

    # Send a copy to the List Owner
    mass_mailing_send_to_list_owner => 1,

    amazon_ses_auto_batch_settings => 0,

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

    print_errors_to_header       => 0,
    print_return_path_header     => 0,
    plaintext_encoding           => 'quoted-printable',
    html_encoding                => 'quoted-printable',
    strip_message_headers        => 0,
    add_sendmail_f_flag          => 1,
    verp_return_path             => 0,
    use_domain_sending_tunings   => 0,
    domain_sending_tunings       => undef,
    mime_encode_words_in_headers => 1,

    # view list prefs

    view_list_subscriber_number => 100,

    # archive prefs

    archive_messages                       => 1,
    show_archives                          => 1,
    archives_available_only_to_subscribers => 0,
    archive_subscribe_form                 => 1,
    archive_search_form                    => 1,
    captcha_archive_send_form              => 0,
    archive_send_form                      => 0,
    send_newest_archive                    => 0,

    archive_show_second          => 0,
    archive_show_hour_and_minute => 0,
    archive_show_month           => 1,
    archive_show_day             => 1,
    archive_show_year            => 1,
    archive_index_count          => 10,

    sort_archives_in_reverse    => 1,
    disable_archive_js          => 1,
    style_quoted_archive_text   => 1,
    stop_message_at_sig         => 1,
    publish_archives_rss        => 1,
    ping_archives_rss           => 0,
    html_archives_in_iframe     => 0,
    display_attachments         => 1,
    add_subscribe_form_to_feeds => 1,

    add_social_bookmarking_badges => 1,

    # Can be set to, "none", "spam_me_not", or, "recaptcha_mailhide"
    archive_protect_email => 'spam_me_not',

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

    # white list
    enable_white_list => 0,

    # List Invite Prefs

    invites_check_for_already_invited => 1,
    invites_prohibit_reinvites        => 1,

    # Your Mailing List Template Prefs

    get_template_data => 'from_default_template',
    url_template      => '',

    # Create a Back Link prefs

    website_name => '',
    website_url  => '',

    #SQL stuff

    # I don't think this is honored...
    # Don't change.
    subscription_table => 'dada_subscribers',

    # Not used?
    hard_remove => 1,

    # Not used?
    merge_fields => '',

    fallback_field_values => '',

    # Email Templates

    confirmation_message_subject =>
'<!-- tmpl_var list_settings.list_name --> Mailing List Subscription Confirmation',
    confirmation_message => $CONFIRMATION_MESSAGE,

    subscription_request_approved_message_subject =>
      'Welcome to <!-- tmpl_var list_settings.list_name -->',
    subscription_request_approved_message =>
      $SUBSCRIPTION_REQUEST_APPROVED_MESSAGE,

    subscription_request_denied_message_subject =>
'<!-- tmpl_var list_settings.list_name --> Mailing List Subscription Request - Denied.',
    subscription_request_denied_message => $SUBSCRIPTION_REQUEST_DENIED_MESSAGE,
    subscription_approval_request_message_subject =>
'<!-- tmpl_var subscriber.email --> would like to subscribe to: <!-- tmpl_var list_settings.list_name -->',
    subscription_approval_request_message =>
      $SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE,

    subscribed_message_subject =>
      'Welcome to <!-- tmpl_var list_settings.list_name -->',
    subscribed_message => $SUBSCRIBED_MESSAGE,

    subscribed_by_list_owner_message_subject =>
      'Welcome to <!-- tmpl_var list_settings.list_name -->',
    subscribed_by_list_owner_message => $SUBSCRIBED_BY_LIST_OWNER_MESSAGE,

    unsubscribed_by_list_owner_message_subject =>
      'Unsubscribed from <!-- tmpl_var list_settings.list_name -->',
    unsubscribed_by_list_owner_message => $UNSUBSCRIBED_BY_LIST_OWNER_MESSAGE,

    unsubscribed_message_subject =>
      'Farewell from <!-- tmpl_var list_settings.list_name -->',
    unsubscribed_message => $UNSUBSCRIBED_MESSAGE,

    mailing_list_message_from_phrase =>
      '<!-- tmpl_var list_settings.list_name -->',
    mailing_list_message_to_phrase =>
      '<!-- tmpl_var list_settings.list_name --> Subscriber',
    mailing_list_message_subject =>
      '<!-- tmpl_var list_settings.list_name --> Message',
    mailing_list_message      => $MAILING_LIST_MESSAGE,
    mailing_list_message_html => $MAILING_LIST_MESSAGE_HTML,

    send_archive_message_subject =>
      '<!-- tmpl_var archived_message_subject --> (Archive)',

    you_are_already_subscribed_message_subject =>
      '<!-- tmpl_var list_settings.list_name --> - You Are Already Subscribed',
    you_are_already_subscribed_message => $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE,

    you_are_not_subscribed_message => $YOU_ARE_NOT_SUBSCRIBED_MESSAGE,
    you_are_not_subscribed_message_subject =>
      '<!-- tmpl_var list_settings.list_name --> - You Are Not Subscribed',

    admin_subscription_notice_message_subject =>
      'Subscribed <!-- tmpl_var subscriber.email -->',
    admin_subscription_notice_message => $SUBSCRIPTION_NOTICE_MESSAGE,

    admin_unsubscription_notice_message_subject =>
      'Unsubscribed <!-- tmpl_var subscriber.email -->',
    admin_unsubscription_notice_message => $UNSUBSCRIPTION_NOTICE_MESSAGE,

    enable_email_template_expr => 0,

    # HTML Screen Templates

    html_confirmation_message       => $HTML_CONFIRMATION_MESSAGE,

    html_subscribed_message   => $HTML_SUBSCRIBED_MESSAGE,
    html_unsubscribed_message => $HTML_UNSUBSCRIBED_MESSAGE,

    html_subscription_request_message => $HTML_SUBSCRIPTION_REQUEST_MESSAGE,

    send_archive_message      => $SEND_ARCHIVED_MESSAGE,
    send_archive_message_html => $HTML_SEND_ARCHIVED_MESSAGE,

    # Send a List Invitation

    invite_message_from_phrase => '<!-- tmpl_var list_settings.list_name -->',
    invite_message_to_phrase   => '<!-- tmpl_var list_settings.list_name -->',
    invite_message_text        => $TEXT_INVITE_MESSAGE,
    invite_message_html        => $HTML_INVITE_MESSAGE,
    invite_message_subject =>
'You\'ve been Invited to Subscribe to, "<!-- tmpl_var list_settings.list_name -->"',

    # Feature Set

    disabled_screen_view => 'grey_out',

    # List CP -> Options

    use_wysiwyg_editor    => 'ckeditor',
    enable_mass_subscribe => 0,

    # Send me the list password.
    pass_auth_id => undef,

### Plugins

    # Bridge Plugin:

    group_list => 0,

    open_discussion_list => 0,

    discussion_template_defang   => 1,
    only_allow_group_plain_text  => 0,
    mail_group_message_to_poster => 1,
    prefix_list_name_to_subject  => 1,

    no_prefix_list_name_to_subject_in_archives => 1,

    set_to_header_to_list_address        => 0,
    prefix_discussion_list_subjects_with => 'list_shortname',
    send_msgs_to_list                    => 1,
    disable_discussion_sending           => 1,
    mail_discussion_message_to_poster    => 1,

    ignore_spam_messages                => 0,
    find_spam_assassin_score_by         => 'looking_for_embedded_headers',
    ignore_spam_messages_with_status_of => 6,
    rejected_spam_messages              => 'ignore_spam',

    enable_moderation              => 0,
    moderate_discussion_lists_with => 'owner_email',
    send_moderation_msg            => 0,
    send_moderation_accepted_msg   => 0,
    send_moderation_rejection_msg  => 0,
    send_msg_copy_address          => '',

    enable_authorized_sending        => 0,
    authorized_sending_no_moderation => 0,
    subscriber_sending_no_moderation => 0,

    strip_file_attachments    => 0,
    file_attachments_to_strip => '',
    discussion_pop_server     => '',
    discussion_pop_username   => '',
    discussion_pop_email      => '',
    bridge_list_email_type    => 'pop3_account',
    discussion_pop_password   => '',

    discussion_pop_auth_mode => 'BEST',
    discussion_pop_use_ssl   => 0,

    send_not_allowed_to_post_msg => 0,
    send_invalid_msgs_to_owner   => 0,
    send_msg_copy_to             => 0,
    rewrite_anounce_from_header  => 1,
    discussion_clean_up_replies  => 0,

    not_allowed_to_post_msg_subject =>
'Not Allowed to Post On <!-- tmpl_var list_settings.list_name --> (your original message is attached)',
    not_allowed_to_post_msg => $NOT_ALLOWED_TO_POST_MSG,

    invalid_msgs_to_owner_msg_subject =>
'<!-- tmpl_var PROGRAM_NAME --> Error - <!-- tmpl_var subscriber.email --> Not Allowed to Post On <!-- tmpl_var list_settings.list_name --> (original message attached)',
    invalid_msgs_to_owner_msg => $NOT_ALLOWED_TO_POST_NOTICE_MSG,

    moderation_msg_subject =>
'Message on: <!-- tmpl_var list_settings.list_name --> needs to be moderated. (original message attached)',
    moderation_msg => $MODERATION_MSG,
    await_moderation_msg_subject =>
'Message to: <!-- tmpl_var list_settings.list_name --> w/ Subject: <!-- tmpl_var message_subject --> is awaiting approval.',
    await_moderation_msg => $AWAIT_MODERATION_MSG,
    accept_msg_subject =>
'Message to: <!-- tmpl_var list_settings.list_name --> w/ Subject: <!-- tmpl_var message_subject --> has been accepted.',
    accept_msg => $ACCEPT_MSG,
    rejection_msg_subject =>
'Message to: <!-- tmpl_var list_settings.list_name --> Subject: <!-- tmpl_var message_subject --> rejected.',
    rejection_msg => $REJECTION_MSG,
    msg_too_big_msg_subject =>
'Message to: <!-- tmpl_var list_settings.list_name -->  Subject: <!-- tmpl_var original_subject --> rejected',
    msg_too_big_msg => $MSG_TOO_BIG_MSG,
    msg_labeled_as_spam_msg_subject =>
'Message to: <!-- tmpl_var list_settings.list_name -->  Subject: <!-- tmpl_var original_subject --> Labeled as Spam',
    msg_labeled_as_spam_msg => $MSG_LABELED_AS_SPAM_MSG,

    # Tracker
    tracker_record_view_count                       => 10,

    tracker_auto_parse_links                        => 1,
    tracker_track_opens_method                      => 'directly',

    tracker_track_email                             => 1,

    tracker_clean_up_reports                        => 1,
    tracker_show_message_reports_in_mailing_monitor => 0,

    #	tracker_enable_data_cache                           => 1,
    #	tracker_dada_cache_expires                          => 1, # in hours

    # Bounce Handler

    bounce_handler_threshold_score            => 10,
    bounce_handler_hardbounce_score           => 4,
    bounce_handler_softbounce_score           => 1,
    bounce_handler_decay_score                => 1,
    bounce_handler_forward_msgs_to_list_owner => 0,
    bounce_handler_when_threshold_reached     => 'move_to_bounced_sublist',

    # dada_digest.pl
    last_digest_sent => undef,

    # default messages
    default_plaintext_message_content_src => 'default',    # default/url_or_path
    default_plaintext_message_content_src_url_or_path => undef,
    default_html_message_content_src => 'default',         # default/url_or_path
    default_html_message_content_src_url_or_path => undef,

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

  bridge_list_email_type

  disable_discussion_sending
  discussion_pop_server
  discussion_pop_username
  discussion_pop_email
  discussion_pop_password
  discussion_pop_auth_mode
  discussion_pop_use_ssl


  ) unless keys %LIST_SETUP_OVERRIDES;

$OS ||= $^O;

$NULL_DEVICE ||= '/dev/null';

srand( time() ^ ( $$ + ( $$ << 15 ) ) );

$FIRST_SUB ||= 0;
$SEC_SUB   ||= 2;

@C = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.' );
$SALT = $C[ rand(@C) ] . $C[ rand(@C) ];

# Pick a word. It really doesn't matter what the word is - a longer
# word doesn't necessarily mean a better pin number.

if ( !defined($PIN_WORD) ) {
    $PIN_WORD =
      ( $ROOT_PASS_IS_ENCRYPTED == 1 ) ? ($PROGRAM_ROOT_PASSWORD) : ('dada');
}

# Pick a number. I would keep it between 1 and 9.
$PIN_NUM ||= unpack( "%32C*", $FILES );

$TEXT_CSV_PARAMS ||= {

    binary              => 1,
    allow_loose_escapes => 1,
};

BEGIN { @AnyDBM_File::ISA = qw(DB_File GDBM_File) }

$ATTACHMENT_TEMPFILE ||= 0;

$MAIL_VERP_SEPARATOR ||= '-';

$VERSION = 6.4.1;
$VER     = '6.4.1 Stable 6/09/13';

#
#
#####################################################################

$PROGRAM_NAME ||= "Dada Mail";

%EMAIL_HEADERS = (

    Date          => undef,
    From          => undef,
    To            => undef,
    Cc            => undef,
    Bcc           => undef,
    'Return-Path' => undef,
    'Reply-To'    => undef,
    'In-Reply-To' => undef,
    'Errors-To'   => undef,
    References    => undef,
    'X-Priority'  => undef,

    'Content-Base'     => undef,
    List               => undef,
    'List-Archive'     => undef,
    'List-Digest'      => undef,
    'List-Help'        => undef,
    'List-ID'          => undef,
    'List-Owner'       => undef,
    'List-Post'        => undef,
    'List-Subscribe'   => undef,
    'List-Unsubscribe' => undef,
    'List-URL'         => undef,
    'X-BeenThere'      => undef,

    'Message-ID' => undef,
    'Precedence' => 'list',
    'X-Mailer'   => "$PROGRAM_NAME $VER ",

    Sender                      => undef,
    'Content-type'              => undef,
    'Content-Transfer-Encoding' => undef,

    # Content-Length            =>    undef, # See it *should* be here,
    # but it also states it's unofficial

    'Content-Disposition' => undef,
    'MIME-Version'        => undef,

    Subject => '(no subject)',

    Body => 'blank',

) unless keys %EMAIL_HEADERS;

@EMAIL_HEADERS_ORDER = qw(
  Date
  From
  To
  Cc
  Bcc
  Return-Path
  Reply-To
  In-Reply-To
  Errors-To
  References
  X-Priority
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
  List-URL
  X-BeenThere

  X-Message-ID
  Message-ID

  X-Mailer

  Sender
  Content-type
  Content-Transfer-Encoding
  Content-Disposition
  Content-Base

  MIME-Version

  Subject
  ) unless scalar @EMAIL_HEADERS_ORDER;

######################################################################

# http://dadamailproject.com/purchase/pro.html
#
#
#
#

$GIVE_PROPS_IN_EMAIL = 1;

$GIVE_PROPS_IN_HTML = 1;

$GIVE_PROPS_IN_ADMIN = 1;

$GIVE_PROPS_IN_SUBSCRIBE_FORM = 1;

##########################################

#

sub _config_import {

# There's no user-servicable parts in the subroutine, so don't make any changes,
# unless you're customizing Dada Mail or debugging something interesting.
#
    if ( exists( $ENV{NO_DADA_MAIL_CONFIG_IMPORT} ) ) {
        if ( $ENV{NO_DADA_MAIL_CONFIG_IMPORT} == 1 ) {
            return;
        }
    }

    # Keep this as, 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'
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
        'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi' )
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
        archives_table                     => 'dada_archives',
        settings_table                     => 'dada_settings',
        session_table                      => 'dada_sessions',
        bounce_scores_table                => 'dada_bounce_scores',
        clickthrough_urls_table            => 'dada_clickthrough_urls',
        clickthrough_url_log_table         => 'dada_clickthrough_url_log',
        mass_mailing_event_log_table       => 'dada_mass_mailing_event_log',
        password_protect_directories_table => 'dada_password_protect_directories',
        confirmation_tokens_table          => 'dada_confirmation_tokens',


    );
    for ( keys %default_table_names ) {
        if ( !exists( $SQL_PARAMS{$_} ) ) {
            $SQL_PARAMS{$_} = $default_table_names{$_};
        }
    }

}

# Don't remove the '1'. It lives here at the bottom. It likes it there.

1;
