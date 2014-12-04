package DADA::MailingList::SchedulesDeprecated::MLDb; 

use base "DADA::App::GenericDBFile";




use lib qw( ../../ ../../../ ../../../DADA ../../perllib); 

use Carp qw(croak carp);


use strict; 


use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT 
O_CREAT 
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB);

##############################################################################
#
# Options to use: 
#
#use MLDBM;                          # this gets the default, SDBM
#use MLDBM qw(DB_File FreezeThaw);  # use FreezeThaw for serializing
#use MLDBM qw(DB_File Storable);    # use Storable for serializing
##############################################################################

use MLDBM qw(AnyDBM_File Storable);
use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts;  # For now, my dear. 


=pod

=head1 NAME DADA::MailingList::SchedulesDeprecated::MLDb

=head1 SYNOPSIS

 my $mss = DADA::MailingList::SchedulesDeprecated->new({-list => 'listshortname'}); 

=head1 Description

This module holds methods for manipulating the underlying file format
used to save schedule mailings for Beatitude. This module uses the 
MLDBM module to save complex data structures to disk. 

=head1 Public Methods

=head2 new

  my $mss = DADA::MailingList::SchedulesDeprecated->new({-list => 'listshortname'}); 

B<-List> has to be a valid listshortname.

=cut



sub new {
	my $class = shift;
	my ($args) = @_; 
	
	  my $self = SUPER::new $class (
	  								function => 'schedules',
   							   );  
    							 
	    
       bless $self, $class;
	   $self->_init($args); 
	   return $self;
}




sub _init  { 
    my $self   = shift;
	my ($args) = @_; 
    
    	croak ('BAD List name "' . $args->{-list} . '" ') if $self->_list_name_check($args->{-list}) == 0; 
		$self->{name} = $args->{-list};
	    $self->{ignore_open_db_error} = $args->{-ignore_open_db_error}; 
		$self->_open_db;
}

=pod

=head2 save_record

	my $key = $mss->save_record(-key   => $s_key, 
								-mode  => 'append', 
					            -data  => \%form_vals);

Saves the hashref, B<-data> into key B<-key>. If key is not present, a
new key will be made. Information will be appened to old information
if B<-mode> is set to I<append>, old information will be most likely 
be written over if B<-mode> is set to any other value.


=cut

sub save_record { 
	my $self = shift; 
	
	my %args = (-key  => undef, 
				-mode => 'append', 
				-data => {},
				-backup => 1, 
				@_,
			   ); 
			   
			   
	my $key = $args{-key}; 
	   $key = $self->new_key if ! $key; 		   
		
	if($args{-mode} eq 'append'){ 
		if(exists $self->{DB_HASH}->{$key}){ 
		    
			my $tmp = $self->{DB_HASH}->{$key};

			
			if(keys %{$args{-data}}){
			
				if(! keys %$tmp){ 
					$tmp = {};
				}
				%$tmp = (%$tmp, %{$args{-data}}); 
				$self->{DB_HASH}->{$key} = $tmp; 
			}


		}else{
		    
			$self->{DB_HASH}->{$key} = $args{-data}; 
		}
	}else{ 
		$self->{DB_HASH}->{$key} = $args{-data}; 
	}
	
	if($args{-backup} == 1){ 
	    $self->backupToDir;
	}
	
	return $key; 
	

}


# ONLY use for backup purposes - for reals! 

sub save { 


    my $self = shift; 
    my $vals = shift; 
    
    $self->_open_db; 
    
    for(keys %$vals){ 
        my $new_data = eval($vals->{$_}); 
        
        $self->save_record(-key => $_, -data =>  $new_data, -backup => 0);
    }
   
   
    return 1; 


}




=pod

=head2 get_record

 $record = $mss->get_record($key);

Returns a hashref saved in $key

=cut

sub get_record { 

	my $self = shift; 
	my $key   = shift;
	# return safely_decode($self->{DB_HASH}->{$key}); # Maybe?
	return $self->{DB_HASH}->{$key}; 
}


# ONLY USE for backup stuff, nothing else! Seriously.
sub get { 
	my $self = shift;
	# to encode, or not...
	return $self->{DB_HASH}; 
}




=pod

=head2 record_keys

 my @keys = $mss->record_keys;
   
Returns all records keys.

=cut

sub record_keys { 
	my $self = shift; 
	return sort {$a <=> $b} keys %{$self->{DB_HASH}}; 
} 


=pod

=head2 remove_record

 $mss->remove_record($key); 

removes the record, $key.

=cut

sub remove_record { 
	my $self = shift; 
	my $key  = shift;
	$self->{DB_HASH}->{$key} = undef, 
	delete($self->{DB_HASH}->{$key}); 
} 


=pod

=head2 new_key

 my $new_key = $mss->new_key; 

Creates a new key, based on the time();

=cut

sub new_key { 
	my $self = shift; 
	return time; 
}




sub _list_name_check { 
	my ($self, $n) = @_; 
		$n = $self->_trim($n);
	return 0 if !$n; 
	return 0 if $self->_list_exists($n) == 0;  
	$self->{name} = $n;
	return 1; 
}




sub _list_exists { 
	my ($self, $n)  = @_; 
	return DADA::App::Guts::check_if_list_exists(-List => $n);
} 





sub _trim { 
	my ($self, $s) = @_;
	return DADA::App::Guts::strip($s);
}




sub _safe_path { 
	my ($self, $p) = @_; 
	return DADA::App::Guts::make_safer($p);

}




sub _open_db {
	my $self      = shift;
	my $exception = 0;
	
	$self->_lock_db;
	chmod($DADA::Config::FILE_CHMOD , $self->_db_filename)
		if -e $self->_db_filename; 

		my $dbm = tie %{$self->{DB_HASH}}, 'MLDBM', $self->_db_filename, O_CREAT|O_RDWR, $DADA::Config::FILE_CHMOD
		    or $exception = 1; 
		    
		    #croak 'couldn\'t tie '. $self->_db_filename . ' for reading: ' .$!;
    if($exception == 1){ 
        if($self->{ignore_open_db_error} == 1){ 
            carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! " . 
            'couldn\'t tie '. $self->_db_filename . ' for reading: ' . 
            $! . "Ignoring fatal error assuming you're (hopefully) resolving the issue by visiting: " . 
            $DADA::Config::S_PROGRAM_URL . '?f=restore_lists ';
            $self->{DB_HASH} = {};
        }else{
            croak 'couldn\'t tie '. $self->_db_filename . ' for reading: ' . 
            $! .  '; If your server recently upgraded software or moved 
            your lists to a different server, you may need to restore your list ' . 
            $self->{function} . '. Visit ' . $DADA::Config::S_PROGRAM_URL . '?f=restore_lists '; 
        }
    }
	
	

}

sub _close_db {
	my $self = shift;
	untie %{$self->{DB_HASH}};
	$self->_unlock_db;
}



sub _db_filename { 
	my $self = shift;
	my $fn = $self->{name}; 	
	   $fn =~ s/ /_/g; 
	   $fn = $DADA::Config::FILES . '/mj-' . $self->{name} . '-schedules';  
	  #$fn = $DADA::Config::FILES . '/test';
	   #untaint 
	   $fn = $self->_safe_path($fn); 
	   $fn =~ /(.*)/; 
	   $fn = $1;
	   return $fn;
}




sub _lock_db { 
	my $self = shift; 
	sysopen(DB_SCHEDULE_SAFETYLOCK, $self->_lockfile_name,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
		or croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - Cannot open list lock file " . $self->_lockfile_name . " - $!";
		{
			my $sleep_count = 0; 
			{ 
				flock DB_SCHEDULE_SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
				sleep 1;
				redo if ++$sleep_count < 11; 		
				croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: Server is way too busy to open list schedule db file," . $self->_lockfile_name . " -   $!\n";
		}
	}
}




sub _unlock_db { 
	
	my $self = shift; 
	
	if(-e $self->_lockfile_name){
		close(DB_SCHEDULE_SAFETYLOCK) 
			or carp 'could not close lock file: ' . $self->_lockfile_name . " $!";
		unlink($self->_lockfile_name) or carp "couldn't delete lock file: '" .$self->_lockfile_name ."' - $!";
	}
}




sub _lockfile_name { 
	my $self = shift;
	my $fn =  $self->_safe_path("$DADA::Config::TMP/".$self->{name}."_schedulesdb.lock");	
	$fn =~ /(.*)/;
	$fn = $1; 
	return $fn; 
} 



sub DESTROY { 
	my $self = shift; 
	   $self->_close_db(); 
	   $self->_unlock_db(); 
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

