package DADA::App::Messages; 

use lib qw(../../ ../../perllib); 
use Carp qw(croak carp cluck); 

use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 



require Exporter; 
@ISA = qw(Exporter); 

@EXPORT = qw(
  send_generic_email
  send_confirmation_message
  send_unsubscribed_message
  send_subscribed_message
  send_unsubscribe_request_message
  send_owner_happenings
  send_newest_archive
  send_you_are_already_subscribed_message
  
  send_abuse_report
  
  
);


use strict; 
use vars qw(@EXPORT); 



sub send_generic_email {
    my ($args) = @_;

    if ( !exists( $args->{-test} ) ) {
        $args->{-test} = 0;
    }

    my $ls = undef;

    if( exists( $args->{-list})){ 
        if(! defined($args->{-list})){ 
            delete($args->{-list}); 
        }
    }
    if ( exists( $args->{-list} ) ) {
        if ( !exists( $args->{-ls_obj} ) ) {
            require DADA::MailingList::Settings;
            $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );
        }
        else {
            $ls = $args->{-ls_obj};
        }
    }

    # We'll use this, later
    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
        {
            ( exists( $args->{-list} ) )
            ? (
                -list   => $args->{-list},
                -ls_obj => $ls,
              )
            : (),
        }
    );

    # /We'll use this, later

    my $expr = 1;    # Default it to 1, if there's no list.
    if ( exists( $args->{-list} ) ) {
        if ( $ls->param('enable_email_template_expr') == 1 ) {
            $expr = 1;
        }
        else {
            $expr = 0;
        }
    }

    if ( !exists( $args->{-headers} ) ) {
        $args->{-headers} = {};
    }
    if ( !exists( $args->{-headers}->{To} ) ) {
        $args->{-headers}->{To} = $args->{-email};
    }

    if ( !exists( $args->{-tmpl_params} ) ) {
        if ( exists( $args->{-list} ) ) {

            $args->{-tmpl_params} =
              { -list_settings_vars_param => { -list => $args->{-list} } },    # Dev: Probably could just pass $ls?
        }
        else {
            $args->{-tmpl_params} = {};
        }
    }

    my $data = {
          ( exists( $args->{-list} ) )
        ? ( $mh->list_headers, )
        : (), %{ $args->{-headers} }, Body => $args->{-body},
    };

    while ( my ( $key, $value ) = each %{$data} ) {
        $data->{$key} = safely_encode($value);
    }

    require DADA::App::FormatMessages;
    my $fm = undef;

    if ( exists( $args->{-list} ) ) {
        $fm = DADA::App::FormatMessages->new( -List => $args->{-list} );
    }
    else {
        $fm = DADA::App::FormatMessages->new( -yeah_no_list => 1 );
    }
    $fm->use_header_info(1);
    $fm->use_email_templates(0);

    # Some templates always uses HTML::Template::Expr, example, the sending
    # preferences. This makes sure that the correct templating system is validated
    # correctly.
    # As far as I know, this really is only needed for the sending prefs test.
    #
    if ( $args->{-tmpl_params}->{-expr} == 1 ) {
        $fm->override_validation_type('expr');
    }
    my ($email_str) = $fm->format_message( -msg => $fm->string_from_dada_style_args( { -fields => $data, } ), );

    $email_str = safely_decode($email_str);

    my $entity = $fm->email_template(
        {
            -entity => $fm->get_entity( { -data => safely_encode($email_str), } ),
            -expr   => $expr,
            %{ $args->{-tmpl_params} },    # note: this may have -expr param.
        }
    );
    my $msg = $entity->as_string;
    my ( $header_str, $body_str ) = split( "\n\n", $msg, 2 );

    my $header_str = safely_decode( $entity->head->as_string );
    my $body_str   = safely_decode( $entity->body_as_string );

    if ( $args->{-test} == 1 ) {
        $mh->test(1);
    }

    $mh->send( $mh->return_headers($header_str), Body => $body_str, );

}


sub send_abuse_report {
    my ($args) = @_;

    #    -list                 => $list,
    #    -email                => $email,
    #    -abuse_report_details => $abuse_report_details,
    #     -mid => $diagnostics->{'Simplified-Message-Id'},
    my $abuse_report_details = $args->{-abuse_report_details}; 
    
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $args->{-list}});

	require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('list_abuse_report_message.eml'); 

    if(!exists($args->{-mid})){ 
        $args->{-mid} = '00000000000000'; 
    }
    
    require  DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $args->{-list} } );
    
    my $worked = $lh->add_subscriber(
        {
            -email      => $args->{-email},
            -list       => $args->{-list},
            -type       => 'unsub_request_list',
            -dupe_check => {
                -enable  => 1,
                -on_dupe => 'ignore_add',
            },
        }
    );
    
    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
    my $approve_token = $ct->save(
        {
            -email => $args->{-email},
            -data  => {
                list        => $args->{-list},
                type        => 'list',
                mid         => $args->{-mid}, 
                flavor      => 'unsub_request_approve',
                remote_addr => $ENV{REMOTE_ADDR},
            },
            -remove_previous => 0,
        }
    );    
    
    send_generic_email(
        {
            -list    => $args->{-list},
            -headers => {
                To      => '"' . $msg_data->{to_phrase} . '" <' . $ls->param('list_owner_email') . '>',
                From    => '"' . $msg_data->{to_phrase} . '" <' . $ls->param('list_owner_email') . '>',
# Amazon SES doesn't like that: 
#                From    => '"' . $msg_data->{from_phrase} . '" <' . $args->{-email} . '>',

                Subject => $msg_data->{subject},
            },

            -body => $msg_data->{plaintext_body},
            -tmpl_params => {
                -list_settings_vars_param => { -list => $args->{-list} },
                -subscriber_vars_param    => {
					-list  => $args->{-list}, 
					-email => $args->{-email}, 
					-type  => 'list'
                },
                -vars => {
                    abuse_report_details                  => $abuse_report_details, 
                    list_unsubscribe_request_approve_link => $DADA::Config::S_PROGRAM_URL . '/t/' . $approve_token . '/',
                    
                },
            },
            -test => $args->{-test},
        }
    );

}




sub send_confirmation_message { 


	my ($args) = @_; 
	####
		my $ls;
		if(exists($args->{-ls_obj})){ 
			$ls = $args->{-ls_obj};
		}
		else {
			require DADA::MailingList::Settings; 
			$ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
		}
	####
	
	my $confirmation_msg = $ls->param('confirmation_message'); 
	require DADA::App::FormatMessages; 
	my $fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
	   $confirmation_msg = $fm->subscription_confirmationation({-str => $confirmation_msg}); 
	
	send_generic_email(
		{
			-list    => $args->{-list}, 
			-headers => { 
				To              => '"<!-- tmpl_var list_settings.list_name --> Subscriber" <' . $args->{-email} . '>',
			    Subject         => $ls->param('confirmation_message_subject'),
			}, 
			
			-body => $confirmation_msg,
				
			-tmpl_params => {
				-list_settings_vars_param => {-list => $args->{-list}},
	            -subscriber_vars_param    => {
					-list  => $args->{-list}, 
					-email => $args->{-email}, 
					-type  => 'sub_confirm_list'
				},
	            -vars => {
					'list.confirmation_token' => $args->{-token},
				},
			},
			
			-test => $args->{-test},
		}
	); 
	
    require       DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;
       $log->mj_log($args->{-list}, 'Subscription Confirmation Sent for ' . $args->{-list} . '.list', $args->{-email});     

}




sub send_subscribed_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	require DADA::App::Subscriptions::Unsub; 
	my $dasu = DADA::App::Subscriptions::Unsub->new({-list => $args->{-list}});
	my $unsub_link = $dasu->unsub_link({-email => $args->{-email}, -mid => '00000000000000'}); 
	$args->{-vars}->{list_unsubscribe_link} = $unsub_link; 


	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
					Subject => $ls->param('subscribed_message_subject'),
			}, 
			-body         => $ls->param('subscribed_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				-vars => $args->{-vars}, 
			},
			-test         => $args->{-test}, 
		}
	); 
	
	# Logging?
	
}



sub send_subscription_request_approved_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	require DADA::App::Subscriptions::Unsub; 
	my $dasu = DADA::App::Subscriptions::Unsub->new({-list => $args->{-list}});
	my $unsub_link = $dasu->unsub_link({-email => $args->{-email}, -mid => '00000000000000'}); 
	$args->{-vars}->{list_unsubscribe_link} = $unsub_link; 

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('subscription_request_approved_message_subject'),
			}, 
			-body         => $ls->param('subscription_request_approved_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				-vars => $args->{-vars}, 
			},
			-test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}




sub send_subscription_request_denied_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('subscription_request_denied_message_subject'),
			}, 
			-body         => $ls->param('subscription_request_denied_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				#-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				#-vars => $args->{-vars}, 
				-vars => { 
					'subscriber.email' => $args->{-email}, 
					%{$args->{-vars}},
				}
			},
			-test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}



# this is used when the token system is whack, and you request to unsub, uh, "manually"
sub send_unsubscribe_request_message { 
	
	my ($args) = @_;
	
	####
		my $ls;
		if(exists($args->{-ls_obj})){ 
			$ls = $args->{-ls_obj};
		}
		else {
			require DADA::MailingList::Settings; 
			$ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
		}
	####
	
	require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('unsubscription_request_message.eml'); 
	
	
	my $unsubscription_request_message = $msg_data->{plaintext_body};
	require DADA::App::FormatMessages; 
	my $fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
	   $unsubscription_request_message = $fm->unsubscription_confirmationation({-str => $unsubscription_request_message}); 
	
	require DADA::App::Subscriptions::Unsub; 
	my $dasu = DADA::App::Subscriptions::Unsub->new({-list => $args->{-list}});
	my $unsub_link = $dasu->unsub_link({-email => $args->{-email}, -mid => '00000000000000'}); 
	
	
	send_generic_email(
		{	
		-list        => $args->{-list},
		-ls_obj      => $ls,   
		-headers     => 
			{
					 To      =>  '"'. escape_for_sending($ls->param('list_name')) .' Subscriber"  <' . $args->{-email} . '>',
					 Subject =>  $msg_data->{subject}, 
			},
				
	    -body        => $unsubscription_request_message, 
		-tmpl_params => {
			-list_settings_vars_param => {
				-list => $args->{-list}
			},
            -subscriber_vars_param    => {
				-list  => $args->{-list}, 
				-email => $args->{-email}, 
				-type  => 'list'
			},
            -vars                     => {
#				'list.confirmation_token' => $args->{-token},
				list_unsubscribe_link => $unsub_link,
			},
			},
			-test         => $args->{-test},
		}
	); 
	
    require DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;
       $log->mj_log($args->{-list}, 'Unsubscription Confirmation Sent for ' . $args->{-list} . '.list', $args->{-email});     
 
}

sub subscription_approval_request_message { 
	
	my ($args) = @_;
	my $ls = $args->{-ls_obj}; 
	send_generic_email(
        {
            -list    => $ls->param('list'),
            -headers => {
                To => '"'
                  . escape_for_sending( $ls->param('list_name') )
                  . '" <'
                  . $ls->param('list_owner_email') . '>',
                Subject => $ls->param(
                    'subscription_approval_request_message_subject'),
            },
            -body =>
              $ls->param('subscription_approval_request_message'),
            -tmpl_params => {
                -list_settings_vars_param =>
                  { -list => $ls->param('list') },
                -subscriber_vars_param => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'sub_request_list'
                },
                -vars => {
					%{$args->{-vars}},
				},
            },
            -test => $args->{-test},
        }
    );
}

sub unsubscription_approval_request_message { 

	my ($args) = @_;
	my $ls = $args->{-ls_obj}; 
	
	send_generic_email(
     {
         -list    => $ls->param('list'),
         -headers => {
             To => '"'
               . escape_for_sending( $ls->param('list_name') )
               . '" <'
               . $ls->param('list_owner_email') . '>',
             Subject => $ls->param(
                 'unsubscription_approval_request_message_subject'),
         },
         -body =>
           $ls->param('unsubscription_approval_request_message'),
         -tmpl_params => {
             -list_settings_vars_param =>
               { -list => $ls->param('list') },
             -subscriber_vars_param => {
                 -list  => $ls->param('list'),
                 -email => $args->{-email},
                 -type  => 'unsub_request_list'
             },
             -vars => {
				%{$args->{-vars}},
			},
         },
         -test => $args->{-test},
     }
 );
}






sub send_unsubscribed_message { 
	
	my ($args) = @_; 
	
	if(!exists($args->{-test})){ 
		$args->{-test} = 0; 
	}
	
	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
	
	warn q{$ls->param('list')} . $ls->param('list');  
	warn q{$args->{-list}} . $args->{-list}; 
	
	# This is a hack - if the subscriber has recently been removed, you 
	# won't be able to get the subscriber fields - since there's no way to 
	# get fields of a removed subscriber. 
	# So! We'll go and grab the profile info, instead. 
	my $prof_fields  = {};
	my $unsub_fields = {};
		$unsub_fields->{ 'subscriber.email'} = $args->{-email};
		(
			$unsub_fields->{ 'subscriber.email_name'},
			$unsub_fields->{ 'subscriber.email_domain'}
		) = split(
			'@', 
			$args->{-email},
			2
		);
		require DADA::Profile; 
		my $prof = DADA::Profile->new({-email => $args->{-email}});
		if($prof){ 
			if($prof->exists){ 
				$prof_fields = $prof->{fields}->get;
				for ( keys %$prof_fields ) {
		            $unsub_fields->{ 'subscriber.' . $_ } = $prof_fields->{$_};
		        } 					
			}
		}
	#/This is a hack - if the subscriber has recently been removed, you
	
	
	send_generic_email(
		{

			-list        => $args->{-list},
			-ls_obj      => $ls,
			-email       => $args->{-email}, 
			-headers => { 	
				To           => '"<!-- tmpl_var list_settings.list_name -->" <' . $args->{-email} . '>',
				Subject      => $ls->param('unsubscribed_message_subject'), 
			},
			-body    => $ls->param('unsubscribed_message'),

			-test         => $args->{-test}, 
			
			-tmpl_params  => {	
				-list_settings_vars_param => 
					{
                        -list => $ls->param('list'),
						-dot_it => 1, 
					}, 
				#-subscriber_vars => {'subscriber.email' => $args->{-email}}, # DEV: This line right?
				-subscriber_vars          => $unsub_fields,
			},
		}
	); 
	
	# DEV: Logging?
}


sub send_owner_happenings {

    my ($args) = @_;

    my $ls;
    if ( !exists( $args->{-ls_obj} ) ) {
        require DADA::MailingList::Settings;
        $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );
    }
    else {
        $ls = $args->{-ls_obj};
    }

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'subscribed';
    }
    my $status = $args->{-role};

    if ( !exists( $args->{-note} ) ) {
        $args->{-note} = '';
    }

    if ( $status eq "subscribed" ) {
        if ( $ls->param('get_sub_notice') == 0 ) {
            return;
        }
    }
    elsif ( $status eq "unsubscribed" ) {
        if ( $ls->param('get_unsub_notice') == 0 ) {
            return;
        }
    }

    my $lh;
    if ( $args->{-lh_obj} ) {
        $lh = $args->{-lh_obj};
    }
    else {
        $lh =
          DADA::MailingList::Subscribers->new( { -list => $args->{-list} } );
    }
    my $num_subscribers = $lh->num_subscribers;

    # This is a hack - if the subscriber has recently been removed, you
    # won't be able to get the subscriber fields - since there's no way to
    # get fields of a removed subscriber.
    # So! We'll go and grab the profile info, instead.
    my $prof_fields  = {};
    my $unsub_fields = {};
    if ( $status eq "unsubscribed" ) {
        $unsub_fields->{'subscriber.email'} = $args->{-email};
        (
            $unsub_fields->{'subscriber.email_name'},
            $unsub_fields->{'subscriber.email_domain'}
        ) = split( '@', $args->{-email}, 2 );

        require DADA::Profile;
        my $prof = DADA::Profile->new( { -email => $args->{-email} } );
        if ($prof) {
            if ( $prof->exists ) {
                $prof_fields = $prof->{fields}->get;
                for ( keys %$prof_fields ) {
                    $unsub_fields->{ 'subscriber.' . $_ } = $prof_fields->{$_};
                }
            }
        }
    }

    my $msg_template = {
        subject => '',
        msg     => '',
    };
    if ( $status eq "subscribed" ) {
        $msg_template->{subject} =
          $ls->param('admin_subscription_notice_message_subject');
        $msg_template->{msg} = $ls->param('admin_subscription_notice_message');

    }
    elsif ( $status eq "unsubscribed" ) {
        $msg_template->{subject} =
          $ls->param('admin_unsubscription_notice_message_subject');
        $msg_template->{msg} =
          $ls->param('admin_unsubscription_notice_message');
    }

    require DADA::Template::Widgets;
    for (qw(subject msg)) {
        my $tmpl    = $msg_template->{$_};
        my $content = DADA::Template::Widgets::screen(
            {
                -data => \$tmpl,
                -vars => {
                    num_subscribers => $num_subscribers,
                    status          => $status,
                    note            => $args->{-note},
                    REMOTE_ADDR     => $ENV{REMOTE_ADDR},

                },
                -list_settings_vars_param => { -list => $args->{-list} },
                ( $status eq "subscribed" )
                ? (
                    -subscriber_vars_param => {
                        -list  => $args->{-list},
                        -email => $args->{-email},
                        -type  => 'list'
                    },
                  )
                : ( -subscriber_vars => $unsub_fields, )
            }
        );
        $msg_template->{$_} = $content;

    }

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $args->{-list} );
    $fm->use_email_templates(0);

    my $formatted_from = $fm->_encode_header(
        'From',
        $fm->format_phrase_address(
            $ls->param('list_name'),
            $ls->param('list_owner_email'),
        )
    );

    my $send_to = 'list_owner';
    if ( $status eq "subscribed" ) {
        $send_to = $ls->param('send_subscription_notice_to');
    }
    else {
        $send_to = $ls->param('send_unsubscription_notice_to');
    }

    if ( $send_to eq 'list' ) {
        $fm->mass_mailing(1);
        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new( { -list => $args->{-list} } );
        $mh->list_type('list');
        my $message_id = $mh->mass_send(
            {
                -msg => {
                    From    => $formatted_from,
                    Subject => $msg_template->{subject},
                    Body    => $msg_template->{msg},
                },
            }
        );

    }
    else {
        send_generic_email(
            {
                -list    => $args->{-list},
                -headers => {
                    From    => $formatted_from,
                    To      => $formatted_from,
                    Subject => $msg_template->{subject},
                },
                -body => $msg_template->{msg},
                -test => $args->{-test},
            }

        );
    }
}



sub send_you_are_already_subscribed_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
		
	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
        
		-headers => { 
			To           => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
			Subject      => $ls->param('you_are_already_subscribed_message_subject'), 
		},
		
		-body         => $ls->param('you_are_already_subscribed_message'), 
		
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $ls->param('list'),},
			-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
		},
		
		-test         => $args->{-test}, 
		}
	);
	
}




sub send_not_subscribed_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
		
	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
        
		-headers => { 
			To           => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
			Subject      => $ls->param('you_are_not_subscribed_message_subject'), 
		},
		
		-body         => $ls->param('you_are_not_subscribed_message'), 
		
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $ls->param('list'),},
			-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
		},
		-test         => $args->{-test}, 
		}
	);
	
}


sub send_newest_archive { 

	# Gonna leave this as it is for now...
	my ($args) = @_; 
	
	die "no list!"         if ! exists($args->{-list}); 
	die "no email!"        if ! exists($args->{-email}); 

	
	if(! exists($args->{-test})){ 
		$args->{-test} = 0;
	}
		


	####
		my $ls;
		if(exists($args->{-ls_obj})){ 
			$ls = $args->{-ls_obj};
		}
		else {
			require DADA::MailingList::Settings; 
			$ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
		}
	####

	####
		my $la;
		if(exists($args->{-la_obj})){ 
			$la = $args->{-la_obj};
		}
		else {
			require DADA::MailingList::Archives; 
			$la = DADA::MailingList::Archives->new(
					{
						-list => $args->{-list}
					}
				);
		}
	
	####




    my $newest_entry = $la->newest_entry; 

	
	if(
		defined($newest_entry) && 
		$newest_entry      > 1
	){ 
		
		my ($head, $body) = $la->massage_msg_for_resending(
								-key     => $newest_entry, 
								'-split' => 1,
							);
							
		require DADA::Mail::Send; 
		my $mh = DADA::Mail::Send->new(
					{
						-list   => $args->{-list}, 
						-ls_obj => $ls,
					}
				);
		
		if($args->{-test} == 1){ 
			$mh->test(1);	
		}
		

		
		
		send_generic_email(
			{
	    	-list         => $args->{-list}, 
	        -email        => $args->{-email}, 
	        -ls_obj       => $ls, 

			-headers => { 
						 $mh->return_headers($head),  
					  	 To             => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
			},

			-body         => $body, 

			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
			},

			-test         => $args->{-test}, 
			}
		);
		
	
		return 1;
	}
	else { 
		return 0; 
	}
}



# This one's weird, since it's a part of Bridge 

sub send_not_allowed_to_post_msg { 
	
	my ($args) = @_; 

	require MIME::Entity; 
	
	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	my $attachment;
	if(!exists($args->{-attachment})){ 
		croak "I need an attachment in, -attachment!"; 
	}
	else { 
		$attachment = $args->{-attachment}; 
	}
	

	my $reply = MIME::Entity->build(Type 	=> "multipart/mixed", 
									Subject => $ls->param('not_allowed_to_post_msg_subject'),
									%{$args->{-headers}},
									To           => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
									);
									
	$reply->attach(
				   Type     => 'text/plain', 
				   Encoding => $ls->param('plaintext_encoding'),
				   Data     => $ls->param('not_allowed_to_post_msg'),
				  ); 
				
	$reply->attach( Type        => 'message/rfc822', 
					Disposition  => "attachment",
					Data         => $attachment,
					); 


	# This is weird. I sorta want to do this myself, but maybe I'll just let, 
	# send_generic_email sort it all out...
	
	my $msg_str = $reply->as_string; 
	my ($headers, $body) = split("\n\n", $msg_str, 2);
	my %headers = _mime_headers_from_string($headers);  

	# well, I guess three lines ain't that bad; 


	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
		-headers => { 
			%headers, 
		},
		-body         => $body, 
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $args->{-list}},
			#-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
			-subscriber_vars => 
				{
					'subscriber.email' => $args->{-email}
				},
		},

		-test         => $args->{-test}, 
		}
	);

}

sub send_unsubscription_request_approved_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('unsubscription_request_approved_message_subject'),
			}, 
			-body         => $ls->param('unsubscription_request_approved_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
                -subscriber_vars => 
    				{
    					'subscriber.email' => $args->{-email}
    				},
				# -subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				# -profile_vars_param       => {-email => $args->{-email}},
				# -vars => $args->{-vars}, 
			},
			# -test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}




sub send_unsubscription_request_denied_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('unsubscription_request_denied_message_subject'),
			}, 
			-body         => $ls->param('unsubscription_request_denied_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars => 
    				{
    					'subscriber.email' => $args->{-email}
    				},
				-vars => { 
					'subscriber.email' => $args->{-email}, 
					%{$args->{-vars}},
				}
			},
			# -test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}





sub _mime_headers_from_string { 

	#get the blob
	my $header_blob = shift || "";


	#init a new %hash
	my %new_header;

	# split.. logically
	my @logical_lines = split /\n(?!\s)/, $header_blob;
 
	    # make the hash
	    for my $line(@logical_lines) {
	          my ($label, $value) = split(/:\s*/, $line, 2);
	          $new_header{$label} = $value;
	        }
		
	return %new_header; 

}


1;


=pod

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

