package DADA::App::Subscriptions::ConfirmationTokens::baseSQL;
use strict; 

use lib qw(
  ../../../../
  ../../../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions}; 

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;

    $self->_init($args);
    return $self;
}

sub _init {
    my $self = shift;
    my ($args) = @_;
    $self->_sql_init();
}

sub _sql_init {

    my $self = shift;
    my ($args) = @_;

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

    if ( !keys %{ $self->{sql_params} } ) {
        croak "sql params not filled out?!";
    }
    else {
    }

    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub _backend_specific_save {
	
	warn '_backend_specific_save' 
		if $t; 
		
    my $self   = shift;
    my $token  = shift;
    my $email  = shift;
    my $frozen = shift;

    my $query =
        'INSERT INTO '
      . $self->{sql_params}->{confirmation_tokens_table}
      . '(token, email, data) VALUES(?,?,?)';

    warn 'Query: ' . $query
        if $t;


	if($t){ 
		warn "email:  $email"; 
		warn "token:  $token"; 
		warn "frozen: $frozen"; 
	}

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $token, $email, $frozen, )
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

    return 1;
}

sub fetch {
	
	warn 'fetch'
		if $t; 
		
    my $self  = shift;
    my $token = shift;

    my $query =
        'SELECT data from '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' where token = ?';

	warn 'Query:' . $query
		if $t; 
	
	
    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $token, ) or croak "cannot do statement! $DBI::errstr\n";

    my $return = $sth->fetchrow_hashref();

    my $frozen_data = $return->{data};

    $sth->finish;

    my $data = $self->_thaw($frozen_data);

    return $data;
}

sub remove_by_token {

	warn 'remove_by_token' 
		if $t; 
		
    my $self  = shift;
    my $token = shift;

    my $query =
        'DELETE FROM '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' WHERE token = ?';
	warn 'Query:' . $query
		if $t; 
    my $sth = $self->{dbh}->prepare($query);

    $sth->execute($token)
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

    return 1;

}

sub remove_by_metadata {

	warn 'remove_by_metadata'
		if $t; 
		
    my $self = shift;
    my ($args) = @_;

    my $email    = $args->{-email};
    my $metadata = $args->{-metadata};
    my $tokens   = [];
    my $row      = {};

    # hopefully, this will not be a large list returned (heh...)
    my $query =
        'SELECT * from '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' where email = ?';

	warn 'Query:' . $query
		if $t; 
	

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($email)
      or croak "cannot do statement! $DBI::errstr\n";

    while ( $row = $sth->fetchrow_hashref ) {
	
        my $frozen_data = $row->{data};
        my $data        = $self->_thaw($frozen_data);

        #		warn '$data:'    . Dumper($data);
        #		warn '$metadata' . Dumper($metadata);

        if (   
			   $data->{data}->{list}   eq $metadata->{list}
            && $data->{data}->{type}   eq $metadata->{type}
			&& $data->{data}->{flavor} eq $metadata->{flavor}
		)
        {
            push( @$tokens, $row->{token} );
        }
    }
    $sth->finish;

    foreach my $token (@$tokens) {
        $self->remove_by_token($token);
    }

    return scalar(@$tokens);
}




sub reset_timestamp_by_metadata {
		
	#warn 'reset_timestamp_by_metadata called'; 
	
    my $self = shift;
    my ($args) = @_;

    my $email    = $args->{-email};
    my $metadata = $args->{-metadata};
    my $to_save   = [];
    my $row      = {};

    # hopefully, this will not be a large list returned (heh...)
    my $query =
        'SELECT token, email, data from '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' where email = ?';

	warn 'Query:' . $query
		if $t; 
	

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($email)
      or croak "cannot do statement! $DBI::errstr\n";

    while ( $row = $sth->fetchrow_hashref ) {
	
        my $frozen_data = $row->{data};
        my $data        = $self->_thaw($frozen_data);

        if (   
			   $data->{data}->{list}   eq $metadata->{list}
            && $data->{data}->{type}   eq $metadata->{type}
			&& $data->{data}->{flavor} eq $metadata->{flavor}
		)
        {
            push( @$to_save, $row );
        }
    }
    $sth->finish;
	undef $sth; 
	
	if(scalar(@$to_save) < 1){ 
		#warn 'didnt find anything'; 
		return undef;
	}
		else { 
		#warn 'found something:'; 
	    foreach my $reup (@$to_save) {
			 my $reup_query = 'UPDATE '
							  . $self->{sql_params}->{confirmation_tokens_table} 
							  . ' SET timestamp = NOW() WHERE token = ? AND email = ?';
			if($self->{sql_params}->{dbtype} eq 'SQLite'){ 
				$reup_query =~ s/timestamp \= NOW\(\)/timestamp = CURRENT_TIMESTAMP/;
			}				
				
			#warn 'query: ' . $reup_query; 
			#warn '$reup->{token} ' . $reup->{token}; 
			#warn '$reup->{email} ' . $reup->{email}; 		
	         my $sth = $self->{dbh}->prepare($reup_query);
			
		     $sth->execute($reup->{token}, $reup->{email})
		     	or croak "cannot do statement! $DBI::errstr\n";
			# I really don't like th idea that multiple rows are returned, but we only return 1 token... 
			return $reup->{token}; 
		
	    }
		
	}
}



sub num_tokens { 

    my $self = shift;

    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{confirmation_tokens_table};

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute()
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

    $sth->finish;
	
    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
}


sub exists {
	
	warn 'exists' 
		if $t; 
		
    my $self  = shift;
    my $token = shift;

    if ( !exists( $self->{dbh} ) ) {
        return 0;
    }
    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' WHERE token = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
      if $t;

    $sth->execute($token)
      or croak "cannot do statement (at exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

    # autoviv?
    if ( $row[0] ) {
        return 1;
    }
    else {
        return 0;
    }
}


sub get_all_tokens { 
	
	my $self = shift; 
	my $query = 'SELECT timestamp, token FROM ' 
	. $self->{sql_params}->{confirmation_tokens_table} 
	. " WHERE data LIKE '%sub_confirm%' AND data NOT LIKE '%unsub_confirm%' ORDER BY id DESC LIMIT 5000";
	
    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
      if $t;

    $sth->execute()
      or croak "cannot do statement $DBI::errstr\n";

	  my $tokens = []; 
      while ( my ($timestamp, $token) = $sth->fetchrow_array ) {
          push( 
		  	@$tokens, 
			{
				token     => $token,  
				timestamp => $timestamp
			}
		);
      }
      $sth->finish;

      return $tokens;
	
}

sub remove_all_tokens { 
	my $self = shift; 
	warn 'remove_all_tokens' 
		if $t; 
		 
    my $query = 'DELETE FROM ' . $self->{sql_params}->{confirmation_tokens_table};
	warn 'QUERY:' . $query
		if $t; 
		
    $self->{dbh}->do($query);
		
}

sub _remove_expired_tokens {

	warn '_remove_expired_tokens' 
		if $t; 
		
    my $self = shift;
	
	
	# This doesn't remove tokens, it removes records out of the
	# sub_confirm_list sublist, or addresses that have been hanging around in
	#it for > $DADA::Config::CONFIRMATION_TOKEN_OPTIONS->{expires} days
	my $query; 
	
    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
		$query = 'SELECT email, list FROM ' . $self->{sql_params}->{subscriber_table} 
        . ' WHERE timestamp <= DATE_SUB(NOW(), INTERVAL ' . $DADA::Config::CONFIRMATION_TOKEN_OPTIONS->{expires} . ' DAY)'
		. " AND list_type = 'sub_confirm_list' LIMIT 5000";		

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
		$query = 'SELECT email, list FROM ' . $self->{sql_params}->{subscriber_table} 
		. " WHERE timestamp <= NOW() - INTERVAL '" . $DADA::Config::CONFIRMATION_TOKEN_OPTIONS->{expires} . " DAY'"
		. " AND list_type = 'sub_confirm_list' LIMIT 5000";		
	}
	
    warn 'QUERY: ' . $query
		if $t; 
	
	my $sth = $self->{dbh}->prepare($query);
		
	my $removal_list = {};  

	$sth->execute( )
		or croak "cannot do statement: $DBI::errstr\n";
	
	while ( my ( $email, $list) = $sth->fetchrow_array ) {
		push(@{$removal_list->{$list}}, $email );
	}
	$sth->finish;
		 		
	undef $sth; 
	undef $query; 
    
	for my $r_list(keys %$removal_list) {
        require DADA::MailingList::Subscribers;
        my $lh = DADA::MailingList::Subscribers->new( { -list => $r_list } );
        my ( $removed_email_count, $blacklisted_count ) = $lh->admin_remove_subscribers(
            {
                -addresses => $removal_list->{$r_list},
                -type      => 'sub_confirm_list',
            }
        );
	}
	# and, end that. 
	
	
	
    my $query;
    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . ' WHERE timestamp <= DATE_SUB(NOW(), INTERVAL ' . $DADA::Config::CONFIRMATION_TOKEN_OPTIONS->{expires} . ' DAY)';

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . " WHERE timestamp <= NOW() - INTERVAL '" . $DADA::Config::CONFIRMATION_TOKEN_OPTIONS->{expires} . " DAY'";
    }

	warn 'QUERY:' . $query
		if $t; 
		
    $self->{dbh}->do($query);

}

DESTROY {
    my $self = shift;
    $self->_remove_expired_tokens;
}

1;
