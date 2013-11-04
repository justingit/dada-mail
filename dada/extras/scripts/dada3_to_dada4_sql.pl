#!/usr/bin/perl 


use strict; 

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/DADA/perllib";
use lib "$FindBin::Bin/../../";
use lib "$FindBin::Bin/../../DADA/perllib";

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}

use CGI::Carp qw(fatalsToBrowser); 

use DADA::Config; 
use DADA::App::DBIHandle; 
use DADA::App::Guts; 
use DADA::Template::HTML; 


my $dbi_obj = DADA::App::DBIHandle->new; 
my $dbh  = $dbi_obj->dbh_obj;

use CGI qw(:standard);


if(param('process')){ 
	print list_template(
		-Part => "header", 
		-vars       => { 
			show_profile_widget => 0, 
		}
	); 
	if(step1()) { 
		if(step2()) { 
			if(step3()) {  
				if(step4() ) { 
					if(step5()) { 
						if(step6()) { 
							print h1('Migration Complete!');					
						}
					}
				}
			}
		}	
	} 
	print list_template(-Part => "footer"); 
	
}
else { 
	print list_template(-Part => "header",-vars       => { 
			show_profile_widget => 0, 
				}); 
	
               
	print h1($DADA::Config::PROGRAM_NAME . ' 3.x to 4.x Migration Assistant '); 
	if(step1()){ 
		print <<EOF
		
		<hr /> 

<p>This migration utility will move over your current $DADA::Config::PROGRAM_NAME Subscriber Fields to the
new database design. <strong>Please MAKE SURE to make your own, manual backup of your $DADA::Config::PROGRAM_NAME 
SQL database, as this migration will remove and modify information</strong>. Please see the documentation on this utility for
more information. </p> 

<form>
<input type="hidden" name="process" value="1" /> 
<input type="submit" value="I've Backed Everything Up, Begin Migration!" />
</form> 
		
EOF
; 
	}
	
	print list_template(-Part => "footer"); 

	
}


sub step1 { 
	
	print h1('Step #1 Testing Your Current Setup:');
	my $schema_file = THREEOHCOMPAT::schema_file(); 
	if(! -e $schema_file){ 
		print p('PROBLEM: I cannot find the file, ' . $schema_file . '. Please make sure it exists!'); 
		print p('Stopping Migration.'); 
		return 0; 
	}
	if($DADA::Config::SUBSCRIBER_DB_TYPE ne 'SQL') { 
		print p("Problem: The, " . b('$SUBSCRIBER_DB_TYPE') . " configuration variable is not set to, 'SQL', it's set to '$DADA::Config::SUBSCRIBER_DB_TYPE'."); 
		print p("If you are not using the SQL Backend for Dada Mail, you do not need this utility."); 
		return 0;		
	}
	for(qw(profile_table profile_fields_table profile_fields_attributes_table)){ 
		if(THREEOHCOMPAT::table_exists($DADA::Config::SQL_PARAMS{$_})){ 
			print p("Problem: The, " . b($DADA::Config::SQL_PARAMS{$_}) . " table already exists. Stopping. You'll have to remove this table, before we can continue."); 
			print p("If there is important information saved in this table, you may not want to remove the table - make sure to follow the upgrade utility instructions correctly!");
			return 0; 
		}
		else { 
			print p("The, " . b($DADA::Config::SQL_PARAMS{$_}) . " table does not already exist. Good!"); 		
		}
	}
	
	return 1; 
	print p(em('Done!')); 
	print hr; 

}

sub step2 { 
	
	print h1('Step #2 Adjusting Current Schema:');
	adjust_current_schema();
	print p(em('Done!')); 
	print hr;
	return 1;

}


sub step3{
	
	print h1('Step #3 Creating Tables:');
	THREEOHCOMPAT::create_tables();
	print p(em('Done!')); 
	print hr;
	return 1; 
}


sub step4 { 
	
	my $fbv = THREEOHCOMPAT::threeoh_get_fallback_field_values(); 
	
	print h1('Step #4 Migrating Fields:');
	require DADA::ProfileFieldsManager; 
	my $dpfm = DADA::ProfileFieldsManager->new; 
	for(@{THREEOHCOMPAT::threeoh_subscriber_fields()}){ 
		$dpfm->add_field(
			{
				-field          => $_,
				-fallback_value => $dpfm->{$_},   
			}
		);
	}
	
	
	
	print p(em('Done!')); 
	print hr;
	return 1;
}

sub step5 { 
	print h1('Step #5 Moving Subscriber Profile Fields Information Over:');
	THREEOHCOMPAT::move_profile_info_over();
	print p(em('Done!')); 
	print hr;
	return 1; 
}

sub step6 { 

	print h1('Step #6 Removing Old Subscriber Fields Information');
	THREEOHCOMPAT::remove_old_profile_info();
	print p(em('Done!')); 
	print hr;
	return 1; 
}

sub adjust_current_schema { 
	
	my @sql_statements = (); 
	my $problems       = 0; 
	
	if($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql') { 	
		# This table isn't in 3.x, so no need to update it: 
		# 
		# 'ALTER TABLE `dada_profile_fields` CHANGE `email` `email` VARCHAR( 80 )'
		# 'ALTER TABLE `dada_profile_fields` CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin',
		
		# Needy Database is Needy. 
		# 
		@sql_statements = (
			'ALTER TABLE `dada_subscribers`     DROP INDEX `dada_subscribers_all_index`', 
		 	'ALTER TABLE `dada_archives`        DROP INDEX `dada_subscribers_all_index`', 
		
			'ALTER TABLE `dada_bounce_scores`  CHANGE `email` `email` VARCHAR( 80 )',
			'ALTER TABLE `dada_profiles`       CHANGE `email` `email` VARCHAR( 80 )',
			'ALTER TABLE `dada_subscribers`    CHANGE `email` `email` VARCHAR( 80 )',
		
			'ALTER TABLE `dada_archives`       CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin',
		    'ALTER TABLE `dada_profiles`       CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin',
			'ALTER TABLE `dada_settings`       CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin',
		    'ALTER TABLE `dada_subscribers`    CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin',
		
		);
	}
	elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg') { 
		@sql_statements = (
			'ALTER TABLE dada_bounce_scores  ALTER COLUMN email TYPE VARCHAR( 80 )',
			'ALTER TABLE dada_profiles       ALTER COLUMN email TYPE VARCHAR( 80 )',
			'ALTER TABLE dada_subscribers    ALTER COLUMN email TYPE VARCHAR( 80 )',
			# No need to alter the tables here for charset - charset is set Database-wide
		);		
	}
	elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite') { 
			# Well, not going to worry about it! (You can't) 
	}
	

	for my $query (@sql_statements) { 
		eval { 
			$dbh->do($query) 
				or die $dbh->errstr; 	
		};
		if($@){ 
			$problems++; 
		}
	}

	if($problems >= 1){ 
		return 0; 
	}
	else { 
		return 1; 
	}

}




package THREEOHCOMPAT;
use CGI qw(:standard); 
use Carp qw(croak confess carp);
use DADA::App::Guts; 

# ALl I need is the name of the fields I'm moving: 

sub table_exists { 

	my $table_name = shift; 
	my $count = undef; 
	eval { 
		my $query = 'SELECT COUNT(*) FROM ' . $table_name; 
		my $sth = $dbh->prepare($query); 
		$sth->execute; 
		$count =  $sth->fetchrow_array; 
	};
	
	if($@){ 
		return 0; 
	}
	elsif(defined($count)){
		return 1; 
	}
	else { 
		return 0; 
	}


	
}

sub schema_file { 
	
	my $schema_file = undef; 
	
	if($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql') { 	
		$schema_file = DADA::App::Guts::make_safer('extras/SQL/mysql_schema.sql'); 
	}
	elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg') { 
		$schema_file = DADA::App::Guts::make_safer('extras/SQL/postgres_schema.sql'); 		
	}
	elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite') { 
		$schema_file = DADA::App::Guts::make_safer('extras/SQL/sqlite_schema.sql'); 		
	}
	else { 
		croak "Unknown database type: " . $DADA::Config::SQL_PARAMS{dbtype}; 
	}
	
	if(-e './' . $schema_file){ 
		return './' . $schema_file;
	}
	elsif(-e '../../' . $schema_file){ 
		return '../../' . $schema_file;
	}
	else { 
		return './' . $schema_file;		
	}

	return $schema_file; 
}

sub create_tables { 
	
 	print '<div style="max-height: 200px; overflow: auto; border:1px solid black;background:#fff">';
	print '<pre>';
	my $sql;
	my $schema_file = schema_file(); 

	open(my $SQL, '<', $schema_file ) or croak $!;
	{
	    local $/ = undef;
	    $sql = <$SQL>;

	}
	close($SQL) or die $!;
	
	my @statements = split ( ';', $sql );

	for (@statements) {
	    if ( length($_) > 10 ) {
	        print "\nquery:\n" . $_;
	        eval {
	            my $sth = $dbh->prepare($_);
	            $sth->execute
	              or croak "cannot do statement! $DBI::errstr\n";
	        };
	        if ($@) {
	            print "\nProblem executing query:\n$@";
	        }
	        else {
	            print "\nDone!\n";
	        }
	    }
	}
	 print '</div>'; 
	 print '</pre>'; 
	
	return 1; 
}


sub move_profile_info_over { 
	
	my @fields = ('email', @{threeoh_subscriber_fields()});
	my $query = 'INSERT INTO ' . $DADA::Config::SQL_PARAMS{profile_fields_table} . ' (' . join(', ', @fields) . ' ) ';
	
	if($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){ 
		$query .= ' SELECT DISTINCT ON (' . $DADA::Config::SQL_PARAMS{subscriber_table} . '.email) ';
 	}
	else { 
		$query .= ' SELECT ';
	}
	
	$query .= join(', ', @fields) . ' FROM ' . $DADA::Config::SQL_PARAMS{subscriber_table}; 


	if($DADA::Config::SQL_PARAMS{dbtype} =~ m/^mysql$|^SQLite$/){ 
		$query .= ' GROUP BY ' . $DADA::Config::SQL_PARAMS{subscriber_table} . ' .email';
	}
	
	print code($query); 
	my $sth = $dbh->prepare($query);
	$sth->execute() 
		or croak $DBI::errstr; 
	$sth->dump_results; 
}

sub remove_old_profile_info { 

	my $fields = threeoh_subscriber_fields(); 
	for(@$fields){ 
		threeoh_remove_subscriber_field({-field => $_}); 
	}
	return 1; 
}


sub threeoh_columns { 
#	my $self = shift; 
	my $sth = $dbh->prepare("SELECT * FROM " . $DADA::Config::SQL_PARAMS{subscriber_table} ." where (1 = 0)");    
	$sth->execute() or confess "cannot do statement (at: columns)! $DBI::errstr\n";  
	my $i; 
	my @cols;
	for($i = 1; $i <= $sth->{NUM_OF_FIELDS}; $i++){ 
		push(@cols, $sth->{NAME}->[$i-1]);
	} 
	$sth->finish;
	return \@cols;
}




sub threeoh_subscriber_fields { 

    my ($args) = @_; 
    
	my $l = [] ;
	
	 $l = threeoh_columns();


    if(! exists($args->{-show_hidden_fields})){ 
        $args->{-show_hidden_fields} = 1; 
    }
    if(! exists($args->{-dotted})){ 
        $args->{-dotted} = 0; 
    }
    
    
    # We just want the fields *other* than what's usually there...
    my %omit_fields = (
        email_id    => 1,
        email       => 1,
        list        => 1,
        list_type   => 1,
        list_status => 1
    );

    
    my @r;
    for(@$l){ 
    
        if(! exists($omit_fields{$_})){
    
            if($args->{-show_hidden_fields} == 1){ 
                if($args->{-dotted} == 1){ 
                    push(@r, 'subscriber.' . $_);
                }
                else { 
                    push(@r, $_);
                }
             }
             elsif($DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX eq undef){ 
                if($args->{-dotted} == 1){ 
                    push(@r, 'subscriber.' . $_);
                }
                else { 
                
                    push(@r, $_);
                }
             }  
             else { 
             
                if($_ !~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/ && $args->{-show_hidden_fields} == 0){ 
                    if($args->{-dotted} == 1){ 
                        push(@r, 'subscriber.' . $_);
                    }
                    else { 
                
                        push(@r, $_);
                    }
                }
                else { 
                
                    # ... 
                }
            }
        }
    }
    
    return \@r;
}


sub threeoh_remove_subscriber_field { 

    #my $self = shift; 
    
	
    my ($args) = @_;
    if(! exists($args->{-field})){ 
        croak "You MUST pass a field name in, -field!"; 
    }
    $args->{-field} = lc($args->{-field}); 
 
    my $query =  'ALTER TABLE '  . $DADA::Config::SQL_PARAMS{subscriber_table} . 
                ' DROP COLUMN ' . $args->{-field}; 
    
    my $sth = $dbh->prepare($query);    
    
    my $rv = $sth->execute() 
        or croak "cannot do statement! (at: remove_subscriber_field) $DBI::errstr\n";   
 	
	
	return 1; 
	
}

sub threeoh_get_fallback_field_values { 

    my $v    = {}; 
#    return $v if  $self->can_have_subscriber_fields == 0; 
    require  DADA::MailingList::Settings; 
 
	my @lists = available_lists(); 
	
   if(exists($lists[0])){ 
	
  	 my $ls = DADA::MailingList::Settings->new({-list => $lists[0]});
	    my $li = $ls->get; 
	    my @fallback_fields = split("\n", $li->{fallback_field_values}); 
	    for(@fallback_fields){ 
	        my ($n, $val) = split(':', $_); 
	        $v->{$n} = $val; 
	    }
		return $v; 
	}
	else { 
		return {}; 
	}

}

=pod

=head1 Dada Mail 3 to Dada Mail 4 Migration Utility

=head1 Description

The SQL table schema between Dada Mail 3.0 and Dada Mail 4.0 has changed. 

=head2 Information Saved Differently 

Profile Subscriber Fields that were once saved in the, 
C<dada_subscribers> table now are saved in a few different tables: C<dada_profiles> and C<dada_profile_fields>. 

Attributes of the fields themselves, mostly the, "fallback" value, was saved in the list settings (for some bizarre reason). This information is now saved in the,  ,C<dada_profile_fields_attributes> table. 

=head2 Table Schema Datatypes

Many table column data types have changed, to better work with UTF-8/unicode encoding

=head2 Character Set/Encoding Changes

Some tables now need to have a character set of, B<utf-8>


This utility creates any missing tables, moves the old Profile Subscriber 
Fields information to the new tables and removes the old information. 


=head1 REQUIREMENTS

This utility should only be used when B<upgrading> Dada Mail to version 4, from version 3, or version 2 of Dada Mail. 

This utility should also, only be used if you're using the SQL Backend. 
If you are not using the B<SQL> Backend, you would not need this utility. 

=head1 INSTALLATION

Upgrade your Dada Mail installation to B<4> I<before> attempting to use this utility. 

This utility is located in the Dada Mail distribution, in: 

 dada/extras/scripts/dada3_to_dada4_sql.pl

You'll most likely want to B<move> it to the, C<dada> directory. 

Change it's persmissions to, C<0755> and visit the script in your web browser. 

This script relies on the SQL schemas that are saved in the, 

 dada/extras/SQL

directory to be present. Make sure this directory has been uploaded to your installation!

No other configuration is needed. 

From there, migration should be straightforward. Follow the directions in your browser window. 

Once the migration is complete, please B<REMOVE> this utility from your hosting account. 

=head1 A BIG WARNING ABOUT THIS MIGRATION TOOL AND LOST/CORRUPTED INFORMATION

We don't want you to lose information that's valuable to you. 

Please read this entire section, to understand what's going to happen. 

A major major huge change between Dada Mail 3.0 and 4.0 is that Subscriber Profile Fields information that used to be different per subscriber, per I<list> is now shared between lists. 

What this means is that, if you have a subscriber and there's a few fields, let's say, C<fist_name>, C<last_name>, C<favorite_color>, these three fields will show up for ALL lists (as it had, before), BUT! The information for each list will also be the same. In Dada Mail 3.0, it COULD potentially, be different. 

When you use this migration tool, only ONE version of this information will be moved over. It's up to the migration tool to decide what information gets pulled over. If you're worried about losing information you want to save, and only keeping information you want, it's suggested (kind of) to not use this migration tool, until you've manually changed the subscriber profile fields information to the information you'd like. How to do that? Good question, really. You'd probably have to change (manually) all the profile fields information for each subscriber, in each subscription to the version of the information you want. 

In the real world, we're not sure how much of a problem this is going to be since, the subscriber has to be subscribed to more than one list to first, be impacted by the problem and then, the subscriber has to have different information per list to first lose information from the migration. If the information is like what we've used as an example (C<fist_name>, C<last_name>, C<favorite_color>,) the information is probably going to be shared, anyways, so no worries. 

Dada Mail 4.0 also has the ability to allow your subscribers to change their own Subscription Profile Information, so if they don't like what's saved, they can manually update their own information. 

If you have a subscription field that's unique to each subscriber, for each list, you're going to be out of luck. We don't have a good workaround for that.

This utility will also CHANGE the CHARACTER SET of some of the tables in the schema, to, C<utf8>. If you were using Dada Mail and have non-Latin1 characters in your database, these characters will potentially be corrupted. If this is not something you want, please change convert and change the character set manually. The following tables need to be modified: 

=over

=item * dada_archives   

=item * dada_profiles   

=item * dada_settings

=item * dada_subscribers

=back

=cut