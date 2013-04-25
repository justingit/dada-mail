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
use Try::Tiny; 

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
sub enabled { 
	my $self = shift; 
	return 1; 
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
		$args->{-remote_addr} = $remote_address; 
	}
	else { 
		$remote_address = $args->{-remote_addr}; 
	}

	if(!exists($args->{-email})){ 
		$args->{-email} = ''; 
	}
	
	if ( $self->{ls}->param('enable_open_msg_logging') == 1 ) {
		my $recorded_open_recently = 1; 
		try {
			$recorded_open_recently = $self->_recorded_open_recently($args);
		} catch {
			carp "Couldn't execute, '_recorded_open_recently', : $_";
		};
		if($recorded_open_recently <= 0) { 
			$self->o_log($args); 
		}
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
            'INSERT INTO ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .'(list,' . $ts_snippet .'remote_addr, msg_id, url, email'
          . $sql_snippet
          . ') VALUES (?, ?, ?, ?, ?'
          . $place_holder_string . ')';

        my $sth = $self->{dbh}->prepare($query);
        if(defined($timestamp)){ 
			$sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, $args->{-url}, $args->{-email}, @values );
		}
		else { 
			$sth->execute($self->{name}, $remote_address, $args->{-mid}, $args->{-url}, $args->{-email}, @values );			
		}
        $sth->finish;

        return 1;
    }
    else {
        return 0;
    }
}


sub _recorded_open_recently {
    my $self = shift;
    my ($args) = @_;

    my $query;

	if ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){ 
		    if ( $args->{-timestamp} ) {
		        $query =
		            'SELECT COUNT(*) from '
		          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
		          . ' where list = ? msg_id = ? AND event = ? AND timestamp >= DATE_SUB('
		          . $args->{timestamp}
		          . ', INTERVAL 1 HOUR)';
		    }
		    else {
		        $query =
		            'SELECT COUNT(*) from '
		          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
		          . ' where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)';
		    }
	}
	elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){
		
		if ( $args->{-timestamp} ) {
	        $query =
	            'SELECT COUNT(*) from '
	          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
	          . " where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= ' . $args->{timestamp} . ' - INTERVAL '1 HOUR'"; 
	    }
	    else {
	        $query =
	            'SELECT COUNT(*) from '
	          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
	          . " where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= NOW() - INTERVAL '1 HOUR'";
	    }
		
	}
	else { 
		 # I'm not sure if I want to tackle SQLite, atm... 
		return 1; 
	}
	

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{name}, $args->{-remote_addr}, $args->{-mid}, 'open' )
      or croak "cannot do statment '$query'! $DBI::errstr\n";

    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];
}


sub o_log {
	my $self      = shift; 
    my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	if(!exists($args->{-email})){ 
		$args->{-email} = '';
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
        my $query = 'INSERT INTO ' 
		. $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} 
		.'(list, ' 
		. $ts_snippet 
		. 'remote_addr, msg_id, event, email) VALUES (?, ?, ?, ?, ?' 
		. $place_holder_string 
		.')';
		
        my $sth = $self->{dbh}->prepare($query);
		if(defined($timestamp)){ 
			$sth->execute($self->{name}, $timestamp, $remote_address, $args->{-mid}, 'open', $args->{-email});
		}
		else { 
			$sth->execute($self->{name}, $remote_address, $args->{-mid}, 'open', $args->{-email});
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
# DEV: 		
# Right now, things are only reported as hard, or soft. 
#        elsif ( $args->{-type} eq 'soft' ) {
#         {
#            $bounce_type = 'soft_bounce';
#        }
#		else { 
#           $bounce_type = 'other';			
#		}
#

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

    if ( !exists( $args->{-page} ) ) {
        $args->{-page} = 1;
    }
    if ( !exists( $args->{-entries} ) ) {
        $args->{-entries} = 10;
    }

# postgres: $query .= ' SELECT DISTINCT ON(' . $subscriber_table . '.email) ';
# This query could probably be made into one, if I could simple use a join, or something
# DEV: There's also this idea:
# SELECT * FROM table ORDER BY rec_date LIMIT ?, ?} #
#     q{SELECT * FROM table ORDER BY rec_date LIMIT ?, ?}

    my $query = '';
    if ( $self->{ls}->param('tracker_clean_up_reports') == 1 ) {

        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? AND event = \'num_subscribers\' GROUP BY msg_id ORDER BY msg_id DESC;';
    }
    else {

        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? GROUP BY msg_id ORDER BY msg_id DESC;';
    }

    my $msg_id1 =
      $self->{dbh}->selectcol_arrayref( $query, {}, ( $self->{name} ) );

    warn 'Query: ' . $query
      if $t;

    my $total = 0;
    $total = scalar @$msg_id1;
    if ( $total == 0 ) {
        return ( $total, [] );
    }


	# DEV: LIMIT, OFFSET - HELLO?!
    my $begin = ( $args->{-entries} - 1 ) * ( $args->{-page} - 1 );
    my $end = $begin + ( $args->{-entries} - 1 );

    if ( $end > $total - 1 ) {
        $end = $total - 1;
    }

    @$msg_id1 = @$msg_id1[ $begin .. $end ];

    return ( $total, $msg_id1 );

}




sub report_by_message_index {

	#my $t = time; 

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

		
		my $basic_event_counts = $self->msg_basic_event_count($msg_id); 
		for(keys %$basic_event_counts) { 
			$report->{$msg_id}->{$_} = $basic_event_counts->{$_};
		}
		
	        my $num_sub_query =
	'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';

			#my $nst = time; 
	        $report->{$msg_id}->{num_subscribers} = $self->{dbh}->selectcol_arrayref( $num_sub_query, { MaxRows => 1 }, $self->{name}, $msg_id, 'num_subscribers' )->[0];
			#warn 'total num_sub time:' . (time - $nst); 
			
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
	
	#warn "total report_by_message_index time:" . (time - $t); 
	
	
    return $sorted_report;
}

sub msg_basic_event_count { 
	
	my $self    = shift; 
	my $msg_id = shift; 
	my $basic_events = {};
    my %ok_events = (
        open                => 1,
        soft_bounce         => 1,
        hard_bounce         => 1,
        forward_to_a_friend => 1,
        view_archive        => 1,
    );
	
	my $basic_count_query = 'SELECT msg_id, event, COUNT(*) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? GROUP BY msg_id, event';
	my $sth              = $self->{dbh}->prepare($basic_count_query);
       $sth->execute( $self->{name}, $msg_id);

    while ( my ( $m, $e, $c ) = $sth->fetchrow_array ) {
		if($ok_events{$e}){ 
			$basic_events->{$e} = $c; 
		}
	}
	
	return $basic_events;
}

sub report_by_message {

    my $self   = shift;
    my $mid    = shift;

	my $m_report = {};
    my $report   = {};
    my $l;
		
    my $num_sub_query =
        'SELECT details FROM '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . ' WHERE list = ? AND msg_id = ? AND event = ?';
    $report->{num_subscribers} =
      $self->{dbh}->selectcol_arrayref( $num_sub_query, { MaxRows => 1 },
        $self->{name}, $mid, 'num_subscribers' )->[0];

	my $basic_event_counts = $self->msg_basic_event_count($mid); 
	for(keys %$basic_event_counts) { 
		$report->{$_} = $basic_event_counts->{$_};
	}


    my $url_clickthroughs_query =
        'SELECT url, COUNT(url) AS count FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}
      . ' where list = ? AND msg_id = ? GROUP BY url';
    my $sth = $self->{dbh}->prepare($url_clickthroughs_query);
    $sth->execute( $self->{name}, $mid );
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

	$m_report = $report; 
    return $m_report;
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
		
		my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id url, email), @$custom_fields]);
		print $fh "\n";
		
        $query = 'SELECT timestamp, remote_addr, msg_id, url, email'. $sql_snippet .' FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
    }
    elsif ( $args->{-type} eq 'activity' ) {
	
		my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id activity details email)]);
		print $fh "\n";
		
		# timestamp list message_id activity details
        $query = 'SELECT timestamp, remote_addr, msg_id, event, details, email FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?';
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

sub export_by_email { 
	
	my $self   = shift; 
	my ($args) = @_;
	
	require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}
	
	my $query; 
	
	if ( $args->{-type} eq 'clickthroughs' ) {
#		print $fh 'clickthroughs'; 
	    $query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
	}
	elsif ( $args->{-type} eq 'opens' ) { 
#		print $fh 'opens'; 
		$query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . " WHERE list = ? AND event = 'open'";
	}
	
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id = ?'; 
	}		
	$query .= ' ORDER BY email ASC';
			
	my $sth = $self->{dbh}->prepare($query);
    
	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
    }
	else { 
		$sth->execute($self->{name});
	}
	
#	print $fh $query . "\n";
#	print $fh . '$self->{name} ' . $self->{name} . "\n"; 
#	print $fh . '$args->{-mid} ' . $args->{-mid} . "\n"; 
	
	warn $query
	 if $t; 
	
	while ( my $fields = $sth->fetchrow_arrayref ) {
        my $status = $csv->print( $fh, $fields );
        print $fh "\n";
    }
	
}





sub can_use_country_geoip_data { 
	return 1; 
}




sub ip_data { 
	my $self   = shift; 
	my ($args) = @_; 

#	if(!exists($args->{-count})){ 
#		$args->{-count} = 20; 
#	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}

#	select remote_addr from dada_clickthrough_url_log where msg_id = '20110502135133'; 
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT timestamp, remote_addr, url FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
	}
	elsif($args->{-type} eq 'opens'){ 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ?'; 	
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'ALL') {
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE (event = \'open\' OR event = \'forward_to_a_friend\' OR event = \'view_archive\') AND list = ?'; 				
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

	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		if($args->{-type} eq 'clickthroughs'){ 
			push(@$ips, {
				timestamp => $row->{timestamp}, 
				ip        => $row->{remote_addr}, 
				event     => 'clickthrough', 
				url       => $row->{url}, 
				
			});
		}
		else { 
			push(@$ips, {
				timestamp => $row->{timestamp}, 
				ip        => $row->{remote_addr}, 
				event     => $row->{event}, 
			});
		}
	}	
	$sth->finish; 

	if($args->{-type} eq 'ALL') {
		my $ct_ips = $self->ip_data(
			{ 
				-type => 'clickthroughs', 
				-mid  => $args->{-mid}, 
			}
		); 
		foreach(@$ct_ips){ 
			push(@$ips, $_);
		}
	}
	return $ips; 
	
}
sub country_geoip_data { 
	
	my $self   = shift; 
	my ($args) = @_; 	
	
#	if(!exists($args->{-count})){ 
#		$args->{-count} = 20; 
#	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}

	my $ip_data = $self->ip_data($args); 
	my $loc = {}; 
	
	require  Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->new($args->{-db});
	my $addr_name   = {};
	my $per_country = {}; 
	foreach(@$ip_data){ 
		my $country = $gi->country_code_by_addr($_->{'ip'});
		
		# Cache the Country name by IP...
	    $addr_name->{$country} = $gi->country_name_by_addr($_->{'ip'});
		
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
	my @r = ();
	foreach(keys %$per_country){ 
		if($_ eq 'unknown'){ 
			push(@r, {
				code => $_, 
				name => 'Unknown',
				count => $per_country->{$_}, 
			});
		}
		else { 
			
			push(@r, {
				code => $_, 
				name => $addr_name->{$_},
				count => $per_country->{$_}, 
			}); 
		}
	}	
	my @sorted = map  { $_->[0] }
	          sort { $b->[1] <=> $a->[1] }
	          map  { [$_, $_->{count}] }
	               @r;

	return \@sorted;
	
	
}

sub country_geoip_json { 
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0;
	}
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'country_geoip_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	
	if(! defined($json)){ 
	
		my $report = $self->country_geoip_data($args);	
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
		       { id => 'location',  label => "Location",       type => 'string',},
		       { id => 'color',     label => $args->{-label},  type => 'number',},
	#	       { id => 'type',      label => 'Type',           type => 'string',},
		);

		for(@$report){ 
			$datatable->add_rows(
		        [
		               { v => $_->{code}, f => $_->{name}},
		               { v => $_->{count} },
	#	               { v => $args->{-type} },
	
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'country_geoip_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
				-data    => \$json, 
			}
		);
		
	}
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json; 
	}
	
}

sub individual_country_geoip { 
	 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}
	if(!exists($args->{-country})){ 
		$args->{-country} = 'US'; 
	}
	
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}
	
	my $report = $self->ip_data($args);
	require Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->open($args->{-db});
	my $d           = {};
	my $cities      = {} ;
	my $ips_by_city = {};
	my $ip_data     = $self->ip_data($args); 
	for my $i_data(@$ip_data){ 
		my ($country_code,$country_code3,$country_name,$region,
		    $city,$postal_code,$latitude,$longitude,
		    $metro_code,$area_code ) = $gi->get_city_record($i_data->{'ip'});
		
		if($country_code eq $args->{-country}){ 
			
			
			if(! $city){
				$city = 'Other'; 
			}
			if($country_code eq 'US'){ 
				$city = $city . ', ' . $region;
			}
			if(!$metro_code){ 
				$metro_code = 'Unknown'; 
			}
				
			if(!exists($d->{"$city\:$metro_code"})){
				$d->{"$city\:$metro_code"} = 0; 
				$cities->{"$city\:$metro_code"} = { 
					lat   => $latitude, 
					long  => $longitude, 
				};
				$ips_by_city->{$city} = [];
			} 
			$d->{"$city\:$metro_code"}++; 
			push(@{$ips_by_city->{$city}}, $i_data);  
		}
	}
	my @r; 
	for(keys %$d){ 
		my ($city, $metro_code) = split(':', $_); 
		push(@r, 
			{ 
			lat        => $cities->{$_}->{lat}, 
			long       => $cities->{$_}->{long}, 
			city       => $city, 
			count      => $d->{$_}, 
			ip_data    => $ips_by_city->{$city},
		});
	} 
	# sort by city
	my @sorted = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->{city} ] } @r;
	return [@sorted]; 
}

sub individual_country_geoip_json {
	
	my $self   = shift; 
	my ($args) = @_; 
	
	
	my $json;
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	my $report = $self->individual_country_geoip($args);


	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'individual_country_geoip' . '.' . $args->{-mid} . '.' . $args->{-type} . '.' . $args->{-country}, 
		}
	);
	
	if(! defined($json)){
		
		my $report = $self->individual_country_geoip($args);
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();


		$datatable->add_columns(
		       { id => 'latitude',     label => "Latitude",        type => 'number',},
		       { id => 'longitude',    label => "Longitude",       type => 'number',},
		       { id => 'DESCRIPTION',  label => "Description",     type => 'string',},
		       { id => 'marker_color', label => "Clickthroughs",   type => 'number',},
		);
	
	
		for my $r(@$report) { 
			$datatable->add_rows(
		        [   
		               { v => $r->{lat},   },
		               { v => $r->{long},  },
					   { v => $r->{city},  },
					   { v => $r->{count},},
		       ],
			);
		}
	
		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'individual_country_geoip' . '.' . $args->{-mid} . '.' . $args->{-type} . '.' . $args->{-country}, 
				-data    => \$json, 
			}
		);
	}
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json; 
	}
}
sub individual_country_geoip_report { 
	my $self   = shift; 
	my ($args) = @_;  

	my %labels = (
		open                => 'Open', 
		clickthrough        => 'Clickthrough', 
		view_archive 	    => 'Archive View',
		forward_to_a_friend => 'Forward',  
	); 
	
	my $report = $self->individual_country_geoip($args);



	# This needs to be munged - count each specific IPS: 
	for my $loc(@$report) { 
		my $unique_ips = {};
		my $ip_history = {};
		for my $ipdata(@{$loc->{ip_data}}){ 
			if(!exists($unique_ips->{$ipdata->{ip}})){ 
				$unique_ips->{$ipdata->{ip}} = 0;
				$ip_history->{$ipdata->{ip}} = [];
			}
			$unique_ips->{$ipdata->{ip}}++;
			my $time = $self->timestamp_to_time($ipdata->{timestamp});

			push(@{$ip_history->{$ipdata->{ip}}}, { 
				timestamp   => $ipdata->{timestamp},
				time        => $time, 
				ctime       => scalar(localtime($time)), 
                url         => $ipdata->{url},
                event       => $ipdata->{event},
				event_label => $labels{$ipdata->{event}},
			}); 
		}
		$loc->{unique_ips} = [];
		
		# Sort ip events by date
		my $sorted_ip_history = {};
		for my $unsorted_ips(keys %$ip_history){ 
			$sorted_ip_history->{$unsorted_ips} = [];
			
			
			my $u_ip_data = $ip_history->{$unsorted_ips};
			
			my @sorted_ips = map { $_->[0] }
	          sort { $a->[1] <=> $b->[1] }
	          map { [ $_, $_->{'time'} ] } @$u_ip_data;
	
			 $sorted_ip_history->{$unsorted_ips} = [@sorted_ips]; 
		}
		undef($ip_history); # garbage collect? 
		#/ Sort ip events by date
		
		
		for my $u_ips(keys %$unique_ips){ 
			push(@{$loc->{unique_ips}}, {
				ip         => $u_ips, 
				count      => $unique_ips->{$u_ips}, 
				ip_history => $sorted_ip_history->{$u_ips},
			}); 
		}
		$loc->{unique_ip_count} = scalar(@{$loc->{unique_ips}}); 
		delete($loc->{ip_data});
	} 
	return $report;
	
	
}
sub timestamp_to_time {
	my $self = shift;  	
	my $timestamp = shift;
	
	require Time::Local; 
	 
	my ($date, $time) = split(' ', $timestamp); 
	my ($year, $month, $day) = split('-', $date); 
	my ($hour, $minute, $second) = split(':', $time); 
	$second = int($second - 0.5) ;
	return Time::Local::timelocal( $second, $minute, $hour, $day, $month-1, $year );
}

sub individual_country_geoip_report_table { 
	my $self   = shift; 
	my ($args) = @_;
	my $html; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'individual_country_geoip_report_table' . '.' . $args->{-mid} . '.' . $args->{-country}. '.' . $args->{-type} . '.' . $args->{-chrome},
		}
	);
	if(!defined($html)){ 
	
	
		my $report = $self->individual_country_geoip_report($args);
	
		require DADA::Template::Widgets; 
		$html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/individual_country_geoip_report_table.tmpl',
	            -vars => {
					report => $report, 
					num_bounces   => scalar(@$report), 
					title         => $args->{-type},  
					country       => $args->{-country}, 
					chrome        => $args->{-chrome}, 
					mid           => $args->{-mid}, 
					Plugin_URL    => $args->{Plugin_URL}, 
	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'individual_country_geoip_report_table' . '.' . $args->{-mid} . '.' . $args->{-country}. '.' . $args->{-type} . '.' . $args->{-chrome},
				-data    => \$html, 
			}
		);
	}
	
	
	use CGI qw(:standard); 
	print header(); 
	print $html; 
    
}


sub data_over_time {
	 
	my $self   = shift; 
	my ($args) = @_; 
	my $mid    = undef; 
	my $data   = {};
	my $order  = [];
	my $r      = [];
	
	if(exists($args->{-mid})){ 
		$mid = $args->{-mid};
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
	 
	if($mid){ 
		$query .= ' AND msg_id = ?'; 
	}
	$query .= ' ORDER BY timestamp'; 
	
	
    my $sth = $self->{dbh}->prepare($query);
	if($mid){ 		
	    $sth->execute($self->{name}, $mid)
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

sub data_over_time_json { 
	my $self   = shift; 
	my ($args) = @_;
	
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'data_over_time_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	
	if(! defined($json)){ 
		
		my $report = $self->data_over_time($args);
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
			   { id => 'date',          label => 'Date',           type => 'string'}, 
			   { id => 'number',         label => $args->{-label},  type => 'number',},
		);

		for(@$report){ 
			$datatable->add_rows(
		        [
		               { v => $_->{mdy}  },
		               { v => $_->{count} },
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'data_over_time_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
				-data    => \$json, 
			}
		);
	}
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json; 
	}
}



sub message_bounce_report { 
	
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-mid})){ 
		croak "You MUST pass the, '-mid' paramater!"; 
	}
	my $mid = $args->{-mid};
	my $type = 'soft'; 
	if(exists($args->{-bounce_type})){ 
		$type = $args->{-bounce_type};
	}
	
        my $bounce_query =
            'SELECT timestamp, details from '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? AND msg_id = ? AND event = ? ORDER BY details';
        my $sth = $self->{dbh}->prepare($bounce_query);

        $sth->execute( $self->{name}, $mid, $type . '_bounce' );
        my @bounce_report = ();
        while (my $row = $sth->fetchrow_hashref ) {
            my ( $name, $domain ) = split( '@', $row->{details} );
            push(
                @bounce_report,
                {
                    timestamp    => $row->{timestamp},
                    email        => $row->{details},
                    email_name   => $name,
                    email_domain => $domain,
                }
            );
        }		
        # sort by domain...
        my @sorted = map { $_->[0] }
          sort { $a->[1] cmp $b->[1] }
          map { [ $_, $_->{email_domain} ] } @bounce_report;
        $sth->finish;

		return [@sorted]; 
		
}
sub message_bounce_report_table { 
	my $self   = shift; 
	my ($args) = @_; 
	my $html; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_bounce_report_table' . '.' . $args->{-mid} . '.' . $args->{-bounce_type} , 
		}
	);
	if(! defined($html)){ 
	
		my $title; 
		if($args->{-bounce_type} eq 'soft'){ 
			$title => 'Soft'; 
		}
		else { 
			$title => 'Hard'; 
		}
		my $report = $self->message_bounce_report($args);
		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_bounce_report_table.tmpl',
	            -vars => {
					bounce_report => $report, 
					num_bounces   => scalar(@$report), 
					title         => $title,  
	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_bounce_report_table' . '.' . $args->{-mid} . '.' . $args->{-bounce_type} , 
				-data    => \$html, 
			}
		);
	}
	use CGI qw(:standard); 
	print header(); 
	e_print($html); 
}


sub bounce_stats { 
	
	my $self = shift; 
	my ($args) = @_; 
	my $mid = $args->{-mid};
	my $count; 
	if(!exists($args->{-count})){ 
		$count = 15; 
	}
	else { 
		$count = $args->{-count};
	}
	
	my $type = 'soft'; 
	if(exists($args->{-bounce_type})){ 
		$type = $args->{-bounce_type};
	}
	
	my $report = $self->message_bounce_report($args);
	
	
	my $data = {};

	for my $bounce_report(@$report ){ 

		my $email = $bounce_report->{email};

		my ($name, $domain) = split('@', $email); 
		if(!exists($data->{$domain})){ 
			$data->{$domain} = 0;
		}
		$data->{$domain} = $data->{$domain} + 1; 	
	}
	# Sorted Index
	my @index = sort { $data->{$b} <=> $data->{$a} } keys %$data; 

	# Top n
	my @top = splice(@index,0,($count-1));

	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $data->{$_};
	}
	my $final = [];
	foreach(@top){ 
		push(@$final, {domain => $_, number => $data->{$_}});
		
		#$final->{$_} = $data->{$_};
	}
	if($other > 0){ 
	#	$final->{other} = $other;
		push(@$final, {domain => 'other', number => $other}); 
	
	}		
	
	return $final; 

}

sub bounce_stats_json { 
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-count})){ 
		$args->{-count} = 15; 
	}

	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'bounce_stats_json' . '.' . $args->{-mid} . '.' . $args->{-count} . '.' . $args->{-bounce_type} , 
		}
	);
	
	if(!defined($json)){ 
		my $stats = $self->bounce_stats($args);
	 

		require         Data::Google::Visualization::DataTable;
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
		       { id => 'domain',     label => "Domain",        type => 'string',},
		       { id => 'number',     label => "Number",        type => 'number',},
		);

		for(@$stats){ 
			$datatable->add_rows(
		        [
		               { v => $_->{domain} },
		               { v => $_->{number} },
		       ],
			);
		}

		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'bounce_stats_json' . '.' . $args->{-mid} . '.' . $args->{-count} . '.' . $args->{-bounce_type} , 
				-data    => \$json, 
			}
		);
	}
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json;
	}
	
}



sub purge_log { 
	
	
	my $self = shift; 
	
		
		my $query1 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
		my $query2 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?'; 
		
		$self->{dbh}->do($query1, {}, ($self->{name})) or die "cannot do statment $DBI::errstr\n"; 
		$self->{dbh}->do($query2, {}, ($self->{name})) or die "cannot do statment $DBI::errstr\n";

		require DADA::App::DataCache; 
		my $dc = DADA::App::DataCache->new;
		$dc->flush(
			{
				-list => $self->{name}
			}
		);
		
	return 1; 
}



sub remote_addr {
    return $ENV{'REMOTE_ADDR'} || '127.0.0.1';
}




1;
