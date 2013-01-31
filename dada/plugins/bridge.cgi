#!/usr/bin/perl

package bridge;

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";

use strict;
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

#---------------------------------------------------------------------#
# Bridge
# For instructions, see the pod of this file. try:
#  pod2text ./bridge.cgi | less
#
# Or try online:
#  http://dadamailproject.com/d/bridge.cgi.html
#
#---------------------------------------------------------------------#
# REQUIRED:
#
# It is only required that you read the documentation. All variables
# that are set here are *optional*
#---------------------------------------------------------------------#

use CGI::Carp qw(fatalsToBrowser);

use DADA::Config 6.0.0;

use CGI;
    CGI->nph(1) if $DADA::Config::NPH == 1;

my $q = CGI->new;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);
use Fcntl qw(
  O_CREAT
  O_RDWR
  LOCK_EX
  LOCK_NB
);
use Encode;
use Try::Tiny;

my $Plugin_Config = {};

$Plugin_Config->{Plugin_Name} = 'Bridge';

# Usually, this doesn't need to be changed.
# But, if you are having trouble saving settings
# and are redirected to an
# outside page, you may need to set this manually.
$Plugin_Config->{Plugin_URL} = self_url();

# Can the checking of awaiting messages to send out happen by invoking this
# script from a URL? (CGI mode?)
# The URL would look like this:
#
# http://example.com/cgi-bin/dada/plugins/bridge.cgi?run=1

$Plugin_Config->{Allow_Manual_Run} = 1;

# Set a passcode that you'll have to also pass to invoke this script as
# explained above in, "$Plugin_Config->{Allow_Manual_Run}"

$Plugin_Config->{Manual_Run_Passcode} = '';

# How many messages does Dada Mail look at, at once?
#
$Plugin_Config->{MessagesAtOnce} = 1;

# Is there a limit on how large a single email message can be, until we outright # reject it?
# In, "octets" (bytes) - this is about 2.5 megs...
#
# Soft_Max_Size_Of_Any_Message is the limit to reach before we email the
# original sending, telling them that the message is too large

$Plugin_Config->{Soft_Max_Size_Of_Any_Message} = 1048576;    # 1   meg

# Max_Size_Of_Any_Message is the limit to reach before we just simply
# ignore and remove the message. The reason why we'd ignore and remove is that
# the message is too large to even process!

$Plugin_Config->{Max_Size_Of_Any_Message} = 2621440;         # 2.5 meg

$Plugin_Config->{Allow_Open_Discussion_List} = 0;

# Another Undocumented feature - Room for one more?
# When set to, "1" we look to see how many mailouts there are,
# And if its above or at the limit, we don't attempt to check
# any Bridge list emails for awaiting messages.
# Sounds like a good idea, right? Well, the check has a bug in it, and this
# This is a kludge

$Plugin_Config->{Room_For_One_More_Check} = 1;

# Another Undocumented Feature - Enable Pop3 File Locking?
# Sometimes, the file lock for the POP3 server doesn't work correctly
# and you get a stale lock. Setting this config variable to, "0"
# will disable this plugin's own lock file scheme. Should be fairly safe to use.

$Plugin_Config->{Enable_POP3_File_Locking} = 1;

$Plugin_Config->{Check_List_Owner_Return_Path_Header} = 1;

# Gmail seems to have problems with this...
$Plugin_Config->{Check_Multiple_Return_Path_Headers} = 0;

# Stops From: header spoofing (a little bit, anyways)
$Plugin_Config->{Check_Multiple_From_Addresses} = 1;

#
# There is nothing else to configure in this program.
#---------------------------------------------------------------------#

#---------------------------------------------------------------------#

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

my $App_Version = $DADA::Config::VERSION;

# Phowaa - let's import *a few* things
use DADA::Template::HTML;
use DADA::App::Guts;
use DADA::Mail::Send;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use DADA::Security::Password;
use DADA::App::POP3Tools;
use Email::Address;
use Digest::MD5 qw(md5_hex);
use MIME::Parser;
use MIME::Entity;
use Getopt::Long;

my %Global_Template_Options = (

    #debug              => 1,
    path              => [$DADA::Config::TEMPLATES],
    die_on_bad_params => 0,

    (
          ( $DADA::Config::CPAN_DEBUG_SETTINGS{HTML_TEMPLATE} == 1 )
        ? ( debug => 1, )
        : ()
    ),

);

my $parser = new MIME::Parser;
$parser = optimize_mime_parser($parser);

my $test;

my $help;
my $inject  = 0;
my $verbose = 0;
my $debug   = 0;    # not used?
my $list;
my $run_list;

my $check_deletions = 0;
my $root_login      = 0;

my $checksums = {};

GetOptions(
    "help"            => \$help,
    "test=s"          => \$test,
    "verbose"         => \$verbose,
    "inject"          => \$inject,
    "list=s"          => \$run_list,
    "check_deletions" => \$check_deletions,
);

&init_vars;

run()
  unless caller();

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{'Bridge'}->{$key} ) )
        {

            if (
                defined(
                    $DADA::Config::PLUGIN_CONFIGS->{'Bridge'}->{$key}
                )
              )
            {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{'Bridge'}->{$key};

            }
        }
    }

	# "Plugin_URL" sometimes does not get created automatically, especially when the 
	# script is called via the --inject flag, so it's nice to munge that: 
	if($Plugin_Config->{Plugin_URL} eq 'http://localhost') { 
		$Plugin_Config->{Plugin_URL} = $DADA::Config::PROGRAM_URL;
		$Plugin_Config->{Plugin_URL} =~ s/(mail\.cgi)/plugins\/bridge\.cgi/; 
	}

}

sub run {
    if ( !$ENV{GATEWAY_INTERFACE} ) {
        &cl_main();
    }
    else {
        &cgi_main();
    }

}

sub test_sub {
    return "Hello, World!";
}

sub cgi_main {

    if (   keys %{ $q->Vars }
        && $q->param('run')
        && xss_filter( $q->param('run') ) == 1
        && $Plugin_Config->{Allow_Manual_Run} == 1 )
    {
        cgi_manual_start();
    }
    elsif ( $q->param('flavor') eq 'mod' ) {
        cgi_mod();
    }
    else {

        my $admin_list;

        ( $admin_list, $root_login ) = check_list_security(
            -cgi_obj  => $q,
            -Function => 'bridge',
        );

        $list = $admin_list;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $flavor = $q->param('flavor') || 'cgi_default';

        my %Mode = (
            'cgi_default'                 => \&cgi_default,
            'cgi_show_plugin_config'      => \&cgi_show_plugin_config,
            'test_pop3'                   => \&cgi_test_pop3,
            'awaiting_msgs'               => \&cgi_awaiting_msgs,
            'manual_start'                => \&admin_cgi_manual_start,
            'admin_cgi_manual_start_ajax' => \&admin_cgi_manual_start_ajax,
            'cgi_test_pop3_ajax'          => \&cgi_test_pop3_ajax,
            'edit_email_msgs'             => \&cgi_edit_email_msgs,

            # 'mod'                       => \&cgi_mod,
        );

        if ( exists( $Mode{$flavor} ) ) {
            $Mode{$flavor}->();    #call the correct subroutine
        }
        else {
            &cgi_default;
        }
    }
}

sub cgi_manual_start {

    if (
        (
            xss_filter( $q->param('passcode') ) eq
            $Plugin_Config->{Manual_Run_Passcode}
        )
        || ( $Plugin_Config->{Manual_Run_Passcode} eq '' )

      )
    {

        print $q->header();

        if ( defined( xss_filter( $q->param('verbose') ) ) ) {
            $verbose = xss_filter( $q->param('verbose') );
        }
        else {
            $verbose = 1;
        }

        $check_deletions = 1;

        if ( xss_filter( $q->param( xss_filter('list') ) ) ) {
            $run_list = xss_filter( $q->param('list') );
        }

        print '<pre>'
          if $verbose;
        start();
        print '</pre>'
          if $verbose;

        print '<pre>'
          if $verbose;

        require DADA::Mail::MailOut;
        if ($run_list) {
            DADA::Mail::MailOut::monitor_mailout(
                {
                    -verbose => $verbose,
                    -list    => $list,
                }
            );
        }
        else {
            DADA::Mail::MailOut::monitor_mailout( { -verbose => $verbose } );
        }
        print '</pre>'
          if $verbose;

    }
    else {
        print $q->header();
        print
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Authorization Denied.";
    }
}

sub cgi_test_pop3_ajax {

	    require DADA::App::POP3Tools;
	    my ( $pop3_obj, $pop3_status, $pop3_log ) =
	      DADA::App::POP3Tools::mail_pop3client_login(
	        {
	            server    => $q->param('server'),
	            username  => $q->param('username'),
	            password  => $q->param('password'),
#	            port      => $args->{Port},
	            AUTH_MODE => $q->param('auth_mode'),
	            USESSL    => ($q->param('auth_mode') eq 'true' ? 1 : 0),
	        }
	      );
	    if ( defined($pop3_obj) ) {
	        $pop3_obj->Close();
	    }
		print $q->header(); 
		if($pop3_status == 1){ 
			print '<p>Connection is Successful!</p>'; 
		}
		else { 
			print '<p>Connection is NOT Successful.</p>'; 
		}
		print '<pre>'  . $pop3_log . '</pre>';	  
}

sub cgi_test_pop3 {

    my $chrome = 1;
    if ( defined( $q->param('chrome') ) ) {
        $chrome = $q->param('chrome') || 0;
    }

    my %vars = (
        screen      => 'using_bridge',
        Plugin_Name => $Plugin_Config->{Plugin_Name},
        Plugin_URL  => $Plugin_Config->{Plugin_URL},
    );

    require DADA::Template::Widgets;
    my $scrn;

    if ( $chrome == 1 ) {

        $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen         => 'plugins/bridge/test_pop3.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -vars => { %vars },

            }
        );
    }
    else {
        print $q->header();
        $scrn = DADA::Template::Widgets::screen(
            {
                -screen => 'plugins/bridge/test_pop3.tmpl',
                -with   => 'admin',
                -vars   => { %vars },

            }
        );
    }
    e_print($scrn);

}

sub cgi_awaiting_msgs {

    print(
        admin_template_header(
            -Title      => "Messages Awaiting Moderation",
            -List       => $list,
            -Form       => 0,
            -Root_Login => $root_login
        )
    );

    $run_list = $list;
    $verbose  = 1;
    my $popupscript = <<EOF

<script type="text/javascript">
<!-- 
// This is the function that will open the
// new window when the mouse is moved over the link
function open_new_window(msgtext) 
{
new_window = open("","hoverwindow","width=440,height=300,left=10,top=10");

// open new document 
  new_window.document.open();
  
// Text of the new document
// Replace your " with ' or \" or your document.write statements will fail
new_window.document.write("<html><title>Raw View of Message</title>");
new_window.document.write("<body>");
new_window.document.write(msgtext);
new_window.document.write("</body></html>");

// close the document
  new_window.document.close();  
}

// -->
</script> 

EOF
      ;

    print $popupscript . '<br><pre>';

    my $mod = SimpleModeration->new( { -List => $list } );
    my $awaiting_msgs = $mod->awaiting_msgs();
    print "List of Messages Still Awaiting Moderation:\n\n"
      if $verbose;
    for (@$awaiting_msgs) {
        my $messagename = substr( $_, length($list) + 1 );
        my $parser = $parser;
        my $entity;

        # unescape URI encoded stuff:
        $messagename =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

        eval {
            $entity = $parser->parse_data(
                safely_encode( $mod->get_msg( { -msg_id => $messagename } ) ) );
        };
        if ( !$entity ) {

            #croak "no entity found! die'ing!";
            print "can't show message $messagename: $@\n";
        }
        else {
            my $subject = $entity->head->get( 'Subject', 0 );
            $subject =~ s/\n//g;
            my $from = $entity->head->get( 'From', 0 );
            $from =~ s/\n//g;
            my $date = $entity->head->get( 'Date', 0 );
            $date =~ s/\n//g;
            my $messagehdr =
              "From: " . $from . "; Subj: " . $subject . " ; Date: " . $date;

#        my $messagetxt = quotemeta($entity->head->get('Body', 0));
#        my $view_link = "<a href=\"#\" onMouseOver=\"open_new_window(\'" . $messagehdr . "<br>" . $messagetxt . "\')\">View</a>";

            my $confirmation_link =
                "<a href="
              . $Plugin_Config->{Plugin_URL}
              . '?flavor=mod&list='
              . DADA::App::Guts::uriescape($list)
              . '&process=confirm&msg_id='
              . DADA::App::Guts::uriescape($messagename)
              . ">Accept</a>";

            my $deny_link =
                "<a href="
              . $Plugin_Config->{Plugin_URL}
              . '?flavor=mod&list='
              . DADA::App::Guts::uriescape($list)
              . '&process=deny&msg_id='
              . DADA::App::Guts::uriescape($messagename)
              . ">Reject</a>";

            print $confirmation_link . " or "
              . $deny_link . " - "
              . $messagehdr . "\n"
              if $verbose;
        }
    }

    print '</pre>';

    #    print '<p><a href="'
    #      . $Plugin_Config->{Plugin_URL}
    #      . ' ">Awaiting Message Index...</a></p>';
    #
    print admin_template_footer(
        -Form => 0,
        -List => $list,
    );
}

sub admin_cgi_manual_start_ajax {

    $run_list        = $list;
    $verbose         = 1;
    $check_deletions = 1;

    print $q->header();
    print '<pre>';     # DEV no like.
    start();
    print '</pre>';    # DEV no like.

}

sub cgi_mod {

    my ( $admin_list, $root_login, $checksout ) = check_list_security(
        -cgi_obj         => $q,
        -Function        => 'bridge',
        -manual_override => 1,
    );

    # $list is global, for some reason...
    # And I don't quite understand this. I think this is just so, if you're
    # logged in, you only work with the list you're logged into.
    # This gets annoying, since sometimes you just want to click the link to
    # moderate and go about your business.
    # For now, we'll just say, "Hey, you stink."
    if ( $list ne $q->param('list') ) {

#	print $q->header();
#	print
#	"<p>Gah. You're either logged into a different list, or not logged in at all!</p>";
        $checksout = 0;
    }

    # We'll use the list that's passed to us.
    $list = $q->param('list');

    if ($checksout) {
        print(
            admin_template_header(
                -Title      => "Moderation",
                -List       => $list,
                -Root_Login => $root_login
            )
        );
    }
    else {

        print list_template(
            -Part  => "header",
            -Title => "Moderation",
        );
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my $mod = SimpleModeration->new( { -List => $list } );
    my $msg_id = $q->param('msg_id');

    my $valid_msg = $mod->is_moderated_msg($msg_id);

    if ( $valid_msg == 1 ) {
        print "<p>Message appears to be valid and exists</p>";

        if ( $q->param('process') eq 'confirm' ) {
            my $g_msg = $mod->get_msg( { -msg_id => $msg_id } );
            process(
                {
                    -ls  => $ls,
                    -msg => \$g_msg,
                }
            );

            print "<p>Message has been sent!</p>";
            if ( $ls->param('send_moderation_accepted_msg') == 1 ) {
                print "<p>Sending acceptance message!</p>";
                $mod->send_accept_msg(
                    { -msg_id => $msg_id, -parser => $parser } );
            }

            $mod->remove_msg( { -msg_id => $msg_id } );

            #print "<p>Message has been sent!</p>";
        }
        elsif ( $q->param('process') eq 'deny' ) {

            print "<p>Message has been denied and being removed!</p>";
            if ( $ls->param('send_moderation_rejection_msg') == 1 ) {
                print "<p>Sending rejection message!</p>";

				# This is simply to get the Subject: header - 
				my $subject; 
				my $entity; 
				eval {
		            $entity = $parser->parse_data(
		                safely_encode( 
							$mod->get_msg( { -msg_id => $msg_id } ) 
						)
					);
		        };
		        if ( !$entity ) {
		            croak "no entity found!";
		        }
				else { 
				    $subject = $entity->head->get( 'Subject', 0 );
				}

                $mod->send_reject_msg(
                    {
                        -msg_id  => $msg_id,
                        -parser  => $parser,
                        -subject => $subject,
                    }
                );

            }

#gotta do this, after, since removing it will not make the send rejection message thing to work.

            $mod->remove_msg( { -msg_id => $msg_id } );

        }
        else {
            print "<p>Invalid action - wazzah?</p>";
        }

    }
    else {
        print
"<p>Moderated message doesn't exist - most likely it was already moderated.</p>";
    }

    if ($checksout) {

        print '<p><a href="'
          . $Plugin_Config->{Plugin_URL}
          . '?flavor=awaiting_msgs">Awaiting Message Index...</a></p>';

        print admin_template_footer(
            -Form => 0,
            -List => $list,
        );
    }
    else {
        print( list_template( -Part => "footer" ) );
    }

}

sub validate_list_email {

    my ($args) = @_;

    my $list = $args->{-list};
    if ( !exists( $args->{-list_email} ) ) {
        return ( 1, {} );
    }

    my $list_email = $args->{-list_email};

    $list_email = DADA::App::Guts::strip($list_email);
    my $status = 1;

    my @list_types = qw(
      list
      authorized_senders
    );

    # white_list
    # black_list

    my $errors = {
        list_email_set_to_list_owner_email => 0,
        list_email_set_to_list_admin_email => 0,
    };
    for (@list_types) {
        $errors->{ 'list_email_subscribed_to_' . $_ } = 0;
    }

    if ( $list_email eq '' ) {
        return ( 1, $errors );
    }

    require DADA::MailingList::Settings;
    require DADA::MailingList::Subscribers;

    for my $t_list ( available_lists() ) {

        my $ls = DADA::MailingList::Settings->new( { -list => $t_list } );
        if ( $ls->param('list_owner_email') eq $list_email ) {
            if ( $t_list eq $list ) {
                $errors->{list_email_set_to_list_owner_email} = 1;
            }
            else {
                $errors->{list_email_set_to_another_list_owner_email} = 1;
            }
            $status = 0;
        }
        if ( $ls->param('admin_email') eq $list_email ) {

            if ( $t_list eq $list ) {
                $errors->{list_email_set_to_list_admin_email} = 1;
            }
            else {
                $errors->{list_email_set_to_another_list_admin_email} = 1;
            }
            $status = 0;

        }
        my $lh = DADA::MailingList::Subscribers->new( { -list => $t_list } );

        for my $type (@list_types) {
            if (
                $lh->check_for_double_email(
                    -Email => $list_email,
                    -Type  => $type,
                ) == 1
              )
            {
                if ( $t_list eq $list_email ) {
                    $errors->{ 'list_email_subscribed_to_' . $type } = 1;
                }
                else {
                    $errors->{ 'list_email_subscribed_to_another_' . $type } =
                      1;
                }
                $status = 0;
            }
        }
    }

    #	use Data::Dumper;
    #	die Dumper([$status, $errors]);
    return ( $status, $errors );
}

sub cgi_default {

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    my %bridge_settings_defaults = (
        disable_discussion_sending                 => 0,
        group_list                                 => 0,
        prefix_list_name_to_subject                => 0,
        no_prefix_list_name_to_subject_in_archives => 0,
        discussion_pop_email                       => undef,
        bridge_list_email_type                     => 'pop3_account', 
        discussion_pop_server                      => undef,
        discussion_pop_username                    => undef,
        discussion_pop_password                    => undef,
        discussion_pop_auth_mode                   => undef,
        prefix_discussion_list_subjects_with       => '',
        enable_moderation                          => 0,
        moderate_discussion_lists_with             => 'list_owner_email',
        send_moderation_msg                        => 0,
        send_moderation_accepted_msg               => 0,
        send_moderation_rejection_msg              => 0,
        enable_authorized_sending                  => 0,
        authorized_sending_no_moderation           => 0,
        subscriber_sending_no_moderation           => 0,
        send_msgs_to_list                          => 0,
        send_msg_copy_to                           => 0,
        send_msg_copy_address                      => '',
        send_not_allowed_to_post_msg               => 0,
        send_invalid_msgs_to_owner                 => 0,
        mail_discussion_message_to_poster          => 0,
        strip_file_attachments                     => 0,
        file_attachments_to_strip                  => '',
        ignore_spam_messages                       => 0,
        ignore_spam_messages_with_status_of        => 0,
        rejected_spam_messages                     => 0,
        set_to_header_to_list_address              => 0,
        find_spam_assassin_score_by                => undef,
        open_discussion_list                       => 0,
        rewrite_anounce_from_header                => 0,
        discussion_pop_use_ssl                     => 0,
        discussion_template_defang                 => 0,
        discussion_clean_up_replies                => 0,
    );

    # Validation, basically.
    my $list_email_status = 1;
    my $list_email_errors = {};

    my $discussion_pop_password =
      DADA::Security::Password::cipher_decrypt( $ls->param('cipher_key'),
        $ls->param('discussion_pop_password') );

    if ( $q->param('process') eq 'edit' ) {
        ( $list_email_status, $list_email_errors ) = validate_list_email(
            {
                -list       => $list,
                -list_email => $q->param('discussion_pop_email'),
            }
        );

        if ( $list_email_status == 1 ) {

            if ( $Plugin_Config->{Allow_Open_Discussion_List} == 0 ) {
                $q->param( 'open_discussion_list', 0 );
            }
            else {
            }

            $q->param(
                'discussion_pop_password',
                DADA::Security::Password::cipher_encrypt(
                    $ls->param('cipher_key'),
                    $q->param('discussion_pop_password')
                )
            );

            $ls->save_w_params(
                {
                    -associate => $q,
                    -settings  => { %bridge_settings_defaults }
                }
            );

            print $q->redirect(
                -uri => $Plugin_Config->{Plugin_URL} . '?done=1' );
            return;
        }
        else {
            $q->param( 'done', 0 );
            $discussion_pop_password = $q->param('discussion_pop_password');
        }
    }
    else {

        # Not editing!
    }

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $auth_senders_count =
      $lh->num_subscribers( { -type => 'authorized_senders' } );
    my $show_authorized_senders_table = 1;
    my $authorized_senders            = [];

    if ( $auth_senders_count > 100 || $auth_senders_count == 0 ) {
        $show_authorized_senders_table = 0;
    }
    else {
        $authorized_senders =
          $lh->subscription_list( { -type => 'authorized_senders' } );
    }

    my $can_use_ssl = 0;
    eval { require IO::Socket::SSL };
    if ( !$@ ) {
        $can_use_ssl = 1;
    }

    my $discussion_pop_auth_mode_popup = $q->popup_menu(
        -id       => 'discussion_pop_auth_mode',
	    -name     => 'discussion_pop_auth_mode',

        -default  => $ls->param('discussion_pop_auth_mode'),
        '-values' => [qw(BEST PASS APOP CRAM-MD5)],
        -labels   => { BEST => 'Automatic' },
    );
    my $spam_level_popup_menu = $q->popup_menu(
        '-values' => [ 1 .. 50 ],
        -default  => $ls->param('ignore_spam_messages_with_status_of'),
        -name     => 'ignore_spam_messages_with_status_of',
    );

    my $curl_location = `which curl`;
    $curl_location = strip( make_safer($curl_location) );

    require DADA::Template::Widgets;

    my $mailing_list_message_from_phrase =
      $ls->param('mailing_list_message_from_phrase');
    $mailing_list_message_from_phrase = DADA::Template::Widgets::screen(
        {
            -data                     => \$mailing_list_message_from_phrase,
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            }
        }
    );
    my $mailing_list_message_from =
      Email::Address->new( $mailing_list_message_from_phrase,
        $ls->param('list_owner_email') )->format();

    my $done = $q->param('done') || 0;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -expr           => 1,
            -screen         => 'plugins/bridge/default.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {

                screen      => 'using_bridge',
                Plugin_URL  => $Plugin_Config->{Plugin_URL},
                Plugin_Name => $Plugin_Config->{Plugin_Name},
                Allow_Open_Discussion_List =>
                  $Plugin_Config->{Allow_Open_Discussion_List},
                Allow_Manual_Run    => $Plugin_Config->{Allow_Manual_Run},
                Plugin_URL          => $Plugin_Config->{Plugin_URL},
                Manual_Run_Passcode => $Plugin_Config->{Manual_Run_Passcode},

                curl_location                 => $curl_location,
                can_use_ssl                   => $can_use_ssl,
                done                          => $done,
                authorized_senders            => $authorized_senders,
                show_authorized_senders_table => $show_authorized_senders_table,

                discussion_pop_password => $discussion_pop_password,

                discussion_pop_auth_mode_popup =>
                  $discussion_pop_auth_mode_popup,
                can_use_spam_assassin => &can_use_spam_assassin(),
                spam_level_popup_menu => $spam_level_popup_menu,

                find_spam_assassin_score_by_calling_spamassassin_directly => (
                    $ls->param('find_spam_assassin_score_by') eq
                      'calling_spamassassin_directly'
                  ) ? 1 : 0,
                find_spam_assassin_score_by_looking_for_embedded_headers => (
                    $ls->param('find_spam_assassin_score_by') eq
                      'looking_for_embedded_headers'
                  ) ? 1 : 0,

                list_email_status         => $list_email_status,
                mailing_list_message_from => $mailing_list_message_from,

                error_list_email_set_to_list_owner_email =>
                  $list_email_errors->{list_email_set_to_list_owner_email},
                error_list_email_set_to_list_admin_email =>
                  $list_email_errors->{list_email_set_to_list_admin_email},
                error_list_email_subscribed_to_list =>
                  $list_email_errors->{list_email_subscribed_to_list},
                error_list_email_subscribed_to_authorized_senders =>
                  $list_email_errors
                  ->{list_email_subscribed_to_authorized_senders},

                error_list_email_set_to_another_list_owner_email =>
                  $list_email_errors
                  ->{list_email_set_to_another_list_owner_email},
                error_list_email_set_to_another_list_admin_email =>
                  $list_email_errors
                  ->{list_email_set_to_another_list_admin_email},
                error_list_email_subscribed_to_another_list =>
                  $list_email_errors->{list_email_subscribed_to_another_list},
                error_list_email_subscribed_to_another_authorized_senders =>
                  $list_email_errors
                  ->{list_email_subscribed_to_another_authorized_senders},
				 plugin_path => $FindBin::Bin, 
			     plugin_filename => 'bridge.cgi', 

            },
            -list_settings_vars_param => {
                -list                 => $list,
                -dot_it               => 1,
                -i_know_what_im_doing => 1,
            },
        }

    );
    e_print($scrn);

}

sub cl_main {

    init();
	if ($inject) {
		try { 
        	inject_msg();
		} catch { 
			carp "Problems with injecting message: $_"; 
		}
    }
    elsif ($test) {

        $verbose = 1;

        if ( $test eq 'pop3' ) {

            test_pop3();

        }
        else {

            print "I don't know what you want to test!\n\n";
            help();

        }

    }
    elsif ($help) {

        help();

    }
    else {

        start();

        require DADA::Mail::MailOut;

        if ($list) {

            DADA::Mail::MailOut::monitor_mailout(
                { -verbose => 0, -list => $list } );
        }
        else {

            DADA::Mail::MailOut::monitor_mailout( { -verbose => 0 } );

        }
    }

}

sub init { }

sub start {

    my @lists;

    if ( !$run_list ) {
        e_print(
"Running all lists - \nTo test an individual list, pass the list shortname in the '--list' parameter...\n\n"
        ) if $verbose;
        @lists = available_lists();
    }
    else {
        $lists[0] = $run_list;
    }

    require DADA::Mail::MailOut;
    my (
        $monitor_mailout_report, $total_mailouts,  $active_mailouts,
        $paused_mailouts,        $queued_mailouts, $inactive_mailouts
      )
      = DADA::Mail::MailOut::monitor_mailout(
        {
            -verbose => 0,
            -action  => 0,
        }
      );

    if ( $Plugin_Config->{Room_For_One_More_Check} == 1 ) {

        #/KLUDGE!
        if ( ( $active_mailouts + $queued_mailouts ) >=
            $DADA::Config::MAILOUT_AT_ONCE_LIMIT )
        {
            e_print("There are currently, "
                  . ( $active_mailouts + $queued_mailouts )
                  . " Mass Mailing(s) running or queued. Going to wait until that number falls below, "
                  . $DADA::Config::MAILOUT_AT_ONCE_LIMIT
                  . " Mass Mailing(s) \n" )
              if $verbose;
            return;
        }
        else {
            e_print("Currently, "
                  . ( $active_mailouts + $queued_mailouts )
                  . " Mass Mailing(s) running or queued. \n\n"
                  . "That's below our limit ($DADA::Config::MAILOUT_AT_ONCE_LIMIT). \n"
                  . "Checking awaiting  messages:\n\n" )
              if $verbose;
        }
    }
    else {
        e_print("Skipping, 'Room for one more?' check\n")
          if $verbose;
    }

    my $messages_viewed = 0;
  LIST_QUEUE: for my $list (@lists) {

        if ( $messages_viewed >= $Plugin_Config->{MessagesAtOnce} ) {
            e_print(
"\n\nThe limit has been reached of the amount of messages to be looked at for this execution\n\n"
            ) if $verbose;
            last;
        }

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        e_print("\n"
              . '-' x 72
              . "\nList: "
              . $ls->param('list_name') . '('
              . $list
              . ")\n" )
          if $verbose;

        if ( $ls->param('disable_discussion_sending') == 1 ) {
            e_print("\t* Bridge is not enabled for, $list \n") 
				if $verbose;
            next LIST_QUEUE;
        }
        if ( $ls->param('bridge_list_email_type') eq "mail_forward_pipe" ) {
            e_print("\t* List Email is set up as a Email Forward to Pipe to Bridge \n") 
				if $verbose;
            next LIST_QUEUE;
        }  
		if (
            $ls->param('discussion_pop_email') eq $ls->param('list_owner_email')
          )
        {
            e_print(
"\t\t***Warning!*** Misconfiguration of plugin! The list owner email cannot be the same address as the list email address!\n\t\tSkipping $list...\n"
            ) if $verbose;
            next LIST_QUEUE;
        }


    	if(!valid_login_information($ls)) { 
			e_print("\t\tLogin information doesn't seem to be valid. Make sure you've supplied everything needed: List Email, POP3 Server, POP3 Username, POP3 Password")
			 if $verbose; 
			next; 
		}



        my $lock_file_fh = undef;
        if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
            $lock_file_fh = DADA::App::POP3Tools::_lock_pop3_check(
                { name => 'bridge.lock' } );
        }



        my ( $pop3_obj, $pop3_status, $pop3_log ) = pop3_login($ls);

        e_print($pop3_log)
          if $verbose;
        if ( $pop3_status == 0 ) {
            e_print("\t* POP3 connection failed!\n")
              if $verbose;
            return;
        }



        my $msg_count = $pop3_obj->Count;
        my $msgnums   = {};

        # This is weird - do we get everything out of order, here?
        for ( my $cntr = 1 ; $cntr <= $msg_count ; $cntr++ ) {
            my ( $msg_num, $msg_size ) =
              split( '\s+', $pop3_obj->List($cntr) );
            $msgnums->{$msg_num} = $msg_size;
        }

        my $local_msg_viewed = 0;



        # Hmm, we do, but then we sort them numerically here:
      MSG_QUEUE: for my $msgnum ( sort { $a <=> $b } keys %$msgnums ) {

            if ( $messages_viewed >= $Plugin_Config->{MessagesAtOnce} ) {
                last;
            }
            $messages_viewed++;



            $local_msg_viewed++;
            e_print( "\t* Message Size: " . $msgnums->{$msgnum} . "\n" )
              if $verbose;

            if ( max_msg_test( { -size => $msgnums->{$msgnum} } ) == 0 ) {

                # We don't do anything else to this guy
                next MSG_QUEUE;
            }

            my $full_msg = $pop3_obj->Retrieve($msgnum);

            # We're taking a guess on this decoding:
            $full_msg = safely_decode($full_msg);

            push( @{ $checksums->{$list} }, create_checksum( \$full_msg ) );

            if ( soft_max_msg_test( { -size => $msgnums->{$msgnum} } ) == 0 ) {
                send_msg_too_big( $ls, \$full_msg, $msgnums->{$msgnum} );
                next MSG_QUEUE;
            }

            eval {

                # The below line is just for testing purposes...
                # die "aaaaaaarrrrgggghhhhh!!!";

                my ( $status, $errors ) = validate_msg( $ls, \$full_msg );

                if ($status) {

                    process(
                        {
                            -ls  => $ls,
                            -msg => \$full_msg,
                        }
                    );

                }
                else {

                    e_print(
"\t* Message did not pass verification - handling issues...\n"
                    ) if $verbose;

                    handle_errors( $ls, $errors, $full_msg );

                }

                append_message_to_file( $ls, $full_msg );

            };

            if ($@) {

                warn
"bridge.cgi - irrecoverable error processing message. Skipping message (sorry!): $@";
                e_print(
"bridge.cgi - irrecoverable error processing message. Skipping message (sorry!): $@"
                ) if $verbose;

            }

        }    # MSG_QUEUE

        my $delete_msg_count = 0;

        for my $msgnum_d ( sort { $a <=> $b } keys %$msgnums ) {
            e_print("\t* Removing message from server...\n")
              if $verbose;
            $pop3_obj->Delete($msgnum_d);
            $delete_msg_count++;

            last
              if $delete_msg_count >= $local_msg_viewed;

        }
        e_print("\t* Disconnecting from POP3 server\n")
          if $verbose;

        $pop3_obj->Close();

        if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
            DADA::App::POP3Tools::_unlock_pop3_check(
                {
                    name => 'bridge.lock',
                    fh   => $lock_file_fh,
                }
            );
        }

        if ($check_deletions) {
            if ( keys %$msgnums ) {
                message_was_deleted_check($ls);
            }
            else {
                e_print("\t* No messages received, skipping deletion check.\n")
                  if $verbose;
            }
        }
    }    # LIST_QUEUE?

}

sub max_msg_test {
    my ($args) = @_;
    my $size = $args->{-size};

    if ( $size > $Plugin_Config->{Max_Size_Of_Any_Message} ) {

        e_print("\t* Warning! Message size ( " 
              . $size
              . " ) is larger than the maximum size allowed ( "
              . $Plugin_Config->{Max_Size_Of_Any_Message}
              . " )\n" )
          if $verbose;
        warn "bridge.cgi Warning! Message size ( " 
          . $size
          . " ) is larger than the maximum size allowed ( "
          . $Plugin_Config->{Max_Size_Of_Any_Message} . ")";
        return 0;
    }
    else {
        return 1;
    }

}

sub soft_max_msg_test {

    my ($args) = @_;
    my $size = $args->{-size};
    if ( $size > $Plugin_Config->{Soft_Max_Size_Of_Any_Message} ) {

        e_print("\t* Warning! Message size ( " 
              . $size
              . " ) is larger than the soft maximum size allowed ( "
              . $Plugin_Config->{Soft_Max_Size_Of_Any_Message}
              . " )\n" )
          if $verbose;
        warn "bridge.cgi Warning! Message size ( " 
          . $size
          . " ) is larger than the soft maximum size allowed ( "
          . $Plugin_Config->{Soft_Max_Size_Of_Any_Message} . ")";

        return 0;
    }
    else {
        return 1;
    }

}

sub inject_msg {

    my $list = $run_list;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    require DADA::Security::Password;
    my $filename =
        $DADA::Config::TMP
      . "/tmp_file"
      . DADA::Security::Password::generate_rand_string() . "-"
      . time . ".txt";

    open my $tmp_file, ">", $filename or die $!;
    my $msg;
    while ( my $line = <STDIN> ) {
        print $tmp_file $line;
    }
    close $tmp_file or die $!;
	chmod($DADA::Config::FILE_CHMOD , $filename); 
	
    my $size = ( stat($filename) )[7];
    if ( max_msg_test( { -size => $size } ) == 0 ) {
        return;
    }
    require File::Slurp;
    my $msg = File::Slurp::read_file($filename);
    my $n = unlink($filename);
	if($n != 1){ 
		carp "could not remove tmpfile at, $filename"; 
	}
	
	
	if ( $ls->param('bridge_list_email_type') ne "mail_forward_pipe" ) {
        e_print("\t* Bridge is not enabled to receive mail this way, for this list. \n") 
			if $verbose;
				carp "Bridge is not enabled to receive mail this way, for this list."; 
    }
	else { 
  	  if ( soft_max_msg_test( { -size => $size } ) == 0 ) {
	        send_msg_too_big( $ls, \$msg, $size );
	    }
	    else {

	        inject(
	            {
	                -ls        => $ls,
	                -msg       => $msg,
	                -verbose   => $verbose,
	                -test_mail => $test,
	            }
	        );
	    }
	}
}


sub message_was_deleted_check {

    # DEV: Nice for testing...
    #return;

    e_print("\n\t* Waiting 5 seconds before removal check...\n")
      if $verbose;

    sleep(5);

    my $ls = shift;

    my $lock_file_fh = undef;
    if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
        $lock_file_fh =
          DADA::App::POP3Tools::_lock_pop3_check( { name => 'bridge.lock', } );
    }

    my ( $pop3_obj, $pop3_status, $pop3_log ) = pop3_login($ls);

    if ( $pop3_status == 1 ) {

        my $msg_count = $pop3_obj->Count;
        my $msgnums   = {};

        for ( my $cntr = 1 ; $cntr <= $msg_count ; $cntr++ ) {
            my ( $msg_num, $msg_size ) = split( '\s+', $pop3_obj->List($cntr) );
            $msgnums->{$msg_num} = $msg_size;
        }

        for my $msgnum ( sort { $a <=> $b } keys %$msgnums ) {
            my $msg = $pop3_obj->Retrieve($msgnum);

            my $cs = create_checksum( \$msg );

            e_print("\t\tcs:             $cs\n")
              if $verbose;

            my @cs;
            if ( defined( @{ $checksums->{$list} } ) ) {
                @cs = @{ $checksums->{$list} };
            }

            for my $s_cs (@cs) {

                e_print("\t\tsaved checksum: $s_cs\n")
                  if $verbose;

                if ( $cs eq $s_cs ) {
                    e_print(
"\t* Message was NOT deleted from POP server! Will attempt to do that now...\n"
                    ) if $verbose;
                    $pop3_obj->Delete($msgnum);
                }
                else {
                    e_print(
"\t* Message checksum does not match saved checksum, keeping message for later delivery...\n"
                    ) if $verbose;
                }
            }
        }
        $pop3_obj->Close();

    }
    else {
        e_print("POP3 login failed.\n");
    }

    if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
        DADA::App::POP3Tools::_unlock_pop3_check(
            {
                name => 'bridge.lock',
                fh   => $lock_file_fh,
            }
        );
    }

}

sub help {
    print q{ 

arguments: 
-----------------------------------------------------------
--help                 		
--verbose
--test pop3
--inject

-----------------------------------------------------------
for a general overview and more instructions, try:

pod2text ./bridge.cgi | less

-----------------------------------------------------------

--help

Displays a help menu.

--list

Will allow you to work on one list at a time, instead of all the lists you 
have. 

--verbose 

Runs the script in verbose mode. 

--test pop3

Allows you to test the pop3 login information on the command line. 
Currently the only test available. 

Example: 

 prompt>bridge.cgi --test pop3 --list yourlistshortname

Will test the pop3 connection of a list with a shortname of, 
yourlistshortname

Another Example: 

 prompt>bridge.cgi --verbose --list yourlistshortname

Will check for messages to deliver for list, 
yourlistshortname> and outputting a lot of information on the command line. 

--inject

When this flag is passed, Bridge will then read a full email message from STDIN, and process the message it receives. You will need to also pass the, --list paramater. 

This flag will only work if you have set your mailing list to use a  Email Forward as its List Email, and not a POP3 Account. 

};
    exit;
}

sub test_pop3 {

    my @lists;

    if ( !$run_list ) {
        e_print(
"Testing all lists - \nTo test an individual list, pass the list shortname in the '--list' parameter...\n\n"
        );
        @lists = available_lists();
    }
    else {
        push( @lists, $run_list );
    }

    for my $l (@lists) {

        e_print( "\n" . '-' x 72 . "\nTesting List: '" . $l . "'\n" );

        unless ( check_if_list_exists( -List => $l, ) ) {
            e_print("'$l' does not exist! - skipping\n");
            next;
        }

        my $ls = DADA::MailingList::Settings->new( { -list => $l } );

        my $lock_file_fh = undef;
        if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {

            $lock_file_fh = DADA::App::POP3Tools::_lock_pop3_check(
                { name => 'bridge.lock', } );
        }

        my ( $pop3_obj, $pop3_status, $pop3_log ) = pop3_login($ls);
        e_print($pop3_log)
          if $verbose;
        if ( $pop3_status == 1 ) {
            $pop3_obj->Close();

            if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
                DADA::App::POP3Tools::_unlock_pop3_check(
                    {
                        name => 'bridge.lock',
                        fh   => $lock_file_fh,
                    }
                );
            }
            e_print("\tLogging off of the POP Server.\n");
        }

    }
    e_print("\n\nPOP3 Login Test Complete.\n\n");
}

sub pop3_login {
    my $ls = shift;
    my $password =
      DADA::Security::Password::cipher_decrypt( $ls->param('cipher_key'),
        $ls->param('discussion_pop_password') );

    if ( !valid_login_information($ls) ) {
        e_print(
"Some POP3 Login Information is missing - please double check! (aborting login attempt)\n"
        ) if $verbose;
        return undef;
    }
    else {

        my $pop;
        my $status;
        my $log;

        eval {
            ( $pop, $status, $log ) =
              DADA::App::POP3Tools::mail_pop3client_login(
                {
                    server    => $ls->param('discussion_pop_server'),
                    username  => $ls->param('discussion_pop_username'),
                    password  => $password,
                    verbose   => $verbose,
                    USESSL    => $ls->param('discussion_pop_use_ssl'),
                    AUTH_MODE => $ls->param('discussion_pop_auth_mode'),
                }
              );
        };
        if ( !$@ ) {
            return ( $pop, $status, $log );
        }
        else {
            e_print("Problems Logging in:\n$@")
              if $verbose;
            warn $@;
            return undef;
        }

    }
}

sub valid_login_information {

    my $ls = shift;
    return 0 if ! defined($ls->param('discussion_pop_server'));
    return 0 if ! defined(!$ls->param('discussion_pop_username'));
    return 0 if ! defined(!$ls->param('discussion_pop_email'));
    return 0 if ! defined(!$ls->param('discussion_pop_password'));
    return 1;
}

sub validate_msg {

    my $ls       = shift;
    my $test_msg = shift;           #ref
    my $msg      = ${$test_msg};    # copy of orig

    my $status = 1;
    my $notice = undef;

    # DEV:
    # This should *really* mention each and every test....

    my $errors = {
        multiple_from_addresses                  => 0,
        msg_from_list_address                    => 0,
        list_email_address_is_list_owner_address => 0,
        invalid_msg                              => 0,
        multiple_return_path_headers             => 0,
        x_been_there_header_found                => 0,
        msg_not_from_list_owner                  => 0,
        needs_moderation                         => 0,
        subscribed                               => 0,
        msg_not_from_subscriber                  => 0,
        msg_not_from_list_owner                  => 0,
        msg_not_from_an_authorized_sender        => 0,
        message_seen_as_spam                     => 0,
    };

    my $lh =
      DADA::MailingList::Subscribers->new( { -list => $ls->param('list') } );

    if ( lc_email( $ls->param('discussion_pop_email') ) eq
        lc_email( $ls->param('list_owner_email') ) )
    {
        print
"\t\t***Warning!*** Misconfiguration of plugin! The list owner email cannot be the same address as the list email address!\n"
          if $verbose;
        $errors->{list_email_address_is_list_owner_address} = 1;
    }

    my $message_is_blank = 0;

    if ( !defined($msg) ) {
        $message_is_blank = 1;
    }
    elsif ( $msg eq '' ) {
        $message_is_blank = 1;
    }
    elsif ( length($msg) == 0 ) {
        $message_is_blank = 1;
    }
    if ($message_is_blank) {
        print "\t\t***Warning!*** Message is blank.\n"
          if $verbose;
        $errors->{blank_message} = 1;
        return ( 0, $errors );
    }

    my $entity;
    $msg = safely_encode($msg);

    eval { $entity = $parser->parse_data($msg); };

    if ( !$entity ) {
        print "\t\tMessage invalid! - no entity found.\n" if $verbose;
        $errors->{invalid_msg} = 1;

        #if($verbose){
        #	print "All Errors: \n" . '-' x 72 . "\n";
        #	for(keys %$errors){
        #		"\t*" . $_ . ' => '  . $errors->{$_} . "\n";
        #	}
        #}
        return ( 0, $errors );
    }

  # These checks make sure that multiple From: headers and addresses don't exist
    if ( $Plugin_Config->{Check_Multiple_From_Addresses} == 1 ) {
        eval {
            if ( $entity->head->count('From') > 1 )
            {
                print
"\t\tMessage has more than one 'From' header? Unsupported email message - will reject!\n"
                  if $verbose;
                $errors->{multiple_from_addresses} = 1;

            }
            else {
                my @count =
                  Email::Address->parse( $entity->head->get( 'From', 0 ) );
                if ( scalar(@count) > 1 ) {
                    print
"\t\tMessage has more than one 'From' header? Unsupported email message - will reject!\n"
                      if $verbose;
                    $errors->{multiple_from_addresses} = 1;
                }
            }
        };
        if ($@) {
            print
"\t\tError with multiple from address check! Marking as a problem! - $@"
              if $verbose;
            $errors->{multiple_from_addresses} = 1;

        }
    }

 # /These checks make sure that multiple From: headers and addresses don't exist

    if ( $Plugin_Config->{Check_Multiple_Return_Path_Headers} == 1 ) {

        if ( $entity->head->count('Return-Path') > 1 ) {
            print
"\t\tMessage has more than one 'Return-Path' header? Malformed email message - will reject!\n"
              if $verbose;
            $errors->{multiple_return_path_headers} = 1;
        }

    }

    if ( $entity->head->count('X-BeenThere') ) {
        my $x_been_there_header = $entity->head->get( 'X-BeenThere', 0 );
        chomp($x_been_there_header);

        if ( lc_email($x_been_there_header) eq
            lc_email( $ls->param('discussion_pop_email') ) )
        {
            print
"\t* Message is from myself (the, X-BeenThere header has been set), message should be ignored...\n"
              if $verbose;
            $errors->{x_been_there_header_found} = 1;
        }
        else {
            $errors->{x_been_there_header_found} = 0;
        }

    }

    my $rough_from = $entity->head->get( 'From', 0 );
    my $from_address = '';

    if ( defined($rough_from) ) {
        eval {

            # This correct ?
            $from_address = ( Email::Address->parse($rough_from) )[0]->address;
        };
    }
    else {

        # ...
    }

    print '\t*Warning! Something\'s wrong with the From address - ' . $@
      if $@ && $verbose;

    $from_address = lc_email($from_address);

    print "\t* Message is from: '" . $from_address . "'\n"
      if $verbose;

    if ( lc_email($from_address) eq lc_email( $ls->param('list_owner_email') ) )
    {
        print "\t* From: address is the list owner address ("
          . $ls->param('list_owner_email') . ")\n"
          if $verbose;

        if ( $Plugin_Config->{Check_List_Owner_Return_Path_Header} ) {
            ( $errors, $notice ) =
              test_Check_List_Owner_Return_Path_Header( $ls, $entity, $errors );
            print $notice
              if $verbose;
        }

    }
    else {

        print "\t* From address is NOT from list owner address\n"
          if $verbose;
        $errors->{msg_not_from_list_owner} = 1;

        if ( $ls->param('enable_moderation') ) {
            print "\t* Moderation enabled...\n"
              if $verbose;
            $errors->{needs_moderation} = 1;

            #}

        }
        else {
            print "\t* Moderation disabled...\n"
              if $verbose;
        }

        if ( $ls->param('group_list') == 1 ) {

            print "\t* Discussion List Support enabled...\n"
              if $verbose;

#if($li->{enable_authorized_sending} && $errors->{msg_not_from_an_authorized_sender} == 0){
#
#	print "\t\tSubscription checked skipped - authorized sending enabled and address passed validation.\n"
#	    if $verbose;
#
#}else{

            my ( $s_status, $s_errors ) =
              $lh->subscription_check( { -email => $from_address, } );

            if ( $s_errors->{subscribed} == 1 ) {
                print "\t* Message *is* from a current subscriber.\n"
                  if $verbose;
                $errors->{msg_not_from_list_owner} = 0;
                if ( $ls->param('subscriber_sending_no_moderation') ) {
                    $errors->{needs_moderation} = 0;
                }
                elsif ( $errors->{needs_moderation} == 1 ) {
                    print "\t* However, message still *requires* moderation!\n"
                      if $verbose;
                }
            }
            else {
                print "\t* Message is NOT from a subscriber.\n"
                  if $verbose;
                if (   $ls->param('open_discussion_list') == 1
                    && $Plugin_Config->{Allow_Open_Discussion_List} == 1 )
                {
                    print "\t* Postings from non-subscribers is enabled...\n"
                      if $verbose;
                    $errors->{msg_not_from_list_owner} = 0;
                }
                else {
                    $errors->{msg_not_from_subscriber} = 1;
                }
            }

            #}

        }
        else {
            print "\t* Discussion Support disabled...\n"
              if $verbose;
        }
    }

    if ( $ls->param('enable_authorized_sending') == 1 ) {

        # cancel out other errors???
        print "\t* Authorized Senders List enabled...\n"
          if $verbose;
        my ( $m_status, $m_errors ) = $lh->subscription_check(
            {
                -email => $from_address,
                -type  => 'authorized_senders',
            }
        );
        if ( $m_errors->{subscribed} == 1 ) {
            print "\t * Message *is* from an Authorized Sender!\n"
              if $verbose;
            $errors->{msg_not_from_list_owner} = 0;
            $errors->{msg_not_from_subscriber} = 0;
            if ( $ls->param('authorized_sending_no_moderation') ) {
                $errors->{needs_moderation} = 0;
            }
            elsif ( $errors->{needs_moderation} == 1 ) {
                print "\t * however Message still *requires* moderation!\n"
                  if $verbose;
            }
        }
        else {
            print "\t* Message is NOT from an Authorized Sender!\n"
              if $verbose;
        }
    }
    else {
        print "\t* Authorized Senders List disabled...\n"
          if $verbose;
    }

    if ( $ls->param('ignore_spam_messages') == 1 ) {
        print "\t* SpamAssassin check enabled...\n"
          if $verbose;

        if ( $ls->param('find_spam_assassin_score_by') eq
            'calling_spamassassin_directly' )
        {

            print "\t* Loading SpamAssassin directly...\n"
              if $verbose;

            eval { require Mail::SpamAssassin; };
            if ( !$@ ) {

                if ( $Mail::SpamAssassin::VERSION <= 2.60 && $Mail::SpamAssassin::VERSION >= 2 ) {
                    require Mail::SpamAssassin::NoMailAudit;

                    # this needs to be optimized...
                    my $spam_check_message = $entity->as_string;
                    $spam_check_message = safely_decode($spam_check_message);

                    my @spam_check_message =
                      split( "\n", $spam_check_message );

                    my $mail =
                      Mail::SpamAssassin::NoMailAudit->new(
                        data => \@spam_check_message );

                    my $spamtest = Mail::SpamAssassin->new(
                        {

                            # debug            => 'all',
                            local_tests_only => 1,
                            dont_copy_prefs  => 1,
                        }
                    );

                    my $score;
                    my $report;

                    if ($spamtest) {
                        my $spam_status;
                        $spam_status = $spamtest->check($mail);

                        if ($spam_status) {
                            $score  = $spam_status->get_hits();
                            $report = $spam_status->get_report();
                        }

                    }

                    if ( $score eq undef && $score != 0 ) {
                        print
"\t* Trouble parsing scoring information - letting message pass...\n"
                          if $verbose

                    }
                    else {

                        if ( $score >=
                            $ls->param('ignore_spam_messages_with_status_of') )
                        {
                            print
"\t*  Message has *failed* Spam Test (Score of: $score, "
                              . $ls->param(
                                'ignore_spam_messages_with_status_of')
                              . " needed.) - ignoring message.\n"
                              if $verbose;

                            $errors->{message_seen_as_spam} = 1;

                            print "\n" . $report
                              if $verbose;

                        }
                        else {
                            $errors->{message_seen_as_spam} = 0;

                            print
"\t* Message passed! Spam Test (Score of: $score, "
                              . $ls->param(
                                'ignore_spam_messages_with_status_of')
                              . " needed.)\n"
                              if $verbose;
                        }

                    }

                    undef $mail;
                    undef $spamtest;
                    undef $score;
                    undef $report;

                }
                elsif ( $Mail::SpamAssassin::VERSION >= 3 ) {

                    my $spam_check_message = $entity->as_string;
                    my $spamtest           = Mail::SpamAssassin->new(
                        {

                         #                            debug            => 'all',
                            local_tests_only => 1,
                            dont_copy_prefs  => 1,

                            # userstate_dir    => '/home/hhbc/private/',
                        }
                    );
                    my $mail        = $spamtest->parse($spam_check_message);
                    my $spam_status = $spamtest->check($mail);

                    my $score  = $spam_status->get_score();
                    my $report = $spam_status->get_report();

                    if ( $score eq undef && $score != 0 ) {
                        print
"\t* Trouble parsing scoring information - letting message pass...\n"
                          if $verbose;
                    }
                    else {

                        if (
                            (
                                $score >= $ls->param(
                                    'ignore_spam_messages_with_status_of')
                            )
                            || $spam_status->is_spam()
                          )
                        {
                            print
"\t* Message has *failed* Spam Test (Score of: $score, "
                              . $ls->param(
                                'ignore_spam_messages_with_status_of')
                              . " needed.) - ignoring message.\n"
                              if $verbose;

                            $errors->{message_seen_as_spam} = 1;

                            print "\n" . $report
                              if $verbose;
                        }
                        else {
                            $errors->{message_seen_as_spam} = 0;

                            print
"\t* Message passed! Spam Test (Score of: $score, "
                              . $ls->param(
                                'ignore_spam_messages_with_status_of')
                              . " needed.)\n"
                              if $verbose;
                        }
                    }

                    $spam_status->finish;
                    $mail->finish;
                    $spamtest->finish;
                    undef $score;
                    undef $report;
                }
                else {
                    print
"\t* SpamAssassin 2.x and 3.x are currently supported, you have version $Mail::SpamAssassin::VERSION, skipping test\n"
                      if $verbose;
                }

            }
            else {
                print
"\t* SpamAssassin doesn't seem to be available. Skipping test.\n"
                  if $verbose;
            }

        }
        elsif ( $ls->param('find_spam_assassin_score_by') eq
            'looking_for_embedded_headers' )
        {

            print "\t* Looking for embedding SpamAssassin Headers...\n"
              if $verbose;

            my $score = undef;
            if ( $entity->head->count('X-Spam-Status') ) {

                my @x_spam_status_fields =
                  split( ' ', $entity->head->get( 'X-Spam-Status', 0 ) );
                for (@x_spam_status_fields) {
                    if ( $_ =~ m/score\=/ ) {
                        $score = $_;
                        $score =~ s/score\=//;

                        print "\t* Found them...\n"
                          if $verbose;

                        last;

                    }
                }
            }

            if ( $score eq undef && $score != 0 ) {

                print
"\t* Trouble parsing scoring information - letting message pass...\n"
                  if $verbose

            }
            else {

                if ( $score >=
                    $ls->param('ignore_spam_messages_with_status_of') )
                {
                    print
                      "\t*  Message has *failed* Spam Test (Score of: $score, "
                      . $ls->param('ignore_spam_messages_with_status_of')
                      . " needed.) - ignoring message.\n"
                      if $verbose;

                    $errors->{message_seen_as_spam} = 1;

                    if ($verbose) {
                        my @x_spam_report = $entity->head->get('X-Spam-Report');
                        print "\n\t";
                        print "$_\n" for @x_spam_report;
                    }

                }
                else {
                    $errors->{message_seen_as_spam} = 0;

                    print "\t*  Message passed! Spam Test (Score of: $score, "
                      . $ls->param('ignore_spam_messages_with_status_of')
                      . " needed.)\n"
                      if $verbose;
                }

            }
        }
        else {

            print "\t* Don't know how to find the SpamAssassin score, sorry!\n"
              if $verbose;

        }

    }
    else {
        print "\t* SpamAssassin check disabled...\n"
          if $verbose;
    }

    print "\n"
      if $verbose;

    # This below probably can't happen anymore...
    if ( lc_email( $ls->param('discussion_pop_email') ) eq
        lc_email($from_address) )
    {
        $errors->{msg_from_list_address} = 1;
        print "\t* *WARNING!* Message is from the List Address. That's bad.\n"
          if $verbose;
    }

    for ( keys %$errors ) {
        if ( $errors->{$_} == 1 ) {
            $status = 0;
            last;
        }
    }

    #if($verbose){
    #	print "All Errors: \n" . '-' x 72 . "\n";
    #	for(keys %$errors){
    #		"\t*" . $_ . ' => '  . $errors->{$_} . "\n";
    #	}
    #}
    return ( $status, $errors );
}

sub test_Check_List_Owner_Return_Path_Header {

    my $ls     = shift;
    my $entity = shift;
    my $errors = shift;
    my $notice = 0;

    require Email::Address;

    # This has been copied from the main thingy,
    my $rough_from = $entity->head->get( 'From', 0 );

    #$notice .= '$rough_from: ' . $rough_from;
    my $from_address = '';

    if ( defined($rough_from) ) {

        eval {
            $from_address = ( Email::Address->parse($rough_from) )[0]->address;
        };
    }

    $notice .= '\t\tWarning! Something\'s wrong with the From address - ' . $@
      if $@ && $verbose;

    $from_address = lc_email($from_address);

    # $notice .= '$from_address:  ' . $from_address;

    # /This has been copied from the main thingy,

    my $rough_return_path = undef;

    if ( $entity->head->get( 'Return-Path', 0 ) ) {

# I haven't a clue what this is.
# $notice .= q{$entity->head->get( 'Return-Path', 0 ) } . $entity->head->get( 'Return-Path', 0 );
        $rough_return_path = $entity->head->get( 'Return-Path', 0 );
    }
    else {

        # Strange, but there is no return-path... why?
        $notice .= "\t\t * No Return Path Found - Skipping Test\n";
        $errors->{list_owner_return_path_set_funny} = 0;
        return ( $errors, $notice );
    }

    my $return_path_address = '';

    if ( defined($rough_return_path) ) {

        eval {
            $return_path_address =
              ( Email::Address->parse($rough_return_path) )[0]->address;
        };
    }
    $return_path_address = lc_email($return_path_address);

    if ( lc_email($from_address) eq lc_email($return_path_address) ) {

        $errors->{list_owner_return_path_set_funny} = 0;

        $notice .=
"\t\t * Address set in, From: header, ($from_address) matches, Return-Path address ($return_path_address) Yeah!\n"
          if $verbose;

    }
    else {

        $notice .=
"\t\t * Address set in, From: header, ($from_address) doesn't match, Return-Path address ($return_path_address) ? Why?\n"
          if $verbose;
        warn
"\t\t * Address set in, From: header, ($from_address) doesn't match, Return-Path address ($return_path_address) ? Why?\n";

        if ( lc_email($return_path_address) eq
            lc_email( $ls->param('admin_email') ) )
        {

            $notice .=
"\t\tAh! Ok, The Return-Path is set to the list administrator - I guess that's ok...."
              if $verbose;
            warn
"\t\tAh! Ok, The Return-Path is set to the list administrator - I guess that's ok....";

            $errors->{list_owner_return_path_set_funny} = 0;

        }
        else {

            $errors->{list_owner_return_path_set_funny} = 1;

        }
    }

    return ( $errors, $notice );

   #return ({list_owner_return_path_set_funny => 1}, "This here is my notice.");

}

sub send_msg_too_big {
    my $ls           = shift;
    my $full_msg_ref = shift;
    my $size         = shift;
    my $entity;

    eval {
        $entity = $parser->parse_data($$full_msg_ref);
        if ( !$entity ) {
            warn "couldn't create a new entity in send_msg_too_big, passing.";
        }

        my $from_address =
          ( Email::Address->parse( $entity->head->get( 'From', 0 ) ) )[0]
          ->address;

        require DADA::App::Messages;
        DADA::App::Messages::send_generic_email(
            {
                -list    => $ls->param('list'),
                -headers => {
                    To      => $from_address,
                    Subject => $ls->param('msg_too_big_msg_subject'),
                },
                -body        => $ls->param('msg_too_big_msg'),
                -tmpl_params => {
                    -list_settings_vars_param =>
                      { -list => $ls->param('list'), -dot_it => 1, },

                    -subscriber_vars =>
                      { 'subscriber.email' => $from_address, },
                    -vars => {
                        original_subject => $entity->head->get( 'Subject', 0 ),
                        size_of_original_message =>
                          sprintf( "%.1f", ( $size / 1024 ) ),
                        Soft_Max_Size_Of_Any_Message => sprintf(
                            "%.1f",
                            (
                                $Plugin_Config->{Soft_Max_Size_Of_Any_Message} /
                                  1024
                            )
                        ),
                    }
                }
            }
        );
    };

    if ( !$@ ) {
        return 1;
    }
    else {
        warn "Wasn't able to process message in send_msg_too_big: $@";
        return 0;
    }

}

sub process {

    my ($args) = @_;

    if ( !exists( $args->{-ls} ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{-msg} ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $test_mail = 0;
    if ( exists( $args->{-test_mail} ) ) {
        $test_mail = $args->{-test_mail};
    }

    my $ls = $args->{-ls};

    # $msg is a scalarref
    my $msg = $args->{-msg};

    print "\t* Processing Message...\n"
      if $verbose;

    if ( $ls->param('send_msgs_to_list') == 1 ) {

        my $n_msg = dm_format(
            {
                -ls  => $ls,
                -msg => $msg,    #scalarref
            }
        );

        print "\t* Message being delivered! \n"
          if $verbose;

        my ( $msg_id, $saved_message ) = deliver(
            {
                -ls        => $ls,
                -msg       => $n_msg,
                -test_mail => $test_mail,
            }
        );
        archive(
            {
                -ls        => $ls,
                -msg       => $n_msg,
                -msg_id    => $msg_id,
                -saved_msg => $saved_message
            }
        );
    }

    if (   $ls->param('send_msg_copy_to')
        && $ls->param('send_msg_copy_address') )
    {
        print "\t* Sending a copy of the message to: "
          . $ls->param('send_msg_copy_address') . "\n"
          if $verbose;

        deliver_copy(
            {
                -ls  => $ls,
                -msg => $msg,
            }
        );
    }

    print "\t* Finished Processing Message.\n\n"
      if $verbose;

}

sub dm_format {

    my ($args) = @_;

    if ( !exists( $args->{-ls} ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{-msg} ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $ls  = $args->{-ls};
    my $msg = $args->{-msg};    # scalarref

    if ( $ls->param('strip_file_attachments') == 1 ) {
        $msg = strip_file_attachments( $msg, $ls );
    }

    require DADA::App::FormatMessages;

    my $fm = DADA::App::FormatMessages->new( -List => $ls->param('list') );
    $fm->mass_mailing(1);

    if (   $ls->param('group_list') == 0
        && $ls->param('rewrite_anounce_from_header') == 0 )
    {
        $fm->reset_from_header(0);
    }

    my ( $header_str, $body_str ) = $fm->format_headers_and_body(
        -msg             => ${$msg},
        -convert_charset => 1,
    );

    # not a scalarref (duh)
    my $all_together = $header_str . "\n\n" . $body_str;
    return $all_together;

}

sub strip_file_attachments {

    my $msg = shift;    #ref
    my $ls  = shift;

    my $entity;

    eval { $entity = $parser->parse_data( ${$msg} ) };
    if ( !$entity ) {
        die "no entity found! die'ing!";
    }

    print "\t* Stripping banned file attachments...\n\n"
      if $verbose;

    ( $entity, $ls ) = process_stripping_file_attachments( $entity, $ls );

    my $un = $entity->as_string;
    $un = safely_decode($un);
    return \$un;
}

sub process_stripping_file_attachments {

    my $entity = shift;
    my $ls     = shift;

    my @att_bl = split( ' ', $ls->param('file_attachments_to_strip') );
    my $lt = {};

    for (@att_bl) {
        $lt->{ lc($_) } = 1;
    }

    my @parts = $entity->parts;

    if (@parts) {

        # multipart...
        my $i;
        for $i ( 0 .. $#parts ) {
            ( $parts[$i], $ls ) =
              process_stripping_file_attachments( $parts[$i], $ls );

        }

        my @new_parts;

        for $i ( 0 .. $#parts ) {
            if ( !$parts[$i] ) {

            }
            else {

                push( @new_parts, $parts[$i] );
            }
        }

        $entity->parts( \@new_parts );

        $entity->sync_headers(
            'Length'      => 'COMPUTE',
            'Nonstandard' => 'ERASE'
        );

        return ( $entity, $ls );

    }
    else {

        my $name = $entity->head->mime_attr("content-type.name")
          || $entity->head->mime_attr("content-disposition.filename");

        my $f_ending = $name;
        $f_ending =~ s/(.*)\.//g;

        if (
               $lt->{ lc( $entity->head->mime_type ) } == 1
            || $lt->{ lc($f_ending) } == 1
            || $lt->{ '.' . lc($f_ending) } == 1

          )
        {

            print
"\t* Stripping attachment with:\n\t\t* name: $name \n\t\t* MIME-Type: "
              . $entity->head->mime_type . "\n"
              if $verbose;

            return ( undef, $ls );
        }

        $entity->sync_headers(
            'Length'      => 'COMPUTE',
            'Nonstandard' => 'ERASE'
        );
        return ( $entity, $ls );
    }

    return ( $entity, $ls );
}

sub deliver_copy {

    print "\t* Delivering Copy...\n"
      if $verbose;

    my ($args) = @_;

    if ( !exists( $args->{-ls} ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{-msg} ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $ls  = $args->{-ls};
    my $msg = $args->{-msg};

    my $test_mail = 0;
    if ( exists( $args->{-test_mail} ) ) {
        $test_mail = $args->{-test_mail};
    }

    my $mh = DADA::Mail::Send->new(
        {

            -list   => $ls->param('list'),
            -ls_obj => $ls,
        }
    );

    #carp "test_mail " . $test_mail;

    $mh->test($test_mail);

    my $entity;
    $msg = safely_encode($msg);

    eval { $entity = $parser->parse_data( $msg ) };

    if ( !$entity ) {
        print "\t* Message sucks!\n"
          if $verbose;

    }
    else {

        my $headers = $entity->stringify_header;
        $headers = safely_decode($headers);

        my %headers = $mh->return_headers($headers);
        $headers{To} = $ls->param('send_msg_copy_address');

        if ($verbose) {
            print "\t* Message Details:\n";
            print "\t* Subject: " . $headers{Subject} . "\n";
        }

        # Um. I'm not touching that.
        my $msg_id = $mh->send(

            %headers,

            # Trust me on these :)

# These are here so the message doesn't cause an infinite loop BACK to the list -

            # These are *probably* optional,
            'Bcc' => '',
            'Cc'  => '',

            # This'll do the trick, all by itself.
            'X-BeenThere' => $ls->param('discussion_pop_email'),

            Body => safely_decode( $entity->stringify_body ),

        );

    }

}

sub deliver {

    my ($args) = @_;

    if ( !exists( $args->{-ls} ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{-msg} ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $ls  = $args->{-ls};
    my $msg = $args->{-msg};

    my $test_mail = 0;
    if ( exists( $args->{-test_mail} ) ) {
        $test_mail = $args->{-test_mail};
    }

    my $mh = DADA::Mail::Send->new(
        {
            -list   => $ls->param('list'),
            -ls_obj => $ls,
        }
    );

    $mh->test($test_mail);

    my $entity;

    $msg = safely_encode($msg);
    eval { $entity = $parser->parse_data($msg); };

    if ( !$entity ) {
        print "\t* Message sucks!\n"
          if $verbose;

    }
    else {

        my $headers = $entity->stringify_header;
        $headers = safely_decode($headers);
        my %headers = $mh->return_headers($headers);

        $headers{To} = $ls->param('list_owner_email');

        if ($verbose) {
            print "\t* Message Details: \n";
            print "\t* Subject: " . $headers{Subject} . "\n";
        }

        if (   $ls->param('group_list') == 1
            && $ls->param('mail_discussion_message_to_poster') != 1 )
        {

            my $f_a;

            if ( exists( $headers{From} ) ) {

                eval {
                    $f_a =
                      ( Email::Address->parse( $headers{From} ) )[0]->address;
                };
            }

            if ( !$@ ) {
                print
"\t* Going to skip sending original poster ($f_a) a copy of their own  message...\n"
                  if $verbose;
                $mh->do_not_send_to( [$f_a] );
            }
            else {
                print "\t* Problems not sending copy to original sender: $@\n\n"
                  if $verbose;
            }
        }

        my $body = $entity->stringify_body;
        $body = safely_decode($body);

        my $msg_id = $mh->mass_send(
            %headers,

            # Trust me on these :)
            Body => $body,
        );

        return ( $msg_id, $mh->saved_message );

    }

}

sub archive {

    my ($args) = @_;

    if ( !exists( $args->{-ls} ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{-msg} ) ) {
        croak "You must pass a -msg paramater!";
    }
    if ( !exists( $args->{-msg_id} ) ) {
        croak "You must pass a -msg_id paramater!";
    }
    if ( !exists( $args->{-saved_msg} ) ) {
        croak "You must pass a -saved_msg paramater!";
    }

    my $ls        = $args->{-ls};
    my $msg       = $args->{-msg};
    my $msg_id    = $args->{-msg_id};
    my $saved_msg = $args->{-saved_msg};

    if ( $ls->param('archive_messages') == 1 ) {

        require DADA::MailingList::Archives;

# I'm having trouble with the db handle die'ing after we've forked a mailing.
# I wonder if telling Mr. Archives here to create  new connection will help things...

        my $la =
          DADA::MailingList::Archives->new( { -list => $ls->param('list') } );

        my $entity;

        eval {
            $msg    = safely_encode($msg);
            $entity = $parser->parse_data( $msg );
        };

        if ($entity) {

            my $Subject = $entity->head->get( 'Subject', 0 );
            if ( $ls->param('no_prefix_list_name_to_subject_in_archives') == 1 )
            {
                $Subject = $la->strip_subjects_appended_list_name($Subject);
            }

            eval {

                $la->set_archive_info( $msg_id, $Subject, undef, undef,
                    $saved_msg, );
            };

            if ($@) {
                warn
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! message did not archive correctly!: $@";
            }
        }
        else {
            warn "Problem archiving message...";
        }

    }
}

sub send_msg_not_from_subscriber {

    my $ls   = shift;
    my $msg  = shift;

    $msg = safely_encode($msg);
    my $entity = $parser->parse_data( $msg );

    my $rough_from = $entity->head->get( 'From', 0 );
    my $from_address;
    if ( defined($rough_from) ) {
        ;
        eval {
            $from_address = ( Email::Address->parse($rough_from) )[0]->address;
        };
    }

    if ( $from_address && $from_address ne '' ) {

        require DADA::MailingList::Settings;
        if ( $from_address eq $ls->param('discussion_pop_email') ) {
            warn
"Message is from List Email ($from_address)? Not sending, 'not_allowed_to_post_msg' so to not send message back to list!";
        }
        else {
            my $att = $entity->as_string;
            $att = safely_decode($att);
            require DADA::App::Messages;
            DADA::App::Messages::send_not_allowed_to_post_msg(
                {
                    -list       => $ls->param('list'),
                    -email      => $from_address,
                    -attachment => safely_encode($att),

                },
            );
        }

    }
    else {
        warn
"Problem with send_msg_not_from_subscriber! There's no address to send to?: "
          . $rough_from;
    }

}

sub send_spam_rejection_message {
    my $ls  = shift;
    my $msg = shift;

    $msg = safely_encode($msg);
    my $entity = $parser->parse_data($msg);

    my $rough_from = $entity->head->get( 'From', 0 );
    my $from_address;
    if ( defined($rough_from) ) {
        ;
        eval {
            $from_address = ( Email::Address->parse($rough_from) )[0]->address;
        };
    }

    if ( $from_address && $from_address ne '' ) {

        require DADA::MailingList::Settings;
        my $ls =
          DADA::MailingList::Settings->new( { -list => $ls->param('list') } );

        #my $att = $entity->as_string;
        #   $att = safely_decode($att);
        require DADA::App::Messages;

        DADA::App::Messages::send_generic_email(
            {
                -list    => $ls->param('list'),
                -headers => {
                    To      => $from_address,
                    From    => $ls->param('list_owner_email'),
                    Subject => $ls->param('msg_labeled_as_spam_msg_subject'),
                },
                -body        => $ls->param('msg_labeled_as_spam_msg'),
                -tmpl_params => {

                    -list_settings_vars       => $ls->params,
                    -list_settings_vars_param => { -dot_it => 1, },
                    -subscriber_vars =>
                      { 'subscriber.email' => $from_address, },
                    -vars => {
                        original_subject => $entity->head->get( 'Subject', 0 ),
                    }
                },
            }
        );

    }
    else {
        warn
"Problem with send_spam_rejection_message! There's no address to send to?: "
          . $rough_from;
    }
}

sub send_invalid_msgs_to_owner {

    my $ls  = shift;
    my $msg = shift;

    $msg = safely_encode($msg);
    my $entity = $parser->parse_data( $msg );

    require DADA::App::Messages;

    my $rough_from = $entity->head->get( 'From', 0 );
    my $from_address;
    if ( defined($rough_from) ) {
        ;
        eval {
            $from_address = ( Email::Address->parse($rough_from) )[0]->address;
        };
    }

    if ( $from_address && $from_address ne '' ) {

        my $reply = MIME::Entity->build(
            Type    => "multipart/mixed",
            From    => $ls->param('list_owner_email'),
            To      => $ls->param('list_owner_email'),
            Subject => $ls->param('invalid_msgs_to_owner_msg_subject'),
        );

        $reply->attach(
            Type     => 'text/plain',
            Encoding => $ls->param('plaintext_encoding'),
            Data     => $ls->param('invalid_msgs_to_owner_msg'),
        );

        $reply->attach(
            Type        => 'message/rfc822',
            Disposition => "inline",
            Data        => safely_decode( $entity->as_string ),
        );

        my %msg_headers = DADA::App::Messages::_mime_headers_from_string(
            $reply->stringify_header );

        DADA::App::Messages::send_generic_email(
            {
                -list    => $ls->param('list'),
                -headers => {
                    %msg_headers,

                    # Hack? Or bug somewhere else...
                    #'Content-Type' => 'multipart/mixed',
                },
                -body        => $reply->stringify_body,
                -tmpl_params => {
                    -list_settings_vars       => $ls->params,
                    -list_settings_vars_param => { -dot_it => 1, },

                    -subscriber_vars => { 'subscriber.email' => $from_address, }
                },
            }
        );
    }
    else {
        warn "Problem with send_invalid_msgs_to_owner!";
    }
}

sub handle_errors {

    my $ls       = shift;
    my $errors   = shift;
    my $full_msg = shift;

    my $entity;

    $full_msg = safely_encode($full_msg);

    eval {
        $entity = $parser->parse_data(

            $full_msg
        );
    };
    if ( !$entity ) {
        die "no entity found! die'ing!";
    }

    my $reasons = '';
    for ( keys %$errors ) {
        $reasons .= $_ . ', '
          if $errors->{$_} == 1;
    }
    my $subject = $entity->head->get( 'Subject', 0 );
    $subject =~ s/\n//g;
    my $from = $entity->head->get( 'From', 0 );
    $from =~ s/\n//g;

   # $from should probably be simply the email address, not the entire header...
   #
    eval { $from = ( Email::Address->parse($from) )[0]->address; };
    if ($@) {
        warn
          "this was a problem parsing the email address from the header? '$@'";
    }

    my $message_id = $entity->head->get( 'Message-Id', 0 );
    $message_id =~ s/\n//g;
    if ( !$message_id ) {

        require DADA::Security::Password;

        my ( $f_user, $f_domain ) = split( '@', $from );
        my $fake_message_id = '<'
          . DADA::App::Guts::message_id()
          . '.FAKE_MSG_ID'
          . DADA::Security::Password::generate_rand_string('1234567890') . '@'
          . $f_domain . '>';

        $message_id = $fake_message_id;
        $entity->head->replace( 'Message-ID', $fake_message_id );

        warn
"bridge.cgi - message has no Message-Id header!...? Creating FAKE Message-Id ($fake_message_id) , to avoid any conflicts...";

    }

    warn
"bridge.cgi rejecting sending of received message - \tFrom: $from\tSubject: $subject\tMessage-ID: $message_id\tReasons: $reasons";

    print "\t* Error delivering message! Reasons:\n"
      if $verbose;
    for ( keys %$errors ) {
        print "\t\t* " . $_ . "\n"
          if $errors->{$_} == 1 && $verbose;
    }

    if ( $errors->{list_owner_return_path_set_funny} == 1 ) {

        print "\t\t* list_owner_return_path_set_funny\n"
          if $verbose;

        # and I'm not going to do anything...

    }

    if ( $errors->{message_seen_as_spam} == 1 ) {

        if ( $ls->param('rejected_spam_messages') eq
            'send_spam_rejection_message' )
        {
            print "\t\t* end_spam_rejection_message on its way!\n"
              if $verbose;
            send_spam_rejection_message( $ls, $full_msg );

        }
        elsif ( $ls->param('rejected_spam_messages') eq 'ignore_spam' ) {
            print "\t\t *** Message seen as SPAM - ignoring. ***\n"
              if $verbose;
        }
        else {
            print
"\t\tlist_settings.rejected_spam_messages is setup impoperly - ignoring message!\n";
        }

    }
    elsif ( $errors->{multiple_return_path_headers} == 1 ) {

        print "\t\t* Message has multiple 'Return-Path' headers. Ignoring. \n"
          if $verbose;
        warn
"$DADA::Config::PROGRAM_NAME Error: Message has multiple 'Return-Path' headers. Ignoring.1023";

    }
    elsif ( $errors->{msg_from_list_address} ) {

        print
"\t\t* message was from the list address - will not process! - (ignoring) \n"
          if $verbose;
        warn
"$DADA::Config::PROGRAM_NAME Error: message was from the list address - will not process! - (ignoring)";
    }
    elsif ($errors->{msg_not_from_subscriber} == 1
        || $errors->{msg_not_from_list_owner} == 1
        || $errors->{msg_not_from_an_authorized_sender} == 1 )
    {

        if ( $ls->param('send_not_allowed_to_post_msg') == 1 ) {

            print "\t\t* msg_not_from_subscriber on its way!\n"
              if $verbose;
            send_msg_not_from_subscriber( $ls, $full_msg );

        }

        if ( $ls->param('send_invalid_msgs_to_owner') == 1 ) {
            print "\t\t* invalid_msgs_to_owner on its way!\n"
              if $verbose;
            send_invalid_msgs_to_owner( $ls, $full_msg );

        }

    }
    elsif ( $errors->{needs_moderation} ) {

        print "\t\t* Message being saved for moderation by list owner...\n"
          if $verbose;

        my $mod = SimpleModeration->new( { -List => $ls->param('list') } );
        $mod->save_msg( { -msg => $full_msg, -msg_id => $message_id } );

        # This is only used once...
        $mod->moderation_msg(
            {
                -msg     => $full_msg,
                -msg_id  => $message_id,
                -subject => $subject,
                -from    => $from,
                -parser  => $parser
            }
        );

        if ( $ls->param('send_moderation_msg') == 1 ) {
            print "\t\t * Sending 'awaiting moderation' message!\n"
              if $verbose;
            $mod->send_moderation_msg(
                {
                    -msg_id  => $message_id,
                    -parser  => $parser,
                    -subject => $subject
                }
            );
        }

        my $awaiting_msgs = $mod->awaiting_msgs();

        print "\t* Other awaiting messages:\n"
          if $verbose;

        for (@$awaiting_msgs) {
            print "\t\t * " . $_ . "\n"
              if $verbose;
        }
    }

}

sub create_checksum {

    my $data = shift;

    if ( $] >= 5.008 ) {
        require Encode;
        my $cs = md5_hex( safely_encode($$data) );
        return $cs;
    }
    else {
        my $cs = md5_hex($$data);
        return $cs;
    }
}

sub can_use_spam_assassin {

    eval { require Mail::SpamAssassin; };

    if ( !$@ ) {
        return 1;
    }
    else {
        return 0;
    }

}

sub append_message_to_file {

    my $ls  = shift;
    my $msg = shift;
    my $rp  = find_return_path($msg);

    my $file =
        $DADA::Config::TMP
      . '/bridge_received_msgs-'
      . $ls->param('list') . '.mbox';

    print "Saving message at: '$file' \n"
      if $verbose;

    $file = DADA::App::Guts::make_safer($file);

    open( APPENDLOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or die $!;
    chmod( $DADA::Config::FILE_CHMOD, $file );
    print APPENDLOG 'From ' . $rp . "\n";

    print APPENDLOG $msg . "\n";
    close(APPENDLOG) or die $!;

    print "Saved. \n"
      if $verbose;

    return 1;

}

sub find_return_path {

    my $msg = shift;
    my $rp;

    eval {

        $msg = safely_encode($msg);

        my $entity = $parser->parse_data($msg);
        $rp = $entity->head->get( 'Return-Path', 0 );

    };
    if ( !$@ ) {
        chomp $rp;
        return $rp;
    }
    else {
        return undef;
    }
}

sub cgi_show_plugin_config {

    my $configs = [];
    for ( sort keys %$Plugin_Config ) {
        if ( $_ eq 'Password' ) {
            push( @$configs, { name => $_, value => '(Not Shown)' } );
        }
        else {
            push( @$configs, { name => $_, value => $Plugin_Config->{$_} } );
        }
    }

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'plugins/bridge/plugin_config.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {
                screen      => 'using_bridge',
                Plugin_URL  => $Plugin_Config->{Plugin_URL},
                Plugin_Name => $Plugin_Config->{Plugin_Name},
                configs     => $configs,
            },
        },
    );
    e_print($scrn);

}

sub cgi_edit_email_msgs {

    my $process = $q->param('process') || undef;
    my $done    = $q->param('done')    || undef;

    require DADA::Template::Widgets;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    # Backwards Compatibility!
    for (
        qw(
        not_allowed_to_post_msg_subject
        not_allowed_to_post_msg
        moderation_msg_subject
        moderation_msg
        await_moderation_msg_subject
        await_moderation_msg
        accept_msg_subject
        accept_msg
        rejection_msg_subject
        rejection_msg
        msg_too_big_msg_subject
        msg_too_big_msg
        msg_labeled_as_spam_msg_subject
        msg_labeled_as_spam_msg
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
                -screen         => 'plugins/bridge/edit_email_msgs.tmpl',
                -with           => 'admin',
                -wrapper_params => {
                    -Root_Login => $root_login,
                    -List       => $list,
                },
                -list => $list,
                -vars => {
                    screen      => 'using_bridge',
                    title       => 'Email Templates',
                    done        => $done,
                    Plugin_Name => $Plugin_Config->{Plugin_Name},
                    Plugin_URL  => $Plugin_Config->{Plugin_URL},
                    Soft_Max_Size_Of_Any_Message => sprintf(
                        "%.1f",
                        (
                            $Plugin_Config->{Soft_Max_Size_Of_Any_Message} /
                              1024
                        )
                    ),
                    Max_Size_Of_Any_Message => sprintf( "%.1f",
                        ( $Plugin_Config->{Max_Size_Of_Any_Message} / 1024 ) ),

                },
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1, },
            }
        );
        e_print($scrn);

    }
    else {

        for (
            qw(
            not_allowed_to_post_msg_subject
            not_allowed_to_post_msg
            moderation_msg_subject
            moderation_msg
            await_moderation_msg_subject
            await_moderation_msg
            accept_msg_subject
            accept_msg
            rejection_msg_subject
            rejection_msg
            msg_too_big_msg_subject
            msg_too_big_msg
            msg_labeled_as_spam_msg_subject
            msg_labeled_as_spam_msg
            )
          )
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
                    not_allowed_to_post_msg_subject   => '',
                    not_allowed_to_post_msg           => '',
                    invalid_msgs_to_owner_msg_subject => '',
                    invalid_msgs_to_owner_msg         => '',
                    moderation_msg_subject            => '',
                    moderation_msg                    => '',
                    await_moderation_msg_subject      => '',
                    await_moderation_msg              => '',
                    accept_msg_subject                => '',
                    accept_msg                        => '',
                    rejection_msg_subject             => '',
                    rejection_msg                     => '',
                    msg_too_big_msg_subject           => '',
                    msg_too_big_msg                   => '',
                    msg_labeled_as_spam_msg_subject   => '',
                    msg_labeled_as_spam_msg           => '',
                }
            }
        );
 
		
        print $q->redirect( -uri => $Plugin_Config->{Plugin_URL} . '?flavor=edit_email_msgs&done=1' );

    }
}

sub inject {

	
    my ($args) = @_;

	
    my $msg = $args->{-msg};

    # We're taking a guess, on this one:
    $msg = safely_decode($msg);

    my $send_test = 0;

    my $test_mail = 0;

    if ( exists( $args->{-send_test} ) ) {
        $send_test = $args->{-send_test};
    }
    if ( exists( $args->{-verbose} ) ) {
        $verbose = $args->{-verbose};
        #print "I'm verbosing!\n";
    }
    if ( exists( $args->{-test_mail} ) ) {
        $test_mail = $args->{-test_mail};
    }

    my $ls;
    if ( exists( $args->{-ls} ) ) {
        $ls = $args->{-ls};

    }
    else {
        require DADA::MailingList::Settings;
        $ls = DADA::MailingList::Settings->new( { -list => $ls->param('list') } );
    }

    if ( $ls->param('disable_discussion_sending') != 1 ) {
        my ( $status, $errors );

        eval {

            ( $status, $errors ) = validate_msg( $ls, \$msg );
            if ($status) {
                process(
                    {
                        -ls        => $ls,
                        -msg       => \$msg,
                        -test_mail => $test_mail,
                    }
                );

                append_message_to_file( $ls, $msg );

                return ( $status, $errors );

            }
            else {

                print
                  "\tMessage did not pass verification - handling issues...\n"
                  if $verbose;

                handle_errors( $ls, $errors, $msg );

                append_message_to_file( $ls, $msg );

                return ( $status, $errors );

            }

        };

        if ($@) {

            warn
"bridge.cgi - irrecoverable error processing message. Skipping message (sorry!): $@";
            print
"bridge.cgi - irrecoverable error processing message. Skipping message (sorry!): $@"
              if $verbose;
            return ( 0, { irrecoverable_error => 1 } );

        }

        else {

            return ( $status, $errors );

        }

    }
    else {
        print
"\tThis sending method has been disabled for " . $ls->param('list') . ", ignoring message... \n"
          if $verbose;
        return ( 0, { disabled => 1 } );
    }

}


sub self_url { 
	my $self_url = $q->url; 
	if($self_url eq 'http://' . $ENV{HTTP_HOST}){ 
			$self_url = $ENV{SCRIPT_URI};
	}
	return $self_url; 	
}

END {

    if ( defined($parser) ) {
        $parser->filer->purge;
    }
}





package SimpleModeration;

use strict;

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts qw(!:DEFAULT);
use MIME::Entity;

sub new {
    my $class = shift;
    my $self  = {@_};
    bless $self, $class;

    my ($args) = @_;

    if ( !$args->{-List} ) {
        carp
"You need to supply a list ->new({-List => your_list}) in the constructor.";
        return undef;
    }
    else {

        $self->{list} = $args->{-List};
    }

    $self->init;

    return $self;

}

sub init {

    my $self = shift;
    $self->check_moderation_dir();

}

sub check_moderation_dir {

    # Basically, just makes the tmp directory that we need...

    my $self = shift;
    if ( -d $self->mod_dir ) {

        # Well, ok!
    }
    else {

        croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, '"
          . $self->mod_dir . "'- $!"
          unless mkdir( $self->mod_dir, $DADA::Config::DIR_CHMOD );

        chmod( $DADA::Config::DIR_CHMOD, $self->mod_dir )
          if -d $self->mod_dir;
    }
}

sub awaiting_msgs {

    my $self    = shift;
    my $pattern = quotemeta( $self->{list} . '-' );
    my @awaiting_msgs;
    my %allfiles;

    my $f;
    if ( opendir( MOD_MSGS, $self->mod_dir ) ) {
        while ( defined( $f = readdir MOD_MSGS ) ) {
            next if $f =~ /^\.\.?$/;
            $f =~ s(^.*/)();
            $allfiles{$f} = ( stat( $self->mod_dir . '/' . $f ) )[9];
        }

        closedir(MOD_MSGS)
          or carp "couldn't close: " . $self->mod_dir;

        # if you still need the keys...
        foreach my $key (    #
            sort { $allfiles{$b} <=> $allfiles{$a} }    #
            keys %allfiles
          )
        {
            push( @awaiting_msgs, $key );
        }

    }
    else {
        carp "could not open " . $self->mod_dir . " $!";
    }

    return [@awaiting_msgs];

}

sub save_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-msg} ) {
        croak "You must supply a message!";
    }

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }

    my $file = $self->mod_msg_filename( $args->{-msg_id} );

    open my $MSG_FILE, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file
      or croak "Cannot write saved raw message at: '" . $file . " because: $!";

    print $MSG_FILE $args->{-msg};

    close($MSG_FILE)
      or croak "Coulnd't close: " . $file . "because: " . $!;

}

sub moderation_msg {

    my $self = shift;
    my ($args) = @_;
    my $reply;

    if ( !$args->{-msg} ) {
        croak "You must supply a message!";
    }

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }
    $args->{-msg_id} =~ s/\@/_at_/g;
    $args->{-msg_id} =~ s/\>|\<//g;
    $args->{-msg_id} = DADA::App::Guts::strip( $args->{-msg_id} );

    if ( !$args->{-from} ) {
        croak "You must supply a from!";
    }

    if ( !$args->{-parser} ) {
        croak "You must supply a parser!";
    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    my $parser = $args->{-parser};
    my $entity =
      $parser->parse_data( DADA::App::Guts::safely_encode( $args->{-msg} ) );

    my $confirmation_link =
        $Plugin_Config->{Plugin_URL}
      . '?flavor=mod&list='
      . DADA::App::Guts::uriescape( $self->{list} )
      . '&process=confirm&msg_id='
      . DADA::App::Guts::uriescape( $args->{-msg_id} );
    my $deny_link =
        $Plugin_Config->{Plugin_URL}
      . '?flavor=mod&list='
      . DADA::App::Guts::uriescape( $self->{list} )
      . '&process=deny&msg_id='
      . DADA::App::Guts::uriescape( $args->{-msg_id} );

    #  create an array of recepients
    my @moderators;
    if ( $ls->param('moderate_discussion_lists_with') eq
        'authorized_sender_email' )
    {
        my $lh =
          DADA::MailingList::Subscribers->new( { -list => $self->{list} } );
        my $authorized_senders = [];
        $authorized_senders =
          $lh->subscription_list( { -type => 'authorized_senders' } );
        for my $moderator (@$authorized_senders) {

            if ( $moderator->{email} eq $args->{-from} ) {

                # Well, we'll just pass that one right by...
                # I don't think we want an authorized sender to
                # be able to moderate their own message!
            }
            else {
                push( @moderators, $moderator->{email} );
            }
        }
        print
"\t* Message being sent to Authorized Senders and List Owner for moderation... \n"
          if $verbose;
    }
    else {
        print "\t* Message being sent to List Owner for moderation... \n"
          if $verbose;
    }
    push( @moderators, $ls->param('list_owner_email') );    # always addressed

    # loop through recepients
    for my $to_address (@moderators) {                      # recepient loop
        $reply = MIME::Entity->build(
            Type    => "multipart/mixed",
            Subject => $ls->param('moderation_msg_subject'),
            To      => $to_address,
        );
        print "\t* Sent moderation request to $to_address\n"
          if $verbose;

        # attach parts
        $reply->attach(
            Type     => 'text/plain',
            Encoding => $ls->param('plaintext_encoding'),
            Data     => $ls->param('moderation_msg'),
        );
        $reply->attach(
            Type        => 'message/rfc822',
            Disposition => "inline",
            Data        => DADA::App::Guts::safely_decode(
                DADA::App::Guts::safely_encode( $entity->as_string )
            ),
        );

        # send the message
        require DADA::App::Messages;
        DADA::App::Messages::send_generic_email(
            {
                -list    => $self->{list},
                -headers => {
                    DADA::App::Messages::_mime_headers_from_string(
                        $reply->stringify_header
                    ),
                },
                -body        => $reply->stringify_body,
                -tmpl_params => {
                    -list_settings_vars       => $ls->get,
                    -list_settings_vars_param => { -dot_it => 1, },

                    #-subscriber_vars =>
                    #	{
                    #		#'subscriber.email' =>  $args->{-from},
                    #	},
                    -vars => {
                        moderation_confirmation_link => $confirmation_link,
                        moderation_deny_link         => $deny_link,
                        message_subject              => $args->{-subject},
                        msg_id                       => $args->{-msg_id},
                        'subscriber.email'           => $args->{-from},
                    }
                },
            }
        );
    }
}

sub send_moderation_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }
    $args->{-msg_id} =~ s/\@/_at_/g;
    $args->{-msg_id} =~ s/\>|\<//g;
    $args->{-msg_id} = DADA::App::Guts::strip( $args->{-msg_id} );

    if ( !$args->{-parser} ) {
        croak "You must supply a parser!";
    }

# DEV there are two instances of my $parser, and my $entity of them - which one is the correct one?

    my $parser = $args->{-parser};

    my $entity;
    eval {
        $entity = $parser->parse_data(
            DADA::App::Guts::safely_encode(

                $self->get_msg( { -msg_id => $args->{-msg_id} } )
            )
        );
    };
    if ( !$entity ) {
        croak "no entity found! die'ing!";
    }

    my $subject = $entity->head->get( 'Subject', 0 );
    $subject =~ s/\n//g;
    my $from = $entity->head->get( 'From', 0 );
    $from =~ s/\n//g;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    my $reply = MIME::Entity->build(
        Type     => "text/plain",
        Encoding => $ls->param('plaintext_encoding'),
        To       => $from,
        Subject  => $ls->param('await_moderation_msg_subject'),
        Data     => $ls->param('await_moderation_msg'),
    );

    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->{list},
            -headers => {
                DADA::App::Messages::_mime_headers_from_string(
                    $reply->stringify_header
                ),
            },

            -body        => $reply->stringify_body,
            -tmpl_params => {
                -list_settings_vars       => $ls->params,
                -list_settings_vars_param => { -dot_it => 1, },
                -subscriber_vars => { 'subscriber.email' => $args->{-from}, },
                -vars            => {

                    message_subject => $args->{-subject},
                    message_from    => $args->{-from},
                    msg_id          => $args->{-msg_id},
                    Plugin_Name     => $Plugin_Config->{Plugin_Name},

                }
            },
        }
    );
}

sub send_accept_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }
    $args->{-msg_id} =~ s/\@/_at_/g;
    $args->{-msg_id} =~ s/\>|\<//g;
    $args->{-msg_id} = DADA::App::Guts::strip( $args->{-msg_id} );

    if ( !$args->{-parser} ) {
        croak "You must supply a parser!";
    }

# DEV there are two instances of my $parser, and my $entity of them - which one is the correct one?

    my $parser = $args->{-parser};

    my $entity;
    eval {
        $entity = $parser->parse_data(
            DADA::App::Guts::safely_encode(
                $self->get_msg( { -msg_id => $args->{-msg_id} } )
            )
        );
    };
    if ( !$entity ) {
        croak "no entity found! die'ing!";

    }

    my $subject = $entity->head->get( 'Subject', 0 );
    $subject =~ s/\n//g;
    my $from = $entity->head->get( 'From', 0 );
    $from =~ s/\n//g;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    my $reply = MIME::Entity->build(
        Type     => "text/plain",
        Encoding => $ls->param('plaintext_encoding'),
        To       => $from,
        Subject  => $ls->param('accept_msg_subject'),
        Data     => $ls->param('accept_msg'),
    );

    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->{list},
            -headers => {
                DADA::App::Messages::_mime_headers_from_string(
                    $reply->stringify_header
                ),
            },
            -body        => $reply->stringify_body,
            -tmpl_params => {
                -list_settings_vars       => $ls->params,
                -list_settings_vars_param => { -dot_it => 1, },
                -subscriber_vars => { 'subscriber.email' => $args->{-from}, },
                -vars            => {
                    message_subject => $subject,
                    message_from    => $from,
                    msg_id          => $args->{-msg_id},
                    Plugin_Name     => $Plugin_Config->{Plugin_Name},
                }
            },
        }
    );
}

sub send_reject_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }
    $args->{-msg_id} =~ s/\@/_at_/g;
    $args->{-msg_id} =~ s/\>|\<//g;
    $args->{-msg_id} = DADA::App::Guts::strip( $args->{-msg_id} );

    if ( !$args->{-parser} ) {
        croak "You must supply a parser!";
    }

# DEV there are two instances of my $parser, and my $entity of them - which one is the correct one?

    my $parser = $args->{-parser};

    my $entity;
    eval {
        $entity = $parser->parse_data(
            DADA::App::Guts::safely_encode(
                $self->get_msg( { -msg_id => $args->{-msg_id} } )
            )
        );

    };
    if ( !$entity ) {
        croak "no entity found! die'ing!";
    }

    my $subject = $entity->head->get( 'Subject', 0 );
    $subject =~ s/\n//g;
    my $from = $entity->head->get( 'From', 0 );
    $from =~ s/\n//g;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    my $reply = MIME::Entity->build(
        Type     => "text/plain",
        Encoding => $ls->param('plaintext_encoding'),
        To       => $from,
        Subject  => $ls->param('rejection_msg_subject'),
        Data     => $ls->param('rejection_msg'),
    );

    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->{list},
            -headers => {
                DADA::App::Messages::_mime_headers_from_string(
                    $reply->stringify_header
                ),
            },
            -body        => $reply->stringify_body,
            -tmpl_params => {
                -list_settings_vars       => $ls->params,
                -list_settings_vars_param => { -dot_it => 1, },
                -subscriber_vars          => {
                    'subscriber.email' => $args->{-from},

                },
                -vars => {

                    message_subject => $args->{-subject},
                    message_from    => $args->{-from},
                    msg_id          => $args->{-msg_id},
                    Plugin_Name     => $Plugin_Config->{Plugin_Name},

                }
            },
        }
    );
}

sub is_moderated_msg {

    my $self   = shift;
    my $msg_id = shift;

    print '<pre>';
    print "looking for:\n";
    print $self->mod_msg_filename($msg_id) . "\n";
    print '</pre>';

    if ( -e $self->mod_msg_filename($msg_id) ) {
        return 1;
    }
    else {
        return 0;
    }

}

sub get_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }

    my $file = $self->mod_msg_filename( $args->{-msg_id} );

    if ( !-e $file ) {

        croak "Message: $file doesn't exist?!";

    }
    else {

        open my $MSG_FILE, '<', $file
          or die "Cannot read saved raw message at: '" 
          . $file
          . "' because: "
          . $!;

        my $msg = do { local $/; <$MSG_FILE> };

        close $MSG_FILE
          or die "Didn't close: '" . $file . "'properly because: " . $!;

        return $msg;

    }

}

sub remove_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-msg_id} ) {
        croak "You must supply a message id!";
    }

    my $file = $self->mod_msg_filename( $args->{-msg_id} );

    if ( -e $file ) {

        my $count = unlink($file);
        if ( $count != 1 ) {
            carp "Weird file delete count is: $count - should be, '1'";
        }
    }
    else {
        carp "no file at: $file to delete!";
    }

    return 1;

}

sub mod_msg_filename {

    my $self       = shift;
    my $message_id = shift;

    $message_id =~ s/\@/_at_/g;
    $message_id =~ s/\>|\<//g;
    $message_id = DADA::App::Guts::strip($message_id);
    $message_id = DADA::App::Guts::uriescape($message_id);
    return
        $self->mod_dir . '/'
      . DADA::App::Guts::uriescape( $self->{list} ) . '-'
      . $message_id;

}

sub mod_dir {

    my $self = shift;

    return $DADA::Config::TMP . '/moderated_msgs';

}








=pod

=head1 Bridge

=head1 Description 

The Bridge plugin adds support to Dada Mail to accept messages sent from a mail reader to a specific email address, called the B<List Email>. That message can then be sent out in a mass mailing. 

This allows you to send announce-only messages from your mail reader, without having to log into your list's control panel. 

It also allows you to set up your mailing list as an email discussion list: Each member of your mailing list may send messages to the List Email, which will then be sent to the entire mailing list. 

The B<List Email> will need to be set up manually for each mailing list you will want to use Bridge and can be either a regular B<POP3 email account>, which Bridge will log into on a schedule, or an B<Email Forward>, which will forward the message directly to the plugin itself. 

=head1 User Guide

The below documentation goes into detail on how to I<install> and I<configure> Bridge. A user guide for Bridge is available in the Dada Mail Manual chapter, B<Using Bridge>: 

L<http://dadamailproject.com/pro_dada/using_bridge.html>


=head1 Obtaining The Plugin

Bridge is located in the, I<dada/plugins> directory of the Dada Mail distribution, under the name: I<bridge.cgi>

=head1 Installation 

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. Under, B<Plugins/Extensions>, check, B<Bridge>.

Manually installation isn't recommended, but is outlined later in this doc. 

=head1 Mailing List Configuration 

Once you've installed Bridge, you may access it via the List Control Panel. Bridge is located in the left hand menu, under, B<Plugins>. 

Before you can start using Bridge for your mailing list, there's two things that will have to be done: the first is to B<enable> the plugin; the second is to configure your B<List Email>. 

=head2 Enable Bridge

In Bridge's control panel, under, B<General>, uncheck the option, B<Disable sending using this method>. Save your changes. 

=head2 List Email Configuration 

The List Email is the address that you will be sending your email messages, to be broadcasted to your entire mailing list. 

There's a few constraints you want to keep in mind when creating the List Email. Most likely, the address is going to be on the same domain that you install Dada Mail and it's going to be an address that you're not already using; either somewhere else in Dada Mail, or as another general email address. 

The List Email can either be a normal POP3 email account, or a Mail Forward.

A POP3 email account is fairly easy to set up, as its similar to setting up any mail reader - and Bridge basically acts as a mail reader, while checking messages sent to this account. It does require you to set up an additional cronjob (scheduled task), to check this account on a regular schedule; for example: every 5 minutes. 

A Mail Forward does not need this additional cronjob created, but may be slightly trickier to set up on the mail forward side of things. Before attempting, make sure that you can set up a mail forward that can B<Pipe to a Program>, and not simply forward to another email address.  

=head3 Setup As: POP3 Account 

Toggle the radio buttons labeled, B<Setup As> to, B<POP3 Account>.

Create a new POP3 Account. This email account will be the email address you will send messages to. Additional fields should be shown, where you may plug in the POP3 Login information for this email address ( POP3 Server,  POP3 Username,  POP3 Password, etc.). You may test that the login credentials are working by clicking the button labeled, B<Test POP3 Login Information...>. 

Once the login information works with Bridge, Save your changes. 

=head4 Set the cronjob

Once you've saved your POP3 login info, set the cronjob for Bridge. An I<example> of a cronjob that should work, can be found in the textbox labeled, I<cronjob command using curl (example)>. We recommend setting the cronjob to run every 5 minutes, or less. 

Other options for cronjobs exist and are detailed, below, if the provided example doesn't work. 

=head3 Setup As: Mail Forward

Toggle the radio buttons labeled, B<Setup As> to, B<Email Forward>. An I<example> of the command you'll need to work with Bridge will be shown. 

Create a new Mail Forward, and use the example shown as a starting point for the piped command. Here's an example, 

 |/home/youraccount/public_html/cgi-bin/dada/plugins/bridge.cgi --inject --list yourlist

If you're setting the command in cPanel (or something similar) and it asks you to, "I<enter a path relative to your home directory>", you may need to simply remove the "pipe" B<|> and the path to your home directory I</home/youraccount>, plugging in this, instead: 

	public_html/cgi-bin/dada/plugins/bridge.cgi --inject --list yourlist

=head2 Testing Bridge. 

Once you've enabled Bridge, and set up the List Email, it's time to test the plugin. Simply send a message to your List Email. To make things easier, make sure to send the message from the List Owner's email address, which is allowed to send to both announce-only and discussion type mailing lists. If a message is sent out to your entire mailing list, congratulations: Bridge is working. 

=head2 Additional Mailing List Configuration

In Bridge's List Control Panel and below, B<List Email Configuration> section, are additional settings you may customize, depending on how you'd like your mailing list to function. 

=head1 Advanced Topics

=head1 Plugin Configuration Settings

The below settings are available to you, if you wish to further configure Bridge. These settings can be configured inside your C<.dada_config> file. 

First, search and see if the following lines are present in your C<.dada_config> file: 

 # start cut for plugin configs
 =cut

 =cut
 # end cut for plugin configs

If they are present, remove them.

You can then configure the plugin variables on these lines: 

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

=head2 Plugin_Name

The name of the plugin. By default, B<Bridge>.

=head2 Plugin_URL

Sometimes, the plugin has a hard time guessing what its own URL is. If this is happening, you can manually set the URL of the plugin in C<Plugin_URL>.

=head2 Allow_Manual_Run

Allows you to invoke the plugin to check and send awaiting messages via a URL. 

=head2 Manual_Run_Passcode

Allows you to set a passcode if you want to allow manually running the plugin. 

=head2 MessagesAtOnce

You can specify how many messages you want to have the program actually handle per execution of the script by changing the, C<MessagesAtOnce> variable. By default, it's set conservatively to, C<1>.

=head2 Max_Size_Of_Any_Message

Sets a hard limit on how large a single message can actually be, before you won't allow the message to be processed. If a message is too large, it'll be simple deleted. A warning will be written in the error log, but the original sender will not be notified.

=head2 Soft_Max_Size_Of_Any_Message

Like its brethren, C<Max_Size_Of_Any_Message> C<Soft_Max_Size_Of_Any_Message> sets the maximum size of a message that's accepted, but
If the message falls between, C<Soft_Max_Size_Of_Any_Message> and, C<Max_Size_Of_Any_Message> a, "Your email message is too big!" email message will
be sent to the original poster. 

Set the size in octects. 

=head2 Allow_Open_Discussion_List

If set to, C<1> a new option will be available in Bridge's list control panel to allow you to have a discussion list that anyone can send messages to. 

=head2 Room_For_One_More_Check

C<Room_For_One_More_Check> looks to see how many mass mailings are currently in the mass mailing queue. If its at or above the limit set in C<$MAILOUT_AT_ONCE_LIMIT>, Bridge will not attempt to look for and (possibly) create another mass mailing to join the queue. 

=head2 Enable_POP3_File_Locking

When set to, C<1>, Bridge will use a simple lockfile scheme to make sure that it does not check the same POP3 account at the same time another copy of the plugin is doing the exact same thing, saving you from potentially sending out multiple copies of the same message. 

Sometimes, the simple POPp3 lock in Dada Mail gets stale, and a deadlock happens. Setting this configuration to, C<0> disables lockfiles. Stale locks will be deleted by the app after a day of being stale.  

=head2 Check_List_Owner_Return_Path_Header

When testing the validity of a received message, Dada Mail will look to see if the, C<Return-Path> header matches what's set in the, C<From> header. If they do not match, this test fails and the message will be rejected. Setting, C<Check_List_Owner_Return_Path_Header> to, C<0> will disable this test. 

=head2 Check_Multiple_Return_Path_Headers

C<Check_Multiple_Return_Path_Headers> is another validity test for received messages. This time, the message is looked to see if it has more than one C<Return-Path> header. If it does, it is rejected. If you set, C<Check_Multiple_Return_Path_Headers> to, C<0>, this test will be disabled. 

=head2 Advanced Cronjobs 

A cronjob will need to be set for Bridge, if you have a mailing list that uses a POP3 account for its List Email. If you are using Mail Forwards only, no cronjob needs to be set. 

Generally, setting the cronjob to have Bridge run automatically just means that you have to have a cronjob access a specific URL. The URL looks something like this:

 http://example.com/cgi-bin/dada/plugins/bridge.cgi?run=1&verbose=1

Where, I<http://example.com/cgi-bin/dada/plugins/bridge.cgi> is the URL to your copy of bridge.cgi

You'll see the specific URL used for your installation of Dada Mail in the web-based control panel for Bridge, under the label, B< Manual Run URL:> 

This should work for most Cpanel-based hosting accounts.

Here's the entire cronjob explained:

In this example, I'll be running the script every 5 minutes ( */5 * * * * ) - tailor to your taste.


	*/5 * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0\; --url http://example.com/cgi-bin/dada/plugins/bridge.cgi

=head2 Disallowing running Bridge manually (via URL) 

If you DO NOT want to use this way of invoking the program to check awaiting messages and send them out, make sure to set the B<plugin config variable> (which we'll cover below) C<Allow_Manual_Run> to, C<0>. 

=head2 Security Concerns "Manual_Run_Passcode"

If you'd like, you can set up a simple B<Passcode>, to have some semblence of security over who runs the program. Do this by setting the, plugin config, C<Manual_Run_Passcode> to a password-like string: 

	Manual_Run_Passcode                 => 'sneaky', 


In this example, you'll then have to change the URL in these examples to:

 http://example.com/cgi-bin/dada/plugins/bridge.cgi?run=1&passcode=sneaky

=head3 Additional Options

You can control quite a few things by setting variables right in the query string:

=over

=item * passcode

As mentioned above, the C<Manual_Run_Passcode> allows you to set some sort of security while running in this mode. Passing the actual password is done in the query string:

 http://example.com/cgi-bin/dada/plugins/bridge.cgi?run=1&passcode=sneaky

=item * verbose

By default, you'll receive the a report of how Bridge is doing downloading awaiting messages, validating them and sending them off. 

This is sometimes not so desired, especially in a cron environment, since all this informaiton will be emailed to you (or someone) everytime the script is run. You can run Bridge with a cron that looks like this:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1 --url http://example.com/cgi-bin/dada/plugins/bridge.cgi >/dev/null 2>&1

The, >/dev/null 2>&1 line throws away any values returned.

Since all the information being returned from the plugin is done sort of indirectly, this also means that any problems actually running the program will also be thrown away.

If you set verbose to, C<0>, under normal operation, Bridge won't show any output, but if there's a server error, you'll receive an email about it. This is probably a good thing. Example:

 * * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0 --url http://example.com/cgi-bin/dada/plugins/bridge.cgi

=item * test

Runs Bridge in test mode by checking the messages awaiting and parsing them, but not actually carrying out any sending. 

=back 

=head3 Notes on Setting the Cronjob for curl

You may want to check your version of curl and see if there's a speific way to pass a query string. For example, this:

 */5 * * * * /usr/local/bin/curl -s http://example.com/cgi-bin/dada/plugins/bridge.cgi?run=1&passcode=sneaky

Doesn't work for me.

I have to use the --get and --data flags, like this:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1\;passcode=sneaky --url http://example.com/cgi-bin/dada/plugins/bridge.cgi

my query string is this part:

 run=1\;passcode=sneaky

And also note I had to escape the, ; character. You'll probably have to do the same for the & character.

Finally, I also had to pass the actual URL of the plugin using the --url flag.

=head1 Command Line Interface

This plugin can also be invoked in a command line interface. 

To use Bridge via the command line, first change into the directory that Bridge resides in, and issue the command:

 ./bridge.cgi --help

=head2 Command Line Interface for Cronjobs: 

You can also invoke C<bridge.cgi> from the command line interface for cronjobs. The secret is to actually have two commands in one. The first command changes into the same directory as the C<bridge.cgi> script, the second invokes the script with the paramaters you'd like. 

For example: 

 */5 * * * * cd /home/myaccount/cgi-bin/dada/plugins; /usr/bin/perl ./bridge.cgi  >/dev/null 2>&1

Where, I</home/myaccount/cgi-bin/dada/plugins> is the full path to the directory the C<bridge.cgi> script is located. 


=head1 Manual Installation


=head2 Configuring Bridge's Plugin Side

=head2 #1 Change the permissions of the, bridge.cgi script to, "755"

Find the C<bridge.cgi> script in your I<dada/plugins> directory. Change its permissions to, C<755> 

=head2 #2 Configure your outside config file (.dada_config)

You'll most likely want to edit your outside config file (C<.dada_config>)
so that it shows Bridge in the left-hand menu, under the, B<Plugins> heading. 

First, see if the following lines are present in your C<.dada_config> file: 

 # start cut for list control panel menu
 =cut

 =cut
 # end cut for list control panel menu

If they are, remove them. 

Then, find these lines: 


 #					{-Title      => 'Discussion Lists',
 #					 -Title_URL  => $PLUGIN_URL."/bridge.cgi",
 #					 -Function   => 'bridge',
 #					 -Activated  => 1,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{-Title      => 'Discussion Lists',
 					 -Title_URL  => $PLUGIN_URL."/bridge.cgi",
 					 -Function   => 'bridge',
 					 -Activated  => 1,
 					},

Save your C<.dada_config> file. 

You can now log into your List Control Panel and under the, B<plugins> heading you should now see a link entitled, "Bridge". Clicking that link will allow you to set up Bridge. 

=head1 Debugging 


=head2 Debugging your POP3 account information

The easiest way to debug your POP3 account info is to actually test it out. 

If you have a command line, drop into it and connect to your POP3 server, like so: 

 prompt:]telnet pop3.example.com 110
 Trying 12.123.123.123...
 Connected to pop3.example.com.
 Escape character is '^]'.
 +OK <37892.1178250885@hedwig.summersault.com>
 user user%example.com
 +OK 
 pass sneaky
 +OK 
 list

In the above example, B<pop3.example.com> is your POP3 server. You'll be typing in: 

  user user%example.com

and: 

  pass sneaky

(changing them to their real values) when prompted. This is basically what bridge.cgi does itself. 

If you don't have a command line, try adding an account in a desktop mail reader. If these credentials work there, they'll most likely work for bridge.cgi. 

If your account information is correct and also logs in when you test the pop3 login information through bridge.cgi yourself, check to see if there isn't an email filter attached the account that looks at messages before they're delivered to the POP3 Mailbox and outright deletes messages because it triggered a flag. 

This could be the cause of mysterious occurences of messages never reaching the POP3 Mailbox. 

=head1 COPYRIGHT

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

