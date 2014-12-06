package DADA::MailingList::Subscriber::baseSQL;

use strict;
use lib qw(../../../ ../../../perllib);
use Carp qw(carp croak);
use DADA::Config;
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList};




sub add {

    my $class = shift;
    my ($args) = @_;

    if ($t) {

        warn "Method: add()";
        require Data::Dumper;
        warn "args: " . Data::Dumper::Dumper($args);
    }

    if ( !exists( $args->{-log_it} ) ) {
        $args->{-log_it} = 1;
    }

    my $lh = undef;

    if ( exists( $args->{-dpfm_obj} ) ) {
        warn "reusing dpfm_obj for lh obj"
          if $t;
        $lh = DADA::MailingList::Subscribers->new(
            {
                -list     => $args->{-list},
                -dpfm_obj => $args->{-dpfm_obj},
            }
        );

    }
    else {
        warn "creating new lh obj"
          if $t;
        $lh =
          DADA::MailingList::Subscribers->new( { -list => $args->{-list} } );
    }

    if ( !exists $args->{-type} ) {
        $args->{-type} = 'list';
    }
    if ( !exists $args->{-email} ) {
        croak("You MUST supply an email address in the -email parameter!");
    }
    if ( length( strip( $args->{-email} ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email parameter!");
    }

    if ( !exists( $args->{-confirmed} ) ) {
        $args->{-confirmed} = 1;
    }

    if ( !exists( $args->{-dupe_check}->{-enable} ) ) {
        $args->{-dupe_check}->{-enable} = 0;
    }
    if ( !exists( $args->{-dupe_check}->{-on_dupe} ) ) {
        $args->{-dupe_check}->{-on_dupe} = 'ignore_add';
    }

    if ($t) {
        warn "args after processing: " . Data::Dumper::Dumper($args);
    }
    if ( $args->{-dupe_check}->{-enable} == 1 ) {
        warn '$args->{ -dupe_check }->{-enable}:' . $args->{-dupe_check}->{-enable}
          if $t;

        if (
            $lh->check_for_double_email(
                -Email => $args->{-email},
                -Type  => $args->{-type}
            ) == 1
          )
        {
            if ( $args->{-dupe_check}->{-on_dupe} eq 'error' ) {
                croak 'attempt to to add: "'
                  . $args->{-email}
                  . '" to list: "'
                  . $args->{-list} . '.'
                  . $args->{-type}
                  . '" (email already subcribed)';
            }
            elsif ( $args->{-dupe_check}->{-on_dupe} eq 'ignore_add' ) {
                carp 'attempt to to add: "'
                  . $args->{-email}
                  . '" to list: "'
                  . $args->{-list} . '.'
                  . $args->{-type}
                  . '" (email already subcribed) - ignoring.';
                return undef;
            }
            else {
                croak "unknown option, " . $args->{-dupe_check}->{-on_dupe};
            }
        }
        else {
            #...
        }
    }
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

    $sth->execute( $args->{-email}, $args->{-list}, $args->{-type}, 1 )
      or croak "cannot do statement (at add_subscriber)! $DBI::errstr\n";
    $sth->finish;

    if ( $args->{-type} eq 'list' || $args->{-type} eq 'sub_confirm_list' ) { # Erm, invitelist, as well?
    

        # So, confirmed would e set to, "0", rather than take the default (1)
        # and activated would be, "0"?
        # "preserve" setting should only be available for List Owners?

        ##################
        # Profile Fields #
        ##########################################################################
        warn 'Profile Fields'
          if $t;
         if (! exists $args->{-fields} ) {    
             $args->{-fields}  = {};
         }   
                
        if (keys %{ $args->{-fields} }) { 
            my $fields = undef;

            if ( exists( $args->{-dpfm_obj} ) ) {
                $fields = DADA::Profile::Fields->new(
                    {
                        -dpfm_obj => $args->{-dpfm_obj},
                    }
                );
            }
            else {
                $fields = DADA::Profile::Fields->new;
            }
            my $insert_args = {
                -email     => $args->{-email},
                -fields    => $args->{-fields},
                -confirmed => $args->{-confirmed},
                -mode      => $args->{-fields_options}->{-mode},
            };
            warn 'Inserting fields with args: ' . Data::Dumper::Dumper($insert_args)
              if $t;
            $fields->insert($insert_args);
        }
        else {
            warn 'Not doing anything w/Profile Fields'
              if $t;
        }
        ##########################################################################

        ###########
        # Profile #
        ##########################################################################
        warn 'Profiles'
          if $t;

        # We only do this, if a -profile param is sent.
        if ( exists( $args->{-profile} ) && keys( %{ $args->{-profile} } ) ) {

            # And ONLY if we get a password:
            if ( $args->{-profile}->{-password} ) {
                warn 'A Profile Password has been passed'
                  if $t;
                require DADA::Profile;
                my $prof = DADA::Profile->new( { -email => $args->{-email} } );
                if ($prof) {
                    warn '$prof is defined'
                      if $t;
                    if ( $prof->exists ) {
                        warn 'Profile for ' . $args->{-email} . ' exists'
                          if $t;
                        warn '$args->{ -profile }->{-mode}: ' . $args->{-profile}->{-mode}
                          if $t;

                        if ( $args->{-profile}->{-mode} eq 'writeover' ) {

                            # Or, update, I guess.
                            warn 'removing Profile'
                              if $t;
                            $prof->remove();
                            my $insert_profile_args = {
                                -password  => $args->{-profile}->{-password},
                                -activated => 1,
                            };
                            warn 'inserting new Profile with args:' . Data::Dumper::Dumper($insert_profile_args)
                              if $t;
                            $prof->insert($insert_profile_args);
                        }
                        elsif ( $args->{-profile}->{-mode} eq 'preserve_if_defined' ) {

                            # ... then, nothin'
                        }
                    }
                    else {
                        # Then, we make a new one up!
                        my $insert_profile_args = {
                            -password  => $args->{-profile}->{-password},
                            -activated => 1,
                        };
                        warn 'creating a new Profile: ' . Data::Dumper::Dumper($insert_profile_args)
                            if $t; 
                        $prof->insert($insert_profile_args);
                    }
                }
            }
        }
        ##########################################################################

    }

    my $added_args = {
        -list  => $args->{-list},
        -email => $args->{-email},
        -type  => $args->{-type},
    };
    if ( exists( $args->{-dpfm_obj} ) ) {
        $added_args->{-dpfm_obj} = $args->{-dpfm_obj};
    }

    warn 'Subscriber add args: ' . Data::Dumper::Dumper($added_args)
      if $t;

    my $added = DADA::MailingList::Subscriber->new($added_args);
    if ( $args->{-log_it} == 1 ) {
        if ( $DADA::Config::LOG{subscriptions} == 1 ) {
            $added->{'log'}
              ->mj_log( $added->{list}, 'Subscribed to ' . $added->{list} . '.' . $added->type, $added->email );
        }
    }

    $t = 0;

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
	
	if(! defined($self->type)){ 
		croak("'type' needs to be defined!"); 
	}
	
    my ($args) = @_;

    if ( !exists $args->{ -to } ) {
        croak "You must pass a value in the -to parameter!";
    }

    if ( $self->{lh}->allowed_list_types( $args->{ -to }) != 1 ) {
        croak "list type passed in, -to (" . $args->{ -to } . ") is not valid 1";
    }
	if(!exists($args->{-confirmed})){ 
		$args->{-confirmed} = 0; 
	}

	
	if(!exists($args->{-fields_options}->{-mode})){ 
		$args->{-fields_options}->{-mode} = 'preserve_if_defined'; 
	}
	
	
	###
	# This is sort of strange,
	my $make_new_profile = 0; 
	
	if($self->{lh}->can_have_subscriber_fields == 1){ 
		if($args->{-confirmed} == 1){ 
			
			
			require DADA::Profile::Fields; 
			my $dpf = DADA::Profile::Fields->new;
			
			my $og_profile_exists = $dpf->exists({-email => $self->email}); # no, "*"; 
			
			if($og_profile_exists == 0){ 
				$make_new_profile = 1;
			}
			elsif($args->{-fields_options}->{-mode} eq 'writeover') { 
				$make_new_profile = 1; 
			# Is there already a Profile for this address? 
			} 
			elsif($args->{-fields_options}->{-mode} eq 'preserve' && $og_profile_exists) { 
				$make_new_profile = 1; 
			}
			elsif($args->{-fields_options}->{-mode} eq 'preserve_if_defined' && $og_profile_exists){ 
				
				my $dpf_empty_check = DADA::Profile::Fields->new({-email => $self->email}); 
				# I don't like this juggling around. 				
				if($dpf_empty_check->are_empty) { 
					$make_new_profile = 1; 
				}
				undef $dpf_empty_check; 
			}


			if($dpf->exists({-email => '*' . $self->email})){ 
				my $dpf2 = DADA::Profile::Fields->new({-email => '*' . $self->email});
				if($make_new_profile == 1) { 
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
				else { 
					$dpf2->remove; # This removes the profile for, *asterick email address. 
				}
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
    else { # I'm assumin this is, "writeover_check" 
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

		$query .=' AND list = ' . $self->{dbh}->quote($self->{list}); 
    my $sth = $self->{dbh}->prepare($query);

    my $rv =
      $sth->execute( $args->{ -to }, $self->type, $self->email )
      or croak "cannot do statement (at move_subscriber)! $DBI::errstr\n";

    if ( $rv == 1 ) {
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
        carp "Something's wrong. Returned $rv rows, expected 1 - have >1 copies of the email address been moved?";
    }
}

sub remove {

    my $self = shift;

	if(! defined($self->type)){ 
		croak("'type' needs to be defined!"); 
	}

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

   
	if($t){ 
		require Data::Dumper; 
		warn 'execute params: ' . Data::Dumper::Dumper([$self->email, $self->type]); 
	}
   	$rv = $sth->execute( $self->email, $self->type )
		or croak "cannot do statement (at: remove from list)! $DBI::errstr\n";
    $sth->finish;

    # TODO: I'm just bummed that when GLOBAL UNSUB is enabled, this only logs the unsub for this list. 
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
	my ($args) = @_;
	
    my $query =
        'SELECT list_type FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE email = ? AND  list = ? AND list_status = ?';
    my $list_types = $self->{dbh}->selectcol_arrayref( $query, {},
        ( $self->email,  $self->{list}, 1 ) );

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
