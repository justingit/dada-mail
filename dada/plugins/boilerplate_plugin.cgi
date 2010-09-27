#!/usr/bin/perl -w
package boilerplate; 
use strict; 

# make sure the DADA lib is in the lib paths!
use lib qw(../ ../DADA/perllib); 

# use some of those Modules
use DADA::Config 4.0.0;
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 

# we need this for cookies things
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);

run()
  unless caller();


sub run { 
	
	# This will take care of all out security woes
	my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
	                                                    -Function => 'boilerplate');
	my $list = $admin_list; 

	# get the list information
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	my $li = $ls->get; 
                             
	# header     
	print(admin_template_header(
		-Title      => "Admin Plugin Example",
	    -List       => $li->{list},
	    -Root_Login => $root_login)
	);
	               
	if(!$q->param('process')){ 

	print $q->p('I echo whatever you type in:') . 
	      $q->start_form()                                        . 
	      $q->textfield('echo')                                   . 
		  $q->hidden('process', 'true')                           .
		  $q->submit('echo away!')                                .
		  $q->end_form(); 
	}else{ 

		print $q->h1($q->escapeHTML($q->param('echo'))); 
	}

	#footer
	print admin_template_footer(
		-List => $list
	); 

}


=pod

=head1 Roll Your Own Admin Screen

This should give you a good idea on how to extend Dada Mail's admin area to do.... anything 

There is an example on how to make the actual admin screen + script, it's called 

B<boilerplate_plugin.cgi> 

and should be located in the B<dada/extras/scripts/> directory It should work right out of the box, upload it, chmod 755 it and follow the next set of directions to make it work

=head2 Adding this Module to Dada Mail

You'll need to tweak the $ADMIN_MENU variable in the Config.pm file, $ADMIN_MENU is a reference to an array of hashes of an array of hashes, or somewhere in there. 

Follow the pattern :) 

Adding this right after the last array ref entry: 

	 {-Title           => 'Boilder Plate Example', 
	   -Title_URL      => "plugins/boilerplate_plugin.cgi",
	   -Function       => 'boilerplate',
	   -Activated      => 1, 
	  },
	  
will do the trick, as long as you uploaded B<boilerplate_plugin.cgi> in the same directory as mail.cgi. It's better to give the absolute URL for these things, I think. Upload the revised Config.pm file and there should be a link for this very module. Pretty frickin cool, eh?

=cut


=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2010 Justin Simoni All rights reserved. 

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


