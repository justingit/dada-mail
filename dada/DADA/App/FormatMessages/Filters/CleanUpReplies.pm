package DADA::App::FormatMessages::Filters::CleanUpReplies;
use strict; 

use lib qw(
	../../../../
	../../../../DADA/perllib
); 

use vars qw($AUTOLOAD); 
use DADA::Config qw(!:DEFAULT);

use Carp qw(croak carp); 
use HTML::LinkExtor; 
use URI::file; 
use URI; 

# Need to ship with: 
use DADA::App::Guts; 

my $t = 0; 
my %allowed = (
	placeholder => 'DADAPLACEHOLDER',
);

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my $args = (@_); 
    
   $self->_init($args); 
   return $self;

}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}





sub _init  {

	my $self    = shift; 
	my ($args)  = @_;
	
}




sub filter { 
	my $self   = shift; 
	my ($args) = @_;
	
	if(! exists($args->{-type} )) { 
		croak "you MUST pass the, '-type' parameter!"; 
	}
	if(! exists($args->{-list} )) { 
		croak "you MUST pass the, '-list' parameter!"; 
	}

	if($args->{-type} eq 'text/html') { 
		return $self->for_html($args); 
	}
	elsif($args->{-type} eq 'text/plain') {
		return $self->for_plaintext($args); 
	}
}




sub for_html { 

	my $self   = shift; 
	my ($args) = @_;
	my $o_ogb = quotemeta('<!--opening-->'); 
	my $o_oge = quotemeta('<!--/opening-->'); 

	my $s_ogb = quotemeta('<!--signature-->'); 
	my $s_oge = quotemeta('<!--/signature-->');

	$args->{-msg} =~ s/$o_ogb(.*?)$o_oge//smg;
	$args->{-msg} =~ s/$s_ogb(.*?)$s_oge//smg;
	return $args->{-msg};
}




sub for_plaintext { 
	my $self   = shift; 
	my ($args) = @_; 
	my $msg = $args->{-msg}; 
	
	# First, we need to grab the current PlainText Mailing List Message. 
	# This could potentially use the default if, '-list' isn't passed, but 
	# we're requiring that, at the moment. 
	my $list = $args->{-list}; 
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list});
	my $og_msg = $ls->param('mailing_list_message'); 

	my $msg_body_tag = quotemeta('<!-- tmpl_var message_body -->'); 
	return $args->{-msg}
		if $og_msg !~ m/$msg_body_tag/;
	
	my $og_opener = $self->_get_opener($og_msg); 

	my $opener_regex = $self->_tags_to_placeholders(
							$self->_mock_quoted_text(
								$self->_get_opener(
									$og_msg
								)
							)
						);
	


		$opener_regex    = quotemeta($opener_regex); 
		my $match        = '(.*?)'; 
		my $ph           = $self->placeholder;
		$opener_regex    =~ s/$ph/$match/g; 
		$msg             =~ s/$opener_regex//;
		$msg             = $self->_remove_quoted_sig($msg);
		 
		#carp 'now looks like this:' . "\n$msg\n";
		if(defined(strip($msg))){ 
			return $msg; 
		}
		else { 
			return $args->{-msg};
		}
}
sub _get_opener { 
	my $self = shift; 
	my $str  = shift; 
	my $mbt = quotemeta('<!-- tmpl_var message_body -->'); 
	
	my @l   = split(/\n/, $str);
	my $r    = undef; 

	my $s       = 0; 
	
	 for my $l(@l){
	 	chomp($l); 
	
		$r .= $l . "\n";
		if($l =~ m/^__ $/){ 
			last
		}
		if($l =~ m/$mbt/) { 
			last;
		} 
	}
	return $r;
}

# Not used? 
sub _get_sig { 
	my $self = shift; 
	my $str  = shift; 
	my $mbt = quotemeta('<!-- tmpl_var message_body -->'); 
	
	my @l   = split(/\n/, $str);
	my $r    = undef; 

	my $s       = 0; 
	
	 for my $l(@l){
	 	chomp($l); 
		if($s == 1){ 
			$r .= $l . "\n";
		}
		if($l =~ m/^-- $/){ 
			$s = 1;
		}
		if($l =~ m/$mbt/){
		}
	}
	return $r;	
}

sub _tags_to_placeholders { 
	my $self = shift; 
	my $str  = shift;
	
	my $b1  = quotemeta('<!--');
    my $e1  = quotemeta('-->');

    my $b2 = quotemeta('<');
    my $e2 = quotemeta('>');

    my $b3 = quotemeta('[');
    my $e3 = quotemeta(']');

 	my $ph = $self->placeholder; 

	$str =~ s{$b1(\s*tmpl_(.*?)\s*)($e1|$e2)}{$ph}gi;
	$str =~ s{$b2(\s*tmpl_(.*?)\s*)($e1|$e2)}{$ph}gi;

	$str =~ s{$b1(\s*/tmpl_(.*?)\s*)($e1|$e2)}{$ph}gi;
	$str =~ s{$b2(\s*/tmpl_(.*?)\s*)($e1|$e2)}{$ph}gi;

	return $str; 
	
}

sub _mock_quoted_text { 
	my $self = shift; 
	my $str  = shift; 
	my $r    = shift; 
	my $qs   = '> ';
	my @l = split("\n|\r", $str);
	foreach(@l){
		chomp;  		
		$r .= $qs.$_ . "\n";
	}
	return $r; 
}


sub _remove_quoted_sig { 
	# The idea is that we basically remove any quoted replies, 
	# Until we get to the first sig mark (that's also quoted. 
	# Then, we just keep anything afterwards. 
	my $self = shift; 
	my $str  = shift; 
	my @l    = split("\n|\r", $str); 
	   @l    = reverse @l;
	my @r    = (); 
	my $free = 0; 
	 foreach my $l(@l) { 
		chomp($l); 
		
		# after we found the sig mark?  
		if($free == 1){ 
			push(@r, $l);
		}
		# Not a quote? 
		elsif($l !~ m/\>\s(.*?)/){ 
			push(@r, $l);
		}
		if($l =~ m/\>\s--\s/) { 
			$free = 1; 	
		}
	}
	my $r = join("\n", reverse(@r)); 
	if(length($r) > 10){ 
		return $str; 
	}
}


sub DESTROY { 
	
}


1;