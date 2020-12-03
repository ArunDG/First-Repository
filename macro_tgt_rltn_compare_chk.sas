%macro RLTN_COMPARE_CHK();

proc sort data=&_INPUT;
	by INDV_FRM_KEY INDV_TO_KEY RLTN_CD RLTN_STRT_DT DATA_SRC_CD;
run;

proc sort data=TGT.TB_D_RELTN out=TB_D_RELTN;
	by INDV_FRM_KEY INDV_TO_KEY RLTN_CD RLTN_STRT_DT DATA_SRC_CD;
run;

data &_OUTPUT;
	merge &_INPUT(IN=A) TB_D_RELTN(IN=B rename=(VALID_FRM_DT=VALID_FRM_DT_ORI));
	by INDV_FRM_KEY INDV_TO_KEY RLTN_CD RLTN_STRT_DT DATA_SRC_CD;

	if A=1 AND B=1 then
		do;
			VALID_FRM_DT = min(VALID_FRM_DT, VALID_FRM_DT_ORI);
			tag = 'update';
		end;
	else if A=1 AND B=0 then
		tag = 'new';
	else tag = 'drop';

	if tag ^= 'drop';
run;

%mend RLTN_COMPARE_CHK;
