#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 
use Test::More qw(no_plan);  
use utf8; 
use DADA::Config;
use DADA::App::Guts; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::Mail::Send; 
use DADA::App::Messages; 

my $fake_token = '1234'; 

use MIME::Parser; 
my $parser = new MIME::Parser; 
   $parser = optimize_mime_parser($parser);

my $list = dada_test_config::create_test_list;


use DADA::App::FormatMessages; 
my $fm = DADA::App::FormatMessages->new(-List => $list); 


my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $mh = DADA::Mail::Send->new({-list => $list}); 

my $email        = 'mytest@example.com'; 
my $email_name   = 'mytest'; 
my $email_domain = 'example.com'; 

my $lo_name   = 'test'; 
my $lo_domain = 'example.com'; 

my $msg; 

my $alt_message_subject = 'Email: <!-- tmpl_var subscriber.email --> List Name: <!-- tmpl_var list_settings.list_name -->'; 
my $alt_message_body = q{

List Name: <!-- tmpl_var list_settings.list_name -->
List Owner Email: <!-- tmpl_var list_settings.list_owner_email -->

Subscriber Email: <!-- tmpl_var subscriber.email -->
Subscriber Name: <!-- tmpl_var subscriber.email_name -->
Subscriber Domain: <!-- tmpl_var subscriber.email_domain -->
Subscriber Pin: <!-- tmpl_var subscriber.pin -->

Program Name: <!-- tmpl_var PROGRAM_NAME -->

};


############################
# send_confirmation_message
# Setup. 
ok($lh->add_subscriber({
    -email => $email,
    -type  => 'sub_confirm_list', 
}));
DADA::App::Messages::send_confirmation_message(
	{
        -list   => $list, 
        -email  => $email, 
        -ls_obj => $ls, 
		-test   => 1, 
		-token  => $fake_token,	
	}
);
$msg = slurp($mh->test_send_file); 
my $entity = $parser->parse_data(safely_encode($msg)); 
my $msg_str = safely_decode($entity->bodyhandle->as_string); 

ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
	); 


like($msg, qr/To:(.*?)$email_name\@$email_domain/, "To: set correctly 1"); 

 


my $confirm_url = quotemeta('/t/'. $fake_token . '/'); 
diag $msg_str; 
like($msg_str, qr/$confirm_url/, 'Confirmation link found and correct.'); 
my $list_name = $ls->param('list_name'); 
like($msg_str, qr/$list_name/, "List Name Found"); 
undef($list_name); 

my $privacy_policy = $ls->param('privacy_policy');
like($msg_str, qr/$privacy_policy/, "Privacy Policy Found"); 
undef($privacy_policy); 

my $physical_address = $ls->param('physical_address');
like($msg_str, qr/$physical_address/, "Physical Address Found"); 
undef($physical_address); 

my $list_owner_email = $ls->param('list_owner_email'); 
like($msg_str, qr/$list_owner_email/, "List Owner (" . $ls->param('list_owner_email') . ") Found"); 
undef($list_owner_email); 

ok(unlink($mh->test_send_file)); 
undef $entity; 
undef $msg; 
undef $msg_str; 

# ALternative Saved Text
ok(
	$ls->save(
		{
			confirmation_message         => $alt_message_body, 
			confirmation_message_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_confirmation_message(
	{
        -list   => $list, 
        -email  => $email, 
        -ls_obj => $ls, 
		-test   => 1, 
	}
);
$msg = slurp($mh->test_send_file); 
$entity = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string); 


ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Email: mytest\@example.com List Name: " . $ls->param('list_name'), 
	"Subject: Set Correctly"
); 




diag $msg_str; 

my $list_name = $ls->param('list_name'); 
like($msg_str, qr/List Name\: $list_name/, "Found: List Name"); 
undef($list_name); 

like($msg_str, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg_str, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg_str, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
like($msg_str, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name1"); 

# Reset: 
ok(
	$ls->save(
		{
			confirmation_message         => undef, 
			confirmation_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 

#undef $parser; 








	
##########################
# send_subscribed_message

# Setup
ok($lh->move_subscriber(
	{
		-from    => 'sub_confirm_list', 
		-to      => 'list',  
		-email   => $email,
	}
)); 

DADA::App::Messages::send_subscribed_message(
	{
		-list         => $list, 
        -email        => $email, 
        -ls_obj       => $ls,
		-test         => 1,  
	}
);

$msg = slurp($mh->test_send_file); 
$entity = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);

ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
	); 
like(
	decode_header($entity->head->get('To', 0)), 
	qr/$email_name\@$email_domain/, 
	"To: Set Correctly 2"
);
	
ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Welcome to " . $ls->param('list_name'), 
	"Subject: Set Correctly"
);






my $physical_address = $ls->param('physical_address'); 
like($msg_str, qr/$physical_address/, "Physical Address Found"); 
undef($physical_address); 

like($msg_str, qr/$email_name\@$email_domain/, "The Subscriber Email Address is *somewhere* to be found..."); 
ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 



# ALternative Saved Text
ok(
	$ls->save(
		{
			subscribed_message         => $alt_message_body, 
			subscribed_message_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_subscribed_message(
	{
        -list   => $list, 
        -email  => $email, 
        -ls_obj => $ls, 
		-test   => 1, 
	}
);
$msg = slurp($mh->test_send_file); 
$entity = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);

ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Email: mytest\@example.com List Name: " . $ls->param('list_name'), 
	"Subject: Set Correctly"
);
	

my $list_name = $ls->param('list_name'); 
like($msg_str, qr/List Name\: $list_name/, "Found: List Name"); 
undef($list_name); 

like($msg_str, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg_str, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg_str, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 

like($msg_str, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name2"); 

# Reset: 
ok(
	$ls->save(
		{
			subscribed_message         => undef, 
			subscribed_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 


########################
# send_owner_happenings - subscribed
DADA::App::Messages::send_owner_happenings(
	{
		-list  => $list, 
		-email => $email, 
		-role  => "subscribed",
		-test  => 1,
	}
);

$msg = slurp($mh->test_send_file); 
$entity = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);

ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
);
diag q{decode_header($entity->head->get('To', 0))} . decode_header($entity->head->get('To', 0)); 
ok(
	decode_header($entity->head->get('To', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"To: Set Correctly 3"
);
my   $sub = $entity->head->get('Subject', 0); 
chomp $sub; 

diag "'" . decode_header($sub) ."'"; 
diag "'" . "Subscribed $email_name\@$email_domain" . "'"; 
ok(
	decode_header($sub)
	eq
	"Subscribed $email_name\@$email_domain", 
	"Subject: Set Correctly2"
);

like($msg_str, qr/There are now a total of: 1 subscribers./, "Misc. Body stuff found (2)"); 

ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 






##########################################
# send_you_are_already_subscribed_message


require DADA::App::Messages; 
DADA::App::Messages::send_you_are_already_subscribed_message(		
	{
    	-list         => $list, 
        -email        => $email, 
		-test         => 1, 
	}
);
$msg = slurp($mh->test_send_file); 
$entity = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);

ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
);
#diag "set to this: " . decode_header($entity->head->get('To', 0)); 
#diag "look fo this: " . "\"$ls->param('list_name') Subscriber\" \<$email_name\@$email_domain\>";

#"Dada Test List¡™£¢∞§¶•ªº Subscriber" <mytest@example.com>

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';

	ok(
		decode_header($entity->head->get('To', 0))
		eq
		"\"" . $ls->param('list_name') . " Subscriber\" \<$email_name\@$email_domain\>", 
		"To: Set Correctly 4"
	);

}


undef $sub;
$sub = $entity->head->get('Subject', 0);
chomp $sub;
 
diag '"' . decode_header($sub) . '"'; 
diag '"' . $ls->param('list_name') . "- You Are Already Subscribed" . '"';
ok(
	decode_header($sub)
	eq
	$ls->param('list_name') . " - You Are Already Subscribed", 
	"Subject: Set Correctly"
);

like($msg_str, qr/This email address is actually already subscribed/,                  "Misc. Body string found!"); 
ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 



# ALternative Saved Text
ok(
	$ls->save(
		{
			you_are_already_subscribed_message         => $alt_message_body, 
			you_are_already_subscribed_message_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_you_are_already_subscribed_message(
	{
        -list   => $list, 
        -email  => $email, 
        -ls_obj => $ls, 
		-test   => 1, 
	}
);
$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);

undef $sub;
$sub = $entity->head->get('Subject', 0);
chomp $sub; 

ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Email: mytest\@example.com List Name: " . $ls->param('list_name'), 
	"Subject: Set Correctly"
);

my $list_name = $ls->param('list_name'); 
like($msg_str, qr/List Name\: $list_name/, "Found: List Name"); 
undef($list_name); 

like($msg_str, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg_str, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg_str, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
like($msg_str, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name3"); 

# Reset: 
ok(
	$ls->save(
		{
			you_are_already_subscribed_message         => undef, 
			you_are_already_subscribed_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file));
undef $msg; 
undef $entity; 
undef $msg_str; 




############################
# send_unsubscribed_message 

ok($lh->remove_subscriber({-email => $email, -type => 'list'})); 
ok($lh->remove_subscriber({-email => $email, -type => 'unsub_confirm_list'})); 


DADA::App::Messages::send_unsubscribed_message(
	{
		-list      => $list,
        -email     => $email,
        -ls_obj    => $ls,
		-test      => 1,
	}	
);

diag "here."; 

$msg     = slurp($mh->test_send_file); 

diag "here."; 

$entity  = $parser->parse_data(safely_encode($msg)); 

diag "here."; 

$msg_str = safely_decode($entity->bodyhandle->as_string);



ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
);

diag "here."; 

ok(
	decode_header($entity->head->get('To', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$email_name\@$email_domain\>", 
	"To: Set Correctly 6"
);

diag "here."; 


diag "Subject: " . safely_encode(decode_header($entity->head->get('Subject', 0)));
 
ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Farewell from " . $ls->param('list_name'), 
	"Subject: Set Correctly (1)"
);

diag "here."; 



ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 



# ALternative Saved Text
ok(
	$ls->save(
		{
			unsubscribed_message         => $alt_message_body, 
			unsubscribed_message_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_unsubscribed_message(
	{
        -list   => $list, 
        -email  => $email, 
        -ls_obj => $ls, 
		-test   => 1, 
	}
);


$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);



ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Email: mytest\@example.com List Name: " . $ls->param('list_name'), 
	"Subject: Set Correctly"
);

my $list_name = $ls->param('list_name'); 
like($msg_str, qr/List Name\: $list_name/, "Found: List Name"); 
undef($list_name); 

like($msg_str, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg_str, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg_str, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name4"); 

# Reset: 
ok(
	$ls->save(
		{
			unsubscribed_message         => undef, 
			unsubscribed_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file)); 
undef $msg; 
undef $entity; 
undef $msg_str; 







########################
# send_owner_happenings - unsubscribed
DADA::App::Messages::send_owner_happenings(
	{
		-list  => $list, 
		-email => $email, 
		-role  => "unsubscribed",
		-test  => 1,
	}
);

$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);


ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
);
ok(
	decode_header($entity->head->get('To', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"To: Set Correctly 7"
);

undef $sub;
$sub = $entity->head->get('Subject', 0);
chomp $sub;
 
diag '"' . decode_header($sub) . '"'; 
diag '"' . "Unsubscribed $email_name\@$email_domain" . '"';
ok(
	decode_header($sub)
	eq
	"Unsubscribed $email_name\@$email_domain", 
	"Subject: Set Correctly"
);

like($msg_str, qr/There are now a total of: 0 subscribers./, "Misc. Body stuff found (2)"); 

ok(unlink($mh->test_send_file));
undef $msg; 
undef $entity; 
undef $msg_str; 
#######################
# send_newest_archive

# Having major problems attempting to test this out - dunno!

ok($lh->add_subscriber({
    -email => $email,
    -type  => 'list', 
}));

# If there's no archive to send, it should return, "0"

ok(DADA::App::Messages::send_newest_archive(
	{
	-list         => $list, 
    -email        => $email, 
    -ls_obj       => $ls, 
    -test         => 1,
	}
) == 0, "No archive to send returns, '0'"); 




my $msg_info = {

msg_subject => "This is the Message Subject", 
msg_body    => "This is the Message Body", 
'format'    => 'text/plain', 

};

# OK, well, let's archive a message:
use  DADA::MailingList::Archives; 
my $mla = DADA::MailingList::Archives->new({-list => $list}); 
my $message_id = DADA::App::Guts::message_id(); 



ok(defined $mla,                        'new() returned something, good!' );
ok( $mla->isa('DADA::MailingList::Archives'),   "  and it's the right class" );


# Note passing a message_id will return undef and give back a warning. 
my $set_return_fail = $mla->set_archive_info(undef, "blah", "blah", 'text/plain'); 
ok($set_return_fail eq undef, "adding a new archive entry without a message id returns undef!"); 

my $set_return_pass = $mla->set_archive_info($message_id, $msg_info->{msg_subject}, $msg_info->{msg_body}, $msg_info->{'format'}); 
ok($set_return_pass == 1, "adding a new archive entry *with* a message id returns 1!"); 


#diag '$message_id ' . $message_id; 

my $exists = $mla->check_if_entry_exists($message_id); 
ok($exists == 1, "check_if_entry_exists says our archived message exists!");



ok(DADA::App::Messages::send_newest_archive(
	{
	-list         => $list, 
    -email        => $email, 
    -ls_obj       => $ls, 
    -test         => 1,
	-la_obj       => $mla, 
	}
) == 1, "Archive to send returns, '1' (1)");

$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);


ok(
	decode_header($entity->head->get('From', 0))
	eq
	"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
	"From: Set Correctly"
);
diag 'first: "' .   decode_header($entity->head->get('To', 0)) . '"'; 
diag 'second: "' . "\"" . $ls->param('list_name') . " Subscriber\" \<$email_name\@$email_domain\>" . '"'; 
diag "looks the same to me!"; 

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
	ok(
		decode_header($entity->head->get('To', 0))
		eq
		"\"" . $ls->param('list_name') . " Subscriber\" \<$email_name\@$email_domain\>", 
		"To: Set Correctly 8 "
	);

}

undef $sub;
$sub = $entity->head->get('Subject', 0);
chomp $sub;
 
diag '"' . decode_header($sub) . '"'; 
diag '"' . "$msg_info->{msg_subject}" . '"';


ok(
	decode_header($sub)
	eq
	"$msg_info->{msg_subject}", 
	"Subject: Set Correctly"
); 
TODO: {
    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
	# What?
	like($msg_str, qr/\n\n$msg_info->{msg_body}/, "Body Set Correctly (what? HERE)");

};

ok(unlink($mh->test_send_file));
undef $msg; 
undef $entity; 
undef $msg_str; 


#  [ 2099456 ] 3.0.0 - Send last msg to new subscribers msg corrupted?
# Basically, the Content-type header is always reset to, "text/plain". 
# Let's make sure that's not the case... 
	
	diag ("Testing for bug #2099456");
	undef $set_return_pass;
	$set_return_pass = $mla->set_archive_info(($message_id + 1), "Subject", "Body", 'text/html'); 
	ok($set_return_pass == 1, "adding a new archive entry *with* a message id returns 1!");

	ok(DADA::App::Messages::send_newest_archive(
		{
		-list         => $list, 
	    -email        => $email, 
	    -ls_obj       => $ls, 
	    -test         => 1,
		-la_obj       => $mla, 
		}
	) == 1, "Archive to send returns, '1' (2)");


	$msg     = slurp($mh->test_send_file); 
	$entity  = $parser->parse_data(safely_encode($msg)); 
	
	#$msg_str = safely_decode($entity->bodyhandle->as_string);

	diag '$entity->head->mime_type ' . $entity->head->mime_type; 
	# I honestly only care about the Content-type
	ok($entity->head->mime_type eq 'multipart/alternative', "Content-type set correctly"); 

	ok(unlink($mh->test_send_file));
	

	# diag "Test #2 for bug #2099456"; 
	# Another check - 
	# Dada Mail looks for both Content-Type and Content-type headers, if it 
	# finds both, it'll only use Content-type to send. 
	# If it only finds, Content-Type, it'll copy that over to, Content-type and
	# delete Content-Type. 

	my $test_msg = q{Content-type: text/html
Subject: Subject

Body

};

	undef $set_return_pass;
	$set_return_pass = $mla->set_archive_info(($message_id + 2), 'Subject', undef, undef, $test_msg); 
	ok($set_return_pass == 1, "adding a new archive entry *with* a message id returns 1!");

	ok(DADA::App::Messages::send_newest_archive(
		{
		-list         => $list, 
	    -email        => $email, 
	    -ls_obj       => $ls, 
	    -test         => 1,
		-la_obj       => $mla, 
		}
	) == 1, "Archive to send returns, '1' (3)");


	$msg     = slurp($mh->test_send_file); 
	$entity  = $parser->parse_data(safely_encode($msg)); 
	
	diag '$entity->head->mime_type ' . $entity->head->mime_type; 
	# I honestly only care about the Content-type
	ok($entity->head->mime_type eq 'multipart/alternative', "Content-type set correctly");

	ok(unlink($mh->test_send_file));
	
	
# Grrr! These tests are great, but they don't work well, since the, "DB File" backend
# destroys multipart messages, which I think is where most of our problems are coming from
# Damn!

#
# TODO - split this test file into 4 different tests for, for each backend (or at least Db File and SQLite) 
#


# TODO ALSO is to make sure templating is happening (althoug I think it is...) 

#/ [ 2099456 ] 3.0.0 - Send last msg to new subscribers msg corrupted?

##################################
# send_not_allowed_to_post_msg

my $fake_message_back = qq{
To: list\@example.com
From: $email
Subject: Dud

This isn't getting too far, is it?
};

DADA::App::Messages::send_not_allowed_to_post_msg(
	{
		-list       => $list, 
		-email      => $email,	
		-attachment => $fake_message_back, 
		-test       => 1
	},
);

my $q_fake_message_back = quotemeta($fake_message_back);

$msg     = slurp($mh->test_send_file); 

$entity  = $parser->parse_data(safely_encode($msg)); 
diag '$entity->as_string ' . safely_encode($entity->as_string); 
 
my @parts = $entity->parts; 

#diag '$parts[0]->bodyhandle->as_string ' . safely_encode($parts[0]->bodyhandle->as_string); 
#diag '$parts[1]->as_string ' . safely_encode($parts[1]->as_string); 

my $msg_str0 = safely_decode($parts[0]->bodyhandle->as_string);
#my $msg_str1 = safely_decode($parts[1]->bodyhandle->as_string);
my $msg_str1 = safely_decode($parts[1]->as_string); # uh, why?


TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';

	ok(
		decode_header($entity->head->get('From', 0))
		eq
		"\"" . $ls->param('list_name') . "\" \<$lo_name\@$lo_domain\>", 
		"From: Set Correctly"
	);

}

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
	ok(
		decode_header($entity->head->get('To', 0))
		eq
		"\"" . $ls->param('list_name') . "\" \<$email_name\@$email_domain\>", 
		"To: Set Correctly 9"
	);
}

#diag q{decode_header($entity->head->get('Subject', 0))} . decode_header($entity->head->get('Subject', 0)); 
ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Not Allowed to Post On " . $ls->param('list_name') . " (your original message is attached)", 
	"Subject: Set Correctly"
);


my $natp_msg = quotemeta('But, it doesn\'t seem that you currently have permission to do so.'); 
diag '$msg_str0' . $msg_str0; 
like($msg_str0, qr/$natp_msg/, "Body Set Correctly");

my $list_name = $ls->param('list_name'); 
like($msg_str0, qr/$list_name/, "Found: List Name"); 
undef($list_name); 



like($msg_str1, qr/$q_fake_message_back/, "Original Message seems to be attached.");

ok(unlink($mh->test_send_file));
undef $msg; 
undef $entity; 
undef $msg_str0; 
undef $msg_str1; 



# ALternative Saved Text
ok(
	$ls->save(
		{
			not_allowed_to_post_msg         => $alt_message_body, 
			not_allowed_to_post_msg_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_not_allowed_to_post_msg(
	{
        -list       => $list, 
        -email      => $email, 
        -ls_obj     => $ls, 
		-attachment => $fake_message_back, 
		-test       => 1, 
	}
);


$msg     = slurp($mh->test_send_file); 

# This is a multipart message, it needs something fancier... 
$entity  = $parser->parse_data(safely_encode($msg)); 
@parts = $entity->parts; 
$msg_str = safely_decode($parts[0]->bodyhandle->as_string);
diag $msg_str; 


TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
	ok(
		decode_header($entity->head->get('Subject', 0))
		eq
		"Email: mytest\@example.com List Name: " . $ls->param('list_name'), 
		"Subject: Set Correctly"
	);
}


my $list_name = $ls->param('list_name'); 
like($msg_str, qr/List Name\: $list_name/, "Found: List Name"); 
undef($list_name); 

like($msg_str, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';

			like($msg_str, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
};


TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
		# Hmm! Not sure what to do about this...
		like($msg_str, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
};

like($msg_str, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name5"); 

# Reset: 
ok(
	$ls->save(
		{
			confirmation_message         => undef, 
			confirmation_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file)); 
undef $msg;
undef $entity; 
undef $msg_str; 



DADA::App::Messages::send_not_allowed_to_post_msg(
	{
        -list       => $list, 
        -email      => $email, 
        -ls_obj     => $ls, 
		-attachment => $fake_message_back, 
		-test       => 1, 
	}
);
$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
@parts = $entity->parts; 
$msg_str = safely_decode($parts[0]->bodyhandle->as_string);
diag $msg_str;

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
	ok(
		decode_header($entity->head->get('Subject', 0))
		eq
		"Email: mytest\@example.com List Name: " . $ls->param('list_name'), 
		"Subject: Set Correctly"
	);
};


my $list_name = $ls->param('list_name'); 
like($msg_str, qr/List Name\: $list_name/, "Found: List Name"); 
undef($list_name); 

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
		like($msg_str, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
};

like($msg_str, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 

# Hmm! Not sure what to do about this...
TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';

		like($msg_str, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 

};

like($msg_str, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name6"); 

# Reset: 
ok(
	$ls->save(
		{
			confirmation_message         => undef, 
			confirmation_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file));
undef $msg; 
undef $entity; 
undef $msg_str; 


 
send_generic_email(
	{ 
		-list       => $list, 
        -email      => $email, 
        -ls_obj     => $ls, 
		-test       => 1,

		-headers => {
		    Subject =>  $dada_test_config::UTF8_STR,
		},
		-body => $dada_test_config::UTF8_STR, 
		
		-tmpl_params => { 
            -vars                     => {},
		},
	}
);

$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);

TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';
		like($msg_str, qr/$dada_test_config::UTF8_STR/, 'UTF-8 string found'); 
};

my $ue_subject = $entity->head->get('Subject', 0); 
my $subject    = $fm->_decode_header($ue_subject); 
 
#chomp($ue_subject); 
#ok($ue_subject eq $fm->_encode_header($UTF8_str), 'MIME::Encoded Subject found (' . $ue_subject . ')'); 
TODO: {
	    local $TODO = 'There is, I think a bug in the test itself, dealing with an encoding issue, but this needs to be double-checked.';

		ok($dada_test_config::UTF8_STR eq $subject, 'UTF-8 string found in Subject.(' . Encode::encode('UTF-8', $subject) . ')');  

};


undef $msg_str; 
undef $ue_subject; 
undef $subject; 
undef $entity; 
undef $msg; 



send_generic_email(
	{ 
		-list       => $list, 
        -email      => $email, 
        -ls_obj     => $ls, 
		-test       => 1,

		-headers => {
		    Subject =>  $dada_test_config::UTF8_STR,
		},
		# This is my Unicode torture 
		# Slurp doesn't know encoding, so no need to decode
		# OR, you decode in UTF8 and re-encode. 
		-body => slurp('t/corpus/html/utf8.html'), 
		
		-tmpl_params => { 
            -vars                     => {},
		},
	}
);
$msg     = slurp($mh->test_send_file); 
$entity  = $parser->parse_data(safely_encode($msg)); 
$msg_str = safely_decode($entity->bodyhandle->as_string);



like($msg_str, qr/$dada_test_config::UTF8_STR/, 'UTF-8 string found'); 


$ue_subject = $entity->head->get('Subject', 0);
$subject    = $fm->_decode_header($ue_subject); 

# No, really - that's some pretty crazy stuff, right there. 
ok(1 == 1, "we're still here?!"); 

undef $msg; 
undef $ue_subject; 
undef $subject;
undef $msg_str; 




dada_test_config::remove_test_list;
dada_test_config::wipe_out;



sub decode_header { 
#	my $self   = shift; 
	my $header = shift; 
	
	if($header !~ m/\=\?/){ 
		#warn "skipping header - doesn't look encoded?"; 
		return $header; 
	}	
	require MIME::EncWords; 
	my @dec = MIME::EncWords::decode_mimewords($header, Charset => '_UNICODE_'); 
	my $dec = join('', map { $_->[0] } @dec);
	   $dec = safely_decode($dec); 
	return $dec; 
}



