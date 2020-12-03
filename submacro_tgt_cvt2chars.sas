/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: submacro_tgt_cvt2chars.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%macro cvt2chars(inputlib, /* libref for input data set */
 				inputdsn, /* name of input data set */
				outputlib, /* libref for output data set */
 				outputdsn, /* name of output data set */
		 		excludevars); /* variables to exclude */

		proc sql noprint;
		select name, name
		into :charvars separated by ' ',
			 :charlist separated by '", "'
		from dictionary.columns
		where libname=upcase("&inputlib") and memname=upcase("&inputdsn") and type = ("num")
				and not indexw(upcase("&excludevars"),upcase(name));
		quit;

		data _null_;
		set STG.CANVAS_CTL_SRCFILE_ATTRIB(where=(STG_Table = "&dsname" and Field in ("&charlist")));
			call symput ("fmt"||left(trim(_n_)), left(trim(Format)));
		run;

		%let ncharvars=%sysfunc(countw(&charvars));

		data _null_;
			set &inputlib..&inputdsn end=lastobs;
			array charvars{*} &charvars;
			array charvals{&ncharvars};
			do i=1 to &ncharvars;
			 	if input(charvars{i}, best32.)=. and charvars{i} ne ' ' then charvals{i}+1;
			end;
			if lastobs then do;
				 length varlist $ 32767;
				 do j=1 to &ncharvars;
				 	if charvals{j}=. then do;
						varlist=catx(' ',varlist,vname(charvars{j}));
					end;
					call symputx('varlist', varlist);
				end;
			end;
		run;

		%let nvars=%sysfunc(countw(&varlist));
		%put &nvars;

 		data temp;
			set &inputlib..&inputdsn;
			array charx{&nvars} &varlist;
			array x{&nvars} $;
			do i=1 to &nvars;
				 x{i}=charx{i};
			end;
			%do j=1 %to &nvars;
			 	y&j = put(input(x&j, 8.),&&fmt&j.);
			%end;
			drop &varlist i;
			%do i=1 %to &nvars;
			 	rename y&i = %scan(&varlist,&i) ;
			%end;
		run;

	proc sql noprint;
		select name into :orderlist separated by ' '
		from dictionary.columns
		where libname=upcase("&inputlib") and memname=upcase("&inputdsn")
		order by varnum;
		select catx(' ','label',name,'=',quote(trim(label)),';')
		 into :labels separated by ' '
		from dictionary.columns
		where libname=upcase("&inputlib") and memname=upcase("&inputdsn") and
		 indexw(upcase("&varlist"),upcase(name));
		quit;

	data &outputlib..&outputdsn;
		retain &orderlist;
		set temp;
		&labels
		run;

%mend;
