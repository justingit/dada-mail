package DADA::Profile::Fields;
use strict;

use lib qw(
	./
	./DADA/perllib
	../../ 
	../../DADA 
	../../perllib
);

use Carp qw(carp croak confess);
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

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile_Fields};

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';
               $DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';


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
    require DADA::App::DBIHandle;
    $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;

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
		$self->{email} = cased(
			$args->{ -email }
		);
	}
}




sub insert {

    my $self = shift;
    my ($args) = @_;
	if(!exists($self->{email})){ 
 	   if ( !exists $args->{ -email } ) {
	        croak("You MUST supply an email address in the -email parameter!");
	    }
	    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
	        croak("You MUST supply an email address in the -email parameter!");
	    }
	}
	else { 
		$args->{ -email } = $self->{email}; 
	}
	
    if ( !exists $args->{ -fields } ) {
        $args->{ -fields } = {};
    }
    if ( !exists( $args->{ -confirmed } ) ) {
        $args->{ -confirmed } = 1;
    }

	# writeover
	# preserve,
	
	if( !exists($args->{ -mode } ) ) { 
		$args->{ -mode } = 'writeover';
	}
	
    # See, how I'm doing this, after the confirmed thing? Good idea?
    if ( $args->{ -confirmed } == 0 ) {
        $args->{ -email } = '*' . $args->{ -email };
    }

	my $fields_exists = $self->exists( 
		{
			-email => $args->{ -email } 
		} 
	);
	
	if($fields_exists && $args->{-mode} eq 'preserve'){ 
			# this is kinda weird, but: 
			$self->{email} = $args->{ -email };
			return 1; 
	}		
		
	if($fields_exists && $args->{-mode} eq 'preserve_if_defined'){ 
		$self->{email} = $args->{ -email };
		unless($self->are_empty) { 
			return 1; 
		}
		else { 
			# Well, do what's below, 
		}
	}
	
	if ($fields_exists) {
				
		my $tmp_pf = undef; 
		if(exists($self->{-dpfm_obj})){ 
			$tmp_pf = DADA::Profile::Fields->new(
				{
					-email    => $args->{-email},
					-dpfm_obj => $self->{-dpfm_obj}, 
				}
			); 
        }
		else { 
			$tmp_pf = DADA::Profile::Fields->new(
				{
					-email => $args->{-email}
					
				}
			); 
		}

		$tmp_pf->remove;
		undef $tmp_pf; 
 	}

    my $sql_str             = '';
    my $place_holder_string = '';

    my @order               = @{ $self->{manager}->fields };
    my @values;

    if ( $order[0] ) {
        for my $field (@order) {
            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            if(exists($args->{ -fields }->{$field})){ 
                push ( @values, $args->{ -fields }->{$field} );
            }
            else { 
                push ( @values, '' );               
            }
        }
    }
    $sql_str =~ s/,$//;
    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . '(email'
      . $sql_str . ') 
        VALUES (?' . $place_holder_string . ')';

    warn 'Query: ' . $query
 		if $t;

    my $sth = $self->{dbh}->prepare($query);
	
    $sth->execute( $args->{ -email }, @values )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

	# this is kinda weird, but: 
	$self->{email} = $args->{ -email };

	
	return 1; 
 	
}

sub get {

    my $self = shift;
    my ($args) = @_;

	if(!$self->{email}){ 
		croak "Cannot use this method without passing the '-email' param in, new (get)"; 
	}

    my $sub_fields = $self->{manager}->fields;
	
	if(!$args->{ -dotted }){ 
		$args->{ -dotted } = 0; 
	}
	if(!exists($args->{-dotted_with})){ 
		$args->{-dotted_with} = 'subscriber'; 
	} 
	
	
	#if(!exists($args->{-email})){ 
	#	return undef; 
	#}
	#if(! $self->exists({-email => $args->{-email}})) {  
	#	return undef; 
	#}
	
    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_fields_table}
      . " WHERE email = ?";

    #warn 'QUERY: ' . $query . ', $args->{-email}: ' . $args->{ -email }
	#	if $t;

    warn 'QUERY: ' . $query . ', $self->{email}: ' . $self->{ email }
		if $t;



    my $sth = $self->{dbh}->prepare($query);

   # $sth->execute( $args->{ -email } )
	$sth->execute( $self->{ email } )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $hashref   = {};
    my $n_hashref = {};

    my ( $n, $d ) = split ( '@', $self->{ email }, 2 );
    $n_hashref->{email_name}   = $n;
    $n_hashref->{email_domain} = $d;
    $n_hashref->{email}        = $self->{email};
    
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        for ( @{$sub_fields} ) {
            $n_hashref->{$_} = $hashref->{$_};
        }
		last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        for ( keys %$n_hashref ) {
            $dotted->{$args->{-dotted_with} . '.' . $_ } = $n_hashref->{$_};
        }

		# require Data::Dumper; 
		# carp Data::Dumper::Dumper($dotted); 
        return $dotted;
    }
    else {
		# require Data::Dumper; 
		# carp Data::Dumper::Dumper($n_hashref);
        return $n_hashref;

    }

    carp "Didn't fetch the profile?!";
    return undef;

}


sub are_empty { 
	my $self = shift; 
	my $empty = 1; 
	my $f = $self->get; 

	delete($f->{email_name});
	delete($f->{email_domain});
	delete($f->{email});
	
	if(!keys %{$f}){ 
		return 1; 
	}

	for my $k(keys %{$f}){ 
		if(defined($f->{$k}) && length($f->{$k}) > 0){ 
			return 0; 
		}
		else { 
			# ... 
		}
	}	
	return 1; 
}

sub exists {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT COUNT(*) from '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . ' WHERE email = ? ';

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{ -email } )
      or croak "cannot do statement (at exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

    return $row[0];
}

sub remove {
	
    my $self = shift;
    my ($args) = @_;

	#if(!exists($args->{-email})){ 
	#	return undef; 
	#}
	#if(! $self->exists({-email => $args->{-email}})) {  
	#	return undef; 
	#}
	
	if(!$self->{email}){ 
		croak "Cannot use this variable without passing the '-email' param in, new (remove) (1)"; 
	}
	
    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_fields_table}
      . ' WHERE email = ? ';

    #warn 'QUERY: ' . $query . ' (' . $args->{ -email } . ')'
	warn 'QUERY: ' . $query . ' (' . $self->{ email } . ')'
		if $t;

    my $sth = $self->{dbh}->prepare($query);

    #my $rv = $sth->execute( $args->{ -email } )
	my $rv = $sth->execute( $self->{ email } )
      or croak "cannot do statement (at remove)! $DBI::errstr\n";
    $sth->finish;
    return $rv;

}



sub can_have_subscriber_fields {

    my $self = shift;
    return 1;
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

Justin Simoni https://dadamailproject.com

=head1 LICENSE AND COPYRIGHT

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



