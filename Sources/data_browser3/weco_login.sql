/*
Copyright 2016 Dirk Strack

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-- Required privileges:
GRANT EXECUTE ON SYS.UTL_TCP TO OWNER;
GRANT EXECUTE ON SYS.UTL_SMTP TO OWNER;

-- uninstall
DROP PACCKAGE weco_login;


select weco_auth.Get_Admin_Workspace_Name Admin_Workspace_Name,
	weco_auth.Get_App_Schema_Name App_Schema_Name,
	weco_auth.client_ip_address Client_Ip_Address,
	weco_login.Get_App_Base_URL App_Base_URL,
	weco_login.Get_App_Host_Name App_Host_Name,
	weco_login.Get_App_Domain_Name App_Domain_Name
from dual;

*/

CREATE OR REPLACE PACKAGE weco_login
AUTHID DEFINER -- enable caller to find users (V_CONTEXT_USERS).
AS
	c_Job_Name_Prefix 	CONSTANT VARCHAR2(64) := 'WECO_LOGIN_';
	c_Use_Weco_Mail     CONSTANT BOOLEAN := FALSE;

   	FUNCTION Get_App_Base_URL
   	RETURN VARCHAR2;

   	FUNCTION Get_App_Host_Name
   	RETURN VARCHAR2;

   	FUNCTION Get_App_Domain_Name (
   		p_Host_Name IN VARCHAR2 DEFAULT NULL
   	)
   	RETURN VARCHAR2;

	FUNCTION Custom_VPD_Active
	RETURN BOOLEAN;

	PROCEDURE Guest_New_password (
		p_User_ID				IN NUMBER,
		p_Account_Ablaufdatum 	IN DATE,
		p_App_ID  				IN NUMBER,
		p_Startpage		 		IN NUMBER,
		p_instance_url 			IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex
		p_Host_Name 			IN VARCHAR2 DEFAULT NULL 	-- apex.wecoserv.de
	);

	PROCEDURE Request_New_password (
		p_Name				IN VARCHAR2,
		p_EMail				IN VARCHAR2,
		p_App_ID  			IN NUMBER,
		p_Startpage 		IN NUMBER DEFAULT 303,		-- APP_USERS Account Freischalten
		p_instance_url 		IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex
		p_Host_Name 		IN VARCHAR2 DEFAULT NULL, 	-- data.wegner.de / apex.wecoserv.de
		p_Message			OUT VARCHAR2
	);

	PROCEDURE Use_Account_Token (
		p_Account_Token		IN VARCHAR2,
		p_User_ID			OUT NUMBER
	);

	FUNCTION Get_Unique_Login_Name (
		p_First_Name VARCHAR2,
		p_Last_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	PROCEDURE Split_EMail_Adress (
		p_Email IN VARCHAR2,
		p_Main_Group_Name IN OUT VARCHAR2,
		p_First_Name IN OUT VARCHAR2,
		p_Last_Name IN OUT VARCHAR2,
		p_Login_Name IN OUT VARCHAR2
	);

	PROCEDURE Save_Guest (
		p_Name				IN VARCHAR2,
		p_EMail				IN VARCHAR2,
		p_User_ID			IN NUMBER,
		p_Message			OUT VARCHAR2
	);

	PROCEDURE Account_Info_Mail (
		p_User_ID		IN NUMBER,
		p_Password		IN VARCHAR2,
		p_Account_Token	IN VARCHAR2,
		p_Sender_ID		IN NUMBER DEFAULT NULL,		-- Sender User ID
		p_App_ID  		IN NUMBER,
		p_Startpage		IN NUMBER,
		p_instance_url 	IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex
		p_Host_Name 	IN VARCHAR2 DEFAULT NULL, 	-- apex.wecoserv.de
		p_Workspace 	IN VARCHAR2 DEFAULT NULL,
		p_Mail_Type     IN NUMBER DEFAULT 3			-- 1=Self registration - confirm e-mail address, 2= requests a new password - account credentials, 3=Guests Invitation - confirm e-mail address
	);

	PROCEDURE Load_Job(
		p_Job_Name VARCHAR2,
		p_Comment VARCHAR2,
		p_Sql VARCHAR2,
		p_repeat_interval VARCHAR2 DEFAULT NULL,
		p_Delay_Seconds NUMBER DEFAULT 2
	);

	PROCEDURE Account_Info_Mail_Job (
		p_User_ID		IN NUMBER,
		p_Password		IN VARCHAR2,
		p_Account_Token	IN VARCHAR2,
		p_App_ID		IN NUMBER DEFAULT APEX_APPLICATION.G_FLOW_ID
	);

END weco_login;
/
show errors

-------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY weco_login AS

   	FUNCTION Get_App_Base_URL
   	RETURN VARCHAR2
   	IS
	BEGIN
		if OWA.NUM_CGI_VARS IS NOT NULL then
			RETURN LOWER(OWA_UTIL.get_cgi_env ('REQUEST_PROTOCOL')) || '://'
				|| OWA_UTIL.get_cgi_env ('HTTP_HOST')
				|| OWA_UTIL.get_cgi_env ('SCRIPT_NAME');
		end if;

		RETURN apex_util.host_url('SCRIPT');
	END;

   	FUNCTION Get_App_Host_Name
   	RETURN VARCHAR2
   	IS
   		v_App_Host_Name	VARCHAR2(2000);
	BEGIN
		v_App_Host_Name := apex_util.host_url('NULL');
		if v_App_Host_Name IS NULL and OWA.NUM_CGI_VARS IS NOT NULL then
			v_App_Host_Name := 
				OWA_UTIL.get_cgi_env ('REQUEST_PROTOCOL')
				|| '://'
				|| OWA_UTIL.get_cgi_env ('HTTP_HOST');
		end if;
		RETURN LOWER(v_App_Host_Name);
	END;

	-- Domain Name der Anwendung ohne Protokoll und ohne Pfade --
   	FUNCTION Get_App_Domain_Name(
   		p_Host_Name IN VARCHAR2 DEFAULT NULL
   	)
   	RETURN VARCHAR2
   	IS
   		v_App_Host_Name	VARCHAR2(2000);
   		v_Offset INTEGER;
	BEGIN
		if p_Host_Name IS NOT NULL then
			v_App_Host_Name := p_Host_Name;
		else
			v_App_Host_Name := weco_login.Get_App_Host_Name;
		end if;	
		-- remove protocol
		if INSTR(v_App_Host_Name, '://') > 0 then
			v_App_Host_Name := SUBSTR(v_App_Host_Name, INSTR(v_App_Host_Name, '://') + 3);
		end if;
		-- remove www.
		if SUBSTR(v_App_Host_Name, 1, 4) = 'www.' then
			v_App_Host_Name := SUBSTR(v_App_Host_Name, 5);
		end if;
		-- remove page parameter
		v_Offset := INSTR(v_App_Host_Name, ':');
		if v_Offset > 0 then
			v_App_Host_Name := SUBSTR(v_App_Host_Name, 1, v_Offset - 1);
		end if;
		-- remove call parameter
		v_Offset := INSTR(v_App_Host_Name, '/');
		if v_Offset > 0 then
			v_App_Host_Name := SUBSTR(v_App_Host_Name, 1, v_Offset - 1);
		end if;
		-- find domain extension 
		-- initcap except extension
		v_Offset := INSTR(v_App_Host_Name, '.', -1);
		if v_Offset > 0 then
			v_App_Host_Name :=
				INITCAP(SUBSTR(v_App_Host_Name, 1, v_Offset))
				|| SUBSTR(v_App_Host_Name, v_Offset + 1);
		else
			v_App_Host_Name := INITCAP(v_App_Host_Name);
		end if;
		RETURN v_App_Host_Name;
	END;

	FUNCTION Custom_VPD_Active
	RETURN BOOLEAN
	IS
		l_num pls_integer;
	BEGIN
		SELECT 1
		INTO l_num
		FROM USER_NAMESPACES WHERE WORKSPACE_NAME != SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
		AND ROWNUM < 2;
		RETURN TRUE;
	exception
	  when NO_DATA_FOUND then
		RETURN FALSE;
	END;

	---------------------------------------------------------------------------

	PROCEDURE Guest_New_password (
		p_User_ID				IN NUMBER,
		p_Account_Ablaufdatum 	IN DATE,
		p_App_ID  				IN NUMBER,
		p_Startpage		 		IN NUMBER,
		p_instance_url 			IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex
		p_Host_Name 			IN VARCHAR2 DEFAULT NULL 	-- apex.wecoserv.de
	)
	IS
	    v_count1        NUMBER 		:= 0;
    	v_count2        NUMBER 		:= 0;
		v_Password      VARCHAR2(128);
		v_Token         VARCHAR2(128);
    	v_Workspace     VARCHAR2(50);
    	v_Apex_Workspace VARCHAR2(255);
    	v_Mail_type     pls_integer;
    	v_Sender_ID 	NUMBER;
	BEGIN
       	v_Workspace := case when weco_login.Custom_VPD_Active then SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME') else NULL end;
		v_Password := weco_auth.Temporary_Password();

		SELECT case when EMAIL_VALIDATED = 'N' then dbms_random.string('X',32) end TOKEN,
			case when EMAIL_VALIDATED = 'N' then 3 else 2 end -- 2= requests a new password - account credentials, 3=Guests Invitation - confirm e-mail address
		INTO v_Token, v_Mail_type
		FROM V_CONTEXT_USERS
		WHERE USER_ID = p_User_ID FOR UPDATE;

		UPDATE V_CONTEXT_USERS
		SET PASSWORD_RESET = 'Y',
			PASSWORD_HASH = weco_auth.hex_hash(p_User_ID, v_Password),
			ACCOUNT_EXPIRATION_DATE = p_Account_Ablaufdatum,
		    EMAIL_VALIATION_TOKEN = case when EMAIL_VALIDATED = 'N' then weco_auth.hex_hash(p_User_ID, v_Token) end
		WHERE USER_ID = p_User_ID;
		COMMIT;

		select WORKSPACE
		  into v_Apex_Workspace
		from APEX_APPLICATIONS
		where APPLICATION_ID = p_App_ID;
		v_Sender_ID := SYS_CONTEXT('CUSTOM_CTX', 'USER_ID');
		weco_login.Account_Info_Mail (
			p_User_ID				=> p_User_ID,
			p_Password 				=> v_Password,
			p_Account_Token			=> v_Token,
			p_Sender_ID				=> v_Sender_ID,
			p_App_ID  				=> p_App_ID,
			p_Startpage		 		=> p_Startpage,
			p_instance_url 			=> p_instance_url,
			p_Host_Name 			=> p_Host_Name,
			p_Workspace				=> v_Workspace,
			p_Mail_Type				=> v_Mail_type
		);
		COMMIT;
	END;

	PROCEDURE Request_New_password (
		p_Name					IN VARCHAR2,
		p_EMail					IN VARCHAR2,
		p_App_ID  				IN NUMBER,
		p_Startpage 			IN NUMBER DEFAULT 303,		-- APP_USERS Account Freischalten
		p_instance_url 			IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex
		p_Host_Name 			IN VARCHAR2 DEFAULT NULL, 	-- data.wegner.de / apex.wecoserv.de
		p_Message				OUT VARCHAR2
	)
	is
		v_User_ID    NUMBER;
		v_Name          VARCHAR2(50);
		begin
			p_Message := NULL;
			begin
				SELECT USER_ID
				INTO v_User_ID
				FROM V_CONTEXT_USERS
				WHERE UPPER(EMAIL_ADDRESS) = UPPER(TRIM(p_EMail))
				AND UPPER_LOGIN_NAME = UPPER(TRIM(p_Name));
			exception
			  when NO_DATA_FOUND then
			COMMIT;
$IF data_browser_specs.g_use_dbms_lock $THEN
			SYS.DBMS_LOCK.SLEEP (1);
$END
			p_Message := APEX_LANG.LANG('No matching data found.');
			return;
		end;

		weco_login.Guest_New_password (
			p_User_ID				=> v_User_ID,
			p_Account_Ablaufdatum 	=> SYSDATE+2,
			p_App_ID  				=> p_App_ID,
			p_Startpage		 		=> p_Startpage,
			p_instance_url 			=> p_instance_url,
			p_Host_Name 			=> p_Host_Name
		);

		COMMIT;
		RETURN;
	EXCEPTION
	  when others then
	  	COMMIT;
$IF data_browser_specs.g_use_dbms_lock $THEN
		SYS.DBMS_LOCK.SLEEP (1);
$END
		p_Message := APEX_LANG.LANG('The service is currently not available.');
	end;

	-- when the passed token is valid, the user_id is returned
	PROCEDURE Use_Account_Token (
		p_Account_Token		IN VARCHAR2,
		p_User_ID			OUT NUMBER
	)
	IS
		v_User_ID	NUMBER := NULL;
	BEGIN
		p_User_ID := NULL;

		SELECT USER_ID
		INTO v_User_ID
		FROM V_CONTEXT_USERS
		WHERE EMAIL_VALIATION_TOKEN = weco_auth.hex_hash(USER_ID, p_account_token)
		AND USER_LEVEL < 6
		AND (TRUNC(ACCOUNT_EXPIRATION_DATE) >= TRUNC(SYSDATE) OR ACCOUNT_EXPIRATION_DATE IS NULL)
		FOR UPDATE OF EMAIL_VALIATION_TOKEN;

		UPDATE V_CONTEXT_USERS
		SET EMAIL_VALIATION_TOKEN = NULL,
			LAST_LOGIN_DATE = SYSDATE,
			EMAIL_VALIDATED = 'Y',
			ACCOUNT_EXPIRATION_DATE = NULL,
			ACCOUNT_LOCKED = 'N'
		WHERE USER_ID = v_User_ID;

		p_User_ID	:= v_User_ID;
		COMMIT;
	EXCEPTION
	  when NO_DATA_FOUND then
		NULL;
	  when others then
$IF data_browser_specs.g_use_dbms_lock $THEN
		SYS.DBMS_LOCK.SLEEP (1);
$END
		RAISE;
	END;

	FUNCTION Get_Unique_Login_Name (
		p_First_Name VARCHAR2,
		p_Last_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2 
	IS 
		v_Count  	PLS_INTEGER;
		v_Extension	PLS_INTEGER;
		v_Login_Name APP_USERS.LOGIN_NAME%TYPE;
	BEGIN
		v_Login_Name := TRIM('.' FROM TRIM(p_First_Name) || '.' || TRIM(p_Last_Name));
		v_Login_Name := NVL(v_Login_Name, apex_lang.lang('Guest'));
		SELECT COUNT(*) INTO v_Count FROM V_CONTEXT_USERS WHERE UPPER_LOGIN_NAME LIKE UPPER(v_Login_Name) || '-' || '%';
		if v_Count > 0 then
			v_Extension := v_Count;
			loop 
				SELECT COUNT(*) INTO v_Count FROM V_CONTEXT_USERS WHERE UPPER_LOGIN_NAME = UPPER(v_Login_Name) || '-' || v_Extension;
				exit when v_Count = 0;
				v_Extension := v_Extension + 1;
			end loop;
			v_Login_Name := v_Login_Name || '-' || v_Extension;
		end if;
	
		RETURN v_Login_Name;
	END Get_Unique_Login_Name;
	
	PROCEDURE Split_EMail_Adress (
		p_Email IN VARCHAR2,
		p_Main_Group_Name IN OUT VARCHAR2,
		p_First_Name IN OUT VARCHAR2,
		p_Last_Name IN OUT VARCHAR2,
		p_Login_Name IN OUT VARCHAR2
	)
	IS
		v_Max_Length CONSTANT PLS_INTEGER := 50;
		v_Name_From APP_USERS.EMAIL_ADDRESS%TYPE;
		v_Main_Group_Name APP_USERS.MAIN_GROUP_NAME%TYPE;
		v_First_Name APP_USERS.FIRST_NAME%TYPE;
		v_Last_Name APP_USERS.LAST_NAME%TYPE;
	BEGIN
		v_Main_Group_Name := LOWER(TRIM(SUBSTR(p_Email, INSTR(p_Email, '@') + 1, v_Max_Length)));
		p_Main_Group_Name := NVL(p_Main_Group_Name, v_Main_Group_Name);
		v_Name_From := SUBSTR(p_Email, 1, INSTR(p_Email, '@') - 1);
		if INSTR(v_Name_From, '.') > 0 then 
			v_First_Name := TRIM(SUBSTR(v_Name_From, 1, LEAST(INSTR(v_Name_From, '.') - 1, v_Max_Length)));
			v_Last_Name := TRIM(SUBSTR(v_Name_From, INSTR(v_Name_From, '.') + 1, v_Max_Length));
		else 
			v_First_Name := NULL;
			v_Last_Name := TRIM(SUBSTR(v_Name_From, 1, v_Max_Length));
		end if;
		if p_First_Name IS NULL and p_Last_Name IS NULL then 
			p_First_Name := v_First_Name;
			p_Last_Name := v_Last_Name;
		end if;
		if p_Login_Name IS NULL then
			p_Login_Name := weco_login.Get_Unique_Login_Name(p_First_Name, p_Last_Name);
		else 
			p_Login_Name := weco_login.Get_Unique_Login_Name(p_Login_Name);
		end if;
	END Split_EMail_Adress;
	
	PROCEDURE Save_Guest (
		p_Name					IN VARCHAR2,
		p_EMail					IN VARCHAR2,
		p_User_ID				IN NUMBER,
		p_Message				OUT VARCHAR2
	)
	IS
	    v_count1        NUMBER := 0;
    	v_count2        NUMBER := 0;
	BEGIN
	    p_Message := NULL;

        SELECT COUNT(*)
        INTO v_count1
        FROM V_CONTEXT_USERS
        WHERE UPPER_LOGIN_NAME = UPPER(TRIM(p_Name))
        AND USER_ID <> p_User_ID;

        SELECT COUNT(*)
        INTO v_count2
        FROM V_CONTEXT_USERS
        WHERE UPPER(EMAIL_ADDRESS) = UPPER(TRIM(p_EMail))
        AND USER_ID <> p_User_ID;

        if v_count1 = 0 and v_count2 = 0 then
			UPDATE V_CONTEXT_USERS
			SET LOGIN_NAME = p_Name,
				EMAIL_ADDRESS = p_EMail
			WHERE USER_ID = p_User_ID;
        elsif v_count1 <> 0 then
            p_Message := APEX_LANG.LANG('The name %0 is already in use.', p_Name);
        elsif v_count2 <> 0 then
            p_Message := APEX_LANG.LANG('The email address %0 is already in use.', p_EMail);
        end if;

		COMMIT;
	END;

	/* This procedure is used to sent mails to account owners in various situations
		1. Self Registration - confirm e-mail address
			When the admin name and email address is entered during installation of the application an confirmation mail is sent to the given address.
			the confirmation mail contains a link to confirm the email address.
			When the new user clicks the confirm link, he is directed to the web site and is requested to enter a new password for his account.
		2. An registered user requests a new password
			In this case a mail with new account credentials is sent to the user. The Mail contains a Link to the home page.
			When the user enters the temporary password, he is requested to change his password.
		3. Guests Invitation:
			Triggered by inserting of rows in App_users by an admin user.
			In this case a invitation mail is sent. the invitation mail contains a link to confirm the email address.
			When the new user clicks the confirm link, he is directed to the web site and is requested to enter a new password for his account.
	*/
	PROCEDURE Account_Info_Mail (
		p_User_ID		IN NUMBER,
		p_Password		IN VARCHAR2,
		p_Account_Token	IN VARCHAR2,
		p_Sender_ID		IN NUMBER DEFAULT NULL,		-- Sender User ID
		p_App_ID  		IN NUMBER,
		p_Startpage		IN NUMBER,
		p_instance_url 	IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex
		p_Host_Name 	IN VARCHAR2 DEFAULT NULL, 	-- apex.wecoserv.de
		p_Workspace 	IN VARCHAR2 DEFAULT NULL,
		p_Mail_Type     IN NUMBER DEFAULT 3			-- 1=Self registration - confirm e-mail address, 2= requests a new password - account credentials, 3=Guests Invitation - confirm e-mail address
	)
	IS
		user_cur 	SYS_REFCURSOR;
		stat_cur 	SYS_REFCURSOR;
		v_newline	VARCHAR2(10) := '<br />' || UTL_TCP.CRLF;
		v_cr		VARCHAR2(10) := ' ' || UTL_TCP.CRLF;
		v_textline 	VARCHAR2(4000);
		v_Mail_To 	VARCHAR2(400);
		v_body 		CLOB;
		v_body_html CLOB;
		v_ErrorMessage  VARCHAR2(1024);
		v_Privileges  VARCHAR2(4000);
		v_AccountName VARCHAR2(50);
		v_Subject VARCHAR2(200);
		v_Workspace_Name VARCHAR2(200);
		v_Name_To VARCHAR2(100);
		v_Mail_From VARCHAR2(100);
		v_Name_From VARCHAR2(100);
		v_AccountInfos VARCHAR2(4000);
		v_Account_Expiration_Date DATE;
		v_Date_Format   VARCHAR2(20) :='DD-Mon-YYYY';
    	v_Language_Code V_CONTEXT_USERS.LANGUAGE_CODE%TYPE;
		v_instance_url 	VARCHAR2(1024);
		v_host_name 	VARCHAR2(1024) := NVL(p_host_name, weco_login.Get_App_Host_Name);
		v_domain_name   VARCHAR2(1024) := weco_login.Get_App_Domain_Name(p_host_name);
		v_confirm_url   VARCHAR2(1024);
		v_Mail_Footer	VARCHAR2(4000);
		v_conn 			utl_smtp.connection;
	BEGIN
		if p_User_ID IS NULL or p_App_ID IS NULL then 
			return;
		end if;
		-- call set_security_group_id to enable access to translation repository
		for c1 in (
			select workspace_id, application_name
			from apex_applications
			where application_id = p_App_ID )
		loop
			apex_util.set_security_group_id(p_security_group_id => c1.workspace_id);
			v_Name_From := c1.application_name;
		end loop;

		SELECT LOGIN_NAME, LAST_NAME, EMAIL_ADDRESS, ACCOUNT_EXPIRATION_DATE, LANGUAGE_CODE,
			(SELECT APEX_LANG.LANG (
					p_primary_text_string => S.DESCRIPTION || ' - ' || S.REMARKS,
					p_primary_language => B.LANGUAGE_CODE)
				FROM APP_USER_LEVELS S
				WHERE S.ID = B.USER_LEVEL
			) PRIVS
		INTO v_AccountName, v_Name_To, v_Mail_To, v_Account_Expiration_Date, v_Language_Code, v_Privileges
		FROM V_CONTEXT_USERS B
		WHERE USER_ID = p_User_ID
		;
		if p_Sender_ID IS NOT NULL then
			SELECT NVL(TRIM(B.FIRST_NAME || ' ' || B.LAST_NAME), B.LOGIN_NAME) NAME_FROM
			INTO v_Name_From
			FROM V_CONTEXT_USERS B
			WHERE B.USER_ID = p_Sender_ID;
		end if;
		begin
			SELECT COALESCE(A.INFOMAIL_FROM, 'info@' || v_domain_name)  EMAIL_ADDRESS,
				A.INFOMAIL_FOOTER
			INTO v_Mail_From, v_Mail_Footer
			FROM APP_PREFERENCES A;
		exception
		  when NO_DATA_FOUND then
			v_Mail_From		:= 'info@' || v_domain_name;
		end;

		v_instance_url := RTRIM(NVL(p_instance_url, weco_login.Get_App_Base_URL), '/ ');
		v_confirm_url  := v_instance_url || '/f?p=' || p_App_ID 
			|| ':' || p_Startpage || ':0::::'
			|| case when p_Workspace IS NOT NULL then 'P' || p_Startpage || '_WORKSPACE_NAME,' end
			|| 'P' || p_Startpage || '_PASSWORD,'
			|| 'P' || p_Startpage || '_TOKEN:'
			|| case when p_Workspace IS NOT NULL then p_Workspace || ',' end
			|| p_Password || ','
			|| p_Account_Token || ':';

		v_body_html := '<html><body>' || v_cr;
		v_Workspace_Name := case when p_Workspace IS NOT NULL
			then apex_lang.lang('The workspace name is') || ' ' || p_Workspace || v_newline
		end;
		if p_Mail_Type = 1 then -- 1=Self registration - confirm e-mail address
			v_Subject := apex_lang.message(
				p_name => 'APP.P101.MAIL_SUBJECT1',
				p0 => v_domain_name,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
			v_AccountInfos :=  apex_lang.message(
				p_name => 'APP.P101.MAIL_BODY1',
				p0 => v_Name_To,
				p1 => v_host_name,
				p2 => v_AccountName,
				p3 => v_confirm_url,
				p4 => NVL(TO_CHAR(v_Account_Expiration_Date, v_Date_Format), '---'),
				p5 => v_instance_url,
				p6 => v_domain_name,
				p7 => v_Mail_Footer,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
		elsif p_Mail_Type = 2 then -- 2=requests a new password - account credentials
			v_instance_url := v_instance_url || '/f?p=' || p_App_ID || ':1:0::::';
			v_Subject := apex_lang.message(
				p_name => 'APP.P101.MAIL_SUBJECT2',
				p0 => v_domain_name,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
			v_AccountInfos :=  apex_lang.message(
				p_name => 'APP.P101.MAIL_BODY2',
				p0 => v_Name_To,
				p1 => v_host_name,
				p2 => v_AccountName,
				p3 => p_Password,
				p4 => NVL(TO_CHAR(v_Account_Expiration_Date, v_Date_Format), '---'),
				p5 => v_instance_url,
				p6 => v_domain_name,
				p7 => v_Mail_Footer,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
		elsif p_Mail_Type = 3 then -- 3=Guests Invitation - confirm e-mail address
			v_Subject := apex_lang.message(
				p_name => 'APP.P101.MAIL_SUBJECT3',
				p0 => v_domain_name,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
			v_AccountInfos :=  apex_lang.message(
				p_name => 'APP.P101.MAIL_BODY3',
				p0 => v_host_name,
				p1 => v_Name_From,
				p2 => v_AccountName,
				p3 => p_Password,
				p4 => NVL(TO_CHAR(v_Account_Expiration_Date, v_Date_Format), '---'),
				p5 => v_confirm_url,
				p6 => v_Mail_Footer,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
		end if;
		v_body := REGEXP_REPLACE(REPLACE(v_AccountInfos, v_newline, v_cr), '<[^>]+>', '');
		v_body_html := v_body_html || v_AccountInfos || '</body></html>';
$IF weco_login.c_Use_Weco_Mail $THEN
			weco_mail.send_mail(
				p_to 		=> v_Mail_To,
				p_from 		=> v_Mail_From,
				p_body 		=> v_body,
				p_body_html => v_body_html,
				p_subj 		=> v_Subject,
				p_conn 		=> v_conn,
				p_Message 	=> v_ErrorMessage
			);
			UPDATE V_CONTEXT_USERS 
				SET SEND_MAIL_REPLY_MESSAGE = NVL(SUBSTR(v_ErrorMessage, 1, 1000), 'OK')
			WHERE USER_ID = p_User_ID;
			COMMIT;
$ELSE
			apex_mail.Send (
				p_to 		=> v_Mail_To,
				p_from 		=> v_Mail_From,
				p_body 		=> v_body,
				p_body_html => v_body_html,
				p_subj 		=> v_Subject
			);
			commit;
			apex_mail.push_queue;
$END
	END Account_Info_Mail;

	PROCEDURE Load_Job(
		p_Job_Name VARCHAR2,
		p_Comment VARCHAR2,
		p_Sql VARCHAR2,
		p_repeat_interval VARCHAR2 DEFAULT NULL,
		p_Delay_Seconds NUMBER DEFAULT 2
	)
	IS
		v_Job_Name USER_SCHEDULER_JOBS.JOB_NAME%TYPE;
		v_Job_Name_Prefix USER_SCHEDULER_JOBS.JOB_NAME%TYPE := SUBSTR(c_Job_Name_Prefix || p_Job_Name, 1, 18);
	BEGIN
		v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
		DBMS_OUTPUT.PUT_LINE('weco_login.Load_Job - start ' || v_Job_Name || '; sql: ' || p_Sql);
		dbms_scheduler.create_job(
			job_name => v_Job_Name,
			job_type => 'PLSQL_BLOCK',
			job_action => p_Sql,
			start_date => SYSDATE + (1/24/60/60*p_Delay_Seconds), -- starte in p_Delay_Seconds
			repeat_interval => p_repeat_interval,
			comments => p_Comment,
			enabled => true );
		COMMIT;
	END;

	PROCEDURE Account_Info_Mail_Job (
		p_User_ID		IN NUMBER,
		p_Password		IN VARCHAR2,
		p_Account_Token	IN VARCHAR2,
		p_App_ID		IN NUMBER DEFAULT APEX_APPLICATION.G_FLOW_ID
	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_instance_url 	VARCHAR2(1024);
		v_host_name 	VARCHAR2(1024);
    	v_Workspace     VARCHAR2(50);
    	v_Apex_Workspace VARCHAR2(255);
    	v_sql			VARCHAR2(4000);
    	v_startpage		NUMBER;
    	v_Mail_type     PLS_INTEGER;
    	v_Sender_ID 	NUMBER;
	BEGIN
		if p_App_ID is null then
			return;
		end if;
		if apex_authentication.is_public_user then
			v_Mail_type := 1; -- Self registration
		else
			v_Mail_type := 3; -- Invitation
		end if;
		v_instance_url 	:= weco_login.Get_App_Base_URL;
		v_host_name 	:= weco_login.Get_App_Domain_Name;
       	v_Workspace 	:= case when weco_login.Custom_VPD_Active then SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME') end;
		begin
			select PAGE_ID
			  into v_startpage
			  from APEX_APPLICATION_PAGES
			 where APPLICATION_ID = p_App_ID
			   and PAGE_ALIAS = 'CONFIRM_ACCOUNT_TOKEN';
		exception
		  when NO_DATA_FOUND then
			v_startpage		:= 104;
		end;
		select WORKSPACE
		  into v_Apex_Workspace
		from APEX_APPLICATIONS
		where APPLICATION_ID = p_App_ID;
		v_Sender_ID := SYS_CONTEXT('CUSTOM_CTX', 'USER_ID');
		v_sql :=
        'begin ' || chr(10) ||
        'weco_login.Account_Info_Mail (' || chr(10) ||
        '   p_User_ID       => ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_User_ID) || ', ' || chr(10) ||
        '   p_Password      => ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Password) || ', ' || chr(10) ||
        '   p_Account_Token => ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Account_Token) || ', ' || chr(10) ||
        '   p_Sender_ID     => ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_Sender_ID) || ', ' || chr(10) ||
        '   p_App_ID        => ' || p_App_ID || ', ' || chr(10) ||
        '   p_Startpage     => ' || v_Startpage || ', ' || chr(10) ||
        '   p_instance_url  => ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_instance_url) || ', ' || chr(10) ||
        '   p_Host_Name     => ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_host_name) || ', ' || chr(10) ||
        '   p_Workspace     => ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_Workspace) || ', ' || chr(10) ||
        '   p_Mail_Type     => ' || v_Mail_type || chr(10) ||
        '); end;';
		DBMS_OUTPUT.PUT('v_sql: ');
		DBMS_OUTPUT.PUT(v_sql);
		DBMS_OUTPUT.PUT('-------------------------------------------');
        weco_login.Load_Job (
            p_Job_Name => 'ACCOUNT_MAIL',
            p_Comment => 'Send account info mail for data browser application',
            p_Sql => v_sql
        );
        COMMIT;
	exception
	  when NO_DATA_FOUND then
	  	NULL;
	END Account_Info_Mail_Job;
END weco_login;
/
show errors

CREATE OR REPLACE TRIGGER APP_USERS_PWD_TR
BEFORE INSERT OR UPDATE ON APP_USERS FOR EACH ROW
DECLARE
	v_Password APP_USERS.PASSWORD_HASH%TYPE;
	v_Token    APP_USERS.EMAIL_VALIATION_TOKEN%TYPE;
BEGIN
    if INSERTING then
    	:new.LANGUAGE_CODE := COALESCE(:new.LANGUAGE_CODE, APEX_UTIL.GET_SESSION_LANG, 'de');
    	if :new.PASSWORD_HASH IS NULL then
    		:new.PASSWORD_RESET := 'Y';
    		v_Password := weco_auth.Temporary_Password();
			:new.PASSWORD_HASH := weco_auth.hex_hash(:new.ID, v_Password);
    	else
    		v_Password := :new.PASSWORD_HASH;	-- is password may be already hashed by the program.
    		if Weco_Auth.is_hex_key(:new.PASSWORD_HASH) = 0  then
				:new.PASSWORD_HASH := weco_auth.hex_hash(:new.ID, v_Password);
			end if;
    	end if;
		if :new.EMAIL_ADDRESS IS NOT NULL then 
			weco_login.Split_EMail_Adress (
				p_Email => :new.EMAIL_ADDRESS,
				p_Main_Group_Name => :new.MAIN_GROUP_NAME,
				p_First_Name => :new.FIRST_NAME,
				p_Last_Name => :new.LAST_NAME,
				p_Login_Name => :new.LOGIN_NAME
			);
			if :new.PASSWORD_RESET = 'Y' then 
				:new.ACCOUNT_EXPIRATION_DATE := NVL(:new.ACCOUNT_EXPIRATION_DATE, SYSDATE+2);
				v_Token := dbms_random.string('X',32);
				:new.EMAIL_VALIATION_TOKEN :=  weco_auth.hex_hash(:new.ID, v_Token);
				weco_auth.log_message('APP_USERS_PWD_TR', 'Account_Info_Mail_Job(' || :new.ID ||', ' || v_Password || ', ' || v_Token|| ', ' || V('APP_ID') || ')' );
				weco_login.Account_Info_Mail_Job(
					p_User_ID		=> :new.ID,
					p_Password		=> v_Password,
					p_Account_Token	=> v_Token,
					p_App_ID => V('APP_ID')
				);
			end if;
		end if;
    elsif UPDATING then
		if :new.PASSWORD_HASH IS NOT NULL AND Weco_Auth.is_hex_key(:new.PASSWORD_HASH) = 0  then
			:new.PASSWORD_HASH := weco_auth.Hex_Hash(:new.ID, :new.PASSWORD_HASH);
		elsif :new.PASSWORD_HASH IS NULL then
			:new.PASSWORD_HASH := :old.PASSWORD_HASH;
		end if;
    end if;
END;
/

/*

-------------------------------------------------------------------------------
set serveroutput on
set pagesize 0
set linesize 32767
begin
	weco_login.Account_Info_Mail_Job(
		p_User_ID		=> 141424135413816554241736902659090143070,
		p_Password		=> 'XXX',
		p_Account_Token	=> 'YYY',
		p_App_ID        => 1003
	);
end;
/


*/
