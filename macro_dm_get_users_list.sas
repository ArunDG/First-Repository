%global input_line;

%macro get_inputline(filepath, row_num);
	/*this code is used to get &input_line which tells SAS how to input the columns*/
	data header;
		infile "&filepath" firstobs=&row_num obs=&row_num truncover;
		input header $1-150;
	run;

	data columns;
		set header;
		num_cols = countw(header);
		do i=1 to num_cols;
			word = scan(header, i);
			length = findw(header, scan(header, i));
			output;
		end;
		keep word length;
	run;

	data final;
		merge columns columns(firstobs=2 rename=(length=next_length) drop=word);
		if next_length = . then next_length = length + 30;
	run;

	proc sql noprint;
		select strip(word)||" $"||strip(put(length, 3.))||"-"||strip(put(next_length-1, 3.)) as col
		into :input_line separated by " "
		from final;
	quit;
%mend;

%macro get_userlist(filepath);
	/*parse viya_userslist in blocks since each page has different length to every column*/
	data header;
		infile "&filepath" firstobs=1 truncover;
		input header $1-210;
		if find(header, "Id") and find(header, "Name") and find(header, "Description") and find(header, "State") then do;
			row_num = _N_;
			output;
		end;
	run;

	proc sql noprint;
		select row_num
		into :row_num1-:row_num1000
		from header;
	quit;
	
	%let sql_row = &sqlobs;
	%put &sql_row;

	%do i=1 %to &sql_row;
		
		%get_inputline(&filepath, &&row_num&i);

		%if &i = 1 %then %do;
			data user_list;
				length id $30 name $100 description $50 state $30;
			run;
		%end;
		
		%let k = %sysevalf(&i + 1);	
	
		%if &k <= &sql_row %then %do;
			data temp;
				infile "&filepath" firstobs=%sysevalf(&&row_num&i+1) obs=%sysevalf(&&row_num&k-1) truncover;
				input &input_line;
			run;
		%end;

		%else %do;
			data temp;
				infile "&filepath" firstobs=%sysevalf(&&row_num&i+1) truncover;
				input &input_line;
			run;
		%end;

		proc append base=user_list data=temp force;
		run;
	%end;
%mend;

%macro get_authlist(folderpath, fn, type, access);
	/*this code reads each individual auth text file*/
	%let filepath = %sysfunc(cats(&folderpath, &fn));
	%get_inputline(&filepath, 2);

	data auth;
		infile "&filepath" firstobs=3 truncover;
		input &input_line;
	run;

	data groups_temp users_temp;
		length name $50
		length type access $15;
		set auth;
		type = "&type";
		access = "&access";
		name = scan(principal, 1);
		if find(principal, '(group)') then output groups_temp;
		else if find(principal, '(user)') then output users_temp;
		keep name read type access;
	run;
%mend;

%macro get_users(folderpath);
	/*this code combines all the previous macros to generate user_list / groups_members / users and groups access list*/
	/*based on today's date. if there are no files generated today, code will not run*/
	%let date = %sysfunc(today(), yymmdd10.);

	filename folder "&folderpath";

	data FilesInFolder;
	   length Line 8 File $300;
	   List = dopen('folder');
	   do Line = 1 to dnum(List);
	        File = trim(dread(List,Line));
			output;
	   end;
	   drop list line;
	run;

	proc sql;
		select file, scan(file, 1, "_") as type, scan(file, 2, "_") as access
		into :fn1 - :fn99, :type1 - :type99, :access1 - :access99
		from FilesInFolder
		where File contains "auth" and File contains put(today(), yymmdd10.);
	quit;

	%let sql_numrows = &sqlobs;
	
	%if &sql_numrows = 0 %then %do;
		%put "No text files to parse from Viya!";
	%end;

	%else %do;
		%do i=1 %to &sql_numrows;
			%if &i = 1 %then %do;
				%get_authlist(&folderpath, &&fn&i, &&type&i, &&access&i);
				data groups;
					set groups_temp;
				run;

				data users;
					set users_temp;
				run;
			%end;

			%else %do;
				%get_authlist(&folderpath, &&fn&i, &&type&i, &&access&i);
				proc append base=groups data=groups_temp;
				run;

				proc append base=users data=users_temp;
				run;
			%end;
		%end;

		data groups_members;
			infile folder("group_members_&date..txt") truncover dlm=",";
			length group $30 member $30;
			input group $ member $;
		run;

		%let filepath = &folderpath.viya_userslist_&date..txt;
		%get_userlist(&filepath);

		proc sql;
			create table &_output as
			select group, member, read, type, access,t2.name
			from (
				select name as group, member, read, type, access
				from groups
				left join groups_members
				on groups.name = groups_members.group
				union
				select "" as group, name as member, read, type, access
				from users) as t1
			left join (
				select id, name
				from user_list) as t2
			on t1.member = t2.id;
		quit;
	%end;
%mend;