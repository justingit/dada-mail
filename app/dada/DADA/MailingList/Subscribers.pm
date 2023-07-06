package DADA::MailingList::Subscribers;

use strict;


use lib qw(
  ../
  ../../DADA/perllib
  ./
  ./DADA/perlib
);

use Try::Tiny;
use Carp qw(carp croak);
use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB
);


use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use DADA::MailingList::Subscriber;
use DADA::MailingList::Subscriber::Validate;
use DADA::Profile::Fields;
use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;
my $type;
my $backend;
my $t = 0;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';
               $DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList};

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

    my ($args) = @_;

    if ( !exists( $args->{-ls_obj} ) ) {
        require DADA::MailingList::Settings;
        $self->{ls} =
          DADA::MailingList::Settings->new( { -list => $args->{-list} } );
    }
    else {
        $self->{ls} = $args->{-ls_obj};
    }

    if ( exists( $args->{-dpfm_obj} ) ) {
        $self->{-dpfm_obj} = $args->{-dpfm_obj};
    }
    else {
        #$self->{-dpfm_obj} = $args->{-dpfm_obj} = undef;
    }

    $self->{'log'} = DADA::Logging::Usage->new;
    $self->{list} = $args->{-list};

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};


    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;

    if ( exists( $args->{-dpfm_obj} ) ) {
        $self->{fields} = DADA::Profile::Fields->new(
            {
                -dpfm_obj => $args->{-dpfm_obj},
            }
        );

    }
    else {
        $self->{fields} = DADA::Profile::Fields->new;
    }

    $self->{validate} = DADA::MailingList::Subscriber::Validate->new(
        { -list => $self->{list}, -lh_obj => $self } );
}

sub add_subscriber {

    my $self = shift;
    my ($args) = @_;
    $args->{-list} = $self->{list};
    if ( exists( $self->{-dpfm_obj} ) ) {
        $args->{-dpfm_obj} = $self->{-dpfm_obj};
    }
    return DADA::MailingList::Subscriber->add($args);
}

sub quota_limit {
    my $self        = shift;
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

    my $self = shift;
    my ($args) = @_;

    my $addresses       = $args->{-addresses};
    my $added_addresses = [];
    my $type            = $args->{-type};
    if ( !exists( $args->{-fields_options_mode} ) ) {
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

            if ( $args->{-fields_options_mode} eq 'writeover_ex_password' ) {
                $pf_om   = 'writeover';
                $pass_om = 'preserve_if_defined';
            }
            elsif ( $args->{-fields_options_mode} eq 'writeover_inc_password' )
            {
                $pf_om   = 'writeover';
                $pass_om = 'writeover';
            }

            $dmls = $self->add_subscriber(
                {
                    -email   => $info->{email},
                    -fields  => $info->{fields},
                    -profile => {
                        -password => $info->{profile}->{password},
                        -mode     => $args->{-fields_options_mode},
                    },
                    -type => $type,
                    -fields_options =>
                      { -mode => $args->{-fields_options_mode}, },
                    -dupe_check => {
                        -enable  => 1,
                        -on_dupe => 'ignore_add',
                    },
                }
            );
            $new_total++;
            if ( defined($dmls) ) {    # undef means it wasn't added.
                $new_email_count++;
                push( @$added_addresses, $info );
            }
            else {
                $skipped_email_count++;
            }
        }
    }

    undef($addresses);

    if ( $type eq 'list' ) {
        if ( $self->{ls}->param('send_subscribed_by_list_owner_message') == 1 )
        {
            require DADA::App::MassSend;
            try {
                # DEV:
                # This needs to send the Profile Password, if it's known.
                #
                #warn '$self->{list} ' . $self->{list};
                require DADA::App::MassSend;
                my $dam =
                  DADA::App::MassSend->new( { -list => $self->{list} } );
                $dam->just_subscribed_mass_mailing(
                    {
                        -addresses => $added_addresses,
                    }
                );
            }
            catch {
                warn 'Problems w/send_subscribed_by_list_owner_message:' . $_;
            };
        }

#        warn q{$self->{ls}->param('send_last_archived_msg_mass_mailing')} . $self->{ls}->param('send_last_archived_msg_mass_mailing');

        if ( $self->{ls}->param('send_last_archived_msg_mass_mailing') == 1 ) {
            try {
                require DADA::App::MassSend;
                my $dam =
                  DADA::App::MassSend->new( { -list => $self->{list} } );
                $dam->send_last_archived_msg_mass_mailing(
                    {
                        -addresses => $added_addresses,
                    }
                );
            }
            catch {
                warn 'Problems w/send_last_archived_msg_mass_mailing:' . $_;
            };
        }
		
		# Record as un-consented? 
		require DADA::MailingList::ConsentActivity; 
		my $dmlc = DADA::MailingList::ConsentActivity->new; 
		for(@$added_addresses){
			$dmlc->ch_record(
				{ 
					-email  => $_->{email},
					-list   => $self->{list},
					-action => 'subscription',
					-source => 'admin',
				}
			);
		}
		# /Record as un-consented? 
	 
    }

    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} == 1 )
    {
        eval {
            require DADA::Profile::Htpasswd;
            my $htp =
              DADA::Profile::Htpasswd->new( { -list => $self->{list} } );
            for my $id ( @{ $htp->get_all_ids } ) {
                $htp->setup_directory( { -id => $id } );
            }
        };
        if ($@) {
            warn "Problem updated Password Protected Directories: $@";
        }
    }

    return ( $new_email_count, $skipped_email_count );

}

sub get_subscriber {
    my $self = shift;
    my ($args) = @_;
    $args->{-list} = $self->{list};
    my $dmls = DADA::MailingList::Subscriber->new($args);
    return $dmls->get($args);

}

sub get_subscriber_timestamp { 
	my $self = shift; 
	my ($args) = @_;
	$args->{-list} = $self->{list};
	my $dmls = DADA::MailingList::Subscriber->new($args);
	return $dmls->timestamp();
}

sub move_subscriber {
    my $self = shift;
    my ($args) = @_;
    $args->{-list} = $self->{list};
    $args->{-type} = $args->{-from};
    my $dmls = DADA::MailingList::Subscriber->new($args);

    return $dmls->move($args);

}

sub edit_subscriber {
    my $self = shift;
    my ($args) = @_;
    $args->{-list} = $self->{list};
    my $dmls = DADA::MailingList::Subscriber->new($args);
    return $dmls->edit($args);

}

sub copy_subscriber {
    my $self = shift;
    my ($args) = @_;
    $args->{-list} = $self->{list};
    $args->{-type} = $args->{-from};

    my $dmls = DADA::MailingList::Subscriber->new($args);
    return $dmls->copy($args);
}

sub member_of {
    my $self = shift;
    my ($args) = @_;
    $args->{-list} = $self->{list};

    my $dmls = DADA::MailingList::Subscriber->new($args);
    return $dmls->member_of($args);
}

sub also_subscribed_to {

    my $self = shift;
    my ($args) = @_;

    my @lists = ();
    if ( !exists( $args->{-types} ) ) {
        $args->{-types} = [qw(list)];
    }

  LIST: foreach my $list ( available_lists() ) {

        next
          if $list eq $self->{list};

        my $temp_lh = DADA::MailingList::Subscribers->new( { -list => $list } );

        for my $type ( @{ $args->{-types} } ) {
            if (
                $temp_lh->check_for_double_email(
                    -Email => $args->{-email},
                    -Type  => $type
                ) == 1
              )
            {
                push( @lists, $list );
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

    my $addresses    = $args->{-addresses};
    my $unsubscribed = [];

    if ( !exists( $args->{-type} ) ) {
        croak "you MUST pass the, '-type' parameter!";
    }
    my $type = $args->{-type};


	if($type eq 'list') {
	    if ( !exists( $args->{-consent_vars} ) ) {
	        $args->{-consent_vars} = { 
				-source          => 'admin control panel', 
				-source_location => $DADA::Config::S_PROGRAM_URL, 
			};
	    }
	}
	
    my $d_count = 0;
    for my $address (@$addresses) {
        my $c = $self->remove_subscriber(
            {
                -email            => $address,
                -type             => $type,
                -validation_check => 0,
				($type eq 'list') ? (
					-consent_vars => $args->{-consent_vars}, 
				) : (), 
			}
        );
        $d_count = $d_count + $c;
        if ( $c >= 1 ) {
            push( @$unsubscribed, $address );
        }
    }

    my $bl_count = 0;
    if ( $type eq 'list' || $type eq 'bounced_list' ) {

        if (   $self->{ls}->param('black_list') == 1
            && $self->{ls}->param('add_unsubs_to_black_list') == 1 )
        {

            for (@$addresses) {
                my $a = $self->add_subscriber(
                    {
                        -email      => $_,
                        -type       => 'black_list',
                        -dupe_check => {
                            -enable  => 1,
                            -on_dupe => 'ignore_add',
                        },
                    }
                );
                if ( defined($a) ) {
                    $bl_count++;
                }
            }
        }
    }
	
	# This says, remove any unconfirmed profiles, when you remove an unconfirmed subscription 
	# as long as that address isn't a part of any *any* other sublist throughout the system: 
	
	if($type eq 'sub_confirm_list') {
		
		require DADA::Profile; 
		require DADA::Profile::Fields; 
		for my $address(@$addresses){
			my $prof1 = DADA::Profile->new({-email => $address}); 
			my $all_subs = $prof1->subscribed_to( { -type => ':all' } );
			if ( scalar($all_subs) <= 0 ) {			
				my $prof = DADA::Profile->new({-email => '*' . $address}); 
				if($prof->exists){ 
					$prof->remove();
				}
				my $dpf = DADA::Profile::Fields->new({-email => '*' . $address}); 
				if($dpf->exists){ 
					$dpf->remove();
				}
			}
		}
	}

    warn '$type:' . $type
      if $t;
    
	if ( $type eq 'list' ) {
        warn q{$self->{ls}->param('send_unsubscribed_by_list_owner_message')}
          . $self->{ls}->param('send_unsubscribed_by_list_owner_message')
          if $t;
        if (
            $self->{ls}->param('send_unsubscribed_by_list_owner_message') == 1 )
        {
            require DADA::App::MassSend;
            warn 'sending just_unsubscribed_mass_mailing'
              if $t;
            if ($t) {
                require Data::Dumper;
                warn 'addresses:' . Data::Dumper::Dumper($addresses);
            }
            try {
                my $dam =
                  DADA::App::MassSend->new( { -list => $self->{list} } );
                $dam->just_unsubscribed_mass_mailing(
                    {
                        -addresses => $addresses,
                    }
                );
            }
            catch {
                warn 'Problems w/send_unsubscribed_by_list_owner_message:' . $_;
            };
        }

        if ( $self->{ls}->param('send_admin_unsubscription_notice') == 1 ) {

            require DADA::App::FormatMessages;
            my $fm = DADA::App::FormatMessages->new( -List => $self->{list} );
            $fm->use_email_templates(0);

            #my $profile_email = $self->{ls}->param('list_owner_email');
            #warn 'send_admin_unsubscription_notice 1';

            my $tmpl_addresses = [];
            require DADA::Profile;

            # Ugly!
            foreach my $un (@$unsubscribed) {
                require DADA::Profile::Fields;
                my $dpf = DADA::Profile::Fields->new( { -email => $un } );
                my $profile_vals = {};
                if ( $dpf->exists( { -email => $un } ) ) {
                    $profile_vals = $dpf->get(
                        {
                            -dotted      => 1,
                            -dotted_with => 'profile'
                            , # -dotted_with does not work actually (just an idea), use subscriber.
                        }
                    );
                }
                my $subscriber_loop = [];

                foreach ( sort keys %{$profile_vals} ) {
                    my $nk = $_;
                    $nk =~ s/subscriber\.//;
                    push( @$subscriber_loop,
                        { name => $nk, value => $profile_vals->{$_} } );
                }

                push(
                    @$tmpl_addresses,
                    {
                        subscriber => $subscriber_loop,
                        %$profile_vals,
                        email => $_,
                    }
                );

            }

            require DADA::App::EmailThemes;
            my $em = DADA::App::EmailThemes->new(
                {
                    -list => $self->{list},
                }
            );
            my $etp = $em->fetch('unsubscription_notice_message');

            my $msg = $etp->{plaintext};
            require DADA::Template::Widgets;
            $msg = DADA::Template::Widgets::screen(
                {
                    -data => \$msg,
                    -vars => {
                        addresses => $tmpl_addresses,
                    },
                    -list_settings_vars_param => {
                        -list => $self->{list},
                    },
                }
            );
            my $to = $self->{ls}->param('list_owner_email');

            if ( $self->{ls}->param('send_admin_unsubscription_notice_to') eq
                'list' )
            {

                # warn 'send_admin_unsubscription_notice_to list';

                $fm->mass_mailing(1);
                require DADA::Mail::Send;
                my $mh = DADA::Mail::Send->new( { -list => $self->{list} } );
                $mh->list_type('list');
                my $message_id = $mh->mass_send(
                    {
                        -msg => {
                            Subject => $etp->{vars}->{subject},
                            Body    => $msg,
                        },
                    }
                );
            }
            else {
                if (
                    $self->{ls}->param('send_admin_unsubscription_notice_to')
                    eq 'alt'
                    && check_for_valid_email(
                        $self->{ls}
                          ->param('alt_send_admin_unsubscription_notice_to')
                    ) == 0
                  )
                {
                    $to = $self->{ls}
                      ->param('alt_send_admin_unsubscription_notice_to');

                    # warn 'send_admin_unsubscription_notice_to alt';
                    # warn '$to: ' . $to;

                }
                require DADA::App::Messages;
                my $dap =
                  DADA::App::Messages->new( { -list => $self->{list} } );

                $dap->send_multipart_email(
                    {
                        -headers => {
                            To      => $to,
                            From    => $etp->{vars}->{from_phrase},
                            Subject => $etp->{vars}->{subject},
                        },
                        -plaintext_body => $msg,
                    }
                );
            }
        }
    }

    return ( $d_count, $bl_count );

}

sub admin_update_address {

    my $self = shift;
    my ($args) = @_;

    my $addresses = $args->{-addresses};
    if ( !exists( $args->{-type} ) ) {
        croak "you MUST pass the, '-type' parameter!";
    }
    my $type          = $args->{-type};
    my $email         = $args->{-email};
    my $updated_email = $args->{-updated_email};

    my $og_prof = undef;

    if ( $self->can_have_subscriber_fields ) {
        require DADA::Profile;
        $og_prof = DADA::Profile->new( 
			{ 
				-email                         => $email, 
				-override_profile_enable_check => 1, 
			} 
		);
	}
	else { 
		warn 'NO $og_prof';
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
        'Updated Subscription for ' . $self->{list} . '.' . $type,
        $email . ':' . $updated_email
    );

    # PROFILES

    if ( !$self->can_have_subscriber_fields ) {

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
        my $og_subscriptions = $og_prof->subscribed_to( { -type => 'list' } );

        if ( !$og_prof->exists ) {

            # Make one (old email)
            $og_prof->insert(
                {
                    -password  => $og_prof->_rand_str(8),
                    -activated => 1,
                }
            );
        }


       # Is there another mailing list that has the old address as a subscriber?
       # Remember, we already changed over ONE of the subscriptions.

        if ( scalar(@$og_subscriptions) >= 1 ) {

            my $updated_prof =
              DADA::Profile->new( { -email => $updated_email } );

            # This already around?
            if ( $updated_prof->exists ) {

                # Got any information?
                if ( $updated_prof->{fields}->are_empty ) {

                    # No info in there yet?
                    $updated_prof->{fields}->insert(
                        {
                            -fields => $og_prof->{fields}->get,
                            -mode   => 'writeover',
                        }
                    );
                }
            }
            else {

                # So there's not a profile, yet?
                # COPY (don't move) the old profile info,
                # to the new profile
                # (inludeds fields)
                my $new_prof = $og_prof->copy(
                    {
                        -from => $email,
                        -to   => $updated_email,
                    }
                );
            }
        }
        else {

        # So, no other mailing list has a subscription for the new email address
        #
            my $updated_prof =
              DADA::Profile->new( 
			  	{
						-email                         => $updated_email, 
						-override_profile_enable_check => 1, 
				}
			);

            # But does this profile already exists for the updated address?

            if ( $updated_prof->exists ) {

                # Well, nothing, since it already exists.
            }
            else {

                # updated our old email profile, to the new email
                # Only ONE subscription, w/Profile
                # First save the updated email

                $og_prof->update(
                    {
                        -activated    => 1,
                        -update_email => $updated_email,
                    }
                );

                # Then this method changes the updated email to the email..
                # And changes the profiles fields, as well...
                $og_prof->update_email;
            }
        }

        # so, the old prof have any subscriptions?
        my $old_prof = DADA::Profile->new( 
			{	
				-email                         => $email, 
				-override_profile_enable_check => 1, 
			 }
		);
        if ( $old_prof->exists ) {

            # Again, this will only touch, "list" sublist...
            if ( scalar( @{ $old_prof->subscribed_to } ) == 0 ) {

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

    if ( exists( $self->{-dpfm_obj} ) ) {
        $args->{-dpfm_obj} = $self->{-dpfm_obj};
    }
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }

    my $dmls =
      DADA::MailingList::Subscriber->new(
        { %{$args}, -list => $self->{list} } );
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
	my $list_types =  {};
    for(keys %{$DADA::Config::LIST_TYPES}){ 
		$list_types->{$_} = 1; 
	}
	return $list_types; 
}

sub allowed_list_types {

    my $self = shift;
    my $type = shift;

    my $named_list_types = $self->get_list_types;

    if ( exists( $named_list_types->{$type} ) ) {
        return 1;
    }
    elsif ( $type =~ m/_tmp(.*?)/ ) {
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
                if ( ( $num_subscribers + 1 ) >=
                    $ls->param('subscription_quota') )
                {
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
    my $found_black_list_ref = [];
    my $clean_list_ref       = [];
    my $black_listed_ref     = [];
    my $black_list_ref       = [];
    my $white_listed         = [];
    my $not_white_listed     = [];

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

        ( $clean_list_ref, $black_listed_ref ) =
          $self->find_unique_elements( $unique_ref, $found_black_list_ref );

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
    return (
        $not_unique_ref,   $clean_list_ref, $black_listed_ref,
        $not_white_listed, \@unique_bad_emails
    );

}

sub filter_subscribers_w_meta {

    # So, what are we doing about dupes?

    my $self = shift;
    my ($args) = @_;

    my $info = $args->{-emails};

    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }

    my $dupe_check = {};

    my $emails = [];

    my $fields = $self->subscriber_fields();

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    for my $n_address ( @{$info} ) {

		$n_address->{email} = lc_email( strip( $n_address->{email} ) );
		
        if ( exists( $dupe_check->{ $n_address->{email} } ) ) {
            carp "already looked at: '"
              . $n_address->{email}
              . "' - will not process twice!";
            next;
        }
        $dupe_check->{ $n_address->{email} } = 1;
        my ( $status, $errors ) = $self->subscription_check(
            {
                -email  => $n_address->{email},
                -type   => $args->{-type},
                -mode   => 'admin',
                -fields => $n_address->{fields},
                -skip   => [
                    qw(
                      mx_lookup_failed
                      already_sent_sub_confirmation
                      already_sent_unsub_confirmation
                      over_subscription_quota
                      invite_only_list
                      )
                ],
                -ls_obj => $ls,
            }
        );

        my $csv_str    = '';
        my $csv_fields = [ $n_address->{email} ];
        foreach (@$fields) {
            push( @$csv_fields, $n_address->{fields}->{$_} );
        }
        push( @$csv_fields, $n_address->{profile}->{password} );

        if ( $csv->combine(@$csv_fields) ) {
            $csv_str = $csv->string;
        }
        else {
            carp "well, that didn't work.";
        }

# Put in the import limit, and check that before anything else.
# Put in the pref's to enable/disable tests, like blacklist, whitelist, missing profile fields, etc

        # Ability to set Profile Password...

# MAYBE put in pref - what to do with addresses that are already subscribed - update instead?
# "These addresses are already subscribed (check for Profile Fields if so...:) Update thier profiles? (Root Login only)
#

        push(
            @$emails,
            {
                email   => $n_address->{email},
                fields  => $n_address->{fields},
                profile => $n_address->{profile},
                status  => $status,
                errors  => $errors,
                csv_str => $csv_str,

                #%$ht_errors,
            }
        );
    }
    return $emails;
}

sub filter_subscribers_massaged_for_ht {
    my $self = shift;
    my ($args) = @_;

    my $emails = $self->filter_subscribers_w_meta($args);

    my $new_emails = [];
    my $fields     = $self->subscriber_fields();

    if ( !exists( $args->{-treat_profile_fields_special} ) ) {
        $args->{-treat_profile_fields_special} = 1;
    }

    for my $address (@$emails) {

        my $ht_fields = [];
        my $ht_errors = [];

        if ( exists( $address->{errors}->{invalid_profile_fields} )
            && $args->{-treat_profile_fields_special} == 1 )
        {
            for my $field (@$fields) {
                if (
                    exists( $address->{errors} )
                    && exists(
                        $address->{errors}->{invalid_profile_fields}->{$field}
                    )
                    && exists(
                        $address->{errors}->{invalid_profile_fields}->{$field}
                          ->{required}
                    )
                  )
                {
                    push(
                        @$ht_fields,
                        {
                            name  => $field,
                            value => $address->{fields}->{$field},
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
            for my $field (@$fields) {
                push(
                    @$ht_fields,
                    {
                        name  => $field,
                        value => $address->{fields}->{$field}
                    }
                );
            }

        }

        if ( exists( $address->{errors} ) ) {
            if ( keys %{ $address->{errors} } ) {
                for my $error ( keys %{ $address->{errors} } ) {
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
                email            => $address->{email},
                profile_password => $address->{profile}->{password},
                status           => $address->{status},
                og_errors        => $address->{errors},
                csv_str          => $address->{csv_str},

                errors => $ht_errors,
                fields => $ht_fields,

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

    return ( $not_members, $invalid_email, $subscribed, $black_listed,
        $not_white_listed, $invalid_profile_fields );
}

sub find_unique_elements {

    my $self = shift;

    my $A = shift || undef;
    my $B = shift || undef;

    if ( $A and $B ) {

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
            unless ( $seen{$item} ) {

                # it's not in %seen, so add to @aonly
                push( @unique, $item );
            }
            else {
                push( @already_in, $item );
            }
        }

        return ( \@unique, \@already_in );

    }
    else {
        carp 'I need two array refs!';
        return ( [], [] );
    }
}

sub csv_to_cds {
    my $self     = shift;
    my $csv_line = shift;
    my $cds      = {};

    my $subscriber_fields = $self->subscriber_fields;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    if ( $csv->parse($csv_line) ) {

        my @fields = $csv->fields;
        my $email  = shift @fields;

        $email =~ s{^<}{};
        $email =~ s{>$}{};
        $email = cased( strip( xss_filter($email) ) );

        $cds->{email}  = $email;
        $cds->{fields} = {};

        my $i = 0;
        for (@$subscriber_fields) {
            $cds->{fields}->{$_} = $fields[$i];
            $i++;
        }

        # $i, huh. OK:
        $cds->{profile}->{password} = $fields[$i];
    }
    else {
        carp $DADA::Config::PROGRAM_NAME
          . " Error: CSV parsing error: parse() failed on argument: "
          . $csv->error_input() . ' '
          . $csv->error_diag();
        $cds->{email} = $csv_line;
    }

    return $cds;

}

sub domain_stats_json {
    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-count} ) ) {
        $args->{-count} = 10;
    }
    if ( !exists( $args->{-printout} ) ) {
        $args->{-printout} = 0;
    }
    my $stats = $self->domain_stats(
        {
            -count => $args->{-count},
            -type  => $args->{-type},
        }
    );

	require JSON; 
	my $json_object = JSON->new->allow_nonref;
	
    require Data::Google::Visualization::DataTable;
    my $datatable = Data::Google::Visualization::DataTable->new(
    	{ 
			json_object => $json_object,
		}
    );

    $datatable->add_columns(
        { id => 'domain', label => "Domain", type => 'string', },
        { id => 'number', label => "Number", type => 'number', },
    );

    for (@$stats) {
        $datatable->add_rows( [ { v => $_->{domain} }, { v => $_->{number} }, ],
        );
    }

    # Fancy-pants
    my $json = $datatable->output_javascript( pretty => 1, );
    if ( $args->{-printout} == 1 ) {
        require CGI;
        my $q = CGI->new;
        print $q->header(
            '-Cache-Control' => 'no-cache, must-revalidate',
            -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
            -type            => 'application/json',
        );
        print $json;
    }
    else {
        return $json;
    }

}



sub inexact_match {

    my $self = shift;
    my ($args) = @_;
    my $email = cased( $args->{ -email } );
    my ( $name, $domain ) = split ( '@', $email );

    my $query .= 'SELECT COUNT(*) ';
    $query .= ' FROM ' . $self->{sql_params}->{subscriber_table} . ' WHERE ';
    $query .= ' list_type = ? AND';
    $query .= ' list_status = ' . $self->{dbh}->quote(1);
    if (   $args->{ -against } eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {

        # ...
    }
    else {
        $query .= ' AND list = ?';
    }
	$query .= ' AND (email = ? OR email = ? OR email = ?)';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    if (   $args->{ -against } eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {
		$sth->execute(
		    $args->{ -against },
		    $email,
		    $name . '@',
		    '@' . $domain,
		  )
		  or croak "cannot do statement (inexact_match)! $DBI::errstr\n";

    }
    else {

	$sth->execute(
	    $args->{ -against },
	    $self->{list},
	    $email,
	    $name . '@',
	    '@' . $domain,

	  )
	  or croak "cannot do statement (inexact_match)! $DBI::errstr\n";
	
    }

    my @row = $sth->fetchrow_array();
    $sth->finish;

    if ( $row[0] >= 1 ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub search_list {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{-start} ) ) {
        $args->{-start} = 0;
    }
    if ( !exists( $args->{'-length'} ) ) {
        $args->{'-length'} = 100;
    }

    my $r = [];

    my $partial_listing = {};
    my $search_type = 'any'; 
    
    my $fields = $self->subscriber_fields;
    if(! exists($args->{-query}) && exists($args->{-partial_listing})){ 
        $partial_listing = $args->{-partial_listing}; 
        $search_type = 'all'; 
    }
    else { 
        for (@$fields) {
            $partial_listing->{$_} = {
                 -operator => 'LIKE',
                 -value    => $args->{-query}, 
            };
        }
        # Do I have to do this, explicitly?
        $partial_listing->{email} = {
            -operator => 'LIKE',
            -value    => $args->{-query} 
        };
    }
    
    my $query = $self->SQL_subscriber_profile_join_statement(
        {
            -type            => $args->{-type},
            -partial_listing => $partial_listing,
            -search_type     => $search_type,
            -order_by        => $args->{-order_by},
            -order_dir       => $args->{-order_dir},
			#-start          => $args->{ -start }, 
			#'-length'       => $args->{'-length'}, 
        }
    );
    warn 'QUERY: ' . $query
     if $t; 

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (for search_list)! $DBI::errstr\n";

    my $row   = {};
    my $count = 0;

    while ( $row = $sth->fetchrow_hashref ) {

		# DEV: It would be better to use LIMIT, x, y in the query, 
		# but we still need the total search results number, and something like, 
		# select count(*) from (select [...]);
		# isn't working as well as I'd like
		
        $count++;
        next if $count < ( $args->{ -start } * $args->{ '-length' });
        next if $count >  ( $args->{ -start } * $args->{ '-length' }) + ($args->{'-length'}) ;

        my $info = {};
        
        $info->{timestamp}            = $row->{timestamp};
        $info->{email}                = $row->{email};
		$info->{delivery_prefs_value} = $row->{delivery_prefs_value};
        
		
		$info->{type}     = $args->{-type};    # Whazza?!

        delete( $row->{email} ); #?
        
        $info->{fields} = [];

        for (@$fields) {
            push( @{ $info->{fields} }, { name => $_, value => $row->{$_} } );
        }

        push( @$r, $info );

    }

    $sth->finish();

    return ( $count, $r );

}




sub domain_stats { 
	my $self    = shift;

	my ($args) = @_; 
	
	my $count;
	if(exists($args->{-count})) { 
		$count = $args->{-count}; 
	}
	else { 
		$count = 15; 
	}
	
	my $type = 'list'; 
	if(exists($args->{-type})){ 
		$type = $args->{-type};
	}
	
	my $domains = {};
	
	my $query = "SELECT email FROM " . 
				$self->{sql_params}->{subscriber_table} . 
				" WHERE list_type = ? AND list_status = ? AND list = ?";

	# Count All the Domains
	my $sth = $self->{dbh}->prepare($query);
	$sth->execute($type, 1, $self->{list});
	 while ( ( my $email ) = $sth->fetchrow_array ) {
		my ($name, $domain) = split('@', $email); 
		if(!exists($domains->{$domain})){ 
			$domains->{$domain} = 0;
		}
		$domains->{$domain} = $domains->{$domain} + 1; 
	}
	$sth->finish; 
	
	# Sorted Index
	my @index = sort { $domains->{$b} <=> $domains->{$a} } keys %$domains; 
	
	# Top n
	my @top = splice(@index,0,($count-1));
	
	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $domains->{$_};
	}
	my $final = [];
	foreach(@top){ 
		push(@$final, {domain => $_, number => $domains->{$_}});
	}
	if($other > 0) { 
		push(@$final, {domain => 'other', number => $other}); 
	}
	
	# Return!
	return $final;

}

sub SQL_subscriber_profile_join_statement {

    warn 'at, ' . ( caller(0) )[3] if $t;
    
    my $self = shift;
    my ($args) = @_;

    if($t == 1){ 
        require Data::Dumper; 
        warn 'passed args:' . Data::Dumper::Dumper($args); 
    }
    # init vars:

    my $ls = DADA::MailingList::Settings->new({-list => $self->{list}}); 

    # type list black_List, white_listed, etc
    if ( !$args->{-type} ) {
        $args->{-type} = 'list';
    }

    # Sanity Check.
    if ( $self->allowed_list_types( $args->{-type} ) != 1 ) {
        croak '"' . $args->{-type} . '" is not a valid list type! ';
    }

    if ( !exists( $args->{-order_by}) || !defined($args->{-order_by}) ) {
            $args->{-order_by} = 'email';
    }
    if ( !exists( $args->{-order_dir} ) ) {
        $args->{-order_dir} = 'asc';
    }
    if(!exists($args->{-user_order_by})){ 
        $args->{-user_order_by} = 1; 
    }
    
    if(!exists($args->{-mass_mailing_params})) { 
        $args->{-mass_mailing_params} = 
        {
            -delivery_preferences => 'all', # individual, digest, all
        }; 
    }

	
    if(!exists($args->{-show_delivery_prefs_column})){ 
        $args->{-show_delivery_prefs_column} = 1; 
    }
	
	

    my $query_type = 'AND';
    if ( !$args->{-search_type} ) {
        $args->{-search_type} = 'all';
    }
    if ( $args->{-search_type} !~ /any|all/ ) {
        $args->{-search_type} = 'all';
    }
    if ( $args->{-search_type} eq 'any' ) {
        $query_type = 'OR';
    }
    
    if(!exists($args->{-select_fields})){ 
        $args->{-select_fields}->{':all'} = 1; 
    }

    my $subscriber_table       = $self->{sql_params}->{subscriber_table};
    my $profile_fields_table   = $self->{sql_params}->{profile_fields_table};
    my $profile_settings_table = $self->{sql_params}->{profile_settings_table};
    # We need the email and list from $subscriber_table
	
	# I'm not sure if "DISTINCT" is needed, anymore. 
    my $query;
	   $query = 'SELECT DISTINCT ';

    # This is to select which Profile Fields to return with our query
    my @merge_fields = (); 
    if($args->{-select_fields}->{'subscriber.timestamp'} == 1 || $args->{-select_fields}->{':all'} == 1){ 
        push(@merge_fields, $subscriber_table . '.timestamp');
    }
    if($args->{-select_fields}->{'subscriber.email'} == 1 || $args->{-select_fields}->{':all'} == 1){
        push(@merge_fields, $subscriber_table . '.email'); 
    }
    if($args->{-select_fields}->{'subscriber.list'} == 1 || $args->{-select_fields}->{':all'} == 1){ 
        push(@merge_fields, $subscriber_table . '.list'); 
    }
    foreach(@{ $self->subscriber_fields }) { 
        if($args->{-select_fields}->{'profile.' . $_} == 1 || $args->{-select_fields}->{':all'} == 1){
            push(@merge_fields, $profile_fields_table . '.' . $_)
        }
    }
	
	if($args->{-show_delivery_prefs_column} == 1) {
		# Delivery Prefs
	    if($ls->param('digest_enable') == 1){ 
			push(@merge_fields, $profile_settings_table . '.value as delivery_prefs_value');
		}
	}
	
    $query .= join(', ', @merge_fields); 


	# And we need to match this with the info in $profile_fields_table - this fast/slow?
    $query .=
        ' FROM '
      . $subscriber_table
      . ' LEFT OUTER JOIN '
      . $profile_fields_table . ' ON ';
    $query .= ' '
      . $subscriber_table
      . '.email' . ' = '
      . $profile_fields_table
      . '.email';	


      if($ls->param('digest_enable') == 1){ 
	  	$query .= ' LEFT JOIN ' 
		. $profile_settings_table . ' ON (' 
		. $subscriber_table .'.email = ' . $profile_settings_table . '.email AND '
		. $subscriber_table .'.list = ' . $profile_settings_table . '.list) ';
	}
	
    # Global Black List spans across all lists (yes, we're still using this).
    $query .= ' WHERE  ';
    if (   $DADA::Config::GLOBAL_BLACK_LIST
        && $args->{-type} eq 'black_list' )
    {

        #... Nothin'
    }
    else {
	    $query .=
	        $subscriber_table
	      . '.list = '
	      . $self->{dbh}->quote( $self->{list} ) . ' AND ';
    }

    # list_status is almost always 1
    $query .=
        $subscriber_table
      . '.list_type = '
      . $self->{dbh}->quote( $args->{-type} );
    $query .= ' AND '
      . $subscriber_table
      . '.list_status = '
      . $self->{dbh}->quote('1') . ' ';
      
    # This is all to query the $dada_profile_fields_table
    # The main thing, is that we only want the SQL statement to hold
    # fields that we're actually looking for.

    if ( keys %{ $args->{-partial_listing} } ) {

        warn q|keys %{ $args->{-partial_listing} }| if $t; 
        # This *really* needs its own method, as well...
        # It's somewhat strange, as this relies on the email address in the
        # profile (I think?) to work, if we're looking for email addresses...

        my @add_q      = ();

        for my $field( keys %{ $args->{-partial_listing} } ) {
			
			warn '$field ' . $field
			 if $t; 
			
			my @s_snippets = ();
			
            # This is to make sure we're always using the email from the
            # subscriber table - this stops us from not seeing an email
            # address that doesn't have a profile...
            my $table = $profile_fields_table;
            if ( $field eq 'email' ) {
                $table = $subscriber_table;
            }
            elsif ($field eq 'subscriber.timestamp') { 
                $table = $subscriber_table;             
            }

            next if ! exists($args->{-partial_listing}->{$field}->{-value});
            next if ! defined($args->{-partial_listing}->{$field}->{-value});
            next if           $args->{-partial_listing}->{$field}->{-value} eq '';

            
            my $search_op        = '';
            my $search_pre       = '';
            my $search_app       = '';
            my $search_binder    = '';
			my $add_is_null      = 0; 
			
            if($field ne 'subscriber.timestamp') { 
                if ( $args->{-partial_listing}->{$field}->{-operator} eq '=' ) {
                    $search_op     = '=';
                    $search_pre    = '';
                    $search_app    = '';
                    $search_binder = 'OR';
                }
                elsif ( $args->{-partial_listing}->{$field}->{-operator} eq 'LIKE' ) {
                    $search_op     = 'LIKE';
                    $search_pre    = '%';
                    $search_app    = '%';
                    $search_binder = 'OR';
                }
                elsif ( $args->{-partial_listing}->{$field}->{-operator} eq '!=' ) {
                    $search_op     = '!=';
                    $search_pre    = '';
                    $search_app    = '';
                    $search_binder = 'AND';
					$add_is_null   = 1; 
                }
                elsif ( $args->{-partial_listing}->{$field}->{-operator} eq 'NOT LIKE' ) {
                    $search_op     = 'NOT LIKE';
                    $search_pre    = '%';
                    $search_app    = '%';
                    $search_binder = 'AND';
					$add_is_null   = 1;
                }
									
                my @terms = split(',', $args->{-partial_listing}->{$field}->{-value} );
                foreach my $term(@terms) {
    				$term = strip($term); 
					
					my $query_snippet = 					
	                    $table . '.'
	                      . $field . ' '
	                      . $search_op . ' '
	                      . $self->{dbh}->quote(
	                            $search_pre
	                          . $term
	                          . $search_app
	                      );
					if($add_is_null == 1){ 
						
						$query_snippet .= 
							' OR ' 
							. $table 
							. '.'
							. $field 
							. ' IS NULL ' 
					}  
					  
                    push( @s_snippets, $query_snippet);
                }
    			 push( @add_q, '(' . join( ' ' . $search_binder . ' ', @s_snippets ) . ')' );
    		}
    		elsif($field eq 'subscriber.timestamp') { 
                my $timestamp_snippet = ''; 
                
                $timestamp_snippet = $table . '.timestamp >= ' 
                . $self->{dbh}->quote(
                        $args->{-partial_listing}->{$field}->{-rangestart}
                    )
                . ' AND '
                . $table . '.timestamp <= ' 
                . $self->{dbh}->quote(
                    $args->{-partial_listing}->{$field}->{-rangeend}
                ); 
                warn 'pushing timestamp snippit: ' . $timestamp_snippet
                    if $t;
                push( @add_q, $timestamp_snippet );
    		}
    		else { 
    		    # ... 
    		}
        }
       

	    my $query_pl;
	    if ( $add_q[0] ) {
	        $query_pl = ' AND ( ' . join( ' ' . $query_type . ' ', @add_q ) . ') ';
	        $query .= $query_pl;
	    }
	}
	else { 
	    warn 'no -partial_listing' 
	        if $t; 
	}

   # -exclude_from is to return results from subscribers who *aren't* subscribed
   # to another list.

    # A correlated subquery is a subquery that contains a reference to a
    # table that also appears in the outer query.

    if ( exists( $args->{-exclude_from} ) ) {
        if ( $args->{-exclude_from}->[0] ) {
            my @excludes = ();
            for my $ex_list ( @{ $args->{-exclude_from} } ) {
                push( @excludes, ' b.list = ' . $self->{dbh}->quote($ex_list) );
            }
            my $ex_from_query =
              ' AND NOT EXISTS (SELECT * FROM ' . $subscriber_table . ' b
			    WHERE ( '
              . join( ' OR ', @excludes )
              . ' ) AND '
              . $subscriber_table
              . '.email = b.email) ';
            $query .= $ex_from_query;
        }
    }    
    

#    require Data::Dumper; 
#    warn '$args->{-mass_mailing_params}' . Data::Dumper::Dumper($args->{-mass_mailing_params}); 
    
    my $digest_subq = ' AND EXISTS (SELECT * FROM ' . 
    $profile_settings_table . 
    ' WHERE ' . 
    $subscriber_table . 
    '.email = ' . 
    $profile_settings_table . 
    '.email AND ' .
    $profile_settings_table . 
    '.list = ' . $self->{dbh}->quote( $self->{list}). 
    ' AND ' . 
    $profile_settings_table . 
    '.setting = \'delivery_prefs\' AND ' .
    $profile_settings_table . 
    '.value = \'digest\') '; 
    
    my $individual_subq = ' AND NOT EXISTS (SELECT * FROM ' . 
    $profile_settings_table . 
    ' WHERE ' . 
    $subscriber_table . 
    '.email = ' . 
    $profile_settings_table . 
    '.email AND ' .
    $profile_settings_table . 
    '.list = ' . $self->{dbh}->quote( $self->{list}). 
    ' AND ' . 
    $profile_settings_table . 
    '.setting = \'delivery_prefs\' AND (' .
    $profile_settings_table . 
    '.value = ' . $self->{dbh}->quote("digest") . ' OR ' . $profile_settings_table . 
    '.value = ' . $self->{dbh}->quote("hold") .' ) ) ';
        
    if($args->{-mass_mailing_params}->{-delivery_preferences} eq 'digest'
        && $ls->param('digest_enable') == 1
    ){         
        $query .= $digest_subq; 
    }
    elsif($args->{-mass_mailing_params}->{-delivery_preferences} eq 'individual'
        && $ls->param('digest_enable') == 1
    ){        
        $query .= $individual_subq; 
    }

    if($args->{-user_order_by} == 1){ 
        if ( $args->{-order_by} eq 'email' ) {

            $query .=
                ' ORDER BY '
              . $subscriber_table
              . '.list, '
              . $subscriber_table
              . '.email';
        }
        elsif ( $args->{-order_by} eq 'timestamp' ) {
            $query .=
                ' ORDER BY '
              . $subscriber_table
              . '.list, '
              . $subscriber_table
              . '.timestamp';
        }
        elsif ( $args->{-order_by} eq 'delivery_prefs_value' ) {
            $query .=
            ' ORDER BY '
          . $subscriber_table
          . '.list, '
          . $profile_settings_table . '.value '
		}
        else {
            $query .=
                ' ORDER BY '
              . $subscriber_table
              . '.list, '
              . $profile_fields_table . '.'
              . $args->{-order_by};

        }
    	if($args->{-order_dir} eq 'desc'){ 
    		$query .= ' DESC'; 
    	}
    	else { 
    		$query .= ' ASC'; 
    	}
	}
	if(exists($args->{ -start }) && exists($args->{ '-length' })) { 
		$query .= ' LIMIT '; 
		$query .=  $args->{'-length'};
		$query .= ' OFFSET ';
		$query .= ($args->{ -start } * $args->{ '-length' });		
	}
	
    warn 'QUERY: ' . $query
             if $t;
    
    return $query;
}



sub SQL_subscriber_update_profiles_statement {
    
    my $self = shift; 
    my ($args) = @_; 

    my $u = $args->{-update_fields};
    
    # This should help things not be crazy slow. 
    $args->{-select_fields}->{'subscriber.email'} = 1; 
    $args->{-user_order_by} = 0; 
    $args->{-search_type}   = 'all'; 
    
    my $subscriber_table     = $self->{sql_params}->{subscriber_table};
    my $profile_fields_table = $self->{sql_params}->{profile_fields_table};
    
    my $inner_query = $self->SQL_subscriber_profile_join_statement($args); 
    
    my $query = 'UPDATE ' . $profile_fields_table . '  SET '; 

    foreach (keys %$u ){ 
        $query .= $_ . ' = ' . $self->{dbh}->quote($u->{$_}) . ','; 
    }
    # Remove that last comma, we should do the above, with a join() 
    # or a map() or something 
    
     
    $query  =~ s/\,$//; 
    $query .= ' WHERE email IN ( SELECT * FROM (';
    $query .= $inner_query;
    $query .= ') AS X)';     
        
    return $query; 
    
} 


sub update_profiles { 
    
    my $self = shift; 
    my ($args) = @_; 
    my $query = $self->SQL_subscriber_update_profiles_statement($args); 
    
    # die 'query: ' . $query; 
    
    my $sth = $self->{dbh}->prepare($query);

    my $rv = $sth->execute()
      or croak "cannot do statement (for profile_update)! $DBI::errstr\n";
    
      return $rv; 

}


sub fancy_print_out_list { 
    my $self = shift;
    my ($args) = @_;
    
    if ( !exists( $args->{ -FH } ) ) {
        $args->{ -FH } = \*STDOUT;
    }
    my $fh = $args->{ -FH };
    
    my($scrn, $subscribers_count) = $self->fancy_list($args); 
    e_print($scrn, $fh); 	
    
}



sub fancy_list {

    my $count = 0;

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -type } ) ) {
        croak
'you must supply the type of list we are looking at in, the "-type" parameter';
    }


    if ( !exists( $args->{ -partial_listing } ) ) {
        $args->{ -partial_listing } = {};
    }

	my $show_list_column = 0; 
	if(exists($args->{-show_list_column})){ 
		$show_list_column = $args->{-show_list_column}; 	
	}
	my $show_timestamp_column = 0; 
	if(exists($args->{-show_timestamp_column})){ 
		$show_timestamp_column = $args->{-show_timestamp_column}; 	
	}


    my $subscribers = $self->subscription_list($args);
    for (@$subscribers) {
        $_->{no_email_links}        = 1;
        $_->{no_checkboxes}         = 1;
        $_->{show_timestamp_column} = $show_timestamp_column, 
		$_->{show_list_column}      = $show_list_column, 
    }

    my $field_names = [];
    for ( @{ $self->subscriber_fields } ) {
        push ( @$field_names, { name => $_ } );
    }

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -screen => 'fancy_print_out_list_widget.tmpl',
            -vars   => {
                field_names           => $field_names,
                subscribers           => $subscribers,
                no_checkboxes         => 1,
                no_email_links        => 1,
                show_list_column      => $show_list_column, 
                show_timestamp_column => $show_timestamp_column, 
                count                 => scalar @{$subscribers},
            }, 
        }
    );
     
    return ($scrn, scalar @{$subscribers}); 

}

sub print_out_list {

    my $self = shift;
	my ($args) = @_; 

    my $ls = DADA::MailingList::Settings->new({-list => $self->{list}}); 
	
#	use Data::Dumper; 
#	warn 'args!' . Dumper($args); 
	
	my $r; 
	
	if(! exists($args->{-print_out})){ 
	    $args->{-print_out} = 1;
	}
	if(! exists($args->{-fh})){ 
			$args->{-fh} =  \*STDOUT;
	}
	if(! exists($args->{-type})){ 
		$args->{-type} = 'list'; 
	}	

	if(! exists($args->{-query})){ 
		$args->{-query} = undef; 
	}	

	if(! exists($args->{-show_timestamp_column})){ 
		$args->{-show_timestamp_column} = 1; 
	}	

	if(! exists($args->{-show_profile_fields})){ 
		$args->{-show_profile_fields} = 1; 
	}	
		
	if(! exists($args->{-show_delivery_prefs_column})){ 
		$args->{-show_delivery_prefs_column} = 1; 
	}
	
	# DEV: There's a reason for this tmp var, correct?
    my $fh = $args->{ -fh };

	#binmode $fh, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';

    my $count;
	my $query = ''; 

    if(exists($args->{-partial_listing})){ 
                
        $query = $self->SQL_subscriber_profile_join_statement(  
			{ 
		    -partial_listing            => $args->{-partial_listing},
	        -search_type                => 'all',
			-type                       => $args->{-type},
			-order_by                   => $args->{-order_by},
			-order_dir                  => $args->{-order_dir},
			-show_timestamp_column      => $args->{-show_timestamp_column}, 
			-show_delivery_prefs_column => $args->{-show_delivery_prefs_column},
			}
		);  
		
    }
	elsif(defined($args->{-query})){    
		my $partial_listing = {};
	    my $fields = $self->subscriber_fields;
	    for (@$fields) {
	        $partial_listing->{$_} = { 
	            -operator => 'LIKE',
                -value    => $args->{ -query },
	            };
	    }
	    # Do I have to do this, explicitly?
	    $partial_listing->{email} = { 
	        -operator => 'LIKE',
            -value    => $args->{ -query },
	    };

		$query = $self->SQL_subscriber_profile_join_statement(  
			{ 
		    -partial_listing            => $partial_listing,
	        -search_type                => 'any',
			-type                       => $args->{-type},
			-query                      => $args->{-query},
			-order_by                   => $args->{-order_by},
			-order_dir                  => $args->{-order_dir},
			-show_timestamp_column      => $args->{-show_timestamp_column}, 
			-show_delivery_prefs_column => $args->{-show_delivery_prefs_column},
			
            
			}
		);
	}
	else { 
	    $query =
	      $self->SQL_subscriber_profile_join_statement(
	        { 
				-type                       => $args->{-type}, 
				-show_timestamp_column      => $args->{-show_timestamp_column},
				-show_delivery_prefs_column => $args->{-show_delivery_prefs_column},
				
			} 
		);
	}

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (for print out list)! $DBI::errstr\n";

    my $fields = $self->subscriber_fields;

	# $DADA::Config::TEXT_CSV_PARAMS->{sep_char} = "\t";
    require Text::CSV;
    my $csv = Text::CSV->new(
		$DADA::Config::TEXT_CSV_PARAMS, 
	);

    my $hashref = {};


    my @header = ('email');
	
    if($args->{-show_timestamp_column} == 1){ 
        push(@header, 'timestamp'); 
    }
    
    if($args->{-show_profile_fields} == 1){
	    for (@$fields) {
	        push ( @header, $_ );
	    }
	}
	
	if($args->{-show_delivery_prefs_column} == 1) {
	    if($ls->param('digest_enable') == 1){ 
			push(@header, 'delivery_prefs_value');
		}
	}
	
    if ( $csv->combine(@header) ) {
        my $hstring = $csv->string;
        $r .= $hstring . "\n";

    }
    else {

        my $err = $csv->error_input;
        carp "combine() failed on argument: ", $err, "\n";

    }

    while ( $hashref = $sth->fetchrow_hashref ) {
        
		# Email!
		my @info = ( $hashref->{email} );
		
		# Timestamp!
        if($args->{-show_timestamp_column} == 1){ 
            push(@info, $hashref->{timestamp}); 
        }
		
		# Profile Fields!
		if($args->{-show_profile_fields} == 1){
	        for (@$fields) {
	            $hashref->{$_} =~ s/\n|\r/ /gi;
	            push ( @info, $hashref->{$_} );
	        }
		}
		
		# Delivery Prefs!
		if($args->{-show_delivery_prefs_column} == 1) {		
		    if($ls->param('digest_enable') == 1){ 
				push(@info, $hashref->{delivery_prefs_value});
	        }
		}
		
        if ( $csv->combine(@info) ) {
            my $string = $csv->string;
            $r .= $string . "\n";
        }
        else {
            my $err = $csv->error_input;
            carp "combine() failed on argument: "
              . $csv->error_input
              . " attempting to encode values and try again...";
              
            require CGI;

            my @new_info = ();
            for my $chunk (@info) {
                push ( @new_info, CGI::escapeHTML($chunk) );
            }
            if ( $csv->combine(@new_info) ) {
                my $hstring2 = $csv->string;
                $r .= $hstring2 . "\n";
            }
            else {
                carp "combine() failed on argument: "
                  . $csv->error_input;
            }
        }
        $count++;
    }

    $sth->finish;
    if($args->{-print_out} == 1){ 
        print $fh $r;
    }
    else { 
        return $r; 
    }
        
    
}

sub clone {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-from} ) ) {
        croak "Need to pass the, '-from' (list type) parameter!";
    }
    if ( !exists( $args->{-to} ) ) {
        croak "Need to pass the, '-from' (list type) parameter!";
    }
    if ( $self->allowed_list_types( $args->{-from} ) == 0 ) {
        croak $args->{-from} . " is not a valid list type!";
    }
    if ( $self->allowed_list_types( $args->{-to} ) == 0 ) {
        croak $args->{-to} . " is not a valid list type!";
    }

    # First we see if there's ANY current members in this list;
    if ( $self->num_subscribers( { -type => $args->{-to} } ) > 0 ) {
        carp
"CANNOT clone a list subtype to another list subtype that already exists!";
        return undef;
    }
    else {
        my $query =
            'INSERT INTO '
          . $self->{sql_params}->{subscriber_table}
          . '(email, list, list_type, list_status) SELECT email, "' . $self->{list} . '", "'. $args->{-to}. '", 1 FROM ' . $self->{sql_params}->{subscriber_table} . ' WHERE list = ? AND list_type = ? AND list_status = ?';
        my $sth = $self->{dbh}->prepare($query);
        $sth->execute( $self->{list}, $args->{-from}, 1 )
        or croak "cannot do statement! $DBI::errstr\n";
    }

    return 1;

}


sub subscription_list {
        
    my $self = shift;

    warn 'subscription_list'
     if $t; 

    my $st = time; 

    my ($args) = @_;
    if ( !exists( $args->{-start} ) ) {
        $args->{-start} = 0;
    }
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }

    my $email;
    my $count  = 0;
    my $list   = [];
    my $fields = $self->subscriber_fields;

    if ( !exists( $args->{-partial_listing} ) ) {
        $args->{-partial_listing} = {};
    }

    my $query = $self->SQL_subscriber_profile_join_statement($args);
    my $sth   = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (for subscription_list)! $DBI::errstr\n";

    my $hashref;
    my %mf_lt = ();
    for (@$fields) {
        $mf_lt{$_} = 1;
    }

    while ( $hashref = $sth->fetchrow_hashref ) {
        # Probably, just add it here?
        $hashref->{type} = $args->{-type};

        $hashref->{fields} = [];

        for (@$fields) {

            if ( exists( $mf_lt{$_} ) ) {
                push(
                    @{ $hashref->{fields} },
                    {
                        name  => $_,
                        value => $hashref->{$_}
                    }
                );
                delete( $hashref->{$_} );
            }

        }

        push( @$list, $hashref );

    }

    my $et = time; 
    
    warn 'subscription_list time:' . ($et - $st) . ' seconds.'
        if $t;

    return $list;

}


sub filter_list_through_blacklist {


	# This makes no sense - why not just use a query that looks for unique addresses, 
	# that are in both sublists?
	
    my $self = shift;
    my $list = [];

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = 'black_list' AND list_status = " . $self->{dbh}->quote('1');

    if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

        # Nothin'
    }
    else {
        $query .= ' AND list = ?';
    }

    my $sth = $self->{dbh}->prepare($query);

    if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

        $sth->execute()
          or croak
          "cannot do statement (filter_list_through_blacklist)! $DBI::errstr\n";

    }
    else {

        $sth->execute( $self->{list} )
          or croak
          "cannot do statement (filter_list_through_blacklist)! $DBI::errstr\n";
    }

    my $hashref;
    my $hashref2;

    # Hmm. This seems a little... expensive.

    while ( $hashref = $sth->fetchrow_hashref ) {

        my $query2 =
          'SELECT * from '
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list_type   = 'list' 
		               AND   list_status =  '1'
		               AND   list        =   ? 
		               AND   email      LIKE ?";

        my $sth2 = $self->{dbh}->prepare($query2);
        $sth2->execute( $self->{list}, '%' . $hashref->{email} . '%' )
          or croak
          "cannot do statement (filter_list_through_blacklist)! $DBI::errstr\n";

        while ( $hashref2 = $sth2->fetchrow_hashref ) {
            push ( @$list, $hashref2 );
        }

    }

    return $list;

}

# DEV: This is in need of a rewrite.
# Too bad it works *as is*
# but, it's messy stuff.

sub check_for_double_email {

    my $self = shift;
    my %args = (
        -Email      => undef,
        -Type       => 'list',
        -Status     => 1,
        -Match_Type => 'sublist_centric', # hello, I am bizarre. It's very nice to meet you!
        @_
    );
    my @list;

    if ( $self->{list} and $args{ -Email } ) {

        $args{ -Email } = strip( $args{ -Email } );
        $args{ -Email } = cased( $args{ -Email } );

        if (   $args{ -Type } eq 'black_list'
            && $args{ -Match_Type } eq 'sublist_centric' )
        {
			my $m = $self->inexact_match(
				{
					-against => 'black_list', 
					-email => $args{-Email},
				}
			);
			if($m == 1){ 
				return $m; 
			}
            return 0;

        }

        elsif ($args{ -Type } eq 'white_list'
            && $args{ -Match_Type } eq 'sublist_centric' )
        {
			my $m = $self->inexact_match(
				{
					-against => 'white_list', 
					-email => $args{-Email},
				}
			);
			if($m == 1){ 
				return $m; 
			}
            return 0;
        }
		
		elsif ($args{ -Type } eq 'ignore_bounces_list'
		            && $args{ -Match_Type } eq 'sublist_centric' ) {
			my $m = $self->inexact_match(
				{
					-against => 'ignore_bounces_list', 
					-email => $args{-Email},
				}
			);
			if($m == 1){ 
				return $m; 
			}
	        return 0;
	    }
				
        else {
            my $sth =
              $self->{dbh}->prepare( "SELECT email FROM "
                  . $self->{sql_params}->{subscriber_table}
                  . " WHERE list = ? AND list_type = ? AND email= ? AND list_status = ?"
              );

            $sth->execute(
                $self->{list},
                $args{ -Type },
                $args{ -Email },
                $args{ -Status }
              )
              or croak
              "cannot do statement (for check for double email)! $DBI::errstr\n";
            while ( ( my $email ) = $sth->fetchrow_array ) {
                push ( @list, $email );
            }
            my $in_list = 0;
            if ( $list[0] ) {
                $in_list = 1;
            }
            $sth->finish;
            return $in_list;
        }
    }
    else {
        return 0;
    }
}

sub num_subscribers {

    my $self   = shift;
    my ($args) = @_; 
	if(! exists($args->{-type})){ 
		$args->{-type} = 'list';
	} 
	
    my @row;

    my $query = '';
my $sth = $self->{dbh}->prepare('SELECT * FROM ' . $self->{sql_params}->{subscriber_table});
$sth->execute(); 

    $query .= 'SELECT COUNT(*) ';
    $query .= ' FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE list_type = ? AND list_status = ' . $self->{dbh}->quote('1');

	# I'm sort of guessing, that it's a good idea to do... this!
	if (   $args->{-type} eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {
        # ...
    }
    else {
        $query .= ' AND list = ' . $self->{dbh}->quote($self->{list});
    }
	
    my $count = $self->{dbh}->selectrow_array($query, undef,  $args->{-type}); 
	return $count;

}




sub remove_all_subscribers {

    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{-type} ) {
        $args->{-type} = 'list';
    }

    my $query =
        'SELECT email FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = ? AND list_status = ? AND list = ?";
    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-type}, 1, $self->{list} )
      or croak
      "cannot do statement (at remove_all_subscribers)! $DBI::errstr\n";

    my $count = 0;
    while ( ( my $email ) = $sth->fetchrow_array ) {
        $self->remove_subscriber(
            {
                -email => $email,
                -type  => $args->{-type},
            }
        );
        $count++;
    }

    return $count;
}




sub copy_all_subscribers { 
	
	my $self   = shift ;
	my ($args) = @_; 
	my $total  = 0; 
	if(! exists($args->{-from})){ 
		croak "you MUST pass '-from'";
	}
	else { 
		if ( $self->allowed_list_types( $args->{-from} ) != 1 ) {
            croak '"' . $args->{ -from } . '" is not a valid list type! ';
        }
	}
	if(! exists($args->{-to})){ 
		croak "you MUST pass '-to'";
	}
	else { 
		if ( $self->allowed_list_types( $args->{-to} ) != 1 ) {
            croak '"' . $args->{ -to } . '" is not a valid list type! ';
        }	
	}
	
	my $query = 'SELECT email from ' . $self->{sql_params}->{subscriber_table} . ' WHERE list = ? AND list_type = ?'; 	
	my $sth   = $self->{dbh}->prepare($query); 
	$sth->execute($self->{list}, $args->{-from})
      or croak "cannot do statement $DBI::errstr\n";
	
	while ( ( my $email ) = $sth->fetchrow_array ) {
         chomp($email);
		 my $n_sub = $self->add_subscriber(
			{
				-email         => $email,
				-type          => $args->{-to}, 
				-dupe_check    => {
									-enable  => 1, 
									-on_dupe => 'ignore_add',  
            					},
			}
		 );
		if(defined($n_sub)){ 
			$total++; 
		}
	}
	
	return $total; 
}




sub create_mass_sending_file {
	
    my $self = shift;

    my %args = (
        -Type                => 'list',
        -Pin                 => 1,
        -ID                  => undef,
        -Ban                 => undef,
        -Save_At             => undef,
        -partial_sending     => {},
        -mass_mailing_params => {},
        -exclude_from        => [],
        @_
    );

	# use Data::Dumper; 
	# warn 'create_mass_sending_file args: ' . Dumper({%args});

	my $b_time = time; 
	
    my $list = $self->{list};
    my $type = $args{-Type};
	
	warn '$type: ' . $type 
		if $t; 
		
    my @f_a_lists = available_lists();
    my %list_names;
    for (@f_a_lists) {
        my $als = DADA::MailingList::Settings->new( { -list => $_ } );
        my $ali = $als->get;
        $list_names{$_} = $ali->{list_name};
    }

    $list =~ s/ /_/g;    # really...


    my ( $sec, $min, $hour, $day, $month, $year ) =
      (localtime)[ 0, 1, 2, 3, 4, 5 ];
    my $message_id = sprintf(
        "%02d%02d%02d%02d%02d%02d",
        $year + 1900,
        $month + 1, $day, $hour, $min, $sec
    );

    #use the message ID, If we have one.
    my $letter_id = $args{'-ID'} || $message_id;
    $letter_id =~ s/\@/_at_/g;
    $letter_id =~ s/\>|\<//g;

    my $n_msg_id = $args{'-ID'} || $message_id;
    $n_msg_id =~ s/\<|\>//g;
    $n_msg_id =~ s/\.(.*)//;    #greedy

    my %banned_list;

    if ( $args{-Ban} ) {
        my $banned_list = $args{-Ban};
        $banned_list{$_} = 1 for (@$banned_list);
    }

    my $list_file =
      make_safer( $DADA::Config::FILES . '/' . $list . '.' . $type );
    my $sending_file = make_safer( $args{-Save_At} )
      || make_safer(
        $DADA::Config::TMP . '/msg-' . $list . '-' . $type . '-' . $letter_id );

    #open one file, write to the other.
    my $email;

    open my $SENDINGFILE, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      $sending_file
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Cannot create temporary email list file for sending out bulk message: $!";
    chmod( $SENDINGFILE, $DADA::Config::FILE_CHMOD );
    flock( $SENDINGFILE, LOCK_EX );


	my $have_first_recipient = 1; 
	if($self->{ls}->param('mass_mailing_send_to_list_owner') == 0) {
		$have_first_recipient = 0; 
	}
	# Sending these types of messages to the list owner is very confusing
	# "test" tmp lists should still have the list owner if, "mass_mailing_send_to_list_owner" is still set to , "1"
	elsif($type =~ m/_tmp\-just_subscribed\-|_tmp\-just_unsubscribed\-|_tmp\-just_subed_archive\-/){ 
		$have_first_recipient = 0; 		
	}
	elsif($type =~ m/invite_list/){ 
		$have_first_recipient = 0; 			
	}

    require     Text::CSV;
    my $csv   = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
    my $total = 0;
            
	if($have_first_recipient == 1){ 
	    my $first_email = $self->{ls}->param('list_owner_email');
	    my ( $lo_e_name, $lo_e_domain ) = split( '@', $first_email );

	    my @lo  = (
	        $first_email, 
			$lo_e_name, 
			$lo_e_domain, 
			$self->{list},
	        $list_names{ $self->{list} }, 
			$n_msg_id,
	    );

	# To add to @lo, I want to bring up the Dada Profile and see if there's anything
	# in there...
	    if ( $DADA::Config::PROFILE_OPTIONS->{enabled} == 1 ) {
	        require DADA::Profile;
	        my $dp = DADA::Profile->new( { -email => $first_email } );
	        if ( $dp->exists() ) {
	            require DADA::Profile::Fields;
	            my $dpf = DADA::Profile::Fields->new( { -email => $first_email } );
	            my $fields               = $dpf->{manager}->fields;
	            my $profile_field_values = $dpf->get;
	            for (@$fields) {
	                push( @lo, $profile_field_values->{$_} );
	            }
	        }
	    }

	    if ( $csv->combine(@lo) ) {
	        my $hstring = $csv->string;
	        print $SENDINGFILE $hstring, "\n";
			#warn '[Adding to Sending File:]' . $hstring;
	    }
	    else {
	        my $err = $csv->error_input;
	        carp "combine() failed on argument: ", $err, "\n";
	    }
	    $total++;
	}
	
    my $query = $self->SQL_subscriber_profile_join_statement(
        {
            -type                => $args{-Type},
            -partial_listing     => $args{-partial_sending},
            -mass_mailing_params => $args{-mass_mailing_params},
            -exclude_from        => $args{-exclude_from},
        }
    );

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak
      "cannot do statement (at create mass_sending_file)! $DBI::errstr\n";

    my $field_ref;

    while ( $field_ref = $sth->fetchrow_hashref ) {

        chomp $field_ref->{email};    #new..

        unless ( exists( $banned_list{ $field_ref->{email} } ) ) {

            my @sub = (
                $field_ref->{email},
                ( split( '@', $field_ref->{email} ) ), # 2..
                $field_ref->{list},
                $list_names{ $field_ref->{list} },
                $n_msg_id,
            );

            for ( @{ $self->subscriber_fields } ) {
                if ( defined( $field_ref->{$_} ) ) {
                    chomp $field_ref->{$_};
                    $field_ref->{$_} =~ s/\n|\r/ /g;
                }
                else {
                    $field_ref->{$_} = '';
                }

                push( @sub, $field_ref->{$_} );
            }

            if ( $csv->combine(@sub) ) {
                my $hstring = $csv->string;
                print $SENDINGFILE $hstring, "\n";
				# warn '[Adding to Sending File(2):]' . $hstring;
            }
            else {
                my $err = $csv->error_input;
                carp "combine() failed on argument: ", $err, "\n";
            }
            $total++;
        }

    }

    $sth->finish;


    close($SENDINGFILE)
      or croak(
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - could not close temporary sending  file '$sending_file' successfully"
      );

	if($t){ 
		warn "Mass Sending File Time Creation: " . (time - $b_time) . " seconds."; 
	}
	

    return ( $sending_file, $total );

}

sub unique_and_duplicate {

    my $self = shift;

    my %args = (
        -New_List => undef,
        -Type     => 'list',
        @_,
    );

    # first thing we got to do is to make a lookup hash.
    my %lookup_table;
    my $address_ref = $args{ -New_List };

    if ($address_ref) {
        
        for (@$address_ref) { 
            $lookup_table{$_} = 0 
        }

        my $email;

        my $sth = $self->{dbh}->prepare(
            "SELECT email FROM "
              . $self->{sql_params}->{subscriber_table}
              . " WHERE list         = ? 
                  AND list_type      = ?
                  AND  list_status   = '1'"
        );
        $sth->execute( $self->{list}, $args{ -Type } )
          or croak
          "cannot do statement (at unique_and_duplicate)! $DBI::errstr\n";
        while ( ( my $email ) = $sth->fetchrow_array ) {
            chomp($email);
            $lookup_table{$email} = 1 if ( exists( $lookup_table{$email} ) );
            #nabbed it,
        }
        $sth->finish;

        #lets lookie and see what we gots.
        my @unique;
        my @double;
        my $value;

        for ( keys %lookup_table ) {
            $value = $lookup_table{$_};
            if ( $value == 1 ) {
                push ( @double, $_ );
            }
            else {
                push ( @unique, $_ );
            }
        }
        return ( \@unique, \@double );
    }
    else {

        carp(
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: array ref provided!"
        );
        return undef;
    }

}

sub tables {
    my $self   = shift;
    my @tables = $self->{dbh}->tables();
    return \@tables;
}

sub remove_this_listtype {
    my $self = shift;
    my ($args) = @_; 

    if ( !exists( $args->{ -type } ) ) {
        croak('You MUST specific a list type in the "-type" parameter');
    }
    else {
        if ( $self->allowed_list_types( $args->{ -type } ) != 1 ) {
            croak '"' . $args->{ -type } . '" is not a valid list type! ';
        }
    }

    my $sth = $self->{dbh}->prepare(
        "DELETE FROM "
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list    = ?
		                              AND list_type = ?"
    );
    $sth->execute( $self->{list}, $args->{ -type } )
      or croak
      "cannot do statement! (at: remove_this_listttype) $DBI::errstr\n";
    $sth->finish;

	return 1; 
}

sub can_use_global_black_list {

    my $self = shift;
    return 1;

}

sub can_use_global_unsubscribe {

    my $self = shift;
    return 1;

}

sub can_filter_subscribers_through_blacklist {

    my $self = shift;
    return 1;
}

sub can_have_subscriber_fields {

    my $self = shift;
    return 1;
}

sub DESTROY {}


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

=item * invite_list

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

=item * invite_list

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

Justin Simoni https://dadamailproject.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1999 - 2023 Justin Simoni All rights reserved. 

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

