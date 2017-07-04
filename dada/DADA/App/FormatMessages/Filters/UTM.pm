package DADA::App::FormatMessages::Filters::UTM; 

use v5.10;

use URI::URL;
use URI::QueryParam;
use URI::Find;
use Try::Tiny; 

require Exporter;
#@ISA    = qw(Exporter);
#@EXPORT = qw();
use vars qw(@EXPORT $AUTOLOAD);

use Carp qw(carp croak);
use strict;
my %allowed = (
	domains => undef, 
	utm => {
		source   => undef, 
		medium   => undef, 
		campaign => undef, 
		term     => undef, 
		content  => undef, 
	},
);

my $t = 1; 


sub new {

	warn 'new' if $t; 
	
    my $that = shift;
	
	
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;
    my ($args) = @_;
	
	use Data::Dumper; 
	warn Dumper($args);
	
	
	$self->_init($args);
	
	return $self; 

}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

	return if(substr($AUTOLOAD, -7) eq 'DESTROY');

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {
	
	warn 'init' if $t; 
	

    my $self = shift;
    my ($args) = @_;
	
	$self->utm($args->{-utm}); 
	$self->domains($args->{-domains});
}

sub filter { 
	
	warn 'filter' if $t; 
	my $self = shift; 
	my ($args) = @_; 
	
	if($args->{-type} =~ m/html/){ 
		
		warn 'HTML!' if $t; 
		
		return $self->add_utm_html($args->{-data}); 
	}
	else { 
		warn 'Text!' if $t; 
		
		return $self->add_utm_text($args->{-data}); 
	}
}



sub add_utm_html { 


	my $self   = shift;
	my $s      = shift; 

	
	require HTML::Tree;
	require HTML::Element;
	require HTML::TreeBuilder;

	my $tree = HTML::TreeBuilder->new(
	    ignore_unknown      => 0,
	    no_space_compacting => 1,
	    store_comments      => 1,
		no_expand_entities => 1, 
		# ignore_ignorable_whitespace
		# no_space_compacting
	);

	$tree->parse($s);
	$tree->eof();
	#$tree->elementify();

	my @a_tags = $tree->look_down( '_tag' , 'a' );
	for my $t(@a_tags){
		
		my %attrs = $t->all_attr(); 
		
		next if $attrs{href} =~ m/\<\!\-\-/;
		next if $attrs{href} =~ m/\<\?/;
		
		
		# print $attrs{href} . "\n";
		
		warn '$t->as_text' . $t->as_text; 
		my %utms = (
			term => $self->strip($t->as_text),	
		);
	
		
		for(qw(source medium campaign term content)){ 
			if(exists($attrs{'data-utm_'. $_})){ 
				$utms{$_} = $attrs{'data-utm_'. $_};
			}
		}
		
		my $utmd = $self->add_utm_to_url(
			{ 
				-url => $attrs{href}, 
				-utm => {%utms}
			}
			); 
		
		
		$t->attr('href', $utmd);
	}

	$s = $tree->as_HTML( undef, '  ' );
	$tree->delete;

	return $s; 


}

=cut
sub add_utm_html_old { 
	my $self   = shift;
	my $s      = shift; 
	my $og      = $s; 
	
	try { 
		require URI::Find; 
		require HTML::LinkExtor;
	} catch { 
		warn "Cannot auto redirect links. Missing perl module? $_"; 
		return $s; 
	};
	
	
	my @links_to_look_at = (); 
	my $callback = sub {
	     my($tag, %attr) = @_;     
		# Supported: <a href=""> and <area href=""> 
		return 
			unless $tag eq 'a' || $tag eq 'area'; 
			
		 my $link =  $attr{href}; 
		
		if($link =~ m/^mailto\:/) { 
			# skipping
		}
		elsif($link =~ m/(^(\<\!\-\-|\[|\<\?))|((\]|\-\-\>|\?\>)$)/){ 
			# skipping
		}
		else { 
			warn 'pushing: ' . $link if $t; 
			push(@links_to_look_at, $link);	
		}
		
		if($link =~ m/\&/){ 
			# There's some weird stuff happening in HTML::LinkExtor, 
			# Which will change, "&amps;" back to, "&", probably due to 
			# A well-reasoned... reason. But it still breaks shit. 
			# So I look for both: 

			my $ampersand_link = $link; 
			   $ampersand_link =~ s/\&/\&amp;/g;
			push(@links_to_look_at, $ampersand_link); 

		}
	};

    my $p = HTML::LinkExtor->new( $callback );
       $p->parse($s);
	undef $p; 

	if($t) { 
		require Data::Dumper; 
		warn 'Links Found:' . Data::Dumper::Dumper([@links_to_look_at]); 
	}
	
	foreach my $single_link(@links_to_look_at){ 
		my $utmed_link = $self->add_utm_to_url(
			{ 
				-url => $single_link,
			}
		); 
		warn '$utmed_link: ' . $utmed_link
		 if $t; 
	
		my $qm_link         = quotemeta($single_link);
		warn '$single_link: "' . $single_link . '"'
			if $t; 
		warn '$qm_link: "' . $qm_link . '"'
			if $t; 
		
		# This line is suspect - it only works with double quotes, ONLY looks at the first (?) 
		# double quote and doesn't use any sort of API from HTML::LinkExtor. 
		# 
		# Also see that we don't get rid of dupes in @links_to_look_at, and this regex is not global. 
		# If you do one do the other, 
		$og =~ s/(href(\s*)\=(\s*)(\"?|\'?))$qm_link/$1$utmed_link/;
		
	}

    $s  = $og;

	@links_to_look_at = (); 
	$og = undef; 
	
	return $s; 
	
}
=cut


sub add_utm_text { 
	
	my $self = shift; 
	my $s    = shift; 

	
	
	#require DADA::Security::Password; 
	
	# Find me the URLs in this string!
	my @uris;
	my $finder = URI::Find->new(sub {
	    my($uri) = shift;
		push(@uris, $uri->as_string);
		warn '$uri: ' . $uri
		 if $t;
		return $uri; 
	});
	$finder->find(\$s);
		
	my $links = [];
	
	# Get only unique URLS: 
	my %seen;
	my @unique_uris = grep { ! $seen{$_}++ } @uris;
	# Sort by longest, to shortest: 
	@unique_uris = sort {length $b <=> length $a} @unique_uris;
	
	
	for my $specific_url(@unique_uris){ 
		

		push(@$links,
				{ 
					orig   => $specific_url, 
					utmd   => $self->add_utm_to_url({ -url => $specific_url}), 
					regex  => quotemeta($specific_url), 
				},
			); 
		
	}
	
	# Switch 'em out so my regex is...somewhat simple: 
	my %out_of_the_way; 

	# DADA::Security::Password::
	for my $l(@$links){ 
		my $key = '_UTM_TMP_' . $self->generate_rand_string('1234567890abcdefghijklmnopqestuvwxyz', 16) . '_UTM_TMP_'; 
		$out_of_the_way{$key} = $l; 
		my $qm_l = $l->{regex}; 
		$s =~ s/$qm_l/$key/g; 
	}

=cut
	
#	warn '$s:' . $s; 
	
	for my $specific_url(@unique_uris){ 
		warn '$specific_url ' . $specific_url
			if $t; 
		if(
			$specific_url =~ m/mailto\:/ 
		){
		    # ... skip  
		}
		else { 
			my $qm_link    = quotemeta($specific_url); 
			my $utmd = $self->add_utm_to_url($specific_url);
			warn '$utmd ' . $utmd
				if $t;
			# (somewhat simple regex) 
			$s =~ s/$qm_link/$utmd/g;
			
		}
	}
	
=cut
	
	for (keys %out_of_the_way){ 
		my $str = $out_of_the_way{$_}->{utmd}; 
		$s =~ s/$_/$str/g; 
	}
	
	return $s; 
	

}

sub generate_rand_string { 

	my $self = shift; 
	
	my $chars = shift || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
	my $num   = shift || 8;
   
	my @chars = split '', $chars;
	 my $password;
	      for(1..$num){
	      $password .= $chars[rand @chars];
	         }
	      return $password; 
}

sub add_utm_to_url { 
	
	warn 'add_utm_to_url'
		if $t; 
	
	my $self     = shift;
	my ($args)   = @_; 
	
	my $og_url   = $args->{-url};
	my $alt_utms = $args->{-utm};
	
	my @domains = (); 
	my $domains = {}; 
	
	if(defined($self->domains())){
		# warn 'defined($self->domains()';
		@domains = split(/\s+/, $self->domains());
		for(@domains){ 
			next if $_ eq ''; 
			next if length($_) <= 3; 
			$domains->{$_} = 1; 
		} 
	}
	else { 
		# warn 'undefined($self->domains()';
	}
	
	
#	use Data::Dumper; 
#	warn '$domains!' . Dumper($domains);
	my $url = new URI::URL $og_url; 
	
	if(keys %$domains){
		return $og_url if ! exists($domains->{$url->host});
	}
	else { 
		# everything should work!
	}	
	
	my $default_utm = $allowed{utm};
	my $custom_utm = $self->utm();  

	for(keys %{$custom_utm}){ 
		if(exists $alt_utms->{$_}){ 
			$custom_utm->{$_} = $alt_utms->{$_};
		}
	}

	if($og_url =~ m/\?/){
		for my $key ($url->query_param) {
	
#			warn '$key' . $key; 
			my $lu_key = $key; 
			   $lu_key =~ s/^utm_//; 
	
			if(exists($custom_utm->{$lu_key})){
				#warn '$custom_utm->{$lu_key}' . $custom_utm->{$lu_key}; 
				#warn '$url->query_param($key)'. $url->query_param($key); 
				$custom_utm->{$lu_key} = $url->query_param($key);
			}
			
		}
	}

	for(keys %{$custom_utm}){ 
		next 
			if ! defined($custom_utm->{$_});
		next 
			if  length($custom_utm->{$_}) <= 0;
		$url->query_param( 'utm_' . $_, $custom_utm->{$_} );
	}
	my $custom_url = $url->abs->as_string;  
	undef $url; 
	return $custom_url; 
	


}

sub strip {
	my $self = shift; 
    my $string = shift;
    if (defined($string)) {
        $string =~ s/^\s+//o;
        $string =~ s/\s+$//o;
        return $string;
    }
    else {
        return undef;
    }
}




sub DESTROY {}
1;