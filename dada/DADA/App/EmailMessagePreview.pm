package DADA::App::EmailMessagePreview;

use lib qw(
  ../../.
  ../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

use Carp qw(carp croak);
use Try::Tiny;

use vars qw($AUTOLOAD);
use strict;
my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions};

my %allowed = ( test => 0, );

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my %args = (@_);

    $self->_init( \%args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    return if ( substr( $AUTOLOAD, -7 ) eq 'DESTROY' );

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
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


	$self->{sql_params}->{email_message_previews_table} = 'dada_email_message_previews'; 

    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub id_exists {

    warn 'id_exists'
      if $t;

    my $self = shift;
    my $id   = shift;

    if ( !defined($id) || $id eq '' ) {
        return 0;
    }
    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{dada_email_message_previews}
      . ' WHERE list = ? AND id = ?';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list}, $id )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    warn 'QUERY: ' . $query
      if $t;

    my $count = $sth->fetchrow_array;
    warn '$count:' . $count
      if $t;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }

}

sub save {

    warn 'save'
      if $t;

    my $self   = shift;
    my ($args) = @_;
	
#    require Data::Dumper; 
#    warn 'save $args:' . Data::Dumper::Dumper($args); 

	if ( !exists( $args->{-plaintext} ) ) {
	    croak "You MUST pass a, '-plaintext' parameter!";
	}  
    if ( !exists( $args->{-html} ) ) {
        croak "You MUST pass a, '-html' parameter!";
    }

   my $query; 
	$query =
	'INSERT INTO '
	. $self->{sql_params}->{email_message_previews_table}
	. ' (list, subject, plaintext, html) VALUES (?,?,?,?)';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    if($t == 1) { 
        require Data::Dumper; 
        warn 'execute params: ' . Data::Dumper::Dumper([$self->{list}, $args->{-subject},  $args->{-plaintext}, $args->{-html}]); 
    }
    $sth->execute(
		$self->{list}, 
		$args->{-subject}, 
		$args->{-plaintext}, 
		$args->{-html}, 
	)
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    $sth->finish;

    #return $sth->{mysql_insertid};
    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        return $sth->{mysql_insertid};
    }
    else {
        my $last_insert_id =
          $self->{dbh}->last_insert_id( 
		  	undef, 
			undef, 
			$self->{sql_params}->{email_message_previews_table}, 
			undef 
		);
        warn '$last_insert_id:' . $last_insert_id
          if $t;
        return $last_insert_id;
    }
}

sub fetch {

    warn 'fetch'
      if $t;

    my $self  = shift;
    my $id    = shift;

    my $query =
        'SELECT subject, plaintext, html FROM '
      . $self->{sql_params}->{email_message_previews_table}
      . ' where id = ?';

    warn 'Query:' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $id, ) or croak "cannot do statement! $DBI::errstr\n";

    my $r = $sth->fetchrow_hashref();

 
    $sth->finish;

	return $r;
}



sub _remove_expired_previews {

	warn '_remove_expired_previews' 
		if $t; 
		
    my $self = shift;
	
	my $query; 
	
    my $query;
    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{email_message_previews_table}
          . ' WHERE timestamp <= DATE_SUB(NOW(), INTERVAL ' . '60' . ' DAY)';

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{email_message_previews_table}
          . " WHERE timestamp <= NOW() - INTERVAL '" . '60' . " DAY'";
    }

	warn 'QUERY:' . $query
		if $t; 
		
    $self->{dbh}->do($query);

}

DESTROY {
    my $self = shift;
    $self->_remove_expired_previews;
}


1;
