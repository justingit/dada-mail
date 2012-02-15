#!/usr/bin/perl -w
use strict; 

# make sure the DADA lib is in the lib paths!
use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
	); 

# use some of those Modules
use DADA::Config 5.0.0 qw(!:DEFAULT);
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 

# we need this for cookie things
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);



my $Ver = '1.1';


# This will take care of all out security woes
my ($admin_list, $root_login) = check_list_security(-cgi_obj   => $q, 
													-Function  => 'email_list_owners');
										                
										                
my $list = $admin_list; 

#---------------------------------------------------------------------#

my @list_owners = find_list_owners(); 

my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 

 
# header     
print(admin_template_header(-Title      => "Email List Owners $Ver",
		                -List       => $li->{list},
		                -Form       => 0,
		                -Root_Login => $root_login));
	               
if(!$q->param('process')){ 
	print $q->start_form()								     .
		  $q->table({-cellpadding => 5, -border => 0}, 
		  $q->Tr(
		  $q->td({-valign => 'top'}, [
		  ($q->p("A plain text message will be sent from 
				  $li->{list_owner_email} to every other 
				  list owner")), 
		  ($q->p({-align => 'center'}, $q->b('List Owners:'), 
		   $q->br, 
		   $q->popup_menu( -size    => 5, 
						  '-values' => [@list_owners])))
		  ])))                                               .
		  $q->p($q->b('Subject: ', 
				$q->textfield(-name  => 'Subject',
							  -size  => 49)))                .
		  $q->p(
		  $q->textarea(-name => 'Body', 
					   -cols => 70, 
					   -rows => 15));
	print qq{
	
	<table align=right border=0>
	 <tr>
	  <td>
	   <input type="submit" class="cautionary"  name=process value="Send Test Message" />  
	  </td>
	  <td> 
	   <input type="submit" class="processing"  name=process value="Send Message" /> 
	  </td>
	 </tr>
	</table> 
	 <p>&nbsp;</p>
	};
	  	  
}else{ 
	require DADA::Mail::Send;
	my $mh = DADA::Mail::Send->new(
				{
					-list   => $list, 
					-ls_obj => $ls, 
				}
			);
	for my $owner(@list_owners){ 
		$mh->send(
	 		To      => $owner, 
			From    => $li->{list_owner_email},
			Subject => $q->param('Subject'),
			Body    => $q->param('Body')
		);
	}
	print $q->p($q->b('Your message has been sent to all list owners')); 
}

#footer 
print admin_template_footer(-List => $list, -Form => 0); 

sub find_list_owners {  
	my %lt;
	my @lists = DADA::App::Guts::available_lists(); 
	
	for my $ll(@lists){  
		
		warn '$ll ' . $ll; 
		
		my $t_ls = DADA::MailingList::Settings->new({-list => $ll}); 
		my $t_li = $t_ls->get; 
		
		warn $t_li->{list_owner_email}; 
		
		$lt{$t_li->{list_owner_email}} = 1;
	}
	return keys %lt;
}


#---------------------------------------------------------------------#


=pod

=head1 Plugin: email_list_owners.cgi - Email All List Owners

This plugin allows any list owner to email every other list owner. 

=head2 Installation

Upload email_list_owners.cgi into your cgi-bin. We suggest you create 
a 'plugins' directory in the same directory that the mail.cgi script 
is in. For example. If mail.cgi is at: 

 /home/account/cgi-bin/dada/mail.cgi 

create a directory called plugins at: 

  /home/account/cgi-bin/dada/plugins

and upload this script into that directory:

 /home/account/cgi-bin/dada/plugins/email_list_owners.cgi

Once uploaded in plain text or ASCII mode, chmod the script to 755.   

Add this entry to the $ADMIN_MENU array ref:

	 {-Title           => 'Email All List Owners', 
	   -Title_URL      => $PLUGIN_URL."/email_list_owners.cgi",
	   -Function       => 'email_list_owners',
	   -Activated      => 1, 
	  },

It's possible that this has already been added to $ADMIN_MENU and all
you would need to do is uncomment this entry.

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


