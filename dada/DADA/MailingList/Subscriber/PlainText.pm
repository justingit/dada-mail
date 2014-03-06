package DADA::MailingList::Subscriber::PlainText; 

use lib qw (../../../ ../../../DADA/perllib); 
use strict;
use Carp qw(carp croak);
use DADA::App::Guts; 


sub add {

    my $self = shift;

    my ($args) = @_;
    my $lh =
      DADA::MailingList::Subscribers->new( { -list => $args->{ -list } } );

	if(!exists($args->{-log_it})){ 
		$args->{-log_it} = 1; 
	}
	
    if ( !exists $args->{ -type } ) {
        $args->{ -type } = 'list';
    }
    if ( !exists $args->{ -email } ) {
        croak("You MUST supply an email address in the -email parameter!");
    }
    if ( length( DADA::App::Guts::strip( $args->{ -email } ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email parameter!");
    }

    if ( !exists $args->{ -fields } ) {
        $args->{ -fields } = {};
    }


	# DEV: BAD: This code is copy/pasted in PlainText.pm
	if(!exists($args->{ -dupe_check }->{-enable} )) { 
			$args->{ -dupe_check }->{-enable} = 0;
	}
	if(!exists($args->{ -dupe_check }->{-on_dupe} )) { 
			$args->{ -dupe_check }->{-on_dupe} = 'ignore_add';
	}
	if($args->{ -dupe_check }->{-enable} == 1){ 
		if($lh->check_for_double_email(
	        -Email => $args->{ -email },
	        -Type  => $args->{ -type }
	    ) == 1){
			if($args->{ -dupe_check }->{-on_dupe} eq 'error'){ 
				croak 'attempt to to add: "' . $args->{ -email } . '" to list: "' . $args->{ -list } . '.' . $args->{ -type } . '" (email already subcribed)'; 
			}
			elsif($args->{ -dupe_check }->{-on_dupe} eq 'ignore_add'){ 
				return undef; 
			}
			else { 
				croak "unknown option, " . $args->{ -dupe_check }->{-on_dupe}; 
			}
		}
		else { 
			#... 
		}
	}
	# else:
		

    my $write_list = $args->{ -list };
    $write_list =~ s/ /_/i;

    my $file =
      make_safer(
        $DADA::Config::FILES . '/' . $write_list . '.' . $args->{ -type } );

    open my $LIST, '>>', $file
      or croak "couldn't open $file for reading: $!\n";

    flock( $LIST, 2 );

    chomp( $args->{ -email } );
    $args->{ -email } = strip( $args->{ -email } );
    print $LIST $args->{ -email } . "\n";
    close($LIST);

    my $added = DADA::MailingList::Subscriber->new(
        {
            -list  => $args->{ -list },
            -email => $args->{ -email },
            -type  => $args->{ -type },
        }
    );

	if($args->{-log_it} == 1) { 
	    if ( $DADA::Config::LOG{subscriptions} == 1 ) {
	        $added->{'log'}->mj_log( 
				$added->{list},
	            'Subscribed to ' . $added->{list} . '.' . $added->type,
	            $added->email 
			);
	    }
	}
    return $added;

}




sub get { 

    my $self = shift; 
    my ($args) = @_;
    
    if(! exists $args->{-dotted}){ 
        $args->{-dotted} = 0;
    }    
    
    my ($n, $d) = split('@', $self->email, 2);
        
    if($args->{-dotted} == 1){     
        return {'subscriber.email' => $self->email, 'subscriber.email_name' => $n, 'subscriber.email_domain' => $d}; 
    } else { 
        return {email => $self->email, email_name => $n, email_domain => $d}; 
    
    }
}




sub move { 
    
    my $self   = shift; 
    
    my ($args) = @_;
    
    if(! exists $args->{-to}){ 
        croak "You must pass a value in the -to parameter!"; 
    }
    
    if($self->{lh}->allowed_list_types($args->{-to} ) != 1){ 
        croak "list_type passed in, -type (" . $args->{ -type } . ") is not valid 2";
    }

   
    
    my $moved_from_checks_out = 0; 
    if(! exists($args->{-moved_from_check})){ 
        $args->{-moved_from_check} = 1; 
    }
    
	#?
    if($self->{lh}->check_for_double_email(-Email => $self->email, -Type => $self->type) == 0){ 
        
        if($args->{-moved_from_check} == 1){ 
            croak "email, " . $self->email . " is not subscribed to " . $self->{list} . '.'  . $self->type;     
        }
        else { 
            $moved_from_checks_out = 0; 
        }
    }
    else { 
        $moved_from_checks_out = 1; 
    }


	if(!exists($args->{-mode})){ 
		$args->{-mode} = 'writeover_check'; 
	}
		
	if($args->{-mode} eq 'writeover'){ 
		if($self->{lh}->check_for_double_email(-Email => $self->email, -Type => $args->{-to}) == 1){ 
			DADA::MailingList::Subscriber->new(
				{
					-list  => $self->{list}, 
					-email => $self->email,
	                -type  => $args->{ -to },
				}
			)->remove;
		}
	}
	else {  # I assume this is, "writeover_check"
	    if($self->{lh}->check_for_double_email(-Email => $args->{-email}, -Type => $args->{-to}) == 1){ 
	        croak "email passed in, -email ( $args->{-email}) is already subscribed to list passed in, '-to' ($args->{-to})"; 
	    }
	}

   
   
   if($moved_from_checks_out){ 
       $self->remove;
    }

    my $new_self = DADA::MailingList::Subscriber->add(
        { 
			-list  => $self->{list}, 
            -email => $self->email, 
            -type  => $args->{-to}, 
        }
    ); 

	if ( $DADA::Config::LOG{subscriptions} == 1 ) {
		$self->{'log'}->mj_log( 
			$self->{list},
	        "Unsubscribed from ". $self->{list} . "." . $self->type,
	         $self->email 
		);
	    $self->{'log'}->mj_log( 
			$self->{list},
	        'Subscribed to ' . $self->{list} . '.' . $args->{ -to },
	        $self->email 
		);
	}

	$self = $new_self; 
	return 1; 

}




sub remove { 
	
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-log_it})){ 
		$args->{-log_it} = 1; 
	}
	
	# Notice, for the PlainText backend, we're still going with this old chestnut -
	$self->{lh}->_remove_from_list(
		-Email_List =>[$self->email], 
		-Type       => $self->type,
		-log_it     => $args->{-log_it}, 
	);
	return undef; 
}




sub member_of {
	
    my $self = shift;	
	my ($args) = @_;

	my $list_types = [];
	
	my $lh = DADA::MailingList::Subscribers->new({-list => $self->{list}});
	foreach(keys %{$lh->get_list_types}){ 
		if($lh->check_for_double_email(
	        -Email => $self->email,
	        -Type  => $_,
	    ) == 1){
			push(@$list_types, $_); 
		}
	}

	if(exists($args->{-types})){ 
		my $lt = {}; 
		foreach(@{$args->{-types}}){ 
			$lt->{$_} = 1; 
		}
		my $filtered_list_types = []; 
		foreach(@$list_types){ 
			if($lt->{$_} == 1){ 
				push(@$filtered_list_types, $_); 
			}
		}
		return $filtered_list_types; 
	}
	else { 
		return $list_types; 
	}

} 






1;