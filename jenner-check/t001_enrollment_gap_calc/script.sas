/* Adapted from "SAS code.sas" (ihnguyen/sjogren), lines 1-75.
   Original reads an external MarketScan-derived enrollment-span extract via
   `set 'C:\Users\...\merged';` and a real index date per patient. Here the
   same enrollment-span / index-window / gap logic is exercised against a
   small synthetic panel of fabricated enrollee ids and coverage spans, since
   the original dataset is restricted-access commercial claims data and does
   not ship in the repo. The pre/post index window construction, LAG-based
   gap detection, and cumulative coverage logic are otherwise unchanged. */

data merged;
	length enrolid 8 dtstart dtend indexdt memdays 8;
	input enrolid dtstart :mmddyy10. dtend :mmddyy10. indexdt :mmddyy10. memdays;
	preindex = indexdt-183;
	postindex = indexdt+183;
	format dtstart dtend indexdt preindex postindex mmddyy10.;
	datalines;
1001 01/01/2015 06/30/2015 04/01/2015 181
1001 07/01/2015 12/31/2015 04/01/2015 184
1002 02/01/2015 07/31/2015 05/01/2015 181
1002 08/15/2015 01/31/2016 05/01/2015 170
1003 03/01/2015 08/31/2015 06/01/2015 184
1004 01/15/2015 07/14/2015 04/15/2015 181
1004 07/20/2015 01/15/2016 04/15/2015 180
1005 04/01/2015 09/30/2015 07/01/2015 183
;
run;

proc sort data=merged; by enrolid dtstart dtend; run;

proc sql; select count(distinct enrolid) as count from merged; quit;

data lag;
	set merged;
	by enrolid;
	lag=lag(dtend);
	if first.enrolid then lag=.;
	format lag mmddyy10.;
run;

data gap;
	set lag;
	by enrolid;
	gap = dtstart-lag-1;

	if preindex <= dtend <= indexdt then indpre = 1;
	else if month(dtstart) = month(indexdt) and year(dtstart) = year(indexdt) or month(dtend) = month(indexdt) and year(dtend) = year(indexdt) then do; indpre=1; indpos=2; end;
	else if indexdt <= dtstart <= postindex then indpos= 2;
	else do; indpre=.; indpos=.; end;

run;

data prepostgap;
	set gap;

	if indpre=1 then pregap=dtstart-lag-1;
		else if indpre=1 and dtstart>preindex then pregap=dtstart-preindex-1;
		else if indpre=1 and dtend<indexdt then pregap=indexdt-dtend-1;
		else pregap=.;

	if indpos=2 then posgap=dtstart-lag-1;
		else if indpos=2 and dtstart>indexdt then posgap=dtstart-indexdt-1;
		else if indpos=2 and dtend<postindex then posgap=postindex-dtend-1;
		else posgap=.;

	if indpre=1 and indpos=2 and indexdt>=lag and gap>0 then do; pregap=dtstart-lag-1; posgap=gap-pregap; end;
		else do; pregap=pregap; posgap=posgap; end;

run;

data prepostindex;
	set prepostgap;
	if indpre^=. or indpos^=.;
run;

proc print data=prepostindex noobs;
	var enrolid dtstart dtend indpre indpos pregap posgap;
run;
