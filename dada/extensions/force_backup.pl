#!/usr/bin/perl -w
use strict;  
use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);

use CGI::Carp "fatalsToBrowser";


use DADA::Config 3.0.0 qw(!:DEFAULT);

use DADA::MailingList::Settings;
use DADA::MailingList::Archives;  
use DADA::App::Guts;  

use CGI;
my @lists = DADA::App::Guts::available_lists();
foreach(@lists)
{  
    my $ls = DADA::MailingList::Settings->new({-list => $_});  
    my $la = DADA::MailingList::Archives->new({-list => $ls->get}); 
 	# DEV: Should we put Schedules here, as well?
    $ls->backupToDir;  
    $la->backupToDir;
}

my $q = new CGI;  
$q->charset($DADA::Config::HTML_CHARSET);

print $q->header();
print $q->h1('All lists are now backed up.'); 



=pod

=head1 COPYRIGHT 

Copyright (c) 1999-2008 Justin Simoni All rights reserved. 

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
