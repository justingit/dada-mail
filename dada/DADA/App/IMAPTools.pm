package DADA::App::IMAPTools;

use lib "../../";
use lib "../../DADA/perllib";
use lib './';
use lib './DADA/perllib';

use DADA::Config qw(!:DEFAULT);  

use Carp qw(carp croak);
use Fcntl qw(

    :DEFAULT
    :flock
    LOCK_SH
    O_RDONLY
    O_CREAT
    O_WRONLY
    O_TRUNC

);
use Try::Tiny; 

require Exporter; 
@ISA = qw(Exporter); 


use strict; 

use vars qw(@EXPORT); 

@EXPORT = qw(); 


sub imap_login {

    my ($args) = @_;
    my $r = '';

    my $has_net_imap_simple = 1;

    try {
        require Net::IMAP::Simple;
    }
    catch {
        $has_net_imap_simple = 0;
        carp $_;
    };
    if ( $has_net_imap_simple == 0 ) {
        return ( undef, 0,
            'Net::IMAP::Simple will need to be installed for IMAP support.' );
    }

    if ( !exists( $args->{server} ) ) {
        croak "No Server Passed!";
    }

    if ( !exists( $args->{username} ) ) {
        croak "No Username Passed!";
    }

    if ( !exists( $args->{password} ) ) {
        croak "No Password Passed!";
    }

    if ( !exists( $args->{verbose} ) ) {
        $args->{verbose} = 0;
    }

    #if(! exists($args->{AUTH_MODE})){
    #    $args->{AUTH_MODE} = 'POP';
    #}

    if ( !exists( $args->{USESSL} ) ) {
        $args->{USESSL} = 0;
    }

    if ( !exists( $args->{starttls} ) ) {
        $args->{starttls} = 0;
    }
    #
    #if(!exists($args->{SSL_verify_mode})) {
    #	$args->{SSL_verify_mode} = 0;
    #}

    my $SSL = 0;
    if ( $args->{USESSL} == 1 && $args->{starttls} == 0 ) {
        $SSL = 1;
    }

    if ( !exists( $args->{port} ) ) {
        if ( $SSL == 1 ) {
            $args->{port} = '993';
        }
        else {
            $args->{port} = '143';
        }
    }
    elsif ( $args->{port} eq 'AUTO' ) {
        if ( $SSL == 1 ) {
            $args->{port} = '993';
        }
        else {
            $args->{port} = '143';
        }
    }
    #
    #
    #if(!exists($args->{debug})){
    #	$args->{debug} = 0;
    #}
    # Override everything!
    #if($DADA::Config::CPAN_DEBUG_SETTINGS{NET_POP3} == 1){
    #	$args->{debug} = 1;
    #}

    if ( !exists( $args->{ping_test} ) ) {
        $args->{ping_test} = 0;
    }

    $r .= "* Connecting with Net::IMAP::Simple v"
      . $Net::IMAP::Simple::VERSION . "\n";

    if ( length( $args->{server} ) <= 0 ) {
        $r .= 'Server is blank?' . "\n";
        return ( undef, 0, $r );
    }
    else {
		
		
		if($args->{ping_test} == 1){ 
	        my ( $n_p_t_status, $n_p_t_msg );
	        try {
	            ( $n_p_t_status, $n_p_t_msg ) = net_ping_test(
	                $args->{server},
	                $args->{port},
	            );
	        } catch {
	            warn $_;
	        };
			
			$r .= $n_p_t_msg;
			
			if($n_p_t_status == 0){ 
				return ( undef, 0, $r );
			}	
		}
		
		

        $r .=
            "* Connecting to IMAP host:'"
          . $args->{server}
          . "' on port:'"
          . $args->{port} . "'\n";

        my $imap        = undef;
        my $status      = 0;
        my $imap_worked = 1;

        if ( $args->{ping_test} == 1 ) {

            my $imap_worked = 1;
            try {
                require Net::IMAP::Simple;
                $imap = Net::IMAP::Simple->new(
                    $args->{server},
                    use_ssl => $SSL,
                    port    => $args->{port},

                    # debug => 1
                  )
                  or warn
                  "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";
            }
            catch {
                $imap_worked = 0;
                $r .= '* Problems connection to IMAP host: ' . $_ . "\n";
            };
            if ( $imap_worked == 0 ) {
                return ( undef, 0, $r );
            }
        }
        else {
            require Net::IMAP::Simple;
            $imap = Net::IMAP::Simple->new(
                $args->{server},
                use_ssl => $SSL,
                port    => $args->{port},

                # debug => 1
              )
              or warn "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";
        }
        if ( !defined($imap) ) {
            $r .=
                "* Connection to '"
              . $args->{server}
              . "' wasn't successful: "
              . $Net::IMAP::Simple::errstr . "\n";
            return ( undef, 0, $r );
        }
        if ( $args->{starttls} == 1 ) {
            if ( $imap->starttls() ) {
                $r .= "* STARTTLS Succeeded!\n";
            }
            else {
                $r .= "* STARTTLS Failed!\n";
            }
        }
        if ( $imap->login( $args->{username}, $args->{password} ) ) {
            $status = 1;

            #$r .= "* IMAP login successful\n";
        }
        else {
            $r .= "* IMAP login failed: " . $imap->errstr . "\n";
            $imap = undef;
            return ( undef, 0, $r );
        }
        if ( $status == 1 ) {
            my $count = 0;
            $count = $imap->select('INBOX');

            $r .= "\n";
            $r .= "* IMAP Login successful.\n";
            $r .= "* INBOX Message count: " . $count . "\n";
            return ( $imap, 1, $r );
        }
    }
}



sub net_ping_test {

  #  my $self = shift;
    my $host = shift;
    my $port = shift;

    my $status = 1;
	my $can_use_net_ping = 1; 
    try {
        require Net::Ping;
    }
    catch {
        $status = 0;
        $can_use_net_ping = 0; 
    };
	if($can_use_net_ping == 0){ 
		return ( 1, "* Net::Ping not available.\n" );
	}

    my $timeout = 60;
    my $p       = Net::Ping->new("tcp");
    $p->port_number($port);

    # perform the ping
    if ( $p->ping( $host, $timeout ) ) {
        $p->close();
        return ( 1, "* Host $host successfully pinged at port $port.\n" );
    }
    else {
        $p->close();
        return ( 0,
"* Host $host could not be  pinged at port $port. Outbound port may be blocked, or host is down at specified port\n"
        );
    }

}







1;
