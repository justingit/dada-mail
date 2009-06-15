package DADA::Profile::Fields::baseSQL;
use lib qw(
	../../../ 
	../../perllib
);
use strict; 

use Carp qw(carp croak confess);
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile_Fields};

sub _columns {

	# DEV: TODO: CACHE!
    my $self  = shift;
    my $query =
      "SELECT * FROM "
      . $self->{sql_params}->{profile_fields_table}
      . " WHERE (1 = 0)";
    warn 'Query: ' . $query
		if $t; 
		
    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (at: columns)! $DBI::errstr\n";
    my $i;
    my @cols;
    for ( $i = 1 ; $i <= $sth->{NUM_OF_FIELDS} ; $i++ ) {
        push ( @cols, $sth->{NAME}->[ $i - 1 ] );
    }
    $sth->finish;
    return \@cols;

}

sub fields {

    my $self = shift;
    my ($args) = @_;

    my $l = [];

    if ( exists( $self->{cache}->{fields} ) ) {
        $l = $self->{cache}->{fields};
    }
    else {

       # I'm assuming, "columns" always returns the columns in the same order...
        $l = $self->_columns;
        $self->{cache}->{fields} = $l;
    }

    if ( !exists( $args->{ -show_hidden_fields } ) ) {
        $args->{ -show_hidden_fields } = 1;
    }
    if ( !exists( $args->{ -dotted } ) ) {
        $args->{ -dotted } = 0;
    }

    # We just want the fields *other* than what's usually there...
    my %omit_fields = (
        email_id    => 1,
        fields_id   => 1,
        email       => 1,
        list        => 1,
        list_type   => 1,
        list_status => 1
    );

    my @r;
    foreach (@$l) {

        if ( !exists( $omit_fields{$_} ) ) {

            if ( $args->{ -show_hidden_fields } == 1 ) {
                if ( $args->{ -dotted } == 1 ) {
                    push ( @r, 'subscriber.' . $_ );
                }
                else {
                    push ( @r, $_ );
                }
            }
            elsif ( $DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX eq undef ) {
                if ( $args->{ -dotted } == 1 ) {
                    push ( @r, 'subscriber.' . $_ );
                }
                else {

                    push ( @r, $_ );
                }
            }
            else {

                if (   $_ !~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/
                    && $args->{ -show_hidden_fields } == 0 )
                {
                    if ( $args->{ -dotted } == 1 ) {
                        push ( @r, 'subscriber.' . $_ );
                    }
                    else {

                        push ( @r, $_ );
                    }
                }
                else {

                    # ...
                }
            }
        }
    }

    return \@r;
}

sub insert {

    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{ -email } ) {
        croak("You MUST supply an email address in the -email paramater!");
    }
    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email paramater!");
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
			return 1; 
	}
	
	if ($fields_exists) {
        $self->remove( 
			{ 
				-email => $args->{ -email } 
			} 
		);
 	}

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $self->fields };
    my @values;

    if ( $order[0] ) {
        foreach my $field (@order) {
            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            push ( @values, $args->{ -fields }->{$field} );
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

	return 1; 
 	
}

sub get {

    my $self = shift;
    my ($args) = @_;
    my $sub_fields = $self->fields;
	
	if(!$args->{ -dotted }){ 
		$args->{ -dotted } = 0; 
	}
	if(!exists($args->{-email})){ 
		return undef; 
	}
	if(! $self->exists({-email => $args->{-email}})) {  
		return undef; 
	}
    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_fields_table}
      . " WHERE email = ?";

    warn 'QUERY: ' . $query . ', $args->{-email}: ' . $args->{ -email }
		if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{ -email } )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $hashref   = {};
    my $n_hashref = {};

    my ( $n, $d ) = split ( '@', $args->{-email}, 2 );
    $n_hashref->{email_name}   = $n;
    $n_hashref->{email_domain} = $d;
    $n_hashref->{email}        = $args->{-email};
    
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        foreach ( @{$sub_fields} ) {
            $n_hashref->{$_} = $hashref->{$_};
        }
		last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        foreach ( keys %$n_hashref ) {
            $dotted->{ 'subscriber.' . $_ } = $n_hashref->{$_};
        }

        return $dotted;
    }
    else {
        return $n_hashref;

    }

    carp "Didn't fetch the profile?!";
    return undef;

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

	if(!exists($args->{-email})){ 
		return undef; 
	}
	if(! $self->exists({-email => $args->{-email}})) {  
		return undef; 
	}
	
    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . ' WHERE email = ? ';

    warn 'QUERY: ' . $query . ' (' . $args->{ -email } . ')'
		if $t;

    my $sth = $self->{dbh}->prepare($query);

    my $rv = $sth->execute( $args->{ -email } )
      or croak "cannot do statment (at remove)! $DBI::errstr\n";
    $sth->finish;
    return $rv;

}

sub add_field {

    my $self = shift;

    #DEV: Add testing of parameters!!!!!!

    delete( $self->{cache}->{fields} );

    my ($args) = @_;

    if ( !exists $args->{ -field } ) {
        croak "You must pass a value in the -field paramater!";
    }
    $args->{ -field } = lc( $args->{ -field } );


    if ( !exists( $args->{ -fallback_value } ) ) {
        $args->{ -fallback_value } = '';
    }

    if ( !exists( $args->{ -label } ) ) {
        $args->{ -label } = '';
    }


    my ( $errors, $details ) =
      $self->validate_subscriber_field_name( { -field => $args->{ -field } } );

    if ($errors) {
		my $err; 
        $err = "Something's wrong with the field name you're trying to pass ("
          . $args->{ -field }
          . "). Validate the field name before attempting to add the field with, 'validate_subscriber_field_name' - ";
        foreach ( keys %$details ) {
            if ( $details->{$_} == 1 ) {
                $err .= $args->{ -field } . ' Field Error: ' . $_;
            }
        }
		
		carp $err; 
        return undef;
    }

    my $query =
      'ALTER TABLE '
      . $self->{sql_params}->{profile_fields_table}
      . ' ADD COLUMN '
      . $args->{ -field } . ' TEXT';

    my $sth = $self->{dbh}->prepare($query);

    my $rv = $sth->execute()
      or croak "cannot do statement (at add_field)! $DBI::errstr\n";

    $self->save_field_attributes(
        {
            -field          => $args->{ -field },
            -label          => $args->{ -label },
            -fallback_value => $args->{ -fallback_value },
        }
    );

    delete( $self->{cache}->{fields} );
    return 1;
}

sub save_field_attributes {
    my $self = shift;
    my ($args) = @_;

    my $query = '';

    if ( $self->_field_attributes_exist( { -field => $args->{ -field } } ) ) {
        $query = 'UPDATE '
          . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
          . ' SET label = ? WHERE field = ?';

		 my $sth = $self->{dbh}->prepare($query);

		my $rv = $sth->execute(
			$args->{ -label },
			$args->{ -field }
		)
		or croak "cannot do statement (at save_field_attributes)! $DBI::errstr\n";
		
		undef $sth; 
		undef $rv; 
		
		$query = 'UPDATE '
          . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
          . ' SET fallback_value = ? WHERE field = ?';
		 
		 $sth = $self->{dbh}->prepare($query);

		$rv = $sth->execute(
			$args->{ -fallback_value },
			$args->{ -field }
		)
		or croak "cannot do statement (at save_field_attributes)! $DBI::errstr\n";
    }
    else {
        $query =
          'INSERT INTO '
          . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
          . ' (label, fallback_value, field) values(?,?,?)';
   
		 my $sth = $self->{dbh}->prepare($query);

		    my $rv = $sth->execute(
		        $args->{ -label },
		        $args->{ -fallback_value },
		        $args->{ -field }
		      )
		      or croak "cannot do statement (at save_field_attributes)! $DBI::errstr\n";
 	}

	return 1; 

}

sub _field_attributes_exist {

    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT COUNT(*) FROM '
      . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
      . ' WHERE field = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
    	if $t;

    $sth->execute( $args->{ -field } )
      or croak
      "cannot do statement (at _field_attributes_exist)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

    return $row[0];

}

sub edit_subscriber_field {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -old_name } ) ) {
        croak "You MUST supply the old field name in the -old_name paramater!";
    }
    if ( !exists( $args->{ -new_name } ) ) {
        croak "You MUST supply the new field name in the -new_name paramater!";
    }
	if(! $self->field_exists({-field => $args->{ -old_name }})){ 
		croak 'field, ' . $args->{ -old_name } . ' does not exist!'; 
	}
	if($self->field_exists({-field => $args->{ -new_name }})){ 
		croak 'field, ' . $args->{ -new_name } . ' already exists!'; 
	}
	
    my $query;

    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {

        #ALTER TABLE dada_subscribers RENAME COLUMN oldfoo TO newfoo;
        $query =
          'ALTER TABLE '
          . $self->{sql_params}->{profile_fields_table}
          . ' RENAME COLUMN '
          . $args->{ -old_name } . ' TO '
          . $args->{ -new_name };
    }
    elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {

        $query =
          'ALTER TABLE '
          . $self->{sql_params}->{profile_fields_table}
          . ' CHANGE '
          . $args->{ -old_name } . ' '
          . $args->{ -new_name }
          . '  TEXT';

    }
	elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {
		carp "sorry! renaming columns is currently not available for the SQLite backend!"; 
		return undef; 
	}

    #	die '$query ' . $query;
    $self->{dbh}->do($query)
      or croak
      "cannot do statement (at: edit_subscriber_field)! $DBI::errstr\n";

    delete( $self->{cache}->{fields} );
    return 1;

}

sub remove_field {

    my $self = shift;

    delete( $self->{cache}->{fields} );

    my ($args) = @_;
    if ( !exists( $args->{ -field } ) ) {
        croak "You MUST pass a field name in, -field!";
    }
    $args->{ -field } = lc( $args->{ -field } );

    $self->validate_remove_field_name(
        {
            -field      => $args->{ -field },
            -die_for_me => 1,
        }
    );

    my $query =
      'ALTER TABLE '
      . $self->{sql_params}->{profile_fields_table}
      . ' DROP COLUMN '
      . $args->{ -field };

    my $sth = $self->{dbh}->prepare($query);

    my $rv = $sth->execute()
      or croak
      "cannot do statement! (at: remove_field) $DBI::errstr\n";

    $self->remove_field_attributes( { -field => $args->{ -field } } );
    delete( $self->{cache}->{fields} );

    return 1;

}

sub get_all_field_attributes {

    my $self = shift;
    my ($args) = @_;
    my $v = {};

    #?
    return $v
      if $self->can_have_subscriber_fields == 0;

    my $query =
      'SELECT * FROM '
      . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table};

    warn "QUERY: " . $query
		if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute()
      or croak
      "cannot do statement (at get_all_field_attributes)! $DBI::errstr\n";

    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {

        my $k = $hashref->{field};

        #delete($hashref->{field});
        $v->{$k} = $hashref;
        if ( $v->{$k}->{label} eq '' ) {
            $v->{$k}->{label} = $hashref->{field};
        }
    }

    return $v;

}

sub field_exists {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{ -field } ) ) {
        croak "You must pass a field name in, -field!";
    }

    $args->{ -field } = lc( $args->{ -field } );

    foreach ( @{ $self->fields } ) {
        if ( $_ eq $args->{ -field } ) {
            return 1;
        }
    }
    return 0;
}

sub validate_subscriber_field_name {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{ -field } ) ) {

        croak "You must pass a field name in, -field!";
    }

    if ( !exists( $args->{ -skip } ) ) {
        $args->{ -skip } = [];
    }

    $args->{ -field } = lc( $args->{ -field } );

    my $errors         = {};
    my $thar_be_errors = 0;

    if ( $args->{ -field } eq "" ) {
        $errors->{field_blank} = 1;
    }
    else {
        $errors->{field_blank} = 0;
    }

    if ( length( $args->{ -field } ) > 64 ) {
        $errors->{field_name_too_long} = 1;
    }
    else {
        $errors->{field_name_too_long} = 0;
    }

    if ( $args->{ -field } =~ m/\/|\\/ ) {
        $errors->{slashes_in_field_name} = 1;
    }
    else {
        $errors->{slashes_in_field_name} = 0;
    }

    if ( $args->{ -field } =~ m/\s/ ) {
        $errors->{spaces} = 1;
    }
    else {
        $errors->{spaces} = 0;
    }

    if ( $args->{ -field } =~
        m/\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\>|\<|\-|\0-\037\177-\377/ )
    {
        $errors->{weird_characters} = 1;
    }
    else {
        $errors->{weird_characters} = 0;
    }

    if ( $args->{ -field } =~ m/\"|\'/ ) {
        $errors->{quotes} = 1;
    }
    else {
        $errors->{quotes} = 0;
    }

    if (
        $self->field_exists( { -field => $args->{ -field } } ) == 1 )
    {
        $errors->{field_exists} = 1;
    }
    else {
        $errors->{field_exists} = 0;
    }

    my %omit_fields = (
        email_id     => 1,
        email        => 1,
        list         => 1,
        list_type    => 1,
        list_status  => 1,
        email_name   => 1,
        email_domain => 1,
    );

    if ( exists( $omit_fields{ $args->{ -field } } ) ) {
        $errors->{field_is_special_field} = 1;
    }
    else {
        $errors->{field_is_special_field} = 0;

    }

    my $skip_list = {};
    foreach ( @{ $args->{ -skip } } ) {
        $skip_list->{$_} = 1;
    }

    foreach ( keys %$errors ) {

        if ( exists( $skip_list->{$_} ) ) {
            delete( $errors->{$_} );
            next;
        }

        if ( $errors->{$_} == 1 ) {
            $thar_be_errors = 1;
        }

    }

    return ( $thar_be_errors, $errors );

}

sub validate_remove_field_name {

    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{ -field } ) ) {
        croak "You must pass a field name in, -field!";
    }

    if ( !exists( $args->{ -die_for_me } ) ) {
        $args->{ -die_for_me } = 0;
    }

    my $thar_be_errors = 0;
    my $errors         = {};

    my %omit_fields = (
        email_id    => 1,
        email       => 1,
        list        => 1,
        list_type   => 1,
        list_status => 1
    );

    if ( exists( $omit_fields{ $args->{ -field } } ) ) {

        #croak 'Cannot remove the special field, $args->{-field}';
        $errors->{field_is_special_field} = 1;
    }
    else {
        $errors->{field_is_special_field} = 0;
    }


	my $exists = $self->field_exists({-field => $args->{ -field }}); 
    if ( $exists == 0 ) {

        $errors->{field_exists} = 1;
        if ( $args->{ -die_for_me } == 1 ) {
            croak "The field you are attempting to remove from ("
              . $args->{ -field }
              . ") does not exist";
        }
    }
    else {
        $errors->{field_exists} = 0;
    }

    # What? How exactly is this reached when *removing* a field?
    my $fields = $self->fields;
    if ( $#$fields + 1 > 100 ) {
        $errors->{number_of_fields_limit_reached} = 1;
        if ( $args->{ -die_for_me } == 1 ) {
            croak
'You\ve reached the limit of how many subscriber fields are supported! (100)';
        }
    }
    else {
        $errors->{number_of_fields_limit_reached} = 0;

    }

    foreach ( keys %$errors ) {
        if ( $errors->{$_} == 1 ) {
            $thar_be_errors = 1;
        }
    }

    return ( $thar_be_errors, $errors );

}

sub change_field_order {

    my $self = shift;
    my ($args) = @_;

	delete( $self->{cache}->{fields} );
	
    # fields
    # direction

    if ( !exists( $args->{ -field } ) ) {
        croak "You must pass a field name in, -field!";
    }
	if(! $self->field_exists({-field => $args->{ -field }})){ 
		croak 'field, ' . $args->{ -field } . ' does not exist!'; 
	}

    my $sf = $self->fields;

    my $i   = 0;
    my $pos = 0;
    my $before;
    my $after;
    my $dir = $args->{ -direction };
	
    foreach my $f (@$sf) {

        #	die $f . ' ' . $args->{-field};
        if ( $f eq $args->{ -field } ) {
            $pos = $i;

            #		die $pos;
        }
        else {
            $i++;
        }
    }

    if ( $dir eq 'down' ) {
        if ( $pos >= $#$sf ) {
            return 0;
        }

        $before = $args->{ -field };
        $after  = $sf->[ $pos + 1 ];
    }
    if ( $dir eq 'up' ) {
        if ( $pos <= 0 ) {
            return 0;
        }
        $before = $sf->[ $pos - 1 ];
        $after  = $args->{ -field };
    }

    #	if($dir eq 'up'){
    #		($before, $after) = ($after, $before);
    #	}

    my $query =
      'ALTER TABLE ' . $self->{sql_params}->{profile_fields_table} . ' MODIFY COLUMN ' . $before
      . ' text AFTER '
      . $after;
	print 'QUERY ' . $query . "\n"; 
    #	die $query;
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute()
      or croak "cannot do statement (at: change_field_order)! $DBI::errstr\n";

   	delete( $self->{cache}->{fields} );

    return 1;
}

sub remove_field_attributes {

    my $self = shift;
    my ($args) = @_;

    my $query =
      'DELETE FROM '
      . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
      . ' WHERE field = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $args->{ -field } )
      or croak
      "cannot do statement (at: remove_field_attributes)! $DBI::errstr\n";

    return 1;
}

sub can_have_subscriber_fields {

    my $self = shift;
    return 1;
}

1;
