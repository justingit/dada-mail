#!/usr/bin/perl 
use strict; 

use lib qw(/Users/justin/Documents/DadaMail/git/dada-mail/dada/DADA/perllib); 

use MIME::Parser; 

my $subject = 'Unsubscribed from: <!-- tmpl_var list_settings.list_name --> because of excessive bouncing'; 
my $pt = <<EOF

Hello, This is <!-- tmpl_var Plugin_Name -->, the bounce handler for <!-- tmpl_var PROGRAM_NAME -->

This is a notice that your email address:

    <!-- tmpl_var subscriber.email -->
    
has been unsubscribed from:

    <!-- tmpl_var list_settings.list_name -->
    
Because your email address has been bouncing messages sent to it, 
originating from this list.

If this is in error, please re-subscribe to this list, by following 
this link: 

    <!-- tmpl_var PROGRAM_URL -->/s/<!-- tmpl_var list_settings.list -->

If you have any questions, please email the list owner of this list at: 

    <!-- tmpl_var list_settings.list_owner_email -->
    
for more information. 

- <!-- tmpl_var PROGRAM_NAME -->

EOF
;

my $html = '';


use Email::Address; 

my $from_phrase = '<!-- tmpl_var list_settings.list_name --> Subscriber';
my $to_phrase   = '<!-- tmpl_var list_settings.list_name --> Owner';


use MIME::Entity; 

my $top = MIME::Entity->build(
						   Type     => "multipart/alternative",
						   To       => Email::Address->new($to_phrase,   'user@example.com')->format,
                           From     => Email::Address->new($from_phrase, 'user@example.com')->format,
                           Subject  => $subject);
$top->attach(
	Type => 'text/plain',
	Data => $pt,
	Encoding => 'binary', 
);
 
$top->attach(
	Type => 'text/html',
	Data => $html,
	Encoding => 'binary', 
);


my $parser = MIME::Parser->new; 
my $message = $top->stringify; 
print $message; 

=cut

my $entity = $parser->parse_data($message);

my $r_to_address= $entity->head->get( 'To', 0 );
my $r_to_phrase = ( Email::Address->parse($r_to_address) )[0]->phrase;
print $r_to_phrase; 
print "\n"; 

my $r_from_address= $entity->head->get( 'From', 0 );
my $r_from_phrase = ( Email::Address->parse($r_from_address) )[0]->phrase;
print $r_from_phrase; 
print "\n"; 

my @parts = $entity->parts; 

my $r_pt = $parts[0]->bodyhandle->as_string;
print $r_pt; 


print "\n"; 


my $r_html = $parts[1]->bodyhandle->as_string;
print $r_html; 

=cut
