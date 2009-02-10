package DADA::Profile::Session;

use lib qw (../../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);
use DADA::Config;
use CGI::Session;


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
        if ( !$dbi_obj ) {
            require DADA::App::DBIHandle;
            $dbi_obj = DADA::App::DBIHandle->new;
            $self->{dbh} = $dbi_obj->dbh_obj;
        }
        else {
            $self->{dbh} = $dbi_obj->dbh_obj;
        }
    }

    # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session.pm

    if ( $DADA::Config::SESSION_DB_TYPE =~ m/SQL/i ) {

        if ( $DADA::Config::SESSION_DB_TYPE eq 'PostgreSQL' ) {

# http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/postgresql.pm
            $self->{dsn}      = 'driver:PostgreSQL';
            $self->{dsn_args} = {

                Handle    => $self->{dbh},
                TableName => $DADA::Config::SQL_PARAMS{session_table},

            };

        }
        elsif ( $DADA::Config::SESSION_DB_TYPE eq 'MySQL' ) {

  # http://search.cpan.org/~markstos/CGI-Session/lib/CGI/Session/Driver/mysql.pm
            $self->{dsn}      = 'driver:mysql';
            $self->{dsn_args} = {

                Handle    => $self->{dbh},
                TableName => $DADA::Config::SQL_PARAMS{session_table},

            };

        }
        elsif ( $DADA::Config::SESSION_DB_TYPE eq 'SQLite' ) {

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

=cut

sub login_cookie {

    my $self = shift;

    my %args = (
        -cgi_obj  => undef,
        -list     => undef,
        -password => undef,
        @_
    );

    die 'no CGI Object (-cgi_obj)' if !$args{ -cgi_obj };

    my $cookie;

    my $q = $args{ -cgi_obj };

    my $list = $args{ -list };

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    my $cipher_pass =
      DADA::Security::Password::cipher_encrypt( $li->{cipher_key},
        $args{ -password } );

    if (   $self->{can_use_cgi_session} == 1
        && $self->{can_use_data_dumper} == 1 )
    {

        require CGI::Session;
        CGI::Session->name($DADA::Config::LOGIN_COOKIE_NAME);

        my $session = new CGI::Session( $self->{dsn}, $q, $self->{dsn_args} );

        $session->param( 'Admin_List',     $args{ -list } );
        $session->param( 'Admin_Password', $cipher_pass );

        $session->expire( $DADA::Config::COOKIE_PARAMS{ -expires } );
        $session->expire( 'Admin_Password',
            $DADA::Config::COOKIE_PARAMS{ -expires } );
        $session->expire( 'Admin_List',
            $DADA::Config::COOKIE_PARAMS{ -expires } );

        $cookie = $q->cookie(
            -name  => $DADA::Config::LOGIN_COOKIE_NAME,
            -value => $session->id,
            %DADA::Config::COOKIE_PARAMS
        );

        # My proposal to address the situation is quit relying on flush() happen
        # automatically, and recommend that people use an explicit flush()
        # instead, which works reliably for everyone.
        $session->flush();

    }
    else {

        $cookie = $q->cookie(
            -name  => $DADA::Config::LOGIN_COOKIE_NAME,
            -value => {
                admin_list     => $args{ -list },
                admin_password => $cipher_pass
            },
            %DADA::Config::COOKIE_PARAMS
        );
    }

    return $cookie;
}
=cut

sub login          {}
sub logout         {}
sub validate       {}
sub reset_password {}