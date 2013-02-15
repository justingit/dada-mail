package DADA::App::Subscriptions::ConfirmationTokens::baseSQL;
use strict; 

use lib qw(
  ../../../../
  ../../../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = 1; #$DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions}; 

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
		warn "email: $email"; 
		warn "token: $token"; 
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

        #		use Data::Dumper;

        my $frozen_data = $row->{data};
        my $data        = $self->_thaw($frozen_data);

        #		warn '$data:'    . Dumper($data);
        #		warn '$metadata' . Dumper($metadata);

        if (   $data->{data}->{flavor} eq $metadata->{flavor}
            && $data->{data}->{type} eq $metadata->{type} )
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

sub _remove_expired_tokens {

	warn '_remove_expired_tokens' 
		if $t; 
		
    my $self = shift;
    my $query;

    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . ' WHERE timestamp <= DATE_SUB(NOW(), INTERVAL 1 DAY)';

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . " WHERE timestamp <= NOW() - INTERVAL '1 DAY'";

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
