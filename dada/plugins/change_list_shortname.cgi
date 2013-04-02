#!/usr/bin/perl
package change_list_shortname;
use strict;

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";
use lib "$FindBin::Bin/../../../../perllib";
use lib "$FindBin::Bin/../../../../perl";

# use some of those Modules
use DADA::Config 6.0.0;
use DADA::Template::HTML;
use DADA::App::Guts;
use DADA::MailingList::Settings;

# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);

use CGI::Carp qw(fatalsToBrowser);

use Carp qw(croak carp); 


use Fcntl qw(
	LOCK_SH
	O_RDONLY
	O_CREAT
	LOCK_EX
);


my $admin_list; 
my $root_login; 
my $list; 
my $ls; 

my $Plugin_Config                = {}; 
   $Plugin_Config->{Plugin_Name} = 'Change List Shortname'; 
   $Plugin_Config->{Plugin_URL}  = self_url(); 


&init_vars; 

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{change_list_shortname}->{$key} ) ) {

            if ( defined( $DADA::Config::PLUGIN_CONFIGS->{change_list_shortname}->{$key} ) ) {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{change_list_shortname}->{$key};

            }
        }
    }
}

run()
  unless caller();

sub _init { 
	( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'change_list_shortname'
    );

	$list = $admin_list;
}

sub run {

	_init(); 

	my $flavor = $q->param('flavor') || 'cgi_default';
	$ls = DADA::MailingList::Settings->new({-list => $list}); 	

	my %Mode = (
		'cgi_default'                  => \&cgi_default,
		'verify_change_list_shortname' => \&verify_change_list_shortname, 
		'change_list_shortname'        => \&change_list_shortname, 

	);

	if ( exists( $Mode{$flavor} ) ) {
		$Mode{$flavor}->();    #call the correct subroutine
	}
	else {
		&cgi_default;
	}
}


sub test_sub { 
	return 'Hello, World!'; 
}




sub cgi_default { 
	
	if($DADA::Config::SUBSCRIBER_DB_TYPE !~ /SQL/i){ 
		sql_backend_only_message(); 
		return; 
	}
	
	
    require DADA::Template::Widgets;
	require DADA::MailingList::Settings; 
	
     my $scrn = DADA::Template::Widgets::wrap_screen(
         {
             -screen         => 'plugins/change_list_shortname/default.tmpl',
             -with           => 'admin',
			 -expr           => 1, 
             -wrapper_params => {
                 -Root_Login => $root_login,
                 -List       => $list,
             },
             -vars => {
				Plugin_URL => $Plugin_Config->{Plugin_URL}, 
			},
			-list_settings_vars_param => { 
				-list                 => $list,
				-dot_it               => 1,
			},

         }
     );
     e_print($scrn);
}

sub sql_backend_only_message { 
	my $tmpl = q{ 
		<!-- tmpl_set name="title" value="Plugins &#187; Change List Shortname" --> 
		<div id="screentitle"> 
			<div id="screentitlepadding">
				<!-- tmpl_var title --> 
			</div>
			<!-- tmpl_include help_link_widget.tmpl -->
		</div>
		
		<h1>Sorry,</h1>
		<p>This plugin will only work, if you have installed and configured Dada Mail to use one of the SQL backends.</p>
	};
	
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $ls->param('list'),
            },, 
            -vars => {
            },

            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );	
	e_print($scrn);
}




sub verify_change_list_shortname {
    my $new_name = strip( xss_filter( $q->param('new_name') ) );
    my ( $errors, $flags ) = check_list_setup(
        -fields => {
            list             => $new_name,
        },
    );
	# reset this, as we don't care about all the errors, but: 

	$errors = 0;
	my $change_list_name_errors = {};
#	use Data::Dumper; 
#	die Dumper($flags); 
	
	for(qw(
		list
		list_exists
		shortname_too_long
		slashes_in_name
		weird_characters
		quotes
	)){ 
		if($flags->{$_} == 1){ 
			$change_list_name_errors->{'flags_' . $_} = 1;
			$errors++; 
			
		}
	}
	
	
    require DADA::Template::Widgets;
	
     my $scrn = DADA::Template::Widgets::screen(
         {
             -screen         => 'plugins/change_list_shortname/verify.tmpl',
  			 -expr           => 1, 
             -vars => {
				Plugin_URL => $Plugin_Config->{Plugin_URL}, 
				errors     => $errors, 
				new_name   => $new_name, 
				%{$change_list_name_errors}, 

			},
			-list_settings_vars_param => { 
				-list                 => $list,
				-dot_it               => 1,
			},

         }
     );
	print $q->header(); 
     e_print($scrn);
}



sub change_list_shortname { 

my $new_name = strip(xss_filter($q->param('new_name'))); 
my %p = %DADA::Config::SQL_PARAMS; 


#subscriber_table                  
#profile_table         				# no update needed.            
#profile_fields_table 	          	# no update needed.
#profile_fields_attributes_table    # no update needed.
#archives_table                    
#settings_table                    
#session_table                     # no update needed.
#bounce_scores_table               
#clickthrough_urls_table           # no update needed.
#clickthrough_url_log_table        
#mass_mailing_event_log_table      
#password_protect_directories_table


my $query_string = 
"UPDATE  $p{subscriber_table} SET list = ? WHERE list = ?;
UPDATE  $p{archives_table} SET list = ? WHERE list = ?; 	
UPDATE  $p{settings_table} SET list = ? WHERE list = ?; 
UPDATE  $p{settings_table} SET value = ? WHERE value = ? and setting = 'list';
UPDATE  $p{bounce_scores_table} SET list = ? WHERE list = ?; 
UPDATE  $p{clickthrough_url_log_table} SET list = ? WHERE list = ?; 
UPDATE  $p{mass_mailing_event_log_table} SET list = ? WHERE list = ?; 
UPDATE  $p{password_protect_directories_table} SET list = ? WHERE list = ?";

my @queries = split("\n", $query_string); 

require DADA::App::DBIHandle; 
my $dbi_obj = DADA::App::DBIHandle->new; 
my $dbh     = $dbi_obj->dbh_obj;


foreach my $query(@queries){ 
	my $sth = $dbh->prepare($query);
    my $rv =
      $sth->execute($new_name, $list)
      or croak "cannot do statement! $DBI::errstr\n";
}

require DADA::App::ScreenCache; 
my $c = DADA::App::ScreenCache->new; 
   $c->flush;


print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=logout&login_url='. $DADA::Config::S_PROGRAM_URL . '?f=' . $DADA::Config::ADMIN_FLAVOR_NAME); 

}


sub self_url { 
	my $self_url = $q->url; 
	if($self_url eq 'http://' . $ENV{HTTP_HOST}){ 
			$self_url = $ENV{SCRIPT_URI};
	}
	return $self_url; 	
}


=pod

=head1 Plugin: change_list_shortname.cgi - Change your mailing list's Short Name

Your mailing list's, B<Short Name> is what Dada Mail uses as a unique identifier internally to tell your mailing list apart from every other mailing list. This Short Name is picked out, when you create your mailing list. Although used internally, you may also see it in the various query strings Dada Mail sets for navigation and email confirmations. 

Because of this public view, or an otherwise internal name, you may want to I<change> the List Short Name. Perhaps you picked out a really bad Short Name like, B<temporarytest> or B<listthree> and you've found that your mailing list isn't so temporary, or it's the only mailing list you have, instead of being in a series. 

This plugin allows you to change your List Short Name

=head2 CAVEATS

There's some major caveats when using this plugin, that you want to be aware of, before using it to change your List Short Name

=head3 SQL backend-only

This plugin only works if you are using one of the SQL backends: B<MySQL>, B<PostgreSQL>, or B<SQLite>. It will not work with the B<Default> backend. 

=head3 Always make a backup of your complete database

We encourage you to make a backup of your complete SQL database, before using this plugin. Although checks are made to verify there won't be any problems with using a new List Short Name for a current mailing list, we still want you to err on the side of caution. 

=head3 Text Logs are not processed

This plugin works by changing the List Short Name found in the various tables in your SQL database that makes up your Dada Mail Mailing Lists. Text Logs, such as your error log or usage log are not touched. 

=head3 Potential Susbcription Form/Link Breakage

Any current static Subscription forms, and any subscription/unsubscription links embedded in already sent email messages will most likely B<break>, once you've changed your List Short Name. You will potentially need to update the Subscription forms located on your website, but there's nothing you can do with the links in any sent email messages. 


=head1 Installation 

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin manually.

=head2 Change permissions of "change_list_shortname.cgi" to 755

The, C<change_list_shortname.cgi> plugin will be located in your, I<dada/plugins> diretory. Change the script to, C<755>

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
 #					-Title      => 'Change Your List Short Name',
 #					-Title_URL  => $PLUGIN_URL."/change_list_shortname.cgi",
 #					-Function   => 'change_list_shortname',
 #					-Activated  => 0,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{
 					-Title      => 'Change Your List Short Name',
 					-Title_URL  => $PLUGIN_URL."/change_list_shortname.cgi",
 					-Function   => 'change_list_shortname',
 					-Activated  => 0,
 					},

Save your C<.dada_config> file.

You can now log into your List Control Panel (make sure to log in with the B<Dada Mail Root Password>) and under the, B<plugins> heading you should now see a linked entitled, "Change Your List Short Name". Clicking that link will bring you to this plugin. 

=head1 COPYRIGHT 

Copyright (c) 1999 - 2013 

Justin Simoni

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



