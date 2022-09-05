#!/usr/bin/perl -wT
use strict;
#
# $Id: TFmail_config.pl,v 1.1 2006/11/26 05:33:10 skazat Exp $
#
# USER CONFIGURATION SECTION
# --------------------------

# Set these to same values that you used in TFmail.pl
use constant DEBUGGING      => 1;
use constant LIBDIR         => '.';
use constant CONFIG_ROOT    => '.';
use constant CONFIG_EXT     => '.trc';
use constant LOGFILE_ROOT   => '';
use constant LOGFILE_EXT    => '.log';
use constant CHARSET        => 'iso-8859-1';

# The file that the script should use as a lock file and a
# place to count failed password attempts.  This should not
# be the name of an existing file - the script will create
# the file itself.
use constant LOCKFILE       => '.lock';

# Set the password to some word or phrase that nobody will be
# able to guess.  It's important to choose a strong password
# as anybody who guesses it will be able to take control of
# your web site and use your web server to attack other hosts
# on the internet.
use constant PASSWORD       => 'password';

# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)

=head1 NAME

TFmail_config.pl - TFmail configuration editor

=head1 DESCRIPTION

This CGI script provides basic TFmail configuration file editing
facilities.  All templates are inlined, so each configuration is
a single file.

=cut

use Fcntl ':flock';
use lib LIBDIR;
use NMSCharset;
use CGI qw(:standard);
use IO::File;

BEGIN
{
   use vars qw($VERSION);
   $VERSION = substr q$Revision: 1.1 $, 10, -1;
}

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} =~ /(.*)/ and $ENV{PATH} = $1;

use vars qw($done_headers);
$done_headers = 0;

use vars qw($cs $cs_strip_nonprint);
$cs = NMSCharset->new(CHARSET);
$cs_strip_nonprint = $cs->strip_nonprint_coderef;
sub strip_nonprint { &{ $cs_strip_nonprint }(@_); }

#
# We want to trap die() calls, output an error page and
# then do another die() so that the script aborts and the
# message gets into the server's error log.  If there is
# already a __DIE__ handler installed then we must
# respect it on our final die() call.
#
eval { local $SIG{__DIE__} ; main() };
if ($@)
{
   my $message = $@;
   error_page($message);
   die($message);
}

sub main
{
   local ($CGI::DISABLE_UPLOADS, $CGI::POST_MAX);
   $CGI::DISABLE_UPLOADS = 1;
   $CGI::POST_MAX        = 100000;

   my $cgi = CGI->new;
   my $gotpass = strip_nonprint( $cgi->param('password') || '' );

   if ( PASSWORD =~ /pa[s5][s5]|w[o0]rd/i )
   {
      die "Password too similar to 'password', aborting\n"
   }
   unless ( $ENV{REQUEST_METHOD} eq 'POST' and length $gotpass )
   {
      html_header();
      print <<END;
<?xml version="1.0" encoding="@{[ CHARSET ]}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <title>Password Required</title>
 </head>
 <body>
  <form method="post">
   <p>Please enter the TFmail configuration password.</p>
   <p><input type="password" name="password" /></p>
   <p><input type="submit" value="Continue" /></p>
  </form>
 </body>
</html>
END
      exit;
   }
    
   my $flock = IO::File->new('>>'.LOCKFILE);
   defined $flock or die "open >>@{[ LOCKFILE ]}: $!";
   flock $flock, LOCK_EX or die "flock @{[ LOCKFILE ]}: $!";

   if (-s LOCKFILE > 5)
   {
       html_header();
       print <<END;
<?xml version="1.0" encoding="@{[ CHARSET ]}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <title>Too many incorrect passwords</title>
 </head>
 <body>
  <p>
   This script is disabled because there have been too many
   incorrect password attempts.  To fix this, delete the lock
   file from the server.  The LOCKFILE configuration constant
   in the script holds the lock file location.
  </p>
 </body>
</html>
END
      exit;
   }

   if ($gotpass ne PASSWORD)
   { 
      sleep 1;
      seek $flock, 0, 2 or die "seek: $!";
      print $flock "x";
      close $flock;
      html_header();
      print <<END;
<?xml version="1.0" encoding="@{[ CHARSET ]}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <title>Password Incorrect</title>
 </head>
 <body>
  <form method="post">
   <p>You entered an incorrect password, please try again.</p>
   <p><input type="password" name="password" /></p>
   <p><input type="submit" value="Continue" /></p>
  </form>
 </body>
</html>
END
      exit;
   }

   truncate LOCK, 0;
   
   my $viewlog = $cgi->param('viewlog') || '';
   my $getlog  = $cgi->param('getlog')  || '';

   if (length $viewlog)
   {
      $viewlog =~ /^([\w\-]{1,100})$/ or die "bad log name [$viewlog]";
      send_log($1, 0);
      return;
   }
   elsif (length $getlog)
   {
      $getlog =~ /^([\w\-]{1,100})$/ or die "bad log name [$getlog]";
      send_log($1, 1);
      return;
   }
      
   my $name = strip_nonprint( $cgi->param('config_name') || 'default' );
   $name =~ /^([a-z0-9_]{2,80})$/ or die "bad config name [$name]";
   $name = $1;

   if ( $cgi->param('save') )
   {
      save_config($name, $cgi);
   }
   else
   {
      show_config($name, $cgi);
   }
}

sub send_log
{
   my ($log, $is_download) = @_;

   my $file = LOGFILE_ROOT . "/$log" . LOGFILE_EXT;
   my $fh = IO::File->new("<$file");
   defined $fh or die "open logfile [$log]: $!";
   my $size = -s $file;

   my $buf;
   $fh->read($buf, $size) or die "read logfile [$log]: $!";
   $fh->close;

   if ($is_download)
   {
      print header('-type' => 'application/octet-stream',
                   '-Content_Disposition' => qq{attachment; filename="$log.log"},
                   '-Content_Length' => $size,
                  );
   }
   else
   {
      print header('-type' => 'text/plain');
   }

   print $buf;
}

sub save_config
{
   my ($name, $cgi) = @_;

   my $config = $cgi->param('config') || '';
   $config =~ s#(\015\012|\012|\015)#\n#g;
   $config = strip_nonprint($config);
   $config =~ s#\s*$##;
   $config .= "\n\n";
   
   foreach my $template (grep /_template$/, $cgi->param)
   {
      my $tpl = $cgi->param($template) || '';
      $tpl =~ s#(\015\012|\012|\015)#\n#g;
      $tpl = strip_nonprint($tpl);
      $tpl =~ m#\n$# or $tpl .= "\n";
   
      if ($tpl =~ /\S/)
      {
         $tpl =~ s#^#%#mg;
         $config .= "$template:\n$tpl\n\n";
      }
   } 

   my $filename = CONFIG_ROOT."/$name".CONFIG_EXT;
   open OUT, ">$filename.tmp" or die "open >$filename.tmp: $!";
   print OUT $config or die "write to $filename.tmp: $!";
   close OUT or die "close $filename.tmp: $!";
   rename "$filename.tmp", $filename or die "rename [$filename.tmp] -> [$filename]: $!";

   page_header('');
   print <<END;
  <p>The configuration <tt>$name</tt> was saved successfully.</p>
END

   if ($name eq 'default')
   {
      print <<END;
  <p>
   This is the default configuration, so TFmail will use it for any
   HTML form that doesn't include a <tt>_config</tt> hidden input.
  </p>
END
   }
   else
   {
      print <<END;
  <p>
   To use the configuration you have just saved, ensure that your HTML
   form includes the following:</p>
<pre>&lt;input type=&quot;hidden&quot; name=&quot;_config&quot; value=&quot;$name&quot; /&gt;</pre>
END
   }

   print <<END;
   </form>
  <hr />
 </body>
</html>
END
}
   
sub show_config
{
   my ($name, $cgi) = @_;

   my $filename = CONFIG_ROOT."/$name".CONFIG_EXT;
   my $config;
   if (open INFILE, "<$filename")
   {
      local $/;
      $config = <INFILE>;
      close INFILE;
   }
   else
   {
      $config = default_config();
   }
   $config .= "\n\n\n";

   my %templates = ();
   while ($config =~ s#\n\s*([\w\-]+)_template:\n(.*?)\n(?!\%)#\n\n#s)
   {
      my ($name, $tpl) = ($1, $2);
      exists $templates{$name} or $templates{$name} = '';
      $tpl =~ s#^%##mg;
      $templates{$name} .= $tpl;
   }
   $config =~ s#\s*$#\n\n#;

   page_header($name);
   print <<END;
   <p>
    See the <tt>README</tt> file that came with the TFmail distribution
    for details of the things that can be configured here.
   </p>
END

   my $linecount = $config =~ tr#\n## + 5;
   print <<END;
   <textarea name="config" cols="80" rows="$linecount">${\( $cs->escape($config) )}</textarea>
   <hr />
END

   foreach my $template (sort keys %templates)
   {
      my $linecount = $templates{$template} =~ tr#\n## + 5;
      my $value = $cs->escape( $templates{$template}||'' );

      print <<END;
   <p>The text below is the <b>$template template</b>, see <tt>README</tt>
   for details of what you can change here.</p>
   <textarea name="${template}_template" cols="80" rows="$linecount">$value</textarea>
   <hr />
END
   }
   
   print <<END;
   <p>
    <input type="submit" name="save" value="Save this configuration" />
    as <input type="text" name="config_name" value="$name" />
   </p>
   <hr />
  </form>
 </body>
</html>
END
}

sub default_config
{
   return <<'END';
%% NMS configuration file %%
#
# TFmail configuration.
#

#
# recipient: the email address(s) to which TFmail should
# send the results of the form submission.
#
recipient: your.email@address.goes.here

#
# The names of the CGI inputs that TFmail should use to
# build the From: header of the email.
#
email_input:    email
realname_input: realname

success_page_template:
%<?xml version="1.0" encoding="iso-8859-1"?>
%<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
%    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
%<html xmlns="http://www.w3.org/1999/xhtml">
%  <head>
%    <title>Thank You</title>
%    <link rel="stylesheet" type="text/css" href="/css/nms.css" />
%    <style>
%       h1.title {
%                   text-align : center;
%                }
%    </style>
%  </head>
%  <body>
%    <h1 class="title">Thank You</h1>
%    <p>Below is what you submitted on {= date =}</p>
%    <hr size="1" width="75%" />
%{= FOREACH input_field =}
%    <p><b>{= name =}:</b> {= value =}</p>
%{= END =}
%    <hr size="1" width="75%" />
%    <p align="center">
%      <font size="-1">
%        <a href="http://nms-cgi.sourceforge.net/">TFmail</a>
%        &copy; 2002 London Perl Mongers
%      </font>
%    </p>
%  </body>
%</html>

email_template:
%Below is the result of your feedback form.  It was submitted
%{= by_submitter =}on {= date =}.
%----------------------------------------------------------------------
%
%{= FOREACH input_field =}
%{= name =}: {= value =}
%
%{= END =}
%----------------------------------------------------------------------

missing_template:
%<?xml version="1.0" encoding="iso-8859-1"?>
%<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
%    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
%<html xmlns="http://www.w3.org/1999/xhtml">
%  <head>
%    <title>Missing Fields</title>
%    <link rel="stylesheet" type="text/css" href="/css/nms.css" />
%    <style>
%       h1.title {
%                   text-align : center;
%                }
%    </style>
%  </head>
%  <body>
%    <h1 class="title">Missing Fields</h1>
%    <p>
%      The following fields were left blank in your submission form:
%    </p>
%    <ul>
%{= FOREACH missing_field =}
%      <li>{= name =}</li>
%{= END =}
%    </ul>
%    <p>
%      These fields must be filled in before you can successfully
%      submit the form.
%    </p>
%    <p>
%      Please use your back button to return to the form and
%      try again.
%    </p>
%    <p align="center">
%      <font size="-1">
%        <a href="http://nms-cgi.sourceforge.net/">TFmail</a>
%        &copy; 2002 London Perl Mongers
%      </font>
%    </p>
%  </body>
%</html>

confirmation_template:
%Thankyou for your form submission

END
}

sub page_header
{
   my ($this_config)  = @_;

   opendir D, CONFIG_ROOT or die "opendir @{[ CONFIG_ROOT ]}: $!";
   my @config = sort
                grep {!/^default$/}
                grep {/^[\w\-]+$/}
		map  {s/\Q${\( CONFIG_EXT )}\E$// ? ($_) : ()} 
		readdir D;
   closedir D;

   my $title = 'TFmail Configuration Editor';
   $title .= " - $this_config" if length $this_config;

   html_header();
   print <<END;
<?xml version="1.0" encoding="@{[ CHARSET ]}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <title>$title</title>
 </head>
 <body>
  <h2>$title</h2>
  <form method="post">
   <input type="hidden" name="password" value="@{[ $cs->escape(PASSWORD) ]}" />
END

   $done_headers = 1;

   show_log_files();

   print "<b>Config:</b>\n";
   foreach my $config ('default', @config)
   {
      if ($config eq $this_config)
      {
         print "<b>[$config]</b>\n";
      }
      else
      {
         print qq{<input type="submit" name="config_name" value="$config" />\n};
      }
   }

   print <<END;
  </form>
  <hr />
  <form method="post">
   <input type="hidden" name="password" value="@{[ $cs->escape(PASSWORD) ]}" />
   Create a new config called
   <input type="text" name="config_name" value="" />
   <input type="submit" value="Create" />
  </form>
  <hr />
  <form method="post">
   <input type="hidden" name="password" value="@{[ $cs->escape(PASSWORD) ]}" />
END
}

sub show_log_files
{
   opendir D, LOGFILE_ROOT or return;
   my @logs = map { /([\w\-]+)\Q@{[ LOGFILE_EXT ]}\E$/ ? ($1) : () } readdir D;
   closedir D;

   if (scalar @logs)
   {
      print "<p>View log file:\n";
      foreach my $log (@logs)
      {
         print qq{<input type="submit" name="viewlog" value="$log" />\n};
      }
      print "</p>\nDownload log file:\n";
      foreach my $log (@logs)
      {
         print qq{<input type="submit" name="getlog" value="$log" />\n};
      }
      print "</p>\n<hr />\n";
   }
}

sub error_page
{
   my ($message) = @_;

   unless ( $done_headers )
   {
      html_header();
      print <<EOERR;
<?xml version="1.0" encoding="@{[ CHARSET ]}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Error</title>
  </head>
  <body>
EOERR

      $done_headers = 1;
   }

   if ( DEBUGGING )
   {
      $message = NMSCharset->new(CHARSET)->escape($message);
      $message = "<p>$message</p>";
   }
   else
   {
      $message = '';
   }

   print <<EOERR;
    <h1>Application Error</h1>
    <p>
     An error has occurred in the program
    </p>
    $message
  </body>
</html>
EOERR
}

sub html_header {
    if ($CGI::VERSION >= 2.57) {
        # This is the correct way to set the charset
        print header('-type'=>'text/html', '-charset'=>CHARSET);
    }
    else {
        # However CGI.pm older than version 2.57 doesn't have the
        # -charset option so we cheat:
        print header('-type' => "text/html; charset=@{[ CHARSET ]}");
    }
}

