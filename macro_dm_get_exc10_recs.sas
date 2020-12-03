/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_dm_get_exc10_recs.sas

CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE | MODIFIED BY   | MODIFICATION_TAG  | MODIFICATION REMARKS
<YYYY-MM-DD>    <NAME>        <INITIALS-YYMMDD>   <SHORT DESCRIPTION OF CHANGES>    

**************************************************************************************************/


%macro MSR_EXCP;
	(select 
		case when a.CLIENT_ID_TYPE_CD in ('SB', 'SP') then a.CLIENT_ID else '' end as NRIC_ID,
		case when a.CLIENT_FIN is not null then a.CLIENT_FIN else '' end as FIN_ID,
		case when a.CLIENT_ID_TYPE_CD not in ('SB', 'SP') then a.CLIENT_ID 
			 when a.CLIENT_PREVIOUS_ID is not null then a.CLIENT_PREVIOUS_ID else ''  end as OTH_ID,
		CLIENT_DOB
		from (select exc.*, ejl.JOB_START_DT
			from dbo.EXCP_&tbl_nm  exc
			left join dbo.ETL_JOB_LOG ejl
			on exc.JOB_RUN_ID=ejl.JOB_RUN_ID
			where 
			convert(date, ejl.JOB_START_DT)  =  convert(date, getdate())) b
		left join 
			 dbo.STG_MSR_CLIENTDETAILS a
		on 
			a.CLIENT_IDENTIFIER=b.FEMALE_IDENTIFIER or 
			a.CLIENT_IDENTIFIER=b.MALE_IDENTIFIER
		where b.EXCP_RSN_CD = 'Exception_10') 
%mend;


%macro ICA_EXCP;
	(select 
		case when a1.NRIC_OF_APPLICANT is not null then a1.NRIC_OF_APPLICANT end as NRIC_ID,
		case when a1.FIN_OF_APPLICANT is not null then a1.FIN_OF_APPLICANT end as FIN_ID,
		case when a1.PASSPORT_OF_APPLICANT IS NOT NULL then a1.PASSPORT_OF_APPLICANT end as OTH_ID,
		a1.DOB_OF_APPLICANT AS CLIENT_DOB
		from 
		(select exc.*, ejl.JOB_START_DT
			from dbo.EXCP_&tbl_nm  exc
			left join dbo.ETL_JOB_LOG ejl
			on exc.JOB_RUN_ID=ejl.JOB_RUN_ID
			where  exc.EXCP_RSN_CD = 'Exception_10' and 
			convert(date, ejl.JOB_START_DT)  =  convert(date, getdate())) a1
		union
		select 
		case when a2.NRIC_OF_SPOUSE is not null then a2.NRIC_OF_SPOUSE end as NRIC_ID,
		case when a2.FIN_OF_SPOUSE is not null then a2.FIN_OF_SPOUSE end as FIN_ID,
		case when a2.PASSPORT_OF_SPOUSE IS NOT NULL then a2.PASSPORT_OF_SPOUSE end as OTH_ID,
		a2.DOB_OF_SPOUSE AS CLIENT_DOB
		from 
		(select exc.*, ejl.JOB_START_DT
			from dbo.EXCP_&tbl_nm  exc
			left join dbo.ETL_JOB_LOG ejl
			on exc.JOB_RUN_ID=ejl.JOB_RUN_ID
			where  exc.EXCP_RSN_CD = 'Exception_10' and 
			convert(date, ejl.JOB_START_DT)  =  convert(date, getdate())) a2
		)
%mend;

%macro BBO_EXCP;
	(select 
		case when a.ID_TYPE in ('SB','SP') then a.NRIC_FIN else '' end as NRIC_ID,
		case when a.ID_TYPE IN ('SE','SS') then a.NRIC_FIN else '' end as FIN_ID,
		a.FOREIGN_ID as OTH_ID,
		BIRTH_DT as CLIENT_DOB
		from (select exc.*, ejl.JOB_START_DT
			from dbo.EXCP_&tbl_nm  exc
			left join dbo.ETL_JOB_LOG ejl
			on exc.JOB_RUN_ID=ejl.JOB_RUN_ID
			where 
			convert(date, ejl.JOB_START_DT)  =  convert(date, getdate())) b
		left join 
			 dbo.STG_BBO_PARENT a
		on 
			a.SEQ_PARENT_TRUSTEE=b.SEQ_MOTHER or 
			a.SEQ_PARENT_TRUSTEE=b.SEQ_FATHER
		where b.EXCP_RSN_CD = 'Exception_10'
		) 
%mend;


%macro get_exc10_recs(tbl_nm);

	proc sql;
	connect to SQLSVR as SQLCNCT(DATASRC="CANVAS_STG" authdomain="ETLADMIN");
	create table WORK.EXCP_&tbl_nm as select * from connection to SQLCNCT(
	select 
        b.INDV_KEY,
	b.NRIC_ID,
	b.FIN_ID,
	b.OTH_ID,
	b.BRTH_DT
	from
		%if &tbl_nm = STG_MSR_MARR OR &tbl_nm = STG_MSR_DIVORCE OR &tbl_nm = STG_MSR_ANNULMENT %then %do;
			%MSR_EXCP
		%end; 
		%else %if &tbl_nm = STG_ICA_ZSF038OO OR &tbl_nm = STG_ICA_ZSF051OO OR &tbl_nm = STG_ICA_ZSF054OO %then %do;
			%ICA_EXCP
		%end;   
		%else %if &tbl_nm = STG_BBO_PARENT_MARRIAGE %then %do;
			%BBO_EXCP
		%end;   	
		a
	left join
		CANVAS_TGT.dbo.VW_INDV_IDNTY_LNK b
	on 
	a.NRIC_ID=b.NRIC_ID or
	a.FIN_ID=b.FIN_ID or
	(a.OTH_ID=b.OTH_ID and a.CLIENT_DOB=b.BRTH_DT)
	);
	disconnect from SQLCNCT;
	quit;

	data APPENDED;
	set APPENDED EXCP_&tbl_nm;
	run;

%mend;

