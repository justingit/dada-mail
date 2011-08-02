#!/usr/bin/perl 
use lib qw(./); 
do "./tracker.cgi"; 
tracker->run(); 

=pod

=head1 clickthrough_tracker.cgi

This plugin, as of v4.5.0 of Dada Mail is nothing but a redirect (basically) for the 
new Tracker plugin. 

=head4 More Information 

L<http://dadamailproject.com/d/tracker.cgi.html>

=cut
