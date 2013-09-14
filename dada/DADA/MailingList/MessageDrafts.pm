package DADA::MailingList::MessageDrafts;

use lib qw(
	../../
	../../DADA/perllib
);

BEGIN { 
	my $type = $DADA::Config::BACKEND_DB_TYPE;
	if($type eq 'SQL'){ 
			$backend = 'baseSQL';
	}
	elsif($type eq 'Default'){ 
		$backend = 'Default'; 
	}
	else { 
		die "Unknown \$BACKEND_DB_TYPE: '$type' Supported types: 'SQL'"; 
	}
}
use base "DADA::MailingList::MessageDrafts::$backend";

1;