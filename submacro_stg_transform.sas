/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: submacro_stg_transform.sas

PROGRAM DESCRIPTION: Converts columns into respective data type and format.


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%Macro Transform();
	data Var_to_Cnvrt;
		set Dist_attrib_list;
		where Isconvert="Y" and RecordType="D" and Validcheck_filter ne "Incomplete";
		field1=left(trim(field))||left(trim("1"));
	run;

	proc sql noprint;
	  select
  	  case when upcase(ValidCheck1)="DTM" then  
		left(trim(field1))||"="||"datepart"||"("||"input"||"("||left(trim(field))||","||left(trim(informat))||"))"||";"

               when upcase(informat)="YYMMDD8."  then
	        "IF"||" "||"substr"||"("||left(trim(field))||",1,4) lt 1582"||" "||" "||"THEN"||" "||" "||left(trim(field1))||"=.;"
		 ||"ELSE"||" "||left(trim(field1))||"="||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||";"

             when upcase(informat)="DDMMYY8."  then
	         "IF"||" "||"substr"||"("||left(trim(field))||",5,4) lt 1582"||" "||"THEN"||" "||" "||left(trim(field1))||"=.;"
		 ||"ELSE"||" "||left(trim(field1))||"="||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||";"
	  else 
		left(trim(field1))||"=input("||left(trim(field))||","||left(trim(informat))||");" 
	  end,

	      field,
		  left(trim(field1))||"="||left(trim(field)),
	      left(trim(field1))||" "||left(trim(format))
		  into :transfield separated by " ",
	           :dropfield separated by " ",
	           :renamefield separated by " ",
			   :formatfield separated by " "
	  from Var_to_Cnvrt;
	quit;


data Var_to_Cnvrt1;
		set Dist_attrib_list;
		where Isconvert="Y" and RecordType="D" and Validcheck_filter="Incomplete";
		field1=left(trim(field))||left(trim("1"));
run;
data _null_;
	  set Var_to_Cnvrt1;
	  call symput ("Ifmt_Chk", Informat);
run;
%put &Ifmt_Chk;

	
	proc sql noprint;
	  select  
%if %symexist(Ifmt_Chk) %then %do;
 %if %sysfunc(upcase(%sysfunc(compress(&Ifmt_Chk)))) = YYMMDD8. %then %do;
     "IF"||" "||"substr"||"("||left(trim(field))||",1,4) lt 1582"||" "||/*"AND"||" "||"substr"||"("||left(trim(field))||",5,4) le 0000"||*/" "||"THEN"||" "||" "||left(trim(field1))||"=.;"

	  ||"ELSE IF"||" "||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||" "||"or"||" "||"input"||"("||left(trim(field))||","||left(trim(informat))||")=0"||
          " "||"THEN"||" "||left(trim(field1))||"="||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||";"

	  ||"ELSE IF"||" "||"substr"||"("||left(trim(field))||",1,4) ge 1582"||" "
         ||"AND"||" "||"substr"||"("||left(trim(field))||",5,4) = 0000"|| " "||"THEN" 
              ||" "|| left(trim(field1))||"="||"MDY(1,1,input(substr"||"("||left(trim(field))||",1,4),"||"4."||"))"||";"

	||"ELSE IF"||" "||"(substr"||"("||left(trim(field))||",7,2) gt 0"||" "||"and"||" "||"substr"||"("||left(trim(field))||",7,2) le 31)"||" "
	      ||"AND"||" "||"substr"||"("||left(trim(field))||",5,2) = 00"||" and "||"substr"||"("||left(trim(field))||",1,4) gt 1542"||" "||"THEN" 
		      ||" "||left(trim(field1))||"="||"MDY(1,substr(DOB,7,2),input(substr"||"("||left(trim(field))||",1,4),"||"4."||"))"||";"

	||"ELSE IF"||" "||"(substr"||"("||left(trim(field))||",5,2) gt 0"||" "||"and"||" "||"substr"||"("||left(trim(field))||",5,2) le 12)"||" "
	      ||"AND"||" "||"substr"||"("||left(trim(field))||",7,2) = 00"||" and "||"substr"||"("||left(trim(field))||",1,4) gt 1542"||" "||"THEN" 
	      ||" "|| left(trim(field1))||"="||"MDY(substr(DOB,5,2),1,input(substr"||"("||left(trim(field))||",1,4),"||"4."||"))"||";"
	  
 %end;


 %else %if %sysfunc(upcase(%sysfunc(compress(&Ifmt_Chk)))) = DDMMYY8. %then %do;

    "IF"||" "||"substr"||"("||left(trim(field))||",5,4) lt 1582"||" "/*||"AND"||" "||"substr"||"("||left(trim(field))||",1,4) "|| " "*/||"THEN"||
          " "||" "||left(trim(field1))||"=.;"

	 ||"ELSE IF"||" "||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||" "||"or"||" "||"input"||"("||left(trim(field))||","||left(trim(informat))||")=0"||
         " "||"THEN"||" "||left(trim(field1))||"="||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||";"

	 ||"ELSE IF"||" "||"substr"||"("||left(trim(field))||",5,4) ge 1582"||" "
         ||"AND"||" "||"substr"||"("||left(trim(field))||",1,4) = 0000"|| " "||"THEN" 
              ||" "|| left(trim(field1))||"="||"MDY(1,1,input(substr"||"("||left(trim(field))||",5,4),"||"4."||"))"||";"

     ||"ELSE IF"||" "||"(substr"||"("||left(trim(field))||",1,2) gt 0"||" "||"and"||" "||"substr"||"("||left(trim(field))||",1,2) le 31)"||" "
	      ||"AND"||" "||"substr"||"("||left(trim(field))||",3,2) = 00"||" and "||"substr"||"("||left(trim(field))||",5,4) gt 1542"||" "||"THEN" 
		      ||" "||left(trim(field1))||"="||"MDY(1,substr(DOB,1,2),input(substr"||"("||left(trim(field))||",5,4),"||"4."||"))"||";"

     ||"ELSE IF"||" "||"(substr"||"("||left(trim(field))||",3,2) gt 0"||" "||"and"||" "||"substr"||"("||left(trim(field))||",3,2) le 12)"||" "
	      ||"AND"||" "||"substr"||"("||left(trim(field))||",1,2) = 00"||" and "||"substr"||"("||left(trim(field))||",5,4) gt 1542"||" "||"THEN" 
	      ||" "|| left(trim(field1))||"="||"MDY(substr(DOB,3,2),1,input(substr"||"("||left(trim(field))||",5,4),"||"4."||"))"||";"

 %End;
%end;

 %Else %do;
	  "IF"||" "||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||" "||"THEN"||" "||left(trim(field1))||"="||"input"||"("||left(trim(field))||","||left(trim(informat))||")"||";"
 %End;
 /*
	||"ELSE IF input("||left(trim(field))||",yymmn6.)"||" "||"THEN"  
               ||" "|| left(trim(field1))||"="||"intnx('month',input"||"("||left(trim(field))||","||"yymmn6."||"),0,'BEGINNING')"||";"
	||"ELSE IF input("||left(trim(field))||",monyy8.)"||" "||"THEN"  
               ||" "|| left(trim(field1))||"="||"intnx('month',input"||"("||left(trim(field))||","||"monyy8."||"),0,'BEGINNING')"||";"
    ||"ELSE IF input("||left(trim(field))||",4.) and (input("||left(trim(field))||",4.)>1900 and input("||left(trim(field))||",4.)<2050)"||" "||"THEN" 
              ||" "|| left(trim(field1))||"="||"MDY(1,1,input"||"("||left(trim(field))||","||"4."||"))"||";"
*/

	||"ELSE"||" "||left(trim(field1))||"=.;" ,
	      field,
		  left(trim(field1))||"="||left(trim(field)),
	      left(trim(field1))||" "||left(trim(format))
		  into :transfield1 separated by " ",
	           :dropfield1 separated by " ",
	           :renamefield1 separated by " ",
			   :formatfield1 separated by " "
	  from Var_to_Cnvrt1;
	quit;

	%put &transfield;
	%put &dropfield;
	%put &renamefield;
	%put &formatfield;

	%put &transfield1;
	%put &dropfield1;
	%put &renamefield1;
	%put &formatfield1;

	%if %symexist(transfield)=1 AND %symexist(transfield1)=1 %then %do;
	data in_&target (drop=cnt rej_sts exp_cnt);
		set &target;
		&transfield &transfield1
		drop &dropfield &dropfield1 ;
		format &formatfield &formatfield1;
		rename &renamefield &renamefield1;
	run;
  %end;
  %Else %if %symexist(transfield)=1 AND %symexist(transfield1)NE 1 %then %do;
	data in_&target (drop=cnt rej_sts exp_cnt);
		set &target;
		&transfield 
		drop &dropfield  ;
		format &formatfield ;
		rename &renamefield ;
	run;
   %end;

  %ELSE %if %symexist(transfield) NE 1 AND %symexist(transfield1)=1 %then %do;
	data in_&target (drop=cnt rej_sts exp_cnt);
		set &target;
		&transfield1
		drop  &dropfield1 ;
		format &formatfield1;
		rename &renamefield1;
	run;
  %end;

	%else %do;
	data in_&target(drop=cnt rej_sts exp_cnt);
		set &target;
	run;
	%end;

%mend;
