#!/usr/bin/perl
use strict;

# This doesn't work, if we're eval()ing it.
# use Test::More qw(no_plan);

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib

  /Users/justin/Documents/DadaMail/build/bundle/perllib
);

BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }
use dada_test_config;

require DADA::App::Guts;
require DADA::MailingList;
require DADA::MailingList::Settings;

my $list        = 'dadatest';
my $list_params = {

    list             => $list,
    list_name        => 'Justin!' . $dada_test_config::UTF8_STR,
    list_owner_email => 'user@example.com',
    password         => 'abcd',
    retype_password  => 'abcd',
    info             => 'info' . $dada_test_config::UTF8_STR,
    privacy_policy   => 'privacy_policy' . $dada_test_config::UTF8_STR,
    physical_address => 'physical_address' . $dada_test_config::UTF8_STR,

};

my ( $list_errors, $flags ) =
  DADA::App::Guts::check_list_setup( -fields => $list_params );
ok( $list_errors == 0 );

my $test_list_params = $list_params;
delete( $test_list_params->{retype_password} );

# ok ok ok! We'll actually make the list...
my $ls = DADA::MailingList::Create(
    {
        -list     => $test_list_params->{list},
        -settings => $test_list_params,
    	-test     => 0, 
	}
);

#my $ls = DADA::MailingList::Settings->new({-list => $list});

my $li = $ls->get;

use Data::Dumper; 
use Encode;
diag 'LIST NAME! ' . Encode::encode('UTF-8',$li->{list_name}); 

for ( keys %$list_params ) {
    ok( ( $li->{$_} eq $list_params->{$_} ), $_ );
}

# These have been problematic variables...
ok( length( $li->{cipher_key} ) >= 1, "we have a cipher key!" );
my $orig_cipher_key = $li->{cipher_key};
ok( length( $li->{admin_menu} ) >= 1, "we have an admin menu" );
my $orig_admin_menu = $li->{admin_menu};

# Gotta do this, since the backup names are based on time - gah, should fix that soon;
#sleep(5);
# do a bs save...
$ls->save( { list_name => "New List Name" } );

undef $li;

$li = $ls->get;

ok( $li->{list_name} eq 'New List Name', "New List Name was saved." );
ok(
    $orig_cipher_key eq $li->{cipher_key},
    "Cipher Key didn't change for any odd reason."
);


# This is to just make sure passwords are encrypted and decrypted correctly, 

my @pass_settings = qw(
sasl_smtp_password
pop3_password
discussion_pop_password
); 

for(@pass_settings) { 
	$ls->save({$_ => 'test'}); 
}
for(@pass_settings) { 
	ok(
		$ls->param($_) eq 'test',
		$_ . ' (test) was saved and retrieved correctly!'
	); 
}





# This test is sort of dumb, but whatever...
ok(
    $orig_admin_menu eq $li->{admin_menu},
    "Admin Menu didn't change for any odd reason."
);

eval { $ls->save( { bad => "bad" } ); };
ok( defined($@), "Error when attempting to save a non-existent setting: $@" );

# This tests to make sure various passwords, that are encrypted can be set by default, unencrypted:

require DADA::Security::Password;
my @password_settings = qw(
  sasl_smtp_password
  pop3_password
  discussion_pop_password
);

my $lsd_pass = 'sneaky';

for my $setting (@password_settings) {

    
    # for now, we'll just make sure that's clear out:
    $ls->save( { $setting => undef } );
    
    $DADA::Config::LIST_SETUP_DEFAULTS{$setting} = $lsd_pass;

    ok( $DADA::Config::LIST_SETUP_DEFAULTS{$setting} eq $lsd_pass, 'setting: ' . $setting . ' = ' . $lsd_pass);

    # and then, see if it gets returned, automatically:

    $li = $ls->get;
        
    ok(
        (
            DADA::Security::Password::cipher_decrypt(
                $li->{cipher_key}, $li->{$setting}
            )
        ) eq $lsd_pass,

        "Password: $lsd_pass is saved correctly ("
          . DADA::Security::Password::cipher_decrypt( $li->{cipher_key},
            $li->{$setting} )
          . ") from the list setup defaults!"
    );

}

for my $setting (@password_settings) {

    $DADA::Config::LIST_SETUP_DEFAULTS{$setting} = $lsd_pass;

    my $tmp_list_params = $list_params;
    $tmp_list_params->{list} = $lsd_pass;
    my $local_ls = DADA::MailingList::Create(
        {
            -list     => $tmp_list_params->{list},
            -settings => $tmp_list_params,
			-test     => 0, 
        }
    );
    ok( $local_ls->isa('DADA::MailingList::Settings') );

    my $local_li = $local_ls->get;

    ok(

        (
            DADA::Security::Password::cipher_decrypt(
                $local_li->{cipher_key},
                $local_li->{$setting}
            )
        ) eq $lsd_pass,

        "Password: $lsd_pass is saved correctly ("
          . DADA::Security::Password::cipher_decrypt( $local_li->{cipher_key},
            $local_li->{$setting} )
          . ") from the list setup defaults!"
    );

    ok( DADA::MailingList::Remove( { -name => $tmp_list_params->{list} } ) ==
          1 );

    ok( delete( $DADA::Config::LIST_SETUP_DEFAULTS{$setting} ) );

}

# This is another %LIST_SETUP_DEFAULT check - the admin_email:

my $admin_email = 'admin@example.com';

my $tmp_list_params = $list_params;
$tmp_list_params->{list} = 'adminemail';

$DADA::Config::LIST_SETUP_DEFAULTS{admin_email} = $admin_email;

my $ae_ls = DADA::MailingList::Create(
    {
        -list     => $tmp_list_params->{list},
        -settings => $tmp_list_params,
    	-test     => 0, 
}
);

ok( $ae_ls->isa('DADA::MailingList::Settings') );
my $ae_li = $ae_ls->get;

ok( $ae_li->{admin_email} eq $admin_email,
    "admin email set in the List Setup Defaults was saved correctly." );

ok(
    $ae_ls->param('admin_email') eq $admin_email,
"admin email set in the List Setup Defaults was saved correctly. (via param, too!)"
);

####### param method..

ok( $ls->param('list') eq 'dadatest',
    "param('list') returned the correct thing" );

# This will throw an error:
eval { $ls->param( 'bad', 'bad' ); };
ok( defined($@),
    "Error when attempting to save (via param) a non-existent setting: $@" );
like(
    $@,
    qr/Cannot call param\(\) on unknown setting\,/,
    "and the error message seems to make sense"
);

# But this should work:
ok( $ls->param( 'list_name', 'Brand New List Name' ) eq 'Brand New List Name' );
ok( $ls->param('list_name') eq 'Brand New List Name' );

# And if I go like this:
$li = $ls->get;
ok( $li->{list_name} eq 'Brand New List Name' );

require CGI; 
my $q = CGI->new; 
$ls->save_w_params(
	{
	-associate => $q, 
	-settings  => { 
		list_name => 'fallback',
	}
}
);
ok($ls->param('list_name') eq 'fallback'); 

$q->param('list_name', 'list name from param'); 
$ls->save_w_params(
	{
	-associate => $q, 
	-settings  => { 
		list_name => 'fallback',
	}
}
);
ok($ls->param('list_name') eq 'list name from param'); 



foreach my $html_setting(keys %{$ls->_html_settings}){ 
    $li = $ls->get(-all_settings => 0);
    ok(! defined($li->{$html_setting}), $html_setting . ' is not defined - that\'s OK');
    #diag $li->{$html_setting}; 
}
foreach my $html_setting(keys %{$ls->_html_settings}){ 
    $li = $ls->get(-all_settings => 1);
    ok(defined($li->{$html_setting}), $html_setting . ' is defined - weve explicitly asked for it');
}
undef($ls); 
my $ls = DADA::MailingList::Settings->new({-list => $list});
foreach my $html_setting(keys %{$ls->_html_settings}){ 
    ok(defined($ls->param($html_setting)), $html_setting . ' is defined');  
}



undef($ls); 
my $ls = DADA::MailingList::Settings->new({-list => $list});
foreach my $html_setting(keys %{$ls->_email_message_settings}){ 
    $li = $ls->get(-all_settings => 0);
    ok(! defined($li->{$html_setting}), $html_setting . ' is not defined - that\'s OK');
    #diag $li->{$html_setting}; 
}
foreach my $html_setting(keys %{$ls->_email_message_settings}){ 
    $li = $ls->get(-all_settings => 1);
    ok(defined($li->{$html_setting}), $html_setting . ' is defined - weve explicitly asked for it');
}
undef($ls); 
my $ls = DADA::MailingList::Settings->new({-list => $list});
foreach my $html_setting(keys %{$ls->_email_message_settings}){ 
    ok(defined($ls->param($html_setting)), $html_setting . ' is defined');  
}





















my $Remove = DADA::MailingList::Remove( { -name => $list } );
ok( $Remove == 1, "Remove returned a status of, '1'" );

dada_test_config::wipe_out;
