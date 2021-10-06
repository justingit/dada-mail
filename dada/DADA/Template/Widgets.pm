package DADA::Template::Widgets;
use lib qw(
	../../../ 
	../../../DADA/perllib
); 

use Encode; 
use Try::Tiny; 
use Carp qw(croak carp); 

use DADA::Config qw(!:DEFAULT);  

use constant HAS_HTML_TEMPLATE_PRO => eval { require HTML::Template::Pro; 1; }; 

my $TMP_TIME = undef; 
use POSIX; 

BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}


use DADA::App::Guts; 
my $q; 

lame_init(); 

my $wierd_abs_path = __FILE__; 
   $wierd_abs_path =~ s{^/}{}g;

my @guesses; 
my $Templates; 

if(! $DADA::Config::ALTERNATIVE_HTML_TEMPLATE_PATH ){ 

	eval { require File::Spec };
	
	if(!$@){

	   $Templates  =  File::Spec->rel2abs($wierd_abs_path);
	   $Templates  =~ s/DADA\/Template\/Widgets\.pm$//g;
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
   $second_guess_template  =~ s/DADA\/Template\/Widgets\.pm$//g;
   $second_guess_template  =~ s/\/$//;
   $second_guess_template .= '/templates';
   $second_guess_template  = '/' . $second_guess_template;

	push(@guesses, $second_guess_template);


	my $getpwuid_call; 
	eval { $getpwuid_call = ( getpwuid $> )[7] };
	if(!$@){ 
		# They're called guess, right? right...
		push(@guesses, $getpwuid_call . '/cgi-bin/dada/templates');
		push(@guesses, $getpwuid_call . '/public_html/cgi-bin/templates');
		push(@guesses, $getpwuid_call . '/public_html/dada/templates');
	}

require Exporter; 

use vars (@ISA, @EXPORT); 

@ISA    = qw(Exporter);  
@EXPORT = qw( 
 
templates_dir
priority_popup_menu
list_popup_menu
list_popup_login_form
default_screen
send_url_email_screen
login_switch_widget
screen
absolute_path
subscription_form
unsubscription_form
archive_send_form
profile_widget
_raw_screen
);

use strict; 
use vars qw( @EXPORT );

my %Global_Template_Variables = (
comment                     => 0, 

SUPPORT_FILES_URL           => $DADA::Config::SUPPORT_FILES->{url}, 
kcfinder_enabled            => $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled},
core5_filemanager_enabled   => $DADA::Config::FILE_BROWSER_OPTIONS->{core5_filemanager}->{enabled},
rich_filemanager_enabled    => $DADA::Config::FILE_BROWSER_OPTIONS->{rich_filemanager}->{enabled},
		
ROOT_PASS_IS_ENCRYPTED       => $DADA::Config::ROOT_PASS_IS_ENCRYPTED, 
PROGRAM_NAME                 => $DADA::Config::PROGRAM_NAME, 
PROGRAM_URL                  => $DADA::Config::PROGRAM_URL,
S_PROGRAM_URL                => $DADA::Config::S_PROGRAM_URL,
S_PROGRAM_URL_base64_encoded => encode_html_entities($DADA::Config::S_PROGRAM_URL, '\W'), 

SIGN_IN_FLAVOR_NAME    => $DADA::Config::SIGN_IN_FLAVOR_NAME, 
DISABLE_OUTSIDE_LOGINS => $DADA::Config::DISABLE_OUTSIDE_LOGINS, 

ADMIN_FLAVOR_NAME      => $DADA::Config::ADMIN_FLAVOR_NAME, 
HELP_LINKS_URL         => $DADA::Config::HELP_LINKS_URL, 
MAILPROG               => $DADA::Config::MAILPROG,
FILES                  => $DADA::Config::FILES, 
TEMPLATES              => $DADA::Config::TEMPLATES,
VER                    => $DADA::Config::VER, 

DATA_CACHE             => $DADA::Config::DATA_CACHE, 


# CAPTCHA!
captcha_params_recaptcha_type     => $DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type},
captcha_params_v2_public_key      => $DADA::Config::RECAPTCHA_PARAMS->{v2}->{public_key},
captcha_params_v2_private_key     => $DADA::Config::RECAPTCHA_PARAMS->{v2}->{private_key},
captcha_params_v3_public_key      => $DADA::Config::RECAPTCHA_PARAMS->{v3}->{public_key},
captcha_params_v3_private_key     => $DADA::Config::RECAPTCHA_PARAMS->{v3}->{private_key},

can_use_Google_reCAPTCHA_v2       => scalar DADA::App::Guts::can_use_Google_reCAPTCHA_v2(), 
can_use_Google_reCAPTCHA_v3       => scalar DADA::App::Guts::can_use_Google_reCAPTCHA_v3(), 


GIVE_PROPS_IN_HTML             => $DADA::Config::GIVE_PROPS_IN_HTML, 
GIVE_PROPS_IN_SUBSCRIBE_FORM   => $DADA::Config::GIVE_PROPS_IN_SUBSCRIBE_FORM, 
GIVE_PROPS_IN_ADMIN            => $DADA::Config::GIVE_PROPS_IN_ADMIN, 
GIVE_PROPS_IN_EMAIL            => $DADA::Config::GIVE_PROPS_IN_EMAIL, 
          
		  
GLOBAL_UNSUBSCRIBE             => $DADA::Config::GLOBAL_UNSUBSCRIBE,                     
GLOBAL_BLACK_LIST              => $DADA::Config::GLOBAL_BLACK_LIST,             

DEFAULT_ADMIN_SCREEN           => $DADA::Config::DEFAULT_ADMIN_SCREEN, 
MAIL_SETTINGS                  => $DADA::Config::MAIL_SETTINGS, 
MASS_MAIL_SETTINGS             => $DADA::Config::MASS_MAIL_SETTINGS, 
VER                            => $DADA::Config::VER, 
                               
                               
ENV_SCRIPT_URI                 => $ENV{SCRIPT_URI}, 
ENV_SERVER_ADMIN               => $ENV{SERVER_ADMIN},
HELP_LINKS_URL                 => $DADA::Config::HELP_LINKS_URL, 
HTML_CHARSET                   => $DADA::Config::HTML_CHARSET, 
PROFILE_ENABLED                => $DADA::Config::PROFILE_OPTIONS->{enabled}, 
ENFORCE_CLOSED_LOOP_OPT_IN     => $DADA::Config::ENFORCE_CLOSED_LOOP_OPT_IN != 1 ? 0 : 1, 
SUBSCRIPTION_QUOTA             => $DADA::Config::SUBSCRIPTION_QUOTA, 
PROGRAM_IMG_FILENAME           => $DADA::Config::PROGRAM_IMG_FILENAME, 

GOOGLE_MAPS_API_PARAMS_api_key                => $DADA::Config::GOOGLE_MAPS_API_PARAMS->{api_key}, 
PII_OPTIONS_ip_address_logging_style          => $DADA::Config::PII_OPTIONS->{ip_address_logging_style}, 
PII_OPTIONS_allow_logging_emails_in_analytics => $DADA::Config::PII_OPTIONS->{allow_logging_emails_in_analytics}, 





# DEV: Cough! Kludge! Cough!
LEFT_BRACKET                  => '[',
RIGHT_BRACKET                 => ']',
LT_CHAR                       => '<', 
GT_CHAR                       => '>',    
TEST_UTF_VALUE                => "\x{a1}\x{2122}\x{a3}\x{a2}\x{221e}\x{a7}\x{b6}\x{2022}\x{aa}\x{ba}",        


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

                    
(
	
	($DADA::Config::SHOW_HELP_LINKS eq "1") ?
		(SHOW_HELP_LINKS  => 1,) : 
		(SHOW_HELP_LINKS  =>  0,),
),


); 

my %WYSIWYG_Vars = WYSIWG_Vars(); 
%Global_Template_Variables = (%Global_Template_Variables, %WYSIWYG_Vars); 

sub WYSIWG_Vars { 
	my %Vars = (
		CKEDITOR_URL  => undef, 
		TINY_MCE_URL  => undef, 
	); 
	# And test that I can get to the URL - our that at least it's a valid URL... 
	
	if($DADA::Config::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{enabled} == 1 
		&& defined($DADA::Config::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{url})
		&& isa_url($DADA::Config::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{url})
		){ 
		$Vars{CKEDITOR_URL} = $DADA::Config::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{url}; 
	}
	if($DADA::Config::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{enabled} == 1 
		&& defined($DADA::Config::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{url})
		&& isa_url($DADA::Config::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{url})
	){ 
		$Vars{TINY_MCE_URL} = $DADA::Config::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{url}; 
	}
	
#	use Data::Dumper; 
#	die Dumper({%Vars}); 
	return %Vars;
}


sub make_wysiwyg_vars { 
	
	my $list = shift; 
	my %WYSIWG_Vars = WYSIWG_Vars(); 
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list});
	my %vars = ();
	
	 
	if($ls->param('use_wysiwyg_editor') eq 'ckeditor' && defined($WYSIWG_Vars{CKEDITOR_URL})) { 
		$vars{using_ckeditor} = 1; 
	}
	elsif($ls->param('use_wysiwyg_editor') eq 'tiny_mce' && defined($WYSIWG_Vars{TINY_MCE_URL})) { 
		$vars{using_tiny_mce} = 1; 		
	}
	else { 
		$vars{using_no_wysiwyg_editor} = 1; 
	}
	
#	use Data::Dumper; 
#	die Dumper({%vars}); 
	return %vars; 

}
if($Global_Template_Variables{PROGRAM_URL} eq 'https://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'){ 

	$Global_Template_Variables{PROGRAM_URL} = $q->url; 
	# Well, what if we're running as the installer?
	if($Global_Template_Variables{PROGRAM_URL} =~ m/installer\/install\.cgi$/){ 
		$Global_Template_Variables{PROGRAM_URL} =~ s{installer\/install\.cgi}{mail.cgi};
	}
}
if($Global_Template_Variables{S_PROGRAM_URL} eq 'https://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'){ 
	$Global_Template_Variables{S_PROGRAM_URL} = $Global_Template_Variables{PROGRAM_URL}; 
}
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

my %_ht_tmpl_set_params = (); 
											
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


sub priority_popup_menu { 

	my $li       = shift; 
	my $default = shift || undef;
	
	
	if(! defined($default)){ 
		$default = $li->{priority};
	}
	require HTML::Menu::Select; 
    my $priority_popup_menu = HTML::Menu::Select::popup_menu(
							  		{ 
										name     => 'X-Priority',
										id       => 'X-Priority',
	                                    values   =>[keys %DADA::Config::PRIORITIES],
	                                    labels   => \%DADA::Config::PRIORITIES,
	                                    default  =>  $default, 
                              		}
							  	);
	return $priority_popup_menu; 
	
}




sub list_popup_menu { 

	
	require HTML::Menu::Select; 
	my $r = undef; 
	
	my %args = (
		-show_hidden         => 0,
		-name                => 'list',
		-empty_list_check    => 0, 
		-as_checkboxes       => 0, 
		-show_list_shortname => 0, 
		-selected_list       => undef, 
		-disable_invite_only => 0, 
	    @_
	); 
	my $labels     = {}; 
	my $attributes = {};
	 
	require DADA::MailingList::Settings; 
	
	my @lists = available_lists(-Dont_Die => 1); 

	 
	return undef if scalar @lists <= 0;
	
	my $l_count = 0; 
	
	# This needs its own method...
		foreach my $list( @lists ){
			my $ls = DADA::MailingList::Settings->new({-list => $list}); 
			next if 
				$args{-show_hidden} == 0 
				&& ($ls->param('hide_list') == 1 
				&& $ls->param('private_list') == 1); 
				
			if($args{-show_list_shortname} == 1){ 
				$labels->{$list} = $ls->param('list_name') . ' (' . $list . ')';
			}
			else { 
				$labels->{$list} = $ls->param('list_name');
			}

			if($args{-disable_invite_only} == 1){

				if($ls->param('invite_only_list') == 1){ 
										
					$labels->{$list} .= ' - by Invitation Only';
					$attributes->{$list}->{disabled} = "disabled";
				}
			
				if(	$args{-selected_list} eq $list 
					&& $ls->param('invite_only_list') != 1
				){ 
					$attributes->{$list}->{selected} = "selected";	
				}
			}
			else { 
				if(	$args{-selected_list} eq $list 
				){ 
					$attributes->{$list}->{selected} = "selected";	
				}
			}
			$l_count++;
		}
		my @opt_labels = sort { uc($labels->{$a}) cmp uc($labels->{$b}) } keys %$labels;
	#								#	
	
	if($l_count <= 0 && $args{-empty_list_check} == 1){ 
	
	    return undef; 
	}
	
	if($args{-as_checkboxes} == 1){ 
        $r =  $q->checkbox_group(
                                   -name      => $args{-name}, 
								   -id        => 'ddm_' . $args{-name}, 
                                  '-values'   => [@opt_labels],
                                   -labels    => $labels,
                                   -columns   => 2, 
								   -default  => [$args{-selected_list}],
                                 );				 	
	
	}
	else { 
		
		if(scalar @opt_labels == 0){ 
			return undef; 
		}
        $r = HTML::Menu::Select::popup_menu(
			 {
				name       => $args{-name}, 
				id         => 'ddm_' . $args{-name}, 
				values     => [@opt_labels],
				labels     => $labels,
#				default    => [],
				attributes => $attributes,
			}
		 ); 
    }
	
	
	return $r; 
	
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
	
	my ($args) = @_; 	
#        -show_hidden        => undef,
#        -name               => undef,
#        -email              => undef,
#        -error_invalid_list => 0,

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
            $subscriber_fields = $lh->subscriber_fields(
				{
					-show_hidden_fields => 0,
				}
			);
        }

        # /This is a weird placement...

        my $ls = DADA::MailingList::Settings->new( { -list => $l } );
        if($ls->param('hide_list') == 1 && $ls->param('private_list') == 1){ 
            next; 
        }
        else {
            $labels->{$l} = $ls->param('list_name');
            $l_count++;
        }
    }
    my @list_in_list_name_order =
      sort { uc( $labels->{$a} ) cmp uc( $labels->{$b} ) } keys %$labels;

    foreach my $list (@list_in_list_name_order) {
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $all_list_info        = $ls->get;
        my $all_list_info_dotted = $ls->get( -dotted => 1 );

		my $ah = undef; 
		if($ls->param('show_archives') == 1){   

	        $ah = DADA::MailingList::Archives->new(
	            {
	                -list => $list,
	                ( ($reusable_parser) ? ( -parser => $reusable_parser ) : () )
	            }
	        );
		}
		
        unless($ls->param('hide_list') == 1 && $ls->param('private_list') == 1){ 
            $l_count++;

            # This is strange...
            $all_list_info_dotted->{'list_settings.info'} =
              markdown_to_html({-str => $all_list_info_dotted->{'list_settings.info'} });
            $all_list_info_dotted->{'list_settings.info'} =
              _email_protect({-string => $all_list_info_dotted->{'list_settings.info'}} );

  			my $ne; 
  			my $subject; 
  			if($ls->param('show_archives') == 1){   
              	$ne      = $ah->newest_entry;
              	$subject = $ah->get_archive_subject($ne);
                  $subject = $ah->_parse_in_list_info( -data => $subject );

  			   # this is so atrocious.
  	            $all_list_info_dotted->{latest_archive_date} = date_this(
  	           -Packed_Date   => $ne,
  	           -Write_Month   => $ls->param('archive_show_month'),
  	           -Write_Day     => $ls->param('archive_show_day'),
  	           -Write_Year    => $ls->param('archive_show_year'),
  	           -Write_H_And_M => $ls->param('archive_show_hour_and_minute'),
  	           -Write_Second  => $ls->param('archive_show_second')
  	           );
			   
  				  $all_list_info_dotted->{latest_archive_id} = $ne;
  	            # These two things are sort of strange.
  	            $all_list_info_dotted->{latest_archive_blurb} =
  	              $ah->message_blurb();
  	            $all_list_info_dotted->{latest_archive_subject} = $subject;
  			}
		
		
            push ( @list_information, $all_list_info_dotted );
  			if($ls->param('show_archives') == 1){   
  				$reusable_parser = $ah->{parser} if !$reusable_parser;
  			}
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
        -email               => $args->{email},
        -list                => $args->{list},
		-disable_invite_only => 1, 
    );

	return wrap_screen(
        {
			-with   => 'list', 
            -screen => 'default_screen.tmpl',
            -vars   => {
				can_use_JSON       => scalar DADA::App::Guts::can_use_JSON(), 
                list_popup_menu    => $list_popup_menu,
                email              => $args->{ -email },
                list_information   => \@list_information,
                visible_lists      => $visible_lists,
                error_invalid_list => $args->{ -error_invalid_list },
                fields             => $named_subscriber_fields,
                #subscription_form  => scalar subscription_form(),
            },
        }
    );
}

sub list_page { 

	my %args = (-list           => undef, 
			    -email          => undef, 
				-error_no_email => undef, 
				-cgi_obj        => undef, 
				@_);
    
	require DADA::MailingList::Settings; 
	
	my $ls = DADA::MailingList::Settings->new({-list => $args{-list}}); 

    my $html_archive_list = html_archive_list($args{-list}); 
	
	require DADA::Profile; 
	my $prof = DADA::Profile->new(
		{
			-from_session => 1, 
		}
	); 
	my $allowed_to_view_archives = 1;
	if($prof) { 
		$allowed_to_view_archives = $prof->allowed_to_view_archives(
			{
				-list         => $args{-list},
			}
		);
	}
	
	
	# So, how does, "wrap_screen" embed variables? 
	# In other words, how do I show the list name in the title? That's important. 
	
    my $template = wrap_screen(
        {
        -with                     => 'list', 
        -screen                   => 'list_page_screen.tmpl',
        -list_settings_vars       => $ls->get,
        -list_settings_vars_param => {
			-dot_it => 1
			-list   => $args{-list}, # this is redundant, but important for email protection.
		 },

        -vars                     => 
        { 
			can_use_JSON              => scalar DADA::App::Guts::can_use_JSON(), 
            subscription_form         => subscription_form({-list => $args{-list}, -email => $args{-email}}), 
            error_no_email            => $args{-error_no_email}, 
            html_archive_list         => $html_archive_list, 
			allowed_to_view_archives  => $allowed_to_view_archives,  
        },
        
        -webify_and_santize_these => [qw(
			list_settings.discussion_pop_email
			list_settings.list_owner_email
			list_settings.info list_settings.privacy_policy
		)], 
        
        }
    ); 

    return $template; 

}




sub admin {
	my ($args) = @_; 
	
	if(! exists($args->{-vars}) ){ 
		$args->{-vars} = {};
	}
	
	if(! exists($args->{-vars}->{login_widget}) ){ 
		$args->{-vars}->{login_widget} = $DADA::Config::LOGIN_WIDGET;
	}
	
	if(
		check_if_list_exists( -List => $args->{-vars}->{selected_list}) >= 1
		&& _is_hidden($args->{-vars}->{selected_list})
	
	){ 
		$args->{-vars}->{login_widget} = 'text_box'; 
	}
	
    my @available_lists = available_lists();
	
    my $list_max_reached = 0;
	
	if(strip($DADA::Config::LIST_QUOTA) eq '') {
		$DADA::Config::LIST_QUOTA = undef;
    } 
	# Special: 
	if($DADA::Config::LIST_QUOTA == 0){ 
		$DADA::Config::LIST_QUOTA = undef;
	}
    if (   defined($DADA::Config::LIST_QUOTA)
        && ( 
			( $#available_lists + 1 ) >= $DADA::Config::LIST_QUOTA 
		) 
		
		) {
        $list_max_reached = 1;
    }

    my $list_popup_menu = list_popup_menu(
        -name                => 'admin_list',
        -show_hidden         => 0,
        -empty_list_check    => 1,
        -show_list_shortname => 1,
		-selected_list       => $args->{-vars}->{selected_list},
    );
	if(!defined($list_popup_menu)) {
		$args->{-vars}->{login_widget} = 'text_box';
	}

    my $auth_state;
	
    if ( $DADA::Config::DISABLE_OUTSIDE_LOGINS == 1 ) {
        require DADA::Security::SimpleAuthStringState;
        my $sast = DADA::Security::SimpleAuthStringState->new;
        $auth_state = $sast->make_state;
    }

	my $show_another_link = _show_other_link(); 
	
	my $logged_out = $args->{-cgi_obj}->param('logged_out') // 0; 
	
	my $show_2col_view = 0; 
	my $tmp_vars = $args->{-vars};
	if(	exists($tmp_vars->{errors})	){ 
		for my $err(@{$tmp_vars->{errors}}){ 
			if($err->{error} eq 'invalid_password'){ 
				$show_2col_view = 1;
			}
		}
	}
	
    return wrap_screen(
        {
            -screen         => 'admin_screen.tmpl',
            -with           => 'list',
            -wrapper_params => {
                -Use_Custom => 0,
            },
            -vars => {
				logged_out              => $logged_out, 
                list_popup_menu         => $list_popup_menu,
                list_max_reached        => $list_max_reached,
                auth_state              => $auth_state,
                show_other_link         => $show_another_link,
				%{$args->{-vars}},
            },
        }
    );
}


sub _is_hidden { 
    require DADA::MailingList::Settings; 
    my $list = shift; 
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        return 1
            if $ls->param('hide_list') == 1  && $ls->param('private_list') == 1; 		
    return 0; 
}
sub _show_other_link { 

    require DADA::MailingList::Settings; 
    
    
    # Basically, if there's at least one list that's hidden, we show the 
    # More... link. 
        
    foreach my $list(available_lists(-Dont_Die => 1) ){
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        return 1
            if $ls->param('hide_list') == 1  && $ls->param('private_list') == 1; 
	}
			
    return 0; 
    
}




sub show_login_list_textbox { 
	
	# This means, if all the lists are hidden, we have to show the 
	# text login box. Yup. 
	#
	
	require DADA::MailingList::Settings; 
    
    foreach my $list(available_lists(-Dont_Die => 1) ){
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        return 0
            if $ls->param('hide_list') == 1  && $ls->param('private_list') == 1; 
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

	
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	
	return '' 
		if $ls->param('show_archives') != 1;
	
	require DADA::Profile; 
	my $prof = DADA::Profile->new(
		{
			-from_session => 1, 
		}
	); 
	my $allowed_to_view_archives = 1;
	if($prof) { 
		$allowed_to_view_archives = $prof->allowed_to_view_archives(
			{
				-list         => $list, 
			}
		);
	}
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
	                        -vars                     => $ls->get, 
	                        -list_settings_vars       => $ls->get, 
	                        -list_settings_vars_param => {-dot_it => 1},                    
							-subscriber_vars_param    => {-use_fallback_vars => 1, -list => $ls->param('list')},

	                        }
	                    ); 
	                    # That. Sucked.
                
                
	                # this is so atrocious.
	                my $date = date_this(
	                -Packed_Date   => $entries->[$i],
	                -Write_Month   => $ls->param('archive_show_month'),
	                -Write_Day     => $ls->param('archive_show_day'),
	                -Write_Year    => $ls->param('archive_show_year'),
	                -Write_H_And_M => $ls->param('archive_show_hour_and_minute'),
	                -Write_Second  => $ls->param('archive_show_second')
	                );
					
					my $header_from      = undef;
	                my $orig_header_from = undef;

	                if ($raw_msg) {
	                    $header_from = $archive->get_header(
	                        -header => 'From',
	                        -key    => $entries->[$i]
	                    );
	                    $orig_header_from = $header_from;
	                }
	
					my $can_use_gravatar_url = 0;
	                my $gravatar_img_url     = '';

	                if ( $ls->param('enable_gravatars') ) {

	                    eval { require Gravatar::URL };
	                    if ( !$@ ) {
	                        $can_use_gravatar_url = 1;


                                my $header_address = $archive->sender_address(
                                 {
                                        -id => $entries->[$i],
                                    }
                            ); 
                            $gravatar_img_url = gravatar_img_url(
                                {
                                    -email                => $header_address,
                                    -default_gravatar_url => $ls->param('default_gravatar_url'),
                                }
                            );
	                    }
	                    else {
	                        $can_use_gravatar_url = 0;
	                    }
	                }
		                	
   # die $archive->message_blurb(-key => $entries->[$i]); 
	                my $entry = { 				
	                        id               => $entries->[$i], 
    
	                        date             => $date, 
	                        subject          => $subject,
	                       'format'          => $format, 
	                        list             => $list, 
	                        uri_escaped_list => uriescape($list),
	                        PROGRAM_URL      => $DADA::Config::PROGRAM_URL, 
		                    'list_settings.enable_gravatars' =>
		                      $ls->param('enable_gravatars'),
		                    can_use_gravatar_url => $can_use_gravatar_url,
		                    gravatar_img_url     => $gravatar_img_url,
	
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
	                if($ls->param('sort_archives_in_reverse') == 1);
    
	            # yeah, whatever. 
	            $th_entries->[$ii]->{bullet} = $bullet; 
            
	        }
    	


        $t .= screen({-screen => 'archive_list_widget.tmpl', 
                     -vars => {
                                entries              => $th_entries,
                                list                 => $list, 
                                list_name            => $ls->param('list_name'), 
                                publish_archives_rss => ($ls->param('publish_archives_rss')) ? 1: 0, 
                                index_nav            => $archive->create_index_nav($stopped_at), 
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
                                list_name            => $ls->param('list_name'), 
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

	my $location = $q->self_url || $DADA::Config::S_PROGRAM_URL . '?flavor=' . $args->{-f}; 
	   $location =~ s/^http//; 
	
    require  DADA::App::ScreenCache; 
    my $c  = DADA::App::ScreenCache->new; 
    
 #   if($c->is_cached('login_switch_widget.' . $args->{-list} . '.scrn')){ 
 #       my $lsw = $c->pass('login_switch_widget.' . $args->{-list} . '.scrn');
 #          $lsw =~ s/\[LOCATION\]/$location/g; 
 #          return $lsw; 
 #     }

    my $scrn; 
    my $lists = []; 
    
	foreach my $list(available_lists(-In_Order => 1)){
			my $ls = DADA::MailingList::Settings->new({-list => $list}); 
			my $logged_in = 0; 
			if($list eq $args->{-list}){ 
			   $logged_in = 1;  
			}
			push(
			    @$lists, 
			    {
			        'list_settings.list'      => $list, 
			        'list_settings.list_name' => $ls->param('list_name'), 
			        location                  => $location, 
			        logged_in                 => $logged_in, 
					S_PROGRAM_URL             => $DADA::Config::S_PROGRAM_URL, 
					PROGRAM_URL               => $DADA::Config::PROGRAM_URL, 
					
			    }
			); 
	}

	return DADA::Template::Widgets::screen(
				{
				    -screen => 'login_switch_widget.tmpl',
				    -vars   => { 
				        lists => $lists, 
				    },
				}
			); 
	
	
	
#	$c->cache('login_switch_widget.' . $args->{-list} . '.scrn', \$scrn);	
#	$scrn =~ s/\[LOCATION\]/$location/g; 
 # return $scrn; 

}

sub login_switch_popup_menu_widget { 

	my $args = shift; 
	
	croak "no list!" if ! $args->{-list};
	
	require DADA::MailingList::Settings; 

	my $location = $q->self_url || $DADA::Config::S_PROGRAM_URL . '?flavor=' . $args->{-f}; 

    require  DADA::App::ScreenCache; 
    my $c  = DADA::App::ScreenCache->new; 
    
    #if($c->is_cached('login_switch_widget.' . $args->{-list} . '.scrn')){ 
    #    my $lsw = $c->pass('login_switch_widget.' . $args->{-list} . '.scrn');
    #       $lsw =~ s/\[LOCATION\]/$location/g; 
    #       return $lsw; 
    #  }

    my $scrn; 
    

	my @lists = available_lists(-In_Order => 1); 
	my %label = (); 
	
	# DEV TODO - This needs its own METHOD!!!
	
	foreach my $list( @lists ){
			my $ls = DADA::MailingList::Settings->new({-list => $list}); 
			$label{$list} = $ls->param('list_name') . ' (' . $list . ')'; 
			
	}
	
	$label{$args->{-list}} = '----------'; 
	
	require HTML::Menu::Select;
	my $login_switch_popup_menu = HTML::Menu::Select::popup_menu(
		{
			name    => 'change_to_list', 
			id      => 'change_to_list', 
			value   => [@lists], 
			default => $args->{-list},
			labels  => {%label}, 
		}
	);
		
	my $num_lists = scalar @lists; 
	return DADA::Template::Widgets::screen(
		{
		    -screen => 'login_switch_popup_menu_widget.tmpl',
			-vars   => { 
				num_lists               => $num_lists, 
				login_switch_popup_menu => $login_switch_popup_menu, 
		        location                => $location, 
		    },
		}
	);
}




sub archive_send_form { 

	my ($list, $id, $errors, $captcha_archive_send_form, $captcha_fail) = @_; 

    my $CAPTCHA_string = '';
    # ?!?!
    $captcha_fail = defined $captcha_fail ? $captcha_fail : 0;

    my $can_use_captcha = can_use_Google_reCAPTCHA_v2(); 	
	$can_use_captcha = 0 
		if length($DADA::Config::RECAPTCHA_PARAMS->{v2}->{public_key}) <= 0;
	$can_use_captcha = 0 
		if length($DADA::Config::RECAPTCHA_PARAMS->{v2}->{private_key}) <= 0;
	
    if($captcha_archive_send_form == 1 && $can_use_captcha == 1){ 
            my $captcha_worked = 0; 
            my $captcha_auth   = 1; 

            require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA; 
            my $cap = DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA->new; 
               $CAPTCHA_string = $cap->get_html();  
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

	my ($args) = @_; 
	my $prof_sess_obj = undef; 
	
	if(defined($args->{-prof_sess_obj})){ 
		$prof_sess_obj = $args->{-prof_sess_obj};
	}
	
	
    my $scr              = '';
    my $prof_data        = {};
    my $is_logged_in     = 0;
    my $profiles_enabled = $DADA::Config::PROFILE_OPTIONS->{enabled};
    if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1)
    {
        $profiles_enabled = 0;
    }
    else {
		if(defined($prof_sess_obj)){ 
			if ( $prof_sess_obj->is_logged_in( { -cgi_obj => $q } ) ) {
                $is_logged_in = 1;
                $prof_data = $prof_sess_obj->get( { -cgi_obj => $q } );
			}
		}
		else {
	        require DADA::Profile;
	        my $dp = DADA::Profile->new( { -from_session => 1 } );
	        if ($dp) {
	            require DADA::Profile::Session;
	            require CGI;
	            my $prof_sess = DADA::Profile::Session->new;
	            if ( $prof_sess->is_logged_in( { -cgi_obj => $q } ) ) {
	                $is_logged_in = 1;
					$prof_data = $prof_sess->get( { -cgi_obj => $q } );
	            }
	        }
		}
    }

    return screen(
        {
            -screen => 'profile_widget.tmpl',
            -vars   => {
                profiles_enabled  => $profiles_enabled,
                is_logged_in      => $is_logged_in,
                'profile.email'   => $prof_data->{email},
                gravators_enabled => $DADA::Config::PROFILE_OPTIONS->{gravatar_options}->{enable_gravators},
                gravatar_img_url => gravatar_img_url(
                    {
                        -email                => $prof_data->{email},
                        -size => 45,
                    }
                ),

            }
        }
    );

}


sub amazon_ses_requirements_widget { 
	
	my $amazon_ses_required_modules = [ 
		{module => 'Cwd',             installed => 1}, 
		{module => 'Digest::SHA',     installed => 1}, 
		{module => 'URI::Escape',     installed => 1}, 
		{module => 'MIME::Base64',    installed => 1}, 	
		{module => 'Crypt::SSLeay',   installed => 1}, 	
		{module => 'XML::LibXML',     installed => 1},
		{module => 'LWP',             installed => 1}, 
		{module => 'AWS::Signature4', installed => 1},
#		{module => 'Some::Unknown::Module',       installed => 1}, 
	];


	my $amazon_ses_has_needed_cpan_modules = 1; 
	try {
		require Cwd;
	} catch { 
		$amazon_ses_required_modules->[0]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0;
	};
	try {
		require Digest::SHA;
	} catch { 
		$amazon_ses_required_modules->[1]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0;
	};
	try {
		require URI::Escape;
	} catch { 
		$amazon_ses_required_modules->[2]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0;
	};
	try {
		require MIME::Base64;
	} catch { 
		$amazon_ses_required_modules->[3]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0;
	};
	try {
		require Crypt::SSLeay;
	} catch { 
		$amazon_ses_required_modules->[4]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0;
	};
	try {
		require XML::LibXML;
	} catch { 
		$amazon_ses_required_modules->[5]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0; 
	};
	eval {require LWP;};
	if($@){
		$amazon_ses_required_modules->[6]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0; 
	}
	
	try {
		require AWS::Signature4;
	} catch { 
		$amazon_ses_required_modules->[7]->{installed}           = 0;
		$amazon_ses_has_needed_cpan_modules = 0;
	};
	
#	try {
#		require Some::Unknown::Module;
#	} catch { 
#		$amazon_ses_required_modules->[7]->{installed}           = 0;
#		$amazon_ses_has_needed_cpan_modules = 0; 
#	};
	
	
	
	return screen(
		{
			-screen => 'amazon_ses_requirements_widget.tmpl',
			-vars   => {
				amazon_ses_has_needed_cpan_modules  => $amazon_ses_has_needed_cpan_modules, 
				amazon_ses_required_modules         => $amazon_ses_required_modules, 
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

with just a parameter change. The default is to use HTML::Template. 
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

Via the C<-data> parameter: 

 my $scalar = 'This is my information!'; 
 print DADA::Template::Widgets::screen(
    {
        -data => \$scalar,
    }
 ); 

The information in B<-data> needs to be a reference to a scalar value. In B<H::T>, it maps to the C<scalarref> parameter. 

Via the C<-screen> parameter: 

 print DADA::Template::Widgets::screen(
    {
        -screen => 'somefile.tmpl',
    }
 );

which should be a filename to whatever template you'd like to use. 

In B<H::T>, it maps to the C<filename> parameter. 


Variables to be used in the template can be passed using the, C<-vars> parameter, which maps to the, 
B<H::T> parameter, C<param>. C<-vars> should hold a reference to a hash: 

 my $scalar = 'I wanted to say: <!-- tmpl_var var1 -->'; 
 print DADA::Template::Widgets::screen(
    {
        -data => \$scalar,
        -vars   => {var1 => "This!"}, 
    }
 );

This will print:

 I wanted to say: This!


And that's basically screen. Learn HTML::Template and memorize the mappings and you'll be right at home. 

A few things to mention: 

Many of the Dada Mail modules require you to pass a B<listshortname> some where - C<screen> doesn't,
and this is by design - it attempts to be separate from any Dada Mail backend or information inside. 

There are hooks in C<screen> to pass variables in the template from the settings and subscriber 
backend, but they're limited and absolutely optional, but are handy for shortcuts and hey, what isn't 
programming but shortcuts?

To tell C<screen> to use a specific subscriber information, you have two different methods. 

The first is to give the parameters to *which* subscriber to use, via the C<-subscriber_vars_param>: 

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
method and pass the parameters set in this hashref. It's best to make sure the subscriber I<exists>, 
or you may run into trouble.

The subscriber information will be passed to B<HTML::Template> via its C<param> method. The name of 
the parameters will be appended with, B<subscriber.>, so as not to clobber any other variables you're 
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

and this will loop over your Profile Fields. 

If you'd like, you can also pass the Profile Fields information yourself - this may be useful if
you're in some sort of recursive subroutine, or if you already have the information on hand. You may
do so by passing the, C<-subscriber_vars> parameter, I<instead> of the C<-subscriber_vars_param>
parameter, like so: 

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
 print DADA::Template::Widgets::screen(
 
           { 
                -subscriber_vars => $subscriber,
           }
       ); 

The, B<subscriber> variable will still be magically created for you. 

The B<-subscriber_vars> parameter is also a way to override what gets printed for the, B<subscriber.> 
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
 print DADA::Template::Widgets::screen(
 
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

=item * -subscriber _vars

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
    
    # This is for mispelings: 
	foreach('-list_settings_param', 'list_settings_param', 'list_settings_vars_params', '-list_settings_vars_params', 'list_settings_params', '-list_settings_params'){ 
		if(exists($args->{$_})){ 
			croak "Incorrect parameter passed to DADA::Template::Widgets:'$_'. Did you mean to pass, '-list_settings_vars_param'? $@";
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
                
                if( !exists($args->{-list_settings_vars_param}->{-i_know_what_im_doing}) ){                     
                    # this is to get really naughty bits out: 
                    foreach(qw(
                        password
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
        
        my ($subscriber_vars, $subscriber_loop_vars) = subscriber_vars($args); 
        $args->{-subscriber_vars}    = $subscriber_vars; 
        $args->{-vars}->{subscriber} = $subscriber_loop_vars;  
        
    } # exists($args->{-subscriber_vars}) || exists($args->{-subscriber_vars_param})
    else { 
        $args->{-subscriber_vars}       = {};
        $args->{-subscriber_vars_param} = {};
    }
    
    
	###

	if($DADA::Config::PROFILE_OPTIONS->{enabled} == 1){ 
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

	if(exists($args->{-time})){ 
		$TMP_TIME = $args->{-time};
	}


    
     my $template_vars = {}; 
        %$template_vars = (%{$args->{-list_settings_vars}}, %{$args->{-subscriber_vars}}, %{$args->{-profile_vars}}, %{$args->{-vars}}); 

	
			
		
    if(exists($args->{-webify_and_santize_these})){ 
		if(exists($args->{-list_settings_vars_param}->{-list})) { 
			$template_vars = webify_and_santize(
	            {
	                -to_sanitize => $args->{-webify_and_santize_these},
	                -vars        => $template_vars,
					-list        => $args->{-list_settings_vars_param}->{-list},

	            }
	        );
		}
		else { 
			$template_vars = webify_and_santize(
	            {
	                -to_sanitize => $args->{-webify_and_santize_these},
	                -vars        => $template_vars,

	            }
	        );			
		}
		

    }



		
	if(exists($args->{-webify_these})){ 
		foreach(@{$args->{-webify_these}}){ 
	    	$template_vars->{$_} = markdown_to_html(
				{
					-str    => $template_vars->{$_},
					-method => 'fast', 
				}
			);
	    }
	}


	# Which templating engine to use? 
	#
	my $template; 	
	my $filters = []; 

 	if(exists($args->{-screen})){
		
		push(@$filters, 
				{ 
					sub    => \&decode_str,
					format => 'scalar' 
				}
		); 
	}
	push(@$filters, 
	    { 
			sub => \&hack_in_tmpl_set_support,
			format => 'scalar' 
		},
	);
	push(@$filters, 
	    { 
			sub => \&filter_time_piece,
			format => 'scalar' 
		},
	);
	 
	# This is very strange - but filters break images (binary stuff) 
	if(exists($args->{-img})){ 
		if($args->{-img} == 1){ 
			$filters = [];
		}
	}
	
	require HTML::Template::MyExpr;
	
	if(exists($args->{-screen})){ 
		$template = HTML::Template::MyExpr->new(
			%Global_Template_Options, 
			filename => $args->{-screen},
			filter   => $filters, 
		);
	}elsif(exists($args->{-data})){ 
		
		if($args->{-decode_before} == 1){ 
			${$args->{-data}} = safely_decode(${$args->{-data}}, 1); 
		}
		$template = HTML::Template::MyExpr->new(
			%Global_Template_Options, 
			scalarref => $args->{-data},
			filter    => $filters, 
		);
	}else{ 
		croak "you MUST pass either a scarlarref in, '-data' or a filename in, '-screen'!"; 
	}


	my %date_params = date_params(); 
	my %profile_settings_vars = profile_settings_vars();
	my %final_params = (
		%Global_Template_Variables,		
		%profile_settings_vars,			
		%date_params,
		%$template_vars,
		%_ht_tmpl_set_params,
	);
	if(exists($args->{-list})){ 
		$final_params{list} =  $args->{-list};  
	}
	
   $template->param(%final_params); 
	%_ht_tmpl_set_params = (); 
	if(exists($args->{-return_params})){ 
		if($args->{-return_params} == 1){ 		
			return ($template->output(), {%final_params});	
		}
		else { 					 
			return $template->output();
		}
	}
	else { 
		return $template->output();
	}
}



sub subscriber_vars {
    
    my ($args) = @_;
     
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

    			# What happens if we pass an email address that's not valid? 
    			eval { 
                    $args->{-subscriber_vars} = $lh->get_subscriber(
                                                    {
                                                        -email  => $args->{-subscriber_vars_param}->{-email}, 
                                                        -type   => $args->{-subscriber_vars_param}->{-type},
                                                        -dotted => 1, 
                                                    }
                                                ); 
    			};
    			if($@){ 
    				$args->{-subscriber_vars} = {};
    				carp $@; 
    			}
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

    						my $field_attrs = $lh->get_all_field_attributes; 
    						my $fallback_vars = {}; 
    						foreach(keys %$field_attrs){ 
    							$fallback_vars->{'subscriber.' . $_} = $field_attrs->{$_}->{fallback_value};
    						}
    				# This is sort of an odd placement for this, but I'm not sure 
    				# Where I want this yet...  (perhaps $lh->get_fallback_values ?)

    					if(!exists($args->{-subscriber_vars}->{'subscriber.email'})){ 
    						$fallback_vars->{'subscriber.email'} = 'example@example.com'; 
    					}
    					my ($name, $domain) = split('@', $fallback_vars->{'subscriber.email'}, 2); 
    					$fallback_vars->{'subscriber.email_name'}   = $name; 
    					$fallback_vars->{'subscriber.email_domain'} = $domain; 
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
    			# DEV: This is a really really REALLY good place to put an optimization - 
    			# No caching is currently done, either by this module, or another. 
    			# That's no good! 
    			# At the very least, we could put caching in 
    			# DADA::ProfileFieldsManager and just keep that around... 
    			# Ugh. 
    			# 
    			# Updated: At least in the mass mailing stuff, -use_fallback_vars param is not called, 
    			# The fallback field stuff is done with a cached copy of DADA::ProfileFieldsManager
    			# That's a good thing.

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

    return ($args->{-subscriber_vars}, $args->{-vars}->{subscriber}); 

}

sub date_params { 
	
	my $time = shift || $TMP_TIME || time;
	
	my %params = ();
	 
	
	# Anything more than this, and I should probably use 
	# DateTime or something. 
	# Don't want to for performance reasons
	# OR, use Time::Piece and probably remove some bugs I've created. 
	#
	# 0 1 2 3 4 5 6 7 8
	# $mday = '17'; (Date)
	# $wday = '1' (Monday)
	# $yday =  289the day of the year (ie: in 365 days, this is the nth day")
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    	localtime($time);	

    my $months = [
	qw(
        January  
        February 
        March    
        April    
        May      
        June     
        July     
        August   
        September
        October  
        November 
        December 
	)
    ];           


    my $abbr_months = [
	qw(
        Jan
        Feb
        Mar    
        Apr    
        May      
        Jun     
        Jul     
        Aug   
        Sep
        Oct 
        Nov
        Dec 
	)
    ];

	
	my $days = [
	qw( 
		Sunday   
		Monday   
		Tuesday  
		Wednesday
		Thursday 
		Friday   
		Saturday    
	)
	];

	my $abbr_days = [
	qw( 
		Sun
		Mon   
		Tue  
		Wed
		Thu 
		Fri   
		Sat    
	)
	];
	
	
	my $mail_day_values = {
		1  => '1st', 
		2  => '2nd', 
		3  => '3rd', 
		4  => '4th', 
		5  => '5th',
		6  => '6th', 
		7  => '7th', 
		8  => '8th', 
		9  => '9th', 
		10 => '10th', 
		11 => '11th',
		12 => '12th', 
		13 => '13th', 
		14 => '14th', 
		15 => '15th', 
		16 => '16th', 
		17 => '17th', 
		18 => '18th', 
		19 => '19th', 
		20 => '20th', 
		21 => '21st', 
		22 => '22nd', 
		23 => '23rd', 
		24 => '24th', 
		25 => '25th', 
		26 => '26th', 
		27 => '27th', 
		28 => '28th', 
		29 => '29th', 
		30 => '30th', 
		31 => '31st',
	};
	
    $params{'date.time'}                 = $time;
    $params{'date.localtime'}            = scalar( localtime($time) );
    $params{'date'}                      = $params{'date.localtime'};
    $params{'date.month'}                = $mon + 1;
    $params{'date.named_month'}          = $months->[$mon];
    $params{'date.padded_month'}         = sprintf( "%02d", $mon + 1 );
    $params{'date.abbr_named_month'}     = $abbr_months->[$mon];
    $params{'date.day'}                  = $mday;
    $params{'date.day_of_the_week'}      = $days->[$wday];
    $params{'date.padded_day'}           = sprintf( "%02d", $mday );
    $params{'date.abbr_day_of_the_week'} = $abbr_days->[$wday];
    $params{'date.nth_day'}              = $mail_day_values->{$mday};
    $params{'date.year'}                 = $year += 1900;
    $params{'date.abbr_year'}            = sprintf( "%02d", $year % 100 );
	$params{'date.24_time'}              = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
	$params{'date.timezone'}             = strftime("%Z", localtime()); 
	
	return %params;
	
}


sub profile_settings_vars { 
	
	my %vars = (
		'profile_settings.enabled' => $DADA::Config::PROFILE_OPTIONS->{enabled},
		
		# backwards compat.: 
		PROFILE_ENABLED            => $DADA::Config::PROFILE_OPTIONS->{enabled},
		# are we really going to use these?
		#'profile.email'                            => $DADA::Config::PROFILE_OPTIONS->{profile_email},
		#'profile.enable_captcha'                   => $DADA::Config::PROFILE_OPTIONS->{enable_captcha},
		
		
	); 
	for(qw(
		 register                  
		 password_reset            
		 profile_fields            
		 mailing_list_subscriptions
		 protected_directories     
		 update_email_address      
		 change_password           
		 delete_profile            
	)){ 
		if(exists($DADA::Config::PROFILE_OPTIONS->{features}->{$_})){ 
			$vars{'profile_settings.' . $_} = $DADA::Config::PROFILE_OPTIONS->{features}->{$_}; 
		}
	}
	
	return %vars;
}


=pod

=head2 wrap_screen

	my $scrn = wrap_screen(
		{ 
			-with => 'list', # or, 'admin', 
			-screen => 'some_screen.tmpl', # or, "-data => \$some_data, 
			# ... other options
		}
	); 

C<wrap_screen> allows you to wrap either one of the two templates (currently) 
that Dada Mail uses to wrap other template in: C<list_template.tmpl> and
C<admin_template.tmpl>. 

It takes the same options as, C<screen> and adds a few of its own: 

C<-with> is required and should be set to either, C<list>, or C<admin>, depending on 
whether you want to wrap the template in either the list or admin template. 

C<-wrapper_params> can also be passed and the value of its parameters (confusingly)
will be different, depending on if you're using C<list> or, C<admin> for, C<-with>

For, C<list>:

=over

=item * any parameter you would usually send to DADA::Template::HTML::list_template()

Example: 

	my $scrn = DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'preview_template.tmpl',
			-with   => 'list', 
			-wrapper_params => { 
				-data => \$template_info, # This is the actual template we'll be using! 
			},
		}
	);

=back

For, C<admin> 

=over

=item * any parameter you would usually send to, DADA::Template::HTML::admin_template

	my $scrn .= DADA::Template::Widgets::wrap_screen(
		{
			-screen => 'sending_monitor_index_screen.tmpl',
            -with   => 'admin', 
			-wrapper_params => { 
				-Root_Login => 1,
				-List       => 'my_list',  
			},
			# ... 
		}
	);

=back

=cut 


sub wrap_screen { 
		
	my ($args) = @_; 

	if(!exists($args->{-with})){ 
		croak "you must pass the, '-with' parameter"; 
	}
	else { 
		if($args->{-with} !~ m/^(list|admin)$/){ 
			croak "'-with' parameter must be either, 'list' or, 'admin'";
		}
	}
	my $with = $args->{-with}; 
	# I'd rather not have this passed to, screen(); 
	delete $args->{-with}; 
	
	# I need params from the first template passed. 
	$args->{-return_params} = 1;
	my ($tmpl, $params) = screen($args);

	# "content" is passed to the wrapper template
	my $vars = { 
		content => $tmpl, 
	};
	for(qw(title show_profile_widget load_wysiwyg_editor load_google_viz load_colorbox load_captcha_js load_jquery_validate load_datetimepicker SUPPORT_FILES_URL)){ 
		if(exists($params->{$_})){ 
			# variables within variables... 
			$vars->{$_} = $params->{$_}; 
			if($vars->{$_} =~ m/\<\!\-- tmpl_/){
				$vars->{$_} = screen({-data => \$vars->{$_}, -vars => $params}); 
			}
		}
	}	 
	
	if($with eq 'list'){ 
	
		# list_template is the wrapper template - it calls, screen()
		# This will aggravate you, as I'm aggravated by it - there's 3 ways to send the listshortname to screen()
		# And list_template() here has one way, so we have to figure out where, "list" is, and use it. 
		# Here we go: 
		my $list_param = undef; 
		if(exists($args->{-list})){ 
			$list_param =  $args->{-list}; 
		}
		elsif(exists($args->{-list_settings_vars})){
			if(exists($args->{-list_settings_vars}->{list})){ 
				$list_param =  $args->{-list_settings_vars}->{list}; 
			}
			elsif(exists($args->{-list_settings_vars}->{'list_settings.list'})){ 
				$list_param =  $args->{-list_settings_vars}->{'list_settings.list'}; 
			}	
		}
		elsif(exists($args->{-list_settings_vars_param}->{-list})){
			$list_param = $args->{-list_settings_vars_param}->{-list}; 
		}
		
		require DADA::Template::HTML; 	
		my $template = DADA::Template::HTML::list_template(
			%{$args->{-wrapper_params}}, # This is currently, "blank" - where is put in here - header_params? 
			-vars => $vars,				 
			-Part => 'full', 
			-List => $list_param, 
			); 			
		return $template; 
	}
	elsif($with eq 'admin'){ 
		my %wysiwyg_vars = ();
		if(exists($args->{-wrapper_params}->{-List})){ 
			%wysiwyg_vars = DADA::Template::Widgets::make_wysiwyg_vars($args->{-wrapper_params}->{-List});  
			$vars = {(%$vars, %wysiwyg_vars)};
		}
		require DADA::Template::HTML; 	
		my $template = DADA::Template::HTML::admin_template(
			%{$args->{-wrapper_params}}, 
			-vars => $vars,				 						 
			-Part => 'full', 
			); 
		return $template;
	}
	else { 
		# I think it may be impossible to get here. 
		die "only 'list' and 'admin' wrapping is currently supported."; 
	}
}

sub validate_screen { 
	my ($args) = @_; 
	
	# use Data::Dumper; 
	# carp '$args' . Dumper($args); 
	
	my $r      = 1; 
	my $errors = undef; 
	my $scrn   = undef; 
	try { 
		$scrn = screen({%$args}); 
	} catch {
		# warn 'validate_screen FAILED!';
		# warn $_; 
		$r      = 0; 
		$errors = $_; 
	};
	# warn 'validate_screen PASSED!';
	return ($r, $errors); 
}

sub decode_str { 
	my $ref = shift;
 	   ${$ref} = safely_decode(${$ref}); 
}

sub not_defined { 
    my $ref = shift;
#    use Data::Dumper; 
#    warn Dumper($ref); 
    
    if(ref($ref) eq 'ARRAY'){
        return 1 if defined($ref->[0]); 
    }
    else { 
        return 1 if ! defined($ref); 
    }
    return 0;
}
sub hack_in_tmpl_set_support {
    my $text_ref = shift;

    my $match = qr/\<\!\-\- tmpl_set name\=\"(.*?)\" value\=\"(.*?)\" \-\-\>/;
					#	<!-- set name="one" value="two" -->
    my @taglist = $$text_ref =~ m/$match/gi;
    while (@taglist) {
        my ( $t, $v ) = ( shift @taglist, shift @taglist );		
		$_ht_tmpl_set_params{$t} = $v;
    }

    $$text_ref =~ s/$match//gi;
}

sub filter_time_piece {
	
    my $text_ref = shift;
	my $time     = $TMP_TIME || time; 
	
    my $match = qr/\<\!\-\- tmpl_strftime (.*?) \-\-\>/;
    
	my @taglist = (); 
	@taglist = $$text_ref =~ m/$match/gi;
    
	my $can_use_time_piece = 1;
	my $can_use_posix      = 1; ; 
	my $t                  = undef; 
	if(exists($taglist[0])){  
		
		try { 
			require Time::Piece; 
			#$t = Time::Piece->new;
		     $t = Time::Piece::localtime($time);
		} catch {
			$can_use_time_piece = 0; 
			carp "Time::Piece doesn't work!? $_"; 
		};
		
		if($can_use_time_piece == 0){ 
			# I mean, who knows. 
			try { 
				require POSIX; 
				POSIX::->import( 'strftime' );
			} catch {
				$can_use_posix = 0; 
			};
		}
		if($can_use_time_piece == 0 && $can_use_posix == 0){ 
			croak '<!-- tmpl_var tmpl_strftime [...] --> tags unsupported! Install Time::Piece!'; 
		}
		
		while (@taglist) {
			 # I have no understanding of this, rather than, my $format(@taglist) { } 
			my $format = shift @taglist;
			
			my $formatted_time = undef; 
			
			if($can_use_time_piece) { 
				$formatted_time = $t->strftime($format);
			}
			else { 
				my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
				$formatted_time = POSIX::strftime($format, $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst );
			}
			my $formatted_match = quotemeta("<!-- tmpl_strftime $format -->");
			$$text_ref =~ s/$formatted_match/$formatted_time/gi;
	    }

	}
   
}


sub webify_and_santize { 

    my ($args) = @_; 
    
    if(!exists($args->{-vars})){ 
        die "need to pass, -vars"; 
    }
    
    if(!exists($args->{-to_sanitize})){ 
        die "need to pass, -to_sanitize"; 
    }
    
	if(! exists($args->{-list})){ 
		$args->{-list} = undef; 
	}
    foreach(@{$args->{-to_sanitize}}){ 
    
        
		
		# Markdown seems to wrap all strings in <p> tags
		if(
			   $_ eq 'list_settings.discussion_pop_email'
			|| $_ eq 'discussion_pop_email'
			|| $_ eq 'list_settings.list_owner_email'			
			|| $_ eq 'list_settings.list_owner_email'			
			|| $_ eq 'list_owner_email'			
			|| $_ eq 'list_settings.admin_email'			
			|| $_ eq 'admin_email'			
		){
			plaintext_to_html({-str => $args->{-vars}->{$_}});
		}
		else { 
	        $args->{-vars}->{$_} = markdown_to_html({-str =>$args->{-vars}->{$_}});
		}
		
        $args->{-vars}->{$_} = _email_protect(
			{
				-string => $args->{-vars}->{$_},
				-list   => $args->{-list}, #?
			}
		);
		
          
        
    }
    
    return $args->{-vars};
    
}




sub _email_protect { 
    
	my ($args) = @_; 
    my $str  = $args->{-string};
 	my $list = undef; 
	my $ls   = undef; 
    if(exists($args->{-list}) && $args->{-list} ne undef){ 
		$list = $args->{-list};
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $list});
	}
    

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
		if($list){ 			
			if($ls->param('archive_protect_email') eq 'spam_me_not'){ 		
	            my $pe = spam_me_not_encode($fa);
	            my $le = quotemeta($fa); 
	            $str =~ s/$le/$pe/g;   
	        }
		}
		else { 
			 my $pe = spam_me_not_encode($fa);
	         my $le = quotemeta($fa); 
	         $str =~ s/$le/$pe/g;
		}
	}

    return $str; 
 }




sub subscription_form { 

   
    my ($args) = @_; 
	
    my $list = undef; 
	if(exists($args->{-list})){ 
		$list = $args->{-list};
	}
    
    if(! exists($args->{-form_type})){ 
		$args->{-form_type} = 'full';
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
	
	if(! exists($args->{-magic_form})){
    	$args->{-magic_form} = 1; 
	}

	if(! exists($args->{-show_fieldset})) { 
		$args->{-show_fieldset} = 1;
	}
	
	if(! exists($args->{-subscription_form_id})) { 
		$args->{-subscription_form_id} = undef;
	}
	
	if(! exists($args->{-add_recaptcha_js})) { 
		$args->{-add_recaptcha_js} = 0;
	}
	
	if(! exists($args->{-form_target})) { 
		$args->{-form_target} = '_self';
	}	

    my @available_lists = available_lists(-Dont_Die => 1); 
    if(! $available_lists[0]){ 
        return ''; 
    }
    
    
    require DADA::ProfileFieldsManager; 
    my $pfm               = DADA::ProfileFieldsManager->new; 
	my $subscriber_fields = $pfm->fields(
		{
			-show_hidden_fields => 0,
		}
	);
		
	my $field_attrs       = $pfm->get_all_field_attributes;
	
	my $named_subscriber_fields = [];

	foreach(@$subscriber_fields){ 
	    push(
			@$named_subscriber_fields, 
				{
					name        => $_, 
					pretty_name => $field_attrs->{$_}->{label},
					label       => $field_attrs->{$_}->{label},
					required    => $field_attrs->{$_}->{required},
				}
			)
	}
	
	if(! exists ($args->{-ignore_cgi}) && $args->{-ignore_cgi} != 1){ 
           foreach(qw(email list )){ 
            if(! exists ( $args->{'-' . $_} ) && defined($q->param($_))){ 
                $args->{'-' . $_} = xss_filter($q->param($_));
            }
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

		if (   $DADA::Config::PROFILE_OPTIONS->{enabled} != 1)
	    {
			# ... 
		}		
    }

    if(
		$list && 
		check_if_list_exists( -List=> $list, -Dont_Die  => 1) > 0
	){ 
	
		require DADA::MailingList::Settings; 
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
  
		# This is so that we don't show the entire form, if we don't have to:
		if(
			(
				$ls->param('invite_only_list') == 1
			&&  $ls->param('closed_list') == 1
			) 
		){ 
			if($ls->param('invites_show_profile_fields_in_subscription_form') == 1){ 
				$args->{-show_fields} = 1;
			}
			else { 
				$args->{-show_fields} = 0;
			} 
		}
		
		my $tmpl_name = 'subscription_form_widget.tmpl'; 
		if($args->{-form_type} eq 'minimal'){ 
 			$tmpl_name = 'minimal_subscription_form.tmpl'; 
		}
		elsif($args->{-form_type} eq 'form_fields_example'){ 
 			$tmpl_name = 'subscription_form_fields_example.tmpl'; 
		}
		
		require DADA::MailingList::Consents; 
		my $con           = DADA::MailingList::Consents->new; 
		my $list_consents = $con->give_me_all_consents($ls); 
				
        return screen({
            -screen => $tmpl_name, 
            -vars   => {
							form_target              => $args->{-form_target},  
							can_use_JSON             => scalar DADA::App::Guts::can_use_JSON(), 
                            single_list              => 1, 
                            subscriber_fields        => $named_subscriber_fields,
                            list                     => $list, 
                            email                    => $args->{-email},
                            script_url               => $args->{-script_url}, 
							show_fields              => $args->{-show_fields}, 
							profile_logged_in        => $args->{-profile_logged_in}, 
							subscription_form_id     => $args->{-subscription_form_id}, 
							show_fieldset            => $args->{-show_fieldset}, 
							add_recaptcha_js         => $args->{-add_recaptcha_js}, 
							list_consents            => $list_consents, 					
							
                        },
						-list_settings_vars_param => {
							-list    => $list,
							-dot_it => 1,
						},
                    });  
  
    }
    else { 
		
		my $enable_captcha_on_initial_subscribe_form = 0; 
		
		# Eek, this is a hack, kinda: 
		if($args->{-multiple_lists} == 1){ 
			require DADA::MailingList::Settings; 
			my @lists = available_lists(-Dont_Die => 1); 
			foreach my $mlist(@lists){ 
				my $mls = DADA::MailingList::Settings->new({-list => $mlist}); 
				if($mls->param('enable_captcha_on_initial_subscribe_form') == 1){
					 $enable_captcha_on_initial_subscribe_form = 1; 
				}
				last; 
			}
		}
		
		return screen({
            -screen => 'subscription_form_widget.tmpl', 
            -vars   => {
				form_target              => $args->{-form_target},  
	            single_list              => 0, 
	            subscriber_fields        => $named_subscriber_fields,
	            list                     => $list, 
	            email                    => $args->{-email},
	            list_popup_menu          => list_popup_menu(-disable_invite_only => 1),
	            list_checkbox_menu       => list_popup_menu(-as_checkboxes => 1), 
	            multiple_lists           => $args->{-multiple_lists}, 
	            script_url               => $args->{-script_url}, 
				show_fields              => $args->{-show_fields}, 
				profile_logged_in        => $args->{-profile_logged_in}, 
				subscription_form_id     => $args->{-subscription_form_id}, 
				show_fieldset            => $args->{-show_fieldset}, 
				add_recaptcha_js         => $args->{-add_recaptcha_js}, 
				'list_settings.enable_captcha_on_initial_subscribe_form' 
					=> $enable_captcha_on_initial_subscribe_form, 
			}
    	});      
    }

}



sub unsubscription_form { 
	
	
    my ($args) = @_; 
    
	if(! exists($args->{-list})) { 
		croak "you MUST pass a, '-list'"; 
	}
	my $list_exists = check_if_list_exists( -List=> $args->{-list}, -Dont_Die  => 1) || 0;
	
	if($list_exists == 0){ 
		croak "list,  '" .  $args->{-list} . "' does not exist."; 

	}
	else { 
	
		return screen({
	        -screen => 'unsubscription_form_widget.tmpl', 
	        -vars   => {
                       
	                        list                     => $args->{-list}, 
	                        email                    => $args->{-email},
	                    },
						-list_settings_vars_param => {
							-list    => $args->{-list},
							-dot_it => 1,
						},
					
	                }
		);  
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
		if($args->{-encoding} == 0) {  
			return _slurp_raw($path);
		}
		else { 
			return _slurp($path);
			
		}
	}
	else { 
		carp "cannot find, $screen to open!"; 
		return undef; 
	}
}



sub _slurp { 
	
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

		$file = make_safer($file); 
        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET .')', $file) || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}

sub _slurp_raw { 
	my ($file) = @_;

    local($/) = wantarray ? $/ : undef;
    local(*F);
    my $r;
    my (@r);

	$file = make_safer($file); 
    open(F, '<', $file) || die "open $file: $!";
    @r = <F>;
    close(F) || die "close $file: $!";

    return $r[0] unless wantarray;
    return @r;
}



# This is a bad idea - better to just OO this module... 
sub lame_init(){ 
    if(!defined($q)){ 
        require CGI;
        $q = CGI->new();
    }
}


1;




=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2020 Justin Simoni 
https://justinsimoni.com 
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
