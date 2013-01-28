package Bundle::DadaMail;


$VERSION = '0.01';

1;

__END__

=head1 NAME

Bundle::DadaMail

=head1 DESCRIPTION

This is a a listing of all the CPAN perl modules that are shipped in 
Dada Mail's dada/DADA/perllib directory. When we create a distribution, we fetch the CPAN module list below and insert it into the Dada Mail distribution. 

Dada Mail currently needs the standard Perl distribution's module listing, plus
what's below in the B<CONTENTS> section. Some of these modules below also come 
with a standard Perl distribution - but may be outdated for Dada Mail's taste or
have bugs, or we have workarounds to certain misc. issues.

If you installed the following modules in your server's perl directory, you may 
remove the I<dada/DADA/perllib> directory from the installed distribution. 

=head1 CONTENTS

Captcha::reCAPTCHA

CGI

CGI::Session

CGI::Session::ExpireSessions

Class::Accessor

Class::Accessor::Chained::Fast

Data::Page

Data::PageSet

Date::Format

Digest 

Digest::MD5

Digest::Perl::MD5

Email::Address

Email::Find

Email::Valid

Exporter::Lite

File::Spec

GD::SecurityImage;

Data::Google::Visualization::DataTable

HTML::Entities::Numbered

HTML::Tagset

HTML::Template

HTML::Tiny

Data::Pageset

HTML::Template::Expr

HTTP::Date

HTML::TextToHTML

IO::Stringy

Bundle::libnet

Mail::DeliveryStatus::BounceParser 

Email::Address

Mail::Address

Mail::Cap

Mail::Field

Mail::Field::AddrList

Mail::Field::Date

Mail::Filter

Mail::Header

Mail::Internet 

Mail::Mailer

Mail::Mailer::qmail 	  	 

Mail::Mailer::rfc822 	  	 

Mail::Mailer::sendmail 	  	 

Mail::Mailer::smtp 	  	 

Mail::Mailer::testfile 	 

Mail::POP3Client 

Mail::Send

Mail::Util

Mail::Verp

MD5

MIME::EncWords

MIME::Type

MIME::Types

MIME::Lite

MIME::Lite::HTML

MIME::Tools

MLDBM

Net::SMTP

Net::SMTP_auth 

Parse::RecDescent

id/D/DC/DCONWAY/Text-Balanced-1.98.tar.gz

PHP::Session

Scalar-List-Utils

Text::CSV

Text::Tabs

Text::Wrap

Time::Local

Time::Piece

Try::Tiny

URI::Escape

URI::GoogleChart

=head1 Other Required Modules to Install

=head1 Other Optional Modules To Install

=head2 Required Modules, not fetched via CPAN

The modules in this section NEED to be installed, but aren't installed via CPAN: 

=over

=item * Crypt::CipherSaber

Dada Mail uses, version 0.61 of this module. There's a newer one on CPAN, but it's prereqs are long and some of the modules require compilation, and I haven't figured out what's so great about the new version, so we're sticking with the old version for now. 

The weird thing is that this old version (0.61) isn't available on CPAN anymore. Why? I don't know, but it becomes an annoyance. 

=back

=head2 Optional Modules

The modules below do not need to be installed for Dada Mail to work, but can
enhance the functionality of Dada Mail. 

=head3 HTML::FormatText::WithLinks

C<HTML::FormatText::WithLinks> is used to convert HTML to Plain Text. 

If you do not have this module installed, Dada Mail can use its own HTML to Plain Text formatter, but it's not very good. 

We suggest HTML::FormatText::WithLinks, it just has to be installed manually. 

=head3 Net::Domain

Used to locate the domain of the site Dada Mail is installed - mostly for creating the  Message-ID header for email messages. 

=head3 DBI

If DBI is installed, as well as the proper DBD::xsql driver is installed - as well as a SQL server to compliment it, Dada Mail can use that backend to store its subscription list and archives. In some cases, this adds extra functionality 
to Dada Mail. 

=head3 HTML::Scrubber

Used to take out nasty bits that may be present in archived email messages when viewed in Dada Mail's public archive. 

A B<very> good idea to have if you're running a discussion list. 

=head3 MIME::Base64

This module is actually required, but sometimes is not present in the standard distribution. It's better to use the XS version of this module, but Dada Mail has a copy of the Pure-Perl version in I<dada/DADA/perllib>, but you must change the name of the dada/DADA/perllib/MIME/Base64.pm-remove_to_install and dada/DADA/perllib/MIME/QuotedPrint.pm-remove_to_install, removing, "-remove_to_install"

=head3 Net::DNS;

Used for its mx lookup capabilities. 

=head3 Storable

Used for scheduled mailings. 

=head3 XMLRPC::Lite

Used for pinging the RSS/Atom archive feeds. A part of SOAP::Lite I believe. 

=head3 LWP::Simple

Used to send web pages. 

=head3 Net::SMTP::SSL

Use for SMTP Connections over SSL. Also requires IO::Socket::SSL

=head3 IO::Socket::SSL

Used for SMTP connections over SSL. 

=head3 Captcha::reCAPTCHA::Mailhide

This is used for the reCAPTCHA Mailhide functionality. I was hoping I could distribute Dada Mail
with this module, but I can't, since one of its dependencies is an XS module. It's dependencies are: 

=over

=item * Crypt::Rijndael

There is a Crypt::Rijndael_PP, which is a Pure Perl version of the above, but unless I hack the above module, it won't use it be default. I have added a wishlist to have this happen (and volunteered) 

http://rt.cpan.org//Ticket/Display.html?id=31740

If I don't get an answer, I may infact make some sort of stopgap solution, but I hope I get an answer. 

B<Captcha::reCAPTCHA> should still be included, as it does not require B<Crypt::Rijndael>. 

=item * MIME::Base64

=item * HTML::Tiny


=back

=cut


Authen::SASL is needed for Net::SMTP_auth
