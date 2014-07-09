package DADA::App::DataCache;
use 5.008_001;
use Encode qw(encode decode);

use strict;
use lib qw(../../ ../../DADA/perllib);

use DADA::Config;
use DADA::App::Guts; 

use Carp qw(carp croak) ;
use Fcntl qw(	O_WRONLY	O_TRUNC	O_CREAT	);

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

    $self->_init( \%args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {

    my $self = shift;

    return if $DADA::Config::DATA_CACHE ne '1';

    if ( !-d $self->cache_dir ) {
    	if(mkdir( $self->cache_dir, $DADA::Config::DIR_CHMOD )) { 
          if(-d $self->cache_dir){ 
			chmod( $DADA::Config::DIR_CHMOD, $self->cache_dir );
          }
    	}
		else { 
			warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, ' " . $self->cache_dir . " - $! - disabling data cache.";
			$DADA::Config::DATA_CACHE = 0;
		}
	}

}

sub cache_dir {

    my $self = shift;
    # return if $DADA::Config::DATA_CACHE  ne '1';
    return DADA::App::Guts::make_safer( $DADA::Config::TMP . '/_data_cache' );

}

sub cached {

    my $self   = shift;
	my ($args) = shift; 
	my $filename = $self->filename($args);
	
	#warn 'filename: ' . $filename; 
	# take off the date, 
	my $filename_snippet = $filename; 
	$filename_snippet =~ s/\.([0-9]{10})\.txt$//g; 
	my $date = $1; 
	#warn '$date: ' . $date; 
	
	my @matches; 
	# Now, look for that: 
	my $cached_files = $self->cached_files; 
	foreach my $file(@$cached_files){ 
		#warn "looking at: $file"; 
		if($file =~ m/$filename_snippet\./){ # notice that last dot, there. 
			#warn "got a match...";  
			$file =~ m/\.([0-9]{10})\.txt$/;
			my $file_time = $1; 
			#warn '$file_time is: ' . $file_time; 
			if(($file_time + (60 * 60)) >= $date) { 
				#warn "young enough to use!"; 
				#warn 'seconds remaining: ' . (($file_time + (60 * 60)) - $date);
		    	if ( -e  make_safer($self->cache_dir . '/' . $file) && -r _ ) { 
					#warn "using!"; 
		        	return $file; 
		    	}
			}
			else { 
				# dump it. 
				unlink(make_safer($self->cache_dir . '/' . $file)); 
			}
		}
	}
	# warn "no luck."; 
	return undef; 
}


sub retrieve {

    my $self   = shift;
	my ($args) = @_;
	 
	my $str    = ''; 
	
    my ($args) = @_;
	my $filename = $self->cached($args); 
	if(!defined($filename)){ 
		return undef; 
	}	
    my $path = $self->cache_dir . '/' . $filename;

	open SCREEN, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', DADA::App::Guts::make_safer($path)
	  or carp "cannot open $filename - $!" and return undef;
	while ( my $l = <SCREEN> ) {
		$str .= $l;
	}
	close(SCREEN)
		or croak"cannot close $filename - $!";
	return $str; 
	
}




sub _is_binary { 
	
	# This is inherently flawed. 
	my $self = shift; 
	my $str  = shift; 
	
	# does it have a 3 letter ending? 
	# What we're saying though is, 
	# if it's got what looks like a file ending, that's not, .txt, .html, .csv
	# or, ".scrn" (dada mail's own thing), it's binary. 
	# Otherwise, treat it as text that should be encoded/decoded.
	#
	
	if($str =~ m/\.[a-zA-Z]{3}$/){ 
		# is it text or csv? 
		if($str =~ m/\.(txt|csv)$/){ 
			return 0; 
		}
		else { 
			return 1; 
		}
	# four letters?
	}
	elsif($str =~ m/\.[a-zA-Z]{4}$/){ 
		# is it, "HTML or scrn?"
		if($str =~ m/\.(html|scrn)$/){ 
			return 0; 
		}
		else { 
			return 1; 
		}
	}
	else { 
		return 0; 
	}
}




sub cache {

    my $self   = shift;
	my ($args) = @_; 
	my $filename = $self->filename($args); 
	

	eval { 
	    my $unref = ${$args->{-data}};
	    return if $DADA::Config::DATA_CACHE  ne '1';
	    my $filename =
	      DADA::App::Guts::make_safer(
	        $self->cache_dir . '/' . $filename );


		
	    if ($self->_is_binary($filename)) {
	        open( SCREEN, '>', $filename )
	          or croak $!;
	        binmode SCREEN;
	    }
	    else {
	        open( SCREEN, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
	            $filename )
	          or croak 'Cannot open, ' . $filename . ' ' .$!;
	    }

	    print SCREEN $unref
	      or croak $!;
	    close(SCREEN)
	      or croak "couldn't close: '$filename' because: $!";
	    chmod(
	        $DADA::Config::FILE_CHMOD,
	        DADA::App::Guts::make_safer(
	            $self->cache_dir . '/' . $filename
	        )
	    );
	};
	
	if($@){ 
		carp "Problems with Screen Cache - Directory/File permissions error?: $@"; 
		return 0; 
	}
	else { 
		return 1;
	}

    
}


sub filename { 
	my $self = shift; 
	my ($args) = @_; 

#	-list    => $self->{name}, 
#	-name    => 'message_history_json', 
#	-page    => $page, 
#	-entries => $entries, 
#	-data    => $json, 

	if(! exists($args->{-name})){ 
		croak "I need a name for the cached data!"; 
	}	
	#carp '$args->{-name}' . $args->{-name}; 
	
	my $filename = ''; 
	if(exists($args->{-list})){ 
		$filename .= $args->{-list};
		$filename .= '.';  
	}
	$filename .= $args->{-name}; 
	$filename .= '.';  
	
	for('-page', '-entries'){ 
		if(exists($args->{$_})){ 
			$filename .= $args->{$_}; 
			$filename .= '.';  
		}
	}
	$filename .= time; 
	$filename .= '.txt'; 
	#carp "filename: $filename"; 
	return $filename; 
	
}
sub flush {

    my $self = shift;
	my ($args) = @_; 
	
	my $list = undef; 
	if(exists($args->{-list})){ 
		$list = $args->{-list};
	}
	my $msg_id = undef; 
	if(exists($args->{-msg_id})){ 
		$msg_id = $args->{-msg_id};
	}
    return if $DADA::Config::DATA_CACHE  ne '1';

    my $f;
    opendir( CACHE, $self->cache_dir )
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open '" . $self->cache_dir . "' to read because: $!";

    while ( defined( $f = readdir CACHE ) ) {

        #don't read '.' or '..'
        next if $f =~ /^\.\.?$/;

        $f =~ s(^.*/)();

		if(defined($list) && defined($msg_id)){ 
			next unless $f =~ m/^$list\.(.*?)\.$msg_id\./; 			
		}
		if(defined($list)){ 
			next unless $f =~ m/^$list\./; 
		}
        my $n = unlink( DADA::App::Guts::make_safer( $self->cache_dir . '/' . $f ) );
        warn DADA::App::Guts::make_safer( $self->cache_dir . '/' . $f )
          . " didn't go quietly"
          if $n == 0;

    }

    closedir(CACHE);

}

sub remove {

    my $self = shift;
    my $f    = shift;

    if ( $self->cached($f) ) {
        if ( -e DADA::App::Guts::make_safer( $self->cache_dir . '/' . $f ) ) {
            my $n = unlink( DADA::App::Guts::make_safer( $self->cache_dir . '/' . $f ) );
            if ( $n == 0 ) {
                warn DADA::App::Guts::make_safer( $self->cache_dir . '/' . $f )
                  . " didn't go quietly";
                return 0;
            }
            else {
                return 1;
            }
        }
        else {
            return 0;
        }
    }
    else {
        return 0;
    }
}

sub cached_files {

    my $self = shift;
	my ($args) = @_; 
	
    my $f;
    my $listing = [];

	return $listing if ! -d $self->cache_dir(); 
	
    opendir( CACHE, $self->cache_dir() )
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open '" .  $self->cache_dir . "' to read because: $!";

    while ( defined( $f = readdir CACHE ) ) {

        #don't read '.' or '..'
        next if $f =~ /^\.\.?$/;

        $f =~ s(^.*/)();

        my (
            $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
            $size, $atime, $mtime, $ctime, $blksize, $blocks
        ) = stat( $self->cache_dir . '/' . $f );

        push( @$listing, $f);
    }

    closedir(CACHE);
    return $listing;
}

sub DESTROY { 
	# ALL ASTROMEN!
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

