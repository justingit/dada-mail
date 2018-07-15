package DADA::App::Markdown;
use strict;

use lib qw(
  ../../
  ../../DADA/perllib
);

my $markdown_module;

use DADA::Config qw(!:DEFAULT);
my $t = 0;

#$DADA::Config::MARKDOWN_TYPE = 'TextMarkdown';

BEGIN {
#    $type = $DADA::Config::MARKDOWN_TYPE;
	my $type = 'TextMarkdown';
    if ( $type eq 'TextMarkdown' ) {
            $markdown_module = 'TextMarkdown';
    }
    else {
        die
"Unknown \$MARKDOWN_TYPE: '$type' Supported types: 'TextMarkdown'";
    }
}
use base "DADA::App::Markdown::$markdown_module";

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
    return $self;

}

sub _init {

    my $self = shift;
    my ($args) = @_;

}






1;