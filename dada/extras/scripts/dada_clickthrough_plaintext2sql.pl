#!/usr/bin/perl 

use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard); 
$|++; 
print header(); 
print '<pre>'; 
use lib qw(
./
./DADA/perllib	

../../
../../DADA/perllib
);

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
                $dlc->o_log(
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
               #  $report->{$mid}->{num_subscribers} = $extra;
				$dlc->sc_log(
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

=head1 dada_clickthrough_plaintext2sql.pl

=head2 Description

This script is used to import data from the B<plaintext> backend used by the Clickthrough Tracking (any version of Dada Mail) 
extension or the Tracker plugin to the SQL backend. 

=head1 Usage

Docs on how to move from the default backend of Dada Mail to one of the SQL backends is covered in length here: 

L<http://dadamailproject.com/support/documentation-4_7_0/FAQ-default_2_SQL_backend.pod.html>

This script should be run once you have moved over your backend from the Default to the SQL backend, NOT before. 

You may also use this script, even though you have always run the SQL backend, since the Clickthrough Tracking extension always 
kept its logs in PlainText format. The Clickthrough Tracking extension was superceded by the Tracker plugin in v4.5.0 of Dada Mail. 

B<Change the permissions> of this script to, B<755>

Visit this script in your web browser. 

=head1 See Also

=over

=item * The docs for the Tracker plugin

L<http://dadamailproject.com/d/tracker.cgi.html>

=back

=cut