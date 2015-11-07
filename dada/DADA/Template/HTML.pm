package DADA::Template::HTML;

use lib qw(../../../ ../../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 
use Try::Tiny; 

use Carp qw(croak carp); 


BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}


my $q; 
lame_init(); 

#
# oh that does not look good: 
my $Yeah_Root_Login = 0; 

use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT 
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB
); 

require Exporter; 
our @ISA = qw(Exporter); 


@EXPORT = qw(
	
admin_template
admin_template_header
admin_template_footer

default_template
check_if_template_exists 
available_templates
open_template
list_template
admin_header_params
HTML_Footer

);


use strict; 
use vars qw(@EXPORT); 
=pod

=head1 NAME

DADA::Template::HTML

=head1 SYNOPSIS

Module for generating HTML templates for lists and administration

=head2 DESCRIPTION

 use DADA::Template::HTML;
 
 
 #print out a admin header template: 
 print admin_template_header(-Title => "hola! I am a list header", 
 						   -List => $list,
 						 );  
 						 
 
 # now, print the admin footer template: 
 print admin_template_footer(-List => $list); 
 
 
 # give me the default Dada Mail list template
 my $default_template = default_template($DADA::Config::PROGRAM_URL); 
 				
 				
 					
 # do I have a template? 
 
 	my $template_exists = check_if_template_exists(-List => $list); 						
    print "my template exists!!" if $template_exists >= 1; 
   
   
 # what lists do have templates? 
 my @list_templates = available_templates(); 
 
 
 # open up my template
 my $list_template = open_template(-List => $list); 
 
 # print a list template header
 print list_template(-List      => $list, 	
 				-Part      => 'header', 
 			); 
 			
 			
 # print the list template footer			
  print list_template(-List      => $list, 	
 				-Part      => 'footer', 
 				-Site_Name =>  "justin's site", 
 				-Site_URL  =>  "http://skazat.com", 
 			); 
 

 # the 'send this archived message to a friend" link maker
 # print archive_send_link($list, $message_id); 

=cut


sub admin_template_header { 

	my %args = @_; 
	   $args{-Part} = 'header'; 	
	return admin_template(%args)
	
}

sub admin_template_footer { 
	my %args = @_; 
	   $args{-Part} = 'footer';
	return admin_template(%args)
	
}


sub admin_template { 
 
	require DADA::Template::Widgets; 
	require DADA::Template::Widgets::Admin_Menu;
	require CGI; 
	# DEV: Weird. I know. 
	if($DADA::Config::PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'){ 
		$DADA::Config::PROGRAM_URL = $ENV{SCRIPT_URI} || $q->url();
	}
	
	# DEV: ?!?!

	my $f = $q->param('f') || undef;
	if (! defined(scalar $q->param('flavor'))) { 
	    $q->param('flavor', $f);
	}
	
	my %args = (
				-Title        => "", 
				-List         => "",
				-Root_Login   => 0,
				-HTML_Header  => 0,
				-Part         => undef, 
				-vars         => {},
				@_,
				); 

	my $list = $args{-List};


	# DEV: This is horrible.
	
	if($args{-Root_Login} == 1){ 
		$Yeah_Root_Login = 1
	}
		
	### Admin Menu Creation...
    my $admin_menu; 
    my $m_admin_menu; 
	my $tb_admin_menu;
	my $li; 
	    require  DADA::MailingList::Settings; 
	    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	
	if($Yeah_Root_Login == 1){ 
		$admin_menu    = DADA::Template::Widgets::Admin_Menu::make_admin_menu(
			{
				-privileges => 'superuser',   
				-ls_obj     => $ls,
				-flavor      => scalar $q->param('flavor'), 
				-for_mobile  => 0,		
				-style       => 'side_bar',
			}
		); 
		$m_admin_menu = DADA::Template::Widgets::Admin_Menu::make_admin_menu(
			{
				-privileges  => 'superuser',   
				-ls_obj      => $ls,
				-flavor      => scalar $q->param('flavor'), 
				-for_mobile  => 1, 
				-style       => 'side_bar',
			}
		); 
		$tb_admin_menu    = DADA::Template::Widgets::Admin_Menu::make_admin_menu(
			{
				-privileges => 'superuser',   
				-ls_obj     => $ls,
				-flavor      => scalar $q->param('flavor'), 
				-for_mobile  => 0,		
				-style       => 'top_bar',
			}
		); 
		
		
	}else{
		$admin_menu  = DADA::Template::Widgets::Admin_Menu::make_admin_menu(
			{
				-privileges  => 'user',   
				-ls_obj      => $ls,
				-flavor      => $q->param('flavor'), 
				-for_mobile  => 0, 
				-style       => 'side_bar',
				
			}
		); 
		$m_admin_menu  = DADA::Template::Widgets::Admin_Menu::make_admin_menu(
			{
				-privileges  => 'user',   
				-ls_obj      => $ls,
				-flavor      => scalar $q->param('flavor'), 
				-for_mobile  => 1, 
				-style       => 'side_bar',
				
			}
		); 
		
		$tb_admin_menu    = DADA::Template::Widgets::Admin_Menu::make_admin_menu(
			{
				-privileges => 'user',   
				-ls_obj     => $ls,
				-flavor      => scalar $q->param('flavor'), 
				-for_mobile  => 0,		
				-style       => 'top_bar',
			}
		); 
		
		
	}
	
	$admin_menu = DADA::Template::Widgets::screen(
					{
						-data => \$admin_menu, 
						-list_settings_vars_param => { 
													-list   => $list, 
													-dot_it => 1, 
											 	},
					   -vars => {}
					}
				); 
	$m_admin_menu = DADA::Template::Widgets::screen(
					{
						-data => \$m_admin_menu, 
						-list_settings_vars_param => { 
													-list   => $list, 
													-dot_it => 1, 
											 	},
					   -vars => {}
					}
				); 
				
	$tb_admin_menu = DADA::Template::Widgets::screen(
					{
						-data => \$tb_admin_menu, 
						-list_settings_vars_param => { 
													-list   => $list, 
													-dot_it => 1, 
											 	},
					   -vars => {}
					}
				); 
				
	### /Admin Menu Creation...
 
	my $admin_template; 
	
	if($DADA::Config::ADMIN_TEMPLATE){ 	
		$admin_template = fetch_admin_template($DADA::Config::ADMIN_TEMPLATE); 
	}else{ 
		$admin_template = DADA::Template::Widgets::_raw_screen({-screen => 'admin_template.tmpl', -encoding => 1}); 
	}
	
	#my $login_switch_popup_menu_widget = ''; 
	my $login_switch_widget = ''; 
	if($Yeah_Root_Login){  
		$login_switch_widget = DADA::Template::Widgets::login_switch_widget({-list => $args{-List}, ($q->param('flavor') ? (-f => scalar $q->param('flavor')) : ())}); 
	#	$login_switch_popup_menu_widget = DADA::Template::Widgets::login_switch_popup_menu_widget({-list => $args{-List}, ($q->param('flavor') ? (-f => scalar $q->param('flavor')) : ())});
	}


    my $footer_props; 
    if($DADA::Config::GIVE_PROPS_IN_ADMIN == 1){ 
		$footer_props = HTML_Footer() . '| <strong><a href="http://dadamailproject.com/purchase/pro.html" target="_blank">Go Pro</a></strong>';
    }

	my %wysiwyg_vars = ();
	if($list) { 
		 %wysiwyg_vars = DADA::Template::Widgets::make_wysiwyg_vars($list);  	
	}
	my $final_admin_template = DADA::Template::Widgets::screen( 
									{
										-data => \$admin_template,
										-expr => 1,  
										-vars => 
											{
												login_switch_widget            => $login_switch_widget, 
												admin_menu                     => $admin_menu, 
												mobile_admin_menu              => $m_admin_menu,
												admin_top_bar_menu             => $tb_admin_menu, 
												title                          => $args{-Title},
												root_login                     => $args{-Root_Login},
												content                        => '[_dada_content]',	
												footer_props                   => $footer_props, 
												%wysiwyg_vars, 
												%{ $args{ -vars } }, # content, etc
												
												
											}, 
										-list_settings_vars_param => { 
																	-list   => $list, 
																	-dot_it => 1, 
															 	},
										-dada_pseudo_tag_filter   => 1, 	
									}
								); 
								

	my ($admin_header, $admin_footer) = split(/\[_dada_content\]/, $final_admin_template, 2);
	
	if($args{-Part} eq 'full'){
		$final_admin_template =~ s/\[_dada_content\]/<!-- tmpl_var content -->/;
		if ( $args{ -HTML_Header } == 1 ) {
            return $q->header( 
				admin_header_params(),
				)
              . $final_admin_template;
        }
		else { 
			return $final_admin_template; 
		}
		 
	}
	elsif($args{-Part} eq 'header'){ 
			
		if($args{-HTML_Header} == 1){ 
			$admin_header = $q->header(
				admin_header_params(), 
				) . $admin_header; 
		}
		return $admin_header; 
	}
	else {
		return $admin_footer; 
	}
	
}


sub admin_header_params { 

    my %params = (
        -type            => 'text/html',  
        -charset         => $DADA::Config::HTML_CHARSET,
        -Pragma          => 'no-cache', 
        '-Cache-control' => 'no-cache, must-revalidate',
    );
            
   return %params;


}




sub default_template {
    
    my ($args) = @_; 
    if(!exists($args->{-Use_Custom})){ 
        $args->{-Use_Custom} = 1; 
    }
    my $tmpl;

    if (   
           $args->{-Use_Custom} == 1
        && $DADA::Config::TEMPLATE_OPTIONS->{user}->{enabled} == 1 
        && defined( $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode} ) 
     ) {
        if ( $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode} eq 'magic' ) {
            my ( $m_status, $m_errors, $m_tmpl ) = template_from_magic();
            if ( $m_status == 1 ) {
                $tmpl = $m_tmpl;
            }
            else {
                my $error = 'problems fetching magic template:';
                for (%$m_errors) {
                    $error .= $_ . "\n";
                }
                warn $error;
            }
        }
        elsif ( $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode} eq 'manual' ) {
            my $tmpl_file = $DADA::Config::TEMPLATE_OPTIONS->{user}->{manual_options}->{template_url};
            if ( DADA::App::Guts::isa_url($tmpl_file) ) {
                $tmpl = open_template_from_url( -URL => $tmpl_file );
            }
            else {
                $tmpl = fetch_user_template($tmpl_file);
            }
        }
        else {
            warn 'Unknown user template type: "' . $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode} . '"';
        }
    }
    if ( !defined($tmpl) ) {
        require DADA::Template::Widgets;
        $tmpl = DADA::Template::Widgets::_raw_screen(
            {
                -screen   => 'list_template.tmpl',
                -encoding => 1,
            }
        );
    }
    return $tmpl;
}

sub can_grab_url { 
    my ($args) = @_; 
    if(!exists($args->{-url})){ 
        return undef; 
    }
    my $url = $args->{-url};
    
    my ($src, $res, $md5) = grab_url({-url =>  $url });
    if($res->is_success){ 
        return 1; 
    }
    else { 
        return 0; 
    }
}




sub template_from_magic {

    my ($args) = shift || undef;
    my $status = 0;
    my $errors = {};
    my $template          = undef;
    my $can_use_html_tree = 1;

    try {
        require HTML::Tree;
    }
    catch {
        $can_use_html_tree = 0;
        $errors->{missing_cpan_modules} = 1;
        return ( $status, $errors, undef );
    };

    if ( !defined($args) ) {
        $args = $DADA::Config::TEMPLATE_OPTIONS->{user}->{magic_options};
    }

    if ( $can_use_html_tree == 1 ) {
        try {
            my ( $src, $res, $md5 ) = grab_url({-url =>  $args->{template_url} });
            if ( !$res->is_success ) {
                warn "Couldn't fetch template: " . $res->message;
                $errors->{problems_fetching_url} = 1;
                return ( $status, $errors, undef );
            }
            
            require HTML::Element;
            require HTML::TreeBuilder;

            ############################################################
            # This module is said to work better for things like HTML 5:
            #require HTML::TreeBuilder::LibXML;
            #HTML::TreeBuilder::LibXML->replace_original();
            # can I use LibXML and do the same I'm doing here, just w/XPaths?
            # What's the same as, find_by_tag_name?
            #
            my $root = HTML::TreeBuilder->new(
                ignore_unknown      => 0,
                no_space_compacting => 1,
                store_comments      => 1,
            );

            $root->parse($src);
            $root->eof();
            $root->elementify();


            # <title> tag:
            my $title_ele = $root->find_by_tag_name('title');
            $title_ele->delete_content();
            $title_ele->push_content(
                HTML::Element->new(
                    '~literal', 'text' => '<!-- tmpl_var title -->',
                )
            );

            # <head> manipulation
            my $head_ele = $root->find_by_tag_name('head');

            # css
            my $custom_css_ele = undef;
            if ( $args->{add_custom_css} == 1 ) {
                $custom_css_ele = HTML::Element->new(
                    'link',
                    rel   => "stylesheet",
                    type  => "text/css",
                    media => "screen",
                    href  => $args->{custom_css_url},
                );
            }

            my $header_code_block_ele = HTML::Element->new('~literal', 'text' => '<!-- tmpl_include list_template_header_code_block.tmpl -->');
            # push or unshift?
            if ( $args->{head_content_added_by} eq 'push' ) {
                $head_ele->push_content($header_code_block_ele);
                if ( $args->{add_custom_css} == 1 ) {
                    $head_ele->push_content( $custom_css_ele );
                }
            }
            elsif ( $args->{head_content_added_by} eq 'unshift' ) {
                $head_ele->unshift_content($custom_css_ele);
                if ( $args->{add_custom_css} == 1 ) {
                    $head_ele->unshift_content( $custom_css_ele );
                }
            }

            if ( $args->{'add_base_href'} == 1 ) {
                my $base_href_ele = HTML::Element->new( 'base', 'href' => $args->{base_href_url}, );
                $head_ele->unshift_content($base_href_ele);
            }

            # Body:            
            my $found_id_tag = 0;
            my $replace_tag  = undef;

            if ( $args->{replace_content_from} eq 'id' || $args->{replace_content_from} eq 'class' ) {
                if ( $args->{replace_content_from} eq 'id' ) {
                    if ( $replace_tag = $root->look_down( "id", $args->{replace_id} ) ) {
                        # Well, that's good!
                    }
                    else {
                        $errors->{cannot_find_id} = 1;
                        warn "cannot find css selector id, '"
                          . $args->{replace_id}
                          . "' - will be replace content in body tag.";
                        $args->{replace_content_from} = 'body';
                    }
                }
                elsif ( $args->{replace_content_from} eq 'class' ) {
                    if ( $replace_tag = $root->look_down( "class", $args->{replace_class} ) ) {
                        # Well, that's good!
                    }
                    else {
                        warn "cannot find css selector class, '"
                          . $args->{replace_class}
                          . "' - will be replace content in body tag.";
                        $errors->{cannot_find_class}  = 1;
                        $args->{replace_content_from} = 'body';
                    }
                }
            }

            if ( $args->{replace_content_from} eq 'id' 
              || $args->{replace_content_from} eq 'class' ) {

                # Remove everything
                $replace_tag->delete_content();

                # push to 0
                $replace_tag->push_content(
                    HTML::Element->new(
                        'div', id => "Dada"
                      )->push_content(
                        HTML::Element->new(
                            '~literal', 'text' => '<!-- tmpl_include list_template_body_code_block.tmpl -->'
                        )
                      )
                );
            }
            else {
                my $body_tag = $root->find_by_tag_name('body');
                $body_tag->delete_content();
                $body_tag->push_content(
                    HTML::Element->new(
                        'div', id => "Dada"
                      )->push_content(
                        HTML::Element->new(
                            '~literal', 'text' => '<!-- tmpl_include list_template_body_code_block.tmpl -->'
                        )
                      )
                );
            }

            $status  = 1;
            my $tmpl = $root->as_HTML( undef, '  ' );
            $root->delete;
            
            return ( $status, $errors, $tmpl );
        }
        catch {
            $errors->{cannot_parse_page} = 1;
            return ( $status, $errors, undef );
        };
    }
}

######################################################################
# templates and such that give the look of dada                      #
######################################################################

sub check_if_template_exists { 
#############################################################################
# dadautility <+> $template_exists <+> sees if the list has a template     #
#############################################################################

	my %args = (-List => undef, 
				@_);
	if($args{-List}){ 
		my(@available_templates) = &available_templates;
		my $template_exists = 0;	
		foreach my $hopefuls(@available_templates) { 
			if ($hopefuls eq $args{-List}) { 
				$template_exists++;
			}
		}    
		return $template_exists;
	}else{ 
		return 0;
	}
}


sub available_templates { 
	my @all;
	my @available_templates;
	
	my $present_template = "";
	opendir(TEMPLATES, $DADA::Config::TEMPLATES ) or 
		croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open $DADA::Config::TEMPLATES  to read: $!";
		 
	while(defined($present_template = readdir TEMPLATES)) { 
		next if $present_template =~ /^\.\.?$/;
		        $present_template =~ s(^.*/)();
		        
		push(@all, $present_template);                             
	}          
	closedir(TEMPLATES);
	
	foreach my $all_those(@all) { 
			 if($all_those =~ m/.*\.template/) { 
				   $all_those =~ s/\.template$//;
				  push(@available_templates, $all_those)
			 }
		 }    
		 
	 @available_templates = sort(@available_templates); 
	my %seen = (); 
	my @unique = grep {! $seen{$_} ++ }  @available_templates; 
	
	return @unique; 
}


sub fetch_admin_template { 
	
	my $file = shift; 
	my $admin_template;
	 
	 
	if(DADA::App::Guts::isa_url($file)){
		$admin_template = open_template_from_url(-URL => $file);
	}else{ 
		if($file !~ m/^\//){ 
			$file = $DADA::Config::TEMPLATES  .'/'. $file;
		}
		require DADA::Template::Widgets; 
		$admin_template = DADA::Template::Widgets::_slurp($file); 
	}
	
	return $admin_template; 
} 


sub fetch_user_template { 
	
	my $file = shift; 
		
	my $template = make_safer($file); 
	
	if(!-e $template){ 
		carp "Template file at: $template doesn't exist!"; 
		return undef;
	}
	else { 
		require DADA::Template::Widgets; 
		return DADA::Template::Widgets::_slurp($template);
	}

}




sub open_template {  
		
	my %args = (
				-List => undef,
				@_
			   );
	
	my $list = $args{-List};
	
	my $template = make_safer($DADA::Config::TEMPLATES  . '/' . $list . '.template'); 
	
	if(!-e $template){ 
		carp "Template file at: $template doesn't exist!"; 
		return undef;
	}
	else { 
		require DADA::Template::Widgets; 
		return DADA::Template::Widgets::_slurp($template);
	}
	
}


sub list_template {

    require DADA::Template::Widgets;
    # DEV: Weird. I know.
    if ( $DADA::Config::PROGRAM_URL eq
        'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi' )
    {
        $DADA::Config::PROGRAM_URL = $ENV{SCRIPT_URI} || $q->url();
    }
    my %args = (
        -List          => undef,
        -Part          => undef,
        -Use_Custom    => 1,
        -Title         => undef,
        #-HTML_Header   => 1,
        -header_params => {},	 # this is used only when you delete a list. 
        -data          => undef, # used in previewing a template.  
        -vars          => {},
		-prof_sess_obj => undef,
        @_,
    );
    my $list = undef;
    if ( $args{ -List } ) {
        $list = $args{ -List };
    }

    my $ls = undef;
    if ( defined($list) ) {
        require DADA::MailingList::Settings;
        $ls = DADA::MailingList::Settings->new( { -list => $list } );
    }

    my $list_template = undef;
    my $using_default_template = 1; 
    
    if ( defined( $args{ -data } ) ) {	
        $list_template = ${ $args{ -data } };
        $using_default_template = 0; 
    }
    elsif ($list) {
        if ( $ls->param('get_template_data') eq "from_url"
            && DADA::App::Guts::isa_url( $ls->param('url_template') ) == 1 )
        {
            $list_template =
              open_template_from_url( -URL => $ls->param('url_template'), );
              $using_default_template = 0; 

        }
        elsif ( $ls->param('get_template_data') eq 'from_default_template' ) {

            $list_template = default_template();
            
        }
        elsif (
            -e make_safer(
                $DADA::Config::TEMPLATES . '/' . $list . '.template' ) )
        {

            $list_template = DADA::Template::Widgets::_slurp(
                make_safer(
                    $DADA::Config::TEMPLATES . '/' . $list . '.template'
                )
            );
            $using_default_template = 0; 

        }    # meaning, there's no list template
        else {
            $list_template = default_template();
        }
    }    # meaning, no list was passed:
    else {
        $list_template = default_template({-Use_Custom => $args{-Use_Custom}});
    }





      

    my $prof_email         = '';
    my $is_logged_in       = 0;
    my $subscribed_to_list = 0;
    my $prof_sess          = undef; 
    my $profile_widget     = undef;
    
    
    my $header_options = {
        include_jquery_lib   => 1,
        include_jqueryui_lib => 1,
        include_app_user_js  => 1,
        add_app_css          => 1,
    }; 
    
#    warn q{$args{-Use_Custom}} . $args{-Use_Custom};
#    warn q{$DADA::Config::TEMPLATE_OPTIONS->{user}->{enabled}} . $DADA::Config::TEMPLATE_OPTIONS->{user}->{enabled}; 
#    warn q{$DADA::Config::TEMPLATE_OPTIONS->{user}->{mode}} . $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode}; 
#    warn q{$using_default_template} . $using_default_template; 
    
    if(
              $args{-Use_Custom} == 1
           && $DADA::Config::TEMPLATE_OPTIONS->{user}->{enabled} == 1 
           && $DADA::Config::TEMPLATE_OPTIONS->{user}->{mode} eq 'magic'
           && $using_default_template == 1
           ) {
#               warn 'using magic header params'; 
               $header_options = $DADA::Config::TEMPLATE_OPTIONS->{user}->{magic_options};
    }
    
    try {

        require DADA::Profile::Session;
        require DADA::Profile;
		if(defined($args{-prof_sess_obj})){ 
			$prof_sess = $args{-prof_sess_obj};
		}
		else { 
			$prof_sess = DADA::Profile::Session->new;
		}

        if ( $prof_sess->is_logged_in ) {
            $is_logged_in = 1;
            $prof_email   = $prof_sess->get;
            my $prof = DADA::Profile->new( { -email => $prof_email } );
            $subscribed_to_list =
              $prof->subscribed_to_list( { -list => $list } );
        }
		if(defined($args{-prof_sess_obj})){ 
			$profile_widget = DADA::Template::Widgets::profile_widget({-prof_sess_obj => $args{-prof_sess_obj}}); 
		}
		else { 
			$profile_widget = DADA::Template::Widgets::profile_widget(); 
		}
    } catch {
        carp "CAUGHT Error with Sessioning: $_";
    };
	
	my $footer_props; 
	if ( $DADA::Config::GIVE_PROPS_IN_HTML == 1) {
		$footer_props = DADA::Template::HTML::HTML_Footer(); 
    }
    
     my $content_tag = quotemeta('<!-- tmpl_var content -->');
     if ( $list_template !~ m/$content_tag/ ) {
          # warn 'can\'t find content tag in list template'; 
     }
    
    
	
    my $final_list_template = DADA::Template::Widgets::screen(
        {
            -data                   => \$list_template,
            -dada_pseudo_tag_filter => 1,
            -vars                   => {
                title              => $args{ -Title },
                'profile.email'    => $prof_email,
                subscribed_to_list => $subscribed_to_list,

                # The message tag isn't being used anymore but....
                message             => $args{ -Title },
                content             => '[_dada_content]',
                mojo                => '[_dada_content]',
                dada                => '[_dada_content]',
                profile_widget      => $profile_widget,
                show_profile_widget => 1,
				footer_props        => $footer_props, 
				
				include_jquery_lib   =>  $header_options->{include_jquery_lib},
                include_jqueryui_lib =>  $header_options->{include_jqueryui_lib},
                include_app_user_js  =>  $header_options->{include_app_user_js},
                add_app_css          =>  $header_options->{add_app_css},
                
                %{ $args{ -vars } },
            },
            (
                ( defined($list) )
                ? (
                    -list_settings_vars_param => {
                        -list   => $list,
                        -dot_it => 1,
                    },
                  )
                : (),
            )
        }
    );
	if($args{ -Part } eq 'full'){ 

		$final_list_template =~ s/\[_dada_content\]/<!-- tmpl_var content -->/;
		if ( $args{ -HTML_Header } == 1 ) {
            return $q->header( -type => 'text/html',
                %{ $args{ -header_params } } )
              . $final_list_template;
        }
		else { 
			return $final_list_template; 
		}
	}
	else { 
    	my ( $header, $footer ) =
	      split ( /\[_dada_content\]/, $final_list_template, 2 );

	    if ( $args{ -Part } eq 'header' ) {

	        if ( $args{ -HTML_Header } == 1 ) {
	            return $q->header( -type => 'text/html',
	                %{ $args{ -header_params } } )
	              . $header;
	        }
	        else {
	            return $header;
	        }
	    }
	    else {
        	return $footer;
	    }
	}

}

sub HTML_Footer { 
	return '<a href="http://dadamailproject.com" target="_blank">Dada Mail ' . $DADA::Config::VER . '</a> | Copyright &copy; 1999-2015, <a href="http://dadamailproject.com/justin" target="_blank">Simoni Creative</a>';	
}

sub open_template_from_url {
    my %args = (
        -URL => undef,
        @_,
    );

    if ( !$args{-URL} ) {
        carp "no url passed! $!";
        return undef;
    }
    else {
        my ( $src, $res, $md5 ) = grab_url({-url =>  $args{-URL} });
        if ( $res->is_success ) {
            return $src;
        }
        else {
            return undef;
        }
    }
}
	

# This is a bad idea - better to just OO this module... 
sub lame_init(){ 
    if(!defined($q)){ 
        require CGI;
        $q = CGI->new();
    }
}



=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2015 Justin Simoni 
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



1;

