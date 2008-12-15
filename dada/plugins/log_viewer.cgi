#!/usr/bin/perl

package log_viewer; 

use strict; 

use CGI::Carp qw(fatalsToBrowser); 

# make sure the DADA lib is in the lib paths!
use lib qw(../ ../DADA/perllib ../../../../perl ../../../../perllib); 
$ENV{PATH} = "/bin:/usr/bin"; 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
# we need this for cookies things;
use CGI; CGI->nph(1) if $DADA::Config::NPH == 1; my $q = new CGI; $q->charset($DADA::Config::HTML_CHARSET);


my $Plugin_Config = {}; 


# Usually, this doesn't need to be changed. 
# But, if you are having trouble saving settings 
# and are redirected to an 
# outside page, you may need to set this manually.

$Plugin_Config->{Plugin_URL}   =  $q->url; 


# This refers to the, "tail" command: 
$Plugin_Config->{tail_command} =  'tail';



# use some of those Modules
use DADA::Config 3.0.0;
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 
use DADA::App::LogSearch;


init_vars(); 

use CGI::Ajax;
my $admin_list = undef; 
my $root_login = undef; 
my $list       = undef; 


my %Logs = (
	'Usage Log'      		 => $DADA::Config::PROGRAM_USAGE_LOG,
	'Error Log'      		 => $DADA::Config::PROGRAM_ERROR_LOG,
	'Clickthrough Log (raw)' => $DADA::Config::LOGS . '/' . $list . '-clickthrough.log', 
	#'SMTP Log'       		 => $DADA::Config::SMTP_ERROR_LOG,
	#'SMTP Conversation Log'  => $DADA::Config::SMTP_CONVERSATION_LOG,
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
	
	($admin_list, $root_login) = check_list_security(
									-cgi_obj  => $q,  
	                                -Function => 'log_viewer'
								);
	$list = $admin_list;
	
	
	if($process && $process ne 'search'){ 

	    main(); 

	}
	elsif($process && $process eq 'search'){ 

	    search_logs(); 

	} 
	else { 

	    main(); 

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



sub main { 


    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'log_viewer');
    my $list = $admin_list; 
    
    # get the list information
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $scr; 
    
    
    # header     
    $scr .= (admin_template_header(-Title      => "Log Viewer",
                            -List       => $li->{list},
                            -Form       => 0,
                            -HTML_Header => 0, 
                            -Root_Login => $root_login));
        
         $Default_Log = $log_name; 
       
	               
    my @log_names = keys %$logs; 
    
    if(!$log_names[0]){ 
        $scr .=  $q->p($q->i("There are no " . $DADA::Config::PROGRAM_NAME . "logs set")); 
    }else{ 
    
   $scr .= search_widget(); 
    
    
        $scr .=  log_controls($logs);
        $scr .=  '<div style="width:100%; overflow: auto; max-height: 500px">'; 
        $scr .=  ajax_view_log($log_name, $lines); 
        $scr .=  '</div>';
        $scr .=  log_delete($log_name);
        $scr .= '<hr />';
         
    }
    
    
    #footer
    $scr .=  admin_template_footer(-List => $list, -Form => 0); 

    my $pjx = new CGI::Ajax( 'view_log' => \&ajax_view_log, 'delete_log' => \&ajax_delete_log);
    
    
    print $pjx->build_html( $q, $scr, {admin_header_params()});
        
    
}








sub ajax_view_log {

     my $scr; 
        $scr .=  '<div style="width:100%; overflow: auto; height: 500px" id="resultdiv">'; 
        $scr .=  show_log($log_name, $lines); 
        $scr .=  '</div>';
        
        return $scr; 
        

}



sub ajax_delete_log { 

    my $log_name = shift; 
    
    my @log_names = keys %$logs; 
    
    if(exists($logs->{$log_name})){ 
        my $file = $Logs{$log_name};
        make_safer($file);
        unlink($file); 	
    }
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




sub log_controls { 
	my $logs = shift;
	my $html; 
	my $foo = '<br /><input type="button" value="Refresh" onClick="view_log([\'log_name\', \'lines\'], [\'resultdiv\'] );" />'; 
	
	$html .= $q->start_form(-method => 'post');
	$html .= $q->start_table({-cellpadding => 5}); 
	$html .= $q->Tr(
	         $q->td({-valign => 'bottom'}, [
	         
	         ($q->p('Show this log: ', $q->br, 
	          $q->popup_menu(-name    => 'log_name', 
	                         -id      => 'log_name', 
	                        '-values' => [keys %$logs],
	                        -default  =>  $log_name,
	                        -onClick  => "view_log(['log_name', 'lines'], ['resultdiv'] );",	
	                        )
	         )), 
	         
	         ($q->p('Show the last:', $q->br,   
			  $q->popup_menu(-name => 'lines',
			                 -id   => 'lines', 
							'-values' => [1,10,20,25,50,100,200,500,1000, 10000, 100000, 1000000], 
							 -default => $lines, 
							 -onClick  => "view_log(['log_name', 'lines'], ['resultdiv'] );",							 
							 ), 
	                ' lines')),
	          ($q->p($foo))
	         ])); 
	         
	 $html .= $q->end_form();
	 $html .= $q->end_table();
	                         
	return $html;
}




sub log_delete { 
	
	my $log_name = shift; 
	my $html; 
	$html .= $q->p({-align=> 'center'},
	$html .= $q->start_form(-method => 'post'), 
	         $q->hidden('process',  'remove'), 
	         $q->hidden('log_name', $log_name), 
	        
	         '<input type="button" value="Purge This Log"  onClick="delete_log([\'log_name\'],[]); view_log([\'log_name\', \'lines\'], [\'resultdiv\'] );" />', 
	         
	         $q->end_form());
	return $html;
	
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
                                -Form        => 0,
                                -Root_Login  => $root_login,
                                -HTML_Header => 0,
                              );
    }    
        
    if($only_content != 1){     
          $return .= search_widget(); 
          $return .= $q->p($q->a({-href => $Plugin_Config->{Plugin_URL}}, "Back to Log Viewer")); 
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
					
                    $diff_lines = $searcher->html_highlight_line({-query => $q->param('query'), -line => $diff_lines }); 

						
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
		print $return; 
	}


}

sub search_widget { 


  my $scr =  q{ 
    
    <form method="get"> 
    
     <input type="hidden" name="process" value="search" /> 
     
     <input type="text" name="query" value="" /> 
     
     <input type="submit" value="Search All Logs" class="processing" /> 
     
    </form> 
    
    <hr /> 
    
    }; 
    
    return $scr; 

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




