/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_reckey_generate.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

options mprint symbolgen mlogic;


%macro Generate_Rec_Key(src, dsn);
/* To Generate CANVAS_REC_KEY */

	/* Retrieve start CANVAS REC KEY */
	proc sql noprint;
		select max(CANVAS_REC_KEY) format=12.
		into: RecKeyStart
		from ADMIN.CANVAS_RECKEY_MASTER where Source = "&src";
	quit;

	%if &RecKeyStart = . %then %do;
		proc sql noprint;
			select RecKeyBase format=12.
			into: RecKeyStart
			from ADMIN.CANVAS_RECKEY_START where SourceName = "&src";
		quit;
	%end;	

	%put RecKeyStart is &RecKeyStart;

	/* Retrieve SRC (STG filename) */

		/* Generate CANVAS Rec Key */

		%DATA_LOAD_DT_PARM;

		data &dsn.;
/*		set  STG.&dsn();*/
		set work.&dsn;
			format DATA_LOAD_DT datetime22.;
			retain CANVAS_REC_KEY_ &RecKeyStart;				
			CANVAS_REC_KEY_ + 1;

			CANVAS_REC_KEY=CANVAS_REC_KEY_;

			drop CANVAS_REC_KEY_;

			DATA_LOAD_DT = &DATA_LOAD_DT_PARM;
		run;

/*		proc sql;*/
/*	    	delete from STG.&dsn ; */
/*		quit;*/
/**/
/*		proc append base = STG.&dsn data= &dsn; run;*/

		/* Generating Rec_no per record */
		data EVENT_TBL_INIT;
/*		set stg.&dsn;*/
		set &dsn.;
			format SOURCE $5. FILENAME $200.;
			SOURCE = "&src";
			retain REC_NO;
			REC_NO + 1;

			keep CANVAS_REC_KEY SOURCE REC_NO FILENAME DATA_LOAD_DT;
		run;

		proc append base = ADMIN.CANVAS_RECKEY_MASTER data=EVENT_TBL_INIT force; run;


%mend;
