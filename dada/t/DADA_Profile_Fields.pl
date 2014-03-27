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
my $pf  = undef; 



###############################################################################
# new

$pf = DADA::Profile::Fields->new; 
ok($pf->isa('DADA::Profile::Fields'), "isa DADA::Profile::Fields"); 

undef $pf; 

###############################################################################
# fields
my $fields = undef; 

$pf = DADA::Profile::Fields->new; 
$fields = $pf->{manager}->fields; 
ok($#$fields == -1, "No fields, present (" . $#$fields .")"); 

$pf->{manager}->add_field(
	{
		-field => 'one', 
	}
); 
$fields = $pf->{manager}->fields; 
ok($#$fields == 0, "1 field present (" . $#$fields .")"); 
ok($fields->[0] eq 'one', "Field is called, 'one'"); 

$pf->{manager}->add_field(
	{
		-field => 'two', 
	}
);
$fields = $pf->{manager}->fields; 
ok($#$fields == 1, "2 fields present (" . $#$fields .")"); 
ok($fields->[1] eq 'two', "Field is called, 'two'");

$pf->{manager}->remove_field({-field => 'one'}); 
$fields = $pf->{manager}->fields;
ok($#$fields == 0, "1 field present (" . $#$fields .")"); 

undef $fields; 
$pf->{manager}->remove_field({-field => 'two'});
$fields = $pf->{manager}->fields;
ok($#$fields == -1, "0 field present (" . $#$fields .")"); 


undef $pf;
undef $fields; 


###############################################################################
# insert


$pf = DADA::Profile::Fields->new; 
# C<insert> inserts a new record into the profile table. This method requires a few parameters: 

#C<-email> is required and should hold a valid email address in the form of: C<user@example.com>

eval { $pf->insert(); };
ok($@, "calling insert without any parameters causes an error!: $@");


# This method should return, C<1> on success.  
ok($pf->insert({-email => 'user@example.com'}) == 1, "returning 1 on success"); 
# verify
ok($pf->exists({-email => 'user@example.com'}) == 1, "exists."); 
# remove and clean up.
ok($pf->remove == 1, "removed."); 

# C<-fields> holds the Profile Fields passed as a hashref. It is an optional parameter. 
$pf->{manager}->add_field({-field => 'one'}); 
undef $pf; 

$pf = DADA::Profile::Fields->new; 
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'value', 
		}
	}
);
my $prof = $pf->get; 
ok($prof->{one} eq 'value', "field value passed and saved. ($prof->{one})");
undef $prof; 
undef $pf; 

# C<-mode> sets the way the new profile will be created and can either be set to, C<writeover> or, C<preserve>
# When set to, C<writeover>, any existing profile belonging to the email passed in the <-email> parameter will be clobbered. 
$pf = DADA::Profile::Fields->new; 
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'a new value', 
		},
		-mode => 'writeover', 
	}
);
$prof = $pf->get; 
ok($prof->{one} eq 'a new value', "field value passed and saved. ($prof->{one})");
undef $pf; 


# When set to, C<preserve>, this method will first look and see if an already existing profile exists and if so, will not create a new one, but simply exit the method and return, 1
$pf = DADA::Profile::Fields->new; 
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'another value, that will not be saved.', 
		},
		-mode => 'preserve', 
	}
);
diag 'fpppm!' . $pf->{email};
$prof = $pf->get; 
ok($prof->{one} eq 'a new value', "new field value not saved. ($prof->{one})");

# verify
ok($pf->exists({-email => 'user@example.com'}) == 1, "exists."); 
# remove and clean up.
ok($pf->remove == 1, "removed.");
$pf->{manager}->remove_field({-field => 'one'}); 

undef $prof; 
undef $pf; 


# C<-confirmed> confirmed can also be passed with a value of either C<1> or, 
# C<0>, with C<1> being the default if the parameter is not passed. 
#
# Unconfirmed profiles are marked as existing, but not, "live" as a way to save 
# the profile information, until the profile can be confirmed, by a user. 

# (this is sort of a strange idea!) - there's no programmable way to, "confirm"
# an unconfirmed email...!
$pf = DADA::Profile::Fields->new; 
$pf->insert(
	{
		-email     => 'user@example.com',
		-confirmed => 0, 
	}
);
ok($pf->exists({-email => '*' . 'user@example.com'}) == 1, "unconfirmed profile exists.");
ok($pf->remove == 1, "removed.");
undef $pf; 

###############################################################################
# get

$pf = DADA::Profile::Fields->new; 
$pf->{manager}->add_field({-field => 'one'}); 
$pf->insert(
	{
		-email  => 'user@example.com',
		-fields => { 
			'one' => 'value', 
		}
	}
);

# C<get> returns the Profile Fields for the email address passed in, C<-email> as a hashref. 

$prof = $pf->get; 
ok($prof->{one} eq 'value', "field value passed and saved. ($prof->{one})");
undef $prof; 

#  C<-dotted> is an optional paramter, and will return the keys of the hashref appended with, C<subscriber.>
$prof = $pf->get(
	{
		-dotted => 1, 
	}
); 

ok(exists($prof->{'subscriber.one'}), 'keys are, "dotted"'); 
ok($prof->{'subscriber.one'} eq 'value', "and has the right value");


$pf->{manager}->remove_field({-field => 'one'}); 
ok($pf->remove == 1, "removed.");

undef $prof; 
undef $pf; 

###############################################################################
# exists
$pf = DADA::Profile::Fields->new; 
ok($pf->exists({-email => 'nothere@example.com'}) == 0, "profile does not exist.");
undef $pf; 


$pf = DADA::Profile::Fields->new; 
$pf->insert(
	{
		-email  => 'user@example.com',
		
	}
);
ok($pf->exists({-email => 'user@example.com'}) == 1, "profile exists.");
ok($pf->remove == 1, "removed.");
undef $pf; 

###############################################################################
# remove


# C<remove> removes the Profile Fields assocaited with the email address passed in the 
# C<-email> parameter.
$pf = DADA::Profile::Fields->new; 
$pf->insert(
	{
		-email  => 'user@example.com',
	}
);
ok($pf->remove == 1, "removed the profile."); 


# C<-email> is a required parameter. Not passing it will cause this method to return, C<undef>. 
#
# Passing an email that doesn't have a profile saved will also return, C<undef>. Check before by using, C<exists()>

# ok($pf->remove eq undef, "passing no email returns undef."); 
#ok($pf->exists({-email  => 'nosuchuser@example.com'}) == 0, "exists is returning 0"); 
#ok($pf->remove({-email  => 'nosuchuser@example.com'}) eq undef, "passing an email with no Profile Fields returns undef"); 

###############################################################################
# add_field

#C<add_field()> adds a field to the profile_fields table. 

 $pf->{manager}->add_field(
	{
		-field          => 'myfield', 
		-fallback_value => 'a default', 
		-label          => 'My Field!', 
	}
 ); 


#Not passing a name for your field in the C<-field> parameter will cause the an unrecoverable error.

eval { $pf->{manager}->add_field; }; 
ok(defined($@), "eval trapped an error"); 


# C<-fallback_value> is an optional parameter, it's a more free form value, used when the profile does not have a value for this profile field. This is usually used in templating
#
# C<-label> is an optional parameter and is used in forms that capture Profile Fields information as a, "friendlier" version of the field name. 

ok($pf->{manager}->_field_attributes_exist({-field => 'myfield'}) == 1, "Field Attr. exists.");
my $f_des = $pf->{manager}->get_all_field_attributes;
ok($f_des->{myfield}->{fallback_value} eq 'a default', "Default was saved.");
ok($f_des->{myfield}->{label} eq 'My Field!', "label was saved.");
ok($pf->{manager}->remove_field({-field => 'myfield'}) == 1, "Profile Removed."); 

#This method will return C<undef> if there's a problem with the parameters passed. See also the, C<validate_subscriber_field_name()> method. 

ok($pf->{manager}->add_field({-field => "Spaces in the name"}) eq undef, "undef returned with incorrect -field name"); 
undef $f_des; 



###############################################################################
# save_field_attributes

# Skipping... 


###############################################################################
# _field_attributes_exist

# Skipping... 

###############################################################################
# edit_subscriber_field_name



SKIP: {

    skip "edit_subscriber_field_name note supported for SQLite" 
        if $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite'; 

	#C<edit_subscriber_field_name()> is used to rename a subscriber field. Usually, this means that a column is renamed in table. 
	#Various SQL backends do this differently and this method should provide the necessary magic. 

	$pf->{manager}->add_field(
		{
			-field          => 'myfield', 
		}
	); 
	ok($pf->{manager}->field_exists({-field => 'myfield' }) == 1, "Initial field exists."); 
	ok($pf->{manager}->field_exists({-field => 'renamedfield' }) == 0, "Renamed field doesn't exist."); 

	ok( 
	$pf->{manager}->edit_field_name(
		{ 
			-old_name => 'myfield', 
			-new_name => 'renamedfield', 
		}
	) == 1, "edit_field_name returned, '1'"); 

	ok($pf->{manager}->field_exists({-field => 'renamedfield' }) == 1, "Renamed field exists."); 
	ok($pf->{manager}->field_exists({-field => 'myfield' }) == 0, "original field doesn't exist.");


	#C<-old_name> and C<-new_name> are required parameters and the method will croak if you do not 
	#pass both. 

	eval{$pf->{manager}->edit_subscriber_field_name;};
	ok(defined($@), "unrecoverable error returned(1)"); 
	eval{$pf->{manager}->edit_subscriber_field_name({-old_name => 'myfield',-new_name => 'renamedfield'});};
	ok(defined($@), "unrecoverable error returned(2)"); 

	#This method will also croak if either the C<-old_name> does not exist, or the C<-new_name> exists. 

	ok($pf->{manager}->remove_field({-field => 'renamedfield'}) == 1, "field removed."); 

}

###############################################################################
# remove_field

# C<remove_field> will remove the profile field passed in, C<-field>. 
#
# C<-field> must exist, or the method will croak.

 ok($pf->{manager}->add_field({-field => 'myfield'}) == 1, "Created new field.");
 ok($pf->{manager}->remove_field({-field => 'myfield'}) == 1, "Field removed.");
 ok($pf->{manager}->field_exists({-field => 'myfield'}) == 0, "Field does not exist.");
 eval{$pf->{manager}->remove_field;};
 ok($@, "eval trapped an error from calling remove_field incorrectly. ( $@ )"); 


###############################################################################
# get_all_field_attributes


###############################################################################
# field_exists

###############################################################################
# validate_subscriber_field_name

###############################################################################
# validate_remove_field_name




###############################################################################
# change_field_order

SKIP: {
	
	#C<change_field_order> is used to change the ordering of the Profile Fields. Profile Fields
	#are usually in the order as they are stored in the SQL table and this method actually changes that 
	#order itself. 

	
	
	#This method is not available for the SQLite or PostgreSQL backend. 
    skip "edit_subscriber_field_name note supported for SQLite or PostgreSQL" 
        if $DADA::Config::SQL_PARAMS{dbtype} =~ m/SQLite|Pg/;
		
	ok($pf->{manager}->add_field({-field => 'one'}) == 1, "Created new field, one.");
	ok($pf->{manager}->add_field({-field => 'two'}) == 1, "Created new field, two.");
	ok($pf->{manager}->add_field({-field => 'three'}) == 1, "Created new field, three.");

    #	This method will also croak if you pass a field that does not exist, or if you pass no field at all.
	
	eval {$pf->{manager}->change_field_order();};
	ok($@, "caught error: $@"); 

	eval {$pf->{manager}->change_field_order({-field => "doesnotexist"});};
	ok($@, "caught error: $@"); 


	#	C<-field> should hold the name of the field you'd like to move. 
    #
	#	C<-direction> should be either C<up> or, <down> to denote which direction you'd like the field to be 
	#	moved. Movements are not circular - if you attempt to push a field down and the field is already the last field, it'll stay 
	#	the last field and won't pop to the top of the stack. 
    #
    #		This method should return, C<1>, but if a field cannot be moved, it will return, C<0> 

	ok(
	$pf->{manager}->change_field_order(
			{ 
				-field     => 'one', 
				-direction => 'down', 
			}
		) == 1, 
		"change_field_order() returned, 1"
	); 

	$fields = $pf->{manager}->fields; 

	ok($fields->[0] eq 'two', 'first field is two, (' . $fields->[0] . ')');
	ok($fields->[1] eq 'one', 'second field is one, (' . $fields->[1] . ')'); 
	ok($fields->[2] eq 'three', 'third field is three, (' . $fields->[2] . ')');


	ok(
		$pf->{manager}->change_field_order(
			{ 
				-field     => 'three', 
				-direction => 'up', 
			}
		) == 1, 
		"change_field_order() returned, 1"
	);
	
	$fields = $pf->{manager}->fields; 
	
	ok($fields->[0] eq 'two', 'first field is two, (' . $fields->[0] . ')');
	ok($fields->[1] eq 'three', 'second field is three, (' . $fields->[1] . ')'); 
	ok($fields->[2] eq 'one', 'third field is one, (' . $fields->[2] . ')');
	

	

	ok(
		$pf->{manager}->change_field_order(
			{ 
				-field     => 'one', 
				-direction => 'down', 
			}
		) == 0, 
		"change_field_order() returned, 0"
	);
	
	$fields = $pf->{manager}->fields; 
	
	
	ok($fields->[0] eq 'two', 'first field is two, (' . $fields->[0] . ')');
	ok($fields->[1] eq 'three', 'second field is three, (' . $fields->[1] . ')'); 
	ok($fields->[2] eq 'one', 'third field is one, (' . $fields->[2] . ')');
	
	
	ok(
		$pf->{manager}->change_field_order(
			{ 
				-field     => 'two', 
				-direction => 'up', 
			}
		) == 0, 
		"change_field_order() returned, 0"
	);
	
	$fields = $pf->{manager}->fields; 
	
	
	ok($fields->[0] eq 'two', 'first field is two, (' . $fields->[0] . ')');
	ok($fields->[1] eq 'three', 'second field is three, (' . $fields->[1] . ')'); 
	ok($fields->[2] eq 'one', 'third field is one, (' . $fields->[2] . ')');
	

	
	ok($pf->{manager}->remove_field({-field => 'one'}) == 1, "Removed field, one.");
	ok($pf->{manager}->remove_field({-field => 'three'}) == 1, "Removed field, two.");
	ok($pf->{manager}->remove_field({-field => 'two'}) == 1, "Removed field, three.");
	
}

my $fs  = undef; 
my $fed = {}; 
	
( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => undef } );
ok($fs == 0); 
ok($fed->{field_blank} == 1); 

( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => "'name'" } );
ok($fs == 0); 
ok($fed->{quotes} == 1); 

( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => "spaces spaces" } );
ok($fs == 0); 
ok($fed->{spaces} == 1); 

( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => "toolongtoolongtoolongtoolongtoolongtoolongtoolongtoolongtoolongtoolongtoolongtoolongtoolong" } );
ok($fs == 0); 
ok($fed->{field_name_too_long} == 1); 

( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => "%weirdcharacters" } );
ok($fs == 0); 
ok($fed->{weird_characters} == 1); 

( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => "UpperCase" } );
ok($fs == 0); 
ok($fed->{upper_case} == 1); 

$pf->{manager}->add_field({-field => 'thisone', }); 
$fields = $pf->{manager}->fields; 
( $fs, $fed ) = $pf->{manager}->validate_field_name( { -field => "thisone" } );
ok($fs == 0); 
ok($fed->{field_exists} == 1); 
ok($pf->{manager}->remove_field({-field => 'thisone'}) == 1, "Removed field, thisone.");






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



