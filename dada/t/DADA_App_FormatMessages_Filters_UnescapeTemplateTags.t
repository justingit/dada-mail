#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
my $list = dada_test_config::create_test_list;


use Test::More qw(no_plan);  


require DADA::App::FormatMessages::Filters::UnescapeTemplateTags; 
my $utt = DADA::App::FormatMessages::Filters::UnescapeTemplateTags->new; 

# This basically makes sure that template begin/end tags are destroyed. 
my $str = '&lt;!-- tmpl_if --&gt;&lt;!-- /tmpl_if --&gt;';
   $str = $utt->filter({-html_msg => $str});
ok($str eq '<!-- tmpl_if --><!-- /tmpl_if -->');


dada_test_config::remove_test_list;
dada_test_config::wipe_out;



