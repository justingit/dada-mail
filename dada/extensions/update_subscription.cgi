#!/usr/bin/perl -w 
use strict; 
use lib qw(../ ../DADA/perllib ../../../perllib ../../../perl);
use DADA::Config 3.0.0; 
use DADA::App::Guts; 
use DADA::Template::HTML; 
use DADA::Logging::Usage; 
use DADA::MailingList::Subscribers;

my $log =  new DADA::Logging::Usage;

use CGI::Carp "fatalsToBrowser"; 
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);


my $list = $q->param('list'); 

if((!$q->param('old_email'))  || (!$q->param('new_email'))){ 

	print(list_template(-Part       => "header",
				   -Title      => "Change Your Subscribed Email Address", 
				   -List       => $list,
				   )); 
				   		   
    if($q->param('error') eq 'invalid_email'){ 
    
		print $q->p({class=>'smallred'}, 
		            'Your new email does not appear to be valid, please enter a valid email address');
		             
	}elsif($q->param('error') eq 'not_subscribed'){
		print $q->p({class=>'smallred'}, 
		            'Your email does not appear to be subscribed to any of our lists, please make sure you typed it in correctly'); 
	}
				   
	print $q->start_form(-action => $q->url . '/update_subscription.cgi'), 
		  $q->p('Replace my subscriptions that are using this email address:', 
		  $q->br, 
		  $q->textfield(-name => 'old_email', 
		  				-value => $q->param('old_email'))), 
		  $q->p('with this email address:', $q->br, 
		  $q->textfield(-name  => 'new_email', 
		  				-value => $q->param('new_email'))),   
		  $q->p({-align => 'center'}, 
		  $q->submit(-value  => 'Update My Subscriptions', 
		  			'-class' => 'processing')), 
		  $q->end_form(); 
	print(list_template(-Part     => "footer", 
				   -List     => $list,
				   )); 
}else{ 
	my $report; 
	my $old_email = $q->param('old_email'); 
	my $new_email = $q->param('new_email'); 
	my $check = 0; 
	foreach(available_lists()){ 
			my $lh = DADA::MailingList::Subscribers->new({-list => $_});
			if($lh->check_for_double_email(-List => $_, -Email => $old_email) == 1){ 
				if(check_for_valid_email($new_email) != 1){ 
					$lh->remove_from_list(-List => $_,  -Email_List => [$old_email]);
					 $lh->add_subscriber({-email => $new_email});
					$report .= $q->p("Your subscribed email has been updated for list:", $q->b($_));
					$log->mj_log($_,"Subscription Updated", "$old_email to $new_email"); 
					$check++;
				}else{ 
					print $q->redirect(-uri=>"update_subscription.cgi?error=invalid_email&old_email=$old_email");
				}
			}
		}
		if($check == 0){ 
				print $q->redirect(-uri=>"update_subscription.cgi?error=not_subscribed&new_email=$new_email");
		}else{ 
		print(list_template(-Part       => "header",
					   -Title      => "Email Subscription Updated!", 
					   -List       => $list,
					   )); 
		print $q->h3('Your subscriptions have been updated.');			   
		print $report; 
		print(list_template(-Part     => "footer", 
				       -List     => $list,
				       )); 
	}
}


=pod

=head1 NAME update_subscriptions.cgi

=head1 DESCRIPTION

The script allows a subscriber to change the address they are 
subscribed to another address for all lists at once.

=head1 INSTALLATION

upload this script in plaintext, or ASCII, mode into the 
extensions directory inside the dada directory, something like:

 /home/account/cgi-bin/dada/extensions

If this directory doesn't exist, make it.

chmod 755 this script.

You are good to go.

View this script in a web browser, if everything is installed
correctly, you should see a subscription update form.


=head1 COPYRIGHT 

Copyright (c) 1999-2009 

Justin Simoni

http://justinsimoni.com

All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut

