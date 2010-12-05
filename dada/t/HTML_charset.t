#!/usr/bin/perl 



use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}

use dada_test_config; 
use Test::More qw(no_plan);



my $i = 0; 


my $list = dada_test_config::create_test_list;

use DADA::App::Guts; 
use DADA::Template::HTML; 
 
use DADA::Config qw(!:DEFAULT); 


# [ 1673762 ] 2.10.12 - alt. Charsets not set correctly.
# https://sourceforge.net/tracker/index.php?func=detail&aid=1673762&group_id=13002&atid=113002

for my $charset(@DADA::Config::CHARSETS){
    
    my ($label, $value) = split("\t", $charset, 2); 
    
    $DADA::Config::HTML_CHARSET = $value;


    my $header = DADA::Template::HTML::list_template(-Part => "header");                    
    my @lines = split("\n", $header); 
    ok($lines[0] =~ m/charset\=$value/, "List Template: Wanted: $value, Got: " . $lines[0]); 
    
    
    
    my %admin_header_params = admin_header_params; 
    ok($admin_header_params{'-charset'} eq $value, "Admin Header Params: Wanted: $value, Got: " . $admin_header_params{'-charset'}); 
    
    
    
    my $admin_header = admin_template_header(-List => 'dadatest'); 
    @lines = split("\n", $admin_header); 
    ok($lines[2] =~ m/charset\=$value/, "Admin Header: Wanted: $value, Got: " . $lines[2]); 
    
}

dada_test_config::remove_test_list;
dada_test_config::wipe_out;
