package DADA::Mail::Send;
use strict; 

use lib qw(../../ ../../DADA/perllib); 

use Fcntl qw(
	LOCK_SH
	O_RDONLY
	O_CREAT
);
 
my $dbi_obj; 

use DADA::Config qw(!:DEFAULT);  

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Mail_Send}; 

use DADA::Logging::Usage;
my $log =  new DADA::Logging::Usage;;

use DADA::App::Guts; 
		
use vars qw($AUTOLOAD); 
use Carp qw(croak carp);
   #$Carp::Verbose = 1; 

use Try::Tiny; 

use Fcntl qw(
	:DEFAULT 
	:flock
	O_WRONLY
	O_TRUNC
	O_CREAT
	LOCK_EX
);

my %allowed = (
	
	list                          => undef, 
	list_info                     => {},
	ls                            => undef, 
	list_type                     => 'list',
	
	mass_mailing_params           => {-delivery_preferences => 'individual'},
	
	mass_test                     => 0,
	
	# used anymore? 
	do_not_send_to                => [],
	ignore_schedule_bulk_mailings => 0, 
	saved_message                 => undef, 
	
	also_send_to                  => [], 
	im_mass_sending               => 0, 
	
	num_subscribers               => undef, 
	
	restart_with                  => undef, 
	
	# This is some ninja stuff...
	test_send_file                => $DADA::Config::TMP . '/test_send_file.txt',  
	test                          => 0, 
	test_return_after_mo_create   => 0, 
	
	partial_sending               => {}, 
	multi_list_send               => {}, 
	
	exclude_from                  => [],
	
	net_smtp_obj                  => undef, 
	ses_obj                       => undef, 
	#unsub_obj                     => undef, 
	
	child_ct_obj                  => undef, 
	
); 

my %defaults        = %DADA::Config::EMAIL_HEADERS;
my @default_headers = @DADA::Config::EMAIL_HEADERS_ORDER; 
			   

sub new { 
	my $that = shift; 
	my $class = ref($that) || $that; 
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	bless $self, $class;
	
	my ($args) = @_; 
		
	$self->{list} = undef; 
	
	if(exists($args->{-list})){ 
		if(!exists($args->{-ls_obj})){ 
			require DADA::MailingList::Settings; 
			my $ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
			$self->{ls} = $ls; 
		
			# This really stinks - I need it for the domain sending tunings... grr!
			$self->{list_info} = $ls->get; 
		}
		else {
		
			$self->{ls} = $args->{-ls_obj};
		
		}
	
		$self->{list} = $args->{-list};
	}
	$self->_init($args); 
	
	return $self; 
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
    $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init { 
	
	my $self   = shift; 
	my ($args) = @_; 
	$self->{mj_log} = $log;
	
	if(defined($args->{-list})){ 
			
		if($self->{list_info}->{use_domain_sending_tunings} == 1) { 
	    #if($self->{ls}->param('use_domain_sending_tunings') == 1) { 
    
	        if($self->{ls}->param('domain_sending_tunings')) { 
        
	            my $tunings = eval($self->{ls}->param('domain_sending_tunings')); 
	            my $lookup_tunings = {}; 
            
	            # let's make this into an easier-to-look-up-format: 
            
	            for my $tune(@$tunings){ 
	                if($tune->{domain}){ # only real thingy needed...
	                    $lookup_tunings->{$tune->{domain}} = {};
	                    for my $in_tune(keys %$tune){ 
	                       # next if $in_tune eq 'domain'; 
	                        $lookup_tunings->{$tune->{domain}}->{$in_tune} = $tune->{$in_tune}; 
	                    }
	                }
	            }
            
	            $self->{domain_specific_tunings} = $lookup_tunings; 
	        }
	    }
    
	
        require DADA::MailingList::Subscribers; 
        my $lh = DADA::MailingList::Subscribers->new(
			{
				-list => $self->{list}
			}
		);
        my $merge_fields = $lh->subscriber_fields;
				
        $self->{merge_fields} = $merge_fields;
		
			
			require DADA::ProfileFieldsManager; 
			my $pfm = DADA::ProfileFieldsManager->new; 
        	$self->{field_attr} = $pfm->get_all_field_attributes(); 
       		undef $lh; 
			undef $pfm;
	}
 }






 
sub return_headers { 
my $self = shift; 

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






sub clean_headers { 
	my $self = shift; 
	my %mail_headers = @_; 
	

    if((exists($mail_headers{'Content-Type'})) && (strip($mail_headers{'Content-Type'}) ne "")){ 
        $mail_headers{'Content-type'} = $mail_headers{'Content-Type'};  
        delete($mail_headers{'Content-Type'});
    }
	
	if( defined($mail_headers{'Content-transfer-encoding'}) &&  strip($mail_headers{'Content-transfer-encoding'}) ne ''){ 
        $mail_headers{'Content-Transfer-Encoding'} = $mail_headers{'Content-transfer-encoding'};
	    delete($mail_headers{'Content-transfer-encoding'});
    } 
    
    
	
	$mail_headers{'Content-Base'} = $mail_headers{'Content-base'} 
		if defined $mail_headers{'Content-base'};
	$mail_headers{'Cc'} = $mail_headers{'CC'} 
		if defined $mail_headers{'CC'};
	for(keys %mail_headers){ 
		my $tmp_h = $mail_headers{$_};
		   if($tmp_h){ 
			   $tmp_h =~ s/\n$//;
			   $mail_headers{$_} = $tmp_h;
		   }
	}
	
	delete($mail_headers{'X-Mailer}'})
		if exists $mail_headers{'X-Mailer}'};
	
	return %mail_headers; 
}





sub send {

    require Email::Address;
	my $self = shift; 

	

	my %param_headers = @_; 
	if($self->im_mass_sending == 1){ 
		# ... 
	}
	else { 
		# This is done in mass_send, already. 
		# DEV: This will just be generally, well, chatty. 
		# DEV: This needs to be cleaned up;
		no strict;
		for(keys %param_headers){
			if(strip($param_headers{$_}) eq ''){ 
				delete($param_headers{$_}); 
			}
		}
		use strict;
		#/ DEV: This will just be generally, well, chatty. 
	}
 
	
	
	my %fields = (); 
	if($self->im_mass_sending == 1){ 
		%fields = %param_headers;
	}
	else {     
		%fields = ( 
				  %defaults,  
				  $self->_make_general_headers, 
				  $self->list_headers, 
				   %param_headers, 
				); 
	}
	undef(%param_headers); 

	# Here's the thing - 
    # If there's no Content-Transfer-Encoding header, 
    # We should *really* make one, since it's what we 
    # say we do. 

	 %fields = $self->clean_headers(%fields);

    # I don't like this, but, eh.
    if(
	   ! exists($fields{'Content-type'}) || 
       length(strip($fields{'Content-type'})) == 0
       ){
    
		#carp "did you not set a content-type? (here's what I got:)" . $fields{'Content-type'};

         $fields{'Content-type'} = 'text/plain'; 
    } 
    else {
    
      #  croak "Content-type: '" . $fields{'Content-type'} . "'";
    }
    
    if(
        (
         ! exists ($fields{'Content-Transfer-Encoding'}) 
		||
         ! defined($fields{'Content-Transfer-Encoding'}) 
        )   &&
       
        $fields{'Content-type'} =~ m/(text\/plain|text\/html)/i 
    ){ 
    
        %fields = $self->_content_transfer_encode(
            -fields => \%fields, 
        ); 
 
    }
    
     %fields = $self->clean_headers(%fields); 


	# DEV: I'm setting the date here, since somewhere the date is being rewritten *Somewhere* 
	# DEV: I should also be using Email::Date::Format, instead of something I ripped out of Mail::Bulkmail - no?
	$fields{Date} = $self->_Date; 
	
    # This makes a local copy of the list settings.
    # only use {list_info} for domain sending tunings (grrr!)
	my $local_li = {};
	# This is kinda wasteful. 
	
	# I almost wish this was done once on object initialization... 
	if(defined($self->{list})){ 
		for(keys %{$self->{ls}->params}){ 
			if(exists($DADA::Config::LIST_SETUP_DEFAULTS{$_})){ 
		    	$local_li->{$_} = $self->{ls}->param($_); 
			}
		}
	
		# This copies over domain-specific tunings for sending...
		my ($email_address, $email_domain) = split('@', $fields{To});
		# damn that's weird.
	
		if($self->{ls}->param('use_domain_sending_tunings') == 1) { 
		
	        if($self->{domain_specific_tunings}->{$email_domain}->{domain} eq $email_domain){  
	            for(keys %{$self->{domain_specific_tunings}->{$email_domain}}){
	                $local_li->{$_} = $self->{domain_specific_tunings}->{$email_domain}->{$_};
	            }
	        }
        
		}
	}
	else { 
		%{$local_li} = %DADA::Config::LIST_SETUP_DEFAULTS;
	}
    
    
   
    # and back to your regularly scheduled send() subroutine...


	if($fields{To} =~ m/\<bad\.apple\@example\.com\>$/) { 
		warn 'bad apple!'; 
		return -1; 
	}

	if ($local_li->{strip_message_headers} == 1) { 	
		%fields = $self->_strip_fields(%fields) 
	}
	
	
	my $recipient_for_log = $fields{To}; 
	
	
    # write the header, if its set.
	# This'll write the header, but will do nothing to actually change, 
	# say the Subject; header to use this charset. 
	
    $fields{'Content-type'} .= '; charset='. $local_li->{charset_value} 
        if( 
          (defined($local_li->{charset_value}))  && 
          (defined($fields{'Content-type'}))              && 
          ($fields{'Content-type'} !~ /charset\=/)         #ie, wasn't set before. 
          );
    
    if($local_li->{print_return_path_header} == 1){
        if($local_li->{verp_return_path} == 1){ 
            $fields{'Return-Path'} = '<'. $self->_verp($fields{To}) .'>'; 
        }else{
            $fields{'Return-Path'} =  '<'. $local_li->{admin_email} . '>'; 
        }
    }	
	
	
	
	if(
	   !defined($local_li->{smtp_server}) &&
	   $local_li->{sending_method} eq 'smtp'       
	){ 
		die "SMTP Server has been left blank!";
	}

	
	if(
	   $local_li->{sending_method} eq 'smtp'       
	){ 
		
		if($local_li->{smtp_server} =~ m/amazonaws\.com/){ 
			%fields = $self->_massage_fields_for_amazon_ses(
	        	{ 
					-fields      => {%fields}, 
					-admin_email => $local_li->{admin_email}, 
				}
			);
		}
		
         $self->_pop_before_smtp;
        
     
            my $host; 
            if($local_li->{set_smtp_sender} == 1){ 
                $host = $local_li->{admin_email};
            } else { 
                $host = $local_li->{list_owner_email};
            }
            $host =~ s/(.*?)\@//;
                  
            eval { 
            
				my $mailer; 
			
			
				if(defined($self->net_smtp_obj) && $self->im_mass_sending == 1){ # If it's defined, let's use it; 
				
					warn 'Reusing Net::SMTP object...'
					    if $t; 
					$mailer = $self->net_smtp_obj;
				}
				else { 	
				
                	my %mailer_params = (
	                    Hello   =>  $host,
	                    Host    =>  $local_li->{smtp_server},
	                    Timeout => 60, # Keep this at 60 for now
	                    Port    =>  $local_li->{smtp_port},
	                    (
	                        ($DADA::Config::CPAN_DEBUG_SETTINGS{NET_SMTP} == 1) ? 
	                            (
	                            Debug => 1, 
                            
	                            ) :
	                            ()
	                    ), 
                    
	                ); 
                
	                if($local_li->{use_smtp_ssl} == 1){ 
	                   # require Net::SMTP_auth_SSL;
	                   # $mailer = new Net::SMTP_auth_SSL(%mailer_params);
                
	                    require  Net::SMTP::SSL;
	                    $mailer = Net::SMTP::SSL->new(%mailer_params);
					 	if(!defined($mailer)){ 
							carp "Problems with connecting to the SMTP Server: $!";
							my $extra = ''; 
							$extra .= $_ . ' => ' . $mailer_params{$_} . "\n"
								for(keys %mailer_params); 
							carp $extra; 
					 	}
                                  
              
	                 # authing can fail, although the message may still go through 
	                 # to the SMTP server, since sometimes SASL AUTH isn't required, but is 
	                 # attempted anyways. 
	                 if($local_li->{use_sasl_smtp_auth} == 1){ 
	                     $mailer->auth(
	                       # $local_li->{sasl_auth_mechanism}, 
	                        $local_li->{sasl_smtp_username}, 
	                        $self->_cipher_decrypt($local_li->{sasl_smtp_password})
	                     ) or carp 'Problems sending SASL authorization to SMTP server, make sure your credentials (username, password) are correct.'; 
	                 }
                 



	              }else { 
	                 require Net::SMTP_auth; 
	                 $mailer = new Net::SMTP_auth(%mailer_params);
					 if(!defined($mailer)){ 
							carp "Problems with connecting to the SMTP Server: $!";
							my $extra = ''; 
							$extra .= $_ . ' => ' . $mailer_params{$_} . "\n"
								for(keys %mailer_params); 
							carp $extra;
					 }
                    
	                 # authing can fail, although the message may still go through 
	                 # to the SMTP server, since sometimes SASL AUTH isn't required, but is 
	                 # attempted anyways. 
	                 if($local_li->{use_sasl_smtp_auth} == 1){ 
	                     $mailer->auth(
	                        $local_li->{sasl_auth_mechanism}, 
	                        $local_li->{sasl_smtp_username}, 
	                        $self->_cipher_decrypt($local_li->{sasl_smtp_password})
	                     ) or carp 'Problems sending SASL authorization to SMTP server, make sure your credentials (username, password) are correct.'; 
	                 }
                 
	          	}
            }
					warn 'Saving Net::SMTP Object for re-use'
				if $t; 
			  
				if($self->im_mass_sending == 1){ 
			  		$self->net_smtp_obj($mailer); 
				}
				
               my $to;
               if( $local_li->{group_list}                    == 1 && 
                   $fields{from_mass_send}                    == 1 &&
                   defined($local_li->{discussion_pop_email}) # safegaurd?
                   
                 ){  
                    # This is who it's going to. 
                    $to = $fields{To}; 

					require DADA::App::FormatMessages; 
				    my $fm = DADA::App::FormatMessages->new(
								-List        => $self->{list},  
								-ls_obj      => $self->{ls},
							);
					require Email::Address;
					
					my $formatted_disc_email = $fm->_encode_header(
							'To', 
							$fm->format_phrase_address(
								$self->{ls}->param('list_name'), 
								$local_li->{discussion_pop_email}
							)
						);

                    # This is what we're going to say we are...
                    $fields{To} = $formatted_disc_email;
                    
					if($local_li->{set_to_header_to_list_address} == 1){ 
						# Nothin' needed. 
					}
					else { 
						# Uh, unless it's a list invitation we're sending - why would we want 
						# replies from a non-subscriber posting to the list? 
						if($self->list_type ne 'invitelist'){ 						
							# This goes against RFC
							$fields{'Reply-To'} = $formatted_disc_email; 			
						}
					}
               } else { 
                    # um, nevermind. 
                    $to = $fields{To}; 
						
               }
                
                # why wouldn't it be defined?
                if (defined($to)){; 
                    eval { $to = (Email::Address->parse($to))[0]->address; }
                }                
                
                my $smtp_msg = '';
                for my $field (@default_headers){
                        $smtp_msg .= "$field: $fields{$field}\n" 
                            if( (defined $fields{$field}) && 
                                ($fields{$field} ne "")
                             );
                }
                $smtp_msg .= "\n"; 
                $smtp_msg .=  $fields{Body} . "\n";

                my $FROM_error_flag = 0; 
                my $FROM_error =  "problems sending FROM:<> command to SMTP server."; 
                if($local_li->{set_smtp_sender} == 1){ 
                    if($local_li->{verp_return_path}){ 
                        if(!$mailer->mail($self->_verp($to))){                         
                             carp $FROM_error; 
                             $FROM_error_flag++; 
                        }
                     }else{ 
                        if(!$mailer->mail($local_li->{admin_email})){ 
                            carp $FROM_error; 
                            $FROM_error_flag++; 
                        }    
                     }
                } else { 
                    if($local_li->{verp_return_path}){ 
                        if(!$mailer->mail($self->_verp($to))){ 
                            carp $FROM_error; 
                            $FROM_error_flag++; 
                        }
                     }else{ 
                        if(!$mailer->mail($local_li->{list_owner_email})){ 
                            carp $FROM_error; 
                            $FROM_error_flag++; 
                        }
                     }
                }
            
                if(! $FROM_error_flag){ 
                     if($mailer->to($to)){ 
                        if($mailer->data){ 
                             if($mailer->datasend($smtp_msg)){ 
                                 if($mailer->dataend){ 
                                    # oh hey, everything worked!
                                 }else{ 
                                    carp "problems completing sending message to SMTP server. (dataend)";
                                 }
                                
                            }else{ 
                                carp "problems sending message to SMTP server. (datasend)";
                            }
                        }else{ 
                            carp "problems sending DATA command to SMTP server. (data)";
                        }
                    } else{ 
                        carp "problems sending '" . $to . "' in 'RCPT TO:<>' command to SMTP server."; 
                    }
                } else{ 
                    carp $FROM_error;
                }

                 $mailer->reset()
                    or carp 'problems sending, "RSET" command to SMTP server.'; 
                
					if($local_li->{smtp_connection_per_batch} != 1){ 
						
						 $mailer->quit
		                    or carp "problems 'QUIT'ing SMTP server.";
						$self->net_smtp_obj(undef); 
						
						warn 'Purging Net::SMTP object, since we reconnect for each message'
						    if $t; 
					}

            }; # end of the eval block. 
            
            if($@){ # Something went wrong when trying to send...
                carp "Problems sending via SMTP: $@"; 
				return -1; 
            }
         
         }
		elsif($local_li->{sending_method} eq 'sendmail' ) { 
			
            my $live_mailing_settings; 
            # carp ' $fields{To} ' . $fields{To}; 
            
            my $plain_to_address = $fields{To}; #holds something like, me@you.com 
            if (defined($plain_to_address)){ 
                    eval { $plain_to_address = (Email::Address->parse($plain_to_address))[0]->address; }
            } else { 
                carp "couldn't strip, 'to' address! - $plain_to_address"; 
            }
                
            my $l_mail_settings; 
			if($self->im_mass_sending){ 
           		$l_mail_settings = $DADA::Config::MASS_MAIL_SETTINGS; 
			}
			else{ 
           		$l_mail_settings = $DADA::Config::MAIL_SETTINGS; 				
			}
			
 			if($l_mail_settings =~ /\-f/){ 
            
                carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER, \$DADA::Config::MAIL_SETTINGS of \$DADA::Config::MASS_MAIL_SETTINGS variable already has the -f flag set ($DADA::Config::MAIL_SETTINGS), not setting again $!";
                $live_mailing_settings = $l_mail_settings;
            
            }elsif($local_li->{add_sendmail_f_flag} == 1 && defined($local_li->{admin_email})){	    
            
                if($local_li->{verp_return_path} == 1){ 
                    $live_mailing_settings = $l_mail_settings . ' -f'. $self->_verp($plain_to_address);
                }else{
                    $live_mailing_settings = $l_mail_settings . ' -f'. $local_li->{admin_email};
                }
                
            }else{ 
            
                $live_mailing_settings = $l_mail_settings;
            
            }
            
           if( $local_li->{group_list}                    == 1 && 
               $fields{from_mass_send}                   == 1 &&
               defined($local_li->{discussion_pop_email}) # safegaurd?
             ){
               
				$live_mailing_settings  =~ s/\-t//; # remove any, "-t" flags... 
				$live_mailing_settings .= ' ' . $plain_to_address;  
				
				require DADA::App::FormatMessages; 
			    my $fm = DADA::App::FormatMessages->new(
							-List        => $self->{list},  
							-ls_obj      => $self->{ls},
						);
				require Email::Address;
				
				my $formatted_disc_email = $fm->_encode_header(
						'To', 
						$fm->format_phrase_address(
							$self->{ls}->param('list_name'), 
							$local_li->{discussion_pop_email}
						)
					);
					
			   $fields{To} =  $formatted_disc_email;
				
			   if($local_li->{set_to_header_to_list_address} == 1) { 
	           		# ... Nothin' more needed
				}
				else { 
					# This is against RFC
					$fields{'Reply-To'} = $formatted_disc_email; 
				}

            }
            
            $live_mailing_settings = make_safer($live_mailing_settings);
                       
            carp "MAIL is already open....?" 
                if (defined fileno *FH);
            # The above line makes no sense, shouldn't it say: 
            #  if (defined fileno *MAIL);
            # ?!?!?!?!
            
	
			if($self->test){ 
                # print "NOT SENDING - sending message to test file: '" . $self->test_send_file . "'"; 
                unless(open(MAIL, '>>' . $self->test_send_file)) { 
					warn "couldn't open test file: '" . $self->test_send_file . "' because: $!";
					return -1; 
                }
            }
            else { 

                unless(open(MAIL,$live_mailing_settings)) { 
					warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't pipe to mail program using settings: $DADA::Config::MAIL_SETTINGS or $DADA::Config::MASS_MAIL_SETTINGS: $!";
					return; 
				}
			}

			
			# Well, probably, no? 
			binmode MAIL, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';
            
			# DEV: I guess the idea is, I want this header first?
            if (exists($fields{'Return-Path'})){
            	if ($fields{'Return-Path'} ne undef){
					print MAIL 'Return-Path: ' . $fields{'Return-Path'} . "\n"; 	
				} 
			}
            

            for my $field (@default_headers){
                    print MAIL "$field: $fields{$field}\n"
                        if(
	 						exists($fields{$field})                  && 
							defined $fields{$field}                  && 
                            $fields{$field}         ne ""            && 
                            $field                  ne 'Return-Path'
                         );
            }
            print MAIL "\n"; 


            print MAIL $fields{Body} . "\n"; # DEV: Why the last, "\n"?


            unless(close(MAIL)) {  
            	warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: 
                         didn't close pipe to '$live_mailing_settings' while 
                         attempting to send a message to: '" . $fields{To} ." because:' $!";
				return;  
			}
		
        }
		elsif($local_li->{sending_method} eq 'amazon_ses' ) { 

			# rewriting the To: header...
			if( $local_li->{group_list}                    == 1 && 
               $fields{from_mass_send}                   == 1 &&
               defined($local_li->{discussion_pop_email}) # safegaurd?
             ){

				require Email::Address;			
				require DADA::App::FormatMessages; 
			    my $fm = DADA::App::FormatMessages->new(
							-List        => $self->{list},  
							-ls_obj      => $self->{ls},
						);
				my $formatted_disc_email = $fm->_encode_header(
						'To', 
						$fm->format_phrase_address(
							$self->{ls}->param('list_name'), 
							$local_li->{discussion_pop_email}
						)
					);
					
#			   $fields{To} =  $formatted_disc_email;

			   # rewriting  Reply-To: 
			   if($local_li->{set_to_header_to_list_address} == 1) { 
	           		# ... Nothin' more needed
				}
				else { 
					# This is against RFC
					$fields{'Reply-To'} = $formatted_disc_email; 
				}				
            }
           			
			%fields = $self->_massage_fields_for_amazon_ses(
            	{ 
					-fields      => {%fields}, 
					-admin_email => $local_li->{admin_email}, 
				}
			); 

			my $ses_obj = undef;
			require Net::Amazon::SES;  	
			#carp '$self->ses_obj' . $self->ses_obj; 
			#carp '$self->im_mass_sending' . $self->im_mass_sending; 
			if(
				defined($self->ses_obj) 
				&& $self->im_mass_sending == 1
			){
				#carp "reusing ses_obj"; 
				$ses_obj = $self->ses_obj; 
				
			}
			else { 
				#carp "creating a new ses_obj"; 
				$ses_obj = Net::Amazon::SES->new( $DADA::Config::AMAZON_SES_OPTIONS ); 
				$self->ses_obj($ses_obj); 
			}		
			my $msg = ''; 
						
            for my $field (@default_headers){			
				if(
 					exists($fields{$field})                  && 
					defined $fields{$field}                  && 
                    $fields{$field}         ne ""
                 ) { 
					$msg .= "$field: $fields{$field}\n";
                  }
           	}
			
            $msg .= "\n"; 
            $msg .= $fields{Body} . "\n"; # DEV: Why the last, "\n"?
			#warn "sending " . time; 
			my ($response_code, $response_content) = $ses_obj->send_msg(
				{
					-msg => $msg, 
				}
			);
#            require Data::Dumper; 
#           carp Data::Dumper::Dumper(
#               { 
#                   reponse_code     =>  $response_code,
#                   response_content => $response_content,
#               } 
#            ); 
			
			if($response_code == 200){
				# my($sesMessageId, $sesRequestId) = split("\n", $response_content);
				# do something here about the message id
			}
			else { 
				return -1; 
			}
		}
		else { 
			die 'Unknown Sending Method: "' . $local_li->{sending_method} . '"'; 
		}
        
       
		$self->{mj_log}->mj_log($local_li->{list}, 'Mail Sent', "Recipient:$recipient_for_log, Subject:$fields{Subject}") 
			if $DADA::Config::LOG{mailings};

		$local_li = {};
			
   		return 1; 

}




sub _massage_fields_for_amazon_ses { 
	
	my $self = shift; 
	my ($args) = @_; 
	my $fields = $args->{-fields}; 
	my $admin_email = $args->{-admin_email}, 
	
	$fields->{'X-Message-ID'} = $fields->{'Message-ID'}; 
	$fields->{'Return-Path'} =  '<'. $args->{-admin_email} . '>';
	
	for my $field (@default_headers){
		if(exists($fields->{$field})) { 
			if($field =~ /[\040\x00-\x1F:]/){
				delete($fields->{$field})
			}
		}
	}
	
	return %$fields; 
	
}




sub sending_preferences_test { 

    my $self = shift; 

    require DADA::Security::Password; 
    
    my $filename = $DADA::Config::TMP . '/' .  time . '_' . DADA::Security::Password::generate_rand_string(); 
       $filename = make_safer($filename); 

    chmod($DADA::Config::DIR_CHMOD , $filename);
	
    open(SMTPTEST, ">$filename") or die "Couldn't open file, $filename - $!"; 
    
    *STDERR = *SMTPTEST; 
    
    my $orig_debug_smtp                          = $DADA::Config::CPAN_DEBUG_SETTINGS{NET_SMTP}; 
    $DADA::Config::CPAN_DEBUG_SETTINGS{NET_SMTP} = 1; 
    my $orig_debug_pop3                          = $DADA::Config::CPAN_DEBUG_SETTINGS{NET_POP3}; 
    $DADA::Config::CPAN_DEBUG_SETTINGS{NET_POP3} = 1; 

    require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('sending_preferences_test_message.eml'); 
	
	
	require DADA::App::Messages; 
	DADA::App::Messages::send_generic_email(
		{
			-list    => $self->{list}, 
			-headers => { 
				To              => $self->{ls}->param('list_owner_email'),
				From            => $self->{ls}->param('list_owner_email'), 
			    Subject         => $msg_data->{subject},
			}, 
			-body => $msg_data->{plaintext_body},
			-tmpl_params => {
				
				-list_settings_vars_param => {
					-list   => 	$self->{list}, 
					-dot_it => 1,
				},
				-expr => 1,
				
			},		 
		}
	);
    
    close(SMTPTEST); 
	
    $DADA::Config::CPAN_DEBUG_SETTINGS{NET_SMTP} = $orig_debug_smtp; 
    $DADA::Config::CPAN_DEBUG_SETTINGS{NET_POP3} = $orig_debug_pop3;     
    open(RESULTS, "<" . $filename)
        or die "Couldn't open " . $filename . " - $!"; 
    my $smtp_msg = do { local $/; <RESULTS> };

    close(RESULTS); 

    my @r_l = split("\n", $smtp_msg); 
   
   my $report =  []; 
   
	my @munged_l = (); 
	for my $l(@r_l){ 
		$l =~ s/Net\:\:SMTP(.*?)\)//;
		push(@munged_l, $l); 
		if($l =~ m/502 unimplemented/i){ 
			push (@$report, {line => $l, message => 'SASL Authentication may not be available on this SMTP server - try POP-before-SMTP Authentication.'}); 
		}elsif($l =~ m/250\-AUTH PLAIN LOGIN|250 AUTH LOGIN PLAIN|250\-AUTH\=LOGIN PLAIN/i){ 
			push (@$report, {line => $l, message => 'Looks like Plain SASL Authentication is Supported!'}); 
		}elsif($l =~ m/535 Incorrect authentication data|535 authorization failed/i){ 
			push (@$report, {line => $l, message => 'Looks like there\'s something wrong with your username/password - double check that you entered them right.'}); 
		}elsif($l =~ m/Authentication succeeded|OK Authenticated|Authentication successful/i){ 
			push (@$report, {line => $l, message => 'Looks like we logged in OK!'});
		}elsif($l =~ m/235 ok\, go ahead/i){ 
			push (@$report, {line => $l, message =>'Looks like we logged in OK!'});  
		}elsif($l =~ m/auth not available/i){ 
			push (@$report, {line => $l, message =>'Looks like we tried to log in, but our login was rejected for some reason.!'});  
		}
		
    }

#	unlink($filename) or warn $!; 

	$smtp_msg = ''; 
 	foreach(@munged_l){ 
		$_ = strip($_); 
		next unless length($_) > 0;
		$smtp_msg .= $_ . "\n";
	}
	
    return ($smtp_msg, \@r_l, $report);  


}




sub restart_mass_send { 

	warn 'restart_mass_send'
		if $t; 
	
    my $self = shift; 
    my $id   = shift; 
    my $type = shift; 
    
    croak "no id!" if ! $id; 
    croak "no type!" if ! $type; 
    
    $self->list_type($type); # that should take care of the type... 
    
    $self->{mj_log}->mj_log(
                                $self->{list}, 
							    "Restarting List Sending", 
							     "Internal ID: " . $id, 
							     "Type: " . $type, 
							     
							   )   if $DADA::Config::LOG{mass_mailings};   
		# Why the close? 					    
 	    $self->{mj_log}->close_log if $DADA::Config::LOG{mass_mailings};
 	    
 	    
    
    
		warn 'restart_with set to: ' . $id; 
    $self->restart_with($id); 
    $self->mass_send(); 

	return 1; 
    
}




sub mass_send { 

	my $self   = shift; 	
	my ($args) = @_; 
	
	carp "mass_send called from PID: $$"
		if $t; 
		
	my %param_headers = (); 
	
	if(ref($args)){
		
		if(! exists( $args->{-msg} ) ){ 
			croak "You MUST pass the message in the -msg param"; 
		} 
		else { 
			%param_headers = %{$args->{-msg}};
		}
		# And then, we can pass a few neat things: 
		if(exists($args->{-also_send_to})){
			$self->also_send_to($args->{-also_send_to}); 

		}
		if(exists($args->{-partial_sending})){ 
			$self->partial_sending($args->{-partial_sending}); 
		}
		if(exists($args->{-multi_list_send})){ 
			$self->multi_list_send($args->{-multi_list_send}); 		
		}

		if(exists($args->{-mass_mailing_params})){
		    #use Data::Dumper;  
		    #carp 'mass_mailing_params 1:' . Dumper($args->{-mass_mailing_params}); 
			$self->mass_mailing_params($args->{-mass_mailing_params}); 
		}
		
		# This is also confusing - what's it for? - it is in the test
		# Why isn't it in the, "-partial_sending" param? 
		if(exists($args->{-exclude_from})){ 
			$self->exclude_from($args->{-exclude_from}); 		
		}	
		
		# written to a test file, instead of mailed out? 
		if(exists($args->{-test})){ 
			$self->test($args->{-test}); 
		}
		# Send to only a test recipient, instead of the entire list? 
		if(exists($args->{-mass_test})){ 
			$self->mass_test($args->{-mass_test}); 
		}
		# And who is this rest recipient? 
		if(exists($args->{-mass_test_recipient})){ 
			$self->mass_test_recipient($args->{-mass_test_recipient}); 
		}		
	}
	else { 
		%param_headers = @_; 
	}
	
	# This will just be generally, well, chatty. 
	no strict;
	# DEV: This needs to be cleaned up;
	for(keys %param_headers){
		if(strip($param_headers{$_}) eq ''){ 
			delete($param_headers{$_}); 
		}
	}
	use strict;
	
	
	$self->im_mass_sending(1); 

	carp '[' . $self->{list} . '] (' . $$ . ') starting mass_send at: ' . scalar(localtime(time))
	    if $t;
	    
	my %fields = ( 
				  %defaults,  
				  $self->_make_general_headers, 
				  $self->list_headers, 
				   %param_headers, 
				); 
		

	%fields = $self->clean_headers(%fields); 
	

	
    # save a copy of the message for later pickup.
    $self->saved_message($self->_massaged_for_archive(\%fields));

	# Clear out the data cache, please: 
	try {
		require DADA::App::DataCache; 
		my $dc = DADA::App::DataCache->new; 
		   $dc->flush({-list => $self->{list}}); 
	} catch {
		carp "Problems removing data cache: $_"; 
	};
	
    
	require DADA::MailingList::Subscribers;
	       $DADA::MailingList::Subscribers::dbi_obj = $dbi_obj; 
	my $lh = DADA::MailingList::Subscribers->new({-list => $self->{list}});
	
	
	my $path_to_list          = undef; 
	my $total_sending_out_num = undef; 
	my $bsf_errors            = {};

    require DADA::Mail::MailOut;     
    my $mailout = DADA::Mail::MailOut->new( { -list => $self->{list} } ); 
   
	
    if($self->restart_with){ 
        warn '[' . $self->{list} . '] restart_with is defined: ' . $self->restart_with
            if $t; 
        # Shazzam!
        $mailout->associate(
			$self->restart_with, 
			$self->list_type
		);
        
        if($mailout->should_be_restarted == 1){ 
        
            warn '[' . $self->{list} . '] mass mailing is reporting the mailing should be restarted from PID:' . $$
                if $t; 
			$mailout->log('mass mailing is reporting that it should be restarted from PID:' . $$);
                        
            my $raw_msg = $mailout->reload(); 
            
            my ($raw_header, $raw_body) = split(/\n\n/, $raw_msg, 2); 
            %fields = $self->return_headers($raw_header); 
            $fields{Body} = $raw_body;   
        
        } else { 
            # For the life of me, I do not understand this line. 
			$mailout->log('Attempt to reload a message which does not have a stalled process - check before attempting!');
            carp "Attempt to reload a message which does not have a stalled process - check before attempting!"; 
            return; 
        }
    
    }else { 

        warn '[' . $self->{list} . '] Creating Mass Mailing'
            if $t; 

		$mailout->create({
                        -fields              => {%fields},
                        -list_type           => $self->list_type,
                        -mass_mailing_params => $self->mass_mailing_params, 
                        -mh_obj              => $self,  
                        -partial_sending     => $self->partial_sending, 
						-exclude_from        => $self->exclude_from, 
                   }); 


					
					
					
    	if($self->test_return_after_mo_create == 1){ 
			warn "test_return_after_mo_create is set to 1, and we're getting out of the mass_send method"
				if $t; 
			return; 
		}
		
		$self->_adjust_bounce_score; 
    
    }													 				
	


		
	
    # This is so awkwardly placed...	
	if($self->list_type eq 'invitelist' || $self->list_type =~ m/tmp/){ 
		$lh->remove_this_listtype({-type => $self->list_type});
	}

	# Probably right here we can put the, 
	# "hey, right a log HERE!"; 
	# Or, perhaps just let Mail::MailOut Handle it? 



	# This is for the Tracker.
	my $num_subscribers = $lh->num_subscribers;
	   $self->num_subscribers($num_subscribers); 

	
	
	if( ! $mailout->still_around ){ 
		warn '[' . $self->{list} . '] Mass Mailing seems to have been removed. exit()ing'
            if $t;
		exit(0); 
	}

    my $status = $mailout->status({-mail_fields => 0}); 
    
	my $num_total_recipients = $status->{total_sending_out_num};
	
	my $mailout_id = $status->{id}; 
	
	
	#-------------------------------------------------------------------------#
	# Log the start of this mailing. 	
	my $s_l_subject = $fields{Subject}; 
	   $s_l_subject =~ s/\r|\n//g;
	my $mass_mail_starting_log = join(
	"\t", 
	"Message-Id: "     . $mailout_id, 
	"Subject: "        . $s_l_subject, 
	"Started: "        . scalar(localtime($status->{first_access})), 
	"Mailing Amount: " . $status->{total_sending_out_num},
	);	
	
	if($DADA::Config::LOG{mass_mailings} == 1){ 
		$self->{mj_log}->mj_log(
			$self->{list}, 
			'Mass Mailing Starting',
			$mass_mail_starting_log
		);
	}
	$mailout->log('Mass Mailing Starting: ' . $mass_mail_starting_log);
	
	# /Log the start of this mailing. 
	#-------------------------------------------------------------------------#
		
    # Meaning, queueing is ON! Enabled! Big red button! Blinky blinky!
    if($status->{queue} == 1){ 
    
        warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' queueing is enabled.'
            if $t; 
    	$mailout->log('Queueing is enabled.'); 
		
        warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' $status->{queue_place} ' . $status->{queue_place}
			if $t; 
		$mailout->log('$status->{queue_place} ' . $status->{queue_place}); 
			
		if($self->mass_test == 1){ 
			
			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Queueing is on, but we\'re side-stepping the queueing check to send a test mass mailing out...'
				if $t; 
			$mailout->log('Queueing is on, but we\'re side-stepping the queueing check to send a test mass mailing out...'); 
			
		}else { 
					
    	    if($status->{queue_place} > ($DADA::Config::MAILOUT_AT_ONCE_LIMIT - 1)){
	            # carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Queueing is on, and this mailing falls above the queueing limit';
				# Experimental...
				$mailout->log('Warning: Queueing is on, and this mailing falls above the queueing limit');
            
	            # I can see an instance, where you're over the queueing limit, but still need this Message-ID for archiving 
	            # purposes - can you? I thought you could...
	            return $fields{'Message-ID'};
	        }
	        else { 
	            warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' This message is below the mass mailing limit and shouldn\'t have delays in sending.'
	                if $t; 
				$mailout->log('This message is below the mass mailing limit and shouldn\'t have delays in sending.'); 
				
			}
		}
    }
	
    
    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' $status->{paused}  is reporting ' . $status->{paused}
        if $t; 
    if($status->{paused} > 0){ 
        carp 'Sending is currently paused.'; 
		$mailout->log('Warning: Sending is currently paused.'); 
		
		return $fields{'Message-ID'};

    }

	if($status->{integrity_check} != 1){ 
		carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' is currently reporting an integrity check warning! Pausing mailing and returning.'; 
		
		$mailout->log('Warning: Mass Mailing:' . $mailout_id . ' is currently reporting an integrity check warning! Pausing mailing and returning.'); 
		$mailout->pause;
		return; 
	}
    
    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' $status->{percent_done} is reporting '  . $status->{percent_done}
        if $t; 
	$mailout->log('$status->{percent_done} is reporting '  . $status->{percent_done}); 
	
    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . '$status->{is_batch_locked} is reporting ' . $status->{is_batch_locked}
        if $t; 
        
    if($status->{is_batch_locked} == 1){ 
        carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Sending process is currently locked, not resending message until lock is unlock or seen as stale...'; 
 		$mailout->log('Warning: Sending process is currently locked, not resending message until lock is unlock or seen as stale...'); 
       return; 
    }


	# how many messages get sent between batches? 
	warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id
	    if $t; 
	
		# we need to create a new file that has the subscribers and their pin 
		# number. Those two things will be separated with a '::' so we can split 
		# it apart later.

	undef $lh;

	my $pid; 


    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' About to fork off mass mailing...'
		if $t; 
	$mailout->log('About to fork off mass mailing...'); 
	
	FORK: {
		if ($pid = fork) {

			$mailout->log('Mass Mailing Starting.'); 
							    

			# DEV: DO NOT COUNT FOR: 
			# Restarts: 
			# Tests
			# Any mailing type, except, "list" 
			# 
			warn 'about to call _log_sub_count, $fields{\'Message-ID\'}:' . $fields{'Message-ID'} . ', $num_subscribers: ' . $num_subscribers
				if $t;
				
            $self->_log_sub_count(
                {
                    -msg_id               => $fields{'Message-ID'},
                    -num_subscribers      => $num_subscribers,
                    -num_total_recipients => $num_total_recipients,
                }
            );
            #
            #
            #
            

            
            # I wonder if it'll work that I switch the database connection here. 
            # Would that impact everyone? 
            # Probably not. (rats.); 
            warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Fork successful. (From Parent)'
				if $t; 
				
			# Here's the new stuff: 
			
			if(
				$DADA::Config::MULTIPLE_LIST_SENDING      == 1 
				&& 
				$DADA::Config::MULTIPLE_LIST_SENDING_TYPE eq 'individual'
			) { 
								
				if(keys %{$self->multi_list_send}){ 

					my $local_args = $args; 
					# Cause that would not be good. 
				
					delete($local_args->{-multi_list_send});
					delete($local_args->{-exclude_from});
				
					my $lists = $self->multi_list_send->{-lists};
				
					my @exclude_from = ($self->list);
					for my $local_list(@$lists){ 
						# warn 'looking at: $local_list ' . $local_list; 
					
						sleep(1); # just so things can catch up... 
						require DADA::Mail::Send; 
						my $local_ms = DADA::Mail::Send->new(
								{
									-list => $local_list, 
								}
						); 
						$local_ms->mass_send(
								{
									%$local_args, 
									-exclude_from => [@exclude_from],
								}
							); 
						push(@exclude_from, $local_list); 	
					}
					# warn "Looks like we have more lists to send to!"; 
				}
				else { 
					# warn "Nope. No more lists to send to."; 
				}
			}
            return $fields{'Message-ID'};
                
        } elsif (defined $pid) { # $pid is zero here if defined
            

			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Fork successful. (From Child)'
				if $t;	            
                
            if($DADA::Config::NULL_DEVICE){ 
                open(STDIN,  ">>$DADA::Config::NULL_DEVICE") or carp "couldn't open '$DADA::Config::NULL_DEVICE' - $!"; 
                open(STDOUT, ">>$DADA::Config::NULL_DEVICE") or carp "couldn't open '$DADA::Config::NULL_DEVICE' - $!"; 
            }
            
            
            setpgrp; 
            
            warn "($$) _clarify_dbi_stuff"
				if $t; 
			$mailout = $self->_clarify_dbi_stuff({-dmmo_obj => $mailout}); 
			$mailout->update_last_access;


			# Subscriber # we are currently working with (index starts at #1)
			my $mass_mailing_count  = 0;  
			
			my $batch_num_sent      = 0;  # num of addresses we've sent, per batch 
			my $stop_email          = ''; # address we've stopped on, in this batch;
						
			# Let's tell em we're in control: 
			#
			
			$mailout->set_controlling_pid($$);
			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Setting the controlling PID to: "' . $$ . '"'
		        if $t;
			#
			# 
			

			# Data is stored as a CSV File: 
			require Text::CSV; 
			my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
			
			open(MAILLIST, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $mailout->subscriber_list) or 
				croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: 
				       can't open mailing list (at: '" . $mailout->subscriber_list .
				      "') to send a Mailing List Message: $!"; 


			##################################################################
			# Check to have semaphore file for the actual sending list 
			# The ONLY time this list is accessed with the semaphore file 
			# is for sending. 
			
			my $lock = $mailout->lock_file($mailout->subscriber_list);
			
			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . " opened MAILLIST ($$)"
			    if $t; 
			$mailout->log('opened MAILLIST'); 

			#
			##################################################################

			##################################################################
			# Are we started up this mass mailing at a particular # of addresses? 
			#
			
			my $check_restart_state = 0; 
			# only check the state IF we need to, otherwise, skip the check and save some cycles. 
			if($self->restart_with){ 
			    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' restart_with defined'
			        if $t; 
                $check_restart_state = 1; 
            }

			%fields = $self->_set_clickthrough_tracking_stuff({-fields => \%fields}); 

            warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' locking batch' 
                if $t; 
            $mailout->batch_lock;

			# batch_params is cached in the object. 
			my ( $batching_enabled, $batch_size, $batch_wait ) = $mailout->batch_params;
				$mailout->log('Batching Enabled: ' . $batching_enabled . ', Batch Size: ' . $batch_size . ', Batch Sleep: ' . $batch_wait); 

			my $batch_start_time = time; 
			require DADA::App::FormatMessages; 
		    my $fm = DADA::App::FormatMessages->new(
						-List        => $self->{list},  
						-ls_obj      => $self->{ls},
			);
			
			
			# Perhaps just use, "parse" instead of "parse_open"? Why am I using "parse_open"?
			my ($entity, $filename) = $fm->entity_from_dada_style_args(

			                              {
			                                    -fields        => \%fields,
			                                    -parser_params => {-input_mechanism => 'parse_open'}, 
			                                }
			                         );
			if( -e $filename){ 
				chmod($DADA::Config::FILE_CHMOD , make_safer($filename));
				if(	unlink($filename) < 1){ 
					carp "Couldn't delete tmp file, '$filename'?"; 
				}
			}
			else { 
				carp "'$filename' doesn't exist?"; 
			} 
			
			# while we have people on the list.. 
			my $subcriber_line; 
			SUBSCRIBERLOOP: while(defined($subcriber_line = <MAILLIST>)){ 	
				chomp($subcriber_line);	

				##############################################################
				# calling status() is resource-intensive, but calling 
				# ->paused isn't. We'll call pause to see if a mailing is 
				# paused, so we don't have to go through the entire batch on a 
				# paused() mailing. "queue" requires finding information about 
				# ALL mailings, so it is quite resource-intensive.
				# Is mass mailing paused? 
				#
				my $is_mailout_paused = $mailout->paused; 
				warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . 
				     ' $mailout->paused reporting: ' . $is_mailout_paused
				 	if $t; 
				
				if($is_mailout_paused > 0){                            
					carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . 
					     ' Mailing has been paused - exit()ing';
					$mailout->log('Warning: Mailing has been paused - exit()ing'); 
					$mailout->unlock_batch_lock;
					exit(0);
				}
				
				if($status->{integrity_check} != 1){ 
					carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . 
					     ' is currently reporting an integrity check warning! 
					       Pausing mailing and returning.';
					$mailout->log('Warning: Mailing is currently reporting an 
					               integrity check warning! Pausing mailing and 
					               returning.');  
					$mailout->unlock_batch_lock;
					$mailout->pause;
					exit(0); 
				}
				# / Is mass mailing paused? 
				##############################################################

				
				my @ml_info; 
				if ($csv->parse($subcriber_line)) {
			     	@ml_info = $csv->fields;
			    } else {
			        my $w =  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . " Error: CSV parsing error: parse() failed on argument: ". $csv->error_input() . ' ' . $csv->error_diag ();
			        $mailout->log($w);
			        carp($w); 
			        undef ($w); 
			    	undef(@ml_info);
					next SUBSCRIBERLOOP;
				}
                # incremented:
                $mass_mailing_count++;
				
				
				my $current_email = $ml_info[0];
				

				# only start sending at a point where we're supposed to...
				# so wait - mailing count starts at 1?
				
				warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' $check_restart_state set to ' . $check_restart_state
				    if $t; 


    
				##############################################################
				# These are all checks to make sure we're starting the mailing
				# at the right place in the list. 
				#
				
				if($check_restart_state == 1){ 
                    if($self->restart_with){ 
                        my $mo_counter_at = $mailout->counter_at; 
                        
                        	warn '[' . $self->{list} . '] Mass Mailing:' . 
                                 $mailout_id . ' $mailout->counter_at ' . 
                                 $mo_counter_at
                            	if $t; 
                        
                        if($mo_counter_at > ($mass_mailing_count - 1)){ 
                           warn '[' . $self->{list} . '] Mass Mailing:' . 
                                $mailout_id . ' Skipping Mailing #' . 
                                $mass_mailing_count . 
                                '( $mo_counter_at > ($mass_mailing_count - 1 )'
                            if $t; 
                            next SUBSCRIBERLOOP; 
                        }
                        elsif($mo_counter_at == ($mass_mailing_count - 1)){ 
                            	warn '[' . $self->{list} . '] Mass Mailing:' . 
                                 $mailout_id . 
                                 ' setting check_restart_state to 0'
                                if $t; 
                            $check_restart_state = 0;
                        }
                        elsif($mo_counter_at < ($mass_mailing_count - 1)){ 
                            warn '[' . $self->{list} . '] Mass Mailing:' . 
                                 $mailout_id . 'Problems!' 
                             . '( $mo_counter_at < ($mass_mailing_count - 1 )'
                             . ' how did counter_at get behind $mass_mailing_count?!' 
                             if $t; 
                             $mailout->update_last_access; 
 							 $mailout->unlock_batch_lock;
 							 exit(0);
                        }
                    
                    }
                    else { 
                        warn '[' . $self->{list} . '] Mass Mailing:' . 
                              $mailout_id . ' $check_restart_state set to:' . $check_restart_state
                            if $t; 
                    }
			    }
				#
				##############################################################
				
				$stop_email = $current_email;
								
 				my %nfields = $self->_mail_merge(
				    {
				        -entity => $entity->dup,
				        -data   => \@ml_info, 
						-fm_obj => $fm, 
				    }
				);
								                
                warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' sending mail'
                    if $t; 

				##############################################################
				# Three strikes, and you're out: 
				
				
				my $tries = 0; 
				TRIES: while($tries <= 3){ 	
					$tries++;
					
					warn 'sending to: ' . $nfields{To}
						if $t; 
					warn 'Try #' . $tries 
						if $t; 
					my $send_return = $self->send(%nfields, from_mass_send => 1); # The from_mass_send is a hack. 
					warn '$send_return:"'.$send_return.'"'
						if $t; 
					
					if($send_return == -1 && $tries < 3){
						my $warning = '[' . $self->{list} . '] Mass Mailing:' . $mailout_id 
						. ' Problems sending to, ' . $nfields{To} 
						. ', waiting: ' . $batch_wait . ' seconds to try again. '
						. '(on try #' . $tries . ')';
						 warn $warning; 
						$mailout->log($warning);
						sleep($batch_wait); 
						$mailout->update_last_access; 
					}
					elsif($send_return == -1 && $tries >= 3){ 
						
						# if we've already logged this guy
						if($mailout->isa_problem_address({-address => $current_email})){ 
							# Time to skip.
							my $warning = '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Cannot send to, address: ' . $current_email . 'after 2 x 3 tries, skipping and logging address.';
							warn $warning; 
							$mailout->log($warning);
							$mailout->countsubscriber;
							$self->_log_sending_error({-mid   => $mailout->_internal_message_id, -email => $current_email, -adjust_total_recipients => 1});
							next SUBSCRIBERLOOP;
						}
						else {
							my $warning = '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Bailing out of Mailing for now - last message to, ' . $nfields{To} . ' was unable to be sent! exit()ing!';
							warn $warning;
							$mailout->log($warning);
							$mailout->log_problem_address({-address => $current_email}); 
							$mailout->update_last_access; 
							$mailout->unlock_batch_lock;
							exit(0);
						}
					}
					else { 
						
						warn 'That try seemed to work!'
							if $t; 
							##############################################################
             				# Count Subscriber
             				#
                             warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' counting subscriber.'
                                 if $t; 
                             
                             my $new_count = $mailout->countsubscriber; 

             				$mailout->log($nfields{To} . ' sent message #' . $new_count);
             				
                             warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' $new_count set to, ' . $new_count
                             	if $t; 

             				# And this almost never happens: 
                            if($mass_mailing_count != $new_count){ 

                                my $w = '[' 
                                . $self->{list} 
                                . '] Mass Mailing:' 
                                . $mailout_id 
                                . ' Warning: $mass_mailing_count: '
                                . $mass_mailing_count 
                                . ' is not the same as  $new_count: ' 
                                . $new_count
                                . ' - exit()ing to reset mass mailing.'; 
                                carp $w; 
								$mailout->log($w); 
								$mailout->unlock_batch_lock;
								exit(0); 
                            }
             				$batch_num_sent++; 
             				# /Count Subscriber
             				##############################################################
						last TRIES; 
					}
				}
				
				# / Three strikes, and you're out: 
				##############################################################				
				
				
				# I hate to wrap this in yet another If... state ment, but... 
				if($self->mass_test == 1){ 
					# Well, for a test, we do nothing, so we can skip the batch settings stuff, since we only send 1 message. 
				}
				else {
				
				    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Batching settings: $batching_enabled: ' . $batching_enabled . ' $batch_size ' . $batch_size . ' $batch_wait ' . $batch_wait
				        if $t; 
				    
					if($batching_enabled == 1){ 
					    
				         warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' $batching_enabled is set to 1'
				            if $t; 
			            
						
				    	if($batch_num_sent >= $batch_size){ 
			    	
				    	     warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' reached the amount of messages for this batch:' . $batch_num_sent . ', sleeping (estimate):' . $batch_wait
				    	        if $t; 
							
							$batch_num_sent = 0; 
							
							# Undefined after each batch, if it is defined
							if(defined($self->net_smtp_obj)){

								warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . 'Quitting a SMTP connection for this batch that\'s still going on... ' 
									if $t; 
								
								$self->net_smtp_obj->quit
				               		or carp "problems 'QUIT'ing SMTP server.";
			
								 warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Purging Net::STMP object, since we have reached the final message of the batch.'
								    if $t;
		
								$self->net_smtp_obj(undef); 
							}

							if(defined($self->ses_obj)){ 
							    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' undef\'ing ses_obj'
							        if $t; 
								$self->ses_obj(undef);
							}
							
							warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' calling Mail::MailOut::status() '
								if $t;
			                my $batch_status = $mailout->status({-mail_fields => 0}); 
		                
	                       my $batch_log_message = "Subject:$fields{Subject}, Start Time: " . scalar(localtime($status->{first_access})); 
							for(keys %$batch_status){ 
								next if $_ eq 'email_fields';
								next if $_ =~ m/formatted/; 
								$batch_log_message .= ' ' . $_ . ': ' . $batch_status->{$_}; 
							}
                         
                          	$mailout->log('Batch successfully completed.');
                          	warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Batch Successfully Completed: ' .  $batch_log_message
                          	    if $t; 
                          	
							# Reset the batch settings. 

							if($batch_status->{queued_mailout} == 1){  
								carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Mailing has been queued - exit()ing'; 
								$mailout->log('Warning: Mailing has been queued - exit()ing'); 
								$mailout->unlock_batch_lock;
								exit(0); 
							}
							if($batch_status->{paused} > 0){                          
								carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Mailing has been paused - exit()ing';
								$mailout->log('Warning: Mailing has been paused - exit()ing'); 
								$mailout->unlock_batch_lock;
								exit(0);
							}
							if($batch_status->{integrity_check} != 1){ 
								carp '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' is currently reporting an integrity check warning! Pausing mailing and returning.'; 
								$mailout->log('Warning: Mailing is currently reporting an integrity check warning! Pausing mailing and returning.'); 
								$mailout->unlock_batch_lock;
								$mailout->pause;
								exit(0);
							}
						
							# SES: explicitly reset the batch params cache after every 100 messages sent. 
							if((($mass_mailing_count % (int($batch_wait) * 100))) == 0) { 
								$mailout->log("Resetting Batch Params Cache"); 
								$mailout->reset_batch_params_cache;
								
								( $batching_enabled, $batch_size, $batch_wait ) = $mailout->batch_params;
								$mailout->log('Batching Enabled: ' . $batching_enabled . ', Batch Size: ' . $batch_size . ', Batch Sleep: ' . $batch_wait); 
							}
							else{ 
								# Batch params also expire after 10 mins. 
								( $batching_enabled, $batch_size, $batch_wait ) = $mailout->batch_params;
							}
							
							
	                        if($self->{ls}->param('restart_mailings_after_each_batch') != 1) { 
                          
	                             warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' restart_mailings_after_each_batch is NOT enabled.'
	                                if $t; 
                            
								##############################################
								# This is all to attempt to tweak the sleep time
								# to more reflect the batch settings 
								# 
								
								my $sleep_for_this_amount = $batch_wait;
								if($self->{ls}->param('adjust_batch_sleep_time') == 1){ 
									my $batch_time_took = time - $batch_start_time;
									if($batch_time_took > 0){ 
										#warn "SLEEP: This batch took: $batch_time_took seconds"; 
										if($batch_time_took >= $batch_wait){ 
											warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' SLEEP: batch time took MORE time than $batch_wait - skipping sleeping'
											    if $t; 
											$sleep_for_this_amount = 0;
										}
										else {
											$sleep_for_this_amount = ( $sleep_for_this_amount - $batch_time_took ); 
											warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' SLEEP: setting sleep time to: ' . $sleep_for_this_amount . ' seconds. Sweet Dreams'
											    if $t; 
										}	
									}
									else { 
										warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' SLEEP: batch was basically instantaneous - no need to tweak sleep time...'
										    if $t; 
									}
								}
								#
								# / Tweak Sleep Times
								##############################################
									
								my $before_sleep_time = time; 
								warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Sleeping for ' . $sleep_for_this_amount . ' seconds. See you in the morning. Time: ' . $before_sleep_time
									if $t; 
							
								if($sleep_for_this_amount > 0){ 
								    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' sleeping for: ' . $sleep_for_this_amount . ', time:' . time
								        if $t; 
									sleep($sleep_for_this_amount); 
									warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Good morning!, time:' . time
									    if $t; 
								}

								warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' I\'m awake! from sleep()ing, Time: ' . time . ', Slept for: ' . (time - $before_sleep_time) . ' seconds. '
									if $t; 
								
								if( ! $mailout->still_around ){
									warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Seems to have been removed. exit()ing'
							            if $t; 
									exit(0); 
								}
								
								# Let's make sure I'm still supposed to be working on stuff: 
								if($batch_status->{controlling_pid} == $$){ 
									
									# Good to go.
								
									warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . " Controlling PID check says we're ($$) still in control."
										if $t;
										
								}
								else { 
									warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . 
										 ' Problem! Another process (Current PID: ' . $$ . ', Controlling PID: ' . 
										   $batch_status->{controlling_pid} .' has taken over sending for this mailing! ' . 
										   ' exit()ing to allow that process to do it\'s business!'; 
									exit(0); 
									
								}
								
																
	                            $mailout->unlock_batch_lock;
	                            $mailout->batch_lock;
	
								$batch_start_time = time; 
                            
	                       } else { 
                        
	                            warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' restart_mailings_after_each_batch is enabled.'
	                                if $t; 
                            
	                            close(MAILLIST)
	                                or carp "Problems closing the temporary sending file (" . $mailout->subscriber_list ."), Reason: $!";

	                            warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' unlocking batch lock.'
	                                if $t; 
                                
								$mailout->unlock_file($lock);
								unlink($mailout->subscriber_list . 'lock'); 

	                            $mailout->unlock_batch_lock;
                            
	                            # We only want to, exit(0) if we have more mailings to go. 
	                            # If we don't have any more to do, we have to do all the 
	                            # cleanup, so let's not go quite yet. 
                            
	                            if($batch_status->{total_sent_out} < $batch_status->{total_sending_out_num}){ # We have more mailings to do. 
	                                warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' As far as I can tell, there\'s more mailing to do.'
	                                    if $t; 
	                                exit(0); 
	                            }
                        
	                        }                          
						}
						else { 
						    warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' More messages to be sent in this batch ' 
						        if $t; 
					
						}
					
			        }
				}
			}
			         			
			warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' We\'ve gone through the MAILLIST, it seems?'
			    if $t; 
			
			# Net::SMTP Object cleanup
			if(defined($self->net_smtp_obj)){ 
				# Guess we gotta quit the connection that's still going on... 
				warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Quitting a SMTP connection that\'s still going on... '
					if $t; 
				$self->net_smtp_obj->quit
               		or carp "problems 'QUIT'ing SMTP server.";
			}
			
			# SES Object cleanup
			if(defined($self->ses_obj)){
				$self->ses_obj(undef); 
			}
			my $ending_status = $mailout->status({-mail_fields => 0}); # most likely safe to called status() as much as I'd like...
			
			my $unformatted_end_time = time; 
			if( $self->{ls}->param('get_finished_notification')  == 1){ 			
			    
			    warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' sending finished notification' 
			        if $t; 
			        
                $self->_email_batched_finished_notification(
                    -start_time   => $ending_status->{first_access}, 
                    -end_time     => $unformatted_end_time,
                    -emails_sent  => $ending_status->{total_sent_out},
                    -last_email   => $stop_email,
                    -fields       => \%fields, 
                ); 
                                                        
			}

			my $f_l_subject = $fields{Subject}; 
			   $f_l_subject =~ s/\r|\n//g;
			my $mass_mail_finished_log = join(
				"\t", 
				"Message-Id: "     . $mailout_id, 
				"Subject: "        . $f_l_subject, 
				"Started: "        . scalar(localtime($ending_status->{first_access})), 
				"Finished: "       . scalar(localtime($unformatted_end_time)), 
				"Mailing Amount: " . $mass_mailing_count,
			); 
			
			if($DADA::Config::LOG{mass_mailings} == 1){ 
				$self->{mj_log}->mj_log(
					$self->{list}, 
					'Mass Mailing Completed',
					$mass_mail_finished_log
				); 
			}
			$mailout->log($mass_mail_finished_log);
			
			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' closing MAILLIST'
			    if $t; 
			    
			close(MAILLIST)
			    or carp "Problems closing the temporary sending file (" . $mailout->subscriber_list ."), Reason: $!";
			
			
			#warn "unlocking batch.."; 
			warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' unlocking batch lock' 
			    if $t; 
			
			
			$mailout->unlock_file($lock);    
			unlink($mailout->subscriber_list . 'lock');
		    $mailout->unlock_batch_lock; 

			warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' cleaning up!'
			    if $t; 
            $mailout->clean_up; 
            

			# Undef'ing net_smtp_obj if needed... 
			if(defined($self->net_smtp_obj)){ 	
				
				warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Quitting a SMTP connection at end of mass_send' 
					if $t;
					
				$self->net_smtp_obj->quit
			   		or carp "problems 'QUIT'ing SMTP server.";
			
				$self->net_smtp_obj(undef);
			
			}	
			
			if(defined($self->ses_obj)){
				$self->ses_obj(undef); 
			}
			

			warn  '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' We\'re done. exit()ing!' 
			    if $t;
           	exit(0);		 

		} elsif ($! =~ /No more process/) {
			
			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Getting error in fork: $! - sleeping for 5 seconds and retrying (don\'t hold your breath)'
			     if $t; 
			# EAGAIN, supposedly recoverable fork error
			sleep 5;
			redo FORK;
			
		} else {
			
			warn '[' . $self->{list} . '] Mass Mailing:' . $mailout_id . ' Fork wasn\'t so successful.'
				if $t;
			# weird fork error
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error in Mail.pm, Unable to Fork new process to mass e-mail list message: $!\n";
			}
		}
	}





sub _clarify_dbi_stuff {

    my $self = shift;
    my ($args) = @_;

    my $mailout = $args->{-dmmo_obj};

    ##################################################################
    # DEV: EXPLANATION:
    # This is all to attempt that,
    # * DBI handles made before the fork aren't used
    #   in the child process
    # * Any DBI handles in the child process don't exist
    #   in the parent process
    # * Any references to DBI Handles we didn't get to
    #   will have the, InactiveDestroy attribute set
    #   so that when the child process goes, the parent will
    #   copy will still be around.
    ##################################################################

    if (   $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/
        || $DADA::Config::ARCHIVE_DB_TYPE  =~ m/SQL/
        || $DADA::Config::SETTINGS_DB_TYPE =~ m/SQL/ )
    {

        require DBI;
        if ( $DBI::VERSION >= 1.49 ) {
            my %drivers = DBI->installed_drivers;
            for my $drh ( values %drivers ) {
                map { $drh->{InactiveDestroy} = 1 } @{ $drh->{ChildHandles} };
            }
        }

        # Our own DBI handle:
        require DADA::App::DBIHandle;
        my $dbih = DADA::App::DBIHandle->new;
        my $dbh  = $dbih->dbh_obj;

        # Let's get rid of the ones that are known:
        # DADA::MailingList::Settings
        $self->{ls}->{dbh}->{InactiveDestroy} = 1;
        $self->{ls}->{dbh}                    = undef;
        $self->{ls}->{dbh}                    = $dbh;
        $self->{list_info}                    = $self->{ls}->params;

        my $pass_id   = $mailout->_internal_message_id;
        my $pass_type = $mailout->mailout_type;

        # DADA::Mail::MailOut uses DADA::MailingList::Settings and
        # DADA::MailingList::Subscribers
        # The only way to figure this out totally is to get rid of the
        # current DADA::Mail::MailOut object and re-make it. Weird, huh?

        $mailout = undef;
        $mailout = DADA::Mail::MailOut->new(
            {
                -list   => $self->{list},
                -ls_obj => $self->{ls}
            }
        );

        $mailout->associate( $pass_id, $pass_type );

        require DADA::App::Subscriptions::ConfirmationTokens;
        $self->child_ct_obj(
            DADA::App::Subscriptions::ConfirmationTokens->new() );
        $self->child_ct_obj->{dbh} = $dbh;

        ## And many, many more,
        ## We'd probably have to undef and make a new object for
        ## DADA::Mail::MailOut....
        ## And what else?
        ## DADA::Mail::MailOut needs a way to pass the shared database (now new)
        ## Handle...

    }
    else {
        require DADA::App::Subscriptions::ConfirmationTokens;
        $self->child_ct_obj(
            DADA::App::Subscriptions::ConfirmationTokens->new() );
    }

    return $mailout;

}




sub _set_clickthrough_tracking_stuff {

    my $self = shift;
    my ($args) = @_;

    my $fields = $args->{-fields};

    ##################################################################
    # ClickThrough Tracking Stuff
    # This sometimes fail, if the SQL connection is dropped.
    # ! I've currently taken off the optimization that works around
    # this problem, in hopes that we can find a solution, that doesn't
    # involve a workaround, but a fix, instead.
    #

    # DEV: Should we only use this for mass mailings to, "list"?!
    # This still sucks, since this'll reparse after each restart.
    require DADA::Logging::Clickthrough;
    my $ct = DADA::Logging::Clickthrough->new(
        {
            -list => $self->{list},

            # I guess one way to find out if the
            # InactiveDestroy stuff is working,
            # Is isf DADA::Logging::Clickthrough
            # is working without this kludge:
            #
            #-li   => $self->{ls}->params,
            #
        }
    );
    if ( $ct->enabled ) {
        $fields = $ct->parse_email(
            {
                -as_ref => 1,
                -fields => $fields,
                -mid    => $fields->{'Message-ID'},

            }
        );
        undef $ct;

        # And, that's it.
    }
    #
    ##################################################################

	return %{$fields}; 
	
}



sub _log_sending_error { 
	
	my $self = shift; 
	my ($args) = @_; 
	my $r;
	
	my $mid = $args->{-mid}; 
	   $mid =~ s/\.(.*?)$//; 

	# -adjust_total_recipients doesn't do anything, right now. 
	try { 
		require DADA::Logging::Clickthrough;
	    $r = DADA::Logging::Clickthrough->new( { -list => $self->{ list } } );
	    if ( $r->enabled ) {
	        $r->error_sending_to_log(
	            {
	                -mid   => $mid,
	                -email => $args->{-email},
	            }
	        );
	    }
	} catch { 
		carp "Problems logging error w/sending to: " . $args->{-email} . " (oh, what a world!): $_"; 
		return undef; 
	};
	
	undef $r; 
	
	return 1; 
	
}
sub _adjust_bounce_score {
	 
	my $self = shift; 
	
	if(
		$self->list_type eq 'list'
	 && $self->mass_test != 1
	) { 
		# If we need to, let's decay the bounce scorecard:
		if($self->{ls}->param('bounce_handler_decay_score') >= 1){ 
			#if(the bounce handler is enabled for this){ (which currently, there is no "off" for the bounce handler...
				require DADA::App::BounceHandler::ScoreKeeper;
				my $bhsk = DADA::App::BounceHandler::ScoreKeeper->new({-list => $self->{list}});
				   $bhsk->decay_scorecard;
				undef $bhsk; 
				return 1; 
			#}
		}
	}

}


sub _content_transfer_encode { 

    my $self = shift; 
	my %args = (-fields => {}, @_); 
    
	if(!defined($self->{list})){ 
 		return %{$args{-fields}}; 
	}

    
    my $fields = $args{-fields}; 
    
    my %new_fields; 
    
    my $msg = undef; 
    my $orig_body = $fields->{Body};
  
    $fields->{Body} = undef; 
    delete $fields->{Body};  
        
    require MIME::Parser; 
    my $parser = new MIME::Parser; 
       $parser = DADA::App::Guts::optimize_mime_parser($parser); 

	
    my $encoding = $self->{ls}->param('plaintext_encoding'); 
    if($fields->{'Content-type'} =~ m{html}){ 
        $encoding = $self->{ls}->param('html_encoding'); 
     }
        
    my $entity; 
	eval { 
	
	    $entity  = MIME::Entity->build(
                       Encoding => $encoding,
                       Type     => $fields->{'Content-type'}, 
                       Data     => safely_encode( $orig_body),
        );
        
        
        
        for(keys %$fields){ 
            next if $_ eq 'Content-type'; # Yeah, Content-Type, no Content-type. Weird. Weeeeeeeird.
            next if $_ eq 'Content-Transfer-Encoding'; 
            $entity->head->add($_, safely_encode( $fields->{$_})); 
        }
        
        
        $entity->sync_headers('Length'      =>  'COMPUTE',
							  'Nonstandard' =>  'ERASE');
		

		
        my $head = $entity->head->as_string;
	       $head   = safely_decode( $head);

		# encoded. YES. 
        my $body = $entity->body_as_string;
	       $body   = safely_decode( $body);

	    %new_fields = $self->return_headers($head);
               
        $new_fields{Body} = $body; 
                               
	};
        
    if($@){ 
        carp "problem adding 'Content-Transfer-Encoding' to message! skipping. $@";

       return %{$args{-fields}}; 
    } else { 
    
        return %new_fields; 
    }
   
   

}



sub _domain_for_smtp { 

	my $self = shift; 
	my ($user, $domain) = split('@', $self->{ls}->param('list_owner_email'));
	return $domain;

}




sub _strip_fields { 
	my $self = shift; 
	my %fields = @_; 
	require Email::Address;
	
	if(my $to_temp = (Email::Address->parse($fields{To}))[0]){ 
	   $fields{To} = $to_temp->address();  	
	}
	
	if(my $from_temp = (Email::Address->parse($fields{From}))[0]){ 
	   $fields{From} = $from_temp->address();  
	 }
	 
	return %fields;
}




sub _remove_blank_headers { 
	my $self = shift; 
	my ($args) = @_; 
	my $headers = $args->{-headers}; 
	
	for(keys %$headers){ 
		if(!defined($headers->{$_})){ 
			delete($headers->{$_}); 			
		}
		elsif($headers->{$_} eq undef){ 
			delete($headers->{$_}); 
		}
	}	
	
	return %$headers; 
	
}





sub _make_general_headers { 
	
	my $self = shift; 
	my %gh; 
	
	# I don't understand why this check is here. 
	# Ah, I think there are some places where you can send, without actually have a list. 
	# Huh.
	# PHRASE, ADDRESS, [ COMMENT ]
	require Email::Address;		

	my $ln = undef;
	my $fm = undef; 
	if(defined($self->{list})){ 
		require  DADA::App::FormatMessages; 
		$fm = DADA::App::FormatMessages->new(
			-List => $self->{list}
		); 
	   	$ln = $fm->_encode_header(
			'just_phrase',
			DADA::App::Guts::escape_for_sending(
				$self->{ls}->param('list_name')
			)
		);	   
	}
	
	my $from_phrase  = undef; 
	my $from_address = undef; 
		
	if($self->im_mass_sending == 1){ 
		
		if($self->list_type eq 'invitelist'){ 
			
			$from_phrase  = $self->{ls}->param('invite_message_from_phrase'); 
			$from_address = $self->{ls}->param('list_owner_email');
			
		}
		else { 
			$from_phrase  = $self->{ls}->param('mailing_list_message_from_phrase');
			$from_address = $self->{ls}->param('list_owner_email');
		}
	}
	else { 
		if(defined($self->{list})){ 
			$from_phrase  = $ln;
			$from_address = $self->{ls}->param('list_owner_email');	
		}
		else { 
			$from_phrase  = ''; 
			$from_address = '';
		}
	}
	
	if(defined($self->{list})){
	
		$gh{From} = $fm->format_phrase_address($from_phrase, $from_address); 
		# time  + random number + sender, woot!
		require DADA::Security::Password; 	
		my $ran_number = DADA::Security::Password::generate_rand_string('1234567890');

		my ($name, $host) = split('@', $from_address, 2); 
		$gh{'Message-ID'} = '<' .  
							DADA::App::Guts::message_id() . 
							'.'. 
							$ran_number . 
							'@' . 
							$host . 
							'>';					
		
		# Deprecated.
		if($self->{ls}->param('print_errors_to_header') == 1){ 	
			$gh{'Errors-To'} = $fm->format_phrase_address(
				undef, 
				$self->{ls}->param('admin_email')
			);
		} 	

		if(defined($self->{ls}->param('priority'))) { 
		    if($self->{ls}->param('priority') ne 'none'){ 
		        $gh{'X-Priority'}  = $self->{ls}->param('priority');
		    }
	    }
	}
	else { 
		# No list... 
	}
	return %gh;
}


# _Tz and _Date are swiped from: http://search.cpan.org/src/JIMT/Mail-Bulkmail-3.12/Bulkmail.pm

sub _Tz {

	my $self = shift;
	my $time = shift || time;

	my ($min, $hour, $isdst)	= (localtime($time))[1,2,-1];
	my ($gmin, $ghour, $gsdst)	= (gmtime($time))[1,2, -1];

	my $diffhour = $hour - $ghour;
	$diffhour = $diffhour - 24 if $diffhour > 12;
	$diffhour = $diffhour + 24 if $diffhour < -12;

	($diffhour = sprintf("%03d", $diffhour)) =~ s/^0/\+/;

	return $diffhour . sprintf("%02d", $min - $gmin);

};




sub _Date {

	my $self 	= shift;

	my @months 	= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @days 	= qw(Sun Mon Tue Wed Thu Fri Sat);

	my $time = time;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday) = localtime($time);



	return sprintf("%s, %02d %s %04d %02d:%02d:%02d %05s",
		$days[$wday], $mday, $months[$mon], $year + 1900, $hour, $min, $sec, $self->_Tz($time));


};

sub list_headers { 
	
	my $self = shift; 
	
	if(defined($self->{list})){

		my %lh;
	
		# List
		$lh{'List'}             =   $self->{list};
	
		# List-URL
		$lh{'List-URL'}         =   '<<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/>';

		# List-Subscribe
		if($self->{ls}->param('closed_list') == 1){ 
			if(exists($lh{'List-Subscribe'})){ 
				delete($lh{'List-Subscribe'});
			}
		}
		else { 
			$lh{'List-Subscribe'}   =   '<<!-- tmpl_var PROGRAM_URL -->/s/<!-- tmpl_var list_settings.list -->/<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/>'; 
		}

		$lh{'List-Unsubscribe'} =   '<mailto:<!-- tmpl_var list_settings.list_owner_email -->?Subject=Unsubscribe%20from%20<!-- tmpl_var list_settings.list_name escape="url" -->>, <<!-- tmpl_var list_unsubscribe_link -->>'; 

		# List-Owner
		$lh{'List-Owner'}       =   '<<!-- tmpl_var list_settings.list_owner_email -->>';
	
		# List-Archive
		if($self->{ls}->param('show_archives') ne "0"){
			$lh{'List-Archive'} =  '<' . $DADA::Config::PROGRAM_URL.'/archive/'. $self->{list} . '/>';   
		}
	
	
		# List-Post
		# http://www.faqs.org/rfcs/rfc2369.html
	    # The List-Post field describes the method for posting to the list. 
		# This is typically the address of the list, but MAY be a moderator, 
		# or potentially some other form of submission. For the special case 
		# of a list that does not allow posting (e.g., an announcements list), 
		# the List-Post field may contain the special value "NO".
		if(
		   $self->{ls}->param('group_list')           == 1 && 
		   $self->{ls}->param('discussion_pop_email')
		  ){ 
			$lh{'List-Post'} = '<mailto:' . $self->{ls}->param('discussion_pop_email') . '>';
		}
		else { 
			$lh{'List-Post'} = 'NO';
		
		}
	
		# List-ID
		# Is there a reason I continue to use this? 	
		# http://www.faqs.org/rfcs/rfc2111.html
		eval "require Net::Domain";
		if(!$@){ 
		
			my $domain = undef; 
		
			if($self->test || $DADA::Config::PROGRAM_URL =~ /http\:\/\/localhost/){ 
				# just to speed things up... 
			} 
			else { 
			
				$domain = Net::Domain::hostfqdn() || 
				carp "no domain found for: Net::Domain::hostfqdn()";
			}
		
			$domain ||= 'localhost'; # not sure about this one, I believe if you use localhost, you need a random # as well...
			$lh{'List-ID'} = '<' . $self->{list} .'.'. $domain .'>';
		}else{ 
			carp "Net::Domain should be installed!";
		}
		return %lh;
	}
	else { 
		return (); 
	}
}


sub _cipher_decrypt { 
	my $self = shift; 
	my $str  = shift; 
	require DADA::Security::Password; # why wasn't this here before?!
	return  DADA::Security::Password::cipher_decrypt($self->{ls}->param('cipher_key'), $str);
}




sub _pop_before_smtp { 
	my $self = shift; 
	my $status = 0; 
	
	require DADA::Security::Password; 
	
	my %args = (-pop3_server         => $self->{ls}->param('pop3_server'),
	            -pop3_username       => $self->{ls}->param('pop3_username'),
	            -pop3_password       => $self->_cipher_decrypt($self->{ls}->param('pop3_password')),
	            -pop3_auth_mode      => $self->{ls}->param('pop3_auth_mode'),
	            -pop3_use_ssl        => $self->{ls}->param('pop3_use_ssl'),
	            -verbose             => 0, 
	            @_);          
	            		
	if(
	   ($self->{ls}->param('use_pop_before_smtp') == 1) &&
	   ($args{-pop3_server})                            &&
	   ($args{-pop3_username})                          &&
	   ($args{-pop3_password})
	){
		
		$args{-pop3_server}		= make_safer($args{-pop3_server}); 
		$args{-pop3_username}   = make_safer($args{-pop3_username});
		$args{-pop3_password}   = make_safer($args{-pop3_password});
		
		return (undef, 0, '') if ! $args{-pop3_server};
		return (undef, 0, '') if ! $args{-pop3_username}; 
		return (undef, 0, '') if ! $args{-pop3_password}; 
		
        require DADA::App::POP3Tools; 
        
        my $lock_file_fh = DADA::App::POP3Tools::_lock_pop3_check(
								{
									name => 'dada_mail_send.lock',
								}
							);
        
        my ($pop, $status, $log) = DADA::App::POP3Tools::mail_pop3client_login(
	
            {
                server    => $args{-pop3_server},
                username  => $args{-pop3_username},
                password  => $args{-pop3_password},           
                USESSL    => $args{-pop3_use_ssl},
                AUTH_MODE => $args{-pop3_auth_mode},
                verbose   => $args{-verbose},
            }
        ); 
        
        my $count = $pop->Count; 
        
        $pop->Close();
        DADA::App::POP3Tools::_unlock_pop3_check(
			{
				name => 'dada_mail_send.lock',
				fh   => $lock_file_fh, 
			},
		);
        return ($status); 
                

	}
}




sub _email_batched_finished_notification {

    my $self = shift;

	# Amazon SES may have a limit of 1 message/sec, 
	# so we give ourselves a little space after a mass mailing
	if(
		$self->{ls}->param('sending_method') eq 'amazon_ses' 
	 || $self->{ls}->param('smtp_server') =~ m/amazonaws\.com/){
		sleep(1); 
	}
	#

	
    # DEV:
    # Dum... we need ta hashref this out...

    # Let's turn this stuff off:
    $self->im_mass_sending(0);

    my %args = (
        -fields      => {},
        -start_time  => undef,
        -end_time    => undef,
        -emails_sent => undef,
        -last_email  => undef,
        @_
    );


    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new(
		-List        => $self->{list},  
		-ls_obj      => $self->{ls},
	);
	
    my $fields               = $args{-fields};
    my $formatted_start_time = '';
    my $formatted_end_time   = '';

    if ( defined($args{-start_time} )) {

        my ( $s_sec, $s_min, $s_hour, $s_day, $s_month, $s_year ) =
          ( localtime( $args{-start_time} ) )[ 0, 1, 2, 3, 4, 5 ];
        $formatted_start_time = sprintf(
            "%02d/%02d/%02d %02d:%02d:%02d",
            $s_month + 1,
            $s_day, $s_year + 1900,
            $s_hour, $s_min, $s_sec
        );

    }

    if ( defined($args{-end_time}) ) {

        my ( $e_sec, $e_min, $e_hour, $e_day, $e_month, $e_year ) =
          ( localtime( $args{-end_time} ) )[ 0, 1, 2, 3, 4, 5 ];
        $formatted_end_time = sprintf(
            "%02d/%02d/%02d %02d:%02d:%02d",
            $e_month + 1,
            $e_day, $e_year + 1900,
            $e_hour, $e_min, $e_sec
        );

    }

    my $total_time =
      formatted_runtime( ( $args{-end_time} - $args{-start_time} ) );
      
      require DADA::App::ReadEmailMessages; 
      my $rm = DADA::App::ReadEmailMessages->new; 
      my $msg_data = $rm->read_message('mass_mailing_finished_notification.eml'); 
  	
  	


    require MIME::Entity;
    my $entity = MIME::Entity->build(
        Type => 'multipart/mixed',
        To   => safely_encode( $fm->format_phrase_address('List Owner For ' . $self->{ls}->param('list_name'), $self->{ls}->param('list_owner_email'))),
        Subject  => safely_encode( $msg_data->{subject}),
        Datestamp => 0,

    );

    $entity->attach(
        Type        => 'text/plain',
        Data        =>  safely_encode( $msg_data->{plaintext_body}),
        Encoding    => $self->{ls}->param('plaintext_encoding'),
        Disposition => 'inline',

    );

    my $att;
    for ( keys %$fields ) {
        next if $_ eq 'Body';
        $att .= $_ . ': ' . $fields->{$_} . "\n"
          if defined( $fields->{$_} ) && $fields->{$_} ne "";
    }
    $att .= "\n" . $fields->{Body};

	# Amazon SES seems to not allow you to attach message/rfc822 attachments. 
	# Not sure why!
	# warn q{ $self->{ls}->{sending_method} } . $self->{ls}->{sending_method}; 
	my $disposition = 'inline'; 
	my $type        = 'message/rfc822';
	if($self->{ls}->param('sending_method') eq 'amazon_ses' 
	|| $self->{ls}->param('smtp_server') =~ m/amazonaws\.com/){
			$disposition = 'attachment'; 
			$type        = 'text/plain'; 
	}
		
	    $entity->attach(
	        Type        => $type,
	        Disposition => $disposition,
	        Data => safely_decode( safely_encode( $att ) ),
	    );

	
	my $expr = 0; 
	if($self->{ls}->param('enable_email_template_expr') == 1){ 
		$expr = 1; 
	}

    my $n_entity = $fm->email_template(
        {
            -entity                   => $entity,
            -list_settings_vars       => $self->{ls}->params,
            -list_settings_vars_param => { -dot_it => 1 },
            -vars                     => {
                addresses_sent_to   => $args{-emails_sent},
                mailing_start_time  => $formatted_start_time,
                mailing_finish_time => $formatted_end_time,
                total_mailing_time  => $total_time,
                last_email_send_to  => $args{-last_email},
                message_subject     => safely_encode( $fm->_decode_header($fields->{Subject} )),
            }, 
			-expr => $expr, 
        }
    );

	my $body = $n_entity->body_as_string; 
	   $body = safely_decode($body); 

    $self->send(
	 	$self->return_headers( 
			safely_decode(
				$n_entity->head->as_string
			), 
		),
        Body => $body, 
	);

}




sub _verp { 

	my $self = shift; 
	my $to   = shift; 
	
	croak "no email passed!" 
		if ! $to; 
		
	require Email::Address;
	require Mail::Verp; 
	
	if(my $to_temp = (Email::Address->parse($to))[0]){ 
	   $to = $to_temp->address();  	
	}
		
		my $mv = Mail::Verp->new;
		   $mv->separator($DADA::Config::MAIL_VERP_SEPARATOR );
		
		if($self->{ls}->param('set_smtp_sender') == 1){ 
            return $mv->encode( $self->{ls}->param('admin_email'), $to ); 
        }else{ 
            return $mv->encode( $self->{ls}->param('list_owner_email'), $to ); 
        }
        
}




sub _mail_merge {

    my $self = shift;
    my $orig_entity;

    my ($args) = @_;

    if ( !exists( $args->{-entity} ) ) {
        croak 'you need to pass the -entity parameter';
    }
    else {
        $orig_entity = $args->{-entity};
    }

    if ( !exists( $args->{-data} ) ) {
        croak 'you need to pass the -data parameter';
    }

    if ( exists( $args->{-fm_obj} ) ) {

        # ...
    }
    else {
        croak "you MUST pass the -fm_obj parameter!";
    }

# So all we really have to do is label and arrange the values we have and populate the email message.
# Here we go:

    my $data = $args->{-data};

    my %labeled_data    = ();
    my $subscriber_vars = {};

    $subscriber_vars->{'subscriber.email'}        = shift @$data;
    $subscriber_vars->{'subscriber.email_name'}   = shift @$data;
    $subscriber_vars->{'subscriber.email_domain'} = shift @$data;

# DEV: These are sort of weird - I'd rather get rid of global list sending altogether. It's messy.
    $labeled_data{'list_settings.list'}      = shift @$data;
    $labeled_data{'list_settings.list_name'} = shift @$data;
    $labeled_data{message_id}                = shift @$data;

	# type is passed in, $self->list_type
    my $confirmation_token = $self->_make_token(
        {
            -list   => $labeled_data{'list_settings.list'},
            -email  => $subscriber_vars->{'subscriber.email'},
            -msg_id => $labeled_data{message_id},
        }
    );

    $labeled_data{'list.confirmation_token'} = $confirmation_token;    # list invites? Messed up.
    $labeled_data{'list_unsubscribe_link'} = $DADA::Config::PROGRAM_URL . '/t/'
      . $labeled_data{'list.confirmation_token'} . '/';

    my $merge_fields = $self->{merge_fields};

    my $i = 0;
    for ( $i = 0 ; $i <= $#$merge_fields ; $i++ ) {

# DEV: Euh - this is basically doing what I want -
# caching the fallback field stuff,
# so that we only grab this info once, and reuse it.
# this stops multiple calls to the DADA::ProfileFieldsManager->get_all_field_attributes method
# which is good.

        if ( DADA::App::Guts::strip( $args->{-data}->[$i] ) ) {
            $subscriber_vars->{ 'subscriber.' . $merge_fields->[$i] } =
              $data->[$i];
        }
        else {
            $subscriber_vars->{ 'subscriber.' . $merge_fields->[$i] } =
              $self->{field_attr}->{ $merge_fields->[$i] }->{fallback_value};
        }
    }

    # Add the, "To:" header (very important!)
    my $To_header = '';

    if ( $self->list_type eq 'invitelist' ) {
        $To_header = $args->{-fm_obj}->format_phrase_address(
            $self->{ls}->param('invite_message_to_phrase'),
            $subscriber_vars->{'subscriber.email'}
        );
    }
    else {
        $To_header =
          $args->{-fm_obj}->format_phrase_address(
            $self->{ls}->param('mailing_list_message_to_phrase'),
            $subscriber_vars->{'subscriber.email'} );
    }
    if ( $orig_entity->head->get( 'To', 0 ) ) {
        $orig_entity->head->delete('To');
    }
    $orig_entity->head->add( 'To', $To_header );

    my $expr = 0;
    if ( $self->{ls}->param('enable_email_template_expr') == 1 ) {
        $expr = 1;
    }

    #carp "ORIGINAL ENTITY: \n";
    #carp '-' x 72 . "\n";
    #carp $orig_entity->as_string;
    #carp '-' x 72 . "\n";

    #carp "LABELED DATA\n" ;
    #carp '-' x 72 . "\n";
    #use Data::Dumper;
    #carp Dumper({%labeled_data});
    #carp '-' x 72 . "\n";

    my $entity = $args->{-fm_obj}->email_template(
        {
            -entity                   => $orig_entity,
            -list_settings_vars       => $self->{ls}->params,
            -list_settings_vars_param => { -dot_it => 1 },
            -subscriber_vars          => $subscriber_vars,
            -vars                     => {

                # You know, I need at least this:
                message_id => $labeled_data{message_id},
                %labeled_data,
            },
            -expr => $expr,
        }
    );

    #carp "MODIFIED ENTITY\n";
    #carp '-' x 72 . "\n";
    #carp $entity->as_string;
    #carp '-' x 72 . "\n";

    my $msg = $entity->as_string;
    $msg = safely_decode($msg);

    undef($entity);
    undef($orig_entity);
    my ( $h, $b ) = split( "\n\n", $msg, 2 );
    undef($msg);

    my %final = ( $self->return_headers($h), Body => $b, );

    return %final;
}


sub _make_token {

    my $self = shift;
    my ($args) = @_;
    my $token;

    if ( $self->list_type eq 'invitelist' ) {

        # this is to confirm a subscription
        $token = $self->child_ct_obj->save(
            {
                -email => $args->{-email},
                -data  => {
                    list        => $args->{-list},
                    flavor      => 'sub_confirm',
                    type        => 'list',
                    remote_addr => $ENV{REMOTE_ADDR},
                    invite      => 1,
                }
            }
        );
    }
    else {

		my $token_type = 'unsub_confirm'; 
#		if($self->{ls}->param('private_list') == 1) { 
#			$token_type = 'unsub_request'; 
#		}
        $token = $self->child_ct_obj->save(
            {
                -email => $args->{-email},
                -data  => {
                    list       => $args->{-list},
                    type       => 'list',
                    flavor     => $token_type,
                    mid        => $args->{-msg_id},
                    email_hint => DADA::App::Guts::anonystar_address_encode(
                        $args->{-email}
                    ),
                },
            }
        );

    }

    return $token;
}



sub _massaged_for_archive { 

	my $self       = shift; 
	my $fields     = shift; 
	my $msg; 

	
	for(@DADA::Config::EMAIL_HEADERS_ORDER){ 
		next if $_ eq 'Body'; 
		next if $_ eq 'Message'; # Do I need this?!
		
#		# Currently, it only looks like the subject is giving us worries: 
#		# (But, it really should be everything) 
#		if($_ =~ m/Subject|From|To|Reply\-To|Errors\-To|Return\-Path/){ 
#			my $fm = DADA::App::FormatMessages->new(-List => $self->{list}); 
#			# What if it's already encoded? DORK?!
#			$fields->{$_} = $fm->_encode_header($_, $fields->{$_});  
#			
#		}
#		else { 
#			#
#		}
		$msg .= $_ . ': ' . $fields->{$_} . "\n"
		if((defined $fields->{$_}) && ($fields->{$_} ne ""));


	}
	
	$msg .= "\n" . $fields->{Body};
	
	return $msg; 
}




sub _log_sub_count {

    my $self = shift;
	my ($args) = @_; 
	
    return
      if $self->list_type ne 'list';

    return
      if $self->mass_test;

    my $log_it = 0;

    require DADA::Logging::Clickthrough;
    my $r = DADA::Logging::Clickthrough->new(
        {
            -list => $self->{list},
            -ls   => $self->{ls},
        }
    );
    return if !$r->enabled;

    my $msg_id = $args->{-msg_id};
    $msg_id =~ s/\<|\>//g;
    $msg_id =~ s/\.(.*)//;

    my $num_subscribers      = $args->{-num_subscribers};
	my $num_total_recipients = $args->{-num_total_recipients}; 
	
    warn 'logged_subscriber_count is returning, "'
      . $r->logged_subscriber_count( { -mid => $msg_id } ) . '"'
      if $t;

    if ( $self->restart_with ) {
        if ( $r->logged_subscriber_count( { -mid => $msg_id } ) ) {
            # We got it.
            $log_it = 0;
        }
        else {
            # We don't got it?!
            warn '_log_sub_count: $msg_id: '
              . $msg_id
              . '$num_subscribers:'
              . $num_subscribers
              if $t;
            $log_it = 1;
        }
    }
    else {
        warn '_log_sub_count: $msg_id: '
          . $msg_id
          . '$num_subscribers:'
          . $num_subscribers
          if $t;
        $log_it = 1;

    }

    if ( $log_it == 1 ) {
        $r->num_subscribers_log(
            {
                -mid => $msg_id,
                -num => $num_subscribers
            }
        );
        $r->num_subscribers_log(
            {
                -mid => $msg_id,
                -num => $num_subscribers,
            }
        );
        $r->total_recipients_log(
            {
                -mid => $msg_id,
                -num => $num_total_recipients,
            }
        );
    }
    else {
		#... 
    }

}






sub mass_test_recipient { 

    warn 'mass_test_recipient'
        if $t; 
    
    my $self           = shift; 
    my $test_recipient = shift; 
        
    warn '$test_recipient ' . $test_recipient
     if $t; 
    
    if(! $test_recipient){ 
        
        if(! $self->{test_recipient}){ 
        
            return $self->{ls}->param('list_owner_email');
            
             warn "sending over the list owner as the test recipient.."
                if $t; 
        
        }else{ 
        
            warn "sending over " . $self->{test_recipient}
                if $t; 
            return $self->{test_recipient}; 
        
        }
        
    }else{ 
        
        if(DADA::App::Guts::check_for_valid_email($test_recipient) == 0){ 
            
            $self->{test_recipient} = $test_recipient;
            
        }else{
             warn "Test Recipient, '$test_recipient' is not a valid email address!"
                if $t; 
       }
    }
}






sub DESTROY { 



	# DESTROY ALL ASTROMEN! 
	my $self = shift; 

	# This is probably a really stupid place to put this... 
	
}


1;


=pod

=head1 NAME

DADA::Mail::Send

=head1 SYNOPSIS

 # Initialize: 
 my $mh = DADA::Mail::Send->new(
			 { 
				-list => 'mylist', 
			}
		); 
 
 # Send something out: 
 $mh->send(
	From    => 'me@example.com', 
	To      => 'you@example.com', 
	Subject => "this is the subject', 
	Body    => "This is the body of the message', 
  ); 
 
 # Send a whole lot of things out: 
 $mh->mass_send( 
	{ 
		-msg => {
			Subject => "this is the subject', 
			Body    => "This is the body of the message', 
 		},
	}
); 

=head1 DESCRIPTION

C<DADA::Mail::Send> is in charge of sending messages, via email. 

There's two ways this is done - 

The first is using the C<send> method. This is used to send one message to one person. 

The second way is using the C<mass_send> method. This sends a mass mailing to an entire list. 


=head2 Warning: Thar Be Dragons

There's many coding practices in this module that we would like to change for the better. It's not the easiest to read code. 


=head1 Public Methods

=head2 new

 my $mh = DADA::Mail::Send->new(
			 { 
				-list   => 'mylist', 
				-ls_obj => $ls,
			}
		);

Creates a new C<DADA::Mail::Send> object. 

C<new> requires one argument, C<-list>, which should hold a valid C<listshortname>. 

C<new> has one optional argument, C<-ls_obj>, which should hold a valid C<DADA::MailingList::Settings> object, like so: 

 use DADA::MailingList::Settings; 
 use DADA::Mail::Send; 

 my $list = 'mylist'; 

 my $ls = DADA::MailingList::Settings->new({-list => $list}); 
 
 my $mh = DADA::Mail::Send->new(
			{
				-list   => $list, 
				-ls_obj => $ls,  
			}
		  );

Passing a C<DADA::MailingList::Settings> object is just an optimization step and is not required. With the SQL backend, it does mean one less SQL query, which is nice. 

=head2 send

 # Send something out: 
 $mh->send(
 	To      => 'you@example.com', 
 	Subject => 'this is the subject', 
 	Body    => 'This is the body of the message', 
  ); 

Sends a message, via email. 

Takes a variety of arguments. The arguments should be various B<Email Headers> and the body of the email message, passed in C<Body>

For example, if you have an email message that looks like this: 

 From: me@example.com
 To: you@example.com
 Subject: This is the Subject!
 Body: This is the Body!

You would pass it to, C<send> like so: 

 # Send something out: 
 $mh->send(
	From    => 'me@example.com',
 	To      => 'you@example.com', 
 	Subject => 'This is the Subject!', 
 	Body    => 'This is the Body!', 
  );

No arguments are I<really> necessary, although your message isn't going to get very far, or have much content. 

At the very minimum, you probably want to pass, C<To>, C<Subject> and, C<Body>. All other headers will be filled out to something 
that's pretty sane. 

For example, if the C<From> argument isn't passed, the B<List Owner> of the list is used. This proves to be useful. 

This method is somewhat strange, once you get to multipart/alternative messages - passing the arguments is done exactly the same 
way. 

=head2 mass_send

 # Send to a list - (old API - don't use, if you can help it)
 $mh->mass_send( 
 	Subject => "this is the subject', 
 	Body    => "This is the body of the message', 
 );
 
 # Send to a list - new API
	my $message_id = $mh->mass_send(
		{
			-msg 			  => {
				Subject => "this is the subject', 
			 	Body    => "This is the body of the message',
			},
			-partial_sending  => {...}, 
			-multi_list_send  => {
									-lists    => [@alternative_list], 
									-no_dupes => 1, 
			 					 },
			-test      => 0,
			-mass_test => 0, 
			-test_recipient => 'someone@example.com'
		}
	);

Mails a message to an entire mailing list. 

The Old API is similar to the API to C<send>, but will ignore the, C<To> header, 
if you do pass it. B<Use the new API.> 

C<-msg> is B<required> and should hold a hashref containing the headers of the
message you want to pass and a special key called, B<Body>, that should hold the 
actual email message. 

C<-partial_sending> is an optional argument and if passed, should hold a hashref 
with the following format: 

 { 
 	first_name => {
 		equal_to => "John",
 	},
 	last_name => { 
 		like => "Doe", 
 	},
 }

keys should be named after profile fields and the values themselves should be a hashref. 
The hashref keys can either be, "equal_to" or, "like", depending on if you want to do an
exact match, or a partial match on a string.

C<-multi_list_send> is optional and should hold a hashref with additional arguments. They are: 

=over

=item * -lists

should hold an array ref of additional lists you would like to send to

=item * -no_dupes

should be set to either C<1> or, C<0>. Setting to, C<1> will tell DADA::Mail::Send not to 
send the same message twice, to a subscriber that may be on two lists. 

=back

C<-test> is optional and should hold a value of either C<1> or, C<0>. If set to C<1> 
the mass mailing will NOT be sent out, via email, but rather written to a file. This file 
can be specified using the, C<test_send_file> method. The <-test> parameter works 
the same way as the C<test> method. 

C<-mass_test> is optional and should hold a value of either C<1> or, C<0>. If set to 
C<1> a mass mailing will be done, but only sent to the recipient set in, C<-test_recipient>, 
or the list owner, if no valid recipient is set. Works the same as the, C<mass_test> parameter. 

C<-test_recipient> is option and should hold a valid email address of where test mass 
mailings should be sent. The, <-mass_test> argument should also be set to, C<1>. 
Works the same as the C<test_recipient> method. 


=head2 test

 my $test = $mh->test; 
 # returns, "0"
 
 # or: 
 $mh->test(1); 
 # returns, "1"
  
 $mh->test; 
 # now returns, "1"

The C<test> method is used to change part of the behavior of both the, C<send> and, C<mass_send> methods. 

Instead of sending a message via email, the messsage being created will simply be written to a file. 

The file name and location is saved in the C<test_send_file> method

This method, so rightly named, is handy for testing and debugging, since you can go through the entire process of sending a message,
but simply write the message to a file, to be examined by a trained professional. Or, Justin.  

=head2 test_send_file

 my $test_file = $mh->test_send_file
 
 # or: 
 $mh->test_send_file('/some/path/to/a/file.txt');
 
 # Now 
 $test_file = $mh->test_send_file; 
 # Returns: /some/path/to/a/file.txt

C<test_send_file> is used to store and set the location of the file that C<DADA::Mail::Send> uses to save email messages to, when C<test> 
is set to, B<1>. 

Defaults to: C<$DADA::Config::TMP . '/test_send_file.txt'>

=head1 Private Methods


=head2 _make_general_headers

 my %headers = $mh->_make_general_headers; 

Takes no arguments. 

Return a hash containing the following Email Headers: 

=over

=item * From

=item * Reply-To

=item * Errors-To

=item * Message-ID


=item * Date

=back

The idea behind C<_make_general_headers> is to create usable defaults to email headers that should be included in your email messags. 

=head2 list_headers

 my %list_headers = $mh->list_headers

Similar to C<_make_general_headers>, C<list_headers> creates a set of email headers - in this case headers that deal with 
Mailing Lists. They are: 

=over

=item * List

=item * List-URL

=item * List-Unsubscribe

=item * List-Subscribe

=item * List-Owner

=item * List-Archive

=item * List-Post

=item * List-ID

=back

=head2 clean_headers

 %squeaky_clean_headers = $mh->clean_headers(%these_be_the_heaers);

Not a private method per-se, but seems of little use outside the internals of this module - 

This method does a little munging to the mail headers for better absorbtion; basically, it changes the case of some of the mail headers so everyone's on the same page

=head2 return_headers


	my %headers = $mh->return_headers($string); 

Again, not clearnly a private method, but of little use outside of the internals. 

This is a funky little subroutine that'll take a string that holds the 
header of a mail message, and gives you back a hash of all the headers 
separated, each key in the hash holds a different header, so if I say

	my $mh = DADA::Mail::Send -> new(); 
	my %headers = $mh -> return_headers($header_glob); 


I can then say: 

	my $to = $headers{To}; 

This subroutine is used quite a bit to take out put from the MIME::Lite 
module, which allows you to get the whole header with its header_to_string() 
subroutine and hack it up into something Dada Mail can use. 


=head1 See Also

A great bit of the scheduling, auto-pickup'ing and status'ing of the mass mailing, (basically, everything except looping through the list
is controlled by C<DADA::Mail::MailOut>. 

=head1 COPYRIGHT

Copyright (c) 1999 - 2014 Justin Simoni 
me - justinsimoni.com
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



=cut
