/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 96-108 (exclusion
   criterion 3: "Removed pre index with 2 or more gaps"). Original runs this
   PROC SQL GROUP BY / HAVING count against the real "all" cohort built
   earlier in the script from MarketScan claims enrollment spans, then
   QC-checks the exclusion against a real reference dataset via a DATA-step
   merge anti-join (wc000001.qc_ss_prev). Here the same GROUP BY / HAVING
   exclusion-flagging logic runs against a small synthetic panel of
   fabricated enrollee gap records, since the real cohort and QC reference
   are restricted-access commercial claims data and do not ship in the repo.
   The exclusion criterion itself (>1 pre-index gap between 1 and 30 days)
   is unchanged from the source. */

data all;
	length enrolid 8 indpre 8 gap 8 gap1 8;
	input enrolid indpre gap gap1;
	datalines;
4001 1 5 .
4001 1 12 .
4002 1 20 .
4003 1 . .
4004 1 3 .
4004 1 9 .
4004 1 15 .
4005 1 31 .
;
run;

proc sql;
create table exclude3 as
	select enrolid, indpre, gap, gap1, count(gap) as count
	from all
	where 0<gap<=30 and indpre=1
	group by enrolid
	having count>1;
quit;

proc print data=exclude3 noobs; run;
