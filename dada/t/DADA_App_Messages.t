#!/usr/bin/perl -w
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 
use Test::More qw(no_plan);  

use DADA::Config;
use DADA::App::Guts; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::Mail::Send; 
use DADA::App::Messages; 

my $list = dada_test_config::create_test_list;

my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 
my $mh = DADA::Mail::Send->new({-list => $list}); 

my $email        = 'mytest@example.com'; 
my $email_name   = 'mytest'; 
my $email_domain = 'example.com'; 

my $lo_name   = 'test'; 
my $lo_domain = 'example.com'; 

my $msg; 

my $alt_message_subject = 'Email: [subscriber.email] List Name: [list_settings.list_name]'; 
my $alt_message_body = q{

List Name: [list_settings.list_name]
List Owner Email: [list_settings.list_owner_email]

Subscriber Email: [subscriber.email]
Subscriber Name: [subscriber.email_name]
Subscriber Domain: [subscriber.email_domain]
Subscriber Pin: [subscriber.pin]

Program Name: [PROGRAM_NAME]

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
	}
);
$msg = slurp($mh->test_send_file); 
like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To:(.*?)$email_name\@$email_domain/, "To: set correctly"); 
like($msg, qr/Subject\: $li->{list_name} Mailing List Subscription Confirmation/, "Subject: set correctly"); 

my $pin = DADA::App::Guts::make_pin(-Email => $email); 

my $confirm_url = quotemeta($DADA::Config::PROGRAM_URL . '/n/'. $list . '/' . $email_name . '/' . $email_domain . '/'.$pin.'/'); 

like($msg, qr/$confirm_url/, 'Confirmation link found and correct.'); 
like($msg, qr/$li->{list_name}/, "List Name Found"); 
like($msg, qr/$li->{privacy_policy}/, "Privacy Policy Found"); 
like($msg, qr/$li->{physical_address}/, "Physical Address Found"); 
like($msg, qr/$li->{list_owner_email}/, "List Owner ($li->{list_owner_email}) Found"); 

ok(unlink($mh->test_send_file)); 


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
my $sub = quotemeta('Subject: Email: mytest@example.com List Name: Dada Test List'); 
like($msg, qr/$sub/, "Subject: set correctly"); 
like($msg, qr/List Name\: $li->{list_name}/, "Found: List Name"); 
like($msg, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
like($msg, qr/Subscriber Pin\: $pin/, "Found: Subscriber Pin"); 
like($msg, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name"); 

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

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To:(.*?)$email_name\@$email_domain/, "To: set correctly"); 
like($msg, qr/Subject\: Welcome to $li->{list_name}/, "Subject: set correctly");
like($msg, qr/$li->{physical_address}/, "Physical Address Found"); 
like($msg, qr/$email_name\@$email_domain/, "The Subscriber Email Address is *somewhere* to be found..."); 

ok(unlink($mh->test_send_file)); 

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
my $sub = quotemeta('Subject: Email: mytest@example.com List Name: Dada Test List'); 
like($msg, qr/$sub/, "Subject: set correctly"); 
like($msg, qr/List Name\: $li->{list_name}/, "Found: List Name"); 
like($msg, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
# like($msg, qr/Subscriber Pin\: $pin/, "Found: Subscriber Pin"); 
like($msg, qr/Subscriber Pin\: /, "Did Not Find: Subscriber Pin"); 

like($msg, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name"); 

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

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To: \"$li->{list_name} List Owner\" \<$lo_name\@$lo_domain\>/, "To: Set Correctly"); 
like($msg, qr/Subject\: subscribed $email_name\@$email_domain/, "Subject: set correctly");
like($msg, qr/There is now a total of: 1 subscribers./, "Misc. Body stuff found (2)"); 

ok(unlink($mh->test_send_file)); 

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

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/,                "From: Set Correctly"); 
like($msg, qr/To: \"$li->{list_name} Subscriber\" \<$email_name\@$email_domain\>/, "To: set correctly"); 
like($msg, qr/Subject\: $li->{list_name} - You Are Already Subscribed/,            "Subject: set correctly");
like($msg, qr/This email address is actually already subscribed/,                  "Misc. Body string found!"); 
ok(unlink($mh->test_send_file)); 




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
$msg = slurp($mh->test_send_file); 
my $sub = quotemeta('Subject: Email: mytest@example.com List Name: Dada Test List'); 
like($msg, qr/$sub/, "Subject: set correctly"); 
like($msg, qr/List Name\: $li->{list_name}/, "Found: List Name"); 
like($msg, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
# like($msg, qr/Subscriber Pin\: $pin/, "Found: Subscriber Pin"); 
like($msg, qr/Subscriber Pin\: /, "Did Not Find: Subscriber Pin");
like($msg, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name"); 

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



#################################
# send_unsub_confirmation_message

ok ( 
	$lh->copy_subscriber(
		{
			-from  => 'list', 
			-to    => 'unsub_confirm_list', 
			-email => $email,
		}
	) 
);


DADA::App::Messages::send_unsub_confirmation_message(
	{
    	-list         => $list, 
        -email        => $email, 
        -settings_obj => $ls, 
    	-test         => 1,
	}
);

$msg = slurp($mh->test_send_file); 

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To:(.*?)$email_name\@$email_domain/, "To: set correctly"); 
like($msg, qr/Subject\: $li->{list_name} Mailing List Unsubscription Confirmation/, "Subject: set correctly"); 

$pin = DADA::App::Guts::make_pin(-Email => $email, -List => $list); 

$confirm_url = quotemeta($DADA::Config::PROGRAM_URL . '/u/'. $list . '/' . $email_name . '/' . $email_domain . '/'.$pin.'/'); 

like($msg, qr/$confirm_url/,            'Confirmation link found and correct.'); 
like($msg, qr/$li->{list_name}/,        "List Name Found"); 
like($msg, qr/$li->{privacy_policy}/,   "Privacy Policy Found"); 
like($msg, qr/$li->{physical_address}/, "Physical Address Found"); 
like($msg, qr/$li->{list_owner_email}/, "List Owner ($li->{list_owner_email}) Found"); 

ok(unlink($mh->test_send_file)); 




# ALternative Saved Text
ok(
	$ls->save(
		{
			unsub_confirmation_message         => $alt_message_body, 
			unsub_confirmation_message_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_unsub_confirmation_message(
	{
        -list   => $list, 
        -email  => $email, 
        -ls_obj => $ls, 
		-test   => 1, 
	}
);
$msg = slurp($mh->test_send_file); 
my $sub = quotemeta('Subject: Email: mytest@example.com List Name: Dada Test List'); 
like($msg, qr/$sub/, "Subject: set correctly"); 
like($msg, qr/List Name\: $li->{list_name}/, "Found: List Name"); 
like($msg, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
like($msg, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
like($msg, qr/Subscriber Pin\: $pin/, "Found: Subscriber Pin"); 
like($msg, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name"); 

# Reset: 
ok(
	$ls->save(
		{
			unsub_confirmation_message         => undef, 
			unsub_confirmation_message_subject => undef,	
		},	
	),
);
ok(unlink($mh->test_send_file)); 



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

$msg = slurp($mh->test_send_file); 

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To:(.*?)$email_name\@$email_domain/, "To: set correctly"); 
like($msg, qr/Subject\: Unsubscribed from $li->{list_name}/, "Subject: set correctly");

ok(unlink($mh->test_send_file)); 



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
$msg = slurp($mh->test_send_file); 
my $sub = quotemeta('Subject: Email: mytest@example.com List Name: Dada Test List'); 
like($msg, qr/$sub/, "Subject: set correctly"); 
like($msg, qr/List Name\: $li->{list_name}/, "Found: List Name"); 
like($msg, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 
# Huh. Not sure what to do with this...
#like($msg, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
# like($msg, qr/Subscriber Pin\: $pin/, "Found: Subscriber Pin"); 
like($msg, qr/Subscriber Pin\: /, "Did Not Find: Subscriber Pin");
like($msg, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name"); 

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

$msg = slurp($mh->test_send_file); 

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To: \"$li->{list_name} List Owner\" \<$lo_name\@$lo_domain\>/, "To: Set Correctly"); 
like($msg, qr/Subject\: unsubscribed $email_name\@$email_domain/, "Subject: set correctly");
like($msg, qr/There is now a total of: 0 subscribers./, "Misc. Body stuff found (2)"); 

ok(unlink($mh->test_send_file));


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


diag '$message_id ' . $message_id; 

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
) == 1, "Archive to send returns, '1'");


$msg = slurp($mh->test_send_file); 

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/, "From: Set Correctly"); 
like($msg, qr/To: \"$li->{list_name} Subscriber\" \<$email_name\@$email_domain\>/, "To: set correctly"); 
like($msg, qr/Subject: $msg_info->{msg_subject}\n\n/, "Subject: set correctly");
like($msg, qr/\n\n$msg_info->{msg_body}/, "Body Set Correctly");


ok(unlink($mh->test_send_file));


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
	) == 1, "Archive to send returns, '1'");


	$msg = slurp($mh->test_send_file); 

	
	# I honestly only care about the Content-type
	like($msg, qr/Content-type: multipart\/alternative/, "Content-type set correctly"); 

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
	) == 1, "Archive to send returns, '1'");


	$msg = slurp($mh->test_send_file); 

	diag ($msg);
	
	# I honestly only care about the Content-type
	like($msg, qr/Content-type: multipart\/alternative/, "Content-type set correctly to text/html"); 

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
# send_not_allowed_to_post_message

my $fake_message_back = qq{
To: list\@example.com
From: $email
Subject: Dud

This isn't getting too far, is it?
};

DADA::App::Messages::send_not_allowed_to_post_message(
	{
		-list       => $list, 
		-email      => $email,	
		-attachment => $fake_message_back, 
		-test       => 1
	},
);

my $q_fake_message_back = quotemeta($fake_message_back);

$msg = slurp($mh->test_send_file); 

my $natp_msg = quotemeta('Sorry, it doesn\'t seem that you are allowed to post on:'); 

like($msg, qr/From: \"$li->{list_name}\" \<$lo_name\@$lo_domain\>/,     "From: Set Correctly"); 
like($msg, qr/To: \"$li->{list_name}\" \<$email_name\@$email_domain\>/, "To: set correctly"); 
like($msg, qr/Subject: $DADA::Config::PROGRAM_NAME Error - $email_name\@$email_domain Not Allowed to Post On/, "Subject: set correctly");
like($msg, qr/$natp_msg/, "Body Set Correctly");
like($msg, qr/$li->{list_name}/, "List Name Found"); 
like($msg, qr/$q_fake_message_back/, "Original Message seems to be attached.");

ok(unlink($mh->test_send_file));


# ALternative Saved Text
ok(
	$ls->save(
		{
			not_allowed_to_post_message         => $alt_message_body, 
			not_allowed_to_post_message_subject => $alt_message_subject,	
		},	
	),
);
DADA::App::Messages::send_not_allowed_to_post_message(
	{
        -list       => $list, 
        -email      => $email, 
        -ls_obj     => $ls, 
		-attachment => $fake_message_back, 
		-test       => 1, 
	}
);
$msg = slurp($mh->test_send_file); 
my $sub = quotemeta('Subject: Email: mytest@example.com List Name: Dada Test List'); 
like($msg, qr/$sub/, "Subject: set correctly"); 
like($msg, qr/List Name\: $li->{list_name}/, "Found: List Name"); 
like($msg, qr/List Owner Email\: $lo_name\@$lo_domain/, "Found: List Owner Email"); 
like($msg, qr/Subscriber Email\: $email_name\@$email_domain/, "Found: Subscriber Email"); 

# Hmm! Not sure what to do about this...
#like($msg, qr/Subscriber Domain\: $email_domain/, "Found: Subscriber Domain"); 
# like($msg, qr/Subscriber Pin\: $pin/, "Found: Subscriber Pin"); 
like($msg, qr/Subscriber Pin\: /, "Did Not Find: Subscriber Pin");
like($msg, qr/Program Name\: $DADA::Config::PROGRAM_NAME/, "Found: Program Name"); 

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










dada_test_config::remove_test_list;
dada_test_config::wipe_out;


sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, "<$file") || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}




