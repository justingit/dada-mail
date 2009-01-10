package DADA::MailingList::SubscriberFields; 
use lib qw(../../ ../../DADA ../../perllib);


use Carp qw(carp croak);
my $type; 
use DADA::Config qw(!:DEFAULT); 	
BEGIN { 
	$type = $DADA::Config::SUBSCRIBER_DB_TYPE;
	if($type =~ m/sql/i){ 
		$type = 'baseSQL';
	}
}
use base "DADA::MailingList::SubscriberFields::$type";
#use DADA::MailingList::Subscriber; 
#use DADA::MailingList::Subscribers; 


use strict; 

use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;





1; 

