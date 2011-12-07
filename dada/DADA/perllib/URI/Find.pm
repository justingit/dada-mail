# Copyright (c) 2000, 2009 Michael G. Schwern.  All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package URI::Find;

require 5.006;

use strict;
use base qw(Exporter);
use vars qw($VERSION @EXPORT);

$VERSION        = 20111103;
@EXPORT         = qw(find_uris);

use constant YES => (1==1);
use constant NO  => !YES;

use Carp        qw(croak);
use URI::URL;

require URI;

# URI scheme pattern without the non-alpha numerics.
# Those are extremely uncommon and interfere with the match.
my($schemeRe) = qr/[a-zA-Z][a-zA-Z0-9]*/;
my($uricSet)  = $URI::uric;

# We need to avoid picking up 'HTTP::Request::Common' so we have a
# subset of uric without a colon ("I have no colon and yet I must poop")
my($uricCheat) = __PACKAGE__->uric_set;
$uricCheat =~ tr/://d;

# Identifying characters accidentally picked up with a URI.
my($cruftSet) = q{]),.'";}; #'#


=head1 NAME

URI::Find - Find URIs in arbitrary text

=head1 SYNOPSIS

  require URI::Find;

  my $finder = URI::Find->new(\&callback);

  $how_many_found = $finder->find(\$text);

=head1 DESCRIPTION

This module does one thing: Finds URIs and URLs in plain text.  It finds
them quickly and it finds them B<all> (or what URI::URL considers a URI
to be.)  It only finds URIs which include a scheme (http:// or the
like), for something a bit less strict have a look at
L<URI::Find::Schemeless|URI::Find::Schemeless>.

For a command-line interface, L<urifind> is provided.

=head2 Public Methods

=over 4

=item B<new>

  my $finder = URI::Find->new(\&callback);

Creates a new URI::Find object.

&callback is a function which is called on each URI found.  It is
passed two arguments, the first is a URI::URL object representing the
URI found.  The second is the original text of the URI found.  The
return value of the callback will replace the original URI in the
text.

=cut

sub new {
    @_ == 2 || __PACKAGE__->badinvo;
    my($proto, $callback) = @_;
    my($class) = ref $proto || $proto;
    my $self = bless {}, $class;

    $self->{callback} = $callback;

    return $self;
}

=item B<find>

  my $how_many_found = $finder->find(\$text);

$text is a string to search and possibly modify with your callback.

Alternatively, C<find> can be called with a replacement function for
the rest of the text:

  use CGI qw(escapeHTML);
  # ...
  my $how_many_found = $finder->find(\$text, \&escapeHTML);

will not only call the callback function for every URL found (and
perform the replacement instructions therein), but also run the rest
of the text through C<escapeHTML()>. This makes it easier to turn
plain text which contains URLs into HTML (see example below).

=cut

sub find {
    @_ == 2 || @_ == 3 || __PACKAGE__->badinvo;
    my($self, $r_text, $escape_func) = @_;

    # Might be slower, but it makes the code simpler
    $escape_func ||= sub { return $_[0] };

    # Store the escape func in the object temporarily for use
    # by other methods.
    local $self->{escape_func} = $escape_func;

    $self->{_uris_found} = 0;

    # Yes, evil.  Basically, look for something vaguely resembling a URL,
    # then hand it off to URI::URL for examination.  If it passes, throw
    # it to a callback and put the result in its place.
    local $SIG{__DIE__} = 'DEFAULT';
    my $uri_cand;
    my $uri;

    my $uriRe = sprintf '(?:%s|%s)', $self->uri_re, $self->schemeless_uri_re;

    $$r_text =~ s{ (.*?) (?:(<(?:URL:)?)(.+?)(>)|($uriRe)) | (.+?)$ }{
        my $replace = '';
        if( defined $6 ) {
            $replace = $escape_func->($6);
        }
        else {
            my $maybe_uri = '';

            $replace = $escape_func->($1) if length $1;

            if( defined $2 ) {
                $maybe_uri = $3;
                my $is_uri = do {  # Don't alter $1...
                    $maybe_uri =~ s/\s+//g;
                    $maybe_uri =~ /^$uriRe/;
                };

                if( $is_uri ) {
                    $replace .= $escape_func->($2);
                    $replace .= $self->_uri_filter($maybe_uri);
                    $replace .= $escape_func->($4);
                }
                else {
                    # the whole text inside of the <...> was not a url, but
                    # maybe it has a url (like an HTML <a> link)
                    my $has_uri = do { # Don't alter $1...
                        $maybe_uri = $3;
                        $maybe_uri =~ /$uriRe/;
                    };
                    if( $has_uri ) {
                        my $pre = $2;
                        my $post = $4;
                        do { $self->find(\$maybe_uri, $escape_func) };
                        $replace .= $escape_func->($pre);
                        $replace .= $maybe_uri;  # already escaped by find()
                        $replace .= $escape_func->($post);
                    }
                    else {
                        $replace .= $escape_func->($2.$3.$4);
                    }
                }
            }
            else {
                $replace .= $self->_uri_filter($5);
            }
        }

        $replace;
    }gsex;

    return $self->{_uris_found};
}


sub _uri_filter {
    my($self, $orig_match) = @_;

    # A heuristic.  Often you'll see things like:
    # "I saw this site, http://www.foo.com, and its really neat!"
    # or "Foo Industries (at http://www.foo.com)"
    # We want to avoid picking up the trailing paren, period or comma.
    # Of course, this might wreck a perfectly valid URI, more often than
    # not it corrects a parse mistake.
    $orig_match = $self->decruft($orig_match);

    my $replacement = '';
    if( my $uri = $self->_is_uri(\$orig_match) ) {
        # It's a URI
        $self->{_uris_found}++;
        $replacement = $self->{callback}->($uri, $orig_match);
    }
    else {
        # False alarm
        $replacement = $self->{escape_func}->($orig_match);
    }

    # Return recrufted replacement
    return $self->recruft($replacement);
}


=back

=head2 Protected Methods

I got a bunch of mail from people asking if I'd add certain features
to URI::Find.  Most wanted the search to be less restrictive, do more
heuristics, etc...  Since many of the requests were contradictory, I'm
letting people create their own custom subclasses to do what they
want.

The following are methods internal to URI::Find which a subclass can
override to change the way URI::Find acts.  They are only to be called
B<inside> a URI::Find subclass.  Users of this module are NOT to use
these methods.

=over

=item B<uri_re>

  my $uri_re = $self->uri_re;

Returns the regex for finding absolute, schemed URIs
(http://www.foo.com and such).  This, combined with
schemeless_uri_re() is what finds candidate URIs.

Usually this method does not have to be overridden.

=cut

sub uri_re {
    @_ == 1 || __PACKAGE__->badinvo;
    my($self) = shift;
    return sprintf '%s:[%s][%s#]*', $schemeRe,
                                    $uricCheat,
                                    $self->uric_set;
}

=item B<schemeless_uri_re>

  my $schemeless_re = $self->schemeless_uri_re;

Returns the regex for finding schemeless URIs (www.foo.com and such) and
other things which might be URIs.  By default this will match nothing
(though it used to try to find schemeless URIs which started with C<www>
and C<ftp>).

Many people will want to override this method.  See L<URI::Find::Schemeless>
for a subclass does a reasonable job of finding URIs which might be missing
the scheme.

=cut

sub schemeless_uri_re {
    @_ == 1 || __PACKAGE__->badinvo;
    my($self) = shift;
    return qr/\b\B/; # match nothing
}

=item B<uric_set>

  my $uric_set = $self->uric_set;

Returns a set matching the 'uric' set defined in RFC 2396 suitable for
putting into a character set ([]) in a regex.

You almost never have to override this.

=cut

sub uric_set {
    @_ == 1 || __PACKAGE__->badinvo;
    return $uricSet;
}

=item B<cruft_set>

  my $cruft_set = $self->cruft_set;

Returns a set of characters which are considered garbage.  Used by
decruft().

=cut

sub cruft_set {
    @_ == 1 || __PACKAGE__->badinvo;
    return $cruftSet;
}

=item B<decruft>

  my $uri = $self->decruft($uri);

Sometimes garbage characters like periods and parenthesis get
accidentally matched along with the URI.  In order for the URI to be
properly identified, it must sometimes be "decrufted", the garbage
characters stripped.

This method takes a candidate URI and strips off any cruft it finds.

=cut

sub decruft {
    @_ == 2 || __PACKAGE__->badinvo;
    my($self, $orig_match) = @_;

    $self->{start_cruft} = '';
    $self->{end_cruft} = '';

    if( $orig_match =~ s/([\Q$cruftSet\E]+)$// ) {
        # urls can end with HTML entities if found in HTML so let's put back semicolons
        # if this looks like the case
        my $cruft = $1;
        if( $cruft =~ /^;/ && $orig_match =~ /\&(\#[1-9]\d{1,3}|[a-zA-Z]{2,8})$/) {
            $orig_match .= ';';
            $cruft =~ s/^;//;
        }

        my $opening = $orig_match =~ tr/(/(/;
        my $closing = $orig_match =~ tr/)/)/;
        if ( $cruft =~ /\)$/ && $opening == ( $closing + 1 ) ) {
            $orig_match .= ')';
            $cruft =~ s/\)$//;
        }

        $self->{end_cruft} = $cruft if $cruft;
    }

    return $orig_match;
}

=item B<recruft>

  my $uri = $self->recruft($uri);

This method puts back the cruft taken off with decruft().  This is necessary
because the cruft is destructively removed from the string before invoking
the user's callback, so it has to be put back afterwards.

=cut

#'#

sub recruft {
    @_ == 2 || __PACKAGE__->badinvo;
    my($self, $uri) = @_;

    return $self->{start_cruft} . $uri . $self->{end_cruft};
}

=item B<schemeless_to_schemed>

  my $schemed_uri = $self->schemeless_to_schemed($schemeless_uri);

This takes a schemeless URI and returns an absolute, schemed URI.  The
standard implementation supplies ftp:// for URIs which start with ftp.,
and http:// otherwise.

=cut

sub schemeless_to_schemed {
    @_ == 2 || __PACKAGE__->badinvo;
    my($self, $uri_cand) = @_;

    $uri_cand =~ s|^(<?)ftp\.|$1ftp://ftp\.|
        or $uri_cand =~ s|^(<?)|${1}http://|;

    return $uri_cand;
}

=item B<is_schemed>

  $obj->is_schemed($uri);

Returns whether or not the given URI is schemed or schemeless.  True for
schemed, false for schemeless.

=cut

sub is_schemed {
    @_ == 2 || __PACKAGE__->badinvo;
    my($self, $uri) = @_;
    return scalar $uri =~ /^<?$schemeRe:/;
}

=item I<badinvo>

  __PACKAGE__->badinvo($extra_levels, $msg)

This is used to complain about bogus subroutine/method invocations.
The args are optional.

=cut

sub badinvo {
    my $package = shift;
    my $level   = @_ ? shift : 0;
    my $msg     = @_ ? " (" . shift() . ")" : '';
    my $subname = (caller $level + 1)[3];
    croak "Bogus invocation of $subname$msg";
}

=back

=head2 Old Functions

The old find_uri() function is still around and it works, but its
deprecated.

=cut

# Old interface.
sub find_uris (\$&) {
    @_ == 2 || __PACKAGE__->badinvo;
    my($r_text, $callback) = @_;

    my $self = __PACKAGE__->new($callback);
    return $self->find($r_text);
}


=head1 EXAMPLES

Store a list of all URIs (normalized) in the document.

  my @uris;
  my $finder = URI::Find->new(sub {
      my($uri) = shift;
      push @uris, $uri;
  });
  $finder->find(\$text);

Print the original URI text found and the normalized representation.

  my $finder = URI::Find->new(sub {
      my($uri, $orig_uri) = @_;
      print "The text '$orig_uri' represents '$uri'\n";
      return $orig_uri;
  });
  $finder->find(\$text);

Check each URI in document to see if it exists.

  use LWP::Simple;

  my $finder = URI::Find->new(sub {
      my($uri, $orig_uri) = @_;
      if( head $uri ) {
          print "$orig_uri is okay\n";
      }
      else {
          print "$orig_uri cannot be found\n";
      }
      return $orig_uri;
  });
  $finder->find(\$text);


Turn plain text into HTML, with each URI found wrapped in an HTML anchor.

  use CGI qw(escapeHTML);
  use URI::Find;

  my $finder = URI::Find->new(sub {
      my($uri, $orig_uri) = @_;
      return qq|<a href="$uri">$orig_uri</a>|;
  });
  $finder->find(\$text, \&escapeHTML);
  print "<pre>$text</pre>";

=cut


sub _is_uri {
    @_ == 2 || __PACKAGE__->badinvo;
    my($self, $r_uri_cand) = @_;

    my $uri = $$r_uri_cand;

    # Translate schemeless to schemed if necessary.
    $uri = $self->schemeless_to_schemed($uri) if
      $uri =~ $self->schemeless_uri_re   and
      $uri !~ /^<?$schemeRe:/;

    # Set strict to avoid bogus schemes
    my $old_strict = URI::URL::strict(1);

    eval {
        $uri = URI::URL->new($uri);
    };

    # And restore it
    URI::URL::strict($old_strict);

    if($@ || !defined $uri) {   # leave everything untouched, its not a URI.
        return NO;
    }
    else {                      # Its a URI.
        return $uri;
    }
}


=head1 NOTES

Will not find URLs with Internationalized Domain Names or pretty much
any non-ascii stuff in them.  See
L<http://rt.cpan.org/Ticket/Display.html?id=44226>


=head1 AUTHOR

Michael G Schwern <schwern@pobox.com> with insight from Uri Gutman,
Greg Bacon, Jeff Pinyan, Roderick Schertler and others.

Roderick Schertler <roderick@argon.org> maintained versions 0.11 to 0.16.

Darren Chamberlain wrote urifind.


=head1 LICENSE

Copyright 2000, 2009-2010 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See F<http://www.perlfoundation.org/artistic_license_1_0>

=head1 SEE ALSO

L<urifind>, L<URI::Find::Schemeless>, L<URI::URL>, L<URI>,
RFC 3986 Appendix C

=cut

1;
