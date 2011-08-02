#!/usr/bin/perl 
use lib qw(./); 
do "../plugins/mailing_monitor.cgi"; 
tracker->run(); 

=pod

=head1 auto_pickup.pl

This plugin, as of v4.6.0 of Dada Mail is nothing but a redirect (basically) for the new Mailing Monitor plugin. 

=head4 More Information 

L<http://dadamailproject.com/d/mailing_monitor.cgi.html>

=cut
