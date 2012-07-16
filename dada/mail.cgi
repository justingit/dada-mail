#!/usr/bin/perl
package mail;

use strict;
use 5.008_001;
use Encode qw(encode decode);


# A weird fix.
BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}


#-----------#
# Dada Mail #
#-----------#
#
# Homepage: http://dadamailproject.com
#
# Support: http://dadamailproject.com/support
#
# How To Ask For Free Help:
#    http://dadamailproject.com/support/documentation/getting_help.pod.html
#
#---------------------------------------------------------------------#


 #---------------------------------------------------------------------#
# The Path to your Perl *Libraries*:
# This IS NOT the path to Perl. The path to Perl is the first line of
# this script.
#
#

use lib qw(
	./
	./DADA
	./DADA/perllib
	../../../perl
	../../../perllib
);

# This list may need to be added to. Find the absolute to path to this
# very file. This:
#
#        /home/youraccount/www/cgi-bin/dada/mail.cgi
#
# Is an example of what the absolute path to this file may be.
#
# Get rid of, "/mail.cgi"
#
#        /home/youraccount/www/cgi-bin/dada
#
# Add that line after, "./DADA/perllib" above.
#
# Add "DADA/perllib" from the absolute path you just made right
# after your last entry into the Path to your Perl Libraries:
#
#    /home/youraccount/www/cgi-bin/dada
#    /home/youraccount/www/cgi-bin/dada/DADA/perllib
#
# and you should be good to go.
#
# If this doesn't do the job - make sure ALL the directories, including the
# DADA directory have permissions of: 755 and all files have permissions
# of: 644
#---------------------------------------------------------------------#




#---------------------------------------------------------------------#
#
# If you'd like error messages to be printed out in your browser, set the
# following to 1, like this:

#	use constant ERRORS_TO_BROWSER => 1;

# To always include a stack trace, set it to 2, like this:
#
#	use constant ERRORS_TO_BROWSER => 2;
#

use constant ERRORS_TO_BROWSER => 1;

#
# If you don't want Dada Mail to show any error messages in your web browser, 
# comment remove all the lines (below) between the markers: 

	# Start Web Browser Error Reporting
	
	# End Web Browser Error Reporting





# Start Web Browser Error Reporting
#---------------------------------------------------------------------#

use Carp qw(croak carp);
use CGI::Carp qw(fatalsToBrowser set_message);
    BEGIN {
       $Carp::Verbose = 1 if ERRORS_TO_BROWSER >= 2;
       sub handle_errors {
          my $msg = shift;
          print q{<h1>Program Error (Server Error 500)</h1>
                  <hr />
             <p>
              <em>
              More information about this error may be available in the
              server error log and/or program error log.
              </em>
             </p>
             <hr />
               };
         print "<pre>$msg</pre>" if ERRORS_TO_BROWSER >= 1;
       }
      set_message(\&handle_errors);
    }

#---------------------------------------------------------------------#
# End Web Browser Error Reporting



#---------------------------------------------------------------------#
# No more user-serviceable parts, please see the:
#
# dada/DADA/Config.pm
#
# file and:
#
# for instructions on how to install Dada Mail:
#
#     http://dadamailproject.com/installation/
#-------------------------------------------------------------------#

$|++;


use DADA::Config 5.0.0;

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $dbi_handle;

if($DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ ||
   $DADA::Config::ARCHIVE_DB_TYPE    =~ m/SQL/ ||
   $DADA::Config::SETTINGS_DB_TYPE   =~ m/SQL/
 ){
    require DADA::App::DBIHandle;
    $dbi_handle = DADA::App::DBIHandle->new;
}


use     DADA::App::ScreenCache;
my $c = DADA::App::ScreenCache->new;


use DADA::App::Guts;

use DADA::MailingList::Subscribers;

use CGI;
    CGI->nph(1)
     if $DADA::Config::NPH == 1;


my  $q;

# DEV
# Shouldn't this be:
# if($DADA::Config::PROGRAM_URL =~ m/^\?/){
# Since this'll basically hit everything...?

if($ENV{QUERY_STRING} =~ m/^\?/){

    # DEV Workaround for servers that give a bad PATH_INFO:
    # Set the $DADA::Config::PROGRAM_URL to have, "?" at the end of the URL
    # to change any PATH_INFO's into Query Strings.
    # The below lines will then take this extra question mark
    # out, so actual query strings will work as before.

    $ENV{QUERY_STRING} =~ s/^\?//;

    # DEV: This really really needs to be check to make sure it works
    CGI::upload_hook(\&hook);

    $q = CGI->new($ENV{QUERY_STRING});

} else{

    $q = CGI->new(\&hook);

}

sub hook {
	my ($filename, $buffer, $bytes_read, $data) = @_;

	$bytes_read ||= 0;
    $filename = uriescape($filename);

	open(COUNTER, ">", $DADA::Config::TMP . '/' . $filename . '-meta.txt') ;

	my $per = 0;
	if($ENV{CONTENT_LENGTH} >  0){ # This *should* stop us from dividing by 0, right?
		$per = int(($bytes_read * 100) / $ENV{CONTENT_LENGTH});
	}
	print COUNTER $bytes_read . '-' . $ENV{CONTENT_LENGTH} . '-' . $per;
	close(COUNTER);

}

$q->charset($DADA::Config::HTML_CHARSET);

use DADA::Template::HTML;



# Bad - global variable for the archive editor
# - I'll have to figure this out later.
my $skel = [];



#---------------------------------------------------------------------#
# DEV - This is NOT the best place to put this,
# but I guess we'll leave it here for now...

my %list_types = (
				  list               => 'Subscribers',
                  black_list         => 'Black Listed',
                  white_list         => 'White Listed', # White listed isn't working, no?
                  authorized_senders => 'Authorized Senders',
                  sub_request_list   => 'Subscription Requests',
				  bounced_list       => 'Bouncing Addresses',
				);

my $type = $q->param('type') || undef; 
   my $type_title = "Subscribers";
	if(defined($type)){ 
		$type_title = $list_types{$type};
	}
#---------------------------------------------------------------------#




if($ENV{PATH_INFO}){

    my $dp = $q->url || $DADA::Config::PROGRAM_URL;
       $dp =~ s/^(http:\/\/|https:\/\/)(.*?)\//\//;

    my $info = $ENV{PATH_INFO};

       $info =~ s/^$dp//;
       # script name should be something like:
       # /cgi-bin/dada/mail.cgi
       $info =~ s/^$ENV{SCRIPT_NAME}//i;
       $info =~ s/(^\/|\/$)//g;  #get rid of fore and aft slashes

       # seriously, this shouldn't be needed:
       $info =~ s/^dada\/mail\.cgi//;



       if(!$info && $ENV{QUERY_STRING} && $ENV{QUERY_STRING} =~ m/^\//){

        # DEV Workaround for servers that give a bad PATH_INFO:
        # Set the $DADA::Config::PROGRAM_URL to have, "?" at the end of the URL
        # to change any PATH_INFO's into Query Strings.
        # The below two lines change query strings that look like PATH_INFO's
        # into PATH_INFO's
           $info = $ENV{QUERY_STRING};
           $info =~ s/(^\/|\/$)//g;  #get rid of fore and aft slashes
       }


  	if($info =~ m/subscription_form_js$/){

        my ($pi_flavor, $pi_list) = split('/', $info, 2);

        $q->param('flavor', $pi_flavor)
            if $pi_flavor;

        $q->param('list', $pi_list)
            if $pi_list;

     }elsif($info =~ m/^$DADA::Config::SIGN_IN_FLAVOR_NAME$/){

                my ($sifn, $pi_list) = split('/', $info,2);

        $q->param('f',    $DADA::Config::SIGN_IN_FLAVOR_NAME);
        $q->param('list', $pi_list);

    }elsif($info =~ m/^$DADA::Config::ADMIN_FLAVOR_NAME$/){

        $q->param('f', $DADA::Config::ADMIN_FLAVOR_NAME);

    }elsif($info =~ m/^archive/){

        # archive, archive_rss and archive_atom
        # form:
        #/archive/justin/20050422012839/

        my ($pi_flavor, $pi_list, $pi_id, $extran) = split('/', $info);

        $q->param('flavor', $pi_flavor)
            if $pi_flavor;
        $q->param('list', $pi_list)
            if $pi_list;
        $q->param('id', $pi_id)
            if $pi_id;
        $q->param('extran', $extran);

    }elsif($info =~ /^smtm/){

        $q->param('what_is_dada_mail');

    }elsif($info =~ /^spacer_image/){

        my ($throwaway, $pi_list, $pi_mid, $bollocks) = split('/', $info);

        $q->param('flavor', 'm_o_c');

        $q->param('list',   $pi_list)
            if $pi_list;

        $q->param('mid',    $pi_mid)
            if $pi_mid;

}elsif($info =~ /^img/){

        my ($pi_flavor, $img_name, $extran) = split('/', $info);

        $q->param('flavor', 'img');

        $q->param('img_name',    $img_name)
            if $img_name;


}elsif($info =~ /^js/){

        my ($pi_flavor, $js_lib, $extran) = split('/', $info);

        $q->param('flavor', 'js');

        $q->param('js_lib',    $js_lib)
            if $js_lib;

}elsif($info =~ /^css/){

        my ($pi_flavor, $css_file, $extran) = split('/', $info);

        $q->param('flavor', 'css');
		
		if($css_file){ 
        	$q->param('css_file',    $css_file)
		}
		else { 
			# this is backwards compat. 
			$q->param('css_file', 'default.css'); 
		}

   }elsif($info =~ /^captcha_img/){

        my ($pi_flavor, $pi_img_string, $extran) = split('/', $info);

        $q->param('flavor', 'captcha_img');

        $q->param('img_string',   $pi_img_string)
            if $pi_img_string;

    }elsif($info =~ /^(s|n|u|ur)/){

        my ($pi_flavor, $pi_list, $pi_email, $pi_domain, $pi_pin) = split('/', $info, 5);

        # HACK: If there is no name and a domain, the entire email address is in "email"
        # and there is no domain.
        # move all the other variables to the right
        # This being only the pin, at the moment
        # 2.10 should have relieved this issue...

        if($pi_email !~ m/\@/){
            $pi_email = $pi_email . '@' . $pi_domain
                if $pi_domain;
        }else{
            $pi_pin = $pi_domain
                if !$pi_pin;
        }

		# For whatever reason (bug somewhere?!) the 
		# last character of an unsubscription link - say on the last line of an 
		# email message, contains a, "=". No fun! 
		# If that's so, it's not a valid pin and we should ignore.
		#
		
		if($pi_pin eq '='){ 
			undef $pi_pin;
		}
		
        $q->param('flavor', $pi_flavor)
            if $pi_flavor;
        $q->param('list',   $pi_list)
            if $pi_list;
        $q->param('email',  $pi_email)
            if $pi_email;
        $q->param('pin',    $pi_pin)
            if $pi_pin;

    }elsif($info =~ /^subscriber_help|^list/){

        my ($pi_flavor, $pi_list) = split('/', $info);

        $q->param('flavor', $pi_flavor)
            if $pi_flavor;
        $q->param('list',   $pi_list)
            if $pi_list;

    }elsif($info =~ /^r/){
       # my ($pi_flavor, $pi_list, $pi_k, $pi_mid, @pi_url) = split('/', $info);
         my ($pi_flavor, $pi_list, $pi_key) = split('/', $info);
        my $pi_url;

        $q->param('flavor', $pi_flavor)
            if $pi_flavor;

        $q->param('list',   $pi_list)
            if $pi_list;

	       $q->param('key',   $pi_key)
	            if $pi_key;
    }elsif($info =~ /^what_is_dada_mail$/){

        $q->param('flavor', 'what_is_dada_mail');
   }
 	elsif($info =~ m/^profile/) {
		# profile_login
		# profile_help

		# email is used just to pre-fill in the login form.

	    my ($pi_flavor, $pi_user, $pi_domain, $pi_auth_code) = split('/', $info, 4);
	 	$q->param('flavor', $pi_flavor)
            if $pi_flavor;
		$q->param('email', $pi_user . '@' . $pi_domain)
            if $pi_user && $pi_domain;
		$q->param('auth_code', $pi_auth_code)
            if $pi_auth_code;
    }
	else{
        if($info){
            warn "Path Info present - but not valid? - '" . $ENV{PATH_INFO} . '" - filtered: "' . $info . '"'                    unless $info =~ m/^\x61\x72\x74/;
        }
    }
}
$q = decode_cgi_obj($q);



#---------------------------------------------------------------------#

# I don't like this at all:
my $flavor = undef;
if($q->param('flavor')){
	$flavor = $q->param('flavor');
}
elsif($q->param('f')){
	$flavor = $q->param('f');
	$q->param('flavor', $q->param('f'));
}
my $email = undef;

if($q->param('email')){
	$email = $q->param('email');
}
elsif($q->param('e')){
	$email = $q->param('e');
	$q->param('email', $q->param('e'));
}

my $list = undef;
if($q->param('list')){
	$list = $q->param('list');
}
elsif($q->param('l')){
	$list = $q->param('l');
	$q->param('list',  $q->param('l'));
}

my $pin = undef;
if($q->param('pin')){
	$pin = $q->param('pin');
}
elsif($q->param('p')){
	$pin = $q->param('p');
	$q->param('pin', $q->param('p'));
}

my $process          = $q->param('process');
my $list_name        = $q->param('list_name');
my $admin_email      = $q->param('admin_email');
my $list_owner_email = $q->param('list_owner_email');
my $info             = $q->param('info');
my $privacy_policy   = $q->param('privacy_policy');
my $physical_address = $q->param('physical_address');
my $password         = $q->param('password');
my $retype_password  = $q->param('retype_password');
my $keyword          = $q->param('keyword');
my @address          = $q->param('address');
my $done             = $q->param('done');
my $id               = $q->param('id');
my $advanced         = $q->param('advanced') || 'no';
my $help             = $q->param('help');
my $set_flavor       = $q->param('set_flavor');


#---------------------------------------------------------------------#


if($email){
    $email =~ s/_p40p_/\@/;
    $email =~ s/_p2Bp_/\+/g;
}

$list        = xss_filter($list);
$flavor      = xss_filter($flavor);
$email       = xss_filter($email);
$pin         = xss_filter($pin);
$keyword     = xss_filter($keyword);
$set_flavor  = xss_filter($set_flavor);
$id          = xss_filter($id);

if($q->param('auth_state')){
    $q->param('auth_state', xss_filter($q->param('auth_state')));
}


__PACKAGE__->run()
	unless caller();

sub run {

	#external (mostly..) functions called from the web browser)
	# a few things this program  can do.... :)
	my %Mode = (
	'default'                    =>    \&default,
	'subscribe'                  =>    \&subscribe,
	'subscribe_flash_xml'        =>    \&subscribe_flash_xml,
	'unsubscribe_flash_xml'      =>    \&unsubscribe_flash_xml,
	'new'                        =>    \&confirm,
	'unsubscribe'                =>    \&unsubscribe,
	'login'                      =>    \&login,
	'logout'                     =>    \&logout,
	'log_into_another_list'      =>    \&log_into_another_list,
	'change_login'               =>    \&change_login,
	'new_list'                   =>    \&new_list,
	'change_info'                =>    \&change_info,
	'html_code'                  =>    \&html_code,
	'admin_help'                 =>    \&admin_help,
	'delete_list'                =>    \&delete_list,
	'view_list'                  =>    \&view_list,
	'list_activity'              =>    \&list_activity,
	'view_bounce_history'        =>    \&view_bounce_history, 
	'subscription_requests'      =>    \&subscription_requests,
	'remove_all_subscribers'     =>    \&remove_all_subscribers,
	'view_list_options'          =>    \&list_cp_options,
	'membership'                 =>    \&membership,
	'admin_change_profile_password' => \&admin_change_profile_password, 
	'update_email_results'       =>    \&update_email_results, 
	'admin_update_email'         =>    \&admin_update_email, 
	'mailing_list_history'       =>    \&mailing_list_history, 
	'add'                        =>    \&add,
	'check_status'               =>    \&check_status,
	'email_password'             =>    \&email_password,
	'add_email'                  =>    \&add_email,
	'delete_email'               =>    \&delete_email,
	'subscription_options'       =>    \&subscription_options,
	'send_email'                 =>    \&send_email,
	'previewMessageReceivers'    =>    \&previewMessageReceivers,
	'sending_monitor'            =>    \&sending_monitor,
	'print_mass_mailing_log'     =>    \&print_mass_mailing_log,
	'preview_form'               =>    \&preview_form,
	'remove_subscribers'         =>    \&remove_subscribers,
	'process_bouncing_addresses' =>    \&process_bouncing_addresses, 
	'edit_template'              =>    \&edit_template,
	'view_archive'               =>    \&view_archive,
	'display_message_source'     =>    \&display_message_source,
	'purge_all_archives'         =>    \&purge_all_archives,
	'delete_archive'             =>    \&delete_archive,
	'edit_archived_msg'          =>    \&edit_archived_msg,
	'archive'                    =>    \&archive,
	'archive_bare'               =>    \&archive_bare,
	'archive_rss'                =>    \&archive_rss,
	'archive_atom'               =>    \&archive_atom,
	'manage_script'              =>    \&manage_script,
	'change_password'            =>    \&change_password,
	'text_list'                  =>    \&text_list,
	'archive_options'            =>    \&archive_options,
	'adv_archive_options'        =>    \&adv_archive_options,
	'back_link'                  =>    \&back_link,
	'edit_type'                  =>    \&edit_type,
	'edit_html_type'             =>    \&edit_html_type,
	'list_options'               =>    \&list_options,
	'sending_preferences'        =>    \&sending_preferences,
	'amazon_ses_verify_email'    =>    \&amazon_ses_verify_email, 
	'amazon_ses_get_stats'       =>    \&amazon_ses_get_stats,
	'mass_mailing_preferences'   =>    \&mass_mailing_preferences,
	'previewBatchSendingSpeed'   =>    \&previewBatchSendingSpeed,
	'adv_sending_preferences'    =>    \&adv_sending_preferences,
	'sending_tuning_options'     =>    \&sending_tuning_options,
	'filter_using_black_list'    =>    \&filter_using_black_list,
	'search_archive'             =>    \&search_archive,
	'send_archive'               =>    \&send_archive,
	'list_invite'                =>    \&list_invite,
	'pass_gen'                   =>    \&pass_gen,
	'send_url_email'             =>    \&send_url_email,
	'feature_set'                =>    \&feature_set,
	'list_cp_options'            =>    \&list_cp_options,
	'profile_fields'             =>    \&profile_fields,
	'sending_preferences_test'   =>    \&sending_preferences_test,
	'author'                     =>    \&author,
	'list'                       =>    \&list_page,
	'setup_info'                 =>    \&setup_info,
	'reset_cipher_keys'          =>    \&reset_cipher_keys,
	'restore_lists'              =>    \&restore_lists,
	'r'                          =>    \&redirection,
	'subscriber_help'            =>    \&subscriber_help,
	'show_img'                   =>    \&show_img,
	'file_attachment'            =>    \&file_attachment,
	'm_o_c'                      =>    \&m_o_c,
	'img'                        =>    \&img,
	'js'                         =>    \&js,
	'css'                        =>    \&css, 
	'captcha_img'                =>    \&captcha_img,
	'ver'                        =>    \&ver,
	'resend_conf'                =>    \&resend_conf,



	'subscription_form_html'     =>    \&subscription_form_html,
	'subscription_form_js'       =>    \&subscription_form_js,


	'what_is_dada_mail'          =>    \&what_is_dada_mail,
	'profile_activate'           =>    \&profile_activate,
	'profile_register'           =>    \&profile_register,
	'profile_reset_password'     =>    \&profile_reset_password,
	'profile_update_email'       =>    \&profile_update_email,
	'profile_login'              =>    \&profile_login,
	'profile_logout'             =>    \&profile_logout,
	'profile_help'               =>    \&profile_help,
	'profile'                    =>    \&profile,



	# these params are the same as above, but are smaller in actual size
	# this comes into play when you have to create a url using these as parts of it.

	's'                         =>    \&subscribe,
	'n'                         =>    \&confirm,
	'u'                         =>    \&unsubscribe,
	'ur'                        =>    \&unsubscribe_request, 
	'smtm'                      =>    \&what_is_dada_mail,
	'test_layout'               =>    \&test_layout,
	'send_email_testsuite'      =>    \&send_email_testsuite,


	$DADA::Config::ADMIN_FLAVOR_NAME        =>    \&admin,
	$DADA::Config::SIGN_IN_FLAVOR_NAME      =>    \&sign_in,
	);

	# the BIG switcheroo. Mark doesn't like this :)
	if($flavor){
	    if(exists($Mode{$flavor})) {
	        $Mode{$flavor}->();  #call the correct subroutine
	    }else{
	        &default;
	    }
	}else{
	    &default;
	}
}


sub default {

    if ( DADA::App::Guts::check_setup() == 0 ) {
        user_error( -Error => 'bad_setup' );
        return;
    }

	if(DADA::App::Guts::install_dir_around() == 1){
		user_error( -Error => 'install_dir_still_around' );
	    return;
	}

    if (   $DADA::Config::ARCHIVE_DB_TYPE eq 'Db'
        || $DADA::Config::SETTINGS_DB_TYPE eq 'Db' )
    {
        eval { require AnyDBM_File; };
        if ($@) {
            user_error(
                -Error         => 'no_dbm_package_installed',
                -Error_Message => $@
            );
            return;
        }

        my @l_check = available_lists();
        if ( $l_check[0] ) {

			require DADA::MailingList::Settings;
            my $ls =
              DADA::MailingList::Settings->new( { -list => $l_check[0] } );
            eval { $ls->_open_db; };
            if ($@) {
                user_error(
                    -Error         => 'unreadable_db_files',
                    -Error_Message => $@,
                );
                return;
            }
        }

    }

    elsif ($DADA::Config::SUBSCRIBER_DB_TYPE =~ /SQL/
        || $DADA::Config::ARCHIVE_DB_TYPE  =~ /SQL/
        || $DADA::Config::SETTINGS_DB_TYPE =~ /SQL/ )
    {

        eval { $dbi_handle->dbh_obj; };
        if ($@) {
            user_error(
                -Error         => 'sql_connect_error',
                -Error_Message => $@
            );
            return;
        }
        else {
            if ( DADA::App::Guts::SQL_check_setup() == 0 ) {
                user_error( -Error => 'bad_SQL_setup' );
                return;
            }
        }
    }

    require DADA::MailingList::Settings;

    my @available_lists;
    if (   $DADA::Config::SUBSCRIBER_DB_TYPE =~ /SQL/
        || $DADA::Config::ARCHIVE_DB_TYPE  =~ /SQL/
        || $DADA::Config::SETTINGS_DB_TYPE =~ /SQL/ )
    {

        eval {
            @available_lists =
              available_lists(
				-In_Order   => 1,
			);
        };
        if ($@) {

            user_error(
                -Error         => 'sql_connect_error',
                -Error_Message => $@
            );

            return;
        }
    }
    else {
        @available_lists = available_lists(
            -In_Order   => 1,
        );
    }

    if (   ( $DADA::Config::DEFAULT_SCREEN ne '' )
        && ( $flavor ne 'default' )
        && ( $#available_lists >= 0 ) )
    {
        print $q->redirect( -uri => $DADA::Config::DEFAULT_SCREEN );
        return;    # could we just say, return; ?
    }

    if ( $available_lists[0] ) {
        if ( $q->param('error_invalid_list') != 1 ) {
            if (!$c->profile_on && $c->cached('default.scrn') ) { $c->show('default.scrn'); return; }
        }

		my $scrn = '';

        require DADA::Template::Widgets;
        $scrn .= DADA::Template::Widgets::default_screen(
           # {
                -email              => $email,
                -list               => $list,
                -set_flavor         => $set_flavor,
                -error_invalid_list => $q->param('error_invalid_list'),
           # }
        );
        e_print($scrn);
        if (!$c->profile_on && $available_lists[0] && $q->param('error_invalid_list') != 1 ) {
            $c->cache( 'default.scrn', \$scrn );
        }

        return;

    }
    else {

        my $auth_state;
        if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
            require DADA::Security::SimpleAuthStringState;
            my $sast = DADA::Security::SimpleAuthStringState->new;
            $auth_state = $sast->make_state;
        }

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'congrats_screen.tmpl',
				-with   => 'list', 
                -vars   => {
                    havent_agreed =>
                      ( ( xss_filter( $q->param('agree') ) eq 'no' ) ? 1 : 0 ),
                    auth_state => $auth_state,
                },
            }
        );
		e_print($scrn);
    }
}




sub list_page {

    if ( DADA::App::Guts::check_setup() == 0 ) {
        user_error( -Error => 'bad_setup' );
        return;
    }

    if ( check_if_list_exists( -List => $list ) ==
        0 )
    {
        undef($list);
        &default;
        return;
    }

    require DADA::MailingList::Settings;

    if ( !$email && !$set_flavor && ( $q->param('error_no_email') != 1 ) ) {
        if (!$c->profile_on && $c->cached( 'list/' . $list . '.scrn' ) ) {
            $c->show( 'list/' . $list  . '.scrn');
            return;
        }
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $list_info = $ls->get;

    require DADA::Template::Widgets;

    my $scrn = DADA::Template::Widgets::list_page(
        -list           => $list,
        -cgi_obj        => $q,
        -email          => $email,
        -set_flavor     => $set_flavor,
        -error_no_email => $q->param('error_no_email') || 0,

    );
    e_print($scrn);

    if (!$c->profile_on && !$email && !$set_flavor && ( $q->param('error_no_email') != 1 ) ) {
        $c->cache( 'list/' . $list . '.scrn', \$scrn );
    }

    return;

}




sub admin {

    my @available_lists = available_lists();
    if ( ( $#available_lists < 0 ) ) {
        &default;
        return;
    }

    if ( DADA::App::Guts::install_dir_around() == 1 ) {
        user_error( -Error => 'install_dir_still_around' );
        return;
    }

    my $login_widget = $q->param('login_widget') || $DADA::Config::LOGIN_WIDGET;
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::admin(
        -login_widget => $login_widget,
        -cgi_obj      => $q
    );
    e_print($scrn);

    return;
}




sub sign_in {

    if ( DADA::App::Guts::install_dir_around() == 1 ) {
        user_error( -Error => 'install_dir_still_around' );
        return;
    }

    require DADA::Template::Widgets;

    my $list_exists = check_if_list_exists( -List => $list, );

    if ( $list_exists >= 1 ) {
	
        my $auth_state;
        if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
            require DADA::Security::SimpleAuthStringState;
            my $sast = DADA::Security::SimpleAuthStringState->new;
            $auth_state = $sast->make_state;
        }

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $li = $ls->get;

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'list_login_form.tmpl',
                -with   => 'list',
                -vars   => {
                    flavor_sign_in => 1,
                    auth_state     => $auth_state,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        e_print($scrn);

    }
    else {

        my $login_widget = $q->param('login_widget')
          || $DADA::Config::LOGIN_WIDGET;
        my $scrn = DADA::Template::Widgets::admin(
            -login_widget            => $login_widget,
            -no_show_create_new_list => 1,
            -cgi_obj                 => $q,
        );
        e_print($scrn);

    }

}


sub send_email {

	my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'send_email'
									);
	require DADA::App::MassSend;
	my $ms = DADA::App::MassSend->new;
	   $ms->send_email(
			{
				-cgi_obj     => $q,
				-list        => $admin_list,
				-root_login  => $root_login,
			}
		);
}

sub previewMessageReceivers {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                -Function => 'send_email');

	# This comes in a s a string, sep. by commas. Sigh.
	my $al = $q->param('alternative_lists') || '';
	my @alternative_list         = split(',', $al);


	my $multi_list_send_no_dupes = $q->param('multi_list_send_no_dupes') || 0;

    require DADA::MailingList::Settings;

    $list = $admin_list;

    print $q->header();

    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    my $fields = [];
    # Extra, special one...
    push(@$fields, {name => 'subscriber.email'});
    for my $field(@{$lh->subscriber_fields({-dotted => 1})}){
        push(@$fields, {name => $field});
    }
 	my $undotted_fields = [];
   # Extra, special one...
   push(@$undotted_fields, {name => 'email', label => 'Email Address'});
   for my $undotted_field(@{$lh->subscriber_fields({-dotted => 0})}){
        push(@$undotted_fields, {name => $undotted_field});
    }
    my $partial_sending = {};
    for my $field(@$undotted_fields){
		if($q->param('field_comparison_type_' . $field->{name}) eq 'equal_to'){
		    $partial_sending->{$field->{name}} = {equal_to => $q->param('field_value_' . $field->{name})};
		}
		elsif($q->param('field_comparison_type_' . $field->{name}) eq 'like'){
			$partial_sending->{$field->{name}} = {like => $q->param('field_value_' . $field->{name})};
		}
    }

    if(keys %$partial_sending) {
		if($DADA::Config::MULTIPLE_LIST_SENDING_TYPE eq 'merged'){
     		$lh->fancy_print_out_list(
				{
					-partial_listing   => $partial_sending,
					-type              => 'list',
					-include_from      => [@alternative_list],
				}
			);
		}
		else {
			e_print('<h1>' . $list . '</h1>');

	 		$lh->fancy_print_out_list(
			{
				-partial_listing   => $partial_sending,
				-type              => 'list',
			}
			);

			my @exclude_from = ();

			if($multi_list_send_no_dupes == 1){
				 @exclude_from = ($list);
			}
			if($alternative_list[0]){
				for my $alt_list(@alternative_list){
					e_print('<h1>' . $alt_list . '</h1>');
					my $alt_mls = DADA::MailingList::Subscribers->new({-list => $alt_list});
					 $alt_mls->fancy_print_out_list(
						{
							-partial_listing   => $partial_sending,
							-type              => 'list',
							-exclude_from      => [@exclude_from],
						}
					);
					if($multi_list_send_no_dupes == 1){
						push(@exclude_from, $alt_list);
					}
				}
			}
	   }
    } else {
        e_print($q->p($q->em('Currently, all ' . $q->strong( $lh->num_subscribers ) . ' subscribers of, ' . $list .' will receive this message.')));
    }


}

sub sending_monitor_index { 

	my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'sending_monitor'
									);
									
    my $mailout_status = [];
	my @lists;

	# If we're logged in as dada root, we see all the mass mailings going on. 
	if($root_login == 1){
		@lists = available_lists();
	}
	else {
		# If not, only the current list. 
		@lists = ($list);
	}

	for my $l_list(@lists){
     	my @mailouts  = DADA::Mail::MailOut::current_mailouts(
						{
							-list     => $l_list,
							-order_by => 'creation',
						}
					);
		for my $mo(@mailouts){

			my $mailout = DADA::Mail::MailOut->new({ -list => $l_list });
               $mailout->associate(
					$mo->{id},
					$mo->{type}
				);
            my $status  = $mailout->status();
			require DADA::MailingList::Settings;
			my $l_ls = DADA::MailingList::Settings->new({-list => $l_list});
            push(@$mailout_status,
				{
					%$status,
					list                         => $l_list,
					current_list                 => (($list eq $l_list) ? 1 : 0),
					S_PROGRAM_URL                => $DADA::Config::S_PROGRAM_URL,
					Subject                      => safely_decode($status->{email_fields}->{Subject}, 1),
					status_bar_width             => int($status->{percent_done}) * 1,
					negative_status_bar_width    => 100 - (int($status->{percent_done}) * 1),
					message_id                   => $mo->{id},
					message_type                 => $mo->{type},
					mailing_started              => scalar(localtime($status->{first_access})),
					mailout_stale                => $status->{mailout_stale},
					%{$l_ls->params},
            	}
        	);
		}
	}

	my (
		$monitor_mailout_report,
		$total_mailouts,
		$active_mailouts,
		$paused_mailouts,
		$queued_mailouts,
		$inactive_mailouts
	) = DADA::Mail::MailOut::monitor_mailout(
		{
			-verbose => 0,
			($root_login == 1) ? () : (-list => $list)
		}
	);

	require DADA::Template::Widgets;

	my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'sending_monitor_index_screen.tmpl',
                -with   => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					screen                       => 'sending_monitor',
					killed_it                    => $q->param('killed_it') ? 1 : 0,
					mailout_status               => $mailout_status,
					monitor_mailout_report       => $monitor_mailout_report,
				},
				-list_settings_vars_param => {
					-list    => $list,
					-dot_it => 1,
				},
			}
		);
	e_print($scrn);
			
	
}




sub sending_monitor {

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'sending_monitor'
									);

    require DADA::MailingList::Settings;
	require DADA::Mail::MailOut;

    $list = $admin_list;

	my $mo = DADA::Mail::MailOut->new({-list => $list});
	my ($batching_enabled, $batch_size, $batch_wait) = $mo->batch_params;
	
    my $ls = DADA::MailingList::Settings->new({-list => $list});

    # munging the message id.
    # kinda dumb, but it's sort of up in the air,
    # on how the message id comes to us,
    # so we have to be *real* careful to get it to a state
    # that we *need* it in.

    my $id = DADA::App::Guts::strip($q->param('id'));
       $id =~ s/\@/_at_/g;
	   $id =~ s/\>|\<//g;

	if(!$q->param('id')){
		sending_monitor_index(); 
		return; 
    }

    # 10 is the factory default setting to wait per batch.
    # Let's not refresh an faster, or we'll never have time
    # to read the actual screen.

     my $refresh_after = 10;
     if($refresh_after < $batch_wait){
			$refresh_after = $batch_wait;
		}

	# Type ala, list, invitation list, etc
	my $type = $q->param('type');
	   $type = xss_filter(DADA::App::Guts::strip($type));

    my $restart_count = $q->param('restart_count') || 0;

	require  DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
				{
					-list   => $list,
					-ls_obj => $ls,
				}
			 );

    my $auto_pickup = 0;

    # Kill - the, [Stop] button was pressed. Pressed really hard.

    if ($q->param('process') eq 'kill'){

        if(DADA::Mail::MailOut::mailout_exists($list, $id, $type) == 1){

            my $mailout = DADA::Mail::MailOut->new({ -list => $list });
               $mailout->associate($id, $type);
               $mailout->clean_up;

            print $q->redirect(
						-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&killed_it=1'
					);
			return;

        } else {
            die "mailout does NOT exists! What's going on?!";
        }

    }elsif ($q->param('process') eq 'pause'){
	
        if(DADA::Mail::MailOut::mailout_exists($list, $id, $type) == 1){

            my $mailout = DADA::Mail::MailOut->new({ -list => $list });
               $mailout->associate($id, $type);
               $mailout->pause();

            print $q->redirect(
					-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&id=' . $id . '&type=' . $type . '&paused_it=1'
				);
				
        }
        else {

            die "mailout does NOT exists! What's going on?!";

        }

    }
    elsif ($q->param('process') eq 'resume'){
 
       if(DADA::Mail::MailOut::mailout_exists($list, $id, $type) == 1){

            my $mailout = DADA::Mail::MailOut->new({ -list => $list });
               $mailout->associate($id, $type);
               $mailout->resume();

            print $q->redirect(
				-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&id=' . $id . '&type=' . $type . '&resume_it=1'
			);
        }
        else {

            die "mailout does NOT exists! What's going on?!";

        }

    # Restart is usually called by the program itself, automagically via a redirect if DADA::Mail::MailOut says we should restart.
    }
    elsif ($q->param('process') eq 'restart'){


        print $q->header();
        print "<html>
                <head>

                 <script type=\"text/javascript\">

                 function refreshpage(sec){

                    var refreshafter = sec/1 * 1000;
                    setTimeout(\"self.location.href='$DADA::Config::S_PROGRAM_URL?f=sending_monitor&id=$id&type=$type&restart_count=$restart_count';\",refreshafter);
                }

                </script>


                 </head>
                 <body>
                 ";

        my $restart_time = 1;

        # Let's make sure that restart worked...
        eval { $mh->restart_mass_send($id, $type); };

        # If not...
        if($@){
            print "<h1>Problems Reloading!:</h1><pre>$@</pre>";
            # We're going to refresh, see if it gets better.
            $restart_time = 5;
        }

        # Provide a link in case browser redirect is working
        print '<a href="' . "$DADA::Config::S_PROGRAM_URL?f=sending_monitor&id=$id&type=$type&restart_count=$restart_count" . '">Reloading Mailing...</a>';

        print "

        <script>
        refreshpage($restart_time);
        </script>
        </body>
       </html>";

       return;
    }
	elsif ($q->param('process') eq 'ajax'){


        my $mailout        = undef;
        my $status         = {};
        my $mailout_exists = 0;
        my $mailout_exists = 0;
        my $my_test_mailout_exists = 0;
        eval {
			$my_test_mailout_exists = DADA::Mail::MailOut::mailout_exists($list, $id, $type);
		};
		
        if(!$@){
            $mailout_exists = $my_test_mailout_exists;
        }

        if($mailout_exists){

            $mailout_exists = 1;
            $mailout        = DADA::Mail::MailOut->new({ -list => $list });
            $mailout->associate($id, $type);
            $status         = $mailout->status();

        }else {
	
            # Nothing - I believe this is handled in the template.

        }

		my (
			$monitor_mailout_report,
			$total_mailouts,
			$active_mailouts,
			$paused_mailouts,
			$queued_mailouts,
			$inactive_mailouts
		) = DADA::Mail::MailOut::monitor_mailout(
			{
				-verbose => 0,
				-list    => $list
			}
		);

			
		if(
		$status->{should_be_restarted}								   == 1 && # It's dead in the water.
		$ls->param('auto_pickup_dropped_mailings')                            == 1 && # Auto Pickup is turned on...
		# $status->{total_sending_out_num} - $status->{total_sent_out} >  0 && # There's more subscribers to send out to
		$restart_count                                                 <= 0 && # We haven't *just* restarted this thing
		$status->{mailout_stale}                                       != 1 && # The mailout hasn't been sitting around too long without being restarted,
		$active_mailouts                                                < $DADA::Config::MAILOUT_AT_ONCE_LIMIT # There's not already too many mailouts going out.
		){

			# Whew! Take that for making sure that the damn thing is supposed to be sent.
		
			my $reload_url = $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&id=' . $id . '&process=restart&type=' . $type . '&restart_count=1'; 

			print $q->header(); 
			print "<script> 
			window.location.replace('$reload_url'); 
			</script>";
			return;
		} else {
			$restart_count = 0;
		}


		my $sending_status = [];
		for(keys %$status){
			next if $_ eq 'email_fields';
			push(@$sending_status, {key => $_, value => $status->{$_}});
        }

		# If we're... say... 2x a batch setting and NOTHING has been sent,
		# let's say a mailing will be automatically started in... time since last - wait time.

		my $will_restart_in = undef;
		if(time - $status->{last_access} > ($batch_wait * 1.5)){
			my $tardy_threshold = $batch_wait * 3;
			if($tardy_threshold < 60){
				$tardy_threshold = 60;
			}
			
			$will_restart_in = $tardy_threshold - (time - $status->{last_access});
			if($will_restart_in >= 1){
				$will_restart_in =   _formatted_runtime($will_restart_in);
			}
			else {
				$will_restart_in = undef;
			}
		}

 		my $hourly_rate = 0;
		if($status->{mailing_time} > 0){
			$hourly_rate = commify(int(($status->{total_sent_out} / $status->{mailing_time}) * 60 * 60 + .5));
		}
		require DADA::Template::Widgets;
		my $header_subject_label = DADA::Template::Widgets::screen(
			{
				-data                     => \$status->{email_fields}->{Subject},
				-list_settings_vars_param => {
					-list   => $list,
					-dot_it => 1,
				},
				-subscriber_vars_param => {
				-use_fallback_vars => 1,
				-list              => $list,
			},
			-decode_before => 1,
			}
		);
		
		my $scrn = DADA::Template::Widgets::screen(
				{
					-screen => 'sending_monitor_screen.tmpl',
	                         -vars   => {
						screen                       => 'sending_monitor',
						mailout_exists               => $mailout_exists,
						message_id                   => DADA::App::Guts::strip($id),
						message_type                 => $q->param('type'),
						total_sent_out               => $status->{total_sent_out},
						total_sending_out_num        => $status->{total_sending_out_num},
						mailing_time                 => $status->{mailing_time},
						mailing_time_formatted       => $status->{mailing_time_formatted},
						hourly_rate                  => $hourly_rate,
						percent_done                 => $status->{percent_done},
						status_bar_width             => int($status->{percent_done}) * 5,
						negative_status_bar_width    => 500 - (int($status->{percent_done}) * 5),
						need_to_send_out             => ( $status->{total_sending_out_num} - $status->{total_sent_out}),
						time_since_last_sendout      => _formatted_runtime((time - int($status->{last_access}))),
						its_killed                   => $status->{should_be_restarted},
						header_subject               => safely_decode($status->{email_fields}->{Subject},1 ),
						header_subject_label         => (length($header_subject_label) > 50) ? (substr($header_subject_label, 0, 49) . '...') : ($header_subject_label),
						auto_pickup_dropped_mailings => $ls->param('auto_pickup_dropped_mailings'),
						sending_done                 => ($status->{percent_done} < 100) ? 0 : 1,
						refresh_after                => $refresh_after,
						killed_it                    => $q->param('killed_it') ? 1 : 0,
						sending_status               => $sending_status,
						is_paused                    => $status->{paused} > 0 ? 1 : 0,
						paused                       => $status->{paused},
						queue                        => $status->{queue},
						queued_mailout               => $status->{queued_mailout},
						queue_place                  => ($status->{queue_place} + 1), # adding one since humans like counting from, "1"
						queue_total                  => ($status->{queue_total} + 1), # adding one since humans like counting from, "1"
						status_mailout_stale         => $status->{mailout_stale},
						MAILOUT_AT_ONCE_LIMIT        => $DADA::Config::MAILOUT_AT_ONCE_LIMIT,
						will_restart_in              => $will_restart_in,
						integrity_check              => $status->{integrity_check},
					},
				}
			);
		print $q->header();
		e_print($scrn);
    }
	else { 
		
		my $tracker_url = $DADA::Config::S_PROGRAM_URL; 
		   $tracker_url =~ m/(^.*\/)(.*?)/; #just use the url to get the filename with a regex 
		   $tracker_url = $1 . 'plugins/tracker.cgi'; 
	
		require DADA::Template::Widgets; 
		my $scrn = DADA::Template::Widgets::wrap_screen(
			{ 
				-screen => 'sending_monitor_container_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars => { 
					screen                       => 'sending_monitor',
					message_id                   => DADA::App::Guts::strip($id),
					message_type                 => $q->param('type'),
					refresh_after                => $refresh_after,
					tracker_url                  => $tracker_url, 
					'list_settings.tracker_show_message_reports_in_mailing_monitor' 
						=> $ls->param('tracker_show_message_reports_in_mailing_monitor'),
					list_type_isa_list           => ($q->param('type') eq 'list')       ? 1 : 0,
				}
			}
		); 
		e_print($scrn); 
		
	}
}




sub print_mass_mailing_log {

	my ($admin_list, $root_login) = check_list_security(
		-cgi_obj  => $q,
        -Function => 'sending_monitor'
	);

	my $id   = $q->param('id');
	my $type = $q->param('type');

	$list = $admin_list;

	require DADA::Mail::MailOut;
	my $mailout = DADA::Mail::MailOut->new({ -list => $list });
	   $mailout->associate($id, $type);
	   print $q->header('text/plain');
	   $mailout->print_log;
}


sub _formatted_runtime {

	my $d    = shift || 0;

	my @int = (
        [ 'second', 1                ],
        [ 'minute', 60               ],
        [ 'hour',   60*60            ],
        [ 'day',    60*60*24         ],
        [ 'week',   60*60*24*7       ],
        [ 'month',  60*60*24*30.5    ],
        [ 'year',   60*60*24*30.5*12 ]
    );
    my $i = $#int;
    my @r;
    while ( ($i>=0) && ($d) )
    {
        if ($d / $int[$i] -> [1] >= 1)
        {
            push @r, sprintf "%d %s%s",
                         $d / $int[$i] -> [1],
                         $int[$i]->[0],
                         ( sprintf "%d", $d / $int[$i] -> [1] ) > 1
                             ? 's'
                             : '';
        }
        $d %= $int[$i] -> [1];
        $i--;
    }

    my $runtime;
    if (@r) {
        $runtime = join ", ", @r;
    } else {
        $runtime = '0 seconds';
    }

    return $runtime;
}




sub send_url_email {

	require DADA::App::MassSend;
	my $ms = DADA::App::MassSend->new;
	   $ms->send_url_email(
			{
				-cgi_obj     => $q,
			}
		);
}




sub list_invite {

	require DADA::App::MassSend;
	my $ms = DADA::App::MassSend->new;
	   $ms->list_invite(
			{
				-cgi_obj     => $q,
			}
		);
}




sub change_info {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'change_info');

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;


    my $errors = 0;
    my $flags  = {};

    if($process){

        ($errors, $flags) = check_list_setup(-fields => { list             => $list,
                                                          list_name         => $list_name,
                                                          list_owner_email  => $list_owner_email,
                                                          admin_email       => $admin_email,
                                                          privacy_policy    => $privacy_policy,
                                                          info                => $info,
                                                          physical_address  => $physical_address,
                                                          },
                                                -new_list         => 'no',
                                              );
    }

    undef $process
        if $errors >= 1;

    if(!$process){

        my $err_word      = 'was';
           $err_word      = 'were'
            if $errors && $errors > 1;

        my $errors_ending = '';
           $errors_ending = 's'
            if $errors && $errors > 1;

        my $flags_list_name                = $flags->{list_name}                  || 0;

        my $flags_list_name_bad_characters = $flags->{list_name_bad_characters}                  || 0;

        my $flags_invalid_list_owner_email = $flags->{invalid_list_owner_email}   || 0;
        my $flags_list_info                = $flags->{list_info}                  || 0;
        my $flags_privacy_policy           = $flags->{privacy_policy}             || 0;
        my $flags_physical_address         = $flags->{physical_address}           || 0;
       
		require DADA::Template::Widgets;
		my  $scrn =  DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'change_info_screen.tmpl',
				-with   => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
					-vars   => {
					screen                         => 'change_info',
					done                           => $done,
					errors                         => $errors,
					errors_ending                  => $errors_ending,
					err_word                       => $err_word,
					list                           => $list,
					list_name                      => $list_name        ? $list_name        : $li->{list_name},
					list_owner_email               => $list_owner_email ? $list_owner_email : $li->{list_owner_email},
					admin_email                    => $admin_email      ? $admin_email      : $li->{admin_email},
					info                           => $info             ? $info             : $li->{info},
					privacy_policy                 => $privacy_policy   ? $privacy_policy   : $li->{privacy_policy},
					physical_address               => $physical_address ? $physical_address : $li->{physical_address},
					flags_list_name                => $flags_list_name,
					flags_invalid_list_owner_email => $flags_invalid_list_owner_email,
					flags_list_info                => $flags_list_info,
					flags_privacy_policy           => $flags_privacy_policy,
					flags_physical_address         => $flags_physical_address,
					flags_list_name_bad_characters => $flags_list_name_bad_characters,
				},
			}
		);
    	e_print($scrn);
    }else{

        $admin_email = $list_owner_email
            unless defined($admin_email);

        $ls->save({
                    list_owner_email =>   strip($list_owner_email),
                    admin_email      =>   strip($admin_email),
                    list_name        =>   $list_name,
                    info             =>   $info,
                    privacy_policy   =>   $privacy_policy,
                    physical_address =>   $physical_address,

                   });

        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=change_info&done=1');

    }
}





sub change_password {

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'change_password',
                                     );


    $list = $admin_list;

    require DADA::Security::Password;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    if(!$process) {
        require DADA::Template::Widgets;
        my $scrn =   DADA::Template::Widgets::wrap_screen(
					{
						-screen => 'change_password_screen.tmpl',
						-with   => 'admin', 
						-wrapper_params => { 
							-Root_Login => $root_login,
							-List       => $list,  
						},
                        -list   => $list,
                        -vars   => {
							screen     => 'change_password',
                    		root_login => $root_login,
                        	},
                 	}
				);
		e_print($scrn);

    }else{

        my $old_password       = $q->param('old_password');
        my $new_password       = $q->param('new_password');
        my $again_new_password = $q->param('again_new_password');

        if($root_login != 1){
            my $password_check = DADA::Security::Password::check_password($li->{password},$old_password);
            if ($password_check != 1) {
                user_error(
					-List  => $list,
                    -Error => "invalid_password"
				);
                return;
            }
        }

        $new_password       = strip($new_password);
        $again_new_password = strip($again_new_password);

        if ( $new_password ne $again_new_password ||
             $new_password eq ""
 		){
            user_error(
				-List  => $list,
                -Error => "list_pass_no_match");
            return;
        }

        $ls->save(
			{
            	password => DADA::Security::Password::encrypt_passwd($new_password),
            }
		);

        # -no_list_security_check, because the list password's changed, it wouldn't pass it anyways...
        logout(
			-no_list_security_check => 1,
			-redirect_url            => $DADA::Config::S_PROGRAM_URL . '?f=' . $DADA::Config::SIGN_IN_FLAVOR_NAME . '&list=' . $list,
		);
        return;
    }
}




sub delete_list {

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'delete_list'
									);

    my $list = $admin_list;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    if(!$process){

        require DADA::Template::Widgets;
        my $scrn =   DADA::Template::Widgets::wrap_screen(
					{
						-screen => 'delete_list_screen.tmpl',
						-with   => 'admin', 
						-wrapper_params => { 
							-Root_Login => $root_login,
							-List       => $list,  
						},
                        -list   => $list,
						-vars   => {
							screen => 'delete_list',
						},
						-list_settings_vars_param => {
							-list    => $list,
							-dot_it => 1,
						},
                    }
				);
    	e_print($scrn);

    }else{

        require DADA::MailingList;
        DADA::MailingList::Remove(
            {
                -name           => $list,
                -delete_backups => xss_filter($q->param('delete_backups')),
            }
        );


        $c->flush;

        my $logout_cookie = logout(-redirect => 0);
        require DADA::Template::Widgets;
        my $scrn =   DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'delete_list_success_screen.tmpl',
                -with   => 'list',  
			#	-list   => $list, # The list doesn't really exist anymore now, does it? 
				-wrapper_params => { 
					-header_params => {-COOKIE => $logout_cookie},
				}
			}
		);
    	e_print($scrn);
    }
}




sub list_options {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_options'
    );

    $list = $admin_list;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get();

    my $can_use_mx_lookup = 0;

    eval { require Net::DNS; };
    if ( !$@ ) {
        $can_use_mx_lookup = 1;
    }

    my $can_use_captcha = 0;
    eval { require DADA::Security::AuthenCAPTCHA; };
    if ( !$@ ) {
        $can_use_captcha = 1;
    }

    if ( !$process ) {
	
 	   require    DADA::Template::Widgets;
	   my $scrn = DADA::Template::Widgets::wrap_screen(
	        {
	            -screen => 'list_options_screen.tmpl',
				-with   => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-expr   => 1, 
	            -list   => $list,
	            -vars   => {
	                screen => 'list_options',
	                title  => 'Mailing List Options',
	                done              => $done,
	                CAPTCHA_TYPE      => $DADA::Config::CAPTCHA_TYPE,
	                can_use_mx_lookup => $can_use_mx_lookup,
	                can_use_captcha   => $can_use_captcha,
	            },
	            -list_settings_vars_param => {
	                -list   => $list,
	                -dot_it => 1,
	            },
	        }
	    );
		e_print($scrn);
    }
    else {

        $list = $admin_list;
        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    hide_list                               => 0,
                    closed_list                             => 0,
                    invite_only_list                        => 0,
                    get_sub_notice                          => 0,
                    get_unsub_notice                        => 0,
                    enable_closed_loop_opt_in               => 0,
                    skip_sub_confirm_if_logged_in           => 0,
                    unsub_confirm_email                     => 0,
                    skip_unsub_confirm_if_logged_in         => 0,
                    send_unsub_success_email                => 0,
                    send_sub_success_email                  => 0,
					send_newest_archive                     => 0,
                    mx_check                                => 0,
                    limit_sub_confirm                       => 0,
                    limit_unsub_confirm                     => 0,
                    email_your_subscribed_msg               => 0,
                    email_you_are_not_subscribed_msg        => 0,
                    use_alt_url_sub_confirm_success         => 0,
                    alt_url_sub_confirm_success             => '',
                    alt_url_sub_confirm_success_w_qs        => 0,
                    use_alt_url_sub_confirm_failed          => 0,
                    alt_url_sub_confirm_failed              => '',
                    alt_url_sub_confirm_failed_w_qs         => 0,
                    use_alt_url_sub_success                 => 0,
                    alt_url_sub_success                     => '',
                    alt_url_sub_success_w_qs                => 0,
                    use_alt_url_sub_failed                  => 0,
                    alt_url_sub_failed                      => '',
                    alt_url_sub_failed_w_qs                 => 0,
                    use_alt_url_unsub_confirm_success       => 0,
                    alt_url_unsub_confirm_success           => '',
                    alt_url_unsub_confirm_success_w_qs      => 0,
                    use_alt_url_unsub_confirm_failed        => 0,
                    alt_url_unsub_confirm_failed            => '',
                    alt_url_unsub_confirm_failed_w_qs       => 0,
                    use_alt_url_unsub_success               => 0,
                    alt_url_unsub_success                   => '',
                    alt_url_unsub_success_w_qs              => 0,
                    use_alt_url_unsub_failed                => 0,
                    alt_url_unsub_failed                    => '',
                    alt_url_unsub_failed_w_qs               => 0,
                    enable_subscription_approval_step       => 0,
					enable_mass_subscribe                   => 0,
					send_subscribed_by_list_owner_message   => 0,
					send_unsubscribed_by_list_owner_message => 0, 
					send_last_archived_msg_mass_mailing     => 0, 
                    captcha_sub                             => 0,
					unsub_link_behavior                     => undef, 
                }
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?flavor=list_options&done=1' );
    }
}



sub sending_preferences {
	my ($admin_list, $root_login) = check_list_security(
	-cgi_obj  => $q,
	-Function => 'sending_preferences'
);

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    if(!$process){

	    require DADA::MailingList::Settings;

	    my $ls = DADA::MailingList::Settings->new({-list => $list});
	    my $li = $ls->get;

	    require DADA::Security::Password;


	    my $decrypted_sasl_pass = '';
	    if($li->{sasl_smtp_password}){
	         $decrypted_sasl_pass = DADA::Security::Password::cipher_decrypt($li->{cipher_key}, $li->{sasl_smtp_password});
	   }

	    my $decrypted_pop3_pass = '';
	    if($li->{pop3_password}){
	        $decrypted_pop3_pass = DADA::Security::Password::cipher_decrypt($li->{cipher_key}, $li->{pop3_password});
	    }

		# DEV: This is really strange, since if Net::SMTP isn't available, SMTP sending is completely broken.
	    my $can_use_net_smtp = 0;
	     eval { require Net::SMTP_auth };
	    if(!$@){
	        $can_use_net_smtp = 1;
	    }


	    my $can_use_smtp_ssl = 0;
	     eval { require Net::SMTP::SSL };
	    if(!$@){
	        $can_use_smtp_ssl = 1;
	    }

	    my $can_use_ssl = 0;
	     eval { require IO::Socket::SSL };
	    if(!$@){
	        $can_use_ssl = 1;
	    }

	    my $mechanism_popup;
	    if($can_use_net_smtp){

	        $mechanism_popup = $q->popup_menu(-name     => 'sasl_auth_mechanism',
	 										  -id       => 'sasl_auth_mechanism',
	                                          -default  => $li->{sasl_auth_mechanism},
	                                          '-values' => [qw(PLAIN LOGIN DIGEST-MD5 CRAM-MD5)],
	                                         );
	    }

	    my $pop3_auth_mode_popup =  $q->popup_menu(-name     => 'pop3_auth_mode',
											 -id => 'pop3_auth_mode',
	                                          -default  => $li->{pop3_auth_mode},
	                                          '-values' => [qw(BEST PASS APOP CRAM-MD5)],
	                                           -labels   => {BEST => 'Automatic'},

	                                         );

	    my $wrong_uid = 0;
           $wrong_uid = 1
            if $< != $>;


        my $no_smtp_server_set = 0;
         if(
			!$li->{smtp_server}  &&
			$li->{sending_method} eq "smtp"
		 ) {
			$no_smtp_server_set = 1;
         }


		# Amazon SES Test for stuff. 
		my $has_aws_credentials_file = 0; 
		if(defined($DADA::Config::AMAZON_SES_OPTIONS->{aws_credentials_file}) && (-e $DADA::Config::AMAZON_SES_OPTIONS->{aws_credentials_file})){ 
			$has_aws_credentials_file = 1; 
		}
		my $has_ses_verify_email_address_script = 0; 
		if(defined($DADA::Config::AMAZON_SES_OPTIONS->{ses_verify_email_address_script}) && (-e $DADA::Config::AMAZON_SES_OPTIONS->{ses_verify_email_address_script})){ 
			$has_ses_verify_email_address_script = 1; 
		}
		

		my $amazon_ses_required_modules = [ 
			{module => 'Cwd', installed => 1}, 
			{module => 'Digest::SHA', installed => 1}, 
			{module => 'URI::Escape', installed => 1}, 
			{module => 'MIME::Base64', installed => 1}, 	
			{module => 'Crypt::SSLeay', installed => 1}, 	
			{module => 'XML::LibXML', installed => 1},
			{module => 'LWP 6',       installed => 1}, 
		];


		my $amazon_ses_has_needed_cpan_modules = 1; 
		eval {require Cwd;};           
		if($@){
			$amazon_ses_required_modules->[0]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0;
		}
		eval {require Digest::SHA;};   
		if($@){
			$amazon_ses_required_modules->[1]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0;
		}
		eval {require URI::Escape;};
		if($@){
			$amazon_ses_required_modules->[2]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0;
		}
		eval {require MIME::Base64;};  
		if($@){
			$amazon_ses_required_modules->[3]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0;
		}
		eval {require Crypt::SSLeay;}; 
		if($@){
			$amazon_ses_required_modules->[4]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0;
		}
		eval {require XML::LibXML;};
		if($@){
			$amazon_ses_required_modules->[5]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0; 
		}
		eval {require LWP;};
		if($@){
			$amazon_ses_required_modules->[6]->{installed}           = 0;
			$amazon_ses_has_needed_cpan_modules = 0; 
		}
		else { 
			if($LWP::VERSION < 6){ 
				$amazon_ses_required_modules->[6]->{installed}           = 0;
				$amazon_ses_has_needed_cpan_modules = 0;
			}
		}

        require    DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen         => 'sending_preferences_screen.tmpl',
				-with           => 'admin', 
				-expr           => 1, 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					screen                         => 'sending_preferences',
					done                           => $done,
					no_smtp_server_set             => $no_smtp_server_set,
					mechanism_popup                => $mechanism_popup,
					can_use_ssl                    => $can_use_ssl,
					can_use_smtp_ssl               => $can_use_smtp_ssl,
					'list_settings.pop3_username'  => $li->{pop3_username}, # DEV ?
					decrypted_pop3_pass => $decrypted_pop3_pass,
					wrong_uid           => $wrong_uid,
					pop3_auth_mode_popup => $pop3_auth_mode_popup,
					can_use_ssl          => $can_use_ssl,
					f_flag_settings               => $DADA::Config::MAIL_SETTINGS . ' -f' . $li->{admin_email},

					use_sasl_smtp_auth  => $q->param('use_sasl_smtp_auth') ? $q->param('use_sasl_smtp_auth') : $li->{use_sasl_smtp_auth},
					decrypted_pop3_pass => $q->param('pop3_password')      ? $q->param('pop3_password')      : $decrypted_pop3_pass,
					sasl_auth_mechanism => $q->param('sasl_auth_mechanism') ? $q->param('sasl_auth_mechanism') : $li->{sasl_auth_mechanism},
					sasl_smtp_username  => $q->param('sasl_smtp_username') ? $q->param('sasl_smtp_username') : $li->{sasl_smtp_username},
					sasl_smtp_password  => $q->param('sasl_smtp_password') ? $q->param('sasl_smtp_password') : $decrypted_sasl_pass,
				
					# Amazon SES 
					has_aws_credentials_file            => $has_aws_credentials_file, 
					has_ses_verify_email_address_script => $has_ses_verify_email_address_script, 
					aws_credentials_file                => $DADA::Config::AMAZON_SES_OPTIONS->{aws_credentials_file},
					ses_verify_email_address_script     => $DADA::Config::AMAZON_SES_OPTIONS->{ses_verify_email_address_script},
					amazon_ses_has_needed_cpan_modules  => $amazon_ses_has_needed_cpan_modules, 
					amazon_ses_required_modules         => $amazon_ses_required_modules, 
				},
				-list_settings_vars_param => {
					-list    => $list,
					-dot_it => 1,
				},
			}
		);
		e_print($scrn);
    }else{

        my $pop3_password = strip( $q->param('pop3_password') ) || undef;
        if ( defined($pop3_password) ) {
            $q->param(
                'pop3_password',
                DADA::Security::Password::cipher_encrypt(
                    $li->{cipher_key}, $pop3_password
                )
            );
        }
        my $sasl_smtp_password = strip( $q->param('sasl_smtp_password') )
          || undef;
        if ( defined($sasl_smtp_password) ) {
            $q->param(
                'sasl_smtp_password',
                DADA::Security::Password::cipher_encrypt(
                    $li->{cipher_key}, $sasl_smtp_password
                )
            );
        }

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    sending_method      => undef,
                    add_sendmail_f_flag => 0,
                    use_pop_before_smtp => 0,
                    set_smtp_sender     => 0,
                    smtp_server         => undef,
                    pop3_server         => undef,
                    pop3_username       => undef,
                    pop3_password       => undef,
                    pop3_use_ssl        => undef,
                    pop3_auth_mode      => 'BEST',
                    use_smtp_ssl        => 0,
                    sasl_auth_mechanism => undef,
                    use_sasl_smtp_auth  => 0,
                    sasl_smtp_username  => undef,
                    sasl_smtp_password  => undef,
                    smtp_port           => undef,
                }
            }
        );
        if ( $q->param('no_redirect') == 1 ) {

            # ...
        }
        else {
            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=sending_preferences&done=1' );
        }

	}
}

sub mass_mailing_preferences {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mass_mailing_preferences'
    );

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    if ( !$process ) {

		require  DADA::Mail::MailOut;
		my $mo = DADA::Mail::MailOut->new({ -list => $list });
		my ($batch_sending_enabled, $batch_size, $batch_wait)  = $mo->batch_params();

		my $show_amazon_ses_options = 0; 
		if (
	        $ls->param('sending_method') eq 'amazon_ses'
	        || (   $ls->param('sending_method') eq 'smtp'
	            && $ls->param('smtp_server') =~ m/amazonaws\.com/ )
			)
	    {
			$show_amazon_ses_options = 1; 
		}
		
        my @message_amount = ( 1 .. 180 );
		unshift( @message_amount, $batch_size );

        my @message_wait = (
            1 .. 60, 70,  80,  90,  100, 110, 110, 120,
            130,     140, 150, 160, 170, 180
        );

        unshift( @message_wait, $batch_wait);
        my @message_label = (1);
        my %label_label = ( 1 => 'second(s)', );

        my $mass_send_amount_menu = $q->popup_menu(
            -name     => "mass_send_amount",
            -id       => "mass_send_amount",
            -value    => [@message_amount],
            -onChange => 'previewBatchSendingSpeed()',
        );

        my $bulk_sleep_amount_menu = $q->popup_menu(
            -name     => "bulk_sleep_amount",
            -id       => "bulk_sleep_amount",
            -value    => [@message_wait],
            -onChange => 'previewBatchSendingSpeed()',
        );

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen         => 'mass_mailing_preferences_screen.tmpl',
				-with           => 'admin', 
				-expr           => 1, 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					screen                  => 'mass_mailing_preferences',
					done                    => $done,
					batch_sending_enabled   => $batch_sending_enabled, 
					mass_send_amount_menu   => $mass_send_amount_menu,
					bulk_sleep_amount_menu  => $bulk_sleep_amount_menu,
					batch_size              => $batch_size, 
					batch_wait              => $batch_wait,
					show_amazon_ses_options => $show_amazon_ses_options,  
				},
				-list_settings_vars_param => {
					-list    => $list,
					-dot_it => 1,
				},
			}
		);
		e_print($scrn);
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    mass_send_amount                  => undef,
                    bulk_sleep_amount                 => undef,
                    enable_bulk_batching              => 0,
                    adjust_batch_sleep_time           => 0,
                    get_finished_notification         => 0,
                    auto_pickup_dropped_mailings      => 0,
                    restart_mailings_after_each_batch => 0,
                    smtp_connection_per_batch         => 0,
                    mass_mailing_send_to_list_owner   => 0, 
					amazon_ses_auto_batch_settings    => 0, 
                }
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?flavor=mass_mailing_preferences&done=1' );
    }
}

sub amazon_ses_verify_email { 

	my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'sending_preferences'
    );

	my $amazon_ses_verify_email = $q->param('amazon_ses_verify_email'); 
	if(!-e $DADA::Config::AMAZON_SES_OPTIONS->{ses_verify_email_address_script}){ 
		print $q->header(); 
		print '<p class="error">Cannot find, "' . $DADA::Config::AMAZON_SES_OPTIONS->{ses_verify_email_address_script} .'"</p>'; 
		return; 
	}
	if(check_for_valid_email($amazon_ses_verify_email) == 1){ 
		print $q->header(); 
		print '<p class="error">Invalid Email Address!</p>'; 
	}
	else { 
		`$DADA::Config::AMAZON_SES_OPTIONS->{ses_verify_email_address_script} -v $amazon_ses_verify_email -k $DADA::Config::AMAZON_SES_OPTIONS->{aws_credentials_file}`; 
		print $q->header(); 
		print '<p class="positive">Verification Sent! Check the email account for: ' . $amazon_ses_verify_email . ' to complete the verification!</p>'; 
	}

}

sub amazon_ses_get_stats { 

	my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mass_mailing_preferences'
    );
	$list = $admin_list; 
	
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	
	if(     $ls->param('sending_method') eq 'amazon_ses'
		|| ($ls->param('sending_method') eq 'smtp' && $ls->param('smtp_server') =~ m/amazonaws\.com/)
	){ 
		
		my ( $SentLast24Hours, $Max24HourSend, $MaxSendRate );
		my $found_ses_get_stats_script = 1; 
		if(!-e $DADA::Config::AMAZON_SES_OPTIONS->{ses_get_stats_script}){ 
			$found_ses_get_stats_script = 0; 
		}
		else { 
			require DADA::App::AmazonSES; 
			my $ses = DADA::App::AmazonSES->new; 
		    my ( $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $ses->get_stats; 
		
			print $q->header(); 
			require DADA::Template::Widgets;
			e_print(DADA::Template::Widgets::screen(
				{
					-screen => 'amazon_ses_get_stats_widget.tmpl',
					-vars   => {
						MaxSendRate                => commify($MaxSendRate),
						Max24HourSend              => commify($Max24HourSend),
						SentLast24Hours            => commify($SentLast24Hours),
						found_ses_get_stats_script => $found_ses_get_stats_script,  

						ses_get_stats_script       => $DADA::Config::AMAZON_SES_OPTIONS->{ses_get_stats_script},
						
					}
				}
			));
			
		}
	}
	else { 
		print $q->header(); 
		# Nothing... 
	}
}




sub previewBatchSendingSpeed {


  my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                      -Function => 'mass_mailing_preferences');

    $list = $admin_list;

	my $lh = DADA::MailingList::Subscribers->new({-list => $list});
	

    print $q->header();

    my $enable_bulk_batching           = xss_filter($q->param('enable_bulk_batching'));
    my $mass_send_amount               = xss_filter($q->param('mass_send_amount'));
    my $bulk_sleep_amount              = xss_filter($q->param('bulk_sleep_amount'));
	my $amazon_ses_auto_batch_settings = xss_filter($q->param('amazon_ses_auto_batch_settings')); 
	
	my $per_hour         = 0;
	my $num_subs         = 0;
	my $time_to_send     = 0;
	my $somethings_wrong = 0;

	
    if($enable_bulk_batching == 1){

		if($amazon_ses_auto_batch_settings == 1){ 
			require DADA::Mail::MailOut; 
			my $mo = DADA::Mail::MailOut->new({-list => $list}); 
			my $enabled; 
			($enabled, $mass_send_amount, $bulk_sleep_amount, ) = $mo->batch_params({-amazon_ses_auto_batch_settings => 1});
		}
		
        if($bulk_sleep_amount > 0 && $mass_send_amount > 0){

            my $per_sec  = $mass_send_amount / $bulk_sleep_amount;
        	$per_hour = int($per_sec * 60 *60 + .5); # DEV .5 is some sort of rounding thing (with int). That's wrong.

			$num_subs    = $lh->num_subscribers;
			my $total_hours = 0;
			if($num_subs > 0 && $per_hour > 0){
				$total_hours = $lh->num_subscribers / $per_hour;
			}

			$per_hour      = commify($per_hour);
			$num_subs    = commify($num_subs);

			$time_to_send = _formatted_runtime($total_hours * 60 * 60);

        }
        else{
            $somethings_wrong = 1;
        }
    }

	require DADA::Template::Widgets;
	e_print(DADA::Template::Widgets::screen(
		{
			-screen => 'previewBatchSendingSpeed_widget.tmpl',
			-vars   => {
				enable_bulk_batching => $enable_bulk_batching,
				per_hour             => $per_hour,
				num_subscribers      => $num_subs,
				time_to_send         => $time_to_send,
				somethings_wrong     => $somethings_wrong,
			}
		}
	));



}




sub commify {
   my $input = shift;
      $input = reverse($input);
      $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
      $input = reverse($input);
	return $input; 
}







sub adv_sending_preferences {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'adv_sending_preferences'
    );
    $list = $admin_list;

    require DADA::Security::Password;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;
    
	if(!$process){


        unshift(@DADA::Config::CHARSETS, $li->{charset});
        my $precedence_popup_menu = $q->popup_menu(-name    =>  "precedence",
                                                    -value   => [@DADA::Config::PRECEDENCES],
                                                    -default =>  $li->{precedence},
                                                    );

        my $priority_popup_menu = $q->popup_menu(-name    =>  "priority",
                                                 -value   => [keys %DADA::Config::PRIORITIES],
                                                 -labels  => \%DADA::Config::PRIORITIES,
                                                 -default =>  $li->{priority},
                                                );

        my $charset_popup_menu = $q->popup_menu(-name   => 'charset',
                                                -value  => [@DADA::Config::CHARSETS],
                                               );

        my $plaintext_encoding_popup_menu =  $q->popup_menu( -name    => 'plaintext_encoding',
                                                             -value   => [@DADA::Config::CONTENT_TRANSFER_ENCODINGS],
                                                             -default =>  $li->{plaintext_encoding},
                                                             );

        my $html_encoding_popup_menu = $q->popup_menu(-name    => 'html_encoding',
                                                      -value   => [@DADA::Config::CONTENT_TRANSFER_ENCODINGS],
                                                      -default =>  $li->{html_encoding},
                                                     );



 	   my $can_mime_encode = 1;
	    eval {require MIME::EncWords;};
	    if($@){
			$can_mime_encode = 0;
		}

	    require DADA::Template::Widgets;
	    my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'adv_sending_preferences_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-list   => $list,
				-vars   => {
					screen                        => 'adv_sending_preferences',
					title                         => 'Advanced Sending Preferences',
					done                          => $done,
					precedence_popup_menu         => $precedence_popup_menu,
					priority_popup_menu           => $priority_popup_menu,
					charset_popup_menu            => $charset_popup_menu,
					plaintext_encoding_popup_menu => $plaintext_encoding_popup_menu,
					html_encoding_popup_menu      => $html_encoding_popup_menu,
					can_mime_encode               => $can_mime_encode,
				},
				-list_settings_vars_param => {
					-list    => $list,
					-dot_it => 1,
				},

			}
		);
		e_print($scrn);
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    precedence                   => undef,
                    priority                     => undef,
                    charset                      => undef,
                    plaintext_encoding           => undef,
                    html_encoding                => undef,
                    strip_message_headers        => 0,
                    print_return_path_header     => 0,
                    print_errors_to_header       => 0,
                    verp_return_path             => 0,
                    use_domain_sending_tunings   => 0,
                    mime_encode_words_in_headers => 0,
                }
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?flavor=adv_sending_preferences&done=1' );
    }
}



sub sending_tuning_options {

    my ($admin_list, $root_login) =  check_list_security(-cgi_obj    => $q,
                                                         -Function   => 'sending_tuning_options');


    my @allowed_tunings = qw(
        domain
        sending_method
        add_sendmail_f_flag
        print_return_path_header
        verp_return_path
    );

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

   if($process eq 'remove_all'){

        $ls->save({domain_sending_tunings => ''});
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1&remove=1');

   }elsif($process == 1){

        my $tunings = eval($li->{domain_sending_tunings});
        #my $errors  = {};


        if($q->param('new_tuning') == 1){

            my $new_tuning = {};
            my $p_list = $q->Vars;

            for(keys %$p_list){
                if($_ =~ m/^new_tuning_/){
                    my $name = $_;
                       $name =~ s/^new_tuning_//;
                    $new_tuning->{$name} = $q->param($_);

                   # if($p_list->{new_tuning_domain}){
                   #    # TO DO domain regex needs some work...
                   #     if(DADA::App::Guts($p_list->{new_tuning_domain}) == 0 && $p_list->{new_tuning_domain} !~ m/^([a-z]+[-]*(?=[a-z]|\d)\d*[a-z]*)\.(.*?)/){
                   #         $errors{not_a_domain} = 1;
                   #     }
                   # }
                }
            }

            if($new_tuning->{domain}){ # really, the only required field.
            #if(! keys %$errors){
              push(@$tunings, $new_tuning);
           # }
             }
        }

       # if(! keys %$errors){

            require Data::Dumper;
            my $tunes = Data::Dumper->new([$tunings]);
               $tunes->Purity(1)->Terse(1)->Deepcopy(1);
            $ls->save({domain_sending_tunings => $tunes->Dump});
       #}

        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1');

   }elsif($q->param('process_edit') =~ m/Edit/i) {

        if($q->param('domain')){

            my $saved_tunings = eval($li->{domain_sending_tunings});
            my $new_tunings = [];

            for my $st(@$saved_tunings){

                if($st->{domain} eq $q->param('domain')) {

                    for my $a_tuning(@allowed_tunings){

                        my $new_tune = $q->param($a_tuning) || 0;
                        #  if($q->param($a_tuning)){
                            $st->{$a_tuning} = $new_tune;
                        # }
                    }
                }
            }


            require Data::Dumper;
            my $tunes = Data::Dumper->new([$saved_tunings]);
               $tunes->Purity(1)->Terse(1)->Deepcopy(1);
            $ls->save({domain_sending_tunings => $tunes->Dump});

        }

        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1&edit=1');


   }elsif($q->param('process_edit') =~ m/Remove/i) {

        if($q->param('domain')){

            my $saved_tunings = eval($li->{domain_sending_tunings});
            my $new_tunings = [];

            for(@$saved_tunings){

                if($_->{domain} ne $q->param('domain')) {
                    push(@$new_tunings, $_);
                }

            }

            require Data::Dumper;
            my $tunes = Data::Dumper->new([$new_tunings]);
               $tunes->Purity(1)->Terse(1)->Deepcopy(1);
            $ls->save({domain_sending_tunings => $tunes->Dump});

        }

       print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1&remove=1');


   } else {


       my $li = $ls->get;

       my $saved_tunings = eval($li->{domain_sending_tunings});

       # This is done because variables inside loops are local, not global, and global vars don't work in loops.
       my $c = 0;
       for(@$saved_tunings){
        $saved_tunings->[$c]->{S_PROGRAM_URL} = $DADA::Config::S_PROGRAM_URL;
        $c++;
       }

        require DADA::Template::Widgets;
        my $scrn =  DADA::Template::Widgets::wrap_screen({-screen => 'sending_tuning_options.tmpl',
												-with           => 'admin', 
												-wrapper_params => { 
													-Root_Login => $root_login,
													-List       => $list,  
												},
											  -expr   => 1, 
                                              -vars   => {

                                                            tunings => $saved_tunings,
                                                            done    => ($q->param('done')   ? 1 : 0),
                                                            edit    => ($q->param('edit')   ? 1 : 0),
                                                            remove  => ($q->param('remove') ? 1 : 0),

                                                            use_domain_sending_tunings => ($li->{use_domain_sending_tunings} ? 1 : 0),

                                                            # For pre-filling in the "new" forms
                                                            list_add_sendmail_f_flag         => $li->{add_sendmail_f_flag},
                                                            list_print_return_path_header    => $li->{print_return_path_header},
                                                            list_verp_return_path            => $li->{verp_return_path},

                                                      },
                                             });

		e_print($scrn);

    }

}

sub sending_preferences_test {


    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'sending_preferences'
    );

    my $list = $admin_list;
    $q->param( 'no_redirect', 1 );

	# Saves the params passed
    sending_preferences();

    require DADA::Mail::Send;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $admin_list } );
    my $li = $ls->get;

    my $mh = DADA::Mail::Send->new(
        {
            -list   => $list,
            -ls_obj => $ls,
        }
    );


	
    my ( $results, $lines, $report );
	eval {
   		( $results, $lines, $report ) = $mh->sending_preferences_test;
	}; 
	if($@){
		$results .= $@;
	}
	#else { 
	#	# ... 
	#}

    $results =~ s/\</&lt;/g;
    $results =~ s/\>/&gt;/g;

    my $ht_report = [];

    for my $f (@$report) {

        my $s_f = $f->{line};
        $s_f =~ s{Net\:\:SMTP(.*?)\)}{};
        push ( @$ht_report,
            { SMTP_command => $s_f, message => $f->{message} } );
    }

	print $q->header(); 
    require DADA::Template::Widgets;
    e_print(DADA::Template::Widgets::screen(
        {
            -screen => 'sending_preferences_test_widget.tmpl',
			-expr   => 1, 
            -vars   => {
                report  => $ht_report,
                raw_log => $results,
            },
			-list_settings_vars_param => {
				-list   => 	$list,
				-dot_it => 1,
			},
        }
    ));

}




sub view_list {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    $list = $admin_list;

    my $add_email_count                  = xss_filter($q->param('add_email_count'))                  || 0;
    my $delete_email_count               = xss_filter($q->param('delete_email_count'))               || 0;
    my $black_list_add                   = xss_filter($q->param('black_list_add'))                   || 0;
    my $approved_count                   = xss_filter($q->param('approved_count'))                   || 0;
    my $denied_count                     = xss_filter($q->param('denied_count'))                     || 0;
	my $bounced_list_moved_to_list_count = xss_filter($q->param('bounced_list_moved_to_list_count')) || 0; 
	my $bounced_list_removed_from_list   = xss_filter($q->param('bounced_list_removed_from_list'))   || 0;
	my $type                             = xss_filter($q->param('type'))                             || 'list';
	my $query                            = xss_filter( $q->param('query') )                          || undef;
    my $order_by                         = xss_filter($q->param('order_by'))                         || 'email';
    my $order_dir                        = xss_filter($q->param('order_dir'))                        || 'asc';
    my $mode                             = xss_filter($q->param('mode'))                             || 'view'; 
	my $page                             = xss_filter($q->param('page'))                             || 1;


	require DADA::Template::Widgets; 
	if($mode ne 'viewport'){ 
		my $scrn = DADA::Template::Widgets::wrap_screen(
	        {
	            -list           => $list,
	            -screen         => 'view_list_screen.tmpl',
	            -with           => 'admin',
	            -wrapper_params => {
	                -Root_Login => $root_login,
	                -List       => $list,
	            },
	            -expr => 1,
	            -vars => {
					screen           => 'view_list',
	                flavor           => 'view_list',
					type             => $type,
					page             => $page, 
					query            => $query, 
					order_by         => $order_by, 
					order_dir        => $order_dir, 
					
					
				    add_email_count   => $add_email_count,                 
				    delete_email_count     => $delete_email_count,            
				    black_list_add  => $black_list_add,                  
				    approved_count   => $approved_count,                 
				    denied_count    => $denied_count,                  
					bounced_list_moved_to_list_count => $bounced_list_moved_to_list_count, 
					bounced_list_removed_from_list   => $bounced_list_removed_from_list, 
					
					type_title => $type_title, 

				},
			}
		); 
		
		e_print($scrn); 
		return; 
	}
	else { 

	    # DEV: Yup. Forgot what this was for.
	    if ( defined( $q->param('list') ) ) {
	        if ( $list ne $q->param('list') ) {

				# I should look instead to see if we're logged in view ROOT and then just
				# *Switch* the login. Brilliant! --- maybe I don't want to switch lists automatically - without
				# someone perhaps knowing that THAT's what I did...
	            logout( -redirect_url => $DADA::Config::S_PROGRAM_URL . '?'
	                  . $q->query_string(), );
	            return;
	        }
	    }

	
	    require DADA::MailingList::Settings;

	    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
	    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

	    my $num_subscribers = $lh->num_subscribers( { -type => $type } );

	    my $show_bounced_list = 0;
	    if ( $lh->num_subscribers( { -type => 'bounced_list' } ) > 0  || $ls->param('bounce_handler_when_threshold_reached') eq 'move_to_bounced_sublist') {
	        $show_bounced_list = 1;
	    }

	    my $subscribers = [];


	    require Data::Pageset;
	    my $page_info    = undef;
	    my $pages_in_set = [];
	    my $total_num    = 0;
	    if ($query) {
	        ( $total_num, $subscribers ) = $lh->search_list(
	            {
	                -query     => $query,
	                -type      => $type,
	                -start     => ( $page - 1 ),
	                '-length'  => $ls->param('view_list_subscriber_number'),
	                -order_by  => $order_by,
	                -order_dir => $order_dir,

	            }
	        );

	        $page_info = Data::Pageset->new(
	            {
	                total_entries    => $total_num,
	                entries_per_page => $ls->param('view_list_subscriber_number'),
	                current_page     => $page,
	                mode          => 'slide',    # default fixed
	                pages_per_set => 10,
	            }
	        );

	    }
	    else {

	        $subscribers = $lh->subscription_list(
	            {
	                -type => $type,

	# this really should be just, $page, but subscription_list() would have to be updated, which will break a lot of things...
	                -start     => ( $page - 1 ),
	                '-length'  => $ls->param('view_list_subscriber_number'),
	                -order_by  => $order_by,
	                -order_dir => $order_dir,
	            }
	        );
	        $total_num = $num_subscribers;
	        $page_info = Data::Pageset->new(
	            {
	                total_entries    => $num_subscribers,
	                entries_per_page => $ls->param('view_list_subscriber_number'),
	                current_page     => $page,
	                mode          => 'slide',    # default fixed
	                pages_per_set => 10,
	            }
	        );

	    }

	    foreach my $page_num ( @{ $page_info->pages_in_set() } ) {
	        if ( $page_num == $page_info->current_page() ) {
	            push( @$pages_in_set, { page => $page_num, on_current_page => 1 } );
	        }
	        else {
	            push( @$pages_in_set,
	                { page => $page_num, on_current_page => undef } );
	        }
	    }

	    require DADA::ProfileFieldsManager;
	    my $pfm         = DADA::ProfileFieldsManager->new;
	    my $fields_attr = $pfm->get_all_field_attributes;

	    my $field_names = [];
	    for ( @{ $lh->subscriber_fields } ) {
	        push(
	            @$field_names,
	            {
	                name          => $_,
	                label         => $fields_attr->{$_}->{label},
	                S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL
	            }
	        );
	    }

	    require DADA::Template::Widgets;
	    my $scrn = DADA::Template::Widgets::screen(
	        {
	            -list           => $list,
	            -screen         => 'view_list_viewport_widget.tmpl',
	            -expr => 1,
	            -vars => {

					screen             => 'view_list',
	                flavor             => 'view_list',
	                type               => $type,
	                type_title         => $type_title,


	                first              => $page_info->first,
	                last               => $page_info->last,
	                first_page         => $page_info->first_page,
	                last_page          => $page_info->last_page,
	                next_page          => $page_info->next_page,
	                previous_page      => $page_info->previous_page,
	                page               => $page_info->current_page,
	                show_list_column   => 0,
	                field_names        => $field_names,

	                pages_in_set       => $pages_in_set,
	                num_subscribers    => commify($num_subscribers),
	                total_num          => $total_num,
					total_num_commified => commify($total_num), 
	                subscribers        => $subscribers,
	                query              => $query,
	                order_by           => $order_by,
	                order_dir          => $order_dir,

	                show_bounced_list  => $show_bounced_list,

	                GLOBAL_BLACK_LIST  => $DADA::Config::GLOBAL_BLACK_LIST,
	                GLOBAL_UNSUBSCRIBE => $DADA::Config::GLOBAL_UNSUBSCRIBE,

	                can_use_global_black_list                => $lh->can_use_global_black_list,
	                can_use_global_unsubscribe               => $lh->can_use_global_unsubscribe,

	                can_filter_subscribers_through_blacklist => $lh->can_filter_subscribers_through_blacklist,

	                flavor_is_view_list => 1,

					 list_subscribers_num              => commify($lh->num_subscribers( { -type => 'list' } )),
				     black_list_subscribers_num       =>  commify($lh->num_subscribers( { -type => 'black_list' } )),
				     white_list_subscribers_num       =>  commify($lh->num_subscribers( { -type => 'white_list' } )),
				     authorized_senders_num           =>  commify($lh->num_subscribers( { -type => 'authorized_senders' } )),
				     sub_request_list_subscribers_num =>  commify($lh->num_subscribers( { -type => 'sub_request_list' } )),
				     bounced_list_num                 =>  commify($lh->num_subscribers( { -type => 'bounced_list' } )),
	            },
	            -list_settings_vars_param => {
	                -list   => $list,
	                -dot_it => 1,
	            },
	        }
	    );
		print $q->header(); 
	    e_print($scrn);
	}
}



sub list_activity { 
	
    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_activity'
    );
    $list = $admin_list;

	require DADA::App::LogSearch; 
	my $dals = DADA::App::LogSearch->new; 
	my $r = $dals->list_activity(
		{
			-list => $list, 
		}
	); 
	my $i;
	for($i = 0; $i <= (scalar(@$r) - 1); $i++){ 
		$r->[$i]->{show_email} = 1;
	}

	require DADA::Template::Widgets; 
	e_print(
        DADA::Template::Widgets::wrap_screen(
            {
				-list   => $list,
                -screen => 'list_activity.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
                -vars   => {
                   history => $r, 
                },
				-expr => 1,
            }
        )
    );

}


sub view_bounce_history {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    $list = $admin_list;

    require DADA::App::BounceHandler::Logs;
    my $bhl     = DADA::App::BounceHandler::Logs->new;
    my $results = $bhl->search(
        {
            -query => $email,
            -list  => $list,
            -file  => $DADA::Config::LOGS . '/bounces.txt',
        }
    );

    require DADA::Template::Widgets;
    e_print( $q->header );
    e_print(
        DADA::Template::Widgets::screen(
            {
                -screen => 'bounce_search_results_modal_menu.tmpl',
                -vars   => {
                    search_results => $results,
                    total_bounces  => scalar(@$results),
                    email          => $email,
                    type           => 'bounced_list',
                }
            }
        )
    );

}




sub subscription_requests {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    $list = $admin_list;

    if ( defined( $q->param('list') ) ) {
        if ( $list ne $q->param('list') ) {
            logout( -redirect_url => $DADA::Config::S_PROGRAM_URL . '?'
                  . $q->query_string(), );
            return;
        }
    }

    my @address        = $q->param('address')        || ();
    my $return_to      = $q->param('return_to')      || '';
    my $return_address = $q->param('return_address') || '';

    my $count = 0;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ( $q->param('process') =~ m/approve/i ) {
        for my $email (@address) {
            $lh->move_subscriber(
                {
                    -email     => $email,
                    -from      => 'sub_request_list',
                    -to        => 'list',
                    -mode      => 'writeover',
                    -confirmed => 1,
                }
            );

            my $new_pass    = '';
            my $new_profile = 0;
            if (   $DADA::Config::PROFILE_OPTIONS->{enabled} == 1
                && $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ )
            {

                # Make a profile, if needed,
                require DADA::Profile;
                my $prof = DADA::Profile->new( { -email => $email } );
                if ( !$prof->exists ) {
                    $new_profile = 1;
                    $new_pass    = $prof->_rand_str(8);
                    $prof->insert(
                        {
                            -password  => $new_pass,
                            -activated => 1,
                        }
                    );
                }

                # / Make a profile, if needed,
            }
            require DADA::App::Messages;
            DADA::App::Messages::send_subscription_request_approved_message(
                {
                    -list   => $list,
                    -email  => $email,
                    -ls_obj => $ls,

                    #-test   => $self->test,
                    -vars => {
                        new_profile        => $new_profile,
                        'profile.email'    => $email,
                        'profile.password' => $new_pass,

                    }
                }
            );
            $count++;
        }

        my $flavor_to_return_to = 'view_list';
        if ( $return_to eq 'membership' ) {    # or, others...
            $flavor_to_return_to = $return_to;
        }

        my $qs = 'f='
          . $flavor_to_return_to
          . ';type='
          . $q->param('type')
          . ';approved_count='
          . $count;

        if ( $return_to eq 'membership' ) {
            $qs .= ';email=' . $return_address;
        }

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
    }
    elsif ( $q->param('process') =~ m/deny/i ) {
        for my $email (@address) {
            $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_request_list',
                }
            );
            require DADA::App::Messages;
            DADA::App::Messages::send_subscription_request_denied_message(
                {
                    -list   => $list,
                    -email  => $email,
                    -ls_obj => $ls,

                    #-test   => $self->test,
                }
            );
            $count++;
        }

        my $flavor_to_return_to = 'view_list';
        if ( $return_to eq 'membership' ) {    # or, others...
            $flavor_to_return_to = $return_to;
        }

        my $qs = 'f='
          . $flavor_to_return_to
          . ';type='
          . $q->param('type')
          . ';denied_count='
          . $count;

        if ( $return_to eq 'membership' ) {
            $qs .= ';email=' . $return_address;
        }

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL . '?' . $qs );

    }
    else {
        die "unknown process!";
    }

}




sub remove_all_subscribers {

	# This needs that email notification as well...
	# I need to first, clone the list and then do my thing. 
	# Cloning will be really be resource intensive, so we can't do 
	# checks on each address, 
	# maybe the only check we'll do is to see if anything currently exists. 
	# If there is? Don't do the clone. 
	# If there isn't Do the clone
	# maybe have a paramater saying what to do on an error. 
	# or just return undef. 
	
    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list',
    );
    $list              = $admin_list;
	my $black_list_add = 0; 

    my $type  = xss_filter( $q->param('type') );
    my $lh    = DADA::MailingList::Subscribers->new( { -list => $list } );

	my $ls    = DADA::MailingList::Settings->new( { -list => $list } );
	
	require DADA::App::MassSend; 
	if($type eq 'list') { 
		if($ls->param('send_unsubscribed_by_list_owner_message') == 1){
			require DADA::App::MassSend; 
			eval {
				
				DADA::App::MassSend::just_unsubscribed_mass_mailing(
					{
						-list              => $list, 
						-send_to_everybody => 1, 
					}
				); 
			};
			if($@){ 
				carp $@; 
			}
		}
		
		
		if(
			$ls->param('black_list')               == 1 &&
			$ls->param('add_unsubs_to_black_list') == 1
		){
			$black_list_add = $lh->copy_all_subscribers(
				{ 
					-from => 'list', 
					-to   => 'black_list',
				}
			);
		}
		
	}
	
	

	
    my $count = $lh->remove_all_subscribers( { -type => $type, } );

  	print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=view_list&delete_email_count=' . $count .'&type=' . $type . '&black_list_add=' .$black_list_add);
	return;
}





sub filter_using_black_list {


    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'filter_using_black_list');
    $list = $admin_list;

    if(!$process){

        my $lh = DADA::MailingList::Subscribers->new({-list => $list});
        my $ls = DADA::MailingList::Settings->new({-list => $list});
        my $li = $ls->get;

        my $filtered = $lh->filter_list_through_blacklist;
        require DADA::Template::Widgets;
        my $scrn =  DADA::Template::Widgets::wrap_screen(
			{
				-list   => $list,
				-screen => 'filter_using_black_list.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					filtered          => $filtered,
			},
			}
		);
		e_print($scrn);

    }
}


sub membership {

    if ( !$email ) {
        view_list();
        return;
    }
    my $type = $q->param('type') || 'list';

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );

    $list = $admin_list;
    my $query     = xss_filter( $q->param('query') )     || undef;
    my $page      = xss_filter( $q->param('page') )      || 1;
    my $type      = xss_filter( $q->param('type') );
    my $order_by  = xss_filter( $q->param('order_by') )  || 'email';
    my $order_dir = xss_filter( $q->param('order_dir') ) || 'asc';

    my $add_email_count    = $q->param('add_email_count') || 0;
    my $delete_email_count = $q->param('delete_email_count');
    my $black_list_add     = $q->param('black_list_add') || 0;
    my $approved_count     = $q->param('approved_count') || 0;
    my $denied_count       = $q->param('denied_count') || 0;
    my $bounced_list_moved_to_list_count =
      $q->param('bounced_list_moved_to_list_count') || 0;
    my $bounced_list_removed_from_list =
      $q->param('bounced_list_removed_from_list') || 0;

	my $is_valid_email = 1; 
	if(check_for_valid_email($email)   == 1){ 
		$is_valid_email = 0; 
	}
	
	
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ($process) {
        if ( !$root_login ) {
            die
"You must be logged in with the Dada Mail Root Password to be able to edit a Subscriber's Profile Fields.";
        }
        my $new_fields = {};
        for my $nfield ( @{ $lh->subscriber_fields() } ) {
            if ( defined( $q->param($nfield) ) ) {
                $new_fields->{$nfield} = $q->param($nfield);
            }
        }
		
		my $fields = DADA::Profile::Fields->new;
        $fields->insert(
            {
                -email  => $email,
                -fields => $new_fields,
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?f=membership;email='
              . $email
              . ';type='
              . $type
              . ';done=1' );
        return;
    }
    else {

        my $fields = [];

        my $subscriber_info = {};
		if($is_valid_email){ 
           $subscriber_info = $lh->get_subscriber( { -email => $email, -type => $type } );
		}
		
        # DEV: This is repeated quite a bit...
        require DADA::ProfileFieldsManager;
        my $pfm         = DADA::ProfileFieldsManager->new;
        my $fields_attr = $pfm->get_all_field_attributes;
        for my $field ( @{ $lh->subscriber_fields() } ) {
            push(
                @$fields,
                {
                    name  => $field,
                    value => $subscriber_info->{$field},
                    label => $fields_attr->{$field}->{label},
                }
            );
        }

        my $subscribed_to_lt = {};
		if($is_valid_email) { 
	        for ( @{ $lh->member_of( { -email => $email } ) } ) {
	            $subscribed_to_lt->{$_} = 1;
	        }
		}

        my $add_to = {
            list               => 1,
            black_list         => 1,
            white_list         => 1,
            authorized_senders => 1,
        };

        # Except when, it's already a part of that sublist:
        for ( keys %$subscribed_to_lt ) {
            delete( $add_to->{$_} );    # if $subscribed_to_lt->{$_} == 1;
        }

        # Or if it's blacklisted... can't add!
        if ( $ls->param('closed_list') == 1 ) {
            delete( $add_to->{list} );
        }
        if (   $ls->param('black_list') == 1
            && $ls->param('allow_admin_to_subscribe_blacklisted') != 1
            && $subscribed_to_lt->{black_list} == 1 )
        {
            delete( $add_to->{list} );
        }
        if (   $ls->param('enable_subscription_approval_step')
            && $subscribed_to_lt->{sub_request_list} )
        {
            delete( $add_to->{list} );
        }

        # if Authorized Senders isn't active, well, let's not allow to be added:
        if ( $ls->param('enable_authorized_sending') == 1 ) {

            #...
        }
        else {
            delete( $add_to->{authorized_senders} );
        }

        # Same with the white list
        if ( $ls->param('enable_white_list') == 1 ) {

            #...
        }
        else {
            delete( $add_to->{white_list} );

        }

        #%list_types

        my $add_to_popup_menu = $q->popup_menu(
            -name     => 'type',
            -id       => 'type_add',
            -default  => 'list',
            '-values' => [ keys %$add_to ],
            -labels   => \%list_types,
        );

        # Only if black list is enabled and they're not currently subscribed.
        if ( $ls->param('black_list') == 1 && $subscribed_to_lt->{list} != 1 ) {

            # ...
        }
        else {
            delete( $add_to->{black_list} );
        }

        my $member_of   = [];
        my $remove_from = [];
        foreach (%$subscribed_to_lt) {
            if ( $_ =~
m/^(list|black_list|white_list|authorized_senders|bounced_list)$/
              )
            {
                push( @$member_of,
                    { type => $_, type_title => $list_types{$_} } );
                push( @$remove_from, $_ );
            }
        }

        my $remove_from_popup_menu = $q->popup_menu(
            -name     => 'type',
            -id       => 'type_remove',
            '-values' => $remove_from,
            -labels   => \%list_types,
        );

        my $subscribed_to_list = 0;
        if ( $subscribed_to_lt->{list} == 1 ) {
            $subscribed_to_list = 1;

        }

        my $subscribed_to_sub_request_list = 0;
        if ( $subscribed_to_lt->{sub_request_list} == 1 ) {
            $subscribed_to_sub_request_list = 1;

        }

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'membership.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -vars => {
                    done                   => $done,
                    email                  => $email,
                    type                   => $type,
                    page                   => $page,
                    query                  => $query,
                    order_by               => $order_by,
                    order_dir              => $order_dir,
                    type_title             => $type_title,
                    fields                 => $fields,
                    root_login             => $root_login,
                    add_to_popup_menu      => $add_to_popup_menu,
                    remove_from_popup_menu => $remove_from_popup_menu,
                    remove_from_num        => scalar(@$remove_from),
                    member_of              => $member_of,
                    rand_string            => generate_rand_string(),
                    member_of_num          => scalar(@$remove_from),
                    add_to_num             => scalar( keys %$add_to ),
                    subscribed_to_list     => $subscribed_to_list,
                    subscribed_to_sub_request_list =>
                      $subscribed_to_sub_request_list,

                    add_email_count    => $add_email_count,
                    delete_email_count => $delete_email_count,
                    black_list_add     => $black_list_add,
                    approved_count     => $approved_count,
                    denied_count       => $denied_count,
                    bounced_list_moved_to_list_count =>
                      $bounced_list_moved_to_list_count,
                    bounced_list_removed_from_list =>
                      $bounced_list_removed_from_list,

					can_have_subscriber_fields =>
                      $lh->can_have_subscriber_fields,

					is_valid_email => $is_valid_email,

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );

        e_print($scrn);

    }
}


sub update_email_results { 

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    $list = $admin_list;

	require DADA::MailingList::Subscribers; 
	require DADA::MailingList::Subscriber::Validate;
	require DADA::MailingList::Settings; 

	my %list_types = (
        list               => 'Subscribers',
        black_list         => 'Black Listed',
        authorized_senders => 'Authorized Senders',
        white_list         => 'White Listed',
        sub_request_list   => 'Subscription Requests',
        bounced_list       => 'Bouncing Addresses',
    );
	my %error_title = (
		 invalid_email    => 'Invalid Email Address', 
		 subscribed       => 'Already Subscribed', 
		 mx_lookup_failed => 'MX Lookup Failed', 
		 black_listed     => 'Black Listed', 
		 not_white_listed => 'Not on the White List', 
	);
	
	my $for_all_lists     = $q->param('for_all_lists') || 0; 
	my $lists_to_validate = [];
	my $email         = cased(xss_filter($q->param('email'))); 
	my $updated_email = cased(xss_filter($q->param('updated_email'))); 

	my $list_lh = DADA::MailingList::Subscribers->new({-list => $list}); 
	
	if($list_lh->can_have_subscriber_fields) { 
		if($for_all_lists == 1 && $root_login == 1){ 
			require DADA::Profile; 
			my $prof = DADA::Profile->new({-email => $email}); 
			$lists_to_validate = $prof->subscribed_to; 
		}
		else { 
			push(@$lists_to_validate, $list); 	
		}
	}
	else { 
		push(@$lists_to_validate, $list); 	
	}

	# old address
	
	my $all_list_reports = [];
	my $all_list_status = 1;
	
	for my $to_validate_list(@$lists_to_validate) { 
		
		my $all_reports = [];
		my $all_status  = 1;
		
		my $lh = DADA::MailingList::Subscribers->new({-list => $to_validate_list});   
		my $sv = DADA::MailingList::Subscriber::Validate->new( { -list => $to_validate_list } );
		my $ls = DADA::MailingList::Settings->new( { -list => $to_validate_list } );
		
		for my $type(@{$lh->member_of({-email => $email})}){ 
			my $sub_report = [];		
			# new address
			my ( $sub_status, $sub_errors ) = $sv->subscription_check(
		        {
		            -email => $updated_email,
		            -type  => $type, 
					-skip  => [
		                'closed_list',
		                'over_subscription_quota',
		                'already_sent_sub_confirmation',
		                'invite_only_list',
						($ls->param('allow_admin_to_subscribe_blacklisted') == 1) ? 
	                    (
	                    	'black_listed', 
	                    ) : (),
		            ],
		        }
		    );
			if($sub_status == 0){ 
				$all_status      = 0; 
				$all_list_status = 0; 
			}
			my $errors = [];
			for(keys %$sub_errors){ 
				push(@$errors, {error => $_, error_title => $error_title{$_}}); 
			}
			push(@$all_reports, { type_title => $list_types{$type}, type => $type, status => $sub_status, errors => $errors}); 
		}

		push(@$all_list_reports, 
			{
				list        => $to_validate_list, 
				list_name   => $ls->param('list_name'), 
				all_status  => $all_status,
				all_reports => $all_reports, 
			}
		); 
		
	}
	use Data::Dumper; 	
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
		{ 
			-screen => 'update_email_results_widget.tmpl',
			-expr   => 1,
			-vars   => { 
				email              => $email, 
				updated_email      => $updated_email, 
				all_list_status    => $all_list_status,
				all_list_reports   => $all_list_reports, 
				for_all_lists      => $for_all_lists, 
				root_login         => $root_login, 
				validate_dump      => Dumper($all_list_reports),

			},
		}
	); 
	print $q->header(); 
	e_print($scrn);

}

sub admin_update_email { 

	# Validate
	my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    $list = $admin_list;

	# Get some params
	my $email         = cased(xss_filter($q->param('email'))); 
	my $updated_email = cased(xss_filter($q->param('updated_email'))); 
	my $for_all_lists = $q->param('for_all_lists') || 0; 
	require DADA::MailingList::Subscribers; 	

	my $og_prof = undef; 
	
	my $list_lh = DADA::MailingList::Subscribers->new({-list => $list}); 
	if($list_lh->can_have_subscriber_fields) { 
		require DADA::Profile; 
		$og_prof = DADA::Profile->new({-email => $email}); 	
	}
	
	# One, or many lists we're updating?? 
	my $lists_to_update = [];
	if($list_lh->can_have_subscriber_fields) { 
		if($for_all_lists == 1 && $root_login == 1){ 
				$lists_to_update = $og_prof->subscribed_to; 
		}
		else { 
			push(@$lists_to_update, $list); 
		}
	}
	else { 
		push(@$lists_to_update, $list); 		
	}
	
	# Switch the addresses around
	# But only for lists, and sublists of that lists 
	# that this address is a member of
	# 
	require DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;

	for my $u_list(@$lists_to_update) { 
		my $lh = DADA::MailingList::Subscribers->new({-list => $u_list}); 
		for my $type(@{$lh->member_of({-email => $email})}){ 
			$lh->remove_subscriber(
				{
					-email  => cased($email),
					-type   => $type, 
					-log_it => 0, 
				}
			);
			$lh->add_subscriber(
				{
					-email  => cased($updated_email), 
					-type   => $type, 
					-log_it => 0,
				}
			);
			$log->mj_log(
				$u_list, 
				'Updated Subscription for ' . $u_list . '.' . $type,  
				$email . ':' . $updated_email
			);
		}	
	}
	
	# PROFILES
	
	if(! $list_lh->can_have_subscriber_fields) { 
		print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=membership&email=' . $updated_email . '&type=list&done=1'); 
		return;
	}
	
	# All Lists? EASY
	if($for_all_lists == 1){ 
		if(! $og_prof->exists){ 
			# Make one (old email) 
			$og_prof->insert({
			    -password  => $og_prof->_rand_str(8),
			    -activated => 1,
			}); 
		}
		my $updated_prof = DADA::Profile->new({-email => $updated_email});
		# This already around? 
		if(! $updated_prof->exists){ 
			$og_prof->update({ 
				-activated      => 1, 
				-update_email	=> $updated_email, 
			}); 
			# Then this method changes the updated email to the email..
			# And changes the profiles fields, as well... 
			$og_prof->update_email;
		}
		# so, the old prof have any subscriptions? 
		my $old_prof = DADA::Profile->new({-email => $email}); 
		if($old_prof->exists){ 
			# Again, this will only touch, "list" sublist...
			if(scalar(@{$old_prof->subscribed_to}) == 0) { 
				# Then we can remove it, 
				$old_prof->remove;
			}
		}
	}
	else { 

		# JUST one list? 
		# it gets a little crazy... 
		
		# Basically what we want to do is this: 
		# If the OLD address is subscribed to > 1 list, don't mess with the current
		# profile information, 
		# If the NEW address already has profile information, do not overwrite it
		# 
	
		# Remember, this only works with the, "list" sublist... 
		my $og_subscriptions = $og_prof->subscribed_to; 
	
		if(! $og_prof->exists){ 
			# Make one (old email) 
			$og_prof->insert({
			    -password  => $og_prof->_rand_str(8),
			    -activated => 1,
			}); 
		}

		# Is there another mailing list that has the old address as a subscriber? 
		# Remember, we already changed over ONE of the subscriptions. 
	
		if(scalar(@$og_subscriptions) >= 1){ 
		
			my $updated_prof = DADA::Profile->new({-email => $updated_email});
			# This already around? 
			if($updated_prof->exists){ 
			
				# Got any information? 
				if($updated_prof->{fields}->are_empty){ 
				
					# No info in there yet? 
					$updated_prof->{fields}->insert({
						-fields => $og_prof->{fields}->get, 
						-mode   => 'writeover', 
					}); 		
				}
			}
			else {
			
				# So there's not a profile, yet? 
				# COPY (don't move) the old profile info, 
				# to the new profile
				# (inludeds fields) 
				my $new_prof = $og_prof->copy({ 
					-from => $email, 
					-to   => $updated_email, 
				}); 
			}
		}
		else { 
		
			# So, no other mailing list has a subscription for the new email address
			# 
			my $updated_prof = DADA::Profile->new({-email => $updated_email});
			# But does this profile already exists for the updated address? 
			if($updated_prof->exists){ 
			
				 # Well, nothing, since it already exists.
			}
			else { 
			
				# updated our old email profile, to the new email 
				# Only ONE subscription, w/Profile
				# First save the updated email
				$og_prof->update({ 
					-activated      => 1, 
					-update_email	=> $updated_email, 
				}); 
				# Then this method changes the updated email to the email..
				# And changes the profiles fields, as well... 
				$og_prof->update_email;		
			}
		}
		# so, the old prof have any subscriptions? 
		my $old_prof = DADA::Profile->new({-email => $email}); 
		if($old_prof->exists){ 
			# Again, this will only touch, "list" sublist...
			if(scalar(@{$old_prof->subscribed_to}) == 0) { 
				# Then we can remove it, 
				$old_prof->remove;
			}
		}
		
	}
	print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=membership&email=' . $updated_email . '&type=list&done=1'); 
}


sub mailing_list_history { 
    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    $list = $admin_list;
	
	my $email = xss_filter($q->param('email')); 

    require DADA::App::LogSearch;
    my $searcher = DADA::App::LogSearch->new;
    my $r        = $searcher->subscription_search(
        {
            -list  => $list,
            -email => $email,
        }
    );
	#use Data::Dumper; 
	#die Dumper($r); 
	
	my $i;
	for($i = 0; $i <= (scalar(@$r) - 1); $i++){ 
		$r->[$i]->{show_email} = 0;
	}
	@$r = reverse(@$r);

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
		{ 
			-screen => 'filtered_list_activity_widget.tmpl',
			-expr   => 1,
			-vars   => { 
				history => $r,
				#raw_history            => Dumper($r),
			},
		}
	); 
	print $q->header(); 
	e_print($scrn);

}



sub admin_change_profile_password { 
    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
	my $list = $admin_list; 
	my $profile_password = xss_filter($q->param('profile_password')); 
    my $email            = xss_filter( $q->param('email') );
	my $type             = xss_filter( $q->param('type') );

    require DADA::Profile; 
	my $prof = DADA::Profile->new( { -email => $email } );

	if($prof->exists){ 
		
		$prof->update(
			{
				-password => $profile_password,
			}
		);
		# Reactivate the Account. ?
		$prof->activate();
	}
	else { 
		$prof->insert(
			{
				-password  => $profile_password,
				-activated => 1, 
			}
		);
	}
	
	# DEV: This is going to get repeated quite a bit..
	require DADA::Profile::Htpasswd;
	foreach my $p_list(@{$prof->subscribed_to}) { 
		my $htp     = DADA::Profile::Htpasswd->new({-list => $p_list});
		for my $id(@{$htp->get_all_ids}) {  
			$htp->setup_directory({-id => $id});
		}
	}
	#
	
		
	print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
          . '?f=membership;email='
          . $email
          . ';type='
          . $type
          . ';done=1' );
    return;
}


sub add {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add'
    );

    $list = $admin_list;

	my $type           = $q->param('type') || 'list';
	my $return_to      = $q->param('return_to') || ''; 
	my $return_address = $q->param('return_address') || ''; 
	
	
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ( $q->param('process') ) {

        if ( $q->param('method') eq 'via_add_one' ) {

# We're going to fake the, "via_textarea", buy just make a CSV file, and plunking it
# in the, "new_emails" CGI param. (Hehehe);

            my @columns = ();
            push( @columns, xss_filter( $q->param('email') ) );
            for ( @{ $lh->subscriber_fields() } ) {
                push( @columns, xss_filter( $q->param($_) ) );
            }
            require Text::CSV;

            my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

            my $status =
              $csv->combine(@columns);    # combine columns into a string
            my $line = $csv->string();    # get the combined string

            $q->param( 'new_emails', $line );
            $q->param( 'method',     'via_textarea' );

            # End shienanengans.

        }

        if ( $q->param('method') eq 'via_file_upload' ) {
            if ( strip( $q->param('new_email_file') ) eq '' ) {
                print $q->redirect(
                    -uri => $DADA::Config::S_PROGRAM_URL . '?f=add' );
                return;
            }
        }
        elsif ( $q->param('method') eq 'via_textarea' ) {
            if ( strip( $q->param('new_emails') ) eq '' ) {
                print $q->redirect(
                    -uri => $DADA::Config::S_PROGRAM_URL . '?f=add' );
                return;
            }
        }

        # DEV: This whole building of query string is much too messy.
        my $qs =
            '&type='
          . $q->param('type')
          . '&new_email_file='
          . $q->param('new_email_file');
        if ( DADA::App::Guts::strip( $q->param('new_emails') ) ne "" ) {

          # DEV: why is it, "new_emails.txt"? Is that supposed to be a variable?
            my $outfile =
              make_safer( $DADA::Config::TMP . '/'
                  . $q->param('rand_string') . '-'
                  . 'new_emails.txt' );

            open( OUTFILE, '>:encoding(UTF-8)', $outfile )
              or die "can't write to " . $outfile . ": $!";

            # DEV: TODO encoding?
            print OUTFILE $q->param('new_emails');
            close(OUTFILE);
            chmod( 0666, $outfile );

          # DEV: why is it, "new_emails.txt"? Is that supposed to be a variable?
            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?f=add_email&fn='
                  . $q->param('rand_string') . '-'
                  . 'new_emails.txt'
                  . $qs
 				  . '&return_to=' . $return_to
				  . '&return_address=' . $return_address
				);

        }
        else {

            if ( $q->param('method') eq 'via_file_upload' ) {
                upload_that_file($q);
            }
            my $filename = $q->param('new_email_file');
            $filename =~ s!^.*(\\|\/)!!;

            $filename = uriescape($filename);

            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?f=add_email&fn='
                  . $q->param('rand_string') . '-'
                  . $filename
                  . $qs );

        }
    }
    else {

        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $li = $ls->get;

        my $num_subscribers            = $lh->num_subscribers;
        my $subscription_quota_reached = 0;
        $subscription_quota_reached = 1
          if ( $li->{use_subscription_quota} == 1 )
          && ( $num_subscribers >= $li->{subscription_quota} )
          && ( $num_subscribers + $li->{subscription_quota} > 1 );

        my $list_type_switch_widget = $q->popup_menu(
            -name     => 'type',
            '-values' => [ keys %list_types ],
            -labels   => \%list_types,
            -default  => $type,
        );

        my $rand_string = generate_rand_string();

        my $fields = [];

        # DEV: This is repeated quite a bit...
        require DADA::ProfileFieldsManager;
        my $pfm         = DADA::ProfileFieldsManager->new;
        my $fields_attr = $pfm->get_all_field_attributes;
        for my $field ( @{ $lh->subscriber_fields() } ) {
            push(
                @$fields,
                {
                    name  => $field,
                    label => $fields_attr->{$field}->{label},
                }
            );
        }
		
		my $list_is_closed = 0; 
		if(
			$type eq 'list' &&
			$ls->param('closed_list') == 1
		){ 
			$list_is_closed = 1;
		}
        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'add_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-expr   => 1, 
                -vars   => {
					screen                     => 'add',
                    subscription_quota_reached => $subscription_quota_reached,
                    num_subscribers            => $num_subscribers,
                    type       => $type,
                    type_title => $type_title,
                    flavor     => 'add',

                    rand_string => $rand_string,

                    list_subscribers_num =>
                      $lh->num_subscribers({-type => 'list'}),
                    black_list_subscribers_num =>
                      $lh->num_subscribers({-type => 'black_list'}),
                    white_list_subscribers_num =>
                      $lh->num_subscribers({-type => 'white_list'}),
                    authorized_senders_num =>
                      $lh->num_subscribers({-type => 'authorized_senders'}),
                   bounced_list_num =>
                      $lh->num_subscribers({-type => 'bounced_list'}),

                    fields => $fields,

                    can_have_subscriber_fields =>
                      $lh->can_have_subscriber_fields,

					list_is_closed => $list_is_closed,

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        e_print($scrn);
    }

}


sub check_status {

    my $filename = $q->param('new_email_file');
    $filename =~ s{^(.*)\/}{};

    $filename = uriescape($filename);

    if ( !-e $DADA::Config::TMP . '/' . $filename . '-meta.txt' ) {
        warn "no meta file at: "
          . $DADA::Config::TMP . '/'
          . $filename
          . '-meta.txt';
        print $q->header();
	}
    else {

        chmod( $DADA::Config::FILE_CHMOD,
            make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' ) );

        open my $META, '<',
          make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' )
          or die $!;

        my $s = do { local $/; <$META> };
        my ( $bytes_read, $content_length, $per ) = split ( '-', $s, 3 );
        close($META);

        my $small = 250 - ( $per * 2.5 );
        my $big   = $per * 2.5;

        print $q->header();
		require DADA::Template::Widgets;
		e_print(DADA::Template::Widgets::screen(
			{
				-screen => 'file_upload_status_bar_widget.tmpl',
				-vars   => {
					percent        => $per,
					bytes_read     => $bytes_read,
					content_length => $content_length,
					big            => $big,
					small          => $small,
				}
			}
		));

    }
}

sub dump_meta_file {
    my $filename = $q->param('new_email_file');
    $filename =~ s{^(.*)\/}{};

    $filename = uriescape($filename);

    my $full_path_to_filename =
      make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' );

	if(! -e $full_path_to_filename){

	}
	else {

  	  my $chmod_check =
	      chmod( $DADA::Config::FILE_CHMOD, $full_path_to_filename );
	    if ( $chmod_check != 1 ) {
	        warn "could not chmod '$full_path_to_filename' correctly.";
	    }

	    my $unlink_check = unlink($full_path_to_filename);
	    if ( $unlink_check != 1 ) {
	        warn "deleting meta file didn't work for: " . $full_path_to_filename;
	    }
	}
}

sub generate_rand_string {

    #warn "generate_rand_string";

    my $chars = shift
      || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    my $num = shift || 1024;

    require Digest::MD5;

    my @chars = split '', $chars;
    my $ran;
    for ( 1 .. $num ) {
        $ran .= $chars[ rand @chars ];
    }
    return Digest::MD5::md5_hex($ran);
}

sub upload_that_file {

    my $fh = $q->upload('new_email_file');

    my $filename = $q->param('new_email_file');
    $filename =~ s!^.*(\\|\/)!!;

    $filename = uriescape($filename);

    # warn '$filename ' . $filename;

    # warn '$q->param(\'rand_string\') '    . $q->param('rand_string');
    # warn '$q->param(\'new_email_file\') ' . $q->param('new_email_file');
    return '' if !$filename;

    my $outfile =
      make_safer(
        $DADA::Config::TMP . '/' . $q->param('rand_string') . '-' . $filename );

    # warn ' $outfile ' . $outfile;

    open( OUTFILE, '>', $outfile )
      or die ( "can't write to " . $outfile . ": $!" );

    while ( my $bytesread = read( $fh, my $buffer, 1024 ) ) {

        # warn $buffer;

        print OUTFILE $buffer;
    }

    close(OUTFILE);
    chmod( 0666, $outfile );

}

sub add_email {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add_email'
    );
    $list = $admin_list;

	my $return_to      = $q->param('return_to') || ''; 
	my $return_address = $q->param('return_address') || ''; 
	
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
	require DADA::ProfileFieldsManager;
	my $pfm =  DADA::ProfileFieldsManager->new;

    my $lh = DADA::MailingList::Subscribers->new(
		{
			-list     => $list,
			-dpfm_obj => $pfm,
		 }
	);
    my $subscriber_fields = $lh->subscriber_fields;

    if ( !$process ) {

        my $new_emails_fn = $q->param('fn');

        my $new_emails = [];
        my $new_info   = [];

        ( $new_emails, $new_info ) =
          DADA::App::Guts::csv_subscriber_parse( $admin_list, $new_emails_fn );

        my (
            $subscribed,       $not_subscribed, $black_listed,
            $not_white_listed, $invalid
          )
          = $lh->filter_subscribers_w_meta(
            {
                -emails => $new_info,
                -type   => $type
            }
          );

        my $num_subscribers = $lh->num_subscribers;

        my $going_over_quota = undef;

# and for some reason, this is its own subroutine...
# This is down here, so the status bar won't disapear before this page is loaded (or the below redirect)
        dump_meta_file();

        $going_over_quota = 1
          if ( ( $num_subscribers + $#$not_subscribed ) >=
            $ls->param('subscription_quota') )
          && ( $ls->param('use_subscription_quota') == 1 );

        my $addresses_to_add = 0;
        $addresses_to_add = 1
          if ( defined( @$not_subscribed[0] ) );

        my $field_names = [];
        for (@$subscriber_fields) {
            push ( @$field_names, { name => $_ } );
        }

		if(
			$type eq 'list' &&
			$ls->param('closed_list') == 1
		){ 
			die "Your list is currently CLOSED to subscribers."; 
		}
		
		# If we're using the black list, but 
		# the list owner is allowed to subscribed blacklisted addresses, 
		# we have to communicate that to the template: 
		if(
			$ls->param('black_list') == 1 
		 && $ls->param('allow_admin_to_subscribe_blacklisted') == 1
		){ 
			for(@$black_listed){ 
				$_->{'list_settings.allow_admin_to_subscribe_blacklisted'} = 1
			}
		}
		
		
        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'add_email_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-expr   => 1,
                -vars   => {
					can_have_subscriber_fields          => $lh->can_have_subscriber_fields,
                    going_over_quota   => $going_over_quota,
                    field_names        => $field_names,
                    subscribed         => $subscribed,
                    not_subscribed     => $not_subscribed,
                    black_listed       => $black_listed,
                    not_white_listed   => $not_white_listed,
                    invalid            => $invalid,
                    type               => $type,
                    type_title         => $type_title,
					root_login         => $root_login,
					return_to          => $return_to, 
					return_address     => $return_address,
                },
				-list_settings_vars_param => {
					-list => $list,
					-dot_it => 1,
				},
            }
        );
		e_print($scrn);
    }
    else {

        if ( $process =~ /invit/i ) {
            &list_invite;
            return;
        }
        else {

			if(
				$ls->param('enable_mass_subscribe') != 1 &&
				$type eq 'list'
			){
				die "Mass Subscribing via the List Control Panel has been disabled.";
			}

            my @address             = $q->param("address");
            my $new_email_count     = 0;
			my $skipped_email_count = 0; 

            # Each Addres is a CSV line...
            for my $a (@address) {
	
                my $info = $lh->csv_to_cds($a);
                my $dmls = $lh->add_subscriber(
                    {
                        -email 		    => $info->{email},
                        -fields 		=> $info->{fields},
                        -type   		=> $type,
						-fields_options => {
							-mode => $q->param('fields_options_mode')
						},
						-dupe_check    => {
							-enable  => 1,
							-on_dupe => 'ignore_add',
	                	},
                    }
                );
				if(defined($dmls)){ # undef means it wasn't added. 
                	$new_email_count++;
            	}
				else { 
					$skipped_email_count++; 
				}
			}

			if($type eq 'list') { 
				if($ls->param('send_subscribed_by_list_owner_message') == 1){
					require DADA::App::MassSend; 
					eval { 
						DADA::App::MassSend::just_subscribed_mass_mailing(
							{ 
								-list      => $list, 
								-addresses => [@address], 
							}	
						); 
					};
					if($@){ 
						carp $@; 
					}
				}
				if($ls->param('send_last_archived_msg_mass_mailing') == 1){ 	
					eval { 
						DADA::App::MassSend::send_last_archived_msg_mass_mailing(
							{ 
								-list      => $list, 
								-addresses => [@address], 
							}	
						);
					};				
					if($@){ 
						carp $@; 
					}	
				}
			}
			
			if(
				$DADA::Config::PROFILE_OPTIONS->{enabled}    == 1 &&
				$DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/
			){
				eval { 
					require DADA::Profile::Htpasswd;
					my $htp     = DADA::Profile::Htpasswd->new({-list => $list});
					for my $id(@{$htp->get_all_ids}) {  
						$htp->setup_directory({-id => $id});
					}
				};
				if($@){ 
					warn "Problem updated Password Protected Directories: $@"; 
				}
			}
			

			my $flavor_to_return_to = 'view_list'; 
			if($return_to eq 'membership'){ # or, others...
				$flavor_to_return_to = $return_to;
			}
			
			my $qs = 'flavor=' . $flavor_to_return_to
			  . ';add_email_count='
              . $new_email_count 
              . ';skipped_email_count='
              . $skipped_email_count
              . ';type='
              . $type;

			if($return_to eq 'membership'){
				$qs .= ';email=' . $return_address;
			}


            print $q->redirect(
				-uri => $DADA::Config::S_PROGRAM_URL . '?' . $qs
			);
        }
    }
}




sub delete_email {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'delete_email',
                                                       );
    $list = $admin_list;

	my $type = $q->param('type') || 'list';

    require  DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    if(!$process){
        require DADA::Template::Widgets;
        my $scrn =  DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'delete_email_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-expr => 1, 
				-vars => {
					screen => 'delete_email',
					title  => 'Remove',
					can_use_global_black_list           => $lh->can_use_global_black_list,
					can_use_global_unsubscribe          => $lh->can_use_global_unsubscribe,
					list_type_isa_list                  => ($type eq 'list')       ? 1 : 0,
					list_type_isa_black_list            => ($type eq 'black_list') ? 1 : 0,
					list_type_isa_authorized_senders    => ($type eq 'authorized_senders') ? 1 : 0,
					list_type_isa_white_list            => ($type eq 'white_list') ? 1 : 0,
					type                                => $type,
					type_title                          => $type_title,
					flavor                              => 'delete_email',
					list_subscribers_num                => $lh->num_subscribers({-type => 'list'}),
					black_list_subscribers_num          => $lh->num_subscribers({-type => 'black_list'}),
					white_list_subscribers_num          => $lh->num_subscribers({-type => 'white_list'}),
					authorized_senders_num              => $lh->num_subscribers({-type => 'authorized_senders'}),
				},
				-list_settings_vars_param => {
					-list    => $list,
					-dot_it => 1,
				},
			}
		);
    	e_print($scrn);

    }else{

        my $delete_list = undef;
        my $delete_email_file = $q->param('delete_email_file');
        if($delete_email_file){
            my $new_file = file_upload('delete_email_file');
            open(UPLOADED, "$new_file")
				or die $!;
            $delete_list = do{ local $/; <UPLOADED> };
            close(UPLOADED);
        }else{
            $delete_list = $q->param('delete_list');
        }

		my $outfile_filename = generate_rand_string() . '-' . 'remove_emails.txt';
		my $outfile = make_safer($DADA::Config::TMP . '/' . $outfile_filename);

		#DEV: encoding?
        open(my $fh, '>' . $outfile )
          or die ( "can't write to " . $outfile . ": $!" );
        print $fh $delete_list;
        close($fh);
        chmod( 0666, $outfile );

		my $new_emails = [];
		my $new_info   = [];
        ( $new_emails, $new_info ) =
          DADA::App::Guts::csv_subscriber_parse( $admin_list, $outfile_filename );

        # subscribed should give a darn if your blacklisted, or white listed, white list and blacklist only looks at unsubs. Right. Right?
        my ($subscribed, $not_subscribed, $black_listed, $not_white_listed, $invalid)
			= $lh->filter_subscribers(
				{
					#-emails => [@delete_addresses],
					-emails => $new_emails,
					-type   => $type,
				}
			);

        my $have_subscribed_addresses = 0;
           $have_subscribed_addresses = 1
            if $subscribed->[0];

        my $addresses_to_remove = [];
        push(@$addresses_to_remove, {email => $_})
            for @$subscribed;

        my $not_subscribed_addresses = [];
        push(@$not_subscribed_addresses, {email => $_})
            for @$not_subscribed;

        my $have_invalid_addresses = 0;
           $have_invalid_addresses = 1
            if $invalid->[0];

        my $invalid_addresses = [];
           push(@$invalid_addresses, {email => $_ })
            for @$invalid;

        require DADA::Template::Widgets;
        my $scrn =  DADA::Template::Widgets::wrap_screen(
			{
											  -screen => 'delete_email_screen_filtered.tmpl',
												-with           => 'admin', 
												-wrapper_params => { 
													-Root_Login => $root_login,
													-List       => $list,  
												},
											
                                              -vars   => {
                                                            have_subscribed_addresses => $have_subscribed_addresses,
                                                            addresses_to_remove       => $addresses_to_remove,
                                                            not_subscribed_addresses  => $not_subscribed_addresses,
                                                            have_invalid_addresses    => $have_invalid_addresses,
                                                            invalid_addresses         => $invalid_addresses,

                                                            type                        => $type,
                                                            type_title                  => $type_title,

                                                        },
                                             });

        e_print($scrn);
    }
}




sub subscription_options {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'subscription_options'
    );
    $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    my @d_quota_values = qw(1 10 25 50 100 150 200 250 300 350 400 450 500 600
      700 800 900 1000 1500 2000 2500 3000 3500 4000 4500
      5000 5500 6000 6500 7000 7500 8000 8500 9000 9500
      10000 11000 12000 13000 14000 15000 16000 17000
      18000 19000 20000 30000 40000 50000 60000 70000
      80000 90000 100000 200000 300000 400000 500000
      600000 700000 800000 900000 1000000
    );

    $DADA::Config::SUBSCRIPTION_QUOTA = undef
      if strip($DADA::Config::SUBSCRIPTION_QUOTA) eq '';
    my @quota_values;

    if ( defined($DADA::Config::SUBSCRIPTION_QUOTA) ) {

        for (@d_quota_values) {
            if ( $_ < $DADA::Config::SUBSCRIPTION_QUOTA ) {
                push( @quota_values, $_ );
            }
        }
        push( @quota_values, $DADA::Config::SUBSCRIPTION_QUOTA );

    }
    else {
        @quota_values = @d_quota_values;
    }

    # Now that's a weird line (now)
    unshift( @quota_values, $li->{subscription_quota} );

    if ( !$process ) {

        my $subscription_quota_menu = $q->popup_menu(
            -name     => 'subscription_quota',
            '-values' => [@quota_values],
            -default  => $li->{subscription_quota},
        );

        my @list_amount = (
            3, 5, 10,   25,   50,    100,   150,   200,   250,   300,
            350,  400,  450,   500,   550,   600,   650,   700,
            750,  800,  850,   900,   950,   1000,  2000,  3000,
            4000, 5000, 10000, 15000, 20000, 25000, 50000, 100000
        );
        my $vlsn_menu = $q->popup_menu(
            -name    => 'view_list_subscriber_number',
            -values  => [@list_amount],
            -default => $li->{view_list_subscriber_number}
        );


        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'subscription_options_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -vars => {
                    screen                       => 'subscription_options',
                    title                        => 'Subscriber Options',
                    done                         => $done,
                    subscription_quota_menu      => $subscription_quota_menu,
					vlsn_menu                    => $vlsn_menu, 
					SUBSCRIPTION_QUOTA           => $DADA::Config::SUBSCRIPTION_QUOTA, 
                    commified_subscription_quota => commify(int($DADA::Config::SUBSCRIPTION_QUOTA)),
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        e_print($scrn);
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    view_list_subscriber_number          => undef,
                    use_subscription_quota               => 0,
                    subscription_quota                   => undef,
                    black_list                           => 0,
                    add_unsubs_to_black_list             => 0,
                    allow_blacklisted_to_subscribe       => 0,
                    allow_admin_to_subscribe_blacklisted => 0,
                    enable_white_list                    => 0,
					invites_check_for_already_invited    => 0, 
					invites_prohibit_reinvites           => 0,
                }
            }
        );
        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?f=subscription_options&done=1' );
    }

}




sub view_archive {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_archive'
    );

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $admin_list } );
    my $li = $ls->get;

    # let's get some info on this archive, shall we?
    require DADA::MailingList::Archives;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    my $entries = $archive->get_archive_entries();

    #if we don't have nothin, print the index,
    unless ( defined($id) ) {

        my $start = int( $q->param('start') ) || 0;

        if (!$c->profile_on && $c->cached( $list . '.admin.view_archive.index.' . $start  . '.scrn' ) ) {
            $c->show( $list . '.admin.view_archive.index.' . $start . '.scrn');
            return;
        }

        my $ht_entries = [];

     #reverse if need be
     #@$entries = reverse(@$entries) if($li->{sort_archives_in_reverse} eq "1");

        my $th_entries = [];

        my ( $begin, $stop ) = $archive->create_index($start);
        my $i;
        my $stopped_at = $begin;

        my @archive_nums;
        my @archive_links;

        for ( $i = $begin ; $i <= $stop ; $i++ ) {

            next if !defined( $entries->[$i] );

            my $entry = $entries->[$i];

            #for $entry (@$entries){
            my ( $subject, $message, $format, $raw_msg ) =
              $archive->get_archive_info($entry);

            my $pretty_subject = pretty($subject);

            my $header_from = undef;
            if ($raw_msg) {
                $header_from =
                  $archive->get_header( -header => 'From', -key => $entry );

                # The SPAM ME NOT Encoding's a little fucked for this, anyways,
                # We should only encode the actual address, anyways. Hmm...
                # $header_from    = spam_me_not_encode($header_from);
            }
            else {
                $header_from = '-';
            }

            my $date = date_this(
                -Packed_Date => $entry,
                -All         => 1
            );

            my $message_blurb = $archive->message_blurb( -key => $entry );
            $message_blurb =~ s/\n|\r/ /g;

            push(
                @$ht_entries,

                {
                    id            => $entry,
                    date          => $date,
                    S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL,
                    subject       => $pretty_subject,
                    from          => $header_from,
                    message_blurb => $message_blurb,
                }
            );

            $stopped_at++;

        }

        my $index_nav = $archive->create_index_nav( $stopped_at, 1 );

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'view_archive_index_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
                -list   => $list,
                -vars   => {

                    screen     => 'view_archive',
                    title      => 'View Archive',
                    index_list => $ht_entries,
                    list_name  => $li->{list_name},
                    index_nav  => $index_nav,

                },
				-expr => 1, 
            }
        );
        e_print($scrn);

		if(!$c->profile_on){ # that's it?
        	$c->cache( $list . '.admin.view_archive.index.' . $start  . '.scrn', \$scrn );
		}
        return;

    }
    else {

        #check to see if $id is a real id key
        my $entry_exists = $archive->check_if_entry_exists($id);

        if ( $entry_exists <= 0 ) {
            user_error( -List => $list, -Error => "no_archive_entry" );
            return;
        }

        my $scrn = '';

        my ( $subject, $message, $format ) = $archive->get_archive_info($id);

        my $cal_date = date_this(
            -Packed_Date => $archive->_massaged_key($id),
            -All         => 1
        );

        my $nav_table = $archive->make_nav_table(
            -Id       => $id,
            -List     => $li->{list},
            -Function => "admin"
        );

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'view_archive_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},

                -vars   => {
                    id      => $id,
                    subject => $subject,
                    date    => $cal_date,
                    can_display_message_source =>
                      $archive->can_display_message_source,
                    nav_table => $nav_table,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        e_print($scrn);

        return;

    }
}





sub display_message_source {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'display_message_source'
    );

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    require DADA::MailingList::Archives;

    my $la = DADA::MailingList::Archives->new( { -list => $list } );

    if ( $la->check_if_entry_exists( $q->param('id') ) ) {

        if ( $la->can_display_message_source ) {

            print $q->header('text/plain');
            $la->print_message_source( \*STDOUT, $q->param('id') );

        }
        else {

            user_error(
                -List  => $list,
                -Error => "no_support_for_displaying_message_source"
            );
            return;
        }

    }
    else {

        user_error( -List => $list, -Error => "no_archive_entry" );
        return;
    }

}

sub delete_archive {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'delete_archive'
    );

    $list = $admin_list;
    my @address = $q->param("address");

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    require DADA::MailingList::Archives;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    $archive->delete_archive(@address);

    print $q->redirect(
        -uri => "$DADA::Config::S_PROGRAM_URL?flavor=view_archive" );

}





sub purge_all_archives {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'purge_all_archives');

    $list = $admin_list;

    require  DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new({-list => $list});

    require  DADA::MailingList::Archives;
    my $ah = DADA::MailingList::Archives->new({-list => $list});

    $ah->delete_all_archive_entries();

    print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=view_archive');

}

sub archive_options {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'archive_options'
    );

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;


        if(!$process){

			my $can_use_captcha = 0;
			eval { require DADA::Security::AuthenCAPTCHA; };
			if(!$@){
				$can_use_captcha = 1;
			}
		
		require DADA::Template::Widgets;
        my $scrn =  DADA::Template::Widgets::wrap_screen(
			{
											  -screen => 'archive_options_screen.tmpl',
											-with           => 'admin', 
											-wrapper_params => { 
												-Root_Login => $root_login,
												-List       => $list,  
											},
											
                                              -expr   => 1,
                                              -vars   => {
													screen                    => 'archive_options',
													title                     => 'Archive Options',
                                                    list                      => $list,
                                                    done                      => $done,
                                                    can_use_captcha           => $can_use_captcha,
                                                    CAPTCHA_TYPE              => $DADA::Config::CAPTCHA_TYPE,

                                                   },
												-list_settings_vars_param => {
													-list    => $list,
													-dot_it => 1,
												},

                                             });
		e_print($scrn);
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    show_archives                          => 0,
                    archives_available_only_to_subscribers => 0,
                    archive_messages                       => 0,
                    archive_subscribe_form                 => 0,
                    archive_search_form                    => 0,
                    archive_send_form                      => 0,
                    captcha_archive_send_form              => 0,
                }
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?flavor=archive_options&done=1' );
    }
}


sub adv_archive_options {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'adv_archive_options'
    );

    $list = $admin_list;

    require  DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    require  DADA::MailingList::Archives;
    my $la = DADA::MailingList::Archives->new( { -list => $list } );

    if ( !$process ) {

        my @index_this = (
            $li->{archive_index_count},
            1 .. 10, 15, 20, 25, 30, 40, 50, 75, 100
        );

        my $archive_index_count_menu = $q->popup_menu(
            -name  => 'archive_index_count',
            -id    => 'archive_index_count',
            -value => [@index_this]
        );

        my $ping_sites = [];
        for (@DADA::Config::PING_URLS) {

            push(
                @$ping_sites,
                {

                    ping_url => $_
                }
            );
        }

        my $can_use_xml_rpc = 1;

        eval { require XMLRPC::Lite };
        if ($@) {
            $can_use_xml_rpc = 0;
        }

        my $can_use_html_scrubber = 1;

        eval { require HTML::Scrubber; };
        if ($@) {
            $can_use_html_scrubber = 0;
        }

        my $can_use_recaptcha_mailhide = 0;


        eval { require Captcha::reCAPTCHA::Mailhide; };

        if ( !$@ ) {

            if (
                !defined(
                    $DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{public_key}
                )
                || !defined(
                    $DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{private_key}
                )
              )
            {
                warn
'You need to configure Recaptcha Mailhide in your configuration.';
            }

            $can_use_recaptcha_mailhide = 1;
        }

        my $can_use_gravatar_url = 0;
        my $gravatar_img_url     = '';
        eval { require Gravatar::URL };
        if ( !$@ ) {
            $can_use_gravatar_url = 1;
            require Email::Address;
            if ( isa_url( $li->{default_gravatar_url} ) ) {

                $gravatar_img_url = Gravatar::URL::gravatar_url(
                    email   => $ls->param('list_owner_email'),
                    default => $li->{default_gravatar_url}
                );
            }
            else {
                $gravatar_img_url = Gravatar::URL::gravatar_url(
                    email => $ls->param('list_owner_email') );
            }
        }
        else {
            $can_use_gravatar_url = 0;
        }

		require DADA::Template::Widgets;
		my $scrn =  DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'adv_archive_options_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
				-Root_Login => $root_login,
				-List       => $list,  
				},
		        -vars   => {
		            screen => 'adv_archive_options',
		            title  => 'Advanced Archive Options',

		            done                       => $done,
		            archive_index_count_menu   => $archive_index_count_menu,
		            list                       => $list,
		            ping_sites                 => $ping_sites,
		            can_use_xml_rpc            => $can_use_xml_rpc,
		            can_use_html_scrubber      => $can_use_html_scrubber,
		            can_display_attachments    => $la->can_display_attachments,
		            can_use_recaptcha_mailhide => $can_use_recaptcha_mailhide,
		            can_use_gravatar_url       => $can_use_gravatar_url,
		            gravatar_img_url           => $gravatar_img_url,

		            (
		                  ( $li->{archive_protect_email} eq 'none' )
		                ? ( archive_protect_email_none => 1, )
		                : ( archive_protect_email_none => 0, )
		            ),
		            (
		                  ( $li->{archive_protect_email} eq 'spam_me_not' )
		                ? ( archive_protect_email_spam_me_not => 1, )
		                : ( archive_protect_email_spam_me_not => 0, )
		            ),
		            (
		                (
		                    $li->{archive_protect_email} eq 'recaptcha_mailhide'
		                ) ? ( archive_protect_email_recaptcha_mailhide => 1, )
		                : ( archive_protect_email_recaptcha_mailhide => 0, )
		            ),
		        },
		        -list_settings_vars_param => {
		            -list   => $list,
		            -dot_it => 1,
		        },
		    }
		);
		e_print($scrn);
    }
    else {
	
        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    sort_archives_in_reverse      => 0,
                    archive_show_year             => 0,
                    archive_show_month            => 0,
                    archive_show_day              => 0,
                    archive_show_hour_and_minute  => 0,
                    archive_show_second           => 0,
                    archive_index_count           => 10,
                    stop_message_at_sig           => 0,
                    publish_archives_rss          => 0,
                    ping_archives_rss             => 0,
                    html_archives_in_iframe       => 0,
                    disable_archive_js            => 0,
                    style_quoted_archive_text     => 0,
                    display_attachments           => 0,
                    add_subscribe_form_to_feeds   => 0,
                    add_social_bookmarking_badges => 0,
                    archive_protect_email         => undef,
                    enable_gravatars              => 0,
                    default_gravatar_url          => '',
                }
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?flavor=adv_archive_options&done=1' );
    }
}




sub edit_archived_msg {

    require DADA::Template::HTML;
    require DADA::MailingList::Settings;

    require DADA::MailingList::Archives;

    require DADA::Mail::Send;

    require MIME::Parser;

    my $parser = new MIME::Parser;
    $parser = optimize_mime_parser($parser);

    my $skel = [];

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_archived_msg'
    );
    my $list = $admin_list;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $li = $ls->get;

    my $mh = DADA::Mail::Send->new(
        {
            -list   => $list,
            -ls_obj => $ls,
        }
    );
    my $ah = DADA::MailingList::Archives->new( { -list => $list } );

    edit_archived_msg_main();

    #---------------------------------------------------------------------#

    sub edit_archived_msg_main {

        if ( $q->param('process') eq 'prefs' ) {
            &prefs;
        }
        else {

            if ( $q->param('process') ) {
                &edit_archive;
            }
            else {
                &view;
            }
        }
    }

    sub view {

        my $D_Content_Types = [ 'text/plain', 'text/html' ];

        my %Headers_To_Edit;

        my $parser = new MIME::Parser;
        $parser = optimize_mime_parser($parser);

        my $id = $q->param('id');

        if ( !$id ) {
            print $q->redirect(
                -uri => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive' );
            exit;
        }

        if ( $ah->check_if_entry_exists($id) <= 0 ) {
            print $q->redirect(
                -uri => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive' );
            exit;
        }

        my ( $subject, $message, $format, $raw_msg ) =
          $ah->get_archive_info($id);

        # do I need this?
        $raw_msg ||= $ah->_bs_raw_msg( $subject, $message, $format );
        $raw_msg =~ s/Content\-Type/Content-type/;
        $raw_msg = safely_encode($raw_msg);

        my $entity;
        eval { $entity = $parser->parse_data($raw_msg); };

        my $form_blob = '';
        make_skeleton($entity);

        for ( split( ',', $li->{editable_headers} ) ) {
            $Headers_To_Edit{$_} = 1;
        }

        for my $tb (@$skel) {

            my @c = split( '-', $tb->{address} );
            my $bqc = $#c - 1;

            for ( 0 .. $bqc ) {
                $form_blob .=
'<div style="padding-left: 30px; border-left:1px solid #ccc">';
            }

            if ( $tb->{address} eq '0' ) {
                $form_blob .= '<table width="100%">';

                # head of the message!
                my %headers =
                  $mh->return_headers( $tb->{entity}->head->original_text );
                for my $h (@DADA::Config::EMAIL_HEADERS_ORDER) {
                    if ( $headers{$h} ) {
                        if ( $Headers_To_Edit{$h} == 1 ) {

                            $form_blob .= qq{
								<tr>
								 <td>
								  <p>
								   <label for="$h">
									$h: </label>
								  </p>
								</td>
								<td width="99%">
							};

                            if (   $DADA::Config::ARCHIVE_DB_TYPE eq 'Db'
                                && $h eq 'Content-type' )
                            {
                                push( @{$D_Content_Types}, $headers{$h} );
                                $form_blob .= $q->p(
                                    $q->popup_menu(
                                        '-values' => $D_Content_Types,
                                        -id       => $h,
                                        -name     => $h,
                                        -default  => $headers{$h}
                                    )
                                );
                            }
                            else {
                                my $value = $headers{$h};
                                if ( $ls->param('mime_encode_words_in_headers')
                                    == 1 )
                                {
                                    if ( $h =~ m/To|From|Cc|Reply\-To|Subject/ )
                                    {
                                        $value = $ah->_decode_header($value);
                                    }
                                }
                                $form_blob .= $q->p(
                                    $q->textfield(
                                        -value => $value,
                                        -id    => $h,
                                        -name  => $h,
                                        -class => 'full'
                                    )
                                );
                            }

                            $form_blob .= '</td></tr>';
                        }

                    }

                }
                $form_blob .= '</table>';
            }
            my ( $type, $subtype ) =
              split( '/', $tb->{entity}->head->mime_type );

            $form_blob .= $q->p( $q->strong('Content Type: '),
                $tb->{entity}->head->mime_type );

            if ( $tb->{body} ) {

                if (   $type =~ /^(text|message)$/
                    && $tb->{entity}->head->get('content-disposition') !~
                    m/attach/i )
                {    # text: display it...

#$q->checkbox(-name => 'delete_' . $tb->{address}, -value => 1, -label => '' ), 'Delete?', $q->br(),

                    if ( $subtype =~ /html/ && $DADA::Config::FCKEDITOR_URL ) {

                        require DADA::Template::Widgets;
                        $form_blob .= DADA::Template::Widgets::screen(
                            {
                                -screen => 'edit_archived_msg_textarea.widget',
                                -vars   => {
                                    name  => $tb->{address},
                                    value => js_enc(
                                        safely_decode(
                                            $tb->{entity}
                                              ->bodyhandle->as_string()
                                        )
                                    ),
                                }
                            }
                        );
                    }
                    else {

                        $form_blob .= $q->p(
                            $q->textarea(
                                -value => safely_decode(
                                    $tb->{entity}->bodyhandle->as_string
                                ),
                                -rows => 15,
                                -name => $tb->{address}
                            )
                        );

                    }

                }
                else {

                    $form_blob .=
                      '<div style="border: 1px solid #000;padding: 5px">';

                    my $name =
                         $tb->{entity}->head->mime_attr("content-type.name")
                      || $tb->{entity}
                      ->head->mime_attr("content-disposition.filename");

                    my $attachment_url;

                    if ($name) {
                        $attachment_url =
                            $DADA::Config::S_PROGRAM_URL
                          . '?f=file_attachment&l='
                          . $list . '&id='
                          . $id
                          . '&filename='
                          . $name
                          . '&mode=inline';
                    }
                    else {

                        $name = 'Untitled.';

                        my $m_cid = $tb->{entity}->head->get('content-id');
                        $m_cid =~ s/^\<|\>$//g;

                        $attachment_url =
                            $DADA::Config::S_PROGRAM_URL
                          . '?f=show_img&l='
                          . $list . '&id='
                          . $id . '&cid='
                          . $m_cid;

                    }

                    $form_blob .= $q->p(
                        $q->strong('Attachment: '),
                        $q->a(
                            { -href => $attachment_url, -target => '_blank' },
                            $name
                        )
                    );

                    $form_blob .= '<table style="padding:5px">';

                    $form_blob .= '<tr><td>';

                    if ( $type =~ /^image/ && $subtype =~ m/gif|jpg|jpeg|png/ )
                    {
                        $form_blob .= $q->p(
                            $q->a(
                                {
                                    -href   => $attachment_url,
                                    -target => '_blank'
                                },
                                $q->img(
                                    {
                                        -src   => $attachment_url,
                                        -width => '100'
                                    }
                                )
                            )
                        );
                    }
                    else {

#$form_blob .=  $q->p($q->a({-href => $attachment_url, -target => '_blank'}, $q->strong('Attachment: ' ), $q->a({-href => $attachment_url, -target => '_blank'}, $name)));
                    }
                    $form_blob .= '</td><td>';

                    $form_blob .= $q->p(
                        $q->checkbox(
                            -name  => 'delete_' . $tb->{address},
                            -id    => 'delete_' . $tb->{address},
                            -value => 1,
                            -label => ''
                        ),
                        $q->label(
                            { '-for' => 'delete_' . $tb->{address} },
                            'Remove From Message'
                        )
                    );
                    $form_blob .=
                      $q->p( $q->strong('Update:'),
                        $q->filefield( -name => 'upload_' . $tb->{address} ) );

                    $form_blob .= '</td></tr></table>';

                    $form_blob .= '</div>';

                }
            }

            for ( 0 .. $bqc ) {
                $form_blob .= '</div>';
            }
        }

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'edit_archived_msg.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},

                -vars   => {
                    big_blob_of_form_widgets_to_edit_an_archived_message =>
                      $form_blob,
                    can_display_message_source =>
                      $ah->can_display_message_source,
                    id   => $id,
                    done => $q->param('done'),

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,

                },
            }
        );
        e_print($scrn);

    }

    sub prefs {

        if ( $q->param('process_prefs') ) {

            my $the_id = $q->param('id');

            my $editable_headers = join( ',', $q->param('editable_header') );
            $ls->save( { editable_headers => $editable_headers } );

            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?f=edit_archived_msg&process=prefs&done=1&id='
                  . $the_id );
            exit;

        }
        else {

            my %editable_headers;
            $editable_headers{$_} = 1
              for ( split( ',', $li->{editable_headers} ) );

            my $edit_headers_menu = [];
            for (@DADA::Config::EMAIL_HEADERS_ORDER) {

                push( @$edit_headers_menu,
                    { name => $_, editable => $editable_headers{$_} } );
            }

            my $the_id = $q->param('id');
            my $done   = $q->param('done');

            require DADA::Template::Widgets;
            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'edit_archived_msg_prefs_screen.tmpl',
					-with           => 'admin', 
					-wrapper_params => { 
						-Root_Login => $root_login,
						-List       => $list,  
					},
                    -vars   => {
                        edit_headers_menu => $edit_headers_menu,
                        done              => $done,
                        id                => $the_id,
                    },
                }
            );
            e_print($scrn);
        }

    }

    sub edit_archive {

        my $id = $q->param('id');

        my $parser = new MIME::Parser;
        $parser = optimize_mime_parser($parser);

        my ( $subject, $message, $format, $raw_msg ) =
          $ah->get_archive_info($id);

        $raw_msg ||= $ah->_bs_raw_msg( $subject, $message, $format );
        $raw_msg =~ s/Content\-Type/Content-type/;
        $raw_msg = safely_encode($raw_msg);

        my $entity;

        eval { $entity = $parser->parse_data($raw_msg) };

        my $throwaway = undef;

        ( $entity, $throwaway ) = edit($entity);

        # not sure if this, "if" is needed.
        if ( $DADA::Config::ARCHIVE_DB_TYPE eq 'Db' ) {
            $ah->set_archive_info(
                $id,
                $entity->head->get( 'Subject', 0 ),
                undef,
                $entity->head->get( 'Content-type', 0 ),
                safely_decode( $entity->as_string )
            );
        }
        else {

            $ah->set_archive_info( $id, $entity->head->get( 'Subject', 0 ),
                undef, undef, safely_decode( $entity->as_string ) );
        }

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?f=edit_archived_msg&id='
              . $id
              . '&done=1' );

    }

    sub make_skeleton {
        my ( $entity, $name ) = @_;
        defined($name) or $name = "0";

        my $IO;

        # Output the body:
        my @parts = $entity->parts;
        if (@parts) {

            push( @$skel, { address => $name, entity => $entity } );

            # multipart...
            my $i;
            for $i ( 0 .. $#parts ) {    # dump each part...
                make_skeleton( $parts[$i], ( "$name\-" . ($i) ) );
            }

        }
        else {                               # single part...
            push( @$skel, { address => $name, entity => $entity, body => 1 } );

        }
    }

    sub edit {

        my ( $entity, $name ) = @_;
        defined($name) or $name = "0";
        my $IO;

        my %Headers_To_Edit;

        if ( $name eq '0' ) {

            for ( split( ',', $li->{editable_headers} ) ) {
                $Headers_To_Edit{$_} = 1;
            }

            require DADA::App::FormatMessages;
            my $fm = DADA::App::FormatMessages->new( -List => $list );

            for my $h (@DADA::Config::EMAIL_HEADERS_ORDER) {
                if ( $Headers_To_Edit{$h} == 1 ) {
                    my $value = $q->param($h);

                    # Dum, what to do here?
                    if ( $h =~ m/To|From|Cc|Reply\-To|Subject/ ) {
                        $value = $fm->_encode_header( $h, $value )
                          if $fm->im_encoding_headers;
                    }
                    $entity->head->replace( $h, $value );
                }
            }
        }

        my @parts = ();
        if ( defined($entity) ) {
            @parts = $entity->parts;
        }
        else {

            #...
        }

        if (@parts) {

            my %ditch = ();

            # multipart...
            my $i;
            for $i ( 0 .. $#parts ) {
                my $name_is;
                ( $parts[$i], $name_is ) =
                  edit( $parts[$i], ( "$name\-" . ($i) ) );

                if ( $q->param( 'delete_' . $name_is ) == 1 ) {
                    $ditch{$i} = 1;

                }
                else {
                    $ditch{$i} = 0;
                }
            }

            my @new_parts;
            my $ii;
            for $ii ( 0 .. $#parts ) {
                if ( $ditch{$ii} == 1 ) {

                    # don't push it.
                }
                else {

                    push( @new_parts, $parts[$ii] );
                }
            }

            $entity->parts( \@new_parts );

            $entity->sync_headers(
                'Length'      => 'COMPUTE',
                'Nonstandard' => 'ERASE'
            );

        }
        else {
            if ( $q->param( 'delete_' . $name ) == 1 ) {

                # Well, just leave it alone!
                return ( $entity, $name );
            }
            else {

                # Uh, this means it's some sort of text, apparrently.
                my $content = $q->param($name);
                $content =~ s/\r\n/\n/g;
                if ($content) {

                    # DEV: encoding?
                    my $body = $entity->bodyhandle;
                    my $io   = $body->open('w');
                    $io->print($content);
                    $io->close;
                }

                my $cid;
                $cid = $entity->head->get('content-id') || undef;
                if ( $q->param( 'upload_' . $name ) ) {
                    $entity = get_from_upload( $name, $cid, $entity->head->get('content-disposition') );
                }

                $entity->sync_headers(
                    'Length'      => 'COMPUTE',
                    'Nonstandard' => 'ERASE'
                );

                return ( $entity, $name );
            }
        }

        return ( $entity, $name );

    }

    sub get_from_upload {

        my $name        = shift;
        my $cid         = shift;
		my $disposition = shift || 'attachment';

        my $filename = file_upload( 'upload_' . $name );
        my $data;

        my $nice_filename = $q->param( 'upload_' . $name );

        require MIME::Entity;
        my $ent = MIME::Entity->build(
            Path        => $filename,
            Filename    => $nice_filename,
            Encoding    => "base64",
            Disposition => $disposition,
            Type        => find_attachment_type($filename),
            Id          => $cid,
        );
        return $ent;

    }

}





sub html_code {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'html_code');
    $list = $admin_list;

    require DADA::Template::Widgets;
    my $scrn =  DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'html_code_screen.tmpl',
			-with           => 'admin', 
			-wrapper_params => { 
				-Root_Login => $root_login,
				-List       => $list,  
			},
			-vars              => {
				screen             => 'html_code',
				list               => $list,
				subscription_form  => DADA::Template::Widgets::subscription_form({-list => $list, -ignore_cgi => 1}),
			}
		}
	);
    e_print($scrn);

}



sub edit_template {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_template'
    );
    $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    require DADA::Template::Widgets;
    my $raw_template     = DADA::Template::HTML::default_template();
    my $default_template = default_template();

    if ( !$process ) {
		my $content_tag_found_in_template         = 0; 
		my $content_tag_found_in_url_template     = 0; 
		my $content_tag_found_in_default_template = 0; 
		
		my $content_tag = quotemeta('<!-- tmpl_var content -->');
		
		if($raw_template =~ m/$content_tag/){ 
			$content_tag_found_in_default_template = 1; 
		}
		
		
		
        my $edit_this_template = $default_template . "\n";
        if(check_if_template_exists( -List => $list ) >= 1) { 
			$edit_this_template = open_template( -List => $list ) . "\n"
    	}
		if($edit_this_template =~ m/$content_tag/){ 
			$content_tag_found_in_template = 1; 
		}
		

        my $get_template_data_from_default_template = 0;
        $get_template_data_from_default_template = 1
          if $li->{get_template_data} eq 'from_default_template';

        my $get_template_data_from_template_file = 0;
        $get_template_data_from_template_file = 1
          if $li->{get_template_data} eq 'from_template_file';

        my $get_template_data_from_url = 0;
        $get_template_data_from_url = 1
          if $li->{get_template_data} eq 'from_url';

        my $can_use_lwp_simple;
        eval { require LWP::Simple; };
        $can_use_lwp_simple = 1
          if !$@;

        my $template_saved = 0;
        if ( -e $DADA::Config::TEMPLATES . '/' . $list . '.template' ) {
            $template_saved = 1;
        }
        my $template_url_check = 1;

        if ( $get_template_data_from_url == 1 ) {

            if ( $can_use_lwp_simple == 1 ) {
				eval { $LWP::Simple::ua->agent('Mozilla/5.0 (compatible; ' . $DADA::CONFIG::PROGRAM_NAME . ')'); };
                if ( LWP::Simple::get( $li->{url_template} ) ) {
					my $tmp_tmpl = LWP::Simple::get( $li->{url_template}); 
					if($tmp_tmpl =~ m/$content_tag/){ 
						$content_tag_found_in_url_template = 1; 
					}
				}
                else {

                    $template_url_check = 0;

                }
            }
        }
        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'edit_template_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					screen                                  => 'edit_template',
					done                                    => $done,
					edit_this_template                      => $edit_this_template,					
					get_template_data_from_url              => $get_template_data_from_url,
					get_template_data_from_template_file    => $get_template_data_from_template_file,
					get_template_data_from_default_template => $get_template_data_from_default_template,
					can_use_lwp_simple                      => $can_use_lwp_simple,
					default_template                        => $default_template,
					template_url_check                      => $template_url_check,
					template_saved                          => $template_saved,
					content_tag_found_in_template           => $content_tag_found_in_template, 
					content_tag_found_in_url_template       => $content_tag_found_in_url_template, 
					content_tag_found_in_default_template   => $content_tag_found_in_default_template, 
					# I don't think this is directly used: 
					#get_template_data                       => $li->{get_template_data},

				},
				-list_settings_vars_param =>
				{
					-list                     => $list,
					-dot_it                   => 1,
				},
			}
		);
		e_print($scrn);
		
    }
    else {

        if ( $process eq "preview template" ) {

            my $template_info;
            my $test_header;
            my $test_footer;

            if ( $q->param('get_template_data') eq 'from_default_template' ) {
                $template_info = $raw_template;
            }
            elsif ( $q->param('get_template_data') eq 'from_url' ) {
                eval { require LWP::Simple; };
                if ( !$@ ) {
					eval { $LWP::Simple::ua->agent('Mozilla/5.0 (compatible; ' . $DADA::CONFIG::PROGRAM_NAME . ')'); };
                    $template_info =
                      LWP::Simple::get( $q->param('url_template') );
                }
            }
            else {
                $template_info = $q->param("template_info");
			}
			
			require DADA::Template::Widgets;
			my $scrn = DADA::Template::Widgets::wrap_screen(
					{
						-screen => 'preview_template.tmpl',
						-with   => 'list', 
						-wrapper_params => { 
							-data => \$template_info, 
						},
						-vars => { 
							title => 'Preview', 
						},
						-list_settings_vars_param => {
							-list    => $list,
							-dot_it  => 1,
						},
					}
			);
			e_print($scrn);
        }
        else {

            my $template_info = $q->param("template_info");

            $ls->save_w_params(
                {
                    -associate => $q,
                    -settings  => {
                        apply_list_template_to_html_msgs => 0,
                        url_template                     => '',
                        get_template_data                => '',
                    }
                }
            );

            make_template( { -List => $list, -Template => $template_info } );

            $c->flush;
            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=edit_template&done=1' );
            return;
        }
    }
}




sub back_link {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'back_link');

    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    if(!$process){

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'back_link_screen.tmpl',
				-list   => $list,
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					screen       => 'back_link',
					done         => (($q->param('done')) ? ($q->param('done')) : (0)),
				},
				-list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
			}
		);
		e_print($scrn);

    }else{

        $ls->save_w_params(
			{
				-associate => $q, 
				-settings  => { 
					website_name  =>   '',
                   	website_url   =>   '',
                 }
			}
		);

        print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=back_link&done=1');
    }
}




sub edit_type {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_type'
    );
    $list = $admin_list;

    require DADA::Template::Widgets;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    # Backwards Compatibility!
    for (
        qw(
        confirmation_message
        subscribed_message
        unsub_confirmation_message
        unsubscribed_message
        mailing_list_message
        mailing_list_message_html
        send_archive_message
        send_archive_message_html
        you_are_already_subscribed_message
        email_your_subscribed_msg
        )
      )
    {
        my $m = $li->{$_};
        DADA::Template::Widgets::dada_backwards_compatibility( \$m );
        $li->{$_} = $m;
    }

    require DADA::App::FormatMessages;
    my $dfm = DADA::App::FormatMessages->new( -List => $list );

    if ( !$process ) {

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'edit_type_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
                -list   => $list,
                -vars   => {
                    screen => 'edit_type',
                    title  => 'Email Templates',
                    done   => $done,

                    unsub_link_found_in_pt_mlm => $dfm->can_find_unsub_link(
                        { -str => $li->{mailing_list_message} }
                    ),
                    unsub_link_found_in_html_mlm => $dfm->can_find_unsub_link(
                        { -str => $li->{mailing_list_message_html} }
                    ),

                    message_body_tag_found_in_pt_mlm => $dfm->can_find_message_body_tag(
                        { -str => $li->{mailing_list_message} }
                    ),
                    message_body_tag_found_in_html_mlm => $dfm->can_find_message_body_tag(
                        { -str => $li->{mailing_list_message_html} }
                    ),


                    sub_confirm_link_found_in_confirmation_message =>
                      $dfm->can_find_sub_confirm_link(
                        { -str => $li->{confirmation_message} }
                      ),

                    unsub_link_found_in_pt_subscribed_by_list_owner_msg => $dfm->can_find_unsub_link(
                        { -str => $li->{subscribed_by_list_owner_message} }
                    ),


                    sub_confirm_link_found_in_pt_invite_msg =>
                      $dfm->can_find_sub_confirm_link(
                        { -str => $li->{invite_message_text} }
                      ),
                    sub_confirm_link_found_in_html_invite_msg =>
                      $dfm->can_find_sub_confirm_link(
                        { -str => $li->{invite_message_html} }
                      ),
                    unsub_confirm_link_found_in_unsub_confirmation_message =>
                      $dfm->can_find_unsub_confirm_link(
                        { -str => $li->{unsub_confirmation_message} }
                      ),
                },
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1, },
            }
        );
        e_print($scrn);

    }
    else {

        for (qw(
            subscribed_message_subject
            subscribed_message

			subscribed_by_list_owner_message_subject
			subscribed_by_list_owner_message
			
			unsubscribed_by_list_owner_message_subject
			unsubscribed_by_list_owner_message
			
            unsubscribed_message_subject
            unsubscribed_message
            confirmation_message_subject
            confirmation_message
            unsub_confirmation_message_subject
            unsub_confirmation_message
            mailing_list_message_from_phrase
            mailing_list_message_to_phrase
            mailing_list_message_subject
            mailing_list_message
            mailing_list_message_html
            send_archive_message_subject
            send_archive_message
            send_archive_message_html
            you_are_already_subscribed_message_subject
            you_are_already_subscribed_message
			you_are_not_subscribed_message_subject
			you_are_not_subscribed_message
            invite_message_from_phrase
            invite_message_to_phrase
            invite_message_text
            invite_message_html
            invite_message_subject
          ))
        {
          
            # a very odd place to put this, but, hey,  easy enough.
            if ( $q->param('revert') ) {
                $q->param( $_, '' );
            }
			else { 
				  my $tmp_setting = $q->param($_);
		             $tmp_setting =~ s/\r\n/\n/g;
		          $q->param( $_, $tmp_setting );
			}
        }

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    confirmation_message_subject               => undef,
                    confirmation_message                       => undef,
                    subscribed_message_subject                 => undef,
                    subscribed_message                         => undef,
					subscribed_by_list_owner_message_subject   => undef, 
					subscribed_by_list_owner_message           => undef,
					unsubscribed_by_list_owner_message_subject => undef, 
					unsubscribed_by_list_owner_message         => undef,  
                    unsubscribed_message_subject               => undef,
                    unsubscribed_message                       => undef,
                    unsub_confirmation_message_subject         => undef,
                    unsub_confirmation_message                 => undef,
                    mailing_list_message_from_phrase           => undef,
                    mailing_list_message_to_phrase             => undef,
                    mailing_list_message_subject               => undef,
                    mailing_list_message                       => undef,
                    mailing_list_message_html                  => undef,
                    send_archive_message_subject               => undef,
                    send_archive_message                       => undef,
                    send_archive_message_html                  => undef,
                    you_are_already_subscribed_message_subject => undef,
                    you_are_already_subscribed_message         => undef,
					you_are_not_subscribed_message_subject     => undef, 
					you_are_not_subscribed_message             => undef, 
                    invite_message_from_phrase                 => undef,
                    invite_message_to_phrase                   => undef,
                    invite_message_text                        => undef,
                    invite_message_html                        => undef,
                    invite_message_subject                     => undef,
                    enable_email_template_expr                 => 0,
                }
            }
        );

        print $q->redirect(
            -uri => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_type&done=1' );

    }
}

sub edit_html_type {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_html_type'
    );
    $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    # Backwards Compatibility!
    require DADA::Template::Widgets;
    for (
        qw(
        html_confirmation_message
        html_unsub_confirmation_message
        html_subscribed_message
        html_unsubscribed_message

        )
      )
    {
        my $m = $li->{$_};
        DADA::Template::Widgets::dada_backwards_compatibility( \$m );
        $li->{$_} = $m;
    }

    if ( !$process ) {

        require DADA::Template::Widgets;
		my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'edit_html_type_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-list   => $list,
		        -list   => $list,
		        -vars   => {
		            screen                    => 'edit_html_type',
		            title                     => 'HTML Screen Templates',
		            done                      => $done,
				},
	            -list_settings_vars_param => {
	                -list   => $list,
	                -dot_it => 1,
	            },

		    }
		);
		e_print($scrn);

    }
    else{
	
        for (
            qw(
            html_confirmation_message
            html_unsub_confirmation_message
            html_subscribed_message
            html_unsubscribed_message
            )
          )
        {
            my $tmp_setting = $q->param($_);
            $tmp_setting =~ s/\r\n/\n/g;
            $q->param( $_, $tmp_setting );
        }

        $ls->save_w_params(
            {
                -associate => $q,
                -settings => {
                    html_confirmation_message       => '',
                    html_unsub_confirmation_message => '',
                    html_subscribed_message         => '',
                    html_unsubscribed_message       => '',
                }
            }
        );

        print $q->redirect( -uri =>
              "$DADA::Config::S_PROGRAM_URL?flavor=edit_html_type&done=1" );
    }
}




sub manage_script {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'manage_script');

       $list                = $admin_list;
    my $more_info           = $q->param('more_info') || 0;
    my $sendmail_locations    =`whereis sendmail`;
	my $curl_location         = `which curl`;
	my $wget_location         = `which wget`;

    my $at_incs             = [];

	for(@INC){
		if($_ !~ /^\./){
    		push(@$at_incs, {name => $_});
		}
    }

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'manage_script_screen.tmpl',
				-with   => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-list   => $list,
				-vars   => {
					more_info          => $more_info,
					smtp_server        => $li->{smtp_server},
					server_software    => $q->server_software(),
					operating_system   => $^O,
					perl_version       => $],
					sendmail_locations => $sendmail_locations,
					at_incs            => $at_incs,
					list_owner_email   => $li->{list_owner_email},
					curl_location      => $curl_location,
					wget_location      => $wget_location,
				},
			}
		);

	e_print($scrn);

}




sub feature_set {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'feature_set');
    $list = $admin_list;

    require  DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    require DADA::Template::Widgets::Admin_Menu;

    if(!$process){

    	my $feature_set_menu = DADA::Template::Widgets::Admin_Menu::make_feature_menu($li);
        require DADA::Template::Widgets;
        my $scrn =  DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'feature_set_screen.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				

                                              -vars   => {
													   screen           => 'feature_set',
                                                       done             => (defined($done)) ? 1 : 0,
                                                       feature_set_menu => $feature_set_menu,
                                                       disabled_screen_view_hide     => ($li->{disabled_screen_view} eq 'hide')     ? 1 : 0,
                                                       disabled_screen_view_grey_out => ($li->{disabled_screen_view} eq 'grey_out') ? 1 : 0,
                                                      },
                                             });
		e_print($scrn);

    }else{

        my @params = $q->param;
        my %param_hash;
        for(@params){
            next if $_ eq 'disabled_screen_view'; # special case.
            $param_hash{$_} = $q->param($_);
        }

            my $save_set = DADA::Template::Widgets::Admin_Menu::create_save_set(\%param_hash);

            my $disabled_screen_view = $q->param('disabled_screen_view');

            $ls->save({
                        admin_menu           => $save_set,
                        disabled_screen_view => $disabled_screen_view,
                      });

            print $q->redirect(-uri=>"$DADA::Config::S_PROGRAM_URL?flavor=feature_set&done=1");
        }
}



sub list_cp_options {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_cp_options'
    );
    $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    if ( !$process ) {


   require DADA::Template::Widgets;
   my $scrn =   DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'list_cp_options.tmpl',
			-with           => 'admin', 
			-wrapper_params => { 
				-Root_Login => $root_login,
				-List       => $list,  
			},
			
                                               -list   => $list,
                                               -vars   => {
													screen    => 'list_cp_options',
													done      => xss_filter($q->param('done')),
												},
											-list_settings_vars       => $li,
                                            -list_settings_vars_param => {-dot_it => 1},
                                           });

		e_print($scrn);
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    enable_fckeditor                 => 0,
					show_message_body_plaintext_ver  => 0, 
					show_message_body_html_ver       => 0,
                }
            }
        );

        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
              . '?flavor=list_cp_options&done=1' );
    }
}




sub profile_fields {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'profile_fields');

     $list  = $admin_list;

	require DADA::ProfileFieldsManager;
	my $pfm = DADA::ProfileFieldsManager->new;

	require DADA::Profile::Fields;
	my $dpf = DADA::Profile::Fields->new;

	if($dpf->can_have_subscriber_fields == 0){
	     require DADA::Template::Widgets;
	     my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'profile_fields.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				-vars   => {
					screen                     => 'profile_fields',
					title                      => 'Profile Fields',
					can_have_subscriber_fields => $dpf->can_have_subscriber_fields,

				},
			}
		);
		e_print($scrn);
		return;
	}


	 # But, if we do....
	 my $subscriber_fields = $pfm->fields;

	 my $fields_attr = $pfm->get_all_field_attributes;

     my $ls = DADA::MailingList::Settings->new({-list => $list});
     my $li = $ls->get();

     my $field_errors = 0;
     my $field_error_details = {
            field_blank            => 0,
            field_name_too_long    => 0,
            slashes_in_field_name  => 0,
            weird_characters       => 0,
            quotes                 => 0,
            field_exists           => 0,
            spaces                 => 0,
            field_is_special_field => 0,
     };


     my $edit_field           = xss_filter($q->param('edit_field'));

	 my $field                = '';
	 my $fallback_field_value = '';
	 my $field_label          = '';

	 if($edit_field == 1){
				$field                = xss_filter($q->param('field'));
				$fallback_field_value = $fields_attr->{$field}->{fallback_value};
				$field_label          = $fields_attr->{$field}->{label};
	 }
	else {
		$field                = xss_filter($q->param('field'));
		$fallback_field_value = xss_filter($q->param('fallback_field_value'));
		$field_label          = xss_filter($q->param('field_label'));
	}

	 if(!$root_login && defined($process)){
         die "You need to log into the list with the root pass to do that!";
     }

	 if($process eq 'edit_field_order'){
		my $dir = $q->param('direction') || 'down';
		$pfm->change_field_order(
			{
				-field     => $field,
				-direction => $dir,
			}
		);
		$c->flush;
		print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=profile_fields'});
        return;

	 }
     if($process eq 'delete_field'){

		###
        $pfm->remove_field({-field => $field});
        $c->flush;
        print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=profile_fields;deletion=1;working_field=' . $field . ';field_changes=1'});
        return;
     }
     elsif($process eq 'add_field'){


        ($field_errors, $field_error_details) = $pfm->validate_field_name(
			{
				-field => $field
			}
		);

        if($field_errors == 0){

            $pfm->add_field(
				{
					-field => $field,
					-fallback_value => $fallback_field_value,
					-label          => $field_label,
				}
			);

            print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=profile_fields;addition=1;working_field=' . $field . ';field_changes=1'});
            $c->flush;
			return;
         }
         else {
            # Else, I guess for now, we'll show the template and have the errors print out there...
            $field_errors = 1;
         }
     }
	 elsif($process eq 'edit_field'){

		my $orig_field = xss_filter($q->param('orig_field'));

		#old name			# new name
		if($orig_field eq $field){
		 	($field_errors, $field_error_details) = $pfm->validate_field_name({-field => $field, -skip => [qw(field_exists)]});
		}
		else {
			($field_errors, $field_error_details) = $pfm->validate_field_name({-field => $field});
		}
		 if($field_errors == 0){

             $pfm->remove_field_attributes({-field => $orig_field});

			if($orig_field eq $field){
				# ...
			}
			else {
            	$pfm->edit_field({-old_name => $orig_field ,-new_name => $field});
			}
			$pfm->save_field_attributes(
				{
					-field 			=> $field,
					-fallback_value => $fallback_field_value,
					-label          => $field_label,
				}
			);
			$c->flush;
			print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=profile_fields;edited=1;working_field=' . $field . ';field_changes=1'});
             return;
		}
         else {
            # Else, I guess for now, we'll show the template and have the errors print out there...
            $field_errors = 1;
			$edit_field   = 1;
			$field        = xss_filter($q->param('orig_field'));
         }
	 }


	 my $can_move_columns = ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql') ? 1 : 0;

     my $named_subscriber_fields = [];


     for(@$subscriber_fields){
        push(
			@$named_subscriber_fields,
				{
					field            => $_,
					fallback_value   => $fields_attr->{$_}->{fallback_value},
					label            => $fields_attr->{$_}->{label},
					root_login       => $root_login,
					can_move_columns => $can_move_columns,
				}
			);
     }
        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'profile_fields.tmpl',
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
				
                                               -vars   => {

													   screen                           => 'profile_fields',
													   title                            => 'Profile Fields',

													   edit_field                       => $edit_field,
                                                       fields                           => $named_subscriber_fields,

                                                       field_errors                     => $field_errors,
                                                       field_error_field_blank            => $field_error_details->{field_blank},
                                                       field_error_field_name_too_long    => $field_error_details->{field_name_too_long},
                                                       field_error_slashes_in_field_name  => $field_error_details->{slashes_in_field_name},
                                                       field_error_weird_characters       => $field_error_details->{weird_characters},
                                                       field_error_quotes                 => $field_error_details->{quotes},
                                                       field_error_field_exists           => $field_error_details->{field_exists},
                                                       field_error_spaces                 => $field_error_details->{spaces},
                                                       field_error_field_is_special_field => $field_error_details->{field_is_special_field},

                                                       field                            => $field,
                                                       fallback_field_value             => $fallback_field_value,
                                                       field_label                      => $field_label,

													   can_have_subscriber_fields       => $dpf->can_have_subscriber_fields,

                                                       root_login                       => $root_login,

                                                       HIDDEN_SUBSCRIBER_FIELDS_PREFIX  => $DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX,

														using_SQLite                     => $DADA::Config::SUBSCRIBER_DB_TYPE eq 'SQLite' ? 1 : 0,
														field_changes                    => xss_filter($q->param('field_changes')), 
														working_field                    => xss_filter($q->param('working_field')),
														deletion                         => xss_filter($q->param('deletion')),
														addition                         => xss_filter($q->param('addition')),
														edited                           => xss_filter($q->param('edited')),

														can_move_columns                 => $can_move_columns,

													},
                                             });
		e_print($scrn);

}




sub subscribe {

    my %args = (-html_output => 1, @_);

    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
       $das->subscribe(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );

}




sub subscribe_flash_xml {

    if($q->param('test') == 1){
        print $q->header('text/plain');
    }else{
        print $q->header('application/x-www-form-urlencoded');
    }

    if(check_if_list_exists(-List => $list) == 0){
        #note! This should be handled in the subscription_check_xml() method,
        # but this object *also* checks to see if a list is real. Chick/Egg
        e_print('<subscription><email>' . $email . '</email><status>0</status><errors><error>no_list</error></errors></subscription>');
    }else{
        my $lh = DADA::MailingList::Subscribers->new({-list => $list});
        my ($xml, $status, $errors) =  $lh->subscription_check_xml(
											{
												-email => $email
											},
										);
        e_print($xml);

        if($status == 1){
            subscribe(-html_output => 0);
        }
    }
}




sub unsubscribe_flash_xml {

    if($q->param('test') == 1){
        print $q->header('text/plain');
    }else{
        print $q->header('application/x-www-form-urlencoded');
    }

    if(check_if_list_exists(-List => $list) == 0){
        e_print('<unsubscription><email>' . $email . '</email><status>0</status><errors><error>no_list</error></errors></unsubscription>');
    }else{
        my $lh = DADA::MailingList::Subscribers->new({-list => $list});
        my ($xml, $status, $errors) =  $lh->unsubscription_check_xml(
											{
												-email => $email
											}
										);
        e_print($xml);

        if($status == 1){
            unsubscribe(-html_output => 0);
        }
    }
}




sub unsubscribe {

    my %args = (-html_output => 1, @_);
     require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
       $das->unsubscribe(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );

}




sub unsubscribe_request { 

	if(check_if_list_exists(-List => $list) == 0){
		&default;
		return;
	}


	  require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
			{
				-screen                   => 'unsubscribe_request.tmpl',
				-with                     => 'list', 
				-list                     => $list, 
                -list_settings_vars_param => {-list => $list,},
                -subscriber_vars_param    => {-list => $list, -email => $email, -type => 'list'},
                -dada_pseudo_tag_filter   => 1, 
			}
		);
		e_print($scrn);
}



sub confirm {

    my %args = (-html_output => 1, @_) ;

    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
       $das->confirm(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );

}




sub unsub_confirm {

    print $q->header();

    my %args = (-html_output => 1, @_);
     require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
       $das->unsub_confirm(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );

}





sub resend_conf {


    my $list_exists = check_if_list_exists(
						-List       => $list,
					);

    if($list_exists == 0){
        &default;
        return;
    }
    if (!$email){
        $q->param('error_no_email', 1);
        list_page();
        return;
    }

    if(
		$q->param('rm') eq 's' ||
		$q->param('rm') eq 'u'
	){
		# ...
    }
	else {
		&default;
        return;
	}

    if($q->request_method() !~ m/POST/i){
        &default;
        return;
    }


    require DADA::MailingList::Settings;


    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});


	my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];


	# I'm assuming this happens if we FAILED this test below (1 = failure for check_email_pin)
	#
	if(DADA::App::Guts::check_email_pin(
							-Email => $month . '.' . $day . '.' . $email,
							-Pin   => xss_filter($q->param('auth_code')),
							-List  => $list,
							)
							== 0
	){

		my ($e_day, $e_month, $e_stuff) = split('.', $email);

		#  Ah, I see, it only is blocked for a... day?
		if($e_day != $day || $e_month != $month){
			# a stale blocking thingy.
			if($q->param('rm') eq 's'){
				my $rm_status = $lh->remove_subscriber(
					{
						-email => $email,
						-type  => 'sub_confirm_list'
					}
				);
			}
			elsif($q->param('rm') eq 'u'){

				my $rm_status = $lh->remove_subscriber(
					{
						-email => $email,
						-type  => 'unsub_confirm_list'
					}
				);
			}
		}


		list_page();
		return;
	}
	else {


	    if($q->param('rm') eq 's'){

			my $sub_info = $lh->get_subscriber(
			                {
			                        -email => $email,
			                        -type  => 'sub_confirm_list',
			                }
			        );

	        my $rm_status = $lh->remove_subscriber(
				{
					-email => $email,
					-type  => 'sub_confirm_list'
				}
			);

			$q->param('list', $list);
			$q->param('email', $email);
			$q->param('f', 's');
			&subscribe;
	        return;

	    }elsif($q->param('rm') eq 'u'){
			# I like the idea better that we call the function directly...
	        my $rm_status = $lh->remove_subscriber(
				{
					-email => $email,
					-type  => 'unsub_confirm_list'
				}
			);

			$q->param('list', $list);
			$q->param('email', $email);
			$q->param('f', 'u');

			&unsubscribe;
	        return;

	    }

	}
}




sub text_list {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'text_list'
    );

    $list = $admin_list;
	my $type = $q->param('type') || 'list';
	my $query       = xss_filter($q->param('query')) || undef; 
	my $order_by    = $q->param('order_by')  || 'email'; 
	my $order_dir   = $q->param('order_dir') || 'asc'; 


    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $email;

	my $header  = 'Content-Disposition: attachement; filename="' . $list . '-' . $type . '.csv"' .  "\n"; 
	   $header .= 'Content-type: text/csv' . "\n\n"; 
		
	print $header; 
		
	    $lh->print_out_list(
			{ 
				-type      => $type,
				-query     => $query, 
				-order_by  => $order_by, 
				-order_dir => $order_dir, 
			}
		 );
}


sub preview_form {

my $code = $q->param("code");

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'preview_form');

print $q->header();

# Why isn't this templated out?
my $form = <<EOF

<html>
 <head>
  <title>Form Preview</title>
 </head>
 <body bgcolor="#ffffff">
  <table width="100%" height="100%" align="center">
   <tr>
    <td align="center">
     <p>$code</p>
     <p><a href="#" onclick="self.close();">close the window</a></p>
    </td>
   </tr>
  </table>
 </body>
</html>

EOF
;

e_print($form);

}

sub new_list {

    require DADA::Security::Password;
    my $root_password = $q->param('root_password');
    my $agree         = $q->param('agree');

    if(!$process) {

        my $errors = shift;
        my $flags  = shift;
        my $pw_check;

       if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){
            require DADA::Security::SimpleAuthStringState;
            my $sast =  DADA::Security::SimpleAuthStringState->new;
            my $auth_state = $q->param('auth_state');

            if($sast->check_state($auth_state) != 1){
                user_error(-List => undef, -Error => 'incorrect_login_url');
                return;
            }

        }

        if(!$DADA::Config::PROGRAM_ROOT_PASSWORD){
            user_error(-List => $list, -Error => "no_root_password");
            return;
        }elsif($DADA::Config::ROOT_PASS_IS_ENCRYPTED == 1){
            #encrypted password check
            $pw_check = DADA::Security::Password::check_password($DADA::Config::PROGRAM_ROOT_PASSWORD, $root_password);
        }else{
            # unencrypted password check
            if($DADA::Config::PROGRAM_ROOT_PASSWORD eq $root_password){$pw_check = 1}
        }

        if ($pw_check == 1){

            my @t_lists = available_lists();

            $agree = 'yes' if $errors;

            if((!$t_lists[0]) && ($agree ne 'yes') && (!$process)){
                    print $q->redirect(-uri => "$DADA::Config::S_PROGRAM_URL?agree=no");
            }

            $DADA::Config::LIST_QUOTA = undef if strip($DADA::Config::LIST_QUOTA) eq '';
            if(($DADA::Config::LIST_QUOTA) && (($#t_lists + 1) >= $DADA::Config::LIST_QUOTA)){
                user_error(-List => $list, -Error => "over_list_quota");
                return;
            }

            if(!$t_lists[0]){
                $help = 1;
            }

            my $ending   = undef;
            my $err_word = undef;

            if($errors){
                $ending = '';
                $err_word = 'was';
                $ending = 's'      if $errors > 1;
                $err_word = 'were' if $errors > 1;
            }

            require DADA::Template::Widgets;

			my @available_lists = DADA::App::Guts::available_lists();
			my $lists_exist = $#available_lists + 1;

			my $list_popup_menu = DADA::Template::Widgets::list_popup_menu(
										-show_hidden         => 1,
										-name                => 'clone_settings_from_this_list',
										-empty_list_check    => 1,
										-show_list_shortname => 1, 
									);

            my $scrn = DADA::Template::Widgets::wrap_screen(
				{
					-screen => 'new_list_screen.tmpl',
					-with   => 'list', 
					-vars   => {
						errors                            => $errors,
						ending                            => $ending,
						err_word                          => $err_word,
						help                              => $help,
						root_password                     => $root_password,
						flags_list_name                   => $flags->{list_name},
						list_name                         => $list_name,
						flags_list_exists                 => $flags->{list_exists},
						flags_list                        => $flags->{list},
						flags_shortname_too_long          => $flags->{shortname_too_long},
						flags_slashes_in_name             => $flags->{slashes_in_name},
						flags_weird_characters            => $flags->{weird_characters},
						flags_quotes                      => $flags->{quotes},
						list                              => $list,
						flags_password                    => $flags->{password},
						password                          => $password,

						flags_password_is_root_password   => $flags->{password_is_root_password},

						flags_retype_password             => $flags->{retype_password},
						flags_password_ne_retype_password => $flags->{password_ne_retype_password},
						retype_password                   => $retype_password,
						flags_invalid_list_owner_email    => $flags->{invalid_list_owner_email},
						list_owner_email                  => $list_owner_email,
						flags_list_info                   => $flags->{list_info},
						info                              => $info,
						flags_privacy_policy              => $flags->{privacy_policy},
						privacy_policy                    => $privacy_policy,
						flags_physical_address            => $flags->{physical_address},
						physical_address                  => $physical_address,
						flags_list_name_bad_characters    => $flags->{list_name_bad_characters},

						lists_exist                       => $lists_exist,
						list_popup_menu                   => $list_popup_menu,
					},
				}
			);
			e_print($scrn);

        }else{
            user_error(
				-List  => $list,
				-Error => "invalid_root_password"
			);
            return;
        }
    }else{

        chomp($list);
        $list =~ s/^\s+//;
        $list =~ s/\s+$//;
        # $list =~ s/ /_/g; # What?

        my $list_exists = check_if_list_exists(-List => $list);
        my ($list_errors,$flags) = check_list_setup(
										-fields => {
											list             => $list,
                                            list_name        => $list_name,
                                            list_owner_email => $list_owner_email,
                                            password         => $password,
                                            retype_password  => $retype_password,
                                            info             => $info,
                                            privacy_policy   => $privacy_policy,
                                            physical_address => $physical_address,
                                        }
                               		);

        if($list_errors >= 1){
            undef($process);
            new_list(
				$list_errors,
				$flags
			);

        }elsif($list_exists >= 1){
            user_error(
				-List  => $list,
				-Error => "list_already_exists"
			);
            return;
        }else{


            $list_owner_email  = lc_email($list_owner_email);
            $password          = DADA::Security::Password::encrypt_passwd($password);

            my $new_info = {
						#	list             =>   $list,
                            list_owner_email =>   $list_owner_email,
                            list_name        =>   $list_name,
                            password         =>   $password,
                            info             =>   $info,
                            privacy_policy   =>   $privacy_policy,
                            physical_address =>   $physical_address,
                           };

            require DADA::MailingList;
			my $ls;
			if($q->param('clone_settings') == 1){
            	$ls = DADA::MailingList::Create(
						{
							-list     => $list,
							-settings => $new_info,
							-clone    => xss_filter($q->param('clone_settings_from_this_list')),
						}
					);
            }
            else {
            	$ls = DADA::MailingList::Create(
						{
							-list     => $list,
							-settings => $new_info,
						}
					);
			}

            my $status;

			if($DADA::Config::LOG{list_lives}){
	            require DADA::Logging::Usage;
	            my $log = new DADA::Logging::Usage;
	               $log->mj_log(
							$list,
							'List Created',
							"remote_host:$ENV{REMOTE_HOST}," .
							"ip_address:$ENV{REMOTE_ADDR}"
							);
            }

            my $li = $ls->get;

            my $escaped_list = uriescape($li->{list});


            my $auth_state;

            if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){
                require DADA::Security::SimpleAuthStringState;
                my $sast       =  DADA::Security::SimpleAuthStringState->new;
                   $auth_state = $sast->make_state;
            }


            require DADA::Template::Widgets;
            my $scrn = DADA::Template::Widgets::wrap_screen(
				{
					-screen => 'new_list_created_screen.tmpl',
					-with   => 'list', 
                    -vars   => {
                                list_name        => $li->{list_name},
                                list             => $li->{list},
                                escaped_list     => $escaped_list,
                                list_owner_email => $li->{list_owner_email},
                                info             => $li->{info},
                                privacy_policy   => $li->{privacy_policy},
                                physical_address => $li->{physical_address},
                                auth_state       => $auth_state,
                            },
                   }
			);
			e_print($scrn);

        }
    }
}




sub archive {

    # are we dealing with a real list?
    my $list_exists = check_if_list_exists(
        -List       => $list,
    );

    if ( $list_exists == 0 ) {

        print $q->redirect(
            -status => '301 Moved Permanently',
            -uri    => $DADA::Config::PROGRAM_URL,
        );
        return;
    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    require DADA::Profile;
	my $prof = DADA::Profile->new({-from_session => 1});
    my $allowed_to_view_archives = 1;
	if($prof){
 		$allowed_to_view_archives = $prof->allowed_to_view_archives(
	        {
	            -list         => $list,
	        }
	    );
	}
    if ( $allowed_to_view_archives == 0 ) {
        user_error( -List => $list, -Error => "not_allowed_to_view_archives" );
        return;
    }

    my $start = int( $q->param('start') ) || 0;

    require DADA::Template::Widgets;

    if ( $li->{show_archives} == 0 ) {
        user_error( -List => $list, -Error => "no_show_archives" );
        return;
    }

    require DADA::MailingList::Archives;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    my $entries = $archive->get_archive_entries();

###### These are all little thingies.

    my $archive_send_form = '';
    $archive_send_form = DADA::Template::Widgets::archive_send_form(
        $list, $id,
        xss_filter( $q->param('send_archive_errors') ),
        $li->{captcha_archive_send_form},
        xss_filter( $q->param('captcha_fail') )
      )
      if $li->{archive_send_form} == 1 && defined($id);

    my $nav_table = '';
    $nav_table = $archive->make_nav_table( -Id => $id, -List => $li->{list} )
      if defined($id);

    my $archive_search_form = '';
    $archive_search_form = $archive->make_search_form( $li->{list} )
      if $li->{archive_search_form} == 1;

    my $archive_subscribe_form = "";

    if ( $li->{hide_list} ne "1" ) {

		# DEV: This takes the cake for worst hack I have found... today.
        my $info = '<!-- tmpl_var list_settings.info -->';
		   $info = DADA::Template::Widgets::screen(
				{
					-data => \$info,
					-list_settings_vars_param => {-list => $list,  -dot_it => 1 },
					-webify_and_santize_these => [qw(list_settings.info)],
				}
			);

        unless ( $li->{archive_subscribe_form} eq "0" ) {

			$archive_subscribe_form .= $info;
            $archive_subscribe_form .=
              DADA::Template::Widgets::subscription_form(
                {
                    -list       => $li->{list},
                    -email      => $email,
                    -give_props => 0,
                }
              );
        }
    }

    my $archive_widgets = {
        archive_send_form      => $archive_send_form,
        nav_table              => $nav_table,
        publish_archives_rss   => $li->{publish_archives_rss} ? 1 : 0,
        archive_search_form    => $archive_search_form,
        archive_subscribe_form => $archive_subscribe_form,
    };

    #/##### These are all little thingies.

    if ( !$id ) {

		if (!$c->profile_on && $c->cached( 'archive/' . $list . '/' . $start  . '.scrn') ) {
		    $c->show( 'archive/' . $list . '/' . $start  . '.scrn');
		    return;
		}

        my $th_entries = [];

        my ( $begin, $stop ) = $archive->create_index($start);
        my $i;
        my $stopped_at = $begin;
        my $num        = $begin;

        $num++;
        my @archive_nums;
        my @archive_links;

        # iterate and save
        for ( $i = $begin ; $i <= $stop ; $i++ ) {
            my $link;

            if ( defined( $entries->[$i] ) ) {

                my ( $subject, $message, $format, $raw_msg ) =
                  $archive->get_archive_info( $entries->[$i] );

                # DEV: This is stupid, and I don't think it's a great idea.
                $subject = DADA::Template::Widgets::screen(
                    {
                        -data                     => \$subject,
                        -vars                     => $li,
                        -list_settings_vars       => $li,
                        -list_settings_vars_param => { -dot_it => 1 },
                        -dada_pseudo_tag_filter   => 1,
                        -subscriber_vars_param    =>
                          { -use_fallback_vars => 1, -list => $list },
                    },

                );

                # this is so atrocious.
                my $date = date_this(
                    -Packed_Date   => $archive->_massaged_key( $entries->[$i] ),
                    -Write_Month   => $li->{archive_show_month},
                    -Write_Day     => $li->{archive_show_day},
                    -Write_Year    => $li->{archive_show_year},
                    -Write_H_And_M => $li->{archive_show_hour_and_minute},
                    -Write_Second  => $li->{archive_show_second}
                );

                my $entry = {
                    id               => $entries->[$i],
                    date             => $date,
                    subject          => $subject,
                    'format'         => $format,
                    list             => $list,
                    uri_escaped_list => uriescape($list),
                    PROGRAM_URL      => $DADA::Config::PROGRAM_URL,
                    message_blurb    =>
                      $archive->message_blurb( -key => $entries->[$i] ),

                };

                $stopped_at++;
                push ( @archive_nums,  $num );
                push ( @archive_links, $link );
                $num++;

                push ( @$th_entries, $entry );

            }
        }

        my $ii;
        for ( $ii = 0 ; $ii <= $#archive_links ; $ii++ ) {

            my $bullet = $archive_nums[$ii];

            #fix if we're doing reverse chronologic
            $bullet = ( ( $#{$entries} + 1 ) - ( $archive_nums[$ii] ) + 1 )
              if ( $li->{sort_archives_in_reverse} == 1 );

            # yeah, whatever.
            $th_entries->[$ii]->{bullet} = $bullet;

        }

        my $index_nav = $archive->create_index_nav($stopped_at);

        require DADA::Profile;
		my $prof = DADA::Profile->new(
			{
				-from_session => 1
			}
		);
	    my $allowed_to_view_archives = 1;
		if($prof){
	 		$allowed_to_view_archives = $prof->allowed_to_view_archives(
		        {
		            -list         => $list,
		        }
		    );
		}

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'archive_index_screen.tmpl',
				-with   => 'list', 
                -vars   => {
                    list                     => $list,
                    list_name                => $li->{list_name},
                    entries                  => $th_entries,
                    index_nav                => $index_nav,
                    flavor_archive           => 1,
                    allowed_to_view_archives => $allowed_to_view_archives,
                    publish_archives_rss => $li->{publish_archives_rss} ? 1 : 0,

                    %$archive_widgets,

                },
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1 },

            }
        );
        e_print($scrn);

        if (!$c->profile_on)
        {
            $c->cache( 'archive/' . $list . '/' . $start . '.scrn', \$scrn );

        }
        return;

    }
    else {    # There's an id...

        $id = $archive->newest_entry if $id =~ /newest/i;
        $id = $archive->oldest_entry if $id =~ /oldest/i;

        if ( $q->param('extran') ) {

            print $q->redirect(
                -status => '301 Moved Permanently',
                -uri    => $DADA::Config::PROGRAM_URL
                  . '/archive/'
                  . $li->{list} . '/'
                  . $id . '/',
            );
            return;
        }

        if ( $id !~ m/(\d+)/g ) {

            print $q->redirect( -uri => $DADA::Config::PROGRAM_URL
                  . '/archive/'
                  . $li->{list}
                  . '/' );
            return;
        }

        $id = $archive->_massaged_key($id);

        if (   $li->{archive_send_form} != 1
            && $li->{captcha_archive_send_form} != 1 )
        {

            if (!$c->profile_on &&
	 			$c->cached( 'archive/' . $list . '/' . $id . '.scrn' )
			) {
                $c->show( 'archive/' . $list . '/' . $id . '.scrn' );				
				require DADA::Logging::Clickthrough; 
				my $r = DADA::Logging::Clickthrough->new({-list => $list});
				$r->view_archive_log(
					{ 
						-mid => $id, 
					}
				);
				
                return;
            }
        }

        my $entry_exists = $archive->check_if_entry_exists($id);
        if ( $entry_exists <= 0 ) {
            user_error( -List => $list, -Error => "no_archive_entry" );
            return;
        }

        my ( $subject, $message, $format, $raw_msg ) =
          $archive->get_archive_info($id);

        # DEV: This is stupid, and I don't think it's a great idea.
        $subject = $archive->_parse_in_list_info( -data => $subject );

        # That. Sucked.

        my ( $massaged_message_for_display, $content_type ) =
          $archive->massaged_msg_for_display( -key => $id, -body_only => 1 );

        my $show_iframe = $li->{html_archives_in_iframe} || 0;
        if ( $content_type eq 'text/plain' ) {
            $show_iframe = 0;
        }

        my $header_from      = undef;
        my $orig_header_from = undef;

        #my $header_date    = undef;
        my $header_subject = undef;

        my $in_reply_to_id;
        my $in_reply_to_subject;

        if ($raw_msg) {
            $header_from =
              $archive->get_header( -header => 'From', -key => $id );
            $orig_header_from = $header_from;

            # DEV: This logic should not be here...

			# DEV: This is stupid, and I don't think it's a great idea.
	        $header_from = $archive->_parse_in_list_info( -data => $header_from );
	
            if ( $li->{archive_protect_email} eq 'recaptcha_mailhide' ) {
                $header_from = mailhide_encode($header_from);
            }
            elsif ( $li->{archive_protect_email} eq 'spam_me_not' ) {
                $header_from = spam_me_not_encode($header_from);
            }
            else {
                $header_from = xss_filter($header_from);
            }

            $header_subject =
              $archive->get_header( -header => 'Subject', -key => $id );

            $header_subject =~ s/\r|\n/ /g;
            if ( !$header_subject ) {
                $header_subject = $DADA::Config::EMAIL_HEADERS{Subject};
            }

            ( $in_reply_to_id, $in_reply_to_subject ) =
              $archive->in_reply_to_info( -key => $id );

            # DEV: This is stupid, and I don't think it's a great idea.
            $header_subject =
              $archive->_parse_in_list_info( -data => $header_subject );
            $in_reply_to_subject =
              $archive->_parse_in_list_info( -data => $in_reply_to_subject );

            # That. Sucked.
            $header_subject      = $header_subject;
            $in_reply_to_subject = $in_reply_to_subject;

        }

        my $attachments =
          ( $li->{display_attachments} == 1 )
          ? $archive->attachment_list($id)
          : [];

        # this is so atrocious.
        my $date = date_this(
            -Packed_Date   => $id,
            -Write_Month   => $li->{archive_show_month},
            -Write_Day     => $li->{archive_show_day},
            -Write_Year    => $li->{archive_show_year},
            -Write_H_And_M => $li->{archive_show_hour_and_minute},
            -Write_Second  => $li->{archive_show_second}
        );

        my $can_use_gravatar_url = 0;
        my $gravatar_img_url     = '';

        if ( $li->{enable_gravatars} ) {

            eval { require Gravatar::URL };
            if ( !$@ ) {
                $can_use_gravatar_url = 1;

                require Email::Address;
                if ( defined($orig_header_from) ) {
                    ;
                    eval {
                        $orig_header_from =
                          ( Email::Address->parse($orig_header_from) )[0]
                          ->address;
                    };
                }
                if ( isa_url( $li->{default_gravatar_url} ) ) {
                    $gravatar_img_url =
                      Gravatar::URL::gravatar_url( email => $orig_header_from );
                }
                else {
                    $gravatar_img_url = Gravatar::URL::gravatar_url(
                        email   => $orig_header_from,
                        default => $li->{default_gravatar_url}
                    );
                }
            }
            else {
                $can_use_gravatar_url = 0;
            }
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'archive_screen.tmpl',
				-with   => 'list', 
                -vars   => {
                    list      => $list,
                    list_name => $li->{list_name},
                    id        => $id,

                    # DEV. OK - riddle ME why there's two of these...
                    header_subject => $header_subject,
                    subject        => $subject,

                    js_enc_subject      => js_enc($subject),
                    uri_encoded_subject => uriescape($subject),
                    uri_encoded_url     => uriescape(
                        $DADA::Config::PROGRAM_URL
                          . '/archive/'
                          . $list . '/'
                          . $id . '/'
                    ),
                    archived_msg_url => $DADA::Config::PROGRAM_NAME
                      . '/archive/'
                      . $list . '/'
                      . $id . '/',
                    massaged_msg_for_display => $massaged_message_for_display,
                    send_archive_success => $q->param('send_archive_success')
                    ? $q->param('send_archive_success')
                    : undef,
                    send_archive_errors => $q->param('send_archive_errors')
                    ? $q->param('send_archive_errors')
                    : undef,
                    show_iframe     => $show_iframe,
                    discussion_list => ( $li->{group_list} == 1 ) ? 1 : 0,

                    header_from         => $header_from,
                    in_reply_to_id      => $in_reply_to_id,
                    in_reply_to_subject => xss_filter($in_reply_to_subject),
                    attachments         => $attachments,
                    date                => $date,
                    add_social_bookmarking_badges =>
                      $li->{add_social_bookmarking_badges},
                    can_use_gravatar_url => $can_use_gravatar_url,
                    gravatar_img_url     => $gravatar_img_url,
                    %$archive_widgets,

                },
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1 },
            }
        );
        e_print($scrn);

		require DADA::Logging::Clickthrough; 
		my $r = DADA::Logging::Clickthrough->new({-list => $list});
		$r->view_archive_log(
			{ 
				-mid => $id, 
			}
		);

        if (!$c->profile_on &&
	   		$li->{archive_send_form} != 1
            && $li->{captcha_archive_send_form} != 1 )
        {
            $c->cache( 'archive/' . $list . '/' . $id . '.scrn', \$scrn );

        }

        return;

    }

}





sub archive_bare {


    if($q->param('admin')){
            my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                                -Function => 'view_archive');
            $list = $admin_list;
    }


    if($c->cached('archive_bare.' . $list . '.' . $id . '.' . $q->param('admin') . '.scrn')){
		$c->show('archive_bare.' . $list . '.' . $id . '.' . $q->param('admin') . '.scrn');
		return;
	}

    require DADA::MailingList::Archives;

    require DADA::MailingList::Settings;


    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    my $la = DADA::MailingList::Archives->new({-list => $list});

    if(!$q->param('admin')){
        if ($li->{show_archives} == 0){
            user_error(-List => $list, -Error => "no_show_archives");
            return;
        }
		require DADA::Profile;
		my $prof = DADA::Profile->new({-from_session => 1});
	    my $allowed_to_view_archives = 1;
		if($prof){
	 		$allowed_to_view_archives = $prof->allowed_to_view_archives(
		        {
		            -list         => $list,
		        }
		    );
		}

		if($allowed_to_view_archives == 0){
			user_error(-List => $list, -Error => "not_allowed_to_view_archives");
			return;
		}
    }
    if($la->check_if_entry_exists($id) <= 0) {
        user_error(-List => $list, -Error => "no_archive_entry");
        return;
    }

    my $scrn = $q->header();
       $scrn .= $la->massaged_msg_for_display(-key => $id);
    e_print($scrn);

    $c->cache('archive_bare.' . $list . '.' . $id . '.' . $q->param('admin') . '.scrn', \$scrn);

    return;
}




sub search_archive {
    if (check_if_list_exists(-List => $list) <= 0) {
        user_error(-List => $list, -Error => "no_list");
        return;
    }

    require  DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    if ($li->{show_archives} == 0){
        user_error(-List => $list, -Error => "no_show_archives");
        return;
    }
	require DADA::Profile;
	my $prof = DADA::Profile->new({-from_session => 1});
    my $allowed_to_view_archives = 1;
	if($prof){
 		$allowed_to_view_archives = $prof->allowed_to_view_archives(
	        {
	            -list         => $list,
	        }
	    );
	}

	if($allowed_to_view_archives == 0){
		user_error(-List => $list, -Error => "not_allowed_to_view_archives");
		return;
	}

    $keyword = xss_filter($keyword);

    if($keyword =~ m/^[A-Za-z]+$/){ # just words, basically.
        if(!$c->profile_on && $c->cached($list.'.search_archive.' . $keyword . '.scrn')){
			$c->show($list.'.search_archive.' . $keyword . '.scrn');
			return;
		}
    }


    require DADA::MailingList::Archives;

    my $archive      = DADA::MailingList::Archives->new({-list => $list});
    my $entries      = $archive->get_archive_entries();
    my $ending       = "";
    my $count        = 0;
    my $ht_summaries = [];


    my $search_results = $archive->search_entries($keyword);

    if(defined(@$search_results[0]) && (@$search_results[0] ne "")){

       $count = $#{$search_results}+1;
       $ending = 's'
        if defined(@$search_results[1]);

        my $summaries = $archive->make_search_summary($keyword, $search_results);

        for(@$search_results){

            my ($subject, $message, $format) = $archive->get_archive_info($_);
            my $date = date_this(-Packed_Date   => $_,
                                 -Write_Month   => $li->{archive_show_month},
                                 -Write_Day     => $li->{archive_show_day},
                                 -Write_Year    => $li->{archive_show_year},
                                 -Write_H_And_M => $li->{archive_show_hour_and_minute},
                                 -Write_Second  => $li->{archive_show_second});

            push(@$ht_summaries, {
                summary     => $summaries->{$_},
                subject     => $archive ->_parse_in_list_info(-data => $subject),
                date        => $date,
                id          => $_,
                PROGRAM_URL => $DADA::Config::PROGRAM_URL,
                list        => uriescape($list),
            });

        }
    }

    my $search_form = '';
    if($li->{archive_search_form} == 1){
        $search_form = $archive->make_search_form($li->{list});
    }

    my $archive_subscribe_form = '';
    if($li->{hide_list} ne "1"){

		# DEV: This takes the cake for worst hack I have found... today.
        my $info = '<!-- tmpl_var list_settings.info -->';
		   $info = DADA::Template::Widgets::screen(
				{
					-data => \$info,
					-list_settings_vars_param => {-list => $list,  -dot_it => 1 },
					-webify_and_santize_these => [qw(list_settings.info)],
				}
			);


        unless ($li->{archive_subscribe_form} eq "0"){
            $archive_subscribe_form .= $info . "\n";
            require DADA::Template::Widgets;
 $archive_subscribe_form .= DADA::Template::Widgets::subscription_form({
                -list       => $li->{list},
                -email      => $email,
                -give_props => 0,
            }
             );
        }

    }

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'search_archive_screen.tmpl',
			-with   => 'list',
			-vars => {
				list_name              => $li->{list_name},
				uriescape_list         => uriescape($list),
				list                   => $list,
				count                  => $count,
				ending                 => $ending,
				keyword                => $keyword,
				summaries              => $ht_summaries,
				search_results         => $ht_summaries->[0] ? 1 : 0,
				search_form            => $search_form,
				archive_subscribe_form => $archive_subscribe_form,
			},
			-list_settings_vars_param => {
				-list   => $list,
				-dot_it => 1,
			},
			}
	);
    e_print($scrn);

    if(!$c->profile_on && $keyword =~ m/^[A-Za-z]+$/){ # just words, basically.
        $c->cache($list.'.search_archive.' . $keyword . '.scrn', \$scrn);
    }

    return;


}





sub send_archive {

    my $entry        = xss_filter($q->param('entry'));
    my $from_email   = xss_filter($q->param('from_email'));
    my $to_email     = xss_filter($q->param('to_email'));
    my $note         = xss_filter($q->param('note'));

    my $errors       = 0;

    my $list_exists = check_if_list_exists(-List => $list);

    if ($list_exists <= 0 ) {
        user_error(-List => $list, -Error => "no_list");
        return;
    }

	if(check_for_valid_email($to_email)   == 1){ 
    	$errors++;
	}
    
	if(check_for_valid_email($from_email) == 1){ 
		$errors++;
	}
	if($DADA::Config::REFERER_CHECK == 1){ 
		if(check_referer($q->referer()) != 1) {
			$errors++;
		}
	}
    require  DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

	require DADA::Profile;
	my $prof = DADA::Profile->new({-from_session => 1});
    my $allowed_to_view_archives = 1;
	if($prof){
 		$allowed_to_view_archives = $prof->allowed_to_view_archives(
	        {
	            -list         => $list,
	        }
	    );
	}

	if($allowed_to_view_archives == 0){
		user_error(-List => $list, -Error => "not_allowed_to_view_archives");
		return;
	}

    # CAPTCHA STUFF

    my $captcha_fail    = 0;
	my $can_use_captcha = 0;
	eval { require DADA::Security::AuthenCAPTCHA; };
	if(!$@){
		$can_use_captcha = 1;
	}

    if($li->{captcha_archive_send_form} == 1 && $can_use_captcha == 1){
        require   DADA::Security::AuthenCAPTCHA;
        my $cap = DADA::Security::AuthenCAPTCHA->new;

        if(xss_filter($q->param('recaptcha_response_field'))){
            my $result = $cap->check_answer(
                $DADA::Config::RECAPTCHA_PARAMS->{private_key},
                $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
                $q->param( 'recaptcha_challenge_field' ),
                $q->param( 'recaptcha_response_field')
            );

            if($result->{is_valid} != 1){
                $errors++;
                $captcha_fail = 1;
            }
       }
        else {
            # yeah, we're gonna need that...
            $errors++;
            $captcha_fail = 1;
		}
    }

	if($li->{archive_send_form}        != 1){ 
    	$errors++;
	}
	
    if($errors > 0){
        print $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=archive&l=' . $list . '&id=' . $entry . '&send_archive_errors=' . $errors . '&captcha_fail=' . $captcha_fail);
    }else{

        require DADA::MailingList::Archives;

        my $archive = DADA::MailingList::Archives->new({-list => $list});

        if($entry =~ /newest/i){
            $entry = $archive->newest_entry;
        }
        elsif($entry =~ /oldest/i){
            $entry = $archive->oldest_entry;
        }


        my $archive_message_url = $DADA::Config::PROGRAM_URL . '/archive/' . $list . '/' . $entry . '/';

        my ($subject, $message, $format, $raw_msg) = $archive->get_archive_info($entry);
        chomp($subject);

		require DADA::Template::Widgets;
        # DEV: This is stupid, and I don't think it's a great idea.
        $subject = $archive ->_parse_in_list_info(-data => $subject);
		### /

        require MIME::Lite;

        # DEV: This should really be moved to DADA::App::Messages...
        my $msg = MIME::Lite->new(
                    From    => '"<!-- tmpl_var list_settings.list_name -->" <' . $from_email . '>',
                    To      => '"<!-- tmpl_var list_settings.list_name -->" <' . $to_email   . '>',
                    Subject => $li->{send_archive_message_subject},
                    Type    => 'multipart/mixed',
                  );


        my $pt = MIME::Lite->new(Type     => 'text/plain',
                                 Data     => $li->{send_archive_message},
                                 Encoding => $li->{plaintext_encoding});

        my $html = MIME::Lite->new(Type      => 'text/html',
                                   Data      => $li->{send_archive_message_html},
                                   Encoding  => $li->{html_encoding}
                                  );

        my $ma = MIME::Lite->new(Type => 'multipart/alternative');
           $ma->attach($pt);
           $ma->attach($html);

		$msg->attach($ma);

        my $a_msg;

		#... sort of weird.
        if($raw_msg){

            $a_msg = MIME::Lite->new(Type          => 'message/rfc822',
                                       Disposition => "inline",
                                       Data        => $archive->massage_msg_for_resending(-key => $entry),
                                      );

        }else{

            $a_msg = MIME::Lite->new(Type          => 'message/rfc822',
                                       Disposition => "inline",
                                       Type        => $format,
                                       Data        => $message
                                      );
        }

        $msg->attach($a_msg);

        require DADA::App::FormatMessages;
        my $fm = DADA::App::FormatMessages->new(-List => $list);
           $fm->use_list_template(0);
           $fm->use_email_templates(0);
           $fm->use_header_info(1);

		  my $msg_a_s = safely_encode($msg->as_string);
		   my ($email_str) = $fm->format_message(
									-msg => $msg_a_s,
		                          );


			my ($e_name, $e_domain) = split('@', $to_email, 2);
		    my $entity = $fm->email_template(
		        {
		            -entity                   => $fm->get_entity({-data => $email_str}),
		            -list_settings_vars_param => {-list => $list,},
		            -vars                     => {
						from_email                => $from_email,
						to_email                  => $to_email,
						note                      => $note,
						archive_message_url       => $archive_message_url,
						archived_message_subject  => $subject,
						'subscriber.email_name'   => $e_name, 
						'subscriber.email_domain' => $e_domain, 
		        	},
		        }
		    );

		    $msg = safely_decode($entity->as_string);
		    my ($header_str, $body_str) = split("\n\n", $msg, 2);

			require DADA::Mail::Send;
			my $mh = DADA::Mail::Send->new(
						{
							-list   => $list,
							-ls_obj => $ls,
						}
					);

			$mh->send(
			    $mh->return_headers($header_str),
				Body => $body_str,
		    );
		
			require DADA::Logging::Clickthrough; 
			my $r = DADA::Logging::Clickthrough->new({-list => $list});
			$r->forward_to_a_friend_log(
				{ 
					-mid => $entry, 
				}
			); 
			
            print $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=archive&l=' . $list . '&id=' . $entry . '&send_archive_success=1');
    }
}




sub archive_rss {

    my %args = (-type => 'rss',
                @_
               );

    my $list_exists = check_if_list_exists(-List => $list);

    if ($list_exists == 0){

    }else{

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new({-list => $list});
        my $li = $ls->get;

        if ($li->{show_archives} == 0){

        }else{

			require DADA::Profile;
			my $prof = DADA::Profile->new({-from_session => 1});
		    my $allowed_to_view_archives = 1;
			if($prof){
		 		$allowed_to_view_archives = $prof->allowed_to_view_archives(
			        {
			            -list         => $list,
			        }
			    );
			}

			if($allowed_to_view_archives == 0){
				return '';
			}

            if($li->{publish_archives_rss} == 0){

            }else{

                if($args{-type} eq 'rss'){

                    if($c->cached('archive_rss/' . $list)){
						$c->show('archive_rss/' . $list . '.scrn');
						return;
					}

                    require DADA::MailingList::Archives;

                    my    $archive = DADA::MailingList::Archives->new({-list => $list});

                    my $scrn = $q->header('application/xml') .  $archive->rss_index();

                    e_print($scrn);

                    $c->cache('archive_rss/' . $list . '.scrn', \$scrn);
                    return;


                }elsif($args{-type} eq 'atom'){

                    if($c->cached('archive_atom/' . $list)){
						$c->show('archive_atom/' . $list . '.scrn');
						return;
					}

                    require DADA::MailingList::Archives;
                    my    $archive = DADA::MailingList::Archives->new({-list => $list});
                    my $scrn = $q->header('application/xml') . $archive->atom_index();
                    e_print($scrn);

                    $c->cache('archive_atom/' . $list . '.scrn', \$scrn);
                    return;

                }else{
                    warn "wrong type of feed asked for: " . $args{-type} . ' - '. $!;
                }
            }
     }
    }
}




sub archive_atom {
    archive_rss(-type => 'atom');
}




sub email_password {


    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    require DADA::Security::Password;

    if(( $li->{pass_auth_id} ne "")    &&
       ( defined($li->{pass_auth_id})) &&
       ( $q->param('pass_auth_id')  eq $li->{pass_auth_id})){

        my $new_password  = DADA::Security::Password::generate_password();
        my $new_encrypt   = DADA::Security::Password::encrypt_passwd($new_password);

        $ls->save(
			{
             	password     => $new_encrypt,
                pass_auth_id => ''
            }
		);

		require DADA::App::Messages;
		DADA::App::Messages::send_generic_email(
			{
				-list    => $list,
				-headers => {
					From    => '"' .                escape_for_sending($li->{list_name}) . '" <' . $li->{list_owner_email} . '>',
				    To      => '"List Owner for: '. escape_for_sending($li->{list_name}) . '" <' . $li->{list_owner_email} . '>',
				    Subject => $DADA::Config::LIST_RESET_PASSWORD_MESSAGE_SUBJECT,
				},
				-body        => $DADA::Config::LIST_RESET_PASSWORD_MESSAGE,
				-tmpl_params => {
					-list_settings_vars_param => {
						-list   => $list,
						-dot_it => 1,
					},
		            -vars => {
		            	new_password => $new_password,
		            },
				},
			}
		);

		require DADA::Logging::Usage;
		my $log = new DADA::Logging::Usage;
		   $log->mj_log($list, 'List Password Reset', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}")
				if $DADA::Config::LOG{list_lives};
		print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=' . $DADA::Config::SIGN_IN_FLAVOR_NAME . '&list=' . $list);

}else{

    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
				{
					-list   => $list,
					-ls_obj => $ls,
				}
			);

    my $random_string = DADA::Security::Password::generate_rand_string();

    $ls->save(
		{
			pass_auth_id => $random_string,
		}
	);

	require DADA::App::Messages;
	DADA::App::Messages::send_generic_email(
		{
			-list    => $list,
			-headers => {
				From     => '"'                  . escape_for_sending($li->{list_name}) . '" <' . $li->{list_owner_email} . '>',
			    To       =>  '"List Owner for: ' . escape_for_sending($li->{list_name}) . '" <' . $li->{list_owner_email} . '>',
 				Subject  => $DADA::Config::LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT,
			},
			-body        => $DADA::Config::LIST_CONFIRM_PASSWORD_MESSAGE,
			-tmpl_params => {
				-list_settings_vars_param => {
					-list   => $list,
					-dot_it => 1,
				},
	            -vars => {
	            	random_string => $random_string,
					REMOTE_HOST   => $ENV{REMOTE_HOST},
					REMOTE_ADDR   => $ENV{REMOTE_ADDR},
	            },
			},
		}
	);

	require DADA::Logging::Usage;
	my $log = new DADA::Logging::Usage;
	   $log->mj_log($list, 'Sent Password Change Confirmation', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}")
	        if $DADA::Config::LOG{list_lives};


    sleep(10);

    require DADA::Template::Widgets;
	my $scrn =   DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'list_password_confirmation_screen.tmpl',
			-with   => 'list', 
			-vars   => {
				REMOTE_HOST => $ENV{REMOTE_HOST},
				REMOTE_ADDR => $ENV{REMOTE_ADDR},
			},
			-list_settings_vars_param => {
				-list    => $list,
				-dot_it  => 1,
			},
		},
	);
	e_print($scrn);

    }
}




sub login {

    my $referer        = $q->param('referer')        || $DADA::Config::DEFAULT_ADMIN_SCREEN;
    my $admin_password = $q->param('admin_password') || "";
    my $admin_list     = $q->param('admin_list')     || "";
    my $auth_state     = $q->param('auth_state')     || undef;

    my $try_referer = $referer;

       $try_referer =~ s/(^http\:\/\/|^https\:\/\/)//;
       $try_referer =~ s/^www//;

       my $reg_try_referer = quotemeta($try_referer);
       if($DADA::Config::PROGRAM_URL =~ m/$reg_try_referer$/){
            $referer = $DADA::Config::DEFAULT_ADMIN_SCREEN;
       }

    $list = $admin_list;

   if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){
        require DADA::Security::SimpleAuthStringState;
        my $sast =  DADA::Security::SimpleAuthStringState->new;
        if($sast->check_state($auth_state) != 1){
            user_error(
				-List  => $list,
				-Error => 'incorrect_login_url',
			);
            return;
        }
    }

    my $cookie;


    if(check_if_list_exists(-List => $list) >= 1){

       require DADA::Security::Password;

        my $dumb_cookie = $q->cookie(-name    => 'blankpadding',
                                     -value   => 'blank',
                                     %DADA::Config::COOKIE_PARAMS,
                                    );

        require DADA::App::Session;
        my $dada_session = DADA::App::Session->new();


        if($dada_session->logged_into_diff_list(-cgi_obj => $q) != 1){

            my $login_cookie = $dada_session->login_cookie(-cgi_obj => $q,
                                                           -list    => $list,
                                                           -password => $admin_password);

            require DADA::App::ScreenCache;
            my $c = DADA::App::ScreenCache->new;
            $c->remove('login_switch_widget.' . $list . '.scrn');

            if($DADA::Config::LOG{logins}){
                require DADA::Logging::Usage;
                my $log = new DADA::Logging::Usage;
                my $rh = $ENV{REMOTE_HOST} || '';
                my $ra = $ENV{REMOTE_ADDR} || '';

                $log->mj_log($admin_list, 'login', 'remote_host:' . $rh . ', ip_address:' . $ra);
            }

            print $q->header(-cookie  => [$dumb_cookie, $login_cookie],
                              -nph     => $DADA::Config::NPH,
                              -Refresh =>'0; URL=' . $referer);

            print $q->start_html(-title=>'Logging in...',
                                 -BGCOLOR=>'#FFFFFF'
                                );
            print $q->p($q->a({-href => $referer}, 'Logging in...'));
            print $q->end_html();

            $dada_session->remove_old_session_files();

        }else{

            user_error(-List  => $list,
                       -Error => "logged_into_different_list",
                      );
            return;

        }

    }else{
        user_error(-List  => $list,
                   -Error => "no_list",
                  );
        return;
    }
}




sub logout {

    my %args = (
		-redirect               => 1,
        -redirect_url           => $DADA::Config::DEFAULT_LOGOUT_SCREEN,
        -no_list_security_check => 0,
    	@_
	);

     my $admin_list;
     my $root_login;

     my $list_exists = check_if_list_exists(-List => $admin_list);

    # I don't quite even understand why there's this check...

    if($args{-no_list_security_check} == 0){
        if($list_exists == 1){

            ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                             -Function => 'logout');
        }
    }


    require DADA::App::ScreenCache;
    my $c = DADA::App::ScreenCache->new;
       $c->remove('login_switch_widget.' .$admin_list . '.scrn');

    my $l_list   = $admin_list;

    my $location = $args{-redirect_url};

    if($q->param('login_url')){
        $location = $q->param('login_url');
    }

    if ($DADA::Config::LOG{logins} != 0){

        require DADA::Logging::Usage;
        my $log = new DADA::Logging::Usage;
           $log->mj_log($l_list, 'logout', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}");

    }

    my $logout_cookie;

        require DADA::App::Session;
        my $dada_session  = DADA::App::Session->new(-List => $l_list);
           $logout_cookie = $dada_session->logout_cookie(-cgi_obj => $q);

    if($args{-redirect} == 1){

        print $q->header(-COOKIE       => $logout_cookie,
                              -nph     => $DADA::Config::NPH,
                              -Refresh =>'0; URL=' . $location,
                            );

        print $q->start_html(-title   =>'Logging Out...',
                             -BGCOLOR =>'#FFFFFF'
                            ),
              $q->p($q->a( {-href => $location}, 'Logging Out...')),
              $q->end_html();
     } else {
        return $logout_cookie;
     }

}



sub log_into_another_list {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'log_into_another_list');

    logout(-redirect_url => $DADA::Config::PROGRAM_URL . '?f=' . $DADA::Config::SIGN_IN_FLAVOR_NAME, );

    return;

}





sub change_login {


    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'change_login');

    die "only for root logins!"
        if ! $root_login;

    require DADA::App::Session;
    my $dada_session = DADA::App::Session->new();

    my $change_to_list = $q->param('change_to_list');
    my $location       = $q->param('location');

    $q->delete_all();

    # DEV: Ooh. This is messy.
    $location =~ s/(\;|\&)done\=1$//;
    $location =~ s/(\;|\&)delete_email_count\=(.*?)$//;
    $location =~ s/(\;|\&)email_count\=(.*?)$//;



    my $new_cookie = $dada_session->change_login(-cgi_obj => $q, -list => $change_to_list);

    require DADA::App::ScreenCache;
    my $c = DADA::App::ScreenCache->new;
       $c->remove('login_switch_widget.' . $change_to_list . '.scrn');

    print $q->header(-cookie  => [$new_cookie],
                      -nph     => $DADA::Config::NPH,
                      -Refresh =>'0; URL=' . $location);
    print $q->start_html(-title=>'Switching...',
                         -BGCOLOR=>'#FFFFFF'
                        );
    print $q->p($q->a({-href => $location}, 'Switching...'));
    print $q->end_html();

}




sub remove_subscribers {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );

    $list = $admin_list;

	my $return_to      = $q->param('return_to')      || ''; 
	my $return_address = $q->param('return_address') || ''; 
	
	 
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my ( $d_count, $bl_count ) = $lh->admin_remove_subscribers(
        {
            -addresses        => [@address],
            -type             => $type,
			-validation_check => 0, 
        }
    );

	my $flavor_to_return_to = 'view_list'; 
	if($return_to eq 'membership'){ # or, others...
		$flavor_to_return_to = $return_to;
	}
	
    my $qs =
        
       'flavor=' . $flavor_to_return_to 
      . ';delete_email_count='
      . $d_count
      . ';type='
      . $type
      . ';black_list_add='
      . $bl_count;

	if($return_to eq 'membership'){
		$qs .= ';email=' . $return_address;
	}


    print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL . '?' . $qs );

}



sub process_bouncing_addresses { 
	
	my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );

	$list = $admin_list;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

	if($q->param('process') =~ m/remove/i){ 
	    my ( $d_count, $bl_count ) = $lh->admin_remove_subscribers(
	        {
	            -addresses => [@address],
				-type      => 'bounced_list',
	        }
	    );
		 my $uri =
		        $DADA::Config::S_PROGRAM_URL
		      . '?flavor=view_list'
		      . '&bounced_list_removed_from_list='
		      . $d_count
		      . '&type='
		      . $type
		      . '&black_list_add='
		      . $bl_count;
			print $q->redirect( -uri => $uri );
		
	}
	elsif($q->param('process') =~ m/move/i){ 

		my $m_count = 0; 
		
        for my $address (@address) {
			$lh->move_subscriber(
	            {
	                -email            => $address,
	                -from             => 'bounced_list',
	                -to               => 'list', 
	        		-mode             => 'writeover', 
	            }
			);
			$m_count++; 
		}
		
		# maybe if the bounce_list num_subscribers count is 0, we just go to the view_list screen.
		my $uri =
	        $DADA::Config::S_PROGRAM_URL
	      . '?flavor=view_list'
	      . '&type='
	      . $type
	      . '&bounced_list_moved_to_list_count='
	      . $m_count;
		print $q->redirect( -uri => $uri );
	 
	
	}

	
	else { 
		croak "I'm not sure what I'm supposed to do!"; 
	}
}



sub find_attachment_type {

	my $self = shift;

    my $filename = shift;
    my $a_type;

  my $attach_name =  $filename;
     $attach_name =~ s!^.*(\\|\/)!!;
     $attach_name =~ s/\s/%20/g;

   my $file_ending = $attach_name;
      $file_ending =~ s/.*\.//;

    require MIME::Types;
    require MIME::Type;

    if(($MIME::Types::VERSION >= 1.005) && ($MIME::Type::VERSION >= 1.005)){
        my ($mimetype, $encoding) = MIME::Types::by_suffix($filename);
        $a_type = $mimetype if ($mimetype && $mimetype =~ /^\S+\/\S+$/);  ### sanity check
    }else{
        if(exists($DADA::Config::MIME_TYPES{'.'.lc($file_ending)})) {
            $a_type = $DADA::Config::MIME_TYPES{'.'.lc($file_ending)};
        }else{
            $a_type = $DADA::Config::DEFAULT_MIME_TYPE;
        }
    }
    if(!$a_type){
        warn "attachment MIME Type never figured out, letting MIME::Lite handle this...";
        $a_type = 'AUTO';
    }

    return $a_type;
}

sub file_upload {

    my $upload_file = shift;

    my $fu   = CGI->new();
    my $file = $fu->param($upload_file);
    if ($file ne "") {
        my $fileName = $file;
           $fileName =~ s!^.*(\\|\/)!!;

        $fileName = uriescape($fileName);

        my $outfile = make_safer($DADA::Config::TMP . '/' . time . '_' . $fileName);

        open (OUTFILE, '>' . $outfile) or warn("can't write to '" . $outfile . "' because: $!");
        while (my $bytesread = read($file, my $buffer, 1024)) {
            print OUTFILE $buffer;
        }
        close (OUTFILE);
        chmod($DADA::Config::FILE_CHMOD, $outfile);
        return $outfile;
    }

}




sub pass_gen {

    my $pw = $q->param('pw');
    require DADA::Template::Widgets;

    if ( !$pw ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'pass_gen_screen.tmpl',
                -with   => 'list',
                -expr   => 1,
                -vars   => {},
            }
        );
        e_print($scrn);

    }
    else {

        require DADA::Security::Password;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'pass_gen_process_screen.tmpl',
                -with   => 'list',
                -expr   => 1,
                -vars   => {
                    encrypted_password =>
                      DADA::Security::Password::encrypt_passwd($pw),
                },
            }
        );
        e_print($scrn);
    }

}




sub setup_info {

    require DADA::Template::Widgets;

    my $root_password = $q->param('root_password') || '';

    my $from_control_panel = 0;

    my ( $admin_list, $root_login, $checksout ) = check_list_security(
        -cgi_obj         => $q,
        -Function        => 'setup_info',
        -manual_override => 1
    );
    if ( $checksout == 1 && $root_password eq '' ) {
        $from_control_panel = 1;
		$list               = $admin_list; 
    }


    if ( $checksout == 1 || root_password_verification($root_password) == 1 ) {

		# If we have a .dada_config file, this is a contemporary installation, we'll say.
        my $c_install = 0;
		# Not sure why I should do this check at all, if the "auto" dealy
		# could be set, anyways,
        if (
			(-e $DADA::Config::PROGRAM_CONFIG_FILE_DIR
            && -d $DADA::Config::PROGRAM_CONFIG_FILE_DIR) ||
			$DADA::Config::PROGRAM_CONFIG_FILE_DIR eq 'auto'
 		)
        {
            if ( -e $DADA::Config::CONFIG_FILE ) {
                $c_install = 1;
            }
        }


        my $config_file_contents = undef;
        if ( -e $DADA::Config::CONFIG_FILE ) {
            $config_file_contents =
              DADA::Template::Widgets::_slurp($DADA::Config::CONFIG_FILE);
        }
        my $config_pm_file_contents =
          DADA::Template::Widgets::_slurp('DADA/Config.pm');

        my $files_var_exist = 0;
        if ( -e $DADA::Config::FILES ) {
            $files_var_exist = 1;
        }

        my $config_vals = [];

        for (@DADA::Config::EXPORT_OK) {
            my $orig_name = $_;
            $_ =~ s/^(\$|\@|\%)//;
            my $sigil = $1;

			require Data::Dumper;

            my $var_val = undef;
 			if($sigil eq '$'){
				$var_val = Data::Dumper::Dumper( ${ $DADA::Config::{$_} } );
            }elsif($sigil eq '@'){
				$var_val = Data::Dumper::Dumper( \@{ $DADA::Config::{$_} } );
            }elsif($sigil eq '%'){
				$var_val = Data::Dumper::Dumper( \%{ $DADA::Config::{$_} } );
			}
			else {
				$var_val = '???';
			}

			#$var_val =~ s/^(.*?)\'//m;
           $var_val =~ s/^\$VAR(.*?)\= //;
           $var_val =~ s/^\'//;
		   $var_val =~ s/(\';|\'$)$//;
           $var_val =~ s/\;$//;

            push( @$config_vals, { name => $orig_name, value => $var_val } );
        } 

        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'setup_info_screen.tmpl',
				(
					$from_control_panel == 1 ? (
						-with           => 'admin',
			            -wrapper_params => {
			                -Root_Login => $root_login,
			                -List       => $list,
			            },
					) : (
						-with => 'list', 
					)
				),
                -vars   => {
                    FILES => $DADA::Config::FILES,
                    PROGRAM_ROOT_PASSWORD =>
                      $DADA::Config::PROGRAM_ROOT_PASSWORD,
                    MAILPROG => $DADA::Config::MAILPROG,
                    PROGRAM_CONFIG_FILE_DIR =>
                      $DADA::Config::PROGRAM_CONFIG_FILE_DIR,
                    PROGRAM_ERROR_LOG       => $DADA::Config::PROGRAM_ERROR_LOG,
					screen                  => 'setup_info',
                    c_install               => $c_install,
                    config_file_contents    => $config_file_contents,
                    config_pm_file_contents => $config_pm_file_contents,
                    files_var_exist         => $files_var_exist,
                    config_vals             => $config_vals,

                },
            }
        );
        e_print($scrn);

    }
    else {

        if ( $from_control_panel == 1 ) {

            # just doin' this again, w/o the manual override:
            check_list_security(
                -cgi_obj  => $q,
                -Function => 'setup_info',
            );
        }
        else {

            my $guess = $DADA::Config::PROGRAM_URL;
            $guess = $q->script_name()
              if $DADA::Config::PROGRAM_URL eq ""
                  || $DADA::Config::PROGRAM_URL eq
                  'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'
            ;    # default.

            my $incorrect_root_password = $root_password ? 1 : 0;
            require DADA::Template::Widgets;
            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'setup_info_login_screen.tmpl',
					-with   => 'list', 
                    -vars   => {
                        program_url_guess       => $guess,
                        incorrect_root_password => $incorrect_root_password,
                        PROGRAM_URL             => $DADA::Config::PROGRAM_URL,
                        S_PROGRAM_URL           => $DADA::Config::S_PROGRAM_URL,
                    },
                }
            );
            e_print($scrn);
        }

    }

}




sub reset_cipher_keys {

    my $root_password   = $q->param('root_password');
    my $root_pass_check = root_password_verification($root_password);

    if ( $root_pass_check == 1 ) {
        require DADA::Security::Password;
        my @lists = available_lists();

        require DADA::MailingList::Settings;

        for (@lists) {
            my $ls = DADA::MailingList::Settings->new( { -list => $_ } );
            $ls->save(
                { cipher_key => DADA::Security::Password::make_cipher_key() } );
        }

		require DADA::Template::Widgets; 
		my $scrn = DADA::Template::Widgets::wrap_screen(
			-screen => 'reset_cipher_keys_process.tmpl', 
			-with   => 'list', 
		);
       e_print($scrn);

    }
    else {
		require DADA::Template::Widgets; 
		my $scrn = DADA::Template::Widgets::wrap_screen(
			-screen => 'reset_cipher_keys.tmpl', 
			-with   => 'list', 
		);
        e_print($scrn);
    }

}


sub restore_lists {

    if ( root_password_verification( $q->param('root_password') ) ) {

        require DADA::MailingList::Settings;

        require DADA::MailingList::Archives;

        require DADA::MailingList::Schedules;

        # No SQL veresion, so don't worry about handing over the dbi handle...

        my @lists = available_lists();

        if ( $process eq 'true' ) {

            my $report = '';

            my %restored;
            for my $r_list (@lists) {
                if (   $q->param( 'restore_' . $r_list . '_settings' )
                    && $q->param( 'restore_' . $r_list . '_settings' ) == 1 )
                {
                    my $ls =
                      DADA::MailingList::Settings->new( { -list => $r_list } );
                    $ls->{ignore_open_db_error} = 1;
                    $report .=
                      $ls->restoreFromFile(
                        $q->param( 'settings_' . $r_list . '_version' ) );
                }
            }
            for my $r_list (@lists) {
                if (   $q->param( 'restore_' . $r_list . '_archives' )
                    && $q->param( 'restore_' . $r_list . '_archives' ) == 1 )
                {
                    my $ls =
                      DADA::MailingList::Settings->new( { -list => $r_list } );
                    $ls->{ignore_open_db_error} = 1;
                    my $la = DADA::MailingList::Archives->new(
                        { -list => $r_list, -ignore_open_db_error => 1 } );
                    $report .=
                      $la->restoreFromFile(
                        $q->param( 'archives_' . $r_list . '_version' ) );
                }
            }

            for my $r_list (@lists) {
                if (   $q->param( 'restore_' . $r_list . '_schedules' )
                    && $q->param( 'restore_' . $r_list . '_schedules' ) == 1 )
                {
                    my $mss = DADA::MailingList::Schedules->new(
                        { -list => $r_list, -ignore_open_db_error => 1 } );
                    $mss->{ignore_open_db_error} = 1;
                    $report .=
                      $mss->restoreFromFile(
                        $q->param( 'schedules_' . $r_list . '_version' ) );
                }
            }
            require DADA::Template::Widgets;
            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'restore_lists_complete.tmpl',
                    -with   => 'list',
                }
            );
            e_print($scrn);

        }
        else {

            my $backup_hist = {};
            for my $l (@lists) {
                my $ls = DADA::MailingList::Settings->new( { -list => $l } );
                $ls->{ignore_open_db_error} = 1;
                my $la = DADA::MailingList::Archives->new(
                    { -list => $l, -ignore_open_db_error => 1 } )
                  ;    #yeah, it's diff from MailingList::Settings - I'm stupid.

                my $mss = DADA::MailingList::Schedules->new(
                    { -list => $l, -ignore_open_db_error => 1 } );

                $backup_hist->{$l}->{settings} = $ls->backupDirs
                  if $ls->uses_backupDirs;
                $backup_hist->{$l}->{archives} = $la->backupDirs
                  if $la->uses_backupDirs;

                # DEV: Is this returning what I think it's supposed to?
                # Tests have to be written about this...
                $backup_hist->{$l}->{schedules} = $mss->backupDirs
                  if $mss->uses_backupDirs;
			#	require Data::Dumper; 
			#	warn '$l: ' . $l . '$n: ' . $mss->{name} . " backup dirs: " . Data::Dumper::Dumper($backup_hist->{$l}->{schedules}); 
				
            }

            my $restore_list_options = '';

            #    labels are for the popup menus, that's it    #
            my $labels = {};
			#use Data::Dumper; 
			#print $q->header(); 
			#print '<pre>'  . Data::Dumper::Dumper($backup_hist) . '</pre>'; 
            for my $l ( sort keys %$backup_hist ) {
 
               for my $bu( @{ $backup_hist->{$l}->{settings} } ) {
                    my ( $time_stamp, $appended ) = ( '', '' );
                    if ( $bu->{dir} =~ /\./ ) {
                        ( $time_stamp, $appended ) =
                          split( /\./, $bu->{dir}, 2 );
                    }
                    else {
                        $time_stamp = $bu->{dir};
                    }

                    $labels->{$l}->{settings}->{ $bu->{dir} } =
                        scalar( localtime($time_stamp) ) . ' ('
                      . $bu->{count}
                      . ' entries)';

                }

                for my $bu ( @{ $backup_hist->{$l}->{archives} } ) {

                    my ( $time_stamp, $appended ) = ( '', '' );
                    if ( $bu->{dir} =~ /\./ ) {
                        ( $time_stamp, $appended ) =
                          split( /\./, $bu->{dir}, 2 );
                    }
                    else {
                        $time_stamp = $bu->{dir};
                    }

                    $labels->{$l}->{archives}->{ $bu->{dir} } =
                        scalar( localtime($time_stamp) ) . ' ('
                      . $bu->{count}
                      . ' entries)';

                }
                for my $bu ( @{ $backup_hist->{$l}->{schedules} } ) {

                    my ( $time_stamp, $appended ) = ( '', '' );
                    if ( $bu->{dir} =~ /\./ ) {
                        ( $time_stamp, $appended ) =
                          split( /\./, $bu->{dir}, 2 );
                    }
                    else {
                        $time_stamp = $bu->{dir};
                    }

                    $labels->{$l}->{schedules}->{ $bu->{dir} } =
                        scalar( localtime($time_stamp) ) . ' ('
                      . $bu->{count}
                      . ' entries)';

                }
            }

            #

            for my $f_list ( keys %$backup_hist ) {

                $restore_list_options .=
                  $q->start_table( { -cellpadding => 5 } );
                $restore_list_options .= $q->h3($f_list);

                $restore_list_options .= $q->Tr(
                    $q->td(
                        { -valign => 'top' },
                        [
                            ( $q->p( $q->strong('Restore?') ) ),
                            ( $q->p( $q->strong('Backup Version*:') ) ),
                        ]
                    )
                );

                for my $t ( 'settings', 'archives', 'schedules' ) {

                    #		require Data::Dumper;
                    #		die Data::Dumper::Dumper(%labels);
                    my $vals = [];
                    for my $d( @{ $backup_hist->{$f_list}->{$t} } ) {
                        push( @$vals, $d->{dir} );
                    }

                    $restore_list_options .= $q->Tr(
                        $q->td(
                            [
                                (
                                    $q->p(
                                        $q->checkbox(
                                            -name => 'restore_' 
                                              . $f_list . '_'
                                              . $t,
                                            -id => 'restore_' 
                                              . $f_list . '_'
                                              . $t,
                                            -value => 1,
                                            -label => ' ',
                                        ),
                                        '<label for="'
                                          . 'restore_'
                                          . $f_list . '_'
                                          . $t . '">'
                                          . $t
                                          . '</label>'
                                    )
                                ),

                                ( scalar @{ $backup_hist->{$f_list}->{$t} } )
                                ? (

                                    (
                                        $q->p(
                                            $q->popup_menu(
                                                -name => $t . '_' 
                                                  . $f_list
                                                  . '_version',
                                                '-values' => $vals,
                                                -labels   => $labels->{$f_list}->{$t}
                                            )
                                        )
                                    ),

                                  )
                                : (

                                    (
                                        $q->p(
                                            { -class => 'error' },
                                            '-- No Backup Information Found --'
                                        ),
                                        $q->hidden(
                                            -name => $t . '_' 
                                              . $f_list
                                              . '_version',
                                            -value => 'just_remove_blank'
                                        )
                                    ),
                                ),
                            ]
                        )
                    );
					$vals = [];

                }
                $restore_list_options .= '</table>';
            }

            require DADA::Template::Widgets;
            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'restore_lists_options_screen.tmpl',
                    -with   => 'list',
                    -vars   => {
                        restore_list_options => $restore_list_options,
                        root_password =>
                          xss_filter( $q->param('root_password') ),
                    }
                }
            );
            e_print($scrn);

        }

    }
    else {
        require DADA::Template::Widgets;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            { -screen => 'restore_lists_screen.tmpl', -with => 'list', } );
        e_print($scrn);
    }

}


sub subscription_form {

    require DADA::Template::Widgets;
    return DADA::Template::Widgets::subscription_form({
        -list => $list,
    });

}

sub subscription_form_html {

    print $q->header();
    e_print(subscription_form());


}

sub subscription_form_js {
    print $q->header();
    my $js_form = js_enc(subscription_form());
    e_print('document.write(\'' . $js_form . '\');');
}

sub test_layout {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'test_layout'
    );
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'test_layout_screen.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
        }
    );
    e_print($scrn);

}





sub subscriber_help {

    if(!$list){
        &default;
        return;
    }

    if(check_if_list_exists(-List => $list) == 0){
        undef($list);
        &default;
        return;
    }

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get;

    require DADA::Template::Widgets;
    my $scrn =  DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'subscriber_help_screen.tmpl',
			-with   => 'list',
            -vars   => {
                     list             => $list,
                     list_name        => $li->{list_name},
                     list_owner_email => spam_me_not_encode($li->{list_owner_email}),
            }
    		}
		);
	e_print($scrn);

}




sub show_img {

    file_attachment(-inline_image_mode => 1);
}




sub file_attachment {


    # Weird:
    my ($admin_list, $root_login, $checksout) = check_list_security(-cgi_obj         => $q,
                                                                    -Function        => 'send_email',
                                                                   -manual_override => 1
                                                                   );

    my %args = (-inline_image_mode => 0, @_);

    if(check_if_list_exists(-List => $list) == 1){

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new({-list => $list});
        my $li = $ls->get;

        if($li->{show_archives} == 1 || $checksout == 1){

            if($li->{display_attachments} == 1 || $checksout == 1){

                require DADA::MailingList::Archives;

                my $la = DADA::MailingList::Archives->new({-list => $list});

                if($la->can_display_attachments){

                    if($la->check_if_entry_exists($q->param('id'))){

                        if($args{-inline_image_mode} == 1){

                            if($c->cached('view_inline_attachment.' . $list . '.' . $id . '.' . $q->param('cid') . '.cid')){ $c->show('view_inline_attachment.' . $list . '.' . $id . '.' . $q->param('cid') . '.cid'); return;}
                                my $scrn =  $la->view_inline_attachment(-id => $q->param('id'), -cid => $q->param('cid'));
								# Bettin' that it's binary (or at least, unencoded)
								print($scrn);
                                $c->cache('view_inline_attachment.' . $list . '.' . $id . '.' . $q->param('cid') . '.cid', \$scrn);
                                return;
                        }else{
                            if($c->cached('view_file_attachment.' . $list . '.' . $id . '.' . $q->param('filename'))){ $c->show('view_file_attachment.' . $list . '.' . $id . '.' . $q->param('filename')); return;}
                            my $scrn = $la->view_file_attachment(-id => $q->param('id'), -filename => $q->param('filename'));
							# Binary. Well, actually, *probably* - how would you figure out the content-type of an attached file?
							print($scrn);
                            $c->cache('view_file_attachment.' . $list . '.' . $id . '.' . $q->param('filename'), \$scrn);


                        }

                    } else {

                        user_error(-List => $list, -Error => "no_archive_entry");
                        return;
                    }

                } else {

                    user_error(-List => $list, -Error => "no_display_attachments");
                    return;
                }

            } else {

                user_error(-List => $list, -Error => "no_display_attachments");
                return;
            }

        } else {

            user_error(-List => $list, -Error => "no_show_archives");
            return;
        }

    } else {

        user_error(-List => $list, -Error => 'no_list');
        return;
    }

}




sub redirection {

    require DADA::Logging::Clickthrough;
    my $r = DADA::Logging::Clickthrough->new({-list => $q->param('list')});

	if(defined($q->param('key'))){

		my ($mid, $url, $atts) = $r->fetch($q->param('key'));

		   if(defined($mid) && defined($url)){
	       		$r->r_log(
					{ 
						-mid  => $mid, 
						-url  => $url, 
						-atts => $atts
					}
				);
			}
	    if($url){
			if($url =~ m/mailto\:/){ 
				print $q->header(
					-location => $url, 
					-status   => 200, 
				);
			}
	        print $q->redirect(-uri => $url);
	    	return;
	    }else{
	        print $q->redirect(-uri => $DADA::Config::PROGRAM_URL);
	    }
	}
	else {
		print $q->redirect(-uri => $DADA::Config::PROGRAM_URL);
	}
}




sub m_o_c {

    my $list = xss_filter( $q->param('list') );

    if ( check_if_list_exists( -List => $list ) == 0 ) {
        carp "list: '$list' does not exist, aborted logging of open message\n" . 
			 '$ENV{PATH_INFO}: ' . $ENV{PATH_INFO}; 

    }
    else {
        require DADA::Logging::Clickthrough;
        my $r =
          DADA::Logging::Clickthrough->new( { -list => $q->param('list') } );
        if ( defined( $q->param('mid') ) ) {
            $r->o_log( { -mid => $q->param('mid'), } );
        }
    }
    require MIME::Base64;
    print $q->header('image/png');

    # a simple, 1px png image.
    my $str = <<EOF
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAABGdBTUEAANbY1E9YMgAAABl0RVh0
U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAGUExURf///wAAAFXC034AAAABdFJOUwBA
5thmAAAADElEQVR42mJgAAgwAAACAAFPbVnhAAAAAElFTkSuQmCC
EOF
;
    print MIME::Base64::decode_base64($str);

}



sub js {
    my $js_lib = xss_filter( $q->param('js_lib') );

    my @allowed_js = qw(

	  dada_mail_admin_js.js

	  prototype.js
      builder.js
      controls.js
      dragdrop.js
      effects.js
      slider.js
      sound.js
      unittest.js
      scriptaculous.js
      modalbox.js
      
      prototype_scriptaculous_package.js
      tiny_mce_config.js

    );

    my %lt = ();
    for (@allowed_js) { $lt{$_} = 1; }

    require DADA::Template::Widgets;
#warn '$js_lib ' . $js_lib;

    if ( $lt{$js_lib} == 1 ) {
        if ( $c->cached('js/' . $js_lib . '.scrn') ) {
			$c->show('js/' . $js_lib . '.scrn'); return;
		}
        my $r = $q->header('text/javascript');
        $r .= DADA::Template::Widgets::screen( { -screen => 'js/' . $js_lib } );
        e_print($r);
        $c->cache( 'js/' . $js_lib . '.scrn', \$r );

    }
    else {

        # nothing for now...
    }

}

sub css {

	my $css_file = xss_filter( $q->param('css_file') );
    
	my $allowed_css = {
		'default.css' => 1, 
		'modalbox.css'    => 1, 
	};
	if(!exists($allowed_css->{$css_file})){ 
		return; 
	}
	
	require DADA::Template::Widgets;
    e_print( $q->header('text/css') ); 
	e_print(  DADA::Template::Widgets::screen( { -screen => 'css/' . $css_file } ));
    
}




sub img {

    my $img_name = xss_filter( $q->param('img_name') );

    my @allowed_images = qw(

      3f0.png
      badge_blinklist.png
      badge_blogmarks.png
      badge_delicious.png
      badge_digg.png
      badge_fark.png
      badge_feed.png
      badge_furl.png
      badge_magnolia.png
      badge_newsvine.png
      badge_reddit.png
      badge_segnalo.png
      badge_simpy.png
      badge_smarking.png
      badge_spurl.png
      badge_wists.png
      badge_yahoo.png

	  centeredmenu.gif
	
      cff.png

      dada_mail_logo.png

      dada_mail_screenshot.jpg

	header_bg.gif

      spinner.gif

    );

    my %lt = ();
    for (@allowed_images) { $lt{$_} = 1; }

    require DADA::Template::Widgets;

    if ( $lt{$img_name} == 1 ) {
        if ( $c->cached( 'img/' . $img_name ) ) {
            $c->show( 'img/' . $img_name );
            return;
        }
        my $r;
        if ( $img_name =~ m/\.png$/ ) {
            $r = $q->header('image/png');
        }
        elsif ( $img_name =~ m/\.gif$/ ) {
            $r = $q->header('image/gif');
        }
        elsif ( $img_name =~ m/\.jpg$/ ) {
            $r = $q->header('image/jpg');
        }
		else { 
			die "can't show image!"; 
		}
        $r .= DADA::Template::Widgets::_raw_screen(
            {
                -screen   => 'img/' . $img_name,
                -encoding => 0,
            }
        ); 
        print $r;
        $c->cache( 'img/' . $img_name, \$r );

    }
    else {

        # nothing for now...
    }

}




sub  captcha_img {

    my $img_str = xss_filter($q->param('img_string'));

    if(-e $DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png'){

            print $q->header('image/png');
            open(IMG,  '< ' . $DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png') or die $!;
             {
            #slurp it all in
           local $/ = undef;
            print <IMG>;

            }
        close (IMG) or die $!;

        chmod($DADA::Config::FILE_CHMOD , make_safer($DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png'));

        my $success = unlink(make_safer($DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png'));
        warn 'Couldn\'t delete file, ' . $DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png' if $success == 0;

    }else{

        &default();
    }
}




sub ver {

    print $q->header();
    e_print($DADA::Config::VER);

}



sub author {

    print $q->header();
    e_print("Dada Mail is originally written by Justin Simoni");

}

sub profile_login {

	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){
		default();
		return
	}

	if($DADA::Config::PROFILE_OPTIONS->{enabled} != 1){
		default();
		return
	}
	require DADA::Profile; 
	###
	my $all_errors = [];
	my $named_errs = {};
	my $errors     = $q->param('errors');
	for(@$errors){
		$named_errs->{'error_' . $_} = 1 ;
		push(@$all_errors, {error => $_});
	}
	###

	require DADA::Profile::Session;
	my $prof_sess = DADA::Profile::Session->new;

	if($q->param('process') != 1){

	if($prof_sess->is_logged_in({-cgi_obj => $q})){
		print $q->redirect(
			{
				-uri => $DADA::Config::PROGRAM_URL . '/profile/',
			}
			);
		return;
	}
	else {
			my $scrn = '';
			my $can_use_captcha = 0;
			my $CAPTCHA_string  = '';
			my $cap             = undef;
			if($DADA::Config::PROFILE_OPTIONS->{enable_captcha} == 1){
				eval {
					require DADA::Security::AuthenCAPTCHA;
					$cap = DADA::Security::AuthenCAPTCHA->new;
				};
				if(!$@){
					$can_use_captcha = 1;
				}
			}

		   if($can_use_captcha == 1){

            	$CAPTCHA_string = $cap->get_html($DADA::Config::RECAPTCHA_PARAMS->{public_key});
			}

   		    require DADA::Template::Widgets;
		    $scrn =  DADA::Template::Widgets::wrap_screen(
				{
					-screen => 'profile_login.tmpl',
					-with   => 'list', 
					-expr => 1,
					-vars   => {
						errors                       => $all_errors,
						%$named_errs,
						email	                     => xss_filter($q->param('email'))            || '',
						email_again                  => xss_filter($q->param('email_again'))      || '',
						error_profile_login          => $q->param('error_profile_login')          || '',
						error_profile_register       => $q->param('error_profile_register')       || '',
						error_profile_activate       => $q->param('error_profile_activate')       || '',
						error_profile_reset_password => $q->param('error_profile_reset_password') || '',
						password_changed             => $q->param('password_changed')			  || '',
						logged_out                   => $q->param('logged_out') || '',
						can_use_captcha              => $can_use_captcha,
						CAPTCHA_string               => $CAPTCHA_string,
						welcome                      => $q->param('welcome')					   || '',
						removal                      => $q->param('removal')                       || '',
						%{DADA::Profile::feature_enabled()}
					}, 
				}
			);
			e_print($scrn);
		}
    }
	else {
		my ($status, $errors) = $prof_sess->validate_profile_login(
			{
				-email    => $q->param('email'),
				-password => $q->param('password'),

			},
		);

		if($status == 1){
			my $cookie = $prof_sess->login(
				{
					-email    => $q->param('email'),
					-password => $q->param('password'),
				},
			);
			#DEV: encoding?
			print $q->header(
				-cookie  => [$cookie],
                -nph     => $DADA::Config::NPH,
                -Refresh =>'0; URL=' . $DADA::Config::PROGRAM_URL . '/profile/'
			);

            print $q->start_html(
				-title=>'Logging in...',
                -BGCOLOR=>'#FFFFFF'
            );
            print $q->p($q->a({-href => $DADA::Config::PROGRAM_URL . '/profile/'}, 'Logging in...'));
            print $q->end_html();
			return;
		}
		else {
			my $p_errors = [];
			for(keys %$errors){
				if($errors->{$_} == 1){
					push(@$p_errors, $_);
				}
			}
			$q->param('errors',              $p_errors);
			$q->param('process',             0        );
			$q->param('error_profile_login', 1        );
			profile_login();
		}
	}

}

sub profile_register {

	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		
		default();
		return;
	}
	require DADA::Profile;
	my $prof = DADA::Profile->new({-email => $email});

	if(! DADA::Profile::feature_enabled('register') == 1){ 
		default();
		return;
	}

	my $email       = strip(cased(xss_filter($q->param('email'      ))));
	my $email_again = strip(cased(xss_filter($q->param('email_again'))));
	my $password    = strip(xss_filter($q->param('password')));



	if($prof->exists() &&
	   !$prof->is_activated()
	){
		$prof->remove();
	}

	my($status, $errors) = $prof->is_valid_registration(
		{
			-email 		               => $email,
			-email_again               => $email_again,
			-password                  => $password,
	        -recaptcha_challenge_field => $q->param( 'recaptcha_challenge_field' ),
	        -recaptcha_response_field  => $q->param( 'recaptcha_response_field'),
		}
	);
	if($status == 0){
		my $p_errors = [];
		for(keys %$errors){
			if($errors->{$_} == 1){
				push(@$p_errors, $_);
			}
		}
		$q->param('errors',                 $p_errors);
		$q->param('error_profile_register',  1        );
		profile_login();
		return;
	}
	else {
		$prof->setup_profile(
			{
				-password    => $password,
			}
		);
		my $scrn = '';
	    require DADA::Template::Widgets;
	    $scrn =  DADA::Template::Widgets::wrap_screen(
			{
				-screen => 'profile_register.tmpl',
				-with   => 'list', 
				-vars   => {

					'profile.email' => $email,
				}
			}
		);
		e_print($scrn);

	}
}

sub profile_activate {

	
	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default();
		return
	}

	require DADA::Profile;
	if(! DADA::Profile::feature_enabled('register') == 1){ 
		default();
		return;
	}
	
	my $email       = strip(cased(xss_filter($q->param('email'))));
	my $auth_code = xss_filter($q->param('auth_code'));



	my $prof = DADA::Profile->new({-email => $email});

	if($email && $auth_code){

		my ($status, $errors) = $prof->is_valid_activation(
			{
				-auth_code => xss_filter($q->param('auth_code')) || '',
			}
		);
		if($status == 1){
			$prof->activate;
			my $profile = $prof->get();
			$q->param('welcome',  1);
			profile_login();
		}
		else {
			my $p_errors = [];
			for(keys %$errors){
				if($errors->{$_} == 1){
					push(@$p_errors, $_);
				}
			}
			$q->param('errors',                 $p_errors);
			$q->param('error_profile_activate', 1        );
			profile_login();
			return;
		}
	}
	else {
			die 'no email or auth code!';
	}
}

sub profile_help {

	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default();
		return;
	}

	require DADA::Profile;
	if(! DADA::Profile::feature_enabled('help') == 1){ 
		default();
		return;
	}

    require DADA::Template::Widgets;
    my $scrn =  DADA::Template::Widgets::wrap_screen(
		{
			-with   => 'list', 
			-screen => 'profile_help.tmpl',
			-vars   => {
			}
		}
	);
	e_print($scrn);
}


sub profile {

	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default();
		return;
	}

	require DADA::Profile::Session;
	my $prof_sess = DADA::Profile::Session->new;


	if($prof_sess->is_logged_in({-cgi_obj => $q})){
		my $email = $prof_sess->get({-cgi_obj => $q});

		require DADA::Profile::Fields;
		require DADA::Profile;

		my $prof              = DADA::Profile->new({-email => $email});
		my $dpf               = DADA::Profile::Fields->new({-email => $email});
		my $subscriber_fields =  $dpf->{manager}->fields(
			{
				-show_hidden_fields => 0,
			}
		);
		my $field_attr         = $dpf->{manager}->get_all_field_attributes;
		my $email_fields      = $dpf->get;

		if($q->param('process') eq 'edit_subscriber_fields'){

			my $edited = {};
			for(@$subscriber_fields){
				$edited->{$_} = xss_filter($q->param($_));
				# This is better than nothing, but it's very lazy -
				# Make sure that the length is less than 10k.
				if(length($edited->{$_}) > 10240){
					# Sigh.
					die $DADA::CONFIG::PROGRAM_NAME . ' ' . $DADA::Config::VER . ' Error! Attempting to save Profile Field with too large of a value!';
				}
			}
			
			# DEV: This is somewhat of a hack - so that we don't writeover hidden fields, we re-add them, here
			# A little kludgey. 
			
			for my $field(@{$dpf->{manager}->fields({-show_hidden_fields => 1})}){
				if($field =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/){ 
	      			$edited->{$field} = $email_fields->{$field},
				}
			}
			$dpf->insert(
				{
					-fields => $edited,
				}
			);
			print $q->redirect({-uri => $DADA::Config::PROGRAM_URL . '?f=profile&edit=1'});

		}
		elsif($q->param('process') eq 'change_password'){
			
			if(! DADA::Profile::feature_enabled('change_password') == 1){ 
				default();
				return;
			}
			
			my $new_password       = xss_filter($q->param('password'));
			my $again_new_password = xss_filter($q->param('again_password'));
			# DEV: See?! Why are we doing this manually? Can we use is_valid_registration() perhaps?
			if(length($new_password) > 0 && $new_password eq $again_new_password){
				$prof->update(
					{
						-password => $new_password,
					}
				);
				$q->param('password_changed', 1);
				$q->delete('process');

				require DADA::Profile::Session;
				my $prof_sess = DADA::Profile::Session->new->logout;
				profile_login();
				
				# DEV: This is going to get repeated quite a bit..
				require DADA::Profile::Htpasswd;
				foreach my $p_list(@{$prof->subscribed_to}) { 
					my $htp     = DADA::Profile::Htpasswd->new({-list => $p_list});
					for my $id(@{$htp->get_all_ids}) {  
						$htp->setup_directory({-id => $id});
					}
				}
				#
				
				
				
			}
			else {
				$q->param('errors', 1);
				$q->param('errors_change_password', 1);
				$q->delete('process');
				profile();
			}

		}
		elsif($q->param('process') eq 'update_email'){

			if(! DADA::Profile::feature_enabled('update_email_address') == 1){ 
				default();
				return;
			}

			# So, send the confirmation email for update to the NEW email address?
			# What if the OLD email address is activated? Guess we'll have to go with the
			# NEW email address. The only problem is if someone gains access to the account
			# changes the address as their own, etc.
			# But, they'd still need access to the account...

			# So,
			# * Send confirmation out
			# * Display report if there are any problems.
			#
			# Old AND New address subscribed to a list:
			#
			# At the moment, if a subscriber is already subscribed, we
			# can give the option (only option) to remove the old address
			# And keep the current address :
			#
			# New Address isn't allowed to subscribe
			#
			# Keep old address, profile for old address will be gone
			# Option to unsubscribe old address
			# Option to tell list owner to unsubscribe old address? (Perhaps)
			#


			# If we haven't confirmed....

				# Check to make sure the email address is valid.

				# Valid? OK! send the confirmaiton email

				# Not Valid? Geez we better tell someone.
			my $updated_email = cased(xss_filter($q->param('updated_email')));

				# Oh. What if there is already a profile for this address?

			my ($status, $errors) = $prof->is_valid_update_profile_email(
				{
					-updated_email => $updated_email,
				}
			);
			if($status == 0){

				my $p_errors = [];
				for(keys %$errors){
					if($errors->{$_} == 1){
						#push(@$p_errors, $_);
						$q->param('error_' . $_, 1);
					}
				}
			#	$q->param('errors',              $p_errors);
			    $q->param('errors', 1);
				$q->param('process', 0);
				$q->param('errors_update_email', 1);
				$q->param('updated_email', $updated_email);
				profile();
			}
			else {

				$prof->confirm_update_profile_email(
					{
						-updated_email => $updated_email,
					}
				);
				
				my $info = $prof->get({-dotted => 1});
				my $scrn = '';
			    require DADA::Template::Widgets;
			    $scrn =  DADA::Template::Widgets::wrap_screen(
					{
						-with   => 'list', 
						-screen => 'profile_update_email_auth_send.tmpl',
						-vars   => {
							%$info,
						}
					}
				);
				e_print($scrn);
			}
			# Oh! We've confirmed?

				# We've got to make sure that we can switch the email address in each
				# various list - perhaps the new address is blacklisted? Ack. that would be stinky
				# Another problem: What if the new email address is already subscribed?
				# May need a, "replace" function.
				# Sigh...

			# That's it.
		}
		elsif ($q->param('process') eq 'delete_profile'){

			if(! DADA::Profile::feature_enabled('delete_profile') == 1){ 
				default();
				return;
			}
			
			$prof_sess->logout;
			$prof->remove;

			undef $prof;
			undef $prof_sess;

			$q->param('f', 'profile_login');
			$q->param('removal', 1);

			profile_login();

			return;

		}
		else {

		   	my $fields = [];
			for my $field(@$subscriber_fields){
		        push(@$fields, {
					name          => $field,
					label		  => $field_attr->{$field}->{label},
					value         => $email_fields->{$field},
					}
				);
		    }

		   my $subscriptions = $prof->subscribed_to({-html_tmpl_params => 1}),
		   my $filled = [];
		   my $has_subscriptions = 0;

		   my $protected_directories = [];
		
		   for my $i(@$subscriptions){

				if($i->{subscribed} == 1){
					$has_subscriptions = 1;
				}

				require DADA::MailingList::Settings;
				my $ls = DADA::MailingList::Settings->new({-list => $i->{list}});
				my $li = $ls->get(-dotted => 1);
				# Ack, this is very awkward:

				#  Ack, this is very awkward:
				require DADA::Template::Widgets;
				$li = DADA::Template::Widgets::webify_and_santize(
					{
						-vars        => $li,
						-to_sanitize => [qw(list_settings.list_owner_email list_settings.info list_settings.privacy_policy )],
					}
				);
				
				
				require DADA::Profile::Htpasswd;
				my $htp = DADA::Profile::Htpasswd->new({-list => $i->{list}}); 
				my $l_p_d = $htp->get_all_entries; 
				if(scalar(@$l_p_d) > 0){ 
					@$protected_directories = (@$protected_directories, @$l_p_d); 
				}
				push(@$filled, 
					{%{$i}, 
					%{$li}, 
					PROGRAM_URL => $DADA::Config::PROGRAM_URL})
			}
			my $scrn = '';
		    require DADA::Template::Widgets;
		    $scrn .=  DADA::Template::Widgets::wrap_screen(
				{
					-screen => 'profile_home.tmpl',
					-with   => 'list', 
					-expr => 1,
					-vars   => {
						errors                      => $q->param('errors') || 0,
						'profile.email'             => $email,
						subscriber_fields           => $fields,
						subscriptions               => $filled,
						has_subscriptions           => $has_subscriptions,
						welcome                     => $q->param('welcome')                     || '',
						edit                        => $q->param('edit')                        || '',
						errors_change_password      => $q->param('errors_change_password') || '',
						errors_update_email         => $q->param('errors_update_email') || '',
						error_invalid_email         => $q->param('error_invalid_email') || '',
						error_profile_exists        => $q->param('error_profile_exists') || '',
						updated_email      		    => $q->param('updated_email') || '',

						gravators_enabled            => $DADA::Config::PROFILE_OPTIONS->{gravatar_options}->{enable_gravators},
						gravatar_img_url             => gravatar_img_url(
															{
																-email                => $email,
																-default_gravatar_url => $DADA::Config::PROFILE_OPTIONS->{gravatar_options}->{default_gravatar_url},
															}
														),
						protected_directories => $protected_directories, 
						%{DADA::Profile::feature_enabled()},

						
					}
				}
			);
			e_print($scrn);
		}
	}
	else {
		$q->param('error_profile_login', 1              );
		$q->param('errors',     ['not_logged_in']);
		profile_login();
		return;
	}

}

sub profile_logout {

	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default();
		return
	}

	require DADA::Profile::Session;
	my $prof_sess = DADA::Profile::Session->new;

	$prof_sess->logout;
	print $q->header(
		-cookie => [$prof_sess->logout_cookie],
        -nph     => $DADA::Config::NPH,
        -Refresh =>'0; URL=' . $DADA::Config::PROGRAM_URL . '?f=profile_login&logged_out=1',
	);
    print $q->start_html(
		-title=>'Logging Out...',
        -BGCOLOR=>'#FFFFFF'
    );
    print $q->p($q->a({-href => $DADA::Config::PROGRAM_URL . '?f=profile_login&logged_out=1'}, 'Logging Out...'));
    print $q->end_html();
	return;

}


sub profile_reset_password {

	if(
		$DADA::Config::PROFILE_OPTIONS->{enabled}    != 1      ||
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){
		default();
		return;
	}

	require DADA::Profile;
	if(! DADA::Profile::feature_enabled('password_reset') == 1){ 
		default();
		return;
	}

	my $email     = cased(xss_filter($q->param('email')));
	my $password  = xss_filter($q->param('password'))  || undef;
	my $auth_code = xss_filter($q->param('auth_code')) || undef;

	require DADA::Profile;
	my $prof = DADA::Profile->new({-email => $email});

	if($email){
		if($auth_code){
			my ($status, $errors) = $prof->is_valid_activation(
				{
					-auth_code => $auth_code,
				}
			);
			if($status == 1){
				if(!$password){
				    require DADA::Template::Widgets;
				    my $scrn =  DADA::Template::Widgets::wrap_screen(
						{
							-screen => 'profile_reset_password.tmpl',
							-with   => 'list', 
							-vars   => {
								email     => $email,
								auth_code => $auth_code,
							}
						}
					);
					e_print($scrn);
				}
				else {
					# Reset the Password
					$prof->update(
						{
							-password => $password,
						}
					);
					# Reactivate the Account
					$prof->activate();
					# Log The person in.
					# Probably pass the needed stuff to profile_login via CGI's param()
					$q->param('email',    $email);
					$q->param('password', $password);
					$q->param('process',  1);

					# and just called the subroutine itself. Hazzah!
					profile_login();
					# Go home, kiss the wife.
				}
			}
			else {
				my $p_errors = [];
				for(keys %$errors){
					if($errors->{$_} == 1){
						push(@$p_errors, $_);
					}
				}
				$q->param('error_profile_reset_password', 1);
				$q->param('errors', $p_errors);
				profile_login();
			}
		}
		else {


			if($prof->exists()){

				$prof->send_profile_reset_password_email();
				$prof->activate;
			    require DADA::Template::Widgets;
			    my $scrn =  DADA::Template::Widgets::wrap_screen(
					{
						-screen => 'profile_reset_password_confirm.tmpl',
						-with   => 'list', 
						-vars   => {
							email           => $email,
							'profile.email' => $email,
						}
					}
				);
				e_print($scrn);

			}
			else {
				$q->param('error_profile_reset_password', 1);
				$q->param('errors', ['unknown_user']);
				$q->param('email', $email);
				profile_login();
			}
		}
    }
	else {
		print $q->redirect({
			-uri => $DADA::Config::PROGRAM_URL . '/profile_login/',
		});
	}
}


sub profile_update_email {

	my $auth_code = xss_filter($q->param('auth_code'));
	my $email     = cased(xss_filter($q->param('email')));
	my $confirmed = xss_filter($q->param('confirmed'));

	require DADA::Profile;
	
	if(! DADA::Profile::feature_enabled('update_email_address') == 1){ 
		default();
		return;
	}
	
	
	my $prof = DADA::Profile->new({-email => $email});
	my $info = $prof->get;

	my ($status, $errors) = $prof->is_valid_update_profile_activation({
		-update_email_auth_code => $auth_code,
	});

	if($status == 1){

		my $profile_info = $prof->get({-dotted => 1});
		my $subs = $prof->profile_update_email_report;
		#require Data::Dumper;
		#die Data::Dumper::Dumper($subs);
		if($confirmed == 1){

			# This should probably go in the update_email method...
			require DADA::MailingList::Subscribers;
			for my $in_list(@$subs) {
				my $lh = DADA::MailingList::Subscribers->new(
					{
						-list => $in_list->{'list_settings.list'},
					}
				);
				$lh->remove_subscriber(
					{
						-email => cased($profile_info->{'profile.email'})
					}
				);
				$lh->add_subscriber(
					{
						-email => cased($profile_info->{'profile.update_email'})
					}
				);
			}
			$prof->update_email;
			#/ This should probably go in the update_email method...

			$prof->send_update_email_notification(
				{ 
					-prev_email => cased($profile_info->{'profile.email'}), 
				}
			);

			# Now, just log us in:
			require DADA::Profile::Session;
			my $prof_sess = DADA::Profile::Session->new;
			if($prof_sess->is_logged_in){
				$prof_sess->logout;
			}
			undef $prof_sess;

			my $prof_sess = DADA::Profile::Session->new;
			my $cookie = $prof_sess->login(
				{
					-email    => $profile_info->{'profile.update_email'},
					-no_pass  => 1,
				}
			);

			print $q->header(
				-cookie  => [$cookie],
                -nph     => $DADA::Config::NPH,
                -Refresh =>'0; URL=' . $DADA::Config::PROGRAM_URL . '/profile/'
			);
            print $q->start_html(
				-title=>'Logging in...',
                -BGCOLOR=>'#FFFFFF'
            );
            print $q->p($q->a({-href => $DADA::Config::PROGRAM_URL . '/profile/'}, 'Logging in...'));
            print $q->end_html();
			return;

		}
		else {

			# I should probably also just, log this person in...

			require DADA::Template::Widgets;
			 my $scrn = DADA::Template::Widgets::wrap_screen(
					{
						-screen => 'profile_update_email_confirm.tmpl',
						-with   => 'list', 
						-vars   => {
							auth_code     => $auth_code,
							subscriptions => $subs,
							%$profile_info,
						},
					}
				);
			   e_print($scrn);

		}
	}
	else {

		require    DADA::Template::Widgets;
		my $scrn = DADA::Template::Widgets::wrap_screen(
				{
					-screen => 'profile_update_email_error.tmpl',
					-with  => 'list', 
					-vars   => {
					},
				}
			);
		   e_print($scrn);

	}
}


sub what_is_dada_mail {

    require DADA::Template::Widgets;
    my $scrn =  DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'what_is_dada_mail.tmpl',
			-with   => 'list', 
		}
	);
    e_print($scrn);

}

sub END {
	if($DADA::Config::MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION == 1){
		require DADA::Mail::MailOut;
		        DADA::Mail::MailOut::monitor_mailout({-verbose => 0});
	}
}



__END__

=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

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
