/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 512-526 (age-range
   n/percent formatting for the demographics summary table). Original runs
   this PROC FREQ + string-formatting pipeline against the real "inc"/"prev"
   labeled cohorts built earlier in the script from MarketScan claims data.
   Here the same PROC FREQ NOPRINT -> comma-formatted count -> "n (%)"
   string-build pipeline runs against a small synthetic labeled cohort, since
   the real cohorts are restricted-access commercial claims data and do not
   ship in the repo. The formatting logic (put(count,8.), comma6., 10.1
   percent, concatenation) is unchanged from the source. */

data inc;
	length txt1 $30;
	input txt1 $30.;
	datalines;
Age range: 18-44 years, n (%)
Age range: 18-44 years, n (%)
Age range: 45-54 years, n (%)
Age range: 55-64 years, n (%)
Age range: 65-74 years, n (%)
Age range: >=75 years, n (%)
Age range: >=75 years, n (%)
Age range: >=75 years, n (%)
;
run;

* Calculate Age n and percent;
proc freq noprint data=inc; table txt1 / out=incfreq; run;
data incid1; length var 8.; set incfreq;
	var= compress(put(count,8.)); run;
data incid; set incid1; var1= put(var,comma6.);
	col2 = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;

proc print data=incid noobs;
	var txt1 col2;
run;
