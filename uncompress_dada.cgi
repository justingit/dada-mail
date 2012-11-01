#!/usr/bin/perl -T
use strict;

# For information on what this script is used for, please see: 
# http://dadamailproject.com/d/install_dada_mail.pod.html


# You may have to update this, depending on the version of Dada Mail!
my $gz = 'dada-5_2_2.tar.gz';

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

print h1('Adventures with Dada Mail!');
if ( -e 'dada' ) {
    print p("STOPPING! 'dada' directory already exists! Please manually move this directory, before running this script!");
    exit;
}

print p(i("Starting Adventure..."));


print p("Uncompressing $gz...");
`gunzip $gz`;

my $tar = $gz;
   $tar =~ s/\.gz$//;

if ( !-e $tar ) {
    print p( 'Can\'t find ' . $tar . ' to uncompress!' );
    print p('You may have to uncompress and prep Dada Mail manually.');

    exit;
}
else {
    print p(i("Success!"));
}

print p("Unrolling $tar");
`tar -xvf $tar`;

if ( !-e 'dada' ) {
    print p("Can't find 'dada' directory!");
    exit;
}
else {
    print p(i("Success!"));
}

print p("Changing permissions of dada/mail.cgi to, 755");
`chmod 755 dada/mail.cgi`;
`chmod 777 dada/DADA/Config.pm`;

my $installer_loc     = 'dada/installer-disabled';
my $new_installer_loc = 'dada/installer';

print p("Enabling installer at $installer_loc by moving it to, $new_installer_loc\n");

`mv $installer_loc $new_installer_loc`;
`chmod 755 $new_installer_loc/install.cgi`;

print p(i("Done!"));

print
"<h1 style=\"text-align:center\"><a href=\"./$new_installer_loc/install.cgi\">Install and Configure Dada Mail!</a></h1>";
