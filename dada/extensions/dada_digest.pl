#!/usr/bin/perl

# use CGI::Carp "fatalsToBrowser"; 

my $Digests = [ 
	{
		List_Name         => 'list_name', 
		Digest_List_Name  => 'digest_list_name',
		Message_History   =>  24, # in hours;
	},
];


use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);


=pod

=head1 NAME dada_digest.pl

=head1 DESCRIPTION 

Creates a digest message from one list, to be sent to another list. 

=head1 INSTRUCTIONS

dada_digest.pl is designed to be called from the command line or a cron
job. It is not a cgi script.

=head1 INSTALLATION

=head2 SETTING UP A DIGEST

To set up a digest, You need to have two lists, a list to grab the
messages to be digested from and a list to send the digest. I made a
list with a shortname of 'test' and another with a shortname of 
'digest_test'

People who want to have every single message sent to them would want to
subscribe to 'test', people who want the digest would want to subscribe
to 'digest_test'

I then have to decide what sort of time span I want to send my digest. 
I'm thinking every day will work for me. 

Now, dada_digest.pl needs to know all of this. On the top of the script
itself is a variable called '$Digests'. To put the above information
that I just worked out into $Digests, I'd write: 

	my $Digests = [ 
	{
	List_Name         => 'test', 
	Digest_List_Name  => 'digest_test',
	Message_History   =>  24, 
	},
	];

Message_History work in hours, so one day equals 24 hours. 

If I had another list, called "ramblings" and a list for digests called
"digest_ramblings", that I wanted sent every 3 hours, I'd put that
after my first one: 

	my $Digests = [ 
	{
	List_Name         => 'test', 
	Digest_List_Name  => 'digest_test',
	Message_History   =>  24,
	},
	{
	List_Name         => 'ramblings', 
	Digest_List_Name  => 'digest_ramblings',
	Message_History   =>  3,
	},
	];
	


Upload dada_digest.pl to your hosting account. I recommend NOT putting 
this script in your cgi-bin, simply because it isn't a cgi-script.
You may want to make a directory for dada scripts like this one in your home account: 

 mkdir /home/account/dada_scripts

B<Putting this script in your cgi-bin would probably constitute a security threat!>  

change the permissions of dada_digest.pl to 755.  

To use this script, simple run it: 

 >perl dada_digest.pl

That's the essence of it. 

=head2 OPTIONS

=over

=item --test

running dada_digest.pl with the test option will only send out the 
digest to the list owner. Very handy for testing purposes. 

 >perl dada_digest.pl --test

=item --reset listname

This takes a bit of explaination, but it basically resets the time
dada_digest.pl remembers when it last sent out a digest. If I send out 
a digest ever day, dada_digest.pl will remember this and won't send out
a message in a digest it has already sent. This will make 
dada_digest.pl forget this. 

 >perl dada_digest.pl --reset listname

listname is the shortname of the list you're grabbing the messages to be
digested, not the digest list 

=back

=head2 Setting up a Cron Tab

You're most likely going to run dada_digest.pl via a crontab. Here's an
example of one: 

 0 0,3,6,9,12,15,18,21 * * * /home/account/dada_scripts/dada_digest.pl 

This will run the script every 3 hours to check if any digests need to 
be sent out. 

=cut




#---------------------------------------------------------------------#




use strict;

use DADA::Config 5.0.0 qw(!:DEFAULT);

use DADA::App::Guts;
use DADA::MailingList::Archives;
use DADA::Mail::Send;
use DADA::Logging::Usage;

use Time::Local;
use Getopt::Long; 

my $Time = $^T;
my $log  =  new DADA::Logging::Usage;

my $reset;
my $test                   = 0;
my $verbose                = 0; 
my $munge_last_digest_time = 0; 
my $send_to                = undef; 


GetOptions("reset=s"                => \$reset,
		   "verbose"                => \$verbose,
		   "munge_last_digest_time" => \$munge_last_digest_time, 
		   "test"                   => \$test,
		   "send_to=s"              => \$send_to, 

		   ); 
		   
		   

$verbose = 1 if $test == 1; 

GetOptions("reset=s"  => \$reset, 
			"test"    => \$test); 
			
#
#	if(!$ENV{GATEWAY_INTERFACE}){ 
#
#	}else{ 
#		require CGI;
#		
#		my $q = new CGI; 
#		   $q->charset($DADA::Config::HTML_CHARSET);
#		   
#		print $q->header();
#		print $q->p('starting...'); 
#		print '<pre>';
#		$test = 1; 
#		
#	}




			
if($reset){ 
	reset_digest_time($reset);
}else{
	main();
}

#---------------------------------------------------------------------#





sub main { 
	foreach my $profile (@$Digests){ 
		if(profile_check($profile) == 1){ 
			send_digest($profile);
		}
	} 
}





sub profile_check { 
	my $profile = shift; 
	my $check   = 1;
	foreach('List_Name', 'Digest_List_Name'){ 
		if(check_if_list_exists(-List => $profile->{$_}) == 0){ 
			print  $profile->{$_} . " does not exist!\n"
				if $verbose;
			print $profile->{$_} . " does NOT exist! Bad!\n" 
				if $verbose; 
			return 0; 
		}else{ 
			print $profile->{$_} . " is a valid listshortname...\n" 
				if $verbose;
		}
	}	
	return $check;
}





sub send_digest { 
	my $profile = shift; 
	my %list_info        = open_database(-List => $profile->{List_Name}); 
	my %digest_list_info = open_database(-List => $profile->{Digest_List_Name}); 
	my $archive          = DADA::MailingList::Archives->new({-list => $list_info{list}});
	
	my $span = int($list_info{last_digest_sent}) + (int($profile->{Message_History}) * 3600); # 3600 seconds in an hour 
	
	print 'Time between Digests (in seconds): ' . $span . " seconds \n" 
		if $verbose; 
	
	print "Munging time difference by " . (int($profile->{Message_History}) * 3600) . " Seconds...\n" 
		if $verbose && $munge_last_digest_time; 
		
	if($munge_last_digest_time){ 
			$span = int($list_info{last_digest_sent}) - (int($profile->{Message_History}) * 3600); # 3600 seconds in an hour 
	}
	
	
	if($Time > $span){ 
		
		my $t = relative_keys(\%list_info, $profile, $archive, $profile->{Message_History});
		if($t->[0]){ 			
			my $digest_index = digest_index(\%list_info, $profile, $archive, $profile->{Message_History}); 
			my $digest_body  = digest_body(\%list_info, $profile, $archive, $profile->{Message_History}); 
			
			my $body = 'In this issue' . "\n\n" . $digest_index . "\n\n" . $digest_body;
			   $body = safely_encode($body); 
		       
		       #$body = create_message($body, \%digest_list_info);


			require MIME::Lite;			
			$MIME::Lite::PARANOID = $DADA::Config::MIME_PARANOID;
			my $msg = MIME::Lite->new(
									  Type      => 'text/plain', 
									  Data      => $body, 
									  Encoding  => 'quoted-printable', 
									  Subject   => 'blank',   
									  Datestamp => 0, 
									); 
									
			my $msg_as_string = (defined($msg)) ? $msg->as_string : undef;
			
			#$msg->attr('content-type.charset' => 'UTF8');
			    
			require DADA::App::FormatMessages;
			my $fm = DADA::App::FormatMessages->new(-List => $profile->{Digest_List_Name}); 
			   $fm->mass_mailing(1);
			my ($final_header, $final_body) = $fm->format_headers_and_body(-msg => $msg_as_string);

			print '$profile->{List_Name} ' . $profile->{List_Name}; 
			print "\n"; 
			print '$profile->{Digest_List_Name} ' . $profile->{Digest_List_Name}; 
			
			my $mh = DADA::Mail::Send->new(
						{
							#-list => $list_info{list}, 
							-list  => $profile->{Digest_List_Name}, 
						}
					);


			  my %headers = $mh->return_headers($final_header);

			   print "Sending as a test message\n" 
			    	if $verbose;
			   
			   if($send_to){ 
			   	print "Sending test message ONLY to: $send_to...\n"; 
			   
			   		$mh->send( 
						%headers,
						To      => $send_to, 
						Subject => $list_info{list_name} . ' Digest', 
						Body    => $final_body
					);	
					
			   }else{ 
			   
			   
				   $mh->mass_test(1) if($test == 1);
				   
				   
				   $mh->mass_send( 
						%headers,
						Subject => $list_info{list_name} . ' Digest', 
						Body    => $final_body
					);	

				}
			
			
			$log->mj_log($list_info{list}, 'digest_sent');    
			
			if($test != 1){ 	
				my $status = setup_list({list            => $list_info{list}, 
										last_digest_sent => $Time});		
				warn "last digest time not saved correctly!" if $status == 0; 
			}
			
		}else{
			$log->mj_log($list_info{list}, 'digest_not_sent', "Reason: No messages to send, $#$t");  
			print "no messages to send a digest too! Time: $Time, Span: $span\n" 
				if $verbose; 
		}
	}else{ 
		print "no message to send - Reason: Didn't need to, $Time < $span \n" 
			if $verbose; 
		
		$log->mj_log($list_info{list}, 'digest_not_sent', "Reason: Didn't need to, $Time < $span");    	
	}
}





sub digest_index { 
	my ($list_info, $profile, $archive, $profile_history) = @_;
	
	my @subjects;
	my $index; 
	my $keys    = relative_keys($list_info, $profile, $archive, $profile_history);
	
	foreach my $k (@$keys){ 
		my $subject = $archive->get_archive_subject($k);
		chomp($subject); 
		   
		push(@subjects, $subject); 
	}
	
	my $i = 0; 
	foreach(@subjects){ 
		$i++;
		$index .= '    ' . $i . ': ' . $_ . "\n";
	}
	return $index; 
}




sub digest_body { 
	my ($list_info, $profile, $archive, $profile_history) = @_;
	
	my $body;
	my $index; 
	my $keys = relative_keys($list_info, $profile, $archive, $profile_history);
	
	foreach my $k (@$keys){ 
		my ($subject, $message, $format) = $archive->get_archive_info($k);
		my ($year, $month, $day, $hour, $minute, $sec) = archive_time($k);
		
		#$message = $archive->zap_sig($message); 
		
		#$message = $archive->_zap_sig_plaintext($message); 

		my $good_message = $archive->massaged_msg_for_display(-key            => $k, 
													          -plain_text     => 1,
													          -body_only      => 1,
													          -entity_protect => 0, 
													         );
		$good_message = safely_decode($good_message);
		$subject      = safely_decode($subject);

		$body .= '-' x 72 . "\n\n";
		$body .= 'Date: ' . pretty_date($k) . "\n";
		$body .= 'Subject: ' . $subject . "\n\n";
		$body .= $good_message . "\n\n";
		
		$body .= "Original Message:\n$DADA::Config::PROGRAM_URL/archive/" . $list_info->{list} . '/' . $k . '/' . "\n\n";
	}
	
	return $body;
}




sub relative_keys {
	my ($list_info, $profile, $archive, $profile_history) = @_;
	my $keys = $archive->get_archive_entries('normal');
	my @r_keys;
	foreach my $p_num (@$keys) { 
		
		my ($year, $month, $day, $hour, $minute, $sec) = archive_time($p_num);
		my $c_time  = timelocal($sec, $minute, $hour, $day, $month, $year);	
		
		if($munge_last_digest_time){ 

			if($c_time > int($list_info->{last_digest_sent} - (int($profile_history) * 3600))){ 
				push(@r_keys, $p_num); 	
			}

				
		}else{ 
		
		
			if($c_time > int($list_info->{last_digest_sent})){ 
				push(@r_keys, $p_num); 	
			}
		
		}
	}
	return \@r_keys;
}




sub archive_time { 


	my $p_num     = shift;
	my $year      = substr($p_num, 0,  4)   || "";
	my $month     = substr($p_num, 4,  2)   || ""; 
	my $day       = substr($p_num, 6,  2)   || "";
	my $hour      = substr($p_num, 8,  2)   || "";
	my $minute    = substr($p_num, 10, 2)   || ""; 
	my $sec       = substr($p_num, 12, 2)   || "";

	$_      = int $_ for($year, $month, $day, $hour, $minute, $sec); 
	$year  -= 1900;
	$month -= 1; 
	return ($year, $month, $day, $hour, $minute, $sec);
}




sub pretty_date { 
	my $k = shift; 	
	my ($year, $month, $day, $hour, $minute, $sec) = archive_time($k);
	my $ending = 'am';
	 
	if($hour > 12){ 
		$hour = $hour - 12; 
		$ending = "pm";
	}
	
	$year += 1900;
	


	my %months = (
	'0'   =>    "January",
	'1'   => 	"February",
	'2'   => 	"March",
	'3'   => 	"April",
	'4'   =>	"May",
	'5'   =>	"June",
	'6'   =>	"July",
	'7'   =>	"August",
	'8'   =>	"September",
	'9'   => 	"October",
	'10'  => 	"November",
	'11'  => 	"December"
	);
	
	
	my %end = (
	1    => "1st",
	2    => "2nd",
	3    => "3rd",
	4    => "4th",
	5    =>	"5th",
	6    =>	"6th",
	7    =>	"7th",
	8    =>	"8th",
	9    =>	"9th",
	10   => "10th",
	11   => "11th",
	12   => "12th",
	13   => "13th",
	14   => "14th", 
	15   => "15th", 
	16   => "16th", 
	17   => "17th",
	18   => "18th", 
	19   => "19th", 
	20   => "20th", 
	21   => "21st", 
	22   => "22nd", 
	23   => "23rd",
	24   => "24th", 
	25   => "25th", 
	26   => "26th", 
	27   => "27th", 
	28   => "28th", 
	29   => "29th", 
	30   => "30th", 
	31   => "31st", 
	);
	
	my $date = ""; 
	   $date .= "$months{$month} "       ;#if $args{-Write_Month}   == 1; 
	   $date .= "$end{$day}, "           ;#if $args{-Write_Day}     == 1; 		
	   $date .= "$year "                 ;#if $args{-Write_Year}    == 1; 
	   $date .= "$hour:$minute"          ;#if $args{-Write_H_And_M} == 1; 
	 # $date .= ":$sec "                 ;#if $args{-Write_Second}  == 1; 
	   $date .= " $ending  "             ;#if $args{-Write_H_And_M} == 1; 
	return $date;
}


sub reset_digest_time { 
	my $list = shift; 
	if(check_if_list_exists(-List => $list) == 0){ 
		warn "$list does not exist!\n"; 
	}else{ 
		print "reseting digest time for '$list'\n";
		my $status = setup_list({last_digest_sent => 0});	
		warn "last digest time not saved correctly!" if $status == 0; 
		print "done.\n\n";
	}
}




sub open_database { 

	my %args = (
				-List => undef, 
				@_, 
			  ); 
			  
	my $list = $args{-List};

	require DADA::MailingList::Settings; 

	my $ls = DADA::MailingList::Settings->new({-list => $list}); 

	my $li = $ls->get(); 

	return %$li; 

}





sub setup_list { 

	my $vars = shift; 
	
	require DADA::MailingList::Settings; 
	
	 my $ls = DADA::MailingList::Settings->new({-list => $vars->{list}}); 
		delete($vars->{list}); 
	    $ls->save($vars); 
	   
}





=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2012 
Justin Simoni
me@justinsimoni.com http://justinsimoni.com

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

