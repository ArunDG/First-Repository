/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_tgt_UIN_Validation.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		
2020-04-19              Vyna                             VC - 200419                    Exclude Null IDs from exception records 
											for ZSF0ICA6500 and ZSF0ICA660D

2020-02-10		Winson				 WA-201002			Changed OTH ID check to check for length of 
											OTH ID >= 1 (At least 1 digit present)
**************************************************************************************************/

%include '/sasdata/CANVAS/Jobs/SAS Code/submacro/submacro_tgt_cvt2chars.sas';

proc format;
value FIN_CHKSUM
1 =  'K'
2 =  'L' 
3 =  'M' 
4 =  'N' 
5 =  'P' 
6 =  'Q' 
7 =  'R' 
8 =  'T' 
9 =  'U' 
10 = 'W'
11 = 'X'
;

value NRIC_CHKSUM
1 =  'A'
2 =  'B' 
3 =  'C' 
4 =  'D' 
5 =  'E' 
6 =  'F' 
7 =  'G' 
8 =  'H' 
9 =  'I' 
10 = 'Z'
11 = 'J'
;
run;

%macro isBlank(param);
 %sysevalf(%superq(param)=,boolean)
%mend isBlank; 

%macro uin_validation;

	data get_ids;
		set TGT.MAST_UIN_LIST (where=(in_tbl = "&dsname"));
		call symput("in_fldnm"||left(trim(_n_)),  Field_nm);
		call symput("nric_parm"||left(trim(_n_)), Out_NRIC);
		call symput("fin_parm"||left(trim(_n_)),  Out_FIN);
		call symput("oth_parm"||left(trim(_n_)),  Out_OTH);
	run;

	proc sql noprint;
		select count(*) into :tot
		from get_ids;
	quit;

	proc sql noprint;
		select name into :exc_vars separated by ' '
		from dictionary.columns
		where libname=upcase("&lib") and memname=upcase("&dsname") and name not in ("CANVAS_REC_KEY", "FILE_LOAD_DTTM");
		quit;

  	data valid_ids;
	set &lib..&dsname;

	  %do i = 1 %to &tot;
		%chksum_proc;
	            if first_char in ('F', 'G') and id_len = 7 and upcase(substr(&&in_fldnm&i,length(&&in_fldnm&i),1)) = chk_sum 
			then &&fin_parm&i = &&in_fldnm&i;
	            else if first_char in ('S', 'T') and id_len = 7 and upcase(substr(&&in_fldnm&i,length(&&in_fldnm&i),1)) = chk_sum 
			then &&nric_parm&i = &&in_fldnm&i;	
		%if %isblank(&&oth_parm&i) = 0 %then %do;
		    else if length(compress(&&in_fldnm&i,'123456789','k')) >= 1 and compress(&&in_fldnm&i,'123456789','k') ^= '' then &&oth_parm&i = &&in_fldnm&i; /* WA - 201002  */
		%end;
		%if &FILEID = ICA12 or &FILEID = ICA01 %then %do; /* start: VC - 200419  */
                    else &&oth_parm&i = ' ';
		%end;
		%else %do;
		    else DESCRIPTION = "Invalid UIN";
		%end;  /* end: VC - 200419  */		

		drop chk_sum_ chk_sum numpart first_char id_len ;

	  %end;

	run;

	data &_output(drop=DESCRIPTION) invalid_ids;
		set valid_ids;
		if DESCRIPTION = "Invalid UIN" then output invalid_ids;
		else output &_output;
	run;


%mend;

