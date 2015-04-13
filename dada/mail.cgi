#!/usr/bin/perl 

use FindBin;
use lib "$FindBin::Bin/";
use lib "$FindBin::Bin/DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}

use CGI;
    $CGI::LIST_CONTEXT_WARN = 0;
    
use DADA::App;
use DADA::App::Dispatch;

my $d = DADA::App::Dispatch->new;
my $q = new CGI;
   $q = $d->prepare_cgi_obj($q);

my $dadamail = new DADA::App( QUERY => $q, );
   $dadamail->run();

