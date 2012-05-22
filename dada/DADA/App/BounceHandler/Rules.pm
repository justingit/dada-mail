package DADA::App::BounceHandler::Rules;

use strict;
use lib qw(
  ../../../
  ../../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use 5.008_001;
use Mail::Verp;

use Carp qw(croak carp);
use vars qw($AUTOLOAD);

my %allowed = ();

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

}

sub find_rule_to_use {

    my $self  = shift;
    my $Rules = [];
    $Rules = $self->rules;

    my ( $list, $email, $diagnostics ) = @_;

    my $ir = 0;

  RULES: for ( $ir = 0 ; $ir <= $#$Rules ; $ir++ ) {
        my $rule  = $Rules->[$ir];
        my $title = ( keys %$rule )[0];

        next if $title eq 'default';
        my $match   = {};
        my $examine = $Rules->[$ir]->{$title}->{Examine};

        my $message_fields = $examine->{Message_Fields};
        my %ThingsToMatch;

        for my $m_field ( keys %$message_fields ) {
            my $is_regex   = 0;
            my $real_field = $m_field;
            $ThingsToMatch{$m_field} = 0;

            if ( $m_field =~ m/_regex$/ ) {
                $is_regex   = 1;
                $real_field = $m_field;
                $real_field =~ s/_regex$//;
            }

          MESSAGEFIELD:
            for my $pos_match ( @{ $message_fields->{$m_field} } ) {
                if ( $is_regex == 1 ) {
					if(exists($diagnostics->{$real_field})){ 
	                    if ( $diagnostics->{$real_field} =~ m/$pos_match/ ) {
	                        $ThingsToMatch{$m_field} = 1;
	                        next MESSAGEFIELD;
	                    }
					}
                }
                else {
					if(exists($diagnostics->{$real_field})){ 		
	                    if ( $diagnostics->{$real_field} eq $pos_match ) {
	                        $ThingsToMatch{$m_field} = 1;
	                        next MESSAGEFIELD;
	                    }
					}

                }
            }

        }

        # If we miss one, the rule doesn't work,
        # All or nothin', just like life.

        for ( keys %ThingsToMatch ) {
            if ( $ThingsToMatch{$_} == 0 ) {
                next RULES;
            }
        }

        if ( keys %{ $examine->{Data} } ) {
            if ( $examine->{Data}->{Email} ) {
                my $valid_email = 0;
                my $email_match;
                if ( DADA::App::Guts::check_for_valid_email($email) == 0 ) {
                    $valid_email = 1;
                }
                if (
                    (
                           ( $examine->{Data}->{Email} eq 'is_valid' )
                        && ( $valid_email == 1 )
                    )
                    || (   ( $examine->{Data}->{Email} eq 'is_invalid' )
                        && ( $valid_email == 0 ) )
                  )
                {
                    $email_match = 1;
                }
                else {
                    next RULES;
                }
            }

            if ( $examine->{Data}->{List} ) {
                my $valid_list = 0;
                my $list_match;
                if ( DADA::App::Guts::check_if_list_exists( -List => $list ) !=
                    0 )
                {
                    $valid_list = 1;
                }
                if (
                    (
                           ( $examine->{Data}->{List} eq 'is_valid' )
                        && ( $valid_list == 1 )
                    )
                    ||

                    (
                           ( $examine->{Data}->{List} eq 'is_invalid' )
                        && ( $valid_list == 0 )
                    )
                  )
                {
                    $list_match = 1;
                }
                else {
                    next RULES;
                }
            }
        }
        return $title;
    }
    return 'default';
}

sub rules {

    my $self = shift;

    #{
    #	hotmail_notification => {
    #		Examine => {
    #			Message_Fields => {
    #			   'Remote-MTA'          => [qw(Windows_Live)],
    #				Bounce_From_regex    =>  [qr/staff\@hotmail.com/],
    #				Bounce_Subject_regex => [qr/complaint/],
    #			},
    #
    #			Data => {
    #				Email => 'is_valid',
    #				List  => 'is_valid',
    #			}
    #		},
    #		Action => {
    #			unsubscribe_bounced_email	=> 'from_list',
    #		}
    #	}
    #},

    my $Rules = [
	
    {
        amazon_ses_dsn_no_such_user => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA  => [qw(Amazon_SES)],
					Action => [qw(failed)],
					Status_regex => [qr/5\.0\.0/],
                    'Diagnostic-Code_regex' => [qr/Unknown address/],
                },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => {
				add_to_score => 'hardbounce_score',
            }
        }
    },
    {
        secureserver_dot_net_mailbox_full => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA  => [qw(secureserver_dot_net)],
					'Diagnostic-Code_regex' => [qr/mailfolder is full|Mail quota exceeded/],
                },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => {
				add_to_score => 'softbounce_score',
            }
        }
    },

		
        {
            qmail_delivery_delay_notification => {
                Examine => {
                    Message_Fields => {
                        Guessed_MTA => [qw(Qmail)],
                        'Diagnostic-Code_regex' =>
                          [qr/The mail system will continue delivery attempts/],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #nothing!
                }
            }
        },

        {
            hotmail_over_quota => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.2.3)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' =>
                          [ (qr/larger than the current system limit/) ]
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            over_quota_obscure_mta => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.0.0)],
                        'Final-Recipient_regex' => [ (qr/LOCAL\;\<\>/) ],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            over_quota => {
                Examine => {
                    Message_Fields => {
                        Action => [qw(failed Failed)],
                        Status => [qw(5.2.2 4.2.2 5.0.0 5.1.1)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' => [
                            (
qr/552|exceeded storage allocation|over quota|storage full|mailbox full|disk quota exceeded|Mail quota exceeded|Quota violation/
                            )
                        ]
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            over_quota_obscure_mta_two => {
                Examine => {

                    Message_Fields => {
                        Action => [qw(failed)],
                        Status => [qw(4.2.2)],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            yahoo_over_quota => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.0.0)],
                        'Remote-MTA_regex'      => [ (qr/yahoo.com/) ],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' => [ (qr/over quota/) ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            yahoo_over_quota_two => {
                Examine => {
                    Message_Fields => {
                        'Remote-MTA'            => [qw(yahoo.com)],
                        'Diagnostic-Code_regex' => [ (qr/over quota/) ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            qmail_over_quota => {
                Examine => {
                    Message_Fields => {

                        Guessed_MTA             => [qw(Qmail)],
                        Status                  => [qw(5.2.2 5.x.y)],
                        'Diagnostic-Code_regex' => [
                            (
qr/mailbox is full|Exceeded storage allocation|recipient storage full|mailbox full|storage full/
                            )
                        ],

                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            over_quota_552 => {
                Examine => {
                    Message_Fields => {
                        'Diagnostic-Code_regex' =>
                          [ (qr/552 recipient storage full/) ],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            qmail_tmp_disabled => {
                Examine => {
                    Message_Fields => {

                        Guessed_MTA => [qw(Qmail)],
                        Status      => [qw(4.x.y)],
                        'Diagnostic-Code_regex' =>
                          [ (qr/temporarily disabled/) ],

                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'softbounce_score', }
            }
        },

        {
            delivery_time_expired => {
                Examine => {
                    Message_Fields => {
                        Status_regex => [qr(/4.4.7|delivery time expired/)],
                        Action_regex => [qr(/Failed|failed/)],
                        'Final-Recipient_regex' => [qr(/822/)],

                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    # TODO:
                    # Not sure what to put here ATM.
                }
            }
        },

        {
            status_over_quota => {
                Examine => {
                    Message_Fields => {

                        Action => [qw(Failed failed)],    #originally Failed
                        Status => [qr/mailbox full/],     # like, wtf?
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            earthlink_over_quota => {
                Examine => {
                    Message_Fields => {
                        'Diagnostic-Code_regex' => [qr/522|Quota violation/],
                        'Remote-MTA'            => [qw(Earthlink)],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'softbounce_score',
                }
            }
        },

        {
            qmail_error_5dot5dot1 => {
                Examine => {
                    Message_Fields => {

                        Guessed_MTA => [qw(Qmail)],

                        #Status                  => [qw(5.1.1)],
                        'Diagnostic-Code_regex' => [ (qr/551/) ],

                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'hardbounce_score', }
            }
        },

        {
            qmail_error_5dot1dot1 => {
                Examine => {
                    Message_Fields => {

                        Guessed_MTA => [qw(Qmail)],
                        Status      => [qw(5.1.1)],
                        'Diagnostic-Code_regex' =>
                          [ (qr/no mailbox here by that name/) ],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'hardbounce_score', }
            }
        },
		{
           qmail_error2_5dot1dot1 => {
                Examine => {
                    Message_Fields => {

                        Guessed_MTA => [qw(Qmail)],
                       # Status      => [qw(5.1.1)],
                        'Diagnostic-Code_regex' =>
                          [ (qr/511 sorry, no mailbox here by that name/) ],
                    },

                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { 
					add_to_score => 'hardbounce_score',
                     
				}
            }
        },

        {

            # AOL, apple.com, mac.com, altavista.net, pobox.com...
            delivery_error_550 => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.1.1)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' => [
                            (
qr/SMTP\; 550|550 MAILBOX NOT FOUND|550 5\.1\.1 unknown or illegal alias|User unknown|No such mail drop/
                            )
                        ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'hardbounce_score',
                }
              } 
	},

        {

            # same as above, but without the Diagnostic_Code_regex.

            delivery_error_5dot5dot1_status => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.1.1)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'hardbounce_score', }
              } },

        {

            # Yahoo!
            delivery_error_554 => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.0.0 5.5.0)],
                        'Diagnostic-Code_regex' => [ (qr/554 delivery error/) ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'hardbounce_score',
                }
              } },

        {
            qmail_user_unknown => {
                Examine => {
                    Message_Fields => {
                        Status      => [qw(5.x.y)],
                        Guessed_MTA => [qw(Qmail)],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                }
            }
        },

        {
            qmail_error_554 => {
                Examine => {
                    Message_Fields => {
                        'Diagnostic-Code_regex' => [ (qr/554/) ],
                        Guessed_MTA => [qw(Qmail)],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'hardbounce_score',
                }
            }
        },

        {
            qmail_error_550 => {
                Examine => {
                    Message_Fields => {
                        'Diagnostic-Code_regex' => [ (qr/550/) ],
                        Guessed_MTA => [qw(Qmail)],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'hardbounce_score', }
            }
        },

        {
            qmail_unknown_domain => {
                Examine => {
                    Message_Fields => {
                        Status      => [qw(5.1.2)],
                        Guessed_MTA => [qw(Qmail)],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'hardbounce_score', }
            }
        },

        {

            # more info:
            # http://www.qmail.org/man/man1/bouncesaying.html

            qmail_bounce_saying => {
                Examine => {
                    Message_Fields => {
                        'Diagnostic-Code_regex' =>
                          [qr/This address no longer accepts mail./],
                        Guessed_MTA => [qw(Qmail)],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                }
              } },

        {
            exim_user_unknown => {
                Examine => {
                    Message_Fields => {
                        Status      => [qw(5.x.y)],
                        Guessed_MTA => [qw(Exim)],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                },
            }
        },
        { 
	
			exim_retry_timeout_exceeded => {
             Examine => {
                 Message_Fields => {
                     Guessed_MTA => [qw(Exim)],
                     'Diagnostic-Code_regex' => [ (qr/retry timeout exceeded/) ],

                 },
                 Data => {
                     Email => 'is_valid',
                     List  => 'is_valid',
                 }
             },
             Action => {
                 add_to_score => 'softbounce_score',
             },
         }
     },
        {
            exchange_user_unknown => {
                Examine => {
                    Message_Fields => {

                        #Status      => [qw(5.x.y)],
                        Guessed_MTA             => [qw(Exchange)],
                        'Diagnostic-Code_regex' => [ (qr/Unknown Recipient/) ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    },
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                }
            }
        },

        #{
        #novell_access_denied => {
        #	Examine => {
        #			Message_Fields => {
        #				#Status         => [qw(5.x.y)],
        #				'X-Mailer_regex' => [qw(Novell)],
        #				'Diagnostic-Code_regex' => [(qr/access denied/)],
        #			},
        #			Data => {
        #				Email       => 'is_valid',
        #				List        => 'is_valid',
        #			},
        #
        #		},
        #			Action => {
        #				#unsubscribe_bounced_email => 'from_list',
        #               add_to_score => 'hardbounce_score',
        #		}
        #	}
        #},

        {

    # note! this should really make no sense, but I believe this is a bounce....
            aol_user_unknown => {
                Examine => {
                    Message_Fields => {
                        Status                  => [qw(2.0.0)],
                        Action                  => [qw(failed)],
                        'Reporting-MTA_regex'   => [ (qr/aol\.com/) ],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' => [ (qr/250 OK/) ]
                        ,    # no for real, everything's "OK" #
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    add_to_score => 'hardbounce_score',
                },
              } },

        {

            user_unknown_5dot3dot0_status => {
                Examine => {
                    Message_Fields => {
                        Action                  => [qw(failed)],
                        Status                  => [qw(5.3.0)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' =>
                          [ (qr/No such user|Addressee unknown/) ],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => { add_to_score => 'hardbounce_score', }
              } },

        {
            user_inactive => {
                Examine => {
                    Message_Fields => {

                        Status_regex            => [ (qr/5\.0\.0/) ],
                        Action                  => [qw(failed)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' => [
                            (qr/user inactive|Bad destination|bad destination/)
                        ],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                },
            }
        },

        {
            postfix_5dot0dot0_error => {
                Examine => {
                    Message_Fields => {

                        Status      => [qw(5.0.0)],
                        Guessed_MTA => [qw(Postfix)],
                        Action      => [qw(failed)],

                       #said_regex              => [(qr/550\-Mailbox unknown/)],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                },
            }
        },


      	 {
	            bounce_4dot4dot1_error => {
	                Examine => {
	                    Message_Fields => {
	                        Status                  => [qw(4.4.1)],
	                        Action                  => [qw(failed)],
							'Diagnostic-Code_regex' =>  [ (qr/(C|c)onnection refused/) ],
	                    },
	                    Data => {
	                        Email => 'is_valid',
	                        List  => 'is_valid',
	                    }
	                },
	                Action => {

	                    #unsubscribe_bounced_email => 'from_list',
	                    add_to_score => 'hardbounce_score',
	                },
	            }
	        },



        {
            permanent_move_failure => {
                Examine => {
                    Message_Fields => {

                        Status                  => [qw(5.1.6)],
                        Action                  => [qw(failed)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' => [
                            (
qr/551 not our customer|User unknown|ecipient no longer/
                            )
                        ],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                },
            }
        },

        {
            unknown_domain => {
                Examine => {
                    Message_Fields => {

                        Status                  => [qw(5.1.2)],
                        Action                  => [qw(failed)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

                    #unsubscribe_bounced_email => 'from_list',
                    add_to_score => 'hardbounce_score',
                },
            }
        },

        {
            relaying_denied => {
                Examine => {
                    Message_Fields => {

                        Status                  => [qw( 5.7.1)],
                        Action                  => [qw(failed)],
                        'Final-Recipient_regex' => [ (qr/822/) ],
                        'Diagnostic-Code_regex' =>
                          [ (qr/Relaying denied|relaying denied/) ],

                    },
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    }
                },
                Action => {

            # TODO
            # Again, not sure quite what to put here - will be silently ignored.

                  # NOTE: Sometimes this message is sent by servers of spammers.
                },
            }
        },

        #{
        # Supposively permanent error.
        #access_denied => {
        #					Examine => {
        #						Message_Fields => {
        #
        #							Status                  => [qw(5.7.1)],
        #							Action                  => [qw(failed)],
        #						    'Final-Recipient_regex' => [(qr/822/)],
        #						    'Diagnostic-Code_regex' => [(qr/ccess denied/)],
        #
        #					},
        #					Data => {
        #						Email => 'is_valid',
        #						List  => 'is_valid',
        #					}
        #					},
        #					Action => {
        #						#unsubscribe_bounced_email => 'from_list',
        #                        add_to_score => 'hardbounce_score',
        #					},
        #					}
        #},

        {

            unknown_bounce_type => {
                Examine => {
                    Data => {
                        Email => 'is_valid',
                        List  => 'is_valid',
                    },
                },
                Action => {

                    add_to_score => 'softbounce_score',
                  }

              } },

        {
            email_not_found => {
                Examine => {
                    Data => {
                        Email => 'is_invalid',
                        List  => 'is_valid',
                    },
                },
                Action => {}
            }
        },

    ];

    return $Rules;
}

sub DESTROY { }

1;

=pod

=head1 Introduction to Rules


An example Rule: 

     {
        exim_user_unknown => { 
            Examine => { 
                Message_Fields => { 
                    Status      => [qw(5.x.y)], 
                    Guessed_MTA => [qw(Exim)],  
                }, 
                Data => { 
                    Email       => 'is_valid',
                    List        => 'is_valid', 
                }
            },
                Action => { 
                     add_to_score => 'hardbounce_score',
                }, 
            }
    }, 

B<exim_user_unknown> is the title of the rule -  just a label, nothing else.

B<Examine> holds a set of parameters that the handler looks at when
trying to figure out what to do with a bounced message. This example
has a B<Message_Fields> entry and inside that, a B<Status> entry. The
B<Status> entry holds a list of status codes. The ones in shown there
all correspond to hard bounces; the mailbox probably doesn't exist. 

B<Message_Fields> also hold a, B<Guessed_MTA> entry - it's explicitly looking for a 
bounce back from the, I<Exim> mail server. 


B<Examine> also holds a B<Data> entry, which holds the B<Email> or B<List> 
entries, or both. Their values are either 'is_valid', or 'is_invalid'. 

So, to sum this all up, this rule will match a message that has B<Status:> 
B<Message Field> contaning a user unknown error code, B<(5.1.1, etc)> and also a B<Guessed_MTA> B<Message Field> containing, B<Exim>. The message
also has to be parsed to have found a valid email and list name. 

If this all matches, the B<Action> is... acted upon. In this case, the offending email address will be appended a, B<Bounce Score> of,
 whatever, B<UPDATE THIS>, which is by default, B<4>. 

If you would like to have the bounced address automatically removed, without any sort of scoring happening, change the B<action> from,

    add_to_score => 'hardbounce_score',

to: 

    unsubscribe_bounced_email => 'from_list'

Also, changing B<from_list>, to B<from_all_lists> will do the trick. 

Here's a schematic of all the different things you can do: 

 {
 rule_name => {
	 Examine => {
		Message_Fields => {
			Status               => qw([    ]), 
			Last-Attempt-Date    => qw([    ]), 
			Action               => qw([    ]), 
			Status               => qw([    ]), 
			Diagnostic-Code      => qw([    ]), 
			Final-Recipient      => qw([    ]), 
			Remote-MTA           => qw([    ]), 
			# etc, etc, etc
			
		},
		Data => { 
			Email => 'is_valid' | 'is_invalid' 
			List  => 'is_valid' | 'is_invalid' 
		}
	},
	Action => { 
	           add_to_score             =>  $x, # where, "$x" is a number
			   unsubscribe_bounced_email => 'from_list' | 'from_all_lists',
	},
 },	

Rules also support the use of regular expressions for matching any of the B<Message_Fields>. 
To tell the parser that you're using a regular expression, make the Message_Field key end in '_regex': 

 'Final-Recipient_regex' => [(qr/RFC822/)], 

=cut

