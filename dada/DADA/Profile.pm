package DADA::Profile;

use lib qw (
  ../
  ../perllib
);

use Carp qw(carp croak);
use DADA::Config;
use DADA::App::Guts;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();
use strict;
use vars qw(@EXPORT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile};

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);

    # This means we want to pull the email we want to use from
    # the saved session, but there is no valid session saved, so
    # this isn't going to work.
    if ( 
		 $args->{ -from_session } == 1 && 
		 !defined( $args->{ -email } ) ) {
        return undef;
    }
    if (   $DADA::Config::PROFILE_ENABLED != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return undef;
    }

    # Else...
    return $self;

}

sub _init {

    my $self = shift;

    my ($args) = @_;
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

    if ( exists( $args->{ -from_session } ) ) {
        if ( $args->{ -from_session } == 1 ) {
            require DADA::Profile::Session;
            my $sess = DADA::Profile::Session->new;
            if ( $sess->is_logged_in ) {
                $args->{ -email } = $sess->get;
            }
            else {
                $args->{ -email } = undef;
                return;
            }
        }
    }
    else {
        $args->{ -from_session } = 0;
    }

    if ( !exists( $args->{ -email } ) ) {
        croak "you must pass an email address in, '-email'";
    }
    else {
        $self->{email} = $args->{ -email };
    }

	if(exists($self->{email})){ 
		require DADA::Profile::Fields; 
		$self->{fields} = DADA::Profile::Fields->new({-email => $self->{email}});
	}
	
	
    my $dbi_obj = undef;

    require DADA::App::DBIHandle;
    $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;

}

sub insert {

    my $self = shift;
    my ($args) = @_;

    require DADA::Security::Password;

    #    if ( !exists $self->{ email } ) {
    #        croak("You MUST supply an email address in the -email paramater!");
    #    }
    #    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
    #        croak("You MUST supply an email address in the -email paramater!");
    #    }

    my $enc_password = undef;
    if ( !exists( $args->{ -password } ) ) {
        $args->{ -password } = '';
    }
    else {
        $enc_password =
          DADA::Security::Password::encrypt_passwd( $args->{ -password } );
    }

    if ( !exists $args->{ -activated } ) {
        $args->{ -activated } = 0;
    }

    # ?
    #	if($self->exists({-email => $args->{-email}}) >= 1){
    #		$self->remove({-email => $args->{-email}});
    #	 }

    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . '(email, password, auth_code, activated) VALUES (?, ?, ?, ?)';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute(
        $self->{email}, 
		$enc_password,
        $args->{ -auth_code },
        $args->{ -activated },
      )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

    return 1;

}

sub get {

    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_table}
      . " WHERE email = ?";

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{email} )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $profile_info = {};
    my $hashref      = {};

    #warn $sth->dump_results(undef, undef, undef, *STDERR);

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {

        #warn '$hashref->{$_} ' . $hashref->{$_} ;
        $profile_info = $hashref;

        last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        foreach ( keys %$profile_info ) {
            $dotted->{ 'profile.' . $_ } = $profile_info->{$_};
        }
        return $dotted;
    }
    else {
        return $profile_info;

    }

    carp "Didn't fetch the profile?!";
    return undef;

}

sub subscribed_to_list {
    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{ -list } ) ) {
        return 0;
    }

    my $subscriptions = $self->subscribed_to;
    foreach (@$subscriptions) {
        if ( $_ eq $args->{ -list } ) {
            return 1;
        }
    }
    return 0;

}

sub subscribed_to {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }
    my $subscriptions   = [];
    my @available_lists = DADA::App::Guts::available_lists();

    require DADA::MailingList::Subscribers;
    require DADA::MailingList::Settings;

    my $list_names = {};

    foreach (@available_lists) {
        my $lh = DADA::MailingList::Subscribers->new( { -list => $_ } );

        if (
            $lh->check_for_double_email(
                -Email => $self->{email},
                -Type  => $args->{ -type }
            )
          )
        {
            push ( @$subscriptions, $_ );
        }

        # This needs its own method...

        my $ls = DADA::MailingList::Settings->new( { -list => $_ } );
        $list_names->{$_} = $ls->param('list_name');

    }

    if ( $args->{ -html_tmpl_params } ) {
        my $lt        = {};
        my $html_tmpl = [];
        foreach (@$subscriptions) {
            $lt->{$_} = 1;
        }
        foreach (@available_lists) {
            if ( exists( $lt->{$_} ) ) {
                push (
                    @$html_tmpl,
                    {
                        'profile.email' => $self->{email},
                        list            => $_,
                        subscribed      => 1
                    }
                );
            }
            else {
                push (
                    @$html_tmpl,
                    {
                        'profile.email' => $self->{email},
                        list            => $_,
                        subscribed      => 0
                    }
                );
            }
        }
        return $html_tmpl;
    }
    else {
        return $subscriptions;
    }

}

sub is_activated {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT activated FROM '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
		if $t; 

    $sth->execute( $args->{ -email } )
      or croak "cannot do statement (is_activated)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();

    my $activated = 0;
  FETCH: while ( my $hashref = $sth->fetchrow_hashref ) {
        $activated = $hashref->{activated};
        last FETCH;
    }

    $sth->finish;
    return $activated;
}



sub allowed_to_view_archives {

    my ($args) = @_;

    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a list in the, '-list' param!";
    }
    if ( !exists( $args->{ -ls_obj } ) ) {
        croak "I haven't made that, yet!";
    }

    if (   $DADA::Config::PROFILE_ENABLED != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return 1;
    }
    else {

        if ( $args->{ -ls_obj }->param('archives_available_only_to_subscribers')
            == 1 )
        {
            my $prof = DADA::Profile->new($args);
            if ($prof) {
                if (
                    $prof->subscribed_to_list( { -list => $args->{ -list } } ) )
                {
                    return 1;
                }
                else {
                    return 0;
                }
            }
            else {
                return 0;
            }
        }
        else {
            return 1;
        }
    }
}

sub exists {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT COUNT(*) FROM '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
		if $t; 

    $sth->execute( $self->{email} )
      or croak "cannot do statement (at exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

    return $row[0];

}

sub is_valid_password {

    my $self = shift;
    my ($args) = @_;

    require DADA::Security::Password;

    my $query =
      'SELECT email, password FROM '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ?';

    warn 'QUERY: ' . $query
		if $t; 

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{email} )
      or croak "cannot do statement (at is_valid_password)! $DBI::errstr\n";

  FETCH: while ( my $hashref = $sth->fetchrow_hashref ) {

        if (
            DADA::Security::Password::check_password(
                $hashref->{password}, $args->{ -password } ) == 1
          )
        {
            $sth->finish;
            return 1;
        }
        else {
            $sth->finish;
            return 0;
        }

        last FETCH;    # which will never be called...
    }

}

sub validate_registration {

    my $self = shift;
    my ($args) = @_;

    my $status = 1;
    my $errors = {
        email_no_match => 0,
        profile_exists => 0,
        invalid_email  => 0,
        password_blank => 0,
        captcha_failed => 0,
    };

    if ( $args->{ -email } ne $args->{ -email_again } ) {
        $errors->{email_no_match} = 1;
        $status = 0;
    }
    if ( check_for_valid_email( $args->{ -email } ) == 0 ) {

        # ...
    }
    else {
        $errors->{invalid_email} = 1;
        $status = 0;
    }
    if ( $self->exists( { -email => $args->{ -email } } ) ) {
        $errors->{profile_exists} = 1;
        $status = 0;
    }
    if ( length( $args->{ -password } ) == 0 ) {
        $errors->{password_blank} = 1;
        $status = 0;
    }

    my $can_use_captcha = 0;
    my $cap             = undef;
    if ( $DADA::Config::PROFILE_ENABLE_CAPTCHA == 1 ) {
        eval { require DADA::Security::AuthenCAPTCHA; };
        if ( !$@ ) {
            $can_use_captcha = 1;
        }
    }
    if ( $can_use_captcha == 1 ) {
        $cap = DADA::Security::AuthenCAPTCHA->new;
        my $result = $cap->check_answer(
            $DADA::Config::RECAPTCHA_PARAMS->{private_key},
            $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
            $args->{ -recaptcha_challenge_field },
            $args->{ -recaptcha_response_field },
        );
        if ( $result->{is_valid} == 1 ) {

            # ...
        }
        else {
            $errors->{captcha_failed} = 1;
            $status = 0;
        }
    }

    return ( $status, $errors );

}

sub update {

    my $self = shift;
    my ($args) = @_;
    my $orig = $self->get();

    foreach ( keys %$orig ) {
        next if $_ eq 'email';
        if ( exists( $args->{ '-' . $_ } ) ) {
            $orig->{$_} = $args->{ '-' . $_ };
        }
    }
    $self->remove();
    $orig->{ -email } = $self->{email};

    # This is kind of strange:
    my $new = {};
    foreach ( keys %$orig ) {
        $new->{ '-' . $_ } = $orig->{$_};
    }
    $self->insert($new);

}

sub setup_profile {
    my $self = shift;
    my ($args) = @_;

    # Pop it in,

    $self->insert( { -password => $args->{ -password }, } );

    # Spit it out:
    $self->send_profile_activation_email();
    return 1;
}

sub send_profile_activation_email {
    my $self = shift;
    my ($args) = @_;

    my $auth_code = $self->set_auth_code($args);
    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -email   => $self->{email},
            -headers => {
                Subject => $DADA::Config::PROFILE_ACTIVATION_MESSAGE_SUBJECT,
                From    => $DADA::Config::PROFILE_EMAIL,
                To      => $self->{email},
            },
            -body        => $DADA::Config::PROFILE_ACTIVATION_MESSAGE,
            -tmpl_params => {
                -vars => {
                    authorization_code => $auth_code,
                    email              => $self->{email},
                },
            },
        }
    );

    return 1;

}

sub send_profile_reset_password {
    my $self = shift;
    my ($args) = @_;

    my $auth_code = $self->set_auth_code($args);
    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -email   => $self->{email},
            -headers => {
                Subject =>
                  $DADA::Config::PROFILE_RESET_PASSWORD_MESSAGE_SUBJECT,
                From => $DADA::Config::PROFILE_EMAIL,
                To   => $self->{email},
            },
            -body        => $DADA::Config::PROFILE_RESET_PASSWORD_MESSAGE,
            -tmpl_params => {
                -vars => {
                    authorization_code => $auth_code,
                   	'profile.email'    => $self->{email},
					email              => $self->{email},
                },
            },
        }
    );
    return 1;
}

sub validate_profile_activation {

    my $self = shift;
    my ($args) = shift;

    my $status = 1;
    my $errors = { invalid_auth_code => 0, };

    my $profile = $self->get($args);

    if ( $profile->{auth_code} eq $args->{ -auth_code } ) {

        # ...
    }
    else {
        $errors->{invalid_auth_code} = 1;
        $status = 0;
    }

    return ( $status, $errors );
}

sub activate {
    my $self = shift;
    my ($args) = shift;

    if ( !exists( $args->{ -activate } ) ) {
        $args->{ -activate } = 1;
    }

    my $query = 'UPDATE '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' SET activated    = ? '
      . ' WHERE email      = ? ';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
      if $t;

    my $rv = $sth->execute( $args->{ -activate }, $self->{email} )
      or croak "cannot do statment (at activate)! $DBI::errstr\n";
    $sth->finish;
    return 1;
}

sub set_auth_code {

    my $self = shift;
    my ($args) = @_;

    #if( ! exists($args->{ -activated } )) {
    #	 $args->{ -activated } = 0;
    #}

    if ( $self->exists($args) ) {
        my $auth_code = $self->rand_str;
        my $query     = 'UPDATE '
          . $DADA::Config::SQL_PARAMS{profile_table}
          . ' SET auth_code	   = ? '
          . ' WHERE email   = ? ';
        my $sth = $self->{dbh}->prepare($query);

        warn 'QUERY: ' . $query
          if $t;
        my $rv = $sth->execute( $auth_code, $self->{email} )
          or croak "cannot do statment (at set_auth_code)! $DBI::errstr\n";
        $sth->finish;
        return $auth_code;
    }
    else {
        die "user does not exist!";
    }

}

sub remove {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ? ';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query . ' (' . $self->{email} . ')'
      if $t;
    my $rv = $sth->execute( $self->{email} )
      or croak "cannot do statment (at remove)! $DBI::errstr\n";
    $sth->finish;
    return $rv;
}

sub rand_str {
    my $self = shift;
    my $size = shift || 16;
    require DADA::Security::Password;
    return DADA::Security::Password::generate_rand_string( undef, $size );
}

1;


=pod

=head1 NAME 

DADA::Profile

=head1 SYNOPSIS


=head1 DESCRIPTION




=head1 Public Methods

=head2 new

	 my $p = DADA::Profile->new(
		{ 
			-email => 'user@example.com', 
		}
	); 
	
C<new> returns a DADA::Profile object. 

C<new> requires you to either pass the C<-email> paramater, with a valid email 
address, or the, C<-from_session> paramater, set to, C<1>: 

 my $p = DADA::Profile->new(
	{ 
		-from_session => 1, 
	}
 );

If invoked this way, the email address needed will be searched for within the 
saved session information for the particular environement. 

If no email address is passed, or found within the session, this method will croak. 

The email address passed needs not to have a valid profile, but some sort of email address needs to be passed. 


=head2 insert 

(blinky blinky under construction!)

 $p->insert(
	{
		-password  => 'mypass',
		-activated => 1, 
		-auth_code => 1234, 
	}
 );



C<insert>, I<inserts> a profile. It's not specifically used to I<create> new profiles and perhaps a shortcoming of this module (currently). What's strange is that 
if you attempt to insert two profiles dealing with the same address, you'll probably error out, just with the UNIQUE column of the table design... Gah.

Because of this somewhat sour design of this method, it's recommended you tread lightly and assume that the API will change, if not in the stable release, 
in a release sooner, rather than later. Outside of this module's code, it's used only once - making it somewhat of a private method, anyways. I'm going to forgo testing
this method until I figure all that out... </notestomyself>






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

