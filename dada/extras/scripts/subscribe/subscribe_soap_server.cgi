#!/usr/bin/perl 

use lib qw(
	../../../
	../../../DADA/perllib
	../../
	../../DADA/perllib
	./
	./DADA/perllib
); 

use SOAP::Transport::HTTP;
SOAP::Transport::HTTP::CGI   
  -> dispatch_to('DadaMail')     
  -> handle;

package DadaMail;

sub subscribe { 
	
	my $r; 
	my ($class) = shift; 
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

	    require   DADA::App::Subscriptions; 
	    my $das = DADA::App::Subscriptions->new; 

	   		$r =  $das->subscribe(
	        {
	            -cgi_obj     => $q, 
				-html_output => 0,
	        }
	    ); 
	}
	return [$sc_status, $sc_errors]; 
	
}
