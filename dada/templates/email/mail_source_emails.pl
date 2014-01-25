#!/usr/bin/perl 
use strict; 

use lib qw(/Users/justin/Documents/DadaMail/git/dada-mail/dada/DADA/perllib); 

use MIME::Parser; 

my $subject = 'You\'ve been Invited to Subscribe to, "<!-- tmpl_var list_settings.list_name -->"'; 
my $pt = <<EOF
Hello!

The List Owner of, "<!-- tmpl_var list_settings.list_name -->" (<!-- tmpl_var list_settings.list_owner_email -->) has invited you to Subscribe!
 
* Here's a brief description of this mailing list: 

<!-- tmpl_var list_settings.info --> 

* If you'd like to subscribe, just click the link below: 
<!-- tmpl_var list_confirm_subscribe_link --> 

<!-- tmpl_if list_settings.group_list --> 
* This mailing list is a group discussion list <!-- tmpl_if list_settings.enable_moderation -->(moderated)<!-- tmpl_else -->(unmoderated)<!-- /tmpl_if -->. Once subscribed, you can start a new thread, by sending an email message to, <!-- tmpl_var list_settings.discussion_pop_email --> 
<!-- tmpl_else --> 
* This mailing list is an announce-only mailing list. 
<!-- /tmpl_if --> 

* Want more information? Visit:
<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/

* Privacy Policy: 
<!-- tmpl_var list_settings.privacy_policy -->

* Physical Address:
<!-- tmpl_var list_settings.physical_address -->

Thanks! 

- <!-- tmpl_var list_settings.list_owner_email -->
EOF
;

my $html = <<EOF
<p>
 Hello!
</p>

<p>
 The List Owner of, &quot;
  <strong>
   <!-- tmpl_var list_settings.list_name -->
  </strong>
  &quot; (
  <a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->">
   <!-- tmpl_var list_settings.list_owner_email -->
  </a>
 ) has invited you to Subscribe!
</p>

<ul> 
 <li>
  <p>
   Here's a brief description of this mailing list: 
  </p>

<blockquote> 
<!-- tmpl_var list_settings.info --> 
</blockquote> 

</li> 

<li> 
 <p>
  <strong> 
   If you'd like to subscribe, just click the link below: 
  </strong>
 </p> 
 <p>
  <strong> 
   <a href="<!-- tmpl_var list_confirm_subscribe_link -->">
    <!-- tmpl_var list_confirm_subscribe_link -->
   </a>
  </strong>
 </p>
</li>

<li>

<!-- tmpl_if list_settings.group_list --> 

	<p>
	 This mailing list is a group discussion list 
	<!-- tmpl_if list_settings.enable_moderation -->
		(moderated)
	<!-- tmpl_else -->
		(unmoderated)
	<!-- /tmpl_if -->.
		Once subscribed, you can start a new thread, by sending an email message to,</p>
		<ul> 
		 <li> 
		  <a href="mailto:<!-- tmpl_var list_settings.discussion_pop_email -->">
		   <!-- tmpl_var list_settings.discussion_pop_email -->
		  </a>
		 </li>
		</ul>
<!-- tmpl_else -->
	<p>This mailing list is an announce-only mailing list.</p>
<!-- /tmpl_if --> 
</li>

<li>
 <p>
  <strong>
   Want more information? Visit:
  </strong>
 </p>
  <a href="<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/">
   <!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var list_settings.list -->/
  </a> 
 </p> 
</li>

<li>
 <p>
  <strong>
   Privacy Policy:
  </strong>
 </p>

 <blockquote> 
  <!-- tmpl_var list_settings.privacy_policy -->
 </blockquote> 
</li>

<li>
 <p>
  <strong>
   Physical Address:
  </strong>
 </p>
 <blockquote> 
  <!-- tmpl_var list_settings.physical_address -->
 </blockquote> 
</li>

</ul> 

<p>
 <strong>
  Thanks!
 </strong>
</p>


<p>-<a href="mailto:<!-- tmpl_var list_settings.list_owner_email -->"><!-- tmpl_var list_settings.list_owner_email --></a></p> 

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
