/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_tgt_upd_val_recalc.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		
2020-04-21		Vyna				VC-200421			Add handling if there are no Updates on target table
2020-04-23		Vyna				VC-200423			Updated Sorting
2020-05-03		Vyna				VC-200503			Changed the passing for values per indv_key
2020-06-09		Vyna				VC-200609			Updated the passing for values per indv_key
2020-11-19		Vyna				VC-201119			Change to datetime format
**************************************************************************************************/


%macro upd_val_recalc(tgt);

	proc sort data=&_INPUT out=COMBINED; by indv_key valid_frm_dt; run;

	proc sql noprint; 
		select nvar - 5 into :num_vars
		from dictionary.tables
		where libname="TGT" and memname="&tgt" ;
		select distinct(name) into :first_vars separated by ', ' 
		from dictionary.columns
		where libname="TGT" and memname="&tgt" and name in ("INDV_KEY", "DATA_LOAD_DT", "DATA_SRC_CD", "VALID_FRM_DT", "VALID_TO_DT");
		select distinct(name) into :second_vars separated by ', ' 
		from dictionary.columns
		where libname="TGT" and memname="&tgt" and name not in ("INDV_KEY", "DATA_LOAD_DT", "DATA_SRC_CD", "VALID_FRM_DT", "VALID_TO_DT");
	quit;
	run;

	%put &num_vars;

	proc sql;
	create table arrange_cols as
	select 
		&first_vars,
		&second_vars
	from 
		combined
	order by
		INDV_KEY, VALID_FRM_DT;
	quit;

	proc sql noprint; 
		select distinct(name) into :var1-:var%trim(%left(&num_vars))
		from dictionary.columns
		where libname="WORK" and memname="ARRANGE_COLS" and name not in ("INDV_KEY", "DATA_LOAD_DT", "DATA_SRC_CD", "VALID_FRM_DT", "VALID_TO_DT");
	quit;

	%put &num_vars;

/* START: VC-200503 */

	proc sort data = ARRANGE_COLS; by INDV_KEY  VALID_FRM_DT; run;

	proc sql noprint;
		select count(*) into :obschk
		from ARRANGE_COLS;
	quit;

	data null_upd_vals;
		set ARRANGE_COLS;
		keep indv_key DATA_LOAD_DT DATA_SRC_CD VALID_FRM_DT VALID_TO_DT; 
	run;

	proc sort data = ARRANGE_COLS;  by INDV_KEY  VALID_FRM_DT; run;
	proc sort data = null_upd_vals; by INDV_KEY  VALID_FRM_DT; run;

  %do i = 1 %to &num_vars;
/* VC-200609: start */
/*	proc sql;
	create table checks as
	select distinct
		indv_key,  
		case when VALID_FRM_DT = min(VALID_FRM_DT) and &&var&i is not null then &&var&i end as chk_&&var&i,
		min(VALID_FRM_DT) format datetime22.3 as chk_VALID_FRM_DT	
	from
		ARRANGE_COLS
	
	where
		&&var&i is not null 
	group by
		INDV_KEY
	having
		min(VALID_FRM_DT) and &&var&i is not null and chk_&&var&i is not null; 

	create table upd_vals&i as
	select distinct
		a.indv_key, 
		case when a.VALID_FRM_DT >= b.chk_VALID_FRM_DT and a.&&var&i is null then b.chk_&&var&i else a.&&var&i end as &&var&i.,
		a.DATA_LOAD_DT, 
		a.DATA_SRC_CD, 
		a.VALID_FRM_DT, 
		a.VALID_TO_DT
	from
		ARRANGE_COLS a
	left join 
		checks b
	on 
		a.indv_key=b.indv_key
	group by
		a.INDV_KEY 
	order by
		a.INDV_KEY, a.VALID_FRM_DT;
	quit; */ 

	data upd_vals&i;
	set ARRANGE_COLS(keep=indv_key &&var&i VALID_FRM_DT rename=(&&var&i=_&&var&i));
		by indv_key;
		retain &&var&i;
		if first.indv_key then &&var&i=_&&var&i;
		if not missing(_&&var&i) then &&var&i=_&&var&i;
		drop _&&var&i;
	run;

/* VC-200609: end */

	data null_upd_vals;
		merge null_upd_vals(in=a) upd_vals&i(in=b);
		by indv_key VALID_FRM_DT;
		if a and b;
	run;

  %end;
 
	proc sort data = null_upd_vals; by INDV_KEY VALID_FRM_DT; run;

%if obschk > 0 %then %do;
/* END: VC-200503 */
	data &_OUTPUT;                                             
		merge null_upd_vals(rename=(VALID_TO_DT=ori_valid_to_dt)) null_upd_vals(firstobs=2 keep=indv_key valid_frm_dt         
		               rename=(indv_key=indv_key2 valid_frm_dt=new_valid_to_dt ));  
		if indv_key ne indv_key2 then new_valid_to_dt= .;                           

		if new_valid_to_dt = . then VALID_TO_DT = ori_valid_to_dt;
		else VALID_TO_DT = new_valid_to_dt;

/* VC-201119: start */
/*		format VALID_TO_DT date9.;  

		drop indv_key2 new_valid_to_dt ori_valid_to_dt; 

		if VALID_TO_DT = . then VALID_TO_DT = '01JAN5999'd; */

		format VALID_TO_DT datetime22.3;  

		drop indv_key2 new_valid_to_dt ori_valid_to_dt; 

		if VALID_TO_DT = . then VALID_TO_DT = '01JAN5999 00:00:000.00'dt;
		else if VALID_TO_DT ^= . and VALID_TO_DT ^= '01JAN5999 00:00:000.00'dt then VALID_TO_DT = intnx('second', VALID_TO_DT, -1); 

/* VC-201119: end */

	run; 

%end;
%else  %do;

	data &_OUTPUT;
	   set TGT.&tgt;
	   if _N_ < 1;
	stop;	
	run;

%end;

%mend; 