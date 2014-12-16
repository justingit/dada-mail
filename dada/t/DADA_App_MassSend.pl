#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	/Users/justin/Documents/DadaMail/build/bundle/perllib-include
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 
#use Test::More qw(no_plan);  

use DADA::Config;
use DADA::App::Guts; 
use DADA::App::MassSend; 
use DADA::Mail::Send; 
use DADA::MailingList::Settings; 



my $list = dada_test_config::create_test_list;

# This is to speed up things... 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
$ls->param('enable_bulk_batching', 0); 
$ls->param('get_finished_notification', 0); 

ok($ls->param('enable_bulk_batching') == 0,      "set the bulk batching settings correctly " . $ls->param('enable_bulk_batching') . ' == 0'); 
ok($ls->param('get_finished_notification') == 0, "set get_finished_notification to 0"); 


my $mh = DADA::Mail::Send->new({-list => $list}); 

my $ms = DADA::App::MassSend->new({-list => $list});
ok($ms->isa('DADA::App::MassSend'), 'We have the right type of object!'); 

use CGI; 
my $q = new CGI; 
   $q = decode_cgi_obj($q);

# Globals
my $msg; 




$ms->test(1);
 
ok($ms->test ==  1, "testing has been turned on."); 

# Hmm, where to start? 
$q->param('process', 1); 
$q->param('text_message_body',     'This is the text message body!'); 


$ms->send_email(
	{
        -cgi_obj    => $q,
        -root_login => 1, # I mean, sure. 
	}
); 

sleep(1); 
$msg = slurp($mh->test_send_file); 
diag $msg; 
# TODO like($msg, qr/Subject\: \(no subject\)/, "no subject set correctly!"); 
undef $msg; 

ok(unlink($mh->test_send_file)); 

# OK, things seem to be working, let's do some damage: 

undef $q; 

$q = new CGI; 
$q->param('process', 1); 

# Only the To: Phrase can be edited... 
$q->param('Reply-To',   '"Changed Reply-To" <reply@example.com>'); 
$q->param('X-Priority',  1); 
$q->param('Subject',     'Changed Subject'); 
$q->param('text_message_body',     'This is the text message body!'); 
$ms->send_email(
	{
		-cgi_obj => $q, 
		-list    => $list, 
	}
); 


sleep(1); 
$msg = slurp($mh->test_send_file);


like($msg, qr/Subject\: Changed Subject/, "Subject set Correctly."); 
like($msg, qr/X\-Priority\: 1/, "X-Priority set correctly."); 
like($msg, qr/Reply\-To\: \"Changed Reply\-To\" \<reply\@example\.com\>/, "Reply-To set correctly."); 
like($msg, qr/Content-type\: text\/plain\;/, "Content-Type set correctly."); 
undef $msg; 
ok(unlink($mh->test_send_file)); 


## Multipart... 
$q->param('text_message_body',     'This is the text message body!'); 
$q->param('html_message_body',     'This is the html message body!'); 
$ms->send_email(
	{
		-cgi_obj => $q, 
		-list    => $list, 
	}
);

sleep(1); 
$msg = slurp($mh->test_send_file);
like($msg, qr/Content-type: multipart\/alternative\;/, "Multipart/alternative header set!"); 

my $parser; 
my $entity; 
my @parts; 
$parser = new MIME::Parser; 
$parser = optimize_mime_parser($parser);
$entity = $parser->parse_data($msg);
@parts  = $entity->parts; 
ok(
	$ls->param('charset_value') eq $parts[0]->head->mime_attr('content-type.charset'), 
	"Charset Match " . $parts[0]->head->mime_attr('content-type.charset')
); 
ok(
	$ls->param('charset_value') eq $parts[1]->head->mime_attr('content-type.charset'), 
	"Charset Match(2) " . $parts[0]->head->mime_attr('content-type.charset')
);
undef $parser; 
undef $entity; 
undef @parts;


undef $msg; 
ok(unlink($mh->test_send_file));
undef $q; 

# This makes sure the plaintext part is created, along with the multipart part: 
$q = new CGI; 
$q->param('process', 1);
$q->param('html_message_body',     '<h1>This is the html message body!</h1>'); 

$ms->send_email(
	{
		-cgi_obj => $q, 
		-list    => $list, 
	}
);
sleep(1); 

$msg = slurp($mh->test_send_file);

like($msg, qr/Content-type: multipart\/alternative\;/, "Multipart/alternative header set!"); 
# We'll also find these: 
like($msg, qr/Content-type: text\/html/i, "text/html header set!"); 
like($msg, qr/Content-type: text\/plain/i, "text/plain header set!"); 
like($msg, qr/This is the html message body!\n/m, "Found plain text version of HTML message"); 
like($msg, qr/\<h1\>This is the html message body!\<\/h1\>/m, "Found HTML  version of HTML message"); 

$parser = new MIME::Parser; 
$parser = optimize_mime_parser($parser);
$entity = $parser->parse_data($msg);
@parts  = $entity->parts; 
ok(
	$ls->param('charset_value') eq $parts[0]->head->mime_attr('content-type.charset'), 
	"Charset Match " . $parts[0]->head->mime_attr('content-type.charset')
); 
ok(
	$ls->param('charset_value') eq $parts[1]->head->mime_attr('content-type.charset'), 
	"Charset Match(2) " . $parts[0]->head->mime_attr('content-type.charset')
);
undef $parser; 
undef $entity; 
undef @parts; 
ok(unlink($mh->test_send_file));


# backdated_msg_id 
ok($ms->backdated_msg_id('2014-04-29 10:32:58') eq '20140429103257', 'backdated_msg_id'); 


dada_test_config::remove_test_list;
dada_test_config::wipe_out;

undef $q; 
$q = new CGI; 
ok($ms->are_we_archiving_based_on_params() == 1); 
$q->param('local_archive_options_present', 1);
ok($ms->are_we_archiving_based_on_params($q) == 0); 
$q->param('archive_message', 1);
ok($ms->are_we_archiving_based_on_params($q) == 1); 
$q->param('archive_message', 0); # that's not gonna happen. 
ok($ms->are_we_archiving_based_on_params($q) == 0); 



sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}




