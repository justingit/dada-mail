package DADA::Security::AuthenCAPTCHA;;

# This is all sorts of messed up. 
use strict; 

use lib qw(../../ ../../DADA ../perllib ./ ../ ../perllib ../../ ../../perllib); 


use DADA::Config qw(!:DEFAULT); 

use Carp qw(croak carp); 

if (eval "require require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;::$DADA::Config::CAPTCHA_TYPE") {
    use base "require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;::$DADA::Config::CAPTCHA_TYPE";
    
}else{ 
    die("cannot find 'require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;::$DADA::Config::CAPTCHA_TYPE', $!");
}


1;
