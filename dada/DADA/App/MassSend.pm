package DADA::App::MassSend;

#use warnings; 

use lib qw(../../ ../../perllib);


use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 
use DADA::Template::HTML; 

use Carp qw(carp croak); 


use strict; 
use vars qw($AUTOLOAD); 

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_MassSend}; 


my %allowed = (
	test => 0, 
);



sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my %args = (@_); 
		
   $self->_init(\%args); 
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




sub _init {}




sub send_email { 

	my $self   = shift; 
	my ($args) = @_; 
	my $q          = $args->{-cgi_obj};
	my $dbi_handle = $args->{-dbi_handle};

	my $process = xss_filter(strip($q->param('process'))); 
	my $flavor  = xss_filter(strip($q->param('flavor'))); 
    my $root_login = $args->{-root_login}; 

	my $list;
	if(! exists($args->{-list})){ 
		croak "You must pass the -list paramater!"; 
	}
	else { 
		$list = $args->{-list}; 
	}
	
	if(! exists($args->{-html_output})){ 
		$args->{-html_output} = 1; 
	}
	

													
    
    require DADA::MailingList::Settings; 
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 


    
    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get; 

	require DADA::MailingList::Subscribers; 
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
    
   my $fields = [];  
   # Extra, special one... 
   push(@$fields, {name => 'subscriber.email'}); 
   foreach my $field(@{$lh->subscriber_fields({-dotted => 1})}){ 
        push(@$fields, {name => $field});
    }

 	my $undotted_fields = [];  
   # Extra, special one... 
   push(@$undotted_fields, {name => 'email', label => 'Email Address'});
	require DADA::ProfileFieldsManager; 
	my $pfm = DADA::ProfileFieldsManager->new;
	my $fields_attr = $pfm->get_all_field_attributes;
   foreach my $undotted_field(@{$lh->subscriber_fields({-dotted => 0})}){ 
        push(@$undotted_fields, {name => $undotted_field, label => $fields_attr->{$undotted_field}->{label}});
    }

    
    
    
	if(! $process){
  
		my ($num_list_mailouts, $num_total_mailouts, $active_mailouts, $mailout_will_be_queued)  = $self->mass_mailout_info($list);    
            my $scrn = ''; 
            $scrn .= admin_template_header(
						-Title      => "Send a Message", 
						-List       => $list, 
						-Root_Login => $root_login,
						-Form       => 0, 
					); 

            require  DADA::Template::Widgets;
			$scrn .= DADA::Template::Widgets::screen(
						{
							-screen     => 'send_email_screen.tmpl', 
							-vars       =>  {
								
								screen                     => 'send_email', 
								title                      => 'Send a Message',
								
								flavor                     => $flavor,

								priority_popup_menu        => DADA::Template::Widgets::priority_popup_menu($li),
								precendence_popup_menu     => DADA::Template::Widgets::precendence_popup_menu($li),
								type                       => 'list', 
								fields                     => $fields,
								undotted_fields            => $undotted_fields,
								can_have_subscriber_fields => $lh->can_have_subscriber_fields, 
								# I don't really have this right now...
								#  apply_list_template_to_html_msgs => $li->{apply_list_template_to_html_msgs} ? $li->{apply_list_template_to_html_msgs} : 0,
								
								MAILOUT_AT_ONCE_LIMIT      => $DADA::Config::MAILOUT_AT_ONCE_LIMIT, 
								mailout_will_be_queued     => $mailout_will_be_queued, 
								num_list_mailouts          => $num_list_mailouts, 
								num_total_mailouts         => $num_total_mailouts, 
								active_mailouts            => $active_mailouts,
								
								global_list_sending_checkbox_widget => DADA::Template::Widgets::global_list_sending_checkbox_widget($list), 
								
							}, 
							-list_settings_vars       => $ls->params, 
							-list_settings_vars_param => 
							{
								-dot_it => 1, 
							},
						}
			);                
            $scrn .= admin_template_footer(-List => $list, -Form => 0);
            
			if($args->{-html_output} == 1){ 
				print $scrn; 
  			}

        }else{
			
			require  DADA::App::FormatMessages; 
			my $fm = DADA::App::FormatMessages->new(-List => $list);
									
			# DEV: Headers.  Ugh, remember this is in, "Send a Webpage" as well. 	
			my %headers = ();
			foreach my $h(qw(
				Reply-To 
				Errors-To 
				Return-Path
				X-Priority
				Precedence 
				Subject 
			)) { 
				if(defined($q->param($h))){
					$headers{$h} = strip($q->param($h));
				}
			}
			#/Headers
			
			# Are we archiving this message? 
			if(defined($q->param('local_archive_options_present'))){ 
	           if($q->param('local_archive_options_present') == 1){ 
	               if($q->param('archive_message') != 1){ 
	                   $q->param(-name => 'archive_message', -value => 0); 
	               }
	           }
		   }
		
           my $archive_m = $li->{archive_messages} || 0;
                if($q->param('archive_message') == 1 || $q->param('archive_message') == 0){ 
                    $archive_m = $q->param('archive_message');
            }
			# /Are we archiving this message?    
                    
            require MIME::Lite;            
            $MIME::Lite::PARANOID = $DADA::Config::MIME_PARANOID;
            
            my $email_format      = $q->param('email_format');
			my $attachment        = $q->param('attachment');
			
			my $text_message_body = $q->param('text_message_body') || undef; 
			my $html_message_body = $q->param('html_message_body') || undef; 
			
			($text_message_body, $html_message_body) = 
				DADA::App::FormatMessages::pre_process_msg_strings($text_message_body, $html_message_body); 
				
            my $msg; 
            
            if($html_message_body && $text_message_body){ 
                
              $msg = MIME::Lite->new(
			  	Type      => 'multipart/alternative', 
			    Datestamp => 0, 
			  ); 
			  $msg->attr('content-type.charset' => $li->{charset_value});
 

			  my $pt_part = MIME::Lite->new(
					Type     => 'text/plain', 
                  	Data     => $text_message_body,
                  	Encoding => $li->{plaintext_encoding},
			  );
			  $pt_part->attr('content-type.charset' => $li->{charset_value});

              $msg->attach($pt_part); 
              my $html_part = MIME::Lite->new(
					Type     => 'text/html', 
					Data     => $html_message_body,
					Encoding => $li->{html_encoding},
			   ); 
			   $html_part->attr(
				'content-type.charset' => $li->{charset_value}
			 	);
			
               $msg->attach($html_part);
                
            }elsif($html_message_body){ 
                                
                $msg = MIME::Lite->new(
                                       Type      => 'text/html', 
                                       Data      => $html_message_body, 
                                       Encoding  => $li->{html_encoding},
									   Datestamp => 0, 
                                      ); 
                $msg->attr('content-type.charset' => $li->{charset_value});
            }elsif($text_message_body){ 
                            
                $msg = MIME::Lite->new(
					   		Type      => 'TEXT',
                            Data      => $text_message_body,
                            Encoding  => $li->{plaintext_encoding},
						    Datestamp => 0, 
                       );          
            	$msg->attr('content-type.charset' => $li->{charset_value});
			}
			else { 
				croak "There's no text in either the text, or HTML version of your message!"; 
			}
            
            my @cleanup_attachments = (); 
            
            my @attachments = $self->has_attachments({-cgi_obj => $q}); 
            my @compl_att = (); 
            
            if(@attachments){ 
                my @compl_att = (); 
                
                foreach(@attachments){ 
                    #carp '$_ ' . $_; 
                    
                    my ($msg_att, $filename) = $self->make_attachment({-name => $_, -cgi_obj => $q}); 
                    push(@compl_att, $msg_att)
                        if $msg_att;
                    
                    push(@cleanup_attachments, $filename)
                        if $filename; 
                }
                
                if($compl_att[0]){ 
                    my $mpm_msg = MIME::Lite->new(
						Type      => 'multipart/mixed',
						Datestamp => 0, 
					);
                       $mpm_msg->attach($msg);
                       foreach(@compl_att){ 
                          $mpm_msg->attach($_);
                       }
                    $msg = $mpm_msg;
                }
            }
            
            
        my $msg_as_string = (defined($msg)) ? $msg->as_string : undef;
                  #  croak '$msg_as_string ' . $msg_as_string;

           $fm->Subject($headers{Subject});
           $fm->use_list_template($q->param('apply_template')); 
           if($li->{group_list} == 1){ 
				$fm->treat_as_discussion_msg(1);
    		}

        my ($final_header, $final_body) = $fm->format_headers_and_body(-msg => $msg_as_string );
                
        require DADA::Mail::Send;
               $DADA::Mail::Send::dbi_obj = $dbi_handle;

        my $mh = DADA::Mail::Send->new(
					{ 
						-list   => $list, 
						-ls_obj => $ls,  
					}
			  	);
				
        unless($mh->isa('DADA::Mail::Send')){
			croak "DADA::Mail::Send object wasn't created correctly?"; 
		}
				
        $mh->test($self->test); 
        
		my %mailing = (
					   $mh->return_headers($final_header),
					   %headers,
                       Body      =>  $final_body,
                       ); 

		###### Blah blah blah, parital listing 
	    my $partial_sending = {}; 
	    foreach my $field(@$undotted_fields){ 
			if($q->param('field_comparison_type_' . $field->{name}) eq 'equal_to'){ 
			    $partial_sending->{$field->{name}} = {equal_to => $q->param('field_value_' . $field->{name})}; 
			}
			elsif($q->param('field_comparison_type_' . $field->{name}) eq 'like'){ 
				$partial_sending->{$field->{name}} = {like => $q->param('field_value_' . $field->{name})}; 
			}  
	    }

  		######/ Blah blah blah, parital listing 
      
        my $message_id; 
		my $test_recipient = ''; 
        if($q->param('archive_no_send') != 1){ 
			
			my @alternative_list = (); 
			@alternative_list = $q->param('alternative_list');
			my $og_test_recipient = $q->param('test_recipient') || ''; 
			$mh->mass_test_recipient($og_test_recipient); 
            $test_recipient = $mh->mass_test_recipient;

			my $multi_list_send_no_dupes = $q->param('multi_list_send_no_dupes') || 0; 
			
            # send away
			#require Data::Dumper; 			
            #die Data::Dumper::Dumper(@alternative_list);
 
			$message_id = $mh->mass_send(
				{
					-msg 			  => {%mailing},
					-partial_sending  => $partial_sending, 
					-multi_list_send  => {
											-lists    => [@alternative_list], 
											-no_dupes => $multi_list_send_no_dupes, 
					 					 },
					-also_send_to     => [@alternative_list],
				($process =~ m/test/i) ? (-mass_test => 1, -test_recipient => $og_test_recipient,) : (-mass_test => 0,)
								        	 
				}
			); 
        }else{ 
            
            # This is currently similar code as what's in the DADA::Mail::Send::_mail_general_headers method...
            
            my $msg_id = DADA::App::Guts::message_id(); 
            
            if($q->param('back_date') == 1){ 
                $msg_id = $self->backdated_msg_id({-cgi_obj => $q}); 
            }
            
            %mailing = $mh->clean_headers(%mailing); 

            %mailing = (    
                        %mailing,
                        $mh->_make_general_headers, 
                        $mh->_make_list_headers
                       ); 
                           
            require DADA::Security::Password;    
            my $ran_number = DADA::Security::Password::generate_rand_string('1234567890');
            $mailing{'Message-ID'} = '<' .  $msg_id . '.'. $ran_number . '.' . $li->{list_owner_email} . '>'; 
            $message_id = $msg_id; 
            
            $mh->saved_message($mh->_massaged_for_archive(\%mailing)); 
        
        }


        if($message_id){ 
            if(($archive_m == 1) && ($process !~ m/test/i)){
                require DADA::MailingList::Archives;                
                my $archive = DADA::MailingList::Archives->new({-list => $list});
                   $archive->set_archive_info($message_id, $headers{Subject}, undef, undef, $mh->saved_message); 

               	DADA::App::Guts::tweet_about_mass_mailing(
					$list, 
					$archive->_parse_in_list_info(-data => $headers{Subject}), 
					$DADA::Config::PROGRAM_URL . '/archive/' . $list . '/' . $archive->newest_entry.'/'
				) if $ls->param('twitter_mass_mailings') == 1;
				
            }
        } else { 
            $archive_m = 0;
        }

		my $uri = $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&type=list&id=' . $message_id; 
		if($args->{-html_output} == 1){ 
			print $q->redirect(-uri => $uri); 
		}
		
		 if ($DADA::Config::ATTACHMENT_TEMPFILE == 1 ){ 
        	$self->clean_up_attachments([@cleanup_attachments]) 
    	}
    	return; 
	}
}






sub send_url_email { 
	
	my $self   = shift; 
	my ($args) = @_; 

	my $q          = $args->{-cgi_obj}; 
	my $process    = xss_filter(strip($q->param('process'))); 
	my $flavor     = xss_filter(strip($q->param('flavor')));
	my $dbi_handle = $args->{-dbi_handle}; 
	
    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'send_url_email');
    
    my $list = $admin_list; 
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
    
    my $la = DADA::MailingList::Archives->new(   {-list => $list});           
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
    

    my $can_use_mime_lite_html  = 0; 
    my $mime_lite_html_error    = undef; 
    eval { require DADA::App::MyMIMELiteHTML };
    if(!$@){ 
        $can_use_mime_lite_html = 1;
    }else{ 
            $mime_lite_html_error = $@; 
    }
    
    
    my $can_use_lwp_simple  = 0;    
    my $lwp_simple_error    = undef; 
    eval { require LWP::Simple };
    if(!$@){ 
        $can_use_lwp_simple = 1;
    }else{ 
            $lwp_simple_error = $@; 

    }
    
   my $fields = [];  
   # Extra, special one... 
   push(@$fields, {name => 'subscriber.email'}); 
   foreach my $field(@{$lh->subscriber_fields({-dotted => 1})}){ 
        push(@$fields, {name => $field});
    }
 	my $undotted_fields = [];  
   # Extra, special one... 
   push(@$undotted_fields, {name => 'email', label => 'Email Address'});
	require DADA::ProfileFieldsManager; 
	my $pfm = DADA::ProfileFieldsManager->new;
	my $fields_attr = $pfm->get_all_field_attributes;
   foreach my $undotted_field(@{$lh->subscriber_fields({-dotted => 0})}){ 
        push(@$undotted_fields, {name => $undotted_field, label => $fields_attr->{$undotted_field}->{label}});
    }        

    
    
    if(!$process){ 
        
		my ($num_list_mailouts, $num_total_mailouts, $active_mailouts, $mailout_will_be_queued)  = $self->mass_mailout_info($list);


        my $scrn = '';          
        $scrn .= admin_template_header(     
              -Title       => "Send a Webpage", 
              -List        => $list,
              -Root_Login  => $root_login,
        );

        require DADA::Template::Widgets;

        $scrn .= DADA::Template::Widgets::screen(
				 	{
						-screen => 'send_url_email_screen.tmpl',
						-vars       =>  {
							
							screen                           => 'send_url_email', 
							title                            => 'Send a Webpage', 
							
							can_use_mime_lite_html           => $can_use_mime_lite_html,
							mime_lite_html_error             => $mime_lite_html_error, 
							can_use_lwp_simple               => $can_use_lwp_simple, 
							lwp_simple_error                 => $lwp_simple_error, 
							can_display_attachments          => $la->can_display_attachments, 
							fields                           => $fields,
							undotted_fields                  => $undotted_fields,
							can_have_subscriber_fields       => $lh->can_have_subscriber_fields,
							SERVER_ADMIN                     => $ENV{SERVER_ADMIN}, 
							priority_popup_menu              => DADA::Template::Widgets::priority_popup_menu($li),
							precendence_popup_menu           => DADA::Template::Widgets::precendence_popup_menu($li),
							
							global_list_sending_checkbox_widget => DADA::Template::Widgets::global_list_sending_checkbox_widget($list), 
							
							MAILOUT_AT_ONCE_LIMIT      => $DADA::Config::MAILOUT_AT_ONCE_LIMIT, 
							mailout_will_be_queued     => $mailout_will_be_queued, 
							num_list_mailouts          => $num_list_mailouts, 
							num_total_mailouts         => $num_total_mailouts,							
							active_mailouts            => $active_mailouts,
						},
						-list_settings_vars       => $ls->params, 
						-list_settings_vars_param => 
							{
								-dot_it => 1, 
							},
   						}
					); 

        $scrn .= admin_template_footer(-List => $list );
        print $scrn; 

    }else{ 
        
        if($can_use_mime_lite_html){ 
        
			# DEV: Headers.  Ugh, remember this is in, "Send a Webpage" as well. 	
			my %headers = ();
			foreach my $h(qw(
				Reply-To 
				Errors-To 
				Return-Path
				X-Priority
				Precedence 
				Subject 
			)) { 
				if(defined($q->param($h))){
					$headers{$h} = strip($q->param($h));
				}
			}
			#/Headers
			
			
            my $url_options   =  $q->param('url_options') || undef; 
            
            my $login_details; 
        
            if(defined($q->param('url_username')) && defined($q->param('url_password'))){ 
                $login_details =  $q->param('url_username') . ':' . $q->param('url_password')
            }
            
            
            my $proxy = defined($q->param('proxy')) ? $q->param('proxy') : undef;
            

	 
            my $mailHTML = new DADA::App::MyMIMELiteHTML(
	
												'IncludeType' => $url_options, 
                                                'TextCharset' => $li->{charset_value},
                                                'HTMLCharset' => $li->{charset_value}, 
                                                
                                                HTMLEncoding  => $li->{html_encoding},
                                                TextEncoding  => $li->{plaintext_encoding},
                                     
                                                 (($proxy) ? (Proxy => $proxy,) :  ()),
                                                 (($login_details) ? (LoginDetails => $login_details,) :  ()),

                                                (
                                                ($DADA::Config::CPAN_DEBUG_SETTINGS{MIME_LITE_HTML} == 1) ? 
                                                (Debug => 1, ) :
                                                ()
                                                ), 
                                                                     
                                                ); 
                                                
            my $t = $q->param('text_message_body') || 'This email message requires that your mail reader support HTML'; 
            
            
            if($q->param('auto_create_plaintext') == 1){ 
                
                if($q->param('content_from') eq 'url'){ 
                    require LWP::Simple; 
                    my $good_try = LWP::Simple::get($q->param('url'));
                    $t           = convert_to_ascii($good_try);
                }else{ 
                    $t           = convert_to_ascii($q->param('html_message_body'));
                }
            }
            
            my $MIMELiteObj; 
            
            if($q->param('content_from') eq 'url'){ 
                $MIMELiteObj = $mailHTML->parse($q->param('url'), $t);
            }else{ 
                $MIMELiteObj = $mailHTML->parse($q->param('html_message_body'), $t);
            }
            
            require  DADA::App::FormatMessages; 
            my $fm = DADA::App::FormatMessages->new(-List => $list); 
            
               $fm->originating_message_url(strip($q->param('url'))); 
               $fm->Subject($headers{Subject}); 
               $fm->treat_as_discussion_msg(1)
                    if $li->{group_list} == 1;
            
            my $problems = 0; 
			my $eval_error = ''; 
            my $rm       = '';
            my @MIME_HTML_errors = (); 

			#carp '$MIMELiteObj->as_string ' . $MIMELiteObj->as_string;
            eval { $rm = $MIMELiteObj->as_string; }; 
            if($@){ 
                warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER - Send a Webpage isn't functioning correctly? - $@";  
                $problems++;
				$eval_error = $@; 
				@MIME_HTML_errors = $mailHTML->errstr;
				foreach(@MIME_HTML_errors){ 
					$eval_error .= $_; 
				}	
            }
			else { 
				@MIME_HTML_errors = $mailHTML->errstr;
			}
            
            my $message_id; 
            my $mh; 
 
            if($q->param('local_archive_options_present') == 1){ 
                if($q->param('archive_message') != 1){ 
                    $q->param(-name => 'archive_message', -value => 0); 
                }
            }
            my $archive_m = $li->{archive_messages} || 0;
            if($q->param('archive_message') == 1 || $q->param('archive_message') == 0){ 
                $archive_m = $q->param('archive_message');
            }   

            my $test_recipient = ''; 

            if(!$problems){ 
            
                my ($header_glob, $template) =  $fm->format_headers_and_body(-msg => $rm);
                
                require DADA::Mail::Send;
                       $DADA::Mail::Send::dbi_obj = $dbi_handle;

                   $mh      = DADA::Mail::Send->new(
								{
									-list   => $list, 
									-ls_obj => $ls, 
								}
							  );
             
		
                my %mailing = (
							   %headers,
							   $mh->return_headers($header_glob),    
                               Body      => $template,
                              );
                               
			    my $partial_sending = {}; 
			    foreach my $field(@$undotted_fields){ 
					if($q->param('field_comparison_type_' . $field->{name}) eq 'equal_to'){ 
					    $partial_sending->{$field->{name}} = {equal_to => $q->param('field_value_' . $field->{name})}; 
					}
					elsif($q->param('field_comparison_type_' . $field->{name}) eq 'like'){ 
						$partial_sending->{$field->{name}} = {like => $q->param('field_value_' . $field->{name})}; 
					}  
			    }
				
                if($q->param('archive_no_send') != 1){ 
                    # Woo Ha! Send away!

					my @alternative_list = (); 
					@alternative_list = $q->param('alternative_list');

					my $og_test_recipient        = $q->param('test_recipient') || ''; 
					my $multi_list_send_no_dupes = $q->param('multi_list_send_no_dupes') || 0; 
					
					$mh->mass_test_recipient($og_test_recipient); 
		            $test_recipient = $mh->mass_test_recipient;

		            # send away
		            $message_id = $mh->mass_send(
						{
							-msg 			  => {%mailing},
							-partial_sending  => $partial_sending, 
							-multi_list_send  => {
													-lists    => [@alternative_list], 
													-no_dupes => $multi_list_send_no_dupes, 
							 					 },
							-also_send_to     => [@alternative_list],
						($process =~ m/test/i) ? (-mass_test => 1, -test_recipient => $og_test_recipient,) : (-mass_test => 0,)

						}
					);


                }else{ 
            
                    # This is currently similar code as what's in the DADA::Mail::Send::_mail_general_headers method...
                    
                    my $msg_id = DADA::App::Guts::message_id(); 
                    
                    if($q->param('back_date') == 1){ 
                        $msg_id = $self->backdated_msg_id({-cgi_obj => $q}); 
                    }
                    
                    # time  + random number + sender, woot!
                    require DADA::Security::Password;    
                    my $ran_number = DADA::Security::Password::generate_rand_string('1234567890');
                    
                    %mailing = $mh->clean_headers(%mailing); 
                    
                    %mailing = (
                                %mailing,
                                $mh->_make_general_headers, 
                                $mh->_make_list_headers
                           ); 
                    
                    $mailing{'Message-ID'} = '<' .  $msg_id . '.'. $ran_number . '.' . $li->{list_owner_email} . '>'; 

                    $message_id = $msg_id; 
                    
                    $mh->saved_message($mh->_massaged_for_archive(\%mailing)); 
                
                }
                                
                if($archive_m == 1 && ($q->param('process') !~ m/test/i)){ 
                
                    require DADA::MailingList::Archives;
                           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
                    
                    my $archive = DADA::MailingList::Archives->new({-list => $list});
                    $archive->set_archive_info($message_id, $q->param('Subject'), undef, undef, $mh->saved_message); 
                    
					DADA::App::Guts::tweet_about_mass_mailing(
						$list, 
						$archive->_parse_in_list_info(-data => $headers{Subject}), 
						$DADA::Config::PROGRAM_URL . '/archive/' . $list . '/' . $archive->newest_entry.'/'
					) if $ls->param('twitter_mass_mailings') == 1;
					
                }

				my $uri = $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&type=list&id=' . $message_id; 
				print $q->redirect(-uri => $uri);
				
            }
			else { 
				# DEV: This should probably be fleshed out to be a bit more verbose...
				die $eval_error; 
			}

        }else{ 
            die "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: $!\n";
        }
    }
}





sub list_invite { 
	
	my $self   = shift; 
	my ($args) = @_; 
	my $q = $args->{-cgi_obj};
	my $dbi_handle = $args->{-dbi_handle};

	my $process = xss_filter(strip($q->param('process'))); 
	my $flavor  = xss_filter(strip($q->param('flavor')));
	
    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'list_invite');
    my $list = $admin_list; 
    
    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 

    if($process =~ m/invite/i){ 

		my ($num_list_mailouts, $num_total_mailouts, $active_mailouts, $mailout_will_be_queued)  = $self->mass_mailout_info($list);


		my $field_names = []; 
		my $subscriber_fields = $lh->subscriber_fields;
         foreach(@$subscriber_fields){ 
             push(@$field_names, {name => $_}); 
        }
        
		my @addresses = $q->param('address'); 
 
	  my $verified_addresses = []; 
	  
	  # Addresses hold CSV info - each item in the array is one line of CSV...
	
	  foreach my $a(@addresses){ 
			my $pre_info = $lh->csv_to_cds($a); 
			my $info     = {};
			# DEV: Here I got again:
		
			$info->{email} = $pre_info->{email}; 

			my $new_fields = [];
			my $i = 0; 
			foreach(@$subscriber_fields){
				push(@$new_fields, {name => $_, value => $pre_info->{fields}->{$_} }); 
				$i++;
			}
			$info->{fields} = $new_fields;
			
			#And... Then this! 
			$info->{csv_info} = $a;	
			push(@$verified_addresses, $info); 
			
	    }
	       
        print(admin_template_header(-Title      => "Invitations", 
                                -List       => $list, 
                                -Root_Login => $root_login));
                                
            
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen(
					{
						-screen => 'list_invite_screen.tmpl', 
						-vars   => {
							# This is sort of weird, as it default to the "Send a Message" Subject
							Subject                        => $ls->param('invite_message_subject'), 
							field_names                    => $field_names, 
							verified_addresses             => $verified_addresses, 
							#invite_message_html_js_escaped => js_enc($li->{invite_message_html}),
							
							html_message_body_content            => $li->{invite_message_html}, 
							html_message_body_content_js_escaped => js_enc($li->{invite_message_html}),
							MAILOUT_AT_ONCE_LIMIT      => $DADA::Config::MAILOUT_AT_ONCE_LIMIT, 
							mailout_will_be_queued     => $mailout_will_be_queued, 
							num_list_mailouts          => $num_list_mailouts, 
							num_total_mailouts         => $num_total_mailouts,
							active_mailouts            => $active_mailouts,
						},
						-list_settings_vars       => $li, 
						-list_settings_vars_param => 
							{ 
								-dot_it => 1,
							}, 
					}
				);
        print(admin_template_footer(-List => $list));

    }elsif($process =~ m/submit/i){ 
 
       # add these to a special 'invitation' list. we'll clear this list later. 
        my @address         = $q->param("address"); 
        #my $new_email_count = 0; 

        foreach my $a(@address){ 
           	my $info   = $lh->csv_to_cds($a); 
            $lh->add_subscriber(
                { 
                    -email         => $info->{email}, 
                    -fields        => $info->{fields},
                    -type          => 'invitelist', 
                }
            ); 
            $lh->add_subscriber(
                { 
                    -email         => $info->{email}, 
                    -fields        => $info->{fields},
					-type          => 'sub_confirm_list', 
                }
            );

 		}
                                              
        
		# DEV: Headers.  Ugh, remember this is in, "Send a Webpage" as well. 	
		my %headers = ();
		foreach my $h(qw(
			Reply-To 
			Errors-To 
			Return-Path
			X-Priority
			Precedence 
			Subject 
		)) { 
			if(defined($q->param($h))){
				$headers{$h} = strip($q->param($h));
			}
		}
		#/Headers

			
		require DADA::App::FormatMessages; 

		my $text_message_body = $q->param('text_message_body') || undef; 
		if($q->param('use_text_message') != 1){ 
			$text_message_body = undef; 
		}
		my $html_message_body = $q->param('html_message_body') || undef; 
		if($q->param('use_html_message') != 1){ 
			$html_message_body = undef; 
		}
		
		if($text_message_body eq undef && $html_message_body eq undef){ 
			croak "Message will be sent blank! Stopping!"; 
		}
		
		($text_message_body, $html_message_body) = 
			DADA::App::FormatMessages::pre_process_msg_strings($text_message_body, $html_message_body);
						
        require MIME::Lite; 
        $MIME::Lite::PARANOID = $DADA::Config::MIME_PARANOID;
        my $msg; 
      
    
        if($text_message_body and $html_message_body){     
        
            $msg = MIME::Lite->new(
					Type      =>  'multipart/alternative',
					Datestamp => 0, 
				  );  
            $msg->attach(Type=> 'TEXT', Data => $text_message_body);
            $msg->attach(Type => 'text/html', Data => $html_message_body);  
        
        }elsif($html_message_body){
        
            # make only a text body                       
             $msg = MIME::Lite->new(
						Type      => 'text/html', 
						Data      => $html_message_body,
						Datestamp => 0, 
					);
        
        }elsif($text_message_body){
        
            $msg = MIME::Lite->new(
					Type      => 'TEXT', 
					Data      => $text_message_body,
					Datestamp => 0, 
			);                                
        
        } else{ 
        
            warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning: both text and html versions of invitation message blank?!"; 
            $msg = MIME::Lite->new(
						Type      => 'TEXT', 
						Data      => $li->{invite_message_text},
						Datestamp => 0, 
				  );                                

        }
        
        $msg->replace('X-Mailer' =>"");
        
        my $msg_as_string = (defined($msg)) ? $msg->as_string : undef;
        
		require DADA::App::FormatMessages; 
        my $fm = DADA::App::FormatMessages->new(-List => $list); 
           $fm->Subject($headers{Subject}); 
           $fm->use_email_templates(0); 
           
        my ($header_glob, $message_string) =  $fm->format_headers_and_body(-msg => $msg_as_string );
    
        require DADA::Mail::Send;
               $DADA::Mail::Send::dbi_obj = $dbi_handle;

        my $mh = DADA::Mail::Send->new(
					{
						-list   => $list, 
						-ls_obj => $ls, 
					}
				 ); 
        # translate the glob into a hash
        %headers = ($mh->return_headers($header_glob), %headers); 

        $mh->list_type('invitelist');
        
        $mh->mass_test(1) 
            if($process =~ m/test/i); 
    
        my $test_recipient = ''; 
        if($process =~ m/test/i){ 
            $mh->mass_test_recipient(strip($q->param('test_recipient'))); 
            $test_recipient = $mh->mass_test_recipient; 
        }
        
	my  $message_id = $mh->mass_send( 
					  		%headers,  
							Body     =>    $message_string,
					 );
					
	my $uri = $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&type=invitelist&id=' . $message_id; 
	print $q->redirect(-uri => $uri);
	
    }
}




sub has_attachments { 
    
	my $self = shift; 
	
	my ($args) = @_; 
	my $q = $args->{-cgi_obj};
		
    my @ive_got    = (); 

	my $num = $q->param('attachment'); 
	
    foreach(1 .. $num) { 
      #  warn "Working on: " . $_; 
        
        my $filename = $q->param('attachment_' . $_);
      #  warn '$filename ' . $filename; 
        if(defined($filename) && length($filename) > 1){  
            push(@ive_got, 'attachment_' . $_);
        }
    }
    return @ive_got;
}




sub make_attachment { 

	my $self = shift; 
	my ($args) = @_; 
    my $name = $args->{-name};
  
	my $q = $args->{-cgi_obj};
	
    require MIME::Lite; 

    
    my $attachment    = $q->param($name);    
    
  #  warn '$attachment ' . $attachment; 
    
    my $uploaded_file = ''; 
    
    if(!$attachment){ 
        warn '!$attachment'; 
        return (undef, undef); 
    }
    
    my $a_type = $self->find_attachment_type($attachment);


    
    my $attach_name =  $attachment; 
       $attach_name =~ s!^.*(\\|\/)!!;
       $attach_name =~ s/\s/%20/g;
       
    my %mime_args = ( Type              =>  $a_type,
                      # Id              => '<'.$attach_name.'>',
                      Filename          =>  $attach_name,
                      Disposition       =>  $self->make_a_disposition($a_type), 
					  Datestamp         => 0, 
                      ); 
                      
    my $attachment_file;
    
    # Oh, great, I just busted that... 
    
    # kinda used only for testing at the moment; 
    #if($name =~ m/^filepath_attachment/){ 
    #
    #    $mime_args{Path} = $attachment; 
    #     $file_uploaded_file   = $attach_name;
    #
    #}else{ 
    
        if($DADA::Config::ATTACHMENT_TEMPFILE == 1){ 
            
            # $name is the CGI paramater name - we need to pass that
            # to keep the CGI object, "magic"
            
            my $attachment_file = $self->file_upload(
				{
					-cgi_obj => $q, -name => $name
				}
			); 
               $mime_args{Path} =  $attachment_file;    
               $uploaded_file   =  $attachment_file;
                        
        }else{ 
        
             $mime_args{FH}  =  $attachment;
             $uploaded_file  = $attach_name; 
        }                  
    #}
    
   # warn '$uploaded_file ' . $uploaded_file; 
    
    my $msg_att = MIME::Lite->new(%mime_args); 
       $msg_att->attr('Content-Location' =>  $attach_name);


	# I'm not sure what's making the, '-meta.txt' files, but this should 
	# help remove them /hack
	dump_attachment_meta_file($uploaded_file); 
	
    return($msg_att, $uploaded_file); 
        
}


# /hack
sub dump_attachment_meta_file {
    my $filename = shift;
    $filename =~ s{^(.*)\/}{};

    eval { require URI::Escape };
    if ( !$@ ) {
        $filename = URI::Escape::uri_escape( $filename, "\200-\377" );
    }
    else {
        warn('no URI::Escape is installed!');
    }
    $filename =~ s/\s/%20/g;

    my $full_path_to_filename =
      make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' );

	if(! -e $full_path_to_filename){ 
		
	}
	else { 
		
  	  my $chmod_check =
	      chmod( $DADA::Config::FILE_CHMOD, $full_path_to_filename );
	    if ( $chmod_check != 1 ) {
	        warn "could not chmod '$full_path_to_filename' correctly.";
	    }

	    my $unlink_check = unlink($full_path_to_filename);
	    if ( $unlink_check != 1 ) {
	        warn "deleting meta file didn't work for: " . $full_path_to_filename;
	    }
	}
}




sub make_a_disposition { 

	my $self = shift; 
    my $n = shift; 
    my $disposition = 'inline'; 
    
    if($n !~ m/image/){ 
        #if($n !~ /text/){ # if they're inline, they get parsed as if 
                           # they were a part of Dada Mail... hmm...
            $disposition = 'attachment';
        #}
    }
    
    return $disposition; 
    
}


sub find_attachment_type { 

	my $self = shift; 
	
    my $filename = shift; 
    my $a_type; 
        
  my $attach_name =  $filename; 
     $attach_name =~ s!^.*(\\|\/)!!;
     $attach_name =~ s/\s/%20/g;
     
   my $file_ending = $attach_name; 
      $file_ending =~ s/.*\.//;
 
    require MIME::Types; 
    require MIME::Type;

    if(($MIME::Types::VERSION >= 1.005) && ($MIME::Type::VERSION >= 1.005)){ 
        my ($mimetype, $encoding) = MIME::Types::by_suffix($filename);
        $a_type = $mimetype if ($mimetype && $mimetype =~ /^\S+\/\S+$/);  ### sanity check
    }else{ 
        if(exists($DADA::Config::MIME_TYPES{'.'.lc($file_ending)})) {  
            $a_type = $DADA::Config::MIME_TYPES{'.'.lc($file_ending)};
        }else{ 
            $a_type = $DADA::Config::DEFAULT_MIME_TYPE; 
        }
    }
    if(!$a_type){ 
        warn "attachment MIME Type never figured out, letting MIME::Lite handle this..."; 
        $a_type = 'AUTO';
    } 
    
    return $a_type; 
}




sub file_upload {

	my $self = shift; 
	
	my ($args) = @_; 
	my $q = $args->{-cgi_obj};
    my $upload_file = $args->{-name};
    
    my $fu   = CGI->new(); 
    my $file = $fu->param($upload_file);  
    if ($file ne "") {
        my $fileName = $file; 
           $fileName =~ s!^.*(\\|\/)!!;   
         eval {require URI::Escape}; 
         if(!$@){
            $fileName =  URI::Escape::uri_escape($fileName, "\200-\377");
         }else{ 
            warn('no URI::Escape is installed!'); 
         }
        $fileName =~ s/\s/%20/g;
          
        my $outfile = make_safer($DADA::Config::TMP . '/' . time . '_' . $fileName);
         
        open (OUTFILE, '>' . $outfile) or warn("can't write to '" . $outfile . "' because: $!");        
        while (my $bytesread = read($file, my $buffer, 1024)) { 
            print OUTFILE $buffer;
        } 
        close (OUTFILE);
        chmod($DADA::Config::FILE_CHMOD, $outfile);  
        return $outfile;
    }
    
}




sub backdated_msg_id { 

	my $self   = shift; 
	my ($args) = @_; 
	my $q = $args->{-cgi_obj}; 
    my $backdate_hour = $q->param('backdate_hour');
       $backdate_hour = int($backdate_hour) + 12
        if $q->param('backdate_hour_label') =~ /p/; # as in, p.m.
      
    my $message_id = sprintf("%02d%02d%02d%02d%02d%02d", $q->param('backdate_year'), 
                                                         $q->param('backdate_month'), 
                                                         $q->param('backdate_day'),  
                                                         $backdate_hour, 
                                                         $q->param('backdate_minute'),
                                                         $q->param('backdate_second')
                                                        );
    return $message_id; 
    
}




sub clean_up_attachments { 

	my $self  = shift; 
    my $files = shift || [];
    foreach(@$files){ 
        $_ = make_safer($_); 
        warn "could not remove '$_'"
            unless
                unlink($_) > 0;
                    # i love the above!
    }
}


sub mass_mailout_info { 
	
	my $self = shift; 
	my $list = shift; 
	my $num_list_mailouts      = undef; 
	my $num_total_mailouts     = undef; 
	my $mailout_will_be_queued = undef; 
	
	my (
	$monitor_mailout_report, 
	$total_mailouts, 
	$active_mailouts, 
	$paused_mailouts, 
	$queued_mailouts,
	$inactive_mailouts
	);
	 
	eval { 
		require DADA::Mail::MailOut; 

		my @mailouts  = DADA::Mail::MailOut::current_mailouts({-list => $list});  
		$num_list_mailouts = $#mailouts + 1; 

			(
			$monitor_mailout_report, 
			$total_mailouts, 
			$active_mailouts, 
			$paused_mailouts, 
			$queued_mailouts,
			$inactive_mailouts
			) = DADA::Mail::MailOut::monitor_mailout(
					{
						-verbose => 0, 
						-list    => $list,
						-action  => 0, 
					}
				);
		$num_total_mailouts = $total_mailouts; 
	};
	if($@){ 
		warn "Problems filling out the 'Sending Monitor' admin menu item with interesting bits of information about the mailouts: $@"; 
	}
	else { 
	
		if($DADA::Config::MAILOUT_AT_ONCE_LIMIT ne undef){ 
			
			# DEV: 2203220  	 3.0.0 - Stale Mailout can still clog up mail queue
			# https://sourceforge.net/tracker2/?func=detail&aid=2203220&group_id=13002&atid=113002
			# We've got to look at *active* mailouts, first
			# We don't care about paused or inactive mailouts - any of that, 
			 if($active_mailouts >= $DADA::Config::MAILOUT_AT_ONCE_LIMIT){
				$mailout_will_be_queued = 1;
			}
		}
	}
	return($num_list_mailouts, $num_total_mailouts, $active_mailouts, $mailout_will_be_queued); 
	
}







sub DESTROY { 

	my $self = shift; 
	
}










1;

