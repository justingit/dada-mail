package DADA::Profile::Fields;
use lib qw(../../ ../../DADA ../../perllib);
use Carp qw(carp croak);
my $type;
use DADA::Config qw(!:DEFAULT);

BEGIN {
    $type = $DADA::Config::SUBSCRIBER_DB_TYPE;
    if ( $type =~ m/sql/i ) {
        if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {
            $type = 'SQLite';
        }
        else {
            $type = 'baseSQL';
        }
    }
}
use base "DADA::Profile::Fields::$type";
use strict;

use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;

use strict;

use DADA::App::Guts;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};

use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB
);

my %fields;

my $dbi_obj;

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

    $self->{'log'} = new DADA::Logging::Usage;

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    if ( $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ ) {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $self->{dbh} = $dbi_obj->dbh_obj;
    }

}

1;


=pod

=head1 NAME 

DADA::Profile::Fields

=head1 SYNOPSIS


=head1 DESCRIPTION




=head1 Public Methods

=head2 new

 my $pf = DADA::Profile::Fields->new

C<new> requires no paramaters.

A C<DADA::Profile::Fields> object will be returned. 

=head2 fields 

 my $fields = $pf->fields; 

C<fields> returns an array ref of the names of the columns that represent the profile fields currently created. 

C<fields> returns the fields in the order they are usually stored in the SQL table. 

C<fields> requires no paramaters. 

=head2 insert

 $df->insert(
 { 
	-email => 'user@example.com',
 }	
 ); 

C<insert> inserts a new record into the profile table. This method requires a few paramaters: 

C<-email> is required and should hold a valid email address in the form of: C<user@example.com>

C<-fields> holds the profile fields passed as a hashref. It is an optional paramater. 

C<-mode> sets the way the new profile will be created and can either be set to, C<writeover> or, C<preserve>

When set to, C<writeover>, any existing profile belonging to the email passed in the <-email> paramater will be clobbered. 

When set to, C<preserve>, this method will first look and see if an already existing profile exists and if so, will not create a new one, but simply exit the method. 

C<writeover> is the default, if no paramater is passed. 

C<-confirmed> confirmed can also be passed with a value of either C<1> or, C<0>, with C<1> being the default if the paramater is not passed. 

Unconfirmed profiles are marked as existing, but not, "live" as a way to save the profile information, until the profile can be confirmed, by a user. 

This method should return, C<1> on success.  

=head2 add_subscriber

 $lh->add_subscriber(
	{
		-email  => 'user@example.com', 
		-type   => 'list',
		-fields => {
					# ...
				   },
	}
);

C<add_subscriber> adds a subscriber to a sublist. 

C<-email> is required and should hold a valid email address in form of: C<user@example.com>

C<-type> holds the sublist you want to subscribe the address to, if no sublist is passed, B<list> is used as a default.

C<-fields> holds the subscription fields you'd like associated with the subscription, passed as a hashref. 

For example, if you have two fields, B<first_name> and, B<last_name>, you would pass the subscriber fields like this: 

 $lh->add_subscriber(
	{
		-email  => 'user@example.com', 
		-type   => 'list',
		-fields => {
					first_name => "John", 
					last_name  => "Doe", 
				   },
	}
 );

Passing field values is optional.

Fields that are not actual fields that are being passed will be ignored. 

=head3 Diagnostics

=over

=item * You must pass an email in the -email paramater!

You forgot to pass an email in the, -email paramater, ie: 

 # DON'T do this:
 $lh->add_subscriber();

=item * cannot do statement (at add_subscriber)!

Something went wrong in the SQL side of things.

=back



=head1 AUTHOR

Justin Simoni http://dadamailproject.com

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999-2009 Justin Simoni All rights reserved. 

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



