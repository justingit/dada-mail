package DADA::Template::Widgets::Admin_Menu;

=pod

=head1 NAME DADA::Template::Widgets::Admin_Menu

=head1 SYNOPSIS

	use DADA:Widgets::Admin_Menu

=head1 DESCRIPTION 

This module creates the Admin Menu for the List Control Panel. It also packs data so 
it can be saved

=head1 SUBROUTINES

=cut

use lib qw(
	../../../
	../../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(
  make_nav_hashes
  check_function_permissions
  make_admin_menu
  make_feature_menu
  create_save_set
);

use strict;
use vars qw(@EXPORT);

=pod

=head2 make_nav_hashes

a pretty private sub, returns 2 references to hashes from saved information and defaults

=cut

sub make_nav_hashes {

    my $list_info_ref = shift;

    my $admin_menu = $list_info_ref->{admin_menu} || create_save_set();

    # simple procedural interface

    my %NAVS;
    my %SUBNAVS;
    if ($admin_menu) {
        my @nav_params = split( ';', $admin_menu );
        foreach my $this_nav (@nav_params) {
            if ( $this_nav =~ /SUBNAV/ ) {
                $this_nav =~ s/SUBNAV\-//g;
                my ( $name, $value ) = split( '=', $this_nav );
                $SUBNAVS{$name} = $value;
            }
            else {
                $this_nav =~ s/NAV\-//g;
                my ( $name, $value ) = split( '=', $this_nav );
                $NAVS{$name} = $value;
            }
        }

        return ( \%NAVS, \%SUBNAVS );
    }
}

=pod

=head2 check_function_permissions

	my $function_permissions = check_function_permissions(-List_Ref => \%list_info, 
														  -Function => $args{-Function});
		if ($function_permissions < 1){
			$problems++;
		}

=cut

sub check_function_permissions {

    my %args = (
        -List_Ref => undef,
        -Function => undef,
        @_
    );
    my $check = 1;
    my ( $NAVS, $SUBNAVS ) = make_nav_hashes( $args{-List_Ref} );

    my @Global_Admin_Menu_Copy = @$DADA::Config::ADMIN_MENU;

    foreach my $nav (@Global_Admin_Menu_Copy) {
        my $nav_entry;

        if ( $nav->{-Title} ) {

            if ( exists( $NAVS->{ $nav->{-Title} } ) ) {
                $nav->{-Activated} = $NAVS->{ $nav->{-Title} };
            }

            if (   defined( $nav->{-Function} )
                && defined( $args{-Function} )
                && ( $nav->{-Activated} == 0 )
                && ( $nav->{-Function} eq $args{-Function} ) )
            {
                $check = 0;
            }
            foreach my $subnav ( @{ $nav->{-Submenu} } ) {
                my $subnav_entry;
                if ( $subnav->{-Function} ) {
                    if ( exists( $SUBNAVS->{ $subnav->{-Function} } ) ) {
                        $subnav->{-Activated} = $SUBNAVS->{ $subnav->{-Function} };
                    }
                    if (   $subnav->{-Activated} == 0
                        && $subnav->{-Function} eq $args{-Function} )
                    {
                        $check = 0;
                    }
                }
            }
        }
    }

    return $check;

}

=pod

=head2 make_admin_menu
	
		$admin_menu  = DADA::Template::Widgets::Admin_Menu::make_admin_menu('superuser'); 
	 
		$admin_menu  = DADA::Template::Widgets::Admin_Menu::make_admin_menu('user',\%list_info); 


If the superuse is specified, all menu items will be active, if not, what will be 
active will be determined by the \%list_info (the settings) 

this returns an html menu.

=cut

sub make_admin_menu {
	my ($args) = @_; 

	if(! exists($args->{-privileges})) { 
		$args->{-privileges} = 'regular'; 
	}
	my $ls = undef; 
	if(! exists($args->{-ls_obj})) { 
		croak("need to pass -ls_obj");
	}
	else { 
		$ls = $args->{-ls_obj};
	}
	if(! exists($args->{-flavor})) { 
		$args->{-flavor} = ''; 
	}

	if(! exists($args->{-for_mobile})) { 
		$args->{-for_mobile} = 0; 
	}
	
	# warn '$args->{-style}' . $args->{-style}; 
	if(! exists($args->{-style})) { 
		#$args->{-style} = 'side_bar'; 
	}
	
	
	
	

   #---------------------------------------------------------------------------#
    require DADA::Template::Widgets;

   #---------------------------------------------------------------------------#

    my $ht_admin_menu = [];

    my ( $NAVS, $SUBNAVS ) = make_nav_hashes($ls->get);

    my $ht_entry = [];

    my @Global_Admin_Menu_Copy = @$DADA::Config::ADMIN_MENU;

    foreach my $nav (@Global_Admin_Menu_Copy) {

        next if !$nav->{-Title};

        # I don't know...
        if ( exists( $NAVS->{ $nav->{-Title} } ) ) {
            $nav->{-Activated} = $NAVS->{ $nav->{-Title} };
        }

        $nav->{-Activated} = 1
          if ( $args->{-privileges} eq 'superuser' );

        my $ht_subnav = [];

        foreach my $subnav ( @{ $nav->{-Submenu} } ) {

            next if !$subnav->{-Function};

            #again, what?
            if ( exists( $SUBNAVS->{ $subnav->{-Function} } ) ) {
                $subnav->{-Activated} = $SUBNAVS->{ $subnav->{-Function} };
            }

			if ( $args->{-privileges} eq 'superuser' ) { 
            	$subnav->{-Activated} = 1;
			}
            
            if ( $subnav->{-Title} =~ m/Invite/ ) {
                $subnav->{-Title} = DADA::Template::Widgets::screen(
                    {
                        -data => \$subnav->{-Title},
                        -expr => 1, 
                        -vars => {
                            'list_settings.enable_mass_subscribe'                   => $ls->param('enable_mass_subscribe'),
                            'list_settings.enable_mass_subscribe_only_w_root_login' => $ls->param('enable_mass_subscribe_only_w_root_login'), 
                            
                        },
                    }
                );
            }

            push(
                @$ht_subnav,
                {
                    Activated => $subnav->{-Activated},
                    Title_URL => $subnav->{-Title_URL},
                    Title     => $subnav->{-Title},
					Function  => $subnav->{-Function},
                    (
                        (
                            defined( $ls->param('disabled_screen_view') )
                              && $ls->param('disabled_screen_view') eq 'hide'
                        ) ? ( hide_nav => 1, ) : ( hide_nav => 0, )
                    )
                }
            );

        }

        push(
            @$ht_entry,
            {
                Activated => $nav->{-Activated},
                Title_URL  => $nav->{-Title_URL},
                Title      => $nav->{-Title},
                SUBNAV     => $ht_subnav,
				for_mobile => $args->{-for_mobile},
                (
                    (
                        defined( $ls->param('disabled_screen_view') )
                          && $ls->param('disabled_screen_view') eq 'hide'
                    ) ? ( hide_nav => 1, ) : ( hide_nav => 0, )
                )
            }
        );

    }
    
    #require Data::Dumper; 
    #warn Data::Dumper::Dumper($ht_entry); 
    
	my $login_switch_popup_menu_widget = '';
	if ( $args->{-privileges} eq 'superuser' ) { 
		$login_switch_popup_menu_widget = DADA::Template::Widgets::login_switch_popup_menu_widget(
			{
			-list => $ls->param('list'), 
			-flavor => $args->{-flavor},
			}
		);
	}
	
	if($args->{-style} eq 'side_bar') {
	    return DADA::Template::Widgets::screen(
	        {
	            -screen => 'admin_menu_widget.tmpl',
	            -vars   => { 
	                for_mobile                     => $args->{-for_mobile}, 
					login_switch_popup_menu_widget => $login_switch_popup_menu_widget, 
	                NAV                            => $ht_entry, 
	            },
	            -list_settings_vars_param => {
	                -list   => $ls->param('list'),
	                -dot_it => 1,
	            },
	        }
	    );
	}
	elsif($args->{-style} eq 'top_bar') {
	    return DADA::Template::Widgets::screen(
	        {
	            -screen => 'admin_top_bar_menu.tmpl',
	            -vars   => { 
	                for_mobile                     => $args->{-for_mobile}, 
					login_switch_popup_menu_widget => $login_switch_popup_menu_widget, 
	                NAV                            => $ht_entry, 
	            },
	            -list_settings_vars_param => {
	                -list   => $ls->param('list'),
	                -dot_it => 1,
	            },
	        }
	    );
		
	}
}

=pod

=head2 make_feature_menu

print make_feature_menu(\%list_info); 

creates a form to allow you to turn on and off features of the admin menu

=cut

sub make_feature_menu {

    my $list_info_ref = shift;

    my $NAVS    = {};
    my $SUBNAVS = {};

    ( $NAVS, $SUBNAVS ) = make_nav_hashes($list_info_ref);

    my $menu;

    #walk through the complex data structures..

    my @Global_Admin_Menu_Copy = @$DADA::Config::ADMIN_MENU;

    foreach my $nav (@Global_Admin_Menu_Copy) {
        my $nav_entry;
        if ( $nav->{-Title} ) {

            #turn off.

            # *really* Don't understand this line.
            # I don't understand this line.
            if ( exists( $NAVS->{ $nav->{-Title} } ) ) {
                $nav->{-Activated} = $NAVS->{ $nav->{-Title} };
            }

            if ( $nav->{-Activated} == 1 ) {
                $nav_entry =
"<p><input type=\"checkbox\" name='NAV-$nav->{-Title}' id='NAV-$nav->{-Title}' checked=\"checked\" value=\"1\" /> <label for='NAV-$nav->{-Title}'>$nav->{-Title}</label>\n";
                $menu .= $nav_entry;
            }
            else {
                $nav_entry =
"<p><input type=\"checkbox\" name='NAV-$nav->{-Title}' id='NAV-$nav->{-Title}' value=\"1\" /> <label for='NAV-$nav->{-Title}'>$nav->{-Title}</label>\n";
                $menu .= $nav_entry;

            }
            foreach my $subnav ( @{ $nav->{-Submenu} } ) {
                my $subnav_entry;
                if ( $subnav->{-Function} ) {

                    #turn off.
                    if ( exists( $SUBNAVS->{ $subnav->{-Function} } ) ) {
                        $subnav->{-Activated} = $SUBNAVS->{ $subnav->{-Function} };
                    }

                    if ( $subnav->{-Activated} == 1 ) {
                        $subnav_entry =
"<br />&nbsp;<input type=\"checkbox\" name='SUBNAV-$subnav->{-Function}' id='SUBNAV-$subnav->{-Function}' checked=\"checked\" value=\"1\" /><label for='SUBNAV-$subnav->{-Function}'>$subnav->{-Title}</label>\n";
                    }
                    else {
                        $subnav_entry =
"<br />&nbsp;<input type=\"checkbox\" name='SUBNAV-$subnav->{-Function}' id='SUBNAV-$subnav->{-Function}' value=\"1\" /><label for='SUBNAV-$subnav->{-Function}'>$subnav->{-Title}</label>\n";
                    }
                    $menu .= $subnav_entry;
                }
            }
            $menu .= '</p><hr />';
        }
        else {
            $nav_entry =
"<p><input type=\"checkbox\" name='NAV-$nav->{-Title}' id='NAV-$nav->{-Title}' value=\"1\" /><label for='NAV-$nav->{-Title}'>$nav->{-Title}</label>\n";
            $menu .= $nav_entry;
        }
    }

    return $menu;
}

=pod

=head2 create_save_set

	foreach(@params){$param_hash{$_} = $q->param($_);}	
	my $save_set = create_save_set(\%param_hash); 
	my %new_info = (list => $list, admin_menu => $save_set);
	setup_list(\%new_info); 

creates a packed string to save admin menu information, The format is really weird, 

take mi word for it.


=cut

sub create_save_set {

    my $param_hashref = shift || undef;
    my $save_set;
    my $prev_info = 1;

    if ( !defined($param_hashref) ) {
        $prev_info = 0;
    }

    my @Global_Admin_Menu_Copy = @$DADA::Config::ADMIN_MENU;

    foreach my $nav (@Global_Admin_Menu_Copy) {
        my $default = 0;
        if ( $prev_info == 0 ) {
            $default = $nav->{-Activated};
        }
        my $save_nav = $param_hashref->{"NAV-$nav->{-Title}"}
          || $default;    #$nav->{-Activated};
        $save_set .= "NAV-$nav->{-Title}\=$save_nav;";
        foreach my $subnav ( @{ $nav->{-Submenu} } ) {
            my $s_default = 0;
            if ( $prev_info == 0 ) {
                $s_default = $subnav->{-Activated};
            }
            my $save_subnav = $param_hashref->{"SUBNAV-$subnav->{-Function}"}
              || $s_default;    #|| $subnav->{-Activated};
            $save_set .= "SUBNAV-$subnav->{-Function}\=$save_subnav;";
        }
    }
    return $save_set;
}

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2019 Justin Simoni All rights reserved. 

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

