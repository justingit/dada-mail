#!/usr/bin/perl

use strict; 

# DO NOT USE THIS SCRIPT WITHOUT FULLY BACKING UP YOUR ENTIRE DADA MAIL INSTALL 


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


# REALLY. 
use CGI::Carp qw(fatalsToBrowser); 


use Carp qw(croak carp); 


use DADA::Config 7.0.0; 
#use DADA::App::Guts; 


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


#use AnyDBM_File; 
use DBI;

connectdb();

print "beginning...\n";

for my $list(local_available_lists()){ 

	print "\tworking on list: '$list'...\n";

    if(-d $DADA::Config::BACKUPS . '/' . $list){ 
        print "great, it looks like we have a backup of the list...\n";
        
        if(-d $DADA::Config::BACKUPS . '/' . $list . '/archives'){ 
         
         
            print "and well... hey! We ever have backups of the list archives - how novel!\n";
            
            my $backup_dir = $DADA::Config::BACKUPS . '/' . $list . '/archives'; 
            my $backup; 
            my $backups;
            
            if(opendir(DIR, $backup_dir)){ 
                while(defined($backup = readdir DIR) ) {
            
                    next if ! -d $backup_dir . '/' . $backup;
                    next if $backup =~ /^\.\.?$/;
                    next if (($backup eq '') || ($backup eq ' ')); 
                    
                    $backup         =~ s(^.*/)(); 
            
                    push(@$backups, $backup);
                }
                closedir(DIR) or warn "didn't close properly... $!"; 
                
                #desc
                @$backups = sort {$b <=> $a} @$backups;

                #and.. we'll use the newest one. 
                

            }else{ 
                warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not open backup directory: '" . $backup_dir ."' $!";
            }
             
         
         my $freshest_backup_dir = $backup_dir . '/' . $backups->[0];
         my %new_values = (); 

               opendir(ADIR, $freshest_backup_dir) || die "can't opendir $freshest_backup_dir: $!";
   			
   			my @files = grep { -f "$freshest_backup_dir/$_" } readdir(ADIR);
            
            closedir(ADIR);
            
			for my $value(@files){ 
			    
				next if $value =~ /^\.\.?$/;
				$value         =~ s(^.*/)();
				
				my $value_file = $freshest_backup_dir . '/' . $value;
				
				if(-e $value_file){ 
					open(VALUE, $value_file) or carp $!; 
					
				#	my $saved_info = do{ local $/; <VALUE> }; 
					
						my $entry = do{ local $/; <VALUE> }; 
						my ($subject, $message, $format, $raw_msg) = split(/\[::\]/, $entry); 
						set_archive_info($list, $value, $subject, $message, $format, $raw_msg); 			
						print "\t\tentry $value... Done!\n";
				
					
					
                                       
					close(VALUE) or carp $!;
									
				}else{ 
					croak $value_file . "doesn't exist?!";
				}
				
				
			}
         
        }
        
        
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




sub save_setting { 

	my $list        = shift;	
	my $key         = shift; 
	my $value       = shift; 

	my $query = 'INSERT INTO '. $DADA::Config::SQL_PARAMS{archives_table} .' VALUES (?,?,?)';
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
	

		   
	my $path = $DADA::Config::FILES; 
	 #untaint 
	#$path = make_safer($path); 
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

=head1 dada_archives_backup_to_sql.pl

=head1 Description

C<dada_archives_backup_to_sql.pl> migration script converts your Dada Mail List Settings I<Backups> from the Default backend, to one of the SQL backends. 

The Default backend for the List Settings is going to be a database file, like the Berkeley DB file format. The I<Backup> of this will be a collection of files/directories, usually saved in the I<.dada_files/.backups> directory. This script should only be used if your List Settings are corrupted are unusable - both of which can happen during a server move. Backups are only made for the Default Backend and no backups are made for the SQL backend. 

If you List Settings are not corrupted use the, C<dada_archives_db_to_sql.pl> script. 

C<dada_archives_backup_to_sql.pl> is to be used I<after> you have reconfigured Dada Mail to use one of the SQL backends - you'll most likely do this via the Dada Mail installer. Once you have reconfigured your Dada Mail, none of your previous mailing lists will be available, until after you run this migration script. 

Before running this migration script, please make sure to backup your important Dada Mail files/information, most notably, the B<.dada_files> directory. 

=head1 Configuration

No configuration will need to be done in this script itself. The permissions of this script simply need to be set to, C<755>.

=head1 Using

Visit C<dada_archives_backup_to_sql.pl> in your web browser, or run the script via the command line. Make sure to B<only run this script once>, or data will be duplicated. 

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








