#!/usr/bin/perl
use strict; 
use Carp; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 
use DADA::App::Guts; 
use DADA::MailingList::Settings; 

use DADA::Mail::Send; 
use DADA::Mail::MailOut;


#dada_test_config::wipe_out;

use Test::More qw(no_plan);  

my $list = dada_test_config::create_test_list;

my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 
do "plugins/bridge.cgi"; 




ok(bridge->test_sub() eq q{Hello, World!}); 

my $test_msg = undef; 
my $entity   = undef; 
my $errors   = {}; 
my $notice      = undef; 

use MIME::Parser;
use MIME::Entity; 

my $parser = new MIME::Parser; 
   $parser = DADA::App::Guts::optimize_mime_parser($parser); 


# [ 2136642 ] 3.0.0 - Check_List_Owner_Return_Path_Header fails with undef
# http://sourceforge.net/tracker/index.php?func=detail&aid=2136642&group_id=13002&atid=113002

$test_msg = q{To: you@example.com
From: me@example.com
Subject: Well, Heya

Blah Blah Blah
	
};

$entity = $parser->parse_data($test_msg);


($errors, $notice) = bridge::test_Check_List_Owner_Return_Path_Header($ls, $entity, $errors); 


ok($errors->{list_owner_return_path_set_funny} == 0, "list_owner_return_path_set_funny has been set to, 0");
like($notice, qr/No Return Path Found/, '"No Return Path Found" notice reported.');

$errors = {};
undef $notice; 
undef $entity; 
undef $test_msg;

# /[ 2136642 ] 3.0.0 - Check_List_Owner_Return_Path_Header fails with undef
# /http://sourceforge.net/tracker/index.php?func=detail&aid=2136642&group_id=13002&atid=113002



# Hey! Let's see if our new, "inject' thingy works!
$test_msg = ''; 
my $status = undef; 


($status, $errors) = bridge::inject(
	{ 
		-ls        => $ls, 
		-msg       => $test_msg, 
		-verbose   => 1, 
		-test_mail => 1, 
	}
); 

ok($status == 0, "inject returning 0 - it's disabled, #1"); 
ok($errors->{disabled} == 1, "inject returning 0 - it's disabled #2"); 


$ls->param('disable_discussion_sending', 0);
ok($ls->param('disable_discussion_sending') == 0, "we've enabled this crazy thing..."); 

$errors = {}; 
undef $status; 


($status, $errors) = bridge::inject(
	{ 
		-ls        => $ls,
		-msg       => '', 
		-verbose   => 1, 
		-test_mail => 1, 
	}
);

ok($status == 0, "inject returning 0 - it's not disabled, but we've got an improper email message"); 
ok($errors->{blank_message} == 1, "Error Produced is that the message is blank. Good! ($errors->{blank_message})"); 

# We should really go through all the different thinga-ma-jigs that you can, to make a message work, 
# But, we'll leave that for later... 

# Mime Word Encoded Message: 
my $msg = slurp('t/corpus/email_messages/simple_utf8_subject.txt'); 
#diag $msg; 

# First, we actually have to set everything up, so it'll work: 
$ls->param('disable_discussion_sending',  0                     );
$ls->param('discussion_pop_email',       'listemail@example.com'); 
$ls->param('list_owner_email',           'listowner@example.com'); 
$ls->param('rewrite_anounce_from_header', 0                     ); 
$ls->param('enable_bulk_batching',        0                     ); 
$ls->param('get_finished_notification',   0                     ); 

($status, $errors) = bridge::inject(
	{ 
		-msg       => $msg, 
		-verbose   => 1, 
		-test_mail => 1, 
		-ls        => $ls, 
	}
);




wait_for_msg_sending(); 




my $mh = DADA::Mail::Send->new({-list => $list}); 
my $sent_msg =  slurp($mh->test_send_file); 

# This could be a lot more intricate, but we're just going to see if the 
# To: and, Subject: Headers are the same and contain the mime encoded words strings, 
# (for now) 
my $orig_entity = $parser->parse_data($msg);
my $sent_entity = $parser->parse_data($sent_msg);

SKIP: {
    skip 'Some UTF stuff - the encoding is done different, the unencoded is probably the same', 2 unless 0;
	ok($orig_entity->head->get('Subject', 0) eq $sent_entity->head->get('Subject', 0), "The Subject header of the original and sent messages is the same. (1) (" . $orig_entity->head->get('Subject', 0) . ") and, (" . $sent_entity->head->get('Subject', 0) . ")" ); 
	ok($orig_entity->head->get('From', 0) eq $sent_entity->head->get('From', 0), "The From header of the original and sent messages is the same."); 

};




undef $status; 
undef $errors; 
undef $orig_entity; 
undef $sent_entity; 
undef $sent_msg; 

unlink $mh->test_send_file;

# Now, we gotta do it, with encoding explicatly on: 
$ls->param('charset',                        "utf-8\tutf-8"        ); 
$ls->param('mime_encode_words_in_headers',   1                     ); 

($status, $errors) = bridge::inject(
	{ 
		-msg       => $msg, 
		-verbose   => 1, 
		-test_mail => 1, 
		-ls        => $ls, 
	}
);


wait_for_msg_sending(); 






$sent_msg =  slurp($mh->test_send_file); 

$orig_entity = $parser->parse_data($msg);
$sent_entity = $parser->parse_data($sent_msg);

require MIME::EncWords; 

my $orig_sub = MIME::EncWords::decode_mimewords($orig_entity->head->get('Subject', 0), Charset => '_UNICODE_');
my $sent_sub = MIME::EncWords::decode_mimewords($sent_entity->head->get('Subject', 0), Charset => '_UNICODE_');
#
my $orig_from =  MIME::EncWords::decode_mimewords($orig_entity->head->get('From', 0), Charset => '_UNICODE_');
my $sent_from =  MIME::EncWords::decode_mimewords($sent_entity->head->get('From', 0), Charset => '_UNICODE_');


#my $orig_sub = $orig_entity->head->get('Subject', 0);
#my $sent_sub = $sent_entity->head->get('Subject', 0);

#my $orig_from =  $orig_entity->head->get('From', 0);
#my $sent_from =  $sent_entity->head->get('From', 0);

#diag ' $orig_sub ' . $orig_sub; 
#diag ' $sent_sub ' . $sent_sub; 
#diag ' $orig_from ' . $orig_from; 
#diag ' $sent_from ' . $sent_from; 



diag "this will fail, since the list short name is prepended, so..."; 
ok(
	'['.$list.'] ' . $orig_sub 
	eq 
	$sent_sub, 
"The Subject header of the original and sent messages is the same. (2) '$orig_sub', '$sent_sub'
");

 
#ok($orig_entity->head->get('From', 0) eq $sent_entity->head->get('From', 0), "The From header of the original and sent messages is the same."); 
like($orig_entity->head->get('From', 0), qr/\<listowner\@example.com\>/, "I can still find the From: address just fine.");



unlink $mh->test_send_file;

undef $status; 
undef $errors; 
undef $orig_entity; 
undef $sent_entity; 
undef $sent_msg;
undef $orig_sub; 
undef $sent_sub;
undef $orig_from; 
undef $sent_from; 
undef $test_msg; 


$test_msg = slurp('t/corpus/email_messages/from_header_phrase_spoof.eml'); 
($status, $errors) = bridge::validate_msg($ls, \$test_msg);

#use Data::Dumper; 
#diag Data::Dumper::Dumper($errors); 


ok($status == 0, "spoof test is returning 0?"); 
$errors = {}; 
undef $status;
undef $test_msg; 


# Does that Subject header get appended? 
$ls->param('group_list', 1); 


($status, $errors) = bridge::inject(
	{ 
		-msg       => $msg, 
		-verbose   => 1, 
		-test_mail => 1, 
		-ls        => $ls, 
	}
);

#use Data::Dumper; 
#diag Data::Dumper::Dumper($errors);

wait_for_msg_sending(); 

$sent_msg =  slurp($mh->test_send_file); 
$orig_entity = $parser->parse_data($msg);
$sent_entity = $parser->parse_data($sent_msg);
my $sent_sub = MIME::EncWords::decode_mimewords($sent_entity->head->get('Subject', 0), Charset => '_UNICODE_');
my $qm_subject = quotemeta('[dadatest]'); 
like($sent_sub, qr/^$qm_subject/, "list short name appeneded to Subject! ($sent_sub)"); 

$ls->param('group_list', 0); 
undef $test_msg; 
undef $status; 
undef $errors; 
undef $sent_msg; 
undef $orig_entity; 
undef $sent_entity; 
ok(unlink($mh->test_send_file)); 

diag "NOW WE START."; 


$msg = slurp('t/corpus/email_messages/simple_utf8_msg.eml'); 
($status, $errors) = bridge::validate_msg($ls, \$msg);

ok($status == 1, "status returning 1"); 

($status, $errors) = bridge::inject(
	{ 
		-msg       => $msg, 
		-verbose   => 1, 
		-test_mail => 1, 
		-ls        => $ls, 
	}
);

wait_for_msg_sending(); 

$sent_msg =  slurp($mh->test_send_file); 
# so this does nothing but make sure we're... still alive? 
# Great .
ok (1 ==1); 

undef $msg; 
undef $status; 
undef $errors; 
undef $sent_msg; 

# Moderation! 
# WOO!.







dada_test_config::remove_test_list;
dada_test_config::wipe_out;
 




sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || croak "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}


sub  wait_for_msg_sending { 
	
	my @mailouts = DADA::Mail::MailOut::current_mailouts({-list => $list}); 
	my $timeout = 0; 
	while($mailouts[0] ){ 
		diag "sleeping until mailout is done..."  . $mailouts[0]->{sendout_dir}; 
		sleep(5); 
		if($timeout >= 30){ 
			die "something's wrong with the testing - dying."	
		}
		@mailouts = DADA::Mail::MailOut::current_mailouts({-list => $list});
	}
	undef @mailouts;

	
}



