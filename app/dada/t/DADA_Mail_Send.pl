#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config;

#use Test::More qw(no_plan);  
use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::Mail::Send; 
use DADA::App::Messages; 

my $list = dada_test_config::create_test_list;
my $mh; 

#### -list isn't currently a needed parameter (anymore) 
# Test to see if fail will happen if we don't pass the, -list param: 
# This will fail: 
#eval {$mh = DADA::Mail::Send->new();};
#ok($@); 
#like($@, qr/You MUST pass the \-list parameter\!/); 




# Now, we'll see if it's successful when we do pass that param: 
$mh = DADA::Mail::Send->new(
	  		{
				-list => $list
			}
		); 

ok($mh->isa('DADA::Mail::Send'), "returns the right type of object!"); 


# These are all tests to make sure the, "test" method works: 
ok($mh->test    == 0); 
ok($mh->test(1) == 1); 
ok($mh->test    == 1); 
ok($mh->test(0) == 0); 
ok($mh->test    == 0); 

my $d_test_send_file = $mh->test_send_file; 

ok($mh->test_send_file eq $DADA::Config::TMP . '/test_send_file.txt');
ok($mh->test_send_file('/some/path/to/a/file.txt') eq '/some/path/to/a/file.txt');
ok($mh->test_send_file eq '/some/path/to/a/file.txt'); 
ok($mh->test_send_file($d_test_send_file) eq $DADA::Config::TMP . '/test_send_file.txt'); 
ok($mh->test_send_file eq $DADA::Config::TMP . '/test_send_file.txt');
undef $mh; 



# This is a test, to make sure we cannot restart a mailing, that does not need
# to be restarted! 

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


$mh = DADA::Mail::Send->new(
	  		{
				-list => $list
			}
		);
		

# Off it goes: 
$mh->test(1); 

my $msg_id =  $mh->mass_send({
	-msg 			  => {
		Subject => 'Test', 
		Body    => 'This is the body!',
	} 	
}); 	

diag '$msg_id: ' . $msg_id; 


#
# This is actually, really whacky - I don't know why there's a DADA::Mail::Send
# method, to control the DADA::Mail::MailOut method, 

diag 'restart_mass_send';

eval { 
$mh->restart_mass_send(
		$msg_id,
		'list',
	);
};

ok(defined($@), 'errors are found'); 

diag 'catched errors: ' . $@; 



# How about directly? 

require DADA::Mail::MailOut; 
my $mailout = DADA::Mail::MailOut->new(
		{
			-list => $list, 
		}
); 
$mailout->associate($msg_id, 'list'); 

eval { 
	$mailout->reload;
};

ok(defined($@), 'errors are found(2)'); 
diag $@;

# The other thing we can try, is unlocking the batch lock ourselves: 
#
$mailout->unlock_batch_lock;
#
# We'll also have to muck about with the last_access file, to reset it to something whacky: 
my $md = $mailout->dir . '/last_access.txt'; 
chmod `644 $md`;
open(my $la, ">", $mailout->dir . '/last_access.txt') or die $!; 
print $la (time - 500) or die $!; 
close ($la) or die; 


ok($mh->restart_mass_send(
		$msg_id,
		'list',
	) == 1);



# But, I'm still a little wary, on how to test that this has work...?

$mailout->pause;
$mailout->clean_up;

wait_for_msg_sending(); 





	

#
#############################################################################




dada_test_config::remove_test_list;
dada_test_config::wipe_out;
#


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

sub  wait_for_msg_sending { 
	
	my @mailouts = DADA::Mail::MailOut::current_mailouts({-list => $list}); 
	my $timeout = 0; 
	
	diag "number of mailouts: " . scalar(@mailouts);
	
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









