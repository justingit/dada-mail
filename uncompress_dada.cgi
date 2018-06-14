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
my $basic = 'dada-11_0_2.tar.gz';
#
#
# Pro Dada
my $pro = 'pro_' . $basic;

my $using = $pro;
 
print "Content-type:text/html\r\n\r\n";
print '<h1><em>Beginning Adventures with Dada Mail...</em></h1>';

if($] < 5.010){ 
    print qq{
		<p style="color:red"><strong>Warning:</strong> you may be currently 
		running a version of Perl that's below the minimum requirement 
		(Perl v5.10.1) - see if a newer version of Perl is available and adjust 
		the app, before running the installer!</p>}; 
}

if ( -e 'dada' ) {
    print  qq{<p><strong>Yikes!</strong> A directory named, "dada" already exists 
			 in this location! Please manually move this directory, before running 
			 this script!</p>};
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

print "<h2>Starting Adventure...</h2>";

print "<p>Uncompressing $using...</p>";

`tar -xvzf $using`;

if ( !-e 'dada' ) {

    `gunzip $using`;
    my $tar = $using;
    $tar =~ s/\.gz$//;
    if ( !-e $tar ) {
        print '<p>Can\'t find ' . $tar . ' to uncompress!</p>';
        print '<p>You may have to uncompress and prep Dada Mail manually.</p>';
        exit;
    }
    else {
        print "<h2>Success!</h2>";
        print "<p>Unrolling $tar</p>";
        `tar -xvf $tar`;
    }
}
else {
    print "<h2>Success!</h2>";
}

print  "<p>Checking to see if \"dada\" directory now exists...</p>";
if ( !-e 'dada' ) {
    print "<p><strong>Can't find 'dada' directory!</strong></p>";
    exit;
}
else {
    print "<h2>Success!</h2>";
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

print "<h2>Done!</h2>";

print qq{<h1 style="text-align:center"><a href="./$new_installer_loc/install.cgi">
	Continue Installing and Configuring Dada Mail!</a></h1>};
