#!/usr/bin/perlml

use FindBin;
use lib "$FindBin::Bin/";
use lib "$FindBin::Bin/DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}

use DADA::App;
use CGI::Fast;

CGI::Fast->file_handles(
    {
        fcgi_input_file_handle  => \*STDIN,
        fcgi_output_file_handle => \*STDOUT,
        fcgi_error_file_handle  => \*STDERR,
    }
);

while ( my $q = new CGI::Fast ) {
    use DADA::App::Dispatch;
    my $d = DADA::App::Dispatch->new;
    $q = $d->prepare_cgi_obj($q);
    my $dadamail = new DADA::App(
        QUERY  => $q,
        PARAMS => {
            Ext_Request => \$CGI::Fast::Ext_Request,
        }
    );
    $dadamail->run();
}
