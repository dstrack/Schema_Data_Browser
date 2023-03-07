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
DROP PACCKAGE data_browser_login;


select data_browser_auth.Get_Admin_Workspace_Name Admin_Workspace_Name,
	data_browser_auth.Get_App_Schema_Name App_Schema_Name,
	data_browser_auth.client_ip_address Client_Ip_Address,
	data_browser_login.Get_App_Base_URL App_Base_URL,
	data_browser_login.Get_App_Host_Name App_Host_Name,
	data_browser_login.Get_App_Domain_Name App_Domain_Name
from dual;

*/

CREATE OR REPLACE PACKAGE data_browser_login
AUTHID DEFINER -- enable caller to find users (V_CONTEXT_USERS).
AS
	c_Job_Name_Prefix 	CONSTANT VARCHAR2(64) := 'DBR_LOGIN_';

   	FUNCTION Get_App_Base_URL
   	RETURN VARCHAR2;

   	FUNCTION Get_App_Host_Name
   	RETURN VARCHAR2;

   	FUNCTION Get_App_Domain_Name (
   		p_Host_Name IN VARCHAR2 DEFAULT NULL
   	)
   	RETURN VARCHAR2;

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
		p_instance_url 	IN VARCHAR2 DEFAULT NULL, 
		p_Host_Name 	IN VARCHAR2 DEFAULT NULL, 
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

END data_browser_login;
/

-------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY data_browser_login AS

   	FUNCTION Get_App_Base_URL
   	RETURN VARCHAR2
   	IS
   		v_result varchar2(32767);
	BEGIN
		v_result := apex_util.host_url('SCRIPT');
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING v_result;
        $END
        return v_result;
	END Get_App_Base_URL;

   	FUNCTION Get_App_Host_Name
   	RETURN VARCHAR2
   	IS
        v_result varchar2(32767);
	BEGIN -- example: https://abc-strack02.adb.eu-frankfurt-1.oraclecloudapps.com/ords/
		v_result := APEX_MAIL.GET_INSTANCE_URL;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING v_result;
        $END
        return v_result;
	END Get_App_Host_Name;

	-- Domain Name der Anwendung ohne Protokoll und ohne Pfade --
   	FUNCTION Get_App_Domain_Name(
   		p_Host_Name IN VARCHAR2 DEFAULT NULL
   	)
   	RETURN VARCHAR2
   	IS
        v_result varchar2(32767);
   		v_Offset INTEGER;
	BEGIN
		if p_Host_Name IS NOT NULL then
			v_result := p_Host_Name;
		else
			v_result := data_browser_login.Get_App_Host_Name;
		end if;	
		-- remove protocol
		if INSTR(v_result, '://') > 0 then
			v_result := SUBSTR(v_result, INSTR(v_result, '://') + 3);
		end if;
		-- remove www.
		if SUBSTR(v_result, 1, 4) = 'www.' then
			v_result := SUBSTR(v_result, 5);
		end if;
		-- remove page parameter
		v_Offset := INSTR(v_result, ':');
		if v_Offset > 0 then
			v_result := SUBSTR(v_result, 1, v_Offset - 1);
		end if;
		-- remove call parameter
		v_Offset := INSTR(v_result, '/');
		if v_Offset > 0 then
			v_result := SUBSTR(v_result, 1, v_Offset - 1);
		end if;
		-- find domain extension 
		-- initcap except extension
		v_Offset := INSTR(v_result, '.', -1);
		if v_Offset > 0 then
			v_result :=
				INITCAP(SUBSTR(v_result, 1, v_Offset))
				|| SUBSTR(v_result, v_Offset + 1);
		else
			v_result := INITCAP(v_result);
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_host_name,v_result;
        $END
        return v_result;
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_host_name;
        RAISE;
	END Get_App_Domain_Name;

	---------------------------------------------------------------------------

	PROCEDURE Guest_New_password (
		p_User_ID				IN NUMBER,
		p_Account_Ablaufdatum 	IN DATE,
		p_App_ID  				IN NUMBER,
		p_Startpage		 		IN NUMBER,
		p_instance_url 			IN VARCHAR2 DEFAULT NULL, 
		p_Host_Name 			IN VARCHAR2 DEFAULT NULL 
	)
	IS
	    v_count1        NUMBER 		:= 0;
    	v_count2        NUMBER 		:= 0;
		v_Password      VARCHAR2(128);
		v_Token         VARCHAR2(128);
    	v_Workspace     VARCHAR2(128);
    	v_Mail_type     pls_integer;
	BEGIN
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_user_id,p_account_ablaufdatum,p_app_id,p_startpage,p_instance_url,p_host_name;
        $END
		v_Password := data_browser_auth.Temporary_Password();

		SELECT case when EMAIL_VALIDATED = 'N' then dbms_random.string('X',32) end TOKEN,
			case when EMAIL_VALIDATED = 'N' then 3 else 2 end MAIL_TYPE, -- 2= requests a new password - account credentials, 3=Guests Invitation - confirm e-mail address
			WORKSPACE_NAME
		INTO v_Token, v_Mail_type, v_Workspace
		FROM VDATA_BROWSER_USERS
		WHERE USER_ID = p_User_ID FOR UPDATE;

		UPDATE V_CONTEXT_USERS
		SET PASSWORD_RESET = 'Y',
			PASSWORD_HASH = data_browser_auth.hex_hash(p_User_ID, v_Password),
			ACCOUNT_EXPIRATION_DATE = p_Account_Ablaufdatum,
		    EMAIL_VALIATION_TOKEN = case when EMAIL_VALIDATED = 'N' then data_browser_auth.hex_hash(p_User_ID, v_Token) end
		WHERE USER_ID = p_User_ID;
		COMMIT;

		data_browser_login.Account_Info_Mail (
			p_User_ID				=> p_User_ID,
			p_Password 				=> v_Password,
			p_Account_Token			=> v_Token,
			p_App_ID  				=> p_App_ID,
			p_Startpage		 		=> p_Startpage,
			p_instance_url 			=> p_instance_url,
			p_Host_Name 			=> p_Host_Name,
			p_Workspace				=> case when data_browser_conf.Has_Multiple_Workspaces = 'YES' then v_Workspace end,
			p_Mail_Type				=> v_Mail_type
		);
		COMMIT;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit;
        $END
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_user_id,p_account_ablaufdatum,p_app_id,p_startpage,p_instance_url,p_host_name;
        RAISE;
	END Guest_New_password;

	PROCEDURE Request_New_password (
		p_Name					IN VARCHAR2,
		p_EMail					IN VARCHAR2,
		p_App_ID  				IN NUMBER,
		p_Startpage 			IN NUMBER DEFAULT 303,	
		p_instance_url 			IN VARCHAR2 DEFAULT NULL, 
		p_Host_Name 			IN VARCHAR2 DEFAULT NULL, 
		p_Message				OUT VARCHAR2
	)
	is
		v_User_ID    NUMBER;
		v_Name          VARCHAR2(50);
	begin
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_name,p_email,p_app_id,p_startpage,p_instance_url,p_host_name;
        $END
		p_Message := NULL;
		begin
			SELECT MAX(USER_ID)
			INTO v_User_ID
			FROM VDATA_BROWSER_USERS
			WHERE UPPER(EMAIL_ADDRESS) = UPPER(TRIM(p_EMail))
			AND UPPER_LOGIN_NAME = UPPER(TRIM(p_Name))
			AND (WORKSPACE_NAME = SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME') 
				OR SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME') IS NULL
				OR data_browser_conf.Has_Multiple_Workspaces = 'NO');
		exception
		  when NO_DATA_FOUND then
			COMMIT;
			APEX_UTIL.PAUSE(1);
			p_Message := APEX_LANG.LANG('No matching data found.');
			return;
		end;

		data_browser_login.Guest_New_password (
			p_User_ID				=> v_User_ID,
			p_Account_Ablaufdatum 	=> SYSDATE+2,
			p_App_ID  				=> p_App_ID,
			p_Startpage		 		=> p_Startpage,
			p_instance_url 			=> p_instance_url,
			p_Host_Name 			=> p_Host_Name
		);
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit
            USING p_message;
        $END
	EXCEPTION
	  when others then
	  	COMMIT;
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_name,p_email,p_app_id,p_startpage,p_instance_url,p_host_name,p_message;
		APEX_UTIL.PAUSE(1);
		p_Message := APEX_LANG.LANG('The service is currently not available.');
	end Request_New_password;

	-- when the passed token is valid, the user_id is returned
	PROCEDURE Use_Account_Token (
		p_Account_Token		IN VARCHAR2,
		p_User_ID			OUT NUMBER
	)
	IS
		v_User_ID	NUMBER := NULL;
	BEGIN
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_account_token;
        $END
		p_User_ID := NULL;

		SELECT USER_ID
		INTO v_User_ID
		FROM V_CONTEXT_USERS
		WHERE EMAIL_VALIATION_TOKEN = data_browser_auth.hex_hash(USER_ID, p_account_token)
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
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit
            USING p_user_id;
        $END
	EXCEPTION
	  when NO_DATA_FOUND then
		NULL;
	  when others then
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_account_token,p_user_id;
		APEX_UTIL.PAUSE(1);
		RAISE;
	END Use_Account_Token;

	FUNCTION Get_Unique_Login_Name (
		p_First_Name VARCHAR2,
		p_Last_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2 
	IS 
		v_Count  	PLS_INTEGER;
		v_Extension	PLS_INTEGER;
        v_result varchar2(32767);
	BEGIN
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_first_name,p_last_name;
        $END
		v_result := TRIM('.' FROM TRIM(p_First_Name) || '.' || TRIM(p_Last_Name));
		v_result := NVL(v_result, apex_lang.lang('Guest'));
		SELECT COUNT(*) INTO v_Count FROM VDATA_BROWSER_USERS WHERE UPPER_LOGIN_NAME LIKE UPPER(v_result) || '-' || '%';
		if v_Count > 0 then
			v_Extension := v_Count;
			loop 
				SELECT COUNT(*) INTO v_Count FROM VDATA_BROWSER_USERS WHERE UPPER_LOGIN_NAME = UPPER(v_result) || '-' || v_Extension;
				exit when v_Count = 0;
				v_Extension := v_Extension + 1;
			end loop;
			v_result := v_result || '-' || v_Extension;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING v_result;
        $END
        return v_result;
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_first_name,p_last_name;
        RAISE;
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
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_email;
        $END
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
			p_Login_Name := TRIM('.' FROM TRIM(p_First_Name) || '.' || TRIM(p_Last_Name));
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit
            USING p_main_group_name,p_first_name,p_last_name,p_login_name;
        $END
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_email,p_main_group_name,p_first_name,p_last_name,p_login_name;
        RAISE;
    end split_email_adress;
	
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
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_name,p_email,p_user_id;
        $END
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
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit
            USING p_message;
        $END
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_name,p_email,p_user_id,p_message;
        RAISE;
	END Save_Guest;

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
		p_instance_url 	IN VARCHAR2 DEFAULT NULL, 	-- https://apex.wecoserv.de/apex -- is used to construct a link to the p_Startpage
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
		v_Subject VARCHAR2(2000);
		v_Workspace_Name VARCHAR2(200);
		v_Name_To VARCHAR2(100);
		v_Mail_From VARCHAR2(100);
		v_Name_From VARCHAR2(100);
		v_AccountInfos VARCHAR2(4000);
		v_Account_Expiration_Date DATE;
		v_Date_Format   VARCHAR2(20) :='DD-Mon-YYYY';
    	v_Language_Code V_CONTEXT_USERS.LANGUAGE_CODE%TYPE;
		v_instance_url 	VARCHAR2(1024);
		v_home_url 		VARCHAR2(1024);
		v_host_name 	VARCHAR2(1024); 
		v_App_Name_Subject VARCHAR2(1024);
		v_confirm_url   VARCHAR2(1024);
		v_Mail_Footer	VARCHAR2(4000);
		v_conn 			utl_smtp.connection;
	BEGIN
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_user_id,p_password,p_account_token,p_sender_id,p_app_id,p_startpage,p_instance_url,p_host_name,p_workspace,p_mail_type;
        $END
		if p_User_ID IS NULL or p_App_ID IS NULL then 
			return;
		end if;
		v_App_Name_Subject := data_browser_conf.Get_Configuration_Name;
		v_App_Name_Subject := data_browser_conf.Get_Configuration_Name;
		v_host_name := NVL(p_host_name, data_browser_login.Get_App_Host_Name) 
		|| 'f?p=' || p_App_ID || ':LOGIN_DESKTOP'; 
		-- call set_security_group_id to enable access to translation repository
		for c1 in (
			select workspace_id
			from apex_applications
			where application_id = p_App_ID )
		loop
			apex_util.set_security_group_id(p_security_group_id => c1.workspace_id);
		end loop;
		$IF data_browser_specs.g_use_custom_ctx $THEN
			set_custom_ctx.set_current_workspace(p_Workspace_Name=>NVL(p_Workspace, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')), p_Client_Id=>NULL);
			set_custom_ctx.set_current_user(p_User_Name=>SYS_CONTEXT('USERENV', 'SESSION_USER'), p_Client_Id=>NULL);
		$END
		SELECT LOGIN_NAME, NVL(TRIM(FIRST_NAME || ' ' ||  LAST_NAME), LOGIN_NAME) NAME_TO, 
			EMAIL_ADDRESS, ACCOUNT_EXPIRATION_DATE, LANGUAGE_CODE,
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
			SELECT NVL(TRIM(FIRST_NAME || ' ' ||  LAST_NAME), LOGIN_NAME) NAME_FROM
			INTO v_Name_From
			FROM V_CONTEXT_USERS B
			WHERE B.USER_ID = p_Sender_ID;
		else 
			v_Name_From := data_browser_conf.Get_Configuration_Name;
		end if;
		v_Mail_From := data_browser_conf.Get_Email_From_Address;
		
		SELECT DESCRIPTION 
		INTO v_Mail_Footer
		FROM DATA_BROWSER_CONFIG
		WHERE ID = data_browser_conf.Get_Configuration_ID;
		if v_Mail_Footer IS NOT NULL then 
			v_Mail_Footer := '<br />------------<br />'||v_Mail_Footer;
		end if;
		
		v_instance_url := RTRIM(NVL(p_instance_url, data_browser_login.Get_App_Base_URL), '/ ');
		v_confirm_url  := v_instance_url || '/f?p=' || p_App_ID 
			|| ':' || p_Startpage || ':0::::'
			|| case when p_Workspace IS NOT NULL then 'P' || p_Startpage || '_WORKSPACE_NAME,' end
			|| 'P' || p_Startpage || '_PASSWORD,'
			|| 'P' || p_Startpage || '_TOKEN:'
			|| case when p_Workspace IS NOT NULL then p_Workspace || ',' end
			|| p_Password || ','
			|| p_Account_Token || ':';
		v_home_url := v_instance_url || '/f?p=' || p_App_ID || ':1:0::::';
		if p_Workspace IS NOT NULL then 
			v_home_url := v_home_url || 'LOGIN_WORKSPACE:' || p_Workspace;
		end if;

		v_body_html := '<html><body>' || v_cr;
		if p_Mail_Type = 1 then -- 1=Self registration - confirm e-mail address
			v_Subject := apex_lang.message(
				p_name => 'APP.P101.MAIL_SUBJECT1',
				p0 => v_App_Name_Subject,
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
				p5 => v_home_url,
				p6 => v_App_Name_Subject,
				p7 => v_Mail_Footer,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
		elsif p_Mail_Type = 2 then -- 2=requests a new password - account credentials
			v_Subject := apex_lang.message(
				p_name => 'APP.P101.MAIL_SUBJECT2',
				p0 => v_App_Name_Subject,
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
				p5 => v_home_url,
				p6 => v_App_Name_Subject,
				p7 => v_Mail_Footer,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
		elsif p_Mail_Type = 3 then -- 3=Guests Invitation - confirm e-mail address
			v_Subject := apex_lang.message(
				p_name => 'APP.P101.MAIL_SUBJECT3',
				p0 => v_App_Name_Subject,
				p_lang => v_Language_Code,
				p_application_id => p_App_ID
			);
			if p_Workspace IS NOT NULL then 
				v_host_name := v_host_name || ':0::::LOGIN_WORKSPACE:' || p_Workspace;
			end if;
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
		apex_mail.Send (
			p_to 		=> v_Mail_To,
			p_from 		=> v_Mail_From,
			p_body 		=> v_body,
			p_body_html => v_body_html,
			p_subj 		=> v_Subject
		);
		commit;
		apex_mail.push_queue;
		DBMS_OUTPUT.PUT_LINE('data_browser_login.Account_Info_Mail(p_from:'||v_Mail_From||', Mail_To:'||v_Mail_To||') - completed ');
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit;
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
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_job_name,p_comment,p_sql,p_repeat_interval,p_delay_seconds;
        $END
		v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
		DBMS_OUTPUT.PUT_LINE('data_browser_login.Load_Job - start ' || v_Job_Name || '; sql: ' || p_Sql);
		dbms_scheduler.create_job(
			job_name => v_Job_Name,
			job_type => 'PLSQL_BLOCK',
			job_action => p_Sql,
			start_date => SYSDATE + (1/24/60/60*p_Delay_Seconds), -- starte in p_Delay_Seconds
			repeat_interval => p_repeat_interval,
			comments => p_Comment,
			enabled => true );
		COMMIT;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit;
        $END
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_job_name,p_comment,p_sql,p_repeat_interval,p_delay_seconds;
        RAISE;
	END Load_Job;

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
    	v_sql			VARCHAR2(4000);
    	v_startpage		NUMBER;
    	v_Mail_type     PLS_INTEGER;
    	v_Sender_ID 	NUMBER;
	BEGIN
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Start
            USING p_user_id,p_password,p_account_token,p_app_id;
        $END
		if p_App_ID is null then
			return;
		end if;
		if apex_authentication.is_public_user then
			v_Mail_type := 1; -- Self registration
		else
			v_Mail_type := 3; -- Invitation
		end if;
		v_instance_url 	:= data_browser_login.Get_App_Base_URL;
		v_host_name 	:= data_browser_login.Get_App_Host_Name;
       	v_Workspace 	:= case when data_browser_conf.Has_Multiple_Workspaces = 'YES' then SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME') end;
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
		v_Sender_ID := SYS_CONTEXT('CUSTOM_CTX', 'USER_ID');
		v_sql :=
        'begin ' || chr(10) ||
        'data_browser_login.Account_Info_Mail (' || chr(10) ||
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
        data_browser_login.Load_Job (
            p_Job_Name => 'ACCOUNT_MAIL',
            p_Comment => 'Send account info mail for data browser application',
            p_Sql => v_sql
        );
        COMMIT;
       ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Exit;
        $END
    exception 
	  when NO_DATA_FOUND then
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_user_id,p_password,p_account_token,p_app_id;
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_user_id,p_password,p_account_token,p_app_id;
        RAISE;
	END Account_Info_Mail_Job;
END data_browser_login;
/

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
            v_Password := data_browser_auth.Temporary_Password();
            :new.PASSWORD_HASH := data_browser_auth.hex_hash(:new.ID, v_Password);
        else
            v_Password := :new.PASSWORD_HASH;   -- is password may be already hashed by the program.
            if data_browser_auth.is_hex_key(:new.PASSWORD_HASH) = 0  then
                :new.PASSWORD_HASH := data_browser_auth.hex_hash(:new.ID, v_Password);
            end if;
        end if;
        if :new.EMAIL_ADDRESS IS NOT NULL then 
            data_browser_login.Split_EMail_Adress (
                p_Email => :new.EMAIL_ADDRESS,
                p_Main_Group_Name => :new.MAIN_GROUP_NAME,
                p_First_Name => :new.FIRST_NAME,
                p_Last_Name => :new.LAST_NAME,
                p_Login_Name => :new.LOGIN_NAME
            );
            if :new.PASSWORD_RESET = 'Y' then 
                :new.ACCOUNT_EXPIRATION_DATE := NVL(:new.ACCOUNT_EXPIRATION_DATE, SYSDATE+2);
                v_Token := dbms_random.string('X',32);
                :new.EMAIL_VALIATION_TOKEN :=  data_browser_auth.hex_hash(:new.ID, v_Token);
                data_browser_auth.log_message('APP_USERS_PWD_TR', 'Account_Info_Mail_Job(' || :new.ID ||', ' || v_Password || ', ' || v_Token|| ', ' || V('APP_ID') || ')' );
                data_browser_login.Account_Info_Mail_Job(
                    p_User_ID       => :new.ID,
                    p_Password      => v_Password,
                    p_Account_Token => v_Token,
                    p_App_ID => V('APP_ID')
                );
            end if;
        end if;
    elsif UPDATING then
        if :new.PASSWORD_HASH IS NOT NULL AND data_browser_auth.is_hex_key(:new.PASSWORD_HASH) = 0  then
            :new.PASSWORD_HASH := data_browser_auth.Hex_Hash(:new.ID, :new.PASSWORD_HASH);
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
	data_browser_login.Account_Info_Mail_Job(
		p_User_ID		=> 141424135413816554241736902659090143070,
		p_Password		=> 'XXX',
		p_Account_Token	=> 'YYY',
		p_App_ID        => 1003
	);
end;
/


*/
