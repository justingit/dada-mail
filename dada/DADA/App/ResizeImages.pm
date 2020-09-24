package DADA::App::ResizeImages; 

use lib qw(../../ ../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  
use Carp qw(carp croak);
use Try::Tiny; 

require Exporter; 
@ISA = qw(Exporter); 

use strict; 
use vars qw(@EXPORT); 
@EXPORT = qw(); 

use Image::Scale;

my $t = 1; 


sub resize_image { 

	my ($args) = @_; 
	
	if($t){ 
		require Data::Dumper; 
		warn 'args: ' . Data::Dumper::Dumper($args);
	}

	if(!exists($args->{-file_path})){ 
		croak "you need to pass, -fn";
	}

	if(!exists($args->{-save_file_path})){ 
		croak "you need to pass, -save_path";
	}

	if(!exists($args->{-width})){ 
		croak "you need to pass, -width";
	}
	
	#if(!exists($args->{-height})){ 
	#	croak "you need to pass, -height";
	#}
	
	try { 
		my $img = Image::Scale->new($args->{-file_path}) || die "Invalid file: " . $args->{-file_path};
		my $w = $img->width; 
	
		my $r_fn = filename_from_url($args->{-file_path}); 
	
	    if ($w > $args->{-width} ) {
       
			#my $h   = $img->height;
	        my $n_w = $args->{-width};
	        #my $n_h = int( ( int($n_w) * int($h) ) / int($w) ); # not needing for this module. 

	        $img->resize_gd( 
				{ 
					width  => $n_w, 
					#height => $n_h
				} 
			);
		
	        if ( $r_fn =~ m/\.(jpg|jpeg)$/ ) {
	        	$img->save_jpeg($args->{-save_file_path});
	        }
	        elsif ( $r_fn =~ m/\.(gif)$/ ) {
	        	$img->save_png($args->{-save_file_path});
	        }
	        elsif ( $r_fn =~ m/\.(png)$/ ) {
	        	$img->save_png($args->{-save_file_path});
	        }
		
			return (1, $args->{-save_file_path}); 
		
		}
		else {
			return(0, $args->{-file_path});
		}
	} catch { 
		warn $_; 
		return (0, $args->{-file_path}); 
	};	
	
}


1;