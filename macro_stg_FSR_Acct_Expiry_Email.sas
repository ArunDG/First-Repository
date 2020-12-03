/**************************************************************************************************
PROJECT: MSF CANVAS

PROGRAM NAME: macro_stg_FSR_Acct_Expiry_Email.sas

PROGRAM DESCRIPTION: <Program Description>


CREATED DATE: 2020-03-11
CREATED BY: NCS PTE LTD.

REVISIONS:
MODIFIED DATE	|	MODIFIED BY		|	MODIFICATION_TAG	|	MODIFICATION REMARKS
<YYYY-MM-DD>		<NAME>				<INITIALS-YYMMDD>		<SHORT DESCRIPTION OF CHANGES>		
**************************************************************************************************/

*Sends an email to users whose FSR Accounts are expiring;


data ctl_acct_expiring_email;
	set &_input;
	keep AD_ACCOUNT Email_Address;
run;

 %macro sendemail(RunDate, EXPIRY_Duration); 
 	/* Send Email to Users with Expiring Accounts */
 	/* 1. Retrieve Email Receipient list from ctl_acct_expiring_email */

	proc sql noprint;
		select trim(AD_ACCOUNT), Email_Address
			into :pTo_Name separated by "; ", :pBCC_list separated by "; "
			from ctl_acct_expiring_email;
	quit;	

	/*2. Specify Email Options*/

	/*Edit emailsys, emailhost and emailport options below*/
	options emailsys = smtp emailhost='smtp-application.tp.edu.sg' emailport=25; 

	filename mailbox EMAIL  Subject = "FSR Account is Expiring on &RunDate";

	/*3. Send Email to All Users with Expiring Accounts*/

	data _null_;
		File Mailbox   bcc  = (&pBCC_list)
					   from = 'DAP<acsadmin@tp.edu.sg.com>'; /*Edit From Email Account*/
		put "Dear user,";
		put " ";
		put "Please be informed that your account will be expiring within &EXPIRY_Duration days.";
		put " ";
		put " ";
		put "Best Regards,";
		put "Sender";
	run;

%mend;



