#!/usr/bin/perl 

use strict;

package subscribe_email;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/DADA/perllib";
use lib "$FindBin::Bin/../../../";
use lib "$FindBin::Bin/../../../DADA/perllib";



use DADA::Config;
use DADA::App::Subscriptions;
use DADA::App::Guts;
use CGI;
use Getopt::Long;

my $verbose = 0;
my $email;
my $list;
my $fields = {}; 

# http://search.cpan.org/~jv/Getopt-Long-2.38/lib/Getopt/Long.pm#Options_with_hash_values
GetOptions(
    "email=s"   => \$email,
    "list=s"    => \$list,
    "fields=s%" => \$fields,
    "verbose"   => \$verbose,
);

__PACKAGE__->run()
  unless caller();

sub run {
	
	my $status = 0; 
	my $errors = {}; 
	
	use DADA::App::Guts; 
	if(check_if_list_exists(-List => $list) == 0){ 
		
		#return [0, {invalid_list => 1}];
		if($verbose == 1){ 
			require Data::Dumper; 
			Data::Dumper::Dumper(
				{ 
					status => 0, 
					errors => {
						invalid_list => 1, 
					}
				}
			); 
		}
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
									-fields => $fields, 
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

		if($verbose == 1){ 
			print "Email: $email\n";
			print "List: $list\n"; 
			print "Fields:\n"; 
			if(scalar(@{$lh->subscriber_fields}) >= 1) { 
				for(@{$lh->subscriber_fields}){ 
					print '*' . $_ . ': ' .  $q->param($_) . "\n";  
				}	
			}
			print "\n"; 
		}
		
	    require   DADA::App::Subscriptions; 
	    my $das = DADA::App::Subscriptions->new; 

	   		my $r =  $das->subscribe(
	        {
	            -cgi_obj     => $q, 
				-html_output => 0,
	        }
	    ); 
	}
	if($verbose == 1){ 
		require Data::Dumper; 
		print Data::Dumper::Dumper(
			{ 
				status => $sc_status, 
				errors => $sc_errors,
			}
		); 
	}}
