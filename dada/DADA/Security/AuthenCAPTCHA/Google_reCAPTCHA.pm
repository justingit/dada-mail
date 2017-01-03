package DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;
use lib qw(../../../ ../../../DADA/perllib); 
use DADA::Config qw(!:DEFAULT); 

use strict; 
use Carp qw(croak); 
use Try::Tiny; 


sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
	return $self;

}

sub _init { 
    my $self = shift; 
}

sub get_html { 
    my $self = shift; 
	my $key  = shift || $DADA::Config::RECAPTCHA_PARAMS->{public_key}; 
    return '<div class="g-recaptcha" data-sitekey="' 
	. $key 
	. '"></div>';
}

sub check_answer { 

    my $self = shift; 
    
    my (
		$remoteip,
		$response,
	) = @_; 
	
	my $result = {}; 
		
	if(!defined($response)){ 
		$result->{is_valid} = 0;
		return $result; 		
	}
	else {
		try {
			require Google::reCAPTCHA;
			my $c = Google::reCAPTCHA->new(
				secret =>  $DADA::Config::RECAPTCHA_PARAMS->{private_key},
			);
		
			# Verifying the user's response 
			my $success = $c->siteverify( 
				response => $response, 
				remoteip => $remoteip,
			);
			if( $success ) {
			    $result->{is_valid} = 1;
			}
		} catch { 
			warn "Problem with Google reCAPTCHA (v2):" . $_; 
			 $result->{is_valid} = 1;
		};
	}
    return $result;

}

1;


=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2017 Justin Simoni All rights reserved. 

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


