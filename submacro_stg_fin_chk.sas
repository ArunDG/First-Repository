/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_fin_chk.sas

PROGRAM DESCRIPTION: Checks UIN has correct format for FIN.


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%Macro FIN_CHK();

	data dataevalid;
	set Dist_Attrib_list;
	where fileid="&fileid" and (ValidCheck="FIN" OR ValidCheck1="FIN") ;
	run;

	proc sql noprint;
			select count(*) into :FINTOT 
			from dataevalid;
	quit;
			
	%put &FINTOT;

	%if &FINTOT>0 %then %do;

		%put &Excptbl;
		%put &fileid;

		data dataevalid;
		set dataevalid;
		f=scan(Validcheck_filter1,1," ");
		g=scan(Validcheck_filter1,2," ");
		h=scan(Validcheck_filter1,3," ");
		Validcheck_filter2=left(trim(f))||" "||"NOT"||" "||left(trim(g))||" "||left(trim(h));
		run;

		data _null_;
		set dataevalid end=last;
		call symput("var"||left(trim(_n_)),field);
		call symput("expchkfile",target);
		call symput("file_expt"||left(trim(_n_)),left(trim(Name_Key)));
		call symput("isrej"||left(trim(_n_)),is_rej);
		call symput("NRICCheck"||left(trim(_n_)),left(trim(ValidCheck)));
		call symput("FINCheck"||left(trim(_n_)),left(trim(ValidCheck1)));
		call symput ("basefilchk"||left(trim(_n_)),"and"||" "||left(trim(Validcheck_filter1)));
		call symput ("addfiltchk"||left(trim(_n_)),"else"||" "||"if"||" "||left(trim(Validcheck_filter2))||" "||"then"||" "||"cnt=0");
		if last=1 then call symput("totcol",_n_);
		run;

		%put &totcol;
		%put &basefilchk1;
		%put &addfiltchk1;
                %put &NRICCheck1;
                %put &NRICCheck2;
                %put &NRICCheck3;
                %put &NRICCheck4;
                %put &FINCheck1;
                %put &FINCheck2;
                %put &FINCheck3;
                %put &FINCheck4;
   




			%do k=1 %to &totcol; 
					data  prestag.&expchkfile (DROP=C E D P);
					set prestag.&expchkfile;
					if upcase(substr(&&var&k,1,1))="F"  and length(compress(&&var&k,' ','kd'))=7 then do;
						c=compress(&&var&k,' ','kd');
						d=((input(substr(c,1,1),best12.)*2)+(input(substr(c,2,1),best12.)*7)+(input(substr(c,3,1),best12.)*6)
						  +(input(substr(c,4,1),best12.)*5)+(input(substr(c,5,1),best12.)*4)+(input(substr(c,6,1),best12.)*3)
						  +(input(substr(c,7,1),best12.)*2));
					    E=11-MOD(D,11);
					end;

					else if  upcase(substr(&&var&k,1,1))="G" and length(compress(&&var&k,' ','kd'))=7 then do;
						c=compress(&&var&k,' ','kd');
						d=((input(substr(c,1,1),best12.)*2)+(input(substr(c,2,1),best12.)*7)+(input(substr(c,3,1),best12.)*6)
						  +(input(substr(c,4,1),best12.)*5)+(input(substr(c,5,1),best12.)*4)+(input(substr(c,6,1),best12.)*3)
						  +(input(substr(c,7,1),best12.)*2))+4;
						E=11-MOD(D,11);
					end;
					else DO;
						d=.;
						E=11-MOD(D,11);
					END;

					If E=1         then P="K";
					ELSE IF  E=2   then p="L"; 
					ELSE IF  E=3   then p="M"; 
					ELSE IF  E=4   then p="N"; 
					ELSE IF  E=5   then p="P"; 
					ELSE IF  E=6   then p="Q"; 
					ELSE IF  E=7   then p="R"; 
					ELSE IF  E=8   then p="T"; 
					ELSE IF  E=9   then p="U"; 
					ELSE IF  E=10  then p="W";
					ELSE IF  E=11  then p="X";
					ELSE P=" ";

			%IF  &&NRICCheck&k=NRIC AND &&FINCheck&k=FIN %THEN %DO;

					IF (upcase(substr(&&var&k,1,1))="F" OR  upcase(substr(&&var&k,1,1))="G") and length(compress(&&var&k,' ','kd'))=7 and upcase(substr(&&var&k,length(&&var&k),1))=P &&basefilchk&k then cnt=0;
			        &&addfiltchk&k;
			        else cnt=1;
				    rej_sts=sum(rej_sts,cnt*&&isrej&k);
				    exp_cnt=sum(exp_cnt,cnt);
					run;
			%END;

			%ELSE %IF  &&NRICCheck&k=FIN AND &&FINCheck&k=OTHERID %THEN %DO;

					IF  (upcase(substr(&&var&k,1,1))="F" OR  upcase(substr(&&var&k,1,1))="G") and length(compress(&&var&k,' ','kd'))=7 and upcase(substr(&&var&k,length(&&var&k),1))=P &&basefilchk&k then cnt=0;
			        &&addfiltchk&k;
			        else cnt=1;
				    rej_sts=sum(rej_sts,cnt*&&isrej&k);
				    exp_cnt=sum(exp_cnt,cnt);
					run;
			%END;

			%ELSE %IF  &&NRICCheck&k=FIN AND &&FINCheck&k=Missing %THEN %DO;

					IF  (upcase(substr(&&var&k,1,1))="F" OR  upcase(substr(&&var&k,1,1))="G") and length(compress(&&var&k,' ','kd'))=7 and upcase(substr(&&var&k,length(&&var&k),1))=P then cnt=0;
					else if &&var&k=" " then cnt=0; 
			        else cnt=1;
				    rej_sts=sum(rej_sts,cnt*&&isrej&k);
				    exp_cnt=sum(exp_cnt,cnt);
					run;
			%END;

			%ELSE %DO;
					IF  (upcase(substr(&&var&k,1,1))="F" OR  upcase(substr(&&var&k,1,1))="G") and length(compress(&&var&k,' ','kd'))=7 and upcase(substr(&&var&k,length(&&var&k),1))=P then cnt=0;
			        else cnt=1;
				    rej_sts=sum(rej_sts,cnt*&&isrej&k);
				    exp_cnt=sum(exp_cnt,cnt);
					run;
			%END;

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
                         EXCP_RSN_CD="Exception_6";
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

			%end;
		%end;
	%end;
	%else %put There is no field to validate for FIN;

%Mend;
