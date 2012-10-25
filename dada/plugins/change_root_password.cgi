#!/usr/bin/perl -w
use strict; 

# make sure the DADA lib is in the lib paths!
use lib qw(../ ../DADA/perllib ../../../../perl ../../../../perllib); 

use CGI::Carp qw(fatalsToBrowser);

# use some of those Modules
use DADA::Config 6.0.0;
use DADA::Template::HTML; 
use DADA::Template::Widgets; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 


my $Start_Marker = '# Start Root Password'; 
my $End_Marker   = '# End Root Password'; 





# we need this for cookies things
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);

my $URL = $q->url; 

# This will take care of all out security woes
my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
                                                    -Function => 'change_root_password');
my $list = $admin_list; 

# get the list information
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 
                             
	               
if(!$q->param('process')){ 

    my $tmpl = default_screen(); 	                
	my $scrn = DADA::Template::Widgets::wrap_screen(
						{
							-data => \$tmpl, 
							-with           => 'admin', 
							-wrapper_params => { 
								-Root_Login => $root_login,
								-List       => $list,  
							},
							-vars => { 
								 ROOT_PASS_IS_ENCRYPTED => $DADA::Config::ROOT_PASS_IS_ENCRYPTED, 
								
							        new_pass_no_match => ($q->param('new_pass_no_match') == 1) ? 1 : 0, 
							        old_root_pass_incorrect => ($q->param('old_root_pass_incorrect') == 1) ? 1 : 0, 
								
							},
						}
					);
    e_print($scrn); 

}else{ 


    
    if(!$q->param('old_password')){ 
        
        print $q->redirect(-url => $URL . '?old_root_pass_incorrect=1'); 
        return; 
        
    }else{ 
    
    
    
       if($DADA::Config::ROOT_PASS_IS_ENCRYPTED == 1){ 	
            require DADA::Security::Password; 
            my $root_password_check = DADA::Security::Password::check_password($DADA::Config::PROGRAM_ROOT_PASSWORD, $q->param('old_password')); 
            if($root_password_check == 1){
                # we are good.
            } else { 
                print $q->redirect(-url => $URL . '?old_root_pass_incorrect=1'); 
                return; 
            }
        }else{ 
            
            if($DADA::Config::PROGRAM_ROOT_PASSWORD eq $q->param('old_password')){ 
                # we are good.
            } else { 
            
                print $q->redirect(-url => $URL . '?old_root_pass_incorrect=1'); 
                return; 
                
            }
        }
                               
    }
    
    if($q->param('new_password') ne $q->param('again_new_password')){ 
    
        print $q->redirect(-url => $URL . '?new_pass_no_match=1'); 
        return; 
    }
    
    
    # Well, if everything works out, we're cool. 
    my $file = $DADA::Config::CONFIG_FILE; 
    open my $CONFIG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file
    or die "Cannot read config file at: '" . $file
    . "' because: "
    . $!;
    my $config =  do { local $/; <$CONFIG> };
    close($CONFIG) or die $!; 
    
    my $qmsp = quotemeta($Start_Marker); 
    my $qmep = quotemeta($End_Marker); 
    
    require DADA::Security::Password; 
    
    my $pw = $q->param('new_password');
        
    my $root_pass = DADA::Security::Password::encrypt_passwd($pw);
    
    my $new_pass = "\n" . '$ROOT_PASS_IS_ENCRYPTED = 1; ' . "\n \n" . '$PROGRAM_ROOT_PASSWORD  = \'' . $root_pass . "'; \n"; 
    
    $config =~ s/($qmsp)(.*?)($qmep)/$Start_Marker\n$new_pass\n$End_Marker/sm; 
    
   # die $root_pass; 
    
    open my $CONFIGW, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')' , $file
    or die "Cannot write config file at: '" . $file
    . "' because: "
    . $!;
    print $CONFIGW $config or die $!; 
    close($CONFIGW) or die $!; 
    
    print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=logout&login_url='. $DADA::Config::S_PROGRAM_URL . '/' . $DADA::Config::ADMIN_FLAVOR_NAME); 
    exit;

}






sub default_screen { 

return <<EOF

<!-- tmpl_set name="title" value="Plugins &#187; Change Your <!-- tmpl_var PROGRAM_NAME --> Root Password" -->
<div id="screentitle"> 
	<div id="screentitlepadding">
		<!-- tmpl_var title --> 
	</div>
	<!-- tmpl_include help_link_widget.tmpl -->
</div>

<form method="post"> 

<!--tmpl_if old_root_pass_incorrect --> 

    <p class="error">
     You did not type in the correct, current <!-- tmpl_var PROGRAM_NAME --> Root Password. Please try again.
    </p>

<!--/tmpl_if--> 


<!-- tmpl_if new_pass_no_match --> 

    <p class="error"> 
        Your retyped new <!-- tmpl_var PROGRAM_NAME --> Root Password did not match!
    </p>

<!--/tmpl_if--> 

	<p>
	 Enter your old <!-- tmpl_var PROGRAM_NAME --> Root <label for="old_password">Password</label>:
	 <br />
	 <input type="password" id="old_password" name="old_password" maxlength="24" />
	</p>
	

<p>
 <label for="new_password">
  Enter your new <!-- tmpl_var PROGRAM_NAME --> Root Password</label>:
 <br />
 <input type="password" name="new_password" id="new_password" size="16" maxlength="24" />
</p>

<p>
 <label for="again_new_password">
  Re-enter your new <!-- tmpl_var PROGRAM_NAME --> Root Password</label>:
 <br />
 <input type="password" name="again_new_password" id="again_new_password" size="16" maxlength="24" />
</p>

<div class="buttonfloat">
 <input type="reset"  class="cautionary" />
 <input type="submit" class="processing" value="Change <!-- tmpl_var PROGRAM_NAME --> Root Password" />
</div>
<div class="floatclear"></div>

<input type="hidden" name="f"       value="change_password" />
<input type="hidden" name="process" value="true" />


</form> 

EOF
; 

}


=pod

=head1 NAME

change_root_password.cgi - B<EXPERIMENTAL> Dada Mail plugin to allow you to easily change the Dada Mail Root Password. 

=head1 VERSION

Refer to the version of Dada Mail you're using - NEVER use a version of this proggy with an earlier or later version of Dada Mail. 

=head1 USAGE

This script is a Dada Mail plugin. Once configured, you should be able to log into your list and access this plugin under the, B<Plugins> menu. 

B<Note>, that by default, this plugin can only be accessed if you log into a list using the B<Dada Mail Root Password>.

=head1 DESCRIPTION

=head1 Installation

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin manually. 

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Please Read Before Installing

Before getting into configuration of the plugin, do note that this is an B<experimental> plugin, so it is slightly awkward in a few places. Make sure you have the correct environment set up to use it. 

Here's what you'll need to have: 

=over

=item * Outside Config File (.dada_config)

Currently, this plugin only works when you do a contemporary installation of Dada Mail. Refer to the installation instructions that come with Dada Mail to understand the difference between a contemporary installation and a basic installation. If you use the installer that comes with Dada Mail, you will have a B<Contemporary Installation> of Dada Mail. 


=item * Specific Markers in the Outside Config File

This plugin very simply looks for a, B<Start Marker> and an, B<End Marker> and between these two markers should be the following variables: 

=over

=item *  $ROOT_PASS_IS_ENCRYPTED

(can either be set to 1 or 0)

=item *  $PROGRAM_ROOT_PASSWORD

=back

By default, the two markers are set in this very plugin under the variables, B<$Start_Marker> and B<$End_Marker>. So, in your C<.dada_config> file, you should have something that looks similar to this: 

 # Start Root Password
 
 $ROOT_PASS_IS_ENCRYPTED = 1; 
  
 $PROGRAM_ROOT_PASSWORD  = 'S5R8IqNB7C3cQ';  
 
 # End Root Password

If your C<.dada_config> file does not have a part of its content that looks like this, this plugin will not work. 

=back

=head2 Change permissions of "change_root_password.cgi" to 755

The, C<change_root_password.cgi> plugin will be located in your, I<dada/plugins> diretory. Change the script to, C<755>

=head2 Configure your .dada_config file

Now, edit your C<.dada_config> file, so that it shows the plugin in the left-hand menu, under the, B<Plugins> heading: 

First, see if the following lines are present in your C<.dada_config> file: 

 # start cut for list control panel menu
 =cut

 =cut
 # end cut for list control panel menu

If they are, remove them. 

Then, find these lines: 

 #					{
 #					-Title      => 'Change the Program Root Password',
 #					-Title_URL  => $PLUGIN_URL."/change_root_password.cgi",
 #					-Function   => 'change_root_password',
 #					-Activated  => 0,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{
 					-Title      => 'Change the Program Root Password',
 					-Title_URL  => $PLUGIN_URL."/change_root_password.cgi",
 					-Function   => 'change_root_password',
 					-Activated  => 0,
 					},

Save your C<.dada_config> file.


=head1 DEPENDENCIES

You'll most likely want to use the version of this plugin with the version of Dada Mail is comes with. 

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

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

