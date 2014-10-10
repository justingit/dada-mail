package DadaMailWebService;

use strict;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use URI::Escape;
use HTML::Entities;
use Digest::SHA qw(hmac_sha256_base64);

use CGI (qw/:oldstyle_urls/);
use Carp qw(carp croak);

sub new {
    my $class = shift;
    my $self  = {@_};
    bless $self, $class;
    my ($server, $public_key, $private_key) = @_;
    $self->init($server, $public_key, $private_key);
    return $self;
}

sub init {
    my $self   = shift;
    my ($server, $public_key, $private_key) = @_;

    $self->{server}      = $server;
    $self->{public_key}  = $public_key;
    $self->{private_key} = $private_key;

    my $json   = JSON->new->allow_nonref;
    $self->{json_obj}    = $json;

}

sub request {
    my $self = shift;
    my ( $list, $service, $params) = @_;

    my $q      = CGI->new();
    my $query  = {};
    my $nonce  = time . ':' . $self->nonce();
    my $qs     = undef; 
    my $digest = undef; 
    
    if ( $service eq 'mass_email' ) {
        if(!exists($params->{test})){ 
           $params->{test} = 0;  
        }
        $query = {
            format  => $params->{format},
            message => $params->{message},
            subject => $params->{subject},
            nonce   => $nonce,
            test    => $params->{test}, 
        };
        $q->param( 'format',  $query->{format} );
        $q->param( 'message', $query->{message} );
        $q->param( 'nonce',   $query->{nonce} );
        $q->param( 'subject', $query->{subject} );
        $q->param( 'test',    $query->{test} );

        $qs     = $self->the_query_string($query);
        $digest = $self->digest($qs);
        
    }
    elsif($service eq 'update_settings') { 
        $query = {
            nonce    => $nonce,
            settings => $self->{json_obj}->utf8->encode( $params->{settings} ),
        };
        $q->param( 'nonce',    $query->{nonce} );
        $q->param( 'settings', $query->{settings} );
        
        $qs     = $self->the_query_string($query);
        $digest = $self->digest($qs);        
    }
    elsif($service eq 'settings'){ 
        $digest = $self->digest($nonce); 
    }
    else {
        $query = {
            addresses => $self->{json_obj}->utf8->encode( $params->{addresses} ),
            nonce     => $nonce,
        };
        $q->param( 'addresses', $query->{addresses} );
        $q->param( 'nonce',     $query->{nonce} );
        
        $qs     = $self->the_query_string($query);
        $digest = $self->digest($qs);        
    }


    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/5.0 (compatible);');
    
    if($service eq 'settings'){ 
        $ua->default_header( 
            'Authorization' => 'hmac ' . ' ' . $self->{public_key} . ':' . $digest,
            'X-DADA-NONCE'  => $nonce, 
         );
    }
    else { 
        $ua->default_header( 'Authorization' => 'hmac ' . ' ' . $self->{public_key} . ':' . $digest );
    }
    my $server_w_path_info = $self->{server} . '/api/' . uri_escape($list) . '/' . uri_escape($service) . '/';
    my $response; 
    
    if($service eq 'settings'){ 
        $response = $ua->request( GET $server_w_path_info)   
    }
    else { 
        $response = $ua->request( POST $server_w_path_info, content => $query );
    }
    if ( $response->is_success ) {
        return $self->{json_obj}->utf8->decode( $response->decoded_content );
    }
    else {
        carp 'Problems with Request: ' . $response->decoded_content . "\n" . $server_w_path_info;
        return {};
    }
}

sub the_query_string {
    my $self         = shift;
    my $query_params = shift;
    my $new_q        = CGI->new;
    for ( sort { lc $a cmp lc $b } ( keys %$query_params ) ) {
        $new_q->param( $_, $query_params->{$_} );
    }
    my $qs = $new_q->query_string();
    return $qs;
}

sub nonce() {
    my $self  = shift;
    my @chars = ( 0 .. 9, 'a' .. 'z', 'A' .. 'Z' );
    my $num   = 8;

    my $nonce;
    for ( 1 .. $num ) {
        $nonce .= $chars[ rand @chars ];
    }
    return $nonce;
}

sub digest {
    my $self    = shift;
    my $message = shift;
    my $digest  = hmac_sha256_base64( $message, $self->{private_key} );
    while ( length($digest) % 4 ) {
        $digest .= '=';
    }
    return $digest;
}

1; 