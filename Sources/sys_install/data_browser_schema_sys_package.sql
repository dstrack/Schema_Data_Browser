/*
Copyright 2019 Dirk Strack, Strack Software Development

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Package with special functions used in the data browser application.
*/

set serveroutput on size unlimited
set scan off

--DROP PACKAGE data_browser_schema;
--DROP PACKAGE BODY data_browser_schema;


declare 
    v_Schema_Name VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
	v_Use_Admin_Features VARCHAR2(128);
	v_package_exists NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end 
	INTO v_Use_Admin_Features
	FROM DBA_ROLE_PRIVS 
	WHERE GRANTEE = v_Schema_Name
	AND GRANTED_ROLE = 'DBA';

	SELECT COUNT(*) 
	INTO v_package_exists
	FROM USER_OBJECTS 
	WHERE OBJECT_NAME = 'DATA_BROWSER_SCHEMA'
	AND OBJECT_TYPE = 'PACKAGE';

	if v_package_exists != 0 then
		EXECUTE IMMEDIATE 'DROP PACKAGE DATA_BROWSER_SCHEMA';
	end if;
	
	v_stat := q'[
CREATE OR REPLACE PACKAGE data_browser_schema 
AUTHID DEFINER
IS
	TYPE DATA_BROWSER_MAILPARAM_TYPE IS RECORD (
		INFOMAIL_FROM		VARCHAR2(256), 
		SMTP_HOST_ADDRESS	VARCHAR2(256), 
		SMTP_HOST_PORT		INTEGER, 
		SMTP_USERNAME		VARCHAR2(256), 
		SMTP_PASSWORD		VARCHAR2(256), 
		WALLET_PATH			VARCHAR2(256), 
		WALLET_PWD			VARCHAR2(256), 
		SMTP_TLS_MODE		INTEGER, 
		SMTP_TLS_PLAIN		INTEGER
	);
	TYPE DATA_BROWSER_MAILPARAM_TAB IS TABLE OF DATA_BROWSER_MAILPARAM_TYPE;
	
	TYPE Data_Browser_Schema_List_Rec IS RECORD (
		SCHEMA_NAME VARCHAR2(128),
		APP_VERSION_NUMBER VARCHAR2(64),
		SPACE_USED_BYTES NUMBER,
		USER_ACCESS_LEVEL NUMBER,
		SCHEMA_ICON VARCHAR2(2000),
		DESCRIPTION VARCHAR2(2000),
		CONFIGURATION_NAME VARCHAR2(128)
	);
	TYPE Data_Browser_Schema_List_Tab IS TABLE OF Data_Browser_Schema_List_Rec;
	
    FUNCTION FN_GET_PARAMETER(p_Name VARCHAR2) RETURN VARCHAR2;

	FUNCTION FN_Pipe_mail_parameter RETURN DATA_BROWSER_MAILPARAM_TAB PIPELINED;

	FUNCTION Get_User_Access_Level (
		p_Schema_Name VARCHAR2,
		p_User_Name VARCHAR2
	) RETURN NUMBER;

	FUNCTION List_Schema (
		p_User_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_application_id IN NUMBER DEFAULT NV('APP_ID'),
		p_App_Version_Number IN VARCHAR2 DEFAULT NULL
	) RETURN Data_Browser_Schema_List_Tab PIPELINED;

	PROCEDURE Add_Schema (
		p_Schema_Name	VARCHAR2,
		p_Password		VARCHAR2 DEFAULT NULL
	);

	PROCEDURE Revoke_Schema (
		p_Schema_Name	VARCHAR2
	);

	PROCEDURE Add_Apex_Workspace_Schema (
		p_Schema_Name	VARCHAR2,
		p_Apex_Workspace_Name VARCHAR2 DEFAULT NULL,
        p_Application_ID VARCHAR2 DEFAULT V('APP_ID')
	);

	PROCEDURE Copy_Schema (
	  p_source_user		 IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
	  p_dest_user		 IN VARCHAR2,
	  p_dest_user_pwd	 IN VARCHAR2 DEFAULT NULL,
	  p_paral_lvl		 IN NUMBER	 DEFAULT 2,
	  p_database_link	 IN VARCHAR2 DEFAULT NULL, 
	  p_include_rows	 IN NUMBER	 DEFAULT 1 
	);

	PROCEDURE Drop_Schema (
		p_Schema_Name VARCHAR2,
		p_Apex_Workspace_Name VARCHAR2 DEFAULT NULL,
		p_User_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER')
	);

	PROCEDURE Install_Data_Browser_App (
		p_workspace VARCHAR2,
		p_schema VARCHAR2,
		p_app_id VARCHAR2,
		p_app_alias VARCHAR2 DEFAULT NULL
	);

	PROCEDURE Install_Data_Browser_Publish (
		p_workspace VARCHAR2,
		p_app_id VARCHAR2
	);

	PROCEDURE First_Run (
		p_Dest_Schema VARCHAR2,
		p_Admin_User VARCHAR2,
		p_Admin_Password VARCHAR2,	-- encrypted by data_browser_auth.Hex_Crypt
		p_Admin_EMail VARCHAR2,		-- encrypted by data_browser_auth.Hex_Crypt
		p_Add_Demo_Guest VARCHAR2
	);

	g_Use_Admin_Features	   CONSTANT BOOLEAN := ]'
	|| v_Use_Admin_Features || ';' || chr(10) 
	|| 'END data_browser_schema;' || chr(10) ;
	EXECUTE IMMEDIATE v_Stat;
    --dbms_output.put_line(v_Stat);
end;
/

CREATE OR REPLACE PACKAGE BODY data_browser_schema
IS

    FUNCTION FN_GET_PARAMETER(p_Name VARCHAR2) RETURN VARCHAR2 
    IS 
    BEGIN
$IF data_browser_schema.g_Use_Admin_Features $THEN 
        return APEX_INSTANCE_ADMIN.GET_PARAMETER (p_Name);
$ELSE 
		return NULL;
$END
	exception    -- prevent ORA-20987: APEX - Instance parameter not found - Contact your application administrator.
	  when others then
		IF SQLCODE != -20987 THEN
			RAISE;
		END IF;
        return null;
	end;

	-- enable the application to obtain the mail server configuration for the APEX_INSTANCE_ADMIN parameters. 
	FUNCTION FN_Pipe_mail_parameter RETURN DATA_BROWSER_MAILPARAM_TAB PIPELINED
	IS
	PRAGMA UDF;
		c_cur SYS_REFCURSOR;
		v_row DATA_BROWSER_MAILPARAM_TYPE; -- output row
	BEGIN
		OPEN c_cur FOR
			SELECT FN_GET_PARAMETER('SMTP_FROM') INFOMAIL_FROM, 
				FN_GET_PARAMETER ( 'SMTP_HOST_ADDRESS' ) SMTP_HOST_ADDRESS,
				FN_GET_PARAMETER ( 'SMTP_HOST_PORT' ) SMTP_HOST_PORT,
				FN_GET_PARAMETER ( 'SMTP_USERNAME' ) SMTP_USERNAME,
				FN_GET_PARAMETER ( 'SMTP_PASSWORD' ) SMTP_PASSWORD,
				FN_GET_PARAMETER ( 'WALLET_PATH' ) WALLET_PATH,
				FN_GET_PARAMETER ( 'WALLET_PWD' ) WALLET_PWD,
				case FN_GET_PARAMETER ( 'SMTP_TLS_MODE' ) when 'N' then 0 else 1 end SMTP_TLS_MODE,
				case FN_GET_PARAMETER ( 'SMTP_TLS_MODE' ) when 'STARTTLS' then 1 else 0 end SMTP_TLS_PLAIN
			FROM DUAL;
		loop
			FETCH c_cur INTO v_row;
			EXIT WHEN c_cur%NOTFOUND;
			PIPE ROW(v_row);
		end loop;
		CLOSE c_cur;
		RETURN;
	END FN_Pipe_mail_parameter;

	PROCEDURE Add_Apex_Workspace_Schema (
		p_Schema_Name	VARCHAR2,
		p_Apex_Workspace_Name VARCHAR2 DEFAULT NULL,
        p_Application_ID VARCHAR2 DEFAULT V('APP_ID')
	)
	IS
		v_workspace_id		NUMBER;
		v_Workspace_Name	APEX_APPLICATIONS.WORKSPACE%TYPE;
	BEGIN
		if p_Apex_Workspace_Name IS NULL then
			select workspace
			into v_Workspace_Name
			from apex_applications
			where application_id = p_Application_ID;
		else 
			v_Workspace_Name := p_Apex_Workspace_Name;
		end if;
		v_workspace_id := apex_util.find_security_group_id (p_workspace => v_Workspace_Name);
		apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
$IF data_browser_schema.g_Use_Admin_Features $THEN 
		APEX_INSTANCE_ADMIN.UNRESTRICT_SCHEMA(p_schema => p_Schema_Name);
$END
$IF data_browser_schema.g_Use_Admin_Features $THEN 
		APEX_INSTANCE_ADMIN.ADD_SCHEMA(p_workspace => v_Workspace_Name, p_schema => p_Schema_Name);
$ELSE 
	DBMS_OUTPUT.PUT_LINE('Add the schema to the Workspace within the APEX ADMIN Page - Workspace to Schema Assignment');
$END
		COMMIT;
	EXCEPTION
	WHEN OTHERS THEN
		if SQLCODE <> -1 then
			RAISE;
		end if;
	END Add_Apex_Workspace_Schema;

	PROCEDURE Add_Schema (
		p_Schema_Name	VARCHAR2,
		p_Password		VARCHAR2 DEFAULT NULL
	)
	IS
		v_app_owner			VARCHAR2(100) := upper(p_Schema_Name);
		v_apex_schema		VARCHAR2(100);
		v_global_name		VARCHAR2(100);
		v_dba_schema		VARCHAR2(100)	:= SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		v_cnt INTEGER;
		v_Grantee_Name		VARCHAR2(50)	:= DBMS_ASSERT.ENQUOTE_NAME(p_Schema_Name);
		v_Password			VARCHAR2(50)	:= DBMS_ASSERT.ENQUOTE_NAME(p_Password, FALSE);
		v_User_Table_Space	VARCHAR2(50)	:= 'USERS';
		v_Temp_Table_Space	VARCHAR2(50)	:= 'TEMP';

		procedure Run_Stat( p_Stat VARCHAR2) is
		begin
			DBMS_OUTPUT.PUT_LINE(p_Stat || ';');
			EXECUTE IMMEDIATE p_Stat;
		end Run_Stat;

		PROCEDURE Run_DDL_Stat (
			p_Statement		IN CLOB,
			p_Allowed_Code	IN NUMBER DEFAULT 0,
			p_Allowed_Code2	 IN NUMBER DEFAULT 0,
			p_Allowed_Code3	 IN NUMBER DEFAULT 0
		)
		IS
		BEGIN
			DBMS_OUTPUT.PUT_LINE(p_Statement || ';');
			EXECUTE IMMEDIATE p_Statement;
		EXCEPTION
		WHEN OTHERS THEN
			-- ORA-01919: Rolle '...' nicht vorhanden
			-- ORA-01924: Rolle '...' wurde nicht gewährt oder ist nicht vorhanden
			-- ORA-01918: Benutzer '...' ist nicht vorhanden
			-- ORA-01921: Rolle '...' kollidiert mit anderem Benutzer- oder Rollennamen
			-- ORA-01031: Nicht ausreichende Berechtigungen
			-- ORA-01932: ADMIN-Berechtigung wurde für Rolle '...' nicht erteilt
			DBMS_OUTPUT.PUT_LINE('-- SQL Error :' || SQLCODE || ' ' || SQLERRM);
			if SQLCODE NOT IN (p_Allowed_Code, p_Allowed_Code2, p_Allowed_Code3) then
				RAISE;
			end if;
		END Run_DDL_Stat;

$IF DBMS_DB_VERSION.VERSION >= 12 and data_browser_schema.g_Use_Admin_Features $THEN
		PROCEDURE grant_connect (p_app_owner VARCHAR2)
		is
		begin
			DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
				host => '*.smtp',
				ace => xs$ace_type(privilege_list => xs$name_list('connect'),
								principal_name => p_app_owner,
								principal_type => xs_acl.ptype_db)
			);
		end grant_connect;
$ELSIF DBMS_DB_VERSION.VERSION >= 12 and data_browser_schema.g_Use_Admin_Features $THEN
		procedure grant_connect (p_app_owner VARCHAR2)
		is
			l_ACL_Path VARCHAR2(4000);
		begin
			SELECT ACL INTO l_ACL_Path FROM DBA_NETWORK_ACLS
			WHERE HOST = '*' AND LOWER_PORT IS NULL AND UPPER_PORT IS NULL;
			IF DBMS_NETWORK_ACL_ADMIN.CHECK_PRIVILEGE(l_ACL_Path, p_app_owner, 'connect') IS NULL THEN
				DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(l_ACL_Path, p_app_owner, TRUE, 'connect');
			END IF;
			COMMIT;
		exception
		  when NO_DATA_FOUND then
			DBMS_NETWORK_ACL_ADMIN.CREATE_ACL('smtp_users.xml',
				'ACL that lets users connect to smtp hosts', p_app_owner, TRUE, 'connect');
			DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL('smtp_users.xml','*.smtp');
			COMMIT;
		end grant_connect;
$ELSE
		procedure grant_connect (p_app_owner VARCHAR2)
		is
		begin
			COMMIT;
		end grant_connect;
$END

	begin
		SELECT table_owner INTO v_apex_schema
		FROM all_synonyms
		WHERE synonym_name = 'APEX'
		and owner = 'PUBLIC';
			
		SELECT GLOBAL_NAME INTO v_global_name
		FROM GLOBAL_NAME;
		
		if p_Password is not null then
			Run_DDL_Stat ('CREATE USER '|| v_Grantee_Name
					|| case when p_Password is not null then ' IDENTIFIED BY ' || v_Password end
					|| ' PROFILE DEFAULT ACCOUNT UNLOCK'
					|| ' DEFAULT TABLESPACE ' || DBMS_ASSERT.ENQUOTE_NAME(v_User_Table_Space)
					|| ' TEMPORARY TABLESPACE ' || DBMS_ASSERT.ENQUOTE_NAME(v_Temp_Table_Space),
					-1921, -1920);
		end if;
		Run_DDL_Stat ('ALTER USER ' || v_Grantee_Name
				|| ' PROFILE DEFAULT ACCOUNT UNLOCK'
				|| ' DEFAULT TABLESPACE ' || DBMS_ASSERT.ENQUOTE_NAME(v_User_Table_Space)
				|| ' TEMPORARY TABLESPACE ' || DBMS_ASSERT.ENQUOTE_NAME(v_Temp_Table_Space),
				-1921);
		Run_DDL_Stat ('ALTER USER ' || v_Grantee_Name || ' DEFAULT ROLE ALL ');
		Run_DDL_Stat ('GRANT UNLIMITED TABLESPACE TO '|| v_Grantee_Name);
		Run_DDL_Stat ('GRANT CONNECT TO '|| v_Grantee_Name);
		Run_DDL_Stat ('GRANT RESOURCE TO '|| v_Grantee_Name);

		Run_Stat('GRANT CREATE CLUSTER TO ' || v_app_owner);
		Run_Stat('GRANT CREATE DIMENSION TO ' || v_app_owner);
		Run_Stat('GRANT CREATE INDEXTYPE TO ' || v_app_owner);
		Run_Stat('GRANT CREATE JOB TO ' || v_app_owner);
		Run_Stat('GRANT CREATE MATERIALIZED VIEW TO ' || v_app_owner);
		Run_Stat('GRANT CREATE OPERATOR TO ' || v_app_owner);
		Run_Stat('GRANT CREATE PROCEDURE TO ' || v_app_owner);
		Run_Stat('GRANT CREATE SEQUENCE TO ' || v_app_owner);
		Run_Stat('GRANT CREATE SESSION TO ' || v_app_owner);
		Run_Stat('GRANT CREATE SYNONYM TO ' || v_app_owner);
		Run_Stat('GRANT CREATE TABLE TO ' || v_app_owner);
		Run_Stat('GRANT CREATE TRIGGER TO ' || v_app_owner);
		Run_Stat('GRANT CREATE TYPE TO ' || v_app_owner);
		Run_Stat('GRANT CREATE VIEW TO ' || v_app_owner);

		Run_Stat('GRANT EXECUTE ON SYS.DBMS_CRYPTO TO ' || v_app_owner);
		-- Run_Stat('GRANT EXECUTE ON SYS.DBMS_STATS TO ' || v_app_owner);
		-- monitoring of jobs
		Run_Stat('GRANT SELECT ON SYS.V_$LOCK TO ' || v_app_owner);
		Run_Stat('GRANT SELECT ON SYS.V_$SESSION TO ' || v_app_owner);

		-- changelog_gen
		Run_Stat('GRANT EXECUTE ON SYS.UTL_RECOMP TO ' || v_app_owner);
		Run_Stat('GRANT EXECUTE ON SYS.DBMS_REDEFINITION TO ' || v_app_owner);
		Run_Stat('GRANT SELECT ON SYS.DBA_REDEFINITION_ERRORS TO ' || v_app_owner);
		Run_Stat('GRANT SELECT_CATALOG_ROLE TO ' || v_app_owner);
		-- data_browser_check
		Run_Stat('GRANT SELECT ON SYS.V_$STATNAME TO ' || v_app_owner);
		Run_Stat('GRANT SELECT ON SYS.V_$MYSTAT TO ' || v_app_owner);
		-- chat room
		Run_Stat('GRANT EXECUTE ON SYS.DBMS_ALERT TO ' || v_app_owner);

		Run_Stat('GRANT CREATE JOB TO ' || v_app_owner);
		Run_Stat('GRANT EXECUTE ON CTXSYS.CTX_DDL TO ' || v_app_owner);
		Run_Stat ('GRANT CTXAPP TO '|| v_app_owner);	-- Use the Oracle Text PL/SQL packages
$IF data_browser_schema.g_Use_Admin_Features $THEN
		-- Schema Managment
        Run_DDL_Stat ('GRANT APEX_ADMINISTRATOR_ROLE TO ' || v_Grantee_Name );
        Run_DDL_Stat ('GRANT EXECUTE ON APEX_INSTANCE_ADMIN TO ' || v_Grantee_Name);
		-- CTX_INDEXES access is not permitted on Oracle CLoud
		Run_Stat ('GRANT SELECT ON CTXSYS.CTX_INDEXES TO '|| v_app_owner); -- used by wema_vpd_mgr
		-- Enable Update of lov_query and lov_data in User Interface Defaults
		Run_Stat('GRANT SELECT ON ' || v_apex_schema || '.WWV_FLOW_HNT_TABLE_INFO TO ' || v_app_owner);
		Run_Stat('GRANT SELECT,UPDATE ON ' || v_apex_schema || '.WWV_FLOW_HNT_COLUMN_INFO TO ' || v_app_owner);
		Run_Stat('GRANT SELECT,INSERT,UPDATE,DELETE ON ' || v_apex_schema || '.WWV_FLOW_HNT_LOV_DATA TO ' || v_app_owner);
		-- Install Supporting Objects 
		Run_Stat('GRANT EXECUTE ON ' || v_apex_schema || '.WWV_FLOW_INSTALL_WIZARD TO ' || v_app_owner);
		Run_Stat('CREATE OR REPLACE SYNONYM ' || v_app_owner || '.WWV_FLOW_INSTALL_WIZARD FOR ' || v_apex_schema || '.WWV_FLOW_INSTALL_WIZARD');
$END		
		-- Enable Send email
		SELECT COUNT(*) INTO v_cnt
		FROM ALL_OBJECTS 
		WHERE OWNER = 'CUSTOM_KEYS'
		AND OBJECT_NAME = 'SCHEMA_KEYCHAIN'
		AND OBJECT_TYPE = 'PACKAGE';
		if v_cnt = 1 then
			Run_Stat('GRANT EXECUTE ON SYS.UTL_TCP TO ' || v_app_owner);
			Run_Stat('GRANT EXECUTE ON SYS.UTL_SMTP TO ' || v_app_owner);
			-- crypto keystore
			Run_Stat('GRANT EXECUTE ON CUSTOM_KEYS.SCHEMA_KEYCHAIN TO ' || v_app_owner);
			Run_Stat('CREATE OR REPLACE SYNONYM ' || v_app_owner || '.SCHEMA_KEYCHAIN FOR CUSTOM_KEYS.SCHEMA_KEYCHAIN');
			-- access smtp parameter, add_schema 
			Run_Stat('GRANT EXECUTE ON ' || v_dba_schema || '.DATA_BROWSER_SCHEMA TO ' || v_app_owner);
			Run_Stat('CREATE OR REPLACE SYNONYM ' || v_app_owner || '.DATA_BROWSER_SCHEMA FOR DATA_BROWSER_SCHEMA');

$IF data_browser_schema.g_Use_Admin_Features $THEN
			SELECT COUNT(*) INTO v_cnt
			FROM DBA_NETWORK_ACL_PRIVILEGES
			WHERE UPPER(PRIVILEGE) = 'CONNECT' AND IS_GRANT = 'true'
			AND PRINCIPAL = v_app_owner;
			if v_cnt = 0 then
				grant_connect(v_app_owner);
				commit;
				DBMS_OUTPUT.PUT_LINE('DBMS_NETWORK_ACL_ADMIN - connect granted for ' || v_app_owner);
			end if;
			SELECT COUNT(*) INTO v_cnt
			FROM DBA_NETWORK_ACL_PRIVILEGES
			WHERE UPPER(PRIVILEGE) = 'CONNECT' AND IS_GRANT = 'true'
			AND PRINCIPAL = v_apex_schema;
			if v_cnt = 0 then
				grant_connect(v_apex_schema);
				commit;
				DBMS_OUTPUT.PUT_LINE('DBMS_NETWORK_ACL_ADMIN - connect granted for ' || v_apex_schema);
			end if;
$END
		end if;
	end Add_Schema;

	PROCEDURE Revoke_Schema (
		p_Schema_Name	VARCHAR2
	)
	IS
		l_app_owner VARCHAR2(100) := upper(p_Schema_Name);
		l_apex_schema VARCHAR2(100);
		l_cnt INTEGER;
		procedure Run_Stat( p_Stat VARCHAR2) is
		begin
			DBMS_OUTPUT.PUT_LINE(p_Stat || ';');
			EXECUTE IMMEDIATE p_Stat;
		EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('-- SQL Warning :' || SQLCODE || ' ' || SQLERRM);
			if SQLCODE not in (
				-1927, -- Sie können keine Berechtigungen entziehen, die Sie nicht erteilt haben.
				-1951, -- ROLE 'X' wurde 'Y' nicht erteilt
				-1952, -- Systemberechtigungen wurden 'WINDZ' nicht erteilt
				-942   -- Tabelle oder View nicht vorhanden
			)
			then
				RAISE;
			end if;
		end;
	begin
		SELECT table_owner INTO l_apex_schema
		FROM all_synonyms
		WHERE synonym_name = 'APEX'
		and owner = 'PUBLIC';

		Run_Stat('REVOKE EXECUTE ON SYS.DBMS_CRYPTO FROM ' || l_app_owner);
		Run_Stat('REVOKE EXECUTE ON SYS.UTL_RECOMP FROM ' || l_app_owner);
		Run_Stat('REVOKE EXECUTE ON SYS.DBMS_REDEFINITION FROM ' || l_app_owner);
		Run_Stat('REVOKE SELECT ON SYS.DBA_REDEFINITION_ERRORS FROM ' || l_app_owner);
		Run_Stat('REVOKE SELECT_CATALOG_ROLE FROM ' || l_app_owner);
	
		Run_Stat('REVOKE SELECT ON SYS.V_$STATNAME FROM ' || l_app_owner);
		Run_Stat('REVOKE SELECT ON SYS.V_$MYSTAT FROM ' || l_app_owner);

		Run_Stat('REVOKE EXECUTE ON SYS.DBMS_ALERT FROM ' || l_app_owner);
		-- Run_Stat('REVOKE EXECUTE ON SYS.UTL_FILE FROM ' || l_app_owner);
		Run_Stat('REVOKE CREATE JOB FROM ' || l_app_owner);
		Run_Stat('REVOKE EXECUTE ON CTXSYS.CTX_DDL FROM ' || l_app_owner);
		Run_Stat('REVOKE CTXAPP FROM ' || l_app_owner);
$IF data_browser_schema.g_Use_Admin_Features $THEN
		-- CTX_INDEXES access is not permitted on Oracle CLoud
		Run_Stat('REVOKE SELECT ON CTXSYS.CTX_INDEXES FROM ' || l_app_owner);

		RUN_STAT('DROP VIEW ' || l_app_owner || '.USER_UI_DEFAULTS_COLUMNS');
		RUN_STAT('DROP VIEW ' || l_app_owner || '.USER_UI_DEFAULTS_LOV_DATA');

		-- Enable Update of lov_query and lov_data in User Interface Defaults
		Run_Stat('REVOKE SELECT ON ' || l_apex_schema || '.WWV_FLOW_HNT_TABLE_INFO FROM ' || l_app_owner);
		Run_Stat('REVOKE SELECT,UPDATE ON ' || l_apex_schema || '.WWV_FLOW_HNT_COLUMN_INFO FROM ' || l_app_owner);
		Run_Stat('REVOKE SELECT,INSERT,UPDATE,DELETE ON ' || l_apex_schema || '.WWV_FLOW_HNT_LOV_DATA FROM ' || l_app_owner);
$END
		Run_Stat('REVOKE EXECUTE ON SYS.UTL_TCP FROM ' || l_app_owner);
		Run_Stat('REVOKE EXECUTE ON SYS.UTL_SMTP FROM ' || l_app_owner);
		Run_Stat('REVOKE EXECUTE ON CUSTOM_KEYS.SCHEMA_KEYCHAIN FROM ' || l_app_owner);
		-- Can not be executed by deinstaller - causes hanging session :
		--Run_Stat('REVOKE EXECUTE ON ' || l_apex_schema || '.WWV_FLOW_INSTALL_WIZARD FROM ' || l_app_owner);
		--RUN_STAT('DROP SYNONYM ' || l_app_owner || '.WWV_FLOW_INSTALL_WIZARD');
		
		-- access smtp parameter, add_schema 
		-- deadlock: Run_Stat('REVOKE EXECUTE ON DATA_BROWSER_SCHEMA FROM ' || l_app_owner);
		-- revoke for DBMS_NETWORK_ACL_ADMIN is missing
	end Revoke_Schema;


	FUNCTION Get_User_Access_Level (
		p_Schema_Name VARCHAR2,
		p_User_Name VARCHAR2
	) RETURN NUMBER
	IS
		v_User_Level NUMBER;
		v_Query VARCHAR2(1024);
		cv		SYS_REFCURSOR;
	BEGIN
		-- check that the user is permitted to edit table data.
		v_Query := 'select USER_LEVEL from ' 
		|| DBMS_ASSERT.ENQUOTE_NAME(p_Schema_Name)
		|| '.APP_USERS where upper_login_name = :a';
		OPEN cv FOR v_Query USING p_User_Name;
		FETCH cv INTO v_User_Level;
		CLOSE cv;
		return v_User_Level;
	exception
	  when others then
		if SQLCODE IN (-904, -942) then
			RETURN NULL;
		end if;
		raise;
	END Get_User_Access_Level;

	FUNCTION List_Schema (
		p_User_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_application_id IN NUMBER DEFAULT NV('APP_ID'),
		p_App_Version_Number IN VARCHAR2 DEFAULT NULL
	) RETURN Data_Browser_Schema_List_Tab PIPELINED
	IS
		s_cur  SYS_REFCURSOR;
		v_row Data_Browser_Schema_List_Rec; -- output row
    	v_stat VARCHAR2(32767);
	BEGIN
		for c_cur in (
			select /*+ RESULT_CACHE */ 
				A.owner,               
				sum(A.BYTES) USED_BYTES
			from APEX_WORKSPACE_SCHEMAS S
			join APEX_APPLICATIONS APP on S.WORKSPACE_NAME = APP.WORKSPACE
			join sys.DBA_SEGMENTS A on S.SCHEMA = A.OWNER
			join sys.DBA_TABLES B on A.owner = B.owner and B.table_name = 'DATA_BROWSER_CONFIG'
			join sys.DBA_TABLES C on A.owner = C.owner and C.table_name = 'VDATA_BROWSER_USERS'
			where APP.APPLICATION_ID = p_application_id
			group by A.owner
		) loop 
			v_stat := v_stat 
			|| case when v_stat IS NOT NULL then 
				chr(10)||'union all ' 
			end         
			|| 'select ' || dbms_assert.enquote_literal(c_cur.owner) || ' SCHEMA_NAME, A.APP_VERSION_NUMBER, '
			||  dbms_assert.enquote_literal(c_cur.USED_BYTES) || ' SPACE_USED_BYTES, B.USER_LEVEL,'
			||  'A.SCHEMA_ICON, A.DESCRIPTION, A.CONFIGURATION_NAME' || chr(10)
			|| 'from ' || c_cur.owner || '.DATA_BROWSER_CONFIG A, ' || c_cur.owner || '.VDATA_BROWSER_USERS B, param P'|| chr(10)
			|| 'where A.ID = 1 and B.UPPER_LOGIN_NAME = P.LOGIN_NAME';
		end loop;
		if v_stat IS NOT NULL then 
		v_stat := 'with param as (select :a LOGIN_NAME from dual) select * from (' || chr(10) || v_stat || chr(10) || ')';
		dbms_output.put_line(v_stat);
			open s_cur for v_stat using IN p_User_Name;
			loop
				FETCH s_cur INTO v_row;
				EXIT WHEN s_cur%NOTFOUND;
				if v_row.User_Access_Level <= 6
				and v_row.App_Version_Number >= NVL(p_App_Version_Number, v_row.App_Version_Number) then
					pipe row ( v_row );
				end if;
			end loop;
		end if;
		return;
	END List_Schema;
	-- usage : SELECT S.Schema_Name, S.Space_Used_Bytes, S.App_Version_Number, S.Description 
	-- FROM TABLE( sys.data_browser_schema.List_Schema(p_user_name => 'DIRK', p_application_id => 2000, p_App_Version_Number => '1.5.4') ) S;

	
	PROCEDURE Copy_Schema (
	  p_source_user		 IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
	  p_dest_user		 IN VARCHAR2,
	  p_dest_user_pwd	 IN VARCHAR2 DEFAULT NULL,
	  p_paral_lvl		 IN NUMBER	 DEFAULT 2,
	  p_database_link	 IN VARCHAR2 DEFAULT NULL, 
	  p_include_rows	 IN NUMBER	 DEFAULT 1 
	) 
	IS
		v_handle		NUMBER; -- job handle
		v_jobstate		user_datapump_jobs.state%TYPE; -- to hold job status
		v_global_name	VARCHAR2(100);
	BEGIN
		SELECT GLOBAL_NAME INTO v_global_name
		FROM GLOBAL_NAME;

		/* open a new schema level import job using our loopback DB link */
		v_handle := dbms_datapump.open ('IMPORT','SCHEMA', NVL(p_database_link, v_global_name));
		/* set parallel level */
		dbms_datapump.set_parallel(handle => v_handle, degree => p_paral_lvl);
		/* make any data copied consistent with respect to now */
$IF data_browser_schema.g_Use_Admin_Features $THEN
		dbms_datapump.set_parameter (v_handle, 'FLASHBACK_SCN', dbms_flashback.get_system_change_number);
$END
		/* DS: privilege grants to the exported schemas should also be part of the operation */
		dbms_datapump.set_parameter (v_handle, 'USER_METADATA', 1);
		/* DS: inhibits the assignment of the exported OID during type or table creation. Instead, a new OID will be assigned. */
		dbms_datapump.metadata_transform(v_handle, 'OID', 0);
		/* restrict to the schema we want to copy */
		dbms_datapump.metadata_filter (v_handle, 'SCHEMA_LIST', DBMS_ASSERT.ENQUOTE_LITERAL(p_source_user));
		/* remap the importing schema name to the schema we want to create */
		dbms_datapump.metadata_remap (v_handle,'REMAP_SCHEMA',p_source_user,p_dest_user);
		/* copy_data for each table or not 1 - yes 0 - meta data only */
		dbms_datapump.data_filter (v_handle, 'INCLUDE_ROWS', p_include_rows, NULL, NULL);
		/* start the job */
		dbms_datapump.start_job(v_handle);
		/* wait for the job to finish */
		dbms_datapump.wait_for_job(v_handle, v_jobstate);
		if p_dest_user_pwd IS NOT NULL then /* change the password for new user */
			EXECUTE IMMEDIATE 'ALTER USER ' || DBMS_ASSERT.ENQUOTE_NAME(p_dest_user) 
						|| ' IDENTIFIED BY ' || DBMS_ASSERT.ENQUOTE_NAME(p_dest_user_pwd, FALSE);
		end if;
	end Copy_Schema;	
	
	PROCEDURE Drop_Schema (
		p_Schema_Name VARCHAR2,
		p_Apex_Workspace_Name VARCHAR2 DEFAULT NULL,
		p_User_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER')
	)
	IS 
		v_workspace_id		NUMBER;
		v_Workspace_Name	APEX_APPLICATIONS.WORKSPACE%TYPE;
	BEGIN 
		if p_Apex_Workspace_Name IS NULL then
			select workspace
			into v_Workspace_Name
			from apex_applications
			where application_id = V('APP_ID');
		else 
			v_Workspace_Name := p_Apex_Workspace_Name;
		end if;
		if data_browser_schema.Get_User_Access_Level(p_Schema_Name => p_Schema_Name, p_User_Name => p_User_Name) <= 1 then
			v_workspace_id := apex_util.find_security_group_id (p_workspace => v_Workspace_Name);
			apex_util.set_security_group_id (p_security_group_id => v_workspace_id);

$IF data_browser_schema.g_Use_Admin_Features $THEN 
			APEX_INSTANCE_ADMIN.REMOVE_SCHEMA(v_Workspace_Name, p_Schema_Name);
$ELSE 
	DBMS_OUTPUT.PUT_LINE('Remove the schema from the Workspace within the APEX ADMIN Page - Workspace to Schema Assignment');
$END
			COMMIT;
			EXECUTE IMMEDIATE 'DROP USER ' || DBMS_ASSERT.ENQUOTE_NAME(p_Schema_Name) || ' CASCADE ' ;
			DBMS_OUTPUT.PUT_LINE('-- dropped Schema ' || p_Schema_Name || ' from Workspace ' || v_Workspace_Name);
		end if;
	END Drop_Schema;

	PROCEDURE Install_Data_Browser_App (
		p_workspace VARCHAR2,
		p_schema VARCHAR2,
		p_app_id VARCHAR2,
		p_app_alias VARCHAR2 DEFAULT NULL
	)
	is
		v_workspace_id		number;
		v_workspace_name	APEX_APPLICATIONS.WORKSPACE%TYPE;
		v_app_schema		APEX_APPLICATIONS.OWNER%TYPE;
		v_app_id			APEX_APPLICATIONS.APPLICATION_ID%TYPE;
		v_app_name			APEX_APPLICATIONS.APPLICATION_NAME%TYPE;
		v_app_alias			APEX_APPLICATIONS.ALIAS%TYPE;
		v_username			APEX_APPLICATIONS.OWNER%TYPE;
		v_workspace_name2	APEX_APPLICATIONS.WORKSPACE%TYPE;
	begin
		if p_workspace IS NULL or p_schema IS NULL or p_app_id IS NULL then 
			RAISE_APPLICATION_ERROR(-20001, 'Validation Error - parameter missing.');
		end if;
		v_workspace_name	:= UPPER(p_workspace);
		v_app_schema		:= UPPER(p_schema);
		v_app_id			:= TO_NUMBER(p_app_id);

		begin 
			select username into v_username 
			from ALL_USERS
			where username = v_app_schema;
		exception when NO_DATA_FOUND then
			RAISE_APPLICATION_ERROR(-20002, 'Validation Error - schema name : ' || v_app_schema || ' does not exist.');
		end;
		begin 
			select SCHEMA into v_username 
			from APEX_WORKSPACE_SCHEMAS
			where SCHEMA = v_app_schema
			and WORKSPACE_NAME = v_workspace_name;
		exception when NO_DATA_FOUND then
			RAISE_APPLICATION_ERROR(-20003, 'Validation Error - workspace to schema assignment does not exist');
		end;
	
		begin 
			select WORKSPACE into v_workspace_name2 
			from APEX_APPLICATIONS
			where APPLICATION_ID = v_app_id;
			if v_workspace_name != v_workspace_name2 then 
				RAISE_APPLICATION_ERROR(-20004, 'Validation Error - Application ID is used in a different workspace : ' || v_workspace_name2);		
			end if;
		exception when NO_DATA_FOUND then
			NULL;
		end;
		if v_app_id >= 3000 and v_app_id <= 8999 then
				RAISE_APPLICATION_ERROR(-20005, 'Validation Error - Application ID is in reserved range (3000 - 8999).');		
		end if;

		v_app_name := 'Data Browser (' || INITCAP(v_app_schema) || ')';
		v_app_alias :=	NVL(p_app_alias, 'DATA_BROWSER_' || v_app_schema);
		dbms_output.put_line('Installing Apex Application : ' || v_app_id || ' - ' || v_app_name);

		apex_application_install.set_workspace( v_workspace_name );
		apex_application_install.set_application_id( v_app_id );
		apex_application_install.generate_offset;
		apex_application_install.set_schema( v_app_schema );
		apex_application_install.set_application_name(v_app_name );
		apex_application_install.set_application_alias(v_app_alias);
		apex_application_install.set_auto_install_sup_obj( p_auto_install_sup_obj => true );
	end Install_Data_Browser_App;

	PROCEDURE Install_Data_Browser_Publish (
		p_workspace VARCHAR2,
		p_app_id VARCHAR2
	)
	is
		v_workspace_id		NUMBER;
		v_workspace_name	APEX_APPLICATIONS.WORKSPACE%TYPE;
		v_app_id			APEX_APPLICATIONS.APPLICATION_ID%TYPE;
	begin
		if p_workspace IS NULL or p_app_id IS NULL then 
			RAISE_APPLICATION_ERROR(-20001, 'Validation Error - parameter missing.');
		end if;
		v_workspace_name	:= UPPER(p_workspace);
		v_app_id			:= TO_NUMBER(p_app_id);
		v_workspace_id := apex_util.find_security_group_id (p_workspace => v_workspace_name);
		if v_workspace_id IS NULL then 
			return;
		end if;
		apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
		dbms_output.put_line('seed and publish translation for application_id : ' || v_app_id);
		apex_application_install.generate_offset; -- prevent error ORA-20001: Error during execution of wwv_flow_copy: WWV_FLOWS >> ORA-01722: Ungültige Zahl
		apex_lang.seed_translations(
			p_application_id => v_app_id,
			p_language => 'de' 
		);
		apex_lang.publish_application(
			p_application_id => v_app_id,
			p_language => 'de' 
		);

		commit;
	end Install_Data_Browser_Publish;
	
	PROCEDURE First_Run (
		p_Dest_Schema VARCHAR2,
		p_Admin_User VARCHAR2,
		p_Admin_Password VARCHAR2,	-- encrypted by data_browser_auth.Hex_Crypt
		p_Admin_EMail VARCHAR2,		-- encrypted by data_browser_auth.Hex_Crypt
		p_Add_Demo_Guest VARCHAR2
	)
	is
		v_First_Run VARCHAR2(2000);
	begin
		v_First_Run := 'begin '
			|| dbms_assert.enquote_name(p_Dest_Schema) || '.data_browser_auth.First_Run ('
			|| 'p_Admin_User => ' || dbms_assert.enquote_literal(p_Admin_User)
			|| ',p_Admin_Password => ' || dbms_assert.enquote_literal(p_Admin_Password)
			|| ',p_Admin_EMail => ' || dbms_assert.enquote_literal(p_Admin_EMail)
			|| ',p_Add_Demo_Guest => ' || dbms_assert.enquote_literal(p_Add_Demo_Guest)
			|| '); end;';
		EXECUTE IMMEDIATE v_First_Run;
	end First_Run;
	
end data_browser_schema;
/
declare 
	procedure Run_Stat( p_Stat VARCHAR2) is
	begin
		DBMS_OUTPUT.PUT_LINE(p_Stat || ';');
		EXECUTE IMMEDIATE p_Stat;
	end Run_Stat;
begin 
	for cur in (select owner from all_objects where object_name = 'DATA_BROWSER_CONF' and object_type = 'PACKAGE') loop 
		Run_Stat('GRANT EXECUTE ON DATA_BROWSER_SCHEMA TO ' || cur.owner);
		Run_Stat('CREATE OR REPLACE SYNONYM ' || cur.owner || '.DATA_BROWSER_SCHEMA FOR DATA_BROWSER_SCHEMA');
		IF data_browser_schema.g_Use_Admin_Features THEN
		-- Schema Managment
			Run_Stat ('GRANT APEX_ADMINISTRATOR_ROLE TO ' || cur.owner );
			Run_Stat ('GRANT EXECUTE ON APEX_INSTANCE_ADMIN TO ' || cur.owner);
		END IF;
    end loop;
end;
/
