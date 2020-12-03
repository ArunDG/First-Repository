
/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_tgt_vald_to_recalc.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%global col_nms;

%macro vald_to_recalc(tgt);

	/* Get existing INDV_KEYS with OPEN valid_to_dt from TGT.TB_D_INDV_NM */
	PROC SQL;
		create table OPEN_RECS as
		select 
			a.*
		from TGT.&tgt a
		where VALID_TO_DT="01Jan5999"d OR VALID_TO_DT gt today()+1;


	/* Get matching INDV_KEYS from OPEN_RECS - FOR CLOSING V2DATE*/
		create table NOUPDATE as
		select 
			a.*
		from OPEN_RECS a
		where indv_key in (select INDV_KEY from &_INPUT. where (&criteria1.))
		order by indv_key, valid_to_dt;


	/* Get matching INDV_KEYS from OPEN_RECS - FOR CLOSING V2DATE*/
		create table PREV_RECS as
		select 
			a.*
		from OPEN_RECS a
		where indv_key in (select INDV_KEY from &_INPUT. where (&criteria.))
		and VALID_FRM_DT IS NOT NULL 
		order by indv_key, valid_frm_dt, valid_to_dt;


   	/* Get matching INDV_KEYS from OPEN_RECS WITH UPDATE */
		create table UPDATES as
		select 
			a.*
		from &_INPUT. a
		where indv_key in (select INDV_KEY from OPEN_RECS where (&criteria.))
		and VALID_FRM_DT IS NOT NULL 
		order by indv_key, valid_frm_dt, valid_to_dt;


	/* Get INDV_KEYS FOR NEW RECORDS */
		create table NEW_RECS as
		select 
			a.*
		from &_INPUT. a
		where indv_key ^in (select INDV_KEY from TGT.&tgt.)
		AND VALID_FRM_DT IS NOT NULL ;
	QUIT;

	proc sql noprint;
		select count(indv_key) into :opn_cnt from OPEN_RECS;
		select count(indv_key) into :nupd_cnt from NOUPDATE;
		select distinct indv_key into :nupd_rows separated by "," from NOUPDATE;
		
		select count(indv_key) into :old_cnt from PREV_RECS;
		select distinct indv_key into :old_rows separated by "," from PREV_RECS;
		select count(indv_key) into :seminew_cnt from UPDATES;
		select distinct indv_key into :seminew_rows separated by "," from UPDATES;
		select count(indv_key) into :new_cnt from NEW_RECS;	
		select distinct indv_key into :new_rows separated by "," from NEW_RECS;	
	quit;

	%PUT >>> &OPN_CNT. RECORDS WITH OPEN VALID_TO_DT.;  
	%PUT >>> &NUPD_CNT. RECORDS (&nupd_rows.) WITH NO UPDATES REQUIRED.;  
	%PUT >>> &OLD_CNT. RECORDS (&old_rows.) EXISTING IN TARGET TABLE: &TGT..;  
    %PUT >>> &SEMINEW_CNT. RECORDS (&seminew_rows.) DUE FOR UPDATE...;  
	%PUT >>> &NEW_CNT. NEW RECORDS (&new_rows.) TO INSERT.;
	
	proc sql;
		create table &_OUTPUT. like TGT.&tgt.;
	quit;

	%if &seminew_cnt. > 0 %then %do;

	/* Retrieve existing records linked to Indv_keys from TGT.TB_D_INDV_NM */
	/* With an Assumption that there can only be 1 indv_key with valid_to_dt="01Jan5999"d */
		data LAST_REC;
		set PREV_RECS;
		by indv_key VALID_TO_DT;
		if last.indv_key and last.VALID_TO_DT;
		run;

		proc sql noprint; 
		select nvar into :num_vars from dictionary.tables
			where libname="WORK" and memname="LAST_REC";

		select distinct(name) into :var1-:var%trim(%left(&num_vars)) from dictionary.columns
			where libname="WORK" and memname="LAST_REC";
		quit;
		%put &num_vars;

		%macro t;
		proc datasets library = WORK;
		modify LAST_REC;
		rename
			%do i = 1 %to &num_vars;
				&&var&i = CURR_&&var&i.
			%end;
		;
		quit; run; 
		%mend t; %t
		%upds_w_values(&tgt);
		%put --> &tgt;

		%put ---> col_nms is &col_nms;

		%let col_nms_ = &col_nms;

	/* Supply remaining cols for semi-new recs */
		proc sql;
		create table UPDTS_W_CURR as
		select
			a.INDV_KEY,
			&col_nms_.
			a.DATA_LOAD_DT,
			a.VALID_FRM_DT,
			a.VALID_TO_DT,
			'1' as tag
		from UPDATES a
		left join LAST_REC b
			on (a.indv_key=b.CURR_INDV_KEY);
		quit;
		proc sort data=UPDTS_W_CURR; by indv_key valid_frm_dt tag; run;

		data prev_w_curr;
		merge  PREV_RECS UPDTS_W_CURR;
		by indv_key valid_frm_dt;
		run;
		proc sort data=PREV_W_CURR; by indv_key valid_frm_dt tag; run;   

		/* ReCalculate VALID_TO_DT to MAX for each Indv_Keys with latest valid_frm_dt */
		data OLD_w_UPDATE;
		merge prev_w_curr(rename=(VALID_TO_DT=ori_valid_to_dt)) prev_w_curr(firstobs=2 keep=indv_key valid_frm_dt         
		                        rename=(indv_key=indv_key2 valid_frm_dt=new_valid_to_dt));  
		if indv_key ne indv_key2 then new_valid_to_dt=.;                           

		if new_valid_to_dt =. then valid_to_dt = ori_valid_to_dt;
		else VALID_TO_DT = new_valid_to_dt;

		format VALID_TO_DT date9.;  

		drop indv_key2 new_valid_to_dt ori_valid_to_dt; 
		run; 

		/* Append to Final Table */
		proc append base=&_Output. data=OLD_w_UPDATE (drop=tag); run;

	%end;
	%if &new_cnt. > 0 %then %do;

		/* Append to Final Table */
		proc append base=&_Output. data=NEW_RECS; run;

	%end;
%mend vald_to_recalc;
