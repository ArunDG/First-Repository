/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: submacro_tgt_chksum.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%macro chksum_proc;
		first_char = upcase(substr(&&in_fldnm&i,1,1));
		id_len     = length(compress(&&in_fldnm&i,' ','kd'));

		if first_char = 'F'  and id_len = 7 then do;
					numpart  = compress(&&in_fldnm&i,' ','kd');
					chk_sum_ = ((input(substr(numpart,1,1),best12.)*2)+(input(substr(numpart,2,1),best12.)*7)+(input(substr(numpart,3,1),best12.)*6)
							   +(input(substr(numpart,4,1),best12.)*5)+(input(substr(numpart,5,1),best12.)*4)+(input(substr(numpart,6,1),best12.)*3)
							   +(input(substr(numpart,7,1),best12.)*2));				    
					chk_sum  = put( 11 - MOD(chk_sum_,11), fin_chksum. );
		end;
		else if first_char = 'G'  and id_len = 7 then do;
					numpart  = compress(&&in_fldnm&i,' ','kd');
					chk_sum_ = ((input(substr(numpart,1,1),best12.)*2)+(input(substr(numpart,2,1),best12.)*7)+(input(substr(numpart,3,1),best12.)*6)
							   +(input(substr(numpart,4,1),best12.)*5)+(input(substr(numpart,5,1),best12.)*4)+(input(substr(numpart,6,1),best12.)*3)
							   +(input(substr(numpart,7,1),best12.)*2)) + 4;				    
					chk_sum  = put( 11 - MOD(chk_sum_,11), fin_chksum. );
		end;
		else if first_char = 'S'  and id_len = 7 then do;
					numpart  = compress(&&in_fldnm&i,' ','kd');
					chk_sum_ = ((input(substr(numpart,1,1),best12.)*2)+(input(substr(numpart,2,1),best12.)*7)+(input(substr(numpart,3,1),best12.)*6)
							   +(input(substr(numpart,4,1),best12.)*5)+(input(substr(numpart,5,1),best12.)*4)+(input(substr(numpart,6,1),best12.)*3)
							   +(input(substr(numpart,7,1),best12.)*2));				    
					chk_sum  = put( 11 - MOD(chk_sum_,11), nric_chksum. );
		end;
		else if first_char = 'T'  and id_len = 7 then do;
					numpart  = compress(&&in_fldnm&i,' ','kd');
					chk_sum_ = ((input(substr(numpart,1,1),best12.)*2)+(input(substr(numpart,2,1),best12.)*7)+(input(substr(numpart,3,1),best12.)*6)
							   +(input(substr(numpart,4,1),best12.)*5)+(input(substr(numpart,5,1),best12.)*4)+(input(substr(numpart,6,1),best12.)*3)
							   +(input(substr(numpart,7,1),best12.)*2))+4;				    
					chk_sum  = put( 11 - MOD(chk_sum_,11), nric_chksum. );
		end;

%mend;
