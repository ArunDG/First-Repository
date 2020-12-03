%let EXCLdate=%sysfunc(putn(%sysfunc(date()),yymmddn8));
%put &EXCLdate.;

%MACRO EXCLUDE_LEDM;
/*PHASE 1 - BUILDING EXCLUSION LIST */
%IF %SYSFUNC(INDEX(&ETLS_JOBNAME.,DRV_MRTL_STS)) GT 0 %THEN %DO;
	/*Build Permanent Exclusion List if does not exist for subsequent DRV_MRTL_STS jobs*/
	%IF %SYSFUNC(EXIST(EXCLLEDM.EXCL_LEDM_&EXCLDATE.)) = 0 %THEN %DO;
		proc sql noprint;
		create table EXCLLEDM.EXCL_LEDM_&EXCLdate.
			(
			PROF_REF_NO		num 			label='Profile Reference Number' ,	
		  	INDV_KEY		num				label='Individual Key',
			EVENT_DT		num				label='Event Date' Format=date9. informat=date9.,
			EVENT_TYPE		varchar(50)		label='Event Type',
			EXCP_RSN_CD		varchar(50)		label='Exception Reason Code',
			EVENT_TYPE_ID	varchar(50)		label='Event Certificate Number ID',
			EXCP_COL		varchar(32)		label='Exception Column'
		   	);
		quit;
	%END;

	/*Begin Building Exclusion List from Exception Records - Rejected from Loading into CANVAS*/
	proc sql;
	create table Build_EXCL as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		. AS EVENT_DT,
		"" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		"" AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	where (BIRTH_DT = . AND MARR_DT = . AND DVRCE_DT = . AND ANNULMT_DT = . 
			AND REVCTN_DT = . AND INDV_DEATH_DT = . AND SPS_DEATH_DT = .)
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_BIRTH as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.BIRTH_DT AS EVENT_DT,
		"BIRTH" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		COALESCE(B.NRIC_ID,B.FIN_ID) AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	left join TGT.TB_D_INDV_IDNTY B
		on (a.INDV_KEY=b.INDV_KEY)
	where A.BIRTH_DT NE . 
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_MARR as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.MARR_DT AS EVENT_DT,
		"MARRIAGE" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		B.MARR_CERT_NBR_ID AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	left join TGT.TB_F_MARR B
		on (a.MARR_KEY=b.MARR_KEY and A.MARR_DT=B.MARR_DT)
	where A.MARR_DT NE . 
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_DVRCE as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.DVRCE_DT AS EVENT_DT,
		"DIVORCE" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		B.DVRCE_CERT_NBR_ID AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	left join TGT.TB_F_DVRCE B
		on (a.DVRCE_KEY=b.DVRCE_KEY AND A.DVRCE_DT=B.DVRCE_DT)
	where A.DVRCE_DT NE .
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_ANNULMT as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.ANNULMT_DT AS EVENT_DT,
		"ANNULMENT" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		B.ANNULMT_CERT_NBR_ID AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	left join TGT.TB_F_ANNULMT B
		on (a.ANNULMT_KEY=b.ANNULMT_KEY AND A.ANNULMT_DT=B.ANNULMT_DT)
	where A.ANNULMT_DT NE .
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_REVCTN as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.REVCTN_DT AS EVENT_DT,
		"REVOCATION" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		B.REVCTN_CERT_NBR_ID AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	left join TGT.TB_F_REVCTN B
		on (a.DVRCE_KEY=b.DVRCE_KEY AND A.REVCTN_DT=B.REVCTN_DT)
	where A.REVCTN_DT NE .
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_DEATH_IDNV as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.INDV_DEATH_DT AS EVENT_DT,
		"DEATH OF INDIV" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		A.INDV_DEATH_CERT_NBR_ID AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	where A.INDV_DEATH_DT NE .
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);

	create table Build_DEATH_SPOUSE as 
	select distinct
		A.INDV_KEY,
		A.PROF_REF_NO,
		A.SPS_DEATH_DT AS EVENT_DT,
		"DEATH OF SPOUSE" AS EVENT_TYPE FORMAT=$50. INFORMAT=$50. LENGTH=50,
		A.EXCP_TYP AS EXCP_RSN_CD,
		A.EXCP_COL,
		A.SPS_DEATH_CERT_NBR_ID AS EVENT_TYPE_ID FORMAT=$50. INFORMAT=$50. LENGTH=50
	FROM EXCL_DRV_MRTL_STS A
	where A.SPS_DEATH_DT NE . AND A.INDV_DEATH_DT NE SPS_DEATH_DT
	AND upcase(A.EXCP_TYP) in ("EXCEPTION_8","EXCEPTION_9","EXCEPTION_10","EXCEPTION_35","EXCEPTION_36"
	);
	quit;

	/*Combine Events Tables*/
	data EVENT_EXCL;
	set Build_BIRTH Build_MARR Build_DVRCE Build_ANNULMT Build_REVCTN Build_DEATH_IDNV Build_DEATH_SPOUSE BUILD_EXCL;
	if upcase(EXCP_COL) = "MARR_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_8","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE) = "MARRIAGE" then output;
	if upcase(EXCP_COL) = "DVRCE_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_9","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE) = "DIVORCE" then output;
	if upcase(EXCP_COL) = "ANNULMT_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_9","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE) = "ANNULMENT" then output;
	if upcase(EXCP_COL) = "REVCTN_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_10","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE) = "REVOCATION" then output;
	run;

	proc sort data=EVENT_EXCL nodupkey; by PROF_REF_NO INDV_KEY EVENT_DT EVENT_TYPE EXCP_RSN_CD EXCP_COL EVENT_TYPE_ID; run;

	proc sql noprint;
	select count(EXCP_RSN_CD) into: EXCL_EXCP_DRV from EVENT_EXCL;
	quit;
	%put &EXCL_EXCP_DRV.;

	%if &EXCL_EXCP_DRV gt 0 %then %do;
		/*Append Combined Event Table to Exclusion List*/
		proc append base=EXCLLEDM.EXCL_LEDM_&EXCLdate. data=EVENT_EXCL FORCE;
		run; 
	%end;
%END;

/*PHASE 2 - REMOVAL OF RECS BEFORE LOADING INTO DM LIFE EVENTS */
%IF %SYSFUNC(INDEX(&ETLS_JOBNAME.,TB_DM_FSR_LIFE_EVENTS)) GT 0 %THEN %DO;

	proc sql noprint;
	select count(distinct INDV_KEY) into: EXCL_RECS from EXCLLEDM.EXCL_LEDM_&EXCLdate.;
	quit;
	%put &EXCL_RECS.;

	%if &EXCL_RECS gt 0 %then %do;
		proc sort data=EXCLLEDM.EXCL_LEDM_&EXCLdate. out=EXCL_LEDM_&EXCLdate. nodupkey; by PROF_REF_NO INDV_KEY EVENT_DT EVENT_TYPE EXCP_RSN_CD EXCP_COL EVENT_TYPE_ID; run;

		proc sql noprint;
		select compress(val) into :salt_val
		from TGT.SALT_VAL;
		quit;

		data EXCL_LEDM_MSK_&EXCLdate.;
		set EXCL_LEDM_&EXCLdate.;
		if PROF_REF_NO ne . then MATCH_PRN=put(sha256(cats(substr(compress(put(PROF_REF_NO, best.)), 1, 2), "&salt_val.",substr(compress(put(PROF_REF_NO, best.)),3,length(compress(put(PROF_REF_NO, best.)))-2))), $hex64.);
		if INDV_KEY ne . then MATCH_NDV=put(sha256(cats(substr(compress(put(INDV_KEY, best.)), 1, 2), "&salt_val.",substr(compress(put(INDV_KEY, best.)),3,length(compress(put(INDV_KEY, best.)))-2))), $hex64.);
		run;

		proc sql;
		create table Check_DMLE_&EXCLdate. as
		select 
			A.INDV_KEY as INDV_KEY_LEDM,
			A.PROF_REF_NO as PROF_REF_NO_LEDM,
			A.EVENT_DT AS EVENT_DT_LEDM,
			A.EVENT_TYPE_TX AS EVENT_TYPE_LEDM,
			A.EVENT_CERT_NBR_ID as EVENT_ID_LEDM,

			B.INDV_KEY as INDV_KEY_EXCL,
			B.PROF_REF_NO as PROF_REF_NO_EXCL,
			B.EVENT_DT AS EVENT_DT_EXCL,
			B.EVENT_TYPE AS EVENT_TYPE_EXCL,
			B.EVENT_TYPE_ID as EVENT_ID_EXCL,

			B.EXCP_RSN_CD,
			B.EXCP_COL

			FROM &_INPUT. A
			INNER JOIN EXCL_LEDM_MSK_&EXCLdate. B
				ON (upcase(A.PROF_REF_NO)=upcase(b.MATCH_PRN) 
				AND upcase(A.INDV_KEY)=upcase(b.MATCH_NDV) 
				AND upcase(A.EVENT_TYPE_TX)=upcase(B.EVENT_TYPE))
			;
		QUIT;

		data EXCLLEDM.EXCLUDE_DMLE_&EXCLdate.;
		Format PROF_REF_NO $64. INDV_KEY $64. Event_DT date9.;
		set Check_DMLE_&EXCLdate.;
		PROF_REF_NO=PROF_REF_NO_LEDM;
		INDV_KEY=INDV_KEY_LEDM;
		EVENT_TYPE_TX=EVENT_TYPE_LEDM;
		EVENT_DT=EVENT_DT_LEDM;
		EVENT_CERT_NBR_ID=EVENT_ID_LEDM;

		if upcase(EXCP_COL) = "MARR_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_8","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE_LEDM) = "MARRIAGE" AND EVENT_DT_LEDM ^= . then do;
/*			IF EVENT_ID_LEDM = EVENT_ID_EXCL AND EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;*/
			IF EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;
		end;
		if upcase(EXCP_COL) = "DVRCE_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_9","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE_LEDM) = "DIVORCE" AND EVENT_DT_LEDM ^= . then do;
/*			IF EVENT_ID_LEDM = EVENT_ID_EXCL AND EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;*/
			IF EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;
		end;
		if upcase(EXCP_COL) = "ANNULMT_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_9","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE_LEDM) = "ANNULMENT" AND EVENT_DT_LEDM ^= . then do;
/*			IF EVENT_ID_LEDM = EVENT_ID_EXCL AND EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;*/
			IF EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;
		end;
		if upcase(EXCP_COL) = "REVCTN_DT" AND upcase(EXCP_RSN_CD) in ("EXCEPTION_10","EXCEPTION_35","EXCEPTION_36") AND upcase(EVENT_TYPE_LEDM) = "REVOCATION" AND EVENT_DT_LEDM ^= . then do;
/*			IF EVENT_ID_LEDM = EVENT_ID_EXCL AND EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;*/
			IF EVENT_DT_EXCL=EVENT_DT_LEDM THEN output;
		end;
		KEEP PROF_REF_NO INDV_KEY EVENT_DT EVENT_TYPE_TX EVENT_CERT_NBR_ID EXCP_RSN_CD;
		run;

		proc sql noprint;
		select count(distinct INDV_KEY) into: EXCL_RECS2 from EXCLLEDM.EXCLUDE_DMLE_&EXCLdate.;
		quit;
		%put &EXCL_RECS2.;

		%if &EXCL_RECS2 gt 0 %then %do;

			proc sort data=&_input. out=pre_exclusion; by PROF_REF_NO INDV_KEY EVENT_DT EVENT_TYPE_TX EVENT_CERT_NBR_ID ; run;
			proc sort data=EXCLLEDM.EXCLUDE_DMLE_&EXCLdate. out=EXCLUDE_DMLE; by PROF_REF_NO INDV_KEY EVENT_DT EVENT_TYPE_TX EVENT_CERT_NBR_ID ; run;

			data &_OUTPUT.;
			merge pre_exclusion (in=a) EXCLUDE_DMLE (in=b);
			by PROF_REF_NO INDV_KEY EVENT_DT EVENT_TYPE_TX EVENT_CERT_NBR_ID;
			if a=1 and b=0;
			run;

		%end;
		%else %do;
			%put "Nothing Matched to exlcude from Loading into DM LIFE EVENTS.";

			proc sql;
			create table &_OUTPUT. as
			select 
				A.*
			from &_INPUT. A;
			quit;

		%end;
	%end;
	%else %do;
		%put "Nothing to exlcude from Loading into DM LIFE EVENTS.";

		proc sql;
		create table &_OUTPUT. as
		select 
			A.*
		from &_INPUT. A;
		quit;

	%end;
%END;

%MEND EXCLUDE_LEDM;
%EXCLUDE_LEDM;
