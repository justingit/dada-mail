package DADA::App::Subscriptions;

use lib qw(
  ../../.
  ../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

use Carp qw(carp croak);
$CARP::Verbose = 1; 
use Try::Tiny;

use vars qw($AUTOLOAD);
use strict;
my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions};

my %allowed = ( test => 0, );

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my %args = (@_);

    $self->_init( \%args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init { }

sub token {

    warn 'token'
      if $t;

    my $self = shift;
    my ($args) = @_;
    my $q;

    if ( !exists( $args->{-cgi_obj} ) ) {
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.';
    }
    else {
        $q = $args->{-cgi_obj};
    }

    my $token = xss_filter( $q->param('token') );

    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
    if ( $ct->exists($token) ) {
        warn 'token exists'
          if $t;

        my $data = $ct->fetch($token);

#		use Data::Dumper; 
#		die Dumper($data); 
		
        if ( !exists( $data->{data}->{invite} ) ) {
            $data->{data}->{invite} = 0;
        }
        if ( exists( $data->{data}->{remote_addr} ) ) {
            if (   $data->{data}->{remote_addr} ne $ENV{REMOTE_ADDR}
                && $data->{data}->{invite} != 1 )
            {
                require Data::Dumper;
                carp 'Token\'s env REMOTE_ADDR ('
                  . $data->{data}->{remote_addr}
                  . ') is different than current referer ('
                  . $ENV{REMOTE_ADDR} . ')';
                carp "Additional Information: " . Data::Dumper::Dumper($data);
                if ( $q->param('simple_test') ne 'pass' ) {
                    return user_error(
                        {
                            -error => 'mismatch_ip_on_confirm',
                            -test  => $self->test,
                            -vars  => {
                                t      => $token,
                                flavor => $data->{data}->{flavor},
                            }
                        }
                    );
                }
                else {
                    carp
"User has manually 'proved' that they're real - moving along,";
                }
            }
        }
        if ( $data->{data}->{flavor} eq 'sub_confirm' ) {

            warn 'sub_confirm'
              if $t;

            $q->param( 'email', $data->{email} );
            $q->param( 'list',  $data->{data}->{list} );
            $q->param( 'token', $token );

            warn 'confirming'
              if $t;

            $self->confirm(
                {
                    -html_output => $args->{-html_output},
                    -cgi_obj     => $q,
                },
            );
        }
        elsif ( $data->{data}->{flavor} eq 'unsub_confirm' ) {
            $q->param( 'token', $token );
            $self->unsubscribe(
                {
                    -html_output => $args->{-html_output},
                    -cgi_obj     => $q,
                },
            );
        }
		elsif( $data->{data}->{flavor} eq 'sub_request_approve'
		||     $data->{data}->{flavor} eq 'sub_request_deny'
		){ 
			$q->param('token', $token); 
			$self->subscription_requests(
				{ 
                    -html_output => $args->{-html_output},
                    -cgi_obj     => $q,
				}
			); 
		}
        else {
            return user_error(
                {
                    -error => 'token_problem',
                    -test  => $self->test,
                }
            );
        }
    }
    else {
        return user_error(
            {
                -error => 'token_problem',
                -test  => $self->test,
            }
        );
    }

}

sub subscribe {

    my $self = shift;
    my ($args) = @_;

    require DADA::Template::HTML;

    # Test sub-subscribe-no-cgi
    if ( !$args->{-cgi_obj} ) {
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.';
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;
    }
    if ( !exists( $args->{-return_json} ) ) {
        $args->{-return_json} = 0;
    }
    if ( $args->{-return_json} == 1 ) {
        $args->{-html_output} = 0;
    }

    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }

    my $fh = $args->{-fh};

    my $q    = $args->{-cgi_obj};

	if($t == 1) { 
		warn 'sent over Vars:'; 
		require Data::Dumper; 
		warn Data::Dumper::Dumper({$q->Vars}); 
	}
	
    my $list = xss_filter( $q->param('list') );
    warn '$list: ' . $list
      if $t;

    my $email = lc_email( strip( xss_filter( $q->param('email') ) ) );
    warn '$email: ' . $email
      if $t;

    my $list_exists = DADA::App::Guts::check_if_list_exists( -List => $list );
    my $ls = undef;

    require DADA::MailingList::Settings;

    if ($list_exists) {
        warn 'list exists.'
          if $t;
        $ls = DADA::MailingList::Settings->new( { -list => $list } );
    }
    else {
        warn 'list does NOT exist.'
          if $t;

    }
 
   # This is a special case, since without a valid list, we can't run any of the
   # other validation stuff!
   # ! $list_exists
    if ( $list_exists == 0 ) {
        my $r = {
            status   => 0,
            list     => $list,
            email    => $email,
            errors   => { invalid_list => 1 },
            redirect => {
                url   => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1',
                query => 'list=&email='
                  . uriescape($email)
                  . 'errors[]=invalid_list'
            }
        };
        if ( $args->{-html_output} == 0 ) {
            if ( $args->{-return_json} == 1 ) {
				return $self->fancy_data({-data => $r, -type => 'json'}); 
            }
            else {
				return $self->fancy_data({-data => $r}); 			
            }
        }
        else {
            # Test sub-subscribe-redirect-error_invalid_list
            my $rd = $self->alt_redirect($r);
            $self->test ? return $rd : print $fh safely_encode($rd) and return;

            # There's also:
            #return user_error(
            #    -List  => $list,
            #    -Error => "no_list",
            #    -Email => $email,
            #    -fh    => $args->{-fh},
            #    -test  => $self->test,
            #);

        }
    }

    #/ !$list_exists
 

    # Do a little Subscriber Profile Fields Work...
    require DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my $fields = {};
    for ( @{ $lh->subscriber_fields } ) {
        if ( defined( $q->param($_) ) ) {
            $fields->{$_} = xss_filter( $q->param($_) );
        }
    }

    #/ Do a little Subscriber Profile Fields Work...

    # I really wish this was done, after we look and see if the confirmation
    # step is even needed, just so we don't have to do this, twice. It would
    # clarify a bunch of things, I think.
    my ( $status, $errors ) = $lh->subscription_check(
        {
            -email => $email,
            -type  => 'list',

            ( $ls->param('allow_blacklisted_to_subscribe') == 1 )
            ? ( -skip => ['black_listed'], )
            : (),
        }
    );

    # This is kind of strange...
    my $skip_sub_confirm_if_logged_in = 0;

 

    if ( $status == 1 ) {

 

  # What would be more useful, is if more information on *how* you
  # could finish this was given - like a way to point to a URL for this request,
  # and a way to redirect to another screen, after the request.
  #
#		warn q{$ls->param('enable_closed_loop_opt_in')} . $ls->param('enable_closed_loop_opt_in');
#		warn q{$ls->param('captcha_sub')} . $ls->param('captcha_sub'); 
#		warn q{$ls->param('enable_subscription_approval_step')} . $ls->param('enable_subscription_approval_step'); 
#		warn q{$args->{-html_output} } . $args->{-html_output}; 
		
		
        if (   $ls->param('enable_closed_loop_opt_in') == 0
            && $ls->param('captcha_sub') == 1
			&& $ls->param('enable_subscription_approval_step') == 0
			&& $args->{-html_output} == 0 
			)
        {
            my $r = {
				flavor  => 'subscription_requires_captcha', 
                status  => 1,
                list    => $list,
                email   => $email,
				redirect => {
	                url   => $DADA::Config::PROGRAM_URL . '?f=subscribe&email=' . uriescape($email) . '&list=' . uriescape($list),
	            }
            };

			# So this is a little munge, as we basically have to re-submit the subscription request, 
			# BUT, we don't want to make it out like we're... resubmitting the subscription request: 
			my $rm_status = $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'sub_confirm_list'
                }
            );
            # OK - 

            if ( $args->{-return_json} == 1 ) {
				return $self->fancy_data({-data => $r, -type => 'json'}); 
            }
            else {
				return $self->fancy_data({-data => $r}); 			
            }
        }

        my $skip_sub_confirm_if_logged_in = 0;

		# Not EVEN going to attempt: 
		if($args->{-html_output} == 1) {  
	        if ( $ls->param('skip_sub_confirm_if_logged_in') ) {
	            require DADA::Profile::Session;
	            my $sess = DADA::Profile::Session->new;
	            if ( $sess->is_logged_in ) {
	                my $sess_email = $sess->get;
	                if ( $sess_email eq $email ) {

	                    # something...
	                    $skip_sub_confirm_if_logged_in = 1;
	                }
	            }
	        }
	        if (   $ls->param('enable_closed_loop_opt_in') == 0
	            || $skip_sub_confirm_if_logged_in == 1 )
	        {

	            # I still have to make a confirmation token, the CAPTCHA step before
	            # confirmation step #1 still requires it.
	            require DADA::App::Subscriptions::ConfirmationTokens;
	            my $ct    = DADA::App::Subscriptions::ConfirmationTokens->new();
	            my $token = $ct->save(
	                {
	                    -email => $email,
	                    -data  => {
	                        list        => $list,
	                        type        => 'list',
	                        flavor      => 'sub_confirm',
	                        remote_addr => $ENV{REMOTE_ADDR},
	                    },
	                    -remove_previous => 1,
	                }
	            );

	            # And then, we have to stick the token in the query,
	            $args->{-cgi_obj}->param( 'token', $token );

	            my $add_to_sub_confirm_list = $lh->add_subscriber(
	                {
	                    -email      => $email,
	                    -type       => 'sub_confirm_list',
	                    -fields     => $fields,
	                    -confirmed  => 0,
	                    -dupe_check => {
	                        -enable  => 1,
	                        -on_dupe => 'ignore_add',
	                    },
	                }
	            );
	            if ( !defined($add_to_sub_confirm_list) ) {
	                warn
	"address, $email, wasn't added to the sub_confirm_list correctly - is it already on there?";
	            }

	            return $self->confirm(
	                {
	                    -return_json => $args->{-return_json},
	                    -html_output => $args->{-html_output},
	                    -cgi_obj     => $args->{-cgi_obj},
	                },
	            );
	        }
	    }
	}
 

    my $mail_your_subscribed_msg = 0;

    if ( $ls->param('email_your_subscribed_msg') == 1 ) {
        if ( $errors->{subscribed} == 1 ) {

            # This is a strange one, as this *could* potentially be set,
            # and if so, muck about with us.
            if ( exists( $errors->{already_sent_sub_confirmation} ) ) {
                delete( $errors->{already_sent_sub_confirmation} );
            }

            #/

            my @num = keys %$errors;
            if ( $#num == 0 ) {    # meaning, "subscribed" is the only error...
                # Don't Treat as an Error
                $status = 1;
                # But send a private error message out...
                $mail_your_subscribed_msg = 1;
            }
        }
    }

 

    if ( $status == 0 ) {
        my $r = {
            status   => 0,
            list     => $list,
            email    => $email,
            errors   => $errors,
            redirect => {
                using => $ls->param('use_alt_url_sub_confirm_failed'),
                using_with_query =>
                  $ls->param('alt_url_sub_confirm_failed_w_qs'),
                url   => $ls->param('alt_url_sub_confirm_failed'),
                query => '',
            }
        };
        my $qs = 'list='
          . uriescape($list)
          . '&email='
          . uriescape($email)
          . '&status=0'
          . '&rm=sub_confirm';
        $qs .= '&errors[]=' . $_ for keys %$errors;
        $qs .= '&' . $_ . '=' . uriescape( $fields->{$_} ) for keys %$fields;

        $r->{redirect}->{query} = $qs;

        if ( $args->{-html_output} == 0 ) {
            if ( $args->{-return_json} == 1 ) {
				return $self->fancy_data({-data => $r, -type => 'json'}); 
            }
            else {
				return $self->fancy_data({-data => $r}); 			
            }
        }
        elsif ( $args->{-html_output} == 1 ) {
            if ( $ls->param('use_alt_url_sub_confirm_failed') == 1 ) {
                my $rd = $self->alt_redirect($r);
                $self->test ? return $rd : print $fh safely_encode($rd)
                  and return;
            }
            else {
                # how does invalid email get here,
                # if we're looking at that, above?
                my @list_of_errors = qw(
                  invalid_email
                  invalid_list
                  mx_lookup_failed
                  subscribed
                  closed_list
                  invite_only_list
                  over_subscription_quota
                  black_listed
                  not_white_listed
                  settings_possibly_corrupted
                  already_sent_sub_confirmation
                );

                for (@list_of_errors) {
                    if ( $errors->{$_} == 1 ) {
                        return user_error(
                            {
                                -list  => $list,
                                -error => $_,
                                -email => $email,
                                -fh    => $args->{-fh},
                                -test  => $self->test,
                            }
                        );
                    }
                }

                # Fallback
                return user_error(
                    {
                        -list  => $list,
                        -email => $email,
                        -fh    => $args->{-fh},
                        -test  => $self->test,
                    }
                );
            }
        }
    }
    elsif ( $status == 1 ) {

 

# The idea is, we'll save the information for the subscriber in the confirm list, and then
# move the info to the actual subscription list,
# And then remove the information from the confirm list, when we're all done.
        $lh->remove_subscriber(
            {
                -email => $email,
                -type  => 'sub_confirm_list',
            }
        );
        $lh->add_subscriber(
            {
                -email      => $email,
                -type       => 'sub_confirm_list',
                -fields     => $fields,
                -confirmed  => 0,
                -dupe_check => {
                    -enable  => 1,
                    -on_dupe => 'ignore_add',
                },

            }
        );
        if ( $mail_your_subscribed_msg == 0 ) {
            require DADA::App::Subscriptions::ConfirmationTokens;
            my $ct    = DADA::App::Subscriptions::ConfirmationTokens->new();
            my $token = $ct->save(
                {
                    -email => $email,
                    -data  => {
                        list        => $list,
                        type        => 'list',
                        flavor      => 'sub_confirm',
                        remote_addr => $ENV{REMOTE_ADDR},
                    },
                    -remove_previous => 1,
                }
            );

            require DADA::App::Messages;
            DADA::App::Messages::send_confirmation_message(
                {
                    -list   => $list,
                    -email  => $email,
                    -ls_obj => $ls,
                    -test   => $self->test,
                    -token  => $token,
                }
            );

        }
        else {
            warn
'>>>> >>> >>> Sending: "Mailing List Confirmation - Already Subscribed" message'
              if $t;

            require DADA::App::Messages;
            DADA::App::Messages::send_you_are_already_subscribed_message(
                {
                    -list  => $list,
                    -email => $email,
                    -test  => $self->test,
                }
            );
        }
        my $r = {
            flavor   => 'subscription_confirmation',
            status   => 1,
            list     => $list,
            email    => $email,
            redirect => {
                using => $ls->param('use_alt_url_sub_confirm_success'),
                using_with_query =>
                  $ls->param('alt_url_sub_confirm_success_w_qs'),
                url   => $ls->param('alt_url_sub_confirm_success'),
                query => '',
            }
        };
        my $qs = 'list='
          . uriescape($list)
          . '&email='
          . uriescape($email)
          . '&status=1'
          . '&rm=sub_confirm';
        $qs .= '&' . $_ . '=' . uriescape( $fields->{$_} ) for keys %$fields;
        $r->{redirect}->{query} = $qs;

        if ( $args->{-html_output} == 0 ) {
            if ( $args->{-return_json} == 1 ) {
				return $self->fancy_data({-data => $r, -type => 'json'}); 
            }
            else {
				return $self->fancy_data({-data => $r}); 			
            }
        }
        else {
            if ( $ls->param('use_alt_url_sub_confirm_success') == 1 ) {
                my $rd = $self->alt_redirect($r);
                $self->test ? return $rd : print $fh safely_encode($rd)
                  and return;
            }
            else {
				
                my $s = $self->_subscription_confirmation_success_msg(
                    {
                        -list   => $list,
                        -email  => $email,
                        -chrome => 1,
                    }
                );

                $self->test ? return $s : print $fh safely_encode($s)
                  and return;
            }
        }
    }
    else {
        die "Unknown Status: '$status'";
    }
}

sub confirm {

    my $self = shift;
    my ($args) = @_;

    warn 'Starting Subscription Confirmation.'
      if $t;

    require DADA::Template::HTML;

    # Test: sub-confirm-no-cgi
    if ( !exists( $args->{-cgi_obj} ) ) {
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.';
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;

    }
    if ( !exists( $args->{-return_json} ) ) {
        $args->{-return_json} = 0;
    }
    if ( $args->{-return_json} == 1 ) {
        $args->{-html_output} = 0;
    }

    warn '-html_output set to ' . $args->{-html_output}
      if $t;

    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};

    my $q     = $args->{-cgi_obj};
    my $list  = xss_filter( $q->param('list') );
    my $email = lc_email( strip( xss_filter( $q->param('email') ) ) );

    warn '$list: ' . $list
      if $t;
    warn '$email: ' . $email
      if $t;
    my $list_exists = DADA::App::Guts::check_if_list_exists( -List => $list );

    require DADA::MailingList::Settings;
    my $ls = undef;

    if ( $list_exists == 1 ) {
        $ls = DADA::MailingList::Settings->new( { -list => $list } );
    }

# I'm not json-ifying this, as json isn't covered for confirmation, unless double-opt-in is used
# and this test is already done for !list and !email.
#
    if ( $args->{-html_output} == 1 ) {

        if ( $list_exists == 0 ) {

            warn '>>>> >>>> list doesn\'t exist. Redirecting to default screen.'
              if $t;
            my $r = $q->redirect(
                -uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1' );
            $self->test ? return $r : print $fh safely_encode($r) and return;
        }
        else {
            # Again!

            if ( !$email ) {
                if ( $ls->param('use_alt_url_sub_failed') == 1 ) {
                    warn '>>>> >>>> no email passed. Redirecting to list screen'
                      if $t;
                    my $r =
                      $q->redirect( -uri => $DADA::Config::PROGRAM_URL
                          . '?f=list&list='
                          . $list
                          . '&error_no_email=1' );
                    $self->test ? return $r : print $fh safely_encode($r)
                      and return;
                }
            }
        }
    }

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    warn 'captcha_sub set to: ' . $ls->param('captcha_sub')
      if $t;
    if ( $ls->param('captcha_sub') == 1 ) {
        my $can_use_captcha = 1;
        try {
            require DADA::Security::AuthenCAPTCHA;
        }
        catch {
            carp "CAPTCHA Not working correctly?: $_";
            $can_use_captcha = 0;
        };
        if ( $can_use_captcha == 1 ) {
            warn '>>>> Captcha step is enabled...'
              if $t;
            my $captcha_worked = 0;
            my $captcha_auth   = 1;
            if ( !xss_filter( $q->param('recaptcha_response_field') ) ) {
                $captcha_worked = 0;
            }
            else {
                require DADA::Security::AuthenCAPTCHA;
                my $cap    = DADA::Security::AuthenCAPTCHA->new;
                my $result = $cap->check_answer(
                    $DADA::Config::RECAPTCHA_PARAMS->{private_key},
                    $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
                    $q->param('recaptcha_challenge_field'),
                    $q->param('recaptcha_response_field')
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
            if ( $captcha_worked == 0 ) {
                my $simple_test = 0;
                if ( $q->param('simple_test') eq 'pass' ) {
                    $simple_test = 1;
                }
                warn '>>>> >>>> Showing confirm_captcha_step_screen screen'
                  if $t;
                my $cap = DADA::Security::AuthenCAPTCHA->new;
                my $CAPTCHA_string =
                  $cap->get_html(
                    $DADA::Config::RECAPTCHA_PARAMS->{public_key} );
                require DADA::Template::Widgets;
                my $r = DADA::Template::Widgets::wrap_screen(
                    {
                        -screen => 'confirm_captcha_step_screen.tmpl',
                        -with   => 'list',
                        -list_settings_vars_param =>
                          { -list => $ls->param('list') },
                        -subscriber_vars_param => {
                            -list  => $ls->param('list'),
                            -email => $email,
                            -type  => 'sub_confirm_list'
                        },
                        -dada_pseudo_tag_filter => 1,
                        -vars                   => {
                            CAPTCHA_string => $CAPTCHA_string,
                            flavor         => 't',
                            list           => xss_filter( $q->param('list') ),
                            email          => lc_email(
                                strip( xss_filter( $q->param('email') ) )
                            ),
                            token        => xss_filter( $q->param('token') ),
                            captcha_auth => xss_filter($captcha_auth),
                            simple_test  => (
                                  ( $simple_test == 1 )
                                ? ( $q->param('simple_test') )
                                : (undef)
                            ),
                        },
                    },
                );
                $self->test ? return $r : print $fh safely_encode($r)
                  and return;
            }
        }
        else {
            carp "Captcha isn't available!";
        }
    }
    else {
        warn '>>>> Captcha step is disabled.'
          if $t;
    }

    my ( $status, $errors ) = $lh->subscription_check(
        {
            -email => $email,
            ( $ls->param('allow_blacklisted_to_subscribe') == 1 )
            ? (
                -skip => [
                    'black_listed', 'already_sent_sub_confirmation',
                    'invite_only_list'
                ],
              )
            : ( -skip =>
                  [ 'already_sent_sub_confirmation', 'invite_only_list' ], ),
        }
    );

    warn 'subscription check gave back status of: ' . $status
      if $t;
    if ($t) {
        for ( keys %$errors ) {
            warn '>>>> >>>> ERROR: ' . $_ . ' => ' . $errors->{$_}
              if $t;
        }
    }

    my $mail_your_subscribed_msg = 0;
    warn 'email_your_subscribed_msg is set to: '
      . $ls->param('email_your_subscribed_msg')
      if $t;
    if ( $ls->param('email_your_subscribed_msg') == 1 ) {
        warn '>>>> $errors->{subscribed} set to: ' . $errors->{subscribed}
          if $t;

        if ( $errors->{subscribed} == 1 ) {
            ## This is a strange one, as this *could* potentially be set,
            ## and if so, muck about with us.
            if ( exists( $errors->{already_sent_sub_confirmation} ) ) {
                delete( $errors->{already_sent_sub_confirmation} );
            }
            ##/

            my @num = keys %$errors;
            if ( $#num == 0 ) {    # meaning, "subscribed" is the only error...
                                   # Don't Treat as an Error
                $status = 1;

                # But send a private error message out...
                $mail_your_subscribed_msg = 1;
                warn '$mail_your_subscribed_msg set to: '
                  . $mail_your_subscribed_msg
                  if $t;
            }
        }
    }

# DEV it would be *VERY* strange to fall into this, since we've already checked this...
    if ( $args->{-html_output} != 0 ) {
        if ( exists( $errors->{no_list} ) ) {
            if ( $errors->{no_list} == 1 ) {
                warn '>>>> >>>> No list found.'
                  if $t;
                return user_error(
                    {
                        -list  => $list,
                        -error => "no_list",
                        -email => $email,
                        -fh    => $args->{-fh},
                        -test  => $self->test,
                    }
                );
            }
        }
    }

    # My last check - are they currently on the subscription confirmation list?!
    if (
        $lh->check_for_double_email(
            -Email => $email,
            -Type  => 'sub_confirm_list'
        ) == 0
      )
    {
        $status = 0;
        $errors->{not_on_sub_confirm_list} = 1;
    }

    if ( $status == 0 ) {
        warn '>>>> status is 0'
          if $t;

        my $r = {
            status   => 0,
            list     => $list,
            email    => $email,
            errors   => $errors,
            redirect => {
                using            => $ls->param('use_alt_url_sub_failed'),
                using_with_query => $ls->param('alt_url_sub_failed_w_qs'),
                url              => $ls->param('alt_url_sub_failed'),
                query            => '',
            }
        };
        my $qs =
          'list=' . $list . '&rm=sub&status=0&email=' . uriescape($email);
        $qs .= '&errors[]=' . $_ for keys %$errors;
        $r->{redirect}->{query} = $qs;

        if ( $args->{-html_output} == 0 ) {
            if ( $args->{-return_json} == 1 ) {
				return $self->fancy_data({-data => $r, -type => 'json'}); 
            }
            else {
				return $self->fancy_data({-data => $r}); 			
            }
        }
        elsif ( $args->{-html_output} == 1 ) {
            if ( $ls->param('use_alt_url_sub_failed') == 1 ) {
                my $rd = $self->alt_redirect($r);
                $self->test ? return $rd : print $fh safely_encode($rd)
                  and return;
            }
            else {
                my @list_of_errors = qw(
                  invalid_email
                  mx_lookup_failed
                  subscribed
                  closed_list
                  over_subscription_quota
                  black_listed
                  not_white_listed
                  not_on_sub_confirm_list
                );

                for (@list_of_errors) {
                    if ( $errors->{$_} == 1 ) {
                        return user_error(
                            {
                                -list  => $list,
                                -error => $_,
                                -email => $email,
                                -fh    => $args->{-fh},
                                -test  => $self->test,
                            }
                        );
                    }
                }

                # Fallback.
                return user_error(
                    {
                        -list  => $list,
                        -email => $email,
                        -fh    => $args->{-fh},
                        -test  => $self->test,
                    }
                );
            }
        }
    }
    elsif ( $status == 1 ) {

        if ( $ls->param('enable_subscription_approval_step') == 1 ) {

            # we go HERE, if subscriptions need to be approved. Got that?
            $lh->move_subscriber(
                {
                    -email          => $email,
                    -from           => 'sub_confirm_list',
                    -to             => 'sub_request_list',
                    -mode           => 'writeover',
                    -confirmed      => 1,
                    -fields_options => { -mode => 'preserve_if_defined', },

                }
            );
            require DADA::App::Subscriptions::ConfirmationTokens;
            my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
            $ct->remove_by_token( $q->param('token') );


			my $approve_token = $ct->save(
                {
                    -email => $email,
                    -data  => {
                        list        => $list,
                        type        => 'list',
                        flavor      => 'sub_request_approve',
                        remote_addr => $ENV{REMOTE_ADDR},
                    },
                    -remove_previous => 1,
                }
            );
            
			my $deny_token = $ct->save(
                {
                    -email => $email,
                    -data  => {
                        list        => $list,
                        type        => 'list',
                        flavor      => 'sub_request_deny',
                        remote_addr => $ENV{REMOTE_ADDR},
                    },
                    -remove_previous => 1,
                }
            );
			
			my $list_subscribe_request_approve_link = $DADA::Config::S_PROGRAM_URL . '/t/' . $approve_token . '/';
			my $list_subscribe_request_deny_link    = $DADA::Config::S_PROGRAM_URL . '/t/' . $deny_token . '/';
			
            require DADA::App::Messages;
            DADA::App::Messages::send_generic_email(
                {
                    -list    => $ls->param('list'),
                    -headers => {
                        To => '"'
                          . escape_for_sending( $ls->param('list_name') )
                          . '" <'
                          . $ls->param('list_owner_email') . '>',
                        Subject => $ls->param(
                            'subscription_approval_request_message_subject'),
                    },
                    -body =>
                      $ls->param('subscription_approval_request_message'),
                    -tmpl_params => {
                        -list_settings_vars_param =>
                          { -list => $ls->param('list') },
                        -subscriber_vars_param => {
                            -list  => $ls->param('list'),
                            -email => $email,
                            -type  => 'sub_request_list'
                        },
                        -vars => {
						list_subscribe_request_approve_link => $list_subscribe_request_approve_link, 
						list_subscribe_request_deny_link => $list_subscribe_request_deny_link, 	
},
                    },
                    -test => $self->test,
                }
            );

          # There's no, "Well, hey! You've already done that!" check here. Sigh.
            my $r = {
                flavor         => 'subscription_requires_approval',
                status         => 1,
                list           => $list,
                email          => $email,
                needs_approval => 1,
                redirect       => {
                    using =>
                      $ls->param('use_alt_url_subscription_approval_step'),
                    using_with_query =>
                      $ls->param('alt_url_subscription_approval_step'),
                    url =>
                      $ls->param('alt_url_subscription_approval_step_w_qs'),
                    query => '',
                }
            };
            my $qs = 'list='
              . $list
              . '&rm=sub&subscription_requires_approval=1&status=1&email='
              . uriescape($email);
            $r->{redirect}->{query} = $qs;

            if ( $args->{-html_output} == 0 ) {
	            if ( $args->{-return_json} == 1 ) {
					return $self->fancy_data({-data => $r, -type => 'json'}); 
	            }
	            else {
					return $self->fancy_data({-data => $r}); 			
	            }
            }
            else {
                if ( $ls->param('use_alt_url_sub_success') == 1 ) {
                    my $rd = $self->alt_redirect($r);
                    $self->test ? return $rd : print $fh safely_encode($rd)
                      and return;
                }
                else {

                    my $s = $self->_subscription_requires_approval_message(
                        {
                            -list   => $list,
                            -email  => $email,
                            -chrome => 1,
                        }
                    );
                    $self->test ? return $s : print $fh safely_encode($s)
                      and return;
                }
            }
        }
        elsif ( $ls->param('enable_subscription_approval_step') != 1 ) {

            my $new_pass    = '';
            my $new_profile = 0;
            my $sess_cookie = undef;
            my $sess        = undef;

            if ( $mail_your_subscribed_msg == 0 ) {
                warn '>>>> >>>> $mail_your_subscribed_msg is set to: '
                  . $mail_your_subscribed_msg
                  if $t;

        # We can do an remove from confirm list, and a add to the subscribe
        # list, but why don't we just *move* the darn subscriber?
        # (Basically by updating the table and changing the, "list_type" column.
        # Easy enough for me.

                warn
'>>>> >>>> Moving subscriber from "sub_confirm_list" to "list" '
                  if $t;

                $lh->move_subscriber(
                    {
                        -email          => $email,
                        -from           => 'sub_confirm_list',
                        -to             => 'list',
                        -mode           => 'writeover',
                        -confirmed      => 1,
                        -fields_options => { -mode => 'preserve_if_defined', },

                    }
                );

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

                    require DADA::Profile::Session;
                    $sess = DADA::Profile::Session->new;
                    if ( $sess->is_logged_in ) {
                        my $sess_email = $sess->get;
                        if ( $sess_email eq $email ) {

                            #...
                        }
                        else {
                            $sess->logout;
                            $sess_cookie =
                              $sess->_login_cookie( { -email => $email } );
                        }
                    }
                    else {
                        $sess_cookie =
                          $sess->_login_cookie( { -email => $email } );
                    }
                }
                warn '>>>> >>>> send_sub_success_email is set to: '
                  . $ls->param('send_sub_success_email')
                  if $t;

                if ( $ls->param('send_sub_success_email') == 1 ) {

                    warn '>>>> >>>> >>>> sending subscribed message'
                      if $t;
                    require DADA::App::Messages;
                    DADA::App::Messages::send_subscribed_message(
                        {
                            -list   => $list,
                            -email  => $email,
                            -ls_obj => $ls,
                            -test   => $self->test,
                            -vars   => {
                                new_profile        => $new_profile,
                                'profile.email'    => $email,
                                'profile.password' => $new_pass,

                            }
                        }
                    );

                }

                require DADA::App::Messages;
                DADA::App::Messages::send_owner_happenings(
                    {
                        -list  => $list,
                        -email => $email,
                        -role  => "subscribed",
                        -test  => $self->test,
                    }
                );

                warn 'send_newest_archive set to: '
                  . $ls->param('send_newest_archive')
                  if $t;

                if ( $ls->param('send_newest_archive') == 1 ) {

                    warn 'Sending newest archive.'
                      if $t;
                    require DADA::App::Messages;
                    DADA::App::Messages::send_newest_archive(
                        {
                            -list   => $list,
                            -email  => $email,
                            -ls_obj => $ls,
                            -test   => $self->test,
                        }
                    );
                }
                require DADA::App::Subscriptions::ConfirmationTokens;
                my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
                $ct->remove_by_token( $q->param('token') );
            }
            else {

                warn
'>>>> >>> >>> Sending: "Mailing List Confirmation - Already Subscribed" message'
                  if $t;

                require DADA::App::Messages;
                DADA::App::Messages::send_you_are_already_subscribed_message(
                    {
                        -list  => $list,
                        -email => $email,
                        -test  => $self->test,
                    }
                );
            }

            my $r = {
                flavor         => 'subscription',
                status         => 1,
                list           => $list,
                email          => $email,
                needs_approval => 1,
                redirect       => {
                    using            => $ls->param('use_alt_url_sub_success'),
                    using_with_query => $ls->param('alt_url_sub_success_w_qs'),
                    url              => $ls->param('alt_url_sub_success'),
                    query            => '',
                }
            };
            my $qs = 'list='
              . $list
              . '&rm=sub&needs_approval=1&status=1&email='
              . uriescape($email);
            $r->{redirect}->{query} = $qs;

            if ( $args->{-html_output} == 0 ) {
	            if ( $args->{-return_json} == 1 ) {
					return $self->fancy_data({-data => $r, -type => 'json'}); 
	            }
	            else {
					return $self->fancy_data({-data => $r}); 			
	            }
            }
            elsif ( $args->{-html_output} == 1 ) {
                if ( $ls->param('use_alt_url_sub_success') == 1 ) {
                    my $r = $self->alt_redirect($r);
                    $self->test ? return $r : print $fh safely_encode($r)
                      and return;
                }
                else {

                    warn 'Printing out, Subscription Successful screen'
                      if $t;

                    my $s = $self->_subscription_successful_message(
                        {
                            -list        => $list,
                            -email       => $email,
                            -chrome      => 1,
                            -sess        => $sess,
                            -sess_cookie => $sess_cookie,
                        }
                    );

                    $self->test ? return $s : print $fh safely_encode($s)
                      and return;
                }
            }
        }
    }
}

sub unsubscription_request {

    my $self = shift;
    my ($args) = @_;

    warn 'Starting Unsubscription Request.'
      if $t;

    require DADA::Template::HTML;

    if ( !$args->{-cgi_obj} ) {
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.';
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;
    }

    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};

    my $q     = $args->{-cgi_obj};
    my $list  = xss_filter( $q->param('list') );
    my $email = lc_email( strip( xss_filter( $q->param('email') ) ) );

    # If the list doesn't exist, don't go through the process,
    if ( $args->{-html_output} == 1 ) {
        if ( check_if_list_exists( -List => $list ) == 0 ) {
            my $r = $q->redirect(
                -uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1' );
            $self->test ? return $r : print $fh safely_encode($r) and return;
        }

        # If the list is there,
        # state that an email needs to be filled out
        # and show the unsub request page.

        if ( !$email ) {
            warn "no email."
              if $t;
            my $r =
              $q->redirect( -uri => $DADA::Config::PROGRAM_URL
                  . '?f=outdated_subscription_urls&list='
                  . $list
                  . '&orig_flavor=u' );
            $self->test ? return $r : print $fh safely_encode($r) and return;
        }

    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my ( $status, $errors ) = $lh->unsubscription_check(
        {
            -email => $email,
            -skip  => ['no_list']
        }
    );
    if ($t) {
        if ( $status == 0 ) {
            warn '"' . $email . '" failed unsubscription_check(). Details: ';
            for ( keys %$errors ) {
                warn 'Error: ' . $_ . ' => ' . $errors->{$_};
            }
        }
        else {
            warn '"' . $email . '" passed unsubscription_check()'
              if $t;
        }
    }

    # send you're already unsub'd message?
    # First, only one error and is the error that you're not sub'd?
    my $send_you_are_not_subscribed_email = 0;
    if (   $status == 0
        && scalar( keys %$errors ) == 1
        && $errors->{not_subscribed} == 1 )
    {
        # Changed the status to, "1" BUT,
        $status = 1;

        # Mark that we have to send a special email.
        $send_you_are_not_subscribed_email = 1;
    }
    else {
        warn "else,what?" if $t;

        # ...
    }

    # If there's any problems, handle them.
    if ( $status == 0 ) {

        warn '$status: ' . $status if $t;
        if ( $args->{-html_output} != 0 ) {

            # If not, show the correct error screen.
            ### invalid_email -> unsub_invalid_email

            my @list_of_errors = qw(
              invalid_email
              not_subscribed
              settings_possibly_corrupted
              already_sent_unsub_confirmation
            );
            for (@list_of_errors) {
                if ( $errors->{$_} == 1 ) {

                    # Special Case.
                    $_ = 'unsub_invalid_email'
                      if $_ eq 'invalid_email';

                    # warn "showing error, $_";
                    return user_error(
                        {
                            -list  => $list,
                            -error => $_,
                            -email => $email,
                            -fh    => $args->{-fh},
                            -test  => $self->test,
                        }
                    );
                }
            }

            # Fallback
            return user_error(
                {
                    -list  => $list,
                    -email => $email,
                    -fh    => $args->{-fh},
                    -test  => $self->test,
                }
            );
        }

    }
    else {    # Else, the unsubscribe request was OK,

        # Are we just pretending thing went alright?
        if ( $send_you_are_not_subscribed_email == 1 ) {

            # Send the URL with the unsub confirmation URL:
            require DADA::App::Messages;
            DADA::App::Messages::send_not_subscribed_message(
                {
                    -list         => $list,
                    -email        => $email,
                    -settings_obj => $ls,
                    -test         => $self->test,
                }
            );
        }
        else {

            # Send the URL with the unsub confirmation URL:
            require DADA::App::Messages;
            DADA::App::Messages::send_unsubscribe_request_message(
                {
                    -list         => $list,
                    -email        => $email,
                    -settings_obj => $ls,
                    -test         => $self->test,
                }
            );

            # Why is this removed, before seeing if they're actually subscribed?
            my $rm_status = $lh->remove_subscriber(
                {
                    -email => $email,
                    -type  => 'unsub_confirm_list'
                }
            );
            $lh->add_subscriber(
                {
                    -email      => $email,
                    -type       => 'unsub_confirm_list',
                    -dupe_check => {
                        -enable  => 1,
                        -on_dupe => 'ignore_add',
                    },
                }
            );
        }

        if ( $args->{-html_output} != 0 ) {

            require DADA::Template::Widgets;
            my $r = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'list_confirm_unsubscribe.tmpl',
                    -with   => 'list',
                    -list_settings_vars_param =>
                      { -list => $ls->param('list'), },
                    -subscriber_vars_param => {
                        -list  => $ls->param('list'),
                        -email => $email,
                        -type  => 'list'
                    },
                    -dada_pseudo_tag_filter => 1,
                    -vars => { email => $email, subscriber_email => $email },

                }
            );
            $self->test ? return $r : print $fh safely_encode($r) and return;
        }
    }
}

sub unsubscribe {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-cgi_obj} ) {
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.';
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;
    }
    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }
    my $fh      = $args->{-fh};
    my $q       = $args->{-cgi_obj};
    my $token   = $q->param('token')   || undef;
    my $process = $q->param('process') || undef;

    # If we don't have a token, things are very wrong:
    if ( !defined($token) ) {

        # I may expand on this, in the future...
        my $r =
          $q->redirect( -uri => $DADA::Config::PROGRAM_URL
              . '?flavor=outdated_subscription_urls&orig_flavor=u&list='
              . xss_filter( strip( $q->param('list') ) )
              . '&email='
              . xss_filter( strip( $q->param('email') ) ) );
        $self->test ? return $r : print $fh safely_encode($r) and return;
    }

    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
    if ( !$ct->exists($token) ) {
        return user_error(
            {
                -error => 'token_problem',
                -test  => $self->test,
            }
        );
    }

    my $data = $ct->fetch($token);

    # not sure how you got here, but, whatever:
    if ( $data->{data}->{flavor} ne 'unsub_confirm' ) {
        return user_error(
            {
                -error => 'token_problem',
                -test  => $self->test,
            }
        );
    }

    my $is_valid = 1;

    my $list_exists =
      DADA::App::Guts::check_if_list_exists( -List => $data->{data}->{list} );

    if ( $process == 1 ) {

        my $email = lc_email( strip( xss_filter( $q->param('email') ) ) );
        if ( $email eq $data->{email} ) {
            $is_valid = 1;
        }
        else {
            $is_valid = 0;
        }

        if ($is_valid) {

            $q->param( 'email', $email );
            $q->param( 'list',  $data->{data}->{list} );
            $q->param( 'mid',   $data->{data}->{mid} );
            $args->{-cgi_obj} = $q;
	
			require DADA::MailingList::Settings; 
			my $ls = DADA::MailingList::Settings->new({-list => $data->{data}->{list}}); 

			if($ls->param('private_list') == 1) {	
				$self->complete_unsubscription_request($args); 
			}
			else { 
	            $self->complete_unsubscription($args);
	            return;
			}
        }
    }
	else { 
	    require DADA::Template::Widgets;
	    my $r = DADA::Template::Widgets::wrap_screen(
	        {
	            -screen => 'list_unsubscribe.tmpl',
	            -with   => 'list',
	            -expr   => 1,
	            -vars   => {
	                token       => $token,
	                process     => $process,
	                is_valid    => $is_valid,
	                list_exists => $list_exists,
	                email_hint  => $data->{data}->{email_hint},
	            },
	            ( $list_exists == 1 )
	            ? ( -list_settings_vars_param =>
	                  { -list => $data->{data}->{list}, }, )
	            : ()
	        }
	    );
	    $self->test ? return $r : print $fh safely_encode($r) and return;
	}
}

sub complete_unsubscription {

    my $self = shift;
    my ($args) = @_;

    for ('-cgi_obj') {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " parameter!";
        }
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;
    }
    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};
    my $q  = $args->{-cgi_obj};

    my $list  = $q->param('list');
    my $email = $q->param('email');

    require DADA::MailingList::Settings;
    require DADA::MailingList::Subscribers;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    # Unsub Check - everything OK?
    my ( $status, $errors ) = $lh->unsubscription_check(
        {
            -email => $email,
            -skip  => ['already_sent_unsub_confirmation']
        }
    );
    if ($t) {
        if ( $status == 0 ) {
            warn '"' . $email . '" failed unsubscription_check(). Details: ';
            for ( keys %$errors ) {
                warn 'Error: ' . $_ . ' => ' . $errors->{$_};
            }
        }
        else {
            warn '"' . $email . '" passed unsubscription_check()';
        }
    }

    # Hmm, so we're not subscribed?
    if ( $status == 0 ) {

        return user_error(
            {
                -list  => $list,
                -error => 'not_subscribed',
                -email => $email,
                -fh    => $args->{-fh},
                -test  => $self->test,
            }
        );
        return;
    }
	else { 

	    if (
	           $ls->param('black_list') == 1
	        && $ls->param('add_unsubs_to_black_list') == 1

	      )
	    {
	        if (
	            $lh->check_for_double_email(
	                -Email => $email,
	                -Type  => 'black_list'
	            ) == 0
	          )
	        {
	            # Not on, already:
	            $lh->add_subscriber(
	                {
	                    -email      => $email,
	                    -type       => 'black_list',
	                    -dupe_check => {
	                        -enable  => 1,
	                        -on_dupe => 'ignore_add',
	                    },
	                }
	            );
	        }
	    }

	    warn 'removing, ' . $email . ' from, "list"'
	      if $t;

	    $lh->remove_subscriber(
	        {
	            -email => $email,
	            -type  => 'list'
	        }
	    );

	    require DADA::App::Messages;
	    DADA::App::Messages::send_owner_happenings(
	        {
	            -list  => $list,
	            -email => $email,
	            -role  => "unsubscribed",
	            -test  => $self->test,
	        }
	    );

	    if ( $ls->param('send_unsub_success_email') == 1 ) {

	        require DADA::App::Messages;
	        DADA::App::Messages::send_unsubscribed_message(
	            {
	                -list   => $list,
	                -email  => $email,
	                -ls_obj => $ls,
	                -test   => $self->test,
	            }
	        );

	    }

	    require DADA::Logging::Clickthrough;
	    my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
	    if ( $r->enabled ) {
	        $r->unsubscribe_log(
	            {
	                -mid   => $q->param('mid'),
	                -email => $q->param('email'),
	            }
	        );
	    }

	    require DADA::App::Subscriptions::ConfirmationTokens;
	    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
	    $ct->remove_by_token( $q->param('token') );

	    my $r = {
	        flavor   => 'unsubscription',
	        status   => 1,
	        list     => $list,
	        email    => $email,
	        redirect => {
	            using            => $ls->param('use_alt_url_unsub_success'),
	            using_with_query => $ls->param('alt_url_unsub_success_w_qs'),
	            url              => $ls->param('alt_url_unsub_success'),
	            query            => 'list=' . uriescape($list) . '&rm=unsub&status=1&email=' . uriescape($email),
	        }
	    };

	    if ( $args->{-html_output} == 1 ) {
	        if ( $ls->param('use_alt_url_unsub_success') == 1 ) {
	            my $rd = $self->alt_redirect($r);
	            $self->test ? return $rd : print $fh safely_encode($rd) and return;
	    	}
			else {
		        my $s = $ls->param('html_unsubscribed_message');
		        require DADA::Template::Widgets;
		        my $return = DADA::Template::Widgets::wrap_screen(
		            {
		                -data                     => \$s,
		                -with                     => 'list',
		                -list_settings_vars_param => { -list => $ls->param('list') },
		                -dada_pseudo_tag_filter   => 1,
		                -subscriber_vars          => { 'subscriber.email' => $email },
		            }
		        );
		        $self->test ? return $return : print $fh safely_encode($return) and return;
			}
	    }
		else { 
			# Else, I dunno! There's no, -html_output argument, here!"; 
		}
	}
}



sub complete_unsubscription_request { 

    my $self = shift;
    my ($args) = @_;

    for ('-cgi_obj') {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " parameter!";
        }
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;
    }
    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};
    my $q  = $args->{-cgi_obj};

    my $list  = $q->param('list');
    my $email = $q->param('email');

    require DADA::MailingList::Settings;
    require DADA::MailingList::Subscribers;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    # Unsub Check - everything OK?
    my ( $status, $errors ) = $lh->unsubscription_check(
        {
            -email => $email,
            -skip  => ['already_sent_unsub_confirmation']
        }
    );
    if ($t) {
        if ( $status == 0 ) {
            warn '"' . $email . '" failed unsubscription_check(). Details: ';
            for ( keys %$errors ) {
                warn 'Error: ' . $_ . ' => ' . $errors->{$_};
            }
        }
        else {
            warn '"' . $email . '" passed unsubscription_check()';
        }
    }

    # Hmm, so we're not subscribed?
    if ( $status == 0 ) {
        return user_error(
            {
                -list  => $list,
                -error => 'not_subscribed',
                -email => $email,
                -fh    => $args->{-fh},
                -test  => $self->test,
            }
        );
        return;
    }
	else { # $status == 1

=cut
		
		if (
	           $ls->param('black_list') == 1
	        && $ls->param('add_unsubs_to_black_list') == 1

	      )
	    {
	        if (
	            $lh->check_for_double_email(
	                -Email => $email,
	                -Type  => 'black_list'
	            ) == 0
	          )
	        {
	            # Not on, already:
	            $lh->add_subscriber(
	                {
	                    -email      => $email,
	                    -type       => 'black_list',
	                    -dupe_check => {
	                        -enable  => 1,
	                        -on_dupe => 'ignore_add',
	                    },
	                }
	            );
	        }
	    }

	    warn 'removing, ' . $email . ' from, "list"'
	      if $t;

	    $lh->remove_subscriber(
	        {
	            -email => $email,
	            -type  => 'list'
	        }
	    );

	    require DADA::App::Messages;
	    DADA::App::Messages::send_owner_happenings(
	        {
	            -list  => $list,
	            -email => $email,
	            -role  => "unsubscribed",
	            -test  => $self->test,
	        }
	    );

	    if ( $ls->param('send_unsub_success_email') == 1 ) {

	        require DADA::App::Messages;
	        DADA::App::Messages::send_unsubscribed_message(
	            {
	                -list   => $list,
	                -email  => $email,
	                -ls_obj => $ls,
	                -test   => $self->test,
	            }
	        );

	    }

	    require DADA::Logging::Clickthrough;
	    my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
	    if ( $r->enabled ) {
	        $r->unsubscribe_log(
	            {
	                -mid   => $q->param('mid'),
	                -email => $q->param('email'),
	            }
	        );
	    }

	    require DADA::App::Subscriptions::ConfirmationTokens;
	    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
	    $ct->remove_by_token( $q->param('token') );

=cut

	    my $r = {
	        flavor   => 'unsubscription_request',
	        status   => 1,
	        list     => $list,
	        email    => $email,
	        redirect => {
	            using            => $ls->param('use_alt_url_unsub_success'),
	            using_with_query => $ls->param('alt_url_unsub_success_w_qs'),
	            url              => $ls->param('alt_url_unsub_success'),
	            query            => 'list=' . uriescape($list) . '&rm=unsub&status=1&email=' . uriescape($email),
	        }
	    };

	    if ( $args->{-html_output} == 1 ) {
	        if ( $ls->param('use_alt_url_unsub_success') == 1 ) {
	            my $rd = $self->alt_redirect($r);
	            $self->test ? return $rd : print $fh safely_encode($rd) and return;
	    	}
			else {
		        my $s = 'Dude, your unsub request has been done up!'; # $ls->param('html_unsubscribed_message');
		        require DADA::Template::Widgets;
		        my $return = DADA::Template::Widgets::wrap_screen(
		            {
		                -data                     => \$s,
		                -with                     => 'list',
		                -list_settings_vars_param => { -list => $ls->param('list') },
		                -dada_pseudo_tag_filter   => 1,
		                -subscriber_vars          => { 'subscriber.email' => $email },
		            }
		        );
		        $self->test ? return $return : print $fh safely_encode($return) and return;
			}
	    }
		else { 
			# Else, I dunno! There's no, -html_output argument, here!"; 
		}
	}
}

sub subscription_requests {

    my $self = shift;
    my ($args) = @_;

    if ( !$args->{-cgi_obj} ) {
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.';
    }

    if ( !exists( $args->{-html_output} ) ) {
        $args->{-html_output} = 1;
    }
    if ( !exists( $args->{-fh} ) ) {
        $args->{-fh} = \*STDOUT;
    }
    my $fh      = $args->{-fh};
    my $q       = $args->{-cgi_obj};
    my $token   = $q->param('token')   || undef;

    # If we don't have a token, things are very wrong:
    if ( !defined($token) ) {
        my $r =
          $q->redirect( -uri => $DADA::Config::PROGRAM_URL
              . '?flavor=outdated_subscription_urls&orig_flavor=u&list='
              . xss_filter( strip( $q->param('list') ) )
              . '&email='
              . xss_filter( strip( $q->param('email') ) ) );
        $self->test ? return $r : print $fh safely_encode($r) and return;
    }

    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
    if ( !$ct->exists($token) ) {
        return user_error(
            {
                -error => 'token_problem',
                -test  => $self->test,
            }
        );
    }

    my $data = $ct->fetch($token);
    # not sure how you got here, but, whatever:
    if ( 
		$data->{data}->{flavor} ne 'sub_request_approve' 
	&&  $data->{data}->{flavor} ne 'sub_request_deny'
	) {
        return user_error(
            {
                -error => 'token_problem',
                -test  => $self->test,
            }
        );
    }


	my $flavor = $data->{data}->{flavor}; 
	my $email  = $data->{email}; 
	my $list   = $data->{data}->{list}; 

	# And then, is never used? 
    my $list_exists = DADA::App::Guts::check_if_list_exists( -List => $list );

    require DADA::MailingList::Settings;
    require DADA::MailingList::Subscribers;
    require DADA::App::Subscriptions::ConfirmationTokens;

    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );	
	
	if ($lh->check_for_double_email(
      -Email => $email,
      -Type  => 'sub_request_list'
    ) == 0) { 
		$ct->remove_by_token( $token );
	    return user_error(
	        {
	            -error => 'token_problem',
	            -test  => $self->test,
	        }
	    );
	}
	else { 
		$ct->remove_by_token( $token );
	    if ( $flavor eq 'sub_request_approve' ) {
			 my $count = 1; 
		
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

			use CGI qw(:standard); 
			print header(); 
			print 'subscriber approved, dude!'; 
		
=cut
	        my $flavor_to_return_to = 'view_list';
	        if ( $return_to eq 'membership' ) {    # or, others...
	            $flavor_to_return_to = $return_to;
	        }

	        my $qs = 'f=' . $flavor_to_return_to . ';type=' . $q->param('type') . ';approved_count=' . $count;

	        if ( $return_to eq 'membership' ) {
	            $qs .= ';email=' . $return_address;
	        }

	        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
=cut

	    }
	    elsif ( $flavor eq 'sub_request_deny' ) {
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
		    my $count = 1; 

=cut

	        my $flavor_to_return_to = 'view_list';
	        if ( $return_to eq 'membership' ) {    # or, others...
	            $flavor_to_return_to = $return_to;
	        }

	        my $qs = 'f=' . $flavor_to_return_to . ';type=' . $q->param('type') . ';denied_count=' . $count;

	        if ( $return_to eq 'membership' ) {
	            $qs .= ';email=' . $return_address;
	        }
	        print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL . '?' . $qs );
=cut

		use CGI qw(:standard); 
		print header(); 
		print 'subscriber denied, dude!'; 



	    }
	    else {
	        die "unknown process!";
	    }
	}
}




sub fancy_data {
    my $self = shift;
    my ($args) = @_;
	if(!exists($args->{-type})){ 
		$args->{-type} = 'perl';
	}

	my $data = $args->{-data}; 
	my $type = $args->{-type}, 

    my $return = {
        list   => $data->{list},
        email  => $data->{email},
        status => $data->{status},
		redirect => $data->{redirect}, 
    };

    my $error_descriptions = {};
	
    for ( keys %{ $data->{errors} } ) {
		if($_ eq 'already_sent_sub_confirmation') {			
			$return->{error_descriptions}->{already_sent_sub_confirmation} = 'use redirect';
			$return->{redirect_required}  = 'subscription_requires_captcha';
	 		$return->{redirect}->{url} = 
				$DADA::Config::PROGRAM_URL 
				. '?f=show_error&email=' 
				. uriescape($data->{email}) 
				. '&list=' 
				. uriescape($data->{list}) 
				. '&error=already_sent_sub_confirmation';
		}
		elsif($_ eq 'invalid_list'){ 
			$return->{error_descriptions}->{invalid_list} = 'use redirect';
			$return->{redirect_required}  = 'invalid_list';
		}
		else { 
			
			$return->{error_descriptions}->{$_} = $self->_user_error_msg({
	            -list   => $data->{list},
	            -email  => $data->{email},
	            -chrome => 0,
	            -error  => $_,
	        });
		}
    }

    if ( keys %{ $data->{errors} } ) {
		$return->{errors}             = $data->{errors};
    }
    else {
        if ( $data->{flavor} eq 'subscription_confirmation' ) {
            $return->{success_message} =
              $self->_subscription_confirmation_success_msg(
                {
                    -list   => $data->{list},
                    -email  => $data->{email},
                    -chrome => 0,
                }
              );
        }
        elsif ( $data->{flavor} eq 'subscription' ) {
            $return->{success_message} =
              $self->_subscription_successful_message(
                {
                    -list   => $data->{list},
                    -email  => $data->{email},
                    -chrome => 0,
                }
              );
        }
		elsif( $data->{flavor} eq 'subscription_requires_captcha') { 
			$return->{success_message} = 'use redirect';
			$return->{redirect_required} = 'subscription_requires_captcha'
		}
        elsif ( $data->{flavor} eq 'subscription_requires_approval' ) {
            $return->{success_message} =
              $self->_subscription_requires_approval_message(
                {
                    -list   => $data->{list},
                    -email  => $data->{email},
                    -chrome => 0,
                }
              );
        }
        else {
            warn 'unkown flavor, "' . $data->{flavor} . '"';
        }
    }

	if(!exists($data->{redirect}->{using})){ 
		$data->{redirect}->{using} = 0; 
	}
	$data->{redirect}->{using} = int($data->{redirect}->{using}); 
	if(!exists($data->{redirect}->{using_with_query})){ 
		$data->{redirect}->{using_with_query} = 0; 
	}
	$data->{redirect}->{using_with_query} = int($data->{redirect}->{using_with_query}); 
	if(!exists($data->{redirect}->{url})){ 
		$data->{redirect}->{url}= ''; 
	}
	if(!exists($data->{redirect}->{query})){ 
		$data->{redirect}->{query}= ''; 
	}

	if($args->{-type} eq 'json') { 
		require JSON::PP;
	    my $json = JSON::PP->new->allow_nonref;
	    my $data_back = $json->pretty->encode($return);
	    return $data_back;
	}
	else { 
		return $return; 
	}
}

sub _subscription_confirmation_success_msg {
    my $self = shift;
    my ($args) = @_;

    my $list = $args->{-list};

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );

    my $s = $ls->param('html_confirmation_message');
    require DADA::Template::Widgets;
    my $r;
    if ( $args->{-chrome} == 1 ) {
        $r = DADA::Template::Widgets::wrap_screen(
            {
                -data => \$s,
                -with => 'list',
                -expr => 1,
                -vars => { chrome => $args->{-chrome}, },
                -list_settings_vars_param =>
                  { -list => $ls->param('list'), -dot_it => 1, },
                -subscriber_vars_param => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'sub_confirm_list'
                },
                -dada_pseudo_tag_filter => 1,
            }
        );
    }
    else {
        $r = DADA::Template::Widgets::screen(
            {
                -data => \$s,
                -expr => 1,
                -vars => { chrome => $args->{-chrome}, },
                -list_settings_vars_param =>
                  { -list => $ls->param('list'), -dot_it => 1, },
                -subscriber_vars_param => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'sub_confirm_list'
                },
                -dada_pseudo_tag_filter => 1,
            }
        );
    }

    return $r;

}

sub _subscription_successful_message {

    my $self = shift;
    my ($args) = @_;
    my $sess_cookie;
    my $sess;

    my $list = $args->{-list};

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );

    my $s = $ls->param('html_subscribed_message');
    require DADA::Template::Widgets;
    my $r;
    if ( $args->{-chrome} == 1 ) {
        $r = DADA::Template::Widgets::wrap_screen(
            {
                -data           => \$s,
                -with           => 'list',
                -wrapper_params => {
                    -header_params => { -cookie => [ $args->{-sess_cookie} ], },
                    -prof_sess_obj => $args->{-sess},
                },
                -list_settings_vars_param => { -list => $ls->param('list'), },
                -subscriber_vars_param    => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'list'
                },
                -dada_pseudo_tag_filter => 1,
                -vars                   => {
                    chrome           => $args->{-chrome},
                    email            => $args->{-email},
                    subscriber_email => $args->{-email},
                },
            }
        );
    }
    else {
        $r = DADA::Template::Widgets::screen(
            {
                -data                     => \$s,
                -list_settings_vars_param => { -list => $ls->param('list'), },
                -subscriber_vars_param    => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'list'
                },
                -dada_pseudo_tag_filter => 1,
                -vars                   => {
                    chrome           => $args->{-chrome},
                    email            => $args->{-email},
                    subscriber_email => $args->{-email}
                },
            }

        );
    }

    return $r;
}

sub _subscription_requires_approval_message {

    my $self = shift;
    my ($args) = @_;

    my $list = $args->{-list};

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );

    my $s = $ls->param('html_subscription_request_message');
    require DADA::Template::Widgets;
    my $r;
    if ( $args->{-chrome} == 1 ) {
        $r = DADA::Template::Widgets::wrap_screen(
            {
                -data                     => \$s,
                -with                     => 'list',
                -list_settings_vars_param => { -list => $ls->param('list'), },
                -subscriber_vars_param    => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'sub_request_list'
                },
                -dada_pseudo_tag_filter => 1,
                -vars                   => {
                    chrome           => $args->{-chrome},
                    email            => $args->{-email},
                    subscriber_email => $args->{-email}
                },
            }
        );
    }
    else {
        $r = DADA::Template::Widgets::screen(
            {
                -data                     => \$s,
                -list_settings_vars_param => { -list => $ls->param('list'), },
                -subscriber_vars_param    => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'sub_request_list'
                },
                -dada_pseudo_tag_filter => 1,
                -vars                   => {
                    chrome           => $args->{-chrome},
                    email            => $args->{-email},
                    subscriber_email => $args->{-email}
                },
            }
        );
    }

    return $r;
}

sub _user_error_msg {
    my $self = shift;
    my ($args) = @_;
    require DADA::App::Error;
    my $s = DADA::App::Error::cgi_user_error(
        {
            -list   => $args->{-list},
            -error  => $args->{-error},
            -email  => $args->{-email},
            -vars   => $args->{-vars}, 
            -chrome => $args->{-chrome},
        }
    );
    return $s;
}



sub alt_redirect {

    my $self = shift;
    my ($args) = @_;

	if(!exists($args->{redirect}->{url})){ 
		croak "I need a url, before I can redirect to it!"; 
	}
    my $url = $args->{redirect}->{url};

    require CGI;
    my $q = CGI->new;
    $q->charset($DADA::Config::HTML_CHARSET);

    $url = strip($url);

    if ( !isa_url($url) ) {
        $url = 'http://' . $url;
    }
    if ( $args->{redirect}->{using_with_query} == 1 ) {
        if ( $url =~ m/\?/ ) {

            # Already has a query string?!
            $url = $q->redirect( $url . '&' . $args->{redirect}->{query} );
        }
        else {
            $url = $q->redirect( $url . '?' . $args->{redirect}->{query} );
        }
    }
    else {
        return $q->redirect($url);
    }

}

sub DESTROY {

}

1;

=pod

=head1 NAME 

DADA::App::Subscriptions

=head1 SYNOPSIS

 # Import
 use DADA::App::Subscriptions; 
  
 # Create a new object - no arguments needed
 my $das = DADA::App::Subscriptions->new; 
 
 # Awkwardly use CGI.pm's param() method to stuff parameters for 
 # DADA::App::Subscriptions->subscribe() to use
 
 use CGI; 
 my $q = CGI->new; 
 $q->param('list', 'yourlist');
 $q->param('email', 'user@example.com');
 
 # subscribe
 my $das = DADA::App::Subscriptions->new;
    $das->subscribe(
    {
          -cgi_obj     => $q,
    }
  );


=head1 DESCRIPTION

This module holds reusable code for a user to subscribe or unsubscribe from a Dada Mail mailing list. 

=head1 Public Methods

=head2 Initializing

=head2 new

 my $das = DADA::App::Subscriptions->new; 

C<new> takes no arguments. 

=head2 test

 $das->test(1);

Passing, C<test> a value of, C<1> will turn this module into testing mode. Usually (and also, awkwardly) this module will 
perform the needed job of printing any HTML needed to complete the request you've given it.

If testing mode is on, the HTML will merely be returned to you. 

Email messages will also be printed to a text file, instead of being sent out. 

You probably only want to use, C<test> if you're actually I<testing>, via the unit tests that ship with Dada Mail. 

=head2 subscribe

 # Awkwardly use CGI.pm's param() method to stuff parameters for 
 # DADA::App::Subscriptions->subscribe() to use
 
 use CGI; 
 my $q = CGI->new; 
 $q->param('list', 'yourlist');
 $q->param('email', 'user@example.com');
 
 # subscribe
 my $das = DADA::App::Subscriptions->new;
    $das->subscribe(
    {
          -cgi_obj     => $q,
    }
 );

C<subscribe> requires one parameter, C<-cgi-obj>, which needs to be a CGI.pm object 
(a CGI.pm param-compatible module won't work, but we may work on that) THAT IN ITSELF has two parameters: 

=over

=item * list

holding the list shortname you want to work with

=item * email

holding the email address you want to work with

=back

C<-html_output> is an optional parameter, if set to, C<0>, this method will not print out the HTML 
user message telling the user if everything went well (or not). 

On success, this method will return, C<undef>

=head3 Notes on awkwardness of the API

It's quite apparrent that the API of this method is not very well thought-out. The history of this method 
started as a subroutine in the main, C<mail.cgi> script itself that overgrown its bounds considerably, but didn't 
receive a re-design of its API. Also, returning, C<undef> on success is also not very helpful. 

Rather, you may want to look into Dada Mail's Experimental JSON API: 

L<http://dadamailproject.com/d/COOKBOOK-subscriptions.pod.html>

=head1 AUTHOR

Justin Simoni http://dadamailproject.com

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999 - 2013 Justin Simoni All rights reserved. 

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

=cut 

