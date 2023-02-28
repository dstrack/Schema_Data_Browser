
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



------------------------------------------------------------------------------
package for Apex custom authentication via user name and encrypted password

Setting for Apex Custom Authentification Schema :

	Sentry Function Name : data_browser_auth.page_sentry

	Authentication Function Name : data_browser_auth.authenticate

	Post Logout Procedure Name : data_browser_auth.post_logout

	Post-Authentication Procedure Name : data_browser_auth.post_authenticate

	Error Handling Function : #OWNER#.apex_error_handling

	Verify Function Name ; data_browser_auth.check_session_schema

	Authorization Scheme : APPLICATION_SENTRY
Setting for Application / Edit Security Attributes
Database Session
	Initialization PL/SQL Code: 

currently not used
-- data_browser_auth.page_sentry
-- data_browser_auth.check_session_schema

-- required privileges:
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO OWNER;
GRANT EXECUTE ON CUSTOM_KEYS.SCHEMA_KEYCHAIN TO OWNER;

-- uninstall
DROP SYNONYM SCHEMA_KEYCHAIN;
DROP VIEW VCURRENT_WORKSPACE;
DROP VIEW V_CONTEXT_USERS;
DROP PACKAGE data_browser_auth;
DROP TABLE APP_PREFERENCES;
DROP TABLE APP_USERS;
DROP TABLE APP_PROTOCOL;
DROP TABLE APP_USER_LEVELS;
DROP TABLE USER_WORKSPACE_SESSIONS;
DROP TABLE USER_NAMESPACES CASCADE CONSTRAINTS;
DROP SEQUENCE USER_NAMESPACES_SEQ;
*/


--------------------------------------------------

CREATE OR REPLACE SYNONYM SCHEMA_KEYCHAIN FOR CUSTOM_KEYS.SCHEMA_KEYCHAIN;

CREATE OR REPLACE VIEW VCURRENT_WORKSPACE AS
SELECT WORKSPACE$_ID, WORKSPACE_NAME, CREATED_BY, CREATION_DATE, WORKSPACE_STATUS STATUS, WORKSPACE_TYPE TYPE, TEMPLATE_NAME, APPLICATION_GROUP, EXPIRATION_DATE, APPLICATION_ID
FROM USER_NAMESPACES
WHERE WORKSPACE$_ID = custom_changelog.Get_Current_Workspace_ID
WITH CHECK OPTION;

CREATE OR REPLACE PACKAGE data_browser_auth
AUTHID DEFINER -- enable caller to find users (APP_USERS).
IS
    FUNCTION Get_Admin_Workspace_Name RETURN VARCHAR2;

	FUNCTION Get_App_Schema_Name RETURN VARCHAR2;
$IF data_browser_specs.g_use_dbms_crypt $THEN
	-- initialize the crypto key table - add a row for each user
	PROCEDURE init_keys;

	-- delivers the encrypted raw string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
	FUNCTION crypt (
		p_Crypto_Key_ID IN NUMBER,
		p_Text IN VARCHAR2)
	RETURN RAW;

	-- delivers the decrypted raw string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
	FUNCTION dcrypt (
		p_Crypto_Key_ID IN NUMBER,
		p_Eingabe IN RAW)
	RETURN VARCHAR2;

	-- delivers the encrypted hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_crypt(
    	p_Crypto_Key_ID IN NUMBER,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2;

    FUNCTION hex_crypt(
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2;

	-- delivers the decrypted hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_dcrypt(
    	p_Crypto_Key_ID IN NUMBER,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2;

    FUNCTION hex_dcrypt(
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2;
$END

	-- test for valid encrypted password string
    FUNCTION is_hex_key(
    	p_Text IN VARCHAR2)
    RETURN NUMBER;

    FUNCTION get_encrypted_count(
    	p_Table_Name IN VARCHAR2,
    	p_Column_Name IN VARCHAR2)
    RETURN NUMBER;

	-- delivers the hashed hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_hash(
    	p_User_ID IN APP_USERS.ID%TYPE,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2;

   	PROCEDURE log_message (
   		p_Subject	IN VARCHAR2,
   		p_Info	IN VARCHAR2
   	);

	-- add user <p_Username> with <p_Password> to custom user table to enable access with the authenticate function
    FUNCTION add_user (
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Email IN VARCHAR2 DEFAULT NULL,
        p_User_level IN NUMBER DEFAULT 3,
        p_Password_Reset IN VARCHAR2 DEFAULT 'Y',
        p_Account_Locked IN VARCHAR2 DEFAULT 'N',
        p_Email_Validated IN VARCHAR2 DEFAULT 'N'
    )
    RETURN APP_USERS.ID%TYPE;

    PROCEDURE add_user(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Email IN VARCHAR2 DEFAULT NULL,
        p_User_level IN NUMBER DEFAULT 3,
        p_Password_Reset IN VARCHAR2 DEFAULT 'Y',
        p_Account_Locked IN VARCHAR2 DEFAULT 'N',
        p_Email_Validated IN VARCHAR2 DEFAULT 'N'
    );

	FUNCTION Temporary_Password
	RETURN VARCHAR2;

	PROCEDURE Add_Developers;

	PROCEDURE First_Run (
		p_Admin_User VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_Admin_Password VARCHAR2,	-- encrypted by data_browser_auth.Hex_Crypt
		p_Admin_EMail VARCHAR2,		-- encrypted by data_browser_auth.Hex_Crypt
		p_Add_Demo_Guest VARCHAR2 DEFAULT 'NO'
	);

	PROCEDURE Add_Admin (
		p_Username IN VARCHAR2,
        p_Email IN VARCHAR2 DEFAULT NULL,
        p_Password IN VARCHAR2 DEFAULT NULL
	);

	-- validate browser session cookie, replace zero session with cookie session
	FUNCTION page_sentry
	RETURN boolean;

	-- validate user <p_Username> with <p_Password> exists in custom user table
	-- called in apex custom authorization schema
    FUNCTION authenticate(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2)
    RETURN BOOLEAN;

	FUNCTION client_ip_address RETURN VARCHAR2;

	-- quick check for valid session
	FUNCTION check_session_schema RETURN BOOLEAN;

	-- post_authenticate to be called in apex custom authorization schema
	PROCEDURE post_authenticate(
		p_newpasswordPage NUMBER DEFAULT NULL
	);

	PROCEDURE Set_Apex_Context(p_Schema_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));
	PROCEDURE Clear_Context;	

	FUNCTION strong_password_check (
		p_Username		IN VARCHAR2,
		p_password		IN VARCHAR2,
		p_old_password	IN VARCHAR2
	)
    RETURN VARCHAR2;

	-- change password in custom user table for <p_Username>. New password is <p_Password>
	PROCEDURE change_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2);

	-- change password of database account for <p_Username>. New password is <p_Password>
	PROCEDURE change_db_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2);

	-- post_logout called in apex custom authorization schema
    PROCEDURE post_logout;

END data_browser_auth;
/

CREATE OR REPLACE PACKAGE BODY data_browser_auth IS
    g_NewUserIDFunction CONSTANT VARCHAR2(100) := 'to_number(sys_guid(),''XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'')';
    -- g_NewUserIDFunction CONSTANT VARCHAR2(100) := 'APP_USERS_SEQ.NEXTVAL';
    g_AppUserExt   		CONSTANT VARCHAR2(10)   := '_APP_USER';	-- Extension for schema name of application user

    FUNCTION Get_Admin_Workspace_Name RETURN VARCHAR2
    IS
    	v_workspace_name VARCHAR2(50);
    BEGIN
        SELECT DISTINCT FIRST_VALUE(WORKSPACE_NAME) OVER (ORDER BY WORKSPACE$_ID) WORKSPACE_NAME
        INTO v_workspace_name
        FROM USER_NAMESPACES
        WHERE WORKSPACE_TYPE = 'INTERNAL';
        return v_workspace_name;
	exception
	  when NO_DATA_FOUND then
        return REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), g_AppUserExt || '$');
    END;

    FUNCTION Get_App_Schema_Name RETURN VARCHAR2
    IS
    	v_workspace_name VARCHAR2(50);
    BEGIN
        return REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), g_AppUserExt || '$');
    END;

$IF data_browser_specs.g_use_crypt_key_chain $THEN
	FUNCTION int_crypto_key (p_Crypto_Key_ID IN NUMBER) RETURN RAW
	IS
	BEGIN
		RETURN schema_keychain.Crypto_Key (p_Crypto_Key_ID, Get_App_Schema_Name, custom_changelog.Get_Context_Workspace_Name);
	END;

	-- initialize the crypto key table - add a row for each user
	PROCEDURE init_keys
	IS
		v_crypto_key	RAW(32);
	BEGIN
		for rec in (
			SELECT B.USER_ID KEY_ID
			FROM V_CONTEXT_USERS B
		)
		loop
			v_crypto_key := int_crypto_key (rec.KEY_ID);
		end loop;
		COMMIT;
	END;

$ELSE 
	FUNCTION int_crypto_key (p_Text IN VARCHAR2) RETURN RAW
	IS
    	v_salt VARCHAR2(300);
    	v_length pls_integer;
    	v_length2 pls_integer;
	BEGIN
		v_length := length(data_browser_conf.g_Software_Copyright);
		SELECT ORA_HASH(p_Text, v_length, 7+v_length) x into v_length2 from dual;
		v_salt := SUBSTR(data_browser_conf.g_Software_Copyright || data_browser_conf.g_Software_Copyright, v_length2, v_length);
		RETURN utl_raw.cast_to_raw(v_salt);
	END;

$END
	-- delivers a crypto salt hex string for the given <p_Crypto_Key_ID>
	FUNCTION crypto_salt (p_Crypto_Key_ID IN NUMBER)
		RETURN VARCHAR2
	IS
	BEGIN
		RETURN rawtohex(int_crypto_key (p_Crypto_Key_ID));
	END;

$IF data_browser_specs.g_use_dbms_crypt $THEN
	-- delivers the encrypted raw string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
	FUNCTION crypt (
		p_Crypto_Key_ID IN NUMBER,
		p_Text IN VARCHAR2)
	RETURN RAW
	IS
	  v_crypto_key		RAW(32);		-- crypto key for 256-bit
	  v_Crypto_Method   PLS_INTEGER :=  -- crypto method
		 DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_ZERO;
	BEGIN
		v_crypto_key := int_crypto_key (p_Crypto_Key_ID);
		RETURN DBMS_CRYPTO.ENCRYPT(
				   src => UTL_I18N.STRING_TO_RAW (p_Text, 'AL32UTF8'),
				   typ => v_Crypto_Method,
				   key => v_crypto_key);
	END;

	-- delivers the decrypted raw string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
	FUNCTION dcrypt (
		p_Crypto_Key_ID IN NUMBER,
		p_Eingabe IN RAW)
	RETURN VARCHAR2
	IS
	  v_Data   	      	RAW(8000);
	  v_crypto_key		RAW(32);
	  v_Crypto_Method  	PLS_INTEGER :=
		 DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_ZERO;
		 
      NLS_error_detected EXCEPTION;
      PRAGMA EXCEPTION_INIT(NLS_error_detected, -1890);
	BEGIN
		v_crypto_key := int_crypto_key (p_Crypto_Key_ID);
		v_Data   := DBMS_CRYPTO.DECRYPT(
			 src => p_Eingabe,
			 typ => v_Crypto_Method,
			 key => v_crypto_key);
		RETURN UTL_I18N.RAW_TO_CHAR(v_Data, 'AL32UTF8');
	EXCEPTION WHEN NLS_error_detected THEN
		RETURN NULL;
	END;

	-- delivers the encrypted hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_crypt(
    	p_Crypto_Key_ID IN NUMBER,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2
    IS
    BEGIN
	  	RETURN case when p_Text IS NOT NULL then rawtohex(crypt(p_Crypto_Key_ID, p_Text)) end;
    END hex_crypt;

    FUNCTION hex_crypt(
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2
    IS
    BEGIN
	  	RETURN case when p_Text IS NOT NULL then rawtohex(crypt(-1, p_Text)) end;
    END hex_crypt;

	-- delivers the decrypted hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_dcrypt(
    	p_Crypto_Key_ID IN NUMBER,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2
    IS
    BEGIN
	  	RETURN case when p_Text IS NOT NULL then dcrypt(p_Crypto_Key_ID, hextoraw(p_Text)) end;
    END hex_dcrypt;

    FUNCTION hex_dcrypt(
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2
    IS
    BEGIN
	  	RETURN case when p_Text IS NOT NULL then dcrypt(-1, hextoraw(p_Text)) end;
    END hex_dcrypt;

	-- delivers the hashed hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_hash(
    	p_User_ID IN APP_USERS.ID%TYPE,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2
    IS
    	v_Crypto_Key_ID NUMBER;
    	v_salt VARCHAR2(300);
    BEGIN
    	if p_Text IS NOT NULL then 
			v_Crypto_Key_ID := TO_NUMBER(p_User_ID);
			v_salt := crypto_salt (v_Crypto_Key_ID);
			RETURN rawtohex(sys.dbms_crypto.hash (
						   sys.utl_raw.cast_to_raw(p_Text || v_salt),
						   sys.dbms_crypto.HASH_SH1 ));
		end if; 
		return NULL;
    END hex_hash;

$ELSE
	-- delivers the hashed hex string for the given <p_Text>
	-- using the secret crypto key of <p_Crypto_Key_ID>
    FUNCTION hex_hash(
    	p_User_ID IN APP_USERS.ID%TYPE,
    	p_Text IN VARCHAR2)
    RETURN VARCHAR2
    IS
    	v_Crypto_Key_ID NUMBER;
    	v_salt VARCHAR2(300);
    BEGIN
    	if p_Text IS NOT NULL then 
			v_Crypto_Key_ID := TO_NUMBER(p_User_ID);
			v_salt := crypto_salt (v_Crypto_Key_ID);
			RETURN rawtohex(
				sys.utl_raw.cast_to_raw(
					SUBSTR(apex_util.get_hash(p_values => apex_t_varchar2 ( p_Text, v_salt ), p_salted => false), 1, 32)
				)
			);
		end if; 
		return NULL;
    END hex_hash;

$END
	-- test for valid encrypted password string
    FUNCTION is_hex_key(
    	p_Text IN VARCHAR2)
    RETURN NUMBER    IS
    BEGIN
	  	RETURN CASE WHEN LENGTH(p_Text) >= 32 AND TRANSLATE(p_Text, '0123456789ABCDEF', NULL) IS NULL THEN 1 ELSE 0 END;
    END is_hex_key;

	-- count valid encrypted password string
    FUNCTION get_encrypted_count(
    	p_Table_Name IN VARCHAR2,
    	p_Column_Name IN VARCHAR2)
    RETURN NUMBER
    IS
		stat_cur	SYS_REFCURSOR;
		v_cnt		NUMBER;
	BEGIN
		OPEN  stat_cur FOR
			'SELECT COUNT(*) FROM '
			|| DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name)
    		|| ' WHERE data_browser_auth.is_hex_key(' || DBMS_ASSERT.ENQUOTE_NAME(p_Column_Name) || ') > 0';
		FETCH stat_cur INTO v_cnt;
		RETURN v_cnt;
	EXCEPTION
	WHEN others THEN
		return NULL;
	END;



	-- Execute generated statements
	PROCEDURE run_stat (
		p_Statement    	IN CLOB,
		p_Do_Execute  	IN NUMBER	DEFAULT 1,
		p_Delimiter		IN VARCHAR2 DEFAULT ';'
	)
	IS
	BEGIN
		if p_Do_Execute = 1 then
			DBMS_OUTPUT.PUT_LINE(p_Statement || p_Delimiter);
			EXECUTE IMMEDIATE p_Statement;
		else
			DBMS_OUTPUT.PUT_LINE(p_Statement || p_Delimiter);
		end if;
	END;

   	PROCEDURE log_message (
   		p_Subject	IN VARCHAR2,
   		p_Info	IN VARCHAR2
   	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Subject APP_PROTOCOL.DESCRIPTION%TYPE;
		v_Info	APP_PROTOCOL.Remarks%TYPE;
	BEGIN
		v_Subject	:= SUBSTRB(p_Subject, 1, 40);
		v_Info 		:= SUBSTRB(p_Info, 1, 4000);
		DBMS_OUTPUT.PUT_LINE('Subject:' || p_Subject);
		DBMS_OUTPUT.PUT_LINE('Info:' || p_Info);
		INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  (v_Subject, v_Info);
		COMMIT;
	EXCEPTION
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('data_browser_auth.log_message - failed with ' || SQLERRM);
	END;


	-- add user <p_Username> with <p_Password> to custom user table to enable access with the authenticate function
    FUNCTION add_user (
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Email IN VARCHAR2 DEFAULT NULL,
        p_User_level IN NUMBER DEFAULT 3,
        p_Password_Reset IN VARCHAR2 DEFAULT 'Y',
        p_Account_Locked IN VARCHAR2 DEFAULT 'N',
        p_Email_Validated IN VARCHAR2 DEFAULT 'N'
    ) RETURN APP_USERS.ID%TYPE
    IS
        v_id   		APP_USERS.ID%TYPE;
    	v_Data		APP_USERS.PASSWORD_HASH%TYPE;
    	v_Username	APP_USERS.LOGIN_NAME%TYPE;
    	v_EMail 	APP_USERS.EMAIL_ADDRESS%TYPE;
    BEGIN
    	v_Username := UPPER(TRIM(p_Username));
		v_EMail := NVL(p_Email, APEX_UTIL.GET_EMAIL(v_Username));
    	SELECT MAX(USER_ID)
    	INTO v_id
    	FROM V_CONTEXT_USERS WHERE UPPER_LOGIN_NAME = v_Username;
    	if v_id IS NULL then
			execute immediate 'begin :new_id := ' || g_NewUserIDFunction || '; end;' using out v_id;
			v_Data := hex_hash(v_id, p_Password);
			INSERT INTO V_CONTEXT_USERS (User_Id, Login_Name, Password_Hash, Email_Address, Email_Validated, User_Level, Password_Reset, Account_Locked)
			VALUES (v_id, TRIM(p_Username), v_Data, TRIM(p_Email), p_Email_Validated, p_User_level, p_Password_Reset, p_Account_Locked);
		end if;
    	RETURN v_id;
    END add_user;

    PROCEDURE add_user (
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Email IN VARCHAR2 DEFAULT NULL,
        p_User_level IN NUMBER DEFAULT 3,
        p_Password_Reset IN VARCHAR2 DEFAULT 'Y',
        p_Account_Locked IN VARCHAR2 DEFAULT 'N',
        p_Email_Validated IN VARCHAR2 DEFAULT 'N'
    )
    IS
        v_id   		APP_USERS.ID%type;
    BEGIN
		v_id	:= add_user(p_Username, p_Password, p_Email, p_User_level, p_Password_Reset, p_Account_Locked, p_Email_Validated);
    END add_user;

	FUNCTION Temporary_Password
	RETURN VARCHAR2
	IS
		v_result VARCHAR2(20);
	BEGIN
		loop 
			v_result := REPLACE(INITCAP(REGEXP_REPLACE(dbms_random.string('X',12), '(.{4})(.{4})(.{4})', '\1_\2_\3')), '_', '-');
			exit when v_result NOT IN ( UPPER(v_result), LOWER(v_result));
		end loop;
		RETURN v_result;
	END;

	PROCEDURE Add_Admin (
		p_Username IN VARCHAR2,
        p_Email IN VARCHAR2 DEFAULT NULL,
        p_Password IN VARCHAR2 DEFAULT NULL
	)
	IS
	BEGIN
		custom_changelog.set_new_workspace(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));
		-- Enable APEX_PUBLIC_USER as app user
		data_browser_auth.add_user(p_Username => SYS_CONTEXT('USERENV', 'SESSION_USER'), p_Password => Temporary_Password, p_Account_Locked => 'Y');
		if p_Username IS NOT NULL and p_Password IS NOT NULL then
			begin
				data_browser_auth.add_user(
					p_Username => p_Username,
					p_Email    => p_Email,
					p_Password => p_Password,
					p_User_level => 1,
					p_Password_Reset => 'N',
					p_Email_Validated => 'Y'
				);
				data_browser_auth.change_password(
					p_Username => p_Username,
					p_Password => p_Password
				);
			end;
		end if;
	END Add_Admin;

	PROCEDURE Add_Developers
	IS
	BEGIN
		INSERT INTO V_CONTEXT_USERS (Login_Name, First_Name, Last_Name, EMail_Address, User_Level, Password_Reset, Email_Validated)
		select D.USER_NAME, D.FIRST_NAME, D.LAST_NAME, D.EMAIL,
			case when D.IS_ADMIN = 'Yes' then 1
				when D.IS_APPLICATION_DEVELOPER = 'Yes' then 2
				else 3
			end User_Level,
			'N' Password_Reset,
			'Y' Email_Validated
		from APEX_WORKSPACE_DEVELOPERS D
		 where WORKSPACE_ID = APEX_CUSTOM_AUTH.GET_SECURITY_GROUP_ID
		and NOT EXISTS (
			SELECT 1
			FROM V_CONTEXT_USERS U
			WHERE U.UPPER_LOGIN_NAME = D.USER_NAME
		);
		commit;
	END Add_Developers;

	PROCEDURE First_Run (
		p_Admin_User VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_Admin_Password VARCHAR2,	-- encrypted by data_browser_auth.Hex_Crypt
		p_Admin_EMail VARCHAR2,		-- encrypted by data_browser_auth.Hex_Crypt
		p_Add_Demo_Guest VARCHAR2 DEFAULT 'NO'
	)
	is
		v_Count	PLS_INTEGER;
	begin 
		select count(*) into v_Count from V_CONTEXT_USERS where UPPER_LOGIN_NAME = UPPER(p_Admin_User);
		if v_Count = 0 then 
			-- first run : add admin, demo, guest accounts
$IF data_browser_specs.g_use_dbms_crypt $THEN
			data_browser_auth.Add_Admin(
				p_Username => p_Admin_User,
				p_Password => data_browser_auth.hex_dcrypt( p_Admin_Password ),
				p_email => data_browser_auth.hex_dcrypt (p_Admin_EMail )
			);
$ELSE
			data_browser_auth.Add_Admin(
				p_Username => p_Admin_User,
				p_Password => p_Admin_Password,
				p_email => p_Admin_EMail
			);
$END
		end if;
		if p_Add_Demo_Guest = 'YES' then 
			select count(*) into v_Count from V_CONTEXT_USERS where UPPER_LOGIN_NAME = 'DEMO';
			if v_Count = 0 then 
				data_browser_auth.Add_User(
					p_Username => 'Demo',
					p_Password => 'Demo/2945',
					p_User_level => 1,
					p_Password_Reset => 'N',
					p_Email_Validated => 'Y'
				);
			end if;
			select count(*) into v_Count from V_CONTEXT_USERS where UPPER_LOGIN_NAME = 'GUEST';
			if v_Count = 0 then 
				data_browser_auth.Add_User(
					p_Username => 'Guest',
					p_Password => 'Guess/2945',
					p_User_level => 6,
					p_Password_Reset => 'N',
					p_Email_Validated => 'Y'
				);
			end if;
		end if;
	end First_Run;

	-- validate browser session cookie, replace zero session with cookie session
	-- called in apex custom authorization schema
	-- see http://www.yenlo.nl/nl/oracle-apex-sessions-across-several-browser-tabs/
	FUNCTION page_sentry
	RETURN boolean
	is
		l_username varchar2 (512);
		l_session_id number;
		l_app_id	number := v ('APP_ID');
		l_url       varchar2(4000);
		l_url_sid	varchar2(40);
	begin
		-- only do this if the connected user = APEX_PUBLIC_USER
		if user != 'APEX_PUBLIC_USER' then
			return false;
		end if;
		/* special case public pages eg. translated login page */
		if APEX_CUSTOM_AUTH.CURRENT_PAGE_IS_PUBLIC() = true then
			return true;
		end if;

		-- get your session ID from your browser cookie
		l_session_id := wwv_flow_custom_auth_std.get_session_id_from_cookie;
		if wwv_flow_custom_auth_std.is_session_valid then
			apex_application.g_instance := l_session_id;
			l_username := wwv_flow_custom_auth_std.get_username;
			-- the session can be valid, but you also have to be connected
			if lower (l_username) <> 'nobody' then
				wwv_flow_custom_auth.define_user_session (p_user => l_username, p_session_id => l_session_id);
				return true;
			else
				/* special case public pages eg. translated login page */
				if APEX_CUSTOM_AUTH.CURRENT_PAGE_IS_PUBLIC() = true then
					return true;
				end if;
			end if;
		else
			-- if the session is not valid, go to your login page
			l_url := apex_util.prepare_url('f?p=' || l_app_id || ':LOGIN_DESKTOP');
			log_message('page_sentry-redirect_url:' || USER,  l_url);
			owa_util.redirect_url (l_url);
		end if;
		return false;
	end page_sentry;


	-- validate user <p_Username> with <p_Password> exists in custom user table
	-- validate Workspace Application_ID
	-- called in apex custom authorization schema
    FUNCTION authenticate(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2)
    RETURN BOOLEAN
    IS
		v_result         BOOLEAN := false;
		v_user 			APP_USERS.Login_Name%type;
		v_id   			APP_USERS.ID%type;
		v_password		VARCHAR2(1000);
		v_pwd_hash		APP_USERS.Password_Hash%type;
		v_reset_pw 		APP_USERS.Password_Reset%type;
		v_message		VARCHAR2(50);
    BEGIN
    	v_user  := UPPER(TRIM(p_Username));
    	v_password := TRIM(p_Password);
    	if check_session_schema then
			begin
				SELECT USER_ID, Password_Hash, Password_Reset
				INTO v_id, v_pwd_hash, v_reset_pw
				FROM V_CONTEXT_USERS B
				WHERE UPPER_LOGIN_NAME = v_user
				AND (Account_Expiration_Date >= TRUNC(SYSDATE) OR Account_Expiration_Date IS NULL)
				AND EMAIL_VALIDATED = 'Y'
				AND ACCOUNT_LOCKED = 'N'
				FOR UPDATE OF B.LAST_LOGIN_DATE;

				if v_pwd_hash IS NOT NULL then
					if v_pwd_hash = hex_hash(v_id, v_password) then
						v_result := true;
						v_message := 'Login - successful';
					else
						v_message := 'Login - failed';
					end if;
				end if;
			exception
			  when NO_DATA_FOUND then
				v_message := 'Login - failed. Invalid credentials';
			  when others then
				v_message := 'Login - error ' || SQLCODE;
			end;
		else
			v_message := 'Login - Workspace App mismatch';
		end if;
		log_message(v_message, v_user);

		if v_result = false then
			APEX_UTIL.PAUSE(1);
		end if;
        return v_result;
    END authenticate;

	FUNCTION client_ip_address
		RETURN VARCHAR2
	IS
	BEGIN
		if OWA.NUM_CGI_VARS IS NOT NULL then -- PL/SQL gateway connection (WEB client)
			return SUBSTR(OWA_UTIL.get_cgi_env ('REMOTE_ADDR'), 1, 255);
		else -- Direct connection over tcp/ip network
			return SUBSTR(SYS_CONTEXT ('USERENV', 'IP_ADDRESS'), 1, 255);
		end if;
	END client_ip_address;

	-- Verify Function Name : quick check for valid session
	FUNCTION check_session_schema RETURN BOOLEAN
	IS
		v_Privileges_Cnt NUMBER := 0;
	BEGIN
		SELECT COUNT(*) INTO v_Privileges_Cnt
		FROM VCURRENT_WORKSPACE
		WHERE APPLICATION_ID = V('APP_ID') OR APPLICATION_ID IS NULL;
		if v_Privileges_Cnt = 1 then	-- Nur wenn APPLICATION_ID mit dem aktuellen Workspace übereinstimmen.
			return TRUE;
		else
			return FALSE;
		end if;
	END check_session_schema;


	-- post_authenticate called in apex custom authorization schema
	PROCEDURE post_authenticate (
		p_newpasswordPage NUMBER DEFAULT NULL
	)
	IS
      v_id   			APP_USERS.ID%type;
      v_user 			APP_USERS.Login_Name%type;
      v_pwd_hash  			APP_USERS.Password_Hash%type;
      v_reset_pw 		APP_USERS.Password_Reset%type;
      v_expire_date		APP_USERS.Password_Expiration_Date%type;
      v_redirect_url	VARCHAR2(200);
      v_client_ip_address VARCHAR2(255) := SUBSTR(data_browser_auth.client_ip_address(), 1, 255);
	BEGIN
		SELECT USER_ID, UPPER_LOGIN_NAME, Password_Hash, Password_Reset, Password_Expiration_Date
		INTO v_id, v_user, v_pwd_hash, v_reset_pw, v_expire_date
		FROM V_CONTEXT_USERS B
		WHERE UPPER_LOGIN_NAME = V('APP_USER')
		FOR UPDATE OF B.LAST_LOGIN_DATE;

		UPDATE V_CONTEXT_USERS
		SET LAST_LOGIN_DATE = SYSDATE
		WHERE USER_ID = v_id;

		MERGE INTO USER_WORKSPACE_SESSIONS D
		USING (SELECT V('APP_SESSION') 						APEX_SESSION_ID,
					custom_changelog.Get_Current_User_Name 	USER_NAME,
					SYSDATE									SESSION_CREATED,
					v_client_ip_address						IP_ADDRESS
			FROM DUAL
		) S
		ON (D.APEX_SESSION_ID = S.APEX_SESSION_ID)
		WHEN MATCHED THEN
			UPDATE SET D.USER_NAME = S.USER_NAME, D.SESSION_CREATED = S.SESSION_CREATED, D.IP_ADDRESS = S.IP_ADDRESS
		WHEN NOT MATCHED THEN
			INSERT (D.APEX_SESSION_ID, D.USER_NAME, D.SESSION_CREATED, D.IP_ADDRESS, D.WORKSPACE$_ID)
			VALUES (S.APEX_SESSION_ID, S.USER_NAME, S.SESSION_CREATED, S.IP_ADDRESS, custom_changelog.Get_Current_Workspace_ID)
		;
		COMMIT;
        if  (v_reset_pw = 'Y' or v_pwd_hash IS NULL or v_expire_date < TRUNC(SYSDATE)) and p_newpasswordPage IS NOT NULL then
  			-- Request new password
			log_message('Request new password', v_user);

            v_redirect_url := apex_util.prepare_url('f?p='||V('APP_ID')||':' || p_newpasswordPage || ':' || V('APP_SESSION') || '::'||V('DEBUG')||':::');
			apex_util.set_session_state(p_name => 'FSP_AFTER_LOGIN_URL',p_value => v_redirect_url);
        end if;

	END post_authenticate;

	PROCEDURE Set_Apex_Context(p_Schema_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'))
	IS 
		v_Table_App_Users VARCHAR2(200) := changelog_conf.Get_Table_App_Users;
	BEGIN
$IF data_browser_specs.g_use_custom_ctx $THEN
		if apex_application.g_debug then
			apex_debug.message('set_custom_ctx.set_apex_context(p_Table_App_Users=>''%s'', p_Schema_Name=>''%s'')',v_Table_App_Users, p_Schema_Name);
			apex_debug.message('-- SCHEMA: %s, APP_PARSING_SCHEMA: %s, APP_USER: %s, APP_WORKSPACE: %s', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), V('APP_PARSING_SCHEMA'), V('APP_USER'), V('APP_WORKSPACE') );
		end if;
		set_custom_ctx.set_apex_context(p_Table_App_Users=>v_Table_App_Users, p_Schema_Name=>p_Schema_Name);
		if apex_application.g_debug then
			apex_debug.message('-- USER_ID: %s, WORKSPACE_ID: %s ', SYS_CONTEXT('CUSTOM_CTX', 'USER_ID'), SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_ID'));
		end if;
$ELSE
		null;
$END
	END;

	PROCEDURE Clear_Context
	IS 
	BEGIN
$IF data_browser_specs.g_use_custom_ctx $THEN
		set_custom_ctx.Clear_Context;
$ELSE
		null;
$END
	END;


	FUNCTION strong_password_check (
		p_Username		IN VARCHAR2,
		p_password		IN VARCHAR2,
		p_old_password	IN VARCHAR2
	)
    RETURN VARCHAR2
	IS
		v_workspace_name              varchar2(30);
		v_min_length_err              boolean;
		v_new_differs_by_err          boolean;
		v_one_alpha_err               boolean;
		v_one_numeric_err             boolean;
		v_one_punctuation_err         boolean;
		v_one_upper_err               boolean;
		v_one_lower_err               boolean;
		v_not_like_username_err       boolean;
		v_not_like_workspace_name_err boolean;
		v_not_like_words_err          boolean;
		v_not_reusable_err            boolean;
		v_result                      varchar2(500);
	BEGIN
		v_workspace_name := APEX_UTIL.GET_DEFAULT_SCHEMA;

	  APEX_UTIL.STRONG_PASSWORD_CHECK(
		p_username                    => p_username,
		p_password                    => p_password,
		p_old_password                => p_old_password,
		p_workspace_name              => v_workspace_name,
		p_use_strong_rules            => false,
		p_min_length_err              => v_min_length_err,
		p_new_differs_by_err          => v_new_differs_by_err,
		p_one_alpha_err               => v_one_alpha_err,
		p_one_numeric_err             => v_one_numeric_err,
		p_one_punctuation_err         => v_one_punctuation_err,
		p_one_upper_err               => v_one_upper_err,
		p_one_lower_err               => v_one_lower_err,
		p_not_like_username_err       => v_not_like_username_err,
		p_not_like_workspace_name_err => v_not_like_workspace_name_err,
		p_not_like_words_err          => v_not_like_words_err,
		p_not_reusable_err            => v_not_reusable_err
	  );

	  IF v_min_length_err THEN
		  v_result := v_result || ' ' || ('Password is too short.');
	  END IF;

	  IF v_new_differs_by_err THEN
		   v_result := v_result || ' ' || APEX_LANG.LANG('Password must be different from the old password.');
	  END IF;

	  IF v_one_alpha_err THEN
		   v_result := v_result || ' ' || APEX_LANG.LANG('Password must contain at least one letter.');
	  END IF;

	  IF v_one_numeric_err THEN
		   v_result := v_result || ' ' || APEX_LANG.LANG('Password must contain at least one digit.');
	  END IF;

	  IF v_one_punctuation_err THEN
		   v_result := v_result || ' ' || APEX_LANG.LANG('Password must contain at least one special character.');
	  END IF;

	  IF v_one_lower_err THEN
		  v_result := v_result || ' ' || APEX_LANG.LANG('Password must contain at least one lowercase letter.');
	  END IF;

	  IF v_one_upper_err THEN
		  v_result := v_result || ' ' || APEX_LANG.LANG('Password must contain at least one uppercase.');
	  END IF;

	  IF v_not_like_username_err THEN
		  v_result := v_result || ' ' || APEX_LANG.LANG('Password must not contain the user name.');
	  END IF;

	  IF v_not_like_workspace_name_err THEN
		  v_result := v_result || ' ' || APEX_LANG.LANG('Password should not contain the workspace name.');
	  END IF;

	  IF v_not_like_words_err THEN
		  v_result := v_result || ' ' || APEX_LANG.LANG('Password contains illegal term.');
	  END IF;

	  IF v_not_reusable_err THEN
		  v_result := v_result || ' ' || APEX_LANG.LANG('Password can not be reused.');
	  END IF;
	  return v_result;
	END strong_password_check;

-- change password in custom user table for <p_Username>. New password is <p_Password>
	PROCEDURE change_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2)
	IS
	BEGIN
		UPDATE V_CONTEXT_USERS
		SET Password_Hash = hex_hash(USER_ID, p_Password),
			Password_Reset = 'N',
			Password_Expiration_Date = NULL,
			Account_Expiration_Date = case when Password_Reset = 'Y' then NULL else Account_Expiration_Date end,
			Email_Validated = 'Y',
			LAST_LOGIN_DATE = SYSDATE
		WHERE UPPER_LOGIN_NAME = UPPER(TRIM(p_Username));
	END change_password;

	-- change password of apex account for <p_Username>. New password is <p_Password>
	PROCEDURE change_apex_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2)
	IS
	BEGIN
		APEX_UTIL.CHANGE_CURRENT_USER_PW (p_Password);
	END change_apex_password;

	-- post_logout called in apex custom authorization schema
	PROCEDURE post_logout
	IS
      v_User 	APP_USERS.Login_Name%type := V('APP_USER');
      v_Message	VARCHAR2(300) := 'Logout';
	BEGIN
		log_message(v_Message, v_User);
	END post_logout;

	-- change password of database account for <p_Username>. New password is <p_Password>
	PROCEDURE change_db_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2)
	IS
		v_UserName VARCHAR2(50);
		v_UserPW VARCHAR2(50);
		v_Stat VARCHAR2(200);
	BEGIN
		v_UserName := DBMS_ASSERT.ENQUOTE_NAME(p_Username);
		v_UserPW   := DBMS_ASSERT.ENQUOTE_NAME(p_Password, FALSE);
		v_Stat     := 'ALTER  USER ' || v_UserName || ' IDENTIFIED BY ' || v_UserPW;
		EXECUTE IMMEDIATE v_Stat;
	END;

END data_browser_auth;
/



declare
	v_Count PLS_INTEGER;
begin -- when the custom context exists, a trigger is installed. that trigger set the context on login 
	SELECT COUNT(*) INTO v_Count
	FROM all_synonyms WHERE OWNER = 'PUBLIC' AND synonym_name = 'SET_CUSTOM_CTX' AND table_owner = 'CUSTOM_KEYS';
	if v_Count = 1 then
		EXECUTE IMMEDIATE '
CREATE OR REPLACE TRIGGER set_custom_ctx_trig AFTER LOGON ON SCHEMA
BEGIN
  set_custom_ctx.post_db_logon;
EXCEPTION
  WHEN OTHERS THEN
  	set_custom_ctx.Log_Message(SQLCODE, SQLERRM);
END;
';
	end if;
end;
/
-- for access by DATA_BROWSER_SCHEMA package
grant select on APP_USERS to PUBLIC;
grant select on V_CONTEXT_USERS to PUBLIC;
/*

begin if data_browser_auth.authenticate('DIRK', 'abc') then dbms_output.PUT_LINE('OK'); else dbms_output.PUT_LINE('failed'); end if; end;
/


function check_session_owner return boolean
is -- for application without multiple workspaces, the application schema is equal to the workspace_name.
begin
    if APEX_CUSTOM_AUTH.CURRENT_PAGE_IS_PUBLIC() = true then
		return true;
	end if;
    return V('APP_WORKSPACE') = V('OWNER');
end check_session_owner;


*/
