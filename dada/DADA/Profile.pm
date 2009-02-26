package DADA::Profile;

use lib qw (../../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);
use DADA::Config; 
use DADA::App::Guts; 

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL}; 


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
	$self->{sql_params} = {%DADA::Config::SQL_PARAMS};

	if(!exists($args->{-email})){ 
		croak "you must pass an email address in, '-email'"; 
	}
	else { 
		$self->{email} = $args->{-email}; 
	}


	my $dbi_obj = undef; 
	if($DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/){ 
		require DADA::App::DBIHandle; 
		$dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}
}


sub insert { 

    my $self   = shift;
    my ($args) = @_;

#    if ( !exists $self->{ email } ) {
#        croak("You MUST supply an email address in the -email paramater!");
#    }
#    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
#        croak("You MUST supply an email address in the -email paramater!");
#    }

    if ( !exists ( $args->{ -password } ) ) {
	    $args->{ -password } = '';
    }

    if ( !exists $args->{ -activated } ) {
	    $args->{ -activated } = 0;
    }

# ? 
#	if($self->exists({-email => $args->{-email}}) >= 1){ 
#		$self->drop({-email => $args->{-email}}); 
#	 }
	
    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . '(email, password, auth_code, activated) VALUES (?, ?, ?, ?)';

    warn 'Query: ' . $query
     if $t;

    my $sth     = $self->{dbh}->prepare($query);

    $sth->execute(
        $self->{  email },
		$args->{ -password },
		$args->{ -auth_code },
		$args->{ -activated }, 
     )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
	$sth->finish;
	

	return 1; 
	
}




sub get {

    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_table}
      . " WHERE email = ?";

	warn 'QUERY: ' . $query
		if $t; 


    my $sth = $self->{dbh}->prepare($query);
		

    $sth->execute($self->{email})
      or croak "cannot do statement (at get)! $DBI::errstr\n";
	
	my $profile_info = {};
	my $hashref      = {};
	
	#warn $sth->dump_results(undef, undef, undef, *STDERR);
	 
  	FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        #warn '$hashref->{$_} ' . $hashref->{$_} ;
    	$profile_info = $hashref;
        
    last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        foreach ( keys %$profile_info ) {
            $dotted->{ 'profile.' . $_ } = $profile_info->{$_};
        }
        return $dotted;
    }
    else {
        return $profile_info;
		

    }

    carp "Didn't fetch the subscriber profile?!";
    return undef;

}



sub subscribed_to { 

	my $self   = shift; 
	my ($args) = @_; 
	my $subscriptions = [];
	my @available_lists = DADA::App::Guts::available_lists(); 
	
	require DADA::MailingList::Subscribers; 
	require DADA::MailingList::Settings; 
	
	my $list_names = {};
	
	foreach(@available_lists){ 
		my $lh = DADA::MailingList::Subscribers->new({-list => $_});
		 
		if($lh->check_for_double_email(
          -Email => $self->{email},
          #-Type  => $args->{ -type }
        )){ 
			push(@$subscriptions, $_); 
		}
		
		# This needs its own method...
	
			my $ls = DADA::MailingList::Settings->new({-list => $_}); 
			$list_names->{$_} = $ls->param('list_name'); 
		
	}
	
	if($args->{-html_tmpl_params}){ 
		my $lt = {};
		my $html_tmpl = [];
		foreach(@$subscriptions){ 
			$lt->{$_} = 1; 
		}
		foreach(@available_lists){ 
			if(exists($lt->{$_})){ 
				push(@$html_tmpl, {PROGRAM_URL => $DADA::Config::PROGRAM_URL, list => $_, list_name => $list_names->{$_}, subscribed => 1, email => $self->{email} });
			}
			else { 
				push(@$html_tmpl, {PROGRAM_URL => $DADA::Config::PROGRAM_URL, list => $_, list_name =>  $list_names->{$_}, subscribed => 0, email => $self->{email} });
			}
		}
		return $html_tmpl; 
	}
	else { 
		return $subscriptions;
	}
	
	
}



sub is_activated { 
	my $self   = shift; 
	my ($args) = @_;

	my $query = 'SELECT activated FROM ' . 
				$DADA::Config::SQL_PARAMS{profile_table}
    			 . ' WHERE email = ?'; 

	my $sth     = $self->{dbh}->prepare($query);

	warn 'QUERY: ' . $query; 

	$sth->execute($args->{ -email })
		or croak "cannot do statement (is_activated)! $DBI::errstr\n";	 
	my @row = $sth->fetchrow_array();


	my $activated = 0; 
	FETCH: while (my $hashref = $sth->fetchrow_hashref ) {
    	$activated = $hashref->{activated};
        last FETCH; 
    }

    $sth->finish;
	return $activated; 
}

sub exists { 
	my $self   = shift; 
	my ($args) = @_;
	
	my $query = 'SELECT COUNT(*) FROM ' . 
				$DADA::Config::SQL_PARAMS{profile_table}
    			 . ' WHERE email = ?'; 
				
	my $sth     = $self->{dbh}->prepare($query);

	warn 'QUERY: ' . $query; 
	
	$sth->execute($self->{email})
		or croak "cannot do statement (at exists)! $DBI::errstr\n";	 
	my @row = $sth->fetchrow_array();
    $sth->finish;
   
   return $row[0];

}




sub is_valid_password { 
	
	my $self   = shift; 
	my ($args) = @_; 
	my $query = 'SELECT email, password FROM ' . 
				$DADA::Config::SQL_PARAMS{profile_table} . 
				' WHERE email = ?'; 
	warn 'QUERY: ' . $query; 
	
	my $sth     = $self->{dbh}->prepare($query);

	$sth->execute($self->{ email })
		or croak "cannot do statement (at is_valid_password)! $DBI::errstr\n";	 
		
	FETCH: while (my $hashref = $sth->fetchrow_hashref ) {
        
		#warn '$hashref->{password} ' . $hashref->{password} ; 
	#	warn '$args->{ -password } ' . $args->{ -password }; 
    	if($hashref->{password} eq $args->{ -password }){ 
			$sth->finish; 	
			return 1; 
		}
		else { 
			$sth->finish; 	
			return 0; 
		}
   
        last FETCH; # which will never be called...
    }

}


sub validate_registration { 
	
	my $self   = shift; 
	my ($args) = @_; 
	
	my $status = 1; 
	my $errors = { 
		email_no_match => 0, 
		profile_exists => 0, 
		invalid_email  => 0, 
		password_blank => 0, 
		captcha_failed => 0, 
	};
	
	if($args->{-email} ne $args->{-email_again}){ 
		$errors->{email_no_match} = 1;
		$status 				  = 0;
	}
	if(check_for_valid_email($args->{-email}) == 0){
		# ... 
	}
	else { 
		$errors->{invalid_email}  = 1;
		$status 				  = 0;		
	} 
	if($self->exists({ -email => $args->{-email} })){ 
		$errors->{profile_exists} = 1;
		$status 				  = 0;
	}	
	if(length($args->{-password}) == 0){ 
		$errors->{password_blank} = 1;
		$status 				  = 0;		
	}
	
	
	my $can_use_captcha = 0; 
	my $cap             = undef; 
	if($DADA::Config::PROFILE_ENABLE_CAPTCHA == 1){ 
		eval { require DADA::Security::AuthenCAPTCHA; };
		if(!$@){ 
			$can_use_captcha = 1;        
		}
	}
   if($can_use_captcha == 1){
		$cap = DADA::Security::AuthenCAPTCHA->new; 
		 my $result = $cap->check_answer(
                $DADA::Config::RECAPTCHA_PARAMS->{private_key}, 
                $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'}, 
                $args->{-recaptcha_challenge_field},  
                $args->{-recaptcha_response_field},
            );
		if($result->{is_valid} == 1){ 
			# ...
		}
		else { 
			$errors->{captcha_failed} = 1;
			$status 				  = 0;
		}
	}		
	
	return ($status, $errors);
	
}

sub update { 
	
	my $self   = shift; 
	my ($args) = @_;
	my $orig = $self->get();
	
	foreach(keys %$orig){ 
		next if $_ eq 'email'; 
		if(exists($args->{'-'.$_})){
			$orig->{$_} = $args->{'-'.$_};
		}
	}  	
	$self->drop();
	$orig->{-email} = $self->{email}; 
	
	# This is kind of strange: 
	my $new = {}; 
	foreach(keys %$orig){ 
		$new->{'-'.$_} = $orig->{$_};
	}
	$self->insert($new); 
	
}



sub setup_profile { 
	my $self   = shift; 
	my ($args) = @_;
	# Pop it in, 

	$self->insert(
		{
			-password  => $args->{-password}, 
		}
	);
	# Spit it out:
	$self->send_profile_activation_email();
	return 1; 
}




sub send_profile_activation_email { 
	my $self   = shift; 
	my ($args) = @_; 

	my $auth_code = $self->set_auth_code($args); 
	require DADA::App::Messages; 
	DADA::App::Messages::send_generic_email(
	{
       -email   => $self->{email},
	   -headers => { 
        	Subject => $DADA::Config::PROFILE_ACTIVATION_MESSAGE_SUBJECT, 
			From    => $DADA::Config::PROFILE_EMAIL, 
			To      => $self->{email},
    	},
		-body      => $DADA::Config::PROFILE_ACTIVATION_MESSAGE, 
		-tmpl_params => { 
			-vars => {
					authorization_code => $auth_code,
					email              => $self->{email}, 
			},
		}, 
	}
	);

	return 1; 
	
}




sub send_profile_reset_password { 
	my $self   = shift; 
	my ($args) = @_; 

	my $auth_code = $self->set_auth_code($args); 
	require DADA::App::Messages; 
	DADA::App::Messages::send_generic_email(
	{
       -email   => $self->{email},
	   -headers => { 
        	Subject => $DADA::Config::PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT, 
			From    => $DADA::Config::PROFILE_EMAIL, 
			To      => $self->{email},
    	},
		-body      => $DADA::Config::PROFILE_RESET_PASSWORD_MESSAGE, 
		-tmpl_params => { 
			-vars => {
					authorization_code => $auth_code,
					email              => $self->{email}, 
			},
		}, 
	}
	);
	return 1; 
}



sub validate_profile_activation {
	
	my $self   = shift; 
	my ($args) = shift; 
	
	my $status = 1; 
	my $errors = {
		invalid_auth_code => 0, 
	};
	
	my $profile = $self->get($args); 
	#warn '$profile->{auth_code} ' . $profile->{auth_code}; 
	#warn '$args->{-auth_code}' . $args->{-auth_code}; 
	
	if($profile->{auth_code} eq $args->{-auth_code}){ 
		# ...
	}
	else { 
		$errors->{invalid_auth_code} = 1; 
		$status                      = 0; 
	}

	return ($status, $errors); 
}


sub activate { 
	my $self   = shift; 
	my ($args) = shift;	
	
	if(!exists($args->{-activate})){ 
		$args->{-activate} = 1;
	}
	
	my $query = 'UPDATE ' . 
				 $DADA::Config::SQL_PARAMS{profile_table} . 
				' SET activated    = ? ' . 
				' WHERE email      = ? ';
				
	my $sth = $self->{dbh}->prepare($query); 

	warn 'QUERY: ' . $query
		if $t; 

	my $rv = $sth->execute($args->{-activate}, $self->{ email })
		or croak "cannot do statment (at activate)! $DBI::errstr\n";
	$sth->finish;
	return 1; 
}

sub set_auth_code { 
	
	my $self   = shift; 
	my ($args) = @_;
	
	#if( ! exists($args->{ -activated } )) {
	#	 $args->{ -activated } = 0;
	#}
	
	if($self->exists($args)){ 
		my $auth_code = $self->rand_str;
		my $query = 'UPDATE ' . 
					 $DADA::Config::SQL_PARAMS{profile_table} . 
					' SET auth_code	   = ? ' . 
					' WHERE email   = ? ';
		my $sth = $self->{dbh}->prepare($query); 

		warn 'QUERY: ' . $query
			if $t; 
		my $rv = $sth->execute( $auth_code, $self->{ email } )
			or croak "cannot do statment (at set_auth_code)! $DBI::errstr\n";
		$sth->finish;
		return $auth_code; 
	}
	else { 
		die "user does not exist!"; 
	}
	
}



sub drop {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ? ';

	my $sth = $self->{dbh}->prepare($query); 
    
	warn 'QUERY: ' . $query . ' ('. $self->{ email } . ')'
		if $t; 
	my $rv = $sth->execute( $self->{ email } )
      or croak "cannot do statment (at drop)! $DBI::errstr\n";
    $sth->finish;
    return $rv;
}



sub rand_str { 
	my $self = shift; 
	my $size = shift || 16;
	require DADA::Security::Password; 
 	return DADA::Security::Password::generate_rand_string(undef, $size);
}



