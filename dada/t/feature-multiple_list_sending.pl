#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use DADA::Config; 
$DADA::Config::MULTIPLE_LIST_SENDING = 1; 

use strict;
use Carp; 

##############################################################################
#
$DADA::Config::MULTIPLE_LIST_SENDING_TYPE = 'individual'; 
#

# These holds names of the lists 
#
my $list  = dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1});
my $list2 = dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1, -name => 'dadatest2'});
my $list3 = dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1, -name => 'dadatest3'});

require DADA::App::Guts;
require DADA::MailingList::Subscribers; 

my $ls  = DADA::MailingList::Subscribers->new({-list => $list}); 
my $ls2 = DADA::MailingList::Subscribers->new({-list => $list2});   
my $ls3 = DADA::MailingList::Subscribers->new({-list => $list3});   


# Add the ones all list's share: 
#
my @subs = qw(
	user1@example.com
	user2@example.com
	user3@example.com
	user4@example.com
	user5@example.com
); 
my @ls_s = ($ls, $ls2, $ls3); 

for my $local_ls(@ls_s){ 
	for my $sub(@subs){ 
		$local_ls->add_subscriber(
			{
				-email => $sub, 
			}
		);
	}
}

# Add the ones specific to each list
#
$ls->add_subscriber(
	{
		-email => 'only_on_dadatest@example.com', 
	}
);

$ls2->add_subscriber(
	{
		-email => 'only_on_dadatest2@example.com', 
	}
);

$ls3->add_subscriber(
	{
		-email => 'only_on_dadatest3@example.com', 
	}
);

my $sl = [];



# Let's see what we have, that's unique to our first list: 
$sl = $ls->subscription_list(
	{
		-exclude_from => [$list2, $list3],
	}
);
ok(scalar @$sl == 1, "OK! We have ONE subscriber, unique to this one list"); 
undef $sl; 




# Let's see if we can't confuse it - should still only return one result
$ls->add_subscriber(
	{
		-email => 'somewhereelse@fubar.com', 
	}
);
$sl = $ls->subscription_list(
	{
		-exclude_from    => [$list2, $list3],
		-partial_listing => {
								email => 
									{
										like => 'example',
									}
							},
	}
);
ok(scalar @$sl == 1, "OK! We have ONE subscriber, unique to this one list"); 
undef $sl;


# What if we add that subscriber to list #2? We shouldn't get any results:
$ls2->add_subscriber(
	{
		-email => 'somewhereelse@fubar.com', 
	}
);
$sl = $ls->subscription_list(
	{
		-exclude_from    => [$list2, $list3],
		-partial_listing => {
								email => 
									{
										like => 'fubar.com',
									}
							},
	}
);
ok(scalar @$sl == 0, "OK! We have NO subscriber, unique to this one list"); 
undef $sl;


# But, what if we're not looking at list #2, just list #3? We should get one result: 
$sl = $ls->subscription_list(
	{
		-exclude_from    => [$list3],
		-partial_listing => {
								email => 
									{
										like => 'fubar.com',
									}
							},
	}
);
ok(scalar @$sl == 1, "OK! We have ONE subscriber, unique to this one list"); 
undef $sl;

# Time for some Subscriber Profile Fields, I guess: 
require DADA::Profile::Fields;
my $pf = DADA::Profile::Fields->new; 
$pf->{manager}->add_field(
	{
		-field => 'one', 
	}
);
$pf->{manager}->add_field(
	{
		-field => 'two', 
	}
);
$pf->{manager}->add_field(
	{
		-field => 'three', 
	}
);

for my $sub(@{$ls->subscription_list}){ 
	$ls->edit_subscriber(
		{
			-email    => $sub->{email}, 
			-fields   => { 
				one   => "ONE", 
				two   => "TWO", 
				three => "THREE",
			}
		}
	);
}


undef $sl; 


$sl = $ls->subscription_list(
	{
		-partial_listing => {
								one => 
									{
										like => 'ONE',
									}
							},
	}
);
ok(scalar @$sl == 7, "OK! We have 7 subscribers, unique to this one list (" . scalar @$sl . ")"); 
undef $sl; 





$sl = $ls->subscription_list(
	{
		-exclude_from    => [$list2, $list3],
		-partial_listing => {
								one => 
									{
										like => 'ONE',
									}
							},
	}
);
ok(scalar @$sl == 1, "OK! We have 1 subscribers, unique to this one list (" . scalar @$sl . ")"); 
undef $sl; 



# This is now a test to make sure that the DADA::Mail::MailOut module actually
# creates the temp sending list correctly: 
require DADA::Security::Password;
require DADA::App::Guts; 
require DADA::Mail::Send; 
require DADA::Mail::MailOut; 
my $mh = DADA::Mail::Send->new({-list => $list}); 
   $mh->test(1);	
my $mo = DADA::Mail::MailOut->new({-list => $list}); 
my $test_msg_fields = {
    From         => 'me@example.com',
    To           => 'you@example.com',
    Subject      => 'hey!',
    Body         => 'This is my body!', 
	'Message-ID' => '<' .  DADA::App::Guts::message_id() . '.'. DADA::Security::Password::generate_rand_string('1234567890') . '@' . 'example.com' . '>', 
};
# Let's first do this, with no exlusions:
$mo->create(
	{
		-fields        => $test_msg_fields, 
		-mh_obj        => $mh, 
		-list_type     => 'list',
		-exclude_from  => [],
	 },
);
ok($mo->status->{total_sending_out_num} == 8, "sending along to 8 people"); 
# DESTROY! 
$mo->clean_up(); 
undef $mo; 

# Do it again!: Exclude list 2
$mo = DADA::Mail::MailOut->new({-list => $list}); 
$mo->create(
	{
		-fields        => $test_msg_fields, 
		-mh_obj        => $mh, 
		-list_type     => 'list',
		-exclude_from  => [$list2],
	 },
);
ok($mo->status->{total_sending_out_num} == 2, "sending along to 2 people"); 
$mo->clean_up(); 
undef $mo; 
# Just to be thorough, let's exclude both lists: 
$mo = DADA::Mail::MailOut->new({-list => $list}); 
$mo->create(
	{
		-fields        => $test_msg_fields, 
		-mh_obj        => $mh, 
		-list_type     => 'list',
		-exclude_from  => [$list2, $list3],
	 },
);
ok($mo->status->{total_sending_out_num} == 2, "sending along to 2 people"); 
$mo->clean_up(); 
undef $mo;

# This should do that same thing as the last test, but we're doing it, 
# indirectly from DADA::Mail::Send. This just makes sure D::M::Send is using 
# The correct API for D::M::MailOut: 

$mh->test_return_after_mo_create(1); 
$mh->mass_send(
	{
		-msg 			  => $test_msg_fields,
		-exclude_from     => [$list2, $list3],
	}
); 

my @mailouts = DADA::Mail::MailOut::current_mailouts({-list => $list});
$mo = DADA::Mail::MailOut->new({-list => $list}); 
$mo->associate($mailouts[0]->{id}, 'list'); 
ok($mo->status->{total_sending_out_num} == 2, "sending along to 2 people"); 
$mo->clean_up(); 
undef $mo;


#diag "Sleeping!"; 
#sleep(320);



##############################################################################
#
$DADA::Config::MULTIPLE_LIST_SENDING_TYPE = 'merged'; 
#

$sl = $ls->subscription_list(
	{
		-include_from     => [$list2],
	}
);
ok(scalar @$sl == 8, "We have 8 subscribers that are subscribed to all three lists. (" . scalar @$sl . ")"); 
undef $sl;



$sl = $ls->subscription_list(
	{
		-include_from     => [$list2, $list3],
	}
);
ok(scalar @$sl == 9, "We have 9 subscribers that are subscribed to all three lists. (" . scalar @$sl . ")"); 
undef $sl;


# I guess this is valid, as it doesn't do anything wrong, but it's still sort of weird: 
$sl = $ls->subscription_list(
	{
		-include_from     => [$list],
	}
);
ok(scalar @$sl == 7, "We have 7 subscribers that are subscribed to the first two lists. (" . scalar @$sl . ")"); 
undef $sl;



$sl = $ls->subscription_list(
	{
		-include_from    => [$list2, $list3],
		-partial_listing => {
								one => 
									{
										like => 'ONE',
									}
							},
	}
);
ok(scalar @$sl == 7, "OK! We have 7 subscribers (" . scalar @$sl . ")"); 
undef $sl; 



dada_test_config::remove_test_list;
dada_test_config::remove_test_list({-name => 'dadatest2'});
dada_test_config::remove_test_list({-name => 'dadatest3'});

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


