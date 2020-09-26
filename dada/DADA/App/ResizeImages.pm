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

    if ($t) {
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
        $img_scale_obj = Image::Scale->new( $args->{-file_path} )
          || die "Invalid file: " . $args->{-file_path};
        $can_use_Image_Scale = 1;
    }
    catch {
        # ...
        warn $_;
    };

    if ( $can_use_Image_Scale == 1 ) {
        $args->{-image_scale_obj} = $img_scale_obj;
        return resize_image_via_Image_Scale($args);
    }
	
    my $can_use_Image_Resize = 0;
    my $img_resize_obj       = undef;
    my $img_resize_error     = undef;	
	
    try {

        # We do it this way, as Image::Scale may be available,
        # but not built for say, .gif (WTF?)
        #
        require Image::Resize;
        $img_resize_obj = Image::Resize->new( $args->{-file_path} )
          || die $_; 
        $can_use_Image_Resize = 1;
    }
    catch {
        # ...
        warn $_;
    };
	
    if ( $can_use_Image_Resize == 1 ) {
        $args->{-image_resize_obj} = $img_resize_obj;
        return resize_image_via_Image_Resize($args);
    }
	
	

	
	
	
    my $can_use_Image_Magick = 0;
    my $img_magick_obj       = undef;
    my $img_magick_obj_error     = undef;	
	
    try {

        # We do it this way, as Image::Scale may be available,
        # but not built for say, .gif (WTF?)
        #
        require Image::Magick;
        $img_magick_obj = Image::Magick->new()
          || die $_; 
        $can_use_Image_Magick = 1;
    }
    catch {
        # ...
        warn $_;
    };
	
    if ( $can_use_Image_Magick == 1 ) {
        $args->{-image_magick_obj} = $img_magick_obj;
        return resize_image_via_Image_Magick($args);
    }

	
	
	
	
	
	

	return ( 0, $args->{-file_path}, undef, undef );
}

sub resize_image_via_Image_Scale {

    my ($args) = @_;
    my $img = undef;
    if ( !exists( $args->{-image_scale_obj} ) ) {
        croak "you need to pass the -image_scale_obj!";
    }
    else {
        $img = $args->{-image_scale_obj};
    }

    if ( !exists( $args->{-file_path} ) ) {
        croak "you need to pass, -file_path";
    }

    if ( !exists( $args->{-width} ) ) {
        croak "you need to pass, -width";
    }
	
    try {

        my $w = $img->width;
        if ( $w > $args->{-width} ) {

            my ( $u_path, $u_filename ) = path_and_file( $args->{-file_path} );
            my $new_file_path =
              new_image_file_path( $u_path . '/' . 'resized-' . $u_filename );
            make_safer($new_file_path);

            my $h   = $img->height;
            my $n_w = $args->{-width};
            my $n_h = int( ( int($n_w) * int($h) ) / int($w) )
              ;    # not needing for this module.

            $img->resize_gd(
                {
                    width => $n_w,

                    #height => $n_h
                }
            );
			
            if ( $u_filename =~ m/\.(jpg|jpeg)$/ ) {
                $img->save_jpeg($new_file_path);
            }
            elsif ( $u_filename =~ m/\.(gif)$/ ) {
                $img->save_png($new_file_path);
            }
            elsif ( $u_filename =~ m/\.(png)$/ ) {
                $img->save_png($new_file_path);
            }

            return ( 1, $new_file_path, $n_w, $n_h );

        }
        else {
            return ( 0, $args->{-file_path}, $img->width, $img->height );
        }
    }
    catch {
        warn $_;
        return ( 0, $args->{-file_path}, undef, undef );
    };
}




sub resize_image_via_Image_Resize {

    my ($args) = @_;
    my $img = undef;
    if ( !exists( $args->{-image_resize_obj} ) ) {
        croak "you need to pass the -image_resize_obj!";
    }
    else {
        $img = $args->{-image_resize_obj};
    }

    if ( !exists( $args->{-file_path} ) ) {
        croak "you need to pass, -file_path";
    }

    if ( !exists( $args->{-width} ) ) {
        croak "you need to pass, -width";
    }
	
    try {

        my $w = $img->width;
        if ( $w > $args->{-width} ) {

            my ( $u_path, $u_filename ) = path_and_file( $args->{-file_path} );
            my $new_file_path =
              new_image_file_path( $u_path . '/' . 'resized-' . $u_filename );
            make_safer($new_file_path);

            my $h   = $img->height;
            my $n_w = $args->{-width};
            my $n_h = int( ( int($n_w) * int($h) ) / int($w) );
        
            $img->resize($n_w, $n_h);
			require File::Slurper; 
			
            if ( $u_filename =~ m/\.(jpg|jpeg)$/ ) {
		        File::Slurper::write_binary( $new_file_path, $img->jpeg($new_file_path) );
            }
            elsif ( $u_filename =~ m/\.(gif)$/ ) {
		        File::Slurper::write_binary( $new_file_path, $img->gif($new_file_path) );
            }
            elsif ( $u_filename =~ m/\.(png)$/ ) {
		        File::Slurper::write_binary( $new_file_path, $img->png($new_file_path) );
            }

            return ( 1, $new_file_path, $n_w, $n_h );

        }
        else {
            return ( 0, $args->{-file_path}, $img->width, $img->height );
        }
    }
    catch {
        warn $_;
        return ( 0, $args->{-file_path}, undef, undef );
    };
}





sub resize_image_via_Image_Magick {

	warn 'in resize_image_via_Image_Magick'
		if $t; 
	
    my ($args) = @_;
    my $img = undef;
    if ( !exists( $args->{-image_magick_obj} ) ) {
        croak "you need to pass the -image_resize_obj!";
    }
    else {
        $img = $args->{-image_magick_obj};
    }

    if ( !exists( $args->{-file_path} ) ) {
        croak "you need to pass, -file_path";
    }

    if ( !exists( $args->{-width} ) ) {
        croak "you need to pass, -width";
    }
	
    try {
		
		my ($w, $h, $size, $format) = $img->Ping($args->{-file_path});
		
		if($t){
			require Data::Dumper; 
			warn Data::Dumper::Dumper(
			{ 
				w => $w, 
				h => $h, 
				size => $size, 
				'format' => $format, 
			}
				
			);
		}
		
		if ( $w > $args->{-width} ) {

            my ( $u_path, $u_filename ) = path_and_file( $args->{-file_path} );
            my $new_file_path = new_image_file_path( $u_path . '/' . 'resized-' . $u_filename );
            make_safer($new_file_path);
			
			my $error = $img->Read($args->{-file_path}); 
			die $error if $error;
			undef $error; 
		
            my $n_w = $args->{-width};
            my $n_h = int( ( int($n_w) * int($h) ) / int($w) );
        
			my ($max_height, $max_width) = ($n_w,$n_h);			
			my $error = $img->Resize(geometry => qq{${max_height}x${max_width}}); 
			die $error if $error; 
			undef $error; 
			
			my $error = $img->Write($new_file_path); 
			die $error if $error; 
			undef $error; 
			
            return ( 1, $new_file_path, $n_w, $n_h );

        }
        else {
            return ( 0, $args->{-file_path}, $img->width, $img->height );
        }
    }
    catch {
        warn $_;
        return ( 0, $args->{-file_path}, undef, undef );
    };
}




1;
