package DADA::App::SMTPTools;


# use IO::Socket::SSL qw(debug3);

use lib qw(../../ ../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  

use Carp qw(carp croak);

use Try::Tiny; 

require Exporter; 
@ISA = qw(Exporter); 


use strict; 

use vars qw(@EXPORT); 

@EXPORT = qw(); 


sub smtp_obj { 
	
	my ($args) = @_; 
	
	my $status   = 1; 
	my $r        = ''; 
	my $smtp_obj = undef; 
	
	require Net::SMTP; 
	
	if(!exists($args->{hello})){ 
	    $r .= 'Identify yourself in the, "hello" argument, please!' . "\n";
	    return (undef, 0, $r); 
	}
	
	if(!exists($args->{ssl})){ 
		$args->{ssl} = 0; 
	}
	
	if(!exists($args->{starttls})){ 
		$args->{starttls} = 0; 
	}
	
	my $SSL = 0; 
	if($args->{ssl} == 1 && $args->{starttls} == 0){ 
		$SSL = 1; 
	}
	
	if(!exists($args->{port})){ 
		if($SSL == 1){
			$args->{port} = '465'; 
		}
		else { 
			$args->{port} = '25'; 
		}
	}
	elsif($args->{port} eq 'AUTO'){ 
		if($SSL == 1){
			$args->{port} = '465'; 
		}
		else { 
			$args->{port} = '25'; 
		}
	}
	
	if(! exists($args->{host})){ 
		$args->{host} = 'localhost'; # or should I just return with an error? 
	}
	
	if(!exists($args->{username})){
		$args->{username} = undef; 
	} 

	if(!exists($args->{password})){
		$args->{password} = undef; 
	} 

	if(!exists($args->{sasl_auth_mechanism})){ 
		$args->{sasl_auth_mechanism} = 'AUTO';
	}
		
	if(! exists($args->{timeout})){ 
		$args->{timeout} = 60; 
	}
	

	
	if(!exists($args->{ssl_verify_mode})){
		$args->{ssl_verify_mode} = 0; 
	}
	
	if(!exists($args->{debug})){ 
		$args->{debug} = 0;
	}
	# Override everything!
	if($DADA::Config::CPAN_DEBUG_SETTINGS{NET_SMTP} == 1){ 
		$args->{debug} = 1; 
	}
	
	
	$r .= "Connecting to SMTP host:" . $args->{host} . ' on port:' . $args->{port} . "\n"; 

	
	if($SSL == 1){ 
		$r .= "SSL: enabled\n";
	}
	else { 
		$r .= "SSL: disabled\n";
	}
	
	if($args->{starttls} == 1){ 
		$r .= "STARTTLS: enabled\n";
	}
	else { 
		$r .= "STARTTLS: disabled\n";	
	}
	
	if($args->{ssl_verify_mode} == 1){ 
		$r .= "Verifying SSL Certificate during connection\n";
	}
	else { 
		$r .= "NOT Verifying SSL Certificate during connection\n";
	}

	
	$r .= "\n";
	
	my $smtp_args = { 
		Hello   => $args->{hello},
		Port    => $args->{port},
		SSL     => $SSL,
		Debug   => $args->{debug}, 
		Timeout => $args->{timeout},
	};
	
	# Docs don't even mention this, so I don't even know if this is a thing, 
	# But if it is, this is how I think I can do it... 
	if($args->{ssl_verify_mode} == 0){ 
		$smtp_args->{SSL_verify_mode} = 0; 
	}
	
	try {
		$smtp_obj = Net::SMTP->new(
			$args->{host},
			%$smtp_args,
		) or $r .= "Connection to '" . $args->{host} . "' failed: $@\n";
	} catch { 
		warn $r 
			if($args->{debug} == 1); 
		return (0, $r, undef); 
	};
	
	if(!defined($smtp_obj)){ 
		warn $r 
			if($args->{debug} == 1); 
		return (0, $r, undef); 
	}
	
	$r .= $smtp_obj->banner() . "\n";
	
	if($smtp_obj->can_ssl()){ 
		$r .= "SSL Supported.\n";
	}else { 
		$r .= "SSL is NOT Supported.\n";
	}
	
	if($args->{starttls} == 1){
		$r .= "STARTTLS\n";
		if($args->{ssl_verify_mode} == 0){ 
			$smtp_obj->starttls(
				SSL_verify_mode => 0,
			); 
		}
		else {
			$smtp_obj->starttls(); 
		}
	}
	else{ 
		$r .= "no STARTTLS\n";
	}

	if(
			defined($args->{username})
		 && defined($args->{username})
	 ){
		my $auth_r = 0; 
		if($args->{sasl_auth_mechanism} eq 'AUTO'){
		 	$auth_r = $smtp_obj->auth(
				$args->{username},	
				$args->{password},
			);
		}
		else { 
			require Authen::SASL;
			my $sasl = Authen::SASL->new(
			  mechanism => $args->{sasl_auth_mechanism},
			  callback => {
	  		    user => $args->{username},
			    pass => $args->{password},
			  }
			);
		 	$auth_r = $smtp_obj->auth($sasl);
		}
		if($auth_r != 1){ 
			$r .= "Connection to '" . $args->{host} . "' failed: $@\n";
			$smtp_obj->quit;
			warn $r 
				if($args->{debug} == 1); 
			return (0, $r, undef); 	
		}
	}
	
	if(defined($smtp_obj)){
		$r .= "* SMTP Login succeeded!" . $smtp_obj->domain . "\n";
		warn $r 
			if($args->{debug} == 1); 
		return (1, $r, $smtp_obj);
	}
	else { 
		$r .= "Connection to '" . $args->{host} . "' failed: $@\n";
		warn $r 
			if($args->{debug} == 1); 
		return (0, $r, undef); 	
	}
	
}




1;
