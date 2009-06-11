#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

diag('$DADA::Config::SUBSCRIBER_DB_TYPE ' . $DADA::Config::SUBSCRIBER_DB_TYPE); 



use strict;
use Carp; 


my $list = dada_test_config::create_test_list({-remove_existing_list => 1, -remove_subscriber_fields => 1});

use DADA::Profile::Fields; 

#
my $pf = undef; 



###############################################################################
# new

$pf = DADA::Profile::Fields->new; 
ok($pf->isa('DADA::Profile::Fields'), "isa DADA::Profile::Fields"); 

undef $pf; 

###############################################################################
# fields
my $fields = undef; 

$pf = DADA::Profile::Fields->new; 
$fields = $pf->fields; 
ok($#$fields == -1, "No fields, present (" . $#$fields .")"); 

$pf->add_field(
	{
		-field => 'one', 
	}
); 
$fields = $pf->fields; 
ok($#$fields == 0, "1 field present (" . $#$fields .")"); 
ok($fields->[0] eq 'one', "Field is called, 'one'"); 

$pf->add_field(
	{
		-field => 'two', 
	}
);
$fields = $pf->fields; 
ok($#$fields == 1, "2 fields present (" . $#$fields .")"); 
ok($fields->[1] eq 'two', "Field is called, 'two'");

$pf->remove_field({-field => 'one'}); 
$fields = $pf->fields;
ok($#$fields == 0, "1 field present (" . $#$fields .")"); 

undef $fields; 
$pf->remove_field({-field => 'two'});
$fields = $pf->fields;
ok($#$fields == -1, "0 field present (" . $#$fields .")"); 


undef $pf;
undef $fields; 


###############################################################################
# insert


$pf = DADA::Profile::Fields->new; 
# C<insert> inserts a new record into the profile table. This method requires a few paramaters: 

#C<-email> is required and should hold a valid email address in the form of: C<user@example.com>

eval { $pf->insert(); };
ok($@, "calling insert without any paramaters causes an error!: $@");

# This method should return, C<1> on success.  
ok($pf->insert({-email => 'user@example.com'}) == 1, "returning 1 on success"); 
# verify
ok($pf->exists({-email => 'user@example.com'}) == 1, "exists."); 
# remove and clean up.
ok($pf->remove({-email => 'user@example.com'}) == 1, "removed."); 

# C<-fields> holds the profile fields passed as a hashref. It is an optional paramater. 
$pf->add_field({-field => 'one'}); 
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'value', 
		}
	}
);
my $prof = $pf->get({-email  => 'user@example.com'}); 
ok($prof->{one} eq 'value', "field value passed and saved. ($prof->{one})");
undef $prof; 

# C<-mode> sets the way the new profile will be created and can either be set to, C<writeover> or, C<preserve>
# When set to, C<writeover>, any existing profile belonging to the email passed in the <-email> paramater will be clobbered. 
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'a new value', 
		},
		-mode => 'writeover', 
	}
);
$prof = $pf->get({-email  => 'user@example.com'}); 
ok($prof->{one} eq 'a new value', "field value passed and saved. ($prof->{one})");

# When set to, C<preserve>, this method will first look and see if an already existing profile exists and if so, will not create a new one, but simply exit the method and return, 1
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'another value, that will not be saved.', 
		},
		-mode => 'preserve', 
	}
);
$prof = $pf->get({-email  => 'user@example.com'}); 
ok($prof->{one} eq 'a new value', "new field value not saved. ($prof->{one})");






 
dada_test_config::remove_test_list;
dada_test_config::wipe_out;


sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, "<$file") || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}



