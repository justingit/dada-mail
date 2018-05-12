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
	
	$DADA::Config::SQL_PARAMS{consent_activity_table} = 'dada_consent_activity';
	
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
	
	# auto data migration! 
	require DADA::MailingList::PrivacyPolicyManager;
	my $ppm = DADA::MailingList::PrivacyPolicyManager->new; 
	my $pp_data = $ppm->latest_privacy_policy({-list => $args->{-list}});
	if(!exists($pp_data->{privacy_policy})){ 
		require DADA::MailingList::Settings; 
		my $ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
		my $new_pp_id = $ppm->add(
			{ 
				-list           => -list => $args->{-list}, 
				-privacy_policy => $ls->param('privacy_policy'), 
			}
		); 
		$pp_data = $ppm->latest_privacy_policy({-list => -list => $args->{-list}});
	}
	
	$args->{-privacy_policy_id}	= $pp_data->{privacy_policy_id};
	
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
	
	if(!exists($args->{-privacy_policy_id})){
		$args->{-privacy_policy_id} = undef; 
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
		$args->{-privacy_policy_id},
	);
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{consent_activity_table}
      . '(remote_addr, email, list, list_type, source, source_location, action, consent_session_token, privacy_policy_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';
		
	if(defined($args->{-consent_id})){
		
		warn "we've got a -consent_id";
		push(@payload, $args->{-consent_id}); 
	  	$query =
	        'INSERT INTO '
	      . $DADA::Config::SQL_PARAMS{consent_activity_table}
	      . '(remote_addr, email, list, list_type, source, source_location, action, consent_session_token, privacy_policy_id, consent_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';	
	}

    carp 'QUERY: ' . $query;
#      if $t;

    my $sth = $self->{dbh}->prepare($query);

	
#	use Data::Dumper; 
#	warn 'payload!' . Dumper([@payload]);

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


sub subscriber_consented_to { 
	
	use Data::Dumper; 
	
	my $self  = shift; 
	my $list  = shift; 
	my $email = shift; 
	
	my $consent_scorecard = {}; 
		
    my $query = 'SELECT timestamp, action, consent_id FROM ' 
	.  $DADA::Config::SQL_PARAMS{consent_activity_table} 
	. ' WHERE list = ? AND email = ? AND'
	. ' (action = "consent granted" OR action = "consent revoked")'
	. ' ORDER BY timestamp ASC';
	
	#warn 'QUERY: ' . $query;
    my $sth = $self->{dbh}->prepare($query);
	
	$sth->execute($list, $email);
	
 	while ( my $fields = $sth->fetchrow_hashref ) {
		
		my $consent_id = $fields->{consent_id}; 
		
		if(!exists($consent_scorecard->{$consent_id})) { 
			$consent_scorecard->{$consent_id} = 0; 
		}
		if($fields->{action} eq 'consent granted') {
			$consent_scorecard->{$consent_id} = int($consent_scorecard->{$consent_id}) + 1;
		}
		elsif($fields->{action} eq 'consent revoked') {  
			$consent_scorecard->{$consent_id} = int($consent_scorecard->{$consent_id}) - 1;
		}
    }
	
	my $consents = []; 
	for(keys %$consent_scorecard){ 
		if($consent_scorecard->{$_} >= 1){ 
			push(@$consents, $_)
		}
		else { 
			warn 'consent, ' . $_ . 'was revoked!';
		}
	}
	
    return $consents;
}

sub consent_history_report { 

	my $self   = shift; 
	my ($args) = @_; 

	my $dada_consent_activity = 'dada_consent_activity';
	my $dada_privacy_policies = 'dada_privacy_policies';
	my $dada_consents         = 'dada_consents';
	
	my $query = qq{ 
		SELECT 
			$dada_consent_activity.consent_activity_id AS consent_activity_id, 
		    $dada_consent_activity.remote_addr         AS remote_addr,
		    $dada_consent_activity.timestamp           AS timestamp,
		    $dada_consent_activity.email               AS email,
		    $dada_consent_activity.list                AS list,
		    $dada_consent_activity.action              AS action,
		    $dada_consent_activity.source              AS source,
		    $dada_consent_activity.source_location     AS source_location,
		    $dada_consent_activity.consent_id          AS consent_id,
		    $dada_consent_activity.privacy_policy_id   AS privacy_policy_id,
		    $dada_privacy_policies.privacy_policy      AS privacy_policy,
		    $dada_consents.consent                     AS consent
		 FROM $dada_consent_activity
		    LEFT JOIN $dada_privacy_policies ON $dada_consent_activity.privacy_policy_id = $dada_privacy_policies.privacy_policy_id
		    LEFT JOIN $dada_consents         ON $dada_consent_activity.consent_id        = $dada_consents.consent_id
		 WHERE $dada_consent_activity.email = ? AND $dada_consent_activity.list = ?
		 ORDER BY $dada_consent_activity.timestamp ASC
	};
	
	warn 'QUERY:' . $query; 
	
    my $sth = $self->{dbh}->prepare($query);
	
	$sth->execute($args->{-email}, $args->{-list});
	
	
	my $results = []; 
	
 	while ( my $fields = $sth->fetchrow_hashref ) {
		push(@$results, $fields);
	}
	
	#my $r = $sth->fetchall_hashref('consent_activity_id');
	
	return $results; 
	
}

1;