%MACRO CH_UPDATE(PRV_REC=,OUT=);

/**** Get the records which has diff mother or father *****/

PROC SQL;
	CREATE TABLE Update_Rec_&OUT as
	SELECT DISTINCT A.INDV_FRM_KEY,A.INDV_TO_KEY FROM &_INPUT AS A 
	INNER JOIN 
		(SELECT INDV_FRM_KEY, INDV_TO_KEY, RLTN_CD
		 FROM TGT.TB_D_RELTN
		 WHERE VALID_TO_DT = '01JAN5999'd) AS B
	ON
	A.INDV_FRM_KEY=B.INDV_FRM_KEY AND
	A.INDV_TO_KEY NE B.INDV_TO_KEY  AND
	A.RLTN_CD=B.RLTN_CD;
QUIT;

/**** Get the records which has same mother or father *****/

PROC SQL;
	CREATE TABLE Same_Rec_&OUT as 
	SELECT DISTINCT A.INDV_FRM_KEY,A.INDV_TO_KEY FROM &_INPUT AS A 
	INNER JOIN 
		(SELECT INDV_FRM_KEY, INDV_TO_KEY, RLTN_CD
		 FROM TGT.TB_D_RELTN
		 WHERE VALID_TO_DT = '01JAN5999'd) AS B
	ON
	A.INDV_FRM_KEY=B.INDV_FRM_KEY AND
	A.INDV_TO_KEY = B.INDV_TO_KEY  AND
	A.RLTN_CD=B.RLTN_CD;
QUIT;

/****** Get count of children who has same or diff father or mother *******/

proc sql noprint;
		select count(*) into :no_recs
		from Update_Rec_&OUT;
quit;
       
proc sql noprint;
		select count(*) into :no_recs1
		from Same_Rec_&OUT;
quit;



/*****  Get the Ind keys into macro variable******/

%if &no_recs1 > 0 %then %do;

	proc sql noprint;
			select distinct INDV_FRM_KEY,INDV_TO_KEY into :INDV_FRM_KEY_LST_SM separated by ",",
			                                              :INDV_TO_KEY_LST_SM separated by ","
			from Same_Rec_&OUT;
	quit;
%end;

 %if &no_recs > 0 %then %do;

proc sql noprint;
		select distinct INDV_FRM_KEY,INDV_TO_KEY into :INDV_FRM_KEY_LST separated by ",",
		                                              :INDV_TO_KEY_LST  separated by ","
		from Update_Rec_&OUT;
quit;



	DATA NEW_&OUT DIFFERENT_&OUT SAME_&OUT;
		SET &_INPUT;
		LENGTH TAG $8;	
		IF INDV_FRM_KEY IN (&INDV_FRM_KEY_LST) AND INDV_TO_KEY IN (&INDV_TO_KEY_LST) THEN DO;
		TAG="DIFF";
		OUTPUT DIFFERENT_&OUT;
		END;
%if &no_recs1 > 0 %then %do;

		ELSE IF INDV_FRM_KEY IN (&INDV_FRM_KEY_LST_SM) AND INDV_TO_KEY IN (&INDV_TO_KEY_LST_SM) THEN DO;
		TAG="SAME";
		OUTPUT SAME_&OUT;
		END;

%END;
		ELSE DO;
		TAG="NEW";
		OUTPUT NEW_&OUT;
		END;
	RUN;

/*** Extratc Prev rec from RELTN  table****/

	PROC SQL;
		CREATE TABLE &PRV_REC AS
		SELECT A.*,"UPDT" AS  TAG FROM TGT.TB_D_RELTN AS A
		INNER JOIN  DIFFERENT_&OUT AS B
		ON
		A.INDV_FRM_KEY=B.INDV_FRM_KEY AND
		A.INDV_TO_KEY NE B.INDV_TO_KEY  AND
		A.RLTN_CD=B.RLTN_CD
		WHERE A.VALID_TO_DT='01JAN5999'D;
	QUIT;

/* Re-Calculate Valid to date for all the record ***/

	proc sort data=DIFFERENT_&OUT;
		by INDV_FRM_KEY;
	run;

	PROC SORT DATA=&PRV_REC;
		BY INDV_FRM_KEY;
	RUN;

	DATA PREV_REC_&OUT (DROP=NEW_VALID_FRM_DT ORI_VALID_TO_DT);
		MERGE &PRV_REC (rename=(VALID_TO_DT=ORI_VALID_TO_DT)in=a) DIFFERENT_&OUT(KEEP=INDV_FRM_KEY VALID_FRM_DT RENAME=(VALID_FRM_DT=NEW_VALID_FRM_DT)in=b);
		BY INDV_FRM_KEY;
        if a=1 and b=1;
		IF VALID_FRM_DT>NEW_VALID_FRM_DT THEN VALID_TO_DT=ORI_VALID_TO_DT;
		ELSE VALID_TO_DT=NEW_VALID_FRM_DT;
		FORMAT VALID_TO_DT DATE9.;
	RUN;


	DATA DIFFERENT1_&OUT (DROP=NEW_VALID_FRM_DT ORI_VALID_TO_DT);
		MERGE DIFFERENT_&OUT (rename=(VALID_TO_DT=ORI_VALID_TO_DT)in=a) &PRV_REC (KEEP=INDV_FRM_KEY VALID_FRM_DT RENAME=(VALID_FRM_DT=NEW_VALID_FRM_DT)in=b) ;
		BY INDV_FRM_KEY;
      if a=1 and b=1;
		IF VALID_FRM_DT>NEW_VALID_FRM_DT THEN VALID_TO_DT=ORI_VALID_TO_DT;
		ELSE VALID_TO_DT=NEW_VALID_FRM_DT;
		FORMAT VALID_TO_DT DATE9.;
	RUN;


	DATA &_Output;
		SET NEW_&OUT DIFFERENT1_&OUT PREV_REC_&OUT;
	RUN;
%END;

%ELSE %DO;

%if &no_recs1 > 0 %then %do;

	Data SAME_&OUT NEW_&OUT;
	    SET &_INPUT;
	    LENGTH TAG $8;	
		IF INDV_FRM_KEY IN (&INDV_FRM_KEY_LST_SM) AND INDV_TO_KEY IN (&INDV_TO_KEY_LST_SM) THEN DO;
			TAG="SAME";
			OUTPUT SAME_&OUT;
		END;

		ELSE DO;
			TAG="NEW";
	      	RLTN_KEY=.;
			OUTPUT NEW_&OUT;
		END;
	RUN;

	DATA &_Output;
		SET NEW_&OUT;
	RUN;
%END;

%ELSE %DO;
   DATA &_Output;
	   SET &_INPUT;
	   LENGTH TAG $8;
	   TAG="NEW";
      RLTN_KEY=.;
   RUN;
%END;
%END;
%MEND;



