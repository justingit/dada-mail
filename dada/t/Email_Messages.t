#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


my %test_message = (
        To      => 'justin@example.com', 
        From    => 'from@example.com', 
        Subject => 'heya', 
        Body    => 'what is up?', 
); 


use Test::More qw(no_plan);
use dada_test_config; 




my $list = dada_test_config::create_test_list;

use DADA::App::Guts; 

use DADA::MailingList::Settings; 
use DADA::Mail::Send; 
use DADA::Config;

# close ( STDERR ); 



my $ls = DADA::MailingList::Settings->new({-list => $list}); 

# I'm going to make this implicit, just in case there's a whacky default made: 

$ls->save(
    {
    sending_method => 'sendmail',     
    }
);


my $li = $ls->get; 



ok($ls->isa('DADA::MailingList::Settings'), "name list isa DADA::MailingList::Settings!"); 

use MIME::Parser;
use MIME::Entity; 

my $parser = new MIME::Parser; 
   $parser = optimize_mime_parser($parser); 


 
my $mh = DADA::Mail::Send->new({-list => $list});



# Make sure my casing is correct..
my %dirty = ('Content-Type' => 'text/html', 'Content-transfer-encoding' => 'utf-8'); 
my %clean = $mh->clean_headers(%dirty); 
ok($clean{'Content-type'} eq 'text/html'); 
ok(! exists($clean{'Content-Type'})); 

ok($clean{'Content-Transfer-Encoding'} eq 'utf-8'); 
ok(! exists($clean{'Content-transfer-encoding'})); 

my %dirty2 = ('Content-type' => 'text/html', 'Content-Transfer-Encoding' => 'utf-8'); 
my %clean2 = $mh->clean_headers(%dirty2); 
ok($clean2{'Content-type'} eq 'text/html'); 
ok(! exists($clean{'Content-Type'})); 

ok($clean{'Content-Transfer-Encoding'} eq 'utf-8'); 
ok(! exists($clean{'Content-transfer-encoding'})); 


   $mh->test(1); 
	
diag q{$mh->test_send_file } . $mh->test_send_file; 
 
   $mh->send(%test_message);

diag "sent test!"; 

my $entity; 
   $entity = $parser->parse_open($mh->test_send_file()); 
   


for my $header(qw(To From Subject)){ 
    
    my $sv = $entity->head->get($header, 0);
    chomp $sv;
    ok($sv      eq $test_message{$header}); 
}


unlink($mh->test_send_file); 
undef($mh); 
undef $entity; 





for(keys %DADA::Config::PRIORITIES){ 
    
    next if $_ eq 'none';
    
    $ls->save({priority => $_}); 
    undef $li;
    my $li = $ls->get; 
    
    my $mh = DADA::Mail::Send->new({-list => $list});
       $mh->test(1);
	   $mh->send(%test_message);
    
    my $entity; 
       $entity = $parser->parse_open($mh->test_send_file); 
    
    my $precedence = $entity->head->get('X-Priority', 0);
    chomp($precedence); 
    
    ok($precedence eq $_); 

	ok(unlink($mh->test_send_file)); 
}




my @content_types = qw(text/plain text/html);
for my $content_type(@content_types){ 

    for my $encoding(@DADA::Config::CONTENT_TRANSFER_ENCODINGS){ 
        
        if($content_type =~ m/html/i){ 
        
            $ls->save({html_encoding => $encoding}); 
        } 
        else {
            
            $ls->save({plaintext_encoding => $encoding});     
        }
        
        undef $li;
        my $li = $ls->get; 
        
        my $mh = DADA::Mail::Send->new({-list => $list});
           $mh->test(1);
		   $mh->send(%test_message, 'Content-type' => $content_type);
        
        my $entity; 
           $entity = $parser->parse_open($mh->test_send_file); 
        
		#print $entity->as_string; 
		
		
        my $cte = $entity->head->get('Content-Transfer-Encoding', 0);
        chomp($cte); 
        
        ok($cte eq $encoding, "$cte is equal to $encoding for $content_type messages. (Content-Transfer-Encoding test)"); 
        
        my $ct = $entity->head->get('Content-type', 0);
        chomp($ct);

    
        ok($ct =~ m{$content_type}, "$ct equals $content_type matches what we gave it..."); 
    
		ok(unlink($mh->test_send_file)); 
		
    }

}






for my $charset(@DADA::Config::CHARSETS){
    
    my ($label, $value) = split("\t", $charset, 2); 
    
    $ls->save({charset => $charset}); 
    undef $li;
    my $li = $ls->get; 
    
    my $mh = DADA::Mail::Send->new({-list => $list});
	   $mh->test(1);
       $mh->send(%test_message);
    
    my $entity; 
       $entity = $parser->parse_open($mh->test_send_file); 
    
      my $cs = $entity->head->get('Content-type', 0);
        chomp($cs);
        
        like($cs, qr/$value/, "$cs equals $value which what we gave it ($charset) (charset check)"); 
		
		ok(unlink($mh->test_send_file)); 
}



# Test to make sure the Date: header is being set...
# [ 1654669 ] 2.10.12 - No Date: header set in outgoing emails
# https://sourceforge.net/tracker/index.php?func=detail&aid=1654669&group_id=13002&atid=113002

    undef $li;
    my $li = $ls->get; 
    

    my $mh = DADA::Mail::Send->new({-list => $list});
	   $mh->test(1);
       $mh->send(%test_message);
    
    my $entity; 
       $entity = $parser->parse_open($mh->test_send_file); 
    
      my $date = $entity->head->get('Date', 0);
        chomp($date);
        
        ok(defined($date), "Date: header has been set to: '$date'"); 
       
		ok(unlink($mh->test_send_file)); 







# [ 1654672 ] 2.10.12 - utf8 unsupported in Charsets for HTML/emails
# https://sourceforge.net/tracker/index.php?func=detail&aid=1654672&group_id=13002&atid=113002


SKIP: {
    eval { require Test::utf8 };
     skip "Skipping utf-8 testing, Test::utf8 needs to be installed...", 1 if $@;
     
	if(! -e 't/corpus/html/utf8.html'){ 
		die "I can't find my test file at: " . 't/corpus/html/utf8.html'; 
	}
	
    open my $FILE, '<', "t/corpus/html/utf8.html" or die $!; 
	
    my $str = do { local $/; <$FILE> };

#	ok(defined($str), 'string seems to be defined at least'); 
	
    close($FILE); 

    $ls->save({charset => "utf-8\tutf-8"}); 

    for my $encoding(@DADA::Config::CONTENT_TRANSFER_ENCODINGS){ 

        $ls->save({html_encoding => $encoding}); 

        undef $li; 
        
        $li = $ls->get; 
        
        my $mh = DADA::Mail::Send->new({-list => $list});
           $mh->test(1);   
		   $mh->send(%test_message,
            'Content-type' => 'text/html', 
             Body         => $str, 
           );
    
        my $entity; 
           $entity = $parser->parse_open($mh->test_send_file); 
        
        my $utf_body = $entity->body_as_string;
          
         Encode::_utf8_on($utf_body);
         Test::utf8::is_sane_utf8($utf_body); 
         
        my $ct = $entity->head->get('Content-type', 0);
        chomp($ct);
        
        like($ct, qr/text\/html/, "'$ct' equals 'text/html' (Content-Type 2)"); 
	 	
        ok(unlink($mh->test_send_file)); 
		
    }        
    
}



dada_test_config::remove_test_list;
dada_test_config::wipe_out;
