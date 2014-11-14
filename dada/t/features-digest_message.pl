#!/usr/bin/perl 

my $large_num = 1000; 
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
        -setting => 'digest', 
        -value   => 1,
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
            -sending_to => 'digest' # individ, digest, all
        },
    }
); 
ok(scalar(@$s) == 2); 
#diag Dumper($s); 
undef($s); 

$ls->save({
    digest_enable => 1, 
}); 

# this should give us 1 back, now: 
my $s = $lh->subscription_list(
    {
        -mass_mailing_params => {
            -sending_to => 'digest' # individ, digest, all
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
            -sending_to => 'individ' # individ, digest, all
        },
    }
); 
ok($s->[0]->{email} eq 'no.digest@example.com'); 


# This should give back BOTH subscribers, 
my $s = $lh->subscription_list(
    {
        -mass_mailing_params => {
            -sending_to => 'all' # individ, digest, all
        },
    }
); 
my $n = scalar(@$s); 
ok($n == 2); 


my $digest = DADA::App::Digests->new(
    {
        -list  => $list,
        '-time' => 1416003468, 
    }
); 






dada_test_config::remove_test_list;
dada_test_config::wipe_out;



