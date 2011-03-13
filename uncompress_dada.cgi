#!/usr/bin/perl -T
use strict;

# For information on what this script is used for, please see: 
# http://dadamailproject.com/d/install_dada_mail.pod.html


# You may have to update this, depending on the version of Dada Mail!
my $gz = 'dada-4_4_3-beta1.tar.gz';

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
print header();

if ( !-e $gz ) {
    $gz = 'pro_' . $gz;
}
if ( !-e $gz ) {
    print p('Can\'t find ' . $gz . ' to uncompress!');
    exit;
}

print h1('Dada Mail!');
if ( -e 'dada' ) {
    print p("STOP. 'dada' directory already exists!");
    exit;
}

print p("Uncompressing $gz...");
print pre(`gunzip $gz`);

my $tar = $gz;
   $tar =~ s/\.gz$//;

if ( !-e $tar ) {
    print p( 'Can\'t find ' . $tar . ' to uncompress!' );
    print p('You may have to uncompress and prep Dada Mail manually.');

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

print p("Enabling installer at $installer_loc by moving it to, $new_installer_loc\n");

print pre(`mv $installer_loc $new_installer_loc`);

print pre(`chmod 755 $new_installer_loc/install.cgi`);

print p("done!");

print
"<h1><a href=\"./$new_installer_loc/install.cgi\">Install and Configure Dada Mail!</a></h1>";
