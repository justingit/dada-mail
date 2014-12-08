package DADA::Profile;

use lib qw (
  ../
  ../DADA/perllib
);

use Carp qw(carp croak);
use Try::Tiny; 

use DADA::Config;
use DADA::App::Guts;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();
use strict;
use vars qw(@EXPORT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile};

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);

    # This means we want to pull the email we want to use from
    # the saved session, but there is no valid session saved, so
    # this isn't going to work.
    if ( 
		 $args->{ -from_session } == 1 && 
		 !defined( $args->{ -email } ) ) {
       # return undef;
    }
    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return undef;
    }

    # Else...
    return $self;

}




sub _init {

    my $self = shift;

    my ($args) = @_;
	if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1  || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
	    # not enabled... 

	}
	else { 
		$self->{sql_params} = {%DADA::Config::SQL_PARAMS};
		my $dbi_obj = undef;
	    require DADA::App::DBIHandle;
	    $dbi_obj = DADA::App::DBIHandle->new;
	    $self->{dbh} = $dbi_obj->dbh_obj;
	}

    if ( exists( $args->{ -from_session } ) ) {
        if ( $args->{ -from_session } == 1 ) {
            require DADA::Profile::Session;
			my $sess = undef; 
			
            eval { 
				$sess = DADA::Profile::Session->new;
			}; 
			if($@){ 
				$args->{ -email } = undef;
                return;
			}
			else { 
					
	            if ( $sess->is_logged_in ) {
	                $args->{ -email } = $sess->get;
	            }
	            else {
	                $args->{ -email } = undef;
	                return;
	            }
			}
        }
    }
    else {
        $args->{ -from_session } = 0;
    }

    if ( !exists( $args->{ -email } ) ) {
        croak "you must pass an email address in, '-email'";
    }
    else {
        $self->{email} = cased($args->{ -email });
    }

	if(exists($self->{email})){ 
		require DADA::Profile::Fields; 
		$self->{fields} = DADA::Profile::Fields->new({-email => $self->{email}});
	}
}




sub exists {
	
    my $self = shift;
  #  my ($args) = @_;

	# This is saying, if we don't have a dbh handle, we don't have a proper 
	# "handle" on a profile. 
	
	if(! exists($self->{dbh})){ 
		return 0; 
	}
    my $query =
      'SELECT COUNT(*) FROM '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
		if $t; 

    $sth->execute($self->{email} )
      or croak "cannot do statement (at exists)! $DBI::errstr\n";

      my $count = $sth->fetchrow_array;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }

}




sub create { 
	
	my $type   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-email})){ 
		croak "You must pass an email in the, -email parameter!"; 
	}
	my $p = DADA::Profile->new(
		{
			-email => $args->{-email}
		}
	);  
	if($p->exists){ 
		croak "a profile for, " . $args->{-email} . " already exists!"; 
	}
	$p->insert($args); 
	return $p;
	
}



sub remove {
	
    my $self = shift;
    my ($args) = @_;
	
	if(!$self->{email}){ 
		croak "Cannot use this method without passing the '-email' param in, new (remove)"; 
	}
	if(!$self->exists){ 
		croak "Profile does not exist!"; 
	}
	
    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ? ';

	warn 'QUERY: ' . $query . ' (' . $self->{ email } . ')'
		if $t;

    my $sth = $self->{dbh}->prepare($query);

	my $rv = $sth->execute( $self->{ email } )
      or croak "cannot do statement (at remove)! $DBI::errstr\n";

    $sth->finish;

    return $rv;

}

sub insert {

	# DEV: No likey this method, at all. What's going on? 
	# I think the newer, create() method is a whole lot better.
	# (which.. eh, is just a wrapper for this! Eek!) 
	
    my $self = shift;
    my ($args) = @_;

    require DADA::Security::Password;

    my $enc_password = '';
    if ( exists( $args->{ -password } ) ) {
		require DADA::Security::Password; 
		$enc_password = DADA::Security::Password::encrypt_passwd( $args->{ -password } );
	}elsif(exists( $args->{ -encrypted_password })){ 
		$enc_password = $args->{ -encrypted_password };
	}
	else { 
		$enc_password = ''; 
	}

    if ( !exists $args->{ -activated } ) {
        $args->{ -activated } = 0;
    }

	# What? 
    if ( !exists $args->{ -update_email_auth_code } ) {
        # What? 
		# $args->{ -activated } = 0;
		
		# Maybe I meant, this? 
		$args->{ -update_email_auth_code } = undef; 
    }


    if ( !exists $args->{ -update_email } ) {
        # What? 
		# $args->{ -activated } = 0;
		
		# Maybe I meant, this? 
		$args->{ -update_email } = undef; 
		
    }

	my $email; 
	if(!exists($args->{-email})){ 
		$email = $self->{email};
	}
	else { 
		$email = $args->{-email}; 
	}

	
	if($enc_password eq ''){ 
		
		my $query =
	      'INSERT INTO '
	      . $DADA::Config::SQL_PARAMS{profile_table}
	      . '(email, auth_code, activated, update_email_auth_code, update_email) VALUES (?, ?, ?, ?, ?)';

	    warn 'QUERY: ' . $query
	      if $t;

	    my $sth = $self->{dbh}->prepare($query);

	    $sth->execute(
			$email, 
	        $args->{ -auth_code },
	        $args->{ -activated },
			$args->{ -update_email_auth_code },
			$args->{ -update_email },

	      )
	      or croak "cannot do statement (at insert)! $DBI::errstr\n";
	    $sth->finish;
	}
	else { 
	 	   my $query =
	      'INSERT INTO '
	      . $DADA::Config::SQL_PARAMS{profile_table}
	      . '(email, password, auth_code, activated, update_email_auth_code, update_email) VALUES (?, ?, ?, ?, ?, ?)';

	    warn 'QUERY: ' . $query
	      if $t;

	    my $sth = $self->{dbh}->prepare($query);

	    $sth->execute(
			$email, 
			$enc_password,
	        $args->{ -auth_code },
	        $args->{ -activated },
			$args->{ -update_email_auth_code },
			$args->{ -update_email },

	      )
	      or croak "cannot do statement (at insert)! $DBI::errstr\n";
	    $sth->finish;
	}
    return 1;

}

sub get {

    my $self = shift;
    my ($args) = @_;

	if(!$self->exists({-email => $args->{-email}})){ 
		return undef; 
	}

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{profile_table}
      . " WHERE email = ?";

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{email} )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $profile_info = {};
    my $hashref      = {};

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {

        $profile_info = $hashref;

        last FETCH;
    }

	# This would probably be the, "real" way to do it...
	#my (
	#	$profile_info->{email_name}, $profile_info->{email_domain}
	#) = split(
	#	'@', $profile_info->{email}
	#); 
	
    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        for ( keys %$profile_info ) {
            $dotted->{ 'profile.' . $_ } = $profile_info->{$_};
        }
        return $dotted;
    }
    else {
        return $profile_info;

    }

    carp "Didn't fetch the profile?!";
    return undef;

}

sub remove {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'DELETE  from '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ? ';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query . ' (' . $self->{email} . ')'
      if $t;
    my $rv = $sth->execute( $self->{email} )
      or croak "cannot do statement (at remove)! $DBI::errstr\n";
    $sth->finish;
    return $rv;
}



sub copy { 

	my $self = shift; 
    my ($args) = @_;
    if ( !exists( $args->{ -from } ) ) {
        die "you MUST pass the, '-from' parameter!";
    }
    if ( !exists( $args->{ -to } ) ) {
        die "you MUST pass the, '-to' parameter!";
    }

	require DADA::Profile::Fields; 
	my $og_dpf = DADA::Profile::Fields->new({-email => $args->{-from}});
	my $new_prof = DADA::Profile->new({-email => $args->{-to}});	 
	$new_prof->insert(
		{ 
			-confirmed => 1, 
			-mode      => 'writeover', 
			-password  => $self->_rand_str(8),
		}
	); 
	$new_prof->{fields}->insert({
		-fields => $og_dpf->get, 
		-mode   => 'writeover', 
	}); 
	return $new_prof; 
	
}

sub subscribed_to_list {
	
    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{ -list } ) ) {
        return 0;
    }

    my $subscriptions = $self->subscribed_to;
    for (@$subscriptions) {
        if ( $_ eq $args->{ -list } ) {
            return 1;
        }
    }
    return 0;
}

sub subscribed_to {

	# weirdly, a profile does not have to exists, for this to work. 
	# What? 
	
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }
    my $subscriptions   = [];
    my @available_lists = DADA::App::Guts::available_lists();

    require DADA::MailingList::Subscribers;
    require DADA::MailingList::Settings;

    my $list_names = {};
	
	my $lss = {};
	
    for (@available_lists) {
        my $lh = DADA::MailingList::Subscribers->new( { -list => $_ } );

		if($args->{-type} eq ':all'){ 
			
			my %list_types = (
							  list               => 'Subscribers',
			                  black_list         => 'Black Listed',
			                  white_list         => 'White Listed', # White listed isn't working, no?
			                  authorized_senders => 'Authorized Senders',
			                  moderators         => 'Moderators',
			                  sub_request_list   => 'Subscription Requests',
#			                  unsub_request_list => 'Unsubscription Requests',
							  bounced_list       => 'Bouncing Addresses',
			);
			
			ALL_TYPES: for my $s_type(keys %list_types){
				if ($lh->check_for_double_email(
	                	-Email => $self->{email},
	                	-Type  => $s_type,
				)) {
	            	push ( @$subscriptions, $_ );
					last ALL_TYPES;
	        	}
			}
		}else { 
	        if (
	            $lh->check_for_double_email(
	                -Email => $self->{email},
	                -Type  => $args->{ -type }
	            )
	          )
	        {
	            push ( @$subscriptions, $_ );
	        }
		}
        # This needs its own method...

        $lss->{$_} = DADA::MailingList::Settings->new( { -list => $_ } );
        $list_names->{$_} = $lss->{$_}->param('list_name');

    }

    if ( $args->{ -html_tmpl_params } ) {
        my $lt        = {};
        my $html_tmpl = [];
        for (@$subscriptions) {
            $lt->{$_} = 1;
        }
        for (@available_lists) {
			my $is_list_owner = 0; 
			if($lss->{$_}->param('list_owner_email') eq $self->{email}){ 
				$is_list_owner = 1; 
			}
            if ( exists( $lt->{$_} ) ) {
                push (
                    @$html_tmpl,
                    {
                        'profile.email' => $self->{email},
                        list            => $_,
                        subscribed      => 1,
						list_owner      => $is_list_owner, 
                    }
                );
            }
            else {
                push (
                    @$html_tmpl,
                    {
                        'profile.email' => $self->{email},
                        list            => $_,
                        subscribed      => 0,
						list_owner      => $is_list_owner, 
                    }
                );
            }
        }
        return $html_tmpl;
    }
    else {
        return $subscriptions;
    }

}

sub profile_update_email_report {

    my $self  = shift;
    my $lists = $self->subscribed_to;
    my $info  = $self->get;
	my $d_info = $self->get({-dotted => 1}); 
    require DADA::MailingList::Subscriber::Validate;
    my $subs = [];
	my $skip_list = []; 
	my $default_skip = [qw(
		closed_list
		over_subscription_quota
		already_sent_sub_confirmation
		no_list
	)];
	
	if(exists($DADA::Config::PROFILE_OPTIONS->{update_email_options}->{subscription_check_skip})){ 
		if($DADA::Config::PROFILE_OPTIONS->{update_email_options}->{subscription_check_skip} eq 'auto'){ 
			$skip_list  = $default_skip;  
		}
		else { 
			$skip_list = $DADA::Config::PROFILE_OPTIONS->{update_email_options}->{subscription_check_skip};
		}
	}
	else { 
		$skip_list = $default_skip;
	}
    for my $list (@$lists) {
        my $sv =
          DADA::MailingList::Subscriber::Validate->new( { -list => $list } );
        my ( $sub_status, $sub_errors ) = $sv->subscription_check(
            {
                -email => $info->{update_email},
                -skip  => [
					'closed_list', # DEV: I guess this is more of a design idea - 
								   # Should a subscriber, who is on a closed list, 
								   # be allowed to update their email address? \
								   # Since an address corresponds to a person, it make sense, 
								   # Although, I guess this could be used for nefarious purposes. 
								   # Ugh. Would like this to be some sort of option... 
                    'over_subscription_quota',
                    'already_sent_sub_confirmation',
                    'no_list',
                    'profile_fields',
                ],
            }
        );
        # warn 'email: ' . $info->{update_email}; 
        # warn 'status: ' . $sub_status;
        # warn 'errors:' . Data::Dumper::Dumper($sub_errors); 
        
        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        push (
            @$subs,
            {
                %{ $ls->get( -dotted => 1 ) },
                status => $sub_status,
                %$sub_errors,
				%$d_info, 
            }
        );
    }

	return $subs; 
	
}




sub update_email {

    my $self       = shift;
    my $old_fields = $self->{fields}->get;
    my $info       = $self->get;

    # Probably some check here, just to be thorough...

    # This updates the profile
    $self->update(
        {
            -activated              => 1,
            -email                  => $info->{update_email},
            -update_email           => '',
            -update_email_auth_code => '',
        }
    );

    # THis updates its fields
    my $new_prof_fields = DADA::Profile::Fields->new( { -email => $info->{update_email} } );
    $new_prof_fields->insert(
        {
            -fields    => $old_fields,
            -confirmed => 1,
            -mode      => 'writeover',
        }
    );

    # Why isn't the old profile fields stuff not removed?
    my $old_prof_fields = DADA::Profile::Fields->new( { -email => $info->{email} } );
    $old_prof_fields->remove;
    undef($old_prof_fields);
    
    # This updates the DADA::Profile::Settings; 
    require DADA::Profile::Settings;
    my $dps = DADA::Profile::Settings->new; 
       $dps->update(
           { 
               -from => $self->{email},
               -to   => $info->{update_email},
           }
    ); 
	
    $self->{email} = $info->{update_email};
    
    
    return 1;
}


sub is_activated {
    my $self = shift;
    my ($args) = @_;

    my $query =
      'SELECT activated FROM '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
		if $t; 

    $sth->execute( $args->{ -email } )
      or croak "cannot do statement (is_activated)! $DBI::errstr\n";
 #   my @row = $sth->fetchrow_array();

    my $activated = 0;
  	FETCH: while ( my $hashref = $sth->fetchrow_hashref ) {
        $activated = $hashref->{activated};
        last FETCH;
    }

    $sth->finish;
    return $activated;
}

sub activate {
    my $self = shift;
    my ($args) = @_;

	if(!$self->exists){ 
		croak "Profile does not exist!"; 
	}
	
    if ( !exists( $args->{ -activate } ) ) {
        $args->{ -activate } = 1;
    }
    if($args->{ -activate } != 1 && $args->{ -activate } != 0){ 
		croak "activate can only be set to 1 or 0!"; 
	}

    my $query = 'UPDATE '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' SET activated    = ? '
      . ' WHERE email      = ? ';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
      if $t;

    my $rv = $sth->execute( $args->{ -activate }, $self->{email} )
      or croak "cannot do statement (at activate)! $DBI::errstr\n";
    $sth->finish;
    return 1;
}





sub allowed_to_view_archives {

	my $self = shift; 
    my ($args) = @_;


	
	
    if ( !exists( $args->{ -list } ) ) {
        croak "You must pass a list in the, '-list' param!";
    }
 
    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1
        || $DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/ )
    {
        return 1;
    }
    else {
		require DADA::MailingList::Settings; 
		my $ls = DADA::MailingList::Settings->new({-list => $args->{ -list }}); 
        if ( $ls->param('archives_available_only_to_subscribers') == 1 )
        {
	

			
            if ($self->exists) {



                if (
                    $self->subscribed_to_list( { -list => $args->{ -list } } ) )
                {
                    return 1;
                }
                else {
                    return 0;
                }
            }
            else {
                return 0;
            }
        }
        else {
            return 1;
        }
    }
}

sub is_valid_password {

    my $self = shift;
    my ($args) = @_;

	if(! exists($args->{ -password })){ 
		return 0; 
	}
	
    require DADA::Security::Password;

    my $query =
      'SELECT email, password FROM '
      . $DADA::Config::SQL_PARAMS{profile_table}
      . ' WHERE email = ?';

    warn 'QUERY: ' . $query
		if $t; 
		
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{email} )
      or croak "cannot do statement (at is_valid_password)! $DBI::errstr\n";

  FETCH: while ( my $hashref = $sth->fetchrow_hashref ) {

        if (
            DADA::Security::Password::check_password(
                $hashref->{password}, $args->{ -password } ) == 1
          )
        {
            $sth->finish;
            return 1;
        }
        else {
            $sth->finish;
            return 0;
        }

        last FETCH;    # which will never be called...
    }

}

sub is_valid_registration {

    my $self = shift;
    my ($args) = @_;

    my $status = 1;
    my $errors = {
        email_no_match => 0,
        profile_exists => 0,
        invalid_email  => 0,
        password_blank => 0,
        captcha_failed => 0,
    };

    if ( $args->{ -email } ne $args->{ -email_again } ) {
        $errors->{email_no_match} = 1;
        $status = 0;
    }
    if ( check_for_valid_email( $args->{ -email } ) == 0 ) {

        # ...
    }
    else {
        $errors->{invalid_email} = 1;
        $status = 0;
    }
    if ( $self->exists ) {
        $errors->{profile_exists} = 1;
        $status = 0;
    }
    if ( length( $args->{ -password } ) == 0 ) {
        $errors->{password_blank} = 1;
        $status = 0;
    }

    my $cap             = undef;

	if($DADA::Config::PROFILE_OPTIONS->{enable_captcha} == 1){
	    if ( can_use_AuthenCAPTCHA() == 1 ) {
	        $cap = DADA::Security::AuthenCAPTCHA->new;
	        my $result = $cap->check_answer(
	            $DADA::Config::RECAPTCHA_PARAMS->{private_key},
	            $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'},
	            $args->{ -recaptcha_challenge_field },
	            $args->{ -recaptcha_response_field },
	        );
	        if ( $result->{is_valid} == 1 ) {

	            # ...
	        }
	        else {
	            $errors->{captcha_failed} = 1;
	            $status = 0;
	        }
	    }
	}
    return ( $status, $errors );

}

sub is_valid_update_profile_email { 
	
	my $self = shift; 
	my ($args) = @_;
	
	my $status = 1; 
	my $errors = {		
	    profile_exists => 0,
        invalid_email  => 0,
  	}; 

    if ( check_for_valid_email( $args->{ -updated_email } ) == 0 ) {
        # ...
    }
    else {
        $errors->{invalid_email} = 1;
        $status = 0;
    }
	my $new_prof = DADA::Profile->new({-email => $args->{ -updated_email }}); 
    if ( $new_prof->exists ) {
        $errors->{profile_exists} = 1;
        $status = 0;
    }
	
	return ($status, $errors);
		
}

sub is_valid_update_profile_activation { 

	my $self = shift; 
	my ($args) = @_;
	
	my $status = 1; 
	
	my $errors = {		
	    profile_exists    => 0,
        invalid_email     => 0,
		invalid_auth_code => 0, 
  	}; 

	if($self->exists == 1){ 
		# ... 
	}
	else { 
        $errors->{profile_no_exists} = 1;
        $status = 0;		
        return ($status, $errors);
	}
	
	my $profile = $self->get;
	
	my $new_prof = DADA::Profile->new({-email => $profile->{ update_email }}); 
    if ( $new_prof->exists == 1 ) {
        $errors->{profile_exists} = 1;
        $status = 0;
    }
    undef($new_prof); 

	if ( check_for_valid_email( $profile->{ update_email } ) == 0 ) {
        # ...
    }
    else {
        $errors->{invalid_email} = 1;
        $status = 0;
    }

    if ( $profile->{update_email_auth_code} eq $args->{ -update_email_auth_code } ) {
        # ...
    }
    else {
        $errors->{invalid_auth_code} = 1;
        $status = 0;
    }
	return ($status, $errors);
}

sub update {

    my $self = shift;
    my ($args) = @_;
    my $orig = $self->get;
	my $new  = {}; 
	
	# This couldn't be any more terrible:
    for ( keys %$orig ) {
        # I'll have to remember why email is skipped... 
		#next if $_ eq 'email';
		
		if ( exists( $args->{ '-' . $_ } ) ) {
	            $new->{'-'.$_} = $args->{ '-' . $_ };
        }
		else { 
			if($_ eq 'password'){ 
				
				$new->{'-encrypted_password'} = $orig->{$_};
				delete($new->{'-password'}); # that may not be needed. 
			}
			else { 
				$new->{'-'.$_} = $orig->{$_}; 
			}
		}
    }

    $self->remove();
    $self->insert($new);

}


sub setup_profile {
    my $self = shift;
    my ($args) = @_;

    # Pop it in,
    $self->insert( 
		{ 
			-password => $args->{ -password }, 
		} 
	);

    # Spit it out:
    $self->send_profile_activation_email();
    return 1;
}

sub send_profile_activation_email {
    my $self = shift;
    my ($args) = @_;

    # We're currently faking this:
    my ( $n, $d ) = split( '@', $self->{email} );

    my $auth_code = $self->set_auth_code($args);
    my $profile_activation_link =
        $DADA::Config::PROGRAM_URL
      . '/profile_activate/'
      . uriescape($n) 
      . '/'
      . $d 
      . '/'
      . $auth_code 
      . '/';

      require DADA::App::ReadEmailMessages; 
      my $rm = DADA::App::ReadEmailMessages->new; 
      my $msg_data = $rm->read_message('profiles_activation_message.eml'); 
  
    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->_config_profile_host_list,
            -email   => $self->{email},
            -headers => {
                Subject => $msg_data->{subject},
                From    => $self->_config_profile_email(1),
                To      => $self->{email},
            },
            -body        => $msg_data->{plaintext_body},
            -tmpl_params => {
                -vars => {
                    auth_code                    => $auth_code,
                    email                        => $self->{email},
                    'profile.email'              => $self->{email},
                    'profile.email_name'         => $n,
                    'profile.email_domain'       => $d,
                    'app.profile_activation_link' => $profile_activation_link, 
                },
            },
        }
    );

    return 1;

}

sub send_profile_reset_password_email {
    my $self = shift;
    my ($args) = @_;

	# We're currently faking this: 
	my ($n, $d) = split('@', $self->{email});
	
    my $auth_code = $self->set_auth_code($args);
	my $profile_reset_confirmation_link = $DADA::Config::PROGRAM_URL 
	. '/profile_reset_password/'
    . uriescape($n) 
    . '/'
    . $d 
    . '/'
    . $auth_code 
    . '/';
    
    require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('profiles_reset_password_message.eml'); 
    
    
    require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->_config_profile_host_list, 
            -email   => $self->{email},
            -headers => {
                Subject =>
                  $msg_data->{subject}, 
                From => $self->_config_profile_email(1),
                To   => $self->{email},
            },
            -body        => $msg_data->{plaintext_body},
            -tmpl_params => {
                -vars => {
                    auth_code                             => $auth_code,
                   	'profile.email'                       => $self->{email},
					'profile.email_name'                  => $n, 
					'profile.email_domain'                => $d,
					email                                 => $self->{email},
					'app.profile_reset_password_link'     => $profile_reset_confirmation_link, 
                },
            },
        }
    );
    return 1;
}


sub confirm_update_profile_email { 
	
	my $self = shift; 
	my ($args) = @_; 
	
	if(! exists($args->{-updated_email}) ){ 
		croak "You MUST pass the email to update the profile in, '-updated_email' parameter!"; 
	}
	
	my $auth_code = $self->_rand_str; 
	
	my $info = $self->get; 
	
	$self->update({ 
		-activated 				=> 1, 
		-update_email 			=> $args->{-updated_email}, 
		-update_email_auth_code => $auth_code, 
	}); 
	
	$self->send_update_profile_email_email({
		-updated_email 			=> $args->{-updated_email}, 
		-update_email_auth_code => $auth_code,		
	}); 
	
	return 1; 
	
}

sub send_update_profile_email_email { 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(! exists( $args->{-updated_email} ) ){ 
		croak "You MUST pass the email to update the profile in, '-updated_email' parameter!"; 
	}
	if(! exists($args->{-update_email_auth_code}) ){ 
		croak "You MUST pass the auth_code to update the profile in, '-update_email_auth_code' parameter!"; 
	}
	
	# We're currently faking this: 
	my ($n, $d) = split('@', $self->{email});
	my $auth_code = $args->{-update_email_auth_code}; 
	
	my $update_profile_email_link = $DADA::Config::PROGRAM_URL 
	. '/profile_update_email/'
    . uriescape($n) 
    . '/'
    . $d 
    . '/'
    . $auth_code 
    . '/';
	
	my $info = $self->get({-dotted => 1}); 
	
	
	require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('profiles_update_email_message.eml'); 
    
	require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->_config_profile_host_list, 
            -email   => $args->{-updated_email},
            -headers => {
                Subject =>
                  $msg_data->{subject},
                From => $self->_config_profile_email(1),
                To   => $args->{-updated_email},
            },
            -body        => $msg_data->{plaintext_body},
            -tmpl_params => {
                -vars => {
                    'profile.update_email_auth_code' => $args->{-update_email_auth_code},
					'profile.updated_email'          => $args->{-updated_email}, 
                   	'profile.email'                  => $self->{email},
					'profile.email_name'             => $n, 
					'profile.email_domain'           => $d,
					'app.profile_update_email_link'  => $update_profile_email_link, 
                },
            },
        }
    );
    return 1;
}

sub send_update_email_notification { 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(exists($DADA::Config::PROFILE_OPTIONS->{update_email_options}->{send_notification_to_profile_email})){ 
		if($DADA::Config::PROFILE_OPTIONS->{update_email_options}->{send_notification_to_profile_email} == 1){ 
			# ... 
		}
		else { 
			return 1; 
		}
	}
	
	
	
	
	if(! exists( $args->{-prev_email} ) ){ 
		croak "You MUST pass the old email  in, '-prev_email' parameter!"; 
	}
	my $info = $self->get({-dotted => 1}); 
	
	require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('profiles_email_updated_notification_message.eml'); 
    

	require DADA::App::Messages;
    DADA::App::Messages::send_generic_email(
        {
            -list    => $self->_config_profile_host_list, 
            -headers => {
                Subject => $msg_data->{subject},
                From => $self->_config_profile_email(1),
                To   => $self->_config_profile_email,
            },
            -body        => $msg_data->{plaintext_body},
            -tmpl_params => {
                -vars => {
					'profile.prev_email'             => $args->{-prev_email}, 
                   	'profile.email'                  => $self->{email},					
                },
            },
        }
    );
    return 1;

	
}



sub is_valid_activation {

    my $self = shift;
    my ($args) = @_; 

    my $status = 1;
    my $errors = { invalid_auth_code => 0, };

    my $profile = $self->get($args);

    if ( $profile->{auth_code} eq $args->{ -auth_code } ) {

        # ...
    }
    else {
        $errors->{invalid_auth_code} = 1;
        $status = 0;
    }

    return ( $status, $errors );
}


sub set_auth_code {

    my $self = shift;
    my ($args) = @_;

    if ( $self->exists($args) ) {
        my $auth_code = $self->_rand_str;
        my $query     = 'UPDATE '
          . $DADA::Config::SQL_PARAMS{profile_table}
          . ' SET auth_code	   = ? '
          . ' WHERE email   = ? ';
        my $sth = $self->{dbh}->prepare($query);

        warn 'QUERY: ' . $query
          if $t;
        my $rv = $sth->execute( $auth_code, $self->{email} )
          or croak "cannot do statement (at set_auth_code)! $DBI::errstr\n";
        $sth->finish;
        return $auth_code;
    }
    else {
        croak "profile for, " . $self->{email} . " does not exist!";
    }

}



sub _rand_str {
    my $self = shift;
    my $size = shift || 16;
    require DADA::Security::Password;
    return DADA::Security::Password::generate_rand_string( undef, $size );
}


sub _config_profile_email {
    my $self = shift;
	my $n    = shift || undef; 
 
    if ( length($DADA::Config::PROFILE_OPTIONS->{profile_email}) > 0) {
		my @good_addresses = (); 
		require Email::Address;
		my @addrs = Email::Address->parse( $DADA::Config::PROFILE_OPTIONS->{profile_email} );

		for my $a(@addrs) { 
			if(DADA::App::Guts::check_for_valid_email($a->address) == 0){ 
				push(@good_addresses, $a->format);
			}
		}
		# Do we have >= 1 address that are good? 
		if(scalar(@good_addresses) >= 1){
			my $r = ''; 
			# We gotta limit on how many we want back? 
			if(defined($n) && $self->_is_integer($n)){ 
				# Is it more than how many are available? 
				if($n > scalar(@good_addresses)){ 
					# Well, let's lower that a bit
					$n = scalar(@good_addresses);
				}
				# join!
				$r = join(', ', $good_addresses[0, ($n - 1)]);
			}
			else { 
				# Well then join them all
				$r = join(', ', @good_addresses);
			}
			return $r; 
		}
		else { 
			return $self->_magic_config_profile_email;			
		}
    }
    else {
		return $self->_magic_config_profile_email;
    }
}

sub _config_profile_host_list { 
    my $self = shift; 
    if ( length($DADA::Config::PROFILE_OPTIONS->{profile_host_list}) > 0) {
        if(check_if_list_exists(-List => $DADA::Config::PROFILE_OPTIONS->{profile_host_list}) == 1){ 
            return $DADA::Config::PROFILE_OPTIONS->{profile_host_list};
        }
        else { 
            warn 'list, ' . $DADA::Config::PROFILE_OPTIONS->{profile_host_list} . ' does not exist.'; 
            return undef; 
        }
    }
    else { 
        return undef; 
    }
}

sub _magic_config_profile_email { 
	my $self = shift; 
	
	if(defined($self->_config_profile_host_list)){ 
        require DADA::MailingList::Settings;
	    my $ls = DADA::MailingList::Settings->new( { -list => $self->_config_profile_host_list } );
        return $ls->param('list_owner_email');
	}
	else { 
	    
        # magically.
        require DADA::App::Guts;
        my @l = DADA::App::Guts::available_lists();
        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $l[0] } );
        return $ls->param('list_owner_email');
    }
}

sub _is_integer {
	my $self = shift; 
	my $n    = shift; 
    defined $n && $n =~ /^[+-]?\d+$/;
}

sub feature_enabled { 	
	#my $self = shift; 
	my $feature || undef; 
	my $enabled = $DADA::Config::PROFILE_OPTIONS->{features}; 


	if(!defined($feature)){
		# For templates, basically. 
		my $defaults = {
			help                        => 1,
			login                       => 1, 
			register                    => 1, 
			password_reset              => 1, 
			profile_fields              => 1,  
			mailing_list_subscriptions  => 1,
			protected_directories       => 1,  
			update_email_address        => 1, 
			change_password             => 1, 
			delete_profile              => 1, 
		};
		my $pf = {};
		for(keys %$defaults){ 
			if(!exists($enabled->{$_})){ 
				$pf->{'profile_feature_' . $_} = $defaults->{$_}; 
			}
			else { 
				$pf->{'profile_feature_' . $_} = $enabled->{$_}; 
			}
		}
		return $pf;
	}
	else { 
		if(exists($enabled->{$feature})){ 
			if($enabled->{$feature} == 1){ 
				return 1;
			}
			else { 
				return 0; 
			}
		}
		else { 
			return 0; 
		}
	}
}



1;


=pod

=head1 NAME 

DADA::Profile

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 Public Methods

=head2 new

	 my $p = DADA::Profile->new(
		{ 
			-email => 'user@example.com', 
		}
	); 

C<new> returns a DADA::Profile object. 

C<new> requires you to either pass the C<-email> parameter, with a valid email 
address, or the, C<-from_session> parameter, set to, C<1>: 

 my $p = DADA::Profile->new(
	{ 
		-from_session => 1, 
	}
 );

If invoked this way, the email address needed will be searched for within the 
saved session information for the particular environment. 

If no email address is passed, or found within the session, this method will croak. 

The email address passed needs not to have a valid profile, but some sort of email address needs to be passed. 

=head2 exists 

 my $prof = DADA::Profile->new({-email => 'user@example.com'}); 
 if($prof->exists){ 
	print "you exist!"; 
 }
 else { 
	print "you do not exist!"; 
 }

or even, 

 if(DADA::Profile->new({-email => 'user@example.com'})->exists){ 
	print "it's alive!"; 
 }

C<exists> let's you know if a profile with the email address, C<-email> 
actually exists. Return C<1> if it does, C<0> if it doesn't. 

=head2 subscribed_to_list 

 $p->subscribed_to_list(
	{
		-list => 'my list',
	}
 ); 

C<subscribed_to_list> returns C<1> if the profile has a subscription to the list passed in, C<-list> 
and will return C<0> if they are not subscribed.

=head2 insert 

(blinky blinky under construction!)

 $p->insert(
	{
		-password  => 'mypass',
		-activated => 1, 
		-auth_code => 1234, 
	}
 );



C<insert>, I<inserts> a profile. It's not specifically used to I<create> new profiles and perhaps a shortcoming of this module (currently). What's strange is that 
if you attempt to insert two profiles dealing with the same address, you'll probably error out, just with the UNIQUE column of the table design... Gah.

Because of this somewhat sour design of this method, it's recommended you tread lightly and assume that the API will change, if not in the stable release, 
in a release sooner, rather than later. Outside of this module's code, it's used only once - making it somewhat of a private method, anyways. I'm going to forgo testing
this method until I figure all that out... </notestomyself>

(see create())



=head2 subscribed_to

 my $subs = $p->subscribed_to; 

C<subscribed_to> returns an array ref of all the lists the profile is subscribed to. 

You can pass a C<-type> param to change which sublists are looked at. The default is, C<list>. 

You can also pass the, C<-html_tmpl_params> parameter (set to, "1") to return back a complex data structure that works well with HTML::Template: 

If our profile was subscribed to the list, I<mylist> this: 
	
	my $p = DADA::Profile->new(
		{
			-email => 'user@example.com'
		}
	); 
	$p->subscribed_to(
		{
			-list             => 'my list', 
			-html_tmpl_params => 1, 
		}
	);

would return, 

 [
  {
	'profile.email' => 'user@example.com',
    list            => 'mylist',
    subscribed      => 1
  }
 ]

=head2 is_activated

 if($p->is_activated){ 
	print "We are activated!"; 
 }
 else { 
	print "Nope. Not activated.";
 }

C<-activated> returns either C<1> if the profile is actived, or, C<0>, if the profile is not C<activated>

You can activate a profile using the, C<activate()> method: 

 $p->activate; 

=head2 activate

 $p->activate; 

Or, 

 $p->activate(
	{
		-activate => 1, 
	}
 ); 

Or, to deactivate: 

 $p->activate(
	{
		-activate => 0, 
	}
 ); 

C<activate> is used primarily to activate a profile. If no parameters are passed, 
the method will activate a profile. 

You may pass the, C<-activate> parameter, set to either C<1> or, C<0> to activate or deactivate the profile. 

=head2 allowed_to_view_archives
	
  my $p = DADA::Profile->new({-email => 'user@example.com'}); 
 if($p->allowed_to_view_archives({-list => 'mylist'})){ 
	# Show 'em the archives!
 }
 else { 
	# No archives for you!
 }

C<allowed_to_view_archives> returns either C<1>, if the profile is allowed to view archives for a particular list, or, C<0> if they aren't. 

The, C<-list> parameter is required and needs to be filled out to a specific Dada Mail List (shortname). If no C<-list> parameter is passed, this method will croak. 

Several things will change the return value of this method: 

If Profiles are not enabled (via the, C<$PROFILE_OPTIONS-E<gt>{enabled}> Config.pm variable), this method will always return, C<1>. 

If Profiles are enabled, but the email address you're trying to look up profile information, doesn't actually have a profile, I<and> profiles are  enabled, this method will always return C<0> 

Other than that, this method should return whatever is usually expected. 

=head2 is_valid_password

 if($p->is_valid_password({-password => 'secret'})){ 
	print "let 'em in!"; 
 }
 else { 
	print "Show them the door!"; 
 } 

C<is_valid_password> is used to check a passed password (passed in the, C<-password> param), with the stored password. The stored password will be stored in an encrypted form, so don't try to match directly. 

Will return C<1> if the passwords do match and will return C<0> if they do not match, or you forget to pass a password in the, C<-password> param. 

=head2 is_valid_registration

 my ($status, $errors) = $p->is_valid_registration(
		{
			-email 		               => 'user@example.com', 
			-email_again               => 'user@example.com', 
			-password                  => 'secret', 
	        -recaptcha_challenge_field => '1234', 
	        -recaptcha_response_field  => 'abcd', 
		}
 ); 

C<is_valid_registration> is used to validate a new registration. This usually means taking information from an HTML form and passing it through this method, to make sure 
that the information passed is valid, so we can start the registration process. It requires a few parameters: 

=over

=item * -email

Should hold the email address, associated with the new profile

=item * -email_again

Should match exactly what's passed in the, C<-email> parameter. 

=item * -password

Should hold a valid password. Currently, this just means that I<something> has to be passed in this parameter. 

=back

If CAPTCHA is enabled for Profiles, (via the Config.pm C<$PROFILE_OPTIONS-E<gt>{gravatar_options}-E<gt>{enable_gravators}> parameter) the following two parameters also have to be passed: 

=over

=item * -recaptcha_challenge_field

=item * -recaptcha_response_field

=back 

C<-recaptcha_challenge_field> and C<-recaptcha_response_field> map to the 3rd and 4th arguments you have to pass in C<DADA::Security::AuthenCAPTCHA>'s method, C<check_answer>, which is sadly currently under documented, but 
follows the same API as Captcha::reCAPTCHA: 

L<http://search.cpan.org/~andya/Captcha-reCAPTCHA/lib/Captcha/reCAPTCHA.pm>

(the C<check_answer> method does, at the very least) 

This method will return an array or two elements. 

The first element, is the status. If it's set to, C<1>, then the information passed will work to create a brand new profile. If it's set to, C<0>, there's something wrong with the information. 

The exact problems will be described in the second element passed, which will be a hashref. The key will describe the problem, and the value will be set to, C<1> if a problem was found. Here's the keys that may be passed: 

=over

=item * email_no_match

C<-email> and, C<-email_again> are not the same. 

=item * invalid_email

The email isn't a valid email address. 

=item * profile_exists

There's already a profile for the email address you're passwing! 

=item * captcha_failed

The captcha test didn't pass. 

=back

If $status returns C<0>, in no way should a new profile be registered. 

=head2 update

 $p->update(
	{
		-password => 'my_new_password', 
	}
 ); 

C<update> simply updates the information for the profile. In its current state, it looks like it should only 
be used to update the password of a profile, although any information about the profile, except the email address, 
can be updated. 

Scarily, there's no checks on the validity of the information passed. This should be fixed in the future. 

=head2 setup_profile

=head2 send_profile_activation_email

=head2 send_profile_reset_password_email

=head2 send_profile_reset_password_email

=head2 is_valid_activation

 $p->is_valid_activation(
	{
		-auth_code => $auth_code,
	}
 );

This method is similar to, C<is_valid_registration>, as it returns a two-element array, the first element set to either C<1>, for validity and C<0> for not, with the second element being 
a hashref of key/values describing what went wrong. 

In this case, the only thing it's looking for the is the authorization code, which you should pass in the, C<-auth_code> parameter. 

This is the authorization code that used in the email sent out to confirm a new profile. If the authorization code is not current, $status will be set to, C<0> 
and the second element hashref will have the current key/value pair: 

	invalid_auth_code => 1

Other errors may join, C<invalid_auth_code> in the future. 

=head2 set_auth_code

	$p->set_auth_code; 

C<set_auth_code> sets a new authorization code for the profile you're working on. It takes no arguments. 

But, it will return the authorization code it creates. 

This method will croak if the profile you're trying to set an authorization code doesn't actually exist. 

=head2 


=head1 AUTHOR

Justin Simoni http://dadamailproject.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

