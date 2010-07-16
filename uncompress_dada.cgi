#!/usr/bin/perl -T
use strict;

my $gz  = 'pro_dada-4_1_0.tar.gz';
my $tar = 'pro_dada-4_1_0.tar';

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
print header();
print h1('Dada Mail!');
if ( -e 'dada' ) {
    print "STOP. 'dada' directory already exists!";
    exit;
}
if ( !-e $gz ) {
    print 'Can\'t find ' . $gz . ' to uncompress!';
    exit;
}
print p("Uncompressing $gz...");

print pre(`gunzip $gz`);
if ( !-e $tar ) {
    print p( 'Can\'t find ' . $tar . ' to uncompress!' );
    exit;
}
else {
    print p("Success!");
}
print p("Unrolling $tar");
`tar -xvf $tar`;

if ( !-e 'dada' ) {
    print p("Can't find 'dada' directory!");
    exit;
}
else {
    print p("Success!");
}

print p("Changing permissions of dada/mail.cgi to, 755");
print pre(`chmod 755 dada/mail.cgi`);

print pre(`chmod 777 dada/DADA/Config.pm`);

my $installer_loc     = 'dada/installer-disabled';
my $new_installer_loc = 'dada/installer';

print p("Enabling installer at $installer_loc by moving it to, \n");

print pre(`mv $installer_loc $new_installer_loc`);

print pre(`chmod 755 $new_installer_loc/install.cgi`);

print p("done!");

print
"<h1><a href=\"./$new_installer_loc/install.cgi\">Install and Configure Dada Mail!</a></h1>";