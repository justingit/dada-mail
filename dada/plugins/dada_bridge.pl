#!/usr/bin/perl
package dada_bridge;


use strict;
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

#---------------------------------------------------------------------#
# Dada Bridge
# For instructions, see the pod of this file. try:
#  pod2text ./dada_bridge.pl | less
#
# Or try online:
#  http://dadamailproject.com/d/dada_bridge.pl.html
#
#---------------------------------------------------------------------#
# REQUIRED:
#
# It is only required that you read the documentation. All variables
# that are set here are *optional*
#---------------------------------------------------------------------#

use lib qw(
	../
	../DADA/perllib 
);


use CGI::Carp qw(fatalsToBrowser);
use DADA::Config 4.0.0;

use CGI;
CGI->nph(1) if $DADA::Config::NPH == 1;
my $q = new CGI;
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);
use Fcntl qw(
  O_CREAT
  O_RDWR
  LOCK_EX
  LOCK_NB
);
use Encode; 

my $Plugin_Config = {};

$Plugin_Config->{Plugin_Name} = 'Dada Bridge';

# Usually, this doesn't need to be changed.
# But, if you are having trouble saving settings
# and are redirected to an
# outside page, you may need to set this manually.
$Plugin_Config->{Plugin_URL} = $q->url;

# Can the checking of awaiting messages to send out happen by invoking this
# script from a URL? (CGI mode?)
# The URL would look like this:
#
# http://example.com/cgi-bin/dada/plugins/dada_bridge.pl?run=1

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
# any Dada Bridge list emails for awaiting messages.
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

# This is the message sent to the List Owner,
# telling them a message is waiting for their
# Approval! Yeah!

my $Moderation_Msg_Subject =
'Message on: <!-- tmpl_var list_settings.list_name --> needs to be moderated. (original message attached)';
my $Moderation_Msg = <<EOF

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

my $AwaitModeration_Message_Subject =
'Message to: <!-- tmpl_var list_settings.list_name --> w/ Subject: <!-- tmpl_var message_subject --> is awaiting approval.';
my $AwaitModeration_Message = <<EOF

Hello, 

Your recent message to <!-- tmpl_var list_settings.list_name --> with the subject of: 

    <!-- tmpl_var message_subject --> 
  
is awaiting approval. 

-- <!-- tmpl_var Plugin_Name -->

EOF
  ;

my $Accept_Message_Subject =
'Message to: <!-- tmpl_var list_settings.list_name --> w/ Subject: <!-- tmpl_var message_subject --> has been accepted.';
my $Accept_Message = <<EOF

Hello, 

Your recent message to <!-- tmpl_var list_settings.list_name --> with the subject of: 

    <!-- tmpl_var message_subject -->
    
was accepted by the list owner. It will be forwarded to the list soon. 

-- <!-- tmpl_var Plugin_Name -->

EOF
  ;

my $Rejection_Message_Subject =
  'Message to: <!-- tmpl_var list_settings.list_name --> Subject: <!-- tmpl_var message_subject --> rejected.';
my $Rejection_Message = <<EOF

Hello, 

Your recent message to <!-- tmpl_var list_settings.list_name --> with the subject of: 

    <!-- tmpl_var message_subject -->
    
was rejected by the list owner. You may email the list owner at: 

    <!-- tmpl_var list_settings.list_owner_email -->
    
for more details. 

-- <!-- tmpl_var Plugin_Name -->

EOF
  ;

my $Message_Too_Big_Subject =
  'Message to: <!-- tmpl_var list_settings.list_name -->  Subject: <!-- tmpl_var original_subject --> rejected';
my $Message_Too_Big_Message = <<EOF

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

my $Message_Labeled_As_Spam_Subject =
  'Message to: <!-- tmpl_var list_settings.list_name -->  Subject: <!-- tmpl_var original_subject --> Labeled as Spam';
my $Message_Labeled_As_Spam_Message = <<EOF

Hello, <!-- tmpl_var subscriber.email -->, 

We've received a message from you with the Subject,

	<!-- tmpl_var original_subject -->
		
but couldn't deliver it to the mailing list because it hit the spam filters and seems 
suspicious. 

If you did not send a message with this subject, please disregard this message. 

-- <!-- tmpl_var list_settings.list_owner_email -->

EOF
;

#
# There is nothing else to configure in this program.
#---------------------------------------------------------------------#

#---------------------------------------------------------------------#

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

my $App_Version = $DADA::Config::VERSION;

$DADA::Config::LIST_SETUP_DEFAULTS{open_discussion_list} = 0;

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
my $verbose = 0;
my $debug   = 0;    # not used?
my $list;
my $run_list;
my $check_deletions = 0;

my $root_login = 0;

my $checksums = {};

GetOptions(
    "help"            => \$help,
    "test=s"          => \$test,
    "verbose"         => \$verbose,
    "list=s"          => \$run_list,
    "check_deletions" => \$check_deletions,
);

&init_vars;

run()
  unless caller();

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{'Dada_Bridge'}->{$key} ) )
        {

            if (
                defined(
                    $DADA::Config::PLUGIN_CONFIGS->{'Dada_Bridge'}->{$key}
                )
              )
            {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{'Dada_Bridge'}->{$key};

            }
        }
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
	elsif ($q->param('flavor') eq 'mod'){ 
		cgi_mod();
	}
    else {

        my $admin_list;

        ( $admin_list, $root_login ) = check_list_security(
            -cgi_obj    => $q,
            -Function   => 'dada_bridge',
        );

        $list = $admin_list;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $li = $ls->get();

        my $flavor = $q->param('flavor') || 'cgi_default';

        my %Mode = (
            'cgi_default'                 => \&cgi_default,
            'cgi_show_plugin_config'      => \&cgi_show_plugin_config,
            'test_pop3'                   => \&cgi_test_pop3,
            'awaiting_msgs'               => \&cgi_awaiting_msgs,
            'manual_start'                => \&admin_cgi_manual_start,
            'admin_cgi_manual_start_ajax' => \&admin_cgi_manual_start_ajax,
            'cgi_test_pop3_ajax'          => \&cgi_test_pop3_ajax,
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
    }
    else {
        print $q->header();
        print
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Authorization Denied.";
    }
}


sub cgi_test_pop3_ajax { 

	$run_list = $list;
    $verbose  = 1;
    print $q->header(); 
	print '<pre>'; # DEV: do not like
	test_pop3();
 	print '</pre>'; # DEV: do not like   
	
}
sub cgi_test_pop3_tmpl { 

	return q{ 
	<!-- tmpl_set name="title" value="POP3 Login Test" --> 
	
	
	<script type="text/javascript">
	    //<![CDATA[
		Event.observe(window, 'load', function() {
		  test_pop3();				
		});
		
		 function test_pop3() { 
			new Ajax.Updater(
				'test_pop3_results', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						flavor:       'cgi_test_pop3_ajax'
						
					},
				onCreate: 	 function() {
					$('test_pop3_results').hide();
					$('test_pop3_results_loading').show();
				},
				onComplete: 	 function() {
					$('test_pop3_results_loading').hide();
					Effect.BlindDown('test_pop3_results');
				}	
			}
			);
		}
	    //]]>
	</script>
		
   <p id="breadcrumbs">
        <a href="<!-- tmpl_var Plugin_URL -->">
		 <!-- tmpl_var Plugin_Name -->
	</a> &#187; Test POP3 Login
   </p>

	<div id="test_pop3_results_loading" style="display:none;"> 
		<p class="alert">Loading...</p>
	</div> 
	<div id="test_pop3_results"> 			
	</div> 
		
	}
	
}
sub cgi_test_pop3 {
	
	my $tmpl = cgi_test_pop3_tmpl(); 
	require    DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
						{ 
							-data => \$tmpl, 
							-with           => 'admin', 
							-wrapper_params => { 
								-Root_Login => $root_login,
								-List       => $list,  
							},
						-vars => $Plugin_Config,
					}
	); 
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
<script language="JavaScript">
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
        eval {
            $entity =
              $parser->parse_data(
				safely_encode(
                	$mod->get_msg( { -msg_id => $messagename } ) 
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
        my $date = $entity->head->get( 'Date', 0 );
        $date =~ s/\n//g;
        my $messagehdr =
          "From: " . $from . "; Subj: " . $subject . " ; Date: " . $date;

#        my $messagetxt = quotemeta($entity->head->get('Body', 0));
#        my $view_link = "<a href=\"#\" onMouseOver=\"open_new_window(\'" . $messagehdr . "<br>" . $messagetxt . "\')\">View</a>";

        my $confirmation_link = "<a href="
          . $Plugin_Config->{Plugin_URL}
          . '?flavor=mod&list='
          . DADA::App::Guts::uriescape($list)
          . '&process=confirm&msg_id='
          . DADA::App::Guts::uriescape($messagename)
          . ">Accept</a>";

        my $deny_link = "<a href="
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

    print '</pre>';
    print '<p><a href="'
      . $Plugin_Config->{Plugin_URL}
      . ' ">Awaiting Message Index...</a></p>';

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
	print '<pre>';  # DEV no like. 
	start();
	print '</pre>'; # DEV no like. 
	    
}
sub admin_cgi_manual_start {
	
	my $tmpl = admin_cgi_manual_start_tmpl(); 
	
	require    DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
		{ 
			-data => \$tmpl, 
			-with => 'admin', 
			-wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
			
			-vars => {
				Plugin_Name    => $Plugin_Config->{Plugin_Name}, 
				Plugin_URL     => $Plugin_Config->{Plugin_URL}, 
			}, 
		}
	); 
	e_print($scrn); 
	
}




sub admin_cgi_manual_start_tmpl { 
	
	return q{ 
		
		<!-- tmpl_set name="title" value="Manually Running Mailing..." --> 

	   <p id="breadcrumbs">
	        <a href="<!-- tmpl_var Plugin_URL -->">
			 <!-- tmpl_var Plugin_Name -->
		</a> &#187; Manually Running Mailing
	   </p>
			
			<script type="text/javascript">
			    //<![CDATA[
				Event.observe(window, 'load', function() {
				  manual_start();				
				});
				
				 function manual_start(){ 

					new Ajax.Updater(
						'manual_start_results', '<!-- tmpl_var Plugin_URL -->', 
						{ 
						    method: 'post', 
							parameters: {
								flavor:       'admin_cgi_manual_start_ajax'
							},
						onCreate: 	 function() {
							Form.Element.setValue('manual_start_button', 'Checking...');
							$('manual_start_results').hide();
							$('manual_start_results_loading').show();
						},
						onComplete: 	 function() {

							$('manual_start_results_loading').hide();
							Effect.BlindDown('manual_start_results');
							Form.Element.setValue('manual_start_button', 'Check For Messages');
						}	
						});
				}
			    //]]>
			</script>
	

	<form name="some_form" id="some_form"> 
		<input type="button" value="Check For Messages" id="manual_start_button" class="processing" onClick="manual_start();" /> 
	</form>
	
		<div id="manual_start_results_loading" style="display:none;"> 
			<p class="alert">Loading...</p>
		</div> 
		<div id="manual_start_results"> 			
		</div> 
			
	};
}


sub cgi_mod {

	my ($admin_list, $root_login, $checksout) = check_list_security(    
		-cgi_obj         => $q,
        -Function        => 'dada_bridge',
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
	

	if($checksout){ 
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
    my $li = $ls->get();

    my $mod    = SimpleModeration->new( { -List => $list } );
    my $msg_id = $q->param('msg_id');

    my $valid_msg = $mod->is_moderated_msg($msg_id);

    if ( $valid_msg == 1 ) {
        print "<p>Message appears to be valid and exists</p>";

        if ( $q->param('process') eq 'confirm' ) {
			my $g_msg = $mod->get_msg( { -msg_id => $msg_id } ); 
            process(
                {
                    -list => $list,
                    -ls   => $ls,
                    -msg  => \$g_msg,
                }
            );

            print "<p>Message has been sent!</p>";
            if ( $li->{send_moderation_accepted_msg} == 1 ) {
                print "<p>Sending acceptance message!</p>";
                $mod->send_accept_msg(
                    { -msg_id => $msg_id, -parser => $parser } );
            }

            $mod->remove_msg( { -msg_id => $msg_id } );

            #print "<p>Message has been sent!</p>";
        }
        elsif ( $q->param('process') eq 'deny' ) {

            print "<p>Message has been denied and being removed!</p>";
            if ( $li->{send_moderation_rejection_msg} == 1 ) {
                print "<p>Sending rejection message!</p>";
                $mod->send_reject_msg(
                    {
                        -msg_id  => $msg_id,
                        -parser  => $parser,
                        -subject => 'Fix Me'
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

	if($checksout){ 

	    print '<p><a href="'
	      . $Plugin_Config->{Plugin_URL}
	      . '?flavor=awaiting_msgs">Awaiting Message Index...</a></p>';

	    print admin_template_footer(
	        -Form => 0,
	        -List => $list,
	    );
	}
	else { 
		print(
			list_template(
				-Part      => "footer"
			)
		);
	}

}

sub validate_list_email {

	my ($args) = @_; 
	
	my $list       = $args->{-list};  
	if(!exists($args->{-list_email})){ 
		return (1, {}); 
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
	for(@list_types){ 
		$errors->{'list_email_subscribed_to_' . $_} = 0; 
	}
	
	if($list_email eq ''){ 
		return (1, $errors); 
	}
	
	require DADA::MailingList::Settings; 
	require DADA::MailingList::Subscribers; 
	
	for my $t_list(available_lists()){ 
		
		my $ls = DADA::MailingList::Settings->new({-list => $t_list}); 
		if ( $ls->param('list_owner_email') eq $list_email ) { 
			if($t_list eq $list){ 
			    $errors->{list_email_set_to_list_owner_email} = 1;
			}
			else { 
			    $errors->{list_email_set_to_another_list_owner_email} = 1;
			}
			$status = 0; 
	    }
		if ( $ls->param('admin_email') eq $list_email ) {
			
			if($t_list eq $list){ 
	        	$errors->{list_email_set_to_list_admin_email} = 1;     
			}
			else { 
				$errors->{list_email_set_to_another_list_admin_email} = 1;     
			}
			$status = 0; 
			
		}
		my $lh = DADA::MailingList::Subscribers->new({-list => $t_list});

		for my $type(@list_types){ 
			if($lh->check_for_double_email(
		        -Email => $list_email,
		        -Type  => $type,
		    ) == 1){
				if($t_list eq $list_email){ 
					$errors->{'list_email_subscribed_to_' . $type} = 1;   
				}
				else { 
					$errors->{'list_email_subscribed_to_another_' . $type} = 1;   					
				}  
				$status = 0;
			}
		}
	}
	
#	use Data::Dumper; 
#	die Dumper([$status, $errors]); 
    return ($status, $errors);
}

sub cgi_default {

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get();

	my %dada_bridge_settings_defaults = (
		disable_discussion_sending                 => 0,
		group_list                                 => 0,
		prefix_list_name_to_subject                => 0,
		no_prefix_list_name_to_subject_in_archives => 0,
		discussion_pop_email                       => undef,
		discussion_pop_server                      => undef, 
		discussion_pop_username                    => undef, 
		discussion_pop_password                    => undef,
		discussion_pop_auth_mode                   => undef, 
		prefix_discussion_list_subjects_with               => '', 
		enable_moderation                          =>  0,
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
	); 

    # Validation, basically.
    my $list_email_status = 1; 
	my $list_email_errors = {}; 

	my $discussion_pop_password = DADA::Security::Password::cipher_decrypt(
		$li->{cipher_key}, 
		$li->{discussion_pop_password}
	); 
	
    if ( $q->param('process') eq 'edit' ) {
		($list_email_status, $list_email_errors) = validate_list_email(
			{ 
				-list       => $list, 
				-list_email => $q->param('discussion_pop_email'), 
			}
		);
		
        if ( $list_email_status == 1 ) {

			if($Plugin_Config->{Allow_Open_Discussion_List} == 1) { 
				$q->param('open_discussion_list', 0); 
			}
			else { 
			}
			$q->param(
				'discussion_pop_password', 
				DADA::Security::Password::cipher_encrypt( 
					$li->{cipher_key},
					$q->param('discussion_pop_password') 
				)
			);
			
		    $ls->save_w_params(
		        {
		            -associate => $q,
		            -settings  => {
						%dada_bridge_settings_defaults
		            }
		        }
		    );
			
            print $q->redirect(
                -uri => $Plugin_Config->{Plugin_URL} . '?saved=1' );
            return;
        }
        else {

			for ( keys %dada_bridge_settings_defaults) {
				$li->{$_} = $q->param($_);
			}
			$q->param('saved', 0);
			$discussion_pop_password = $q->param('discussion_pop_password'); 
        }
    }
	else { 
		# Not editing!
	}

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $auth_senders_count =
      $lh->num_subscribers({-type => 'authorized_senders'});
    my $show_authorized_senders_table = 1;
    my $authorized_senders            = [];

    if ( $auth_senders_count > 100 || $auth_senders_count == 0 ) {
        $show_authorized_senders_table = 0;
    }
    else {
        $authorized_senders =
          $lh->subscription_list({ -type => 'authorized_senders' });
    }

    my $can_use_ssl = 0;
    eval { require IO::Socket::SSL };
    if ( !$@ ) {
        $can_use_ssl = 1;
    }

    my $discussion_pop_auth_mode_popup = $q->popup_menu(
        -name     => 'discussion_pop_auth_mode',
        -default  => $li->{discussion_pop_auth_mode},
        '-values' => [qw(BEST PASS APOP CRAM-MD5)],
        -labels   => { BEST => 'Automatic' },
    );
    my $spam_level_popup_menu = $q->popup_menu(
        '-values' => [ 1 .. 50 ],
        -default  => $li->{ignore_spam_messages_with_status_of},
        -name     => 'ignore_spam_messages_with_status_of',
    );

    my $curl_location = `which curl`;
       $curl_location = strip( make_safer($curl_location) );

    require DADA::Template::Widgets;

	my $mailing_list_message_from_phrase = $li->{mailing_list_message_from_phrase}; 
	   $mailing_list_message_from_phrase = DADA::Template::Widgets::screen(
		{ 
			-data => \$mailing_list_message_from_phrase,
			-list_settings_vars_param => { 
				-list                 => $list,
				-dot_it               => 1,
			}
		}
	); 
	my $mailing_list_message_from = Email::Address->new($mailing_list_message_from_phrase, $li->{list_owner_email})->format();
	
	

    my $tmpl = default_cgi_template();

	my $saved = $q->param('saved') || 0;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -expr => 1,
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {

				Plugin_URL                 => $Plugin_Config->{Plugin_URL},
                Plugin_Name                => $Plugin_Config->{Plugin_Name},
                Allow_Open_Discussion_List => $Plugin_Config->{Allow_Open_Discussion_List},
                Allow_Manual_Run           => $Plugin_Config->{Allow_Manual_Run},
                Plugin_URL                 => $Plugin_Config->{Plugin_URL},
                Manual_Run_Passcode        => $Plugin_Config->{Manual_Run_Passcode},

                curl_location => $curl_location,
				can_use_ssl   => $can_use_ssl, 
                saved         => $saved,
                authorized_senders             => $authorized_senders,
                show_authorized_senders_table  => $show_authorized_senders_table,

             	discussion_pop_password        => $discussion_pop_password,

                discussion_pop_auth_mode_popup => $discussion_pop_auth_mode_popup,
                can_use_spam_assassin          => &can_use_spam_assassin(),
                spam_level_popup_menu          => $spam_level_popup_menu,

                find_spam_assassin_score_by_calling_spamassassin_directly => (
                    $li->{find_spam_assassin_score_by} eq
                      'calling_spamassassin_directly'
                  ) ? 1 : 0,
                find_spam_assassin_score_by_looking_for_embedded_headers => (
                    $li->{find_spam_assassin_score_by} eq
                      'looking_for_embedded_headers'
                  ) ? 1 : 0,

				list_email_status                                         => $list_email_status, 
				mailing_list_message_from                                 => $mailing_list_message_from, 
				
				error_list_email_set_to_list_owner_email                  => $list_email_errors->{list_email_set_to_list_owner_email}, 
				error_list_email_set_to_list_admin_email                  => $list_email_errors->{list_email_set_to_list_admin_email},
				error_list_email_subscribed_to_list                       => $list_email_errors->{list_email_subscribed_to_list},
				error_list_email_subscribed_to_authorized_senders         => $list_email_errors->{list_email_subscribed_to_authorized_senders},				

				error_list_email_set_to_another_list_owner_email          => $list_email_errors->{list_email_set_to_another_list_owner_email}, 
				error_list_email_set_to_another_list_admin_email          => $list_email_errors->{list_email_set_to_another_list_admin_email},
				error_list_email_subscribed_to_another_list               => $list_email_errors->{list_email_subscribed_to_another_list},
				error_list_email_subscribed_to_another_authorized_senders => $list_email_errors->{list_email_subscribed_to_another_authorized_senders},
								
            },                                            
			-list_settings_vars       => $li, 
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

    if ($test) {

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
"Running all lists - \nTo test an individual list, pass the list shortname in the '--list' parameter...\n\n")
          if $verbose;
        @lists = available_lists();
    }
    else {
        $lists[0] = $run_list;
    }

    require DADA::Mail::MailOut;
	  my (
	        $monitor_mailout_report, $total_mailouts,
	        $active_mailouts,        $paused_mailouts,
	        $queued_mailouts,        $inactive_mailouts
	      )
	      = DADA::Mail::MailOut::monitor_mailout(
	        {
	            -verbose => 0,
	            -action  => 0,
	        }
	      );


    if ( $Plugin_Config->{Room_For_One_More_Check} == 1 ) {

        #/KLUDGE!
        if ( ( $active_mailouts + $queued_mailouts) >= $DADA::Config::MAILOUT_AT_ONCE_LIMIT ) {
            e_print( "There are currently, "
              . ( $active_mailouts + $queued_mailouts )
              . " mass mailout(s) running or queued. Going to wait until that number falls below, "
              . $DADA::Config::MAILOUT_AT_ONCE_LIMIT
              . " mass mailout(s) \n")
              if $verbose;
            return;
        }
        else {
            e_print( "Currently, "
              . ( $active_mailouts + $queued_mailouts )
              . " mass mailout(s) running or queued. \n\n"
              . "That's below our limit ($DADA::Config::MAILOUT_AT_ONCE_LIMIT). \n"
              . "Checking awaiting  messages:\n\n")
              if $verbose;
        }
    }
    else {
        e_print( "Skipping, 'Room for one more?' check\n")
          if $verbose;
    }

    my $messages_viewed = 0;
  QUEUE: for my $list (@lists) {

        if ( $messages_viewed >= $Plugin_Config->{MessagesAtOnce} ) {
            last;
        }

        e_print( "\n" . '-' x 72 . "\nList: " . $list . "\n")
          if $verbose;

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $li = $ls->get();

        if ( $li->{discussion_pop_email} eq $li->{list_owner_email} ) {
            e_print(
"\t\t***Warning!*** Misconfiguration of plugin! The list owner email cannot be the same address as the list email address!\n\t\tSkipping $list...\n")
              if $verbose;
            next;
        }

        next
          if !valid_login_information(
            {
                -list      => $list,
                -list_info => $li
            }
          );

        my $lock_file_fh = undef;
        if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
            $lock_file_fh =
              DADA::App::POP3Tools::_lock_pop3_check(
                { name => 'dada_bridge.lock' } );
        }

        my $pop = pop3_login(
            $list,                          $li,
            $li->{discussion_pop_server},   $li->{discussion_pop_username},
            $li->{discussion_pop_password}, $li->{discussion_pop_auth_mode},
            $li->{discussion_pop_use_ssl},
        );

        if ( defined($pop) ) {

            my $msg_count = $pop->Count;
            my $msgnums   = {};

            # This is weird - do we get everything out of order, here?
            for ( my $cntr = 1 ; $cntr <= $msg_count ; $cntr++ ) {
                my ( $msg_num, $msg_size ) = split ( '\s+', $pop->List($cntr) );
                $msgnums->{$msg_num} = $msg_size;
            }

            my $local_msg_viewed = 0;

            # Hmm, we do, but then we sort them numerically here:
            for my $msgnum ( sort { $a <=> $b } keys %$msgnums ) {

                $local_msg_viewed++;
                e_print( "\t* Message Size: " . $msgnums->{$msgnum} . "\n")
                  if $verbose;
                if ( $msgnums->{$msgnum} >
                    $Plugin_Config->{Max_Size_Of_Any_Message} )
                {

                    e_print( "\t* Warning! Message size ( "
                      . $msgnums->{$msgnum}
                      . " ) is larger than the maximum size allowed ( "
                      . $Plugin_Config->{Max_Size_Of_Any_Message} . " )\n")
                      if $verbose;
                    warn "dada_bridge.pl $App_Version: Warning! Message size ( "
                      . $msgnums->{$msgnum}
                      . " ) is larger than the maximum size allowed ( "
                      . $Plugin_Config->{Max_Size_Of_Any_Message} . ")";

                }
                else {

                    if ( $li->{disable_discussion_sending} != 1 ) {

                        my $full_msg = $pop->Retrieve($msgnum);
						   # We're taking a guess on this one: 
						   $full_msg = safely_decode($full_msg); 
						
                        push (
                            @{ $checksums->{$list} },
                            create_checksum( \$full_msg )
                        );

                        if ( $msgnums->{$msgnum} >
                            $Plugin_Config->{Soft_Max_Size_Of_Any_Message} )
                        {

                            e_print( "\t* Warning! Message size ( "
                              . $msgnums->{$msgnum}
                              . " ) is larger than the soft maximum size allowed ( "
                              . $Plugin_Config->{Soft_Max_Size_Of_Any_Message}
                              . " )\n")
                              if $verbose;
                            warn
"dada_bridge.pl $App_Version: Warning! Message size ( "
                              . $msgnums->{$msgnum}
                              . " ) is larger than the soft maximum size allowed ( "
                              . $Plugin_Config->{Soft_Max_Size_Of_Any_Message}
                              . ")";

                            send_msg_too_big( $list, $li, \$full_msg,
                                $msgnums->{$msgnum} );

                        }
                        else {

                            eval {

                                # The below line is just for testing purposes...
                                # die "aaaaaaarrrrgggghhhhh!!!";

                                my ( $status, $errors ) =

								
                                  validate_msg( $list, \$full_msg, $li );

                                if ($status) {

                                    process(
                                        {
                                            -list => $list,
                                            -ls   => $ls,
                                            -msg  => \$full_msg,
                                        }
                                    );

                                }
                                else {

                                    e_print(
"\t* Message did not pass verification - handling issues...\n")
                                      if $verbose;

                                    handle_errors( $list, $errors, $full_msg,
                                        $li );

                                }

                                append_message_to_file( $full_msg, $list );

                            };

                            if ($@) {

                                warn
"dada_bridge.pl - irrecoverable error processing message. Skipping message (sorry!): $@";
                                e_print(
"dada_bridge.pl - irrecoverable error processing message. Skipping message (sorry!): $@")
                                  if $verbose;

                            }

                        }
                    }
                    else {
                        e_print(
"\t* This sending method has been disabled for $list, deleting message... \n")
                          if $verbose;
                    }
                }

                $messages_viewed++;

                if ( $messages_viewed >= $Plugin_Config->{MessagesAtOnce} ) {
                    e_print(
"\n\nThe limit has been reached of the amount of messages to be looked at for this execution\n\n")
                      if $verbose;
                    last;
                }

            }

            my $delete_msg_count = 0;

            for my $msgnum_d ( sort { $a <=> $b } keys %$msgnums ) {
                e_print( "\t* Removing message from server...\n")
                  if $verbose;
                 $pop->Delete($msgnum_d);
                $delete_msg_count++;

                last
                  if $delete_msg_count >= $local_msg_viewed;

            }
            e_print( "\t* Disconnecting from POP3 server\n")
              if $verbose;

            $pop->Close();

            if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
                DADA::App::POP3Tools::_unlock_pop3_check(
                    {
                        name => 'dada_bridge.lock',
                        fh   => $lock_file_fh,
                    }
                );
            }

            if ($check_deletions) {
                if ( keys %$msgnums ) {
                    message_was_deleted_check( $list, $li );
                }
                else {
                    e_print( "\t* No messages received, skipping deletion check.\n")
                      if $verbose;
                }
            }
        }
        else {
            e_print( "\t* POP3 connection failed!\n")
              if $verbose;
        }
    }
}

sub message_was_deleted_check {

    # DEV: Nice for testing...
    #return;

    e_print( "\n\t* Waiting 5 seconds before removal check...\n")
      if $verbose;

    sleep(5);

    my $list = shift;
    my $li   = shift;

    my $lock_file_fh = undef;
    if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
        $lock_file_fh =
          DADA::App::POP3Tools::_lock_pop3_check(
            { name => 'dada_bridge.lock', } );
    }

    my $pop = pop3_login(
        $list,                          $li,
        $li->{discussion_pop_server},   $li->{discussion_pop_username},
        $li->{discussion_pop_password}, $li->{discussion_pop_auth_mode},
        $li->{discussion_pop_use_ssl},
    );

    if ($pop) {

        my $msg_count = $pop->Count;
        my $msgnums   = {};

        for ( my $cntr = 1 ; $cntr <= $msg_count ; $cntr++ ) {
            my ( $msg_num, $msg_size ) = split ( '\s+', $pop->List($cntr) );
            $msgnums->{$msg_num} = $msg_size;
        }

        for my $msgnum ( sort { $a <=> $b } keys %$msgnums ) {
            my $msg = $pop->Retrieve($msgnum);

            my $cs = create_checksum( \$msg );

            e_print( "\t\tcs:             $cs\n")
              if $verbose;

            my @cs;
            if ( defined( @{ $checksums->{$list} } ) ) {
                @cs = @{ $checksums->{$list} };
            }

            for my $s_cs (@cs) {

                e_print( "\t\tsaved checksum: $s_cs\n")
                  if $verbose;

                if ( $cs eq $s_cs ) {
                    e_print(
"\t* Message was NOT deleted from POP server! Will attempt to do that now...\n")
                      if $verbose;
                    $pop->Delete($msgnum);
                }
                else {
                    e_print(
"\t* Message checksum does not match saved checksum, keeping message for later delivery...\n")
                      if $verbose;
                }
            }
        }
        $pop->Close();

    }
    else {
        e_print( "POP3 login failed.\n");
    }

    if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
        DADA::App::POP3Tools::_unlock_pop3_check(
            {
                name => 'dada_bridge.lock',
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

-----------------------------------------------------------
for a general overview and more instructions, try:

pod2text ./dada_bridge.pl | less

-----------------------------------------------------------

--help

Displays a help menu.

--list

Will allow you to work on one list at a time, instead of all the lists you 
have. 

--verbose 

Prints out a whole lot of stuff on the command line that may be helpful in 
determining what's happening. 

--test pop3

Allows you to test the pop3 login information on the command line. 
Currently the only test available. 

--check_deletions

When this flag is run, an extra check is done to ensure that messages on 
the POP server that should have been removed, have been removed. Shouldn't 
have to be used, but this problem has been... problematic. 

Example: 

 prompt>dada_bridge.pl --test pop3 --list yourlistshortname

Will test the pop3 connection of a list with a shortname of, 
yourlistshortname

Another Example: 

 prompt>dada_bridge.pl --verbose --list yourlistshortname

Will check for messages to deliver for list, 
yourlistshortname> and outputting a lot of information on the command line. 

};
    exit;
}

sub test_pop3 {

    my $li = shift || undef;

    my @lists;

    if ( !$run_list ) {
        e_print(
"Testing all lists - \nTo test an individual list, pass the list shortname in the '--list' parameter...\n\n");
        @lists = available_lists();
    }
    else {
        push ( @lists, $run_list );
    }

    for my $l (@lists) {

        e_print( "\n" . '-' x 72 . "\nTesting List: '" . $l . "'\n");

        unless (
            check_if_list_exists( -List => $l, ) )
        {
            e_print( "'$l' does not exist! - skipping\n");
            next;
        }

        if ( !$li ) {
            my $ls = DADA::MailingList::Settings->new( { -list => $l } );
            $li = $ls->get();
        }

        if ( $li->{disable_discussion_sending} == 1 ) {
            e_print( "'$l' has this feature disabled - skipping.\n");
        }
        else {

            my $lock_file_fh = undef;
            if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {

                $lock_file_fh =
                  DADA::App::POP3Tools::_lock_pop3_check(
                    { name => 'dada_bridge.lock', } );
            }

            my $pop = pop3_login(
                $l,
                $li,
                $li->{discussion_pop_server},
                $li->{discussion_pop_username},
                $li->{discussion_pop_password},
                $li->{discussion_pop_auth_mode},
                $li->{discussion_pop_use_ssl},
            );
            if ($pop) {
                $pop->Close();

                if ( $Plugin_Config->{Enable_POP3_File_Locking} == 1 ) {
                    DADA::App::POP3Tools::_unlock_pop3_check(
                        {
                            name => 'dada_bridge.lock',
                            fh   => $lock_file_fh,
                        }
                    );
                }
                e_print( "\tLogging off of the POP Server.\n");
            }
        }
    }
    e_print( "\n\nPOP3 Login Test Complete.\n\n");
}

sub pop3_login {

    my ( $l, $li, $server, $username, $password, $auth_mode, $use_ssl ) = @_;

    $password =
      DADA::Security::Password::cipher_decrypt( $li->{cipher_key}, $password );

    if ( !valid_login_information( { -list => $l, -list_info => $li } ) ) {
        e_print(
"Some POP3 Login Information is missing - please double check! (aborting login attempt)\n")
          if $verbose;
        return undef;
    }
    else {

        my $pop = undef;

        eval {
            $pop = DADA::App::POP3Tools::mail_pop3client_login(
                {
                    server   => $server,
                    username => $username,
                    password => $password,

                    verbose => $verbose,

                    USESSL    => $use_ssl,
                    AUTH_MODE => $auth_mode,
                }
            );
        };
        if ( !$@ ) {
            return $pop;
        }
        else {
            e_print( "Problems Logging in:\n$@")
              if $verbose;
            warn $@;
            return undef;
        }

    }
}

sub valid_login_information {

    my ($args) = @_;

    my $list = $args->{ -list };
    my $li   = {};
    if ( $args->{ -list_info } ) {
        $li = $args->{ -list_info };
    }
    else {

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        $li = $ls->get();
    }

    return 0 if !$li->{discussion_pop_server};
    return 0 if !$li->{discussion_pop_username};
    return 0 if !$li->{discussion_pop_email};
    return 0 if !$li->{discussion_pop_password};
    return 1;
}

sub validate_msg {

    my $list = shift;
    my $test_msg  = shift;    #ref
	my $msg = ${$test_msg}; # copy of orig
    my $li   = shift;

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

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    if ( lc_email( $li->{discussion_pop_email} ) eq
        lc_email( $li->{list_owner_email} ) )
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

    eval { 
		$entity = $parser->parse_data($msg); 
	};

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
			if ( $entity->head->count('From') > 1 ) {
				print "\t\tMessage has more than one 'From' header? Unsupported email message - will reject!\n"
					if $verbose;
				$errors->{multiple_from_addresses} = 1;
			}
			else { 
		    	my @count = Email::Address->parse($entity->head->get( 'From', 0)); 
				if(scalar(@count) > 1){ 
					print "\t\tMessage has more than one 'From' header? Unsupported email message - will reject!\n"
						if $verbose;
					$errors->{multiple_from_addresses} = 1;
				}
			}
		};
		if($@){ 
			print "\t\tError with multiple from address check! Marking as a problem! - $@"
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
            lc_email( $li->{discussion_pop_email} ) )
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

    my $rough_from   = $entity->head->get( 'From', 0 );
    my $from_address = '';

    if ( defined($rough_from) ) {
        eval {
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

    if ( lc_email($from_address) eq lc_email( $li->{list_owner_email} ) ) {
        print "\t* From: address is the list owner address ; ("
          . $li->{list_owner_email} . ')' . "\n"
          if $verbose;

        if ( $Plugin_Config->{Check_List_Owner_Return_Path_Header} ) {
            ( $errors, $notice ) =
              test_Check_List_Owner_Return_Path_Header( $entity, $errors, $li );
            print $notice
              if $notice != 0 && $verbose;
        }

    }
    else {

        print "\t* From address is NOT from list owner address\n"
          if $verbose;
        $errors->{msg_not_from_list_owner} = 1;

        if ( $li->{enable_moderation} ) {
            print "\t* Moderation enabled...\n"
              if $verbose;
            $errors->{needs_moderation} = 1;

            #}

        }
        else {
            print "\t* Moderation disabled...\n"
              if $verbose;
        }

        if ( $li->{group_list} == 1 ) {

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
                if ( $li->{subscriber_sending_no_moderation} ) {
                    $errors->{needs_moderation} = 0;
                }
                elsif ( $errors->{needs_moderation} == 1 ) {
                    print
                      "\t * however Message still *requires* moderation!\n"
                      if $verbose;
                }
            }
            else {
                print "\t * Message is NOT from a subscriber.\n"
                  if $verbose;
                if (   $li->{open_discussion_list} == 1
                    && $Plugin_Config->{Allow_Open_Discussion_List} == 1 )
                {
                    print "\tPostings from non-subscribers is enabled...\n"
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
            print "\tDiscussion Support disabled...\n"
              if $verbose;
        }
    }

    if ( $li->{enable_authorized_sending} == 1 ) {

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
            if ( $li->{authorized_sending_no_moderation} ) {
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

    if ( $li->{ignore_spam_messages} == 1 ) {
        print "\t* SpamAssassin check enabled...\n"
          if $verbose;

        if ( $li->{find_spam_assassin_score_by} eq
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
                      split ( "\n", $spam_check_message );

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
                            $li->{ignore_spam_messages_with_status_of} )
                        {
                            print
"\t*  Message has *failed* Spam Test (Score of: $score, "
                              . $li->{ignore_spam_messages_with_status_of}
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
                              . $li->{ignore_spam_messages_with_status_of}
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
                    my $spamtest = Mail::SpamAssassin->new(
                        {
#                            debug            => 'all',
                            local_tests_only => 1,
                            dont_copy_prefs  => 1,
                            # userstate_dir    => '/home/hhbc/private/',
                        }
                    );
                    my $mail = $spamtest->parse($spam_check_message);
                    my $spam_status = $spamtest->check($mail);

                    my $score  = $spam_status->get_score();
                    my $report = $spam_status->get_report();

                    if ( $score eq undef && $score != 0 ) {
                        print
"\t* Trouble parsing scoring information - letting message pass...\n"
                          if $verbose
                    }
                    else {

                        if (( $score >=
                            $li->{ignore_spam_messages_with_status_of}) || $spam_status->is_spam())
                        {
                            print
"\t* Message has *failed* Spam Test (Score of: $score, "
                              . $li->{ignore_spam_messages_with_status_of}
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
                              . $li->{ignore_spam_messages_with_status_of}
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
        elsif ( $li->{find_spam_assassin_score_by} eq
            'looking_for_embedded_headers' )
        {

            print "*\t Looking for embedding SpamAssassin Headers...\n"
              if $verbose;

            my $score = undef;
            if ( $entity->head->count('X-Spam-Status') ) {

                my @x_spam_status_fields =
                  split ( ' ', $entity->head->get( 'X-Spam-Status', 0 ) );
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

                if ( $score >= $li->{ignore_spam_messages_with_status_of} ) {
                    print
"\t*  Message has *failed* Spam Test (Score of: $score, "
                      . $li->{ignore_spam_messages_with_status_of}
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
                      . $li->{ignore_spam_messages_with_status_of}
                      . " needed.)\n"
                      if $verbose;
                }

            }
        }
        else {

            print
              "\t* Don't know how to find the SpamAssassin score, sorry!\n"
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
    if ( lc_email( $li->{discussion_pop_email} ) eq lc_email($from_address) ) {
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

    my $entity = shift;
    my $errors = shift;
    my $li     = shift;
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

        if ( lc_email($return_path_address) eq lc_email( $li->{admin_email} ) )
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
    my $list         = shift;
    my $li           = shift;
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
                -list    => $list,
                -headers => {
                    To      => $from_address,
                    Subject => $Message_Too_Big_Subject,
                },
                -body        => $Message_Too_Big_Message,
                -tmpl_params => {
                    -list_settings_vars       => $li,
                    -list_settings_vars_param => { -dot_it => 1, },

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

    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a -list paramater!";
    }
    if ( !exists( $args->{ -ls } ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{ -msg } ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $test_mail = 0;
    if ( exists( $args->{ -test_mail } ) ) {
        $test_mail = $args->{ -test_mail };
    }

    my $list = $args->{ -list };
    my $ls   = $args->{ -ls };
	# $msg is a scalarref
    my $msg  = $args->{ -msg };
	
    print "\t* Processing Message...\n"
      if $verbose;

    if ( $ls->param('send_msgs_to_list') == 1 ) {

        my $n_msg = dm_format(
            {
                -list => $list,
                -msg  => $msg, #scalarref
                -ls   => $ls,
            }
        );

        print "\t* Message being delivered! \n"
          if $verbose;

        my ( $msg_id, $saved_message ) = deliver(
            {
                -list      => $list,
                -msg       => $n_msg,
                -ls        => $ls,
                -test_mail => $test_mail,
            }
        );
        archive(
            {
                -list      => $list,
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
                -list => $list,
                -ls   => $ls,
                -msg  => $msg,
            }
        );
    }

    print "\t* Finished Processing Message.\n\n"
      if $verbose;

}

sub dm_format {

    my ($args) = @_;

    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a -list paramater!";
    }
    if ( !exists( $args->{ -ls } ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{ -msg } ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $list = $args->{ -list };
    my $ls   = $args->{ -ls };
    my $msg  = $args->{ -msg }; # scalarref

	if ( $ls->param('strip_file_attachments') == 1 ) {
        $msg = strip_file_attachments( $msg, $ls );
    }

    require DADA::App::FormatMessages;

    my $fm = DADA::App::FormatMessages->new( -List => $list );
	   $fm->mass_mailing(1); 
   	   $fm->treat_as_discussion_msg(1);
	
    if (   $ls->param('group_list') == 0
        && $ls->param('rewrite_anounce_from_header') == 0 )
    {
        $fm->reset_from_header(0);
    }

	
    my ( $header_str, $body_str ) =
      $fm->format_headers_and_body( 
		-msg            => ${$msg}, 
		-convert_charset => 1,  
	);
	
	# not a scalarref (duh)
    my $all_together =  $header_str . "\n\n" . $body_str;
	return $all_together; 
	
}

sub strip_file_attachments {

    my $msg = shift; #ref
    my $ls  = shift;

    my $entity;

    eval { $entity = $parser->parse_data(${$msg}) };
    if ( !$entity ) {
        die "no entity found! die'ing!";
    }

    print "\t* Stripping banned file attachments...\n\n"
      if $verbose;

    ( $entity, $ls ) = process_stripping_file_attachments( $entity, $ls );

    my $un =  $entity->as_string;
       $un = safely_decode($un); 
	return \$un; 
}

sub process_stripping_file_attachments {

    my $entity = shift;
    my $ls     = shift;

    my @att_bl = split ( ' ', $ls->param('file_attachments_to_strip') );
    my $lt     = {};

    for (@att_bl) {

        $lt->{$_} = lc( $lt->{$_} );
        $lt->{$_} = 1;
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

                push ( @new_parts, $parts[$i] );
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

        if (   $lt->{ lc( $entity->head->mime_type ) } == 1
            || $lt->{ lc($f_ending) } == 1 )
        {

            print
"\t* Stripping attachment with:\n\t\t* name: $name and MIME-Type: "
              . $entity->head->mime_type . "\n";
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

    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a -list paramater!";
    }
    if ( !exists( $args->{ -ls } ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{ -msg } ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $list = $args->{ -list };
    my $ls   = $args->{ -ls };
    my $msg  = $args->{ -msg };

    my $test_mail = 0;
    if ( exists( $args->{ -test_mail } ) ) {
        $test_mail = $args->{ -test_mail };
    }

    my $mh = DADA::Mail::Send->new(
        {

            -list   => $list,
            -ls_obj => $ls,
        }
    );

    #carp "test_mail " . $test_mail;

    $mh->test($test_mail);

    my $entity;
	  $msg = safely_encode($msg); 
	
    eval { 
		$entity = $parser->parse_data(
			$msg
		) 
	};

    if ( !$entity ) {
        print "\t* Message sucks!\n"
          if $verbose;

    }
    else {

		my $headers = $entity->stringify_header;
		   $headers = safely_decode($headers); 
		
        my %headers = $mh->return_headers( $headers );
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

            Body => safely_decode(
				$entity->stringify_body
			),

        );

    }

}

sub deliver {

    my ($args) = @_;

    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a -list paramater!";
    }
    if ( !exists( $args->{ -ls } ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{ -msg } ) ) {
        croak "You must pass a -msg paramater!";
    }

    my $list = $args->{ -list };
    my $ls   = $args->{ -ls };
    my $msg  = $args->{ -msg };

    my $test_mail = 0;
    if ( exists( $args->{ -test_mail } ) ) {
        $test_mail = $args->{ -test_mail };
    }

    my $mh = DADA::Mail::Send->new(
        {
            -list   => $list,
            -ls_obj => $ls,
        }
    );

    $mh->test($test_mail);

    my $entity;

	$msg = safely_encode($msg); 
    eval { 
		$entity = $parser->parse_data($msg);
	};

    if ( !$entity ) {
        print "\t* Message sucks!\n"
          if $verbose;

    }
    else {

		my $headers = $entity->stringify_header;
	       $headers = safely_decode($headers); 
        my %headers = $mh->return_headers( $headers);
		
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

    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a -list paramater!";
    }
    if ( !exists( $args->{ -ls } ) ) {
        croak "You must pass a -ls paramater!";
    }
    if ( !exists( $args->{ -msg } ) ) {
        croak "You must pass a -msg paramater!";
    }
    if ( !exists( $args->{ -msg_id } ) ) {
        croak "You must pass a -msg_id paramater!";
    }
    if ( !exists( $args->{ -saved_msg } ) ) {
        croak "You must pass a -saved_msg paramater!";
    }

    my $list      = $args->{ -list };
    my $ls        = $args->{ -ls };
    my $msg       = $args->{ -msg };
    my $msg_id    = $args->{ -msg_id };
    my $saved_msg = $args->{ -saved_msg };

    if ( $ls->param('archive_messages') == 1 ) {

        require DADA::MailingList::Archives;

# I'm having trouble with the db handle die'ing after we've forked a mailing.
# I wonder if telling Mr. Archives here to create  new connection will help things...

        my $la = DADA::MailingList::Archives->new( { -list => $list } );

        my $entity;
		
        eval { 
			$msg = safely_encode($msg); 
			$entity = $parser->parse_data(
			$msg
			); 
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

    my $list   = shift;
    my $msg    = shift;

	$msg = safely_encode($msg); 
    my $entity = $parser->parse_data(
			$msg
	);

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
		my $ls = DADA::MailingList::Settings->new({-list => $list});
		if($from_address eq $ls->param('discussion_pop_email')) {
			warn "Message is from List Email ($from_address)? Not sending, 'not_allowed_to_post_message' so to not send message back to list!" ;
		}
		else {  	
			my $att = $entity->as_string; 
			   $att = safely_decode($att); 
	        require DADA::App::Messages;
	        DADA::App::Messages::send_not_allowed_to_post_message(
	            {
	                -list       => $list,
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
    my $list = shift;
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
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );

        #my $att = $entity->as_string;
        #   $att = safely_decode($att);
        require DADA::App::Messages;

        DADA::App::Messages::send_generic_email(
            {
                -list    => $list,
                -headers => {
                    To      => $from_address,
                    From    => $ls->param('list_owner_email'),
                    Subject => $Message_Labeled_As_Spam_Subject,
                },
                -body        => $Message_Labeled_As_Spam_Message,
                -tmpl_params => {

                    -list_settings_vars       => $ls->params, 
                    -list_settings_vars_param => { -dot_it => 1, },
                    -subscriber_vars => { 'subscriber.email' => $from_address, },
                     -vars          => {
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

    my $li     = shift;
    my $list   = shift;
    my $msg    = shift;

	$msg = safely_encode($msg); 
    my $entity = $parser->parse_data(
					$msg
			);

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
            From    => $li->{list_owner_email},
            To      => $li->{list_owner_email},
            Subject =>
              $DADA::Config::NOT_ALLOWED_TO_POST_NOTICE_MESSAGE_SUBJECT,
        );

        # DEV: If the above works, we'll have to make this a per-list thingy.
        $reply->attach(
            Type => 'text/plain',
            Data => $DADA::Config::NOT_ALLOWED_TO_POST_NOTICE_MESSAGE,
        );
        $reply->attach(
            Type        => 'message/rfc822',
            Disposition => "inline",
            Data        => safely_decode(safely_encode($entity->as_string)),
        );

        my %msg_headers =
          DADA::App::Messages::_mime_headers_from_string(
            $reply->stringify_header );

        DADA::App::Messages::send_generic_email(
            {
                -list    => $list,
                -headers => {
                    %msg_headers,

                    # Hack? Or bug somewhere else...
                    #'Content-Type' => 'multipart/mixed',
                },
                -body        => $reply->stringify_body,
                -tmpl_params => {
                    -list_settings_vars       => $li,
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

    my $list     = shift;
    my $errors   = shift;
    my $full_msg = shift;
    my $li       = shift;

    my $entity;

	$full_msg = safely_encode($full_msg); 

	
    eval { $entity = $parser->parse_data(
		
			$full_msg) ;
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
	eval {
		$from = (Email::Address->parse($from))[0]->address;
	};
    if($@){
		warn "this was a problem parsing the email address from the header? '$@'"; 
	}




    my $message_id = $entity->head->get( 'Message-Id', 0 );
    $message_id =~ s/\n//g;
    if ( !$message_id ) {

        require DADA::Security::Password;

        my ( $f_user, $f_domain ) = split ( '@', $from );
        my $fake_message_id = '<'
          . DADA::App::Guts::message_id()
          . '.FAKE_MSG_ID'
          . DADA::Security::Password::generate_rand_string('1234567890') . '@'
          . $f_domain . '>';

        $message_id = $fake_message_id;
        $entity->head->replace( 'Message-ID', $fake_message_id );

        warn
"dada_bridge.pl - message has no Message-Id header!...? Creating FAKE Message-Id ($fake_message_id) , to avoid any conflicts...";

    }

    warn
"dada_bridge.pl rejecting sending of received message - \tFrom: $from\tSubject: $subject\tMessage-ID: $message_id\tReasons: $reasons";

    print "\t\tError delivering message! Reasons:\n\n"
      if $verbose;
    for ( keys %$errors ) {
        print "\t\t\t" . $_ . "\n"
          if $errors->{$_} == 1 && $verbose;
    }

    if ( $errors->{list_owner_return_path_set_funny} == 1 ) {

        print "\n\n\t\tlist_owner_return_path_set_funny\n\n"
          if $verbose;

        # and I'm not going to do anything...

    }

    if ( $errors->{message_seen_as_spam} == 1 ) {

		if ( $li->{rejected_spam_messages} eq 'send_spam_rejection_message' ) {
				print "\t\send_spam_rejection_message on its way! \n\n"
	              if $verbose;
	            send_spam_rejection_message( $list, $full_msg );

		}
		elsif ( $li->{rejected_spam_messages} eq 'ignore_spam' ) {
        	print "\n\n\t\t *** Message seen as SPAM - ignoring. ***\n\n"
          		if $verbose;
		}
		else { 
			print "\n\n\t\tlist_settings.rejected_spam_messages is setup impoperly - ignoring message!\n\n";
		}
		
    }
    elsif ( $errors->{multiple_return_path_headers} == 1 ) {

        print "\t\tMessage has multiple 'Return-Path' headers. Ignoring. \n\n"
          if $verbose;
        warn
"$DADA::Config::PROGRAM_NAME Error: Message has multiple 'Return-Path' headers. Ignoring.1023";

    }
    elsif ( $errors->{msg_from_list_address} ) {

        print
"\t\tmessage was from the list address - will not process! - (ignoring) \n\n"
          if $verbose;
        warn
"$DADA::Config::PROGRAM_NAME Error: message was from the list address - will not process! - (ignoring)";
    }
    elsif ($errors->{msg_not_from_subscriber} == 1
        || $errors->{msg_not_from_list_owner} == 1
        || $errors->{msg_not_from_an_authorized_sender} == 1 )
    {

        if ( $li->{send_not_allowed_to_post_msg} == 1 ) {

            print "\t\tmsg_not_from_subscriber on its way! \n\n"
              if $verbose;
            send_msg_not_from_subscriber( $list, $full_msg );

        }

        if ( $li->{send_invalid_msgs_to_owner} == 1 ) {
            print "\t\tinvalid_msgs_to_owner on its way! \n\n"
              if $verbose;
            send_invalid_msgs_to_owner( $li, $list, $full_msg );

        }

#if($errors->{msg_from_list_address}){
#    warn "$DADA::Config::PROGRAM_NAME Error: message was from the list address - will not process! - (ignoring)";
#}

    }
    elsif ( $errors->{needs_moderation} ) {

        print "\t\tMessage being saved for moderation by list owner... \n\n"
          if $verbose;

        my $mod = SimpleModeration->new( { -List => $list } );
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

        if ( $li->{send_moderation_msg} == 1 ) {
            print "\t\t * Sending 'awaiting moderation' message!\n\n"
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

        print "\t\tOther awaiting messages:\n\n"
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

    my $msg  = shift;
    my $list = shift;
    my $rp   = find_return_path($msg);

    my $file =
      $DADA::Config::TMP . '/dada_bridge_received_msgs-' . $list . '.mbox';

    print "Saving message at: '$file' \n"
      if $verbose;

    $file = DADA::App::Guts::make_safer($file);

    open( APPENDLOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET.')', $file ) or die $!;
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

    my $tmpl = cgi_show_plugin_config_tmpl();

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
            -vars => {
                Plugin_URL  => $Plugin_Config->{Plugin_URL},
                Plugin_Name => $Plugin_Config->{Plugin_Name},
                configs     => $configs,
            },
        },
    );
    e_print($scrn);

}

sub cgi_show_plugin_config_tmpl {

    return q{ 
    
    
	<!-- tmpl_set name="title" value="<!-- tmpl_var Plugin_Name --> Plugin Configuration" -->
	
  <p id="breadcrumbs">
   <a href="<!-- tmpl_var Plugin_URL -->"> 
   <!-- tmpl_var Plugin_Name --> 
   </a> 
   &#187;
        Plugin Configuration
   </a> 
  </p> 

        <table> 
        
        <!-- tmpl_loop configs --> 
        
        <tr> 
          <td> 
           <p> 
             <strong> 
              <!-- tmpl_var name --> 
              </strong>
            </p>
           </td> 
           <td> 
            <p>
            <!-- tmpl_var value --> 
            </p>
            </td> 
            </tr> 
        <!-- /tmpl_loop --> 
        </table>
 
    };

}

sub inject {

    my ($args) = @_;

    my $msg       = $args->{ -msg };
	   # We're taking a guess, on this one: 
	   $msg 	  = safely_decode( $msg );
	 
    my $send_test = 0;
    my $list      = $args->{ -list };
    my $test_mail = 0;

    if ( exists( $args->{ -send_test } ) ) {
        $send_test = $args->{ -send_test };
    }
    if ( exists( $args->{ -verbose } ) ) {
        $verbose = $args->{ -verbose };
        print "I'm verbosing!\n";
    }
    if ( exists( $args->{ -test_mail } ) ) {
        $test_mail = $args->{ -test_mail };
    }

    my $ls;
    if ( exists( $args->{ -ls } ) ) {
        $ls = $args->{ -ls };

    }
    else {
        require DADA::MailingList::Settings;
        $ls = DADA::MailingList::Settings->new( { -list => $list } );
    }

    # used later down, there.
    my $li = $ls->get;

#	die q{	die $ls->param('disable_discussion_sending');  "} . $ls->param('disable_discussion_sending') . '"';
    if ( $ls->param('disable_discussion_sending') != 1 ) {
        my ( $status, $errors );

        eval {

            ( $status, $errors ) = validate_msg( $list, \$msg, $li );
            if ($status) {
                process(
                    {
                        -list      => $list,
                        -ls        => $ls,
                        -msg       => \$msg,
                        -test_mail => $test_mail,
                    }
                );

                append_message_to_file( $msg, $list );

                return ( $status, $errors );

            }
            else {

                print
                  "\tMessage did not pass verification - handling issues...\n"
                  if $verbose;

                handle_errors( $list, $errors, $msg, $li );

                append_message_to_file( $msg, $list );

                return ( $status, $errors );

            }

        };


        if ($@) {

            warn
"dada_bridge.pl - irrecoverable error processing message. Skipping message (sorry!): $@";
            print
"dada_bridge.pl - irrecoverable error processing message. Skipping message (sorry!): $@"
              if $verbose;
            return ( 0, { irrecoverable_error => 1 } );

        }

        else {

            return ( $status, $errors );

       }

    }
    else {
        print
"\tThis sending method has been disabled for $list, ignoring message... \n"
          if $verbose;
        return ( 0, { disabled => 1 } );
    }

}

sub default_cgi_template {

    return q{ 


<!-- tmpl_set name="title" value="Discussion List Options" --> 

<!-- tmpl_if saved -->
	<!-- tmpl_var GOOD_JOB_MESSAGE  -->
<!-- /tmpl_if -->

<!-- tmpl_unless list_email_status -->
	<div style="background:#fcc;margin:5px;padding:5px;text-align:center">
		  <h1>
			Information Not Saved! Please Fix Problems Below.
		<h1/>
	</div> 
<!--/tmpl_unless--> 
<form name="default_form" action="<!-- tmpl_var Plugin_URL --> "method="post">



<!-- tmpl_if list_settings.disable_discussion_sending -->
 <div style="background:#fcc;margin:5px;padding:5px;text-align:center">
  <h1>
   This Plugin is Currently Disabled for This List!
  </h1> 

<p>
 Uncheck the option labeled, <em>Disable sending using this method</em> below to enable this plugin for this Mailing List.
</p>
 </div> 
  
<!--/tmpl_if--> 



<fieldset> 

<legend>List Email Address Configuration</legend>

 

  <blockquote class="positive">
 <p>
   The 
   <strong> 
    List Email 
   </strong>
   address is the email address you will be sending to, to have your messages 
   broadcast to your entire Subscription List. This email account needs to be created, 
   if it's not already available. Make sure this address is not being used 
   for <strong>any</strong> other purpose.

 </p> 
 <p>
   The 
   <strong>
    List Email 
   </strong>
   should be different than both your list owner email address 
   (<em><!-- tmpl_var list_settings.list_owner_email escape="HTML" --></em>)
   and your list admin email address (<em><!-- tmpl_var list_settings.admin_email escape="HTML" --></em>). 
   If 
   <strong>
    &quot;Make this list a discussion list&quot;
   </strong> 
   has been checked, all subscribers can mail to the <strong>List Email</strong>
   and have their message sent to all other subscribers. 
 </p>
</blockquote> 


<!-- tmpl_if error_list_email_set_to_list_owner_email --> 
		<ul> 
			<li>
				<p class="error">
					Your List Email was set to the same address as the List Owner Email. It needs to be set to a different address. 
				</p>
			</li>
		</ul>
	<!-- /tmpl_if -->
	
<!-- tmpl_if error_list_email_set_to_another_list_owner_email --> 
		<ul> 
			<li>
				<p class="error">
					Your List Email was set to the same address as a List Owner Email address of a different list. It needs to be set to a different address. 
				</p>
			</li>
		</ul>
	<!-- /tmpl_if -->
		
<!-- tmpl_if error_list_email_set_to_list_admin_email --> 
	<ul> 
		<li>
			<p class="error">
				Your List Email was set to the same address as the List Admin Email. It needs to be set to a different address. 
			</p>
		</li>
	</ul>
<!-- /tmpl_if -->
<!-- tmpl_if error_list_email_set_to_another_list_admin_email --> 
	<ul> 
		<li>
			<p class="error">
				Your List Email was set to the same address as the List Admin Email address of a different list. It needs to be set to a different address. 
			</p>
		</li>
	</ul>
<!-- /tmpl_if -->

<!-- tmpl_if error_list_email_subscribed_to_list --> 
	<ul> 
		<li>
			<p class="error">
				Your List Email is currently subscribed to your Subscription List. It needs to be set to a different address. 
			</p>
		</li>
	</ul>
<!-- /tmpl_if -->
<!-- tmpl_if error_list_email_subscribed_to_authorized_senders --> 
	<ul> 
		<li>
			<p class="error">
				Your List Email is currently subscribed to your Authorized Senders List. It needs to be set to a different address. 
			</p>
		</li>
	</ul>
<!-- /tmpl_if -->

<!-- tmpl_if error_list_email_subscribed_to_another_list --> 
	<ul> 
		<li>
			<p class="error">
				Your List Email is currently subscribed to another mailing list's Subscription List. It needs to be set to a different address. 
			</p>
		</li>
	</ul>
<!-- /tmpl_if -->
<!-- tmpl_if error_list_email_subscribed_to_another_authorized_senders --> 
	<ul> 
		<li>
			<p class="error">
				Your List Email is currently subscribed to another mailing list's Authorized Senders List. It needs to be set to a different address. 
			</p>
		</li>
	</ul>
<!-- /tmpl_if -->




 <table width="100%" cellpadding="5" cellspacing="0">
  <tr> 
   <td>
    <label for="discussion_pop_email">
     List Email:
    </label>
   </td>
   <td>


    <input name="discussion_pop_email" id="discussion_pop_email" type="text" value="<!-- tmpl_var list_settings.discussion_pop_email -->" class="full" <!-- tmpl_unless list_email_status -->style="background:red;font-weight:bold;color:white;border:3px solid black"<!-- /tmpl_unless -->/>
	
	
   </td>
  </tr>
  <tr> 
   <td width="125">
    <label for="discussion_pop_server">
     POP3 Server:
    </label>
   </td>
   <td>
    <input name="discussion_pop_server" id="discussion_pop_server" type="text" value="<!-- tmpl_var list_settings.discussion_pop_server -->" class="full" />
   </td>
  </tr>
  <tr>
   <td width="125">
    <label for="discussion_pop_username">
     POP3 Username:
    </label>
   </td>
   <td>
    <input name="discussion_pop_username" id="discussion_pop_username" type="text" value="<!-- tmpl_var list_settings.discussion_pop_username -->" class="full" />
   </td>
  </tr>
  <tr>
   <td width="125">
    <label for="discussion_pop_password">
     POP3 Password:
    </label>
   </td>
   <td>
    <input name="discussion_pop_password" id="discussion_pop_password" type="password" value="<!-- tmpl_var name=discussion_pop_password escape="HTML"-->" />
   </td>
  </tr>


<tr>
     <td>
      <p>
       <label for="discussion_pop_auth_mode">
        Type:
       </label>
      </p>
     </td>
     <td>
      <p>
       <!-- tmpl_var discussion_pop_auth_mode_popup --> 
     </p>
     </td>
    </tr>
    
    
   </table>
   
    <table <!-- tmpl_unless can_use_ssl -->class="disabled"<!--/tmpl_unless-->> 
     <tr>
      <td>
       <p>
        <input type="checkbox" name="discussion_pop_use_ssl" id="discussion_pop_use_ssl" value="1" <!-- tmpl_if list_settings.discussion_pop_use_ssl -->checked="checked"<!-- /tmpl_if --> <!-- tmpl_unless can_use_ssl -->disabled="disabled"<!--/tmpl_unless-->/>
       </p>
      </td>
      <td>
       <p>
        <label for="discussion_pop_use_ssl">
         Use Secure Sockets Layer (SSL)
        </label>
        <!-- tmpl_unless can_use_ssl -->
            <br />
            <span class="error">
             Disabled. The IO::Socket::SSL module needs to be installed.
            </span>
        <!--/tmpl_unless--> 
        
       </p>
      </td>
     </tr>
    </table> 
    
  </fieldset>   



<fieldset> 
 <legend> 
General
</legend> 


 <table width="100%" cellspacing="0" cellpadding="5">
  <tr>
   <td>
    <input name="disable_discussion_sending" id="disable_discussion_sending" type="checkbox" value="1" <!--tmpl_if list_settings.disable_discussion_sending -->checked="checked"<!--/tmpl_if--> />
   </td>
   <td>
   
    
    <p>
     <label for="disable_discussion_sending">
      Disable sending using this method
     </label>
          <br /> 
      ALL e-mails received at (<strong><!-- tmpl_var list_settings.discussion_pop_email escape="HTML" --></strong>) will be deleted.     
    </p>
   
   
   
   </td>
  </tr>


  <tr> 
   <td> 
    <input name="enable_authorized_sending" id="enable_authorized_sending" type="checkbox" value="1" <!--tmpl_if list_settings.enable_authorized_sending -->checked="checked"<!--/tmpl_if--> /> 
   </td>
   <td>
    <p>
     <label for="enable_authorized_sending">
      Allow Messages Received From Authorized Senders
     </label>
     <br /> 
     
       Authorized Senders may post to announce-only lists and discussions lists without being on the subscription list themselves. Once enabled, you may 
     add Authorized Senders using the 
     
     <!-- tmpl_if list_settings.enable_authorized_sending --> 
      <a href="<!-- tmpl_var S_PROGRAM_URL -->?f=view_list&type=authorized_senders">
       View</a>/<a href="<!-- tmpl_var S_PROGRAM_URL -->?f=add&type=authorized_senders">Add
      </a>


	<!-- tmpl_else --> 
	View/Add 
     <!--/tmpl_if-->

 list Administration Screens.
    </p>
	<!-- tmpl_if list_settings.enable_authorized_sending --> 
	
	
	
	
     
  		  <!-- tmpl_if show_authorized_senders_table --> 
			<p><strong>Your Authorized Senders:</strong></p>
			<div style="max-height: 200px; width:250px; overflow: auto; border:1px solid black">
			 <table cellpadding="2" cellspacing="0" border="0" width="100%">
	
				<!-- tmpl_loop authorized_senders --> 
					  <tr
					 <!-- tmpl_if name="__odd__" --> style="background-color:#ccf;"<!-- tmpl_else --> style="background-color:#fff;" <!--/tmpl_if-->>
					 <td> 
					 <p><!-- tmpl_var email --></p>
					</td> 
					</tr> 
		
				<!--/tmpl_loop-->
				
				</table> 
				
				</div> 
				
		<!-- /tmpl_if --> 	
	
	
	<!--/tmpl_if-->

    </td> 
   </tr> 
   
   </table> 
   
</fieldset> 

<fieldset> 
 <legend> 
 Announce Only List Options
 </legend> 



 <table width="100%" cellspacing="0" cellpadding="5">
  <tr> 
   <td> 
    <input name="rewrite_anounce_from_header" id="rewrite_anounce_from_header" type="checkbox" value="1" <!--tmpl_if list_settings.rewrite_anounce_from_header -->checked="checked"<!--/tmpl_if--> /> 
   </td>
   <td>
    <p>
     <label for="rewrite_anounce_from_header">
      Rewrite the From: header on announce-only messages to the List Owner address 
     </label>
     <br /> 
     
     Outgoing announce-only mass mailings will have the From: header set to: <code><!-- tmpl_var mailing_list_message_from escape="HTML" --></code>
     </p>
    </td> 
   </tr> 
   
   </table> 
   
</fieldset> 





<fieldset> 
 <legend> 
 Discussion List Options
 </legend> 


 <table width="100%" cellspacing="0" cellpadding="5">
  <tr> 
   <td align="right">
    <input name="group_list" id="group_list" type="checkbox" value="1" <!--tmpl_if list_settings.group_list -->checked="checked"<!--/tmpl_if--> /> 
   </td>
   <td>
    <p>
     <label for="group_list">
      Make this mailing list a Discussion List
     </label>
     <br />
     Everyone subscribed to your list may post messages for everyone else 
     on your list by sending  messages to (<strong><!-- tmpl_var list_settings.discussion_pop_email escape="HTML" --></strong>).
   </p>
  	 <table width="100%" cellspacing="0" cellpadding="5">
        <tr> 
        
 
   	 
	<tr> 
   <td align="right">
    <input name="prefix_list_name_to_subject" id="prefix_list_name_to_subject" type="checkbox" value="1" <!--tmpl_if list_settings.prefix_list_name_to_subject -->checked="checked"<!--/tmpl_if--> />
   </td>
   <td>  
    <p>
     <label for="prefix_discussion_list_subjects_with">
      Prefix message subjects with the:
     </label>
     <br />
     <select name="prefix_discussion_list_subjects_with">
      <option value="list_shortname" <!--tmpl_if expr="(list_settings.prefix_discussion_list_subjects_with eq 'list_shortname')" -->selected="selected" <!--/tmpl_if--> >list shortname: [<!-- tmpl_var list_settings.list escape="HTML" -->]</option>
      <option value="list_name"      <!--tmpl_if expr="(list_settings.prefix_discussion_list_subjects_with eq 'list_name')" -->selected="selected" <!--/tmpl_if--> >List Name: [<!-- tmpl_var list_settings.list_name escape="HTML" -->]</option>
     </select> 
     <br />
     The List Name/Short Name will be surrounded by square brackets. 
     
     <table>
      <tr> 
       <td>
           <input name="no_prefix_list_name_to_subject_in_archives" id="no_prefix_list_name_to_subject_in_archives" type="checkbox" value="1" <!--tmpl_if list_settings.no_prefix_list_name_to_subject_in_archives -->checked="checked"<!--/tmpl_if--> />
       </td> 
       <td> 
        <label for="no_prefix_list_name_to_subject_in_archives">
         Do not append the list/list shortname to archived messages (only outgoing messages).  
        </label>
       </td> 
      </tr> 
     </table> 
    </p>
   </td>
  </tr>
   <tr> 
   <td align="right">
    <input name="mail_discussion_message_to_poster" id="mail_discussion_message_to_poster" type="checkbox" value="1" <!--tmpl_if list_settings.mail_discussion_message_to_poster -->checked="checked"<!--/tmpl_if--> />
   </td>
   <td>
    <label for="mail_discussion_message_to_poster">
     Send message posters a copy of the message they've sent the discussion list. 
    </label>
    <br />
   </td>
  </tr>

     <tr> 
   <td align="right">
    <input name="discussion_template_defang" id="discussion_template_defang" type="checkbox" value="1" <!--tmpl_if list_settings.discussion_template_defang -->checked="checked"<!--/tmpl_if--> />
   </td>
   <td>
    <label for="discussion_template_defang">
	DON'T parse templates in discussion messages
    </label>
    <br />
	Parsing Template Tags could create formatting problems. 
   </td>
  </tr>
 </table> 


	<p><label>Replies to messages should:</label><br/> 
	<table>
     <tr>
      <td>
	<p>
	 <input type="radio" name="set_to_header_to_list_address" value="1" <!--tmpl_if list_settings.set_to_header_to_list_address -->checked="checked"<!--/tmpl_if--> /></p>
	  </td><td>
	<p><label>be addressed to the sender</label><br />
	 <em>(you can still "Reply-All" to send the reply to the sender, as well as the mailing list)</em></p>
	</td>
	</tr> 
	<tr> 

	<td>
	<p>
	 <input type="radio" name="set_to_header_to_list_address" value="0" <!--tmpl_unless list_settings.set_to_header_to_list_address -->checked="checked"<!--/tmpl_unless--> />
	</p></td> 
	<td> 
	<label>be addressed to the mailing list</label>
</p> 
</td> 
</tr> 
</table>


      </td>
  </tr>


<!-- tmpl_if Allow_Open_Discussion_List -->
        <tr> 
       <td align="right">
        <input name="open_discussion_list" id="open_discussion_list" type="checkbox" value="1" <!--tmpl_if list_settings.open_discussion_list -->checked="checked"<!--/tmpl_if--> />
       </td>
       <td>
        <label for="open_discussion_list">
         Allow messages to also be posted to the list from non-subscribers.         
        </label>
         <br /><span class="alert">(This opens up your mailing list to possible abuse, unless moderated)</span> 
       </td>
      </tr>
 <!-- /tmpl_if -->




 </table> 


<fieldset> 
 <legend>List Moderation Options</legend> 
  <table width="100%" cellspacing="0" cellpadding="5">    
  <tr> 
   <td> 
    <input name="enable_moderation" id="enable_moderation" type="checkbox" value="1" <!--tmpl_if list_settings.enable_moderation -->checked="checked"<!--/tmpl_if--> /> 
   </td>
   <td>
    <p>
     <label for="enable_moderation">
      Use Moderation
     </label>
     
     <!-- tmpl_if list_settings.enable_moderation --> 
       - <a href="<!-- tmpl_var Plugin_URL -->?flavor=awaiting_msgs">View/Manage Messages Awaiting Moderation</a>.
     <!--/tmpl_if-->
     
     <br />      
          Messages sent to your discussion list will first have to be approved by: 
      </p>
   	  <p>
 		<input type="radio" name="moderate_discussion_lists_with" value="list_owner_email" <!--tmpl_if expr="(list_settings.moderate_discussion_lists_with eq 'list_owner_email')" -->checked="checked" <!--/tmpl_if--> />
		<label for="">
			List Owner
		</label>
		<br />

 			<input type="radio" name="moderate_discussion_lists_with" value="authorized_sender_email" <!--tmpl_if expr="(list_settings.moderate_discussion_lists_with eq 'authorized_sender_email')" -->checked="checked"<!--/tmpl_if--><!-- tmpl_unless list_settings.enable_authorized_sending -->disabled="disabled"<!-- /tmpl_unless --> />
			<label for="">
				List Owner or an Authorized Sender
			</label>
			<!-- tmpl_unless list_settings.enable_authorized_sending --><span class="error">
	             Disabled. Enable, &quot;Allow Messages Received From Authorized Senders &quot;, to enabled this option.
	            </span>
			<!-- /tmpl_unless -->
		
		</p>      
     <table  cellspacing="0" cellpadding="5">

  <!-- tmpl_if list_settings.enable_authorized_sending -->  
     <!-- tmpl_if list_settings.group_list -->          
      <tr>
       <td>
        <input name="authorized_sending_no_moderation" id="authorized_sending_no_moderation" type="checkbox" value="1" <!--tmpl_if list_settings.authorized_sending_no_moderation -->checked="checked"<!--/tmpl_if--> />
       </td>
       <td>
        <p>
         <label for="authorized_sending_no_moderation">
          Allow Authorized Senders to send messages to the entire list without moderation
         </label><br /> 
         If not checked, messages from Authorized Senders also require moderation.
        </p>
       </td>
       </tr>     
     <!--/tmpl_if-->
   <!--/tmpl_if-->     
     	   
 <!-- tmpl_if list_settings.open_discussion_list -->       
   <!-- tmpl_if list_settings.group_list --> 
      <tr>
       <td>
        <input name="subscriber_sending_no_moderation" id="subscriber_sending_no_moderation" type="checkbox" value="1" <!--tmpl_if list_settings.subscriber_sending_no_moderation -->checked="checked"<!--/tmpl_if--> />
       </td>
       <td>
        <p>
         <label for="subscriber_sending_no_moderation">
          Allow Subscribers to send messages to the entire list without moderation
         </label><br /> 
         If not checked, messages from Subscribers require moderation.
        </p>
       </td>
       </tr> 
   <!-- /tmpl_if --> 
 <!-- /tmpl_if --> 
      
     <table  cellspacing="0" cellpadding="5">
           <tr>
       <td>
        <input name="send_moderation_msg" id="send_moderation_msg" type="checkbox" value="1" <!--tmpl_if list_settings.send_moderation_msg -->checked="checked"<!--/tmpl_if--> />
       </td>
       <td>
        <p>
         <label for="send_moderation_msg">
          Send a, &quot;Message Received, Awaiting Moderation&quot; Message
         </label><br /> 
         The original poster will receive a message stating that the message has been received, but requires moderation.
        </p>
       </td>
       </tr>
       
       <tr>
       <td>
        <input name="send_moderation_accepted_msg" id="send_moderation_accepted_msg" type="checkbox" value="1" <!--tmpl_if list_settings.send_moderation_accepted_msg -->checked="checked"<!--/tmpl_if--> />
       </td>
       <td>
        <p>
         <label for="send_moderation_accepted_msg">
          Send an, &quot;Acceptance&quot; Message
         </label><br /> 
         The original poster will receive a message stating that the moderated message was accepted.
        </p>
       </td>  
       </tr>
       
      <tr>
       <td>
        <input name="send_moderation_rejection_msg" id="send_moderation_rejection_msg" type="checkbox" value="1" <!--tmpl_if list_settings.send_moderation_rejection_msg -->checked="checked"<!--/tmpl_if--> />
       </td>
       <td>
        <p>
         <label for="send_moderation_rejection_msg">
          Send a, &quot;Rejection&quot; Message
         </label><br /> 
         The original poster will receive a message stating that the moderated message was rejected.
        </p>
       </td>
      </tr>
    </table> 
    
   </td>
  </tr>
 
	</table>
  
  </td>
  </tr>
  
  
  
 </table> 


</fieldset> 


</fieldset> 
<fieldset> 
 <legend> 
 Delivery
 </legend> 

 <table width="100%" cellspacing="0" cellpadding="5">
  <tr> 
   <td> 
    <p>
     <label>
     	When allowed messages are received:
	</label>
    </p>
    <table>
     <tr>
      <td> 
       <input type="checkbox" name="send_msgs_to_list" id="send_msgs_to_list" value="1" <!-- tmpl_if list_settings.send_msgs_to_list -->checked="checked"<!--/tmpl_if--> />
      </td> 
      <td>
       <label for="send_msgs_to_list">
        send the messages to the Subscription List.
       </label>
      </td>
     </tr> 
     <tr> 
      <td>
       <input type="checkbox" name="send_msg_copy_to" id="send_msg_copy_to" value="1" <!-- tmpl_if list_settings.send_msg_copy_to -->checked="checked"<!--/tmpl_if--> />
      </td>
      <td>
       <label for="send_msg_copy_to">
        forwarded  a copy <label for="send_msg_copy_address">to</label>:
       </label>
       <p>
        <input type="text" name="send_msg_copy_address" id="send_msg_copy_address"value="<!-- tmpl_var list_settings.send_msg_copy_address -->" />
       </p>
      </td> 
     </tr> 
     <tr> 
      <td>
		&nbsp;
      </td>
      <td>
       <p>
        <!-- tmpl_if list_settings.archive_messages --> 
         <p class="positive"> 
         * Archiving is Enabled.
         </p>
        <!--/tmpl_if-->
       </p>
      </td> 
     </tr> 
    </table> 
   </td>
  </tr>
  <tr> 
  
  
  
  
   <td> 
    <p>
     <label>
  		When disallowed messages are received:
     </label>
    </p>
    <table> 
     <tr>
      <td> 
       <input type="checkbox" name="send_invalid_msgs_to_owner" id="send_invalid_msgs_to_owner" value="1" <!-- tmpl_if list_settings.send_invalid_msgs_to_owner -->checked="checked"<!--/tmpl_if--> />
      </td> 
      <td>
       <label for="send_invalid_msgs_to_owner">
        send the List Owner a &quot;Not a Subscriber&quot; email message, with the original message attached.
       </label>
      </td>
     </tr> 
     
     <!--
     <tr> 
      <td>
       <input type="checkbox" />
      </td>
      <td>
       be forwarded to the Authorized Senders (Authorized Sending must be turned on!).
      </td> 
     </tr>
     --> 
     
     <tr> 
      <td> 
       <input type="checkbox" name="send_not_allowed_to_post_msg" id="send_not_allowed_to_post_msg" value="1" <!-- tmpl_if list_settings.send_not_allowed_to_post_msg -->checked="checked"<!--/tmpl_if--> />
      </td> 
      <td> 
       <label for="send_not_allowed_to_post_msg">
        send back a &quot;Not Allowed to Post&quot; message.
       </label>
      </td>  
     </tr> 
    </table> 
   </td> 
  </tr>
 </table>
 
 </fieldset> 



<fieldset> 
 <legend> 
Mailing List Security
</legend> 
 


   <table>


   <tr>
      <td> 
       <input type="checkbox" name="ignore_spam_messages" id="ignore_spam_messages" value="1" <!-- tmpl_if list_settings.ignore_spam_messages -->checked="checked"<!--/tmpl_if--> />
      </td> 
      <td>
       <label for="ignore_spam_messages">
        Reject messages labeled as, &quot;SPAM&quot; by SpamAssassin filters. 
       </label></p> 
      
       
        <!-- tmpl_unless can_use_spam_assassin --> 
          <p class="error">* SpamAssassin may not be installed on your server.</p>
        <!--/tmpl_unless--> 
      
        <p>Find SpamAssassin Score By: 
        <table border="0"> 
         <tr> 
          <td><input type="radio" id="looking_for_embedded_headers" name="find_spam_assassin_score_by" value="looking_for_embedded_headers" <!-- tmpl_if find_spam_assassin_score_by_looking_for_embedded_headers -->checked="checked"<!--/tmpl_if--> /></td>
          <td>
           <p>
            <label for="looking_for_embedded_headers">
            Look for the embedded SpamAssassin Headers (Fast! But may not be available)
            </label> 
           </p>
          </td>
         </tr>
         
         <tr> 
          <td><input type="radio" id="calling_spamassassin_directly" name="find_spam_assassin_score_by" value="calling_spamassassin_directly" <!-- tmpl_if find_spam_assassin_score_by_calling_spamassassin_directly -->checked="checked"<!--/tmpl_if--> /></td>
          <td>
           <p>
            <label for="calling_spamassassin_directly">
            Use the SpamAssassin Modules directly (Slow, resource-intensive)
            </label> 
           </p>
          </td>
         </tr>
         
         <!-- 
         
         <tr> 
          <td><input type="radio" disabled="disabled" /></td>
          <td>
           <p>
            <label> 
             Use the spamd daemon (not currently supported)
            </label>
           </p>
          </td>
         </tr>
         
         --> 
         
        </table> 
      
       <p> 
        Messages must reach a SpamAssassin level of at least: <!-- tmpl_var spam_level_popup_menu --> to be considered SPAM.
       </p> 
	<table cellpadding="5"> 
	<tr> 
	<td><input type="radio" name="rejected_spam_messages" value="ignore_spam" <!-- tmpl_if expr="(list_settings.rejected_spam_messages eq 'ignore_spam')" -->checked="checked"<!-- /tmpl_if --> /></td>
	<td><p><label>Ignore Spam Messages</label><br /> 
	</p>
	</td>
	</tr> 
	<tr> 
	<td><input type="radio" name="rejected_spam_messages" value="send_spam_rejection_message" <!-- tmpl_if expr="(list_settings.rejected_spam_messages eq 'send_spam_rejection_message')" -->checked="checked"<!-- /tmpl_if -->/><label></td><td><p><label>Send a Rejection Message</label><br /> 
	The original poster will receive a message stating that the original message was rejected.

</p> 
	</td>
	</tr> 
	</table> 

      </td>
     </tr> 


     
     <tr>
      <td> 
      
 <input type="checkbox" name="strip_file_attachments" id="strip_file_attachments" value="1" <!-- tmpl_if list_settings.strip_file_attachments -->checked="checked"<!--/tmpl_if--> />
 
 </td>
 <td>
 <p>
 <label for="strip_file_attachments">Strip attachments that have the following file ending or MIME-Type:</label> <em>(separated by spaces)</em>
	 <br />
	 
         <input type="text" name="file_attachments_to_strip" id="file_attachments_to_strip"value="<!-- tmpl_var list_settings.file_attachments_to_strip -->" class="full" />

  </p>
 </td>
 </tr>
 </table> 
 
 
 </fieldset> 
 
 
   
 <input name="flavor"  type="hidden" value="cgi_default" />
 <input name="process" type="hidden" value="edit" />
 <div class="buttonfloat"> 
  <input type="reset"  class="cautionary" value="Clear Changes" />
  <input type="submit" class="processing" value="Save Changes" />
 </div> 
 <div class="floatclear"></div> 
 
 
</form>



<fieldset> 

<legend>Manually Run <!-- tmpl_var Plugin_Name --></legend>


 <div class="buttonfloat">


<form method="get" style="display:inline">
 <input name="flavor" type="hidden" value="test_pop3" />
  <input type="submit" class="cautionary" value="Test Saved POP3 Login Information..." />
</form> 



<form method="get" style="display:inline">
 <input name="flavor" type="hidden" value="manual_start" />
  <input type="submit" class="cautionary" value="Manually Check and Send Waiting Messages..." />

</form> 

 </div> 
 <div class="floatclear"></div> 



<p>
 <label for="cronjob_url">Manual Run URL:</label><br /> 
<input type="text" class="full" id="cronjob_url" value="<!-- tmpl_var Plugin_URL -->?run=1&passcode=<!-- tmpl_var Manual_Run_Passcode -->" />
</p>



<p> <label for="cronjob_command">curl command example (for a cronjob):</label><br /> 
<input type="text" class="full" id="cronjob_command" value="<!-- tmpl_var name="curl_location" default="/cannot/find/curl" -->  -s --get --data run=1\;passcode=<!-- tmpl_var Manual_Run_Passcode -->\;verbose=0  --url <!-- tmpl_var Plugin_URL -->" />
<!-- tmpl_unless curl_location --> 
	<span class="error">Can't find the location to curl!</span><br />
<!-- /tmpl_unless --> 

<!-- tmpl_unless Allow_Manual_Run --> 
    <span class="error">(Currently disabled)</a>
<!-- /tmpl_unless --> 

</p>



</fieldset> 



<fieldset> 
<legend><!-- tmpl_var Plugin_Name --> Configuration</legend>

 <div class="buttonfloat"> 
 <form action="<!-- tmpl_var Plugin_URL -->"> 
  <input type="hidden" name="flavor" value="cgi_show_plugin_config" /> 
  <input type="submit" value="View All Plugin Configurations..." class="cautionary" /> 
 </form> 
 </div> 

<div class="floatclear"></div> 


</fieldset> 


};

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

    if ( !$args->{ -List } ) {
        carp
"You need to supply a list ->new({-List => your_list}) in the constructor.";
        return undef;
    }
    else {

        $self->{list} = $args->{ -List };
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

    if ( opendir( MOD_MSGS, $self->mod_dir ) ) {

        %allfiles = map { $_, ( stat($_) )[9] } readdir(MOD_MSGS);

        closedir(MOD_MSGS)
          or carp "couldn't close: " . $self->mod_dir;

        for my $key ( sort $allfiles{$a} <=> $allfiles{$b}, keys %allfiles )
        {

            next if ( $key =~ /^\.\.?$/ );

            $key =~ s(^.*/)();
            if ( $key =~ m/$pattern/ ) {
                push ( @awaiting_msgs, $key );
            }

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

    if ( !$args->{ -msg } ) {
        croak "You must supply a message!";
    }

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }

    my $file = $self->mod_msg_filename( $args->{ -msg_id } );

    open my $MSG_FILE, '>:encoding(' . $DADA::Config::HTML_CHARSET.')' , $file
      or croak "Cannot write saved raw message at: '" . $file . " because: $!";

    print $MSG_FILE $args->{ -msg };

    close($MSG_FILE)
      or croak "Coulnd't close: " . $file . "because: " . $!;

}

sub moderation_msg {

    my $self = shift;
    my ($args) = @_;
    my $reply;

    if ( !$args->{ -msg } ) {
        croak "You must supply a message!";
    }

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }
    $args->{ -msg_id } =~ s/\@/_at_/g;
    $args->{ -msg_id } =~ s/\>|\<//g;
    $args->{ -msg_id } = DADA::App::Guts::strip( $args->{ -msg_id } );

    if ( !$args->{ -from } ) {
        croak "You must supply a from!";
    }

    if ( !$args->{ -parser } ) {
        croak "You must supply a parser!";
    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    my $li = $ls->get;

    my $parser = $args->{ -parser };
    my $entity = $parser->parse_data(DADA::App::Guts::safely_encode( $args->{ -msg } ));

    my $confirmation_link =
      $Plugin_Config->{Plugin_URL}
      . '?flavor=mod&list='
      . DADA::App::Guts::uriescape($self->{list})
      . '&process=confirm&msg_id='
      . DADA::App::Guts::uriescape($args->{ -msg_id });
    my $deny_link =
      $Plugin_Config->{Plugin_URL}
      . '?flavor=mod&list='
      . DADA::App::Guts::uriescape($self->{list})
      . '&process=deny&msg_id='
      . DADA::App::Guts::uriescape($args->{ -msg_id });

    #  create an array of recepients
    my @moderators;
    if ( $li->{moderate_discussion_lists_with} eq 'authorized_sender_email' ) {
        my $lh =
          DADA::MailingList::Subscribers->new( { -list => $self->{list} } );
        my $authorized_senders = [];
        $authorized_senders =
          $lh->subscription_list(
	 		{
				-type => 'authorized_senders'
			}
		);
        for my $moderator (@$authorized_senders) {

			if($moderator->{email} eq $args->{ -from }){ 
				# Well, we'll just pass that one right by... 
				# I don't think we want an authorized sender to 
				# be able to moderate their own message!
			}
            else { 
				push ( @moderators, $moderator->{email} );
        	}
		}
        print
"\t\Message being sent to Authorized Senders and List Owner for moderation... \n\n"
          if $verbose;
    }
    else {
        print "\t\Message being sent to List Owner for moderation... \n"
          if $verbose;
    }
    push ( @moderators, $ls->param('list_owner_email') );    # always addressed

    # loop through recepients
    for my $to_address (@moderators) {                   # recepient loop
        $reply = MIME::Entity->build(
            Type    => "multipart/mixed",
            Subject => $Moderation_Msg_Subject,
            To      => $to_address,
        );
        print "\t * Sent moderation request to $to_address\n"
          if $verbose;

        # attach parts
        $reply->attach(
            Type => 'text/plain',
            Data => $Moderation_Msg,
        );
        $reply->attach(
            Type        => 'message/rfc822',
            Disposition => "inline",
            Data        => DADA::App::Guts::safely_decode(DADA::App::Guts::safely_encode($entity->as_string)),
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
                    -list_settings_vars       => $li,
                    -list_settings_vars_param => { -dot_it => 1, },

                    #-subscriber_vars =>
                    #	{
                    #		#'subscriber.email' =>  $args->{-from},
                    #	},
                    -vars => {
                        moderation_confirmation_link => $confirmation_link,
                        moderation_deny_link         => $deny_link,
                        message_subject              => $args->{ -subject },
                        msg_id                       => $args->{ -msg_id },
                        'subscriber.email'           => $args->{ -from },
                    }
                },
            }
        );
    }
}

sub send_moderation_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }
    $args->{ -msg_id } =~ s/\@/_at_/g;
    $args->{ -msg_id } =~ s/\>|\<//g;
    $args->{ -msg_id } = DADA::App::Guts::strip( $args->{ -msg_id } );

    if ( !$args->{ -parser } ) {
        croak "You must supply a parser!";
    }

# DEV there are two instances of my $parser, and my $entity of them - which one is the correct one?

    my $parser = $args->{ -parser };

    my $entity;
    eval {
        $entity =
          $parser->parse_data(
		 DADA::App::Guts::safely_encode( 

            	$self->get_msg( { -msg_id => $args->{ -msg_id } } )) );
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
    my $li = $ls->get;

    my $reply = MIME::Entity->build(
        Type    => "text/plain",
        To      => $from,
        Subject => $AwaitModeration_Message_Subject,
        Data    => $AwaitModeration_Message,
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
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1, },
                -subscriber_vars => { 'subscriber.email' => $args->{ -from }, },
                -vars            => {

                    message_subject => $args->{ -subject },
                    message_from    => $args->{ -from },
                    msg_id          => $args->{ -msg_id },
                    Plugin_Name     => $Plugin_Config->{Plugin_Name},

                }
            },
        }
    );
}

sub send_accept_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }
    $args->{ -msg_id } =~ s/\@/_at_/g;
    $args->{ -msg_id } =~ s/\>|\<//g;
    $args->{ -msg_id } = DADA::App::Guts::strip( $args->{ -msg_id } );

    if ( !$args->{ -parser } ) {
        croak "You must supply a parser!";
    }

# DEV there are two instances of my $parser, and my $entity of them - which one is the correct one?

    my $parser = $args->{ -parser };

    my $entity;
    eval {
        $entity =
          $parser->parse_data(
			DADA::App::Guts::safely_encode(
			        	$self->get_msg( 
					{ 
						-msg_id => $args->{ -msg_id } } )) );
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
    my $li = $ls->get;

    my $reply = MIME::Entity->build(
        Type    => "text/plain",
        To      => $from,
        Subject => $Accept_Message_Subject,
        Data    => $Accept_Message,
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
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1, },
                -subscriber_vars => { 'subscriber.email' => $args->{ -from }, },
                -vars            => {
                    message_subject => $subject,
                    message_from    => $from,
                    msg_id          => $args->{ -msg_id },
                    Plugin_Name     => $Plugin_Config->{Plugin_Name},
                }
            },
        }
    );
}

sub send_reject_msg {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }
    $args->{ -msg_id } =~ s/\@/_at_/g;
    $args->{ -msg_id } =~ s/\>|\<//g;
    $args->{ -msg_id } = DADA::App::Guts::strip( $args->{ -msg_id } );

    if ( !$args->{ -parser } ) {
        croak "You must supply a parser!";
    }

# DEV there are two instances of my $parser, and my $entity of them - which one is the correct one?

    my $parser = $args->{ -parser };

    my $entity;
    eval {
        $entity =
          $parser->parse_data(
			DADA::App::Guts::safely_encode(
            $self->get_msg( { -msg_id => $args->{ -msg_id } } ) ));

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
    my $li = $ls->get;

    my $reply = MIME::Entity->build(
        Type    => "text/plain",
        To      => $from,
        Subject => $Rejection_Message_Subject,
        Data    => $Rejection_Message,
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
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1, },
                -subscriber_vars          => {
                    'subscriber.email' => $args->{ -from },

                },
                -vars => {

                    message_subject => $args->{ -subject },
                    message_from    => $args->{ -from },
                    msg_id          => $args->{ -msg_id },
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

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }

    my $file = $self->mod_msg_filename( $args->{ -msg_id } );

    if ( !-e $file ) {

        croak "Message: $file doesn't exist?!";

    }
    else {

        open my $MSG_FILE, '<', $file
          or die "Cannot read saved raw message at: '" . $file
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

    if ( !$args->{ -msg_id } ) {
        croak "You must supply a message id!";
    }

    my $file = $self->mod_msg_filename( $args->{ -msg_id } );

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
    return $self->mod_dir . '/' . DADA::App::Guts::uriescape($self->{list}) . '-' . $message_id;

}

sub mod_dir {

    my $self = shift;

    return $DADA::Config::TMP . '/moderated_msgs';

}

=pod

=head1 Dada Bridge

=head1 Description 

Dada Bridge is a plugin for Dada Mail that adds support to send email from your mail reader to a Dada Mail mailing list, both for announce-only tasks and discussion lists.

Dada Bridge allows you to do two things, fairly easily: 

=over

=item * Set up an Announce-Only list. 

Dada Bridge allows you to send an email message to the List Email address, which will then be sent to your entire mailing list. 

=item * Set up a Discussion List. 

Anyone subscribed to your mailing list will be able send an email to the List Email Address, which will then be sent to the entire mailing list. Anyone else may reply to messages sent to the same mailing list. 

=back

There's some advantages to using Dada Bridge over more sophisticated programs: 

=over

=item * You do NOT need root access to the server to install the program, or setup the List Email address

=item * You do NOT need to use an alias to a script to use Dada Bridge

=back

Having solved these two problems also makes Dada Bridge potentially more secure to use and opens its use to a wider audience. 

=head1 How does Dada Bridge work?

Many of Dada Bridge's concepts are slightly different than what you may be used to in traditional mailing lists: 


=over

=item * Subscription/Unsubscription requests are handled via Dada Mail itself

In other words, it's all web-based. There are currently no subscription mechanisms that use email commands.

=item *  A, "List Email" is just a POP3 email account. 

In Dada Mail, the B<List Email> is the address you send to when you want to post a message to the list. This differs from the, B<List Owner> email, which is the address that messages will be sent on behalf of (unless discussion lists are enabled). 

Usually in a mailing list manager, this address is created automatically by the program itself. In Dada Mail, you'll have to manually create the email  (POP3) account and plug in the email address, POP3 server and username/password into Dada Mail.

This allows anyone who can make POP3 accounts to have a discussion mailing list. You also have a whole lot of flexibility when it comes to what the B<List Email> can be. 

In normal use, Dada Bridge will check this account and deliver any messages it finds accordingly. When in normal use, do not check this account yourself. 

=back

=head1 Requirements

=over

=item * Familiarity with setting cron jobs

If you do not know how to set up a cron job, attempting to set one up for Dada Bridge will result in much aggravation. Please read up on the topic before attempting!

=item * a free POP3 account for each mailing list you want to use Dada Bridge for. 

=back 

=head1 Recommendations

=over

=item * Setup Dada Mail using the SQL Backend. 

Multipart messages, attachments and inline embedded images will work very well if you use the SQL Backend. 

=item * Disable Javascript in Archived Messages 

In Dada Mail's List control panel under, I<Message Archives - # Advanced Archive Options>, check the option, B<Disable Javascript in Archived Messages >. This will prevent exploitations embedded in messages sent to the mailing list when viewed in Dada Mail's own archives. Along with Javascript, this option will strip out: C<embed>, C<object>, C<frame>, C<iframe>, and C<meta> tags. 

This feature does require the use of a CPAN module called, B<HTML::Scrubber>, which you may have to install yourself: 

L<http://search.cpan.org/dist/HTML-Scrubber/>

If you do not have this available, I do urgently suggest you do not use archiving for B<discussion> lists. 

=back

=head1 Obtaining The Plugin

Dada Bridge is located in the, I<dada/plugins> directory of the Dada Mail distribution, under the name: I<dada_bridge.pl>

=head1 Installation 

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin B<manually>.

If you install the plugin using the Dada Mail installer, you will still have set the cronjob manually, which is covered below. 

=head1 Lightning Configuration/Installation Instructions

=over 


=item * chmod 755 the dada_bridge.pl script

The, C<dada_bridge.pl> script should be in your I<dada/plugins> directory. 

=item * Run dada_bridge.pl in your web browser.

In other words, visit it in your web browser L<http://example.com/cgi-bin/dada/plugins/dada_bridge.pl> 

=item * Set the cronjob

The command for your cronjob will be listed on the plugin's list control panel. Set it to run for every five minutes. 


=back

=head1 Configuration/Installation Screencasts

Configuring and Installing (and Using) Dada Bridge is covered in two screencasts: 

=head2 Part 1

L<http://www.youtube.com/watch?v=PWzSbpCbfGI&hd=1>

=for html <iframe title="YouTube video player" width="640" height="510" src="http://www.youtube.com/embed/PWzSbpCbfGI" frameborder="0" allowfullscreen></iframe>

=head2 Part 2

L<http://www.youtube.com/watch?v=S5GwxZnw3oU&hd=1>

=for html  <iframe title="YouTube video player" width="640" height="510" src="http://www.youtube.com/embed/S5GwxZnw3oU?hd=1" frameborder="0" allowfullscreen></iframe>


=head1 Installation

Before we get into installation, here's how Dada Bridge is used: 

One part of Dada Bridge is run as a Dada Mail plugin - you'll have to log into your list before you're able to make any changes to its settings. 

The second part of Dada Bridge is the part that actually looks for any new mail to be examined and hopefully, broadcasted and sent out to your list. This part of Dada Bridge is usually run via a B<cronjob>.  

There's a few ways that Dada Bridge can do the second part, and we'll go in detail on how to set up both ways. 

=head2 Configuring Dada Bridge's Plugin Side

=head2 #1 Change the permissions of the, dada_bridge.pl script to, "755"

Find the C<dada_bridge.pl> script in your I<dada/plugins> directory. Change its permissions to, C<755> 

=head2 #2 Configure your outside config file (.dada_config)

You'll most likely want to edit your outside config file (C<.dada_config>)
so that it shows Dada Bridge in the left-hand menu, under the, B<Plugins> heading. 

First, see if the following lines are present in your C<.dada_config> file: 

 # start cut for list control panel menu
 =cut

 =cut
 # end cut for list control panel menu

If they are, remove them. 

Then, find these lines: 


 #					{-Title      => 'Discussion Lists',
 #					 -Title_URL  => $PLUGIN_URL."/dada_bridge.pl",
 #					 -Function   => 'dada_bridge',
 #					 -Activated  => 1,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{-Title      => 'Discussion Lists',
 					 -Title_URL  => $PLUGIN_URL."/dada_bridge.pl",
 					 -Function   => 'dada_bridge',
 					 -Activated  => 1,
 					},

Save your C<.dada_config> file. 

You can now log into your List Control Panel and under the, B<plugins> heading you should now see a linked entitled, "Discussion lists". Clicking that will allow you to set up your list to receive mail from a mail reader. 

Messages will not yet be received and sent out via Dada Bridge.

For that to happen - two things will have to be configured. The first is setting up the B<List Email> - that's done in the control panel for the plugin itself and should (hopefully) be self-explanitory. 

The second is to set up the cronjob and that's what we'll talk about next: 

=head1 Configurating the Cronjob to Automatically Run Dada Bridge

We're going to assume that you already know how to set up the actual cronjob, but we'll be explaining in depth on what the cronjob you need to set is.

=head2 Setting the cronjob

Generally, setting the cronjob to have Dada Bridge run automatically just means that you have to have a cronjob access a specific URL. The URL looks something like this:

 http://example.com/cgi-bin/dada/plugins/dada_bridge.pl?run=1&verbose=1

Where, I<http://example.com/cgi-bin/dada/plugins/dada_bridge.pl> is the URL to your copy of dada_bridge.pl

You'll see the specific URL used for your installation of Dada Mail in the web-based control panel for Dada Bridge, under the fieldset legend, B<Manually Run Dada Bridge>. under the heading, B<Manual Run URL:>

This will have Dada Bridge check any awaiting messages.

You may have to look through your hosting account's own FAQ, Knowledgebase and/or other docs to see exactly how you invoke a URL via a cronjob.

A Pretty Good Guess of what the entire cronjob should be set to is located in the web-based crontrol panel for Dada Bridge, under the fieldset legend, B<Manually Run Dada Bridge>, under the heading, B<curl command example (for a cronjob)>:

From my testing, this should work for most Cpanel-based hosting accounts.

Here's the entire cronjob explained:

In this example, I'll be running the script every 5 minutes ( */5 * * * * ) - tailor to your taste.


	*/5 * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0\; --url http://example.com/cgi-bin/dada/plugins/dada_bridge.pl

=head2 Disallowing running Dada Bridge manually (via URL) 

If you DO NOT want to use this way of invoking the program to check awaiting messages and send them out, make sure to set the B<plugin config variable> (which we'll cover below) C<Allow_Manual_Run> to, C<0>. 

=head2 Security Concerns "Manual_Run_Passcode"

Running the plugin like this is somewhat risky, as you're allowing an anonymous web browser to run the script in a way that was originally designed to only be run either after successfully logging into the list control panel, or, when invoking this script via the command line.

If you'd like, you can set up a simple B<Passcode>, to have some semblence of security over who runs the program. Do this by setting the, plugin config (again, we'll cover plugin configs, below), C<Manual_Run_Passcode> to a password-like string: 

	Manual_Run_Passcode                 => 'sneaky', 


In this example, you'll then have to change the URL in these examples to:

 http://example.com/cgi-bin/dada/plugins/dada_bridge.pl?run=1&passcode=sneaky

=head3 Other options you may pass

You can control quite a few things by setting variables right in the query string:

=over

=item * passcode

As mentioned above, the C<Manual_Run_Passcode> allows you to set some sort of security while running in this mode. Passing the actual password is done in the query string:

 http://example.com/cgi-bin/dada/plugins/dada_bridge.pl?run=1&passcode=sneaky

=item * verbose

By default, you'll receive the a report of how Dada Bridge is doing downloading awaiting messages, validating them and sending them off. 

This is sometimes not so desired, especially in a cron environment, since all this informaiton will be emailed to you (or someone) everytime the script is run. You can run Dada Bridge with a cron that looks like this:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1 --url http://example.com/cgi-bin/dada/plugins/dada_bridge.pl >/dev/null 2>&1

The, >/dev/null 2>&1 line throws away any values returned.

Since all the information being returned from the program is done sort of indirectly, this also means that any problems actually running the program will also be thrown away.

If you set verbose to, C<0>, under normal operation, Dada Bridge won't show any output, but if there's a server error, you'll receive an email about it. This is probably a good thing. Example:

 * * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0 --url http://example.com/cgi-bin/dada/plugins/dada_bridge.pl

=item * test

Runs Dada Bridge in test mode by checking the messages awaiting and parsing them, but not actually carrying out any sending. 

=back 

=head3 Notes on Setting the Cronjob for curl

You may want to check your version of curl and see if there's a speific way to pass a query string. For example, this:

 */5 * * * * /usr/local/bin/curl -s http://example.com/cgi-bin/dada/plugins/dada_bridge.pl?run=1&passcode=sneaky

Doesn't work for me.

I have to use the --get and --data flags, like this:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1\;passcode=sneaky --url http://example.com/cgi-bin/dada/plugins/dada_bridge.pl

my query string is this part:

 run=1\;passcode=sneaky

And also note I had to escape the, ; character. You'll probably have to do the same for the & character.

Finally, I also had to pass the actual URL of the plugin using the --url flag.

=head1 Command Line Interface

There's a slew of optional arguments you can give to this script. To use Dada Bridge via the command line, first change into the directory that Dada Bridge resides in, and issue the command:

 ./dada_bridge.pl --help

=head2 Command Line Interface for Cronjobs: 

You can also invoke C<dada_bridge.pl> from the command line interface for cronjobs. The secret is to actually have two commands in one. The first command changes into the same directory as the C<dada_bridge.pl> script, the second invokes the script with the paramaters you'd like. 

For example: 

 */5 * * * * cd /home/myaccount/cgi-bin/dada/plugins; /usr/bin/perl ./dada_bridge.pl  >/dev/null 2>&1

Where, I</home/myaccount/cgi-bin/dada/plugins> is the full path to the directory the C<dada_bridge.pl> script is located. 

=head1 Remember to enable sending using this method! 

By default, the ability for dada_bridge.pl to send and receive messages is disabled on a per-list basis. To enable sending, log into your list control panel and go to the dada_bridge.pl admin screen. 

Uncheck: 

 Disable sending using this method 

And you're off to the races. 

=head1 Plugin Configuration Settings

The below settings are available to you, if you wish to further configure the plugin. You'll find the settings within the plugin itself - look at the top of the, C<dada_bridge.pl> script. 

B<BUT>, we suggest that you set these plugin config settings in your outside config file (C<.dada_config>). 

First, search and see if the following lines are present in your C<.dada_config> file: 

 # start cut for plugin configs
 =cut

 =cut
 # end cut for plugin configs

If they are present, remove them.

You can then configure the plugin variables on these lines: 

	Dada_Bridge => {

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

The name of the plugin. By default, B<Dada Bridge>.

=head2 Plugin_URL

Sometimes, the plugin has a hard time guessing what its own URL is. If this is happening, you can manually set the URL of the plugin in Plugin_URL.

=head2 Allow_Manual_Run

Allows you to invoke the plugin to check and send awaiting messages via a URL. 

=head2 Manual_Run_Passcode

Allows you to set a passcode if you want to allow manually running the plugin. 

=head2 MessagesAtOnce

You can specify how many messages you want to have the program actually handle per execution of the script by changing the, B<MessagesAtOnce> variable. By default, it's set conservatively to, B<1>.

=head2 Soft_Max_Size_Of_Any_Message

Like its brethren, C<Max_Size_Of_Any_Message> C<Soft_Max_Size_Of_Any_Message> sets the maximum size of a message that's accepted, but
If the message falls between, C<Soft_Max_Size_Of_Any_Message> and, C<Max_Size_Of_Any_Message> a, "Your email message is too big!" email message will
be sent to the original poster. 

Set the size in octects. 

=head2 Max_Size_Of_Any_Message

Sets a hard limit on how large a single message can actually be, before you won't allow the message to be processed. If a message is too large, it'll be simple deleted. A warning will be written in the error log, but the original sender will not be notified.

=head2 Allow_Open_Discussion_List

If set to, C<1> a new option will be available in Dada Bridge's list control panel to allow you to have a discussion list that anyone can send messages to. 

=head2 Room_For_One_More_Check

C<Room_For_One_More_Check> looks to see how many mass mailings are currently happening. If its at or above the limit set in C<$MAILOUT_AT_ONCE_LIMIT>, Dada Bridge will not attempt to look for and (possibly) create another mass mailing to join the queue. 

=head2 Enable_POP3_File_Locking

C<Enable_POP3_File_Locking>. Sometimes, the pop3 locking stuff in Dada Mail simply goes haywire and you get deadlocks. Setting this configuration to, C<0> stops that. 

=head2 Check_List_Owner_Return_Path_Header

When testing the validity of a received message, Dada Mail will look to see if the, C<Return-Path> header matches what's set in the, C<From> header. If they do not match, this test fails and the message will be rejected. Setting, C<Check_List_Owner_Return_Path_Header> will disable this test. 

=head2 Check_Multiple_Return_Path_Headers

C<Check_Multiple_Return_Path_Headers> is another validity test for received messages. This time, the message is looked to see if it has more than one C<Return-Path> header. If it does, it is rejected. If you set, C<Check_Multiple_Return_Path_Headers> to, C<0>, this test will be disabled. 

=head1 Dada Bridge-Specific Email Messages

=head2 $Moderation_Msg

The text of the email message that gets sent out to the list owner, when they receive an email message that requires moderation. 

=head2 $AwaitModeration_Msg

The text of the email message that gets sent out to the message sender, who has a email message sent to the list that requires moderation. 

=head2 $Moderation_Msg

The text of the email message that gets sent out to the message sender who has a email message sent to the list that was accepted during moderation. 

=head2 $Rejection_Message

The text of the email message that gets sent out to the message sender who has a email message sent to the list that was rejected during moderation. 

=head1 DEBUGGING 

This plugin, much more so than the main Dada Mail program is a bit finicky, since you have to rely on getting a successful connection to your POP3 server and also be able to run the program via a cronjob. 

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

(changing them to their real values) when prompted. This is basically what dada_bridge.pl does itself. 

If you don't have a command line, try adding an account in a desktop mail reader. If these credentials work there, they'll most likely work for dada_bridge.pl. 

If your account information is correct and also logs in when you test the pop3 login information through dada_bridge.pl yourself, check to see if there isn't an email filter attached the account that looks at messages before they're delivered to the POP3 Mailbox and outright deletes messages because it triggered a flag. 

This could be the cause of mysterious occurences of messages never reaching the POP3 Mailbox. 

=head1 COPYRIGHT

Copyright (c) 1999 - 2011 Justin Simoni All rights reserved. 

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

