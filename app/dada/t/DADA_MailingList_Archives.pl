#!/usr/bin/perl
use strict; 

use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


# This doesn't work, if we're eval()ing it. 
# use Test::More qw(no_plan); 

diag('$DADA::Config::ARCHIVE_DB_TYPE ' . $DADA::Config::ARCHIVE_DB_TYPE); 

my $list = 'dadatest'; 

my $list_params = { 

        list             =>  $list, 
        list_name        => 'Justin!', 
        list_owner_email => 'user@example.com',  
        password         => 'abcd', 
        retype_password  => 'abcd', 
        info             => 'info', 
        privacy_policy   => 'privacy_policy',
        physical_address => 'physical_address', 

};

my $msg_info = {

msg_subject => "This is the Message Subject", 
msg_body    => "This is the Message Body", 
'format'    => 'text/plain', 

};


#diag ('$msg_info->{msg_body} ' . $msg_info->{msg_body}); 

use DADA::App::Guts; 
use DADA::MailingList; 
use DADA::MailingList::Archives; 

# This is just so we don't make stupid mistakes right off the bat!

my ($list_errors,$flags) = check_list_setup(-fields => $list_params);
ok($list_errors == 0); 



# ok ok ok! We'll actually make the list...
my $l_list_params = $list_params; 
delete($list_params->{retype_password}); 
my $ls = DADA::MailingList::Create(
	{
		-list     => $l_list_params->{list},
		-settings => $l_list_params, 
		-test     => 0,
	}
); 

  
# Let's try saving something in the archives: 

# Short and quick...
my $message_id = DADA::App::Guts::message_id(); 

my $li = $ls->get; 
my $mla = DADA::MailingList::Archives->new({-list => $list});

ok(defined $mla,                        'new() returned something, good!' );
ok( $mla->isa('DADA::MailingList::Archives'),   "  and it's the right class" );

ok($mla->num_archives == 0, "no archive entries."); 


#$archive -> set_archive_info($subject, $message, $format, $raw_msg);

# Note passing a message_id will return undef and give back a warning. 
my $set_return_fail = $mla->set_archive_info(undef, $msg_info->{msg_subject}, $msg_info->{msg_body}, $msg_info->{'format'}); 
ok($set_return_fail eq undef, "adding a new archive entry without a message id returns undef!"); 


#die ' $msg_info->{msg_body} '; 

my $set_return_pass = $mla->set_archive_info($message_id, $msg_info->{msg_subject}, $msg_info->{msg_body}, 'text/plain'); 
ok($set_return_pass == 1, "adding a new archive entry *with* a message id returns 1!"); 

my $exists = $mla->check_if_entry_exists($message_id); 
ok($exists == 1, "check_if_entry_exists says our archived message exists!"); 


ok($mla->num_archives == 1, "1 archive entries.");


my $entries = $mla->get_archive_entries(); 

my @match_entries = grep { $_ == $message_id } @$entries; 


ok($match_entries[0] == $message_id, "get_archive_entries() returns our message!"); 


my ($subject, $message, $format, $raw_msg) = $mla->get_archive_info($message_id); 

ok(defined($subject), "get returns the subject");
ok(defined($message), "get returns the message");
ok(defined($format), "get returns the format");
ok(defined($raw_msg), "get returns the raw_msg");

ok($subject eq $msg_info->{msg_subject}, "message subject matched what we saved."); 
ok($message eq $msg_info->{msg_body},    "message body matched what we saved."); 
ok($format eq $msg_info->{'format'},    "message format matched what we saved."); 

my $message_blurb = $mla->message_blurb(-key => $message_id); 
 
#ok(defined($message_blurb), "message_blurb returned something");
 
my $atom = $mla->atom_index(); 
my $rss = $mla->rss_index(); 

ok(defined($atom), "we have an atom index"); 
ok(defined($rss),  "we have an rss index"); 


if($DADA::Config::ARCHIVE_DB_TYPE =~ m/SQL/i){ 
    ok($mla->can_display_attachments == 1, "Yes!, can display them attachments"); 
    ok($mla->can_display_message_source == 1, "Yes!, can display message source!"); 
    
    
} else { 
    ok($mla->can_display_attachments == 0, "Nope, can't display them attachments");
    ok($mla->can_display_message_source == 0, "Nope, can't display message source!"); 
}




my $Remove = DADA::MailingList::Remove({ -name => $list }); 
ok($Remove == 1, "Remove returned a status of, '1'");

dada_test_config::wipe_out;
