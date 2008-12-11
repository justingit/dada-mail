package Email::Find;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = "0.10";

# Need qr//.
require 5.005;

use base qw(Exporter);
@EXPORT = qw(find_emails);

use Email::Valid;
use Email::Find::addrspec;
use Mail::Address;

sub addr_regex { $Addr_spec_re }

{
    my $validator = Email::Valid->new(
	'-fudge'      => 0,
	'-fqdn'       => 1,
	'-local_rules' => 0,
	'-mxcheck'    => 0,
    );

    sub do_validate {
	my($self, $addr) = @_;
	$validator->address($addr);
    }
}

sub new {
    my($proto, $callback) = @_;
    my $class = ref $proto || $proto;
    bless { callback => $callback }, $class;
}

sub find {
    my($self, $r_text) = @_;

    my $emails_found = 0;
    my $re = $self->addr_regex;
    $$r_text =~ s{($re)}{
	my($replace, $found) = $self->validate($1);
	$emails_found += $found;
	$replace;
    }eg;
    return $emails_found;
}

sub validate {
    my($self, $orig_match) = @_;

    my $replace;
    my $found = 0;

    # XXX Add cruft handling.
    my($start_cruft) = '';
    my($end_cruft)   = '';


    if( $orig_match =~ s|([),.'";?!]+)$|| ) { #"')){
	$end_cruft = $1;
    }
    if( my $email = $self->do_validate($orig_match) ) {
	$email = Mail::Address->new('', $email);
	$found++;
	$replace = $start_cruft . $self->{callback}->($email, $orig_match) . $end_cruft;
    }
    else {
	# XXX Again with the cruft!
	$replace = $start_cruft . $orig_match . $end_cruft;
    }
    return $replace, $found;
}

# backward comaptibility
sub find_emails(\$&) {
    my($r_text, $callback) = @_;
    my $finder = __PACKAGE__->new($callback);
    $finder->find($r_text);
}

1;
__END__

=pod

=head1 NAME

Email::Find - Find RFC 822 email addresses in plain text

=head1 SYNOPSIS

  use Email::Find;

  # new object oriented interface
  my $finder = Email::Find->new(\&callback);
  my $num_found - $finder->find(\$text);

  # good old functional style
  $num_found = find_emails($text, \&callback);

=head1 DESCRIPTION

Email::Find is a module for finding a I<subset> of RFC 822 email
addresses in arbitrary text (see L</"CAVEATS">).  The addresses it
finds are not guaranteed to exist or even actually be email addresses
at all (see L</"CAVEATS">), but they will be valid RFC 822 syntax.

Email::Find will perform some heuristics to avoid some of the more
obvious red herrings and false addresses, but there's only so much
which can be done without a human.

=head1 METHODS

=over 4

=item new

  $finder = Email::Find->new(\&callback);

Constructs new Email::Find object. Specified callback will be called
with each email as they're found.

=item find

  $num_emails_found = $finder->find(\$text);

Finds email addresses in the text and executes callback registered.

The callback is given two arguments.  The first is a Mail::Address
object representing the address found.  The second is the actual
original email as found in the text.  Whatever the callback returns
will replace the original text.

=head1 FUNCTIONS

For backward compatibility, Email::Find exports one function,
find_emails(). It works very similar to URI::Find's find_uris().

=head1 EXAMPLES

  use Email::Find;

  # Simply print out all the addresses found leaving the text undisturbed.
  my $finder = Email::Find->new(sub {
				    my($email, $orig_email) = @_;
				    print "Found ".$email->format."\n";
				    return $orig_email;
				});
  $finder->find(\$text);

  # For each email found, ping its host to see if its alive.
  require Net::Ping;
  $ping = Net::Ping->new;
  my %Pinged = ();
  my $finder = Email::Find->new(sub {
  				    my($email, $orig_email) = @_;
  				    my $host = $email->host;
  				    next if exists $Pinged{$host};
  				    $Pinged{$host} = $ping->ping($host);
  				});

  $finder->find(\$text);

  while( my($host, $up) = each %Pinged ) {
      print "$host is ". $up ? 'up' : 'down' ."\n";
  }

  # Count how many addresses are found.
  my $finder = Email::Find->new(sub { $_[1] });
  print "Found ", $finder->find(\$text), " addresses\n";

  # Wrap each address in an HTML mailto link.
  my $finder = Email::Find->new(
      sub {
  	  my($email, $orig_email) = @_;
  	  my($address) = $email->format;
  	  return qq|<a href="mailto:$address">$orig_email</a>|;
      },
  );
  $finder->find(\$text);

=head1 SUBCLASSING

If you want to change the way this module works in finding email
address, you can do it by making your subclass of Email::Find, which
overrides C<addr_regex> and C<do_validate> method.

For example, the following class can additionally find email addresses
with dot before at mark. This is illegal in RFC822, see
L<Email::Valid::Loose> for details.

  package Email::Find::Loose;
  use base qw(Email::Find);
  use Email::Valid::Loose;

  # should return regex, which Email::Find will use in finding
  # strings which are "thought to be" email addresses
  sub addr_regex {
      return $Email::Valid::Loose::Addr_spec_re;
  }

  # should validate $addr is a valid email or not.
  # if so, return the address as a string.
  # else, return undef
  sub do_validate {
      my($self, $addr) = @_;
      return Email::Valid::Loose->address($addr);
  }

Let's see another example, which validates if the address is an
existent one or not, with Mail::CheckUser module.

  package Email::Find::Existent;
  use base qw(Email::Find);
  use Mail::CheckUser qw(check_email);

  sub do_validate {
      my($self, $addr) = @_;
      return check_email($addr) ? $addr : undef;
  }

=head1 CAVEATS

=over 4

=item Why a subset of RFC 822?

I say that this module finds a I<subset> of RFC 822 because if I
attempted to look for I<all> possible valid RFC 822 addresses I'd wind
up practically matching the entire block of text!  The complete
specification is so wide open that its difficult to construct
soemthing that's I<not> an RFC 822 address.

To keep myself sane, I look for the 'address spec' or 'global address'
part of an RFC 822 address.  This is the part which most people
consider to be an email address (the 'foo@bar.com' part) and it is
also the part which contains the information necessary for delivery.

=item Why are some of the matches not email addresses?

Alas, many things which aren't email addresses I<look> like email
addresses and parse just fine as them.  The biggest headache is email
and usenet and email message IDs.  I do my best to avoid them, but
there's only so much cleverness you can pack into one library.

=back

=head1 AUTHORS

Copyright 2000, 2001 Michael G Schwern E<lt>schwern@pobox.comE<gt>.
All rights reserved.

Current maintainer is Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>.

=head1 THANKS

Schwern thanks to Jeremy Howard for his patch to make it work under 5.005.

=head1 LICENSE

This module is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=for _private
After talking with a few legal people, it was found I can't restrict how
code is used, only how it is distributed.  Not without making installation
of the module annoying.  Please don't make me add the annoying installation
steps.

The author B<STRONGLY SUGGESTS> that this module not be used for the
purposes of sending unsolicited email (ie. spamming) in any way, shape
or form or for the purposes of generating lists for commercial sale.

If you use this module for spamming I reserve the right to make fun of
you.

=head1 SEE ALSO

L<Email::Valid>, RFC 822, L<URI::Find>, L<Apache::AntiSpam>,
L<Email::Valid::Loose>

=cut
