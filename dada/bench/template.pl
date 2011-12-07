#!/usr/bin/perl

use strict;

use lib qw(../t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib DADA/perllib); 
use dada_test_config; 

use Benchmark qw(cmpthese timethese);
use DADA::Config; 
use DADA::Template::Widgets; 

use HTML::Template; 
use HTML::Template::Pro; 

my $tmpl = tmpl(); 

my %params = (
	'alert'         => 'I am alert.',
    'company.name'  => "MY NAME IS",
    'company_id'    => "10001",
    'office_id'     => "10103214",
    'name'          => 'SAM I AM',
    'address'       => '101011 North Something Something',
    'city'          => 'NEW York',
    'state'         => 'NEw York',
    'zip'           => '10014',
    'phone'         => '212-929-4315',
    'phone2'        => '',
    'subcategories' => 'kfldjaldsf',
    'description' =>
      "dsa;kljkldasfjkldsajflkjdsfklfjdsgkfld\nalskdjklajsdlkajfdlkjsfd\n\talksjdklajsfdkljdsf\ndsa;klfjdskfj",
    'website'       => 'http://www.assforyou.com/',
    'intranet_url'  => 'http://www.something.com',
    'remove_button' => "<INPUT TYPE=SUBMIT NAME=command VALUE=\"Remove Office\">",
    'company_admin_area' =>
      "<A HREF=administrator.cgi?office_id=office_id&command=manage>Manage Office Administrators</A>",
    'casestudies_list' =>
      "adsfkljdskldszfgfdfdsgdsfgfdshghdmfldkgjfhdskjfhdskjhfkhdsakgagsfjhbvdsaj hsgbf jhfg sajfjdsag ffasfj hfkjhsdkjhdsakjfhkj kjhdsfkjhdskfjhdskjfkjsda kjjsafdkjhds kjds fkj skjh fdskjhfkj kj kjhf kjh sfkjhadsfkj hadskjfhkjhs ajhdsfkj akj fkj kj kj  kkjdsfhk skjhadskfj haskjh fkjsahfkjhsfk ksjfhdkjh sfkjhdskjfhakj shiou weryheuwnjcinuc 3289u4234k 5 i 43iundsinfinafiunai saiufhiudsaf afiuhahfwefna uwhf u auiu uh weiuhfiuh iau huwehiucnaiuncianweciuninc iuaciun iucniunciunweiucniuwnciwe",
    'number_of_contacts' => "aksfjdkldsajfkljds",
    'country_selector'   => "klajslkjdsafkljds",
    'logo_link'          => "dsfpkjdsfkgljdsfkglj",
    'photo_link'         => "lsadfjlkfjdsgkljhfgklhasgh",
); 



my $count = 1000;
timethese($count, {
    'HTML Template' => sub {
	
	    my $tmpl = HTML::Template->new(scalarref => \$tmpl );
		
	    $tmpl->param(%params);
	     my $foo =  $tmpl->output;
},
    'HTML Template Pro' => sub {

	    my $tmpl = HTML::Template::Pro->new(scalarref => \$tmpl );
		
	    $tmpl->param(%params);
	     my $foo =  $tmpl->output;
},
   'DADA::Template::Widgets' => sub {
	 my $foo = DADA::Template::Widgets::screen(
		{ 
			-data => \$tmpl, 
			-vars => {
				%params, 
			}
		}
	); 
	 
},
  'DADA::Template::Widgets w/Pro enabled' => sub {
	 my $foo = DADA::Template::Widgets::screen(
		{ 
			-data => \$tmpl, 
			-vars => {
				%params, 
			},
			-pro => 1, 
		}
	); 
	 
},

});

sub tmpl { 
	
return q{ 
	
	<HTML>  
	<HEAD>
	<TITLE> Global Navigator Administration : Office Editor </TITLE>
	</HEAD> 
	<BODY BGCOLOR=#FFFFFF TEXT=#000000>


	<TABLE BGCOLOR=#FFFFFF BORDER=0 CELLSPACING=10 CELLPADING=10 ALIGN=CENTER WIDTH=100%>
	<TR><TD>

	<FONT FACE="Arial, Helvetica, Sans-Serif" SIZE=+1> 
	Office Editor
	<TMPL_VAR NAME=ALERT>
	</FONT>
	</TD></TR>

	<TR><TD>
	<TABLE BORDER=0 BGCOLOR=#000000 WIDTH=100% CELLSPACING=10>
	<TR><TD COLSPAN=2>
	<FONT FACE="Arial, Helvetica, Sans-Serif" COLOR=#FFFFFF> Office Data
	</TD></TR>
	<TR><TD BGCOLOR=#FFFFFF><FONT FACE="Arial, Helvetica, Sans-Serif">
	        <FORM ACTION=office.cgi METHOD=POST ENCTYPE=multipart/form-data>
	        <INPUT TYPE=HIDDEN NAME=command VALUE=updateOffice>
	        <INPUT TYPE=HIDDEN NAME=office_id VALUE=<TMPL_VAR NAME=OFFICE_ID>>
	        <INPUT TYPE=HIDDEN NAME=company_id VALUE=<TMPL_VAR NAME=COMPANY_ID>>
	<TABLE BORDER=2>
	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Company Name
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <A HREF=company.cgi?command=Go&company_id=<TMPL_VAR NAME=COMPANY_ID>><TMPL_VAR NAME=COMPANY.NAME></A>
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Office Name
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=name VALUE="<TMPL_VAR NAME=NAME>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Address
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <TEXTAREA ROWS=2 COLS=40 NAME=address><TMPL_VAR NAME=ADDRESS></TEXTAREA>
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       City
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=city VALUE="<TMPL_VAR NAME=CITY>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       State
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=state VALUE="<TMPL_VAR NAME=STATE>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Country
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <TMPL_VAR NAME=COUNTRY_SELECTOR>
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Postal Code
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=zip VALUE="<TMPL_VAR NAME=ZIP>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Phone Number
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=phone VALUE="<TMPL_VAR NAME=PHONE>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Secondary Phone Number
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=phone2 VALUE="<TMPL_VAR NAME=PHONE2>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Email
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=20 NAME=email VALUE="<TMPL_VAR NAME=EMAIL>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Website
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=40 NAME=website VALUE="<TMPL_VAR NAME=WEBSITE>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Intranet URL
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <INPUT TYPE=TEXT SIZE=40 NAME=intranet_url VALUE="<TMPL_VAR NAME=INTRANET_URL>">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Logo
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <TMPL_VAR NAME=LOGO_LINK>
	       Upload New Logo: <INPUT TYPE=FILE SIZE=10 NAME=new_logo>
	       <INPUT TYPE=SUBMIT NAME=logoUpload VALUE="Upload">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Photo
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <TMPL_VAR NAME=PHOTO_LINK>
	       Upload New Photo: <INPUT TYPE=FILE SIZE=10 NAME=new_photo>
	       <INPUT TYPE=SUBMIT NAME=photoUpload VALUE="Upload">
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Subcategories
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <TEXTAREA NAME=subcategories ROWS=4 COLS=40><TMPL_VAR NAME=SUBCATEGORIES></TEXTAREA>
	       </TD>        
	   </TR>

	   <TR><TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       Description
	       </TD>
	       <TD><FONT FACE="Arial, Helvetica, Sans-Serif">
	       <TEXTAREA NAME=description ROWS=4 COLS=40><TMPL_VAR NAME=DESCRIPTION></TEXTAREA>
	       </TD>        
	   </TR>
	   <TR><TD COLSPAN=2 ALIGN=CENTER><FONT FACE="Arial, Helvetica, Sans-Serif">
	        <INPUT TYPE=SUBMIT NAME=unused VALUE=Update>
	        </FORM>
	        <FORM ACTION=office.cgi METHOD=POST>
	        <INPUT TYPE=HIDDEN NAME=office_id VALUE=<TMPL_VAR NAME=OFFICE_ID>>
	        <INPUT TYPE=HIDDEN NAME=company_id VALUE=<TMPL_VAR NAME=COMPANY_ID>>
	        <TMPL_VAR NAME=REMOVE_BUTTON>
	        </FORM>
	       </TD>
	   </TR>
	</TABLE>
	</TD></TR>

	<TR><TD COLSPAN=2>
	<FONT FACE="Arial, Helvetica, Sans-Serif" COLOR=#FFFFFF> Case Study
	</TD></TR>
	<TR><TD BGCOLOR = #FFFFFF><FONT FACE="Arial, Helvetica, Sans-Serif">
	    <TABLE BORDER=1 BGCOLOR=#FFFFFF WIDTH=100%>
	    <TR>
	    <TD></TD>
	    <TD>
	    <FONT FACE="Arial, Helvetica, Sans-Serif"> <B> Client </B>
	    </TD>
	    <TD>
	    <FONT FACE="Arial, Helvetica, Sans-Serif"> <B> Brands </B>
	    </TD>
	    <TD>
	    <FONT FACE="Arial, Helvetica, Sans-Serif"> <B> Account Manager </B>
	    </TD>
	    </TR>
	<TMPL_VAR NAME=CASESTUDIES_LIST>
	<TR><TD></TD><TD COLSPAN=3><FONT FACE="Arial, Helvetica, Sans-Serif">
	<A HREF=casestudy.cgi?command=Create&office_id=<TMPL_VAR NAME=OFFICE_ID>> Add a Case Study </A>
	</TD>
	</TABLE>

	</TD></TR>
	<TR><TD COLSPAN=2>
	<FONT FACE="Arial, Helvetica, Sans-Serif" COLOR=#FFFFFF> Contacts
	</TD></TR>
	<TR><TD BGCOLOR = #FFFFFF><FONT FACE="Arial, Helvetica, Sans-Serif">
	<FORM ACTION=contact.cgi METHOD=POST>
	<INPUT TYPE=HIDDEN NAME=command value=manage>
	<INPUT TYPE=HIDDEN NAME=office_id value=<TMPL_VAR NAME=OFFICE_ID>>
	This office has <TMPL_VAR NAME=NUMBER_OF_CONTACTS> Contacts.<BR>  <INPUT TYPE=Submit NAME=unused VALUE="Manage Contacts">
	</FORM>
	</TD>
	</TABLE>

	</TD></TR>

	</TABLE>
	</TD></TR>

	<TMPL_VAR NAME=COMPANY_ADMIN_AREA>

	</TABLE>
	</BODY>
	</HTML>
	
}; 
}