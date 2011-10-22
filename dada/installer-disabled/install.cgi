#!/usr/bin/perl -T
use strict;
use Carp qw(croak carp);
use CGI::Carp qw(fatalsToBrowser);

# -T flag stuff. 
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

use lib qw(./lib); 
use DadaMailInstaller; 
    DadaMailInstaller->run();