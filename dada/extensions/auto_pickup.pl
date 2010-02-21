#!/usr/bin/perl -w
use strict; 

$|++; 

use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);

BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}



use CGI::Carp qw(fatalsToBrowser); 



use Getopt::Long;

my $verbose = 1; 

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use DADA::Mail::MailOut; 



if(!$ENV{GATEWAY_INTERFACE}){ 
    # this (hopefully) means we're running on the cl...

} else { 

    require CGI; 
    my $q = new CGI; $q->charset($DADA::Config::HTML_CHARSET);
       $q = decode_cgi_obj($q);
    print $q->header();
    if(defined($q->param('verbose')) == 1){ 
        $verbose = $q->param('verbose');
    }
  
    
    if($verbose == 1){ 
        print '<pre>'; 
    }
}



GetOptions(
    "verbose"    => \$verbose
);

DADA::Mail::MailOut::monitor_mailout({-verbose => $verbose}); 


=head1 NAME

auto_pickup.pl - A small extension to monitor mailings and auto reload them if they seem to have fallen off the wayside. 

This script can easily be run this as a CGI script in your web browser  or via the command line. 

The main intention of this script is to have it be run via a cronjob. 

=head1 VERSION

Refer to the version of Dada Mail you're using - NEVER use a version of this program with an earlier or later version of Dada Mail. 

=head1 USAGE

This little program can be used two ways: 

=over

=item * Use it like a cgi script. 

Put it in your, B<extensions> directory (ala: cgi-bin/dada/extensions), chmod 755, visit it in your web browser.

=item * Use it like a command line script 

Change into the directory it's located in, and type: 

 ./auto_pickup.pl

This script takes B<one> argument: C<--verbose>. Tack that flag on: 

 ./auto_pickup.pl --verbose

and you'll receive a nice printout. Call it without any arguments and it won't return anything - it'll just run, and exit. Good for a cronjob.


=back

=head1 REQUIRED ARGUMENTS

There are no required arguments.  

=head1 OPTIONS

=over

=item --verbose

As explained, prints out what's goin' on. Probably a good option to use, if you've never used this specific extension. 

=back

=head1 DESCRIPTION

Mailing to your entire list in Dada Mail can take a long time - hours even. Sometimes - and depending on your hosting account setup, this process can go on longer than the server allows a process to run. 

Dada Mail itself is written to understand this problem and to work around it, but keeping exact track on where in the mass mailing it is and then being able to, "pick up" the mass mailing from the exact point it was, "dropped". 

Since Dada Mail does not run continuously itself, you do need to monitor the sending process for this "auto pick up" to work. 

One way is to keep the, Sending Monitor open in the List Control Panel. This works great, but has the problem of you always having to have your web browser open, your computer on, your computer to be connected to the internet, etc.  Tak about a kludge. 

Another way to use this very little extension script. 

We highly highly recommend using this very little extension script. 

Having this script run every 5 minutes or so should relieve you of having to monitor your mailing yourself and should stop you from worrying about a long-running mass mailing process. 

=cut

#(I'm not sure about this, yet) 
#
#=head2 Step by Step Installation
#
#The C<auto_pickup.pl> extension can be found in the, I<dada/extensions> directory of the Dada Mail distribution. To install, upload a copy of this extension into your, I<dada/extensions> directory, which is in your C<cgi-bin> (if it's not already in there). 
#
#Change the permissions of the script to, C<755> and run the script in your web browser. 

=pod

=head1 CONFIGURATION AND ENVIRONMENT

We've tried to make this script as easy as possible to get up and running, in hopes you'll take advantage of it. 

There is no configuration needed to be done. 

=head2 Running the script via a cronjob

There's two ways you can run this script as a cronjob, either directly or by accessing it like you would in a web browser. 

=head3 Running the extension directly

To use this style, you'll have to know the absolute path to your, I<dada/extensions> directory. For example: 

I</home/myaccount/cgi-bin/dada/extensions>

Is an example of an absolute path to an I<dada/extensions> directory. 

I</home/myaccount> is the path to my home directory. In my home directory, lives my I<cgi-bin> directory and inside that directory, is my I<dada> directiory, which, in turn, holds the I<extensions> directory. Hazzah!

These paths, especially the path to your home directory are going to be unique to your hosting account setup, so make sure to figure out yours is configured to be, exactly. 

To run this extension every 5 minutes, your cronjob will look like this: 

*/5 * * * * cd /home/myaccount/cgi-bin/dada/extensions; /usr/bin/perl ./auto_pickup.pl

If you have ssh access to your hosting account, you can test if you have the right commands that make up the cronjob by running the command right on the command line: 

 prompt>cd /home/myaccount/cgi-bin/dada/extensions; /usr/bin/perl ./auto_pickup.pl

If nothing gets printed, you probably have it installed correctly. To be sure, use the C--verbose> flag: 

 prompt>cd /home/myaccount/cgi-bin/dada/extensions; /usr/bin/perl ./auto_pickup.pl --verbose

You should get a report on any mass mailings that are going out and their status. 

=head3 Running the extension via curl

The second style is to use something like, C<curl> to access the extension, much like you would in your web browser. 

In these examples, I'm using, 

I</usr/bin/curl> 

as my path to curl. You'll want to double-check what your path to curl is. 

In my below examples, the URL to this extension is: 

I<http://example.com/cgi-bin/dada/extensions/auto_pickup.pl>

You'll want to replace this with your actual URL to this script. To double check, just visit this URL in your web browser. 

To run this extension every 5 minutes, your cronjob will look like this: 

 */5 * * * * /usr/bin/curl http://example.com/cgi-bin/dada/extensions/auto_pickup.pl

You may receive the verbose printout using this method, so you may want to pass the, "verbose" paramater. This should work: 

 */5 * * * * /usr/bin/curl http://example.com/cgi-bin/dada/extensions/auto_pickup.pl?verbose=0

If not, try this: 

 */5 * * * * /usr/bin/curl -s --get --data verbose=0  --url  http://example.com/cgi-bin/dada/extensions/auto_pickup.pl

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 SEE ALSO

The Mailing List Sending FAQ has a whole lot of information about Dada Mail's Mailing Monitor, Auto-Pickup features and Batch Sending:

L<http://dadamailproject.com/support/documentation/FAQ-mailing_list_sending.pod.html>

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Justin Simoni All rights reserved. 

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
