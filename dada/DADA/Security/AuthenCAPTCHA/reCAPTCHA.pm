package DADA::Security::AuthenCAPTCHA::reCAPTCHA;
use strict; 
use lib qw(../../../ ../../../DADA/perllib); 


use DADA::Config 7.0.0;

if(
	!defined($DADA::Config::RECAPTCHA_PARAMS->{remote_address}) ||
    !defined($DADA::Config::RECAPTCHA_PARAMS->{public_key})     ||	
    !defined($DADA::Config::RECAPTCHA_PARAMS->{private_key})    ||
	$DADA::Config::RECAPTCHA_PARAMS->{remote_address}     eq '' ||
    $DADA::Config::RECAPTCHA_PARAMS->{public_key}         eq '' ||	
    $DADA::Config::RECAPTCHA_PARAMS->{private_key}        eq ''
){ 
	die 'You\'ll need to configure Captcha::reCAPTCHA in your config.'; 
}		

use base "Captcha::reCAPTCHA"; 

1; 
