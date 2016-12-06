package Google::reCAPTCHA;

use strict;
use warnings;

use Carp;
use LWP::UserAgent;
use JSON qw( decode_json );
use Params::Validate qw( validate SCALAR );

our $VERSION = '0.06';

use constant URL => 'https://www.google.com/recaptcha/api/siteverify';

my $IPv4_re = "((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))";
my $G       = "[0-9a-fA-F]{1,4}";

my @tail = ( ":",
	"(:($G)?|$IPv4_re)",
    ":($IPv4_re|$G(:$G)?|)",
    "(:$IPv4_re|:$G(:$IPv4_re|(:$G){0,2})|:)",
	"((:$G){0,2}(:$IPv4_re|(:$G){1,2})|:)",
	"((:$G){0,3}(:$IPv4_re|(:$G){1,2})|:)",
	"((:$G){0,4}(:$IPv4_re|(:$G){1,2})|:)"
);

my $IPv6_re = $G;

$IPv6_re = "$G:($IPv6_re|$_)" for @tail;
$IPv6_re = qq/:(:$G){0,5}((:$G){1,2}|:$IPv4_re)|$IPv6_re/;
$IPv6_re =~ s/\(/(?:/g;
$IPv6_re = qr/$IPv6_re/;

sub new {
    my $class = shift;
    my $self  = validate( @_, {
        secret => {
            type      => SCALAR,
            callbacks => {
                'is a secret key' =>
                    sub { $_[0] ne '' }
            }
        }
    } );
    
    bless $self, $class;
    
    return $self; 
}

sub siteverify {
    my $self = shift;
    my $pd   = validate( @_, {
        response => {
            type      => SCALAR,
            callbacks => {
                'is a response code' =>
                    sub { $_[0] ne '' }
            }
        },
        remoteip => {
            type      => SCALAR,
            optional  => 1,
            callbacks => {
                'is a remote ipv4 or ipv6 address' =>
                    sub { $_[0] =~ /^$IPv4_re$/ || $_[0] =~ /^$IPv6_re$/ }
            },
        },
    } );
    
    $pd->{secret} = $self->{secret};
    
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts( verify_hostname => 0 );

    my $response = $ua->post( URL , $pd );
    
    if ( $response->is_success)  {
        my $data = decode_json( $response->decoded_content );
        
        if ( exists ( $data->{'error-codes'} ) ) {
            croak( 'API Error: ' . join( ', ', @{ $data->{'error-codes'} } ) );
        }
        
        return $data->{success} ? 1 : 0;          
    }
    else {      
        my $content = $response->decoded_content ? $response->decoded_content : '';
        my $message = 'HTTP Request failed with status ' . $response->code . ' : ' . $content;

        croak( $message );
    }
}   
    
1;
__END__

=head1 NAME

Google::reCAPTCHA - A simple lightweight implementation of Google's reCAPTCHA for perl

=head1 SYNOPSIS

    use Google::reCAPTCHA;

    my $c = Google::reCAPTCHA->new( secret => 'secret_key' );
    
    # Verifying the user's response 
    my $success = $c->siteverify( response => 'response_key', remoteip => '192.168.0.1' );
    
    if( $success ) {
        # CAPTCHA was valid
    }

=head1 GETTING STARTED

To use reCAPTCHA you need to register your site here:

https://www.google.com/recaptcha/admin/create

=head1 PUBLIC INTERFACE

=head2 Google::reCAPTCHA->new( secret => 'secret_key' )

Our constructor, will croak when invalid parameters are given.


B<secret>

Required. The shared key between your site and ReCAPTCHA.

=head2 siteverify( response => 'response_key', remoteip => '192.168.0.1' )

Request siteverify from Google reCAPTCHA API


B<response>

Required. Form data containing g_captcha_response.

B<remoteip>

Optional. User's ip address. Both IPv4 and IPv6 is supported.

=head2 Errors

B<Error code reference:>

missing-input-secret    - I<The secret parameter is missing.>

invalid-input-secret    - I<The secret parameter is invalid or malformed.>

missing-input-response  - I<The response parameter is missing.>

invalid-input-response  - I<The response parameter is invalid or malformed.>

=head1 Git repo

L<https://bitbucket.org/tcorkran/google-recaptcha>

=head1 VERSION

0.06

=head1 AUTHOR

Thomas Corkran C<< <thomascorkran@gmail.com> >>

=head1 CONTRIBUTORS

Christopher Mevissen C<< <mev412@gmail.com> >>

=head1 ACKNOWLEDGEMENTS

Matthew Green C<< <green.matt.na@gmail.com> >>

---

This projects work was sponsored by Hostgator.com.

L<http://www.hostgator.com>

L<http://www.endurance.com>

=head1 COPYRIGHT & LICENSE

Copyright 2015, Thomas Corkran C<< <thomascorkran@gmail.com> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
