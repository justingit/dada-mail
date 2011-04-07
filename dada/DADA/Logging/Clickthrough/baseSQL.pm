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

    my $class = shift;
    my ($args) = @_;
    my $self = {};
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

sub add {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url = shift;
    my $key = $self->random_key();

    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . '(redirect_id, msg_id, url) values(?,?,?)';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $key, $mid, $url )
      or croak "cannot do statement! (at: add) $DBI::errstr\n";

    return $key;

}

sub reuse_key {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url = shift;

    my $query =
      'SELECT * FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE msg_id = ? AND url = ? ';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $mid, $url )
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

    my $query =
      'SELECT msg_id, url FROM '
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
        return ( $hashref->{msg_id}, $hashref->{url} );
    }

    return ( undef, undef );
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

    $sth->execute( $args->{ -key } )
      or croak "cannot do statement (at key_exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];

}



sub r_log { 
	
	# stamp mid, url
	
	my ($self, $mid, $url) = @_;
	if($self->{is_redirect_on} == 1){ 
	my $query = 'INSERT INTO dada_clickthrough_url_log(msg_id,url) VALUES (?, ?)';

	my $sth   = $self->{dbh}->prepare($query); 
	   $sth->execute($mid, $url); 
	   $sth->finish;

		return 1; 
	}else{ 
		return 0;
	}
}



sub o_log { 
	my ($self, $mid) = @_;
	if($self->{is_log_openings_on} == 1){ 
		my $query = 'INSERT INTO dada_mass_mailing_event_log(msg_id, event) VALUES (?, ?)';
		my $sth   = $self->{dbh}->prepare($query); 
		   $sth->execute($mid, 'open'); 
		   $sth->finish;
		return 1; 
	}else{ 
		return 0;
	}
}




sub sc_log { 
	my ($self, $mid, $sc) = @_;
	if($self->{enable_subscriber_count_logging} == 1){ 
		my $query = 'INSERT INTO dada_mass_mailing_event_log(msg_id, event, details) VALUES (?, ?, ?)';
		my $sth   = $self->{dbh}->prepare($query); 
		   $sth->execute($mid, 'num_subscribers', $sc); 
		   $sth->finish;

		return 1; 
	}else{ 
		return 0;
	}
}




sub bounce_log { 
	my ($self, $type, $mid, $email) = @_;
	if($self->{is_log_bounces_on} == 1){ 
		
		my $bounce_type = ''; 
		if($type eq 'hard'){ 
			$bounce_type = 'hard_bounce'; 
		}
		else { 
			$bounce_type = 'soft_bounce'; 
		}
		my $query = 'INSERT INTO dada_mass_mailing_event_log(msg_id, event, details) VALUES (?, ?, ?)';
		my $sth   = $self->{dbh}->prepare($query); 
		   $sth->execute($mid, $bounce_type, $email); 
		   $sth->finish;
		
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}



sub unique_and_dupe { 
	my $self = shift; 
	my $array = shift; 
	
 	my @unique = ();
 	my %seen = ();
   
    foreach my $elem ( @$array )
    {
    next if $seen{ $elem }++;
    push @unique, $elem;
    }
	return [@unique];
	
}

sub report_by_message_index {
    my $self          = shift;
    my $sorted_report = [];
    my $report        = {};
    my $l;

	# postgres: $query .= ' SELECT DISTINCT ON(' . $subscriber_table . '.email) ';
    
	# This query could probably be made into one, if I could simple use a join, or something, 
	my $msg_id_query1 = 'SELECT msg_id FROM dada_mass_mailing_event_log GROUP BY msg_id;';
	my $msg_id_query2 = 'SELECT msg_id FROM dada_clickthrough_url_log GROUP BY msg_id;';
	
	my $msg_id1 = $self->{dbh}->selectcol_arrayref($msg_id_query1);
	my $msg_id2 = $self->{dbh}->selectcol_arrayref($msg_id_query2);
	push(@$msg_id1, @$msg_id2);
	$msg_id1 = $self->unique_and_dupe($msg_id1); 
	
	for my $msg_id(@$msg_id1){
		
		$report->{$msg_id}->{msg_id} = $msg_id; 
		
		# Clickthroughs 
		my $clickthrough_count_query = 'SELECT COUNT(msg_id) FROM dada_clickthrough_url_log WHERE msg_id = ?';
		$report->{$msg_id}->{count} = $self->{dbh}->selectcol_arrayref($clickthrough_count_query, {}, $msg_id)->[0];
		
		my $misc_count_query = 'SELECT COUNT(msg_id) FROM dada_mass_mailing_event_log WHERE msg_id = ? AND event = ?';
		$report->{$msg_id}->{open} = $self->{dbh}->selectcol_arrayref($misc_count_query, {}, $msg_id, 'open')->[0];
		$report->{$msg_id}->{soft_bounce} = $self->{dbh}->selectcol_arrayref($misc_count_query, {}, $msg_id, 'soft_bounce')->[0];
		$report->{$msg_id}->{hard_bounce} = $self->{dbh}->selectcol_arrayref($misc_count_query, {}, $msg_id, 'hard_bounce')->[0];

		my $num_sub_query = 'SELECT details FROM dada_mass_mailing_event_log WHERE msg_id = ? AND event = ?';
		$report->{$msg_id}->{num_subscribers} = $self->{dbh}->selectcol_arrayref($num_sub_query, {MaxRows => 1}, $msg_id, 'num_subscribers')->[0];
			
	}

        require DADA::MailingList::Archives;
        my $mja =
          DADA::MailingList::Archives->new( { -list => $self->{name} } );

        # Now, sorted:
        for ( sort { $b <=> $a } keys %$report ) {
            $report->{$_}->{mid} = $_; # this again.
            $report->{$_}->{date} = DADA::App::Guts::date_this( -Packed_Date => $_, );
            

           if ( $mja->check_if_entry_exists($_) ) {
                $report->{$_}->{message_subject} = $mja->get_archive_subject($_)
                  || $_;
            }
            else {
            }


            push( @$sorted_report, $report->{$_} );
        }
		#require Data::Dumper; 
		#die Data::Dumper::Dumper($sorted_report); 
        return $sorted_report;
}





sub report_by_message {
	 
	my $self      = shift; 
	my $msg_id    = shift; 
	
	my $report = {}; 
	my $l;


	
	my $num_sub_query = 'SELECT details FROM dada_mass_mailing_event_log WHERE msg_id = ? AND event = ?';
	$report->{num_subscribers} = $self->{dbh}->selectcol_arrayref($num_sub_query, {MaxRows => 1}, $msg_id, 'num_subscribers')->[0];
	
	my $misc_count_query = 'SELECT COUNT(msg_id) FROM dada_mass_mailing_event_log WHERE msg_id = ? AND event = ?';
#	# This may be different. 
	$report->{open}        = $self->{dbh}->selectcol_arrayref($misc_count_query, {}, $msg_id, 'open')       ->[0];
	$report->{soft_bounce} = $self->{dbh}->selectcol_arrayref($misc_count_query, {}, $msg_id, 'soft_bounce')->[0];
	$report->{hard_bounce} = $self->{dbh}->selectcol_arrayref($misc_count_query, {}, $msg_id, 'hard_bounce')->[0];

	my $url_clickthroughs_query = 'SELECT url, COUNT(url) AS count FROM dada_clickthrough_url_log where msg_id = ? GROUP BY url'; 
	my $sth = $self->{dbh}->prepare($url_clickthroughs_query);
	   $sth->execute($msg_id); 
	my $url_report = [];
	my $row = undef; 
	while ( $row = $sth->fetchrow_hashref ) {
    	push(@$url_report, {url => $row->{url}, count => $row->{count}});
	}
	$sth->finish; 
	undef $sth; 
	$report->{url_report} = $url_report; 
	
	
	for my $bounce_type(qw(soft_bounce hard_bounce)){
		my $bounce_query = 'SELECT timestamp, details from dada_mass_mailing_event_log where msg_id = ? and event = ? order by timestamp'; 
		my $sth = $self->{dbh}->prepare($bounce_query);
		   $sth->execute($msg_id, $bounce_type); 
		my $bounce_report = [];
		while ( $row = $sth->fetchrow_hashref ) {
	    	push(@$bounce_report, {timestamp => $row->{timestamp}, email => $row->{details}});
		}
		$report->{$bounce_type . '_report'} = $bounce_report; 
		$sth->finish; 
	}
	#require Data::Dumper; 
	#die Data::Dumper::Dumper($report); 
	
	return $report; 
}



1;
