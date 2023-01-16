package DADA::Profile::Settings; 
use strict;
use lib qw(./ ../ ../../ ../../DADA ../perllib); 

use Carp qw(carp croak);
 
use Try::Tiny;

use DADA::Config;
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile};

my $type; 
my $backend; 

sub _init {

    my $self = shift;
    my ($args) = @_;
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    my $dbi_obj = undef;
    require DADA::App::DBIHandle;
    $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
	
	require DADA::MailingList::Settings; 
	$self->{ls_obj} = DADA::MailingList::Settings->new(
		{
			-list => $args->{-list}
		}
	); 
	
	$self->{list} = $args->{-list};
	
}


sub new {

    my $class = shift;
    my ($args) = @_;


#    if ( !exists( $args->{ -list } )) {
#        croak("You must supply a list name in the '-list' parameter.");
#    }

    my $self = {};
    bless $self, $class;
    $self->_init($args);
    return $self;
}


sub enabled { 
	my $self = shift; 
	return 1; 
}

sub save {
    my $self = shift;
    my ($args) = @_;
    for ( '-email', '-setting', '-value' ) {
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

    $sth->execute( 
		$self->{list}, 
		$args->{-email}, 
		$args->{-setting}, 
		$args->{-value}
	) or croak "cannot do statement! $DBI::errstr\n";

    $sth->finish;

    return 1;

}

sub fetch {
    my $self = shift;
    my ($args) = @_;
    for ( '-email') {
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
        $self->{list},
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

    for ( '-email', '-setting' ) {
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
        $self->{list},
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

    for ( '-email', '-setting' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "you MUST pass the, '" . $_ . "' parameter!";
        }
    }

    my $query =
      'DELETE FROM ' . $self->{sql_params}->{profile_settings_table} . ' WHERE list = ? AND email = ? and setting = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( 
		$self->{list}, 
		$args->{-email}, 
		$args->{-setting}
	) or croak "cannot do statement! $DBI::errstr\n";
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
        $self->{list},
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



sub enabled { 
	my $self = shift; 
	return 1; 
}

sub save {
    my $self = shift;
    my ($args) = @_;
    for ( '-email', '-setting', '-value' ) {
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

    $sth->execute( 
		$self->{list}, 
		$args->{-email}, 
		$args->{-setting}, 
		$args->{-value}
	) or croak "cannot do statement! $DBI::errstr\n";

    $sth->finish;

    return 1;

}

sub fetch {
    my $self = shift;
    my ($args) = @_;
    for ( '-email') {
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
        $self->{list},
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

    for ( '-email', '-setting' ) {
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
        $self->{list},
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

    for ( '-email', '-setting' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "you MUST pass the, '" . $_ . "' parameter!";
        }
    }

    my $query =
      'DELETE FROM ' . $self->{sql_params}->{profile_settings_table} . ' WHERE list = ? AND email = ? and setting = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( 
		$self->{list}, 
		$args->{-email}, 
		$args->{-setting}
	) or croak "cannot do statement! $DBI::errstr\n";
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
        $self->{list},
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

sub DESTROY {}

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



1;
