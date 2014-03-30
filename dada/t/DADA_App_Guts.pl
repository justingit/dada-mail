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
use DADA::MailingList::Settings; 

my $list = dada_test_config::create_test_list;

my $ls  = DADA::MailingList::Settings->new({-list => $list}); 


#available_lists
# One list

is_deeply(available_lists(), ($list));

my $list2 = dada_test_config::create_test_list(-name => 'two', -list_name => 'A Very Nice List');
my $list3 = dada_test_config::create_test_list(-name => 'three', -list_name => 'Zap! A Better List'); 

# three lists
is_deeply([sort(available_lists())], [sort($list, $list3, $list2)]); #sort is used, so that the sorting is the same - 
																	 # no matter what that is. 
# in order
is_deeply([available_lists(-In_Order => 1)], [$list2, $list, $list3]);

# three lists as ref
is_deeply([sort(@{available_lists(-As_Ref => 1)})], [sort($list, $list3, $list2)]); #sort is used, so that the sorting is the same - 


# in order as ref
is_deeply(available_lists(-In_Order => 1, -As_Ref => 1), [$list2, $list, $list3] );

dada_test_config::remove_test_list({-name => $list2});
dada_test_config::remove_test_list({-name => $list3});

### check_for_valid_email
 
ok( check_for_valid_email('test@example.com') == 0 );
ok( check_for_valid_email('test@example.co.uk') == 0 );
ok( check_for_valid_email('test.one.two@example.co.uk') == 0 );
ok( check_for_valid_email('test@example.nu') == 0 );
ok( check_for_valid_email('test+0@example.nu') == 0 );
ok( check_for_valid_email('test') == 1 );
ok( check_for_valid_email('test@example') == 1 );
ok( check_for_valid_email('example.co.uk') == 1 );
ok( check_for_valid_email( 'newline@example.com' . "\n" ) == 1 );
ok( check_for_valid_email( 'newline@example.com' . "\r\n" ) == 1 );
ok( check_for_valid_email( 'newline@example.com' . "\r" ) == 1 );
ok( check_for_valid_email('spaces@example. com') == 1 );
ok( check_for_valid_email('spaces@example . com') == 1 );
ok( check_for_valid_email('spaces@example .com') == 1 );
ok( check_for_valid_email('test @example.nu') == 1 );
ok( check_for_valid_email('test+0') == 1 );



### strip

ok(strip(' foo ') eq 'foo'); 
ok(strip('foo ')  eq 'foo'); 
ok(strip(' foo')  eq 'foo'); 



### pretty

ok(pretty('_foo_') eq ' foo '); 
ok(pretty('foo_')  eq 'foo '); 
ok(pretty('_foo')  eq ' foo'); 


### make_pin
### check_email_pin


### make_template


my $template = 'blah blah blah'; 


ok(make_template() eq undef); 
ok(make_template({ -List => $list }) eq undef); 
ok(make_template({ -List => $list, -Template => $template }) == 1); 

my $template_file = $DADA::Config::TEMPLATES . '/' . $list . '.template'; 


ok(-e $template_file); 

    open my $TEMPLATE_FILE, '<', $template_file
        or die $!;

    my $template_info = do { local $/; <$TEMPLATE_FILE> };

    close $TEMPLATE_FILE
        or die $!;
 
ok($template_info eq $template, 'Template info saved correctly'); 




### delete_list_template

ok(delete_list_template() eq undef); 
ok(delete_list_template( { -List => $list })); 
ok(! -e $template_file); 



### delete_list_info
### delete_email_list



### check_if_list_exists

ok(check_if_list_exists(-List => $list)        == 1); 
ok(check_if_list_exists(-List => 'idontexist') == 0); 




my $Remove = DADA::MailingList::Remove({ -name => $list }); 
ok($Remove == 1, "Remove returned a status of, '1'");

ok(date_this(-Packed_Date => '20061120024010') =~ m{(\s*)November 20th 2006(\s*)}); 
ok(date_this(-Packed_Date => '20061120024010', -All => 1) =~ m{(\s*)November 20th 2006 2:40:10 a.m.(\s*)}); 


# t/corpus/html/utf8.html


### csv_subscriber_parse
$list = dada_test_config::create_test_list;

    diag('csv_subscriber_parse'); 
    
    require DADA::MailingList::Subscribers; 
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 

	SKIP: {

	    skip "Multiple Profile Fields is not supported with this current backend." 
	        if $lh->can_have_subscriber_fields == 0;
	
	    my $r = $lh->add_subscriber_field({-field => 'first_name'});
	    ok($r == 1, "\$r = $r"); 
	
#diag "sleeping!";
#sleep(400); 
	
	    ok($lh->add_subscriber_field({-field => 'last_name'})); 
    
	    my @test_files = qw(
	    DOS.csv
	    DOS2.csv
	    Mac.csv
	    Mac2.csv
	    Unix.csv
	    Unix2.csv
	    );
    
	    for my $test_file(@test_files){ 
    
	        `cp t/corpus/csv/$test_file $DADA::Config::TMP/$test_file`;
        
			
	        my ($new_emails) = DADA::App::Guts::csv_subscriber_parse($list, $test_file);
	        
	        
			#use Data::Dumper; 
			#diag Data::Dumper::Dumper($new_emails);
			#diag("wahoo!"); 
			 
	        ok($new_emails->[0]->{email} eq 'example1@example.com',      'example1@example.com');
	        ok($new_emails->[0]->{fields}->{first_name}  eq 'Example', "Example");
	        ok($new_emails->[0]->{fields}->{last_name}  eq 'One',  "One");
    
	        ok($new_emails->[1]->{email} eq 'example2@example.com');
	        ok($new_emails->[1]->{fields}->{first_name}  eq 'Example', "Example");
	        ok($new_emails->[1]->{fields}->{last_name}  eq 'Two',  "Two");

	        ok($new_emails->[2]->{email} eq 'example3@example.com');
	        ok($new_emails->[2]->{fields}->{first_name}  eq 'Example', "Example");
	        ok($new_emails->[2]->{fields}->{last_name}  eq 'Three',  "Three");
        
	        # It's kina weird this subroutine removes the file but... ok!
	        ok(! -e $DADA::Config::TMP . '/$test_file'); 
	    }
	    ok($lh->remove_subscriber_field({-field => 'first_name'})); 
	    ok($lh->remove_subscriber_field({-field => 'last_name'})); 
	
} # Skip


### /csv_subscriber_parse

# isa_url

ok(isa_url('http://example.com') == 1, 'http://example.com seems to be a URL!');
ok(isa_url('example.com')        == 0, 'example.com does not seem to be a URL!');
ok(isa_url('ftp://example.com')  == 1, 'ftp://example.com seems to be a URL!');
ok(isa_url('ical://example.com') == 1, 'ical://example.com seems to be a URL!');


# safely_decode 
my $str = $dada_test_config::UTF8_STR; 

eval { 
	
	$str = safely_decode($str); 
	$str = safely_decode($str); 
	$str = safely_decode($str); 
	$str = safely_decode($str); 
	$str = safely_decode($str); 
	$str = safely_decode($str); 
}; 
ok(!$@, "safely decoding a whole bunch - didn't die!") ;

# reset, 
$str = $dada_test_config::UTF8_STR;

# safely_encode 
eval { 
	
	$str = safely_encode($str); 
	$str = safely_encode($str); 
	$str = safely_encode($str); 
	$str = safely_encode($str); 
	$str = safely_encode($str); 
	$str = safely_encode($str); 
 
}; 
ok(!$@, "safely encoding a whole bunch - didn't die!") ;


# decode_cgi_obj 
$str = $dada_test_config::UTF8_STR;

require CGI; 
my $q = new CGI; 
$q->param('utf8str', Encode::encode('UTF-8', $str)); # kind of like if we got it from outside the prog, 
$q = decode_cgi_obj($q); 

ok($q->param('utf8str') eq $dada_test_config::UTF8_STR, "decoding the cgi object didn't destroy our data!"); 
$q->delete('utf8str'); 


$q->param('utf8array', Encode::encode('UTF-8', $str), Encode::encode('UTF-8', $str), Encode::encode('UTF-8', $str)); # kind of like if we got it from outside the prog, 
$q = decode_cgi_obj($q); 

my @utf8array = $q->param('utf8array'); 
for(@utf8array){ 
	ok($_ eq $dada_test_config::UTF8_STR, "decoding the cgi object didn't destroy our data!");
}




dada_test_config::remove_test_list;
dada_test_config::wipe_out;


