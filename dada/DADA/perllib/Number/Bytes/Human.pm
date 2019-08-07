package Number::Bytes::Human;

use strict;
use warnings;

our $VERSION = '0.11';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(format_bytes parse_bytes);

require POSIX;
use Carp qw(croak carp);

#my $DEFAULT_BLOCK = 1024;
#my $DEFAULT_ZERO = '0';
#my $DEFAULT_ROUND_STYLE = 'ceil';
my %DEFAULT_SUFFIXES = (
  1024 => ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'],
  1000 => ['', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'],
  1024000 => ['', 'M', 'T', 'E', 'Y'],
  si_1024 => ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'],
  si_1000 => ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'],
);
my @DEFAULT_PREFIXES = @{$DEFAULT_SUFFIXES{1024}};

sub _default_suffixes {
  my $set = shift || 1024;
  if (exists $DEFAULT_SUFFIXES{$set}) {
    return @{$DEFAULT_SUFFIXES{$set}} if wantarray;
    return [ @{$DEFAULT_SUFFIXES{$set}} ];
  }
  croak "unknown suffix set '$set'";
}

my %ROUND_FUNCTIONS = (
  ceil => sub { return POSIX::ceil($_[0] * (10 ** $_[1])) / 10**$_[1]; },
  floor => sub { return POSIX::floor($_[0] * (10 ** $_[1])) / 10**$_[1]; },
  round => sub { return sprintf( "%." . ( $_[1] || 0 ) . "f", $_[0] ); },
  trunc => sub { return sprintf( "%d", $_[0] * (10 ** $_[1])) / 10**$_[1]; },
  # what about 'ceiling'?
);

sub _round_function {
  my $style = shift;
  if (exists $ROUND_FUNCTIONS{$style}) {
    return $ROUND_FUNCTIONS{$style}
  }
  croak "unknown round style '$style'";
}

# options
#   block | block_size | base | bs => 1024 | 1000
#   base_1024 | block_1024 | 1024 => $true
#   base_1000 | block_1000 | 1000 => $true
#
#   round_function => \&
#   round_style => 'ceiling', 'round', 'floor', 'trunc'
#
#   suffixes => 1024 | 1000 | si_1024 | si_1000 | 1024000 | \@
#   si => 1
#   unit => string (eg., 'B' | 'bps' | 'b')
#
#   zero => '0' (default) | '-' | '0%S' | undef
#
#
#   supress_point_zero | no_point_zero =>
#   b_to_i => 1
#   to_s => \&
#
#   allow_minus => 0 | 1
#   too_large => string
#   quiet => 1 (supresses "too large number" warning)



#  PROBABLY CRAP:
#   precision => integer

# parsed options
#   BLOCK => 1024 | 1000
#   ROUND_STYLE => 'ceil', 'round', 'floor', 'trunc'
#   ROUND_FUNCTION => \&
#   SUFFIXES => \@
#   ZERO =>
#   SI => undef | 1			Parse SI compatible


=begin private

  $options = _parse_args($seed, $args)
  $options = _parse_args($seed, arg1 => $val1, ...)

$seed is undef or a hashref
$args is a hashref

=end private

=cut

sub _parse_args {
  my $seed = shift;
  my %args;

  my %options;
  unless (defined $seed) { # use defaults
    $options{BLOCK} = 1024;
    $options{ROUND_STYLE} = 'ceil';
    $options{ROUND_FUNCTION} = _round_function($options{ROUND_STYLE});
    $options{ZERO} = '0';
    $options{SI} = undef;
    $options{PRECISION} = 1;
    $options{PRECISION_CUTOFF} = 1;
    #$options{SUFFIXES} = # deferred to the last minute when we know BLOCK, seek [**]
    $options{UNIT} = undef;
  }
  # else { %options = %$seed } # this is set if @_!=0, down below

  if (@_==0) { # quick return for default values (no customized args)
    return (defined $seed) ? $seed : \%options;
  } elsif (@_==1 && ref $_[0]) { # \%args
    %args = %{$_[0]};
  } else { # arg1 => $val1, arg2 => $val2
    %args = @_;
  }

  # this is done here so this assignment/copy doesn't happen if @_==0
  %options = %$seed unless %options;

# block | block_size | base | bs => 1024 | 1000
# block_1024 | base_1024 | 1024 => $true
# block_1000 | base_1000 | 1024 => $true
  if ($args{block} ||
      $args{block_size} ||
      $args{base} ||
      $args{bs}
    ) {
    my $block = $args{block} ||
                $args{block_size} ||
                $args{base} ||
                $args{bs};
    unless ($block==1000 || $block==1024 || $block==1_024_000) {
      croak "invalid base: $block (should be 1024, 1000 or 1024000)";
    }
    $options{BLOCK} = $block;

  } elsif ($args{block_1024} ||
           $args{base_1024}  ||
           $args{1024}) {

    $options{BLOCK} = 1024;
  } elsif ($args{block_1000} ||
           $args{base_1000}  ||
           $args{1000}) {

    $options{BLOCK} = 1000;
  }

# round_function => \&
# round_style => 'ceil' | 'floor' | 'round' | 'trunc'
  if ($args{round_function}) {
    unless (ref $args{round_function} eq 'CODE') {
      croak "round function ($args{round_function}) should be a code ref";
    }
    $options{ROUND_FUNCTION} = $args{round_function};
    $options{ROUND_STYLE} = $args{round_style} || 'unknown';
  } elsif ($args{round_style}) {
    $options{ROUND_FUNCTION} = _round_function($args{round_style});
    $options{ROUND_STYLE} = $args{round_style};
  }

# SI compatibility (mostly for parsing)
  if ($args{si}) {
    $options{SI} = 1;
  }

# suffixes => 1024 | 1000 | si_1024 | si_1000 | 1024000 | \@
  if ($args{suffixes}) {
    if (ref $args{suffixes} eq 'ARRAY') {
      $options{SUFFIXES} = $args{suffixes};
    } elsif ($args{suffixes} =~ /^(si_)?(1000|1024)$/) {
      $options{SUFFIXES} = _default_suffixes($args{suffixes});
    } else {
      croak "suffixes ($args{suffixes}) should be 1024, 1000, si_1024, si_1000, 1024000 or an array ref";
    }
  }
  if (defined $args{unit}) {
    $options{UNIT} = $args{unit};
  }

# zero => undef | string
  if (exists $args{zero}) {
    $options{ZERO} = $args{zero};
    if (defined $options{ZERO}) {
      $options{ZERO} =~ s/%S/$options{SUFFIXES}->[0]/g
    }
  }

# precision => <integer>
  if (exists $args{precision} and $args{precision} =~ /\A\d+\z/) {
    $options{PRECISION} = $args{precision};
  }

# precision_cutoff => <intenger>
  if (exists $args{precision_cutoff} and ($args{precision_cutoff} =~ /\A\d+\z/ or $args{precision_cutoff} = '-1')) {
    $options{PRECISION_CUTOFF} = $args{precision_cutoff};
  }

# quiet => 1
  if ($args{quiet}) {
    $options{QUIET} = 1;
  }

  if (defined $seed) {
    %$seed = %options;
    return $seed;
  }
  return \%options
}

# NOTE. _format_bytes() SHOULD not change $options - NEVER.

sub _format_bytes {
  my $bytes = shift;
  return undef unless defined $bytes;
  my $options = shift;
  my %options = %$options;

  local *human_round = $options{ROUND_FUNCTION};

  return $options{ZERO} if ($bytes==0 && defined $options{ZERO});

  my $block = $options{BLOCK};

  # if a suffix set was not specified, pick a default [**]
  my @suffixes = $options{SUFFIXES} ? @{$options{SUFFIXES}} : _default_suffixes( ($options{SI} ? 'si_' : '') . $block);

  # WHAT ABOUT NEGATIVE NUMBERS: -1K ?
  my $sign = '';
  if ($bytes<0) {
     $bytes = -$bytes;
     $sign = '-';
  }

  my $suffix = $suffixes[0];
  my $x = $bytes;
  my $magnitude = 0;
  if($bytes >= $block) {
  #  return "$sign$bytes" if $bytes<$block;
    do {
      $x /= $block;
      $magnitude++;
    } while ( human_round($x, $options{PRECISION}) >= $block );
    if($magnitude >= (0 + @suffixes)) {
      carp "number too large (>= $block**$magnitude)" unless ($options{QUIET});
    }
    $suffix = $suffixes[$magnitude];
  }
  #$x = human_round( $x, $options{PRECISION} );

  $x = _precision_cutoff($x, $options);
  #reasses encase the precision_cutoff caused the value to cross the block size
  if($x >= $block) {
    $x /= $block;
    $magnitude++;
    if($magnitude >= (0 + @suffixes)) {
      carp "number too large (>= $block**$magnitude)" unless ($options{QUIET});
    }
    $suffix = $suffixes[$magnitude];
    $x = _precision_cutoff($x, $options);
  }

  my $unit = $options{UNIT} || '';

  return $sign . $x . $suffix . $unit;

}

sub _precision_cutoff {
 my $bytes   = shift;
 my $options = shift;
 my %options = %$options;
 if ( $options{PRECISION_CUTOFF} != -1 and ( length( sprintf( "%d", $bytes ) ) > $options{PRECISION_CUTOFF} ) ) {
   $bytes = sprintf( "%d", human_round( $bytes, 0 ) );
 } else {
   $bytes = sprintf( "%." . $options{PRECISION} . "f", human_round( $bytes, $options{PRECISION} ) );
 }
 return $bytes;
}

sub _parse_bytes {
  my $human = shift;
  my $options = shift;
  my %options = %$options;

  return 0 if( exists $options{ZERO} && ((!defined $options{ZERO} && !defined $human) || (defined $human && $human eq $options{ZERO})) );
  return undef unless defined $human;

  my %suffix_mult;
  my %suffix_block;
  my $m;

  if( $options{SUFFIXES} ) {
    $m = 1;
    foreach my $s (@{$options{SUFFIXES}}) {
      $suffix_mult{$s} = $m;
      $suffix_block{$s} = $options{BLOCK};
      $m *= $suffix_block{$s};
    }
  } else {
    if( !defined $options{SI} || $options{SI} == 1 ) {
      # If SI compatibility has been set BLOCK is ignored as it is infered from the unit
      $m = 1;
      foreach my $s (@{$DEFAULT_SUFFIXES{si_1000}}) {
        $suffix_mult{$s} = $m;
        $suffix_block{$s} = 1000;
        $m *= $suffix_block{$s};
      }
    
      $m = 1;
      foreach my $s (@{$DEFAULT_SUFFIXES{si_1024}}) {
        $suffix_mult{$s} = $m;
        $suffix_block{$s} = 1024;
        $m *= $suffix_block{$s};
      }
    }

    # The regular suffixes are only taken into account in default mode without specifically asking for SI compliance
    if( !defined $options{SI} ) {
      $m = 1;
      foreach my $s (_default_suffixes( $options{BLOCK} )) {
        $suffix_mult{$s} = $m;
        $suffix_block{$s} = $options{BLOCK};
        $m *= $suffix_block{$s};
      }
    }
  }

  my ($sign, $k, $unit) = ($human =~ /^\s*(-?)\s*(\d*(?:\.\d*)?)\s*(\D*)$/);

#  print STDERR "S: $sign K: $k U: $unit\n";


  my $mult;
  my $u = $options{UNIT} || '';
  foreach my $s (keys %suffix_block) {
    if( $unit =~ /^${s}${u}$/i ) {
      $mult = ($sign eq '-' ? -1 : 1) * $suffix_mult{$s};
      last;
    }
  }

  if( !defined $mult ) {
    carp "Could not parse human readable byte value '$human'";
    return undef;
  }

  my $bytes = int( $k * $mult );

  return $bytes;
}


# convert byte count (file size) to human readable format
sub format_bytes {
  my $bytes = shift;
  my $options = _parse_args(undef, @_);
  #use YAML; print Dump $options;
  return _format_bytes($bytes, $options);
}

# convert human readable format to byte count (file size)
sub parse_bytes {
  my $human = shift;
  my $options = _parse_args(undef, @_);
  #use YAML; print Dump $options;
  return _parse_bytes($human, $options);
}

### the OO way

# new()
sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $opts = _parse_args(undef, @_);
  return bless $opts, $class;
}

# set_options()
sub set_options {
  my $self = shift;
  return $self->_parse_args(@_);
}

# format()
sub format {
  my $self = shift;
  my $bytes = shift;
  return _format_bytes($bytes, $self);
}

# parse()
sub parse {
  my $self = shift;
  my $human = shift;
  return _parse_bytes($human, $self);
}

# the solution by COG in Filesys::DiskUsage
# convert size to human readable format
#sub _convert {
#  defined (my $size = shift) || return undef;
#  my $config = {@_};
#  $config->{human} || return $size;
#  my $block = $config->{'Human-readable'} ? 1000 : 1024;
#  my @args = qw/B K M G/;
#
#  while (@args && $size > $block) {
#    shift @args;
#    $size /= $block;
#  }
#
#  if ($config->{'truncate-readable'} > 0) {
#    $size = sprintf("%.$config->{'truncate-readable'}f",$size);
#  }
#
#  "$size$args[0]";
#}
#
# not exact: 1024 => 1024B instead of 1K
# not nicely formatted => 1.00 instead of 1K

1;

__END__

=head1 NAME

Number::Bytes::Human - Convert byte count to human readable format

=head1 SYNOPSIS

  use Number::Bytes::Human qw(format_bytes parse_bytes);
  $size = format_bytes(0); # '0'
  $size = format_bytes(2*1024); # '2.0K'

  $size = format_bytes(1_234_890, bs => 1000); # '1.3M'
  $size = format_bytes(1E9, bs => 1000); # '1.0G'

  my $bytes = parse_bytes('1.0K');   # 1024
  my $bytes = parse_bytes('1.0KB');  # 1000, SI unit
  my $bytes = parse_bytes('1.0KiB'); # 1024, SI unit

  # the OO way
  $human = Number::Bytes::Human->new(bs => 1000, si => 1);
  $size = $human->format(1E7); # '10MB'

  $bytes = $human->parse('10MB');   # 10*1000*1000
  $bytes = $human->parse('10MiB');  # 10*1024*1024
  $bytes = $human->parse('10M');    # Error, no SI unit

  $human->set_options(zero => '-');
  $size = $human->format(0);    # '-'
  $bytes = $human->parse('-');  # 0

  $human = Number::Bytes::Human->new(bs => 1000, round_style => 'round', precision => 2);
  $size = $human->format(10240000); # '10.24MB'

=head1 DESCRIPTION

THIS IS ALPHA SOFTWARE: THE DOCUMENTATION AND THE CODE WILL SUFFER
CHANGES SOME DAY (THANKS, GOD!).

This module provides a formatter which turns byte counts
to usual readable format, like '2.0K', '3.1G', '100B'.
It was inspired in the C<-h> option of Unix
utilities like C<du>, C<df> and C<ls> for "human-readable" output.

From the FreeBSD man page of C<df>: http://www.freebsd.org/cgi/man.cgi?query=df

  "Human-readable" output.  Use unit suffixes: Byte, Kilobyte,
  Megabyte, Gigabyte, Terabyte and Petabyte in order to reduce the
  number of digits to four or fewer using base 2 for sizes.

  byte      B
  kilobyte  K = 2**10 B = 1024 B
  megabyte  M = 2**20 B = 1024 * 1024 B
  gigabyte  G = 2**30 B = 1024 * 1024 * 1024 B
  terabyte  T = 2**40 B = 1024 * 1024 * 1024 * 1024 B

  petabyte  P = 2**50 B = 1024 * 1024 * 1024 * 1024 * 1024 B
  exabyte   E = 2**60 B = 1024 * 1024 * 1024 * 1024 * 1024 * 1024 B
  zettabyte Z = 2**70 B = 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 B
  yottabyte Y = 2**80 B = 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 B

I have found this link to be quite useful:

  http://www.t1shopper.com/tools/calculate/

If you feel like a hard-drive manufacturer, you can start
counting bytes by powers of 1000 (instead of the generous 1024).
Just use C<< bs => 1000 >>.

But if you are a floppy disk manufacturer and want to start
counting in units of 1024000 (for your "1.44 MB" disks)?
Then use C<< bs => 1_024_000 >>.

If you feel like a purist academic, you can force the use of
metric prefixes
according to the Dec 1998 standard by the IEC. Never mind the units for base 1000
are C<('B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB')> and,
even worse, the ones for base 1024 are
C<('B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB')>
with the horrible names: bytes, kibibytes, mebibytes, etc.
All you have to do is to use C<< si => 1 >>. Ain't that beautiful
the SI system? Read about it:

  http://physics.nist.gov/cuu/Units/binary.html

You can try a pure Perl C<"ls -lh">-inspired command with the one-liner, er, two-liner:

  $ perl -MNumber::Bytes::Human=format_bytes \
         -e 'printf "%5s %s\n", format_bytes(-s), $_ for @ARGV' *

Why to write such a module? Because if people can write such things
in C, it can be written much easier in Perl and then reused,
refactored, abused. And then, when it is much improved, some
brave soul can port it back to C (if only for the warm feeling
of painful programming).

It is also possible to parse human readable formatted bytes. The 
automatic format detection recognizes SI units with the blocksizes
of 1000 and 1024 respectively and additionally the customary K / M / G etc. with
blocksize 1024. When si => 1 is added to the options only SI units
are recognized. Explicitly specifying a blocksize changes it
for all detected units.

=head2 OBJECTS

An alternative to the functional style of this module
is the OO fashion. This is useful for avoiding the
unnecessary parsing of the arguments over and over
if you have to format lots of numbers


  for (@sizes) {
    my $fmt_size = format_bytes($_, @args);
    ...
  }

versus

  my $human = Number::Format::Bytes->new(@args);
  for (@sizes) {
    my $fmt_size = $human->format($_);
    ...
  }

for TODO
[TODO] MAKE IT JUST A MATTER OF STYLE: memoize _parse_args()
$seed == undef

=head2 FUNCTIONS

=over 4

=item B<format_bytes>

  $h_size = format_bytes($size, @options);

Turns a byte count (like 1230) to a readable format like '1.3K'.
You have a bunch of options to play with. See the section
L</"OPTIONS"> to know the details.

=item B<parse_bytes>

  $size = parse_bytes($h_size, @options);

Turns a human readable byte count into a number of the equivalent bytes.

=back

=head2 METHODS

=over 4

=item B<new>

  $h = Number::Bytes::Human->new(@options);

The constructor. For details on the arguments, see the section
L</"OPTIONS">.

=item B<format>

  $h_size = $h->format($size);

Turns a byte count (like 1230) to a readable format like '1.3K'.
The statements

  $h = Number::Bytes::Human->new(@options);
  $h_size = $h->format($size);

are equivalent to C<$h_size = format_bytes($size, @options)>,
with only one pass for the option arguments.

=item B<parse>

  $size = $h->parse($h_size)

Turns a human readable byte count into the number of bytes.
The statements

  $h = Number::Bytes::Human->new(@options);
  $size = $h->format($h_size);

are equivalent to C<$size = parse_bytes($h_size, @options)>,
with only one pass for the option arguments.

=item B<set_options>

  $h->set_options(@options);

To alter the options of a C<Number::Bytes::Human> object.
See L</"OPTIONS">.

=back

=head2 OPTIONS

=over 4

=item BASE

  block | base | block_size | bs => 1000 | 1024 | 1024000
  base_1024 | block_1024 | 1024 => 1
  base_1000 | block_1000 | 1000 => 1

The base to be used: 1024 (default), 1000 or 1024000.

Any other value throws an exception.

=item SUFFIXES

  suffixes => 1000 | 1024 | 1024000 | si_1000 | si_1024 | $arrayref

By default, the used suffixes stand for '', 'K', 'M', ...
for base 1024 and '', 'k', 'M', ... for base 1000
(which are indeed the usual metric prefixes with implied unit
as bytes, 'B'). For the weird 1024000 base, suffixes are
'', 'M', 'T', etc.

=item ZERO

  zero => string | undef

The string C<0> maps to ('0' by default). If C<undef>, the general case is used.
The string may contain '%S' in which case the suffix for byte is used.

  format_bytes(0, zero => '-') => '-'

=item METRIC SYSTEM

  si => 1

=item ROUND

  round_function => $coderef
  round_style => 'ceil' | 'floor' | 'round' | 'trunc'

=item TO_S

=item QUIET

  quiet => 1

Suppresses the warnings emitted. Currently, the only case is
when the number is large than C<$base**(@suffixes+1)>.

=item PRECISION

  precision => <integer>

default = 1
sets the precicion of digits, only apropreacte for round_style 'round' or if you
want to accept it in as the second parameter to your custome round_function.

=item PRECISION_CUTOFF

  precision_cutoff => <integer>

default = 1
when the number of digits exceeds this number causes the precision to be cutoff
(was default behaviour in 0.07 and below)

=back

=head2 EXPORT

It is alright to import C<format_bytes> and C<parse_bytes>, but nothing is exported by default.

=head1 DIAGNOSTICS

  "unknown round style '$style'";

  "invalid base: $block (should be 1024, 1000 or 1024000)";

  "round function ($args{round_function}) should be a code ref";

  "suffixes ($args{suffixes}) should be 1000, 1024, 1024000 or an array ref";

  "negative numbers are not allowed" (??)

=head1 SEE ALSO

F<lib/human.c> and F<lib/human.h> in GNU coreutils.

The C<_convert()> solution by COG in Filesys::DiskUsage.

=head1 BUGS

Please report bugs via Github L<https://github.com/aferreira/cpan-Number-Bytes-Human/issues>.

=head1 AUTHOR

Adriano R. Ferreira, E<lt>ferreiraE<64>cpan.orgE<gt>

Dagobert Michelsen, E<lt>dagobertE<64>cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2017 by Adriano R. Ferreira

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
