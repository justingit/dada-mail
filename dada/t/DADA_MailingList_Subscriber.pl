#!/usr/bin/perl 

my $large_num = 1000; 

use lib
  qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib );
BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }
use DADA::Config; 

use dada_test_config;
my $list = dada_test_config::create_test_list(
    { -remove_existing_list => 1, -remove_subscriber_fields => 1 } );


require DADA::MailingList::Subscriber; 

eval { my $dms = DADA::MailingList::Subscriber->new(); };
ok($@, "You MUST supply an email address in the -email parameter!" );
undef($@); 

eval { my $dms = DADA::MailingList::Subscriber->new({-list => $list, -type => 'list', -email => 'blah'}); }; 
ok($@, "email, 'blah' passed in, -email is not valid, type: list"); 
undef($@);

my $valid_email = 'user@example.com'; 

##############################################################################
#
# Checking to see if a Profile is created, without sending a Profile Password
# (it shouldn't)

my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email => $valid_email,  
        -list  => $list, 
        -type  => 'list', 
   } 
);
require DADA::Profile; 
my $prof = DADA::Profile->new({-email => $valid_email});
ok(!$prof->exists, "No Profile Exists - we didn't pass a Profile Password.");
$dms->remove(); 
undef($dms);


##############################################################################
# Now, we're going to add a subscriber, as well as pass a Profile Password, 
# the Profile should be created. 
my $password = 'test'; 
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -profile => {
            -password => $password, 
        }
   } 
);
require DADA::Profile; 
my $prof = DADA::Profile->new({-email => $valid_email});
ok($prof->exists, "Profile Exists - we passed a Profile Password.");
ok($prof->is_valid_password({-password => $password}), "Password passed to create new Profile works,!"); 
ok(!$prof->is_valid_password({-password => scalar(reverse($password))}), "Password passed to create new Profile works,!"); 
$dms->remove(); 
undef($dms); 
undef($prof); 

# Profile exists after the subscriber is removed: 
my $prof = DADA::Profile->new({-email => $valid_email});
ok($prof->exists, "Profile Exists");

##############################################################################
#
# We're going to make a new subscriber, with a password, but the password won't be used, because a profile already exists: 
my $new_password = 'differentpass'; 
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -profile => {
            -password => $new_password, 
        }
   } 
);
my $prof = DADA::Profile->new({-email => $valid_email});
ok($prof->exists, "Profile Exists - we passed a Profile Password.");
ok(! $prof->is_valid_password({-password => $new_password}), "New Password does not work"); 
ok(  $prof->is_valid_password({-password => $password}), "But old password works fine"); 
$dms->remove(); 
undef($dms); 
undef($prof); 
undef($new_password); 




##############################################################################
# Let's see if preserve_if_defined works: 
my $new_password = 'differentpass'; 
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -profile => {
            -password => $new_password, 
            -mode     => 'preserve_if_defined', 
        }
   } 
);
my $prof = DADA::Profile->new({-email => $valid_email});
ok($prof->exists, "Profile Exists - we passed a Profile Password.");
ok(! $prof->is_valid_password({-password => $new_password}), "New Password does not work"); 
ok(  $prof->is_valid_password({-password => $password}), "But old password does."); 
$dms->remove(); 
undef($dms); 
undef($prof); 
undef($new_password); 







##############################################################################
# This time, we'll force the recreation of the password: 
my $new_password = 'differentpass'; 
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -profile => {
            -password => $new_password, 
            -mode     => 'writeover', 
        }
   } 
);
my $prof = DADA::Profile->new({-email => $valid_email});
ok($prof->exists, "Profile Exists - we passed a Profile Password.");
ok( $prof->is_valid_password({-password => $new_password}), "New Password works"); 
ok(!  $prof->is_valid_password({-password => $password}), "But old password does not."); 
$dms->remove(); 
undef($dms); 
undef($prof); 
undef($new_password);




##############################################################################
# Profile Fields! 
require   DADA::ProfileFieldsManager; 
my $pfm = DADA::ProfileFieldsManager->new;
   $pfm->add_field(
	{
		-field          => 'myfield', 
		-fallback_value => 'a default', 
		-label          => 'My Field!', 
	}
); 



my $field_value = 'Value!'; 
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -fields  => { 
            myfield => $field_value, 
        },
        -fields_options => {
            -mode => 'preserve_if_defined',
        }
   } 
);
my $sf = $dms->get(); 
ok($sf->{myfield} eq $field_value, 'field value set!'); 
$dms->remove(); 
undef($dms); 
undef($field_value);




##############################################################################
# We'll subscribe the address again, and see if setting new profile fields 
# works

my $field_value = 'New Value!'; # different than before!
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -fields  => { 
            myfield => $field_value, 
        },
        -fields_options => {
            -mode => 'preserve_if_defined',
        }
   } 
);
my $sf = $dms->get(); 
ok($sf->{myfield} ne $field_value, 'new field value not set!'); 
$dms->remove(); 
undef($dms); 
undef($field_value);




##############################################################################
# We'll subscribe the address again, and see if setting new profile fields 
# works (we'll force it, this time) 

my $field_value = 'Another New Value!'; # different than before!
my $dms = DADA::MailingList::Subscriber->add(
   { 
        -email   => $valid_email,  
        -list    => $list, 
        -type    => 'list', 
        -fields  => { 
            myfield => $field_value, 
        },
        -fields_options => {
            -mode => 'writeover',
        }
   } 
);
my $sf = $dms->get(); 
ok($sf->{myfield} eq $field_value, 'new field #2 value set!'); 
$dms->remove(); 
undef($dms); 
undef($field_value);




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

