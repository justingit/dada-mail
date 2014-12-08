#!/usr/bin/perl 

use strict; 

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";
BEGIN { 
	my $b__dir = ( getpwuid($>) )[7].'/perl';
    push @INC,$b__dir.'5/lib/perl5',$b__dir.'5/lib/perl5/x86_64-linux-thread-multi',$b__dir.'lib',map { $b__dir . $_ } @INC;
}


use Getopt::Long; 

use DADA::App::Guts; 

use DADA::MailingList::Settings; 

use DADA::Config qw(!:DEFAULT); 

my $verbose; 
my $archive; 
my $list; 


GetOptions( 
           "verbose"    => \$verbose, 
		   "archive"    => \$archive, 
		   "list=s"     => \$list,

		); 	
		
my $msg  = join('', (<STDIN>));


&main(); 


sub main(){ 

    if(validate_list($list) eq undef){
    
        warn "List $list does not exist.";
        exit (1); 
    
    }
    else { 
    
        deliver($list, $msg); 
    
    
    }
}




sub validate_list { 

    my $list = shift; 
    
    my $list_exists = check_if_list_exists(-List => $list);


    if($list_exists == 0){ 
    
        return undef; 
    
    } 
    else {
    
        return 1;
    
    }
}




sub deliver { 

    my ($list, $msg) = @_; 
     
    require DADA::App::FormatMessages; 
    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $fm = DADA::App::FormatMessages->new(-List => $list); 
       $fm->mass_mailing(1); 
		
       
    
    my ($final_header, $final_body) = $fm->format_headers_and_body(-msg => $msg );
            
    require DADA::Mail::Send;
           
    my $mh      = DADA::Mail::Send->new(
				  	{
						-list   => $list, 
						-ls_obj => $ls, 
					}
				 );
    
    my %headers = $mh->return_headers($final_header);
    
    my %mailing = (%headers,
                   Body      =>  $final_body,
                   ); 
          
    my $message_id = $mh->mass_send(%mailing);
    
    

# This parts archiving:    
    
     require DADA::MailingList::Archives;
            
            my $archive = DADA::MailingList::Archives->new({-list => $li});
              
              # For now, there's a bug, that won't allow you to snatch this saved message, until sending *starts* which it won't, if you go over queue. Doh! 
              # $archive->set_archive_info($message_id, $headers{Subject}, undef, undef, $mh->saved_message);    
               
# This needs to go away when this bug: 
# Has been resolved: 
# https://sourceforge.net/tracker/index.php?func=detail&aid=1706307&group_id=13002&atid=113002

            %mailing = $mh->clean_headers(%mailing); 
                    
            %mailing = (
                        %mailing,
                        $mh->_make_general_headers, 
                        $mh->list_headers
                   ); 
                    

                    
                    $mh->saved_message($mh->_massaged_for_archive(\%mailing)); 
                    
                    $archive->set_archive_info($message_id, $headers{Subject}, undef, undef, $mh->saved_message);    
    
# / End # This needs to go away                
}


=pod

=head1 NAME

send_dada_mail.pl - a small extension that allows you to send a mailing list message out from the command line.

=head1 VERSION

Refer to the version of Dada Mail you're using - NEVER use a version of this proggy with an earlier or later version of Dada Mail. 

Saying that, this extension is a work in progress, and probably breaks all over the place. 

=head1 USAGE

This program is supposed to be used similar to how the sendmail utility is to be used - although it's not (in no way, shape or form) a sendmail command B<replacement>. No. 

Anyways, you can use it via the command line by calling it up: 

 
    prompt:] /home/account/cgi-bin/dada/extensions/send_dada_mail.pl --list mylist

And type out your message: 

 Subject: This is my subject!
 
 This is my message!
 
 -- Justin
 ^D


The, B<message> part of this should be a full on email message, headers and all. As the above example shows, you can just place in the headers you'd B<like> to have and any missing fields will be filled in intelligently for you. One header I'd make sure to put in is the B<Subject:> header. 

Skip B<two> new lines and start entering your actual message. 

Like the sendmail command, it's real use is when you call it in another script. In Perl, that would look like this: 


 #!/usr/bin/perl
 
	open( DADA, "|/home/youraccount/cgi-bin/dada/extensions/send_dada_mail.pl --list mylist") or die $!;
	print DADA "Subject: This is my subject!\n\n";
	print DADA "This is my message!\n\n";
	print DADA "-- Justin";
	close DADA or die $!;


=head1 REQUIRED ARGUMENTS

As you'll notice from these examples, the, B<--list> flag is being passed, and the parameter is set to a B<valid list short name> 

If this parameter is missing, or the list short name is not valid the script will exit with an C<exit> status of, C<1> and you won't be sending anything. 

=head1 OPTIONS

Currently, the only flag that's accepted is the B<--list> flag. 

=head1 DIAGNOSTICS


=head1 CONFIGURATION AND ENVIRONMENT

You probably want to set the explict paths to your Dada Mail libraries. 

For example, if your Dada Mail installation is at: 

 /home/account/cgi-bin/dada

Your Dada Mail libraries would be at: 

 /home/account/cgi-bin/dada

and: 

 /home/account/cgi-bin/dada/DADA/perllib

The following lines on top of this script would be changed from: 


	use lib qw(

	../
	../DADA
	../DADA/perllib

	);

to: 

	use lib qw(

	../
	../DADA
	../DADA/perllib

	 /home/account/cgi-bin/dada
	 /home/account/cgi-bin/dada/DADA/perllib
 
	); 

=head1 DEPENDENCIES


=head1 CAVEATS

=head2 Dada Mail 3.x/4.x support

I haven't tested this with Dada Mail 3.x yet (or 4.x). Does it work well? 

=head2 SECURITY 

Currently, there's not much security in this script - only the check for a valid list short name. Normally, you'd have to either log into the List Control Panel to send a message out, which requires a password, or, use the Bridge Plugin, which has it's own slew of checks. 

Because of that, I'd only use this script where you're mighty sure that abuse will not happen (ha.). Abuse of this extension is quite possible and very easy, as you're giving the option of any program to send to any Dada Mail-administrated list as much as it would like. You see where I'm going here with this. OK? Ok. 

Future versions will most likely have some semblance of security and feedback (general) about this extension is more than welcome. 

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENSE AND COPYRIGHT

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut







