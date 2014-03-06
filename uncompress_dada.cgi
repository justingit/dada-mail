#!/usr/bin/perl -T
use strict;

# No dependencies: 
# use CGI::Carp qw(fatalsToBrowser);

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

#----------------------------------------------------------------------------#
# For information on what this script is used for, please see:
# http://dadamailproject.com/d/install_dada_mail.pod.html

# What's the name of the file I'm looking for to uncompress?
# Basic Dada Mail
my $basic = 'dada-6_9_0.tar.gz';
#
#
# Pro Dada
my $pro = 'pro_' . $basic;

my $using = $pro;

print "Content-type:text/html\r\n\r\n";
print '<h1>Adventures with Dada Mail!</h1>';

if ( -e 'dada' ) {
    print 
"<p>Yikes! A directory named, \"dada\" already exists in this location! Please manually move this directory, before running this script!</p>";
    exit;
}

if ( !-e $pro ) {

    print "<p>Can't find Pro Dada distribution at, $pro, looking for Basic distribution...</p>";
    $using = $basic;

    if ( !-e $basic ) {
        print '<p>Yikes! Can\'t find either the  '
              . $basic . ' or '
              . $pro
              . ' Dada Mail distributions to uncompress!</p>';
        exit;
    }
	else { 
		print "<p>Found, $basic!</p>"; 
	}
}

print "<p><em>Starting Adventure...</em></p>";

print "<p>Uncompressing $using...</p>";

`tar -xvzf $using`;

if ( !-e 'dada' ) {

    `gunzip $using`;
    my $tar = $using;
    $tar =~ s/\.gz$//;
    if ( !-e $tar ) {
        print  '<p>Can\'t find ' . $tar . ' to uncompress!</p>';
        print '<p>You may have to uncompress and prep Dada Mail manually.</p>';
        exit;
    }
    else {
        print "<p><em>Success!</em></p>";
        print "<p>Unrolling $tar</p>";
        `tar -xvf $tar`;
    }
}
else {
    print "<p><em>Success!</em></p>";
}

print  "<p>Checking to see if \"dada\" directory now exists...</p>";
if ( !-e 'dada' ) {
    print "<p>Can't find 'dada' directory!</p>";
    exit;
}
else {
    print "<p><em>Success!</em></p>";
}

print "<p>Changing permissions of dada/mail.cgi to, 755</p>";
`chmod 755 dada`;
`chmod 755 dada/DADA`;
`chmod 755 dada/mail.cgi`;
`chmod 777 dada/DADA/Config.pm`;

my $installer_loc     = 'dada/installer-disabled';
my $new_installer_loc = 'dada/installer';

print 
    "<p>Enabling installer at $installer_loc by moving it to, $new_installer_loc</p>";

`mv $installer_loc $new_installer_loc`;
`chmod 755 $new_installer_loc`;
`chmod 755 $new_installer_loc/install.cgi`;

print "<p><em>Done!</em></p>";

print
"<h1 style=\"text-align:center\"><a href=\"./$new_installer_loc/install.cgi\">Install and Configure Dada Mail!</a></h1>";
