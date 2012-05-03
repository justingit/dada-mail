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
	
	my $remote_address = undef; 
	if(!exists($args->{-remote_addr})){ 
		$remote_address = $self->remote_addr;
	}
	else { 
		$remote_address = $args->{-remote_addr}; 
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
            'INSERT INTO ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .'(list,' . $ts_snippet .'remote_addr, msg_id, url'
          . $sql_snippet
          . ') VALUES (?, ?, ?, ?'
          . $place_holder_string . ')';

        my $sth = $self->{dbh}->prepare($query);
        if(defined($timestamp)){ 
			$sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, $args->{-url}, @values );
		}
		else { 
			$sth->execute($self->{name}, $remote_address, $args->{-mid}, $args->{-url}, @values );			
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
	my $remote_address = undef; 
	if(!exists($args->{-remote_addr})){ 
		$remote_address = $self->remote_addr;
	}
	else { 
		$remote_address = $args->{-remote_addr}; 
	}
	
    if ( $self->{ls}->param('enable_open_msg_logging') == 1 ) {
        my $query =
'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'remote_addr, msg_id, event) VALUES (?, ?, ?, ?' . $place_holder_string .')';
        my $sth = $self->{dbh}->prepare($query);
		if(defined($timestamp)){ 
			$sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, 'open' );
		}
		else { 
			$sth->execute($self->{name}, $remote_address, $args->{-mid}, 'open' );
        }
		$sth->finish;
        return 1;
    }
    else {
        return 0;
    }
}

sub sc_log {
    my $self      = shift;
    my ($args)    = @_;
    my $timestamp = undef;
    if ( exists( $args->{-timestamp} ) ) {
        $timestamp = $args->{-timestamp};
    }
    my $ts_snippet          = '';
    my $place_holder_string = '';

    if ( defined($timestamp) ) {
        $ts_snippet = 'timestamp,';
        $place_holder_string .= ' ,?';
    }

    my $remote_address = undef;
    if ( !exists( $args->{-remote_addr} ) ) {
        $remote_address = $self->remote_addr;
    }
    else {
        $remote_address = $args->{-remote_addr};
    }

    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . '(list, '
      . $ts_snippet
      . 'remote_addr, msg_id, event, details) VALUES (?, ?, ?, ?, ?'
      . $place_holder_string . ')';

    my $sth = $self->{dbh}->prepare($query);
    if ( defined($timestamp) ) {
        $sth->execute(
            $self->{name}, $timestamp,        $remote_address,
            $args->{-mid}, 'num_subscribers', $args->{-num}
        ) or carp "cannot do statement! $DBI::errstr\n";
    }
    else {
        $sth->execute(
            $self->{name},     $remote_address, $args->{-mid},
            'num_subscribers', $args->{-num}
        ) or carp "cannot do statement! $DBI::errstr\n";
    }
    $sth->finish;

    return 1;
}




sub logged_sc {
    my $self = shift;
    my ($args) = @_;
    my $query =
        'SELECT COUNT(*) from '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . ' WHERE list = ? AND msg_id = ? AND event = ?';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
       $sth->execute( $self->{name}, $args->{-mid}, 'num_subscribers')
      	or carp "cannot do statement! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

    $sth->finish;

    warn '$count is ' . $count
      if $t;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
}






sub forward_to_a_friend_log {

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

	my $remote_address = undef; 
	if(!exists($args->{-remote_addr})){ 
		$remote_address = $self->remote_addr;
	}
	else { 
		$remote_address = $args->{-remote_addr}; 
	}
	
	
    if ( $self->{ls}->param('enable_forward_to_a_friend_logging') == 1 ) {
		my $query =
'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'remote_addr, msg_id, event) VALUES (?, ?, ?, ?' . $place_holder_string . ')';
        
		my $sth = $self->{dbh}->prepare($query);
		if(defined($timestamp)){ 
	        $sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, 'forward_to_a_friend') 
				or carp "cannot do statement! $DBI::errstr\n";
		}
		else { 
	        $sth->execute($self->{name}, $remote_address, $args->{-mid}, 'forward_to_a_friend') 
				or carp "cannot do statement! $DBI::errstr\n";;			
		}
        $sth->finish;

        return 1;
    }
    else {
        return 0;
    }
}




sub view_archive_log { 
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

	my $remote_address = undef; 
	if(!exists($args->{-remote_addr})){ 
		$remote_address = $self->remote_addr;
	}
	else { 
		$remote_address = $args->{-remote_addr}; 
	}


    if ( $self->{ls}->param('enable_view_archive_logging') == 1 ) {
		my $query =
'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'remote_addr, msg_id, event) VALUES (?, ?, ?, ?' . $place_holder_string . ')';

		my $sth = $self->{dbh}->prepare($query);
		if(defined($timestamp)){ 
	        $sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, 'view_archive') 
				or carp "cannot do statement! $DBI::errstr\n";
		}
		else { 
	        $sth->execute($self->{name}, $remote_address, $args->{-mid}, 'view_archive') 
				or carp "cannot do statement! $DBI::errstr\n";;			
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
	
	my $remote_address = undef; 
	if(!exists($args->{-remote_addr})){ 
		$remote_address = $self->remote_addr;
	}
	else { 
		$remote_address = $args->{-remote_addr}; 
	}
	
    if ( $self->{ls}->param('enable_bounce_logging') == 1 ) {

        my $bounce_type = '';
        if ( $args->{-type} eq 'hard' ) {
            $bounce_type = 'hard_bounce';
        }
        else {
            $bounce_type = 'soft_bounce';
        }
        my $query = 'INSERT INTO ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .'(list, ' . $ts_snippet . 'remote_addr, msg_id, event, details) VALUES (?, ?, ?, ?, ?' . $place_holder_string . ')';
        my $sth = $self->{dbh}->prepare($query);

		if(defined($timestamp)){ 
        	$sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, $bounce_type, $args->{-email} );
		}
		else { 
			$sth->execute($self->{name}, $remote_address, $args->{-mid}, $bounce_type, $args->{-email} );
	        
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
	if($self->{ls}->param('tracker_clean_up_reports') == 1){ 
						# SELECT msg_id FROM dada_mass_mailing_event_log WHERE list = 'dada_announce' AND event = 'num_subscribers'; 
      $msg_id_query1 = 'SELECT msg_id FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND event = \'num_subscribers\' GROUP BY msg_id ORDER BY msg_id DESC;';
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

#	use Data::Dumper;
#	die Data::Dumper::Dumper($msg_id1); 
	my $total = 0; 
	#if(exists $msg_id1->[0]){ 
		$total = scalar @$msg_id1; 
	#}
	if($total == 0){ 
		return ($total, []);
	}	

	my $begin = ($args->{-entries} - 1) * ($args->{-page} - 1);
	my $end   = $begin + ($args->{-entries} - 1);

	if($end > $total - 1){ 
		$end = $total -1; 
	}

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
		
		next 
			unless defined $msg_id;
		
        $report->{$msg_id}->{msg_id} = $msg_id;

        # Clickthroughs
        my $clickthrough_count_query =
'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .' WHERE list = ?  AND msg_id = ?';
        $report->{$msg_id}->{count} =
          $self->{dbh}
          ->selectcol_arrayref( $clickthrough_count_query, {}, $self->{name}, $msg_id )->[0];

        my $misc_count_query =
'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';

	for(
		qw(
			open
			soft_bounce
			hard_bounce
			forward_to_a_friend
			view_archive
		)
	){ 
		$report->{$msg_id}->{$_} =
          $self->{dbh}
          ->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, $_ )->[0];
	}

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

	for(
		qw(
			open
			soft_bounce
			hard_bounce
			forward_to_a_friend
			view_archive
		)
	){
	$report->{$_} = $self->{dbh}->selectcol_arrayref( $misc_count_query, {}, $self->{name}, $msg_id, $_ )->[0];
   }

    my $url_clickthroughs_query =
'SELECT url, COUNT(url) AS count FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' where list = ? AND msg_id = ? GROUP BY url';
    my $sth = $self->{dbh}->prepare($url_clickthroughs_query);
    $sth->execute($self->{name}, $msg_id);
    my $url_report = [];
    my $row        = undef;
    $report->{clickthroughs} = 0; 
    while ( $row = $sth->fetchrow_hashref ) {
        push( @$url_report, { url => $row->{url}, count => $row->{count} } );
		$report->{clickthroughs} = $report->{clickthroughs} + $row->{count};
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
	
    my $query = '';
    if ( $args->{-type} eq 'clickthrough' ) {

		my $custom_fields = $self->custom_fields; 
		my $sql_snippet = ''; 
		if(exists($custom_fields->[0])){ 
			$sql_snippet = join(', ', @$custom_fields);
			$sql_snippet = ', ' . $sql_snippet; 
		}
		
		my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id url), @$custom_fields]);
		print $fh "\n";
		
        $query = 'SELECT timestamp, remote_addr, msg_id, url'. $sql_snippet .' FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
    }
    elsif ( $args->{-type} eq 'activity' ) {
	
		my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id activity details)]);
		print $fh "\n";
		
		# timestamp list message_id activity details
        $query = 'SELECT timestamp, remote_addr, msg_id, event, details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?';
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


sub can_use_country_geoip_data { 
	return 1; 
}
sub country_geoip_data { 
	
	my $self   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-count})){ 
		$args->{-count} = 20; 
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{type} = 'clickthroughs'; 
	}
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}
#	select remote_addr from dada_clickthrough_url_log where msg_id = '20110502135133'; 
	my $query; 
	
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT remote_addr FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
	}
	elsif($args->{-type} eq 'opens'){ 
		$query = 'SELECT remote_addr FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ?'; 	
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT remote_addr FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT remote_addr FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ?'; 			
	}
		
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id=?'; 
	}
	my $sth = $self->{dbh}->prepare($query);
	
	#	die $query; 
		
	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
	}
	else { 
		$sth->execute($self->{name});
	}
	my $ips = []; 

	while ( ( my $ip ) = $sth->fetchrow_array ) {
		push(@$ips, $ip);
	}	

	my $loc = {}; 
	
	require Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->new($args->{-db});

	my $per_country = {}; 
	foreach(@$ips){ 
		my $country = $gi->country_code_by_addr($_);
		if(defined($country)){ 
			if(!exists($per_country->{$country})){ 
				$per_country->{$country} = 0; 
			}
			$per_country->{$country}++;
		}
		else { 
			if(!exists($per_country->{'unknown'})){ 
				$per_country->{unknown} = 0;
			}
			$per_country->{'unknown'}++;
		}
	}
	return $per_country; 
	
}


sub data_over_time {
	 
	my $self   = shift; 
	my ($args) = @_; 
	my $msg_id = undef; 
	my $data   = {};
	my $order  = [];
	my $r      = [];
	
	if(exists($args->{-msg_id})){ 
		$msg_id = $args->{-msg_id};
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs';
	}
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? '; 	
	}
	elsif($args->{-type} eq 'opens') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ? '; 			
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ? '; 					
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ? '; 					
	}
	 
	if($msg_id){ 
		$query .= ' AND msg_id = ?'; 
	}
	$query .= ' ORDER BY timestamp'; 
	
	
    my $sth = $self->{dbh}->prepare($query);
	if($msg_id){ 		
	    $sth->execute($self->{name}, $msg_id)
	      or croak "cannot do statement! $DBI::errstr\n";
	}
	else { 
	    $sth->execute($self->{name})
	      or croak "cannot do statement! $DBI::errstr\n";
	}
	
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		my $date = $row->{timestamp}; 
		my ($mdy, $rest) = split(' ', $date, 2);
		if(!exists($data->{$mdy})){ 
			$data->{$mdy} = 0; 
			push(@$order, $mdy)
		}
		$data->{$mdy}++; 
      }

	foreach(@$order){ 
		push(@$r, {mdy => $_, count => $data->{$_}});
	}

	return $r; 
	
}




sub purge_log { 
	
	
	my $self = shift; 
	
		
		my $query1 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
		my $query2 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?'; 
		
		$self->{dbh}->do($query1, {}, ($self->{name})) or die "cannot do statment $DBI::errstr\n"; 
		$self->{dbh}->do($query2, {}, ($self->{name})) or die "cannot do statment $DBI::errstr\n";


	return 1; 
}



sub remote_addr {
    return $ENV{'REMOTE_ADDR'} || '127.0.0.1';
}




1;
