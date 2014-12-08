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

	if(exists( $args->{-dpfm_obj} )){ 

		$self->{manager}   = $args->{-dpfm_obj};
		$self->{-dpfm_obj} = $args->{-dpfm_obj};
	}
	else { 
		require DADA::ProfileFieldsManager; 
		$self->{manager}      = DADA::ProfileFieldsManager->new;
	}
	
	# fields() is cached when new() is called... 
	#$self->{fields_order} = $self->{manager}->fields || []; 
	
	
	if(!exists($args->{-email})){ 
		#croak "You need to pass, -email in the email thingy.";
	}
	else { 
		$self->{email} = $args->{-email};
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

C<new> requires no parameters.

A C<DADA::Profile::Fields> object will be returned. 

=head2 insert

 $df->insert(
 { 
	-email => 'user@example.com',
 }	
 ); 

C<insert> inserts a new record into the profile table. This method requires a few parameters: 

C<-email> is required and should hold a valid email address in the form of: C<user@example.com>

C<-fields> holds the Profile Fields passed as a hashref. It is an optional parameter. 

C<-mode> sets the way the new profile will be created and can either be set to, C<writeover> or, C<preserve>

When set to, C<writeover>, any existing profile belonging to the email passed in the <-email> parameter will be clobbered. 

When set to, C<preserve>, this method will first look and see if an already existing profile exists and if so, will not create a new one, but simply exit the method. 

C<writeover> is the default, if no parameter is passed. 

C<-confirmed> confirmed can also be passed with a value of either C<1> or, C<0>, with C<1> being the default if the parameter is not passed. 

Unconfirmed profiles are marked as existing, but not, "live" as a way to save the profile information, until the profile can be confirmed, by a user. 

This method should return, C<1> on success.  

=head2 get

 my $prof = $pf->get; 

C<get> returns the Profile Fields for the email address passed in, C<-email> as a hashref. 

C<-email> is a required parameter. Not passing it will cause this method to return, C<undef>. 

Passing an email that doesn't have a profile saved will also return, C<undef>. Check before by using, C<exists()>

C<-dotted> is an optional paramter, and will return the keys of the hashref appended with, C<subscriber.>

=head2 exists

	my $exists = $pf->exists(
		{
			-email => 'user@example.com', 
		}
	); 

C<exists> return either C<1>, if the profile associated with the email address passed in the C<-email> parameter has a profile

or, C<0> if there is no profile. 

=head2 remove


 $pf->remove(
	{
		-email => 'user@example.com', 
	}
 ); 

C<remove> removes the Profile Fields assocaited with the email address passed in the 
C<-email> parameter. 

C<remove> will return the number of rows removed - this should hopefully be only C<1>. Any larger number 
would be a serious problem. 

C<-email> is a required parameter. Not passing it will cause this method to return, C<undef>. 

Passing an email that doesn't have a profile saved will also return, C<undef>. Check before by using, C<exists()>




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



