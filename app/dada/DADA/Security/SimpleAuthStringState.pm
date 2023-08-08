package DADA::Security::SimpleAuthStringState;

use strict;

my $t       = 0;
my $dbi_obj = undef;

use lib qw(../../ ../../DADA ../perllib ./ ../ ../perllib ../../ ../../perllib);

use AnyDBM_File;
use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB);

use Carp qw(carp croak);

sub new {

    my $class = shift;
    my %args  = (@_);

    my $self = {};
    bless $self, $class;

    $self->_init;
    return $self;

}

sub _init {

    my $self = shift;
    $self->_can_use_md5;

    require DADA::App::DBIHandle;
    $dbi_obj            = DADA::App::DBIHandle->new;
    $self->{dbh}        = $dbi_obj->dbh_obj;
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

}

sub make_state {

    my $self     = shift;
    my $auth_str = $self->_create_auth_string;

    # We can also just dbl-check the auth_string doesn't exist.
    my $query =
        'INSERT INTO '
      . $self->{sql_params}->{simple_auth_str_table}
      . '(auth_str) VALUES (?)';

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $auth_str)
      or die "cannot do statement $DBI::errstr\n";
    $sth->finish;

	warn '$auth_str: ' . $auth_str 
		if $t; 
	
    return $auth_str;

}

sub remove_state {

    my $self  = shift;
    my $state = shift;

    my $query =
        'DELETE FROM '
      . $self->{sql_params}->{simple_auth_str_table}
      . ' WHERE auth_str = ?';

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($state)
      or die "cannot do statement $DBI::errstr\n";
    $sth->finish;

    # we could dbl check that something was removed...

    return 1;

}

sub check_state {
    my $self  = shift;
    my $state = shift;
    my $auth  = 0;
    if ( $self->has_auth_state($state) >= 1 ) {
        $auth = 1;
        $self->remove_state($state);
    }
    else {
        $auth = 0;
    }
}

sub has_auth_state {

    my $self        = shift;
    my $auth_string = shift;

    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{simple_auth_str_table}
      . ' WHERE auth_str = ?';

    warn 'QUERY: ' . $query
      if $t;

	  warn '$auth_string: ' . $auth_string 
	  	if $t; 
	  
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($auth_string)
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

	warn '$count: ' . $count 
		if $t; 
	
    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }

}

sub _can_use_md5 {

    my $self = shift;

    my $can_use_md5 = 0;

    eval { require Digest::MD5 };    # hey, just in case, right?
    if ( !$@ ) {
        $self->{can_use_md5} = 1;
    }
}

sub _create_auth_string {

    my $self = shift;
    require DADA::Security::Password;
    my $str = DADA::Security::Password::generate_rand_string( undef, 64 );

    if ( $self->{_can_use_md5} ) {

        require Digest::MD5;    # Reminder: Ship with Digest::Perl::MD5....

        require Encode;
        my $cs = Digest::MD5::md5_hex( safely_encode($$str) );
        return $cs;
    }
    else {
        # Guess we're faking it...
        return $str;
    }

}



sub _remove_expired_auths {

	warn '_remove_expired_auths' 
		if $t; 
		
    my $self = shift;
	
	
    my $query;
    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{simple_auth_str_table}
          . ' WHERE timestamp <= DATE_SUB(NOW(), INTERVAL 7 DAY)';

    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
        $query =
            'DELETE FROM '
          . $self->{sql_params}->{confirmation_tokens_table}
          . " WHERE timestamp <= NOW() - INTERVAL '7 DAY'";
    }

	warn 'QUERY:' . $query
		if $t; 
		
    $self->{dbh}->do($query);

}




DESTROY {
    my $self = shift;
    $self->_remove_expired_auths;
}

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2023 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 
