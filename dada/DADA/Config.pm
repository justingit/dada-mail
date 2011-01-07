package DADA::Config; 

##############################################################################
# For information on how to install Dada Mail, please see: 
# http://dadamailproject.com/support/documentation/install_dada_mail.pod.html 
##############################################################################

require Exporter;  
our @ISA =   qw(Exporter);  
use vars     qw($PROGRAM_ROOT_PASSWORD $MAILPROG $FILES $PROGRAM_URL $S_PROGRAM_URL $PLUGIN_CONFIGS $MAIL_SETTINGS $MASS_MAIL_SETTINGS $FIRST_SUB $SEC_SUB @C $SALT $FILE_CHMOD  $DIR_CHMOD $GIVE_PROPS_IN_EMAIL $GIVE_PROPS_IN_HTML $GIVE_PROPS_IN_ADMIN $GIVE_PROPS_IN_SUBSCRIBE_FORM $SUBSCRIBED_MESSAGE $SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE $SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE $SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT $SUBSCRIPTION_NOTICE_MESSAGE $UNSUBSCRIBED_MESSAGE  $CONFIRMATION_MESSAGE  $HTML_CONFIRMATION_MESSAGE  $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE $YOU_ARE_NOT_SUBSCRIBED_MESSAGE $HTML_UNSUB_CONFIRMATION_MESSAGE $HTML_SUBSCRIBED_MESSAGE $HTML_UNSUBSCRIBED_MESSAGE $HTML_SUBSCRIPTION_REQUEST_MESSAGE $ARCHIVES  $TEMPLATES $ALTERNATIVE_HTML_TEMPLATE_PATH $TMP $LOGS  $BACKUPS %BACKUP_HISTORY $MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION $ENFORCE_CLOSED_LOOP_OPT_IN $FCKEDITOR_URL $CKEDITOR_URL $LOG_VIEWER_PLUGIN_URL $SCREEN_CACHE $GLOBAL_BLACK_LIST $GLOBAL_UNSUBSCRIBE $MULTIPLE_LIST_SENDING $MULTIPLE_LIST_SENDING_TYPE $HIDDEN_SUBSCRIBER_FIELDS_PREFIX @PING_URLS $SUBSCRIPTION_SUCCESSFUL_COPY $MAILING_LIST_MESSAGE $MAILING_LIST_MESSAGE_HTML $ADMIN_MENU $NOT_ALLOWED_TO_POST_MESSAGE $NOT_ALLOWED_TO_POST_NOTICE_MESSAGE $NOT_ALLOWED_TO_POST_NOTICE_MESSAGE_SUBJECT  $MAILING_FINISHED_MESSAGE $MAILING_FINISHED_MESSAGE_SUBJECT $PIN_WORD $PIN_NUM $TEXT_CSV_PARAMS @DOMAINS %SERVICES $SHOW_DOMAIN_TABLE $SHOW_SERVICES_TABLE $GOOD_JOB_MESSAGE  $NO_ONE_SUBSCRIBED  $ALLOW_ROOT_LOGIN $UNSUB_CONFIRMATION_MESSAGE $SUBSCRIPTION_REQUEST_APPROVED_MESSAGE $SUBSCRIPTION_REQUEST_DENIED_MESSAGE @CHARSETS @PRECEDENCES @CONTENT_TYPES %LIST_SETUP_DEFAULTS %LIST_SETUP_INCLUDE %LIST_SETUP_OVERRIDES @LIST_SETUP_DONT_CLONE @SERVICES %PRIORITIES $ATTACHMENT_TEMPFILE $MAIL_VERP_SEPARATOR %MIME_TYPES $DEFAULT_MIME_TYPE $TEXT_INVITE_MESSAGE $PROFILE_ACTIVATION_MESSAGE_SUBJECT $PROFILE_ACTIVATION_MESSAGE $PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT $PROFILE_RESET_PASSWORD_MESSAGE $PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT $PROFILE_UPDATE_EMAIL_MESSAGE $LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT $LIST_CONFIRM_PASSWORD_MESSAGE $LIST_RESET_PASSWORD_MESSAGE_SUBJECT $LIST_RESET_PASSWORD_MESSAGE $HTML_INVITE_MESSAGE $MIME_PARANOID $MIME_HUSH $MIME_OPTIMIZE $NPH $PROGRAM_USAGE_LOG $ROOT_PASS_IS_ENCRYPTED @ALLOWED_IP_ADDRESSES $SHOW_ADMIN_LINK $ADMIN_FLAVOR_NAME $SIGN_IN_FLAVOR_NAME $DISABLE_OUTSIDE_LOGINS %LOG $DEBUG_TRACE %CPAN_DEBUG_SETTINGS $ADMIN_MENU $EMAIL_CASE @EMAIL_EXCEPTIONS $LIST_IN_ORDER $ADMIN_TEMPLATE $USER_TEMPLATE $SUBSCRIBER_DB_TYPE $ARCHIVE_DB_TYPE $SETTINGS_DB_TYPE $SESSION_DB_TYPE $BOUNCE_SCORECARD_DB_TYPE $CLICKTHROUGH_DB_TYPE  %SQL_PARAMS $DBI_PARAMS $PROFILE_OPTIONS $PROGRAM_ERROR_LOG $SHOW_HELP_LINKS $HELP_LINKS_URL $VER $VERSION  $PROGRAM_NAME @CONTENT_TRANSFER_ENCODINGS $CONFIG_FILE $PROGRAM_CONFIG_FILE_DIR $OS $DEFAULT_ADMIN_SCREEN $DEFAULT_LOGOUT_SCREEN $DEFAULT_SCREEN $HTML_CHARSET $HTML_SEND_ARCHIVED_MESSAGE $SEND_ARCHIVED_MESSAGE $REFERER_CHECK $CAPTCHA_TYPE $RECAPTCHA_PARAMS $RECAPTHCA_MAILHIDE_PARAMS $GD_SECURITYIMAGE_PARAMS $LOGIN_COOKIE_NAME %COOKIE_PARAMS $HTML_TEXTTOHTML_OPTIONS $TEMPLATE_SETTINGS $LOGIN_WIDGET $NULL_DEVICE $LIST_QUOTA $SUBSCRIPTION_QUOTA $MAILOUT_AT_ONCE_LIMIT $MAILOUT_STALE_AFTER %EMAIL_HEADERS @EMAIL_HEADERS_ORDER); 
@EXPORT_OK = qw($PROGRAM_ROOT_PASSWORD $MAILPROG $FILES $PROGRAM_URL $S_PROGRAM_URL $PLUGIN_CONFIGS $MAIL_SETTINGS $MASS_MAIL_SETTINGS $FIRST_SUB $SEC_SUB @C $SALT $FILE_CHMOD  $DIR_CHMOD $GIVE_PROPS_IN_EMAIL $GIVE_PROPS_IN_HTML $GIVE_PROPS_IN_ADMIN $GIVE_PROPS_IN_SUBSCRIBE_FORM $SUBSCRIBED_MESSAGE $SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE $SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE $SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT $SUBSCRIPTION_NOTICE_MESSAGE $UNSUBSCRIBED_MESSAGE  $CONFIRMATION_MESSAGE  $HTML_CONFIRMATION_MESSAGE  $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE $YOU_ARE_NOT_SUBSCRIBED_MESSAGE $HTML_UNSUB_CONFIRMATION_MESSAGE $HTML_SUBSCRIBED_MESSAGE $HTML_UNSUBSCRIBED_MESSAGE $HTML_SUBSCRIPTION_REQUEST_MESSAGE $ARCHIVES  $TEMPLATES $ALTERNATIVE_HTML_TEMPLATE_PATH $TMP $LOGS  $BACKUPS %BACKUP_HISTORY $MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION $ENFORCE_CLOSED_LOOP_OPT_IN $FCKEDITOR_URL $CKEDITOR_URL $LOG_VIEWER_PLUGIN_URL $SCREEN_CACHE $GLOBAL_BLACK_LIST $GLOBAL_UNSUBSCRIBE $MULTIPLE_LIST_SENDING $MULTIPLE_LIST_SENDING_TYPE $HIDDEN_SUBSCRIBER_FIELDS_PREFIX @PING_URLS $SUBSCRIPTION_SUCCESSFUL_COPY $MAILING_LIST_MESSAGE $MAILING_LIST_MESSAGE_HTML $ADMIN_MENU $NOT_ALLOWED_TO_POST_MESSAGE $NOT_ALLOWED_TO_POST_NOTICE_MESSAGE $NOT_ALLOWED_TO_POST_NOTICE_MESSAGE_SUBJECT  $MAILING_FINISHED_MESSAGE $MAILING_FINISHED_MESSAGE_SUBJECT $PIN_WORD $PIN_NUM $TEXT_CSV_PARAMS @DOMAINS %SERVICES $SHOW_DOMAIN_TABLE $SHOW_SERVICES_TABLE $GOOD_JOB_MESSAGE  $NO_ONE_SUBSCRIBED  $ALLOW_ROOT_LOGIN $UNSUB_CONFIRMATION_MESSAGE $SUBSCRIPTION_REQUEST_APPROVED_MESSAGE $SUBSCRIPTION_REQUEST_DENIED_MESSAGE @CHARSETS @PRECEDENCES @CONTENT_TYPES %LIST_SETUP_DEFAULTS %LIST_SETUP_INCLUDE %LIST_SETUP_OVERRIDES @LIST_SETUP_DONT_CLONE @SERVICES %PRIORITIES $ATTACHMENT_TEMPFILE $MAIL_VERP_SEPARATOR %MIME_TYPES $DEFAULT_MIME_TYPE $TEXT_INVITE_MESSAGE $PROFILE_ACTIVATION_MESSAGE_SUBJECT $PROFILE_ACTIVATION_MESSAGE $PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT $PROFILE_RESET_PASSWORD_MESSAGE $PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT $PROFILE_UPDATE_EMAIL_MESSAGE  $HTML_INVITE_MESSAGE $MIME_PARANOID $MIME_HUSH $MIME_OPTIMIZE $NPH $PROGRAM_USAGE_LOG $ROOT_PASS_IS_ENCRYPTED @ALLOWED_IP_ADDRESSES $SHOW_ADMIN_LINK $ADMIN_FLAVOR_NAME $SIGN_IN_FLAVOR_NAME $DISABLE_OUTSIDE_LOGINS %LOG $DEBUG_TRACE %CPAN_DEBUG_SETTINGS $ADMIN_MENU $EMAIL_CASE @EMAIL_EXCEPTIONS $LIST_IN_ORDER $ADMIN_TEMPLATE $USER_TEMPLATE $SUBSCRIBER_DB_TYPE $ARCHIVE_DB_TYPE $SETTINGS_DB_TYPE $SESSION_DB_TYPE $BOUNCE_SCORECARD_DB_TYPE $CLICKTHROUGH_DB_TYPE  %SQL_PARAMS $DBI_PARAMS $PROFILE_OPTIONS $PROGRAM_ERROR_LOG $SHOW_HELP_LINKS $HELP_LINKS_URL $VER $VERSION  $PROGRAM_NAME @CONTENT_TRANSFER_ENCODINGS $CONFIG_FILE $PROGRAM_CONFIG_FILE_DIR $OS $DEFAULT_ADMIN_SCREEN $DEFAULT_LOGOUT_SCREEN $DEFAULT_SCREEN $HTML_CHARSET $HTML_SEND_ARCHIVED_MESSAGE $SEND_ARCHIVED_MESSAGE $REFERER_CHECK $CAPTCHA_TYPE $RECAPTCHA_PARAMS $RECAPTHCA_MAILHIDE_PARAMS $GD_SECURITYIMAGE_PARAMS $LOGIN_COOKIE_NAME %COOKIE_PARAMS $HTML_TEXTTOHTML_OPTIONS $TEMPLATE_SETTINGS $LOGIN_WIDGET $NULL_DEVICE $LIST_QUOTA $SUBSCRIPTION_QUOTA $MAILOUT_AT_ONCE_LIMIT $MAILOUT_STALE_AFTER %EMAIL_HEADERS @EMAIL_HEADERS_ORDER); 
use strict; 


$PROGRAM_CONFIG_FILE_DIR = 'auto';

#--------------------------------#
# Leave the below line, alone!
 _config_import(); # Leave alone! 
# Leave the above line, alone!
#--------------------------------#

BEGIN {


$PROGRAM_ERROR_LOG = undef;


# Keep this next bit as-is; it's just opening the error file for writing. 
if($PROGRAM_ERROR_LOG){open (STDERR, ">>$PROGRAM_ERROR_LOG") || warn "$PROGRAM_NAME Error: Cannot redirect STDERR, it's possible that Dada Mail does not have write permissions to this file ($PROGRAM_ERROR_LOG) or it doesn't exist! If Dada Mail cannot make this file for you, create it yourself and give it enough permissions so it may write to it: $!";}
	# chmod(0777, $PROGRAM_ERROR_LOG); 
}


=pod

=head1 NAME Config.pm 

=head1 DESCRIPTION 

The, I<dada/DADA/Config.pm> file holds all the global variables in Dada Mail. It should not itself be 
heavily edited with custom changes - such changes will be lost whenever you upgrade. 
Use the outside config file (C<.dada_config>) for that. 

=head1 How To Use This File and This Documentation

Other than the variables: 

=over

=item * $PROGRAM_CONFIG_FILE_DIR

=item * $PROGRAM_ERROR_LOG

=back 

You should not make any changes to the variables in the, C<dada/DADA/Config.pm> file. 

Rather, use the variables and inline documentation as a guide for making custom 
changes to your own outside config file (called, C<.dada_config>) 

=head2 How to place new variables in your outside config file

First, double-check that the variable doesn't already exist in the outside 
configuration file. Duplicates will simply cause headaches when editing. 

Place new variables in your outside config file by simply copying the 
variable you want to set a custom variable for and pasting that variable in 
your outside config file. 

For historical reasons, the outside config file sets the config variables by 
simply using Perl code, instead of a configuration-specific format. This may 
change in the future - we don't like this  technique. One problem with this 
technique is that setting configuration variables successfully means that you will need
to use strict and valid Perl code. This will make things harder for a casual 
user of the program perform, successfully - and unfortunately. 

Some things to be careful of: 

The variables set in the C<dada/DADA/Config.pm> file use the, C<||=> operator,
like this: 

 $SOME_VARIABLE ||= 'some value'; 

Replace the, C<||=> operator with the, C<=> operator, when placing it in the outside config file: 

 $SOME_VARIABLE = 'some custom value'; 

You may also see hashes and arrays with, C<unless> clauses at the end: 

 %SOME_HASH = (
 	# a long list of key/value pairs
 ) unless keys %SOME_HASH; 

or, 

 @SOME_ARRAY = (
 	# ... 
 ) unless scalar @SOME_ARRAY; 

Remove the entire, C<unless> clause: 
 
 %SOME_HASH = (
 	# a long list of key/value pairs
 ); 
 
 
 @SOME_ARRAY = (
 	# ... 
 ); 

If you need to set a variable in the outside config file to '0', it 
may not work. Instead, try setting it to '2'. This is a known - and embarrassing, 
issue. 

Currently, the C<$PROGRAM_ERROR_LOG> variable cannot be set in the outside config 
file - you'll need to set it in here. 

=head1 How to Set Up, Install and Configure Dada Mail 

Complete installation instructions may be found here: 

L<http://dadamailproject.com/installation/>

Dada Mail ships with an installer that will guide you through the setup and
configuration of Dada Mail, write a starter outside config file and generally, 
get you up and running. 

=head1 Config Variables

=head1 $PROGRAM_CONFIG_FILE_DIR

$PROGRAM_CONFIG_FILE_DIR holds the absolute path to the, B<directory> the outside 
config file, named, C<.dada_config>, can be found. 

By default, you'll notice that the C<$PROGRAM_CONFIG_FILE_DIR>
variable is set to, I<auto>. If this is the case, Dada Mail will attempt 
to look for the C<.dada_config> file in the following location: 

 /home/user/.dada_files/.configs

An example of a complete, usable and extendable C<.dada_config> file can be found
in the Dada Mail distribution at: 

I<dada/extras/examplees/example_dada_config.txt>

You may also want to read the README for this example, located at: 

I<dada/extras/examplees/example_dada_config-README.txt>

=cut


=pod

=head2 $PROGRAM_ERROR_LOG

If you want to set a specific location for all errors from Dada Mail to be 
logged, B<$PROGRAM_ERROR_LOG> is what you want to look at. 

Set this variable to, B<An absolute path, to a location of a file you want
the error log to be>. Sounds like a mouthful - let's break it down:

=over

=item * "An absolute path" -  the path to a resource on the server, from the server's perspective. (begin geekery:)

In a Unix environment, an absolute path starts with, "B</>", also known as the, "root" directory and moves
down, like an upside-down tree. Example of some absolute paths: 

=over

=item * /home/myaccount

an example of the absolute path to my home directory

=item * /home/myaccount/dada_files

an example of the absolute path to where I've set the, B<$FILES> variable to (just as example). 

So, if you've set the B<$FILES> variable correctly, you already know what absolute paths are. You see? You're smarter than you thought. 

=back

=item * "to a location of a file you want the error log to be"

So what's , "an error log"? It's just a plain text file - that's it, so set the B<$PROGRAM_ERROR_LOG> variable to an absolute path to a plaintext file. Easy enough. As to, "I<what> location"? Well, if you've set the B<$FILES> variable to an absolute path of a directory (per directions), use that as a starting point, and just specify an exact file in that directoy - easy! 

=back

So, if I set B<$FILES> to: 

 $FILES = '/home/myaccount/dada_files'; 

set, B<$PROGRAM_ERROR_LOG> to: 

 $PROGRAM_ERROR_LOG = '/home/myaccount/dada_files/errors.txt'; 

and you're done. 

B<Note!> This B<WILL NOT> work: 
 
 $PROGRAM_ERROR_LOG = $FILES . '/errors.txt'; 

So, don't do that. 

Also, you cannot set this variable in an outside configuration file (.dada_config), it has to be set in the Config.pm file. 

Don't create the file beforehand - you won't need to. It'll be created automatically for you, as long as the path you set in this variable is to a place Dada Mail can actually write to. 

Finally, just to clarify, the program can't automatically set a error log, since there may be problems with the program, before it's able to be fully interpreted, so we have to hard code it, that's why there's this variable. 

=cut



=head1 Basic Configuration Variables

=head2 $PROGRAM_ROOT_PASSWORD

The $PROGRAM_ROOT_PASSWORD  is used to create new mailing lists and also may
be used to log into any existing mailing list. 

=cut



$PROGRAM_ROOT_PASSWORD ||= 'root_password';



=pod

THE $PROGRAM_ROOT_PASSWORD variable should be encrypted. Instructions to do so 
can be found in the documentation for the, $ROOT_PASS_IS_ENCRYPTED variable. 


=head2 $FILES

$FILES holds the directory you want your mailing list subscribers, schedules and a few
obscure files to be saved in. 

=cut



$FILES ||= '/home/youraccount/dada_files';



=pod

=head2 $MAILPROG

This variable should hold  the Absolute Path of your sendmail-like program.

If you don't have sendmail, this script will still work great,
but you may have to fiddle around with the "$MAIL_SETTINGS"
variable under the "additional settings" after the first four 
variables. Dada Mail uses a Mail Program like Sendmail or qmail to
send its messages and it needs to know where the Mail Program is 
to be able to use it. 

=cut



$MAILPROG ||= '/usr/sbin/sendmail';  



=pod

=head2 $PROGRAM_URL

This variable holds the  URL of the mail.cgi script.

This is the address of the mail.cgi script (not this file!), 
so when you're all done setting up the script, you'll have to go 
here to make your first list. 

=cut



$PROGRAM_URL ||='http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi';



=pod

=head1 Backend DB Options

By default, Dada Mail comes configured out of the box using a PlainText backend for list subscribers and 
DB Files for everything else: Archives, Settings and Session Handling. 

This makes setup simple, since there's no SQL setup needed. 

YOU may want the additional features that an SQL Backend provides. 
These additional features include being able to save Profiles and Subscriber Profile Fields, other than the email address. 

There's B<three steps> involved to setup Dada Mail to use its SQL backend. 

The first step is to set the five variables, C<$SUBSCRIBER_DB_TYPE>, 
C<$ARCHIVE_DB_TYPE>, C<$SETTINGS_DB_TYPE> , C<$SESSION_DB_TYPE> and 
C<$BOUNCE_SCORECARD_DB_TYPE> all to, C<SQL>.

=cut

# Here are the four variables that are talked about, above: 

$SUBSCRIBER_DB_TYPE       ||= 'PlainText'; 
$ARCHIVE_DB_TYPE          ||= 'Db'; 
$SETTINGS_DB_TYPE         ||= 'Db'; 
$SESSION_DB_TYPE          ||= 'Db';
$BOUNCE_SCORECARD_DB_TYPE ||= 'Db';
$CLICKTHROUGH_DB_TYPE     ||= 'Db'; 



=pod

=head2 Required SQL tables

Dada Mail supports three different types of SQL backends, B<MySQL>, B<Postgres> and, B<SQLite>. SQLite is included, but isn't
advised to be used in production. The MySQL and PostgreSQL backends are exactly the same, feature-wise. 

The second step in setting up the SQL backend is to create the correct SQL tables needed for the type of backend you're going to use. 

The appropriate tables are listed in the files located in the dada/extras/SQL driectory of the distribution itself: 

=over

=item * MySQL

I<dada/extras/SQL/mysql_schema.sql>

=item * PostgreSQL

I<dada/extras/SQL/postgres_schema.sql>

=item * SQLite

I<dada/extras/SQL/sqlite_schema.sql>

=back

=head2 %SQL_PARAMS

The third and final step involved in setting up the SQL backend is to fill out the C<%SQL_PARAMS> variable. 

They are as follows: 

=over

=item * database

The name of the database you are using.

=item * dbserver 

The name of the database server itself. Example: I<sql.mydomain.com>, or, I<localhost>

=item * port 

The port that is used when connecting to the database server. 

=item * dbtype

Set dbtype to 'mysql' for MySQL usage, 'Pg' for Postgres or, 'SQLite' for SQLite.

=item * user

The SQL username.

=item * pass 

The SQL password.

=back

=cut




%SQL_PARAMS = ( 

	# May just be, "localhost" 
	dbserver         => 'localhost',
		
	database         => '',
	
	# MySQL:      3306
	# PostgreSQL: 5432      
	port             => '3306',
	
	# MySQL:      mysql 
	# PostgreSQL: Pg
	# SQLite:     SQLite
	dbtype           => 'mysql',  
	
	user             => '',          
	pass             => '',

	subscriber_table                => 'dada_subscribers',
	profile_table                   => 'dada_profiles', 
	profile_fields_table 	        => 'dada_profile_fields', 
	profile_fields_attributes_table => 'dada_profile_fields_attributes',
	archives_table                  => 'dada_archives', 
	settings_table                  => 'dada_settings', 
	session_table                   => 'dada_sessions', 
	bounce_scores_table             => 'dada_bounce_scores', 
	clickthrough_urls_table         => 'dada_clickthrough_urls', 

) unless keys %SQL_PARAMS; 




=pod

=head2 $DBI_PARAMS

These are advanced paramaters sent to the Perl DBI SQL driver. You probably 
will not need to change the below. 

For more information, see: 

L<http://search.cpan.org/~timb/DBI/DBI.pm#ATTRIBUTES_COMMON_TO_ALL_HANDLES>

=cut




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
	
	dada_connection_method  => 'connect_cached', 
	
	
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
		sqlite_unicode  => 1,
		
};

=pod

=head2 Dada Mail Profile Options

=head2 $PROFILE_OPTIONS

=head3 enabled

Sets whether profiles are enabled, or not. Set to, C<1> to enable, set to anything else to disable. 

=head3 profile_email

When a registration email or reset password email goes out, it'll go out on behalf of this email address. We highly encourage you to fill out this variable, or these email messages may not be sent out correctly. Example: 

 profile_email => 'me@mydomain.com', 

If Profiles are enabled and this variable is left blank, the list owner email address of one of the mailing lists will be used. 

=head3 enable_captcha

Registration for Dada Mail Profiles can be verified using a CAPTCHA. We recommend this feature, if it's available. Set this variable to, C<1> to enable CAPTCHA in the registration form. 

=head3 enable_magic_subscription_forms

"Magic" subscription forms are pre-filled out with the subscriber's email address, if they're logged into Dada Mail. To enable this feature, set this variable to, C<1> 

=head3 cookie_params

This variable holds a few options to change the behavior of the session management cookie for Dada Mail Profiles. 

=head3 gravatar_options

Gravatars can also be enabled for Dada Mail Profiles. More information: 

L<http://gravatar.com/> 

=head4 More Information: 

L<http://dadamailproject.com/support/documentation/features-profiles.pod.html>


=cut 

$PROFILE_OPTIONS ||= { 
		
	enabled                         => 1, 
	profile_email                   => '', 
	enable_captcha                  => 1, 
	enable_magic_subscription_forms => 1, 
	
	cookie_params =>
	{ 
		-name    => 'dada_profile',  
	    -path    => '/',
	    -expires => '+7d',		
	},
	
	gravatar_options => 
	{
		enable_gravators     => 1, 
		default_gravatar_url => undef,
	},
};


=pod


=head2 $SHOW_HELP_LINKS						

Most all the list administration screens have direct links to the Dada Mail Manual at
the bottom of the screen. Set this variable to, C<1> to have them shown or, C<0> 
to have them not shown. 

The Dada Mail Manual is a paid service, more information about it can be found at: 

L<http://dadamailproject.com/purchase/pro.html>

=cut

$SHOW_HELP_LINKS ||= 1;

=pod

=head2 $HELP_LINKS_URL

The Dada Mail Manual is available online, and also to download. You may use your 
own copy of the Dada Mail Manual (just somehow password protect it) and set this
URL to the location to where it is. 

The default setting is the online version that we provide - but it is a paid service.

=cut

$HELP_LINKS_URL ||= 'http://dadamailproject.com/pro_dada/4.3.0';


=pod

=head1 Additional Global Configuration Settings

It's well advised that you get familiar with this program and
go through it ENTIRELY before you change any of the settings below. 
From this point, it helps if you have some kind of Unix/Perl 
background, Or you've used previous versions of the script. 

=head2 $S_PROGRAM_URL

The "S" in $S_PROGRAM_URL stands for B<S>ecure, and allows you to 
have all screens that have anything to do with the list control 
panel to use a separate URL where you can install a completely 
different version of Dada Mail, or, if you can access your website 
via the https protocol, you can use that different URL specifically 
for list control panel activity. 

Make sure $S_PROGRAM_URL contains a valid URL (http://...). 

=cut




$S_PROGRAM_URL ||= $PROGRAM_URL;




=pod

=head2 $PLUGIN_CONFIGS

C<$PLUGIN_CONFIGS> holds defaults to various Dada Mail plugins and extensions. 

The idea is that these plugins and extensions are difficult to upgrade, since 
everytime you upgrade, you have to re-configure the plugin. Not so anymore. 

Some of the plugins currently supported are: 

=over

=item * Mystery Girl (Bounce Handler) 

=item * Beatitude (Mail Scheduler) 

=item * Dada Bridge

=item * blog_index.cgi

=back

The order of precendence for the setting of these variables are: 

=over

=item * Inside the plugin/extension itself

=item * Config.pm File

=item * .dada_config file 

=back 

So, if you set the configuration variable in the plugin/extension itself B<and> the 
.dada_config file, the value in the .dada_config file will be used. 

Refer to the plugin/extension itself to know what the various plugin/extension 
configuration names and values are and do. 

=cut 




$PLUGIN_CONFIGS ||= { 
    
    Mystery_Girl => { 
    
        Server                    			=> undef, 
        Username                  			=> undef, 
        Password                  			=> undef, 
        USESSL                              => undef, 
        AUTH_MODE                           => undef, 
        Log                       			=> undef,         
        Send_Messages_To          			=> undef, 
        MessagesAtOnce            			=> undef, 
        Max_Size_Of_Any_Message             => undef, 
        Default_Soft_Bounce_Score 			=> undef, 
        Default_Hard_Bounce_Score 			=> undef, 
        Score_Threshold           			=> undef, 
        Allow_Manual_Run          			=> undef, 
        Manual_Run_Passcode       			=> undef, 
        Plugin_URL                			=> undef, 
        Rules                     			=> undef,
        Bounce_Handler_Name       			=> undef, 
	
    
    }, 
    
    Beatitude => { 
    
        Log                       			=> undef, 
        Plugin_URL                			=> undef, 
        Allow_Manual_Run          			=> undef, 
        Manual_Run_Passcode       			=> undef,         
    }, 
    
    Dada_Bridge => { 
        
        Plugin_URL                          => undef, 
		Plugin_Name                         => undef, 
        Allow_Manual_Run                    => undef, 
        Manual_Run_Passcode                 => undef, 
        MessagesAtOnce                      => undef, 
        Max_Size_Of_Any_Message             => undef, 
        Allow_Open_Discussion_List          => undef, 
        Room_For_One_More_Check             => undef, 
		Enable_POP3_File_Locking            => undef, 
		Check_List_Owner_Return_Path_Header => undef, 
		Check_Multiple_Return_Path_Headers  => undef, 
    
    },

	ajax_include_subscribe => { 
	
        Plugin_URL                          => undef, 
		Default_List                        => undef, 
		
	}, 
    
    blog_index => {

        Default_List                        => undef, 
        Entries                             => undef, 
        Style                               => undef, 
		Allow_QS_Overrides                  => undef,
        Template                            => undef, 

    }, 


    log_viewer => { 
	
		Plugin_URL                          => undef, 
 		tail_command                        => undef, 
    
	},
    
};




=pod

=head1 Security 

This section deals with Dada Mail and security - both to tighten it
up and lax it down, depending on what you want to allow and what 
you can do. 

=head2 $SHOW_ADMIN_LINK

Set $SHOW_ADMIN_LINK to '0' to take off the 'Administration' link
that you see on the Dada Mail default page. You can always get to 
the administration page by pointing your browser to an address 
like this: 

	http://mysite.com/cgi-bin/dada/mail.cgi?f=admin

This is a small security measure but may just stop people from 
snooping further. 

=cut

$SHOW_ADMIN_LINK ||= 1;


=pod 

=head2 $ADMIN_FLAVOR_NAME

Complementary to the C<$SHOW_ADMIN_LINK> variable, C<$ADMIN_FLAVOR_NAME> allows you to set the URL needed to access the screen that has the form to log into all the lists administrated by Dada Mail and to the form to create a new list. 

By default, this variable is set to, C<admin>, which means to access this screen, you'd go to a URL that looks like this: 

http://example.com/cgi-bin/dada/mail.cgi?f=admin

or: 

http://example.com/cgi-bin/dada/mail.cgi/admin

If you set C<$ADMIN_FLAVOR_NAME> to something like, B<kookoo>: 

 $ADMIN_FLAVOR_NAME ||= 'kookoo'; 

You'd then access this screen via the following URLS; 

http://example.com/cgi-bin/dada/mail.cgi?f=kookoo

or: 

http://example.com/cgi-bin/dada/mail.cgi/kookoo

A small security measure for sure, but could help keep curious eyes at bay. 

Works best if you have, B<$SHOW_ADMIN_LINK> set to, B<1>. 

A small note on how to set this variable correctly: 

=over

=item * no spaces in the name

Valid values: 

=over

=item * poopoo1234

=item * agabaga

=item * JKdsfkKJjjkkjjk

=back

Invalid values: 

=over

=item * fads fdas    asdf

=item * You Get The Point

=back

=item * Don't set this variable to anything that Dada Mail already uses, like:

=over

=item * subscribe

=item * unsubscribe

=item * login

=item * logout

=item * list

=item * archive

=back

etc. A good way to make sure would be to append, "admin" to your value, like this: 

=over

=item * adminfoofoo

=item * adminlalalala

=item * adminwhakawhaka

=back

No checks will be made to make sure you don't have this value set to something already present, so do be careful setting this variable. 


=back

=cut


$ADMIN_FLAVOR_NAME ||= 'admin'; 


=pod

=head2 $SIGN_IN_FLAVOR_NAME

Similar to C<$ADMIN_FLAVOR_NAME>, C<$SIGN_IN_FLAVOR_NAME> holds the URL that allows you to log into a particular list (usually), although it is sometimes used to re-login into any of your lists - very similar to the administration screen, but does not give you the form to create a new list. 

The same naming rules apply for this variable as they do for C<$ADMIN_FLAVOR_NAME>. It's also suggested that you append, "sign_in" to the value you set this, like so: 

=over

=item * sign_in_fdskjasdf

=item * sign_in_sneaky_pete

=back

etc. 

=cut


$SIGN_IN_FLAVOR_NAME ||= 'sign_in'; 


=pod

=head2 $DISABLE_OUTSIDE_LOGINS

If set to, B<1>, The only forms that will allow you to log into a Dada Mail list will be by 
a form supplied by Dada Mail itself. This means, you can't create a different form, outside
the program to provide a way to login. 

More so than any other option, this variable attempts to stop attempts of logging into a list
by automated means. 

=cut


$DISABLE_OUTSIDE_LOGINS ||= 0; 


=pod 

=head2 $LOGIN_WIDGET

By default on the list login screen, Dada Mail presents its user 
with a popup menu with the names of all the lists, hidden or not, that 
you can select to login to. 

This is done by setting B<$LOGIN_WIDGET> to 'popup_menu'. 

If you want to only have a text box for someone to type in the 
list Short Name in, set B<$LOGIN_WIDGET> to 'text_box'.

=cut


$LOGIN_WIDGET ||= 'popup_menu'; 


=pod

=head2 $ALLOW_ROOT_LOGIN

B<Allow the Root Password to Log In to All Lists>

Set the '$ALLOW_ROOT_LOGIN' variable to '1' to allow the Dada Root
Administrator to use the dada root password to log into any list. 
This is handy when you have many, many lists and need to tweak them 
but don't want to keep track of all the list passwords. Setting 
this variable to '1' does make your lists less secure, as every list 
can be accessed with the same password and that password is 
written plainly in this file, unless! you encrypt it (see below).

=cut

$ALLOW_ROOT_LOGIN ||= 1; 


=pod

=head2 $ROOT_PASS_IS_ENCRYPTED

You can store an encrypted version of the $PROGRAM_ROOT_PASSWORD 
instead of the plain text version. Here are the steps. This is 
B<extremely> recommended for obvious reasons.

=over

=item 1

Set up Dada Mail so it's working. Usually this means setting up 
the first four variables. 

=item 2

Point your browser to wherever you have the dada.cgi script at, and 
at the end of the URL, append this: ?f=pass_gen so you'll have 
something that looks like this: 

	http://yoursite.com/cgi-bin/dada/mail.cgi?f=pass_gen

=item 3

You'll see a page in your browser that asks for a password to 
encrypt. Type in the password you want to use, and press 'encrypt'. 
An encrypted password will be outputted. 

=item 4

Copy that encrypted password and use it as the root password (that is, 
by changing the $PROGRAM_ROOT_PASSWORD variable above to the 
encrypted password).

=item 5

Set $ROOT_PASS_IS_ENCRYPTED below to '1'.

=cut

$ROOT_PASS_IS_ENCRYPTED ||= 0;

=pod

=item 6 

Eat a mango. They're REALLY good.

=back 


=head2 @ALLOWED_IP_ADDRESSES

You can block anyone from using any list control panel by 
specifying exactly what IP addresses are allowed. Leave the 
@ALLOWED_IP_ADDRESSES blank:

	@ALLOWED_IP_ADDRESSES = qw(); 

to disable this security measure. 

To add an address, just list it, like this: 
	
	@ALLOWED_IP_ADDRESSES = qw(123.456.67.678 
	                           215.234.56.9 
	                           783.456.9.2);

=cut

@ALLOWED_IP_ADDRESSES = qw() 
	unless scalar @ALLOWED_IP_ADDRESSES;

=pod

Please note that crafty people can spoof what IP address they're 
coming from, and dial-up accounts and connections using DHCP may
not have the same IP address per session.  


=head2 $REFERER_CHECK

Setting $REFERER_CHECK to '1' will only allow you to access admin
screens if the referer in your web browser is whatever is set in 
$PROGRAM_URL or $S_PROGRAM_URL. In other words, you won't be able to 
sign in to your list control panel, then stop, check your email on 
Yahoo! and come back to the list control panel by typing in its URL. 

=cut

$REFERER_CHECK ||= 0; 


=pod

=head1 CAPTCHA in Dada Mail

Dada Mail supports a few CAPTCHA tricks. All the configuration of the CAPTCHA
system may be done in the Config.pm file (or outside Config file) 

More information: 

http://en.wikipedia.org/wiki/CAPTCHA

=head2 CAPTCHA Overview

CAPTCHA may be used for: 

=over

=item * Subscription Confirmations 

A CAPTCHA form is shown after a subscriber clicks on a subscription confirmation URL and before they are allowed to subscribed. Why then, instead of say, on the initial sign up form? A good question. 

First, showing the CAPTCHA later is one less hurtle at the beginning of the
subscription process. 

Second, the actual confirmation process of Dada Mail is quite the hurtle for a 
bot to go through, before even attempting to solve a CAPTCHA. 

Enabling CAPTCHA support can be done in the list control panel, under, 

B<Manage List - Mailing List Options>. Check the option labeled, B<Enable CAPTCHA'ing>

=item * In the, "Send this Archive to a Friend", function

This form is shown below archived messages in the publically accessable archives of a Dada Mail List. You may enable this feature, as well as the CAPTCHA for this feature in the list control panel under, B<Manage Archives - Archive Options> B<It's highly suggested to always use CAPTCHA'ing when using the Send an Archive to a friend feature> (The potential for abuse is great). Make sure to check the option, B<Enable CAPTCHA'ing on the, "Send this Archive to a Friend">

=back

=head2 $CAPTCHA_TYPE

Dada Mail supports two different CAPTCHA types. The first is just called, B<Default>, the other one is called, B<reCAPTCHA>. The Default CAPTCHA type is based on: 

L<http://search.cpan.org/~burak/GD-SecurityImage/lib/GD/SecurityImage.pm>

reCAPTCHA is based on the reCAPTCHA service: 

L<http://recaptcha.net/>

It's suggested that you use the reCAPTCHA service, as it's a lot more sophisticated than the Default type. 

To set the type of CATPCHA you'd like to use, make sure to set the variable, 
C<$CAPTCHA_TYPE> to either, B<Default> or, B<reCAPTCHA>.

There are additional and different steps that must be followed to finished the 
configuration of these CAPTCHA types

=cut




# Set to Either, "Default" or, "reCAPTCHA"; 
$CAPTCHA_TYPE ||= 'Default';




=pod


=head2 Default Type CAPTCHA Configuration ($GD_SECURITYIMAGE_PARAMS)

If you are using the B<Default> CAPTCHA type, you'll have the option to configure the paramaters set in the, C<$GD_SECURITYIMAGE_PARAMS> variable. 

This type also requires use of the B<GD> CPAN Perl Module, which itself require the GD C Library. If you do not have that, you will have to install it. 

If you do have the GD library installed, B<no further configuration is necessary>, but you may want to glance around at what is available to play around with. 

See Also: 

L<http://search.cpan.org/~burak/GD-SecurityImage/lib/GD/SecurityImage.pm>

Each key in this hashref corresponds to the different methods of this module ie:

=over

=item * new

=item * create

=item * particle

=back

=cut


$GD_SECURITYIMAGE_PARAMS ||= { 

    'rand_string_from' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZaeiouy', 
    'rand_string_size' => 6, 
    

    'new' => { 
    
        width      => 250,
        height     => 125,
        lines      => 10,
        #gd_font    => 'Giant',
        send_ctobg => 1, 
        
        # There's some magic here, 
        # If the font is located in the, 
        # dada/DADA/Template/templates directory, 
        # You don't have to put the absolute path, 
        # just the filename. 
        
        font       => 'StayPuft.ttf', 
        bgcolor    => "#CCFFCC",
        angle      => 13, 
        ptsize     => 30,
                                          
    
    }, 
    
    create => {
    
       ttf => 'circle',
       # normal => 'circle',      
    }, 
    
    particle => [
        500, 
        undef
    ], 

}; 

=pod

=head2 reCATPCHA Type CAPTCHA ($RECAPTCHA_PARAMS)

If you are using the B<reCAPTCHA> CAPTCHA type, you'll be B<required> to configure the paramaters set in the, C<$RECAPTCHA_PARAMS> variable. 

To configure those paramaters, you'll have to first grab an account: 

L<https://admin.recaptcha.net/accounts/login/?next=/recaptcha/sites/>

and fill in the public_key and private_key in C<$RECAPTCHA_PARAMS>

See Also: 

L<http://search.cpan.org/~andya/Captcha-reCAPTCHA/>

Which is the Perl CPAN module that Dada Mail uses for reCAPTCHA support. 

The reCAPTCHA CAPTCHA type does require the same sort of thing that the, B<Send a Webpage> functionality requires - so if that screen is working, reCAPTCHA should as well. 

=cut

$RECAPTCHA_PARAMS ||= { 

    remote_address => $ENV{'REMOTE_ADDR'}, 
    public_key     => undef,
    private_key    => undef,

};

=pod

=head2 $RECAPTHCA_MAILHIDE_PARAMS CAPTCHA for email address in archives

As an added bonus, you can also use CAPTCHA'ing to hide email addresses in your list's publically viewable archives. Yeah! 

To enable this functionality, in your list control panel, go to: B<Manage Archives - Archive Options - Advanced> and select, B<reCAPTCHA MailHide> under, B<Email Address Protection>

Although Dada Mail supports Captcha::reCAPTCHA::Mailhide, it B<does not come with it.> This is because it's not possible to bundle the module with Dada Mail. You'll need to install it manually (using the CPAN shell, etc). 

See also: 

L<http://search.cpan.org/~andya/Captcha-reCAPTCHA-Mailhide/>

Similar to the reCAPTCHA CAPTCHA type, you'll have to grab a key: 
L<http://mailhide.recaptcha.net/apikey>

and fill in the private_key and public_key parts of the C<$RECAPTHCA_MAILHIDE_PARAMS> variable.

=cut

$RECAPTHCA_MAILHIDE_PARAMS ||= { 
    public_key     => '',
    private_key    => '',
}; 






=pod

=head1 Cookies

Dada Mail uses cookies only for its login mechanism. 
Subscribers are not given a cookie. 


=head2 $LOGIN_COOKIE_NAME

B<$LOGIN_COOKIE_NAME> holds the name of the cookie passed to 
the person's browser that will be accessing the list control 
panel. 

=cut

$LOGIN_COOKIE_NAME ||= 'dadalogin';


=pod

=head2 Cookie Parameters 

Some browsers/servers funkify Dada Mail's cookies. I don't know why.
You can set additional attributes that are written for Dada Mail 
cookies by tweaking the %COOKIE_PARAMS hash, as outlined: 

http://search.cpan.org/author/JHI/perl-5.8.0/lib/CGI.pm#HTTP_COOKIES

=cut

%COOKIE_PARAMS = (
                  -path    => '/',
                  -expires => '+7d', 
                 
                 ) unless keys %COOKIE_PARAMS; 


=pod

=head1 Sendmail Settings


=head2 $MAIL_SETTINGS

B<|$MAILPROG -t -odq> is great to use for very large lists as it 
queues up all messages, but may not be available in all situations.

Since Dada Mail 2.4, most optional flags aren't needed, as Dada Mail now 
handles the mailing of large lists well with its Batch Sending feature
and sending mail through SMTP. These settings are still useful if you 
are using something other than Sendmail or qmail. 

See the main page for Sendmail or whatever mail system 
your server uses for more info.
Some flags for sendmail you can use are:

-io    -> Not exit a line with only a dot is read.

-t     -> Read the headers of the message to decide whom to send it to. 
          (this is really good to have for qmail)   

-odq   -> Insert the message into a queue. 

-oem   -> On error, mail back the message 
          attempting to deliver it immediately.  

An example of using all those flags in the variable looks like this: 

    $MAIL_SETTINGS = "|$MAILPROG -oi -t -odq -oem";

Tip: change this to ">>filename.txt";
to make Dada send email to a file instead of an email, for debugging.
Here's something to look at: 
http://www.courier-mta.org/sendmail.html
if you want more info.

=cut

$MAIL_SETTINGS      ||= "|$MAILPROG -t";
$MASS_MAIL_SETTINGS ||= "|$MAILPROG -t";

=pod

=head1 Windows-Specific Settings


=head2 $NPH

NPH stands for No Parse Headers. I don't know what that means either, 
but Microsoft servers like it, and I've found that cookies don't get 
set correctly and you're left with a funky screen saying you did 
wrong without it. Set this variable to '1' if you're using a Windows 
server. 

=cut

$NPH ||= 0; 

=pod

It's also a good idea to rename dada nph-dada.cgi for Windows servers 
that require scripts to use NPH.

=cut


=pod

=head1 Logging


=head2 $LOGS

$LOGS sort of holds the default location of where all the logs should 
be placed; you can then set the other logs using this as a starting 
point. For example: 

 $LOGS = '/home/account/dada_files/logs';  
 
 $PROGRAM_USAGE_LOG = $LOGS . '/usage.txt'; 

Sneaky. This makes a bit more sense if you're using an outside 
configuration file. 

=cut

$LOGS      ||= $FILES;


=pod

=head2 $PROGRAM_USAGE_LOG

The dada log keeps track of mundane things, such as subscriptions, 
unsubscriptions, control panel logins, ...things like that. 
This can be pretty useful come debugging time, or if something went 
south during a very important mailing - best to turn this on 
/before/ that big mailing. 

Turn logging on by specifying a absolute path to a file you want 
to use for the log. I personally always have this on, since it helps
in finding a general trend and health of my list and can be beneficial
if there is some sort of subscription dispute. 

=cut

$PROGRAM_USAGE_LOG ||= $LOGS . '/dada_usage.txt';


=pod

=head2 %LOG

What should be logged?

Change each value to '1' in the %LOG hash if you want these things 
logged, change the variable to a '0' if you don't. 

=cut

%LOG = (

    # log subscriptions/unsubscriptions?
    subscriptions => 1,

    # log regular mailings?
    mailings => 0,

    # log mass mailings?
    mass_mailings => 1,

    # log batchess of mass mailings?
    mass_mailing_batche => 1,

    # log control panel login/logouts?
    logins => 1,

    # log new lists created/old lists destroyed?
    list_lives => 1,

) unless keys %LOG;



=pod

=head2 $DEBUG_TRACE


=cut

$DEBUG_TRACE ||= { 

	DADA_App_DBIHandle         => 0, 
    DADA_App_Subscriptions     => 0,

	DADA_Logging_Clickthrough  => 0, 
	
	DADA_Profile               => 0, 
	DADA_Profile_Fields        => 0, 
	DADA_Profile_Session       => 0, 
    DADA_Mail_MailOut          => 0, 
    DADA_Mail_Send             => 0, 
	DADA_App_BounceScoreKeeper => 0, 
    DADA_MailingList_baseSQL   => 0,  

 
};


=pod 

=head2 %CPAN_DEBUG_SETTINGS 

Control what outside CPAN modules give back debugging information. 
Set the value to, "1" to enabled debugging information from the CPAN module.

Example: 

 NET_SMTP => 1,

Read the inline comments - there may be instances where you can set these values
to something other than, "1" if the CPAN module itself supports levels of debugging
information (for example:DBI)

=cut

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




=pod

=head1 Templates 							

You can change the look and feel of Dada Mail globally by specifying a
different template file to use. Examples of what these templates 
look like are located in the 'extras' directory. 


=head2 $ADMIN_TEMPLATE

Path to the admin template. The default admin template is located at: 

 dada/DADA/Template/templates/default_admin_template.tmpl

=cut

$ADMIN_TEMPLATE ||= ''; 


=pod 

=head2 $USER_TEMPLATE

Path to the default user template, also know as the list template. 
We'll attempt to stick to one name from now on. The default user/list 
template is located at: 

dada/DADA/Template/templates/default_list_template.tmpl

=cut

$USER_TEMPLATE  ||= ''; 


=pod

=head1 List Files - Specific Places to Write Them


=head2 $TEMPLATES

Templates, by default, are saved in the same directory as your lists. 
To make things cleaner and nicer, you can move them into their own 
directory by setting the B<$TEMPLATES> variable to an absolute path to 
a directory.

=cut

$TEMPLATES ||= $FILES; 


=pod

=head2 $ALTERNATIVE_HTML_TEMPLATE_PATH

Hopefully, this variable will not need to be used - it's a little 
confusing on what it does.... 

Dada Mail, internally, uses a separate templating language from what 
is exposed to list owners and such, called HTML::Template. 
More information:

http://search.cpan.org/~samtregar/HTML-Template-2.7/Template.pm

Dada Mail needs to know the absolute path to these templates, which 
(as of 2.9) is at: 

 /path/to/your/cgi-bin/dada/DADA/Template/templates

Sometimes, the automated thingy that figures this absolute path hangs 
for unknown reasons. 

To thwart that, you can manually put the absolute path you need in 
B<$ALTERNATIVE_HTML_TEMPLATE_PATH> like so: 

 $ALTERNATIVE_HTML_TEMPLATE_PATH = '/home/justin/cgi-bin/dada/DADA/Template/templates'; 

How do you know if you need to set this variable? Most likely, you'll 
get an error that contains something along the lines of: 

 HTML::Template::Expr->new() : Error creating HTML::Template object :   
 HTML::Template->new() : Cannot open included file congrats_screen.tmpl :
 file  not found. at

or something dealing with the "File::Spec" module. 

Somewhat lame, I know. 

=cut

$ALTERNATIVE_HTML_TEMPLATE_PATH ||= undef; 


=pod

=head2 $TMP

Specifies the different directory that Dada Mail should use for 
writing temporary files. These files may contain sensitive data, like 
a copy of an outgoing message, so keep that in mind. 

=cut

$TMP ||= $FILES;
 

=pod

=head2 $ARCHIVES

Set B<$ARCHIVES> to the absolute path a directory that you want 
archives to be saved under.

=cut

$ARCHIVES  ||= $FILES; 


=pod

=head2 $BACKUPS

Set $BACKUPS to an absolute path to a directory to where you want 
list backups to be saved. 

=cut

$BACKUPS   ||= $FILES; 


=pod

=head2 %BACKUP_HISTORY 

%BACKUP_HISTORY sets how many different revisions of various list 
files are saved. 

=cut

%BACKUP_HISTORY = ( 

	settings  => 3,
	archives  => 3, 
	schedules => 3, 
	
) unless keys %BACKUP_HISTORY;


=pod

=head1 Program Behavior

=head2 $MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION 

If set to, B<1>, Dada Mail's mailing monitor will automatically be called. See:

L<http://dadamailproject.com/support/documentation/FAQ-mailing_list_sending.pod.html> 

For more information. 

It's suggested that you use the, B<auto_pickup.pl> extension that's mentioned in the above documentation, as this method has less testing  done to it, but if you can't be bothered (and for the sake of variety), this method is available. 

If you do enable this option, every single time the, I<mail.cgi> program is run, the mailing monitor will be run just before the program quits. This makes things convenient, since you can you just have a cronjob set to run Dada Mail: 

 */5 * * * * /usr/bin/curl http://example.com/cgi-bin/dada/mail.cgi > /dev/null

or, 

 */5 * * * * cd /home/youraccount/cgi-bin/dada/ /usr/bin/perl ./mail.cgi > /dev/null

And you have a mailing monitor running, without any extra scripts to installed. It may also be convenient, if you want the mailing monitor that the C<auto_pick.pl> extension provides, but you don't have access to, or don't know how to set a cronjob. 

=cut

$MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION ||= 0; 

=pod

=head2 $ENFORCE_CLOSED_LOOP_OPT_IN

Set to, C<1> by default, C<$ENFORCE_CLOSED_LOOP_OPT_IN> enables the Closed-Loop Opt-In System in Dada Mail and disables other features in Dada Mail that work around being 100% in conformance to Dada Mail's Closed-Loop Opt-In System. 

It's B<highly> suggested to leave this C<$ENFORCE_CLOSED_LOOP_OPT_IN> set to, C<1>. 

=head4 More Information: 

L<http://dadamailproject.com/installation/using_dada_mail.html>

=cut

$ENFORCE_CLOSED_LOOP_OPT_IN ||= 1; 


=pod 

=head2 FCKEditor Integration - $FCKEDITOR_URL

Currently, Dada Mail can use an inline HTML WYSIWYG Editor called FCKEditor for 
authoring of the HTML version of the mailing list message. To do this, 
you need to install FCKEditor. 

These screencasts could also help you out: 

http://www.youtube.com/watch?v=AgNTNygI4MM&hd=1

http://www.youtube.com/watch?v=uRdDOO5n_Cc&hd=1

How to install FCKeditor: 

Download FCKeditor at: 

http://www.fckeditor.net/download/default.html

Uncompress the distribution you receive. It should make a directory called, "fckeditor"

You'll want to put this entire directory into your public html directory of your hosting accout. Take note of the URL you'll need to access this directory. 

Set the B<$FCKEDITOR_URL> Config.pm variable to this URL. 

Done!

One thing to make sure is that you're install FCKeditor under the same subdomain as your Dada Mail is installed. For example, if Dada Mail is at: 

L<http://www.example.com/cgi-bin/dada/mail.cgi>

FCKeditor has to be installed at something like: 

L<http://www.example.com/fckeditor>

and not, 

L<http://different-subdomain.example.com/fckeditor>

To tweak the configuration of how FCKeditor works within Dada Mail (advanced stuff), see the: 

/dada/DADA/Template/templates/FCKeditor_default_js_options.tmpl

file. 

=cut

$FCKEDITOR_URL ||= undef; 
						 # example: http://example.com/fckeditor
                         #
                         # Remember to put single quotes around the URL
                         # and a semicolon at the end: 
                         # $FCKEDITOR_URL ||= 'http://example.com/fckeditor'; 


=head2 CKeditor Integration - $CKEDITOR_URL (Experimental!) 

CKEditor is the newer version of FCKeditor. It works a little differently and doesn't
have full coverage of all the features that FCKeditor has (most notably, there's no free
File/Image Upload file browser - boo!), so Dada Mail is going 
to support both for a little while, until we're completely comfortable with 
CKEditor. 

The support for CKEditor is experimental. 

CKEditor will only be available in the, "Send a Message", "Send a Webpage" and the, "List Invitation" screens. 

=head3 How to install CKeditor: 

Download CKeditor at: 

L<http://ckeditor.com/download>

Uncompress the distribution you receive. It should make a directory called, "ckeditor"

You'll want to put this entire directory into your public html directory of your hosting accout. 
Take note of the URL you'll need to access this directory. 

Set the B<$CKEDITOR_URL> Config.pm variable to this URL. 

Done!

One thing to make sure is that you're install CKeditor under the same subdomain 
as your Dada Mail is installed. For example, if Dada Mail is at: 

L<http://www.example.com/cgi-bin/dada/mail.cgi>

CKeditor has to be installed at something like: 

L<http://www.example.com/ckeditor>

and not, 

L<http://different-subdomain.example.com/ckeditor>

=cut

$CKEDITOR_URL ||= undef; 
						 # example: http://example.com/ckeditor
                         #
                         # Remember to put single quotes around the URL
                         # and a semicolon at the end: 
                         # $CKEDITOR_URL ||= 'http://example.com/ckeditor';



=pod

=head2 Multiple Mailing List Sending

=head3 MULTIPLE_LIST_SENDING

Set this variable to, C<1> to enable Multiple Mailing List Sending. 

Set this variable to, C<0> to disable Multiple Mailing List Sending. 

=head3 $MULTIPLE_LIST_SENDING_TYPE

Set to, C<merged> or, C<individual> 

=head4 More Information

See: 

L<http://dadamailproject.com/support/documentation/features-multiple_list_sending.pod.html>

=cut


$MULTIPLE_LIST_SENDING      ||= 0; 

$MULTIPLE_LIST_SENDING_TYPE ||= 'merged' ; # individual 


=pod

=head2 $LOG_VIEWER_PLUGIN_URL 

=cut 

$LOG_VIEWER_PLUGIN_URL ||= undef; 

=head2 $SCREEN_CACHE - Caching HTML Screens

Setting B<SCREEN_CACHE> to, 1 will save rendered HTML screens for 
future use, instead of having the program recreate them each and 
every time a certain screen is needed. 

If you have dynamic information in list templates, you may not 
want to use this option. 

More information: 

http://dadamailproject.com/support/documentation/FAQ-general.pod.html.html#is_there_a_way_to_speed_up_screen_rendering__how_to_use_the_screen_cache_

=cut



$SCREEN_CACHE ||= 1; 


=pod

=head2 $GLOBAL_BLACK_LIST

A global black list means that all lists being run under Dada Mail 
use the same black list. Change the value to, "1" to enable.

This feature is only available using the SQL Subscriber backend.

=cut

$GLOBAL_BLACK_LIST ||= 0; 


=pod

=head2 $GLOBAL_UNSUBSCRIBE

Global Unsubscribe means that when a person unsubscribes from one list, they're 
unsusbcribed from every list under Dada Mail. Change the value to, "1" to enable.

This feature is only available using the SQL Subscriber backend.

It's advised that you take advantage of this feature if you also use the Global 
List Sending feature. 

=cut

$GLOBAL_UNSUBSCRIBE ||= 0; 


=pod

=head2 $HIDDEN_SUBSCRIBER_FIELDS_PREFIX

There may be a situation where you'd like to have a field about a subscriber that isn't publically available for a subscriber 
to fill out. If this is the case, when naming the field, create the field with the name prefixed with what is saved in the, 
C<$HIDDEN_SUBSCRIBER_FIELDS_PREFIX> variable. By default, this is set to, C<_> (underscore) 

=cut

$HIDDEN_SUBSCRIBER_FIELDS_PREFIX ||= '_'; 


=pod 

=head2 @PING_URLS

@PING_URLS holds the URLS that should be sent an XML-RPC message 
when you add a new message to your archive.

Here's more information: 

http://www.xmlrpc.com/weblogsCom

You'll need the XMLRPC::Lite Perl module installed: 

http://search.cpan.org/~rjray/RPC-XML-0.57/

=cut

@PING_URLS = qw(

	http://rpc.pingomatic.com/
	http://rpc.weblogs.com/RPC2
	http://ping.blo.gs/
)	unless scalar @PING_URLS;


=pod

=head2 $DEFAULT_SCREEN

If no parameters are passed to the mail.cgi script, you will see the
default or main Dada Mail page. You can override that by setting any 
URL you want into $DEFAULT_SCREEN.

=cut

$DEFAULT_SCREEN ||= '';

=pod

If you do override this screen, it is recommended that you provide 
some way to at least unsubscribe to every one of your lists.

=cut


=pod

=head2 $DEFAULT_ADMIN_SCREEN

By default, when you log into the administration area you are shown
the "Send a Message" screen. You can specify a different URL to 
go to by changing the $DEFAULT_ADMIN_SCREEN variable.

=cut



$DEFAULT_ADMIN_SCREEN ||= $S_PROGRAM_URL.'?f=send_email';

=pod

=head2 $DEFAULT_LOGOUT_SCREEN

When a user clicks the, "Logout" link on left hand menu of the control panel, they'll 
be redirected to the URL located in the, B<$DEFAULT_LOGOUT_SCREEN> variable. By default, 
this is set to the, B<$PROGRAM_URL> variable. 

=cut

$DEFAULT_LOGOUT_SCREEN ||= $S_PROGRAM_URL . '?f=' . $ADMIN_FLAVOR_NAME; 

   

=pod 

=head2 $ADMIN_MENU

This generates the admin menu's various links and features, which can
then be turned on and off via the control panel. You shouldn't fool
around with $ADMIN_MENU itself unless you want to add a feature, like 
a plugin.

=cut

# If you do put the $ADMIN_MENU variable in the outside config file, 
# make sure to also! put the below line (uncommented):
#
#  $S_PROGRAM_URL = $PROGRAM_URL
#
# Before the $ADMIN_URL variable, as well as the below 5 lines of code: 

my $PLUGIN_URL            = $S_PROGRAM_URL; 
   $PLUGIN_URL            =~ s/\/(\w+)\.(cgi|pl)$/\//;
   $PLUGIN_URL           .= 'plugins';
my $EXT_URL = $PLUGIN_URL; 
   $EXT_URL =~ s/plugins/extensions/; 

$ADMIN_MENU ||= [

	{-Title      => 'Mass Mailing',
	 -Activated  => 1,
	 -Submenu    => [

					{ 
					-Title      => 'Send a Message',
					 -Title_URL  => "$S_PROGRAM_URL?f=send_email",
					 -Function   => 'send_email',
					 -Activated  => 1,
					},

					{-Title      => 'Send a Webpage',
					 -Title_URL  => "$S_PROGRAM_URL?f=send_url_email",
					 -Function   => 'send_url_email',
					 -Activated  => 1,
					},

					{-Title      => 'Monitor Your Mailings <!-- tmpl_var list_mailouts -->/<!-- tmpl_var total_mailouts -->',
					 -Title_URL  => "$S_PROGRAM_URL?f=sending_monitor",
					 -Function   => 'sending_monitor',
					 -Activated  => 1,
					},

			]
	},


	{-Title      => 'Your Subscribers',
	 -Activated  => 1,
	 -Submenu    => [
					{-Title      => 'View',
					 -Title_URL  => "$S_PROGRAM_URL?f=view_list",
					 -Function   => 'view_list',
					 -Activated  => 1,
					},

					{-Title      => 'Invite<!-- tmpl_if list_settings.enable_mass_subscribe -->/Add<!-- /tmpl_if -->',
					 -Title_URL  => "$S_PROGRAM_URL?f=add",
					 -Function   => 'add',
					 -Activated  => 1,
					},

					{-Title      => 'Remove',
					 -Title_URL  => "$S_PROGRAM_URL?f=delete_email",
					 -Function   => 'delete_email',
					 -Activated  => 1,
					},

					{-Title      => 'Options', 
					 -Title_URL  =>  "$S_PROGRAM_URL?f=subscription_options",
					 -Function   => 'subscription_options',
					 -Activated  => 0,
					},



			]
	},



	{-Title      => 'Your Mailing List',
	 -Activated  => 1,
	 -Submenu    => [
					{-Title      => 'Change List Information',
					 -Title_URL  => "$S_PROGRAM_URL?f=change_info",
					 -Function   => 'change_info',
					 -Activated  => 1,
					},

					{-Title      => 'Change List Password',
					 -Title_URL  => "$S_PROGRAM_URL?f=change_password",
					 -Function   => 'change_password',
					 -Activated  => 1,
					},

					{-Title      => 'Mailing List Options',
					 -Title_URL  => "$S_PROGRAM_URL?f=list_options",
					 -Function   => 'list_options',
					 -Activated  => 1,
					},

					{-Title      => 'Delete This Mailing List',
					 -Title_URL  => "$S_PROGRAM_URL?f=delete_list",
					 -Function   => 'delete_list',
					 -Activated  => 0,
					},
			]
	},


	{-Title      => 'Mail Sending',
	 -Activated  => 1,
	 -Submenu    => [
				
					{-Title      => 'Sending Preferences',
					 -Title_URL  => "$S_PROGRAM_URL?f=sending_preferences",
					 -Function   => 'sending_preferences',
					 -Activated  => 1,
					},

					{-Title      => 'Advanced Sending Preferences',
					 -Title_URL  => "$S_PROGRAM_URL?f=adv_sending_preferences",
					 -Function   => 'adv_sending_preferences',
					 -Activated  => 1,
					},
					{-Title      => 'Mass Mailing Preferences',
					 -Title_URL  => "$S_PROGRAM_URL?f=mass_mailing_preferences",
					 -Function   => 'mass_mailing_preferences',
					 -Activated  => 1,
					},
			]
	},




	{-Title     => 'Message Archives',
	 -Activated => 1,
	 -Submenu   => [
					{-Title      => 'View Archive',
					 -Title_URL  => "$S_PROGRAM_URL?f=view_archive",
					 -Function   => 'view_archive',
					 -Activated  => 1,
					},

					{-Title      => 'Archive Options',
					 -Title_URL  => "$S_PROGRAM_URL?f=archive_options",
					 -Function   => 'archive_options',
					 -Activated  => 1,
					},
					
					{-Title      => 'Advanced Archive Options',
					 -Title_URL  => "$S_PROGRAM_URL?f=adv_archive_options",
					 -Function   => 'adv_archive_options',
					 -Activated  => 1,
					},
			]
	},


	{-Title      => 'Appearance and Templates',
	 -Activated  => 1,
	 -Submenu    => [
					{-Title      => 'Your Mailing List Template',
					 -Title_URL  => "$S_PROGRAM_URL?f=edit_template",
					 -Function   => 'edit_template',
					 -Activated  => 1,
					},


					{-Title      => 'Email Message Templates',
					 -Title_URL  => "$S_PROGRAM_URL?f=edit_type",
					 -Function   => 'edit_type',
					 -Activated  => 1,
					},

					{-Title      => 'HTML Screen Templates',
					 -Title_URL  => "$S_PROGRAM_URL?f=edit_html_type",
					 -Function   => 'edit_html_type',
					 -Activated  => 1,
					},


					{-Title      => 'Subscription Form HTML',
					 -Title_URL  => "$S_PROGRAM_URL?f=html_code",
					 -Function   => 'html_code',
					 -Activated  => 1,
					},

					{-Title      => 'Create a Back Link',
					 -Title_URL  => "$S_PROGRAM_URL?f=back_link",
					 -Function   => 'back_link',
					 -Activated  => 1,
					},



			]
	},


	{-Title     => 'Profiles',
	 -Activated => 1,
	 -Submenu   => [
				     {
				     -Title      => 'Profile Fields',
				     -Title_URL  => "$S_PROGRAM_URL?f=profile_fields",
				     -Function   => 'profile_fields',
				     -Activated  => 1,
				     },
			]
	},




	{-Title      => 'Your List Control Panel',
	 -Activated  => 0,
	 -Submenu    => [
				{-Title      => 'Customize Feature Set',
				 -Title_URL  => "$S_PROGRAM_URL?f=feature_set",
				 -Function   => 'feature_set',
				 -Activated  => 0,
				},

				{-Title      => 'Options',
				 -Title_URL  => "$S_PROGRAM_URL?f=list_cp_options",
				 -Function   => 'list_cp_options',
				 -Activated  => 0,
				}
			], 
	},


	{-Title      => 'Plugins',
	 -Activated  => 1,
	 -Submenu    => [

#					# These are plugins. Make sure you install them 
#					# if you want to use them! 


#					{-Title      => 'Multi List Sub/Unsub Check',
#					 -Title_URL  => $PLUGIN_URL."/multi_admin_subscribers.cgi",
#					 -Function   => 'multi_admin_subscribers',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Boilerplate Example',
#					 -Title_URL  => $PLUGIN_URL."/boilerplate_plugin.cgi",
#					 -Function   => 'boilerplate',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Change the Program Root Password',
#					 -Title_URL  => $PLUGIN_URL."/change_root_password.cgi",
#					 -Function   => 'change_root_password',
#					 -Activated  => 0,
#					},


#					{-Title      => 'Discussion Lists',
#					 -Title_URL  => $PLUGIN_URL."/dada_bridge.pl",
#					 -Function   => 'dada_bridge',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Clickthrough Tracking',
#					 -Title_URL  => $PLUGIN_URL."/clickthrough_tracking.cgi",
#					 -Function   => 'clickthrough_tracking',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Scheduled Mailings',
#					 -Title_URL  => $PLUGIN_URL."/scheduled_mailings.pl",
#					 -Function   => 'scheduled_mailings',
#					 -Activated  => 1,
#					},


#					{-Title      => 'MX Lookup Verification',
#					 -Title_URL  => $PLUGIN_URL."/mx_lookup.cgi",
#					 -Function   => 'mx_lookup',
#					 -Activated  => 1,
#					},


#					{-Title      => 'View List Settings',
#					 -Title_URL  => $PLUGIN_URL."/view_list_settings.cgi",
#					 -Function   => 'view_list_settings',
#					 -Activated  => 1,
#					},


#					{-Title      => 'View Logs',
#					 -Title_URL  => $PLUGIN_URL."/log_viewer.cgi",
#					 -Function   => 'log_viewer',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Email All List Owners',
#					 -Title_URL  => $PLUGIN_URL."/email_list_owners.cgi",
#					 -Function   => 'email_list_owners',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Bounce Handler',
#					 -Title_URL  => $PLUGIN_URL."/dada_bounce_handler.pl",
#					 -Function   => 'dada_bounce_handler',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Screen Cache',
#					 -Title_URL  => $PLUGIN_URL."/screen_cache.cgi",
#					 -Function   => 'screen_cache',
#					 -Activated  => 0,
#					},


				],
			},



					# Shortcut to the Extensions. Make sure you install them 
					# if you want to use them! 

	{-Title      => 'Extensions',
	 -Activated  => 1,
	 -Submenu    => [


#					{-Title      => 'Multiple Subscribe',
#					 -Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
#					 -Function   => 'multiple_subscribe',
#					 -Activated  => 1,
#					},

#					{-Title      => 'Ajax\'d Subscription Form',
#					 -Title_URL  => $EXT_URL."/ajax_include_subscribe.cgi?mode=html",
#					 -Function   => 'ajax_include_subscribe',
#					 -Activated  => 1,
#					},

#					{-Title      => 'Archive Blog Index',
#					 -Title_URL  => $EXT_URL."/blog_index.cgi?mode=html&list=<!-- tmpl_var list_settings.list -->",
#					 -Function   => 'blog_index',
#					 -Activated  => 1,
#					},


#					{-Title      => 'Sending Monitor Outside Extension',
#					 -Title_URL  => $EXT_URL."/auto_pickup.pl",
#					 -Function   => 'auto_pickup',
#					 -Activated  => 1,
#					},


				],
		},


	{-Title      => 'About Dada Mail',
	 -Title_URL  => "$S_PROGRAM_URL?f=manage_script",
	 -Function   => 'manage_script',
	 -Activated  => 1,
	},

	{-Title      => '<!-- tmpl_var PROGRAM_NAME --> Setup Info',
	 -Title_URL  => "$S_PROGRAM_URL?f=setup_info",
	 -Function   => 'setup_info',
	 -Activated  => 1,
	},

	{-Title      => 'Logout',
	-Title_URL  => "$S_PROGRAM_URL?f=logout",
	-Function   => 'logout',
	-Activated  => 1,
	},


	{-Title      => 'Log Into Another List',
	-Title_URL  => "$S_PROGRAM_URL?f=log_into_another_list",
	-Function   => 'log_into_another_list',
	-Activated  => 1,
	},

];



=pod

=head2 $LIST_QUOTA

$LIST_QUOTA, when set to anything other than B<undef>, can be used 
to set the maximum number of lists a Dada Mail install can have at 
one time. 


If set in an outside config file, you may also use the value, B<' '> 
to mean, "no quota"

=cut

$LIST_QUOTA ||= undef; 



=pod

=head2 $SUBSCRIPTION_QUOTA

$SUBSCRIPTION_QUOTA, when set to anything other than B<undef>, can be used 
to set the maximum number of subscribers in a Dada Mail list. 

B<This> variable will basically also set the limit of the 
per-list setting, B<subscription_quota>. Any limit set in this setting 
that's over the limit imposed in the, B<$SUBSCRIPTION_QUOTA> will be ignored. 

If set in an outside config file, you may also use the value, B<' '> 
to mean, "no quota"


=cut

$SUBSCRIPTION_QUOTA ||= undef; 


=head2 $MAILOUT_AT_ONCE_LIMIT

This variable sets how many different mailouts may go out from an 
installation of Dada Mail at one time. Conservatively, this is set to, B<1> 
by default. 

There are a few reasons why you wouldn't want to set this to any higher limit, 
one being that there's a possibility that there is a limit on how many email messages
you are allowed to go out in a specific period of time. 

Another reason is that sending out too many messages at once may cause the server
your running to be overloaded. 

=cut


$MAILOUT_AT_ONCE_LIMIT ||= 1; 


=head2 $MAILOUT_STALE_AFTER

B<$MAILOUT_STALE_AFTER> sets, in seconds, how long a mailout can go with no mailing activity 
until Dada Mail itself won't automatically reload it, from the point it stopped. The default, B<86400> seconds is one full day. 

This variable attempts to safegaurd you against having a dropped mailing that you've, "forgotten" about 
reloading, "mysteriously" and unintentionally. 

A mailout may still be reloaded if this limit has been surpassed, but it must be done manually, 
through the list control panel. 

=cut

$MAILOUT_STALE_AFTER  ||= 86400;

=pod

=head2 $EMAIL_CASE

$EMAIL_CASE configures dada to either lowercase ONLY the 'domain' 
part of an email, or lowercase the entire email address. Lowercasing 
the domain is the correct way, since the 'name' part of an email 
should be case sensitive, but it is almost never handled that way.
Set this to 'lc_domain' to lowercase JUST the domain, or 
set this to 'lc_all' to lowercase the entire email address.

=cut

$EMAIL_CASE ||= 'lc_all'; 


=pod

=head2 @EMAIL_EXCEPTIONS

@EMAIL_EXCEPTIONS allows you to enter email addresses that wouldn't 
normally pass the email address validator. Good for testing offline 
when all you have is, say, root@localhost working.

=cut

@EMAIL_EXCEPTIONS = qw() 
	unless scalar @EMAIL_EXCEPTIONS;
	
	
=pod

=head2 $LIST_IN_ORDER

$LIST_IN_ORDER controls whether your email list is handled in
alphabetical order. Having a list in alphabetical order makes a list 
easier to work with but BE WARNED that this will, especially when 
you're using a plain text list, slow things down. If you have small 
lists then this shouldn't be too much of a problem. Set this variable 
to '1' to have your list sorted, '0', to keep your list unsorted.

=cut

$LIST_IN_ORDER ||= 0; 


=pod

=head2 $SHOW_DOMAIN_TABLE

This variable tells Dada Mail if you should show the 
"Top-Level Domains" table. You might not be interested in this 
information, or maybe your list is so large that your "View List" 
page is having trouble loading. Change this to '0' to stop the table 
from being shown.

=cut

$SHOW_DOMAIN_TABLE ||= 1; 


=pod

=head2 @DOMAINS

The Domain Table can also be customized.
You can put in or take away any top-level domain ending (like com 
or edu) by changing this list. Just add to the list, or delete 
something out of it - follow the pattern. Lots of top-level domain 
listings won't necessarily slow down the "View List" page. 

=cut

@DOMAINS = qw(
biz
com
info
net
org
edu
gov
mil
nu
us
) unless scalar @DOMAINS;


=pod 

=head2 $SHOW_SERVICES_TABLE 

This variable tells Dada Mail if it should show the "Services" table. 
Change it to '0' if you're not interested in this information, or if 
your list is so large that your "View List" page is having trouble 
loading. 

=cut

$SHOW_SERVICES_TABLE ||= 1; 


=pod

=head2 %SERVICES

The services Panel can also be customized.
You can put in or take away any service that you want to track by 
adding a record in between the parentheses. Here's an example of what 
a new service would look like: 
            
	'Altavista'     => 'altavista.net',

Put the NAME of the service on the left, and the domain ending 
that corresponds to that service on the right. The domain 
ending for America Online is "aol.com" - follow the pattern!

=cut

%SERVICES = ( 
'.Mac'          => 'mac.com',
'AOL'           => 'aol.com',
'Compuserve'    => 'compuserve.com', 
'Excite Mail'   => 'excite.com', 
'Gmail'         => 'gmail.com',
'Hotmail'       => 'hotmail.com',
'MSN'           => 'msn.com',
'PO Box'        => 'pobox.com', 
'Prodigy'       => 'prodigy.net',
'Yahoo!'        => 'yahoo.com',
) unless keys %SERVICES; 

# keep a list as a shorthand. 
@SERVICES = values %SERVICES; 


=pod

=head2 $FILE_CHMOD

$FILE_CHMOD is a variable that sets what permission Dada Mail sets 
files to when it initially writes them. You can set it to a few things: 

0660 - probably all you need
0666 - allows anyone to read and write files in the $FILES directory
0755 - probably insecure
0777 - shooting yourself in the foot insecure
0600 - godawful paranoid about the whole thing - life in general, 
       as secure as it gets

=cut

$FILE_CHMOD ||= 0666;

=pod

It's a good idea to figure out what works and leave this variable 
alone after your lists are set up, as you may not be able to access 
a list under a different $FILE_CHMOD.

We've changed what the $FILE_CHMOD Dada Mail is shipped (02/13/01) 
with from 0660 to 0666. Note that this may be less secure than 0660, 
but may solve some problems people are having. Change this back to 
0660 if everything seems to have been running just fine.

=cut


=pod

=head2 $DIR_CHMOD

Similar to $FILE_CHMOD, $DIR_CHMOD sets permissions to Directories 
created with Dada Mail. 
At the moment, this is limited to backup directories. 

=cut

$DIR_CHMOD ||= 0777; 


=pod

=head2 $HTML_CHARSET

=cut

$HTML_CHARSET ||= 'UTF-8'; 

# http://www.w3.org/International/O-charset.html
# http://www.w3.org/International/O-HTTP-charset

 
=pod 

=head1 List Control Panel

=head1 Email Messages and Headers


=head2 @CHARSETS

Charsets that Dada Mail supports. These are the most used; to add 
your own would look like this: 

	'Description	charset',

There's a TAB between the Description and the actual charset: THIS 
IS REALLY IMPORTANT. 

=cut

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


=pod

=head2 @PRECEDENCES

This is the default group of Precedences used when sending Bulk 
Messages. Be warned that the SMTP sending may not support any other
precedence value except the ones listed here. The Default is "undef", 
which will stop the Precedence header from being written out. 

=cut

@PRECEDENCES = (undef,'list','bulk','junk') unless scalar @PRECEDENCES; 


=pod

=head2 @Content_type

These are the default content-types. Add your own, have fun.

=cut

@CONTENT_TYPES = qw(
text/plain
text/html
) unless scalar @CONTENT_TYPES; 


=pod

=head2 %PRIORITIES

Priorities of mailings. I find people sending me things with the 
highest priority to tell me about credit cards really don't garner 
my attention. 

=cut

%PRIORITIES = ( 
'none' => 'Do not set a, "X-Priority" Header.', 
 5     => 'lowest',
 4     => 'low',
 3     => 'normal', 
 2     => 'high',
 1     => 'highest',
) unless keys %PRIORITIES;


=pod 


=head2 @CONTENT_TRANSFER_ENCODINGS

=cut                

@CONTENT_TRANSFER_ENCODINGS = qw(
7bit
8bit
quoted-printable
base64
binary
) unless scalar @CONTENT_TRANSFER_ENCODINGS;

=pod

=head1 Formatting


=head2 Plain Text to HTML Encoding

Dada Mail uses the HTML::TextToHTM CPAN module to convert plain text 
to HTML when showing plain text in archives and things like that. 
You can change the behavior of this formatting by changing what 
arguments get passed to the HTML::TextToHTML module, as described here: 

http://search.cpan.org/~rubykat/txt2html/lib/HTML/TextToHTML.pm#OPTIONS

=cut

$HTML_TEXTTOHTML_OPTIONS ||= {
	escape_HTML_chars => 0, # This will also be overridden to, 0 by Dada Mail
							# BUT! Dada Mail will provide it's own 
							# escape_HTML_chars-like routine

};

=pod

=head2 Templating 

=head3 $TEMPLATE_SETTINGS

=head4 oldstyle_backwards_compatibility

Setting this paramater to, C<1> will allow you to use the old-style tags that 
Dada Mail originaly used. An old-style tag looks like this: 

 [tag]

New-style tags look like this: 

 <!-- tmpl_var tag --> 

And are nothing but HTML::Template-style tags. We'd like to move away from the 
old-style tags, but still 100% support them, for the time being. Setting this 
paramater to, C<0> is B<very> much experimental. 

=cut

$TEMPLATE_SETTINGS ||= { 
	oldstyle_backwards_compatibility => 1, 
};


=pod

=head1 MIME Settings


=head2 %MIME_TYPES

These are the MIME types Dada Mail understands. The file ending is on 
the left, what MIME type it maps to is on the right. Feel free to add
your own. Dada Mail should be able to figure out the MIME type of a
file, but when it can't, it'll fall back on this.

=cut

%MIME_TYPES = ( 
'.gif'  => 'image/gif', 
'.jpg'  => 'image/jpg',
'.png'  => 'image/png',
'.jpeg' => 'image/jpeg',

'.pdf'  => 'application/pdf',
'.psd'  => 'application/psd',

'.html' => 'text/html',
'.txt'  => 'text/plain',

'.doc'  => 'application/msword',
'.xls'  => 'application/x-msexcel',
'.ppt'  => 'application/x-mspowerpoint',

'.mp3'  => 'application/octet-stream',
'.mov'  => 'video/quicktime',

) unless keys %MIME_TYPES;


=pod

=head2 $DEFAULT_MIME_TYPE

In case nothing up there matches what someone is trying to upload, 
there's a default MIME type for a last ditch guess. Some mail 
readers are sophisticated enough to figure out what an attachment is 
without its MIME type, but don't count on it. 

=cut

$DEFAULT_MIME_TYPE ||= 'application/octet-stream'; 


=pod

=head2 $MIME_PARANOID 

This is set for the $MIME::Lite::PARANOID variable. Set it to '1' 
if you don't know if you have the MIME::Base64 or MIME::QuotedPrint
or you don't know what those are. :) 

=cut

$MIME_PARANOID ||= 0;


=pod

=head2 $MIME_HUSH

Set mime_hush to '1' to suppress/unsuppress all warnings coming from 
this module.

=cut

$MIME_HUSH ||= 0;


=pod

=head2 $MIME_OPTIMIZE

Set to: 'faster', 'less memory', or 'no tmp files'. This controls how 
the MIME::Parser works. For more information: 

http://search.cpan.org/~dskoll/MIME-tools-5.417/lib/MIME/Parser.pm#OPTIMIZING_YOUR_PARSER

=cut

$MIME_OPTIMIZE ||= 'no tmp files'; 


=pod

=head1 Default Email Message Templates

The global default Email Message Templates are saved right here in the Config.pm file. 

Many of these email tempaltes are list-centric and can be edited list by list in the list 
control panel under, B<Manage Copy - Email Templates>. If what you desire is to edit an email template 
for just one list, the place to do that is in the list control panel. 

If you desire to set the default email template for all your lists, you'd want to do this in the 
global configuration (right here, or in the outside configuration file) 


=head2 $SUBSCRIBED_MESSAGE

I<(List-centric, editable per list)> 

This is the default "subscription successful!" email message. 
This message can be customized for each list in the list's Control Panel.

=cut

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

* Want to remove yourself from this mailing list at any time? Use this link: 
<!-- tmpl_var list_unsubscribe_link -->

If the above URL is inoperable, make sure that you have copied the 
entire address. Some mail readers will wrap a long URL and thus break
this automatic unsubscribe mechanism. 

* Want more information about this mailing list? Visit:
<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->

* Need Help? Contact: 
<!-- tmpl_var list_settings.list_owner_email -->

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


=pod

=head2 $SUBSCRIPTION_NOTICE_MESSAGE

This email message is sent to the list owner, when a new subscription has been made by a subscriber. 

=cut

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


=pod

=head2 $SUBSCRIPTION_NOTICE_MESSAGE

This email message is sent to the list owner, when a new subscription has been made by a subscriber. 

=cut


$SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE ||= '<!-- tmpl_var list_settings.list_name --> List Owner';
$SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT   ||= '[status] <!-- tmpl_var subscriber.email -->';  
$SUBSCRIPTION_NOTICE_MESSAGE           ||= <<EOF
<!-- tmpl_var subscriber.email --> has <!-- tmpl_var status --> on list: <!-- tmpl_var list_settings.list_name -->

Server Time: <!-- tmpl_var date -->
IP Logged:   <!-- tmpl_var REMOTE_ADDR -->
<!-- tmpl_var note -->

<!-- tmpl_if subscriber -->Extra Subscriber information: 
-----------------------------
<!-- tmpl_loop subscriber --> 
<!-- tmpl_var name -->: <!-- tmpl_var value -->

<!-- /tmpl_loop -->-----------------------------<!--/tmpl_if-->

There is now a total of: <!-- tmpl_var num_subscribers --> subscribers.

-<!-- tmpl_var PROGRAM_NAME -->

EOF
; 


=pod

=head2 $UNSUBSCRIBED_MESSAGE

I<(List-centric, editable per list)> 

This is the default "unsubscription successful!" email message. 
This message can be customized for each list in the list's Control Panel.

=cut

$UNSUBSCRIBED_MESSAGE  ||= <<EOF

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

<!-- tmpl_var list_subscribe_link -->

If the above URL is inoperable, make sure that you have copied the 
entire address. Some mail readers will wrap a long URL and thus break
this automatic unsubscribe mechanism. 

You may also change your subscription by visiting this list's main screen: 

<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->

If you're still having trouble, please contact the list owner at: 

	mailto:<!-- tmpl_var list_settings.list_owner_email -->

The following physical address is associated with this mailing list: 

<!-- tmpl_var list_settings.physical_address -->

- mailto:<!-- tmpl_var list_settings.list_owner_email -->

EOF
; 


=pod

=head2 $CONFIRMATION_MESSAGE

I<(List-centric, editable per list)> 

This is the default "subscription confirmation" email message. 
This message can be customized for each list in the list's Control Panel.

=cut

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

<mailto:<!-- tmpl_var list_settings.list_owner_email -->>

The following physical address is associated with this mailing list: 

<!-- tmpl_var list_settings.physical_address -->

- <!-- tmpl_var list_settings.list_owner_email -->

EOF
; 


=pod

=head2 $UNSUB_CONFIRMATION_MESSAGE

I<(List-centric, editable per list)> 

This is the default "subscription confirmation" email message. 
This message can be customized for each list in the list's Control Panel.

=cut


$UNSUB_CONFIRMATION_MESSAGE ||= <<EOF   

This message has been sent to you as the final step to confirm your
email *removal* for the following list: 

<!-- tmpl_var list_settings.list_name -->

To confirm this unsubscription, please follow the URL below:

<!-- tmpl_var list_confirm_unsubscribe_link -->

(Click the URL above, or copy and paste the URL into your browser. 
Doing so will remove you to this list.)

-----------------------------------------------------------------------

The following is the description given for this list: 

<!-- tmpl_var list_settings.info -->

-----------------------------------------------------------------------

This Closed-Loop Opt-Out confirmation email was sent to protect the privacy
of the owner of this email address. 

Furthermore, the following privacy policy is associated with this list: 

<!-- tmpl_var list_settings.privacy_policy -->

Please read and understand this privacy policy. 

If you did not ask to be removed from this particular list, please
do not visit the confirmation URL above. The confirmation for removal 
will not go through and no other action on your part will be needed.

To contact the owner of this email list, please use the address below: 

<mailto:<!-- tmpl_var list_settings.list_owner_email -->>

The following physical address is associated with this mailing list: 

<!-- tmpl_var list_settings.physical_address -->


- <mailto:<!-- tmpl_var list_settings.list_owner_email -->>

EOF
; 


$SUBSCRIPTION_REQUEST_APPROVED_MESSAGE ||= $SUBSCRIBED_MESSAGE; 
$SUBSCRIPTION_REQUEST_DENIED_MESSAGE   ||= <<EOF
Hello! 

You've recently have asked to be subscribed to: 

	<!-- tmpl_var list_settings.list_name --> 
	
This subscription request has been denied by the list owner. 

-- mailto:<!-- tmpl_var list_settings.list_owner_email --> 

EOF
; 



=pod

=head2 $MAILING_LIST_MESSAGE

I<(List-centric, editable per list)> 

This is the default "Mailing List!" email message. 
This message can be customized for each list in the list's Control Panel.

=cut

$MAILING_LIST_MESSAGE ||= <<EOF  
(Mailing list information, including how to remove yourself, is located at the end of this message.)
__ 

<!-- tmpl_var message_body -->

-- 
Here's a reminder about your current mailing list subscription: 

You are subscribed to the following mailing list:
  
	<!-- tmpl_var list_settings.list_name -->
	
using the following email:
 
	<!-- tmpl_var subscriber.email -->

* Want to remove yourself from this mailing list at any time? Use this link: 
<!-- tmpl_var list_unsubscribe_link -->

If the above URL is inoperable, make sure that you have copied the 
entire address. Some mail readers will wrap a long URL and thus break
this automatic unsubscribe mechanism. 

* Need Help? Contact: 
<!-- tmpl_var list_settings.list_owner_email -->

* Privacy Policy: 
<!-- tmpl_var list_settings.privacy_policy -->

* Physical Address:
<!-- tmpl_var list_settings.physical_address -->

EOF
; 


=pod

=head2 $MAILING_LIST_MESSAGE_HTML

I<(List-centric, editable per list)> 

Similar to $MAILING_LIST_MESSAGE, but used specifically for HTML messages. 

=cut

$MAILING_LIST_MESSAGE_HTML ||= <<EOF
<!--opening-->
<p><em>(Mailing list information, including how to remove yourself, 
is located at the end of this message.)</em><br/></p>
<!--/opening-->

<!-- tmpl_var message_body -->

<!--signature-->

<p>
 Here's a reminder about your current mailing list subscription:
</p>

<ul> 

<li>
<p>
 You are subscribed to the following mailing list:
</p>
</li> 
<ul> 

 <li>
  <p>
   <strong>
    <a href="<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/"> 
     <!-- tmpl_var list_settings.list_name -->
    </a> 
   </strong>
  </p>
 </li> 
</ul> 
	
<p>using the following email:</p>

<ul> 
 <li>
  <p>
   <strong>
    <!-- tmpl_var subscriber.email -->
   </strong>
  </p>
 </li>
</ul> 
</li> 
 <li>
  <p>Want to remove yourself from this mailing list at any time? Use this link:</p>
  <p>
   <a href="<!-- tmpl_var list_unsubscribe_link -->">
    <!-- tmpl_var list_unsubscribe_link -->
   </a> 
  </p> 

<p>If the above URL is inoperable, make sure that you have copied the 
entire address. Some mail readers will wrap a long URL and thus break
this automatic unsubscribe mechanism.</p> 

</li>
<li>
 <p>
  <strong>
   Need Help? Contact:
  </strong>
 </p> 
 <p>
  <a href="<!-- tmpl_var list_settings.list_owner_email -->">
   <!-- tmpl_var list_settings.list_owner_email -->
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

<!--/signature-->

EOF
; 


=pod

=head2 $NOT_ALLOWED_TO_POST_MESSAGE

I<(List-centric, editable per list)> 

This message is sent to someone who is not allowed to post to your 
list using Dada Bridge plugin. If you do not use the 
Dada Bridge plugin, this won't be of any use to you! This message 
can be customized for each list in the list's Control Panel.

=cut

$NOT_ALLOWED_TO_POST_MESSAGE ||= <<EOF  

<!-- tmpl_var PROGRAM_NAME --> Error - 

Sorry, it doesn't seem that you are allowed to post on: 

	<!-- tmpl_var list_settings.list_name -->
	
with the email address: 

    <!-- tmpl_var subscriber.email -->

This may be because you have to first subscribe to the list to post to the 
list itself. 

Please see: 

	<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->

for more information, or email the list owner at: 

	<mailto:<!-- tmpl_var list_settings.list_owner_email -->>

EOF
; 

=pod

=head2 $NOT_ALLOWED_TO_POST_NOTICE_MESSAGE

This message is sent to the list owner, usually in a discussion list setup, when a message is sent to the list from an email address
who does not have access to do so. 

=cut

$NOT_ALLOWED_TO_POST_NOTICE_MESSAGE_SUBJECT ||=  "<!-- tmpl_var PROGRAM_NAME --> Error - Not Allowed to Post On <!-- tmpl_var list_settings.list_name --> (original message attached)", 	
$NOT_ALLOWED_TO_POST_NOTICE_MESSAGE         ||= <<EOF
The attached message was not sent from one of the subscribers of <!-- tmpl_var list_settings.list_name -->

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
; 

=pod

=head2 $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE

I<(List-centric, editable per list)> 

This message is sent out only if someone that's already currently subscribed to a list tries to subscribe again and 
you've set the preferences to send an email out, instead of giving this message in the web browser.


=cut


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

If you would like to change your subscription, please visit this address: 

<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/

If the above URL is inoperable, make sure that you have copied the 
entire address. Some mail readers will wrap a long URL and thus break
this automatic unsubscribe mechanism. 

To contact the owner of this email list, please use the address below: 

<mailto:<!-- tmpl_var list_settings.list_owner_email -->>


- <!-- tmpl_var list_settings.list_owner_email -->

EOF
; 


=pod

=head2 $YOU_ARE_NOT_SUBSCRIBED_MESSAGE

I<(List-centric, editable per list)> 

This message is sent out only if someone that's not currently subscribed to a list tries to unsubscribe and
you've set the preferences to send an email out, instead of giving this message in the web browser.


=cut


$YOU_ARE_NOT_SUBSCRIBED_MESSAGE ||= <<EOF

Hello, 

This message has been sent to you because a request to remove: 

<!-- tmpl_var subscriber.email -->

from the list: 

<!-- tmpl_var list_settings.list_name -->

was just made. This email address is actually not currently subscribed.

This message has been sent to protect your privacy and only allow this information to be 
available to you. 

If you would like to change your subscription, please visit this address: 

<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/

To contact the owner of this email list, please use the address below: 

<mailto:<!-- tmpl_var list_settings.list_owner_email -->>

EOF
;


=pod

=head2 $MAILING_FINISHED_MESSAGE

This email message is sent to the list owner, when a mass mailing has finished. 

=cut


$MAILING_FINISHED_MESSAGE_SUBJECT ||= '<!-- tmpl_var list_settings.list_name -->  Mailing Complete - <!-- tmpl_var message_subject -->'; 
$MAILING_FINISHED_MESSAGE         ||= <<EOF
Your List Mailing has been successful!
-----------------------------------------------------------------------
Your mailing has reached: <!-- tmpl_var addresses_sent_to --> e-mail address(es)

Mailing Started:    <!-- tmpl_var mailing_start_time -->                              
Mailing Ended:      <!-- tmpl_var mailing_finish_time -->                        
Total Mailing Time: <!-- tmpl_var total_mailing_time -->
Last Email Sent to: <!-- tmpl_var last_email_send_to -->                               

A copy of your Mailing List Message has been attached.
	   	
-<!-- tmpl_var PROGRAM_NAME -->

EOF
;

=pod

=head2 $TEXT_INVITE_MESSAGE

The text version of the list invitation message.

=cut

$TEXT_INVITE_MESSAGE ||= <<EOF  
Hello!

The List Owner of, "<!-- tmpl_var list_settings.list_name -->" (<!-- tmpl_var list_settings.list_owner_email -->) has invited you to Subscribe!
 
* Here's a brief description of this mailing list: 

<!-- tmpl_var list_settings.info --> 

* If you'd like to subscribe, just click the link below: 
<!-- tmpl_var list_confirm_subscribe_link --> 

(You can always remove yourself from the mailing list, at any time) 
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

$PROFILE_ACTIVATION_MESSAGE_SUBJECT ||= 'Profile Authorization Code for, <!-- tmpl_var profile.email -->'; 
$PROFILE_ACTIVATION_MESSAGE         ||= <<EOF

Hello, here's the authorization link to activate your <!-- tmpl_var PROGRAM_NAME --> Profile: 

<!-- tmpl_var PROGRAM_URL -->/profile_activate/<!-- tmpl_var profile.email_name -->/<!-- tmpl_var profile.email_domain -->/<!-- tmpl_var auth_code -->/ 

-- <!-- tmpl_var PROGRAM_NAME --> 

EOF
; 

$PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT ||= 'Profile Authorization Code for, <!-- tmpl_var profile.email -->'; 
$PROFILE_RESET_PASSWORD_MESSAGE         ||= <<EOF
Hello, here's the authorization link to reset your <!-- tmpl_var PROGRAM_NAME --> Profile Password:

<!-- tmpl_var PROGRAM_URL -->/profile_reset_password/<!-- tmpl_var profile.email_name -->/<!-- tmpl_var profile.email_domain -->/<!-- tmpl_var auth_code -->/

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
;


$PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT ||= 'Profile Update Email Authorization Code for, <!-- tmpl_var profile.email -->'; 
$PROFILE_UPDATE_EMAIL_MESSAGE         ||= <<EOF

Hello, here's the authorization link to update your <!-- tmpl_var PROGRAM_NAME --> Profile email address from: 

	<!-- tmpl_var profile.email --> 
	
to: 

	<!-- tmpl_var profile.updated_email --> 
	
Please click the link below to make this update: 	

<!-- tmpl_var PROGRAM_URL -->/profile_update_email/<!-- tmpl_var profile.email_name -->/<!-- tmpl_var profile.email_domain -->/<!-- tmpl_var profile.update_email_auth_code -->/

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
;
$LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT ||= '<!-- tmpl_var list_settings.list_name --> Mailing List Confirmation Password Reset'; 
$LIST_CONFIRM_PASSWORD_MESSAGE         ||= <<EOF
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

$LIST_RESET_PASSWORD_MESSAGE_SUBJECT ||= '<!-- tmpl_var list_settings.list_name --> Mailing List Password Reset';
$LIST_RESET_PASSWORD_MESSAGE         ||= <<EOF

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



=pod

=head2 $HTML_INVITE_MESSAGE

The HTML version of the list invitation message.

=cut

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
 <p>
  <em>
   (You can always remove yourself from the mailing list, at any time)
  </em>
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


=pod

=head2 $SEND_ARCHIVED_MESSAGE

I<(List-centric, editable per list)> 

The text version of the message sent when an archived message is sent 
to a friend.

=cut

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


=pod

=head2 $HTML_SEND_ARCHIVED_MESSAGE

The HTML version of the message sent when an archived message is sent 
to a friend.

=cut

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



=pod

=head1 Default HTML Screen Templates

The global default HTML Screen Templates are saved right here in the Config.pm file. 

Many of these HTML screen templates are list-centric and can be edited list by list in the list 
control panel under, B<Manage Copy -  HTML Screen Templates>. If what you desire is to edit an HTML screen template 
for just one list, the place to do that is in the list control panel. 

If you desire to set the default HTML screen template for all your lists, you'd want to do this in the 
global configuration (right here, or in the outside configuration file) 


=head2 $HTML_CONFIRMATION_MESSAGE

I<(List-centric, editable per list)> 

Shown when a request to subscribe is successful.

=cut

$HTML_CONFIRMATION_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Please Confirm Your Subscription" --> 

<h1>Please confirm your mailing list subscription</h1>  

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
this mailing list, please contact the list owner at: </p>

<p style="text-align:center">
 <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
  <!-- tmpl_var list_settings.list_owner_email -->
 </a>
</p>

EOF
; 


=pod

=head2 $HTML_UNSUB_CONFIRMATION_MESSAGE

I<(List-centric, editable per list)> 

Shown when a request to unsubscribe is successful.

=cut

$HTML_UNSUB_CONFIRMATION_MESSAGE ||= <<EOF

<!-- tmpl_set name="title" value="Please Confirm Your Unsubscription" -->
<h1>Please confirm your mailing list unsubscription</h1>  

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

<p>This confirmation process, known as Closed-Loop Opt-In Confirmation, 
has been put into place to protect the privacy of the owner of this 
email address.</p>

<p>If you do not receive a confirmation for <em>removal</em> in the 
next twenty-four hours or you have any other questions regarding this 
mailing list, please contact the list owner at: </p>

<p style="text-align:center">
 <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
  <!-- tmpl_var list_settings.list_owner_email -->
 </a>
</p>

EOF
; 
 

=pod

=head2 $HTML_SUBSCRIBED_MESSAGE

I<(List-centric, editable per list)> 

Shown when a subscription is successful.

=cut

$HTML_SUBSCRIBED_MESSAGE ||= <<EOF 

<!-- tmpl_set name="title" value="Subscription Successful" -->

<h1>Subscription is successful!</h1>

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

<p>An email will be sent to your address giving you more details of 
this subscription, including how to unsubscribe in the future.</p>

EOF
; 

=head2 $HTML_SUBSCRIPTION_REQUEST_MESSAGE

I<(List-centric, editable per list)> 

=cut


$HTML_SUBSCRIPTION_REQUEST_MESSAGE ||= <<EOF 

<!-- tmpl_set name="title" value="Subscription Request Successful" -->

<h1>Your Request For Subscription is Complete</h1>

<p>The list owner for:</p>

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




=pod

=head2 $HTML_UNSUBSCRIBED_MESSAGE

I<(List-centric, editable per list)> 

Shown when an unsubscription is successful.

=cut

$HTML_UNSUBSCRIBED_MESSAGE ||= <<EOF  

<!-- tmpl_set name="title" value="Unsubscription Successful" --> 

<h1>You have been unsubscribed from the list: <!-- tmpl_var list_settings.list_name --></h1>

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

=pod

=head1 Misc. Text

For some reason, the text below is saved in the Config.pm: 

=head2 $GOOD_JOB_MESSAGE

=cut

# Good Job! 
$GOOD_JOB_MESSAGE ||= '<p class="positive">Your changes have been saved successfully!</p>'; 

=pod

=head2 $NO_ONE_SUBSCRIBED

=cut

# No one's subscribed? 
$NO_ONE_SUBSCRIBED ||= '<p class="error">No one is subscribed to your list at the moment.</p>'; 

######################################################################

=pod

=head1 List Setting Defaults


=head2 %LIST_SETUP_DEFAULTS

These defaults will be used when CREATING a new list. These defaults 
will also be used for existing lists if there isn't a variable 
already set. These values correspond to the values created in the 
list databases. An example would be: 

	%LIST_SETUP_DEFAULTS = ( 
	                         black_list    => 1, 
	                         send_via_smtp => 1,
	                        );

This would setup all lists created now with blacklists on, and mail
being sent using SMTP. 

Note! You *can* enter the passwords for both POP3 
(for POP-before-SMTP stuff) and the SMTP SASL password here, but they will be 
in plain text. When these passwords are saved in the list settings, they are 
encrypted. 

=cut

%LIST_SETUP_DEFAULTS = (
	
	list                               => '', # don't default...
	info                               => '', 
	
	# (Dummy)
	list_info                          => undef, 
	
	admin_email                        => undef, 
	list_owner_email                   => '', 
	privacy_policy                     => '', 
	list_name                          => '', 
	physical_address                   => '',
	password                           => '', # you'll need to encrypt it to use this...

# Misc...

    cipher_key                         => undef, 
    admin_menu                         => undef, 
    
    
	#quotas
	use_subscription_quota             => 0, 
	    subscription_quota             => 0, 

	#mailing list options 	
	mx_check                           => 0,
	closed_list                        => 0, 
	show_hidden                        => 0,	
	hide_list                          => 0,
	
	email_your_subscribed_msg          => 1,  # Notice the incorrect, "your" instead of, "you're" - doh!
	email_you_are_not_subscribed_msg   => 0, 
	
	send_unsub_success_email           => 1,
	send_sub_success_email             => 1,
	
	get_sub_notice                     => 1, 
	get_unsub_notice                   => 1, 
	
	enable_closed_loop_opt_in                   => 1, # Closed-Loop Opt-In 
	skip_sub_confirm_if_logged_in      => 0, 
	unsub_confirm_email                => 1, # Closed-Loop Opt-Out
	                                         # I know, confusing. 
	skip_unsub_confirm_if_logged_in    => 0, 
	limit_sub_confirm                  => 1, 
	limit_unsub_confirm                => 1,  
	
	use_alt_url_sub_confirm_success      => 0,
	    alt_url_sub_confirm_success_w_qs => 0, 
		alt_url_sub_confirm_success      =>  '',
	
	use_alt_url_sub_confirm_failed      => 0,
	    alt_url_sub_confirm_failed_w_qs => 0, 
		alt_url_sub_confirm_failed      => '',
	
	use_alt_url_sub_success            => 0,
	    alt_url_sub_success_w_qs       => 0, 
		alt_url_sub_success            => '',
	
	use_alt_url_sub_failed             => 0,
		alt_url_sub_failed_w_qs        => 0, 
		alt_url_sub_failed             => '',
	
	use_alt_url_unsub_confirm_success      =>  0,
	    alt_url_unsub_confirm_success_w_qs => 0, 
		alt_url_unsub_confirm_success      => '',
	 
	use_alt_url_unsub_confirm_failed      => 0,
		alt_url_unsub_confirm_failed      => '',
	    alt_url_unsub_confirm_failed_w_qs => 0, 

	use_alt_url_unsub_success          => 0,
	    alt_url_unsub_success_w_qs     => 0, 
		alt_url_unsub_success          => '',
	
	use_alt_url_unsub_failed           => 0,
	    alt_url_unsub_failed_w_qs      => 0, 
		alt_url_unsub_failed           => '',
	enable_subscription_approval_step => 0, 
	captcha_sub                        => 0, 	

# SMTP Options

	smtp_server                  => undef,
	smtp_port                    => 25, 
	
    use_smtp_ssl                 => 0,     
	use_pop_before_smtp          => 0,

	pop3_server                  => undef, 
	pop3_username                => undef, 
	pop3_password                => undef, 
	pop3_use_ssl                 => undef, 
	
	# Can be set to, 
	# BEST, PASS, APOP, or CRAM-MD5
	pop3_auth_mode               => 'BEST',  
	
	
	set_smtp_sender              => 1,  
	
	use_sasl_smtp_auth           => 0, 
	sasl_auth_mechanism          => 'PLAIN', 
	sasl_smtp_username           => undef, 
	sasl_smtp_password           => undef, 
	
	smtp_max_messages_per_connection => undef, 
	
# Sending Options 
	
	# Enable Batch Sending
	enable_bulk_batching        => 1,
	
	# adjust_batch_sleep_time
	adjust_batch_sleep_time       => 1, 
	# Receive Finishing Message 
	get_finished_notification   => 1,
	
	# Send: [x] message(s) per batch 
	mass_send_amount            => 1, 

    # and then wait: [x] seconds, before the next
	bulk_sleep_amount           => 8, 
	
	# Auto-Pickup Dropped List Message Mailings 
    auto_pickup_dropped_mailings       => 1, 
    
    # Restart Mailings After Each Batch 
    # TODO - this variable should really be called, "reload_mailings_after_each_batch"
	restart_mailings_after_each_batch  => 0, 
    
    # Send Email Using SMTP 
    send_via_smtp                      => 0, 


	# For mass mailings, connect only once per batch? 
	# 0 = no
	# 1 = yes!
	smtp_connection_per_batch         => 0,
	
# adv sending options

	precedence                   => undef, 
	charset                      => 'UTF-8	UTF-8',
	
	# (Dummy)
	charset_value                => 'UTF-8', 
	priority                     => 3,
	
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

	view_list_subscriber_number  => 100,
	
# archive prefs

	archive_messages             => 1,
	show_archives                => 1,
	archives_available_only_to_subscribers => 0, 
	archive_subscribe_form       => 1,
	archive_search_form          => 1,
	captcha_archive_send_form    => 0, 
	archive_send_form            => 0,
	send_newest_archive          => 0, 
	
	archive_show_second          => 0, 
	archive_show_hour_and_minute => 0, 
	archive_show_month           => 1,
	archive_show_day             => 1,
	archive_show_year            => 1,
	archive_index_count          => 10,
	
	
	sort_archives_in_reverse     => 1,
	disable_archive_js           => 1, 
	style_quoted_archive_text    => 1,
	stop_message_at_sig          => 1, 
	publish_archives_rss         => 1,
	ping_archives_rss            => 0,
	html_archives_in_iframe      => 0, 
	display_attachments          => 1,
	add_subscribe_form_to_feeds  => 1, 
	
	add_social_bookmarking_badges => 1, 
	
	# Can be set to, "none", "spam_me_not", or, "recaptcha_mailhide"
	archive_protect_email         => 'spam_me_not', 
	
	enable_gravatars              => 0, 
	default_gravatar_url          => undef, 
	
# archive editing prefs
	
	editable_headers             => 'Subject', 
 	
	#blacklist 
	black_list                           => 1,
	add_unsubs_to_black_list             => 1,
	allow_blacklisted_to_subscribe       => 1,
	allow_admin_to_subscribe_blacklisted => 0,


# White List Prefs

	 # white list 
	 enable_white_list            => 0,
		
# Your Mailing List Template Prefs

	get_template_data                => 'from_default_template',
	url_template                     => '',
	apply_list_template_to_html_msgs => 0, 
	
# Create a back link prefs
    
    website_name       => '', 
    website_url        => '', 
	
	
	
#SQL stuff
	
	# I don't think this is honored...
	# Don't change.
	subscription_table               => 'dada_subscribers',
	
	# Not used?
	hard_remove                  => 1,
	# Not used?
	merge_fields                 => '',
	
	
	fallback_field_values        => '',

# Email Templates

    confirmation_message_subject               => '<!-- tmpl_var list_settings.list_name --> Mailing List Subscription Confirmation',
	confirmation_message                       =>   $CONFIRMATION_MESSAGE,
	
	subscription_request_approved_message_subject => 'Welcome to <!-- tmpl_var list_settings.list_name -->',
	subscription_request_approved_message         => $SUBSCRIPTION_REQUEST_APPROVED_MESSAGE, 
	
	subscription_request_denied_message_subject   => '<!-- tmpl_var list_settings.list_name --> Mailing List Subscription Request - Denied.',
	subscription_request_denied_message           => $SUBSCRIPTION_REQUEST_DENIED_MESSAGE,
	subscription_approval_request_message_subject => '<!-- tmpl_var subscriber.email --> would like to subscribe to: <!-- tmpl_var list_settings.list_name -->',
	subscription_approval_request_message         => $SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE, 
	
    subscribed_message_subject                 =>   'Welcome to <!-- tmpl_var list_settings.list_name -->', 
	subscribed_message                         =>   $SUBSCRIBED_MESSAGE, 
	 
    unsub_confirmation_message_subject         => '<!-- tmpl_var list_settings.list_name --> Mailing List Unsubscription Confirmation',
	unsub_confirmation_message                 =>   $UNSUB_CONFIRMATION_MESSAGE,
	
	unsubscribed_message_subject               =>   'Unsubscribed from <!-- tmpl_var list_settings.list_name -->',
	unsubscribed_message                       =>   $UNSUBSCRIBED_MESSAGE, 

    mailing_list_message_from_phrase           =>   '<!-- tmpl_var list_settings.list_name -->', 
    mailing_list_message_to_phrase             =>   '<!-- tmpl_var list_settings.list_name --> Subscriber', 
    mailing_list_message_subject               =>   '<!-- tmpl_var list_settings.list_name --> Message', 
	mailing_list_message                       =>   $MAILING_LIST_MESSAGE,
	mailing_list_message_html                  =>   $MAILING_LIST_MESSAGE_HTML,

												   
    not_allowed_to_post_message_subject        => '<!-- tmpl_var PROGRAM_NAME --> Error - <!-- tmpl_var subscriber.email --> Not Allowed to Post On <!-- tmpl_var list_settings.list_name --> (original message attached)', 
	not_allowed_to_post_message                =>   $NOT_ALLOWED_TO_POST_MESSAGE, 
    

	send_archive_message_subject               => '<!-- tmpl_var archived_message_subject --> (Archive)', 

    you_are_already_subscribed_message_subject => '<!-- tmpl_var list_settings.list_name --> - You Are Already Subscribed', 
    you_are_already_subscribed_message         => $YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE, 

	you_are_not_subscribed_message              => $YOU_ARE_NOT_SUBSCRIBED_MESSAGE,
	you_are_not_subscribed_message_subject      => '<!-- tmpl_var list_settings.list_name --> - You Are Not Subscribed',  

	enable_email_template_expr                 => 0, 
	
# HTML Screen Templates

	html_confirmation_message       =>   $HTML_CONFIRMATION_MESSAGE,
	html_unsub_confirmation_message =>   $HTML_UNSUB_CONFIRMATION_MESSAGE,

	html_subscribed_message         =>   $HTML_SUBSCRIBED_MESSAGE,
	html_unsubscribed_message       =>   $HTML_UNSUBSCRIBED_MESSAGE,
	
	html_subscription_request_message => $HTML_SUBSCRIPTION_REQUEST_MESSAGE,

	send_archive_message            =>   $SEND_ARCHIVED_MESSAGE,
	send_archive_message_html       =>   $HTML_SEND_ARCHIVED_MESSAGE,

# Send a List Invitation

	invite_message_from_phrase      =>   '<!-- tmpl_var list_settings.list_name -->', 
	invite_message_to_phrase        =>   '<!-- tmpl_var list_settings.list_name -->',
	invite_message_text             =>   $TEXT_INVITE_MESSAGE,
	invite_message_html             =>   $HTML_INVITE_MESSAGE,	
	invite_message_subject          =>   'You\'ve been Invited to Subscribe to, "<!-- tmpl_var list_settings.list_name -->"', 
	

# Feature Set

    disabled_screen_view            => 'grey_out', 

# List CP -> Options
	enable_fckeditor                => 1, 
	enable_mass_subscribe           => 0, 
    

# Send me the list password.    
    pass_auth_id                    => undef, 
    


### Plugins 

# Dada Bridge Plugin: 

	group_list                   => 0, 
	
	open_discussion_list         => 0, 
	
	
	discussion_template_defang   => 1,
	only_allow_group_plain_text  => 0,
	add_reply_to                 => 1,
	mail_group_message_to_poster => 1,
	append_list_name_to_subject  => 1,
	
	no_append_list_name_to_subject_in_archives => 1, 
	
	set_to_header_to_list_address     => 0, 
	append_discussion_lists_with      => 'list_shortname',
	send_msgs_to_list                 => 1, 
	disable_discussion_sending        => 1, 
	mail_discussion_message_to_poster => 1, 
	
    ignore_spam_messages                => 0, 
    find_spam_assassin_score_by         => 'looking_for_embedded_headers',
    ignore_spam_messages_with_status_of => 6, 
	rejected_spam_messages              => 'ignore_spam',

    enable_moderation                   => 0, 
    moderate_discussion_lists_with      => 'owner_email',	
    send_moderation_msg                 => 0, 
    send_moderation_accepted_msg        => 0,     
    send_moderation_rejection_msg       => 0, 
    send_msg_copy_address               => '', 
    
    enable_authorized_sending           => 0, 
    authorized_sending_no_moderation    => 0,
    subscriber_sending_no_moderation  => 0,
    
    strip_file_attachments              => 0, 
    file_attachments_to_strip           => '', 
    discussion_pop_server               => '', 
    discussion_pop_username             => '', 
    discussion_pop_email                => '', 
    discussion_pop_password             => '',
    
    discussion_pop_auth_mode            => 'BEST', 
    discussion_pop_use_ssl              => 0, 
    
    send_not_allowed_to_post_msg        => 0, 
    send_invalid_msgs_to_owner          => 0, 
    send_msg_copy_to                    => 0, 
    rewrite_anounce_from_header         => 1,

# Clickthrough Tracking

	clickthrough_tracking               => 0,
	enable_open_msg_logging             => 0, 
	enable_subscriber_count_logging     => 0, 
	enable_bounce_logging               => 0,

    
# dada_digest.pl 
last_digest_sent                        => undef, 
    
) unless keys %LIST_SETUP_DEFAULTS;

%LIST_SETUP_INCLUDE = () 
	unless keys %LIST_SETUP_INCLUDE;


=pod

=head2 %LIST_SETUP_INCLUDE

Similar to, %LIST_SETUP_DEFAULTS, %LIST_SETUP_INCLUDE holds defaults values for lists. 

The difference is that any value NOT set here, will be set, in 
accordance to what %LIST_SETUP_DEFAULTS already has. Because of this,
it's much more convenient to use this variable in the outside config 
file. 

For example, if you set up the bounce handler with the bounce 
email of, "bounces@example.com", 
you could set %LIST_SETUP_INCLUDE to have these values: 


 %LIST_SETUP_INCLUDE = (
 set_smtp_sender              => 1, # For SMTP   
 add_sendmail_f_flag          => 1, # For Sendmail Command
 admin_email                  => 'bounces@example.com',
 );

And all new lists would automatically be hooked up to the bounce handler. 

=cut

%LIST_SETUP_DEFAULTS = (%LIST_SETUP_DEFAULTS, %LIST_SETUP_INCLUDE); 

=pod

=head2 %LIST_SETUP_OVERRIDES

B<%LIST_SETUP_OVERRIDES> will override any setting that's in the 
B<%LIST_SETUP_DEFAULTS> hash and whatever is set in the list 
preferences. 

=cut

%LIST_SETUP_OVERRIDES = () 
	unless keys %LIST_SETUP_OVERRIDES;



=pod

=head2 @LIST_SETUP_DONT_CLONE

B<@LIST_SETUP_DONT_CLONE> is a list of settings you'd rather not have allowed to be cloned, 
in the little feature in the, "Create a New List" screen, 
entitled, "Clone settings from this list:"

=cut
	
	
@LIST_SETUP_DONT_CLONE = qw(
	
	list   
	list_name                               
	info                                                    
	list_info                                           
	list_owner_email                   
	privacy_policy                     
	physical_address                   
	password

	disable_discussion_sending
	discussion_pop_server  
	discussion_pop_username
	discussion_pop_email   
	discussion_pop_password
	discussion_pop_auth_mode
	discussion_pop_use_ssl  	
	
	) unless keys %LIST_SETUP_OVERRIDES;



=pod

=head1 Additional Settings You'll Probably Not Need to Change 

(advanced hacker stuff)

=head2 Operating System

Dada Mail tries to guess your Operating System using the $^O variable. 
If it's guessing wrong, you can set it yourself. 

=cut

$OS ||= $^O;


=pod

=head2 $NULL_DEVICE

$NULL_DEVICE refers to where the /dev/null device or file or whatever 
you more smert people call that thing... is located. On most *nix's, 
it's at /dev/null. You may have to change it. For example, if you're 
a Windows folk. 

=cut

$NULL_DEVICE ||= '/dev/null'; 


=pod

=head2 Seed Random Number Generator

if this is taken off, the seed random number will be made from the 
time, or from something pretty random, depending on your version 
of Perl.

=cut

srand ( time() ^ ($$ + ($$ << 15)) );  


=pod

=head2 $FIRST_SUB, $SEC_SUB

Where is the salt number located in the encrypted password? It's 
usually at substr(0,2) but may be different on different systems, 
some systems are set to substring(3,2).
Actually, I've only had this problem on one system - mine :) - 
which was a FreeBsd 4.0 distro. Under most cases, this is NOT going 
to be your problem!

=cut

$FIRST_SUB ||= 0;
$SEC_SUB   ||= 2;


=pod

=head2 $SALT

The salt number. Change $SALT to
 
	 $SALT = "mj";

if all else fails. 

=cut

@C=('a'..'z', 'A'..'Z', '0'..'9','.');
$SALT=$C[rand(@C)].$C[rand(@C)];


=pod

=head2 $PIN_WORD $PIN_NUM 

A pin number is made when someone wants to subscribe to your list. 
They will get a confirmation email with a special link that includes 
their email, and a pin that's generated from the email and the 
variables below using a mathematical equation. It's much harder to 
guess a pin with these two variables changed:

=cut

# Pick a word. It really doesn't matter what the word is - a longer 
# word doesn't necessarily mean a better pin number. 

if(!defined($PIN_WORD)){ 
	$PIN_WORD = ($ROOT_PASS_IS_ENCRYPTED == 1) ? ($PROGRAM_ROOT_PASSWORD) : ('dada');
}	

# Pick a number. I would keep it between 1 and 9. 
$PIN_NUM  ||= unpack("%32C*", $FILES);


=pod

=head2 $TEXT_CSV_PARAMS

Changes how Dada Mail handles parsing CSV files. See: 

L<http://search.cpan.org/~makamaka/Text-CSV/lib/Text/CSV.pm#new_(\%attr)>

=cut

$TEXT_CSV_PARAMS ||= {

	binary              => 1, 
	allow_loose_escapes => 1,
};






=pod

=head2 @AnyDBM_File

Change what DB Dada Mail will use. 
Dada Mail can use various db packages to save each list's information.
It looks for the best one and uses the next package in the list if it 
can't find it. If you get a software error (an error 500, not having 
any information changed when creating a new list) you may have to 
change this to: 

	BEGIN { @AnyDBM_File::ISA = qw(SDBM_File) }

SDBM is the worst package to use, but it is always available with perl.
See the man page for the AnyDBM_File for more information.

=cut

BEGIN { @AnyDBM_File::ISA = qw(DB_File GDBM_File) }

=pod

Check the AnyDBM_File for more info.

=cut


=pod

=head2 $ATTACHMENT_TEMPFILE

To add an attachment to a list message in Dada Mail from the control 
panel, we have to upload it via the web browser. There are two ways 
we can do this. One is to save the information in the $FILES 
directory and then open it up, attach it, and then delete it; and the 
other involves some magical qualities of CGI.pm and MIME::Lite, 
probably coupled with your server's /tmp file, if you can use it. 
Setting $ATTACHMENT_TEMPFILE to '1' uploads, saves, attaches and then 
deletes the file. Setting it to '0' does it magically. I suggest '1', 
unless you want to play around with it. 

=cut

$ATTACHMENT_TEMPFILE ||= 0;

=pod

=head2 $MAIL_VERP_SEPARATOR

See: http://search.cpan.org/~gyepi/Mail-Verp-0.05/Verp.pm

=cut

$MAIL_VERP_SEPARATOR ||= '-'; 

=pod

=head1 Variables That Don't Need Changin'


=head2  $VER

This is the version of this Dada Mail Program. 
Mostly it's used to see if there's a new version out there to use
and to say that you've got the freshest tools on the Web.

=cut




$VERSION = 4.3.1; 
$VER     = '4.3.1 Stable 12/23/10';


#
#
#####################################################################


=pod

=head2 $PROGRAM_NAME

This is the name of the program. I guess if this script has a mid-life 
crisis or something, it can change its name, buy a really fast car 
and start chasing guys half her age. 

=cut

$PROGRAM_NAME ||= "Dada Mail";


=pod

=head2 %EMAIL_HEADERS

C<%EMAIL_HEADERS> hold the default values of all email headers that Dada Mail 
supports. Most of the default values have no default (they're set to, C<undef>)
and in this case, won't be used, unless explicitly set in the program, somewhere. 

You may try changing the default value, (for example, the C<Reply-To> header) 
but these default value will always be overrided by anything explictly set in
in the program. 

=cut

%EMAIL_HEADERS = (

 Date                       =>    undef, 
 From                       =>    undef,
 To                         =>    undef,
 Cc                         =>    undef, 
 Bcc                        =>    undef, 
'Return-Path'               =>    undef, 
'Reply-To'                  =>    undef, 
'In-Reply-To'               =>    undef, 
'Errors-To'                 =>    undef, 
References                  =>    undef,
 'X-Priority'               =>    undef,

'Content-Base'              =>    undef, 
 List                 	    =>    undef, 
'List-Archive'       	    =>    undef, 
'List-Digest'         	    =>    undef, 
'List-Help'          	    =>    undef, 
'List-ID'                   =>    undef, 
'List-Owner'                =>    undef, 
'List-Post'                 =>    undef, 
'List-Subscribe'            =>    undef, 
'List-Unsubscribe'          =>    undef, 
'List-URL'                  =>    undef,  
'X-BeenThere'               =>    undef, 

'Message-ID'                =>    undef, 
 Precedence                 =>    undef,

'X-Mailer'                  =>   "$PROGRAM_NAME $VER ", 
'X-BounceHandler'           =>    undef, 
   
 Sender                     =>    undef, 
'Content-type'              =>    undef, 
'Content-Transfer-Encoding' =>    undef, 
# Content-Length            =>    undef, # See it *should* be here, 
                                  # but it also states it's unofficial


'Content-Disposition'       =>    undef, 
'MIME-Version'              =>    undef, 

 Subject               	    =>   '(no subject)',  
 
 Body                 	    =>   'blank', 

) unless keys %EMAIL_HEADERS; 



=pod

=head2 @EMAIL_HEADERS_ORDER

C<@EMAIL_HEADERS_ORDER> sets the order at which email headers are written in, 
when Dada Mail creates an email message. 

=cut



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

List
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

Message-ID
Precedence

X-Mailer
X-BounceHandler

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
	if(exists($ENV{NO_DADA_MAIL_CONFIG_IMPORT})){ 
			if($ENV{NO_DADA_MAIL_CONFIG_IMPORT} == 1){ 
				return;
			} 
	}
	# Keep this as, 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'
	# What we're doing is, seeing if you've actually changed the variable from
	# it's default, and if not, we take a best guess.	
	
	my $CONFIG_FILE_DIR; 
	
	if(defined($OS) !~ m/^Win|^MSWin/i){ 
		my $getpwuid_call; 
		my $good_getpwuid;
		eval { $getpwuid_call = ( getpwuid $> )[7] };
		       $good_getpwuid = $getpwuid_call if !$@;
	
		if($PROGRAM_CONFIG_FILE_DIR eq 'auto'){ 
			$CONFIG_FILE_DIR = $good_getpwuid . '/.dada_files/.configs';
		}
		else { 
			# ... 
		}
	}
	if($CONFIG_FILE_DIR ne 'auto'){ 
		$CONFIG_FILE_DIR ||= $PROGRAM_CONFIG_FILE_DIR;
	}
	
	$CONFIG_FILE = $CONFIG_FILE_DIR.'/.dada_config';
	
	# yes, shooting yourself in the foot, RTM
	$CONFIG_FILE =~ /(.*)/; 
	$CONFIG_FILE = $1;
	
	if(-e $CONFIG_FILE && -f $CONFIG_FILE && -s $CONFIG_FILE){ 
		open(CONFIG, '<:encoding(UTF-8)',  $CONFIG_FILE) 
			or warn "could not open outside config file, '$CONFIG_FILE' because: $!"; 
		my $conf;
		   $conf = do{ local $/; <CONFIG> }; 

		# shooting again, 
		$conf =~ m/(.*)/ms;
		$conf = $1;	
		eval  $conf;
		if ($@) { 
			die "$PROGRAM_NAME $VER ERROR - Outside config file '$CONFIG_FILE' contains errors:\n\n$@\n\n";
		}	
		if($PROGRAM_CONFIG_FILE_DIR eq 'auto') { 
			if(! defined $PROGRAM_ERROR_LOG){ 
				$PROGRAM_ERROR_LOG = $LOGS . '/errors.txt'; 
				open (STDERR, ">>$PROGRAM_ERROR_LOG")
				|| warn "$PROGRAM_NAME Error: Cannot redirect STDERR, it's possible that Dada Mail does not have write permissions to this file ($PROGRAM_ERROR_LOG) or it doesn't exist! If Dada Mail cannot make this file for you, create it yourself and give it enough permissions so it may write to it: $!";
			}
		}
	}
	
	if($PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'){ 
		require CGI; 
		$PROGRAM_URL = CGI::url(); 
	}
	
	# I really DO NOT think this is the place to massage Config variables if they 
	# aren't set right, but it will save people headaches, in the long run: 
	
	my %default_table_names = (
		subscriber_table                => 'dada_subscribers',
		profile_table                   => 'dada_profiles', 
		profile_fields_table 	        => 'dada_profile_fields', 
		profile_fields_attributes_table => 'dada_profile_fields_attributes',
		archives_table                  => 'dada_archives', 
		settings_table                  => 'dada_settings', 
		session_table                   => 'dada_sessions', 
		bounce_scores_table             => 'dada_bounce_scores', 
		clickthrough_urls_table         => 'dada_clickthrough_urls',
	); 
	foreach(keys %default_table_names){ 
		if(!exists($SQL_PARAMS{$_})){ 
			$SQL_PARAMS{$_} = $default_table_names{$_};
		}
	}
	
}

=pod

=head1 SUPPORT

If you need further support for this script, please do not email 
me directly, but use one of the following channels: 

=over

=item * Dada Mail Support Site

http://dadamailproject.com

=item * The Dada Mailers Discussion List

http://dadamailproject.com/cgi-bin/dada/mail.cgi/dadadev/

=item * Consultation for Dada Mail

http://dadamailproject.com/support/customize.html

=back


=head1 CONTACT

My name is Justin Simoni

=head1 COPYRIGHT 

Copyright (c) 1999-2010 Justin Simoni All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.


=head1 Last Words

To riding bicycles.

=cut



# Don't remove the '1'. It lives here at the bottom. It likes it there.


1;


