package Geography::Countries;

use 5.006;

use strict;
use warnings;
no  warnings 'syntax';

use Exporter ();

our @ISA         = qw /Exporter/;
our @EXPORT      = qw /country/;
our @EXPORT_OK   = qw /code2         code3       numcode       countries
                       CNT_I_CODE2   CNT_I_CODE3 CNT_I_NUMCODE CNT_I_COUNTRY
                       CNT_I_FLAG
                       CNT_F_REGULAR CNT_F_OLD   CNT_F_REGION  CNT_F_ANY/;
our %EXPORT_TAGS = (LISTS   => [qw /code2 code3   numcode     countries/],
                    INDICES => [qw /CNT_I_CODE2   CNT_I_CODE3 CNT_I_NUMCODE
                                    CNT_I_COUNTRY CNT_I_FLAG/],
                    FLAGS   => [qw /CNT_F_REGULAR CNT_F_OLD
                                    CNT_F_REGION  CNT_F_ANY/],);

our $VERSION     = '2009041301';


use constant CNT_I_CODE2   =>    0;
use constant CNT_I_CODE3   =>    1;
use constant CNT_I_NUMCODE =>    2;
use constant CNT_I_COUNTRY =>    3;
use constant CNT_I_FLAG    =>    4;

use constant CNT_F_REGULAR => 0x01;
use constant CNT_F_OLD     => 0x02;
use constant CNT_F_REGION  => 0x04;
use constant CNT_F_ANY     => CNT_F_REGULAR | CNT_F_OLD | CNT_F_REGION;

my (%info, @code2, @code3, @numcode, @countries);

sub norm ($) {
    my $query = shift;
    die "Illegal argument to norm\n" unless defined $query;
    return sprintf "%03d" => $query  unless $query =~ /\D/;
    $query =  lc $query;
    $query =~ s/\s+//g;

    $query;
}

binmode (DATA, ':encoding(iso-8859-1)') if $] >= 5.008;

my $flag;
my %flags   = (
    Regular => CNT_F_REGULAR,
    Old     => CNT_F_OLD,
    Region  => CNT_F_REGION,
);
while (<DATA>) {
    chomp;
    last if $_ eq '__END__';
    s/#.*//;
    next unless /\S/;
    if (/^%%\s*(\S.*\S)\s*%%$/) {
        $flag = $flags {$1} or
                 die "Found illegal flag ``$1'' while parsing __DATA__\n";
        next;
    }
    my $code2   = substr $_,  0, 2;  $code2   = undef if $code2   =~ /\s/;
    my $code3   = substr $_,  3, 3;  $code3   = undef if $code3   =~ /\s/;
    my $numcode = substr $_,  7, 3;  $numcode = undef if $numcode =~ /\s/;
    my $country = substr $_, 11;

    push @code2     =>  $code2   if defined $code2;
    push @code3     =>  $code3   if defined $code3;
    push @numcode   =>  $numcode if defined $numcode;
    push @countries =>  $country;

    my $info    = [$code2, $code3, $numcode, $country, $flag];

    $info {norm $code2}   =  $info if defined $code2  ;
    $info {norm $code3}   =  $info if defined $code3  ;
    $info {$numcode}      =  $info if defined $numcode;

    $info {norm $country} =  $info;
}

@code2     = sort @code2;
@code3     = sort @code3;
@numcode   = sort @numcode;
@countries = sort @countries;

sub code2     {@code2}
sub code3     {@code3}
sub numcode   {@numcode}
sub countries {@countries}


sub country ($;$) {
    my $sub = (caller (0)) [3];

    die "No arguments for $sub.\n"           unless @_;
    die "Too many arguments for $sub.\n"     unless @_ <= 2;

    my ($query, $flags) = @_;

    die "Undefined argument for $sub.\n"     unless defined $query;

    $flags ||=  CNT_F_REGULAR;

    die "Illegal second argument to $sub.\n" if $flags =~ /\D/;

    my $info =  $info {norm $query} or return;

    return unless $info -> [CNT_I_FLAG] & $flags;

    wantarray ? @$info : $info -> [CNT_I_COUNTRY];

}

1;

=pod

=head1 NAME

Geography::Countries - 2-letter, 3-letter, and numerical codes for countries.

=head1 SYNOPSIS

    use Geography::Countries;

    $country = country 'DE';  # 'Germany'
    @list    = country  666;  # ('PM', 'SPM', 666,
                              #  'Saint Pierre and Miquelon', 1)

=head1 DESCRIPTION

This module maps country names, and their 2-letter, 3-letter and
numerical codes, as defined by the ISO-3166 maintenance agency [1],
and defined by the UNSD.

=head2 The C<country> subroutine.

This subroutine is exported by default. It takes a 2-letter, 3-letter or
numerical code, or a country name as argument. In scalar context, it will
return the country name, in list context, it will return a list consisting
of the 2-letter code, the 3-letter code, the numerical code, the country
name, and a flag, which is explained below. Note that not all countries
have all 3 codes; if a code is unknown, the undefined value is returned.

There are 3 categories of countries. The largest category are the 
current countries. Then there is a small set of countries that no
longer exist. The final set consists of areas consisting of multiple
countries, like I<Africa>. No 2-letter or 3-letter codes are available
for the second two sets. (ISO 3166-3 [3] defines 4 letter codes for the
set of countries that no longer exist, but the author of this module
was unable to get her hands on that standard.) By default, C<country>
only returns countries from the first set, but this can be changed
by giving C<country> an optional second argument.

The module optionally exports the constants C<CNT_F_REGULAR>,
C<CNT_F_OLD>, C<CNT_F_REGION> and C<CNT_F_ANY>. These constants can also
be important all at once by using the tag C<:FLAGS>. C<CNT_F_ANY> is just
the binary or of the three other flags. The second argument of C<country>
should be the binary or of a subset of the flags C<CNT_F_REGULAR>,
C<CNT_F_OLD>, and C<CNT_F_REGION> - if no, or a false, second argument is
given, C<CNT_F_REGULAR> is assumed. If C<CNT_F_REGULAR> is set, regular
(current) countries will be returned; if C<CNT_F_OLD> is set, old,
no longer existing, countries will be returned, while C<CNT_F_REGION>
is used in case a region (not necessarely) a country might be returned.
If C<country> is used in list context, the fifth returned element is
one of C<CNT_F_REGULAR>, C<CNT_F_OLD> and C<CNT_F_REGION>, indicating
whether the result is a regular country, an old country, or a region.

In list context, C<country> returns a 5 element list. To avoid having
to remember which element is in which index, the constants C<CNT_I_CODE2>,
C<CNT_I_CODE3>, C<CNT_I_NUMCODE>, C<CNT_I_COUNTRY> and C<CNT_I_FLAG>
can be imported. Those constants contain the indices of the 2-letter code,
the 3-letter code, the numerical code, the country, and the flag explained
above, respectively. All index constants can be imported by using the
C<:INDICES> tag.

=head2 The C<code2>, C<code3>, C<numcode> and C<countries> routines.

All known 2-letter codes, 3-letter codes, numerical codes and country
names can be returned by the routines C<code2>, C<code3>, C<numcode> and
C<countries>. None of these methods is exported by default; all need to
be imported if one wants to use them. The tag C<:LISTS> imports them 
all. In scalar context, the number of known codes or countries is returned.

=head1 REFERENCES

The 2-letter codes come from the ISO 3166-1:1997 standard [2]. ISO 3166
bases its list of country names on the list of names published by
the United Nations. This list is published by the Statistical Division
of the United Nations [4]. The UNSD uses 3-letter codes, and numerical
codes [5]. The information about old countries [6] and regions [7] also
comes from the United Nations.

In a few cases, there was a conflict between the way how the United 
Nations spelled a name, and how ISO 3166 spells it. In most cases,
is was word order (for instance whether I<The republic of> should
preceed the name, or come after the name. A few cases had minor
spelling variations. In all such cases, the method in which the UN
spelled the name was choosen; ISO 3166 claims to take the names from
the UN, so we consider the UN authoritative.

=over 4

=item [1]

ISO Maintenance Agency (ISO 3166/MA)
I<http://www.din.de/gremien/nas/nabd/iso3166ma/index.html>.

=item [2]

I<Country codes>,
I<http://www.din.de/gremien/nas/nabd/iso3166ma/codlstp1.html>,
7 September 1999.

=item [3]

ISO 3166-3, I<Code for formerly used country names>.
I<http://www.din.de/gremien/nas/nabd/iso3166ma/info_pt3.html>.

=item [4]

United Nations, Statistics Division.
I<http://www.un.org/Depts/unsd/statdiv.htm>.

=item [5]

I<Country or area codes in alphabetical order>.
I<http://www.un.org/Depts/unsd/methods/m49alpha.htm>,
26 August 1999.

=item [6]

I<Codes added or changed>.
I<http://www.un.org/Depts/unsd/methods/m49chang.htm>,
26 August 1999.

=item [7]

I<Geographical regions>.
I<http://www.un.org/Depts/unsd/methods/m49regin.htm>,
26 August 1999.

=back

=head1 BUGS

Looking up information using country names is far from perfect.
Except for case and the amount of white space, the exact name as it
appears on the list has to be given. I<USA> will not return anything,
but I<United States> will.

=head1 DEVELOPMENT
    
The current sources of this module are found on github,
L<< git://github.com/Abigail/geography--countries.git >>.
    
=head1 AUTHOR
    
Abigail L<< mailto:geography-countries@abigail.be >>.
    
=head1 COPYRIGHT and LICENSE
       
Copyright (C) 1999, 2009 by Abigail
    
Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut

__DATA__
%% Regular %%
AF AFG 004 Afghanistan
AL ALB 008 Albania
DZ DZA 012 Algeria
AS ASM 016 American Samoa
AD AND 020 Andorra
AO AGO 024 Angola
AI AIA 660 Anguilla
AQ         Antarctica
AG ATG 028 Antigua and Barbuda
       896 Areas not elsewhere specified
       898 Areas not specified
AR ARG 032 Argentina
AM ARM 051 Armenia
AW ABW 533 Aruba
AU AUS 036 Australia
AT AUT 040 Austria
AZ AZE 031 Azerbaijan
BS BHS 044 Bahamas
BH BHR 048 Bahrain
BD BGD 050 Bangladesh
BB BRB 052 Barbados
BY BLR 112 Belarus
BE BEL 056 Belgium
BZ BLZ 084 Belize
BJ BEN 204 Benin
BM BMU 060 Bermuda
BT BTN 064 Bhutan
BO BOL 068 Bolivia
BA BIH 070 Bosnia and Herzegovina
BW BWA 072 Botswana
BV         Bouvet Island
BR BRA 076 Brazil
IO         British Indian Ocean Territory
VG VGB 092 British Virgin Islands
BN BRN 096 Brunei Darussalam
BG BGR 100 Bulgaria
BF BFA 854 Burkina Faso
BI BDI 108 Burundi
KH KHM 116 Cambodia
CM CMR 120 Cameroon
CA CAN 124 Canada
CV CPV 132 Cape Verde
KY CYM 136 Cayman Islands
CF CAF 140 Central African Republic
TD TCD 148 Chad
       830 Channel Islands
CL CHL 152 Chile
CN CHN 156 China
CX         Christmas Island
CC         Cocos (keeling) Islands
CO COL 170 Colombia
KM COM 174 Comoros
CG COG 178 Congo
CK COK 184 Cook Islands
CR CRI 188 Costa Rica
CI CIV 384 Côte d'Ivoire
HR HRV 191 Croatia
CU CUB 192 Cuba
CY CYP 196 Cyprus
CZ CZE 203 Czech Republic
KP PRK 408 Democratic People's Republic of Korea
CD COD 180 Democratic Republic of the Congo
DK DNK 208 Denmark
DJ DJI 262 Djibouti
DM DMA 212 Dominica
DO DOM 214 Dominican Republic
TP TMP 626 East Timor
EC ECU 218 Ecuador
EG EGY 818 Egypt
SV SLV 222 El Salvador
GQ GNQ 226 Equatorial Guinea
ER ERI 232 Eritrea
EE EST 233 Estonia
ET ETH 231 Ethiopia
FO FRO 234 Faeroe Islands
FK FLK 238 Falkland Islands (Malvinas)
FM FSM 583 Micronesia, Federated States of
FJ FJI 242 Fiji
FI FIN 246 Finland
MK MKD 807 The former Yugoslav Republic of Macedonia
FR FRA 250 France
GF GUF 254 French Guiana
PF PYF 258 French Polynesia
TF         French Southern Territories
GA GAB 266 Gabon
GM GMB 270 Gambia
GE GEO 268 Georgia
DE DEU 276 Germany
GH GHA 288 Ghana
GI GIB 292 Gibraltar
GR GRC 300 Greece
GL GRL 304 Greenland
GD GRD 308 Grenada
GP GLP 312 Guadeloupe
GU GUM 316 Guam
GT GTM 320 Guatemala
GN GIN 324 Guinea
GW GNB 624 Guinea-Bissau
GY GUY 328 Guyana
HT HTI 332 Haiti
HM         Heard Island And Mcdonald Islands
VA VAT 336 Holy See
HN HND 340 Honduras
HK HKG 344 Hong Kong Special Administrative Region of China
HU HUN 348 Hungary
IS ISL 352 Iceland
IN IND 356 India
ID IDN 360 Indonesia
IR IRN 364 Iran (Islamic Republic of)
IQ IRQ 368 Iraq
IE IRL 372 Ireland
   IMY 833 Isle of Man
IL ISR 376 Israel
IT ITA 380 Italy
JM JAM 388 Jamaica
JP JPN 392 Japan
JO JOR 400 Jordan
KZ KAZ 398 Kazakhstan
KE KEN 404 Kenya
KI KIR 296 Kiribati
KW KWT 414 Kuwait
KG KGZ 417 Kyrgyzstan
LA LAO 418 Lao People's Democratic Republic
LV LVA 428 Latvia
LB LBN 422 Lebanon
LS LSO 426 Lesotho
LR LBR 430 Liberia
LY LBY 434 Libyan Arab Jamahiriya
LI LIE 438 Liechtenstein
LT LTU 440 Lithuania
LU LUX 442 Luxembourg
MO MAC 446 Macau
MG MDG 450 Madagascar
MW MWI 454 Malawi
MY MYS 458 Malaysia
MV MDV 462 Maldives
ML MLI 466 Mali
MT MLT 470 Malta
MH MHL 584 Marshall Islands
MQ MTQ 474 Martinique
MR MRT 478 Mauritania
MU MUS 480 Mauritius
YT         Mayotte
MX MEX 484 Mexico
MC MCO 492 Monaco
MN MNG 496 Mongolia
MS MSR 500 Montserrat
MA MAR 504 Morocco
MZ MOZ 508 Mozambique
MM MMR 104 Myanmar
NA NAM 516 Namibia
NR NRU 520 Nauru
NP NPL 524 Nepal
NL NLD 528 Netherlands
AN ANT 530 Netherlands Antilles
NC NCL 540 New Caledonia
NZ NZL 554 New Zealand
NI NIC 558 Nicaragua
NE NER 562 Niger
NG NGA 566 Nigeria
NU NIU 570 Niue
NF NFK 574 Norfolk Island
MP MNP 580 Northern Mariana Islands
NO NOR 578 Norway
   PSE 275 Occupied Palestinian Territory
OM OMN 512 Oman
PK PAK 586 Pakistan
PW PLW 585 Palau
PA PAN 591 Panama
PG PNG 598 Papua New Guinea
PY PRY 600 Paraguay
PE PER 604 Peru
PH PHL 608 Philippines
PN PCN 612 Pitcairn
PL POL 616 Poland
PT PRT 620 Portugal
PR PRI 630 Puerto Rico
QA QAT 634 Qatar
KR KOR 410 Republic of Korea
MD MDA 498 Republic of Moldova
RO ROM 642 Romania
RE REU 638 Réunion
RU RUS 643 Russian Federation
RW RWA 646 Rwanda
SH SHN 654 Saint Helena
KN KNA 659 Saint Kitts and Nevis
LC LCA 662 Saint Lucia
PM SPM 666 Saint Pierre and Miquelon
VC VCT 670 Saint Vincent and the Grenadines
WS WSM 882 Samoa
SM SMR 674 San Marino
ST STP 678 Sao Tome and Principe
SA SAU 682 Saudi Arabia
SN SEN 686 Senegal
SC SYC 690 Seychelles
SL SLE 694 Sierra Leone
SG SGP 702 Singapore
SK SVK 703 Slovakia
SI SVN 705 Slovenia
SB SLB 090 Solomon Islands
SO SOM 706 Somalia
ZA ZAF 710 South Africa
GS         South Georgia And The South Sandwich Islands
ES ESP 724 Spain
LK LKA 144 Sri Lanka
SD SDN 736 Sudan
SR SUR 740 Suriname
SJ SJM 744 Svalbard and Jan Mayen Islands
SZ SWZ 748 Swaziland
SE SWE 752 Sweden
CH CHE 756 Switzerland
SY SYR 760 Syrian Arab Republic
TW TWN 158 Taiwan Province of China
TJ TJK 762 Tajikistan
TH THA 764 Thailand
TG TGO 768 Togo
TK TKL 772 Tokelau
TO TON 776 Tonga
TT TTO 780 Trinidad and Tobago
TN TUN 788 Tunisia
TR TUR 792 Turkey
TM TKM 795 Turkmenistan
TC TCA 796 Turks and Caicos Islands
TV TUV 798 Tuvalu
UG UGA 800 Uganda
UA UKR 804 Ukraine
AE ARE 784 United Arab Emirates
GB GBR 826 United Kingdom
TZ TZA 834 United Republic of Tanzania
US USA 840 United States
UM         United States Minor Outlying Islands
VI VIR 850 United States Virgin Islands
UY URY 858 Uruguay
UZ UZB 860 Uzbekistan
VU VUT 548 Vanuatu
VE VEN 862 Venezuela
VN VNM 704 Viet Nam
WF WLF 876 Wallis and Futuna Islands
EH ESH 732 Western Sahara
YE YEM 887 Yemen
YU YUG 891 Yugoslavia
ZM ZMB 894 Zambia
ZW ZWE 716 Zimbabwe
%% Old %%
       810 Union of Soviet Socialist Republics
       532 Netherlands Antilles
       890 Socialist Federal Republic of Yugoslavia
       200 Czechoslovakia
       278 German Democratic Republic
       280 Federal Republic of Germany
       582 Pacific Islands (Trust Territory)
       720 Democratic Yemen
       886 Yemen
       230 Ethiopia
       104 Burma
       116 Democratic Kampuchea
       180 Zaire
       384 Ivory Coast
       854 Upper Volta
%% Region %%
       002 Africa
       014 Eastern Africa
       017 Middle Africa
       015 Northern Africa
       018 Southern Africa
       011 Western Africa
       019 Americas
       419 Latin America and the Caribbean
       029 Caribbean
       013 Central America
       005 South America
       021 Northern America
       142 Asia
       030 Eastern Asia
       062 South-central Asia
       035 South-eastern Asia
       145 Western Asia
       150 Europe
       151 Eastern Europe
       154 Northern Europe
       039 Southern Europe
       155 Western Europe
       009 Oceania
       053 Australia and New Zealand
       054 Melanesia
       055 Micronesia-Polynesia
       057 Micronesia
       061 Polynesia
__END__
