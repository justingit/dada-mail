package DADA::Security::AuthenCAPTCHA::reCAPTCHA;
use strict; 
use lib qw(../../../ ../../../DADA/perllib); 


use DADA::Config 5.0.0;

if(
	!defined($DADA::Config::RECAPTCHA_PARAMS->{remote_address}) ||
    !defined($DADA::Config::RECAPTCHA_PARAMS->{public_key})     ||	
    !defined($DADA::Config::RECAPTCHA_PARAMS->{private_key})
){ 
	die 'You\'ll need to configure Captcha::reCAPTCHA in DADA::Config!'; 
}		

use base "Captcha::reCAPTCHA"; 

1; 
