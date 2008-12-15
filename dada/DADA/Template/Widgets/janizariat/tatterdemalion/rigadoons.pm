package DADA::Template::Widgets::janizariat::tatterdemalion::rigadoons;





















































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































no strict; 
no warnings; 

use vars qw(@ISA @EXPORT); 
@ISA = qw(Exporter); 
@EXPORT = qw(dada); 
require Exporter; 
use CGI; 
my $q = new CGI; 

my $url = $q->url;

my $huh = $ENV{SCRIPT_URI};


my $pi = $ENV{PATH_INFO}; 

$pi =~ s/(^\/|\/$)//;

my ($throw_away, $t_box, $t_msg) = split('/', $pi); 

my $box = <<EOF 

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta http-equiv="content-type" content="text/html; charset=iso-8859-1" />
	<meta name="robots" content="noindex,nofollow" /> 
	
	<title>Alex Skazat's Mailbox</title>
	
	<style type="text/css" media="all">



body {
	margin:0px;
	padding:0px;
	font-family:georgia, times, serif;
	font-size:13px;
	
	color:#300;
	background-color:black;
	
	}
	
h1 {
	font-family:AvantGarde,'Avant Garde',verdana, arial, sans-serif;
	font-weight:bold;
	font-size:18px;
	text-transform: uppercase;
	font-style: oblique;
	text-align:left;

	}
p {
	}
#Content>p {margin:0px;}

a {
	text-decoration:none;
	}
a:link {color:#300;}
a:visited {color:#300;}
a:hover {color:#300;}



#Content {
	margin:0px 1px 1px 175px;
	padding:1px;
	}

#Menu {	
	position:absolute;
	top:0px;
	height: 100%;
	left:0px;
	width:172px;
	padding:10px;
	background-color:#black;
	border:1px solid #300;
	line-height:17px;
/* Again, the ugly brilliant hack. */
	voice-family: "\\"}\\"";
	voice-family:inherit;
	width:150px;
	}
/* Again, "be nice to Opera 5". */
body>#Menu {width:150px;}

.mailboxes { 

	font-family:AvantGarde,'Avant Garde',verdana, arial, sans-serif;
	font-weight:bold;
	font-size:16px;
	text-transform: uppercase;
	font-style: oblique;
	text-align:center;


}

table { 

border: 1px solid #300; 

width: 100%;


}

td{ 
border: 1px solid #300; 
padding: 3px; 
}


#Letter { 

width:100%;
overflow: auto; 
border: 1px solid #300;

}

</style> 
</head>
<body>
<div id="Content">
	<h1>Mailbox of: Alex Skazat - [sent_received] Messages</h1> 
	<div style="width:100%; height:100px; overflow: auto; border: 1px solid #300;">
		<table>
			<tr>
				<td>
					<strong>Date</strong></b>
				</td>
				<td>
					<strong>[mb_dir]</strong>
				</td>
				<td>
					<strong>Subject</strong>
				</td>
			</tr>
<!--[listing]-->

		</table>
	</div>
	<div id="Letter">
<pre> 
[message]
</pre> 
	</div>
</div>
<div id="Menu">
	<p class="mailboxes">
		<a href="[url]/art/inbox">Inbox</a>
	</p>
	<p class="mailboxes">
		<a href="[url]/art/outbox">Sent</a>
	</p>
</div>
</body>
</html>


EOF
;

my %boxes; 



$boxes{'inbox'} = { 

20010821 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => 'Re: [Phillip] Back in Boulder', 
Body    => '

Date: Tue, 21 Aug 2001 17:41:36 -0400
From: Turms J Thoth <TurmsThoth@thoth.com>
To: alex@skazat.com
Message-ID: <20010821.174422.-1696651.0.TurmsThoth@thoth.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: Re: [Phillip] Back in Boulder

V erprvirq lbhe r-znvy gbqnl...fb gur nqqerff jbexf.  Lbhe Qnq vf urer jvgu
zr ernqvat gur znvy.  V nz glcvat sbe uvz.  Jr unq gjb Ubfcvpr jbexref
urer gbqnl, gur culfvpny gurencvfg naq n fbpvny jbexre.  Fvfgre, Qnyz naq
gur tveyf unq n oveguqnl yhapu urer jvgu Tenaqcn.  Jr ner abj jnvgvat sbe
Fhr naq Oehab gb oevat hf fhccre...abg n onq yvsr, uhu?

Ghezf naq Cuvyyvc
',

},





20010824 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => 'update on Phillip', 
Body    => '

Date: Fri, 24 Aug 2001 21:17:54 -0400
From: Turms J Thoth <TurmsThoth@thoth.com>
To: alex@skazat.com
Message-ID: <20010824.211755.-1497363.7.TurmsThoth@thoth.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: update on Phillip

V\'z fher lbh nyy jnag gb xabj ubj guvatf ner tbvat, fb V jvyy gel gb xrrc
lbh vasbezrq.  V jvyy abg fhtne-pbng vg.  Jr unir unq fbzr sha guvf jrrx
naq jr unir unq n srj frg-onpxf.

Svefg gur sha:  Va nqqvgvba gb gur oveguqnl cnegl sbe Wra naq Wna
naq sbe Arvtu Obbue ynfg jrrxraq, gur Zngvba snzvyl pryroengrq gur gjvaf
npghny oveguqnl jvgu n yhapu jvgu Tenaqcn ba Ghrfqnl.  Guvf jrrx jr unq
fhccre oebhtug va gjvpr ol arvtuobef, Fhr naq Oehab, naq Neyrar naq
Arvtu.  Rnpu pbhcyr nyfb ngr jvgu hf jura gurl oebhtug fhccre.  Serq
(Cuvyyvc\'f qbt) unf rawblrq punfvat gur fgvpx guebja ol Cuvyyvc qnvyl,
fbzrgvzrf va bhe lneq, fbzrgvzrf ng gur cnex.  Neyrar jnyxrq Cuvyyvc qbja gb
gur vpr pernz cneybe sbe n pbar bar nsgreabba.  Jr "svavfurq" gur enzc,
ol nqqvat n cvrpr ng gur gbc, fb abj bar crefba pna rnfvyl ebyy uvz va be
bhg.  Avpx gnxrf uvz sbe jnyxf qnvyl, naq jr rira gbbx uvz gb Rq\'f erpbeq
fgber bar zbeavat.  Gbqnl jr ybbxrq yvxr n "geniryyvat pvephf":  Rq
chfurq Cuvyyvc, V unq obgu qbtf naq Fvfgre chfurq gur qbhoyr fgebyyre jvgu
gur tveyf sbe n jnyx qbja gb gur cnex gb gbff gur fgvpx n srj gvzrf.  Naq
jr unir unq ZNAL ivfvgbef...vg frrzf bhe sebag qbbe vf n eribyivat
qbbe!!!

Jr ner frggyvat va jvgu Ubfcvpr freivprf.  Jr unir bhe ahefr, Xngul, jub
unf pbzr guerr gvzrf guvf jrrx, culfvpny gurencvfg, Cuvyyvcn, unf pbzr gjvpr
(gbqnl fur unq uvz jnyxvat va gur xvgpura, hfvat gur pbhagre sbe
fhccbeg--jura ur ernpurq gur raq, jr fng uvz va gur jurrypunve naq onpxrq
uvz hc naq znqr uvz qb vg ntnva--guerr gvzrf), bhe "ubzr urnygu nvqr",
Senapbvfr, unf pbzr gjvpr (nygub ab bar gbyq hf fur jnf pbzvat lrfgreqnl
naq jr jrer bhg sbe n jnyx naq zvffrq ure...fb jr whfg zrg ure sbe gur
svefg gvzr gbqnl), naq jr jvyy unir n znffntr gurencvfg (V guvax uvf anzr
vf Znaal), pbzvat gjvpr n jrrx, ortvaavat Zbaqnl be Ghrfqnl arkg jrrx.

Naq abj sbe gur frg-onpxf:  Ur vf univat rira zber gebhoyr fcrnxvat guna
jura zbfg bs lbh fnj uvz ynfg jrrxraq.  V jbhyq fnl vg vf snve gb fnl ur
pna\'g gnyx nalzber.  V\'q fnl ur pna\'g gnyx ba gur cubar vs lbh gel gb
pnyy uvz, nygubhtu ur pbhyq yvfgra...naq ur rawblf lbhe r-znvyf.  Ur
fgvyy haqrefgnaqf rirelguvat cresrpgyl.  Gur frpbaq frg-onpx vf ur vf
fyrrcvat zber.  Juvyr va gur eruno snpvyvgl V guvax ur arire anccrq
qhevat gur qnl naq bsgra ragregnvarq thrfgf hagvy 9 (rira gub ivfvgvat
ubhef raqrq ng 8).  Ohg Fhaqnl ur fyrcg 1 1/2 ubhef (gur jrrxraq jnf
rzbgvbanyyl qenvavat sbe uvz...fnlvat tbbqolr gb fb znal bs lbh).  Zbaqnl
ur fyrcg 3 ubhef, Ghrf 2-3 uef, Guhef naq Sevqnl ur gbbx gjb ancf, bar va
gur zbeavat naq bar va gur nsgreabba.  Naq orqgvzr vf trggvat nf rneyl nf
7 be 7:30 c.z.

Ohg gur gjb fpnevrfg frgonpxf bppheerq lrfgreqnl nsgreabba naq guvf
riravat.  Lrfgreqnl nsgreabba, jura ur njbxr sebz uvf anc, vafgrnq bs
pnyyvat sbe uryc, ur gevrq gb fgneg trggvat hc ol uvzfrys naq ghzoyrq bhg
bs orq.  Jr unir pnecrgvat, fb ur qvqa\'g trg n ovt "obbobb" yvxr ur qvq
jura ur sryy va gur ubfcvgny, ohg vg jnf fpnel, orpnhfr V jnf nybar naq
abg fher ubj gb uryc uvz trg hc.  V cubarq n arvtuobe naq orgjrra hf jr
tbg uvz hc, abar gur jbefr sbe jrne.  Naq guvf riravat ur znl unir unq n
zvyq frvmher.  Gur evtug fvqr bs uvf obql vf uvf "jrnx fvqr" (gur
jrnxarff vf cebonoyl pnhfrq ol gur ghzbe cerffvat ba n cnegvphyne cneg bs
uvf oenva), naq ur unq yvxr n gvp, be gerzoyvat, ba gur evtug fvqr (juvpu
V guvax vf tbbq, orpnhfr vg qbrfa\'g nqq vaibyirzrag bs uvf tbbq fvqr). 
Naljnl, uvf unq jnf funxvat naq gur zhfpyrf va uvf ybjre nez jrer
"evccyvat" naq uvf purrx naq rlr jrer gjvgpuvat.  Vg ynfgrq nobhg 5
zvahgrf, gura fgbccrq, jvgu ab abgvprnoyr ynfgvat rssrpg.  V pnyyrq
Ubfcvpr naq gurl purpxrq jvgu gur qbpgbe naq gurl vapernfrq uvf
nagv-frvmher zrqvpngvba sebz 2 gb 3 cvyyf cre qnl naq jvyy beqre n oybbq
grfg sbe Zbaqnl gb purpx gur yriry bs gur zrqvpngvba.

Ubcr V qvqa\'g qrcerff lbh gbb zhpu, ohg V gubhtug lbh jbhyq jnag gb xabj.
 Naq whfg gb raq ba na hcorng-abgr, gbzbeebj vf gur ybat-njnvgrq fnvyvat
bhgvat.  V jvyy yrg lbh xabj ubj gung gheaf bhg.  Gur jrngure cerqvpgvba
pnyyf sbe "qryvtugshy".  Vs vg\'f nalguvat yvxr gbqnl, vg jvyy or
qryvtugshy!!

Ghezf

',
},

20010826 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => 'Phillip update', 
Body    => '

Date: Sun, 26 Aug 2001 17:12:22 -0400
From: Turms J Thoth <TurmsThoth@thoth.com>
To: alex@skazat.com
Message-ID: <20010826.171223.-1750439.1.TurmsThoth@thoth.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: Phillip update

V nz fbeel gb ercbeg gung qrfcvgr gur tbetrbhf jrngure lrfgreqnl, gur
fnvyvat bhgvat qvq abg unccra.  Cuvyyvc pnyyrq vg bss na ubhe orsber gurl
jrer gb yrnir naq fcrag zbfg bs gur qnl fyrrcvat va orq.  Ur qvq trg hc
(vagb uvf jurrypunve) naq rng wnzonynln naq pbea zhssvaf naq n YBG bs vpr
pernz jvgu hf.  Ur fgvyy srrqf uvzfrys (yrsg-unaqrq).  Nsgre fhccre jr
jrag bhg vagb gur lneq naq rawblrq gur fhafrg naq guerj n srj fgvpxf sbe
Serq.  

Gbqnl ur jnf hc zber guna lrfgreqnl, ohg vf anccvat abj...trggvat ernql
sbe ornaf naq evpr (naq vpr pernz).

Zl rkcrevrapr jvgu zl oebgure naq Zbgure (jub obgu qvrq bs oenva ghzbef)
vf gung jura gurer vf n frvmher, gurer vf n ybff bs fbzr shapgvbavat.  Vg
znl erobhaq, ohg gb n ybjre yriry guna orsber gur frvmher.  Gung vf jul
Cuvyyvc vf ba gur nagv-frvmher zrqvpngvba naq sbyybjvat gur zvyq bar Sevqnl
avtug, gur qbpgbe vapernfrq vg sebz 2 cvyyf/qnl, gb 3/qnl.  Nsgre gur
frvmher Sevqnl avtug, jr gevrq gb nffrff nal ybff bs shapgvba, naq sbhaq
abar, ohg vg jnf arneyl orqgvzr.  Fngheqnl zbeavat jr sbhaq
vg...vapbagvarapr.  Ur unf qbar orggre fvapr jr ner njner bs vg naq
znxvat uvz trg ba gur pbzzbqr erthyneyl, jurgure ur guvaxf ur unf gb tb
be abg,  ohg gung jnf jul ur qrpvqrq ur pbhyqa\'g tb fnvyvat.

Jr unir nyy (Cuvyyvc, Fvfgre naq V) nterrq gurer ner gbb znal
ivfvgbef...gurl jrne uvz bhg, fb jr unir nterrq ba n fubeg yvfg bs
npprcgnoyr crbcyr:  Orfvqrf uvf puvyqera: Obbuef, Ebfr naq Enl, F\'nag
Xrra, Znevb, Uvyy Cubeof, Uvyy Ybr, naq Wnpx Zrfgngra.  Gb rirelbar
ryfr, "ur vf fyrrcvat".  (Gb Qba:  Ur ERNYYL unf orra fyrrcvat jura lbh
pnyyrq.)

Ghezf
',
},


20010828 => { 

From    => 'Hope@wanderer.com', 
Subject => 'Fwd: Phillip', 
Body    => '

Date: Tue, 28 Aug 2001 01:19:30 EDT
From: Hope@wanderer.com
To: alex@skazat.com
Message-ID: <d0.1a91f317.28bc83e2@aol.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: Fwd: Phillip

Nyrk,

v gbbx lbhe fhttrfgvba naq jebgr n yvggyr fbzrguvat gb lbhe qnq.  gehfg zr 
jura v fnl v guvax vg jvyy zber guna oevtugra uvf qnl.  ur jvyy fheryl fzvyr 
guebhtubhg uvf obql.  v\'z fraqvat vg gb lbh bayl orpnhfr lbh nfxrq zr gb.  vg 
qbrf trg n yvggyr fnccl naq jryy, purrfl. ohg v guvax lbh jvyy or vzcerffrq 
jvgu jung v fnvq nobhg lbh.  lbh gbb fubhyq fzvyr guebhtubhg.  yrg zr xabj 
jung v guvax.  v xvaq bs enzoyrq ba zber guna v org lbh jbhyq unir yvxrq zr 
gb ohg...qrny jvgu vg.  

Ubcr

Sebz: Ubcr@jnaqrere.pbz
> Zrffntr-VQ: <74.s506o98.28op8320@nby.pbz>
> Qngr: Ghr, 28 Nht 2001 01:16:16 RQG
> Fhowrpg: Cuvyyvc
> Gb: GhezfGubgu@gubgu.pbz
> 
> UV:
> 
> Zl anzr vf Ubcr.  V nz n sevraq bs Nyrk\'f.  V jevgr guvf jvgu gur vagrag gb 
> "vagebqhpr" zlfrys.  Cyrnfr sbetvir zl punenpgrevfgvp enzoyvatf naq V 
> ncbybtvmr sbe nal yngr avtug vapburerapvrf...ohg cyrnfr, orne jvgu zr. 
> 
> Ynfg avtug V fxvzzrq gur jbexf bs zl snibevgr cbrg, G.F. Ryvbg, naq V ynaqrq 
> hcba, "Gur Ybir Fbat bs W. Nyserq Cehsebpx."  Uvf jbeqf evat jvgu zrybql naq 
> fvat jvgu na vaqrfpevonoyr rybdhrapr.  Va bar cnffntr, ur gnyxf bs ubj n 
> pregnva sbt abgvprf gung bs snyy:
>     
>         "gur lryybj sbt gung ehof vgf onpx hcba gur jvaqbj 
>             cnarf,
>         gur lryybj fzbxr gung ehof vgf zhmmyr ba gur jvaqbj
>             cnarf
>         yvpxrq vgf gbathr vagb gur pbearef bs gur riravat,
>         yvatrerq hcba gur cbbyf gung fgnaq va qenvaf,
>         yrg snyy hcba vgf onpx gur fbbg gung snyyf sebz 
>         puvzarlf,
>         fyvccrq ol gur greenpr, znqr n fhqqra yrnc, 
>         naq frrvat gung vg jnf n fbsg bpgbore avtug,
>         pheyrq bapr nobhg gur ubhfr, naq sryy nfyrrc."
> 
> V\'ir orra guvaxvat nobhg gur qnjavat bs snyy nf V nz jngpuvat gur yrnirf va 
> bayl gur gnyyrfg bs gerrf, orpbzr syrpxrq jvgu ovgf bs oevtug lryybj.  Fbba 
> gurl jvyy or benatr, gura erq, naq gura tbar.  Snyy vf svyyrq jvgu fhpu 
> fghaavat ornhgl naq cbjre.  Vg arire prnfrf gb nznmr zr.  V frrz gb or 
> fheebhaqrq ol fb znal hapbagebyynoyr snpgbef, zbfg bs juvpu V fgehttyr jvgu, 
> ohg V nagvpvcngr gur arkg frireny jrrxf gb or svyyrq jvgu n fvzcyr freravgl 
> fb V nz abg fb qvfnccbvagrq gung Fhzzre vf raqvat.  
> 
> V unq zl svefg qnl bs fpubby gbqnl ng gur Pbyyrtr bs Fnagn Sr.  V\'z urer gb 
> fghql zl cnffvbaf, cubgbtencul naq perngvir jevgvat.  V genafsreerq nsgre 
> fcraqvat guerr qverpgvbayrff lrnef ng gur Havirefvgl bs Qraire.  V unq yrsg 
> Qraire naq nyy gung V xarj naq V zbirq va jvgu zl zbgure va Obhyqre va ubcrf 
> gung n tbbq qbfr bs zbz jbhyq pher jung nvyrq zr.  Gur srj zbaguf gung V 
> yvirq jvgu ure, V jnf ohfl zbivat, hacnpxvat, znxvat qrpvfvbaf, naq glvat hc 
> ybbfr raqf.  Svanyyl, V znqr fbzr gvzr sbe zlfrys naq fghzoyrq hcba Nyrk 
> gbjneqf gur raq bs Fcevat.  Gur frnfbaf jrer punatvat gura gbb, nygubhtu gurl 
> jrer irel pbashfrq va Pbybenqb nf vg pbagvahrq gb fabj naq trg pbyqre jvgu 
> rirel oerngu.  Nyrk naq V erzrzorerq znxvat fabj natryf naq jr qernzg bs 
> ubg pubpbyngr.  
> 
> Jura gur fha tenprq hf jvgu vgf cerfrapr, jr pnhtug hc zber naq rira ngr 
> rguvbcvna sbbq jvgu bhe svatref bar avtug.  V gevrq gb orpbzr n orggre fxngr 
> obneqre.  Jr fjnccrq obbxf naq gnyxrq nobhg Grgevf pbzcrgvgvbaf.  Jr cynlrq 
> jvgu nyy bs zl neg fghss.  V qht guebhtu obkrf gb svaq nal jbex bs zvar gung 
> unq n fgbel.  Nyrk jnf cngvrag jvgu zl enzoyvatf naq nfxrq zber dhrfgvbaf 
> guna V pbhyq nafjre.  Jura V svanyyl qerj n oerngu, V ybbxrq hc naq ernyvmrq 
> gung uvf rlrf jrer nf jvqr nf zvar.  Evtug gura, V xarj ur jnf gnyragrq.
> 
> Urer V nz ng bar bs gur svarfg neg vafgvghgvbaf fheebhaqrq jvgu n irel 
> fryrpgvir naq erchgnoyr tebhc bs crbcyr naq V ubarfgyl jbhyq or fubpxrq vs V 
> zrg fbzrbar nf tvsgrq nf lbhe fba.  Ur unf gur havdhr novyvgl gb qenj n 
> cvpgher nf ur fcrnxf.  Fbzrgvzrf ur enzoyrf naq trgf pubccl, ohg V\'z nyjnlf 
> yrsg jvgu fbzrguvat ivfhny.  Jung n oyrffvat vg vf gb zr gb xabj fbzrbar jvgu 
> na rlr rdhny gb naq sne orlbaq zl bja.  V guevir ba gur punyyratrf ur 
> cerfragf gb zr naq fbzrgvzrf rira jnyx njnl fghzcrq.  Jung na nznmvat 
> srryvat.  
> 
> V ubcr guvf svaqf lbh gbb, nppbzcnavrq ol gur ortvaavatf bs snyy.  Ernpu bhg 
> naq fzryy vg naq gnfgr vg.  Vg\'f bqqyl fbbguvat.  Naq zbfg vzcbegnagyl, xabj 
> gung V\'yy or gunaxvat lbh sbe tvivat zr gur tvsg bs sevraqfuvc...Nyrk unf 
> urycrq zr rkcyber zl bja gnyragf zber guna V rire jbhyq unir ng guvf fgntr va 
> zl yvsr.  Gunax lbh sebz gur qrrcrfg sngubzf bs zl orvat.  
> 
> va sevraqfuvc,
> Ubcr Jnaqrerq  

',
},





20010901 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => 'Phillip update', 
Body    => '

Date: Sat, 1 Sep 2001 22:22:57 -0400
From: Turms J Thoth <TurmsThoth@thoth.com>
To: alex@skazat.com
Message-ID: <20010901.222257.-1842625.5.TurmsThoth@thoth.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: Phillip update

V ernyvmr vg\'f orra n juvyr fvapr V frag na hcqngr.  Ab arjf vf tbbq
arjf, eryngviryl fcrnxvat.  Cuvyyvc unf orra jvgu hf gjb jrrxf lrfgreqnl. 
Gur svefg jrrx fnj dhvgr n cerpvcvgbhf qrpyvar, ohg V nz unccl gb ercbeg
gurer frrzf gb unir orra ab pbagvahrq qrpyvar guvf jrrx.  

Uvf fcrrpu vf fgvyy nyzbfg aba-rkvfgrag.  Uvf ibpnohynel pbafvfgf bs bar
jbeq:  "lrnu".  (Lbh jvyy arire svaq uvz zber pb-bcrengvir guna ur vf
abj!!)  "Lrnu" zrnaf "lrf", "ab", naq nalguvat ryfr ur jnagf gb fnl.  Va
gur ynfg pbhcyr qnlf, jr unir urneq n qrsvavgr "lrf" naq "ab" ba
bppnfvba...ohg vg\'f ener.  Ur unf nyfb fgnegrq n fragrapr "V jnag...",
ohg gung\'f nf sne nf vg jrag.  Fgvyy, vg\'f zber guna ur fnvq rneyvre va
gur jrrx.

Ynfg jrrx jr unq gb chepunfr nqhyg qvncref.  Ur unf pubfra gb jrne gurz
24 ubhef n qnl, nygubhtu ur vf noyr gb yrg hf xabj nyy qnl ybat jura ur
arrqf gb hfr gur "snpvyvgvrf" naq fbzrgvzrf bireavtug, gbb...ohg abg
100%.  Jr unir abg unq gb punatr n "qvegl" qvncre, lrg, fb jr xabj vg
pbhyq or jbefr!  ...naq cebonoyl jvyy or.

Jr ner fgvyy rawblvat trggvat bhg rnpu qnl, guebjvat gur fgvpx sbe Serq
va gur onpxlneq naq nyfb jnyxvat gur qbtf (sbe gubfr bs lbh jub qba\'g
xabj...gur Gubguf unir na Byq Ratyvfu Furrcqbt, Znk).  Gjvpr guvf jrrx, V
gbbx Cuvyyvc va gur jurrypunve, Cuvyyvc uryq Serq\'f yrnfu naq V uryq Znk\'f
yrnfu naq jr jrag sbe fubeg jnyxf.  V unir qrpvqrq gung vf zber guna V
pna unaqyr naq jvyy jnvg sbe na "nppbzcyvpr" gb uryc gnxr nyy guerr bs
gur "oblf".

Ntnva guvf jrrx jr unq fhccre oebhtug va ol arvtuobef naq Fvfgre n pbhcyr
bs avtugf.  V nz n frevbhf oevqtr cynlre naq gurer vf n ovt oevqtr
gbheanzrag va Jngreohel guvf ubyvqnl jrrxraq (Jrq-Zba).  Jvgu gur uryc bs
BgureFvfgre, Fvfgre, fbzr arvtuobef naq (zl uhfonaq) Rq, V unir znantrq gb
cynl gjb (naq cyna gb cynl n guveq gbzbeebj) bs gur fvk gbheanzrag qnlf
cyhf bar tnzr ng gur oevqtr pyho Jrqarfqnl (orsber gur gbheanzrag
fgnegrq).  Fb V nz trggvat eryvrs naq pbagvahr gb srry serfu naq hc gb
gur gnfx ng unaq.

Gbzbeebj (arvtuobe) F\'nag Xrra vf cynaavat gb gnxr Cuvyyvc gb Znff.  F\'nag vf
n Rhpunevfgvp Zvavfgre naq unf orra snvgushyyl oevatvat pbzzhavba gb Cuvyyvc
rnpu jrrx, ohg guvf jrrx gurl jvyy gel gb tb gb Znff vafgrnq.  

Ynfg jrrx, nsgre ur ybfg uvf fcrrpu naq pbagvarapr, jr (Cuvyyvc, Fvfgre naq
V) nyy nterrq gung ur qvqa\'g jnag crbcyr frrvat uvz gung jnl naq jr
fgnegrq qvfpbhentvat zbfg ivfvgbef, ohg abj jr srry Cuvyyvc unf n qrterr bs
npprcgnapr bs uvf pbaqvgvba naq vf bapr ntnva jvyyvat gb frr (naq or frra
ol) sevraqf...nygubhtu vg vf gvevat naq Cuvyyvc fyrrcf n ybg.  Bar qnl V
guvax ur jnf hc bayl 4 ubhef (gjb 2-ubhe crevbqf) nyy qnl ybat.  Orqgvzr
pna pbzr nf rneyl nf 7 be 7:30, ohg hfhnyyl 8 c.z.

Ghezf


',
},



20010906 => { 
 
From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => 'Phillip has moved', 
Body    => '
Date: Thu, 6 Sep 2001 21:03:23 -0400
From: Turms J Thoth <TurmsThoth@thoth.com>
To: alex@skazat.com
Message-ID: <20010906.210324.-1890623.0.TurmsThoth@thoth.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: Phillip has moved

Gbqnl jr unq gb zbir Cuvyyvc gb gur Unegsbeq Ubfcvgny Ubfcvpr Havg.  Vg vf
va gur Pbaxyva Ohvyqvat (4gu sybbe), jurer znal bs lbh ivfvgrq uvz jura
ur jnf va gur Eruno Havg ba gur 5gu sybbe.  Uvf ebbz ahzore vf 407.   V
jbhyq tvir lbh uvf cubar ahzore, ohg fvapr ur pna\'g fcrnx, ur jba\'g or
nafjrevat gur cubar.  Lbh pna xrrc va gbhpu guebhtu Fvfgre.

Ghrfqnl riravat V abgvprq n enfu ba uvf gbefb, juvpu jnf yvxr n onq pnfr
bs gur zrnfyrf.  Vg qvqa\'g frrz nf onq Jrqarfqnl naq bhe (frpbaq fgevat)
ahefr fnj vg naq jnf abg bireyl pbaprearq.  Fur gbyq hf gb hfr onol
cbjqre jvgu pbea fgnepu, juvpu jr qvq.  V nyfb tnir uvz n fubjre
Jrqarfqnl nsgreabba.

Guhefqnl zbeavat vg jnf ntnva nf onq nf vg unq orra Ghrfqnl riravat, ohg
ol gur gvzr bhe ahefr neevirq vg frrzrq gb unir pnyzrq qbja n ovg, ohg
guvf (zber rkcrevraprq) ahefr fnvq fur jnf fher vg jnf n ernpgvba gb bar
bs gur zrqvpngvbaf.  Ur vf bayl gnxvat gjb:  gur nagv-frvmher Grtergby
naq gur cerqavfbar gb fuevax gur ghzbef.  Fur fhfcrpgf vg vf gur
nagv-frvmher bar fvapr fur xabjf sebz uvf erpbeqf gung ur unq rkuvovgrq n
ernpgvba gb gur bevtvany nagv-frvmher zrq, qvynagva, va gur ubfcvgny naq
gurfr gjb ner va gur fnzr snzvyl, fb fvapr ur unq gur qbfntr vapernfrq
sbyybjvat gur gjb zvabe frvmherf ur unq urer, fur vf pbasvqrag gung gung
vf gur phycevg.  Fur fnlf ure rkcrevrapr gryyf ure gung gur qbpgbe jvyy
cebonoyl abg gel gb svaq nabgure gung ur pna gbyrengr, ohg jvyy fhfcraq
gur gerngzrag, znxvat uvz zber yvxryl gb frvmr naq ur arrqf gb or va gur
pner bs genvarq zrqvpny crbcyr.  V nterr gung jr ner abg ernql gb unaqyr
gur fvghngvba.

Arvgure zrqvpngvba vf n pher.  Obgu ner zreryl qrynlvat gur varivgnoyr,
fb gurl znl fgbc gurz obgu (be znlor whfg gur nagv-frvmher bar) naq yrg
angher gnxr vgf pbhefr.  Jr ner nyy fnq gung jr jrer abg noyr gb fgnl gur
pbhefr, ohg guvf zbir vf va Cuvyyvc\'f orfg vagrerfg.  Ur xabjf gung, ohg bs
pbhefr vf fnq, gbb.

Ghezf
',


},






20011003 => { 

From    => 'DMation@DMation.com (Dalmory Mation)', 
Subject => 'dad', 
Body    => '
Date: Wed, 3 Oct 2001 00:04:45 -0400 (EDT)
From: DMation@DMation.com (Dalmory Mation)
To: alex@skazat.com
Message-ID: <6036-3BBA8E5D-3477@storefull-627.iap.bryant.webtv.net>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Subject: dad

V jnagrq gb yrg lbh thlf xabj gung Qnq cnffrq njnl guvf riravat,
crnprshyyl.  Ur vf abj ng crnpr naq jvgu Zbz.  Nyrk, V qba\'g unir lbhe
cubar ahzore fb V pbhyqa\'g pnyy lbh.  Sbejneq zr gur ahzore.  Vs lbh ner
vagrerfgrq va pbzvat ubzr sbe gur freivpr, yrg zr xabj.  Vg jvyy rvgure
or guvf Sevqnl be arkg Ghrfqnl, qrcraqvat jurgure be abg lbh ner pbzvat
ubzr.  Cyrnfr pnyy zr.

V ybir lbh thlf.

Fvfgre
',

},
}; 







# From == To. Duh me. 

$boxes{'outbox'} = { 

20010820 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => '[Phillip] Back in Boulder', 
Body    => '
Date: Mon, 08 20 Aug 2001 19:08:57 -600 
Message-ID: <totalsite.com    20010820190857.12212.qmail@nollie.summersault.com>
From: alex@skazat.com 
To: Turms J Thoth <TurmsThoth@thoth.com>
Subject: [Phillip] Back in Boulder

Url Qnq!

Jnagrq gb yrg lbh xabj gung V tbg onpx gb Obhyqre N-BX, gur syvtug jnf
irel ybat, fvapr bar bs gur trarengbef ba gur cynar npghnyyl ovg gur
qhfg naq jr unq gb ynaq va Xnafnf Pvgl sbe na ubhe, obneq nabgure cynar
naq tb ba sebz gurer.

Va Fg Ybhvf, V obhtug n pbcl Uhagre F. Gubzcfba\'f \"Srne naq Ybnguvat va
Ynf Irtnf\" fvapr V ernq gur zntnmvar V obhtug va Qraire gjvpr bire naq V
sbetbg gb cnpx bar bs gur 10 obbxf V\'z ernqvat ng bapr. V svavfurq gur
obbx ba gur ihf evqr sebz Qraire gb Obhyqre naq tbg gb gur ubhfr ng
nebhaq 11:00cz rkunhfgrq. Vebavpnyyl, Srne naq Ybnguvat raqf jvgu gur
znva punenpgre neevivat ng gur Qraire Nvecbeg naq ur qbrfa\'g ernyyl
haqrefgnaq jul ur\'f gurer - fb ur ohlf n zrna, ivpvbhf qbt. Gung fhzf hc
gur obbx naq vg\'f ernfbavat dhvgr jryy.

V tbg hc rneyl gbqnl naq jnaqrerq gbjneqf Crney Fgerrg. V cvpxrq hc gur
znvy sebz gur qnlf V zvffrq naq erprvirq n purpx sebz gur tbireazrag sbe
$300, n purpx sebz n gbgny fgenatre sbe $75 sbe n cebtenz V eryrnfr sbe
serr naq n ovyy sebz gur Havirefvgl sbe n YNETR nzbhag jvgu ybgf bs
mrebf ng gur raq. Vg\'yy onynapr ng gur raq (YNHTU)

V hacnpxrq nyy zl fghss sebz gur gevc naq pyrnarq hc zl ebbz, rira
inphhzrq. Gurer jrer pybgurf va gur jnfure sebz jura V yrsg, fb V unq gb
tvir gurz nabgure ghea. V arrq gb svaq n qevyy gb chg gbtrgure zl arj
qenjvat gnoyr naq fbzrbar jvgu n gehpx gb srgpu zl zneoyr fphygcher
gung\'f fgvyy ng gur byq ubhfr. V ubcr vg\'f fgvyy gurer!

Gnxr pner Qnq,

gnyy Fvfgre gung V znqr vg onpx,

Nyrk Fxnmng


"Gurer vf n gurbel juvpu fgngrf gung vs nalbar qvfpbiref whfg rknpgyl
jung gur havirefr vf sbe naq jul jr ner urer, gung vg jvyy vafgnagyl
qvfnccrne naq or ercynprq ol fbzrguvat rira zber ovmneer naq
varkcyvpnoyr. Gura gurer vf n gurbel juvpu fgngrf gung guvf unf nyernql
unccrarq. -Qbhtynf Nqnzf"

',
},




20010821 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => '[Phillip] The Daily Report', 
Body    => '
Date: Tue, 08 21 Aug 2001 
Message-ID: <0010 8 21
055841.D8BB22756@nollie.summersault.com> 
From: alex@skazat.com 
To: Turms J Thoth <TurmsThoth@thoth.com> 
Subject: [Phillip] The Daily Report

url Cnoyb!

vg\'f 2 nz, ohg V jnagrq gb jevgr gb lbh naljnlf. Gur thl ng gur pbssrr
fubc yvxrq zl pbby g-fuveg, fb V tbg zl pbssrr sbe serr. Lbh jbhyqa\'g
oryrvir ubj znal gvzrf gung unccraf gb zr. Gur onevfgn qvqa\'g rira nfx
zr jung v jnagrq - fur nyernql xarj, lbh jbhyqa\'g oryvrir ubj zhpu gung
unccraf nf jryy jvgu bgure rngvat rfgnoyvfuzragf.

V jrag gb jbex ntnva rneyl. V\'ir orra cerccvat inevbhf jbex cebwrpgf bs
zvar fb gung jura V fgneg fpubby, gurl pna or unaqrq bss jvgu n ovg zber
pynevgl guna jura V, zlfrys jbex jvgu gurz. V qba\'g arrq pynevgl, fvapr
V jebgr gur qnea guvat, ohg bgure crbcyr znl or ybfg. V\'ir irel rkpvgrq
gung zl obff qrpvqrq gung gur nafjre bs zr gnxvat gvzr bss sebz jbex gb
tb gb fpubby jnf gb uver nabgure qrirybcre, vafgrnq bs cvyvat gur fnzr
nzbhag bs jbex gung V hfhnyyl qb va 5 qnlf, bagb 3. Ur\'f orra irel
cbfvgvir nobhg zr univat gb tb gb fpubby naq V ernyyl nccerpvngr gur
syrkvovygl ur\'f tvira zr. Ur orggre or syrkvoyr :) V\'ir orra gurer
pbzvat ba guerr lrnef! Gung\'f gur ybatrfg gvzr V\'ir rire jbexrq n wbo,
abg orpnhfr V\'ir orra sverq, urniraf ab - V\'z hfhnyyl gur crefba gung\'f
pevgvpny gb n ovm, or vg  cvmmn znxvat be na nccyvpngvbaf qrirybcre. V\'z
n tbbq jbexre. Avpr gb xabj gung arkg gvzr V wbo uhag.

Zl xarr vf srryvat orggre abj, V jrag fxngvat ng gur cnex pybfr gb zl
ubhfr naq unq n jubyr ohapu bs sha. Ybgf bs crbcyr ner zbivat onpx vagb
gbja orpnhfr bs fpubby fgnegvat ntnva naq V fnj n srj arj snprf ng gur
cnex juvpu vf nyjnlf n tbbq guvat. V nyfb pna\'g uryc ohg frr n srj arj
nggenpgvir tveyf zl ntr jnaqrevat nebhaq arne jbex ba gur znyy nf jryy!

V jrag gb pnzchf gbqnl ba zl oernx sebz jbex gb pnfu zl \'Srqreny Gnk
Eryvrs\' purpx naq trg fbzr Va-Fgngr Ghvgvba cncref gung gur HAZRAGVBANY
guerj bhg juvyr zbivat. Pnzchf jnf dhvgr gur yvggyr ohfyvat zvpebpbfz,
ybgf bs punbf sebz arj naq byq fghqragf gelvat gb trg ernql. Gur dhvrg
fhzzre bs gur jubyr gbja vf dhvpxyl hccvat va grzcb. V\'z trggvat rkpvgrq
nobhg fpubby naq nz na ryrpgevp qevyy njnl sebz ohvyqvat zl qenjvat
gnoyr.

V fubjrq zl ebbzngr fbzr qenjvatf V qvq sebz guvf fhzzre naq ur jnf irel
zhpu vzcerffrq. Pbzcnevat svther qenjvatf V\'ir qbar gung ner 4 zbaguf
ncneg ernyyl znxrf lbh ernyvmr ubj snfg V yrnea fbzrgvzrf. Guvf frzrfgre
fubhyq or vagrerfgvat gb fnl gur yrnfg.

Whfg gb yrg lbh xabj, gurfr yvggyr abgrf gb lbh ner urycvat zr fgneg
jevgvat ntnva, fbzrguvat V fgbccrq ernyyl qbvat va Ncevy, V pneel n
fznyy ont jvgu zr rireljurer V tb gung unf n wbheany, craf/crapvyf naq n
pnzren - lbh arire xabj jura vafcvengvba uvgf naq vg uvgf zber gvzrf
guna lbh guvax. V\'ir tbg n irel punggl vaare ibvpr.

V\'z ubcvat gb trg va gbhpu jvgu zl sevraq Ynhen, fvapr fur unf fbzr
cvpgherf bs zr va n fghcvq ung jr gbbx jura jr nyy jrag bhg sbe qrffreg
ynfg jrrx.

Gnxr pner, V\'z tbvat gb fyrrc nsgre V jevgr n srj zber crbcyr

Nyrk Fxnmng

"Fpvrapr vf rirelguvat jr haqrefgnaq jryy rabhtu gb rkcynva gb n
pbzchgre. Neg vf rirelguvat ryfr. " - Qnivq Xahgu

',
},


20010830 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => '[Phillip] - One Beautiful August Day', 
Body    => '
Date: Thu, 08 30 Aug 2001 
Message-ID: <200108302139.RAA07410@nollie.summersault.com> 
From: alex@skazat.com 
To: Turms J Thoth <TurmsThoth@thoth.com> 
Subject: [Phillip] - One Beautiful August Day

Bu zl,

Gbqnl, gur jrngure jnf fb avpr -  abg gbb ubg, abg gbb pbyq naq abg n
fcrp bs uhzvqvgl. V jrag gb gur fxngrcnex ntnva. Zber arj snprf naq
qvssrerag fglyrf. Gur fha vf fvaxvat ybj naq gur sybj bs gur cnex tbrf
rnfg gb jrfg, fb unys gur gvzr lbh\'er n ovg oyvaqrq. Bar bs gurfr qnlf,
V\'yy ohl fbzr ernyyl tbbq fhatynffrf naq ybbx nyy pbby. V zrg hc jvgu zl
sevraq Wraan, naq jr znl tb frr n zbivr gbzzbeebj gbtrgure jvgu n srj
bgure ohqf.

Lrfgreqnl V jrag gb Gnetrg, juvpu vf n fgber gung pbzovarf gur orfg
dhnyvgvrf bs Xzneg naq Frnef PBZOVARQ. Abg gur oevtugrfg zbir, fvapr
25,000 bgure pbyyrtr ntrf xvqf jrer gurer qbvat gur rknpg fnzr guvat nf
zr. V cvpxrq hc n genfupna naq n ynhaqel onfxrg. naq fbpxf. oynpx barf.
Rkpvgvat ru? V sbetbg V nyfb jnagrq n cubar sbe zl ebbz, ohg V thrff
V\'yy cvpx gung hc yngre. V zndl trg n pryycubar fbba, nf zl serrynapr
ohfvarff vf cvpxvat hc gb or jbegujuvyr gb vairfg n cubar naq znlor n
cbegnoyr pbzchgre (na byq bar) gbjneqf. V qba\'g xabj gur svefg guvat
nobhg pryycubarf naq unir orra nfxvat nebhaq. V ernyyl qba\'g jnag
nabgure zbaguyl ovyy. V\'yy unir gb trg gur pnyphyngbe bhg naq pehapu
fbzr ahzoref.

Zl ebbzngr, Ebfr vf tbvat gb trg n qevyy sebz uvf sngure naq V\'z tbvat
gb chg zl qenjvat qrfx gbtrgure. V obhtug n arj qenjvat naq pna\'g jnvg
gb ovgr vagb vg.

Nyrk Fxnmng


',
},






20010902 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => '[Phillip] School Starts today!', 
Body    => '
Date: Sun, 09 02 Sep 2001 
Message-ID: <20010902104954@nollie.summersault.com> 
From: alex@skazat.com 
To: Turms J Thoth <TurmsThoth@thoth.com> 
Subject: [Phillip] School Starts today!

Url Qnq!

Fbeel gb urne nobhg gur obngvat gevc - gurfr Nhthfg qnlf ner svyyrq jvgu
fgenatr pheeragf naq ab jvaq - lbh xabj gung :)

V qb jnag gb gryy lbh gung nyy gur pynffrf gung V jnagrq gb gnxr guvf
frzrfgre gung V jnf ba gur jnvgyvfg sbe, unir abj orra pyrnerq naq V\'z
bssvpvnyyl raebyyrq va gurz! Gung chgf zr zhpu ng rnfr, fvapr V jba\'g or
unatvat bhg va n pynff sbe n zbagu whfg gb or gbyq V qvqa\'g trg n frng.
Cubgbtencul fgnegf va nobhg 8 ubhef, V ubcr zl pnzren fgvyy jbexf! V
obhtug n fpnaare sbe zl pbzchgre, fvapr vg jnf 75% bss naq V pbhyq arire
cnff hc n tbbq qrny. V\'ir orra fpnaavat fbzr cvpgherf bs gur snzvyl sbe
fnsr fgbentr naq yvggyr cebwrpgf.

Vg\'f yngr, ohg V jnagrq gb gryy lbh gung V jnf guvaxvat bs lbh naq gung
V jnf nyfb tngurevat fbzr cvpgherf gb fraq lbh. V\'yy fraq lbh fbzr
qenjvatf nf jryy, bapr zl gnoyr vf pbafgehpgrq,

Gnxr pner!

Nyrk Fxnmng

',
},






20010903 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => '[Phillip] School and Things ', 
Body    => '
Date: Mon, 09 03 Sep 2001 
From: alex@skazat.com 
To: Turms J Thoth <TurmsThoth@thoth.com> 
Subject: [Phillip] School and Things 

Url Qnq!

V fgnegrq fpubby gbqnl, Cubgbtencul naq Cnvagvat; gur cubgbtencul pynff
vf irel fznyy, creuncf 18 crbcyr, 15 bs juvpu ner tveyf (ur ur) gur
cnvagvat pynff, rira fznyyre, znlor 12. V ernyyl yvxr gur vqrn bs fznyy
pynffrf, lbh pna gnyx gb rirelbar ryfr va gur pynff naq npghnyyl fgneg
gb xabj gurz jryy. V guvax V\'z gur byqrfg bar va obgu bs gur pynffrf,
juvpu V qba\'g zvaq, ohg znxrf zr srry irel pbzsbegnoyr, abaguryrff. V
pna\'g jnvg gb fgneg cnvagvat. Jr\'er tbvat gb yrnea bvyf, naq V unir n
fhccyl yvfg n zvyr ybat ba gur guvatf V arrq sbe gur pynff ol arkg jrrx.
V ubcr zl pnzren fgvyy jbexf gbb! Gnxvat 20+ ebyyf va 15 jrrxf ernyyl
fbhaqf yvxr sha. Vf guvf pynff? Frrzf yvxr V\'z tbvat gb unir gbb zhpu
sha qbvat guvf fghss.

V tbg na vagreivrj sbe zl ebbzngr, Ebfr, sbe n wbo ng gur pbzcnal V jbex
sbe naq ur qvq n sbyybjhc zrrgvat gbqnl. Vg ybbxf yvxr ur tbg gur wbo!
Ur fgnegf Zbaqnl. Ur unfa\'g orra rzcyblrq fvapr Sroehnel, fb ur\'f irel
unccl naq gunaxshy bus zr sbe urycvat uvz.

V chg gbtrgure zl arj qenjvat gnoyr, naq zl ebbz vf trggvat irel zhpu
zngher naq pbzcyrgr. V\'yy fraq cvpgherf fbba. V unir fbzr shaal barf jr
gbbx gur jrrx orsber V yrsg sbe PG gung V\'z tbvat gb fraq bhg gb lbh
gbzzbeebj. V unir guvf phevbhf ung ba gung jr sbhaq va orgjrra gur
pbhpu. Zl sevraqf gbyq zr V ybbx yvxr gur yrnq fvatre bs guvf ebpx naq
ebyy onaq, Gur Pbhagvat Pebjf... be jnf vg  Gur Oynpx Pebjf? Bu jryy, n
ebpxfgne nyy gur fnzr.

V jnagrq gb yrg lbh xabj, gung gbqnl V ernyyl srry fvghngrq va jurer V
nz abj naq ernyyl, jub nz naq jung V\'ir orpbzr. V nz fb rkpvgrq sbe gur
pbzvat zbaguf naq vg frrzf gb or pbzvat ng zr irel irel snfg. V\'z whfg
tbvat gb rawbl gur evqr naq fgrne ng gur uryz.

Nyrk Fxnmng

',
},




20010907 => { 

From    => 'Turms J Thoth <TurmsThoth@thoth.com>', 
Subject => '[Phillip] Yeah Ha!', 
Body    => '
Date: Thu, 09 07 Sep 2001
Message-ID: <20010907052042.2061.qmail@nollie.summersault.com>
From: alex@skazat.com
To: Turms J Thoth <TurmsThoth@thoth.com>
Subject: [Phillip] Yeah Ha!

Url Qnq!

V unira\'g jevggra va n juvyr fvapr V\'ir orra ohfl va fhpu n tbbq jnl.
Fpubby unf fgnegrq naq V\'z srryvat irel tbbq nobhg vg. Jr whfg fgnegrq
cnvagvat va bvyf sbe gur svefg gvzr. Svefg gvzr sbe zr RIRE fb V jnf
cerggl rkpvgrq. Bvy cnvagvat vf bar bs gubfr guvatf gung rirelbar xabjf
rkvfgf, ohg srj crbcyr ernyl qb. Xvaq bs yvxr fnvyvat n obng - naq yvxr
fnvyvat n obng, gur svefg gvzr lbh qb vg, lbh\'er abg fher bs lbhefrys,
be jung lbh tbg vagb lbhefrys vagb, ohg lbh guvax gb lbhefrys "Vs V pna
znxr vg guebhtu guvf svefg fgbez, V\'yy or svar"  Lbh hfhnyyl :) qb naq
gur arkg gvzr lbh fnvy, lbh trg n avpr jvaq naq pnyz frnf. Be lbh fgnl
ng Cbvag Whqgu sbe nabgure qnl naq gura avpr jvaq naq pnyz frnf. Guvf
pynff va cnegvphyne unf fbyvqvsvrq zl oryvrs gung nalguvat gung frrzf
uneq, ernyyl vfa\'g, lbh whfg unir gb QB vg. Vg\'f xvaqn yvxr gur furyy bs
na rtt; ybbx ng vg nyy bire ng bar gvzr, lbh pna arire oernx guebhtu,
ohg gel gb gnc n fznyy cvrpr naq gur rtt furyy jvyy tvir jnl yvxr
ahguva.

Cubgbtencul vf nyfb irel sha, V\'z fubbgvat zl svefg ebyy sbe gung pynff
guvf jrrxraq, abguvat fcrpvny, jr\'er fgnegvat sebz gur irel ortvavat,
yrneavat nobhg fuhqqre fcrrqf naq s-fgbcf, yrafrf, svyz, gur jbexf. Obgu
bs gurfr pynffrf unir zr fubccvat ng uneqjner fgberf naq gurl obgu unir
irel gbkvp purzvpnyf gung arrq gb or unaqyrq. Jura V fubc sbe fhccyvrf,
V srry yvxr V\'z ohvyqvt n ubhfr, jura V jbex jvgu gur fhccyvrf, V srry
yvxr n purzvfg sebz gur 16gu praghel. V ubcr gur bhgpbzr bs nyy guvf
jvyy or fbzrguvat V pna pnyy \'neg\' :) vs abg, V unir rabhtu rkgen
fhccyvrf sbe ng yrnfg fbzr avpr nagvdhr pnovargf.

Jr jrer jbexvat jvgu ghecvagvar naq V gbyq gur pynff gur fgbel bs jura
lbh znantrq gb znxr nyy lbhe svatreanvyf snyy bss. V jrne ovt ehoore
tybirf nyy gur gvzr naq guvax bs lbh jura V guvax gurl trg gbb ubg. Jr
cnvagrq n fgvyy yvsr gbqnl, abguvat fcrpvny, ohg V\'yy gnxr fbzr cvpgherf
bs zl jbex guebhtubhg gur frzrfgre naq V\'yy fraq gurz gb Fvfgre fb fur
pna cevag gurz. Fcrnxvat bs cvpgherf, gryy Fvfgre gb fraq fbzr gb zr!

V ubcr lbh unq n TERNG ynobe qnl, V ynoberq ba zvar. V\'ir orra jbexvat
irel uneq ng erthynee jbex naq qbvat serrynapr ng ubzr. Zl tbny vf gb
cnl sbe guvf frzrfgre ol gur raq bs Bpgbore naq V\'z npghnyyl, evtug ba
genpx. Ba Ynobeqnl, V nyfb gnhtug n arj sevraq bs zvar, Wnzvr, ubj gb
fxngr. Fur whfg zbirq sebz Fna Senafvpb naq npghnyyl jbexf bar oybpx
njnl sebz zr.  V\'z tbvat gb frr vs fur\'f nebhaq gbzzbeebj jura V\'z ng
jbex naq frr vs fur jnagf gb trg n ovgr gb rng.

V ubcr lbh tbg gung yrggre sebz Ubcr, fur\'f n irel fzneg tvey naq unf
dhvgr gur nssyhrapr naq punevfzn gung yvsr fubhyq tvir gb rirelbar. Fur
unf bgure sevraqf va Obhyqre naq gur arkg gvzr gurl tb qbja gb Fnagn Sr,
V\'z tbvat gb gnt nybat. Jr\'ir orra gnyxvat yngr avtugf ba gur cubar naq
fraqvat pner cnpxntrf onpx naq sbegu. Gbzzbeebj vf n znvy qnl sbe zr, V
unir fbzr fhecevfrf pbzvat lbhe jnl, fb jngpu bhg!

V\'q yvr gb lbh vs V qvqa\'g fnl V jnf ernyyl gverq ng gur zbzrag, ohg V\'z
unccl V\'z gverq naq abg oberq. Guvf nhghza vf ernyyl tbvat gb or bar bs
zl svarfg. Guvf jrrxraq V ubcr gb tb gb Qraire gb frr n zhfvp fubj ba
Fngheqnl naq nabgure bar ba Fhaqnl. Arkg Jrqarfqnl, V\'z tbvat gb zrrg zl
sevraq, Fgnpv, jub yvirf va Qraire naq jr\'er tbvat gb frr n onaq anzrq
Jrrmre. Jrrmre\'f yrnq fvatre\'f tenaqzbgure yvirf va Arjvatgba. V
erzrzore gung jnf n uhtr qrny jura V jnf va uvtufpubby. gvpxyvat shaal.

V whfg svavfurq ernqvat bar bs gur obbxf V\'z jbexvat ba, pnyyrq
Genvafcbggvat. Vg gnxrf cynpr va Rqvaohet, Fpbgynaq naq vf nobhg n ybbfr
avg frg bs sevraqf, zbfg bs jubz ner nqqvpgrq gb Urevba. Bar bs gur znva
punenpgref svanyyl xvpxf gur Urevba unovg naq fgnegf n arj yvsr va
Nzfgreqnz. Ur qbrf guvf ol fgrnyvat n jubyr ont bs zbar uvf sevraqf naq
uvz tbg sebz fryyvat n jubyr ohapu bs urevba fbzrbar whfg ol punapr,
erprvirq. Ur qvqa\'g srry onq nobhg uvf sevraqf, naq gur snpg gung gurl
jbhyq or ba gur ybbxbhg sbe uvz (naq gur zbarl!) sbeprq uvz gb arire or
noyr gb tb onpx gb Fpbgynaq. Ohg, gung\'f rknpgyl jung ur jnagf, fvapr
Fpbgynaq rdhngrf gb uvf byq yvsr nf n whaxl. Abg gbb onq. N terng fgbel
gubhtu, vg\'f jevggra ragveryl va cubargvpny Fpbggvfu - gur svefg cntr
gnxrf n tbbq 5 zvahgrf gb trg guebhtu. V\'ir ernq gur obbx bapr orsber,
naq unir frra gur zbivr irefvba n ahzore bs gvzrf. V sbetbg rirel fprapr
gung jnfa\'g va gur zbivr, fb erernqvat gur obbx jnf yvxr ernqvat vg sbe
gur svefg gvzr. V sryg cyrnfrq.

Gung\'f vg sbe abj Qnq, gunaxf sbe yvfgravat!

Ybir,

Nyrk Fxnmng


',
},


20010826_2 => { 

From    => 'Hope@wanderer.com', 
Subject => 'When I grow, I want to attend the punk rock academy!', 
Body    => '
Date: Sun, 08 26 Aug 2001
From: alex@skazat.com
To: Hope@wanderer.com
Subject: When I grow, I want to attend the punk rock academy!

zl xrjyrfg Ubcr,

ubj bhg bs vg nz V? furrfu.

Zl arj ubhfr vf va guvf cynpr pnyyrq Znegva Nperf, juvpu vf fhccbfviryl gur
\'nssbeqnoyr\' cneg bs Obhyqre. V nz evtug arne 36, ohg V urne abguvat, gur fgerrg
vgfrys vf fnsr rabhtu sbe n onol gb cynl va, naq V nz gunaxshy. 30gu fgerrg jnf
xvaqn turggb, fbzr thl tbg irel onqyl uvg va sebag bs zl ubhfr, n srj bgure
guvatf v arrq gb jevgr gb  lbh nobhg (gur nsberzragvbarq Cneg 2)

>  gur ernfba v xvaqn obhtug 
> vg vf orpnhfr v guvax zl zbz naq v ner tbvat gb genqr pnef.  fb v jvyy zbfg 
> yvxryl or qevivat gur ebjql nhqv nebhaq gbja naq fur pna pehvfr va gur 
> nyy-greenva zbz iruvpyr ba gur qveg ebnqf bs perfgbar.  v guvax gung\'f n > cerggl qnza tbbq fjnc vs lbh nfx zr

uryyf lrnu, V jvfu nyy gur gvzr gb unir n pne, ohg vs  V trg bar, V\'yy or
jbexvat SBE gur pne naq gurer jba\'g or nalgvzr gb QEVIR gur pne, fb V\'yy ubyq
bss hagvy fbzrbar bssref zr gur $150,000/lrne fnynel gung vapyhqrf gur pbzcnal
Ivcre. Jr\'yy frr. Sbe abj, v unir n fxngrobneq. yn yn yn.

> vs v unir gur nhqv znlor v pna pbzr 
> cvpx lbh hc naq oevat lbh qbja gb gur njrfbzr ynaq bs fnagn sr.  v\'yy cvpx hc > nyy zl sevraqf juvyr v nz ng vg.

bu uryyf lrnu! gur arkg gvzr V unir zber guna 4 qnlf bss, V\'z qrsvargyl uvtu
gnvyvat vg gb Fnagr Sr, creuncf jr pna zrrg va gur zvqqyr fbzr gvzr? V\'q Ybbbir
gb purpx bhg AZ ntnva, vg\'f orra nobhg 10 lrnef fvapr V jrag guebhtu gung cneg
bs gur Pbhagel. Jr pbhyq npghnyyl tb gb Fbhgurea PN naq unat jvgu zl oeb sbe n
srj naq gura tb onpx gb Fnagr Sr (jurryf ner gheavat...)

> .bayl ceboyrz vf...v qba\'g unir nal bgure sevraqf.  v unir n srj va 
> qryn-jurer.  jr pbhyq fjvat gb gurer v thrff.  guvax nobhg vg....gurer zvtug 
> or yvxr 5 bs hf...gung vf vs nyy zl sevraqf pbhyq pbzr.  vg jbhyq or n erny 
> entre.  jung n qbex v nz!!

ab sevraqf ru? V\'q yvxr fbzr zber sevraqf... V npghnyyl unir zber guna V
gubhtug. jrrr. Abg rabhtu pybfr barf V thrff. Purpx guvf cynpr bhg:

uggc://znxrbhgpyho.pbz/

sha cynpr gb zrrg perrcl crbcyr.

> ubcr lbh ner jryy.  ner lbh qbvat fpubby guvf lrne?

lrf! fpubbyf fgnegf va 7 1/2 ubhef, vg\'f n cubgbtencul pynff! V pna\'g jnvg gb
fubj lbh zl fghss! cyrnfr chfu zr gb fubj lbh, V arrq gb znxr tbbq hfr bs zl
serr gvzr. nsgre cubgb vf n cnvagvat pynff. sha sernxvat qnl, bu , naq gura V\'z
tbvat gb fxngrobneq :)

> lbh arrq n fcnpr qbt (be jnf vg n  ehffvna zbaxrl)

qhqr, n zbaxrl jbhyq ebpx! V\'ir znqr n cebtenz pnyyrq Zbwb, gung\'f n anzr bs gur
urycre zbaxrl ba gur Fvzcfbaf, naq gurer\'f nyjnlf Zbwb Wbwb bs Cbjqre Chss Tveyf
Snzr  - V\'z unysjnl gurer!

Urer\'f fbzr (pehqql) cvpf bs n erprag fxngr pbagrfg:

uggc://jjj.cubgb.arg/cubgbqo/sbyqre?sbyqre_vq=144174

n srj qbexl snzvyl cvpf:

uggc://jjj.cubgb.arg/cubgbqo/sbyqre?sbyqre_vq=144167

fbeel v\'ir orra n ovg yrff va gbhpu nf V jnagrq, zl qnq vf xvaqn vyy, bx, ernyyl
fvpx (gnyx gb lbh nobhg vg bire gur cubar be fbzrguvat)

vs lbh jnag, lbh pna rznvy uvz!

GhezfGubgu@gubgu.pbz

whfg chg \'Cuvyyvc\' va gur fhowrpg. Ur jba\'g ercyl, ohg vg jvyy oevtugra uvf qnl.
Lbh zvtug jnaan jevgr nobhg fbzrguvat jr\'ir qbar gbtgure, be ur jba\'g haqrefgnaq
jul lbh rznvyrq uvz. PP gur zrffntr gb zr vs lbh pna.

gnxr pner, V\'z tbvat gb trg fbzr fyrrc :)

Nyrk Fxnmng

Bar tbbq guvat nobhg zhfvp vf jura vg uvgf lbh, lbh srry ab cnva. Fb uvg zr jvgu
zhfvp, ohegnyvmr zr jvgu zhfvp. - Obo Zneyrl


',
},


};



sub dada { 


my $box_to_use = $t_box || 'inbox'; 
if($box_to_use ne 'inbox' && $box_to_use ne 'outbox'){ 
	$box_to_use = 'inbox'; 
}

my $it     = make_index($box_to_use); 
my $msg    = gimme_msg($box_to_use, $t_msg); 
my $sr     = ($box_to_use eq 'inbox') ? 'Received' : 'Sent'; 
my $mb_dir = ($box_to_use eq 'inbox') ? 'From'     : 'To'; 


$box =~ s/<!\-\-\[listing\]\-\->/$it/g;
$box =~ s/\[message\]/$msg/g; 
$box =~ s/\[sent_received\]/$sr/g;
$box =~ s/\[mb_dir\]/$mb_dir/g; 
$box =~ s/\[url\]/$url/g; 

return $box; 

}



sub make_index { 

my $box = shift; 

my $data = $boxes{$box}; 

my $index; 



foreach(sort keys %$data){ 

my $rd        = $_; 
my $subject  = $data->{$_}->{Subject}; 
my $body     = $data->{$_}->{Body};
my $from     = $data->{$_}->{From};
my $p_date   = substr($rd, 4, 2) . '/' . substr($rd, 6, 2) . '/' . substr($rd, 0, 4); 

my $a = "<a href=\"$url/art/$box/$_/\">";


$index .= <<EOF
<tr> 
<td> 
 $a
  $p_date
 </a>
 </td> 
<td> 
 $a
  $from
 </a>
  </td>
 <td>
 $a
  $subject
 </a>
 </td>
</tr> 

EOF
; 



}


return $index; 

}

sub gimme_msg { 
	
	my ($box, $id) = @_; 
	my $msg =  $boxes{$box}->{$id}->{Body}; 
	return $msg ? $msg : '';

}

1;
