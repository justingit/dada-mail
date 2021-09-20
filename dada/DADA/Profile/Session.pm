package DADA::Profile::Session;

use lib qw (../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);
use DADA::Config;
use DADA::App::Guts; 
use CGI::Session;
CGI::Session->name('dada_profile');
use Carp qw(carp croak); 

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile_Session};

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
    $self->{list} = $args->{ -list };
	my $dbh     = undef; 
	my $dbi_obj = undef; 
		
    require DADA::App::DBIHandle;
       $dbi_obj = DADA::App::DBIHandle->new;
       $dbh     = $dbi_obj->dbh_obj; 
	
    # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session.pm


        if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {

# http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/postgresql.pm
            $self->{dsn}      = 'driver:PostgreSQL';
            $self->{dsn_args} = {

                Handle    => $dbh,
                TableName => $DADA::Config::SQL_PARAMS{session_table},

            };

        }
        elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {

  # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/mysql.pm
            $self->{dsn}      = 'driver:mysql';
            $self->{dsn_args} = {

                Handle    => $dbh,
                TableName => $DADA::Config::SQL_PARAMS{session_table},

            };

        }
        elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {

            # http://search.cpan.org/~bmoyles/CGI-Session-SQLite/SQLite.pm
            $self->{dsn} =
              'driver:SQLite:'
              ;    # . ':' . $DADA::Config::FILES . '/' . $database;;
            $self->{dsn_args} = {

                Handle => $dbh,
				TableName => $DADA::Config::SQL_PARAMS{session_table},

            };

        }
}

sub _login_cookie {

    my $self = shift;
    my ($args) = @_;

	require CGI; 
    my $q = new CGI; 

    my $cookie;

    require CGI::Session;

	use DADA::Security::Password; 

	my $token = DADA::Security::Password::generate_rand_string(undef, 41); 

    my $session = new CGI::Session( $self->{dsn}, $q, $self->{dsn_args} );

       $session->param( 'email',      cased($args->{ -email }) );
       $session->param( '_logged_in', 1 );
       $session->param( 'token',      $token);
	

	    $session->expire( $DADA::Config::COOKIE_PARAMS{ -expires } );
	    $session->expire( '_logged_in', $DADA::Config::COOKIE_PARAMS{ -expires } );
	    $session->expire( 'token', $DADA::Config::COOKIE_PARAMS{ -expires } );

    $cookie = $q->cookie( 
		%{$DADA::Config::PROFILE_OPTIONS->{cookie_params}},
		-value => $session->id, 
		($DADA::Config::PROGRAM_URL =~ m/^https/) ? (
			-secure  => 1,
		) : ()
		
		);
    $session->flush();

    return $cookie;
}

sub login {


    my $self = shift;
    my ($args) = @_;

	require CGI; 
	my $q = new CGI; 

	my ($status, $errors);
	
	if($args->{-skip_validation} == 0){ 
	    ( $status, $errors ) = $self->validate_profile_login($args);
	}
	else { 
		$status = 1; 
		$errors = {};
	}
	
    if ( $status == 0 ) {
        croak "login failed.";
    }
    else {
        my $cookie = $self->_login_cookie($args);
        return $cookie;
    }
}

sub logout {

    my $self = shift;
    my ($args) = @_;

	require CGI; 
	my $q = new CGI; 

    if ( $self->is_logged_in($args) ) {
        my $s = new CGI::Session( $self->{dsn}, $q, $self->{dsn_args} );
        $s->delete;
        $s->flush;
        return 1;
    }
    else {
        carp 'profile was never logged in!';
        return 0;
    }
}

sub logout_cookie { 

	my $self = shift; 
	
	require CGI; 
	my $q = new CGI;
	
	my $cookie = $q->cookie(
				-name    =>  $DADA::Config::PROFILE_OPTIONS->{cookie_params}->{-name},
				-value   =>  '',
				-path    =>  '/',
	);
	return $cookie;
}


sub validate_profile_login {
    my $self = shift;
    my ($args) = @_;
	
	$args->{ -email } = cased($args->{ -email });
	
    my $status = 1;
    my $errors = {
        unknown_user   => 0,
        incorrect_pass => 0,
    };


    require DADA::Security::SimpleAuthStringState;
    my $sast       = DADA::Security::SimpleAuthStringState->new;
    my $auth_state = $args->{-auth_state};

    if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
        if ( $sast->check_state($auth_state) != 1 ) {
	        $status = 0;
	        $errors->{invalid_form} = 1;
        }

    }


    require DADA::Profile;
    my $prof = DADA::Profile->new(
		{ 
			-email => $args->{ -email } 
		} 
	);
    
    
	if ( $prof->exists == 1 ) {
        # ...
    }
    else {
        $status = 0;
        $errors->{unknown_user} = 1;
    }
	
	if($args->{-no_pass} == 1){ 
		# ... 
	}
	else { 
 	   if ( $prof->is_valid_password($args) ) {

	        # ...
	    }
	    else {
	        $status = 0;
	        $errors->{incorrect_pass} = 1;
	
	    }
	}

    return ( $status, $errors );

}

sub check_csrf { 
	my $self = shift; 
	my $q    = shift; 
	
    my $s = CGI::Session->load( $self->{dsn}, $q, $self->{dsn_args} )
      or croak 'failed to load session: ' . CGI::Session->errstr();
	
      if ( $s->is_expired ) {
          return 0;
      }

      if ( $s->is_empty ) {
          return 0;
      }
	
	  if($q->param('csrf_token') eq $s->param('token') ){ 
		  return 1; 
	  }
	  else { 
		  return 0; 
	  }
	

}
sub is_logged_in {

    my $self = shift;
    my ($args) = @_;
    my $q;
    if ( exists( $args->{ -cgi_obj } ) ) {
        $q = $args->{ -cgi_obj };
    }
    else {
        require CGI;
        $q = new CGI;

    }
	
	
    my $s = CGI::Session->load( $self->{dsn}, $q, $self->{dsn_args} )
      or croak 'failed to load session: ' . CGI::Session->errstr();

    if ( $s->is_expired ) {
        return 0;
    }

    if ( $s->is_empty ) {
        return 0;
    }

    if ( $s->param('_logged_in') == 1 ) {
	
		# Something's wrong with this, but I don't know yet, yet: 
		# 
		#require DADA::Profile;
	    #my $prof = DADA::Profile->new( { -email => $self->get }  );
		#
	    #if ( $prof->exists == 1 ) {
	    #   return 1;
	    #}
	    #else {
	    #     return 0;
	    #}
		return 1; 
    }
    else {
        return 0;
    }

}

sub get {

    my $self = shift;
    my ($args) = @_;
    my $q;
    require CGI;
    $q = new CGI;
    require CGI::Session;

    my $session = new CGI::Session( $self->{dsn}, $q, $self->{dsn_args} );
    return {
		email => $session->param('email'), 
		token => $session->param('token'),
	}; 

}

sub reset_password {} # ??? 

1;


=pod

=head1 NAME 

DADA::Profile::Session

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 Public Methods

=head2 new

	my $prof_sess = DADA::Profile::Session->new

C<new> returns a DADA::Profile::Session object. 

C<new> does not take any parameters and returns a C<DADA::Profile::Session> object. 

=head2 login

	my $cookie = $prof_sess->login(
		{ 
			-email    => scalar $q->param('email'),
			-password => scalar $q->param('password'), 
		},
	);

C<login> saves the session information for the profile, as well as returns a cookie, so that the state can be fetched later. 

It requires two arguments: 

C<-email> should hold the email address associated with the profile that you'd like to login. 

C<-password> should hold the correct password associated with the user. 

This method will croak if the login information (user/password) is incorrect. Use C<validate_profile_login()> before trying to login. 

=head2 logout

 $prof_sess->logout;

C<logout> removes the session state information. It'll return C<1> on success and C<0> on failure. Usually, a failure will happen 
if the profile is not actually logged in. 

=head2 validate_profile_login

	my ($status, $errors) = $prof_sess->validate_profile_login(
		{ 
			-email    => scalar $q->param('email'),
			-password => scalar $q->param('password'), 
		
		},
	);

C<validate_profile_login> is used to make sure the login information you give is valid. 

It requires two parameters: 

C<-email> should be the email address associated with the profile. 

C<-password> should be the profile associated with the profile. 

It'll return a two-element array. The first is the status and will be set to either, 
C<1> or C<0>, with C<1> meaning that no problems were encountered. If the status is set 
to, C<0>, then problems were encountered. Any problems will be described in the second element of the 
array. This should be a hashref of key/value pairs. The keys will describe the error and the value would 
be set to, C<1> if the error was found. 

Here's the following keys that may be returned: 

=over

=item * unknown_user

The email address passed in, C<-email> doesn't have a profile. 

=item * incorrect_pass

The password passed in, C<-password> isn't correct for the email address passed in, C<-email> 

=back

=head2 is_logged_in

 my $logged_in = $prof_sess->is_logged_in; 

C<is_logged_in> returns C<1> if a profile is logged in, or C<0> if it is not. 

C<is_logged_in> does not need any arguments. 

=head2 get 

 my $email = $prof_sess->get; 

C<get> returns the email address associated with the profile that is logged in. 

Most likely, if the profile is not logged in, C<undef> will be returned. 

=head1 AUTHOR

Justin Simoni https://dadamailproject.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1999 - 2020 Justin Simoni All rights reserved. 

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


