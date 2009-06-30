#!/usr/bin/perl -w

use lib qw(./ ./DADA/perllib); 
use CGI::Carp qw(fatalsToBrowser); 

use strict; 


# When set to, "1", will go through the subscription process for each subscriber. 
# Cons: Slows things down. 

my $Check_Subscriptions = 0; 



# DO NOT USE THIS SCRIPT WITHOUT FULLY BACKING UP YOUR ENTIRE DADA MAIL INSTALL 




# REALLY. 


use DADA::Config; 
use DADA::App::Guts; 
use DADA::MailingList::Subscribers; 



my $dbh; 

use CGI qw(:standard); 

print header(); 
print '<pre>';


use Fcntl qw(
O_RDWR O_CREAT LOCK_SH); 

use lib qw(./ ./DADA ./DADA/perllib); 

print "beginning...\n";

foreach my $list(DADA::App::Guts::available_lists()){ 
	
	my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
	
	print "\tworking on list: '$list'...\n";
	
	#foreach my $sublist('list', 'black_list', 'authorized_senders'){
	foreach my $sublist('list', 'black_list', 'white_list', 'authorized_senders'){

		my $sublist_filename = $DADA::Config::FILES . '/' . $list . '.' . $sublist; 
		
		unless(-e $sublist_filename){ 
			print "\t\t\t$sublist_filename unavailable - skipping\n";
		}else{ 
			
			print "\t\t\t * $sublist - starting...\n"; 

			sysopen(LIST, $sublist_filename, O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD) 
				or die "couldn't open $sublist_filename for reading: $!\n";
		   flock(LIST, LOCK_SH);
		   
		   while(defined(my $email = <LIST>)){ 
					chomp $email; 					
				my ($status, $errors) = (1, {});
				
				if($Check_Subscriptions == 1){ 
					($status, $errors) = $lh->subscription_check(
										 	{
												-email => $email, 
												-type => $sublist, 
												-skip => [qw(
																no_list 
																closed_list 
																mx_lookup_failed 
																black_listed 
																over_subscription_quota 
																already_sent_sub_confirmation
															)],
												}
											); 
				}
				
				if($status == 1){ 
					$lh->add_subscriber(
						{
							-email => $email, 
							-type  => $sublist
						}
					);
					print "\t\t\t\tadded: $email\n";
				}else{ 
					print "\t\t\t PROBLEMS with $email: "; 
					foreach my $err(keys %$errors){ print "$err, " if $errors->{$err} == 1; }
					print "\n"
				}
			
			}
			
			close(LIST); 
			
			print "\t\t\t * $sublist - done.\n"; 
		}
	}
}

print "Done.\n\n"; 



__END__

=pod

=head1 Name dada_subscribers_plaintext2sql.pl

=head1 Description

Cute name, huh? 

Basically, this small script takes the information of a Dada Mail plaintext subscription list and ports it to the MySQL format.

Fairly simple and straightforward. 

=head1 How to use this script

=over

=item * Backup Everything

SQL tables, list files (all of them) 

=item * Create the Subscribers SQL table

The SQL statement to run should be saved in a file called I<dada_subscribers.sql> which is located in the I<dada/extras/SQL> directory of the distribution

=item * Set B<DB_TYPE> to the correct SQL type (MySQL, Postgres)

Directions are located in the Config.pm about this, search for, I<$SUBSCRIBER_DB_TYPE>

=item * Fill in %SQL_PARAMS in the Config.pm file

Again, directions should be supplied in the Config.pm file. 

=back

After the above (do not skip a step) are done, make sure Dada Mail is still running by visiting it in your webbrowser. The program should run exactly as before, except no subscribers will be present. 

Upload this script into the same directory that you have the I<mail.cgi> script in, and run it, either from your web browser, or via a shell connection (which is prefered). 

That should be it. 


ps. backup everything. 
 

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut









