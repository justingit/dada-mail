#!/usr/bin/perl -w 

use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);
use CGI qw(:fatalsToBrowser); 
use CGI qw(:standard); 

$|++; 

my $Test_Files = '../t';

print header(); 
print "<h1>Starting...</h1>"; 


my $test_files = get_test_files(); 

foreach $file(@$test_files){ 

    print "<h2>$file</h2>"; 
    print "<hr><pre>";
#   print `perl $Test_Files/$file`;   
    print `prove -r -v $Test_Files/$file`; 
  
    print "</pre>"; 
    
}


print "<h1>Done!</h1>"; 



sub get_test_files { 

    my @tests;  
    if(opendir(TESTDIR, $Test_Files)){ 
		my $tf; 
			while(defined($tf = readdir TESTDIR) ) {
				next if $tf   =~ /^\.\.?$/;
				$tf           =~ s(^.*/)();
				if($tf =~ m{\.t$}){ 
				    push(@tests, $tf); 
				} 
			}
		closedir(TESTDIR) or warn "couldn't close: '" . $Test_Files . "' because: $!"; 
    }
    return \@tests; 
}


=head1 NAME

dada_tester.cgi - a VERY rudimentary runner of Perl automated tests. 

=head1 VERSION

Refer to the version of Dada Mail you're using - NEVER use a version of this proggy with an earlier or later version of Dada Mail. 

=head1 USAGE

=over

=item * Use it like a cgi script. 

Put it in your, B<extensions> directory (ala: cgi-bin/dada/extensions), chmod 755, visit it in your web browser. 

=back

=head1 DESCRIPTION

This small script runs the Perl automated test files that come with Dada Mail. These files are located in the, I<dada/t> directory. 

Usually, these files are run using the, C<prove> command like so: 

I<running in a command line, cd'd into the, B<cgi-bin/dada> directory...> 

 prove -r

If you have the ability to run the Dada Mail tests using the C<prove> command via a command line, that's the best way to do it. This very script is basically a very crude wrapper around that command. 

=head1 WARNING! 

B<Do Not> have this script available for anything but testing. It shouldn't be kept in your cgi-bin/dada/extensions directory with permissions to execute, unless you're actually using it. Any other time, either change the permissions to disallow execution, or remove the script entirely. 

=head1 SEE ALSO

Dada Mail's automated test suite is much like any other automated test suites for Perl modules and scripts, distributed through CPAN and other means. 

Because of this, any and all the advice given about Perl automated tests applies to Dada Mail's own testing suite. Some good articles you may want to read to understand how Perl automated tests work: 

=over

=item * Automated testing with Perl

L<http://petdance.com/perl/automated-testing/>

=item * Test::Tutorial

L<http://search.cpan.org/dist/Test-Simple/lib/Test/Tutorial.pod>

=item * C<prove> Documentation

http://search.cpan.org/~petdance/Test-Harness/bin/prove

=back


=head1 DIAGNOSTICS

None, really.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Currently, the server running your Dada Mail is going to have to have at the very least, the Test::Simple and Test::More CPAN modules. Some of the test files require different testing modules to do their job. They'll usually tell you if something's missing. 

If the C<prove> utility isn't available, try this: 

Find this line in the dada_tester.cgi script: 

     print `prove -r -v $Test_Files/$file`; 

And comment it out. 

Find this line in the dada_tester.cgi script: 

    #   print `perl $Test_Files/$file`;   

And uncomment it (delete the, '#' character)

and try running the script again. 
    

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Justin Simoni All rights reserved. 

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
