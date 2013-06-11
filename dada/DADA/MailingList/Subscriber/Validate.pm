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

    if ( !exists( $args->{ -email } ) ) {
        $args->{ -email } = '';
    }
    my $email = $args->{ -email };

    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }

    my %skip;
    $skip{$_} = 1 for @{ $args->{ -skip } };

    my %errors = ();
    my $status = 1;

    require DADA::App::Guts;
    require DADA::MailingList::Settings;

    if ( !$skip{no_list} ) {
        if ( DADA::App::Guts::check_if_list_exists( -List => $self->{list} ) ==
            0 )
        {
            $errors{no_list} = 1;
            return ( 0, \%errors );
        }
    }

    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    my $list_info = $ls->get;

    if ( $args->{ -type } ne 'black_list' ) {
        if ( !$skip{invalid_email} ) {
            $errors{invalid_email} = 1
              if DADA::App::Guts::check_for_valid_email($email) == 1;
        }
    }

    if ( !$skip{subscribed} ) {
        $errors{subscribed} = 1
          if $self->{lh}->check_for_double_email(
            -Email => $email,
            -Type  => $args->{ -type }
          ) == 1;
    }

    if (   $args->{ -type } ne 'black_list'
        || $args->{ -type } ne 'authorized_senders' )
		# uh... white listed?!
    {
	
		if ( !$skip{invite_only_list} ) {
            $errors{invite_only_list} = 1 if $list_info->{invite_only_list} == 1;
        }

        if ( !$skip{closed_list} ) {
            $errors{closed_list} = 1 if $list_info->{closed_list} == 1;
        }
    }

    if ( $args->{ -type } ne 'black_list' ) {
        if ( !$skip{mx_lookup_failed} ) {
            if ( $list_info->{mx_check} == 1 ) {
                require Email::Valid;
                eval {
                    unless (
                        Email::Valid->address(
                            -address => $email,
                            -mxcheck => 1
                        )
                      )
                    {
                        $errors{mx_lookup_failed} = 1;
                    }
					if( $@ ) { 
                    	carp "warning: mx check didn't work: $@, for email, '$email' on list, '" . $self->{list} . "'";
					}
                };
            }
        }
    }

    if ( $args->{ -type } ne 'black_list' ) {
        if ( !$skip{black_listed} ) {
            if ( $list_info->{black_list} eq "1" ) {
                $errors{black_listed} = 1
                  if $self->{lh}->check_for_double_email(
                    -Email => $email,
                    -Type  => 'black_list'
                  ) == 1;
            }
        }
    }

    if ( $args->{ -type } ne 'white_list' ) {
        if ( !$skip{not_white_listed} ) {

            if ( $list_info->{enable_white_list} == 1 ) {

                $errors{not_white_listed} = 1
                  if $self->{lh}->check_for_double_email(
                    -Email => $email,
                    -Type  => 'white_list'
                  ) != 1;
            }
        }
    }

    if (   $args->{ -type } ne 'black_list'
        || $args->{ -type } ne 'authorized_senders' )
    {
        if ( !$skip{over_subscription_quota} ) {
			my $num_subscribers = $self->{lh}->num_subscribers; 
            if ( $list_info->{use_subscription_quota} == 1 ) {
                if ( ( $num_subscribers + 1 ) >=
                    $list_info->{subscription_quota} )
                {
                    $errors{over_subscription_quota} = 1;
                }
            }
			elsif(defined($DADA::Config::SUBSCRIPTION_QUOTA)
				&& $DADA::Config::SUBSCRIPTION_QUOTA > 0
				&& $num_subscribers + 1 >= $DADA::Config::SUBSCRIPTION_QUOTA
			){			
				$errors{over_subscription_quota} = 1;
            }
        }
    }

    if ( !$skip{already_sent_sub_confirmation} ) {
        if ( $list_info->{limit_sub_confirm} == 1 ) {
            $errors{already_sent_sub_confirmation} = 1
              if $self->{lh}->check_for_double_email(
                -Email => $email,
                -Type  => 'sub_confirm_list'
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
