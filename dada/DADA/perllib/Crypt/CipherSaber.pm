################################################################################
#	Crypt::CipherSaber
#
#		an object oriented module implementing CipherSaber-1 and CS-2
#		encryption
#
#	copyright (c) 2001 - 2002 chromatic.  All rights reserved.
#	This program is free software; you can distribute and modify it under the
#	same terms as Perl itself.
################################################################################

package Crypt::CipherSaber;

use strict;
use Carp;
use vars qw($VERSION);

$VERSION = '0.61';

sub new {
	my $class = shift;
	my $key = shift;

	# CS-2 shuffles the state array N times, CS-1 once
	my $N = shift;
	if (!(defined $N) or ($N < 1)) {
		$N = 1;
	}
	my $self = [ $key, [ 0 .. 255 ], $N ];
	bless($self, $class);
}

sub crypt {
	my $self = shift;
	my $iv = shift;
	$self->_setup_key($iv);
	my $message = shift;
	my $state = $self->[1];
	my $output = _do_crypt($state, $message);
	$self->[1] = [ 0 .. 255 ];
	return $output;
}

sub encrypt {
	my $self = shift;
	my $iv = $self->_gen_iv();
	return $iv . $self->crypt($iv, @_);
}

sub decrypt {
	my $self = shift;
	my ($iv, $message) = unpack("a10a*", +shift);
	return $self->crypt($iv, $message);
}

sub fh_crypt {
	my $self = shift;
	my ($in, $out, $iv) = @_;

	unless(UNIVERSAL::isa($in, 'GLOB') and UNIVERSAL::isa($out, 'GLOB')) {
		carp "I need filehandles! ($in) <$out>";
		return;
	}

	local *OUT = $out;
	if (defined($iv)) {
		unless (length($iv) > 1) {
			$iv = $self->_gen_iv();
		}
		$self->_setup_key($iv);
		print OUT $iv;
	}

	my $state = $self->[1];

	my ($buf, @vars);

	while (<$in>) {
		unless ($iv) {
			($iv, $_) = unpack("a10a*", $_);
			$self->_setup_key($iv);
		}
		my $line;
		($line, $state, @vars) = _do_crypt($state, $_, @vars);
		print OUT $line if defined $line;
	}
	$self->[1] = [ 0 .. 255 ];
	return 1;
}

###################
#
# PRIVATE METHODS
#
###################
sub _gen_iv {
	my $iv;
	for (1 .. 10) {
		$iv .= chr(int(rand(256)));
	}
	return $iv;
}

sub _setup_key {
	my $self = shift;
	my $key = $self->[0] . shift;
	my @key = map { ord } split(//, $key);
	my $state = $self->[1];
	my $j = 0;
	my $length = @key;

	# repeat N times, for CS-2
	for (1 .. $self->[2]) {
		for my $i (0 .. 255) {
			$j += ($state->[$i] + ($key[$i % $length]));
			$j %= 256;
			(@$state[$i, $j]) = (@$state[$j, $i]);
		}
	}
}

sub _do_crypt {
	my ($state, $message, $i, $j, $n) = @_;

	my $output;

	for (0 .. (length($message) - 1 )) {
		$i++;
		$i %= 256;
		$j += $state->[$i];
		$j %= 256;
		@$state[$i, $j] = @$state[$j, $i];
		$n = $state->[$i] + $state->[$j];
		$n %= 256;
		$output .= chr( $state->[$n] ^ ord(substr($message, $_, 1)) );
	}

	return wantarray ? ($output, $state, $i, $j, $n) : $output;
}

1;

__END__

=head1 NAME

Crypt::CipherSaber - Perl module implementing CipherSaber encryption.

=head1 SYNOPSIS

  use Crypt::CipherSaber;
  my $cs = Crypt::CipherSaber->new('my pathetic secret key');

  my $coded = $cs->encrypt('Here is a secret message for you');
  my $decoded = $cs->decrypt($coded);

  # encrypt from and to a file
  open(INFILE, 'secretletter.txt') or die "Can't open infile: $!";
  open(OUTFILE, '>secretletter.cs1') or die "Can't open outfile: $!";
  binmode(INFILE);
  binmode(OUTFILE);
  $cs->fh_crypt(\*INFILE, \*OUTFILE, 1);

  # decrypt from and to a file
  open(INFILE, 'secretletter.cs1') or die "Can't open infile: $!";
  open(OUTFILE, '>secretletter.txt') or die "Can't open outfile: $!";
  binmode(INFILE);
  binmode(OUTFILE);
  $cs->fh_crypt(\*INFILE, \*OUTFILE);

=head1 DESCRIPTION

The Crypt::CipherSaber module implements CipherSaber encryption, described at
http://ciphersaber.gurus.com.  It is simple, fairly speedy, and relatively
secure algorithm based on RC4.

Encryption and decryption are done based on a secret key, which must be shared
with all intended recipients of a message.

=head1 METHODS

=over

=item B<new($key, $N)>

Initialize a new Crypt::CipherSaber object.  $key, the key used to encrypt or to
decrypt messages is required.  $N is optional.  If provided and greater than
one, it will implement CipherSaber-2 encryption (slightly slower but more
secure).  If not specified, or equal to 1, the module defaults to CipherSaber-1
encryption.  $N must be a positive integer greater than one.

=item B<encrypt($message)>

Encrypt a message.  This uses the key stored in the current Crypt::CipherSaber 
object.  It will generate a 10-byte random IV (Initialization Vector) 
automatically, as defined in the RC4 specification.  This returns a string 
containing the encrypted message.

Note that the encrypted message may contain unprintable characters, as it uses
the extended ASCII character set (valid numbers 0 through 255).

=item B<decrypt($message)>

Decrypt a message.  For the curious, the first ten bytes of an encrypted
message are the IV, so this must strip it off first.  This returns a string
containing the decrypted message.

The decrypted message may also contain unprintable characters, as the
CipherSaber encryption scheme can handle binary files with fair ease.  If this
is important to you, be sure to treat the results correctly.

=item B<crypt($iv, $message)>

If you wish to generate the IV with a more cryptographically secure random
string (at least compared to Perl's builtin rand() function), you may do so
separately, passing it to this method directly.  The IV must be a ten-byte
string consisting of characters from the extended ASCII set.

This is generally only useful for encryption, although you may extract the
first ten characters of an encrypted message and pass them in yourself.  You
might as well call B<decrypt()>, though.  The more random the IV, the stronger
the encryption tends to be.  On some operating systems, you can read from
/dev/random.  Other approaches are the Math::TrulyRandom module, or compressing
a file, removing the headers, and compressing it again.

=item B<fh_crypt(\*INPUT, \*OUTPUT, ($iv))>

For the sake of efficiency, Crypt::CipherSaber can now operate on filehandles.
It's not super brilliant, but it's relatively fast and sane.  Pass in a
reference to the input file handle and the output filehandle.  If your platform
needs to use C<binmode()>, this is your responsibility.  It is also your
responsibility to close the files.

You may also pass in an optional third parameter, an IV.  There are three
possibilities here.  If you pass no IV, C<fh_crypt()> will pull the first ten
bytes from *INPUT and use that as an IV.  This corresponds to decryption.  If
you pass in an IV of your own (generally ten digits, but more than one digits
as the code is now), it will use your own IV when encrypting the file.  If you
pass in the value '1', it will generate a new, random IV for you.  This
corresponds to an encryption.

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2000 - 2001 chromatic

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

chromatic <chromatic@wgz.org>

thanks to jlp for testing, moral support, and never fearing the icky details
and to the fine folks at http://perlmonks.org

Additional thanks to Olivier Salaun and the Sympa project (http://www.sympa.org)
for testing.

=head1 SEE ALSO

the CipherSaber home page at http://ciphersaber.gurus.com

perl(1), rand().

=cut
