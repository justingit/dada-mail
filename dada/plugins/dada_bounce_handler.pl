#!/usr/bin/perl

package dada_bounce_handler;


use strict; 

#---------------------------------------------------------------------#
# dada_bounce_handler.pl (Mystery Girl) 
#
# Documentation:
#  
#  http://dadamailproject.com/support/documentation/dada_bounce_handler.pl.html
#
#---------------------------------------------------------------------#


# A weird fix.
BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}



$ENV{PATH} = "/bin:/usr/bin"; 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

use lib qw(

../ 
../DADA/perllib 
../../../../perl 
../../../../perllib 

); 

use CGI::Carp qw(fatalsToBrowser); 
use DADA::Config 4.0.0;

my $Plugin_Config = {}; 
# Also see the Config.pm variable, "$PLUGIN_CONFIGS" to set these plugin variables 
# in the Config.pm file itself, or, in the outside config file (.dada_config) 


# Required!
# What is the POP3 mail server of the bounce email address? 	
$Plugin_Config->{Server}   = undef;

# Required!
# And the username? 
$Plugin_Config->{Username} = undef; 

# Required!
# Password?
$Plugin_Config->{Password} = undef;

#---------------------------------------------------------------------#
# Optional Settings - #
#######################
# What POP3 mail server Port Number are you using? 
# Auto will set this to, "110" automatically or, 
# "995" if is USESSL is set to, "1"
$Plugin_Config->{Port} = 'AUTO';

# Are you using SSL?
$Plugin_Config->{USESSL} = 0;

# What's the method? 'BEST', 'PASS', 'APOP' or 'CRAM-MD5'
$Plugin_Config->{AUTH_MODE} = 'BEST';

# The bounce handler log should be written at:
$Plugin_Config->{Log} = $DADA::Config::LOGS . '/bounces.txt';

# Message sent from the bounce handler should go to.. 
# (Leave, undef, if you'd like these messages to go to the list owner)
$Plugin_Config->{Send_Messages_To}          = undef; 

# How many messages should I check in one go?
$Plugin_Config->{MessagesAtOnce}            = 100; 

# Is there a limit on how large a single email message can be, until we outright # reject it? 
# In, "octects" (bytes) - this is about 2.5 megs...
#
$Plugin_Config->{Max_Size_Of_Any_Message} = 2621440;

# "Soft" bounces are given a score of: 
$Plugin_Config->{Default_Soft_Bounce_Score} = 1;

# "Hard" bounces are given a score of:
$Plugin_Config->{Default_Hard_Bounce_Score} = 4; 

# What score does an email address need to go until they're unsubscribed?
$Plugin_Config->{Score_Threshold}           = 10; 

# Can the checking of awaiting messages to send out happen by invoking this 
# script from a URL? (CGI mode?) 
# The URL would look like this: 
#
# http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl?run=1

$Plugin_Config->{Allow_Manual_Run}    = 1; 

# Set a passcode that you'll have to also pass to invoke this script as 
# explained above in, "$Plugin_Config->{Allow_Manual_Run}" Setting this to, 
# "undef" means no passcode is required. 

$Plugin_Config->{Manual_Run_Passcode} = undef;


# Another Undocumented Feature - Enable Pop3 File Locking?
# Sometimes, the file lock for the POP3 server doesn't work correctly
# and you get a stale lock. Setting this config variable to, "0"
# will disable this plugin's own lock file scheme. Should be fairly safe to use. 

$Plugin_Config->{Enable_POP3_File_Locking} = 1;



use CGI; my $q = new CGI;$q->charset($DADA::Config::HTML_CHARSET);

# Usually, this doesn't need to be changed. 
# But, if you are having trouble saving settings 
# and are redirected to an 
# outside page, you may need to set this manually. 
$Plugin_Config->{Plugin_URL} = $q->url; 

# Plugin Name!
$Plugin_Config->{Program_Name} = 'Mystery Girl'; 

# End of Optional Settings. 
#---------------------------------------------------------------------#


my $Score_Card = {}; 

my $Rules = [

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



{	
	qmail_delivery_delay_notification => {
		Examine => {
			Message_Fields => {
				Guessed_MTA             => [qw(Qmail)],
			    'Diagnostic-Code_regex' => [qr/The mail system will continue delivery attempts/],		
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
	over_quota => {
		Examine => {
			Message_Fields => {
				Action                 => [qw(failed Failed)],
				Status                 => [qw(5.2.2 4.2.2 5.0.0 5.1.1)],
				'Final-Recipient_regex' => [(qr/822/)], 
				'Diagnostic-Code_regex' => [(qr/552|exceeded storage allocation|over quota|storage full|mailbox full|disk quota exceeded|Mail quota exceeded|Quota violation/)]	
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},


{	
	hotmail_over_quota => {
		Examine => {
			Message_Fields => {
				Action                 => [qw(failed)],
				Status                 => [qw(5.2.3)],
				'Final-Recipient_regex' => [(qr/822/)], 
				'Diagnostic-Code_regex' => [(qr/larger than the current system limit/)]	
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},



{
over_quota_obscure_mta => {
		Examine => {
			Message_Fields => {
				Action                 => [qw(failed)],
				Status                 => [qw(5.0.0)],
				'Final-Recipient_regex' => [(qr/LOCAL\;\<\>/)], 
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},




{
over_quota_obscure_mta_two => {
		Examine => {
		
			Message_Fields => {
				Action                 => [qw(failed)],
				Status                 => [qw(4.2.2)],
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},




{
	yahoo_over_quota => {
		Examine => {
			Message_Fields => {
				Action                 => [qw(failed)],
				Status                 => [qw(5.0.0)],
			   'Remote-MTA_regex'      => [(qr/yahoo.com/)], 
			   'Final-Recipient_regex' => [(qr/822/)], 
			   'Diagnostic-Code_regex' => [(qr/over quota/)],	
			},
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},


{
	yahoo_over_quota_two => {
		Examine => {
			Message_Fields => {
			   'Remote-MTA'            => [qw(yahoo.com)], 
			   'Diagnostic-Code_regex' => [(qr/over quota/)],	
			},
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},


{	
	qmail_over_quota => {
		Examine => {
			Message_Fields => {
				
				Guessed_MTA             => [qw(Qmail)],
				Status                  => [qw(5.2.2 5.x.y)],
				'Diagnostic-Code_regex' => [(qr/mailbox is full|Exceeded storage allocation|recipient storage full|mailbox full|storage full/)],
					
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},

{	
	over_quota_552 => {
		Examine => {
			Message_Fields => {
				'Diagnostic-Code_regex' => [(qr/552 recipient storage full/)],	
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},




{	
	qmail_tmp_disabled => {
		Examine => {
			Message_Fields => {
				
				Guessed_MTA             => [qw(Qmail)],
				Status                  => [qw(4.x.y)],
				'Diagnostic-Code_regex' => [(qr/temporarily disabled/)],
					
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
		    add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},




{	
	delivery_time_expired => {
		Examine => {
			Message_Fields => {
				Status_regex            => [qr(/4.4.7|delivery time expired/)],
				Action_regex            => [qr(/Failed|failed/)],
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
			
				Action                  => [qw(Failed failed)], #originally Failed
				Status                  =>[qr/mailbox full/], # like, wtf?					
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
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
			#mail_list_owner => 'over_quota_message',
			 add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score}, 
		}
	}
},





{	
	qmail_error_5dot5dot1 => {
		Examine => {
			Message_Fields => {
				
				Guessed_MTA             => [qw(Qmail)],
				#Status                  => [qw(5.1.1)],
				'Diagnostic-Code_regex' => [(qr/551/)],
					
			},
				
			Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score}, 
		}
	}
},


{
qmail2_error_5dot5dot1 => {
	Examine => {
		Message_Fields => {
		
			Guessed_MTA => [qw(Qmail)],
			Status => [qw(5.1.1)],
		    'Diagnostic-Code_regex' => [(qr/no mailbox here by that name/)],
			},
		
		Data => {
				Email => 'is_valid',
				List => 'is_valid',
			}
		},
		Action => {
			unsubscribe_bounced_email	=> 'from_list',
		}
	}
},







{ 
	# AOL, apple.com, mac.com, altavista.net, pobox.com...  
	delivery_error_550 => { 
		Examine => {
			Message_Fields => {
				Action                =>  [qw(failed)],
				Status                =>  [qw(5.1.1)],
			   'Final-Recipient_regex' => [(qr/822/)], 
			   'Diagnostic-Code_regex' =>  [(qr/SMTP\; 550|550 MAILBOX NOT FOUND|550 5\.1\.1 unknown or illegal alias|User unknown|No such mail drop/)], 
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},





{ 
	# same as above, but without the Diagnostic_Code_regex. 
	
	delivery_error_5dot5dot1_status => { 
		Examine => {
			Message_Fields => {
				Action                =>  [qw(failed)],
				Status                =>  [qw(5.1.1)],
			   'Final-Recipient_regex' => [(qr/822/)], 
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},





{ 
	# Yahoo!
	delivery_error_554 => { 
		Examine => {
			Message_Fields => {
				Action                =>  [qw(failed)],
				Status                =>  [qw(5.0.0)],
			   'Diagnostic-Code_regex' => [(qr/554 delivery error/)], 
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
				}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},





{
qmail_user_unknown => { 
	Examine => { 
			Message_Fields => { 
				Status      => [qw(5.x.y)], 
				Guessed_MTA => [qw(Qmail)],  
			}, 
			Data => { 
				Email       => 'is_valid',
				List        => 'is_valid', 
			}
		},
			Action => { 
				#unsubscribe_bounced_email => 'from_list', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},                
		} 
	}
}, 





{
	qmail_error_554 => { 
		Examine => {
			Message_Fields => {
			   'Diagnostic-Code_regex' => [(qr/554/)], 
			   	Guessed_MTA => [qw(Qmail)], 
			   				
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
				}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},





{ 
	qmail_error_550 => { 
		Examine => {
			Message_Fields => {
			   'Diagnostic-Code_regex' => [(qr/550/)], 
			   	Guessed_MTA => [qw(Qmail)], 
			   				
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
				}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                 add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},





{ 
	qmail_unknown_domain => { 
		Examine => {
			Message_Fields => {
			    Status                 => [qw(5.1.2)], 
			   	Guessed_MTA            => [qw(Qmail)], 
			   				
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
				}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},


{ 
	# more info:
	# http://www.qmail.org/man/man1/bouncesaying.html

	qmail_bounce_saying => { 
		Examine => {
			Message_Fields => {
			    'Diagnostic-Code_regex' =>  [qr/This address no longer accepts mail./],  
			   	Guessed_MTA             =>  [qw(Qmail)], 
			   				
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
				}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},


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
				#unsubscribe_bounced_email => 'from_list', 
                 add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
   			}, 
		}
}, 




{
exchange_user_unknown => { 
	Examine => { 
			Message_Fields => { 
				#Status      => [qw(5.x.y)], 
				Guessed_MTA => [qw(Exchange)],  
				'Diagnostic-Code_regex' => [(qr/Unknown Recipient/)],
			}, 
			Data => { 
				Email       => 'is_valid',
				List        => 'is_valid', 
			},
		},
			Action => { 
				#unsubscribe_bounced_email => 'from_list', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
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
#               add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
#		} 
#	}
#}, 





{
# note! this should really make no sense, but I believe this is a bounce....
aol_user_unknown => {
	Examine => {
		Message_Fields => {
			Status => [qw(2.0.0)],
			Action => [qw(failed)],
			'Reporting-MTA_regex'   => [(qr/aol\.com/)], 
			'Final-Recipient_regex' => [(qr/822/)], 
			'Diagnostic-Code_regex' => [(qr/250 OK/)], # no for real, everything's "OK" #
	},
	Data => { 
		Email => 'is_valid', 
		List  => 'is_valid',
	}
	},
	Action => { 
		#unsubscribe_bounced_email => 'from_list', 
		#mail_list_owner => 'user_unknown_message', 
         add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
	},
	}
},	





{

user_unknown_5dot3dot0_status => {
	Examine => {
		Message_Fields => {
			Action                =>  [qw(failed)],
			Status                =>  [qw(5.3.0)],
		   'Final-Recipient_regex' => [(qr/822/)], 
		   'Diagnostic-Code_regex' => [(qr/No such user|Addressee unknown/)], 
		
		},
		Data => { 
				Email => 'is_valid', 
				List  => 'is_valid',
			}
		},
		Action => { 
				#unsubscribe_bounced_email => 'from_list', 
				#mail_list_owner => 'user_unknown_message', 
                add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		}
	}
},





{
	user_inactive => {
		Examine => { 
			Message_Fields => {
			   
				Status_regex            => [(qr/5\.0\.0/)],
				Action                  => [qw(failed)],
				'Final-Recipient_regex' => [(qr/822/)], 
				'Diagnostic-Code_regex' => [(qr/user inactive|Bad destination|bad destination/)],
				
				
		},
		Data => { 
			Email => 'is_valid', 
			List  => 'is_valid',
			}
		},
		Action => { 
			#unsubscribe_bounced_email => 'from_list', 
            add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		},
	}
},	





{
	postfix_5dot0dot0_error => {
		Examine => {
			Message_Fields => {
			   
				Status                  => [qw(5.0.0)],
				Guessed_MTA             => [qw(Postfix)],
				Action                  => [qw(failed)],
				#said_regex              => [(qr/550\-Mailbox unknown/)],
		},
		Data => { 
			Email => 'is_valid', 
			List  => 'is_valid',
			}
		},
		Action => { 
            #unsubscribe_bounced_email => 'from_list', 
            add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		},
	}
},	




{
	permanent_move_failure => {
		Examine => {
			Message_Fields => {
			   
				Status                  => [qw(5.1.6)],
				Action                  => [qw(failed)],
				'Final-Recipient_regex' => [(qr/822/)], 
				'Diagnostic-Code_regex' => [(qr/551 not our customer|User unknown|ecipient no longer/)],
				
		},
		Data => { 
			Email => 'is_valid', 
			List  => 'is_valid',
		}
		},
		Action => { 
			#unsubscribe_bounced_email => 'from_list', 
            add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
		},
	}
},	





{
unknown_domain => {
	Examine => {
		Message_Fields => {
		   
			Status                  => [qw(5.1.2)],
			Action                  => [qw(failed)],
			'Final-Recipient_regex' => [(qr/822/)], 
		},
		Data => { 
			Email => 'is_valid', 
			List  => 'is_valid',
		}
		},
		Action => { 
			#unsubscribe_bounced_email => 'from_list', 
             add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score}, 
		},
	}
},	




{
relaying_denied => {
	Examine => {
		Message_Fields => {
		   
			Status                  => [qw( 5.7.1)],
			Action                  => [qw(failed)],
			'Final-Recipient_regex' => [(qr/822/)], 
			'Diagnostic-Code_regex' => [(qr/Relaying denied|relaying denied/)],

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
#                        add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
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
						#mail_list_owner => 'unknown_bounce_type_message', 
						#append_message_to_file => $Plugin_Config->{Log},
						add_to_score => $Plugin_Config->{Default_Soft_Bounce_Score},
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
		Action => { 
			# mail_list_owner => 'email_not_found_message', 
		}
	}
},

#{
#who_knows => { 
#				Examine => {
#					Message_Fields => {},	
#				}, 
#				Action  => {append_message_to_file => $Plugin_Config->{Log}},
#			},
#},

]; 



my $Over_Quota_Subject = "Bounce Handler - warning user over quota";
my $Over_Quota_Message = qq{
Hello, This is <!-- tmpl_var Program_Name -->, the bounce handler for <!-- tmpl_var PROGRAM_NAME --> 

I received a message and it needs your attention. It seems
that the user, <!-- tmpl_var subscriber.email --> is over their email quota. 

This is probably a *temporary* problem, but if the problem persists,
you may want to unbsubscribe this address. 

I've attached what I was sent, if you're curious (or bored, what have you).  

You can remove this address from your list by clicking this link: 

<!-- tmpl_var list_unsubscribe_link -->

Below is the nerdy diagnostic report: 
-----------------------------------------------------------------------
<!-- tmpl_var report -->

<!-- tmpl_var status_report -->
-----------------------------------------------------------------------

- <!-- tmpl_var Program_Name -->

}; 


my $User_Unknown_Subject = "Bounce Handler - warning user doesn't exist";
my $User_Unknown_Message = qq{
Hello, This is <!-- tmpl_var Program_Name -->, the bounce handler for <!-- tmpl_var ROGRAM_NAME -->

I received a message and it needs your attention. It seems
that the user, <!-- tmpl_var subscriber.email --> doesn't exist, was deleted 
from the system, kicked the big can, etc. 

This is probably a *permanent* problem and I suggest you unsubscribe the
email address, but I'll let you have the last judgement. 

I've attached what I was sent, if you're curious (or bored, what have you).  

You can remove this address from your list by clicking this link: 

<!-- tmpl_var list_unsubscribe_link -->

Below is the nerdy diagnostic report: 
-----------------------------------------------------------------------
<!-- tmpl_var report -->

<!-- tmpl_var status_report -->
-----------------------------------------------------------------------

- <!-- tmpl_var Program_Name -->

}; 

my $Email_Not_Found_Subject = "Bounce Handler - warning";
my $Email_Not_Found_Message = qq{
Hello, This is <!-- tmpl_var Program_Name -->, the bounce handler for <!-- tmpl_var PROGRAM_NAME -->

I received a message and it needs your attention. The message was
bounced, but I cannot find the email associated with the bounce. 

Either I can't understand the bounced report, or there's a bug
in my sourcecode. Internet time is lighting fast and I fear I
may already be reduced to wasted 1's and 0's, *sigh*. 

I've attached what I was sent, if you're curious (or bored, what have you).  

Below is the nerdy diagnostic report: 
-----------------------------------------------------------------------
<!-- tmpl_var report -->

<!-- tmpl_var status_report -->
-----------------------------------------------------------------------

- <!-- tmpl_var Program_Name -->

}; 


my $Email_Unknown_Bounce_Type_Subject = "Bounce Handler - warning";
my $Email_Unknown_Bounce_Type_Message = qq{
Hello, This is <!-- tmpl_var Program_Name -->, the bounce handler for <!-- tmpl_var PROGRAM_NAME -->

I received a message and it needs your attention. The message was
bounced, but I dont know for what reason.

Either I can't understand the bounced report, or there's a bug
in my sourcecode. Internet time is lighting fast and I fear I
may already be reduced to wasted 1's and 0's, *sigh*. 

I've attached what I was sent, if you're curious (or bored, what have you).  

You can remove this address from your list by clicking this link: 

<!-- tmpl_var list_unsubscribe_link -->

Below is the nerdy diagnostic report: 
-----------------------------------------------------------------------
<!-- tmpl_var report -->

<!-- tmpl_var status_report -->

-----------------------------------------------------------------------

- <!-- tmpl_var Program_Name -->

}; 




my $Email_Unsubscribed_Because_Of_Bouncing_Subject = "Unsubscribed from: <!-- tmpl_var list_settings.list_name --> because of excessive bouncing";
my $Email_Unsubscribed_Because_Of_Bouncing_Message = qq{
Hello, This is <!-- tmpl_var Plugin_Name -->, the bounce handler for <!-- tmpl_var PROGRAM_NAME -->

This is a notice that your email address:

    <!-- tmpl_var subscriber.email -->
    
has been unsubscribed from:

    <!-- tmpl_var list_settings.list_name -->
    
Because your email address has been bouncing messages sent to it, 
originating from this list.

If this is in error, please re-subscribe to this list, by following 
this link: 

    <!-- tmpl_var PROGRAM_URL -->/s/<!-- tmpl_var list_settings.list -->

If you have any questions, please email the list owner of this list at: 

    <!-- tmpl_var list_settings.list_owner_email -->
    
for more information. 

- <!-- tmpl_var PROGRAM_NAME -->

}; 

#---------------------------------------------------------------------#
# Nothing else to be configured.                                      #


my $App_Version = '1.6';


use DADA::App::Guts; 
use DADA::Mail::Send; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings;


use DADA::Template::HTML; 


my %Global_Template_Options = (
		#debug             => 1, 		
		path              => [$DADA::Config::TEMPLATES],
		die_on_bad_params => 0,									

        (
            ($DADA::Config::CPAN_DEBUG_SETTINGS{HTML_TEMPLATE} == 1) ? 
                (debug => 1, ) :
                ()
        ), 


);


use Getopt::Long; 
use Mail::Verp; 
use MIME::Parser;
use MIME::Entity; 


use Fcntl qw(
    O_CREAT 
    O_RDWR
    LOCK_EX
    LOCK_NB
); 


my $parser = new MIME::Parser; 
   $parser = optimize_mime_parser($parser); 

my $Remove_List       = {}; 
my $Bounce_History    = {}; 

my $Rules_To_Carry_Out = [];
my $debug = 0; 

my $help = 0;
my $test; 
my $server; 
my $username; 
my $password; 
my $verbose = 0; 
my $log; 
my $Have_Log = 0; 
my $messages = 0; 

my $erase_score_card = 0; 

my $version; 


my $list;
my $admin_list; 
my $root_login; 
	

GetOptions("help"             => \$help, 
		   "test=s"           => \$test, 
		   "server=s"         => \$server, 
		   "username=s"       => \$username, 
		   "password=s"       => \$password, 
		   "verbose"          => \$verbose, 
		   "log=s"            => \$log,
		   "messages=i"       => \$messages, 
		   "erase_score_card" => \$erase_score_card, 
		   "version"          => \$version,  
		); 		

&init_vars; 

run()
	unless caller();
	
sub init_vars { 

    # DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

     while ( my $key = each %$Plugin_Config ) {
        
        if(exists($DADA::Config::PLUGIN_CONFIGS->{Mystery_Girl}->{$key})){ 
        
            if(defined($DADA::Config::PLUGIN_CONFIGS->{Mystery_Girl}->{$key})){ 
                    
                $Plugin_Config->{$key} = $DADA::Config::PLUGIN_CONFIGS->{Mystery_Girl}->{$key};
        
            }
        }
     }
}



sub run { 
	if(!$ENV{GATEWAY_INTERFACE}){ 
		&cl_main(); 
	}else{ 
		&cgi_main(); 
	}
}



sub test_sub { 
	return "Hello, World!"; 
}



sub cgi_main {

    if(keys %{$q->Vars}                        && 
       $q->param('run')                        && 
       xss_filter($q->param('run'))       == 1 &&
       $Plugin_Config->{Allow_Manual_Run} == 1
      ) { 
        cgi_manual_start();
    } 
    else { 

        
        ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                         -Function => 'dada_bounce_handler');
                                                                                                                
        $list = $admin_list; 
        
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get(); 
                                                                  
        my $flavor = $q->param('flavor') || 'cgi_default';
        my %Mode = ( 
        
        'cgi_default'             => \&cgi_default, 
        'cgi_parse_bounce'        => \&cgi_parse_bounce, 
        'cgi_scorecard'           => \&cgi_scorecard, 
        'cgi_bounce_score_search' => \&cgi_bounce_score_search, 
        'cgi_show_plugin_config'  => \&cgi_show_plugin_config,
        ); 
        
        if(exists($Mode{$flavor})) { 
            $Mode{$flavor}->();  #call the correct subroutine 
        }else{
            &cgi_default;
        }
    }
}




sub cgi_default { 

	my $ls   = DADA::MailingList::Settings->new({-list => $list}); 
	my $li   = $ls->get(); 
	
	my $tmpl = default_cgi_template(); 	                

	my @amount = (1,2,3,4,5,6,7,8,9,10,25,50,100,150,200,
	              250,300,350, 400,450,
	              500,550,600,650,700,
	              750,800,850,900,950,1000
	             );
	
	my $curl_location = `which curl`; 
	   $curl_location = strip(make_safer($curl_location)); 
	
	my $parse_amount_widget = $q->popup_menu(-name      => 'parse_amount',
											 -id        => 'parse_amount', 
											 '-values'  => [@amount], 
											 -default   => $Plugin_Config->{MessagesAtOnce}, 
											 -label     => '', 
											 ); 

    my $plugin_configured = 1; 
	if(
		! defined($Plugin_Config->{Server})   ||
	    ! defined($Plugin_Config->{Username}) ||
		! defined($Plugin_Config->{Password})
	
	){ 
		$plugin_configured = 0; 
	}
											 
	print(admin_template_header(
							-Title      => "Bounce Handling",
		                    -List       => $list,
		                    -Form       => 0,
		                    -Root_Login => $root_login,
		                    ));

	require DADA::Template::Widgets; 
	print DADA::Template::Widgets::screen(
						{ 
							-data => \$tmpl, 
							-vars => { 
									plugin_configured  => $plugin_configured, 
				 					Username            => $Plugin_Config->{Username} ? $Plugin_Config->{Username} : "<span class=\"error\">Not Set!</span>",
									Server              => $Plugin_Config->{Server}   ? $Plugin_Config->{Server}   : "<span class=\"error\">Not Set!</span>",
									Plugin_URL          => $Plugin_Config->{Plugin_URL}, 
									parse_amount_widget => $parse_amount_widget, 
									send_via_smtp       => $li->{send_via_smtp}, 
									add_sendmail_f_flag => $li->{add_sendmail_f_flag},
									print_return_path_header => $li->{print_return_path_header}, 
									set_smtp_sender          => $li->{set_smtp_sender}, 
									admin_email              => $li->{admin_email},,
									list_owner_email         => $li->{list_owner_email}, 
									MAIL_SETTINGS            => $DADA::Config::MAIL_SETTINGS, 
						
						
									Default_Soft_Bounce_Score => $Plugin_Config->{Default_Soft_Bounce_Score},
									Default_Hard_Bounce_Score => $Plugin_Config->{Default_Hard_Bounce_Score},
									Score_Threshold           =>  $Plugin_Config->{Score_Threshold},
						
									Program_Name       => $Plugin_Config->{Program_Name},
					
								    Allow_Manual_Run          =>  $Plugin_Config->{Allow_Manual_Run},
								    Manual_Run_Passcode       =>  $Plugin_Config->{Manual_Run_Passcode},
					
									curl_location             => $curl_location, 
								}
						}
					);
	                
	                    
	print admin_template_footer(-Form    => 0, 
							-List    => $list,
						    ); 
}




sub cgi_parse_bounce { 

	print(admin_template_header(
							-Title      => "Parsing Bounces...",
		                    -List       => $list,
		                    -Form       => 0,
		                    -Root_Login => $root_login
		                    ));
		                    
	$test = $q->param('test')
		if $q->param('test'); 
	
	if(defined(xss_filter($q->param('parse_amount')))){
		$Plugin_Config->{MessagesAtOnce} = xss_filter($q->param('parse_amount'));
	}
		
	$verbose  = 1;
	
	    print '
     <p id="breadcrumbs">
        <a href="'  .  $Plugin_Config->{Plugin_URL} . '">
            ' . $Plugin_Config->{Program_Name} .'
        </a> &#187; Parsing Bounces</p>'; 
        
	
	
	print '<pre>';
	cl_main();
	print '</pre>';

	print '<p><a href="' . $Plugin_Config->{Plugin_URL} . '">Back...</a></p>';
	
	print admin_template_footer(-Form    => 0, 
							-List    => $list,
						    ); 
}




sub cgi_manual_start { 
        
        if(
            (xss_filter($q->param('passcode')) eq $Plugin_Config->{Manual_Run_Passcode}) ||             
            ($Plugin_Config->{Manual_Run_Passcode}              eq ''                  )
            
          ) {
            
            if(defined(xss_filter($q->param('verbose')))){
                $verbose = xss_filter($q->param('verbose'));
            }
            else { 
                $verbose = 1;
            }
            
            
            if(defined(xss_filter($q->param('test')))){
                $test = $q->param('test');
            }
            
            if(defined(xss_filter($q->param('messages')))){ 
                $Plugin_Config->{MessagesAtOnce} = xss_filter($q->param('messages')); 
            }
			
			
            print $q->header();
        	print '<pre>'
        	    if $verbose; 
            cl_main();
            print '</pre>'
                if $verbose; 
            

        } else { 
            print $q->header(); 
            print "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Authorization Denied.";
        }
}




sub cgi_scorecard { 


    require   DADA::App::BounceScoreKeeper; 
    my $bsk = DADA::App::BounceScoreKeeper->new(-List => $list); 
                     
    require HTML::Pager; 
    require HTML::Template;
    
    my $table_tmpl = bounce_score_table();
    my $template   = HTML::Template->new(
        %Global_Template_Options,
		scalarref          => \$table_tmpl, 
	    global_vars        => 1, 
	    loop_context_vars  => 1, 
	    
	);
	   $template->param(
	        Plugin_URL => $Plugin_Config->{Plugin_URL}
	   ); 										
    
    my $get_data_sub = sub { 
        my ($offset, $rows) = @_;
        return $bsk->raw_scorecard($offset, $rows); 
    }; 
    
    my $num_rows = $bsk->num_scorecard_rows;   
    
    my $pager = undef; 
    if($num_rows >= 1) { 
        $pager = HTML::Pager->new(
           
            # required parameters
            query             => $q,
            get_data_callback => $get_data_sub,
            rows              => $num_rows,
            page_size         => ($num_rows < 100) ? $num_rows : 100,
            
            persist_vars     => ['flavor'], 
            
            template         => $template, 
            
            # some optional parameters
            #
            # cell_space_color => '#000000',    
            # cell_background_color => '#ffffff',
            # nav_background_color => '#dddddd',
            # javascript_presubmit => 'last_minute_javascript()',
            
            
            debug => 1,
        );
    
    }
    
    print(admin_template_header(
                            -Title      => "Bounce Scorecard",
                            -List       => $list,
                            -Form       => 0,
                            -Root_Login => $root_login
                            ));
    
    print '
     <p id="breadcrumbs">
        <a href="'  .  $Plugin_Config->{Plugin_URL} . '">
            ' . $Plugin_Config->{Program_Name} .'
        </a> &#187; Scorecard</p>'; 
        
    
    
    if($num_rows >= 1) { 
    
        print $pager->output;
    	
	}
	else { 
	    print '<p class="error">Currently, there are no bounced addresses saved in the scorecard.</p>'; 
	    
	}
	print admin_template_footer(-Form    => 0, 
							-List    => $list,
						    ); 
}



sub cgi_show_plugin_config { 


     	print(admin_template_header(
							-Title      => $Plugin_Config->{Program_Name} . " Plugin Configuration",
		                    -List       => $list,
		                    -Form       => 0,
		                    -Root_Login => $root_login
		                    ));
	
	my $tmpl = cgi_show_plugin_config_template(); 
	my $template = HTML::Template->new(%Global_Template_Options,
									   scalarref => \$tmpl, 
											);
    
    my $configs = []; 
    foreach(sort keys %$Plugin_Config){ 
        if($_ eq 'Password'){ 
            push(@$configs, {name => $_, value => '(Not Shown)'});
        }
        else { 
            push(@$configs, {name => $_, value => $Plugin_Config->{$_}}); 
        }
    }
    $template->param( 
    
        Plugin_URL            => $Plugin_Config->{Plugin_URL}, 
        Program_Name => $Plugin_Config->{Program_Name}, 
        configs             => $configs, 
     
    );
	                
	print $template->output();

    print admin_template_footer(-Form    => 0, 
                                -List    => $list,
                                ); 



}




sub cgi_show_plugin_config_template { 

    return q{ 
    
    
    
  <p id="breadcrumbs">
   <a href="<!-- tmpl_var Plugin_URL -->"> 
   <!-- tmpl_var Program_Name --> 
   </a> 
   
   &#187;
   
        Plugin Configuration
   </a> 
   
   
  </p> 
 
 
 
 
        <table> 
        
        <!-- tmpl_loop configs --> 
        
        <tr> 
          <td> 
           <p> 
             <strong> 
              <!-- tmpl_var name --> 
              </strong>
            </p>
           </td> 
           <td> 
            <p>
            <!-- tmpl_var value --> 
            </p>
            </td> 
            </tr> 
            
        <!-- /tmpl_loop --> 
 
        </table> 
        
    };


}




sub cgi_bounce_score_search { 


    #TODO DEV: THIS NEEDS ITS OWN METHOD!!!
    my %l_label; 
    my @l_lists = available_lists(); 
    
    foreach my $l_list( @l_lists ){
			my $l_ls = DADA::MailingList::Settings->new({-list => $l_list}); 
			my $l_li = $l_ls->get; 
			$l_label{$l_list} = $l_li->{list_name}; 
			
	}
	
	require HTML::Template;
	
    require   DADA::App::BounceScoreKeeper; 
    my $bsk = DADA::App::BounceScoreKeeper->new(-List => $list); 
   
    require DADA::App::LogSearch; 
    
    my $query = xss_filter($q->param('query')); 

    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get; 
    
    my $valid_email        = 0; 
    my $subscribed_address = 0; 
    if(DADA::App::Guts::check_for_valid_email($query) == 0) {
        $valid_email = 1; 
        if( $lh->check_for_double_email(-Email => $query) == 1){ 
            $subscribed_address = 1; 
        }
    }
       

    if(!defined($query)){ 
        $q->redirect(-uri =>  $Plugin_Config->{Plugin_URL} . '?flavor=cgi_scorecard');
        return;
    }
  
    
    my $searcher = DADA::App::LogSearch->new; 
    my $results  = $searcher->search({
        -query => $query,
        -files => [$Plugin_Config->{Log}], 
    });
    
    my $search_results = []; 
    my $results_found  = 0;
    

    if($results->{$Plugin_Config->{Log}}->[0]){ 
    
        $results_found = 1; 
        
        foreach my $l(@{$results->{$Plugin_Config->{Log}}}){ 
        
            my @entries = split("\t", $l, 5); # Limit of 5
            
            # Let us try to munge the data!
            
            # Date!
            $entries[0] =~ s/^\[|\]$//g;
            $entries[0] = $searcher->html_highlight_line({-query => $query, -line => $entries[0] }); 
            
            # ListShortName!
            $entries[1] = $searcher->html_highlight_line({-query => $query, -line => $entries[1] }); 
            
            # Action Taken! 
            $entries[2] = $searcher->html_highlight_line({-query => $query, -line => $entries[2] }); 
          
            # Email Address! 
            $entries[3] = $searcher->html_highlight_line({-query => $query, -line => $entries[3] }); 
            
            
            my @diags        = split(",", $entries[4]); 
            my $labeled_digs = [];
            
            foreach my $diag(@diags) { 
                my ($label, $value) = split(":", $diag); 
                
                push(@$labeled_digs, 
                    {
                        diagnostic_label => $searcher->html_highlight_line({-query => $query, -line => $label }), 
                        diagnostic_value => $searcher->html_highlight_line({-query => $query, -line => $value }), 
                       
                    }
                ); 
            
            }
            
            push(@$search_results, 
                { 
                date        => $entries[0], 
                list        => $entries[1],
                list_name   => $l_label{ $entries[1] },
                action      => $entries[2], 
                email       => $entries[3], 
                
                diagnostics =>  $labeled_digs, 
                
                
                }
            );

        }
    }
    else { 
        
        $results_found = 0; 
    
    }
   
       
       
  	print(admin_template_header(
							-Title      => "Bounce Log Search Results",
		                    -List       => $list,
		                    -Form       => 0,
		                    -Root_Login => $root_login
		                    ));
	
	my $tmpl = cgi_bounce_score_search_template(); 
	my $template = HTML::Template->new(%Global_Template_Options,
									   scalarref => \$tmpl, 
											);
    $template->param( 
        query               => $query, 
        list_name           => $li->{list_name}, 
        subscribed_address  => $subscribed_address, 
        valid_email         => $valid_email, 
        search_results      => $search_results, 
        results_found       => $results_found,     
        
        S_PROGRAM_URL       => $DADA::Config::S_PROGRAM_URL, 
        Plugin_URL            => $Plugin_Config->{Plugin_URL}, 
        Program_Name => $Plugin_Config->{Program_Name},
    );
	                
	print $template->output();



    print admin_template_footer(-Form    => 0, 
                                -List    => $list,
                                ); 
    
}




sub cgi_bounce_score_search_template { 


  

my $template = q{


  <p id="breadcrumbs">
   <a href="<!-- tmpl_var Plugin_URL -->"> 
   <!-- tmpl_var Program_Name --> 
   </a> 
   
   &#187;
   
      <a href="<!-- tmpl_var Plugin_URL -->?flavor=cgi_scorecard"> 
         Scorecard
   </a> 
   
   &#187;
   
   Search Results for:<!-- tmpl_var query ESCAPE="HTML" --> 
  </p> 
 
 
  

    <h1>
     Search Results For: <!-- tmpl_var query ESCAPE="HTML" --> 
    </h1> 
   
   <!-- tmpl_if valid_email --> 
   
       <!-- tmpl_if subscribed_address --> 
            <p class="positive">
            <!-- tmpl_var query ESCAPE="HTML" --> is currently subscribed to your list (<!-- tmpl_var list_name ESCAPE="HTML" -->) - 
            <strong> 
            <a href="<!-- tmpl_var S_PROGRAM_URL -->?f=edit_subscriber&email=<!-- tmpl_var query ESCAPE="URL" -->&type=list">
             More Information...
             </a> 
            </strong>
            </p>       
       <!-- tmpl_else --> 
       
                <p class="error">
            <!-- tmpl_var query ESCAPE="HTML" --> is currently not subscribed to your list (<!-- tmpl_var list_name ESCAPE="HTML" -->)
            </p
       
       <!-- /tmpl_if --> 
   
   <!-- /tmpl_if --> 
   
   <!-- tmpl_if results_found --> 
   
       <!-- tmpl_loop search_results --> 
       
           <h2>
            Date: <!-- tmpl_var date --> 
           </h2> 
           

<div style="padding-left:5px"> 

           <table>
         	<tr>
             <td> 
              <strong>Email:</strong>
             </td>
             <td>
			 <!-- tmpl_var email --> 
			</td> 
			</tr>             
			<tr>
             	<td> 
              <strong>List Name:</strong>
            </td> <td><!-- tmpl_var list_name --> (<!-- tmpl_var list -->) </td>

        	</tr>             
			<tr>
		     
             
            	<td> 
              <strong>Action Taken:</strong> 
            </td> 
<td>
<!-- tmpl_var action --> 
</td> 

</tr> 

</table> 

        
           <div style="padding-left:5px"> 
        
            <h2>
             Diagnostics of the Bounced Message:
            </h2> 
            
         <table style="margin-left:10px;padding-left:10px">
          
            
             <!-- tmpl_loop diagnostics --> 
              
                <tr>
<td>
                    <strong> 
                     <!-- tmpl_var diagnostic_label -->:
                    </strong> 
    </td>
<td>
                
                    <!-- tmpl_var diagnostic_value -->
</td>
</tr> 
                
             <!-- /tmpl_loop --> 
            
</table> 

</div> 
</div> 

            <hr /> 
    
        <!-- /tmpl_loop --> 

    <!-- tmpl_else --> 
    
        <p>
         Sorry, no results were found when searching for: 
         <em> 
          <!-- tmpl_var query  ESCAPE="HTML" -->
         </em>
        </p>
    
    <!-- /tmpl_if --> 
    

};

return $template; 


}




sub cl_main { 
	
	&init; 
	
	if($help == 1){ 
		show_help(); 
	}
	elsif($erase_score_card){ 
	   erase_score_card(); 
	}
	elsif(defined($test) && $test ne 'bounces'){
		test_script(); 
	}elsif(defined($version)){ 
		&version(); 
	}
	
	 if(!$Plugin_Config->{Server} ||
	       !$Plugin_Config->{Username} || 
	       !$Plugin_Config->{Password}
	    ){ 
	        print "The Server Username and/password haven't been filled out, stopping." 
	            if $verbose;        
	            return;
	    }
	
	print "Making POP3 Connection...\n" 
	    if $verbose; 
	
	
	require DADA::App::POP3Tools;
	
	my $lock_file_fh; 
	if($Plugin_Config->{Enable_POP3_File_Locking} == 1){ 
		$lock_file_fh = DADA::App::POP3Tools::_lock_pop3_check(
			{
				name => 'dada_bounce_handler.lock'
			}
		);
	}
	
	my $pop = DADA::App::POP3Tools::mail_pop3client_login(
	    { 
        server    => $Plugin_Config->{Server}, 
        username  => $Plugin_Config->{Username}, 
        password  => $Plugin_Config->{Password},
		port      => $Plugin_Config->{Port}, 
        USESSL    => $Plugin_Config->{USESSL},
        AUTH_MODE => $Plugin_Config->{AUTH_MODE},
        verbose   => $verbose, 
        
        }
    ); 
    
    
    
    
    my @delete_list = (); 
    
    my @List = $pop->List; 
    
    if(!$List[0]){ 
    
        print "No bounces to handle.\n"
            if $verbose;
    }
    else { 
    
        MSGCHECK:
        foreach my $msg_info(@List){ 
         
        my ($msgnum, $msgsize) = split('\s+', $msg_info);
        #foreach my $msgnum (sort { $a <=> $b } keys %$msgnums) {
                    
            my $delete = undef; 
            
            #if($msgnums->{$msgnum} > $Plugin_Config->{Max_Size_Of_Any_Message}){ 
            if($msgsize > $Plugin_Config->{Max_Size_Of_Any_Message}){
                print "\tWarning! Message size ( " . $msgsize . " ) is larger than the maximum size allowed ( " . $Plugin_Config->{Max_Size_Of_Any_Message} . ")"
                        if $verbose; 
                warn  "dada_bounce_handler.pl $App_Version: Warning! Message size ( " . $msgsize . " ) is larger than the maximum size allowed ( " . $Plugin_Config->{Max_Size_Of_Any_Message} . ")";
                
                $delete = 1; 
                
            }
            else { 
                    
               my $msg = $pop->Retrieve($msgnum); 
               my $full_msg = $msg;     
                
        
                eval { 
                
                    $delete = parse_bounce(-message => $full_msg); 
                };
                if($@){ 
                     
                    warn  "dada_bounce_handler.pl - irrecoverable error processing message. Skipping message (sorry!): $@"; 
                    print "dada_bounce_handler.pl - irrecoverable error processing message. Skipping message (sorry!): $@"
                    if $verbose; 
                    
                    $delete = 1; 
                
                }
                
            }
            
            if($delete == 1){ 
                push(@delete_list, $msgnum); 
            }
            
            
            #if ($messages_viewed >= $Plugin_Config->{MessagesAtOnce}){ 
            if(($#delete_list + 1) >= $Plugin_Config->{MessagesAtOnce}){ 
            
                print "\n\nThe limit has been reached of the amount of messages to be looked at for this execution\n\n"
                    if $verbose;
                last MSGCHECK; 
            
            }
    
    
        } 
        
        if(! $debug){ 
        	foreach(@delete_list){ 
	
	            print "deleting message #: $_\n" 
					if $verbose;
					
	            $pop->Delete($_);            
	        }
		}
		else {
			print "Skipping Message Deletion - Debugging is on.\n"; 
		}
                    
        
        #$pop->quit();
         $pop->Close; 
         
    	if($Plugin_Config->{Enable_POP3_File_Locking} == 1){ 
	        DADA::App::POP3Tools::_unlock_pop3_check(
				{
					name => 'dada_bounce_handler.lock',
					fh   => $lock_file_fh, 
				},
			);
		}
		
		
        print "\nSaving Scores...\n\n"
           if $verbose; 			
        save_scores($Score_Card); 
        
        remove_bounces($Remove_List) 
			if ! $debug; 
        
        &close_log; 

    }
}

sub init { 

	$Plugin_Config->{Server}         = $server   if $server;
	$Plugin_Config->{Username}       = $username if $username; 
	$Plugin_Config->{Password}       = $password if $password; 
	$Plugin_Config->{Log}            = $log      if $log; 
    $Plugin_Config->{MessagesAtOnce} = $messages if $messages > 0; 
    
 
	if($test){
		$debug = 1 
			if $test eq 'bounces'; 
	}
	
	$verbose = 1 
		if $debug == 1; 
	
	# init a hashref of hashrefs
	# for unsub optimization 
	my @a_Lists = DADA::App::Guts::available_lists(); 
 	foreach(@a_Lists){ 
 		$Remove_List->{$_} = {}; 
 	}
 	
	open_log($Plugin_Config->{Log}); 
}










sub parse_bounce { 

    my $only_this_list = $list; 
    my $msg_report = ''; 

	my %args = (-message => undef, @_); 
				
	my $message = $args{-message}; 
	 
	my $email       = '';
	my $list        = '';
	my $diagnostics = {};
	
	my $entity; 
	
	eval { $entity = $parser->parse_data($message) };
	
	if(!$entity){
	
		warn   "No MIME entity found, this message could be garbage, skipping";
		$msg_report .=  "No MIME entity found, this message could be garbage, skipping"
			if $verbose;
			
	}else{ 
			
	    
		$email = find_verp($entity);
		
	
		my ($gp_list, $gp_email, $gp_diagnostics) = generic_parse($entity); 	
		
		$list        = $gp_list if $gp_list; 
		$email     ||=  $gp_email; 
		$diagnostics = $gp_diagnostics
			if $gp_diagnostics;
		
		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    
			my ($qmail_list, $qmail_email, $qmail_diagnostics) = parse_for_qmail($entity); 
			$list  ||= $qmail_list;
			$email ||= $qmail_email;
			%{$diagnostics} = (%{$diagnostics}, %{$qmail_diagnostics})
				if $qmail_diagnostics; 
		} 
		
		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    

			my ($exim_list, $exim_email, $exim_diagnostics) = parse_for_exim($entity); 
			$list  ||= $exim_list;
			$email ||= $exim_email;
			%{$diagnostics} = (%{$diagnostics}, %{$exim_diagnostics})
				if $exim_diagnostics; 
		}
		

		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    

			my ($ms_list, $ms_email, $ms_diagnostics) = parse_for_f__king_exchange($entity); 
			$list  ||= $ms_list;
			$email ||= $ms_email;
			%{$diagnostics} = (%{$diagnostics}, %{$ms_diagnostics})
				if $ms_diagnostics; 
		}
		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    

			my ($nv_list, $nv_email, $nv_diagnostics) = parse_for_novell($entity); 
			$list  ||= $nv_list;
			$email ||= $nv_email;
			%{$diagnostics} = (%{$diagnostics}, %{$nv_diagnostics})
				if $nv_diagnostics; 
		}
		
		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    

			my ($g_list, $g_email, $g_diagnostics) = parse_for_gordano($entity); 
			$list  ||= $g_list;
			$email ||= $g_email;
			%{$diagnostics} = (%{$diagnostics}, %{$g_diagnostics})
				if $g_diagnostics; 
		}
		
		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    

			my ($y_list, $y_email, $y_diagnostics) = parse_for_overquota_yahoo($entity); 
			$list  ||= $y_list;
			$email ||= $y_email;
			%{$diagnostics} = (%{$diagnostics}, %{$y_diagnostics})
				if $y_diagnostics;
		}	

		if((!$list) || (!$email) || !keys %{$diagnostics}){ 		    

			my ($el_list, $el_email, $el_diagnostics) = parse_for_earthlink($entity); 
			$list  ||= $el_list;
			$email ||= $el_email;
			%{$diagnostics} = (%{$diagnostics}, %{$el_diagnostics})
				if $el_diagnostics; 
		}	
		
		if((!$list) || (!$email) || !keys %{$diagnostics}){ 	
				my ($wl_list, $wl_email, $wl_diagnostics) = parse_for_windows_live($entity); 
				
				$list  ||= $wl_list;
				$email ||= $wl_email;
				%{$diagnostics} = (%{$diagnostics}, %{$wl_diagnostics})
					if $wl_diagnostics; 
		}




        # This is a special case - since this outside module adds pseudo diagonistic
        # reports, we'll say, add them if they're NOT already there:
        
        my ($bp_list, $bp_email, $bp_diagnostics) = parse_using_m_ds_bp($entity); 
        
        # There's no test for these in the module itself, so we 
        # won't even look for them. 
        #$list  ||= $bp_list;
        #$email ||= $bp_email;
        
        %{$diagnostics} = (%{$bp_diagnostics}, %{$diagnostics})
            if $bp_diagnostics; 
        
		
        chomp($email) if $email; 

		
		
		#small hack, turns, %2 into, '-'
		$list =~ s/\%2d/\-/g;
		
		$list = trim($list); 
		
		if(!$diagnostics->{'Message-Id'}){ 
			$diagnostics->{'Message-Id'} = find_message_id_in_headers($entity);
			if(!$diagnostics->{'Message-Id'}){ 
				$diagnostics->{'Message-Id'} = find_message_id_in_body($entity);
			}
		}
		
		if($diagnostics->{'Message-Id'}){ 
			$diagnostics->{'Simplified-Message-Id'} = $diagnostics->{'Message-Id'}; 
			$diagnostics->{'Simplified-Message-Id'} =~ s/\<|\>//g;
	        $diagnostics->{'Simplified-Message-Id'} =~ s/\.(.*)//; #greedy
		}

        # Means, either there is no $list set, or the $list that *is* set is the one we want set. 
        
        
      #  if(! defined($only_this_list) ){ 
      #      die "NO DEFINED! LIST!"; 
      #      
      #  }
       if(! defined($only_this_list) || ($list eq $only_this_list)){ 
        
            my $rule_report; 
            
            $msg_report .= generate_nerd_report($list, $email, $diagnostics) if $verbose;  
                my $rule = find_rule_to_use($list, $email, $diagnostics); 
                $msg_report .= "\nUsing Rule: $rule\n\n" 
                    if $verbose; 	
            if(!bounce_from_me($entity)){			
                
                ###
                
                my $valid_list_1;
                if(DADA::App::Guts::check_if_list_exists(-List=>$list) != 0){
	    	 		$valid_list_1 = 1; 
	    	 	}
	    	 	else { 
	    	 	    $valid_list_1  = 0; 
	    	 	}
	    	 	
	    	 	if($valid_list_1 == 1){ 
	    	 	
                    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
                    if($lh->check_for_double_email(-Email => $email) == 1){ 
                    
                        if(!$debug){ 
                            #push(@$Rules_To_Carry_Out, [$rule, $list, $email, $diagnostics, $message]);
                            $rule_report = carry_out_rule($rule, $list, $email, $diagnostics, $message); 
                        } 
                    
                    }
                    else { 
                        print "Bounced Message is from an email address that isn't subscribed to: $list. Ignorning.\n"
                            if $verbose;
                    }
                }
                else { 
                    print 'List, ' . $list . ' doesn\'t exist. Ignoring and deleting.'
						if $verbose;
                }
                ###
                
            }else{ 
                
                print "Bounced message was sent by myself. Ignoring and deleting\n"
                    if $verbose; 
                warn "Bounced message was sent by myself. Ignoring and deleting";
            }
        
            if($verbose){ 
                
                print '-' x 72 . "\n"; 
                $entity->dump_skeleton; 
                print '-' x 72 . "\n";
                
                print $msg_report; 
                
                print $rule_report; 
            }
            
            return 1; 
        }
        elsif (! $list){ 
        
            if($verbose){ 
                print '-' x 72 . "\n"; 
                $entity->dump_skeleton; 
                print '-' x 72 . "\n";
                
                print "No valid list found, ignoring and deleting...\n";
            }
               
            return 1; 
        
        }
        else { 
            return 0; 
        }
        
	}
	#sleep(1);
}




sub bounce_from_me(){ 
	my $entity = shift; 
	my $bh = $entity->head->get('X-BounceHandler', 0);
	$bh =~ s/\n//g; 
	$bh = trim($bh); 
	$bh eq $Plugin_Config->{Program_Name} ? return 1 : return 0; 
}




sub carry_out_rule { 
	
	my ($title, $list, $email, $diagnostics, $message) = @_; 
	my $actions = {};
    
    my $report = ''; 
    
	my $i = 0;
	foreach my $rule(@$Rules){ 
		if((keys %$rule)[0] eq $title){ 
			$actions = $Rules->[$i]->{$title}->{Action}; # wooo that was fun.
		}
		$i++;
	}	
	
	foreach my $action(keys %$actions){ 
	
		if($action eq 'add_to_score'){ 
		  $report .= add_to_score($list, $email, $diagnostics, $actions->{$action}); 
		}elsif($action eq 'unsubscribe_bounced_email'){ 
			$report .= unsubscribe_bounced_email($list, $email, $diagnostics, $actions->{$action}); 
		}elsif($action eq 'mail_list_owner'){
			$report .= mail_list_owner($list, $email, $diagnostics, $actions->{$action}, $message);
		}elsif($action eq 'append_message_to_file'){
			$report .= append_message_to_file($list, $email, $diagnostics, $actions->{$action}, $message);		
		}elsif($action eq 'default'){
			$report .= default_action($list, $email, $diagnostics, $actions->{$action}, $message);
		}else{ 
			warn "unknown rule trying to be carried out, ignoring"; 
		}
		log_action($list, $email, $diagnostics, "$action $actions->{$action}");
	}
	
	return $report; 
}




sub default_action { 
	warn "Parsing... really didn't work. Ignoring and deleting bounce."; 
}




sub add_to_score { 

    	my ($list, $email, $diagnostics, $action) = @_; 
        if($Score_Card->{$list}->{$email}){ 
            $Score_Card->{$list}->{$email} += $action; 
            # Hmm. That was easy. 
        }else{ 
            $Score_Card->{$list}->{$email} = $action;
        }
        
        return "Email, '$email', on list: $list -  adding  $action to total score. Will remove after score reaches, $Plugin_Config->{Score_Threshold}\n";
           
}



sub unsubscribe_bounced_email {

	my ($list, $email, $diagnostics, $action) = @_; 
	my @delete_list; 
	
	if($action eq 'from_list'){ 
		$delete_list[0] = $list; 
	}elsif($action eq 'from_all_lists'){ 
		@delete_list = DADA::App::Guts::available_lists(); 
	}else{ 
		warn "unknown action: '$action', no unsubscription will be made from this email!"; 
	}
	
	$Bounce_History->{$list}->{$email} = [$diagnostics, $action];	
	
	my $report; 
	
	$report .= "\n";
	
	foreach(@delete_list){ 
		$Remove_List->{$_}->{$email} = 1;
		$report .="$email to be deleted off of: '$_'\n";
	} 
	
	return $report; 
		
}




sub mail_list_owner { 

	my ($list, $email, $diagnostics, $action, $message) = @_; 
	
	my $report = ''; 
	
	my $Body; 
	my $Subject; 
	
	if($action eq 'over_quota_message'){ 
		$Subject = $Over_Quota_Subject;  
		$Body    = $Over_Quota_Message; 
	}elsif($action eq 'user_unknown_message'){ 
		$Subject = $User_Unknown_Subject;  
		$Body    = $User_Unknown_Message; 
	}elsif($action eq 'email_not_found_message'){ 
		$Subject = $Email_Not_Found_Subject;  
		$Body    = $Email_Not_Found_Message; 
	}elsif($action eq 'unknown_bounce_type_message'){ 
		$Subject = $Email_Unknown_Bounce_Type_Subject; 	
		$Body    = $Email_Unknown_Bounce_Type_Message; 		
	}else{ 
		warn "There's been a misconfiguration somewhere, $Plugin_Config->{Program_Name} is about to die..., ";
		warn "AARRGGGGH!";
	}
	
		my $ls = DADA::MailingList::Settings->new({-list => $list}); 
		my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
		
	
	my $li = $ls->get; 
	
	my ($sub_status, $sub_errors) = $lh->unsubscription_check(
										{
											-email => $email,
										}
									); 
	
	# A little sanity check... 
	if($email eq $li->{admin_email}){ 
		warn "Bounce is from bounce handler, stopping '$action'"; 
	
	
	}elsif(($sub_errors->{not_subscribed} == 1) &&   (($action ne 'user_unknown_message') || ($action ne 'over_quota_message')|| ($action ne 'email_not_found_message')) ){ 
		$report .= "parsed message contains an email ($email) that's not even subscribed. No reason to tell list owner\n";
	}else{ 
		
		my $mh = DADA::Mail::Send->new(
					{
						-list   => $list, 
						-ls_obj => $ls,  
					}
				); 
	 
		my $to  = $Plugin_Config->{Send_Messages_To} || $li->{list_owner_email}; 
		
		my $msg = MIME::Entity->build(
		
		                              To      => $email, 
									  From    => $li->{admin_email},
									  Subject => $Subject,
									  Type    => 'multipart/mixed',
									  );
									  
									   
			$msg->attach(Type        => 'text/plain', 
						 Disposition => 'inline', 
						 Data        => $Body,
						 Encoding    => $li->{plaintext_encoding}
						); 
											 
			$msg->attach(Type        => 'message/rfc822', 
						Disposition  => "attachment",
						Data         => $message); 

			my $report        = generate_nerd_report($list, $email, $diagnostics); 
			my $status_report = rfc1893_status($diagnostics->{Status});

		
			require DADA::App::FormatMessages; 
	
			my $fm = DADA::App::FormatMessages->new(-List => $list); 
	  		   $fm->use_header_info(1);
	           $fm->use_email_templates(0); 

		    $msg = $fm->email_template(
		                    {
		                        -entity                   => $msg,        
		                 		 -subscriber_vars         => { 
									'subscriber.email'    => $email, 
								},
		                        -list_settings_vars       => $ls->params, 
		                        -list_settings_vars_param => {-dot_it => 1},
		                        -vars                   => 
		                            {
										report         => $report, 
										status_report  => $status_report, 
										Program_Name   => $Plugin_Config->{Program_Name},
										Plugin_Name    => $Plugin_Config->{Program_Name},
		                            },
		                    }
		                );
	            
	        my ($header_str, $body_str) = $fm->format_headers_and_body(-msg => $msg->as_string);


		
		   $mh->send(
				  # Trust me on these :) 
				  $mh->return_headers($header_str),
				  'X-BounceHandler' => $Plugin_Config->{Program_Name},
				  To                => $to, 
				  Body => $body_str,
				  
				 );

		$report .= "mail for: $action is on its way!\n";
		    
	}	
	
	return $report; 


} 


sub append_message_to_file { 
	
	my ($list, $email, $diagnostics, $action, $message) = @_; 
	
	my $report ;
	
	
	$report .= "Appending Email to '$action'\n"; 
	    
	$action = DADA::App::Guts::make_safer($action); 
			
	open(APPENDLOG, ">>$action") or die $!; 
	chmod($DADA::Config::FILE_CHMOD, $action); 
	print APPENDLOG "\n" . $message; 
	close(APPENDLOG) or die $!; 

    return $report; 
    
}





sub generate_nerd_report { 

	my ($list, $email, $diagnostics) = @_;
	my $report; 
	$report = "List: $list\nEmail: $email\n\n"; 
	foreach(keys %$diagnostics){ 
		$report .= "$_: " . $diagnostics->{$_} . "\n"; 
	}	
	
	return $report; 

}







sub find_rule_to_use { 
	my ($list, $email, $diagnostics) = @_;
	
	my $ir = 0;
	 
	
	RULES: for ($ir = 0; $ir <= $#$Rules; $ir++){ 
		my $rule = $Rules->[$ir];  
		my $title = (keys %$rule)[0]; 
		
		next if $title eq 'default'; 
		my $match = {}; 
		my $examine = $Rules->[$ir]->{$title}->{Examine}; 
		
		my $message_fields = $examine->{Message_Fields};
		my %ThingsToMatch; 
		
		
		foreach my $m_field(keys %$message_fields){ 
			my $is_regex   = 0; 
			my $real_field = $m_field; 
			$ThingsToMatch{$m_field} = 0; 
			
			if($m_field =~ m/_regex$/){ 
				$is_regex = 1; 
				$real_field = $m_field; 
				$real_field =~ s/_regex$//;  
			}
			
			MESSAGEFIELD: foreach my $pos_match(@{$message_fields->{$m_field}}){ 
				if($is_regex == 1){ 
					if($diagnostics->{$real_field} =~ m/$pos_match/){ 	
						$ThingsToMatch{$m_field} = 1;
						next MESSAGEFIELD;
					}				
				}else{ 
				
					if($diagnostics->{$real_field} eq $pos_match){ 	
						$ThingsToMatch{$m_field} = 1;
						next MESSAGEFIELD;
					}
				
				}
			}	
			
		}

		# If we miss one, the rule doesn't work, 
		# All or nothin', just like life. 
		
		foreach(keys %ThingsToMatch){ 
			if($ThingsToMatch{$_} == 0){
				next RULES; 
			}
		}

   
	    if(keys %{$examine->{Data}}){ 
	    	if($examine->{Data}->{Email}){ 
	    	 	my $valid_email = 0; 
	    	 	my $email_match; 
	    	 	if(DADA::App::Guts::check_for_valid_email($email) == 0){
	    	 			$valid_email = 1; 
	    	 	}
	    	 	if((($examine->{Data}->{Email} eq 'is_valid')   && ($valid_email == 1)) ||
				   (($examine->{Data}->{Email} eq 'is_invalid') && ($valid_email == 0))){
	    	 		$email_match = 1; 
	    	 	}else{ 
	    	 		next RULES;
	    	 	} 
	   		}
	   		
	   		if($examine->{Data}->{List}){ 
	    	 	my $valid_list = 0; 
	    	 	my $list_match; 
	    	 	if(DADA::App::Guts::check_if_list_exists(-List=>$list) != 0){
	    	 		$valid_list = 1; 
	    	 	}
	    	 	if((($examine->{Data}->{List} eq 'is_valid')   && ($valid_list == 1)) ||
				   
				
				   (($examine->{Data}->{List} eq 'is_invalid') && ($valid_list == 0))){
	    	 		$list_match = 1;  
	    	 	}else{ 
	    	 		next RULES;
	    	 	}	 
	   		}
	    }
		return $title; 
	}
	return 'default'; 
}




sub find_verp { 

	my $entity = shift; 
	my $mv = Mail::Verp->new;
	   $mv->separator($DADA::Config::MAIL_VERP_SEPARATOR);
	my ($sender, $recipient) = $mv->decode($entity->head->get('To', 0));
	return $recipient || undef; 


}




sub generic_parse { 

	my $entity = shift; 
	my ($email, $list); 
	my %return = (); 
	my $headers_diag = {}; 
	   $headers_diag = get_orig_headers($entity); 
	my $diag = {}; 
	($email, $diag) = find_delivery_status($entity); 	

	if(keys %$diag){ 	
		%return = (%{$diag}, %{$headers_diag});
	}
	else { 
		%return = %{$headers_diag};
	}
	
	$list = find_list_in_list_headers($entity); 
		
	$list ||= generic_body_parse_for_list($entity); 
	
	$email = DADA::App::Guts::strip($email);
	$email =~ s/^\<|\>$//g if $email;  
	$list  = DADA::App::Guts::strip($list) if $list; 
	return ($list, $email, \%return); 
	
}

sub get_orig_headers { 
	
	my $entity = shift; 
	my $diag = {}; 
	
	foreach('From', 'To', 'Subject'){ 

		if ($entity->head->count($_)){ 
	
			my $header = $entity->head->get($_, 0);
			chomp $header; 
			$diag->{'Bounce_' . $_} = $header; 
		}

	}
	
	return $diag; 
	
	
}




sub find_delivery_status {

	my $entity = shift; 
	my @parts = $entity->parts; 
	my $email; 

	my $diag = {}; 
		
	if(!@parts){ 
		if($entity->head->mime_type eq 'message/delivery-status'){ 
			($email, $diag) = generic_delivery_status_parse($entity); 
	    	return ($email, $diag); 
		} 
	}else{ 
		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($email, $diag) = find_delivery_status($part); 
			if(($email) && (keys %$diag)){ 
				return ($email, $diag); 
			}
		}
	}
} 



sub find_mailer_bounce_headers { 

	my $entity = shift; 
	my $mailer = $entity->head->get('X-Mailer', 0); 
	   $mailer =~ s/\n//g;
	return $mailer if $mailer; 

}




sub find_list_in_list_headers { 

	my $entity = shift; 
	my @parts = $entity->parts; 
	my $list; 	
	if($entity->head->mime_type eq 'message/rfc822'){ 
		my $orig_msg_copy = $parts[0];
		
			my $list_header = $orig_msg_copy->head->get('List', 0); 
			$list = $list_header if $list_header !~ /\:/;
	
			if(!$list){ 
				my $list_id = $orig_msg_copy->head->get('List-ID', 0);
				if($list_id =~ /\<(.*?)\./){ 
					$list = $1 if $1 !~ /\:/;
				}
			}
			if(!$list){ 
				my $list_sub = $orig_msg_copy->head->get('List-Subscribe', 0);
				if($list_sub =~ /l\=(.*?)\>/){ 
					$list = $1; 
				}
			}
		chomp $list; 
		return $list;
	}else{ 
		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			$list = find_list_in_list_headers($part);  
			return $list if $list;
		}
	}
}




sub find_message_id_in_headers { 

	my $entity = shift; 
	my @parts = $entity->parts; 
	my $m_id; 	
	if($entity->head->mime_type eq 'message/rfc822'){ 
		my $orig_msg_copy = $parts[0];	
		   $m_id = $orig_msg_copy->head->get('Message-ID', 0); 
		chomp($m_id); 
		return $m_id;
	}else{ 
		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			$m_id = find_message_id_in_headers($part);  
			return $m_id if $m_id;
		}
	}
}




sub find_message_id_in_body { 

	my $entity = shift; 
	my $m_id; 		
	
	my @parts = $entity->parts; 

	# for singlepart stuff only. 
	if(!@parts){ 
		
		my $body = $entity->bodyhandle; 
		my $IO; 
		
		return undef if ! defined($body); 
	
		if($IO = $body->open("r")){ # "r" for reading.  
			while (defined($_ = $IO->getline)){ 
				chomp($_); 
				if($_ =~ m/^Message\-Id\:(.*?)$/ig){ 
					#yeah, sometimes the headers are in the body of
					#an attached message. Go figure. 
					$m_id = $1; 
				}
			}
		} 
		
		$IO->close;	
		return $m_id; 
	}else{ 
		return undef; 
	}
}











sub generic_delivery_status_parse { 

	my $entity = shift; 
	my $diag = {}; 
	my $email; 
	
		# sanity check
		#if($delivery_status_entity->head->mime_type eq 'message/delivery-status'){ 	
			my $body = $entity->bodyhandle;
			my @lines;
			my $IO; 
			my %bodyfields;
			if($IO = $body->open("r")){ # "r" for reading.  
				while (defined($_ = $IO->getline)){ 
					if ($_ =~ m/\:/){ 
						my ($k, $v) = split(':', $_);
						chomp($v); 
						#$bodyfields{$k} = $v;
						$diag->{$k} = $v; 
					}
				} 
				$IO->close;
			}
			
			if($diag->{'Diagnostic-Code'} =~ /X\-Postfix/){
				$diag->{Guessed_MTA} = 'Postfix';
			} 
			
			my ($rfc, $remail) = split(';', $diag->{'Final-Recipient'});
			if($remail eq '<>'){ #example: Final-Recipient: LOCAL;<>
			 	($rfc, $remail) = split(';', $diag->{'Original-Recipient'});
			}
			$email = $remail; 
			
		foreach(keys %$diag){ 
			$diag->{$_} = DADA::App::Guts::strip($diag->{$_}); 
		}
		
	return ($email, $diag); 
}




sub generic_body_parse_for_list { 

	my $entity = shift; 
	my $list; 
	
	my @parts = $entity->parts; 
	if(!@parts){ 
		$list = find_list_from_unsub_list($entity); 
		return $list if $list; 
	}else{ 
		my $i; 
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			$list = generic_body_parse_for_list($part);
			if($list){ 
				return $list; 
			}
		}
	}	
}




sub find_list_from_unsub_list { 
	
	my $entity = shift; 
	my $list; 		


	my $body = $entity->bodyhandle; 
	my $IO; 
	
	return undef if ! defined($body); 

	if($IO = $body->open("r")){ # "r" for reading.  
		while (defined($_ = $IO->getline)){ 
			chomp($_); 
			
			# DEV: BUGFIX:
			# 2351425 - 3.0.0 - find_list_from_unsub_list sub out-of-date
			# https://sourceforge.net/tracker2/?func=detail&aid=2351425&group_id=13002&atid=113002
			if($_ =~ m/$DADA::Config::PROGRAM_URL\/(u|list)\/(.*?)\//){
				$list = $2;
			}
			# /DEV: BUGFIX
			elsif($_ =~ m/^List\:(.*?)$/){ 
				#yeah, sometimes the headers are in the body of
				#an attached message. Go figure. 
				$list = $1; 
			}
			elsif($_ =~ m/(.*?)\?l\=(.*?)\&f\=u\&e\=/){ 
				$list = $2;
			}
			elsif($_ =~ m/(.*?)\?f\=u\&l\=(.*?)\&e\=/){ 
				$list = $2; 	
			} 
		}
	} 
	
	$IO->close;	
	return $list; 
}




sub parse_for_qmail {

	# When I'm bored
	# => http://cr.yp.to/proto/qsbmf.txt
	# => http://mikoto.sapporo.iij.ad.jp/cgi-bin/cvsweb.cgi/fmlsrc/fml/lib/Mail/Bounce/Qmail.pm
	
	my $entity = shift;	
	my ($email, $list); 
	my $diag = {}; 
	my @parts = $entity->parts; 
	
	my $state        = 0;
	my $pattern      = 'Hi. This is the';
	my $pattern2     = 'Your message has been enqueued by';
	
	my $end_pattern  = '--- Undelivered message follows ---';
	my $end_pattern2 = '--- Below this line is a copy of the message.';
	my $end_pattern3 = '--- Enclosed is a copy of the message.';
	my $end_pattern4 = 'Your original message headers are included below.';
	
	my ($addr, $reason);
		
	if(!@parts){ 
		my $body = $entity->bodyhandle; 
		my $IO;
		if($body){ 
			if($IO = $body->open("r")){ # "r" for reading.  
				while (defined($_ = $IO->getline)){ 
					
					my $data = $_;
					$state = 1 if $data =~ /$pattern|$pattern2/;
					$state = 0 if $data =~ /$end_pattern|$end_pattern2|$end_pattern3/;
					
					if ($state == 1) {	
						$data =~ s/\n/ /g;
	
						if($data =~ /\t(\S+\@\S+)/){ 
							$email = $1; 
						} elsif ($data =~ /\<(\S+\@\S+)\>:\s*(.*)/) {
							($addr, $reason) = ($1, $2);	
							 $diag->{Action} = $reason;
							my $status = '5.x.y';
							if($data =~ /\#(\d+\.\d+\.\d+)/) {
								$status = $1;
							}elsif ($data =~ /\s+(\d{3})\s+/) {
								my $code = $1;
								$status  = '5.x.y' if $code =~ /^5/;
								$status  = '4.x.y' if $code =~ /^4/;
							
							    $diag->{Status} = $status;
								$diag->{Action} = $code; 
								
							}
						
							$email                 = $addr; 
							$diag->{Guessed_MTA}   = 'Qmail'; 
							
						}elsif ($data =~ /(.*)\s\(\#(\d+\.\d+\.\d+)\)/){		# Recipient's mailbox is full, message returned to sender. (#5.2.2)

								$diag->{'Diagnostic-Code'} = $1; 
								$diag->{Status}            = $2; 
								$diag->{Guessed_MTA}       = 'Qmail'; 
								
						}elsif($data =~ /Remote host said:\s(\d{3})\s(\d+\.\d+\.\d+)\s\<(\S+\@\S+)\>(.*)/){ 	# Remote host said: 550 5.1.1 <xxx@xxx>... Account is over quota. Please try again later..[EOF] 

						$diag->{Status}             = $2; 
						$email                      = $3; 
						$diag->{'Diagnostic-Code'}  = $4;
						$diag->{Action}             = 'failed'; #munging this for now...
						$diag->{'Final-Recipient'}  = 'rfc822'; #munging, again. 
						
						}elsif($data =~ /Remote host said:\s(.*?)\s(\S+\@\S+)\s(.*)/){ 
							
							my $status;	
							$email                   ||= $2; 


							$status                  ||= $1;
							$diag->{Status}          ||= '5.x.y' if $status =~ /^5/;
							$diag->{Status}          ||= '4.x.y' if $status =~ /^4/;
							$diag->{'Diagnostic-Code'} = $data;
							$diag->{Guessed_MTA}       = 'Qmail'; 
						
						}elsif ($data =~ /Remote host said:\s(\d{3}.*)/){ 
						
							$diag->{'Diagnostic-Code'} = $1; 
						
						}elsif ($data =~ /(.*)\s\(\#(\d+\.\d+\.\d+)\)/){ 
						
							$diag->{'Diagnostic-Code'} = $1; 
							$diag->{Status}            = $2;
						
						}elsif ($data =~ /(No User By That Name)/){ 
						
							$diag->{'Diagnostic-Code'} = $data; 
							$diag->{Status} = '5.x.y';
						
						}elsif ($data =~ /(This address no longer accepts mail)/){ 
						
							$diag->{'Diagnostic-Code'} = $data; 
						
						}elsif($data =~ /The mail system will continue delivery attempts/){ 
							$diag->{Guessed_MTA}       = 'Qmail'; 
							$diag->{'Diagnostic-Code'} = $data;
						}
					}
				}
			}
			
			$list ||= generic_body_parse_for_list($entity);
			return ($list, $email, $diag); 
		}else{ 
			# no body part to parse
			return (undef, undef, {});
		}
	}else{ 
		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($list, $email, $diag) = parse_for_qmail($part); 
			if(($email) && (keys %$diag)){ 
				return ($list, $email, $diag); 
			}
		}
	} 
}



sub parse_for_exim { 

my $entity = shift;	
	my ($email, $list); 
	my $diag = {}; 
	
	my @parts = $entity->parts;
	if(!@parts){ 
		if($entity->head->mime_type =~ /text/){ 
			# Yeah real hard. Bring it onnnn!
			if($entity->head->get('X-Failed-Recipients', 0)){ 
				
				$email                  = $entity->head->get('X-Failed-Recipients', 0);
				$email                  =~ s/\n//; 
				$email                  = trim($email); 
				$list                   = generic_body_parse_for_list($entity);
				$diag->{Status}         = '5.x.y'; 
				$diag->{Guessed_MTA}    = 'Exim'; 
				return ($list, $email, $diag);
				
			}else{ 
				
				my $body = $entity->bodyhandle; 
				my $IO;
				if($body){ 
				
					if($IO = $body->open("r")){ # "r" for reading.  
						
						my $pattern     = 'This message was created automatically by mail delivery software (Exim).';
						my $end_pattern = '------ This is a copy of the message';
						my $state       = 0;
						
						while (defined($_ = $IO->getline)){ 
						
							my $data = $_;
						
							$state = 1 if $data =~ /\Q$pattern/;
							$state = 0 if $data =~ /$end_pattern/;
						
							if ($state == 1) {
						
								$diag->{Guessed_MTA} = 'Exim';
					
								if($data =~ /(\S+\@\S+)/){
						
									$email = $1;
									$email = trim($email);
						
								}elsif($data =~ m/unknown local-part/){ 
						
									$diag->{'Diagnostic-Code'} = 'unknown local-part';
									$diag->{'Status'}          = '5.x.y';
						
								}	
							}
						}
					}
				}
				return ($list, $email, $diag);
			} 
		}else{ 
			return (undef, undef, {});
		}
	}else{ 
		# no body part to parse
		return (undef, undef, {});
	}	  
} 


sub parse_for_f__king_exchange { 

	my $entity = shift; 
	my @parts = $entity->parts; 
	my $email; 
	my $diag = {}; 
	my $list;
	my $state       = 0;
	my $pattern     = 'Your message';
						
	if(!@parts){ 
		if($entity->head->mime_type eq 'text/plain'){ 
			my $body = $entity->bodyhandle; 
			my $IO;
			if($body){ 
				if($IO = $body->open("r")){ # "r" for reading.  
					while (defined($_ = $IO->getline)){ 
						my $data = $_;
						$state = 1 if $data =~ /$pattern/;
						if ($state == 1) {
							$data =~ s/\n/ /g;
							if($data =~ /\s{2}To:\s{6}(\S+\@\S+)/){ 
								$email =  $1;
							}
							elsif($data =~ /(MSEXCH)(.*?)(Unknown\sRecipient|Unknown|)/){ # I know, not perfect.
								$diag->{Guessed_MTA}       = 'Exchange';
								$diag->{'Diagnostic-Code'} = 'Unknown Recipient';
							}else{ 
								#...
								#warn "nope: " . $data; 
							}
						}
					}
				}
			}
		} 
		return ($list, $email, $diag);
	}else{ 
		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($list, $email, $diag) = parse_for_f__king_exchange($part); 
			if(($email) && (keys %$diag)){ 
				return ($list, $email, $diag); 
			}
		}
	}
}




sub parse_for_novell { #like, really...

	my $entity = shift; 

	my @parts = $entity->parts; 
	my $email; 
	my $diag = {}; 
	my $list;
	my $state       = 0;
	my $pattern     = 'The message that you sent';

	if(!@parts){ 
		if($entity->head->mime_type eq 'text/plain'){ 
			my $body = $entity->bodyhandle; 
			my $IO;
			if($body){ 
				if($IO = $body->open("r")){ # "r" for reading.  
					while (defined($_ = $IO->getline)){ 
						my $data = $_;
						$state = 1 if $data =~ /$pattern/;
						if ($state == 1) {
							$data =~ s/\n/ /g;
							if($data =~ /\s+(\S+\@\S+)\s\((.*?)\)/){ 
								$email                     =  $1;
								$diag->{'Diagnostic-Code'} =  $2;
							}else{ 
								#...
							}
						}
					}
				}
			}
		} 
		return ($list, $email, $diag);
	}else{ 

		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($list, $email, $diag) = parse_for_novell($part); 
			if(($email) && (keys %$diag)){ 
				$diag->{'X-Mailer'} = find_mailer_bounce_headers($entity);
				return ($list, $email, $diag); 
			}
		}
	}
}




sub parse_for_gordano { # what... ever that is there...
	
	my $entity = shift; 
	my @parts = $entity->parts; 
	my $email; 
	my $diag = {}; 
	my $list;
	my $state       = 0;
	
	my $pattern     = 'Your message to';
	my $end_pattern = 'The message headers';
	
	if(!@parts){ 
		if($entity->head->mime_type eq 'text/plain'){ 
			my $body = $entity->bodyhandle; 
			my $IO;
			if($body){ 
				if($IO = $body->open("r")){ # "r" for reading.  
					while (defined($_ = $IO->getline)){ 
						my $data = $_;
						$state = 1 if $data =~ /$pattern/;
						$state = 0 if $data =~ /$end_pattern/;
						if ($state == 1) {
							$data =~ s/\n/ /g;
							if($data =~ /RCPT To:\<(\S+\@\S+)\>/){	#    RCPT To:<xxx@usnews.com>
								$email                     =  $1;
							}elsif($data =~ /(.*?)\s(\d+\.\d+\.\d+)\s(.*)/){	# 550 5.1.1 No such mail drop defined.
								$diag->{Status}			   = $2; 
								$diag->{'Diagnostic-Code'} = $3;
								$diag->{'Final-Recipient'} = 'rfc822'; #munge; 
								$diag->{Action}            = 'failed'; #munge;
							}else{ 
								#...
							}
						}
					}
				}
			}
		} 
		return ($list, $email, $diag);
	}else{ 
		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($list, $email, $diag) = parse_for_gordano($part); 
			if(($email) && (keys %$diag)){ 
				$diag->{'X-Mailer'} = find_mailer_bounce_headers($entity);
				return ($list, $email, $diag); 
			}
		}
	}
}




sub parse_for_overquota_yahoo { 

	my $entity = shift; 
	my @parts = $entity->parts; 
	my $email; 
	my $diag = {}; 
	my $list;
	my $state       = 0;
	my $pattern     = 'Message from  yahoo.com.';

	if(!@parts){ 
		if($entity->head->mime_type eq 'text/plain'){ 
			my $body = $entity->bodyhandle; 
			my $IO;
			if($body){ 
				if($IO = $body->open("r")){ # "r" for reading.  
					while (defined($_ = $IO->getline)){ 
						my $data = $_;
						$state = 1 if $data =~ /$pattern/;
						$diag->{'Remote-MTA'} = 'yahoo.com';
						
						if ($state == 1) {
							$data =~ s/\n/ /g; #what's up with that?	
							if($data =~ /\<(\S+\@\S+)\>\:/){ 
								$email                     =  $1;
							}else{ 
								if($data =~ m/(over quota)/){ 
									$diag->{'Diagnostic-Code'} = $data;
								}
							}
						}
					}
				}
			}
		} 
		return ($list, $email, $diag);
	}else{ 

		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($list, $email, $diag) = parse_for_overquota_yahoo($part); 
			if(($email) && (keys %$diag)){ 
				$diag->{'X-Mailer'} = find_mailer_bounce_headers($entity);
				return ($list, $email, $diag); 
			}
		}
	}
}




sub parse_for_earthlink { 

	my $entity = shift; 
	my @parts = $entity->parts; 
	my $email; 
	my $diag = {}; 
	my $list;
	my $state       = 0;
	my $pattern     = 'Sorry, unable to deliver your message to';

	if(!@parts){ 
		if($entity->head->mime_type eq 'text/plain'){ 
			my $body = $entity->bodyhandle; 
			my $IO;
			if($body){ 
				if($IO = $body->open("r")){ # "r" for reading.  
					while (defined($_ = $IO->getline)){ 
						my $data = $_;
						$state = 1 if $data =~ /$pattern/;
						if ($state == 1) {
							$diag->{'Remote-MTA'} = 'Earthlink';
							$data =~ s/\n/ /g; #what's up with that?	
							if($data =~ /(\d{3})\s(.*?)\s(\S+\@\S+)/){	#  552 Quota violation for postmaster@example.com
								$diag->{'Diagnostic-Code'} = $1 . ' ' . $2; 
								$email = $3; 
							}
						}
					}
				}
			}
		} 
		return ($list, $email, $diag);
	}else{ 

		my $i;
		foreach $i (0 .. $#parts) {
	    	my $part = $parts[$i];
			($list, $email, $diag) = parse_for_earthlink($part); 
			if(($email) && (keys %$diag)){ 
				$diag->{'X-Mailer'} = find_mailer_bounce_headers($entity);
				return ($list, $email, $diag); 
			}
		}
	}
}



sub parse_for_windows_live { 

	my $entity = shift; 
#	
	my $email; 
	my $diag = {}; 
	my $list;
	my $state       = 0;
	
	
	my @parts  = $entity->parts; 
	my @parts0 = $parts[0]->parts; 

	if ($parts0[0]->head->count('X-HmXmrOriginalRecipient')){ 
		$email = $parts0[0]->head->get('X-HmXmrOriginalRecipient', 0);
		$diag->{'Remote-MTA'} = 'Windows_Live'; 
		return ($list, $email, $diag);
	}


}




sub parse_using_m_ds_bp { 

    eval { require Mail::DeliveryStatus::BounceParser; };
    
    
    return (undef, undef, {}) if $@; 
    
    # else, let's get to work; 
    
    my $entity  = shift; 
    my $message = $entity->as_string;
    
    my $bounce = eval { Mail::DeliveryStatus::BounceParser->new($message); };
    
    if ($@) {
        # couldn't parse.
        return (undef, undef, {}) if $@; 
     }
         
      # examples:
      # my @addresses       = $bounce->addresses;       # email address strings
      # my @reports         = $bounce->reports;         # Mail::Header objects
      # my $orig_message_id = $bounce->orig_message_id; # <ABCD.1234@mx.example.com>
      # my $orig_message    = $bounce->orig_message;    # Mail::Internet object

    return (undef, undef, {})
        if $bounce->is_bounce != 1; 

    my ($report) = $bounce->reports;

    return (undef, undef, {})
        if ! defined $report; 
        
    my $diag = {}; 
        
    $diag->{'Message-Id'} = $report->get('orig_message_id')
        if $report->get('orig_message_id');     
    
    $diag->{Action} = $report->get('action')
        if $report->get('action');     

    $diag->{Status} = $report->get('status')
        if $report->get('status');     
    
     $diag->{'Diagnostic-Code'} = $report->get('diagnostic-code')
        if $report->get('diagnostic-code'); 

    $diag->{'Final-Recipient'} = $report->get('final-recipient')
        if $report->get('final-recipient');
        
    # these aren't used particularily in Dada Mail, but let's play around with them...
    
    $diag->{std_reason} = $report->get('std_reason') 
        if $report->get('std_reason'); 
        
    $diag->{reason}     = $report->get('reason')
        if $report->get('reason'); 
        
    $diag->{host}       = $report->get('host')
        if $report->get('host'); 
        
    $diag->{smtp_code}  = $report->get('smtp_code')
        if $report->get('smtp_code');
    
    my $email = $report->get('email') || undef; 
    
    return (undef, $email, $diag); 
    
    
}




#sub carry_out_all_rules { 
#	my $array_ref = shift; 
#	foreach my $dead(@$Rules_To_Carry_Out){
#		 carry_out_rule(@$dead); #hope this works
#	}
#
#}





sub save_scores { 

    
    my $score = shift; 
    
    if(keys %$score){
        
        my @delete_list = DADA::App::Guts::available_lists(); 

        foreach my $d_list(@delete_list){ 
        
			print "\nWorking on list: $list\n"
			 if $verbose; 
			
            require   DADA::App::BounceScoreKeeper; 
            my $bsk = DADA::App::BounceScoreKeeper->new(-List => $d_list); 
            
            my $list_scores = $score->{$d_list}; 
            
            my $lh = DADA::MailingList::Subscribers->new({-list => $d_list}); 
            
            foreach my $bouncing_email(keys %$list_scores){ 
	
			#	print "Examining: $bouncing_email\n"
			#		if $verbose; 
	
                if($lh->check_for_double_email(-Email => $bouncing_email) == 0){ 
                    undef($list_scores->{$bouncing_email}); 
                    delete($list_scores->{$bouncing_email});
                    
             #       print "Email: $bouncing_email not subscribed to: $d_list - ignoring.\n"
              #          if $verbose;
                }
				else { 
                   # print "Email: $bouncing_email subscribed to: $d_list - will unsubscribe.\n"
                   #     if $verbose;
				}
            }
            
            my $give_back_scores = $bsk->tally_up_scores($list_scores); 

            if(keys %$give_back_scores){ 
                print "\nScore Totals for $d_list:\n\n"
                    if $verbose; 
                foreach(keys %$give_back_scores){ 
                print "\tEmail: $_ total score: " . $give_back_scores->{$_} . "\n"
                    if $verbose; 
                }
            } 
            
            my $removal_list = $bsk->removal_list($Plugin_Config->{Score_Threshold}); 			
    
			print "Addresses to be removed:\n" . '-' x 72 . "\n"
				if $verbose; 
				
            foreach my $bad_email(@$removal_list){
                    $Remove_List->{$d_list}->{$bad_email} = 1;
                    print "\t$bad_email\n" 
                        if $verbose;
            
            }
        
			# DEV: Hmm, this gets repeated for each list?
            print "Flushing old scores over " . $Plugin_Config->{Score_Threshold} . "\n" 
				if $verbose; 
            $bsk->flush_old_scores($Plugin_Config->{Score_Threshold}); 
        }
        
    }else{ 

        print "No scores to tally.\n"
            if $verbose; 
            
    }
}




sub remove_bounces { 
	
	my $report = shift; 
	
	print "Removing addresses from all lists:\n" . '-' x 72 . "\n"
	 	if $verbose; 
	
	foreach my $list(keys %$report){ 
		
		print "\nList: $list\n"
			if $verbose; 
		
		my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
		my $ls = DADA::MailingList::Settings->new({-list => $list}); 
		my $li = $ls->get; 
		
		my @remove_list = keys %{$report->{$list}}; 
		
		if($verbose){ 
			foreach(@remove_list){ 
				print "Removing: $_\n"; 
			}
		}
		
			
		# removing them all at once 
		# optimization so it won't thrash a plain text list
				
		$lh->remove_from_list(-Email_List => [@remove_list]);	# As a Fuck son, you sucked.		
	
		if( ($li->{black_list}               == 1)    && 
		    ($li->{add_unsubs_to_black_list} == 1) ){
			foreach my $re(@remove_list){ 
				$lh->add_subscriber(
					{
						-email => $re, 
						-type  => 'black_list', 
					}
				);
			}
		}
			
		# Bang Bang Baby, The Bigger The Better.
		# Bang Bang Baby, The Bigger The Better.
		# Bang Bang Baby, The Bigger The Better.
		# Bang Bang Baby, The Bigger The Better.
		# You aint a baby no more baby 
		# You aint no bigger than before baby 
		# I'll rub that cheap black off your lips baby 
		# so take a swallow as i spit baby 


		if($li->{get_unsub_notice} == 1){ 
			require DADA::App::Messages;
			
			my $r; 
			
			if($li->{enable_bounce_logging}){ 
			require DADA::Logging::Clickthrough; 
					$r = DADA::Logging::Clickthrough->new({-list => $list }); 
					
			}
			
			print "\n"
			 if $verbose; 
			
			my $aa = 0; 
			
			foreach my $d_email(@remove_list){ 
				
				
				# warn '$d_email ' . $d_email . ' at ' . $aa ;
				
				# You shouldn't need the check for a double email, since WE JUST REMOVED THE BLOODY ADDRESS FROM THE LIST. 
				
				#if($lh->check_for_double_email(-Email => $d_email, -Type => 'list') == 1) {  
					DADA::App::Messages::send_owner_happenings(
						{
							-list   => $list, 
							-email  => $d_email, 
							-role   => 'unsubscribed', 
							-lh_obj => $lh, 
							-ls_obj => $ls, 
							-note   => 'Reason: Address is bouncing messages.',  
						}
					);
					
					# No?
					#DADA::App::Messages::send_unsubscribed_message(-List      => $list,
					#						                       -Email     => $d_email,
					#				                               -List_Info => $li); 
					
					DADA::App::Messages::send_generic_email(
						{
					    	-list    => $list, 
                            -email   => $d_email, 
                            -ls_obj  => $ls, 
							-headers => { 
                            	Subject => $Email_Unsubscribed_Because_Of_Bouncing_Subject, 
                        	},
							-body      => $Email_Unsubscribed_Because_Of_Bouncing_Message, 
							-tmpl_params => { 
								-list_settings_vars_param => { 
										-list => $list,
								},
								-subscriber_vars => {
									'subscriber.email' => $d_email, 
								},
								-vars => {
											Plugin_Name => $Plugin_Config->{Program_Name},
										},
							}, 
						}
					);
					if($li->{enable_bounce_logging}){
						$r->bounce_log($Bounce_History->{$list}->{$d_email}->[0]->{'Simplified-Message-Id'},  $d_email); 
					}
	
				#} else { 
			    #		print $d_email . " not subscribed on $list - suppressing actions... \n"
				#		if $verbose;
				#}
			}
		}
	}
}




sub test_script { 
	
	$verbose = 1; 
	
	my @files_to_test; 
	
	if($test eq 'pop3'){ 
		test_pop3(); 
	}elsif(-d $test){ 
		@files_to_test = dir_list($test); 
	}elsif(-f $test){ 
		push(@files_to_test, $test); 
	}
	
	my $i = 1; 
	foreach my $testfile(@files_to_test){ 
		print "test #$i: $testfile\n" . '-' x 60 . "\n"; 
		parse_bounce(-message => openfile($testfile)); 
		++$i; 
	} 
	exit; 

}




sub test_pop3 { 

	require DADA::App::POP3Tools; 
	
	my $lock_file_fh; 
	if($Plugin_Config->{Enable_POP3_File_Locking} == 1){ 
		
		$lock_file_fh = DADA::App::POP3Tools::_lock_pop3_check(
								{
									name => 'dada_bounce_handler.lock',
								}
							);
	}

	my $pop = DADA::App::POP3Tools::mail_pop3client_login(
	    {
	    
	        server    => $Plugin_Config->{Server}, 
	        username  => $Plugin_Config->{Username}, 
	        password  => $Plugin_Config->{Password},
			port      => $Plugin_Config->{Port}, 
	        USESSL    => $Plugin_Config->{USESSL},
	        AUTH_MODE => $Plugin_Config->{AUTH_MODE},
	        verbose   => $verbose,
	    
	    }
	); 
	

	if($Plugin_Config->{Enable_POP3_File_Locking} == 1){ 
		DADA::App::POP3Tools::_unlock_pop3_check(
			{
				name => 'dada_bounce_handler.lock',
				fh   => $lock_file_fh, 
			},
		);
	}
	
	if(defined($pop)){ 
	    $pop->Close();
	}
}




sub version { 

	#heh, subversion, wild. 
	print "$Plugin_Config->{Program_Name} Version: $App_Version\n"; 
	print "$DADA::Config::PROGRAM_NAME Version: $DADA::Config::VER\n"; 
	print "Perl Version: $]\n\n"; 
	
	my @ap = ('No sane man will dance. - Cicero ',
	          'Be happy. It is a way of being wise.  - Colette',
	          'There is more to life than increasing its speed. - Mahatma Gandhi',
	          'Life is short. Live it up. - Nikita Khrushchev'); 
	          
	print "Random Aphorism: " . $ap[int rand($#ap+1)] . "\n\n";	           
	
	exit; 
	
} 


sub dir_list { 
	my $dir = shift; 
	my $file; 
	my @files; 
	$dir = DADA::App::Guts::make_safer($file); 
	opendir(DIR, $dir) or die "$!"; 
	while(defined($file = readdir DIR) ) { 
		next if        $file =~ /^\.\.?$/;
		$file =~ s(^.*/)();
		 if(-f $dir . '/' . $file ){  
			push(@files, $dir . '/' . $file);

		} 
	
	}
	closedir(DIR); 
	return @files; 
} 




sub openfile { 
	my $file = shift; 
	my $data = shift; 
	
	$file = DADA::App::Guts::make_safer($file);
	
	open(FILE, "<$file") or die "$!"; 
	
    $data = do{ local $/; <FILE> }; 

	close(FILE); 
	return $data; 
} 



sub open_log { 
	my $log = shift; 
	   $log = DADA::App::Guts::make_safer($log); 
	if($log){ 
		open(BOUNCELOG, ">>$log") 
			or warn "Can't open bounce log at '$log' because: $!"; 
		chmod($DADA::Config::FILE_CHMOD, $log); 
		$Have_Log = 1; 
		return 1; 
	}
}




sub log_action { 

	my ($list, $email, $diagnostics, $action) = @_; 
	my $time = scalar(localtime());

	if($Have_Log){ 
		my $d; 
		foreach(keys %$diagnostics){ 
			$d .= $_ .': ' . $diagnostics->{$_} . ', ';
		}
		print BOUNCELOG "[$time]\t$list\t$action\t$email\t$d\n";
	} 
	
}




sub close_log{ 
	if($Have_Log){ 
		close(BOUNCELOG); 
	}
}




sub show_help { 
print q{ 

arguments: 
-----------------------------------------------------------
--help                 		
--verbose
--test ('bounces' | 'pop3'|filename | dirname)
--messages         n
--server           server
--username         username
--password         password
--log              filename
--erase_score_card
--version
-----------------------------------------------------------
for a general overview and more instructions, try:

pod2text ./dada_bounce_handler.pl | less

-----------------------------------------------------------

* pop3 server params: --server --username --password

You can pass the POP3 server params to the script via these options. 
The arguments passed will writeover any set in the script. This comes
in handy if, say, you're not comfortable putting the POP3 password in
the script itself. You may be crafty and have the password saved in
a more secure location and created a wrapper script that then calls
this script - I'll leave that to your imagination. 

But anyways: 

 prompt>./dada_bounce_handler \
  --server mail.myhost.com\
  --username dadabounce\
  --password secretgodmoney

 All three of these options are optional and you can use them with 
 any of the tests, discussed above. 

* --verbose

passing the --verbose parameter is like giving this script some 
coffee.  Similar to what you'd see if you ran the script using: 

 prompt>./dada_bounce_handler --test bounces
 
But bounce handling will go through to completion. 

* --help

Obligatory help text printed out. Written as geeky as possible. 

* --version

Will print out both the version of Mystery Girl and also of Dada Mail. 
Good for debugging. Looks like this: 

 Mystery Girl version: 1.6
 Dada Mail version: 2.10.9

* --log

If you pass a filename to the script, it'll write a log of the action
it takes per email. A log entry looks much like this: 

 [Sun May 11 16:57:23 2003]      justin  unsubscribe_bounced_email from_list \
     fdsafsa890sadf89@hotmail.com     Status: 5.x.y, Action: ,

The format is: 

 time \t list \t action \t email \t diagnostics

If you don't want to pass the log each time, you can set a log in the
B<$Plugin_Config->{Log}> variable - 


* Nifty Tip

If you explicitly set the B<$LOGS> Config.pm variable to an absolute path to a directory, 
set $Plugin_Config->{Log} (in this script) to: 

 my $Plugin_Config->{Log} = $LOGS . '/bounces.txt';

If you're using the Log Viewer plugin,  the plugin will automatically find this file and add it to the logs it will show. 

* --messages

I decided that it would be silly to run dada_bounce_handler.pl by 
blindly trying to handle every bounced message that may be waiting
for it every time its run. Perhaps you have a list that created 1,000
bounces (not unheard of), rummaging through 1,000 messages may take time, 
so instead, I encourage you to set how many messages should be looked
at every time the script is run. 

I like to use this as a final test; I can test one real message towards
completion and make sure everything is OK. 

If you do want to handle, say 1000 messages at a day, I would suggest to
set the number of messages it handles to something like 100 and set your
cronjob to run 10 times, perhaps 15 minutes apart. Your call, though. 

* --erase_score_card

Removes the score card of bounced email addresses. This makes sense, once you read, "More on Scores..." thingy below.

-----------------------------------------------------------

Testing Mystery Girl via the Command Line

You can pass the B<--test> argument to dada_bounce_handler.pl to make
sure everything is workings as it should. The B<--test> argument needs to 
take one of a few paramaters: 


* pop3

 prompt>./dada_bounce_handler.pl --test pop3

This will test only your POP3 login. If it's successful, it'll return 
the number of messages waiting: 

 prompt>./dada_bounce_handler.pl --test pop3
 POP3 Login succeeded.
 Message count: 5 

If the login failed, you'll get back a message that reads: 

 prompt>./dada_bounce_handler.pl --test pop3
 POP3 login failed.

* filename or directory

if you pass an argument that's a filename, dada_bounce_handler.pl 
will attempt to parse that file as if it's a bounced message. If you
pass a directory as an argument, dada_bounce_handler.pl will attempt
to parse all the files in that directory as if they were bounced 
messages. 

dada_bounce_handler.pl won't act on these test messages, but will do
everything until that point. You'll get back a verbose message of the
going's on of the script: 
 
 prompt> perl dada_bounce_handler.pl  --test message8.txt 
 test #1: message8.txt
 ------------------------------------------------------------
 ------------------------------------------------------------------------
 Content-type: multipart/report
 Effective-type: multipart/report
 Body-file: NONE
 Subject: Returned mail: see transcript for details
 Num-parts: 3
 --
     Content-type: text/plain
     Effective-type: text/plain
     Body-file: NONE
     --
     Content-type: message/delivery-status
     Effective-type: message/delivery-status
     Body-file: NONE
     --
     Content-type: message/rfc822
     Effective-type: message/rfc822
     Body-file: NONE
     Num-parts: 1
     --
         Content-type: text/plain
         Effective-type: text/plain
         Body-file: NONE
         Subject: Simoni Creative - Dada Mail Mailing List Confirmation
         --
 ------------------------------------------------------------------------
 List: dada_announce
 Email: de4est@centurytel.net    
 
 Last-Attempt-Date: Sun, 13 Apr 2003 20
 Action: failed
 Status: 5.1.1
 Diagnostic-Code: SMTP; 550 5.1.1 <de4est@centurytel.net>... User unknown
 Final-Recipient: RFC822; de4est@centurytel.net
 Remote-MTA: DNS; [209.142.136.158]
 
 Using Rule: default

The first chunk of output is a skeleton of the bounced message. If it looks 
similar to what's above, you most likely gave the bounce handler a real email
message. 

After that, will be listed the findings of the bounce handler. 
The List and Email address will be listed, followed by some diagnostic
code. 

The last thing printed out is the rule, and we'll get to that shortly. 

* bounces

Setting the test argument to B<bounces> will actually perform the
test on any live bounce email messages in the mailbox. 
You'll see similar output that you would if you were testing a file.

};
	exit; 
}




sub erase_score_card { 

    print "Removing the Bounce Score Card...\n\n";
    
    my @delete_list; 
    
    if($list) { 
            @delete_list = ($list); 
    }
    else { 
        
        @delete_list = DADA::App::Guts::available_lists(); 
        
    }    
       
       
    foreach(@delete_list){ 
       
        require   DADA::App::BounceScoreKeeper; 
        my $bsk = DADA::App::BounceScoreKeeper->new(-List => $_); 
            
        $bsk->erase; 
        
        print "Kapow! All scores for $_ have been erased.\n";
   
    }

    exit;
}




sub trim { 
my $string = shift || undef; 
	if($string){ 
		$string =~ s/^\s+//o;
		$string =~ s/\s+$//o;

		return $string;
	}else{ 
		return undef; 
	}
}




sub rfc1893_status { 

	my $status = shift; 
       $status = trim($status); 
       
	return "" if ! $status; 
	my $key; 

	my ($class, $subject, $detail) = split(/\./, $status); 

	$key = 'X' . '.' . $subject . '.' . $detail; 
	
	my %rfc1893; 
	
	$rfc1893{'X.0.0'} = qq {  
	Other undefined status is the only undefined error code. It
	should be used for all errors for which only the class of the
	error is known.
	}; 
	
	$rfc1893{'X.1.0'} = qq { 
	X.1.0   Other address status
	
	Something about the address specified in the message caused
	this DSN.
	}; 
	
	$rfc1893{'X.1.1'} = qq { 
	X.1.1   Bad destination mailbox address
	
	The mailbox specified in the address does not exist.  For
	Internet mail names, this means the address portion to the
	left of the "@" sign is invalid.  This code is only useful
	for permanent failures.
	};
	
	$rfc1893{'X.1.2'} = qq { 
	X.1.2   Bad destination system address
	
	The destination system specified in the address does not
	exist or is incapable of accepting mail.  For Internet mail
	names, this means the address portion to the right of the
	"@" is invalid for mail.  This codes is only useful for
	permanent failures.
	}; 
	
	$rfc1893{'X.1.3'} = qq { 
	X.1.3   Bad destination mailbox address syntax
	
	The destination address was syntactically invalid.  This can
	apply to any field in the address.  This code is only useful
	for permanent failures.
	};
	
	$rfc1893{'X.1.4'} = qq { 
	X.1.4   Destination mailbox address ambiguous
	
	The mailbox address as specified matches one or more
	recipients on the destination system.  This may result if a
	heuristic address mapping algorithm is used to map the
	specified address to a local mailbox name.
	}; 
	
	$rfc1893{'X.1.5'} = qq { 
	X.1.5   Destination address valid
	
	This mailbox address as specified was valid.  This status
	code should be used for positive delivery reports.
	};
	
	$rfc1893{'X.1.6'} = qq { 
	X.1.6   Destination mailbox has moved, No forwarding address
	
	The mailbox address provided was at one time valid, but mail
	is no longer being accepted for that address.  This code is
	only useful for permanent failures.
	}; 
	
	$rfc1893{'X.1.7'} = qq { 
	X.1.7   Bad sender's mailbox address syntax
	
	The sender's address was syntactically invalid.  This can
	apply to any field in the address.
	}; 
	
	$rfc1893{'X.1.8'} = qq { 
	X.1.8   Bad sender's system address
	
	The sender's system specified in the address does not exist
	or is incapable of accepting return mail.  For domain names,
	this means the address portion to the right of the "@" is
	invalid for mail.
	}; 
	
	$rfc1893{'X.2.0'} = qq { 
	X.2.0   Other or undefined mailbox status
	
	The mailbox exists, but something about the destination
	mailbox has caused the sending of this DSN.
	};
	
	$rfc1893{'X.2.1'} = qq {  
	X.2.1   Mailbox disabled, not accepting messages
	
	The mailbox exists, but is not accepting messages.  This may
	be a permanent error if the mailbox will never be re-enabled
	or a transient error if the mailbox is only temporarily
	disabled.
	}; 
	
	$rfc1893{'X.2.2'} = qq {  
	X.2.2   Mailbox full
	
	The mailbox is full because the user has exceeded a
	per-mailbox administrative quota or physical capacity.  The
	general semantics implies that the recipient can delete
	messages to make more space available.  This code should be
	used as a persistent transient failure.
	};
	
	$rfc1893{'X.2.3'} = qq {  
	X.2.3   Message length exceeds administrative limit
	
	A per-mailbox administrative message length limit has been
	exceeded.  This status code should be used when the
	per-mailbox message length limit is less than the general
	system limit.  This code should be used as a permanent
	failure.
	}; 
	
	$rfc1893{'X.2.4'} = qq {  
	X.2.4   Mailing list expansion problem
	
	The mailbox is a mailing list address and the mailing list
	was unable to be expanded.  This code may represent a
	permanent failure or a persistent transient failure.
	};
	
	$rfc1893{'X.3.0'} = qq {  
	X.3.0   Other or undefined mail system status
	
	The destination system exists and normally accepts mail, but
	something about the system has caused the generation of this
	DSN.
	};
	
	$rfc1893{'X.3.1'} = qq {  
	X.3.1   Mail system full
	
	Mail system storage has been exceeded.  The general
	semantics imply that the individual recipient may not be
	able to delete material to make room for additional
	messages.  This is useful only as a persistent transient
	error.
	};
	
	$rfc1893{'X.3.2'} = qq {  
	X.3.2   System not accepting network messages
	
	The host on which the mailbox is resident is not accepting
	messages.  Examples of such conditions include an immanent
	shutdown, excessive load, or system maintenance.  This is
	useful for both permanent and permanent transient errors.
	};
	
	$rfc1893{'X.3.3'} = qq {  
	X.3.3   System not capable of selected features
	
	Selected features specified for the message are not
	supported by the destination system.  This can occur in
	gateways when features from one domain cannot be mapped onto
	the supported feature in another.
	};
	
	$rfc1893{'X.3.4'} = qq {  
	X.3.4   Message too big for system
	
	The message is larger than per-message size limit.  This
	limit may either be for physical or administrative reasons.
	This is useful only as a permanent error.
	}; 
	
	$rfc1893{'X.3.5'} = qq {  
	X.3.5 System incorrectly configured
	
	The system is not configured in a manner which will permit
	it to accept this message.
	};
	
	$rfc1893{'X.4.0'} = qq {  
	X.4.0   Other or undefined network or routing status
	
	Something went wrong with the networking, but it is not
	clear what the problem is, or the problem cannot be well
	expressed with any of the other provided detail codes.
	}; 
	
	$rfc1893{'X.4.1'} = qq {  
	X.4.1   No answer from host
	
	The outbound connection attempt was not answered, either
	because the remote system was busy, or otherwise unable to
	take a call.  This is useful only as a persistent transient
	error.
	}; 
	
	$rfc1893{'X.4.2'} = qq {  
	X.4.2   Bad connection

	
	The outbound connection was established, but was otherwise
	unable to complete the message transaction, either because
	of time-out, or inadequate connection quality. This is
	useful only as a persistent transient error.
	};
	
	$rfc1893{'X.4.3'} = qq {   
	X.4.3   Directory server failure
	
	The network system was unable to forward the message,
	because a directory server was unavailable.  This is useful
	only as a persistent transient error.
	
	The inability to connect to an Internet DNS server is one
	example of the directory server failure error.
	}; 
	
	$rfc1893{'X.4.4'} = qq { 
	X.4.4   Unable to route
	
	The mail system was unable to determine the next hop for the
	message because the necessary routing information was
	unavailable from the directory server. This is useful for
	both permanent and persistent transient errors.
	
	A DNS lookup returning only an SOA (Start of Administration)
	record for a domain name is one example of the unable to
	route error.
	};
	
	$rfc1893{'X.4.5'} = qq { 
	X.4.5   Mail system congestion
	
	The mail system was unable to deliver the message because
	the mail system was congested. This is useful only as a
	persistent transient error.
	};
	
	$rfc1893{'X.4.6'} = qq { 
	X.4.6   Routing loop detected
	
	A routing loop caused the message to be forwarded too many
	times, either because of incorrect routing tables or a user
	forwarding loop. This is useful only as a persistent
	transient error.
	};
	
	$rfc1893{'X.4.7'} = qq { 
	X.4.7   Delivery time expired
	
	The message was considered too old by the rejecting system,
	either because it remained on that host too long or because
	the time-to-live value specified by the sender of the
	message was exceeded. If possible, the code for the actual
	problem found when delivery was attempted should be returned
	rather than this code.  This is useful only as a persistent
	transient error.
	};
	
	$rfc1893{'X.5.0'} = qq { 
	X.5.0   Other or undefined protocol status
	
	Something was wrong with the protocol necessary to deliver
	the message to the next hop and the problem cannot be well
	expressed with any of the other provided detail codes.
	};
	
	$rfc1893{'X.5.1'} = qq { 
	X.5.1   Invalid command
	
	A mail transaction protocol command was issued which was
	either out of sequence or unsupported.  This is useful only
	as a permanent error.
	};
	
	$rfc1893{'X.5.2'} = qq { 
	X.5.2   Syntax error
	
	A mail transaction protocol command was issued which could
	not be interpreted, either because the syntax was wrong or
	the command is unrecognized. This is useful only as a
	permanent error.
	};
	
	$rfc1893{'X.5.3'} = qq { 
	X.5.3   Too many recipients
	
	More recipients were specified for the message than could
	have been delivered by the protocol.  This error should
	normally result in the segmentation of the message into two,
	the remainder of the recipients to be delivered on a
	subsequent delivery attempt.  It is included in this list in
	the event that such segmentation is not possible.
	};
	
	$rfc1893{'X.5.4'} = qq { 
	X.5.4   Invalid command arguments
	
	A valid mail transaction protocol command was issued with
	invalid arguments, either because the arguments were out of
	range or represented unrecognized features. This is useful
	only as a permanent error.
	};
	
	$rfc1893{'X.5.5'} = qq { 
	X.5.5   Wrong protocol version
	
	A protocol version mis-match existed which could not be
	automatically resolved by the communicating parties.
	};
	
	$rfc1893{'X.6.0'} = qq { 
	X.6.0   Other or undefined media error
	
	Something about the content of a message caused it to be
	considered undeliverable and the problem cannot be well
	expressed with any of the other provided detail codes.
	};
	
	$rfc1893{'X.6.1'} = qq { 
	X.6.1   Media not supported
	
	The media of the message is not supported by either the
	delivery protocol or the next system in the forwarding path.
	This is useful only as a permanent error.
	};
	
	$rfc1893{'X.6.2'} = qq { 
	X.6.2   Conversion required and prohibited
	
	The content of the message must be converted before it can
	be delivered and such conversion is not permitted.  Such
	prohibitions may be the expression of the sender in the
	message itself or the policy of the sending host.
	}; 
	
	$rfc1893{'X.6.3'} = qq { 
	X.6.3   Conversion required but not supported
	
	The message content must be converted to be forwarded but
	such conversion is not possible or is not practical by a
	host in the forwarding path.  This condition may result when
	an ESMTP gateway supports 8bit transport but is not able to
	downgrade the message to 7 bit as required for the next hop.
	};
	
	$rfc1893{'X.6.4'} = qq {          
	X.6.4   Conversion with loss performed
	
	This is a warning sent to the sender when message delivery
	was successfully but when the delivery required a conversion
	in which some data was lost.  This may also be a permanant
	error if the sender has indicated that conversion with loss
	is prohibited for the message.
	};
	
	$rfc1893{'X.6.5'} = qq {    
	X.6.5   Conversion Failed
	
	A conversion was required but was unsuccessful.  This may be
	useful as a permanent or persistent temporary notification.
	};
	
	$rfc1893{'X.7.0'} = qq {   
	X.7.0   Other or undefined security status
	
	Something related to security caused the message to be
	returned, and the problem cannot be well expressed with any
	of the other provided detail codes.  This status code may
	also be used when the condition cannot be further described
	because of security policies in force.
	};
	
	$rfc1893{'X.7.1'} = qq {  
	X.7.1   Delivery not authorized, message refused
	
	The sender is not authorized to send to the destination.
	This can be the result of per-host or per-recipient
	filtering.  This memo does not discuss the merits of any
	such filtering, but provides a mechanism to report such.
	This is useful only as a permanent error.
	};
	
	$rfc1893{'X.7.2'} = qq {  
	X.7.2   Mailing list expansion prohibited
	
	The sender is not authorized to send a message to the
	intended mailing list. This is useful only as a permanent
	error.
	};
	
	$rfc1893{'X.7.3'} = qq {  
	X.7.3   Security conversion required but not possible
	
	A conversion from one secure messaging protocol to another
	was required for delivery and such conversion was not
	possible. This is useful only as a permanent error.
	};
	
	$rfc1893{'X.7.4'} = qq {  
	A message contained security features such as secure
	authentication which could not be supported on the delivery
	protocol. This is useful only as a permanent error.
	};
	
	$rfc1893{'X.7.5'} = qq {  
	A transport system otherwise authorized to validate or
	decrypt a message in transport was unable to do so because
	necessary information such as key was not available or such
	information was invalid.
	};
	
	$rfc1893{'X.7.6'} = qq {  
	A transport system otherwise authorized to validate or
	decrypt a message was unable to do so because the necessary
	algorithm was not supported.
	};
	
	$rfc1893{'X.7.7'} = qq {  
	X.7.7   Message integrity failure
	
	A transport system otherwise authorized to validate a
	message was unable to do so because the message was
	corrupted or altered.  This may be useful as a permanent,
	transient persistent, or successful delivery code.
	};
	
	
	 return "\n" . '-' x 72 . "\n" . $rfc1893{$key} . "\n"; 	

}




sub default_cgi_template {


return q { 

     <p id="breadcrumbs">
        
           <!-- tmpl_var Program_Name --> 
    </p> 
 
		<!-- tmpl_unless plugin_configured --> 
		
			<div style="background:#fcc;margin:5px;padding:5px;text-align:center;border:2px #ccc dotted">
			  <h1>
			   Warning! <!-- tmpl_var Program_Name --> Not Configured!
			  </h1> 
	
			<p class="error">
			 You must set up the Bounce Handler Email Address in the plugin-specific configuration. 
			</p> 
	 		
			 </div>
		
		<!-- /tmpl_unless --> 
		
<fieldset> 
 <legend> 
Bounce Email Scorecard
 </legend> 
 
 <p>The bounce scorecard keeps track of addresses that bounce back messages sent to it. </p> 
 

<form action="<!-- tmpl_var Plugin_URL -->" method="get"> 
 <input type="hidden" name="flavor" value="cgi_scorecard" /> 

<div class="buttonfloat"> 
 <input type="submit" value="View The Bounce Scorecard..." class="cautionary" />
</div> 
<div class="floatclear"></div> 

</form>

 
</fieldset> 


<fieldset> 
 <legend>Manually Run <!-- tmpl_var Program_Name --></legend> 

<form action="<!-- tmpl_var Plugin_URL -->">

<input type="checkbox" name="test" id="test" value="bounces" /><label for="test">Only Test</label>

<p><label for="parse_amount">Review</label> <!-- tmpl_var parse_amount_widget --> Messages.</p>

<input type="hidden" name="flavor" value="cgi_parse_bounce" /> 
<div class="buttonfloat"> 

<input type="submit" class="cautionary" value="Parse Bounces..." />
</div> 

<div class="floatclear"></div> 

</form>

<p>
 <label for="cronjob_url">Manual Run URL:</label><br /> 
<input type="text" class="full" id="cronjob_url" value="<!-- tmpl_var Plugin_URL -->?run=1&verbose=1&passcode=<!-- tmpl_var Manual_Run_Passcode -->" />
</p>
<!-- tmpl_unless Allow_Manual_Run --> 
    <span class="error">(Currently disabled)</a>
<!-- /tmpl_unless -->


<p> <label for="cronjob_command">curl command example (for a cronjob):</label><br /> 
<input type="text" class="full" id="cronjob_command" value="<!-- tmpl_var name="curl_location" default="/cannot/find/curl" -->  -s --get --data run=1\;passcode=<!-- tmpl_var Manual_Run_Passcode -->\;verbose=0  --url <!-- tmpl_var Plugin_URL -->" />
<!-- tmpl_unless curl_location --> 
	<span class="error">Can't find the location to curl!</span><br />
<!-- /tmpl_unless --> 

<!-- tmpl_unless Allow_Manual_Run --> 
    <span class="error">(Currently disabled)</a>
<!-- /tmpl_unless --> 

</p>
</li>
</ul> 
</fieldset> 


<fieldset>
 <legend> 
  <!-- tmpl_var Program_Name --> Configuration</h1>
 </legend> 
 
 
 

<table cellpadding="5">
 <tr> 
  <td>
   <p><strong>Your Bounce Handler POP3 Username:</strong>
   </td> 
   <td> 
    <p><!-- tmpl_var Username --></p>
   </td> 
   </tr> 
   <tr> 
   <td>
    <p><strong>On:</strong>
    </p>
    </td>
    <td>
     <p>
      <!-- tmpl_var Server --></p>
   </td> 
   </tr> 
   
   
      <tr> 
   <td>
    <p><strong>"Soft" Bounce Score:</strong>
    </p>
    </td>
    <td>
     <p>
      <!-- tmpl_var  Default_Soft_Bounce_Score --></p>
   </td> 
   </tr> 
   
    
      <tr> 
   <td>
    <p><strong>"Hard" Bounce Score:</strong>
    </p>
    </td>
    <td>
     <p>
      <!-- tmpl_var  Default_Hard_Bounce_Score --></p>
   </td> 
   </tr>   
  

      <tr> 
   <td>
    <p><strong>Addresses Removed After a Score of:</strong>
    </p>
    </td>
    <td>
     <p>
      <!-- tmpl_var  Score_Threshold --></p>
   </td> 
   </tr>   
   
   
  </table> 
  
 <div class="buttonfloat"> 
 <form action="<!-- tmpl_var Plugin_URL -->"> 
  <input type="hidden" name="flavor" value="cgi_show_plugin_config" /> 
  <input type="submit" value="View All Plugin Configurations..." class="cautionary" /> 
 </form> 
 </div> 

<div class="floatclear"></div> 
  
</fieldset> 

<fieldset> 

<legend>Mailing List Configuration</legend>

<!-- tmpl_if send_via_smtp --> 

	<p>Mailing is being sent via: <strong>SMTP</strong>. 
	
	<!-- tmpl_if set_smtp_sender --> 
	
		<p>The SMTP Sender is being set to: <strong><!-- tmpl_var admin_email --></strong>. This should
		be the same address as the above <strong>Bounce Handler POP3 Username</strong></p> 
		
	<!-- tmpl_else --> 

		<p>The SMTP Sender has not be explicitly set.  Bounces may go to the list owner (<!-- tmpl_var list_owner_email -->) or to 
		a server default address.</p> 
	
	<!--/tmpl_if--> 
	
<!--tmpl_else--> 
	
	<p>Mailing is being sent via <strong>the sendmail command <!-- tmpl_if add_sendmail_f_flag -->'-f' flagged added<!--/tmpl_if--></strong>:</p>
	
	<blockquote>
	<p><em><!-- tmpl_var MAIL_SETTINGS --><!-- tmpl_if add_sendmail_f_flag --> -f<!--tmpl_var admin_email --><!--/tmpl_if--></em></p>
	</blockquote>

<!--/tmpl_if--> 
</legend> 


};

}




sub bounce_score_table { 

return q{ 
    
    
    
  <!-- tmpl_var PAGER_JAVASCRIPT -->
  
  <form>
  
<table cellpadding="2" cellspacing="0" border="0" width="100%">
<tr>
<td style="background:#fff"><p><strong>Email</strong></p>

<td style="background:#fff" width="30">
<p><strong>Score</strong></p>
</td>
</tr>

</table> 

   <div style="max-height: 400px; overflow: auto; border:1px solid black">
    <table cellpadding="2" cellspacing="0" border="0" width="100%">
     
    
    
 <!-- tmpl_loop PAGER_DATA_LIST -->
   
    
 
    
   <tr <!-- tmpl_if __odd__ -->style="background-color:#ccf;"<!--/tmpl_if-->>

    <td>
        <a href="<!-- tmpl_var PLUGIN_URL -->?flavor=cgi_bounce_score_search&amp;query=<!-- tmpl_var PAGER_DATA_COL_0 ESCAPE=URL -->"> 
         <!-- tmpl_var PAGER_DATA_COL_0 -->
        </a> 
      </td>
        
      <td  width="30">
       <!-- tmpl_var PAGER_DATA_COL_1 -->
     </td>
    </tr>
  <!-- /tmpl_loop -->
  
</table>

</div> 

    <table cellpadding="2" cellspacing="0" border="0" width="100%">

<tr>
   <td style="background:#DDD" colspan="3" align="center">
    <!-- tmpl_var PAGER_PREV -->
    <!-- tmpl_var PAGER_JUMP -->
    <!-- tmpl_var PAGER_NEXT -->
  </td>
 </tr>
 
 </table> 
 
<!-- tmpl_var PAGER_HIDDEN -->
  </form>
  
};

}


END { 

	$parser->filer->purge 
	    if $parser;
}

=pod

=head1 NAME

Mystery Girl - A Bounce Handler For Dada Mail

=head1 DESCRIPTION

Mystery Girl intelligently handles bounces from Dada Mail list messages.

Mystery Girl hooks into your Dada Mail mailing lists indirectly. You'll first need to create a new POP3 email address which will be used to send all bounces from the Dada Mail lists. This address is known as your B<Bounce Email Address> 

The login information for this account will be set in Mystery Girl.

This same address will also be set in the B<Return-Path> of messages sent by Dada Mail. Thus, when a message is bounced, it gets sent to this address, which is monitored by Mystery Girl. Hazzah.

Once Mystery Girl connects to this  POP3 acccount, awaiting messages are first B<read>, then, the message is B<parsed>, in an attempt to understand why the message has bounced. 

The parsed email will then be B<examined> and an B<action> will be taken. The examination and action are set in
a collection of B<rules>.  These rules can be tweaked, added, removed
and generally mucked about with. 

The usual action that is taken is to apply a, B<score> to the offending email address, everytime the address bounces back a message. Once the, B<Threshold> is reached, the email address is unsubscribed from the list. 

This usually means that it takes a few bounces from a particular email address to get it removed from a list. This gives a bit of wiggle room and makes sure an email address that is bouncing is bouncing for a fairly good reason, for example: it no longer exists. 

=head1 OBTAINING A COPY OF THIS PROGRAM

Mystery Girl is located in the, I<dada/plugins> directory of the main Dada Mail distribution, under the name, B<dada_bounce_handler.pl>

=head1 REQUIREMENTS

These points are absolutely necessary. Please make sure you have them before you try to install this plugin: 

=over

=item * Dada Mail 4

Basically, use the version of Mystery Girl that comes with the version of Dada 
Mail you're running. 

=item * A POP3 Email Account

Mystery Girl works by checking a bounce email address via the POP3 protocol. 

You will need to setup a new email address for Mystery Girl to check. I usually set up an account named, "bounces@yourdomain.com", where, "yourdomain.com" is the name of the domain Dada Mail is installed on. 

Some things to consider: 

=over

=item * Do NOT use this address for anything but Mystery Girl's functions

Meaning: don't periodically check it yourself via a mail reader. Doing so will not break Dada Mail, but it will stop Mystery Girl from working correctly. Why? Because sometimes checking a POP3 address will download the messages awaiting in the POP3 Inbox and remove them from this inbox. If you need to periodically check this inbox, make sure to have your mail reader set to B<not> automatically remove the mssages. 

=item * The email address MUST belong to the domain you have Dada Mail installed

Meaning, if your domain is, "yourdomain.com", the bounce email address should be something like, "bounces@yourdomain.com". In other words, do not use a Yahoo! Gmail, or Hotmail account for your bounce address. This will most likely disrupt all regular mail sending in Dada Mail. 

=item * Mystery Girl MUST be able to check the POP3 account

Sometimes, it can't - there may be a block for connections to port 110 from connections that come from your hosting account server.  

=back

=back

=head1 RECOMMENDED

These points are not required, but recommended to have to use Mystery Girl:

=over

=item * Ability to set Cron Jobs. 

Mystery Girl can be configured to run automatically by using a cron tab - In Other Words: a scheduled task. 

If you do not know how to set up a cron job, attempting to set one up for Dada Mail will result in much aggravation. Please read up on the topic before attempting! 

=item * Shell Access to Your Hosting Account

Shell Access is sometimes required to set up a cronjob, using the: 

 crontab -e 

command. You may also be able to set up a cron tab using a web-based control panel tool, like Cpanel. 

Shell access also facilitates testing of the program. 

=back

=head1 Lightning Configuration/Installation Instructions 

To get to the point: 

=over

=item * Create the bounce handler email account

=item * Set your list to use this address for its, "List Administrator Address" in the list control panel, under, Manage list - Change List Information.

=item * Open up the dada_bounce_handler.pl script in a text editor. 

=item * Set the POP3 server, username and password. Save. 

=item * Upload the dada_bounce_handler.pl script into the cgi-bin/dada/plugins directory

=item * chmod 755 the dada_bounce_handler.pl script

=item * run the plugin via a web browser. 

=item * Set the cronjob (optional)

=back

Below is the detailed version of the above: 


=head1 CONFIGURATION

There's a few things you need to configure in this script, they're all
at the top. 

=over

=item * POP3 server information. 

Your bounce email address login information is saved in the, B<dada_bounce_handler.pl> script itself - 

Create a new POP3 email account. This email account will be the address that
bounced messages will be directed towards. 

Change the following variables: 

=over

=item * $Plugin_Config->{Server}

=item * $Plugin_Config->{Username}

=item * $Plugin_Config->{Password}

=back

to reflect the permissions for the email address you're going to use
for the bounce handler. 

=back

As far as required changes, we are done. 

=head1 INSTALLATION

Mystery Girl acts like a Dada Mail plugin.  

Usually, you'll set up Dada Mail in your cgi-bin: in your cgi-bin, there's a directory called, "dada". Inside the, "dada" directory, there are at least two things, one called, "DADA" (uppercase) and the mail.cgi script. 

In the, "dada" directory, create a new directory called, "plugins". Upload the dada_bounce_handler.pl script, already configured, into this directory. Change its permissions to, "755".  Visit the script in your web browser - the URL will look something like this: 

	http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl

To run the bounce handler on your bounced messages, click the, B<Parse Bounces...> button. 


If you would like have a link on the left hand side of the list control panel, find the following line in the Config.pm: 

 #					{-Title      => 'Bounce Handler',
 #					 -Title_URL  => $PLUGIN_URL."/dada_bounce_handler.pl",
 #					 -Function   => 'dada_bounce_handler',
 #					 -Activated  => 1,
 #					},

And uncomment it (Take off the, "#" on each line). 

Mystery Girl is now installed. 

The last thing you will have to configure is your Dada Mail B<list administration email> address. 

=head2 Telling Dada Mail to use the Bounce Handler. 

You're going to have to tell Dada Mail explicitly that you want
bounces to go to the bounce handler. The first step is to set the 
B<Dada List Administrator> to your bounce email address. You'll set this per list in the each list's control panel, under B<Manage List - Change List Information>

After that, you'll need to configure outgoing email messages to set the B<Dada List Administrator> address in the C<Return-Path> header. Sounds scary, but it's easy enough.  

=head3 If you're using th sendmail command: 

In the list control panel, go to B<Mail Sending - Sending Preferences> and 
check: B<Add the Sendmail '-f' flag when sending messages ...>

This I<should> set the sending to the admin email, and in turn, set the
B<Return-Path> header. Dada Mail 3.0 is shipped to have this option set by default. 

=head3 If you're using SMTP sending: 

In the list control panel, go to: B<Sending Preferences - Sending Preferences>
and check the box labeled: B<Set the Sender of SMTP mailings to the 
list administration email address>  Dada Mail 3.0 is shipped to have this option set by default. 

=head2 Testing

To test out any of these configurations, Send yourself a test message
and view the source of the message itself, in your mail reader. In the
mail headers, you should see the B<Return-Path> header: 


 Return-Path: <dadabounce@myhost.com>
 Delivered-To: justin@myhost.com
 Received: (qmail 75721 invoked from network); 12 May 2003 04:50:01 -0000
 Received: from myhost.com (208.10.44.140)
   by hedwig.myhost.com with SMTP; 12 May 2003 04:50:01 -0000
 Date:Sun, 11 May 2003 23:50:01 -0500
 From:justin <justin@myhost.com>
 Subject:Test, Test, Test
 To:justin@myhost.com
 Sender:dadabounce@myhost.com
 Reply-To:justin <justin@myhost.com>
 Precedence:list
 Content-type:text/plain; charset=iso-8859-1

Notice that the first line has the B<Return-Path> header, correctly
putting my bounce email address. My List Owner address, 
justin@myhost.com still occupies the To: and Reply-To headers, so 
whoever replies to my message will reply to me, not the bounce handler.

Once you've dialed in your list to use the bounce handler, you should
be all set.

=head1 Configurating the Cronjob to Automatically Run Mystery Girl

We're going to assume that you already know how to set up the actual cronjob, 
but we'll be explaining in depth on what the cronjob you need to set B<is>.

=head2 Setting the cronjob

Generally, setting the cronjob to have Mystery Girl run automatically, just 
means that you have to have a cronjob access a specific URL. The URL looks something like this: 

 http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl?run=1&verbose=1

Where, L<http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl> is the URL to your copy of dada_bounce_handler.pl

You'll see the specific URL used for your installation of Dada Mail in the web-based control panel for Mystery Girl, under the fieldset legend, B<Manually Run Mystery Girl>, under the heading, B<Manual Run URL:>

This will have Mystery Girl check any awaiting messages. 

You may have to look through your hosting account's own FAQ, Knowledgebase and/or other docs to see exactly how you invoke a URL via a cronjob. 

A I<Pretty Good Guess> of what the entire cronjob should be set to is located 
in the web-based crontrol panel for Mystery Girl, under the fieldset legend, B<Manually Run Mystery Girl>, under the heading, B<curl command example (for a cronjob):>

From my testing, this should work for most Cpanel-based hosting accounts. 

Here's the entire thing explained: 

In all these examples, I'll be running the script every 5 minutes ( */5 * * * * ) - tailor to your taste.  

=over

=item * Using Curl: 

 */5 * * * * /usr/local/bin/curl -s --get --data run=1 --url http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl

=item * Using Curl, a few more options (we'll cover those in just a bit): 

 */5 * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0\;test=0\;messages=100 --url http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl

=back

=head3 $Plugin_Config->{Allow_Manual_Run}

If you B<DO NOT> want to use this way of invoking the program to check awaiting messages and send them out, make sure to change the variable, B<$Plugin_Config->{Allow_Manual_Run}> to, B<0>:

 $Plugin_Config->{Allow_Manual_Run}    = 0; 

at the top of the dada_bounce_handler.pl script. If this variable is not set to, B<1> this method will not work. 

=head3 Security Concerns and $Plugin_Config->{Manual_Run_Passcode}

Running the plugin like this is somewhat risky, as you're allowing an anonymous web browser to run the script in a way that was originally designed to only be run either after successfully logging into the list control panel, or, when invoking this script via the command line. 

If you'd like, you can set up a simple B<Passcode>, to have some semblence of security over who runs the program. Do this by setting the, B<$Plugin_Config->{Manual_Run_Passcode}> variable in the dada_bounce_handler.pl source itself. 

If you set the variable like so: 

    $Plugin_Config->{Manual_Run_Passcode} = 'sneaky'; 

You'll then have to change the URL in these examples to: 

 http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl?run=1&passcode=sneaky

=head3 Other options you may pass

You can control quite a few things by setting variables right in the query string: 

=over

=item * passcode

As mentioned above, the B<$Plugin_Config->{Manual_Run_Passcode}> allows you to set some sort of security while running in this mode. Passing the actual password is done in the query string: 

 http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl?run=1&passcode=sneaky

=item * messages

Overrides B<$Plugin_Config->{MessagesAtOnce}>. States how many messages should be checked and parsed in one execution of the program. Example: 

  http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl?run=1&messages=10

=item * verbose

By default, you'll receive the a report of how Mystery Girl is doing parsing and adding scores (and what not). This is sometimes not so desired, especially in a cron environment, since all this informaiton will be emailed to you (or someone) everytime the script is run.  You can run Mystery Girl with a cron that looks like this: 

 */5 * * * * /usr/local/bin/curl -s --get --data run=1 --url http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl >/dev/null 2>&1

The, C<E<gt>/dev/null 2E<gt>&1> line throws away any values returned. 

Since B<all> the information being returned from the program is done sort of indirectly, this also means that any problems actually running the program will also be thrown away. 

If you set B<verbose> to, "0", under normal operation, Mystery Girl won't show any output, but if there's a server error, you'll receive an email about it. This is probably a good thing. Example: 

 * * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0 --url http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl

=item * test

Runs Mystery Girl in test mode by checking the bounces and parsing them, but not actually carrying out the Rules. 

=back

=head3 Notes on Setting the Cronjob for curl 

You may want to check your version of C<curl> and see if there's a speific way to pass a query string. For example, this: 

 */5 * * * * /usr/local/bin/curl -s http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl?run=1&passcode=sneaky

Doesn't work for me. 

I have to use the C<--get> and C<--data> flags, like this: 

 */5 * * * * /usr/local/bin/curl -s --get --data run=1\;passcode=sneaky --url http://example.com/cgi-bin/dada/plugins/dada_bounce_handler.pl

my query string is this part: 

 run=1\;passcode=sneaky

And also note I had to escape the, B<;> character. You'll probably have to do the same for the B<&> character. 

Finally, I also had to pass the actual URL of the plugin using the B<--url> flag. 

=head1 Command Line Interface

There's a slew of optional arguments you can give to this script. To use Mystery Girl via the command line, first change into the directory that Mystery Girl resides in, and issue the command: 

 ./dada_bounce_handler.pl --help

For a full list of paramaters. 

One of the reasons why you may want to run Mystery Girl via the command line is to set the cronjob via the command line interface, rather than the web-based way. Fair enough!

=head2 Command Line Interface for Cronjobs: 

One reason that the web-based way of running the cronjob is better, is that it 
doesn't involve reconfiguring the plugin, every time you upgrade. This makes 
the web-based invoking a bit more convenient. 

=head3 #1 Change the lib path

You'll need to explicitly state where both the:

=over

=item * Absolute Path to the site-wide Perl libraries

=item * Absolute Path of the local Dada Mail libraries

=back

I'm going to rush through this, since if you want to run Mystery Girl this way
you probably know the terminology, but: 

This script will be running in a different environment and from a different location than what you'd run it as, when you visit it in a web-browser. It's annoying, but one of the things you have to do when running a command line script via a cronjob. 

As an example: C<use lib qw()> lines probably look like: 

 use lib qw(
 
 ../ 
 ../DADA/perllib 
 ../../../../perl 
 ../../../../perllib 
 
 );


To this list, you'll want to append your site-wide Perl Libraries and the 
path to the Dada Mail libraries. 

If you don't know where your site-wide Perl libraries are, try running this via the command line:

 perl -e 'print $_ ."\n" foreach @INC'; 

If you do not know how to run the above command, visit your Dada Mail in a web browser, log into your list and on the left hand menu and: click, B<About Dada Mail> 

Under B<Script Information>, click the, B< +/- More Information> link and under the, B<Perl Library Locations>, select each point that begins with a, "/" and use those as your site-wide path to your perl libraries. 


=head2 #2 Set the cron job 

Cron Jobs are scheduled tasks. We need something to check your POP3 email account quite a bit. We're going to set a cron job to test for new messages every 5 minutes. Here's an example cron tab: 

  */5  *  *  *  * /usr/bin/perl /home/myaccount/cgi-bin/dada/plugins/dada_bounce_handler.pl >/dev/null 2>&1

Where, I</home/myaccount/cgi-bin/dada/plugins/dada_bounce_handler.pl> is the full path to the script we just configured. 

=head1 How Mystery Girl Works

Once you've set up and installed Mystery Girl correctly, bounced email messages 
now been set to be delivered to the email address that Mystery Girl checks - 
that is, the, C<Return-Path> header has been set to the B<Bounce Email Address>,
 which is also the address set for your B<List Admin Email Address>. 

When Mystery Girl checks each bounced email message, it'll attempt to figure 
out the severity of the bounce and score the email address belonging to the 
subscriber accordingly. 

=head2 Mystery Girl's Web-Based Control Panel

There's a few things you may also do in Mystery Girl's own control panel: 

=head3 Bounce Email Scorecard

You can view the bounce email scorecard - the scores that Mystery Girl gives
to email addresses that are currently bouncing and haven't been unsubscribed
yet. 

Selecting an email address (and clicking it) will give you a rundown of the 
bounce report for each bounce the email address creates. 

=head3 Manually Run Mystery Girl

If you like, you can run Mystery Girl whenever you like. Running Mystery Girl 
this way is a good way to see if everything is working correctly and give you 
an insight of how it all works. 

=head3 Mystery Girl Configuration

View how Mystery Girl is configured. 




=head1 Advanced Configuration: Rules, Rule! 

dada_bounce_handler.pl figures out what to do with the bounce messages
receives by consulting a group of rules. These rules are highly configurable, 
so if you need to change the behavior of this script, you don't have to 
change the code. 


These rules are stored in the B<$Plugin_Config-\>{Rules}> hashref. An example rule:

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
                     add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score},
                }, 
            }
    }, 

B<exim_user_unknown> is the title of the rule -  just a label, nothing else.

B<Examine> holds a set of parameters that the handler looks at when
trying to figure out what to do with a bounced message. This example
has a B<Message_Fields> entry and inside that, a B<Status> entry. The
B<Status> entry holds a list of status codes. The ones in shown there
all correspond to hard bounces; the mailbox probably doesn't exist. B<Message_Fields> also hold a, B<Guessed_MTA> entry - it's explicitly looking for a bounce back from the, I<Exim> mail server. 


B<Examine> also holds a B<Data> entry, which holds the B<Email> or B<List> 
entries, or both. Their values are either 'is_valid', or 'is_invalid'. 

So, to sum this all up, this rule will match a message that has B<Status:> 
B<Message Field> contaning a user unknown error code, B<(5.1.1, etc)> and also a B<Guessed_MTA> B<Message Field> containing, B<Exim>. The message
also has to be parsed to have found a valid email and list name. 

Pretty Slick, eh? 

If this all matches, the B<Action> is... acted upon. In this case, the offending email address will be appended a, B<Bounce Score> of, whatever, B<$Plugin_Config->{Default_Hard_Bounce_Score}>, which is by default, B<4>. 

If you would like to have the bounced address automatically removed, without any sort of scoring happening, change the B<action> from,

    add_to_score => $Plugin_Config->{Default_Hard_Bounce_Score}

to: 

    unsubscribe_bounced_email => 'from_list'

Also, changing B<from_list>, to B<from_all_lists> will do the trick. 

I could change the line: 

 unsubscribe_bounced_email => 'from_list', 

to: 

 mail_list_owner => 'user_unknown_message'

This will, instead of deleting the email automatically, send a message 
to the list owner, stating that, "Hey, the message bounced, what do you
want to do?" 

Another example: 

 {
 over_quota => {
	 Examine => {
		Message_Fields => {
			Status => [qw(5.2.2)]
		},
		Data => { 
			Email => 'is_valid', 
			List  => 'is_valid',
		}
	},
	Action => { 
		mail_list_owner => 'over_quota_message', 
	},
 }                    

This time, I created a list for messages that get bounced because the
mailbox is full. This is still considered a hard bounce, but I don't
want the subscriber removed because they haven't check their inbox 
during the week. In this case, the B<Action> has been set to: 

 mail_list_owner => 'over_quota_message', 

Which will do what it sounds like, it'll mail the list owner a message
explaining the circumstances. 

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
			   mail_list_owner           => 'user_unknown_message', 
			   mail_list_owner           => 'email_not_found_message', 
			   mail_list_owner           => 'over_quota_message', 
			   unsubscribe_bounced_email => 'from_list' | 'from_all_lists',
	},
 },	

Mystery Girl also supports the use of regular expressions for matching any of the B<Message_Fields>. To tell the parser that you're using a regular expression, make the Message_Field key end in '_regex': 

 'Final-Recipient_regex' => [(qr/RFC822/)], 

Setting rules is sort of the super advanced part of the configuration,
but it may come in handy. 

=head1 More on Scores, Thresholds, etc

We talked about scoring, but not in great detail, so let's do that: 

By default, The Bounce Handler assigns a particular score to each email address that bounces back a message. These scores are tallied each time an email address bounces a message.

Since Dada Mail understands the differences between B<Hard Bounces> and B<Soft Bounces>, it'll append a smaller score for soft bounces, and a larger score for hard bounces. 

Once the email address's B<Bounce Score> reaches the B<Threshold>, the email address is then removed from the list. 

You can manipulate the Soft and Hard Bounce Scores and Threshold pretty easily. On the top of this script, you'll see the necessary variables to tweak, 

=over

=item * $Plugin_Config->{Default_Soft_Bounce_Score}

=item * $Plugin_Config->{Default_Hard_Bounce_Score}

=item * $Plugin_Config->{Score_Threshold}

=back

Fairly self-explanitory. 

If you want even greater control over what kind of bounces give what scores, you can manipulate the B<Bounce Rules> themselves, as described above. 

Some things to understand: 

If you would like to periodically erase the saved scores, you may do so, by running this script via the command line, like so: 

    ./dada_bounce_handler.pl --erase_score_card


=head1 FAQs

=over

=item * Does the bounce handler differentiate between "hard' bounces and 'soft' bounces?

Yes. Because of the Rules, you can set what happens, depending on what 
type of bounce you receive. By default, the bounce handler is set up to think, "hard bounces" are email addresses that 
are  invalid because they simply don't exist, and
soft bounces as email addresses that because the email box
is full, or there was some sort of problem actually sending the message to the subscriber. 

Dada Mail basically works by saying, I<After x amount of bounces, just remove from the list.>

=item * I keep getting, 'permission denied' errors, what's wrong?

It's very possible that Mystery Girl can't read your subscription database or the list settings database. This is because Dada Mail may be running under the webserver's username, usually, B<nobody>, and not what Mystery Girl is running under, usually your account username. 

You'll need to do a few things: 

=over

=item * Change the permissions of the list subscription and settings databases

You'll most likely need to change the permissions of these files to, '777'. PlainText subscription databases have the format of B<listshortname.list> and are usually located where you set the B<$FILES> Config file variable. .List settings Databases have the format of B<mj-listshortname> and are usually located in the same location.


=item * Change the $FILE_CHMOD variable

So you don't need to change the permissions of the list files for every new list you create, set the $FILE_CMOD Config variable to 0777:
	
 $FILE_CHMOD = 0777; 

Notice there are no quotes around 0777. 

=back

=item * The program is working great; but bounces aren't being handled at all

Make sure that you have checked, B<Print list-specific headers in all list emails> in Mail Sending - Advanced Sending Preferences>. Mystery Girl uses the I<List> 
header to figure out what list the bounce is coming from.

=item * I found a bug in this program, what do I do? 

Report it to the bug tracker: 

http://sourceforge.net/tracker/?group_id=13002&atid=113002

=item * I keep getting this bounced message, but Mystery Girl isn't handling it, what do I do? 

You'll most likely have to make a new rule for it. If you want, attach a copy of the bounced message to the bug tracker: 

http://sourceforge.net/tracker/?group_id=13002&atid=113002

And we'll see if we can't get that kind of bounce in a new version.

=item * What's up with the name, Mystery Girl?

It's from a I<Yeah Yeah Yeahs> song: B<Mystery Girl>. A bounce handler
is sort of a mysterious tool, making decisions for you and a mysterious
girl just seems to be one full of power and allusion. The song itself 
is about rejecting a guy that just doesn't make it anymore, 
so that gives a good metaphor to  a bounced mail, in a slightly weird, 
nerdy, nerdy, nerdy... artsy way.   

When the bounce handler emails a list owner, you can do nothing but
answer back to it. Yeah Yeah Yeah. 

B<(colophon)> 

Actually, the lyrics I'm thinking of aren't from the song, Mystery Girl, 
but from the song, "Bang!" off of the YYY's self titled release. Mystery Girl
is the next song on that album.  The song after that is one called,
"Art Star", which is what I am in the daytime! The next song is 
called, "Miles Away", which is where you probably are to me. All this
in, "Our Time" (the last song) See? it's like this was all written in
the stars. 

http://yeahyeahyeahs.com

Here's a small clip of the YYY's performing "Mystery Girl" at the Gothic on 11.20.03 that I took: 

http://dadamailproject.com/media/YYYs_Mystery_Girl_Clip.mov

hot!

=back


=head1 Thanks

Thanks to: Jake Ortman Henry Hughes for some prelim bounce examples.

Thanks to Eryq ( http://www.zeegee.com ) for the amazing MIME-tools
collection. It's a gnarly group of modules. 

=head1 COPYRIGHT

Copyright (c) 1999-2009 Justin Simoni 
http://justinsimoni.com 
All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Parts of this script were swiped from Mail::Bounce::Qmail module, fetched from here: 

http://mikoto.sapporo.iij.ad.jp/cgi-bin/cvsweb.cgi/fmlsrc/fml/lib/Mail/Bounce/Qmail.pm

The copyright of that code stated: 

Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi
All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

Thanks Ken'ichi

=cut
