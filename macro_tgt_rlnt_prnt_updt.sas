%MACRO PRNT_UPDATE(RL=,RLCD=,PRV_REC=);

/**** Get the records which has diff mother or father *****/

	PROC SQL;
		CREATE TABLE Update_Rec_&RL as
		SELECT DISTINCT A.INDV_FRM_KEY,A.INDV_TO_KEY FROM &_INPUT AS A 
		INNER JOIN 
			(SELECT INDV_FRM_KEY, INDV_TO_KEY, RLTN_CD
		 	FROM TGT.TB_D_RELTN
		 	WHERE VALID_TO_DT = '01JAN5999'd) AS B
		ON
		A.INDV_FRM_KEY NE B.INDV_FRM_KEY AND
		A.INDV_TO_KEY = B.INDV_TO_KEY  AND
		A.RLTN_CD=B.RLTN_CD;
	QUIT;

/**** Get the records which has same mother or father *****/

	PROC SQL;
		CREATE TABLE Same_Rec_&RL as 
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
			from Update_Rec_&RL;
	quit;
       
	 proc sql noprint;
			select count(*) into :no_recs1
			from Same_Rec_&RL;
	quit;
/*****  Get the Ind keys into macro variable******/

%if &no_recs1 > 0 %then %do;

	proc sql noprint;
			select distinct INDV_FRM_KEY,INDV_TO_KEY into :INDV_FRM_KEY_LST_SM separated by ",",
			                                              :INDV_TO_KEY_LST_SM separated by ","
			from Same_Rec_&RL;
	quit;
%end;

%if &no_recs > 0 %then %do;

	proc sql noprint;
			select distinct INDV_FRM_KEY,INDV_TO_KEY into :INDV_FRM_KEY_LST separated by ",",
			                                              :INDV_TO_KEY_LST  separated by ","
			from Update_Rec_&RL;
	QUIT;


	DATA NEW_&RL DIFFERENT_&RL SAME_&RL;
		SET &_INPUT;
		LENGTH TAG $8;
		IF INDV_FRM_KEY IN (&INDV_FRM_KEY_LST) AND INDV_TO_KEY IN (&INDV_TO_KEY_LST) THEN DO;
		TAG="DIFF";
		OUTPUT DIFFERENT_&RL;
		END;
%if &no_recs1 > 0 %then %do;

		ELSE IF INDV_FRM_KEY IN (&INDV_FRM_KEY_LST_SM) AND INDV_TO_KEY IN (&INDV_TO_KEY_LST_SM) THEN DO;
		TAG="SAME";
		OUTPUT SAME_&RL;
		END;

%END;
		ELSE DO;
		TAG="NEW";
		OUTPUT NEW_&RL;
		END;
	RUN;

/***** Extract previouse record ******/

	PROC SQL;
		CREATE TABLE PREV_REC_&RL AS
		SELECT A.*, "UPDT" AS  TAG FROM TGT.TB_D_RELTN AS A
		INNER JOIN  &PRV_REC AS B
		ON
		A.INDV_TO_KEY=B.INDV_FRM_KEY AND
		A.INDV_FRM_KEY = B.INDV_TO_KEY 
		WHERE A.VALID_TO_DT='01JAN5999'D AND B.RLTN_CD="&RLCD";
	QUIT;


/* Re-Calculate Valid to date for all the record ***/

	proc sort data=DIFFERENT_&RL;
		by INDV_TO_KEY;
	run;

	PROC SORT DATA=PREV_REC_&RL;
		BY INDV_TO_KEY;
	RUN;

	DATA PREV_REC1_&RL (DROP=NEW_VALID_FRM_DT ORI_VALID_TO_DT);
		MERGE PREV_REC_&RL (rename=(VALID_TO_DT=ORI_VALID_TO_DT)in=a) DIFFERENT_&RL(KEEP=INDV_TO_KEY VALID_FRM_DT RENAME=(VALID_FRM_DT=NEW_VALID_FRM_DT)in=b);
		BY INDV_TO_KEY;
      if a=1 and b=1;
		IF VALID_FRM_DT>NEW_VALID_FRM_DT THEN VALID_TO_DT=ORI_VALID_TO_DT;
		ELSE VALID_TO_DT=NEW_VALID_FRM_DT;
		FORMAT VALID_TO_DT DATE9.;
	RUN;


	DATA DIFFERENT1_&RL (DROP=NEW_VALID_FRM_DT ORI_VALID_TO_DT);
		MERGE DIFFERENT_&RL (rename=(VALID_TO_DT=ORI_VALID_TO_DT)) PREV_REC_&RL (KEEP=INDV_TO_KEY VALID_FRM_DT RENAME=(VALID_FRM_DT=NEW_VALID_FRM_DT)) ;
		BY INDV_TO_KEY;
		IF VALID_FRM_DT>NEW_VALID_FRM_DT THEN VALID_TO_DT=ORI_VALID_TO_DT;
		ELSE VALID_TO_DT=NEW_VALID_FRM_DT;
		FORMAT VALID_TO_DT DATE9.;
	RUN;


	DATA &_Output;
		SET NEW_&RL DIFFERENT1_&RL PREV_REC1_&RL;
	RUN;

%END;

%ELSE %DO;

%if &no_recs1 > 0 %then %do;

	Data SAME_&RL NEW_&RL;
	    SET &_INPUT;
	    LENGTH TAG $8;
		IF INDV_FRM_KEY IN (&INDV_FRM_KEY_LST_SM) AND INDV_TO_KEY IN (&INDV_TO_KEY_LST_SM) THEN DO;
			TAG="SAME";
			OUTPUT SAME_&RL;
		END;
		ELSE DO;
			TAG="NEW";
      		RLTN_KEY=.;
			OUTPUT NEW_&RL;
      	END;
	RUN;

	DATA &_Output;
		SET NEW_&RL;
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
