package DADA::MailingList::Subscribers::baseSQL;

use strict;

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib);

use Carp qw(croak carp confess);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList};

use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB
);

sub inexact_match {

    my $self = shift;
    my ($args) = @_;
    my $email = cased( $args->{ -email } );
    my ( $name, $domain ) = split ( '@', $email );

    my $query .= 'SELECT COUNT(*) ';
    $query .= ' FROM ' . $self->{sql_params}->{subscriber_table} . ' WHERE ';
    $query .= ' list_type = ? AND';
    $query .= ' list_status = ' . $self->{dbh}->quote(1);
    if (   $args->{ -against } eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {

        # ...
    }
    else {
        $query .= ' AND list = ?';
    }
	$query .= ' AND (email = ? OR email = ? OR email = ?)';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    if (   $args->{ -against } eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {
		$sth->execute(
		    $args->{ -against },
		    $email,
		    $name . '@',
		    '@' . $domain,
		  )
		  or croak "cannot do statement (inexact_match)! $DBI::errstr\n";

    }
    else {

	$sth->execute(
	    $args->{ -against },
	    $self->{list},
	    $email,
	    $name . '@',
	    '@' . $domain,

	  )
	  or croak "cannot do statement (inexact_match)! $DBI::errstr\n";
	
    }

    my @row = $sth->fetchrow_array();
    $sth->finish;

    if ( $row[0] >= 1 ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub search_list {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{-start} ) ) {
        $args->{-start} = 0;
    }
    if ( !exists( $args->{'-length'} ) ) {
        $args->{'-length'} = 100;
    }

    my $r = [];

    my $partial_listing = {};
    my $search_type = 'any'; 
    
    my $fields = $self->subscriber_fields;
    if(! exists($args->{-query}) && exists($args->{-partial_listing})){ 
        $partial_listing = $args->{-partial_listing}; 
        $search_type = 'all'; 
    }
    else { 
        for (@$fields) {
            $partial_listing->{$_} = {
                 -operator => 'LIKE',
                 -value    => $args->{-query}, 
            };
        }
        # Do I have to do this, explicitly?
        $partial_listing->{email} = {
            -operator => 'LIKE',
            -value    => $args->{-query} 
        };
    }
    
    my $query = $self->SQL_subscriber_profile_join_statement(
        {
            -type            => $args->{-type},
            -partial_listing => $partial_listing,
            -search_type     => $search_type,
            -order_by        => $args->{-order_by},
            -order_dir       => $args->{-order_dir},
			#-start          => $args->{ -start }, 
			#'-length'       => $args->{'-length'}, 
        }
    );
    warn 'QUERY: ' . $query
     if $t; 

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (for search_list)! $DBI::errstr\n";

    my $row   = {};
    my $count = 0;

    while ( $row = $sth->fetchrow_hashref ) {

		# DEV: It would be better to use LIMIT, x, y in the query, 
		# but we still need the total search results number, and something like, 
		# select count(*) from (select [...]);
		# isn't working as well as I'd like
		
        $count++;
        next if $count < ( $args->{ -start } * $args->{ '-length' });
        next if $count >  ( $args->{ -start } * $args->{ '-length' }) + ($args->{'-length'}) ;

        my $info = {};
        
        $info->{timestamp} = $row->{timestamp};
        $info->{email}     = $row->{email};
        $info->{type}     = $args->{-type};    # Whazza?!

        delete( $row->{email} ); #?
        
        $info->{fields} = [];

        for (@$fields) {
            push( @{ $info->{fields} }, { name => $_, value => $row->{$_} } );
        }

        push( @$r, $info );

    }

    $sth->finish();

    return ( $count, $r );

}




sub domain_stats { 
	my $self    = shift;

	my ($args) = @_; 
	
	my $count;
	if(exists($args->{-count})) { 
		$count = $args->{-count}; 
	}
	else { 
		$count = 15; 
	}
	
	my $type = 'list'; 
	if(exists($args->{-type})){ 
		$type = $args->{-type};
	}
	
	my $domains = {};
	
	my $query = "SELECT email FROM " . 
				$self->{sql_params}->{subscriber_table} . 
				" WHERE list_type = ? AND list_status = ? AND list = ?";

	# Count All the Domains
	my $sth = $self->{dbh}->prepare($query);
	$sth->execute($type, 1, $self->{list});
	 while ( ( my $email ) = $sth->fetchrow_array ) {
		my ($name, $domain) = split('@', $email); 
		if(!exists($domains->{$domain})){ 
			$domains->{$domain} = 0;
		}
		$domains->{$domain} = $domains->{$domain} + 1; 
	}
	$sth->finish; 
	
	# Sorted Index
	my @index = sort { $domains->{$b} <=> $domains->{$a} } keys %$domains; 
	
	# Top n
	my @top = splice(@index,0,($count-1));
	
	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $domains->{$_};
	}
	my $final = [];
	foreach(@top){ 
		push(@$final, {domain => $_, number => $domains->{$_}});
	}
	if($other > 0) { 
		push(@$final, {domain => 'other', number => $other}); 
	}
	
	# Return!
	return $final;

}

sub SQL_subscriber_profile_join_statement {

    warn 'at, ' . ( caller(0) )[3] if $t;
    
    my $self = shift;
    my ($args) = @_;

    if($t == 1){ 
        require Data::Dumper; 
        warn 'passed args:' . Data::Dumper::Dumper($args); 
    }
    # init vars:

    my $ls = DADA::MailingList::Settings->new({-list => $self->{list}}); 

    # type list black_List, white_listed, etc
    if ( !$args->{-type} ) {
        $args->{-type} = 'list';
    }

    # Sanity Check.
    if ( $self->allowed_list_types( $args->{-type} ) != 1 ) {
        croak '"' . $args->{-type} . '" is not a valid list type! ';
    }

    if ( !exists( $args->{-order_by}) || !defined($args->{-order_by}) ) {
            $args->{-order_by} = 'email';
    }
    if ( !exists( $args->{-order_dir} ) ) {
        $args->{-order_dir} = 'asc';
    }
    if(!exists($args->{-user_order_by})){ 
        $args->{-user_order_by} = 1; 
    }
    
    if(!exists($args->{-mass_mailing_params})) { 
        $args->{-mass_mailing_params} = 
        {
            -delivery_preferences => 'all', # individual, digest, all
        }; 
    }

    if ( exists( $args->{-include_from} ) ) {
        if ( exists( $args->{-include_from}->[0] ) ) {

            # ...
        }
        else {
            delete( $args->{-include_from} );
        }
    }

    my $query_type = 'AND';
    if ( !$args->{-search_type} ) {
        $args->{-search_type} = 'all';
    }
    if ( $args->{-search_type} !~ /any|all/ ) {
        $args->{-search_type} = 'all';
    }
    if ( $args->{-search_type} eq 'any' ) {
        $query_type = 'OR';
    }
    
    if(!exists($args->{-select_fields})){ 
        $args->{-select_fields}->{':all'} = 1; 
    }

    my $subscriber_table       = $self->{sql_params}->{subscriber_table};
    my $profile_fields_table   = $self->{sql_params}->{profile_fields_table};
    my $profile_settings_table = $self->{sql_params}->{profile_settings_table};
    # We need the email and list from $subscriber_table
    my $query;

    if ( exists( $args->{-include_from} )
        && $self->{sql_params}->{dbtype} eq 'Pg' )
    {
        $query .= ' SELECT DISTINCT ON(' . $subscriber_table . '.email) ';
    }
    else {
        $query = 'SELECT ';
    }

    # This is to select which Profile Fields to return with our query
    my @merge_fields = (); 
    if($args->{-select_fields}->{'subscriber.timestamp'} == 1 || $args->{-select_fields}->{':all'} == 1){ 
        push(@merge_fields, $subscriber_table . '.timestamp');
    }
    if($args->{-select_fields}->{'subscriber.email'} == 1 || $args->{-select_fields}->{':all'} == 1){
        push(@merge_fields, $subscriber_table . '.email'); 
    }
    if($args->{-select_fields}->{'subscriber.list'} == 1 || $args->{-select_fields}->{':all'} == 1){ 
        push(@merge_fields, $subscriber_table . '.list'); 
    }
    foreach(@{ $self->subscriber_fields }) { 
        if($args->{-select_fields}->{'profile.' . $_} == 1 || $args->{-select_fields}->{':all'} == 1){
            push(@merge_fields, $profile_fields_table . '.' . $_)
        }
    }

    $query .= join(', ', @merge_fields); 

# And we need to match this with the info in $profile_fields_table - this fast/slow?
    $query .=
        ' FROM '
      . $subscriber_table
      . ' LEFT OUTER JOIN '
      . $profile_fields_table . ' ON ';
    $query .= ' '
      . $subscriber_table
      . '.email' . ' = '
      . $profile_fields_table
      . '.email';

    # Global Black List spans across all lists (yes, we're still using this).
    $query .= ' WHERE  ';
    if (   $DADA::Config::GLOBAL_BLACK_LIST
        && $args->{-type} eq 'black_list' )
    {

        #... Nothin'
    }
    else {

        if ( exists( $args->{-include_from} ) ) {
            my @include_from = ( $self->{list}, @{ $args->{-include_from} } );
            @include_from = map( $self->{dbh}->quote($_), @include_from );
            @include_from =
              map( $_ = $subscriber_table . '.list = ' . $_, @include_from );

            my $include_from_query = join( ' OR ', @include_from );
            $include_from_query = '( ' . $include_from_query . ' )';
            $include_from_query .= ' AND ';
            $query .= $include_from_query;
        }
        else {
            $query .=
                $subscriber_table
              . '.list = '
              . $self->{dbh}->quote( $self->{list} ) . ' AND ';
        }
    }

    # list_status is almost always 1
    $query .=
        $subscriber_table
      . '.list_type = '
      . $self->{dbh}->quote( $args->{-type} );
    $query .= ' AND '
      . $subscriber_table
      . '.list_status = '
      . $self->{dbh}->quote('1') . ' ';
      
    # This is all to query the $dada_profile_fields_table
    # The main thing, is that we only want the SQL statement to hold
    # fields that we're actually looking for.

    if ( keys %{ $args->{-partial_listing} } ) {

        warn q|keys %{ $args->{-partial_listing} }| if $t; 
        # This *really* needs its own method, as well...
        # It's somewhat strange, as this relies on the email address in the
        # profile (I think?) to work, if we're looking for email addresses...

        my @add_q      = ();

        for my $field( keys %{ $args->{-partial_listing} } ) {
			
			warn '$field ' . $field
			 if $t; 
			
			my @s_snippets = ();
			
            # This is to make sure we're always using the email from the
            # subscriber table - this stops us from not seeing an email
            # address that doesn't have a profile...
            my $table = $profile_fields_table;
            if ( $field eq 'email' ) {
                $table = $subscriber_table;
            }
            elsif ($field eq 'subscriber.timestamp') { 
                $table = $subscriber_table;             
            }

            next if ! exists($args->{-partial_listing}->{$field}->{-value});
            next if ! defined($args->{-partial_listing}->{$field}->{-value});
            next if           $args->{-partial_listing}->{$field}->{-value} eq '';

            
            my $search_op        = '';
            my $search_pre       = '';
            my $search_app       = '';
            my $search_binder    = '';

            if($field ne 'subscriber.timestamp') { 
                if ( $args->{-partial_listing}->{$field}->{-operator} eq '=' ) {
                    $search_op     = '=';
                    $search_pre    = '';
                    $search_app    = '';
                    $search_binder = 'OR';
                }
                elsif ( $args->{-partial_listing}->{$field}->{-operator} eq 'LIKE' ) {
                    $search_op     = 'LIKE';
                    $search_pre    = '%';
                    $search_app    = '%';
                    $search_binder = 'OR';
                }
                elsif ( $args->{-partial_listing}->{$field}->{-operator} eq '!=' ) {
                    $search_op     = '!=';
                    $search_pre    = '';
                    $search_app    = '';
                    $search_binder = 'AND';
                }
                elsif ( $args->{-partial_listing}->{$field}->{-operator} eq 'NOT LIKE' ) {
                    $search_op     = 'NOT LIKE';
                    $search_pre    = '%';
                    $search_app    = '%';
                    $search_binder = 'AND';
                }

                my @terms = split(',', $args->{-partial_listing}->{$field}->{-value} );
                foreach my $term(@terms) {
    				$term = strip($term); 
                    push(
                        @s_snippets,
                        $table . '.'
                          . $field . ' '
                          . $search_op . ' '
                          . $self->{dbh}->quote(
                                $search_pre
                              . $term
                              . $search_app
                          )
                    );
                }
    			 push( @add_q, '(' . join( ' ' . $search_binder . ' ', @s_snippets ) . ')' );
    		}
    		elsif($field eq 'subscriber.timestamp') { 
                my $timestamp_snippet = ''; 
                
                $timestamp_snippet = $table . '.timestamp >= ' 
                . $self->{dbh}->quote(
                        $args->{-partial_listing}->{$field}->{-rangestart}
                    )
                . ' AND '
                . $table . '.timestamp <= ' 
                . $self->{dbh}->quote(
                    $args->{-partial_listing}->{$field}->{-rangeend}
                ); 
                warn 'pushing timestamp snippit: ' . $timestamp_snippet
                    if $t;
                push( @add_q, $timestamp_snippet );
    		}
    		else { 
    		    # ... 
    		}
        }
       

	    my $query_pl;
	    if ( $add_q[0] ) {
	        $query_pl = ' AND ( ' . join( ' ' . $query_type . ' ', @add_q ) . ') ';
	        $query .= $query_pl;
	    }
	}
	else { 
	    warn 'no -partial_listing' 
	        if $t; 
	}

   # -exclude_from is to return results from subscribers who *aren't* subscribed
   # to another list.

    # A correlated subquery is a subquery that contains a reference to a
    # table that also appears in the outer query.

    if ( exists( $args->{-exclude_from} ) ) {
        if ( $args->{-exclude_from}->[0] ) {
            my @excludes = ();
            for my $ex_list ( @{ $args->{-exclude_from} } ) {
                push( @excludes, ' b.list = ' . $self->{dbh}->quote($ex_list) );
            }
            my $ex_from_query =
              ' AND NOT EXISTS (SELECT * FROM ' . $subscriber_table . ' b
			    WHERE ( '
              . join( ' OR ', @excludes )
              . ' ) AND '
              . $subscriber_table
              . '.email = b.email) ';
            $query .= $ex_from_query;
        }
    }    
    

#    require Data::Dumper; 
#    warn '$args->{-mass_mailing_params}' . Data::Dumper::Dumper($args->{-mass_mailing_params}); 
    
    my $digest_subq = ' AND EXISTS (SELECT * FROM ' . 
    $profile_settings_table . 
    ' WHERE ' . 
    $subscriber_table . 
    '.email = ' . 
    $profile_settings_table . 
    '.email AND ' .
    $profile_settings_table . 
    '.list = ' . $self->{dbh}->quote( $self->{list}). 
    ' AND ' . 
    $profile_settings_table . 
    '.setting = \'delivery_prefs\' AND ' .
    $profile_settings_table . 
    '.value = \'digest\') '; 
    
    my $individual_subq = ' AND NOT EXISTS (SELECT * FROM ' . 
    $profile_settings_table . 
    ' WHERE ' . 
    $subscriber_table . 
    '.email = ' . 
    $profile_settings_table . 
    '.email AND ' .
    $profile_settings_table . 
    '.list = ' . $self->{dbh}->quote( $self->{list}). 
    ' AND ' . 
    $profile_settings_table . 
    '.setting = \'delivery_prefs\' AND (' .
    $profile_settings_table . 
    '.value = ' . $self->{dbh}->quote("digest") . ' OR ' . $profile_settings_table . 
    '.value = ' . $self->{dbh}->quote("hold") .' ) ) ';
        
    if($args->{-mass_mailing_params}->{-delivery_preferences} eq 'digest'
        && $ls->param('digest_enable') == 1
    ){         
        $query .= $digest_subq; 
    }
    elsif($args->{-mass_mailing_params}->{-delivery_preferences} eq 'individual'
        && $ls->param('digest_enable') == 1
    ){        
        $query .= $individual_subq; 
    }



    if ( exists( $args->{-include_from} )
        && $self->{sql_params}->{dbtype} =~ m/^mysql$|^SQLite$/ )
    {
        $query .= ' GROUP BY ' . $subscriber_table . '.email ';
    }

    if($args->{-user_order_by} == 1){ 
        if ( $args->{-order_by} eq 'email' ) {

            $query .=
                ' ORDER BY '
              . $subscriber_table
              . '.list, '
              . $subscriber_table
              . '.email';
        }
        elsif ( $args->{-order_by} eq 'timestamp' ) {
            $query .=
                ' ORDER BY '
              . $subscriber_table
              . '.list, '
              . $subscriber_table
              . '.timestamp';
        }
        else {
            $query .=
                ' ORDER BY '
              . $subscriber_table
              . '.list, '
              . $profile_fields_table . '.'
              . $args->{-order_by};

        }
    	if($args->{-order_dir} eq 'desc'){ 
    		$query .= ' DESC'; 
    	}
    	else { 
    		$query .= ' ASC'; 
    	}
	}
	if(exists($args->{ -start }) && exists($args->{ '-length' })) { 
		$query .= ' LIMIT '; 
		$query .=  $args->{'-length'};
		$query .= ' OFFSET ';
		$query .= ($args->{ -start } * $args->{ '-length' });		
	}
	
    warn 'QUERY: ' . $query
             if $t;
    
    return $query;
}



sub SQL_subscriber_update_profiles_statement {
    
    my $self = shift; 
    my ($args) = @_; 

    my $u = $args->{-update_fields};
    
    # This should help things not be crazy slow. 
    $args->{-select_fields}->{'subscriber.email'} = 1; 
    $args->{-user_order_by} = 0; 
    $args->{-search_type}   = 'all'; 
    
    my $subscriber_table     = $self->{sql_params}->{subscriber_table};
    my $profile_fields_table = $self->{sql_params}->{profile_fields_table};
    
    my $inner_query = $self->SQL_subscriber_profile_join_statement($args); 
    
    my $query = 'UPDATE ' . $profile_fields_table . '  SET '; 

    foreach (keys %$u ){ 
        $query .= $_ . ' = ' . $self->{dbh}->quote($u->{$_}) . ','; 
    }
    # Remove that last comma, we should do the above, with a join() 
    # or a map() or something 
    
     
    $query  =~ s/\,$//; 
    $query .= ' WHERE email IN ( SELECT * FROM (';
    $query .= $inner_query;
    $query .= ') AS X)';     
        
    return $query; 
    
} 


sub update_profiles { 
    
    my $self = shift; 
    my ($args) = @_; 
    my $query = $self->SQL_subscriber_update_profiles_statement($args); 
    
    # die 'query: ' . $query; 
    
    my $sth = $self->{dbh}->prepare($query);

    my $rv = $sth->execute()
      or croak "cannot do statement (for profile_update)! $DBI::errstr\n";
    
      return $rv; 

}

sub fancy_print_out_list {

    my $count = 0;

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -type } ) ) {
        croak
'you must supply the type of list we are looking at in, the "-type" parameter';
    }

    if ( !exists( $args->{ -FH } ) ) {
        $args->{ -FH } = \*STDOUT;
    }
    my $fh = $args->{ -FH };

    if ( !exists( $args->{ -partial_listing } ) ) {
        $args->{ -partial_listing } = {};
    }

	my $show_list_column = 0; 
	if(exists($args->{-show_list_column})){ 
		$show_list_column = $args->{-show_list_column}; 	
	}
	my $show_timestamp_column = 0; 
	if(exists($args->{-show_timestamp_column})){ 
		$show_timestamp_column = $args->{-show_timestamp_column}; 	
	}


    my $subscribers = $self->subscription_list($args);
    for (@$subscribers) {
        $_->{no_email_links}        = 1;
        $_->{no_checkboxes}         = 1;
        $_->{show_timestamp_column} = $show_timestamp_column, 
		$_->{show_list_column}      = $show_list_column, 
    }

    my $field_names = [];
    for ( @{ $self->subscriber_fields } ) {
        push ( @$field_names, { name => $_ } );
    }

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -screen => 'fancy_print_out_list_widget.tmpl',
            -vars   => {
                field_names           => $field_names,
                subscribers           => $subscribers,
                no_checkboxes         => 1,
                no_email_links        => 1,
                show_list_column      => $show_list_column, 
                show_timestamp_column => $show_timestamp_column, 
                count                 => scalar @{$subscribers},
            }, 
			-expr => 1, 
        }
    );
	e_print($scrn, $fh); 

    return scalar @{$subscribers};

}

sub print_out_list {

    my $self = shift;
	my ($args) = @_; 
	
#	use Data::Dumper; 
#	warn 'args!' . Dumper($args); 
	
	if(! exists($args->{-fh})){ 
			$args->{-fh} =  \*STDOUT;
	}
	if(! exists($args->{-type})){ 
		$args->{-type} = 'list'; 
	}	

	if(! exists($args->{-query})){ 
		$args->{-query} = undef; 
	}	

	if(! exists($args->{-show_timestamp_column})){ 
		$args->{-show_timestamp_column} = 0; 
	}	
	if(! exists($args->{-order_dir})){ 
		$args->{-order_dir} = undef; 
	}
	
	# DEV: There's a reason for this tmp var, correct?
    my $fh = $args->{ -fh };

	binmode $fh, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';

    my $count;
	my $query = ''; 

    if(exists($args->{-partial_listing})){ 
                
        $query = $self->SQL_subscriber_profile_join_statement(  
			{ 
		    -partial_listing       => $args->{-partial_listing},
	        -search_type           => 'all',
			-type                  => $args->{-type},
			-order_by              => $args->{-order_by},
			-order_dir             => $args->{-order_dir},
			-show_timestamp_column => $args->{-show_timestamp_column}, 
			}
		);  
		
    }
	elsif(defined($args->{-query})){    
		my $partial_listing = {};
	    my $fields = $self->subscriber_fields;
	    for (@$fields) {
	        $partial_listing->{$_} = { 
	            -operator => 'LIKE',
                -value    => $args->{ -query },
	            };
	    }
	    # Do I have to do this, explicitly?
	    $partial_listing->{email} = { 
	        -operator => 'LIKE',
            -value    => $args->{ -query },
	    };

		$query = $self->SQL_subscriber_profile_join_statement(  
			{ 
		    -partial_listing       => $partial_listing,
	        -search_type           => 'any',
			-type                  => $args->{-type},
			-query                 => $args->{-query},
			-order_by              => $args->{-order_by},
			-order_dir             => $args->{-order_dir},
			-show_timestamp_column => $args->{-show_timestamp_column}, 
            
			}
		);
	}
	else { 
	    $query =
	      $self->SQL_subscriber_profile_join_statement(
	        { 
				-type                  => $args->{-type}, 
				-show_timestamp_column => $args->{-show_timestamp_column},
			} 
		);
	}

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (for print out list)! $DBI::errstr\n";

    my $fields = $self->subscriber_fields;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    my $hashref = {};


    my @header = ('email');
    if($args->{-show_timestamp_column} == 1){ 
        unshift(@header, 'timestamp'); 
    }
    
    
    for (@$fields) {
        push ( @header, $_ );
    }

    if ( $csv->combine(@header) ) {

        my $hstring = $csv->string;
        print $fh $hstring, "\n";

    }
    else {

        my $err = $csv->error_input;
        carp "combine() failed on argument: ", $err, "\n";

    }

    while ( $hashref = $sth->fetchrow_hashref ) {
        my @info = ( $hashref->{email} );
        if($args->{-show_timestamp_column} == 1){ 
            unshift(@info, $hashref->{timestamp}); 
        }
        
        for (@$fields) {

# DEV: Do we remove newlines here? Huh?
# BUG: [ 2147102 ] 3.0.0 - "Open List in New Window" has unwanted linebreak?
# https://sourceforge.net/tracker/index.php?func=detail&aid=2147102&group_id=13002&atid=113002
            $hashref->{$_} =~ s/\n|\r/ /gi;
            push ( @info, $hashref->{$_} );
        }

        if ( $csv->combine(@info) ) {
            my $string = $csv->string;
            print $fh $string, "\n";
        }
        else {
            my $err = $csv->error_input;
            carp "combine() failed on argument: "
              . $csv->error_input
              . " attempting to encode values and try again...";
              
            require CGI;

            my @new_info = ();
            for my $chunk (@info) {
                push ( @new_info, CGI::escapeHTML($chunk) );
            }
            if ( $csv->combine(@new_info) ) {
                my $hstring2 = $csv->string;
                print $fh $hstring2, "\n";
            }
            else {
                carp "combine() failed on argument: "
                  . $csv->error_input;
            }
        }
        $count++;
    }

    $sth->finish;
    return $count;
    
}

sub clone {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-from} ) ) {
        croak "Need to pass the, '-from' (list type) parameter!";
    }
    if ( !exists( $args->{-to} ) ) {
        croak "Need to pass the, '-from' (list type) parameter!";
    }
    if ( $self->allowed_list_types( $args->{-from} ) == 0 ) {
        croak $args->{-from} . " is not a valid list type!";
    }
    if ( $self->allowed_list_types( $args->{-to} ) == 0 ) {
        croak $args->{-to} . " is not a valid list type!";
    }

    # First we see if there's ANY current members in this list;
    if ( $self->num_subscribers( { -type => $args->{-to} } ) > 0 ) {
        carp
"CANNOT clone a list subtype to another list subtype that already exists!";
        return undef;
    }
    else {
        my $query =
            'INSERT INTO '
          . $self->{sql_params}->{subscriber_table}
          . '(email, list, list_type, list_status) SELECT email, "' . $self->{list} . '", "'. $args->{-to}. '", 1 FROM ' . $self->{sql_params}->{subscriber_table} . ' WHERE list = ? AND list_type = ? AND list_status = ?';
        my $sth = $self->{dbh}->prepare($query);
        $sth->execute( $self->{list}, $args->{-from}, 1 )
        or croak "cannot do statement! $DBI::errstr\n";
    }

    return 1;

}


sub subscription_list {

    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{-start} ) ) {
        $args->{-start} = 0;
    }
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }

    my $email;
    my $count  = 0;
    my $list   = [];
    my $fields = $self->subscriber_fields;

    if ( !exists( $args->{-partial_listing} ) ) {
        $args->{-partial_listing} = {};
    }

    my $query = $self->SQL_subscriber_profile_join_statement($args);
    my $sth   = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (for subscription_list)! $DBI::errstr\n";

    my $hashref;
    my %mf_lt = ();
    for (@$fields) {
        $mf_lt{$_} = 1;
    }

    while ( $hashref = $sth->fetchrow_hashref ) {

        # Probably, just add it here?
        $hashref->{type} = $args->{-type};

        $hashref->{fields} = [];

        for (@$fields) {

            if ( exists( $mf_lt{$_} ) ) {
                push(
                    @{ $hashref->{fields} },
                    {
                        name  => $_,
                        value => $hashref->{$_}
                    }
                );
                delete( $hashref->{$_} );
            }

        }

        push( @$list, $hashref );

    }

    return $list;

}


sub filter_list_through_blacklist {


	# This makes no sense - why not just use a query that looks for unique addresses, 
	# that are in both sublists?
	
    my $self = shift;
    my $list = [];

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = 'black_list' AND list_status = " . $self->{dbh}->quote('1');

    if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

        # Nothin'
    }
    else {
        $query .= ' AND list = ?';
    }

    my $sth = $self->{dbh}->prepare($query);

    if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

        $sth->execute()
          or croak
          "cannot do statement (filter_list_through_blacklist)! $DBI::errstr\n";

    }
    else {

        $sth->execute( $self->{list} )
          or croak
          "cannot do statement (filter_list_through_blacklist)! $DBI::errstr\n";
    }

    my $hashref;
    my $hashref2;

    # Hmm. This seems a little... expensive.

    while ( $hashref = $sth->fetchrow_hashref ) {

        my $query2 =
          'SELECT * from '
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list_type   = 'list' 
		               AND   list_status =  '1'
		               AND   list        =   ? 
		               AND   email      LIKE ?";

        my $sth2 = $self->{dbh}->prepare($query2);
        $sth2->execute( $self->{list}, '%' . $hashref->{email} . '%' )
          or croak
          "cannot do statement (filter_list_through_blacklist)! $DBI::errstr\n";

        while ( $hashref2 = $sth2->fetchrow_hashref ) {
            push ( @$list, $hashref2 );
        }

    }

    return $list;

}

# DEV: This is in need of a rewrite.
# Too bad it works *as is*
# but, it's messy stuff.

sub check_for_double_email {

    my $self = shift;
    my %args = (
        -Email      => undef,
        -Type       => 'list',
        -Status     => 1,
        -Match_Type => 'sublist_centric', # hello, I am bizarre. It's very nice to meet you!
        @_
    );
    my @list;

    if ( $self->{list} and $args{ -Email } ) {

        $args{ -Email } = strip( $args{ -Email } );
        $args{ -Email } = cased( $args{ -Email } );

        if (   $args{ -Type } eq 'black_list'
            && $args{ -Match_Type } eq 'sublist_centric' )
        {
			my $m = $self->inexact_match(
				{
					-against => 'black_list', 
					-email => $args{-Email},
				}
			);
			if($m == 1){ 
				return $m; 
			}
            return 0;

        }

        elsif ($args{ -Type } eq 'white_list'
            && $args{ -Match_Type } eq 'sublist_centric' )
        {

			my $m = $self->inexact_match(
				{
					-against => 'white_list', 
					-email => $args{-Email},
				}
			);
			if($m == 1){ 
				return $m; 
			}
            return 0;

        }
        else {
            my $sth =
              $self->{dbh}->prepare( "SELECT email FROM "
                  . $self->{sql_params}->{subscriber_table}
                  . " WHERE list = ? AND list_type = ? AND email= ? AND list_status = ?"
              );

            $sth->execute(
                $self->{list},
                $args{ -Type },
                $args{ -Email },
                $args{ -Status }
              )
              or croak
              "cannot do statement (for check for double email)! $DBI::errstr\n";
            while ( ( my $email ) = $sth->fetchrow_array ) {
                push ( @list, $email );
            }
            my $in_list = 0;
            if ( $list[0] ) {
                $in_list = 1;
            }
            $sth->finish;
            return $in_list;
        }
    }
    else {
        return 0;
    }
}

sub num_subscribers {

    my $self   = shift;
    my ($args) = @_; 
	if(! exists($args->{-type})){ 
		$args->{-type} = 'list';
	} 
	
    my @row;

    my $query = '';
my $sth = $self->{dbh}->prepare('SELECT * FROM ' . $self->{sql_params}->{subscriber_table});
$sth->execute(); 

    $query .= 'SELECT COUNT(*) ';
    $query .= ' FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE list_type = ? AND list_status = ' . $self->{dbh}->quote('1');

	# I'm sort of guessing, that it's a good idea to do... this!
	if (   $args->{-type} eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {
        # ...
    }
    else {
        $query .= ' AND list = ' . $self->{dbh}->quote($self->{list});
    }
	
    my $count = $self->{dbh}->selectrow_array($query, undef,  $args->{-type}); 
	return $count;

}




sub remove_all_subscribers {

    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{-type} ) {
        $args->{-type} = 'list';
    }

    my $query =
        'SELECT email FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = ? AND list_status = ? AND list = ?";
    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-type}, 1, $self->{list} )
      or croak
      "cannot do statement (at remove_all_subscribers)! $DBI::errstr\n";

    my $count = 0;
    while ( ( my $email ) = $sth->fetchrow_array ) {
        $self->remove_subscriber(
            {
                -email => $email,
                -type  => $args->{-type},
            }
        );
        $count++;
    }

    return $count;
}




sub copy_all_subscribers { 
	
	my $self   = shift ;
	my ($args) = @_; 
	my $total  = 0; 
	if(! exists($args->{-from})){ 
		croak "you MUST pass '-from'";
	}
	else { 
		if ( $self->allowed_list_types( $args->{-from} ) != 1 ) {
            croak '"' . $args->{ -from } . '" is not a valid list type! ';
        }
	}
	if(! exists($args->{-to})){ 
		croak "you MUST pass '-to'";
	}
	else { 
		if ( $self->allowed_list_types( $args->{-to} ) != 1 ) {
            croak '"' . $args->{ -to } . '" is not a valid list type! ';
        }	
	}
	
	my $query = 'SELECT email from ' . $self->{sql_params}->{subscriber_table} . ' WHERE list = ? AND list_type = ?'; 	
	my $sth   = $self->{dbh}->prepare($query); 
	$sth->execute($self->{list}, $args->{-from})
      or croak "cannot do statement $DBI::errstr\n";
	
	while ( ( my $email ) = $sth->fetchrow_array ) {
         chomp($email);
		 my $n_sub = $self->add_subscriber(
			{
				-email         => $email,
				-type          => $args->{-to}, 
				-dupe_check    => {
									-enable  => 1, 
									-on_dupe => 'ignore_add',  
            					},
			}
		 );
		if(defined($n_sub)){ 
			$total++; 
		}
	}
	
	return $total; 
}




sub create_mass_sending_file {

    my $self = shift;

    my %args = (
        -Type                => 'list',
        -Pin                 => 1,
        -ID                  => undef,
        -Ban                 => undef,
        -Bulk_Test           => 0,
        -Save_At             => undef,
        -Test_Recipient      => undef,
        -partial_sending     => {},
        -mass_mailing_params => {},
        -exclude_from        => [],
        @_
    );


	my $b_time = time; 
	
    my $list = $self->{list};
    my $type = $args{-Type};
		
    my @f_a_lists = available_lists();
    my %list_names;
    for (@f_a_lists) {
        my $als = DADA::MailingList::Settings->new( { -list => $_ } );
        my $ali = $als->get;
        $list_names{$_} = $ali->{list_name};
    }

    $list =~ s/ /_/g;    # really...


    my ( $sec, $min, $hour, $day, $month, $year ) =
      (localtime)[ 0, 1, 2, 3, 4, 5 ];
    my $message_id = sprintf(
        "%02d%02d%02d%02d%02d%02d",
        $year + 1900,
        $month + 1, $day, $hour, $min, $sec
    );

    #use the message ID, If we have one.
    my $letter_id = $args{'-ID'} || $message_id;
    $letter_id =~ s/\@/_at_/g;
    $letter_id =~ s/\>|\<//g;

    my $n_msg_id = $args{'-ID'} || $message_id;
    $n_msg_id =~ s/\<|\>//g;
    $n_msg_id =~ s/\.(.*)//;    #greedy

    my %banned_list;

    if ( $args{-Ban} ) {
        my $banned_list = $args{-Ban};
        $banned_list{$_} = 1 for (@$banned_list);
    }

    my $list_file =
      make_safer( $DADA::Config::FILES . '/' . $list . '.' . $type );
    my $sending_file = make_safer( $args{-Save_At} )
      || make_safer(
        $DADA::Config::TMP . '/msg-' . $list . '-' . $type . '-' . $letter_id );

    #open one file, write to the other.
    my $email;

    open my $SENDINGFILE, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      $sending_file
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Cannot create temporary email list file for sending out bulk message: $!";
    chmod( $SENDINGFILE, $DADA::Config::FILE_CHMOD );
    flock( $SENDINGFILE, LOCK_EX );

	my $have_first_recipient = 1; 
	if(
		$args{'-Bulk_Test'} == 0 
	 && $self->{ls}->param('mass_mailing_send_to_list_owner') == 0
	){ 
		$have_first_recipient = 0; 
	}
	# Sending these types of messages to the list owner is very confusing
	if($type =~ m/_tmp\-just_subscribed\-|_tmp\-just_unsubscribed\-|_tmp\-just_subed_archive\-/){ 
		$have_first_recipient = 0; 		
	}

    require     Text::CSV;
    my $csv   = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
    my $total = 0;

    warn '$args{-Test_Recipient} ' . $args{-Test_Recipient}
            if $t; 
    warn '$args{-Bulk_Test}' . $args{-Bulk_Test}
        if $t; 
            
	if($have_first_recipient == 1){ 
	    my $first_email = $self->{ls}->param('list_owner_email');
	    if ( 
			$args{-Bulk_Test} == 1 
		 && $args{-Test_Recipient} 
		) {
	        $first_email = $args{-Test_Recipient};
	    }
	    
	    warn '$first_email ' . $first_email
            if $t; 
            
	    my ( $lo_e_name, $lo_e_domain ) = split( '@', $first_email );

	    my @lo  = (
	        $first_email, 
			$lo_e_name, 
			$lo_e_domain, 
			$self->{list},
	        $list_names{ $self->{list} }, 
			$n_msg_id,
	    );

	# To add to @lo, I want to bring up the Dada Profile and see if there's anything
	# in there...
	    if ( $DADA::Config::PROFILE_OPTIONS->{enabled} == 1 ) {
	        require DADA::Profile;
	        my $dp = DADA::Profile->new( { -email => $first_email } );
	        if ( $dp->exists() ) {
	            require DADA::Profile::Fields;
	            my $dpf = DADA::Profile::Fields->new( { -email => $first_email } );
	            my $fields               = $dpf->{manager}->fields;
	            my $profile_field_values = $dpf->get;
	            for (@$fields) {
	                push( @lo, $profile_field_values->{$_} );
	            }
	        }
	    }

	    if ( $csv->combine(@lo) ) {
	        my $hstring = $csv->string;
	        print $SENDINGFILE $hstring, "\n";
	    }
	    else {
	        my $err = $csv->error_input;
	        carp "combine() failed on argument: ", $err, "\n";
	    }
	    $total++;
	}
	
	if($args{'-Bulk_Test'} != 1){ 
		
        my $query = $self->SQL_subscriber_profile_join_statement(
            {
                -type                => $args{-Type},
                -partial_listing     => $args{-partial_sending},
                -mass_mailing_params => $args{-mass_mailing_params},
                -exclude_from        => $args{-exclude_from},
                -include_from        => $args{-include_from},
            }
        );

        my $sth = $self->{dbh}->prepare($query);

        $sth->execute()
          or croak
          "cannot do statement (at create mass_sending_file)! $DBI::errstr\n";

        my $field_ref;

        while ( $field_ref = $sth->fetchrow_hashref ) {

            chomp $field_ref->{email};    #new..

            unless ( exists( $banned_list{ $field_ref->{email} } ) ) {

                my @sub = (
                    $field_ref->{email},
                    ( split( '@', $field_ref->{email} ) ), # 2..
                    $field_ref->{list},
                    $list_names{ $field_ref->{list} },
                    $n_msg_id,
                );

                for ( @{ $self->subscriber_fields } ) {
                    if ( defined( $field_ref->{$_} ) ) {
                        chomp $field_ref->{$_};
                        $field_ref->{$_} =~ s/\n|\r/ /g;
                    }
                    else {
                        $field_ref->{$_} = '';
                    }

                    push( @sub, $field_ref->{$_} );
                }

                if ( $csv->combine(@sub) ) {
                    my $hstring = $csv->string;
                    print $SENDINGFILE $hstring, "\n";
                }
                else {
                    my $err = $csv->error_input;
                    carp "combine() failed on argument: ", $err, "\n";
                }
                $total++;
            }

        }

        $sth->finish;
    }

    close($SENDINGFILE)
      or croak(
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - could not close temporary sending  file '$sending_file' successfully"
      );

	if($t){ 
		warn "Mass Sending File Time Creation: " . (time - $b_time) . " seconds."; 
	}
	

    return ( $sending_file, $total );

}

sub unique_and_duplicate {

    my $self = shift;

    my %args = (
        -New_List => undef,
        -Type     => 'list',
        @_,
    );

    # first thing we got to do is to make a lookup hash.
    my %lookup_table;
    my $address_ref = $args{ -New_List };

    if ($address_ref) {
        
        for (@$address_ref) { 
            $lookup_table{$_} = 0 
        }

        my $email;

        my $sth = $self->{dbh}->prepare(
            "SELECT email FROM "
              . $self->{sql_params}->{subscriber_table}
              . " WHERE list         = ? 
                  AND list_type      = ?
                  AND  list_status   = '1'"
        );
        $sth->execute( $self->{list}, $args{ -Type } )
          or croak
          "cannot do statement (at unique_and_duplicate)! $DBI::errstr\n";
        while ( ( my $email ) = $sth->fetchrow_array ) {
            chomp($email);
            $lookup_table{$email} = 1 if ( exists( $lookup_table{$email} ) );
            #nabbed it,
        }
        $sth->finish;

        #lets lookie and see what we gots.
        my @unique;
        my @double;
        my $value;

        for ( keys %lookup_table ) {
            $value = $lookup_table{$_};
            if ( $value == 1 ) {
                push ( @double, $_ );
            }
            else {
                push ( @unique, $_ );
            }
        }
        return ( \@unique, \@double );
    }
    else {

        carp(
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: array ref provided!"
        );
        return undef;
    }

}

sub tables {
    my $self   = shift;
    my @tables = $self->{dbh}->tables();
    return \@tables;
}

sub remove_this_listtype {
    my $self = shift;
    my ($args) = @_; 

    if ( !exists( $args->{ -type } ) ) {
        croak('You MUST specific a list type in the "-type" parameter');
    }
    else {
        if ( $self->allowed_list_types( $args->{ -type } ) != 1 ) {
            croak '"' . $args->{ -type } . '" is not a valid list type! ';
        }
    }

    my $sth = $self->{dbh}->prepare(
        "DELETE FROM "
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list    = ?
		                              AND list_type = ?"
    );
    $sth->execute( $self->{list}, $args->{ -type } )
      or croak
      "cannot do statement! (at: remove_this_listttype) $DBI::errstr\n";
    $sth->finish;

	return 1; 
}

sub can_use_global_black_list {

    my $self = shift;
    return 1;

}

sub can_use_global_unsubscribe {

    my $self = shift;
    return 1;

}

sub can_filter_subscribers_through_blacklist {

    my $self = shift;
    return 1;
}

sub can_have_subscriber_fields {

    my $self = shift;
    return 1;
}

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

