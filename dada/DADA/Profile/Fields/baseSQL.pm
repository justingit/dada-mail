package DADA::Profile::Fields::baseSQL; 
use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 

use Carp qw(carp croak confess);
use DADA::App::Guts; 

sub columns { 
	
	my $self = shift; 
	my $sth = $self->{dbh}->prepare("SELECT * FROM " . $self->{sql_params}->{profile_fields_table} ." WHERE (1 = 0)");    
	$sth->execute() or confess "cannot do statement (at: columns)! $DBI::errstr\n";  
	my $i; 
	my @cols;
	for($i = 1; $i <= $sth->{NUM_OF_FIELDS}; $i++){ 
		push(@cols, $sth->{NAME}->[$i-1]);
	} 
	$sth->finish;
	return \@cols;

}



sub subscriber_fields { 

    my $self = shift;
    my ($args) = @_; 
    
	my $l = [] ;
	
	if(exists( $self->{cache}->{subscriber_fields} ) ) { 
		$l = $self->{cache}->{subscriber_fields};
	} 
	else { 
    	# I'm assuming, "columns" always returns the columns in the same order... 
	    $l = $self->columns;
	    $self->{cache}->{subscriber_fields} = $l; 
    }


    if(! exists($args->{-show_hidden_fields})){ 
        $args->{-show_hidden_fields} = 1; 
    }
    if(! exists($args->{-dotted})){ 
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
    foreach(@$l){ 
    
        if(! exists($omit_fields{$_})){
    
            if($args->{-show_hidden_fields} == 1){ 
                if($args->{-dotted} == 1){ 
                    push(@r, 'subscriber.' . $_);
                }
                else { 
                    push(@r, $_);
                }
             }
             elsif($DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX eq undef){ 
                if($args->{-dotted} == 1){ 
                    push(@r, 'subscriber.' . $_);
                }
                else { 
                
                    push(@r, $_);
                }
             }  
             else { 
             
                if($_ !~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/ && $args->{-show_hidden_fields} == 0){ 
                    if($args->{-dotted} == 1){ 
                        push(@r, 'subscriber.' . $_);
                    }
                    else { 
                
                        push(@r, $_);
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

    my $self   = shift;
    my ($args) = @_;

	# use Data::Dumper; 
	# warn '$args passed to, insert(): ' . Data::Dumper::Dumper($args); 

    if ( !exists $args->{ -email } ) {
        croak("You MUST supply an email address in the -email paramater!");
    }
    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email paramater!");
    }

    if ( !exists $args->{ -fields } ) {
		warn 'did you not pass any fields?'; 
        $args->{ -fields } = {};
    }

	if($self->exists({-email => $args->{-email}}) >= 1){ 
		$self->drop({-email => $args->{-email}}); 
	}

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $self->subscriber_fields };
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

    my $sth     = $self->{dbh}->prepare($query);

	# use Data::Dumper; 
	# warn 'DADA::Profile::Fields->insert(): ' . Data::Dumper::Dumper($args->{ -email },@values);
    $sth->execute(
        $args->{ -email },
		@values
      )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
	$sth->finish;
}




sub get {

    my $self = shift;
    my ($args) = @_;
    my $sub_fields = $self->subscriber_fields;

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_fields_table}
      . " WHERE email = ?";

	warn 'QUERY: ' . $query . ', $args->{-email}: ' . $args->{-email}
		if $t; 


    my $sth = $self->{dbh}->prepare($query);
		

    $sth->execute($args->{-email})
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $hashref   = {};
    my $n_hashref = {};

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        foreach ( @{$sub_fields} ) {
            $n_hashref->{$_} = $hashref->{$_};
        }
        $n_hashref->{email} = $hashref->{email};

        my ( $n, $d ) = split ( '@', $hashref->{email}, 2 );
        $n_hashref->{email_name}   = $n;
        $n_hashref->{email_domain} = $d;

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

    carp "Didn't fetch the subscriber?!";
    return undef;

}




sub exists { 
	my $self   = shift; 
	my ($args) = @_;
	
	my $query = 'SELECT COUNT(*) from ' . $DADA::Config::SQL_PARAMS{profile_fields_table}
    			 . ' WHERE email = ? '; 
				
	my $sth     = $self->{dbh}->prepare($query);

	$sth->execute($args->{ -email })
		or croak "cannot do statement (at exists)! $DBI::errstr\n";	 
	my @row = $sth->fetchrow_array();
    $sth->finish;
   
   return $row[0];
}



sub drop {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . ' WHERE email = ? ';

	my $sth = $self->{dbh}->prepare($query); 
    
	warn 'QUERY: ' . $query . ' ('. $args->{ -email } . ')'
		if $t; 
	my $rv = $sth->execute( $args->{ -email } )
      or croak "cannot do statment (at drop)! $DBI::errstr\n";
    $sth->finish;
    return $rv;
}





sub add_subscriber_field { 

    my $self = shift; 
    #DEV: Add testing of parameters!!!!!!
    
	delete($self->{cache}->{subscriber_fields}); 

    my ($args) = @_;

    if(! exists $args->{-field}){ 
        croak "You must pass a value in the -field paramater!"; 
    }
    
    $args->{-field} = lc($args->{-field}); 
    
    my ($errors, $details) = $self->validate_subscriber_field_name({-field =>  $args->{-field}});
    
    
    if($errors){ 
        carp "Something's wrong with the field name you're trying to pass (" . $args->{-field} . "). Validate the field name before attempting to add the field with, 'validate_subscriber_field_name' - ";
        foreach(keys %$details){ 
            if($details->{$_} ==1){ 
                carp  $args->{-field} . ' Field Error: ' . $_; 
            }
        }
        
        return undef; 
    }
    
    my $query =  'ALTER TABLE ' . $self->{sql_params}->{profile_fields_table} . 
                ' ADD COLUMN ' .  $args->{-field} . 
                ' TEXT'; 
        
               
    my $sth = $self->{dbh}->prepare($query);    


    my $rv = $sth->execute() 
	    or croak "cannot do statement (at add_subscriber_field)! $DBI::errstr\n";   
	
	
	if(exists($args->{-fallback_value})){ 
		warn "fallback field value exists."; 
	    $self->_save_fallback_value({-field => $args->{-field}, -fallback_value => $args->{-fallback_value}});
	}
	
	delete($self->{cache}->{subscriber_fields}); 
	return 1; 
}




sub edit_subscriber_field { 

	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-old_name})){ 
		croak "You MUST supply the old field name in the -old_name paramater!"; 
	}		

	if(!exists($args->{-new_name})){ 
		croak "You MUST supply the new field name in the -new_name paramater!"; 
	}	
	
	my $query; 
	
	if($DADA::Config::SUBSCRIBER_DB_TYPE eq 'PostgreSQL') {
	
		#ALTER TABLE dada_subscribers RENAME COLUMN oldfoo TO newfoo;
		$query = 'ALTER TABLE ' . $self->{sql_params}->{profile_fields_table} . ' RENAME COLUMN ' . $args->{-old_name} . ' TO ' . $args->{-new_name}; 
	}
	else { 
		
		$query = 'ALTER TABLE ' . $self->{sql_params}->{profile_fields_table} . ' CHANGE ' . $args->{-old_name} . ' ' . $args->{-new_name} . '  TEXT'; 
 
	}
#	die '$query ' . $query; 
	$self->{dbh}->do($query) or croak "cannot do statement (at: edit_subscriber_field)! $DBI::errstr\n";   ;    

	delete($self->{cache}->{subscriber_fields});
	return 1; 
	
}










sub remove_subscriber_field { 

    my $self = shift; 
    
	delete($self->{cache}->{subscriber_fields}); 

    my ($args) = @_;
    if(! exists($args->{-field})){ 
        croak "You MUST pass a field name in, -field!"; 
    }
    $args->{-field} = lc($args->{-field}); 
    
    $self->validate_remove_subscriber_field_name(
        {
        -field      => $args->{-field}, 
        -die_for_me => 1, 
        }
    ); 
   
        
    my $query =  'ALTER TABLE '  . $self->{sql_params}->{profile_fields_table} . 
                ' DROP COLUMN ' . $args->{-field}; 
    
    my $sth = $self->{dbh}->prepare($query);    
    
    my $rv = $sth->execute() 
        or croak "cannot do statement! (at: remove_subscriber_field) $DBI::errstr\n";   
 	
	$self->_remove_fallback_value({-field => $args->{-field}}); 
	delete($self->{cache}->{subscriber_fields}); 
	
	return 1; 
	
}





sub subscriber_field_exists { 

    my $self = shift; 
    
    my ($args) = @_;
    
    if(! exists($args->{-field})){
        croak "You must pass a field name in, -field!"; 
    }
    
    $args->{-field} = lc($args->{-field}); 
    
    
    foreach(@{$self->subscriber_fields}){ 
        if($_ eq $args->{-field}){ 
            return 1;    
        }
    }
    return 0;
}



sub validate_subscriber_field_name { 

    my $self = shift; 
    
    my ($args) = @_;
   
    if(! exists($args->{-field})){
 
        croak "You must pass a field name in, -field!"; 
    }
    
    if(! exists($args->{-skip})){ 
		$args->{-skip} = [];
	}
	
    $args->{-field} = lc($args->{-field}); 
    
    my $errors = {};
    my $thar_be_errors = 0; 
    
     
	if($args->{-field} eq ""){ 
		$errors->{field_blank} = 1;
	}else{ 
		$errors->{field_blank} = 0;
	}
		
		
    if(length($args->{-field}) > 64){ 
        $errors->{field_name_too_long} = 1;
    }else{ 
        $errors->{field_name_too_long} = 0;
    }
    
    if($args->{-field} =~ m/\/|\\/){ 
        $errors->{slashes_in_field_name} = 1;
    }else{ 
        $errors->{slashes_in_field_name} = 0;
    }


    if($args->{-field} =~ m/\s/){ 
        $errors->{spaces} = 1;
    }
    else { 
        $errors->{spaces} = 0;
    }
    
    if($args->{-field} =~ m/\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\>|\<|\-|\0-\037\177-\377/){ 
        $errors->{weird_characters} = 1;
    }else{ 
        $errors->{weird_characters} = 0;
    }
 
    if($args->{-field} =~ m/\"|\'/){ 
        $errors->{quotes} = 1;
    }else{ 
        $errors->{quotes} = 0;
    }
	
	if($self->subscriber_field_exists({-field => $args->{-field}}) == 1) { 
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
					   
	if(exists($omit_fields{$args->{-field}})){ 
	    $errors->{field_is_special_field} = 1; 
	}
	 else { 
	    $errors->{field_is_special_field} = 0;
	 
	}
	
	my $skip_list = {}; 
	foreach(@{$args->{-skip}}){ 
		$skip_list->{$_} = 1; 
	}
	
	foreach(keys %$errors){ 

		if(exists($skip_list->{$_})){
			delete($errors->{$_}); 
			next;
		}	

	    if($errors->{$_} == 1){ 
	        $thar_be_errors = 1; 
	    }

	}
	
	return ($thar_be_errors, $errors);

}






sub validate_remove_subscriber_field_name {

    my $self = shift; 
    
    my ($args) = @_;
    if(! exists($args->{-field})){ 
        croak "You must pass a field name in, -field!"; 
    }

    if(! exists($args->{-die_for_me})){ 
        $args->{-die_for_me} = 0; 
    }
    
    my $thar_be_errors  = 0; 
    my $errors         = {}; 
    
    my %omit_fields = (
        email_id    => 1,
        email       => 1,
        list        => 1,
        list_type   => 1,
        list_status => 1
    );	
					   
	if(exists($omit_fields{$args->{-field}})){ 
	   #croak 'Cannot remove the special field, $args->{-field}';
	   $errors->{field_is_special_field} = 1; 
	} else{ 
	   $errors->{field_is_special_field} = 0; 
	}   
	
	my $exists = 0;
	foreach(@{$self->subscriber_fields}){ 
	    if($args->{-field} eq $_){ 
	        $exists = 1; 
	        last; 
	    }
	}
	if($exists == 0){ 
	   
        $errors->{field_exists} = 1;  
        if($args->{-die_for_me} == 1){ 
            croak "The field you are attempting to unsubscribe from (" . $args->{-field} . ") does not exist";
        }
    }
    else { 
        $errors->{field_exists} = 0; 
    }
    
	# What? How exactly is this reached when *removing* a field? 
    my $fields = $self->subscriber_fields; 
    if($#$fields+1 > 100){     
        $errors->{number_of_fields_limit_reached} = 1; 
        if($args->{-die_for_me} == 1){ 
            croak 'You\ve reached the limit of how many subscriber fields are supported! (100)'; 
        }
    }
    else { 
        $errors->{number_of_fields_limit_reached} = 0; 

    }
    
    foreach(keys %$errors){ 
	    if($errors->{$_} == 1){ 
	        $thar_be_errors = 1; 
	    }
	}
	
	return ($thar_be_errors, $errors);
    
}




sub _remove_fallback_value { 

    my $self = shift; 
    my ($args) = @_; 
    
    if(! exists $args->{-field}){ 
        croak "You MUST pass a value in the -field paramater!"; 
    }

    require DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $self->{list}}); 
    my $li = $ls->get; 
    
    
    my $fallback_field_values = $self->get_fallback_field_values;
    

    my $new_fallback_field_values = '';
    foreach(keys %$fallback_field_values){ 
        next if $_ eq $args->{-field}; 
        $new_fallback_field_values .= $_ . ':' . $fallback_field_values->{$_} . "\n";
    }
    $ls->save({fallback_field_values => $new_fallback_field_values}); 
    
    return 1; 
}




sub _save_fallback_value { 

    my $self = shift; 
    my ($args) = @_; 

	# use Data::Dumper; 
	# warn "$args given to _save_fallback_value: " . Data::Dumper::Dumper($args); 
    
    if(! exists $args->{-field}){ 
        croak "You MUST pass a value in the -field paramater!"; 
    }

    if(! exists $args->{-fallback_value}){ 
        croak "You must pass a value in the -fallback_value paramater!"; 
    }
    
	warn ' $self->{list} ' .  $self->{list}; 
	
 	require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $self->{list}});

    my $fallback_field_values = $self->get_fallback_field_values;
    
    my $fallback_field_clump = ''; 
	
	foreach(keys %$fallback_field_values){ 
		$fallback_field_clump .= $_ . ':' . $fallback_field_values->{$_} . "\n";
	}

    $args->{-fallback_value} =~ s/\r|\n/ /g;
    $args->{-fallback_value} =~ s/\://g;
    
    $fallback_field_clump .= $args->{-field} . ':' . $args->{-fallback_value} . "\n";
    
    $ls->save({fallback_field_values => $fallback_field_clump});
    
    return 1; 
}




sub can_have_subscriber_fields { 

    my $self = shift; 
    return 1; 
}











1; 
