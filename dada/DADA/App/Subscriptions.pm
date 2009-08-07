package DADA::App::Subscriptions;

use lib qw(../../ ../../perllib);


use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 

use Carp qw(carp croak); 


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
    
    my $dbi_handle = undef; 
    if(exists($args->{-dbi_handle})){ 
        $dbi_handle = $args->{-dbi_handle};
    }
    
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }

    my $fh = $args->{-fh}; 
    
    my $q     = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = xss_filter($q->param('email')); 
       $email = DADA::App::Guts::strip($email); 

    my $list_exists = DADA::App::Guts::check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle);
	my $ls          = undef; 
	my $li          = undef; 
	
	
	
	require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle;
	
	
	
	if($list_exists){ 
		$ls = DADA::MailingList::Settings->new({-list => $list}); 
		$li = $ls->get();
	}	
    if($args->{-html_output} == 1){
	
	         
        if($list_exists == 0){ 
            # Test sub-subscribe-redirect-error_invalid_list
			my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1');  
			$self->test ? return $r : print $fh $r and return; 
        }
		else { 
			
			 if (!$email){ 
					if($li->{use_alt_url_sub_confirm_failed} != 1) { 
						# Test sub-subscribe-redirect-error_no_email
						# This is just so we don't use the actual error screen.
				  		my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=s'); 
						$self->test ? return $r : print $fh $r and return; 
					}
		        }
			
		}
	}
	else { 
		# ...?!?!
	}
	


    
    require DADA::MailingList::Subscribers;         
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
    
    my $fields = {}; 
    foreach(@{$lh->subscriber_fields}){ 
		if(defined($q->param($_))){ 
        	$fields->{$_} = xss_filter($q->param($_)); 
		}
	}
    
    
    $email = lc_email($email);

    my ($status, $errors) = $lh->subscription_check(
								{
                                -email => $email,   
   								-type  => 'list', 

                                    ($li->{allow_blacklisted_to_subscribe} == 1) ? 
                                    (
                                    -skip  => ['black_listed'], 
                                    ) : (),
 								}
                             ); 
	
	# This is kind of strange... 
	my $skip_sub_confirm_if_logged_in = 0; 
	
	
	if($status == 1){ 
		

		my $skip_sub_confirm_if_logged_in = 0; 
		if($li->{skip_sub_confirm_if_logged_in}){
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
			$li->{no_confirm_email}    == 0 || 
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
     
     if($li->{email_your_subscribed_msg} == 1){ 
        
        if($errors->{subscribed} == 1){ 
        
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
				$li->{use_alt_url_sub_confirm_failed} == 1 &&
			    isa_url($li->{alt_url_sub_confirm_failed})
			){ 
            
                my $qs = ''; 
                if($li->{alt_url_sub_confirm_failed_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=sub_confirm&status=0&email=' . DADA::App::Guts::uriescape($email);
                    $qs .= '&error=' . $_ foreach keys %$errors; 
                    $qs .= '&' . $_ . '=' . uriescape($fields->{$_}) foreach keys %$fields; 
                }
                
                my $r = $q->redirect(-uri => $li->{alt_url_sub_confirm_failed} . $qs); 
				$self->test ? return $r : print $fh $r and return; 

            }else{

                my @list_of_errors = qw(
                    invalid_email
                    mx_lookup_failed
                    subscribed
                    closed_list
                    over_subscription_quota
                    black_listed
                    not_white_listed
                    settings_possibly_corrupted
                    already_sent_sub_confirmation
                );
                
                foreach(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                        user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
                        ); 
                        return; 
                    }
                }

                # Fallback
                user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
                );    
                return;
            }            
        }
        
    }else{ 
        

        # The idea is, we'll save the information for the subscriber in the confirm list, and then 
        # move the info to the actual subscription list, 
        # And then remove the information from the confirm list, when we're all done. 
        
        my $rm_status = $lh->remove_from_list(
                            -Email_List =>[$email], 
                            -Type       => 'sub_confirm_list',
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
            
			if($errors->{subscribed} == 1 && 
			   $li->{no_confirm_email} == 0
			){
				# 3.0.x code: 
				$args->{-cgi_obj}->param('pin', DADA::App::Guts::make_pin(-Email => $email));  
				# 3.1 code: 
				#$args->{-cgi_obj}->param('pin', DADA::App::Guts::make_pin(-Email => $email, -List => $list));  
				$self->confirm(
		            {
		                -html_output => $args->{-html_output}, 
		                -cgi_obj     => $args->{-cgi_obj},
		            },
		        );

		        return;
			}

            
        }
        
        
        if($args->{-html_output} != 0){         
            if(
                $li->{use_alt_url_sub_confirm_success}       ==  1 && 
                isa_url($li->{alt_url_sub_confirm_success})
              ){ 
                my $qs = ''; 
                if($li->{alt_url_sub_confirm_success_w_qs} == 1){ 
                    $qs  = '?list=' . $list . '&rm=sub_confirm&status=1&email=' . DADA::App::Guts::uriescape($email); 
                    $qs .= '&' . $_ . '=' . uriescape($fields->{$_}) foreach keys %$fields; 
                    
                }
                my $r = $q->redirect(-uri => $li->{alt_url_sub_confirm_success} . $qs); 

      			$self->test ? return $r : print $fh $r and return; 

            }else{ 
    			
				my $r = ''; 
                $r .= DADA::Template::HTML::list_template(
                               -Part  => "header",
                               -Title => "Please Confirm Your Subscription",
                               -List  => $li->{list}
                          );
                               
				my $s; 
				$s = $li->{html_confirmation_message}; 

				require DADA::Template::Widgets; 
				$r .=   DADA::Template::Widgets::screen(
				{ 
					-data                     => \$s,
					-list_settings_vars_param => {-list => $li->{list},},
					-subscriber_vars_param    => {-list => $li->{list}, -email => $email, -type => 'sub_confirm_list'},
					-dada_pseudo_tag_filter   => 1,             
				} 

				); 
                
                $r .= DADA::Template::HTML::list_template(
                               -Part      => "footer", 
                               -List      => $li->{list},
                               -Site_Name => $li->{website_name}, 
                               -Site_URL  => $li->{website_url},
                               );
            	# Test: sub_confirm-sub_confirm_success
				$self->test ? return $r : print $fh $r and return; 
                 
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
    
    my $dbi_handle = undef; 
    if(exists($args->{-dbi_handle})){ 
        $dbi_handle = $args->{-dbi_handle};
        warn '>>>> dbi_handle passed.' 
            if $t; 
    }
    
    my $q = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = xss_filter($q->param('email'));     
       $email = DADA::App::Guts::strip($email); 
        
    my $pin   = xss_filter($q->param('pin')); 

    warn '$list: ' . $list
        if $t; 
    warn '$email: ' . $email
        if $t;
    warn '$pin: ' . $pin
        if $t; 
        
    my $list_exists = DADA::App::Guts::check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle);
    
	require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle;

		my $ls = undef; 
		my $li = undef; 
	
	if($list_exists == 1){ 
		$ls = DADA::MailingList::Settings->new({-list => $list}); 
	    $li = $ls->get();
	}
	
    if($args->{-html_output} == 1){ 
	
        if($list_exists == 0){ 
            
            warn '>>>> >>>> list doesn\'t exist. Redirecting to default screen.'
                if $t; 
            my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1'); 
			$self->test ? return $r : print $fh $r and return; 
        }
		else { 
			# Again!
			
	        if (!$email){ 	
				if($li->{use_alt_url_sub_failed} != 1) { 
	            	warn '>>>> >>>> no email passed. Redirecting to list screen'
		                if $t; 
		            my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=s'); 
		            $self->test ? return $r : print $fh $r and return;
				}	
			}
        }
    }
    
    
    $email = lc_email($email); 
           
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    warn '$li->{captcha_sub} set to: ' . $li->{captcha_sub}
        if $t; 
    
    if($li->{captcha_sub} == 1){
	 
		my $can_use_captcha = 0; 
		eval { require DADA::Security::AuthenCAPTCHA; };
		if(!$@){ 
			$can_use_captcha = 1;        
		}

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
      
				my $r = ''; 
      
	             $r .= DADA::Template::HTML::list_template(
	                -Part  => "header",
	                -Title => "Subscription Almost Complete",
	                -List => $li->{list},
	            );
	            require DADA::Template::Widgets;
	           	$r .=  DADA::Template::Widgets::screen(
	                                                {
	                                                  -screen                   => 'confirm_captcha_step_screen.tmpl', 
	                                                  -list_settings_vars_param => {-list => $li->{list}},
	                                                  -subscriber_vars_param    => {-list => $li->{list}, -email => $email, -type => 'sub_confirm_list'},
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
	                                                        email        => xss_filter($q->param('email')), 
	                                                        pin          => xss_filter($q->param('pin')), 
	                                                        captcha_auth => xss_filter($captcha_auth),        
                                                        
	                                                          },
	                                                      },
                                                      

	                                                    );
	            $r .=  DADA::Template::HTML::list_template(
	                -Part      => "footer", 
	                -List      => $li->{list},
	                -Site_Name => $li->{website_name},
	                -Site_URL  => $li->{website_url},
	            );                                          
    
				$self->test ? return $r : print $fh $r and return; 

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
	                                     ($li->{allow_blacklisted_to_subscribe} == 1) ? 
	                                     (
	                                     -skip  => ['black_listed', 'already_sent_sub_confirmation'], 
	                                     ) : 
	                                     (
	                                     -skip => ['already_sent_sub_confirmation'], 
	                                     ),
	 								}
                              );
                                                
     warn 'subscription check gave back status of: ' . $status
        if $t; 
     if($t){ 
        foreach(keys %$errors){ 
            warn '>>>> >>>> ERROR: ' . $_ . ' => ' . $errors->{$_}
                if $t; 
        }
     }
     
     my $mail_your_subscribed_msg = 0; 
     warn '$li->{email_your_subscribed_msg} is set to: ' . $li->{email_your_subscribed_msg}
        if $t; 
        
     if($li->{email_your_subscribed_msg} == 1){ 
     
        warn '>>>> $errors->{subscribed} set to: ' . $errors->{subscribed}
            if $t; 
            
        if($errors->{subscribed} == 1){ 
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
	            user_error(
	                -List  => $list, 
	                -Error => "no_list",
	                -Email => $email,
	                -fh    => $args->{-fh},
	            );
	            return;            
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

            warn '>>>> >>>> $li->{use_alt_url_sub_failed} set to: ' . $li->{use_alt_url_sub_failed}
                if $t; 
            warn '>>>> >>>> ($li->{alt_url_sub_failed} set to: ' . $li->{alt_url_sub_failed} 
                if $t; 
            if(
				$li->{use_alt_url_sub_failed}      == 1 && 
				isa_url($li->{alt_url_sub_failed})
			){ 
                        
                my $qs = ''; 
                warn '>>>> >>>> >>>> $li->{alt_url_sub_failed_w_qs} set to: ' . $li->{alt_url_sub_failed_w_qs}
                    if $t; 
                    
                if($li->{alt_url_sub_failed_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=sub&status=0&email=' . DADA::App::Guts::uriescape($email);
                    $qs .= '&errors=' . $_ foreach keys %$errors; 
                    
                }
                warn '>>>> >>>> >>>> redirecting to: ' . $li->{alt_url_sub_failed} . $qs
                    if $t; 
                my $r = $q->redirect(-uri => $li->{alt_url_sub_failed} . $qs); 
                $self->test ? return $r : print $fh $r and return; 
                
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
                
                foreach(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                        user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
                        ); 
                        return; 
                    }
                }
                # Fallback.
                user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
                );
                return;
                
            }            
        }        
    }
    
    
    else{ 
    
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
			
			my $new_pass    = ''; 
			my $new_profile = 0; 
			if(
			   $DADA::Config::PROFILE_ENABLED == 1 && 
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
							-unecrypted_password  => $new_pass,
							-activated => 1, 
						}
					); 
				}
				# / Make a profile, if needed, 
			}
            warn '>>>> >>>> $li->{send_sub_success_email} is set to: ' . $li->{send_sub_success_email}
                if $t; 
                
            if($li->{send_sub_success_email} == 1){                                             
    
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
    
            warn '$li->{send_newest_archive} set to: ' . $li->{send_newest_archive}
                if $t; 
                
            if($li->{send_newest_archive} == 1){ 
                
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
				$li->{use_alt_url_sub_success} == 1 &&
				isa_url($li->{alt_url_sub_success})
			){

                my $qs = ''; 
                if($li->{alt_url_sub_success_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=sub&status=1&email=' . DADA::App::Guts::uriescape($email); 
                }
                warn 'redirecting to: ' . $li->{alt_url_sub_success} . $qs
                    if $t; 
                	
					my $r = $q->redirect(-uri => $li->{alt_url_sub_success} . $qs); 
                	$self->test ? return $r : print $fh $r and return;
                
            }else{        
                
                warn 'Printing out, Subscription Successful screen' 
                    if $t; 
                
				my $r = ''; 
				$r .=  DADA::Template::HTML::list_template(
                               -Part  => "header",
                               -Title => "Subscription Successful",
                               -List  => $li->{list},
                      );
                
                
               my $s = $li->{html_subscribed_message};
               require DADA::Template::Widgets; 
               $r .= DADA::Template::Widgets::screen(
                            { 
                               -data                     => \$s,
                               -list_settings_vars_param => {-list => $li->{list},},
                               -subscriber_vars_param    => {-list => $li->{list}, -email => $email, -type => 'list'},
                               -dada_pseudo_tag_filter   => 1, 
                               -vars                     => { email => $email, subscriber_email => $email}, 
                            } 
               ); 
                
               $r .= DADA::Template::HTML::list_template(
                               -Part      => "footer", 
                               -List      => $li->{list},
                     );

                $self->test ? return $r : print $fh $r and return; 

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
    
    my $dbi_handle = undef; 
    if(exists($args->{-dbi_handle})){ 
        $dbi_handle = $args->{-dbi_handle};
    }
    
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh}; 
    
    
    
    my $q     = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = xss_filter($q->param('email')); 
       $email = DADA::App::Guts::strip($email); 
       
    my $pin   = xss_filter($q->param('pin')); 
    
    # If the list doesn't exist, don't go through the process, 
    # Just go to the default page, 
    # Set the flavor to, "unsubscribe"
    # And give a word out that the list ain't there: 
    
    if($args->{-html_output} != 0){ 
    
        if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 0){     
           my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1&set_flavor=u'); 
           $self->test ? return $r : print $fh $r and return;       
        }
    
        # If the list is there, 
        # but there's no email already filled out, 
        # state that an email needs to be filled out
        # and show the list page. 
        
        if (!$email){                                    

            my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=u'); 
            $self->test ? return $r : print $fh $r and return;
        }

    }
   
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 
    
   
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get(); 

    require DADA::MailingList::Subscribers; 
           $DADA::MailingList::Subscribers::dbi_obj = $dbi_handle; 
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
            
    # Basically, if double opt out is turn off, 
    # make up a pin
    # and confirm the unsub from there
    # This *still* does error check the unsub request
    # just in a different place. 
  
  	my $skip_unsub_confirm_if_logged_in = 0; 
	if($li->{skip_unsub_confirm_if_logged_in}){
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
		$li->{unsub_confirm_email}       == 0 || 
		$skip_unsub_confirm_if_logged_in == 1
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
        $self->unsub_confirm(
            {
                -html_output => $args->{-html_output}, 
                -cgi_obj     => $args->{-cgi_obj},
            }
        );
        return;
     }       
 
    # If there's already a pin, 
    # (that we didn't just make) 
    # Confirm the unsubscription
    if($pin){
        $self->unsub_confirm({-html_output => $args->{-html_output}, -cgi_obj =>  $args->{-cgi_obj}}); #we'll change this one later...
        return;
    }

    my ($status, $errors) = $lh->unsubscription_check(
								{
									-email => $email, 
									-skip => ['no_list']
								}
							);
        
    # If there's any problems, handle them. 
    if($status == 0){ 
    
        if($args->{-html_output} != 0){ 
        
            # URL redirect?
            if(
				$li->{use_alt_url_unsub_confirm_failed} == 1 && 
				isa_url($li->{alt_url_unsub_confirm_failed})
			){ 
                
                my $qs = ''; 
                # With a query string?
                if($li->{alt_url_unsub_confirm_failed_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=unsub_confirm&status=0&email=' . DADA::App::Guts::uriescape($email); 
                    $qs .= '&errors=' . $_ foreach keys %$errors; 
                }
                my $r = $q->redirect(-uri => $li->{alt_url_unsub_confirm_failed} . $qs);
                $self->test ? return $r : print $fh $r and return; 
                
            }else{        
                # If not, show the correct error screen. 
                ### invalid_email -> unsub_invalid_email 
                
                my @list_of_errors = qw(
                    invalid_email
                    not_subscribed
                    settings_possibly_corrupted
                    already_sent_unsub_confirmation
                ); 
                foreach(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                    
                        # Special Case. 
                        $_ = 'unsub_invalid_email' 
                            if $_ eq 'invalid_email';
                        
                        user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
                        ); 
                        return; 
                    }
                }

                # Fallback
                user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
                );    
                return;
                
                
            }
        }
    }else{    # Else, the unsubscribe request was OK, 
     
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

        
                        
        # It would be neat to have a copy function..., 
        # So I could say: 
        # 
        # $lh->copy_subscriber(
        #        -email => $email, 
        #        -from  => 'list', 
        #        -to    => 'unsub_confirm', 
        #  ); 
       
       my $rm_status = $lh->remove_from_list(
                            -Email_List =>[$email], 
                            -Type       => 'unsub_confirm_list'
                        );
        $lh->add_subscriber(
            {
                -email => $email,
                -type  => 'unsub_confirm_list',
            }
        );
        
        if($args->{-html_output} != 0){ 
        
            # Redirect?
            if(
                $li->{use_alt_url_unsub_confirm_success} == 1 &&
                isa_url($li->{alt_url_unsub_confirm_success})
            ){ 
            
                # With... Query String?
                my $qs = ''; 
                if($li->{use_alt_url_unsub_confirm_success_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=unsub_confirm&status=1&email=' . DADA::App::Guts::uriescape($email); 
                }
                my $r = $q->redirect(-uri => $li->{alt_url_unsub_confirm_success} . $qs);
                $self->test ? return $r : print $fh $r and return; 
                
            }else{ 
            	my $r = ''; 

                $r .= DADA::Template::HTML::list_template(
                           -Part  => "header",
                           -Title => "Please Confirm Your Unsubscription",
                           -List  => $li->{list},
                      );
                # $li->{html_unsub_confirmation_message} =~ s/\[subscriber_email\]/$email/g; 
                # print $fh $li->{html_unsub_confirmation_message}; 
                
               my $s = $li->{html_unsub_confirmation_message};
               require DADA::Template::Widgets; 
               $r .= DADA::Template::Widgets::screen({ 
                                                       -data                     => \$s,
                                                       -list_settings_vars_param => {-list => $li->{list},},
                                                       -subscriber_vars_param    => {-list => $li->{list}, -email => $email, -type => 'list'},
                                                       -dada_pseudo_tag_filter  => 1, 
                                                       -vars                    => { email => $email, subscriber_email => $email}, 
            
               } 
               ); 



 
             	$r .= DADA::Template::HTML::list_template(-Part      => 'footer', 
                            -List      => $li->{list},
                            -Site_Name => $li->{website_name},
                            -Site_URL  => $li->{website_url}
                       );
				$self->test ? return $r : print $fh $r and return;
				
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
    
    my $dbi_handle = undef; 
    if(exists($args->{-dbi_handle})){ 
        $dbi_handle = $args->{-dbi_handle};
    }
    
    if(! exists($args->{-fh})){ 
        $args->{-fh} = \*STDOUT;
    }
    my $fh = $args->{-fh};
    
   
    my $q     = $args->{-cgi_obj}; 
    my $list  = xss_filter($q->param('list')); 
    my $email = xss_filter($q->param('email'));     
       $email = DADA::App::Guts::strip($email); 
        
    my $pin   = xss_filter($q->param('pin')); 
    
    if($args->{-html_output} != 0){ 
        if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 0){
            
            warn 'redirecting to: ' . $DADA::Config::PROGRAM_URL . '?error_invalid_list=1&set_flavor=u'
                if $t; 
                
           my $r = $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?error_invalid_list=1&set_flavor=u'); 
		   $self->test ? return $r : print $fh $r and return;
		
        }
    }
    
    require DADA::MailingList::Subscribers; 
           $DADA::MailingList::Subscribers::dbi_obj = $dbi_handle; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get(); 
    

    
    my($status, $errors) = $lh->unsubscription_check(
								{
                                 	-email => $email, 
                                 	-skip  => ['already_sent_unsub_confirmation'],
                           		}
							);
    
    if($t){ 
        if($status == 0){ 
            warn '"' . $email . '" failed unsubscription_check(). Details: '; 
            foreach(keys %$errors){ 
                warn 'Error: ' . $_ . ' => ' . $errors->{$_}; 
            }
        }
        else { 
            warn '"' . $email . '" passed unsubscription_check()'; 
        }
    }
    
    

    if($args->{-html_output} != 0){ 
        if($errors->{no_list} == 1){ 
            user_error(
                -List  => $list, 
                -Error => "no_list", 
                -Email => $email
                
            );
        }
    }
    
    if(check_email_pin(-Email => $email, -List  => $list, -Pin   => $pin) == 0){ 
         $status = 0; 
         $errors->{invalid_pin} = 1; 
         
         warn '"' . $email . '" invalid pin found!'
            if $t; 
    }
    
    # My last check - are they currently on the UNsubscription confirmation list?!
    if($lh->check_for_double_email(-Email => $email,-Type  => 'unsub_confirm_list')  == 0){ 
        $status = 0; 
        $errors->{not_on_unsub_confirm_list} = 1; 
        warn ' $errors->{not_on_unsub_confirm_list} set to 1'
            if $t; 
    }
    else {
    	
		warn 'removing, ' . $email . ' from unsub_confirm_list'
			if $t; 
        my $rm_status = $lh->remove_from_list(
                        -Email_List =>[$email], 
                        -Type       => 'unsub_confirm_list'
                    );    
                    
    }

    
    if($status == 0){ 
    
        warn 'Status has been set to, "0"'
            if $t; 
            
        if($args->{-html_output} != 0){ 
    
            if(
                $li->{use_alt_url_unsub_failed} == 1 &&
                isa_url($li->{alt_url_unsub_failed})
            ){ 
            
                my $qs = ''; 
                if($li->{alt_url_unsub_failed_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=unsub&status=0&email=' . DADA::App::Guts::uriescape($email); 
                    $qs .= '&errors=' . $_ foreach keys %$errors; 
                }
                warn 'Redirecting to: ' . $li->{alt_url_unsub_failed} . $qs 
                    if $t; 
                    
                my $r = $q->redirect(-uri => $li->{alt_url_unsub_failed} . $qs);
                $self->test ? return $r : print $fh $r and return; 
                    
            }else{ 
            
                my @list_of_errors = qw(
                    invalid_pin
                    not_subscribed
                    invalid_email
                    not_on_unsub_confirm_list
                    settings_possibly_corrupted
                    
                    
                ); 
                foreach(@list_of_errors){ 
                    if ($errors->{$_} == 1){ 
                    
                        # Special Case. 
                        $_ = 'unsub_invalid_email' 
                            if $_ eq 'invalid_email';
                        
                        warn 'Showing user_error: ' . $_
                            if $t; 
                        user_error(
                            -List  => $list, 
                            -Error => $_,            
                            -Email => $email,
                            -fh    => $args->{-fh},
                        ); 
                        return; 
                    }
                }
                # Fallback
                warn "Fallback error!" if $t; 
                user_error(
                    -List  => $list, 
                    -Email => $email,
                    -fh    => $args->{-fh},
                );    
                return;
            }
            
        }
    }else{ 
 
        warn 'Status is set to, "1"'
            if $t; 
        
        
		
        if(
            $li->{black_list}               == 1 && 
            $li->{add_unsubs_to_black_list} == 1

        ){

			# I don't have to do this anymore, since moving/removing a subscriber
			# Will not destroy the profile information... I don't think. 
			## Basically, what I gotta do is make sure that there aren't on the 
			## Blacklist ALREADY, or Baaaaaaad things happen. 
			#
            ## We move, in an attempt to keep the subscription information
            ## Perhaps, they'll be moved back?
            #
            #warn 'Moving email (' . $email .') to blacklist.' 
            #    if $t; 
            #$lh->move_subscriber(
            #
            #    {
            #        -email => $email,  
            #        -from  => 'list',
            #        -to    => 'black_list',
			#		-mode  => 'writeover', 
            #    }
            #);
        	if($lh->check_for_double_email(-Email => $email, -Type  => 'black_list')  == 0){ 
				# Not on, already: 
				$lh->add_subscriber(
				    {
				        -email => $email,  
						-type => 'black_list', 
				    }
				);
			}

        }
        #else { 
             
     		warn 'removing, ' . $email . ' from, "list"'
				if $t; 
            $lh->remove_from_list(
                -Email_List =>[$email], 
                -Type       => 'list'
            );
        
        #}
        
        require DADA::App::Messages; 
        DADA::App::Messages::send_owner_happenings(
			{
				-list  => $list, 
				-email => $email, 
				-role  => "unsubscribed",
				-test  => $self->test,
			}
		);
        
        if($li->{send_unsub_success_email} == 1){ 
	
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
                $li->{use_alt_url_unsub_success} == 1 && 
                isa_url($li->{alt_url_unsub_success})
              ){ 
                my $qs = ''; 
                if($li->{alt_url_unsub_success_w_qs} == 1){ 
                    $qs = '?list=' . $list . '&rm=unsub&status=1&email=' . DADA::App::Guts::uriescape($email);  
                }
                my $r = $q->redirect(-uri => $li->{alt_url_unsub_success} . $qs);
                $self->test ? return $r : print $fh $r and return;
            
            }else{                
				my $r = ''; 
                $r .=  DADA::Template::HTML::list_template(
                            -Part  => "header",
                            -Title => "Unsubscription Successful",
                            -List  => $list
                      ); 
                
               my $s = $li->{html_unsubscribed_message};
               require DADA::Template::Widgets; 
               $r .=  DADA::Template::Widgets::screen({ 

                                                       -data                     => \$s,
                                                       -list_settings_vars_param => {-list => $li->{list}},
                                                       -dada_pseudo_tag_filter   => 1, 
													   -subscriber_vars          => {'subscriber.email' => $email},

                    									}); 

                $r .=  DADA::Template::HTML::list_template(
                            -Part      => "footer",
                            -List      => $list,
                            -Site_Name => $li->{website_name},
                            -Site_URL  => $li->{website_url},
                      ); 

                $self->test ? return $r : print $fh $r and return; 

            }
        }
    } 
}




sub DESTROY { 

}



1;
