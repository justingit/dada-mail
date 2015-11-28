#!/usr/bin/perl
package DADA::App;
use base 'CGI::Application';

#use CGI::Application::Plugin::DebugScreen;

use strict;

use Encode qw(encode decode);


BEGIN {
    if ( $] > 5.008 ) {
        require Errno;
        require Config;
    }
}
use FindBin; 
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../../";
use lib "$FindBin::Bin/../../../";
use lib "$FindBin::Bin/../DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

#---------------------------------------------------------------------#
use Carp qw(carp croak);

#$CARP::Verbose = 1;

#---------------------------------------------------------------------#

use DADA::Config 9.0.0;

use DADA::App::ScreenCache;
my $c = DADA::App::ScreenCache->new;
use DADA::App::Guts;
use DADA::MailingList::Subscribers;
use Try::Tiny;
use DADA::Template::HTML;
use DADA::Template::Widgets;

#---------------------------------------------------------------------#

sub cgiapp_init {
    
    $CGI::Application::LIST_CONTEXT_WARN = 0;
    
    my $self = shift;
    $self->query->charset($DADA::Config::HTML_CHARSET);

    # Kinda Weird.
    $DADA::Template::Widgets::q = $self->query;
    $DADA::Template::HTML::q    = $self->query;

}

sub cgiapp_postrun {
    my ( $self, $output_ref ) = @_;
    $$output_ref = safely_encode($$output_ref);
}

sub setup {

    my $self = shift;

    $self->start_mode('default');
    $self->mode_param('flavor');
    $self->error_mode('yikes');

    # So, maybe the, "schedules" runmode should be something quite random, that can also be reset?
    # And then implement some sort of limit on how many times a schedule can be run?
    # And then, and then! Have a screen showing:
    # * an example cronjob
    # * a way to force the schedule to run
    # *

    my $sched_flavor = $DADA::Config::SCHEDULED_JOBS_OPTIONS->{scheduled_jobs_flavor};

    $self->run_modes(
        'plugins'                                     => \&plugins,
        $sched_flavor                                 => \&schedules,
        'scheduled_jobs'                              => \&scheduled_jobs,
        'default'                                     => \&default,
        'subscribe'                                   => \&subscribe,
        'restful_subscribe'                           => \&restful_subscribe,
        'api'                                         => \&api,
        'token'                                       => \&token,
        'unsubscribe'                                 => \&unsubscribe,
        'unsubscription_request'                      => \&unsubscription_request,
		'unsubscribe_email_lookup'                    => \&unsubscribe_email_lookup, 
        'report_abuse'                                => \&report_abuse,
        'login'                                       => \&login,
        'logout'                                      => \&logout,
        'log_into_another_list'                       => \&log_into_another_list,
        'change_login'                                => \&change_login,
        'new_list'                                    => \&new_list,
        'change_info'                                 => \&change_info,
        'html_code'                                   => \&html_code,
        'preview_jquery_plugin_subscription_form'     => \&preview_jquery_plugin_subscription_form,
        'admin_help'                                  => \&admin_help,
        'delete_list'                                 => \&delete_list,
        'view_list'                                   => \&view_list,
        'mass_update_profiles'                        => \&mass_update_profiles,
        'domain_breakdown_json'                       => \&domain_breakdown_json,
        'search_list_auto_complete'                   => \&search_list_auto_complete,
        'list_activity'                               => \&list_activity,
        'sub_unsub_trends_json'                       => \&sub_unsub_trends_json,
        'view_bounce_history'                         => \&view_bounce_history,
        'subscription_requests'                       => \&subscription_requests,
        'unsubscription_requests'                     => \&unsubscription_requests,
        'remove_all_subscribers'                      => \&remove_all_subscribers,
        'view_list_options'                           => \&list_cp_options,
        'membership'                                  => \&membership,
        'also_member_of'                              => \&also_member_of,
        'admin_change_profile_password'               => \&admin_change_profile_password,
        'admin_profile_delivery_preferences'          => \&admin_profile_delivery_preferences,
        'validate_update_email'                       => \&validate_update_email,
        'validate_remove_email'                       => \&validate_remove_email,
        'mailing_list_history'                        => \&mailing_list_history,
        'membership_activity'                         => \&membership_activity,
        'export_membership_history'                   => \&export_membership_history,
        'add'                                         => \&add,
        'check_status'                                => \&check_status,
        'email_password'                              => \&email_password,
        'add_email'                                   => \&add_email,
        'delete_email'                                => \&delete_email,
        'subscription_options'                        => \&subscription_options,
        'admin_menu_drafts_notification'              => \&admin_menu_drafts_notification,
        'admin_menu_subscriber_count_notification'    => \&admin_menu_subscriber_count_notification,
        'admin_menu_mailing_monitor_notification'     => \&admin_menu_mailing_monitor_notification,
        'admin_menu_archive_count_notification'       => \&admin_menu_archive_count_notification,
        'admin_menu_mail_sending_options_notification' => \&admin_menu_mail_sending_options_notification,
        'admin_menu_mailing_sending_mass_mailing_options_notification' => \&admin_menu_mailing_sending_mass_mailing_options_notification, 
        'admin_menu_bounce_handler_notification'      => \&admin_menu_bounce_handler_notification,
        'admin_menu_tracker_notification'             => \&admin_menu_tracker_notification,
        'send_email'                                  => \&send_email,
        'send_email_button_widget'                    => \&send_email_button_widget, 
        'mass_mailing_schedules_preview'                 => \&mass_mailing_schedules_preview, 
        'draft_message_values'                        => \&draft_message_values, 
        'ckeditor_template_tag_list'                  => \&ckeditor_template_tag_list,
        'draft_saved_notification'                    => \&draft_saved_notification,
        'drafts'                                      => \&drafts,
        'delete_drafts'                               => \&delete_drafts,
        'create_from_stationery'                      => \&create_from_stationery,
        'message_body_help'                           => \&message_body_help,
        'url_message_body_help'                       => \&url_message_body_help,
        'preview_message_receivers'                   => \&preview_message_receivers,
        'sending_monitor'                             => \&sending_monitor,
        'print_mass_mailing_log'                      => \&print_mass_mailing_log,
        'remove_subscribers'                          => \&remove_subscribers,
        'process_bouncing_addresses'                  => \&process_bouncing_addresses,
        'edit_template'                               => \&edit_template,
        'view_archive'                                => \&view_archive,
        'display_message_source'                      => \&display_message_source,
        'purge_all_archives'                          => \&purge_all_archives,
        'delete_archive'                              => \&delete_archive,
        'edit_archived_msg'                           => \&edit_archived_msg,
        'archive'                                     => \&list_archive,
        'archive_bare'                                => \&archive_bare,
        'archive_rss'                                 => \&archive_rss,
        'archive_atom'                                => \&archive_atom,
        'manage_script'                               => \&manage_script,
        'change_password'                             => \&change_password,
        'text_list'                                   => \&text_list,
        'archive_options'                             => \&archive_options,
        'adv_archive_options'                         => \&adv_archive_options,
        'back_link'                                   => \&back_link,
        'edit_type'                                   => \&edit_type,
        'edit_html_type'                              => \&edit_html_type,
        'list_options'                                => \&list_options,
        'web_services'                                => \&web_services,
        'mail_sending_options'                         => \&mail_sending_options,
        'amazon_ses_verify_email'                     => \&amazon_ses_verify_email,
        'amazon_ses_get_stats'                        => \&amazon_ses_get_stats,
        'mailing_sending_mass_mailing_options'                    => \&mailing_sending_mass_mailing_options,
        'previewBatchSendingSpeed'                    => \&previewBatchSendingSpeed,
        'mail_sending_advanced_options'                     => \&mail_sending_advanced_options,
        'filter_using_black_list'                     => \&filter_using_black_list,
        'search_archive'                              => \&search_archive,
        'send_archive'                                => \&send_archive,
        'list_invite'                                 => \&list_invite,
        'mass_mailing_options'                        => \&mass_mailing_options,
        'pass_gen'                                    => \&pass_gen,
        'send_url_email'                              => \&send_url_email,
        'feature_set'                                 => \&feature_set,
        'list_cp_options'                             => \&list_cp_options,
        'profile_fields'                              => \&profile_fields,
        'mail_sending_options_test'                    => \&mail_sending_options_test,
        'author'                                      => \&author,
        'list'                                        => \&list_page,
        'setup_info'                                  => \&setup_info,
        'reset_cipher_keys'                           => \&reset_cipher_keys,
        'restore_lists'                               => \&restore_lists,
        'r'                                           => \&redirection,
        'subscriber_help'                             => \&subscriber_help,
        'show_img'                                    => \&show_img,
        'file_attachment'                             => \&file_attachment,
        'm_o_c'                                       => \&m_o_c,
        'img'                                         => \&img,
        'js'                                          => \&js,
        'css'                                         => \&css,
        'captcha_img'                                 => \&captcha_img,
        'ver'                                         => \&ver,
        'resend_conf'                                 => \&resend_conf,
        'show_error'                                  => \&show_error,
        'subscription_form_html'                      => \&subscription_form_html,
        'what_is_dada_mail'                           => \&what_is_dada_mail,
        'profile_activate'                            => \&profile_activate,
        'profile_register'                            => \&profile_register,
        'profile_reset_password'                      => \&profile_reset_password,
        'profile_update_email'                        => \&profile_update_email,
        'profile_login'                               => \&profile_login,
        'profile_logout'                              => \&profile_logout,
        'profile'                                     => \&profile,

        # These handled the oldstyle confirmation. For some backwards compat, I've changed
        # them so that there's at least a shim to the new system,
        #
        #	'n'                          =>    \&confirm,
        's'                          => \&subscribe,
        'u'                          => \&unsubscribe,
        'outdated_subscription_urls' => \&outdated_subscription_urls,

        # This is the new system
        't' => \&token,

        # This doesn't really happen, anymore:
        'ur'                               => \&outdated_subscription_urls,
        'smtm'                             => \&what_is_dada_mail,
        'send_email_testsuite'             => \&send_email_testsuite,
        $DADA::Config::ADMIN_FLAVOR_NAME   => \&admin,
        $DADA::Config::SIGN_IN_FLAVOR_NAME => \&sign_in,

        bridge_inject => \&bridge_inject,
    );

    # ...inject?
    if ( !$ENV{GATEWAY_INTERFACE} ) {

        my $inject;
        my $run_list;
        require Getopt::Long;
        Getopt::Long::GetOptions(
            "inject" => \$inject,
            "list=s" => \$run_list,
        );
        if ($inject) {

            # $ENV{CGI_APP_RETURN_ONLY} = 1;

            if ($run_list) {
                $self->param( 'run_list', $run_list );
                $self->start_mode('bridge_inject');
            }
            else {
                # Well, that won't work.
            }
        }
        else {
            # Do watcha did before.
        }
    }

}

sub yikes {

    my $self  = shift;
    my $error = shift;

    my $TIME = scalar( localtime() );
    return qq{
<html>
<head></head>
<body>
<div style="padding:5px;border:3px dotted #ccc; font-family:helvetica; font-size:.7em; line-height:150%; width:600px;margin-left:auto;margin-right:auto;margin-top:100px;">
<img alt="Dada Mail" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJYAAAC
WCAMAAAAL34HQAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAAxQTFRFCAgIXV
1dp6en/f39XG2aJgAAAqpJREFUeNrs3OGO4yAMBOB0+/7vvFWRLMtjjAkEqDT5dddyy1fJNwSH7vU+8
rrIWsX6+15k/TTr+l6v12s6jqxlrA/oUtdEHFm7WKXOyPotltZ8CmuijKw1LCks7ZiVFGQtYOlocF8n
63CWZAGWkbxF1uGsYGEW1mBGkPUoyw13fJesY1k6GuKyWxoQZM0I9ya6t9TIeojV3KPWsqNwydrOisP
duKWSPn+4l/tkTWc1w702Rm+QyNrIaoZ7HB/3GkxkzWVl2rW1lgRZJ7Ay4a6Lzx1G1kZWJtx18XVth8
oqrh+R6iffZE1hJcM9sxgj64KrTCf1R9YUVibcm9Ggb5qFheMxhsgaZwVLr2tyh5UBWiYv4mcoY8iax
cr8nzcmd5ihaGLtB5I1yJK1sxkNGZOulQyrfAyyBll4jieYT48pk5lTlfqD6c0PWY+ycNZaN0EPKOML
SGK9ycIP3MgtsjpTHnG1w3baoUsK+w7mmNeEOwiyOnc+meDQ9WFYZhssAl2R2Xt5snpYZv02/YKgIkv
cByxcKrDmyJrIynTtyw/VT8Jilukc+TfcZC1hmfN2+q8Bq3yAaU9fyRpjmcR3tzqi1JVH1mks3KCaZq
IkSNfXSMhaw9IpgEeZcQdF1oGs2taldivcdQaIrC2sN3yfGXdK+W/JkrWLFfeG+pYQss5gjVxk3WaZj
oNOcPf15ADsYtQmImucVfvVAKYb2OwbmplqveDgOTdZt1lB8z1o6WLX3sxE1kaWbqPXWLX2vXvjRdbT
LHcCt27co1c4mKz1rGAC8wr+Agi3EN1FAlmNpZqsuyw32bEa8EGXW4LN2sKnLGTdY8Xh7tbN1bqSrOh
ZNVlpFpYOHkw3LPNPZBuD05C1niXvmeM4Zkwt94NmrjnpRdZcFvtbv8z6F2AA/5G8jEIpBJoAAAAASU
VORK5CYII=" style="float:left;padding:10px"/></p>
<h1>Yikes! App/Server Problem!</h1>
<p>We apologize, but the server encountered a problem when attempting to complete its task.</p> 
<p>More information about this error may be available in the <em>program's own error log</em>.</p> 
<p><a href="mailto:$ENV{SERVER_ADMIN}">Contact the Server Admin</a></p>
<p>Time of error: <strong>$TIME</strong></p> 	
</div>

</body> 
</html> 
};

}

sub default {

    my $self = shift;
    my $q    = $self->query();

    if ( DADA::App::Guts::check_setup() == 0 ) {
        return user_error( { -error => 'bad_setup' } );
    }
    if ( DADA::App::Guts::install_dir_around() == 1 ) {
        return user_error( { -error => 'install_dir_still_around' } );
    }

	# SQL backed working? 
	my $dbi_handle;
	require DADA::App::DBIHandle;

	$dbi_handle = DADA::App::DBIHandle->new;
	try { 
		$dbi_handle->dbh_obj; 
	} catch {
    	warn $_;
        return user_error(
            {
                -error         => 'sql_connect_error',
                -error_message => $@
            }
        );
    };
	if ( DADA::App::Guts::SQL_check_setup() == 0 ) {
	    return user_error( { -error => 'bad_SQL_setup' } );
	}
    require DADA::MailingList::Settings;
    my @available_lists;
	try  { 
		@available_lists = available_lists( -In_Order => 1 ); 
	} catch {
	    return user_error(
	        {
	            -error         => 'sql_connect_error',
	            -error_Message => $_
	        }
	    );
    };
	
    @available_lists = available_lists( -In_Order => 1 );

    if (   ( $DADA::Config::DEFAULT_SCREEN ne '' )
        && ( $q->param('flavor') ne 'default' )
        && ( $#available_lists >= 0 ) )
    {
        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::DEFAULT_SCREEN );
        return;
    }

    if ( !$available_lists[0] ) {
        my $auth_state;
        if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
            require DADA::Security::SimpleAuthStringState;
            my $sast = DADA::Security::SimpleAuthStringState->new;
            $auth_state = $sast->make_state;
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'congrats_screen.tmpl',
                -with   => 'list',
                -vars   => {
                    havent_agreed => ( ( xss_filter( scalar $q->param('agree') ) eq 'no' ) ? 1 : 0 ),
                    auth_state => $auth_state,
                },
            }
        );
        return $scrn;
    }

    if ( 
			$q->param('error_invalid_list') != 1 
		&& ( !$c->profile_on ) 
		&& ( $c->is_cached('default.scrn') ) 
	) {
        return $c->cached('default.scrn');
    }

    my $scrn = DADA::Template::Widgets::default_screen(
    	{
	        -email              => scalar $q->param('email'),
	        -list               => scalar $q->param('list'),
	        -error_invalid_list => scalar $q->param('error_invalid_list'),
    	}
    );
    if (  !$c->profile_on
        && $available_lists[0]
        && $q->param('error_invalid_list') != 1 )
    {
        $c->cache( 'default.scrn', \$scrn );
    }
    return $scrn;
	
}

sub list_page {

    my $self = shift;
    my $q    = $self->query();

    if ( DADA::App::Guts::check_setup() == 0 ) {
        return user_error( { -error => 'bad_setup' } );
    }

    if ( check_if_list_exists( -List => scalar $q->param('list') ) == 0 ) {
        $q->delete('list');
        return $self->default();
    }

    my $list = $q->param('list');
    require DADA::MailingList::Settings;

    if ( !defined( $q->param('email') ) && ( $q->param('error_no_email') != 1 ) ) {
        if ( !$c->profile_on && $c->is_cached( 'list/' . $list . '.scrn' ) ) {
            return $c->cached( 'list/' . $list . '.scrn' );
        }
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $scrn = DADA::Template::Widgets::list_page(
        -list           => $list,
        -cgi_obj        => $q,
        -email          => scalar $q->param('email'),
        -error_no_email => scalar $q->param('error_no_email') || 0,
    );
    if ( !$c->profile_on && !defined( $q->param('email') ) && ( $q->param('error_no_email') != 1 ) ) {
        $c->cache( 'list/' . $list . '.scrn', \$scrn );
    }
    return $scrn;

}

sub admin {

    my $self = shift;
    my $q    = $self->query();

    my @available_lists = available_lists();
    if ( ( $#available_lists < 0 ) ) {
        return $self->default();
    }

    if ( DADA::App::Guts::install_dir_around() == 1 ) {
        return user_error( { -error => 'install_dir_still_around' } );
    }

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'admin',
    );

    if ($checksout) {
        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::DEFAULT_ADMIN_SCREEN );
        return;
    }
    else {

        my $login_widget = $q->param('login_widget') // $DADA::Config::LOGIN_WIDGET;

        my $scrn = DADA::Template::Widgets::admin(
			{ 
	            -cgi_obj      => $q,
				-vars         => {
					login_widget => $login_widget, 
				}
			}
		); 
		
        return $scrn;
    }
}

sub sign_in {

    my $self = shift;
    my $q    = $self->query();

    if ( DADA::App::Guts::install_dir_around() == 1 ) {
        return user_error( { -error => 'install_dir_still_around' } );
    }

    my $list = $q->param('list');

    my $list_exists = check_if_list_exists( -List => $list, );

    if ( $list_exists >= 1 ) {

        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj  => $q,
            -Function => 'sign_in',
        );
        if ( $checksout && $admin_list eq $list ) {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::DEFAULT_ADMIN_SCREEN );
        }
        else {
            my $auth_state;
            if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
                require DADA::Security::SimpleAuthStringState;
                my $sast = DADA::Security::SimpleAuthStringState->new;
                $auth_state = $sast->make_state;
            }

            require DADA::MailingList::Settings;

            my $ls = DADA::MailingList::Settings->new( { -list => $list } );

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen         => 'list_login_form.tmpl',
					-expr           => 1, 
                    -with           => 'list',
                    -wrapper_params => {
                        -Use_Custom => 0,
                    },
                    -vars => {
                        flavor_sign_in => 1,
                        auth_state     => $auth_state,
						login_widget   => 'hidden_field',
						selected_list  => $list,
                    },
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                }
            );
            return $scrn;
        }
    }
    else {

        my $login_widget = $q->param('login_widget')
          || $DADA::Config::LOGIN_WIDGET;
        my $scrn = DADA::Template::Widgets::admin(
			{ 
	            -cgi_obj                 => $q,
				-vars => { 
					login_widget => $login_widget
				},
			}
        );
        return $scrn;
    }

}

sub admin_menu_drafts_notification {

    my $self = shift;
    my $q    = $self->query();

    try {

        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
        if ($checksout) {
            my $list = $admin_list;
            require DADA::MailingList::MessageDrafts;

            my $d = DADA::MailingList::MessageDrafts->new( { -list => $list } );
            my $num_drafts     = $d->count( { -role => 'draft' } );
            my $num_stationery = $d->count( { -role => 'stationery' } );
            my $num_shedules   = $d->count( { -role => 'schedule' } );

            if (   $num_drafts > 0
                || $num_stationery > 0
                || $num_shedules > 0 )
            {
                return
                    '('
                  . commify($num_drafts) . ','
                  . commify($num_stationery) . ','
                  . commify($num_shedules) . ')';
            }
        }
    } catch {
        warn
"Problems filling out the 'Sending Monitor' admin menu item with interesting bits of information about the mailouts: $_";
    };

}

sub admin_menu_mailing_monitor_notification {

    my $self = shift;
    my $q    = $self->query();

    try {

        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
        if ($checksout) {

            my $list = $admin_list;
            require DADA::Mail::MailOut;
            my @mailouts = DADA::Mail::MailOut::current_mailouts( { -list => $list } );
            my $list_mailouts = $#mailouts + 1;

            my (
                $monitor_mailout_report, $total_mailouts,  $active_mailouts,
                $paused_mailouts,        $queued_mailouts, $inactive_mailouts
              )
              = DADA::Mail::MailOut::monitor_mailout(
                {
                    -verbose => 0,
                    -list    => $list,
                    -action  => 0,
                }
              );
            return $list_mailouts . '/' . $total_mailouts;
        }
    } catch {
        warn
"Problems filling out the 'Sending Monitor' admin menu item with interesting bits of information about the mailouts: $_";
    };
}

sub admin_menu_subscriber_count_notification {

    my $self = shift;
    my $q    = $self->query();

    try {

        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj         => $q,
            -manual_override => 1
        );
        if ($checksout) {
            my $list = $admin_list;
            require DADA::MailingList::Subscribers;
            my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
            my $num = $lh->num_subscribers();
            if ( $num > 0 ) {
                return '(' . commify($num) . ')';
            }
        }
    } catch {
        carp($_);
        return '';
    };
}

sub admin_menu_archive_count_notification {

    my $self = shift;
    my $q    = $self->query();

    try {

        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj         => $q,
            -manual_override => 1
        );
        if ($checksout) {
            my $list = $admin_list;
            require DADA::MailingList::Archives;
            my $lh = DADA::MailingList::Archives->new( { -list => $list } );
            my $num = $lh->num_archives();
            if ( $num > 0 ) {
                return '(' . commify($num) . ')';
            }
        }
    } catch {
        carp($_);
        return '';
    };
}

sub admin_menu_mail_sending_options_notification {
    my $self = shift;
    my $q    = $self->query();

    try {
        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj         => $q,
            -manual_override => 1
        );
        my $rs = '';
        if ($checksout) {
            my $list = $admin_list;
            require DADA::MailingList::Settings;
            my $ls = DADA::MailingList::Settings->new( { -list => $list } );

            if ( $ls->param('sending_method') eq 'sendmail' ) {
                $rs = '(sendmail)';
            }
            elsif ( $ls->param('sending_method') eq 'smtp' ) {
                $rs = '(SMTP)';
            }
            elsif ( $ls->param('sending_method') eq 'amazon_ses' ) {
                $rs = '(Amazon SES)';
            }
        }
        return $rs;
    } catch {
        carp($_);
        return '';
    };
}


sub admin_menu_mailing_sending_mass_mailing_options_notification {
    my $self = shift;
    my $q    = $self->query();
    try {
        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj         => $q,
            -manual_override => 1
        );
        if ($checksout) {
            my $list = $admin_list;
            require  DADA::Mail::MailOut;
            my $mo = DADA::Mail::MailOut->new( { -list => $list } );
            my ( $batch_sending_enabled, $batch_size, $batch_wait ) = $mo->batch_params();
            my $per_sec = $batch_size / $batch_wait;
            my $per_hour =  int( $per_sec * 60 * 60 + .5 );    # DEV .5 is some sort of rounding thing (with int). That's wrong.
            if($batch_sending_enabled == 1){ 
                return '(' . commify($per_hour) . '/hr)';
            }
            else { 
                return ''; 
            }
        }
    } catch {
        carp($_);
        return '';
    };
}







sub admin_menu_bounce_handler_notification {
    my $self = shift;
    my $q    = $self->query();

    try {
        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj         => $q,
            -manual_override => 1
        );
        if ($checksout) {
            my $list = $admin_list;
            require DADA::App::BounceHandler::ScoreKeeper;
            my $bsk = DADA::App::BounceHandler::ScoreKeeper->new( { -list => $list } );
            my $num = $bsk->num_scorecard_rows;
            if ( $num > 0 ) {
                return '(' . commify($num) . ')';
            }
        }
    } catch {
        carp($_);
        return '';
    };
}




sub admin_menu_tracker_notification {
    my $self = shift;
    my $q    = $self->query();

    try {
        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj         => $q,
            -manual_override => 1
        );
        my $rs = '';
        if ($checksout) {
            require DADA::Logging::Clickthrough;
            my $rd = DADA::Logging::Clickthrough->new({-list => $admin_list});
            my ( $total, $msg_ids ) = $rd->get_all_mids; 
            return '(' . commify($total) . ')';
        }
    } catch {
        carp($_);
        return '';
    };
}



sub send_email {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_email'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    require DADA::App::MassSend;
    my $ms = DADA::App::MassSend->new( { -list => $list } );

    my $Ext_Request = undef;
    if ( defined( $self->param('Ext_Request') ) ) {
        $Ext_Request = $self->param('Ext_Request');
    }
    my ( $headers, $body ) = $ms->send_email(
        {
            -cgi_obj     => $q,
            -Ext_Request => $Ext_Request,
            -root_login  => $root_login,
        }
    );
    

    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }
}

sub send_email_button_widget { 
    my $self = shift;
    my $q    = $self->query();
    
    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_email send_url_email'
    );    
		
    if ( !$checksout ) { return $error_msg; }
    my $list = $admin_list;
    
    my $draft_role = $q->param('draft_role') || 'draft'; 
    my $archive_no_send = $q->param('archive_no_send') || 0; 
    
    my $scrn    = DADA::Template::Widgets::screen(
        {
            -screen         => 'send_email_button_widget.tmpl',
            -expr => 1,
            -vars => {
                draft_role      => $draft_role ,
                archive_no_send => $archive_no_send, 
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;
}

sub mass_mailing_schedules_preview {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_email'
    );
    if ( !$checksout ) { return $error_msg; }
    my $list = $admin_list;

    my $errors = {};
    my $status = 1;

    my $schedule_activated = $q->param('schedule_activated') || 0;
    my $schedule_type      = $q->param('schedule_type')      || undef;

    my $schedule_single_displaydatetime = undef;
    my $schedule_single_ctime           = undef;

    if ( $schedule_type eq 'single' ) {
        $schedule_single_displaydatetime = $q->param('schedule_single_displaydatetime') || undef;
        if ( !$schedule_single_displaydatetime ) {
            $status = 0;
            $errors->{missing_information};
        }

        # warn '$schedule_single_displaydatetime ' . $schedule_single_displaydatetime;
        $schedule_single_ctime = displaytime_to_ctime($schedule_single_displaydatetime);
    }

    my $day_set = undef;
    my $dates   = [];
    my $errors  = undef;

    my $start = undef;
    my $end   = undef;

    my $rd   = [];
    my $days = {
        7 => 'Sunday',
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
    };

    my $schedule_recurring_displaydatetime_start = undef;
    my $schedule_recurring_displaydatetime_end   = undef;
    my $schedule_recurring_ctime_start           = undef;
    my $schedule_recurring_ctime_end             = undef;
    my $schedule_recurring_display_hms           = undef;
    my $schedule_recurring_hms                   = undef;
    my @schedule_recurring_days                  = undef;

    if ( $schedule_type eq 'recurring' ) {

        $schedule_recurring_displaydatetime_start = $q->param('schedule_recurring_displaydatetime_start') || undef;
        $schedule_recurring_displaydatetime_end   = $q->param('schedule_recurring_displaydatetime_end')   || undef;
        $schedule_recurring_display_hms           = $q->param('schedule_recurring_display_hms')           || undef;
        $schedule_recurring_ctime_start = displaytime_to_ctime($schedule_recurring_displaydatetime_start);
        $schedule_recurring_ctime_end   = displaytime_to_ctime($schedule_recurring_displaydatetime_end);
        @schedule_recurring_days        = $q->multi_param('schedule_recurring_days');
        $schedule_recurring_hms         = display_hms_to_hms($schedule_recurring_display_hms);

        if ( !( scalar DADA::App::Guts::can_use_datetime() ) ) {
            $status = 0;
            $errors->{datetime} = 1;
        }
        elsif ( $schedule_recurring_ctime_start > $schedule_recurring_ctime_end ) {
            $status = 0;
            $errors->{schedule_recurring_dates_wrong} = 1;
        }
        elsif (!$schedule_recurring_displaydatetime_start
            || !$schedule_recurring_displaydatetime_start
            || !$schedule_recurring_display_hms
            || ( scalar @schedule_recurring_days <= 0 ) )
        {
            $status = 0;
            $errors->{missing_information} = 1;
        }
        else {

            for (@schedule_recurring_days) {
                push(
                    @$rd,
                    {
                        day  => $_,
                        name => $days->{$_},
                    }
                );
            }
            $schedule_recurring_ctime_start += $schedule_recurring_hms;
            $schedule_recurring_ctime_end   += $schedule_recurring_hms;

            try {
                require DateTime;
                require DateTime::Event::Recurrence;
                $start = DateTime->from_epoch( epoch => $schedule_recurring_ctime_start );
                $end   = DateTime->from_epoch( epoch => $schedule_recurring_ctime_end );
            } catch {
                warn $_;
                $errors .= $_;
            };
            my ( $hours, $minutes, $seconds ) = split( ':', $schedule_recurring_display_hms );
        }
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $scrn = DADA::Template::Widgets::screen(
        {
            -screen => 'mass_mailing_schedules_preview.tmpl',
            -expr   => 1,
            -vars   => {
                status => $status,

                #   errors                             => $errors,
                schedule_activated => $schedule_activated,
                schedule_type      => $schedule_type,

                schedule_single_ctime           => $schedule_single_ctime,
                schedule_single_localtime       => ctime_to_localtime($schedule_single_ctime),
                schedule_single_displaydatetime => $schedule_single_displaydatetime,

                schedule_recurring_hms         => $schedule_recurring_hms,
                schedule_recurring_display_hms => $schedule_recurring_display_hms,

                schedule_recurring_displaydatetime_start => $schedule_recurring_displaydatetime_start,
                schedule_recurring_displaydatetime_end   => $schedule_recurring_displaydatetime_end,

                schedule_recurring_localtime_start => ctime_to_localtime($schedule_recurring_ctime_start),
                schedule_recurring_localtime_end   => ctime_to_localtime($schedule_recurring_ctime_end),

                schedule_recurring_days => $rd,
                num_recurring_days      => scalar @$rd,

                #  dates                              => $dates,

                schedule_last_checked_ago => formatted_runtime( time - $ls->param('schedule_last_checked_time') ),

            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;

}

sub draft_message_values {
    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_email'
    );
    if ( !$checksout ) { return $error_msg; }
    my $list = $admin_list;    

    require DADA::App::MassSend;
    my $ms = DADA::App::MassSend->new( { -list => $list } );

    my ( $headers, $body ) = $ms->draft_message_values(
        {
            -cgi_obj     => $q,
        }
    );

#    require Data::Dumper; 
#    warn Data::Dumper::Dumper(
#        { 
#            headers => $headers, 
#            body    => $body, 
#        }
#    );
    if ( keys %$headers ) {
        $self->header_props(%$headers);
    }
    return $body;
    
}

sub datetime_to_ctime {
    my $datetime = shift;
#    warn '$datetime ' . $datetime; 
    require Time::Local;
    my ( $date, $time ) = split( ' ', $datetime );
    my ( $year, $month,  $day )    = split( '-', $date );
    my ( $hour, $minute, $second ) = split( ':', $time );
    $second = int( $second - 0.5 );    # no idea.
    my $time = Time::Local::timelocal( $second, $minute, $hour, $day, $month - 1, $year );

    return $time;
}
sub datetime_to_localtime {
    my $datetime = shift;
    my $time     = datetime_to_ctime($datetime);
    return scalar( localtime($time) );
}






sub ckeditor_template_tag_list {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require JSON;
    my $json = JSON->new->allow_nonref;

    my $strings = [];

    require DADA::ProfileFieldsManager;
    my $pfm         = DADA::ProfileFieldsManager->new;
    my $fields_attr = $pfm->get_all_field_attributes;

    push( @$strings, { name => 'Profile Fields', } );
    push(
        @$strings,
        {
            name  => 'Email Address',
            value => '<!-- tmpl_var subscriber.email -->',
        }
    );
    push(
        @$strings,
        {
            name  => 'Email Name',
            value => '<!-- tmpl_var subscriber.email_name -->',
        }
    );

    push(
        @$strings,
        {
            name  => 'Email Domain',
            value => '<!-- tmpl_var subscriber.email_domain -->',
        }
    );

    foreach my $field ( @{ $pfm->fields } ) {
        push(
            @$strings,
            {
                name  => $fields_attr->{$field}->{label},
                value => '<!-- tmpl_var subscriber.' . $field . ' -->',
            }
        );
    }

    my $settings = [
        {
            name => 'List Settings'
        },
        {
            name  => 'List Name',
            value => '<!-- tmpl_var list_settings.list_name -->',
        },
        {
            name  => 'List Owner Email Address',
            value => '<!-- tmpl_var list_settings.list_owner_email -->',
        },
        {
            name  => 'Mailing List Description',
            value => '<!-- tmpl_var list_settings.info -->',
        },
        {
            name  => 'Mailing List Privacy Policy',
            value => '<!-- tmpl_var list_settings.privacy_policy -->',
        },
        {
            name  => 'Physical Address',
            value => '<!-- tmpl_var list_settings.physical_address -->',
        },
    ];
    push( @$strings, @$settings );

    push( @$strings, { name => 'Loops/Conditionals', } );
    push(
        @$strings,
        {
            name  => 'loop...',
            value => '<!-- tmpl_loop field_name --><!-- /tmpl_loop -->',
        }
    );
    push(
        @$strings,
        {
            name  => 'if...',
            value => '<!-- tmpl_if field_name --><!-- /tmpl_if -->',
        }
    );
    push(
        @$strings,
        {
            name  => 'unless...',
            value => '<!-- tmpl_unless field_name --><!-- /tmpl_unless -->',
        }
    );

    my $headers = { -type => 'application/json', };
    my $body = $json->encode( { strings => $strings } );

    $self->header_props(%$headers);

    return $body;

}

sub draft_saved_notification {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
    if ( !$checksout ) { return $error_msg; }

    my $role = $q->param('role');

    my $scrn = DADA::Template::Widgets::screen(
        {
            -screen => 'draft_saved_notification_widget.tmpl',
            -expr   => 1,
            -vars   => {
                role => $role,
            }
        }
    );
    return $scrn;
}

sub drafts {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'drafts'
    );
    if ( !$checksout ) { return $error_msg; }
    my $list = $admin_list;

    my $delete_draft = $q->param('delete_draft') || 0;

    require DADA::MailingList::MessageDrafts;
    my $d = DADA::MailingList::MessageDrafts->new( { -list => $list } );

    my $di  = [];
    my $si  = [];
    my $sci = [];

    $di  = $d->draft_index( { -role => 'draft' } );
    $si  = $d->draft_index( { -role => 'stationery' } );
    $sci = $d->draft_index( { -role => 'schedule' } );

    #use Data::Dumper;
    #return '<pre>' . Data::Dumper::Dumper($sci);

    my $sci_active   = [];
    my $sci_inactive = [];
    for (@$sci) {
        if ( $_->{schedule_activated} == 1 ) {
            push( @$sci_active, $_ );
        }
        else {
            push( @$sci_inactive, $_ );
        }
    }

    my $scrn    = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'drafts.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -expr => 1,
            -vars => {
                screen                  => 'drafts',
                delete_draft            => $delete_draft,
                draft_index             => $di,
                stationery_index        => $si,
                active_schedule_index   => $sci_active,
                inactive_schedule_index => $sci_inactive,
                num_drafts              => scalar(@$di),
                num_stationery          => scalar(@$si),
                num_schedules           => scalar(@$sci),
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;
}

sub delete_drafts {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my @draft_ids = $q->multi_param('draft_ids');

    require DADA::MailingList::MessageDrafts;
    my $d = DADA::MailingList::MessageDrafts->new( { -list => $list } );

    foreach my $id (@draft_ids) {
        $d->remove($id);
    }

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=drafts&delete_draft=1' );

}

sub create_from_stationery {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
    if ( !$checksout ) { return $error_msg; }

    my $list     = $admin_list;
    my $draft_id = $q->param('draft_id');
    my $screen   = $q->param('screen');

    require DADA::MailingList::MessageDrafts;
    my $d = DADA::MailingList::MessageDrafts->new( { -list => $list } );
    my $new_id = $d->create_from_stationery( { -id => $draft_id, -screen => $screen } );

    $self->header_type('redirect');
    $self->header_props(
        -url => $DADA::Config::S_PROGRAM_URL . '?flavor=' . $screen . '&restore_from_draft=true&draft_id=' . $new_id );

}

sub message_body_help {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
    if ( !$checksout ) { return $error_msg; }

    my $body = DADA::Template::Widgets::screen( { -screen => 'send_email_message_body_help_widget.tmpl', } );
    return $body;
}

sub url_message_body_help {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q );
    if ( !$checksout ) { return $error_msg; }
    return ( {}, DADA::Template::Widgets::screen( { -screen => 'send_url_email_message_body_help_widget.tmpl', } ) );
}

sub preview_message_receivers {

    my $self = shift;
    my $q    = $self->query();

    my $r;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security( -cgi_obj => $q, );
    if ( !$checksout ) { return $error_msg; }

    # This comes in a s a string, sep. by commas. Sigh.
    my $al = $q->param('alternative_lists') || '';
    my @alternative_list = split( ',', $al );

    my $multi_list_send_no_dupes = $q->param('multi_list_send_no_dupes') || 0;
    require DADA::MailingList::Settings;
    my $list   = $admin_list;
    my $lh     = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $fields = [];

    # Extra, special one...
    push( @$fields, { name => 'subscriber.email' } );
    for my $field ( @{ $lh->subscriber_fields( { -dotted => 1 } ) } ) {
        push( @$fields, { name => $field } );
    }
    my $naked_fields = $lh->subscriber_fields( { -dotted => 0 } );
    my $undotted_fields = [];

    # Extra, special one...
    push( @$undotted_fields, { name => 'email', label => 'Email Address' } );
    for my $undotted_field ( @{$naked_fields} ) {
        push( @$undotted_fields, { name => $undotted_field } );
    }

    my $partial_sending = partial_sending_query_to_params( $q, $naked_fields );

    my $order_by  = 'email';
    my $order_dir = 'desc';

    if ( exists( $partial_sending->{'subscriber.timestamp'}->{-value} ) ) {
        $order_by  => 'timestamp';
        $order_dir => 'desc';
    }
    my ($fancy_r, $fancy_c); 
    
    if ( keys %$partial_sending ) {
		($fancy_r, $fancy_c) = $lh->fancy_list(
		    {
		        -partial_listing       => $partial_sending,
		        -type                  => 'list',
		        -show_list_column      => 1,
		        -show_timestamp_column => 1,
		        -order_by              => $order_by,
		        -order_dir             => $order_dir,
		    }
		);
		$r .= $fancy_r;
    }
    else {
        if ( $alternative_list[0] ) {
            $r .= $q->p(
                $q->em(
                        'Every Subscriber of each of these mailing lists: '
                      . $list . ', '
                      . join( ', ', @alternative_list )
                      . ' will receive this message.'
                )
            );
        }
        else {
            $r .= $q->p(
                $q->em(
                        'All '
                      . $q->strong( commify( $lh->num_subscribers ) )
                      . ' Subscribers of your mailing list will receive this message.'
                )
            );
        }
    }
    return $r;

}

sub sending_monitor_index {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'sending_monitor'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list           = $admin_list;
    my $mailout_status = [];
    my @lists;

    # If we're logged in as dada root, we see all the mass mailings going on.
    if ( $root_login == 1 ) {
        @lists = available_lists();
    }
    else {
        # If not, only the current list.
        @lists = ($list);
    }

    for my $l_list (@lists) {
        my @mailouts = DADA::Mail::MailOut::current_mailouts(
            {
                -list     => $l_list,
                -order_by => 'creation',
            }
        );
        for my $mo (@mailouts) {

            my $mailout = DADA::Mail::MailOut->new( { -list => $l_list } );
            $mailout->associate( $mo->{id}, $mo->{type} );
            my $status = $mailout->status();
            require DADA::MailingList::Settings;
            my $l_ls = DADA::MailingList::Settings->new( { -list => $l_list } );
            push(
                @$mailout_status,
                {
                    %$status,
                    list          => $l_list,
                    current_list  => ( ( $list eq $l_list ) ? 1 : 0 ),
                    S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL,
                    Subject =>
                      safely_decode( $status->{email_fields}->{Subject}, 1 ),
                    status_bar_width          => int( $status->{percent_done} ) * 1,
                    negative_status_bar_width => 100 -
                      ( int( $status->{percent_done} ) * 1 ),
                    message_id   => $mo->{id},
                    message_type => $mo->{type},
                    mailing_started =>
                      scalar( localtime( $status->{first_access} ) ),
                    mailout_stale => $status->{mailout_stale},
                    %{ $l_ls->params },
                }
            );
        }
    }

    my (
        $monitor_mailout_report, $total_mailouts,  $active_mailouts,
        $paused_mailouts,        $queued_mailouts, $inactive_mailouts
      )
      = DADA::Mail::MailOut::monitor_mailout(
        {
            -verbose => 0,
            ( $root_login == 1 ) ? () : ( -list => $list )
        }
      );
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'sending_monitor_index_screen.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {
                screen                 => 'sending_monitor',
                killed_it              => scalar $q->param('killed_it') ? 1 : 0,
                mailout_status         => $mailout_status,
                monitor_mailout_report => $monitor_mailout_report,
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;

}

sub sending_monitor {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'sending_monitor'
    );
    if ( !$checksout ) { return $error_msg; }

    require DADA::MailingList::Settings;
    require DADA::Mail::MailOut;

    my $list = $admin_list;

    my $mo = DADA::Mail::MailOut->new( { -list => $list } );
    my ( $batching_enabled, $batch_size, $batch_wait ) = $mo->batch_params;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    # munging the message id.
    # kinda dumb, but it's sort of up in the air,
    # on how the message id comes to us,
    # so we have to be *real* careful to get it to a state
    # that we *need* it in.

    my $id = DADA::App::Guts::strip( scalar $q->param('id') );
    $id =~ s/\@/_at_/g;
    $id =~ s/\>|\<//g;

    if ( !$q->param('id') ) {
        return $self->sending_monitor_index();
    }

    # 10 is the factory default setting to wait per batch.
    # Let's not refresh an faster, or we'll never have time
    # to read the actual screen.

    my $refresh_after = 10;
    if ( $refresh_after < $batch_wait ) {
        $refresh_after = $batch_wait;
    }

    # Type ala, list, invitation list, etc
    my $type = $q->param('type');
    $type = xss_filter( DADA::App::Guts::strip($type) );

    my $restart_count = $q->param('restart_count') || 0;

    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
        {
            -list   => $list,
            -ls_obj => $ls,
        }
    );

    my $auto_pickup = 0;

    # Kill - the, [Stop] button was pressed. Pressed really hard.

    if ( $q->param('process') eq 'kill' ) {

        if ( DADA::Mail::MailOut::mailout_exists( $list, $id, $type ) == 1 ) {
            my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
            $mailout->associate( $id, $type );
            $mailout->clean_up;
        }
        else {
            warn "mailout $id does NOT exists! What's going on?!";
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_monitor&killed_it=1' );

    }
    elsif ( $q->param('process') eq 'pause' ) {

        if ( DADA::Mail::MailOut::mailout_exists( $list, $id, $type ) == 1 ) {

            my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
            $mailout->associate( $id, $type );
            $mailout->pause();

            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=sending_monitor&id='
                  . $id
                  . '&type='
                  . $type
                  . '&paused_it=1' );
        }
        else {
            die "mass mailing does NOT exists! What's going on?!";
        }

    }
    elsif ( $q->param('process') eq 'resume' ) {

        if ( DADA::Mail::MailOut::mailout_exists( $list, $id, $type ) == 1 ) {

            my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
            $mailout->associate( $id, $type );
            $mailout->resume();

            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=sending_monitor&id='
                  . $id
                  . '&type='
                  . $type
                  . '&resume_it=1' );

        }
        else {

            die "mass mailing does NOT exists! What's going on?!";

        }

# Restart is usually called by the program itself, automagically via a redirect if DADA::Mail::MailOut says we should restart.
    }
    elsif ( $q->param('process') eq 'restart' ) {

        my $restart_time = 1;

        # Let's make sure that restart worked...
        my $should_be_restarted = 0;
        eval {

            my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
            $mailout->associate( $id, $type );
            $should_be_restarted = $mailout->should_be_restarted;
            if ( $should_be_restarted == 1 ) {
                $mh->restart_mass_send( $id, $type );
                sleep(5);
            }
        };

        my $refresh_url;
        if ( $should_be_restarted == 1 ) {
            $refresh_url =
                $DADA::Config::S_PROGRAM_URL
              . '?flavor=sending_monitor&id='
              . $id
              . '&type='
              . $type
              . ' &restart_count='
              . $restart_count;
        }
        else {
            $refresh_url = $DADA::Config::S_PROGRAM_URL . '?flavor=sending_monitor&id=' . $id . '&type=' . $type;
        }
        my $r = "<html>
                <head>

                 <script type=\"text/javascript\">

                 function refreshpage(sec){

                    var refreshafter = sec/1 * 1000;
                    setTimeout(\"self.location.href='$refresh_url';\",refreshafter);
                }

                </script>


                 </head>
                 <body>
                 ";
        return ( {}, $r );

        # If not...
        if ($@) {
            my $r = "<h1>Problems Reloading!:</h1><pre>$@</pre>";

            # We're going to refresh, see if it gets better.
            $restart_time = 5;
        }

        if ( $should_be_restarted == 1 ) {

            # Provide a link in case browser redirect is working
            warn 'Reloading Message from Mailing Monitor';
            $r .= '<a href="' . $refresh_url . '">Reloading Mailing...</a>';
        }
        else {
            warn 'Refreshing Screen from Mailing Monitor';
            $r .= '<a href="' . $refresh_url . '">Refreshing Screen....</a>';
        }
        $r .= "

        <script type=\"text/javascript\">
        refreshpage($restart_time);
        </script>
        </body>
       </html>";

        return ( {}, $r );
    }
    elsif ( $q->param('process') eq 'ajax' ) {

        my $mailout                = undef;
        my $status                 = {};
        my $mailout_exists         = 0;
        my $mailout_exists         = 0;
        my $my_test_mailout_exists = 0;
        eval { $my_test_mailout_exists = DADA::Mail::MailOut::mailout_exists( $list, $id, $type ); };

        if ( !$@ ) {
            $mailout_exists = $my_test_mailout_exists;
        }

        if ($mailout_exists) {

            $mailout_exists = 1;
            $mailout = DADA::Mail::MailOut->new( { -list => $list } );
            $mailout->associate( $id, $type );
            $status = $mailout->status();

        }
        else {

            # Nothing - I believe this is handled in the template.

        }

        my (
            $monitor_mailout_report, $total_mailouts,  $active_mailouts,
            $paused_mailouts,        $queued_mailouts, $inactive_mailouts
          )
          = DADA::Mail::MailOut::monitor_mailout(
            {
                -verbose => 0,
                -list    => $list
            }
          );

        #warn '$status->{should_be_restarted} ' . $status->{should_be_restarted};
        #warn q{$ls->param('auto_pickup_dropped_mailings') }
        #  . $ls->param('auto_pickup_dropped_mailings');
        #warn '$restart_count' . $restart_count;
        #warn '$status->{mailout_stale}' . $status->{mailout_stale};
        #warn '$active_mailouts' . $active_mailouts;

        if (
            $status->{should_be_restarted} == 1 &&    # It's dead in the water.
            $ls->param('auto_pickup_dropped_mailings') == 1
            &&                                        # Auto Pickup is turned on...
             # $status->{total_sending_out_num} - $status->{total_sent_out} >  0 && # There's more subscribers to send out to
            $restart_count <= 0 &&    # We haven't *just* restarted this thing
            $status->{mailout_stale} != 1
            &&                        # The mailout hasn't been sitting around too long without being restarted,
            $active_mailouts < $DADA::Config::MAILOUT_AT_ONCE_LIMIT   # There's not already too many mailouts going out.
          )
        {

            # warn "Yes, we need to restart!";

            # Whew! Take that for making sure that the damn thing is supposed to be sent.

            my $reload_url =
                $DADA::Config::S_PROGRAM_URL
              . '?flavor=sending_monitor&id='
              . $id
              . '&process=restart&type='
              . $type
              . '&restart_count=1';

            my $r = "<script type=\"text/javascript\"> 
			window.location.replace('$reload_url'); 
			</script>";
            return ( {}, $r );
        }
        else {

            # warn "No, no need to restart.";
            $restart_count = 0;
        }

        my $sending_status = [];
        for ( keys %$status ) {
            next if $_ eq 'email_fields';
            push( @$sending_status, { key => $_, value => $status->{$_} } );
        }

        # If we're... say... 2x a batch setting and NOTHING has been sent,
        # let's say a mailing will be automatically started in... time since last - wait time.

        my $will_restart_in = undef;

        # $batch_wait
        if ( time - $status->{last_access} > ( $batch_wait * 1.5 ) ) {
            my $tardy_threshold = $batch_wait * 3;

            if ( $tardy_threshold < 60 ) {
                $tardy_threshold = 60;
            }

            $will_restart_in = $tardy_threshold - ( time - $status->{last_access} );
            if ( $will_restart_in >= 1 ) {
                $will_restart_in = formatted_runtime($will_restart_in);
            }
            else {
                $will_restart_in = undef;
            }
        }

        my $hourly_rate = 0;
        if ( $status->{mailing_time} > 0 ) {
            $hourly_rate = commify( int( ( $status->{total_sent_out} / $status->{mailing_time} ) * 60 * 60 + .5 ) );
        }

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
                -expr   => 1,
                -vars   => {
                    screen                    => 'sending_monitor',
                    mailout_exists            => $mailout_exists,
                    message_id                => DADA::App::Guts::strip($id),
                    message_type              => scalar $q->param('type'),
                    total_sent_out            => $status->{total_sent_out},
                    total_sending_out_num     => $status->{total_sending_out_num},
                    mailing_time              => $status->{mailing_time},
                    mailing_time_formatted    => $status->{mailing_time_formatted},
                    hourly_rate               => $hourly_rate,
                    percent_done              => $status->{percent_done},
                    status_bar_width          => int( $status->{percent_done} ) * 5,
                    negative_status_bar_width => 500 - ( int( $status->{percent_done} ) * 5 ),
                    need_to_send_out          => ( $status->{total_sending_out_num} - $status->{total_sent_out} ),
                    time_since_last_sendout   => formatted_runtime( ( time - int( $status->{last_sent} ) ) ),
                    its_killed                => $status->{should_be_restarted},
                    header_subject            => safely_decode( $status->{email_fields}->{Subject}, 1 ),
                    header_subject_label      => ( length($header_subject_label) > 50 )
                    ? ( substr( $header_subject_label, 0, 49 ) . '...' )
                    : ($header_subject_label),
                    auto_pickup_dropped_mailings => $ls->param('auto_pickup_dropped_mailings'),
                    sending_done                 => ( $status->{percent_done} < 100 ) ? 0 : 1,
                    refresh_after                => $refresh_after,
                    killed_it                    => scalar $q->param('killed_it') ? 1 : 0,
                    sending_status               => $sending_status,
                    is_paused                    => $status->{paused} > 0 ? 1 : 0,
                    paused                       => $status->{paused},
                    queue                        => $status->{queue},
                    queued_mailout               => $status->{queued_mailout},
                    queue_place => ( $status->{queue_place} + 1 ),    # adding one since humans like counting from, "1"
                    queue_total => ( $status->{queue_total} + 1 ),    # adding one since humans like counting from, "1"
                    status_mailout_stale  => $status->{mailout_stale},
                    MAILOUT_AT_ONCE_LIMIT => $DADA::Config::MAILOUT_AT_ONCE_LIMIT,
                    will_restart_in       => $will_restart_in,
                    integrity_check       => $status->{integrity_check},
                },
            }
        );

        return $scrn;
    }
    else {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'sending_monitor_container_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    screen        => 'sending_monitor',
                    message_id    => DADA::App::Guts::strip($id),
                    message_type  => scalar $q->param('type'),
                    refresh_after => $refresh_after,
                    'list_settings.tracker_show_message_reports_in_mailing_monitor' =>
                      $ls->param('tracker_show_message_reports_in_mailing_monitor'),
                    list_type_isa_list => ( $q->param('type') eq 'list' )
                    ? 1
                    : 0,
                }
            }
        );
        return $scrn;
    }
}

sub print_mass_mailing_log {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'sending_monitor'
    );
    if ( !$checksout ) { return $error_msg; }

    my $id   = $q->param('id');
    my $type = $q->param('type');

    my $list = $admin_list;

    require DADA::Mail::MailOut;
    my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
    $mailout->associate( $id, $type );
    $self->header_props( { -type => 'text/plain' } );
    return $mailout->return_log;
}

sub send_url_email {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_url_email'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $Ext_Request = undef;
    if ( defined( $self->param('Ext_Request') ) ) {
        $Ext_Request = $self->param('Ext_Request');
    }

    require DADA::App::MassSend;
    my $ms = DADA::App::MassSend->new( { -list => $list } );
    my ( $headers, $body ) = $ms->send_url_email(
        {
            -cgi_obj     => $q,
            -Ext_Request => $Ext_Request,
            -root_login  => $root_login,
        }
    );
    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }
}

sub list_invite {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::App::MassSend;
    my $ms = DADA::App::MassSend->new( { -list => $list } );

    my $Ext_Request = undef;
    if ( defined( $self->param('Ext_Request') ) ) {
        $Ext_Request = $self->param('Ext_Request');
    }

    my ( $headers, $body ) = $ms->list_invite(
        {
            -cgi_obj     => $q,
            -Ext_Request => $Ext_Request,
            -root_login  => $root_login,
        }
    );
    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }
}

sub mass_mailing_options {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mass_mailing_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list    = $admin_list;
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    if ( !$process ) {

        my $can_use_css_inliner = 1;
        try {
            require CSS::Inliner;
        } catch {
            $can_use_css_inliner = 0;
        };

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'mass_mailing_options_screen.tmpl',
                -with           => 'admin',
                -expr           => 1,
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    done                => $done,
                    can_use_css_inliner => $can_use_css_inliner,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    mass_mailing_convert_plaintext_to_html => 0,
                    mass_mailing_block_css_to_inline_css   => 0,
                }
            }
        );
        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=mass_mailing_options&done=1' );
    }

}

sub change_info {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'change_info'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $list_name        = $q->param('list_name')        || undef;
    my $list_owner_email = $q->param('list_owner_email') || undef;
    my $admin_email      = $q->param('admin_email')      || undef;
    my $privacy_policy   = $q->param('privacy_policy')   || undef;
    my $info             = $q->param('info')             || undef;
    my $physical_address = $q->param('physical_address') || undef;
    my $done             = $q->param('done')             || undef;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $ses_params = {};
    if ( $ls->param('sending_method') eq 'amazon_ses'
        || ( $ls->param('sending_method') eq 'smtp' && $ls->param('smtp_server') =~ m/amazonaws\.com/ ) )
    {
        $ses_params->{using_ses} = 1;
        require DADA::App::AmazonSES;
        my $ses = DADA::App::AmazonSES->new;
        $ses_params->{list_owner_ses_verified}     = $ses->sender_verified( $ls->param('list_owner_email') );
        $ses_params->{list_admin_ses_verified}     = $ses->sender_verified( $ls->param('admin_email') );
        $ses_params->{discussion_pop_ses_verified} = $ses->sender_verified( $ls->param('discussion_pop_email') );
    }
    my $errors = 0;
    my $flags  = {};

    if ($process) {
        ( $errors, $flags ) = check_list_setup(
            -fields => {
                list             => $list,
                list_name        => $list_name,
                list_owner_email => $list_owner_email,
                admin_email      => $admin_email,
                privacy_policy   => $privacy_policy,
                info             => $info,
                physical_address => $physical_address,
            },
            -new_list => 'no',
        );
    }

    undef $process
      if $errors >= 1;

    if ( !$process ) {

        my $err_word = 'was';
        $err_word = 'were'
          if $errors && $errors > 1;

        my $errors_ending = '';
        $errors_ending = 's'
          if $errors && $errors > 1;

        my $flags_list_name = $flags->{list_name} || 0;

        my $flags_list_name_bad_characters = $flags->{list_name_bad_characters}
          || 0;

        my $flags_invalid_list_owner_email = $flags->{invalid_list_owner_email}
          || 0;
        my $flags_list_info        = $flags->{list_info}        || 0;
        my $flags_privacy_policy   = $flags->{privacy_policy}   || 0;
        my $flags_physical_address = $flags->{physical_address} || 0;

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'change_info_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -vars => {
                    screen        => 'change_info',
                    done          => $done,
                    errors        => $errors,
                    errors_ending => $errors_ending,
                    err_word      => $err_word,
                    list          => $list,
                    list_name     => $list_name ? $list_name : $ls->param('list_name'),
                    list_owner_email => $list_owner_email ? $list_owner_email
                    : $ls->param('list_owner_email'),
                    admin_email => $admin_email ? $admin_email
                    : $ls->param('admin_email'),
                    info => $info ? $info : $ls->param('info'),
                    privacy_policy => $privacy_policy ? $privacy_policy
                    : $ls->param('privacy_policy'),
                    physical_address => $physical_address ? $physical_address
                    : $ls->param('physical_address'),
                    flags_list_name                => $flags_list_name,
                    flags_invalid_list_owner_email => $flags_invalid_list_owner_email,
                    flags_list_info                => $flags_list_info,
                    flags_privacy_policy           => $flags_privacy_policy,
                    flags_physical_address         => $flags_physical_address,
                    flags_list_name_bad_characters => $flags_list_name_bad_characters,
                    %$ses_params,
                },
            }
        );
        return $scrn;
    }
    else {

        $admin_email = $list_owner_email
          unless defined($admin_email);

        $ls->save(
            {
                list_owner_email => strip($list_owner_email),
                admin_email      => strip($admin_email),
                list_name        => $list_name,
                info             => $info,
                privacy_policy   => $privacy_policy,
                physical_address => $physical_address,
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=change_info&done=1' );
    }
}

sub change_password {

    my $self = shift;
    my $q    = $self->query();

    my $process = $q->param('process') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'change_password',
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::Security::Password;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'change_password_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -list => $list,
                -vars => {
                    screen     => 'change_password',
                    root_login => $root_login,
                },
            }
        );
        return $scrn;
    }
    else {

        my $old_password       = $q->param('old_password');
        my $new_password       = $q->param('new_password');
        my $again_new_password = $q->param('again_new_password');

        if ( $root_login != 1 ) {
            my $password_check = DADA::Security::Password::check_password( $ls->param('password'), $old_password );
            if ( $password_check != 1 ) {
                return (
                    {},
                    user_error(
                        {
                            -list  => $list,
                            -error => "invalid_password"
                        }
                    )
                );
            }
        }

        $new_password       = strip($new_password);
        $again_new_password = strip($again_new_password);

        if (   $new_password ne $again_new_password
            || $new_password eq "" )
        {
            return (
                {},
                user_error(
                    {
                        -list  => $list,
                        -error => "list_pass_no_match"
                    }
                )
            );
        }

        $ls->save( { password => DADA::Security::Password::encrypt_passwd($new_password), } );

        # -no_list_security_check, because the list password's changed, it wouldn't pass it anyways...
        my ( $headers, $body ) = $self->logout(
            -no_list_security_check => 1,
            -redirect_url           => $DADA::Config::S_PROGRAM_URL
              . '?flavor='
              . $DADA::Config::SIGN_IN_FLAVOR_NAME
              . '&list='
              . $list,
        );
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }
}

sub delete_list {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'delete_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $process = $q->param('process') || undef;

    if ( !$process ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'delete_list_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -list                     => $list,
                -vars                     => { screen => 'delete_list', },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        require DADA::MailingList;
        DADA::MailingList::Remove(
            {
                -name           => $list,
            }
        );

        $c->flush;

      #  my $logout_cookie = logout( -redirect => 0 );

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'delete_list_success_screen.tmpl',
                -with   => 'list',
                -wrapper_params => {
                   -Use_Custom => 0,
                },
                #	-list   => $list, # The list doesn't really exist anymore now, does it?
                # -wrapper_params => { -header_params => { -COOKIE => $logout_cookie }, }
            }
        );
        #my $headers = {
        #    -COOKIE  => $logout_cookie,
        #}; 
        
        require DADA::App::Session;
        my $dada_session  = DADA::App::Session->new( -List => $list );
        my $logout_cookie = $dada_session->logout_cookie( -cgi_obj => $q );
        
        
        $self->header_props(
            -cookie => $logout_cookie, 
        ); 
        return $scrn;
    }
}

sub list_options {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $process = $q->param('process') || undef;
    my $done    = $q->param('done')    || undef;

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $can_use_mx_lookup = 0;

    eval { require Net::DNS; };
    if ( !$@ ) {
        $can_use_mx_lookup = 1;
    }

    my $can_use_captcha = can_use_AuthenCAPTCHA();

    if ( !$process ) {
		require HTML::Menu::Select;
        my $send_subscription_notice_to_popup_menu = HTML::Menu::Select::popup_menu(
			{
	            name        => 'send_subscription_notice_to',
	            id          => 'send_subscription_notice_to',
	            default     => $ls->param('send_subscription_notice_to'),
	            labels      => { list => 'Your Subscribers', 'list_owner' => 'The List Owner', 'alt' => 'Other:'},
	            values      => [qw(list list_owner alt)],
			}
		);
        my $send_unsubscription_notice_to_popup_menu = HTML::Menu::Select::popup_menu(
			{
	            name     => 'send_unsubscription_notice_to',
	            id       => 'send_unsubscription_notice_to',
	            default  => $ls->param('send_unsubscription_notice_to'),
	            labels   => { list => 'Your Subscribers', 'list_owner' => 'The List Owner', 'alt' => 'Other:' },
	            values   => [qw(list list_owner alt)],
			}
		);
        my $send_admin_unsubscription_notice_to_popup_menu = HTML::Menu::Select::popup_menu(
			{
	            name     => 'send_admin_unsubscription_notice_to',
	            id       => 'send_admin_unsubscription_notice_to',
	            default  => $ls->param('send_admin_unsubscription_notice_to'),
	            labels   => { list => 'Your Subscribers', 'list_owner' => 'The List Owner', 'alt' => 'Other:' },
	            values => [qw(list list_owner alt)],
			}
		);

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'list_options_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -list => $list,
                -vars => {
                    screen                                         => 'list_options',
                    title                                          => 'Options',
                    done                                           => $done,
                    CAPTCHA_TYPE                                   => $DADA::Config::CAPTCHA_TYPE,
                    can_use_mx_lookup                              => $can_use_mx_lookup,
                    can_use_captcha                                => $can_use_captcha,
                    send_subscription_notice_to_popup_menu         => $send_subscription_notice_to_popup_menu,
                    send_unsubscription_notice_to_popup_menu       => $send_unsubscription_notice_to_popup_menu,
                    send_admin_unsubscription_notice_to_popup_menu => $send_admin_unsubscription_notice_to_popup_menu, 
                    list_owner_email_anonystar_address =>
                      DADA::App::Guts::anonystar_address_encode( $ls->param('list_owner_email') ),
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        if ( $q->param('anyone_can_subscribe') == 1 ) {
            $q->param( 'invite_only_list', 0 );
        }
        else {
            $q->param( 'invite_only_list', 1 );
        }

        my $list = $admin_list;
        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    private_list                            => 0,
                    hide_list                               => 0,
                    closed_list                             => 0,
                    invite_only_list                        => 0,
                    get_sub_notice                          => 0,
                    get_unsub_notice                        => 0,
                    enable_closed_loop_opt_in               => 0,
                    skip_sub_confirm_if_logged_in           => 0,
                    send_unsub_success_email                => 0,
                    send_sub_success_email                  => 0,
                    send_newest_archive                     => 0,
                    mx_check                                => 0,
                    limit_sub_confirm                       => 0,
                    limit_sub_confirm_use_captcha           => 0,
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
                    use_alt_url_subscription_approval_step  => 0,
                    alt_url_subscription_approval_step      => '',
                    alt_url_subscription_approval_step_w_qs => 0,

                    use_alt_url_unsub_success               => 0,
                    alt_url_unsub_success                   => '',
                    alt_url_unsub_success_w_qs              => 0,
                    unsub_show_email_hint                   => 0,
					one_click_unsubscribe                   => 0,
                    enable_subscription_approval_step       => 0,
                    enable_mass_subscribe                   => 0,
                    enable_mass_subscribe_only_w_root_login => 0,
                    send_subscribed_by_list_owner_message   => 0,
                    send_unsubscribed_by_list_owner_message => 0,
                    send_last_archived_msg_mass_mailing     => 0,
                    captcha_sub                             => 0,

                    send_subscription_notice_to             => undef,
                    send_unsubscription_notice_to           => undef,
                    
                    alt_send_unsubscription_notice_to       => undef, 
                    alt_send_subscription_notice_to         => undef,
                    alt_send_admin_unsubscription_notice_to => undef, 
                    
                    
                }
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=list_options&done=1' );

    }
}

sub api {

    my $self = shift;
    my $q    = $self->query();

    my $dp = $q->url || $DADA::Config::PROGRAM_URL;
    $dp =~ s/^(http:\/\/|https:\/\/)(.*?)\//\//;

    my $info = $q->path_info();

    $info =~ s/^$dp//;

    # script name should be something like:
    # /cgi-bin/dada/mail.cgi
    $info =~ s/^$ENV{SCRIPT_NAME}//i;
    $info =~ s/(^\/|\/$)//g;    #get rid of fore and aft slashes

    # seriously, this shouldn't be needed:
    $info =~ s/^dada\/mail\.cgi//;

    my ( $pi_flavor, $pi_list, $pi_service, $pi_public_key, $pi_digest ) = split( '/', $info );

    # https://metacpan.org/pod/distribution/CGI/lib/CGI.pod#FETCHING-ENVIRONMENT-VARIABLES
    # http://stackoverflow.com/questions/7362932/perl-equivalent-of-php-auth-pw
    # HTTP_AUTHORIZATION
    my %incoming_headers = map { $_ => $q->http($_) } $q->http();
    #use Data::Dumper;
    #warn Dumper( {%incoming_headers} );

    if ( !defined($pi_public_key) && !defined($pi_digest) ) {
        my $auth_h = $incoming_headers{HTTP_AUTHORIZATION};
        $auth_h =~ s/^hmac //;
        ( $pi_public_key, $pi_digest ) = split( ':', $auth_h );
    }
    if ( !defined( $q->param('nonce') ) && $ENV{REQUEST_METHOD} eq 'GET' ) {
        $q->param( 'nonce', $incoming_headers{'HTTP_X_DADA_NONCE'} );
    }

    $q->delete('flavor');    # ... probably.

    require DADA::App::WebServices;
    my $ws = DADA::App::WebServices->new;
    my ( $headers, $body ) = $ws->request(
        {
            -list       => $pi_list,
            -service    => $pi_service,
            -public_key => $pi_public_key,
            -digest     => $pi_digest,
            -cgi_obj    => $q,
        }
    );

    if ( keys %$headers ) {
        $self->header_props(%$headers);
    }
    return $body;
}

sub web_services {

    my $self = shift;
    my $q    = $self->query();

    my $process = $q->param('process') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'web_services'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( length( $ls->param('public_api_key') ) <= 0 || $process eq 'reset_keys' ) {
        require DADA::Security::Password;
        $ls->save( { public_api_key => DADA::Security::Password::generate_rand_string( undef, 21 ) } );
        undef $ls;
        $ls = DADA::MailingList::Settings->new( { -list => $list } );
    }
    if ( length( $ls->param('private_api_key') ) <= 0 || $process eq 'reset_keys' ) {
        require DADA::Security::Password;
        $ls->save( { private_api_key => DADA::Security::Password::generate_rand_string( undef, 41 ) } );
        undef $ls;
        $ls = DADA::MailingList::Settings->new( { -list => $list } );
    }
    my $keys_reset = 0;
    if ( $process eq 'reset_keys' ) {
        $keys_reset = 1;
    }

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'web_services.tmpl',
            -with           => 'admin',
            -expr           => 1,
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {
                keys_reset => $keys_reset,
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;

}

sub mail_sending_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mail_sending_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $ses_params = {};
    if ( $ls->param('sending_method') eq 'amazon_ses'
        || ( $ls->param('sending_method') eq 'smtp' && $ls->param('smtp_server') =~ m/amazonaws\.com/ ) )
    {
        $ses_params->{using_ses} = 1;
        require DADA::App::AmazonSES;
        my $ses = DADA::App::AmazonSES->new;
        $ses_params->{list_owner_ses_verified}     = $ses->sender_verified( $ls->param('list_owner_email') );
        $ses_params->{list_admin_ses_verified}     = $ses->sender_verified( $ls->param('admin_email') );
        $ses_params->{discussion_pop_ses_verified} = $ses->sender_verified( $ls->param('discussion_pop_email') );
    }
    if ( !$process ) {

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        require DADA::Security::Password;

        my $decrypted_sasl_pass = '';
        if ( $ls->param('sasl_smtp_password') ) {
            $decrypted_sasl_pass =
              DADA::Security::Password::cipher_decrypt( $ls->param('cipher_key'), $ls->param('sasl_smtp_password') );
        }

        my $decrypted_pop3_pass = '';
        if ( $ls->param('pop3_password') ) {
            $decrypted_pop3_pass =
              DADA::Security::Password::cipher_decrypt( $ls->param('cipher_key'), $ls->param('pop3_password') );
        }

        # DEV: This is really strange, since if Net::SMTP isn't available, SMTP sending is completely broken.
        my $can_use_net_smtp = 0;
        eval { require Net::SMTP_auth };
        if ( !$@ ) {
            $can_use_net_smtp = 1;
        }

        my $can_use_smtp_ssl = 0;
        eval { require Net::SMTP::SSL };
        if ( !$@ ) {
            $can_use_smtp_ssl = 1;
        }

        my $can_use_ssl = 0;
        eval { require IO::Socket::SSL };
        if ( !$@ ) {
            $can_use_ssl = 1;
        }

        my $mechanism_popup;
		require HTML::Menu::Select;

        if ($can_use_net_smtp) {			
            $mechanism_popup = HTML::Menu::Select::popup_menu(
				{ 
	                name     => 'sasl_auth_mechanism',
	                id       => 'sasl_auth_mechanism',
	                default  => $ls->param('sasl_auth_mechanism'),
	                values => [qw(PLAIN LOGIN DIGEST-MD5 CRAM-MD5)],
				}
			);
        }

        my $pop3_auth_mode_popup = HTML::Menu::Select::popup_menu(
			{
				name     => 'pop3_auth_mode',
	            id       => 'pop3_auth_mode',
	            default  => $ls->param('pop3_auth_mode'),
	            values   => [qw(BEST PASS APOP CRAM-MD5)],
	            labels   => { BEST => 'Automatic' },
			}
        );

        my $wrong_uid = 0;
        $wrong_uid = 1
          if $< != $>;

        my $no_smtp_server_set = 0;
        if (  !$ls->param('smtp_server')
            && $ls->param('sending_method') eq "smtp" )
        {
            $no_smtp_server_set = 1;
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'mail_sending_options_screen.tmpl',
                -with           => 'admin',
                -expr           => 1,
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    screen                        => 'mail_sending_options',
                    done                          => $done,
                    no_smtp_server_set            => $no_smtp_server_set,
                    mechanism_popup               => $mechanism_popup,
                    can_use_ssl                   => $can_use_ssl,
                    can_use_smtp_ssl              => $can_use_smtp_ssl,
                    'list_settings.pop3_username' => $ls->param('pop3_username'),    # DEV ?
                    decrypted_pop3_pass           => $decrypted_pop3_pass,
                    wrong_uid                     => $wrong_uid,
                    pop3_auth_mode_popup          => $pop3_auth_mode_popup,
                    can_use_ssl                   => $can_use_ssl,
                    f_flag_settings => $DADA::Config::MAIL_SETTINGS . ' -f' . $ls->param('admin_email'),

                    use_sasl_smtp_auth => scalar $q->param('use_sasl_smtp_auth') ? scalar $q->param('use_sasl_smtp_auth')
                    : $ls->param('use_sasl_smtp_auth'),
                    decrypted_pop3_pass => scalar $q->param('pop3_password') ? scalar $q->param('pop3_password')
                    : $decrypted_pop3_pass,
                    sasl_auth_mechanism => scalar $q->param('sasl_auth_mechanism') ? scalar $q->param('sasl_auth_mechanism')
                    : $ls->param('sasl_auth_mechanism'),
                    sasl_smtp_username => scalar $q->param('sasl_smtp_username') ? scalar $q->param('sasl_smtp_username')
                    : $ls->param('sasl_smtp_username'),
                    sasl_smtp_password => scalar $q->param('sasl_smtp_password') ? scalar $q->param('sasl_smtp_password')
                    : $decrypted_sasl_pass,

                    amazon_ses_requirements_widget => DADA::Template::Widgets::amazon_ses_requirements_widget(),
                    %$ses_params,

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        my $pop3_password = strip( scalar $q->param('pop3_password') ) || undef;
        if ( defined($pop3_password) ) {
            $q->param( 'pop3_password',
                DADA::Security::Password::cipher_encrypt( $ls->param('cipher_key'), $pop3_password ) );
        }
        my $sasl_smtp_password = strip( scalar $q->param('sasl_smtp_password') )
          || undef;
        if ( defined($sasl_smtp_password) ) {
            $q->param( 'sasl_smtp_password',
                DADA::Security::Password::cipher_encrypt( $ls->param('cipher_key'), $sasl_smtp_password ) );
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
            return undef;    # I mean, I guess...
        }
        else {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=mail_sending_options&done=1' );

        }
    }
}

sub mailing_sending_mass_mailing_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process');
    my $done    = $q->param('done');

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mailing_sending_mass_mailing_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {

        require DADA::Mail::MailOut;
        my $mo = DADA::Mail::MailOut->new( { -list => $list } );
        my ( $batch_sending_enabled, $batch_size, $batch_wait ) = $mo->batch_params();

        my $show_amazon_ses_options = 0;
        my $type_of_service         = 'ses';

        if (

            (
                $ls->param('sending_method') eq 'amazon_ses' || ( $ls->param('sending_method') eq 'smtp'
                    && $ls->param('smtp_server') =~ m/amazonaws\.com/ )
            )
            || ( ( $ls->param('sending_method') eq 'smtp' && $ls->param('smtp_server') =~ m/smtp\.mandrillapp\.com/ ) )
          )
        {
            $show_amazon_ses_options = 1;
            if (   $ls->param('sending_method') eq 'smtp'
                && $ls->param('smtp_server') =~ m/smtp\.mandrillapp\.com/ )
            {
                $type_of_service = 'mandrill';
            }
        }

        my @message_amount = ( 1 .. 180 );
        unshift( @message_amount, $batch_size );

        my @message_wait = ( 1 .. 60, 70, 80, 90, 100, 110, 110, 120, 130, 140, 150, 160, 170, 180 );

        unshift( @message_wait, $batch_wait );
        my @message_label = (1);
        my %label_label = ( 1 => 'second(s)', );

		require HTML::Menu::Select; 
        my $mass_send_amount_menu = HTML::Menu::Select::popup_menu(
            {
				name  => "mass_send_amount",
	            id    => "mass_send_amount",
	            value => [@message_amount],
	            class => 'previewBatchSendingSpeed',
			}
        );

        my $bulk_sleep_amount_menu = HTML::Menu::Select::popup_menu(
			{
	            name  => "bulk_sleep_amount",
	            id    => "bulk_sleep_amount",
	            value => [@message_wait],
	            class => 'previewBatchSendingSpeed',
			}
		);

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'mailing_sending_mass_mailing_options_screen.tmpl',
                -with           => 'admin',
                -expr           => 1,
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    screen                  => 'mailing_sending_mass_mailing_options',
                    done                    => $done,
                    batch_sending_enabled   => $batch_sending_enabled,
                    mass_send_amount_menu   => $mass_send_amount_menu,
                    bulk_sleep_amount_menu  => $bulk_sleep_amount_menu,
                    batch_size              => $batch_size,
                    batch_wait              => $batch_wait,
                    show_amazon_ses_options => $show_amazon_ses_options,
                    type_of_service         => $type_of_service,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
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
                    smtp_connection_per_batch         => 0,
                    mass_mailing_send_to_list_owner   => 0,
                    amazon_ses_auto_batch_settings    => 0,
                    mass_mailing_save_logs            => 0,
                }
            }
        );
        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=mailing_sending_mass_mailing_options&done=1' );
    }
}

sub amazon_ses_verify_email {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mail_sending_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $valid_email             = 1;
    my $status                  = undef;
    my $result                  = undef;
    my $amazon_ses_verify_email = xss_filter( strip( scalar $q->param('amazon_ses_verify_email') ) );
    if ( check_for_valid_email($amazon_ses_verify_email) == 1 ) {
        $valid_email = 0;
    }
    else {
        require DADA::App::AmazonSES;
        my $ses = DADA::App::AmazonSES->new;
        ( $status, $result ) = $ses->verify_sender( { -email => $amazon_ses_verify_email } );
    }

    my $body = DADA::Template::Widgets::screen(
        {
            -screen => 'amazon_ses_verify_email_widget.tmpl',
            -expr   => 1,
            -vars   => {
                amazon_ses_verify_email => $amazon_ses_verify_email,
                valid_email             => $valid_email,
                status                  => $status,
                result                  => $result,
            }
        }
    );
    return $body;
}

sub amazon_ses_get_stats {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mailing_sending_mass_mailing_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $has_ses_options = 1;
    if (   !defined( $DADA::Config::AMAZON_SES_OPTIONS->{AWSAccessKeyId} )
        || !defined( $DADA::Config::AMAZON_SES_OPTIONS->{AWSSecretKey} ) )
    {
        $has_ses_options = 0;
    }

    if (
        $ls->param('sending_method') eq 'amazon_ses'
        || (   $ls->param('sending_method') eq 'smtp'
            && $ls->param('smtp_server') =~ m/amazonaws\.com/ )
        || (   $ls->param('sending_method') eq 'smtp'
            && $ls->param('smtp_server') =~ m/smtp\.mandrillapp\.com/ )
      )
    {

        my $status                           = undef;
        my $SentLast24Hours                  = undef;
        my $Max24HourSend                    = undef;
        my $MaxSendRate                      = undef;
        my $allowed_sending_quota_percentage = undef;

        my $using_ses = 0;
        my $using_man = 0;

        if ( $ls->param('sending_method') eq 'amazon_ses'
            || ( $ls->param('sending_method') eq 'smtp' && $ls->param('smtp_server') =~ m/amazonaws\.com/ )
            && $has_ses_options == 1 )
        {
            require DADA::App::AmazonSES;
            my $ses = DADA::App::AmazonSES->new;
            ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $ses->get_stats;
            $allowed_sending_quota_percentage = $ses->allowed_sending_quota_percentage;
            $using_ses                        = 1;

        }
        elsif ($ls->param('sending_method') eq 'smtp'
            && $ls->param('smtp_server') =~ m/smtp\.mandrillapp\.com/ )
        {
            require DADA::App::Mandrill;
            my $man = DADA::App::Mandrill->new;
            ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $man->get_stats;
            $allowed_sending_quota_percentage = 100;
            $using_man                        = 1;

        }

        my $body = DADA::Template::Widgets::screen(
            {
                -screen => 'amazon_ses_get_stats_widget.tmpl',
                -expr   => 1,
                -vars   => {
                    status                           => $status,
                    has_ses_options                  => $has_ses_options,
                    MaxSendRate                      => commify($MaxSendRate),
                    Max24HourSend                    => commify($Max24HourSend),
                    SentLast24Hours                  => commify($SentLast24Hours),
                    allowed_sending_quota_percentage => $allowed_sending_quota_percentage,
                    using_ses                        => $using_ses,
                    using_man                        => $using_man,
                }
            }
        );
        return $body;
    }
    else {
        return undef;
    }

}

sub previewBatchSendingSpeed {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mailing_sending_mass_mailing_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $enable_bulk_batching           = xss_filter( scalar $q->param('enable_bulk_batching') );
    my $mass_send_amount               = xss_filter( scalar $q->param('mass_send_amount') );
    my $bulk_sleep_amount              = xss_filter( scalar $q->param('bulk_sleep_amount') );
    my $amazon_ses_auto_batch_settings = xss_filter( scalar $q->param('amazon_ses_auto_batch_settings') );

    my $per_hour         = 0;
    my $num_subs         = 0;
    my $time_to_send     = 0;
    my $somethings_wrong = 0;

    if ( $enable_bulk_batching == 1 ) {

        if ( $amazon_ses_auto_batch_settings == 1 ) {
            require DADA::Mail::MailOut;
            my $mo = DADA::Mail::MailOut->new( { -list => $list } );
            my $enabled;
            ( $enabled, $mass_send_amount, $bulk_sleep_amount ) =
              $mo->batch_params( { -amazon_ses_auto_batch_settings => 1 } );
        }

        if ( $bulk_sleep_amount > 0 && $mass_send_amount > 0 ) {

            my $per_sec = $mass_send_amount / $bulk_sleep_amount;
            $per_hour =
              int( $per_sec * 60 * 60 + .5 );    # DEV .5 is some sort of rounding thing (with int). That's wrong.

            $num_subs = $lh->num_subscribers;
            my $total_hours = 0;
            if ( $num_subs > 0 && $per_hour > 0 ) {
                $total_hours = $lh->num_subscribers / $per_hour;
            }

            $per_hour = commify($per_hour);
            $num_subs = commify($num_subs);

            $time_to_send = formatted_runtime( $total_hours * 60 * 60 );

        }
        else {
            $somethings_wrong = 1;
        }
    }

    my $body = DADA::Template::Widgets::screen(
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
    );
    return $body;

}

sub mail_sending_advanced_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process');
    my $done    = $q->param('done');

	
    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mail_sending_advanced_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::Security::Password;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );


    if ( !$process ) {
		
		require HTML::Menu::Select;
        unshift( @DADA::Config::CHARSETS, $ls->param('charset') );
        my $precedence_popup_menu = HTML::Menu::Select::popup_menu(
            {
				name    => "precedence",
	            id      => "precedence",
	            value   => [@DADA::Config::PRECEDENCES],
	            default => $ls->param('precedence'),
			}
        );

        my $priority_popup_menu = HTML::Menu::Select::popup_menu(
			{
	            name    => "priority",
	            id      => "priority",
	            value   => [ keys %DADA::Config::PRIORITIES ],
	            labels  => \%DADA::Config::PRIORITIES,
	            default => $ls->param('priority'),
			}
		);

        my $charset_popup_menu = HTML::Menu::Select::popup_menu(
            {
				name  => 'charset',
          	    id    => 'charset',
            	value => [@DADA::Config::CHARSETS],
        	}
		);

        my $plaintext_encoding_popup_menu = HTML::Menu::Select::popup_menu(
            {
				name    => 'plaintext_encoding',
				id      => 'plaintext_encoding',
	            value   => [@DADA::Config::CONTENT_TRANSFER_ENCODINGS],
	            default => $ls->param('plaintext_encoding'),
			}
        );

        my $html_encoding_popup_menu = HTML::Menu::Select::popup_menu(
            {
				name    => 'html_encoding',
				id      => 'html_encoding',
	            value   => [@DADA::Config::CONTENT_TRANSFER_ENCODINGS],
	            default => $ls->param('html_encoding'),
			}
        );

        my $can_mime_encode = 1;
        eval { require MIME::EncWords; };
        if ($@) {
            $can_mime_encode = 0;
        }
		

			
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'mail_sending_advanced_options_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -list => $list,
                -vars => {
                    screen                        => 'mail_sending_advanced_options',
                    title                         => 'Advanced Options',
                    done                          => $done,
                    precedence_popup_menu         => $precedence_popup_menu,
                    priority_popup_menu           => $priority_popup_menu,
                    charset_popup_menu            => $charset_popup_menu,
                    plaintext_encoding_popup_menu => $plaintext_encoding_popup_menu,
                    html_encoding_popup_menu      => $html_encoding_popup_menu,
                    can_mime_encode               => $can_mime_encode,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
		return $scrn;
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
                    verp_return_path             => 0,
                    mime_encode_words_in_headers => 0,
                }
            }
        );

        $self->header_type('redirect');
        $self->header_props( 
			-url => $DADA::Config::S_PROGRAM_URL . '?flavor=mail_sending_advanced_options&done=1'
		);

    }
}



sub mail_sending_options_test {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mail_sending_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    $q->param( 'no_redirect', 1 );

    # Saves the params passed
    $self->mail_sending_options();

    require DADA::Mail::Send;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $admin_list } );

    my $mh = DADA::Mail::Send->new(
        {
            -list   => $list,
            -ls_obj => $ls,
        }
    );

    my ( $results, $lines, $report );
    eval { ( $results, $lines, $report ) = $mh->mail_sending_options_test; };
    if ($@) {
        $results .= $@;
    }

    $results =~ s/\</&lt;/g;
    $results =~ s/\>/&gt;/g;

    my $ht_report = [];

    for my $f (@$report) {

        my $s_f = $f->{line};
        $s_f =~ s{Net\:\:SMTP(.*?)\)}{};
        push( @$ht_report, { SMTP_command => $s_f, message => $f->{message} } );
    }

    my $body = DADA::Template::Widgets::screen(
        {
            -screen => 'mail_sending_options_test_widget.tmpl',
            -expr   => 1,
            -vars   => {
                report  => $ht_report,
                raw_log => $results,
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $body;

}

sub view_list {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $add_email_count    = xss_filter( scalar $q->param('add_email_count') )    || 0;
    my $update_email_count = xss_filter( scalar $q->param('update_email_count') ) || 0;
    my $skipped_email_count = xss_filter( scalar $q->param('skipped_email_count') )
      || 0;
    my $delete_email_count               = xss_filter( scalar $q->param('delete_email_count') )               || 0;
    my $black_list_add                   = xss_filter( scalar $q->param('black_list_add') )                   || 0;
    my $approved_count                   = xss_filter( scalar $q->param('approved_count') )                   || 0;
    my $denied_count                     = xss_filter( scalar $q->param('denied_count') )                     || 0;
    my $bounced_list_moved_to_list_count = xss_filter( scalar $q->param('bounced_list_moved_to_list_count') ) || 0;
    my $bounced_list_removed_from_list   = xss_filter( scalar $q->param('bounced_list_removed_from_list') )   || 0;
    my $updated_addresses                = xss_filter( scalar $q->param('updated_addresses') )                || 0;
    my $type                             = xss_filter( scalar $q->param('type') )                             || 'list';
    my $query                            = xss_filter( scalar $q->param('query') )                            || undef;
    my $order_by        = $q->param('order_by')           || $ls->param('view_list_order_by');
    my $order_dir       = $q->param('order_dir')          || lc( $ls->param('view_list_order_by_direction') );
    my $mode            = xss_filter( scalar $q->param('mode') ) || 'view';
    my $page            = xss_filter( scalar $q->param('page') ) || 1;
    my $advanced_search = $q->param('advanced_search')    || 0;
    my $advanced_query  = $q->param('advanced_query')     || undef;

    if ( $mode ne 'viewport' ) {
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
                    screen          => 'view_list',
                    flavor          => 'view_list',
                    root_login      => $root_login,
                    type            => $type,
                    page            => $page,
                    query           => $query,
                    order_by        => $order_by,
                    order_dir       => $order_dir,
                    advanced_search => $advanced_search,
                    advanced_query  => $advanced_query,

                    add_email_count                  => $add_email_count,
                    update_email_count               => $update_email_count,
                    skipped_email_count              => $skipped_email_count,
                    delete_email_count               => $delete_email_count,
                    black_list_add                   => $black_list_add,
                    approved_count                   => $approved_count,
                    denied_count                     => $denied_count,
                    bounced_list_moved_to_list_count => $bounced_list_moved_to_list_count,
                    bounced_list_removed_from_list   => $bounced_list_removed_from_list,
                    updated_addresses                => $updated_addresses,
                    type_title                       => $DADA::Config::LIST_TYPES->{$type},

                },
            }
        );

        return $scrn;
    }
    else {

        # DEV: Yup. Forgot what this was for.
        if ( defined( $q->param('list') ) ) {
            if ( $list ne $q->param('list') ) {

                # I should look instead to see if we're logged in view ROOT and then just
                # *Switch* the login. Brilliant! --- maybe I don't want to switch lists automatically - without
                # someone perhaps knowing that THAT's what I did...
                my ( $headers, $body ) =
                  $self->logout( -redirect_url => $DADA::Config::S_PROGRAM_URL . '?' . $q->query_string(), );

                if ( keys %$headers ) {
                    $self->header_props(%$headers);
                }
                return $body;
            }
        }

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

        my $num_subscribers = $lh->num_subscribers( { -type => $type } );

        my $show_bounced_list = 0;
        if (   $lh->num_subscribers( { -type => 'bounced_list' } ) > 0
            || $ls->param('bounce_handler_when_threshold_reached') eq 'move_to_bounced_sublist' )
        {
            $show_bounced_list = 1;
        }

        my $subscribers = [];

        require Data::Pageset;
        my $page_info    = undef;
        my $pages_in_set = [];
        my $total_num    = 0;

        # warn '$query ' . $query;
        # warn '$advanced_query ' . $advanced_query;
        # warn ' $advanced_search' . $advanced_search;

        if ( $query || $advanced_query ) {

            if ( $advanced_search == 1 ) {
                open my $fh, '<', \$advanced_query || die $!;
                require CGI;
                my $new_q = CGI->new($fh);
                   $new_q->charset($DADA::Config::HTML_CHARSET);
                
                $new_q = decode_cgi_obj($new_q);
                my $partial_sending = partial_sending_query_to_params($new_q);

                ( $total_num, $subscribers ) = $lh->search_list(
                    {
                        -partial_listing => $partial_sending,
                        -type            => $type,
                        -start           => ( $page - 1 ),
                        '-length'        => $ls->param('view_list_subscriber_number'),
                        -order_by        => $order_by,
                        -order_dir       => $order_dir,

                    }
                );
            }
            else {

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
            }
            $page_info = Data::Pageset->new(
                {
                    total_entries    => $total_num,
                    entries_per_page => $ls->param('view_list_subscriber_number'),
                    current_page     => $page,
                    mode             => 'slide',                                     # default fixed
                    pages_per_set    => 10,
                }
            );

        }
        else {
            $subscribers = $lh->subscription_list(
                {
                    -type  => $type,
                    -start => ( $page - 1 )
                    , # this really should be just, $page, but subscription_list() would have to be updated, which will break a lot of things...
                    '-length'  => $ls->param('view_list_subscriber_number'),
                    -order_by  => $order_by,
                    -order_dir => $order_dir,

                    #-show_list_column      => 0,
                    #-show_timestamp_column => 0,
                }
            );
            $total_num = $num_subscribers;
            $page_info = Data::Pageset->new(
                {
                    total_entries    => $num_subscribers,
                    entries_per_page => $ls->param('view_list_subscriber_number'),
                    current_page     => $page,
                    mode             => 'slide',                                     # default fixed
                    pages_per_set    => 10,
                }
            );

        }

        foreach my $page_num ( @{ $page_info->pages_in_set() } ) {
            if ( $page_num == $page_info->current_page() ) {
                push( @$pages_in_set, { page => $page_num, on_current_page => 1 } );
            }
            else {
                push( @$pages_in_set, { page => $page_num, on_current_page => undef } );
            }
        }

        require DADA::ProfileFieldsManager;
        my $pfm         = DADA::ProfileFieldsManager->new;
        my $fields_attr = $pfm->get_all_field_attributes;

        my $field_names = [];
        my $undotted_fields = [ { name => 'email', label => 'Email Address' } ];
        for ( @{ $lh->subscriber_fields } ) {
            push(
                @$field_names,
                {
                    name          => $_,
                    label         => $fields_attr->{$_}->{label},
                    S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL
                },
            );
            push(
                @$undotted_fields,
                {
                    name          => $_,
                    label         => $fields_attr->{$_}->{label},
                    S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL
                },
            );
        }

        my $scrn = DADA::Template::Widgets::screen(
            {
                -list   => $list,
                -screen => 'view_list_viewport_widget.tmpl',
                -expr   => 1,
                -vars   => {
                    can_have_subscriber_fields => 1,
                    screen                     => 'view_list',
                    flavor                     => 'view_list',
                    root_login                 => $root_login,

                    type       => $type,
                    type_title => $DADA::Config::LIST_TYPES->{$type},

                    first                 => $page_info->first,
                    last                  => $page_info->last,
                    first_page            => $page_info->first_page,
                    last_page             => $page_info->last_page,
                    next_page             => $page_info->next_page,
                    previous_page         => $page_info->previous_page,
                    page                  => $page_info->current_page,
                    show_list_column      => 0,
                    show_timestamp_column => $ls->param('view_list_show_timestamp_col'),
                    field_names           => $field_names,
                    undotted_fields       => $undotted_fields,

                    pages_in_set        => $pages_in_set,
                    num_subscribers     => commify($num_subscribers),
                    total_num           => $total_num,
                    total_num_commified => commify($total_num),
                    subscribers         => $subscribers,
                    query               => $query,
                    advanced_search     => $advanced_search,
                    advanced_query      => $advanced_query,
                    order_by            => $order_by,
                    order_dir           => $order_dir,

                    show_bounced_list => $show_bounced_list,

                    GLOBAL_BLACK_LIST  => $DADA::Config::GLOBAL_BLACK_LIST,
                    GLOBAL_UNSUBSCRIBE => $DADA::Config::GLOBAL_UNSUBSCRIBE,

                    can_use_global_black_list  => $lh->can_use_global_black_list,
                    can_use_global_unsubscribe => $lh->can_use_global_unsubscribe,

                    can_filter_subscribers_through_blacklist => $lh->can_filter_subscribers_through_blacklist,

                    flavor_is_view_list        => 1,
                    list_subscribers_num       => commify( $lh->num_subscribers( { -type => 'list' } ) ),
                    black_list_subscribers_num => commify( $lh->num_subscribers( { -type => 'black_list' } ) ),
                    white_list_subscribers_num => commify( $lh->num_subscribers( { -type => 'white_list' } ) ),
                    authorized_senders_num     => commify( $lh->num_subscribers( { -type => 'authorized_senders' } ) ),
                    moderators_num             => commify( $lh->num_subscribers( { -type => 'moderators' } ) ),
                    sub_request_list_subscribers_num =>
                      commify( $lh->num_subscribers( { -type => 'sub_request_list' } ) ),
                    unsub_request_list_subscribers_num =>
                      commify( $lh->num_subscribers( { -type => 'unsub_request_list' } ) ),
                    bounced_list_num => commify( $lh->num_subscribers( { -type => 'bounced_list' } ) ),
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
}

sub mass_update_profiles {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list          = $admin_list;
    my $ls            = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh            = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $update_fields = {};

    for my $field ( @{ $lh->subscriber_fields() } ) {
        if ( $q->param( 'update.' . $field ) == 1 ) {
            $update_fields->{$field} = $q->param($field);
        }
    }

    my $advanced_query = xss_filter( scalar $q->param('advanced_query') ) || undef;
    open my $fh, '<', \$advanced_query || die $!;
    require CGI;
    my $new_q = CGI->new($fh);
       $new_q->charset($DADA::Config::HTML_CHARSET);
    $new_q = decode_cgi_obj($new_q);
    my $partial_listing = partial_sending_query_to_params($new_q);

    my $updated = $lh->update_profiles(
        {

            -update_fields   => $update_fields,
            -partial_listing => $partial_listing,

        }
    );

    # And then, we're return with a search query, to show the results:
    $q->param( 'updated_addresses', $updated );
    $q->param( 'advanced_search',   1 );
    $q->param( 'done',              1 );

    undef($new_q);
    require CGI;
    $new_q = CGI->new;
    $new_q->charset($DADA::Config::HTML_CHARSET);
    $new_q->delete_all;

    #    $new_q->param('favorite_color.operator', '=');
    #    $new_q->param('favorite_color.value', 'mauve');

    for my $field (%$update_fields) {
        $new_q->param( $field . '.operator', '=' );
        $new_q->param( $field . '.value',    $update_fields->{$field} );
    }

    my $new_advanced_search_query = $new_q->query_string();
    $new_advanced_search_query =~ s/\;/\&/g;

    $q->param( 'advanced_query', $new_advanced_search_query );

    return $self->view_list();
}

sub domain_breakdown_json {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    my $type = $q->param('type') || 'list';

    require DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $headers = {
        '-Cache-Control' => 'no-cache, must-revalidate',
        -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
        -type            => 'application/json',
    };
    my $body = $lh->domain_stats_json(
        {
            -type     => $type,
            -count    => 15,
            -printout => 0,
        }
    );

    if ( keys %$headers ) {
        $self->header_props(%$headers);
    }
    return $body;
}

sub search_list_auto_complete {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $query = xss_filter( scalar $q->param('query') ) || undef;
    my $type  = xss_filter( scalar $q->param('type') )  || 'list';

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my ( $total_num, $subscribers ) = $lh->search_list(
        {
            -query    => $query,
            -type     => $type,
            '-length' => 10,
        }
    );

    my $r = [];
    for my $result (@$subscribers) {
        push( @$r, { 'email' => $result->{email} } );
    }

    require JSON;
    my $json = JSON->new->allow_nonref;

    $self->header_props( -type => 'application/json' );
    return $json->encode($r);

}

sub list_activity {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_activity'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    require DADA::App::LogSearch;
    my $dals = DADA::App::LogSearch->new;
    my $r = $dals->list_activity( { -list => $list, } );
    my $i;
    for ( $i = 0 ; $i <= ( scalar(@$r) - 1 ) ; $i++ ) {
        $r->[$i]->{show_email} = 1;
    }

    my $body = DADA::Template::Widgets::wrap_screen(
        {
            -list           => $list,
            -screen         => 'list_activity_screen.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => { history => $r, },
            -expr => 1,
        }
    );
    return $body;

}

sub sub_unsub_trends_json {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_activity'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $days = xss_filter( strip( scalar $q->param('days') ) );

    require DADA::App::LogSearch;
    my $dals = DADA::App::LogSearch->new;

    my $headers = {
        '-Cache-Control' => 'no-cache, must-revalidate',
        -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
        -type            => 'application/json',
    };
    my $r = $dals->sub_unsub_trends_json(
        {
            -list     => $list,
            -printout => 0,
            -days     => $days,
        }
    );

    $self->header_props(%$headers);
    return $r;
}

sub view_bounce_history {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list           = $admin_list;
    my $return_to      = $q->param('return_to') || 'view_list';
    my $return_address = $q->param('return_address') || undef;

    require DADA::App::BounceHandler::Logs;
    my $bhl     = DADA::App::BounceHandler::Logs->new;
    my $results = $bhl->search(
        {
            -query => scalar $q->param('email'),
            -list  => $list,
            -file  => $DADA::Config::LOGS . '/bounces.txt',
        }
    );

    my $body = DADA::Template::Widgets::screen(
        {
            -screen => 'bounce_search_results_modal_menu.tmpl',
            -vars   => {
                search_results => $results,
                total_bounces  => scalar(@$results),
                email          => scalar $q->param('email'),
                type           => 'bounced_list',
                return_to      => $return_to,
                return_address => $return_address,
            }
        }
    );
    return $body;
}

sub subscription_requests {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    #?
    if ( defined( $q->param('list') ) ) {
        if ( $list ne $q->param('list') ) {
            my ( $headers, $body ) =
              $self->logout( -redirect_url => $DADA::Config::S_PROGRAM_URL . '?' . $q->query_string(), );
            if ( keys %$headers ) {
                $self->header_props(%$headers);
            }
            return $body;
        }
    }

    my @address        = $q->multi_param('address');
    my $return_to      = $q->param('return_to') || '';
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
            $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_confirm_list',
                }
            );

            my $new_pass    = '';
            my $new_profile = 0;
            if (   $DADA::Config::PROFILE_OPTIONS->{enabled} == 1
                && $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ )
            {

                # Make a profile, if needed,
                require DADA::Profile;
                my $prof = DADA::Profile->new( { -email => scalar $q->param('email') } );
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
                    -email  => scalar $q->param('email'),
                    -ls_obj => $ls,

                    #-test   => $self->test,
                    -vars => {
                        new_profile        => $new_profile,
                        'profile.email'    => scalar $q->param('email'),
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

        my $qs = 'f=' . $flavor_to_return_to . '&type=' . scalar($q->param('type')) . '&approved_count=' . $count;

        if ( $return_to eq 'membership' ) {
            $qs .= '&email=' . $return_address;
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
    }
    elsif ( $q->param('process') =~ m/deny/i ) {
        for my $email (@address) {
            $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_request_list',
                }
            );
            $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_confirm_list',
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

        my $qs = 'f=' . $flavor_to_return_to . '&type=' . scalar($q->param('type')) . '&denied_count=' . $count;

        if ( $return_to eq 'membership' ) {
            $qs .= '&email=' . $return_address;
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );

    }
    else {
        die "unknown process!";
    }

}

sub unsubscription_requests {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    #    #?
    #    if ( defined( $q->param('list') ) ) {
    #        if ( $list ne $q->param('list') ) {
    #            my ( $headers, $body ) =
    #              $self->logout( -redirect_url => $DADA::Config::S_PROGRAM_URL . '?' . $q->query_string(), );
    #            if ( keys %$headers ) {
    #                $self->header_props(%$headers);
    #            }
    #            return $body;
    #        }
    #    }

    my @address        = $q->multi_param('address');
    my $return_to      = $q->param('return_to') || '';
    my $return_address = $q->param('return_address') || '';

    my $count = 0;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ( $q->param('process') =~ m/approve/i ) {

        # go!
        my ( $d_count, $bl_count ) = $lh->admin_remove_subscribers(
            {
                -addresses        => [@address],
                -type             => 'list',
                -validation_check => 0,
            }
        );

        for my $email (@address) {
            $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'unsub_request_list',
                }
            );

            #           warn 'send_unsubscription_request_approved_message'
            #                if $t;
            require DADA::App::Messages;
            DADA::App::Messages::send_unsubscription_request_approved_message(
                {
                    -list   => $list,
                    -email  => $email,
                    -ls_obj => $ls,

                    #-test   => $self->test,
                }
            );
        }
        
        $count = int($count) + int($d_count);
        
        my $flavor_to_return_to = 'view_list';
        if ( $return_to eq 'membership' ) {    # or, others...
            $flavor_to_return_to = $return_to;
        }

        my $qs = 'f=' . $flavor_to_return_to . '&type=' . scalar( $q->param('type') ) . '&approved_count=' . $count;

        if ( $return_to eq 'membership' ) {
            $qs .= '&email=' . $return_address;
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
    }
    elsif ( $q->param('process') =~ m/deny/i ) {
        for my $email (@address) {
            $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'unsub_request_list',
                }
            );
            require DADA::App::Messages;
            DADA::App::Messages::send_unsubscription_request_denied_message(
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

        my $qs = 'f=' . $flavor_to_return_to . '&type=' . scalar( $q->param('type') ) . '&denied_count=' . $count;

        if ( $return_to eq 'membership' ) {
            $qs .= '&email=' . $return_address;
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );

    }
    else {
        die "unknown process!";
    }

}



sub remove_all_subscribers {

    my $self = shift;
    my $q    = $self->query();

    # This needs that email notification as well...
    # I need to first, clone the list and then do my thing.
    # Cloning will be really be resource intensive, so we can't do
    # checks on each address,
    # maybe the only check we'll do is to see if anything currently exists.
    # If there is? Don't do the clone.
    # If there isn't Do the clone
    # maybe have a parameter saying what to do on an error.
    # or just return undef.

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list',
    );
    if ( !$checksout ) { return $error_msg; }

    my $list           = $admin_list;
    my $black_list_add = 0;

    my $type = xss_filter( scalar $q->param('type') );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::App::MassSend;
    if ( $type eq 'list' ) {
        if ( $ls->param('send_unsubscribed_by_list_owner_message') == 1 ) {
            require DADA::App::MassSend;
            eval {
                my $dam = DADA::App::MassSend->new( { -list => $list } );
                   $dam->just_unsubscribed_mass_mailing(
                    {
                        -send_to_everybody => 1,
                    }
                );
            };
            if ($@) {
                carp $@;
            }
        }

        if (   $ls->param('black_list') == 1
            && $ls->param('add_unsubs_to_black_list') == 1 )
        {
            $black_list_add = $lh->copy_all_subscribers(
                {
                    -from => 'list',
                    -to   => 'black_list',
                }
            );
        }

    }

    my $count = $lh->remove_all_subscribers( { -type => $type, } );

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
          . '?flavor=view_list&delete_email_count='
          . $count
          . '&type='
          . $type
          . '&black_list_add='
          . $black_list_add );

}

sub filter_using_black_list {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process');

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'filter_using_black_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    if ( !$process ) {

        my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        my $filtered = $lh->filter_list_through_blacklist;

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -list           => $list,
                -screen         => 'filter_using_black_list.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => { filtered => $filtered, },
            }
        );
        return $scrn;
    }
}

sub membership {

    my $self = shift;
    my $q    = $self->query();

    if ( !defined( $q->param('email') ) ) {
        $self->view_list();
    }
    my $type = $q->param('type') || 'list';

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $process = $q->param('process')             || undef;
    my $done    = $q->param('done')                || undef;
    my $query   = xss_filter( scalar $q->param('query') ) || undef;
    my $page    = xss_filter( scalar $q->param('page') )  || 1;
    my $type    = xss_filter( scalar $q->param('type') );

    my $order_by  = $q->param('order_by')  || $ls->param('view_list_order_by');
    my $order_dir = $q->param('order_dir') || lc( $ls->param('view_list_order_by_direction') );

    my $add_email_count                  = $q->param('add_email_count') || 0;
    my $delete_email_count               = $q->param('delete_email_count');
    my $black_list_add                   = $q->param('black_list_add') || 0;
    my $approved_count                   = $q->param('approved_count') || 0;
    my $denied_count                     = $q->param('denied_count') || 0;
    my $bounced_list_moved_to_list_count = $q->param('bounced_list_moved_to_list_count') || 0;
    my $bounced_list_removed_from_list   = $q->param('bounced_list_removed_from_list') || 0;

    my $profile_exists = 0;
    require DADA::Profile;
    my $prof = DADA::Profile->new( { -email => scalar $q->param('email') } );
    if ($prof) {
        $profile_exists = $prof->exists;
    }
    if ($process) {
        if ( $root_login != 1 && $ls->param('allow_profile_editing') != 1 ) {
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
                -email  => scalar $q->param('email'),
                -fields => $new_fields,
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
              . '?flavor=membership&email='
              . scalar($q->param('email'))
              . '&type='
              . $type
              . '&done=1' );
    }
    else {

        my $fields = [];

        my $subscriber_info = {};

        # this is a hack - if type has nothing, this fails, so we fill it in with, "list"
        if ( !defined($type) || $type eq '' ) { $type = 'list'; }
        $subscriber_info = $lh->get_subscriber( { -email => scalar $q->param('email') } );

        # DEV: This is repeated quite a bit...
        require DADA::ProfileFieldsManager;
        my $pfm         = DADA::ProfileFieldsManager->new;
        my $fields_attr = $pfm->get_all_field_attributes;
        for my $field ( @{ $lh->subscriber_fields() } ) {
            push(
                @$fields,
                {
                    name     => $field,
                    value    => $subscriber_info->{$field},
                    label    => $fields_attr->{$field}->{label},
                    required => $fields_attr->{$field}->{required},
                }
            );
        }

        my $subscribed_to_lt = {};
        for ( @{ $lh->member_of( { -email => scalar $q->param('email') } ) } ) {
            $subscribed_to_lt->{$_} = 1;
        }

        my %add_list_types = %{ DADA::App::Guts::list_types() };

        my $add_to = {
            list               => 1,
            black_list         => 1,
            white_list         => 1,
            authorized_senders => 1,
            moderators         => 1,
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

        # if Moderators isn't active, well, let's not allow to be added:
        if ( $ls->param('enable_moderation') == 1 ) {

            #...
        }
        else {
            delete( $add_to->{moderators} );
        }

        # Same with the white list
        if ( $ls->param('enable_white_list') == 1 ) {

            #...
        }
        else {
            delete( $add_to->{white_list} );

        }

        my $is_bouncing_address = 0;
        my $bouncing_info       = '';
        if ( $subscribed_to_lt->{bounced_list} == 1 ) {
            $is_bouncing_address = 1;

        }

		require HTML::Menu::Select; 
        my $add_to_popup_menu = HTML::Menu::Select::popup_menu(
			{
	            name     => 'type',
	            id       => 'type_add',
	            default  => 'list',
	            values  => [ keys %$add_to ],
	            labels   => \%add_list_types,
	        }
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
        my $list_types  = DADA::App::Guts::list_types();

        foreach (%$subscribed_to_lt) {
            if ( $_ =~ m/^(list|black_list|white_list|authorized_senders|moderators|bounced_list)$/ ) {
                push( @$member_of, { type => $_, type_title => $list_types->{$_} } );
                push( @$remove_from, $_ );
            }
        }

		require HTML::Menu::Select;
        my $remove_from_popup_menu = HTML::Menu::Select::popup_menu(
	        {    name     => 'type_remove',
	            id       => 'type_remove',
	            values => $remove_from,
	            labels   => $list_types,
	        }
		);

        my @update_option_values = ( ':all', ( keys %$subscribed_to_lt ) );
        my %update_option_labels = ( ':all' => 'All Sublists', $list_types );
        my $update_address_popup_menu = HTML::Menu::Select::popup_menu(
			{
	            name     => 'type_update',
	            id       => 'type_update',
	            values => [@update_option_values],
	            labels   => {%update_option_labels},
	        }
		);

        my $subscribed_to_list = 0;
        if ( $subscribed_to_lt->{list} == 1 ) {
            $subscribed_to_list = 1;

        }

        my $subscribed_to_sub_request_list = 0;
        if ( $subscribed_to_lt->{sub_request_list} == 1 ) {
            $subscribed_to_sub_request_list = 1;

        }

        require DADA::Profile::Settings;
        my $dpa = DADA::Profile::Settings->new;
        my $s   = $dpa->fetch(
            {
                -list  => $list,
                -email => scalar $q->param('email'),
            }
        );
        my $delivery_prefs = $s->{delivery_prefs} || 'individual';
        my $digest_timeframe = formatted_runtime( $ls->param('digest_schedule') );

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'membership_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -vars => {
                    done                           => $done,
                    email                          => scalar $q->param('email'),
                    type                           => $type,
                    page                           => $page,
                    query                          => $query,
                    order_by                       => $order_by,
                    order_dir                      => $order_dir,
                    type_title                     => $DADA::Config::LIST_TYPES->{$type},
                    fields                         => $fields,
                    root_login                     => $root_login,
                    profile_exists                 => $profile_exists,
                    add_to_popup_menu              => $add_to_popup_menu,
                    update_address_popup_menu      => $update_address_popup_menu,
                    remove_from_popup_menu         => $remove_from_popup_menu,
                    remove_from_num                => scalar(@$remove_from),
                    member_of                      => $member_of,
                    is_bouncing_address            => $is_bouncing_address,
                    rand_string                    => generate_rand_string_md5(),
                    member_of_num                  => scalar(@$remove_from),
                    add_to_num                     => scalar( keys %$add_to ),
                    subscribed_to_list             => $subscribed_to_list,
                    subscribed_to_sub_request_list => $subscribed_to_sub_request_list,

                    add_email_count                  => $add_email_count,
                    delete_email_count               => $delete_email_count,
                    black_list_add                   => $black_list_add,
                    approved_count                   => $approved_count,
                    denied_count                     => $denied_count,
                    bounced_list_moved_to_list_count => $bounced_list_moved_to_list_count,
                    bounced_list_removed_from_list   => $bounced_list_removed_from_list,

                    can_have_subscriber_fields => $lh->can_have_subscriber_fields,

                    delivery_prefs   => $delivery_prefs,
                    digest_timeframe => $digest_timeframe,

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
}

sub validate_update_email {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Subscribers;
    require DADA::MailingList::Subscriber::Validate;
    require DADA::MailingList::Settings;

    my $list_types = DADA::App::Guts::list_types();

    my %error_title = (
        invalid_email    => 'Invalid Email Address',
        subscribed       => 'Already Subscribed',
        mx_lookup_failed => 'MX Lookup Failed',
        black_listed     => 'Black Listed',
        not_white_listed => 'Not on the White List',
    );

    my $for_all_lists     = $q->param('for_all_lists') || 0;
    my $lists_to_validate = [];
    my $email             = cased( xss_filter( scalar $q->param('email') ) );
    my $updated_email     = cased( xss_filter( scalar $q->param('updated_email') ) );
    my $process           = $q->param('process') || 0;

    my $list_lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    # not sure where I'm going with, with, "can_have_subscriber_fields"
    if ( $list_lh->can_have_subscriber_fields ) {
        if ( $for_all_lists == 1 && $root_login == 1 ) {
            require DADA::Profile;
            my $prof = DADA::Profile->new( { -email => $email } );
            $lists_to_validate = $prof->subscribed_to;
        }
        else {
            push( @$lists_to_validate, $list );
        }
    }
    else {
        push( @$lists_to_validate, $list );
    }

    # old address

    if ( $process != 1 ) {

        my $list_validations = [];
        my $none_validated   = 1;

        for my $to_validate_list (@$lists_to_validate) {

            my $type_reports = [];

            my $lh = DADA::MailingList::Subscribers->new( { -list => $to_validate_list } );
            my $sv = DADA::MailingList::Subscriber::Validate->new( { -list => $to_validate_list } );
            my $ls = DADA::MailingList::Settings->new( { -list => $to_validate_list } );

            for my $type (
                @{
                    $lh->member_of(
                        {
                            -email => $email,
                            -types => [qw(list black_list white_list authorized_senders moderators)],
                        }
                    )
                }
              )
            {
                my $sublists = [];

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
                            'profile_fields',
                            ( $ls->param('allow_admin_to_subscribe_blacklisted') == 1 ) ? ( 'black_listed', ) : (),
                        ],
                    }
                );

                if ( $sub_status == 1 && $none_validated == 1 ) {
                    $none_validated = 0;
                }
                my $errors = [];
                for ( keys %$sub_errors ) {
                    push( @$errors, { error => $_, error_title => $error_title{$_} } );
                }

                $sublists = {
                    type                 => $type,
                    type_label           => $list_types->{$type},
                    status               => $sub_status,
                    errors               => $errors,
                    'list_settings.list' => $ls->param('list'),

                };
                push( @$type_reports, $sublists );
            }

            push(
                @$list_validations,
                {
                    'list_settings.list'      => $ls->param('list'),
                    'list_settings.list_name' => $ls->param('list_name'),
                    sublists                  => $type_reports
                },
            );

        }

        require Data::Dumper;

        my $scrn = DADA::Template::Widgets::screen(
            {
                -screen => 'validate_update_email_widget.tmpl',
                -expr   => 1,
                -vars   => {
                    email                  => $email,
                    updated_email          => $updated_email,
                    update_list_validation => $list_validations,
                    none_validated         => $none_validated,
                    validate_dump          => Data::Dumper::Dumper($list_validations),

                    #all_list_status       => $all_list_status,
                    #all_list_reports      => $all_list_reports,
                    #for_all_lists         => $for_all_lists,
                    #root_login            => $root_login,

                },
            }
        );
        return $scrn;

    }
    else {
        my @update_list   = $q->multi_param('update_list');
        my $total_u_count = 0;

        foreach my $update_list (@update_list) {
            my ( $u_list, $u_type ) = split( ':', $update_list, 2 );
            my $lh = DADA::MailingList::Subscribers->new( { -list => $u_list } );
            my ($u_count) = $lh->admin_update_address(
                {
                    -email            => $email,
                    -updated_email    => $updated_email,
                    -type             => $u_type,
                    -validation_check => 0,
                }
            );
            $total_u_count = $total_u_count + $u_count;

        }

        my $return_to      = 'membership';
        my $return_address = $updated_email;

        my $qs = 'flavor=' . $return_to . '&update_email_count=' . $total_u_count;

        if ( $return_to eq 'membership' ) {
            $qs .= '&email=' . $return_address;
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );

    }

}

sub also_member_of {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list  = $admin_list;
    my $email = xss_filter( scalar $q->param('email') );
    my $type  = xss_filter( scalar $q->param('type') ) || 'list';

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $mto = 0;

    my @also_subscribed_to = $lh->also_subscribed_to(
        {
            -email => $email,
            -types => [qw(list black_list white_list authorized_senders moderators)],
        }
    );
    if ( scalar @also_subscribed_to > 0 ) {
        $mto = 1;
    }
    require JSON;
    my $json    = JSON->new->allow_nonref;
    my $headers = { -type => 'application/json' };
    my $body    = $json->encode(
        {
            also_member_of => int($mto)
        }
    );
    $self->header_props(%$headers);
    return $body;
}

sub validate_remove_email {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list               = $admin_list;
    my $type               = xss_filter( scalar $q->param('type') );
    my $email              = xss_filter( scalar $q->param('email') );
    my $process            = xss_filter( scalar $q->param('process') ) || 0;
    my @remove_from_list   = $q->multi_param('remove_from_list');
    my $return_to          = xss_filter( scalar $q->param('return_to') ) || 0;
    my $for_multiple_lists = xss_filter( scalar $q->param('for_multiple_lists') ) || 0;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {
        my @lists = ($list);
        if ( $for_multiple_lists == 1 ) {
            my @also_subscribed_to = $lh->also_subscribed_to(
                {
                    -email => $email,
                    -types => [qw(list black_list white_list authorized_senders moderators)],
                }
            );
            @lists = ( @lists, @also_subscribed_to );
        }

        my $subscribed_lists = [];

        my $list_types = DADA::App::Guts::list_types();

        foreach my $tmp_list (@lists) {
            my $tmp_ls = DADA::MailingList::Settings->new( { -list => $tmp_list } );
            my $tmp_lh = DADA::MailingList::Subscribers->new( { -list => $tmp_list } );

            my $sublists = [];
            for my $sublist (
                @{
                    $tmp_lh->member_of(
                        {
                            -email => $email,
                            -types => [qw(list black_list white_list authorized_senders moderators)],
                        }
                    )
                }
              )
            {
                push(
                    @$sublists,
                    {
                        type                      => $sublist,
                        type_label                => $list_types->{$sublist},
                        'list_settings.list'      => $tmp_ls->param('list'),
                        'list_settings.list_name' => $tmp_ls->param('list_name'),
                    }
                );
            }

            push(
                @$subscribed_lists,
                {
                    'list_settings.list'      => $tmp_ls->param('list'),
                    'list_settings.list_name' => $tmp_ls->param('list_name'),
                    sublists                  => $sublists,
                }
            );
        }

        require Data::Dumper;
        my $subscribed_lists_dump = Data::Dumper::Dumper($subscribed_lists);

        my $body = DADA::Template::Widgets::screen(
            {
                -screen => 'validate_remove_email_widget.tmpl',
                -vars   => {
                    email                 => $email,
                    list_type             => $type,
                    list_type_label       => $list_types->{$type},
                    for_multiple_lists    => $for_multiple_lists,
                    subscribed_lists      => $subscribed_lists,
                    subscribed_lists_dump => $subscribed_lists_dump,
                }
            }
        );

        return $body;
    }
    else {

        my $full_d_count  = 0;
        my $full_bl_count = 0;
        foreach my $remove_list (@remove_from_list) {
            my ( $r_list, $r_type ) = split( ':', $remove_list, 2 );
            my $lh = DADA::MailingList::Subscribers->new( { -list => $r_list } );
            my ( $d_count, $bl_count ) = $lh->admin_remove_subscribers(
                {
                    -addresses        => [$email],
                    -type             => $r_type,
                    -validation_check => 0,
                }
            );
            $full_d_count  = $full_d_count + $d_count;
            $full_bl_count = $full_bl_count + $bl_count;
        }

        my $return_address = $email;

        my $qs =
            'flavor='
          . $return_to
          . '&delete_email_count='
          . $full_d_count
          . '&type=' . ''
          . '&black_list_add='
          . $full_bl_count;

        if ( $return_to eq 'membership' ) {
            $qs .= '&email=' . $return_address;
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
    }
}

sub mailing_list_history {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list               = $admin_list;
    my $email              = xss_filter( scalar $q->param('email') );
    my $membership_history = xss_filter( scalar $q->param('membership_history') )
      || 'this_list';
    my $mode = xss_filter( scalar $q->param('mode') ) || 'html';

    require DADA::App::LogSearch;
    my $searcher = DADA::App::LogSearch->new;
    my $r;

    if ( $membership_history eq 'this_list' ) {
        $r = $searcher->subscription_search(
            {
                -email => $email,
                -list  => $list,
            }
        );
    }
    else {
        $r = $searcher->subscription_search( { -email => $email, } );

    }

    @$r = reverse(@$r);

    if ( $mode eq 'html' ) {

        my $i;
        for ( $i = 0 ; $i <= ( scalar(@$r) - 1 ) ; $i++ ) {
            $r->[$i]->{show_email} = 0;
            unless ( $membership_history eq 'this_list' ) {
                $r->[$i]->{show_list_name} = 1;
            }
        }

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
        return $scrn;
    }
    elsif ( $mode eq 'export_csv' ) {

        require Text::CSV;
        my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
        my $fh  = \*STDOUT;

        my $headers = {
            -attachment => 'membership_history-' . $list . '-' . time . '.csv',
            -type       => 'text/csv',
        };

        my $body;
        my @cols = qw(
          date
          list
          list_name
          ip
          email
          type
          type_title
          action
          updated_email
        );

        my $status = $csv->combine(@cols);
        $body .= $csv->string() . "\n";

        for my $line (@$r) {
            my @lines = ();
            foreach (@cols) {
                push( @lines, $line->{$_} );
            }
            $status = $csv->combine(@lines);
            $body .= $csv->string() . "\n";
        }

        $self->header_props(%$headers);
        return $body;
    }
}

sub membership_activity {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list  = $admin_list;
    my $email = xss_filter( scalar $q->param('email') );
    my $mode  = xss_filter( scalar $q->param('mode') ) || 'html';

    if ( $mode eq 'html' ) {
        require DADA::Logging::Clickthrough;
        my $rd = DADA::Logging::Clickthrough->new( { -list => $list } );

        require DADA::MailingList::Archives;
        my $ma = DADA::MailingList::Archives->new( { -list => $list } );

        my $activity_tables = [];
        my ( $total, $mids ) = $rd->get_all_mids;
        foreach my $mid (@$mids) {
            my $plugin_url = $DADA::Config::S_PROGRAM_URL;
            $plugin_url =~ s/mail\.cgi$/plugins\/tracker.cgi/;
            my $activity_table = $rd->message_individual_email_activity_report_table(
                {
                    -mid        => $mid,
                    -email      => $email,
                    -plugin_url => $plugin_url,

                }
            );

            my $archive_exists  = 0;
            my $archive_subject = '';
            if ( $ma->check_if_entry_exists($mid) ) {
                $archive_exists  = 1;
                $archive_subject = $ma->get_archive_subject($mid);
            }

            push(
                @$activity_tables,
                {
                    activity_table  => $activity_table,
                    archive_exists  => $archive_exists,
                    archive_subject => $archive_subject,
                    mid             => $mid,
                }
            );
        }

        my $scrn = DADA::Template::Widgets::screen(
            {
                -screen                   => 'membership_activity_screen.tmpl',
                -vars                     => { activity_tables => $activity_tables, },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        my $at_email = $email;
        $at_email =~ s/\@/_at_/;

        require DADA::Logging::Clickthrough;
        my $rd = DADA::Logging::Clickthrough->new( { -list => $list } );

        require Text::CSV;
        my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

        my $fh = \*STDOUT;

        my $headers = {
            -attachment => 'membership_activity-' . $at_email . '-' . $list . '-' . time . '.csv',
            -type       => 'text/csv',
        };
        my $body;

        #		timestamp
        #		time
        #		event_label

        my @cols = qw(
          ctime
          mid
          email
          ip
          event
          url
        );

        my $status = $csv->combine(@cols);
        $body .= $csv->string() . "\n";

        my ( $total, $mids ) = $rd->get_all_mids;
        foreach my $mid (@$mids) {

            my $report = $rd->message_individual_email_activity_report(
                {
                    -mid   => $mid,
                    -email => $email,
                }
            );

            for my $line (@$report) {
                my @lines = ();
                foreach (@cols) {
                    if ( $_ eq 'email' ) {
                        push( @lines, $email );
                    }
                    elsif ( $_ eq 'mid' ) {
                        push( @lines, $mid );
                    }
                    else {
                        push( @lines, $line->{$_} );
                    }
                }
                my $status = $csv->combine(@lines);
                $body .= $csv->string() . "\n";
            }
        }
        $self->header_props(%$headers);
        return $body;
    }
}

sub admin_change_profile_password {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list             = $admin_list;
    my $profile_password = xss_filter( scalar $q->param('profile_password') );
    my $email            = xss_filter( scalar $q->param('email') );
    my $type             = xss_filter( scalar $q->param('type') );

    require DADA::Profile;
    my $prof = DADA::Profile->new( { -email => $email } );

    if ( $prof->exists ) {

        $prof->update( { -password => $profile_password, } );

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
    foreach my $p_list ( @{ $prof->subscribed_to } ) {
        my $htp = DADA::Profile::Htpasswd->new( { -list => $p_list } );
        for my $id ( @{ $htp->get_all_ids } ) {
            $htp->setup_directory( { -id => $id } );
        }
    }
    #

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
          . '?flavor=membership&email='
          . uriescape($email)
          . '&type='
          . $type
          . '&done=1' );

}

sub admin_profile_delivery_preferences {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'membership'
    );
    if ( !$checksout ) { return $error_msg; }

    my $email          = xss_filter( scalar $q->param('email') );
    my $list           = xss_filter( scalar $q->param('list') );
    my $delivery_prefs = xss_filter( scalar $q->param('delivery_prefs') );
    my $type           = xss_filter( scalar $q->param('type') );

    require DADA::Profile::Settings;
    my $dps = DADA::Profile::Settings->new;
    my $r   = $dps->save(
        {
            -email   => $email,
            -list    => $list,
            -setting => 'delivery_prefs',
            -value   => $delivery_prefs,
        }
    );

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
          . '?flavor=membership&email='
          . uriescape($email)
          . '&type='
          . $type
          . '&done=1' );

}

sub add {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list   = $admin_list;
    my $chrome = $q->param('chrome');
    if ( $chrome ne '0' ) { $chrome = 1; }

    my $type           = $q->param('type')           || 'list';
    my $return_to      = $q->param('return_to')      || '';
    my $return_address = $q->param('return_address') || '';

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ( $q->param('process') ) {

        if ( $q->param('method') eq 'via_add_one' ) {

            # We're going to fake the, "via_textarea", buy just make a CSV file, and plunking it
            # in the, "new_emails" CGI param. (Hehehe);

            my @columns = ();
            push( @columns, xss_filter( scalar $q->param('email') ) );
            for ( @{ $lh->subscriber_fields() } ) {
                push( @columns, xss_filter( scalar $q->param($_) ) );
            }
            if ( $type eq 'list' && $lh->can_have_subscriber_fields ) {
                push( @columns, xss_filter( scalar $q->param('profile_password') ) );
            }

            require Text::CSV;
            my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

            my $status = $csv->combine(@columns);    # combine columns into a string
            my $line   = $csv->string();             # get the combined string

            $q->param( 'new_emails', $line );
            $q->param( 'method',     'via_textarea' );

            # End shienanengans.

        }

        if ( $q->param('method') eq 'via_file_upload' ) {
            if ( strip( scalar $q->param('new_email_file') ) eq '' ) {

                $self->header_type('redirect');
                $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=add' );
            }
        }
        elsif ( $q->param('method') eq 'via_textarea' ) {
            if ( strip( scalar $q->param('new_emails') ) eq '' ) {
                $self->header_type('redirect');
                $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=add' );
            }
        }

        # DEV: This whole building of query string is much too messy.
        my $qs = '&type=' . scalar($q->param('type')) . '&new_email_file=' . uriescape(scalar($q->param('new_email_file')));

        if ( DADA::App::Guts::strip( scalar $q->param('new_emails') ) ne "" ) {

            # DEV: why is it, "new_emails.txt"? Is that supposed to be a variable?
            my $outfile = make_safer( $DADA::Config::TMP . '/' . scalar($q->param('rand_string')) . '-' . 'new_emails.txt' );

            open( OUTFILE, '>:encoding(UTF-8)', $outfile )
              or die "can't write to " . $outfile . ": $!";

            # DEV: TODO encoding?
            print OUTFILE $q->param('new_emails');
            close(OUTFILE);
            chmod( $DADA::Config::FILE_CHMOD, $outfile );

            # DEV: why is it, "new_emails.txt"? Is that supposed to be a variable?
            my $redirect =
                $DADA::Config::S_PROGRAM_URL
              . '?flavor=add_email&fn='
              . scalar($q->param('rand_string')) . '-'
              . 'new_emails.txt'
              . $qs
              . '&return_to='
              . $return_to
              . '&return_address='
              . $return_address
              . '&chrome='
              . $chrome;

            $self->header_type('redirect');
            $self->header_props( -url => $redirect );

        }
        else {

            if ( $q->param('method') eq 'via_file_upload' ) {
                $self->_upload_that_file($q);
            }
            my $filename = $q->param('new_email_file');
            $filename =~ s!^.*(\\|\/)!!;

            $filename = uriescape($filename);

            my $redirect =
              $DADA::Config::S_PROGRAM_URL . '?flavor=add_email&fn=' . scalar($q->param('rand_string')) . '-' . $filename . $qs;

            $self->header_type('redirect');
            $self->header_props( -url => $redirect );

        }
    }
    else {
        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        my $num_subscribers            = $lh->num_subscribers;
        my $subscription_quota_reached = 0;

        if ( $type eq 'list' ) {
            if (   $ls->param('use_subscription_quota') == 1
                && ( $num_subscribers >= $ls->param('subscription_quota') )
                && ( $num_subscribers + $ls->param('subscription_quota') > 1 ) )
            {
                $subscription_quota_reached = 1;
            }
            elsif (defined($DADA::Config::SUBSCRIPTION_QUOTA)
                && $DADA::Config::SUBSCRIPTION_QUOTA > 0
                && $num_subscribers >= $DADA::Config::SUBSCRIPTION_QUOTA )
            {
                $subscription_quota_reached = 1;
            }
        }
		
		require HTML::Menu::Select; 
        my $list_type_switch_widget = HTML::Menu::Select::popup_menu(
			{
				name     => 'type',
	            values => [ keys %{ DADA::App::Guts::list_types() } ],
	            labels   => DADA::App::Guts::list_types(),
	            default  => $type,
	        }
		);

        my $rand_string = generate_rand_string_md5();

        my $fields = [];

        # DEV: This is repeated quite a bit...
        require DADA::ProfileFieldsManager;
        my $pfm         = DADA::ProfileFieldsManager->new;
        my $fields_attr = $pfm->get_all_field_attributes;
        for my $field ( @{ $lh->subscriber_fields() } ) {
            push(
                @$fields,
                {
                    name     => $field,
                    label    => $fields_attr->{$field}->{label},
                    required => $fields_attr->{$field}->{required},
                }
            );
        }

        my $list_is_closed = 0;
        if (   $type eq 'list'
            && $ls->param('closed_list') == 1 )
        {
            $list_is_closed = 1;
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'add_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -vars => {
                    screen                     => 'add',
                    root_login                 => $root_login,
                    subscription_quota_reached => $subscription_quota_reached,
                    num_subscribers            => $num_subscribers,
                    SUBSCRIPTION_QUOTA         => $DADA::Config::SUBSCRIPTION_QUOTA,
                    type                       => $type,
                    type_title                 => $DADA::Config::LIST_TYPES->{$type},
                    flavor                     => 'add',
                    rand_string                => $rand_string,
                    list_subscribers_num       => $lh->num_subscribers( { -type => 'list' } ),
                    black_list_subscribers_num => $lh->num_subscribers( { -type => 'black_list' } ),
                    white_list_subscribers_num => $lh->num_subscribers( { -type => 'white_list' } ),
                    authorized_senders_num     => $lh->num_subscribers( { -type => 'authorized_senders' } ),
                    moderators_num             => $lh->num_subscribers( { -type => 'moderators' } ),
                    bounced_list_num           => $lh->num_subscribers( { -type => 'bounced_list' } ),
                    fields                     => $fields,
                    can_have_subscriber_fields => $lh->can_have_subscriber_fields,
                    list_is_closed             => $list_is_closed,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }

}

sub check_status {

    my $self = shift;
    my $q    = $self->query();

    require JSON;
    my $json = JSON->new->allow_nonref;

    my $filename = $q->param('new_email_file');
    $filename =~ s{^(.*)\/}{};
    $filename = uriescape($filename);

    if ( !-e $DADA::Config::TMP . '/' . $filename . '-meta.txt' ) {
        warn "no meta file at: " . $DADA::Config::TMP . '/' . $filename . '-meta.txt';
        my $json = JSON->new->allow_nonref;
        $self->header_props( -type => 'application/json' );
        return $json->encode( { percent => 0, content_length => 0, bytes_read => 0 } );
    }
    else {

        chmod( $DADA::Config::FILE_CHMOD, make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' ) );

        open my $META, '<', make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' )
          or die $!;

        my $s = do { local $/; <$META> };

        my ( $bytes_read, $content_length, $per ) = split( '-', $s, 3 );
        if ( $per == 99 ) { $per = 100 }
        close($META);

        my $json = JSON->new->allow_nonref;
        $self->header_props( -type => 'application/json' );
        return $json->encode(
            {
                bytes_read     => $bytes_read,
                content_length => $content_length,
                percent        => int($per),
            }
        );
    }
}

sub dump_meta_file {

    my $self = shift;
    my $q    = $self->query();

    my $filename = $q->param('new_email_file');
    $filename =~ s{^(.*)\/}{};
    $filename = uriescape($filename);

    my $full_path_to_filename = make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' );

    if ( !-e $full_path_to_filename ) {

    }
    else {

        my $chmod_check = chmod( $DADA::Config::FILE_CHMOD, $full_path_to_filename );
        if ( $chmod_check != 1 ) {
            warn "could not chmod '$full_path_to_filename' correctly.";
        }

        my $unlink_check = unlink($full_path_to_filename);
        if ( $unlink_check != 1 ) {
            warn "deleting meta file didn't work for: " . $full_path_to_filename;
        }
    }
}

sub _upload_that_file {

    my $self = shift;
    my $q    = $self->query();

    #DEV: move
    my $fh = $q->upload('new_email_file');

    my $filename = $q->param('new_email_file');
    $filename =~ s!^.*(\\|\/)!!;

    $filename = uriescape($filename);

    # warn '$filename ' . $filename;

    # warn '$q->param(\'rand_string\') '    . $q->param('rand_string');
    # warn '$q->param(\'new_email_file\') ' . $q->param('new_email_file');
    return '' if !$filename;

    my $outfile = make_safer( $DADA::Config::TMP . '/' . scalar($q->param('rand_string')) . '-' . $filename );

    # warn ' $outfile ' . $outfile;

    open( OUTFILE, '>', $outfile )
      or die( "can't write to " . $outfile . ": $!" );

    while ( my $bytesread = read( $fh, my $buffer, 1024 ) ) {

        # warn $buffer;

        print OUTFILE $buffer;
    }

    close(OUTFILE);
    chmod( $DADA::Config::FILE_CHMOD, $outfile );

}

sub add_email {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $type    = $q->param('type') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add_email'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $return_to      = $q->param('return_to')      || '';
    my $return_address = $q->param('return_address') || '';
    my $chrome         = $q->param('chrome');
    if ( $chrome ne '0' ) { $chrome = 1; }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    require DADA::ProfileFieldsManager;
    my $pfm        = DADA::ProfileFieldsManager->new;
    my $field_atts = $pfm->get_all_field_attributes;

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

        if ( $ls->param('use_add_list_import_limit') == 1 ) {
            my $num_file_lines = DADA::App::Guts::num_file_lines($new_emails_fn);
            if ( $num_file_lines > $ls->param('add_list_import_limit') ) {
                my $error = 'over_add_list_import_limit';

                my $scrn = DADA::Template::Widgets::wrap_screen(
                    {
                        -screen         => 'add_email_error_screen.tmpl',
                        -with           => 'admin',
                        -wrapper_params => {
                            -Root_Login => $root_login,
                            -List       => $list,
                        },
                        -expr                     => 1,
                        -vars                     => { error => $error },
                        -list_settings_vars_param => {
                            -list   => $list,
                            -dot_it => 1,
                        },
                    }
                );
                return $scrn;
            }
        }
        else {
            # ...
        }
        try {
            ($new_emails) = DADA::App::Guts::csv_subscriber_parse( $admin_list, $new_emails_fn );
        } catch {
            my $error = $_;

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen         => 'add_email_error_screen.tmpl',
                    -with           => 'admin',
                    -wrapper_params => {
                        -Root_Login => $root_login,
                        -List       => $list,
                    },
                    -expr                     => 1,
                    -vars                     => { error => $error },
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                }
            );
            return $scrn;
        };

        my ( $not_members, $invalid_email, $subscribed, $black_listed, $not_white_listed, $invalid_profile_fields ) =
          $lh->filter_subscribers_massaged_for_ht(
            {
                -emails => $new_emails,
                -type   => $type,
            }
          );

        my $num_subscribers = $lh->num_subscribers;

        # and for some reason, this is its own subroutine...
        # This is down here, so the status bar won't disapear before this page is loaded (or the below redirect)
        $self->dump_meta_file();

        # This is to see if we're already over quota:
        my $subscription_quota_reached = 0;
        if ( $type eq 'list' ) {
            if (   $ls->param('use_subscription_quota') == 1
                && ( $num_subscribers >= $ls->param('subscription_quota') )
                && ( $num_subscribers + $ls->param('subscription_quota') > 1 ) )
            {
                $subscription_quota_reached = 1;
            }
            elsif (defined($DADA::Config::SUBSCRIPTION_QUOTA)
                && $DADA::Config::SUBSCRIPTION_QUOTA > 0
                && $num_subscribers >= $DADA::Config::SUBSCRIPTION_QUOTA )
            {
                $subscription_quota_reached = 1;
            }
        }
        if ($subscription_quota_reached) {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=add&type=list' );
            return;
        }

        my $going_over_quota = 0;
        if ( $type eq 'list' ) {
            if ( $ls->param('use_subscription_quota') == 1
                && ( $num_subscribers + scalar(@$not_members) ) > $ls->param('subscription_quota') )
            {
                $going_over_quota = 1;
            }
            elsif (defined($DADA::Config::SUBSCRIPTION_QUOTA)
                && $DADA::Config::SUBSCRIPTION_QUOTA > 0
                && ( $num_subscribers + scalar(@$not_members) ) > $DADA::Config::SUBSCRIPTION_QUOTA )
            {
                $going_over_quota = 1;
            }
        }

        my $addresses_to_add = 0;
        if ( exists($not_members->[0]) ) {
            $addresses_to_add = 1;
        }

        my $field_names = [];

        # if($type eq 'list') {
        for (@$subscriber_fields) {
            push(
                @$field_names,

                {
                    name  => $_,
                    label => $field_atts->{$_}->{label},
                }
            );
        }

        #    }

        if (   $type eq 'list'
            && $ls->param('closed_list') == 1 )
        {
            die "Your list is currently CLOSED to subscribers.";
        }

        # If we're using the black list, but
        # the list owner is allowed to subscribed blacklisted addresses,
        # we have to communicate that to the template:
        if (   $ls->param('black_list') == 1
            && $ls->param('allow_admin_to_subscribe_blacklisted') == 1 )
        {
            for (@$black_listed) {
                $_->{'list_settings.allow_admin_to_subscribe_blacklisted'} = 1;
            }
        }

        my $show_invitation_button = 0;
        my $show_update_button     = 0;
        my $show_add_button        = 0;

        if ( $type eq 'list' ) {
            if ( scalar(@$not_members) > 0 ) {
                $show_invitation_button = 1;
            }
            elsif ( scalar(@$black_listed) > 0
                && $ls->param('allow_admin_to_subscribe_blacklisted') == 1 )
            {
                $show_invitation_button = 1;
            }
            elsif ( scalar($invalid_profile_fields) > 0
                && ( $root_login == 1 || $ls->param('allow_profile_editing') == 1 ) )
            {
                $show_invitation_button = 1;
            }

            if (   scalar( @$not_members < 1 )
                && ( scalar(@$black_listed) < 1 && $ls->param('allow_admin_to_subscribe_blacklisted') == 1 )
                && scalar(@$subscribed) > 1
                && ( $root_login == 1 || $ls->param('allow_profile_editing') == 1 ) )
            {
                $show_update_button = 1;
            }
            else {
                $show_add_button = 1;
            }
        }

        my %vars = (

            show_invitation_button => $show_invitation_button,
            show_update_button     => $show_update_button,
            show_add_button        => $show_add_button,

            can_have_subscriber_fields => $lh->can_have_subscriber_fields,
            going_over_quota           => $going_over_quota,
            field_names                => $field_names,
            subscribed                 => $subscribed,
            not_members                => $not_members,
            black_listed               => $black_listed,
            not_white_listed           => $not_white_listed,
            invalid_email              => $invalid_email,
            invalid_profile_fields     => $invalid_profile_fields,
            type                       => $type,
            type_title                 => $DADA::Config::LIST_TYPES->{$type},
            root_login                 => $root_login,
            return_to                  => $return_to,
            return_address             => $return_address,
            chrome                     => $chrome,
        );

        my $scrn;
        if ( $chrome == 1 ) {
            $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen         => 'add_email_screen.tmpl',
                    -with           => 'admin',
                    -wrapper_params => {
                        -Root_Login => $root_login,
                        -List       => $list,
                    },
                    -expr                     => 1,
                    -vars                     => { %vars, },
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                }
            );
        }
        else {
            $scrn = DADA::Template::Widgets::screen(
                {
                    -screen                   => 'add_email_screen.tmpl',
                    -expr                     => 1,
                    -vars                     => { %vars, },
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                }
            );
        }
        return $scrn;
    }
    else {

        my $update_email_count = 0;

        if ( $type eq 'list' ) {
            if ( $process =~ m/subscribe|invit|update/i ) {

                # This is what updates already existing profile fields and profile passwords;
                #
                my @update_fields_address = $q->multi_param("update_fields_address");

                # This is a lot of code, to set one thing:
                my $subscribed_fields_options_mode =
                  $q->param('subscribed_fields_options_mode') || 'writeover_inc_password';
                my $spass_om = 'writeover';
                if ( $subscribed_fields_options_mode eq 'writeover_ex_password' ) {
                    $spass_om = 'preserve_if_defined';
                }

                #/

                my $update_email_count = 0;

                # Change from csv to a complex data structure.
                my @munged_update_addresses = ();
                for my $ua (@update_fields_address) {
                    push( @munged_update_addresses, $lh->csv_to_cds($ua) );
                }

                require DADA::Profiles;
                my $dp                 = DADA::Profiles->new;
                my $update_email_count = $dp->update(
                    {
                        -addresses       => [@munged_update_addresses],
                        -password_policy => $spass_om,
                    }
                );
            }
        }

        if ( $process =~ /invit/i ) {
            $self->list_invite();
        }
        else {

            if ( $type eq 'list' ) {
                unless ( $ls->param('enable_mass_subscribe') == 1
                    && ( $root_login == 1 || $ls->param('enable_mass_subscribe_only_w_root_login') != 1 ) )
                {
                    die "Mass Subscribing via the List Control Panel has been disabled.";
                }
            }

            my @address = $q->multi_param("address");

            my @munged_add_addresses = ();
            for my $a (@address) {
                push( @munged_add_addresses, $lh->csv_to_cds($a) );
            }
            undef(@address);

            my $not_members_fields_options_mode = $q->param('not_members_fields_options_mode');

            my ( $new_email_count, $skipped_email_count ) = $lh->add_subscribers(
                {
                    -addresses           => [@munged_add_addresses],
                    -fields_options_mode => $not_members_fields_options_mode,
                    -type                => $type,
                }
            );

            my $flavor_to_return_to = 'view_list';
            if ( $return_to eq 'membership' ) {    # or, others...
                $flavor_to_return_to = $return_to;
            }

            my $qs =
                'flavor='
              . $flavor_to_return_to
              . '&add_email_count='
              . $new_email_count
              . '&skipped_email_count='
              . $skipped_email_count
              . '&update_email_count='
              . $update_email_count
              . '&type='
              . $type;

            if ( $return_to eq 'membership' ) {
                $qs .= '&email=' . $return_address;
            }

            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );

        }
    }
}

sub delete_email {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process');

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'delete_email',
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $type = $q->param('type') || 'list';

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ( !$process ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'delete_email_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -vars => {
                    screen                     => 'delete_email',
                    title                      => 'Remove',
                    can_use_global_black_list  => $lh->can_use_global_black_list,
                    can_use_global_unsubscribe => $lh->can_use_global_unsubscribe,
                    list_type_isa_list         => ( $type eq 'list' ) ? 1 : 0,
                    list_type_isa_black_list => ( $type eq 'black_list' ) ? 1
                    : 0,
                    list_type_isa_authorized_senders => ( $type eq 'authorized_senders' ) ? 1 : 0,
                    list_type_isa_moderators         => ( $type eq 'moderators' )         ? 1 : 0,
                    list_type_isa_white_list         => ( $type eq 'white_list' )         ? 1
                    : 0,
                    type                       => $type,
                    type_title                 => $DADA::Config::LIST_TYPES->{$type},
                    flavor                     => 'delete_email',
                    list_subscribers_num       => $lh->num_subscribers( { -type => 'list' } ),
                    black_list_subscribers_num => $lh->num_subscribers( { -type => 'black_list' } ),
                    white_list_subscribers_num => $lh->num_subscribers( { -type => 'white_list' } ),
                    authorized_senders_num     => $lh->num_subscribers( { -type => 'authorized_senders' } ),
                    moderators_num             => $lh->num_subscribers( { -type => 'moderators' } ),
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;

    }
    else {

        my $delete_list       = undef;
        my $delete_email_file = $q->param('delete_email_file');
        if ($delete_email_file) {
            my $new_file = $self->file_upload('delete_email_file');
            open( UPLOADED, "$new_file" )
              or die $!;
            $delete_list = do { local $/; <UPLOADED> };
            close(UPLOADED);
        }
        else {
            $delete_list = $q->param('delete_list');
        }

        my $outfile_filename = generate_rand_string_md5() . '-' . 'remove_emails.txt';
        my $outfile          = make_safer( $DADA::Config::TMP . '/' . $outfile_filename );

        #DEV: encoding?
        open( my $fh, '>' . $outfile )
          or die( "can't write to " . $outfile . ": $!" );
        print $fh $delete_list;
        close($fh);
        chmod( $DADA::Config::FILE_CHMOD, $outfile );

        my $new_emails = [];
        my $new_info   = [];
        ( $new_emails, $new_info ) = DADA::App::Guts::csv_subscriber_parse( $admin_list, $outfile_filename );

        my ( $not_members, $invalid_email, $subscribed, $black_listed, $not_white_listed, $invalid_profile_fields ) =
          $lh->filter_subscribers_massaged_for_ht(
            {
                -emails => $new_emails,
                -type   => $type,
                -treat_profile_fields_special => 0, 
                
            }
          );

#        use Data::Dumper; 
#        warn Dumper({
#             not_members => $not_members, 
#             invalid_email => $invalid_email, 
#             subscribed => $subscribed, 
#             black_listed => $black_listed, 
#             not_white_listed => $not_white_listed, 
#             invalid_profile_fields => $invalid_profile_fields,
#        }); 
        
        my $have_subscribed_addresses = 0;
        $have_subscribed_addresses = 1
          if $subscribed->[0];

        my $addresses_to_remove = [];
        push( @$addresses_to_remove, { email => $_->{email} } ) for @$subscribed;

        my $not_subscribed_addresses = [];
        push( @$not_subscribed_addresses, { email => $_->{email} } ) for @$not_members;

        my $have_invalid_addresses = 0;
        $have_invalid_addresses = 1
          if $invalid_email->[0];

        my $invalid_addresses = [];
        push( @$invalid_addresses, { email => $_->{email} } ) for @$invalid_email;

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'delete_email_screen_filtered.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -vars => {
                    have_subscribed_addresses => $have_subscribed_addresses,
                    addresses_to_remove       => $addresses_to_remove,
                    not_subscribed_addresses  => $not_subscribed_addresses,
                    have_invalid_addresses    => $have_invalid_addresses,
                    invalid_addresses         => $invalid_addresses,

                    type       => $type,
                    type_title => $DADA::Config::LIST_TYPES->{$type},

                },
            }
        );

        return $scrn;
    }
}

sub subscription_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'subscription_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

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
    unshift( @quota_values, $ls->param('subscription_quota') );

    if ( !$process ) {

        require DADA::ProfileFieldsManager;
        my $dpfm = DADA::ProfileFieldsManager->new;
        require DADA::Profile::Fields;
        my $dpf = DADA::Profile::Fields->new;

        my $view_list_order_by_menu           = '';
        my $view_list_order_by_direction_menu = '';
		require HTML::Menu::Select; 

        if ( $dpf->can_have_subscriber_fields ) {

            my $field_atts      = $dpfm->get_all_field_attributes;
            my $pf_field_labels = {};
            for ( keys %{$field_atts} ) {
                $pf_field_labels->{$_} = $field_atts->{$_}->{label};
            }
            my $field_values = $dpfm->fields;
            unshift( @$field_values, 'timestamp' );
            unshift( @$field_values, 'email' );

            $pf_field_labels->{timestamp} = 'Subscription Date';
            $pf_field_labels->{email}     = 'Email Address';

            $view_list_order_by_menu = HTML::Menu::Select::popup_menu(
				{
	                name     => 'view_list_order_by',
	                id       => 'view_list_order_by',
	                values => $field_values,
	                labels   => $pf_field_labels,
	                default  => $ls->param('view_list_order_by'),
				}
			);
            $view_list_order_by_direction_menu = HTML::Menu::Select::popup_menu(
				{
	                name     => 'view_list_order_by_direction',
	                id       => 'view_list_order_by_direction',
	                values => [ 'ASC', 'DESC' ],
	                labels   => { ASC => 'Ascending', DESC => 'Descending' },
	                default  => $ls->param('view_list_order_by_direction'),
	            }
			);
        }
        my $subscription_quota_menu = HTML::Menu::Select::popup_menu(
			{
				name     => 'subscription_quota',
	            id       => 'subscription_quota',
	            values => [@quota_values],
	            default  => $ls->param('subscription_quota'),
			}
        );

        my @list_amount = (
            3,    5,    10,   25,   50,    100,   150,   200,   250,   300, 350, 400,
            450,  500,  550,  600,  650,   700,   750,   800,   850,   900, 950, 1000,
            2000, 3000, 4000, 5000, 10000, 15000, 20000, 25000, 50000, 100000
        );
		require HTML::Menu::Select; 
        my $vlsn_menu = HTML::Menu::Select::popup_menu(
            {
				name    => 'view_list_subscriber_number',
	            values  => [@list_amount],
	            default => $ls->param('view_list_subscriber_number'),
			}
        );

        my $add_list_import_limit_menu = HTML::Menu::Select::popup_menu(
            {
				name    => 'add_list_import_limit',
            	values  => [qw(100 200 300 400 500 600 750 1000 1500 2000 2500 3000 5000 7500 10000)],
            	default => $ls->param('add_list_import_limit'),
        	}
		);

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'subscription_options_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -vars => {
                    screen                            => 'subscription_options',
                    title                             => 'Subscriber Options',
                    done                              => $done,
                    subscription_quota_menu           => $subscription_quota_menu,
                    can_have_subscriber_fields        => $dpf->can_have_subscriber_fields,
                    vlsn_menu                         => $vlsn_menu,
                    view_list_order_by_menu           => $view_list_order_by_menu,
                    view_list_order_by_direction_menu => $view_list_order_by_direction_menu,
                    add_list_import_limit_menu        => $add_list_import_limit_menu,
                    SUBSCRIPTION_QUOTA                => $DADA::Config::SUBSCRIPTION_QUOTA,
                    commified_subscription_quota      => commify( int($DADA::Config::SUBSCRIPTION_QUOTA) ),
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    view_list_subscriber_number          => undef,
                    view_list_show_timestamp_col         => 0,
                    view_list_order_by                   => undef,
                    view_list_order_by_direction         => undef,
                    use_add_list_import_limit            => 0,
                    add_list_import_limit                => undef,
                    allow_profile_editing                => 0,
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

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=subscription_options&done=1' );
    }

}

sub view_archive {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_archive'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $admin_list } );

    # let's get some info on this archive, shall we?
    require DADA::MailingList::Archives;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    my $entries = $archive->get_archive_entries();

    #if we don't have nothin, print the index,

    my $id = $q->param('id') || undef;

    unless ( defined($id) ) {

        my $start = int( $q->param('start') ) || 0;

        if (  !$c->profile_on
            && $c->is_cached( $list . '.admin.view_archive.index.' . $start . '.scrn' ) )
        {
            return $c->cached( $list . '.admin.view_archive.index.' . $start . '.scrn' );
        }

        my $ht_entries = [];

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
            my ( $subject, $message, $format, $raw_msg ) = $archive->get_archive_info($entry);

            my $pretty_subject = pretty($subject);

            my $header_from = undef;
            if ($raw_msg) {
                $header_from = $archive->get_header( -header => 'From', -key => $entry );

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

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'view_archive_index_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -list => $list,
                -vars => {
					can_use_JSON => scalar DADA::App::Guts::can_use_JSON(), 
                    screen       => 'view_archive',
                    title        => 'View Archive',
                    index_list   => $ht_entries,
                    list_name    => $ls->param('list_name'),
                    index_nav    => $index_nav,

                },
            }
        );

        if ( !$c->profile_on ) {    # that's it?
            $c->cache( $list . '.admin.view_archive.index.' . $start . '.scrn', \$scrn );
        }
        return $scrn;
    }
    else {

        #check to see if $id is a real id key
        my $entry_exists = $archive->check_if_entry_exists($id);

        if ( $entry_exists <= 0 ) {
            return user_error( { -list => $list, -error => "no_archive_entry" } );
        }

        my $scrn = '';

        my ( $subject, $message, $format ) = $archive->get_archive_info($id);

        my $cal_date = date_this(
            -Packed_Date => $archive->_massaged_key($id),
            -All         => 1
        );

        my $nav_table = $archive->make_nav_table(
            -Id       => $id,
            -List     => $ls->param('list'),
            -Function => "admin"
        );

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'view_archive_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -vars => {
                    id                         => $id,
                    subject                    => $subject,
                    date                       => $cal_date,
                    can_display_message_source => $archive->can_display_message_source,
                    nav_table                  => $nav_table,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
}

sub display_message_source {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'display_message_source'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::MailingList::Archives;

    my $la = DADA::MailingList::Archives->new( { -list => $list } );

    if ( $la->check_if_entry_exists( $q->param('id') ) ) {

        if ( $la->can_display_message_source ) {

            $self->header_props( { -type => 'text/plain' } );
            return $la->message_source( $q->param('id') );

        }
        else {

            return user_error(
                {
                    -list  => $list,
                    -error => "no_support_for_displaying_message_source"
                }
            );
        }

    }
    else {
        return user_error( { -list => $list, -error => "no_archive_entry" } );
    }

}

sub delete_archive {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'delete_archive'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list    = $admin_list;
    my @address = $q->multi_param("address");

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::MailingList::Archives;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    $archive->delete_archive(@address);

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive' );

}

sub purge_all_archives {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'purge_all_archives'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::MailingList::Archives;
    my $ah = DADA::MailingList::Archives->new( { -list => $list } );

    $ah->delete_all_archive_entries();

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive' );

}

sub archive_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'archive_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {

        my $can_use_captcha = can_use_AuthenCAPTCHA();

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'archive_options_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -expr => 1,
                -vars => {
                    screen          => 'archive_options',
                    title           => 'Archive Options',
                    list            => $list,
                    done            => $done,
                    can_use_captcha => $can_use_captcha,
                    CAPTCHA_TYPE    => $DADA::Config::CAPTCHA_TYPE,

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },

            }
        );
        return $scrn;
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
        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=archive_options&done=1' );
    }
}

sub adv_archive_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'adv_archive_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::MailingList::Archives;
    my $la = DADA::MailingList::Archives->new( { -list => $list } );

    if ( !$process ) {

        my @index_this = ( $ls->param('archive_index_count'), 1 .. 10, 15, 20, 25, 30, 40, 50, 75, 100 );
		
		require HTML::Menu::Select; 
        my $archive_index_count_menu = HTML::Menu::Select::popup_menu(
            {
				name  => 'archive_index_count',
            	id    => 'archive_index_count',
				value => [@index_this],
    		}
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
        try {
            require HTML::Scrubber;
        } catch {
            carp "HTML::Scrubber not working correctly?: $_";
            $can_use_html_scrubber = 0;
        };

        my $can_use_recaptcha_mailhide = 1;
        try {
            require Captcha::reCAPTCHA::Mailhide;
        } catch {
            carp "reCAPTCHA Mailhide not working correctly?: $_";
            $can_use_recaptcha_mailhide = 0;
        } finally {
            if (   !defined( $DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{public_key} )
                || !defined( $DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{private_key} )
                || $DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{public_key} eq ''
                || $DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{private_key} eq '' )
            {
                $can_use_recaptcha_mailhide = 0;
            }
        };

        my $gravatar_img_url     = '';
        my $can_use_gravatar_url = 1;
        try {
            require Gravatar::URL;
        } catch {
            $can_use_gravatar_url = 0;
        };

        if ( $can_use_gravatar_url == 1 ) {
            $gravatar_img_url = gravatar_img_url(
                {
                    -email                => $ls->param('list_owner_email'),
                    -default_gravatar_url => $ls->param('default_gravatar_url'),
                }
            );
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'adv_archive_options_screen.tmpl',
                -with           => 'admin',
				-expr           => 1, 
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    screen => 'adv_archive_options',
                    title  => 'Advanced Options',

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
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
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

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=adv_archive_options&done=1' );
    }
}

sub edit_archived_msg {

    my $self = shift;
    my $q    = $self->query();

    require DADA::Template::HTML;
    require DADA::MailingList::Settings;

    require DADA::MailingList::Archives;

    require DADA::Mail::Send;

    require MIME::Parser;

    my $parser = new MIME::Parser;
    $parser = optimize_mime_parser($parser);

    my $skel = [];

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_archived_msg'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    my $ls   = DADA::MailingList::Settings->new( { -list => $list } );
    my $mh   = DADA::Mail::Send->new(
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
            return prefs();
        }
        else {

            if ( $q->param('process') ) {
                return edit_archive();
            }
            else {
                return view();
            }
        }
    }

    sub view {

		require HTML::Menu::Select; 
        my $D_Content_Types = [ 'text/plain', 'text/html' ];

        my %Headers_To_Edit;

        my $parser = new MIME::Parser;
        $parser = optimize_mime_parser($parser);

        my $id = $q->param('id');

        if ( !$id ) {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive' );
        }

        if ( $ah->check_if_entry_exists($id) <= 0 ) {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive' );
        }

        my ( $subject, $message, $format, $raw_msg ) = $ah->get_archive_info($id);

        # do I need this?
        $raw_msg ||= $ah->_bs_raw_msg( $subject, $message, $format );
        $raw_msg =~ s/Content\-Type/Content-type/;
        $raw_msg = safely_encode($raw_msg);

        my $entity;
        eval { $entity = $parser->parse_data($raw_msg); };

        my $form_blob = '';
        make_skeleton($entity);

        for ( split( ',', $ls->param('editable_headers') ) ) {
            $Headers_To_Edit{$_} = 1;
        }

        for my $tb (@$skel) {

            my @c = split( '-', $tb->{address} );
            my $bqc = $#c - 1;

            for ( 0 .. $bqc ) {
                $form_blob .= '<div style="padding-left: 30px; border-left:1px solid #ccc">';
            }

            if ( $tb->{address} eq '0' ) {
                $form_blob .= '<table  width="100%">';

                # head of the message!
                my %headers = $mh->return_headers( $tb->{entity}->head->original_text );
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
                                    HTML::Menu::Select::popup_menu(
                                        {
											values => $D_Content_Types,
                                        	id       => $h,
                                        	name     => $h,
                                        	default  => $headers{$h}
                                    	}
									)
                                );
                            }
                            else {
                                my $value = $headers{$h};
                                if ( $ls->param('mime_encode_words_in_headers') == 1 ) {
                                    if ( $h =~ m/To|From|Cc|Reply\-To|Subject/ ) {
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

            $form_blob .= $q->p( $q->strong('Content Type: '), $tb->{entity}->head->mime_type );

            if ( $tb->{body} ) {

                if (   $type =~ /^(text|message)$/
                    && $tb->{entity}->head->get('content-disposition') !~ m/attach/i )
                {    # text: display it...

                    # Needs to be WYSIWYG Editor-ized
                    $form_blob .= $q->p(
                        $q->textarea(
                            -value => safely_decode( $tb->{entity}->bodyhandle->as_string ),
                            -rows  => 15,
                            -name  => $tb->{address}
                        )
                    );

                }
                else {

                    $form_blob .= '<div style="border: 1px solid #000;padding: 5px">';

                    my $name = $tb->{entity}->head->mime_attr("content-type.name")
                      || $tb->{entity}->head->mime_attr("content-disposition.filename");

                    my $attachment_url;

                    if ($name) {
                        $attachment_url =
                            $DADA::Config::S_PROGRAM_URL
                          . '?flavor=file_attachment&list='
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
                          . '?flavor=show_img&list='
                          . $list . '&id='
                          . $id . '&cid='
                          . $m_cid;

                    }

                    $form_blob .= $q->p( $q->strong('Attachment: '),
                        $q->a( { -href => $attachment_url, -target => '_blank' }, $name ) );

                    $form_blob .= '<table  style="padding:5px">';

                    $form_blob .= '<tr><td>';

                    if ( $type =~ /^image/ && $subtype =~ m/gif|jpg|jpeg|png/ ) {
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
                        $q->label( { '-for' => 'delete_' . $tb->{address} }, 'Remove From Message' )
                    );
                    $form_blob .= $q->p( $q->strong('Update:'), $q->filefield( -name => 'upload_' . $tb->{address} ) );

                    $form_blob .= '</td></tr></table>';

                    $form_blob .= '</div>';

                }
            }

            for ( 0 .. $bqc ) {
                $form_blob .= '</div>';
            }
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'edit_archived_msg.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -vars => {
                    subject                                              => $subject,
                    big_blob_of_form_widgets_to_edit_an_archived_message => $form_blob,
                    can_display_message_source                           => $ah->can_display_message_source,
                    id                                                   => $id,
                    done                                                 => scalar $q->param('done'),

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,

                },
            }
        );
        return $scrn;
    }

    sub prefs {

        if ( $q->param('process_prefs') ) {

            my $the_id = $q->param('id');

            my $editable_headers = join( ',', $q->param('editable_header') );
            $ls->save( { editable_headers => $editable_headers } );

            $self->header_type('redirect');
            $self->header_props(
                -url => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_archived_msg&process=prefs&done=1&id=' . $the_id );

        }
        else {

            my %editable_headers;
            $editable_headers{$_} = 1 for ( split( ',', $ls->param('editable_headers') ) );

            my $edit_headers_menu = [];
            for (@DADA::Config::EMAIL_HEADERS_ORDER) {

                push( @$edit_headers_menu, { name => $_, editable => $editable_headers{$_} } );
            }

            my $the_id = $q->param('id');
            my $done   = $q->param('done');

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen         => 'edit_archived_msg_prefs_screen.tmpl',
                    -with           => 'admin',
                    -wrapper_params => {
                        -Root_Login => $root_login,
                        -List       => $list,
                    },
                    -vars => {
                        edit_headers_menu => $edit_headers_menu,
                        done              => $done,
                        id                => $the_id,
                    },
                }
            );
            return $scrn;
        }

    }

    sub edit_archive {

        my $id = $q->param('id');

        my $parser = new MIME::Parser;
        $parser = optimize_mime_parser($parser);

        my ( $subject, $message, $format, $raw_msg ) = $ah->get_archive_info($id);

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
                $id, $entity->head->get( 'Subject', 0 ),
                undef,
                $entity->head->get( 'Content-type', 0 ),
                safely_decode( $entity->as_string )
            );
        }
        else {

            $ah->set_archive_info( $id, $entity->head->get( 'Subject', 0 ),
                undef, undef, safely_decode( $entity->as_string ) );
        }

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_archived_msg&id=' . $id . '&done=1' );

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
        else {                           # single part...
            push( @$skel, { address => $name, entity => $entity, body => 1 } );

        }
    }

    sub edit {

        my ( $entity, $name ) = @_;
        defined($name) or $name = "0";
        my $IO;

        my %Headers_To_Edit;

        if ( $name eq '0' ) {

            for ( split( ',', $ls->param('editable_headers') ) ) {
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
                ( $parts[$i], $name_is ) = edit( $parts[$i], ( "$name\-" . ($i) ) );

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
                else {
                    my $body = $entity->bodyhandle;
                    my $io   = $body->open('w');
                    $io->print('!!!DELETE PART!!!');
                    $io->close;

                    # This is what should do the actual deleting.
                    $q->param( 'delete_' . $name, 1 );
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

        my $filename = $self->file_upload( 'upload_' . $name );
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

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'html_code'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $jquery_head_code = DADA::Template::Widgets::screen(
        {
            -screen                   => 'jquery_subscription_form_head.tmpl',
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    my $jquery_body_code = DADA::Template::Widgets::screen(
        {
            -screen => 'jquery_subscription_form_body.tmpl',
            -vars   => {
                subscription_form => DADA::Template::Widgets::subscription_form(
                    {
                        -list                 => $list,
                        -ignore_cgi           => 1,
                        -show_fieldset        => 0,
                        -subscription_form_id => 'dada_mail_modal_subscription_form'
                    }
                )
            }
        }
    );

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'html_code_screen.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {
                screen            => 'html_code',
                list              => $list,
                jquery_head_code  => $jquery_head_code,
                jquery_body_code  => $jquery_body_code,
                subscription_form => DADA::Template::Widgets::subscription_form(
                    { -list => $list, -ignore_cgi => 1, -show_fieldset => 0 }
                ),
                minimal_subscription_form => DADA::Template::Widgets::subscription_form(
                    { 
						-list          => $list, 
						-form_type     => 'minimal', 
						-ignore_cgi    => 1, 
						-show_fieldset => 0 
					}
                ),
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;

}

sub preview_jquery_plugin_subscription_form {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'html_code'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    my $jquery_subscription_form_body = DADA::Template::Widgets::screen(
        {
            -screen => 'jquery_subscription_form_body.tmpl',
            -vars   => {
                subscription_form => DADA::Template::Widgets::subscription_form(
                    {
                        -list                 => $list,
                        -ignore_cgi           => 1,
                        -show_fieldset        => 0,
                        -subscription_form_id => 'dada_mail_modal_subscription_form'
                    }
                )
            }
        }
    );

    my $jquery_subscription_form_head = DADA::Template::Widgets::screen(
        {
            -screen                   => 'jquery_subscription_form_head.tmpl',
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );

    my $scrn = DADA::Template::Widgets::screen(
        {
            -screen => 'preview_jquery_plugin_subscription_form.tmpl',
            -vars   => {
                jquery_subscription_form_head => $jquery_subscription_form_head,
                jquery_subscription_form_body => $jquery_subscription_form_body,
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    return $scrn;

}

sub edit_template {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('don') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_template'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $raw_template     = DADA::Template::HTML::default_template();
    my $default_template = default_template(
		{
			-Use_Custom => 0
		}
	);

    if ( !$process ) {
        my $content_tag_found_in_template         = 0;
        my $content_tag_found_in_url_template     = 0;
        my $content_tag_found_in_default_template = 0;

        my $content_tag = quotemeta('<!-- tmpl_var content -->');

		if (   
	        $DADA::Config::TEMPLATE_OPTIONS->{user}->{enabled} == 1 
	        && $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode} eq 'magic' 
     	) {
	        if ( $raw_template =~ m/$content_tag/ ) {
	            $content_tag_found_in_default_template = 1;
	        }
			else { 
		        my $list_template_body_code_block = DADA::Template::Widgets::_raw_screen(
		            { 
						-screen => 'list_template_body_code_block.tmpl' 
					} 
				);
		        if ( $list_template_body_code_block =~ m/$content_tag/ ) {
		            $content_tag_found_in_default_template = 1;
		        }
			}	
		}
		else {
	        if ( $raw_template =~ m/$content_tag/ ) {
	            $content_tag_found_in_default_template = 1;
	        }
		}
		# .tmpl
		
        my $edit_this_template = $default_template . "\n";
        if ( check_if_template_exists( -List => $list ) >= 1 ) {
            $edit_this_template = open_template( -List => $list ) . "\n";
        }
        if ( $edit_this_template =~ m/$content_tag/ ) {
            $content_tag_found_in_template = 1;
        }

        my $get_template_data_from_default_template = 0;
        $get_template_data_from_default_template = 1
          if $ls->param('get_template_data') eq 'from_default_template';

        my $get_template_data_from_template_file = 0;
        $get_template_data_from_template_file = 1
          if $ls->param('get_template_data') eq 'from_template_file';

        my $get_template_data_from_url = 0;
        $get_template_data_from_url = 1
          if $ls->param('get_template_data') eq 'from_url';

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
                eval { $LWP::Simple::ua->agent( 'Mozilla/5.0 (compatible; ' . $DADA::CONFIG::PROGRAM_NAME . ')' ); };
                if ( LWP::Simple::get( $ls->param('url_template') ) ) {
                    my $tmp_tmpl = LWP::Simple::get( $ls->param('url_template') );
                    if ( $tmp_tmpl =~ m/$content_tag/ ) {
                        $content_tag_found_in_url_template = 1;
                    }
                }
                else {

                    $template_url_check = 0;

                }
            }
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'edit_template_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
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

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;

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
                    eval { $LWP::Simple::ua->agent( 'Mozilla/5.0 (compatible; ' . $DADA::CONFIG::PROGRAM_NAME
                              . ')' ); };
                    $template_info = LWP::Simple::get( $q->param('url_template') );
                }
            }
            else {
                $template_info = $q->param("template_info");
            }

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen                   => 'preview_template.tmpl',
                    -with                     => 'list',
                    -wrapper_params           => { -data => \$template_info, },
                    -vars                     => { title => 'Preview', },
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                }
            );
            return $scrn;
        }
        else {

            my $template_info = $q->param("template_info");

            $ls->save_w_params(
                {
                    -associate => $q,
                    -settings  => {
                        url_template      => '',
                        get_template_data => '',
                    }
                }
            );

            make_template( { -List => $list, -Template => $template_info } );

            $c->flush;

            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_template&done=1' );

        }
    }
}

sub back_link {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'back_link'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'back_link_screen.tmpl',
                -list           => $list,
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    screen => 'back_link',
                    done   => ( ( $q->param('done') ) ? ( $q->param('done') ) : (0) ),
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    website_name => '',
                    website_url  => '',
                }
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=back_link&done=1' );

    }
}

sub edit_type {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_type'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::App::FormatMessages;
    my $dfm = DADA::App::FormatMessages->new( -List => $list );

    if ( !$process ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'edit_type_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -list => $list,
                -vars => {
                    screen => 'edit_type',
                    title  => 'Email Templates',
                    done   => $done,

                    unsub_link_found_in_pt_mlm =>
                      $dfm->can_find_unsub_link( { -str => $ls->param('mailing_list_message') } ),
                    unsub_link_found_in_html_mlm =>
                      $dfm->can_find_unsub_link( { -str => $ls->param('mailing_list_message_html') } ),
                    message_body_tag_found_in_pt_mlm =>
                      $dfm->can_find_message_body_tag( { -str => $ls->param('mailing_list_message') } ),
                    message_body_tag_found_in_html_mlm =>
                      $dfm->can_find_message_body_tag( { -str => $ls->param('mailing_list_message_html') } ),
                    sub_confirm_link_found_in_confirmation_message =>
                      $dfm->can_find_sub_confirm_link( { -str => $ls->param('confirmation_message') } ),
                    unsub_link_found_in_pt_subscribed_by_list_owner_msg =>
                      $dfm->can_find_unsub_link( { -str => $ls->param('subscribed_by_list_owner_message') } ),
                    sub_confirm_link_found_in_pt_invite_msg =>
                      $dfm->can_find_sub_confirm_link( { -str => $ls->param('invite_message_text') } ),
                    sub_confirm_link_found_in_html_invite_msg =>
                      $dfm->can_find_sub_confirm_link( { -str => $ls->param('invite_message_html') } ),
                },
                -list_settings_vars       => $ls->get( -all_settings => 1 ),
                -list_settings_vars_param => { -dot_it               => 1, },
            }
        );
        return $scrn;

    }
    else {

        for (
            qw(
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

            admin_subscription_notice_message
            admin_subscription_notice_message_subject

            unsubscription_notice_message
            unsubscription_notice_message_subject
            
            admin_unsubscription_notice_message
            admin_unsubscription_notice_message_subject
            
            

            )
          )
        {

            # a very odd place to put this, but, hey,  easy enough.
            if ( $q->param('revert') ) {
                $q->delete($_);
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
                    confirmation_message_subject                => undef,
                    confirmation_message                        => undef,
                    subscribed_message_subject                  => undef,
                    subscribed_message                          => undef,
                    subscribed_by_list_owner_message_subject    => undef,
                    subscribed_by_list_owner_message            => undef,
                    unsubscribed_by_list_owner_message_subject  => undef,
                    unsubscribed_by_list_owner_message          => undef,
                    unsubscribed_message_subject                => undef,
                    unsubscribed_message                        => undef,
                    mailing_list_message_from_phrase            => undef,
                    mailing_list_message_to_phrase              => undef,
                    mailing_list_message_subject                => undef,
                    mailing_list_message                        => undef,
                    mailing_list_message_html                   => undef,
                    send_archive_message_subject                => undef,
                    send_archive_message                        => undef,
                    send_archive_message_html                   => undef,
                    you_are_already_subscribed_message_subject  => undef,
                    you_are_already_subscribed_message          => undef,
                    you_are_not_subscribed_message_subject      => undef,
                    you_are_not_subscribed_message              => undef,
                    invite_message_from_phrase                  => undef,
                    invite_message_to_phrase                    => undef,
                    invite_message_text                         => undef,
                    invite_message_html                         => undef,
                    invite_message_subject                      => undef,
                    admin_subscription_notice_message           => undef,
                    admin_subscription_notice_message_subject   => undef,
                    
                    unsubscription_notice_message               => undef, 
                    unsubscription_notice_message_subject       => undef, 
                    admin_unsubscription_notice_message         => undef,
                    admin_unsubscription_notice_message_subject => undef,

                    enable_email_template_expr => 0,
                }
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_type&done=1' );

    }
}

sub edit_html_type {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;

    my $done = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'edit_html_type'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {

        #use Data::Dumper;
        #die Dumper($ls->get(-dotted => 1, -all_settings => 1));

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'edit_html_type_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -list => $list,
                -vars => {
                    screen => 'edit_html_type',
                    title  => 'HTML Screen Templates',
                    done   => $done,
                },
                -list_settings_vars       => $ls->get( -all_settings => 1 ),
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },

            }
        );
        return $scrn;

    }
    else {

        for (
            qw(
            html_confirmation_message
            html_subscribed_message
            html_subscription_request_message
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
                -settings  => {
                    html_confirmation_message         => '',
                    html_subscribed_message           => '',
                    html_subscription_request_message => '',
                    html_unsubscribed_message         => '',
                }
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_html_type&done=1' );
    }
}

sub manage_script {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'manage_script'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list               = $admin_list;
    my $more_info          = $q->param('more_info') || 0;
    my $sendmail_locations = `whereis sendmail`;
    my $curl_location      = `which curl`;
    my $wget_location      = `which wget`;

    my $at_incs = [];

    for (@INC) {
        if ( $_ !~ /^\./ ) {
            push( @$at_incs, { name => $_ } );
        }
    }

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'manage_script_screen.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -list => $list,
            -vars => {
                more_info          => $more_info,
                smtp_server        => $ls->param('smtp_server'),
                server_software    => $q->server_software(),
                operating_system   => $^O,
                perl_version       => $],
                sendmail_locations => $sendmail_locations,
                at_incs            => $at_incs,
                list_owner_email   => $ls->param('list_owner_email'),
                curl_location      => $curl_location,
                wget_location      => $wget_location,
            },
        }
    );

    return $scrn;

}

sub feature_set {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;
    my $done    = $q->param('done') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'feature_set'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::Template::Widgets::Admin_Menu;

    if ( !$process ) {

        my $feature_set_menu = DADA::Template::Widgets::Admin_Menu::make_feature_menu( $ls->get );

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'feature_set_screen.tmpl',
                -with           => 'admin',
				-expr           => 1, 
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },

                -vars => {
                    screen                        => 'feature_set',
                    done                          => ( defined($done) ) ? 1 : 0,
                    feature_set_menu              => $feature_set_menu,
                    disabled_screen_view_hide     => ( $ls->param('disabled_screen_view') eq 'hide' ) ? 1 : 0,
                    disabled_screen_view_grey_out => ( $ls->param('disabled_screen_view') eq 'grey_out' ) ? 1 : 0,
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        return $scrn;
    }
    else {

        my @params = $q->param;
        my %param_hash;
        for (@params) {
            next if $_ eq 'disabled_screen_view';    # special case.
            $param_hash{$_} = $q->param($_);
        }

        my $save_set = DADA::Template::Widgets::Admin_Menu::create_save_set( \%param_hash );

        my $disabled_screen_view     = $q->param('disabled_screen_view');
        my $list_control_panel_style = $q->param('list_control_panel_style') // 'top_bar';

        $ls->save(
            {
                admin_menu               => $save_set,
                disabled_screen_view     => $disabled_screen_view,
				list_control_panel_style => $list_control_panel_style,
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=feature_set&done=1' );

    }
}

sub list_cp_options {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'list_cp_options'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( !$process ) {

        my %wysiwyg_vars = DADA::Template::Widgets::make_wysiwyg_vars($list);

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'list_cp_options_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -expr => 1,
                -list => $list,
                -vars => {
                    screen => 'list_cp_options',
                    done   => xss_filter( scalar $q->param('done') ),

                    ckeditor_enabled => $DADA::Config::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{enabled},
                    ckeditor_url     => $DADA::Config::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{url},

                    tiny_mce_enabled => $DADA::Config::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{enabled},
                    tiny_mce_url     => $DADA::Config::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{url},
                    %wysiwyg_vars,

                },
                -list_settings_vars       => $ls->get,
                -list_settings_vars_param => { -dot_it => 1 },
            }
        );

        return $scrn;
    }
    else {

        $ls->save_w_params(
            {
                -associate => $q,
                -settings  => {
                    use_wysiwyg_editor => 'none',
                }
            }
        );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=list_cp_options&done=1' );

    }
}

sub profile_fields {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process') || undef;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'profile_fields'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;

    require DADA::ProfileFieldsManager;
    my $pfm = DADA::ProfileFieldsManager->new;

    require DADA::Profile::Fields;
    my $dpf = DADA::Profile::Fields->new;

    if ( $dpf->can_have_subscriber_fields == 0 ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'profile_fields_screen.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => {
                    screen                     => 'profile_fields',
                    title                      => 'Profile Fields',
                    can_have_subscriber_fields => $dpf->can_have_subscriber_fields,

                },
            }
        );
        return $scrn;
    }

    # But, if we do....
    my $subscriber_fields = $pfm->fields;
    my $fields_attr       = $pfm->get_all_field_attributes;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $field_status        = 1;
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
    my %flattened_field_errors = ();

    my $edit_field = xss_filter( scalar $q->param('edit_field') );

    my $field                = '';
    my $fallback_field_value = '';
    my $field_label          = '';
    my $field_required       = 0;

    if ( $edit_field == 1 ) {
        $field                = xss_filter( scalar $q->param('field') );
        $fallback_field_value = $fields_attr->{$field}->{fallback_value};
        $field_label          = $fields_attr->{$field}->{label};
        $field_required       = $fields_attr->{$field}->{required};
    }
    else {
        $field                = xss_filter( scalar $q->param('field') );
        $fallback_field_value = xss_filter( scalar $q->param('fallback_field_value') );
        $field_label          = xss_filter( scalar $q->param('field_label') );
        $field_required       = $q->param('field_required') || 0;
        if ( $field_required ne "1" && $field_required ne "0" ) {
            die "field_required needs to be either 1, or 0!";
            $field_required = 0;
        }
    }

    if ( !$root_login && defined($process) ) {
        die "You need to log into the list with the root pass to do that!";
    }
    if ( $process eq 'edit_field_order' ) {
        my $dir = $q->param('direction') || 'down';
        $pfm->change_field_order(
            {
                -field     => $field,
                -direction => $dir,
            }
        );
        $c->flush;

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?flavor=profile_fields' );

    }
    if ( $process eq 'delete_field' ) {
        ###
        $pfm->remove_field( { -field => $field } );
        $c->flush;

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
              . '?flavor=profile_fields;deletion=1;working_field='
              . $field
              . ';field_changes=1' );

    }
    elsif ( $process eq 'add_field' ) {

        ( $field_status, $field_error_details ) = $pfm->validate_field_name( { -field => $field } );

        if ( $field_status == 1 ) {
            $pfm->add_field(
                {
                    -field          => $field,
                    -fallback_value => $fallback_field_value,
                    -label          => $field_label,
                    -required       => $field_required,
                }
            );

            $c->flush;
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=profile_fields;addition=1;working_field='
                  . $field
                  . ';field_changes=1' );

        }
        else {
            # Else, I guess for now, we'll show the template and have the errors print out there...
            for (%$field_error_details) {
                $flattened_field_errors{ 'field_error_' . $_ } = $field_error_details->{$_};
            }

        }
    }
    elsif ( $process eq 'edit_field' ) {

        my $orig_field = xss_filter( scalar $q->param('orig_field') );

        #old name			# new name
        if ( $orig_field eq $field ) {
            ( $field_status, $field_error_details ) =
              $pfm->validate_field_name( { -field => $field, -skip => [qw(field_exists)] } );
        }
        else {
            ( $field_status, $field_error_details ) = $pfm->validate_field_name( { -field => $field } );
        }
        if ( $field_status == 1 ) {

            $pfm->remove_field_attributes( { -field => $orig_field } );

            if ( $orig_field eq $field ) {

                # ...
            }
            else {
                $pfm->edit_field_name( { -old_name => $orig_field, -new_name => $field } );
                my $meta = $ls->param('tracker_update_profile_fields_ip_dada_meta');
                if ( length($meta) > 4 ) {
                    my $thawed_gip = $ls->_dd_thaw($meta);
                    $thawed_gip->{$field} = $thawed_gip->{$orig_field};
                    delete( $thawed_gip->{$orig_field} );
                    $ls->save( { tracker_update_profile_fields_ip_dada_meta => $ls->_dd_freeze($thawed_gip) } );
                }
            }
            $pfm->save_field_attributes(
                {
                    -field          => $field,
                    -fallback_value => $fallback_field_value,
                    -label          => $field_label,
                    -required       => $field_required,
                }
            );
            $c->flush;

            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=profile_fields;edited=1;working_field='
                  . $field
                  . ';field_changes=1' );
        }
        else {
            # Else, I guess for now, we'll show the template and have the errors print out there...
            $edit_field = 1;
            $field      = xss_filter( scalar $q->param('orig_field') );

            for (%$field_error_details) {
                $flattened_field_errors{ 'field_error_' . $_ } = $field_error_details->{$_};
            }
        }
    }

    my $can_move_columns = ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) ? 1 : 0;

    my $named_subscriber_fields = [];

    for (@$subscriber_fields) {
        push(
            @$named_subscriber_fields,
            {
                field            => $_,
                fallback_value   => $fields_attr->{$_}->{fallback_value},
                label            => $fields_attr->{$_}->{label},
                required         => $fields_attr->{$_}->{required},
                root_login       => $root_login,
                can_move_columns => $can_move_columns,
            }
        );
    }

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'profile_fields_screen.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },

            -vars => {

                screen => 'profile_fields',
                title  => 'Profile Fields',

                edit_field => $edit_field,
                fields     => $named_subscriber_fields,

                field_status         => $field_status,
                field                => $field,
                fallback_field_value => $fallback_field_value,
                field_label          => $field_label,
                field_required       => $field_required,

                can_have_subscriber_fields => $dpf->can_have_subscriber_fields,

                root_login => $root_login,

                HIDDEN_SUBSCRIBER_FIELDS_PREFIX => $DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX,

                using_SQLite => $DADA::Config::SUBSCRIBER_DB_TYPE eq 'SQLite'
                ? 1
                : 0,
                field_changes => xss_filter( scalar $q->param('field_changes') ),
                working_field => xss_filter( scalar $q->param('working_field') ),
                deletion      => xss_filter( scalar $q->param('deletion') ),
                addition      => xss_filter( scalar $q->param('addition') ),
                edited        => xss_filter( scalar $q->param('edited') ),

                can_move_columns => $can_move_columns,

                %flattened_field_errors,
            },
        }
    );
    return $scrn;

}

sub subscribe {

    my $self = shift;
    my $q    = $self->query();

    my %args = ( -html_output => 1, @_ );

    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
    my ( $headers, $body ) = $das->subscribe(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );

    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }

}

sub restful_subscribe {

    my $self = shift;
    my $q    = $self->query();

	try  {
		require JSON;
	} catch { 
		warn 'Perl CPAN module: JSON is required!';
		 die '425';
	};
	
    my $json = JSON->new->allow_nonref;

    my $using_jsonp = 0;

    if ( $q->param('_method') eq 'GET' && $q->url_param('callback') ) {

        # that's OK - it's a jsonp call.
        $using_jsonp = 1;
    }
    elsif ( $q->content_type =~ m/application\/json/ ) {

        # That's OK too - we support getting the params you send us in POST
    }
    elsif ( !$q->content_type || $q->content_type =~ m/text\/html/ ) {

        # RTFM!
        my $api_doc_url = 'http://dadamailproject.com/d/COOKBOOK-subscriptions.pod.html#restful_api';
        return '<p>API Documentation: <a href="' . $api_doc_url . '"/>' . $api_doc_url . '</a></p>';
    }
    else {
        die '425';
    }

    my $new_q = undef;
    if ( $using_jsonp == 0 ) {

        my $post_data = $q->param('POSTDATA');
        my $data      = undef;
        try {
            $data = $json->decode($post_data);
        } catch {
            # What should really be done is to return a custom json doc
            # saying there was a problem with the POSTDATA - essentially, it
            # would be blank. 
            warn 'problems decoding POSTDATA: ' . $_;
            warn 'POSTDATA looks like this: ' . $data;
            die '400';
        };
        
        require CGI; 
        $new_q = CGI->new;
        $new_q->charset($DADA::Config::HTML_CHARSET);

        $new_q->delete_all;

        $new_q->param( 'list',   $data->{list} );
        $new_q->param( 'email',  $data->{email} );
        $new_q->param( 'flavor', 'subscribe' );

        require DADA::ProfileFieldsManager;
        my $pfm = DADA::ProfileFieldsManager->new;

        # Profile Fields
        for ( @{ $pfm->fields } ) {
            if ( exists( $data->{fields}->{$_} ) ) {
                $new_q->param( $_, $data->{fields}->{$_} );
            }
        }
    }
    else {
        $new_q = $q;
    }

    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;

    my $callback = undef;
    if ($using_jsonp) {
        $callback = xss_filter( strip( $q->url_param('callback') ) );
    }

    my $headers = {};
    if ($using_jsonp) {
        $headers = {
            -type                          => 'application/javascript',
            '-Access-Control-Allow-Origin'  => '*',
            '-Access-Control-Allow-Methods' => 'POST',
            '-Cache-Control'               => 'no-cache, must-revalidate',
            -expires                       => 'Mon, 26 Jul 1997 05:00:00 GMT',
        };

    }
    else {
        $headers = {
            -type            => 'application/json',
            '-Cache-Control' => 'no-cache, must-revalidate',
            -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
        };
    }

    my ( $throwaway_headers, $body ) = $das->subscribe(
        {
            -cgi_obj     => $new_q,
            -return_json => 1,
        }
    );

    #	warn "\$callback\n" . $callback;
    #	warn "\$headers\n" . $headers;

    if ($using_jsonp) {
        $self->header_props(%$headers);
        return $callback . '(' . $body . ');';
    }
    else {
        $self->header_props(%$headers);
        return $body;
    }
}

sub unsubscribe {

    my $self = shift;
    my $q    = $self->query();

    my %args = ( -html_output => 1, @_ );
    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
    my ( $headers, $body ) = $das->unsubscribe(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );
    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }

}




sub unsubscription_request {

    my $self = shift;
    my $q    = $self->query();

    my %args = ( -html_output => 1, @_ );
    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
    my ( $headers, $body ) = $das->unsubscription_request(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );
    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }

}

sub unsubscribe_email_lookup { 
	
    my $self  = shift;
    my $q     = $self->query();

    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
    my ( $headers, $body ) = $das->unsubscribe_email_lookup(
        {
            -cgi_obj     => $q,
        }
    );
    $self->header_props(%$headers);
    return $body;

}



sub outdated_subscription_urls {

    my $self  = shift;
    my $q     = $self->query();
    my $list  = $q->param('list');
    my $email = $q->param('email');

    if ( check_if_list_exists( -List => $list ) == 0 ) {
        undef($list);
        return $self->default();
    }

    my $orig_flavor = $q->param('orig_flavor') || undef;

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'outdated_subscription_urls_screen.tmpl',
            -with   => 'list',
            -list   => $list,
            -expr   => 1,

            #		-list_settings_vars_param => {-list => $list,},
            #		-subscriber_vars_param    => {-list => $list, -email => $email, -type => 'list'},

            -vars => {
                show_profile_widget => 0,
                orig_flavor         => $orig_flavor,

                subscription_form => DADA::Template::Widgets::subscription_form(
                    {
                        -list       => $list,
                        -email      => $email,
                        -give_props => 0,
                        -magic_form => 0,
                    },
                ),
                unsubscription_form => DADA::Template::Widgets::unsubscription_form(
                    {
                        -list  => $list,
                        -email => $email,
                    },
                ),
            }
        }
    );
    return $scrn;
}

sub token {

    my $self = shift;
    my $q    = $self->query();

    my %args = ( -html_output => 1, @_ );
    require DADA::App::Subscriptions;
    my $das = DADA::App::Subscriptions->new;
    my ( $headers, $body ) = $das->token(
        {
            -cgi_obj     => $q,
            -html_output => $args{-html_output},
        }
    );
    
    # use Data::Dumper;
    # warn Dumper({headers => $headers, body => $body}); 
    
    if ( exists( $headers->{-redirect_uri} ) ) {
        $self->header_type('redirect');
        $self->header_props( -url => $headers->{-redirect_uri} );
    }
    else {
        if ( keys %$headers ) {
            $self->header_props(%$headers);
        }
        return $body;
    }
}

sub report_abuse {

    my $self = shift;
    my $q    = $self->query();

    my $report_abuse_token = $q->param('report_abuse_token');
    my $process = $q->param('process') || 0;

    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();

    if ( $ct->exists($report_abuse_token) ) {
        my $data = $ct->fetch($report_abuse_token);

        if ( $data->{data}->{flavor} eq 'report_abuse' ) {

            my $list = $data->{data}->{list};

            if ( $process != 1 ) {

                my $scrn = DADA::Template::Widgets::wrap_screen(
                    {
                        -screen => 'report_abuse.tmpl',
                        -with   => 'list',
                        -vars   => {
                            report_abuse_token => $report_abuse_token,
                        },
                        -list_settings_vars_param => { -list => $list, -dot_it => 1 },
                    }
                );
                return $scrn;
            }
            else {

                my $abuse_report_details = $q->param('abuse_report_details');
                $abuse_report_details =~ s/\r\n/\n/g;

                my $email = $data->{email};

                #use Data::Dumper;
                #warn Dumper($data);

                # Email the Abuse Report
                require DADA::App::Messages;
                DADA::App::Messages::send_abuse_report(
                    {
                        -list                 => $list,
                        -email                => $email,
                        -abuse_report_details => $abuse_report_details,
                    }
                );

                # (log the actual report?)
                # ... #
                #

                # Log it for the Tracker
                require DADA::Logging::Clickthrough;
                my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
                    $r->abuse_log(
                        {
                            -email => $email,
                            -mid   => $data->{data}->{mid},

                            # -details => unique_id to some sort of report table...
                        }
                    );
            

                $ct->remove_by_token($report_abuse_token);

                # Tell 'em it worked!
                my $scrn = DADA::Template::Widgets::wrap_screen(
                    {
                        -screen                   => 'report_abuse_complete.tmpl',
                        -with                     => 'list',
                        -vars                     => {},
                        -list_settings_vars_param => { -list => $list, -dot_it => 1 },
                    }
                );
                return $scrn;

            }
        }
        else {
            return user_error( { -error => 'token_problem' } );
        }
    }
    else {
        return user_error( { -error => 'token_problem' } );
    }
}

sub resend_conf {

    my $self  = shift;
    my $q     = $self->query();
    my $list  = $q->param('list');
    my $email = $q->param('email');

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $can_use_captcha = 0;

    if ( $ls->param('limit_sub_confirm_use_captcha') == 1 ) {
        $can_use_captcha = can_use_AuthenCAPTCHA();
    }
    if ( $can_use_captcha == 1 ) {
        $self->resend_conf_captcha();
    }
    else {
        $self->resend_conf_no_captcha();
    }

}

sub resend_conf_captcha {

    my $self  = shift;
    my $q     = $self->query();
    my $list  = $q->param('list');
    my $email = $q->param('email');

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $captcha_worked = 0;
    my $captcha_auth   = 1;
    if ( !xss_filter( scalar $q->param('recaptcha_response_field') ) ) {
        $captcha_worked = 0;
    }
    else {
        require DADA::Security::AuthenCAPTCHA;
        my $cap    = DADA::Security::AuthenCAPTCHA->new;
        my $result = $cap->check_answer(
            $DADA::Config::RECAPTCHA_PARAMS->{private_key}, $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
            $q->param('recaptcha_challenge_field'),         $q->param('recaptcha_response_field')
        );
        if ( $result->{is_valid} == 1 ) {
            $captcha_auth   = 1;
            $captcha_worked = 1;
        }
        else {
            $captcha_worked = 0;
            $captcha_auth   = 0;
        }
    }
    if ( $captcha_worked == 1 ) {
        if ( $q->param('rm') eq 's' ) {

            # so, what's $sub_info for?!
            my $sub_info = $lh->get_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_confirm_list',
                }
            );
            for ( keys %{$sub_info} ) {
                next if $_ eq 'email';
                next if $_ eq 'email_name';
                next if $_ eq 'email_domain';
                $q->param( $_, $sub_info->{$_} );
            }

            my $rm_status = $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_confirm_list'
                }
            );
            $q->param( 'list',  $list );
            $q->param( 'email', $email );
            $q->delete( 'flavor', 'rm', 'recaptcha_challenge_field', 'recaptcha_response_field', 'token' );
            $q->param( 'flavor', 's' );
            $self->subscribe();

        }
        elsif ( $q->param('rm') eq 'unsubscription_request' ) {

            # I like the idea better that we call the function directly...
            my $rm_status = $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'unsub_confirm_list'
                }
            );
            $q->param( 'list',   $list );
            $q->param( 'email',  $email );
            $q->param( 'flavor', 'unsubscription_request' );
            $self->unsubscription_request();
        }
    }
    else {
        my $error = '';
        if ( $q->param('rm') eq 's' ) {
            $error = 'already_sent_sub_confirmation';
        }
        elsif ( $q->param('rm') eq 'unsubscription_request' ) {
            $error = 'already_sent_unsub_confirmation';
        }
        else {
            die 'unknown $rm!';
        }
        return user_error(
            {
                -error => $error,
                -list  => $list,
                -email => $email,
                -vars  => { captcha_auth => $captcha_auth, },
            }
        );
    }

}

sub resend_conf_no_captcha {

    my $self  = shift;
    my $q     = $self->query();
    my $list  = $q->param('list');
    my $email = $q->param('email');

    my $list_exists = check_if_list_exists( -List => $list, );

    if ( $list_exists == 0 ) {
        return $self->default();
    }
    if ( !$email ) {
        $q->param( 'error_no_email', 1 );
        return $self->list_page();
    }
    if (   $q->param('rm') ne 's'
        && $q->param('rm') ne 'u' )
    {
        return $self->default();
    }
    if ( $q->request_method() !~ m/POST/i ) {
        return $self->default();
    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my ( $sec, $min, $hour, $day, $month, $year ) = (localtime)[ 0, 1, 2, 3, 4, 5 ];

    # This is just really broken... should be a CAPTCHA...
    # I'm assuming this happens if we FAILED this test below (1 = failure for check_email_pin)
    #

    if (
        DADA::App::Guts::check_email_pin(
            -Email => $month . '.' . $day . '.' . $email,
            -Pin   => xss_filter( scalar $q->param('auth_code') ),
            -List  => $list,
        ) == 0
      )
    {
        my ( $e_day, $e_month, $e_stuff ) = split( '.', $email );

        #  Ah, I see, it only is blocked for a... day?
        if ( $e_day != $day || $e_month != $month ) {

            # a stale blocking thingy.
            if ( $q->param('rm') eq 's' ) {
                my $rm_status = $lh->remove_subscriber(
                    {
                        -email => $email,
                        -type  => 'sub_confirm_list'
                    }
                );
            }
            elsif ( $q->param('rm') eq 'u' ) {

                my $rm_status = $lh->remove_subscriber(
                    {
                        -email => $email,
                        -type  => 'unsub_confirm_list'
                    }
                );
            }
        }
        return $self->list_page();
    }
    else {

        if ( $q->param('rm') eq 's' ) {
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
            $q->param( 'list',   $list );
            $q->param( 'email',  $email );
            $q->param( 'flavor', 's' );
            $self->subscribe();
        }
        elsif ( $q->param('rm') eq 'u' ) {

            # I like the idea better that we call the function directly...
            my $rm_status = $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'unsub_confirm_list'
                }
            );
            $q->param( 'list',   $list );
            $q->param( 'email',  $email );
            $q->param( 'flavor', 'unsubscription_request' );
            $self->unsubscription_request();
        }
    }
}

sub show_error {

    my $self = shift;
    my $q    = $self->query();

    my $email = xss_filter( scalar $q->param('email') ) || undef;
    my $error = xss_filter( scalar $q->param('error') ) || undef;
    my $list  = xss_filter( scalar $q->param('list') )  || undef;

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $list_exists = check_if_list_exists( -List => $list, );
    if ( $list_exists == 0 ) {
        return $self->default();
    }
    if ( !$email ) {
        $q->param( 'error_no_email', 1 );
        return $self->list_page();
    }

    if ( $error ne 'already_sent_sub_confirmation' ) {
        return $self->default();
    }

    require DADA::App::Error;
    my $error_msg = DADA::App::Error::cgi_user_error(
        {
            -list  => $list,
            -error => $error,
            -email => $email,
        }
    );
    return $error_msg;

}

sub text_list {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'text_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    my $ls   = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh   = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $type            = $q->param('type')                          || 'list';
    my $query           = xss_filter( scalar $q->param('query') )           || undef;
    my $advanced_search = xss_filter( scalar $q->param('advanced_search') ) || 0;
    my $advanced_query  = xss_filter( scalar $q->param('advanced_query') )  || undef;
    my $order_by        = $q->param('order_by')                      || $ls->param('view_list_order_by');
    my $order_dir = $q->param('order_dir') || lc( $ls->param('view_list_order_by_direction') );

    my $partial_listing = {};
    if ($advanced_query) {
        if ( $advanced_search == 1 ) {
            open my $fh, '<', \$advanced_query || die $!;
            require CGI;
            my $new_q = CGI->new($fh);
            $new_q->charset($DADA::Config::HTML_CHARSET);
            $new_q           = decode_cgi_obj($new_q);
            $partial_listing = partial_sending_query_to_params($new_q);
        }
    }

    my $email;

    my $headers = {
        -attachment => $list . '-' . $type . '.csv',
        -type       => 'text/csv',
    };
    my $body;
    if ($advanced_query) {
        $body = $lh->print_out_list(
            {
                -type                  => $type,
                -order_by              => $order_by,
                -order_dir             => $order_dir,
                -partial_listing       => $partial_listing,
                -show_timestamp_column => 1,
                -print_out             => 0,
            }
        );
    }
    else {
        $body = $lh->print_out_list(
            {
                -type                  => $type,
                -query                 => $query,
                -order_by              => $order_by,
                -order_dir             => $order_dir,
                -show_timestamp_column => 1,
                -print_out             => 0,
            }
        );
    }
    $self->header_props(%$headers);
    return $body;
}

sub new_list {

    my $self = shift;
    my $q    = $self->query();

    require DADA::Security::Password;
    my $root_password    = $q->param('root_password');
    my $agree            = $q->param('agree');
    my $process          = $q->param('process');
    my $help             = $q->param('help');
    my $list             = $q->param('list');
    my $list_name        = $q->param('list_name') || undef;
    my $list_owner_email = $q->param('list_owner_email') || undef;
    my $admin_email      = $q->param('admin_email') || undef;
    my $privacy_policy   = $q->param('privacy_policy') || undef;
    my $info             = $q->param('info') || undef;
    my $physical_address = $q->param('physical_address') || undef;
    my $password         = $q->param('password') || undef;
    my $retype_password  = $q->param('retype_password') || undef;

    if ( !$process ) {

        my $errors = shift;
        my $flags  = shift;
        my $pw_check;

        require DADA::Security::SimpleAuthStringState;
        my $sast       = DADA::Security::SimpleAuthStringState->new;
        my $auth_state = $q->param('auth_state');

        if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
            if ( $sast->check_state($auth_state) != 1 ) {
                return user_error( { -list => undef, -error => 'incorrect_login_url' } );
            }

        }

        if ( !$DADA::Config::PROGRAM_ROOT_PASSWORD ) {
            return user_error( { -list => $list, -error => "no_root_password" } );
        }
        elsif ( $DADA::Config::ROOT_PASS_IS_ENCRYPTED == 1 ) {

            #encrypted password check
            $pw_check =
              DADA::Security::Password::check_password( $DADA::Config::PROGRAM_ROOT_PASSWORD, $root_password );
        }
        else {
            # unencrypted password check
            if ( $DADA::Config::PROGRAM_ROOT_PASSWORD eq $root_password ) {
                $pw_check = 1;
            }
        }

        if ( $pw_check == 1 ) {

            my @t_lists = available_lists();

            $agree = 'yes' if $errors;

            if ( ( !$t_lists[0] ) && ( $agree ne 'yes' ) && ( !$process ) ) {
                $self->header_type('redirect');
                $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?agree=no' );
            }

            $DADA::Config::LIST_QUOTA = undef
              if strip($DADA::Config::LIST_QUOTA) eq '';
            if (   ($DADA::Config::LIST_QUOTA)
                && ( ( $#t_lists + 1 ) >= $DADA::Config::LIST_QUOTA ) )
            {
                return user_error( { -list => $list, -error => "over_list_quota" } );
            }

            if ( !$t_lists[0] ) {
                $help = 1;
            }

            my $ending   = undef;
            my $err_word = undef;

            if ($errors) {
                $ending   = '';
                $err_word = 'was';
                $ending   = 's' if $errors > 1;
                $err_word = 'were' if $errors > 1;
            }

            my @available_lists = DADA::App::Guts::available_lists();
            my $lists_exist     = $#available_lists + 1;

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
                    -wrapper_params => {
                       -Use_Custom => 0,
                    },
                    -vars   => {
                        errors                   => $errors,
                        ending                   => $ending,
                        err_word                 => $err_word,
                        help                     => $help,
                        root_password            => $root_password,
                        flags_list_name          => $flags->{list_name},
                        list_name                => $list_name,
                        flags_list_exists        => $flags->{list_exists},
                        flags_list               => $flags->{list},
                        flags_shortname_too_long => $flags->{shortname_too_long},
                        flags_slashes_in_name    => $flags->{slashes_in_name},
                        flags_weird_characters   => $flags->{weird_characters},
                        flags_quotes             => $flags->{quotes},
                        list                     => $list,
                        flags_password           => $flags->{password},
                        password                 => $password,

                        flags_password_is_root_password => $flags->{password_is_root_password},

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

                        lists_exist     => $lists_exist,
                        list_popup_menu => $list_popup_menu,
                        auth_state      => $sast->make_state

                    },
                }
            );
            return $scrn;

        }
        else {
			require DADA::Template::Widgets; 
            return DADA::Template::Widgets::admin(
				{ 
		            -cgi_obj      => $q,
					-vars         => {
						errors      => [{error => 'invalid_root_password'}],
						error_with  => 'new_list', 
					}
				}
			); 
            
        }
    }
    else {

        chomp($list);
        $list =~ s/^\s+//;
        $list =~ s/\s+$//;

        # $list =~ s/ /_/g; # What?

        my $list_exists = check_if_list_exists( -List => $list );
        my ( $list_errors, $flags ) = check_list_setup(
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

        if ( $list_errors >= 1 ) {
            undef($process);
            $q->delete('process'); 
            
            $self->new_list( $list_errors, $flags );

        }
        elsif ( $list_exists >= 1 ) {
            return user_error(
                {
                    -list  => $list,
                    -error => "list_already_exists"
                }
            );
        }
        else {

            $list_owner_email = lc_email($list_owner_email);
            $password         = DADA::Security::Password::encrypt_passwd($password);

            my $new_info = {

                #	list             =>   $list,
                list_owner_email => $list_owner_email,
                list_name        => $list_name,
                password         => $password,
                info             => $info,
                privacy_policy   => $privacy_policy,
                physical_address => $physical_address,
            };

            require DADA::MailingList;
            my $ls;
            if ( $q->param('clone_settings') == 1 ) {
                $ls = DADA::MailingList::Create(
                    {
                        -list     => $list,
                        -settings => $new_info,
                        -clone    => xss_filter( scalar $q->param('clone_settings_from_this_list') ),
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

            if ( $DADA::Config::LOG{list_lives} ) {
                require DADA::Logging::Usage;
                my $log = new DADA::Logging::Usage;
                $log->mj_log( $list, 'List Created',
                    "remote_host:$ENV{REMOTE_HOST}," . "ip_address:$ENV{REMOTE_ADDR}" );
            }

            my $escaped_list = uriescape( $ls->param('list') );

            my $auth_state;

            if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
                require DADA::Security::SimpleAuthStringState;
                my $sast = DADA::Security::SimpleAuthStringState->new;
                $auth_state = $sast->make_state;
            }

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'new_list_created_screen.tmpl',
                    -with   => 'list',
                    -wrapper_params => {
                       -Use_Custom => 0,
                    },
                    -vars   => {
                        list_name        => $ls->param('list_name'),
                        list             => $ls->param('list'),
                        escaped_list     => $escaped_list,
                        list_owner_email => $ls->param('list_owner_email'),
                        info             => $ls->param('info'),
                        privacy_policy   => $ls->param('privacy_policy'),
                        physical_address => $ls->param('physical_address'),
                        auth_state       => $auth_state,
                    },
                }
            );
            return $scrn;

        }
    }
}

sub list_archive {

    my $self  = shift;
    my $q     = $self->query();
    my $list  = $q->param('list');
    my $email = $q->param('email');

    # are we dealing with a real list?
    my $list_exists = check_if_list_exists( -List => $list, );

    if ( $list_exists == 0 ) {

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::PROGRAM_URL );

    }

    my $id = $q->param('id') || undef;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::Profile;
    my $prof = DADA::Profile->new( { -from_session => 1 } );
    my $allowed_to_view_archives = 1;
    if ($prof) {
        $allowed_to_view_archives = $prof->allowed_to_view_archives( { -list => $list, } );
    }
    if ( $allowed_to_view_archives == 0 ) {
        return user_error( { -list => $list, -error => "not_allowed_to_view_archives" } );
    }

    my $start = int( $q->param('start') ) || 0;

    if ( $ls->param('show_archives') == 0 ) {
        return user_error( { -list => $list, -error => "no_show_archives" } );
    }

    require DADA::MailingList::Archives;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    my $entries = $archive->get_archive_entries();

###### These are all little thingies.

    my $archive_send_form = '';
    $archive_send_form = DADA::Template::Widgets::archive_send_form(
        $list, $id,
        xss_filter( scalar $q->param('send_archive_errors') ),
        $ls->param('captcha_archive_send_form'),
        xss_filter( scalar $q->param('captcha_fail') )
    ) if $ls->param('archive_send_form') == 1 && defined($id);

    my $nav_table = '';
    $nav_table = $archive->make_nav_table( -Id => $id, -List => $ls->param('list') )
      if defined($id);


    my $archive_subscribe_form = "";

    if ( $ls->param('hide_list') ne "1" ) {

        # DEV: This takes the cake for worst hack I have found... today.
        my $info = '<!-- tmpl_var list_settings.info -->';
        $info = DADA::Template::Widgets::screen(
            {
                -data                     => \$info,
                -list_settings_vars_param => { -list => $list, -dot_it => 1 },
                -webify_and_santize_these => [qw(list_settings.info)],
            }
        );

        unless ( $ls->param('archive_subscribe_form') eq "0" ) {

            $archive_subscribe_form = DADA::Template::Widgets::subscription_form(
                {
                    -list       => $ls->param('list'),
                    -email      => $email,
                    -give_props => 0,
                }
            );
        }
    }

    my $archive_widgets = {
        archive_send_form      => $archive_send_form,
        nav_table              => $nav_table,
        publish_archives_rss   => $ls->param('publish_archives_rss') ? 1 : 0,
        subscription_form      => $archive_subscribe_form,
    };

    #/##### These are all little thingies.

    if ( !$id ) {

        if (  !$c->profile_on
            && $c->is_cached( 'archive/' . $list . '/' . $start . '.scrn' ) )
        {
            return $c->cached( 'archive/' . $list . '/' . $start . '.scrn' );

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

                my ( $subject, $message, $format, $raw_msg ) = $archive->get_archive_info( $entries->[$i] );

                # DEV: This is stupid, and I don't think it's a great idea.
                # $subject = safely_decode($subject);
                $subject = DADA::Template::Widgets::screen(
                    {
                        -data                     => \$subject,
                        -vars                     => $ls->get,
                        -list_settings_vars       => $ls->get,
                        -list_settings_vars_param => { -dot_it => 1 },
                        -dada_pseudo_tag_filter   => 1,
                        -subscriber_vars_param    => { -use_fallback_vars => 1, -list => $list },
                    },

                );

                # this is so atrocious.
                my $date = date_this(
                    -Packed_Date   => $archive->_massaged_key( $entries->[$i] ),
                    -Write_Month   => $ls->param('archive_show_month'),
                    -Write_Day     => $ls->param('archive_show_day'),
                    -Write_Year    => $ls->param('archive_show_year'),
                    -Write_H_And_M => $ls->param('archive_show_hour_and_minute'),
                    -Write_Second  => $ls->param('archive_show_second'),
                );
                my $header_from      = undef;
                my $orig_header_from = undef;

                if ($raw_msg) {
                    $header_from = $archive->get_header(
                        -header => 'From',
                        -key    => $entries->[$i]
                    );
                    $orig_header_from = $header_from;
                }

                my $can_use_gravatar_url = 1;
                my $gravatar_img_url     = undef;
				my $show_gravatar        = 0; 
				
                if ( $ls->param('enable_gravatars') ) {

                    try { 
						require Gravatar::URL 
					} catch { 
						$can_use_gravatar_url = 0; 
					};
					
                    if ( $can_use_gravatar_url == 1 ) {
                        my $header_address = $archive->sender_address(
                             {
                                    -id => $entries->[$i],
                                }
                        ); 
                        $gravatar_img_url = gravatar_img_url(
                            {
                                -email                => $header_address,
                                -default_gravatar_url => $ls->param('default_gravatar_url'),
                            }
                        );
                        
                    }
                    else {
                        $can_use_gravatar_url = 0;
                    }
					if($ls->param('enable_gravatars') ==1 
						&& $can_use_gravatar_url == 1
						&& defined(gravatar_img_url)
					) { 
						$show_gravatar = 1; 
					}
					
					
                }

                my $entry = {
                    id                               => $entries->[$i],
                    date                             => $date,
                    subject                          => $subject,
                    'format'                         => $format,
                    list                             => $list,
                    uri_escaped_list                 => uriescape($list),
                    PROGRAM_URL                      => $DADA::Config::PROGRAM_URL,
                    message_blurb                    => $archive->message_blurb( -key => $entries->[$i] ),
                    show_gravatar					 => $show_gravatar, 
					can_use_gravatar_url             => $can_use_gravatar_url,
                    gravatar_img_url                 => $gravatar_img_url,

                };

                $stopped_at++;
                push( @archive_nums,  $num );
                push( @archive_links, $link );
                $num++;

                push( @$th_entries, $entry );

            }
        }

        my $ii;
        for ( $ii = 0 ; $ii <= $#archive_links ; $ii++ ) {

            my $bullet = $archive_nums[$ii];

            #fix if we're doing reverse chronologic
            $bullet = ( ( $#{$entries} + 1 ) - ( $archive_nums[$ii] ) + 1 )
              if ( $ls->param('sort_archives_in_reverse') == 1 );

            # yeah, whatever.
            $th_entries->[$ii]->{bullet} = $bullet;

        }

        my $index_nav = $archive->create_index_nav($stopped_at);

        require DADA::Profile;
        my $prof = DADA::Profile->new( { -from_session => 1 } );
        my $allowed_to_view_archives = 1;
        if ($prof) {
            $allowed_to_view_archives = $prof->allowed_to_view_archives( { -list => $list, } );
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'list_archive_index_screen.tmpl',
                -with   => 'list',
                -vars   => {
                    list                     => $list,
                    list_name                => $ls->param('list_name'),
                    entries                  => $th_entries,
                    index_nav                => $index_nav,
                    flavor_archive           => 1,
                    allowed_to_view_archives => $allowed_to_view_archives,
                    publish_archives_rss     => $ls->param('publish_archives_rss')
                    ? 1
                    : 0,

                    %$archive_widgets,

                },
				
                -list_settings_vars       => $ls->get,
                -list_settings_vars_param => { -list => $list, -dot_it => 1 },
		        -webify_and_santize_these => [qw(list_settings.discussion_pop_email list_settings.list_owner_email list_settings.info list_settings.privacy_policy )], 

            }
        );
        if ( !$c->profile_on ) {
            $c->cache( 'archive/' . $list . '/' . $start . '.scrn', \$scrn );
        }
        return $scrn;

    }
    else {    # There's an id...

        $id = $archive->newest_entry if $id =~ /newest/i;
        $id = $archive->oldest_entry if $id =~ /oldest/i;

        if ( $q->param('extran') ) {

            $self->header_type('redirect');
            $self->header_props(
                -url => $DADA::Config::PROGRAM_URL . '/archive/' . $ls->param('list') . '/' . $id . '/' );
        }

        if ( $id !~ m/(\d+)/g ) {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::PROGRAM_URL . '/archive/' . $ls->param('list') . '/' );
        }

        $id = $archive->_massaged_key($id);

        if (   $ls->param('archive_send_form') != 1
            && $ls->param('captcha_archive_send_form') != 1 )
        {

            if (  !$c->profile_on
                && $c->is_cached( 'archive/' . $list . '/' . $id . '.scrn' ) )
            {
                require DADA::Logging::Clickthrough;
                my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
                   $r->view_archive_log( { -mid => $id, } );
                return $c->cached( 'archive/' . $list . '/' . $id . '.scrn' );
            }
        }

        my $entry_exists = $archive->check_if_entry_exists($id);
        if ( $entry_exists <= 0 ) {
            return user_error( { -list => $list, -error => "no_archive_entry" } );
        }

        my ( $subject, $message, $format, $raw_msg ) = $archive->get_archive_info($id);

        # DEV: This is stupid, and I don't think it's a great idea.
        $subject = $archive->_parse_in_list_info( -data => $subject );

        # That. Sucked.

        my ( $massaged_message_for_display, $content_type ) =
          $archive->massaged_msg_for_display( { -key => $id, -body_only => 1 } );

        my $show_iframe = $ls->param('html_archives_in_iframe') || 0;
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
            $header_from = $archive->get_header( -header => 'From', -key => $id );
            $orig_header_from = $header_from;

            # DEV: This logic should not be here...

            # DEV: This is stupid, and I don't think it's a great idea.
            $header_from = $archive->_parse_in_list_info( -data => $header_from );

            if ( $ls->param('archive_protect_email') eq 'recaptcha_mailhide' ) {
                $header_from = mailhide_encode($header_from);
            }
            elsif ( $ls->param('archive_protect_email') eq 'break' ) {
                $header_from = break_encode($header_from);
            }
            elsif ( $ls->param('archive_protect_email') eq 'spam_me_not' ) {
                $header_from = spam_me_not_encode($header_from);
            }
            else {
                $header_from = xss_filter($header_from);
            }

            $header_subject = $archive->get_header( -header => 'Subject', -key => $id );

            $header_subject =~ s/\r|\n/ /g;
            if ( !$header_subject ) {
                $header_subject = $DADA::Config::EMAIL_HEADERS{Subject};
            }

            ( $in_reply_to_id, $in_reply_to_subject ) = $archive->in_reply_to_info( -key => $id );

            # DEV: This is stupid, and I don't think it's a great idea.
            $header_subject      = $archive->_parse_in_list_info( -data => $header_subject );
            $in_reply_to_subject = $archive->_parse_in_list_info( -data => $in_reply_to_subject );

            # That. Sucked.
            $header_subject      = $header_subject;
            $in_reply_to_subject = $in_reply_to_subject;

        }

        my $attachments =
          ( $ls->param('display_attachments') == 1 )
          ? $archive->attachment_list($id)
          : [];

        # this is so atrocious.
        my $date = date_this(
            -Packed_Date   => $id,
            -Write_Month   => $ls->param('archive_show_month'),
            -Write_Day     => $ls->param('archive_show_day'),
            -Write_Year    => $ls->param('archive_show_year'),
            -Write_H_And_M => $ls->param('archive_show_hour_and_minute'),
            -Write_Second  => $ls->param('archive_show_second'),
        );

		my $show_gravatar        = 0; 
        my $gravatar_img_url     = undef;
        my $can_use_gravatar_url = 1; 
       
	    if ( $ls->param('enable_gravatars') ) {
            try { 
				require Gravatar::URL 
			} catch { 
				$can_use_gravatar_url = 0; 
			};
			if($can_use_gravatar_url == 1) {
				my $header_address = $archive->sender_address(
                     {
                            -id => $id,
                        }
                ); 
                $gravatar_img_url = gravatar_img_url(
                    {
                        -email                => $header_address,
                        -default_gravatar_url => $ls->param('default_gravatar_url'),
                    }
                );
            }
            else {
                $can_use_gravatar_url = 0;
            }
        }
		if($ls->param('enable_gravatars') ==1 
			&& $can_use_gravatar_url == 1
			&& defined(gravatar_img_url)
		) { 
			$show_gravatar = 1; 
		}
				
				
		

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'list_archive_screen.tmpl',
                -with   => 'list',
                -vars   => {
                    list      => $list,
                    list_name => $ls->param('list_name'),
                    id        => $id,

                    # DEV. OK - riddle ME why there's two of these...
                    header_subject => $header_subject,
                    subject        => $subject,

                    js_enc_subject      => js_enc($header_subject),
                    uri_encoded_subject => uriescape($header_subject),
                    uri_encoded_url  => uriescape( $DADA::Config::PROGRAM_URL . '/archive/' . $list . '/' . $id . '/' ),
                    archived_msg_url => $DADA::Config::PROGRAM_NAME . '/archive/' . $list . '/' . $id . '/',
                    massaged_msg_for_display => $massaged_message_for_display,
                    send_archive_success     => scalar $q->param('send_archive_success') ? $q->param('send_archive_success')
                    : undef,
                    send_archive_errors => scalar $q->param('send_archive_errors') ? $q->param('send_archive_errors')
                    : undef,
                    show_iframe     => $show_iframe,
                    discussion_list => ( $ls->param('group_list') == 1 ) ? 1
                    : 0,

                    header_from                   => $header_from,
                    in_reply_to_id                => $in_reply_to_id,
                    in_reply_to_subject           => xss_filter($in_reply_to_subject),
                    attachments                   => $attachments,
                    date                          => $date,
                    add_social_bookmarking_badges => $ls->param('add_social_bookmarking_badges'),
                    show_gravatar                 => $show_gravatar,  
					can_use_gravatar_url          => $can_use_gravatar_url,
                    gravatar_img_url              => $gravatar_img_url,
                    %$archive_widgets,

                },
                -list_settings_vars       => $ls->get,
                -list_settings_vars_param => { -list => $list, -dot_it => 1 },
		        -webify_and_santize_these => [qw(list_settings.discussion_pop_email list_settings.list_owner_email list_settings.info list_settings.privacy_policy )], 
                -list_settings_vars_param => { -list => $list, -dot_it => 1 },				
            }
        );

        require DADA::Logging::Clickthrough;
        my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
           $r->view_archive_log( { -mid => $id, } );
        if (  !$c->profile_on
            && $ls->param('archive_send_form') != 1
            && $ls->param('captcha_archive_send_form') != 1 )
        {
            $c->cache( 'archive/' . $list . '/' . $id . '.scrn', \$scrn );

        }
        return $scrn;
    }

}

sub archive_bare {

    my $self = shift;
    my $q    = $self->query();

    my $list = $q->param('list');

    if ( $q->param('admin') ) {
        my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
            -cgi_obj  => $q,
            -Function => 'view_archive'
        );
        if ( !$checksout ) { return $error_msg; }
        $list = $admin_list;
    }

    my $id = $q->param('id') || undef;

    if ( $c->is_cached( 'archive_bare.' . $list . '.' . $id . '.' . scalar($q->param('admin')) . '.scrn' ) ) {
        return $c->cached( 'archive_bare.' . $list . '.' . $id . '.' . scalar($q->param('admin')) . '.scrn' );
    }

    require DADA::MailingList::Archives;
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $la = DADA::MailingList::Archives->new( { -list => $list } );

    if ( !$q->param('admin') ) {
        if ( $ls->param('show_archives') == 0 ) {
            return user_error( { -list => $list, -error => "no_show_archives" } );
        }
        require DADA::Profile;
        my $prof = DADA::Profile->new( { -from_session => 1 } );
        my $allowed_to_view_archives = 1;
        if ($prof) {
            $allowed_to_view_archives = $prof->allowed_to_view_archives( { -list => $list, } );
        }

        if ( $allowed_to_view_archives == 0 ) {
            return user_error( { -list => $list, -error => "not_allowed_to_view_archives" } );
        }
    }
    if ( $la->check_if_entry_exists($id) <= 0 ) {
        return user_error( { -list => $list, -error => "no_archive_entry" } );
    }

    my $scrn = $la->massaged_msg_for_display( { -key => $id } );
    $c->cache( 'archive_bare.' . $list . '.' . $id . '.' . scalar($q->param('admin')) . '.scrn', \$scrn );
    return $scrn;

}

sub search_archive {

    my $self  = shift;
    my $q     = $self->query();
    my $list  = $q->param('list');
    my $email = $q->param('email');

    if ( check_if_list_exists( -List => $list ) <= 0 ) {
        return user_error( { -list => $list, -error => "no_list" } );
    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    if ( $ls->param('show_archives') == 0 ) {
        return user_error( { -list => $list, -error => "no_show_archives" } );
    }
    require DADA::Profile;
    my $prof = DADA::Profile->new( { -from_session => 1 } );
    my $allowed_to_view_archives = 1;
    if ($prof) {
        $allowed_to_view_archives = $prof->allowed_to_view_archives( { -list => $list, } );
    }

    if ( $allowed_to_view_archives == 0 ) {
        return user_error( { -list => $list, -error => "not_allowed_to_view_archives" } );
    }

    my $keyword = $q->param('keyword');
    $keyword = xss_filter($keyword);

    if ( $keyword =~ m/^[A-Za-z]+$/ ) {    # just words, basically.
        if (  !$c->profile_on
            && $c->is_cached( $list . '.search_archive.' . $keyword . '.scrn' ) )
        {
            return $c->cached( $list . '.search_archive.' . $keyword . '.scrn' );
        }
    }

    require DADA::MailingList::Archives;

    my $archive      = DADA::MailingList::Archives->new( { -list => $list } );
    my $entries      = $archive->get_archive_entries();
    my $ending       = "";
    my $count        = 0;
    my $ht_summaries = [];

    my $search_results = $archive->search_entries($keyword);

    if ( exists($search_results->[0]) && ( @$search_results[0] ne "" ) ) {

        $count  = $#{$search_results} + 1;
        $ending = 's'
          if exists($search_results->[1]);

        my $summaries = $archive->make_search_summary( $keyword, $search_results );

        for (@$search_results) {

            my ( $subject, $message, $format ) = $archive->get_archive_info($_);
            my $date = date_this(
                -Packed_Date   => $_,
                -Write_Month   => $ls->param('archive_show_month'),
                -Write_Day     => $ls->param('archive_show_day'),
                -Write_Year    => $ls->param('archive_show_year'),
                -Write_H_And_M => $ls->param('archive_show_hour_and_minute'),
                -Write_Second  => $ls->param('archive_show_second'),
            );

            push(
                @$ht_summaries,
                {
                    summary     => $summaries->{$_},
                    subject     => $archive->_parse_in_list_info( -data => $subject ),
                    date        => $date,
                    id          => $_,
                    PROGRAM_URL => $DADA::Config::PROGRAM_URL,
                    list        => uriescape($list),
                }
            );

        }
    }

    my $archive_subscribe_form = '';
    if ( $ls->param('hide_list') ne "1" ) {

        # DEV: This takes the cake for worst hack I have found... today.
        my $info = '<!-- tmpl_var list_settings.info -->';
        $info = DADA::Template::Widgets::screen(
            {
                -data                     => \$info,
                -list_settings_vars_param => { -list => $list, -dot_it => 1 },
                -webify_and_santize_these => [qw(list_settings.info)],
            }
        );

        unless ( $ls->param('archive_subscribe_form') == 0 ) {
            $archive_subscribe_form = DADA::Template::Widgets::subscription_form(
                {
                    -list       => $ls->param('list'),
                    -email      => $email,
                    -give_props => 0,
                }
            );
        }

    }

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'search_archive_screen.tmpl',
            -with   => 'list',
            -vars   => {
                list_name              => $ls->param('list_name'),
                uriescape_list         => uriescape($list),
                list                   => $list,
                count                  => $count,
                ending                 => $ending,
                keyword                => $keyword,
                summaries              => $ht_summaries,
                search_results         => $ht_summaries->[0] ? 1 : 0,
                subscription_form      => $archive_subscribe_form,
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );

    if ( !$c->profile_on && $keyword =~ m/^[A-Za-z]+$/ ) {    # just words, basically.
        $c->cache( $list . '.search_archive.' . $keyword . '.scrn', \$scrn );
    }
    return $scrn;

}

sub send_archive {

    my $self = shift;
    my $q    = $self->query();

    my $entry      = xss_filter( scalar $q->param('entry') );
    my $from_email = xss_filter( scalar $q->param('from_email') );
    my $to_email   = xss_filter( scalar $q->param('to_email') );
    my $note       = xss_filter( scalar $q->param('note') );
    my $list       = $q->param('list');

    my $errors = 0;

    my $list_exists = check_if_list_exists( -List => $list );

    if ( $list_exists <= 0 ) {
        return user_error( { -list => $list, -error => "no_list" } );
    }

    if ( check_for_valid_email($to_email) == 1 ) {
        $errors++;
    }

    if ( check_for_valid_email($from_email) == 1 ) {
        $errors++;
    }
    if ( $DADA::Config::REFERER_CHECK == 1 ) {
        if ( check_referer( $q->referer() ) != 1 ) {
            $errors++;
        }
    }
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::Profile;
    my $prof = DADA::Profile->new( { -from_session => 1 } );
    my $allowed_to_view_archives = 1;
    if ($prof) {
        $allowed_to_view_archives = $prof->allowed_to_view_archives( { -list => $list, } );
    }

    if ( $allowed_to_view_archives == 0 ) {
        return user_error( { -list => $list, -error => "not_allowed_to_view_archives" } );
    }

    # CAPTCHA STUFF

    my $captcha_fail    = 0;
    my $can_use_captcha = can_use_AuthenCAPTCHA();

    if ( $ls->param('captcha_archive_send_form') == 1 && $can_use_captcha == 1 ) {
        require DADA::Security::AuthenCAPTCHA;
        my $cap = DADA::Security::AuthenCAPTCHA->new;

        if ( xss_filter( scalar $q->param('recaptcha_response_field') ) ) {
            my $result = $cap->check_answer(
                $DADA::Config::RECAPTCHA_PARAMS->{private_key}, $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
                $q->param('recaptcha_challenge_field'),         $q->param('recaptcha_response_field')
            );

            if ( $result->{is_valid} != 1 ) {
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

    if ( $ls->param('archive_send_form') != 1 ) {
        $errors++;
    }

    if ( $errors > 0 ) {

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::PROGRAM_URL
              . '?flavor=archive&list='
              . $list . '&id='
              . $entry
              . '&send_archive_errors='
              . $errors
              . '&captcha_fail='
              . $captcha_fail );

    }
    else {

        require DADA::MailingList::Archives;

        my $archive = DADA::MailingList::Archives->new( { -list => $list } );

        if ( $entry =~ /newest/i ) {
            $entry = $archive->newest_entry;
        }
        elsif ( $entry =~ /oldest/i ) {
            $entry = $archive->oldest_entry;
        }

        my $archive_message_url = $DADA::Config::PROGRAM_URL . '/archive/' . $list . '/' . $entry . '/';

        my ( $subject, $message, $format, $raw_msg ) = $archive->get_archive_info($entry);
        chomp($subject);

        # DEV: This is stupid, and I don't think it's a great idea.
        $subject = $archive->_parse_in_list_info( -data => $subject );
        ### /

        require MIME::Lite;

        # DEV: This should really be moved to DADA::App::Messages...
        my $msg = MIME::Lite->new(
            From    => '"<!-- tmpl_var list_settings.list_name -->" <' . $from_email . '>',
            To      => '"<!-- tmpl_var list_settings.list_name -->" <' . $to_email . '>',
            Subject => $ls->param('send_archive_message_subject'),
            Type    => 'multipart/mixed',
        );

        my $pt = MIME::Lite->new(
            Type     => 'text/plain',
            Data     => $ls->param('send_archive_message'),
            Encoding => $ls->param('plaintext_encoding')
        );

        my $html = MIME::Lite->new(
            Type     => 'text/html',
            Data     => $ls->param('send_archive_message_html'),
            Encoding => $ls->param('html_encoding'),
        );

        my $ma = MIME::Lite->new( Type => 'multipart/alternative' );
        $ma->attach($pt);
        $ma->attach($html);

        $msg->attach($ma);

        my $a_msg;

        #... sort of weird.
        if ($raw_msg) {

            $a_msg = MIME::Lite->new(
                Type        => 'message/rfc822',
                Disposition => "inline",
                Data        => $archive->massage_msg_for_resending( -key => $entry ),
            );

        }
        else {

            $a_msg = MIME::Lite->new(
                Type        => 'message/rfc822',
                Disposition => "inline",
                Type        => $format,
                Data        => $message
            );
        }

        $msg->attach($a_msg);

        require DADA::App::FormatMessages;
        my $fm = DADA::App::FormatMessages->new( -List => $list );
        $fm->use_email_templates(0);
        $fm->use_header_info(1);

        my $msg_a_s = safely_encode( $msg->as_string );
        my ($email_str) = $fm->format_message( -msg => $msg_a_s, );

        my ( $e_name, $e_domain ) = split( '@', $to_email, 2 );
        my $entity = $fm->email_template(
            {
                -entity                   => $fm->get_entity( { -data => $email_str } ),
                -list_settings_vars_param => { -list          => $list, },
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

        $msg = safely_decode( $entity->as_string );
        my ( $header_str, $body_str ) = split( "\n\n", $msg, 2 );

        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new(
            {
                -list   => $list,
                -ls_obj => $ls,
            }
        );

        $mh->send( $mh->return_headers($header_str), Body => $body_str, );

        require DADA::Logging::Clickthrough;
        my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
           $r->forward_to_a_friend_log( { -mid => $entry, } );

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::PROGRAM_URL
              . '?flavor=archive&list='
              . $list . '&id='
              . $entry
              . '&send_archive_success=1' );

    }
}

sub archive_rss {

    my $self = shift;
    my $q    = $self->query();

    my %args = (
        -type => 'rss',
        @_
    );
    my $list = $q->param('list');

    my $list_exists = check_if_list_exists( -List => $list );

    if ( $list_exists == 0 ) {

    }
    else {

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        if ( $ls->param('show_archives') == 0 ) {

        }
        else {

            require DADA::Profile;
            my $prof = DADA::Profile->new( { -from_session => 1 } );
            my $allowed_to_view_archives = 1;
            if ($prof) {
                $allowed_to_view_archives = $prof->allowed_to_view_archives( { -list => $list, } );
            }

            if ( $allowed_to_view_archives == 0 ) {
                return '';
            }

            if ( $ls->param('publish_archives_rss') == 0 ) {

            }
            else {

                if ( $args{-type} eq 'rss' ) {

                    if ( $c->is_cached( 'archive_rss/' . $list ) ) {
                        return $c->cached( 'archive_rss/' . $list . '.scrn' );
                    }
                    require DADA::MailingList::Archives;
                    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
                    my $scrn = $archive->rss_index();
                    $c->cache( 'archive_rss/' . $list . '.scrn', \$scrn );
                    my $headers = { -type => 'application/xml' };

                    $self->header_props(%$headers);
                    return $scrn;

                }
                elsif ( $args{-type} eq 'atom' ) {
                    if ( $c->is_cached( 'archive_atom/' . $list ) ) {
                        return $c->cached( 'archive_atom/' . $list . '.scrn' );
                    }
                    else {
                        require DADA::MailingList::Archives;
                        my $archive = DADA::MailingList::Archives->new( { -list => $list } );
                        my $scrn = $archive->atom_index();
                        $c->cache( 'archive_atom/' . $list . '.scrn', \$scrn );
                        my $headers = { -type => 'application/xml' };
                        $self->header_props(%$headers);
                        return $scrn;
                    }
                }
                else {
                    warn "wrong type of feed asked for: " . $args{-type} . ' - ' . $!;
                }
            }
        }
    }
}

sub archive_atom {

    my $self = shift;
    my $q    = $self->query();
    return $self->archive_rss( -type => 'atom' );
}

sub email_password {

    my $self = shift;
    my $q    = $self->query();
    my $list = $q->param('list');

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::Security::Password;

    if (   ( $ls->param('pass_auth_id') ne "" )
        && ( defined( $ls->param('pass_auth_id') ) )
        && ( $q->param('pass_auth_id') eq $ls->param('pass_auth_id') ) )
    {

        my $new_password = DADA::Security::Password::generate_password();
        my $new_encrypt  = DADA::Security::Password::encrypt_passwd($new_password);

        $ls->save(
            {
                password     => $new_encrypt,
                pass_auth_id => ''
            }
        );

        require DADA::App::ReadEmailMessages;
        my $rm       = DADA::App::ReadEmailMessages->new;
        my $msg_data = $rm->read_message('list_password_reset_message.eml');

        require DADA::App::Messages;
        DADA::App::Messages::send_generic_email(
            {
                -list    => $list,
                -headers => {
                    From => '"'
                      . escape_for_sending( $ls->param('list_name') ) . '" <'
                      . $ls->param('list_owner_email') . '>',
                    To => '"List Owner for: '
                      . escape_for_sending( $ls->param('list_name') ) . '" <'
                      . $ls->param('list_owner_email') . '>',
                    Subject => $msg_data->{subject},
                },
                -body        => $msg_data->{plaintext_body},
                -tmpl_params => {
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                    -vars => { new_password => $new_password, },
                },
            }
        );

        require DADA::Logging::Usage;
        my $log = new DADA::Logging::Usage;
        $log->mj_log( $list, 'List Password Reset', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}" )
          if $DADA::Config::LOG{list_lives};

        $self->header_type('redirect');
        $self->header_props(
            -url => $DADA::Config::S_PROGRAM_URL . '?flavor=' . $DADA::Config::SIGN_IN_FLAVOR_NAME . '&list=' . $list );
    }
    else {

        if ( can_use_AuthenCAPTCHA() ) {
            require DADA::Security::AuthenCAPTCHA;
            my $cap = DADA::Security::AuthenCAPTCHA->new;

            my $captcha_worked;

            my $result = $cap->check_answer(
                $DADA::Config::RECAPTCHA_PARAMS->{private_key}, $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
                $q->param('recaptcha_challenge_field'),         $q->param('recaptcha_response_field')
            );
            if ( $result->{is_valid} == 1 ) {
                $captcha_worked = 1;
            }
            else {
                $captcha_worked = 0;
            }

            if ( $captcha_worked == 0 ) {
				
				my $add_vars = {}; 
		        my $can_use_captcha = 0;
		        my $CAPTCHA_string  = '';
		        my $cap; 
		        if ( can_use_AuthenCAPTCHA() == 1 ) {
		            require DADA::Security::AuthenCAPTCHA;
		            $cap    = DADA::Security::AuthenCAPTCHA->new;
		            $CAPTCHA_string = $cap->get_html( $DADA::Config::RECAPTCHA_PARAMS->{public_key} );
		            $add_vars->{captcha_string}  = $CAPTCHA_string;
		            $add_vars->{can_use_captcha} = 1;
		            $add_vars->{selected_list}   = $list;
		        }
				
				require DADA::Template::Widgets; 
                return DADA::Template::Widgets::admin(
					{ 
			            -cgi_obj      => $q,
						-vars         => {
							selected_list   => $list, 
							invalid_captcha => 1, 
							errors => [{error => 'invalid_password'}],
							%$add_vars,
						}
					}
				); 
            }
        }

        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new(
            {
                -list   => $list,
                -ls_obj => $ls,
            }
        );

        my $random_string = DADA::Security::Password::generate_rand_string();

        $ls->save( { pass_auth_id => $random_string, } );

        require DADA::App::ReadEmailMessages;
        my $rm       = DADA::App::ReadEmailMessages->new;
        my $msg_data = $rm->read_message('list_password_reset_confirmation_message.eml');

        require DADA::App::Messages;
        DADA::App::Messages::send_generic_email(
            {
                -list    => $list,
                -headers => {
                    From => '"'
                      . escape_for_sending( $ls->param('list_name') ) . '" <'
                      . $ls->param('list_owner_email') . '>',
                    To => '"List Owner for: '
                      . escape_for_sending( $ls->param('list_name') ) . '" <'
                      . $ls->param('list_owner_email') . '>',
                    Subject => $msg_data->{subject},
                },
                -body        => $msg_data->{plaintext_body},
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
        $log->mj_log(
            $list,
            'Sent Password Change Confirmation',
            "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}"
        ) if $DADA::Config::LOG{list_lives};

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'list_password_confirmation_screen.tmpl',
                -with   => 'list',
                -vars   => {
                    REMOTE_HOST => $ENV{REMOTE_HOST},
                    REMOTE_ADDR => $ENV{REMOTE_ADDR},
                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            },
        );
        return $scrn;
    }
}

sub login {

    my $self = shift;
    my $q    = $self->query();

    my $referer        = $q->param('referer')        || $DADA::Config::DEFAULT_ADMIN_SCREEN;
    my $admin_password = $q->param('admin_password') || "";
    my $admin_list     = $q->param('admin_list')     || "";
    my $auth_state     = $q->param('auth_state')     || undef;

    my $try_referer = $referer;

    $try_referer =~ s/(^http\:\/\/|^https\:\/\/)//;
    $try_referer =~ s/^www//;

    my $reg_try_referer = quotemeta($try_referer);
    if ( $DADA::Config::PROGRAM_URL =~ m/$reg_try_referer$/ ) {
        $referer = $DADA::Config::DEFAULT_ADMIN_SCREEN;
    }

    my $list = $admin_list;

    if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
        require DADA::Security::SimpleAuthStringState;
        my $sast = DADA::Security::SimpleAuthStringState->new;
        if ( $sast->check_state($auth_state) != 1 ) {
            return user_error(
                {
                    -list  => $list,
                    -error => 'incorrect_login_url',
                }
            );
        }
    }

    my $cookie;

    if ( check_if_list_exists( -List => $list ) >= 1 ) {

        require DADA::Security::Password;

        my $dumb_cookie = $q->cookie(
            -name  => 'blankpadding',
            -value => 'blank',
            %DADA::Config::COOKIE_PARAMS,
        );

        require DADA::App::Session;
        my $dada_session = DADA::App::Session->new();

        if ( $dada_session->logged_into_diff_list( -cgi_obj => $q ) != 1 ) {

            my $login_cookies = $dada_session->login_cookies(
                -cgi_obj  => $q,
                -list     => $list,
                -password => $admin_password
            );

			# not cached atm
            # require DADA::App::ScreenCache;
            # my $c = DADA::App::ScreenCache->new;
            # $c->remove( 'login_switch_widget.' . $list . '.scrn' );

            if ( $DADA::Config::LOG{logins} ) {
                require DADA::Logging::Usage;
                my $log = new DADA::Logging::Usage;
                my $rh  = $ENV{REMOTE_HOST} || '';
                my $ra  = $ENV{REMOTE_ADDR} || '';

                $log->mj_log( $admin_list, 'login', 'remote_host:' . $rh . ', ip_address:' . $ra );
            }

            my $cookies = [ $dumb_cookie, @$login_cookies ];
            my $headers = {
                -cookie  => $cookies,
                -nph     => $DADA::Config::NPH,
                -Refresh => '0; URL=' . $referer
            };
			
		    my $scrn    = DADA::Template::Widgets::wrap_screen(
		        {
		            -with           => 'list',
					-screen         => 'logging_in_screen.tmpl',
                    -wrapper_params => {
                       -Use_Custom => 0,
                    },
		            -vars => {
						show_profile_widget => 0,
		            	referer             => $referer, 
					},
		        }
		    );
			
            $dada_session->remove_old_session_files();

            $self->header_props(%$headers);
            $scrn;
        }
        else {

            return user_error(
                {
                    -list  => $list,
                    -error => "logged_into_different_list",
                }
            );
        }

    }
    else {
        return user_error(
            {
                -list  => $list,
                -error => "no_list",
            }
        );
    }
}

sub logout {

    my $self = shift;

    my $q = $self->query();

    my $headers = {};
    my $body    = undef;

    my %args = (
        -redirect               => 1,
        -redirect_url           => $DADA::Config::DEFAULT_LOGOUT_SCREEN,
        -no_list_security_check => 0,
        @_
    );

    my $admin_list;
    my $root_login;

    my $list_exists = check_if_list_exists( -List => $admin_list );

    # I don't quite even understand why there's this check...
    if ( $args{-no_list_security_check} == 0 ) {
        if ( $list_exists == 1 ) {
            my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
                -cgi_obj  => $q,
                -Function => 'logout'
            );
            if ( !$checksout ) { return $error_msg; }
        }
    }

	# not cached atm
    #require DADA::App::ScreenCache;
    #my $c = DADA::App::ScreenCache->new;
    #$c->remove( 'login_switch_widget.' . $admin_list . '.scrn' );

    my $l_list = $admin_list;

    my $location = $args{-redirect_url};

    if ( $q->param('login_url') ) {
        $location = $q->param('login_url');
    }

    if ( $DADA::Config::LOG{logins} != 0 ) {

        require DADA::Logging::Usage;
        my $log = new DADA::Logging::Usage;
        $log->mj_log( $l_list, 'logout', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}" );

    }

    my $logout_cookie;

    require DADA::App::Session;
    my $dada_session = DADA::App::Session->new( -List => $l_list );
    $logout_cookie = $dada_session->logout_cookie( -cgi_obj => $q );

    if ( $args{-redirect} == 1 ) {

        $headers = {
            -COOKIE  => $logout_cookie,
            -nph     => $DADA::Config::NPH,
            -Refresh => '0; URL=' . $location,
        };

	    my $scrn    = DADA::Template::Widgets::wrap_screen(
	        {
	            -with           => 'list',
				-screen         => 'logging_out_screen.tmpl',
                -wrapper_params => {
                   -Use_Custom => 0,
                },
	            -vars => {
					show_profile_widget => 0,
	            	location            => $location, 
				},
	        }
	    );
		          
        # Probably not setting up the header_props here, yey?
        $self->header_props(%$headers);
        return ($headers, $scrn);
    }
    else {
        return $logout_cookie;    #DEV: not sure about this one...
    }

}

sub log_into_another_list {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'log_into_another_list'
    );
    if ( !$checksout ) { return $error_msg; }

    $self->logout( -redirect_url => $DADA::Config::PROGRAM_URL . '?flavor=' . $DADA::Config::SIGN_IN_FLAVOR_NAME, );

}

sub change_login {

    my $self = shift;
    my $q    = $self->query();

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'change_login'
    );
    if ( !$checksout ) { return $error_msg; }

    die "only for root logins!"
      if !$root_login;

    require DADA::App::Session;
    my $dada_session = DADA::App::Session->new();

    my $change_to_list = $q->param('change_to_list');
    my $location       = $q->param('location');

    $q->delete_all();

    # DEV: Ooh. This is messy.
    $location =~ s/(\;|\&)done\=1$//;
    $location =~ s/(\;|\&)delete_email_count\=(.*?)$//;
    $location =~ s/(\;|\&)email_count\=(.*?)$//;

    $location =~ s/f\=add_email\&fn\=(.*?)(\&)/f\=add\2/;

    my $new_cookie = $dada_session->change_login( -cgi_obj => $q, -list => $change_to_list );

	# not cached atm
    # require DADA::App::ScreenCache;
    # my $c = DADA::App::ScreenCache->new;
    # $c->remove( 'login_switch_widget.' . $change_to_list . '.scrn' );

    my $headers = {
        -cookie  => [$new_cookie],
        -nph     => $DADA::Config::NPH,
        -Refresh => '0; URL=' . $location
    };

    my $scrn    = DADA::Template::Widgets::wrap_screen(
        {
            -with           => 'list',
			-screen         => 'logging_switch_screen.tmpl',
            -wrapper_params => {
               -Use_Custom => 0,
            },
            -vars => {
				show_profile_widget => 0,
            	location            => $location, 
			},
        }
    );
	
	
    $self->header_props(%$headers);
    return $scrn;
}

sub remove_subscribers {

    my $self = shift;
    my $q    = $self->query();
    my $type = $q->param('type');

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list           = $admin_list;
    my $return_to      = $q->param('return_to') || '';
    my $return_address = $q->param('return_address') || '';
    my @address        = $q->multi_param('address');

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my ( $d_count, $bl_count ) = $lh->admin_remove_subscribers(
        {
            -addresses        => [@address],
            -type             => $type,
            -validation_check => 0,
        }
    );

    my $flavor_to_return_to = 'view_list';
    if ( $return_to eq 'membership' ) {    # or, others...
        $flavor_to_return_to = $return_to;
    }

    my $qs =

      'flavor='
      . $flavor_to_return_to
      . '&delete_email_count='
      . $d_count
      . '&type='
      . $type
      . '&black_list_add='
      . $bl_count;

    if ( $return_to eq 'membership' ) {
        $qs .= '&email=' . $return_address;
    }

    $self->header_type('redirect');
    $self->header_props( -url => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
}

sub process_bouncing_addresses {

    my $self    = shift;
    my $q       = $self->query();
    my @address = $q->multi_param('address');
    my $type    = $q->param('type');
    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list'
    );
    if ( !$checksout ) { return $error_msg; }

    my $list = $admin_list;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $return_to      = $q->param('return_to')      || 'view_list';
    my $return_address = $q->param('return_address') || undef;

    if ( $q->param('process') =~ m/remove/i ) {
        my ( $d_count, $bl_count ) = $lh->admin_remove_subscribers(
            {
                -addresses => [@address],
                -type      => 'bounced_list',
            }
        );
        my $uri =
            $DADA::Config::S_PROGRAM_URL
          . '?flavor='
          . $return_to
          . '&bounced_list_removed_from_list='
          . $d_count
          . '&type='
          . $type
          . '&black_list_add='
          . $bl_count
          . '&email='
          . $return_address;

        $self->header_type('redirect');
        $self->header_props( -url => $uri );

    }
    elsif ( $q->param('process') =~ m/move/i ) {

        my $m_count = 0;

        for my $address (@address) {
            $lh->move_subscriber(
                {
                    -email => $address,
                    -from  => 'bounced_list',
                    -to    => 'list',
                    -mode  => 'writeover',
                }
            );
            $m_count++;
        }

        # maybe if the bounce_list num_subscribers count is 0, we just go to the view_list screen.
        my $uri =
            $DADA::Config::S_PROGRAM_URL
          . '?flavor='
          . $return_to
          . '&type='
          . $type
          . '&bounced_list_moved_to_list_count='
          . $m_count
          . '&email='
          . $return_address;
        $self->header_type('redirect');
        $self->header_props( -url => $uri );

    }
    else {
        croak "I'm not sure what I'm supposed to do!";
    }
}

sub find_attachment_type {

    my $self = shift;
    my $q    = $self->query();

    my $filename = shift;
    my $a_type;

    my $attach_name = $filename;
    $attach_name =~ s!^.*(\\|\/)!!;
    $attach_name =~ s/\s/%20/g;

    my $file_ending = $attach_name;
    $file_ending =~ s/.*\.//;

    require MIME::Types;
    require MIME::Type;

    if ( ( $MIME::Types::VERSION >= 1.005 ) && ( $MIME::Type::VERSION >= 1.005 ) ) {
        my ( $mimetype, $encoding ) = MIME::Types::by_suffix($filename);
        $a_type = $mimetype
          if ( $mimetype && $mimetype =~ /^\S+\/\S+$/ );    ### sanity check
    }
    else {
        if ( exists( $DADA::Config::MIME_TYPES{ '.' . lc($file_ending) } ) ) {
            $a_type = $DADA::Config::MIME_TYPES{ '.' . lc($file_ending) };
        }
        else {
            $a_type = $DADA::Config::DEFAULT_MIME_TYPE;
        }
    }
    if ( !$a_type ) {
        warn "attachment MIME Type never figured out, letting MIME::Lite handle this...";
        $a_type = 'AUTO';
    }

    return $a_type;
}

sub file_upload {

    my $self = shift;
    my $q    = $self->query();

    my $upload_file = shift;
    require CGI;
    my $fu   = CGI->new;
    $fu->charset($DADA::Config::HTML_CHARSET);
    my $file = $fu->param($upload_file);
    if ( $file ne "" ) {
        my $fileName = $file;
        $fileName =~ s!^.*(\\|\/)!!;

        $fileName = uriescape($fileName);

        my $outfile = make_safer( $DADA::Config::TMP . '/' . time . '_' . $fileName );

        open( OUTFILE, '>' . $outfile )
          or warn( "can't write to '" . $outfile . "' because: $!" );
        while ( my $bytesread = read( $file, my $buffer, 1024 ) ) {
            print OUTFILE $buffer;
        }
        close(OUTFILE);
        chmod( $DADA::Config::FILE_CHMOD, $outfile );
        return $outfile;
    }

}

sub pass_gen {

    my $self = shift;
    my $q    = $self->query();

    my $pw = $q->param('pw');

    if ( !$pw ) {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'pass_gen_screen.tmpl',
                -with   => 'list',
                -expr   => 1,
                -vars   => {},
            }
        );
        return $scrn;

    }
    else {

        require DADA::Security::Password;
        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'pass_gen_process_screen.tmpl',
                -with   => 'list',
                -expr   => 1,
                -vars   => { encrypted_password => DADA::Security::Password::encrypt_passwd($pw), },
            }
        );
        return $scrn;
    }

}

sub setup_info {

    my $self = shift;
    my $q    = $self->query();

    my $root_password = $q->param('root_password') || '';

    my $from_control_panel = 0;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'setup_info',
    );
    my $list = undef;
    if ( $checksout == 1 && $root_password eq '' ) {
        $from_control_panel = 1;
        $list               = $admin_list;
    }

    if ( $checksout == 1 || root_password_verification($root_password) == 1 ) {

        # If we have a .dada_config file, this is a contemporary installation, we'll say.
        my $c_install = 0;

        # Not sure why I should do this check at all, if the "auto" dealy
        # could be set, anyways,
        if ( ( -e $DADA::Config::PROGRAM_CONFIG_FILE_DIR && -d $DADA::Config::PROGRAM_CONFIG_FILE_DIR )
            || $DADA::Config::PROGRAM_CONFIG_FILE_DIR eq 'auto' )
        {
            if ( -e $DADA::Config::CONFIG_FILE ) {
                $c_install = 1;
            }
        }

        my $config_file_contents = undef;
        if ( -e $DADA::Config::CONFIG_FILE ) {
            $config_file_contents = DADA::Template::Widgets::_slurp($DADA::Config::CONFIG_FILE);
        }
        my $config_pm_file_contents = DADA::Template::Widgets::_slurp('DADA/Config.pm');

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
            if ( $sigil eq '$' ) {
                $var_val = Data::Dumper::Dumper( ${ $DADA::Config::{$_} } );
            }
            elsif ( $sigil eq '@' ) {
                $var_val = Data::Dumper::Dumper( \@{ $DADA::Config::{$_} } );
            }
            elsif ( $sigil eq '%' ) {
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

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'setup_info_screen.tmpl',
                (
                    $from_control_panel == 1
                    ? (
                        -with           => 'admin',
                        -wrapper_params => {
                            -Root_Login => $root_login,
                            -List       => $list,
                        },
                      )
                    : ( -with => 'list', )
                ),
                -vars => {
                    FILES                   => $DADA::Config::FILES,
                    PROGRAM_ROOT_PASSWORD   => $DADA::Config::PROGRAM_ROOT_PASSWORD,
                    MAILPROG                => $DADA::Config::MAILPROG,
                    PROGRAM_CONFIG_FILE_DIR => $DADA::Config::PROGRAM_CONFIG_FILE_DIR,
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
        return $scrn;

    }
    else {

        if ( $from_control_panel == 1 ) {

            # just doin' this again, w/o the manual override:
            my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
                -cgi_obj  => $q,
                -Function => 'setup_info',
            );
            if ( !$checksout ) { return $error_msg; }
        }
        else {

            my $guess = $DADA::Config::PROGRAM_URL;
            $guess = $q->script_name()
              if $DADA::Config::PROGRAM_URL eq ""
              || $DADA::Config::PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi';    # default.

            my $incorrect_root_password = $root_password ? 1 : 0;

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
            return $scrn;
        }

    }

}

sub reset_cipher_keys {

    my $self = shift;
    my $q    = $self->query();

    my $root_password   = $q->param('root_password');
    my $root_pass_check = root_password_verification($root_password);

    if ( $root_pass_check == 1 ) {
        require DADA::Security::Password;
        my @lists = available_lists();

        require DADA::MailingList::Settings;

        for (@lists) {
            my $ls = DADA::MailingList::Settings->new( { -list => $_ } );
            $ls->save( { cipher_key => DADA::Security::Password::make_cipher_key() } );
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            -screen => 'reset_cipher_keys_process.tmpl',
            -with   => 'list',
        );
        return $scrn;

    }
    else {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            -screen => 'reset_cipher_keys.tmpl',
            -with   => 'list',
        );
        return $scrn;
    }

}

sub restore_lists {

    my $self    = shift;
    my $q       = $self->query();
    my $process = $q->param('process');

    if ( root_password_verification( $q->param('root_password') ) ) {

        require DADA::MailingList::Settings;

        require DADA::MailingList::Archives;

        # No SQL veresion, so don't worry about handing over the dbi handle...

        my @lists = available_lists();

        if ( $process eq 'true' ) {

            my $report = '';

            my %restored;
            for my $r_list (@lists) {
                if (   $q->param( 'restore_' . $r_list . '_settings' )
                    && $q->param( 'restore_' . $r_list . '_settings' ) == 1 )
                {
                    my $ls = DADA::MailingList::Settings->new( { -list => $r_list } );
                    $ls->{ignore_open_db_error} = 1;
                    $report .= $ls->restoreFromFile( $q->param( 'settings_' . $r_list . '_version' ) );
                }
            }
            for my $r_list (@lists) {
                if (   $q->param( 'restore_' . $r_list . '_archives' )
                    && $q->param( 'restore_' . $r_list . '_archives' ) == 1 )
                {
                    my $ls = DADA::MailingList::Settings->new( { -list => $r_list } );
                    $ls->{ignore_open_db_error} = 1;
                    my $la = DADA::MailingList::Archives->new( { -list => $r_list, -ignore_open_db_error => 1 } );
                    $report .= $la->restoreFromFile( $q->param( 'archives_' . $r_list . '_version' ) );
                }
            }

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'restore_lists_complete.tmpl',
                    -with   => 'list',
                    -wrapper_params => {
                       -Use_Custom => 0,
                    },
                }
            );
            return $scrn;

        }
        else {

            my $backup_hist = {};
            for my $l (@lists) {
                my $ls = DADA::MailingList::Settings->new( { -list => $l } );
                $ls->{ignore_open_db_error} = 1;
                my $la =
                  DADA::MailingList::Archives->new( { -list => $l, -ignore_open_db_error => 1 } )
                  ;    #yeah, it's diff from MailingList::Settings - I'm stupid.

                $backup_hist->{$l}->{settings} = $ls->backupDirs
                  if $ls->uses_backupDirs;
                $backup_hist->{$l}->{archives} = $la->backupDirs
                  if $la->uses_backupDirs;

            }

            my $restore_list_options = '';

            #    labels are for the popup menus, that's it    #
            my $labels = {};

            #use Data::Dumper;
            for my $l ( sort keys %$backup_hist ) {

                for my $bu ( @{ $backup_hist->{$l}->{settings} } ) {
                    my ( $time_stamp, $appended ) = ( '', '' );
                    if ( $bu->{dir} =~ /\./ ) {
                        ( $time_stamp, $appended ) =
                          split( /\./, $bu->{dir}, 2 );
                    }
                    else {
                        $time_stamp = $bu->{dir};
                    }

                    $labels->{$l}->{settings}->{ $bu->{dir} } =
                      scalar( localtime($time_stamp) ) . ' (' . $bu->{count} . ' entries)';

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
                      scalar( localtime($time_stamp) ) . ' (' . $bu->{count} . ' entries)';

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
                      scalar( localtime($time_stamp) ) . ' (' . $bu->{count} . ' entries)';

                }
            }

            #

            for my $f_list ( keys %$backup_hist ) {

                $restore_list_options .= $q->start_table( { -cellpadding => 5 } );
                $restore_list_options .= $q->h3($f_list);

                $restore_list_options .= $q->Tr(
                    $q->td(
                        { -valign => 'top' },
                        [ ( $q->p( $q->strong('Restore?') ) ), ( $q->p( $q->strong('Backup Version*:') ) ), ]
                    )
                );

                for my $t ( 'settings', 'archives', 'schedules' ) {

                    #		require Data::Dumper;
                    #		die Data::Dumper::Dumper(%labels);
                    my $vals = [];
                    for my $d ( @{ $backup_hist->{$f_list}->{$t} } ) {
                        push( @$vals, $d->{dir} );
                    }

                    $restore_list_options .= $q->Tr(
                        $q->td(
                            [
                                (
                                    $q->p(
                                        $q->checkbox(
                                            -name  => 'restore_' . $f_list . '_' . $t,
                                            -id    => 'restore_' . $f_list . '_' . $t,
                                            -value => 1,
                                            -label => ' ',
                                        ),
                                        '<label for="' . 'restore_' . $f_list . '_' . $t . '">' . $t . '</label>'
                                    )
                                ),

                                ( scalar @{ $backup_hist->{$f_list}->{$t} } )
                                ? (

                                    (
                                        '<p>' . 
										HTML::Menu::Select::popup_menu(
                                                { 
													name    => $t . '_' . $f_list . '_version',
                                                	values  => $vals,
                                                	labels  => $labels->{$f_list}->{$t},
												}
											) . '</p>'
                                    ),

                                  )
                                : (

                                    (
                                        $q->p( { -class => 'error' }, '-- No Backup Information Found --' ),
                                        $q->hidden(
                                            -name  => $t . '_' . $f_list . '_version',
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

            my $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'restore_lists_options_screen.tmpl',
                    -with   => 'list',
                    -wrapper_params => {
                       -Use_Custom => 0,
                    },
                    -vars   => {
                        restore_list_options => $restore_list_options,
                        root_password        => xss_filter( scalar $q->param('root_password') ),
                    }
                }
            );
            return $scrn;

        }

    }
    else {

        my $scrn = DADA::Template::Widgets::wrap_screen( { -screen => 'restore_lists_screen.tmpl', -with => 'list', } );
        return $scrn;
    }

}

sub subscription_form_html {

    my $self                 = shift;
    my $q                    = $self->query();
    my $list                 = $q->param('list');
    my $subscription_form_id = $q->param('subscription_form_id')
      || 'jquery_subscription_form';

    my $subscription_form = DADA::Template::Widgets::subscription_form(
        {
            -subscription_form_id => $subscription_form_id,
            -show_fieldset        => 0,
            -magic_form           => 0,
            ( defined($list) ? ( -list => $list, ) : () )
        }
    );
    if ( $q->param('_method') eq 'GET' && $q->param('callback') ) {

        my $headers = {
            -type                          => 'application/javascript',
            '-Access-Control-Allow-Origin'  => '*',
            '-Access-Control-Allow-Methods' => 'POST',
            '-Cache-Control'               => 'no-cache, must-revalidate',
            -expires                       => 'Mon, 26 Jul 1997 05:00:00 GMT',
        };

        my $callback = xss_filter( strip( $q->url_param('callback') ) );
        require JSON;
        my $json = JSON->new->allow_nonref;
        my $r = $json->encode( { subscription_form => $subscription_form } );

        $self->header_props(%$headers);
        return $callback . '(' . $r . ');';
    }
    else {
        return $subscription_form;
    }
}

sub subscriber_help {

    my $self = shift;
    my $q    = $self->query();
    my $list = $q->param('list');

    if ( !$list ) {
        return $self->default();
    }

    if ( check_if_list_exists( -List => $list ) == 0 ) {
        undef($list);
        return $self->default();
    }

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'subscriber_help_screen.tmpl',
            -with   => 'list',
            -vars   => {
                list             => $list,
                list_name        => $ls->param('list_name'),
                list_owner_email => spam_me_not_encode( $ls->param('list_owner_email') ),
            }
        }
    );
    return $scrn;

}

sub show_img {

    my $self = shift;
    my $q    = $self->query();

    $self->file_attachment( -inline_image_mode => 1 );
}

sub file_attachment {

    my $self = shift;
    my $q    = $self->query();
    my $list = $q->param('list');

    # Weird:
    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_email',
    );

    #if(!$checksout){ return $error_msg; }

    my %args = ( 
        -inline_image_mode => 0, 
        @_ 
    );

    my $id = $q->param('id') || undef;

    if ( check_if_list_exists( -List => $list ) == 1 ) {

        require DADA::MailingList::Settings;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        if ( $ls->param('show_archives') == 1 || $checksout == 1 ) {

            if ( $ls->param('display_attachments') == 1 || $checksout == 1 ) {

                require DADA::MailingList::Archives;

                my $la = DADA::MailingList::Archives->new( { -list => $list } );

                if ( $la->can_display_attachments ) {

                    if ( $la->check_if_entry_exists( $q->param('id') ) ) {

                        if ( $args{-inline_image_mode} == 1 ) {

                          #  if (
                          #      $c->is_cached(
                          #          'view_inline_attachment.' . $list . '.' . $id . '.' . scalar($q->param('cid')) . '.cid'
                          #      )
                          #    )
                          #  {
                          #      return $c->cached(
                          #          'view_inline_attachment.' . $list . '.' . $id . '.' . scalar($q->param('cid')) . '.cid' );
                          #  }
                            my ($h, $scrn) = $la->view_inline_attachment(
                                -id  => scalar $q->param('id'),
                                -cid => scalar $q->param('cid')
                            );

                            # Bettin' that it's binary (or at least, unencoded)
                           # $c->cache( 'view_inline_attachment.' . $list . '.' . $id . '.' . scalar($q->param('cid')) . '.cid',
                           #        \$scrn );
                           #    return $scrn;
                           
                           $self->header_props($h);
                           return $scrn; 

                        }
                        else {
                            #if (
                            #    $c->is_cached(
                            #        'view_file_attachment.' . $list . '.' . $id . '.' . scalar($q->param('filename'))
                            #    )
                            #  )
                            #{
                            #    return $c->cached(
                            #        'view_file_attachment.' . $list . '.' . $id . '.' . scalar($q->param('filename') ));
                            #}
                            #else {
                                
                                my ($h, $scrn) = $la->view_file_attachment(
                                    -id       => scalar $q->param('id'),
                                    -filename => scalar $q->param('filename')
                                );
                                #$c->cache( 'view_file_attachment.' . $list . '.' . $id . '.' . scalar($q->param('filename')),
                                #    \$scrn );

                   # Binary. Well, actually, *probably* - how would you figure out the content-type of an attached file?
                            $self->header_props($h);
                            return $scrn; 
                            

                            #}
                        }

                    }
                    else {
                        return user_error( { -list => $list, -error => "no_archive_entry" } );
                    }

                }
                else {
                    return user_error( { -list => $list, -error => "no_display_attachments" } );
                }

            }
            else {
                return user_error( { -list => $list, -error => "no_display_attachments" } );
            }

        }
        else {
            return user_error( { -list => $list, -error => "no_show_archives" } );
        }

    }
    else {
        return user_error( { -list => $list, -error => 'no_list' } );
    }

}

sub redirection {

    my $self = shift;
    my $q    = $self->query();

    #	use Data::Dumper;
    #	die Dumper([$q->param('key'), $q->param('email')] );
    require DADA::Logging::Clickthrough;
    my $r = DADA::Logging::Clickthrough->new( { -list => scalar $q->param('list') } );
    if ( defined( $q->param('key') ) ) {

        my ( $mid, $url, $atts ) = $r->fetch( $q->param('key') );

        if ( defined($mid) && defined($url) ) {
            $r->r_log(
                {
                    -mid   => $mid,
                    -url   => $url,
                    -atts  => $atts,
                    -email => scalar $q->param('email'),
                }
            );
        }
        if ($url) {
            $self->header_type('redirect');
            $self->header_props( -url => $url );
        }
        else {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::PROGRAM_URL );
        }
    }
    else {
        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::PROGRAM_URL );
    }
}

sub m_o_c {

    my $self = shift;
    my $q    = $self->query();

    my $list = xss_filter( scalar $q->param('list') );

    if ( check_if_list_exists( -List => $list ) == 0 ) {
        carp "list: '$list' does not exist, aborted logging of open message\n" . 'path_info(): ' . $q->path_info();

    }
    else {
        require DADA::Logging::Clickthrough;
        my $r = DADA::Logging::Clickthrough->new( { -list => scalar $q->param('list') } );
        if ( defined( $q->param('mid') ) ) {

            $r->open_log(
                {
                    -mid   => scalar $q->param('mid'),
                    -email => scalar $q->param('email'),
                }
            );
        }
    }
    require MIME::Base64;
    my $headers = {
        -type             => 'image/png',
        '-Cache-Control'  => 'no-cache, max-age=0',
       # '-Content-Length' => 0,
     };

    # a simple, 1px png image.
    my $str = <<EOF
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAABGdBTUEAANbY1E9YMgAAABl0RVh0
U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAGUExURf///wAAAFXC034AAAABdFJOUwBA
5thmAAAADElEQVR42mJgAAgwAAACAAFPbVnhAAAAAElFTkSuQmCC
EOF
;
    $self->header_props(%$headers);
    return MIME::Base64::decode_base64($str);

}

sub css {

    my $self = shift;
    my $q    = $self->query();

    # Backwards compat -
    my $headers = { -type => 'text/css' };

    if ( $q->param('css_file') eq 'dada_mail.css' ) {

        my $body = DADA::Template::Widgets::_raw_screen(
            { -screen => $DADA::Config::SUPPORT_FILES->{dir} . '/static/css/dada_mail.css' } );

        $self->header_props(%$headers);
        return $body;
    }
    else {
        $self->header_props(%$headers);
    }
}

sub captcha_img {

    my $self = shift;
    my $q    = $self->query();

    my $img_str = xss_filter( scalar $q->param('img_string') );

    if ( -e $DADA::Config::TMP . '/capcha_imgs/CAPTCHA-' . $img_str . '.png' ) {

        my $headers = { -type => 'image/png' };
        my $body;

        open( IMG, '< ' . $DADA::Config::TMP . '/capcha_imgs/CAPTCHA-' . $img_str . '.png' )
          or die $!;
        {
            #slurp it all in
            local $/ = undef;
            $body = <IMG>;

        }
        close(IMG) or die $!;

        chmod( $DADA::Config::FILE_CHMOD,
            make_safer( $DADA::Config::TMP . '/capcha_imgs/CAPTCHA-' . $img_str . '.png' ) );

        my $success = unlink( make_safer( $DADA::Config::TMP . '/capcha_imgs/CAPTCHA-' . $img_str . '.png' ) );
        warn 'Couldn\'t delete file, ' . $DADA::Config::TMP . '/capcha_imgs/CAPTCHA-' . $img_str . '.png'
          if $success == 0;

        $self->header_props(%$headers);
        return $body;

    }
    else {
        return $self->default();
    }
}

sub ver {

    my $self = shift;
    my $q    = $self->query();

    return $DADA::Config::VER;
}

sub author {

    my $self = shift;
    my $q    = $self->query();

    return "Dada Mail is originally written by Justin Simoni";

}

sub profile_login {

    my $self = shift;
    my $q    = $self->query();

    my $whole_url = $q->url( -path_info => 1, -query =>0 );
    if(exists($ENV{QUERY_STRING})) { 
        if(length($ENV{QUERY_STRING}) > 0) { 
            $whole_url .= '?' . $ENV{QUERY_STRING};
        }
    }
    
    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return $self->default();

    }

    if ( $DADA::Config::PROFILE_OPTIONS->{enabled} != 1 ) {
        return $self->default();
    }
    require DADA::Profile;
    ###
    my $all_errors = [];
    my $named_errs = {};
    my $errors     = $q->param('errors');
    for (@$errors) {
        $named_errs->{ 'error_' . $_ } = 1;
        push( @$all_errors, { error => $_ } );
    }
    ###

    require DADA::Profile::Session;
    my $prof_sess = DADA::Profile::Session->new;

    if ( $q->param('process') != 1 ) {

        if ( $prof_sess->is_logged_in( { -cgi_obj => $q } ) && $q->param('logged_out') != 1 ) {
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::PROGRAM_URL . '/profile/' );
        }
        else {
            my $scrn            = '';
            my $can_use_captcha = 0;
            my $CAPTCHA_string  = '';
            my $cap             = undef;
            if ( $DADA::Config::PROFILE_OPTIONS->{enable_captcha} == 1 ) {
                $can_use_captcha = can_use_AuthenCAPTCHA();
            }
            if ( $can_use_captcha == 1 ) {
                require DADA::Security::AuthenCAPTCHA;
                my $cap = DADA::Security::AuthenCAPTCHA->new;
                $CAPTCHA_string = $cap->get_html( $DADA::Config::RECAPTCHA_PARAMS->{public_key} );
            }

            $scrn = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'profile_login.tmpl',
                    -with   => 'list',
                    -expr   => 1,
                    -vars   => {
                        errors => $all_errors,
                        %$named_errs,

                        email => xss_filter( scalar $q->param('email') )
                          || '',
                        login_email => xss_filter( scalar $q->param('login_email') )
                          || '',
                        register_email => xss_filter( scalar $q->param('register_email') )
                          || '',
                        reset_email => xss_filter( scalar $q->param('reset_email') )
                          || '',
                        register_email_again => xss_filter( scalar $q->param('register_email_again') )
                          || '',

                        error_profile_login          => scalar $q->param('error_profile_login')          || '',
                        error_profile_register       => scalar $q->param('error_profile_register')       || '',
                        error_profile_activate       => scalar $q->param('error_profile_activate')       || '',
                        error_profile_reset_password => scalar $q->param('error_profile_reset_password') || '',
                        password_changed             => scalar $q->param('password_changed')             || '',
                        logged_out                   => scalar $q->param('logged_out')                   || '',
                        can_use_captcha              => $can_use_captcha,
                        CAPTCHA_string               => $CAPTCHA_string,
                        welcome                      => scalar $q->param('welcome')                      || '',
                        removal                      => scalar $q->param('removal')                      || '',
                        WHOLE_URL => $whole_url, 
                        %{ DADA::Profile::feature_enabled() }
                    },

                }
            );
            return $scrn;
        }
    }
    else {
        my ( $status, $errors ) = $prof_sess->validate_profile_login(
            {
                -email    => xss_filter( scalar $q->param('login_email') ),
                -password => xss_filter( scalar $q->param('login_password') ),

            },
        );

        if ( $status == 1 ) {
            my $cookie = $prof_sess->login(
                {
                    -email    => xss_filter( scalar $q->param('login_email') ),
                    -password => xss_filter( scalar $q->param('login_password') ),
                },
            );

            #DEV: encoding?
            my $headers = {
                -cookie  => [$cookie],
                -nph     => $DADA::Config::NPH,
                -Refresh => '0; URL=' . $DADA::Config::PROGRAM_URL . '/profile/'
            };
            my $body = $q->start_html(
                -title   => 'Logging in...',
                -BGCOLOR => '#FFFFFF'
            );
            $body .= $q->p( $q->a( { -href => $DADA::Config::PROGRAM_URL . '/profile/' }, 'Logging in...' ) );
            $body .= $q->end_html();

            $self->header_props(%$headers);
            return $body;
        }
        else {
            my $p_errors = [];
            for ( keys %$errors ) {
                if ( $errors->{$_} == 1 ) {
                    push( @$p_errors, $_ );
                }
            }
            $q->param( 'errors',              $p_errors );
            $q->param( 'process',             0 );
            $q->param( 'error_profile_login', 1 );
            return $self->profile_login();
        }
    }

}

sub profile_register {

    my $self = shift;
    my $q    = $self->query();

    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return $self->default();
    }

    require DADA::Profile;
    if ( !DADA::Profile::feature_enabled('register') == 1 ) {
        return $self->default();
    }

    my $register_email       = strip( cased( xss_filter( scalar $q->param('register_email') ) ) );
    my $register_email_again = strip( cased( xss_filter( scalar $q->param('register_email_again') ) ) );
    my $register_password    = strip( xss_filter( scalar $q->param('register_password') ) );

    my $prof = DADA::Profile->new( { -email => $register_email } );

     
    if ( $prof->exists()
        && !$prof->is_activated() )
    {
        $prof->remove();
    }

    
    my ( $status, $errors ) = $prof->is_valid_registration(
        {
            -email                     => $register_email,
            -email_again               => $register_email_again,
            -password                  => $register_password,
            -recaptcha_challenge_field => scalar $q->param('recaptcha_challenge_field'),
            -recaptcha_response_field  => scalar $q->param('recaptcha_response_field'),
        }
    );
    
    
    if ( $status == 0 ) {
        my $p_errors = [];
        for ( keys %$errors ) {
            if ( $errors->{$_} == 1 ) {
                push( @$p_errors, $_ );
            }
        }
        $q->param( 'errors',                 $p_errors );
        $q->param( 'error_profile_register', 1 );
        return $self->profile_login();

    }
    else {
        $prof->setup_profile( { -password => $register_password, } );
        my $scrn = '';

        $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'profile_register.tmpl',
                -with   => 'list',
                -vars   => {

                    'profile.email' => $register_email,
                }
            }
        );
        return $scrn;

    }
}

sub profile_activate {

    my $self = shift;
    my $q    = $self->query();

    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return $self->default();
    }

    require DADA::Profile;
    if ( !DADA::Profile::feature_enabled('register') == 1 ) {
        return $self->default();
    }

    my $email     = strip( cased( xss_filter( scalar $q->param('email') ) ) );
    my $auth_code = xss_filter( scalar $q->param('auth_code') );

    my $prof = DADA::Profile->new( { -email => $email } );

    if ( $email && $auth_code ) {
        my ( $status, $errors ) =
          $prof->is_valid_activation( { -auth_code => xss_filter( scalar $q->param('auth_code') ) || '', } );
        if ( $status == 1 ) {
            $prof->activate;
            my $profile = $prof->get;
            $q->param( 'welcome', 1 );
            return $self->profile_login();
        }
        else {
            my $p_errors = [];
            for ( keys %$errors ) {
                if ( $errors->{$_} == 1 ) {
                    push( @$p_errors, $_ );
                }
            }
            $q->param( 'errors',                  $p_errors );
            $q->param( 'error_invalid_auth_code', $errors->{invalid_auth_code} );
            $q->param( 'error_profile_activate',  1 );
            return $self->profile_login();
        }
    }
    else {
        return 'no email or auth code!';
    }
}

sub profile {

    my $self = shift;
    my $q    = $self->query();

    my $whole_url = $q->url( -path_info => 1, -query =>0 );
    if(exists($ENV{QUERY_STRING})) { 
        if(length($ENV{QUERY_STRING}) > 0) { 
            $whole_url .= '?' . $ENV{QUERY_STRING};
        }
    }


    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return $self->default();

    }

    require DADA::Profile::Session;
    my $prof_sess = DADA::Profile::Session->new;

    if ( $prof_sess->is_logged_in( { -cgi_obj => $q } ) ) {
        my $email = $prof_sess->get( { -cgi_obj => $q } );

        require DADA::Profile::Fields;
        require DADA::Profile;

        my $prof = DADA::Profile->new( { -email => $email } );
        my $dpf = DADA::Profile::Fields->new( { -email => $email } );
        my $subscriber_fields = $dpf->{manager}->fields( { -show_hidden_fields => 0, } );
        my $field_attr        = $dpf->{manager}->get_all_field_attributes;
        my $email_fields      = $dpf->get;

        if ( $q->param('process') eq 'edit_subscriber_fields' ) {

            my $edited = {};
            for (@$subscriber_fields) {
                $edited->{$_} = xss_filter( scalar $q->param($_) );

                # This is better than nothing, but it's very lazy -
                # Make sure that the length is less than 10k.
                if ( length( $edited->{$_} ) > 10240 ) {

                    # Sigh.
                    die $DADA::CONFIG::PROGRAM_NAME . ' '
                      . $DADA::Config::VER
                      . ' Error! Attempting to save Profile Field with too large of a value!';
                }
            }

            # DEV: This is somewhat of a hack - so that we don't writeover hidden fields, we re-add them, here
            # A little kludgey.

            for my $field ( @{ $dpf->{manager}->fields( { -show_hidden_fields => 1 } ) } ) {
                if ( $field =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/ ) {
                    $edited->{$field} = $email_fields->{$field},;
                }
            }
            $dpf->insert( { -fields => $edited, } );

            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::PROGRAM_URL . '?flavor=profile&edit=1' );
        }
        elsif ( $q->param('process') eq 'change_password' ) {
            
            if ( !DADA::Profile::feature_enabled('change_password') == 1 ) {
                # warn 'feature disabled.'; 
                return $self->default();
            }
            else { 
#                # warn 'feature enabled!'; 
            }

            my $new_password       = xss_filter( scalar $q->param('password') );
            my $again_new_password = xss_filter( scalar $q->param('again_password') );

            # DEV: See?! Why are we doing this manually? Can we use is_valid_registration() perhaps?
            if ( length($new_password) > 0
                && $new_password eq $again_new_password )
            {
                $prof->update( { -password => $new_password, } );
                $q->param( 'password_changed', 1 );
                $q->delete('process');

                require DADA::Profile::Session;
                my $prof_sess = DADA::Profile::Session->new->logout;

                # DEV: This is going to get repeated quite a bit..
                require DADA::Profile::Htpasswd;
                foreach my $p_list ( @{ $prof->subscribed_to } ) {
                    my $htp = DADA::Profile::Htpasswd->new( { -list => $p_list } );
                    for my $id ( @{ $htp->get_all_ids } ) {
                        $htp->setup_directory( { -id => $id } );
                    }
                }
                #
                return $self->profile_login();
                
            }
            else {
                $q->param( 'errors',                 1 );
                $q->param( 'errors_change_password', 1 );
                $q->delete('process');
                return $self->profile();
            }

        }
        elsif ( $q->param('process') eq 'update_email' ) {

            if ( !DADA::Profile::feature_enabled('update_email_address') == 1 ) {
                 
                
                return $self->default();
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
            my $updated_email = cased( xss_filter( scalar $q->param('updated_email') ) );

            # Oh. What if there is already a profile for this address?

            my ( $status, $errors ) = $prof->is_valid_update_profile_email( { -updated_email => $updated_email, } );
            if ( $status == 0 ) {

                my $p_errors = [];
                for ( keys %$errors ) {
                    if ( $errors->{$_} == 1 ) {

                        #push(@$p_errors, $_);
                        $q->param( 'error_' . $_, 1 );
                    }
                }

                #	$q->param('errors',              $p_errors);
                $q->param( 'errors',              1 );
                $q->param( 'process',             0 );
                $q->param( 'errors_update_email', 1 );
                $q->param( 'updated_email',       $updated_email );
                return $self->profile();
            }
            else {

                 
                
                $prof->confirm_update_profile_email( { -updated_email => $updated_email, } );

                my $info = $prof->get( { -dotted => 1 } );
                my $scrn = '';

                $scrn = DADA::Template::Widgets::wrap_screen(
                    {
                        -with   => 'list',
                        -screen => 'profile_update_email_auth_send.tmpl',
                        -vars   => { %$info, }
                    }
                );
                return $scrn;
            }

            # Oh! We've confirmed?

            # We've got to make sure that we can switch the email address in each
            # various list - perhaps the new address is blacklisted? Ack. that would be stinky
            # Another problem: What if the new email address is already subscribed?
            # May need a, "replace" function.
            # Sigh...

            # That's it.
        }
        elsif ( $q->param('process') eq 'delete_profile' ) {

            if ( !DADA::Profile::feature_enabled('delete_profile') == 1 ) {
                return $self->default();
            }
            else {
                $prof_sess->logout;
                $prof->remove;

                undef $prof;
                undef $prof_sess;

                $q->param( 'flavor',  'profile_login' );
                $q->param( 'removal', 1 );
                
                return $self->profile_login();
            }
        }
        elsif ( $q->param('process') eq 'profile_delivery_preferences' ) {
            my $list           = xss_filter( scalar $q->param('list') );
            my $delivery_prefs = xss_filter( scalar $q->param('delivery_prefs') );

            require DADA::Profile::Settings;
            my $dps = DADA::Profile::Settings->new;
            my $r   = $dps->save(
                {
                    -email   => $email,
                    -list    => $list,
                    -setting => 'delivery_prefs',
                    -value   => $delivery_prefs,
                }
            );
            $self->header_type('redirect');
            $self->header_props( -url => $DADA::Config::PROGRAM_URL . '?flavor=profile&edit=1' );

        }
        else {

            my $fields = [];
            for my $field (@$subscriber_fields) {
                push(
                    @$fields,
                    {
                        name     => $field,
                        label    => $field_attr->{$field}->{label},
                        value    => $email_fields->{$field},
                        required => $field_attr->{$field}->{required},
                    }
                );
            }

            my $subscriptions = $prof->subscribed_to( { -html_tmpl_params => 1 } ), my $filled = [];
            my $has_subscriptions = 0;

            my $protected_directories = [];

            for my $i (@$subscriptions) {

                if ( $i->{subscribed} == 1 ) {
                    $has_subscriptions = 1;
                }

                require DADA::MailingList::Settings;
                my $ls = DADA::MailingList::Settings->new( { -list => $i->{list} } );

                # Ack, this is very awkward:

                #  Ack, this is very awkward:

                my $li = DADA::Template::Widgets::webify_and_santize(
                    {
                        -vars => $ls->get( -dotted => 1 ),
                        -to_sanitize =>
                          [qw(list_settings.list_owner_email list_settings.info list_settings.privacy_policy )],
                    }
                );

                require DADA::Profile::Htpasswd;
                my $htp = DADA::Profile::Htpasswd->new( { -list => $i->{list} } );
                my $l_p_d = $htp->get_all_entries;
                if ( scalar(@$l_p_d) > 0 ) {
                    @$protected_directories = ( @$protected_directories, @$l_p_d );
                }

                require DADA::App::Subscriptions::Unsub;
                my $dasu = DADA::App::Subscriptions::Unsub->new( { -list => $i->{list} } );
                my $unsub_link = $dasu->unsub_link( { -email => $email, -mid => '00000000000000' } );

                my $digest_timeframe = formatted_runtime( $ls->param('digest_schedule') );

                require DADA::Profile::Settings;
                my $dpa = DADA::Profile::Settings->new;
                my $s   = $dpa->fetch(
                    {
                        -list  => $i->{list},
                        -email => $email,
                    }
                );
                my $delivery_prefs = $s->{delivery_prefs} || 'individual';
                push(
                    @$filled,
                    {
                        %{$i},
                        %{$li},
                        PROGRAM_URL           => $DADA::Config::PROGRAM_URL,
                        list_unsubscribe_link => $unsub_link,
                        digest_timeframe      => $digest_timeframe,
                        delivery_prefs        => $delivery_prefs,
                    }
                );
            }

            my $scrn = '';

            $scrn .= DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'profile_home.tmpl',
                    -with   => 'list',
                    -expr   => 1,
                    -vars   => {
                        errors => scalar $q->param('errors')
                          || 0,
                        'profile.email'   => $email,
                        subscriber_fields => $fields,
                        subscriptions     => $filled,
                        has_subscriptions => $has_subscriptions,
                        welcome           => scalar $q->param('welcome')
                          || '',
                        edit => scalar $q->param('edit')
                          || '',
                        errors_change_password => scalar $q->param('errors_change_password')
                          || '',
                        errors_update_email => scalar $q->param('errors_update_email')
                          || '',
                        error_invalid_email => scalar $q->param('error_invalid_email')
                          || '',
                        error_profile_exists => scalar $q->param('error_profile_exists')
                          || '',
                        updated_email => scalar $q->param('updated_email')
                          || '',

                        gravators_enabled     => $DADA::Config::PROFILE_OPTIONS->{gravatar_options}->{enable_gravators},
                        gravatar_img_url      => gravatar_img_url( { -email => $email, } ),
                        protected_directories => $protected_directories,
                        WHOLE_URL => $whole_url, 
                        %{ DADA::Profile::feature_enabled() },

                    }
                }
            );
            return $scrn;
        }
    }
    else {
        $q->param( 'error_profile_login', 1 );
        $q->param( 'errors', ['not_logged_in'] );
        return $self->profile_login();
    }

}

sub profile_logout {

    my $self = shift;
    my $q    = $self->query();

    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return $self->default();
    }

    require DADA::Profile::Session;
    my $prof_sess = DADA::Profile::Session->new;

    $prof_sess->logout;
    my $redirect_to = $DADA::Config::PROGRAM_URL . '?flavor=profile_login&logged_out=1';

    #if ( $q->referer() && $q->referer() !~ m/\/profile\// ) {
    #    $redirect_to = $q->referer();
    #}
    my $headers = {
        -cookie  => [ $prof_sess->logout_cookie ],
        -nph     => $DADA::Config::NPH,
        -Refresh => '0; URL=' . $redirect_to,
    };
    my $body = $q->start_html(
        -title   => 'Logging Out...',
        -BGCOLOR => '#FFFFFF'
    );
    $body .= $q->p( $q->a( { -href => $redirect_to }, 'Logging Out...' ) );
    $body .= $q->end_html();

    $self->header_props(%$headers);
    return $body;
}

sub profile_reset_password {

    my $self  = shift;
    my $q     = $self->query();
    my $email = $q->param('email');

    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return $self->default();
    }

    require DADA::Profile;
    if ( !DADA::Profile::feature_enabled('password_reset') == 1 ) {
        return $self->default();
    }

    my $reset_email = cased( xss_filter( scalar $q->param('reset_email') ) );
    my $auth_code = xss_filter( scalar $q->param('auth_code') ) || undef;

    if ($auth_code) {
        $reset_email = $email;
    }
    require DADA::Profile;
    my $prof = DADA::Profile->new( { -email => $reset_email } );

    if ($reset_email) {

        my $password = xss_filter( scalar $q->param('password') ) || undef;

        if ($auth_code) {
            my ( $status, $errors ) = $prof->is_valid_activation( { -auth_code => $auth_code, } );
            if ( $status == 1 ) {
                if ( !$password ) {

                    my $scrn = DADA::Template::Widgets::wrap_screen(
                        {
                            -screen => 'profile_reset_password.tmpl',
                            -with   => 'list',
                            -vars   => {
                                email     => $reset_email,
                                auth_code => $auth_code,
                            }
                        }
                    );
                    return $scrn;
                }
                else {
                    # Reset the Password
                    $prof->update( { -password => $password, } );

                    # Reactivate the Account
                    $prof->activate();

                    # Log The person in.
                    # Probably pass the needed stuff to profile_login via CGI's param()
                    $q->param( 'login_email',    $reset_email );
                    $q->param( 'login_password', $password );
                    $q->param( 'process',        1 );

                    # and just called the subroutine itself. Hazzah!
                    return $self->profile_login();

                    # Go home, kiss the wife.
                }
            }
            else {

                my $p_errors = [];
                for ( keys %$errors ) {
                    if ( $errors->{$_} == 1 ) {
                        push( @$p_errors, $_ );
                        $q->param( 'error_' . $_, 1 );
                    }
                }
                $q->param( 'error_profile_reset_password', 1 );
                $q->param( 'errors',                       $p_errors );
                return $self->profile_login();
            }
        }
        else {

            if ( $prof->exists() ) {

                $prof->send_profile_reset_password_email();
                $prof->activate;

                my $scrn = DADA::Template::Widgets::wrap_screen(
                    {
                        -screen => 'profile_reset_password_confirm.tmpl',
                        -with   => 'list',
                        -vars   => {
                            email           => $reset_email,
                            'profile.email' => $reset_email,
                        }
                    }
                );
                return $scrn;
            }
            else {
                $q->param( 'error_profile_reset_password', 1 );
                $q->param( 'error_unknown_user',           1 );
                $q->param( 'errors', ['unknown_user'] );
                $q->param( 'email', $reset_email );
                return $self->profile_login();
            }
        }
    }
    else {

        $self->header_type('redirect');
        $self->header_props( -url => $DADA::Config::PROGRAM_URL . '/profile_login/' );
    }
}

sub profile_update_email {

    my $self = shift;
    my $q    = $self->query();

    my $auth_code = xss_filter( scalar $q->param('auth_code') );
    my $email     = cased( xss_filter( scalar $q->param('email') ) );
    my $confirmed = xss_filter( scalar $q->param('confirmed') );

    require DADA::Profile;

    if ( !DADA::Profile::feature_enabled('update_email_address') == 1 ) {
        return $self->default();
    }

    my $prof = DADA::Profile->new( { -email => $email } );
    my $info = $prof->get;

    my ( $status, $errors ) = $prof->is_valid_update_profile_activation( { -update_email_auth_code => $auth_code, } );

    if ( $status == 1 ) {

        my $profile_info = $prof->get( { -dotted => 1 } );
        my $subs = $prof->profile_update_email_report;

        #require Data::Dumper;
        #die Data::Dumper::Dumper($subs);
        if ( $confirmed == 1 ) {

            # This should probably go in the update_email method...
            require DADA::MailingList::Subscribers;
            for my $in_list (@$subs) {
                my $lh = DADA::MailingList::Subscribers->new( { -list => $in_list->{'list_settings.list'}, } );
                $lh->remove_subscriber(
                    {
                        -email => cased( $profile_info->{'profile.email'} ),
                        -type  => 'list'
                    }
                );
                $lh->add_subscriber(
                    {
                        -email => cased( $profile_info->{'profile.update_email'} ),
                        -type  => 'list'
                    }
                );
            }
            $prof->update_email;

            #/ This should probably go in the update_email method...

            $prof->send_update_email_notification( { -prev_email => cased( $profile_info->{'profile.email'} ), } );

            # Now, just log us in:
            require DADA::Profile::Session;
            my $prof_sess = DADA::Profile::Session->new;
            if ( $prof_sess->is_logged_in ) {
                $prof_sess->logout;
            }
            undef $prof_sess;

            my $prof_sess = DADA::Profile::Session->new;
            my $cookie    = $prof_sess->login(
                {
                    -email   => $profile_info->{'profile.update_email'},
                    -no_pass => 1,
                }
            );

            my $headers = {
                -cookie  => [$cookie],
                -nph     => $DADA::Config::NPH,
                -Refresh => '0; URL=' . $DADA::Config::PROGRAM_URL . '/profile/'
            };
            my $body = $q->start_html(
                -title   => 'Logging in...',
                -BGCOLOR => '#FFFFFF'
            );
            $body .= $q->p( $q->a( { -href => $DADA::Config::PROGRAM_URL . '/profile/' }, 'Logging in...' ) );
            $body .= $q->end_html();

            $self->header_props(%$headers);
            return $body;
        }
        else {

            # I should probably also just, log this person in...

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
            return $scrn;
        }
    }
    else {

        # DEV: Currently there is no description of what the error is, just
        # that, "there is one". Perhaps change that?
        #

        my $ht_errors = [];
        for ( keys %$errors ) {
            push( @$ht_errors, { name => $_, value => $errors->{$_} } );
        }

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'profile_update_email_error.tmpl',
                -with   => 'list',
                -vars   => {
                    errors => $ht_errors,
                },
            }
        );
        return $scrn;

    }
}

sub what_is_dada_mail {

    my $self = shift;
    my $q    = $self->query();

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'what_is_dada_mail.tmpl',
            -with   => 'list',
        }
    );
    return $scrn;

}

sub plugins {
    my $self   = shift;
    my $q      = $self->query();
    my $plugin = $q->param('plugin');
    my ( $headers, $body );
    if ( exists( $DADA::Config::PLUGINS_ENABLED->{$plugin} ) ) {
        if ( $DADA::Config::PLUGINS_ENABLED->{$plugin} != 1 ) {
            return 'Plugin disabled.';
        }
        eval {
            require 'plugins/' . $plugin;
            ( $headers, $body ) = $DADA::Config::PLUGIN_RUNMODES->{$plugin}->{run}->($q);
        };
        if ( !$@ ) {
            if ( exists( $headers->{-redirect_uri} ) ) {
                $self->header_type('redirect');
                $self->header_props( -url => $headers->{-redirect_uri} );
            }
            else {
                if ( keys %$headers ) {
                    $self->header_props(%$headers);
                }
                return $body;
            }
        }
        else {
            return ($@);
        }
    }
    else {
        return "plugin not registered.";
    }

}

sub bridge_inject {

    my $self = shift;
    my $r;

    $ENV{CGI_APP_RETURN_ONLY} = 1;

    if ( $DADA::Config::PLUGINS_ENABLED->{bridge} != 1 ) {
        return 'Plugin disabled.';
    }
    my $run_list = $self->param('run_list');

    if ( !defined($run_list) ) {
        $r .= 'No List Defined.';
    }
    require 'plugins/bridge';


    # One problem with this is that we don't know the encoding of the message.
    # If it's 8bit, and ISO-whatever, we're in trouble
    # We could read the full msg in, and change the encoding, THEN Tag the message in that encoding. 
    # Sounds message. 
    
    require DADA::Security::Password;
    my $filename =
      $DADA::Config::TMP . "/tmp_file" . DADA::Security::Password::generate_rand_string() . "-" . time . ".txt";
    open my $tmp_file, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $filename or die $!;
 #   open my $tmp_file2, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $filename . '2' or die $!;
    
    my $msg;
    # binmode(STDIN,  ":utf8");
    # binmode STDIN;
    while ( my $line = <STDIN> ) {
#        $line = safely_decode($line);
#        $line = safely_encode($line);

        print $tmp_file $line;
#        print $tmp_file2 $line; 
    }
    close $tmp_file  or die $!;
 #   close $tmp_file2 or die $!;
    
    chmod( $DADA::Config::FILE_CHMOD, $filename );

    $r .= bridge::inject_msg(
        {
            -filename => $filename,
            -list     => $run_list,
        }
    );

}

sub schedules {

    # Just need to document this
    # and figure out inject stuff.... sigh.

    
    my $self = shift;
    my $q    = $self->query;

    my $t = time;
    
    my $list         = $q->param('list')         || '_all';
    my $schedule     = $q->param('schedule')     || '_all';
    my $output_mode  = $q->param('output_mode')  || '_verbose';
    my $for_colorbox = $q->param('for_colorbox') || 0;

    my $r;
    $r .= "Started: " . scalar localtime($t) . "\n"; 

    require DADA::App::ScheduledTasks;
    my $dast = DADA::App::ScheduledTasks->new;

    if ( $schedule eq '_all' ) {
        $r .= "\n\nMonitor:\n" . '-' x 72 . "\n\n";
        try {
            $r .= $dast->mass_mailing_monitor($list);
        } catch {
            $r .= "* Error: $_\n";
        };

        $r .= "\n\nMass Mailing Schedules:\n" . '-' x 72 . "\n\n";
        try {
            $r .= $dast->scheduled_mass_mailings($list);
        } catch {
            $r .= "* Error: $_\n";
        };

        undef($dast);

        for my $plugin ( keys %$DADA::Config::PLUGINS_ENABLED ) {
            if ( exists( $DADA::Config::PLUGINS_ENABLED->{$plugin} ) ) {
                next if ( $DADA::Config::PLUGINS_ENABLED->{$plugin} != 1 );
                next if !exists( $DADA::Config::PLUGIN_RUNMODES->{$plugin}->{sched_run} );
                $r .= "\n\nPlugin: $plugin\n" . '-' x 72 . "\n\n";
                try {
                    require 'plugins/' . $plugin;
                    $r .= $DADA::Config::PLUGIN_RUNMODES->{$plugin}->{sched_run}->($list);
                } catch {
                    $r .= "* Error: $_\n";
                };
            }
        }
    }
    elsif ( $schedule eq 'mass_mailing_monitor' ) {
        $r .= "\n\nMonitor:\n" . '-' x 72 . "\n\n";
        try {
            $r .= $dast->mass_mailing_monitor($list);
        } catch {
            $r .= "* Error: $_\n";
        };
    }
    elsif ( $schedule eq 'scheduled_mass_mailings' ) {
        $r .= "\n\nMass Mailing Schedules:\n" . '-' x 72 . "\n\n";
        try {
            $r .= $dast->scheduled_mass_mailings($list);
        } catch {
            $r .= "* Error: $_\n";
        };
    }
    elsif ($schedule eq 'bridge'
        || $schedule eq 'bounce_handler' )
    {
        if ( $DADA::Config::PLUGINS_ENABLED->{$schedule} != 1 ) {

            #....
        }
        else {
			
			
            $r .= "\n\nPlugin: $schedule\n" . '-' x 72 . "\n\n";
			
            try {
                require 'plugins/' . $schedule;
                $r .= $DADA::Config::PLUGIN_RUNMODES->{$schedule}->{sched_run}->($list);
            } catch {
                $r .= "* Error: $_\n";
            };
        }
    }
    else {
        $r .= 'No such schedule:"' . $schedule . '"';
    }

    my $end_t = time; 
    my $total_t = $end_t - $t; 
    $r .= "Finished: " . scalar localtime($end_t) . "\n"; 
    $r .= "Total processing time: " . formatted_runtime($total_t) . "\n"; 
    
    if ( $DADA::Config::SCHEDULED_JOBS_OPTIONS->{'log'} == 1 ) {
        require DADA::Logging::Usage;
        my $log = new DADA::Logging::Usage;
        $log->cron_log($r);
    }

    
    if ( $output_mode ne '_silent' ) {
        $self->header_props( { -type => 'text/plain' } );
        if ( $for_colorbox == 1 ) {
            return '<pre>' . 
					$r . 
					'</pre>';
        }
        else {
           # $ENV{CGI_APP_RETURN_ONLY} = 1;
            return $r;
        }
    }
    else {
        return '';
    }
}

sub scheduled_jobs {

    my $self = shift;
    my $q    = $self->query;

    my ( $admin_list, $root_login, $checksout, $error_msg ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'send_email'
    );
    if ( !$checksout ) { return $error_msg; }

    my $curl_location = `which curl`;

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'scheduled_jobs.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $admin_list,
            },
            -expr => 1,
            -vars => {
                scheduled_jobs_flavor => $DADA::Config::SCHEDULED_JOBS_OPTIONS->{scheduled_jobs_flavor},
                curl_location         => $curl_location,
            },
        }
    );
}

sub DESTROY {

    # warn 'DADA::App::DESTROY called.';
}

sub END { }

1;

__END__

=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2015 Justin Simoni All rights reserved. 

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

