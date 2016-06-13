package CGI::Application::Plugin::RateLimit;

use 5.006;
use strict;
use warnings;

use Carp qw(croak);

our $VERSION = '1.0';

# export the rate_limit method into the using CGI::App and setup the
# prerun callback
sub import {
    my $pkg     = shift;
    my $callpkg = caller;

    {
        no strict qw(refs);
        *{$callpkg . '::rate_limit'} = \&rate_limit;
    }

    $callpkg->add_callback(prerun => \&prerun_callback);
}

# setup accessor/mutators for simple stuff
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(dbh table violation_mode violation_callback identity_callback
      violated_mode violated_action violated_limits));

# setup a new object the first time it's called
sub rate_limit {
    my $cgi_app = shift;
    return $cgi_app->{__rate_limit_obj} if $cgi_app->{__rate_limit_obj};

    my $rate_limit = $cgi_app->{__rate_limit_obj} = __PACKAGE__->new();

    # setup defaults
    $rate_limit->table('rate_limit_hits');
    $rate_limit->identity_callback(
        sub {
            return $ENV{REMOTE_USER} || $ENV{REMOTE_IP};
        });

    return $rate_limit;
}

# intercept the run-mode call
sub prerun_callback {
    my $cgi_app = shift;
    my $self    = $cgi_app->rate_limit;
    my $query   = $cgi_app->query;

    # see if this mode is protected
    my $mode = $query->param($cgi_app->mode_param)
      || $cgi_app->start_mode;
    my $protected = $self->protected_modes || {};
    my $limits = $protected->{$mode};
    return unless $limits;

    $self->_verify_attributes();

    # record the hit
    my $action = ref($cgi_app) . "::$mode";
    $self->record_hit(action => $action);

    # check for a violation
    if ($self->check_violation(action => $action, limits => $limits)) {

        # deal with it by jumping to violation_mode or calling the
        # violation callback
        if ($self->violation_mode) {
            $cgi_app->prerun_mode($self->violation_mode);
        } else {
            my $violation_callback = $self->violation_callback();
            $cgi_app->prerun_mode($violation_callback->($cgi_app));
        }
    }
}

# make sure we're ready to rumble
sub _verify_attributes {
    my $self = shift;

    for my $name (qw(dbh table identity_callback)) {
        croak(  "You forgot to set the required '$name' attribute on your "
              . __PACKAGE__
              . " object.")
          unless $self->{$name};
    }
    croak(  "You forgot to set the required 'violation_mode' or "
          . "'violation_callback' attribute on your "
          . __PACKAGE__
          . " object.")
      unless $self->{violation_mode}
      or $self->{violation_callback};
}

# translate a timeframe like 10s, 5m or 1h into seconds
sub _timeframe_to_seconds {
    my $time = shift;
    my ($digits, $modifier) = $time =~ /^(\d+)([smh])$/;
    croak(  "Invalid timeframe found: '$time'.  "
          . "Should be a number followed by s, m or h.")
      unless $digits and $modifier;

    return $digits           if $modifier eq 's';
    return $digits * 60      if $modifier eq 'm';
    return $digits * 60 * 60 if $modifier eq 'h';
}

sub protected_modes {
    my ($self, %args) = @_;
    return $self->{protected_modes} unless @_ > 1;
    $self->_check_limits(\%args);
    $self->{protected_modes} = \%args;
}

sub protected_actions {
    my ($self, %args) = @_;
    return $self->{protected_actions} unless @_ > 1;
    $self->_check_limits(\%args);
    $self->{protected_actions} = \%args;
}

sub _check_limits {
    my ($self, $args) = @_;
    foreach my $limits (values %$args) {
        defined $limits->{$_}
          or croak("Missing required value in protected limits hash: '$_'.")
          for (qw(timeframe max_hits));
        croak("Unknown keys found in protected limits hash.")
          unless keys(%$limits) == 2;
    }
}

sub record_hit {
    my ($self, %args) = @_;
    $self->_verify_attributes();

    my $dbh       = $self->dbh;
    my $timestamp = time;

    my $id_callback = $self->identity_callback();
    my $user_id     = $id_callback->();
    croak(  "Identity callback failed to return a value to "
          . __PACKAGE__
          . "::record_hit.")
      unless $user_id;

    $self->record_hit_sth($dbh)->execute($user_id, $args{action}, $timestamp)
      or croak(  "Failed to insert hit into table '"
               . $self->table . "': "
               . $dbh->errstr);

    # record particulars of last hit for revoke
    $self->{last_hit} = {user_id   => $user_id,
                         action    => $args{action},
                         timestamp => $timestamp};
}

sub revoke_hit {
    my $self = shift;
    $self->_verify_attributes();

    my $dbh      = $self->dbh;
    my $last_hit = $self->{last_hit}
      or croak("revoke_hit called without previous hit!");

    my $sth = $self->revoke_hit_sth($dbh);
    $sth->execute($last_hit->{user_id}, $last_hit->{action},
                  $last_hit->{timestamp})
      or croak(  "Failed to delete hit from table '"
               . $self->table . "': "
               . $dbh->errstr);

}

sub check_violation {
    my ($self, %args) = @_;

    my $dbh = $self->dbh;

    my $id_callback = $self->identity_callback();
    my $user_id     = $id_callback->();
    croak(  "Identity callback failed to return a value to "
          . __PACKAGE__
          . "::check_violation.")
      unless $user_id;

    # get limits passed-in for protected modes, else lookup for actions
    my ($limits, $is_mode);
    if ($args{limits}) {
        $limits  = $args{limits};
        $is_mode = 1;
    } else {
        my $protected_actions = $self->protected_actions() || {};
        $limits = $protected_actions->{$args{action}};
        croak(  "Called check_violation() for unknown protected action "
              . "'$args{action}'.")
          unless $limits;
    }

    my $seconds = _timeframe_to_seconds($limits->{timeframe});

    my $sth = $self->check_violation_sth($dbh);
    $sth->execute($user_id, $args{action}, time - $seconds);
    my ($count) = $sth->fetchrow_array();
    $sth->finish;

    if ($count > $limits->{max_hits}) {

        # setup violation details
        if ($is_mode) {
            $self->violated_mode($args{action});
        } else {
            $self->violated_action($args{action});
        }
        $self->violated_limits($limits);

        return 1;
    }

    return 0;
}

#
# SQL code.  If you want to port this module to a new DB, add some
# magic here.  With any luck you won't have to - this SQL is pretty
# bland.
#

sub record_hit_sth {
    my ($self, $dbh) = @_;

    return $dbh->prepare_cached('INSERT INTO '
                            . $dbh->quote_identifier($self->table)
                            . ' (user_id, action, timestamp) VALUES (?,?,?)');
}

sub check_violation_sth {
    my ($self, $dbh) = @_;

    return $dbh->prepare_cached('SELECT COUNT(*) FROM '
                     . $dbh->quote_identifier($self->table)
                     . ' WHERE user_id = ? AND action = ? AND timestamp > ?');
}

sub revoke_hit_sth {
    my ($self, $dbh) = @_;

    return $dbh->prepare_cached('DELETE FROM '
                     . $dbh->quote_identifier($self->table)
                     . ' WHERE user_id = ? AND action = ? AND timestamp = ?');
}

1;
__END__

=head1 NAME

CGI::Application::Plugin::RateLimit - limits runmode call rate per user

=head1 SYNOPSIS

  use CGI::Application::Plugin::RateLimit;

  sub setup {
    ...

    # call this in your setup routine to set
    my $rate_limit = $self->rate_limit();

    # set the database handle to use
    $rate_limit->dbh($dbh);

    # set the table name to use for storing hits, the default is
    # 'rate_limit_hits'
    $rate_limit->table('rate_limit_hits');

    # keep people from calling 'send' more often than 5 times in 10
    # minutes and 'list' more often than once every 5 seconds.
    $rate_limit->protected_modes(send => {timeframe => '10m',
                                          max_hits  => 5
                                         },
                                 list => {timeframe => '5s',
                                          max_hits  => 1
                                         });

    # you can also protect abstract actions, for example to prevent a
    # flood of failed logins
    $rate_limit->protected_actions(failed_login => {timeframe => '10s',
                                                    max_hits  => 2
                                                   });

    # call this runmode when a violation is detected
    $rate_limit->violation_mode('too_fast_buddy');

    # or, run this callback
    $rate_limit->violation_callback(sub { die(...) });

    # override the default identity function
    # ($ENV{REMOTE_USER} || $ENV{REMOTE_IP})
    $rate_limit->identity_callback(sub { ... });
  }

  # record a hit for an action (not needed for run-modes which are
  # handled automatically)
  $rate_limit->record_hit(action => 'failed_login');

  # check for a violation on an action and handle
  return $self->slow_down_buddy
    if( $rate_limit->check_violation(action => 'failed_login') );

  # revoke the most recent hit for this user, preventing it from
  # counting towards a violation
  $rate_limit->revoke_hit();

  # examine the violation in violation_mode or violation_callback:
  $mode   = $rate_limit->violated_mode;
  $action = $rate_limit->violated_action;
  $limits = $rate_limit->violated_limits;

=head1 DESCRIPTION

This module provides protection against a user calling a runmode too
frequently.  A typical use-case might be a contact form that sends
email.  You'd like to allow your users to send you messages, but
thousands of messages from a single user would be a problem.

This module works by maintaining a database of hits to protected
runmodes.  It then checks this database to determine if a new hit
should be allowed based on past activity by the user.  The user's
identity is, by default, tied to login (via REMOTE_USER) or IP address
(via REMOTE_IP) if login info is not available.  You may provide your
own identity function via the identity_callback() method.

To use this module you must create a table in your database with the
following schema (using MySQL-syntax, although other DBs may work as
well with minor alterations):

  CREATE TABLE rate_limit_hits (
     user_id   VARCHAR(255)      NOT NULL,
     action    VARCHAR(255)      NOT NULL,
     timestamp UNSIGNED INTEGER  NOT NULL,
     INDEX (user_id, action, timestamp)
  );

You may feel free to vary the storage-type and size of user_id and
action to match your usage.  For example, if your identity_callback()
always returns an integer you could make user_id an integer column.

This table should be periodically cleared of old data.  Anything older
than the maximum timeframe being used can be safely deleted.

B<IMPORTANT NOTE>: The protection offered by this module is not
perfect.  Identifying a user on the internet is very hard and a
sophisticated attacker can work around these checks, by switching IPs
or automating login creation.

=head1 INTERFACE

The object returned from calling C<< $self->rate_limit >> on your
CGI::App object supports the following method calls:

=head2 dbh

   $rate_limit->dbh($dbh);

Call this to set the database handle the object should use.  Must be
set in setup().

=head2 table

   $rate_limit->table('some_table_name');

Call this to determine the table to be used to store and lookup hits.
The default is 'rate_limit_hits' if not set.  See the DESCRIPTION
section for the required table schema.

=head2 protected_modes

    $rate_limit->protected_modes(send => {timeframe => '10m',
                                          max_hits  => 5
                                         },
                                 list => {timeframe => '5s',
                                          max_hits  => 1
                                         });

Takes a list of key-value pairs describing the modes to protect.  Keys
are names of run-modes.  Values are hashes with the following keys:

  timeframe - the timeframe to be considered for violations.  Values
  must be numbers followed by either 's' for seconds, 'm' for minutes
  or 'h' for hours.

  max_hits - how many hits to allow in the specified timeframe before
  triggering a violation.

=head2 protected_actions

    $rate_limit->protected_actions(failed_login => {timeframe => '10s',
                                                    max_hits  => 2
                                                   });

Specifies non-run-mode actions to protect.  These are arbitrary keys
you can use with record_hit() and check_violation().  Takes the same
data-structure as protected_modes().

=head2 violation_mode

  $rate_limit->violation_mode('too_fast_buddy');

Call to set a run-mode to call when a violation is triggered.  Either
this or violation_callback must be set.

=head2 violation_callback

    $rate_limit->violation_callback(sub { ... });

Callback to call when a violation is detected.  Should either throw an
exception or return the run-mode to run.  Called with the CGI::App
object as its sole parameter.

=head2 identity_callback

    $rate_limit->identity_callback(sub { ... });

Call this to provide a customized mechanism for determining the
identity of the user.  The default is:

  sub { $ENV{REMOTE_USER} || $ENV{REMOTE_IP} }

You might consider adding in session-ID or a hook to your
authentication system if it doesn't use REMOTE_USER.  Whatever you
write should return a single scalar which is expected to be unique to
each user.

=head2 record_hit

  $rate_limit->record_hit(action => 'failed_login');

Record a hit for an arbitrary action.  This is not needed for run-mode
protection.  Takes the action name as an argument, which must match an
action registered with protected_actions().

=head2 check_violation

  return $self->slow_down_buddy
    if( $rate_limit->check_violation(action => 'failed_login') );

Checks for a violation of a protected action.  This is not needed for
run-mode protection.  Takes the action name as an argument, which must
match an action registered with protected_actions().

Returns 1 if a violation took place, 0 otherwise.

=head2 revoke_hit

  $rate_limit->revoke_hit();

Revokes the last hit for this user.  You might use this to prevent
validation errors from counting against a user, for example.

=head2 violated_mode

  $mode = $rate_limit->violated_mode;

Returns the mode for the last violation, or undef if an action caused
the violation.

=head2 violated_action

  $mode = $rate_limit->violated_action;

Returns the action for the last violation, or undef if an action
caused the violation.

=head2 violated_limits

  $limits = $rate_limit->violated_limits;

Returns the hash-ref passed to protected_actions() or
protected_modes() for the violated mode/action.

=head1 DATABASE SUPPORT

I've tested this module with MySQL and SQLite.  I think it's likely to
work with many other databases - please let me know if you try one.

=head1 SUPPORT

Please send questions and suggestions about this module to the
CGI::Application mailing-list.  To join the mailing list, simply send
a blank message to:

  cgiapp-subscribe@lists.erlbaum.net

=head1 VERSION CONTROL

This module is in a public Subversion repository at SourceForge here:

   https://svn.sourceforge.net/svnroot/html-template/trunk/CGI-Application-Plugin-RateLimit

=head1 BUGS

I know of no bugs.  If you find one, let me know by filing a report on
http://rt.cpan.org.  Failing that, you can email me at sam@tregar.com.
Please include the version of the module you're using and small test
case demonstrating the problem.

=head1 AUTHOR

Sam Tregar, sam@plusthree.com

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Sam Tregar

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
