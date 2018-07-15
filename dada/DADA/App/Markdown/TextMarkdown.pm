package DADA::App::Markdown::TextMarkdown;
use strict; 

use Text::Markdown;

sub markdown_to_html { 
	my $self = shift; 
	my $text = shift; 
	
	my $m = Text::Markdown->new;
	my $html = $m->markdown($text);
 
 	return $html; 
	
}


1;