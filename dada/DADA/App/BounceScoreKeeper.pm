package DADA::App::BounceScoreKeeper; 
use strict; 

use lib qw(../../ ../../perllib); 

use DADA::Config; 	

my $type; 
BEGIN { 
	
	$type = $DADA::Config::BOUNCE_SCORECARD_DB_TYPE;
	if($type eq 'SQL'){ 
		$type = 'baseSQL'; 
	}
}
use base "DADA::App::BounceScoreKeeper::$type";




sub _init  { 
    my ($self, $args) = @_; 
    if($self->{new_list} != 1){ 
    	croak('BAD List name "' . $args->{-List} . '" ' . $!) if $self->_list_name_check($args->{-List}) == 0; 
	}else{ 
		$self->{name} = $args->{-List}; 
	}
	
	return $self;
}




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



1;
