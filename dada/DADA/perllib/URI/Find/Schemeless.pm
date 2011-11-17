# Copyright (c) 2000, 2009 Michael G. Schwern.  All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package URI::Find::Schemeless;

use strict;
use base qw(URI::Find);

# base.pm error in 5.005_03 prevents it from loading URI::Find if I'm
# required first.
use URI::Find ();

use vars qw($VERSION);
$VERSION = 20111103;

my($dnsSet) = 'A-Za-z0-9-';

my($cruftSet) = __PACKAGE__->cruft_set . '<>?}';

my($tldRe) = __PACKAGE__->top_level_domain_re;

my($uricSet) = __PACKAGE__->uric_set;

=head1 NAME

URI::Find::Schemeless - Find schemeless URIs in arbitrary text.


=head1 SYNOPSIS

  require URI::Find::Schemeless;

  my $finder = URI::Find::Schemeless->new(\&callback);

  The rest is the same as URI::Find.


=head1 DESCRIPTION

URI::Find finds absolute URIs in plain text with some weak heuristics
for finding schemeless URIs.  This subclass is for finding things
which might be URIs in free text.  Things like "www.foo.com" and
"lifes.a.bitch.if.you.aint.got.net".

The heuristics are such that it hopefully finds a minimum of false
positives, but there's no easy way for it know if "COMMAND.COM" refers
to a web site or a file.

=cut

sub schemeless_uri_re {
    @_ == 1 || __PACKAGE__->badinvo;
    return qr{
              # Originally I constrained what couldn't be before the match
              # like this:  don't match email addresses, and don't start
              # anywhere but at the beginning of a host name
              #    (?<![\@.$dnsSet])
              # but I switched to saying what can be there after seeing a
              # false match of "Lite.pm" via "MIME/Lite.pm".
              (?: ^ | (?<=[\s<>()\{\}\[\]]) )
              # hostname
              (?: [$dnsSet]+(?:\.[$dnsSet]+)*\.$tldRe
                  | (?:\d{1,3}\.){3}\d{1,3} ) # not inet_aton() complete
              (?:
                  (?=[\s\Q$cruftSet\E]) # followed by unrelated thing
                  (?!\.\w)              #   but don't stop mid foo.xx.bar
                      (?<!\.p[ml])      #   but exclude Foo.pm and Foo.pl
                  |$                    # or end of line
                      (?<!\.p[ml])      #   but exclude Foo.pm and Foo.pl
                  |/[$uricSet#]*        # or slash and URI chars
              )
           }x;
}

=head3 top_level_domain_re

  my $tld_re = $self->top_level_domain_re;

Returns the regex for matching top level DNS domains.  The regex shouldn't
be anchored, it shouldn't do any capturing matches, and it should make
itself ignore case.

=cut

sub top_level_domain_re {
    @_ == 1 || __PACKAGE__->badinvo;
    my($self) = shift;

    # Updated from http://www.iana.org/domains/root/db/
    my $plain = join '|', qw(
        AERO
        ARPA
        ASIA
        BIZ
        CAT
        COM
        COOP
        EDU
        GOV
        INFO
        INT
        JOBS
        MIL
        MOBI
        MUSEUM
        NAME
        NET
        ORG
        PRO
        TEL
        TRAVEL
    );

    return qr/(?:[a-z]{2}|$plain)/i;
}

=head1 AUTHOR

Original code by Roderick Schertler <roderick@argon.org>, adapted by
Michael G Schwern <schwern@pobox.com>.

Currently maintained by Roderick Schertler <roderick@argon.org>.

=head1 SEE ALSO

  L<URI::Find>

=cut

1;
