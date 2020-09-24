#!/usr/bin/perl -w

my $t = 1; 



use strict; 
use v5.10; 


use Carp; 
$Carp::Verbose = 1; 


my $image_upload_dir = 'image_tmp' ;

use MIME::Entity; 
use MIME::Parser; 


my $tl_entity = MIME::Entity->build(
	Type => 'multipart/alternative', 			
); 

my $mr_entity = MIME::Entity->build(
	Type => 'multipart/related', 			
); 

my $html = MIME::Entity->build(
'Type'     => 'text/html',
Data => 'HTML! <img src="cid:blahblahbalh">',
);
my $pt_entity =  MIME::Entity->build(
'Type'     => 'text/plain',
Data => 'plaintext',
);

my $img = MIME::Entity->build(
	'Type' => 'image/jpg',
	Path => './big.jpg',
	Id    => 'blahblahbalh',
);


#my $imgtwo = MIME::Entity->build(
#	'Type' => 'image/gif',
#	Path => './another_image.gif',
#	Id    => 'blahblaadfsdahbalh',
#);


$mr_entity->add_part($html); 
$mr_entity->add_part($img); 
#$mr_entity->add_part($imgtwo); 

$tl_entity->add_part($pt_entity); 
$tl_entity->add_part($mr_entity); 

$tl_entity = replace_images($tl_entity);

my $str = $tl_entity->as_string; 

print $str; 

#use MIME::Parser; 
#
#my $parser = new MIME::Parser; 
#   $parser->output_to_core(1); 



#use Image::Scale;
## Resize to 150 width and save to a file
#my $rimg = Image::Scale->new('big.jpg') || die "Invalid JPEG file";
#$rimg->resize_gd( { width => 100 } );
#$rimg->save_jpeg($image_upload_dir . '/resized.jpg');


sub replace_images { 
	
	say 'in replace_images';
	
	my $entity = shift; 
	
	if($entity->head->mime_type eq 'multipart/alternative'){ 
	
		say "multipart/alt";
		
		my @parts = $entity->parts; 
		my @new_parts = (); 
	
		for my $s_e(0 .. $#parts){
			
			
		
			my $new_entity = $parts[$s_e];

			if($new_entity->head->mime_type eq 'multipart/related'){ 
				
				say 'multipart/related'; 
				
				$new_entity = replace_images_loop($new_entity); 
			}
			push(@new_parts, $new_entity);
		}
		$entity->parts(\@new_parts); 
	}
	return $entity; 
}
sub replace_images_loop { 
	
	say 'in replace_images_loop'; 
	
	my $entity = shift; 
	
	my @parts  = $entity->parts; 
    
    if(@parts){
        my $i; 
        foreach $i (0 .. $#parts) {
            $parts[$i] = replace_images_loop($parts[$i]);    

        }
        
		$entity->sync_headers('Length'      =>  'COMPUTE',
                              'Nonstandard' =>  'ERASE');
		$entity->parts( \@parts );
    }
	else { 
        if($entity->head->mime_type eq 'image/jpg'){ 
			
			my $new_entity = resized_image_entity($entity); 			
			$entity = $new_entity;
        }
        return $entity; 
    }
    return $entity; 
}

sub resized_image_entity { 
	
	my $entity = shift; 
	
	my $type = $entity->mime_type;
#	my $bh   = $entity->bodyhandle;

	#use Data::Dumper; 
	#warn Dumper($entity);

 	my $og_fn = $entity->head->mime_attr("content-disposition.filename") || 'random_name.gif';

	
	my $og_saved_fn  = $image_upload_dir . '/' . 'orig-' . $og_fn;
	my $new_saved_fn = $image_upload_dir . '/' . 'new-' . $og_fn;
	
	if (defined $entity->bodyhandle) {
	    open(my $OUTFILE, ">", $og_saved_fn) or die $!;
	    binmode($OUTFILE);
		print $OUTFILE $entity->bodyhandle->as_string;
	    close($OUTFILE);
	}

	resize_image(
		{ 
			-width          => 10, 
			-file_path      => $og_saved_fn, 
			-save_file_path => $new_saved_fn, 
		}	
	);
	
	
    my $n_entity = new MIME::Entity->build(
 
		Path          => $new_saved_fn, 
		Encoding      => 'base64',
		Disposition   => "inline",
		Type          => 'image/jpg', 	
		#Filename     => $filename,  
    );

	return $n_entity; 

}




sub resize_image { 

	say "in resize_image";
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
	
	require Image::Scale;
	
	my $img = Image::Scale->new($args->{-file_path}) || die "Invalid file: " . $args->{-file_path};
	my $w = $img->width; 
	
	# This needs to be figured out for real, as we don't want paths like, 
	#
	# /home/user/blah.jpg/some/where/else/image.gif
	
	my $r_fn = $args->{-file_path}; 
	
    if ($w > $args->{-width} ) {
       
		my $h   = $img->height;
        my $n_w = $args->{-width};
        #my $n_h = int( ( int($n_w) * int($h) ) / int($w) ); # not needing for this module. 

        $img->resize_gd( 
			{ 
				width  => $n_w, 
				#height => $n_h
			} 
		);
		
        if ( $r_fn =~ m/\.(jpg|jpeg)$/ ) {
			
			say "saving at, " . $args->{-save_file_path}; 
        	$img->save_jpeg($args->{-save_file_path});
        }
        elsif ( $r_fn =~ m/\.(gif)$/ ) {
        	$img->save_png($args->{-save_file_path});
        }
        elsif ( $r_fn =~ m/\.(png)$/ ) {
        	$img->save_png($args->{-save_file_path});
        }
		
		return $args->{-save_file_path}
		
	}
	else {
		return $args->{-file_path}
	}
	
	
	
}



