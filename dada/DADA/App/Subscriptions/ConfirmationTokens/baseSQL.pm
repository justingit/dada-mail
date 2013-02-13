package DADA::App::Subscriptions::ConfirmationTokens::baseSQL;
use lib qw(
  ../../../../
  ../../../../perllib
);

use Carp qw(croak carp);

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

    if ( !$dbi_obj ) {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $self->{dbh} = $dbi_obj->dbh_obj;
    }
    else {
        $self->{dbh} = $dbi_obj->dbh_obj;
    }
}

sub _backend_specific_save {
    my $self   = shift;
    my $token  = shift;
    my $email  = shift;
    my $frozen = shift;

    my $query =
        'INSERT INTO '
      . $self->{sql_params}->{confirmation_tokens_table}
      . '(token, email, data) VALUES (?,?,?)';

    #  warn 'Query: ' . $query
    #      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $token, $email, $frozen, )
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

    return 1;
}

sub fetch {
    my $self  = shift;
    my $token = shift;

    my $query =
        'SELECT data from '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' where token = ?';

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $token, ) or croak "cannot do statement! $DBI::errstr\n";

    my $return = $sth->fetchrow_hashref();

    my $frozen_data = $return->{data};

    $sth->finish;

    my $data = $self->_thaw($frozen_data);

    return $data;
}

sub remove_by_token {

    my $self  = shift;
    my $token = shift;

    my $query =
        'DELETE FROM '
      . $self->{sql_params}->{confirmation_tokens_table}
      . ' WHERE token = ?';

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute($token)
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

    return 1;

}

sub remove_by_metadata {

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

    my $self = shift;
    my $query;

    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . ' WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 1 DAY)';

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . ' WHERE timestamp >= NOW() - INTERVAL "1 DAY"';
    }

    $self->{dbh}->do($query);

}

DESTROY {
    my $self = shift;
    $self->_remove_expired_tokens;
}

1;
