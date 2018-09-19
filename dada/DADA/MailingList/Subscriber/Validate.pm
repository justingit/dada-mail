package DADA::MailingList::Subscriber::Validate;

use lib qw (../../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);
use DADA::App::Guts; 
use Try::Tiny; 
my $t =  $DADA::Config::DEBUG_TRACE->{DADA_MailingList};

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
    return $self;

}

sub _init {

    my $self = shift;

    my ($args) = @_;

    $self->{list} = $args->{ -list };
    if ( exists( $args->{ -lh_obj } ) ) {
        $self->{lh} = $args->{ -lh_obj };
    }
    else {
        require DADA::MailingList::Subscribers;
        my $lh =
          DADA::MailingList::Subscribers->new( { -list => $args->{ -list } } );
        $self->{lh} = $lh;
    }

}

sub subscription_check {

    my $self = shift;
    my ($args) = @_;

	if($t){ 
		require Data::Dumper; 
		warn 'subscription_check passed args:' . Data::Dumper::Dumper($args);
	}
	
    if ( !exists( $args->{-email} ) ) {
        $args->{-email} = '';
    }
    my $email = $args->{-email};
	
	# my $email = $self->normalize_email(
	#	$args->{-email}
	#);
    
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }
    if ( !exists( $args->{-fields} ) ) {
        $args->{-fields} = {};
    }
	
    if ( !exists( $args->{-consent_ids} ) ) {
        $args->{-consent_ids} = [];
    }
    
    if(! exists($args->{-skip})) { 
        $args->{-skip} = [];
    }
    if(! exists($args->{-mode})) { 
        $args->{-mode} = 'user';
    }
	
    if(! exists($args->{-captcha_params})) { 
		$args->{-captcha_params} = {}; 
	}
    
    my %skip;
    for(@{ $args->{-skip} }) { 
        $skip{$_} = 1;
    }
    
    my $errors = {};
    my $status = 1;

    require DADA::App::Guts;
    require DADA::MailingList::Settings;

    if ( !$skip{no_list} ) {
        if ( DADA::App::Guts::check_if_list_exists( -List => $self->{list} ) == 0 ) {
            $errors->{no_list} = 1;
			# short circuiting. 
			warn 'error, no_list'
				if $t;
            return ( 0, $errors );
        }
    }

    my $ls = undef;
    if(exists($args->{-ls_obj})){ 
           $ls = $args->{-ls_obj};
    }
    else{ 
        $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    } 
    
    if ( 
		   $args->{-type} ne 'black_list' 
		&& $args->{-type} ne 'white_list'
		&& $args->{-type} ne 'ignore_bounces_list'
	 ) {
        if ( !$skip{invalid_email} ) {
              if(DADA::App::Guts::check_for_valid_email($email) == 1) { 
			  	$errors->{invalid_email} = 1;
	   				warn 'error, invalid_email'
	     				if $t;
	  	   		# short circuiting. 
	     		return ( 0, $errors );
			  
			  }
        }
    }
    else {
        if ( DADA::App::Guts::check_for_valid_email($email) == 1 ) {
            if ( $email !~ m/^\@|\@$/ ) {
                $errors->{invalid_email} = 1;
	  			warn 'error, invalid_email'
	  				if $t;
	            return ( 0, $errors );
            }
        }
    }
	
	if (
		$args->{-type}    eq 'list'
		&& $args->{-mode} eq 'user'
	){ 
	    if (
			!$skip{captcha_challenge_failed} 
			&& length($DADA::Config::RECAPTCHA_PARAMS->{public_key}) > 0
			&& length($DADA::Config::RECAPTCHA_PARAMS->{private_key}) > 0
			&& $DADA::Config::RECAPTCHA_PARAMS->{on_subscribe_form} == 1
			&& can_use_Google_reCAPTCHA()
		) {		
			$errors->{captcha_challenge_failed} = 0; 
	        if(!defined($args->{-captcha_params})){ 
				$errors->{captcha_challenge_failed} = 1; 
			    # short circuiting. 
	  			warn 'error, captcha_challenge_failed'
	  				if $t;
	            return ( 0, $errors );
			}
			elsif(
				length($args->{-captcha_params}->{-remote_addr}) <= 0
				||
				length($args->{-captcha_params}->{-response}) <= 0
			) { 
				$errors->{captcha_challenge_failed} = 1; 
	  			warn 'error, captcha_challenge_failed'
	  				if $t;
			    # short circuiting. 
	            return ( 0, $errors );
			}
			else {
				require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;
				my $cap = DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA->new;
		        my $result = $cap->check_answer(
		            $args->{-captcha_params}->{-remote_addr},
					$args->{-captcha_params}->{-response},
				);
		        if ( $result->{is_valid} == 1 ) {
					$errors->{captcha_challenge_failed} = 0; 
					delete($errors->{captcha_challenge_failed});
		        }
		        else {
					$errors->{captcha_challenge_failed} = 1; 
	  			 	# short circuiting. 
		  			warn 'error, captcha_challenge_failed'
		  				if $t;
	                return ( 0, $errors );
		        }
			}
		}
	}
	
    if ( !$skip{subscribed} ) {
        $errors->{subscribed} = 1
          if $self->{lh}->check_for_double_email(
            -Email => $self->normalize_email($email),
            -Type  => $args->{-type}
          ) == 1;
    }

    if($args->{-type} eq 'list') {
        if ( !$skip{invite_only_list} ) {
		   	if($ls->param('invite_only_list') == 1){ 
                if(
					$self->{lh}->check_for_double_email(
                    	-Email => $self->normalize_email($email),
                   	 -Type  => 'invited_list'
                	 ) == 1
				){ 
					# $errors->{invite_only_list} = 0; 
				}
				else { 
					$errors->{invite_only_list} = 1; 
				}
        	}
		}
		else { 
			# $errors->{invite_only_list} = 0; 
        }

        if ( !$skip{closed_list} ) {
            $errors->{closed_list} = 1 if $ls->param('closed_list') == 1;
        }
		
        if ( !$skip{over_subscription_quota} ) {
            my $num_subscribers = $self->{lh}->num_subscribers;
            if ( $ls->param('use_subscription_quota') == 1 ) {
                if ( ( $num_subscribers + 1 ) >= $ls->param('subscription_quota') ) {
                    $errors->{over_subscription_quota} = 1;
                }
            }
            elsif (defined($DADA::Config::SUBSCRIPTION_QUOTA)
                && $DADA::Config::SUBSCRIPTION_QUOTA > 0
                && $num_subscribers + 1 >= $DADA::Config::SUBSCRIPTION_QUOTA )
            {
                $errors->{over_subscription_quota} = 1;
            }
        }
		
		
    }

    if ( $args->{-type} ne 'black_list' ) {
        if ( !$skip{mx_lookup_failed} ) {
            if ( $ls->param('mx_check') == 1 ) {
                require Email::Valid;
                eval {
                    unless (
                        Email::Valid->address(
                            -address => $email,
                            -mxcheck => 1
                        )
                      )
                    {
                        $errors->{mx_lookup_failed} = 1;
                    }
                    if ($@) {
                        carp "warning: mx check didn't work: $@, for email, '$email' on list, '" . $self->{list} . "'";
                    }
                };
            }
        }
    }
    
    
    # When -usermode is set to, this is where, "allow_blacklisted_to_subscribe" should be checked 
    # similar for admin
    #
    if ( $args->{-type} ne 'black_list' ) {
        if ( !$skip{black_listed} ) {
            if ( $ls->param('black_list') == 1 ) {
                $errors->{black_listed} = 1
                  if $self->{lh}->check_for_double_email(
                    -Email => $self->normalize_email($email),
                    -Type  => 'black_list'
                  ) == 1;
            }
        }
    }

    if ( $args->{-type} ne 'white_list' ) {
        if ( !$skip{not_white_listed} ) {

            if ( $ls->param('enable_white_list') == 1 ) {

                $errors->{not_white_listed} = 1
                  if $self->{lh}->check_for_double_email(
                    -Email => $self->normalize_email($email),
                    -Type  => 'white_list'
                  ) != 1;
            }
        }
    }

    if ( !$skip{already_sent_sub_confirmation} ) {
        if ( $ls->param('limit_sub_confirm') == 1 ) {
            if( $self->{lh}->check_for_double_email(
				-Email => $self->normalize_email($email),
				-Type  => 'sub_confirm_list'
			) == 1) { 
                  $errors->{already_sent_sub_confirmation} = 1;
              }
        }
    }

    if ( !$skip{settings_possibly_corrupted} ) {
        if ( !$ls->perhapsCorrupted ) {
            $errors->{settings_possibly_corrupted} = 1;
        }
    }
	
	if (
		$args->{-type}    eq 'list'
		&& $args->{-mode} eq 'user'
	){ 
		if ( !$skip{list_consent_check} ) {		
			$errors->{list_consent_check_failed} = 0;
			require DADA::MailingList::Consents; 
			my $con           = DADA::MailingList::Consents->new; 
			my $list_consents = $con->give_me_all_consents($ls); 
			
			my $list_consent_ids = [];
			my $any = 0; 
			for(@$list_consents){ 
				next if ! exists($_->{id});
				push(@$list_consent_ids, $_->{id}); 
				$any++; 
			}
			if($any >= 1){ 		
				my $passed_consent = {}; 
				for(@{$args->{-consent_ids}}){ 
					$passed_consent->{$_} = 1; 
				}				
				for(@$list_consent_ids){ 
					if(!exists($passed_consent->{$_})){ 
						$errors->{list_consent_check_failed} = 1; 
		                $status = 0;
		                last;
					}
				}
				if($status == 1){ 
					delete($errors->{list_consent_check_failed}); 
				}
			}
			else { 
				delete($errors->{list_consent_check_failed}); 
			}
		}
	}
	
	if (
		$args->{-type}    eq 'list'
		&& $args->{-mode} eq 'user'
	){ 


		

		$errors->{stop_forum_spam_check_failed} = 0;
	    if ( !$skip{stop_forum_spam_check_failed} ) {		
			if($ls->param('enable_sub_confirm_stopforumspam_protection') == 1) {
				warn '$self->sfs_check($email)' . $self->sfs_check($email)
					if $t;
				try {
					if ($self->sfs_check($email) == 0) { 
						 $errors->{stop_forum_spam_check_failed} = 1;
					}
				} catch { 
					warn "something wrong with stopforumspam check?: $_";
				}
			}
		}
		# If StopForumSpam is showing a hit, no need to do this... 
		if($errors->{stop_forum_spam_check_failed} != 1){
			
		    if ( !$skip{suspicious_activity_by_ip_check_failed} ) {		
				if($ls->param('enable_sub_confirm_suspicious_activity_by_ip_protection') == 1) {
					if (
						$self->suspicious_activity_by_ip(
							{
								-ip    => $ENV{'REMOTE_ADDR'}. 
								-email => $email, 
							}
						) == 0
					){ 
						 $errors->{suspicious_activity_by_ip_check_failed} = 1;
					}
				}
			}
		}
		
		if($errors->{stop_forum_spam_check_failed} == 0) { 
			delete($errors->{stop_forum_spam_check_failed});
		}
	}
	
	
    if ( $args->{-type} eq 'list') {
        # Profile Fields
        if(!$skip{profile_fields}) { 
                
            require DADA::ProfileFieldsManager; 
            my $dpfm = DADA::ProfileFieldsManager->new; 
            my $dpf_att = $dpfm->get_all_field_attributes;        
            my $fields = $dpfm->fields; 
        
            for my $field_name(@{$fields}) {     
                my $field_name_status = 1; 
                if($dpf_att->{$field_name}->{required} == 1){ 
                    if(exists($args->{-fields}->{$field_name})){ 
                        if(defined($args->{-fields}->{$field_name}) && $args->{-fields}->{$field_name} ne ""){ 
                            #... Well, that's good! 
                        }
                        else { 
                            if ($args->{-mode} eq 'user' &&  $field_name =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/) {
                                # Well, then that's OK too: users can't fill in hidden fields
                            }
                            else { 
                                $field_name_status = 0; 
                            }
                        }
                    }
                    else { 
                        if ($args->{-mode} eq 'user' &&  $field_name =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/) {
                            # Well, then that's OK too: users can't fill in hidden fields
                        }
                        else { 
                            $field_name_status = 0; 
                        }
                    }
                }
                if($field_name_status == 0){ 
                    # We do this, so when we add things like "type checking" we don't
                    # have to redo everything again.
                    $errors->{invalid_profile_fields}->{$field_name}->{required} = 1; 
                }
            }
            
            if(exists($errors->{invalid_profile_fields})){ 
                # This is going to be more expensive, than just seeing if some value is passed, 
                # But I guess the policy is, if the profile already exists, then it doens't matter 
                # if these fields are empty  as they were already empty! 
                #
                # I'd rather this look at Profile, rather than the fields of Profiles, which can easily be 
                # orphans, if Fields are saved, but profiles aren't, (say, when you're subscribing via the 
                # list control panel - d'oh!) 
                #
                #
                if(! exists($errors->{invalid_email})){ 
                    require    DADA::Profile::Fields; 
                    my $dpf = DADA::Profile::Fields->new({
    					-dpfm_obj => $dpfm, 
    				});
                    if($dpf->exists({-email => $email})){ 
                        # Nevermind. 
                        $errors->{invalid_profile_fields} = undef;
                        delete($errors->{invalid_profile_fields}); 
                        undef($dpf); 
                    } 
                }
            }
        }
    }
    
    for my $error_name( keys %{$errors} ) {
        if($error_name ne 'invalid_profile_fields') {
            if ($errors->{$error_name} == 1) { 
                $status = 0;
                last;
            }
#			else { 
#				delete($errors->{$error_name}); # don't return it, if it's not an error?
#			}
        }
        elsif(keys %{$errors->{$error_name}} ) { # invalid_profile_fields
            $status = 0;             
            last;
            
        }
    }
    
	if($t){ 
		require Data::Dumper; 
		warn 'subscription_check returning: ' . Data::Dumper::Dumper({status => $status, errors => $errors});
	}
    return ( $status, $errors );

}

sub unsubscription_check {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -email } ) ) {
        $args->{ -email } = '';
    }
    #my $email = $self->normalize_email(
	#	$args->{ -email }
	#);
	my $email = $args->{ -email };

    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }

    my %errors = ();
    my $status = 1;

    if ( !exists( $args->{ -skip } ) ) {
        $args->{ -skip } = [];
    }
    my %skip;
    $skip{$_} = 1 for @{ $args->{ -skip } };

    require DADA::App::Guts;
    require DADA::MailingList::Settings;

    if ( !$skip{no_list} ) {
        $errors{no_list} = 1
          if DADA::App::Guts::check_if_list_exists( -List => $self->{list} ) ==
          0;
        return ( 0, \%errors ) if $errors{no_list} == 1;
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    if ( !$skip{invalid_email} ) {
        $errors{invalid_email} = 1
          if DADA::App::Guts::check_for_valid_email($email) == 1;
    }

    if ( !$skip{not_subscribed} ) {
        $errors{not_subscribed} = 1
          if $self->{lh}->check_for_double_email( 
		  	-Email => $self->normalize_email($email), 
		) != 1;
    }

    if ( !$skip{already_sent_unsub_confirmation} ) {
        my $li = $ls->get;
        if ( $li->{limit_sub_confirm} == 1 ) {
            $errors{already_sent_unsub_confirmation} = 1
              if $self->{lh}->check_for_double_email(
                -Email => $self->normalize_email($email),
                -Type  => 'unsub_confirm_list'
              ) == 1;
        }
    }

    if ( !$skip{settings_possibly_corrupted} ) {
        if ( !$ls->perhapsCorrupted ) {
            $errors{settings_possibly_corrupted} = 1;
        }
    }

    for ( keys %errors ) {
        $status = 0 if $errors{$_} == 1;
        last;
    }

    return ( $status, \%errors );

}

sub sfs_check { 

	# Pass: 1
	# Fail: 0;
	if($ENV{NO_DADA_MAIL_CONFIG_IMPORT} == 1){ 
		return 1;
	} 
	
	my $self  = shift; 
	my $email = shift; 
		
	my $can_use_StopForumSpam = can_use_StopForumSpam(); 
	if($can_use_StopForumSpam == 0){ 
		return 1;
	}
	require WWW::StopForumSpam;

	my $sfs = WWW::StopForumSpam->new();

	my $r_ip = 0; 
	if(length($ENV{'REMOTE_ADDR'}) >= 1) {
		$r_ip = $sfs->check(
			ip => $ENV{'REMOTE_ADDR'},
		); 
	}
	if($r_ip == 1){ 
		warn 'sfs_check FAIL ip lookup: ' . anonymize_ip($ENV{'REMOTE_ADDR'})
			if $t; 
	}
	else { 
		warn 'sfs_check PASS ip lookup: ' . anonymize_ip($ENV{'REMOTE_ADDR'})
			if $t; 
	}
	
	my $r_email = $sfs->check(
		email => $email
	); 
	if($r_email == 1){ 
		warn 'sfs_check FAIL email lookup: ' . $email
			if $t; 
	}
	else { 
		warn 'sfs_check PASS email lookup: ' . $email
			if $t; 
	}
	
	if($r_ip == 1 || $r_email == 1){ 
		if($r_ip == 1 && $r_email == 1) {  # both fail? Seems suspicious...
			my ($ping_test, $ping_r) = ping_test('api.stopforumspam.org', 80);
			if($ping_test == 1) { 
				return 0;		
			}
			else {
				warn 'cannot successfully ping ' . 'api.stopforumspam.org:' . $ping_r
					if $t; 
				return 1;
			} 
		}
		else { 
			return 0; 
		}
	}
	else { 
		return 1; 
	}
}

sub suspicious_activity_by_ip {
	 
	my $self = shift; 
	my ($args) = @_; 
	my $ip = undef; 
	
	if(exists($args->{-ip})){
		$ip = $args->{-ip};
	}	
	else { 
		warn "you need to pass the ip address to check in, '-ip'";
	}
	
	if(! defined($ip) || length($ip) == 0) {
		warn 'no ip found.';
		return 1; 
	}
	
	require DADA::App::Subscriptions::ConfirmationTokens;
	my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
	my $tokens = $ct->get_all_tokens(
		{
			-limit => 5000, 
			-flavor => 'sub_confirm',
		}
	);
	
	#require Data::Dumper; 
	#warn '$tokens' . Data::Dumper::Dumper($tokens);
	warn (scalar @$tokens) . " returned"
		if $t; 
	
	my $r = {}; 
	
	foreach my $t(@$tokens){ 
			
		my $data = $ct->fetch($t->{token});
		#warn '$data->{data}->{flavor}' . $data->{data}->{flavor}; 
		next 
			if $data->{data}->{flavor} ne 'sub_confirm'; 
		push(
			@{
				$r->{
					$data->{data}->{remote_addr}
				}
			}, 
			$data->{email}
		); 
	}

	# warn '$r' . Data::Dumper::Dumper($r);
	
	for my $c(keys %$r){ 
		my $unique_count = 0; 
		my $tmp_l = {}; 

		for my $ucl( @{$r->{$c}} ){ 
			if(!exists($tmp_l->{$ucl})){ 
				$tmp_l->{$ucl} = 1;
			}
			else {		
				$tmp_l->{$ucl}++; 
			}
		}
		
		# warn '$tmp_l' . Data::Dumper::Dumper($tmp_l);
		$unique_count = scalar keys %$tmp_l;
		
		# warn '$unique_count' . $unique_count; 
		
		next if($unique_count < 3);
		#warn '$c'  . $c; 
		#warn '$ip' . $ip; 
		if($c eq $ip) { 
			warn 'IP Address: ' 
			. $ip 
			. ' flagged for suspicious activity in, suspicious_activity_by_ip(), email: ' 
			. $args->{-email};
			return 0;
		}
		else { 
			# warn 'IP Address: ' . $ip . ' check out!';
		}
	}
	return 1; 

}

sub normalize_email {
    my $self  = shift;
    my $email = shift;
    return lc_email( strip($email) );
}


1;
