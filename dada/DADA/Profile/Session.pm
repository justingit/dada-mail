package DADA::Profile::Session;

use lib qw (../../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);
use DADA::Config;
use CGI::Session;
CGI::Session->name('dada_profile');



my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};

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

    if ( $DADA::Config::SESSION_DB_TYPE =~ /SQL/ ) {
    	require DADA::App::DBIHandle;
       	my  $dbi_obj = DADA::App::DBIHandle->new;
  		$self->{dbh} = $dbi_obj->dbh_obj; 
    }

    # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session.pm

    if ( $DADA::Config::SESSION_DB_TYPE =~ m/SQL/i ) {

        if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {

# http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/postgresql.pm
            $self->{dsn}      = 'driver:PostgreSQL';
            $self->{dsn_args} = {

                Handle    => $self->{dbh},
                TableName => $DADA::Config::SQL_PARAMS{session_table},

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
            $self->{dsn} =
              'driver:SQLite:'
              ;    # . ':' . $DADA::Config::FILES . '/' . $database;;
            $self->{dsn_args} = {

                Handle => $self->{dbh},

            };

            $CGI::Session::SQLite::TABLE_NAME = 'dada_sessions';
        }
    }
    elsif ( $DADA::Config::SESSION_DB_TYPE eq 'Db' ) {

# http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/db_file.pm
        $self->{dsn}      = 'driver:db_file';
        $self->{dsn_args} = {

            FileName => $DADA::Config::TMP . '/dada_sessions',

        };

    }
    elsif ( $DADA::Config::SESSION_DB_TYPE eq 'PlainText' ) {

   # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/file.pm

        $self->{dsn}      = undef;
        $self->{dsn_args} = { Directory => $DADA::Config::TMP };

    }
    else {
        croak "Wrong Login Type!";
    }

}



sub login_cookie {

    my $self   = shift;
	my ($args) = shift; 

    die 'no CGI Object (-cgi_obj)' if !$args->{ -cgi_obj };

    my $cookie;

    my $q = $args->{ -cgi_obj };


    require CGI::Session;

    my $session = new CGI::Session( 
		$self->{dsn}, 
		$q, 
		$self->{dsn_args}
	 );

    $session->param( 
		'email',     
		$args->{ -email } 
	);
    $session->param(
		'_logged_in', 
		1 
	);

    $session->expire( 
		$DADA::Config::COOKIE_PARAMS{ -expires } 
	);
    $session->expire( 
		'_logged_in',
        $DADA::Config::COOKIE_PARAMS{ -expires } );

    $cookie = $q->cookie(
        -name  => 'dada_profile',
        -value => $session->id,
       # %DADA::Config::COOKIE_PARAMS
    );

    # My proposal to address the situation is quit relying on flush() happen
    # automatically, and recommend that people use an explicit flush()
    # instead, which works reliably for everyone.
    $session->flush();

    return $cookie;
}

sub login          {

	my $self   = shift; 
	my ($args) = @_;
	my ($status, $errors) = $self->validate_profile_login($args);
	if($status == 0){ 
		die "login failed."; 
	}
	else { 
		my $cookie = $self->login_cookie($args); 
	#	require Data::Dumper; 
	#	die Data::Dumper::Dumper($cookie);
		return $cookie;
	}
}

sub logout         {
	
    my $self   = shift; 
	my ($args) = @_; 
	my $q = $args->{-cgi_obj};
	
	if($self->is_logged_in($args)){ 
		my $s = new CGI::Session( 
			$self->{dsn}, 
			$q, 
			$self->{dsn_args}
		 );
		$s->delete; 
		$s->flush; 
		return 1; 
	}
	else { 
		warn 'profile was never logged in!'; 
		return 0; 
	}
	

}

sub validate_profile_login { 
	my $self   = shift; 
	my ($args) = @_;
	my $status = 1;  
	my $errors = { 
		unknown_user   => 0, 
		incorrect_pass => 0, 
	};
	
	require DADA::Profile; 
	my $prof = DADA::Profile->new({-email => $args->{-email}});
	if($prof->exists()){ 
		# ...
	}
	else { 
		$status = 0; 
		$errors->{unknown_user} = 1;		
	}
	
	if($prof->is_valid_password($args)){
		# ...
	}
	else { 
		$status = 0; 
		$errors->{incorrect_pass} = 1;		
	}
	
	return ($status, $errors);
	
}


sub is_logged_in { 
	
	my $self   = shift; 
	my ($args) = @_; 
	my $q; 
	if(exists($args->{-cgi_obj})){ 
		$q = $args->{-cgi_obj};
	}
	else { 
		require CGI; 
		$q = new CGI; 
	}
	my $s = CGI::Session->load(
		$self->{dsn}, 
		$q, 
		$self->{dsn_args}
	)
	or die CGI::Session->errstr();
		
    if ( $s->is_expired ) {
    	return 0; 
	}

    if ( $s->is_empty ) {
       	return 0; 
    }

	if($s->param('_logged_in') == 1){ 
		return 1; 
	}
	else { 
		return 0; 
	}

}

sub get { 
	
	my $self   = shift; 
	my ($args) = @_; 
	my $q;
	if(exists($args->{-cgi_obj})){ 
		$q = $args->{-cgi_obj};
	}
	else { 
		require CGI; 
		$q = new CGI; 
	}
	require CGI::Session;

    my $session = new CGI::Session( 
		$self->{dsn}, 
		$q, 
		$self->{dsn_args}
	 );
	return $session->param('email'); 
	
}



sub reset_password {}