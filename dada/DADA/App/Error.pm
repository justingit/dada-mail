package DADA::App::Error;

=pod

=head1 NAME 

DADA::App::Error

=head1 SYNOPSIS

	use DADA::App::Error

This module basically has error messages in HTML and spits 'em back at ya.

=cut

use lib qw(../../ ../perllib);

use DADA::Config;
use DADA::App::Guts;
use DADA::Template::HTML;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(cgi_user_error);
use strict;
use vars qw(@EXPORT);
my %error;

use Try::Tiny;
use Carp qw(carp croak);

#$Carp::Verbose = 1;

require CGI;
my $q = CGI->new;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);

my $Referer = uriescape( $q->referer );

if (   ( $DADA::Config::PROGRAM_URL eq "" )
    || ( $DADA::Config::PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi' ) )
{
    $DADA::Config::PROGRAM_URL = $ENV{SCRIPT_URI} || $q->url();

}

if (   ( $DADA::Config::S_PROGRAM_URL eq "" )
    || ( $DADA::Config::S_PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi' ) )
{
    $DADA::Config::S_PROGRAM_URL = $ENV{SCRIPT_URI} || $q->url();
}

=pod

=head1 SUBROUTINES

=head2 cgi_user_error

 print cgi_user_error({-list  => 'my_list', 
                      -error => 'some_error', 
                      -email => 'some@email.com'}); 

Gives back an HTML friendly error message.

=cut

sub cgi_user_error {

    my ($args) = @_;

    require DADA::Template::Widgets;

    my $available_lists_ref;
    my $li              = {};
    my $list_login_form = "";
    my $list_exists     = 0;

    if ( !exists( $args->{-wrap_with} ) ) {
        $args->{-wrap_with} = 'list';
    }
    if ( !exists( $args->{-chrome} ) ) {
        $args->{-chrome} = 1;
    }

    if ( !exists( $args->{-vars}->{captcha_auth} ) ) {
        $args->{-vars}->{captcha_auth} = 1;
    }

    #    if(!exists($args->{-error})) {
    #        carp "no error was passed!";
    # #       $args->{-error} = 'undefined';
    #    }
    #
    #    if(!defined($args->{-error})){
    #            carp "no error was passed!";
    #        }
    #
    my $profile_fields_report = [];

    # Something Something, add Name/Label of Field...
    if ( exists( $args->{-invalid_profile_fields} ) ) {

        require DADA::ProfileFieldsManager;
        my $attrs = DADA::ProfileFieldsManager->new->get_all_field_attributes;
        foreach my $field_error ( keys %{ $args->{-invalid_profile_fields} } ) {
            push(
                @$profile_fields_report,
                {
                    field => $field_error,
                    label => $attrs->{$field_error}->{label},
                    error => 'required',                        # punking out on this, for now
                }
            );
        }
    }
    if ( $args->{-error} !~ /unreadable_db_files|sql_connect_error|bad_setup/ ) {
        $list_exists = check_if_list_exists( -List => $args->{-list}, -Dont_Die => 1 ) || 0;
    }

    if ( $list_exists > 0 ) {
        require DADA::MailingList::Settings;
        my $ls =
          DADA::MailingList::Settings->new( { -list => $args->{-list} } );
        $li = $ls->get();
    }

    # What a weird idea...
    my ( $sec, $min, $hour, $day, $month, $year ) =
      (localtime)[ 0, 1, 2, 3, 4, 5 ];
    my $auth_code = DADA::App::Guts::make_pin(
        -Email => $month . '.' . $day . '.' . $args->{-email},
        -List  => $args->{-list},
    );

    if ( $args->{-error} !~ /unreadable_db_files|sql_connect_error|bad_setup/ ) {
        if ( $DADA::Config::LOGIN_WIDGET eq 'popup_menu' ) {
            $list_login_form = DADA::Template::Widgets::list_popup_login_form();
        }
        elsif ( $DADA::Config::LOGIN_WIDGET eq 'text_box' ) {
            $list_login_form = DADA::Template::Widgets::screen( { -screen => 'text_box_login_form.tmpl', -expr => 1 } );
        }
        else {
            warn "'$DADA::Config::LOGIN_WIDGET' misconfigured!";
        }
    }

    my $subscription_form;
    my $unsubscription_form;

    if ( $args->{-error} !~ /unreadable_db_files|sql_connect_error|bad_setup|bad_SQL_setup|install_dir_still_around/ ) {
        if ( $args->{-list} ) {
            $subscription_form = DADA::Template::Widgets::subscription_form(
                {
                    -list       => $args->{-list},
                    -email      => $args->{-email},
                    -give_props => 0
                }
            );
            if ( $list_exists > 0 ) {
                $unsubscription_form = DADA::Template::Widgets::unsubscription_form(
                    {
                        -list       => $args->{-list},
                        -email      => $args->{-email},
                        -give_props => 0
                    }
                );
            }
        }
        else {
            $subscription_form =
              DADA::Template::Widgets::subscription_form( { -email => $args->{-email}, -give_props => 0 } )
              ;    # -show_hidden =>1 ?!?!?!
            if ( $list_exists > 0 ) {
                $unsubscription_form =
                  DADA::Template::Widgets::unsubscription_form( { -email => $args->{-email}, -give_props => 0 } )
                  ;    # -show_hidden => 1?!?!?!
            }
        }
    }

    my $unknown_dirs = [];
    if ( $args->{-error} eq 'bad_setup' ) {
        my @tests = ( $DADA::Config::FILES, $DADA::Config::TEMPLATES, $DADA::Config::TMP );

        my %sift;
        for (@tests) { $sift{$_}++ }
        @tests = keys %sift;

        for my $test_dir (@tests) {

            if ( !-d $test_dir ) {
                push( @$unknown_dirs, { dir => $test_dir } );
            }
            elsif ( !-e $test_dir ) {
                push( @$unknown_dirs, { dir => $test_dir } );
            }
            else {
                # ...
            }
        }
    }

    if (   $args->{-error} eq 'already_sent_sub_confirmation'
        || $args->{-error} eq 'already_sent_unsub_confirmation' )
    {
        my $list  = $args->{-list};
        my $email = $args->{-email};
        my $rm;
        if ( $args->{-error} eq 'already_sent_sub_confirmation' ) {
            $rm = 's';
        }
        elsif ( $args->{-error} eq 'already_sent_unsub_confirmation' ) {
            $rm = 'unsubscription_request';
        }
        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
        my $can_use_captcha = 0;

        if ( $ls->param('limit_sub_confirm_use_captcha') == 1 ) {
            $can_use_captcha = can_use_AuthenCAPTCHA();
        }

        if ( $can_use_captcha == 1 ) {
            my $cap            = DADA::Security::AuthenCAPTCHA->new;
            my $CAPTCHA_string = $cap->get_html( $DADA::Config::RECAPTCHA_PARAMS->{public_key} );

            require DADA::Template::Widgets;
            my $r = DADA::Template::Widgets::wrap_screen(
                {
                    -screen                   => 'resend_conf_captcha_step.tmpl',
                    -with                     => 'list',
                    -expr                     => 1,
                    -list_settings_vars_param => { -list => $ls->param('list') },
                    -subscriber_vars_param    => {
                        -list  => $list,
                        -email => $email,
                        -type  => 'sub_confirm_list'
                    },    #what?
                    -dada_pseudo_tag_filter => 1,
                    -vars                   => {
                        %{ $args->{-vars} },
                        rm             => $rm,
                        CAPTCHA_string => $CAPTCHA_string,
                        flavor         => 'resend_conf',
                        list           => xss_filter($list),
                        email          => $email,
                        token          => xss_filter( $q->param('token') ),
                    },
                },
            );
            return $r;
        }
        else {
            # Well, nothing,
            # Continue below:
        }
    }
    
    if($args->{-error} eq 'invalid_password'){ 

        my $can_use_captcha = 0;
        my $CAPTCHA_string  = '';
        my $cap; 
        if ( can_use_AuthenCAPTCHA() == 1 ) {
            require DADA::Security::AuthenCAPTCHA;
            $cap    = DADA::Security::AuthenCAPTCHA->new;
            $CAPTCHA_string = $cap->get_html( $DADA::Config::RECAPTCHA_PARAMS->{public_key} );
            # It's a weird place for this, I admit: 
            $args->{-vars}->{captcha_string}  = $CAPTCHA_string;
            $args->{-vars}->{can_use_captcha} = 1;
            
        }
    }

    my $screen = '';
    my $r      = '';

    eval {
        if ( $args->{-chrome} == 1 ) {
            $screen = DADA::Template::Widgets::wrap_screen(
                {
                    -screen => 'error_' . $args->{-error} . '_screen.tmpl',
                    (
                        $args->{-wrap_with} eq 'admin'
                        ? (
                            -with           => 'admin',
                            -wrapper_params => {

                                #-Root_Login => $root_login,
                                -List => $args->{-list},
                            },

                          )
                        : ( -with => 'list', )
                    ),
                    -vars => {
                        %{ $args->{-vars} },
                        subscription_form     => $subscription_form,
                        unsubscription_form   => $unsubscription_form,
                        list_login_form       => $list_login_form,
                        email                 => $args->{-email},
                        profile_fields_report => $profile_fields_report,
                        auth_code             => $auth_code,
                        unknown_dirs          => $unknown_dirs,
                        PROGRAM_URL           => $DADA::Config::PROGRAM_URL,
                        S_PROGRAM_URL         => $DADA::Config::S_PROGRAM_URL,
                        error_message         => $args->{-error_message},
                    },

                    -list_settings_vars       => $li,
                    -list_settings_vars_param => { -dot_it => 1 },
                    -subscriber_vars          => { 'subscriber.email' => $args->{-email} },
                }
            );
        }
        else {
            $screen = DADA::Template::Widgets::screen(
                {
                    -screen => 'error_' . $args->{-error} . '_screen.tmpl',
                    -vars   => {
                        %{ $args->{-vars} },
                        subscription_form     => $subscription_form,
                        unsubscription_form   => $unsubscription_form,
                        list_login_form       => $list_login_form,
                        email                 => $args->{-email},
                        profile_fields_report => $profile_fields_report,
                        auth_code             => $auth_code,
                        unknown_dirs          => $unknown_dirs,
                        PROGRAM_URL           => $DADA::Config::PROGRAM_URL,
                        S_PROGRAM_URL         => $DADA::Config::S_PROGRAM_URL,
                        error_message         => $args->{-error_message},
                    },
                    -list_settings_vars       => $li,
                    -list_settings_vars_param => { -dot_it => 1 },
                    -subscriber_vars          => { 'subscriber.email' => $args->{-email} },
                }
            );
        }

    };

    if ($@) {
        if ( defined( $args->{-error_message} ) ) {

            die "Problems showing error message? - $@, \n\n\nOriginal error message: " . $args->{-error_message};
        }
        else {
            die "Problems showing error message? - $@";
        }
    }
    else {
        $r = $screen;
    }

    return $r;

}

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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

1;
