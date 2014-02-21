#!/usr/bin/perl 

use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard); 
$|++; 
print header(); 
print '<pre>'; 
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


use DADA::Config; 

use DADA::App::Guts; 
my @lists = available_lists(); 

use DADA::Logging::Clickthrough; 

print "starting!\n\n"; 
# some sort of check to make sure we're usign the SQL backend... 
foreach my $list(@lists){ 
	print "working on: $list \n"; 
	
	my $dlc = DADA::Logging::Clickthrough->new({-list => $list});
	# name-clickthrough.log
	my $cl_logging_file = make_safer(
			$DADA::Config::LOGS . '/' . $list . '-clickthrough.log'
		);
	
	  if ( -e $cl_logging_file ) {
        open( LOG,
            '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',
            $cl_logging_file
          )
          or croak "Couldn't open file: '"
          . $cl_logging_file
          . '\'because: '
          . $!;
        while ( defined( $l = <LOG> ) ) {
            chomp($l);

			my ( $t, $mid, $url, $extra ) = split( "\t", $l, 4 );

            $t     = strip($t);
            $mid   = strip($mid);
            $url   = strip($url);
            $extra = strip($extra);

			next if ! $mid;  
			next unless($dlc->verified_mid($mid)); 



            if (   $url ne 'open'
                && $url ne 'num_subscribers'
                && $url ne 'bounce'
                && $url ne 'hard_bounce'
                && $url ne 'soft_bounce'
                && $url ne undef )
            {
				# Clickthrough! 
                # $report->{$mid}->{count}++;
				$dlc->r_log(
					{
						-timestamp   => convert_timestamp($t), 
						-mid         => $mid, 
						-url         => $url, 
						-remote_addr => undef, 
					}
				); 
            }
            elsif ( $url eq 'open' ) {
                $dlc->open_log(
					{
						-timestamp   => convert_timestamp($t), 
						-mid         => $mid, 
						-remote_addr => undef, 
						
					}
				);
            }
            elsif ( $url eq 'soft_bounce' ) {
                $dlc->bounce_log(
					{
						-timestamp   => convert_timestamp($t), 
						-mid         => $mid, 
						-type        => 'soft', 
						-email       => $extra, 
						-remote_addr => undef, 
						
					}
				);
            }
            elsif ( $url eq 'hard_bounce' || $url eq 'bounce') {

                $dlc->bounce_log(
					{
						-timestamp => convert_timestamp($t), 
						-mid         => $mid, 
						-type        => 'hard', 
						-email       => $extra, 
						-remote_addr => undef, 
						
					}
				);

            }
            elsif ( $url eq 'num_subscribers' ) {				
				$dlc->num_subscribers_log(
					{
						-timestamp => convert_timestamp($t), 
						-mid       => $mid, 
						-num       => $extra, 
					}
				);
            }
			else { 
				print "Skipping: $t\n"; 
			}
			print "Finished: $t\n"; 
        }
        close(LOG);

	}
	else { 
		print "No clickthrough logs available for: $list\n\n"; 
	}
}

print "Done!\n"; 
print '</pre>'; 
sub convert_timestamp { 
	my $ts = shift; 

	my %lt = (
	Jan => '01', 
	Feb => '02', 
	Mar => '03', 
	Apr => '04', 
	May => '05', 
	Jun => '06', 
	Jul => '07', 
	Aug => '08', 
	Sep => '09', 
	Oct => '10', 
	Nov => '11', 
	Dec => '12', 		
	); 


	my @s = split(' ', $ts);
	return $s[4] . '-' . $lt{$s[1]} . '-' . $s[2] . ' ' . $s[3];
}



=pod

=head1 dada_clickthrough_plaintext_to_sql.pl

=head1 Description

C<dada_clickthrough_plaintext_to_sql.pl> migration script converts your Dada Mail List Clickthrough Logs from the Default backend, to one of the SQL backends. 

The Default backend for the Clickthrough Log is going to be a plaintext file. 

C<dada_clickthrough_plaintext_to_sql.pl> is to be used I<after> you have reconfigured Dada Mail to use one of the SQL backends - you'll most likely do this via the Dada Mail installer. Once you have reconfigured your Dada Mail, none of your previous mailing lists will be available, until after you run this migration script. 

This script may also be used, even though you have always run the SQL backend, since the Clickthrough Tracking extension have historically  
kept Clickthrough logs in PlainText format. The Clickthrough Tracking extension was superceded by the Tracker plugin in v4.5.0 of Dada Mail. So, if you are upgrading a Dada Mail, with an SQL from a version of v4.5.0 and want to migrate over your Clickthrough logs, use this script. 

Before running this migration script, please make sure to backup your important Dada Mail files/information, most notably, the B<.dada_files> directory. 

=head1 Configuration

No configuration will need to be done in this script itself. The permissions of this script simply need to be set to, C<755>.

=head1 Using

Visit C<dada_clickthrough_plaintext_to_sql.pl> in your web browser, or run the script via the command line. Make sure to B<only run this script once>, or data will be duplicated. 

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