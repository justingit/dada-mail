#!/usr/bin/perl 

use lib qw(./dada ./dada/DADA/perllib ./ ./DADA); 
use lib qw(./test_dada ./test_dada/DADA/perllib); 

use SOAP::Transport::HTTP;

SOAP::Transport::HTTP::CGI   
  -> dispatch_to('DadaMail')     
  -> handle;

package DadaMail;

sub subscription_check { 
	
	my ($self, $list, $email) = @_;
	
	require  DADA::MailingList::Subscribers; 
	my $lh = DADA::MailingList::Subscribers->new(
				{
					-list => $list
				}
			);
 	my ($status, $errors) = $lh->subscription_check(
								{
									-email => $email,
								}
							);

	return [$status, $errors]; 

}



# Somewhat of a bonus.
sub subscribe { 
	
	my $r; 

	my ($class) = shift; 
	my $list    = shift; 
	my $email   = shift; 

	require CGI;
	my $q = new CGI; 
    $q->param('f',     's'   );
	$q->param('list',  $list ); 
	$q->param('email', $email); 

    require       DADA::App::Subscriptions; 
    require       DADA::MailingList::Subscribers; 
    my $das = DADA::App::Subscriptions->new; 

      # $das->test(1);

   		$r =  $das->subscribe(
        {
            -cgi_obj     => $q, 
			-html_output => 0,
        }
    ); 

	return $r; 
}
