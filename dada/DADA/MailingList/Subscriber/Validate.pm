package DADA::MailingList::Subscriber::Validate;

use lib qw (../../../ ../../../DADA/perllib);
use strict;
use Carp qw(carp croak);

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

    $self->{list} = $args->{ -list };
    if ( exists( $args->{ -lh_obj } ) ) {
        $self->{lh} = $args->{ -lh_obj };
    }
    else {
        require DADA::MailingList::Subscribers;
        my $lh =
          DADA::MailingList::Subscribers->new( { -list => $args->{ -list } } );
        $self->{lh} = $lh;
    }

}

sub subscription_check {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        $args->{-email} = '';
    }
    my $email = $args->{-email};
    
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'list';
    }
    if ( !exists( $args->{-fields} ) ) {
        $args->{-fields} = {};
    }
    
    if(! exists($args->{-skip})) { 
        $args->{-skip} = [];
    }
    if(! exists($args->{-mode})) { 
        $args->{-mode} = 'user';
    }
    
    my %skip;
    for(@{ $args->{-skip} }) { 
        $skip{$_} = 1;
    }
    
    my $errors = {};
    my $status = 1;

    require DADA::App::Guts;
    require DADA::MailingList::Settings;

    if ( !$skip{no_list} ) {
        if ( DADA::App::Guts::check_if_list_exists( -List => $self->{list} ) == 0 ) {
            $errors->{no_list} = 1;
            return ( 0, $errors );
        }
    }

    my $ls = undef;
    if(exists($args->{-ls_obj})){ 
           $ls = $args->{-ls_obj};
    }
    else{ 
        $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    } 
    
    if ( $args->{-type} ne 'black_list' && $args->{-type} ne 'white_list' ) {
        if ( !$skip{invalid_email} ) {
            $errors->{invalid_email} = 1
              if DADA::App::Guts::check_for_valid_email($email) == 1;
        }
    }
    else {
        if ( DADA::App::Guts::check_for_valid_email($email) == 1 ) {
            if ( $email !~ m/^\@|\@$/ ) {
                $errors->{invalid_email} = 1;
            }
        }
    }
    
    if ( !$skip{subscribed} ) {
        $errors->{subscribed} = 1
          if $self->{lh}->check_for_double_email(
            -Email => $email,
            -Type  => $args->{-type}
          ) == 1;
    }

    if (   $args->{-type} ne 'black_list'
        || $args->{-type} ne 'authorized_senders'
        || $args->{-type} ne 'moderators' )

      # uh... white listed?!
    {

        if ( !$skip{invite_only_list} ) {
            $errors->{invite_only_list} = 1 if $ls->param('invite_only_list') == 1;
        }

        if ( !$skip{closed_list} ) {
            $errors->{closed_list} = 1 if $ls->param('closed_list') == 1;
        }
    }

    if ( $args->{-type} ne 'black_list' ) {
        if ( !$skip{mx_lookup_failed} ) {
            if ( $ls->param('mx_check') == 1 ) {
                require Email::Valid;
                eval {
                    unless (
                        Email::Valid->address(
                            -address => $email,
                            -mxcheck => 1
                        )
                      )
                    {
                        $errors->{mx_lookup_failed} = 1;
                    }
                    if ($@) {
                        carp "warning: mx check didn't work: $@, for email, '$email' on list, '" . $self->{list} . "'";
                    }
                };
            }
        }
    }
    
    
    # When -usermode is set to, this is where, "allow_blacklisted_to_subscribe" should be checked 
    # similar for admin
    #
    if ( $args->{-type} ne 'black_list' ) {
        if ( !$skip{black_listed} ) {
            if ( $ls->param('black_list') == 1 ) {
                $errors->{black_listed} = 1
                  if $self->{lh}->check_for_double_email(
                    -Email => $email,
                    -Type  => 'black_list'
                  ) == 1;
            }
        }
    }

    if ( $args->{-type} ne 'white_list' ) {
        if ( !$skip{not_white_listed} ) {

            if ( $ls->param('enable_white_list') == 1 ) {

                $errors->{not_white_listed} = 1
                  if $self->{lh}->check_for_double_email(
                    -Email => $email,
                    -Type  => 'white_list'
                  ) != 1;
            }
        }
    }

    if (   $args->{-type} ne 'black_list'
        || $args->{-type} ne 'authorized_senders'
        || $args->{-type} ne 'moderators' )
    {
        if ( !$skip{over_subscription_quota} ) {
            my $num_subscribers = $self->{lh}->num_subscribers;
            if ( $ls->param('use_subscription_quota') == 1 ) {
                if ( ( $num_subscribers + 1 ) >= $ls->param('subscription_quota') ) {
                    $errors->{over_subscription_quota} = 1;
                }
            }
            elsif (defined($DADA::Config::SUBSCRIPTION_QUOTA)
                && $DADA::Config::SUBSCRIPTION_QUOTA > 0
                && $num_subscribers + 1 >= $DADA::Config::SUBSCRIPTION_QUOTA )
            {
                $errors->{over_subscription_quota} = 1;
            }
        }
    }

    if ( !$skip{already_sent_sub_confirmation} ) {
        if ( $ls->param('limit_sub_confirm') == 1 ) {
            if( $self->{lh}->check_for_double_email(-Email => $email, -Type  => 'sub_confirm_list') == 1) { 
                  $errors->{already_sent_sub_confirmation} = 1;
              }
        }
    }

    if ( !$skip{settings_possibly_corrupted} ) {
        if ( !$ls->perhapsCorrupted ) {
            $errors->{settings_possibly_corrupted} = 1;
        }
    }
    
    if ( $args->{-type} eq 'list') {
        # Profile Fields
        if(!$skip{profile_fields}) { 
        
            
            require DADA::ProfileFieldsManager; 
            my $dpfm = DADA::ProfileFieldsManager->new; 
            my $dpf_att = $dpfm->get_all_field_attributes;        
            my $fields = $dpfm->fields; 
        
            for my $field_name(@{$fields}) {     
                my $field_name_status = 1; 
                if($dpf_att->{$field_name}->{required} == 1){ 
                    if(exists($args->{-fields}->{$field_name})){ 
                        if(defined($args->{-fields}->{$field_name}) && $args->{-fields}->{$field_name} ne ""){ 
                            #... Well, that's good! 
                        }
                        else { 
                            if ($args->{-mode} eq 'user' &&  $field_name =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/) {
                                # Well, then that's OK too: users can't fill in hidden fields
                            }
                            else { 
                                $field_name_status = 0; 
                            }
                        }
                    }
                    else { 
                        if ($args->{-mode} eq 'user' &&  $field_name =~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/) {
                            # Well, then that's OK too: users can't fill in hidden fields
                        }
                        else { 
                            $field_name_status = 0; 
                        }
                    }
                }
                if($field_name_status == 0){ 
                    # We do this, so when we add things like "type checking" we don't
                    # have to redo everything again.
                    $errors->{invalid_profile_fields}->{$field_name}->{required} = 1; 
                }
            }
            
            if(exists($errors->{invalid_profile_fields})){ 
                # This is going to be more expensive, than just seeing if some value is passed, 
                # But I guess the policy is, if the profile already exists, then it doens't matter 
                # if these fields are empty  as they were already empty! 
                #
                # I'd rather this look at Profile, rather than the fields of Profiles, which can easily be 
                # orphans, if Fields are saved, but profiles aren't, (say, when you're subscribing via the 
                # list control panel - d'oh!) 
                #
                #
                if(! exists($errors->{invalid_email})){ 
                    require    DADA::Profile::Fields; 
                    my $dpf = DADA::Profile::Fields->new({
    					-dpfm_obj => $dpfm, 
    				});
                    if($dpf->exists({-email => $email})){ 
                        # Nevermind. 
                        $errors->{invalid_profile_fields} = undef;
                        delete($errors->{invalid_profile_fields}); 
                        undef($dpf); 
                    } 
                }
            }
        }
    }
    
    for my $error_name( keys %{$errors} ) {
        if($error_name ne 'invalid_profile_fields') {
            if ($errors->{$error_name} == 1) { 
                $status = 0;
                last;
            }
        }
        elsif(keys %{$errors->{$error_name}} ) { # invalid_profile_fields
            $status = 0;             
            last;
            
        }
    }
    
    return ( $status, $errors );

}

sub unsubscription_check {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -email } ) ) {
        $args->{ -email } = '';
    }
    my $email = $args->{ -email };

    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }

    my %errors = ();
    my $status = 1;

    if ( !exists( $args->{ -skip } ) ) {
        $args->{ -skip } = [];
    }
    my %skip;
    $skip{$_} = 1 for @{ $args->{ -skip } };

    require DADA::App::Guts;
    require DADA::MailingList::Settings;

    if ( !$skip{no_list} ) {
        $errors{no_list} = 1
          if DADA::App::Guts::check_if_list_exists( -List => $self->{list} ) ==
          0;
        return ( 0, \%errors ) if $errors{no_list} == 1;
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    if ( !$skip{invalid_email} ) {
        $errors{invalid_email} = 1
          if DADA::App::Guts::check_for_valid_email($email) == 1;
    }

    if ( !$skip{not_subscribed} ) {
        $errors{not_subscribed} = 1
          if $self->{lh}->check_for_double_email( -Email => $email ) != 1;
    }

    if ( !$skip{already_sent_unsub_confirmation} ) {
        my $li = $ls->get;
        if ( $li->{limit_sub_confirm} == 1 ) {
            $errors{already_sent_unsub_confirmation} = 1
              if $self->{lh}->check_for_double_email(
                -Email => $email,
                -Type  => 'unsub_confirm_list'
              ) == 1;
        }
    }

    if ( !$skip{settings_possibly_corrupted} ) {
        if ( !$ls->perhapsCorrupted ) {
            $errors{settings_possibly_corrupted} = 1;
        }
    }

    for ( keys %errors ) {
        $status = 0 if $errors{$_} == 1;
        last;
    }

    return ( $status, \%errors );

}

1;
