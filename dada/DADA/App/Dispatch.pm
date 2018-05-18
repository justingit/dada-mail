package DADA::App::Dispatch; 
use strict; 

use FindBin;
use lib "$FindBin::Bin/../../";
use lib "$FindBin::Bin/../DADA/perllib";
BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}

use DADA::Config; 
use DADA::App::Guts; 


use Carp qw(croak carp); 
use CGI; 

use vars qw($AUTOLOAD);
my %allowed = ( test => 0, );

sub hook {
    my ( $filename, $buffer, $bytes_read, $data ) = @_;
    $bytes_read ||= 0;
    $filename = uriescape($filename);
    open( COUNTER, ">", $DADA::Config::TMP . '/' . $filename . '-meta.txt' );
    my $per = 0;
    if ( $ENV{CONTENT_LENGTH} > 0 ) {    # This *should* stop us from dividing by 0, right?
        $per = int( ( $bytes_read * 100 ) / ( $ENV{CONTENT_LENGTH} - 1024 ) );    #1024 added to round up.
    }
    print COUNTER $bytes_read . '-' . $ENV{CONTENT_LENGTH} . '-' . $per;
    close(COUNTER);
}



sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;

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
    my $self = shift;
    my ($args) = @_;
}


sub prepare_cgi_obj
 { 
    my $self = shift; 
    my $q = shift || CGI->new;
       $q->charset($DADA::Config::HTML_CHARSET);
    
    if($DADA::Config::RUNNING_UNDER eq 'PSGI'){ 
        $ENV{PATH_INFO}    = $q->path_info(); 
        $ENV{QUERY_STRING} = $q->query_string(); 
    }
    
    
    # Surely, this is broken. 
    if ( $ENV{QUERY_STRING} =~ m/^\?/ ) {
        # DEV Workaround for servers that give a bad PATH_INFO:
        # Set the $DADA::Config::PROGRAM_URL to have, "?" at the end of the URL
        # to change any PATH_INFO's into Query Strings.
        # The below lines will then take this extra question mark
        # out, so actual query strings will work as before.
        $ENV{QUERY_STRING} =~ s/^\?//;
        # DEV: This really really needs to be check to make sure it works
        #CGI::upload_hook( \&hook );
        $q = CGI->new( $ENV{QUERY_STRING} );
    }
    else {
        #$q = CGI->new( \&hook );
    }

    # PROGRAM_URL has a, "?"
    # PATH INFO is blank
    # QUERY_STRING starts with a, "/"
    if (   $DADA::Config::PROGRAM_URL =~ m/\?$/
        && length( $ENV{PATH_INFO} ) == 0
        && $ENV{QUERY_STRING} =~ m/^\// )
    {
        $ENV{PATH_INFO}    = $ENV{QUERY_STRING};
        $ENV{QUERY_STRING} = '';
    }
    
    # This basially just fills $q with things from the PATH_INFO
    $q = $self->translate({
        -cgi_obj      => $q ,
    }); 
#    $q = DADA::App::Guts::decode_cgi_obj($q);
    return $q;
    
    
}

sub translate {
    my $self   = shift;
    my ($args) = @_;

    my $q            = $args->{-cgi_obj};
    
    if($DADA::Config::RUNNING_UNDER eq 'PSGI'){ 
        $ENV{PATH_INFO}    = $q->path_info(); 
        $ENV{QUERY_STRING} = $q->query_string(); 
    }

    my $env          = {%ENV};

    
    my $sched_flavor = $DADA::Config::SCHEDULED_JOBS_OPTIONS->{scheduled_jobs_flavor};
    
    if ( $env->{PATH_INFO} ) { # should be exists($env->{PATH_INFO})? 

        my $dp = $q->url || $DADA::Config::PROGRAM_URL;
        $dp =~ s/^(http:\/\/|https:\/\/)(.*?)\//\//;

        my $info = $env->{PATH_INFO};

        $info =~ s/^$dp//;

        # script name should be something like:
        # /cgi-bin/dada/mail.cgi
        $info =~ s/^$env->{SCRIPT_NAME}//i;
        $info =~ s/(^\/|\/$)//g;    #get rid of fore and aft slashes

        # seriously, this shouldn't be needed:
        $info =~ s/^dada\/mail\.cgi//;

        if ( !$info && $env->{QUERY_STRING} && $env->{QUERY_STRING} =~ m/^\// ) {

            # DEV Workaround for servers that give a bad PATH_INFO:
            # Set the $DADA::Config::PROGRAM_URL to have, "?" at the end of the URL
            # to change any PATH_INFO's into Query Strings.
            # The below two lines change query strings that look like PATH_INFO's
            # into PATH_INFO's
            $info = $env->{QUERY_STRING};
            $info =~ s/(^\/|\/$)//g;    #get rid of fore and aft slashes
        }

        if ( $info =~ m/^$DADA::Config::SIGN_IN_FLAVOR_NAME$/ ) {

            my ( $sifn, $pi_list ) = split( '/', $info, 2 );

            $q->param( 'flavor',    $DADA::Config::SIGN_IN_FLAVOR_NAME );
            $q->param( 'list', $pi_list );

        }
        elsif ( $info =~ m/^$DADA::Config::ADMIN_FLAVOR_NAME$/ ) {
            $q->param( 'flavor', $DADA::Config::ADMIN_FLAVOR_NAME );

        }
        elsif ( $info =~ m/^plugins/ ) {
            my ( $flavor, $plugin, $prm ) = split( '/', $info, 3 );
            $q->param('flavor', 'plugins'); 
            $q->param('plugin', $plugin); 
            $q->param('prm',    $prm); 
        }
        elsif ( $info =~ m/^schedules_config/ ) {
            $q->param('flavor',      'schedules_config'); 
        }
        elsif ( $info =~ m/^$sched_flavor/ ) {
            my ( $flavor, $schedule, $list, $output_mode ) = split( '/', $info, 4 );
            $q->param('flavor',      $sched_flavor); 
            if(!defined($schedule)){ 
                $q->param('schedule',    '_all');
            }
            else { 
                $q->param('schedule',    $schedule);
            }
            if(!defined($list)){
                $q->param('list',        '_all');
            } 
            else { 
                $q->param('list',        $list);
            }
            if(!defined($output_mode)){
                $q->param('output_mode', '_verbose');
            }
            else { 
                $q->param('output_mode', $output_mode);
            }   
            

        }
        elsif ( $info =~ m/^archive/ ) {

            # archive, archive_rss and archive_atom
            # form:
            #/archive/justin/20050422012839/

            my ( $pi_flavor, $pi_list, $pi_id, $extran ) = split( '/', $info );

            $q->param( 'flavor', $pi_flavor )
              if $pi_flavor;
            $q->param( 'list', $pi_list )
              if $pi_list;
            $q->param( 'id', $pi_id )
              if $pi_id;
            $q->param( 'extran', $extran );

        }
        elsif ( $info =~ m/^privacy_policy/ ) {

            my ( $pi_flavor, $pi_list, $extran ) = split( '/', $info );

            $q->param( 'flavor', $pi_flavor )
              if $pi_flavor;
            $q->param( 'list', $pi_list )
              if $pi_list;
            $q->param( 'extran', $extran );

        }
        elsif ( $info =~ /^spacer_image/ ) {

            # spacer_image/list/mid/spacer.png';
            # Or
            # spacer_image/list/mid/email_name/email_domain/spacer.png';

            $q->param( 'flavor', 'm_o_c' );

            my @data = split( '/', $info );

            $q->param( 'list', $data[1] );
            $q->param( 'mid',  $data[2] );

            if (   $data[3] ne 'spacer_image.png'
                && $data[4]
                && $data[5]
                && $data[5] eq 'spacer.png' )
            {
                $q->param( 'email', $data[3] . '@' . $data[4] );
            }

        }
        elsif ( $info =~ /^show_img/ ) {
			
            my ( $pi_flavor, $pi_list, $pi_id, $pi_cid ) = split( '/', $info );
            $q->param( 'flavor', 'show_img' );
            $q->param( 'list', $pi_list );
            $q->param( 'id', $pi_id );
            $q->param( 'cid', $pi_cid );
		}
        elsif ( $info =~ /^img/ ) {

            my ( $pi_flavor, $img_name, $extran ) = split( '/', $info );

            $q->param( 'flavor', 'img' );

            $q->param( 'img_name', $img_name )
              if $img_name;

        }
        elsif ( $info =~ /^file_attachment/ ) {
			
            my ( $pi_flavor, $pi_list, $pi_id, $pi_fn ) = split( '/', $info );
            $q->param( 'flavor', 'file_attachment' );
            $q->param( 'list', $pi_list );
            $q->param( 'id', $pi_id );
            $q->param( 'filename', $pi_fn );
		}
		
        elsif ( $info =~ /^json\/subscribe/ ) {
            $q->param( 'flavor', 'restful_subscribe' );
        }
        elsif ( $info =~ /^js/ ) {

            my ( $pi_flavor, $js_lib, $extran ) = split( '/', $info );

            $q->param( 'flavor', 'js' );

            $q->param( 'js_lib', $js_lib )
              if $js_lib;

        }
        elsif ( $info =~ /^css/ ) {

            my ( $pi_flavor, $css_file, $extran ) = split( '/', $info );

            $q->param( 'flavor', 'css' );

            if ($css_file) {
                $q->param( 'css_file', $css_file );
            }
            else {
                # this is backwards compat.
                $q->param( 'css_file', 'dada_mail.css' );
            }

        }
        elsif ( $info =~ /^captcha_img/ ) {

            my ( $pi_flavor, $pi_img_string, $extran ) = split( '/', $info );

            $q->param( 'flavor', 'captcha_img' );

            $q->param( 'img_string', $pi_img_string )
              if $pi_img_string;

        }
        elsif ( $info =~ /^(s|n|u|ur)/ ) {

            # s is sort of weird.
            # u is an old unsub link - unsub confirmation as well?
            # ur is the alternative form of the unsub link, that gives you a form
            # n is the old sub confirmation
            my ( $pi_flavor, $pi_list, $pi_email, $pi_domain, $pi_pin ) =
              split( '/', $info, 5 );

            if ($pi_email) {
                if ( $pi_email !~ m/\@/ ) {
                    $pi_email = $pi_email . '@' . $pi_domain
                      if $pi_domain;
                    if ( $pi_email =~ m/\=$/ ) {
                        $pi_email =~ s/\=$//;
                    }

                }
                else {
                    $pi_pin = $pi_domain
                      if !$pi_pin;
                }
            }

            if ( $pi_pin eq '=' ) {
                undef $pi_pin;
            }
            if ($pi_list) {
                if ( $pi_list =~ m/\=$/ ) {
                    $pi_list =~ s/\=$//;
                }
            }

            if (   ( $pi_flavor eq 'n' )
                || ( $pi_flavor eq 'u' )
                || ( $pi_flavor eq 'ur' ) )
            {
                $q->param( 'flavor',      'outdated_subscription_urls' );
                $q->param( 'orig_flavor', $pi_flavor )
                  if $pi_flavor;
                $q->param( 'orig_flavor', 'u' )
                  if $pi_flavor eq 'ur';
            }
            else {

                $q->param( 'flavor', $pi_flavor )
                  if $pi_flavor;
            }

            $q->param( 'list', $pi_list )
              if $pi_list;
            $q->param( 'email', $pi_email )
              if $pi_email;

            # pin?
            $q->param( 'pin', $pi_pin )
              if $pi_pin;

        }
        elsif ( $info =~ /^t\// ) {

            my ( $pi_flavor, $pi_token, $etc ) = split( '/', $info, 3 );

            $q->param( 'flavor', 'token' );
            $q->param( 'token',  $pi_token );

        }

        elsif ( $info =~ /^subscribe_form/ ) {

            my ( $pi_flavor, $pi_list ) = split( '/', $info );

            $q->param( 'flavor', $pi_flavor )
              if $pi_flavor;
            $q->param( 'list', $pi_list )
              if $pi_list;
        }

        elsif ( $info =~ /^subscriber_help|^list/ ) {

            my ( $pi_flavor, $pi_list ) = split( '/', $info );

            $q->param( 'flavor', $pi_flavor )
              if $pi_flavor;
            $q->param( 'list', $pi_list )
              if $pi_list;

        }
        elsif ( $info =~ /^r/ ) {

            # my ($pi_flavor, $pi_list, $pi_k, $pi_mid, @pi_url) = split('/', $info);
            my ( $pi_flavor, $pi_list, $pi_key, $pi_email_name, $pi_email_domain, ) = split( '/', $info, 5 );
            my $pi_url;

            $q->param( 'flavor', $pi_flavor )
              if $pi_flavor;

            $q->param( 'list', $pi_list )
              if $pi_list;

            $q->param( 'key', $pi_key )
              if $pi_key;
            my $pi_email = $pi_email_name . '@' . $pi_email_domain
              if $pi_email_name && $pi_email_domain;
            $q->param( 'email', $pi_email )
              if $pi_email;

        }
        elsif ( $info =~ m/^profile/ ) {

            # profile_login
            # profile_activate

            # email is used just to pre-fill in the login form.

            my ( $pi_flavor, $pi_user, $pi_domain, $pi_auth_code ) =
              split( '/', $info, 4 );
            $q->param( 'flavor', $pi_flavor )
              if $pi_flavor;
            $q->param( 'email', $pi_user . '@' . $pi_domain )
              if $pi_user && $pi_domain;
            $q->param( 'auth_code', $pi_auth_code )
              if $pi_auth_code;
        }
        elsif ( $info =~ m/^api/ ) {
            $q->param( 'flavor', 'api' );
        }
        else {
            if ($info) {
                warn "Path Info present - but not valid? - '" . $env->{PATH_INFO} . '" - filtered: "' . $info . '"'
                  unless $info =~ m/^\x61\x72\x74/;
            }
        }
    }
    
    if(!defined($q->param('flavor')) && defined($q->param('f'))){ 
        $q->param('flavor', scalar $q->param('f')); 
    }
    
    return $q;

}

sub DESTROY {}


1;