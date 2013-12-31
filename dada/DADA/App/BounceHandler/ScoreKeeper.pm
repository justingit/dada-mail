package DADA::App::BounceHandler::ScoreKeeper; 
use strict; 

use lib qw(../../../ ../../../perllib); 

use DADA::Config; 	

use Carp qw(carp croak); 

my $type; 
BEGIN { 
	
	$type = $DADA::Config::BOUNCE_SCORECARD_DB_TYPE;
	if($type eq 'SQL'){ 
		$type = 'baseSQL'; 
	}
}
use base "DADA::App::BounceHandler::ScoreKeeper::$type";




sub _init  { 
    my $self   = shift; 
	my ($args) = @_; 
	
    if($self->{new_list} != 1){ 
		if($self->_list_name_check($args->{-list}) == 0) { 
			croak('BAD List name "' . $args->{-list} . '" ' . $!); 
		}
		else { 
			$self->{list} = $args->{-list}; 			
		}
	}else{ 
		$self->{list} = $args->{-list}; 
	}
	
	require DADA::MailingList::Settings; 
	$self->{ls} = DADA::MailingList::Settings->new({-list => $self->{list}}); 
	
	
	return $self;
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
