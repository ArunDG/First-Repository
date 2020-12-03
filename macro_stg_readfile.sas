/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_readfile.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
2020-01-15			ARUN			AP-200115			Added FILE_LOAD_DT
2020-01-29   		VYNA			VC-200129			Added OTHER ID validation 
2020-03-03			JONATHAN			JL-200303			Added PARENT UIN Check
2020-03-04			WINSON			WA-200304			Added MAND Check for Code Tables
2020-03-19			WINSON			WA-200319			Added Checks for first column with length=1
2020-04-17			MICHAEL			MV-200417			Uncomment NRIC and FIN checks for Delimited=FIXED
2020-04-20			ARUN			AP-200420			Commented parent UIN checks checks for Delimited=FIXED
2020-05-05			MELISSA			MR-200505			Added Data Cleansing
2020-08-13			YEE SENG			YS-200813			Ensure STG_ADMIN_LOG displays correct logs for Job_stat_typ = 3

**************************************************************************************************/

%macro Readfile;

	data _null_;
		set FileID_list end=eof;
		call symput("SourceName"||left(trim(_N_)),left(trim(FileID)));
		if eof=1  then call symput("max",_n_);
	run;

	%put &max;

	%do i=1 %to &max;

	/* Filter each interface file for processing*/
		data Parm_tbl;
			set Full_parm_tbl;
		    WHERE fileid="&&SourceName&i";
			ColPos_ = input(colpos, 3.);
			drop ColPos;
			rename ColPos_  = ColPos;
		run;

		%put &i &&SourceName&i;

		/* Get distinct list of files to process*/


		proc sql;
	      %if &srcnm = FJC %then %do;
			create table Txt_Filelist as 
			select distinct path,name 
			from Parm_tbl
			where Extension = '.txt';

			create table Cnt_Filelist as 
			select distinct path,name 
			from Parm_tbl
			where Extension = '.cnt';
	     %end;
		 %else %do;
		 	create table Filelist as 
			select distinct path,name 
			from Parm_tbl;
		 %end;
		quit;


	  %if &srcnm = FJC %then %do;
		proc sql noprint;
			select count(*) into :detchk
			from TXT_Filelist;
		quit;

		%put &detchk;
		/* AP-200115 */
		%if &detchk > 0 %then %do;
			data _null_;
			    set TXT_Filelist end=eof;
                DATE1=SCAN(SCAN(NAME,-1,"_"),1,".");
                FILE_LOAD_DT = INPUT(DATE1,YYMMDD8.);		
			    call symput("filename"||left(trim(_N_)),left(trim(path)));
				call symput("name"||left(trim(_N_)),left(trim(name)));
				call symput ("FILE_LOAD_DT"||LEFT(TRIM(_N_)),FILE_LOAD_DT);
			    if eof=1  then call symput("totfile",_n_);
				FORMAT DATE2 DATE9. TIME2 TIME8. FILE_LOAD_DT date9.;
			run;
		%end;
		%else %do;
			data _null_;
			    set parm_tbl end=eof;
			    call symput("filename"||left(trim(_N_)),left(trim(filename)));
				call symput("name"||left(trim(_N_)),left(trim(filename)));
			    call symput("totfile",0);
			run;			
		%end;

		%put &&cntname&i;
		
		proc sql noprint;
			select count(*) into :cntchk
			from CNT_Filelist;
			quit;

		%put &cntchk;
		%if &cntchk > 0 %then %do;
			data _null_;
			    set CNT_Filelist end=eof;
				call symput("cntname"||left(trim(_N_)),left(trim(path))); 
			run;
		%end;
		%else %do;
			data _null_;
			call symput("cntname"||left(trim(&i))," ");
			run;			
		%end;

		%put &cntname1; /*VC-200319: Original is &&cntname&i*/
	  %end;
	  %else %do;
		data _null_;
		    set Filelist end=eof;
			%if &srcnm = ICA %then %do;
				DATE1=SCAN(SCAN(NAME,-1,"_"),1,".");
	            FILE_LOAD_DT = INPUT(DATE1,YYMMDD8.);
				CALL SYMPUT ("FILE_LOAD_DT"||LEFT(TRIM(_N_)),FILE_LOAD_DT);
				FORMAT DATE2 DATE9. TIME2 TIME8. FILE_LOAD_DT date9.;
			%END;
            %ELSE %DO;
				TIME1=SCAN(SCAN(NAME,-1,"_"),1,".");
	            DATE1=SCAN(NAME,-2,"_");
	            FILE_LOAD_DT = INPUT(DATE1,YYMMDD8.);
				CALL SYMPUT ("FILE_LOAD_DT"||LEFT(TRIM(_N_)),FILE_LOAD_DT);
				FORMAT DATE2 DATE9. TIME2 TIME8. FILE_LOAD_DT date9.;
			%END;
		  	call symput("filename"||left(trim(_N_)),left(trim(path)));
			call symput("name"||left(trim(_N_)),left(trim(name)));
		    if eof=1  then call symput("totfile",_n_);
		run;
	  %end;

		%put &filename1; /*VC-200319: Original is %put &&filename&i;*/
		%put &name1 ;
		%put &totfile;
	
		/* Store source file name, location, delimiter in macro variable*/
		  data _null_;
		    set Parm_tbl;
		    if _n_=1 then do;
				call symput("delim",     left(trim(Delimiter)));
		    	call symput("target",    target);
				call symput("STG_Table", STG_Table);
		    	call symput("source",    left(trim(FileLocation))||left(trim(Filename)));
				call symput("Filetype",  FileType);
			end;
		  run;

		%put &delim;
		%put &target;
		%put &source;
		%put &Filetype;
		%put &STG_Table;


	/* TRUNCATE STAGING TABLE */
		proc sql;
			delete from stg.&STG_Table;
		quit; 
		
	/****************** Read  file and load into SAS Data set ***********************/

	/* keep column name and type and length in macro variable for passing infile statement*/

		Proc sort data=Parm_tbl out=Dist_Attrib_list nodupkey;
			by field;
		run;
		Proc sort data=Dist_Attrib_list ;
			by sourceid fileid name RecordType colpos;
		run;

		/*VC-200319 Start*/
		%global Col1 Col1_Len;

		proc sql noprint;
			select Field, Length into :Col1, :Col1_Len 
				from DIST_ATTRIB_LIST
				where COLPOS=1 and RecordType='D';
		quit;

		%put &Col1;
		%put &Col1_Len;

		data DIST_ATTRIB_LIST;
			set DIST_ATTRIB_LIST;
			if ColPos=1 and length=1 then do;
				length=2;
				Format = "$CHAR2.";
				Informat="$CHAR2.";
			end;
		run;
		/*VC-200132 End*/ 

		data _null_;
		set Dist_Attrib_list;
			call symput("fileid",  Fileid);
			call symput("Excptbl", left(trim("EXCP_"))||left(trim(Target)));
		run;

		%put &Excptbl;


			proc sql noprint;
			select 
			%if &filetype = Delimiter %then %do;
			    case when recordtype="D" then  left(trim(field)) ||" "|| left(trim("$"))
				    else ' ' end,
			    case when recordtype="D" then left(trim(field)) ||" "|| left(trim("$"))||" "||left(trim(length))
				   else ' ' end,
			    case when recordtype="D"  then left(trim(field))
					else ' ' end,
	            case when recordtype="T" then  left(trim(field)) ||" "|| left(trim("$"))
			   		else ' ' end,
	         	case when recordtype="T" then left(trim(field)) ||" "|| left(trim("$"))||" "||left(trim(length))
			   		else ' ' end,
	         	case when recordtype="T"  then left(trim(field))
			  		else ' ' end
			    into :Inputfield separated by " ",
			         :Inputlength separated by " ",
			         :Keepcol separated by " ", 
				     :InputTrlfield separated by " ",
			         :InputTrllength separated by " ",
			         :KeepTrlcol separated by " " 
			%end;
			%else %if &filetype=Fixed %then %do;
				 case when recordtype="D" then  left(trim(field)) ||" "|| left(trim("$"))||" "||trim(colstart)||left(trim("-"))||left(trim(colend))
					else ' ' end,
				 case when recordtype="D" then left(trim(field)) ||" "|| left(trim("$"))||" "||left(trim(length))
				   else ' ' end,
				 case when recordtype="D"  then left(trim(field))
				  else ' ' end,
				 case when recordtype="T" then  left(trim(field)) ||" "|| left(trim("$"))||" "||trim(colstart)||left(trim("-"))||left(trim(colend))
				   else ' ' end,
				 case when recordtype="T" then left(trim(field)) ||" "|| left(trim("$"))||" "||left(trim(length))
				   else ' ' end,
				 case when recordtype="T"  then left(trim(field))
				  else ' ' end
			  into :Inputfield separated by " ",
				   :Inputlength separated by " ",
				   :Keepcol separated by " ", 
				   :InputTrlfield separated by " ",
				   :InputTrllength separated by " ",
				   :KeepTrlcol separated by " " 
			%end;
			    from Dist_Attrib_list;
			 quit;

			%PUT &Keepcol;
			%put &InputTrlfield;

			data _null_;
			set Dist_Attrib_list;
				 if  colpos=1 and recordtype="D" then call symput("DetColTrans",left(trim(field)));
				 if  colpos=1 and recordtype="T" then call symput("TrColTrans", left(trim(field)));
			run;

			%PUT &DetColTrans;
			%PUT &TrColTrans;			 
			%put &KeepCol;

			%do j=1 %to &totfile;
				%if %sysfunc(fileexist(&&filename&j)) %then %do;
					/* Read file each and load into pre-staging library*/


				  %if &srcnm = FJC %then %do;
					DATA prestag.&target(keep=&KeepCol filename FILE_LOAD_DT);
 			    		length &Inputlength &InputTrllength;
						INFILE "&&filename&j" firstobs=1  truncover  end=last;
						input @ ;

			            FILENAME     = "&&name&j";
						FILE_LOAD_DT = &&FILE_LOAD_DT&j;
                        FORMAT FILE_LOAD_DT date9.;

						INPUT  &Inputfield ;
						output  prestag.&target;
						hash_cnt+1;

						call symput ("hash_cnt", hash_cnt);
					run;

				  %if &cntchk > 0 %then %do;
					DATA control_table&j(keep= filename &KeepTrlcol hash_cnt ) ;
						INFILE "&&cntname&j" firstobs=1  truncover  end=last;
						input @ ;
			            FILENAME     = "&&name&j";
						hash_cnt     = &hash_cnt;
						input &InputTrlfield;
					RUN;
				  %end;
				  %else %do;
					DATA control_table&j ;
			            FILENAME     = "&&name&j";
						hash_cnt     = &hash_cnt;
					RUN;		
				  %end;

					proc sql noprint;
						select count(*) into :ctlchk
						from control_table&j;
					quit;

					%put &ctlchk;

					%if &ctlchk = 0 %then %do;
						DATA control_table&j(keep= filename &KeepTrlcol hash_cnt ) ;
				            FILENAME     = "&&name&j";
							hash_cnt     = &hash_cnt;
							TRAIL_CNT	 = .;
							CREATED_DTTM = .;
						RUN;						
					%end;

				  %end;
				  %else %do;   
					DATA prestag.&target(keep=&KeepCol filename FILE_LOAD_DT) 
					  %if &filetype = Delimiter %then %do;
					    %if &SrcNm = BBO %then %do;
						control_table&j(keep= filename &KeepTrlcol hash_cnt ) ;
						%end;
                                            %ELSE %if &SrcNm = ROM OR &SrcNm = ROMM OR &SrcNm = MSR  %then %do;
                                                control_table&j(keep= filename &KeepTrlcol hash_cnt ) ;
						%end;
					    %else %do;
						control_table&j(keep= filename SRC_NAME &KeepTrlcol hash_cnt ) ;
						%end;
					    length FILENAME $200. &Inputlength &InputTrllength ;
					    INFILE "&&filename&j" firstobs=2 %if &SrcNm = ROM OR &SrcNm = ROMM OR &SrcNm = MSR %then %do; ENCODING="LATIN1" %end; 
						 /*TERMSTR=CRLF*/ DLM="&delim" DSD MISSOVER end=last;
					  %end;
					  %else %if &filetype = Fixed %then %do;
					  	control_table&j(keep=Filename &KeepTrlcol hash_cnt) ;
			    		length &Inputlength &InputTrllength;
			    		INFILE "&&filename&j" firstobs=2  /*TERMSTR=CRLF*/ DLM="&delim" DSD missover end=last;
					  %end;
						input @ ;

			            FILENAME     = "&&name&j";
						FILE_LOAD_DT=&&FILE_LOAD_DT&j;
                        FORMAT FILE_LOAD_DT date9.;

					    if last ne 1  then do;
							INPUT  &Inputfield ;
							output  prestag.&target;
						    hash_cnt+1;
					    end;

						if last=1 then do;
					 %if &SrcNm = BBO %then %do;
					 	input &InputTrlfield;
					 %end;
                                       %ELSE %if &SrcNm = ROM OR &SrcNm = ROMM OR &SrcNm = MSR  %then %do;
					 	input &InputTrlfield;
					 %end;
					 %else %do;
					   	input SRC_NAME $ &InputTrlfield;
					 %end;
					    output control_table&j;
					    end;	
					RUN;
				  %end;

					%if &filetype = Delimiter %then %do;
			  		data prestag.&target;
				  		set prestag.&target;
				  		&DetColTrans= SUBSTR(&DetColTrans,2);
			  		run;
					%end;

					/*VC-200132 Start*/
					%if &Col1_Len=1 %then %do;
						data prestag.&target;
							length &Col1 $ 1;
							set prestag.&target;
							format &Col1 $CHAR1.;
						run;
					%end;
					/*VC-200132 End*/

				proc sql noprint;
					select count(*) into :prestgcnt
					from  prestag.&target;


					select count(*) into :ctlcnt
					from  control_table&j;
				quit;




				%if &prestgcnt= 0 and &ctlcnt=0 %then %do;
				%put Pre-Staging table not created. Check Interface File detail records;
						
				data _null_;
					call symput ("err_no_inf", "Pre-Staging table not created");
					call symput ("Job_Stat_Typ", '4');
					call symput("filename_in","&&name&j");
				run;

				%ADMIN_LOG_PROC(&err_no_inf, &Job_Stat_Typ);

				%end;
				%else %do;

					/* Verify whether hashcount and trail count is matching */			
		            data control_table&j(keep=FILENAME LOAD_DATE TRAIL_CNT HASH_CNT);
						set control_table&j;
		                format LOAD_DATE datetime22.;

						trail_cnt_ = input(trail_cnt,8.);
						drop trail_cnt;
						rename trail_cnt_  = trail_cnt;

						if trail_cnt = hash_cnt then 
							 REC_STS = 1;
						else REC_STS = 0;

		                call symput("rec_sts",REC_STS);
					   %if &filetype = Delimiter %then %do;
						&TrColTrans  = SUBSTR(&TrColTrans,2);
					  %end;
						LOAD_DATE = datetime();
					run;

					%put &rec_sts;
					
					%if &&rec_sts=1 %then %do;
						%put Exception Table is &Excptbl;
						/* Start Validity Check */
						  %if &filetype = Delimiter %then %do;
							%DateValid();
							%NRIC_CHK();
							%FIN_CHK();
							%MAND_CHK();
							%POST_CHK();
							%NUM_CHK();
							%OTHID_CHK();  /* VC-200129 */
						  %end;
						  %else %if &filetype = Fixed %then %do;
							%DateValid();
                                                        %NRIC_CHK(); /*MV-200132*/
                                                        %FIN_CHK();	 /*MV-200132*/
                                                        %MAND_CHK();
							%POST_CHK();
							%NUM_CHK();
							/*%PARENT_UIN_CHK;*/ /* JL-200130 */
							%let Table_Type = %SCAN(&STG_Table, 3, _); /* WA-200131 */
							%if &Table_Type = CODE or &Table_Type = CD %then %MAND_CHK(); /* WA-200131 */
						  %end;

						/* Check for Excptbl */
						%if %sysfunc(exist(excp.&Excptbl))=0 %then %put Exception table is not created;

							data &target._norej;
							set prestag.&target;
								if rej_sts=0 ;
							run;

							proc sql noprint;
								select count(*) into :valcnt
								from &target._norej;
							quit;

						/*Transform column into actual type*/		    

						%if &valcnt>0 %then %do;

							%Transform();

							%generate_rec_key(&SrcNm, in_&target);

							data in2_&target;
							set in_&target;
							keep FILENAME &KEEPCOL CANVAS_REC_KEY DATA_LOAD_DT FILE_LOAD_DT;
							run;

                                                        /*MR-200505 - Retain alphanumeric characters in character columns*/
                                                        %clean_char_vars(in2_&target);

							proc append base=stg.&STG_Table data=in2_%sysfunc(trim(&target))_clean force; run;

							data excp_cnt (keep=filename excp_cnt);
							  set prestag.&target  end=last;
							  if rej_sts=0 then excp_cnt+0;
							  else excp_cnt+1;
							  if last=1;
							run; 

							proc sql;
								create table control_tableb&j as
								select a.*,b.EXCP_CNT
								from  control_table&j as a, EXCP_CNT as b
								where a.filename=b.filename;
							quit;

							data _null_;
								call symput ("err_no_inf", "LOADING SUCCESSFUL");
								call symput ("Job_Stat_Typ", '2');
							run;

							%ADMIN_LOG_PROC(&err_no_inf, &Job_Stat_Typ);


						%end;
						%else %do;
							%put There is no data to transform and load into staging table;

							/*YS-200813 start*/
							
							data excp_cnt (keep=filename excp_cnt);
								set prestag.&target end=last;
								if rej_sts=0 then excp_cnt+0;
								else excp_cnt+1;
								if last=1;
							run;

							proc sql;
								create table control_tableb&j as
								select a.*, b.EXCP_CNT
								from control_table&j as a, EXCP_CNT as b
								where a.filename = b.filename;
							quit;
							
							/*YS-200813 end*/

							data _null_;
								/*set &target._norej*/ /*YS-200813*/
								call symput ("err_no_inf", "Records from Pre-staging rejected. No data to transform and load into staging table");
								call symput ("Job_Stat_Typ", '3');
							run;

							%ADMIN_LOG_PROC(&err_no_inf, &Job_Stat_Typ);
						%end;
					%end;
					%else %do;

						%put Staging table not created due to non-matching hash count and trail count;

						data control_tableb&j;
						set control_table&j;
						EXCP_CNT = . ;
						run;
						
						data _null_;
							call symput ("err_no_inf", "Non-Matching Hash and Trail count");
							call symput ("Job_Stat_Typ", '2');
						run;

						%ADMIN_LOG_PROC(&err_no_inf, &Job_Stat_Typ);

					%end;
				%end;
			%end;
		%end;
	%end;



		proc sql ;
		create table missing_inf(where=(actual_file = ' ')) as
		select distinct
			a.name_key,
			b.name as actual_file,
			a.FileID
		from
			full_attrib as a 
			full join 
			Full_list as b
		on a.name_key=b.name_key
	  %if &srcnm = FJC %then %do;
           and compress(substr(b.name, find(b.name,'.') , 4)) = compress(a.Extension)
	  %end;
	     ;
		quit;

		proc sql noprint;
			select count(*) into :datacnt
			from missing_inf;
		quit;

	%if &datacnt > 0  %then %do;
		%do y = 1 %to &datacnt;
			data _null_;
				set missing_inf;
				if _N_ = &y then call symput("miss_inf_var", compress(name_key));
			run;

			%put  The external file &miss_inf_var..txt does not exist.; 
								
			data _null_;
				call symput ("err_no_inf", "Missing Interface File.");
				call symput ("Job_Stat_Typ", '1');
				call symput ("filename_in", "&miss_inf_var.");
			run;

			%ADMIN_LOG_PROC(&err_no_inf, &Job_Stat_Typ);

		%end;
	%end;
	
%mend;


