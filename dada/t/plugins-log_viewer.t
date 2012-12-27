#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 

use DADA::App::Guts; 
use DADA::MailingList::Settings; 

$DADA::Config::PROGRAM_USAGE_LOG = $DADA::Config::FILES . '/dada_usage.txt'; 


use DADA::Logging::Usage; 

my $log =  new DADA::Logging::Usage;;
$log->trace('<found>');


#dada_test_config::wipe_out;

use Test::More qw(no_plan);  

my $list = dada_test_config::create_test_list;

my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 


do "plugins/log_viewer.cgi"; 


ok(log_viewer->test_sub() eq q{Hello, World!}); 

# [ 2124123 ] 3.0.0 - Log viewer doesn't escape ">" "<" in searches
# http://sourceforge.net/tracker/index.php?func=detail&aid=2124123&group_id=13002&atid=113002

my $results   = log_viewer::search_logs([$DADA::Config::PROGRAM_USAGE_LOG], 'found', 1);
my $find_this = quotemeta('<em class="highlighted">found</em>'); 
like($results, qr/$find_this/, "found the stuff, escaped."); 

#/ [ 2124123 ] 3.0.0 - Log viewer doesn't escape ">" "<" in searches
#/ http://sourceforge.net/tracker/index.php?func=detail&aid=2124123&group_id=13002&atid=113002






dada_test_config::remove_test_list;
dada_test_config::wipe_out;
