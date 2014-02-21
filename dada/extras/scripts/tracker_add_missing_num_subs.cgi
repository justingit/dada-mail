#!/usr/bin/perl 


my $need_this_many_entries = 5; 



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
use Carp; 
#$Carp::Verbose = 1;
use CGI qw(:standard); 
use DADA::Config;
use DADA::App::Guts; 
use DADA::Logging::Clickthrough;
use DADA::App::DBIHandle;
use Data::Dumper; 
use DADA::MailingList::Archives; 

$|++;

my $dbi_obj = DADA::App::DBIHandle->new;
my $dbh     = $dbi_obj->dbh_obj;

print header(); 
for my $list(available_lists()){ 
	
	print h1($list); 
	my $r = DADA::Logging::Clickthrough->new( { -list => $list } );
	if(! $r->enabled){ 
		print p('Clickthrough is not enabled for this list. Skipping');
		next;  
		
	}
	
	my $query   = 'SELECT msg_id FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? GROUP BY msg_id ORDER BY msg_id DESC;';
	my $msg_ids = $dbh->selectcol_arrayref($query, {}, ($list)); #($statement, \%attr, @bind_values);

	
	for my $mid(@$msg_ids){ 
		print '<h2>' . $mid . '</h2>'; 
		
		if(!verified_mid($mid)){ 
			print p(b('NOT VALID MSG_ID')); 
		}
		else { 
			my $ah = DADA::MailingList::Archives->new({-list => $list}); 
			if($ah->check_if_entry_exists($mid)){ 
				print p('ARCHIVE EXISTS');
				# Do we have a num_subscribers entry? 
				my $num_sub_entry = num_subscriber_entry($list, $mid);
				if($num_sub_entry > 0){ 
					print p("YES NUM_SUB_ENTRY ($num_sub_entry)"); 
				}
				else { 
					print p("NO NUM_SUB_ENTRY"); 
					my $num_entries = num_entries($list, $mid);
					print p(b('ADD A NUM SUB ENTRY! - has ' . $num_entries . ' entries AND an Archive!')); 
					$r->num_subscribers_log(
						{
							-mid => $mid, 
							-num => 0, 
						}
					);	
					print p('Added!'); 			
				}
			}
			else { 
				print p('NO ARCHIVE EXISTS');
				#???print p("NO NUM_SUB_ENTRY"); 
				my $num_entries = num_entries($list, $mid);
				if($num_entries > $need_this_many_entries){ 
					print p(b('ADD A NUM SUB ENTRY! - has ' . $num_entries . ' entries!')); 
					$r->num_subscribers_log(
						{
							-mid => $mid, 
							-num => 0, 
						}
					);
					print p('Added!'); 
				}
				else { 
					print p(b('DON\'T ADD A NUM SUB ENTRY! - only has ' . $num_entries . ' entries!')); 
				}
			}
		}
		print hr(); 
	}	
}

print p('Done!'); 


sub num_entries { 
	my $list = shift; 
	my $mid  = shift; 
	my $query = 'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ?';
	my $msg_id_entries = $dbh->selectcol_arrayref( $query, {}, $list, $mid)->[0];
	return $msg_id_entries;
}
sub num_subscriber_entry {
	my $list = shift; 
	my $mid   = shift; 
	my $query = 'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND event = ?';
	my $c =  $dbh->selectcol_arrayref($query, {}, $list, $mid, 'num_subscribers')->[0]; 
	#print p(i('num_subscriber_entry ' . $c)); 
	return $c; 
}
sub verified_mid { 
	my $mid  = shift; 
	# This could be stronger, but... 
	if ($mid =~ /^\d+$/ && length($mid) == 14) {
		return 1; 
	}
	else { 
		return 0; 
	}
}

=pod

=head1 tracker_add_missing_num_subs.cgi

=head1 Description

Around v5.0.0 to v5.0.3 (the actually version this problem happens is fuzzy), there is/was a problem with the Tracker plugin, 
where it wouldn't successfully track the B<Number of Subscribers> at the time of a mass mailing, or this metric wasn't being tracked, because of a user preference 
(I<Enable Subscriber Count Logging> was B<unchecked>). 

Some related bugs: 

B<https://github.com/justingit/dada-mail/issues/281>

This leads to a major problem, as Tracker uses this one metric to grab all the mass mailings that it shows in its reports. No "Number of Subscriber" report, no report for anything else.  

C<tracker_add_missing_num_subs.cgi> adds that missing entry into the database. You can get a preview of what this plugin will most likely achieve in the Tracker before running this script. In the Tracker Preferences, uncheck the option, B<Clean Up Tracker Reports>. Your missing entries should now be shown, although other, "garbage" entries will probably also be shown, such as Test Mass Mailings.

Since the number of subscribers of a past mass mailing is unknown, it will simply add a new entry and record, C<0> subscribers. (You may later manualy fix this in the SQL table, if you would like.). 

This script also makes some assumptions, so not to make a new "Number of Subscribers" entry for every single thing in the Tracker Log:  

=over

=item * Doesn't already have a, "num_subscribers" entry

Only mass mailings with missing "num_subscribers" entries will be looked at. 

This also means that it's safe to re-run this script multiple times, if you find the desire to do so. 

=item * Mass Mailings with an Archived Message but no, "num_subscribers" entry will be given one

=item * Mass Mailings without an Archived Message and too few total Tracker entries will NOT be given a new "num_subscriber" entry

At the moment, this limit is a paltry, B<5>, and you may change this limit on the top of the script, in the variable, 

C<$need_this_many_entries>

=back

This plugin also only works with any of the B<SQL> backends, and does not work with the B<Default> (plaintext logs) Backend. 


=head1 Configuration

No configuration will need to be done in this script itself. The permissions of this script simply need to be set to, C<755>.

=head1 Using

Please fix backup the B<dada_mass_mailing_event_log> table in your SQL database. Although this script will not I<remove> any data from your
database, it will potentially I<add> data and add quite a bit data. 

Visit C<tracker_add_missing_num_subs.cgi> in your web browser, or run the script via the command line. Be aware that 
running the script may potentially take several minutes, depending on how many entries in the database you have, how many lists you have - things like that. 

Once the script is finished, visit the Tracker plugin and see if the missing Message entries are now visible. 
The Tracker Summary graph itself will probably have some wildly changing entries, as the actual  B<Subscribers> data is not available.

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


