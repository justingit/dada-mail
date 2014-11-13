package DADA::Logging::Clickthrough::baseSQL;

use lib qw(../../../ ../../../DADA/perllib);

use strict;

use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB);
use Carp qw(croak carp);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;    # For now, my dear.
use Try::Tiny; 

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Logging_Clickthrough};

sub new {

    my $class  = shift;
    my ($args) = @_;
    my $self   = {};
    bless $self, $class;
    $self->_init($args);
    $self->_sql_init($args);
    return $self;
}
sub enabled { 
	my $self = shift; 
	return 1; 
}


sub _sql_init {

    my $self = shift;
    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub custom_fields {
    my $self = shift;
    my $cols = $self->_columns;

    my %omit_fields = (
        url_id      => 1,
        redirect_id => 1,
        msg_id      => 1,
        url         => 1,
    );

    my $custom = [];
    for (@$cols) {
        if ( !exists( $omit_fields{$_} ) ) {
            push( @$custom, $_ );
        }
    }
    return $custom;
}

sub _columns {

    my $self = shift;
    my @cols;

    if ( exists( $self->{cache}->{columns} ) ) {
        return $self->{cache}->{columns};
    }
    else {
        my $query =
            "SELECT * FROM "
          . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
          . " WHERE (1 = 0)";
        warn 'Query: ' . $query
          if $t;

        my $sth = $self->{dbh}->prepare($query);

        $sth->execute()
          or croak "cannot do statement (at: columns)! $DBI::errstr\n";
        my $i;
        for ( $i = 1 ; $i <= $sth->{NUM_OF_FIELDS} ; $i++ ) {
            push( @cols, $sth->{NAME}->[ $i - 1 ] );
        }
        $sth->finish;
        $self->{cache}->{columns} = \@cols;
    }
    return \@cols;
}

sub add {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url    = shift;
    my $fields = shift;

    my $key = $self->random_key();

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $self->custom_fields };
    my @values;
    if ( $order[0] ) {
        for my $field (@order) {
            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            push( @values, $fields->{$field} );
        }
    }
    $sql_str =~ s/,$//;

    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . '(redirect_id, msg_id, url'
      . $sql_str
      . ') values(?,?,?'
      . $place_holder_string . ')';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $key, $mid, $url, @values )
      or croak "cannot do statement! (at: add) $DBI::errstr\n";
    return $key;

}

sub reuse_key {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url    = shift;
    my $fields = shift;

    my $custom_fields = $self->custom_fields;
    my %cust_fields   = ();
    foreach (@$custom_fields) {
        $cust_fields{$_} = 1;
    }
    my $place_holder_string = '';
    my @values              = ();

    foreach my $field ( keys %$fields ) {
        if ( exists( $cust_fields{$field} ) ) {
            push( @values, $fields->{$field} );
            $place_holder_string .= ' AND ' . $field . ' = ?';
        }
    }
    my $query =
        'SELECT * FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE msg_id = ? AND url = ? '
      . $place_holder_string;

    warn 'QUERY: ' . $query
 		if $t;
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $mid, $url, @values )
      or croak "cannot do statement! (at: reuse_key) $DBI::errstr\n";
    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        return $hashref->{redirect_id};
    }

    return undef;

}

sub fetch {

    my $self = shift;
    my $key  = shift;
    die "no key! " if !defined $key;

    my $sql_snippet = '';
    my $fields      = $self->custom_fields;
    foreach (@$fields) {
        $sql_snippet .= ', ' . $_;
    }

    my $query =
        'SELECT msg_id, url'
      . $sql_snippet
      . ' FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE  redirect_id = ?';
    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($key)
      or croak "cannot do statement! (at: fetch) $DBI::errstr\n";
    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        my $msg_id = $hashref->{msg_id};
        my $url    = $hashref->{url};
        delete( $hashref->{msg_id} );
        delete( $hashref->{url} );
        return ( $msg_id, $url, $hashref );
    }

    return ( undef, undef, {} );
}

sub key_exists {

    my $self = shift;
    my ($args) = @_;

    my $query =
        'SELECT COUNT(*) FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE redirect_id = ? ';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-key} )
      or croak "cannot do statement (at key_exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];

}

sub r_log {

    my $self      = shift;
    my ($args)    = @_;
    my $timestamp = undef;
    if ( exists( $args->{-timestamp} ) ) {
        $timestamp = $args->{-timestamp};
    }
    my $atts = {};
    if ( exists( $args->{-atts} ) ) {
        $atts = $args->{-atts};
    }

    my $remote_address = undef;
    if ( !exists( $args->{-remote_addr} ) ) {
        $remote_address = $self->remote_addr;
        $args->{-remote_addr} = $remote_address;
    }
    else {
        $remote_address = $args->{-remote_addr};
    }

    if ( !exists( $args->{-email} ) ) {
        $args->{-email} = '';
    }

    if(!exists($args->{-update_fields} )) { 
        $args->{-update_fields}; 
    }
    
    my $recorded_open_recently = 1;
    try {
        $recorded_open_recently = $self->_recorded_open_recently($args);
    }
    catch {
        carp "Couldn't execute, '_recorded_open_recently', : $_";
    };
    if ( $recorded_open_recently <= 0 ) {
        $self->open_log($args);
    }

    my $place_holder_string = '';
    my $sql_snippet         = '';

    my @values    = ();
    my $fields    = $self->custom_fields;
    my $lt_fields = {};
    foreach (@$fields) {
        $lt_fields->{$_} = 1;
    }

    foreach ( keys %$atts ) {
        if ( exists( $lt_fields->{$_} ) ) {
            push( @values, $atts->{$_} );
            $place_holder_string .= ' ,?';
            $sql_snippet .= ' ,' . $_;
        }
    }
    my $ts_snippet = '';
    if ( defined($timestamp) ) {
        $ts_snippet = 'timestamp,';
        $place_holder_string .= ' ,?';
    }
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}
      . '(list,'
      . $ts_snippet
      . 'remote_addr, msg_id, url, email'
      . $sql_snippet
      . ') VALUES (?, ?, ?, ?, ?'
      . $place_holder_string . ')';

    my $sth = $self->{dbh}->prepare($query);
    if ( defined($timestamp) ) {
        $sth->execute( $self->{name}, $timestamp, $remote_address,
            $args->{-mid}, $args->{-url}, $args->{-email}, @values );
    }
    else {
        $sth->execute(
            $self->{name}, $remote_address, $args->{-mid},
            $args->{-url}, $args->{-email}, @values
        );
    }
    $sth->finish;
    
    if($self->{ls}->param('tracker_track_email') == 1 
    && $self->{ls}->param('tracker_update_profiles_w_geo_ip_data') == 1
    && $args->{-email} ne '') { 
        try { 
            warn '$args->{-email}' . $args->{-email} 
                if $t; 
            warn '$remote_address'  . $remote_address 
                if $t; 
            $self->_update_profile_fields(
                {
                    -email      => $args->{-email},
                    -ip_address => $remote_address, 
                }
            ); 
        } catch { 
            carp "problems updating fields with geo ip data: $_"; 
        };
    }
    return 1;
}



sub _update_profile_fields {
    
    warn '_update_profile_fields' 
        if $t; 
        
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'need to pass an -email!';
        return undef;
    } 
    else { 
        if ( DADA::App::Guts::check_for_valid_email($args->{-email}) == 0 ) {
    
        }
        else { 
            warn 'invalid email: ' . $args->{-email}; 
            return undef; 
        }
    }
    if (! exists( $args->{-ip_address} ) ) {
        warn 'need to pass an -ip_address!';
        return undef;
    }

    my $geoip_db        = undef;
    my @loc_of_geoip_db = (
        '../../../../data/GeoLiteCity.dat', '../../../data/GeoLiteCity.dat',
        '../../data/GeoLiteCity.dat',       '../data/GeoLiteCity.dat',
        './data/GeoLiteCity.dat',
    );

    for (@loc_of_geoip_db) {
        if ( -e $_ ) {
            $geoip_db = $_;
            last;
        }
    }
    if ( !defined($geoip_db) ) {
        croak "Can not find GEO IP DN! at any of these locations: " . join( ', ', @loc_of_geoip_db );
    }
    else { 
        warn '$geoip_db at: ' . $geoip_db
            if $t;
    }

    my $thawed_gip = $self->{ls}->_dd_thaw( $self->{ls}->param('tracker_update_profile_fields_ip_dada_meta') );
    #warn '$thawed_gip:' . $thawed_gip; 
    
    require Geo::IP::PurePerl;
    my $gi = Geo::IP::PurePerl->new($geoip_db);
    my (
        $country_code, $country_code3, $country_name, $region,     $city,
        $postal_code,  $latitude,      $longitude,    $metro_code, $area_code
    ) = $gi->get_city_record( $args->{-ip_address} );

    my $named_vals = {
        ip_address    => $args->{-ip_address},
        country_code  => $country_code,
        country_code3 => $country_code3,
        country_name  => $country_name,
        region        => $region,
        city          => $city,
        postal_code   => $postal_code,
        latitude      => $latitude,
        longitude     => $longitude,
        metro_code    => $metro_code,
        area_code     => $area_code,
    };

    require DADA::ProfileFieldsManager;
    my $dpfm = DADA::ProfileFieldsManager->new;

    require DADA::Profile;
    my $prof = DADA::Profile->new( { -email => $args->{-email} } );
    if ($prof) {
        if ( !$prof->exists ) {
            warn 'no $prof.'
                if $t; 
            # create a new one.
            $prof->insert(
                {
                    -password  => $prof->_rand_str(8),
                    -activated => 1,
                }
            );
        }
        else { 
            warn '$prof exists.'
                if $t; 
        }
        # done with $prof.
        undef($prof);

        my $new_vals = {};
        my $old_vals = {};

        require DADA::Profile::Fields;
        my $dpf = DADA::Profile::Fields->new( { -email => $args->{-email} } );
        if ( $dpf->exists( { -email => $args->{-email} } ) ) {
            $old_vals = $dpf->get;
            delete( $old_vals->{email} );
            delete( $old_vals->{email_name} );
            delete( $old_vals->{email_domain} );
        }
        for my $uf ( @{ $dpfm->fields( { -show_hidden_fields => 1 } ) } ) {
            if ( $thawed_gip->{$uf}->{enabled} == 1 ) {
                $new_vals->{$uf} = $named_vals->{ $thawed_gip->{$uf}->{geoip_data_type} };
            }
            else {
                if(defined($old_vals->{$uf})) { 
                    $new_vals->{$uf} = $old_vals->{$uf};
                }
                else {
                    $new_vals->{$uf} = ''; 
                }
            }
        }
        if($t){ 
            require Data::Dumper; 
            warn 'inserting: ' . Data::Dumper::Dumper($new_vals); 
        }
        $dpf->insert( { -fields => $new_vals, } );
    }
    return 1;

}


sub logged_subscriber_count {
    my $self = shift;
    my ($args) = @_;
    my $query =
        'SELECT COUNT(*) from '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . ' WHERE list = ? AND msg_id = ? AND event = ?';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
       $sth->execute( $self->{name}, $args->{-mid}, 'num_subscribers')
      	or carp "cannot do statement! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

    $sth->finish;

    warn '$count is ' . $count
      if $t;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
}

sub open_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; # Well, yeah
    $args->{-event}          = 'open'; 
    $args->{-update_fields}  = 1; 
    return $self->mass_mailing_event_log($args); 
}
sub num_subscribers_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'num_subscribers'; 
    $args->{-details}        = $args->{-num};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub total_recipients_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'total_recipients'; 
    $args->{-details}        = $args->{-num};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub forward_to_a_friend_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'forward_to_a_friend'; 
    $args->{-update_fields}  = 0; # I guess we could...  
    return $self->mass_mailing_event_log($args); 
}
sub view_archive_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-update_fields}  = 0;
    $args->{-event}          = 'view_archive'; 
    return $self->mass_mailing_event_log($args); 
}
sub bounce_log {
    my $self                 = shift;
    my ($args)               = @_;
    my $bounce_type          = '';
    if ( $args->{-type} eq 'hard' ) {
        $bounce_type = 'hard_bounce';
    }
    else {
        $bounce_type = 'soft_bounce';
    }
    $args->{-record_as_open} = 0; 
    $args->{-event}          = $bounce_type; 
    $args->{-details}        = $args->{-email}; # I know, it's weird. 
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub error_sending_to_log {
    my $self                 = shift; 
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'errors_sending_to'; 
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub unsubscribe_log { 
	my $self                 = shift; 
    my ($args)               = @_;
    $args->{-record_as_open} = 1; 
    $args->{-event}          = 'unsubscribe'; 
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub abuse_log { 
	my $self                 = shift; 
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'abuse_report';
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}




sub mass_mailing_event_log {
    my $self      = shift;
    my ($args)    = @_;
    

    if ( $t == 1 ) {
        warn 'sent over Vars:';
        require Data::Dumper;
		warn '$args:' . Data::Dumper::Dumper($args);
	}
	
    # timestamp
    my $timestamp = undef;
    if ( exists( $args->{-timestamp} ) ) {
        $timestamp = $args->{-timestamp};
    }
    
    # remote address
    my $remote_address = undef;
    if ( !exists( $args->{-remote_addr} ) ) {
        $remote_address = $self->remote_addr;
    }
    else {
        $remote_address = $args->{-remote_addr};
    }
    
    # email
    if ( !exists( $args->{-email} ) ) {
        $args->{-email} = '';
    }
    
    #event
    if ( !exists( $args->{-event} ) ) {
        croak "You need to pass an, '-event'"; 
    }
    my $event = $args->{-event};
    
    # details
    if ( !exists( $args->{-details} ) ) {
        $args->{-details} = undef; 
    }
    my $details = $args->{-details};
    
    
    
    # Record this as an open? 
    if ( !exists( $args->{-record_as_open} ) ) {
        $args->{-record_as_open} = 0; 
    }
    if($args->{-record_as_open} == 1) {    
        my $recorded_open_recently = 1;
        try {
            $recorded_open_recently = $self->_recorded_open_recently($args);
        }
        catch {
            carp "Couldn't execute, '_recorded_open_recently', : $_";
        };
        if($t == 1){ 
            if(defined($args->{-mid})) { 
                warn 'mid is defined - we\'ll count this'; 
            }
            else { 
                warn 'mid is NOT defined - we\'re not counting this open'; 
            }
        }
        if ( $recorded_open_recently <= 0 && defined($args->{-mid})) {
            $self->open_log($args);
        }
    }
    
    my $ts_snippet          = '';
    my $place_holder_string = '';
    
    if ( defined($timestamp) ) {
        $ts_snippet = 'timestamp,';
        $place_holder_string .= ' ,?';
    }
    
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . '(list, '
      . $ts_snippet
      . 'remote_addr, msg_id, event, email, details) VALUES (?, ?, ?, ?, ?, ?'
      . $place_holder_string . ')';

	  warn '$query:' . $query
	    if $t;
	  
    my $sth = $self->{dbh}->prepare($query);
    
	my @execute_args = (); 
    if ( defined($timestamp) ) {
		warn 'timestamp!'
		    if $t; 
		@execute_args = ($self->{name}, $timestamp, $remote_address, $args->{-mid}, $event, $args->{-email}, $details);
        $sth->execute(@execute_args);
    }
    else {
		@execute_args = ($self->{name},             $remote_address, $args->{-mid}, $event, $args->{-email}, $details);
		
        $sth->execute(@execute_args);
    	warn 'no timestamp' 
    	    if $t; 
	}
    if ( $t == 1 ) {
        require Data::Dumper;
		warn 'excute_args:' . Data::Dumper::Dumper([@execute_args]);
	}
	
	
	
	$sth->finish;
    return 1;
}




sub _recorded_open_recently {
    my $self = shift;
    my ($args) = @_;

    my $query;

	if ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){ 
		    if ( $args->{-timestamp} ) {
		        $query =
		            'SELECT COUNT(*) from '
		          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
		          . ' where list = ? msg_id = ? AND event = ? AND timestamp >= DATE_SUB('
		          . $args->{timestamp}
		          . ', INTERVAL 1 HOUR)';
		    }
		    else {
		        $query =
		            'SELECT COUNT(*) from '
		          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
		          . ' where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)';
		    }
	}
	elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){
		
		if ( $args->{-timestamp} ) {
	        $query =
	            'SELECT COUNT(*) from '
	          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
	          . " where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= ' . $args->{timestamp} . ' - INTERVAL '1 HOUR'"; 
	    }
	    else {
	        $query =
	            'SELECT COUNT(*) from '
	          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
	          . " where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= NOW() - INTERVAL '1 HOUR'";
	    }
		
	}
	else { 
		 # I'm not sure if I want to tackle SQLite, atm... 
		return 1; 
	}
	

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{name}, $args->{-remote_addr}, $args->{-mid}, 'open' )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];
}




sub unique_and_dupe {
    my $self  = shift;
    my $array = shift;

    my @unique = ();
    my %seen   = ();

    foreach my $elem (@$array) {
        next if $seen{$elem}++;
        push @unique, $elem;
    }
    return [@unique];

}


sub get_all_mids {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-page} ) ) {
        $args->{-page} = 1;
    }
    if ( !exists( $args->{-entries} ) ) {
        $args->{-entries} = 10;
    }

# postgres: $query .= ' SELECT DISTINCT ON(' . $subscriber_table . '.email) ';
# This query could probably be made into one, if I could simple use a join, or something
# DEV: There's also this idea:
# SELECT * FROM table ORDER BY rec_date LIMIT ?, ?} #
#     q{SELECT * FROM table ORDER BY rec_date LIMIT ?, ?}

    my $query = '';
    if ( $self->{ls}->param('tracker_clean_up_reports') == 1 ) {

        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? AND event = \'num_subscribers\' GROUP BY msg_id ORDER BY msg_id DESC;';
    }
    else {

        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? GROUP BY msg_id ORDER BY msg_id DESC;';
    }

    my $msg_id1 =
      $self->{dbh}->selectcol_arrayref( $query, {}, ( $self->{name} ) );

    warn 'Query: ' . $query
      if $t;

    my $total = 0;
    $total = scalar @$msg_id1;
    if ( $total == 0 ) {
        return ( $total, [] );
    }


	# DEV: LIMIT, OFFSET - HELLO?!
    my $begin = ( $args->{-entries} - 1 ) * ( $args->{-page} - 1 );
    my $end = $begin + ( $args->{-entries} - 1 );

    if ( $end > $total - 1 ) {
        $end = $total - 1;
    }

    @$msg_id1 = @$msg_id1[ $begin .. $end ];

    return ( $total, $msg_id1 );

}




sub report_by_message_index {


    my $self          = shift;
	my ($args)        = @_; 

	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	my $sorted_report = [];
	    my $report        = {};
	    my $l;
	
	
		my $total   = undef; 
		my $msg_id1 = []; 
	
		if(exists($args->{-all_mids})){ 
			$msg_id1 = $args->{-all_mids};
		}
		else { 
			# Not using total, right now... 
			($total, $msg_id1) = $self->get_all_mids(); # no vars? 
		}
		if(!exists($args->{-page})){ 
			$args->{-page} = 1; 
		}
		
	    for my $msg_id (@$msg_id1) {
		
			next 
				unless defined $msg_id;
		
	        $report->{$msg_id}->{msg_id} = $msg_id;

	        # Clickthroughs
	        my $clickthrough_count_query =
	'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .' WHERE list = ?  AND msg_id = ?';
	        $report->{$msg_id}->{count} =
	          $self->{dbh}
	          ->selectcol_arrayref( $clickthrough_count_query, {}, $self->{name}, $msg_id )->[0];

		
		my $basic_event_counts = $self->msg_basic_event_count($msg_id); 
		for(keys %$basic_event_counts) { 
			$report->{$msg_id}->{$_} = $basic_event_counts->{$_};
		}
		
	    }

	    require DADA::MailingList::Archives;
	    my $mja = DADA::MailingList::Archives->new( { -list => $self->{name} } );

	    # Now, sorted:
	    for ( sort { $b <=> $a } keys %$report ) {
	        $report->{$_}->{mid}           = $_;    # this again.
	        $report->{$_}->{date}          = DADA::App::Guts::date_this( -Packed_Date => $_, );
			$report->{$_}->{S_PROGRAM_URL} = $DADA::Config::S_PROGRAM_URL; 
			$report->{$_}->{list}          = $self->{name}; 
	        if ( $mja->check_if_entry_exists($_) ) {
	            $report->{$_}->{message_subject} = $mja->get_archive_subject($_)
	              || $_;
	        }
	        else {
	        }

	        push( @$sorted_report, $report->{$_} );
	    }
	
		# The idea is if we've already calculated all this, no 
		# reason to do it twice, if the table and graph are shown together. 
		if(! $dc->cached(
			{
			-list    => $self->{name}, 
			-name    => 'message_history_json', 
			-page    => $args->{-page}, 
			-entries => $self->{ls}->param('tracker_record_view_count')
			}
		)){
			# warn 'creating message_history_json JSON ffrom report_by_message_index'; 
			$self->message_history_json(
				{
					-report_by_message_index_data => $sorted_report,
					-page                         => $args->{-page}, 
					-printout                     => 0,	
				}
			);
		}
	
    return $sorted_report;
}

sub msg_basic_event_count { 
	
	my $self    = shift; 
	my $msg_id = shift; 
	my $basic_events = {};
    my %ok_events = (
        open                => 1,
        soft_bounce         => 1,
        hard_bounce         => 1,
        forward_to_a_friend => 1,
        view_archive        => 1,
		unsubscribe         => 1,
		errors_sending_to   => 1,
		abuse_report        => 1,
    );
    
    for(keys %ok_events){ 
        if(!exists($basic_events->{$_})){ 
            $basic_events->{$_} = 0; 
        }
        
    }
    
	my $basic_count_query = 'SELECT msg_id, event, COUNT(*) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? GROUP BY msg_id, event';
	my $sth              = $self->{dbh}->prepare($basic_count_query);
       $sth->execute( $self->{name}, $msg_id);
    while ( my ( $m, $e, $c ) = $sth->fetchrow_array ) {
		if($ok_events{$e}){ 
			$basic_events->{$e} = $c; 
		}
	}
	$sth->finish; 
	undef $sth; 
	
	# num subscribers
 	my $num_sub_query = 'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';
	$basic_events->{num_subscribers} = $self->{dbh}->selectcol_arrayref( $num_sub_query, { MaxRows => 1 }, $self->{name}, $msg_id, 'num_subscribers' )->[0];

	# total recipients
	my $total_recipients_query = 'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';
	$basic_events->{total_recipients} = $self->{dbh}->selectcol_arrayref( $total_recipients_query, { MaxRows => 1 }, $self->{name}, $msg_id, 'total_recipients' )->[0];

	# num subscribers
	if(! defined($basic_events->{total_recipients}) || $basic_events->{total_recipients} eq ''){ 
		$basic_events->{total_recipients} = $basic_events->{num_subscribers};
	}
	
	# Received: 
	# total_recipients - soft_bounce - hard_bounce - errors_sending_to
	$basic_events->{received} = 
	  $basic_events->{total_recipients}
	- $basic_events->{soft_bounce}
	- $basic_events->{hard_bounce}
    - $basic_events->{errors_sending_to};

	# Delivered to (sent successfully, could bounce back) 
	# total_recipients - errors_sending_to
	$basic_events->{delivered_to} = 
	  $basic_events->{total_recipients}
    - $basic_events->{errors_sending_to};	
	
	# Unique Opens
	my $uo_query = 'SELECT msg_id, event, email, COUNT(*) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? and event = \'open\' GROUP BY msg_id, event, email'; 
	my $uo_count  = 0; 
	my $sth      = $self->{dbh}->prepare($uo_query);
       $sth->execute( $self->{name}, $msg_id);
	# Just counting what gets returned. 
	while ( my ( $m, $e, $c ) = $sth->fetchrow_array ) {
		$uo_count++; 
	}
	$basic_events->{unique_open} = $uo_count; 
	$sth->finish; 
	# /Unique Opens
	$basic_events->{unique_opens_percent}          
		= $self->percentage(
			$basic_events->{unique_open}, 
			$basic_events->{received}
	);
	
	# Unsubscribes 
	$basic_events->{unique_unsubscribes_percent} = 
		$self->percentage(
			$basic_events->{unsubscribe}, 
			$basic_events->{delivered_to}
		); 
	
    # ...Bounces
	$basic_events->{unique_soft_bounces_percent} = 
		$self->percentage(
			$basic_events->{soft_bounce}, 
			$basic_events->{delivered_to}
		); 

	$basic_events->{unique_hard_bounces_percent} = 
		$self->percentage(
			$basic_events->{hard_bounce}, 
			$basic_events->{delivered_to}
		); 
	
	$basic_events->{unique_bounces_percent} = 
		$basic_events->{unique_soft_bounces_percent} 
	  + $basic_events->{unique_hard_bounces_percent};
	
	# Received Percent
	$basic_events->{received_percent} = 
		$self->percentage(
			$basic_events->{received}, 
			$basic_events->{total_recipients}
	); 
	
	# Errors Sending To
	$basic_events->{errors_sending_to_percent} = 
		$self->percentage(
			$basic_events->{errors_sending_to}, 
			$basic_events->{total_recipients}
	); 

#	# 
#	$basic_events->{abuse_report_percent} = 
#		$self->percentage(
#			$basic_events->{abuse_report}, 
#			$basic_events->{total_recipients}
#	); 

	return $basic_events;

}




sub msg_basic_event_count_json { 
	
    my $self          = shift;
	my ($args)        = @_;
	
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0;
	}
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'msg_basic_event_count_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	

	if(! defined($json)){ 

		my $report = $self->msg_basic_event_count($args->{-mid});	

		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
		       { id => 'category',   label => "Category",      type => 'string',},
		       { id => 'number',     label => "Number",        type => 'number',},
		);


		if($args->{-type} eq 'opens') { 
			$datatable->add_rows(
		        [
		               { v => 'Unique Opens' },
		               { v => $report->{unique_opens_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Unopened' },
		               { v => (100 - $report->{unique_opens_percent}) },
		       ],
			);
			
			
		}
		elsif($args->{-type} eq 'unsubscribes') { 
			$datatable->add_rows(
		        [
		               { v => 'Unsubscribes' },
		               { v => $report->{unique_unsubscribes_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Still Subscribed' },
		               { v => (100 - $report->{unique_unsubscribes_percent}) },
		       ],
			);
			
			
		}
		elsif($args->{-type} eq 'bounces') {
			$datatable->add_rows(
		        [
		               { v => 'Soft Bounces' },
		               { v => $report->{unique_soft_bounces_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Hard Bounces' },
		               { v => $report->{unique_hard_bounces_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Received' },
		               { v => $report->{received_percent} },
		       ],
			);		
			$datatable->add_rows(
		        [
		               { v => 'Sending Errors' },
		               { v => $report->{errors_sending_to_percent} },
		       ],
			);		


		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'msg_basic_event_count_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
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

sub percentage { 
	my $self = shift; 
	my $num  = shift; 
	my $total = shift; 
	my $p     = 0; 

	$num = $num + 0; 
	$total = $total + 0; 
	
	return 0 unless $total > 0; 
	try { 
		$p =  $num/$total * 100; 
	} catch { 
		carp "problems finding percentage: $_"; 
	};

	return sprintf ("%.1f", $p); 
	
	#return $p; 
}

sub report_by_message {

    my $self   = shift;
    my $mid    = shift;

	my $m_report = {};
    my $report   = {};
    my $l;
		
	my $basic_event_counts = $self->msg_basic_event_count($mid); 
	for(keys %$basic_event_counts) { 
		$report->{$_} = $basic_event_counts->{$_};
	}

    my $url_clickthroughs_query =
        'SELECT url, COUNT(url) AS count FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}
      . ' where list = ? AND msg_id = ? GROUP BY url';
    my $sth = $self->{dbh}->prepare($url_clickthroughs_query);
    $sth->execute( $self->{name}, $mid );
    my $url_report = [];
    my $row        = undef;
    $report->{clickthroughs} = 0;
    while ( $row = $sth->fetchrow_hashref ) {
        push( @$url_report, { url => $row->{url}, count => $row->{count} } );
        $report->{clickthroughs} = $report->{clickthroughs} + $row->{count};
    }
    $sth->finish;
    undef $sth;
    $report->{url_report} = $url_report;

	$m_report = $report; 
    return $m_report;
}

sub export_logs {

    my $self   = shift;
	my ($args) = @_; 

	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthrough';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	
    my $query = '';
    if ( $args->{-type} eq 'clickthrough' ) {

		my $custom_fields = $self->custom_fields; 
		my $sql_snippet = ''; 
		if(exists($custom_fields->[0])){ 
			$sql_snippet = join(', ', @$custom_fields);
			$sql_snippet = ', ' . $sql_snippet; 
		}
		
		my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id url, email), @$custom_fields]);
		print $fh "\n";
		
        $query = 'SELECT timestamp, remote_addr, msg_id, url, email'. $sql_snippet .' FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
    }
    elsif ( $args->{-type} eq 'activity' ) {
	
		my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id activity details email)]);
		print $fh "\n";
		
		# timestamp list message_id activity details
        $query = 'SELECT timestamp, remote_addr, msg_id, event, details, email FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?';
    }
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id = ?'; 
	}
	
    my $sth = $self->{dbh}->prepare($query);
	
	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
    }
	else { 
		$sth->execute($self->{name});
	}

 	while ( my $fields = $sth->fetchrow_arrayref ) {
        my $status = $csv->print( $fh, $fields );
        print $fh "\n";
    }
}

sub export_by_email { 
	
	my $self   = shift; 
	my ($args) = @_;
	
	require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}
	
	my $query; 
	
	if ( $args->{-type} eq 'clickthroughs' ) {
	    $query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
	}
	elsif ( $args->{-type} eq 'opens' ) { 
		$query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . " WHERE list = ? AND event = 'open'";
	}
	elsif ( $args->{-type} eq 'abuse_reports' ) {
		$query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . " WHERE list = ? AND event = 'abuse_report'";	
	}
	
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id = ?'; 
	}		
	$query .= ' ORDER BY email ASC';
			
	my $sth = $self->{dbh}->prepare($query);
    
	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
    }
	else { 
		$sth->execute($self->{name});
	}
	
#	print $fh $query . "\n";
#	print $fh . '$self->{name} ' . $self->{name} . "\n"; 
#	print $fh . '$args->{-mid} ' . $args->{-mid} . "\n"; 
	
	warn $query
	 if $t; 
	
	while ( my $fields = $sth->fetchrow_arrayref ) {
        my $status = $csv->print( $fh, $fields );
        print $fh "\n";
    }
	
}





sub can_use_country_geoip_data { 
	return 1; 
}




sub ip_data { 
	
	# Todo: add email stuff to that. 
	# Remember bounces and everything else use a different column for email address!
	my $self   = shift; 
	my ($args) = @_; 

#	if(!exists($args->{-count})){ 
#		$args->{-count} = 20; 
#	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}

#	select remote_addr from dada_clickthrough_url_log where msg_id = '20110502135133'; 
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT timestamp, remote_addr, url FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
	}
	elsif($args->{-type} eq 'opens'){ 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ?'; 	
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'ALL') {
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE (event = \'open\' OR event = \'forward_to_a_friend\' OR event = \'view_archive\') AND list = ?'; 				
	} 

	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id=?'; 
	}
	my $sth = $self->{dbh}->prepare($query);

	#	die $query; 

	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
	}
	else { 
		$sth->execute($self->{name});
	}
	my $ips = []; 

	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		if($args->{-type} eq 'clickthroughs'){ 
			push(@$ips, {
				timestamp => $row->{timestamp}, 
				ip        => $row->{remote_addr}, 
				event     => 'clickthrough', 
				url       => $row->{url}, 
				
			});
		}
		else { 
			push(@$ips, {
				timestamp => $row->{timestamp}, 
				ip        => $row->{remote_addr}, 
				event     => $row->{event}, 
			});
		}
	}	
	$sth->finish; 

	if($args->{-type} eq 'ALL') {
		my $ct_ips = $self->ip_data(
			{ 
				-type => 'clickthroughs', 
				-mid  => $args->{-mid}, 
			}
		); 
		foreach(@$ct_ips){ 
			push(@$ips, $_);
		}
	}
	return $ips; 
	
}
sub country_geoip_data { 
	
	my $self   = shift; 
	my ($args) = @_; 	
	
#	if(!exists($args->{-count})){ 
#		$args->{-count} = 20; 
#	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}

	my $ip_data = $self->ip_data($args); 
	my $loc = {}; 
	
	require  Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->new($args->{-db});
	my $addr_name   = {};
	my $per_country = {}; 
	foreach(@$ip_data){ 
		my $country = $gi->country_code_by_addr($_->{'ip'});
		
		# Cache the Country name by IP...
	    $addr_name->{$country} = $gi->country_name_by_addr($_->{'ip'});
		
		if(defined($country)){ 
			if(!exists($per_country->{$country})){ 
				$per_country->{$country} = 0; 
			}
			$per_country->{$country}++;
		}
		else { 
			if(!exists($per_country->{'unknown'})){ 
				$per_country->{unknown} = 0;
			}
			$per_country->{'unknown'}++;
		}
	}
	my @r = ();
	foreach(keys %$per_country){ 
		if($_ eq 'unknown'){ 
			push(@r, {
				code => $_, 
				name => 'Unknown',
				count => $per_country->{$_}, 
			});
		}
		else { 
			
			push(@r, {
				code => $_, 
				name => $addr_name->{$_},
				count => $per_country->{$_}, 
			}); 
		}
	}	
	my @sorted = map  { $_->[0] }
	          sort { $b->[1] <=> $a->[1] }
	          map  { [$_, $_->{count}] }
	               @r;

	return \@sorted;
	
	
}

sub country_geoip_json { 
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0;
	}
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'country_geoip_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	
	if(! defined($json)){ 
	
		my $report = $self->country_geoip_data($args);	
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
		       { id => 'location',  label => "Location",       type => 'string',},
		       { id => 'color',     label => $args->{-label},  type => 'number',},
	#	       { id => 'type',      label => 'Type',           type => 'string',},
		);

		for(@$report){ 
			$datatable->add_rows(
		        [
		               { v => $_->{code}, f => $_->{name}},
		               { v => $_->{count} },
	#	               { v => $args->{-type} },
	
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'country_geoip_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
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

sub individual_country_geoip { 
	 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}
	if(!exists($args->{-country})){ 
		$args->{-country} = 'US'; 
	}
	
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}
	
	my $report = $self->ip_data($args);
	require Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->open($args->{-db});
	my $d           = {};
	my $cities      = {} ;
	my $ips_by_city = {};
	my $ip_data     = $self->ip_data($args); 
	for my $i_data(@$ip_data){ 
		my ($country_code,$country_code3,$country_name,$region,
		    $city,$postal_code,$latitude,$longitude,
		    $metro_code,$area_code ) = $gi->get_city_record($i_data->{'ip'});
		
		if($country_code eq $args->{-country}){ 
			
			
			if(! $city){
				$city = 'Other'; 
			}
			if($country_code eq 'US'){ 
				$city = $city . ', ' . $region;
			}
			if(!$metro_code){ 
				$metro_code = 'Unknown'; 
			}
				
			if(!exists($d->{"$city\:$metro_code"})){
				$d->{"$city\:$metro_code"} = 0; 
				$cities->{"$city\:$metro_code"} = { 
					lat   => $latitude, 
					long  => $longitude, 
				};
				$ips_by_city->{$city} = [];
			} 
			$d->{"$city\:$metro_code"}++; 
			push(@{$ips_by_city->{$city}}, $i_data);  
		}
	}
	my @r; 
	for(keys %$d){ 
		my ($city, $metro_code) = split(':', $_); 
		push(@r, 
			{ 
			lat        => $cities->{$_}->{lat}, 
			long       => $cities->{$_}->{long}, 
			city       => $city, 
			count      => $d->{$_}, 
			ip_data    => $ips_by_city->{$city},
		});
	} 
	# sort by city
	my @sorted = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->{city} ] } @r;
	return [@sorted]; 
}

sub individual_country_geoip_json {
	
	my $self   = shift; 
	my ($args) = @_; 
	
	
	my $json;
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	my $report = $self->individual_country_geoip($args);


	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'individual_country_geoip' . '.' . $args->{-mid} . '.' . $args->{-type} . '.' . $args->{-country}, 
		}
	);
	
	if(! defined($json)){
		
		my $report = $self->individual_country_geoip($args);
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();


		$datatable->add_columns(
		       { id => 'latitude',     label => "Latitude",        type => 'number',},
		       { id => 'longitude',    label => "Longitude",       type => 'number',},
		       { id => 'DESCRIPTION',  label => "Description",     type => 'string',},
		       { id => 'marker_color', label => "Clickthroughs",   type => 'number',},
		);
	
	
		for my $r(@$report) { 
			$datatable->add_rows(
		        [   
		               { v => $r->{lat},   },
		               { v => $r->{long},  },
					   { v => $r->{city},  },
					   { v => $r->{count},},
		       ],
			);
		}
	
		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'individual_country_geoip' . '.' . $args->{-mid} . '.' . $args->{-type} . '.' . $args->{-country}, 
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
sub individual_country_geoip_report { 
	my $self   = shift; 
	my ($args) = @_;  

	my %labels = (
		open                => 'Open', 
		clickthrough        => 'Clickthrough', 
		view_archive 	    => 'Archive View',
		forward_to_a_friend => 'Forward',  
	    abuse_report        => 'Abuse Report', 
	); 
	
	my $report = $self->individual_country_geoip($args);



	# This needs to be munged - count each specific IPS: 
	for my $loc(@$report) { 
		my $unique_ips = {};
		my $ip_history = {};
		for my $ipdata(@{$loc->{ip_data}}){ 
			if(!exists($unique_ips->{$ipdata->{ip}})){ 
				$unique_ips->{$ipdata->{ip}} = 0;
				$ip_history->{$ipdata->{ip}} = [];
			}
			$unique_ips->{$ipdata->{ip}}++;
			my $time = $self->timestamp_to_time($ipdata->{timestamp});

			push(@{$ip_history->{$ipdata->{ip}}}, { 
				timestamp   => $ipdata->{timestamp},
				time        => $time, 
				ctime       => scalar(localtime($time)), 
                url         => $ipdata->{url},
                event       => $ipdata->{event},
				event_label => $labels{$ipdata->{event}},
			}); 
		}
		$loc->{unique_ips} = [];
		
		# Sort ip events by date
		my $sorted_ip_history = {};
		for my $unsorted_ips(keys %$ip_history){ 
			$sorted_ip_history->{$unsorted_ips} = [];
			
			
			my $u_ip_data = $ip_history->{$unsorted_ips};
			
			my @sorted_ips = map { $_->[0] }
	          sort { $a->[1] <=> $b->[1] }
	          map { [ $_, $_->{'time'} ] } @$u_ip_data;
	
			 $sorted_ip_history->{$unsorted_ips} = [@sorted_ips]; 
		}
		undef($ip_history); # garbage collect? 
		#/ Sort ip events by date
		
		
		for my $u_ips(keys %$unique_ips){ 
			push(@{$loc->{unique_ips}}, {
				ip         => $u_ips, 
				count      => $unique_ips->{$u_ips}, 
				ip_history => $sorted_ip_history->{$u_ips},
			}); 
		}
		$loc->{unique_ip_count} = scalar(@{$loc->{unique_ips}}); 
		delete($loc->{ip_data});
	} 
	return $report;
	
	
}
sub timestamp_to_time {
	my $self = shift;  	
	my $timestamp = shift;
	
	require Time::Local; 
	 
	my ($date, $time) = split(' ', $timestamp); 
	my ($year, $month, $day) = split('-', $date); 
	my ($hour, $minute, $second) = split(':', $time); 
	$second = int($second - 0.5) ; # no idea. 
	return Time::Local::timelocal( $second, $minute, $hour, $day, $month-1, $year );
}

sub individual_country_geoip_report_table { 
	my $self   = shift; 
	my ($args) = @_;
	my $html; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'individual_country_geoip_report_table' . '.' . $args->{-mid} . '.' . $args->{-country}. '.' . $args->{-type} . '.' . $args->{-chrome},
		}
	);
	if(!defined($html)){ 
	
	
		my $report = $self->individual_country_geoip_report($args);
	
		require DADA::Template::Widgets; 
		$html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/individual_country_geoip_report_table.tmpl',
	            -vars => {
					report => $report, 
					num_bounces   => scalar(@$report), 
					title         => $args->{-type},  
					country       => $args->{-country}, 
					chrome        => $args->{-chrome}, 
					mid           => $args->{-mid}, 
					Plugin_URL    => $args->{Plugin_URL}, 
	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'individual_country_geoip_report_table' . '.' . $args->{-mid} . '.' . $args->{-country}. '.' . $args->{-type} . '.' . $args->{-chrome},
				-data    => \$html, 
			}
		);
	}
	
	
	use CGI qw(:standard); 
	print header(); 
	print $html; 
    
}


sub data_over_time {
	 
	my $self   = shift; 
	my ($args) = @_; 
	my $mid    = undef; 
	my $data   = {};
	my $order  = [];
	my $r      = [];
	
	if(exists($args->{-mid})){ 
		$mid = $args->{-mid};
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs';
	}
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? '; 
	}
	elsif($args->{-type} eq 'opens') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ? ';
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ? ';
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ? ';
	}
	elsif($args->{-type} eq 'unsubscribes') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'unsubscribe\' AND list = ? ';
	}
	elsif($args->{-type} eq 'abuse_report') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'abuse_report\' AND list = ? ';
	}
	 
	if($mid){ 
		$query .= ' AND msg_id = ?'; 
	}
	$query .= ' ORDER BY timestamp'; 
	
	
    my $sth = $self->{dbh}->prepare($query);
	if($mid){ 		
	    $sth->execute($self->{name}, $mid)
	      or croak "cannot do statement! $DBI::errstr\n";
	}
	else { 
	    $sth->execute($self->{name})
	      or croak "cannot do statement! $DBI::errstr\n";
	}
	
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		my $date = $row->{timestamp}; 
		my ($mdy, $rest) = split(' ', $date, 2);
		if(!exists($data->{$mdy})){ 
			$data->{$mdy} = 0; 
			push(@$order, $mdy)
		}
		$data->{$mdy}++; 
      }

	foreach(@$order){ 
		push(@$r, {mdy => $_, count => $data->{$_}});
	}

	return $r; 
	
}

sub data_over_time_json { 
	my $self   = shift; 
	my ($args) = @_;
	
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'data_over_time_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	
	if(! defined($json)){ 
		
		my $report = $self->data_over_time($args);
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
			   { id => 'date',          label => 'Date',           type => 'string'}, 
			   { id => 'number',         label => $args->{-label},  type => 'number',},
		);

		for(@$report){ 
			$datatable->add_rows(
		        [
		               { v => $_->{mdy}  },
		               { v => $_->{count} },
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'data_over_time_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
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



sub message_email_report {

    my $self = shift;
    my ($args) = @_;

    # warn '$args->{-type} ' . $args->{-type};
    if ( !exists( $args->{-mid} ) ) {
        croak "You MUST pass the, '-mid' parameter!";
    }
    my $mid  = $args->{-mid};
    my $type = undef;

    if ( exists( $args->{-type} ) ) {
        $type = $args->{-type};
    }
    else {
        croak 'you MUST pass -type!';
    }

	my $email_col = undef; 
	
	# Guh.
	if($type =~ m/bounce/) { 
		$email_col = 'details'; 
	}
	else { 
		$email_col = 'email'; 	    
	}
	
    my $query =
        'SELECT timestamp, ' . $email_col . ' from '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . ' WHERE list = ? AND msg_id = ? AND event  = ? ORDER BY ' . $email_col;

	warn 'Query: ' . $query
		if $t; 

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{name}, $mid, $type );

    my @report = ();
    while ( my $row = $sth->fetchrow_hashref ) {
        my ( $name, $domain ) = split( '@', $row->{$email_col} );
        push(
            @report,
            {
                timestamp    => $row->{timestamp},
                email        => $row->{$email_col},
                email_name   => $name,
                email_domain => $domain,
            }
        );
    }

    # sort by domain...
    my @sorted = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->{email_domain} ] } @report;
    $sth->finish;

	# use Data::Dumper; 
	# warn Dumper(\@sorted); 
	
    return [@sorted];

}
sub message_email_report_table { 
	my $self   = shift; 
	my ($args) = @_; 
	my $html; 
	
	if(! exists($args->{-type})){ 
		croak 'you MUST pass -type!'; 
	}
	
	if(! exists($args->{-vars})){ 
		$args->{-vars} = {}; 
	}
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_email_report_table' . '.' . $args->{-mid} . '.' . $args->{-type} , 
		}
	);
	if(! defined($html)){ 
	
		my $title; 
		if($args->{-type} eq 'soft_bounce'){ 
			$title = 'Soft Bounces'; 
		}
		elsif($args->{-type} eq 'hard_bounce'){ 
			$title = 'Hard Bounces'; 
		}
		elsif($args->{-type} eq 'unsubscribe'){ 
			$title = 'Unsubscribes'; 
		}
		my $report = $self->message_email_report($args);
		
#		use Data::Dumper; 
#		warn Dumper($report); 
		
		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_email_report_table.tmpl',
				-expr => 1, 
	            -vars => {
					type          => $args->{-type},
					report        => $report, 
					num           => scalar(@$report), 
					title         => $title,  
					%{$args->{-vars}}, 
	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_email_report_table' . '.' . $args->{-mid} . '.' . $args->{-type} , 
				-data    => \$html, 
			}
		);
	}
	use CGI qw(:standard); 
	print header(); 
	e_print($html); 
}



sub message_email_report_export_csv {
	
	my $self   = shift; 
	my ($args) = @_; 
	
	if(! exists($args->{-type})){ 
		croak 'you MUST pass -type!'; 
	}
	
	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh};
	
	require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	my $report = []; 
	
	if($args->{-type} eq 'email_activity') { 
		$report = $self->message_email_activity_listing($args);
	
	}
	else { 
		$report = $self->message_email_report($args);
	}
	
	my $title_status = $csv->print($fh, ['email type: ' . $args->{-type}]);
	print $fh "\n";
	
	for my $i_report(@$report){ 
		my $email = $i_report->{email};
		my $status = $csv->print( $fh, [$email] );
        print $fh "\n";
	}
}


sub email_stats { 
	
	my $self = shift; 
	my ($args) = @_; 
	my $mid = $args->{-mid};
	my $count; 
	if(!exists($args->{-count})){ 
		$count = 15; 
	}
	else { 
		$count = $args->{-count};
	}
	
	my $type = undef; 
	if(exists($args->{-type})){ 
		$type = $args->{-type};
	}
	else { 
		croak 'you MUST pass -type!'; 
	}
	
	my $report = $self->message_email_report($args);
	
	
	my $data = {};

	for my $report(@$report ){ 

		my $email = $report->{email};

		my ($name, $domain) = split('@', $email); 
		if(!exists($data->{$domain})){ 
			$data->{$domain} = 0;
		}
		$data->{$domain} = $data->{$domain} + 1; 	
	}
	# Sorted Index
	my @index = sort { $data->{$b} <=> $data->{$a} } keys %$data; 

	# Top n
	my @top = splice(@index,0,($count-1));

	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $data->{$_};
	}
	my $final = [];
	foreach(@top){ 
		push(@$final, {domain => $_, number => $data->{$_}});
		
		#$final->{$_} = $data->{$_};
	}
	if($other > 0){ 
	#	$final->{other} = $other;
		push(@$final, {domain => 'other', number => $other}); 
	
	}		
	
	return $final; 

}

sub email_stats_json { 
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-count})){ 
		$args->{-count} = 15; 
	}

	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'email_stats_json' . '.' . $args->{-mid} . '.' . $args->{-count} . '.' . $args->{-type} , 
		}
	);
	
	if(!defined($json)){ 
		my $stats = $self->email_stats($args);
	 

		require         Data::Google::Visualization::DataTable;
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
		       { id => 'domain',     label => "Domain",        type => 'string',},
		       { id => 'number',     label => "Number",        type => 'number',},
		);

		for(@$stats){ 
			$datatable->add_rows(
		        [
		               { v => $_->{domain} },
		               { v => $_->{number} },
		       ],
			);
		}

		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'email_stats_json' . '.' . $args->{-mid} . '.' . $args->{-count} . '.' . $args->{-type} , 
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

sub message_email_activity_listing {
	 
	my $self   = shift; 
	my ($args) = @_; 
	
	# mass mailing event log, no bounces
	my $query = 'SELECT email, COUNT(email) as "count" FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND event != \'num_subscribers\' GROUP BY msg_id, email ORDER BY count DESC;'; 
	my $sth = $self->{dbh}->prepare($query);
	   $sth->execute( $self->{name}, $args->{-mid} )
	      	or croak "cannot do statement! $DBI::errstr\n";
	my $r; 
	my $emails_events = {}; 
	while (my $row = $sth->fetchrow_hashref ) {		
    	$emails_events->{$row->{email}} = $row->{count}
	}
	$sth->finish; 
	undef $sth; 

	# mass mailing event log, bounces
 	$query = 'SELECT details, COUNT(event) as "count" FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND (event = \'soft_bounce\' OR event = \'hard_bounce\') GROUP BY msg_id, details ORDER BY count DESC;'; 
	my $sth = $self->{dbh}->prepare($query);
	   $sth->execute( $self->{name}, $args->{-mid} )
	      	or croak "cannot do statement! $DBI::errstr\n";
	my $r; 
	my $emails_bounces = {}; 
	while (my $row = $sth->fetchrow_hashref ) {
    	$emails_bounces->{$row->{details}} = (int($row->{count}) * .5); # WEIGHTED (down)
	}
	$sth->finish; 
	undef $sth; 
	# mass mailing event log, bounces
	
	#
	# I'm going to weigh Clickthroughs more than other things... 
	#
	# clickthrough log 
	   $query = 'SELECT email, COUNT(email) as "count" FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? AND msg_id = ?  GROUP BY msg_id, email ORDER BY count DESC;'; 
	my $sth = $self->{dbh}->prepare($query);
	   $sth->execute( $self->{name}, $args->{-mid} )
	      	or croak "cannot do statement! $DBI::errstr\n";
	my $r; 
	my $emails_clicks = {}; 
	while (my $row = $sth->fetchrow_hashref ) {
    	$emails_clicks->{$row->{email}} = (int($row->{count}) * 5) # WEIGHTED!
	}
	$sth->finish; 
	undef $sth; 
	#/ clickthrough log 

	my $folded = $emails_events; 
	# now, fold 'em all up; 
	foreach(keys %$emails_bounces){ 
		if(exists($folded->{$_})){ 
			$folded->{$_} = $folded->{$_} + $emails_bounces->{$_}; 
		}
		else { 
			$folded->{$_} = $emails_bounces->{$_}; 
		}
	}
	foreach(keys %$emails_clicks){ 
		if(exists($folded->{$_})){ 
			$folded->{$_} = $folded->{$_} + $emails_clicks->{$_}; 
		}
		else { 
			$folded->{$_} = $emails_clicks->{$_}; 
		}
	}
	
	
	# Sorted Index
	my @index = sort { $folded->{$b} <=> $folded->{$a} } keys %$folded; 
	my $sorted = []; 
	foreach(@index){ 
		next if !defined($_); 
		next if $_ eq ''; 
		push(@$sorted, {
			email => $_, 
			count => $folded->{$_}, 
			});
	}
	return $sorted; 
}

sub message_email_activity_listing_table { 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(! exists($args->{-vars})){ 
		$args->{-vars} = {}; 
	}
	
	my $html;
		
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;  
	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_email_activity_listing_table' . '.' . $args->{-mid}, 
		}
	);
	
	if(!defined($html)){ 
			
		my $report = $self->message_email_activity_listing($args);
		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_email_report_table.tmpl',
				-expr => 1, 
	            -vars => {
	#				type          => $args->{-type},
					report        => $report, 
					num           => scalar(@$report), 
					title         => 'Subscriber Activity', 
					label         => 'message_email_activity_listing_table',
					show_count    => 1, 
					%{$args->{-vars}},  
	            },
	        }
	    );	
	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_email_activity_listing_table' . '.' . $args->{-mid},
				-data    => \$html, 
			}
		);
	}
	
	use CGI qw(:standard); 
	print header(); 
	print $html;
	
}




sub message_individual_email_activity_csv { 
    
	my $self   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	my $report = $self->message_individual_email_activity_report($args);

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    my @title_fields = qw(
        timestamp
        remote_addr   
        event 
        url 
    ); 

    my @fields = qw(
        ctime
        ip   
        event 
        url 
    ); 
    
    my $title_status = $csv->print($fh, [@title_fields]);
    print $fh "\n";
    
    foreach my $ir(@$report) { 
        my $row = []; 
        foreach(@fields){ 
            push(@$row, $ir->{$_}); 
        }
        my $status = $csv->print( $fh, $row );
        print $fh "\n";
    }
    
}



sub message_individual_email_activity_report {
	my $self   = shift; 
	my ($args) = @_; 
	
	my $email = $args->{-email}; 
	my $mid   = $args->{-mid}; 
	
	my %labels = (
		open                => 'Open', 
		clickthrough        => 'Clickthrough', 
		unsubscribe         => 'Unsubcribe', 
		soft_bounce         => 'Soft Bounce', 
		hard_bounce         => 'Hard Bounce', 
		errors_sending_to   => 'Sending Error',
		abuse_report        => 'Abuse Report',  
	);
	
	my $return = []; 
	my $event_query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND ((email = ?) OR (event LIKE \'%bounce\' AND details = ?)) ORDER BY timestamp DESC';
    my $click_query = 'SELECT timestamp, remote_addr, url FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? and msg_id = ? and email = ? ORDER BY timestamp DESC';
		
	my $sth = $self->{dbh}->prepare($event_query);
	   $sth->execute($self->{name}, $mid, $email, $email);
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		my $time = $self->timestamp_to_time($row->{timestamp});
		push(
			@$return, {
			time        => $time, 
			timestamp   => $row->{timestamp}, 
			ctime       => scalar(localtime($time)), 
			ip          => $row->{remote_addr}, 
			event       => $row->{event}, 
			event_label => $labels{$row->{event}},
			}
		); 
	}
	$sth->finish;
	undef $row;  
	undef $sth; 

	my $sth = $self->{dbh}->prepare($click_query);
	   $sth->execute($self->{name}, $mid, $email);
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		
		my $time = $self->timestamp_to_time($row->{timestamp});
		push(
			@$return, {
			timestamp   => $row->{timestamp}, 
			time        => $time, 
			ctime       => scalar(localtime($time)), 
			ip          => $row->{remote_addr}, 
			event       => 'clickthrough', 
			event_label => $labels{clickthrough},
			url         => $row->{url},
			}
		); 
	}
	$sth->finish; 
	undef $sth;	
	
	@$return = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] }
      map { [ $_, $_->{'time'} ] } @$return;

	
	return $return;
	
}

sub message_individual_email_activity_report_table { 
	my $self   = shift; 
	my ($args) = @_;

	my $html;
		
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;  
	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_individual_email_activity_report' . '.' . $args->{-mid} . '.' . $args->{-email}, 
		}
	);
	
	if(!defined($html)){ 
	
		my $report = $self->message_individual_email_activity_report($args); 
	
		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_individual_email_activity_report_table.tmpl',
				-expr => 1, 
	            -vars => {
					email         => $args->{-email}, 
					mid           => $args->{-mid},
					report        => $report, 
					Plugin_URL    => $args->{-plugin_url}, 

	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_individual_email_activity_report' . '.' . $args->{-mid} . '.' . $args->{-email}, 
				-data    => \$html, 
			}
		);
	}
	return $html

}







sub purge_log { 
	
	
	my $self = shift; 
	
		
		my $query1 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
		my $query2 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?'; 
		
		$self->{dbh}->do($query1, {}, ($self->{name})) or die "cannot do statement $DBI::errstr\n"; 
		$self->{dbh}->do($query2, {}, ($self->{name})) or die "cannot do statement $DBI::errstr\n";

		require DADA::App::DataCache; 
		my $dc = DADA::App::DataCache->new;
		$dc->flush(
			{
				-list => $self->{name}
			}
		);
		
	return 1; 
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
