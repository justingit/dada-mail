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
use DADA::Profile::Fields; 

my $ls = DADA::MailingList::Settings->new(    { -list => $list } );
my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
my $pf = DADA::Profile::Fields->new; 

# Let's set this up! 
$pf->{manager}->add_field({ -field => 'name',  }); 
$pf->{manager}->add_field({ -field => 'city',  }); 
$pf->{manager}->add_field({ -field => 'color', }); 

my $subs = [
    {
        email => 'one@example.com', 
        fields => {
            name => 'og One', 
            city => 'og Denver', 
            color => 'og red',
        },  
    },
    {
        email => 'two@example.com', 
        fields => {
            name => 'og Two', 
            city => 'og Boulder', 
            color => 'og blue',
        },  
    },
    {
        email => 'three@example.com', 
        fields => {
            name => 'og Three', 
            city => 'og Durango', 
            color => 'og orange',
        },  
    },   
]; 

for(@$subs){ 
    $lh->add_subscriber(
       { 
           -email  => $_->{email}, 
           -fields => $_->{fields}, 
       } 
    ); 
}


my $partial_listing = { 
    name => {
        -operator => '=',
        -value    => 'og One',
    }, 
};    
my ( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);


ok($total_num == 1, "one result"); 
ok($subscribers->[0]->{email} eq 'one@example.com', "of this specific email!"); 

my $updates = $lh->update_profiles({ 
    -update_fields   => { 
        name => "New Name One", 
    }, 
    -partial_listing => $partial_listing,
}); 
ok($updates == 1, "one email updated!"); 

my ( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 0, "zero results!"); 

$partial_listing = { 
    name => {
        -operator => '=',
        -value    => 'New Name One',
    }, 
};  

( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 1, "one results!");  





$partial_listing = { 
    'email' => {
        -operator => 'LIKE',
        -value    => 'example.com',
    }, 
};  
( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 3, "three results!");  




$updates = $lh->update_profiles({ 
    -update_fields   => { 
        color => "green", 
    }, 
    -partial_listing => $partial_listing,
}); 
ok($updates == 3, "Three subs updated!"); 






$partial_listing = { 
    'color' => {
        -operator => '=',
        -value    => 'green',
    }, 
};  
( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 3, "three results!");  




$partial_listing = { 
    'name' => {
        -operator => 'LIKE',
        -value    => 'og',
    }, 
};  
( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 2, "two results!");  


$updates = $lh->update_profiles({ 
    -update_fields   => { 
        city => "Omaha", 
    }, 
    -partial_listing => $partial_listing,
}); 
ok($updates == 2, "two subs updated!"); 














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

