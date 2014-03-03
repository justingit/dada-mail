#!/usr/bin/perl 

use strict;
use warnings;
use Benchmark qw/cmpthese timethese/;


use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	
); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
dada_test_config::create_MySQL_db(); 


my $list = dada_test_config::create_test_list;
require DADA::MailingList::Subscribers; 
my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 

require DADA::MailingList::Settings; 
my $ls = DADA::MailingList::Settings->new({-list => $list}); 

my @subs; 
for(0..999){ 
    push(@subs, $_ . '@example.com'); 
}
for(0..499){ 
    $lh->add_subscriber({-email => $_ . '@example.com'}); 
}
use Data::Dumper; 


cmpthese(-60, {
        og => sub {    
            
                        my ($subscribed, $not_subscribed, $black_listed, $not_white_listed, $invalid) 
                    		= $lh->filter_subscribers(
                    			{
                    				-emails => [@subs], 
                    				-type   => 'list'
                    			}
                    		);
                    	#	print Dumper(
                    	#	    {
                    	#	        subscribed => $subscribed, 
                    	#	        not_subscribed => $not_subscribed, 
                    	#	        black_listed => $black_listed, 
                    	#	        not_white_listed => $not_white_listed, 
                    	#	        invalid => $invalid
                    	#	    }
                    	#	); 
                        
                  },
        next => sub {  
                        my $r = (); 
                        for(@subs){
                            my ( $status, $errors ) = $lh->unsubscription_check(
                                {
                                    -email => $_,
                                    -skip => [qw(
                                        mx_lookup_failed
                                        already_sent_unsub_confirmation
                                        profile_fields
                                        over_subscription_quota
                                    )],
                                    -ls_obj => $ls, 
                                }
                            );

                        push(@$r, {
                            $_ => {
                                status => $status, 
                                errors => $errors
                            }
                        });
                    } 
                      #  print Dumper($r); 
            
                    },
});

dada_test_config::destroy_MySQL_db();
dada_test_config::remove_test_list;
dada_test_config::wipe_out;
