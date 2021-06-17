package DADA::App::WebServices;
use strict;

use lib qw(./ ../ ../../ ../../DADA ../perllib);

use Carp qw(carp croak);
$CARP::Verbose = 1;

use DADA::Config qw(!:DEFAULT);
use JSON;
use DADA::Config;
use DADA::App::Guts;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use Digest::SHA qw(hmac_sha256_base64);
use Try::Tiny;

use CGI (qw/:oldstyle_urls/);
my $calculated_digest = undef;

use vars qw($AUTOLOAD);

my $t = 1;    #$DADA::Config::DEBUG_TRACE->{DADA_App_WebServices};

my %allowed = (
    test => 0,

    ls_obj => undef,

    r_list            => undef,
    r_service         => undef,
    r_public_key      => undef,
    r_digest          => undef,
    r_cgi_obj         => undef,
    global_level      => undef,
    i_private_api_key => undef,

);

sub new {
    my $that  = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my %args = (@_);

    $self->_init( \%args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    return if ( substr( $AUTOLOAD, -7 ) eq 'DESTROY' );

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {
    my $self = shift;
    $self->{q} = CGI->new;
}

sub request {
    my $self   = shift;
    my $status = 1;
    my $errors = {};
    my ($args) = @_;

    for ( '-list', '-service', '-public_key', '-digest', '-cgi_obj' ) {

        my $param = $_;
        $param =~ s/^\-//;

        if ( !exists( $args->{$_} ) ) {
            $status = 0;
            $errors->{ 'missing_' . $param } = 1;
            warn 'passed param: ' . $_ . ' => ' . $param
              if $t;
        }
        else {
            $args->{$_} = strip( $args->{$_} );
        }

        warn $_ . ' => ' . $args->{$_}
          if $t;

    }

    warn '$status: ' . $status
      if $t;

    if ( $status == 1 ) {
        $self->r_list( $args->{-list} );
        $self->r_service( $args->{-service} );
        $self->r_public_key( $args->{-public_key} );
        $self->r_digest( $args->{-digest} );
        $self->r_cgi_obj( $args->{-cgi_obj} );
    }

    warn '$self->check_list(): ' . $self->check_list();
    warn '$self->r_list: ' . $self->r_list;
    warn '$self->r_public_key: ' . $self->r_public_key;
    warn '$DADA::Config::GLOBAL_API_OPTIONS->{public_key}: '
      . $DADA::Config::GLOBAL_API_OPTIONS->{public_key};

    if (
        ( $self->check_list() == 1 )
        && ( $self->r_public_key eq
            $DADA::Config::GLOBAL_API_OPTIONS->{public_key} )
      )
    {

        warn 'here.';

        $self->ls_obj(
            DADA::MailingList::Settings->new( { -list => $self->r_list } ) );
        $self->global_level(1);
        $self->i_private_api_key(
            $DADA::Config::GLOBAL_API_OPTIONS->{private_key} );

    }
    elsif ( $self->check_list() == 1 ) {
        $self->ls_obj(
            DADA::MailingList::Settings->new( { -list => $self->r_list } ) );
        $self->global_level(0);
        $self->i_private_api_key( $self->ls_obj->param('private_api_key') );
    }
    else {
       # If there's a list that's passed, but it's invalid, this shouldn't workL
        if (
            ( $self->r_list eq undef )
            && ( $self->r_public_key eq
                $DADA::Config::GLOBAL_API_OPTIONS->{public_key} )
          )
        {
            $self->global_level(1);

            # Well, OK...
            $self->i_private_api_key(
                $DADA::Config::GLOBAL_API_OPTIONS->{private_key} );
        }
        else {
            $status = 0;
            $errors->{'invalid_list'} = 1;
        }
    }

    warn 'global_level: ' . $self->global_level
      if $t;

    warn '$status: ' . $status
      if $t;

    my $r = {};

    if ( $status == 0 ) {
        $r = {
            status => 0,
            errors => $errors,
        };
    }
    else {
        # we're reusing these, below:
        undef $status;
        undef $errors;

        my ( $status, $errors ) = $self->check_request();

        if ( $status == 1 ) {
            if ( $self->r_service eq 'validate_subscription' ) {
                $r = $self->validate_subscription();
            }
            elsif ( $self->r_service eq 'subscription' ) {
                $r = $self->subscription();
            }
            elsif ( $self->r_service eq 'unsubscription' ) {
                $r = $self->unsubscription();
            }
            elsif ( $self->r_service eq 'mass_email' ) {
                $r = $self->mass_email();
            }
            elsif ( $self->r_service eq 'settings' ) {
                $r = $self->settings();
            }
            elsif ( $self->r_service eq 'update_settings' ) {
                $r = $self->update_settings();
            }
            elsif ( $self->r_service eq 'update_profile_fields' ) {
                $r = $self->update_profile_fields();
            }
            elsif ( $self->r_service eq 'create_new_list' ) {
                $r = $self->create_new_list();
            }
            else {
                $r = {
                    status => 0,
                    errors => {
                        invalid_request => 1
                    }
                };
            }
        }
        else {
            $r = {
                status => 0,
                errors => $errors,
            };
        }
    }

    if ($t) {
        $r->{r_path_info}       = $self->r_cgi_obj->path_info();
        $r->{r_service}         = $self->r_service;
        $r->{r_query}           = $self->r_cgi_obj->query_string();
        $r->{r_digest}          = $self->r_digest;
        $r->{calculated_digest} = $calculated_digest;
        $r->{r_public_key}      = $self->r_public_key;
        $r->{i_private_api_key} = $self->i_private_api_key;
    }
    my $headers = {
        -type            => 'application/json',
        '-Cache-Control' => 'no-cache, must-revalidate',
        -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
    };
    my $json = JSON->new->allow_nonref;
    return ( $headers, $json->pretty->encode($r) );
}

sub validate_subscription {
    my $self      = shift;
    my $addresses = $self->r_cgi_obj->param('addresses');

    my $lh = DADA::MailingList::Subscribers->new( { -list => $self->r_list } );
    my $json              = JSON->new;
    my $decoded_addresses = $json->decode($addresses);

    my $f_addresses = $lh->filter_subscribers_w_meta(
        {
            -emails => $decoded_addresses,
            -type   => 'list',
        }
    );

    for (@$f_addresses) {

        # We don't need these:
        delete( $_->{csv_str} );
    }
    return {
        status  => 1,
        results => $f_addresses
    };
}

sub subscription {

    my $self      = shift;
    my $addresses = $self->r_cgi_obj->param('addresses');
    my $lh = DADA::MailingList::Subscribers->new( { -list => $self->r_list } );
    my $json                = JSON->new;
    my $decoded_addresses   = $json->decode($addresses);
    my $new_email_count     = 0;
    my $skipped_email_count = 0;

    my $not_members_fields_options_mode = 'preserve_if_defined';

    my $f_addresses = $lh->filter_subscribers_w_meta(
        {
            -emails => $decoded_addresses,
            -type   => 'list',
        }
    );

    my $subscribe_these = [];
    my $filtered_out    = 0;

    #    my $overridden_tests = {
    #        black_listed    => 0,
    #        not_whitelisted => 0,
    #        profile_fields  => 0,
    #    }

    for (@$f_addresses) {
        if ( $_->{status} == 1 ) {
            push( @$subscribe_these, $_ );

            #        }
            #        elsif(1 == 0){ # are there tests we're skippin'?
            #            push( @$subscribe_these, $_ );
        }
        else {
            $filtered_out++;
        }
    }

    if ( scalar(@$subscribe_these) > 0 ) {
        ( $new_email_count, $skipped_email_count ) = $lh->add_subscribers(
            {
                -addresses => $subscribe_these,
                -type      => 'list',
            }
        );
    }

    #-fields_options_mode => undef,
    $skipped_email_count = $skipped_email_count + $filtered_out;

    return {
        status  => 1,
        results => {
            subscribed_addresses => $new_email_count,
            skipped_addresses    => $skipped_email_count,
        }
    };

}

sub unsubscription {

    my $self      = shift;
    my $addresses = $self->r_cgi_obj->param('addresses');
    my $lh = DADA::MailingList::Subscribers->new( { -list => $self->r_list } );
    my $json                = JSON->new;
    my $decoded_addresses   = $json->decode($addresses);
    my $removed_email_count = 0;
    my $skipped_email_count = 0;
    my $blacklisted_count   = 0;

    my $f_addresses = $lh->filter_subscribers_w_meta(
        {
            -emails => $decoded_addresses,
            -type   => 'list',
        }
    );

    my $unsubscribe_these = [];
    my $filtered_out      = 0;

    for (@$f_addresses) {
        if ( $_->{status} == 0 && $_->{errors}->{subscribed} == 1 ) {
            push( @$unsubscribe_these, $_->{email} );
        }
        else {
            $filtered_out++;
        }
    }

    if ( scalar(@$unsubscribe_these) > 0 ) {
        ( $removed_email_count, $blacklisted_count ) =
          $lh->admin_remove_subscribers(
            {
                -addresses => $unsubscribe_these,
                -type      => 'list',
            }
          );
    }

    $skipped_email_count = $skipped_email_count + $filtered_out;

    return {
        status  => 1,
        results => {
            unsubscribed_addresses => $removed_email_count,
            skipped_addresses      => $skipped_email_count,
        }
    };
}

sub mass_email {

    my $self    = shift;
    my $subject = $self->r_cgi_obj->param('subject');
    my $format  = $self->r_cgi_obj->param('format');
    my $message = $self->r_cgi_obj->param('message');
    my $test    = $self->r_cgi_obj->param('test') || 0;

    my $type = 'text/plain';
    if ( $format =~ m/html/i ) {
        $type = 'text/html';
    }
    my $qq = CGI->new();
    $qq->delete_all();

    $qq->param( 'Subject', $subject );
    if ( $type eq 'text/html' ) {
        $qq->param( 'html_message_body', $message );
    }
    else {
        # Say that we don't have any HTML
        $qq->param( 'content_from', 'none' );

        # but we do have plaintext
        $qq->param( 'plaintext_content_from', 'text' );

        # and make sure that's found
        $qq->param( 'text_message_body', $message );
    }
    $qq->param( 'f',          'send_email' );
    $qq->param( 'draft_role', 'draft' );

    require DADA::App::MassSend;
    my $dam      = DADA::App::MassSend->new( { -list => $self->r_list } );
    my $draft_id = $dam->save_as_draft(
        {
            -cgi_obj => $qq,
            -list    => $self->r_list,
            -json    => 0,

        }
    );

    my $process;
    if ( $test == 1 ) {
        $process = 'test';
    }
    else {
        $process = 1;
    }

    # to fetch a draft, I need id, list and role (lame)
    my $c_r = $dam->construct_and_send(
        {
            -draft_id => $draft_id,
            -screen   => 'send_email',
            -role     => 'draft',
            -process  => $process,
        }
    );
    $dam->delete_draft($draft_id);

    if ( $c_r->{status} == 0 ) {
        return {
            status => 0,
            errors => {
                mass_email_error => $c_r->{errors},
            }
        };
    }
    else {
        return {
            status  => 1,
            results => {
                message_id => $self->_massaged_key( $c_r->{mid} ),
            }
        };
    }
}

sub settings {
    my $self = shift;
    warn 'settings called'
      if $t;

    return {
        status  => 1,
        results => {
            settings => $self->ls_obj->get()
        }
    };
}

sub update_settings {

    my $self = shift;

    my $json = JSON->new->allow_nonref;
    my $r    = {};

    my $settings = $self->r_cgi_obj->param('settings');
    $settings = $json->decode($settings);

    try {
        $self->ls_obj->save(
            {
                -settings => $settings
            }
        );
        $r = {
            status  => 1,
            results => {
                saved => 1
            },
        };
    }
    catch {
        $r = {
            status => 0,
            errors => {
                error => $_
            },
        };
    };

    return $r;
}

sub update_profile_fields {

    my $self = shift;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $self->r_list } );

    my $json = JSON->new->allow_nonref;
    my $r    = {};

    my $email = $self->r_cgi_obj->param('email');
    $email = $json->decode($email);
    $email = cased( xss_filter($email) );

    if ( check_for_valid_email($email) == 1 ) {
        return {
            status => 0,
            errors => {
                invalid_email => 1,
            },
            email => $email,
        };
    }

    try {

        require DADA::Profile;
        my $prof = DADA::Profile->new( { -email => $email } );

        my $profile_fields = $self->r_cgi_obj->param('profile_fields');
        $profile_fields = $json->decode($profile_fields);

        #warn 'pf:' . $profile_fields;

        # check to see if profiles exist?
        # Actually, it doesnm't matter to me if the profile exists or not,

        my $new_fields = {};
        for my $nfield ( @{ $lh->subscriber_fields() } ) {
            if ( exists( $profile_fields->{$nfield} ) ) {
                $new_fields->{$nfield} = $profile_fields->{$nfield};
            }
        }

        my $dpf  = DADA::Profile::Fields->new( { -email => $email } );
        my $orig = $dpf->get;

        delete( $orig->{email} );
        delete( $orig->{email_name} );
        delete( $orig->{email_domain} );

        $dpf->insert(
            {
                -email  => $email,
                -fields => $new_fields,
            }
        );
        $r = {
            status  => 1,
            results => {
                saved                   => 1,
                email                   => $email,
                profile_fields          => $new_fields,
                previous_profile_fields => $orig,

            },
        };
    }
    catch {
        $r = {
            status => 0,
            errors => {
                error => $_,
            }
        };
    };

    return $r;
}

sub create_new_list {

    my $self = shift;
    warn 'create_new_list called'
      if $t;

    my $json = JSON->new->allow_nonref;
    my $r    = {};

    my $status = 0;
    my $errors = {};

=pod

	# OK, so remember we need to do a list quota check: 
	
	if(strip($DADA::Config::LIST_QUOTA) eq '') {
		$DADA::Config::LIST_QUOTA = undef;
    } 
	# Special: 
	if($DADA::Config::LIST_QUOTA == 0){ 
		$DADA::Config::LIST_QUOTA = undef;
	}
    if (   defined($DADA::Config::LIST_QUOTA)
        && ( ( $#t_lists + 1 ) >= $DADA::Config::LIST_QUOTA ) )
    {
        return user_error(
            { -list => $list, -error => "over_list_quota" } );
    }

    
    my @available_lists = DADA::App::Guts::available_lists();
    my $lists_exist     = $#available_lists + 1;

=cut

    my $settings = $self->r_cgi_obj->param('settings');
    $settings = $json->decode($settings);

    warn '$self->r_cgi_obj->param(\'options\'): '
      . $self->r_cgi_obj->param('options');

    my $options = $self->r_cgi_obj->param('options');
    $options = $json->decode($options);

    use Data::Dumper;
    warn '$options: ' . Dumper($options);

    my $list_exists = check_if_list_exists( -List => $settings->{list} );
    my ( $list_errors, $flags ) = check_list_setup(
        -fields => {
            list             => $settings->{list},
            list_name        => $settings->{list_name},
            list_owner_email => $settings->{list_owner_email},
            password         => $settings->{password},
            retype_password  => $settings->{password},
            info             => $settings->{info},
            privacy_policy   => $settings->{privacy_policy},
            physical_address => $settings->{physical_address},
            consent          => $settings->{consent},
        }
    );

    if ( $list_errors >= 1 ) {
        $status = 0;
        $errors = $flags;

        for ( keys %$errors ) {
            if ( $errors->{$_} != 1 ) {
                delete( $errors->{$_} );
            }
        }
        return {
            status  => $status,
            results => {
                error => $errors,
            }
        };

    }
    elsif ( $list_exists >= 1 ) {
        return {
            status => 0,
            errors => {
                list_exists => 1,
            },
        };

    }
    else {

        $settings->{list_owner_email} =
          lc_email( $settings->{list_owner_email} );

        my $new_info = {};

        my @init_settings = (
            qw(
              list
              list_owner_email
              list_name
              password
              info
              physical_address
              privacy_policy
              consent
            )
        );

        for (@init_settings) {
            if ( length( $settings->{$_} ) > 1 ) {
                $new_info->{$_} = $settings->{$_};
            }
        }

        require DADA::MailingList;
        my $ls;

        if ( exists( $options->{clone_settings_from_list} ) ) {
            warn 'yes.';

            warn
'check_if_list_exists(-List => $options->{clone_settings_from_list}: '
              . check_if_list_exists(
                -List => $options->{clone_settings_from_list} );

            if (
                check_if_list_exists(
                    -List => $options->{clone_settings_from_list}
                ) <= 0
              )
            {

                warn 'yes.';

                $status = 0;
                $errors = { clone_list_no_exists => 1 };
                return {
                    status => $status,
                    errors => {
                        clone_list_no_exists => 1,
                    }
                };
            }
            else {

                warn 'yes.';

                $ls = DADA::MailingList::Create(
                    {
                        -list     => $settings->{list},
                        -settings => $new_info,
                        -clone    => xss_filter(
                            scalar $options->{clone_settings_from_list}
                        ),
                    }
                );
            }
        }
        else {

            warn 'yes.';

            $ls = DADA::MailingList::Create(
                {
                    -list     => $settings->{list},
                    -settings => $new_info,
                }
            );
        }

        if ( $DADA::Config::LOG{list_lives} ) {
            require DADA::Logging::Usage;
            my $log = new DADA::Logging::Usage;
            $log->mj_log(
                $settings->{list},
                'List Created',
                "remote_host:$ENV{REMOTE_HOST},"
                  . "ip_address:$ENV{REMOTE_ADDR}"
            );
        }

        if ( $options->{'send_new_list_welcome_email'} == 1 ) {
            try {
                require DADA::App::Messages;
                my $dap = DADA::App::Messages->new(
                    {
                        -list => $settings->{list},
                    }
                );

                # seems dumb to be passing this around, if we don't need to:
                my $send_new_list_created_notification_vars = {};

                if ( $options->{send_new_list_welcome_email_with_list_pass} ==
                    1 )
                {
                    $send_new_list_created_notification_vars = {
                        send_new_list_welcome_email_with_list_pass => 1,
                        list_password => $settings->{password},
                    };
                }
                else {
                    $send_new_list_created_notification_vars = {
                        send_new_list_welcome_email_with_list_pass => 0,
                        list_password                              => undef,
                    };
                }

                $dap->send_new_list_created_notification(
                    {
                        -vars => $send_new_list_created_notification_vars
                    }
                );
            }
            catch {
                warn 'problems sending send_new_list_created_notification: '
                  . $_;
            };
        }

        use Data::Dumper;

        return {
            status  => 1,
            results => {
                settings => Dumper($settings),
            }
        };
    }
}

sub check_request {

    my $self = shift;

    my $status = 1;
    my $errors = {};

    if ( $self->check_nonce() == 0 ) {
        $status = 0;
        $errors->{invalid_nonce} = 1;
    }
    if ( $self->check_public_key() == 0 ) {
        $status = 0;
        $errors->{invalid_public_key} = 1;
    }
    if ( $self->check_digest() == 0 ) {
        $status = 0;
        $errors->{invalid_digest} = 1;
    }

    warn '$self->check_list(): ' . $self->check_list();

    if ( $self->check_list() == 0 ) {

        warn '$self->global_level: ' . $self->global_level;
        warn '$self->r_list: ' . $self->r_list;
        warn '$self->r_service: ' . $self->r_service;

        if (   $self->global_level == 1
            && $self->r_list eq undef
            && $self->r_service eq 'create_new_list' )
        {
            # Special Case - this is fine.
        }
        else {

            warn 'nope.';

            $status = 0;
            $errors->{invalid_list} = 1;
        }
    }
    if ($t) {
        require Data::Dumper;
        warn 'check_request: '
          . Data::Dumper::Dumper( { status => $status, errors => $errors } );
    }
    return ( $status, $errors );
}

sub check_nonce {
    my $self = shift;

    warn '$self->r_cgi_obj->param(\'nonce\'): '
      . $self->r_cgi_obj->param('nonce');

    my ( $timestamp, $nonce ) = split( ':', $self->r_cgi_obj->param('nonce') );

    my $r = 0;

# for now, we throw away $nonce, but we should probably save it for x amount of time
    if ( ( int($timestamp) + ( 60 * 5 ) ) < int(time) ) {
        $r = 0;
    }
    else {
        $r = 1;
    }
    warn 'check_nonce: ' . $r
      if $t;

    return $r;
}

sub check_public_key {

    my $self = shift;
    my $r    = 0;

    # I mean, ok:
    # $self->r_public_key
    # is what's passed in the request, so I guess this sort of makes sense:
    #

    warn '$self->global_level : ' . $self->global_level;

    my $tmp_public_key = undef;
    if ( $self->global_level == 1 ) {
        $tmp_public_key = $DADA::Config::GLOBAL_API_OPTIONS->{public_key};
    }
    else {
        $tmp_public_key = $self->ls_obj->param('public_api_key');
    }

    if ( $tmp_public_key ne $self->r_public_key ) {
        $r = 0;
    }
    else {
        $r = 1;
    }
    warn 'check_public_key ' . $r
      if $t;

    return $r;
}

sub check_digest {

    my $self = shift;
    my $r    = 0;

    my $qq = CGI->new();
    $qq->delete_all();

    my $n_digest = undef;

    warn '$self->r_service: ' . $self->r_service
      if $t;

    if ( $self->r_service eq 'mass_email' ) {
        $qq->param( 'format',  $self->r_cgi_obj->param('format') );
        $qq->param( 'message', $self->r_cgi_obj->param('message') );
        $qq->param( 'nonce',   $self->r_cgi_obj->param('nonce') );
        $qq->param( 'subject', $self->r_cgi_obj->param('subject') );

        # optional
        if ( defined( $self->r_cgi_obj->param('test') ) ) {
            $qq->param( 'test', $self->r_cgi_obj->param('test') );
        }
        $n_digest = $self->digest( $qq->query_string() );
    }
    elsif ( $self->r_service eq 'update_settings' ) {
        $qq->param( 'nonce',    $self->r_cgi_obj->param('nonce') );
        $qq->param( 'settings', $self->r_cgi_obj->param('settings') );
        $n_digest = $self->digest( $qq->query_string() );
    }
    elsif ( $self->r_service eq 'settings' ) {
        $n_digest = $self->digest( $self->r_cgi_obj->param('nonce') );
    }
    elsif ( $self->r_service eq 'update_profile_fields' ) {
        $qq->param( 'email', $self->r_cgi_obj->param('email') );
        $qq->param( 'nonce', $self->r_cgi_obj->param('nonce') );
        $qq->param( 'profile_fields',
            $self->r_cgi_obj->param('profile_fields') );
        $n_digest = $self->digest( $qq->query_string() );
    }
    elsif ( $self->r_service eq 'create_new_list' ) {
        $qq->param( 'nonce', $self->r_cgi_obj->param('nonce') );
        if ( defined( $self->r_cgi_obj->param('options') ) ) {
            $qq->param( 'options', $self->r_cgi_obj->param('options') );
        }
        $qq->param( 'settings', $self->r_cgi_obj->param('settings') );
        $n_digest = $self->digest( $qq->query_string() );
    }
    else {
        # This should be explicit
        $qq->param( 'addresses', $self->r_cgi_obj->param('addresses') );
        $qq->param( 'nonce',     $self->r_cgi_obj->param('nonce') );
        $n_digest = $self->digest( $qq->query_string() );
    }

    # debug'n

    $calculated_digest = $n_digest;

    if ( $self->r_digest ne $n_digest ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub digest {

    my $self    = shift;
    my $message = shift;

    warn '$message ' . $message
      if $t;

    warn '$self->i_private_api_key: ' . $self->i_private_api_key
      if $t;

    my $n_digest = hmac_sha256_base64( $message, $self->i_private_api_key );
    while ( length($n_digest) % 4 ) {
        $n_digest .= '=';
    }

    warn '$n_digest:' . $n_digest
      if $t;

    return $n_digest;
}

sub check_list {
    my $self = shift;
    if ( DADA::App::Guts::list_exists( -List => $self->r_list ) ) {
        return 1;
    }
    else {
        return 0;
    }

}

sub _massaged_key {

    my $self = shift;
    my $key  = shift;
    $key =~ s/^\<|\>$//g
      if $key;

    $key =~ s/^\%3C|\%3E$//g
      if $key;

    $key =~ s/^\&lt\;|\&gt\;$//g
      if $key;

    $key =~ s/\.(.*)//
      if $key;    #greedy

    return $key;

}

1;
