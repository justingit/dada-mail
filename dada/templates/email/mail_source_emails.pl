#!/usr/bin/perl 
use strict; 

use lib qw(/Users/justin/Documents/DadaMail/git/dada-mail/dada/DADA/perllib); 

use MIME::Parser; 

my $subject = '<!-- tmpl_var archived_message_subject --> (Archive)'; 
my $pt = <<EOF

Hello, 

On behalf of: <!-- tmpl_var from_email -->, the following archived message from: 

<!-- tmpl_var list_settings.list_name --> 

has been sent to you. They wrote: 

<!-- tmpl_var note -->

The archived message is below. 

You can subscribe to <!-- tmpl_var list_settings.list_name --> by following this link:

<!-- tmpl_var list_subscribe_link -->

If you cannot view the archived message, please visit: 

<!-- tmpl_var archive_message_url -->

EOF
;

my $html = <<EOF

<p>Hello,</p> 

<p>On behalf of: <!-- tmpl_var from_email -->, the following archived message 
from:</p>

<p><!-- tmpl_var list_settings.list_name --></p>

<p>has been sent to you. They wrote:</p> 

<p>
 <em> 
  <!-- tmpl_var note -->
 </em> 
</p>

<p>The archived message is below.</p> 

<p>You can subscribe to <!-- tmpl_var list_settings.list_name --> by following this link:</p>

<p>
 <a href="<!-- tmpl_var list_subscribe_link -->">
  <!-- tmpl_var list_subscribe_link -->
 </a>.
</p>

<p>If you cannot view the archived message, please visit:</p>

<p><a href="<!-- tmpl_var archive_message_url -->"><!-- tmpl_var archive_message_url --></a></p>


EOF
;

use Email::Address; 

my $from_phrase = '<!-- tmpl_var list_settings.list_name -->';
my $to_phrase   = '<!-- tmpl_var list_settings.list_name -->';


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
