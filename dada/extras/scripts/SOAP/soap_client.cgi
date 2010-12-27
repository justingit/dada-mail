#!/usr/bin/perl 

use SOAP::Lite;

use CGI qw(:standard); 

my $proxy     = 'http://localhost/cgi-bin/soap_server.cgi'; 
my $namespace = 'DadaMail';


my $email     = 'user@example.com'; 
my $list      = 'mylist';


print header(); 



my $soap = SOAP::Lite 
	-> uri('urn:' . $namespace)
  	-> proxy($proxy);

  my $result = $soap->subscription_check($list, $email);

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
	foreach(keys %$errors){ 
			print "	* Error: $_\n";
		}
	}

} else {
	print join ', ', 
	$result->faultcode, 
	$result->faultstring;
}

print "done.\n";