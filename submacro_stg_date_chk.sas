/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_date_chk.sas

PROGRAM DESCRIPTION: Checks date correct format for data type = date.


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%macro DateValid();

data dataevalid;
set Dist_Attrib_list;
where fileid="&FILEID" and validcheck="Date" ;
run;

proc sql noprint;
select count(*) into :DTTOT 
from dataevalid;
quit;

%put &DTTOT;

%if &DTTOT>0 %then %do;

	data _null_;
	set dataevalid end=last;
	call symput("var"||left(trim(_n_)),field);
	call symput("format"||left(trim(_n_)),left(trim(informat)));
	call symput("expchkfile",target);
	call symput("file_expt"||left(trim(_n_)),left(trim(Name_Key)));
	call symput("basedate",left(trim(basedate)));
	call symput("isrej"||left(trim(_n_)),is_rej);
	/*MC06MAY2020: ADDED VALIDCHECK1 FOR DTM TRIGGER*/
	call symput("DTM"||left(trim(_n_)),upcase(ValidCheck1));
	call symput("format1"||left(trim(_n_)),left(trim(format)));
	if last=1 then call symput("totcol",_n_);
	run;

	%put &totcol;
	%put &basedate;
	%put &DTM1.;

	%do k=1 %to &totcol; 
		data prestag.&expchkfile;
		set prestag.&expchkfile;
		/*MC06MAY2020: ADDED DTM TRIGGER*/
		%if &&DTM&k = DTM %then %do;
			/*MC25MAY2020: ADDED MIN ACCEPT YEAR=1582*/
			if (input(&&var&k,&&format1&k) or input(&&var&k,&&format1&k)=0)  and input(&&var&k,&&format&k)<datetime() and substr(&&var&k,8,4) ge 1582 then cnt=0;
			else cnt=1; 
		%end;
		%else %do;
		/*MC25MAY2020: ADDED MIN ACCEPT YEAR=1582 and handling for date value format: DDMMYYYY*/
		/*MC29MAY2020: ADDED Compress and Upcase Functions*/
			%if %sysfunc(upcase(%sysfunc(compress(&&format&k)))) = DDMMYY8. %then %do;
				if (input(&&var&k,&&format&k) or input(&&var&k,&&format&k)=0)  and input(&&var&k,&&format&k)<today() and substr(&&var&k,5,4) ge 1582 then cnt=0;
				else cnt=1;
			%end;
			%else %do;
				if (input(&&var&k,&&format&k) or input(&&var&k,&&format&k)=0)  and input(&&var&k,&&format&k)<today() and substr(&&var&k,1,4) ge 1582 then cnt=0;
				else cnt=1;
			%end;
		%end;

		rej_sts=sum(rej_sts,cnt*&&isrej&k);
		exp_cnt=sum(exp_cnt,cnt);
		run;

                %let dat=%sysfunc(datetime(),datetime23.);

		data &&file_expt&k(DROP=cnt exp_cnt  RSN_CD);
		length DESCRIPTION $50;
		set prestag.&expchkfile ;
		if cnt>0;
		DESCRIPTION="Invalid &&var&k";
		DATA_LOAD_DT=DATETIME();

            /**** AR 08Jul2020 added exception column ****/
                RSN_CD=&&isrej&k;
                JOB_RUN_ID="&JOB_RUN_ID.";
                EXCP_ID=cats("&srcnm","&dat"dt+_n_);
                EXCP_TYP='ROW';
                ROW_NO=_n_;
                if  RSN_CD=1 then EXCP_RSN_CD="Exception_8";
                else EXCP_RSN_CD=" ";
                EXCP_COL="&&var&k";
                JOB_STRT_DT="&JOB_START_FMT."dt;
            /**** AR 08Jul2020 added exception column ****/

		FORMAT DATA_LOAD_DT DATETIME22.  JOB_STRT_DT DATETIME22.;
		drop FILE_LOAD_DT;
		run;


		proc sql noprint;
		select count(*) into :totexp 
		from &&file_expt&k;
		quit;

		%put &totexp;

		%if &totexp>0 %then %do;

		proc append base=EXCP.&Excptbl data=&&file_expt&k force;
		run;
		/*
		proc sort data=EXCP.&Excptbl nodupkey;
		by _all_;
		run;*/
		%end;
	%end;
%end;
%else %put There is no field to validate for Date;
%mend;
/*%DateValid();*/
