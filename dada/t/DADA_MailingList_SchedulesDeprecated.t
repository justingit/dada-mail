#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 

use Test::More qw(no_plan);  

use DADA::Config;
use DADA::App::Guts; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::MailingList::SchedulesDeprecated; 
use CGI; 

my $list = dada_test_config::create_test_list;

my $mss = DADA::MailingList::SchedulesDeprecated->new(
			{ 
				-list => $list,
			}
			); 

ok($mss->isa('DADA::MailingList::SchedulesDeprecated')); 

my %schema = DADA::MailingList::SchedulesDeprecated::schedule_schema();

# I'm guessing if we have this, we have all the rest too; 
ok($schema{message_name} eq 'scheduled mailing');

eval { $mss->save_from_params(); };

ok(defined($@), "Error when attempting to save without passing the -cgi_obj: $@");

my $q = new CGI; 
   $q = decode_cgi_obj($q);

   $q->param('message_name',     'My Message Name'); 
   $q->param('active',            1); 
   $q->param('Subject',          'My Message Subject'); 
   $q->param('PlainText_source', 'from_text'); 
   $q->param('PlainText_text',   'My Message Body'); 
	
my $key = $mss->save_from_params(
				{
					-cgi_obj => $q, 
				}
			); 
ok($key > 0, "We have a defined key!"); 

my @keys = $mss->record_keys; 
ok($#keys == 0, "Looks like our record is saved!"); 
ok($key == $keys[0], "Looks like our keys ($key) matches up, too!"); 


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




