package DADA::App::Session;

use strict;
use lib qw(../../ ../../DADA/perllib);

use DADA::Config qw(!:DEFAULT);
use DADA::Security::Password;
use DADA::MailingList::Settings;
use DADA::App::Guts;
use Carp qw(carp croak);
use Try::Tiny;
my $dbi_obj;

my $t; 

sub new {
    my $class = shift;
    my %args  = (
        -List => undef,
        @_
    );
    my $self = {};
    bless $self, $class;
    $self->_init( \%args );
    return $self;
}

sub _init {

    my $self = shift;

    require DADA::App::DBIHandle;
    $self->{dbh} = DADA::App::DBIHandle->new->dbh_obj;

    # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session.pm

    if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {

# http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/postgresql.pm
        $self->{dsn}      = 'driver:PostgreSQL';
        $self->{dsn_args} = {

            Handle     => $self->{dbh},
            TableName  => $DADA::Config::SQL_PARAMS{session_table},
            ColumnType => "binary"
        };
    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {

# http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/mysql.pm
        $self->{dsn}      = 'driver:mysql';
        $self->{dsn_args} = {

            Handle    => $self->{dbh},
            TableName => $DADA::Config::SQL_PARAMS{session_table},

        };
    }
    elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {

        # http://search.cpan.org/~bmoyles/CGI-Session-SQLite/SQLite.pm
        $self->{dsn} = 'driver:SQLite:'
          ;    # . ':' . $DADA::Config::FILES . '/' . $database;;
        $self->{dsn_args} = {
            Handle    => $self->{dbh},
            TableName => $DADA::Config::SQL_PARAMS{session_table},
        };
    }
}

sub login_cookies {

    my $self = shift;

    my %args = (
        -cgi_obj  => undef,
        -list     => undef,
        -password => undef,
        @_
    );

    die 'no CGI Object (-cgi_obj)' if !$args{-cgi_obj};

    my $cookies = [];

    my $q = $args{-cgi_obj};

    my $list = $args{-list};

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    my $cipher_pass = DADA::Security::Password::cipher_encrypt( $li->{cipher_key}, $args{-password} );

    require CGI::Session;
    CGI::Session->name($DADA::Config::LOGIN_COOKIE_NAME);

    my $session = CGI::Session->new( $self->{dsn}, $q, $self->{dsn_args} )
      or carp $!;

    $session->param( 'Admin_List',     $args{-list} );
    $session->param( 'Admin_Password', $cipher_pass );
    $session->param( 'ip_address',     $ENV{REMOTE_ADDR} );
	
    $session->expire( $DADA::Config::COOKIE_PARAMS{-expires} );
    $session->expire( 'Admin_Password', $DADA::Config::COOKIE_PARAMS{-expires} );
    $session->expire( 'Admin_List',     $DADA::Config::COOKIE_PARAMS{-expires} );
    $session->expire( 'ip_address',     $DADA::Config::COOKIE_PARAMS{-expires} );

    $cookies->[0] = $q->cookie(
        -name  => $DADA::Config::LOGIN_COOKIE_NAME,
        -value => $session->id,
        %DADA::Config::COOKIE_PARAMS
    );

    $session->flush();

    if ( $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} == 1 ) {
        try {
            my $kcfinder_cookie = $self->kcfinder_session_begin;
            if ( defined($kcfinder_cookie) ) {
                $cookies->[1] = $kcfinder_cookie;
            }
        }
        catch {
            carp "initializing KCFinder session return an error: $_";
        }
    }


    return $cookies;
}

sub kcfinder_session_begin {

    my $self = shift;
    require PHP::Session;
    require CGI::Lite;
    my $new_sess = 0;

    my $cgi     = new CGI::Lite;
    my $cookies = $cgi->parse_cookies;
    my $sess_id = '';
    if (
        $cookies->{ $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_name} } )
    {
        $sess_id =
          $cookies->{ $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_name} };
    }
    else {
        $new_sess = 1;
    }

    if ( $new_sess == 1 ) {
        require DADA::Security::Password;
        $sess_id = DADA::Security::Password::generate_rand_string(
            'abcdefghijklmnopqrstuvwxyz123456789', 32 );

    }

    # This makes the session directory, just in case!
    my $dada_sess_dir = make_safer( $DADA::Config::TMP . '/php_sessions' );
    if ( $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_dir} eq
        $dada_sess_dir )
    {
        if ( !-d $dada_sess_dir ) {
            mkdir( $dada_sess_dir, $DADA::Config::DIR_CHMOD );
        }
    }

    my $session = PHP::Session->new(
        $sess_id,
        {
            create => 1,
            save_path =>
              $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_dir},
        }
    );
    my $KCFINDER = {
        disabled =>
          ( !$DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} ),
        uploadDir =>
          $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{upload_dir},
        uploadURL =>
          $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{upload_url},
    };

    $session->set( KCFINDER => $KCFINDER );
    $session->save;
	chmod(
		$DADA::Config::FILE_CHMOD, 
		make_safer($DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_dir} . '/sess_' . $sess_id)
	);


    if ( $new_sess == 1 ) {
        require CGI;
        my $cookie = CGI::cookie(
            -name =>
              $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_name},
            -value => $sess_id,
            %DADA::Config::COOKIE_PARAMS,
        );
        return $cookie;
    }
    else {
        return undef;
    }

}

sub kcfinder_session_end {
    my $self = shift;
    my $self = shift;
    require PHP::Session;
    require CGI::Lite;

    my $cgi     = new CGI::Lite;
    my $cookies = $cgi->parse_cookies;
    my $sess_id = '';
    if (
        $cookies->{ $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}
              ->{session_name} } )
    {
        $sess_id =
          $cookies->{ $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}
              ->{session_name} };
    }
    else {
        carp "no PHP session?";
    }

    my $session = PHP::Session->new(
        $sess_id,
        {
            create => 1,
            save_path =>
              $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{session_dir},
        }
    );
    $session->unregister('KCFINDER');
    $session->save;
    return 1;
}

sub change_login {

    my $self = shift;

    my %args = (
        -cgi_obj => undef,
        -list    => undef,
        @_
    );

    die "no list!" if !$args{-list};

    my $q = $args{-cgi_obj};
    my $cookie;

    require CGI::Session;

    CGI::Session->name($DADA::Config::LOGIN_COOKIE_NAME);
    my $old_session = CGI::Session->new( $self->{dsn}, $q, $self->{dsn_args} )
      or carp $!;

    my $old_password = $old_session->param('Admin_Password');

    my $old_list = $old_session->param('Admin_List');

    my $old_ls = DADA::MailingList::Settings->new( { -list => $old_list } );
    my $old_li = $old_ls->get;

    my $ue_old_password =
      DADA::Security::Password::cipher_decrypt( $old_li->{cipher_key},
        $old_password );

    my $ls = DADA::MailingList::Settings->new( { -list => $args{-list} } );
    my $li = $ls->get;

    my $cipher_pass =
      DADA::Security::Password::cipher_encrypt( $li->{cipher_key},
        $ue_old_password );

    $old_session->param( 'Admin_List',     $args{-list} );
    $old_session->param( 'Admin_Password', $cipher_pass );

    $old_session->flush();

    $cookie = $q->cookie(
        -name  => $DADA::Config::LOGIN_COOKIE_NAME,
        -value => $old_session->id,
        %DADA::Config::COOKIE_PARAMS
    );
    return $cookie;
}

sub logged_into_diff_list {

    my $self = shift;

    my %args = ( -cgi_obj => undef, @_ );

    die 'no CGI Object (-cgi_obj)' if !$args{-cgi_obj};
    my $q = $args{-cgi_obj};

    my $session;

    require CGI::Session;

    CGI::Session->name($DADA::Config::LOGIN_COOKIE_NAME);
    $session = CGI::Session->new( $self->{dsn}, $q, $self->{dsn_args} )
      or carp $!;

    $args{-Admin_List}     = $session->param('Admin_List');
    $args{-Admin_Password} = $session->param('Admin_Password');


    if (   defined( $args{-Admin_List} )
        && $args{-Admin_List} ne ""
        && ( $args{-Admin_List} ne $q->param('admin_list') ) )
    {
        return 1;
    }
    else {

# This means, there isn't a session there before, so let's remove the one we just made.

        $session->delete();
        $session->flush;

        return 0;

    }

}

sub logout_cookie {

    my $self = shift;

    my %args = (
        -cgi_obj => undef,
        @_,
    );

    die 'no CGI Object (-cgi_obj)' if !$args{-cgi_obj};
    my $q = $args{-cgi_obj};

    my $cookie;

    require CGI::Session;

    CGI::Session->name($DADA::Config::LOGIN_COOKIE_NAME);
    my $session = CGI::Session->new( $self->{dsn}, $q, $self->{dsn_args} )
      or carp $!;

    $session->delete();

    $cookie = $q->cookie(
        -name  => $DADA::Config::LOGIN_COOKIE_NAME,
        -value => undef,
        -path  => '/'
    );

    $session->flush();

    try {
        if ( $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} == 1 ) {
            $self->kcfinder_session_end;
        }
    }
    catch {
        carp "ending kcfinder session return an error: $_";
    }
    return $cookie;

}



sub check_session_list_security {

    warn 'at check_session_list_security'
        if $t; 
    
    my $self = shift;

    my %args = (
        -Function        => undef,
        -cgi_obj         => undef,
        @_
    );

    die 'no CGI Object (-cgi_obj)' if !$args{-cgi_obj};
    my $q = $args{-cgi_obj};

    my $session = undef;
 
    require CGI::Session;

    CGI::Session->name($DADA::Config::LOGIN_COOKIE_NAME);

    $session = CGI::Session->load( $self->{dsn}, $q, $self->{dsn_args} )
      or carp $!;

	  my $sess_args = {
	  	Admin_List     => $session->param('Admin_List'),
	  	Admin_Password => $session->param('Admin_Password'),
	  	ip_address     => $session->param('ip_address'),
	  };

    my ( $problems, $flags, $root_logged_in ) = $self->check_admin_cgi_security(
        -Admin_List     => $sess_args->{'Admin_List'},
        -Admin_Password => $sess_args->{'Admin_Password'},
		-ip_address     => $sess_args->{'ip_address'},
        -Function       => $args{-Function},
    );
    if ($problems) {

		if(scalar keys %$flags == 1 && $flags->{"no_admin_permissions"} == 1){ 
			#... 
		}
		else {
			 try {
	            $session->delete();
	            $session->flush();
	        } catch { 
	            warn "Problems deleting and flushing session cookie: $_";
	        };
		}
        
        
        my $body = $self->enforce_admin_cgi_security(
            -Admin_List     => $sess_args->{'Admin_List'},
            -Admin_Password => $sess_args->{'Admin_Password'},
            -Flags          => $flags,
			-cgi_obj        => $q, 
        );
        return ( undef, 0, 0, $body );
    }
    else {
	    $session->flush();
	    undef $session;
		return ( $sess_args->{'Admin_List'},, $root_logged_in, 1, undef );
    }
}

sub check_admin_cgi_security {

    my $self = shift;

    my %args = (
        -Admin_List     => undef,
        -Admin_Password => undef,
        -ip_address     => undef,
        -Function       => undef,
        @_
    );

    my $root_logged_in = 0;

    require DADA::Security::Password;
    require DADA::MailingList::Settings;

    my $problems = 0;
    my %flags    = ();

    unless ( defined( $args{-Admin_List} )
        && defined( $args{-Admin_Password} ) )
    {
        $problems++;
        $flags{"need_to_login"} = 1;
        return ( $problems, \%flags, 0 );

    }

    if ( $DADA::Config::REFERER_CHECK == 1 ) {
        if ( check_referer( CGI::referer() ) != 1 ) {
            $problems++;
            $flags{"need_to_login"} = 1;
            return ( $problems, \%flags, 0 );
        }
    }

    if (@DADA::Config::ALLOWED_IP_ADDRESSES) {
        my $ip_check = 0;
        for (@DADA::Config::ALLOWED_IP_ADDRESSES) {
            if ( $_ eq $ENV{REMOTE_ADDR} ) {
                $ip_check = 1;
                last;
            }
        }

        #error! no ip!
        if ( $ip_check == 0 ) {
            $problems++;
            $flags{"bad_ip"} = 1;
        }
    }
	
	if($DADA::Config::CP_SESSION_PARAMS->{check_matching_ip_addresses} == 1) {
		if($ENV{REMOTE_ADDR} ne $args{-ip_address}){ 
			
			warn '$ENV{REMOTE_ADDR:'  . $ENV{REMOTE_ADDR}; 
			warn '$args{-ip_address}' . $args{-ip_address}; 

	        $problems++;
	        $flags{"mismatching_ip_address"} = 1;

		}
	}
	

    my $list = $args{-Admin_List};
    my ($list_exists) = check_if_list_exists( -List => $list );

    # error! no such list
    if ( $list_exists <= 0 ) {
        $problems++;
        $flags{no_list} = 1;
    }
    else {

        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $list_info = $ls->get;

        # I do not like this anymore.
        unless ( $list_info->{cipher_key} ) {
            $ls->save();    #this won't work anyways...
            $list_info = $ls->get;
        }

        my $cipher_pass =
          DADA::Security::Password::cipher_decrypt( $list_info->{cipher_key},
            $args{-Admin_Password} );
        my $password_check =
          DADA::Security::Password::check_password( $list_info->{password},
            $cipher_pass );

# If $password_check is 1, the list password worked - let's not try for the root password, mmmkay?

     # meaning, the password check FAILED for the list,
     # But this may just mean, the pass in question is the root password
     # If it succeeds, we don't check, since the list pass may be set
     # as the same as the root pass, and unknowingly to the list password-haver,
     # they've just logged in with extra privileges.
     # and that's BAD.

        if ( $password_check == 0 ) {

            # if root logging in is set, let em login with the root password
            if ( $DADA::Config::ALLOW_ROOT_LOGIN == 1 ) {
                if ( defined($DADA::Config::PROGRAM_ROOT_PASSWORD) ) {
                    my $cipher_dada_root_password =
                      DADA::Security::Password::cipher_decrypt(
                        $list_info->{cipher_key},
                        $args{-Admin_Password} );
                    if ( $DADA::Config::ROOT_PASS_IS_ENCRYPTED == 1 ) {
                        my $root_password_check =
                          DADA::Security::Password::check_password(
                            $DADA::Config::PROGRAM_ROOT_PASSWORD,
                            $cipher_dada_root_password );
                        if ( $root_password_check == 1 ) {
                            $password_check++;
                            $root_logged_in = 1;
                        }
                    }
                    else {
                        my $cipher_dada_admin_password =
                          DADA::Security::Password::cipher_decrypt(
                            $list_info->{cipher_key},
                            $args{-Admin_Password} );
                        if ( $DADA::Config::PROGRAM_ROOT_PASSWORD eq
                            $cipher_dada_admin_password )
                        {
                            $password_check++;
                            $root_logged_in = 1;
                        }
                    }
                }
            }
        }

        if ( $password_check < 1 ) {
            $problems++;
            $flags{"invalid_password"} = 1;
        }

		my @func = split(' ', $args{-Function});
	
	    require DADA::Template::Widgets::Admin_Menu;
	
		my $status = 1; 
		ALLFUNC: for(@func) {
	        if ( $root_logged_in != 1 &&  $_ ne undef) {
	            $status =
	              DADA::Template::Widgets::Admin_Menu::check_function_permissions(
	                -List_Ref => $list_info,
	                -Function => $_, 
	              );
				  if ($status == 1) { 
					  last ALLFUNC;
				  }
	        }
	    }	
		
      if ( $status < 1 ) {
          $problems++;
          $flags{no_admin_permissions} = 1;
      }
	  																					
    }

    return ( $problems, \%flags, $root_logged_in );

}

sub enforce_admin_cgi_security {

    my $self = shift;

    my %args = (
        -Admin_List     => undef,
        -Admin_Password => undef,
        -Flags          => {},
		-cgi_obj        => undef, 
        @_
    );
    my $flags = $args{-Flags};
    require DADA::App::Error;

    my @error_precedence = qw(need_to_login mismatching_ip_address bad_ip no_list invalid_password no_admin_permissions);
    for (@error_precedence) {
        if ( $flags->{$_} == 1 ) {
			
			my $add_vars = {}; 
			if($_  =~ m/need_to_login|mismatching_ip_address|bad_ip|invalid_password/){ 
				
				# I could probably just pass the flags, here, eh? 
				# Then, just show the various different error messages 
				# based on the flags. 
				# rather than a specific screen for each eerror message
				# which would really cut down on how many error screens I have!
				
				$add_vars->{selected_list}   = $args{-Admin_List};
				
				if($_ eq 'invalid_password'){ 
			        my $can_use_captcha = 0;
			        my $CAPTCHA_string  = '';
			        my $cap; 
		            	
			        if ( can_use_AuthenCAPTCHA() == 1 ) {
			            require DADA::Security::AuthenCAPTCHA;
			            $cap    = DADA::Security::AuthenCAPTCHA->new;
			            $CAPTCHA_string = $cap->get_html( $DADA::Config::RECAPTCHA_PARAMS->{public_key} );
			            $add_vars->{captcha_string}  = $CAPTCHA_string;
			            $add_vars->{can_use_captcha} = 1;
			        }
				}
				require DADA::Template::Widgets; 
				my $error_msg = DADA::Template::Widgets::admin(
					{ 
						-cgi_obj => $args{-cgi_obj},
						-vars    => {
							errors => [{error => $_}],
							%$add_vars, 
						}
					}
				); 
				return $error_msg; 
			}
            elsif ( $_ eq 'no_admin_permissions' ) {
                my $error_msg = DADA::App::Error::cgi_user_error(
                    {
                        -list      => $args{-Admin_List},
                        -error     => $_,
                        -wrap_with => 'admin',
                    }
                );
                return $error_msg;
            }
            else {
                my $error_msg = DADA::App::Error::cgi_user_error(
                    {
                        -list  => $args{-Admin_List},
                        -error => $_
                    }
                );
                return $error_msg;
            }
        }
    }
}

sub remove_old_session_files {

	my $self = shift;
	# I'm going to wrap this in an eval(), since it's hell to get off of CPAN,
	# for whatever reason. (?!?!)

	try { 
		require CGI::Session::ExpireSessions;
	} catch { 
		warn 'cannot use, CGI::Session::ExpireSessions';
		return;
	};

	my $expirer = CGI::Session::ExpireSessions->new( delta => (86400 * 7));  
	$expirer->expire_sessions(
		cgi_session_dsn => $self->{dsn},
		dsn_args        => $self->{dsn_args}
	);

    

}

sub DESTROY { }

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2016 Justin Simoni All rights reserved. 

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

