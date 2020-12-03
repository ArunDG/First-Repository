/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_tgt_subsist_annull.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		

**************************************************************************************************/

%macro drv_mrtl_sts;

	/*deal with subsisting civil marriages here*/
	proc sql;
		create table subsist_civil as
		select DATA_SRC_CD, INDV_KEY, MARR_KEY, REG_CD, DATA_LOAD_DT, EVENT_DT, MARR_TAG, MARR_1961_TAG, BIRTH_DT
		from &_INPUT
		where MARR_1961_Tag = 'Subsisting Civil';
	quit;

	proc sort data=subsist_civil;
		by INDV_KEY descending EVENT_DT;
	run;

	/*this code deals with existing civil marriages. i.e. multiple civil marriages are sorted by date and the older one is closed off*/
	data end_subsisting_marr;
		set subsist_civil;
		by INDV_KEY descending EVENT_DT;
		length VALID_TO_DT PREV_VALID_TO_DT VALID_FRM_DT 8 DRV_MRTL_STS $2;
		retain PREV_VALID_TO_DT;

		/*there will not be any divorced status of 5. instead we will just close off the older marriage record*/
		format VALID_TO_DT PREV_VALID_TO_DT VALID_FRM_DT date9.;
		if first.INDV_KEY and first.EVENT_DT then do;
			PREV_VALID_TO_DT = EVENT_DT;
			VALID_FRM_DT = EVENT_DT;
			VALID_TO_DT = "01JAN5999"d;
			DRV_MRTL_STS = "2";
		end;

		else do;
			VALID_TO_DT = PREV_VALID_TO_DT;
			VALID_FRM_DT = EVENT_DT;
			PREV_VALID_TO_DT = EVENT_DT;
			MARR_TAG = 'Active Marriage';
			DRV_MRTL_STS = "2";
		end;

		keep VALID_FRM_DT DATA_SRC_CD DATA_LOAD_DT INDV_KEY MARR_TAG VALID_TO_DT MARR_1961_TAG DRV_MRTL_STS BIRTH_DT;
	run;

	/*want to take input table and enumerate all of the columns, excluding subsisting civil and muslim / multiple marriages records*/
	proc sql;
		create table exclude_muslim_civil as
		select *
		from &_input
		where indv_key not in (select distinct indv_key 
								from &_input 
								where MARR_1961_TAG in ("Subsisting Civil", "Muslim Male", "Male-Multiple Marr"));
	quit;

	/*basically if marr_tag = divorced_marriage, theres an internal record for marriage as well. so need to have 2 records produced*/
	/*similarly for widowed. we ignore annulled marriage here because annulled marriage = marriage did not happen (revert back to previous status) */
	/*so can ignore*/
	data split_data;
		set exclude_muslim_civil;
		length VALID_TO_DT VALID_FRM_DT 8 DRV_MRTL_STS $2;
		if MARR_TAG = "Divorced Marriage" then do;
			drv_mrtl_sts = "2";
			valid_frm_dt = marr_dt;
			valid_to_dt = dvrce_dt;
			output;

			drv_mrtl_sts = "5";
			valid_frm_dt = dvrce_dt;
			valid_to_dt = "01JAN5999"d;
			output;
		end;

		else if MARR_TAG = "Active Marriage" then do;
			drv_mrtl_sts = "2";
			valid_frm_dt = marr_dt;
			valid_to_dt = "01JAN5999"d;
			output;
		end;

		else if MARR_TAG = "Widowed" then do;
			drv_mrtl_sts = "3";
			valid_frm_dt = sps_death_dt;
			valid_to_dt = "01JAN5999"d;
			output;

			drv_mrtl_sts = "2";
			valid_frm_dt = marr_dt;
			valid_to_dt = sps_death_dt;
			output;
		end;

		else if MARR_TAG = "Single" then do;
			drv_mrtl_sts = "1";
			valid_frm_dt = birth_dt;
			valid_to_dt = "01JAN5999"d;
			output;
		end;

		format VALID_TO_DT VALID_FRM_DT date9.;

		keep VALID_FRM_DT DATA_SRC_CD DATA_LOAD_DT INDV_KEY MARR_TAG VALID_TO_DT DRV_MRTL_STS MARR_1961_TAG BIRTH_DT;
	run;

	/*finally deal with all the muslim marriages here*/
	/*basically, we need to check if the oldest record is an active marriage or not*/
	/* 1) if active marriage, means that the status of the individual will forever be open marriage record.*/
	/* 2) if first record is widowed / divorced marriage, then we need to check if it overlaps with subsequent marriage records or not.*/
	/* 		a) if it does not overlap with subsequent marriage record, then we need to */
	/*		   have a closed marriage record for this particular oldest record, and then start from scratch again*/
	/*		   i.e. the subsequent record will be treated as though its the oldest record and the same checks will be done again */
	/* 3) if first record overlaps with subsequent marriage record, and subsequent marriage record is a widowed / divorced marriage */
	/*		a) if the oldest record has a more recent divorce / widow dt than the subsequent record, it means that the subsequent record */
	/*		   can be considered to be covered by the oldest record, and thus we can ignore the subsequent record */
	/* 		b) if oldest record has a less recent divorce / widow dt than subsequent record, */
	/* 		   it means that we can treat these 2 overlapping records as though its the new oldest widowed / divorced marriage record*/
	/*		   hence we shift the LATEST_DVRCE / WIDOW_DT */
	/*		c) if subsequent record is an active marriage record, then we will take the marr_dt of the oldest record and have an open*/
	/*		   marriage record. this is because the overlapping period ensures that the individual is always married, even though */
	/*		   the oldest record may be a widowed / divorced record */
	proc sql;
		create table muslim_males as
		select *
		from &_input
		where INDV_KEY in (select distinct indv_key from &_input where MARR_1961_TAG in ("Muslim Male", "Male-Multiple Marr"));
	quit;

	proc sort data = muslim_males;
		by INDV_KEY MARR_DT;
	run;

	data muslim_males;
		set muslim_males;
		by INDV_KEY MARR_DT;
		where MARR_TAG ^= "Annulled Marriage";
		length VALID_TO_DT VALID_FRM_DT EARLIEST_MARR_DT LATEST_DVRCE_DT LATEST_WIDOW_DT 8 DRV_MRTL_STS $2 FINAL_OUTPUT_TAG $1;
		retain LATEST_DVRCE_DT EARLIEST_MARR_DT FINAL_OUTPUT_TAG LATEST_WIDOW_DT;

		if first.INDV_KEY and first.MARR_DT then do;
			FINAL_OUTPUT_TAG = "N";
			EARLIEST_MARR_DT = MARR_DT;
			if MARR_TAG = "Divorced Marriage" then do;
				LATEST_DVRCE_DT = DVRCE_DT;
			end;
			else if MARR_TAG = "Widowed" then do;
				LATEST_WIDOW_DT = SPS_DEATH_DT;
			end;
			else if MARR_TAG = "Active Marriage" then do;
				DRV_MRTL_STS = "2";
				VALID_FRM_DT = EARLIEST_MARR_DT;
				VALID_TO_DT = "01JAN5999"d;
				FINAL_OUTPUT_TAG = "Y";
				output;
			end;
		end;

		else if last.INDV_KEY and last.MARR_DT and FINAL_OUTPUT_TAG ^= "Y" then do;
			VALID_FRM_DT = EARLIEST_MARR_DT;
			VALID_TO_DT = "01JAN5999"d;
			DRV_MRTL_STS = "2";
			output;
		end;

		else do;
			if FINAL_OUTPUT_TAG ^= "Y" then do;
				if not missing(LATEST_DVRCE_DT) and not missing(LATEST_WIDOW_DT) then do;
					if coalesce(LATEST_DVRCE_DT, LATEST_WIDOW_DT) >= MARR_DT then do;
						if MARR_TAG = "Divorced Marriage" then do;
							if coalesce(LATEST_DVRCE_DT, LATEST_WIDOW_DT) < DVRCE_DT then do;
								LATEST_DVRCE_DT = DVRCE_DT;
								LATEST_WIDOW_DT = .;
							end;

						end;

						else if MARR_TAG = "Widowed" then do;
							if coalesce(LATEST_DVRCE_DT, LATEST_WIDOW_DT) < SPS_DEATH_DT then do;
								LATEST_WIDOW_DT = SPS_DEATH_DT;
								LATEST_DVRCE_DT = .;
							end;
						end;

					end;

					else if coalesce(LATEST_DVRCE_DT, LATEST_WIDOW_DT) < MARR_DT then do;
						DRV_MRTL_STS = "2";
						VALID_FRM_DT = EARLIEST_MARR_DT;
						VALID_TO_DT = coalesce(LATEST_DVRCE_DT, LATEST_WIDOW_DT);
						output;

						if MARR_TAG = "Active Marriage" then do;
							EARLIEST_MARR_DT = marr_dt;
							LATEST_DVRCE_DT = .;
							VALID_FRM_DT = EARLIEST_MARR_DT;
							VALID_TO_DT = "01JAN5999"d;
							FINAL_OUTPUT_TAG = "Y";
							output;
						end;

						else if MARR_TAG = "Divorced Marriage" then do;
							DRV_MRTL_STS = "5";
							VALID_FRM_DT = EARLIEST_MARR_DT;
							VALID_TO_DT = MARR_DT;
							EARLIEST_MARR_DT = marr_dt;
							LATEST_DVRCE_DT = dvrce_dt;
							LATEST_WIDOW_DT = .;
							output;
						end;

						else if MARR_TAG = "Widowed" then do;
							DRV_MRTL_STS = "3";
							VALID_FRM_DT = EARLIEST_MARR_DT;
							VALID_TO_DT = MARR_DT;
							EARLIEST_MARR_DT = marr_dt;
							LATEST_WIDOW_DT = SPS_DEATH_DT;
							LATEST_DVRCE_DT = .;
						end;
					end;
				end;
			end;
		end;

		format VALID_TO_DT VALID_FRM_DT LATEST_DVRCE_DT EARLIEST_MARR_DT LATEST_WIDOW_DT date9.;

		keep VALID_FRM_DT DATA_SRC_CD DATA_LOAD_DT INDV_KEY MARR_TAG VALID_TO_DT DRV_MRTL_STS MARR_1961_TAG BIRTH_DT;
	run;

	/*here we combine all the generated datasets because we want to generate Single drv mrtl sts for all of them*/
	data combined_data;
		set end_subsisting_marr split_data muslim_males;
	run;

	proc sort data=combined_data;
		by indv_key valid_frm_dt;
	run;

	data get_single_sts;
		set combined_data;
		by indv_key valid_frm_dt;
		if first.indv_key and first.valid_frm_dt and marr_tag ^= "Single" then do;
			DRV_MRTL_STS = "1";
			MARR_TAG = "Single";
			VALID_TO_DT = VALID_FRM_DT;
			VALID_FRM_DT = birth_dt;
			output;
		end;
	run;

	data combined_data;
		set get_single_sts combined_data;
	run;

	/*on top of that, some of the civil marriage individuals may have remarried and thus multiple divorces / widows*/
	/*hence we need to order them and close off the older divorce/widow record. i.e. drv_mrtl_sts: 1 -> 2 -> 5 -> 2 -> 3 etc. */
	proc sort data=combined_data;
		by indv_key descending valid_frm_dt;
	run;

	data close_multiple_entries(drop=prev_valid_frm);
		set combined_data;
		by indv_key descending valid_frm_dt;
		length prev_valid_frm 8;
		retain prev_valid_frm;
		format prev_valid_frm date9.;

		if first.indv_key and first.valid_frm_dt then do;
			prev_valid_frm = valid_frm_dt;
		end;

		else do;
			if valid_to_dt = "01JAN5999"d then do;
				if DRV_MRTL_STS = "2" then valid_to_dt = prev_valid_frm;
				else valid_to_dt = prev_valid_frm;
			end;
			prev_valid_frm = valid_frm_dt;
		end;
	run;

	/*here we extract all the individuals who only have annulled records, and generate Single marital statuses for them.*/
	proc sql;
		create table single_annulled as
		select b.indv_key, "1" as drv_mrtl_sts, b.birth_dt as valid_frm_dt, "01JAN5999"d as valid_to_dt, b.marr_tag, b.data_load_dt,
				b.data_src_cd, b.MARR_1961_tag
		from (
			select indv_key, count(*) as count
			from &_input
			group by indv_key) as a
		inner join (
			select indv_key, marr_tag, birth_dt, data_load_dt, data_src_cd, MARR_1961_tag
			from &_input
			where marr_tag = "Annulled Marriage") as b
		on a.indv_key = b.indv_key
		where a.count = 1;
	quit;

	data final_output;
		set close_multiple_entries single_annulled;
	run;

	proc sort data=final_output out=&_output nodupkeys;
		by INDV_KEY DRV_MRTL_STS VALID_FRM_DT VALID_TO_DT;
	run;
%mend;
