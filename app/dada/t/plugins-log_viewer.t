#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 
dada_test_config::create_SQLite_db(); 
my $list = dada_test_config::create_test_list;

use CGI; 
my $q = CGI->new; 


use DADA::App::Guts; 
use DADA::MailingList::Settings; 

$DADA::Config::PROGRAM_USAGE_LOG = $DADA::Config::FILES . '/dada_usage.txt'; 


use DADA::Logging::Usage; 

my $log =  new DADA::Logging::Usage;

   $log->trace('<found>');


#dada_test_config::wipe_out;

use Test::More qw(no_plan);  


my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 
require "plugins/log_viewer"; 


ok(log_viewer::test_sub() eq q{Hello, World!}); 

# [ 2124123 ] 3.0.0 - Log viewer doesn't escape ">" "<" in searches
# http://sourceforge.net/tracker/index.php?func=detail&aid=2124123&group_id=13002&atid=113002

$q->param('query', 'found'); 

# I do not know why this is needed: 
`chmod 644 $DADA::Config::PROGRAM_USAGE_LOG`;

my $results   = log_viewer::search_logs(
    $q,
    [$DADA::Config::PROGRAM_USAGE_LOG], 
    'found',
    1, 
    $list
);		

diag "$results: " . $results; 
	
				
my $find_this = quotemeta('<em class="dm_highlighted">found</em>'); 
like($results, qr/$find_this/, "found the stuff, escaped."); 

#/ [ 2124123 ] 3.0.0 - Log viewer doesn't escape ">" "<" in searches
#/ http://sourceforge.net/tracker/index.php?func=detail&aid=2124123&group_id=13002&atid=113002






dada_test_config::remove_test_list;
dada_test_config::destroy_SQLite_db();

dada_test_config::wipe_out;
