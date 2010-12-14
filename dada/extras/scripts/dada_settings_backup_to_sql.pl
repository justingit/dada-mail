#!/usr/bin/perl -w

use strict; 

# DO NOT USE THIS SCRIPT WITHOUT FULLY BACKING UP YOUR ENTIRE DADA MAIL INSTALL 




# REALLY. 
use CGI::Carp qw(fatalsToBrowser); 


use Carp qw(croak carp); 


use DADA::Config 3.0.0; 
#use DADA::App::Guts; 


my $database         = $DADA::Config::SQL_PARAMS{database};
my $dbserver         = $DADA::Config::SQL_PARAMS{dbserver};    	  
my $port             = $DADA::Config::SQL_PARAMS{port};     	  
my $user             = $DADA::Config::SQL_PARAMS{user};         
my $pass             = $DADA::Config::SQL_PARAMS{pass};
my $dbtype           = $DADA::Config::SQL_PARAMS{dbtype};

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 


my $dbh; 

use CGI qw(:standard); 

print header(); 
print '<pre>';


use Fcntl qw(
O_RDWR O_CREAT); 

use lib qw(./ ./DADA ./DADA/perllib); 

#use AnyDBM_File; 
use DBI;

connectdb();

print "beginning...\n";

foreach my $list(local_available_lists()){ 

	print "\tworking on list: '$list'...\n";

    if(-d $DADA::Config::BACKUPS . '/' . $list){ 
        print "great, it looks like we have a backup of the list...\n";
        
        if(-d $DADA::Config::BACKUPS . '/' . $list . '/settings'){ 
         
         
            print "and well... hey! We ever have backups of the list settings - how novel!\n";
            
            my $backup_dir = $DADA::Config::BACKUPS . '/' . $list . '/settings'; 
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
            
			foreach my $value(@files){ 
			    
				next if $value =~ /^\.\.?$/;
				$value         =~ s(^.*/)();
				
				my $value_file = $freshest_backup_dir . '/' . $value;
				
				if(-e $value_file){ 
					open(VALUE, $value_file) or carp $!; 
					
					$new_values{$value} = do{ local $/; <VALUE> }; 
                                       
					close(VALUE) or carp $!;
									
				}else{ 
					croak $value_file . "doesn't exist?!";
				}
				
				
			}

			
			    foreach(keys %new_values){ 
			    
			        if(! exists($DADA::Config::LIST_SETUP_DEFAULTS{$_})){ 
			            carp "skipping restoring setting: $_ (not used anymore?) on list: " . $list; 
			            delete($new_values{$_}); 
			        } else { 
			        
			             print "list: $list\n\key: $_\n"; #value: $new_values{$_}\n\n";
			             save_setting($list, $_, $new_values{$_}); 
			        }
			    }
			
		#	}
			    
			#$self->save({%new_values});
            #save_setting($list, $_, $new_values{$_}); 
           
           
          # print "list: $list\n\key: $_\nvalue: $new_values{$_}\n\n";
         
         
         
         
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
		
		foreach my $all_those(@dbs) {      
			 push( @available_lists, $all_those)
			 	if($all_those !~ m/\-archive.*|\-schedules.*/)
		}		    
		
		#give me just one occurence of each name
		my %seen = (); 
		my @unique = grep {! $seen{$_} ++ }  @available_lists; 
		
		my @clean_unique; 
		
		foreach(@unique){ 
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





__END__

=pod

=head1 Name dada_settings_backup_to_sql.pl

=head1 Description

Cute name, huh? 

Basically, this small script takes the information of a Dada Mail list settings I<backup directories> and ports it to the MySQL format.

Fairly simple and straightforward. 

=head1 How to use this script

=over

=item * Backup Everything

SQL tables, list files (all of them) 

=item * Create the List Settings SQL table

The SQL statement to run should be saved in a file called I<dada_settings.sql> which is located in the I<dada/extras/SQL> directory of the distribution

=item * Set B<$SETTINGS_DB_TYPE> to the correct SQL type (MySQL, Postgres)

Directions are located in the Config.pm about this, search for, I<$SETTINGS_DB_TYPE>

=item * Fill in %SQL_PARAMS in the Config.pm file

Again, directions should be supplied in the Config.pm file. 

=back

After the above (do not skip a step) are done, make sure Dada Mail is still running by visiting it in your webbrowser. The program should run as if no lists existed - not to worry! We shall fix that soon enough.

Upload this script into the same directory that you have the I<mail.cgi> script in, and run it, either from your web browser, or via the command line. 

That should be it. 


ps. backup everything. 
 

=head1 COPYRIGHT 

Copyright (c) 1999-2008 Justin Simoni All rights reserved. 

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









