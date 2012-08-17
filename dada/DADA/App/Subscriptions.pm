package DADA::App::Subscriptions;

use lib qw(../../ ../../perllib);


use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 

use Carp qw(carp croak); 
use Try::Tiny; 

use vars qw($AUTOLOAD); 
use strict; 
my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions}; 


my %allowed = (
	test => 0, 
); 

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my %args = (@_); 
		
   $self->_init(\%args); 
   return $self;
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init {}




sub subscribe { 
    
    my $self = shift; 

    my ($args) = @_; 
    
    require DADA::Template::HTML;
    
	# Test sub-subscribe-no-cgi
    if ( ! $args->{-cgi_obj}){ 
        croak 'Error: No CGI Object passed in the -cgi_obj parameter.'; 
    }

    if(! exists($args->{-html_output})){ 
        $args->{-html_output} = 1; 
    }
    
    
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }

    my $fh = $args->{-fh}; 
    
    my $q     = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 

    my $email = lc_email( strip ( xss_filter( $q->param( 'email' ) ) ) ); 

    my $list_exists = DADA::App::Guts::check_if_list_exists(-List => $list);
	my $ls          = undef; 
	
	require DADA::MailingList::Settings;
	
	
	
	if($list_exists){ 
		$ls = DADA::MailingList::Settings->new({-list => $list}); 
	}	
    if($args->{-html_output} == 1){         
        if($list_exists == 0){ 
            # Test sub-subscribe-redirect-error_invalid_list
			my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1');  
			$self->test ? return $r : print $fh safely_encode(  $r) and return; 
        }
		else { 
			
			 if (!$email){ 
					if($ls->param('use_alt_url_sub_confirm_failed') != 1) { 
						# Test sub-subscribe-redirect-error_no_email
						# This is just so we don't use the actual error screen.
				  		my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=s'); 
						$self->test ? return $r : print $fh safely_encode(  $r) and return; 
					}
		        }
			
		}
	}
	else { 
		#  List does not exist.
	}
	
    require DADA::MailingList::Subscribers;         
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
    
    my $fields = {}; 
    for(@{$lh->subscriber_fields}){ 
		if(defined($q->param($_))){ 
        	$fields->{$_} = xss_filter($q->param($_)); 
		}
	}
    
	# I really wish this was done, after we look and see if the confirmation
	# step is even needed, just so we don't have to do this, twice. It would
	# clarify a bunch of things, I think.
    my ($status, $errors) = $lh->subscription_check(
								{
                                -email => $email,   
   								-type  => 'list', 

                                    ($ls->param('allow_blacklisted_to_subscribe') == 1) ? 
                                    (
                                    -skip  => ['black_listed'], 
                                    ) : (),
 								}
                             ); 
	
	# This is kind of strange... 
	my $skip_sub_confirm_if_logged_in = 0; 
	
	
	if($status == 1){ 
	
		my $skip_sub_confirm_if_logged_in = 0; 
		if($ls->param('skip_sub_confirm_if_logged_in')){
			require DADA::Profile::Session; 
			my $sess = DADA::Profile::Session->new; 
			if($sess->is_logged_in){	
				my $sess_email = $sess->get;
				if ($sess_email eq $email){ 
					# something... 
					$skip_sub_confirm_if_logged_in = 1;
				}
			}
		}	
		if(
			$ls->param('enable_closed_loop_opt_in')    == 0 || 
			$skip_sub_confirm_if_logged_in == 1
		){    
	
			
	        $lh->add_subscriber(
	            {
	                -email         => $email, 
	                -type          => 'sub_confirm_list', 
	                -fields        => $fields,
	            	-confirmed     => 0, 
				}
	        );

	        # This is... slightly weird.
	        $args->{-cgi_obj}->param('pin', DADA::App::Guts::make_pin(-Email => $email, -List => $list));  

	        $self->confirm(
	            {
	                -html_output => $args->{-html_output}, 
	                -cgi_obj     => $args->{-cgi_obj},
	            },
	        );

	        return; 
	    }
	}	
	
									
							
     my $mail_your_subscribed_msg = 0; 
     
     if($ls->param('email_your_subscribed_msg') == 1){ 
        if($errors->{subscribed} == 1){ 
        
			# This is a strange one, as this *could* potentially be set, 
			# and if so, muck about with us. 
			if(exists($errors->{already_sent_sub_confirmation})){ 
				delete($errors->{already_sent_sub_confirmation}); 
			}
			#/

            my @num = keys %$errors; 
			
            if($#num == 0){ # meaning, "subscribed" is the only error...
               
                # Don't Treat as an Error
                $status = 1; 
                
                # But send a private error message out...
                $mail_your_subscribed_msg = 1; 
            }
        }
    }    
    
    if($status == 0){     
        if($args->{-html_output} != 0){ 
        
			# Test sub-subscribe-alt_url_sub_confirm_failed
            if(
				$ls->param('use_alt_url_sub_confirm_failed') == 1
			){ 
            
                my $qs = ''; 
                if($ls->param('alt_url_sub_confirm_failed_w_qs') == 1){ 
                    $qs = 'list=' . $list . '&rm=sub_confirm&status=0&email=' . uriescape($email);
                    $qs .= '&errors[]=' . $_ for keys %$errors; 
                    $qs .= '&' . $_ . '=' . uriescape($fields->{$_}) for keys %$fields; 
                }
                
                my $r = $self->alt_redirect($ls->param('alt_url_sub_confirm_failed'), $qs); 
				$self->test ? return $r : print $fh safely_encode(  $r) and return; 

            }else{

                my @list_of_errors = qw(
                    invalid_email
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
                
                for(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                        return user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
							-test  => $self->test, 
                        ); 
                    }
                }

                # Fallback
               return user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
					-test  => $self->test, 
                );    
            }            
        }
        
    }else{ 
        
        # The idea is, we'll save the information for the subscriber in the confirm list, and then 
        # move the info to the actual subscription list, 
        # And then remove the information from the confirm list, when we're all done. 
        
        my $rm_status = $lh->remove_subscriber(
			{
            	-email => $email, 
                -type  => 'sub_confirm_list',
            }
		);
		                
        $lh->add_subscriber(
             { 
                 -email     => $email, 
                 -type      => 'sub_confirm_list', 
                 -fields    => $fields,
	             -confirmed => 0, 
             }
        ); 
        
        if($mail_your_subscribed_msg == 0){ 
        
            require DADA::App::Messages;
            DADA::App::Messages::send_confirmation_message(
				{
	                -list   => $list, 
	                -email  => $email, 
	                -ls_obj => $ls, 
					-test   => $self->test, 
        		}
			); 

        }else{ 
			warn '>>>> >>> >>> Sending: "Mailing List Confirmation - Already Subscribed" message' 
			if $t; 

			require DADA::App::Messages;
			DADA::App::Messages::send_you_are_already_subscribed_message(		
				{
					-list         => $list, 
					-email        => $email, 
					-test         => $self->test, 
				}
			);

        }
		
        
        if($args->{-html_output} != 0){         
            if(
                $ls->param('use_alt_url_sub_confirm_success')       ==  1 
              ){ 
                my $qs = ''; 
                if($ls->param('alt_url_sub_confirm_success_w_qs') == 1){ 
                    $qs  = 'list=' . $list . '&rm=sub_confirm&status=1&email=' . uriescape($email); 
                    $qs .= '&' . $_ . '=' . uriescape($fields->{$_}) for keys %$fields; 
                    
                }
                my $r = $self->alt_redirect($ls->param('alt_url_sub_confirm_success'), $qs); 

      			$self->test ? return $r : print $fh safely_encode(  $r) and return; 

            }else{ 
    			
				my $s = $ls->param('html_confirmation_message'); 
				require DADA::Template::Widgets; 
				my $r =   DADA::Template::Widgets::wrap_screen(
				{ 
					-data                     => \$s,
					-with                     => 'list', 
					-list_settings_vars_param => {-list => $ls->param('list'),}, # um, -dot_it? 
					-subscriber_vars_param    => {-list => $ls->param('list'), -email => $email, -type => 'sub_confirm_list'},
					-dada_pseudo_tag_filter   => 1,             
				} 

				); 
                # Test: sub_confirm-sub_confirm_success
				$self->test ? return $r : print $fh safely_encode(  $r) and return; 
                 
            }
        }
    }
}




sub confirm { 

    my $self = shift; 
    my ($args) = @_; 
    
    warn 'Starting Subscription Confirmation.' 
        if $t; 
    
    require DADA::Template::HTML;
    
	# Test: sub-confirm-no-cgi
    if(! exists($args->{-cgi_obj}) ){ 
		croak 'Error: No CGI Object passed in the -cgi_obj parameter.'; 
	}
    
    if(! exists($args->{-html_output})){ 
        $args->{-html_output} = 1; 
         
    }
    warn '-html_output set to ' . $args->{-html_output}
        if $t; 
    
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};

    my $q = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = lc_email( strip ( xss_filter( $q->param( 'email' ) ) ) ); 
        
    my $pin   = xss_filter($q->param('pin')); 

    warn '$list: ' . $list
        if $t; 
    warn '$email: ' . $email
        if $t;
    warn '$pin: ' . $pin
        if $t; 
        
    my $list_exists = DADA::App::Guts::check_if_list_exists(-List => $list);
    
	require DADA::MailingList::Settings;
	my $ls = undef; 
	
	if($list_exists == 1){ 
		$ls = DADA::MailingList::Settings->new({-list => $list}); 
	}
	
    if($args->{-html_output} == 1){ 
	
        if($list_exists == 0){ 
            
            warn '>>>> >>>> list doesn\'t exist. Redirecting to default screen.'
                if $t; 
            my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1'); 
			$self->test ? return $r : print $fh safely_encode(  $r) and return; 
        }
		else { 
			# Again!
			
	        if (!$email){ 	
				if($ls->param('use_alt_url_sub_failed') != 1) { 
	            	warn '>>>> >>>> no email passed. Redirecting to list screen'
		                if $t; 
		            my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=s'); 
		            $self->test ? return $r : print $fh safely_encode(  $r) and return;
				}	
			}
        }
    }
              
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    warn 'captcha_sub set to: ' . $ls->param('captcha_sub')
        if $t; 
    
    if($ls->param('captcha_sub') == 1){
	 
		my $can_use_captcha = 1; 
		try { 
			require DADA::Security::AuthenCAPTCHA; 
		} catch {
			carp "CAPTCHA Not working correctly?: $_";  
			$can_use_captcha = 0;
		};
		
	   if($can_use_captcha == 1){ 

	        warn '>>>> Captcha step is enabled...'
	            if $t; 
        
	        # CAPTCHA STUFF
        
	        # warn "captcha on..."; 
        
        
	        my $captcha_worked = 0; 
	        my $captcha_auth   = 1; 
        
        
	        if(! xss_filter($q->param('recaptcha_response_field'))){      
            
	            $captcha_worked = 0; 
    
	        }else{
	            require DADA::Security::AuthenCAPTCHA;         
	            my $cap = DADA::Security::AuthenCAPTCHA->new; 
	            my $result = $cap->check_answer(
	                $DADA::Config::RECAPTCHA_PARAMS->{private_key}, 
	                $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'}, 
	                $q->param( 'recaptcha_challenge_field' ), 
	                $q->param( 'recaptcha_response_field')
	            ); 
           
	           if($result->{is_valid} == 1){ 
	                $captcha_auth    = 1;
	                $captcha_worked  = 1; 
	            } else { 
	                 $captcha_worked = 0; 
	                 $captcha_auth   = 0; 
	            }        
        
	        }
    
    
    
	        if($captcha_worked == 0){ 
            
	            warn '>>>> >>>> Showing confirm_captcha_step_screen screen'
	                if $t; 
 
		
	            my $cap = DADA::Security::AuthenCAPTCHA->new; 
	            my $CAPTCHA_string = $cap->get_html($DADA::Config::RECAPTCHA_PARAMS->{public_key}); 
      
				require DADA::Template::Widgets;
				my $r =  DADA::Template::Widgets::wrap_screen(
					{
					-screen                   => 'confirm_captcha_step_screen.tmpl', 
					-with                     => 'list',
					-list_settings_vars_param => {-list => $ls->param('list')},
					-subscriber_vars_param    => {-list => $ls->param('list'), -email => $email, -type => 'sub_confirm_list'},
					-dada_pseudo_tag_filter   => 1, 

					-vars   => {

						CAPTCHA_string   => $CAPTCHA_string,

						# BUGFIX: 
						#  2308530  	 3.0.0 - sub Confirm CAPTCHA broken w/close-loop disabled
						# https://sourceforge.net/tracker2/?func=detail&aid=2308530&group_id=13002&atid=113002
						# I'm trying to figure out where this would not be, "n", but I'm faiing, so 
						# for the moment, I'm just going to put that value in, myself: 

						#flavor       => xss_filter($q->param('flavor')), 
						flavor        => 'n', 

						list         => xss_filter( $q->param('list')), 
						email        => lc_email( strip ( xss_filter( $q->param( 'email' ) ) ) ), 
						pin          => xss_filter($q->param('pin')), 
						captcha_auth => xss_filter($captcha_auth),        

						},
					},
				);
    
				$self->test ? return $r : print $fh safely_encode(  $r) and return; 

	        }                                             
    
	        #/ CAPTCHA STUFF
	    }
		else { 
			carp "Captcha stuff isn't available!"; 
		}
	}
	   else { 
   
        warn '>>>> Captcha step is disabled.'
            if $t; 
           	    
}
                                             
    my ($status, $errors) = $lh->subscription_check(
								{
                                 	-email => $email, 
	                                     ($ls->param('allow_blacklisted_to_subscribe') == 1) ? 
	                                     (
 	                                     -skip  => ['black_listed', 'already_sent_sub_confirmation', 'invite_only_list'], 
	                                     ) : 
	                                     (
	                                     -skip => ['already_sent_sub_confirmation', 'invite_only_list'], 
	                                     ),
	 								}
                              );
    
	                                          
     warn 'subscription check gave back status of: ' . $status
        if $t; 
     if($t){ 
        for(keys %$errors){ 
            warn '>>>> >>>> ERROR: ' . $_ . ' => ' . $errors->{$_}
                if $t; 
        }
     }
 
	
     my $mail_your_subscribed_msg = 0; 
     warn 'email_your_subscribed_msg is set to: ' . $ls->param('email_your_subscribed_msg')
        if $t; 
     if($ls->param('email_your_subscribed_msg') == 1){ 
        warn '>>>> $errors->{subscribed} set to: ' . $errors->{subscribed}
            if $t; 
            
        if($errors->{subscribed} == 1){ 
			## This is a strange one, as this *could* potentially be set, 
			## and if so, muck about with us. 
			if(exists($errors->{already_sent_sub_confirmation})){ 
				delete($errors->{already_sent_sub_confirmation}); 
			}
			##/
			
            my @num = keys %$errors; 
            if($#num == 0){ # meaning, "subscribed" is the only error...
                # Don't Treat as an Error
                $status = 1; 
                # But send a private error message out...
                $mail_your_subscribed_msg = 1; 
                warn '$mail_your_subscribed_msg set to: ' . $mail_your_subscribed_msg
                    if $t; 
            }
        }
    }    
                                                
    
    my $is_pin_valid = check_email_pin(
		-Email => $email, 
		-List => $list, 
		-Pin => $pin
	);
    warn '$is_pin_valid set to: ' . $is_pin_valid
        if $t; 
    if ($is_pin_valid == 0) {
        $status = 0; 
        $errors->{invalid_pin} = 1;
        warn '>>>> $errors->{invalid_pin} set to: ' . $errors->{invalid_pin}
			if $t; 
        
    }

    # DEV it would be *VERY* strange to fall into this, since we've already checked this...
    if($args->{-html_output} != 0){
		if(exists($errors->{no_list})){ 
	        if ($errors->{no_list}  == 1){ 
	            warn '>>>> >>>> No list found.'
	                if $t; 
	            return user_error(
	                -List  => $list, 
	                -Error => "no_list",
	                -Email => $email,
	                -fh    => $args->{-fh},
					-test  => $self->test, 
	            );            
	        }
		}
    }
    
    
    # My last check - are they currently on the subscription confirmation list?!
    if($lh->check_for_double_email(-Email => $email,-Type  => 'sub_confirm_list')  == 0){ 
        $status = 0; 
        $errors->{not_on_sub_confirm_list} = 1; 
    }

    if($status == 0){ 
        warn '>>>> status is 0'
            if $t; 
        if($args->{-html_output} != 0){ 

            warn '>>>> >>>> use_alt_url_sub_failed set to: ' . $ls->param('use_alt_url_sub_failed')
                if $t; 
            warn '>>>> >>>> alt_url_sub_failed set to: ' . $ls->param('alt_url_sub_failed')
                if $t; 
            if(
				$ls->param('use_alt_url_sub_failed')      == 1 
			){ 
                        
                my $qs = ''; 
                warn '>>>> >>>> >>>> alt_url_sub_failed_w_qs set to: ' . $ls->param('alt_url_sub_failed_w_qs')
                    if $t; 
                    
                if($ls->param('alt_url_sub_failed_w_qs') == 1){ 
                    $qs = 'list=' . $list . '&rm=sub&status=0&email=' . uriescape($email);
                    $qs .= '&errors[]=' . $_ for keys %$errors; 
                    
                }
                warn '>>>> >>>> >>>> redirecting to: ' . $ls->param('alt_url_sub_failed') . $qs
                    if $t; 
                my $r = $self->alt_redirect($ls->param('alt_url_sub_failed'), $qs); 
                $self->test ? return $r : print $fh safely_encode(  $r) and return; 
                
            }else{            
                
                my @list_of_errors = qw(
                    invalid_email
                    invalid_pin
                    mx_lookup_failed
                    subscribed
                    closed_list
                    over_subscription_quota
                    black_listed
                    not_white_listed
                    not_on_sub_confirm_list                    
                );
                
                for(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                        return user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
                        	-test  => $self->test, 
						); 
                         
                    }
                }
                # Fallback.
               return user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
					-test  => $self->test, 
                );
            }            
        }        
    }
    
    
    else{ 
    	if($ls->param('enable_subscription_approval_step') == 1){ 
 			# we go HERE, if subscriptions need to be approved. Got that?S
			$lh->move_subscriber(
                {
                    -email            => $email,
                    -from             => 'sub_confirm_list',
                    -to               => 'sub_request_list', 
	        		-mode             => 'writeover', 
	        		-confirmed        => 1, 
                }
			);
            my $s = $ls->param('html_subscription_request_message');
            require DADA::Template::Widgets; 
            my $r .= DADA::Template::Widgets::wrap_screen(
                         { 
                            -data                     => \$s,
							-with                     => 'list', 
                            -list_settings_vars_param => {-list => $ls->param('list'),},
                            -subscriber_vars_param    => {-list => $ls->param('list'), -email => $email, -type => 'sub_request_list'},
                            -dada_pseudo_tag_filter   => 1, 
                            -vars                     => { email => $email, subscriber_email => $email}, 
                         } 
            ); 
			
			require DADA::App::Messages; 
			DADA::App::Messages::send_generic_email(
				{
					-list    => $ls->param('list'), 
					-headers => { 
						To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $ls->param('list_owner_email') .'>',
					    Subject         => $ls->param('subscription_approval_request_message_subject'), 
					}, 
					-body => $ls->param('subscription_approval_request_message'),
					-tmpl_params => {
						-list_settings_vars_param => {-list => $ls->param('list')},
			            -subscriber_vars_param    => {-list => $ls->param('list'), -email => $email, -type => 'sub_request_list'},
			            -vars                     => {},
					},
					-test => $self->test,
				}
			);
			
			e_print($r);
			return;  
		}
		else { 
		
			my $new_pass    = ''; 
	        my $new_profile = 0; 
			my $sess_cookie = undef;
			my $sess        = undef; 
			
        	if($mail_your_subscribed_msg == 0){ 
                           warn '>>>> >>>> $mail_your_subscribed_msg is set to: ' . $mail_your_subscribed_msg
                    if $t; 
        
                # We can do an remove from confirm list, and a add to the subscribe 
		        # list, but why don't we just *move* the darn subscriber? 
                # (Basically by updating the table and changing the, "list_type" column. 
		        # Easy enough for me.             
                
                warn '>>>> >>>> Moving subscriber from "sub_confirm_list" to "list" '
                    if $t; 
                    
                $lh->move_subscriber(
                    {
                        -email            => $email,
                        -from             => 'sub_confirm_list',
                        -to               => 'list', 
		        		-mode             => 'writeover', 
		        		-confirmed        => 1, 
                    }
                );
				
		        if(
		           $DADA::Config::PROFILE_OPTIONS->{enabled} == 1 && 
		           $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/
		        ){ 
		        	# Make a profile, if needed, 
		        	require DADA::Profile; 
		        	my $prof = DADA::Profile->new({-email => $email}); 
		        	if(!$prof->exists){ 
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
					if($sess->is_logged_in){	
						my $sess_email = $sess->get;
						if ($sess_email eq $email){ 
							#...
						}
						else { 
							$sess->logout; 
							$sess_cookie = $sess->_login_cookie({-email => $email});
						}
					}
					else { 
						$sess_cookie = $sess->_login_cookie({-email => $email});
				    }
				}
                warn '>>>> >>>> send_sub_success_email is set to: ' . $ls->param('send_sub_success_email')
                    if $t; 
                    
                if($ls->param('send_sub_success_email') == 1){                                             
        
                    warn '>>>> >>>> >>>> sending subscribed message'
                        if $t; 
                    require DADA::App::Messages; 
                    DADA::App::Messages::send_subscribed_message(
		        		{
		        			-list         => $list, 
                            -email        => $email, 
                            -ls_obj       => $ls,
		        			-test         => $self->test, 
		        			-vars         => {
		        								new_profile        => $new_profile, 
		        								'profile.email'    =>  $email, 
		        								'profile.password' =>  $new_pass,
		        								
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
        
                warn 'send_newest_archive set to: ' . $ls->param('send_newest_archive')
                    if $t; 
                    
                if($ls->param('send_newest_archive') == 1){ 
                    
                    warn 'Sending newest archive.'
                        if $t; 
                    require DADA::App::Messages;
                    DADA::App::Messages::send_newest_archive(
		        		{
		        		-list         => $list, 
                        -email        => $email, 
                        -ls_obj       => $ls, 
                        -test         => $self->test,
                    	}
		        	);                                   
                }
        
        
        	}else{ 
        
                warn '>>>> >>> >>> Sending: "Mailing List Confirmation - Already Subscribed" message' 
                    if $t; 
                
                require DADA::App::Messages;
                DADA::App::Messages::send_you_are_already_subscribed_message(		
                	{
                    	-list         => $list, 
	                    -email        => $email, 
	            		-test         => $self->test, 
                	}
		        );
        	}
        
        	if($args->{-html_output} != 0){    
        
                if(
		        	$ls->param('use_alt_url_sub_success') == 1
		        ){
        
                    my $qs = ''; 
                    if($ls->param('alt_url_sub_success_w_qs') == 1){ 
                        $qs = 'list=' . $list . '&rm=sub&status=1&email=' . uriescape($email); 
                    }
                    warn 'redirecting to: ' . $ls->param('alt_url_sub_success') . $qs
                        if $t; 
                    	
		        		my $r = $self->alt_redirect($ls->param('alt_url_sub_success'), $qs); 
                    	$self->test ? return $r : print $fh safely_encode(  $r) and return;
                    
                }else{        
                    
                    warn 'Printing out, Subscription Successful screen' 
                        if $t; 
                    
			
                   my $s = $ls->param('html_subscribed_message');
                   require DADA::Template::Widgets; 
                   my $r .= DADA::Template::Widgets::wrap_screen(
                                { 
                                   -data                     => \$s,
								   -with                     => 'list', 
								   -wrapper_params           => { 
										-header_params => { 
											-cookie => [$sess_cookie],
										},
										-prof_sess_obj => $sess,
									},
                                   -list_settings_vars_param => {-list => $ls->param('list'),},
                                   -subscriber_vars_param    => {-list => $ls->param('list'), -email => $email, -type => 'list'},
                                   -dada_pseudo_tag_filter   => 1, 
                                   -vars                     => { email => $email, subscriber_email => $email}, 
                                } 
                   ); 
                            
                    $self->test ? return $r : print $fh safely_encode(  $r) and return; 
        
                }
        	} 
        }
    }
}




sub unsubscribe { 

    my $self = shift; 
    my ($args) = @_; 
    
	warn 'Starting Unsubscription.' 
        if $t;

    require DADA::Template::HTML;
    
    croak if ! $args->{-cgi_obj}; 
    
    if(! exists($args->{-html_output})){ 
        $args->{-html_output} = 1; 
    }
        
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }
	# do not like this. 
	if(! exists($args->{-no_auto_config})){ 
		$args->{-no_auto_config} = 0; 
	}
    my $fh = $args->{-fh}; 
    
    
    
    my $q     = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = lc_email( strip ( xss_filter( $q->param( 'email' ) ) ) ); 
       
    my $pin   = xss_filter($q->param('pin')); 
    
    # If the list doesn't exist, don't go through the process, 
    # Just go to the default page, 
    # Set the flavor to, "unsubscribe"
    # And give a word out that the list ain't there: 
    
    if($args->{-html_output} != 0){ 
    
        if(check_if_list_exists(-List => $list) == 0){     
           my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1&set_flavor=u'); 
           $self->test ? return $r : print $fh safely_encode(  $r) and return;       
        }
    
        # If the list is there, 
        # but there's no email already filled out, 
        # state that an email needs to be filled out
        # and show the list page. 
        
        if (!$email){                                    

            my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=u'); 
            $self->test ? return $r : print $fh safely_encode(  $r) and return;
        }

    }
   
    require DADA::MailingList::Settings; 
    
   
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 

    require DADA::MailingList::Subscribers;  
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
            
    # Basically, if double opt out is turn off, 
    # make up a pin
    # and confirm the unsub from there
    # This *still* does error check the unsub request
    # just in a different place. 
  
  	my $skip_unsub_confirm_if_logged_in = 0; 
	if($ls->param('skip_unsub_confirm_if_logged_in')){
		require DADA::Profile::Session; 
		my $sess = DADA::Profile::Session->new; 
		if($sess->is_logged_in){	
			my $sess_email = $sess->get;
			if ($sess_email eq $email){ 
				# something... 
				$skip_unsub_confirm_if_logged_in = 1;
			}
		}
	}
	
    if(
		(
		$ls->param('unsub_confirm_email')       == 0 || 
		$skip_unsub_confirm_if_logged_in == 1
		)
		&&
		$args->{-no_auto_config}         == 0 
	){  
        warn 'skipping the unsubscription process and going straight to the confirmation process'
            if $t;
    
        # This is... slightly weird.
        $args->{-cgi_obj}->param('pin', DADA::App::Guts::make_pin(-Email => $email, -List => $list));  
    
		warn 'adding, ' . $email . ' to unsub_confirm_list'
			if $t; 
		# This will error out, if '$email' is not a valid email address. Strangely enough!
        $lh->add_subscriber(
            {
                -email         => $email, 
                -type          => 'unsub_confirm_list', 
            }
        );
        
        
        warn 'going to unsub_confirm()'
			if $t; 			
        return $self->unsub_confirm(
            {
                -html_output => $args->{-html_output}, 
                -cgi_obj     => $args->{-cgi_obj},
            }
        );
     }       
 
    # If there's already a pin, 
    # (that we didn't just make) 
    # Confirm the unsubscription

    if($pin && $args->{-no_auto_config}  == 0 ){
        return $self->unsub_confirm({-html_output => $args->{-html_output}, -cgi_obj =>  $args->{-cgi_obj}}); #we'll change this one later...
    }

    my ($status, $errors) = $lh->unsubscription_check(
								{
									-email => $email, 
									-skip => ['no_list']
								}
							);
    if($t){ 
        if($status == 0){ 
            warn '"' . $email . '" failed unsubscription_check(). Details: '; 
            for(keys %$errors){ 
                warn 'Error: ' . $_ . ' => ' . $errors->{$_}; 
            }
        }
        else { 
            warn '"' . $email . '" passed unsubscription_check()'; 
        }
    }


    # send you're already unsub'd message? 
	# First, only one error and is the error that you're not sub'd?
    my $send_you_are_not_subscribed_email = 0;
    if (   $ls->param('email_you_are_not_subscribed_msg') == 1
        && $status == 0
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
    if($status == 0){ 
    	
		warn '$status: ' . $status if $t; 
        if($args->{-html_output} != 0){ 
        
            # URL redirect?
            if(
				$ls->param('use_alt_url_unsub_confirm_failed') == 1 
			){ 
                
                my $qs = ''; 
                # With a query string?
                if($ls->param('alt_url_unsub_confirm_failed_w_qs') == 1){ 
                    $qs = 'list=' . $list . '&rm=unsub_confirm&status=0&email=' . uriescape($email);
                    $qs .= '&errors[]=' . $_ for keys %$errors; 
                }
                my $r = $self->alt_redirect($ls->param('alt_url_unsub_confirm_failed'), $qs);
                $self->test ? return $r : print $fh safely_encode(  $r) and return; 
                
            }else{        
                # If not, show the correct error screen. 
                ### invalid_email -> unsub_invalid_email 
                
                my @list_of_errors = qw(
                    invalid_email
                    not_subscribed
                    settings_possibly_corrupted
                    already_sent_unsub_confirmation
                ); 
                for(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                    
                        # Special Case. 
                        $_ = 'unsub_invalid_email' 
                            if $_ eq 'invalid_email';
                       # warn "showing error, $_"; 
                        return user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
							-test  => $self->test, 
                        ); 
                    }
                }

                # Fallback
                return user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
					-test  => $self->test, 
                );    
            }
        }
    }else{    # Else, the unsubscribe request was OK, 
     
		# Are we just pretending thing went alright? 
		if($send_you_are_not_subscribed_email == 1){ 
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
	        DADA::App::Messages::send_unsub_confirmation_message(
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
					-email =>$email, 
					-type  => 'unsub_confirm_list'
				}
			);
	        $lh->add_subscriber(
	            {
	                -email => $email,
	                -type  => 'unsub_confirm_list',
	            }
	        );
		}
        
        if($args->{-html_output} != 0){ 
        
            # Redirect?
            if(
                $ls->param('use_alt_url_unsub_confirm_success') == 1 
            ){ 
            
                # With... Query String?
                my $qs = ''; 
                if($ls->param('alt_url_unsub_confirm_success_w_qs') == 1){ 
                    $qs = 'list=' . $list . '&rm=unsub_confirm&status=1&email=' . uriescape($email); 
                }
                my $r = $self->alt_redirect($ls->param('alt_url_unsub_confirm_success'), $qs);
                $self->test ? return $r : print $fh safely_encode(  $r) and return; 
                
            }else{ 
               my $s = $ls->param('html_unsub_confirmation_message');
               require DADA::Template::Widgets; 
               my $r = DADA::Template::Widgets::wrap_screen({ 
                                                       -data                     => \$s,
													   -with                     => 'list', 
                                                       -list_settings_vars_param => {-list => $ls->param('list'),},
                                                       -subscriber_vars_param    => {-list => $ls->param('list'), -email => $email, -type => 'list'},
                                                       -dada_pseudo_tag_filter  => 1, 
                                                       -vars                    => { email => $email, subscriber_email => $email}, 
            
               } 
               ); 
				$self->test ? return $r : print $fh safely_encode(  $r) and return;
				
            }                 
        }
    }
}




sub unsub_confirm { 
	

    my $self = shift; 
    my ($args) = @_; 

	warn 'Starting Unsubscription Confirmation.' 
        if $t;
    
    require DADA::Template::HTML;
    
    croak if ! $args->{-cgi_obj}; 
    
    if(! exists($args->{-html_output})){ 
        $args->{-html_output} = 1; 
    }
     
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};
    
   
    my $q     = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = lc_email( strip ( xss_filter( $q->param( 'email' ) ) ) );
    my $pin   = xss_filter($q->param('pin')); 
    
    if($args->{-html_output} != 0){ 
        if(check_if_list_exists(-List => $list) == 0){
            
            warn 'redirecting to: ' . $DADA::Config::PROGRAM_URL . '?error_invalid_list=1&set_flavor=u'
                if $t; 
                
           my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1&set_flavor=u'); 
		   $self->test ? return $r : print $fh safely_encode(  $r) and return;
		
        }
    }
    
    require DADA::MailingList::Subscribers;  
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    require DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    
    my($status, $errors) = $lh->unsubscription_check(
								{
                                 	-email => $email, 
                                 	-skip  => ['already_sent_unsub_confirmation'],
                           		}
							);
    
    if($t){ 
        if($status == 0){ 
            warn '"' . $email . '" failed unsubscription_check(). Details: '; 
            for(keys %$errors){ 
                warn 'Error: ' . $_ . ' => ' . $errors->{$_}; 
            }
        }
        else { 
            warn '"' . $email . '" passed unsubscription_check()'; 
        }
    }


    if($args->{-html_output} != 0){ 
        if($errors->{no_list} == 1){ 
            return user_error(
                -List  => $list, 
                -Error => "no_list", 
                -Email => $email
                -test  => $self->test, 
				# no -fh?
            );
        }
    }
    
    if(check_email_pin(-Email => $email, -List  => $list, -Pin   => $pin) == 0){ 
         $status = 0; 
         $errors->{invalid_pin} = 1; 
         
         warn '"' . $email . '" invalid pin found!'
            if $t; 
    }

	# send you're already unsub'd message? 
	# First, only one error and is the error that you're not sub'd?
	my $send_you_are_not_subscribed_email = 0;
	if (   $ls->param('email_you_are_not_subscribed_msg') == 1
	    && $status == 0
	    && scalar( keys %$errors ) == 1
	    && $errors->{not_subscribed} == 1 )
	{

	    # Changed the status to, "1" BUT,
	    $status = 1;

	    # Mark that we have to send a special email.
	    $send_you_are_not_subscribed_email = 1;
		
		# We probably have to do this, so as not to have this error on us
		# (potentially?)
		my $rm_status = $lh->remove_subscriber(
			{
				-email =>$email, 
				-type  => 'unsub_confirm_list'
			}
		);
 
        return $self->unsubscribe(
            {
                -html_output    => $args->{-html_output}, 
                -cgi_obj        => $args->{-cgi_obj},
				-no_auto_config => 1, 
            }
        );
	}
	else {

	    # ...
	}
	



    
    # My last check - are they currently on the Unsubscription confirmation list?!
    if($lh->check_for_double_email(-Email => $email,-Type  => 'unsub_confirm_list')  == 0){ 
        $status = 0; 
        $errors->{not_on_unsub_confirm_list} = 1; 
        warn ' $errors->{not_on_unsub_confirm_list} set to 1'
            if $t; 
    }
    else {
    	
		warn 'removing, ' . $email . ' from unsub_confirm_list'
			if $t; 
        my $rm_status = $lh->remove_subscriber(
			{ 
	            -email => $email, 
	            -type  => 'unsub_confirm_list'
             }
		);    
                    
    }

    
    if($status == 0){ 
    
        warn 'Status has been set to, "0"'
            if $t; 
            
        if($args->{-html_output} != 0){ 
    
            if(
                $ls->param('use_alt_url_unsub_failed') == 1
            ){ 
            
                my $qs = ''; 
                if($ls->param('alt_url_unsub_failed_w_qs') == 1){ 
                    $qs = 'list=' . $list . '&rm=unsub&status=0&email=' . uriescape($email); 
                    $qs .= '&errors[]=' . $_ for keys %$errors; 
                }
                warn 'Redirecting to: ' . $ls->param('alt_url_unsub_failed') . $qs 
                    if $t; 
                    
                my $r = $self->alt_redirect($ls->param('alt_url_unsub_failed'), $qs);
                $self->test ? return $r : print $fh safely_encode(  $r) and return; 
                    
            }else{ 
            
                my @list_of_errors = qw(
                    invalid_pin
                    not_subscribed
                    invalid_email
                    not_on_unsub_confirm_list
                    settings_possibly_corrupted
                    
                    
                ); 
                for(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                    
                        # Special Case. 
                        $_ = 'unsub_invalid_email' 
                            if $_ eq 'invalid_email';
                        
                        warn 'Showing user_error: ' . $_
                            if $t; 

                        return user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
							-test  => $self->test, 
                        ); 
                    }
                }
                # Fallback
                warn "Fallback error!" if $t; 
                return user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
					-test  => $self->test, 
                );    
            }
            
        }
    }else{ 
 
        warn 'Status is set to, "1"'
            if $t; 
        
        
		
        if(
            $ls->param('black_list')               == 1 && 
            $ls->param('add_unsubs_to_black_list') == 1

        ){
        	if($lh->check_for_double_email(-Email => $email, -Type  => 'black_list')  == 0){ 
				# Not on, already: 
				$lh->add_subscriber(
				    {
				        -email => $email,  
						-type => 'black_list', 
						-dupe_check    => {
											-enable  => 1, 
											-on_dupe => 'ignore_add',  
	                					},
				    }
				);
			}

        }
             
    	warn 'removing, ' . $email . ' from, "list"'
			if $t; 
			
		# This is the only place where we're removing from, 'list' that I can find 
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
        
        if($ls->param('send_unsub_success_email') == 1){ 
	
            require DADA::App::Messages; 
            DADA::App::Messages::send_unsubscribed_message(
				{
					-list      => $list,
                    -email     => $email,
                    -ls_obj    => $ls,
					-test      => $self->test,
				}	
			); 

        }

        if($args->{-html_output} != 0){ 
            if(
                $ls->param('use_alt_url_unsub_success') == 1
              ){ 
                my $qs = ''; 
                if($ls->param('alt_url_unsub_success_w_qs') == 1){ 
                    $qs = 'list=' . $list . '&rm=unsub&status=1&email=' . uriescape($email);  
                }
                my $r = $self->alt_redirect($ls->param('alt_url_unsub_success'), $qs);
                $self->test ? return $r : print $fh safely_encode(  $r) and return;
            
            }else{                
               my $s = $ls->param('html_unsubscribed_message');
               require DADA::Template::Widgets; 
               my $r =  DADA::Template::Widgets::wrap_screen(
					{ 
  						-data                     => \$s,
						-with                     => 'list', 
						-list_settings_vars_param => {-list => $ls->param('list')},
						-dada_pseudo_tag_filter   => 1, 
						-subscriber_vars          => {'subscriber.email' => $email},
						}
				); 
                $self->test ? return $r : print $fh safely_encode(  $r) and return; 

            }
        }
    } 
}



sub alt_redirect {

    my $self = shift;
    my $url  = shift;
    my $qs   = shift;

    require CGI;
    my $q = CGI->new;
       $q->charset($DADA::Config::HTML_CHARSET);

    $url = strip($url);

    if ( isa_url($url) ) {

        #...
    }
    else {
        $url = 'http://' . $url;
    }

    return $q->redirect( $url . '?' . $qs );
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
 
 # Awkwardly use CGI.pm's param() method to stuff paramaters for 
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
This is the code that's hit, basically when someone fills out a subscription form on a page of a website, 
but it can be used in scripts outside of Dada Mail to perform similar actions. Dada Mail does ship with a few
examples of this, which we'll get into, soon enough. 

=head1 Public Methods

=head2 Initializing

=head2 new

 my $das = DADA::App::Subscriptions->new; 

C<new> takes no arguments. 

=head2 test

 $das->test(1);

Passing, C<test> a value of, C<1> will turn this module into testing mode. Usually (and also, awkwardly) this module will 
perform the needed job of printing any HTML needed to complete the request you've given it. If testing mode is on, the HTML will 
merely be returned to you. 

Email messages will also be printed to a text file, instead of being sent out. 

You probably only want to use, C<test> if you're actually I<testing>, via the unit tests that ship with Dada Mail. 

=head2 subscribe

 # Awkwardly use CGI.pm's param() method to stuff paramaters for 
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

C<subscribe> requires one paramater, C<-cgi-obj>, which needs to be a CGI.pm object 
(a CGI.pm param-compatible module won't work, but we may work on that) THAT IN ITSELF has two paramaters: 

=over

=item * list

holding the list shortname you want to work with

=item * email

holding the email address you want to work with

=back

C<-html_output> is an optional paramater, if set to, C<0>, this method will not print out the HTML 
user message telling the user if everything went well (or not). 

On success, this method will return, C<undef>

=head3 Notes on awkwardness of the API

It's quite apparrent that the API of this method is not very well thought-out. The history of this method 
started as a subroutine in the main, C<mail.cgi> script itself that overgrown its bounds considerably, but didn't 
receive a re-design of its API. Also, returning, C<undef> on success is also not very helpful. 

These types of issues will be addressed in later versions of Dada Mail, but not anytime before v4.4.0 of the application. 
We will make a very obvious note in the changelog about it. We promise. Ok? Ok. 

=head3 Examples

This method is the best way to hook into Dada Mail's subscription API, but its awkward API can leave many head-scratching.
Currently, the best way to understand how to use it, would be to see examples of its usage. 

The B<Subscription Cookbook> contains a small, command line utility script that wraps this method into something a little easier to work with
and also has several examples of using the method, including augmented form handling scripts and a proof-of-concept SOAP server/client(s):

http://dadamailproject.com/support/documentation/COOKBOOK-subscriptions.pod.html

=head1 AUTHOR

Justin Simoni http://dadamailproject.com

=head1 LICENCE AND COPYRIGHT

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 


