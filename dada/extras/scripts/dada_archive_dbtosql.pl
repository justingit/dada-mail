#!/usr/bin/perl -w

use lib qw(./ ./DADA/perllib); 

use CGI::Carp qw(fatalsToBrowser); 

use strict; 

# DO NOT USE THIS SCRIPT WITHOUT FULLY BACKING UP YOUR ENTIRE DADA MAIL INSTALL 




# REALLY. 


use DADA::Config; 
use DADA::App::Guts; 


my $database         = $DADA::Config::SQL_PARAMS{database};
my $dbserver         = $DADA::Config::SQL_PARAMS{dbserver};    	  
my $port             = $DADA::Config::SQL_PARAMS{port};     	  
my $user             = $DADA::Config::SQL_PARAMS{user};         
my $pass             = $DADA::Config::SQL_PARAMS{pass};
my $dbtype           = $DADA::Config::SQL_PARAMS{dbtype};



my $dbh; 

use CGI qw(:standard); 

print header(); 
print '<pre>';


use Fcntl qw(
O_RDWR O_CREAT); 

use lib qw(./ ./DADA ./DADA/perllib); 

use AnyDBM_File; 
use DBI;

connectdb();

print "beginning...\n";

foreach my $list(DADA::App::Guts::available_lists()){ 

	print "\tworking on list: '$list'...\n";
	
	my %old_data; 
	print "\t" . $DADA::Config::ARCHIVES . '/mj-' . $list . '-archive' . "\n";
	my $filename = $DADA::Config::ARCHIVES . '/mj-' . $list . '-archive';
	
	eval { tie %old_data, "AnyDBM_File", $filename,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD;}; 
	if(!$@){ 
		 


		foreach my $key(keys %old_data){ 
			my $entry = $old_data{$key}; 
			my ($subject, $message, $format, $raw_msg) = split(/\[::\]/, $entry); 
			set_archive_info($list, $key, $subject, $message, $format, $raw_msg); 			
			print "\t\tentry $key... Done!\n";
		}
	
		untie %old_data; 
	}
	else { 
		print "\t\tError! Attempting to access information in: " . $filename . "  - Skipping...\n";
	}
}

print "Done.\n\n"; 


disconnectdb(); 


sub connectdb {
  
  my $data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";
  $dbh = DBI->connect("$data_source", $user, $pass) || die("can't connect to db: $!");
 
}


sub disconnectdb {
  $dbh->disconnect;
}




sub set_archive_info { 

	my $list        = shift;	
	my $key         = shift; 
	my $new_subject = shift; 
	my $new_message = shift;
	my $new_format  = shift;
	my $raw_msg     = shift; 
	
	my $query = 'INSERT INTO '. $DADA::Config::SQL_PARAMS{archives_table} .' VALUES (?,?,?,?,?,?)';
	my $sth   = $dbh->prepare($query); 
	   $sth->execute($list, $key, $new_subject, $new_message, $new_format, $raw_msg);
	return 1; 
	
}


__END__

=pod

=head1 Name dada_archive_dbtosql.pl

=head1 Description

Cute name, huh? 

Basically, this small script takes the information of a Dada Mail archive in the DB File and ports it to the MySQL format.

Fairly simple and straightforward. 

=head1 How to use this script

=over

=item * Backup Everything

SQL tables, list files (all of them) 

=item * Create the Archives SQL table

The SQL statement to run should be saved in a file called I<dada_archives.sql> which is located in the I<dada/extras/SQL> directory of the distribution

=item * Set B<ARCHIVE_DB_TYPE> to the correct SQL type (MySQL, Postgres)

Directions are located in the Config.pm about this, search for, I<$ARCHIVE_DB_TYPE>

=item * Fill in %SQL_PARAMS in the Config.pm file

Again, directions should be supplied in the Config.pm file. 

=back

After the above (do not skip a step) are done, make sure Dada Mail is still running by visiting it in your webbrowser. The program should run exactly as before, except no archives should be available. 

Upload this script into the same directory that you have the I<mail.cgi> script in, and run it, either from your web browser, or via the command line. 

That should be it. 


ps. backup everything. 
 

=head1 COPYRIGHT 

Copyright (c) 1999 - 2009 Justin Simoni All rights reserved. 

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









