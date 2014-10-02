#!/usr/bin/perl 

package main;
use strict;

use Data::Dumper;
use URI::Escape;
use HTML::Entities;

use CGI (qw/:oldstyle_urls/); 
my $q = CGI->new;
use FindBin; 
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}

#---------------------------------------------------------------------#

my $list        = 'example';
my $public_key  = 'aaOKqoeobNoaJPyAMYHo';                         #20
my $private_key = 'bju7EF35jHua5aYvdiEyboipDcBQo3eeRqCNfc4E';    #40
my $flavor      = 'validate_subscription';

my $addresses = [
    {
        email  => 'test@example.com',
        fields => {},
    },
    {
        email => 'adsfljsdklfjhaksdjfh!!!',
    }
];

my $ws = WebService->new(
    {
        -public_key  => $public_key,
        -private_key => $private_key,
    }
);


print $q->header();
print '<pre>'; 


my $my_params = {
    subject => 'my subject!', 
    format  => 'text', 
    message => 'my message', 
}; 

my $results  = $ws->request( $list, 'mass_email', $my_params);


#my $results = $ws->request( $list, $flavor, {addresses => $addresses} );


print '<pre>' . encode_entities( Dumper($results) ) . '</pre>';




package WebService;

use strict;
use JSON;
use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use Data::Dumper;
use CGI (qw/:oldstyle_urls/);
use CGI::Carp qw(fatalsToBrowser);
use Carp qw(carp croak);
use URI::Escape;
use HTML::Entities;

sub new {
    my $class = shift;
    my $self  = {@_};
    bless $self, $class;
    my ($args) = @_;
    $self->init($args);
    return $self;

}

sub init {
    my $self   = shift;
    my ($args) = @_;
    my $json   = JSON->new->allow_nonref;
    $self->{json_obj}    = $json;
    $self->{public_key}  = $args->{-public_key};
    $self->{private_key} = $args->{-private_key};	
}

sub request {
    my $self = shift;

    my ( $list, $flavor, $params ) = @_;


    my $q     = CGI->new();
    my $query = {}; 
    if($flavor eq 'mass_email'){ 
        $query = {
            format    => $params->{format},
            message   => $params->{message},
            subject   => $params->{subject},
            timestamp => time,
        };
    	$q->param('format',    $query->{format});
    	$q->param('message',   $query->{message});
    	$q->param('subject',   $query->{subject});
    	$q->param('timestamp', $query->{timestamp});
    }
    else {
        $query = {
            addresses => $self->{json_obj}->utf8->encode($params->{addresses}),
            timestamp => time,
        };
    	$q->param('addresses', $query->{addresses});
    	$q->param('timestamp', $query->{timestamp});
	}
	
    my $qs     = $self->the_query_string( $query );
    my $digest = $self->digest($qs);
	
    my $server = 'http://secret.dadademo.com/cgi-bin/dada/mail.cgi';

    my $ua = LWP::UserAgent->new;
	   $ua->agent('Mozilla/5.0 (compatible;'); 

    
	my $server_w_path_info = $server . '/api/' . uri_escape($list) . '/' . uri_escape($flavor) . '/'. uri_escape($self->{public_key}) . '/' . uri_escape($digest) . '/'; 
	# print '$server_w_path_info ' . $server_w_path_info; 
	my $response; 
	
    $response = $ua->request(POST $server_w_path_info, content => $query);      
    my $tries = 0; 
    #print "\n" . '$response->status_line"' . $response->status_line . '"'; 
    while($response->status_line =~ m/^404/ && $tries <= 3) {
        #print "trying...\n"; 
        #print '$response->status_line"' . $response->status_line . '"'; 
        $tries++; 
        sleep(1); 
        $response = $ua->request(POST $server_w_path_info, content => $query);
    }

    if ( $response->is_success ) { 
        return $self->{json_obj}->utf8->decode( $response->decoded_content );
    }
    else {
        croak 'Problems with Request: ' . $response->decoded_content . "\n" . $server_w_path_info;
    }
}

sub the_query_string {
    my $self           = shift;
    my $query_params   = shift;
	my $new_q = CGI->new; 
    for ( sort { lc $a cmp lc $b } ( keys %$query_params ) ) {
        $new_q->param( $_, $query_params->{$_} );
    }
    my $qs = $new_q->query_string();
    return $qs;
}

sub digest {

    my $self    = shift;
	
    my $message = shift;

    use Digest::SHA qw(hmac_sha256_base64);
    my $digest = hmac_sha256_base64( $message, $self->{private_key} );
    while ( length($digest) % 4 ) {
        $digest .= '=';
    }
    return $digest;
}



