package DADA::ProfileFieldsManager;
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
use base "DADA::ProfileFieldsManager::$type";
use strict;

use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;

use strict;

use DADA::App::Guts;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList};

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

	# Init?
	#$self->{cache}->{fields}  = $self->fields; 
	#$self->{cache}->{columns} = $self->_columns; 

}

sub clear_cache { 

	my $self = shift; 
	delete($self->{cache}->{fields}); 
	delete($self->{cache}->{columns}); 
}

1;


=pod

=head1 NAME 

DADA::ProfileFieldsManager

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 Public Methods

=head2 new

 my $pfm = DADA::ProfileFieldsManager->new

C<new> requires no parameters.

A C<DADA::ProfileFieldsManager> object will be returned. 

=head2 fields 

 my $fields = $pfm->fields; 

C<fields> returns an array ref of the names of the columns that represent the Profile Fields currently created. 

C<fields> returns the fields in the order they are usually stored in the SQL table. 

C<fields> requires no parameters. 

=head2 add_field

 $pfm->add_field(
	{
		-field          => 'myfield', 
		-fallback_value => 'a default', 
		-label          => 'My Field!', 
	}
 ); 

C<add_field()> adds a field to the profile_fields table. 

C<-field> is a required parameter and should be the name of the field you want to 
create. This field has to be a valid column name for whatever backend you're using. 
It's suggested that you stick with lowercase, less than 16 character names. 

Not passing a name for your field in the C<-field> parameter will cause the an unrecoverable error.

C<-fallback_value> is an optional parameter, it's a more free form value, used when the profile does not have a value for this profile field. This is usually used in templating

C<-label> is an optional parameter and is used in forms that capture Profile Fields information as a, "friendlier" version of the field name. 

This method will return C<undef> if there's a problem with the parameters passed. See also the, C<validate_subscriber_field_name()> method. 

=head2 save_field_attributes

 $pfm->save_field_attributes(
	{  
		-field 			=> 'myfield', 
		-fallback_value => 'a default', 
		-label          => 'My Field!',
	}
 );

Similar to C<add_field()>, C<save_field_attributes()> saves the fallback value and label for a field. It will not create a new field, 
but will error if you attempt to save a field attribute to a field that does not exist. 

=head2 edit_subscriber_field_name

   	$pfm->edit_subscriber_field(
		{
			-old_name => 'myfield' ,
			-new_name => 'mynewname',
		}
	);	
	
C<edit_subscriber_field_name()> is used to rename a subscriber field. Usually, this means that a column is renamed in table. 
Various SQL backends do this differently and this method should provide the necessary magic. 

C<-old_name> and C<-new_name> are required parameters and the method will croak if you do not 
pass both. 

This method will also croak if either the C<-old_name> does not exist, or the C<-new_name> exists. 

=head2 remove_field 

 $pfm->remove_field(
	{ 
		-field => 'myfield', 
	}
 ); 

C<remove_field> will remove the profile field passed in, C<-field>. 

C<-field> must exist, or the method will croak. 

=head2 change_field_order

 $pfm->change_field_order(
	{
		-field     => 'myfield', 
		-direction => 'down', # or, 'up' 
	}
 );

C<change_field_order> is used to change the ordering of the Profile Fields. Profile Fields
are usually in the order as they are stored in the SQL table and this method actually changes that 
order itself. 

This method is not available for the SQLite or PostgreSQL backend. 

C<-field> should hold the name of the field you'd like to move. 

C<-direction> should be either C<up> or, <down> to denote which direction you'd like the field to be 
moved. Movements are not circular - if you attempt to push a field down and the field is already the last field, it'll stay 
the last field and won't pop to the top of the stack. 

This method should return, C<1>, but if a field cannot be moved, it will return, C<0> 

This method will also croak if you pass a field that does not exist, or if you pass no field at all. 


=head1 AUTHOR

Justin Simoni http://dadamailproject.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

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



