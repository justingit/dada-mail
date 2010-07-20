#!/usr/bin/perl -T
use strict;

# -T flag stuff. 
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

use lib qw(./); 
use DadaMailInstaller; 
    DadaMailInstaller->run(); 