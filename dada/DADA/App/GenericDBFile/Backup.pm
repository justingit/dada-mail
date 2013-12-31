package DADA::App::GenericDBFile::Backup;

use lib qw(../../../ ../../../DADA/perllib); 
use strict; 


use DADA::Config qw(!:DEFAULT); 



use Carp qw(croak carp);

use Fcntl qw(	O_WRONLY	O_TRUNC		O_CREAT		);

sub backupToDir { 

	my $self    = shift;
		
	return if ! exists $DADA::Config::BACKUP_HISTORY {$self->{function}}; 
	return if          $DADA::Config::BACKUP_HISTORY {$self->{function}} < 1; 

	my $li      = $self->get(-Format => 'unmunged');
	my $t       = time; 
	
	if(! -d $self->rootBackupDirPath){ 
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, '$self->rootBackupDirPath'- $!" 
			unless mkdir ($self->rootBackupDirPath, $DADA::Config::DIR_CHMOD );
		chmod($DADA::Config::DIR_CHMOD , $self->rootBackupDirPath)
			if -d $self->rootBackupDirPath; 
	}
	
	my $backup_dir = $self->backDirPath;
	if(! -d $backup_dir){ 
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, '$backup_dir'- $!" 
			unless (mkdir $backup_dir, $DADA::Config::DIR_CHMOD );
		chmod($DADA::Config::DIR_CHMOD , $backup_dir)
			if -d $backup_dir; 
	}
	
	my $new_dir = $self->_safe_path($backup_dir . '/' . $t); 
	
	# This means it already exists!
	my $ok_dir = 0; 

    if(-d $new_dir){ 
	    my $append = 0; 
	    while($ok_dir == 0){ 
	        if(-d  $new_dir . '.' . $append){ 
	         $append++;
	         # well.... keep going
	        } else { 
	            $new_dir = $new_dir . '.' . $append;
	            $ok_dir = 1;
	        }
	    }
	}
	
	carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, '$new_dir'- $!" 
		unless mkdir ( $new_dir, $DADA::Config::DIR_CHMOD  );
		chmod($DADA::Config::DIR_CHMOD , $new_dir)
			if -d $new_dir; 
		
		
	if(-d $new_dir){
		for my $setting(keys %$li){	
			next if ! $setting;
			open(KEY, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->_safe_path($new_dir . '/' . $setting)) 
				or carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER error! Can't write key/value file at: '" . $self->_safe_path($new_dir . '/' . $setting) . "' $!";  
				
			# Not quite sure why I'm doing this twice, except I used to do it in the sysopen call: 
			chmod($DADA::Config::FILE_CHMOD , $self->_safe_path($new_dir . '/' . $setting)); 
			
			if($self->{function} eq 'schedules'){ 
			    require Data::Dumper; 			
			    
			    require Data::Dumper; 
                my $bu = Data::Dumper->new([$li->{$setting}]); 
                   $bu->Purity(1)->Terse(1)->Deepcopy(1);
                print KEY $bu->Dump; 
                
            
			} else { 
			    print KEY $li->{$setting};
			}
			
			close(KEY) or carp $!;
			chmod($DADA::Config::FILE_CHMOD , $self->_safe_path($new_dir . '/' . $setting)); 
		}
		$self->removeOldBackupsToDir;
	}else{ 
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! $backup_dir wasn't created! Backup failed.";
	}	
}


sub removeAllBackups { 

	my $self = shift; 
	my $all  = shift; 
	
	$self->removeOldBackupsToDir((-1));
	if( -d $self->backDirPath){ 
	
		if($self->backDirPath eq $DADA::Config::FILES . '/'){ 
			croak "backDirPath (" . $self->backDirPath .") is root backup directory?!"; 
		}
		
		# This zaps any files that are saved if a restore from backup takes place. 
		#
		#
		my $backup_of_backup_file; 
			if(opendir(BUOBU, $self->backDirPath)){ 
		
				while(defined($backup_of_backup_file = readdir BUOBU) ) {
					next if $backup_of_backup_file   =~ /^\.\.?$/;
					$backup_of_backup_file           =~ s(^.*/)();
				
					next if -d 	$self->backDirPath . '/' . $backup_of_backup_file;
				
					my $n = unlink($self->_safe_path($self->backDirPath . '/' . $backup_of_backup_file)); 
						carp $self->backDirPath . '/' . $backup_of_backup_file . " didn't go quietly" if $n == 0; 
				}
			closedir(BUOBU) or carp "couldn't close: " . $self->backDirPath; 
		}else{
			carp "could not open " . $self->backDirPath . " $!"; 
		}
		#
		#
		# and enough of that. 
	
		carp 'Could not remove: '. $self->backDirPath . " - $!"
			unless rmdir ($self->backDirPath);
		}
		
	if($all){
		if(-d $self->_safe_path($self->rootBackupDirPath)){ 
			carp 'Couldn\'t remove, '. $self->_safe_path($self->rootBackupDirPath) . " - $!"
				unless rmdir ($self->_safe_path($self->rootBackupDirPath));
		}
	}
}




sub removeOldBackupsToDir { 

	my $self    = shift;
	my $depth   = shift || $DADA::Config::BACKUP_HISTORY {$self->{function}};
	my $backups = $self->backupDirs; 
	my $i = -1; 
	for(@$backups){
		$i++;
		next if $i < $depth; 	
		$self->removeBackupDir($backups->[$i]->{dir});
	}
	
}




sub backupDirs { 
	
	my $self = shift; 
	
	my $backups     = [];
	my $backup_dirs = []; 
	
	my $backup; 
	
	if(-d $self->backDirPath){ 
		if(opendir(DIR, $self->backDirPath)){ 
			while(defined($backup = readdir DIR) ) {
		
				next if ! -d $self->backDirPath . '/' . $backup;
				next if $backup =~ /^\.\.?$/;
				next if (($backup eq '') || ($backup eq ' ')); 
				
				$backup         =~ s(^.*/)(); 
		
		        
		        push(@$backup_dirs, $backup);
		
				#push(@$backups, {dir => $backup, count => $dir_count});
			}
			closedir(DIR) or carp "didn't close properly... $!"; 
			
			#desc
			@$backup_dirs = sort {$b <=> $a} @$backup_dirs;
			
			for(@$backup_dirs){ 
			    my $dir_count   = $self->dirCount($self->backDirPath . '/' . $_); 
                push(@$backups, {dir => $_, count => $dir_count});
			}
			
			
			return $backups; 
		}else{ 
			carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not open backup directory: '" . $self->backDirPath ."' $!";
			return [];
		}
	}else{ 
		# backupdir not even there...
		return [];
	}
}




sub dirCount { 

    my $self = shift; 
    my $dir  = shift; 
    my $file; 
    my $count = 0; 
    
    if(opendir(my $DIR, $dir)){ 
    
        while(defined($file = readdir $DIR) ) {
        
            next if $file =~ /^\.\.?$/;
            next if -d $file;
            $count++; 
            
        }
        
        closedir($DIR) or carp "didn't close properly... $!"; 

        return $count; 
        
    }else{ 
    
		return 0;
	
	}
	

    
}




sub removeBackupDir { 
	
	my $self = shift;
	my $dir  = shift; 
	
	my $deep_six_dir = $self->backDirPath . '/'. $dir;
	
	my $bufile; 


	if(opendir(BUFILES, $deep_six_dir)){ 
	
	    my $file_count = 0; 
	    my @file_deep_six_list; 
	    
		while(defined($bufile = readdir BUFILES) ) {
			next if $bufile =~ /^\.\.?$/;
			$bufile         =~ s(^.*/)();
		    push(@file_deep_six_list, $self->_safe_path($deep_six_dir . '/' . $bufile));
		    $file_count++; 
		}
		
		closedir(BUFILES)
		    or carp "couldn't close: " . $deep_six_dir; 
        
		my $final_count = 0; 
        if($file_deep_six_list[0]){ 
            $final_count = unlink(@file_deep_six_list)
		            or carp "could not remove any backup files! in directory: " . $deep_six_dir . '/' . $bufile . " $!"; 
        }
		else { 
			# Else, we got nothin' to remove, sucka!
			$final_count = 0; 
		}

        if($final_count < $file_count){ 
            carp "Some backup files in, '" . $deep_six_dir .  "' weren't removed!"; 
        } else { 
            carp "couldn't remove $deep_six_dir $!"
			    unless rmdir($self->_safe_path($deep_six_dir));
        }

	}else{ 
		carp "couldn't open: " . $deep_six_dir; 
	}

}


sub rootBackupDirPath { 
	my $self = shift; 
	return $self->_safe_path($DADA::Config::BACKUPS  . '/' . $self->{name}); 
}





sub backDirPath { 
	my $self = shift;
	return $self->_safe_path($self->rootBackupDirPath . '/' . $self->{function}); 
}




sub restoreFromFile { 
	my $self         = shift; 
	my $restore_dir  = shift; 
	my $r            = ''; 
		
	$self->{im_restoring} = 1; 
	
	my $function = '';
	   $function = '-archive'    if $self->{function} eq 'archives';

	   $function = '-schedules'  if $self->{function} eq 'schedules';
	   
	my $Path = $DADA::Config::FILES; 
	   $Path = $DADA::Config::ARCHIVES        if $self->{function} eq 'archives';    
	   
	require File::Copy; 
	

	if(-e $Path . '/mj-' . $self->{name} . $function){ 
		File::Copy::copy($self->_safe_path($Path . '/mj-' . $self->{name} . $function),        $self->_safe_path($self->backDirPath .  '/backup_of_mj-' . $self->{name} . $function . '-' . time));
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER  warning! removing list file didn't work... $!"
			unless unlink $self->_safe_path($Path . '/mj-' . $self->{name} . $function);
	}
	
	if(-e $Path . '/mj-' . $self->{name} . $function . '.db'){ 
		File::Copy::copy($self->_safe_path($Path . '/mj-' . $self->{name} . $function . '.db'), $self->_safe_path($self->backDirPath .  '/backup_of_mj-' . $self->{name} . $function . '.db-' . time));
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER  warning! removing list  file didn't work... $!"
			unless unlink $self->_safe_path($Path . '/mj-' . $self->{name} . $function . '.db');
	}
	
	if(-e $Path . '/mj-' . $self->{name} . $function . '.pag'){ 
		File::Copy::copy($self->_safe_path($Path . '/mj-' . $self->{name} . $function . '.pag'), $self->_safe_path($self->backDirPath .  '/backup_of_mj-' . $function . $self->{name} . '.pag-' . time));
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER  warning! removing list  file didn't work... $!"
			unless unlink $self->_safe_path($Path . '/mj-' . $self->{name} . $function . '.pag');
	}
	
	if(-e $Path . '/mj-' . $self->{name} . $function . '.dir'){ 
		File::Copy::copy($self->_safe_path($Path . '/mj-' . $self->{name} . $function . '.dir'), $self->_safe_path($self->backDirPath .  '/backup_of_mj-' . $self->{name} . $function . '.dir-' . time));
		carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER  warning! removing list setting file didn't work... $!"
			unless unlink $self->_safe_path($Path . '/mj-' . $self->{name} . $function . '.dir');
	}
	
	my %new_values; 
	my $value; 
	
	if ($restore_dir ne 'just_remove_blank'){ 
	    
		if(opendir(BACKUPDIR, $self->backDirPath .  '/' . $restore_dir)){  	
			while(defined($value = readdir BACKUPDIR) ) { 
			    
				next if $value =~ /^\.\.?$/;
				$value         =~ s(^.*/)();
				
				my $value_file = $self->backDirPath .  '/' . $restore_dir . '/' . $value;
				
				if(-z $value_file){ 
					carp "File, '$value_file' is empty! Skipping.";  
				}
				
				if(-e $value_file && ! -z $value_file){ # -z means 0 size
					
					open(VALUE, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $value_file) 
						or carp $!; 
					$new_values{$value} = do{ local $/; <VALUE> };    
					close(VALUE) or carp $!; 
				}else{ 
					carp $value_file . "doesn't exist?!";
				}
				
				
			}
			closedir(BACKUPDIR); 
			
			if($self->{function} eq 'settings'){ 
			
			    for(keys %new_values){ 
			    
			        if(! exists($DADA::Config::LIST_SETUP_DEFAULTS{$_})){ 
			            carp "skipping restoring setting: $_ (not used anymore?) on list: " . $self->{name}; 
			            delete($new_values{$_}); 
			        }
			    }
			
			}
			elsif($self->{function} eq 'schedules'){ 
			    for(keys %new_values){ 
			    
			        if(! defined($new_values{$_}) || $new_values{$_} eq '' || length($new_values{$_}) <= 0){ 
			            carp "skipping restoring schedule: $_ - blank!"; 
			            delete($new_values{$_}); 
			        }
			    }
							
			}
			
			    
			$self->save({%new_values});
			
		}else{ 
			carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! opening the backup dir: '" . $self->backDirPath . '/' . $restore_dir . "' didn't work!";
			return undef;
		}
	}
}




sub uses_backupDirs { 
	return 1; 
}




1;


=pod

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

