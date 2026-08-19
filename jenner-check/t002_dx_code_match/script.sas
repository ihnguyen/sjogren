/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 328-361.
   Original merges three real claims extracts (f_combined/is_combined/o_combined,
   read from external MarketScan-derived paths) and scans up to 15 wide dx columns
   plus a primary pdx column for a Sjogren's syndrome ICD-9/ICD-10 code
   ('7102' or 'M350*'). Here the same wide-column diagnosis-code scan and rename
   logic run against a small synthetic claims panel with fabricated dx values,
   since the real extracts are restricted-access commercial claims data and do
   not ship in the repo. The matching logic (ICD-9 exact code, ICD-10 prefix via
   SUBSTR, first-match-wins across dx1-dx15/pdx) is unchanged from the source. */

data allcombined;
	length enrolid 8 dx1-dx9 pdx $6 sex 8 o_date is_date f_date 8;
	input enrolid dx1 $ dx2 $ dx3 $ pdx $ sex o_date :mmddyy10.;
	format o_date mmddyy10.;
	datalines;
2001 7102 4019 25000 7102 2 03/12/2015
2002 71530 M35019 4019 71530 1 05/02/2016
2003 4019 25000 41401 4019 2 07/19/2015
2004 M35000 71530 25000 M35000 1 11/03/2017
2005 25000 4019 71530 25000 2 01/22/2016
;
run;

data allcombined;
	set allcombined;
	if  dx1 = '7102' or substr(dx1,1,4) = 'M350' then dx=dx1;
		else if dx2 = '7102' or substr(dx2,1,4) = 'M350' then dx=dx2;
		else if dx3 = '7102' or substr(dx3,1,4) = 'M350' then dx=dx3;
		else if pdx = '7102' or substr(pdx,1,4) = 'M350' then dx=pdx;
	else dx='';
run;

proc freq data=allcombined;
	table dx / missing;
run;

proc print data=allcombined noobs;
	var enrolid dx1 dx2 dx3 pdx dx;
run;
