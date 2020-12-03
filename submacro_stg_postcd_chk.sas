/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_postcd_chk.sas

PROGRAM DESCRIPTION: Checks Postal code column  has Post code format.


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%Macro POST_CHK();

	data dataevalid;
	set Dist_Attrib_list;
	where fileid="&fileid" and upcase(validcheck)="POST" ;
	run;

	proc sql noprint;
			select count(*) into :PSTOT 
			from dataevalid;
	quit;
			
	%put &PSTOT;

	%if &PSTOT>0 %then %do;


	%put &Excptbl;
	%put &fileid;

	data _null_;
	set dataevalid end=last;
	call symput("var"||left(trim(_n_)),field);
	call symput("expchkfile",target);
	call symput("file_expt"||left(trim(_n_)),left(trim(Name_Key)));
	call symput("isrej"||left(trim(_n_)),is_rej);
	if last=1 then call symput("totcol",_n_);
	run;
	%put &totcol;

	%do k=1 %to &totcol; 
			data  prestag.&expchkfile;
			set prestag.&expchkfile;
	        if input(&&var&k,best.) and length(compress(&&var&k,' ','kd'))=6 then cnt=0;
	        else cnt=1;
			rej_sts=sum(rej_sts,cnt*&&isrej&k);
		    exp_cnt=sum(exp_cnt,cnt);
			run;
               
                    %let dat=%sysfunc(datetime(),datetime23.);

			data &&file_expt&k (DROP=cnt exp_cnt);
			length DESCRIPTION $50;
			set prestag.&expchkfile ;
			if cnt>0;
			DESCRIPTION="Invalid &&var&k";
                        DATA_LOAD_DT=DATETIME();
                        /**** AR 08Jul2020 added exception column ****/
                        JOB_RUN_ID="&JOB_RUN_ID.";
                        EXCP_ID=cats("&srcnm","&dat"dt+_n_);
                        EXCP_TYP='ROW';
                        ROW_NO=_n_;
                        EXCP_COL="&&var&k";
                       JOB_STRT_DT="&JOB_START_FMT."dt;
                      /**** AR 08Jul2020 added exception column ****/

                        FORMAT DATA_LOAD_DT DATETIME22. JOB_STRT_DT DATETIME22.;
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
	%else %put There is no field to validate Postal Code;
%Mend;

