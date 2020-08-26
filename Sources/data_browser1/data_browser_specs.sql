/*
Copyright 2020 Dirk Strack, Strack Software Development

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

set serveroutput on size unlimited

declare 
    v_Schema_Name VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    v_apex_schema VARCHAR2(128);
	v_update_apex_tables VARCHAR2(128);
	v_use_apex_installer VARCHAR2(128);
	v_use_dbms_crypt VARCHAR2(128);
	v_use_dbms_lock VARCHAR2(128);
	v_use_ctx_ddl VARCHAR2(128);
	v_use_key_chain VARCHAR2(128);
	v_use_custom_ctx VARCHAR2(128);
	v_use_data_reporter VARCHAR2(128);
	v_use_schema_tools VARCHAR2(128);
	v_stat VARCHAR2(32767);
begin
	SELECT table_owner INTO v_apex_schema
	FROM all_synonyms
	WHERE synonym_name = 'APEX'
	and owner = 'PUBLIC';

    dbms_output.put_line('-- creating packge data_browser_specs');
    dbms_output.put_line('-- current schema : ' || v_Schema_Name);
    dbms_output.put_line('-- apex schema    : ' || v_apex_schema);

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_update_apex_tables
	FROM SYS.ALL_TAB_PRIVS P
	WHERE P.TABLE_NAME = 'WWV_FLOW_HNT_LOV_DATA' 
	AND P.TABLE_SCHEMA = v_apex_schema
	AND P.GRANTEE = v_Schema_Name
	AND P.PRIVILEGE = 'INSERT';


	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_apex_installer
	FROM SYS.ALL_TAB_PRIVS P
	JOIN SYS.USER_SYNONYMS S ON P.TABLE_NAME = S.SYNONYM_NAME
	WHERE P.TABLE_NAME = 'WWV_FLOW_INSTALL_WIZARD' 
	AND P.GRANTEE = v_Schema_Name
	AND P.PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_dbms_crypt
	FROM SYS.ALL_TAB_PRIVS 
	WHERE TABLE_NAME = 'DBMS_CRYPTO' 
	AND TABLE_SCHEMA = 'SYS' 
	AND GRANTEE IN (v_Schema_Name, 'PUBLIC')
	AND PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_dbms_lock
	FROM SYS.ALL_TAB_PRIVS 
	WHERE TABLE_NAME = 'DBMS_LOCK' 
	AND TABLE_SCHEMA = 'SYS' 
	AND GRANTEE IN (v_Schema_Name, 'PUBLIC')
	AND PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_ctx_ddl
	FROM SYS.ALL_TAB_PRIVS 
	WHERE TABLE_NAME = 'CTX_DDL' 
	AND TABLE_SCHEMA = 'CTXSYS' 
	AND GRANTEE IN (v_Schema_Name, 'PUBLIC')
	AND PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_key_chain
	FROM SYS.ALL_TAB_PRIVS 
	WHERE TABLE_NAME = 'SCHEMA_KEYCHAIN' 
	AND TABLE_SCHEMA = 'CUSTOM_KEYS' 
	AND GRANTEE = v_Schema_Name
	AND PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_custom_ctx
	FROM SYS.ALL_TAB_PRIVS 
	WHERE TABLE_NAME = 'SET_CUSTOM_CTX' 
	AND TABLE_SCHEMA = 'CUSTOM_KEYS' 
	AND GRANTEE IN (v_Schema_Name, 'PUBLIC')
	AND PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_data_reporter
	FROM SYS.USER_TABLES 
	WHERE TABLE_NAME = 'EBA_DP_DATA_SOURCES';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_schema_tools
	FROM SYS.ALL_TAB_PRIVS P
	JOIN SYS.USER_SYNONYMS S ON P.TABLE_NAME = S.SYNONYM_NAME
	WHERE P.TABLE_NAME = 'DATA_BROWSER_SCHEMA' 
	AND P.GRANTEE = v_Schema_Name
	AND P.PRIVILEGE = 'EXECUTE';

	/* generate the package data_browser_spec to enable conditional compilation */

	v_stat := '
CREATE OR REPLACE PACKAGE data_browser_specs AUTHID DEFINER 
IS -- package for specifications of the available libraries in the current installation schema
	g_update_apex_tables		CONSTANT BOOLEAN	:= ' || v_update_apex_tables || ';
	g_use_apex_installer		CONSTANT BOOLEAN	:= ' || v_use_apex_installer || ';
	g_use_dbms_lock 			CONSTANT BOOLEAN	:= ' || v_use_dbms_lock || ';
	g_use_dbms_crypt 			CONSTANT BOOLEAN	:= ' || v_use_dbms_crypt || ';
	g_use_ctx_ddl 			    CONSTANT BOOLEAN	:= ' || v_use_ctx_ddl || ';
	g_use_crypt_key_chain 		CONSTANT BOOLEAN	:= ' || v_use_key_chain || ';
	g_use_custom_ctx 			CONSTANT BOOLEAN	:= ' || v_use_custom_ctx || ';
	g_use_data_reporter 		CONSTANT BOOLEAN	:= ' || v_use_data_reporter || ';		
	g_use_schema_tools 			CONSTANT BOOLEAN	:= ' || v_use_schema_tools || ';		
END data_browser_specs;
';
	EXECUTE IMMEDIATE v_Stat;
    dbms_output.put_line(v_Stat);
end;
/

