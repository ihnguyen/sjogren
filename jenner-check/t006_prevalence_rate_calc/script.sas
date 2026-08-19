/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 651-696 (overall and
   gender-stratified prevalence/incidence rate calculation, reported per
   100,000). Original runs this PROC SQL SELECT ... INTO :macrovar block
   against the real "genderadd"/"prevalence"/"population" cohorts built from
   MarketScan claims data earlier in the script. Here the same SELECT INTO
   macro-variable population and per-100,000 rate arithmetic runs against a
   small synthetic cohort and population denominator, since the real cohorts
   are restricted-access commercial claims data and do not ship in the repo.
   The rate formula and rounding are unchanged from the source. */

data genderadd;
	length enrolid 8 sex 8;
	input enrolid sex;
	datalines;
5001 2
5002 1
5003 2
5004 2
5005 1
;
run;

data population;
	length enrolid 8 sex 8;
	input enrolid sex;
	datalines;
9001 1
9002 1
9003 1
9004 2
9005 2
9006 2
9007 2
9008 1
9009 2
9010 1
;
run;

proc sql;
		select count(sex) into: n1 from genderadd;
		select count(sex) into: n5 from genderadd where sex='1';
		select count(sex) into: n7 from genderadd where sex='2';

		select count(enrolid) into: n0 from population;
		select count(sex) into: n19 from population where sex='1';
		select count(sex) into: n20 from population where sex='2';
quit;

%put &n0. &n1. &n5. &n7. &n19. &n20.;

data all; txt1='All'; prev= compress(put(round((&n1./&n0.)*100000,0.01),10.1)); sort=2; run;
data female; txt1='Gender: Female'; prev=compress(put((&n7./&n20.)*100000,10.1)); sort=3; run;
data male; txt1='Gender: Male'; prev=compress(put((&n5./&n19.)*100000,10.1)); sort=4; run;

data overallrates; length txt1 $50.; set all female male; run;
proc sort data=overallrates; by sort; run;

proc print data=overallrates noobs;
	var txt1 prev;
run;
