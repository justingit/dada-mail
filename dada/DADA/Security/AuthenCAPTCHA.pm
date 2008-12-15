package DADA::Security::AuthenCAPTCHA;

use strict; 

use lib qw(../../ ../../DADA ../perllib ./ ../ ../perllib ../../ ../../perllib); 


use DADA::Config qw(!:DEFAULT); 

use Carp qw(croak carp); 

if (eval "require DADA::Security::AuthenCAPTCHA::$DADA::Config::CAPTCHA_TYPE") {
    use base "DADA::Security::AuthenCAPTCHA::$DADA::Config::CAPTCHA_TYPE";
    
}else{ 
    die("cannot find 'DADA::Security::AuthenCAPTCHA::$DADA::Config::CAPTCHA_TYPE', $!");
}


1;
