package DADA::Logging::Clickthrough::baseSQL;

use lib qw(../../../ ../../../DADA/perllib);

use strict;

use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB);
use Carp qw(croak carp);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;    # For now, my dear.

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Logging_Clickthrough};

sub new {

    my $class  = shift;
    my ($args) = @_;
    my $self   = {};
    bless $self, $class;
    $self->_init($args);
    $self->_sql_init($args);
    return $self;
}

sub _sql_init {

    my $self = shift;
    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub custom_fields {
    my $self = shift;
    my $cols = $self->_columns;

    my %omit_fields = (
        url_id      => 1,
        redirect_id => 1,
        msg_id      => 1,
        url         => 1,
    );

    my $custom = [];
    for (@$cols) {
        if ( !exists( $omit_fields{$_} ) ) {
            push( @$custom, $_ );
        }
    }
    return $custom;
}

sub _columns {

    my $self = shift;
    my @cols;

    if ( exists( $self->{cache}->{columns} ) ) {
        return $self->{cache}->{columns};
    }
    else {
        my $query =
            "SELECT * FROM "
          . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
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

sub add {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url    = shift;
    my $fields = shift;

    my $key = $self->random_key();

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $self->custom_fields };
    my @values;
    if ( $order[0] ) {
        for my $field (@order) {
            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            push( @values, $fields->{$field} );
        }
    }
    $sql_str =~ s/,$//;

    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . '(redirect_id, msg_id, url'
      . $sql_str
      . ') values(?,?,?'
      . $place_holder_string . ')';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $key, $mid, $url, @values )
      or croak "cannot do statement! (at: add) $DBI::errstr\n";
    return $key;

}

sub reuse_key {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url    = shift;
    my $fields = shift;

    my $custom_fields = $self->custom_fields;
    my %cust_fields   = ();
    foreach (@$custom_fields) {
        $cust_fields{$_} = 1;
    }
    my $place_holder_string = '';
    my @values              = ();

    foreach my $field ( keys %$fields ) {
        if ( exists( $cust_fields{$field} ) ) {
            push( @values, $fields->{$field} );
            $place_holder_string .= ' AND ' . $field . ' = ?';
        }
    }
    my $query =
        'SELECT * FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE msg_id = ? AND url = ? '
      . $place_holder_string;

    warn 'QUERY: ' . $query
 		if $t;
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $mid, $url, @values )
      or croak "cannot do statement! (at: reuse_key) $DBI::errstr\n";
    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        return $hashref->{redirect_id};
    }

    return undef;

}

sub fetch {

    my $self = shift;
    my $key  = shift;
    die "no key! " if !defined $key;

    my $sql_snippet = '';
    my $fields      = $self->custom_fields;
    foreach (@$fields) {
        $sql_snippet .= ', ' . $_;
    }

    my $query =
        'SELECT msg_id, url'
      . $sql_snippet
      . ' FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE  redirect_id = ?';
    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($key)
      or croak "cannot do statement! (at: fetch) $DBI::errstr\n";
    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        my $msg_id = $hashref->{msg_id};
        my $url    = $hashref->{url};
        delete( $hashref->{msg_id} );
        delete( $hashref->{url} );
        return ( $msg_id, $url, $hashref );
    }

    return ( undef, undef, {} );
}

sub key_exists {

    my $self = shift;
    my ($args) = @_;

    my $query =
        'SELECT COUNT(*) FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE redirect_id = ? ';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-key} )
      or croak "cannot do statement (at key_exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];

}

sub r_log {

    my $self      = shift; 
    my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	my $atts = {};
	if(exists($args->{-atts})){ 
		$atts = $args->{-atts};
	}
	
    if ( $self->{ls}->param('clickthrough_tracking') == 1 ) {
        my $place_holder_string = '';
        my $sql_snippet         = '';

        my @values    = ();
        my $fields    = $self->custom_fields;
        my $lt_fields = {};
        foreach (@$fields) {
            $lt_fields->{$_} = 1;
        }

        foreach ( keys %$atts ) {
            if ( exists( $lt_fields->{$_} ) ) {
                push( @values, $atts->{$_} );
                $place_holder_string .= ' ,?';
                $sql_snippet .= ' ,' . $_;
            }
        }
		my $ts_snippet = ''; 
		if(defined($timestamp)){ 
			$ts_snippet = 'timestamp,'; 
			$place_holder_string .= ' ,?';
		}
        my $query =
            'INSERT INTO ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .'(list,' . $ts_snippet .'msg_id, url'
          . $sql_snippet
          . ') VALUES (?, ?, ?'
          . $place_holder_string . ')';

        my $sth = $self->{dbh}->prepare($query);
        if(defined($timestamp)){ 
			$sth->execute($self->{name}, $timestamp, $args->{-mid}, $args->{-url}, @values );
		}
		else { 
			$sth->execute($self->{name}, $args->{-mid}, $args->{-url}, @values );			
		}
        $sth->finish;

        return 1;
    }
    else {
        return 0;
    }
}

sub o_log {
	my $self      = shift; 
    my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	my $ts_snippet = ''; 
	my $place_holder_string = ''; 
	
	if(defined($timestamp)){ 
		$ts_snippet = 'timestamp,'; 
		$place_holder_string .= ' ,?';
	}
	
    if ( $self->{ls}->param('is_log_openings_on') == 1 ) {
        my $query =
'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'msg_id, event) VALUES (?, ?, ?' . $place_holder_string .')';
        my $sth = $self->{dbh}->prepare($query);
		if(defined($timestamp)){ 
			$sth->execute($self->{name}, $timestamp, $args->{-mid}, 'open' );
		}
		else { 
			$sth->execute($self->{name}, $args->{-mid}, 'open' );
        }
		$sth->finish;
        return 1;
    }
    else {
        return 0;
    }
}

sub sc_log {
    #my ( $self, $mid, $sc ) = @_;

	my $self      = shift; 
    my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	my $ts_snippet = ''; 
	my $place_holder_string = ''; 
	
	if(defined($timestamp)){ 
		$ts_snippet = 'timestamp,'; 
		$place_holder_string .= ' ,?';
	}
	
	
    if ( $self->{ls}->param('enable_subscriber_count_logging') == 1 ) {
		my $query =
'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'msg_id, event, details) VALUES (?, ?, ?, ?' . $place_holder_string . ')';
        

		print 'query "' . $query . '"'; 
		my $sth = $self->{dbh}->prepare($query);
		if(defined($timestamp)){ 
	        $sth->execute($self->{name}, $timestamp, $args->{-mid}, 'num_subscribers', $args->{-num});
		}
		else { 
	        $sth->execute($self->{name}, $args->{-mid}, 'num_subscribers', $args->{-num});			
		}
        $sth->finish;

        return 1;
    }
    else {
        return 0;
    }
}

sub bounce_log {
   # my ( $self, $type, $mid, $email ) = @_;

	my $self      = shift; 
	my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	my $ts_snippet = ''; 
	my $place_holder_string = ''; 
	
	if(defined($timestamp)){ 
		$ts_snippet = 'timestamp,'; 
		$place_holder_string .= ' ,?';
	}
	
	
    if ( $self->{ls}->param('is_log_bounces_on') == 1 ) {

        my $bounce_type = '';
        if ( $args->{-type} eq 'hard' ) {
            $bounce_type = 'hard_bounce';
        }
        else {
            $bounce_type = 'soft_bounce';
        }
        my $query = 'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'msg_id, event, details) VALUES (?, ?, ?, ?' . $place_holder_string . ')';
        my $sth = $self->{dbh}->prepare($query);

		if(defined($timestamp)){ 
        	$sth->execute($self->{name}, $timestamp, $args->{-mid}, $bounce_type, $args->{-email} );
		}
		else { 
			$sth->execute($self->{name}, $args->{-mid}, $bounce_type, $args->{-email} );
	        
		}
        $sth->finish;

        close(LOG);
        return 1;
    }
    else {
        return 0;
    }
}

sub unique_and_dupe {
    my $self  = shift;
    my $array = shift;

    my @unique = ();
    my %seen   = ();

    foreach my $elem (@$array) {
        next if $seen{$elem}++;
        push @unique, $elem;
    }
    return [@unique];

}


sub get_all_mids { 

	my $self = shift; 
	my ($args) = @_;
	
	if(!exists($args->{-page})){ 
		$args->{-page} = 1; 
	}
	if(!exists($args->{-entries})){ 
		$args->{-entries} = 10; 
	}
	
	# postgres: $query .= ' SELECT DISTINCT ON(' . $subscriber_table . '.email) ';
	# This query could probably be made into one, if I could simple use a join, or something,

	# DEV: There's also this idea: 
	# SELECT * FROM table ORDER BY rec_date LIMIT ?, ?} #
	#     q{SELECT * FROM table ORDER BY rec_date LIMIT ?, ?}
	
	my $msg_id_query1 = ''; 
	if($self->{-li}->{tracker_clean_up_reports} == 1){ 
      $msg_id_query1 = 'SELECT msg_id FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND event = "num_subscribers" GROUP BY msg_id ORDER BY msg_id DESC;';
	}
	else { 
		$msg_id_query1 = 'SELECT msg_id FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? GROUP BY msg_id ORDER BY msg_id DESC;';
	}
 #   my $msg_id_query2 =
 #     'SELECT msg_id FROM dada_clickthrough_url_log WHERE list = ? GROUP BY msg_id  ORDER BY msg_id DESC;';

    my $msg_id1 = $self->{dbh}->selectcol_arrayref($msg_id_query1, {}, ($self->{name})); #($statement, \%attr, @bind_values);
 #   my $msg_id2 = $self->{dbh}->selectcol_arrayref($msg_id_query2, {}, ($self->{name}));
 #   push( @$msg_id1, @$msg_id2 );
 #   $msg_id1 = $self->unique_and_dupe($msg_id1);

	my $total = scalar @$msg_id1; 
	if($total == 0){ 
		return ($total, []);
	}	

	my $begin = ($args->{-entries} - 1) * ($args->{-page} - 1);
	my $end   = $begin + ($args->{-entries} - 1);
	@$msg_id1 = @$msg_id1[$begin..$end];
	return ($total, $msg_id1);


}




sub report_by_message_index {

    my $self          = shift;
	my ($args)        = @_; 
	
    my $sorted_report = [];
    my $report        = {};
    my $l;
	
	my $total   = undef; 
	my $msg_id1 = []; 
	
	if(exists($args->{-all_mids})){ 
		$msg_id1 = $args->{-all_mids};
	}
	else { 
		# Not using total, right now... 
		($total, $msg_id1) = $self->get_all_mids();
	}
	

	
    for my $msg_id (@$msg_id1) {

        $report->{$msg_id}->{msg_id} = $msg_id;

        # Clickthroughs
        my $clickthrough_count_query =
'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .' WHERE list = ?  AND msg_id = ?';
        $report->{$msg_id}->{count} =
          $self->{dbh}
          ->selectcol_arrayref( $clickthrough_count_query, {}, $self->{name}, $msg_id )->[0];

        my $misc_count_query =
'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';
        $report->{$msg_id}->{open} =
          $self->{dbh}
          ->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, 'open' )->[0];
        $report->{$msg_id}->{soft_bounce} =
          $self->{dbh}
          ->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, 'soft_bounce' )
          ->[0];
        $report->{$msg_id}->{hard_bounce} =
          $self->{dbh}
          ->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, 'hard_bounce' )
          ->[0];

        my $num_sub_query =
'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';

        $report->{$msg_id}->{num_subscribers} = $self->{dbh}->selectcol_arrayref( $num_sub_query, { MaxRows => 1 }, $self->{name}, $msg_id, 'num_subscribers' )->[0];

    }

    require DADA::MailingList::Archives;
    my $mja = DADA::MailingList::Archives->new( { -list => $self->{name} } );

    # Now, sorted:
    for ( sort { $b <=> $a } keys %$report ) {
        $report->{$_}->{mid} = $_;    # this again.
        $report->{$_}->{date} =
          DADA::App::Guts::date_this( -Packed_Date => $_, );
		$report->{$_}->{S_PROGRAM_URL} = $DADA::Config::S_PROGRAM_URL; 
		$report->{$_}->{list} = $self->{name}; 
        if ( $mja->check_if_entry_exists($_) ) {
            $report->{$_}->{message_subject} = $mja->get_archive_subject($_)
              || $_;
        }
        else {
        }

        push( @$sorted_report, $report->{$_} );
    }

    return $sorted_report;
}

sub report_by_message {

    my $self   = shift;
    my $msg_id = shift;

    my $report = {};
    my $l;

    my $num_sub_query =
'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND event = ?';
    $report->{num_subscribers} =
      $self->{dbh}->selectcol_arrayref( $num_sub_query, { MaxRows => 1 },
        $self->{name}, $msg_id, 'num_subscribers' )->[0];

    my $misc_count_query =
'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND event = ?';

    #	# This may be different.
    $report->{open} =
      $self->{dbh}->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, 'open' )
      ->[0];
    $report->{soft_bounce} =
      $self->{dbh}
      ->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, 'soft_bounce' )
      ->[0];
    $report->{hard_bounce} =
      $self->{dbh}
      ->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, 'hard_bounce' )
      ->[0];

    my $url_clickthroughs_query =
'SELECT url, COUNT(url) AS count FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' where list = ? AND msg_id = ? GROUP BY url';
    my $sth = $self->{dbh}->prepare($url_clickthroughs_query);
    $sth->execute($self->{name}, $msg_id);
    my $url_report = [];
    my $row        = undef;
    while ( $row = $sth->fetchrow_hashref ) {
        push( @$url_report, { url => $row->{url}, count => $row->{count} } );
    }
    $sth->finish;
    undef $sth;
    $report->{url_report} = $url_report;

    for my $bounce_type (qw(soft_bounce hard_bounce)) {
        my $bounce_query =
'SELECT timestamp, details from ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND event = ? ORDER BY timestamp';
        my $sth = $self->{dbh}->prepare($bounce_query);
        $sth->execute($self->{name},  $msg_id, $bounce_type );
        my $bounce_report = [];
        while ( $row = $sth->fetchrow_hashref ) {
            push( @$bounce_report,
                { timestamp => $row->{timestamp}, email => $row->{details} } );
        }
        $report->{ $bounce_type . '_report' } = $bounce_report;
        $sth->finish;
    }
    return $report;
}

sub export_logs {

    my $self   = shift;
	my ($args) = @_; 

	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthrough';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}


    my $l;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

	if($args->{-type} eq 'clickthrough'){ 
		my $title_status = $csv->print ($fh, [qw(timestamp list message_id url)]);
		print $fh "\n";
	}
	elsif($args->{-type} eq 'activity'){ 
		my $title_status = $csv->print ($fh, [qw(timestamp list message_id activity details)]);
		print $fh "\n";
	}
	
    my $query = '';
    if ( $args->{-type} eq 'clickthrough' ) {
        $query = 'SELECT * FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
    }
    elsif ( $args->{-type} eq 'activity' ) {
        $query = 'SELECT * FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?';
    }
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id = ?'; 
	}

    my $sth = $self->{dbh}->prepare($query);

	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
    }
	else { 
		$sth->execute($self->{name});
	}

 	while ( my $fields = $sth->fetchrow_arrayref ) {
        my $status = $csv->print( $fh, $fields );
        print $fh "\n";
    }
}




sub purge_log { 
	my $self = shift; 
	my $query1 = 'TRUNCATE ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}; 
	my $query2 = 'TRUNCATE ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}; 
	$self->{dbh}->do($query1); 
	$self->{dbh}->do($query2); 
	return 1; 
}




1;
