package DADA::Profile::Fields::SQLite;
use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib);

use Carp qw(carp croak confess);
use DADA::App::Guts;
use base "DADA::Profile::Fields::baseSQL";
use strict;

1;