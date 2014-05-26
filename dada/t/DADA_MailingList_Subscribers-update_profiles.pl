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



# Alright, let's stop this kid's stuff: 
ok( $lh->remove_all_subscribers == 3, "Removed all the subscribers!" );
ok($lh->num_subscribers == 0,         "there are now one subscriber on list"); 
ok( $pf->{manager}->remove_all_fields == 3, "removed all fields"); 


my $test_file = 'address_w_fields_pass.csv'; 
`cp t/corpus/csv/$test_file $DADA::Config::TMP/$test_file`;

undef $lh; 
my    $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

my @fields = qw(
first_name
last_name
city
state
favorite_color
_secret
); 

for(@fields){ 
    $pf->{manager}->add_field({ -field => $_,  }); 
}

my ($new_emails) = DADA::App::Guts::csv_subscriber_parse($list, $test_file);


my $s_time = time; 
my ($addresses)
  = $lh->filter_subscribers_w_meta( { -emails => $new_emails, } );
diag 'filter_subscribers_w_meta took: ' . (time - $s_time) . ' seconds';
undef $s_time; 

my $s_time = time; 
foreach (@$addresses) { 
    next if $_->{status} != 1; 
    
    $lh->add_subscriber(
       { 
           -email  => $_->{email}, 
           -fields => $_->{fields}, 
           
       } 
    ); 
}
diag 'adding subscribers took: ' . (time - $s_time) . ' seconds';
undef $s_time; 

# Right - now let's try some searches: 

$partial_listing = { 
    'state' => {
        -operator => '=',
        -value    => 'VT',
    }, 
    'favorite_color' => {
        -operator => '=',
        -value    => 'green',
    }, 
    
};  
( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 4, "four results!"); 
my $updates = $lh->update_profiles({ 
    -update_fields   => { 
        _secret => "Xanadu",
    }, 
    -partial_listing => $partial_listing,
}); 
ok($updates == 4, "four updates!"); 


$partial_listing = { 
    '_secret' => {
        -operator => '=',
        -value    => 'Xanadu',
    }, 
};  
( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == 4, "four new results!"); 


#use Data::Dumper; 
#diag Dumper($subscribers); 

for my $subs(@$subscribers){ 
   for my $f(@{$subs->{fields}}){ 
       if($f->{name} eq 'state'){ 
           ok($f->{value} eq 'VT', "Vermont!"); 
        }
        elsif($f->{name} eq 'favorite_color'){ 
            ok($f->{value} eq 'green', "green!"); 
        }
        elsif($f->{name} eq '_secret'){ 
            ok($f->{value} eq 'Xanadu', "Xanadu!"); 
            
        }
    }
}

ok($lh->print_out_list({-query => 'John'}), "print_out_list correctly returns 10"); 


##############################################################################
# This is a weird test, to make sure that a new field, which should have 
# any value in it, returns when you search for something it isn't. 
#
$pf->{manager}->add_field({ -field => 'new_field',  }); 

$partial_listing = { 
    'new_field' => {
        -operator => '!=',
        -value    => 'something',
    }, 
};  
undef $lh; 
my    $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
my ( $total_num, $subscribers ) = $lh->search_list(
    {
        -partial_listing  => $partial_listing, 
    }
);
ok($total_num == $lh->num_subscribers, "everyone is returned!"); 
##############################################################################





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

