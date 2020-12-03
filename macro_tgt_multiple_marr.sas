/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_tgt_multiple_marr.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: <YYYY-MM-DD>
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<2020-07-14>		<Yee Seng>			<YS-200714>				<Added handling for subsisting marr>
<2020-08-18>		<Yee Seng>			<YS-200818>				<Added filtering to remove gender_cd=F>
<2020-11-20>		<Yee Seng>			<YS-201120>				<Added datetime format to valid_to_dt / valid_frm_dt>

**************************************************************************************************/

%macro multiple_marr;
	proc sort data=&_input out=muslim_males;
		by indv_key valid_frm_dt;
/* 		where gndr_cd = "M"; */
	run;

/* 	data females;
		set &_input;
		where gndr_cd ^= "M";
	run; */

	data get_count;
		set muslim_males;
		by indv_key valid_frm_dt;
		length counter 8 prev_drv_mrtl_sts $2 prev_tag $20;
		retain counter prev_drv_mrtl_sts prev_tag;
		if first.indv_key and first.valid_frm_dt then do;
			counter = 1;
			prev_drv_mrtl_sts = drv_mrtl_sts;
			prev_tag = marr_1961_tag;
		end;

		else do;
			if prev_drv_mrtl_sts = drv_mrtl_sts and (marr_1961_tag ^= prev_tag or marr_1961_tag = "") then do; /*YS-200714*/
				counter = counter + 1;
			end;
			else do;
				counter = 1;
			end;

			prev_drv_mrtl_sts = drv_mrtl_sts;
			prev_tag = marr_1961_tag;
		end;
		drop prev_drv_mrtl_sts prev_tag;
	run;

	proc sort data=get_count out=get_count;
		by indv_key descending valid_frm_dt;	
	run;

	data get_count;
		set get_count;
		by indv_key descending valid_frm_dt;
		length prev_drv_mrtl_sts $2 max_counter final_counter 8 prev_tag $20;
		retain prev_drv_mrtl_sts max_counter final_counter prev_tag;
		
		if first.indv_key and first.valid_frm_dt then do;
			max_counter = counter;
			final_counter = counter;
			prev_drv_mrtl_sts = drv_mrtl_sts;
			prev_tag = marr_1961_tag;
		end;

		else do;
			if prev_drv_mrtl_sts = drv_mrtl_sts and (marr_1961_tag ^= prev_tag or marr_1961_tag = "") then do; /*YS-200714*/
				final_counter = max_counter;
				prev_tag = marr_1961_tag;
			end;

			else do;
				prev_drv_mrtl_sts = drv_mrtl_sts;
				max_counter = counter;
				final_counter = max_counter;
				prev_tag = marr_1961_tag;
			end;
		end;
		drop max_counter prev_drv_mrtl_sts prev_tag;
	run;

	proc sort data=get_count out=sorted2;
		by indv_key valid_frm_dt;
	run;

	data &_output;
		set sorted2;
		by indv_key valid_frm_dt;
		length prev_drv_mrtl_sts final_output_tag $2 prev_valid_to_dt prev_valid_frm_dt 8 prev_tag $20;
		retain prev_valid_to_dt prev_drv_mrtl_sts prev_valid_frm_dt final_output_tag prev_tag;
		if first.indv_key and first.valid_frm_dt then do;
			prev_drv_mrtl_sts = drv_mrtl_sts;
			prev_valid_frm_dt = valid_frm_dt;
			prev_valid_to_dt = valid_to_dt;
			prev_tag = marr_1961_tag;
			output;
			final_output_tag = "N";
		end;

		else do;
			if prev_drv_mrtl_sts = drv_mrtl_sts and (marr_1961_tag ^= prev_tag or marr_1961_tag = "") then do; /*YS-200714*/
				if valid_to_dt > prev_valid_to_dt then prev_valid_to_dt = valid_to_dt;
				if counter = final_counter then do;
					valid_frm_dt = prev_valid_frm_dt;
					valid_to_dt = prev_valid_to_dt;
					temp_tag = marr_1961_tag;
					marr_1961_tag = prev_tag;
					prev_tag = temp_tag;
					output;
					if valid_to_dt ^= "01JAN5999 00:00:000.00"dt then prev_valid_frm_dt = valid_to_dt; /*YS-201120*/

					if drv_mrtl_sts = "2" and valid_to_dt = "01JAN5999 00:00:000.00"dt and gndr_cd = "M" and (reg_cd = "M" or (reg_cd ^= "M" and year(datepart(marr_dt)) < 1961)) then final_output_tag = "Y";
				end;
				else prev_tag = marr_1961_tag;
			end;
			else do;
				if final_output_tag = "N" then do;
					prev_drv_mrtl_sts = drv_mrtl_sts;
					prev_valid_to_dt = valid_to_dt;
					prev_tag = marr_1961_tag;

					if prev_valid_frm_dt > valid_frm_dt then valid_frm_dt = prev_valid_frm_dt;

					prev_valid_frm_dt = valid_frm_dt;
					if counter = final_counter then output;
				end;
			end;
		end;
		drop counter final_counter prev_drv_mrtl_sts final_output_tag prev_valid_frm_dt prev_valid_to_dt prev_tag temp_tag;
	run;

/* 	data &_output;
		set final_males females;
	run; */

%mend;