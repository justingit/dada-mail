#!/usr/bin/perl -w
package default_mass_mailing_messages;
use strict;

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";

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
my $pt_fn; 
my $html_fn; 

my $Plugin_Config                = {}; 
   $Plugin_Config->{Plugin_Name} = 'Password Protect Directories'; 
   $Plugin_Config->{Plugin_URL}  = $q->url; 


&init_vars; 

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{default_mass_mailing_messages}->{$key} ) ) {

            if ( defined( $DADA::Config::PLUGIN_CONFIGS->{default_mass_mailing_messages}->{$key} ) ) {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{default_mass_mailing_messages}->{$key};

            }
        }
    }
}

run()
  unless caller();

sub _init { 
	( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'default_mass_mailing_messages'
    );

	$list = $admin_list;
	$pt_fn = $DADA::Config::TEMPLATES . '/' . 'default_plaintext_message_content' . '-' . $list . '.txt';
	$html_fn = $DADA::Config::TEMPLATES . '/' . 'default_html_message_content' . '-' . $list . '.html';
	
}

sub run {

	_init(); 

	my $flavor = $q->param('flavor') || 'cgi_default';

	my %Mode = (
		'cgi_default'                => \&cgi_default,
		'save_params'                => \&save_params, 
		'view_file'                  => \&view_file, 
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
	
    require DADA::Template::Widgets;
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 	
	
	my $done        = $q->param('done')        || undef; 
	my $pt_return   = 1; 
	my $html_return = 1; 
	if($done){ 
		$pt_return   = $q->param('pt_return')   || undef; 
		$html_return = $q->param('html_return') || undef; 
	}
	
	my $default_plaintext_message_content_data = ''; 
	if(-e $pt_fn){ 
		eval { $default_plaintext_message_content_data = slurp($pt_fn); };
	} 
	my $default_html_message_content_data = ''; 
	if(-e $html_fn){ 
		eval { $default_html_message_content_data = slurp($html_fn); };
	}


	my $plaintext_message_source_isa_url  = isa_url($ls->param('default_plaintext_message_content_src_url_or_path'));
	my $plaintext_message_source_isa_file = 0; 
	my $problems_fetching_plaintext_url   = 0; 
	my $problems_opening_plaintext_file   = 0;
	if(length($ls->param('default_plaintext_message_content_src_url_or_path')) > 0 && $plaintext_message_source_isa_url != 1){ 
		$plaintext_message_source_isa_file = 1;
	}
	if(length($ls->param('default_plaintext_message_content_src_url_or_path')) > 0){ 
		if($plaintext_message_source_isa_url == 1){ 
			if(! grab_url($ls->param('default_plaintext_message_content_src_url_or_path'))){ 
				$problems_fetching_plaintext_url = 1; 
			}
		}
		elsif($plaintext_message_source_isa_file == 1) { 
			if(! -e $ls->param('default_plaintext_message_content_src_url_or_path')){ 
				$problems_opening_plaintext_file = 1; 
			}
		}
	}
	# DEV: This is exact copy/paste job of the above. Not good. 
	my $html_message_source_isa_url  = isa_url($ls->param('default_html_message_content_src_url_or_path'));
	my $html_message_source_isa_file = 0; 
	my $problems_fetching_html_url   = 0; 
	my $problems_opening_html_file   = 0;
	if(length($ls->param('default_html_message_content_src_url_or_path')) > 0 && $html_message_source_isa_url != 1){ 
		$html_message_source_isa_file = 1;
	}
	if(length($ls->param('default_html_message_content_src_url_or_path')) > 0){ 
		if($html_message_source_isa_url == 1){ 
			if(! grab_url($ls->param('default_html_message_content_src_url_or_path'))){ 
				$problems_fetching_html_url = 1; 
			}
		}
		elsif($html_message_source_isa_file == 1) { 
			if(! -e $ls->param('default_html_message_content_src_url_or_path')){ 
				$problems_opening_html_file = 1; 
			}
		}
	}
	
     my $scrn = DADA::Template::Widgets::wrap_screen(
         {
             -screen         => 'plugins/default_mass_mailing_messages/default.tmpl',
             -with           => 'admin',
			 -expr           => 1, 
             -wrapper_params => {
                 -Root_Login => $root_login,
                 -List       => $list,
             },
             -vars => {
				Plugin_URL => $q->url, 
				default_plaintext_message_content_data => $default_plaintext_message_content_data, 
				default_html_message_content_data      => $default_html_message_content_data, 
				plaintext_message_source_isa_url       => $plaintext_message_source_isa_url,
				plaintext_message_source_isa_file      => $plaintext_message_source_isa_file, 
				problems_fetching_plaintext_url        => $problems_fetching_plaintext_url, 
			    problems_opening_plaintext_file        => $problems_opening_plaintext_file, 

				default_html_message_content_data      => $default_html_message_content_data, 
				default_html_message_content_data      => $default_html_message_content_data, 
				html_message_source_isa_url            => $html_message_source_isa_url,
				html_message_source_isa_file           => $html_message_source_isa_file, 
				problems_fetching_html_url             => $problems_fetching_html_url, 
				problems_opening_html_file             => $problems_opening_html_file, 
				
				done                                   => $done, 
				pt_return                              => $pt_return, 
				html_return                            => $html_return, 
			},
			-list_settings_vars_param => { 
				-list                 => $list,
				-dot_it               => 1,
			},

         }
     );
     e_print($scrn);
}

sub save_params { 
	
	my $default_plaintext_message_content_data = $q->param('default_plaintext_message_content_data'); 
	my $default_html_message_content_data      = $q->param('default_html_message_content_data'); 
       
       $default_plaintext_message_content_data =~ s/\r\n/\n/g; 
       $default_html_message_content_data      =~ s/\r\n/\n/g;

	my $pt_return   = 1; 
	my $html_return = 1; 
	if(length($default_plaintext_message_content_data) > 0){ 
		$pt_return = save_file($pt_fn, $default_plaintext_message_content_data); 
	}
	if(length($default_html_message_content_data) > 0){ 
		$html_return = save_file($html_fn, $default_html_message_content_data); 
	}
	
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 	
	$ls->save_w_params(
		{
			-associate => $q, 
			-settings  => { 
				default_plaintext_message_content_src             => undef, 
				default_plaintext_message_content_src_url_or_path => undef, 
				default_html_message_content_src                  => undef, 
				default_html_message_content_src_url_or_path      => undef, 
			}
		}
	);
	print $q->redirect($q->url . '?done=1;pt_return=' . $pt_return . ';html_return=' . $html_return); 
}

sub save_file { 
	my $fn = shift; 
	my $data = shift; 
	$fn = make_safer($fn);
	eval { 
		open(TEMPLATE, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $fn) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't write file $fn': $!"; 
		flock(TEMPLATE, LOCK_EX) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't lock to write new file at '$fn': $!" ; 
		print TEMPLATE $data;
		close(TEMPLATE); 
	    chmod($DADA::Config::FILE_CHMOD , $fn); 
	};
	
	if($@){ 
		return 0; 
	}
	else { 
		return 1; 
	}

}

sub view_file { 
	my $fn = xss_filter($q->param('fn')); 
	my $data = undef; 
	print $q->header(); 
	
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 	
	if($fn eq 'default_plaintext_message_content_src_url_or_path' || $fn eq 'default_html_message_content_src_url_or_path') { 
		$data = slurp($ls->param($fn));
		e_print($q->pre(encode_html_entities($data))); 
	}
	else { 
		croak('sorry I cannot show, ' . $fn);
	}
	
}


=pod

=head1 Plugin: default_mass_mailing_messages.cgi - Set Default Mass Mailing Messages

This plugin allows you to set default message copy in the, "Send a Message" and "Send a Webpage" screens. This copy can be 
loaded with dummy/placeholder text to be used as a starting point for a new mailing list message.

This copy can reside outside of the program at a different file location or URL, or can be inputted directly into the plugin itself.

=head1 Installation 

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin manually.

=head2 Change permissions of "default_mass_mailing_messages.cgi" to 755

The, C<default_mass_mailing_messages.cgi> plugin will be located in your, I<dada/plugins> diretory. Change the script to, C<755>

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
 #					-Title      => 'Default Mass Mailing Messages',
 #					-Title_URL  => $PLUGIN_URL."/default_mass_mailing_messages.cgi",
 #					-Function   => 'default_mass_mailing_messages',
 #					-Activated  => 1,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{
 					-Title      => 'Default Mass Mailing Messages',
 					-Title_URL  => $PLUGIN_URL."/default_mass_mailing_messages.cgi",
 					-Function   => 'default_mass_mailing_messages',
 					-Activated  => 1,
 					},

Save your C<.dada_config> file.

=head1 Default Text and CKeditor/Tiny MCE/FCKeditor

Setting default text/copy for the HTML message will work when using one of the WYSIWYG editors that Dada Mail 
supports. Some guidelines: 

=over

=item * Template Tags

Be careful with using Dada Mail-style template tags, like this, 

	<!-- tmpl_var im_a_tag -->

I<Especially within links>. These tags will mostly be broken. Try instead to use old-style Dada Mail tags for
the time being: 

	[im_a_tag]

=item * Full HTML documents

Full HTML documents, like so: 

	<html> 
	 <head>
	  <title></title>
	 </head>
	 <body> 
	  I'm the body!
	 </body> 
	</html> 

May have everything, except the content in the body removed by CKeditor/Tiny MCE/FCKeditor. That may mean that any styles 
that are saved in the head of the document will be lost. 

=back


=head1 COPYRIGHT 

Copyright (c) 1999 - 2012 

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



