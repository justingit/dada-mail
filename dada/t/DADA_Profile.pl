#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

diag('$DADA::Config::SUBSCRIBER_DB_TYPE ' . $DADA::Config::SUBSCRIBER_DB_TYPE); 



use strict;
use Carp; 


my $list = dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1});

use DADA::Profile; 

#
my $p = undef; 

###############################################################################
# new

eval { $p = DADA::Profile->new; }; 
ok($@, "Calling new without an -email param creates an error! ($@)"); 

#eval { $p = DADA::Profile->new({-from_session => 1}); }; 
#ok($@, "Calling new with, -from_session param (without a session) creates an error! ($@)"); 


eval { $p = DADA::Profile->new({-email => 'user@example.com'}); };

ok($p->isa('DADA::Profile'), 'object is a DADA::Profile');

# These two lines will error out - insert() needs to be rethought.  
# $p->insert(); 
# $p->insert(); 

undef $p; 


###############################################################################
# exists 

my $p = DADA::Profile->new({-email => 'user@example.com'}); 
ok($p->exists == 0, "The profile does not exist(1)."); 
ok(DADA::Profile->new({-email => 'user@example.com'})->exists == 0, "The profile does not exist(2).");
undef $p; 

my $p = DADA::Profile->create(
	{
		-email => 'user@example.com', 
	}
); 
undef $p; 

ok(DADA::Profile->new({-email => 'user@example.com'})->exists == 1, "Profile now exists(2).");

my $p = DADA::Profile->new(
	{
		-email => 'user@example.com'
	}
); 
ok($p->exists == 1, "Profile now exists(1)."); 
$p->remove; 
ok($p->exists == 0, "Profile does not exist, anymore."); 

my ( $status, $errors ) = $p->is_valid_update_profile_activation;
require Data::Dumper; 
diag $status; 
diag Data::Dumper::Dumper($errors); 



dada_test_config::remove_test_list;
dada_test_config::wipe_out;


sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}



