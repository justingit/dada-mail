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



1;
