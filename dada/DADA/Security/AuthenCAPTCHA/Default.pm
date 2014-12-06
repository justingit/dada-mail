package DADA::Security::AuthenCAPTCHA::Default;
use lib qw(../../../ ../../../DADA/perllib); 
use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts;

# I do this, so if we don't have GD, the thing doesn't act like we do...
use GD; 
use GD::SecurityImage; 

# Needed by GD::SecurityImage
require Math::Trig; 

use strict; 


use AnyDBM_File; 
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

use base qw(DADA::App::GenericDBFile);

sub new {
	my $class = shift;
	
	my %args = (-List => undef,
				-new_list => 0,  
					@_); 
					     
    my $self = SUPER::new $class (
    							  function => 'CAPTCHA',
    							 );  
	   
	   $self->_init; 
	   return $self;
}

sub _init { 
    
    my $self = shift; 


}




sub get_html { 


    my $self = shift; 
    
    my $img_string = $self->create_CAPTCHA; 
    my $width  = $DADA::Config::GD_SECURITYIMAGE_PARAMS->{new}->{width}; 
    my $height = $DADA::Config::GD_SECURITYIMAGE_PARAMS->{new}->{height}; 
    
    return qq{
        <p>
        <img src="$DADA::Config::PROGRAM_URL/captcha_img/$img_string/" width="$width" height="$height" /><br />
    	<em>(CAPTCHA is case sensitive)</em>
    
        <!-- as far as I know, this doesn't do anythng... should it? --> 
        <input type="hidden" name="recaptcha_challenge_field" value="$img_string" /> 
        <br />
        <input type="text" name="recaptcha_response_field" value="" /> 
        </p>    
    
    }; 




}



sub create_CAPTCHA { 

    my $self          = shift; 


    require DADA::Security::Password; 
    my $secret_phrase = DADA::Security::Password::generate_rand_string($DADA::Config::GD_SECURITYIMAGE_PARAMS->{rand_string_from}, $DADA::Config::GD_SECURITYIMAGE_PARAMS->{rand_string_size});
 
    
    my $auth_string   = $self->_create_CAPTCHA_auth_string($secret_phrase); 
    $self->_open_db; 
        $self->{DB_HASH}->{$secret_phrase} = $auth_string;
    $self->_close_db; 
    
    $self->create_img($secret_phrase, $auth_string); 
    
    
    return substr($auth_string, 0, 11);
    
}


sub _dir_setup { 
	my $self = shift; 
	# Directory?
	if(-d $DADA::Config::TMP){ 
		# Write to it? 
		if(! -r $DADA::Config::TMP || ! -w $DADA::Config::TMP || ! -x $DADA::Config::TMP) { 
			chmod($DADA::Config::DIR_CHMOD , $DADA::Config::TMP)			
		}
		else { 
			# good.
		}
		my $captcha_dir = make_safer($DADA::Config::TMP . '/capcha_imgs'); 
		if(! -d $captcha_dir) { 
			mkdir ($captcha_dir, $DADA::Config::DIR_CHMOD );
			chmod($DADA::Config::DIR_CHMOD , $captcha_dir)
				if -d $captcha_dir; 
		}
		
	}
	else { 
		croak "Can't find, " . $DADA::Config::TMP; 
	}
}

sub create_img {

    my $self = shift;

    my ( $secret_phrase, $auth_string ) = @_;

    $self->_dir_setup();

    my ( $image_data, $mime_type, $random_number ) =
      $self->create_img_data( $secret_phrase, $auth_string );

    my $filename =
      make_safer( $DADA::Config::TMP
          . "/capcha_imgs/CAPTCHA-"
          . substr( $auth_string, 0, 11 )
          . '.png' );
    open my $FILE, ">", $filename or die $!;
    print $FILE $image_data or die $!;
    close($FILE) or die $!;

}


sub create_img_data {

    my $self = shift;

    my ( $secret_phrase, $auth_string ) = @_;

    # Magic!

    # Don't check if it doesn't exist...
    if ( exists( $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'new'}->{'font'} ) ) {

        if ( -e $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'new'}->{'font'} ) {

            # well, good show!
        }
        else {

            require DADA::Template::Widgets;
            my $guess = DADA::Template::Widgets::file_path(
                $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'new'}->{'font'} );

            if ($guess) {

                $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'new'}->{'font'} =
                  $guess;
            }
            else {
                warn "Cannot find the font, "
                  . $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'new'}->{'font'}
                  . " anywhere!?";
            }
        }
    }

    # Create a normal image

    my $image = GD::SecurityImage->new(
        %{ $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'new'} } );
    $image->random($secret_phrase);
    $image->create( %{ $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'create'} } );
    $image->particle(
        $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'particle'}->[0],
        $DADA::Config::GD_SECURITYIMAGE_PARAMS->{'particle'}->[1]
    );

    my ( $image_data, $mime_type, $random_number ) = $image->out;

    return ( $image_data, $mime_type, $random_number );

}

sub inline_img_data { 
	my $self = shift; 
	my ( $secret_phrase, $auth_string ) = @_;
    
    my ( $image_data, $mime_type, $random_number ) =
      $self->create_img_data( $secret_phrase, $auth_string );

	require MIME::Base64; 
	my $encoded = MIME::Base64::encode_base64($image_data);
	return 'data:image/' . $mime_type. ';base64,' . $encoded; 
	
}


sub remove_CAPTCHA { 

    my $self  = shift; 
    my $state = shift; 
    
    $self->_open_db; 
    $self->{DB_HASH}->{$state} = undef;
    delete($self->{DB_HASH}->{$state});
    $self->_close_db; 
}




sub check_CAPTCHA {

    my $self  = shift; 
    
    my $challenge = shift; 
    
    my $response = shift;
    
    my $auth  = 0; 
    $self->_open_db; 
    
    if(exists($self->{DB_HASH}->{$response})){ 
        
        my $auth_string = $self->_create_CAPTCHA_auth_string($response);
        
        if(
           ($self->{DB_HASH}->{$response} eq $auth_string) && 
           ($challenge                    eq substr($auth_string, 0, 11)) 
           ){ 
        
             $self->_close_db; 
             $self->remove_CAPTCHA($response); 
             
            
             return 1; 

        } else { 
             
             $self->_close_db; 
             #$self->remove_CAPTCHA($response); 

            return 0; 
        }
    
    } else { 
        return 0; 
    }
 
   

}

sub check_answer { 

    my $self = shift; 
    
    my ($private_key, $remote_address, $captcha_challenge_field, $recaptcha_response_field) = @_; 
    
    my $result = {}; 
    
    $result->{is_valid} = $self->check_CAPTCHA($captcha_challenge_field, $recaptcha_response_field); 

    return $result; 
}






sub _create_CAPTCHA_auth_string { 

	my $self = shift; 
	my $auth_string = shift; 
	
    require Digest::MD5; # Reminder: Ship with Digest::Perl::MD5....
    
#    if($] >= 5.008){
 #       require Encode;
 #       my $cs = Digest::MD5::md5_hex(safely_encode($$auth_string));
 #       return $cs;
 #   }else{ 			
        my $cs = Digest::MD5::md5_hex($auth_string);
        return $cs;
 #   }

   
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


