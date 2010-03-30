package CGI::Session::ExpireSessions;

# Name:
#	CGI::Session::ExpireSessions.
#
# Documentation:
#	POD-style documentation is at the end. Extract it with pod2html.*.
#
# Reference:
#	Object Oriented Perl
#	Damian Conway
#	Manning
#	1-884777-79-1
#	P 114
#
# Note:
#	o Tab = 4 spaces || die.
#
# Author:
#	Ron Savage <ron@savage.net.au>
#	Home page: http://savage.net.au/index.html
#
# Licence:
#	Australian copyright (c) 2004 Ron Savage.
#
#	All Programs of mine are 'OSI Certified Open Source Software';
#	you can redistribute them and/or modify them under the terms of
#	The Artistic License, a copy of which is available at:
#	http://www.opensource.org/licenses/index.html

use strict;
use warnings;

require 5.005_62;

require Exporter;

use Carp;
use CGI::Session;
use File::Spec;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use CGI::Session::ExpireSessions ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);
our $VERSION = '1.09';

# -----------------------------------------------

# Preloaded methods go here.

# -----------------------------------------------

# Encapsulated class data.

{
	my(%_attr_data) =
	(
		_cgi_session_dsn	=> undef,
		_dbh				=> '',
		_delta				=> 2 * 24 * 60 * 60, # Seconds.
		_dsn_args			=> undef,
		_table_name			=> 'sessions',
		_temp_dir			=> '/tmp',
		_time				=> time(),
		_verbose			=> 0,
	);

	sub _check_expiry
	{
		my($self, $D)	= @_;
		my($expired)	= 0;
		my($time)		= time();

		if ( ($time - $$D{'_SESSION_ATIME'}) >= $$self{'_delta'})
		{
			$expired = 1;

			print STDOUT "Delta time: $$self{'_delta'}. Time elapsed: ", $time - $$D{'_SESSION_ATIME'}, ". Expired?: $expired. \n" if ($$self{'_verbose'});
		}

		if ($$D{'_SESSION_ETIME'} && ! $expired)
		{
			$expired = 1 if ($time >= ($$D{'_SESSION_ATIME'} + $$D{'_SESSION_ETIME'}) );

			print STDOUT "Last access time: $$D{'_SESSION_ATIME'}. Expiration time: $$D{'_SESSION_ETIME'}. Time elapsed: ", $time - $$D{'_SESSION_ATIME'}, ". Expired?: $expired. \n" if ($$self{'_verbose'});
		}

		$expired;
	}

	sub _default_for
	{
		my($self, $attr_name) = @_;

		$_attr_data{$attr_name};
	}

	# Warning: The args hashref passed in to sub _purge() has /no/ connexion
	# with the $self hashref with belongs to the object instantiated by our client.
	# The client code did something like this to create an object:
	# my($expirer) = CGI::Session::ExpireSessions -> new(delta => 1);
	# and we, the object, i.e. $expirer, are in fact the server.

	sub _purge
	{
		my($session, $args) = @_;

		return if ($session -> is_empty() );

		if ($session -> is_expired() || ($$args{'_time'} - $session -> atime() >= $$args{'_delta'}) )
		{
			print STDOUT "Expiring id @{[$session -> id()]}. \n" if ($$args{'_verbose'});

			$session -> delete();
			$session -> flush();
		}
	}

	sub _standard_keys
	{
		keys %_attr_data;
	}

}	# End of encapsulated class data.

# -----------------------------------------------

sub expire_db_sessions
{
	my($self, %arg) = @_;

	$self -> set(%arg) if (%arg);

	Carp::croak(__PACKAGE__ . ". You must specify a value for the parameter 'dbh'") if (! $$self{'_dbh'});

	my($sth) = $$self{'_dbh'} -> prepare("select * from $$self{'_table_name'}");

	$sth -> execute();

	my($data, $D, @id, $untainted_data);

	while ($data = $sth -> fetchrow_hashref() )
	{
		# Untaint the data the brute force way.

		($untainted_data) = $$data{'a_session'} =~ /(.*)/;

		eval $untainted_data;

		push @id, $$data{'id'} if ($self -> _check_expiry($D) );
	}

	for (@id)
	{
		print STDOUT "Expiring db id: $_. \n" if ($$self{'_verbose'});

		$sth = $$self{'_dbh'} -> prepare("delete from $$self{'_table_name'} where id = ?");

		$sth -> execute($_);

		$sth -> finish();
	}

	if ( ($#id < 0) && $$self{'_verbose'})
	{
		print STDOUT "No db ids are due to expire. \n";
	}

}	# End of expire_db_sessions.

# -----------------------------------------------

sub expire_file_sessions
{
	my($self, %arg) = @_;

	$self -> set(%arg) if (%arg);

	Carp::croak(__PACKAGE__ . ". You must specify a value for the parameter 'temp_dir'") if (! $$self{'_temp_dir'});

	opendir(INX, $$self{'_temp_dir'}) || Carp::croak("Can't opendir($$self{'_temp_dir'}): $!");
	my(@file) = map{File::Spec -> catfile($$self{'_temp_dir'}, $_)} grep{/cgisess_[0-9a-f]{32}/} readdir(INX);
	closedir INX;

	my($count)	= 0;
	my($time)	= time();

	my($file, @stat, $D);

	for my $file (@file)
	{
		@stat = stat($file);

		# Delete old, tiny files.

		if ( ( ($time - $stat[8]) >= $$self{'_delta'}) && ($stat[7] <= 5) )
		{
			$count++;

			print STDOUT "Delta time: $$self{'_delta'}. Size: $stat[7] bytes. Time elapsed: ", $time - $stat[8], ". Expired?: 1. \n" if ($$self{'_verbose'});

			unlink $file;

			next;
		}

		# Ignore new, tiny files.

		next if ($stat[7] <= 5);

		open(INX, $file) || Carp::croak("Can't open($file): $!");
		binmode INX;
		my(@session) = <INX>;
		close INX;

		# Pod/perlfunc.html#item_eval
		# This does not work:
		# eval{no warnings 'all'; $session[0]};
		# This was when I used to say 'eval $session[0];', but that fails
		# when the session data contains \n characters. Hence the join.

		eval join('', @session);

		if ($@)
		{
			print STDOUT "Unable to parse contents of file: $file. \n" if ($$self{'_verbose'});

			next;
		}

		if ($self -> _check_expiry($D) )
		{
			$count++;

			print STDOUT "Expiring file id: $$D{'_SESSION_ID'}. \n" if ($$self{'_verbose'});

			unlink $file;
		}
	}

	print STDOUT "No file ids are due to expire. \n" if ( ($count == 0) && $$self{'_verbose'});

}	# End of expire_file_sessions.

# -----------------------------------------------

sub expire_sessions
{
	my($self, %arg) = @_;

	return if (! CGI::Session -> can('find') );

	# Return the result of find, which is:
	# o Undef for failure
	# o 1 for success

	$self -> set(%arg) if (%arg);

	return CGI::Session -> find
	(
		$$self{'_cgi_session_dsn'},
		sub{_purge(@_,
		{												# This hashref is a parameter for _purge().
			_delta		=> $$self{'_delta'}	|| 0,		# These 2 defaults are in case the user sets them to undef!
			_time		=> $$self{'_time'}	|| time(),	# The defaults then stop Perl issuing warning messages about
			_verbose	=> $$self{'_verbose'},			# uninitialized variables during the call to sub _purge().
		})},
		$$self{'_dsn_args'}
	);

}	# End of expire_sessions.

# -----------------------------------------------

sub new
{
	my($class, %arg)	= @_;
	my($self)			= bless({}, $class);

	for my $attr_name ($self -> _standard_keys() )
	{
		my($arg_name) = $attr_name =~ /^_(.*)/;

		if (exists($arg{$arg_name}) )
		{
			$$self{$attr_name} = $arg{$arg_name};
		}
		else
		{
			$$self{$attr_name} = $self -> _default_for($attr_name);
		}
	}

	return $self;

}	# End of new.

# -----------------------------------------------

sub set
{
	my($self, %arg) = @_;

	for my $arg (keys %arg)
	{
		$$self{"_$arg"} = $arg{$arg} if (exists($$self{"_$arg"}) );
	}

}	# End of set.

# -----------------------------------------------

1;

__END__

=head1 NAME

C<CGI::Session::ExpireSessions> - Delete expired C<CGI::Session>-type db-based and file-based sessions

=head1 Synopsis

	#!/usr/bin/perl

	use strict;
	use warnings;

	use CGI::Session::ExpireSessions;
	use DBI;

	# -----------------------------------------------

	my($dbh) = DBI -> connect
	(
	  'dbi:mysql:aussi:127.0.0.1',
	  'root',
	  'pass',
	  {
	    AutoCommit         => 1,
	    PrintError         => 0,
	    RaiseError         => 1,
	    ShowErrorStatement => 1,
	  }
	);

	CGI::Session::ExpireSessions -> new(dbh => $dbh, verbose => 1) -> expire_db_sessions();
	CGI::Session::ExpireSessions -> new(temp_dir => '/tmp', verbose => 1) -> expire_file_sessions();
	CGI::Session::ExpireSessions -> new(verbose => 1) -> expire_sessions();

	# Note: You are strongly urged to use method expire_sessions() (it requires CGI::Session V 4 or later),
	# since it does not eval the session data, and hence avoids the security issues of evaling a string
	# which comes from outside the program. See examples/expire-set.pl, which contains extensive comments.

=head1 Description

C<CGI::Session::ExpireSessions> is a pure Perl module.

It deletes C<CGI::Session>-type sessions which have passed their use-by date.

It works with C<CGI::Session>-type sessions in a database or in disk files, but does not appear
to work with C<CGI::Session::PureSQL>-type sessions.

The recommended way to use this module is via method C<expire_sessions()>, which requires
C<CGI::Session> V 4 or later.

Sessions can be expired under one of three conditions:

=over 4

=item You deem the session to be expired as of now

=over 4

=item Methods: C<expire_db_sessions()> and C<expire_file_sessions()>

You want the session to be expired and hence deleted now because it's last access time is longer ago than the
time you specify in the call to new, using the delta parameter.

That is, delete the session because the time span, between the C<last access> time and now, is greater than delta.

In other words, force sessions to expire.

The module has always used this condition to delete sessions.

=item Method: C<expire_sessions()>

You want the session to be expired and hence deleted now because it's C<last access> time is longer ago than the
time you specify in the call to new, using the delta parameter.

=back

=item The session has already expired

This section applies to all 3 methods: C<expire_db_sessions()>, C<expire_file_sessions()> and C<expire_sessions()>.

This condition is new as of V 1.02.

You want the session to be deleted now because it has already expired.

That is, you want this module to delete the session, rather than getting C<CGI::Session> to delete it, when
C<CGI::Session> would delete the session automatically if you used C<CGI::Session> to retrieve the session.

Note: This condition assumes the session's expiration time is defined (it does not have to be).

=item The file size is <= 5 bytes and was accessed more than 'delta' seconds ago

This condition is new as of V 1.03.

This section applies to method: C<expire_file_sessions()>.

See below for how to provide a value of delta to the constructor.

Old versions of C<CGI::Session> sometimes create a file of size 0 bytes, so this test checks for such files,
and deletes them if they are old enough.

=back

Sessions are deleted if any of these conditions is true.

Sessions are deleted from the 'sessions' table in the database, or from the temp directory,
depending on how you use C<CGI::Session>.

=head1 Distributions

This module is available both as a Unix-style distro (*.tgz) and an
ActiveState-style distro (*.ppd). The latter is shipped in a *.zip file.

See http://savage.net.au/Perl-modules.html for details.

See http://savage.net.au/Perl-modules/html/installing-a-module.html for
help on unpacking and installing each type of distro.

=head1 Security

For file-based sessions, method C<expire_file_sessions()> parses the contents of the
file, using eval{}, in an attempt to determine the access and expiration times recorded
within the file.

So, if you are uneasy about the security implication of this (as you should be),
don't use this method. Use method C<expire_sessions()> instead. The latter is a much more
sophisticated way of expiring sessions, but it does require C<CGI::Session> V 4 or later.

=head1 Constructor and initialization

new(...) returns a C<CGI::Session::ExpireSessions> object.

This is the class's contructor.

Usage: CGI::Session::ExpireSessions -> new().

This method takes a set of parameters. Only some of these parameters are mandatory.

For each parameter, call method C<new()> as new(param_1 => value_1, param_2 => value_2, ...).

Note: As of V 1.07 of this module, you may call method C<set()> to set parameters after calling
method C<new()>.

Not only that, but you may pass into all of the 3 methods C<expire_db_sessions()>,
C<expire_file_sessions()> and C<expire_sessions()> any of the parameters accepted by C<new()>,
since these 3 methods call C<set()> if their caller provides parameters.

Parameters which can be used with C<new()>, C<set()>, or C<expire_*()>:

=over 4

=item cgi_session_dsn

This is the DSN (Data Source Name) used by C<CGI::Session> to control what type of sessions
you previously created and what type of sessions you now wish to expire.

Do not confuse this with the DSN used by C<CGI::Session>'s method find(param_1, \&sub, {DataSource => other_dsn...}, ...)
when referring to db-based sessions.

Method C<expire_sessions()> is the only method in this module which uses this parameter.

So, when you call C<expire_sessions()>, this parameter - cgi_session_dsn - determines the
set of sessions processed by, and possibly expired by, the call to C<expire_sessions()>.

The default value is undef, which means C<CGI::Session> defaults to file-based sessions.

This parameter is optional for file-based sessions, and mandatory for db-based sessions.

=item dbh

This is a database handle for the database containing the table 'sessions'.

Either this parameter is mandatory, or the temp_dir parameter is mandatory.

=item delta

=over 4

=item Methods: C<expire_db_sessions()> and C<expire_file_sessions()>

This is the number of seconds since the C<last access> to the session, which determines
whether or not the session will be expired.

=item Method: C<expire_sessions()>

This is the number of seconds since the C<last access> time of the session, which determines
whether or not the session will be expired.

=back

The default value is 2 * 24 * 60 * 60, which is the number of seconds in 2 days.

By default, then, sessions which were last accessed more than 2 days ago are expired.

This parameter is optional.

=item dsn_args

If your cgi_session_dsn uses file-based storage, then this hashref might contain keys such as:

	{
		Directory => Value 1,
		NoFlock   => Value 2,
		UMask     => Value 3
	}

If your cgi_session_dsn uses db-based storage, then this hashref contains (up to) 3 keys, and looks like:

	{
		DataSource => Value 1,
		User       => Value 2,
		Password   => Value 3
	}

These 3 form the DSN, username and password used by DBI to control access to your database server,
and hence are only relevant when using db-based sessions.

Method C<expire_sessions()> is the only method in this module which uses the parameter dsn_args.

The default value for this parameter is undef.

These parameters are optional for file-based sessions, and mandatory for db-based sessions.

=item table_name

This is the name of the database table used to hold the sessions.

The default value is 'sessions'.

This parameter is optional.

=item temp_dir

This is the name of the temp directory where you store CGI::Session-type session files.

The default value is '/tmp'.

Either this parameter is mandatory, or the dbh parameter is mandatory.

=item time

The session's C<last access> time is subtracted from the value of this parameter, and if the result
is greater than or equal to the value of parameter 'delta', then the session is expired.

Method C<expire_sessions()> is the only method in this module which uses this parameter.

The default value is obtained by calling time().

This parameter is optional.

=item verbose

This is a integer, 0 or 1, which - when set to 1 - causes progress messages to be
written to STDOUT.

The default value is 0.

This parameter is optional.

=back

=head1 Method: expire_db_sessions()

Returns nothing.

This method uses the dbh parameter passed to C<new()> to delete database-type sessions.

=head1 Method: expire_file_sessions()

Returns nothing.

This method uses the temp_dir parameter passed to C<new()> to delete file-type sessions.

=head1 Method: expire_sessions()

Return value:

=over 4

=item undef

Returns undef if your version of C<CGI::Session> does not support method C<find()>.

Also, returns undef when C<CGI::Session>'s method C<find()> failed for some reason.

=item 1

Returns 1 when C<find()> succeeds.

=back

Returns the result of calling CGI::Session's method find(), which will be undef for some
sort of failure, and 1 for success.

This method handles both file-based and db-based sessions.

=head1 Example code

See the examples/ directory in the distro.

There are 2 demo programs: expire-sessions.pl and expire-set.pl.

=head1 Required Modules

=over 4

=item Carp

=item CGI::Session

=item File::Spec

=back

=head1 Author

C<CGI::Session::ExpireSessions> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2004.

Home page: http://savage.net.au/index.html

=head1 Copyright

Australian copyright (c) 2004, Ron Savage. All rights reserved.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
