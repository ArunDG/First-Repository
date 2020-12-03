/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_dm_hash_surrkey.sas
CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE | MODIFIED BY   | MODIFICATION_TAG  | MODIFICATION REMARKS
<YYYY-MM-DD>    <NAME>        <INITIALS-YYMMDD>   <SHORT DESCRIPTION OF CHANGES>    

**************************************************************************************************/

%global salt_val;

%macro hash_surrkey;

	proc sql noprint;
		select compress(val) into :salt_val
		from TGT.SALT_VAL;
	quit;

%mend;

