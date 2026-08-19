/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 474-510.
   Original calls the repo's own %format and %prov macros against the real
   "incidence" and "prevalence" patient-level cohorts built earlier in the
   script (age/sex/provider-specialty fields from MarketScan claims data).
   Here the same two macros -- unchanged from the source -- are called against
   a small synthetic cohort of fabricated enrollee ages, sexes, and provider
   specialty codes, since the real cohorts are restricted-access commercial
   claims data and do not ship in the repo. */

data incidence;
	length enrolid 8 age 8 sex 8 stdprov 8;
	input enrolid age sex stdprov;
	datalines;
3001 29 2 300
3002 47 1 240
3003 61 2 204
3004 70 2 330
3005 39 2 .
3006 81 1 999
;
run;

* Create macro variable for age range assignments;
%macro format(new, old);
data &new;
length txt1 txt2 $30.;
	set &old;
if 18<=age<=44 then do; txt1 = 'Age range: 18-44 years, n (%)'; sort=4; end;
	else if 45<=age<=54 then do; txt1 = 'Age range: 45-54 years, n (%)'; sort=5; end;
	else if 55<=age<=64 then do; txt1 = 'Age range: 55-64 years, n (%)'; sort=6; end;
	else if 65<=age<=74 then do; txt1 = 'Age range: 65-74 years, n (%)'; sort=7; end;
	else if 75<=age then do; txt1='Age range: >=75 years, n (%)'; sort=8; end;
	else txt1='missing';
if sex=1 then txt2= 'Male';
	else if sex=2 then do; txt2= 'Female'; sort=1; end;
	else txt2='missing';
keep txt1 txt2 sort;
run;
%mend;
%format(inc,incidence);

* Create macro for specialty assignments;
%macro prov(new, old);
data &new;
length txt1 $50.;
	set &old;
if stdprov=204 then txt1= 'Physician specialty: Internal Medicine, n (%)';
	else if stdprov=240 then txt1= 'Physician specialty: Family Practice, n (%)';
	else if stdprov=330 then txt1= 'Physician specialty: Ophthalmology, n (%)';
	else if stdprov=300 then txt1= 'Physician specialty: Rheumatology, n (%)';
	else if stdprov=. then txt1= 'Physician specialty: Unknown, n (%)';
	else txt1='Physician specialty: Others, n (%)';
keep txt1;
run;
%mend;

%prov(incprov,incidence);

proc print data=inc noobs; run;
proc print data=incprov noobs; run;
