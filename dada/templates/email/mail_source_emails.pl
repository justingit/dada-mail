#!/usr/bin/perl 
use strict; 

use lib qw(/Users/justin/Documents/DadaMail/git/dada-mail/dada/DADA/perllib); 

use MIME::Parser; 

my $subject = 'Abuse Reported on <!-- tmpl_var list_settings.list_name --> (<!-- tmpl_var list_settings.list -->): <!-- tmpl_var subscriber.email -->'; 
my $pt = <<EOF

Hello, <!-- tmpl_var list_settings.list_owner_email -->, 

The following address: 

    <!-- tmpl_var subscriber.email --> 
    
has reported abuse pertaining to your mailing list: 

    <!-- tmpl_var list_settings.list_name --> (<!-- tmpl_var list_settings.list -->)
    
Their report is below: 

<!-- tmpl_var abuse_report_details -->

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
