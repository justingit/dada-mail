package DADA::Template::Widgets;
use lib qw(

          /sw/lib/perl5/5.8.6/darwin-thread-multi-2level
          /sw/lib/perl5
          
          ../../ ./ ../ ./dada ../dada ./DADA ../DADA ./DADA/perllib ../DADA/perllib); 

use CGI::Carp qw(croak carp); 

use DADA::Config qw(!:DEFAULT);  


# A weird fix.
BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}


use DADA::App::Guts; 
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);

	my $dbi_handle; 

if(
	$DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/i || 
    $DADA::Config::ARCHIVE_DB_TYPE    =~ m/SQL/i || 
    $DADA::Config::SETTINGS_DB_TYPE   =~ m/SQL/i ||
    $DADA::Config::SESSION_DB_TYPE    =~ m/SQL/i 
){        
	require DADA::App::DBIHandle; 
    $dbi_handle = DADA::App::DBIHandle->new; 
}

my $wierd_abs_path = __FILE__; 
   $wierd_abs_path =~ s{^/}{}g;

my @guesses; 

my $Templates; 

if(! $DADA::Config::ALTERNATIVE_HTML_TEMPLATE_PATH ){ 

	eval { require File::Spec };
	
	if(!$@){

	   $Templates  =  File::Spec->rel2abs($wierd_abs_path);
	   $Templates  =~ s/Widgets\.pm$//g;
	   $Templates  =~ s/\/$//; # cut off the first slash, if it's there; 
	   $Templates .= '/templates';
	   
	    push(@guesses, $Templates); 
	   
	}elsif($@){

	 carp "$DADA::Config::PROGRAM_NAME warning: File::Spec isn't working correctly: ". $@;
	 carp 'You may want to setup the, "$DADA::Config::ALTERNATIVE_HTML_TEMPLATE_PATH " Config variable!';
	 
	} else{ 
	
		$Templates = $DADA::Config::ALTERNATIVE_HTML_TEMPLATE_PATH ;
    	push(@guesses, $Templates);
	}
	
}else{ 
	
	$Templates = $DADA::Config::ALTERNATIVE_HTML_TEMPLATE_PATH ;
    push(@guesses, $Templates);

}
		
my $second_guess_template  = $wierd_abs_path; 
   $second_guess_template  =~ s/Widgets\.pm$//g;
   $second_guess_template  =~ s/\/$//;
   $second_guess_template .= '/templates';
   $second_guess_template  = '/' . $second_guess_template;

	push(@guesses, $second_guess_template);


	my $getpwuid_call; 
	eval { $getpwuid_call = ( getpwuid $> )[7] };
	if(!$@){ 
		# They're called guess, right? right...
		push(@guesses, $getpwuid_call . '/cgi-bin/dada/DADA/Template/templates');
		push(@guesses, $getpwuid_call . '/public_html/cgi-bin/dada/DADA/Template/templates');
		push(@guesses, $getpwuid_call . '/public_html/dada/DADA/Template/templates');
	}
	
require Exporter; 

use vars (@ISA, @EXPORT); 

@ISA    = qw(Exporter);  
@EXPORT = qw( 
 
templates_dir

precendence_popup_menu
priority_popup_menu

list_popup_menu
list_popup_login_form
default_screen
send_url_email_screen
login_switch_widget
screen
absolute_path
subscription_form
archive_send_form
profile_widget
_raw_screen
);

use strict; 
use vars qw( @EXPORT );

my %Global_Template_Variables = (

NO_ONE_SUBSCRIBED      => $DADA::Config::NO_ONE_SUBSCRIBED , 
GOOD_JOB_MESSAGE       => $DADA::Config::GOOD_JOB_MESSAGE, 
ROOT_PASS_IS_ENCRYPTED => $DADA::Config::ROOT_PASS_IS_ENCRYPTED, 
PROGRAM_NAME           => $DADA::Config::PROGRAM_NAME, 
PROGRAM_URL            => $DADA::Config::PROGRAM_URL,
S_PROGRAM_URL          => $DADA::Config::S_PROGRAM_URL,

SIGN_IN_FLAVOR_NAME    => $DADA::Config::SIGN_IN_FLAVOR_NAME, 
DISABLE_OUTSIDE_LOGINS => $DADA::Config::DISABLE_OUTSIDE_LOGINS, 

ADMIN_FLAVOR_NAME      => $DADA::Config::ADMIN_FLAVOR_NAME, 
SHOW_HELP_LINKS        => $DADA::Config::SHOW_HELP_LINKS,
HELP_LINKS_URL         => $DADA::Config::HELP_LINKS_URL, 
MAILPROG               => $DADA::Config::MAILPROG,
FILES                  => $DADA::Config::FILES, 
VER                    => $DADA::Config::VER, 
FCKEDITOR_URL          => $DADA::Config::FCKEDITOR_URL, 

GIVE_PROPS_IN_HTML            => $DADA::Config::GIVE_PROPS_IN_HTML, 
GIVE_PROPS_IN_SUBSCRIBE_FORM  => $DADA::Config::GIVE_PROPS_IN_SUBSCRIBE_FORM, 
GIVE_PROPS_IN_ADMIN           => $DADA::Config::GIVE_PROPS_IN_ADMIN, 

DEFAULT_ADMIN_SCREEN          => $DADA::Config::DEFAULT_ADMIN_SCREEN, 

ENV_SCRIPT_URI                => $ENV{SCRIPT_URI}, 
ENV_SERVER_ADMIN              => $ENV{SERVER_ADMIN},
SHOW_HELP_LINKS               => $DADA::Config::SHOW_HELP_LINKS, 
HELP_LINKS_URL                => $DADA::Config::HELP_LINKS_URL, 

PROFILE_ENABLED               => $DADA::Config::PROFILE_ENABLED, 

# DEV: Cough! Kludge! Cough!
LEFT_BRACKET                  => '[',
RIGHT_BRACKET                 => ']',
LT_CHAR                       => '<', 
GT_CHAR                       => '>',           


# Random hacks for MS Word, Outlook (sigh)
#
# [ 2030573 ] Dadamail 3.0 strips out [endif]
# http://sourceforge.net/tracker/index.php?func=detail&aid=2030573&group_id=13002&atid=113002
#
endif                         => '[endif]',    
#
# /Random hacks for MS Word, Outlook (sigh)

(
    ($DADA::Config::CPAN_DEBUG_SETTINGS{HTML_TEMPLATE} == 1) ? 
        (debug => 1, ) :
        ()
), 

(
	
	($DADA::Config::SHOW_ADMIN_LINK eq "1") ?
		(SHOW_ADMIN_LINK  => 1,) : 
		(SHOW_ADMIN_LINK  =>  0,),
), 

                    

); 


my %Global_Template_Options = (
		# DEV: Dude, it's no wonder any templates are ever found.  		
		path              => [
								$DADA::Config::TEMPLATES, 
								$DADA::Config::ALTERNATIVE_HTML_TEMPLATE_PATH, 
								@guesses, 
								'templates', 
								'Templates/templates', 
								'DADA/Templates/templates', 
								'../DADA/Templates/templates',
								'../../DADA/Templates/templates',
							],
		die_on_bad_params => 0,	
		loop_context_vars => 1, 									
);

											
=pod

=head1 Name

DADA::Template::Widgets

=head1 Description

Holds commonly used HTML 'widgets'

=head1 Subroutines

=cut


=pod

=head2 list_popup_menu

returns a popup menu holding all the list names as labels and 
list shortnames as values

=cut


sub precendence_popup_menu { 
	
	my $li       = shift; 
	my $default = shift || undef; 
	
	if(! defined($default)){ 
		$default = $li->{precedence};
	}

	my $precendence_popup_menu = $q->popup_menu(
									-name    => 'Precedence',
	                                -values  =>  \@DADA::Config::PRECEDENCES ,
	                                -default =>  $default,
								);

	return $precendence_popup_menu; 

}

sub priority_popup_menu { 

	my $li       = shift; 
	my $default = shift || undef;
	
	
	if(! defined($default)){ 
		$default = $li->{priority};
	}
	
    my $priority_popup_menu = $q->popup_menu(
							  		-name    =>'X-Priority',
                                    -values  =>[keys %DADA::Config::PRIORITIES],
                                    -labels  => \%DADA::Config::PRIORITIES,
                                    -default =>  $default, 
                               );

	return $priority_popup_menu; 

}




sub list_popup_menu { 

	
	my %args = (
		-show_hidden         => 0,
		-name                => 'list',
		-empty_list_check    => 0, 
		-as_checkboxes       => 0, 
		-show_list_shortname => 0, 
	    @_
	); 
	my $labels = {}; 
	
	require DADA::MailingList::Settings; 
		   $DADA::MailingList::Settings::dbi_obj = $dbi_handle;
	
	my @lists = available_lists(-Dont_Die => 1); 

	 
	return ' ' if !@lists;
	
	my $l_count = 0; 
	
	# This needs its own method...
		foreach my $list( @lists ){
			my $ls = DADA::MailingList::Settings->new({-list => $list}); 
			my $li = $ls->get; 
			next if $args{-show_hidden} == 0 && $li->{hide_list} == 1; 
			if($args{-show_list_shortname} == 1){ 
				$labels->{$list} = $li->{list_name} . ' (' . $list . ')';
			}
			else { 
				$labels->{$list} = $li->{list_name};				
			}
			$l_count++;
		}
		my @opt_labels = sort { uc($labels->{$a}) cmp uc($labels->{$b}) } keys %$labels;
	#								#	
	
	if($l_count <= 0 && $args{-empty_list_check} == 1){ 
	
	    return undef; 
	}
	
	if($args{-as_checkboxes} == 1){ 
        return  $q->checkbox_group(
                                   -name      => $args{-name}, 
                                  '-values'   => [@opt_labels],
                                   -labels    => $labels,
                                   -columns   => 2, 
                                 );				 	
	
	}
	else { 
	
        return $q->popup_menu( -name    => $args{-name}, 
                               -id      => $args{-name}, 
                              '-values' => [@opt_labels],
                               -labels   => $labels,
                               -style    => 'width:200px'); 
    }
}




sub list_popup_login_form { 
	
	my %args = (
		-show_hidden => 0, 
		-auth_state  => undef, 
		@_,
	); 
	
	my $url             = $ENV{SCRIPT_URI} || $q->url(); 
	my $referer         = $ENV{HTTP_REFERER}; 
	my $query_string    = $ENV{QUERY_STRING}; 
	my $path_info       = $ENV{PATH_INFO}; 
	
	my $list_popup_menu = list_popup_menu(
							-name   	         => 'admin_list', 
				   		    -show_hidden         => $args{-show_hidden},
				   		    -empty_list_check    => 1, 
							-show_list_shortname => 1, 
				   		   );

		if(show_login_list_textbox() == 1){ 
			return screen( 
				{ 
					-screen => 'text_box_login_form.tmpl', 
			        -expr   => 1, 
			        -vars   => { 

			            list_popup_menu => $list_popup_menu, 
	                    auth_state      => $args{-auth_state},
						referer         => $referer, 
						url             => $url, 
						query_string    => $query_string, 
						path_info       => $path_info, 
						show_other_link => _show_other_link(),  
				    }
				},	
			);
		}
		else { 
						  		                 
			return screen(
			    {
			        -screen => 'list_popup_login_form.tmpl',		
			        -expr   => 1, 
			        -vars   => { 
		            
			            list_popup_menu => $list_popup_menu, 
	                    auth_state      => $args{-auth_state},
						referer         => $referer, 
						url             => $url, 
						query_string    => $query_string, 
						path_info       => $path_info, 
						show_other_link => _show_other_link(),  
				    }
				}
		    ); 
	}
}



sub default_screen {

    my %args = (
        -show_hidden        => undef,
        -name               => undef,
        -email              => undef,
        -set_flavor         => undef,
        -error_invalid_list => 0,
        @_
    );

    require DADA::MailingList::Settings;
    require DADA::MailingList::Archives;

    my $subscriber_fields;
    my @list_information = ();
    my $reusable_parser  = undef;

    # Keeps count of how many visible lists are printed out;
    my $l_count = 0;

    my $labels = {};
    foreach my $l ( available_lists() ) {

        # This is a weird placement...
        if ( !$subscriber_fields ) {
            require DADA::MailingList::Subscribers;
            my $lh = DADA::MailingList::Subscribers->new( { -list => $l } );
            $subscriber_fields = $lh->subscriber_fields;
        }

        # /This is a weird placement...

        my $ls = DADA::MailingList::Settings->new( { -list => $l } );
        my $li = $ls->get;
        next if $li->{hide_list} == 1;
        $labels->{$l} = $li->{list_name};
        $l_count++;
    }
    my @list_in_list_name_order =
      sort { uc( $labels->{$a} ) cmp uc( $labels->{$b} ) } keys %$labels;

    foreach my $list (@list_in_list_name_order) {
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $all_list_info        = $ls->get();
        my $all_list_info_dotted = $ls->get( -dotted => 1 );

        my $ah = DADA::MailingList::Archives->new(
            {
                -list => $list,
                ( ($reusable_parser) ? ( -parser => $reusable_parser ) : () )
            }
        );

        if ( $all_list_info->{hide_list} != 1 )
        {    # should we do this here, or in the template?

            $l_count++;

            # This is strange...
            $all_list_info_dotted->{'list_settings.info'} =
              webify_plain_text(
                $all_list_info_dotted->{'list_settings.info'} );
            $all_list_info_dotted->{'list_settings.info'} =
              _email_protect( $all_list_info_dotted->{'list_settings.info'} );

            my $ne      = $ah->newest_entry;
            my $subject = $ah->get_archive_subject($ne);
            $subject = $ah->_parse_in_list_info( -data => $subject );

            # These two things are sort of strange.
            $all_list_info_dotted->{newest_archive_blurb} =
              $ah->message_blurb();
            $all_list_info_dotted->{newest_archive_subject} = $subject;

            push ( @list_information, $all_list_info_dotted );

            $reusable_parser = $ah->{parser} if !$reusable_parser;

        }
    }

    my $visible_lists = 1;
    if ( $l_count == 0 ) {
        $visible_lists = 0;
    }

    my $named_subscriber_fields = [];
    foreach (@$subscriber_fields) {
        push ( @$named_subscriber_fields, { name => $_ } );
    }

    my $list_popup_menu = list_popup_menu(
        -email      => $args{email},
        -list       => $args{list},
        -set_flavor => $args{set_flavor},
    );

    return screen(
        {
            -screen => 'default_screen.tmpl',
            -expr   => 1,
            -vars   => {

                list_popup_menu    => $list_popup_menu,
                email              => $args{ -email },
                set_flavor         => $args{ -set_flavor },
                list_information   => \@list_information,
                visible_lists      => $visible_lists,
                error_invalid_list => $args{ -error_invalid_list },
                fields             => $named_subscriber_fields,
                subscription_form  => subscription_form( { -give_props => 0 } ),

            },
        }
    );
}





sub list_page { 

	my %args = (-list           => undef, 
			    -email          => undef, 
				-set_flavor     => undef,
				-error_no_email => undef, 
				-cgi_obj        => undef, 
				@_);
    

    if(exists($args{-set_flavor}) && ($args{-set_flavor} eq 'unsubscribe' || $args{-set_flavor} eq 'u')){ 
        $args{-set_flavor} = 'u' 
    }
    else {
        $args{-set_flavor} = 's' 
    }

	require DADA::MailingList::Settings; 
		   $DADA::MailingList::Settings::dbi_obj = $dbi_handle;
	
	my $ls = DADA::MailingList::Settings->new({-list => $args{-list}}); 
	my $li= $ls->get; 

	# allowed_to_view_archives
    my $html_archive_list = html_archive_list($args{-list}); 
    my $template = screen(
        {
        -expr                     => 1, 
        -screen                   => 'list_page_screen.tmpl',
        -list_settings_vars       => $li,
        -list_settings_vars_param => {-dot_it => 1},
        -vars                     => 
        { 
            subscription_form         => subscription_form({-list => $args{-list}, -email => $args{-email}, -flavor_is => $args{-set_flavor}, -give_props => 0 }), 
            error_no_email            => $args{-error_no_email}, 
            set_flavor                => $args{-set_flavor},
            html_archive_list         => $html_archive_list, 
			#allowed_to_view_archives  => $allowed_to_view_archives,  
        },
        
        -webify_and_santize_these => [qw(list_settings.list_owner_email list_settings.info list_settings.privacy_policy )], 
        
        }
    ); 

    return $template; 

}




sub admin { 

	my %args = (
		-login_widget            => $DADA::Config::LOGIN_WIDGET,
		-no_show_create_new_list => 0, 
		-cgi_obj                 => '', 
		@_,
	); 
	
	my $login_widget = $DADA::Config::LOGIN_WIDGET;

    # Why is this so BIG?!
    if($args{-login_widget} eq 'text_box'){ 
        $login_widget = 'text_box';
    } elsif($DADA::Config::LOGIN_WIDGET eq 'popup_menu'){ 
        $login_widget = 'popup_menu';
    } elsif($DADA::Config::LOGIN_WIDGET eq 'text_box') { 
        $login_widget = 'text_box';	
    } else { 
        carp "'\$DADA::Config::LOGIN_WIDGET' misconfigured!";
    }

	my @available_lists = available_lists();
	
    $DADA::Config::LIST_QUOTA = undef if strip($DADA::Config::LIST_QUOTA) eq '';
	my $list_max_reached = 0; 

    if(
      ($DADA::Config::LIST_QUOTA) && 
      (($#available_lists + 1) >= $DADA::Config::LIST_QUOTA)
     ) { 
      
	   $list_max_reached = 1;
     }	
	
	
	my $list_popup_menu = list_popup_menu(
		-name   	         => 'admin_list', 
		-show_hidden         => 0,
		-empty_list_check    => 1,
		-show_list_shortname => 1, 
	);
	
	if(!$list_popup_menu){ 
	    $login_widget = 'text_box'; # hey Zeus that's a lot of switching aboot. 
	}
		
	my $auth_state; 
	
	if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){ 
        require DADA::Security::SimpleAuthStringState;
        my $sast =  DADA::Security::SimpleAuthStringState->new;  
           $auth_state = $sast->make_state; 
	}
	
	
        my $logged_in_list_name = undef; 
        my ($admin_list, $root_login, $checksout) = check_list_security(
														-cgi_obj         => $args{-cgi_obj},  
                                                        -Function        => 'admin',
                                                        -manual_override => 1,
                                                    );
        if($checksout == 1){ 
            require DADA::MailingList::Settings; 
            $DADA::MailingList::Settings::dbi_obj = $dbi_handle;
            my $l_ls             = DADA::MailingList::Settings->new({-list => $admin_list}); 
            my $l_li             = $l_ls->get(); 
            $logged_in_list_name = $l_li->{list_name};
        }

    return screen(
                    {
                        -screen => 'admin_screen.tmpl',
                        -expr   => 1, 
                        -vars   => { 
	    
                            login_widget            => $login_widget, 
                            list_popup_menu         => $list_popup_menu,
                            list_max_reached        => $list_max_reached, 
                            auth_state              => $auth_state, 
                            show_other_link         => _show_other_link(),  
                            no_show_create_new_list => $args{-no_show_create_new_list}, 
                            logged_in_list_name     => $logged_in_list_name, 

                            }, 
                        }
	                );
}



sub _show_other_link { 

    require DADA::MailingList::Settings; 
    $DADA::MailingList::Settings::dbi_obj = $dbi_handle;
    
    
    # Basically, if there's at least one list that's hidden, we show the 
    # More... link. 
        
    foreach my $list(available_lists(-Dont_Die => 1) ){
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get; 
        return 1
            if $li->{hide_list} == 1; 
	}
			
    return 0; 
    
}




sub show_login_list_textbox { 
	
	# This means, if all the lists are hidden, we have to show the 
	# text login box. Yup. 
	#
	
	require DADA::MailingList::Settings; 
    $DADA::MailingList::Settings::dbi_obj = $dbi_handle;
    
    foreach my $list(available_lists(-Dont_Die => 1) ){
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get; 
        return 0
            if $li->{hide_list} == 0; 
	}
			
    return 1;
	
}




sub html_archive_list { 

	#  DEV: god, what a mess...
	#
	my $list = shift; 
	my $t    = "";
	
	require DADA::MailingList::Archives; 
	require DADA::MailingList::Settings;
		   $DADA::MailingList::Settings::dbi_obj = $dbi_handle;

	
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	my $li = $ls->get; 
	
	require DADA::Profile; 
	my $allowed_to_view_archives = DADA::Profile::allowed_to_view_archives(
			{
				-from_session => 1, 
				-list         => $list, 
				-ls_obj       => $ls,
			}
		);

	
	if($allowed_to_view_archives == 1){ 
		
		my $archive = DADA::MailingList::Archives->new({-list => $list}); 
		my $entries = $archive->get_archive_entries(); 
	
	
		if(defined($entries->[0])) { 
	

	        my ($begin, $stop) = $archive->create_index(0);
	        my $i;
	        my $stopped_at = $begin;
	        my $num = $begin;
        
	        $num++; 
	        my @archive_nums; 
	        my @archive_links; 
	        my $th_entries = []; 
    
        
        
	        # iterate and save
	        for($i = $begin; $i <=$stop; $i++){ 
	            my $link; 
            
	            if(defined($entries->[$i])){
                
	                my ($subject, $message, $format, $raw_msg) = $archive->get_archive_info($entries->[$i]); 
                
                
	                 # THis is stupid: 
	                 # DEV: This is stupid, and I don't think it's a great idea. 
	                    $subject = DADA::Template::Widgets::screen(
	                        {
	                        -data                    => \$subject, 
	                        -vars                     => $li, 
	                        -list_settings_vars       => $li, 
	                        -list_settings_vars_param => {-dot_it => 1},                    
	                        -dada_pseudo_tag_filter   => 1, 
							-subscriber_vars_param    => {-use_fallback_vars => 1, -list => $li->{list}},

	                        }
	                    ); 
	                    # That. Sucked.
                
                
	                # this is so atrocious.
	                my $date = date_this(-Packed_Date   => $entries->[$i],
	                -Write_Month   => $li->{archive_show_month},
	                -Write_Day     => $li->{archive_show_day},
	                -Write_Year    => $li->{archive_show_year},
	                -Write_H_And_M => $li->{archive_show_hour_and_minute},
	                -Write_Second  => $li->{archive_show_second});
    
    
	                my $entry = { 				
	                        id               => $entries->[$i], 
    
	                        date             => $date, 
	                        subject          => $subject,
	                       'format'          => $format, 
	                        list             => $list, 
	                        uri_escaped_list => uriescape($list),
	                        PROGRAM_URL      => $DADA::Config::PROGRAM_URL, 
	                        message_blurb    => $archive->message_blurb(-key => $entries->[$i]),
	                    }; 
                
	                $stopped_at++;
	                push(@archive_nums, $num); 
	                push(@archive_links, $link); 
	                $num++;
    
    
	                push(@$th_entries, $entry); 
                    
	            }
	        } 
    
	        my $ii; 
        
	        for($ii=0;$ii<=$#archive_links; $ii++){ 
    
	            my $bullet = $archive_nums[$ii];
            
	            #fix if we're doing reverse chronologic 
	            $bullet = (($#{$entries}+1) - ($archive_nums[$ii]) +1) 
	                if($li->{sort_archives_in_reverse} == 1);
    
	            # yeah, whatever. 
	            $th_entries->[$ii]->{bullet} = $bullet; 
            
	        }
    	


        $t .= screen({-screen => 'archive_list_widget.tmpl', 
                     -vars => {
                                entries              => $th_entries,
                                list                 => $list, 
                                list_name            => $li->{list_name}, 
                                publish_archives_rss => ($li->{publish_archives_rss}) ? 1: 0, 
                                index_nav            => $archive->create_index_nav($stopped_at), 
                                search_form          => ( ($li->{archive_search_form} eq "1") && (defined($entries->[0])) ) ? $archive->make_search_form($li->{list}) : ' ', 
                               allowed_to_view_archives => 1, 
							}
                    });  
 
			}
	}
	else { 
		$t = screen({-screen => 'archive_list_widget.tmpl', 
                     -vars => {
                                entries              => [],
                                list                 => $list, 
                                list_name            => $li->{list_name}, 
                                publish_archives_rss => 0,
                                index_nav            => '', 
                                search_form          => '', 
								allowed_to_view_archives => 0, 
                               }
                    });  

	}
	
	return $t; 

}




sub login_switch_widget { 

	my $args = shift; 
	
	croak "no list!" if ! $args->{-list};
	
	require DADA::MailingList::Settings; 
		   $DADA::MailingList::Settings::dbi_obj = $dbi_handle;

	my $location = $q->self_url || $DADA::Config::S_PROGRAM_URL . '?flavor=' . $args->{-f}; 

    require  DADA::App::ScreenCache; 
    my $c  = DADA::App::ScreenCache->new; 
    
    if($c->cached('login_switch_widget')){ 
        my $lsw = $c->pass('login_switch_widget');
           $lsw =~ s/\[LOCATION\]/$location/g; 
           return $lsw; 
      }

    my $scrn; 
    

	my @lists = available_lists(-dbi_handle => $dbi_handle); 
	my %label = (); 
	
	# DEV TODO - This needs its own METHOD!!!
	
	foreach my $list( @lists ){
			my $ls = DADA::MailingList::Settings->new({-list => $list}); 
			my $li = $ls->get; 
			$label{$list} = $li->{list_name} . ' (' . $list . ')'; 
			
	}
	
	$label{$args->{-list}} = '----------'; 
	
	if($lists[1]){ 
		$scrn = $q->start_form(-action => $DADA::Config::S_PROGRAM_URL, 
							  -method => "post",
							  ) . 
			   $q->popup_menu(-style   => 'width:75px', 
							  -name    => 'change_to_list', 
							  -value   => [@lists], 
							  -default => $args->{-list},
							  -labels  => {%label}, 
							  ) . 
			   $q->hidden(-name => 'location', 
						  -value => '[LOCATION]',
						 ) . 
			   $q->hidden(-name      => 'flavor', 
						   -value    => 'change_login',
						   -override => 1,
				 ) . 
	
			   $q->submit(-value => 'switch', -class=>'plain') .
			   $q->end_form(); 
	}else{ 
		$scrn = '';
	}
	
	$c->cache('login_switch_widget', \$scrn);
	
	$scrn =~ s/\[LOCATION\]/$location/g; 
	
    return $scrn; 
}




sub archive_send_form { 

	my ($list, $id, $errors, $captcha_archive_send_form, $captcha_fail) = @_; 

    my $CAPTCHA_string = '';
    # ?!?!
    $captcha_fail = defined $captcha_fail ? $captcha_fail : 0;

	my $can_use_captcha = 0; 
	eval { require DADA::Security::AuthenCAPTCHA; };
	if(!$@){ 
		$can_use_captcha = 1;        
	}
	
    if($captcha_archive_send_form == 1 && $can_use_captcha == 1){ 
            my $captcha_worked = 0; 
            my $captcha_auth   = 1; 

            require DADA::Security::AuthenCAPTCHA; 
            my $cap = DADA::Security::AuthenCAPTCHA->new; 
               $CAPTCHA_string = $cap->get_html($DADA::Config::RECAPTCHA_PARAMS->{public_key});  
    }

	return DADA::Template::Widgets::screen(
				{
				    -screen => 'send_archive_form_widget.tmpl',
				    -vars   => { 
				        send_archive_form_error => $errors, 
				        list                    => $list, 
				        id                      => $id, 
	        
				        # CAPTCHA stuff
					    can_use_captcha => $can_use_captcha, 
				        CAPTCHA_string  => $CAPTCHA_string,
				        captcha_fail    => $captcha_fail, 
				    },
				}
			); 
}



sub profile_widget { 

	my $scr          = ''; 
	my $email        = ''; 
	my $is_logged_in = 0; 
	my $profiles_enabled = $DADA::Config::PROFILE_ENABLED;
	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){
		$profiles_enabled = 0; 
	}
	else { 		
		require DADA::Profile; 
		my $dp = DADA::Profile->new({-from_session => 1}); 
		if($dp){ 
			require DADA::Profile::Session;
			require CGI; 
			my $q = new CGI; 
			my $prof_sess = DADA::Profile::Session->new; 
			if($prof_sess->is_logged_in({-cgi_obj => $q})){ 
				$is_logged_in = 1; 
			    $email        = $prof_sess->get({-cgi_obj => $q}); 
			}
		}
	}
	
	return screen(
		{
			-screen => 'profile_widget.tmpl', 
	        -vars   => { 
				profiles_enabled => $profiles_enabled,
 				is_logged_in    => $is_logged_in, 
				'profile.email' => $email,  
				gravators_enabled => $DADA::Config::PROFILE_GRAVATAR_OPTIONS->{enable_gravators},
				gravatar_img_url  => gravatar_img_url({-email => $email, -default_gravatar_url => $DADA::Config::PROFILE_GRAVATAR_OPTIONS->{default_gravatar_url}, -size => '30'}),						
				
				
		    }
		}
	); 
	
}






=pod

=head2 screen

C<screen()> is a slight wrapper around the HTML::Template module. See: 

L<http://search.cpan.org/~samtregar/HTML-Template/Template.pm>

C<screen> has somewhat of a similar API, but a bit simplier - for example, it also 
includes support for HTML::Template::Expr: 

L<http://search.cpan.org/~samtregar/HTML-Template-Expr/Expr.pm>

with just a paramater change. The default is to use HTML::Template. 
No other HTML::Template::* modules are used. 

I won't delve into great detail on how to make a HTML::Template or HTML::Template::Expr template, 
but I would encourage you to look into the docs for the two above modules for the jist. Any valid 
HTML::Template and/or HTML::Template::Expr template can be used for C<screen>.

Finally screen has some (always optional) hooks into Dada Mail's Settings and Subscribers backends, 
so you may tell C<screen> to use that information, instead of passing things in the C<-vars> paramter. 

Anyways: 

 require DADA::Template::Widgets; 
 print DADA::Template::Widgets::screen(\
    {
    # ...
    }
 ); 

C<screen> returns back a string with the final result of the template and basically what 
B<HTML::Template>'s C<output> will return. No post processing is done after that. 

Getting data to screen can be done in basically two ways: 

Via the C<-data> paramater: 

 my $scalar = 'This is my information!'; 
 print DADA::Template::Widgets::screen(
    {
        -data => \$scalar,
    }
 ); 

The information in B<-data> needs to be a reference to a scalar value. In B<H::T>, it maps to the C<scalarref> paramater. 

Via the C<-screen> paramater: 

 print DADA::Template::Widgets::screen(
    {
        -screen => 'somefile.tmpl',
    }
 );

which should be a filename to whatever template you'd like to use. 

In B<H::T>, it maps to the C<filename> paramater. 

If the data you're giving C<screen> is an HTML::Template::Expr template, you may also pass over the, 
C<-expr> paramater with a value of, C<1>: 

 print DADA::Template::Widgets::screen(
    {
        -screen => 'somefile.tmpl',
        -expr   => 1, 
    }
 );

Variables to be used in the template can be passed using the, C<-vars> paramater, which maps to the, 
B<H::T> paramater, C<param>. C<-vars> should hold a reference to a hash: 

 my $scalar = 'I wanted to say: <!-- tmpl_var var1 -->'; 
 print DADA::Template::Widgets::screen(
    {
        -data => \$scalar,
        -vars   => {var1 => "This!"}, 
    }
 );

This will print:

 I wanted to say: This!

There is one small B<HTML::Template> filter that turns the very B<very> simple (oldstyle) Dada 
Mail template-like files into something B<HTML::Template> can use. In the beginning (gather 'round, kids)
Dada Mail didn't have a Templating system (really) at all, and just used regex search and replace - 
sort of like everyone did, before they knew better. Old style Dada Mail variables looked like this: 

 [var1]

These oldstyle variables will still work, but do remember to pass the, C<-dada_pseudo_tag_filter>
with a value of, C<1> to enable this filter: 

 my $scalar = 'I wanted to say: [var1]'; 
 print DADA::Template::Widgets::screen(
    {
        -data                   => \$scalar,
        -vars                   => {var1 => "This!"}, 
        -dada_pseudo_tag_filter => 1, 
    }
 );

This will print:

 I wanted to say: This!

My suggestion is to try not to mix the two dialects and note that we'll I<probably> be moving to 
using the B<H::T> default template conventions, so as to make geeks and nerds more comfortable with 
the program. Saying that, you I<can> mix the two dialects and everything should work. This may be 
interesting in a pinch, where you want to say something like: 

 Welcome to [boring_name]
 
 <!-- tmpl_if boring_description --> 
  My boring description: 
  
    [boring_description]
    
 <!--/tmpl_if--> 

since the oldstyle Dada Mail template stuff didn't have any sort of idea of a C<if> block. I'm not 
really considering adding support either. 

And that's basically screen. Learn HTML::Template and memorize the mappings and you'll be right at home. 

A few things to mention: 

Many of the Dada Mail modules require you to pass a B<listshortname> some where - C<screen> doesn't,
and this is by design - it attempts to be separate from any Dada Mail backend or information inside. 

There are hooks in C<screen> to pass variables in the template from the settings and subscriber 
backend, but they're limited and absolutely optional, but are handy for shortcuts and hey, what isn't 
programming but shortcuts?

To tell C<screen> to use a specific subscriber information, you have two different methods. 

The first is to give the paramaters to *which* subscriber to use, via the C<-subscriber_vars_param>: 

 print DADA::Template::Widgets::screen(
    {
    -subscriber_vars_param => 
        {
            -list  => 'listshortname', 
            -email => 'this@example.com', 
            -type  => 'list',
        }
    }
 );

This will basically have C<screen> call the B<DADA::MailingList::Subscribers::*> C<get_subscriber> 
method and pass the paramaters set in this hashref. It's best to make sure the subscriber I<exists>, 
or you may run into trouble.

The subscriber information will be passed to B<HTML::Template> via its C<param> method. The name of 
the paramaters will be appended with, B<subscriber.>, so as not to clobber any other variables you're 
passing, so if you have a field named, "first_name", you can use a template var that looks like this: 

 <!-- tmpl_var subscriber.first_name --> 

or: 

 [subscriber.first_name]

The following won't work: 

 <!-- tmpl_var first_name --> 

 [first_name]

B<Note:> that this dot notation isn't using B<HTML::Template::Plugin::Dot>, but is just a variable 
naming convention, to give the subscriber information some sort of namespace.


The other magical thing that will happen, is that you'll get a new variable to be used in your template
called, B<subscriber>, which is a array ref of hashrefs with name/value pairs for all your subscriber 
fields. So, this'll allow you to do something like this: 

 <!-- tmpl_loop subscriber --> 
 
  <!-- tmpl_var name -->: <!-- tmpl_value -->
 
 <!--/tmpl_loop-->

and this will loop over your subscriber fields. 

If you'd like, you can also pass the subscriber fields information yourself - this may be useful if
you're in some sort of recursive subroutine, or if you already have the information on hand. You may
do so by passing the, C<-subscriber_vars> paramater, I<instead> of the C<-subscriber_vars_param>
paramater, like so: 

 use DADA::MailingList::Subscribers; 
 my $lh = DADA::MailingList::Subscribers->new({-list => 'listshortname'}); 
 
 my $subscriber = $lh->get_subscriber(
                      {
                         -email  => 'this@example.com', 
                         -type   => 'list', 
                         -dotted => 1, 
                       }
                   ); 
 
 use DADA::Template::Widgets; 
 print DADA::Template::Wigets::screen(
 
           { 
                -subscriber_vars => $subscriber,
           }
       ); 

The, B<subscriber> variable will still be magically created for you. 

The B<-subscriber_vars> paramater is also a way to override what gets printed for the, B<subscriber.> 
variables, since nothing is done to check the validity of what you're passing. So, keep that in mind - 
all these are shortcuts and syntactic sugar. And we I<like> sugar. 



A similar thing can be used to retrieve the list settings of a particular list: 

 print DADA::Template::Widgets::screen(
    {
    -list_settings_vars_param => 
        {
            -list  => 'listshortname', 
        }
    }
 );

or:

 use DADA::MailingList::Settings; 
 my $ls = DADA::MailingList::Settings->new({-list => 'mylist'}); 
 
 my $list_settings = $ls->get(
                         -dotted => 1, 
                     ); 
 
 use DADA::Template::Widgets; 
 print DADA::Template::Wigets::screen(
 
           { 
                -list_settings_vars => $list_settings,
           }
       ); 

This will even work, as well in a template: 

 <!-- tmpl_loop list_settings --> 
 
    <!-- tmpl_var name -->: <!-- tmpl_var value -->
 
 <!-- /tmpl_loop -->

Again, much of this is syntactical sugar and magic, but a lot of it is to keep organized the various
sources of your template data. Only at the very final time is all this information folded into itself. 

The precendence for these various variables is: 

=over

=item * -list_settings_vars

=item * -subscriber_vars

=item * -vars

=back

Which means, if you (for whatever weird reason) want to override anything in either the 
B<-list_settings_vars> or B<-subscriber_vars>, you can in B<-vars>

=cut


sub screen {  

    my ($args) = @_; 

    if (! exists($args->{-screen}) && ! exists($args->{-data})){ 
        croak "no -screen! or -data!";
    }
    
    if(! exists($args->{-vars})){ 
        $args->{-vars} = {};
    }
    
    if(! exists($args->{-expr})){ 
        $args->{-expr} = 0;
    }    
    
    if(! exists($args->{-dada_pseudo_tag_filter})){ 
        $args->{-dada_pseudo_tag_filter} = 0;
    }
    

    
    # This is for mispelings: 
	foreach('-list_settings_param', 'list_settings_param', 'list_settings_vars_params', '-list_settings_vars_params', 'list_settings_params', '-list_settings_params'){ 
		if(exists($args->{$_})){ 
			croak "Incorrect paramater passed to DADA::Template::Widgets:'$_'. Did you mean to pass, '-list_settings_vars_param'? $@";
		}
	}



    if(
        exists($args->{-list_settings_vars})       || 
        exists($args->{-list_settings_vars_param})
    ){ 
    
        if( !exists($args->{-list_settings_vars_param}) ){ 
            # Well, nothing. 
            $args->{-list_settings_vars_param} = {}; 
        }
        else { 
            
            if(
                !exists($args->{-list_settings_vars})      &&  # Don't write over something that's already there. 
                 exists($args->{-list_settings_vars_param})    # This is a rehash of the last if() statement, but it's here, for clarity...
            ){             
                require DADA::MailingList::Settings; 
                my $ls = DADA::MailingList::Settings->new(
							{
                             	-list => $args->{-list_settings_vars_param}->{-list},
                         	}
						); 
                $args->{-list_settings_vars} = $ls->get(-dotted => 1);
                
                
                #foreach(keys %{$args->{-list_settings_vars}}){ 
                #    warn $_ . ' => ' . $args->{-list_settings_vars}->{$_};
                #}
                
                
                if( !exists($args->{-list_settings_vars_param}->{i_know_what_im_doing}) ){                     
                    # this is to get really naughty bits out: 
                    foreach(qw(
                        password
                        pop3_password
                        sasl_smtp_password
                        pass_auth_id
                        discussion_pop_password
                        pop3_username
                        sasl_smtp_username
                        discussion_pop_username
                        cipher_key
                        
                    )){ 
                        if(exists($args->{-list_settings_vars}->{'list_settings.' . $_})){ 
                            delete($args->{-list_settings_vars}->{'list_settings.' . $_}); 
                        }  
                    }
                }
            }
       }
       
       if(!exists($args->{-list_settings_vars_param}->{-dot_it})){
            $args->{-list_settings_vars_param}->{-dot_it} = 0; 
       }


       if($args->{-list_settings_vars_param}->{-dot_it} == 1){
            
            my $new = {}; 
            
            while (my ($k, $v) = each(%{$args->{-list_settings_vars}})){
                if($k =~ m/^list_settings\./){ 
                    $new->{$k} = $v 
                }
                else { 
                    $new->{'list_settings.' . $k} = $v; 
                }       
            }
            
            $args->{-list_settings_vars} = $new;         
       }



      if(!exists($args->{-vars}->{list_settings})){
        
            $args->{-vars}->{list_settings} = [];
            foreach(keys %{$args->{-list_settings_vars}}){ 
                my $nk = $_; 
                $nk =~ s/list_settings\.//; 
                push( @{$args->{-vars}->{list_settings}}, {name => $nk, value => $args->{-list_settings_vars}->{$_}});   
            }
        }
    }
    else { 
        $args->{-list_settings_vars}       = {};
        $args->{-list_settings_vars_param} = {};
    }
    
    
    
    
    if(
        exists($args->{-subscriber_vars})       || 
        exists($args->{-subscriber_vars_param})
    ){ 

   
        if(!exists($args->{-subscriber_vars_param})){ 
            $args->{-subscriber_vars_param} = {}; 
        }
        else { 
      
            if(
                !exists($args->{-subscriber_vars})       &&  # Don't write over something that's already there. 
                 exists($args->{-subscriber_vars_param})     # This is a rehash of the last if() statement, but it's here, for clarity...
            ){       


	      		if(
					exists($args->{-subscriber_vars_param}->{-email}) &&
					exists($args->{-subscriber_vars_param}->{-type})
				){ 
  					
            	    require  DADA::MailingList::Subscribers;     
                
	                my $lh = DADA::MailingList::Subscribers->new(
								{
	                            	-list => $args->{-subscriber_vars_param}->{-list},
	                         	}
							); 
              		

	                $args->{-subscriber_vars} = $lh->get_subscriber(
	                                                {
	                                                    -email  => $args->{-subscriber_vars_param}->{-email}, 
	                                                    -type   => $args->{-subscriber_vars_param}->{-type},
	                                                    -dotted => 1, 
	                                                }
	                                            ); 
                }

            } #if(!exists($args->{-subscriber_vars})){ 
	
				if(exists($args->{-subscriber_vars_param}->{-use_fallback_vars})){ 
					if($args->{-subscriber_vars_param}->{-use_fallback_vars} == 1){ 
						require DADA::MailingList::Subscribers;
					  	my $lh = DADA::MailingList::Subscribers->new(
									{
		                            	-list => $args->{-subscriber_vars_param}->{-list},
		                         	}
								);
		
								my $fallback_vars = $lh->get_all_field_attributes; 
					
						# This is sort of an odd placement for this, but I'm not sure 
						# Where I want this yet...  (perhaps $lh->get_fallback_values ?)
							if(!exists($args->{-subscriber_vars}->{'subscriber.email'})){ 
								$fallback_vars->{'subscriber.email'} = 'example@example.com'; 
							}
							my ($name, $domain) = split('@', $fallback_vars->{'subscriber.email'}, 2); 
							$fallback_vars->{'subscriber.email_name'}   = $name; 
							$fallback_vars->{'subscriber.email_domain'} = $domain; 
							$fallback_vars->{'subscriber.pin'}          = make_pin(-Email => $fallback_vars->{'subscriber.email'}, $args->{-subscriber_vars_param}->{-list});
						### /

						foreach(keys %$fallback_vars){ 
							if(! exists($args->{-subscriber_vars}->{$_})){ 
								
								#warn "I'm putting in a fallback field $_ that equals: " . $fallback_vars->{$_}; 
								
								$args->{-subscriber_vars}->{$_} = $fallback_vars->{$_};
							}	
							else  { 
								#warn "no need for the fallback var! We're good with: " . $args->{-subscriber_vars}->{$_}; 
							}
						}
					}	
					
				}#if(exists($args->{-subscriber_vars_param}->{-use_fallback_vars}){
					

			if(exists($args->{-subscriber_vars_param}->{-use_fallback_vars})){ 
				if($args->{-subscriber_vars_param}->{-use_fallback_vars} == 1){ 
					require DADA::MailingList::Subscribers;
				  	my $lh = DADA::MailingList::Subscribers->new(
								{
	                            	-list => $args->{-subscriber_vars_param}->{-list},
	                         	}
							);

							my $fallback_vars = $lh->get_all_field_attributes; 

					# This is sort of an odd placement for this, but I'm not sure 
					# Where I want this yet...  (perhaps $lh->get_fallback_values ?)
						$fallback_vars->{'subscriber.email'}        = 'example@example.com'; 
					    $fallback_vars->{'subscriber.email_name'}   = 'example'; 
					    $fallback_vars->{'subscriber.email_domain'} = 'example.com';    
				        $fallback_vars->{'subscriber.pin'}          = '1234';
					### /

					foreach(keys %$fallback_vars){ 
						if(! exists($args->{-subscriber_vars}->{$_})){ 
							$args->{-subscriber_vars}->{$_} = $fallback_vars->{$_};
						}	
					}
				}	

			}#if(exists($args->{-subscriber_vars_param}->{-use_fallback_vars}){
        
        } #if(!exists($args->{-subscriber_vars_param})){ 

      
        if( !exists($args->{-vars}->{subscriber}) ){
        
            $args->{-vars}->{subscriber} = [];
          
            if(exists($args->{-subscriber_vars_param}->{-in_order})){ 
                foreach(sort %{$args->{-subscriber_vars}}){ 
                    my $nk = $_; 
                    $nk =~ s/subscriber\.//; 
                    push( @{$args->{-vars}->{subscriber}}, {name => $nk, value => $args->{-subscriber_vars}->{$_}});
                }
            }
            else { 
                foreach(keys %{$args->{-subscriber_vars}}){ 
                    my $nk = $_; 
                       $nk =~ s/subscriber\.//; 
                    push( @{$args->{-vars}->{subscriber}}, {name => $nk, value => $args->{-subscriber_vars}->{$_}});
                }
            } #if(exists($args->{-subscriber_vars_param}->{-in_order})){ 
        } #if( !exists($args->{-vars}->{subscriber}) ){
    } # exists($args->{-subscriber_vars}) || exists($args->{-subscriber_vars_param})
    else { 
        $args->{-subscriber_vars}       = {};
        $args->{-subscriber_vars_param} = {};
    }
    
    
###

if($DADA::Config::PROFILE_ENABLED == 1 && $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/){ 
	if(
	     exists($args->{-profile_vars})       || 
	     exists($args->{-profile_vars_param})
	 ){ 
 
	     if( !exists($args->{-profile_vars_param}) ){ 
	         # Well, nothing. 
	         $args->{-profile_vars_param} = {}; 
	     }
	     else { 
         
	         if(
	             !exists($args->{-profile_vars})      &&  # Don't write over something that's already there. 
	              exists($args->{-profile_vars_param})    # This is a rehash of the last if() statement, but it's here, for clarity...
	         ){  
				if(exists($args->{-profile_vars_param}->{-email})){ 
			         require DADA::Profile; 
					 my $prof = DADA::Profile->new(
						{
							-email => $args->{-profile_vars_param}->{-email},
						}
					);
					if($prof->exists){ 
		             $args->{-profile_vars} = $prof->get(
						{
							-dotted => 1,
						}
					);
		        	}
					else { 
						$args->{-profile_vars} = {};
					}
		         }
			}
	    }
    

	   if(!exists($args->{-vars}->{profile})){
     
	         $args->{-vars}->{profile} = [];
	         foreach(keys %{$args->{-profile_vars}}){ 
	             my $nk = $_; 
	             $nk =~ s/profile\.//; 
	             push( @{$args->{-vars}->{profile}}, {name => $nk, value => $args->{-profile_vars}->{$_}});   
	         }
	     }
	 }
	 else { 
	     $args->{-profile_vars}       = {};
	     $args->{-profile_vars_param} = {};
	 }
}
else { 
	$args->{-profile_vars}       = {};
    $args->{-profile_vars_param} = {};
}




    
     my $template_vars = {}; 
        %$template_vars = (%{$args->{-list_settings_vars}}, %{$args->{-subscriber_vars}}, %{$args->{-profile_vars}}, %{$args->{-vars}}); 

    if(exists($args->{-webify_and_santize_these})){ 
        $template_vars = webify_and_santize(
            {
                -to_sanitize => $args->{-webify_and_santize_these},
                -vars        => $template_vars,
 
            }
        )
    }

	if(exists($args->{-webify_these})){ 
		foreach(@{$args->{-webify_these}}){ 
	    	$template_vars->{$_} = webify_plain_text($template_vars->{$_});
	    }
	}



	my $template; 
	
	if($args->{-expr}){ 
	
		if($args->{-screen}){ 
	
			 require HTML::Template::MyExpr;
			 $template = HTML::Template::MyExpr->new(%Global_Template_Options, 
													 filename => $args->{-screen},
                                                         
                                                         ($args->{-dada_pseudo_tag_filter} == 1) ?
                                                         (
                                                         filter => [ 

                                                              { sub => \&dada_backwards_compatibility,
                                                               format => 'scalar' },
                                                             { sub => \&dada_pseudo_tag_filter,
                                                               format => 'scalar' },
                                                         ])
                                                         :
                                                         (),
                                        
													);
		}elsif($args->{-data}){ 
		
			require HTML::Template::MyExpr;
			$template = HTML::Template::MyExpr->new(%Global_Template_Options, 
												  scalarref => $args->{-data},
												  
                                                         
                                                         ($args->{-dada_pseudo_tag_filter} == 1) ?
                                                         (
                                                        filter => [ 
													   
                                                              { sub => \&dada_backwards_compatibility,
                                                               format => 'scalar' },
                                                             { sub => \&dada_pseudo_tag_filter,
                                                               format => 'scalar' },
                                                         ])
                                                         :
                                                         (),

                                                    
													);
		}else{ 
			carp "what are you trying to do?!"; 
		}
		
   }else{ 
   
   	if($args->{-screen}){ 

   		require HTML::Template;
		$template = HTML::Template->new(%Global_Template_Options, 
										filename => $args->{-screen},
                                                         
                                                         ($args->{-dada_pseudo_tag_filter} == 1) ?
                                                         (
                                                        filter => [ 

                                                              { sub => \&dada_backwards_compatibility,
                                                               format => 'scalar' },
                                                             { sub => \&dada_pseudo_tag_filter,
                                                               format => 'scalar' },
                                                         ])                                                         :
                                                         (),


							   );

	}elsif($args->{-data}){ 

   		require HTML::Template;
		$template = HTML::Template->new(%Global_Template_Options, 
										scalarref => $args->{-data},

                                                                     
                                        ($args->{-dada_pseudo_tag_filter} == 1) ?
                                        (
                                                        filter => [ 

                                                              { sub => \&dada_backwards_compatibility,
                                                               format => 'scalar' },
                                                             { sub => \&dada_pseudo_tag_filter,
                                                               format => 'scalar' },
                                                         ])                                        :
                                        (),


							   );
							   					   
   		}else{ 
			carp "what are you trying to do?!"; 
		}
   }
   
   
   
#   foreach(keys %{$args->{-list_settings_vars}}){ 
#    warn "list settings! " . $_ . ' => ' . $args->{-list_settings_vars}->{$_}; 
#   }
   
   $template->param(   
					%Global_Template_Variables,
					
					# I like that, (not) 
					date    => scalar(localtime()),
					
					%$template_vars,

				   
				   ); 
				   
	if($args->{-list}){ 
		$template->param('list', $args->{-list}); 
	}
				   
	return $template->output();
}



sub dada_backwards_compatibility { 

    my $sref = shift; 
    
	if(!defined($$sref)){ return; }
	
#	<http://maillists.bigbcreations.com/cgi-bin/dada/mail.cgi/n/FreedomFit/justin/skazat.com/7557432/>
	
	$$sref =~ s{\[plain_list_confirm_subscribe_link\]}{[PROGRAM_URL]/n/[list_settings.list]/[subscriber.email_name]/[subscriber.email_domain]/[subscriber.pin]/}g;
	$$sref =~ s{\[plain_list_confirm_unsubscribe_link\]}{[PROGRAM_URL]/u/[list_settings.list]/[subscriber.email_name]/[subscriber.email_domain]/[subscriber.pin]/}g;
	
	
    $$sref =~ s{\[list_privacy_policy\]}{[privacy_policy]}g;
    $$sref =~ s{\[list_info\]}{[info]}g;
    $$sref =~ s{\[subscriber_email\]}{[email]}g;

    $$sref =~ s{\[program_url\]}{[PROGRAM_URL]}g;

    foreach (qw(
        email
        email_name
        email_domain
        pin
    )){ 
        $$sref =~ s{\[$_\]}{[subscriber.$_]}g; 
    }
    
    foreach (qw(
        list
        list_name                             
        info    
        physical_address
        privacy_policy                 
        list_owner_email                      
        list_admin_email                      
    )){ 
        $$sref =~ s{\[$_\]}{[list_settings.$_]}g; 
    }
    
    
}




sub dada_pseudo_tag_filter { 

    my $text_ref = shift;
    
	if(!defined($$text_ref)){ return; }

	$$text_ref =~ s{\[tmpl_else\]}{<!-- tmpl_else -->}g;
	
	# This one doesn't make too much sense:
	$$text_ref =~ s{\[tmpl_else\s(\w+?)\]}{<!-- tmpl_else $1 -->}g;
    
	$$text_ref =~ s{\[((\w+?)|subscriber\.\w+?|list_settings\.\w+?)\]}{<!-- tmpl_var $1 -->}g; # Match 1 or more word (alphanum + _), non-greedy


	$$text_ref =~ s{\[(profile\.\w+?)\]}{<!-- tmpl_var $1 -->}g; # Match 1 or more word (alphanum + _), non-greedy



    # I know I said I wasn't going to do it, but I did it. 

    $$text_ref =~ s{\[tmpl_if\s((\w+?)|subscriber\.\w+?|list_settings\.\w+?)\]}{<!-- tmpl_if $1 -->}g;
    $$text_ref =~ s{\[/tmpl_if\]}{<!-- /tmpl_if -->}g;
    
    
    
    $$text_ref =~ s{\[tmpl_unless\s((\w+?)|subscriber\.\w+?|list_settings\.\w+?)\]}{<!-- tmpl_unless $1 -->}g;
    $$text_ref =~ s{\[/tmpl_unless\]}{<!-- /tmpl_unless -->}g;
    
    $$text_ref =~ s{\[tmpl_loop\s((\w+?)|subscriber\.\w+?|list_settings\.\w+?)\]}{<!-- tmpl_loop $1 -->}g; 
    $$text_ref =~ s{\[/tmpl_loop\]}{<!-- /tmpl_loop -->}g;
   
   
}




sub webify_and_santize { 

    my ($args) = @_; 
    
    if(!exists($args->{-vars})){ 
        die "need to pass, -vars"; 
    }
    
    if(!exists($args->{-to_sanitize})){ 
        die "need to pass, -to_sanitize"; 
    }
    
    foreach(@{$args->{-to_sanitize}}){ 
    
        
        $args->{-vars}->{$_} = webify_plain_text($args->{-vars}->{$_});
        $args->{-vars}->{$_} = _email_protect($args->{-vars}->{$_});  
        
    }
    
    return $args->{-vars};
    
}




sub _email_protect { 
    
    my $str = shift; 
    
    # strange module - API based on File::Find I guess.
	require Email::Find;
 	my $found_addresses = []; 
   
	my $finder = Email::Find->new(sub {
									my($email, $orig_email) = @_;
									push(@$found_addresses, $orig_email); 
									return $orig_email; 
								});
	$finder->find(\$str); 
	
	foreach my $fa (@$found_addresses){ 		
    
    
#
#
#		if($self->{list_info}->{archive_protect_email} eq 'recaptcha_mailhide'){ 
#            my $pe = mailhide_encode($fa);
#            my $le = quotemeta($fa); 
#            $body =~ s/$le/$pe/g;
#            
#		}
#		elsif($self->{list_info}->{archive_protect_email} eq 'spam_me_not'){ 		

    
            my $pe = spam_me_not_encode($fa);
            



            my $le = quotemeta($fa); 
            $str =~ s/$le/$pe/g;
            
            
        }


#	}

    return $str; 
 }




sub subscription_form { 

   
    my ($args) = @_; 
    
        
    if(! exists($args->{-give_props})){
        $args->{-give_props} = $DADA::Config::GIVE_PROPS_IN_SUBSCRIBE_FORM; 
    }
   	
    if(! exists($args->{-ajax_subscribe_extension})){ 
        $args->{-ajax_subscribe_extension} = 0; 
    }   
    
    if(! exists($args->{-script_url})){ 
        $args->{-script_url} = $DADA::Config::PROGRAM_URL; 
    }
    
        
    if(! exists($args->{-multiple_lists})){ 
        $args->{-multiple_lists} = 0; 
    }

	if(! exists($args->{-show_fields})){ 
		$args->{-show_fields} = 1; 
	}
    
    my $li;
    my @available_lists = available_lists(-Dont_Die => 1); 
    if(! $available_lists[0]){ 
        return ''; 
    }
    
    
    require DADA::Profile::Fields; 
    my $dpf = DADA::Profile::Fields->new; 
	my $subscriber_fields = $dpf->fields;
	my $field_attrs = $dpf->get_all_field_attributes;
	my $named_subscriber_fields = [];

	foreach(@$subscriber_fields){ 
	    push(
			@$named_subscriber_fields, 
				{
					name        => $_, 
					pretty_name => $field_attrs->{$_}->{label},
					label 		=> $field_attrs->{$_}->{label},
				}
			)
	}
	
	
	if(! exists ($args->{-ignore_cgi}) && $args->{-ignore_cgi} != 1){ 
   
        require CGI; 

 
        my $q = new CGI; 
           $q->charset($DADA::Config::HTML_CHARSET);

        foreach(qw(email list )){ 
            if(! exists ( $args->{'-' . $_} ) && defined($q->param($_))){ 
                $args->{'-' . $_} = xss_filter($q->param($_));
            }
        }
        

        # rewrite.
		# THis is pretty weird. 
        if(! exists ( $args->{'-flavor_is'} ) && defined($q->param('set_flavor'))){ 
               $args->{'-flavor_is'} = xss_filter($q->param('set_flavor')); 
        }

        my $i = 0; 
        foreach my $sf(@$subscriber_fields){ 
            if(defined($q->param($sf))){ 
                $named_subscriber_fields->[$i]->{given_value} = xss_filter($q->param($sf));
            }
            $i++;
        }
        undef($i);

		$args->{-profile_logged_in} = 0; 
		if($DADA::Config::PROFILE_ENABLE_MAGIC_SUBSCRIPTION_FORMS == 1) { 
			require DADA::Profile::Session; 
			my $sess = DADA::Profile::Session->new; 
			if($sess->is_logged_in){ 
				my $email                   = $sess->get; 
				$args->{-email}             = $email;
				$args->{-show_fields}       = 0; 
				$args->{-profile_logged_in} = 1; 
			}
			else { 
				# ...
			}
		}
		
		
		
		
		
    }



    
    my $list = $args->{-list} || undef; 
    if(! exists $args->{-flavor_is}){ 
        $args->{-flavor_is} = 'subscribe'; 
    }
    


    my $flavor_is_subscribe   = 1; 
    my $flavor_is_unsubscribe = 0; 
    if($args->{-flavor_is} eq 'u' || $args->{-flavor_is} eq 'unsubscribe'){ 
        $flavor_is_subscribe   = 0; 
        $flavor_is_unsubscribe = 1;  
    }
    
	
	
    
    if($list){ 
     
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
           $li = $ls->get(); 
           
        return screen({
            -screen => 'subscription_form_widget.tmpl', 
            -vars   => {
                           
                            single_list              => 1, 
                            
                            subscriber_fields        => $named_subscriber_fields,
                            list                     => $list, 
                            list_name                => $li->{list_name}, 
                            email                    => $args->{-email},
                            flavor_is_subscribe      => $flavor_is_subscribe, 
                            flavor_is_unsubscribe    => $flavor_is_unsubscribe,
                            closed_list              => $li->{closed_list}, 
                            list_popup_menu          => list_popup_menu(),
                            give_props               => $args->{-give_props}, 
                            ajax_subscribe_extension => $args->{-ajax_subscribe_extension},
                            script_url               => $args->{-script_url}, 
							show_fields              => $args->{-show_fields}, 
							profile_logged_in        => $args->{-profile_logged_in}, 
                            
                        }
                    });  
                
    }
    else { 
  return screen({
            -screen => 'subscription_form_widget.tmpl', 
            -vars   => {
                            
                            single_list              => 0, 
                            
                            subscriber_fields        => $named_subscriber_fields,
                            list                     => $list, 
                            email                    => $args->{-email},
                            flavor_is_subscribe      => $flavor_is_subscribe, 
                            flavor_is_unsubscribe    => $flavor_is_unsubscribe,
                            list_popup_menu          => list_popup_menu(),
                            list_checkbox_menu       => list_popup_menu(-as_checkboxes => 1), 
                            give_props               => $args->{-give_props} == 1, 
                            ajax_subscribe_extension => $args->{-ajax_subscribe_extension}, 
                            multiple_lists           => $args->{-multiple_lists}, 
                            script_url               => $args->{-script_url}, 
							show_fields              => $args->{-show_fields}, 
							profile_logged_in        => $args->{-profile_logged_in}, 
                        }
                    });      
    
    
    
    }

}




sub file_path { 

    my $fn   = shift; 
    if(!$fn){ 
        croak "You did not pass a filename as the sole argument!!!"; 
    }
    my $path = undef; 
    
    foreach my $path(@{$Global_Template_Options{path}}){ 
        if(-e $path . '/' . $fn){ 
            return $path . '/' . $fn;
        }
    }
}



sub _raw_screen { 
	
	my ($args) = @_; 
	
	my $screen = $args->{-screen}; 
	
	
	my $path = file_path($screen);
	
	if($path){ 
		return _slurp($path);
	}
	else { 
		carp "cannot find, $screen to open!"; 
	}
}



sub _slurp { 
	
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, "<$file") || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}







1;




=pod

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

=cut
