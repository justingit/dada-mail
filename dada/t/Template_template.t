#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
use Test::More;

eval "use Test::HTML::Lint qw(no_plan)";
plan skip_all => "Test::HTML::Lint required for testing Templates." if $@;

use HTML::Template::Expr; 
use DADA::Config; 



my $dir = 'DADA/Template/templates'; 

#Work on this one later...
# archive_screen.tmpl


my @files = (); 

my $file;
	
	
opendir(TMPL, $dir) or die "can't open '$dir' to read: $!";

while(defined($file = readdir TMPL)) {
    #don't read '.' or '..'
    next if $file =~ /^\.\.?$/; 

    if($file =~ m{(\.tmpl|\.widget)}){ 
    
		# Wait. Why am I skipping these?
        next if $file =~ m{rss-2_0.tmpl}; 
        next if $file =~ m{atom-1_0.tmpl}; 
        next if $file =~ m{admin_js.tmpl}; 
        next if $file =~ m{unsubscription_check_xml.tmpl}; 
        next if $file =~ m{subscription_check_xml.tmpl}; 

        push(@files, $file);
    }


     
 }






for my $test_file(@files){ 

	html_ok( strip_comments(open_file($dir . '/' . $test_file)), $test_file . 'through Lint test');
       
	eval { 
    my $template = HTML::Template::Expr->new(path => $dir,
    		                                 die_on_bad_params => 0,	
		                                     loop_context_vars => 1,
		                                     filename          => $test_file, 
		                                    );		                              
    $template->output();  

};
ok(! $@, "$test_file through HTML::Template::Exp"); 
    if($@){ 
        diag($@); 
    }
    
	undef $template; 
		
}

my $template_strings = {
    SUBSCRIBED_MESSAGE => $DADA::Config::SUBSCRIBED_MESSAGE,
    SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE =>
      $DADA::Config::SUBSCRIPTION_APPROVAL_REQUEST_MESSAGE,
    SUBSCRIPTION_NOTICE_MESSAGE => $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE,
    SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE =>
      $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE,
    SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT =>
      $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT,
    SUBSCRIPTION_NOTICE_MESSAGE => $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE,
    UNSUBSCRIBED_MESSAGE        => $DADA::Config::UNSUBSCRIBED_MESSAGE,
    CONFIRMATION_MESSAGE        => $DADA::Config::CONFIRMATION_MESSAGE,
    UNSUB_CONFIRMATION_MESSAGE  => $DADA::Config::UNSUB_CONFIRMATION_MESSAGE,
    SUBSCRIPTION_REQUEST_APPROVED_MESSAGE =>
      $DADA::Config::SUBSCRIPTION_REQUEST_APPROVED_MESSAGE,
    SUBSCRIPTION_REQUEST_DENIED_MESSAGE =>
      $DADA::Config::SUBSCRIPTION_REQUEST_DENIED_MESSAGE,
    MAILlING_LIST_MESSAGE       => $DADA::Config::MAILlING_LIST_MESSAGE,
    MAILlING_LIST_MESSAGE_HTML  => $DADA::Config::MAILlING_LIST_MESSAGE_HTML,
    NOT_ALLOWED_TO_POST_MESSAGE => $DADA::Config::NOT_ALLOWED_TO_POST_MESSAGE,
    NOT_ALLOWED_TO_POST_NOTICE_MESSAGE_SUBJECT =>
      $DADA::Config::NOT_ALLOWED_TO_POST_NOTICE_MESSAGE_SUBJECT,
    NOT_ALLOWED_TO_POST_NOTICE_MESSAGE =>
      $DADA::Config::NOT_ALLOWED_TO_POST_NOTICE_MESSAGE,
    YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE =>
      $DADA::Config::YOU_ARE_ALREADY_SUBSCRIBED_MESSAGE,
    MAILING_FINISHED_MESSAGE_SUBJECT =>
      $DADA::Config::MAILING_FINISHED_MESSAGE_SUBJECT,
    MAILING_FINISHED_MESSAGE => $DADA::Config::MAILING_FINISHED_MESSAGE,
    TEXT_INVITE_MESSAGE      => $DADA::Config::TEXT_INVITE_MESSAGE,
    PROFILE_ACTIVATION_MESSAGE_SUBJECT =>
      $DADA::Config::PROFILE_OPTIONS_ACTIVATION_MESSAGE_SUBJECT,
    PROFILE_ACTIVATION_MESSAGE => $DADA::Config::PROFILE_OPTIONS_ACTIVATION_MESSAGE,
    PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT =>
      $DADA::Config::PROFILE_OPTIONS_RESET_PASSWORD_MESSAGE_SUBJECT,
    PROFILE_RESET_PASSWORD_MESSAGE =>
      $DADA::Config::PROFILE_OPTIONS_RESET_PASSWORD_MESSAGE,
    PROFILE_UPDATE_EMAIL_MESSAGE_SUBJECT =>
      $DADA::Config::PROFILE_OPTIONS_UPDATE_EMAIL_MESSAGE_SUBJECT,
    PROFILE_UPDATE_EMAIL_MESSAGE => $DADA::Config::PROFILE_OPTIONS_UPDATE_EMAIL_MESSAGE,
    LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT =>
      $DADA::Config::LIST_CONFIRM_PASSWORD_MESSAGE_SUBJECT,
    LIST_CONFIRM_PASSWORD_MESSAGE =>
      $DADA::Config::LIST_CONFIRM_PASSWORD_MESSAGE,
    LIST_RESET_PASSWORD_MESSAGE_SUBJECT =>
      $DADA::Config::LIST_RESET_PASSWORD_MESSAGE_SUBJECT,
    LIST_RESET_PASSWORD_MESSAGE => $DADA::Config::LIST_RESET_PASSWORD_MESSAGE,
    HTML_INVITE_MESSAGE         => $DADA::Config::HTML_INVITE_MESSAGE,
    SEND_ARCHIVED_MESSAGE       => $DADA::Config::SEND_ARCHIVED_MESSAGE,
    HTML_SEND_ARCHIVED_MESSAGE  => $DADA::Config::HTML_SEND_ARCHIVED_MESSAGE,
    HTML_CONFIRMATION_MESSAGE   => $DADA::Config::HTML_CONFIRMATION_MESSAGE,
    HTML_UNSUB_CONFIRMATION_MESSAGE =>
      $DADA::Config::HTML_UNSUB_CONFIRMATION_MESSAGE,
    HTML_SUBSCRIBED_MESSAGE => $DADA::Config::HTML_SUBSCRIBED_MESSAGE,
    HTML_SUBSCRIPTION_REQUEST_MESSAGE =>
      $DADA::Config::HTML_SUBSCRIPTION_REQUEST_MESSAGE,
    HTML_UNSUBSCRIBED_MESSAGE => $DADA::Config::HTML_UNSUBSCRIBED_MESSAGE,
};

for(keys %$template_strings){ 
		eval { 
		my $str = $template_strings->{$_};
	
	    my $template = HTML::Template::Expr->new(
	    		                                 die_on_bad_params => 0,	
			                                     loop_context_vars => 1,
			                                     scalarref          => \$str, 
			                                    );		                              
	    $template->output();  

	};
	ok(! $@, "$_ through HTML::Template::Exp"); 
	    if($@){ 
	        diag($@); 
	    }

		undef $template; 
	
}

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

