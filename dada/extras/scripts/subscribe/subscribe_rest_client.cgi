#!/usr/bin/perl 
use strict; 

# You will need to change the below variables: 
#
my $host = 'http://localhost/cgi-bin/dada/extras/scripts/subscribe/subscribe_rest_server.cgi'; 
my $email = 'listshortname'; 
my $list  = 'user@example.com'; 
my $fields = { 
	# Profile Fields go here! Example: 
	#
	# first_name => 'John', 
	# last_name  => 'Doe', 
	#
	# (etc)
}
#

use CGI::Carp qw(fatalsToBrowser); 
use JSON; 
use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use CGI qw(:standard); 

my    $q = CGI->new; 
print $q->header();


# All of our commands will share this user agent
my $ua = LWP::UserAgent->new;

subscribe(
	{
		-list  => $list, 
		-email => $email, 
		-fields => { 
			$fields, 
		}
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

