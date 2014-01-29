#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
use Test::More;

# Think about using Test::HTML::Tidy, instead for at least some of these. 
eval "use Test::HTML::Lint qw(no_plan)";
plan skip_all => "Test::HTML::Lint required for testing Templates." if $@;

use HTML::Template::MyExpr; 
use DADA::Config; 


my @dirs = (

	'templates', 
	'templates/plugins/bounce_handler',
	'templates/plugins/bridge',
	'templates/plugins/change_list_shortname',
	'templates/plugins/default_mass_mailing_messages',
	'templates/plugins/global_config',
	'templates/plugins/log_viewer',
	'templates/plugins/mailing_monitor',
	'templates/plugins/password_protect_directories',
	'templates/plugins/screen_cache',
	'templates/plugins/shared',
	'templates/plugins/tracker',
	
	'installer-disabled/templates',
); 

#Work on this one later...
# archive_screen.tmpl


my @files = (); 

foreach my $dir(@dirs) { 

	my $file;
	opendir(TMPL, $dir) or die "can't open '$dir' to read: $!";

	while(defined($file = readdir TMPL)) {
	    #don't read '.' or '..'
	    next if $file =~ /^\.\.?$/; 

	    if($file =~ m{(\.tmpl|\.widget)}){ 
			# Wait. Why am I skipping these?
#			next if $file =~ m{example_dada_config.tmpl};
#	        next if $file =~ m{rss-2_0.tmpl}; 
#	        next if $file =~ m{atom-1_0.tmpl}; 
	        push(@files, $dir . '/' . $file);
	    }
	 }
}

=cut
for my $test_file (@files) {
    html_ok( strip_comments( open_file( $dir . '/' . $test_file ) ),
        $test_file . ' through Lint test' );
}
=cut




for my $test_file (@files) {

    eval {
        my $template = HTML::Template::MyExpr->new(
            path              => 'templates',
            die_on_bad_params => 0,
            loop_context_vars => 1,
            filename          => $test_file,
            filter            => [
                {
                    sub    => \&shh_tmpl_set,
                    format => 'scalar'
                }
            ],
        );
        $template->output();

    };
    ok( !$@, "$test_file through HTML::Template::MyExpr" );
    if ($@) {
        diag($@);
    }

    undef $template;
}


=cut

SKIP: {

	eval { require HTML::Template::Pro };
	skip "HTML::Template::Pro is not installed", 2 if $@;

	for my $test_file (@files) {
	    eval {
	        my $template = HTML::Template::Pro->new(
	            path              => $dir,
	            die_on_bad_params => 0,
	            loop_context_vars => 1,
	            filename          => $test_file,
	            filter            => [
	                {
	                    sub    => \&shh_tmpl_set,
	                    format => 'scalar'
	                }
	            ],
	        );
	        my $foo = $template->output();
	    };
	    ok( !$@, "$test_file through HTML::Template::Pro" );
	    if ($@) {
	        diag($@);
	    }
	    undef $template;
	}
}

=cut



my $template_strings = {
    SUBSCRIBED_MESSAGE => $DADA::Config::SUBSCRIBED_MESSAGE,
    SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE =>
      $DADA::Config::SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE,
#    SUBSCRIPTION_NOTICE_MESSAGE => $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE,
#    SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE =>
#      $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE,
#    SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT =>
 #     $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT,
#    SUBSCRIPTION_NOTICE_MESSAGE => $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE,
#    UNSUBSCRIBED_MESSAGE        => $DADA::Config::UNSUBSCRIBED_MESSAGE,
#    CONFIRMATION_MESSAGE        => $DADA::Config::CONFIRMATION_MESSAGE,
#    UNSUBSCRIPTION_REQUEST_MESSAGE  => $DADA::Config::UNSUBSCRIPTION_REQUEST_MESSAGE,
    SUBSCRIPTION_REQUEST_APPROVED_MESSAGE =>
      $DADA::Config::SUBSCRIPTION_REQUEST_APPROVED_MESSAGE,
    SUBSCRIPTION_REQUEST_DENIED_MESSAGE =>
      $DADA::Config::SUBSCRIPTION_REQUEST_DENIED_MESSAGE,
#    MAILING_LIST_MESSAGE        => $DADA::Config::MAILING_LIST_MESSAGE,
#    MAILING_LIST_MESSAGE_HTML   => $DADA::Config::MAILING_LIST_MESSAGE_HTML,
    NOT_ALLOWED_TO_POST_MESSAGE => $DADA::Config::NOT_ALLOWED_TO_POST_MESSAGE,
    NOT_ALLOWED_TO_POST_MSG =>
      $DADA::Config::NOT_ALLOWED_TO_POST_MSG,
    YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE =>
      $DADA::Config::YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE,
#    MAILING_FINISHED_MESSAGE_SUBJECT =>
#      $DADA::Config::MAILING_FINISHED_MESSAGE_SUBJECT,
#    MAILING_FINISHED_MESSAGE => $DADA::Config::MAILING_FINISHED_MESSAGE,
#    TEXT_INVITE_MESSAGE      => $DADA::Config::TEXT_INVITE_MESSAGE,
#    PROFILE_ACTIVATION_MESSAGE_SUBJECT =>
#      $DADA::Config::PROFILE_OPTIONS_ACTIVATION_MESSAGE_SUBJECT,
#    PROFILE_ACTIVATION_MESSAGE =>
#      $DADA::Config::PROFILE_OPTIONS_ACTIVATION_MESSAGE,
#    PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT =>
#      $DADA::Config::PROFILE_OPTIONS_RESET_PASSWORD_MESSAGE_SUBJECT,
#    PROFILE_RESET_PASSWORD_MESSAGE =>
#      $DADA::Config::PROFILE_OPTIONS_RESET_PASSWORD_MESSAGE,
#    PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT =>
#      $DADA::Config::PROFILE_OPTIONS_UPDATE_EMAIL_MESSAGE_SUBJECT,
#    PROFILE_UPDATE_EMAIL_MESSAGE =>
#      $DADA::Config::PROFILE_OPTIONS_UPDATE_EMAIL_MESSAGE,
#    LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT =>
#      $DADA::Config::LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT,
#    LIST_CONFIRM_PASSWORD_MESSAGE =>
#      $DADA::Config::LIST_CONFIRM_PASSWORD_MESSAGE,
#    LIST_RESET_PASSWORD_MESSAGE_SUBJECT =>
#      $DADA::Config::LIST_RESET_PASSWORD_MESSAGE_SUBJECT,
#    LIST_RESET_PASSWORD_MESSAGE => $DADA::Config::LIST_RESET_PASSWORD_MESSAGE,
#   HTML_INVITE_MESSAGE         => $DADA::Config::HTML_INVITE_MESSAGE,
    SEND_ARCHIVED_MESSAGE       => $DADA::Config::SEND_ARCHIVED_MESSAGE,
    HTML_SEND_ARCHIVED_MESSAGE  => $DADA::Config::HTML_SEND_ARCHIVED_MESSAGE,
    HTML_CONFIRMATION_MESSAGE   => $DADA::Config::HTML_CONFIRMATION_MESSAGE,
    HTML_SUBSCRIBED_MESSAGE => $DADA::Config::HTML_SUBSCRIBED_MESSAGE,
    HTML_SUBSCRIPTION_REQUEST_MESSAGE =>
      $DADA::Config::HTML_SUBSCRIPTION_REQUEST_MESSAGE,
    HTML_UNSUBSCRIBED_MESSAGE     => $DADA::Config::HTML_UNSUBSCRIBED_MESSAGE,
#    SENDING_PREFS_MESSAGE_SUBJECT => $DADA::Config::SENDING_PREFS_MESSAGE_SUBJECT,
#    SENDING_PREFS_MESSAGE         => $DADA::Config::SENDING_PREFS_MESSAGE,

	NOT_ALLOWED_TO_POST_MSG => $DADA::Config::NOT_ALLOWED_TO_POST_MSG, 
	MODERATION_MSG          => $DADA::Config::MODERATION_MSG, 
	AWAIT_MODERATION_MSG    => $DADA::Config::AWAIT_MODERATION_MSG, 
	ACCEPT_MSG              => $DADA::Config::ACCEPT_MSG, 
	REJECTION_MSG           => $DADA::Config::REJECTION_MSG, 
	MSG_TOO_BIG_MSG         => $DADA::Config::MSG_TOO_BIG_MSG, 
	MSG_LABELED_AS_SPAM_MSG => $DADA::Config::MSG_LABELED_AS_SPAM_MSG, 

	
};

my @list_settings = qw(
confirmation_message_subject
subscription_request_approved_message_subject
subscription_request_denied_message_subject
subscription_approval_request_message_subject
subscribed_message_subject
subscribed_by_list_owner_message
unsubscribed_by_list_owner_message_subject
unsubscribed_message_subject
mailing_list_message_from_phrase
mailing_list_message_to_phrase
mailing_list_message_subject
send_archive_message_subject
you_are_already_subscribed_message_subject
you_are_not_subscribed_message_subject
invite_message_from_phrase
invite_message_to_phrase
invite_message_subject
not_allowed_to_post_msg_subject
invalid_msgs_to_owner_msg_subject
moderation_msg_subject
await_moderation_msg_subject
accept_msg_subject
rejection_msg_subject
msg_too_big_msg_subject
msg_labeled_as_spam_msg_subject


); 

for(@list_settings){ 
	$template_strings->{$_} = $DADA::Config::LIST_SETUP_DEFAULTS{$_}; 	
}
for(keys %$template_strings){ 
		eval { 
		my $str = $template_strings->{$_};
	
	    my $template = HTML::Template::MyExpr->new(
	    		                                 die_on_bad_params => 0,	
			                                     loop_context_vars => 1,
			                                     scalarref          => \$str, 
												filter   => [{sub    => \&shh_tmpl_set,
												format => 'scalar'}],
			                                    );		                              
	    $template->output();  

	};
	ok(! $@, "$_ through HTML::Template::MyExpr"); 
	    if($@){ 
	        diag($@); 
	    }

		undef $template; 
	
}
dada_test_config::wipe_out;


sub open_file { 

    my $fn = shift; 
    die "no fn!  " if ! $fn; 
    
    open my $file, '<', $fn or die; 
    my $info = do { local $/; <$file> };
    close $file or die; 
    
    return $info; 
    

}


sub strip_comments { 

    # *very* old code: 
    
    my $html = shift; 
    

$html =~ s{ <!                   # comments begin with a `<!'
                            # followed by 0 or more comments;

        (.*?)           # this is actually to eat up comments in non 
                            # random places

         (                  # not suppose to have any white space here

                            # just a quick start; 
          --                # each comment starts with a `--'
            .*?             # and includes all text up to and including
          --                # the *next* occurrence of `--'
            \s*             # and may have trailing while space
                            #   (albeit not leading white space XXX)
         )+                 # repetire ad libitum  XXX should be * not +
        (.*?)           # trailing non comment text
       >                    # up to a `>'
    }{
        if ($1 || $3) { # this silliness for embedded comments in tags
            "<!$1 $3>";
        } 
    }gesx;                 # mutate into nada, nothing, and niente
    
return $html; 

}

sub shh_tmpl_set { 
	my $text_ref = shift;

    my $match = qr/\<\!\-\- tmpl_set name\=\"(.*?)\" value\=\"(.*?)\" \-\-\>/;
    $$text_ref =~ s/$match//gi;
	
}
