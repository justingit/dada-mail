package DADA::Profile::Fields::baseSQL;
use lib qw(
	../../../ 
	../../perllib
);
use strict; 

use Carp qw(carp croak confess);

use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile_Fields};

sub insert {

    my $self = shift;
    my ($args) = @_;
	if(!exists($self->{email})){ 
 	   if ( !exists $args->{ -email } ) {
	        croak("You MUST supply an email address in the -email parameter!");
	    }
	    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
	        croak("You MUST supply an email address in the -email parameter!");
	    }
	}
	else { 
		$args->{ -email } = $self->{email}; 
	}
	
    if ( !exists $args->{ -fields } ) {
        $args->{ -fields } = {};
    }
    if ( !exists( $args->{ -confirmed } ) ) {
        $args->{ -confirmed } = 1;
    }

	# writeover
	# preserve,
	
	if( !exists($args->{ -mode } ) ) { 
		$args->{ -mode } = 'writeover';
	}
	
    # See, how I'm doing this, after the confirmed thing? Good idea?
    if ( $args->{ -confirmed } == 0 ) {
        $args->{ -email } = '*' . $args->{ -email };
    }

	my $fields_exists = $self->exists( 
		{
			-email => $args->{ -email } 
		} 
	);
	
	if($fields_exists && $args->{-mode} eq 'preserve'){ 
			# this is kinda weird, but: 
			$self->{email} = $args->{ -email };
			return 1; 
	}		
		
	if($args->{-mode} eq 'preserve_if_defined' && $fields_exists){ 
		$self->{email} = $args->{ -email };
		unless($self->are_empty) { 
			return 1; 
		}
		else { 
			# Well, do what's below, 
		}
	}
	
	if ($fields_exists) {
				
		my $tmp_pf = undef; 
		if(exists($self->{-dpfm_obj})){ 
			$tmp_pf = DADA::Profile::Fields->new(
				{
					-email    => $args->{-email},
					-dpfm_obj => $self->{-dpfm_obj}, 
				}
			); 
        }
		else { 
			$tmp_pf = DADA::Profile::Fields->new(
				{
					-email => $args->{-email}
					
				}
			); 
		}

		$tmp_pf->remove;
		undef $tmp_pf; 
 	}

    my $sql_str             = '';
    my $place_holder_string = '';

    my @order               = @{ $self->{manager}->fields };
    my @values;

    if ( $order[0] ) {
        for my $field (@order) {
            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            if(exists($args->{ -fields }->{$field})){ 
                push ( @values, $args->{ -fields }->{$field} );
            }
            else { 
                push ( @values, '' );               
            }
        }
    }
    $sql_str =~ s/,$//;
    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . '(email'
      . $sql_str . ') 
        VALUES (?' . $place_holder_string . ')';

    warn 'Query: ' . $query
 		if $t;

    my $sth = $self->{dbh}->prepare($query);
	
    $sth->execute( $args->{ -email }, @values )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

	# this is kinda weird, but: 
	$self->{email} = $args->{ -email };

	
	return 1; 
 	
}

sub get {

    my $self = shift;
    my ($args) = @_;

	if(!$self->{email}){ 
		croak "Cannot use this method without passing the '-email' param in, new (get)"; 
	}

    my $sub_fields = $self->{manager}->fields;
	
	if(!$args->{ -dotted }){ 
		$args->{ -dotted } = 0; 
	}
	#if(!exists($args->{-email})){ 
	#	return undef; 
	#}
	#if(! $self->exists({-email => $args->{-email}})) {  
	#	return undef; 
	#}
	
    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_fields_table}
      . " WHERE email = ?";

    #warn 'QUERY: ' . $query . ', $args->{-email}: ' . $args->{ -email }
	#	if $t;

    warn 'QUERY: ' . $query . ', $self->{email}: ' . $self->{ email }
		if $t;



    my $sth = $self->{dbh}->prepare($query);

   # $sth->execute( $args->{ -email } )
	$sth->execute( $self->{ email } )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $hashref   = {};
    my $n_hashref = {};

    my ( $n, $d ) = split ( '@', $self->{ email }, 2 );
    $n_hashref->{email_name}   = $n;
    $n_hashref->{email_domain} = $d;
    $n_hashref->{email}        = $self->{email};
    
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        for ( @{$sub_fields} ) {
            $n_hashref->{$_} = $hashref->{$_};
        }
		last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        for ( keys %$n_hashref ) {
            $dotted->{ 'subscriber.' . $_ } = $n_hashref->{$_};
        }

		# require Data::Dumper; 
		# carp Data::Dumper::Dumper($dotted); 
        return $dotted;
    }
    else {
		# require Data::Dumper; 
		# carp Data::Dumper::Dumper($n_hashref);
        return $n_hashref;

    }

    carp "Didn't fetch the profile?!";
    return undef;

}


sub are_empty { 
	my $self = shift; 
	my $empty = 1; 
	my $f = $self->get; 

	delete($f->{email_name});
	delete($f->{email_domain});
	delete($f->{email});
	
	if(!keys %{$f}){ 
		return 1; 
	}

	for my $k(keys %{$f}){ 
		if(defined($f->{$k}) && length($f->{$k}) > 0){ 
			return 0; 
		}
		else { 
			# ... 
		}
	}	
	return 1; 
}

sub exists {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT COUNT(*) from '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . ' WHERE email = ? ';

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{ -email } )
      or croak "cannot do statement (at exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

    return $row[0];
}

sub remove {
	
    my $self = shift;
    my ($args) = @_;

	#if(!exists($args->{-email})){ 
	#	return undef; 
	#}
	#if(! $self->exists({-email => $args->{-email}})) {  
	#	return undef; 
	#}
	
	if(!$self->{email}){ 
		croak "Cannot use this variable without passing the '-email' param in, new (remove) (1)"; 
	}
	
    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . ' WHERE email = ? ';

    #warn 'QUERY: ' . $query . ' (' . $args->{ -email } . ')'
	warn 'QUERY: ' . $query . ' (' . $self->{ email } . ')'
		if $t;

    my $sth = $self->{dbh}->prepare($query);

    #my $rv = $sth->execute( $args->{ -email } )
	my $rv = $sth->execute( $self->{ email } )
      or croak "cannot do statement (at remove)! $DBI::errstr\n";
    $sth->finish;
    return $rv;

}



sub can_have_subscriber_fields {

    my $self = shift;
    return 1;
}

1;
