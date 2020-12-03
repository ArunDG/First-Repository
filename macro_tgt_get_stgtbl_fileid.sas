/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_tgt_get_stgtbl_fileid.sas     

PROGRAM DESCRIPTION: Retrieves FILEID of staging table from CONTROL FILELIST


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%macro get_stgtbl_fileid(stg_table);

/* retrieves fileid from STG.CTL_FILELIST given the name of the staging table */

proc sql noprint;
	select FileID
	into :tbl_fileid
	from STG.CTL_FILELIST
	where STG_Table = "&stg_table";

quit;

proc sql noprint;
	create table tmp as
	select a.*,
		"&tbl_fileid" as FILE_ID
		from &_input. as a;
quit;

data &_output;
	set tmp;
run;

%mend;