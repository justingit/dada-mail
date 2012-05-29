package DADA::MailingList::Subscriber::baseSQL;

use strict;
use lib qw(../../../ ../../../perllib);
use Carp qw(carp croak);
use DADA::Config;
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};




sub add {

    my $class = shift;
    my ($args) = @_;
	
	if(!exists($args->{-log_it})){ 
		$args->{-log_it} = 1; 
	}
	
	
	my $lh = undef; 
	
	if(exists($args->{-dpfm_obj})){ 
		$lh =
	      DADA::MailingList::Subscribers->new( 
			{ 
				-list     => $args->{ -list },
				-dpfm_obj => $args->{-dpfm_obj},
			} 
		);
		
	}
	else { 
		$lh =
	      DADA::MailingList::Subscribers->new( { -list => $args->{ -list } } );
	 	
	}

    if ( !exists $args->{ -type } ) {
        $args->{ -type } = 'list';
    }
    if ( !exists $args->{ -email } ) {
        croak("You MUST supply an email address in the -email paramater!");
    }
    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email paramater!");
    }

	if(!exists($args->{ -confirmed } )){ 
		$args->{ -confirmed } = 1; 
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
	
    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{subscriber_table}
      . '(email,list,list_type,list_status) VALUES (?,?,?,?)';

    warn 'Query: ' . $query
      if $t;
	require DADA::App::DBIHandle;
	my $dbi_obj = DADA::App::DBIHandle->new;
	my $dbh     = $dbi_obj->dbh_obj;
	my $sth     = $dbh->prepare($query);

	$sth->execute(
		$args->{ -email },
		$args->{ -list },
		$args->{ -type },
		1
    )
	or croak "cannot do statement (at add_subscriber)! $DBI::errstr\n";
	$sth->finish;
	
	if ( exists $args->{ -fields } && keys %{$args->{ -fields }}) {
		my $fields = undef; 
		
		if(exists($args->{-dpfm_obj})){ 
			$fields = DADA::Profile::Fields->new(
				{
					-dpfm_obj => $args->{-dpfm_obj}, 
				}
			);
		}
		else {
			$fields = DADA::Profile::Fields->new;
		}		
		$fields->insert(
			{
				-email     => $args->{  -email },
				-fields    => $args->{  -fields },
				-confirmed => $args->{ -confirmed },
				-mode      => $args->{ -fields_options }->{-mode}, 
			}
		); 
	}
    my $added = DADA::MailingList::Subscriber->new(
        {
            -list  => $args->{ -list },
            -email => $args->{ -email },
            -type  => $args->{ -type },
			(
				exists($args->{-dpfm_obj})
			) ? (
				-dpfm_obj => $args->{-dpfm_obj},
			) : 
			(
			)
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

    my $self   = shift;
    my ($args) = @_;
	# I don't think I even pass anything to this method... 
	
    require DADA::Profile::Fields; 
	my $sf = DADA::Profile::Fields->new(
			{
				
				-email => $self->{email}, 
			#	%$args,
			}
	); 
	
	
	my $r =  $sf->get($args);  
	
	return $r; 
}

sub move {

    my $self = shift;

    my ($args) = @_;

    if ( !exists $args->{ -to } ) {
        croak "You must pass a value in the -to paramater!";
    }

    if ( $self->{lh}->allowed_list_types( $args->{ -to }) != 1 ) {
        croak "list_type passed in, -to is not valid";
    }
	if(!exists($args->{-confirmed})){ 
		$args->{-confirmed} = 0; 
	}

	
	###
	# This is sort of strange,
	if($self->{lh}->can_have_subscriber_fields == 1){ 
		if($args->{-confirmed} == 1){ 
			require DADA::Profile::Fields; 
			my $dpf = DADA::Profile::Fields->new;
			if($dpf->exists({-email => '*' . $self->email})){ 
				my $dpf2 = DADA::Profile::Fields->new({-email => '*' . $self->email});
				my $fields = $dpf2->get;
				$dpf2->remove; 
				$dpf->insert(
					{
						-email     => $self->{email},
						-fields    => $fields, 
						-confirmed => 1, 
					}
				); 
			}
		}
	}
	### And then, do your thing, 
	

    # Why wasn't this in before?
    my $moved_from_checks_out = 0;
    if ( !exists( $args->{ -moved_from_check } ) ) {
        $args->{ -moved_from_check } = 1;
    }

    if (
        $self->{lh}->check_for_double_email(
            -Email => $self->email,
            -Type  => $self->type
        ) == 0
      )
    {

        if ( $args->{ -moved_from_check } == 1 ) {
            croak $self->email
              . " is not subscribed to list type, "
              . $self->type;
        }
        else {
            $moved_from_checks_out = 0;
        }
    }
    else {
        $moved_from_checks_out = 1;
    }

    # /Why wasn't this in before?

    if ( !exists( $args->{ -mode } ) ) {
        $args->{ -mode } = 'writeover_check';
    }

    if ( $args->{ -mode } eq 'writeover' ) {
        if (
            $self->{lh}->check_for_double_email(
                -Email => $self->email,
                -Type  => $args->{ -to }
            ) == 1
          )
        {
            DADA::MailingList::Subscriber->new(
                {
                    -list  => $self->{list},
                    -email => $self->email,
                    -type  => $args->{ -to },
                }
            )->remove;
        }
    }
    else {
        if (
            $self->{lh}->check_for_double_email(
                -Email => $args->{ -email },
                -Type  => $args->{ -to }
            ) == 1
          )
        {
            croak
"email passed in, -email ( $args->{-email}) is already subscribed to list passed in, '-to' ($args->{-to})";
        }
    }

    my $query = 'UPDATE '
      . $self->{sql_params}->{subscriber_table}
      . ' SET   list_type   = ? 
                      WHERE list_type   = ? 
                      AND   email       = ?';

	## Unsubs via a subscriber are done by first moving  them to the unsub_confirm_list
	#if($args->{ -to } eq 'unsub_confirm_list' && $DADA::Config::GLOBAL_UNSUBSCRIBE == 1){ 
		$query .=' AND list = ' . $self->{dbh}->quote($self->{list}); 
	#}
		
    my $sth = $self->{dbh}->prepare($query);

    my $rv =
      $sth->execute( $args->{ -to }, $self->type, $self->email )
      or croak "cannot do statement (at move_subscriber)! $DBI::errstr\n";

    if ( $rv == 1 ) {
		if ( $DADA::Config::LOG{subscriptions} ) {
			#	        $self->{'log'}->mj_log(
			#	            $self->{list},
			#	            'Moved from:  '
			#	              . $self->{list} . '.'
			#	              . $self->type . ' to: '
			#	              . $self->{list} . '.'
			#	              . $args->{ -to },
			#	            $self->email,
			#	        );

	
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
	    }

	    # Since this is a reference, this should do what I want -
	    $self = DADA::MailingList::Subscriber->new(
	        {
	            -email => $self->email,
	            -type  => $args->{ -to },
	            -list  => $self->{list},
	        }
	    );
	
        return 1;
        #carp "Hey, that worked!";
    }
    else {
        carp "Something's wrong. Returned $rv rows, expected 1";
    }
}

sub remove {

    my $self = shift;
	my ($args) = @_; 
	if(!exists($args->{-log_it})){ 
		$args->{-log_it} = 1; 
	}
	
    my $query = "DELETE FROM " . $self->{sql_params}->{subscriber_table} . " 
				 WHERE email   = ?
				 AND list_type = ?";

    if ( $self->type eq 'black_list' ) {
		#warn "here 1"; 
        if ( $DADA::Config::GLOBAL_BLACK_LIST != 1 ) {
			#warn "here 2"; 
            $query .= ' AND list =' . $self->{dbh}->quote($self->{list});
        }
    }								 
    elsif ( $self->type eq 'list') {
		#warn "here 3"; 
        if ( $DADA::Config::GLOBAL_UNSUBSCRIBE != 1 ) {
			#warn "here 5"; 
            $query .= ' AND list =' . $self->{dbh}->quote($self->{list});
        }
		else { 
			#warn "here 6"; 
		}
    }
	# this is for the global unsub stuff
	elsif($self->type eq 'unsub_confirm_list' && $DADA::Config::GLOBAL_UNSUBSCRIBE == 1) { 
		# ... nothin' 
	}
    else {
		#warn warn "here 4"; 
        $query .= ' AND list =' . $self->{dbh}->quote($self->{list});
    }
	
	#warn 'Query: ' . $query;
	
	warn 'Query: ' . $query
		if $t; 
		
    my $sth = $self->{dbh}->prepare($query);
    my $rv;

   

   	$rv = $sth->execute( $self->email, $self->type )
		or croak "cannot do statement (at: remove from list)! $DBI::errstr\n";

   #warn '$rv ' . $rv; 
    $sth->finish;
	if($args->{-log_it} == 1) { 
		if ($DADA::Config::LOG{subscriptions}) { 
		    $self->{'log'}->mj_log( 
				$self->{list},
		        "Unsubscribed from " . $self->{list} . "." . $self->type,
				$self->email
			);
		}
	}
    undef $self;
	return $rv;	

}

sub member_of {
	
    my $self = shift;	
    my $query =
        'SELECT list_type FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE email = ? AND  list = ? AND list_status = ?';
    return $self->{dbh}->selectcol_arrayref( $query, {},
        ( $self->email,  $self->{list}, 1 ) );

}

1;
