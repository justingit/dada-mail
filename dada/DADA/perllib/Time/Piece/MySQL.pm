package Time::Piece::MySQL;
use strict;
use vars qw($VERSION);
$VERSION = '0.06';

use Time::Piece;

sub import { shift; @_ = ('Time::Piece', @_); goto &Time::Piece::import }

package Time::Piece;

use Time::Seconds;

BEGIN
{
    # I don't know what this dst bug is, but the code was here...
    my $has_dst_bug =
	Time::Piece->strptime( '20000601120000', '%Y %m %d %H %M %S' )->hour != 12;
    sub HAS_DST_BUG () { $has_dst_bug }
}

sub mysql_date
{
    my $self = shift;
    my $old_sep = $self->date_separator('-');
    my $ymd = $self->ymd;
    $self->date_separator($old_sep);
    return $ymd;
}

sub mysql_time
{
    my $self = shift;
    my $old_sep = $self->time_separator(':');
    my $hms = $self->hms;
    $self->time_separator($old_sep);
    return $hms;
}

sub mysql_datetime
{
    my $self = shift;
    return join ' ', $self->mysql_date, $self->mysql_time;
}


# '1000-01-01 00:00:00' to '9999-12-31 23:59:59'

sub from_mysql_date {
    my ($class, $dt) = @_;
    return unless $dt and $dt ge '1970' and $dt lt '2038';
    my $time = eval {$class->strptime($dt, '%Y-%m-%d')};
    return $time;
}

sub from_mysql_datetime {
    my ($class, $dt) = @_;
    return unless $dt and $dt ge '1970' and $dt lt '2038';
    my $time = eval {$class->strptime($dt, '%Y-%m-%d %H:%M:%S')};
    $time -= ONE_HOUR if HAS_DST_BUG && $time->isdst;
    return $time;
}

sub mysql_timestamp {
	my $self = shift;
	return $self->strftime('%Y%m%d%H%M%S');
}

sub from_mysql_timestamp {
    # From MySQL version 4.1, timestamps are returned as datetime strings
    my ($class, $timestamp) = @_;
    my $length = length $timestamp;
    return from_mysql_datetime(@_) if $length == 19;
    # most timestamps have 2-digit years, except 8 and 14 char ones
    if ( $length != 14 && $length != 8 ) {
        $timestamp = (substr($timestamp, 0, 2) < 70 ? "20" : "19")
                   . $timestamp;
    }
    # now we need to extend this to 14 chars to make sure we get
    # consistent cross-platform results
    $timestamp .= substr("19700101000000", length $timestamp);
    my $time = eval {$class->strptime( $timestamp, '%Y %m %d %H %M %S')};
    return $time;
}

1;

__END__

=head1 NAME

Time::Piece::MySQL - Adds MySQL-specific methods to Time::Piece

=head1 SYNOPSIS

  use Time::Piece::MySQL;

  my $time = localtime;

  print $time->mysql_datetime;
  print $time->mysql_date;
  print $time->mysql_time;

  my $time = Time::Piece->from_mysql_datetime( $mysql_datetime );
  my $time = Time::Piece->from_mysql_date( $mysql_date );
  my $time = Time::Piece->from_mysql_timestamp( $mysql_timestamp );

=head1 DESCRIPTION

Using this module instead of, or in addition to, C<Time::Piece> adds a
few MySQL-specific date-time methods to C<Time::Piece> objects.

=head1 OBJECT METHODS

=head2 mysql_date / mysql_time / mysql_datetime / mysql_timestamp

Returns the date and/or time in a format suitable for use by MySQL.

=head1 CONSTRUCTORS

=head2 from_mysql_date / from_mysql_datetime / from_mysql_timestamp

Given a date, datetime, or timestamp value as returned from MySQL, these
constructors return a new Time::Piece object.  If the value is NULL, they
will retrun undef.

=head2 CAVEAT

C<Time::Piece> itself only works with times in the Unix epoch, this module has
the same limitation.  However, MySQL itself handles date and datetime columns
from '1000-01-01' to '9999-12-31'.  Feeding in times outside of the Unix epoch
to any of the constructors has unpredictable results.

Also, MySQL doesn't validate dates (because your application should); it only
checks that dates are in the right format.  So, your database might include
dates like 2004-00-00 or 2001-02-31.  Passing invalid dates to any of the
constructors is a bad idea: on my system the former type (with zeros) returns
undef (previous version used to die) while the latter returns a date in the
following month.

=head1 AUTHOR

Original author: Dave Rolsky <autarch@urth.org>

Current maintainer: Marty Pauley <marty+perl@kasei.com>

=head1 COPYRIGHT

(c) 2002 Dave Rolsky

(c) 2004 Marty Pauley

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Time::Piece>

=cut
