#!/usr/bin/perl 
use strict; 

my $host = 'http://localhost/cgi-bin/test_dada/rest_server.cgi'; 

use JSON; 
use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use CGI qw(:standard); 

my    $q = CGI->new; 
print $q->header();


# Our data is sane!

# All of our commands will share this user agent
my $ua = LWP::UserAgent->new;

subscribe(
	{
		-list  => 'j', 
		-email => 'justin@skazat.com', 
	}
); 


sub subscribe {
	my ($args) = @_; 
	my $list  = $args->{-list}; 
	my $email = $args->{-email}; 

	my $format = { 
		email => $email,
		list  => $list, 
	};

	my $json = JSON->new->allow_nonref;
	my $data = $json->pretty->encode( $format ); 
		
    my $response = $ua->request(POST $host .'/=/subscribe', 
        'Content-Type' => 'application/json',
         Content        => $data
    );

    # On success, return the new ID assigned to the resource
    if ($response->is_success) {
		     print '<pre>'. $response->decoded_content . '</pre>';  # or whatever
	}

    # On failure, barf
    else {
        die $response;
    }
};

