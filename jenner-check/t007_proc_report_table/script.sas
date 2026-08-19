/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 711-716 (the final
   "Demographics" report table, one row per summary metric with prevalent vs.
   incident cohort columns). Original builds this from the real "demographics"
   dataset assembled across the whole script from MarketScan claims data, and
   writes it to an ODS EXCEL workbook. Here the same PROC REPORT column
   layout and labels run against a small synthetic summary table (the report
   plumbing, not the ODS EXCEL destination, is what's under test -- the
   listing below is Jenner's default text destination), since the real
   demographics table is built from restricted-access commercial claims data
   and does not ship in the repo. */

data demographics;
	length txt1 $50 col1 $20 col2 $20;
	input txt1 & $50. col1 $20. col2 $20.;
	datalines;
N                                                 412 (100%)          98 (100%)
Female n (%)                                     312 (75.7%)          71 (72.4%)
Mean age years at index date (standard deviation) 52.3 (14.2)          49.8 (15.1)
Age range: 18-44 years, n (%)                    103 (25.0%)          29 (29.6%)
Age range: 45-54 years, n (%)                    98 (23.8%)           21 (21.4%)
;
run;

proc report data=demographics;
	column txt1  col1  col2 ;
	define txt1 / display "METRIC";
	define col1 / display "SS Prevalent Cohort";
	define col2 / display "SS Incident Cohort";
run;
