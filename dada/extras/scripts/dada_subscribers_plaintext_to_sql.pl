#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/DADA/perllib";
use lib "$FindBin::Bin/../../";
use lib "$FindBin::Bin/../../DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}


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

print "beginning...\n";

for my $list(DADA::App::Guts::available_lists()){ 
	
	my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
	
	print "\tworking on list: '$list'...\n";
	
	for my $sublist(qw(list black_list white_list authorized_senders moderators)){

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
																invite_only_list
																closed_list 
																mx_lookup_failed 
																black_listed 
																over_subscription_quota 
																already_sent_sub_confirmation
																profile_fields
															)],
												}
											); 
				}
				
				if($status == 1){ 
					eval { 
						$lh->add_subscriber(
							{
								-email => $email, 
								-type  => $sublist
							}
						);
					};
					if(!$@){ 
						print "\t\t\t\tadded: $email\n";
					}
					else { 
						print "\t\t\t\tProblems! Adding: $email - $@\n";	
					}
				}else{ 
					print "\t\t\t PROBLEMS with $email: "; 
					for my $err(keys %$errors){ print "$err, " if $errors->{$err} == 1; }
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

=head1 dada_subscribers_plaintext_to_sql.pl

=head1 Description

C<dada_subscribers_plaintext_to_sql.pl> migration script converts your Dada Mail List Subscribers from the Default backend, to one of the SQL backends. 

The Default backend for the List Subscribers is going to be a plaintext file, 
with one line per email address. 

C<dada_subscribers_plaintext_to_sql.pl> is to be used I<after> you have reconfigured Dada Mail to use one of the SQL backends - you'll most likely do this via the Dada Mail installer. Once you have reconfigured your Dada Mail, none of your previous mailing lists will be available, until after you run this migration script. 

Before running this migration script, please make sure to backup your important Dada Mail files/information, most notably, the B<.dada_files> directory. 

=head1 Configuration

No configuration will need to be done in this script itself. The permissions of this script simply need to be set to, C<755>.

=head1 Using

Visit C<dada_subscribers_plaintext_to_sql.pl> in your web browser, or run the script via the command line. Make sure to B<only run this script once>, or data will be duplicated. 

=head1 COPYRIGHT 

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

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








