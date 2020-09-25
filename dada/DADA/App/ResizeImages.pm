package DADA::App::ResizeImages; 

use lib qw(../../ ../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 
use Carp qw(carp croak);
use Try::Tiny; 

require Exporter; 
@ISA = qw(Exporter); 

use strict; 
use vars qw(@EXPORT); 
@EXPORT = qw(); 



my $t = 0; 


sub resize_image { 

	my ($args) = @_; 
	
	if($t){ 
		require Data::Dumper; 
		warn 'args: ' . Data::Dumper::Dumper($args);
	}
	
	my $can_use_Image_Scale = 0; 
	my $img_scale_obj       = undef; 
	my $img_scale_error     = undef; 
	try { 
		
		# We do it this way, as Image::Scale may be available,
		# but not built for say, .gif (WTF?)
		#
		
		require Image::Scale;
		$img_scale_obj = Image::Scale->new($args->{-file_path}) 
			|| die "Invalid file: " . $args->{-file_path};
		$can_use_Image_Scale = 1; 
	} catch { 
		# ... 
		warn $_; 
	};
	
	if($can_use_Image_Scale == 1){ 
		$args->{image_scale_obj} = $img_scale_obj;
		return resize_image_via_Image_Scale($args);
	}
	else {
		return (0, $args->{-file_path}, undef, undef); 
	}
}
	
sub resize_image_via_Image_Scale { 	

	my ($args) = @_; 
	my $img = undef; 
	if(!exists($args->{image_scale_obj})){ 
		croak "you need to pass the image_scale_obj!";
	}
	else { 
		$img = $args->{image_scale_obj};
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
		# my $img = Image::Scale->new($args->{-file_path}) || die "Invalid file: " . $args->{-file_path};
		my $w = $img->width; 
	
		my $r_fn = filename_from_url($args->{-file_path}); 
	
	    if ($w > $args->{-width} ) {
       
			my $h   = $img->height;
	        my $n_w = $args->{-width};
	        my $n_h = int( ( int($n_w) * int($h) ) / int($w) ); # not needing for this module. 

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
		
			return (1, $args->{-save_file_path}, $n_w, $n_h); 
		
		}
		else {
			return(0, $args->{-file_path}, $img->width, $img->height);
		}
	} catch { 
		warn $_; 
		return (0, $args->{-file_path}, undef, undef); 
	};	
	
}


1;