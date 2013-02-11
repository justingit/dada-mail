package DADA::App::Subscriptions::ConfirmationTokens::baseSQL;
use lib qw(
  ../../../../
  ../../../../perllib
);

use Carp qw(croak carp);

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

sub save {

    my $self = shift;
    my $args = shift;

    if ( !exists( $args->{-list} ) ) {
        croak "no -list!";
    }
    if ( !exists( $args->{-email} ) ) {
        croak "no -email!";
    }
    if ( !exists( $args->{-data} ) ) {
        croak "no -data!";
    }

    my $data = {
        list  => $args->{-list},
        email => $args->{-email},
        data  => $args->{-data},
    };

    my $frozen = $self->_freeze($data);
    my $token  = $self->token;

    my $query =
      'INSERT INTO dada_confirmation_tokens(token, data) VALUES (?,?)';

    #  warn 'Query: ' . $query
    #      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $token, $frozen, )
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

    return $token;

}

sub fetch {
    my $self  = shift;
    my $token = shift;

    my $query = 'SELECT data from dada_confirmation_tokens where token = ?';

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

    my $query = "DELETE FROM dada_confirmation_tokens 
				 WHERE token = ?";

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $token )
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

    return 1;

}

sub exists {
    my $self  = shift;
    my $token = shift;

    if ( !exists( $self->{dbh} ) ) {
        return 0;
    }
    my $query =
      'SELECT COUNT(*) FROM ' . 'dada_confirmation_tokens' . ' WHERE token = ?';

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

sub _freeze {
    my $self = shift;
    my $data = shift;

    require Data::Dumper;
    my $d = new Data::Dumper( [$data], ["D"] );
    $d->Indent(0);
    $d->Purity(1);
    $d->Useqq(0);
    $d->Deepcopy(0);
    $d->Quotekeys(1);
    $d->Terse(0);

    # ;$D added to make certain we get our data structure back when we thaw
    return $d->Dump() . ';$D';

}

sub _thaw {

    my $self = shift;
    my $data = shift;

    # To make -T happy
    my ($safe_string) = $data =~ m/^(.*)$/s;
    my $rv = eval($safe_string);
    if ($@) {
        croak "couldn't thaw data!";
    }
    return $rv;
}

sub _remove_expired_tokens {
	
    my $self = shift;
    my $query;

    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        $query = 'DELETE FROM '
          . 'dada_confirmation_tokens'
          . ' WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 1 DAY)';

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
        $query =
            'DELETE FROM '
          . 'dada_confirmation_tokens'
          . ' WHERE timestamp >= NOW() - INTERVAL "1 DAY"';
    }

	$self->{dbh}->do($query); 

}

DESTROY {
    my $self = shift;
    $self->_remove_expired_tokens;
}

1;
