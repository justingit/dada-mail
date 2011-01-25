#!/usr/bin/perl

package log_viewer; 

use strict; 

use CGI::Carp qw(fatalsToBrowser); 

# make sure the DADA lib is in the lib paths!
use lib qw(../ ../DADA/perllib ../../../../perl ../../../../perllib); 
$ENV{PATH} = "/bin:/usr/bin"; 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
# we need this for cookies things;
use CGI; 
CGI->nph(1) 
	if $DADA::Config::NPH == 1; 
	
	my $q = new CGI; 
	   $q->charset($DADA::Config::HTML_CHARSET);
       $q = decode_cgi_obj($q);


my $Plugin_Config = {}; 


# Usually, this doesn't need to be changed. 
# But, if you are having trouble saving settings 
# and are redirected to an 
# outside page, you may need to set this manually.

$Plugin_Config->{Plugin_URL}   =  $q->url; 


$Plugin_Config->{Plugin_Name}  = 'Log Viewer'; 


# This refers to the, "tail" command: 
$Plugin_Config->{tail_command} =  'tail';



# use some of those Modules
use DADA::Config 4.0.0;
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 
use DADA::App::LogSearch;


init_vars(); 

my $admin_list = undef; 
my $root_login = undef; 
my $list       = undef; 

my %Logs = (
	'Usage Log'      		 => $DADA::Config::PROGRAM_USAGE_LOG,
	'Error Log'      		 => $DADA::Config::PROGRAM_ERROR_LOG,
	'Clickthrough Log (raw)' => $DADA::Config::LOGS . '/' . $list . '-clickthrough.log', 
	'Bounce Handler Log'     => $DADA::Config::LOGS . '/' . 'bounces.txt', 
); 
my $Default_Log = 'Usage Log';

my $process     = $q->param('process'); 

    my $logs        = find_logs(); 
    my $lines       = $q->param('lines')    || 100; 
    my $log_name    = $q->param('log_name') || $Default_Log;

run()
  unless caller();


sub run { 
	if(!$ENV{GATEWAY_INTERFACE}){ 
	#	croak "There's no CLI for this plugin."; 
	}else{ 
		&cgi_main(); 
	}
}


sub test_sub { 
	return "Hello, World!"; 
}



sub init_vars { 

    # DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

     while ( my $key = each %$Plugin_Config ) {
        
        if(exists($DADA::Config::PLUGIN_CONFIGS->{'log_viewer'}->{$key})){ 
        
            if(defined($DADA::Config::PLUGIN_CONFIGS->{'log_viewer'}->{$key})){ 
                    
                $Plugin_Config->{$key} = $DADA::Config::PLUGIN_CONFIGS->{'log_viewer'}->{$key};
        
            }
        }
     }
}

sub cgi_main {


	my $admin_list;

	( $admin_list, $root_login ) = check_list_security(
	    -cgi_obj    => $q,
	    -Function   => 'log_viewer',
	);

	$list = $admin_list;

	my $ls = DADA::MailingList::Settings->new( { -list => $list } );
	my $li = $ls->get();

	my $flavor = $q->param('flavor') || 'cgi_view';

	my %Mode = (
	   'cgi_view'               => \&cgi_view, 
	   'ajax_view_logs_results' => \&ajax_view_logs_results, 
	   'ajax_delete_log'        => \&ajax_delete_log, 
	   'search_logs'            => \&search_logs, 
	);

	if ( exists( $Mode{$flavor} ) ) {
	    $Mode{$flavor}->();    #call the correct subroutine
	}
	else {
	    &cgi_view;
	}

}



sub cgi_view { 

    # get the list information
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    

    my $logs_popup_menu = $q->popup_menu(
        -name     => 'log_name',
        -id       => 'log_name',
        '-values' => [ keys %$logs ],
        -default  => $log_name,
        -onClick  => "view_logs();",
    );
	my $log_lines = []; 
	for(100, 1,10,20,25,50,100,200,500,1000, 10000, 100000, 1000000){ 
		push(@$log_lines, {line_count => $_});
	}

	$Default_Log = $log_name; 
                      
    my @log_names = keys %$logs; 
    
	my $tmpl = main_tmpl(); 
	
	require DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
		{ 
			-data           => \$tmpl, 
			-with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $list,
            },
			-vars => { 
				log_names       => ($log_names[0] ? 1 : 0),
				logs_popup_menu => $logs_popup_menu, 
				log_lines       => $log_lines, 
				Plugin_URL      => $Plugin_Config->{Plugin_URL}, 
			},
		}
		
	); 
	e_print($scrn); 
	    
}

sub main_tmpl { 
	
	return q{ 
		
		<!-- tmpl_set name="title" value="Log Viewer" -->
		
		<script type="text/javascript">
		    //<![CDATA[
			Event.observe(window, 'load', function() {
			  view_logs();				
			});
			
			 function view_logs(){ 
				new Ajax.Updater(
					'view_logs_results', '<!-- tmpl_var Plugin_URL -->', 
					{ 
					    method: 'post', 
						parameters: {
							flavor:       'ajax_view_logs_results',
							log_name:     $F('log_name'),
							lines:        $F('lines')
						},
					onCreate: 	 function() {
						Form.Element.setValue('refresh_button', 'Loading...');
						/*$('view_logs_results').hide();*/
						/*$('view_logs_results_loading').show();*/
					},
					onComplete: 	 function() {

					/*	$('view_logs_results_loading').hide(); */
						$('view_logs_results').show();
					Form.Element.setValue('refresh_button', 'Refresh');
					}	
					});
			}
			function purge_log(){ 
				
				var confirm_msg =  "Are you sure you want to delete this log? ";
				    confirm_msg += "There is no way to undo this deletion.";
				if(confirm(confirm_msg)){
						new Ajax.Request(
						  '<!-- tmpl_var Plugin_URL -->', 
						{
						  method: 'post',
						 	parameters: {
								flavor: 'ajax_delete_log', 
								log_name:     $F('log_name')
						  },
						  onSuccess: function() {
							view_logs()
						  }, 
						onFailure: function() { 
							alert('Warning! Something went wrong when attempting to remove the log file.'); 
						}
						}
						);
				}
				else { 
					alert('Log deletion canceled.'); 
				}
			}
		    //]]>
		</script>
		
		
		<!-- tmpl_if log_names --> 
		
			<form method="post">
			<table cellpadding="5"> 
			 <tr> 
			  <td valign="bottom"> 
				<p>Show this log:<br /> 
				 <!-- tmpl_var logs_popup_menu --> 
				</p> 
			</td> 
		 	<td valign="bottom"> 
			  <p>Show the last:<br /> 
				<select name="lines" id="lines" onclick="view_logs();"> 
					<!-- tmpl_loop log_lines --> 
						<option value="<!-- tmpl_var line_count -->"><!-- tmpl_var line_count --></option> 
					<!-- /tmpl_loop --> 
				</select> lines
			</p> 
			</td> 
		 	<td valign="bottom"> 
			<br /><input type="button" value="Refresh" id="refresh_button" onClick="view_logs();" />
			</td> 
		 	<td valign="bottom"> 
			<br /><input type="button" value="Delete Log"  onclick="purge_log();" /> 
					</form> 
			</td>
	<td valign="bottom"> <br />
			<form method="get"> 
		     <input type="hidden" name="flavor" value="search_logs" /> 
		     <input type="text" name="query" value="" /> 
		     <input type="submit" value="Search All Logs" class="processing" /> 
		    </form>
	 		</td> 
	
		   </tr> 
		</table> 

			

			

			<div id="view_logs_results">
			
			</div> 
			<div id="view_logs_results_loading" style="display:none"> 
				<p class="alert">Loading...</p>
			</div> 
			

		
		<!-- tmpl_else -->
			<p>
			 <em>
			  There are no <!-- tmpl_var PROGRAM_NAME --> logs set.
			 </em>
		   </p>
		<!-- /tmpl_if --> 
		
		
		
	};
	
}




sub ajax_view_logs_results {

     my $scrn; 
        $scrn .=  '<div style="width:100%; overflow: auto; height: 500px" id="resultdiv">'; 
        $scrn .=  show_log($log_name, $lines); 
        $scrn .=  '</div>';
        
		print $q->header(); 
        e_print($scrn); 
}


sub show_log { 
	my ($log_name, $lines) = @_;
	my $loglines = log_lines($Logs{$log_name}, $lines); 
	my $html; 
	   $html .= '<pre>';
	foreach(@$loglines){ 
		$_ =~ s/\t/    /g;
		$html .= $_ . "\n";
	}
	$html .= '</pre>';
	return $html;
}




sub ajax_delete_log { 

    
    my @log_names = keys %$logs;     
    if(exists($logs->{$log_name})){ 
        my $file = $Logs{$log_name};
        make_safer($file);
        unlink($file); 	
    }
	print $q->header(); 
}



#---------------------------------------------------------------------#


sub find_logs { 
	my %found_logs;	
	foreach(keys %Logs){ 
		if(file_check($Logs{$_}) == 1){ 
			$found_logs{$_} = $Logs{$_};
		}
	}	
	return \%found_logs; 
}




sub log_name { 

    my $file_name = shift; 
    
    
    foreach(keys %Logs){ 
    
        if($file_name eq $Logs{$_}){ 
        
            return $_;
        }
    }



}




sub file_check { 
	my $filename = shift; 
	if(-f $filename && -e $filename){ 
		return 1;
	}else{ 
		return 0; 
	}
}




sub log_lines { 
	my ($filename, $lines) = @_;

	my $tail  = make_safer($Plugin_Config->{tail_command}); 
	$filename = make_safer($filename); 
	$lines    = make_safer($lines); 
	
	my $log = `$tail -n $lines $filename`;
	
	my @lines = split("\n", $log);
	
	if(($log_name eq "Usage Log") || ($log_name eq "Bounce Handler Log")){ 
	 
		my @good_lines; 	
		foreach(@lines){ 
			if (($_ =~ m/\[(.*?)\]\t$list(.*)/) || ($_ =~ m/\[(.*?)\]\t(.*?)\t$list(.*)/)){ 
				push(@good_lines, $_); 		
			}
		}
		@lines = @good_lines; 
	}
		
	
	
	return \@lines;
}




sub search_logs { 
	
	my $s_logs = shift || [values(%$logs)]; 
	my $query  = shift || $q->param('query'); 
	my $test   = shift || undef; 
	
	
	require Data::Dumper;
	
    my $only_content = 0; 
	my $list         = undef; 
	my $ls           = undef; 
	my $li           = undef; 
	my $return       = undef; 
	
	
	if(! $test){ 
		
		$only_content = xss_filter($q->param('only_content')) || 0;
		
		my ($admin_list, $root_login) = check_list_security(
											-cgi_obj  => $q,  
	                                        -Function => 'log_viewer'
										);
	    $list = $admin_list; 
	
	    # get the list information
	     $ls = DADA::MailingList::Settings->new(
											{
												-list => $list,
											}
										); 
	     $li = $ls->get;
	
    }
	else { 
		$only_content = 1; 
	}
    
  

    # header 
    $return .= $q->header(admin_header_params()); 
    
    if($only_content != 1){ 

        $return .= admin_template_header(
								-Title       => "Log Viewer - Search",
                                -List        => $li->{list},
                                -Root_Login  => $root_login,
                                -HTML_Header => 0,
                              );
    }    
        
    if($only_content != 1){     

		  $return .= "<p id=\"breadcrumb\"><a href=\"" . $Plugin_Config->{Plugin_URL} . "\">" . $Plugin_Config->{Plugin_Name} . "</a> &#187; Search Results</p>	";


          $return .= $q->h1("Results for: " . $q->param('query')); 
    }
    
    my $searcher = DADA::App::LogSearch->new; 
    my $results  = $searcher->search({
        -query => $query,
        -files => $s_logs, 
    }); 
           
    my @terms = split(' ', $q->param('query')); 
    
    foreach my $file_name(keys %$results){ 
        
        if($results->{$file_name}->[0]){ 
        
            $return .= $q->h1(log_name($file_name));
            
            foreach my $l(@{$results->{$file_name}}){ 
            
                my @entries = split("\t", $l); 
                
                $return .= '<ul>'; 
                foreach my $diff_lines(@entries){ 
                  
					# BUGFIX: [ 2124123 ] 3.0.0 - Log viewer does not escape ">" "<" etc. 
					# http://sourceforge.net/tracker/index.php?func=detail&aid=2124123&group_id=13002&atid=113002
					#$diff_lines = webify_plain_text($diff_lines);
					$diff_lines =~ s/& /&amp; /g;
			        $diff_lines =~ s/</&lt;/g;
			        $diff_lines =~ s/>/&gt;/g;
			        $diff_lines =~ s/\"/&quot;/g;
					$diff_lines = convert_to_ascii($diff_lines);
					# DEV: This will probably work, so long as the lines do not have new line endings, 
					
                    $diff_lines = $searcher->html_highlight_line({-query => $query, -line => $diff_lines }); 

						
                  	$return .= $q->li({-style => 'list-style-type:none"'}, $diff_lines);
					
				}
				$return .= '</ul><hr />'; 
				
            }
        }
   
   
    }
    
    if($only_content != 1){ 

        $return .= admin_template_footer(
					-List => $list, 
					-Form => 0
					); 
    
    }

	if($test){ 
		return $return; 
	}
	else { 
		e_print($return); 
	}


}







#---------------------------------------------------------------------#

=pod

=head1 Plugin: log_viewer.cgi - View Logs Created by Dada Mail

This plugin allows you to view the Dada Mail, Error, Bounce and Clickthrough logs
that  Dada Mail creates in its activities through your web browser. 

=head2 Installation

Upload log_viewer.cgi into your cgi-bin. We suggest you create 
a 'plugins' directory in the same directory that the mail.cgi script 
is in. For example. If mail.cgi is at: 

 /home/account/cgi-bin/dada/mail.cgi 

create a directory called plugins at: 

  /home/account/cgi-bin/dada/plugins

and upload this script into that directory:

 /home/account/cgi-bin/dada/plugins/log_viewer.cgi

Once uploaded in plain text or ASCII mode, chmod the script to 755.   

Add this entry to the $ADMIN_MENU array ref:

	 {-Title          => 'View Logs', 
	  -Title_URL      => $PLUGIN_URL."/log_viewer.cgi",
	  -Function       => 'log_viewer',
	  -Activated      => 1, 
	  },

It's possible that this has already been added to $ADMIN_MENU and all
you would need to do is uncomment this entry.

=head1 COPYRIGHT 

Copyright (c) 1999 - 2008 

Justin Simoni

http://justinsimoni.com

All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut




