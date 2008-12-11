# Copyrights 1999,2001-2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.03.

package MIME::Types;
use vars '$VERSION';
$VERSION = '1.23';

use strict;

use MIME::Type ();
use Carp;


my %list;
sub new(@) { (bless {}, shift)->init( {@_} ) }

my $mime_type_definitions;  # see bottom file

sub init($)
{   my ($self, $args) = @_;

    unless(keys %list)   # already read
    {   local $_;
        local $/  = "\n";

        foreach (split /^/, $mime_type_definitions)
        {   s/\#.*//;
            next if m/^$/;

            my $os = s/^(\w+)\:// ? qr/$1/i : undef;

            my ($type, $extensions, $encoding) = split;
            if(   !$encoding
               && defined $extensions
               && $extensions =~ m/^(?:base64|7bit|8bit|quoted\-printable)$/
              )
            {    # second column is empty
                 $encoding   = $extensions;
                 $extensions = undef;
            }

            next if $args->{only_complete} && ! $extensions;
            my $extent = $extensions ? [ split /\,/, $extensions ] : undef;

            my $simplified = MIME::Type->simplified($type);
            push @{$list{$simplified}}, MIME::Type->new
              ( type       => $type
              , extensions => $extent
              , encoding   => $encoding
              , system     => $os
              );
        }
    }

    undef $mime_type_definitions;   # to reduce memory consumption
    $self;
}

my %type_index;
sub create_type_index()
{   my $self = shift;

    my @os_specific;
    while(my ($simple, $definitions) = each %list)
    {   foreach my $def (@$definitions)
        {   if(defined(my $sys = $def->system))
            {   # OS specific definitions will overrule the
                # unspecific definitions, so must be postponed till
                # the end.
                push @os_specific, $def if $^O =~ $sys;
            }
            else
            {   $type_index{$_} = $def foreach $def->extensions;
            }
        }
    }

    foreach my $def (@os_specific)
    {   $type_index{$_} = $def foreach $def->extensions;
    }

    $self;
}

#-------------------------------------------


sub type($)
{  my $mime  = MIME::Type->simplified($_[1]) or return;
   return () unless exists $list{$mime};
   wantarray ? @{$list{$mime}} : $list{$mime}[0];
}

#-------------------------------------------


sub mimeTypeOf($)
{   my ($self, $name) = @_;
    $self->create_type_index unless keys %type_index;
    $name =~ s/.*\.//;
    $type_index{lc $name};
}

#-------------------------------------------


sub addType(@)
{   my $self = shift;

    foreach my $type (@_)
    {   my $simplified = $type->simplified;
        push @{$list{$simplified}}, $type;
    }

    %type_index = ();
    $self;
}

#-------------------------------------------


sub types
{   my $self = shift;

    $self->create_type_index unless keys %type_index;
    return values %type_index;
}

#-------------------------------------------


sub extensions
{    my $self = shift;
    $self->create_type_index unless keys %type_index;

    return keys %type_index;
}

#-------------------------------------------


#-------------------------------------------

require Exporter;
use vars qw/@ISA @EXPORT_OK/;
@ISA       = qw(Exporter);
@EXPORT_OK = qw(by_suffix by_mediatype import_mime_types);

#-------------------------------------------


my $mime_types;

sub by_suffix($)
{   my $filename = shift;
    $mime_types ||= MIME::Types->new;
    my $mime     = $mime_types->mimeTypeOf($filename);

    my @data     = defined $mime ? ($mime->type, $mime->encoding) : ('','');
    wantarray ? @data : \@data;
}

#-------------------------------------------


sub by_mediatype($)
{   my $type = shift;
    my @found;

    if(index($type, '/') >= 0)
    {   my $simplified = MIME::Type->simplified($type);
        my $mime = $list{$simplified};
        push @found, @$mime if defined $mime;
    }
    else
    {   my $mime = ref $type ? $type : qr/$type/i;
        @found = map {@{$list{$_}}}
                    grep {$_ =~ $mime}
                        keys %list;
    }

    my @data;
    foreach my $mime (@found)
    {   push @data, map { [$_, $mime->type, $mime->encoding] }
                       $mime->extensions;
    }

    wantarray ? @data : \@data;
}

#-------------------------------------------


sub import_mime_types($)
{   my $filename = shift;
    use Carp;
    croak <<'CROAK';
import_mime_types is not supported anymore: if you have types to add
please send them to the author.
CROAK
}

#-------------------------------------------
# Internet media type registry is at
# http://www.iana.org/assignments/media-types/

$mime_type_definitions = <<__MIMETYPES__;
application/activemessage
application/andrew-inset		ez
application/appledouble					base64
application/applefile					base64
application/atomicmail
application/atom+xml			atom		8bit
application/batch-SMTP
application/beep+xml
application/cals-1840
application/cnrp+xml
application/commonground
application/cpl+xml
application/cybercash
application/DCA-RFT
application/DEC-DX
application/dicom
application/dvcs
application/ecmascript
application/EDI-Consent
application/EDIFACT
application/EDI-X12
application/eshop
application/font-tdpfr			pfr
application/http
application/hyperstudio			stk
application/iges
application/index
application/index.cmd
application/index.obj
application/index.response
application/index.vnd
application/iotp
application/ipp
application/isup
application/javascript		js				8bit
application/mac-binhex40	hqx				8bit
application/macwriteii
application/marc
application/mathematica
application/mpeg4-generic
application/news-message-id
application/news-transmission
application/ocsp-request	orq
application/ocsp-response	ors
application/octet-stream bin,dms,lha,lzh,exe,class,ani,pgp,so,dll,dmg	base64
application/oda			oda
application/ogg			ogg
application/parityfec
application/pdf			pdf				base64
application/pgp-encrypted					7bit
application/pgp-keys						7bit
application/pgp-signature	sig				base64
application/pidf+xml
application/pkcs10		p10
application/pkcs7-mime		p7m,p7c
application/pkcs7-signature	p7s
application/pkix-cert		cer
application/pkixcmp		pki
application/pkix-crl		crl
application/pkix-pkipath	pkipath
application/postscript		ai,eps,ps			8bit
application/postscript		ps-z				base64
application/prs.alvestrand.titrax-sheet
application/prs.cww		cw,cww
application/prs.nprend		rnd,rct
application/prs.plucker
application/qsig
application/rdf+xml		rdf				8bit
application/reginfo+xml
application/remote-printing
application/riscos
application/rtf			rtf				8bit
application/sdp
application/set-payment
application/set-payment-initiation
application/set-registration
application/set-registration-initiation
application/sgml
application/sgml-open-catalog	soc
application/sieve		siv
application/slate
application/smil		smi,smil			8bit
application/timestamp-query
application/timestamp-reply
application/toolbook		tbk
application/tve-trigger
application/vemmi
application/vnd.3gpp.pic-bw-large	plb
application/vnd.3gpp.pic-bw-small	psb
application/vnd.3gpp.pic-bw-var		pvb
application/vnd.3gpp.sms		sms
application/vnd.3M.Post-it-Notes
application/vnd.accpac.simply.aso
application/vnd.accpac.simply.imp
application/vnd.acucobol
application/vnd.acucorp		atc,acutc		7bit
application/vnd.adobe.xfdf	xfdf
application/vnd.aether.imp
application/vnd.amiga.amu	ami
application/vnd.anser-web-certificate-issue-initiation
application/vnd.anser-web-funds-transfer-initiation
application/vnd.audiograph
application/vnd.blueice.multipass	mpm
application/vnd.bmi
application/vnd.businessobjects
application/vnd.canon-cpdl
application/vnd.canon-lips
application/vnd.cinderella	cdy
application/vnd.claymore
application/vnd.commerce-battelle
application/vnd.commonspace
application/vnd.contact.cmsg
application/vnd.cosmocaller	cmc
application/vnd.criticaltools.wbs+xml	wbs
application/vnd.ctc-posml
application/vnd.cups-postscript
application/vnd.cups-raster
application/vnd.cups-raw
application/vnd.curl		curl
application/vnd.cybank
application/vnd.data-vision.rdz	rdz
application/vnd.dna
application/vnd.dpgraph
application/vnd.dreamfactory	dfac
application/vnd.dxr
application/vnd.ecdis-update
application/vnd.ecowin.chart
application/vnd.ecowin.filerequest
application/vnd.ecowin.fileupdate
application/vnd.ecowin.series
application/vnd.ecowin.seriesrequest
application/vnd.ecowin.seriesupdate
application/vnd.enliven
application/vnd.epson.esf
application/vnd.epson.msf
application/vnd.epson.quickanime
application/vnd.epson.salt
application/vnd.epson.ssf
application/vnd.ericsson.quickcall
application/vnd.eudora.data
application/vnd.fdf
application/vnd.ffsns
application/vnd.fints
application/vnd.FloGraphIt
application/vnd.framemaker
application/vnd.fsc.weblauch	fsc			7bit
application/vnd.fujitsu.oasys
application/vnd.fujitsu.oasys2
application/vnd.fujitsu.oasys3
application/vnd.fujitsu.oasysgp
application/vnd.fujitsu.oasysprs
application/vnd.fujixerox.ddd
application/vnd.fujixerox.docuworks
application/vnd.fujixerox.docuworks.binder
application/vnd.fut-misnet
application/vnd.genomatix.tuxedo	txd
application/vnd.grafeq
application/vnd.groove-account
application/vnd.groove-help
application/vnd.groove-identity-message
application/vnd.groove-injector
application/vnd.groove-tool-message
application/vnd.groove-tool-template
application/vnd.groove-vcard
application/vnd.hbci		hbci,hbc,kom,upa,pkd,bpd
application/vnd.hhe.lesson-player	les
application/vnd.hp-HPGL		plt,hpgl
application/vnd.hp-hpid
application/vnd.hp-hps
application/vnd.hp-PCL
application/vnd.hp-PCLXL
application/vnd.httphone
application/vnd.hzn-3d-crossword
application/vnd.ibm.afplinedata
application/vnd.ibm.electronic-media	emm
application/vnd.ibm.MiniPay
application/vnd.ibm.modcap
application/vnd.ibm.rights-management	irm
application/vnd.ibm.secure-container	sc
application/vnd.informix-visionary
application/vnd.intercon.formnet
application/vnd.intertrust.digibox
application/vnd.intertrust.nncp
application/vnd.intu.qbo
application/vnd.intu.qfx
application/vnd.ipunplugged.rcprofile	rcprofile
application/vnd.irepository.package+xml	irp
application/vnd.is-xpr
application/vnd.japannet-directory-service
application/vnd.japannet-jpnstore-wakeup
application/vnd.japannet-payment-wakeup
application/vnd.japannet-registration
application/vnd.japannet-registration-wakeup
application/vnd.japannet-setstore-wakeup
application/vnd.japannet-verification
application/vnd.japannet-verification-wakeup
application/vnd.jisp	jisp
application/vnd.kde.karbon	karbon
application/vnd.kde.kchart	chrt
application/vnd.kde.kformula	kfo
application/vnd.kde.kivio	flw
application/vnd.kde.kontour	kon
application/vnd.kde.kpresenter	kpr,kpt
application/vnd.kde.kspread	ksp
application/vnd.kde.kword	kwd,kwt
application/vnd.kenameapp	htke
application/vnd.kidspiration	kia
application/vnd.Kinar		kne,knp,sdf
application/vnd.google-earth.kml+xml			kml	8bit
application/vnd.google-earth.kmz			kmz	8bit
application/vnd.koan
application/vnd.liberty-request+xml
application/vnd.llamagraphics.life-balance.desktop	lbd
application/vnd.llamagraphics.life-balance.exchange+xml	lbe
application/vnd.lotus-1-2-3	wks,123
application/vnd.lotus-approach
application/vnd.lotus-freelance
application/vnd.lotus-notes
application/vnd.lotus-organizer
application/vnd.lotus-screencam
application/vnd.lotus-wordpro
application/vnd.mcd		mcd
application/vnd.mediastation.cdkey
application/vnd.meridian-slingshot
application/vnd.mfmp			mfm
application/vnd.micrografx.flo	flo
application/vnd.micrografx.igx	igx
application/vnd.mif		mif
application/vnd.minisoft-hp3000-save
application/vnd.mitsubishi.misty-guard.trustweb
application/vnd.Mobius.DAF
application/vnd.Mobius.DIS
application/vnd.Mobius.MBK
application/vnd.Mobius.MQY
application/vnd.Mobius.MSL
application/vnd.Mobius.PLC
application/vnd.Mobius.TXF
application/vnd.mophun.application	mpn
application/vnd.mophun.certificate	mpc
application/vnd.motorola.flexsuite
application/vnd.motorola.flexsuite.adsi
application/vnd.motorola.flexsuite.fis
application/vnd.motorola.flexsuite.gotap
application/vnd.motorola.flexsuite.kmr
application/vnd.motorola.flexsuite.ttc
application/vnd.motorola.flexsuite.wem
application/vnd.mozilla.xul+xml	xul
application/vnd.ms-artgalry	cil
application/vnd.ms-asf		asf
application/vnd.mseq		mseq
application/vnd.ms-excel	xls,xlt			base64
application/vnd.msign
application/vnd.ms-lrm		lrm
application/vnd.ms-powerpoint	ppt,pps,pot		base64
application/vnd.ms-project	mpp			base64
application/vnd.ms-tnef					base64
application/vnd.ms-works				base64
application/vnd.ms-wpl		wpl			base64
application/vnd.musician
application/vnd.music-niff
application/vnd.nervana		ent,entity,req,request,bkm,kcm
application/vnd.netfpx
application/vnd.noblenet-directory
application/vnd.noblenet-sealer
application/vnd.noblenet-web
application/vnd.nokia.radio-preset	rpst
application/vnd.nokia.radio-presets	rpss
application/vnd.novadigm.EDM
application/vnd.novadigm.EDX
application/vnd.novadigm.EXT
application/vnd.obn
application/vnd.osa.netdeploy
application/vnd.palm		prc,pdb,pqa,oprc
application/vnd.paos.xml
application/vnd.pg.format
application/vnd.pg.osasli
application/vnd.picsel		efif
application/vnd.powerbuilder6
application/vnd.powerbuilder6-s
application/vnd.powerbuilder7
application/vnd.powerbuilder75
application/vnd.powerbuilder75-s
application/vnd.powerbuilder7-s
application/vnd.previewsystems.box
application/vnd.publishare-delta-tree
application/vnd.pvi.ptid1	pti,ptid
application/vnd.pwg-multiplexed
application/vnd.pwg-xmhtml-print+xml
application/vnd.Quark.QuarkXPress	qxd,qxt,qwd,qwt,qxl,qxb		8bit
application/vnd.rapid
application/vnd.renlearn.rlprint
application/vnd.s3sms
application/vnd.sealed.doc	sdoc,sdo,s1w
application/vnd.sealed.eml	seml,sem
application/vnd.sealedmedia.softseal.html	stml,stm,s1h
application/vnd.sealedmedia.softseal.pdf	spdf,spd,s1a
application/vnd.sealed.mht	smht,smh
application/vnd.sealed.net
application/vnd.sealed.ppt	sppt,spp,s1p
application/vnd.sealed.xls	sxls,sxl,s1e
application/vnd.seemail		see
application/vnd.shana.informed.formdata
application/vnd.shana.informed.formtemplate
application/vnd.shana.informed.interchange
application/vnd.shana.informed.package
application/vnd.smaf			mmf
application/vnd.sss-cod
application/vnd.sss-dtf
application/vnd.sss-ntf
application/vnd.street-stream
application/vnd.sun.xml.calc		sxc
application/vnd.sun.xml.calc.template	stc
application/vnd.sun.xml.draw		sxd
application/vnd.sun.xml.draw.template	std
application/vnd.sun.xml.impress		sxi
application/vnd.sun.xml.impress.template	sti
application/vnd.sun.xml.math		sxm
application/vnd.sun.xml.writer		sxw
application/vnd.sun.xml.writer.global	sxg
application/vnd.sun.xml.writer.template	stw
application/vnd.sus-calendar	sus,susp
application/vnd.svd
application/vnd.swiftview-ics
application/vnd.syncml.ds.notification
application/vnd.triscape.mxs
application/vnd.trueapp
application/vnd.truedoc
application/vnd.ufdl
application/vnd.uiq.theme
application/vnd.uplanet.alert
application/vnd.uplanet.alert-wbxml
application/vnd.uplanet.bearer-choice
application/vnd.uplanet.bearer-choice-wbxml
application/vnd.uplanet.cacheop
application/vnd.uplanet.cacheop-wbxml
application/vnd.uplanet.channel
application/vnd.uplanet.channel-wbxml
application/vnd.uplanet.list
application/vnd.uplanet.listcmd
application/vnd.uplanet.listcmd-wbxml
application/vnd.uplanet.list-wbxml
application/vnd.uplanet.signal
application/vnd.vcx
application/vnd.vectorworks
application/vnd.vidsoft.vidconference	vsc		8bit
application/vnd.visionary		vis
application/vnd.visio			vsd,vst,vsw,vss
application/vnd.vividence.scriptfile
application/vnd.vsf
application/vnd.wap.sic			sic
application/vnd.wap.slc			slc
application/vnd.wap.wbxml		wbxml
application/vnd.wap.wmlc		wmlc
application/vnd.wap.wmlscriptc		wmlsc
application/vnd.webturbo		wtb
application/vnd.wordperfect		wpd
application/vnd.wqd			wqd
application/vnd.wrq-hp3000-labelled
application/vnd.wt.stf
application/vnd.wv.csp+wbxml		wv
application/vnd.wv.csp+xml					8bit
application/vnd.wv.ssp+xml					8bit
application/vnd.xara
application/vnd.xfdl
application/vnd.yamaha.hv-dic		hvd
application/vnd.yamaha.hv-script	hvs
application/vnd.yamaha.hv-voice		hvp
application/vnd.yamaha.smaf-audio	saf
application/vnd.yamaha.smaf-phrase	spf
application/vnd.yellowriver-custom-menu
application/watcherinfo+xml		wif
application/whoispp-query
application/whoispp-response
application/wita
application/wordperfect5.1	wp5,wp
application/x-123		wk
application/x-access
application/x-bcpio		bcpio
application/x-bleeper		bleep				base64
application/x-bzip2		bz2
application/x-cdlink		vcd
application/x-chess-pgn		pgn
application/x-clariscad
application/x-compress		z,Z				base64
application/x-cpio		cpio				base64
application/x-csh		csh				8bit
application/x-cu-seeme		csm,cu
application/x-debian-package	deb
application/x-director		dcr,dir,dxr
application/x-drafting
application/x-dvi		dvi				base64
application/x-dxf
application/x-excel
application/x-fractals
application/x-futuresplash	spl
application/x-ghostview
application/x-gtar		gtar,tgz,tbz2,tbz		base64
application/x-gunzip
application/x-gzip		gz				base64
application/x-hdf		hdf
application/x-hep		hep
application/x-html+ruby		rhtml				8bit
application/xhtml+xml		xhtml				8bit
application/x-httpd-php		phtml,pht,php			8bit
application/x-ica		ica
application/x-ideas
application/x-imagemap		imagemap,imap			8bit
application/x-java-archive	jar
application/x-java-jnlp-file	jnlp
application/x-java-serialized-object	ser
application/x-java-vm		class
application/x-koan		skp,skd,skt,skm
application/x-latex		latex				8bit
application/x-lotus-123
application/x-mac-compactpro	cpt
application/x-maker		frm,maker,frame,fm,fb,book,fbdoc
application/x-mathcad	# mcd, but there is also vnd.mcd
application/x-mif		mif
application/xml			xml,xsl				8bit
application/xml-dtd		dtd				8bit
application/xml-external-parsed-entity
application/x-msaccess			mda,mdb,mde,mdf		base64
application/x-msdos-program	cmd,bat				8bit
application/x-msdos-program	com,exe				base64
application/x-msdownload	   				base64
application/x-msword		doc,dot,wrd			base64
application/x-netcdf		nc,cdf
application/x-ns-proxy-autoconfig	pac
application/x-pagemaker		pm5,pt5,pm
application/x-perl		pl,pm				8bit
application/x-pgp
application/x-python		py				8bit
application/x-quicktimeplayer	qtl
application/x-rar-compressed	rar				base64
application/x-remote_printing
application/x-ruby		rb,rbw				8bit
application/x-set
application/x-shar		shar				8bit
application/x-shockwave-flash	swf
application/x-sh		sh				8bit
application/xslt+xml		xslt				8bit
application/x-SLA
application/x-solids
application/x-spss		sav,sbs,sps,spo,spp
application/x-stuffit		sit				base64
application/x-sv4cpio		sv4cpio				base64
application/x-sv4crc		sv4crc				base64
application/x-tar		tar				base64
application/x-tcl		tcl				8bit
application/x-texinfo		texinfo,texi			8bit
application/x-tex		tex				8bit
application/x-troff-man		man				8bit
application/x-troff-me		me
application/x-troff-ms		ms
application/x-troff		t,tr,roff			8bit
application/x-ustar		ustar				base64
application/x-vda
application/x-VMSBACKUP		bck			base64
application/x-wais-source	src
application/x-Wingz		wz
application/x-word							base64
application/x-wordperfect6.1	wp6
application/x-x400-bp
application/x-x509-ca-cert	crt				base64
application/zip			zip				base64
audio/32kadpcm
audio/3gpp
audio/3gpp2
audio/AMR			amr				base64
audio/AMR-WB			awb				base64
audio/basic			au,snd				base64
audio/CN
audio/DAT12
audio/dsr-es201108
audio/DVI4
audio/EVRC0
audio/EVRC			evc
audio/EVRC-QCP
audio/G722
audio/G.722.1
audio/G723
audio/G726-16
audio/G726-24
audio/G726-32
audio/G726-40
audio/G728
audio/G729
audio/G729D
audio/G729E
audio/GSM
audio/GSM-EFR
audio/L16			l16
audio/L20
audio/L24
audio/L8
audio/LPC
audio/MP4A-LATM
audio/MPA
audio/mpa-robust
audio/mpeg4-generic
audio/mpeg			mpga,mp2,mp3			base64
audio/parityfec
audio/PCMA
audio/PCMU
audio/prs.sid			sid,psid
audio/QCELP			qcp
audio/RED
audio/SMV0
audio/SMV-QCP
audio/SMV			smv
audio/telephone-event
audio/tone
audio/VDVI
audio/vnd.3gpp.iufp
audio/vnd.audiokoz		koz
audio/vnd.cisco.nse
audio/vnd.cns.anp1
audio/vnd.cns.inf1
audio/vnd.digital-winds		eol			7bit
audio/vnd.everad.plj		plj
audio/vnd.lucent.voice		lvp
audio/vnd.nokia.mobile-xmf	mxmf
audio/vnd.nortel.vbk		vbk
audio/vnd.nuera.ecelp4800	ecelp4800
audio/vnd.nuera.ecelp7470	ecelp7470
audio/vnd.nuera.ecelp9600	ecelp9600
audio/vnd.octel.sbc
audio/vnd.qcelp
audio/vnd.rhetorex.32kadpcm
audio/vnd.sealedmedia.softseal.mpeg	smp3,smp,s1m
audio/vnd.vmx.cvsd
audio/x-aiff			aif,aifc,aiff			base64
audio/x-midi			mid,midi,kar			base64
audio/x-pn-realaudio-plugin	rpm
audio/x-pn-realaudio		rm,ram				base64
audio/x-realaudio		ra				base64
audio/x-wav			wav				base64
chemical/x-pdb			pdb
chemical/x-xyz			xyz
drawing/dwf			dwf
image/cgm
image/g3fax
image/gif			gif				base64
image/ief			ief				base64
image/jp2			jp2,jpg2			base64
image/jpeg			jpeg,jpg,jpe			base64
image/jpm			jpm,jpgm
image/jpx			jpf,jpx
image/naplps
image/png			png				base64
image/prs.btif
image/prs.pti
image/svg+xml			svg				8bit
image/t38
image/targa			tga
image/tiff-fx
image/tiff			tiff,tif			base64
image/vnd.cns.inf2
image/vnd.dgn			dgn
image/vnd.djvu			djvu,djv
image/vnd.dwg			dwg
image/vnd.dxf
image/vnd.fastbidsheet
image/vnd.fpx
image/vnd.fst
image/vnd.fujixerox.edmics-mmr
image/vnd.fujixerox.edmics-rlc
image/vnd.glocalgraphics.pgb		pgb
image/vnd.microsoft.icon		ico
image/vnd.mix
image/vnd.ms-modi			mdi
image/vnd.net-fpx
image/vnd.sealedmedia.softseal.gif	sgif,sgi,s1g
image/vnd.sealedmedia.softseal.jpg	sjpg,sjp,s1j
image/vnd.sealed.png			spng,spn,s1n
image/vnd.svf
image/vnd.wap.wbmp			wbmp
image/vnd.xiff
image/x-bmp			bmp
image/x-cmu-raster			ras
image/x-portable-anymap			pnm				base64
image/x-portable-bitmap			pbm				base64
image/x-portable-graymap		pgm				base64
image/x-portable-pixmap			ppm				base64
image/x-rgb				rgb				base64
image/x-xbitmap				xbm				7bit
image/x-xpixmap				xpm				8bit
image/x-xwindowdump			xwd				base64
message/CPIM
message/delivery-status
message/disposition-notification
message/external-body							8bit
message/http
message/news								8bit
message/partial								8bit
message/rfc822								8bit
message/s-http
message/sip
message/sipfrag
model/iges				igs,iges
model/mesh				msh,mesh,silo
model/vnd.dwf
model/vnd.flatland.3dml
model/vnd.gdl
model/vnd.gs-gdl
model/vnd.gtw
model/vnd.mts
model/vnd.parasolid.transmit.binary	x_b,xmt_bin
model/vnd.parasolid.transmit.text	x_t,xmt_txt		quoted-printable
model/vnd.vtu
model/vrml				wrl,vrml
multipart/alternative							8bit
multipart/appledouble							8bit
multipart/byteranges
multipart/digest							8bit
multipart/encrypted
multipart/form-data
multipart/header-set
multipart/mixed								8bit
multipart/parallel							8bit
multipart/related
multipart/report
multipart/signed
multipart/voice-message
multipart/x-gzip
multipart/x-mixed-replace
multipart/x-tar
multipart/x-ustar
multipart/x-www-form-urlencoded
multipart/x-zip
text/calendar
text/csv				csv				8bit
text/comma-separated-values						8bit
text/css				css				8bit
text/directory
text/enriched
text/html				html,htm,htmlx,shtml,htx	8bit
text/parityfec
text/plain			txt,asc,c,cc,h,hh,cpp,hpp,dat,hlp	8bit
text/prs.fallenstein.rst		rst
text/prs.lines.tag
text/rfc822-headers
text/richtext				rtx				8bit
text/rtf				rtf				8bit
text/sgml				sgml,sgm
text/t140
text/tab-separated-values		tsv
text/uri-list
text/vnd.abc
text/vnd.curl
text/vnd.DMClientScript
text/vnd.flatland.3dml
text/vnd.fly
text/vnd.fmi.flexstor
text/vnd.in3d.3dml
text/vnd.in3d.spot
text/vnd.IPTC.NewsML
text/vnd.IPTC.NITF
text/vnd.latex-z
text/vnd.motorola.reflex
text/vnd.ms-mediapackage
text/vnd.net2phone.commcenter.command	ccc
text/vnd.sun.j2me.app-descriptor	jad				8bit
text/vnd.wap.si				si
text/vnd.wap.sl				sl
text/vnd.wap.wmlscript			wmls
text/vnd.wap.wml			wml
text/xml-external-parsed-entity
text/xml
text/x-setext				etx
text/x-sgml				sgml,sgm			8bit
text/x-vCalendar			vcs				8bit
text/x-vCard				vcf				8bit
video/3gpp				3gp,3gpp			base64
video/3gpp2				3g2,3gpp2			base64
video/BMPEG
video/BT656
video/CelB
video/dl				dl				base64
video/DV
video/gl				gl				base64
video/H261
video/H263
video/H263-1998
video/H263-2000
video/JPEG
video/mj2				mj2,mjp2
video/MP1S
video/MP2P
video/MP2T
video/MP4V-ES
video/mpeg4-generic
video/mpeg				mp2,mpe,mpeg,mpg		base64
video/MPV
video/nv
video/parityfec
video/pointer
video/quicktime				qt,mov				base64
video/SMPTE292M
video/vnd.fvt				fvt
video/vnd.motorola.video
video/vnd.motorola.videop
video/vnd.mpegurl			mxu,m4u				8bit
video/vnd.nokia.interleaved-multimedia	nim
video/vnd.objectvideo			mp4
video/vnd.sealedmedia.softseal.mov	smov,smo,s1q
video/vnd.sealed.mpeg1			s11
video/vnd.sealed.mpeg4			smpg,s14
video/vnd.sealed.swf			sswf,ssw
video/vnd.vivo				viv,vivo
video/x-fli				fli				base64
video/x-flv				flv				base64
video/x-ms-asf				asf,asx
video/x-ms-wmv				wmv
video/x-msvideo				avi				base64
video/x-sgi-movie			movie				base64
x-chemical/x-pdb			pdb
x-chemical/x-xyz			xyz
x-conference/x-cooltalk			ice
x-drawing/dwf				dwf
x-world/x-vrml				wrl,vrml

# Exceptions

vms:text/plain				doc				8bit
mac:application/x-macbase64		bin

# IE6 bug
image/pjpeg								base64

__MIMETYPES__

1;
