package DADA::MailingList::ConsentHistory;

use lib qw(./ ../DADA ../ ../../ ../../DADA ../perllib); 

use Carp qw(carp croak);
use Try::Tiny; 

use DADA::Config;
use DADA::App::Guts;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();
use strict;
use vars qw(@EXPORT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_ConsentHistory};

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
	
	return $self; 

}


sub _init {
	my $self = shift; 
	$self->{sql_params} = {%DADA::Config::SQL_PARAMS};
	my $dbi_obj = undef;
    require DADA::App::DBIHandle;
    $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}



sub start_consent { 
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-source})){ 
		$args->{-source} = 'unknown';
	}
	
	if(!exists($args->{-source_location})){ 
		$args->{-source_location} = 'unknown';
	}
	
	$args->{-token}  = $self->token; 
	$args->{-action} = 'start consent';
	
	$self->ch_record($args);

	return $args->{-token};
}

sub token { 
	my $self = shift; 
	
	require DADA::Security::Password; 
	my $str = DADA::Security::Password::generate_rand_string(undef, 40);
	try { 
		# Entirely unneeded: 
		require Digest::SHA1;
		$str = Digest::SHA1->new->add('blob '.length($str)."\0".$str)->hexdigest(), "\n";
	}
	return $str; 
}

sub ch_record {
	

	# insert into dada_consent_activity (email) values('user@example.com'); 

	$DADA::Config::SQL_PARAMS{consent_activity_table} = 'dada_consent_activity';
		
    my $self = shift;
    my ($args) = @_;
	
	if(!exists($args->{-email})){
		croak '-email is required!'; 
	}

	if(!exists($args->{-list},)){ 
		croak '-list is required!'; 
	}
	
	if(!exists($args->{-token})){
		#croak '-token is required!'; 
		$args->{-token} = undef; 
	}
	
	if(!exists($args->{-remote_addr},)){ 
		$args->{-remote_addr} = $self->remote_addr;
	}

	if(!exists($args->{-action},)){ 
		$args->{-action} = 'unknown';
	}

	if(!exists($args->{-list_type},)){ 
		$args->{-list_type} = 'list';
	}

	if(!exists($args->{-consent_id},)){ 
		$args->{-consent_id} = undef;
	}
	
	if(!exists($args->{-source})){
		#croak '-token is required!'; 
		$args->{-source} = undef; 
	}
	
	if(!exists($args->{-source_location})){
		#croak '-token is required!'; 
		$args->{-source_location} = undef; 
	}
	
	my @payload = (
		$args->{-remote_addr},
		$args->{-email},      
		$args->{-list},       
		$args->{-list_type}, 
		$args->{-source}, 
		$args->{-source_location}, 
		$args->{-action},     
		$args->{-token},  
	);
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{consent_activity_table}
      . '(remote_addr, email, list, list_type, source, source_location, action, consent_session_token) VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
		
	if(defined($args->{-consent_id})){
		push(@payload, $args->{-consent_id}); 
		
	  	my $query =
	        'INSERT INTO '
	      . $DADA::Config::SQL_PARAMS{consent_activity_table}
	      . '(remote_addr, email, list, list_type, source, source_location, action, consent_session_token, consent_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';	
	}

    carp 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute(@payload)
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    	$sth->finish;

}


sub remote_addr {
    if(exists($ENV{HTTP_X_FORWARDED_FOR})){ 
        # http://en.wikipedia.org/wiki/X-Forwarded-For
        my ($client, $proxies) = split(',', $ENV{HTTP_X_FORWARDED_FOR}, 2); 
        return $client; 
    }
    else { 
        return $ENV{'REMOTE_ADDR'} || '127.0.0.1';
    }
}


1;