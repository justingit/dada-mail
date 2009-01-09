package DADA::MailingList::Subscriber;
use lib qw(./ ../ ../../ ../../DADA ../../perllib);

use DADA::Config qw(!:DEFAULT); 	
BEGIN { 
	$type = $DADA::Config::SUBSCRIBER_DB_TYPE;
	if($type =~ m/sql/i){ 
		$type = 'baseSQL'; 
	}
	else { 
		$type = 'PlainText'; 
	}
}
use base "DADA::MailingList::Subscriber::$type";
use Carp qw(carp croak);

use strict; 

use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;


sub edit { 
	
	my $self = shift; 
    my ($args) = @_;

    if(! exists $args->{-type}){ 
        $args->{-type} = 'list';
    }
	if(! exists $args->{-email}){ 
        croak("You MUST supply an email address in the -email paramater!"); 
    }
	if(length(DADA::App::Guts::strip($args->{-email})) <= 0){ 
        croak("You MUST supply an email address in the -email paramater!"); 		
	}
	
    if(! exists $args->{-fields}){ 
        $args->{-fields} = {};
    }

    if(! exists $args->{-mode}){ 
        $args->{-mode} = 'update';
    }

	if($args->{-mode} !~ /update|writeover/){ 
		croak "The -mode paramater must be set to, 'update', 'writeover' or left undefined!"; 
	}

	my $f_values = {}; 
	
	if($args->{-mode} eq 'update'){ 
		
		$f_values	= $self->get(
			{
				-email => $args->{-email},
				-type  => $args->{-type}, 
			}
		);

	}

	$self->remove(
		{
			-email => $args->{-email},
			-type  => $args->{-type},
		}
	);

	foreach(keys %{$args->{-fields}}){ 
		$f_values->{$_} = $args->{-fields}->{$_};
	}
	
	$self->add(
	     { 
		  -email         => $args->{-email}, 
	      -type          => $args->{-type},
	      -fields        => $f_values,
	    });
	
	return 1;
		
}




sub copy { 
	
 my $self   = shift; 

    my ($args) = @_;

    if(! exists $args->{-to}){ 
        croak "You must pass a value in the -to paramater!"; 
    }
    if(! exists $args->{-from}){ 
        croak "You must pass a value in the -from paramater!"; 
    }    
    if(! exists $args->{-email}){ 
        croak "You must pass a value in the -email paramater!"; 
    }

    if($self->{lh}->allowed_list_types->{$args->{-to}} != 1){ 
        croak "list_type passed in, -to is not valid"; 
    }

    if($self->{lh}->allowed_list_types->{$args->{-from}} != 1){ 
        croak "list_type passed in, -from is not valid"; 
    }

     if(DADA::App::Guts::check_for_valid_email($args->{-email}) == 1){ 
        croak "email passed in, -email is not valid"; 
    }


    my $moved_from_checks_out = 0; 
    if(! exists($args->{-moved_from_check})){ 
        $args->{-moved_from_check} = 1; 
    }

    if($self->{lh}->check_for_double_email(-Email => $args->{-email}, -Type => $args->{-from}) == 0){ 

        if($args->{-moved_from_check} == 1){ 
            croak "email passed in, -email is not subscribed to list passed in, '-from'";     
        }
        else { 
            $moved_from_checks_out = 0; 
        }
    }
    else { 
        $moved_from_checks_out = 1; 
    }


    if($self->{lh}->check_for_double_email(-Email => $args->{-email}, -Type => $args->{-to}) == 1){ 
        croak "email passed in, -email ( $args->{-email}) is already subscribed to list passed in, '-to' ($args->{-to})"; 
    }

	my $sub = $self->get({-email => $args->{-email}, -type => $args->{-from}}); 
    $self->add(
        { 
            -email  => $args->{-email}, 
            -type   => $args->{-to}, 
			-fields => $sub,
        }
    ); 

    if ($DADA::Config::LOG{subscriptions}) { 
        $log->mj_log(
            $self->{list}, 
            'Copy from:  ' . $self->{list} . '.' . $args->{-from} . ' to: ' . $self->{list} . '.' . $args->{-to}, 
            $args->{-email}, 
        );
    }


	return 1;

}




sub remove { 
	
	my $self   = shift;
	my ($args) = @_; 

	if(! exists $args->{-type}){ 
	    $args->{-type} = 'list';
	}
	if(! exists $args->{-email}){ 
	    croak("You MUST supply an email address in the -email paramater!"); 
	}
	if(length(DADA::App::Guts::strip($args->{-email})) <= 0){ 
	    croak("You MUST supply an email address in the -email paramater!"); 		
	}

	# Kind of a wrapper ATM:
	return $self->{lh}->remove_from_list(
		-Email_List => [$args->{-email}], 
		-Type       => $args->{-type},
	);

}




sub subscription_check { 

	my $self = shift; 
	my ($args) = @_; 

	
	if(! exists($args->{-email})){ 
		$args->{-email} = ''; 
	}
	my $email = $args->{-email};

	if(! exists($args->{-type})){ 
		$args->{-type} = 'list'; 
	} 
	
	my %skip; 
	$skip{$_} = 1 foreach @{$args->{-skip}}; 
		
	my %errors = ();
	my $status = 1; 
		
	require DADA::App::Guts; 
	require DADA::MailingList::Settings;
	
	if(!$skip{no_list}){
		if(DADA::App::Guts::check_if_list_exists(-List => $self->{list}) == 0){
			$errors{no_list} = 1;
			return (0, \%errors);
		}
	}
				
	my $ls = DADA::MailingList::Settings->new({-list => $self->{list}}); 
	my $list_info = $ls->get;
	
	if($args->{-type} ne 'black_list'){ 
		if(!$skip{invalid_email}){
			$errors{invalid_email} = 1 if DADA::App::Guts::check_for_valid_email($email)      == 1;
		}
	}
	
	if(!$skip{subscribed}){
			$errors{subscribed} = 1 if $self->{lh}->check_for_double_email(-Email => $email, -Type => $args->{-type}) == 1; 
	}
	
	if($args->{-type} ne 'black_list' || $args->{-type} ne 'authorized_senders'){ 
		if(!$skip{closed_list}){
			$errors{closed_list}   = 1 if $list_info->{closed_list}                             == 1; 
		}
	}
	
	if($args->{-type} ne 'black_list'){ 
		if(!$skip{mx_lookup_failed}){		
			if($list_info->{mx_check} == 1){ 
				require Email::Valid;
				eval {
					unless(Email::Valid->address(-address => $email,
												 -mxcheck => 1)) {
						$errors{mx_lookup_failed}   = 1;
					};
				carp "mx check error: $@" if $@;
				}; 
			}
		}
	}

	
	if($args->{-type} ne 'black_list'){ 
		if(!$skip{black_listed}){
			if($list_info->{black_list} eq "1"){
				$errors{black_listed} = 1 if $self->{lh}->check_for_double_email(-Email => $email, 
																		  -Type  => 'black_list')  == 1; 
			}
		}
	}


	if($args->{-type} ne 'white_list'){ 
		if(!$skip{not_white_listed}){
		
			if($list_info->{enable_white_list} == 1){

				$errors{not_white_listed} = 1 if $self->{lh}->check_for_double_email(-Email => $email, 
																		       -Type  => 'white_list')  != 1; 
			}
		}
	}


	if($args->{-type} ne 'black_list' || $args->{-type} ne 'authorized_senders'){ 
		if(!$skip{over_subscription_quota}){ 
			if($list_info->{use_subscription_quota} == 1){ 
				if(($self->{lh}->num_subscribers + 1) >= $list_info->{subscription_quota}){ 
					$errors{over_subscription_quota} = 1; 
				}
			}
		}
	}
	
	
	if(!$skip{already_sent_sub_confirmation}){ 
		if($list_info->{limit_sub_confirm } == 1){ 
			$errors{already_sent_sub_confirmation} = 1 if $self->{lh}->check_for_double_email(-Email => $email, 
																                        -Type  => 'sub_confirm_list')  == 1;
		}
	}
	
	
	
	if(!$skip{settings_possibly_corrupted}){ 
		if(!$ls->perhapsCorrupted){ 
			$errors{settings_possibly_corrupted} = 1; 
		}
	}
	
	
	
	foreach(keys %errors){ 
		$status = 0 if $errors{$_} == 1;
		last;
	}
	
	return ($status, \%errors); 
	
}




sub unsubscription_check {
		 
	my $self = shift; 
	my ($args) = @_; 

	
	if(! exists($args->{-email})){ 
		$args->{-email} = ''; 
	}
	my $email = $args->{-email};

	if(! exists($args->{-type})){ 
		$args->{-type} = 'list'; 
	}  
	
	my %errors = ();
	my $status = 1; 
	
	if(!exists($args->{-skip})){ 
		$args->{-skip} = [];
	}
	my %skip; 
	$skip{$_} = 1 foreach @{$args->{-skip}}; 
	
	require DADA::App::Guts;
	require DADA::MailingList::Settings;
	
	if(!$skip{no_list}){
		$errors{no_list} = 1 if DADA::App::Guts::check_if_list_exists(-List => $self->{list})     == 0;
		return (0, \%errors) if $errors{no_list} == 1;
	}
				
	my $ls = DADA::MailingList::Settings->new({-list => $self->{list}}); 
		
	if(!$skip{invalid_email}){
		$errors{invalid_email} = 1 if DADA::App::Guts::check_for_valid_email($email)      == 1;
	}
	
	if(!$skip{not_subscribed}){
		$errors{not_subscribed}    = 1 if $self->{lh}->check_for_double_email(-Email => $email)     != 1; 
	}
	
	if(!$skip{already_sent_unsub_confirmation}){ 
		my $li = $ls->get; 
		if($li->{limit_unsub_confirm } == 1){ 
			$errors{already_sent_unsub_confirmation} = 1 if $self->{lh}->check_for_double_email(-Email => $email, 
																                          -Type  => 'unsub_confirm_list')  == 1;
		}
	}
	
	
	if(!$skip{settings_possibly_corrupted}){ 
		if(!$ls->perhapsCorrupted){ 
			$errors{settings_possibly_corrupted} = 1; 
		}
	}

		
	foreach(keys %errors){ 
		$status = 0 if $errors{$_} == 1;
		last;
	}
	
	

	return ($status, \%errors); 
	

}



sub subscription_check_xml { 

	my $self = shift; 
	my ($args) = @_; 
	my ($status, $errors) = $self->subscription_check($args); 
	
	my $errors_array_ref = []; 
	push(@$errors_array_ref, {error => $_}) 
		foreach keys %$errors; 
	
	require    DADA::Template::Widgets;
	my $xml =  DADA::Template::Widgets::screen({-screen => 'subscription_check_xml.tmpl', 
		                                  -vars   => {
		                                               email  => $args->{-email}, 
		                                               errors => $errors_array_ref,
		                                               status => $status, 
		                                               
		                                              },
	
	            });
	
	$xml =~ s/\n|\r|\s|\t//g;
	
	
	return ($xml, $status, $errors); 
}



sub unsubscription_check_xml { 

	my $self = shift; 
	my ($args) = @_; 
	my ($status, $errors) = $self->unsubscription_check($args); 
	
	my $errors_array_ref = []; 
	push(@$errors_array_ref, {error => $_}) 
		foreach keys %$errors; 

	require    DADA::Template::Widgets;
	my $xml =  DADA::Template::Widgets::screen({-screen => 'unsubscription_check_xml.tmpl', 
		                                  	   -vars   => {
		                                               email  => $args->{-email}, 
		                                               errors => $errors_array_ref,
		                                               status => $status, 
		                                               
		                                              },
		                                     }); 
	$xml =~ s/\n|\r|\s|\t//g;
	
	return ($xml, $status, $errors); 
}



1; 
