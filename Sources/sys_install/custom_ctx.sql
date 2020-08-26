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
Package and trigger to manage your own application context
with current clients, user data, and access time.

i have learned from :
	http://jeffkemponoracle.com/2013/02/28/apex-and-application-contexts/


The following objects must be installed in the application schema with the script weco_auth.sql
	table  USER_NAMESPACES must exist -- used to manage namespaces for the applications
	View V_CONTEXT_USERS must exist -- used to access the user list
	View V_ERROR_PROTOCOL must exist -- used to register errors

The following Apex Application Item must be created in your application:
	APP_USER_ID -- current user identifier in view V_CONTEXT_USERS
	APP_USERLEVEL -- current user level
	APP_WORKSPACE -- current workspace name
	APP_QUERY_TIMESTAMP -- current query timestamp

Setting for Application / Edit Security Attributes /
	Database Session Initialization PL/SQL Code :
	set_custom_ctx.set_apex_context;


-- required privileges
GRANT CREATE ANY CONTEXT, CREATE PROCEDURE,
	CREATE TRIGGER, ADMINISTER DATABASE TRIGGER TO CUSTOM_KEYS;
GRANT EXECUTE ON SYS.UTL_HTTP TO CUSTOM_KEYS;
*/

CREATE OR REPLACE CONTEXT CUSTOM_CTX USING custom_keys.set_custom_ctx;

CREATE OR REPLACE PACKAGE custom_keys.set_custom_ctx
AUTHID  CURRENT_USER
IS
    g_TableWorkspaces  	CONSTANT VARCHAR2(32) := 'USER_NAMESPACES'; -- Tabelle Name for Custom Namspace
    g_ColumnWorkspace  	CONSTANT VARCHAR2(32) := 'WORKSPACE$_ID';   -- Column Name for Custom Namspace ID
	g_ColWorkspaceName  CONSTANT VARCHAR2(32) := 'WORKSPACE_NAME'; 	-- Column Name for Custom Namspace Name

    g_TableAppUsers  	CONSTANT VARCHAR2(32) := 'V_CONTEXT_USERS'; 	-- Tabelle Name for Custom Namspace User
    																	-- see weco_auth.sql for definition
    g_TableErrProtocol 	CONSTANT VARCHAR2(32) := 'V_ERROR_PROTOCOL'; 	-- Tabelle Name for Error Protocol
    																	-- see weco_auth.sql for definition
	g_CtxNamespace  	CONSTANT VARCHAR2(32) := 'CUSTOM_CTX';		-- Context Namespace
	g_CtxUserID		   	CONSTANT VARCHAR2(32) := 'USER_ID';			-- Context Parameter for current user identifier
	g_CtxUserName   	CONSTANT VARCHAR2(32) := 'USER_NAME';		-- Context Parameter for current user name
	g_CtxWorkspaceID    CONSTANT VARCHAR2(32) := 'WORKSPACE_ID'; 	-- Context Parameter for current Custom Namspace identifier
	g_CtxWorkspaceName  CONSTANT VARCHAR2(32) := 'WORKSPACE_NAME'; 	-- Context Parameter for current Custom Namspace Name
	g_CtxQueryTimestamp	CONSTANT VARCHAR2(32) := 'QUERY_TIMESTAMP';		-- Context Parameter for query timestamp

	g_User_Name_Item 	CONSTANT VARCHAR2(30) := 'APP_USER';		-- Existing Apex Item for current user identifier
	g_User_Id_Item 		CONSTANT VARCHAR2(30) := 'APP_USER_ID';		-- Apex Item for current user identifier
	g_User_Level_Item 	CONSTANT VARCHAR2(30) := 'APP_USERLEVEL';	-- Apex Item for current user level
	g_Workspace_Item 	CONSTANT VARCHAR2(30) := 'APP_WORKSPACE';	-- Apex Item for current workspace name
	g_Timestamp_Item 	CONSTANT VARCHAR2(32) := 'APP_QUERY_TIMESTAMP'; -- Apex Item for current query timestamp

	g_CtxDateFormat 	CONSTANT VARCHAR2(64)	:= 'DD.MM.YYYY HH24:MI:SS';
	g_CtxTimestampFormat CONSTANT VARCHAR2(64)	:= 'DD.MM.YYYY HH24.MI.SSXFF TZH:TZM';
	g_Log_Message_Query CONSTANT VARCHAR2(300)	:= 'INSERT INTO ' || g_TableErrProtocol || ' (DESCRIPTION, REMARKS) VALUES  (:a, :b)';
	g_Find_WSID_Query	CONSTANT VARCHAR2(200)	:=
		'SELECT ' || g_ColumnWorkspace || ' FROM ' || g_TableWorkspaces || ' WHERE ' || g_ColWorkspaceName || ' = UPPER(:a)';
	g_Insert_WS_Stat	CONSTANT VARCHAR2(200)	:=
		'INSERT INTO ' || g_TableWorkspaces || ' (' || g_ColWorkspaceName || ',  CREATED_BY)' ||
		' VALUES (UPPER(:a), :b) RETURNING (' || g_ColumnWorkspace || ') INTO :c';
	g_Find_User_Query 	CONSTANT VARCHAR2(200)	:=
		'SELECT USER_ID, USER_LEVEL, EMAIL_ADDRESS FROM ' || g_TableAppUsers || ' WHERE UPPER_LOGIN_NAME = :a';

	g_QueryTimestampFunction VARCHAR2(64) := 'set_custom_ctx.Get_Query_Timestamp';
    -- Context Expression for current Namespace
    g_ContextWorkspaceIDExpr VARCHAR2(128)   := 'SYS_CONTEXT(' || DBMS_ASSERT.ENQUOTE_LITERAL(g_CtxNamespace) || ', ' || DBMS_ASSERT.ENQUOTE_LITERAL(g_CtxWorkspaceID) || ')';
    -- Context Expression for current User default
    g_ContextUserNameExpr   VARCHAR2(128)   := 'SYS_CONTEXT(' || DBMS_ASSERT.ENQUOTE_LITERAL(g_CtxNamespace) || ', ' || DBMS_ASSERT.ENQUOTE_LITERAL(g_CtxUserName) || ')';

    g_ContextUserIDExpr   VARCHAR2(128)   := 'SYS_CONTEXT(' || DBMS_ASSERT.ENQUOTE_LITERAL(g_CtxNamespace) || ', ' || DBMS_ASSERT.ENQUOTE_LITERAL(g_CtxUserID) || ')';

    g_debug         	NUMBER          := 0;	-- Enable logging in table APP_PROTOCOL

	TYPE cur_type IS REF CURSOR;

    FUNCTION Get_CtxNamespace RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Ctx_Date_Format RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Ctx_Timestamp_Format RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Context_WorkspaceID_Expr RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Context_User_Name_Expr RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Context_User_ID_Expr RETURN VARCHAR2 DETERMINISTIC;

	PROCEDURE Set_Default_Workspace (
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	);

	PROCEDURE Set_Current_Workspace (
   		p_Workspace_Name	IN VARCHAR2,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	);

	PROCEDURE Set_New_Workspace (
   		p_Workspace_Name	IN VARCHAR2,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	);

	PROCEDURE Set_Current_User (
		p_User_Name		IN VARCHAR2,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
	);

	PROCEDURE Set_Query_Timestamp (
   		p_Timestamp		IN TIMESTAMP,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	);

	PROCEDURE Set_Query_Date (
   		p_DateTime		IN DATE,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	);

	FUNCTION Get_Query_Timestamp RETURN TIMESTAMP;
	FUNCTION Get_Query_Timestamp_Function RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Get_Context_Workspace_Name RETURN VARCHAR2;
	FUNCTION Get_Context_Workspace_ID RETURN NUMBER;
    FUNCTION Get_Current_Workspace_ID RETURN NUMBER;
	FUNCTION Get_Context_User_Name RETURN VARCHAR2;
    FUNCTION Get_Current_User_Name RETURN VARCHAR2;

	PROCEDURE Post_Db_Logon;

	PROCEDURE Post_Apex_Logon;

	PROCEDURE Set_Apex_Context;

	PROCEDURE Clear_Context (
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	);

   	PROCEDURE Log_Message (
   		p_CODE		IN VARCHAR2,
   		p_MESSAGE	IN VARCHAR2
   	);
 END set_custom_ctx;
/
show errors

CREATE OR REPLACE PACKAGE BODY custom_keys.set_custom_ctx IS
    FUNCTION Get_CtxNamespace RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_CtxNamespace; END;
	FUNCTION Get_Ctx_Date_Format RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_CtxDateFormat; END;
	FUNCTION Get_Ctx_Timestamp_Format RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_CtxTimestampFormat; END;
    FUNCTION Get_Context_WorkspaceID_Expr RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ContextWorkspaceIDExpr; END;
    FUNCTION Get_Context_User_Name_Expr   RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ContextUserNameExpr; END;
    FUNCTION Get_Context_User_ID_Expr RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ContextUserIDExpr; END;

	PROCEDURE Set_Existing_Apex_Item(
		p_Item_Name VARCHAR2,
		p_Item_Value VARCHAR2
	)
	IS
		v_Count			PLS_INTEGER;
	BEGIN
		select count(*)
		into v_Count
		from APEX_APPLICATION_ITEMS
		where APPLICATION_ID = V('APP_ID')
		and ITEM_NAME = p_Item_Name;
		if v_Count > 0 then
			APEX_UTIL.SET_SESSION_STATE(p_Item_Name, p_Item_Value);
		end if;	
	END;
	
	PROCEDURE Set_Default_Workspace (
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
   	IS
        v_Schema_Name       VARCHAR2(50) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
   	BEGIN
		if p_Client_Id IS NOT NULL and APEX_UTIL.GET_SESSION_STATE(g_Workspace_Item) IS NULL then
			Set_Existing_Apex_Item(g_Workspace_Item, v_Schema_Name);
		end if;   	
   	END;
   	
	PROCEDURE Set_Current_Workspace (
   		p_Workspace_Name	IN VARCHAR2,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Workspace_Id NUMBER := NULL;
		v_Workspace_Name VARCHAR2(50) := UPPER(p_Workspace_Name);
		v_App_User		VARCHAR2(50);
   		cv 				cur_type;
		v_TimestampString VARCHAR2(64);
        v_Schema_Name       VARCHAR2(50) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
	BEGIN
		OPEN cv FOR g_Find_WSID_Query USING v_Workspace_Name;
		FETCH cv INTO v_Workspace_Id;
		IF cv%NOTFOUND THEN
			if v_Workspace_Name = v_Schema_Name then
				v_App_User := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER);
				EXECUTE IMMEDIATE g_Insert_WS_Stat
				USING IN v_Workspace_Name, v_App_User, OUT v_Workspace_Id;
			else 
				clear_context(p_Client_Id);
				return;
			end if;
		END IF;
		CLOSE cv;
		COMMIT;
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxWorkspaceID, v_Workspace_Id, p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxWorkspaceName, v_Workspace_Name, p_Client_Id);
		v_TimestampString := TO_CHAR(CURRENT_TIMESTAMP, g_CtxTimestampFormat);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxQueryTimestamp, v_TimestampString, p_Client_Id);

		if p_Client_Id IS NOT NULL then
			Set_Existing_Apex_Item(g_Workspace_Item, v_Workspace_Name);
		end if;
	EXCEPTION
	WHEN OTHERS THEN
		Log_Message(SQLCODE, SQLERRM);
		Log_Message('set_current_workspace', '(' || p_Workspace_Name || ', ' || p_Client_Id || ') failed!' );
		clear_context(p_Client_Id);
	END;

	PROCEDURE Set_New_Workspace (
   		p_Workspace_Name	IN VARCHAR2,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Workspace_Id NUMBER := NULL;
		v_Workspace_Name VARCHAR2(50) := UPPER(p_Workspace_Name);
		v_App_User		VARCHAR2(50);
   		cv 				cur_type;
		v_TimestampString VARCHAR2(64);
	BEGIN
		OPEN cv FOR g_Find_WSID_Query USING v_Workspace_Name;
		FETCH cv INTO v_Workspace_Id;
		IF cv%NOTFOUND THEN
			v_App_User := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER);
			EXECUTE IMMEDIATE g_Insert_WS_Stat
			USING IN v_Workspace_Name, v_App_User, OUT v_Workspace_Id;
		END IF;
		CLOSE cv;
		COMMIT;
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxWorkspaceID, v_Workspace_Id, p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxWorkspaceName, v_Workspace_Name, p_Client_Id);
		v_TimestampString := TO_CHAR(CURRENT_TIMESTAMP, g_CtxTimestampFormat);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxQueryTimestamp, v_TimestampString, p_Client_Id);
		if p_Client_Id IS NOT NULL then
			Set_Existing_Apex_Item(g_Workspace_Item, v_Workspace_Name);
		end if;
	EXCEPTION
	WHEN OTHERS THEN
		Log_Message('set_new_workspace', '(' || p_Workspace_Name || ', ' || p_Client_Id || ') failed!' );
		clear_context(p_Client_Id);
	END;


	PROCEDURE Set_Current_User (
   		p_User_Name		IN VARCHAR2,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
	IS
		v_User_Id 		VARCHAR2(100);
		v_User_Name		VARCHAR2(300);
		v_Userlevel 	INTEGER;
		v_User_Email 	VARCHAR2(300);
		v_Csv_Charset	VARCHAR2(300);
   		cv 				cur_type;
	BEGIN
		v_User_Name := UPPER(p_User_Name);
		UTL_HTTP.GET_BODY_CHARSET (v_Csv_Charset);
		begin
			OPEN cv FOR g_Find_User_Query USING v_User_Name;
			FETCH cv INTO v_User_Id, v_Userlevel, v_User_Email;
			if cv%NOTFOUND then
				v_User_Id 	:= APEX_UTIL.GET_USER_ID(v_User_Name);
				v_User_Email := APEX_UTIL.GET_EMAIL(v_User_Name);
				v_Userlevel := 5;
			end if;
			CLOSE cv;
		exception
		when OTHERS then
			Log_Message(SQLCODE, SQLERRM);
			Log_Message('set_current_user', '(' || p_User_Name || ', ' || p_Client_Id || ') failed!' );
		end;
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxUserID, 		v_User_Id, 		p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxUserName, 	v_User_Name, 	p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, 'USERLEVEL', 	v_Userlevel, 	p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, 'USER_EMAIL', 	v_User_Email, 	p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, 'CSV_CHARSET', 	v_Csv_Charset, 	p_Client_Id);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, 'CLIENT_IDENTIFIER', p_Client_Id, p_Client_Id);
		if p_Client_Id IS NOT NULL then
			Set_Existing_Apex_Item(g_User_Id_Item, v_User_Id);
			Set_Existing_Apex_Item(g_User_Level_Item, v_Userlevel);
		end if;
	END;

	PROCEDURE Set_Query_Timestamp (
   		p_Timestamp		IN TIMESTAMP,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
	IS
		v_TimestampString VARCHAR2(64);
	BEGIN
		v_TimestampString := TO_CHAR(CAST(p_Timestamp AS TIMESTAMP WITH TIME ZONE), g_CtxTimestampFormat);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxQueryTimestamp, v_TimestampString, p_Client_Id);
		if p_Client_Id IS NOT NULL then
			Set_Existing_Apex_Item(g_Timestamp_Item, v_TimestampString);
		end if;
	END;

	PROCEDURE Set_Query_Date (
   		p_DateTime		IN DATE,
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
	IS
		v_TimestampString VARCHAR2(64);
	BEGIN
		v_TimestampString := TO_CHAR(CAST(p_DateTime AS TIMESTAMP WITH TIME ZONE) + NUMTODSINTERVAL(0.999999999, 'SECOND'), g_CtxTimestampFormat);
		DBMS_SESSION.SET_CONTEXT(g_CtxNamespace, g_CtxQueryTimestamp, v_TimestampString, p_Client_Id);
		if p_Client_Id IS NOT NULL then
			Set_Existing_Apex_Item(g_Timestamp_Item, v_TimestampString);
		end if;
	END;


	FUNCTION Get_Query_Timestamp RETURN TIMESTAMP
	IS
	BEGIN
		RETURN NVL(TO_TIMESTAMP_TZ(SYS_CONTEXT(g_CtxNamespace, g_CtxQueryTimestamp), g_CtxTimestampFormat), CURRENT_TIMESTAMP);
	END;

	FUNCTION Get_Query_Timestamp_Function RETURN VARCHAR2 DETERMINISTIC
	IS
	BEGIN
		RETURN g_QueryTimestampFunction;
	END;

	FUNCTION Get_Context_Workspace_Name RETURN VARCHAR2 IS BEGIN RETURN SYS_CONTEXT(g_CtxNamespace, g_CtxWorkspaceName); END;
	FUNCTION Get_Context_Workspace_ID RETURN NUMBER IS BEGIN RETURN SYS_CONTEXT(g_CtxNamespace, g_CtxWorkspaceID); END;

    FUNCTION Get_Current_Workspace_ID RETURN NUMBER
    IS
        v_Workspace_ID      NUMBER := SYS_CONTEXT(g_CtxNamespace, g_CtxWorkspaceID);
    BEGIN
        if v_Workspace_ID IS NULL then
            RAISE_APPLICATION_ERROR (-20000, 'SYS_CONTEXT (' || g_CtxNamespace || ',' || g_CtxWorkspaceID || ') is not initialized.' );
        end if;
        RETURN v_Workspace_ID;
    END;

	FUNCTION Get_Context_User_Name RETURN VARCHAR2 IS BEGIN RETURN SYS_CONTEXT(g_CtxNamespace, g_CtxUserName); END;

    FUNCTION Get_Current_User_Name RETURN VARCHAR2
    IS
        v_User_Name      VARCHAR2(50) := NVL(SYS_CONTEXT(g_CtxNamespace, g_CtxUserName), USER);
    BEGIN
        if v_User_Name IS NULL then
            RAISE_APPLICATION_ERROR (-20001, 'SYS_CONTEXT (' || g_CtxNamespace || ',' || g_CtxUserName || ') is not initialized.' );
        end if;
        RETURN v_User_Name;
    END;

	PROCEDURE Post_Db_Logon
	IS
		v_Workspace_Name	VARCHAR2(50)  := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		v_User_Name		VARCHAR2(50)  := SYS_CONTEXT('USERENV', 'SESSION_USER');
		v_Client_Id 	VARCHAR2(200) := SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	BEGIN
		v_Client_Id := REPLACE(v_Client_Id, 'nobody', v_User_Name);
		set_current_workspace(v_Workspace_Name, v_Client_Id);
		set_current_user(v_User_Name, v_Client_Id);
		COMMIT;
		if g_debug > 0 then
			Log_Message('Post_Db_Logon', '(' || v_Workspace_Name || ', ' || v_User_Name || ', ' || v_Client_Id || ')' );
		end if;
	END;

	PROCEDURE Post_Apex_Logon
	IS
		v_Workspace_Name	VARCHAR2(50) := V(g_Workspace_Item);
		v_User_Name		VARCHAR2(50) := SYS_CONTEXT('APEX$SESSION','APP_USER');
		v_Client_Id 	VARCHAR2(200) := SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	BEGIN
		v_Client_Id := REPLACE(v_Client_Id, 'nobody', v_User_Name);
		if v_Workspace_Name IS NULL then
			RAISE_APPLICATION_ERROR (-20010, g_Workspace_Item || ' is not initialized.' );
		end if;
		set_current_workspace(v_Workspace_Name, v_Client_Id);
		set_current_user(v_User_Name, v_Client_Id);
		COMMIT;
		if g_debug > 0 then
			Log_Message('Post_Apex_Logon', '(' || v_Workspace_Name || ', ' || v_User_Name || ', ' || v_Client_Id || ')' );
		end if;
	END;

	PROCEDURE Set_Apex_Context
	IS
		v_User_Name 		VARCHAR2(50) := V(g_User_Name_Item);
		v_Workspace_Name 	VARCHAR2(50) := V(g_Workspace_Item);
		v_TimestampString 	VARCHAR2(64) := V(g_Timestamp_Item);
		v_Client_Id 	VARCHAR2(200) := SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	BEGIN
		v_Client_Id := REPLACE(v_Client_Id, 'nobody', v_User_Name);
		if v_Workspace_Name IS NOT NULL then
			Set_Current_Workspace(v_Workspace_Name, v_Client_Id);
			Set_Current_User(v_User_Name, v_Client_Id);
		end if;
		if v_TimestampString IS NOT NULL then
			Set_Query_Timestamp(TO_TIMESTAMP_TZ(v_TimestampString, g_CtxTimestampFormat), v_Client_Id);
		end if;
		if g_debug > 0 then
			Log_Message('Set_Apex_Context', '(' || v_Workspace_Name || ', ' || v_User_Name || ', ' || v_Client_Id || ')' );
		end if;
	END;

	PROCEDURE Clear_Context(
   		p_Client_Id 	IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
   	)
	IS
	BEGIN
		DBMS_SESSION.CLEAR_CONTEXT(g_CtxNamespace, p_Client_Id);
	END;

   	PROCEDURE Log_Message (
   		p_CODE		IN VARCHAR2,
   		p_MESSAGE	IN VARCHAR2
   	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Subject VARCHAR2(40) := SUBSTR('CUSTOM_CTX: ' || p_CODE, 1, 40);
		v_Info	VARCHAR2(300) := SUBSTR(p_MESSAGE, 1, 300);
	BEGIN
		-- DBMS_OUTPUT.PUT_LINE('CODE:' || v_Subject);
		-- DBMS_OUTPUT.PUT_LINE('MESSAGE:' || v_Info);
		if SYS_CONTEXT(g_CtxNamespace, g_CtxWorkspaceID) IS NOT NULL
		and SYS_CONTEXT(g_CtxNamespace, g_CtxUserName) IS NOT NULL then
			EXECUTE IMMEDIATE g_Log_Message_Query
			USING IN v_Subject, v_Info;

			COMMIT;
		end if;
	EXCEPTION
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE(g_Log_Message_Query || ' - failed with ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
		NULL;
	END;

END set_custom_ctx;
/
show errors

GRANT EXECUTE ON custom_keys.set_custom_ctx TO PUBLIC;
CREATE OR REPLACE PUBLIC SYNONYM set_custom_ctx FOR custom_keys.set_custom_ctx;

/*
-- uninstall
DROP TRIGGER set_custom_ctx_trig;
DROP PACKAGE set_custom_ctx;
DROP PUBLIC SYNONYM set_custom_ctx;
DROP TABLE App_Protocol;

-- Session untersuchen !!!! --
call DBMS_SESSION.set_identifier('DIRK:2844010113657');
SELECT V('APP_USER') FROM DUAL;

begin apex_session.attach (
	p_app_id => 100, 
	p_page_id => 1, 
	p_session_id => 11253944187345 );
end;
/

SET SERVEROUTPUT ON
SET LONG 2000000
SET PAGESIZE 0

call set_custom_ctx.set_current_workspace(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));
call set_custom_ctx.set_current_user(SYS_CONTEXT('USERENV', 'SESSION_USER'));


call set_custom_ctx.post_apex_logon();
call set_custom_ctx.post_db_logon();
call set_custom_ctx.set_apex_context();
call set_custom_ctx.Set_Query_Date(SYSDATE);
SELECT 	SYS_CONTEXT('CUSTOM_CTX', 'USER_ID') USER_ID,
		SYS_CONTEXT('CUSTOM_CTX', 'USER_NAME') USER_NAME,
		SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_ID') WORKSPACE_ID,
		SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME') WORKSPACE_NAME,
		SYS_CONTEXT('CUSTOM_CTX', 'USERLEVEL') USERLEVEL,
		SYS_CONTEXT('CUSTOM_CTX', 'USER_EMAIL') USER_EMAIL,
		SYS_CONTEXT('CUSTOM_CTX', 'CSV_CHARSET') CSV_CHARSET,
		SYS_CONTEXT('CUSTOM_CTX', 'CLIENT_IDENTIFIER') CLIENT_IDENTIFIER,
		SYS_CONTEXT('CUSTOM_CTX', 'QUERY_TIMESTAMP') QUERY_TIMESTAMP
FROM DUAL;

SELECT * FROM SESSION_CONTEXT ORDER BY 1,2;

*/
