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



use CGI qw(:standard); 

print header();

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


print '<pre>';


use Fcntl qw(
O_RDWR O_CREAT); 

use AnyDBM_File; 
use DBI;

connectdb();

print "beginning...\n";

for my $list(local_available_lists()){ 

	print "\tworking on list: '$list'...\n";
	
	my %old_data; 
	print "\t" . $DADA::Config::FILES . '/mj-' . $list . "\n";

	my $filename = $DADA::Config::FILES . '/mj-' . $list;
	
	tie %old_data, "AnyDBM_File", $filename,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD  or die $!;  


	for my $key(keys %old_data){ 
		my $value = $old_data{$key}; 

		save_setting($list, $key, $value); 
		
		print "\t\tentry $key... Done!\n";
	}
	
	untie %old_data; 
		
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




sub save_setting { 

	my $list        = shift;	
	my $key         = shift; 
	my $value       = shift; 

	my $query = 'INSERT INTO '. $DADA::Config::SQL_PARAMS{settings_table} .' VALUES (?,?,?)';
	my $sth   = $dbh->prepare($query); 
	   $sth->execute($list, $key, $value);
	return 1; 
	
}





sub local_available_lists { 

	my %args = ( 
				-As_Ref     => 0,
				-In_Order   => 0,
				-Dont_Die   => 0,
				@_
			   ); 
	
	
	my $want_ref        = $args{-As_Ref};
	my @dbs             = ();
	my @available_lists = (); 
	my $present_list;
	
	require DADA::MailingList::Settings;  
		   
	my $path = $DADA::Config::FILES; 
	 #untaint 
	$path = make_safer($path); 
	$path =~ /(.*)/; 
	$path = $1; 
	
	if(opendir(LISTS, $DADA::Config::FILES)){ 
		while(defined($present_list = readdir LISTS) ) { 
			next if $present_list =~ /^\.\.?$/;
					$present_list =~ s(^.*/)();
			next if $present_list !~ /^mj-.*$/; 
	
			$present_list =~ s/mj-//;
			$present_list =~ s/(\.dir|\.pag|\.db)$//;
			$present_list =~ s/(\.list|\.template)$//;
	 
			next if $present_list eq ""; 
			push(@dbs, $present_list) 
				if(defined($present_list) && $present_list ne "" && $present_list !~ m/^\s+$/); 
		}
		
		for my $all_those(@dbs) {      
			 push( @available_lists, $all_those)
			 	if($all_those !~ m/\-archive.*|\-schedules.*/)
		}		    
		
		#give me just one occurence of each name
		my %seen = (); 
		my @unique = grep {! $seen{$_} ++ }  @available_lists; 
		
		my @clean_unique; 
		
		for(@unique){ 
			push(@clean_unique, $_) 
				if(defined($_) && $_ ne "" && $_ !~ m/^\s+$/);
		}
		
		if($args{-In_Order} == 1){ 
		
			my $labels = {}; 
			for my $l( @clean_unique){		
				my $ls        = DADA::MailingList::Settings->new({-list => $l}); 
				my $li        = $ls->get; 		
				$labels->{$l} = $li->{list_name};
			}			
			@clean_unique = sort { uc($labels->{$a}) cmp uc($labels->{$b}) } keys %$labels;						  
		}
		
		$want_ref == "1" ? return \@clean_unique : return @clean_unique;
		
	}else{ 
		# DON'T rely on this...
		if($args{-Dont_Die} == 1){ 
			$want_ref == "1" ? return [] : return ();	
		}else{ 
			die("$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, please MAKE SURE that '$path' is a directory (NOT a file) and that Dada Mail has enough permissions to write into this directory: $!"); 
	
		}
	}
	

} 





__END__

=pod

=head1 dada_settings_db_to_sql.pl

=head1 Description

C<dada_settings_db_to_sql.pl> migration script converts your Dada Mail List Settings from the Default backend, to one of the SQL backends. 

The Default backend for the List Settings is going to be a database file, like the Berkeley DB file format. 

C<dada_settings_db_to_sql.pl> is to be used I<after> you have reconfigured Dada Mail to use one of the SQL backends - you'll most likely do this via the Dada Mail installer. Once you have reconfigured your Dada Mail, none of your previous mailing lists will be available, until after you run this migration script. 

Before running this migration script, please make sure to backup your important Dada Mail files/information, most notably, the B<.dada_files> directory. 

=head1 Configuration

No configuration will need to be done in this script itself. The permissions of this script simply need to be set to, C<755>.

=head1 Using

Visit C<dada_settings_db_to_sql.pl> in your web browser, or run the script via the command line. Make sure to B<only run this script once>, or data will be duplicated. 

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









