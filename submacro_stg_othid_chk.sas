/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_othid_chk.sas

PROGRAM DESCRIPTION: Checks Other ID have valid format.


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%Macro OTHID_CHK();

	data othidevalid;
		set Dist_Attrib_list;
		where fileid="&fileid" and (ValidCheck="PASSPORT" OR ValidCheck1="PASSPORT" OR ValidCheck2="PASSPORT") ;
	run;

	proc sql noprint;
		select count(*) into :FINTOT 
		from othidevalid;
	quit;
		
	%put &FINTOT;

	%if &FINTOT>0 %then %do;

		%put &Excptbl;
		%put &fileid;

		/*data othidevalid;
		set othidevalid;
			f=scan(Validcheck_filter1,1," ");
			g=scan(Validcheck_filter1,2," ");
			h=scan(Validcheck_filter1,3," ");
			Validcheck_filter2=left(trim(f))||" "||"NOT"||" "||left(trim(g))||" "||left(trim(h));
		run;*/

		data _null_;
		set othidevalid end=last;
		call symput("var"||left(trim(_n_)),field);
		call symput("expchkfile",target);
		call symput("file_expt"||left(trim(_n_)),left(trim(Name_Key)));
		call symput("isrej"||left(trim(_n_)),is_rej);
		call symput("PP1Check"||left(trim(_n_)),left(trim(ValidCheck)));
		call symput("PP2Check"||left(trim(_n_)),left(trim(ValidCheck1)));
		call symput("PP3Check"||left(trim(_n_)),left(trim(ValidCheck2)));
		call symput("basefilchk"||left(trim(_n_)),"and"||" "||left(trim(Validcheck_filter)));
		call symput("addfiltchk"||left(trim(_n_)),"else"||" "||"if"||" "||left(trim(Validcheck_filter2))||" "||"then"||" "||"cnt=0");

		if last=1 then call symput("totcol",_n_);
		run;

		%put &totcol;
		%put &basefilchk1;
		%put &addfiltchk1;

		%do k=1 %to &totcol; 
			
			data _null_;
			set othidevalid;
			if field = "&&var&k";

			     if ValidCheck = "PASSPORT" then call symput("basefilchk&k.", left(trim(Validcheck_filter)));
			else if ValidCheck1 = "PASSPORT" then call symput("basefilchk&k.", left(trim(Validcheck_filter1)));
			else if ValidCheck2 = "PASSPORT" then call symput("basefilchk&k.", left(trim(Validcheck_filter2)));

			run;

			data  prestag.&expchkfile;
				set prestag.&expchkfile;
			    if &&basefilchk&k. then do;
					if compress(&&var&k, '123456789', 'k')*1 ge 1 then cnt=0;
					else cnt = 1;
				end;
				rej_sts = sum(rej_sts,cnt*&&isrej&k);
				exp_cnt = sum(exp_cnt,cnt);
				run;

                         %let dat=%sysfunc(datetime(),datetime23.);

			data &&file_expt&k (DROP=cnt exp_cnt);
				length DESCRIPTION $50;
				set prestag.&expchkfile ;
				if cnt>0;
					DESCRIPTION  = "Invalid &&var&k";
			        DATA_LOAD_DT = DATETIME();

                                /**** AR 08Jul2020 added exception column ****/
                               JOB_RUN_ID="&JOB_RUN_ID.";
                               EXCP_ID=cats("&srcnm","&dat"dt+_n_);
                               EXCP_TYP='ROW';
                               ROW_NO=_n_;
                               EXCP_COL="&&var&k";
                               JOB_STRT_DT="&JOB_START_FMT."dt;
                               EXCP_RSN_CD="Exception_6";
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
			%end;

		%end;

	%end;
	%else %put There is no field to validate for OTHER ID;

%Mend;
