#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use Test::More qw(no_plan);  


my $list = dada_test_config::create_test_list;

use DADA::App::MyMIMELiteHTML;

my @tmpl_tags = (

'<!-- tmpl_var blah -->',
'<!-- tmpl_if blah -->boom!<!-- /tmpl_if --->',	
'<!-- tmpl_loop blah -->boom!<!-- /tmpl_loop --->',
'[redirect=http://example.com]'
); 

my $html_msg = <<EOF

<h1>Heading!</h1> 

<p><a href="<!-- tmpl_var blah -->">Something!</a></p> 

<p><a href="<!-- tmpl_if blah -->boom!<!-- /tmpl_if --->">Something!</a></p> 

<p><a href="<!-- tmpl_loop blah -->boom!<!-- /tmpl_loop --->">Something!</a></p> 

<p><a href="[redirect=http://example.com]">Something!</a></p> 

EOF
; 

# This test is to make sure tags embedded in links still work. 
my $mailHTML = new DADA::App::MyMIMELiteHTML();
my $MIMELiteObj = $mailHTML->parse($html_msg);
my $msg = $MIMELiteObj->as_string;

use MIME::Parser; 
my $parser = MIME::Parser->new;
   $parser = DADA::App::Guts::optimize_mime_parser($parser);  
my $entity     = $parser->parse_data($msg);
	
my $str = $entity->bodyhandle->as_string;

for my $tmpl_tag(@tmpl_tags){ 
	my $match = quotemeta($tmpl_tag); 
	like($str, qr/$match/, "found: $tmpl_tag ")
}

#dada_test_config::remove_test_list;
dada_test_config::wipe_out;



