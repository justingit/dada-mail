package DADA::MailingList::Archives::PostgreSQL; 

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 

use base DADA::MailingList::Archives::baseSQL; 



sub make_table { 

	my $self = shift; 
	
	my $query = 'CREATE TABLE dada_archives (list varchar(32), archive_id varchar(32), subject text, message text, format text, raw_msg text);';
	my $sth   = $self->{dbh}->prepare($query); 
	   $sth->execute()
	   		or die "cannot do statement! $DBI::errstr\n";   
	   $sth->finish;
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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 
