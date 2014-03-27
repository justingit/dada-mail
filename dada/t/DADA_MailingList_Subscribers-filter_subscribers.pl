#!/usr/bin/perl 
use strict;


use lib
  qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib );
BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }
use dada_test_config;

# This doesn't work, if we're eval()ing it.
# use Test::More qw(no_plan);

my $list = dada_test_config::create_test_list({ -remove_existing_list => 1, -remove_subscriber_fields => 1 } );

use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;

my $ls = DADA::MailingList::Settings->new(    { -list => $list } );
my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

chmod( 0777, $DADA::Config::TMP . '/mail.txt' );


# OG list: 1 not_member email, 3 invalid emails
#
my $email_list = [
 {email =>  'user@example.com'},
 {email =>  'user'},
 {email =>  'example.com'},
 {email =>  '@example.com'},
];


ok(
    $lh->{ls}->isa('DADA::MailingList::Settings'),
    "looks like there's a Settings obj in ->{ls}, good!"
);

my (
    $not_members, 
    $invalid_email,  
    $subscribed,
    $black_listed,    
    $not_white_listed,
    $invalid_profile_fields,
    )
  = $lh->filter_subscribers_massaged_for_ht( { -emails => $email_list, } );

diag('1 not_member email, 3 invalid emails'); 

ok( eq_array( $subscribed, [] ) == 1, "Subscribed" );
ok( eq_array(just_the_emails($not_members), ['user@example.com'] ) == 1, "Not Subscribed (user\@example.com)" );
ok( eq_array( $black_listed,     [] ) == 1, "Black Listed" );
ok( eq_array( $not_white_listed, [] ) == 1, "Not White Listed" );
ok(eq_array( [ sort(@{just_the_emails($invalid_email)}) ], [ sort( 'user', 'example.com', '@example.com' ) ] ) == 1,"Invalid");


# Adding, user@example.com:
my $obj = $lh->add_subscriber(
    { 
        -email => 'user@example.com',
        -type  => 'list',
    }
);
ok( defined($obj), "added one address" );
undef($obj);

($not_members, 
$invalid_email,  
$subscribed,
$black_listed,    
$not_white_listed,
$invalid_profile_fields,
) = $lh->filter_subscribers_massaged_for_ht( { -emails => $email_list, } );

diag(' 1 subscribed email, 3 invalid emails');
ok( eq_array( just_the_emails($subscribed), ['user@example.com'] ) == 1, "Subscribed" );
ok( eq_array( $not_members,   [] ) == 1, "Not Subscribed ()" );
ok( eq_array( $black_listed,     [] ) == 1, "Black Listed" );
ok( eq_array( $not_white_listed, [] ) == 1, "Not White Listed" );
ok(eq_array( [ sort(@{just_the_emails($invalid_email)}) ], [ sort( 'user', 'example.com', '@example.com' ) ] ) == 1,"Invalid");




# removing user@example.com: 
my $r_count = $lh->remove_subscriber({ -email => 'user@example.com' } );
ok( $r_count == 1, "removed one address (user\@example.com)" );
undef($r_count);


$ls->save( { black_list => 1 } );
ok( $ls->param('black_list') == 1, "black list enabled." );

for my $blacklist_this ( 'user@', '@example.com', 'user@example.com' ) {
    my $obj = $lh->add_subscriber({
        -email =>  $blacklist_this ,
        -type      => 'black_list',
    });

    ok( defined($obj), "added one address" );
    undef($obj);
}

(
$not_members, 
$invalid_email,  
$subscribed,
$black_listed,    
$not_white_listed,
$invalid_profile_fields,
) = $lh->filter_subscribers_massaged_for_ht( { -emails => $email_list, } );


    
for my $blacklist_this ( 'user@', '@example.com', 'user@example.com' ) {
    $lh->remove_subscriber(
        { 
            -email => $blacklist_this, 
            -type  => 'black_list', 
        }
    ); 
    $r_count++; 
    ok( $r_count == 1, "removed one address from blacklist ($blacklist_this)" );
    undef($r_count);
}



SKIP: {

    skip
"Multiple Profile Fields is not supported with this current backend."
      if $lh->can_have_subscriber_fields == 0;


    # So now let's see if the required Profile Fields stuff is working: 
    require DADA::ProfileFieldsManager;
    my $pfm = DADA::ProfileFieldsManager->new;

    $pfm->add_field(
        {
            -field          => 'first',
            -required       => 0,
        }
    );
    $pfm->add_field(
        {
            -field          => 'second',
            -required       => 1,
        }
    );
    # uh, I gotta undef this to clear the cache: 
    undef($lh); 
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );




    # This is kinda cheap, since none of the subscribers we've passed have a valid, required field. 
    my $f_emails =  $lh->filter_subscribers_w_meta( { -emails => $email_list, } );
    foreach(@$f_emails){ 
        ok($_->{errors}->{invalid_profile_fields}->{second}->{required} == 1, "yup, required"); 
    }

    ($not_members, 
    $invalid_email,  
    $subscribed,
    $black_listed,    
    $not_white_listed,
    $invalid_profile_fields,
    ) = $lh->filter_subscribers_massaged_for_ht( { -emails => $email_list, } );

    
    ok( eq_array(just_the_emails($invalid_profile_fields), ['user@example.com'] ) == 1, "invalid_profile_fields (user\@example.com)" );



    # So, if we add someone to this list, w/a valid profile field, we should be ok still: 
    push(@$email_list, {email => 'another.user@example.com', fields => {second => 'here be the second!'}}); 

    my $f_emails =  $lh->filter_subscribers_w_meta( { -emails => $email_list, } );

    ($not_members, 
    $invalid_email,  
    $subscribed,
    $black_listed,    
    $not_white_listed,
    $invalid_profile_fields,
    ) = $lh->filter_subscribers_massaged_for_ht( { -emails => $email_list, } );


    diag(' 1 nonmemeber email, 3 invalid emails, 1 invalid profiler? '); 
    ok( eq_array( $subscribed,       [] ) == 1, "subscribed" );
    ok( eq_array( $black_listed,     [] ) == 1, "black_listed (user\@example.com)" );
    ok( eq_array( $subscribed,       [] ) == 1, "Subscribed" );
    ok( eq_array( just_the_emails($not_members),      ['another.user@example.com'] ) == 1, "Not Subscribed ()" );
    ok( eq_array( $not_white_listed, [] ) == 1, "Not White Listed" );
    ok(eq_array( [ sort(@{just_the_emails($invalid_email)}) ], [ sort( 'user', 'example.com', '@example.com' ) ] ) == 1,"Invalid");

    ok( eq_array( just_the_emails($invalid_profile_fields), ['user@example.com'] ) == 1, "invalid_profile_fields" );



 #   use Data::Dumper; 
 #   diag(Dumper($not_members)); 

}





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

sub slurp {

    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open( F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      || die "open $file: $!";
    @r = <F>;
    close(F) || die "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}

