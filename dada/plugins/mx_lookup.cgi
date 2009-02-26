#!/usr/bin/perl -w
use strict; 

# make sure the DADA lib is in the lib paths!
use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
); 

use CGI::Carp qw(fatalsToBrowser); 


# use some of those Modules
use DADA::Config 3.0.0 qw(!:DEFAULT);
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings;

my $Ver = '1.0';

# we need this for cookies things
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);

my ($admin_list, $root_login) = check_list_security(-cgi_obj   => $q, 
                                                    -Function  => 'mx_lookup');
my $list = $admin_list; 


# get the list information
#my %list_info = open_database(-List => $list); 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $list_info = $ls->get();
                          
# header     
print(admin_template_header(-Title      => "mx lookup Verification $Ver",
		                -List       => $list_info->{list},
		                -Form       => 0,
		                -Root_Login => $root_login));
	
	               
if(!$q->param('process')){ 

	print $q->p('Warning! mx lookup has not been enabled! '  .
		  $q->a({-href=> $DADA::Config::S_PROGRAM_URL.'?f=list_options'}, 
		  $q->b('Enable...'))) 
			  unless $list_info->{mx_check} == 1; 
	
	
	
	print $q->p({-align => 'right'}, 
		  $q->start_form(-action => $DADA::Config::S_PROGRAM_URL, 
					     -method => 'POST',
					     -target => 'text_list'),
		$q->hidden('f', 'text_list'),
		$q->submit(-name  => 'Open Subscription List in New Window',
				   -class => 'plain') .
		$q->end_form()); 
		
		
		
	
	print $q->p("Paste email addresses that you would like an mx lookup for:") . 
		  $q->start_form()                                                     . 
		  $q->p(
		  $q->textarea(-name => 'addresses',
					   -rows  => 5,
					   -cols  => 40,
								))                                             . 
		  $q->hidden('process', 'true')                                        .
		  $q->submit(-name => 'Verify...',
					-class => 'processing')                                                 .
		  $q->end_form(); 



	}else{ 
		
		my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
		my @emails = split(/\s+|,|;|\n+/, $q->param('addresses'));
		my @passed;
		my @failed; 
		
		###################################################################
		#
		#
		
		foreach my $email(@emails){ 
			my ($status, $errors) = $lh->subscription_check(
										{
											-email => $email,
										}
									); 
			if($errors->{mx_lookup_failed} == 1){
				push(@failed, $email);	
			}else{ 
				push(@passed, $email);
			}
		}
		my $passed_report = join("\n", @passed); 
		my $failed_report = join("\n", @failed); 
		
		#
		#
		###################################################################
		
		print $q->p('the following emails passed mx lookup verification:')     . 
			  
	
			  $q->start_form(-action => $DADA::Config::S_PROGRAM_URL, -method => 'POST')          .  
			  $q->hidden('f', 'add'),
			  $q->hidden('process', 1),
			  $q->p($q->textarea(-name  => 'new_emails', 
								 -value => $passed_report,
								 -rows  => 5,
								 -cols  => 40)) .
			  $q->submit(-name  => 'Add These Addresses to Your List', 
						 -class => 'processing')                       .
			  $q->end_form() .
			  
			  
					  
			  $q->p('The following emails failed mx lookup verification:') . 
			  
			  
			  $q->start_form(-action => $DADA::Config::S_PROGRAM_URL, -method => 'POST')      .
			  $q->hidden('f', 'delete_email'), 
			  $q->hidden('process', 'true'), 
			  $q->p($q->textarea(-name  => 'delete_list', 
								 -value => $failed_report,
								 -rows  => 5,
								 -cols  => 40,
								 )) .
			  $q->submit(-name => 'Remove These Addresses From Your List',
						 -class => 'alertive')                     .
			  $q->end_form(); 	


}


#footer
print admin_template_footer(-List => $list, -Form => 0); 


=pod

=head1 COPYRIGHT 

Copyright (c) 1999-2009 Justin Simoni All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

