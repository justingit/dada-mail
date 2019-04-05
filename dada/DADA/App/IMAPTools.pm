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

require Exporter; 
@ISA = qw(Exporter); 


use strict; 

use vars qw(@EXPORT); 

@EXPORT = qw(); 


sub imap_login { 

    my ($args) = @_;
	my $r = ''; 
	
	use Data::Dumper; 
	$r .= 'args: . ' . Dumper($args);
	
	require Net::IMAP::Simple;
   
    if(! exists($args->{IMAP_server})){ 
        croak "No Server Passed!";
    }
    
   if(! exists($args->{IMAP_username})){ 
        croak "No Username Passed!";
    }
    
   if(! exists($args->{IMAP_password})){ 
        croak "No Password Passed!";
    }
    
    if(! exists($args->{IMAP_verbose})){ 
        $args->{IMAP_verbose} = 0; 
    }
	
    #if(! exists($args->{AUTH_MODE})){ 
    #    $args->{AUTH_MODE} = 'POP'; 
    #}

	#if(!exists($args->{USESSL})){ 
	#	$args->{USESSL} = 0;
	#}
	#
	#if(!exists($args->{starttls})){ 
	#	$args->{starttls} = 0;
	#}
	#
	#if(!exists($args->{SSL_verify_mode})) { 
	#	$args->{SSL_verify_mode} = 0;
	#}
	
	#my $SSL = 0; 
	#if($args->{USESSL} == 1 && $args->{starttls} == 0){ 
	#	$SSL = 1; 
	#}
	#
	#if(!exists($args->{port})){ 
	#	if($SSL == 1){
	#		$args->{port} = '995'; 
	#	}
	#	else { 
	#		$args->{port} = '110'; 
	#	}
	#}
	#elsif($args->{port} eq 'AUTO'){ 
	#	if($SSL == 1){
	#		$args->{port} = '995'; 
	#	}
	#	else { 
	#		$args->{port} = '110'; 
	#	}
	#}
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
	
	if(length($args->{IMAP_server}) <= 0 ) { 
	    $r .= 'Server is blank?' . "\n";
	    return (undef, 0, $r); 
	}
	else { 
	    
        $r .= "* Connecting to IMAP host:'" . $args->{IMAP_server} . "' on port:'" . $args->{IMAP_port} . "'\n"; 
					
		
		my $imap   = undef; 
		my $status = 0; 
		
		$imap = Net::IMAP::Simple->new(
			$args->{IMAP_server}, 
			use_ssl => 1, 
			port => $args->{IMAP_port}, 
			# debug => 1
		) or warn "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";		
		
		# require Data::Dumper; 
		#$r .= 'Arguments Sent:' . 
		#'Server: ' . $args->{server} . "\n" . 
		#Data::Dumper::Dumper($n_p3_args); 
		
		if(!defined($imap)){ 
			 $r .= "* Connection to '" . $args->{IMAP_server} . "' wasn't successful: " . $Net::IMAP::Simple::errstr . "\n";
			return ( undef, 0, $r );
		}
		
	
		#	$r .= '* ' . $pop->banner() . "\n";
		
		if($imap->login(
			$args->{IMAP_username},
			$args->{IMAP_password})
		){
			$status = 1; 
			$r .= "IMAP login successful\n";
		} else {
		    $r .=  "IMAP login failed: " . $imap->errstr . "\n";
			$imap = undef; 
		}
	
		
		my $count = 0; 
		   $count = $imap->select('INBOX');
		
		$r .= "\n";			
        $r .= "* IMAP Login succeeded!\n";
        $r .= "* Message count: " . $count . "\n";
  
           return ( $imap, 1, $r );
      
	  }
}





1;
