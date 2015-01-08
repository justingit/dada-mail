#!/usr/bin/perl 

$|++;

use FindBin;
use lib "$FindBin::Bin/";
use lib "$FindBin::Bin/DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}


use CGI::Carp qw(fatalsToBrowser);

use     DADA::App::Dispatch; 
my $d = DADA::App::Dispatch->new; 
my $q = $d->prepare_cgi_obj; 

#use Data::Dumper; 
#die Dumper($q); 

use DADA::App;
my $dadamail = DADA::App->new(QUERY => $q);
$dadamail->run();
