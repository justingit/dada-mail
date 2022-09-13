#!/usr/bin/perl -w
use strict; 

use Getopt::Long;
my $help         = 0; 
my $dry_run      = 0; 
my $run_tests    = 0; 
my $skip_perllib = 0; 
my $remove_tests = 0; 


Getopt::Long::GetOptions(
	"remove_tests"  => \$remove_tests,
	"help"          => \$help,
	"dry_run"       => \$dry_run, 
	"skip_perllib"  => \$skip_perllib, 
	
);
		

my $t = 1; 
my $HTML_CHARSET = 'utf-8';
my $FILE_CHMOD   = 0644;
my $DIR_CHMOD    = 0755;

use 5.010;

use Cwd qw(getcwd);
use File::Path qw(remove_tree);
use File::Copy; 
use File::Copy::Recursive qw(rmove dircopy);
use Carp qw(carp croak);

use LWP::Simple qw(getstore getprint); 


my $github_repos = { 
	perllib => {
		remote         => 'https://github.com/justingit/',
		repo           => 'dada-mail-perllib',
		branch         => 'main', 
		dir_name       => 'perllib',
		local_dir_path => 'DADA/perllib', 

	},
	ckeditor => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'ckeditor-for-dada-mail',
		branch         => 'main', 
		dir_name       => 'ckeditor',
		local_dir_path => 'extras/packages/ckeditor', 
	},
	tinymce => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'tiny_mce-for-dada-mail',
		branch         => 'main', 
		dir_name       => 'tinymce',
		local_dir_path => 'extras/packages/tinymce', 
	},
	kcfinder => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'kcfinder-for-dada-mail',
		branch         => 'main', 
		dir_name       => 'kcfinder',
		local_dir_path => 'extras/packages/kcfinder', 
	},
	core5_filemanager => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'core5-filemanager-for-dada-mail',
		branch         => 'bugfixes_post_11_19_0', 
		dir_name       => 'core5_filemanager',
		local_dir_path => 'extras/packages/core5_filemanager', 
	},
	RichFilemanager => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'RichFilemanager-for-dada-mail',
		branch         => 'upgrade_to_v2_7_6', 
		dir_name       => 'RichFileManager',
		local_dir_path => 'extras/packages/RichFileManager', 
	},
	
};

my $github_releases = {
	dada_mail_foundation_email_templates => { 
		url => 'https://github.com/justingit/dada_mail_foundation_email_templates/releases/download/v11_19_0-stable_2022_08_20/dada_mail_foundation_email_templates-11_19_0.tar.gz',
		filename       => 'dada_mail_foundation_email_templates-11_19_0.tar.gz',
		dir_name       => 'to_bundle',
		local_dir_path => 'extras/packages/themes/email', 		
	},	
};

my $maxmind_dbs =  { 
	remote         => 'https://github.com/justingit/',
	repo           => 'MaxMind-GeoIP-for-dada-mail',
	branch         => 'main', 
	country_db     => 'GeoIP.dat', 
	city_db        => 'GeoLiteCity.dat',
};


if($help){ 
	
	help();

}
else { 
	
	make_distro();
	
	if($remove_tests){ 
		remove_tests(); 
	}
	
	if(!$dry_run){
		md_create_distro(); 
	}
	
	clean_up(); 

}




sub help { 
	print "This is where the help goes.\n";
}




sub clean_up { 
	md_rmdir(
		'./tmp'
	); 
}




sub make_distro { 

	clean_up(); 

	md_rmdir(
		'./distribution'
	); 

	md_mkdir('./tmp', $DIR_CHMOD);
	md_dircopy('./app/dada', './tmp/dada'); 
	md_mkdir('./tmp/dada/extras/packages', $DIR_CHMOD);
	md_mkdir('./tmp/dada/extras/packages/themes', $DIR_CHMOD);

	md_rm('./tmp/dada/.gitignore'); 
	
	if(!$skip_perllib){
		md_pulldown_git_and_copy($github_repos->{perllib});
	}
	
	md_pulldown_git_and_copy($github_repos->{ckeditor});
	md_pulldown_git_and_copy($github_repos->{tinymce});
	md_pulldown_git_and_copy($github_repos->{kcfinder});
	md_pulldown_git_and_copy($github_repos->{core5_filemanager});
	md_pulldown_git_and_copy($github_repos->{RichFilemanager});

	md_email_template($github_releases->{dada_mail_foundation_email_templates}); 

	md_maxmind_dbs($maxmind_dbs); 

	md_copy_over_static_to_installer(); 
	
	md_copy_core_file_filemanager_pl(); 
	
	md_make_cl_installer_help_scrn(); 

	
}

sub remove_tests { 
	md_rmdir('./tmp/dada/t');
}


sub md_make_cl_installer_help_scrn { 
	`pod2text ./tmp/dada/extras/documentation/pod_source/install_dada_mail_cl.pod  > ./tmp/dada/installer-disabled/templates/cl_help_scrn.tmpl`;
}




sub md_copy_core_file_filemanager_pl { 

	md_cp(
	'./tmp/dada/extras/packages/core5_filemanager/connectors/pl/filemanager.pl'
	,
	'./tmp/dada/installer-disabled/templates/core5_filemanager-filemanager_pl.tmpl'
	); 
}







sub md_create_distro { 
	
	my $config = md_slurp('./tmp/dada/DADA/Config.pm'); 
	
	
	$config =~ m/\$VERSION \= (\d+\.\d+\.\d+);/gsmi;
	
	my $ver = $1;
	   $ver =~ s/\./_/gi;  
	
	chdir "./tmp";
	`tar -cvf dada_mail-$ver.tar dada`;
	`gzip dada_mail-$ver.tar`;
	
	chdir "../";
	
	md_mkdir(
		'./distribution', 
		$DIR_CHMOD
	); 
	
	md_cp(
		'./tmp/dada_mail-' . $ver . '.tar.gz'
		, 
		'./distribution/dada_mail-' . $ver . '.tar.gz'
	);
	
	md_cp(
		'./app/uncompress_dada.cgi'
		, 
		'./distribution/uncompress_dada.cgi'
	);
	
}



sub md_copy_over_static_to_installer { 
	
	md_mkdir(
		'./tmp/dada/installer-disabled/templates/static', 
		$DIR_CHMOD
	); 
	
	md_dircopy(
		'./tmp/dada/static/javascripts',
		'./tmp/dada/installer-disabled/templates/static/javascripts'
	);
	
	md_dircopy(
		'./tmp/dada/static/css',
		'./tmp/dada/installer-disabled/templates/static/css'
	);
	
	md_dircopy(
		'./tmp/dada/static/images',
		'./tmp/dada/installer-disabled/templates/static/images'
	);
	
		
}

sub md_maxmind_dbs { 
	my ($args) = @_; 

	chdir "./tmp";
	`git clone $args->{remote}/$args->{repo}.git`;
	chdir('./' . $args->{repo});
	`git checkout $args->{branch}`;
	chdir('../../'); # oh I'm sure that'll be work...
	
	md_mv(
		'./tmp/' 
		. $args->{repo} 
		.'/'
		. $args->{country_db}
		,
		'./tmp/dada/data/'
		. $args->{country_db},
		); 
	md_mv(
		'./tmp/' 
		. $args->{repo} 
		.'/'
		. $args->{city_db}
		,
		'./tmp/dada/data/'
		. $args->{city_db},
		); 	
	
	md_rmdir('./tmp/' . $args->{repo} );
}




sub md_email_template { 
	my ($args) = @_; 

	chdir "./tmp";
	getstore(
		$args->{url},
		$args->{filename},
	); 
	`tar -xvf $args->{filename}`;
	
	chdir "../";
	
	md_mvdir(
		'./tmp/' 
		. $args->{dir_name}
		,
		'./tmp/dada/'
		. 
		$args->{local_dir_path}
	); 
	
	md_rmdir('./tmp/' . $args->{dir_name} );
	md_rmdir('./tmp/' . $args->{filename} );
	
}
sub md_pulldown_git_and_copy { 
	
	my ($args) = @_; 
	
	chdir "./tmp";
	
	#`git clone $args->{remote}/$args->{repo}.git`;
	
	`git clone -b '$args->{branch}' --single-branch --depth 1 $args->{remote}/$args->{repo}.git`;
	
	#chdir('./' . $args->{repo});
	#`git checkout $args->{branch}`;
	
	chdir('../'); # oh I'm sure that'll be work...
	
	md_mv(
		'./tmp/' 
		. $args->{repo} 
		.'/'
		. $args->{dir_name}
		,
		'./tmp/dada/'
		. $args->{local_dir_path},
		); 
	md_rmdir('./tmp/' . $args->{repo} );
	
}




sub md_write_file { 

    my ($str, $fn, $chmod) = @_;

    $fn = make_safer( $fn );

    open my $fh, '>:encoding(' . $HTML_CHARSET . ')', $fn or croak $!;
    print   $fh $str or croak $!;
    close   $fh or croak $!;
    md_chmod( $FILE_CHMOD, $fn );
    undef   $fh;
    return 1; 
    
}

sub md_cp {
    require File::Copy;
    my ( $source, $dest ) = @_;
	
	warn "install_cp: source: '$source', dest: '$dest'\n"
		if $t; 
	
    my $r = File::Copy::copy( $source, $dest );    # or croak "Copy failed: $!";
    return $r;
}

sub md_mv {
    my ( $source, $dest ) = @_;
	
	warn "md_mv: source: '$source', dest: '$dest'\n"
		if $t; 
	
    my $r = File::Copy::move( $source, $dest ) or croak "Copy failed from: '$source', to: '$dest': $!";
    return $r;
}


sub md_mvdir {
    my ( $source, $dest ) = @_;
	
	warn "md_mv: source: '$source', dest: '$dest'\n"
		if $t; 
	
    my $r = rmove( $source, $dest ) or croak "Copy failed from: '$source', to: '$dest': $!";
    return $r;
}



sub md_rm {
    my $file  = shift;
	
	warn "md_rm: file: '$file'"
		if $t; 
	
    my $count = unlink($file);
    return $count;
}

sub md_chmod {
	
    my ( $octet, $file ) = @_;

	warn 'md_chmod $octet:' . $octet . ', $file:'  . $file
		if $t; 
	
	my $r = chmod( $octet, $file );
    return $r;
}

sub md_mkdir {

    my ( $dir, $chmod ) = @_;
    my $r = mkdir( $dir, $chmod );
	
	warn "md_mkdir, dir: '$dir'"
		if $t; 

    if(!$r){ 
        warn 'mkdir didn\'t succeed at: ' . $dir . ' because:' . $!; 
    }
    return $r;
}

sub md_rmdir {
    my $dir  = shift;
	
	warn "md_rmdir, dir: '$dir'"
		if $t; 
	
    my $r    = remove_tree($dir);
    return $r;
}

sub md_dircopy {
    my ( $source, $target ) = @_;
	
	warn "md_mv: source: '$source', target: '$target'\n"
		if $t; 
		
	dircopy( $source, $target )
      or die "can't copy directory from, '$source' to, '$target' because: $!";
}

sub md_slurp {

    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open( F, '<:encoding(' . $HTML_CHARSET . ')', $file )
      || croak "open $file: $!";
    @r = <F>;
    close(F) || croak "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}


