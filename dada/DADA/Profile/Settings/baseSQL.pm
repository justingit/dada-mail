package DADA::Profile::Settings::baseSQL;

use lib qw (
  ../../../
  ../../../DADA/perllib
);

use Carp qw(carp croak);
use Try::Tiny;

use DADA::Config;
use DADA::App::Guts;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();
use strict;
use vars qw(@EXPORT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile};


sub _init {

    my $self = shift;
    my ($args) = @_;
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    my $dbi_obj = undef;
    require DADA::App::DBIHandle;
    $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub enabled { 
	my $self = shift; 
	return 1; 
}
sub save {
    my $self = shift;
    my ($args) = @_;
    for ( '-email', '-list', '-setting', '-value' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "you MUST pass the, '" . $_ . "' parameter!";
        }
    }
    if ( $self->setting_exists($args) ) {
        $self->remove($args);
    }

    my $query =
      'INSERT INTO ' . $self->{sql_params}->{profile_settings_table} . '(list, email, setting, value) VALUES(?,?,?,?)';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-list}, $args->{-email}, $args->{-setting}, $args->{-value}, )
      or croak "cannot do statement! $DBI::errstr\n";

    $sth->finish;

    return 1;

}

sub fetch {
    my $self = shift;
    my ($args) = @_;
    for ( '-email', '-list' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "you MUST pass the, '" . $_ . "' parameter!";
        }
    }
    
    my $query =
        'SELECT setting, value from '
      . $self->{sql_params}->{profile_settings_table}
      . ' where list = ? AND email = ?';

	warn 'Query:' . $query
		if $t; 

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute(
        $args->{-list}, 
        $args->{-email}
    ) or croak "cannot do statement! $DBI::errstr\n";

    my $row; 
    my $r = {};
    while ( $row = $sth->fetchrow_hashref ) {
	    $r->{$row->{setting}} = $row->{value}; 
    }
    
    $sth->finish;

    return $r;
        
}

sub setting_exists {

    warn 'setting_exists'
      if $t;

    my $self = shift;
    my ($args) = @_;

    for ( '-email', '-list', '-setting' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "you MUST pass the, '" . $_ . "' parameter!";
        }
    }

    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{profile_settings_table}
      . ' WHERE list = ? AND email = ? AND setting = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
      if $t;

    $sth->execute( 
        $args->{-list}, 
        $args->{-email}, 
        $args->{-setting}
        )
      or croak "cannot do statement: $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;
    if ( scalar(@row) == 0 ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub remove {

    my $self = shift;
    my ($args) = @_;

    for ( '-email', '-list', '-setting' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "you MUST pass the, '" . $_ . "' parameter!";
        }
    }

    my $query =
      'DELETE FROM ' . $self->{sql_params}->{profile_settings_table} . ' WHERE list = ? AND email = ? and setting = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $args->{-list}, $args->{-email}, $args->{-setting}, )
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

}



sub update { 
    my $self = shift;

    my ($args) = @_;

    my $query  =
        "UPDATE "
      . $self->{sql_params}->{profile_settings_table}
      . " SET email = ? WHERE email = ?";
    my $sth = $self->{dbh}->prepare($query);
    
    $sth->execute( 
        $args->{-to}, 
        $args->{-from}, 
    ) or croak "cannot do statement $DBI::errstr\n";
    $sth->finish;
    
    return 1; 
    
}



sub count { 
    
    my $self = shift; 
    my ($args) = @_;

    my $query  =
        "SELECT COUNT(*) FROM "
      . $self->{sql_params}->{profile_settings_table}
      . " WHERE list = ? AND  setting = ? AND value = ? ";
    my $sth = $self->{dbh}->prepare($query);
    
    $sth->execute( 
        $args->{-list},
        $args->{-setting}, 
        $args->{-value}, 
    ) or croak "cannot do statement $DBI::errstr\n";
    my $count = $sth->fetchrow_array;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
    
}


1;
