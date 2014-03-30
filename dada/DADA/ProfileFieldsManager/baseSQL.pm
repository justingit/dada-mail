package DADA::ProfileFieldsManager::baseSQL;
use lib qw(
	../../
	../../perllib
);
use strict; 

use Carp qw(carp croak confess);
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile_Fields};

sub _columns {

    my $self = shift;
    my @cols;

    if ( exists( $self->{cache}->{columns} ) ) {
        return $self->{cache}->{columns};
    }
    else {
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
        for ( $i = 1 ; $i <= $sth->{NUM_OF_FIELDS} ; $i++ ) {
            push( @cols, $sth->{NAME}->[ $i - 1 ] );
        }
        $sth->finish;
        $self->{cache}->{columns} = \@cols;
    }
    return \@cols;

}


sub fields {

    my $self   = shift;
    my ($args) = @_;
    my $l      = [];

    # I don't know, but this isn't always working...
    if ( exists( $self->{cache}->{fields} ) ) {
        $l = $self->{cache}->{fields};
    }
    else {
       # I'm assuming, "columns" always returns the columns in the same order...
        $l = $self->_columns;
        $self->{cache}->{fields} = $l;
    }

    if ( !exists( $args->{-show_hidden_fields} ) ) {
        $args->{-show_hidden_fields} = 1;
    }
    if ( !exists( $args->{-dotted} ) ) {
        $args->{-dotted} = 0;
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
    for my $field (@$l) {

        next
          if exists( $omit_fields{$field} );

        next
          if ( $args->{-show_hidden_fields} == 0
            && $DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX ne undef
            && $field =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/ );

        if ( $args->{-dotted} == 1 ) {
            push( @r, 'subscriber.' . $field );
        }
        else {
            push( @r, $field );
        }

    }

    return \@r;
}



sub add_field {

    my $self = shift;
	
    $self->clear_cache;

    my ($args) = @_;

    if ( !exists $args->{ -field } ) {
        croak "You must pass a value in the -field parameter!";
    }
    if ( !exists( $args->{ -fallback_value } ) ) {
        $args->{ -fallback_value } = '';
    }
    if ( !exists( $args->{ -label } ) ) {
        $args->{ -label } = '';
    }
    if ( !exists( $args->{ -required } ) ) {
        $args->{ -required } = 0; 
    }
    
    my ( $status, $details ) =
      $self->validate_field_name( { -field => $args->{ -field } } );

    if ($status == 0) {
		my $err; 
        $err = "Something's wrong with the field name you're trying to pass ("
          . $args->{ -field }
          . "). Validate the field name before attempting to add the field with, 'validate_field_name' - ";
        for ( keys %$details ) {
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
      . $args->{ -field } . " TEXT NOT NULL DEFAULT ''";
    my $sth = $self->{dbh}->prepare($query);

    my $rv = $sth->execute()
      or croak "cannot do statement (at add_field)! $DBI::errstr\n";

    $self->save_field_attributes(
        {
            -field          => $args->{ -field },
            -label          => $args->{ -label },
            -fallback_value => $args->{ -fallback_value },
            -required       => $args->{ -required },
        }
    );

    $self->clear_cache;
    $self->_clear_screen_cache; 

    return 1;
}

sub save_field_attributes {
    
    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{-field} ) {
        croak "You must pass a value in the -field parameter!";
    }
    if ( !exists( $args->{-fallback_value} ) ) {
        $args->{-fallback_value} = '';
    }
    if ( !exists( $args->{-label} ) ) {
        $args->{-label} = '';
    }
    if ( !exists( $args->{-required} ) ) {
        $args->{-required} = 0;
    }

    my $query = '';

    if ( $self->_field_attributes_exist( { -field => $args->{-field} } ) ) {
        $query =
            'UPDATE '
          . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
          . ' SET label = ?, fallback_value = ?, required = ? WHERE field = ?';

        my $sth = $self->{dbh}->prepare($query);
        my $rv = $sth->execute( $args->{-label}, $args->{-fallback_value}, $args->{-required}, $args->{-field}, )
          or croak "cannot do statement (at save_field_attributes)! $DBI::errstr\n";

        undef $sth;
        undef $rv;
    }
    else {
        $query =
            'INSERT INTO '
          . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
          . ' (field, label, fallback_value, required) values(?,?,?,?)';

        my $sth = $self->{dbh}->prepare($query);

        my $rv = $sth->execute( $args->{-field}, $args->{-label}, $args->{-fallback_value}, $args->{-required}, )
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

sub edit_field_name {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -old_name } ) ) {
        croak "You MUST supply the old field name in the -old_name parameter!";
    }
    if ( !exists( $args->{ -new_name } ) ) {
        croak "You MUST supply the new field name in the -new_name parameter!";
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
      "cannot do statement (at: edit_field_name)! $DBI::errstr\n";

    $self->clear_cache;
	$self->_clear_screen_cache; 
	
    return 1;

}

sub remove_field {

    my $self = shift;

    $self->clear_cache;

    my ($args) = @_;
    if ( !exists( $args->{ -field } ) ) {
        croak "You MUST pass a field name in, -field!";
    }

	# DEV: This is pretty suspect - why are we lower-casing the field name? 
    # $args->{ -field } = lc( $args->{ -field } );

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
	$self->_clear_screen_cache; 
    $self->clear_cache;

    return 1;

}


sub remove_all_fields { 
    my $self = shift; 
    my $count = 0; 
    foreach(@{$self->fields}) { 
        $self->remove_field({ -field => $_},); 
        $count++; 
    }
    return $count; 
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
	# DEV: This is pretty suspect - why are we lower-casing the field name? 
    # $args->{ -field } = lc( $args->{ -field } );

    for ( @{ $self->fields } ) {
        if ( $_ eq $args->{ -field } ) {
            return 1;
        }
    }
    return 0;
}

sub validate_field_name {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{ -field } ) ) {

        croak "You must pass a field name in, -field!";
    }

    if ( !exists( $args->{ -skip } ) ) {
        $args->{ -skip } = [];
    }

	# DEV: This is pretty suspect - why are we lower-casing the field name? 
    # $args->{ -field } = lc( $args->{ -field } );

    my $errors         = {};
    my $status         = 1;

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

	#                          [[:upper:]]
    if ( $args->{ -field } =~ m/[A-Z]/ ) {
        $errors->{upper_case} = 1;
    }
    else {
        $errors->{upper_case} = 0;
    }


    if ( $args->{ -field } =~ m/\s/ ) {
        $errors->{spaces} = 1;
    }
    else {
        $errors->{spaces} = 0;
    }

    if ( $args->{ -field } =~ m/\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\>|\<|\-|\0-\037\177-\377/ )
    {
        $errors->{weird_characters} = 1;
    }
    else {
     #	# Match anything but ASCII alphanumerics
		if($args->{ -field } =~ m/[^a-zA-Z0-9_]/){ 
			$errors->{weird_characters} = 1;
		}
   		else { 
			$errors->{weird_characters} = 0;
		}
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
    for ( @{ $args->{ -skip } } ) {
        $skip_list->{$_} = 1;
    }

    for ( keys %$errors ) {

        if ( exists( $skip_list->{$_} ) ) {
            delete( $errors->{$_} );
            next;
        }

        if ( $errors->{$_} == 1 ) {
			$status = 0;
        }

    }

    return ( $status, $errors );

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

    my $status         = 1;
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
'You\ve reached the limit of how many Profile Fields are supported! (100)';
        }
    }
    else {
        $errors->{number_of_fields_limit_reached} = 0;

    }

    for ( keys %$errors ) {
        if ( $errors->{$_} == 1 ) {
            $status = 0;
        }
    }

    return ( $status, $errors );

}

sub change_field_order {

    my $self = shift;
    my ($args) = @_;

	$self->clear_cache;
	
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
	
    for my $f (@$sf) {

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
    #	die $query;
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute()
      or croak "cannot do statement (at: change_field_order)! $DBI::errstr\n";

	$self->_clear_screen_cache; 
    $self->clear_cache;

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

sub _clear_screen_cache { 
	
	require DADA::App::ScreenCache; 
	my $c = DADA::App::ScreenCache->new; 
	   $c->flush;
	
}
1;
