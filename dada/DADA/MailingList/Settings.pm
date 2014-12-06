package DADA::MailingList::Settings; 
use strict;
use lib qw(./ ../ ../../ ../../DADA ../perllib); 


my $t = 0; 

use Carp qw(croak carp); 

my $type; 
my $backend; 
use DADA::Config qw(!:DEFAULT); 	
use DADA::App::Guts; 

BEGIN { 
	$type = $DADA::Config::SETTINGS_DB_TYPE;
	if($type eq 'SQL'){ 
	 	if ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){ 
			$backend = 'MySQL';
		}
		elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){ 		
				$backend = 'PostgreSQL';
		}
		elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite'){ 
			$backend = 'SQLite';
		}
	}
	elsif($type eq 'Db'){ 
		$backend = 'Db'; 
	}
	else { 
		die "Unknown \$SETTINGS_DB_TYPE: '$type' Supported types: 'Db', 'SQL'"; 
	}
}
use base "DADA::MailingList::Settings::$backend";


sub _init  { 
    my $self   = shift; 
	my ($args) = @_; 

	
    if($args->{-new_list} == 1){ 
	
		$self->{name} = $args->{-list};
	}else{ 
		
		if($self->_list_name_check($args->{-list}) == 0) { 
    		croak('BAD List name "' . $args->{-list} . '" ' . $!);
		}
	}
}




sub get { 
	
	my $self = shift; 
	my %args = (
	    -Format => "raw", 
	    -dotted => 0, 
	    @_
	); 

	$self->_raw_db_hash;
	
	my $ls                   = $self->{RAW_DB_HASH}; 
	
	$ls = $self->post_process_get($ls, {%args});
	
	if($args{-dotted} == 1){ 
        my $new_ls = {}; 
        while (my ($k, $v) = each(%$ls)){
            $new_ls->{'list_settings.' . $k} = $v; 
        }
        return $new_ls; 

	}
	else { 
			
	    return $ls; 
    }
}




sub post_process_get {

    my $self = shift;
    my $li   = shift;
    my $args = shift;

    if(! exists($args->{-all_settings})){ 
        $args->{-all_settings} = 0; 
    }
   #  warn '$args->{-all_settings} ' . $args->{-all_settings}; 
    
    carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! List "
      . $self->{function}
      . " db empty!  List setting DB Possibly corrupted!"
      unless keys %$li;

    carp
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! no listshortname saved in list "
      . $self->{function}
      . " db! List "
      . $self->{function}
      . " DB Possibly corrupted!"
      if !$li->{list};

    carp "listshortname in db, '"
      . $self->{name}
      . "' does not match saved list shortname: '"
      . $li->{list} . "'"
      if $self->{name} ne $li->{list};

    if ( $args->{-Format} ne 'unmunged' ) {
        $li->{charset_value} = $self->_munge_charset($li);
        $li = $self->_munge_for_deprecated($li);

        if ( !exists( $li->{list_info} ) ) {
            $li->{list_info} = $li->{info};
        }

        # sasl_smtp_password
        # pop3_password

        # If we don't need to load, DADA::Security::Password, let's not.

        my $d_password_check = 0;
        for ( 'sasl_smtp_password', 'pop3_password',
            'discussion_pop_password' )
        {
            if (   exists( $DADA::Config::LIST_SETUP_DEFAULTS{$_} )
                || exists( $DADA::Config::LIST_SETUP_OVERRIDES{$_} ) )
            {
                $d_password_check = 1;
                require DADA::Security::Password;
                last;
            }
        }
        
        for ( 'sasl_smtp_password', 'pop3_password',
            'discussion_pop_password' )
        {

            if ( $DADA::Config::LIST_SETUP_OVERRIDES{$_} ) {

                $self->{orig}->{LIST_SETUP_OVERRIDES}->{$_} =
                  $DADA::Config::LIST_SETUP_OVERRIDES{$_};
                $DADA::Config::LIST_SETUP_OVERRIDES{$_} =
                  DADA::Security::Password::cipher_encrypt( $li->{cipher_key},
                    $DADA::Config::LIST_SETUP_OVERRIDES{$_} );
                next;
            }

            if ( $DADA::Config::LIST_SETUP_DEFAULTS{$_} ) {
                if ( !$li->{$_} ) {
                    $self->{orig}->{LIST_SETUP_DEFAULTS}->{$_} =
                      $DADA::Config::LIST_SETUP_DEFAULTS{$_};
                    $DADA::Config::LIST_SETUP_DEFAULTS{$_} =
                      DADA::Security::Password::cipher_encrypt(
                        $li->{cipher_key},
                        $DADA::Config::LIST_SETUP_DEFAULTS{$_} );
                }
            }
        }

        for ( keys %$li ) {
            if ( exists( $li->{$_} ) ) {
                if ( !defined( $li->{$_} ) ) {
                    delete( $li->{$_} );
                }
            }
        }

        if($args->{-all_settings} == 1) { 
            my $start_time = time; 
            my $html_settings          = $self->_html_settings;
            my $email_message_settings = $self->_email_message_settings; 
        
            for ( keys %DADA::Config::LIST_SETUP_DEFAULTS ) {
                if ( !exists( $li->{$_} ) || length( $li->{$_} ) == 0 ) {
                    if(exists($email_message_settings->{$_})) { 
                        $li->{$_} = $self->_fill_in_email_message_settings($_); 
                    }
                    elsif(exists($html_settings->{$_})) {
                        $li->{$_} = $self->_fill_in_html_settings($_);                      
                    }
                    else { 
                        $li->{$_} = $DADA::Config::LIST_SETUP_DEFAULTS{$_};
                    }
                }
            }
        }
        else { 
            for ( keys %DADA::Config::LIST_SETUP_DEFAULTS ) {
                if ( !exists( $li->{$_} ) || length( $li->{$_} ) == 0 ) {
                    $li->{$_} = $DADA::Config::LIST_SETUP_DEFAULTS{$_};               
                }
            }
        }
		# This says basically, make sure the list subscription quota is <= the global list sub quota. 
        $DADA::Config::SUBSCRIPTION_QUOTA ||= undef;

        if (   $DADA::Config::SUBSCRIPTION_QUOTA
            && $li->{subscription_quota}
            && ( $li->{subscription_quota} > $DADA::Config::SUBSCRIPTION_QUOTA )
          )
        {
            $li->{subscription_quota} = $DADA::Config::SUBSCRIPTION_QUOTA;
        }



        for ( 'sasl_smtp_password', 'pop3_password',
            'discussion_pop_password' )
        {
            if ( $DADA::Config::LIST_SETUP_OVERRIDES{$_} ) {
                $DADA::Config::LIST_SETUP_OVERRIDES{$_} =
                  $self->{orig}->{LIST_SETUP_OVERRIDES}->{$_};
            }

            if ( $DADA::Config::LIST_SETUP_DEFAULTS{$_} ) {
                $DADA::Config::LIST_SETUP_DEFAULTS{$_} =
                  $self->{orig}->{LIST_SETUP_DEFAULTS}->{$_};
            }
        }
    }

    # And then, there's this:
    # DEV: Strange, that it's been left out? Did it get removed?
    for ( keys %DADA::Config::LIST_SETUP_OVERRIDES ) {
        next if $_ eq 'sasl_smtp_password';
        next if $_ eq 'pop3_password';
        next if $_ eq 'discussion_pop_password';
        $li->{$_} = $DADA::Config::LIST_SETUP_OVERRIDES{$_};
    }

    if ( !exists( $li->{admin_email} ) ) {
        $li->{admin_email} = $li->{list_owner_email};
    }
    elsif ( $li->{admin_email} eq undef ) {
        $li->{admin_email} = $li->{list_owner_email};
    }

    if ( $DADA::Config::ENFORCE_CLOSED_LOOP_OPT_IN != 1 ) {
		# ... 
    }
	else { 
	    $li->{enable_closed_loop_opt_in}               = 1;
        $li->{enable_mass_subscribe}                   = 0;
        $li->{enable_mass_subscribe_only_w_root_login} = 0; 
		$li->{allow_admin_to_subscribe_blacklisted}    = 0; 
		$li->{skip_sub_confirm_if_logged_in}           = 0;	
	}
    return $li;

}




sub params { 
	
	my $self = shift; 
	
	if(keys %{$self->{cached_settings}}){ 
		#... 
	}
	else { 
		$self->{cached_settings} = $self->get; 
	}
	
	return $self->{cached_settings};
	
}



sub param { 
	
	my $self  = shift; 
	my $name  = shift  || undef; 
	my $value = shift;
	
	if(!defined($name)){ 
		croak "You MUST pass a name as the first argument!"; 
	}
	
	if(!exists($DADA::Config::LIST_SETUP_DEFAULTS{$name})){ 
		croak "Cannot call param() on unknown setting, '$name'"; 
	}
	
	
	if(keys %{$self->{cached_settings}}){ 
		warn "$name is cached, using cached stuff." if $t;  
	}
	else { 
		warn "$name is NOT cached, fetching new stuff" if $t; 
		$self->{cached_settings} = $self->get; 
	}
	
	if(defined($value)){  
		$self->save({$name => $value});
		$self->{cached_settings} = {};
		return $value; # or... what should I return?
	}
	else { 
	
		if(exists($self->{cached_settings}->{$name}) && defined($self->{cached_settings}->{$name})) { 
		    warn 'setting is cached and defined.' if $t; 
			return $self->{cached_settings}->{$name};
		}
		elsif($self->_html_settings()->{$name}){ 
		    warn 'setting isa _html_settings. ' if $t; 
		    
            if($self->{cached_settings}->{_cached_all_settings} == 1) {
                warn 'all settings are cached, but the saved value seems to be blank!' if $t;  
                # Guess it's... blank. 
                return ''; 
		    }
		    else { 
		        warn 'removing cache' if $t; 
                $self->{cached_settings} = {}; 
                warn 'creating cache, with all vals' if $t;     
                $self->{cached_settings} = $self->get(-all_settings => 1); 
                warn 'setting that cache has all vals' if $t; 
                $self->{_cached_all_settings} = 1; 
                warn 'returning val for, ' . $name if $t; 
                return $self->{cached_settings}->{$name}; 
		    }
		}
		elsif($self->_email_message_setting($name)){ 
            if($self->{cached_settings}->{_cached_all_settings} == 1) {
                # Guess it's... blank. 
                return ''; 
		    }
		    else { 
                $self->{cached_settings} = {}; 
                $self->{cached_settings} = $self->get(-all_settings => 1); 
                $self->{_cached_all_settings} = 1; 
                return $self->{cached_settings}->{$name}; 
		    }
		}
		elsif(! exists($self->{cached_settings}->{$name}) ) { 
		    carp "Cannot fill in value for, '$name'";
			return undef; 
		}
		else { 
		    return ''; 
		}
	}
}

sub _html_settings {
    return {
        html_confirmation_message         => 1,
        html_subscribed_message           => 1,
        html_unsubscribed_message         => 1,
        html_subscription_request_message => 1,
    };
}

sub _fill_in_html_settings { 
    my $self = shift;
	my $name = shift; 
	
	my $message_settings = { 
        html_confirmation_message         => 'confirmation.tmpl',
        html_subscription_request_message => 'subscription_request.tmpl',	    
        html_subscribed_message           => 'subscribed.tmpl',
        html_unsubscribed_message         => 'unsubscribed.tmpl',
	}; 
	
    if(exists($message_settings->{$name})) { 
        my $raw_screen = DADA::Template::Widgets::_raw_screen( { -screen => 'list/' . $message_settings->{$name} } );
        return $raw_screen; 
	}
	else { 
		return undef; 
	}
}

sub _email_message_settings {
    my $self = shift;
    return {
        mailing_list_message_from_phrase => 1,
        mailing_list_message_to_phrase   => 1,
        mailing_list_message_subject     => 1,
        mailing_list_message             => 1,
        mailing_list_message_html        => 1,

        digest_message_subject           => 1, 
        digest_message                   => 1, 
        digest_message_html              => 1, 
        
        confirmation_message_subject => 1,
        confirmation_message         => 1,

        subscribed_message_subject => 1,
        subscribed_message         => 1,

        unsubscribed_message_subject => 1,
        unsubscribed_message         => 1,

        invite_message_from_phrase => 1,
        invite_message_to_phrase   => 1,
        invite_message_text        => 1,
        invite_message_html        => 1,
        invite_message_subject     => 1,

        subscribed_by_list_owner_message         => 1,
        subscribed_by_list_owner_message_subject => 1,

        unsubscribed_by_list_owner_message_subject => 1,
        unsubscribed_by_list_owner_message         => 1,

        you_are_not_subscribed_message_subject => 1,
        you_are_not_subscribed_message         => 1,

        send_archive_message_subject => 1,
        send_archive_message         => 1,
        send_archive_message_html    => 1,

        you_are_already_subscribed_message_subject => 1,
        you_are_already_subscribed_message         => 1,

        admin_subscription_notice_message_subject => 1,
        admin_subscription_notice_message         => 1,

        admin_unsubscription_notice_message_subject => 1,
        admin_unsubscription_notice_message         => 1,

        not_allowed_to_post_msg_subject => 1,
        not_allowed_to_post_msg         => 1,

        invalid_msgs_to_owner_msg_subject => 1,
        invalid_msgs_to_owner_msg         => 1,

        moderation_msg_subject => 1,
        moderation_msg         => 1,

        await_moderation_msg_subject => 1,
        await_moderation_msg         => 1,

        accept_msg_subject => 1,
        accept_msg         => 1,

        rejection_msg_subject => 1,
        rejection_msg         => 1,

        msg_too_big_msg_subject => 1,
        msg_too_big_msg => 1,

        msg_received_msg_subject => 1,
        msg_received_msg => 1,

        msg_labeled_as_spam_msg_subject => 1,
        msg_labeled_as_spam_msg         => 1,

        subscription_approval_request_message_subject => 1,
        subscription_approval_request_message         => 1,

        subscription_request_approved_message_subject => 1,
        subscription_request_approved_message         => 1,

        subscription_request_denied_message_subject => 1,
        subscription_request_denied_message         => 1,

        unsubscription_approval_request_message_subject => 1,
        unsubscription_approval_request_message         => 1,

        unsubscription_request_approved_message_subject => 1,
        unsubscription_request_approved_message         => 1,

        unsubscription_request_denied_message_subject => 1,
        unsubscription_request_denied_message         => 1,

    };
}

sub _email_message_setting {
    my $self             = shift;
    my $name             = shift;    
    my $message_settings = $self->_email_message_settings();
    if ( exists( $message_settings->{$name} ) ) {
        # warn "it's there!"; 
        return 1;
    }
    else {
        # warn "it's not there!";      
        return 0;
    }
}




sub _fill_in_email_message_settings { 
	my $self = shift;
	my $name = shift; 
	
	my $message_settings = {

		mailing_list_message_from_phrase            => {-tmpl => 'mailing_list_message.eml', -part => 'from_phrase'}, 
		mailing_list_message_to_phrase              => {-tmpl => 'mailing_list_message.eml', -part => 'to_phrase'}, 
		mailing_list_message_subject                => {-tmpl => 'mailing_list_message.eml', -part => 'subject'}, 
		mailing_list_message                        => {-tmpl => 'mailing_list_message.eml', -part => 'plaintext_body'}, 
		mailing_list_message_html                   => {-tmpl => 'mailing_list_message.eml', -part => 'html_body'}, 

        digest_message_subject                      => {-tmpl => 'digest_message.eml', -part => 'subject'}, 
        digest_message                              => {-tmpl => 'digest_message.eml', -part => 'plaintext_body'}, 
        digest_message_html                         => {-tmpl => 'digest_message.eml', -part => 'html_body'}, 

		confirmation_message_subject                => {-tmpl => 'confirmation_message.eml', -part => 'subject'},  
        confirmation_message                        => {-tmpl => 'confirmation_message.eml', -part => 'plaintext_body'},  

        subscribed_message_subject                  => {-tmpl => 'subscribed_message.eml', -part => 'subject'},  
        subscribed_message                          => {-tmpl => 'subscribed_message.eml', -part => 'plaintext_body'},  

        unsubscribed_message_subject                => {-tmpl => 'unsubscribed_message.eml', -part => 'subject'},  
        unsubscribed_message                        => {-tmpl => 'unsubscribed_message.eml', -part => 'plaintext_body'},  

        invite_message_from_phrase                  => {-tmpl => 'invite_message.eml', -part => 'from_phrase'}, 
        invite_message_to_phrase                    => {-tmpl => 'invite_message.eml', -part => 'to_phrase'}, 
        invite_message_subject                      => {-tmpl => 'invite_message.eml', -part => 'subject'}, 
        invite_message_text                         => {-tmpl => 'invite_message.eml', -part => 'plaintext_body'}, 
        invite_message_html                         => {-tmpl => 'invite_message.eml', -part => 'html_body'}, 

        subscribed_by_list_owner_message_subject    => {-tmpl => 'subscribed_by_list_owner_message.eml', -part => 'subject'},  
        subscribed_by_list_owner_message            => {-tmpl => 'subscribed_by_list_owner_message.eml', -part => 'plaintext_body'},  

        unsubscribed_by_list_owner_message_subject  => {-tmpl => 'unsubscribed_by_list_owner_message.eml', -part => 'subject'},  
        unsubscribed_by_list_owner_message          => {-tmpl => 'unsubscribed_by_list_owner_message.eml', -part => 'plaintext_body'},  

        you_are_not_subscribed_message_subject      => {-tmpl => 'you_are_not_subscribed_message.eml', -part => 'subject'},  
        you_are_not_subscribed_message              => {-tmpl => 'you_are_not_subscribed_message.eml', -part => 'plaintext_body'},  

        send_archive_message_subject                => {-tmpl => 'send_archive_message.eml', -part => 'subject'},  
        send_archive_message                        => {-tmpl => 'send_archive_message.eml', -part => 'plaintext_body'},  
        send_archive_message_html                   => {-tmpl => 'send_archive_message.eml', -part => 'html_body'}, 

        you_are_already_subscribed_message_subject  => {-tmpl => 'you_are_already_subscribed_message.eml', -part => 'subject'},
        you_are_already_subscribed_message          => {-tmpl => 'you_are_already_subscribed_message.eml', -part => 'plaintext_body'},

        admin_subscription_notice_message_subject   => {-tmpl => 'admin_subscription_notice_message.eml', -part => 'subject'},
        admin_subscription_notice_message           => {-tmpl => 'admin_subscription_notice_message.eml', -part => 'plaintext_body'}, 


        admin_unsubscription_notice_message_subject => {-tmpl => 'admin_unsubscription_notice_message.eml', -part => 'subject'},
        admin_unsubscription_notice_message         => {-tmpl => 'admin_unsubscription_notice_message.eml', -part => 'plaintext_body'}, 

        not_allowed_to_post_msg_subject             => {-tmpl => 'not_allowed_to_post_msg.eml', -part => 'subject'},
        not_allowed_to_post_msg                     => {-tmpl => 'not_allowed_to_post_msg.eml', -part => 'plaintext_body'}, 

        invalid_msgs_to_owner_msg_subject           => {-tmpl => 'invalid_msgs_to_owner_msg.eml', -part => 'subject'},   
        invalid_msgs_to_owner_msg                   => {-tmpl => 'invalid_msgs_to_owner_msg.eml', -part => 'plaintext_body'}, 
        
        moderation_msg_subject                      => {-tmpl => 'moderation_msg.eml', -part => 'subject'},    
        moderation_msg                              => {-tmpl => 'moderation_msg.eml', -part => 'plaintext_body'},  

        await_moderation_msg_subject                =>   {-tmpl => 'await_moderation_msg.eml', -part => 'subject'},    
        await_moderation_msg                        =>   {-tmpl => 'await_moderation_msg.eml', -part => 'plaintext_body'},  
        
        accept_msg_subject                          => {-tmpl => 'accept_msg.eml', -part => 'subject'},    
        accept_msg                                  => {-tmpl => 'accept_msg.eml', -part => 'plaintext_body'},    

        rejection_msg_subject                       => {-tmpl => 'rejection_msg.eml', -part => 'subject'},  
        rejection_msg                               => {-tmpl => 'rejection_msg.eml', -part => 'plaintext_body'}, 
        
        msg_too_big_msg_subject                     =>   {-tmpl => 'msg_too_big_msg.eml', -part => 'subject'},    
        msg_too_big_msg                             =>   {-tmpl => 'msg_too_big_msg.eml', -part => 'plaintext_body'}, 
        
        msg_received_msg_subject                    => {-tmpl => 'msg_received_msg.eml', -part => 'subject'},  
        msg_received_msg                            =>   {-tmpl => 'msg_received_msg.eml', -part => 'plaintext_body'}, 
        
        msg_labeled_as_spam_msg_subject             => {-tmpl => 'msg_labeled_as_spam_msg.eml', -part => 'subject'},   
        msg_labeled_as_spam_msg                     => {-tmpl => 'msg_labeled_as_spam_msg.eml', -part => 'plaintext_body'},
        
        subscription_approval_request_message_subject    => {-tmpl => 'subscription_approval_request_message.eml', -part => 'subject'},   
        subscription_approval_request_message            => {-tmpl => 'subscription_approval_request_message.eml', -part => 'plaintext_body'},,
          
         subscription_request_approved_message_subject   => {-tmpl => 'subscription_request_approved_message.eml', -part => 'subject'},   
         subscription_request_approved_message           => {-tmpl => 'subscription_request_approved_message.eml', -part => 'plaintext_body'},   

         subscription_request_denied_message_subject     => {-tmpl => 'subscription_request_approved_message.eml', -part => 'subject'},   
         subscription_request_denied_message             => {-tmpl => 'subscription_request_approved_message.eml', -part => 'plaintext_body'},   
          
         unsubscription_approval_request_message_subject => {-tmpl => 'unsubscription_approval_request_message.eml', -part => 'subject'},   
         unsubscription_approval_request_message         => {-tmpl => 'unsubscription_approval_request_message.eml', -part => 'plaintext_body'},   
         
         unsubscription_request_approved_message_subject => {-tmpl => 'unsubscription_request_approved_message.eml', -part => 'subject'}, 
         unsubscription_request_approved_message         => {-tmpl => 'unsubscription_request_approved_message.eml', -part => 'plaintext_body'},   
         
         unsubscription_request_denied_message_subject   => {-tmpl => 'unsubscription_request_denied_message.eml', -part => 'subject'}, 
         unsubscription_request_denied_message           => {-tmpl => 'unsubscription_request_denied_message.eml', -part => 'plaintext_body'}, 
	}; 
	
	if(exists($message_settings->{$name})) { 
		my $f_settings = $self->_get_email_message_settings($message_settings->{$name}->{'-tmpl'}); 
		# warn '$f_settings->{$message_settings->{$name}->{-part}} ' . $f_settings->{$message_settings->{$name}->{-part}}; 
		return $f_settings->{$message_settings->{$name}->{-part}};
	}
	else { 
		return undef; 
	}
}



sub _get_email_message_settings {

    my $self = shift;
    my $tmpl = shift;

    require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    return $rm->read_message($tmpl); 

}

# This has got to go! 
sub x_message_body_content { 
	my $self = shift; 
	my $type = shift || undef; 
	die '$type cannot be undef!' 
		if $type eq undef;  
	my $param_name = ''; 
	if($type =~ m/html/i){ 
		$param_name = 'default_html_message_content'
	}
	else { 
		$param_name = 'default_plaintext_message_content'; 
	}
	
	my $str = '';
	if($self->param($param_name . '_src') eq 'url_or_path'){ 
		if(isa_url($self->param($param_name . '_src_url_or_path'))){ 
			grab_url($self->param($param_name . '_src_url_or_path'));
		}
		elsif(-e $self->param($param_name . '_src_url_or_path')){ 
			my $fn = make_safer($self->param($param_name . '_src_url_or_path')); 
			my $d = undef; 
			eval { $d  = slurp($fn); }; 
			if($@){ 
				carp $@;
				return '';  
			}
			else { 
				return $d; 
			}
		}
		else { # 'default'
			return ''; 
		}
	}
	else { 
		my $fn; 
		if($type =~ m/html/i){ 
			$fn = $DADA::Config::TEMPLATES . '/' . $param_name . '-' . $self->{name} . '.html'; 
		}
		else { 
			$fn = $DADA::Config::TEMPLATES . '/' . $param_name . '-' . $self->{name} . '.txt'; 
		}
		$fn = make_safer($fn);  
		if(-e $fn){
			eval { $str = slurp($fn); }; 
			if($@){ 
				carp $@;
				return '';  
			}
			else { 
				return $str; 
			}
		} 
		return $str
	}

}
sub plaintext_message_body_content { 
	my $self = shift; 
	return $self->x_message_body_content('plaintext');
}
sub html_message_body_content { 
	my $self = shift; 
	return $self->x_message_body_content('html');
}


sub save_w_params {

    my $self      = shift;
    my ($args)    = @_;
    my $associate = undef;
    my $settings  = {};

    if ( !exists( $args->{-associate} ) ) {
        croak(
'you\'ll need to pass a Perl object with a compatible, param() method in "-associate"'
        );
    }
    if ( !exists( $args->{-settings} ) ) {
        croak(
'you\'ll need to pass what you want to save in the, "-settings" param as a hashref'
        );
    }

    $associate = $args->{-associate};
    $settings  = $args->{-settings};

    my $saved_settings = {};

    for my $setting (keys %$settings) {

        # is it here?
        if ( defined( $associate->param($setting) ) ) {
			if($associate->param($setting) ne '') { 
            	$saved_settings->{$setting} = $associate->param($setting);
			}
			else { 
            	$saved_settings->{$setting} = $settings->{$setting};				
			}
        }
        else {

            # fallback
			# not checking for defined-ness here, since the value could be, "undef"
            $saved_settings->{$setting} = $settings->{$setting};
        }

        # This is probably a good place to check that the variable is actually
        # a valid value.
    }

#	use Data::Dumper; 
#	croak Data::Dumper::Dumper($saved_settings); 

    return $self->save($saved_settings);
	
}





sub _existence_check { 

    my $self = shift; 
    my $li   = shift; 
    for(keys %$li){ 
        if(!exists($DADA::Config::LIST_SETUP_DEFAULTS{$_})){         
            croak("Attempt to save a unregistered setting: '$_'"); 
        }
    }
}




sub _munge_charset { 
	my ($self, $li) = @_;
	
	
	if(!exists($li->{charset})){ 
	   $li->{charset} =  $DADA::Config::LIST_SETUP_DEFAULTS{charset};
	    
	}
	
	my $charset_info = $li->{charset};
	my @labeled_charsets = split(/\t/, $charset_info);	
	return $labeled_charsets[$#labeled_charsets];      

}



sub _munge_for_deprecated { 
	
	my ($self, $li) = @_; 
	$li->{list_owner_email} ||= $li->{mojo_email};
#    $li->{admin_email}      ||= $li->{list_owner_email}; 
  
    $li->{privacy_policy}   ||= $li->{private_policy};
  
	#we're talkin' way back here..
	
	if(!exists($li->{list_name})){ 
		$li->{list_name} = $li->{list}; 
		$li->{list_name} =~ s/_/ /g;
	}
	
	return $li; 
}




sub _trim { 
	my ($self, $s) = @_;
	return DADA::App::Guts::strip($s);
}



sub _dd_freeze {
    my $self = shift;
    my $data = shift;

    require Data::Dumper;
    my $d = new Data::Dumper( [$data], ["D"] );
    $d->Indent(0);
    $d->Purity(1);
    $d->Useqq(0);
    $d->Deepcopy(0);
    $d->Quotekeys(1);
    $d->Terse(0);

    # ;$D added to make certain we get our data structure back when we thaw
    return $d->Dump() . ';$D';

}

sub _dd_thaw {

    my $self = shift;
    my $data = shift;

    # To make -T happy
    my ($safe_string) =  $data =~ m/^(.*)$/s;
    $safe_string = 'my ' . $safe_string; 
    my $rv = eval($safe_string);
    if ($@) {
        croak "couldn't thaw data! - $@\n" . $data;
    }
    return $rv;
}







1; 

=head1 NAME

DADA::MailingList::Subscribers - API for the Dada Mailing List Settings

=head1 SYNOPSIS

 # Import
 use DADA::MailingList::Settings; 
 
 # Create a new object
  my $ls = DADA::MailingList::Settings->new(
           		{ 
					-list => $list, 
				}
			);
 
	# A hashref of all settings
	my $li = $ls->get; 
	print $li->{list_name}; 
 	
 
 
	# Save a setting
	$ls->save(
		{
			list_name => "my list", 
		}
	);
 
 # save a setting, from a CGI parameter, with a fallback variable: 
 $ls->save_w_params(
	-associate => $q, # our CGI object
	-settings  => { 
		list_name => 'My List', 
	}
 ); 
 
 
  # get one setting
  print $ls->param('list_name'); 
 
 
 
 #save one setting: 
 $ls->param('list_name', "My List"); 
  
 
 # Another way to get all settings
 my $li = $ls->params; 


=head1 DESCRIPTION

This module represents the API for Dada Mail's List Settings. Each DADA::MailingList::Settings object represents ONE list. 

Dada Mail's list settings are basically the saved values and preferences that 
make up the, "what" of your Dada Mail list. The settings hold things like the name of your list, the description, as well as things like email sending options.  

=head2 Mailing List Settings Model

Settings are saved in a key/value pair, as originally, the backend for all this was a dn file - and still is, for the default backend. This module basically manipulates that key/value hash. Very simple. 

=head2 Default Values of List Settings

The default value of B<ALL> list settings are saved currently in the I<Config.pm> file, in the variable, C<%LIST_SETUP_DEFAULTS>

This module will make sure you will not attempt to save an unknown list setting in the C<save> method, as well when calling C<param> with either one or two arguments. 

The error will be fatal. This may seem rash, but many bugs surface just because of trying to use a list setting that does not actually exist. 

The C<get> method is NOT guaranteed to give back valid list settings! This is a known issue and may be fixed later, after backwards-compatibility problems are assessed. 

=head1 Public Methods

Below are the list of I<Public> methods that we recommend using when manipulating the  Dada Mail List Settings: 

=head2 Initializing

=head2 new

 my $ls = DADA::MailingList::Settings->new({-list => 'mylist'}); 

C<new> requires you to pass a B<listshortname> in, C<-list>. If you don't, your script will die. 

A C<DADA::MailingList::Settings> object will be returned. 

=head2 Getting/Setting Mailing List Paramaters

=head2 get

 my $li = $ls->get; 

There are no public parameters that we suggest passing to this method. 

This method returns a hashref that contains each and every key/value pair of settings associated with the mailing list you're working with.

This method will grab a fresh copy of the list settings from whatever backend is being used. Because of this, we suggest that instead of using this method, you use the, C<param> or C<params> method, which has caching of this information.  

=head3 Diagnostics

None, really. 

=head2 save

 $ls->save({list_name => 'my new list name'}); 

C<save> accepts a hashref as a parameter. The hashref should contain key/value pairs of list settings you'd like to change. All key/values passed will re-write any options saved. There is no validation of the information you passed. 

DO NOT pass, I<list> as one of the key/value pairs. The method will return an error. 

This method is most convenient when you have many list settings you'd like saved at one time. See the, C<param> method if all you want to do is save one list setting parameter. 

Returns B<1> on success. 


=head2 save_w_params

 $ls->save_w_params(
	-associate => $q, # our CGI object
	-settings  => { 
		list_name => 'My List', 
	}
 ); 

C<save_w_params> allows you to save list settings that are passed in a compatible Perl object (one that has a C<param> method, similar to CGI.pm's)

C<save_w_params> also allows you to pass a fallback value of the list settings you want to save. 

C<-associate> should hold a Perl Object with the compatable, C<param> method (like CGI.pm's C<param> method. B<required> 

C<-settings> should hold a hashref of the fallback values for each list setting you want to save. 

Returns, C<1> on success. 

=head3 Diagnostics

=over

=item * Attempt to save a unregistered setting - 

The actual settings you attempt to save have to actually exist. Make sure the names (keys) of your the list settings you're attempting to pass are valid. 


=back


=head2 param

 # Get a Value
 $ls->param('list_name'); 
 
 # Save a Value
 $ls->param('list_name', 'my new list name'); 

C<param> can be used to get and save  a list setting parameter. 

Call C<param> with one argument to receive the value of the name of the setting you're passing. 

Call C<param> with two arguments - the first being the name of the setting, the second being the value you'd like to save. 

C<param> is something of a wrapper around the C<get> method, but we suggest using C<param> over, C<get> as, C<param> checks the validity of the list setting B<name> that you pass, as well as caching information you've already fetched from the backend.

=head3 Diagnostics

=over

=item * You MUST pass a name as the first argument!

You cannot call, C<param> without an argument. That first argument needs to be the name of the list setting you want to get/set. 

=item * Cannot call param() on unknown setting.

If you do call C<param> with 2 arguments, the first argument has to be the name of a setting tha actual exists. 

=back

For the two argument version of calling this method, also see the, I<Diagnostics> section of the, C<save> method. 

=head2 params

	my $li = $ls->params;

Takes no arguments. 

Returns the exact same thing as the, C<get> method, except does caching of any information fetched from the backend. Because of this, it's suggested that you use C<params>, instead of, C<get> whenever you can. 

=head2 A note about param and params

The name, C<param> and, C<params> is taken from the CGI.pm module: 

Many different modules support passing parameter values to their own methods, as a sort of shortcut. We had this in mind, but we haven't used or tested how compatible this idea is. When and if we do, we'll update the documentation to reflect this. 

=head1 BUGS AND LIMITATIONS

=head1 COPYRIGHT 

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
