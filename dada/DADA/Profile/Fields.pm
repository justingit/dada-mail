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

=head2 get

 my $prof = $pf->get(
	{
		-email => 'user@example.com', 
 	}
 ); 

C<get> returns the profile fields for the email address passed in, C<-email> as a hashref. 

C<-email> is a required paramater. Not passing it will cause this method to return, C<undef>. 

Passing an email that doesn't have a profile saved will also return, C<undef>. Check before by using, C<exists()>

C<-dotted> is an optional paramter, and will return the keys of the hashref appended with, C<subscriber.>

=head2 exists

	my $exists = $pf->exists(
		{
			-email => 'user@example.com', 
		}
	); 

C<exists> return either C<1>, if the profile associated with the email address passed in the C<-email> paramater has a profile

or, C<0> if there is no profile. 

=head2 remove


 $pf->remove(
	{
		-email => 'user@example.com', 
	}
 ); 

C<remove> removes the profile fields assocaited with the email address passed in the 
C<-email> paramater. 

C<remove> will return the number of rows removed - this should hopefully be only C<1>. Any larger number 
would be a serious problem. 

C<-email> is a required paramater. Not passing it will cause this method to return, C<undef>. 

Passing an email that doesn't have a profile saved will also return, C<undef>. Check before by using, C<exists()>

=head2 add_field

 $pf->add_field(
	{
		-field          => 'myfield', 
		-fallback_value => 'a default', 
		-label          => 'My Field!', 
	}
 ); 

C<add_field()> adds a field to the profile_fields table. 

C<-field> is a required paramater and should be the name of the field you want to 
create. This field has to be a valid column name for whatever backend you're using. 
It's suggested that you stick with lowercase, less than 16 character names. 

Not passing a name for your field in the C<-field> paramater will cause the an unrecoverable error.

C<-fallback_value> is an optional paramater, it's a more free form value, used when the profile does not have a value for this profile field. This is usually used in templating

C<-label> is an optional paramater and is used in forms that capture profile fields information as a, "friendlier" version of the field name. 

This method will return C<undef> if there's a problem with the paramaters passed. See also the, C<validate_subscriber_field_name()> method. 

=head2 save_field_attributes

 $pf->save_field_attributes(
	{  
		-field 			=> 'myfield', 
		-fallback_value => 'a default', 
		-label          => 'My Field!',
	}
 );

Similar to C<add_field()>, C<save_field_attributes()> saves the fallback value and label for a field. It will not create a new field, 
but will error if you attempt to save a field attribute to a field that does not exist. 

=head2 edit_subscriber_field

   	$pf->edit_subscriber_field(
		{
			-old_name => 'myfield' ,
			-new_name => 'mynewname',
		}
	);	
	
C<edit_subscriber_field()> is used to rename a subscriber field. Usually, this means that a column is renamed in table. 
Various SQL backends do this differently and this method should provide the necessary magic. 

C<-old_name> and C<-new_name> are required paramaters and the method will croak if you do not 
pass both. 

This method will also croak if either the C<-old_name> does not exist, or the C<-new_name> exists. 

=head2 remove_field 

 $pf->remove_field(
	{ 
		-field => 'myfield', 
	}
 ); 

C<remove_field> will remove the profile field passed in, C<-field>. 

C<-field> must exist, or the method will croak. 

=head2 change_field_order

 $pf->change_field_order(
	{
		-field     => 'myfield', 
		-direction => 'down', # or, 'up' 
	}
 );

C<change_field_order> is used to change the ordering of the profile fields. Profile fields
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



