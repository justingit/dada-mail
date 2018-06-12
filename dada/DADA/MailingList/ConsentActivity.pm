package DADA::MailingList::ConsentActivity;

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

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_ConsentActivity};

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
		$args->{-remote_addr} = anonymize_ip($args->{-remote_addr}); 
		
	}

	if(!exists($args->{-action},)){ 
		$args->{-action} = 'unknown';
	}
	if($self->allowed_action($args->{-action}) != 1){ 
		croak 'unknown action!: ' . $args->{-action};
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
	my @order = qw(
		remote_addr
		email  
		list       
		list_type 
		source
		source_location 
		action
		consent_session_token  
		privacy_policy_id
	);
			
	if(defined($args->{-consent_id})){
		push(@payload, $args->{-consent_id}); 
		push(@order, 'consent_id');
	}
	
	if(defined($args->{-timestamp})){
#		warn 'yes, timestamp: ' . $args->{-timestamp}; 
		push(@payload, $args->{-timestamp}); 
		push(@order, 'timestamp');
	}
	
	my $qm_str = '';
	my @qma = ();
	for(@order){
		push(@qma, '?'); 
	}
	
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{consent_activity_table}
      . '(' 
	  .	join(', ', @order) 
	  .') VALUES (' 
	  . join(',', @qma)
	  . ')';

#    carp 'QUERY: ' . $query;
#      if $t;

    my $sth = $self->{dbh}->prepare($query);
	
    $sth->execute(@payload)
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    	$sth->finish;

}

sub allowed_action { 
	my $self = shift;
	my $action = shift; 
	 
	my $actions = { 
		'unknown'         => 1, 
		'start consent'   => 1, 
		'cloic confirmed' => 1, 
		'consent granted' => 1,
		'subscription requested' => 1,
		'solved captcha' => 1,
		'cloic sent' => 1,
		'subscription' => 1,
		'consent revoked' => 1,
		'unsubscribe' => 1,
	};
	
	if(exists($actions->{$action})){ 
		return 1; 
	}
	else { 
		return 0; 
	}

}


sub remote_addr {
    if(exists($ENV{HTTP_X_FORWARDED_FOR})){ 
        # http://en.wikipedia.org/wiki/X-Forwarded-For
        my ($client, $proxies) = split(',', $ENV{HTTP_X_FORWARDED_FOR}, 2); 
        return anonymize_ip($client); 
    }
    else { 
        return anonymize_ip($ENV{'REMOTE_ADDR'}) || '127.0.0.1';
    }
}


sub subscriber_consented_to { 
	
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


sub list_activity { 
	my $self   = shift; 
	my ($args) = @_; 
	
	my $query = 'SELECT email, action, timestamp FROM ' 
	. $DADA::Config::SQL_PARAMS{consent_activity_table}
	. ' WHERE list = ? AND (action = \'subscription\' OR action = \'unsubscribe\')'
	. ' ORDER BY timestamp DESC LIMIT 100'; 
	
    my $sth = $self->{dbh}->prepare($query);
	
	$sth->execute($args->{-list});
	my $r = []; 
	
 	while ( my $f = $sth->fetchrow_hashref ) {
		push(
			
			@$r, { 
		        date           => $f->{timestamp},
		        list           => $args->{-list},
				#list_name      => 'Subscriber', 
		        ip             => $f->{timestamp},
		        email          => $f->{email},
		        type           => 'list',
		        type_title     => 'Subscribers',
		        action         => $f->{action},
				#updated_email  => $new_email, # used for subscription updates
			}
		)
	}
	
return $r; 
	
}



sub sub_unsub_trends { 
	my $self = shift;
	my ($args) = @_; 
	
	my $type = 'list'; 
	my $time = time; 
	my $r = []; 
	
	my @dates; 

	my $days = 180;
	if(exists($args->{-days})){ 
		$days = $args->{-days};
	}
	
	for(0 .. ($days)){ 
		my $s_date = simplified_date_str(past_date($time, $_));
		push(@dates, $s_date);
	}

	my $query = 'SELECT email, action, timestamp FROM ' 
	. $DADA::Config::SQL_PARAMS{consent_activity_table}
	. ' WHERE list = ? AND (action = \'subscription\' OR action = \'unsubscribe\')'; 
	
	if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
		$query .= ' AND DATE_SUB(CURDATE(),INTERVAL ' 
		   . $days  
		   . ' DAY) <= timestamp '
	}
	elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' ) {
		$query .= ' AND (NOW() - INTERVAL \'' 
			   . $days 
			   . '\' DAY) <= timestamp ';
	}
	 	
	$query .= ' ORDER BY timestamp DESC'; 
		
    my $sth = $self->{dbh}->prepare($query);
	
	$sth->execute($args->{-list});
	my $r = []; 
	
	my $count = 0; 
	my %trends = ();

	
	
 	while ( my $f = $sth->fetchrow_hashref ) {
		
		my ($date_string, $time_string) = split(" ", $f->{timestamp}, 2); 
		# Init if we need to. 
		if(!exists($trends{$date_string})){ 
			$trends{$date_string} = {subscription => 0, unsubscribe => 0};
		}
		$trends{$date_string}->{$f->{action}}++;
	}
	
	# Fill in missing dates. 
	for(@dates){ 		
		if(!exists($trends{$_})){ 
			$trends{$_} = {subscription => 0, unsubscribe => 0};
		}
	}

	my @r_trends = (); 
	my $cum_sub = 0; 
	my $cum_unsub = 0; 
	
	for my $d(reverse @dates){ 
		$cum_sub   += $trends{$d}->{subscription};
		$cum_unsub += $trends{$d}->{unsubscribe};
		push(@r_trends, { 
			date                    => $d, 
			subscribed              => $trends{$d}->{subscription},
			unsubscribed            => $trends{$d}->{unsubscribe},
			cumulative_subscribed   => $cum_sub,
			cumulative_unsubscribed => $cum_unsub,
		}); 
		
		
	}

	return [@r_trends];
}


sub simplified_date_str { 
	my $date = shift; 
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($date);
	$year += 1900; 
	$mon  += 1; 
	$mday = sprintf("%02d", $mday);
	$mon  = sprintf("%02d", $mon );
	return join('-', $year, $mon, $mday);
	
}

sub past_date {
    my $time = shift;
    my $days = shift || 0;
	return $time if $days == 0; 
    my $now  = defined $time ? $time : time;
    my $then = $now - 60 * 60 * 24 * ($days); # why, -1? 
    my $ndst = ( localtime $now )[8] > 0;
    my $tdst = ( localtime $then )[8] > 0;

    # Added '=' to avoid warning (and return)
    $then -= ( $tdst - $ndst ) * 60 * 60;
    return $then;
}


sub sub_unsub_trends_json { 
	my $self = shift; 
	my ($args) = @_; 
	if(! exists($args->{-days})){ 
		$args->{-days} = 30;
	}
	
	
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $args->{-list}, 
			-name    => 'sub_unsub_trends_json' . '.' . $args->{-days},
		}
	);
	
	if(!defined($json)){ 
	
		my $trends = $self->sub_unsub_trends($args);
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
			   { id => 'date',                    label => 'Date',                      type => 'string'}, 
			   { id => 'cumulative_subscribed',   label => 'Cumulative Subscriptions',  type => 'number',},
			   { id => 'cumulative_unsubscribed', label => 'Cumulative Unubscriptions', type => 'number',},
			   { id => 'subscribed',              label => 'Subscriptions',             type => 'number',},
			   { id => 'unsubscribed',            label => 'Unubscriptions',            type => 'number',},
		);

		for(@$trends){ 
			$datatable->add_rows(
		        [
		               { v => $_->{date}},
		               { v => $_->{cumulative_subscribed} },
		               { v => $_->{cumulative_unsubscribed} },
		               { v => $_->{subscribed} },
		               { v => $_->{unsubscribed} },
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $args->{-list}, 
				-name    => 'sub_unsub_trends_json' . '.' . $args->{-days},
				-data    => \$json, 
			}
		);
		
	}
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json; 
	}
}




sub consent_history_report { 

	my $self   = shift; 
	my ($args) = @_; 
	
	if(! exists($args->{-as_csv})){ 
		$args->{-as_csv} = 0; 
	}

	my $dada_consent_activity = $DADA::Config::SQL_PARAMS{consent_activity_table};
	my $dada_privacy_policies = $DADA::Config::SQL_PARAMS{privacy_policies_table};
	my $dada_consents         = $DADA::Config::SQL_PARAMS{consents_table};
	
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
		    $dada_consents.consent                     AS consent,
		    $dada_consent_activity.privacy_policy_id   AS privacy_policy_id,
		    $dada_privacy_policies.privacy_policy      AS privacy_policy
		 FROM $dada_consent_activity
		    LEFT JOIN $dada_privacy_policies ON $dada_consent_activity.privacy_policy_id = $dada_privacy_policies.privacy_policy_id
		    LEFT JOIN $dada_consents         ON $dada_consent_activity.consent_id        = $dada_consents.consent_id
		 WHERE $dada_consent_activity.email = ? AND $dada_consent_activity.list = ?
		 ORDER BY $dada_consent_activity.timestamp ASC
	};
	
	warn 'QUERY:' . $query
		if $t; 
	
    my $sth = $self->{dbh}->prepare($query);
	
	$sth->execute($args->{-email}, $args->{-list});
	
	my $results = []; 
	
 	while ( my $fields = $sth->fetchrow_hashref ) {
		push(@$results, $fields);
	}
	
	if($args->{-as_csv} == 1){ 
        
		my $status; 
		require Text::CSV;
        my $csv = Text::CSV->new(
			$DADA::Config::TEXT_CSV_PARAMS
		);

        my $csv_str = undef; 
		
        my @cols = qw(
			  
			  consent_activity_id
	          remote_addr
			  
			  timestamp
	          email
	          
			  list
	          action
			  
			  source
	          source_location

	          consent_id
	  		  consent

			  privacy_policy_id
	          privacy_policy
		 ); 

		$status   = $csv->combine(@cols);
        $csv_str .= $csv->string() . "\n";
		
		foreach my $fr(@$results) {
				my @lines = (); 
				foreach (@cols) {
					$fr->{$_} =~ s/\r|\n/ /gi; 
                	push(@lines, $fr->{$_});
            	}
			
            $status = $csv->combine(@lines);
            $csv_str .= $csv->string() . "\n";
        }
        return $csv_str;
	}
	else {
		return $results; 
	}
	
}

1;