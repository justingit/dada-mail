package CGI::Session::ID::md5;

# $Id$

use strict;
use Digest::MD5;
use CGI::Session::ErrorHandler;

$CGI::Session::ID::md5::VERSION = '4.43';
@CGI::Session::ID::md5::ISA     = qw( CGI::Session::ErrorHandler );

*generate = \&generate_id;
sub generate_id {
    my $md5 = Digest::MD5->new();
    $md5->add($$ , time() , rand(time) );
    return $md5->hexdigest();
}


1;

=pod

=head1 NAME

CGI::Session::ID::md5 - default CGI::Session ID generator

=head1 SYNOPSIS

    use CGI::Session;
    $s = CGI::Session->new("id:md5", undef);

=head1 DESCRIPTION

CGI::Session::ID::MD5 is to generate MD5 encoded hexadecimal random ids. The library does not require any arguments. 

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut
