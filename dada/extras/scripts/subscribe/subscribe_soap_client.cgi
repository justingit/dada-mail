#!/usr/bin/perl 

use CGI::Carp qw(fatalsToBrowser); 

# There should be a test to make sure SOAP::Lite is installed. 
use SOAP::Lite;

use CGI qw(:standard); 

my $proxy     = 'http://localhost/cgi-bin/dada/extras/scripts/suscribe/subscribe_soap_server.cgi'; 
my $namespace = 'DadaMail';


my $email     = 'user@example.com'; 
my $list      = 'listshortname';
my $fields = { 
	# Profile Fields go here! Example: 
	#
	# first_name => 'John', 
	# last_name  => 'Doe', 
	#
	# (etc)
};



print header(); 

my $soap = SOAP::Lite 
	-> uri('urn:' . $namespace)
  	-> proxy($proxy);

  my $result = $soap->subscribe($list, $email, $fields);

print "<pre>\n"; 
print '	* Email: ' . $email . "\n"; 
print '	* List: '  . $list  . "\n\n"; 

unless ($result->fault) {
	my $return = $result->result();

	require Data::Dumper; 
	print Data::Dumper::Dumper($return); 
	
	my $check  = $return->[0]; 


	print "Subscription Check: $check\n"; 

	my $errors = $return->[1]; 


	if(keys %$errors){ 
		print "Errors: \n"; 
	for(keys %$errors){ 
			print "	* Error: $_\n";
		}
	}

} else {
	print join ', ', 
	$result->faultcode, 
	$result->faultstring;
}

print "done.\n";