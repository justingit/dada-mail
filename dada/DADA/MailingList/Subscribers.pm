package DADA::MailingList::Subscribers;

use lib qw(
	../../
	../../DADA/perllib
);


use Carp qw(carp croak);
my $type;
my $backend;  
use DADA::Config qw(!:DEFAULT); 	
BEGIN { 
	$type = $DADA::Config::SUBSCRIBER_DB_TYPE;
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
	elsif($type eq 'PlainText'){ 
		$backend = 'PlainText'; 
	}
	else { 
		die "Unknown \$SUBSCRIBER_DB_TYPE: '$type' Supported types: 'PlainText', 'SQL'"; 
	}
}

use strict; 

use base "DADA::MailingList::Subscribers::$backend";
use DADA::App::Guts;
use DADA::MailingList::Subscriber; 
use DADA::MailingList::Subscriber::Validate;
use DADA::Profile::Fields; 
use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;


sub new {

	my $class  = shift;
	my ($args) = @_; 

	my $self = {};			
	bless $self, $class;
	$self->_init($args); 
	return $self;

}





sub _init  { 

    my $self = shift; 

	my ($args) = @_; 

	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings;		 
		$self->{ls} = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$self->{ls} = $args->{-ls_obj};
	}
	
	if(exists($args->{-dpfm_obj})){ 
		$self->{-dpfm_obj} = $args->{-dpfm_obj};
	}
	else {
		#$self->{-dpfm_obj} = $args->{-dpfm_obj} = undef; 
	}
	
    $self->{'log'}      = DADA::Logging::Usage->new;
    $self->{list}       = $args->{-list};

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    	
	if($DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/){ 
	
		require DADA::App::DBIHandle; 
		my $dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}
	
	if(exists($args->{-dpfm_obj})){ 
		$self->{fields}   = DADA::Profile::Fields->new(
			{
				-dpfm_obj => $args->{-dpfm_obj},
			}
		); 		
		
	}
	else { 
		$self->{fields}   = DADA::Profile::Fields->new; 		
	}

	$self->{validate} = DADA::MailingList::Subscriber::Validate->new({-list => $self->{list}, -lh_obj => $self}); 		
}



sub add_subscriber {

    my $self = shift;
	my ($args) = @_;
	$args->{-list} = $self->{list};
	if(exists($self->{-dpfm_obj})){ 
		$args->{-dpfm_obj} = $self->{-dpfm_obj}; 
	}
    return DADA::MailingList::Subscriber->add( $args );
}



sub quota_limit { 
    my $self = shift; 
    my $quota_limit = undef;
    if ( $type eq 'list' ) {
        if ( $self->{ls}->param('use_subscription_quota') == 1 ) {
            $quota_limit = $self->{ls}->param('subscription_quota');
        }
        elsif ( defined($DADA::Config::SUBSCRIPTION_QUOTA)
            && $DADA::Config::SUBSCRIPTION_QUOTA > 0 )
        {
            $quota_limit = $DADA::Config::SUBSCRIPTION_QUOTA;
        }
    }
    return $quota_limit; 
    
}

sub add_subscribers { 
    
    my $self   = shift; 
    my ($args) = @_; 
    
    my $addresses           = $args->{-addresses};
    my $added_addresses     = []; 
    my $type                = $args->{-type}; 
    if(!exists($args->{-fields_options_mode})){ 
        $args->{-fields_options_mode} = 'preserve_if_defined';
    }
    
    my $num_subscribers     = $self->num_subscribers;
    my $new_total           = $num_subscribers; 
    my $quota_limit         = $self->quota_limit; 
    my $new_email_count     = 0; 
    my $skipped_email_count = 0; 
    
    # Each Address is a CSV line...
    for my $info (@$addresses) {

        my $dmls = undef;

        if (   $type eq 'list'
            && defined($quota_limit)
            && $new_total >= $quota_limit )
        {
            $skipped_email_count++;
        }
        else {
            my $pf_om   = 'preserve_if_defined'; 
            my $pass_om = 'preserve_if_defined'; 

            if($args->{-fields_options_mode} eq 'writeover_ex_password'){ 
                $pf_om   = 'writeover'; 
                $pass_om = 'preserve_if_defined'; 
            }
            elsif($args->{-fields_options_mode} eq 'writeover_inc_password'){ 
                $pf_om   = 'writeover'; 
                $pass_om = 'writeover'; 
            }
            
            $dmls = $self->add_subscriber(
                {
                    -email             => $info->{email},
                    -fields            => $info->{fields},
                    -profile           => { 
                        -password => $info->{profile}->{password}, 
                        -mode     => $args->{-fields_options_mode}, 
                    },
                    -type              => $type,
                    -fields_options    => { -mode => $args->{-fields_options_mode}, },
                    -dupe_check        => {
                        -enable  => 1,
                        -on_dupe => 'ignore_add',
                    },
                }
            );                         
            $new_total++;
            if ( defined($dmls) ) {    # undef means it wasn't added.
                $new_email_count++;
                push(@$added_addresses, $info); 
            }
            else {
                $skipped_email_count++;
            }
        }
    }
    
    undef($addresses); 
    
    if ( $type eq 'list' ) {
        if ( $self->{ls}->param('send_subscribed_by_list_owner_message') == 1 ) {
            require DADA::App::MassSend;
            eval {
                
                # DEV: 
                # This needs to send the Profile Password, if it's known. 
                #
                require DADA::App::MassSend;
                DADA::App::MassSend::just_subscribed_mass_mailing(
                    {
                        -list      => $self->{list},
                        -addresses => $added_addresses,
                    }
                );
            };
            if ($@) {
                carp $@;
            }
        }
        if ( $self->{ls}->param('send_last_archived_msg_mass_mailing') == 1 ) {
            eval {
                require DADA::App::MassSend;
                DADA::App::MassSend::send_last_archived_msg_mass_mailing(
                    {
                        -list      => $self->{list},
                        -addresses => $added_addresses,
                    }
                );
            };
            if ($@) {
                carp $@;
            }
        }
    }

    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} == 1
        && $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ )
    {
        eval {
            require DADA::Profile::Htpasswd;
            my $htp = DADA::Profile::Htpasswd->new( { -list =>$self->{list} } );
            for my $id ( @{ $htp->get_all_ids } ) {
                $htp->setup_directory( { -id => $id } );
            }
        };
        if ($@) {
            warn "Problem updated Password Protected Directories: $@";
        }
    }
    
    return ($new_email_count, $skipped_email_count); 
    
}





sub get_subscriber {
    my $self   = shift;
    my ($args) = @_;
	$args->{-list} = $self->{list};
    my $dmls =
      DADA::MailingList::Subscriber->new($args);
    return $dmls->get($args);

}




sub move_subscriber {
    my $self = shift;
    my ($args) = @_;
	$args->{-list} = $self->{list};
	$args->{-type} = $args->{-from};
    my $dmls =
      DADA::MailingList::Subscriber->new( $args );

    return $dmls->move($args);
	
}
sub edit_subscriber { 
	my $self = shift;
    my ($args) = @_;
	$args->{-list} = $self->{list};
    my $dmls =
      DADA::MailingList::Subscriber->new( $args );
   return $dmls->edit($args);
   
}




sub copy_subscriber { 
	my $self = shift;
    my ($args) = @_;
	$args->{-list} = $self->{list};
	$args->{-type} = $args->{-from};
	
    my $dmls =
      DADA::MailingList::Subscriber->new( $args );
    return $dmls->copy($args);
}

sub member_of { 
	my $self = shift; 
	my ($args) = @_;
	$args->{-list} = $self->{list};
	
 my $dmls =
      DADA::MailingList::Subscriber->new( $args );
    return $dmls->member_of($args);	
}

sub also_subscribed_to { 
	
	my $self = shift; 
	my ($args) = @_; 
	
	my @lists = (); 
	if(! exists($args->{-types})){ 
		$args->{-types} = [qw(list)];
	}
	
	
	LIST: foreach my $list(available_lists()){ 

		next
			if $list eq $self->{list};	

		my $temp_lh = DADA::MailingList::Subscribers->new({-list => $list});
				
		for my $type(@{$args->{-types}}){ 
			if($temp_lh->check_for_double_email(
		        -Email => $args->{ -email },
		        -Type  => $type
		    ) == 1){
				push(@lists, $list); 
				undef $temp_lh;
				next LIST; 
			}
		}
		undef $temp_lh;
	}
	
	return @lists; 
}



sub admin_remove_subscribers { 
	
	my $self = shift; 
	my ($args) = @_; 
	
	my $addresses = $args->{-addresses}; 
	if(! exists($args->{-type})){ 
		croak "you MUST pass the, '-type' parameter!"; 
	}
	my $type      = $args->{-type};

	my $d_count = 0; 
	for my $address(@$addresses){ 
		my $c = $self->remove_subscriber(
			{ 
				-email             => $address, 
				-type              => $type, 
				-validation_check  => 0, 
			}
		); 
		$d_count = $d_count + $c; 
	}

	my $bl_count = 0; 
	if($type eq 'list' || $type eq 'bounced_list'){
				
	    if($self->{ls}->param('black_list')               == 1 &&
	       $self->{ls}->param('add_unsubs_to_black_list') == 1
	       ){
			
			for(@$addresses){
				my $a = $self->add_subscriber(
					{
						-email => $_,
						-type  => 'black_list',
						-dupe_check    => {
											-enable  => 1,
											-on_dupe => 'ignore_add',
	                					},
					}
				);
				if(defined($a)){ 
					$bl_count++;
				}
			}
	    }
	}

	if($type eq 'list') { 
		if($self->{ls}->param('send_unsubscribed_by_list_owner_message') == 1){
			require DADA::App::MassSend; 
			eval { 
				DADA::App::MassSend::just_unsubscribed_mass_mailing(
					{ 
						-list      => $self->{list}, 
						-addresses => $addresses, 
					}	
				); 
			};
			if($@){ 
				carp $@; 
			}	
		}
	}
	
	
	return($d_count, $bl_count); 
		
}



sub admin_update_address { 

	my $self = shift; 
	my ($args) = @_; 
	
	my $addresses = $args->{-addresses}; 
	if(! exists($args->{-type})){ 
		croak "you MUST pass the, '-type' parameter!"; 
	}
	my $type          = $args->{-type};
	my $email         = $args->{-email}; 
	my $updated_email = $args->{-updated_email}; 

	my $og_prof = undef; 
	
	if($self->can_have_subscriber_fields) { 
		require DADA::Profile; 
		$og_prof = DADA::Profile->new({-email => $email}); 	
	}
		
	# Switch the addresses around

	require DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;

	$self->remove_subscriber(
		{
			-email  => cased($email),
			-type   => $type, 
			-log_it => 0, 
		}
	);
	$self->add_subscriber(
		{
			-email  => cased($updated_email), 
			-type   => $type, 
			-log_it => 0,
		}
	);
	$log->mj_log(
		 $self->{list}, 
		'Updated Subscription for ' .  $self->{list} . '.' . $type,  
		$email . ':' . $updated_email
	);
	
	
	# PROFILES
	
	if(! $self->can_have_subscriber_fields) { 
	
	}
	else { 
		
		# JUST one list? 
		# it gets a little crazy... 
	
		# Basically what we want to do is this: 
		# If the OLD address is subscribed to > 1 list, don't mess with the current
		# profile information, 
		# If the NEW address already has profile information, do not overwrite it
		# 

		# 
		my $og_subscriptions = $og_prof->subscribed_to({-type => 'list'}); 

		if(! $og_prof->exists){ 
			# Make one (old email) 
			$og_prof->insert({
			    -password  => $og_prof->_rand_str(8),
			    -activated => 1,
			}); 
		}

		# Is there another mailing list that has the old address as a subscriber? 
		# Remember, we already changed over ONE of the subscriptions. 

		if(scalar(@$og_subscriptions) >= 1){ 
	
			my $updated_prof = DADA::Profile->new({-email => $updated_email});
			# This already around? 
			if($updated_prof->exists){ 
		
				# Got any information? 
				if($updated_prof->{fields}->are_empty){ 
			
					# No info in there yet? 
					$updated_prof->{fields}->insert({
						-fields => $og_prof->{fields}->get, 
						-mode   => 'writeover', 
					}); 		
				}
			}
			else {
		
				# So there's not a profile, yet? 
				# COPY (don't move) the old profile info, 
				# to the new profile
				# (inludeds fields) 
				my $new_prof = $og_prof->copy({ 
					-from => $email, 
					-to   => $updated_email, 
				}); 
			}
		}
		else { 
	
			# So, no other mailing list has a subscription for the new email address
			# 
			my $updated_prof = DADA::Profile->new({-email => $updated_email});
			# But does this profile already exists for the updated address? 
			
			if($updated_prof->exists){ 
		
				 # Well, nothing, since it already exists.
			}
			else { 
		
				# updated our old email profile, to the new email 
				# Only ONE subscription, w/Profile
				# First save the updated email
				
				$og_prof->update({ 
					-activated      => 1, 
					-update_email	=> $updated_email, 
				}); 
				# Then this method changes the updated email to the email..
				# And changes the profiles fields, as well... 
				$og_prof->update_email;		
			}
		}
		# so, the old prof have any subscriptions? 
		my $old_prof = DADA::Profile->new({-email => $email}); 
		if($old_prof->exists){ 
			# Again, this will only touch, "list" sublist...
			if(scalar(@{$old_prof->subscribed_to}) == 0) { 
				# Then we can remove it, 
				$old_prof->remove;
			}
		}
	}
	
	return 1; 
}





sub remove_subscriber { 
	my $self = shift;
    my ($args) = @_;

	if(exists($self->{-dpfm_obj})){ 
		$args->{-dpfm_obj} = $self->{-dpfm_obj}; 
	}
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }
		
    my $dmls =
      DADA::MailingList::Subscriber->new( { %{$args}, -list => $self->{list} } );
	$dmls->remove($args);
	return 1; 
}

sub columns { 
	my $self = shift; 
	return $self->{fields}->{manager}->columns; 
}
sub subscriber_fields { 
	my $self = shift; 
	return $self->{fields}->{manager}->fields(@_);
}
sub add_subscriber_field { 
	my $self = shift; 
	return $self->{fields}->{manager}->add_field(@_);
}
sub edit_subscriber_field_name { 
	my $self = shift; 
	return $self->{fields}->{manager}->edit_subscriber_field_name(@_);
}
sub remove_subscriber_field { 
	my $self = shift; 
	return $self->{fields}->{manager}->remove_field(@_);
}
sub subscriber_field_exists { 
	my $self = shift; 
	return $self->{fields}->{manager}->field_exists(@_);
}
sub validate_subscriber_field_name { 
	my $self = shift; 
	return $self->{fields}->{manager}->validate_field_name(@_);
}
sub get_all_field_attributes { 
	my $self = shift; 
	return $self->{fields}->{manager}->get_all_field_attributes(@_);
}




sub get_list_types {

	my $self = shift; 
	return { 
		list                => 1,       
		black_list          => 1, 
		authorized_senders  => 1, 
		moderators         => 1,
		testers             => 1, 
		white_list          => 1, 
		sub_confirm_list    => 1, 
		unsub_confirm_list  => 1, 
		invitelist          => 1,
		invited_list        => 1,  
		sub_request_list    => 1,
		unsub_request_list  => 1, 
		bounced_list        => 1,			
	};
	
}

sub allowed_list_types { 

    my $self = shift; 
    my $type = shift; 

    my $named_list_types = $self->get_list_types;
    
	if( exists( $named_list_types->{$type} ) ){ 
		return 1; 
	}
	elsif($type =~ m/_tmp(.*?)/){ 
			return 1; 
	}
	else { 
		return 0;
	}
   
}

sub subscription_check { 
	my $self = shift;
    my ($args) = @_;
    return $self->{validate}->subscription_check($args);
}

sub unsubscription_check {
	my $self = shift;
    my ($args) = @_;
    return $self->{validate}->unsubscription_check($args);

}



sub filter_subscribers {

    my $self = shift;
    my ($args) = @_;

    my $new_addresses = $args->{-emails};

    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }
    my $type = $args->{-type};

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    my $num_subscribers = $self->num_subscribers;

    my @good_emails = ();
    my @bad_emails  = ();

    for my $check_this_address (@$new_addresses) {

        my $errors = {};
        my $status = 1;

        # It's weird, because Black List and White List still have some sort of
        # format they have to follow. 
        # 
        if ( $type eq 'black_list' ) {
            # Yeah... nothing...
        }
        elsif ( $type eq 'white_list' ) {
            # Yeah... nothing...
        }
        else {
            if ( check_for_valid_email($check_this_address) == 1 ) {
                $errors->{invalid_email} = 1;
                $status = 0;
            }
            else {
                $errors->{invalid_email} = 0;
            }
        }
        
        if ( $type eq 'list' ) {
            if ( $ls->param('use_subscription_quota') == 1 ) {
                if ( ( $num_subscribers + 1 ) >= $ls->param('subscription_quota') ) {
                    $errors->{over_subscription_quota} = 1;
                    $status = 0;
                }
            }
            elsif (defined($DADA::Config::SUBSCRIPTION_QUOTA)
                && $DADA::Config::SUBSCRIPTION_QUOTA > 0
                && $num_subscribers + 1 >= $DADA::Config::SUBSCRIPTION_QUOTA )
            {
                $errors->{over_subscription_quota} = 1;
                $status = 0;
            }
        }
        if ( $status != 1 ) {
            push( @bad_emails, $check_this_address );
        }
        else {
            $check_this_address = lc_email($check_this_address);
            push( @good_emails, $check_this_address );
        }
    }

    # I've gotta do this twice, why not just once, before looking for validity? 
    #
    my %seen = ();
    my @unique_good_emails = grep { !$seen{$_}++ } @good_emails;

    %seen = ();
    my @unique_bad_emails = grep { !$seen{$_}++ } @bad_emails;

    # And then, sorting? 
    @unique_good_emails = sort(@unique_good_emails);
    @unique_bad_emails  = sort(@unique_bad_emails);

    # figure out what unique emails we have from the new list when compared to the old list
    # We do this, rather than "check_for_double_email" - I guess that's a optimization... 
    #
    my ( $unique_ref, $not_unique_ref ) = $self->unique_and_duplicate(
        -New_List => \@unique_good_emails,
        -Type     => $type,
    );

    #initialize
    my @black_list;
    my $found_black_list_ref   = [];
    my $clean_list_ref         = [];
    my $black_listed_ref       = [];
    my $black_list_ref         = [];
    my $white_listed           = [];
    my $not_white_listed       = [];
    
    # This is basically, "Are you blacklisted...", 
    # check_for_double_email will also do an inexact match, you tell it to, 
    # 
    #
    if ( $ls->param('black_list') == 1 && $type eq 'list' ) {
        for my $b_email (@$unique_ref) {
            my $is_black_listed = $self->inexact_match(
                {
                    -email   => $b_email,
                    -against => 'black_list',
                }
            );
            if ( $is_black_listed == 1 ) {
                push( @$found_black_list_ref, $b_email );
            }
        }

        ( $clean_list_ref, $black_listed_ref ) = $self->find_unique_elements( $unique_ref, $found_black_list_ref );

    }
    else {
        $clean_list_ref = $unique_ref;
    }

    # The entire white list stuff is pure messed.
    # This is basically, "Are you white listed...", 
    # check_for_double_email will also do an inexact match, you tell it to, 
    
    if ( $ls->param('enable_white_list') == 1 && $type eq 'list' ) {
        for my $w_email (@$clean_list_ref) {
            my $is_white_listed = $self->inexact_match(
                {
                    -email   => $w_email,
                    -against => 'white_list',
                }
            );
            if ( $is_white_listed == 1 ) {
                push( @$white_listed, $w_email );
            }

        }
        ( $not_white_listed, $clean_list_ref, ) =
          $self->find_unique_elements( $clean_list_ref, $white_listed )
          ;    # It probably doesn't matter what order I give these things in is
    }
    else {
        # nothing, really.
        $not_white_listed = [];
    }

    # $subscribed,         $not_subscribed,   $black_listed,    $not_white_listed,     $invalid
    return ( $not_unique_ref, $clean_list_ref, $black_listed_ref, $not_white_listed, \@unique_bad_emails );

}

sub filter_subscribers_w_meta { 

    # So, what are we doing about dupes? 

	my $self   = shift; 
	my ($args) = @_; 

	my $info = $args->{-emails}; 

	if(! exists($args->{-type})){ 
		$args->{-type} = 'list'; 
	}
	my $type = $args->{-type}; 

    my $dupe_check = {};

	my $emails = [];

	my $fields = $self->subscriber_fields(); 

	require   Text::CSV; 
	my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    for my $n_address(@{$info}){ 

        if(exists($dupe_check->{$n_address->{email}})){
            carp "already looked at: '"  . $n_address->{email} . "' - will not process twice!"; 
        }
        $dupe_check->{$n_address->{email}} = 1; 

        my ($status, $errors) = $self->subscription_check(
            {
                -email  => $n_address->{email},
                -type   => $type, 
                -mode   => 'admin', 
                -fields => $n_address->{fields},
                -skip   => [qw(
                    mx_lookup_failed
                    already_sent_sub_confirmation
                    already_sent_unsub_confirmation
                    over_subscription_quota
                    invite_only_list
                    )],
                -ls_obj => $ls, 
            }
        );
        my $csv_str = ''; 
        my $csv_fields = [$n_address->{email}]; 
        foreach(@$fields){ 
            push(@$csv_fields, $n_address->{fields}->{$_}); 
        }
        push(@$csv_fields, $n_address->{profile}->{password}); 
        
        if ($csv->combine(@$csv_fields)) {
	        $csv_str = $csv->string;
	    } else {
		    carp "well, that didn't work."; 
		}		
		
		# Put in the import limit, and check that before anything else.
		# Put in the pref's to enable/disable tests, like blacklist, whitelist, missing profile fields, etc
		
		# Ability to set Profile Password...
		
		# MAYBE put in pref - what to do with addresses that are already subscribed - update instead? 
		# "These addresses are already subscribed (check for Profile Fields if so...:) Update thier profiles? (Root Login only) 
		# 
		

        push(@$emails, {
                email    => $n_address->{email}, 
                fields   => $n_address->{fields}, 
                profile  => $n_address->{profile}, 
                status   => $status, 
                errors   => $errors, 
                csv_str  => $csv_str, 
                #%$ht_errors, 
            }
        ); 
    }
    return $emails; 
}


sub filter_subscribers_massaged_for_ht {
    my $self   = shift;
    my ($args) = @_;

    my $emails = $self->filter_subscribers_w_meta($args);

    my $new_emails = [];
    my $fields     = $self->subscriber_fields();

    for my $address (@$emails) {
        
        my $ht_fields = [];
        my $ht_errors = [];
        
        if(exists($address->{errors}->{invalid_profile_fields})) { 
            for my $field(@$fields) {
                if ( 
                    exists($address->{errors})
                 && exists($address->{errors}->{invalid_profile_fields}->{$field}) 
                 && exists( $address->{errors}->{invalid_profile_fields}->{$field}->{required} ) 
                 ) {
                    push(
                        @$ht_fields,
                        {
                            name                  => $field,
                            value                 => $address->{fields}->{$field},
                            invalid_profile_field => 1,
                        }
                    );
                }
                else {                
                    push(
                        @$ht_fields,
                        {
                            name  => $field,
                            value => $address->{fields}->{$field}
                        }
                    );
                }
            }
        }
        else { 
            for my $field(@$fields) {
                push(
                    @$ht_fields,
                    {
                        name  => $field,
                        value => $address->{fields}->{$field}
                    }
                );
            }
            
        }
        
        if(exists($address->{errors})){ 
            if(keys %{$address->{errors}}) { 
                for my $error( keys %{ $address->{errors} } ) {
                    push(
                        @$ht_errors,
                        {
                            name  => $error,
                            value => 1,
                        }
                    );
                }
            }
        }
        push(
            @$new_emails,
            {
                email              => $address->{email},
                profile_password   => $address->{profile}->{password},
                status             => $address->{status},
                og_errors          => $address->{errors},
                csv_str            => $address->{csv_str},
                
                errors             => $ht_errors,
                fields             => $ht_fields,
                
                # %$ht_errors,
            }
        );
    }
    undef($emails);

    my $not_members            = [];
    my $invalid_email          = [];
    my $subscribed             = [];
    my $black_listed           = [];
    my $not_white_listed       = [];
    my $invalid_profile_fields = [];

    for my $address (@$new_emails) {
        if ( $address->{status} == 1 ) {
            push( @$not_members, $address );
        }
        elsif ( $address->{og_errors}->{invalid_email} == 1 ) {
            push( @$invalid_email, $address );
        }
        elsif ( $address->{og_errors}->{subscribed} == 1 ) {
            push( @$subscribed, $address );
        }
        elsif ( $address->{og_errors}->{black_listed} == 1 ) {
            push( @$black_listed, $address );
        }
        elsif ( $address->{og_errors}->{not_white_listed} == 1 ) {
            push( @$not_white_listed, $address );
        }
        elsif ( exists( $address->{og_errors}->{invalid_profile_fields} ) ) {
            push( @$invalid_profile_fields, $address );
        }

    }

    return ( $not_members, $invalid_email, $subscribed, $black_listed, $not_white_listed, $invalid_profile_fields );
}




sub find_unique_elements { 

	my $self = shift; 
	
	my $A = shift || undef; 
	my $B = shift || undef; 
	
	if($A and $B){ 	
		#lookup table
		my %seen = ();     
		# we'll store unique things in here            
		my @unique = ();
		#we'll store what we already got in here
		my @already_in = ();                 
		# build lookup table
		for my $item (@$B) { $seen{$item} = 1 }
		# find only elements in @$A and not in @$B
		for my $item (@$A) {
			unless ($seen{$item}) {
				# it's not in %seen, so add to @aonly
				push(@unique, $item);
			}else{
				push(@already_in, $item);
				}
		}
		
		return (\@unique, \@already_in); 
	
	}else{ 
		carp 'I need two array refs!';
		return ([], []); 
	}
}




sub csv_to_cds { 
	my $self     = shift; 
	my $csv_line = shift; 
	my $cds      = {};
	
	my $subscriber_fields = $self->subscriber_fields;
	
	require   Text::CSV; 
	my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
    
	if ($csv->parse($csv_line)) {
	    
        my @fields = $csv->fields;
        my $email  = shift @fields; 

        $email =~ s{^<}{};
        $email =~ s{>$}{};
        $email =  cased(strip(xss_filter($email))); 


        $cds->{email}  = $email;
		$cds->{fields} = {};
		
		my $i = 0; 
        for(@$subscriber_fields){ 
			$cds->{fields}->{$_} = $fields[$i];
			$i++; 
		}
		# $i, huh. OK: 
		$cds->{profile}->{password} = $fields[$i];
    } else {
        carp $DADA::Config::PROGRAM_NAME . " Error: CSV parsing error: parse() failed on argument: ". $csv->error_input() . ' ' . $csv->error_diag();         
		$cds->{email} = $csv_line; 
    }
	
	return $cds; 
	
}


sub domain_stats_json { 
	my $self    = shift;
	my ($args)  = @_; 
	if(!exists($args->{-count})){ 
		$args->{-count} = 10; 
	}
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0; 
	}
	my $stats = $self->domain_stats(
		{ 
			-count => $args->{-count},
			-type  => $args->{-type},
		}
	);
	
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

	# Fancy-pants
	my $json = $datatable->output_javascript(
		pretty  => 1,
	);
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














1;

__END__

=pod

=head1 NAME 

DADA::MailingList::Subscribers - API for the Dada Mailing List Subscribers

=head1 SYNOPSIS

 # Import
 use DADA::MailingList::Subscribers; 
  
 # Create a new object
 my $lh = DADA::MailingList::Subscribers->new({-list => 'mylist'}); 
 
 # Check if this can be a valid subscription: 
 
 my ($status, $errors) = $lh->subscription_check(
	{
		-email => 'user@example.com', 
	}
 );
 
 # How about to unsubscribe: 
 
 my ($status, $errors) = $lh->unsubscription_check(
	{
		-email => 'user@example.com', 
	}
  );
 
 # Add
 $lh->add_subscriber(
	{
		-email => 'user@example.com',
		-type  => 'list', 
	}
 );
 
 # Move
 $lh->move_subscriber(
	{
		-email => 'user@example.com',
		-from  => 'list', 
		-to    => 'black_list', 
	}
  );
 
 # Copy
 $lh->copy_subscriber(
	{
		-email => 'user@example.com',
		-from  => 'black_list', 
		-to    => 'list', 
	}
  );
 
 # Remove
 $lh->remove_subscriber(
	{
		-email => 'user@example.com',
		-type  => 'list', 
	}
  );

=head1 DESCRIPTION

This module represents the API for Dada Mail's subscriptions lists. 

=head2 Subscription List Model

Dada Mail's Subscription List system is currently fairly simple:

=head3  A subscriber is mostly identified by their email address

Usually, when we talk of a, "Subscriber", we're talking about a email address that has been included
in a Dada Mail Subscription List. 

=head3 The Subscription List is made up of Sublists.

A sublist is a list of subscribers. Each sublist is completely separated from each other sublist. 

Each sublist is known because of its type. 

The types of sublists are as follows: 

=over

=item * list

This is your main subscription list and is the most important type of sublist. It holds a Mailing List's B<subscribers>. 
When a mailing list message is sent out, this is the list whose addresses are used. 

=item * black_list

This is the sublist of addresses that are not allowed to join the sublist, B<list> 

The addresses in this sublist do not have to be fully qualified email addresses, 
but can be simple strings, which are then used to match on other addresses, 
for verification. 

=item * white_list

This is the sublist of addresses that are allowed to join the sublist, B<list> 

The addresses in this sublist do not have to be fully qualified email addresses, 
but can be simple strings, which are then used to match on other addresses, 
for verification.

=item * authorized_senders

This is the sublist of addresses that can be allowed to post to a mailing list, from an email client, via the 
B<Bridge> plugin, if this feature has been enabled. 

=item * moderators

This is the sublist of addresses that can be sent a moderation message, for discussion lists.


=item * sub_confirm_list

This is the sublist that keeps subscription information on potential subscribers, 
when they've asked to join a list, but have not yet been verified via an email 
confirmation to subscribe. 

=item * unsub_confirm_list

This is the sublist that keeps unsubscription information on potential unsubscribers, 
when they've asked to leave a list, but have not yet been verified via an email 
confirmation to unsubscribe.

=item * invitelist

This is a sublist of temporary subscribers, who've been invited to join a mailing list. 
It's only used internally and is removed shortly after sending out a list invitation has begun. 

=back

=head3 A Subscription List can have Profile Fields

The Profile Fields are information that's separate than the email address of a subscriber. 
Their values are arbitrary and can be set to most anything you'd like. 

Internally, the Profile Fields are mapped almost exactly to SQL columns - adding a subscriber 
field will add a column in an SQL table. Removing a field will remove a column.

=head3 Restrictions are enforced by Dada Mail to only allow correct information to be saved in the Subscription List

The most obvious enforcement is that the subscriber has to have a valid email address. 

Another enforcement is that a subscriber cannot be subscribed to a sublist twice. 

A subscriber can be on more than one sublist at the same time. 

Some sublists are used to enforce subscription on other sublists. For example, a subscriber in the B<black_list> 
sublist will not be allowed to joing the, B<list> sublist. 

These enforcements are currently lazy - You I<can> easily break these rules, but you don't want to, 
and checking the validation of a subscriber is easy. The easiest way to break these rules is to work with the backend that 
the subscribers are saved in directly. 

=head3 The Subscription List has various backend options

The Subscription List can either be saved as a series of PlainText files (one file for each type of sublist), 
or as an SQL table. 

Each type of backend has different features that are available. The most notable feature is that the SQL 
backend supports arbitrary Profile Fields and the PlainText backend does not. 

Currently, the following SQL flavors are supported: 

=over

=item * MySQL

=item * PostgreSQL

=item * SQLite

=back

Except for being able to change the name of a Subscriber Field in SQLite, every SQL flavor has the same feature set. 

=head1 Public Methods

Below are the list of I<Public> methods that we recommend using when manipulating a Dada Mail Subscription List:

Every method has its parameters, if required (and when it's stated that they're required, I<they are>), passed as a hashref. 

=head2 Initializing

=head2 new

 my $lh = DADA::MailingList::Subscribers->new({-list => 'mylist'}); 

C<new> requires you to pass a B<listshortname> in, C<-list>. If you don't, your script will die. 

A C<DADA::MailingList::Subscribers> object will be returned. 

=head2 Add/Get/Edit/Move/Copy/Remove a Subscriber

=head2 add_subscriber

 $lh->add_subscriber(
	{
		-email  => 'user@example.com', 
		-type   => 'list',
		-fields => {
					# ...
				   },
	}
);

C<add_subscriber> adds a subscriber to a sublist. 

C<-email> is required and should hold a valid email address in form of: C<user@example.com>

C<-type> holds the sublist you want to subscribe the address to, if no sublist is passed, B<list> is used as a default.

C<-fields> holds the subscription fields you'd like associated with the subscription, passed as a hashref. 

For example, if you have two fields, B<first_name> and, B<last_name>, you would pass the Profile Fields like this: 

 $lh->add_subscriber(
	{
		-email  => 'user@example.com', 
		-type   => 'list',
		-fields => {
					first_name => "John", 
					last_name  => "Doe", 
				   },
	}
 );

Passing field values is optional.

Fields that are not actual fields that are being passed will be ignored. 

C<-dupe_check> can also be optionally passed. It should contain a hashref with other 
options. For example: 

    $lh->add_subscriber(
    	{
    		-email  => 'user@example.com', 
    		-type   => 'list',
    		-fields => {
    					first_name => "John", 
    					last_name  => "Doe", 
    				   },
    	}, 
    	-dupe_check    => {
    		-enable  => 1,
    		-on_dupe => 'ignore_add',
    	},
	
    );

C<-enable> can either be set to, C<1> or, C<0>. C<1> enables the check for dupes, right 
before subscribing an address. C<0> ignores the dupe check, so don't set it to C<0> 

C<-on_dupe> may be set to, C<ignore_add> to simply ignore subscribing the address. A warning will
be logged in the error log. You may also set this to, C<error>, which will cause the program to die. 

Setting this to anything else will cause the program to die. Forgetting to set it will have it default to, C<ignore_add>.

If the Duplicate subscriber check fails, (and C<-on_dupe> is set to, C<ignore_add> this method
will return, C<0> and not a DADA::MailingList::Subscriber object. 

=head3 Diagnostics

=over

=item * You must pass an email in the -email parameter!

You forgot to pass an email in the, -email parameter, ie: 

 # DON'T do this:
 $lh->add_subscriber();

=item * cannot do statement (at add_subscriber)!

Something went wrong in the SQL side of things.

=back

B<returns> a DADA::MailingList::Subscriber object on success, C<undef> or croaks on failure. 

=head2 get_subscriber

 my $sub_info = $lh->get_subscriber(
		{
			-email => 'user@example.com', 
			-type  => 'list', 
		}
	);

Returns the Profile Fields information in the form of a hashref. 

C<-email> is required and should hold a valid email address in form of: C<user@example.com>. The address should also be subscribed
and no check is done if the address you passed isn't. 

C<-type> holds the sublist you want to work with. If no sublist is passed, B<list> is used as a default.

=head3 Diagnostics

=over

=item * You must pass an email in the -email parameter!

You forgot to pass an email in the, -email parameter, ie: 

 # DON'T do this:
 $lh->get_subscriber();

=item * cannot do statement (at get_subscriber)!

Something went wrong in the SQL side of things.

=back

=head2 edit_subscriber

 $lh->edit_subscriber(
	{
		-email  => 'user@example.com', 
		-type   => 'list', 
		-fields => 
			{
				# ...
			},
		-method => 'writeover',
	}
 );		

returns C<1> on success. 

Internally, this method removes a subscriber and adds the same subscriber again to the same list.

C<-email> is required and should hold a valid email address in form of: C<user@example.com>

C<-type> holds the sublist you want to subscribe the address to, if no sublist is passed, B<list> is used as a default.

C<-fields> holds the subscription fields you'd like associated with the subscription, passed as a hashref. 

For example, if you have two fields, B<first_name> and, B<last_name>, you would pass the Profile Fields like this: 

 $lh->edit_subscriber(
	{
		-email  => 'user@example.com', 
		-type   => 'list',
		-fields => {
					first_name => "Jon", 
					last_name  => "Doh", 
				   },
	}
 );

Passing field values is optional, although you probably would want to, as this is the point of the entire method.

Fields that are not actual fields that are being passed will be ignored.

C<-method> holds the type of editing you want to do. Currently, this can be either, C<update>, or, C<writeover>. 

C<update> will only save the fields you pass - any other fields saved for this subscriber will not be erased. 

C<writeover> will save only the fields you pass - any other fields will be removed from the subscriber. 

If no C<-method> is passed, B<update> is used as a default.

=head3 Diagnostics

Internally, the subscriber is first removed, than added, using the C<add_subscriber> and, C<remove_subscriber> methods. 
Those diagnostics may pop up, if you use this method incorrectly

=over

=item * The -mode parameter must be set to, 'update', 'writeover' or left undefined!

You didn't set the -mode parameter correctly.

=back

=head2 move_subscriber

 $lh->move_subscriber(
 	{
		-email => 'user@example.com', 
		-from  => 'list', 
		-to    => 'black_list',
	}
 );

C<-email> holds the email address of the subscriber you want to move. 

C<-from> holds the sublist you're moving from. 

C<-to> holds the sublist you're moving to. 

All parameters are required. No other parameters will be honored. 

This method will C<die> if the subscriber isn't actually subscribed to the sublist set in, C<-from> or, 
B<is> already subscribed in the sublist set in, C<-to>. 

=head3 Diagnostics

=over

=item * email passed in, -email is not subscribed to list passed in, '-from'

The subscriber isn't actually subscribed to the sublist set in, C<-from> 

=item * email passed in, -email ( ) is already subscribed to list passed in, '-to'

The Subscriber is already subscribed in the sublist set in, C<-to>. 

=item * list_type passed in, -to is not valid

=item * list_type passed in, -from is not valid

=item * email passed in, -email is not valid

=item * cannot do statement (at move_subscriber)!

Something went wrong in the SQL side of things.

=back




=head2 copy_subscriber

 $lh->copy_subscriber(
 	{
		-email => 'user@example.com', 
		-from  => 'list', 
		-to    => 'black_list',
	}
 );

C<-email> holds the email address of the subscriber you want to copy. 

C<-from> holds the sublist you're copying from. 

C<-to> holds the sublist you're copying to. 

All parameters are required. No other parameters will be honored. 

This method will C<die> if the subscriber isn't actually subscribed to the sublist set in, C<-from> or, 
B<is> already subscribed in the sublist set in, C<-to>.

=head3 Diagnostics

=over

=item * email passed in, -email is not subscribed to list passed in, '-from'

The subscriber isn't actually subscribed to the sublist set in, C<-from> 

=item * email passed in, -email ( ) is already subscribed to list passed in, '-to'

The Subscriber is already subscribed in the sublist set in, C<-to>. 

=item * list_type passed in, -to is not valid

=item * list_type passed in, -from is not valid

=item * email passed in, -email is not valid

=item * cannot do statement (at move_subscriber)!

Something went wrong in the SQL side of things.

=back

=head2 remove_subscriber

 $lh->remove_subscriber(
	{
		-email => 'user@example.com', 
		-type  => 'list', 
	}
 ); 

C<remove_subscriber> removes a subscriber from a sublist. 

C<-email> is required and should hold a valid email address in form of: C<user@example.com>

C<-type> holds the sublist you want to subscribe the address to - you'll want to always explicitly set the type. 

No other parameters are honored.

=head3 Diagnostics

=over

=item * You must pass an email in the -email parameter!

You forgot to pass an email in the, -email parameter, ie: 

 # DON'T do this:
 $lh->remove_subscriber();

=back

=head2 Validating a Subscriber

=head2 get_list_types

 my $list_types = $lh->get_list_types

Returns a hashref of the allowed sublist types. The keys are the actual sublist types, the value is simply set to, C<1>, for 
easy lookup tabling. 

Takes no parameters. 

The current list of allowed sublist types are: 

=over

=item * list  

=item * black_list

=item * authorized_senders

=item * moderators

=item * testers

=item * white_list

=item * sub_confirm_list

=item * unsub_confirm_list

=item * invitelist

=back

=head2 check_for_double_email

B<Note!> The naming, coding and parameter style is somewhat old and crufty and this method is on the chopping block for a re-write

 my $is_subscribed = $lh->check_for_double_email(
	-Email          => 'user@example.com,
	-Type           => 'list',
	-Match_Type     => 'sublist_centric',
	);

Returns B<1> if the email address passed in, C<-Email> is subscribed to the sublist passed in, C<-Type>.


C<-Email> should hold a string that I<usually> is an email address, although can be only a part of an email address. 

C<-Type> should hold a valid sublist name. 

C<-Type> will default to, C<list> if no C<-Type> is passed.

C<-Status> 

C<-Match_Type> controls the behavior of how a email address is looked for and is usualy something you want to override for the, C<black_list> and C<white_list> sublists. 

The sublists have different matching behaviors. For example, if, C<bad> is subscribed to the C<black_list> sublist, this will return C<1>

 my $is_subscribed = $lh->check_for_double_email(
	-Email          => 'bad@example.com,
	-Type           => 'list',
	-Match_Type     => 'sublist_centric',
	);

Since the black list is not simply a list of addresses that are black listed, it's a list of patterns that are black listed. 

C<-Match_Type> can also be set to, C<exact>, in which case, this would return, C<0>

 my $is_subscribed = $lh->check_for_double_email(
	-Email          => 'bad@example.com,
	-Type           => 'list',
	-Match_Type     => 'exact',
	);

C<-Match_Type> will default to, C<sublist_centric> id no C<-Math_Type> is passed. 

=head2 subscription_check

	my ($status, $errors) =  $lh->subscription_check(
		{
			-email => 'user@example.com', 
			-type  => 'list'
			-skip  => []
		}
	); 


C<-email> holds the address you'd like to validate. It is required. 

C<-type> holds the sublist you want to work on. If not passed, C<list> will be used as the default.

C<-skip> holds an arrary ref of checks you'd like not to have done. The checks are named the same as the errors.

For example:

 my ($status, $errors) = $lh->subscription_check(
								{
                               	-email => 'user@example.com', 
                        			-skip => [qw(black_listed closed_list)],
                       		}
							); 

This method returns an array with two elements. 

The first element is the status of the validation. B<1> will be set if the validation was successful, B<0> if there was
an error. 

The second element is a list of the errors that were found when validating, in the form of a hashref, with its name
as the name of the error and the value set to, B<1> if that error was found. 

The errors, which are fairly self-explainitory are as follows: 

=over

=item * invalid_email

=item * subscribed

=item * closed_list

=item * invite_only_list

=item * mx_lookup_failed

=item * black_listed

=item * not_white_listed

=item * over_subscription_quota

=item * already_sent_sub_confirmation

=item * settings_possibly_corrupted

=item * no_list

=back

Unless you have a special case, always use this method to validate an email subscription. 

=head2 unsubscription_check

 my ($status, $errors) =  $lh->unsubscription_check(
								{
									-email => 'user@example.com',
									-type  => 'list', 
									-skip  => [],
									
								}
						   ); 

Like the subscription_check method, this method returns a $status and a hashref of $%errors
when checking the validity of an unsubscription. The following errors may be returned: 

=over

=item * no_list

=item * invalid_email

=item * not_subscribed

=item * settings_possibly_corrupted

=item * already_sent_unsub_confirmation

=back

Again, any of these tests can be skipped using the -skp argument. 

=head2 Add/Get/Edit/Remove a Subscription Field

As noted, Profile Fields are only available in the SQL backends.

It should be also noted that future revisions of Dada Mail may see these types of methods in their own object, ie: 

C<DADA::MailingList::Subscribers::Fields>

or, whatever.

=head2 filter_subscribers

 my (
	$subscribed, 
	$not_subscribed, 
	$black_listed, 
	$not_white_listed, 
	$invalid
	) = $lh->filter_subscribers(
		{
			-emails => [], 
			-type   => 'list',
		}
	);

This is a very powerful and complex method. There's dragons in the code, but the API is pretty simple. 

Used to validated a large amount of addresses at one time. Similar to C<subscripton_check> but is meant for more than one
address. It's also meant to be  bit faster than looping a list of addresses through C<subscripton_check>. 

Accepts two parameters. 

C<-email> is an array ref of email addresses . 

C<-type> is the sublist we want to validate undef. 

Depending on the type of sublist we're working on, validation works slightly different. 

Returns a 5 element array, each element contains an array ref of email addresses. 

This method also sets the precendence of black listed and white listed addresses, since an address can be a member of both sublists. 

The precendence is the same as what's returned: 

=over

=item * black_list

=item * white_list

=item * invalid

=back

In other words, if someone is both black listed and white listed, during validation, it'll be returned that they're black listed. 

=head2 filter_subscribers_w_meta

 my (
 	$subscribed, 
 	$not_subscribed, 
 	$black_listed, 
 	$not_white_listed, 
 	$invalid
     ) = $lh->filter_subscribers_w_meta(
 		{
 			-emails => [], 
 			-type   => 'list',
 		}
 	);

Similar to C<filter_subscribers>, but allows you to pass the subscriber field information with the email address.

The, C<-email> parameter should hold an arrayref of hashrefs, instead of just an array ref. The hashref itself should have the form of: 

 {
	-email => 'user@example.com',
	-fields => { 
		-field1 => 'blah', 
		-field2 => 'blahblah', 
	}
 }

No validation is done on the Profile Fields - they're simply passed through and returned. 

Returns a 5 element array of hashrefs, in the same format as what's passed.

=head2 add_subscriber_field

 $lh->add_subscriber_field(
	-field          => 'myfield', 
	-fallback_value => 'My Fallback Value', 
 ); 

C<add_subscriber_field> adds a new subscriber field. 

C<-field> Should hold the name of the subscriber field you'd like to add. It is required. 

C<-fallback_value> holds what's known as the, B<fallback value>, which is a value used in some instances of Dada Mail, 
if no value is saved in this field for a particular subscriber. It is optional. 

=head3 Diagnostics

=over

=item * You must pass a value in the -field parameter!

You forget to name your new field.

=item * Something's wrong with the field name you're trying to pass (yourfieldname). Validate the field name before attempting to add the field with, 'validate_subscriber_field_name'
You forgot to validate the field name you passed in, C<-field>. 

This will only be a warning and won't be fatal.

This error should actually be followed by more warnings, looking like this:

C<Field Error:>

Which will tell you exactly which test you failed.

=item * cannot do statement (at add_subscriber_field)!

Something went wrong in the SQL side of things.

=back

=head2 subscriber_fields

 my $fields = $lh->subscriber_fields;
 
 # or: 
 
 for(@{$lh->subscriber_fields}){
  # ...	
 }

Returns the Profile Fields in the Subscription List, in the form of an array ref. 

Takes no arguments... usually. 

Internally (and privately), it does accept the, C<-dotted> parameter. This will prepend, 'subscriber.' to every field name.

=head3 Diagnostics

None that I can think of. 

=head2 edit_subscriber_field_name

 $lh->edit_subscriber_field_name(
 	{ 
		-old_name => 'old', 
		-new_name => 'new', 
		
	}
 ); 

Changes the name of a Subscriber Field. 

Returns 1 on success. 

C<-old_name> holds the name of the field you want to rename.

C<-new_name> holds what you'd like to rename the field in C<-old_name> to. 

Both parameters are required.

=head3 Diagnostics

=over

=item * You MUST supply the old field name in the -old_name parameter!

You forgot to pass the old field name.

=item * You MUST supply the new field name in the -new_name parameter!

You forgot to pass the new field name.

=back

=head2 remove_subscriber_field

 $lh->remove_subscriber_field(
	{
		-field => 'myfield', 
	},
 ); 

Removes the field specified in, C<-field>. C<-field> is required.

Returns C<1> upon success. 

=head3 Diagnostics

=over

=item * You MUST pass a field name in, -field! 

You forgot to set, C<-field>

=item * cannot do statement! (at: remove_subscriber_field)

Something went wrong on the SQL side of things. 

=back

=head2 subscriber_field_exists

 my $exists = $lh->subscriber_field_exists(
	{
		-field => 'myfield', 
	}
 ); 

Checks the existance of a subscriber field name. 

=head3 Diagnostics

=over

=item * You MUST pass a field name in, -field! 

You forgot to set, C<-field>

=item * cannot do statement! (at: remove_subscriber_field)

Something went wrong on the SQL side of things. 

=back

=head2 validate_subscriber_field_name

 my ($status, $errors) = $lh->validate_subscriber_field_name(
							{
								-field => $field,
								-skip  => [],
							}
						); 

Used to validate a subscriber field name and meant to be used before a subscriber field is added. 

Returns a two element array, 

The first element is either C<1> or C<0> and is the status of the validation. A status of, B<1>
means the validation was successful; B<0> means the validation had problems. 

The second element is a list of the errors that were found when validating, in the form of a hashref, with the name
of the error set as the key and the value set to, B<1> if this error was found. 

C<-field> is required and should be the name of the field you're attempting to validate. 

C<-skip> is an optional parameter and is used to list the errors you're not so interested in. It should be set to an array ref. 

=head3 Subscriber Validation Requirements

Profile Fields are validated mostly to make sure they're also valid SQL column names for all the SQL backends that are 
supported and also that the fields are not already used for internal SQL fields used by the program for other purposes. 
Validation is also done sparingly for reserved words. 

The entire list of errors that can be reported back are as follows: 

=over

=item * field_blank

=item * field_name_too_long

length of 64

=item * slashes_in_field_name

C</> or, C<\>

=item * spaces

=item * weird_characters

Basically anything that's not alpha/numeric

=item * quotes

C<'> and, C<">

=item * field_exists 

=item * field_is_special_field

The field name is one of the following: 

=over

=item * email_id    

=item * email       

=item * list        

=item * list_type   

=item * list_status 

=item * email_name  

=item * email_domain

=back

=back

=head2 validate_remove_subscriber_field_name

 my ($status, $errors) = $lh->validate_remove_subscriber_field_name(
 							{ 
 								-field      => $field,
 								-skip       => [],
 								-die_for_me => 0, 
 							}
 						); 
  

Similar to, C<validate_subscriber_field_name> is used to validate a subscriber field name 
and is meant to be used before a subscriber field is I<removed>. 

Returns a two element array, 

The first element is either C<1> or C<0> and is the status of the validation. A status of, B<1>
means the validation was successful; B<0> means the validation had problems. 

The second element is a list of the errors that were found when validating, in the form of a hashref, with the name
of the error set as the key and the value set to, B<1> if this error was found. 

C<-field> is required and should be the name of the field you're attempting to validate. 

C<-skip> is an optional parameter and is used to list the errors you're not so interested in. It should be set to an array ref. 

C<-die_for_me> is another optional parameter. If set to, C<1>, an error found in validation will prove fatal. 

The entire list of errors that can be reported back are as follows: 

=over


=item * field_is_special_field

The field name is one of the following: 

=over

=item * email_id    

=item * email       

=item * list        

=item * list_type   

=item * list_status 

=item * email_name  

=item * email_domain

=back

=item * field_exists

=item * number_of_fields_limit_reached

=back

=head2 get_all_field_attributes

 my $field_values = $lh->get_all_field_attributes;

Returns the name of every subscriber field and its fallback value in the form of a hashref. 

The fallback values are actually saved in the List Settings. 

Take no arguments.

=head2 _save_field_attributes

 $lh->_save_field_attributes(
		{
			-field          => $field, 
			-fallback_value => $fallback_field_value, 
			-fallback_value => $fallback_value, 
		}
 );

B<Currently marked as a private method>. 

Used to save a new fallback field value for the field set in, C<-field>. I<usually> shouldn't be used alone, but there is 
actually no way to edit a fallback field value, without using this method. 

If used on an existing field, make sure to remove the fallback field value first, using, C<_remove_field_attributes>, ala: 

 $lh->remove_field_attributes({-field => 'myfield'});
 $lh->save_field_attributes({-field => 'myfield'}, -fallback_value => 'new_value');
 
Is called internally, when creating a new field via, C<add_subscriber_field>, so make sure not to call it twice. 

=head3 Diagnostics

=over

=item * You MUST pass a value in the -field parameter!

=back

=head2 remove_field_attributes

 $lh->remove_field_attributes(
		{
			-field => 'myfield', 
		}
 ); 

B<Currently marked as a private method>. 

Used to remove a fallback field value. Used internally.

=head3 Diagnostics

=over

=item * You MUST pass a value in the -field parameter!

=back


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

