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
	v_use_ctx_ddl VARCHAR2(128);
	v_use_key_chain VARCHAR2(128);
	v_use_custom_ctx VARCHAR2(128);
	v_use_data_reporter VARCHAR2(128);
	v_use_schema_tools VARCHAR2(128);
	v_stat VARCHAR2(32767);
begin
	SELECT S.TABLE_OWNER apex_schema
	   , max(case when P.TABLE_NAME = 'WWV_FLOW_HNT_LOV_DATA' then 'TRUE' else 'FALSE' end) update_apex_tables
	   , max(case when P.TABLE_NAME = 'WWV_FLOW_INSTALL_WIZARD' then 'TRUE' else 'FALSE' end) use_apex_installer
	INTO v_apex_schema, v_update_apex_tables, v_use_apex_installer
	FROM SYS.ALL_SYNONYMS S
	LEFT OUTER JOIN SYS.ALL_TAB_PRIVS P
	ON P.TABLE_NAME IN ('WWV_FLOW_HNT_LOV_DATA', 'WWV_FLOW_INSTALL_WIZARD')
	AND P.TABLE_SCHEMA = S.TABLE_OWNER
	AND P.GRANTEE = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	AND P.PRIVILEGE IN ('INSERT', 'EXECUTE')
	WHERE S.synonym_name = 'APEX'
	AND S.owner = 'PUBLIC'
    GROUP BY S.TABLE_OWNER;

    dbms_output.put_line('-- creating package data_browser_specs');
    dbms_output.put_line('-- current schema : ' || v_Schema_Name);
    dbms_output.put_line('-- apex schema    : ' || v_apex_schema);

	SELECT max(case when TABLE_NAME = 'DBMS_CRYPTO' AND TABLE_SCHEMA = 'SYS' then 'TRUE' else 'FALSE' end) use_dbms_crypt
		   , max(case when TABLE_NAME = 'CTX_DDL' AND TABLE_SCHEMA = 'CTXSYS' then 'TRUE' else 'FALSE' end) use_ctx_ddl
		   , max(case when TABLE_NAME = 'SCHEMA_KEYCHAIN' AND TABLE_SCHEMA = 'CUSTOM_KEYS' then 'TRUE' else 'FALSE' end) use_key_chain
		   , max(case when TABLE_NAME = 'SET_CUSTOM_CTX' AND TABLE_SCHEMA = 'CUSTOM_KEYS' then 'TRUE' else 'FALSE' end) use_custom_ctx
		   , max(case when TABLE_NAME = 'DATA_BROWSER_SCHEMA' then 'TRUE' else 'FALSE' end) use_schema_tools
	INTO v_use_dbms_crypt, v_use_ctx_ddl, v_use_key_chain, v_use_custom_ctx, v_use_schema_tools
	FROM SYS.ALL_TAB_PRIVS 
	WHERE TABLE_NAME IN (
		'DBMS_CRYPTO', 'CTX_DDL', 'SCHEMA_KEYCHAIN', 'SET_CUSTOM_CTX', 
		'EBA_DP_DATA_SOURCES', 'DATA_BROWSER_SCHEMA')
	AND GRANTEE IN (SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'PUBLIC')
	AND PRIVILEGE = 'EXECUTE';

	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_data_reporter
	FROM SYS.USER_TABLES 
	WHERE TABLE_NAME = 'EBA_DP_DATA_SOURCES';

	/* generate the package data_browser_spec to enable conditional compilation */

	v_stat := '
CREATE OR REPLACE PACKAGE data_browser_specs AUTHID DEFINER 
IS -- package for specifications of the available libraries in the current installation schema
	g_update_apex_tables		CONSTANT BOOLEAN	:= ' || v_update_apex_tables || ';
	g_use_apex_installer		CONSTANT BOOLEAN	:= ' || v_use_apex_installer || ';
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

