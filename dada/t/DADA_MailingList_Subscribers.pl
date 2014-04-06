#!/usr/bin/perl 

my $large_num = 1000; 

use lib
  qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib );
BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }
use DADA::Config; 

use dada_test_config;

#diag('$DADA::Config::SUBSCRIBER_DB_TYPE ' . $DADA::Config::SUBSCRIBER_DB_TYPE);

use strict;

use Carp;

# This doesn't work, if we're eval()ing it.
# use Test::More qw(no_plan);

my $list = dada_test_config::create_test_list(
    { -remove_existing_list => 1, -remove_subscriber_fields => 1 } );

use DADA::MailingList::Subscribers;
my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

use DADA::MailingList::Settings;
my $ls = DADA::MailingList::Settings->new( { -list => $list } );


chmod( 0777, $DADA::Config::TMP . '/mail.txt' );

ok(
    $lh->{ls}->isa('DADA::MailingList::Settings'),
    "looks like there's a Settings obj in ->{ls}, good!"
);


$ls->save( { black_list => 0 } );
ok( $ls->param('black_list') == 0, "black list disabled." );

# Oh geez. This should have a million tests.
my @good_addresses =
  ( 'user@example.com', 'another@here.com', 'blah@somewhere.co.uk' );
for my $good_address (@good_addresses) {
    my ( $status, $details ) =
      $lh->subscription_check( { -email => $good_address, } );
    ok( $status == 1,                  "Status is 1" );
    ok( $details->{invalid_email} != 1, "Address seen as valid" );
}

my @bad_addresses = qw(These are all bad addresses yup);
for my $bad_address (@bad_addresses) {
    my ( $status, $details ) =
      $lh->subscription_check( { -email => $bad_address, } );
    ok( $status == 0,                  "Status is 0" );
    ok( $details->{invalid_email} == 1, "Address seen as invalid" );
}

ok(
    $lh->can_have_subscriber_fields == 1
      || $lh->can_have_subscriber_fields == 0,
    "'->can_have_subscriber_fields' returns either 1 or 0"
);

### move_subscriber

eval { $lh->move_subscriber(); };
ok( $@, "calling move_subscriber without any parameters causes an error!: $@" );

eval { $lh->move_subscriber( { -to => 'blahblah' } ); };
ok( $@,
    "calling move_subscriber with incorrect -to parameter causes an error!: $@"
);

eval { $lh->move_subscriber( { -to => 'blahblah', -from => 'yayaya' } ); };
ok( $@,
"calling move_subscriber with incorrect -to and -from parameter causes an error!: $@"
);

eval {
    $lh->move_subscriber(
        { -to => 'blahblah', -from => 'yayaya', -email => 'whackawhacka' } );
};
ok( $@,
"calling move_subscriber with incorrect list_type in, '-to' causes an error!: $@"
);

eval {
    $lh->move_subscriber(
        { -to => 'list', -from => 'yayaya', -email => 'whackawhacka' } );
};
ok( $@,
"calling move_subscriber with incorrect list_type in, '-from' causes an error!: $@"
);

eval {
    $lh->move_subscriber(
        { -to => 'list', -from => 'black_list', -email => 'whackawhacka' } );
};
ok( $@,
    "calling move_subscriber with invalid address causes an error(!)!: $@" );

# Erm - but that's not an invalide Address?
eval {
    $lh->move_subscriber(
        {
            -to    => 'list',
            -from  => 'black_list',
            -email => 'neverwasinthelist@example.com'
        }
    );
};
ok( $@,
    "calling move_subscriber with invalid address causes an error(2)!: $@" );

ok(
    $lh->add_subscriber(
        {
            -email => 'mytest@example.com',
            -type  => 'list',
        }
    ),
    'added mytest@example.com list'
);

ok(
    $lh->add_subscriber(
        {
            -email => 'mytest@example.com',
            -type  => 'black_list',
        }
    ),
    'added mytest@example.com black_list'
);

eval {
    $lh->move_subscriber(
        {
            -to    => 'list',
            -from  => 'black_list',
            -email => 'mytest@example.com'
        }
    );
};
ok( $@,
"calling move_subscriber with address already subscribed in, '-to' causes error!: $@"
);

ok(
    $lh->remove_subscriber({ 
        -email => 'mytest@example.com',
        -type       => 'list'
    })
);
ok(
    $lh->remove_subscriber({
        -email => 'mytest@example.com',
        -type       => 'black_list',
    })
);

#diag "Justin! there are, " . $lh->num_subscribers . "on this list."; 

# So, add_subscriber actually doesn't have a dupe check by default, so it is possible to 
# add the same address multiple times. Most of the app knows this, and takes pains to make sure dupe check is enabled, 
# just in case, but if it's not, it shouldn't ever, ever, ever add the same address twice to one sublist. Ever. 

# So rather, let's start by doing just that: 
ok(
    $lh->add_subscriber(
        {
            -email => 'duper@example.com',
            -type  => 'sub_confirm_list',
	        -dupe_check => {
	            -enable  => 1,
	            -on_dupe => 'ignore_add',
	        },

        }
    ),
    'added duper@example.com sub_confirm_list (1)'
); 
ok(
    $lh->add_subscriber(
        {
            -email => 'duper@example.com',
            -type  => 'sub_confirm_list',
	        -dupe_check => {
	            -enable  => 1,
	            -on_dupe => 'ignore_add',
	        },

        }
    ) eq undef,
    'couldn\'t add duper@example.com sub_confirm_list (2)'
);
ok(
    $lh->add_subscriber(
        {
            -email => 'duper@example.com',
            -type  => 'sub_confirm_list',
	        -dupe_check => {
	            -enable  => 1,
	            -on_dupe => 'ignore_add',
	        },

        }
    ) eq undef,
    'couldn\'t add duper@example.com sub_confirm_list (3)'
); 

$lh->move_subscriber({
    -email => 'duper@example.com',
	-from  => 'sub_confirm_list', 
	-to    => 'list',
#	{ 
#	    -dupe_check    => {
#							-enable  => 1, 
#							-on_dupe => 'only_move_once',  
 #   					}, 
#	} 
});

ok($lh->num_subscribers == 1, "there are now one subscriber on list"); 
ok( $lh->remove_all_subscribers == 1, "Removed all the subscribers!" );



###

#### copy_subscriber

eval { $lh->copy_subscriber(); };
ok( $@, "calling copy_subscriber without any parameters causes an error!: $@" );

eval { $lh->copy_subscriber( { -to => 'blahblah' } ); };
ok( $@,
    "calling copy_subscriber with incorrect -to parameter causes an error!: $@"
);

eval { $lh->copy_subscriber( { -to => 'blahblah', -from => 'yayaya' } ); };
ok( $@,
"calling copy_subscriber with incorrect -to and -from parameter causes an error!: $@"
);

eval {
    $lh->copy_subscriber(
        { -to => 'blahblah', -from => 'yayaya', -email => 'whackawhacka' } );
};
ok( $@,
"calling move_subscriber with incorrect list_type in, '-to' causes an error!: $@"
);

eval {
    $lh->copy_subscriber(
        { -to => 'list', -from => 'yayaya', -email => 'whackawhacka' } );
};
ok( $@,
"calling copy_subscriber with incorrect list_type in, '-from' causes an error!: $@"
);

eval {
    $lh->copy_subscriber(
        { -to => 'list', -from => 'black_list', -email => 'whackawhacka' } );
};
ok( $@, "calling copy_subscriber with invalid address causes an error!: $@" );

eval {
    $lh->copy_subscriber(
        {
            -to    => 'list',
            -from  => 'black_list',
            -email => 'mytest@example.com'
        }
    );
};
ok( $@, "calling copy_subscriber with invalid address causes an error!: $@" );

ok(
    $lh->add_subscriber(
        {
            -email => 'mytest@example.com',
            -type  => 'list',
        }
    ),
    'added mytest@example.com list'
);

ok(
    $lh->add_subscriber(
        {
            -email => 'mytest@example.com',
            -type  => 'black_list',
        }
    ),
    'added mytest@example.com black_list'
);

eval {
    $lh->copy_subscriber(
        {
            -to    => 'list',
            -from  => 'black_list',
            -email => 'mytest@example.com'
        }
    );
};
ok( $@,
"calling copy_subscriber with address already subscribed in, '-to' causes error!: $@"
);

ok(
    $lh->remove_subscriber(
        { -email => 'mytest@example.com', -type => 'list' }
    ),
    'removed mytest@example.com list'
);
ok(
    $lh->remove_subscriber(
        { -email => 'mytest@example.com', -type => 'black_list' }
    ),
    'removed mytest@example.com black_list'
);

ok(
    $lh->add_subscriber(
        {
            -email => 'mytest@example.com',
            -type  => 'list',
        }
    ),
    'added mytest@example.com'
);

ok(
    $lh->copy_subscriber(
        {
            -to    => 'black_list',
            -from  => 'list',
            -email => 'mytest@example.com'
        }
    ),
    "Calling copy_subscriber with correct parameters works!"
);
ok(
    $lh->remove_subscriber({
        -email => 'mytest@example.com',
        -type  => 'list',
    }),
    'removed mytest@example.com list'
);
ok(
    $lh->remove_subscriber({
        -email => 'mytest@example.com',
        -type       => 'black_list'
    }),
    'removed mytest@example.com black_list'
);

###

SKIP: {

    skip
"Multiple Profile Fields is not supported with this current backend."
      if $lh->can_have_subscriber_fields == 0;

    ok( eq_array( $lh->subscriber_fields, [] ),
        'no fields currently present.' );

    my $s = $lh->add_subscriber_field( { -field => 'myfield' } );
    ok( $s == 1, "adding a new field is successful" );

    #sleep(30);

    ok( eq_array( $lh->subscriber_fields, ['myfield'] ),
        'New field is being reported.' );
    undef($s);

    #diag "sleeeeeping";
    #sleep(400);

    #diag "sleep";
    #sleep(400);

    my $s = $lh->remove_subscriber_field( { -field => 'myfield' } );
    ok( $s == 1, "removing a new field is successful" );

    ### validate_subscriber_field_name

    # The order of these is important for later tests....
    my @bad_field_names = (
        'this one has spaces',
        '"thisOneHasQuotes"',
'thisOneIsOverSixtyFourCharactersNoReallyItIsPleaseJustBeleiveMeOnThisOnePleasePleasePleaseOK',
        '/slashes/',
        '',
        '@WeirdCharacters+',
        "$dada_test_config::UTF8_STR",
    );
    my $status  = 0;
    my $details = {};

    for my $bfn (@bad_field_names) {
        ( $status, $details ) =
          $lh->validate_subscriber_field_name( { -field => $bfn } );
        ok( $status == 0, "Bad Field is reporting an error." );
        undef($status);
        undef($details);
    }

    my $s = $lh->add_subscriber_field( { -field => 'myfield' } );
    ok( eq_array( $lh->subscriber_fields, ['myfield'] ),
        'New field is being reported.' );

    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => 'myfield' } );
    ok( $status == 0, "Error being reported by duplicate field" );
    ok( $details->{field_exists} == 1,
        "Error being report as, 'field_exists'" );
    undef($status);
    undef($details);

    my $s = $lh->remove_subscriber_field( { -field => 'myfield' } );
    ok( $s == 1, "removing a new field is successful" );

    # spaces
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[0] } );
    ok( $status == 0,            "Error being reported" );
    ok( $details->{spaces} == 1, "Error being report as, 'spaces'" );
    undef($status);
    undef($details);

    # quotes
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[1] } );
    ok( $status == 0,            "Error being reported" );
    ok( $details->{quotes} == 1, "Error being report as, 'quotes'" );
    undef($status);
    undef($details);

    # field_name_too_long
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[2] } );
    ok( $status == 0, "Error being reported" );
    ok(
        $details->{field_name_too_long} == 1,
        "Error being report as, 'field_name_too_long'"
    );
    undef($status);
    undef($details);

    # slashes_in_field_name
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[3] } );
    ok( $status == 0, "Error being reported" );
    ok(
        $details->{slashes_in_field_name} == 1,
        "Error being report as, 'slashes_in_field_name'"
    );
    undef($status);
    undef($details);

    # field_blank
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[4] } );
    ok( $status == 0,                 "Error being reported" );
    ok( $details->{field_blank} == 1, "Error being report as, 'field_blank'" );
    undef($status);
    undef($details);

    # weird_characters
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[5] } );
    ok( $status == 0, "Error being reported" );
    ok(
        $details->{weird_characters} == 1,
        "Error being report as, 'weird_characters'"
    );
    undef($status);
    undef($details);

    # UTF8/unicode
    ( $status, $details ) =
      $lh->validate_subscriber_field_name( { -field => $bad_field_names[6] } );
    ok( $status == 0, "Error being reported" );
    ok(
        $details->{weird_characters} == 1,
        "Error being report as, 'weird_characters'"
    );
    undef($status);
    undef($details);

    for (qw(email_id email list list_type list_status)) {
        ( $status, $details ) =
          $lh->validate_subscriber_field_name( { -field => $_ } );
        ok( $status == 0, "Error being reported" );
        ok(
            $details->{field_is_special_field} == 1,
            "Error being report as, 'field_is_special_field'"
        );
        undef($status);
        undef($details);
    }

    eval { ( $status, $details ) = $lh->validate_subscriber_field_name(); };
    ok( $@,
"calling validate_subscriber_field_name without any parameters causes an error!: $@"
    );
    undef($status);
    undef($details);

    ###

    ### subscriber_field_exists
    eval { $lh->subscriber_field_exists };
    ok( $@,
"calling subscriber_field_exists without any parameters causes an error!: $@"
    );

    my $s = $lh->add_subscriber_field( { -field => 'myfield' } );
    ok( eq_array( $lh->subscriber_fields, ['myfield'] ),
        'New field is being reported.' );
    undef($s);

    ok(
        $lh->subscriber_field_exists( { -field => 'myfield' } ) == 1,
        "field is being reported as being existingly...like"
    );

    my $s = $lh->remove_subscriber_field( { -field => 'myfield' } );
    ok( $s == 1, "removing a new field is successful" );

    ###

    ### add_subscriber_field w/fallback field....

    my $ff = {
        one       => 'This is one!',
        two       => 'This is two!',
        three     => 'This is three!',
        four      => 'This is four!',
        five      => 'This is five!',
        six       => 'This is six!',
        seven     => 'This is seven!',
        eight     => 'This is eight!',
        nine      => 'This is nine!',
        ten       => 'This is ten!',
        eleven    => 'This is eleven!',
        twelve    => 'This is twelve!',
        thirteen  => 'This is thirteen!',
        fourteen  => 'This is fourteen!',
        fifteen   => 'This is fifteen!',
        sixteen   => 'This is sixteen!',
        seventeen => 'This is seventeen!',
        eighteen  => 'This is eighteen!',
        nineteen  => 'This is nineteen!',
        twenty    => 'This is twenty!',
    };

    for ( keys %$ff ) {

        my $s = $lh->add_subscriber_field(
            { -field => $_, -fallback_value => $ff->{$_} } );
        ok(
            $s == 1,
            "adding a new field, " 
              . $_
              . "with fallback of, "
              . $ff->{$_}
              . "is successful"
        );
        undef $s;

        my $attr = $lh->get_all_field_attributes;

        ok(
            $attr->{$_}->{fallback_value} eq $ff->{$_},
            $ff->{$_}
              . ' equals: '
              . $attr->{$_}->{fallback_value} . "for: "
              . $_
        );

        # This won't kill us, but it will return an, "undef"
        my $s = $lh->add_subscriber_field(
            { -field => $_, -fallback_value => $ff->{$_} } );
        ok(
            $s eq undef,
            "adding a new field, " 
              . $_
              . "with fallback of, "
              . $ff->{$_}
              . "isn't successful"
        );
        undef $s;

    }

    for ( keys %$ff ) {

        ok(
            $lh->remove_subscriber_field( { -field => $_ } ),
            'Field, ' . $_ . ' removed successfully'
        );
        my $attr = $lh->get_all_field_attributes;
        ok( !exists( $attr->{$_} ),
            "old fallback value for $_ has been removed." );

    }

    ###

    ### remove_subscriber_field

    for (qw(email_id email list list_type list_status)) {
        eval { $lh->remove_subscriber_field( { -field => $_ } ); };
        ok( $@,
"calling remove_subscriber_field with special field name causes error!: $@"
        );
    }

    eval { $lh->remove_subscriber_field( { -field => 'foo' } ); };
    ok( $@,
"calling remove_subscriber_field with a non-existent field causes error!: $@"
    );

    ok( $lh->add_subscriber_field( { -field => 'foo' } ),
        'New field created successfully' );
    ok( $lh->remove_subscriber_field( { -field => 'foo' } ),
        'New field removed successfully' );

    ###

    #### copy_subscriber w/Profile Fields
    # the idea is that the subscriber field information
    # should be copied over correctly as well.

    ok(
        $lh->add_subscriber_field( { -field => 'first_name' } ),
        'New field, first_name created successfully'
    );
    ok(
        $lh->add_subscriber_field( { -field => 'last_name' } ),
        'New field, last_name created successfully'
    );

    ok(
        $lh->add_subscriber(
            {
                -email  => 'one@example.com',
                -type   => 'list',
                -fields => {
                    first_name => 'One First Name',
                    last_name  => 'One Last Name',
                }
            }
        ),
        'added, one@example.com'
    );
    ok(
        $lh->copy_subscriber(
            {
                -email => 'one@example.com',
                -from  => 'list',
                -to    => 'black_list',
            }
        ),
        'copied one@example.com from list to black_list'
    );

    ok(
        $lh->check_for_double_email(
            -Email => 'one@example.com',
            -Type  => 'list'
          ) == 1,
        'check_for_double_email for one@example.com on list returns, 1'
    );
    ok(
        $lh->check_for_double_email(
            -Email => 'one@example.com',
            -Type  => 'black_list'
          ) == 1,
        'check_for_double_email for one@example.com on black_list returns, 1'
    );

    my $one_info =
      $lh->get_subscriber( { -email => 'one@example.com', -type => 'list' } );

    use Data::Dumper;

    #diag Data::Dumper::Dumper($one_info);

    ok(
        $one_info->{first_name} eq 'One First Name',
        'first_name equals "One First Name"'
    );
    ok(
        $one_info->{last_name} eq 'One Last Name',
        'last-name equals "One Last Name"'
    );
    undef $one_info;

    my $one_info = $lh->get_subscriber(
        { -email => 'one@example.com', -type => 'black_list' } );
    ok( $one_info->{first_name} eq 'One First Name' );
    ok( $one_info->{last_name}  eq 'One Last Name' );
    undef $one_info;

    ok(
        $lh->remove_subscriber({
            -email => 'one@example.com',
            -type       => 'list'
        }),
        'removed one@example.com from list'
    );
    ok(
        $lh->remove_subscriber({
            -email => 'one@example.com',
            -Type  => 'black_list'
        }),
        'removed one@example.com from black_list'
    );

    ok( $lh->remove_subscriber_field( { -field => 'first_name' } ),
        'removed field first_name' );
    ok( $lh->remove_subscriber_field( { -field => 'last_name' } ),
        'removed field last_name' );

    # Stress Testin'
    my $count = 100;
    while ( $count > 0 ) {
        ok(
            $lh->add_subscriber_field( { -field => 'foo' . $count } ),
            'New field # ' . $count . ' created successfully'
        );
        $count--;
    }

    $count = 100;
    while ( $count > 0 ) {
        ok(
            $lh->remove_subscriber_field( { -field => 'foo' . $count } ),
            'New field # ' . $count . ' removed successfully'
        );
        $count--;
    }

    ok( -e $DADA::Config::TMP );

### Mail Merging stuff - should really be in its own test file.

    # First, let's create some fields:
    #

    my $s = $lh->add_subscriber_field(
        { -field => 'first_name', -fallback_value => 'John' } );
    ok(
        $s == 1,
        "adding a new field, "
          . 'first_name'
          . "with fallback of, " . 'John'
          . "is successful"
    );
    undef $s;

    my $s = $lh->add_subscriber_field(
        { -field => 'last_name', -fallback_value => 'Doe' } );
    ok(
        $s == 1,
        "adding a new field, "
          . 'last_name'
          . "with fallback of, " . 'Doe'
          . "is successful"
    );
    undef $s;

    ok(
        $lh->add_subscriber(
            {
                -email  => 'mike.kelley@example.com',
                -type   => 'list',
                -fields => {
                    first_name => 'Mike',
                    last_name  => 'Kelley',
                }
            }
        )
    );
    ok( -e $DADA::Config::TMP );

    my $sub_info =
      $lh->get_subscriber( { -email => 'mike.kelley@example.com' } );
    ok( $sub_info->{first_name} eq 'Mike',
        "first_name eq 'Mike' (" . $sub_info->{first_name} . ")" );
    ok( $sub_info->{last_name} eq 'Kelley',
        "last_name eq 'Kelley'  (" . $sub_info->{last_name} . ")" );
    undef($sub_info);

    ok(
        $lh->add_subscriber(
            {
                -email  => 'raymond.pettibon@example.com',
                -type   => 'list',
                -fields => {
                    first_name => 'Raymond',
                    last_name  => 'Pettibon',
                }
            }
        ),
        'Add Raymond Pettibon'
    );

    my $sub_info =
      $lh->get_subscriber( { -email => 'raymond.pettibon@example.com' } );
    ok( $sub_info->{first_name} eq 'Raymond' );
    ok( $sub_info->{last_name}  eq 'Pettibon' );
    undef($sub_info);

    ok( -e $DADA::Config::TMP );

    ok(
        $lh->add_subscriber(
            {
                -email  => 'marcel.duchamp@example.com',
                -type   => 'list',
                -fields => {
                    first_name => 'Marcel',
                    last_name  => 'Duchamp',
                }
            }
        ),
        'Added Marcel Duchamp'
    );

    my $sub_info =
      $lh->get_subscriber( { -email => 'marcel.duchamp@example.com' } );
    ok( $sub_info->{first_name} eq 'Marcel' );
    ok( $sub_info->{last_name}  eq 'Duchamp' );
    undef($sub_info);

    ok(
        $lh->add_subscriber(
            {
                -email  => 'man.ray@example.com',
                -type   => 'list',
                -fields => {
                    first_name => 'Man',
                    last_name  => 'Ray',
                }
            }
        ),
        'Add Man Ray'
    );
    ok( -e $DADA::Config::TMP );

    my $sub_info = $lh->get_subscriber( { -email => 'man.ray@example.com' } );
    ok( $sub_info->{first_name} eq 'Man', 'first_name Man' );
    ok( $sub_info->{last_name}  eq 'Ray', 'last_name Ray' );
    undef($sub_info);

    ok(
        $lh->add_subscriber(
            {
                -email => 'no.one@example.com',
                -type  => 'list',
            }
        ),
        'added no.one@example.com'
    );

    my $sub_info = $lh->get_subscriber( { -email => 'no.one@example.com' } );
    ok( $sub_info->{first_name} eq '', 'nothing for first_name' );
    ok( $sub_info->{last_name}  eq '', 'nothing for first_name' );
    undef($sub_info);

    my $body = q{ 
    
    email: <!-- tmpl_var subscriber.email -->, First Name: <!-- tmpl_var subscriber.first_name -->, Last Name: <!-- tmpl_var subscriber.last_name -->

    <!-- tmpl_var subscriber.first_name --><!-- tmpl_var subscriber.first_name --><!-- tmpl_var subscriber.first_name --><!-- tmpl_var subscriber.first_name --><!-- tmpl_var subscriber.first_name --><!-- tmpl_var subscriber.first_name -->
    <!-- tmpl_var subscriber.last_name --><!-- tmpl_var subscriber.last_name --><!-- tmpl_var subscriber.last_name --><!-- tmpl_var subscriber.last_name --><!-- tmpl_var subscriber.last_name --><!-- tmpl_var subscriber.last_name --><!-- tmpl_var subscriber.last_name -->
    
    };

    ok( -e $DADA::Config::TMP, 'file exists.' );

    require DADA::Security::Password;
    my $test_msg_fields = {
        Subject      => 'Hello.',
        'Message-ID' => '<'
          . DADA::App::Guts::message_id() . '.'
          . DADA::Security::Password::generate_rand_string('1234567890') . '@'
          . 'some-example-with-dashes.com' . '>',
        Body => $body,
    };

    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new( { -list => $list } );

    #$mh->test_send_file($DADA::Config::TMP . '/mail.txt');
    $mh->test(1);
    require DADA::Mail::MailOut;
    my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
    my $rv;
    eval {
        $rv = $mailout->create(
            {
                -fields    => $test_msg_fields,
                -mh_obj    => $mh,
                -list_type => 'list'
            }
        );
    };

    if ($@) {
        diag 'Error returned: ' . $@;
    }
    ok( !$@,
"Passing  a correct DADA::Mail::Send object does not create an error! - $@"
    );
    ok( $rv == 1, " create() returns 1!" );

    my $tmp_sub_list = $mailout->dir . '/' . 'tmp_subscriber_list.txt';
    ok( -e $DADA::Config::TMP );

    ok( -e $tmp_sub_list, $tmp_sub_list . ' exists.' );

    open my $TMP_SUB_LIST, '<', $tmp_sub_list
      or die "Cannot read file at: '" . $tmp_sub_list . "' because: " . $!;

    my $contents = do { local $/; <$TMP_SUB_LIST> };

    #diag $contents;

    close $TMP_SUB_LIST or die $!;

    like( $contents, qr/Mike\,Kelley/ );
    like( $contents, qr/Raymond\,Pettibon/ );
    like( $contents, qr/Marcel\,Duchamp/ );
    like( $contents, qr/Man\,Ray/ );

    # ok($contents =~ m/John\:\:Doe/);

    #my $msg = do { local $/; <$MSG_FILE> };
    ok( $mailout->clean_up() == 1, "cleanup still returned a TRUE value!" );

    undef($mailout);

    ok( -e $DADA::Config::TMP );

  #diag( 'orig: $DADA::Config::MAIL_SETTINGS ' . $DADA::Config::MAIL_SETTINGS );

    $ls->save(
        {
            enable_bulk_batching => 0,

           # My tests here don't take into consideration email encoding, so this
           # Kind of hacks unsupport in:

            plaintext_encoding => '8bit',
            html_encoding      => '8bit',

        }
    );

    unlink $DADA::Config::TMP . '/mail.txt'
      if ( -e $DADA::Config::TMP . '/mail.txt' );

    # $DADA::Config::MAIL_SETTINGS = '>>' . $DADA::Config::TMP . '/mail.txt';

   #diag( 'now: $DADA::Config::MAIL_SETTINGS ' . $DADA::Config::MAIL_SETTINGS );

    my $mh = DADA::Mail::Send->new( { -list => $list } );
    $mh->test_send_file( $DADA::Config::TMP . '/mail.txt' );
    $mh->test(1);
    my $msg_id = $mh->mass_send( %$test_msg_fields, );

    my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
    my $associate_worked = $mailout->associate( $msg_id, 'list' );
    ok( $associate_worked == 1, "We assocaited the mailing with what we got." );
    ok( -e $DADA::Config::TMP );

    my $status = $mailout->status;

    #my $percent_done = $status->{percent_done};
    my $seconds = 60;

    ok( -e $DADA::Config::TMP, "TMP dir still around..." );

  #diag ' $mailout->status->{percent_done} ' . $mailout->status->{percent_done};

    while ( $mailout->status->{percent_done} < 100 ) {

        ok( -e $DADA::Config::TMP, "TMP dir still around (2)..." );

        #diag ("Sleeping...");

        sleep(1);

#diag q{ DADA::Mail::MailOut::mailout_exists($list, $msg_id, 'list') } . DADA::Mail::MailOut::mailout_exists($list, $msg_id, 'list');

        if (
            DADA::Mail::MailOut::mailout_exists( $list, $msg_id, 'list' ) == 1 )
        {

  #diag("waiting for mailing to finish... " . $mailout->status->{percent_done});
            $seconds--;
            if ( $seconds == 0 ) {
                ok( -e $DADA::Config::TMP );

                #diag("Waiting timed out! Breaking out!");
                $mailout->clean_up();

                #diag "here 8";
                undef $mailout;
                last;
            }
        }
        else {
            undef $mailout;

            #diag "Sending is finished...";
            last;
        }

    }
    ok( -e $DADA::Config::TMP );

    sleep(2);

    undef $contents;

    open my $TMP_MAIL_FILE, '<', $DADA::Config::TMP . '/mail.txt'
      or die "Cannot read file at: '"
      . $DADA::Config::TMP
      . '/mail.txt'
      . "' because: "
      . $!;

    my $contents = do { local $/; <$TMP_MAIL_FILE> };
    close $TMP_MAIL_FILE or die $!;

    my $l =
      'email: mike.kelley@example.com, First Name: Mike, Last Name: Kelley';
    my $l2 = 'MikeMikeMikeMikeMikeMike';
    my $l3 = 'KelleyKelleyKelleyKelleyKelleyKelleyKelley';
    
    # diag '$contents ' . $contents; 
    
    like( $contents, qr/$l/ );
    like( $contents, qr/$l2/ );
    like( $contents, qr/$l3/ );
    undef $l;
    undef $l2;
    undef $l2;

    my $l =
'email: raymond.pettibon@example.com, First Name: Raymond, Last Name: Pettibon';
    my $l2 = 'RaymondRaymondRaymondRaymondRaymondRaymond';
    my $l3 = 'PettibonPettibonPettibonPettibonPettibonPettibonPettibon';
    like( $contents, qr/$l/ );
    like( $contents, qr/$l2/ );
    like( $contents, qr/$l3/ );
    undef $l;
    undef $l2;
    undef $l2;

    my $l  = 'email: man.ray@example.com, First Name: Man, Last Name: Ray';
    my $l2 = 'ManManManManManMan';
    my $l3 = 'RayRayRayRayRayRayRay';
    like( $contents, qr/$l/ );
    like( $contents, qr/$l2/ );
    like( $contents, qr/$l3/ );
    undef $l;
    undef $l2;
    undef $l2;

    my $l  = 'email: no.one@example.com, First Name: John, Last Name: Doe';
    my $l2 = 'JohnJohnJohnJohnJohnJohn';
    my $l3 = 'DoeDoeDoeDoeDoeDoeDoe';
    like( $contents, qr/$l/,
        'FOUND: email: no.one@example.com, First Name: John, Last Name: Doe' );

    #sleep(400);
    #diag "Sleeing!";

    like( $contents, qr/$l2/, 'FOUND: JohnJohnJohnJohnJohnJohn' );
    like( $contents, qr/$l3/, 'FOUND: DoeDoeDoeDoeDoeDoeDoe' );
    undef $l;
    undef $l2;
    undef $l2;


    # We'll just do this again, for good measure...

    unlink $DADA::Config::TMP . '/mail.txt'
      if ( -e $DADA::Config::TMP . '/mail.txt' );

    #$DADA::Config::MAIL_SETTINGS = '>>' . $DADA::Config::TMP . '/mail.txt';

    undef $mh;
    undef $msg_id;
    undef $mailout;

    my $mh = DADA::Mail::Send->new( { -list => $list } );
    $mh->test_send_file( $DADA::Config::TMP . '/mail.txt' );
    $mh->test(1);
    $mh->partial_sending( 
        { 
            first_name => {
                -operator => '=',  
                -value => 'Raymond', 
            } 
        } 
    );
    my $mess_id = '<'
      . DADA::App::Guts::message_id() . '.'
      . DADA::Security::Password::generate_rand_string('1234567890') . '@'
      . 'some-example-with-dashes.com' . '>';
    my $msg_id = $mh->mass_send( %$test_msg_fields, 'Message-ID' => $mess_id, );

    my $mailout = DADA::Mail::MailOut->new( { -list => $list } );
    my $associate_worked = $mailout->associate( $msg_id, 'list' );
    ok( $associate_worked == 1, "We assocaited the mailing with what we got." );

    while ( $mailout->status->{percent_done} < 100 ) {

        #diag ("Sleeping...");

        sleep(1);
        if (
            DADA::Mail::MailOut::mailout_exists( $list, $msg_id, 'list' ) == 1 )
        {

  #diag("waiting for mailing to finish... " . $mailout->status->{percent_done});

        }
        else {
            undef $mailout;

            #diag "Sending is finished...";
            last;
        }

        $seconds--;
        if ( $seconds == 0 ) {

            #diag("Waiting timed out! Breaking out!");
            $mailout->clean_up();
            undef $mailout;
            last;
        }
    }

    undef $contents;
    undef $TMP_MAIL_FILE;

    open my $TMP_MAIL_FILE, '<', $DADA::Config::TMP . '/mail.txt'
      or die "Cannot read file at: '"
      . $DADA::Config::TMP
      . '/mail.txt'
      . "' because: "
      . $!;

    my $contents = do { local $/; <$TMP_MAIL_FILE> };
    close $TMP_MAIL_FILE or die $!;

    diag '$contents: ' . $contents;


    my $l = quotemeta('email: mike.kelley@example.com, First Name: Mike, Last Name: Kelley');
    my $l2 = quotemeta('MikeMikeMikeMikeMikeMike');
    my $l3 = quotemeta('KelleyKelleyKelleyKelleyKelleyKelleyKelley');

    ok( $contents !~ m/$l/,  "Found: '$l'");
    ok( $contents !~ m/$l2/, "Found: '$l2'");
    ok( $contents !~ m/$l3/, "Found: '$l3'");
    undef $l;
    undef $l2;
    undef $l2;

    my $l = quotemeta(
'email: raymond.pettibon@example.com, First Name: Raymond, Last Name: Pettibon'
    );
    my $l2 = quotemeta('RaymondRaymondRaymondRaymondRaymondRaymond');
    my $l3 =
      quotemeta('PettibonPettibonPettibonPettibonPettibonPettibonPettibon');
    ok( $contents =~ m/$l/ );
    ok( $contents =~ m/$l2/ );
    ok( $contents =~ m/$l3/ );
    undef $l;
    undef $l2;
    undef $l2;

    my $l =  quotemeta('email: man.ray@example.com, First Name: Man, Last Name: Ray');
    my $l2 = quotemeta('ManManManManManMan');
    my $l3 = quotemeta('RayRayRayRayRayRayRay');
    ok( $contents !~ m/$l/,  "Did not find: $l");
    ok( $contents !~ m/$l2/, "Did not find: $l2");
    ok( $contents !~ m/$l3/, "Did not find: $l3"); 
    undef $l;
    undef $l2;
    undef $l2;

### This is sort of weird, since this is a little more low level than we just did, but...

    undef $lh;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );

    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list'
     );

    ok( ($lh->num_subscribers + 1) == $total_sending_out_num,
        "This file is to send to " . $total_sending_out_num . 'subscribers' );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);
    sleep(1);


	# this is to make sure the mass_mailing_send_to_list_owner pref works
	$ls->save({mass_mailing_send_to_list_owner => 0}); 
	# reset the setttings...
    undef $lh;
       my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );	
    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
      );

	#diag "DEV: \$total_sending_out_num" . $total_sending_out_num;
	#diag "DEV \$lh->num_subscribers " . $lh->num_subscribers; 
    ok(
        $total_sending_out_num == $lh->num_subscribers,
        "This file is to send to " . $lh->num_subscribers . " people ($total_sending_out_num)",
    );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);
	$ls->save({mass_mailing_send_to_list_owner => 1}); 
	#/ this is to make sure the mass_mailing_send_to_list_owner pref works
	undef $lh;
       my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );	

	



    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
        -partial_sending => { 
            'first_name' => { 
                -operator => '=',
                -value => 'Raymond', 
            } 
        },
      );

    ok(
        $total_sending_out_num == 2,
        "This file is to send to 2 people ($total_sending_out_num)",
    );

    #diag "sleep! kill me!";
    #sleep(600);

    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);

    sleep(1);

    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
        -partial_sending => { 
            'first_name' => { 
                -operator => 'LIKE', 
                -value    => 'a'
            } 
        },
      );

    ok(
        $total_sending_out_num == 4,
        "This file is to send to 4 people ($total_sending_out_num)",
    );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);

    sleep(1);

    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
        -partial_sending => { 'last_name' => { -operator => 'LIKE', -value => 'a' } },
      );

    #diag "file, '$path_to_list': \n" . slurp($path_to_list);

    ok(
        $total_sending_out_num == 3,
        "This file is to send to 3 people ($total_sending_out_num)",
    );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);

    sleep(1);

    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
        -partial_sending => { 
            last_name => { 
                -operator => '=', 
                -value    => 'Duchamp', 
            } 
        },
      );

    ok(
        $total_sending_out_num == 2,
        "This file is to send to 2 people ($total_sending_out_num)",
    );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);

    sleep(1);

    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
        -partial_sending => { 'first_name' => { -operator => 'LIKE', -value => 'Ma' } },
      );

    ok(
        $total_sending_out_num == 3,
        "This file is to send to 3 people ($total_sending_out_num)",
    );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);

    ok(
        $lh->add_subscriber(
            {
                -email  => 'raymond.lame@example.com',
                -type   => 'list',
                -fields => {
                    first_name => 'Raymond',
                    last_name  => 'Lame',
                }
            }
        )
    );

    sleep(1);

    my ( $path_to_list, $total_sending_out_num ) =
      $lh->create_mass_sending_file(
        -ID   => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type => 'list',
        -partial_sending => { 'first_name' => { -operator => '=', -value => 'Raymond' } },
      );

    ok(
        $total_sending_out_num == 3,
        "This file is to send to 3 people ($total_sending_out_num)",
    );
    ok( unlink($path_to_list) == 1, 'Unlinking ' . $path_to_list . ' worked.' );
    undef($path_to_list);
    undef($total_sending_out_num);

    my $r_count =
      $lh->remove_subscriber({ -email => 'raymond.lame@example.com' });
    ok( $r_count == 1, "removed one address (raymond.lame\@example.com)" );
    undef($r_count);




    # This is quite different - we're testing to see if the profile field
    # For the list owner is picked up, if a test message is sent out:

    require DADA::Profile;
    my $dp = DADA::Profile->create(
        {
            -email     => 'test@example.com',
            -activated => 1,
        }
    );
    $dp->{fields}->insert(
        {
            -fields => {
                first_name => 'Test First Name',
                last_name  => 'Test Last Name',
            }
        }
    );

    ( $path_to_list, $total_sending_out_num ) = $lh->create_mass_sending_file(
        -ID        => DADA::App::Guts::message_id(),    #argh. That's messy.
        -Type      => 'list',
        -Bulk_Test => 1,
    );
    my $file_contents = slurp($path_to_list);

    # This means, The profile fields were looked at, when making the mass
    # sending file:
    my $regex = quotemeta('"Test First Name","Test Last Name"');
    like( $file_contents, qr/$regex/,
        "found first and last name in test mass sending file" );
###

    ###

    my $s = $lh->remove_subscriber_field( { -field => 'first_name' } );
    ok( $s == 1, "removing field 'first_name' is successful" );
    undef($s);

    my $s = $lh->remove_subscriber_field( { -field => 'last_name' } );
    ok( $s == 1, "removing field 'last_name' is successful" );
    undef($s);

    sleep(2);

    chmod( 0777, $DADA::Config::TMP . '/mail.txt' );

    ok(
        $lh->remove_subscriber({
            -email => 'mike.kelley@example.com',
            -type       => 'list'
        }),
        "removed: " . 'mike.kelley@example.com'
    );
    ok(
        $lh->remove_subscriber({
            -email => 'raymond.pettibon@example.com',
            -type       => 'list'
        }),
        "removed: " . 'raymond.pettibon@example.com'
    );
    ok(
        $lh->remove_subscriber({
            -email => 'marcel.duchamp@example.com',
            -type       => 'list'
        }),
        "removed: " . 'marcel.duchamp@example.com'
    );
    ok(
        $lh->remove_subscriber({
            -email => 'man.ray@example.com',
            -type       => 'list'
        }),
        "removed: " . 'man.ray@example.com'
    );
    ok(
        $lh->remove_subscriber({
            -email => 'no.one@example.com',
            -type       => 'list'
        }),
        "removed: " . 'no.one@example.com'
    );

}    # Skip?!

### search_list

undef $lh;

$lh = DADA::MailingList::Subscribers->new( { -list => $list } );
ok( $lh->isa('DADA::MailingList::Subscribers'), 'isa checks out.' );

my $n_subs = $lh->num_subscribers;
if ( $n_subs > 0 ) {
    my $ll = $lh->subscription_list;
    require Data::Dumper;
    print Data::Dumper::Dumper($ll);

}

ok( $n_subs == 0, "no subscribers right now ($n_subs)" );

my $i = 0;
for ( $i = 0 ; $i < 10 ; $i++ ) {

    ok(
        $lh->add_subscriber(
            {
                -email => 'example' . $i . '@example.com',
                -type  => 'list',
            }
        ),
        'added: example' . $i . '@example.com'
    );

}
my $now_n_subs = $lh->num_subscribers;
ok( $now_n_subs == 10, "10 subscribers right now ($now_n_subs)" );

undef $i;
my $num_results = 0;
my $results     = 0;

( $num_results, $results ) = $lh->search_list(
    {
        -operator => '=',
        -value    => 'example',
        -type     => 'list',
    }
);

ok( $results->[9],   "Have 10 results (" . scalar(@$results) . ")" );
ok( !$results->[10], "Do NOT have 11 results." );
ok($num_results == 10, "num results = 10 ($num_results)"); 


for (@$results) {
    like( $_->{email}, qr/example/, "Found: " . $_->{email} );
}
$i = 0;
for ( $i = 0 ; $i < 10 ; $i++ ) {
    ok(
        $lh->remove_subscriber({
            -email =>  'example' . $i . '@example.com' ,
            -type       => 'list'
          }) == 1,
        "removed: " . 'example' . $i . '@example.com'
    );
}
undef $i;

SKIP: {

    skip
"Multiple Profile Fields is not supported with this current backend."
      if $lh->can_have_subscriber_fields == 0;

    for (qw(1 2)) {
        ok( $lh->add_subscriber_field( { -field => 'field' . $_ } ),
            'added field, ' . $_ );
    }

    my $subscribers = [];
    $subscribers = [
        [ 'example1@example.com', "Fred", "Jones" ],
        [ 'example2@example.com', "Tom",  "Jones" ],
        [ 'example3@example.com', "Wes",  "Anderson" ]
    ];

    for (@$subscribers) {
        ok(
            $lh->add_subscriber(
                {
                    -email  => $_->[0],
                    -fields => {
                        field1 => $_->[1],
                        field2 => $_->[2],
                    },
                    -type => 'list',
                }
            ),
            'added:  ' . $_->[0]
        );

    }

    undef $num_results;
    undef $results;

    ( $num_results, $results ) = $lh->search_list(
        {
            -operator => '=', 
            -value   => 'example',
            -type    => 'list',
        }
    );

    ok( $results->[2],  "Found 3 results" );
    ok( !$results->[3], "Did not find 4 results" );
	ok($num_results == 3, "num results = 3 ($num_results)"); 

    #diag "sleeping! 30";
    #sleep(30);

    undef $num_results;
    undef $results;

    ( $num_results, $results ) = $lh->search_list(
        {
            -query    => 'Jones',
            -type     => 'list',
        }
    );

    ok( $results->[1],  "Found 2 results" );
    ok( !$results->[2], "Did not find 3 results" );
	ok($num_results == 2, "num results = 2 ($num_results)"); 

    undef $num_results;
    undef $results;

    ( $num_results, $results ) = $lh->search_list(
        {
            -query    => 'Wes',
            -type     => 'list',
        }
    );

    undef $num_results;
    undef $results;

    ( $num_results, $results ) = $lh->search_list(
        {
            -query    => 'Wes',
            -type     => 'list',
        }
    );
    ok( $results->[0],  "Found 1 result" );
    ok( !$results->[1], "Did not find 0 results" );

    # require Data::Dumper;
    # print Data::Dumper::Dumper($results);
    my $r = $results->[0];
    ok( $r->{fields}->[0]->{value} eq 'Wes',      'equals wes' );
    ok( $r->{fields}->[1]->{value} eq 'Anderson', 'equals anderson' );
    undef $r;

    for (@$subscribers) {
        ok(
            $lh->remove_subscriber({
                -email =>  $_->[0] ,
                -type       => 'list'
            }),
            "removed: " . $_->[0]
        );
    }

    for (qw(1 2)) {
        ok( $lh->remove_subscriber_field( { -field => 'field' . $_ } ),
            'Removed: field' . $_ );
    }

}    # SKIP

# dupe check
my $dupe_email = 'imadupe@example.com';
$lh->add_subscriber( { -email => $dupe_email, } );

my $r = undef;

$r = $lh->add_subscriber(
    {
        -email      => $dupe_email,
        -dupe_check => {
            -enable  => 1,
            -on_dupe => 'ignore_add',
        },
    }
);

ok( !defined($r), "dupe check worked! return of undef" );

undef $r;

eval {
    $r = $lh->add_subscriber(
        {
            -email      => $dupe_email,
            -dupe_check => {
                -enable  => 1,
                -on_dupe => 'error',
            },
        }
    );
};
ok( defined($@), "dupe check worked! died!" );
like(
    $@,
    qr/email already subcribed/,
    "and the error message seems comprehensible!"
);

undef $r;

eval {
    $r = $lh->add_subscriber(
        {
            -email      => $dupe_email,
            -dupe_check => {
                -enable  => 1,
                -on_dupe => 'asfdasdfasdfasd',

            },
        }
    );
};
ok( defined($@), "dupe check worked! died!" );
like( $@, qr/unknown option/, "and the error message seems comprehensible!" );

$lh->remove_subscriber({ -email => $dupe_email });

### /search_list

### Does a newline screw up thingies?
my $withanewline_subscriber = 'withanewline@example.com' . "\n";

my ( $status, $details ) = $lh->subscription_check(
    {
        -email => $withanewline_subscriber,
        -Type  => 'list',
    }
);
ok( $status == 0, "Status is 0 ($status)" );

##############################################################################
# subscription_list
my $sub_list = [];
my @num      = ( 1 ... $large_num );
for (@num) {
    $lh->add_subscriber(
        {
            -email => 'mytest' . $_ . '@example.com',
            -type  => 'list',
        }
    );
}

ok( $lh->num_subscribers == $large_num, "subscribed $large_num addresses." );
$sub_list = $lh->subscription_list(
    {
        -start    => 0,
        '-length' => 100,
        -type     => 'list',
    }
);
ok( ( $#$sub_list + 1 ) == 100,
    "100 subscribers were returned! (" . ( $#$sub_list + 1 ) . ")" );
$sub_list = $lh->subscription_list(
    {
        -start    => 100,
        '-length' => 100,
        -type     => 'list',
    }
);
ok( ( scalar(@$sub_list) ) == 0,
    "0 subscribers were returned! (" . ( scalar(@$sub_list) ) . ")" );

# Just to be weird:
$sub_list = $lh->subscription_list(
    {
        -start    => 99,
        '-length' => 55,
        -type     => 'list',
    }
);
ok( ( scalar(@$sub_list) ) == 0,
    "0 subscribers were returned! (" . ( scalar(@$sub_list) ) . ")" );

$sub_list = $lh->subscription_list(
    {

        #-start    => 0,
        #'-length' => $large_num,
        -type => 'list',
    }
);
ok( ( $#$sub_list + 1 ) == $large_num,
    "$large_num subscribers were returned! (" . ( $#$sub_list + 1 ) . ")" );

##############################################################################
# remove_all_subscribers
ok( $lh->remove_all_subscribers == $large_num, "Removed all the subscribers!" );
for("a".."z" ){ 
    $lh->add_subscriber(
        {
            -email =>  $_ . '@example.com',
            -type  => 'list',
        }
    );	
}
$sub_list = $lh->subscription_list(
    {
        -type => 'list',
    }
);
ok( ( $#$sub_list + 1 ) == 26,
    "26 subscribers were returned! (" . ( $#$sub_list + 1 ) . ")" );

$sub_list = $lh->subscription_list(
    {
        -start  => 1,
		-length => 13,
    }
);
ok($sub_list->[0]->{email} eq  'n@example.com');
ok($sub_list->[12]->{email} eq 'z@example.com');

ok( $lh->remove_all_subscribers == 26, "Removed all the subscribers!" );




# clone
for ( 'one@one.com', 'two@two.com', 'three@three.com' ) {
    $lh->add_subscriber(
        {
            -email => $_,
            -type  => 'list',
        }
    );
}

my $tmp_list = '_tmp-blah' . time;
ok( $lh->num_subscribers( { -type => 'list' } ) == 3, "3 subscribers!" );

ok(
    $lh->clone(
        {
            -from => 'list',
            -to   => $tmp_list,
        }
      ) == 1
);

ok( $lh->num_subscribers( { -type => $tmp_list } ) == 3, "3 subscribers (x2)" );

ok( $lh->remove_this_listtype( { -type => $tmp_list } ) == 1,
    "list type removed!" );

##############################################################################
# copy_all_subscribers #
########################
$lh->remove_all_subscribers( { -type => 'list' } );
$lh->remove_all_subscribers( { -type => 'black_list' } );

for ( 'one@one.com', 'two@two.com', 'three@three.com' ) {
    $lh->add_subscriber(
        {
            -email => $_,
            -type  => 'list',
        }
    );
}
$lh->copy_all_subscribers(
    {
        -from => 'list',
        -to   => 'black_list',
    }
);
ok( $lh->num_subscribers( { -type => 'list' } ) == 3, "3 subscribers! (x3)" );
ok( $lh->num_subscribers( { -type => 'black_list' } ) == 3, "3 black listed!" );

# Do it again!
$lh->copy_all_subscribers(
    {
        -from => 'list',
        -to   => 'black_list',
    }
);

# Should be the same thing:
ok( $lh->num_subscribers( { -type => 'list' } ) == 3 );
ok( $lh->num_subscribers( { -type => 'black_list' } ) == 3 );

$lh->remove_all_subscribers( { -type => 'list' } );
$lh->remove_all_subscribers( { -type => 'black_list' } );

# /copy_all_subscribers

#----------------------------------------------------------------------------#
# subsribed_to

for ( 'list', 'black_list', 'white_list' ) {
    $lh->add_subscriber(
        {
            -email => 'test@example.com',
            -type  => $_,
        }
    );

}

my $st = []; 
$st = $lh->member_of({-email => 'test@example.com'}); 
ok(scalar(@$st) == 3, "3 list types returned."); 

for ( 'list', 'black_list', 'white_list' ) {
	ok($lh->remove_all_subscribers( { -type => $_ } ) == 1);
}
# /subsribed_to
#----------------------------------------------------------------------------#

#----------------------------------------------------------------------------#
# domain_stats
for(qw(1 2 3 4 5)){ 
	$lh->add_subscriber(
	    {
	        -email => $_ . '@example.com',
	        -type  => 'list',
	    }
	);
}


for(qw(1 2 3 4)){ 
	$lh->add_subscriber(
	    {
	        -email => $_ . '@gmail.com',
	        -type  => 'list',
	    }
	);
}
	
for(qw(1 2 3)){ 
	$lh->add_subscriber(
	    {
	        -email => $_ . '@hotmail.com',
	        -type  => 'list',
	    }
	);
}

for(qw(1 2)){ 
	$lh->add_subscriber(
	    {
	        -email => $_ . '@yahoo.com',
	        -type  => 'list',
	    }
	);
}

for(qw(1)){ 
	$lh->add_subscriber(
	    {
	        -email => $_ . '@live.com',
	        -type  => 'list',
	    }
	);
}
my $stats= $lh->domain_stats({-count => 3}); 

#use Data::Dumper; 
#diag Dumper($stats); 
# $VAR1 = [
#           {
#             'domain' => 'example.com',
#             'number' => 5
#           },
#           {
#             'domain' => 'gmail.com',
#             'number' => 4
#           },
#           {
#             'domain' => 'other',
#             'number' => 6
#           }
#         ];

ok($stats->[0]->{domain} eq 'example.com');
ok($stats->[0]->{number} == 5);

ok($stats->[1]->{domain} eq 'gmail.com');
ok($stats->[1]->{number} == 4);

ok($stats->[2]->{domain} eq 'other');
ok($stats->[2]->{number} == 6);

ok($lh->remove_all_subscribers( { -type => 'list' } ) == 15);

# domain_stats
#----------------------------------------------------------------------------#



# Subscription Quotas
#
# Let's add 1,000 to start: 
for(1..1_000) { 
	$lh->add_subscriber(
	    {
	        -email  => $_ . 'sub_quota@example.com',
	        -type   => 'list',
	    }
	);
}

# Set a global quota: 
$DADA::Config::SUBSCRIPTION_QUOTA = 1000; 

my ( $status, $details ) = $lh->subscription_check(
    {
        -email => 'yetonemoresubscriber@example.com',
        -Type  => 'list',
    }
);
ok( $status == 0, "Status is 0 ($status)" );
ok( $details->{over_subscription_quota} == 1, "over_subscription_quota"); 



# Disable the quota. Still works? 
$DADA::Config::SUBSCRIPTION_QUOTA = undef;  
my ( $status, $details ) = $lh->subscription_check(
    {
        -email => 'yetonemoresubscriber@example.com',
        -Type  => 'list',
    }
);
ok( $status == 1, "Status is 1 ($status)" );


# List-specific quota: 
$ls->save(
	{ 
		use_subscription_quota => 1, 
		subscription_quota     => 1000, 
	}	
); 
my ( $status, $details ) = $lh->subscription_check(
    {
        -email => 'yetonemoresubscriber@example.com',
        -Type  => 'list',
    }
);
ok( $status == 0, "Status is 0 ($status)" );
ok( $details->{over_subscription_quota} == 1, "over_subscription_quota"); 

# List-specific quota, bigger than Global Quota - global quota should be used:  
$DADA::Config::SUBSCRIPTION_QUOTA = 1000; 
$ls->save(
	{ 
		use_subscription_quota => 1, 
		subscription_quota     => 50000, 
	}	
); 
my ( $status, $details ) = $lh->subscription_check(
    {
        -email => 'yetonemoresubscriber@example.com',
        -Type  => 'list',
    }
);
ok( $status == 0, "Status is 0 ($status)" );
ok( $details->{over_subscription_quota} == 1, "over_subscription_quota"); 

#undef($subscribed, $not_subscribed, $black_listed, $not_white_listed, $invalid); 
my $f_emails
	= $lh->filter_subscribers_w_meta(
		{
			-emails => [{-email => 'yetonemoresubscriber@example.com'}],
			-type   => 'list',
		}
	);
#ok($invalid->[0] eq 'yetonemoresubscriber@example.com'); 	

ok($lh->remove_all_subscribers( { -type => 'list' } ) == 1000);



SKIP: {

    skip
"Multiple Profile Fields is not supported with this current backend."
      if $lh->can_have_subscriber_fields == 0;
      
      
      my $shh = $lh->add_subscriber_field( 
          { 
              -field    => '_new_field', 
              -label    => "sssssssh!!!!",
              -required => 1,
          } 
        );
        ok( $shh == 1, "adding a new field is successful" );
        
        undef $lh; 
        my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
        
        my $good_address = 'ssh.user@example.com'; 
        # no -mode
        ( $status, $details ) =  $lh->subscription_check( { -email => $good_address, } );
        ok( $status == 1,                  "Status is 1" );
        ok( $details->{invalid_email} != 1, "Address seen as valid" );
        
        # explicit -mode, 'user'
        ( $status, $details ) =  $lh->subscription_check( { -email => $good_address, -mode => 'user'} );
        ok( $status == 1,                  "Status is 1" );
        ok( $details->{invalid_email} != 1, "Address seen as valid" );

        # explicit -mode, 'admin'
        ( $status, $details ) =  $lh->subscription_check( { -email => $good_address, -mode => 'admin'} );
        
        #use Data::Dumper; 
        #diag Dumper([$status, $details]); 
        ok( $status == 0,                  "Status is 0" );
        ok( $details->{invalid_profile_fields}->{_new_field}->{required} == 1, "Didn't pass validation!" );
        undef($good_address); 
      
      
}; 

dada_test_config::remove_test_list;
dada_test_config::wipe_out;

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

