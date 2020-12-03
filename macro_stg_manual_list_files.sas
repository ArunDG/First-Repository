/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_manual_list_files.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: 2020-02-27
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		
**************************************************************************************************/

*Creates a list of all files in the DIR directory with the specified extension (EXT);



%macro manual_list_files(dir, ext);
	%local filrf rc did memcnt name i;
	%let rc=%sysfunc(filename(filrf,&dir));
	%let did=%sysfunc(dopen(&filrf));

	%if &did eq 0 %then	%do;
			%put Directory &dir cannot be open or does not exist;
			%return;
	%end;
	%else %do;
		%if %sysfunc(dnum(&did)) = 0 %then %do;

			%put Missing Interface Files;

			proc sql noprint;
				select count(*) into:inf_cnt 
				from ADMIN.CTL_FILELIST where SourceName = "&SrcNm.";
			quit;

			%put inf_cnt is &inf_cnt;	
				%do z = 1 %to &inf_cnt;
					data _null_;
						set ADMIN.CTL_FILELIST (where=(SourceName = "&SrcNm."));
						if _N_ = &z;
						call symput ("FileName_in", Filename);
						call symput ("err_no_inf",  "Missing Interface File");
						call symput ("Job_Stat_Typ", '1');
						run;

						%ADMIN_LOG_PROC(&err_no_inf, &Job_Stat_Typ);
					%abort;

				%end;
		%end;
		%else %do;
			%do i = 1 %to %sysfunc(dnum(&did));
				%let name = %qsysfunc(dread(&did,&i));

				%if %qupcase(%qscan(&name,-1,.)) = %upcase(&ext) %then %do;
					%put &dir/&name;
					%let file_name =  %qscan(&name,1,.);
					%put &file_name;
						data temp;
							length dir $512 name $100;
							dir		 = symget("dir");
							name	 = symget("name");
							path 	 = catx('/',dir,name);
							the_name = substr(name,1,find(name,'.')-1);
						run;

						proc append base=Full_list data=temp force;
						run;

						proc sql;
							drop table temp;
						quit;
				%end;
			%end;
		%end;
	%end;

	%put %qscan(&name,2,.);
	%let rc=%sysfunc(dclose(&did));
	%let rc=%sysfunc(filename(filrf));

%mend manual_list_files;