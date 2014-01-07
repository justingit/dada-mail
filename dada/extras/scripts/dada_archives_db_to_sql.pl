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


use AnyDBM_File; 
use DBI;

connectdb();

print "beginning...\n";

for my $list(DADA::App::Guts::available_lists()){ 

	print "\tworking on list: '$list'...\n";
	
	my %old_data; 
	print "\t" . $DADA::Config::ARCHIVES . '/mj-' . $list . '-archive' . "\n";
	my $filename = $DADA::Config::ARCHIVES . '/mj-' . $list . '-archive';
	
	eval { tie %old_data, "AnyDBM_File", $filename,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD;}; 
	if(!$@){ 
		 


		for my $key(keys %old_data){ 
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

=head1 dada_archives_db_to_sql.pl

=head1 Description

C<dada_archives_db_to_sql.pl> migration script converts your Dada Mail List Archives from the Default backend, to one of the SQL backends. 

The Default backend for the List Archives is going to be a database file, like the Berkeley DB file format. 

C<dada_archives_db_to_sql.pl> is to be used I<after> you have reconfigured Dada Mail to use one of the SQL backends - you'll most likely do this via the Dada Mail installer. Once you have reconfigured your Dada Mail, none of your previous mailing lists will be available, until after you run this migration script. 

Before running this migration script, please make sure to backup your important Dada Mail files/information, most notably, the B<.dada_files> directory. 

=head1 Configuration

No configuration will need to be done in this script itself. The permissions of this script simply need to be set to, C<755>.

=head1 Using

Visit C<dada_archives_db_to_sql.pl> in your web browser, or run the script via the command line. Make sure to B<only run this script once>, or data will be duplicated. 

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








