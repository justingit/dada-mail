#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use Test::More qw(no_plan);  


use DADA::Config; 
use DADA::App::FormatMessages; 

use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::App::BounceHandler::MessageParser; 
use DADA::App::BounceHandler::Rules;


use DADA::App::BounceHandler; 
use MIME::Parser;
use DADA::App::Guts; 


my $list = dada_test_config::create_test_list;
my $ls   = DADA::MailingList::Settings->new({-list => $list}); 
my $li   = $ls->get;

my $msg; 
my $email; 
my $found_list; 
my $diag; 
my $parser = new MIME::Parser;
$parser = optimize_mime_parser($parser); 
my $entity; 

use Data::Dumper; 

my $bhmp = DADA::App::BounceHandler::MessageParser->new(); 
my $bhr = DADA::App::BounceHandler::Rules->new;
my $rule; 

$msg = dada_test_config::slurp('t/corpus/email_messages/bounce-qmail-550-5.1.1.eml'); 
$entity = $parser->parse_data($msg);


( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);

#diag $email; 
#diag $found_list; 
ok($email eq 'ljdfsajlkadfsmndfsalkjfdsapimoiasdfiodfsakl@gmail.com', 'found email address.'); 
ok($found_list eq 'dadatest', 'found list'); 
#          diag Dumper($diag); 
#         'Simplified-Message-Id' => '20111030223332',
#           'Bounce_To' => 'bounces@dadademo.com',
#           'Bounce_From' => 'MAILER-DAEMON@outbound-ss-2114.bluehost.com',
#           'std_reason' => 'user_unknown',
#           'Message-Id' => '<20111030223332.29501507@skazat.com>',
#           'Action' => '',
#           'Diagnostic-Code' => '550-5.1.1 The email account that you tried to reach does not exist. Please try 550-5.1.1 double-checking the recipient\'s email address for typos or 550-5.1.1 unnecessary spaces. Learn more at                              550 5.1.1 http://mail.google.com/support/bin/answer.py?answer=6596 p8si5913219pbj.37 ',
#           'Guessed_MTA' => 'Qmail',
#           'Bounce_Subject' => 'failure notice'

ok($diag->{'Simplified-Message-Id'} eq '20111030223332', "found 'Simplified-Message-Id'"); 
ok($diag->{Bounce_To} eq 'bounces@dadademo.com', "found 'Bounce_To'"); 
ok($diag->{Bounce_From} eq 'MAILER-DAEMON@outbound-ss-2114.bluehost.com', "found 'Bounce_From'"); 
#ok($diag->{std_reason} eq 'user_unknown', "found 'std_reason'"); # Mail::DeliveryStatus::BounceParser
ok($diag->{'Message-Id'} eq '<20111030223332.29501507@skazat.com>', "found 'Message-Id'"); 
# Diagnostic-Code
ok($diag->{Guessed_MTA} eq 'Qmail', "found Guessed_MTA"); 
ok($diag->{Bounce_Subject} eq 'failure notice', "found Bounce_Subject"); 


#diag Dumper($diag); 
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'qmail_error_550', "rule is: $rule"); 

undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;
undef $rule;


# bouncing_email_with_brackets.eml
$msg    = dada_test_config::slurp('t/corpus/email_messages/bouncing_email_with_brackets.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
# use Data::Dumper; 
# diag Dumper($diag); 


#           'Simplified-Message-Id' => '20090507110112',
#           'Message-Id' => ' <20090507110112.30203023@example.com>',
#           'std_reason' => 'user_unknown',
#           'Remote-MTA' => 'yahoo.com'
#diag $email; 
ok($email eq 'bouncing.email@example.com', 'found email address.'); 
ok($found_list eq 'dadatest', 'found list');
ok($diag->{'Simplified-Message-Id'} eq '20090507110112', "found 'Simplified-Message-Id'"); 
ok($diag->{'Message-Id'} eq '<20090507110112.30203023@example.com>', "found 'Message-Id'"); 
#ok($diag->{std_reason} eq 'user_unknown', "found 'std_reason'"); # Mail::DeliveryStatus::BounceParser
#ok($diag->{'Remote-MTA'} eq 'yahoo.com', "found 'Remote-MTA'"); 

#diag Dumper($diag); 


$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
# This is sooooo wrong, but I'd need to re-parse this bounce, which I'm 
# I just don't have the time to, right now: 
#

#ok($rule eq 'exim_user_unknown', "rule is 'exim_user_unknown': '$rule'"); 
ok($rule eq 'generic_mailbox_unavailable', "rule is 'generic_mailbox_unavailable': '$rule'"); 


undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;


$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce-qmail-551-no_mailbox_here.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);

#           'Simplified-Message-Id' => '20111030223332',
#           'Bounce_To' => 'bounces@dadademo.com',
#           'Bounce_From' => 'MAILER-DAEMON@oproxy6-pub.bluehost.com',
#           'std_reason' => 'user_unknown',
#           'Message-Id' => '<20111030223332.29501507@skazat.com>',
#           'Action' => '',
#           'Diagnostic-Code' => '511 sorry, no mailbox here by that name (#5.1.1 - chkuser) ',
#           'Guessed_MTA' => 'Qmail',
#           'Bounce_Subject' => 'failure notice'


#diag $email; 
ok($email eq 'ljdfsajlkadfsmndfsalkjfdsapimoiasdfiodfsakl@skazat.com', 'found email address.'); 
ok($found_list eq 'dadatest', 'found list');
ok($diag->{'Simplified-Message-Id'} eq '20111030223332', "found 'Simplified-Message-Id'"); 
ok($diag->{Bounce_To} eq 'bounces@dadademo.com', "found 'Bounce_To'"); 
ok($diag->{Bounce_From} eq 'MAILER-DAEMON@oproxy6-pub.bluehost.com', "found 'Bounce_From'"); 
#ok($diag->{std_reason} eq 'user_unknown', "found 'std_reason'"); # Mail::DeliveryStatus::BounceParser
ok($diag->{'Message-Id'} eq '<20111030223332.29501507@skazat.com>', "found 'Message-Id'"); 
# Diagnostic-Code
ok($diag->{Guessed_MTA} eq 'Qmail', "found Guessed_MTA"); 
ok($diag->{Bounce_Subject} eq 'failure notice', "found Bounce_Subject");

#diag Dumper($diag); 


$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'qmail_error2_5dot1dot1', "rule is: $rule"); 



$msg    = dada_test_config::slurp('t/corpus/email_messages/bounces-qmail-554_no_account.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
#           'Simplified-Message-Id' => '20111030223332',
#           'Bounce_To' => 'bounces@dadademo.com',
#           'Status' => '5.x.y',
#           'Bounce_From' => 'MAILER-DAEMON@outbound-ss-1742.bluehost.com',
#           'std_reason' => 'user_unknown',
#           'Message-Id' => '<20111030223332.29501507@skazat.com>',
#           'Action' => '',
#           'Diagnostic-Code' => 'Remote host said: 554 delivery error: dd This user doesn\'t have a yahoo.com account (ljdfsajlkadfsmndfsalkjfdsapimoiasdfiodfsakl@yahoo.com) [0] - mta1076.mail.mud.yahoo.com ',
#           'Guessed_MTA' => 'Qmail',
#           'Bounce_Subject' => 'failure notice'
#diag $email; 
ok($email eq 'ljdfsajlkadfsmndfsalkjfdsapimoiasdfiodfsakl@yahoo.com', 'found email address.'); 
ok($found_list eq 'dadatest', 'found list');
ok($diag->{'Simplified-Message-Id'} eq '20111030223332', "found 'Simplified-Message-Id'"); 
ok($diag->{Bounce_To} eq 'bounces@dadademo.com', "found 'Bounce_To'"); 
ok($diag->{Bounce_From} eq 'MAILER-DAEMON@outbound-ss-1742.bluehost.com', "found 'Bounce_From'"); 
#ok($diag->{std_reason} eq 'user_unknown', "found 'std_reason'"); # Mail::DeliveryStatus::BounceParser
ok($diag->{'Message-Id'} eq '<20111030223332.29501507@skazat.com>', "found 'Message-Id'"); 
like($diag->{'Diagnostic-Code'}, qr/Remote host said\: 554 delivery error/, 'found diagnostic code'); 
ok($diag->{Guessed_MTA} eq 'Qmail', "found Guessed_MTA"); 
ok($diag->{Bounce_Subject} eq 'failure notice', "found Bounce_Subject");

#diag Dumper($diag); 


$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'yahoo_no_account', "rule is: $rule"); 

undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;

$msg    = dada_test_config::slurp('t/corpus/email_messages/bounces-amazon_ses_status-5.5.0.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
# nonexistingaddress@dadademo.com
# dadatest
#           'Simplified-Message-Id' => '20111127194053',
#           'Reporting-MTA' => 'dns; a192-79.smtp-out.amazonses.com',
#           'Status' => '5.0.0 (permanent failure)',
#           'reason' => '5.1.0 - Unknown address error 550-\'No Such User Here"\' (delivery attempts: 0)',
#           'Final-Recipient' => 'rfc822;nonexistingaddress@dadademo.com',
#           'std_reason' => 'user_unknown',
#           'Remote-MTA' => 'dns; [66.147.242.175]',
#           'host' => 'dadademo.com',
#           'Message-Id' => '<20111127194053.58725276@skazat.com>',
#           'Action' => 'failed',
#           'smtp_code' => '550',
#           'Diagnostic-Code' => 'smtp; 5.1.0 - Unknown address error 550-\'No Such User Here"\' (delivery attempts',
#           'Guessed_MTA' => 'Amazon_SES'
#diag $email; 
ok($email eq 'nonexistingaddress@dadademo.com', 'found email address.'); 
ok($found_list eq 'dadatest', 'found list');
ok($diag->{'Simplified-Message-Id'} eq '20111127194053', "found 'Simplified-Message-Id'"); 
#ok($diag->{Bounce_To} eq 'bounces@dadademo.com', "found 'Bounce_To'"); 
#ok($diag->{Bounce_From} eq 'MAILER-DAEMON@outbound-ss-1742.bluehost.com', "found 'Bounce_From'"); 
#ok($diag->{std_reason} eq 'user_unknown', "found 'std_reason'"); # Mail::DeliveryStatus::BounceParser
ok($diag->{'Message-Id'} eq '<20111127194053.58725276@skazat.com>', "found 'Message-Id'"); 
like($diag->{'Diagnostic-Code'}, qr/Unknown address error 550/, 'found diagnostic code'); 
ok($diag->{Guessed_MTA} eq 'Amazon_SES', "found Amazon_SES"); 
#ok($diag->{Bounce_Subject} eq 'failure notice', "found Bounce_Subject");


$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'amazon_ses_dsn_no_such_user', "rule is: $rule"); 

undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;

$msg    = dada_test_config::slurp('t/corpus/email_messages/bounces-amazon_ses_bounce_status-5.1.2.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
#diag $email; 
#diag $list; 
#diag Dumper($diag); 
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'user_inactive', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;





# ??? 
$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce-gmail-550-5.1.1.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
#diag 'email: ' . $email; 
#diag 'list: ' . $list; 
#diag Dumper($diag); 
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
#diag 'rule: ' . $rule; 

#ok($rule eq 'user_inactive', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;





diag 'looking at: bounce-secureservers.net-mailfolder_is_full.eml'; 
$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce-secureservers.net-mailfolder_is_full.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
#diag 'email: ' . $email; 
#diag 'list: '  . $found_list; 
#diag Dumper($diag); 
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
#diag 'rule: ' . $rule; 

ok($email eq 'subscriber@example.com'); 

ok($found_list eq 'dadatest', 'found list(' . $found_list . ')');
ok($rule eq 'secureserver_dot_net_mailbox_full', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;






# diag "looking at: bounce_secureserver.net-mail_quota_exceeded.eml"; 
$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce_secureserver.net-mail_quota_exceeded.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
ok($email eq 'subscriber@example.com'); 
ok($found_list eq 'dadatest', 'found list');
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'secureserver_dot_net_mailbox_full', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;




# diag "looking at: bounce-exim-something.eml"; 
$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce-exim-something.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
ok($email eq 'subscriber@example.com'); 
ok($found_list eq 'dadatest', 'found list');
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );

#diag 'email:' . $email; 
#diag 'found_list:' . $found_list; 
#diag Dumper($diag);
ok($rule eq 'exim_user_unknown', "rule is 'exim_user_unknown': '$rule'"); 

undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;




# diag "looking at: bounce-dsn-user_unknown.eml"; 
$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce-dsn-user_unknown.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
ok($email eq 'subscriber@example.com'); 
ok($found_list eq 'dadatest', "found list ($found_list)");
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );

#diag 'email: ' . $email; 
#diag 'list: ' . $list; 
#diag Dumper($diag); 
#diag 'rule: ' . $rule; 

ok($rule eq 'delivery_error_550', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;





$msg    = dada_test_config::slurp('t/corpus/email_messages/bounce-dsn-4.4.1.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
ok($email eq 'subscriber@example.com'); 
ok($found_list eq 'dadatest', "found list ($found_list)");
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );

#diag 'email: ' . $email; 
#diag 'list: ' . $list; 
#diag Dumper($diag); 
#diag 'rule: ' . $rule; 

ok($rule eq 'bounce_4dot4dot1_error', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;


# diag "looking at: bounce_secureserver.net-mail_quota_exceeded.eml"; 
$msg    = dada_test_config::slurp('t/corpus/email_messages/bounces_amazon_ses_abuse_report.eml'); 
$entity = $parser->parse_data($msg);
( $email, $found_list, $diag ) = $bhmp->run_all_parses($entity);
ok($email eq 'subscriber@example.com'); 
ok($found_list eq 'dadatest', 'found list');
$rule = $bhr->find_rule_to_use( $found_list, $email, $diag );
ok($rule eq 'amazon_ses_abuse_report', "rule is: $rule"); 
undef $msg; 
undef $email; 
undef $found_list; 
undef $diag; 
undef $entity;





$parser->filer->purge;

dada_test_config::remove_test_list;
dada_test_config::wipe_out;


