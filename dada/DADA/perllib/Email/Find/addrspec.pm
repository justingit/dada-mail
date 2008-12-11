package Email::Find::addrspec;

use strict;
use vars qw($VERSION @EXPORT $Addr_spec_re);
$VERSION = 0.09;

use base qw(Exporter);
@EXPORT = qw($Addr_spec_re);

# This is the BNF from RFC 822
my $esc         = '\\\\';
my $period      = '\.';
my $space       = '\040';
my $open_br     = '\[';
my $close_br    = '\]';
my $nonASCII    = '\x80-\xff';
my $ctrl        = '\000-\037';
my $cr_list     = '\n\015';
my $qtext       = qq/[^$esc$nonASCII$cr_list\"]/; #"
my $dtext       = qq/[^$esc$nonASCII$cr_list$open_br$close_br]/;
my $quoted_pair = qq<$esc>.qq<[^$nonASCII]>;
my $atom_char   = qq/[^($space)<>\@,;:\".$esc$open_br$close_br$ctrl$nonASCII]/; #"
my $atom        = qq<$atom_char+(?!$atom_char)>;
my $quoted_str  = qq<\"$qtext*(?:$quoted_pair$qtext*)*\">; #"
my $word        = qq<(?:$atom|$quoted_str)>;
my $local_part  = qq<$word(?:$period$word)*>;

# This is a combination of the domain name BNF from RFC 1035 plus the
# domain literal definition from RFC 822, but allowing domains starting
# with numbers.
my $label       = q/[A-Za-z\d](?:[A-Za-z\d-]*[A-Za-z\d])?/;
my $domain_ref  = qq<$label(?:$period$label)*>;
my $domain_lit  = qq<$open_br(?:$dtext|$quoted_pair)*$close_br>;
my $domain      = qq<(?:$domain_ref|$domain_lit)>;

# Finally, the address-spec regex (more or less)
$Addr_spec_re   = qr<$local_part\s*\@\s*$domain>;

1;
__END__

=head1 NAME

Email::Find::addrspec - exports $Addr_spec_re to Email::Find

=head1 SYNOPSIS

B<DO NOT USE THIS MODULE DIRECTLY>

=head1 DESCRIPTION

See L<Email::Find> for details.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Email::Find>

=cut
