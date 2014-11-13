$Rules = [

    {
        amazon_ses_dsn_no_such_user => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA             => [qw(Amazon_SES)],
                    Action                  => [qw(failed)],
                    Status_regex            => [qr/5\.0\.0/],
                    'Diagnostic-Code_regex' => [qr/Unknown address/],
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
        amazon_ses_delivery_expired => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA  => [qw(Amazon_SES)],
                    Action       => [qw(failed)],
                    Status_regex => [qr/5\.0\.0/],
                    'Diagnostic-Code_regex' =>
                      [qr/5\.4\.7 \- Delivery expired/],
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
        amazon_ses_delivery_expired_soft => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA             => [qw(Amazon_SES)],
                    Action                  => [qw(failed)],
                    Status                  => [qw(4.4.7)],
                    'Diagnostic-Code_regex' => [qr/4\.4\.7 Message expired/],
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
		amazon_ses_abuse_report   => {
	               Examine => {
	                   Message_Fields => {
						   Bounce_From => ['complaints@email-abuse.amazonses.com'],
	                   },
	                   Data => {
	                   }
	               },
	               Action => { abuse_report => 'abuse_report', }
	           }
		   },
    {
        gmail_disabled_account => {
            Examine => {
                Message_Fields => {
                    Action                  => [qw(failed)],
                    Status                  => [qw(5.2.1)],
                    'Diagnostic-Code_regex' => [
qr/The email account that you tried to reach is disabled/
                    ],
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
        blackberry_handheld_5_0_0 => {
            Examine => {
                Message_Fields => {
                    Action               => [qw(failed Failed)],
                    Status               => [qw(5.0.0)],
                    'Notification_regex' => [
qr/not been delivered to the recipient's BlackBerry Handheld/
                    ],
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
        mailbox_currently_suspended => {
            Examine => {
                Message_Fields => {
                    Action => [qw(failed)],
                    Status => [qw(5.3.0)],
                    'Diagnostic-Code_regex' =>
                      [qr/SUSPEND|Mailbox currently suspended/],
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
        mailbox_does_not_exist_5_dot_6_dot_0 => {
            Examine => {
                Message_Fields => {
                    Action               => [qw(failed)],
                    Status               => [qw(5.6.0)],
                    'Notification_regex' => [qr/not exist/],
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
        secureserver_dot_net_mailbox_full => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA => [qw(secureserver_dot_net)],
                    'Diagnostic-Code_regex' =>
                      [qr/mailfolder is full|Mail quota exceeded/],
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
        secureserver_dot_net_mailbox_full => {
            Examine => {
                Message_Fields => {
                    Guessed_MTA => [qw(secureserver_dot_net)],
                    'Diagnostic-Code_regex' =>
                      [qr/mailfolder is full|Mail quota exceeded/],
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
        little_details_mailbox_is_full => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' => [qr/INBOX IS FULL|mailfolder is full/],
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
                    Status => [
                        '5.2.2', '4.2.2',
                        '5.0.0', '5.1.1',
                        '5.2.2 (mailbox full)'
                    ],
                    'Diagnostic-Code_regex' => [
                        (
qr/552|quota exceeded|exceeded storage allocation|over quota|storage full|mailbox full|disk quota exceeded|Mail quota exceeded|Quota violation/
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
        yahoo_no_account => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' =>
                      [ (qr/This user doesn\'t have a yahoo\.com/) ],
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
        yahoo_dmarc => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' =>
                      [ (qr/5\.7\.9 Message not accepted for policy reasons/)],
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
        google_dmarc => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' =>
                      [ (qr/DMARC policy/)],
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
         hotmail_dmarc => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' =>
                      [ (qr/domain owner policy restrictions/)],
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
qr/mailbox is full|Exceeded storage allocation|recipient storage full|mailbox full|storage full|Not enough storage space/
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
        qmail_over_quota2 => {
            Examine => {
                Message_Fields => {

                    Guessed_MTA          => [qw(Qmail)],
                    'Notification_regex' => [
                        (
qr/mailbox is full|Exceeded storage allocation|recipient storage full|mailbox full|storage full|Not enough storage space|user is over quota/
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
        ya_over_quota => {
            Examine => {
                Message_Fields => {

                    Status               => [qw(5.0.0)],
                    'Notification_regex' => [
                        (
qr/mailbox is full|Exceeded storage allocation|recipient storage full|mailbox full|storage full|Not enough storage space|user is over quota/
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

                    Guessed_MTA             => [qw(Qmail)],
                    Status                  => [qw(4.x.y)],
                    'Diagnostic-Code_regex' => [ (qr/temporarily disabled/) ],

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
        delivery_delayed => {
            Examine => {
                Message_Fields => {
                    Status => [qw(4.4.7)],
                    Action => [qw(delayed)],
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
          } },

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
        following_recipients_failed => {
            Examine => {
                Message_Fields => {
                    Action             => [qw(failed)],
                    Status             => [qw(5.5.0)],
                    Notification_regex => [ (qr/following recipients failed/) ],
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

        qmail_tmp_error => {
            Examine => {
                Message_Fields => {
                    Status      => [qw(4.3.0)],
                    Guessed_MTA => [qw(Qmail)],
                },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'softbounce_score', }
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
                    Guessed_MTA             => [qw(Exim)],
                    'Diagnostic-Code_regex' => [ (qr/retry timeout exceeded/) ],

                },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'softbounce_score', },
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

        relay_not_permitted_5dot3dot0_status => {
            Examine => {
                Message_Fields => {
                    Action                  => [qw(failed)],
                    Status                  => [qw(5.3.0)],
                    'Diagnostic-Code_regex' => [ (qr/relay not permitted/) ],

                },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'hardbounce_score', }
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
                    'Diagnostic-Code_regex' =>
                      [ (qr/user inactive|Bad destination|bad destination/) ],

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
                    Status => [qw(4.4.1)],
                    Action => [qw(failed)],
                    'Diagnostic-Code_regex' =>
                      [ (qr/delivery temporarily suspended/) ],
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
        no_such_domain => {
            Examine => {
                Message_Fields => {

                    Status => [qw(5.3.0)],
                    Action => [qw(failed)],
                    'Diagnostic-Code_regex' =>
                      [ (qr/No such domain at this location/) ],
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
        axigen_permanent_failure_notice => {
            Examine => {
                Message_Fields => {

                    Bounce_Subject_regex => [qr/Permanent failure notice/],
                },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => {
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
            Action => { add_to_score => 'hardbounce_score', },
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
        no_such_recipient => {
            Examine => {
                Message_Fields => {
                    Status                  => [qw(5.0.0)],
                    Action                  => [qw(failed)],
                    'Diagnostic-Code_regex' => [qr/No such recipient/],
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
        generic_mailbox_unavailable => {
            Examine => {
                Message_Fields =>
                  { 'Notification_regex' => [qr/mailbox unavailable/], },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'hardbounce_score', }
        }
    },

    {
        generic_mailbox_unavailable2 => {
            Examine => {
                Message_Fields => {
                    Status                  => [qw(5.3.0 5.2.0)],
                    'Diagnostic-Code_regex' => [qr/mailbox unavailable/i],
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
        not_much_to_go_on_5_3_0 => {
            Examine => {
                Message_Fields => { Status => [qw(5.3.0)], },
                Data           => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'hardbounce_score', }
        }
    },

    {
        generic_no_such_user_here => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' => [
qr/No Such User Here|The email account that you tried to reach does not exist/
                    ],
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
        sender_denied => {
            Examine => {
                Message_Fields => {
                    Status_regex            => [qr/5\.0\.0|5\.1\.0/],
                    'Diagnostic-Code_regex' => [qr/sender denied/i],
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
        denylist => {
            Examine => {
                Message_Fields => {
                    'Diagnostic-Code_regex' =>
                      [qr/Sender is on user denylist/i],
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
        error_5_7_1 => {
            Examine => {
                Message_Fields => { Status => [qw(5.7.1)], },
                Data           => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'hardbounce_score', }
        }
    },

    {
        disabled_or_discontinued => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' =>
                      [qr/This account has been disabled or discontinued/],
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
        permanent_error => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' => [qr/This is a permanent error\./],
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
        no_mailbox_here_by_that_name => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' => [qr/no mailbox here by that name/],
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
        generic_could_not_deliver_mail => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' =>
                      [qr/The mail server could not deliver mail to/],
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
        generic_domain_may_not_exist => {
            Examine => {
                Message_Fields =>
                  { 'Notification_regex' => [qr/domain may not exist/], },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'hardbounce_score', }
        }
    },
    {
        generic_retry_time_not_reached_for_any_host => {
            Examine => {
                Message_Fields => {
                    'Notification_regex' => [
qr/retry time not reached for any host after a long failure period/
                    ],
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
        generic_account_is_locked => {
            Examine => {
                Message_Fields =>
                  { 'Notification_regex' => [qr/account is locked/], },
                Data => {
                    Email => 'is_valid',
                    List  => 'is_valid',
                }
            },
            Action => { add_to_score => 'softbounce_score', }
        }
    },
    {
        generic_unknown_address => {
            Examine => {
                Message_Fields => {
                    Action       => [qw(failed)],
                    Status_regex => [qr/5\.0\.0/],
                    'Diagnostic-Code_regex' =>
                      [qr/Unknown address|unknown user account/],
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

        }
    },

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
