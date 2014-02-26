package DADA::Profile::Htpasswd;

use lib qw(../../ ../../DADA ../../perllib);

use DADA::Config; 
use DADA::App::Guts; 
use Carp qw(croak carp); 
my $t = 0; 

my %fields;

my $dbi_obj;

my $default_pass = 'test'; 


sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
    return $self;

}

sub _init {

    my $self = shift;

    my ($args) = @_;

    #$self->{'log'} = new DADA::Logging::Usage;

   
	if(!exists($args->{-list})){ 
		die "no list!";
	}
	else { 
		$self->{list} = $args->{-list}; 
	}
	$self->_sql_init($args); 
}

sub _sql_init {

    my $self = shift;
   $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    if ( $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ ) {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $self->{dbh} = $dbi_obj->dbh_obj;
    }
	else { 
		croak "SQL Backend only!"; 
	}
	
	
}


sub hello { 
	my $self = shift; 
	print "hello!\n"; 
}


sub validate_protected_dir { 
	my $self = shift; 
	my ($args) = @_; 
	
	my $status = 1; 
	my $errors = {}; 
	
	if(!exists($args->{-fields})){ 
		carp "you need to pass the fields in, -fields"; 
		return (0, $errors); 
	}
	if(!exists($args->{-fields}->{-name}) || !defined($args->{-fields}->{-name}) || length($args->{-fields}->{-name}) <= 0) { 
		$errors->{missing_name} = 1;
		$status = 0; 
	}
	if(!exists($args->{-fields}->{-url}) || !defined($args->{-fields}->{-url})  || length($args->{-fields}->{-url}) <= 0) { 
		$errors->{missing_url} = 1; 
		$status = 0; 
	}	
	if(! isa_url($args->{-fields}->{-url})){ 
		$errors->{url_no_exists} = 1; 
		$status = 0; 		
	}
	if(!exists($args->{-fields}->{-path}) || !defined($args->{-fields}->{-path}) || length($args->{-fields}->{-path}) <= 0) { 
		$errors->{missing_path} = 1;
		$status = 0; 
	}
	if(! -d $args->{-fields}->{-path}){ 
		$errors->{path_no_exists} = 1; 
		$status = 0; 		
	} 

	if(! -w $args->{-fields}->{-path}){ 
		$errors->{path_not_writable} = 1; 
		$status = 0; 		
	} 

	 
	if($args->{-fields}->{-use_custom_error_page} !~ m/1|0/) { 
		$errors->{use_custom_error_page_set_funny} = 1; 
		$status = 0; 		
	}
	
	return ($status, $errors);		
}
sub create { 
	my $self  = shift; 
	my ($args) = @_; 
	# A bunch of data testing... 
	$self->insert($args);
}

sub insert {
	my $self = shift; 
	my ($args) = @_; 

	my $query =
      'INSERT INTO '
      .  $self->{sql_params}->{password_protect_directories_table}
      . '(list, name, url, path, use_custom_error_page, custom_error_page, default_password) VALUES (?, ?, ?, ?, ?, ?, ?)';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
	my $password = undef; 
	if(exists($args->{ -default_password }) && defined($args->{ -default_password }) && length($args->{ -default_password }) > 0){ 
		$password = DADA::Security::Password::encrypt_passwd($args->{ -default_password } )
	}
    $sth->execute(
		$self->{list}, 
        $args->{ -name },
		$args->{ -url },
        $args->{ -path },
		$args->{ -use_custom_error_page },
		$args->{ -custom_error_page },
		$password, 
      )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

	
}


sub update {
	my $self = shift; 
	my ($args) = @_; 
	
	my $password = undef; 
	if(exists($args->{ -default_password }) && defined($args->{ -default_password }) && length($args->{ -default_password }) > 0){ 
		$password = DADA::Security::Password::encrypt_passwd($args->{ -default_password } )
	}
	
	
	my $query =
      'UPDATE '
      . $self->{sql_params}->{password_protect_directories_table}
      . ' SET name = ?, url = ?, path = ?, use_custom_error_page = ?, custom_error_page = ?, default_password = ? where id = ?';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute(
        $args->{ -name },
		$args->{ -url },
        $args->{ -path },
		$args->{ -use_custom_error_page },
		$args->{ -custom_error_page },
		$password, 
		$args->{ -id }, 
      )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

	
}




sub id_exists {
	
    my $self  = shift;
    my ($args) = @_;

	# This is saying, if we don't have a dbh handle, we don't have a proper 
	# "handle" on a profile. 
	
	if(! exists($self->{dbh})){ 
		return 0; 
	}
    my $query =
      'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{password_protect_directories_table}
      . ' WHERE id = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
		if $t; 

    $sth->execute($args->{-id} )
      or croak "cannot do statement (at exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

	# autoviv?
    if($row[0]){ 
		return 1; 
	}
	else { 
		return 0; 
	}

}


sub get {

    my $self = shift;
    my ($args) = @_;

	if(! $self->id_exists( { -id => $args->{-id} } ) ){ 
		return undef; 
		# die "blah blah blah"; 
	}

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{password_protect_directories_table}
      . " WHERE id = ?";

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-id} )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $info = {};
    my $hashref      = {};

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $info = $hashref;
        last FETCH;
    }

	return $info; 
	
}

sub remove_directory_files { 
    my $self = shift;
    my ($args) = @_;
	
	if(!exists($args->{-id})){ 
		croak "Cannot use this method without passing the '-id' param "; 
	}
	my $entry = $self->get({-id => $args->{-id}}); 
	if(-e $entry->{path} . '/.htaccess'){ 
		unlink($entry->{path} . '/.htaccess'); 
	}
	if(-e $entry->{path} . '/.htpasswd'){ 
		unlink($entry->{path} . '/.htpasswd'); 
	}
	
}

sub remove {
	
    my $self = shift;
    my ($args) = @_;
	
	if(!exists($args->{-id})){ 
		croak "Cannot use this method without passing the '-id' param "; 
	}

    my $query =
      'DELETE  from '
      . $self->{sql_params}->{password_protect_directories_table}
      . ' WHERE id = ? ';

	warn 'QUERY: ' . $query
		if $t;

    my $sth = $self->{dbh}->prepare($query);

	my $rv = $sth->execute( $args->{ -id } )
      or croak "cannot do statement (at remove)! $DBI::errstr\n";

    $sth->finish;

    return $rv;

}

sub get_all_ids { 

	my $self = shift; 
	my ($args) = @_;
	my $query = 'SELECT id FROM ' . $self->{sql_params}->{password_protect_directories_table} . ' WHERE list = ? GROUP BY id ORDER BY id DESC;';
    my $ids = $self->{dbh}->selectcol_arrayref($query, {}, ($self->{list}));
	return $ids || []; 
}

sub get_all_entries { 
	my $self    = shift; 
	my $entries = []; 
	for my $id(@{$self->get_all_ids}){ 
		push(@$entries, $self->get({-id => $id})); 
	}
	return $entries; 
}

sub setup_directory { 
	my $self = shift; 
	my ($args) = @_; 
	$self->write_htaccess($args);
	$self->write_htpasswd($args);
	return 1; 
}
sub write_htaccess { 
	
	my $self = shift;
	my ($args) = @_; 
	
	my $entry = $self->get({-id => $args->{-id}}); 
	
	my $custom_error_page = undef; 
	if($entry->{use_custom_error_page} == 1 && defined($entry->{custom_error_page})){ 
		$custom_error_page = $entry->{custom_error_page}
	}
	
	my $htaccess_content = ''; 
	if(-e $entry->{path} . '/' . '.htaccess') { 
		$htaccess_content = $self->grab_htaccess_content({-path => $entry->{path}}); 
	}
	
	my $open_pat  = quotemeta('# Begin ' . $DADA::Config::PROGRAM_NAME . ' Password Protect Directives'); 
	my $close_pat = quotemeta('# End ' . $DADA::Config::PROGRAM_NAME . ' Password Protect Directives'); 
	
	require DADA::Template::Widgets; 
	my $data = DADA::Template::Widgets::screen(
        {
            -screen => 'plugins/password_protect_directories/htaccess_file.tmpl',
 			-vars => { 
				name             => $entry->{name}, 
				path              => $entry->{path}, 
				custom_error_page => $custom_error_page,
			},
        }
    );

	if($htaccess_content =~ m/$open_pat(.*)$close_pat/gs){ 
	#	croak "yes"; 
		$htaccess_content =~ s/$open_pat(.*)$close_pat/$data/gs; 
	}
	else { 
#		croak "no."; 
		$htaccess_content = $htaccess_content . "\n\n" . $data; 
	}
	my $loc  = $entry->{path} . '/' . '.htaccess'; 
	
	
	open my $htaccess_file, '>', $loc        or croak $!; 
	print   $htaccess_file $htaccess_content or croak $!; 
	close   $htaccess_file                   or croak $!; 

}




sub grab_htaccess_content { 
	my $self   = shift; 
	my ($args) = @_; 
	if(! exists($args->{-path})) { 
		croak, "you MUST pass the, '-path' parameter!"; 
	}
	my $path = $args->{-path}; 
	my $loc  = $path . '/' . '.htaccess'; 
	my $data = ''; 
	if(-e $loc) { 
		$data = DADA::App::Guts::slurp($loc); 
		return $data; 
	}
	else { 
		return ''; 
	}
}





sub write_htpasswd { 
	my $self = shift;
	my ($args) = @_; 
	
	my $entry = $self->get({-id => $args->{-id}}); 
	open my $htpasswd, '>', $entry->{path} . '/' . '.htpasswd' or die $! ;
	my $pt = $DADA::Config::SQL_PARAMS{profile_table}; 
	my $st = $DADA::Config::SQL_PARAMS{subscriber_table};
	
	my $query = qq{SELECT $st.email, $pt.password 
	FROM $st 
	LEFT JOIN $pt 
	ON $st.email = $pt.email 
	WHERE  $st.list_type = 'list'  AND $st.list = ? AND $st.list_status = 1};
	
	my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statement! $DBI::errstr\n";

	 while ( my ( $email, $password ) = $sth->fetchrow_array ) {
		
		if(defined($password)){ 
			print $htpasswd $email . ':' . $password . "\n";
		}
		else { 
			print $htpasswd $email . ':' . $entry->{default_password} . "\n";
		}
	}

	close $htpasswd; 
	
	$sth->finish;
    
	return 1; 
};

1;