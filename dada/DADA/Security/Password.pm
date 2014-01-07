package DADA::Security::Password;

use strict; 

use lib qw(./ ../ ../perllib ../../ ../../perllib); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts;

require Exporter; 

use vars qw(@ISA @EXPORT); 


@ISA = qw(Exporter);

@EXPORT = qw(
check_password
encrypt_passwd
generate_password
rot13
);

=pod

=head1 NAME

DADA::Security::Password

=head1 SYNOPSIS

	use DADA::Security::Password 

Simple password checking, encrypting and generating for Dada Mail passwords,
 saved primarily in the List DB.

=head1 DESCRIPTION

Please note that I am not in any way a master or even a student of cryptology, 
for the most part, I'm using tried and true methods of encryption and taking the 
necessary precautions when I can. I don't think you should be using Dada Mail for 
International Trade Secrets. No, no. No. No. No. No. No.

Remember that an encryption scheme that uses a password is only as good as the password
used with it. Please, do not use 'dada' as your passwrd. 

Many, if not all of these subroutines can be repurpused for other projects, 
any variables that don't seem to be here are in the Config.pm file, no really, check it out. 

=head1 SUBROUTINES 

=head2 checkpassword

	my $pwcheck = ($encrupted_pass, $unencrypted_pass);

This subroutine checks to see if a encrypted password matches an unencrypted password. 
Passwords are first encrypted using your systems's crypt() function, the same one probably 
used for Apache Server Protected Directories and Hosting Directories themselves. The idea is
the only way to compare a password given to the saved, encrypted password, is to encrypted the 
given password, and then check out if they match. 

This function returns 1 if the passwords  match. 

=cut


sub check_password {
#############################################################################
   # dada utility <+>  $password_check  <+>  checks password                   #
#############################################################################

    my $check = 0;
    my ( $epw, $pw ) = @_;

    my $tmp_salt =
      substr( $epw, $DADA::Config::FIRST_SUB, $DADA::Config::SEC_SUB );
    if ( $epw eq crypt( safely_encode($pw), $tmp_salt ) ) {
        $check = 1;
    }

    return $check;

}


=pod

=head2 encrypt_passwd

	my $enc_pass = encrypt_passwd($string);

Encrypts a string using crypt(). The salt number is created within the Config.pm file, 
every time its executed, so salt numbers are always pretty random. the encrypted password is 
made from the first 8 characters you give it, regardless of how long your password is. 

The password that's created can only be successfully cracked using 'Brute Force' -
trying every freakin combo available. That means the more random your password, the better 
it'll be.    


=cut

sub encrypt_passwd {
    my $pw = shift;
    return crypt( safely_encode($pw), $DADA::Config::SALT );
}


=pod

=head2 generate_password

my $new_pass = generate_password(); 

creates a new, user-unfriendly password, full of numbers and funky symbols (all printable) 
this is primarily used when someone forgets their password and a new one needs to be made. 


=cut


sub generate_password { 
my @chars = split '',
'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789@#$%&*=+_<>?~';
 
 my $password;
      for(1..8){
      $password .= $chars[rand @chars];
         }
      return $password; 
      
 }


sub generate_rand_string { 

my $chars = shift || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
my $num   = shift || 8;
   
my @chars = split '', $chars;
 my $password;
      for(1..$num){
      $password .= $chars[rand @chars];
         }
      return $password; 
 }
 

sub cipher_encrypt {
	
    my ( $key, $str ) = @_;
    require Crypt::CipherSaber;
    my $cs = Crypt::CipherSaber->new($key);

    # New Behavior:
    require Convert::UU;
    return Convert::UU::uuencode( $cs->encrypt($str) );

    # Old Behavior:
    #return $cs->encrypt($str);

}

sub cipher_decrypt {

    my ( $key, $str ) = @_;
    require Crypt::CipherSaber;
    my $cs = Crypt::CipherSaber->new($key);

    # New Behavior:
    require Convert::UU;
    return $cs->decrypt( Convert::UU::uudecode($str) );

    # Old Behavior:
    #return $cs->decrypt($str);

}

sub make_cipher_key { 
	my $key; 
	for(0..4){ 
		$key .= generate_password();
	}
	return $key;
}


=pod

=head2 rot13

	my $rotpass = rot13($string);

encrypts a string, using rot13. 

B<PLEASE BEWARE> rot13 encrytpion is not very secure at all, you can decrypt it by hand. 
No, really. That's almost what it's used for. For now, its used to keep paswords that are
saved in a cooke I<somewhat> secure, like secure in passerbys or someone looking over your shoulder. 

but anyways, its a nice little thing if you ever want to rot13 a message for sending, eh? 

=cut


 sub rot13 { 

# crappy CRAPPY (but simple) encryption
my $val = shift; 
$val =~ tr/a-zA-Z/n-za-mN-ZA-M/;
return $val; 

} 



=pod
 
=head1 COPYRIGHT

Copyright (c) 1999 - 2014 Justin Simoni 
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
