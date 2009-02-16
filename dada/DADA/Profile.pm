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

    if ( !exists $args->{ -email } ) {
        croak("You MUST supply an email address in the -email paramater!");
    }
    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email paramater!");
    }

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
        $args->{ -email },
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

	warn 'QUERY: ' . $query . ', $args->{-email}: ' . $args->{-email}
		if $t; 


    my $sth = $self->{dbh}->prepare($query);
		

    $sth->execute($args->{-email})
      or croak "cannot do statement (at get)! $DBI::errstr\n";
	
	my $profile_info = {};
  	FETCH: while ( my $hashref = $sth->fetchrow_hashref ) {
        
    	$profile_info->{$_} = $hashref->{$_};
        
    last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        foreach ( keys %$profile_info ) {
            $dotted->{ 'subscriber_profile.' . $_ } = $profile_info->{$_};
        }
        return $dotted;
    }
    else {
        return $profile_info;
		

    }

    carp "Didn't fetch the subscriber profile?!";
    return undef;

}




sub exists { 
	my $self   = shift; 
	my ($args) = @_;
	
	my $query = 'SELECT COUNT(*) FROM ' . 
				$DADA::Config::SQL_PARAMS{profile_table}
    			 . ' WHERE email = ? '; 
				
	my $sth     = $self->{dbh}->prepare($query);

	warn 'QUERY: ' . $query; 
	
	$sth->execute($args->{ -email })
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

	$sth->execute($args->{ -email })
		or croak "cannot do statement (at is_valid_password)! $DBI::errstr\n";	 
		
	FETCH: while (my $hashref = $sth->fetchrow_hashref ) {
        
		warn '$hashref->{password} ' . $hashref->{password} ; 
		warn '$args->{ -password } ' . $args->{ -password }; 
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
	
	return ($status, $errors);
	
}
sub setup_profile { 
	my $self   = shift; 
	my ($args) = @_;
	# Pop it in, 

	$self->insert(
		{
			-email     => $args->{-email},
			-password  => $args->{-password}, 
		}
	);
	# Spit it out:
	$self->send_profile_activation_email($args);
	return 1; 
}

sub send_profile_activation_email { 
	my $self   = shift; 
	my ($args) = @_; 

	my $auth_code = $self->set_auth_code($args); 
	require DADA::App::Messages; 
	my $msg = <<EOF

Heya, Here's the authorization link to reset your password - click it!

<!-- tmpl_var PROGRAM_URL -->?f=profile_reset_password&email=<!-- tmpl_var email -->&auth_code=<!-- tmpl_var authorization_code --> 

-- <!-- tmpl_var PROGRAM_NAME --> 

EOF
; 

	DADA::App::Messages::send_generic_email(
	{
       -email   => $args->{-email},
	   -headers => { 
        	Subject => 'Your Authorization Code!', 
			From    => 'justin@skazat.com', 
			To      => $args->{-email},
    	},
		-body      => $msg, 
		-tmpl_params => { 
			-vars => {
					authorization_code => $auth_code,
					email              => $args->{-email}, 
			},
		}, 
	}
	);

	return 1; 
	
}



sub validate_profile_activation {}

sub set_auth_code { 
	
	my $self   = shift; 
	my ($args) = @_;
	
	if( ! exists($args->{ -activated } )) {
		 $args->{ -activated } = 0;
	}
	
	if($self->exists($args)){ 
		my $auth_code = $self->rand_str;
		my $query = 'UPDATE ' . 
					 $DADA::Config::SQL_PARAMS{profile_table} . 
					' SET auth_code	   = ?, ' . 
					'     activated    = ? ' . 
					' WHERE email   = ? ';
		my $sth = $self->{dbh}->prepare($query); 

		warn 'QUERY: ' . $query
			if $t; 
		my $rv = $sth->execute( $auth_code, $args->{ -activated }, $args->{ -email } )
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
    
	warn 'QUERY: ' . $query . ' ('. $args->{ -email } . ')'
		if $t; 
	my $rv = $sth->execute( $args->{ -email } )
      or croak "cannot do statment (at drop)! $DBI::errstr\n";
    $sth->finish;
    return $rv;
}



sub rand_str { 
	my $self = shift; 
	require DADA::Security::Password; 
 	return DADA::Security::Password::generate_rand_string(undef, 16);
}



