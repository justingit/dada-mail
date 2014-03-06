#!/usr/bin/perl 

use strict; 
use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
my $list = dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1});



use DADA::MailingList::Subscribers; 


# Filter stuff

my @email_list = qw(

    user@example.com
    @example.com
	user@
    
);


my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 


use      DADA::MailingList::Settings; 
my $ls = DADA::MailingList::Settings->new(
	{
		-list => $list
	}
); 
$ls->save(
	{
		enable_white_list => 1
	}
); 

my $li = $ls->get(); 

ok($li->{enable_white_list} == 1, "white list enabled."); 


my $count = $lh->add_subscriber(
	{
		-email => 'test@', 
        -type  => 'white_list',
     }
);
 
ok(defined($count), "added one address (test@) to the white list.");                           
undef($count); 

ok($lh->inexact_match({-against => 'white_list', -email => 'test@example.com'}) == 1, 'we have an inexact match between test@example.com and test@ - good!'); 


my ($not_members, 
$invalid_email,  
$subscribed,
$black_listed,    
$not_white_listed,
$invalid_profile_fields,
) = $lh->filter_subscribers_massaged_for_ht( { -emails => [{email => 'test@example.com'}], } );

use Data::Dumper; 

ok(eq_array($subscribed,                   []                  ) == 1, "No one subscribed when testing test\@example.com"); 
ok(eq_array(just_the_emails($not_members), ['test@example.com']) == 1, "test\@example.com is Not Subscribed"); 
ok(eq_array($not_white_listed,             []                  ) == 1, "NOT White Listed when testing test\@example.com");
ok(eq_array($black_listed,                 []                  ) == 1, "Black Listed when testing test\@example.com"); 
ok(eq_array([],                            []                  ) == 1, "Invalid when testing test\@example.com");

undef($subscribed);
undef($not_members);
undef($black_listed);
undef($not_white_listed);
undef($invalid_email);


ok($lh->inexact_match({-against => 'white_list', -email => 'user@example.com'}) == 0, 'we DO NOT have an inexact match between user@example.com and test@ - good!'); 


($not_members, 
$invalid_email,  
$subscribed,
$black_listed,    
$not_white_listed,
$invalid_profile_fields,
) = $lh->filter_subscribers_massaged_for_ht( { -emails => [{email => 'user@example.com'}], } );


#diag(Data::Dumper::Dumper($subscribed, $not_subscribed, $black_listed, $not_white_listed, $invalid)); 
	
	   
ok(eq_array($not_members,         []                  ) == 1, "Subscribed when testing user\@example.com"); 
ok(eq_array($not_members,     []                  ) == 1, "not_members when testing user\@example.com"); 
ok(eq_array(just_the_emails($not_white_listed),   ['user@example.com']) == 1, "NOT White Listed when testing user\@example.com"); 
ok(eq_array($black_listed,       []                  ) == 1, "Black Listed when testing user\@example.com"); 
ok(eq_array($invalid_profile_fields,                  []                  ) == 1, "Invalid when testing user\@example.com"); 


my $r_count = $lh->remove_subscriber({-email => 'test@', -type => 'white_list'}); 
ok($r_count == 1, "removed one address from white list");                           
undef($r_count);






my $count = $lh->add_subscriber(
	{
		-email => 'test@',
		-type  => 'white_list',
	}
);
ok(defined($count), "added one address to the white list.");                           
undef($count); 

                   
my @not_white_listed_addresseses = ('user@example.com', 'another@here.com', 'blah@somewhere.co.uk');
for my $not_white_listed_addresses(@not_white_listed_addresseses){
    my ($status, $errors) = $lh->subscription_check(
								{
									-email => $not_white_listed_addresses,
								}
							);
    ok($status == 0, "Status is 0"); 
    ok($errors->{not_white_listed} == 1, "Address was not_white_listed");
}

my $r_count = $lh->remove_subscriber({-email => 'test@', -type => 'white_list'}); 
ok($r_count == 1, "removed one address from white list");                           
undef($r_count);




my $count = $lh->add_subscriber(
	{
		-email => '@example.com',
		-type  => 'white_list',
     }
); 
 
ok(defined($count), "added one address to the white list.");                           
undef($count); 


my @white_listed_addresses = ('user@example.com', 'another@example.com', 'blah@example.com');
for my $white_listed_addresses(@white_listed_addresses){
    my ($status, $errors) = $lh->subscription_check(
								{
									-email => $white_listed_addresses,
    							}
							);
    #for(keys %$errors){ 
    #    diag($_ . ' => ' . $errors->{$_}); 
    #}
    ok($status == 1, "Status is 1"); 
    ok($errors->{not_white_listed} == 0, "Address ($white_listed_addresses) was White Listed");
}

my $r_count = $lh->remove_subscriber({-email => '@example.com', -type => 'white_list'}); 
ok($r_count == 1, "removed one address from white list");                           
undef($r_count);




# Black List addresses have more of a precedence than white listed addresses. 
# If an address is subscribed to both - the black listed will precende the 
# white listed stuff and the address won't be able to be subscribed. 







   $ls->save({black_list => 1}); 
   $li = $ls->get(); 
ok($li->{black_list} == 1, "black list enabled."); 



my $count = $lh->add_subscriber(
	{
		-email => '@example.com',
		-type  => 'white_list',  
  	}
  );
  
  

ok(defined($count), "added one address to the white list.");                           
undef($count); 


my $count = $lh->add_subscriber(
	{
		-email => '@example.com',   
		-type  => 'black_list',
	}
);

ok(defined($count), "added one address to the black list.");                           
undef($count); 





my ($status, $errors) = $lh->subscription_check(
							{
								-email => 'test@example.com',
							}
						);
  ok($status == 0, "Status is 0"); 
    ok($errors->{black_listed} == 1, "Address is black listed.");


my $r_count = $lh->remove_subscriber({-email => '@example.com', -type => 'black_list'}); 
ok($r_count == 1, "removed one address from black list");                           
undef($r_count);


my ($status, $errors) = $lh->subscription_check(
							{
								-email => 'test@example.com',
							}
						);
  ok($status == 1, "Status is 1"); 
  if($status == 0){ 
    for(keys %$errors){ 
        diag 'test@example.com Error: ' . $_;
    }
  }
  
  ok($errors->{black_listed} == 0, "Address is NOT black listed.");





my $r_count = $lh->remove_subscriber({-email => '@example.com', -type => 'white_list'}); 
ok($r_count == 1, "removed one address from white list");                           
undef($r_count);



# Make sure that a partial match doesn't give me a false match: 
my $count = $lh->add_subscriber(
	{
		-email => 'somewherefaraway@foobar.com', 
        -type  => 'white_list',
     }
);
ok($lh->inexact_match({-against => 'white_list', -email => 'somewherefaraway@adifferentdomain.com'}) == 0, 'no inexact_match'); 





dada_test_config::remove_test_list;
dada_test_config::wipe_out;

sub just_the_emails {
    my $a_ref = shift || []; 
    my $emails = []; 
    for(@$a_ref){ 
        push(@$emails, $_->{email}); 
    }
    return $emails; 
}

