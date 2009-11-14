package DADA::App::Messages; 

use lib qw(../../ ../../perllib); 

use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 

use Carp qw(croak carp cluck); 

require Exporter; 
@ISA = qw(Exporter); 

@EXPORT = qw(
send_generic_email

send_confirmation_message
send_unsub_confirmation_message

send_unsubscribed_message
send_subscribed_message

send_owner_happenings
send_newest_archive

send_you_are_already_subscribed_message

); 

use strict; 
use vars qw(@EXPORT); 



sub send_generic_email { 

	my ($args) = @_; 
	
	if(! exists($args->{-test})){ 
		$args->{-test} = 0;
	}
		
	my $ls   = undef; 
	my $li   = {}; 

	
	if(exists($args->{-list})){ 		
		if (! exists($args->{-ls_obj})){
			require DADA::MailingList::Settings; 
			$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
		}
		else { 
			$ls = $args->{-ls_obj};
		}
		$li = $ls->get;
	}
	
	my $expr = 0; 	
	if($li->{enable_email_template_expr} == 1){ 
		$expr = 1;
	}
	
	if(!exists($args->{-headers})){ 
		$args->{-headers} = {}; 
	}
	if(!exists($args->{-headers}->{To})){ 
		$args->{-headers}->{To} = $args->{-email};
	}
	
	if(!exists($args->{-tmpl_params})){ 
		if(exists($args->{-list})){ 
			$args->{-tmpl_params} = 
				{
					-list_settings_vars_param => 
						{
							-list => $args->{-list}
						}
					}, # Dev: Probably could just pass $ls? 
		}
		else { 
			$args->{-tmpl_params} = {};
		}
	}	
	
	my $data = { 
					%{$args->{-headers}},
					Body => $args->{-body},
			   }; 
			
	require DADA::App::FormatMessages; 
	my $fm = undef; 
	if(exists($args->{-list})){ 
		$fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
   	}  
	else { 
		$fm = DADA::App::FormatMessages->new(-yeah_no_list => 1); 		
	}
	$fm->use_header_info(1);
	$fm->use_email_templates(0);	
			
	my ($email_str) = $fm->format_message(
                            -msg => $fm->string_from_dada_style_args(
                                        {
                                            -fields => $data,
                                        }
                                    ) 
                       );

    my $entity = $fm->email_template(
        {
            -entity => $fm->get_entity({-data => $email_str}),
  			-expr   => $expr, 
			%{$args->{-tmpl_params}},
        }
    );

    my $msg = $entity->as_string; 
    my ($header_str, $body_str) = split("\n\n", $msg, 2);
	
	require DADA::Mail::Send;  
	my $mh = DADA::Mail::Send->new(
				{
					(
						exists($args->{-list})
					) ? ( 
						-list   => $args->{-list}, 
						-ls_obj => $ls,
					) : 
					(
					), 
				}
			); 
				
	if($args->{-test} == 1){ 
		$mh->test(1);	
	}
	
	$mh->send(
	   $mh->return_headers($header_str), 
	   Body => $body_str,
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
		my $li = $ls->get; 
	####
	
	send_generic_email(
		{
			-list    => $args->{-list}, 
			-headers => { 
				To              => '"<!-- tmpl_var list_settings.list_name --> Subscriber" <' . $args->{-email} . '>',
			    Subject         => $li->{confirmation_message_subject},
			}, 
			
			-body => $li->{confirmation_message},
				
			-tmpl_params => {
				-list_settings_vars_param => {-list => $args->{-list}},
	            -subscriber_vars_param    => {-list => $args->{-list}, -email => $args->{-email}, -type => 'sub_confirm_list'},
	            -vars                     => {
	                                            'subscriber.pin' => make_pin(
																	-Email => $args->{-email}, 
																	-List  => $args->{-list}
																	),
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
	my $li    = $ls->get; 

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($li->{list_name}) .'" <'. $args->{-email} .'>',
					Subject => $li->{subscribed_message_subject},
			}, 
			-body         => $li->{subscribed_message},
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $li->{list},},
				-subscriber_vars_param    => {-list => $li->{list}, -email => $args->{-email}, -type => 'list'},
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
	my $li    = $ls->get; 

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($li->{list_name}) .'" <'. $args->{-email} .'>',
					Subject => $li->{subscription_request_approved_message_subject},
			}, 
			-body         => $li->{subscription_request_approved_message},
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $li->{list},},
				-subscriber_vars_param    => {-list => $li->{list}, -email => $args->{-email}, -type => 'list'},
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
	my $li    = $ls->get; 

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($li->{list_name}) .'" <'. $args->{-email} .'>',
					Subject => $li->{subscription_request_denied_message_subject},
			}, 
			-body         => $li->{subscription_request_denied_message},
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $li->{list},},
				#-subscriber_vars_param    => {-list => $li->{list}, -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				#-vars => $args->{-vars}, 
				-vars => { 
					'subscriber.email' => $args->{-email}, 
					%$args->{-vars},
				}
			},
			-test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}





sub send_unsub_confirmation_message { 

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
		my $li = $ls->get; 
	####
	
	send_generic_email(
		{	
		-list        => $args->{-list},
		-ls_obj      => $ls,   
		-headers     => 
			{
					 To      =>  '"'. escape_for_sending($li->{list_name}) .'"  <' . $args->{-email} . '>',
					 Subject =>  $li->{unsub_confirmation_message_subject}, 
			},
				
	    -body        => $li->{unsub_confirmation_message}, 
		-tmpl_params => {
			-list_settings_vars_param => {-list => $args->{-list}},
            -subscriber_vars_param    => {-list => $args->{-list}, -email => $args->{-email}, -type => 'list'},
            -vars                     => {
                                            'subscriber.pin'  => make_pin(-Email => $args->{-email}, -List => $args->{-list}), #DEV: do I need this?
                                         },
										
			},
			-test         => $args->{-test},
		}
	); 
	
    require DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;
       $log->mj_log($args->{-list}, 'Unsubscription Confirmation Sent for ' . $args->{-list} . '.list', $args->{-email});     
 
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
	my $li    = $ls->get; 

	send_generic_email(
		{

			-list        => $args->{-list},
			-ls_obj      => $ls,
			-email       => $args->{-email}, 
			-headers => { 	
				To           => '"<!-- tmpl_var list_settings.list_name -->" <' . $args->{-email} . '>',
				Subject      => $li->{unsubscribed_message_subject}, 
			},
			-body    => $li->{unsubscribed_message},

			-test         => $args->{-test}, 
			
			-tmpl_params  => {	
				-list_settings_vars       => $li, 
				-list_settings_vars_param => 
					{
						-dot_it => 1, 
					}, 
				-subscriber_vars => {'subscriber.email' => $args->{-email}}, # DEV: This line right?
			},
		}
	); 
	
	# DEV: Logging?
}









sub send_owner_happenings { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
	my $li    = $ls->get;
	
	my $status  = $args->{-role};
	 
	if(!exists($args->{-note})){ 
		$args->{-note} = ''; 
	}
	
	
	my $send_it = 1; 
	
	if($status eq "subscribed"){  
	   if(exists($li->{get_sub_notice})){ 
		 if($li->{get_sub_notice} == 0){         
			$send_it = 0; 
			}
		 }   
	   }elsif($status eq "unsubscribed"){  
		if(exists($li->{get_unsub_notice})){ 
		  if($li->{get_unsub_notice} == 0){ 
			$send_it = 0; 
		   }
		}   
	  } 
		
	if($send_it == 1){ 
		
		my $lh; 
		if($args->{-lh_obj}){ 
			$lh = $args->{-lh_obj};
		}
		else { 
			$lh = DADA::MailingList::Subscribers->new({-list => $args->{-list}}); 
		}
		
		my $num_subscribers = $lh->num_subscribers;   
		
		send_generic_email(
			{ 
				-list => $args->{-list}, 
				-headers => {
					'Reply-To'     => $args->{-email}, 
				    To             =>  '"' . escape_for_sending($DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE_TO_PHRASE) . '" <' . $li->{list_owner_email} . '>', 
				    Subject        =>  $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE_SUBJECT,
				},
				-body => $DADA::Config::SUBSCRIPTION_NOTICE_MESSAGE, 
				
				-tmpl_params => { 
					-list_settings_vars_param => {-list => $args->{-list}}, 

		            -vars                     => {
		                                        num_subscribers => $num_subscribers,
		                                        status          => $status, 
		                                        note            => $args->{-note}, 
		                                        REMOTE_ADDR     => $ENV{REMOTE_ADDR}, 

		                                     },

					($status eq "subscribed") ? (
		            	-subscriber_vars_param    => {-list => $args->{-list}, -email => $args->{-email}, -type => 'list'},
				    ) : (
						-subscriber_vars          => {'subscriber.email' => $args->{-email}},
					)
				},
				-test => $args->{-test}, 
			}
		); 

	# Logging?

	} # if($send_it == 1){ 

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
	my $li    = $ls->get;
		
	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
        
		-headers => { 
			To           => '"'. escape_for_sending($li->{list_name}) .' Subscriber" <'. $args->{-email} .'>',
			Subject      => $li->{you_are_already_subscribed_message_subject}, 
		},
		
		-body         => $li->{you_are_already_subscribed_message}, 
		
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $li->{list},},
			-subscriber_vars_param    => {-list => $li->{list}, -email => $args->{-email}, -type => 'list'},
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
		my $li = $ls->get; 
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
	
	# Debug Code...	
	#	my %hh = $mh->return_headers($head); 
	#	foreach(keys %hh){ 
	#		warn 'header: ' . $_ . ' ' . $hh{$_}; 
	#	}
		
		
		# And anyways, this isn't doing any templating.... yeesh...
		#
		#$mh->send(
		#		 $mh->return_headers($head), 
		#	  	 # Um, ok, what was this here for again? 
		#		 #'Content-type' => 'text/plain', 
		#		 #/Um, 
		#	  	 To             => '"'. escape_for_sending($li->{list_name}) .' Subscriber" <'. $args->{-email} .'>',
		#		 Body           => $body, 
		#);
		
		
		send_generic_email(
			{
	    	-list         => $args->{-list}, 
	        -email        => $args->{-email}, 
	        -ls_obj       => $ls, 

			-headers => { 
						 $mh->return_headers($head), 
					  	 # Um, ok, what was this here for again? 
						 #'Content-type' => 'text/plain', 
						 #/Um, 
					  	 To             => '"'. escape_for_sending($li->{list_name}) .' Subscriber" <'. $args->{-email} .'>',
			},

			-body         => $body, 

			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $li->{list},},
				-subscriber_vars_param    => {-list => $li->{list}, -email => $args->{-email}, -type => 'list'},
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



# This one's weird, since it's a part of Dada Bridge 

sub send_not_allowed_to_post_message { 
	
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
	my $li    = $ls->get;

	my $attachment;
	if(!exists($args->{-attachment})){ 
		croak "I need an attachment in, -attachment!"; 
	}
	else { 
		$attachment = $args->{-attachment}; 
	}
	

	my $reply = MIME::Entity->build(Type 	=> "multipart/mixed", 
									Subject => $li->{not_allowed_to_post_message_subject}, 									
									%{$args->{-headers}},
									To           => '"'. escape_for_sending($li->{list_name}) .'" <'. $args->{-email} .'>',
									);
									
	$reply->attach(Type => 'text/plain', 
				   Data  => $li->{not_allowed_to_post_message}
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
			#-subscriber_vars_param    => {-list => $li->{list}, -email => $args->{-email}, -type => 'list'},
			-subscriber_vars => 
				{
					'subscriber.email' => $args->{-email}
				},
		},

		-test         => $args->{-test}, 
		}
	);

}




sub _mime_headers_from_string { 

	#get the blob
	my $header_blob = shift || "";


	#init a new %hash
	my %new_header;

	# split.. logically
	my @logical_lines = split /\n(?!\s)/, $header_blob;
 
	    # make the hash
	    foreach my $line(@logical_lines) {
	          my ($label, $value) = split(/:\s*/, $line, 2);
	          $new_header{$label} = $value;
	        }
		
	return %new_header; 

}


1;


=pod

=head1 COPYRIGHT 

Copyright (c) 1999-2009 Justin Simoni All rights reserved. 

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

