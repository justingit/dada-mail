package DADA::App::ScreenCache;
use 5.8.1; 
use Encode qw(encode decode);

use strict; 
use lib qw(../../ ../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  

use Carp; 
use Fcntl qw(	O_WRONLY	O_TRUNC		O_CREAT		);

use vars qw($AUTOLOAD); 

my %allowed = (); 

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my %args = (@_); 
		
   $self->_init(\%args); 
   return $self;
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init { 

	my $self = shift; 
	
	return if $DADA::Config::SCREEN_CACHE  != 1; 
	
	if(! -d $self->cache_dir){ 
		warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, 'self->cache_dir'- $!" 
			unless mkdir ($self->cache_dir, $DADA::Config::DIR_CHMOD );
		chmod($DADA::Config::DIR_CHMOD , $self->cache_dir)
			if -d $self->cache_dir; 
	}
	
}




sub cache_dir { 

	my $self = shift;
	
	return if $DADA::Config::SCREEN_CACHE  != 1;
	
	return $self->_safe_path($DADA::Config::TMP  . '/cache');
	
}




sub cached { 

	my $self   = shift; 
	my $screen = shift; 
	
	return if $DADA::Config::SCREEN_CACHE  != 1;
	
	if(-f $self->cache_dir . '/' . $self->translate_name($screen)){ 
		return 1; 
	}else{ 
		return 0; 
	}
}




sub show { 

	my $self     = shift; 
	my $screen   = shift; 
	my $filename = $self->cache_dir . '/' . $self->translate_name($screen);
	
	if($self->cached($screen)){ 
		open SCREEN, '<', $self->_safe_path($filename) 
			or croak ("cannot open $filename - $!"); 
		while(my $l = <SCREEN>){ 
			if($filename !~ m/\.(jpg|png|gif)$/){
				print decode('UTF-8', $l) 
			}
			else { 
				print $l;
			}
		}

		close(SCREEN)
			or croak ("cannot close $filename - $!"); 
	} else{ 
		croak "screen is not cached! " . $!; 
	}
	
}




sub pass { 

	my $self     = shift; 
	my $screen   = shift; 
	my $filename = $self->cache_dir . '/' . $self->translate_name($screen);
	
	if($self->cached($screen)){ 
		open(SCREEN, "<" . $self->_safe_path($filename)) 
			or croak ("cannot open '$filename' because: $!"); 
		
		my $return; 
		while(my $l = <SCREEN>){ 
			$return .= $l; 
		}
		close(SCREEN)
			or croak ("cannot close $filename - $!"); 
			
	    return decode('UTF-8', $return); 
	    
	} else{ 
		croak "screen is not cached! " . $!; 
	}
	
}





sub cache { 

	my $self   = shift; 
	my $screen = shift;
	my $data   = shift; 
	
	my $unref = $$data; 
	encode('UTF-8', $unref); 
	return if $DADA::Config::SCREEN_CACHE  != 1;
	my $file = $self->_safe_path($self->cache_dir . '/' . $self->translate_name($screen)); 
	sysopen(SCREEN, $file, O_WRONLY|O_TRUNC|O_CREAT,  $DADA::Config::FILE_CHMOD ) 
		or croak $!;
		print SCREEN $unref
			or croak $!; 
	close(SCREEN)
		or croak "couldn't close: '$file' because: $!";
	chmod($DADA::Config::FILE_CHMOD , $self->_safe_path($self->cache_dir . '/' . $self->translate_name($screen)));
	
}




sub flush { 

	my $self = shift; 
	
	return if $DADA::Config::SCREEN_CACHE  != 1;
	
	my $f;
	opendir(CACHE, $self->cache_dir) 
		or croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open '$self->cache_dir' to read because: $!"; 
	
	while(defined($f = readdir CACHE) ) { 
		
		#don't read '.' or '..'
		next if $f =~ /^\.\.?$/;
		 
		$f =~ s(^.*/)();
		
		my $n = unlink($self->_safe_path($self->cache_dir . '/' . $f)); 
			warn $self->_safe_path($self->cache_dir . '/' . $f) . " didn't go quietly" if $n == 0; 
			
	}
	
	closedir(CACHE);

}




sub remove { 

	my $self = shift; 
	my $f    = shift; 
	
	if($self->cached($f)){ 
	   if(-e $self->_safe_path($self->cache_dir . '/' . $f)){ 
            my $n = unlink($self->_safe_path($self->cache_dir . '/' . $f)); 
                warn $self->_safe_path($self->cache_dir . '/' . $f) . " didn't go quietly" if $n == 0; 
	   }
	}
}




sub translate_name { 

	my $self = shift; 
	my $file = shift; 
	$file =~ s/\//./g; 
	$file =~ s/\@/_at_/g; 
	$file =~ s/\>|\<//g; 
	
	return $file; 
}




sub _safe_path { 

	my ($self, $p) = @_; 
	$p =~ tr/\0-\037\177-\377//d;    # remove unprintables
	$p =~ s/(['\\])/\$1/g;           # escape quote, backslash
	$p =~ /(.*)/;
	return $1;

}




sub cached_screens { 

	my $self = shift; 
	my $f;
	my $listing = []; 

	opendir(CACHE, $self->cache_dir) 
		or croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open $self->cache_dir to read because: $!"; 

	while(defined($f = readdir CACHE) ) { 

		#don't read '.' or '..'
		next if $f =~ /^\.\.?$/;
		 
		$f =~ s(^.*/)();
		
		my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                   $atime,$mtime,$ctime,$blksize,$blocks)
                       = stat($self->cache_dir . '/' . $f);


		push(@{$listing}, {name => $f, size =>  int($size/1024)}) ;
	}
	
	closedir(CACHE); stat
	return $listing; 
}



sub DESTROY {}

1;

=pod

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

