#!/usr/bin/perl 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
use Test::More;

eval "use Test::HTML::Lint qw(no_plan)";
plan skip_all => "Test::HTML::Lint required for testing Templates." if $@;

use HTML::Template::Expr; 




my $dir = 'DADA/Template/templates'; 

#Work on this one later...
# archive_screen.tmpl


my @files = (); 

my $file;
	
	
opendir(TMPL, $dir) or die "can't open '$dir' to read: $!";

while(defined($file = readdir TMPL)) {
    #don't read '.' or '..'
    next if $file =~ /^\.\.?$/; 

    if($file =~ m{(\.tmpl|\.widget)}){ 
    
		# Wait. Why am I skipping these?
        next if $file =~ m{rss-2_0.tmpl}; 
        next if $file =~ m{atom-1_0.tmpl}; 
        next if $file =~ m{admin_js.tmpl}; 
        next if $file =~ m{unsubscription_check_xml.tmpl}; 
        next if $file =~ m{subscription_check_xml.tmpl}; 

        push(@files, $file);
    }


     
 }






foreach my $test_file(@files){ 


	html_ok( strip_comments(open_file($dir . '/' . $test_file)), $test_file);
    
   
	eval { 
    my $template = HTML::Template::Expr->new(path => $dir,
    		                                 die_on_bad_params => 0,	
		                                     loop_context_vars => 1,
		                                     filename          => $test_file, 
		                                    );		                              
    $template->output();  

};
ok(! $@, "$test_file through HTML::Template::Exp"); 
    if($@){ 
        diag($@); 
    }
    
	undef $template; 
		
}




sub open_file { 

    my $fn = shift; 
    die "no fn!  " if ! $fn; 
    
    open my $file, '<', $fn or die; 
    my $info = do { local $/; <$file> };
    close $file or die; 
    
    return $info; 
    

}


sub strip_comments { 

    # *very* old code: 
    
    my $html = shift; 
    

$html =~ s{ <!                   # comments begin with a `<!'
                            # followed by 0 or more comments;

        (.*?)           # this is actually to eat up comments in non 
                            # random places

         (                  # not suppose to have any white space here

                            # just a quick start; 
          --                # each comment starts with a `--'
            .*?             # and includes all text up to and including
          --                # the *next* occurrence of `--'
            \s*             # and may have trailing while space
                            #   (albeit not leading white space XXX)
         )+                 # repetire ad libitum  XXX should be * not +
        (.*?)           # trailing non comment text
       >                    # up to a `>'
    }{
        if ($1 || $3) { # this silliness for embedded comments in tags
            "<!$1 $3>";
        } 
    }gesx;                 # mutate into nada, nothing, and niente
    
return $html; 

}

