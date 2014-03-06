#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use Test::More qw(no_plan); 

use DADA::Config; 
use DADA::App::Guts; 
use DADA::Mail::MailOut; 
use DADA::MailingList; 


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



my $test_msg_fields = {
    From     => 'me@example.com',
    To       => 'you@example.com',
    Subject  => 'hey!',
    Body     => 'This is my body!', 
};






# This is just so we don't make stupid mistakes right off the bat!

my ($list_errors,$flags) = check_list_setup(-fields => $list_params);
ok($list_errors == 0, 'no list errors.'); 

my $broken_mailout = DADA::Mail::MailOut->new(); 
ok(!defined $broken_mailout, 'new() returned undef when no list was passed...' );

my $broken_mailout_two = DADA::Mail::MailOut->new({ -list => $list });
ok(!defined $broken_mailout_two,              'new() returned nothing with a non-existent list - good!' );




 my $l_list_params = $list_params; 
   delete($list_params->{retype_password}); 
my $ls = DADA::MailingList::Create(
	{
		-list     => $l_list_params->{list}, 
		-settings => $l_list_params,
		-test     => 0,

	}
); 
  

my $mailout = DADA::Mail::MailOut->new({ -list => $list });
ok(defined $mailout,                        'new() returned something, good!' );
ok( $mailout->isa('DADA::Mail::MailOut'),   "  and it's the right class" );






eval { $mailout->create() }; 
ok($@, "calling create without any parameters causes an error!: $@"); 
undef $mailout; 

$mailout = DADA::Mail::MailOut->new({ -list => $list });
eval { $mailout->create({ -fields => $test_msg_fields }) }; 
ok($@, "calling create with a '-fields' parameter, but no 'Message-ID' header in those fields causes an error!: $@"); 
undef $mailout; 


# Fine, look, we'll put it in: 
# pretty hairy testing of a correct message id header - note!
require DADA::Security::Password; 	
my $ran_number = DADA::Security::Password::generate_rand_string('1234567890');
$test_msg_fields->{'Message-ID'} = '<' .  DADA::App::Guts::message_id() . '.'. $ran_number . '@' . 'example.com' . '>'; 

$mailout = DADA::Mail::MailOut->new({ -list => $list });
eval { $mailout->create({ -fields => $test_msg_fields, -list_type => 'list' }) }; 
ok($@, "calling create with a '-fields' parameter, but no 'DADA::Mail::Send object causes an error!: $@"); 
undef $mailout; 

$mailout = DADA::Mail::MailOut->new({ -list => $list });
eval { $mailout->create({ -fields => $test_msg_fields, -mh_obj => "blah blah blah", -list_type => 'list' }) }; 
ok($@, "Not passing a correct DADA::Mail::Send object causes an error!: $@"); 
undef $mailout; 



# going to add some subscribers...

require DADA::MailingList::Subscribers; 
my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
my $count = 0; 
for(qw(
    email1@example.com
    email2@example.com
    email3@example.com
    email4@example.com
    )){ 
    $lh->add_subscriber(
        {
            -email => $_, 
            -type  => 'list', 
        }
    ); 
    $count++; 
}
ok($count == 4, "added four, told me I added four. Smashing.");                           





require DADA::Mail::Send;
require DADA::MailingList::Settings; 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $mh = DADA::Mail::Send->new({-list => $list}); 


ok($mh->isa('DADA::Mail::Send'), "DADA::Mail::Send is the right type of object..."); 


$mailout = DADA::Mail::MailOut->new({ -list => $list });
eval { $mailout->create({ -fields => $test_msg_fields, -mh_obj => $mh }) }; 
ok($@, "Not passing a -list_type causes an error!: $@"); 
undef $mailout; 



$mailout = DADA::Mail::MailOut->new({ -list => $list });
my $rv; 
   eval { $rv = $mailout->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 
ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
if($@){ 
	diag 'ERROR: ' . $@;
}

ok($rv == 1, " create() returns 1!"); 

my $status = $mailout->status(); 


ok(keys %$status, "status() returned a hashref!");



for my $in_stat(qw(
    id
    total_sending_out_num
    total_sent_out
    last_access
    email_fields
    type
    is_batch_locked
    percent_done
    )){ 
       # exists instead?
    ok(defined($status->{$in_stat}), "$in_stat present"); 

}

ok($status->{total_sending_out_num} == 5, "total sending out is: 5"); 


# This was here before?!
ok($mailout->is_batch_locked == 0, "Batch isn't locked..."); 


$mailout->batch_lock; 
ok($mailout->is_batch_locked == 1, "Batch is now locked..."); 



$mailout->unlock_batch_lock; 
ok($mailout->is_batch_locked == 0, "Batch is again unlocked..."); 



ok($mailout->counter_at == 0, "Counter is at 0..."); 



my $i = 1; 
for($i = 1; $i <= (int($status->{total_sending_out_num}) - 2); $i++){ 

       $mailout->countsubscriber; 
    ok($mailout->counter_at == $i, 'counter: ' . $mailout->counter_at . " == $i..."); 
}


# and let's make sure we lock the batching process...
$mailout->batch_lock;

#this should fail...
my $set_it = undef; 
eval { $set_it = $mailout->associate($status->{id}, $status->{type})}; 
#diag('set it is: ' . $set_it); 

ok($set_it == undef, "shouldn't be able to associate the mailout with a new id..."); 



ok($mailout->should_be_restarted == 0, "Hey! It doesn't think the mailout needs restarting. Dandy!"); 



eval { $mailout->reload(); }; 
ok($@, "attepting to reload causes error: $@"); 



# unlock this puppy...
$mailout->unlock_batch_lock; 

# let's kill our mailout..
undef $mailout; 




ok(DADA::Mail::MailOut::mailout_exists($list, $status->{id}, 'list') == 1, "Yeah, our mailout better exist..."); 



my $mailout_p = DADA::Mail::MailOut->new({ -list => $list }); 
ok($mailout_p->isa('DADA::Mail::MailOut'), "new mailout is the right type of object..."); 



$mailout_p->associate($status->{id}, $status->{type}); 
my $reloaded_msg = $mailout_p->reload(); 

ok(defined($reloaded_msg), "whoa hey, I have a message"); 



ok($mailout_p->counter_at == (int($status->{total_sending_out_num}) - 2), "and whe're at: " . $mailout_p->counter_at); 



ok($mailout_p->clean_up(), "cleanup returned a true value!"); 




my $broke_mailout_three = DADA::Mail::MailOut->new({ -list => $list });
# This should work....
ok(defined $broke_mailout_three,                        'new() returned something, good!' );
my $rv2; 
   eval { $rv2 = $broke_mailout_three->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 
# this should work
ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
# this should work
ok($rv2== 1, " create() returns 1!"); 
# this should return, 1
ok($broke_mailout_three->_integrity_check == 1, "Integrity is OK!");
# Time to break it...
# NOTE! 'counter.txt' is sort of a variable that you can set in the module, but there's no way to 
# find it's name via the API, so if this name gets changed, this test will then fail...
my $bm3_count = unlink($broke_mailout_three->dir . '/' . 'counter.txt'); 
ok($bm3_count == 1, "Deleted ONE file!"); 
# You broke it
ok($broke_mailout_three->_integrity_check == 0, "Integrity is NOT OK! - OK!");
# This'll whine about a missing file (That we just removed) 
ok($broke_mailout_three->clean_up() == 1, "cleanup still returned a TRUE value!"); 



### Pertaining to bug: 
# [ 1609792 ] 2.10.11b - Sending Monitor Fails if there's a, "-" in tmpdir
# http://sourceforge.net/tracker/index.php?func=detail&aid=1609792&group_id=13002&atid=113002
my $dash_mailout = DADA::Mail::MailOut->new({ -list => $list });
ok(defined $dash_mailout,                        'new() returned something for dash_mailout good!' );

$test_msg_fields->{'Message-ID'} = '<' .  DADA::App::Guts::message_id() . '.'. $ran_number . '@' . 'some-example-with-dashes.com' . '>'; 

my $dm3; 
eval { 
    $dm3 = $dash_mailout->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' });
};
ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
ok($dm3 == 1, " create() returns 1!"); 
ok($dash_mailout->_integrity_check == 1, "Integrity is OK!");

# Status should also bug out...
my $dm3_status = $dash_mailout->status; 

#ok(1 == 1, "I'm still here!"); 
# Here's the bug, if we try to *re* load the mailing it shouldn't work. 
undef $dash_mailout; 

ok(DADA::Mail::MailOut::mailout_exists($list, $dm3_status->{id}, 'list'), "dm3_status->{id} list exists!"); 

my $dash_mailout2 = DADA::Mail::MailOut->new({ -list => $list });
   $dash_mailout2->associate($dm3_status->{id}, $dm3_status->{type}); 
my $dash_mailout2_reloaded_msg = $dash_mailout2->reload(); 

ok(defined($dash_mailout2_reloaded_msg), "Reloaded Message Worked."); 
ok($dash_mailout2->clean_up(), "cleanup returned a true value!"); 


undef($dash_mailout2); 






# This is to make sure that the list type is set correctly, as per this bug: 
# http://sourceforge.net/tracker/index.php?func=detail&aid=1612943&group_id=13002&atid=113002
#diag("sleeping for 3 seconds...");
sleep(3); 

# gotta reset this...
$test_msg_fields->{'Message-ID'} = '<' .  DADA::App::Guts::message_id() . '.'. $ran_number . '@' . 'example.com' . '>'; 

my $invite_mailout = DADA::Mail::MailOut->new({ -list => $list });
ok(defined $invite_mailout,                        'new() returned something, good for $invite_mailout!' );

my $imo; 
eval { 
    $imo = $invite_mailout->create(
		{
			-fields    => $test_msg_fields, 
			-mh_obj    => $mh, 
			-list_type => 'invitelist' 
		}
	);
};
if($@){ 
	warn $@; 
}
ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!");
 
ok($imo == 1, " create() returns 1!"); 
my $invite_mailout_status = $invite_mailout->status;
ok($invite_mailout->status->{type} eq 'invitelist', "type of mailing is correct set to, 'invitelist'");


# Now, let's try to reload it...


# unlock this puppy...
$invite_mailout->unlock_batch_lock; 

# let's kill our mailout..
undef $invite_mailout; 

ok(DADA::Mail::MailOut::mailout_exists($list, $invite_mailout_status->{id}, 'invitelist') == 1, "Yeah, our mailout better exist..."); 


my $invite_mailout_r = DADA::Mail::MailOut->new({ -list => $list }); 
ok($invite_mailout_r->isa('DADA::Mail::MailOut'), "new mailout is the right type of object..."); 



$invite_mailout_r->associate($invite_mailout_status->{id}, $invite_mailout_status->{type}); 
my $invite_mailout_r_reloaded_msg = $invite_mailout_r->reload(); 

ok(defined($invite_mailout_r_reloaded_msg), "whoa hey, I have a message"); 

ok($invite_mailout_r->clean_up(), "cleanup returned a true value!"); 


####################################################
# tests for pausing a mailing
#


my $pause_mailout = DADA::Mail::MailOut->new({ -list => $list });
my $r_pm; 
   eval { $r_pm = $pause_mailout->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 
ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
ok($r_pm == 1, " create() returns 1!"); 
my $status = $pause_mailout->status(); 
ok(keys %$status, "status() returned a hashref!");

$pause_mailout->pause(); 
$status = $pause_mailout->status(); 
ok($status->{paused} > 0, "paused is more than 0 - 1"); 


$pause_mailout->resume(); 
$status = $pause_mailout->status(); 
ok($status->{paused} == 0, "paused is 0 - 2"); 

$pause_mailout->pause(); 
$status = $pause_mailout->status(); 
ok($status->{paused} > 0, "paused is more than 0 - 3"); 

$pause_mailout->resume(); 
$status = $pause_mailout->status(); 
ok($status->{paused} == 0, "paused is 0  - 4"); 

ok($pause_mailout->clean_up(), "cleanup returned a true value!"); 
undef $pause_mailout; 

#
#
#
####################################################

####################################################
# tests for queueing a mailing
#

# Let's set a default, for now: 

$DADA::Config::MAILOUT_AT_ONCE_LIMIT = 1; 

# This one's a lowball: 

ok($DADA::Config::MAILOUT_AT_ONCE_LIMIT == 1, "\$MAILOUT_AT_ONCE_LIMIT is set to 1."); 

# let's make a few mailouts: 


my $queue_mailout_1 = DADA::Mail::MailOut->new({ -list => $list });
my $q_pm_1; 
   eval { $q_pm_1 = $queue_mailout_1->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 

ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
ok($q_pm_1 == 1, " create() returns 1!"); 

my $queue_mailout_1_status = $queue_mailout_1->status(); 

ok(keys %$queue_mailout_1_status, "status() returned a hashref!");

#diag('$queue_mailout_1_status->{queued_mailout} ' . $queue_mailout_1_status->{queued_mailout}); 

ok($queue_mailout_1_status->{queued_mailout} == 0, "Mass Mailing is not queued."); 


sleep(1); 

# This mailout SHOULD be queued:
$test_msg_fields->{'Message-ID'} = '<' .  DADA::App::Guts::message_id() . '.'. $ran_number . '@' . 'example.com' . '>'; 

my $queue_mailout_2 = DADA::Mail::MailOut->new({ -list => $list });
my $q_pm_2; 
   eval { $q_pm_2 = $queue_mailout_2->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 

ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
ok($q_pm_2 == 1, " create() returns 1!"); 

my $queue_mailout_2_status = $queue_mailout_2->status(); 

ok(keys %$queue_mailout_2_status, "status() returned a hashref!");
ok($queue_mailout_2_status->{queued_mailout} == 1, "Mass Mailing *IS*  queued."); 



sleep(1); 

# This mailout SHOULD be queued, too!:
$test_msg_fields->{'Message-ID'} = '<' .  DADA::App::Guts::message_id() . '.'. $ran_number . '@' . 'example.com' . '>'; 

my $queue_mailout_3 = DADA::Mail::MailOut->new({ -list => $list });
my $q_pm_3; 
   eval { $q_pm_3 = $queue_mailout_3->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 

ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
ok($q_pm_3 == 1, " create() returns 1!"); 

my $queue_mailout_3_status = $queue_mailout_3->status(); 

ok(keys %$queue_mailout_3_status, "status() returned a hashref!");
ok($queue_mailout_3_status->{queued_mailout} == 1, "Mass Mailing *IS*  queued."); 




# Good, now let's remove that first mailing, and see what happens: 
ok($queue_mailout_1->clean_up(), "cleanup returned a true value!"); 
undef $queue_mailout_1; 



# get a fresh status: 
$queue_mailout_2_status = $queue_mailout_2->status(); 

ok(keys %$queue_mailout_2_status, "status() returned a hashref!");
ok($queue_mailout_2_status->{queued_mailout} == 0, "Mass Mailing IS NOT NOW  queued."); 

# get a fresh status: 
$queue_mailout_3_status = $queue_mailout_3->status(); 
# But, this one should still be queued...
ok(keys %$queue_mailout_3_status, "status() returned a hashref!");
ok($queue_mailout_3_status->{queued_mailout} == 1, "Mass Mailing *IS* STILL  queued."); 



# and then clean up our mess...


ok($queue_mailout_2->clean_up(), "cleanup returned a true value!"); 
undef $queue_mailout_2; 

ok($queue_mailout_3->clean_up(), "cleanup returned a true value!"); 
undef $queue_mailout_3; 


#
#
####################################################







# This is to test an undefined counter.txt file. 
my $undef_counter_mailout = DADA::Mail::MailOut->new({ -list => $list });
# This should work....
ok(defined $undef_counter_mailout,                        'new() returned something, good!' );

my $undef_cm; 
   eval { $undef_cm = $undef_counter_mailout->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) }; 
# this should work
ok(!$@, "Passing  a correct DADA::Mail::Send object does not create an error!"); 
# this should work
ok($undef_cm== 1, " create() returns 1!"); 

# this should return, 1
ok($undef_counter_mailout->_integrity_check == 1, "Integrity is OK!");



ok(DADA::Mail::MailOut::_poll($undef_counter_mailout->dir . '/' . 'counter.txt') == 0, "counter is returning 0"); 


# Time to break it...
# NOTE! 'counter.txt' is sort of a variable that you can set in the module, but there's no way to 
# find it's name via the API, so if this name gets changed, this test will then fail...

open(BROKEN_COUNTER, ">" . $undef_counter_mailout->dir . '/' . 'counter.txt') or die "$!"; 
print BROKEN_COUNTER '' or die $!; 
close BROKEN_COUNTER or die $!; 

ok(DADA::Mail::MailOut::_poll($undef_counter_mailout->dir . '/' . 'counter.txt') == '', "counter is returning a '' value. Hmm. That's not good (but what we expect)"); 

my $undef_counter_mailout_status = $undef_counter_mailout->status(); 
ok($undef_counter_mailout_status->{should_be_restarted} == 0, "should_be_restarted status explicitly set to, '0'");


# You broke it
ok($undef_counter_mailout->_integrity_check == 0, "Integrity is NOT OK! - OK!");
# This'll whine about a missing file (That we just removed) 
ok($undef_counter_mailout->clean_up() == 1, "cleanup still returned a TRUE value!"); 

 
=cut

my $Remove = DADA::MailingList::Remove({ -name => $list }); 
ok($Remove == 1, "Remove returned a status of, '1'");

my $first_l = dada_test_config::create_test_list({
	-name => 'firstlist', 
});
my $second_l = dada_test_config::create_test_list({
	-name => 'firstlist', 
});


my $m_first_l = DADA::Mail::MailOut->new({ -list => $first_l });
my $first_l_mo; 
   $first_l_mo = $mailout->create({-fields => $test_msg_fields, -mh_obj => $mh, -list_type => 'list' }) };

=cut




# This is a test to see if the semaphore locking is working. 
# What happens if we try the lock, twice? 


$mailout = DADA::Mail::MailOut->new({ -list => $list });


$mailout->use_semaphore_locking(1); 


my $file_to_lock = $DADA::Config::TMP . '/test_file.txt'; 

my $lock1 = $mailout->lock_file($file_to_lock); 

my $lock2;
eval { $lock2 = $mailout->lock_file($file_to_lock); }; 
ok(defined($@), "Double locking throws an error!"); 
like($@, qr/Couldn\'t lock semaphore/, "And the error makes sense! - " . $@); 

ok(unlink($file_to_lock . '.lock') == 1); 

$mailout->unlock_file($lock1); 







dada_test_config::wipe_out;
