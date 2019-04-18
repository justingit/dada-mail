package DADA::App::IMAPTools;
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
use Try::Tiny; 

require Exporter; 
@ISA = qw(Exporter); 


use strict; 

use vars qw(@EXPORT); 

@EXPORT = qw(); 


sub imap_login { 

    my ($args) = @_;
	my $r = ''; 
		
	try {
		require Net::IMAP::Simple;
    } catch { 
		return (undef, 0, 'Net::IMAP::Simple needs to be installed for IMAP support.'); 
	};
	
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
	
    #if(! exists($args->{AUTH_MODE})){ 
    #    $args->{AUTH_MODE} = 'POP'; 
    #}

	if(!exists($args->{USESSL})){ 
		$args->{USESSL} = 0;
	}
	
	if(!exists($args->{starttls})){ 
		$args->{starttls} = 0;
	}
	#
	#if(!exists($args->{SSL_verify_mode})) { 
	#	$args->{SSL_verify_mode} = 0;
	#}
	
	my $SSL = 0; 
	if($args->{USESSL} == 1 && $args->{starttls} == 0){ 
		$SSL = 1; 
	}
	
	if(!exists($args->{port})){ 
		if($SSL == 1){
			$args->{port} = '993'; 
		}
		else { 
			$args->{port} = '143'; 
		}
	}
	elsif($args->{port} eq 'AUTO'){ 
		if($SSL == 1){
			$args->{port} = '993'; 
		}
		else { 
			$args->{port} = '143'; 
		}
	}
	#
	#
	#if(!exists($args->{debug})){ 
	#	$args->{debug} = 0;
	#}
	# Override everything!
	#if($DADA::Config::CPAN_DEBUG_SETTINGS{NET_POP3} == 1){ 
	#	$args->{debug} = 1; 
	#}
	
	$r .= "* Connecting with Net::IMAP::Simple v" . $Net::IMAP::Simple::VERSION . "\n"; 
	
	if(length($args->{server}) <= 0 ) { 
	    $r .= 'Server is blank?' . "\n";
	    return (undef, 0, $r); 
	}
	else { 
	    
        $r .= "* Connecting to IMAP host:'" . $args->{server} . "' on port:'" . $args->{port} . "'\n"; 
					
		
		my $imap   = undef; 
		my $status = 0; 
		
		$imap = Net::IMAP::Simple->new(
			$args->{server}, 
			use_ssl => $SSL, 
			port => $args->{port}, 
			# debug => 1
		) or warn "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";		
				
		if(!defined($imap)){ 
			 $r .= "* Connection to '" . $args->{server} . "' wasn't successful: " . $Net::IMAP::Simple::errstr . "\n";
			return ( undef, 0, $r );
		}
		
		if($args->{starttls} == 1){
			if($imap->starttls()) { 
				$r .= "* STARTTLS Succeeded!\n";
			} 
			else { 
				$r .= "* STARTTLS Failed!\n";
			}
		}
				
		if($imap->login(
			$args->{username},
			$args->{password})
		){
			$status = 1; 
			#$r .= "* IMAP login successful\n";
		} else {
		    $r .=  "* IMAP login failed: " . $imap->errstr . "\n";
			$imap = undef; 
		}
		
		if($status == 1){ 
			my $count = 0; 
			   $count = $imap->select('INBOX');
		
			$r .= "\n";			
	        $r .= "* IMAP Login successful.\n";
	        $r .= "* INBOX Message count: " . $count . "\n";
  
	           return ( $imap, 1, $r );
		   }
      
	  }
}





1;
