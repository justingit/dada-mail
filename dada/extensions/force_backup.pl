#!/usr/bin/perl
use strict;

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";

BEGIN { 
	my $b__dir = ( getpwuid($>) )[7].'/perl';
    push @INC,$b__dir.'5/lib/perl5',$b__dir.'5/lib/perl5/x86_64-linux-thread-multi',$b__dir.'lib',map { $b__dir . $_ } @INC;
}

use DADA::MailingList::Settings;
use DADA::MailingList::Archives;
use DADA::App::Guts;
use CGI;
use CGI::Carp "fatalsToBrowser";
my @lists = DADA::App::Guts::available_lists();

my $q = CGI->new;
   $q = decode_cgi_obj($q);
print $q->header();
foreach (@lists) {
    print $q->h1("list: $_");
    my $ls = DADA::MailingList::Settings->new( { -list => $_ } );
    my $la = DADA::MailingList::Archives->new( { -list => $_ } );

    $ls->backupToDir;
	print $q->h2('Mailing List Settings Backed Up.'); 
    $la->backupToDir;
	print $q->h2('Mailing List Archives Backed Up.'); 
}

print $q->h1('All lists are now backed up.');

=pod

=head1 NAME force_backup.cgi

=head1 DESCRIPTION

C<force_backup.cgi> is very small utility script that will create a backup of 
Mailing List Settings and Mailing List Archives for Dada Mail Mailing Lists 
that use the default, C<Db> backened. 

=head1 INSTALLATION

Place this script in the same directory as the, C<mail.cgi> file. Change its
permissions to, C<755> and visit the script in your web browser. 

This will run the script and create the backups. 

=head1 SHORTCOMINGS

This script will only make backups for the default C<Db> backend for Mailing 
List Settings and Mailing List Archives. It probably won't do anything if you
are running the SQL backend. 

=head1 COPYRIGHT 

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 
