#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 
use DADA::App::Guts; 
use DADA::MailingList::Settings; 

#dada_test_config::wipe_out;

use Test::More qw(no_plan);  

my $list = dada_test_config::create_test_list;

my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 


do "plugins/bounce_handler.cgi"; 


ok(bounce_handler->test_sub() eq q{Hello, World!}); 

my $test_msg = undef; 
my $entity   = undef; 

use MIME::Parser;
use MIME::Entity; 

my $parser = new MIME::Parser; 
   $parser = DADA::App::Guts::optimize_mime_parser($parser); 


# [ 2136642 ] 3.0.0 - Check_List_Owner_Return_Path_Header fails with undef
# http://sourceforge.net/tracker/index.php?func=detail&aid=2136642&group_id=13002&atid=113002

$test_msg = slurp('t/corpus/email_messages/bouncing_email_with_brackets.eml'); 

$entity = $parser->parse_data($test_msg);

require DADA::App::BounceHandler::MessageParser;
my $bhmp = DADA::App::BounceHandler::MessageParser->new;
my ($e, $l, $d) = $bhmp->run_all_parses($entity); 

#use Data::Dumper; 
#diag Dumper([$e, $l, $d]); 
ok($e eq 'bouncing.email@example.com',"($e)"); 
 
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



