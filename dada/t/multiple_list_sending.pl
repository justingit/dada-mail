#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


use strict;
use Carp; 


# These holds names of the lists 
#
my $list  =  dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1});
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

foreach my $local_ls(@ls_s){ 
	foreach my $sub(@subs){ 
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

my $sl = $ls->subscription_list(
	{
		-exclude_from => [$list2, $list3],
	}
);

ok(scalar @$sl == 1, "OK! We have ONE subscriber, unique to this one list"); 





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



