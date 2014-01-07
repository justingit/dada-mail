package DADA::App::ScreenCache;
use 5.008_001;
use Encode qw(encode decode);

use strict;
use lib qw(../../ ../../DADA/perllib);

use DADA::Config;
use DADA::App::Guts; 

use Carp;
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

    return if $DADA::Config::SCREEN_CACHE ne '1';

	if(! -r $DADA::Config::TMP || ! -w $DADA::Config::TMP || ! -x $DADA::Config::TMP) { 
		chmod($DADA::Config::DIR_CHMOD , $DADA::Config::TMP)			 
	}
	
    if ( !-d $self->cache_dir ) {
    	if(mkdir( $self->cache_dir, $DADA::Config::DIR_CHMOD )) { 
          if(-d $self->cache_dir){ 
			chmod( $DADA::Config::DIR_CHMOD, $self->cache_dir );
          }
    	}
		else { 
			warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, ' " . $self->cache_dir . " - $! - disabling screen cache.";
			$DADA::Config::SCREEN_CACHE = 0;
		}
	}

}

sub cache_dir {

    my $self = shift;

    return if $DADA::Config::SCREEN_CACHE  ne '1';

    return DADA::App::Guts::make_safer( $DADA::Config::TMP . '/_screen_cache' );

}

sub cached {

    my $self   = shift;
    my $screen = shift;

    return if $DADA::Config::SCREEN_CACHE  ne '1';
	my $filename = make_safer($self->cache_dir . '/' . $self->translate_name($screen)); 
	#    exists          readable. 
    if ( -e $filename && -r _ ) { 
        return 1;
    }
    else {
        return 0;
    }
}

sub profile_on {
    my $self = shift;
    use CGI;
    my $q = CGI->new;
    if ( $DADA::Config::PROFILE_OPTIONS->{enabled} == 1 ) {
        my $profile_cookie_name =
          $DADA::Config::PROFILE_OPTIONS->{cookie_params}->{-name};
        if ( grep { $_ eq $profile_cookie_name } $q->cookie() ) {
            if ( length( $q->cookie($profile_cookie_name) ) > 0 ) {
                return 1;
            }
            else {
                return 0;
            }
        }
    }
    else {
        return 0;
    }

}

sub show {

    my $self   = shift;
    my $screen = shift;
    my ($args) = @_;
    if ( !exists( $args->{-check_for_header} ) ) {
        $args->{-check_for_header} = 0;
    }
    my $filename = $self->cache_dir . '/' . $self->translate_name($screen);

    if ( $self->cached($screen) ) {

        if ($self->_is_binary($filename)) {
            open SCREEN, '<', DADA::App::Guts::make_safer($filename)
              or croak("cannot open $filename - $!");
            binmode SCREEN;
        }
        else {
            open SCREEN, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', DADA::App::Guts::make_safer($filename)
              or croak("cannot open $filename - $!");
        }
        my $first_line = <SCREEN>;

        if ( $args->{-check_for_header} == 1 ) {
            if ( $first_line !~ m/Content\-Type\:/ ) {
                require CGI;
                my $q = CGI->new;
                $q->charset($DADA::Config::HTML_CHARSET);
                e_print($q->header('text/plain'));
            }
        }
        if ($self->_is_binary($filename)) {
			print($first_line);
	        while ( my $l = <SCREEN> ) {
	            print($l);
	        }	
		}
		else { 	
			e_print($first_line);
	        while ( my $l = <SCREEN> ) {
	            e_print($l);
	        }
		}
        close(SCREEN)
          or croak("cannot close $filename - $!");
    }
    else {
        croak "screen is not cached! " . $!;
    }

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


sub pass {

    my $self     = shift;
    my $screen   = shift;
    my $filename = $self->cache_dir . '/' . $self->translate_name($screen);

    if ( $self->cached($screen) ) {

        if ($self->_is_binary($filename)) {
            open SCREEN, '<', DADA::App::Guts::make_safer($filename)
              or croak("cannot open $filename - $!");
            binmode SCREEN;
        }
        else {
            open SCREEN, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',
              DADA::App::Guts::make_safer($filename)
              or croak("cannot open $filename - $!");
        }

        my $return;

		# If the first line is a, "Content-Type" line, skip it. 
        my $first_line = <SCREEN>;
        if ( $first_line =~ m/Content\-Type\:/ ) {
			# ... 
        }
		else { 
			$return .= $first_line; 
		}
		 
        while ( my $l = <SCREEN> ) {
            $return .= $l;
        }
        close(SCREEN)
          or croak("cannot close $filename - $!");

        return $return;

    }
    else {
        croak "screen is not cached! " . $!;
    }

}

sub cache {

    my $self   = shift;
    my $screen = shift;
    my $data   = shift;

	eval { 
	    my $unref = $$data;
	    return if $DADA::Config::SCREEN_CACHE  ne '1';
	    my $filename =
	      DADA::App::Guts::make_safer(
	        $self->cache_dir . '/' . $self->translate_name($screen) );


		
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
	            $self->cache_dir . '/' . $self->translate_name($screen)
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

sub flush {

    my $self = shift;

    return if $DADA::Config::SCREEN_CACHE  ne '1';

    my $f;
    opendir( CACHE, $self->cache_dir )
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open '" . $self->cache_dir . "' to read because: $!";

    while ( defined( $f = readdir CACHE ) ) {

        #don't read '.' or '..'
        next if $f =~ /^\.\.?$/;

        $f =~ s(^.*/)();

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

sub translate_name {

    my $self = shift;
    my $file = shift;
    $file =~ s/\//./g;
    $file =~ s/\@/_at_/g;
    $file =~ s/\>|\<//g;

    return $file;
}

sub cached_screens {

    my $self = shift;
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

        push( @{$listing}, { name => $f, size => int( $size / 1024 ) } );
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

