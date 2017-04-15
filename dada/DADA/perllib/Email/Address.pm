package Email::Address;
use strict;
## no critic RequireUseWarnings
# support pre-5.6

use vars qw[$VERSION $COMMENT_NEST_LEVEL $STRINGIFY
            $COLLAPSE_SPACES
            %PARSE_CACHE %FORMAT_CACHE %NAME_CACHE
            $addr_spec $angle_addr $name_addr $mailbox];

my $NOCACHE;

$VERSION              = '1.889';
$COMMENT_NEST_LEVEL ||= 2;
$STRINGIFY          ||= 'format';
$COLLAPSE_SPACES      = 1 unless defined $COLLAPSE_SPACES; # who wants //=? me!

=head1 NAME

Email::Address - RFC 2822 Address Parsing and Creation

=head1 SYNOPSIS

  use Email::Address;

  my @addresses = Email::Address->parse($line);
  my $address   = Email::Address->new(Casey => 'casey@localhost');

  print $address->format;

=head1 VERSION

version 1.886

 $Id: Address.pm 881 2007-12-19 22:08:35Z rjbs@cpan.org $

=head1 DESCRIPTION

This class implements a regex-based RFC 2822 parser that locates email
addresses in strings and returns a list of C<Email::Address> objects found.
Alternatley you may construct objects manually. The goal of this software is to
be correct, and very very fast.

=cut

my $CTL            = q{\x00-\x1F\x7F};
my $special        = q{()<>\\[\\]:;@\\\\,."};

my $text           = qr/[^\x0A\x0D]/;

my $quoted_pair    = qr/\\$text/;

my $ctext          = qr/(?>[^()\\]+)/;
my ($ccontent, $comment) = (q{})x2;
for (1 .. $COMMENT_NEST_LEVEL) {
  $ccontent = qr/$ctext|$quoted_pair|$comment/;
  $comment  = qr/\s*\((?:\s*$ccontent)*\s*\)\s*/;
}
my $cfws           = qr/$comment|\s+/;

my $atext          = qq/[^$CTL$special\\s]/;
my $atom           = qr/$cfws*$atext+$cfws*/;
my $dot_atom_text  = qr/$atext+(?:\.$atext+)*/;
my $dot_atom       = qr/$cfws*$dot_atom_text$cfws*/;

my $qtext          = qr/[^\\"]/;
my $qcontent       = qr/$qtext|$quoted_pair/;
my $quoted_string  = qr/$cfws*"$qcontent+"$cfws*/;

my $word           = qr/$atom|$quoted_string/;

# XXX: This ($phrase) used to just be: my $phrase = qr/$word+/; It was changed
# to resolve bug 22991, creating a significant slowdown.  Given current speed
# problems.  Once 16320 is resolved, this section should be dealt with.
# -- rjbs, 2006-11-11
#my $obs_phrase     = qr/$word(?:$word|\.|$cfws)*/;

# XXX: ...and the above solution caused endless problems (never returned) when
# examining this address, now in a test:
#   admin+=E6=96=B0=E5=8A=A0=E5=9D=A1_Weblog-- ATAT --test.socialtext.com
# So we disallow the hateful CFWS in this context for now.  Of modern mail
# agents, only Apple Web Mail 2.0 is known to produce obs-phrase.
# -- rjbs, 2006-11-19
my $simple_word    = qr/$atom|\.|\s*"$qcontent+"\s*/;
my $obs_phrase     = qr/$simple_word+/;

my $phrase         = qr/$obs_phrase|(?:$word+)/;

my $local_part     = qr/$dot_atom|$quoted_string/;
my $dtext          = qr/[^\[\]\\]/;
my $dcontent       = qr/$dtext|$quoted_pair/;
my $domain_literal = qr/$cfws*\[(?:\s*$dcontent)*\s*\]$cfws*/;
my $domain         = qr/$dot_atom|$domain_literal/;

my $display_name   = $phrase;

=head2 Package Variables

Several regular expressions used in this package are useful to others.
For convenience, these variables are declared as package variables that
you may access from your program.

These regular expressions conform to the rules specified in RFC 2822.

You can access these variables using the full namespace. If you want
short names, define them yourself.

  my $addr_spec = $Email::Address::addr_spec;

=over 4

=item $Email::Address::addr_spec

This regular expression defined what an email address is allowed to
look like.

=item $Email::Address::angle_addr

This regular expression defines an C<$addr_spec> wrapped in angle
brackets.

=item $Email::Address::name_addr

This regular expression defines what an email address can look like
with an optional preceeding display name, also known as the C<phrase>.

=item $Email::Address::mailbox

This is the complete regular expression defining an RFC 2822 emial
address with an optional preceeding display name and optional
following comment.

=back

=cut

$addr_spec  = qr/$local_part\@$domain/;
$angle_addr = qr/$cfws*<$addr_spec>$cfws*/;
$name_addr  = qr/$display_name?$angle_addr/;
$mailbox    = qr/(?:$name_addr|$addr_spec)$comment*/;

sub _PHRASE   () { 0 }
sub _ADDRESS  () { 1 }
sub _COMMENT  () { 2 }
sub _ORIGINAL () { 3 }
sub _IN_CACHE () { 4 }

=head2 Class Methods

=over 4

=item parse

  my @addrs = Email::Address->parse(
    q[me@local, Casey <me@local>, "Casey" <me@local> (West)]
  );

This method returns a list of C<Email::Address> objects it finds
in the input string.

The specification for an email address allows for infinitley
nestable comments. That's nice in theory, but a little over done.
By default this module allows for two (C<2>) levels of nested
comments. If you think you need more, modify the
C<$Email::Address::COMMENT_NEST_LEVEL> package variable to allow
more.

  $Email::Address::COMMENT_NEST_LEVEL = 10; # I'm deep

The reason for this hardly limiting limitation is simple: efficiency.

Long strings of whitespace can be problematic for this module to parse, a bug
which has not yet been adequately addressed.  The default behavior is now to
collapse multiple spaces into a single space, which avoids this problem.  To
prevent this behavior, set C<$Email::Address::COLLAPSE_SPACES> to zero.  This
variable will go away when the bug is resolved properly.

=cut

sub __get_cached_parse {
    return if $NOCACHE;

    my ($class, $line) = @_;

    return @{$PARSE_CACHE{$line}} if exists $PARSE_CACHE{$line};
    return; 
}

sub __cache_parse {
    return if $NOCACHE;
    
    my ($class, $line, $addrs) = @_;

    $PARSE_CACHE{$line} = $addrs;
}

sub parse {
    my ($class, $line) = @_;
    return unless $line;

    $line =~ s/[ \t]+/ /g if $COLLAPSE_SPACES;

    if (my @cached = $class->__get_cached_parse($line)) {
        return @cached;
    }

    my (@mailboxes) = ($line =~ /$mailbox/go);
    my @addrs;
    foreach (@mailboxes) {
      my $original = $_;

      my @comments = /($comment)/go;
      s/$comment//go if @comments;

      my ($user, $host, $com);
      ($user, $host) = ($1, $2) if s/<($local_part)\@($domain)>//o;
      if (! defined($user) || ! defined($host)) {
          s/($local_part)\@($domain)//o;
          ($user, $host) = ($1, $2);
      }

      my ($phrase)       = /($display_name)/o;

      for ( $phrase, $host, $user, @comments ) {
        next unless defined $_;
        s/^\s+//;
        s/\s+$//;
        $_ = undef unless length $_;
      }

      my $new_comment = join q{ }, @comments;
      push @addrs,
        $class->new($phrase, "$user\@$host", $new_comment, $original);
      $addrs[-1]->[_IN_CACHE] = [ \$line, $#addrs ]
    }

    $class->__cache_parse($line, \@addrs);
    return @addrs;
}

=pod

=item new

  my $address = Email::Address->new(undef, 'casey@local');
  my $address = Email::Address->new('Casey West', 'casey@local');
  my $address = Email::Address->new(undef, 'casey@local', '(Casey)');

Constructs and returns a new C<Email::Address> object. Takes four
positional arguments: phrase, email, and comment, and original string.

The original string should only really be set using C<parse>.

=cut

sub new {
  my ($class, $phrase, $email, $comment, $orig) = @_;
  $phrase =~ s/\A"(.+)"\z/$1/ if $phrase;

  bless [ $phrase, $email, $comment, $orig ] => $class;
}

=pod

=item purge_cache

  Email::Address->purge_cache;

One way this module stays fast is with internal caches. Caches live
in memory and there is the remote possibility that you will have a
memory problem. In the off chance that you think you're one of those
people, this class method will empty those caches.

I've loaded over 12000 objects and not encountered a memory problem.

=cut

sub purge_cache {
    %NAME_CACHE   = ();
    %FORMAT_CACHE = ();
    %PARSE_CACHE  = ();
}

=item disable_cache

=item enable_cache

  Email::Address->disable_cache if memory_low();

If you'd rather not cache address parses at all, you can disable (and reenable) the Email::Address cache with these methods.  The cache is enabled by default.

=cut

sub disable_cache {
  my ($class) = @_;
  $class->purge_cache;
  $NOCACHE = 1;
}

sub enable_cache {
  $NOCACHE = undef;
}

=pod

=back

=head2 Instance Methods

=over 4

=item phrase

  my $phrase = $address->phrase;
  $address->phrase( "Me oh my" );

Accessor and mutator for the phrase portion of an address.

=item address

  my $addr = $address->address;
  $addr->address( "me@PROTECTED.com" );

Accessor and mutator for the address portion of an address.

=item comment

  my $comment = $address->comment;
  $address->comment( "(Work address)" );

Accessor and mutator for the comment portion of an address.

=item original

  my $orig = $address->original;

Accessor for the original address found when parsing, or passed
to C<new>.

=item host

  my $host = $address->host;

Accessor for the host portion of an address's address.

=item user

  my $user = $address->user;

Accessor for the user portion of an address's address.

=cut

BEGIN {
  my %_INDEX = (
    phrase   => _PHRASE,
    address  => _ADDRESS,
    comment  => _COMMENT,
    original => _ORIGINAL,
  );

  for my $method (keys %_INDEX) {
    no strict 'refs';
    my $index = $_INDEX{ $method };
    *$method = sub {
      if ($_[1]) {
        if ($_[0][_IN_CACHE]) {
          my $replicant = bless [ @{$_[0]} ] => ref $_[0];
          $PARSE_CACHE{ ${ $_[0][_IN_CACHE][0] } }[ $_[0][_IN_CACHE][1] ] 
            = $replicant;
          $_[0][_IN_CACHE] = undef;
        }
        $_[0]->[ $index ] = $_[1];
      } else {
        $_[0]->[ $index ];
      }
    };
  }
}

sub host { ($_[0]->[_ADDRESS] =~ /\@($domain)/o)[0]     }
sub user { ($_[0]->[_ADDRESS] =~ /($local_part)\@/o)[0] }

=pod

=item format

  my $printable = $address->format;

Returns a properly formatted RFC 2822 address representing the
object.

=cut

sub format {
    local $^W = 0; ## no critic
    return $FORMAT_CACHE{"@{$_[0]}"} if exists $FORMAT_CACHE{"@{$_[0]}"};
    $FORMAT_CACHE{"@{$_[0]}"} = $_[0]->_format;
}

sub _format {
    my ($self) = @_;

    unless (
      defined $self->[_PHRASE] && length $self->[_PHRASE]
      ||
      defined $self->[_COMMENT] && length $self->[_COMMENT]
    ) {
        return $self->[_ADDRESS];
    }

    my $format = sprintf q{%s <%s> %s},
                 $self->_enquoted_phrase, $self->[_ADDRESS], $self->[_COMMENT];

    $format =~ s/^\s+//;
    $format =~ s/\s+$//;

    return $format;
}

sub _enquoted_phrase {
  my ($self) = @_;

  my $phrase = $self->[_PHRASE];

  # if it's encoded -- rjbs, 2007-02-28
  return $phrase if $phrase =~ /\A=\?.+\?=\z/;

  $phrase =~ s/\A"(.+)"\z/$1/;
  $phrase =~ s/\"/\\"/g;

  return qq{"$phrase"};
}

=pod

=item name

  my $name = $address->name;

This method tries very hard to determine the name belonging to the address.
First the C<phrase> is checked. If that doesn't work out the C<comment>
is looked into. If that still doesn't work out, the C<user> portion of
the C<address> is returned.

This method does B<not> try to massage any name it identifies and instead
leaves that up to someone else. Who is it to decide if someone wants their
name capitalized, or if they're Irish?

=cut

sub name {
    local $^W = 0;
    return $NAME_CACHE{"@{$_[0]}"} if exists $NAME_CACHE{"@{$_[0]}"};
    my ($self) = @_;
    my $name = q{};
    if ( $name = $self->[_PHRASE] ) {
        $name =~ s/^"//;
        $name =~ s/"$//;
        $name =~ s/($quoted_pair)/substr $1, -1/goe;
    } elsif ( $name = $self->[_COMMENT] ) {
        $name =~ s/^\(//;
        $name =~ s/\)$//;
        $name =~ s/($quoted_pair)/substr $1, -1/goe;
        $name =~ s/$comment/ /go;
    } else {
        ($name) = $self->[_ADDRESS] =~ /($local_part)\@/o;
    }
    $NAME_CACHE{"@{$_[0]}"} = $name;
}

=pod

=back

=head2 Overloaded Operators

=over 4

=item stringify

  print "I have your email address, $address.";

Objects stringify to C<format> by default. It's possible that you don't
like that idea. Okay, then, you can change it by modifying
C<$Email:Address::STRINGIFY>. Please consider modifying this package
variable using C<local>. You might step on someone else's toes if you
don't.

  {
    local $Email::Address::STRINGIFY = 'address';
    print "I have your address, $address.";
    #   geeknest.com
  }
  print "I have your address, $address.";
  #   "Casey West" <casey@geeknest.com>

=cut

sub as_string {
  warn 'altering $Email::Address::STRINGIFY is deprecated; subclass instead'
    if $STRINGIFY ne 'format';

  $_[0]->can($STRINGIFY)->($_[0]);
}

use overload '""' => 'as_string';

=pod

=back

=cut

1;

__END__

=head2 Did I Mention Fast?

On his 1.8GHz Apple MacBook, rjbs gets these results:

  $ perl -Ilib bench/ea-vs-ma.pl bench/corpus.txt 5 
                   Rate  Mail::Address Email::Address
  Mail::Address  2.59/s             --           -44%
  Email::Address 4.59/s            77%             --

  $ perl -Ilib bench/ea-vs-ma.pl bench/corpus.txt 25
                   Rate  Mail::Address Email::Address
  Mail::Address  2.58/s             --           -67%
  Email::Address 7.84/s           204%             --

  $ perl -Ilib bench/ea-vs-ma.pl bench/corpus.txt 50
                   Rate  Mail::Address Email::Address
  Mail::Address  2.57/s             --           -70%
  Email::Address 8.53/s           232%             --

...unfortunately, a known bug causes a loss of speed the string to parse has
certain known characteristics, and disabling cache will also degrade
performance.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::Address>

=head1 SEE ALSO

L<Email::Simple>, L<perl>.

=head1 AUTHOR

Originally by Casey West, <F<casey@geeknest.com>>.

Maintained, 2006-2007, Ricardo SIGNES <F<rjbs@cpan.org>>.

=head1 ACKNOWLEDGEMENTS

Thanks to Kevin Riggle and Tatsuhiko Miyagawa for tests for annoying phrase-quoting bugs!

=head1 COPYRIGHT

Copyright (c) 2004 Casey West.  All rights reserved.  This module is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

