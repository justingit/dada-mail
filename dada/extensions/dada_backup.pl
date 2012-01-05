#!/usr/bin/perl 

=pod

=head1 NAME

dada_backup.pl - a simple list backup utility for Dada Mail

=head1 Directions: 

=over

=item Where are your Perl Libraries? 

Since this script is supposed to be run via a cron job, (although it 
will work fine using from the command line) you usually have to type 
the entire path to your Perl Libraries. 

example: 

	use lib '/usr/local/lib/perl5/site_perl/5.005/';	

=cut

use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);

=pod

=item Where are Dada Mail's Libraries? 

Dada Mail uses variables that are located in the Config.pm file 
to figure out where the lists are, among other things. 

example:

	use lib '/usr/home/account/public_html/cgi-bin/dada'; 

=cut

use lib qw(
/usr/home/account/public_html/cgi-bin/dada
/usr/home/account/public_html/cgi-bin/dada/DADA
/usr/home/account/public_html/cgi-bin/dada/DADA/perllib
);

=pod

=item Where are the backup files going? 

Makes sure this script has  read and write permisssions to this directory

example:

	my $backup_lists = '/home/account/.dada_files/.backups'; 

=cut

my $backup_lists = '/home/account/.dada_files/.backups'; 

=pod

=item Where is the backup log? 

dada_backup.pl will keep a log of what it's doing so you're not left in the dark if 
something goes awry

example:

	my $dada_backup_log = "$backup_lists/dada_backup.log"; 

=cut

my $dada_backup_log = "$backup_lists/dada_backup.log"; 

=pod


=item When should dada_backup.pl remove old files? 

It'll remove EVERYTHING in the $backup_lists directory except the backup log, 
if it finds it. This is in days:

example:

	my $remove_after = 1; 

=cut

my $remove_after = 7; 

=pod

=item  How do you want your backup lists named?

Things in brackets will be replaced with what they really are, so 
[year] will be replaced with 2001, etc

you have 

	[list_name] [year] [month] [day] [hour] [minute] [second]

to choose from

example:

	my $backup_name = '[list_name].list-[year][month][day][hour][minute][second]';

=cut
 
my $backup_name = '[list_name].list-[year][month][day][hour][minute][second]';

=pod

=item Want to send this backup report to someone?

place their e-mail address in this variable, and they'll get a copy as well

example:

	my $email_log_to = 'you@here.com'; 

=cut

my $email_log_to; 

=pod

=item Echo? 

Finally, if you run this script interactively quite a bit, you may want 
to have a copy of the report printed out  in the terminal, so you can 
figure out what's going on, just set this variable to 1;

example: 

	my $echo_log = 0; 


=back 

=cut

my $echo_log = 1; 

#
############################################################################
# That's it, everything after this isn't servicable						   #
############################################################################

my $Version = 1.2; 


# load some needed modules.. 
use DADA::Config; 
use DADA::App::Guts; 
use Fcntl;
use Time::Local; 
use File::Copy; 
use strict; 

# open the log for logging
open_log($dada_backup_log); 


# get a list of the lists (har har) 
my @lists = available_lists(); 
my $email_log; 

# get what time is it (4:30) 
my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];

# make a few changes for good looks
my $t_month  = $month + 1; 
my $t_year   = $year  + 1900; 
my $t_min    = $min; 
my $t_sec    = $sec; 
   $t_min    = "0$min" if ($min < 10); 
   $t_sec    = "0$sec" if ($sec < 10); 

# how many lists do we have? 
my $list_num = $#lists+1;

# start logging
print_log("$PROGRAM_NAME List Backup ver. $Version \n It is: $t_month/$day/$t_year $hour:$t_min:$t_sec"); 
print_log("======================================================================");
print_log("There are $list_num lists to backup-\n"); 


# for all out lists ...  
foreach my $list_file(@lists){ 

   	# where's the original file? 
   	my $orig_file   = "$FILES/$list_file.list";
   	
   	# what is the backup file looking like? 
   	my $backup_file = $backup_name; 
     
    # fill in the template
    $backup_file =~ s/\[list_name\]/$list_file/i; 
    $backup_file =~ s/\[year]/$t_year/i; 
    $backup_file =~ s/\[month\]/$t_month/i; 
    $backup_file =~ s/\[day]/$day/i; 
    $backup_file =~ s/\[hour\]/$hour/i; 
    $backup_file =~ s/\[minute\]/$t_min/i; 
    $backup_file =~ s/\[second\]/$t_sec/i; 
     
    # find how big this list is
    my $old_size = (stat($orig_file))[7];

	print_log("Backing up: $orig_file"); 
	print_log("            ($old_size bytes)"); 


    # this is the internal method
	#list_copy($orig_file, $backup_file);
    
    # this is the File::Copy method
    copy($orig_file, $backup_lists .'/'.$backup_file);

    # so, what's the new size? 
	my $new_size = (stat($backup_lists .'/'.$backup_file))[7];

	print_log("To:         $backup_file  "); 
	print_log("            ($new_size bytes)"); 
     
    # if its not the same, tell someone
	if($new_size < $old_size){ 

		my $dif = $old_size - $new_size; 
   		print_log("WARNING! new file is $dif bytes smaller..."); 

	}else{ 
        
        # good job!
		print_log("Backup successful!\n");

	} 

}

print_log("\nRemoving all backup files that are $remove_after day(s) old.\n"); 

# now we'll remove the lists that are getting a bit old there. 
my $count = 0; 

opendir(BACKUPLISTS, $backup_lists) or die "$PROGRAM_NAME $VER erro, can't open $backup_lists to read: $!"; 
my $this_list; 
while(defined($this_list = readdir BACKUPLISTS) ) { 

	#don't read '.' or '..'
	next if $this_list =~ /^\.\.?$/;
  
    # don't clobber the log file! 
    next if("$backup_lists/$this_list" eq $dada_backup_log); 
    
    # next if file is a directory,  
    next if     -d "$backup_lists/$this_list"; 
     # next unless file is a plain file
    next unless -f "$backup_lists/$this_list"; 
     
    # this is how many seconds since 1970  
  	my $epoch = timelocal($sec, $min, $hour, $day, $month, $year); 

    # how old is our file? 
	my $file_age = (stat("$backup_lists/$this_list"))[9]; 
	    
	   # 
	   $file_age = $epoch - $file_age; 

	my $reaper = $remove_after * 86400; #seconds in a day
        
	if($file_age >= $reaper){ 

		# say goodbye...
		print_log("Removing $this_list ($file_age seconds old)"); 
		unlink("$backup_lists/$this_list"); 
		print_log("Removal Successful.\n"); 
        $count++; 
	}
	
	
	
	
	
}

if($count > 0){ 

	print_log("$count backup lists have been removed."); 

}else{ 

	print_log ("No backup lists had to be removed."); 

}

print_log("\n Backup Complete."); 
print_log("======================================================================\n");


# close the log, send the email if we have to
close_log(); 


sub open_log { 
	my $location = shift; 
	
	open(Log, ">>$location") 
		or die "$PROGRAM_NAME $VER Error: Could not open back up log file, quitting: $!";
	
	}
	
sub print_log { 
	
	my $entry = shift; 
	print Log $entry, "\n"; 
	 
	print $entry, "\n" if $echo_log == 1; 
	
	$email_log .= "$entry \n" 
		if defined($email_log_to) && $email_log_to ne ""; 

}

sub close_log { 

	close (Log); 
	
	if(defined($email_log_to) && $email_log_to ne ""){ 
	
#
#		require DADA::Mail::Send; 
#		my $mh = DADA::Mail::Send->new(); 
#		
#		my $body = $email_log . 
#		           "\n\n"     . 
#		           '-' . $PROGRAM_NAME .
#		           "\n";
#
#		$mh->send( 
#			To       =>  $email_log_to,
#			From     =>  $email_log_to, 
#			Subject  => "$PROGRAM_NAME List Backup Report $t_month/$day/$t_year $hour:$t_min:$t_sec", 
#			Body     =>  $body
#		); 
#		
	
	}


}

=pod

=head1 Changes


=head2 Version 1.2

commented out the list_copy subroutine... since, it wasn't being used anyways!

=head2 Version 1.1

Changes were made to the script to specifically not look at directories. The problem is, 
as of version 2.8.12 of the script, a backup directory could in fact have a backup directory per list
with list setting and archive information, that would muck up this script. In the future, more integration 
should be done with this script and the other backup model. 


=head1 AUTHOR

Justin Simoni

creative@justinsimoni.com

http://justinsimoni.com

=head1 COPYRIGHT 

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

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
