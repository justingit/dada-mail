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
use DADA::App::Subscriptions; 
use DADA::MailingList::Settings; 
use DADA::MailingList::Subscribers; 

my $log = ''; 

use MIME::Parser; 
my $parser = new MIME::Parser; 
   $parser = optimize_mime_parser($parser);


use CGI;
my $q = CGI->new; 
   $q = decode_cgi_obj($q);


my %orig = %DADA::Config::LIST_SETUP_DEFAULTS;
delete($orig{list}); 

my $list = dada_test_config::create_test_list;


my $dap = DADA::App::Subscriptions->new; 
   $dap->test(1);

ok($dap->test == 1, "Testing is on..."); 


### sub subscribe 

# sub-subscribe-no-cgi
# 
eval{ $dap->subscribe();};
like($@, qr/No CGI Object/);

# sub-subscribe-redirect-error_invalid_list
my $regex = quotemeta('Location: ' . $DADA::Config::PROGRAM_URL . '?error_invalid_list=1'); 
like($dap->subscribe({-cgi_obj => $q}), qr/$regex/, 'sub-subscribe-redirect-error_invalid_list');





# sub-subscribe-redirect-error_no_email
$q->param('list', $list); 
$regex = quotemeta('Location: ' . $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=s'); 
like($dap->subscribe({-cgi_obj => $q}), qr/$regex/, 'sub-subscribe-redirect-error_no_email'); 
$q->param('list', ''); 



# sub-subscribe-alt_url_sub_confirm_failed
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	$ls->save(
		{
			use_alt_url_sub_confirm_failed => 1, 
			alt_url_sub_confirm_failed     => 'http://example.com/confirm_failed.html', 
			# alt_url_sub_confirm_failed_w_qs
		}
	);


	$q->param('list', $list); 
	$regex = quotemeta('Location: ' . 'http://example.com/confirm_failed.html'); 
	like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/);


	$ls->save(
		{
			use_alt_url_sub_confirm_failed  => 1, 
			alt_url_sub_confirm_failed      => 'http://example.com/confirm_failed.html', 
			alt_url_sub_confirm_failed_w_qs => 1, 
		}
	);
	$regex = quotemeta('Location: ' . 'http://example.com/confirm_failed.html?list=' . $list . '&rm=sub_confirm&status=0&email=&errors[]=invalid_email'); 
	like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/);

	$q->param('email', 'bad'); 

	$regex = quotemeta('Location: ' . 'http://example.com/confirm_failed.html?list=' . $list . '&rm=sub_confirm&status=0&email=bad&errors[]=invalid_email'); 
	like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/);

	$q->param('email', ''); 
	$q->param('list', ''); 
	undef $regex; 

	$ls->save(
		{
			use_alt_url_sub_confirm_failed  => 0, 
			alt_url_sub_confirm_failed      => '', 
			alt_url_sub_confirm_failed_w_qs => 0, 
		}
	);

	# 




# sub_confirm-sub_confirm_success

my $email = 'this@example.com'; 

$q->param('email', $email); 
$q->param('list',  $list );

$regex = '<h1>Please Confirm Your Mailing List Subscription</h1>';
like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/); 

my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
ok(
	$lh->check_for_double_email(
		-Email => $email, 
		-Type => 'sub_confirm_list'
	),
	"check_for_double_email returned 1"
	); 

$q->param('list', ''); 
$q->param('email', ''); 

# Check the logs? 
$log = slurp($DADA::Config::PROGRAM_USAGE_LOG); 
# [Thu Apr  1 22:47:58 2010]	dadatest		Subscribed to dadatest.sub_confirm_list	this@example.com
like($log, qr/\t$list\t(.*?)\tSubscribed to $list\.sub_confirm_list\t$email/, "usage log entry found");
# Let's remove the log, for the next time! 
unlink($DADA::Config::PROGRAM_USAGE_LOG); 
undef $log; 
# 




# sub confirm

# sub-confirm-no-cgi
# 
eval{ $dap->confirm();};
like($@, qr/No CGI Object/);


# sub-confirm-redirect-error_invalid_list
$regex = quotemeta('Location: ' . $DADA::Config::PROGRAM_URL . '?error_invalid_list=1'); 
like($dap->confirm({-cgi_obj => $q}), qr/$regex/, 'sub-confirm-redirect-error_invalid_list');



# sub-confirm-redirect-error_no_email

$q->param('list', $list); 
$q->param('email', ''); 
$regex = quotemeta('Location: ' . $DADA::Config::PROGRAM_URL . '?f=list&list=' . $list . '&error_no_email=1&set_flavor=s'); 
like($dap->confirm({-cgi_obj => $q}), qr/$regex/, 'sub-confirm-redirect-error_no_email'); 
$q->param('list', '');
$q->param('email', '');



# Lets try the whole process
# Example #1: A quick and easy subscription successful! 

	my $li = $ls->get; 
	
	require DADA::Mail::Send; 
	my $mh = DADA::Mail::Send->new({-list => $list}); 
# Step #1: Subscribe:

	$email = 'subscribe@example.com'; 
	$q->param('email', $email); 
	$q->param('list', $list); 

	$regex = '<h1>Please Confirm Your Mailing List Subscription</h1>';
	like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/, 'subscribe');

	my $confirm_email = slurp($mh->test_send_file); 
	my $entity = $parser->parse_data($confirm_email); 
	

	like($confirm_email, qr/To:(.*?)subscribe\@example.com/, "To: set correctly"); 
	#like($confirm_email, qr/Subject\: Dada Test List Mailing List Subscription Confirmation/, "Subject: set correctly"); 
	ok(
		decode_header($entity->head->get('Subject', 0))
		eq
		"$li->{list_name} Mailing List Subscription Confirmation", 
		"Subject: Set Correctly"
	);
	
	my $pin = DADA::App::Guts::make_pin(-Email => $email, -List => $list); 
	
	my $confirm_url = quotemeta($DADA::Config::PROGRAM_URL . '/n/dadatest/subscribe/example.com/'.$pin.'/'); 

	TODO: {
	    local $TODO = 'Looks like there is a bug in the test itself - the message needs to be decoded from quoted-printable, but this needs to be double-checked.';	
			like($confirm_email, qr/$confirm_url/, 'Confirmation link found and correct.'); 
	}
	
	ok($lh->check_for_double_email(-Email => $email, -Type => 'sub_confirm_list'), 'check_for_double_email'); 
	
	ok(unlink($mh->test_send_file)); 
	undef $confirm_email; 
	undef $entity; 
	
	# Check the logs? 
	$log = slurp($DADA::Config::PROGRAM_USAGE_LOG); 
	# [Thu Apr  1 22:47:59 2010]	dadatest		Subscribed to dadatest.sub_confirm_list	subscribe@example.com
	like($log, qr/\t$list\t(.*?)\tSubscribed to $list\.sub_confirm_list\t$email/, "usage log entry found");
	# [Thu Apr  1 22:47:59 2010]	dadatest		Subscription Confirmation Sent for dadatest.list	subscribe@example.com
	like($log, qr/\t$list\t(.*?)\tSubscription Confirmation Sent for $list\.list\t$email/, "usage log entry found");
	# Let's remove the log, for the next time! 
	unlink($DADA::Config::PROGRAM_USAGE_LOG); 
	undef $log; 
	#
	


# Step #2: Confirm: 

	$q->param('pin', $pin);
	
	$regex = quotemeta('<h1>Your Mailing List Subscription is Successful</h1>'); 
	like($dap->confirm({-cgi_obj => $q}), qr/$regex/);

	ok($lh->check_for_double_email(-Email => $email, -Type => 'list'), 'check_for_double_email'); 
	ok($lh->check_for_double_email(-Email => $email, -Type => 'sub_confirm_list') == 0, 'check_for_double_email'); 
	
	my $msg = 	slurp($mh->test_send_file); 
	   $entity = $parser->parse_data($msg); 

=cut
I kind of screwed this up: 

# There's going to be two emails in this file... 
#
like($subscribed_email, qr/To:(.*?)subscribe\@example\.com/, "To: set correctly"); 
like($subscribed_email, qr/Subject\: Welcome to Dada Test List/, "Subject: set correctly"); 

like($subscribed_email, qr/To\: \"Dada Test List List Owner\" \<test\@example\.com\>/, "To: set correctly (2)"); 
like($subscribed_email, qr/Subject\: subscribed subscribe\@example\.com/, "Subject: set correctly (2)");

=cut

TODO: {
    local $TODO = 'Looks like there is a bug in the test itself - the message needs to be decoded from quoted-printable, but this needs to be double-checked.';	

	ok(
		decode_header($entity->head->get('To', 0))
		eq
		"\"$li->{list_name} Subscriber\" \<subscribe\@example\.com\>", 
		"To: Set Correctly (" . "\"$li->{list_name} Subscriber\" \<subscribe\@example\.com\>" . ") equals (" . decode_header($entity->head->get('To', 0)) . ")"
	);

}
ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"Welcome to $li->{list_name}", 
	"Subject: Set Correctly"
);

# Check the logs? 
$log = slurp($DADA::Config::PROGRAM_USAGE_LOG); 

# [Thu Apr  1 22:47:59 2010]	dadatest		Unsubscribed from dadatest.sub_confirm_list	subscribe@example.com
# [Thu Apr  1 22:47:59 2010]	dadatest		Subscribed to dadatest.list	subscribe@example.com
like($log, qr/\t$list\t(.*?)\tUnsubscribed from $list\.sub_confirm_list\t$email/, "usage log entry found");
like($log, qr/\t$list\t(.*?)\tSubscribed to $list\.list\t$email/, "usage log entry found");
# Let's remove the log, for the next time! 
unlink($DADA::Config::PROGRAM_USAGE_LOG); 
undef $log; 
#




	$q->param('pin', '');
	ok(unlink($mh->test_send_file)); 
	undef $msg; 
	undef $entity; 
	

	
# Step #3: Unsubscribe: 

	$regex = '<h1>Please Confirm Your Mailing List Unsubscription</h1>';
	like($dap->unsubscribe({-cgi_obj => $q,}), qr/$regex/);
	ok($lh->check_for_double_email(-Email => $email, -Type => 'unsub_confirm_list'), 'check_for_double_email'); 

	$msg = slurp($mh->test_send_file); 
	$entity = $parser->parse_data($msg); 
	
 	$confirm_url = quotemeta($DADA::Config::PROGRAM_URL . '/u/dadatest/subscribe/example.com/'.$pin.'/'); 

	TODO: {
	    local $TODO = 'Looks like there is a bug in the test itself - the message needs to be decoded from quoted-printable, but this needs to be double-checked.';	

	like($msg, qr/$confirm_url/, 'Unsub Confirmation link found and correct.');
};
	
#	like($msg, qr/To:(.*?)subscribe\@example.com/, "To: set correctly"); 
#	like($msg, qr/Subject\: Dada Test List Mailing List Unsubscription Confirmation/, "Subject: set correctly"); 
TODO: {
    local $TODO = 'Looks like there is a bug in the test itself - the message needs to be decoded from quoted-printable, but this needs to be double-checked.';	


ok(
	decode_header($entity->head->get('To', 0))
	eq
	"\"$li->{list_name} Subscriber\" \<subscribe\@example\.com\>", 
	"To: Set Correctly"
);

};

ok(
	decode_header($entity->head->get('Subject', 0))
	eq
	"$li->{list_name} Mailing List Unsubscription Confirmation", 
	"Subject: Set Correctly"
);

# Check the logs? 
$log = slurp($DADA::Config::PROGRAM_USAGE_LOG); 

# [Thu Apr  1 22:48:00 2010]	dadatest		Unsubscription Confirmation Sent for dadatest.list	subscribe@example.com
# [Thu Apr  1 22:48:00 2010]	dadatest		Subscribed to dadatest.unsub_confirm_list	subscribe@example.com
like($log, qr/\t$list\t(.*?)\tUnsubscription Confirmation Sent for $list\.list\t$email/, "usage log entry found");
like($log, qr/\t$list\t(.*?)\tSubscribed to $list\.unsub_confirm_list\t$email/, "usage log entry found");

# Let's remove the log, for the next time! 
unlink($DADA::Config::PROGRAM_USAGE_LOG); 
undef $log; 
#

	
	unlink($mh->test_send_file);
	undef $msg; 
	undef $entity; 
	

	
# Step #4: Confirm the Unsubscription:

	$q->param('pin', $pin); 
	
	$regex = '<h1>Unsubscription is Successful</h1>';
	like($dap->unsub_confirm({-cgi_obj => $q,}), qr/$regex/);
	ok($lh->check_for_double_email(-Email => $email, -Type => 'unsub_confirm_list') == 0, 'check_for_double_email'); 
	ok($lh->check_for_double_email(-Email => $email, -Type => 'list') == 0, 'check_for_double_email');
	
	my $unsubscribed_email = slurp($mh->test_send_file); 

	
	# There's going to be two emails in this file... 
	#
=cut

	like($unsubscribed_email, qr/To:(.*?)subscribe\@example\.com/, "To: set correctly"); 
	like($unsubscribed_email, qr/Subject\: Unsubscribed from Dada Test List/, "Subject: set correctly"); 

	like($unsubscribed_email, qr/To\: \"Dada Test List List Owner\" \<test\@example\.com\>/, "To: set correctly (2)"); 
	like($unsubscribed_email, qr/Subject\: unsubscribed subscribe\@example\.com/, "Subject: set correctly (2)");
=cut
	
	
# Check the logs? 
$log = slurp($DADA::Config::PROGRAM_USAGE_LOG); 

# [Thu Apr  1 22:48:00 2010]	dadatest		Unsubscribed from dadatest.unsub_confirm_list	subscribe@example.com
# [Thu Apr  1 22:48:00 2010]	dadatest		Subscribed to dadatest.black_list	subscribe@example.com
# [Thu Apr  1 22:48:00 2010]	dadatest		Unsubscribed from dadatest.list	subscribe@example.com
like($log, qr/\t$list\t(.*?)\tUnsubscribed from $list\.unsub_confirm_list\t$email/, "usage log entry found");
like($log, qr/\t$list\t(.*?)\tSubscribed to $list\.black_list\t$email/, "usage log entry found");
like($log, qr/\t$list\t(.*?)\tUnsubscribed from $list\.list\t$email/, "usage log entry found");


# Let's remove the log, for the next time! 
unlink($DADA::Config::PROGRAM_USAGE_LOG); 
undef $log; 
#
	
	
	unlink($mh->test_send_file);	
	
# So what happens, if we try to unsubscribe an address, that's not subscribed? 


$q->param('email', 'notsubscribed@example.com'); 
$q->param('list',  $list );
$q->param('pin', '');
$q->param('f',  'u' );

# First, we're going to do the test, getting the, "you're not subscribed"
# error in our browser: 
$ls->param('email_you_are_not_subscribed_msg', 0); 
$regex = 'begin error_not_subscribed_screen';
like($dap->unsubscribe({-cgi_obj => $q,}), qr/$regex/, "Got the, error_not_subscribed_screen template in browser!"); 
# Now, we're going to do the same, but let's turn the email-notification stuff on: 
$q->param('email', 'notsubscribed2@example.com'); 
$ls->param('email_you_are_not_subscribed_msg', 1);
$regex = 'Please Confirm Your Mailing List Unsubscription';
like($dap->unsubscribe({-cgi_obj => $q,}), qr/$regex/, "Please Confirm Your Mailing List Unsubscription"); 
$regex = 'You Are Not Subscribed'; # or, whatever. 
like(slurp($mh->test_send_file), qr/$regex/, "Got the, You Are Not Subscribed message!"); 
unlink($mh->test_send_file);

# Now, turn Closed Loop Opt-Out off: 
$ls->param('unsub_confirm_email', 0); 
# Should give the same report, no? 
$q->param('email', 'notsubscribed3@example.com'); 
$q->param('list',  $list );
$q->param('pin', '');
$q->param('f',  'u' );

# First, we're going to do the test, getting the, "you're not subscribed"
# error in our browser: 
$ls->param('email_you_are_not_subscribed_msg', 0); 
$regex = 'begin error_not_subscribed_screen';
my $foo = $dap->unsubscribe({-cgi_obj => $q,}); 
like($foo, qr/$regex/, "Got the, error_not_subscribed_screen template in browser!"); 
# Now, we're going to do the same, but let's turn the email-notification stuff on: 
$q->param('email', 'notsubscribed4@example.com'); 
$ls->param('email_you_are_not_subscribed_msg', 1);
$regex = 'Please Confirm Your Mailing List Unsubscription';
like($dap->unsubscribe({-cgi_obj => $q,}), qr/$regex/, "Please Confirm Your Mailing List Unsubscription"); 
$regex = 'You Are Not Subscribed'; # or, whatever. 
like(slurp($mh->test_send_file), qr/$regex/, "Got the, You Are Not Subscribed message!"); 
unlink($mh->test_send_file);


	


dada_test_config::remove_test_list;
dada_test_config::wipe_out;

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


sub decode_header { 
	my $header = shift; 
	require MIME::EncWords; 
	my $dec_header = MIME::EncWords::decode_mimewords($header, Charset => '_UNICODE_'); 
	return $dec_header; 
}
