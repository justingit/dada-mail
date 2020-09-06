#!/usr/bin/perl -w
use strict; 


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
	'Type' => 'image/gif',
	Path => './small_image.gif',
	Id    => 'blahblahbalh',
);
$mr_entity->add_part($html); 
$mr_entity->add_part($img); 

$tl_entity->add_part($pt_entity); 
$tl_entity->add_part($mr_entity); 






my $str = $tl_entity->as_string; 

#print $str; 

#use MIME::Parser; 
#
#my $parser = new MIME::Parser; 
#   $parser->output_to_core(1); 

sub replace_images { 
	
	my $entity = shift; 
	
	if($entity->head->mime_type eq 'multipart/alternative'){ 
	
		my @parts = $entity->parts; 
		my @new_parts = (); 
	
		for my $s_e(0 .. $#parts){
		
			my $new_entity = $parts[$s_e];

			if($new_entity->head->mime_type eq 'multipart/related'){ 
				$new_entity = replace_images_loop($new_entity); 
			}
			push(@new_parts, $new_entity);
		}
		$entity->parts(\@new_parts); 
	}
}
sub replace_images_loop { 
	
	my $entity = shift; 
	
	my @parts  = $entity->parts; 
    
    if(@parts){
        my $i; 
        foreach $i (0 .. $#parts) {
            $parts[$i] = replace_images($parts[$i]);    

        }
        
		$entity->sync_headers('Length'      =>  'COMPUTE',
                              'Nonstandard' =>  'ERASE');
		$entity->parts( \@parts );
    }
	else { 
        if($entity->head->mime_type eq 'image/gif'){ 
			
			my $new_entity = MIME::Entity->build(
				'Type' => 'image/gif',
				Path => './it_worked.gif',
				Filename => 'small_image.gif',
				Id       => 'blahblahbalh',
			);
			
			$entity = $new_entity;
        }
        return $entity; 
    }
    return $entity; 
}


