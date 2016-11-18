package DADA::App::MIMECache;

use lib qw(
  ../../.
  ../../DADA/perllib
);

use Fcntl qw(
  :DEFAULT
  :flock
  LOCK_SH
  O_RDONLY
  O_CREAT
  O_WRONLY
  O_TRUNC
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

use Carp qw(carp croak);
use Try::Tiny;

use vars qw($AUTOLOAD);
use strict;
my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_MimeCache};

my %allowed = (
    lockfile  => undef,
    num_files => 1000,
);

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;

    $self->_init($args);
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    return if ( substr( $AUTOLOAD, -7 ) eq 'DESTROY' );

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
    $self->lockfile( make_safer( $DADA::Config::TMP . '/_mime_cache.lock' ) );
}

sub clean_out {

    my $self = shift;

    my $lock = $self->lock_file();
    if ( !defined($lock) ) {
        # Too busy, I guess.
        return 0;
    }
	else {

	    my $dir  = make_safer( $DADA::Config::TMP . '/_mime_cache' );
	    my $file = undef;
	    my @files;
	    my $c = 0;

	    if ( -d $dir ) {
	        if(opendir( DIR, $dir )) {
		        while ( defined( $file = readdir DIR ) ) {
		            next if $file =~ /^\.\.?$/;
		            $c++;
		            last
		              if $c >= $self->num_files;

		            $file =~ s(^.*/)();
		            $file = make_safer( $dir . '/' . $file );
		            if ( -f $file && -M $file > 3 ) {
		                my $unlink_check = unlink($file);
		                if ( $unlink_check != 1 ) {
		                    warn "couldn't delete tmp: " . $file;
		                }
		            }
		        }
		        closedir(DIR);
			}
			else { 
                warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not open directory: '" . $dir ."' $!";
				return undef; 
			}
	    }
	    else {
	        if ( mkdir( $dir, $DADA::Config::DIR_CHMOD ) ) {
	            # good!
	        }
	        else {
	            warn "couldn't make dir, $dir";
	        }
	    }
	    $self->unlock_file($lock);
	}

}

sub lock_file {

    my $self = shift;
    my $i = 0;

	if(-f $self->lockfile){ 
		if(-M $self->lockfile > 1){ 
			$self->remove_lockfile(); 
		}
	}

    my $countdown = shift || 10;

    if ( open my $fh, ">", $self->lockfile ) {
        chmod $DADA::Config::FILE_CHMOD, $self->lockfile;
        {
            my $count = 0;
            {
                flock $fh, LOCK_EX | LOCK_NB and last;
                sleep 1;
				$count++; 
                redo if $count < $countdown;
				
                carp "Couldn't lock semaphore file '"
                  . $self->lockfile
                  . "' because: '$!', exiting with error to avoid file corruption!";
                return undef;
            }
        }
	    return $fh;
    }
    else {
        warn "Can't open semaphore file " . $self->lockfile . " because: $!";
    }



}


sub remove_lockfile { 
	my $self = shift; 
	
    my $unlink_check = unlink($self->lockfile);
    if ( $unlink_check != 1 ) {
        warn "deleting," . $self->lockfile . " failed: " . $!;
    	return 0; 
	}
	else { 
		return 1;
	}
}

sub unlock_file {

    my $self = shift;
    my $fh = shift || croak "You must pass a filehandle to unlock!";
    if(close($fh)){ 
		$self->remove_lockfile();
	    return 1;
	}
	else { 
		warn q{Couldn't unlock semaphore file for, } . $fh . ' ' . $!;
		return 0; 
	}
}

1;
