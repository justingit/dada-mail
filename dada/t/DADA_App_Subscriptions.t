#!/usr/bin/perl -w
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use Test::More qw(no_plan);  

use DADA::Config;
use Dada::App::Guts; 
use DADA::App::Subscriptions; 
use DADA::MailingList::Settings; 
use DADA::MailingList::Subscribers; 

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
	$regex = quotemeta('Location: ' . 'http://example.com/confirm_failed.html?list=' . $list . '&rm=sub_confirm&status=0&email=&error=invalid_email'); 
	like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/);

	$q->param('email', 'bad'); 

	$regex = quotemeta('Location: ' . 'http://example.com/confirm_failed.html?list=' . $list . '&rm=sub_confirm&status=0&email=bad&error=invalid_email'); 
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

$regex = '<h1>Please confirm your mailing list subscription</h1>';
like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/); 

my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
ok($lh->check_for_double_email(-Email => $email, -Type => 'sub_confirm_list')); 

$q->param('list', ''); 
$q->param('email', ''); 
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

	$regex = '<h1>Please confirm your mailing list subscription</h1>';
	like($dap->subscribe({-cgi_obj => $q,}), qr/$regex/, 'subscribe');

	my $confirm_email = slurp($mh->test_send_file); 

	like($confirm_email, qr/To:(.*?)subscribe\@example.com/, "To: set correctly"); 
	like($confirm_email, qr/Subject\: Dada Test List Mailing List Subscription Confirmation/, "Subject: set correctly"); 
	
	my $pin = DADA::App::Guts::make_pin(-Email => $email, -List => $list); 
	
	my $confirm_url = quotemeta($DADA::Config::PROGRAM_URL . '/n/dadatest/subscribe/example.com/'.$pin.'/'); 
	
	like($confirm_email, qr/$confirm_url/, 'Confirmation link found and correct.'); 
	
	ok($lh->check_for_double_email(-Email => $email, -Type => 'sub_confirm_list')); 
	
	ok(unlink($mh->test_send_file)); 
	
# Step #2: Confirm: 

	$q->param('pin', $pin);
	
	$regex = quotemeta('<h1>Subscription is successful!</h1>'); 
	like($dap->confirm({-cgi_obj => $q}), qr/$regex/);

	ok($lh->check_for_double_email(-Email => $email, -Type => 'list')); 
	ok($lh->check_for_double_email(-Email => $email, -Type => 'sub_confirm_list') == 0); 
	
	my $subscribed_email = 	slurp($mh->test_send_file); 
	
	# There's going to be two emails in this file... 
	#
	like($subscribed_email, qr/To:(.*?)subscribe\@example\.com/, "To: set correctly"); 
	like($subscribed_email, qr/Subject\: Welcome to Dada Test List/, "Subject: set correctly"); 

	like($subscribed_email, qr/To\: \"Dada Test List List Owner\" \<test\@example\.com\>/, "To: set correctly (2)"); 
	like($subscribed_email, qr/Subject\: subscribed subscribe\@example\.com/, "Subject: set correctly (2)");
	
	$q->param('pin', '');
	ok(unlink($mh->test_send_file)); 
		
# Step #3: Unsubscribe: 

	$regex = '<h1>Please confirm your mailing list unsubscription</h1>';
	like($dap->unsubscribe({-cgi_obj => $q,}), qr/$regex/);
	ok($lh->check_for_double_email(-Email => $email, -Type => 'unsub_confirm_list')); 

	my $confirm_email = slurp($mh->test_send_file); 

 	$confirm_url = quotemeta($DADA::Config::PROGRAM_URL . '/u/dadatest/subscribe/example.com/'.$pin.'/'); 
	like($confirm_email, qr/$confirm_url/, 'Unsub Confirmation link found and correct.');
	
	like($confirm_email, qr/To:(.*?)subscribe\@example.com/, "To: set correctly"); 
	like($confirm_email, qr/Subject\: Dada Test List Mailing List Unsubscription Confirmation/, "Subject: set correctly"); 
	
	unlink($mh->test_send_file);
	
# Step #4: Confirm the Unsubscription:

	$q->param('pin', $pin); 
	
	$regex = '<h1>You have been unsubscribed from the list:';
	like($dap->unsub_confirm({-cgi_obj => $q,}), qr/$regex/);
	ok($lh->check_for_double_email(-Email => $email, -Type => 'unsub_confirm_list') == 0); 
	ok($lh->check_for_double_email(-Email => $email, -Type => 'list') == 0);
	
	my $unsubscribed_email = slurp($mh->test_send_file); 
	
	# There's going to be two emails in this file... 
	#
	like($unsubscribed_email, qr/To:(.*?)subscribe\@example\.com/, "To: set correctly"); 
	like($unsubscribed_email, qr/Subject\: Unsubscribed from Dada Test List/, "Subject: set correctly"); 

	like($unsubscribed_email, qr/To\: \"Dada Test List List Owner\" \<test\@example\.com\>/, "To: set correctly (2)"); 
	like($unsubscribed_email, qr/Subject\: unsubscribed subscribe\@example\.com/, "Subject: set correctly (2)");
	
	unlink($mh->test_send_file);	
	
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




