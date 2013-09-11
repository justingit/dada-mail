package CGI::Session::ID::static;
use base 'CGI::Session::ErrorHandler';

use strict;
use Carp 'croak';
use CGI::Session::ErrorHandler;

$CGI::Session::ID::static::VERSION = '4.44';

sub generate_id {
    my ($self, $args, $claimed_id ) = @_;
    unless ( defined $claimed_id ) {
        croak "'CGI::Session::ID::Static::generate_id()' requires static id";
    }
    return $claimed_id;
}

1;
__END__

=head1 NAME

CGI::Session::ID::static - CGI::Session ID Driver for generating static IDs

=head1 SYNOPSIS

    use CGI::Session;
    $session = CGI::Session->new( 'driver:mysql;id:static', $ENV{REMOTE_ADDR}, { Handle => $dbh } );

=head1 DESCRIPTION

CGI::Session::ID::static is used to generate consistent, static session
ID's. In other words, you tell CGI::Session ID you want to use, and it will honor it.

Unlike the other ID drivers, this one requires that you provide an ID when creating
the session object; if you pass it an undefined value, it will croak.

=head1 COPYRIGHT

Copyright (C) 2002 Adam Jacob <adam@sysadminsith.org>,

This library is free software. You can modify and distribute it under the same
terms as Perl itself.

=head1 AUTHORS

Adam Jacob <adam@sysadminsith.org>,

=head1 LICENSING

For additional support and licensing see L<CGI::Session|CGI::Session>

=cut
