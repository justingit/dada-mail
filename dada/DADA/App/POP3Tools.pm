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


sub mail_pop3client_login { 

    my ($args) = @_;
    my $params = {};
	my $r = ''; 
	
    require Mail::POP3Client; 

    if(! exists($args->{server})){ 
        croak "No Server Passed!";
    }
	$params->{HOST} = $args->{server};
    
   if(! exists($args->{username})){ 
        croak "No Username Passed!";
    }
    
   if(! exists($args->{password})){ 
        croak "No Password Passed!";
    }
    
    if(! exists($args->{verbose})){ 
        $args->{verbose} = 0; 
    }
	if(exists($args->{port})){ 
		if($args->{port} eq 'AUTO'){ 
			# ...
		}
		else { 
			$params->{PORT} = $args->{port};
		}
	}
	if(exists($args->{USESSL})){ 
		if($args->{USESSL} == 1){ 
			$params->{USESSL} = 1;
		}
	}
	if(exists($args->{AUTH_MODE})){ 
		if($args->{AUTH_MODE} ne 'BEST'){ 
			$params->{AUTH_MODE} = $args->{AUTH_MODE};
		}
	}

	if($DADA::Config::CPAN_DEBUG_SETTINGS{MAIL_POP3CLIENT} == 1){ 
		$params->{DEBUG} = 1;	
	}
	
    $r .= "\tLogging into POP3 server: " . $args->{server} . "\n"; 
    
    my $pop = new Mail::POP3Client(%$params);
       $pop->User( $args->{username} );
       $pop->Pass( $args->{password} );

       $pop->Connect() >= 0 || die $pop->Message();
       
       if($pop->Count == -1){ 
            $r .= "\tConnection to '" . $args->{server} . "' wasn't successful: " . $pop->Message() . "\n";
       	   return ( undef, 0, $r );
	    
		}
       else { 
            $r .= "\tPOP3 Login succeeded.\n";
            $r .= "\n\tMessage count: " . $pop->Count . "\n";
       }

       return ( $pop, 1, $r );
    
}




sub _lock_pop3_check { 

    my ($args) = @_;
	
    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _lock_pop3_check"; 
    }
    
	if(-f _lockfile_name($args)){ 
		# oh, boy - the lockfile exists. 
		if(-M _lockfile_name($args) > 1){ 
			# And it's really old. Let's remove! 
			_remove_pop3_check($args);
		}
	}
    
	#sysopen(POP3_SAFETYLOCK, _lockfile_name($args),  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
	
	open my $POP3_SAFETYLOCK, ">", _lockfile_name($args)
		or croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - Cannot open list lock file " . _lockfile_name($args) . " - $!";
	chmod($DADA::Config::FILE_CHMOD , _lockfile_name($args)); 
	{
		my $sleep_count = 0; 
		{ 
			flock $POP3_SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
			sleep 1;
			redo if ++$sleep_count < 11; 		
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: Server is way too busy to open semaphore file , " . _lockfile_name($args) . " -   $!\n";
		}
	}
	
	return $POP3_SAFETYLOCK; 
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
    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _unlock_pop3_check"; 
    }
    if(! exists($args->{fh})){ 
        croak "You need to supply a filehandle in fh! ";
	}
	
	close($args->{fh});
	if(-f _lockfile_name($args)){ 
		unlink(_lockfile_name($args)) 
			or carp "couldn't delete lock file: '" . _lockfile_name($args) . "' - $!";
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
