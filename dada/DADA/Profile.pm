package DADA::Profile;

use lib qw (../../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);
use DADA::Config; 

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

    if ( !exists $args->{ -password } ) {
	    $args->{ -password } = {};
    }

	if($self->exists({-email => $args->{-email}}) >= 1){ 
		$self->drop({-email => $args->{-email}}); 
	 }

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $self->subscriber_fields };
    my @values;


    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . '(email, password) VALUES (?, ?)';

    warn 'Query: ' . $query
     if $t;

    my $sth     = $self->{dbh}->prepare($query);

    $sth->execute(
        $args->{ -email },
		$args->{ -password },
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



