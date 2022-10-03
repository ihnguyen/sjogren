******************  Load data;
data merged;
set 'C:\Users\tnguyen\Desktop\RWE\merged';
preindex = indexdt-183;
postindex = indexdt+183;
format preindex postindex mmddyy10.;
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

*pregap=dtstart-lag;
*	else if indpre=1 and indpos=2 and dtstart<=indexdt then posgap;

run;

data prepostindex;
	set prepostgap;
if indpre^=. or indpos^=.;
run;
data all;
	set prepostindex;
	by enrolid;

if first.enrolid then do; index=1;gap=dtstart-preindex-1; cumulative=gap; end;
	else index+1;

if last.enrolid then lastgap = postindex-dtend-1;
	else lastgap=.;

*if last.enrolid then gap=postindex-dtend+gap;
cumulative+memdays;

if indpre=1 and indpos=2 and gap>1 then do; gap=.; posgap=.; gap1=dtstart-lag-1;gap2=dtend-indexdt-1; end;
	else if lag<=indexdt<=dtstart then do; gap=.; posgap=.; gap1 = indexdt-lag-1; gap2=dtstart-indexdt-1; end;
	else do; gap1=.; gap2=.; end;

if first.enrolid and lag<preindex then pregap= dtstart-preindex-1; 
if last.enrolid and lag<preindex then posgap= dtstart-lag-1;

run;


* 1 - Removed patients with less than 6 months cumulative;
data exclude1; set all; by enrolid;
if last.enrolid and cumulative<180 then output; run;
data test;*** hooray! zero observations;
	merge exclude1 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 2 - Removed pre or post index with greater than 30 day gap;
data exclude2; set all; 
	if gap1>30 or gap2>30 then output; run;
data test;*** hooray! zero observations;
	merge exclude2 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 3 - Removed pre index with 2 or more gaps;
proc sql;
create table exclude3 as
	select enrolid, indpre, gap, gap1, count(gap) as count
	from all
	where 0<gap<=30 and indpre=1
	group by enrolid
	having count>1;
quit;
data test; *** hooray! zero observations;
	merge exclude3 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 4 - Removed post index with 2 or more gaps;
proc sql;
create table exclude4 as
	select enrolid, indpos, gap, gap2, count(gap) as count
	from all
	where 0<gap<=30 and indpos=2
	group by enrolid
	having count>1;
quit;
data test; *** hooray! zero observations;
	merge exclude4 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 5 - Removed patients with greater than 30 day gap and less than cumulative 6 months;
data sixmonthscum; set all;
	by enrolid;
	if last.enrolid and cumulative>170 then incflag=1; else incflag=.;
data nodupesix; set sixmonthscum;
	if incflag=1; run;
data belowsixmo; merge nodupesix(in=a) all(in=b); by enrolid; if b and not a then output; run;
data exclude5; set belowsixmo;
	if gap>30 then output;
data test; *** hooray! zero observations;
	merge exclude5 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 6 - Remove patients with 3 or more gaps across both pre and post index periods;
proc sql; create table allgaps as select enrolid, lastgap, gap, count(gap) as count from all where gap>0 or lastgap>0 group by enrolid; quit;
data counting; set allgaps;
	if gap=. and lastgap^=. then count+2;
	else if gap=. then count+1;
	else count+0; run;
data exclude6; set counting;
	if count>2 then output;
run;
data test; *** hooray! zero observations;
	merge exclude6 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 7 - Remove patients;
data lessixmonth; set all;
	by enrolid;
	if last.enrolid and cumulative<170 then excflag=1; else excflag=.;
data nodupelessix; set lessixmonth; if excflag=1; run;
data exclude7; set nodupelessix; if gap>30; run;
data test; *** hooray! zero observations;
	merge exclude7 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 8 - Remove pre and post gaps greater than 30 days; 
data exclude8; set all; if pregap>30 or posgap>30; run; 
data test; 
	merge exclude8 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;

* 9 and 10 - Check those with gap>0;
data check; set all;
	if gap>0; run;
data exclude9; set check;
	if indpre=1 and indpos=. and gap>30 then output; run;
data test; 
	merge exclude9 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;
* Check those with gap>0;
data exclude10; set check;
	if indpos=2 and indpre=. and gap>30 then output; run;
data test; 
	merge exclude10 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;

* 11 - Exclude those that don't have at least five months in each pre and post periods;
proc sql; create table precount as select enrolid, count(indpre) as precount from all where indpre=1 group by enrolid having precount<5; quit;
proc sql; create table poscount as select enrolid, count(indpos) as poscount from all where indpos=2 group by enrolid having poscount<5; quit;
data exclude11;
	merge precount poscount;
	by enrolid; run;
data test; 
	merge exclude11 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;

* 12 - Exclude last observations' gap>30 when poscount>=5;
proc sql; create table lastgap as select enrolid, lastgap, count(indpos) as poscount from all where indpos=2 group by enrolid having 5<=poscount<6; quit;
data exclude12;
	set lastgap;
	if lastgap>30 then output;
	run;
data test; ** sadface;
	merge exclude12 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;

* 13 - Exclude poscount = 5;
proc sql; create table five as select enrolid, count(indpos) as poscount from all where indpos=2 group by enrolid having poscount=5; quit;
data exclude13;
	set five;
	if lastgap>30 then output;
	run;
data test; 
	merge exclude13 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 14 - Exclude last observations' gap>30 when precount>=5;
proc sql; create table fiveagain as select enrolid, lastgap, count(indpre) as precount from all where indpre=1 group by enrolid having 5<=precount<=7; quit;
data exclude14;
	set fiveagain;
	if lastgap>30 then output;
	run;
data test; 
	merge exclude14 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;

* 15 - Exclude 2 or more gaps in post index (include lastgap variable);
proc sql;
create table postlastgap1 as
	select enrolid, indpos, lastgap, gap, gap2, count(gap) as count1
	from all
	where gap>0 and indpos=2
	group by enrolid;
quit;
proc sql;
create table postlastgap2 as
	select enrolid, indpos, lastgap, gap, gap2, count(lastgap) as count2
	from all
	where lastgap>0 and indpos=2
	group by enrolid;
quit;
data exclude15; merge postlastgap1 postlastgap2; by enrolid; retain sum; sum=count1+count2; if sum>1; run;
data test; *** hooray! zero observations;
	merge exclude15 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;

* 16 - Exclude 2 or more gaps in pre index (include lastgap variable);
proc sql;
create table prelastgap1 as
	select enrolid, indpre, lastgap, gap, gap1, count(gap) as count1
	from all
	where gap>0 and indpre=1
	group by enrolid;
quit;
proc sql;
create table prelastgap2 as
	select enrolid, indpre, lastgap, gap, gap1, count(lastgap) as count2
	from all
	where lastgap>0 and indpre=1
	group by enrolid;
quit;
data exclude16; merge prelastgap1 prelastgap2; by enrolid; retain sum; sum=count1+count2; if sum>1; run;
data test; *** hooray! zero observations;
	merge exclude16 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 17 - Exclude last gaps >30;
data exclude17; set all; if lastgap>30 then output; run;
data test; *** hooray! zero observations;
	merge exclude17 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


* 18 - Exclude 2 or more pregaps;
proc sql; create table twopre as select enrolid, pregap, count(pregap) as countpre from all where 0<pregap<30 group by enrolid; quit;
data exclude18; set twopre; if countpre>1; run;
data test; *** hooray! zero observations;
	merge exclude18 (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and b then output;run;


****************************************************************************************** Combine exclusions;
data exclusion;
	merge exclude1-exclude18;
	by enrolid;run;

data include;
	merge exclusion(in=a) all(in=b);
	by enrolid;
if b and not a then output;
proc sort data=include out=prevalence nodupkey; by enrolid; run;

data needremove; * hooray!!!;
	merge prevalence (in=a) wc000001.qc_ss_prev (in=b);
	by enrolid;
if a and not b then output;run;

/*data 'C:\Users\tnguyen\Desktop\RWE\prevalence'; set include2; run;*/


***** Table 2: Overall prevelance and incidence cohort;

data prevalence; set 'C:\Users\tnguyen\Desktop\RWE\prevalence'; run;
data f_combined; set 'C:\Users\tnguyen\Desktop\RWE\f_combined'; run;
data is_combined; set 'C:\Users\tnguyen\Desktop\RWE\is_combined'; run;
data o_combined; set 'C:\Users\tnguyen\Desktop\RWE\o_combined'; run;

proc sort data=prevalence; by enrolid; run;
proc sort data=f_combined; by enrolid; run;
proc sort data=is_combined; by enrolid; run;
proc sort data=o_combined; by enrolid; run;

data allcombined;
	merge f_combined(keep=enrolid tsvcdat dx1-dx9 rename=(dx1=f_dx1 dx2=f_dx2 dx3=f_dx3 dx4=f_dx4))
		  is_combined
		  o_combined(rename=(dx1=o_dx1 dx2=o_dx2 dx3=o_dx3 dx4=o_dx4));
	by enrolid;
if  dx1 = '7102' or substr(dx1,1,4) = 'M350' then dx=dx1;
	else if dx2 = '7102' or substr(dx2,1,4) = 'M350' then dx=dx2;
	else if dx3 = '7102' or substr(dx3,1,4) = 'M350' then dx=dx3;
	else if dx4 = '7102' or substr(dx4,1,4) = 'M350' then dx=dx4;
	else if dx5 = '7102' or substr(dx5,1,4) = 'M350' then dx=dx5;
	else if dx6 = '7102' or substr(dx6,1,4) = 'M350' then dx=dx6;
	else if dx7 = '7102' or substr(dx7,1,4) = 'M350' then dx=dx7;
	else if dx8 = '7102' or substr(dx8,1,4) = 'M350' then dx=dx8;
	else if dx9 = '7102' or substr(dx9,1,4) = 'M350' then dx=dx9;
	else if dx10 = '7102' or substr(dx10,1,4) = 'M350' then dx=dx10;
	else if dx11 = '7102' or substr(dx11,1,4) = 'M350' then dx=dx11;
	else if dx12 = '7102' or substr(dx12,1,4) = 'M350' then dx=dx12;
	else if dx13 = '7102' or substr(dx13,1,4) = 'M350' then dx=dx13;
	else if dx14 = '7102' or substr(dx14,1,4) = 'M350' then dx=dx14;
	else if dx15 = '7102' or substr(dx15,1,4) = 'M350' then dx=dx15;
	else if f_dx1 = '7102' or substr(f_dx1,1,4) = 'M350' then dx=f_dx1;
	else if f_dx2 = '7102' or substr(f_dx2,1,4) = 'M350' then dx=f_dx2;
	else if f_dx3 = '7102' or substr(f_dx3,1,4) = 'M350' then dx=f_dx3;
	else if f_dx4 = '7102' or substr(f_dx4,1,4) = 'M350' then dx=f_dx4;
	else if o_dx1 = '7102' or substr(o_dx1,1,4) = 'M350' then dx=o_dx1;
	else if o_dx2 = '7102' or substr(o_dx2,1,4) = 'M350' then dx=o_dx2;
	else if o_dx3 = '7102' or substr(o_dx3,1,4) = 'M350' then dx=o_dx3;
	else if o_dx4 = '7102' or substr(o_dx4,1,4) = 'M350' then dx=o_dx4;
	else if pdx = '7102' or substr(pdx,1,4) = 'M350' then dx=pdx;
else dx='';
rename svcdate=o_date
	disdate=is_date
	tsvcdat=f_date;
run;

data merged1;
	merge allcombined(in=a keep=enrolid o_date f_date is_date dx sex) prevalence(in=b drop=dtend dtstart); by enrolid; if a and b;
	keep enrolid o_date is_date indexdt preindex f_date dx sex;
*	keep enrolid svcdate age fachdid stdprov sex year admdate disdate caseid dx indexdt memdays source preindex postindex TSVCDAT;
run;

data genderadd;
	merge prevalence(in=a) allcombined(in=b);
	by enrolid;
	if a;
run;
proc sort data=genderadd nodupkey; by enrolid; run;

data check; set merged1; if dx=''; run;
data check; set merged1; if indexdt=.; run;
/*data exca; set merged1; if '01Jan2015'd <=svcdate<= '30Jun2015'd and '01Jan2015'd <=preindex<= '30Jun2015'd then output; run;*/
/*	data exc1; set exca; if indexdt<svcdate<preindex; run;*/
/*data excb; set merged1; if '01Jan2015'd <=dtend<= '30Jun2015'd and '01Jan2015'd <=preindex<= '30Jun2015'd then output; run;*/
/*	data exc2; set excb; if indexdt<dtend<preindex; run;	*/
/*data excc; set merged1; if '01Jan2015'd <=TSVCDAT<= '30Jun2015'd and '01Jan2015'd <=preindex<= '30Jun2015'd then output; run;*/
/*	data exc3; set excc; if indexdt<tsvcdat<preindex; run;*/

data exclude1; set merged1; if o_date^=.;
	data exc1; set exclude1; if '30Dec2014'd<=preindex<=o_date<='30Jun2015'd<indexdt; run;
data exclude2; set merged1; if f_date^=.; 
	data exc2; set exclude2; if '30Dec2014'd<=preindex<=f_date<='30Jun2015'd<indexdt; run;
data exclude3; set merged1; if is_date^=.; 
	data exc3; set exclude3; if '30Dec2014'd<=preindex<=is_date<='30Jun2015'd<indexdt; run;

/*data condition; set merged1; if '01Jan2015'd <=preindex<= '30Jun2015'd ; run;*/
/**/
/*data exc1; set merged1;  if '01Jan2015'd<=svcdate<='30Jun2015'd; if indexdt>svcdate>preindex; run;*/
/*data exc2; set merged1;  if '01Jan2015'd<=disdate<='30Jun2015'd; if indexdt>disdate>preindex; run;*/
/*data exc3; set merged1;  if '01Jan2015'd<=tsvcdat<='30Jun2015'd; if indexdt>tsvcdat>preindex; run;*/

data exclude;
	set exc1-exc3;
	by enrolid;
run;

proc sort data=exclude nodupkey; by enrolid; run;

data incidence;
	merge exclude(in=a) prevalence(in=b);
	by enrolid;
	if b and not a;
keep enrolid age indexdt sex dx year stdprov;
	run;



data testing; set merged1; if enrolid=3098429201; run;

data needadd;
	merge incidence (in=a) wc000001.qc_ss_inc (in=b);
	by enrolid;
if b and not a then output;run;
data needremove;
	merge incidence (in=a) wc000001.qc_ss_inc (in=b);
	by enrolid;
if a and not b then output;run;

data test;
	merge incidence (in=a) wc000001.qc_ss_inc (in=b);
	by enrolid;
if a and b then output;run;

proc compare base=wc000001.qc_ss_inc compare=incidence; run;


data genderadd2;
	merge incidence(in=a) allcombined(in=b);
	by enrolid;
	if a;
run;
proc sort data=genderadd2 nodupkey; by enrolid; run;

/**/
/*proc sort data=allcombined nodupkey; by enrolid; run;*/
/**/
/*data subset;*/
/*	merge include2(in=a) allcombined;*/
/*	by enrolid;*/
/*	if a;*/














* Formatting if needed;
proc format;
	value agefmt
	18-44='Age group: 18-44'
	45-54='Age group: 45-54'
	55-64='Age group: 55-64'
	65-74='Age group: 65-74'
	75-HIGH='Age group: >=75';
	value sexfmt
	1='Male'
	2='Female';
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
%format(prev,prevalence);

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
%prov(prevprov,prevalence);

* Calculate Age n and percent;
proc freq noprint data=inc; table txt1 / out=incfreq; run;
data incid1; length var 8.; set incfreq;
	var= compress(put(count,8.)); run;
data incid; set incid1; var1= put(var,comma6.);
	col2 = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;
proc freq noprint data=prev; table txt1 / out=prevfreq; run;
data preval1; length var 8.; set prevfreq;
	var = compress(put(count,8.)); run;
data preval; set preval1; var1=put(var,comma6.);
	col1 = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;


* Calculate Specialty n and percent;
proc freq noprint data=incprov; table txt1 / out=incprov2; run;
data temp2_; length var 8.; set incprov2;
	var=compress(put(count,8.)); run;
data temp2; set temp2_; var1=put(var,comma6.);
	col2 = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;
proc freq noprint data=prevprov; table txt1 / out=prevprov2; run;
data temp1_; length var 8.; set prevprov2;
	var=compress(put(count,8.)); run;
data temp1; set temp1_; var1 = put(var,comma6.);
	col1 = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;


* Calculate Sex n and percent;
proc freq noprint data=genderadd; table sex / out=temp3; run;
data temp4_; length var 8.; set temp3; if sex=2; var=put(count,8.); run;
data temp4; set temp4_; var1=put(var,comma6.);
	gender = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;
proc freq noprint data=genderadd2; table sex / out=temp6; run;
data temp7_; length var 8.; set temp6; if sex=2; var=put(count,8.); run;
data temp7; set temp7_; var1=put(var,comma6.);
	gender = compress(var1)||' ('||compress(put(percent,10.1))||'%)';
	drop count percent;
	run;

* Calculate age mean median standard deviation min max and n;
proc means noprint data=incidence; var age; output out=inc1 n=_n mean=_mean std=_std median=_median min=_min max=_max; run;
proc means noprint data=prevalence; var age; output out=prev1 n=_n mean=_mean std=_std median=_median min=_min max=_max; run;

%macro stats(new,old);
data &new; length n 8.; set &old;
	mean = compress(put(_mean,10.1))||' ('||compress(put(_std,10.2))||')';
	median = compress(put(_median,10.))||' ('||compress(put(_min,10.))||', '||compress(put(_max,10.))||')';
	n = put(_n,8.);
run;
%mend;

%stats(inc2,inc1);
%stats(prev2,prev1);

data inc2; set inc2; var1=put(n,comma6.);
data prev2; set prev2; var1=put(n,comma6.);run;

data inc3; set inc2; var=compress(var1)||' (100%)';
data prev3; set prev2; var=compress(var1)||' (100%)';run;



* Transpose frequency datasets to vertical;
proc transpose data=inc3 out=inc3_; var mean median var; run;
proc transpose data=prev3 out=prev3_; var mean median var; run;
proc transpose data=temp7 out=temp8; var gender; run;
proc transpose data=temp4 out=temp5; var gender; run;

* Sort data;
proc sort data=prev3_; by _NAME_; run;
proc sort data=inc3_(rename=(col1=col2)); by _NAME_; run;

* Rename columns to txt1, col1 or col2;
data temp5; set temp5; rename _NAME_=txt1 col2=col1;  run;
data temp8; set temp8; rename _NAME_=txt1 col1=col2; run;
data inc3a; set inc3_;  rename _NAME_=txt1; run;
data prev3a; set prev3_; rename _NAME_=txt1; run;

	
* Extract year from index date;
* Prevalence ;
data year1; set prevalence; yr = year(indexdt); run;
proc freq noprint data=year1; table yr / out=temp9; run;
	data temp9_; set temp9; retain var; var = put(count,comma6.); run;
data temp10; set temp9_; col1 = compress(var)||' ('||compress(put(percent,10.1))||'%)'; txt1=input(yr,$50.); keep txt1 col1; run;
* Incidence ;
data year2; set incidence; yr = year(indexdt); run;
proc freq noprint data=year2; table yr / out=temp11; run;
	data temp11_; set temp11; retain var; var = put(count,comma6.); run;
data temp12; set temp11_; col2 = compress(var)||' ('||compress(put(percent,10.1))||'%)'; txt1=input(yr,$50.); keep txt1 col2;run;

* Combine or merge all datasets;
data combined; length txt1 $50.;
	merge inc3a prev3a incid preval temp1 temp2 temp5 temp8 temp10 temp12; by txt1; run;
* Assign number for sorting data for table;
data demographics; set combined;
	if txt1='gender' then do; txt1='Female n (%)'; sort=1; end;
	if txt1='var' then do; txt1= "Sjögren's syndrome diagnosis by year, n (%)"; sort=9; end; 
	if txt1='median' then do; txt1= 'Median age years at index date (range)'; sort=3; end;
	if txt1='mean' then do; txt1= 'Mean age years at index date (standard deviation)'; sort=2; end;
	if txt1 = 'Age range: 18-44 years, n (%)' then sort=4;
	if txt1 = 'Age range: 45-54 years, n (%)' then sort=5;
	if txt1 = 'Age range: 55-64 years, n (%)' then sort=6;
	if txt1 = 'Age range: 65-74 years, n (%)' then sort=7;
	if txt1='Age range: >=75 years, n (%)' then sort=8;
	if txt1= '2015' then sort=10; 	if txt1= '2016' then sort=11; 	if txt1= '2017' then sort=12; 	if txt1= '2018' then sort=13; 	if txt1= '2019' then sort=14;
	if txt1= 'Physician specialty: Internal Medicine, n (%)' then sort=15;
	if txt1= 'Physician specialty: Family Practice, n (%)' then sort=16;
	if txt1= 'Physician specialty: Ophthalmology, n (%)' then sort=17;
	if txt1= 'Physician specialty: Rheumatology, n (%)' then sort=18;
	if txt1= 'Physician specialty: Others, n (%)' then sort=19;
	if txt1= 'Physician specialty: Unknown, n (%)' then sort=20;
	drop var var1;
run;
* Sort data by sorting variable;
proc sort data=demographics; by sort; run;






* Prevalence:;
* Number of SS patients in the study period divided by total number of individuals in the MarketScan database for the study period and reported as patients per 100,000;
* Prevalence rate:;
* Overall and stratified by sex and age categories;
* For age specific rates, the denominator will be the total number of adults in each of the age groups to get age-specific prevalence rate;
* For gender specific rate, the denominator will be the total number of adults in each gender male or female to get gender-specific prevalence rate;
data population; set 'C:\Users\tnguyen\Desktop\RWE\population'; run;

proc sql; 

		select count(sex) into: n1 from genderadd; 
		select count(sex) into: n2 from genderadd2;
		select count(enrolid) into: n3 from prevalence;
		select count(enrolid) into: n4 from incidence; 
		select count(sex) into: n5 from genderadd where sex='1';
		select count(sex) into: n6 from genderadd2 where sex='1';
		select count(sex) into: n7 from genderadd where sex='2';
		select count(sex) into: n8 from genderadd2 where sex='2';
		select count(age) into: n9 from prevalence where 18<=age<=44;
		select count(age) into: n10 from prevalence where 45<=age<=54;
		select count(age) into: n11 from prevalence where 55<=age<=64;
		select count(age) into: n12 from prevalence where 65<=age<=74;
		select count(age) into: n13 from prevalence where 75<=age;
		select count(age) into: n14 from incidence where 18<=age<=44;
		select count(age) into: n15 from incidence where 45<=age<=54;
		select count(age) into: n16 from incidence where 55<=age<=64;
		select count(age) into: n17 from incidence where 65<=age<=74;
		select count(age) into: n18 from incidence where 75<=age;

		select count(enrolid) into: n0 from population;
		select count(sex) into: n19 from population where sex='1';
		select count(sex) into: n20 from population where sex='2';
		select count(age) into: n21 from population where 18<=age<=44;
		select count(age) into: n22 from population where 45<=age<=54;
		select count(age) into: n23 from population where 55<=age<=64;
		select count(age) into: n24 from population where 65<=age<=74;
		select count(age) into: n25 from population where 75<=age;

quit;

%put &n25.;


data all; txt1='All'; prev= compress(put(round((&n1./&n0.)*100000,0.01),10.1)); inc= compress(put(round((&n2./(&n0.-&n2.))*100000,0.01),10.1)); sort=2;run;
data n0; length prev0 inc0 8. ;txt1='N'; prev0= put(&n3.,10.); inc0= put(&n4.,10.); sort=1; run;
	data n; set n0; prev=put(prev0,comma6.); inc=put(inc0,comma6.); drop prev0 inc0; run;

data female; txt1='Gender: Female';prev=compress(put((&n7./&n20.)*100000,10.1)); inc=compress(put((&n8./(&n20.-&n8.))*100000,10.1)); sort=3;run;
data male; txt1='Gender: Male';prev=compress(put((&n5./&n19.)*100000,10.1)); inc=compress(put((&n6./(&n19.-&n6.))*100000,10.1)); sort=4;run;
data eighteen; txt1='Age group: 18-44';prev=compress(put((&n9./&n21.)*100000,10.1)); inc=compress(put((&n14./(&n21.-&n14.))*100000,10.1)); sort=5;run;
data fortyfive; txt1='Age group: 45-54';prev=compress(put((&n10./&n22.)*100000,10.1)); inc=compress(put((&n15./(&n22.-&n15.))*100000,10.1)); sort=6;run;
data fiftyfive; txt1='Age group: 55-64';prev=compress(put((&n11./&n23.)*100000,10.1)); inc=compress(put((&n16./(&n23.-&n16.))*100000,10.1)); sort=7;run;
data sixtyfive; txt1='Age group: 65-74';prev=compress(put((&n12./&n24.)*100000,10.1)); inc=compress(put((&n17./(&n24.-&n17.))*100000,10.1)); sort=8;run;
data seventyfive; txt1='Age group: >=75';prev=compress(put((&n13./&n25.)*100000,10.1)); inc=compress(put((&n18./(&n25.-&n18.))*100000,10.1)); sort=9; run;

data overallrates; length txt1 $50.; set n all female male eighteen fortyfive fiftyfive sixtyfive seventyfive; by txt1; run;

proc sort data=overallrates; by sort; run;






ods excel
	file="C:\Users\tnguyen\Desktop\RWE\final.xlsx";
ods excel options( sheet_name = 'Demographics' );

proc report data=demographics;
	column txt1  col1  col2 ;
	define txt1 / display "METRIC";
	define col1 / display "SS Prevalent Cohort";
	define col2 / display "SS Incident Cohort";
run;

ods excel 
	options( sheet_name='OverallRates' );

proc report data=overallrates;
	column txt1  prev  inc ;
	define txt1 / display "METRIC";
	define prev / display "SS Prevalent Cohort";
	define inc / display "SS Incident Cohort";
run;

ods excel close;



