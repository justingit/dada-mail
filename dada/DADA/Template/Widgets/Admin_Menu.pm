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

    my $permissions = shift;
    my $li          = shift;

   #---------------------------------------------------------------------------#
    require DADA::Template::Widgets;

   #---------------------------------------------------------------------------#

    my $ht_admin_menu = [];

    my ( $NAVS, $SUBNAVS ) = make_nav_hashes($li);

    my $ht_entry = [];

    my @Global_Admin_Menu_Copy = @$DADA::Config::ADMIN_MENU;

    foreach my $nav (@Global_Admin_Menu_Copy) {

        next if !$nav->{-Title};

        # I don't know...
        if ( exists( $NAVS->{ $nav->{-Title} } ) ) {
            $nav->{-Activated} = $NAVS->{ $nav->{-Title} };
        }

        $nav->{-Activated} = 1
          if ( $permissions eq 'superuser' );

        my $ht_subnav = [];

        foreach my $subnav ( @{ $nav->{-Submenu} } ) {

            next if !$subnav->{-Function};

            #again, what?
            if ( exists( $SUBNAVS->{ $subnav->{-Function} } ) ) {
                $subnav->{-Activated} = $SUBNAVS->{ $subnav->{-Function} };
            }

			if ( $permissions eq 'superuser' ) { 
            	$subnav->{-Activated} = 1;
			}
            
            if ( $subnav->{-Title} =~ m/Invite/ ) {
                $subnav->{-Title} = DADA::Template::Widgets::screen(
                    {
                        -data => \$subnav->{-Title},
                        -expr => 1, 
                        -vars => {
                            'list_settings.enable_mass_subscribe'                   => $li->{enable_mass_subscribe},
                            'list_settings.enable_mass_subscribe_only_w_root_login' => $li->{enable_mass_subscribe_only_w_root_login}, 
                            
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
                            exists( $li->{disabled_screen_view} )
                              && $li->{disabled_screen_view} eq 'hide'
                        ) ? ( hide_nav => 1, ) : ( hide_nav => 0, )
                    )
                }
            );

        }

        push(
            @$ht_entry,
            {
                Activated => $nav->{-Activated},
                Title_URL => $nav->{-Title_URL},
                Title     => $nav->{-Title},
                SUBNAV    => $ht_subnav,
                (
                    (
                        exists( $li->{disabled_screen_view} )
                          && $li->{disabled_screen_view} eq 'hide'
                    ) ? ( hide_nav => 1, ) : ( hide_nav => 0, )
                )
            }
        );

    }

    return DADA::Template::Widgets::screen(
        {
            -screen => 'admin_menu_widget.tmpl',
            -vars   => { NAV => $ht_entry, }
        }
    );

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
"<p><input type=\"checkbox\" name='NAV-$nav->{-Title}' checked=\"checked\" value=\"1\" /><strong>$nav->{-Title}</strong>\n";
                $menu .= $nav_entry;
            }
            else {
                $nav_entry =
"<p><input type=\"checkbox\" name='NAV-$nav->{-Title}' value=\"1\" /><strong>$nav->{-Title}</strong>\n";
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
"<br />&nbsp;<input type=\"checkbox\" name='SUBNAV-$subnav->{-Function}' checked=\"checked\" value=\"1\" />$subnav->{-Title}\n";
                    }
                    else {
                        $subnav_entry =
"<br />&nbsp;<input type=\"checkbox\" name='SUBNAV-$subnav->{-Function}' value=\"1\" />$subnav->{-Title}\n";
                    }
                    $menu .= $subnav_entry;
                }
            }
            $menu .= '</p><hr />';
        }
        else {
            $nav_entry =
"<p><input type=\"checkbox\" name='NAV-$nav->{-Title}' value=\"1\" /><strong>$nav->{-Title}</strong> five\n";
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

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

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

