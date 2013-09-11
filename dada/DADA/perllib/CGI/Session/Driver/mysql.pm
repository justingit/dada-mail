package CGI::Session::Driver::mysql;

# $Id$

use strict;
use Carp;
use CGI::Session::Driver::DBI;

@CGI::Session::Driver::mysql::ISA       = qw( CGI::Session::Driver::DBI );
$CGI::Session::Driver::mysql::VERSION   = '4.43';

sub _mk_dsnstr {
    my ($class, $dsn) = @_;
    unless ( $class && $dsn && ref($dsn) && (ref($dsn) eq 'HASH')) {
        croak "_mk_dsnstr(): usage error";
    }

    my $dsnstr = $dsn->{DataSource};
    if ( $dsn->{Socket} ) {
        $dsnstr .= sprintf(";mysql_socket=%s", $dsn->{Socket});
    }
    if ( $dsn->{Host} ) {
        $dsnstr .= sprintf(";host=%s", $dsn->{Host});
    }
    if ( $dsn->{Port} ) {
        $dsnstr .= sprintf(";port=%s", $dsn->{Port});
    }
    return $dsnstr;
}


sub init {
    my $self = shift;
    if ( $self->{DataSource} && ($self->{DataSource} !~ /^dbi:mysql/i) ) {
        $self->{DataSource} = "dbi:mysql:database=" . $self->{DataSource};
    }

    if ( $self->{Socket} && $self->{DataSource} ) {
        $self->{DataSource} .= ';mysql_socket=' . $self->{Socket};
    }
    return $self->SUPER::init();
}

sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my $dbh = $self->{Handle};
    $dbh->do("INSERT INTO " . $self->table_name .
			 " ($self->{IdColName}, $self->{DataColName}) VALUES(?, ?) ON DUPLICATE KEY UPDATE $self->{DataColName} = ?",
			 undef, $sid, $datastr, $datastr)
        or return $self->set_error( "store(): \$dbh->do failed " . $dbh->errstr );
    return 1;
}


sub table_name {
    my $self = shift;

    return  $self->SUPER::table_name(@_);
}

1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::mysql - CGI::Session driver for MySQL database

=head1 SYNOPSIS

    $s = CGI::Session->new( 'driver:mysql', $sid);
    $s = CGI::Session->new( 'driver:mysql', $sid, { DataSource  => 'dbi:mysql:test',
                                                   User        => 'sherzodr',
                                                   Password    => 'hello' });
    $s = CGI::Session->new( 'driver:mysql', $sid, { Handle => $dbh } );

=head1 DESCRIPTION

B<mysql> stores session records in a MySQL table. For details see L<CGI::Session::Driver::DBI|CGI::Session::Driver::DBI>, its parent class.

It's especially important for the MySQL driver that the session ID column be
defined as a primary key, or at least "unique", like this:

 CREATE TABLE sessions (
     id CHAR(32) NOT NULL PRIMARY KEY,
     a_session TEXT NOT NULL
  );

To use different column names, change the 'create table' statement, and then simply do this:

    $s = CGI::Session->new('driver:mysql', undef,
    {
        TableName=>'session',
        IdColName=>'my_id',
        DataColName=>'my_data',
        DataSource=>'dbi:mysql:project',
    });

or

    $s = CGI::Session->new('driver:mysql', undef,
    {
        TableName=>'session',
        IdColName=>'my_id',
        DataColName=>'my_data',
        Handle=>$dbh,
    });

=head2 DRIVER ARGUMENTS

B<mysql> driver supports all the arguments documented in L<CGI::Session::Driver::DBI|CGI::Session::Driver::DBI>. In addition, I<DataSource> argument can optionally leave leading "dbi:mysql:" string out:

    $s = CGI::Session->new( 'driver:mysql', $sid, {DataSource=>'shopping_cart'});
    # is the same as:
    $s = CGI::Session->new( 'driver:mysql', $sid, {DataSource=>'dbi:mysql:shopping_cart'});

=head2 BACKWARDS COMPATIBILITY

As of V 4.30, the global variable $CGI::Session::MySQL::TABLE_NAME cannot be used to set the session
table's name.

This is due to changes in CGI::Session::Driver's new() method, which now allows the table's name to be
changed (as well as allowing both the 'id' column name and the 'a_session' column name to be changed).

See the documentation for CGI::Session::Driver::DBI for details.

In particular, the new syntax for C<new()> applies to all database drivers, whereas the old - and bad -
global variable method only applied to MySQL.

Alternately, call $session -> table_name('new_name') just after creating the session object if you wish to
change the session table's name.

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>.

=cut
