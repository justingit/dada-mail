#!/usr/bin/perl


=pod

=head1 NAME 

dada_stats.pl  - A simple statistics script for Dada Mail lists. 

=head1 Installation

=over

=item Where Should The Stat Files Be Written?

The best idea is to have a directory *just* for this function, 
so when you want to retrieve all your reports, you just have to 
download one directory, and open it up into something ike Excel.  
make sure this script has permissions to write to this directory!

example:

	my $Stat_Dir = '/usr/home/account/.dada_files/.stats'; 

=cut

my $Stat_Dir = '/usr/home/account/.dada_files/.stats'; 

=pod

=item  Where Is Your Server's Perl Library? 

If you run this script as a cron job, you'll need to 
set the path to the lib directory
you can type in (or copy, be smart 'bout this)

	perl -e 'foreach(@INC){ print $_,"\n"}' 

in a telnet session to get a list of various perl libs to use. 

example:

	use lib '/usr/local/lib/perl5/site_perl/5.005';

=cut
use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);

=pod

=item Where Are Your dada and DADA Directories? 

Make sure these point to the correct place where the dada and DADA 
directories are, as this script will need to know where they are. 
If you run this script via a cron job, you should set these to absolute 
paths. 

example:

	use lib '/usr/home/account/public_html/cgi-bin/dada'; 
	use lib '/usr/home/account/public_html/cgi-bin/dada/DADA'; 

=back

=cut
	 
	use lib '/usr/home/account/public_html/cgi-bin/dada'; 
	use lib '/usr/home/account/public_html/cgi-bin/dada/DADA'; 
	use lib '/usr/home/account/public_html/cgi-bin/dada/DADA/perllib'; 

=pod

=head1 What Does This Script Do? 

It tries to do a few things, but most importantly, it helps you get a 
good idea on what's going on with your subscriber list. Is it growing? 
Shrinking? Where are people coming from? How many total people are subscribed? 

This script creates two tab-delimited files that you can then open in a 
spreadsheet application like Excel and make pretty little line graphs of 
what's going on with your lists. Every time it's run, it'll create a new
line of data. A smart thing to do would be to run this script once a day, 
thus giving you a snapshot of that day.  The two files it creates are: 

=head2 Domain Stats

The first thing dada_stats does is take count of email addresses by Top Level 
Domain, like .com, .edu, and so forth. You can change what Top Level Domain 
dada_stats.pl works with by changing the @DOMAINS array in the Config.pm, 
instructions are provided in the Config.pm file itself. This is useful to see
from where are people are coming form to subscribe to your list. You may find that 
you have a large college following if you have many '.edu' Top level Domains, 
or many people are coming from Japan if you have a big 'jp' number. Things
like that. The tab-delimited file kinda looks like this: 

	Sun Mar 18 23:15:23 2001	1633	1321	61	5	1	179	1	10	55

Which isn't the most exciting thing in the world, but is easy for a spreadsheet
to handle,  here's the default format lables: 

	Date	Total	com	    edu 	gov 	info    mil 	net 	nu	org    us	Other 

The first column is the date, the second column is the total number of 
subscribers on your list. That may be all you care about and you can do 
a great deal with just that. The rest of the numbers depend on what you have in 
your @DOMAINS array, but its basically the Top Level Domains you want to 
track, in alphabetical order. After that, is the number of subscribers
that don't fall in any of the other categories If you change the 
@DOMAINS array in the Config.pm  while you're using this script, your 
file's format will change and that  not site well with the number crunchers.
If I added 'foo' to the @DOMAINS  array, its entry will go between 'edu'
and 'gov' and all the rest after  'foo' will get pushed to the right. See
what I'm saying?  

=head2 Mail Services Stats

The second file that is created per list is the Internet Email Services
table, which keeps track of free email services and other trackable ones
like, yahoo!'s mail services, aol.com, etc. This is set by the %SERVICES 
hash in the Config.pm file. This file has a similar format to the above: 

	Sun Mar 18 23:15:23    2001    506	6	5	207	8	0	84	817	  

First column is the date, second is the total amount of email addresses, the 
next are your services, in alphabetical order, the default label
would look like this: 

	Date	Tota    .Mac	AOL    Compuserve    Excite Mail    Hotmail    MSN	PO Box	Prodigy Yahoo! Other

(note that 'Excite Mail' is one Service) After those, anything that doesn't
fall in those categories gets written under 'Other'

=head1 How to use this script

Everytime this script is run, it'll write to two files per list, the domains
file and the services file, the filename will be something like 
listshortname-domains.txt  and listshortname-services.txt

It'll write one line of data, explained above. This script should 
really be run  by a cron job, say everyday at midnight. This will give
you a daily snapshot of your list.

This script is just a starting point. the easiest thing to do with the 
files this script creates is to pull it into Excel, which can do all kinds
of crazy stuff to thingies in tables. 

The other thing you can do is create a script that takes the information 
in the files and create a report out of it.  
This is something else you could run via a cronjob, say at 1am every day, 
so when you wake up, you can see exactly what is going on with your
Dada lists, and try to pick out trends.  

=head1 Author

Justin Simoni
http://justinsimoni.com

head1 License

This program is Open Source Software and is covered under the General 
Public License. You should have gotten a copy of the license with this script. 
if not, you can view a copy at: http://www.gnu.org/copyleft/gpl.html

=cut

use DADA::Config; 
use DADA::App::Guts; 
use DADA::MailingList::Subscribers;
use Fcntl;
use strict; 


my $key; 
my $value; 

# get a list of the lists (har har) 
my @lists = available_lists(); 



# foreach of our lists here, 
foreach my $list(@lists){
       
    $SHOW_EMAIL_LIST     = 0;    
    $SHOW_SERVICES_TABLE = 1; 
    $SHOW_DOMAIN_TABLE   = 1; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
	my ($everyone, $domains_ref, $count_services_ref) = $lh->list_option_form(-List => $list, -In_Order => $LIST_IN_ORDER);

	#########################################################################
	#           Domain report.          #
	#####################################

	my @domain_keys = sort(keys %$domains_ref); 

	my @domain_report; 
	
	push(@domain_report, scalar(localtime));
	push(@domain_report, $everyone); 
 
	
	
	foreach $key (@domain_keys){ 
		if($key ne 'Other'){ 
	 		warn $key;
	        push(@domain_report, $domains_ref->{$key}); 
		}
	}
	push(@domain_report, $domains_ref->{Other}); 

	
	my $domain_row = join("\t", @domain_report); 
	
	my $domain_file_name = "$Stat_Dir/$list-domains.txt"; 
	
	open (DOMAIN, ">>$domain_file_name") or 
	die "couldn't open $domain_file_name for appending: $!\n";
	flock(DOMAIN, 1); 
	print DOMAIN $domain_row, "\n";
	close (DOMAIN); 	

	#########################################################################
	#         Services Report           #
	#####################################
	
	
	my @services_report;
	my $services_row; 
	
	my $skey; 
	my $svalue;
	my $using; 
	my @skeys = sort(values %SERVICES); 

	%SERVICES = reverse(%SERVICES);
    
	push(@services_report, scalar(localtime)); 
	push(@services_report, $everyone); 
	

	# ooook. foreach(keys  %$count_services_ref){}
	
	foreach $skey (@skeys){ 
		$svalue = $count_services_ref -> {$skey}; 
		if($SERVICES{$skey} ne "Other"){
			push(@services_report, $svalue);           
	    }
	}

	$svalue = $count_services_ref -> {'Other'}; 
	push(@services_report, $svalue);  

	
    $services_row = join("\t", @services_report); 
	
	my $services_file_name = "$Stat_Dir/$list-services.txt"; 
	open (SERVICES, ">>$services_file_name") or 
	die "couldn't open $services_file_name for appending: $!\n";
	flock(SERVICES, 1); 
	print SERVICES $services_row, "\n"; 
	close (SERVICES); 	
}

=pod

=head1 COPYRIGHT

Copyright (c) 1999-2008 

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
