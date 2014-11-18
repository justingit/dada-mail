#!/usr/bin/perl 

my $time = 1416181791;


use Data::Dumper; 

use lib
  qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib );
BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }
use DADA::Config; 

use dada_test_config;
my $list = dada_test_config::create_test_list(
    { -remove_existing_list => 1, -remove_subscriber_fields => 1 } );

use       DADA::MailingList::Subscribers; 
use       DADA::MailingList::Settings; 
use       DADA::Profile::Settings; 
use       DADA::App::Digests; 
use       DADA::App::Guts; 

my $lh  = DADA::MailingList::Subscribers->new({-list => $list}); 
my $ls  = DADA::MailingList::Settings->new({-list => $list}); 
my $dps = DADA::Profile::Settings->new(); 

ok(1 == 1); 
my $s = $lh->subscription_list(); 
ok(scalar(@$s) == 0); 
undef $s; 

$lh->add_subscriber(
	{ 
		-email => 'no.digest@example.com', 
	},
);
$lh->add_subscriber(
	{ 
		-email => 'yes.digest@example.com', 
	},
);

my $s = $lh->subscription_list(); 
ok(scalar(@$s) == 2); 
undef($s); 



my $s = $lh->subscription_list({-for_mass_mailing => 1}); 
#diag Dumper($s); 
ok(scalar(@$s) == 2); 
undef($s); 


my $r = $dps->save(
    {
        -email   => 'yes.digest@example.com', 
        -list    => $list, 
        -setting => 'delivery_prefs', 
        -value   => 'digest',
    }   
);
ok($r == 1); 



my $psettings = $dps->fetch(
   { 
       -email   => 'yes.digest@example.com', 
       -list    => $list, 
   }
);

ok($psettings->{digest} == 1); 



# Actually, this is a trick - we haven't enabled digests! 
my $s = $lh->subscription_list(
    {
        -mass_mailing_params => {
            -delivery_preferences => 'digest' # individ, digest, all
        },
    }
); 
ok(scalar(@$s) == 2); 
undef($s); 

$ls->save({
    digest_enable => 1, 
}); 

# this should give us 1 back, now: 
my $s = $lh->subscription_list(
    {
        -mass_mailing_params => {
            -delivery_preferences => 'digest' # individ, digest, all
        },
    }
); 
my $n = scalar(@$s); 
ok($n == 1, "should be 1: $n"); 


ok($s->[0]->{email} eq 'yes.digest@example.com'); 
undef($s); 

# This should give one back to, but not the one that wants the digest!
my $s = $lh->subscription_list(
    {
        -mass_mailing_params => {
            -delivery_preferences => 'individual' # individ, digest, all
        },
    }
); 
ok($s->[0]->{email} eq 'no.digest@example.com'); 


# This should give back BOTH subscribers, 
my $s = $lh->subscription_list(
    {
        -mass_mailing_params => {
            -delivery_preferences => 'all' # individ, digest, all
        },
    }
); 
my $n = scalar(@$s); 
ok($n == 2); 


my $digest = digest_obj(); 


ok($digest->should_send_digest == 0, "no archives, so nothing to send!"); 

require   DADA::MailingList::Archives; 
my $dma = DADA::MailingList::Archives->new({-list => $list}); 

my $i    = 0;  
for(0..2){ 
    $i += 1800; # 1/2 hour
    $dma->set_archive_info(
        message_id(($time - $i)),
        undef, 
        undef, 
        undef, 
        q{Content-type: text/plain
From: no.digest@example.com
Subject: this is the subject!

This is the message!},
    ); 
}
my $keys       = $dma->get_archive_entries('normal');
diag scalar(@$keys) . ' archives.'; 

undef($digest); # this is to reload the D::M::Settings; 
my $digest = digest_obj(); 

# Haven't sent a digest, but most recent digest is out of scope! (too far in the future!); 
ok($digest->should_send_digest == 1); 

my $ids = $digest->archive_ids_for_digest; 
ok(scalar(@$ids) == 3, "three archives for digest!");  

sub digest_obj { 
    my $digest = DADA::App::Digests->new(
        {
            -list   => $list,
            -ctime  => $time, 
        }
    ); 
    
    return $digest;
}

#diag $digest->create_digest_msg_entity->as_string();

#diag $ls->param('digest_message'); 
#diag Dumper($digest->digest_ht_vars); 



dada_test_config::remove_test_list;
dada_test_config::wipe_out;



