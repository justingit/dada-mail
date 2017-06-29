package DADA::App::POP3Tools;
use lib qw(../../ ../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  

use Carp qw(carp croak);
use Fcntl qw(

    :DEFAULT
    :flock
    LOCK_SH
    O_RDONLY
    O_CREAT
    O_WRONLY
    O_TRUNC

);

require Exporter; 
@ISA = qw(Exporter); 


use strict; 

use vars qw(@EXPORT); 

@EXPORT = qw(); 


sub net_pop3_login { 

    my ($args) = @_;
	my $r = ''; 
	
    require Net::POP3;

    if(! exists($args->{server})){ 
        croak "No Server Passed!";
    }
    
   if(! exists($args->{username})){ 
        croak "No Username Passed!";
    }
    
   if(! exists($args->{password})){ 
        croak "No Password Passed!";
    }
    
    if(! exists($args->{verbose})){ 
        $args->{verbose} = 0; 
    }

	if(!exists($args->{USESSL})){ 
		$args->{USESSL} = 0;
	}
		
	if(!exists($args->{port})){ 
		if($args->{USESSL} == 1){
			$args->{port} = '995'; 
		}
		else { 
			$args->{port} = '110'; 
		}
	}
	
	
	if(length($args->{server}) <= 0 ) { 
	    $r .= 'Server is blank?' . "\n";
	    return (undef, 0, $r); 
	}
	else { 
	    
        $r .= "\t* Logging into POP3 server '" . $args->{server} . "'\n"; 
    
=cut	
		use Data::Dumper; 
		warn 'passing: ' . Dumper(
		{
			
			server => $args->{server},
			SSL             => $args->{USESSL}, 
			Port            => $args->{port}, 
			Timeout         => 60,
			SSL_verify_mode => 0,
			Debug           => 1, 	
		}	
		);

=cut
					

        my $pop = Net::POP3->new(
			$args->{server},
			SSL             => $args->{USESSL}, 
			Port            => $args->{port}, 
			Timeout         => 60,
			SSL_verify_mode => 0,
			#Debug           => 1, 		
 		);
		
	    $args->{server},

		
		
		
		
		
		my $lr = $pop->login(
			$args->{username},
			$args->{password}
		); 
		if($lr eq undef){ 
            $r .= "\t* Connection to '" . $args->{server} . "' wasn't successful\n";
       	   return ( undef, 0, $r );
		}
		else {
                $r .= "\t* POP3 Login succeeded.\n";
                $r .= "\t* Message count: " . $lr . "\n";
           }
		   
           return ( $pop, 1, $r );
      
	  }
}




sub _lock_pop3_check { 

    my ($args) = @_;
	    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _lock_pop3_check"; 
    }
    
	if(-f _lockfile_name($args)){ 
		# oh, boy - the lockfile exists. 
		# -M  Script start time minus file modification time, in days.
		if(-M _lockfile_name($args) > 1){ 
			# And it's really old. Let's remove! 
			_remove_pop3_check($args);
		}
	}
	
	if(open my $POP3_SAFETYLOCK, ">", _lockfile_name($args)) {
		chmod($DADA::Config::FILE_CHMOD , _lockfile_name($args)); 
		{
			my $sleep_count = 0; 
			{ 
				flock $POP3_SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
				sleep 1;
				redo if ++$sleep_count < 11; 		
				warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: Server is too busy to open semaphore file , " . _lockfile_name($args) . " -   $!\n";
				return undef; 
			}
		}
		return $POP3_SAFETYLOCK; 
	}
	else { 
		warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - Cannot open list lock file " . _lockfile_name($args) . " - $!";
		return undef; 
	}
}



sub _remove_pop3_check { 
	
	my ($args) = @_;
    
	if(-f _lockfile_name($args)){ 
		unlink(_lockfile_name($args)) 
			or carp "couldn't delete lock file: '" . _lockfile_name($args) . "' - $!";
	}
	
}

sub _unlock_pop3_check { 

    my ($args) = @_;
	my $fh = undef; 
    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _unlock_pop3_check"; 
    }
    if(! exists($args->{fh})){ 
        croak "You need to supply a filehandle in fh! ";
	}
	else { 
		$fh = $args->{fh}; 
	}
	
	if(defined($fh)) {
		close($fh);
		if(-f _lockfile_name($args)){ 
			unlink(_lockfile_name($args)) 
				or carp "couldn't delete lock file: '" . _lockfile_name($args) . "' - $!";
		}
	}
}




sub _lockfile_name {

    my ($args) = @_;
    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _lockfile_name"; 
    }
	return  _safe_path("$DADA::Config::TMP/" . $args->{name});	 
}


sub _safe_path { 

    my $p = shift; 
       $p =~ tr/\0-\037\177-\377//d;    # remove unprintables
	   $p =~ s/(['\\])/\$1/g;           # escape quote, backslash
	   $p =~ /(.*)/;
	
	return $1;

}



1;
