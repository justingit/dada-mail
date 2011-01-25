#!/usr/bin/perl -w
package mx_lookup;

use strict;

# make sure the DADA lib is in the lib paths!
use lib qw(
  ../
  ../DADA/perllib
);

use CGI::Carp qw(fatalsToBrowser);

# use some of those Modules
use DADA::Config 4.0.0 qw(!:DEFAULT);
use DADA::Template::HTML;
use DADA::App::Guts;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use DADA::Template::Widgets;

# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);

my $Plugin_Config = {};

$Plugin_Config->{Plugin_URL} = $q->url;

run()
  unless caller();

sub run {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'mx_lookup'
    );
    my $list = $admin_list;

    # get the list information

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $list_info = $ls->get();

    if ( !$q->param('process') ) {
        my $tmpl = default_template();

        my $scrn .= DADA::Template::Widgets::wrap_screen(
            {
                -data => \$tmpl,
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},

                -vars => { Plugin_URL => $Plugin_Config->{Plugin_URL}, },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        e_print($scrn);
    }
    else {

        my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
        my @emails = split( /\s+|,|;|\n+/, $q->param('addresses') );    # wah?
        my @passed;
        my @failed;

        ###################################################################
        #
        #

        foreach my $email (@emails) {
            my ( $status, $errors ) =
              $lh->subscription_check( { -email => $email, } );
            if ( $errors->{mx_lookup_failed} == 1 ) {
                push( @failed, $email );
            }
            else {
                push( @passed, $email );
            }
        }
        my $passed_report = join( "\n", @passed );
        my $failed_report = join( "\n", @failed );

        #
        #
        ###################################################################
        my $tmpl = process_template();
        my $scrn .= DADA::Template::Widgets::wrap_screen(
            {
                -data => \$tmpl,
				-with           => 'admin', 
				-wrapper_params => { 
					-Root_Login => $root_login,
					-List       => $list,  
				},
                -vars => {
                    passed_report => $passed_report,
                    failed_report => $failed_report,

                },
                -list_settings_vars_param => {
                    -list   => $list,
                    -dot_it => 1,
                },
            }
        );
        e_print($scrn);

    }

}

sub default_template {

    return <<EOF

<!-- tmpl_set name="title" value="MX Lookup Verification" -->

<!-- tmpl_unless list_settings.mx_check --> 
	<p>Warning! mx lookup has not been enabled! <strong><a href="S_PROGRAM_URL -->?f=list_options">Enable...</a></strong> 
<!-- /tmpl_unless --> 


<form action="<!-- tmpl_var S_PROGRAM_URL -->" method="post" target="text_list"> 
<input type="hidden" name="f" value="text_list" /> 

<div class="buttonfloat">
<input type="submit" value="Open Your Current Subscription List in New Window" class="plain" /> 
</div>
<div class="floatclear"></div>
</form> 

<fieldset> 
 <legend>Test a Bunch of Addresses
 </legend>
<form action="<!-- tmpl_var Plugin_URL -->" method="post"> 
<p>
Enter addresses, separated by a new line or a comma below: </p> 

<p><textarea name="addresses" rows="5" cols="40"></textarea> 
<input type="hidden" name="process" value="true" /> 
<div class="buttonfloat">
<input type="submit" value="Verify..." class="processing" /> 
</div> 
<div class="floatclear"></div>
</form> 

</fieldset> 

EOF
      ;

}

sub process_template {

    return <<EOF

	<!-- tmpl_set name="title" value="MX Lookup Verification" -->

<p>The following emails passed mx lookup verification:</p> 
<form action="<!-- tmpl_var S_PROGRAM_URL -->" method="post"> 
<input type="hidden" name="f" value="add" /> 
<input type="hidden" name="process" value="1" /> 
<p> 
<textarea name="new_emails" rows="5" cols="40"><!-- tmpl_var passed_report --> </textarea> 
</p> 
<div class="buttonfloat">


	
<!-- tmpl_if list_settings.enable_mass_subscribe -->		
	<input type="submit" value="Invite/Add These Addresses to Your List" class="processing" />
<!-- tmpl_else --> 
	<input type="submit" value="Invite These Addresses to Your List" class="processing" />
<!-- /tmpl_if -->

	
	

</div> 
<div class="floatclear"></div>

</form> 

<p>
 The following emails failed mx lookup verification:
</p> 

<form action="<!-- tmpl_var S_PROGRAM_URL -->" method="post"> 
<input type="hidden" name="f" value="delete_email" /> 
<input type="hidden" name="process" value="true" />

<p> 
<textarea name="delete_list" rows="5" cols="40"><!-- tmpl_var failed_report --></textarea> 
</p> 
<div class="buttonfloat">
<input type="submit" value="Remove These Addresses From Your List" class="alertive" /> 
</div> 
<div class="floatclear"></div>

</form> 


EOF
      ;

}

=pod

=head1 NAME

mx_lookup.cgi - test a list of addresses to see if they have a valid MX record. 

=head1 DEPRECATION NOTICE

This plugin is marked for deprecation - testing for an MX record for an address will be added to the verification process of the Add/Invite screen in future versions of Dada Mail. 

This plugin is useful, though, illustrating how to I<write> a Dada Mail plugin. 

Individual subscription requests can already have an MX record check done - in the list control panel, under, B<Your Mailing List - Mailing List Options>, check the option, I<Look Up Hostnames When Validating Email Addresses (MX Lookup)>. 

=head1 USAGE

This script is a Dada Mail plugin. Once configured, you should be able to log into your list and access this plugin under the, B<Plugins> menu. 

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INSTALLATION

=head2 Upload B<mx_lookup.cgi> into the plugins directory (it may already be there)

We're assuming your cgi-bin looks like this: 

 /home/account/cgi-bin/dada

and inside the I<dada> directory is the I<mail.cgi> file and the I<DADA> (uppercase) directory. Good! Make a B<new> directory in the I<dada> directory called, B<plugins>. 

Upload your tweaked copy of I<mx_lookup.cgi> into that B<plugins> directory. chmod 755 mx_lookup.cgi

=head2 Configure the Config.pm file

This plugin will give you a new menu item in your list control panel. Tell Dada Mail to make this menu item by tweaking the Config.pm file. Find this line (or the line(s) similar) in Config.pm file: 

 #					{-Title      => 'MX Lookup Verification',
 #					 -Title_URL  => $PLUGIN_URL."/mx_lookup.cgi",
 #					 -Function   => 'mx_lookup',
 #					 -Activated  => 1,
 #					},


Uncomment it (take off the "#"'s) 

Save the Config.pm file. 

=head1 DEPENDENCIES

You'll most likely want to use the version of this plugin with the version of Dada Mail is comes with. 

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999 - 2011 Justin Simoni All rights reserved. 

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

