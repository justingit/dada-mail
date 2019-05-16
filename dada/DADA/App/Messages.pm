package DADA::App::Messages;

use lib qw(../../ ../../perllib);
use Carp qw(croak carp cluck);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

use vars qw($AUTOLOAD);
use strict;
my $t = 0;

my %allowed = (
    list    => undef,
    emt     => undef,
    fm      => undef,
    mh      => undef,
	ls      => undef, 
    logging => undef,
	test    => 0,
);

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;

    $self->_init($args);
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
    my ($args) = @_;

    if ( !exists( $args->{-test} ) ) {
        $self->test(0);
    }
	else { 
		$self->test($args->{-test}); 
	}

    if ( exists( $args->{-list} ) ) {
        $self->list( $args->{-list} );

        require DADA::App::FormatMessages;
        my $fm = DADA::App::FormatMessages->new( -List => $self->list );
        $self->fm($fm);

        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $self->list } );
		$self->ls($ls);
		
        require DADA::App::EmailThemes;
        my $em = DADA::App::EmailThemes->new(
            {
                -list      => $self->list,
            }
        );
        $self->emt($em);

        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new(
            {
                -list   => $self->list,
                -ls_obj => $self->ls,
            }
        );
        $self->mh($mh);
    }
    else {
        require DADA::App::FormatMessages;
        my $fm = DADA::App::FormatMessages->new( -yeah_no_list => 1 );
        $self->fm( $self->emt );
    }

    require DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;
    $self->logging($log);
}

sub send_generic_email {

    my $self = shift;
    my ($args) = @_;
	
    $self->fm->use_header_info(1);
    $self->fm->use_email_templates(0);
	
    if ( !exists( $args->{-tmpl_params} ) ) {
        if ( defined( $self->list ) ) {

            $args->{-tmpl_params} =
              { -list_settings_vars_param => { -list => $self->list } }
              ,    # Dev: Probably could just pass $ls?
        }
        else {
            $args->{-tmpl_params} = {};
        }
    }
	
	my $entity; 

	if(exists($args->{-entity})){ 		
	    $entity = $self->fm->email_template(
	        {
	            -entity => $args->{-entity},
	            %{ $args->{-tmpl_params} },
	        }
	    );
	}
	else {

	    if ( !exists( $args->{-headers} ) ) {
	        $args->{-headers} = {};
	    }
	    if ( !exists( $args->{-headers}->{To} ) ) {
	        $args->{-headers}->{To} = $args->{-email};
	    }
	    my $data = {
	          ( defined( $self->list ) )
	        ? ( $self->mh->list_headers, )
	        : (),
	        %{ $args->{-headers} },
	        Body => $args->{-body},
	    };

	    while ( my ( $key, $value ) = each %{$data} ) {
	        $data->{$key} = safely_encode($value);
	    }
		
	    my ($email_str) = $self->fm->format_message(
	        {
	            -msg => $self->fm->string_from_dada_style_args(
	                {
	                    -fields => $data,
	                }
	            )
	        }
	    );

	    $email_str = safely_decode($email_str);

	   $entity = $self->fm->email_template(
	        {
	            -entity => $self->fm->get_entity( { -data => safely_encode($email_str), } ),
	            %{ $args->{-tmpl_params} },
	        }
	    );
		
	}

    my $msg = $entity->as_string;
    my ( $header_str, $body_str ) = split( "\n\n", $msg, 2 );
    my $header_str = safely_decode( $entity->head->as_string );
    my $body_str   = safely_decode( $entity->body_as_string );

    if ( $self->test == 1 ) {
        $self->mh->test(1);
    }

    $self->mh->send( $self->mh->return_headers($header_str),
        Body => $body_str, );

}

sub create_multipart_email {

    #	warn 'at send_multipart_email' ;

    my $self = shift;
    my ($args) = @_;

    my $expr        = 1;
    my $url_options = 'cid';

    if ( $self->ls->param('email_embed_images_as_attachments') != 1 ) {
        $url_options = 'extern';
    }

    if ( !exists( $args->{-headers} ) ) {
        $args->{-headers} = {};
    }
	# encode those headers, before they hit MyMIMELiteHTML
	for(keys %{$args->{-headers}}){
		$args->{-headers}->{$_} = $self->fm->_encode_header( 
			$_, $args->{-headers}->{$_}
		);
	}


    require DADA::App::MyMIMELiteHTML;
    my $mailHTML = new DADA::App::MyMIMELiteHTML(

        remove_jscript =>
          scalar $self->ls->param('mass_mailing_remove_javascript'),
        'IncludeType' => $url_options,
        'TextCharset' => scalar $self->ls->param('charset_value'),
        'HTMLCharset' => scalar $self->ls->param('charset_value'),
        HTMLEncoding  => scalar $self->ls->param('html_encoding'),
        TextEncoding  => scalar $self->ls->param('plaintext_encoding'),
        (
              ( $DADA::Config::CPAN_DEBUG_SETTINGS{MIME_LITE_HTML} == 1 )
            ? ( Debug => 1, )
            : ()
        ),
        %{ $args->{-headers} },
    );

    my ( $status, $errors, $MIMELiteObj, $md5 );

    if (   length( $args->{-html_body} ) > 0
        && length( $args->{-plaintext_body} ) > 0 )
    {
        ( $status, $errors, $MIMELiteObj, $md5 ) = $mailHTML->parse(
            safely_encode( $args->{-html_body} ),
            safely_encode( $args->{-plaintext_body} )
        );
    }
    elsif (length( $args->{-html_body} ) > 0
        && length( $args->{-plaintext_body} ) <= 0 )
    {
        ( $status, $errors, $MIMELiteObj, $md5 ) =
          $mailHTML->parse( safely_encode( $args->{-html_body} ), undef, );
    }
    elsif (length( $args->{-html_body} ) <= 0
        && length( $args->{-plaintext_body} ) > 0 )
    {
        ( $status, $errors, $MIMELiteObj, $md5 ) =
          $mailHTML->parse( undef, safely_encode( $args->{-plaintext_body} ), );
    }
    use MIME::Parser;
    my $parser = new MIME::Parser;
    $parser = optimize_mime_parser($parser);

#	warn '$MIMELiteObj->as_string ' . $MIMELiteObj->as_string ; 
	
	my $moas = $MIMELiteObj->as_string; 
	if(! defined($moas)){ 
		carp 'problems with creating multipart email:'; 
		require Data::Dumper; 
		carp '$MIMELiteObj: ' . Data::Dumper::Dumper($MIMELiteObj); 
		carp '$args:'         . Data::Dumper::Dumper($args);
	}

    my $entity = $parser->parse_data( $moas );
	undef($moas); 
	
    my %lh = $self->mh->list_headers;
    for my $h ( keys %lh ) {
        $entity->head->add( $h, safely_encode( $lh{$h} ) );
    }

    $self->fm->use_header_info(1);
    $self->fm->use_email_templates(0);

	if(!exists($args->{-tmpl_params})){ 
		$args->{-tmpl_params} = {};
	}
	if(!exists($args->{-template_out})){ 
		$args->{-template_out} = 1; 
	}

    $entity = $self->fm->format_message(
        {
            -entity => $entity
        }
    );
	

	if($args->{-template_out} == 1){
	    $entity = $self->fm->email_template(
	        {
	            -entity => $entity,
	            -expr   => $expr,
	            %{ $args->{-tmpl_params} },
	        }
	    );
	}
	
	return $entity; 
}


 
# This is a terrible method - most of the interesting work is being done 
# by create_multipart_email, but this below was split from that, so we 
# could *just* create the stupid email... 
# Below is just translating an entity to the internal format so we can send it 
# with DADA::Mail::Send
# DADA::Mail::Send should just take the entity at this point 
# Clean up a lot of code! 

sub send_multipart_email { 
	
    my $self   = shift;
    my ($args) = @_;
	
	my $entity = $self->create_multipart_email($args);

    my $msg = $entity->as_string;
    my ( $header_str, $body_str ) = split( "\n\n", $msg, 2 );
	
    # Time for DADA::Mail::Send to just have a, "Here's th entity!" argument,
    # rather than always passing this crap back and forth.
    my $header_str = safely_decode( $entity->head->as_string );
    my $body_str   = safely_decode( $entity->body_as_string );
    
	if ( $self->test == 1 ) {
        $self->mh->test(1);
    }
    
	$self->mh->send( 
		$self->mh->return_headers($header_str),
        Body => $body_str,
	);
	return 1; 
		
}

sub send_abuse_report {

    my $self = shift;
    my ($args) = @_;

    #    -email                => $email,
    #    -abuse_report_details => $abuse_report_details,
    #     -mid => $diagnostics->{'Simplified-Message-Id'},

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $abuse_report_details = $args->{-abuse_report_details};
    if ( !exists( $args->{-mid} ) ) {
        $args->{-mid} = '00000000000000';
    }

    my $etp = $self->emt->fetch('list_abuse_report_message');

    require DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $self->list } );

    my $worked = $lh->add_subscriber(
        {
            -email      => $email,
            -list       => $self->list,
            -type       => 'unsub_request_list',
            -dupe_check => {
                -enable  => 1,
                -on_dupe => 'ignore_add',
            },
        }
    );

    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct            = DADA::App::Subscriptions::ConfirmationTokens->new();
    my $approve_token = $ct->save(
        {
            -email => $email,
            -data  => {
                list        => $self->list,
                type        => 'list',
                mid         => $args->{-mid},
                flavor      => 'unsub_request_approve',
                remote_addr => ip_address_logging_filter($ENV{REMOTE_ADDR}),
            },
            -remove_previous => 0,
        }
    );

    $self->send_multipart_email(
        {
            -headers => {
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase},
                    $self->ls->param('list_owner_email')
                ),
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                Subject => $etp->{vars}->{subject},
            },

            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param => { -list => $self->list },
                -subscriber_vars_param    => {
                    -list  => $self->list,
                    -email => $email,
                    -type  => 'list'
                },
                -vars => {
                    abuse_report_details => $abuse_report_details,
                    list_unsubscribe_request_approve_link =>
                      $DADA::Config::S_PROGRAM_URL . '/t/'
                      . $approve_token . '/',
                },
            },
            -test => $self->test,
        }
    );
}

sub send_confirmation_message {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('confirmation_message');

    if ( defined( $etp->{plaintext} ) ) {
        $etp->{plaintext} = $self->fm->subscription_confirmationation(
            { -str => $etp->{plaintext} } );
    }
    if ( defined( $etp->{html} ) ) {
        $etp->{html} =
          $self->fm->subscription_confirmationation( { -str => $etp->{html} } );
    }
	# warn '$etp->{vars}->{from_phrase}' . $etp->{vars}->{from_phrase}; 
    # warn '$etp->{vars}->{preheader}'   . $etp->{vars}->{preheader}; 
	
    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, $email
                ),
                Subject       => $etp->{vars}->{subject},
				'X-Preheader' => $etp->{vars}->{preheader},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param => {
                    -list => $self->list
                },
                -subscriber_vars_param => {
                    -list  => $self->list,
                    -email => $email,
                    -type  => 'sub_confirm_list'
                },
                -vars => {
                    'list.confirmation_token' => $args->{-token},
                },
            },

            -test => $self->test,
        }
    );

    return 1;

}

sub send_subscribed_message {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
	
    my $email = $args->{-email};

    require DADA::App::Subscriptions::Unsub;
    my $dasu = DADA::App::Subscriptions::Unsub->new( { -list => $self->list } );

    my $unsub_link = $dasu->unsub_link(
        {
            -email  => $email,
            -mid    => '00000000000000', 
			-source => 'subscription welcome email message'
        }
    );
    $args->{-vars}->{list_unsubscribe_link} = $unsub_link;

    my $etp = $self->emt->fetch('subscribed_message');

	# warn '$etp->{html}' . $etp->{html}; 
	
    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, 
					$email,
                ),
                Subject       => $etp->{vars}->{subject},
				'X-Preheader' => $etp->{vars}->{preheader},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param => {
                    -list => $self->ls->param('list')
                },
                -subscriber_vars_param => {
                    -list  => $self->ls->param('list'),
                    -email => $email,
                    -type  => 'list'
                },
                -vars => $args->{-vars},
            },
            -test => $self->test,
        }
    );

    return 1;

    # Logging?

}
sub send_subscription_request_denied_message {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{-vars} ) ) {
        $args->{-vars} = {};
    }
    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('subscription_request_denied_message');

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, $email
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param =>
                  { -list => $self->ls->param('list'), },

#-subscriber_vars_param    => {-list => $self->ls->param('list'), -email => $email, -type => 'list'},
#-profile_vars_param       => {-email => $email},
#-vars => $args->{-vars},
                -vars => {
                    'subscriber.email' => $email,
                    %{ $args->{-vars} },
                }
            },
            -test => $self->test,
        }
    );

    # Logging?

}

# this is used when the token system is whack, and you request to unsub, uh, "manually"

sub send_unsubscribe_request_message {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('unsubscription_request_message');

    $etp->{plaintext} = $self->fm->unsubscription_confirmationation(
        {
            -str => $etp->{plaintext}
        }
    );

	$etp->{html} = $self->fm->unsubscription_confirmationation(
		{
			-str => $etp->{html}
		}
	);

    require DADA::App::Subscriptions::Unsub;
    my $dasu = DADA::App::Subscriptions::Unsub->new( { -list => $self->list } );
    my $unsub_link =
      $dasu->unsub_link( { -email => $email, -mid => '00000000000000' } );

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, 
					$email,
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param => {
                    -list => $self->list,
                },
                -subscriber_vars_param => {
                    -list  => $self->list,
                    -email => $email,
                    -type  => 'list'
                },
                -vars => {

                    #				'list.confirmation_token' => $args->{-token},
                    list_unsubscribe_link => $unsub_link,
                },
            },
            -test => $self->test,
        }
    );

    $self->logging->mj_log( $self->list,
        'Unsubscription Confirmation Sent for ' . $self->list . '.list',
        $email );

    return 1;
}

sub subscription_approval_request_message {

    my $self = shift;
    my ($args) = @_;

    my $etp = $self->emt->fetch('subscription_approval_request_message');
	
    if ( ! exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

	# warn '$email:' . $email; 
	
    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, 
				    $self->ls->param('list_owner_email')
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param =>
                  { -list => $self->ls->param('list') },
                -subscriber_vars_param => {
                    -list  => $self->ls->param('list'),
                    -email => $email,
                    -type  => 'sub_request_list'
                },
                -vars => { %{ $args->{-vars} }, },
            },
            -test => $self->test,
        }
    );
}

sub unsubscription_approval_request_message {

    my $self = shift;

    my ($args) = @_;
    my $ls = $args->{-ls_obj};
    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('unsubscription_approval_request_message');

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase},
                    $self->ls->param('list_owner_email')
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param =>
                  { -list => $self->ls->param('list') },
                -subscriber_vars_param => {
                    -list  => $self->ls->param('list'),
                    -email => $email,
                    -type  => 'unsub_request_list'
                },
                -vars => { %{ $args->{-vars} }, },
            },
            -test => $self->test,
        }
    );

}

sub send_unsubscribed_message {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    # This is a hack - if the subscriber has recently been removed, you
    # won't be able to get the subscriber fields - since there's no way to
    # get fields of a removed subscriber.
    # So! We'll go and grab the profile info, instead.
    my $prof_fields  = {};
    my $unsub_fields = {};
    $unsub_fields->{'subscriber.email'} = $email;
    (
        $unsub_fields->{'subscriber.email_name'},
        $unsub_fields->{'subscriber.email_domain'}
    ) = split( '@', $email, 2 );
    require DADA::Profile;
    my $prof = DADA::Profile->new( { -email => $email } );
    if ($prof) {

        if ( $prof->exists ) {
            $prof_fields = $prof->{fields}->get;
            for ( keys %$prof_fields ) {
                $unsub_fields->{ 'subscriber.' . $_ } = $prof_fields->{$_};
            }
        }
    }

    #/This is a hack - if the subscriber has recently been removed, you

    my $etp = $self->emt->fetch('unsubscribed_message');

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, $email,
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},

            -test => $self->test,

            -tmpl_params => {
                -list_settings_vars_param => {
                    -list   => $self->ls->param('list'),
                    -dot_it => 1,
                },

    #-subscriber_vars => {'subscriber.email' => $email}, # DEV: This line right?
                -subscriber_vars => $unsub_fields,
            },
        }
    );

    # DEV: Logging?
}

sub send_owner_happenings {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }

    # Email is not used to send here, it's just used to say who sub'd/unsub'd
    my $email = $args->{-email};

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'subscribed';
    }

    my $status = $args->{-role};

    if ( !exists( $args->{-note} ) ) {
        $args->{-note} = '';
    }

    if ( $status eq "subscribed" ) {
        if ( $self->ls->param('get_sub_notice') == 0 ) {
            return;
        }
    }
    elsif ( $status eq "unsubscribed" ) {
        if ( $self->ls->param('get_unsub_notice') == 0 ) {
            return;
        }
    }

    my $lh;
    if ( $args->{-lh_obj} ) {
        $lh = $args->{-lh_obj};
    }
    else {
        $lh = DADA::MailingList::Subscribers->new( { -list => $self->list } );
    }
    my $num_subscribers = $lh->num_subscribers;

    # This is a hack - if the subscriber has recently been removed, you
    # won't be able to get the subscriber fields - since there's no way to
    # get fields of a removed subscriber.
    # So! We'll go and grab the profile info, instead.
    my $prof_fields  = {};
    my $unsub_fields = {};
    if ( $status eq "unsubscribed" ) {
        $unsub_fields->{'subscriber.email'} = $email;
        (
            $unsub_fields->{'subscriber.email_name'},
            $unsub_fields->{'subscriber.email_domain'}
        ) = split( '@', $email, 2 );

        require DADA::Profile;
        my $prof = DADA::Profile->new( { -email => $email } );
        if ($prof) {
            if ( $prof->exists ) {
                $prof_fields = $prof->{fields}->get;
                for ( keys %$prof_fields ) {
                    $unsub_fields->{ 'subscriber.' . $_ } = $prof_fields->{$_};
                }
            }
        }
    }
    my $etp          = {};
    my $msg_template = {};

    if ( $status eq "subscribed" ) {
        $etp = $self->emt->fetch('admin_subscription_notice_message');
    }
    elsif ( $status eq "unsubscribed" ) {
        $etp = $self->emt->fetch('admin_unsubscription_notice_message');
    }
    $msg_template = {
        from_phrase => $etp->{vars}->{from_phrase},
        to_phrase   => $etp->{vars}->{to_phrase},
        subject     => $etp->{vars}->{subject},
        plaintext   => $etp->{plaintext},
		html        => $etp->{html},
    };

    require DADA::Template::Widgets;
    for (qw(from_phrase to_phrase subject plaintext html)) {
        my $tmpl    = $msg_template->{$_};
        my $content = DADA::Template::Widgets::screen(
            {
                -data => \$tmpl,
                -vars => {
                    num_subscribers => $num_subscribers,
                    status          => $status,
                    note            => $args->{-note},
                    REMOTE_ADDR     => anonymize_ip($ENV{REMOTE_ADDR}),

                },
                -list_settings_vars_param => { -list => $self->list },
                ( $status eq "subscribed" )
                ? (
                    -subscriber_vars_param => {
                        -list  => $self->list,
                        -email => $email,
                        -type  => 'list'
                    },
                  )
                : ( -subscriber_vars => $unsub_fields, )
            }
        );
        $msg_template->{$_} = $content;
    }

    $self->fm->use_email_templates(0);

    my $send_to = 'list_owner';
    if ( $status eq "subscribed" ) {
        $send_to = $self->ls->param('send_subscription_notice_to');
    }
    else {
        $send_to = $self->ls->param('send_unsubscription_notice_to');
    }

    my $from_address   = $self->ls->param('list_owner_email');
    my $formatted_from = $self->fm->format_phrase_address(
            $msg_template->{from_phrase},
            $from_address,
        );

    if ( $send_to eq 'list' ) {
        $self->fm->mass_mailing(1);
        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new( { -list => $self->list } );
        $self->mh->list_type('list');
        my $message_id = $self->mh->mass_send(
            {
                -msg => {
                    From    => $formatted_from,
                    Subject => $msg_template->{subject},
                    Body    => $msg_template->{msg},
                },
            }
        );

    }
    elsif ( $send_to eq 'list_owner' || $send_to eq 'alt' ) {
        my $to = $formatted_from;
        if (
               $send_to eq 'alt'
            && $status eq "subscribed"
            && check_for_valid_email(
                $self->ls->param('alt_send_subscription_notice_to')
            ) == 0
          )
        {
            $to = $self->ls->param('alt_send_subscription_notice_to');
        }
        if (
               $send_to eq 'alt'
            && $status eq "unsubscribed"
            && check_for_valid_email(
                $self->ls->param('alt_send_unsubscription_notice_to')
            ) == 0
          )
        {
            $to = $self->ls->param('alt_send_unsubscription_notice_to');
        }
        $self->send_multipart_email(
            {
                -headers => {
                    To      => $to,
                    From    => $formatted_from,
                    Subject => $msg_template->{subject},
                },
                -plaintext_body => $msg_template->{plaintext},

                -html_body      => $msg_template->{html},
                -test => $self->test,
            }

        );
    }
    else {
        die "who am I sending to?!";
    }
}

sub send_you_are_already_subscribed_message {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('you_are_already_subscribed_message');

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, $email,
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},

            -tmpl_params => {
                -list_settings_vars_param =>
                  { -list => $self->ls->param('list'), },
                -subscriber_vars_param => {
                    -list  => $self->ls->param('list'),
                    -email => $email,
                    -type  => 'list'
                },
            },

            -test => $self->test,
        }
    );

    return 1;
}

sub send_not_subscribed_message {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('you_are_not_subscribed_message');

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, $email,
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param =>
                  { -list => $self->ls->param('list'), },
                -subscriber_vars_param => {
                    -list  => $self->ls->param('list'),
                    -email =>,
                    -type  => 'list'
                },
            },
            -test => $self->test,
        }
    );

}

sub send_newest_archive {

	# warn 'in send_newest_archive';
	
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    require DADA::MailingList::Archives;
    my $la = DADA::MailingList::Archives->new(
        {
            -list => $self->list,
        }
    );

    my $newest_entry = $la->newest_entry;

    if ( defined($newest_entry)
        && $newest_entry > 1 )
    {
		
		# warn 'weve got an entry!'; 

        my ( $head, $body ) = $la->massage_msg_for_resending(
            -key     => $newest_entry,
            '-split' => 1,
			-zap_sigs => 0, 
        );
		
		# warn '$body after massage_msg_for_resending' . $body; 

        if ( $self->test == 1 ) {
			# warn 'testing!';
            $self->mh->test(1);
        }

		# warn 'calling send_generic_email';
        $self->send_generic_email(
            {
                -email   => $email,
                -headers => {
                    $self->mh->return_headers($head),

                    To => $self->fm->format_phrase_address(
                        $self->ls->param('list_name') . ' Subscriber', 
						$email,
                    ),
                },
                -body        => $body,
                -tmpl_params => {
                    -list_settings_vars_param => {
                        -list => $self->ls->param('list')
                    },
                    -subscriber_vars_param => {
                        -list  => $self->ls->param('list'),
                        -email => $email,
                        -type  => 'list'
                    },
                },
                -test => $self->test,
            }
        );
        return 1;
    }
    else {
        return 0;
    }
}


sub send_unsubscription_request_denied_message {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-vars} ) ) {
        $args->{-vars} = {};
    }
    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch('unsubscription_request_denied_message');

    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, $email,
                ),
                Subject => $etp->{vars}->{subject},
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => {
                -list_settings_vars_param =>
                  { -list => $self->ls->param('list'), },
                -subscriber_vars => {
                    'subscriber.email' => $email,
                },
                -vars => {
                    'subscriber.email' => $email,
                    %{ $args->{-vars} },
                }
            },
            -test => $self->test,
        }
    );

    # Logging?

    return 1;

}

sub send_send_list_password_reset_confirmation { 

}

sub send_out_message {
    my $self = shift;
    my ($args) = @_;

#	use Data::Dumper;
#	warn 'send_out_message args:' . Dumper($args);

    if ( !exists( $args->{-tmpl_params} ) ) {
        $args->{-tmpl_params} = {};
    }
	
    if ( !exists( $args->{-email} ) ) {
        warn 'you MUST pass the -email param to use this method!';
        return undef;
    }
    my $email = $args->{-email};

    my $etp = $self->emt->fetch( $args->{-message} );
	
    $self->send_multipart_email(
        {
            -headers => {
                From => $self->fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->ls->param('list_owner_email')
                ),
                To => $self->fm->format_phrase_address(
                    $etp->{vars}->{to_phrase}, 
					$email,
                ),
                Subject => $etp->{vars}->{subject},
				(defined($etp->{vars}->{preheader})
					? 
					('X-Preheader' => $etp->{vars}->{preheader},)
					: ()
				)
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params    => $args->{-tmpl_params}
        }
    );

}

sub _mime_headers_from_string {

    my $self = shift;

    #get the blob
    my $header_blob = shift || "";

    #init a new %hash
    my %new_header;

    # split.. logically
    my @logical_lines = split /\n(?!\s)/, $header_blob;

    # make the hash
    for my $line (@logical_lines) {
        my ( $label, $value ) = split( /:\s*/, $line, 2 );
        $new_header{$label} = $value;
    }

    return %new_header;

}

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2019 Justin Simoni All rights reserved. 

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

