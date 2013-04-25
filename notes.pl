#!/usr/bin/perl 

# Can HTML::Template turn strings into MD5 hashes? That would help.
# Although I may just have to write a filter for this... 


use lib qw(/Users/justin/Documents/DadaMail/git/dada-mail/dada/DADA/perllib); 

my $mid   = '20098784949494'; 
my $c_key = 'iuq?gW=9Ohh6B7aaFyx@j+TXrMa_taacr?tX?Y9~'; 
my $list = 'foo'; 
my $addr = 'blahblahblah@bar.com'; 

my $stuff = $mid . '.' . $list . ' . ' . $addr; 
my $md5   = md5hash(\$stuff); 
print 'md5: ' . $md5 . "\n"; 
my $c_e  = cipher_encrypt($c_key, $md5); 
my $begin_uu = "begin 644 uuencode.uu\n";
my $end_uu   =  "`\nend\n";
print 'c_e "' . $c_e . "\"\n"; 
#This'll have some new lines. Ugh. 
$c_e =~ s/^$begin_uu//; 
$c_e =~ s/$end_uu$//;
$c_e =~ s/\n/\\n/g; 
print $c_e; 
my $hexed = hexit($c_e);

print '$hexed  ' . $hexed ;
#print 'md5 ' . $md5; 
print "\n"; 

my $d = $hexed;  
   $d = perl_dechex($d);
$d = $begin_uu . $d . $end_uu; 
$d = cipher_decrypt($c_key,$d); 

#print $d; 
if(md5hash(\$stuff) eq $d){ 
#	print "yes, it all worked!";
}
else { 
#	print "DRRRRRR!"; 
}



#print anony_star_address($addr); 
#	my $r =  generate_rand_string() . "\n"; 
#	print md5hash(\$r) . "\n"; 



sub anony_star_address { 	
	my $str = shift; 
	my ($n, $d) = split('@', $str); 
	if(length($n) == 1){ 
		return '*@'. $d; 
	} 
	else { 
		return substr($n, 0,1) . '*' x (length($n) -1)  . '@' . $d;  
	}
}




sub md5hash { 

	my $data = shift; 
	
	use Digest::MD5 qw(md5_hex);
	
	if($] >= 5.008){
		require Encode;
		#my $cs = md5_hex(safely_encode($$data));
		my $cs = md5_hex($$data);
		return $cs;
	}else{ 			
		my $cs = md5_hex($$data);
		return $cs;
	}
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

sub hexit { 
	my $s = shift; 
	$s =~ s/(.)/sprintf("%X",ord($1))/eg;
	return $s; 
}

sub perl_dechex { 
	my $s = shift; 
	$s =~ s/([a-fA-F0-9][a-fA-F0-9])/chr(hex($1))/eg;
	return $s; 
}
