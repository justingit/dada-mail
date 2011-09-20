#!/usr/bin/perl 
use strict;

use lib qw(
	../../../
	../../../DADA/perllib
	../../
	../../DADA/perllib
	./
	./DADA/perlib
);


use JSON; 
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);


 
my $q    = CGI->new; 
my $json = JSON->new->allow_nonref;


if($q->path_info() =~ m/\=\/subscribe/){ 
	subscribe(); 
}
else { 
	rest_help(); 
}
sub subscribe() {
	
    # We expect the data to be in YAML format
    unless ($q->content_type eq 'application/json') {
        die '425 use application/json'; 
    }
   my $post_data = $q->param('POSTDATA');
   my $data = undef; 
	eval { 
		# Try to load it and make sure it's valid JSON
		$data = $json->decode( $post_data );
	};
     
   	#On error we need to complain
	if($@) { 
		die '400'; 
	}
	my ($status, $errors) = dada_mail_subscribe($data->{list}, $data->{email}, $data->{fields});

    print $q->header( 
        -status   => 201, 
        -type     => 'text/html',
		# Not sure what location is for... 
        #-location => $resource_url,
    );


	my $data_back = $json->pretty->encode(
		{ 
		status    => $status, 
		errors    => $errors, 
		path_info => $q->path_info(), 
		}
	); 
	print $data_back; 
	
}



sub rest_help(){ 
	
	print $q->header(); 
	
print q{ 
<p>
 Here is a list of what you can do:
</p> 
<dl>
 <dt>POST /=/subscribe</dt> 
 <dd>Subscribe an email address to a mailing list.</dd> 
</dl> 

<p>You'll need to POST this request in the following JSON format:</p> 

<pre> 
{
   "email" : "user@example.com",
   "list" : "listshortname"
}
</pre> 

<p>Returned will be a JSON document with this format: 

<pre> 
{
   "status" : 0,
   "errors" : {
      "subscribed" : 1
   }
}
</pre> 

<p><strong>status</strong> will be set to, <strong>1</strong> 
if there are no problems. If there are problems <strong>status</strong> will be set
to <strong>0</strong> and <strong>errors</strong> will have an associated array
holding what problems there were.</p> 

	
};

    
}




sub dada_mail_subscribe { 
	
	my $r; 

	my $list    = shift; 
	my $email   = shift; 
	my $fields  = shift; 
	
	my $status = 0; 
	my $errors = {}; 
	
	use DADA::App::Guts; 
	if(check_if_list_exists(-List => $list) == 0){ 
		return [0, {invalid_list => 1}];
	}

	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 

	require  DADA::MailingList::Subscribers; 
	my $lh = DADA::MailingList::Subscribers->new(
				{
					-list => $list
				}
			);
			
	# There may be tests that we want to skip: 
	my $skip_tests = [];
	# Black listed subscribers by default can subscribe themselves: 
	if($ls->param('allow_blacklisted_to_subscribe') == 1){  
       push(@$skip_tests, 'black_listed');  
	}
	# We want to at least say there's no problem, but an email message will
	# be sent about it. 
	if($ls->param('email_your_subscribed_msg') == 1){  
 		push(@$skip_tests, 'subscribed');  
	}
	
 	my ($sc_status, $sc_errors) = $lh->subscription_check(
								{
									-email => $email,
									-skip  => $skip_tests, 
								}
							);
							
	if($sc_status == 1){ 
		
		require CGI;
		my $q = new CGI; 
		   $q->param('f',     's'   );
		   $q->param('list',  $list ); 
		   $q->param('email', $email); 

		# Profile Fields
	    for(@{$lh->subscriber_fields}){ 
			if(exists($fields->{$_})){ 
	        	$q->param($_, $fields->{$_}); 
			}
		}
		
	    require       DADA::App::Subscriptions; 
	    my $das = DADA::App::Subscriptions->new; 

	   		$r =  $das->subscribe(
	        {
	            -cgi_obj     => $q, 
				-html_output => 0,
	        }
	    ); 
	}
	return ($sc_status, $sc_errors); 
	
}

