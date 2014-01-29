#!/usr/bin/perl 
use strict; 

use lib qw(/Users/justin/Documents/DadaMail/git/dada-mail/dada/DADA/perllib); 

use MIME::Parser; 

my $subject = 'Sending Preference Test Email for, <!-- tmpl_var list_settings.list_name -->'; 
my $pt = <<EOF

Hello, <!-- tmpl_var list_settings.list_owner_email -->, 

This message was sent out by <!-- tmpl_var PROGRAM_NAME --> to test out mail sending for the mailing list, 

		<!-- tmpl_var list_settings.list_name --> 
		
If you've received this message, it looks like mail sending is working. 

<!-- tmpl_if expr="(list_settings.sending_method eq 'sendmail')" --> 
	* Mail is being sent via the sendmail command
<!--/tmpl_if -->
<!-- tmpl_if expr="(list_settings.sending_method eq 'smtp')" --> 
	* Mail is being sent via SMTP
<!--/tmpl_if --> 
<!-- tmpl_if expr="(list_settings.sending_method eq 'amazon_ses')" --> 
	* Mail is being sent via Amazon Simple Email Service
<!--/tmpl_if -->

-- <!-- tmpl_var PROGRAM_NAME -->

EOF
;

my $html = '';


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
