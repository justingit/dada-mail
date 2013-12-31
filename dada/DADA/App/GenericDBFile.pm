package DADA::App::GenericDBFile;

use Encode; 
use lib qw(
	../../ 
	../../DADA/perllib
);

use strict; 

use base qw(DADA::App::GenericDBFile::Backup);

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



use Carp qw(croak carp);


use DADA::Config qw(!:DEFAULT);  
use AnyDBM_File; 

sub new { 
	my $class = shift;
	my $self = {@_};
	bless $self, $class;  
	return $self;
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
	$p =~ tr/\0-\037\177-\377//d;    # remove unprintables
	$p =~ s/(['\\])/\$1/g;           # escape quote, backslash
	$p =~ /(.*)/;
	return $1;

}




sub _open_db { 

	my $self      = shift; 
	my $exception = 0;
	
    $self->_lock_db;
	chmod($DADA::Config::FILE_CHMOD , $self->_db_filename)
		if -e $self->_db_filename;
				   
	tie %{$self->{DB_HASH}}, "AnyDBM_File", $self->_db_filename,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD   
		or $exception = 1; 
		
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




sub _raw_db_hash { 

	my $self   = shift; 	
	my $as_ref = shift; 
	$self->_open_db; 
	my %RAW_DB_HASH = %{$self->{DB_HASH}};
	$self->{RAW_DB_HASH} = {%RAW_DB_HASH};
	$self->_close_db;
	
	# decode
	while ( my ($key, $value) = each %{$self->{RAW_DB_HASH}} ) {
		if(defined($value)){ 
			$self->{RAW_DB_HASH}->{$key} = safely_decode($value);
		}
	}
	
	$as_ref == 1 ? return \%RAW_DB_HASH : return %RAW_DB_HASH; 
}




sub _db_filename { 
	my $self = shift;
	my $fn = $self->{name}; 	
	   $fn =~ s/ /_/g; 
	
	 
	   
	   my $dir = $DADA::Config::FILES; 
	      $dir = $DADA::Config::ARCHIVES  if $self->{function} eq "archives"; 
          $dir = $DADA::Config::LOGS      if $self->{function} eq "bounces"; 
          $dir = $DADA::Config::TMP       if $self->{function} eq "simple_auth_string_state"; 
          $dir = $DADA::Config::TMP       if $self->{function} eq "CAPTCHA"; 
          $dir = $DADA::Config::TMP       if $self->{function} eq "confirmation_tokens"; 

              
       if($self->{function} ne 'bounces' && $self->{function} ne 'simple_auth_string_state' && $self->{function} ne 'confirmation_tokens'){
	       $fn = $dir . '/mj-' . $self->{name}; 
	   }elsif($self->{function} eq 'bounces'){

	       $fn = $dir . '/' . $self->{name} .'-bounces';
			
	   }elsif($self->{function} eq 'clickthrough'){
	
	       $fn = $dir . '/' . $self->{name} .'-clickthrough';
	
	   }elsif($self->{function} eq 'simple_auth_string_state'){
	       $fn = $dir . '/' . '__auth_state';	   
	   }elsif($self->{function} eq 'CAPTCHA'){
	       $fn = $dir . '/' . '__CAPTCHA';
	   }elsif($self->{function} eq 'confirmation_tokens'){
	       $fn = $dir . '/' . '__confirmation_tokens';	
	   }else{ 
	        carp "misconfiguration in _db_filename!"; 
	   }
	   
	   $fn .= '-archive' if $self->{function} eq "archives"; # This isn't good, since this module 
	                                                         # has to know about the module that 
	                                                         # inherits it. 
	   $fn .= '-schedules' if $self->{function} eq "schedules"; # This isn't good, since this module 
	                                                         # has to know about the module that 
	                                                         # inherits it. 

	    
	   #untaint 
	   $fn = $self->_safe_path($fn);
	   return $fn;
}




sub _close_db { 
	my $self = shift; 

	untie %{$self->{DB_HASH}} 
		or carp "untie didn't work: $!";
	$self->{DB_HASH} = {}; 
	delete $self->{DB_HASH}; 
	$self->_unlock_db; 
}




sub _lock_db { 
	my $self = shift; 
	sysopen(DB_SAFETYLOCK, $self->_lockfile_name,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
		or croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - Cannot open list lock file " . $self->_lockfile_name . " - $!";
	chmod($DADA::Config::FILE_CHMOD , $self->_lockfile_name); 
	{
		my $sleep_count = 0; 
		{ 
			flock DB_SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
			sleep 1;
			redo if ++$sleep_count < 11; 		
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: Server is way too busy to open list db file," . $self->_lockfile_name . " -   $!\n";
		}
	}
}




sub _unlock_db { 
	my $self = shift; 
	close(DB_SAFETYLOCK);
	if(-f $self->_lockfile_name){ 
		unlink($self->_lockfile_name) 
			or carp "couldn't delete lock file: '" . $self->_lockfile_name . "' - $!";
	}
}




sub _lockfile_name { 
	my $self = shift;
	return  $self->_safe_path("$DADA::Config::TMP/".$self->{name}."_" . $self->{function} . "db.lock");	 
}



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






1;
