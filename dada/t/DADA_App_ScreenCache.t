#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

use Test::More qw(no_plan);  


use DADA::Config; 
use DADA::App::ScreenCache; 

# enable it for our tests; 
$DADA::Config::SCREEN_CACHE = 1; 

my $c = DADA::App::ScreenCache->new;

ok(defined $c,                        'new() returned something, good!' );
ok( $c->isa('DADA::App::ScreenCache'),   "  and it's the right class" );

ok($c->cache_dir eq $DADA::Config::TMP  . '/_screen_cache', "dir is giving back the right dir"); 

#cache something; 
my $filename       = 'something.txt'; 
my $something      = 'something' . $dada_test_config::UTF8_STR; 		# test with a UTF-8 string!
my $something_else = 'something_else' . $dada_test_config::UTF8_STR;    # test with a UTF-8 string! 

ok($c->cache($filename, \$something) == 1, "caching worked!"); 
ok($c->cached($filename)             == 1, "reporting that it is cached."); 
ok($c->cached('bs.txt')              == 0, "but this one doesn't really exist."); 

# What happens when we cache the same file, twice? 
ok($c->cache($filename, \$something_else) == 1, "caching worked for the same file!"); 
ok($c->cached($filename)             == 1, "reporting that it is cached(2)."); 
ok($c->pass($filename) eq $something_else, "got content back!");

# well, good, we know that works, let's put that stuff back: 
ok($c->cache($filename, \$something) == 1, "caching worked(3)!"); 


# let's get it back: 
ok($c->pass($filename) eq $something, "got content back!");

# Let's remove it: 
ok($c->remove($filename) == 1, "removed went A-OK!"); 
ok($c->remove($filename) == 0, "Trying to remove this file twice doesn't work!"); 
 

# Still more to do... 

#dada_test_config::remove_test_list;
dada_test_config::wipe_out;


sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}


