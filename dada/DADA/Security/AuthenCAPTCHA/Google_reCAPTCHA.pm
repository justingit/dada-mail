package DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;
use lib qw(../../../ ../../../DADA/perllib); 
use DADA::Config qw(!:DEFAULT); 

use strict; 
use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT 
O_CREAT 
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB); 
use Carp qw(croak); 


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
	my $key  = shift; 
    return '<div class="g-recaptcha" data-sitekey="' 
	. $key 
	. '"></div>';
}

sub check_answer { 

    my $self = shift; 
    
    my ($private_key, $captcha_challenge_field, $recaptcha_response_field) = @_; 
		
	use Google::reCAPTCHA;
	my $c = Google::reCAPTCHA->new(
		secret => $private_key
	);
 
	# Verifying the user's response 
	my $success = $c->siteverify( 
		response => $recaptcha_response_field, 
		remoteip => $ENV{REMOTE_ADDR},
	);
 
 	my $result = {}; 
	if( $success ) {
	    $result->{is_valid} = 1;
	}

    return $result;

}

1;


=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2016 Justin Simoni All rights reserved. 

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


