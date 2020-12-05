/*
Copyright 2017-2019 Dirk Strack

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
Plugin for checking that a table row is deletable.

- Plugin Callbacks:
- Execution Function Name: delete_check_plugin.Process_Row_Is_Deletable
	attribute_01 : Table Owner
	attribute_02 : *Table Name
	attribute_03 : *Primary Key Column
	attribute_04 : *Primary Key Item
	attribute_05 : Secondary Key Column
	attribute_06 : Secondary Key Item
	attribute_07 : *Is Deletable Item

*/
-- Grant this role to allow users SELECT privileges on data dictionary views.
-- GRANT SELECT_CATALOG_ROLE TO HR;
-- Grant this role to allow users EXECUTE privileges for packages and procedures in the data dictionary.
-- GRANT EXECUTE_CATALOG_ROLE TO HR;



create or replace type CLOB_AGG_TYPE
AUTHID CURRENT_USER
AS OBJECT
(
   total clob,

   static function
		ODCIAggregateInitialize(sctx IN OUT CLOB_agg_type )
		return number,

   member function
		ODCIAggregateIterate(self IN OUT CLOB_agg_type ,
							 value IN clob )
		return number,

   member function
		ODCIAggregateTerminate(self IN CLOB_agg_type,
							   returnValue OUT  clob,
							   flags IN number)
		return number,

   member function
		ODCIAggregateMerge(self IN OUT CLOB_agg_type,
						   ctx2 IN CLOB_agg_type)
		return number
);
/
show errors


create or replace type body CLOB_AGG_TYPE
is

	static function ODCIAggregateInitialize(sctx IN OUT CLOB_agg_type)
	return number
	is
	begin
	    sctx := CLOB_agg_type( null );
	    return ODCIConst.Success;
	end;

	member function ODCIAggregateIterate(self IN OUT CLOB_agg_type,
	                                     value IN clob )
	return number
	is
	begin
	    self.total := self.total || ', ' || value;
	    return ODCIConst.Success;
	end;

	member function ODCIAggregateTerminate(self IN CLOB_agg_type,
	                                       returnValue OUT clob,
	                                       flags IN number)
	return number
	is
	begin
	    returnValue := ltrim(self.total,', ');
	    return ODCIConst.Success;
	end;

	member function ODCIAggregateMerge(self IN OUT CLOB_agg_type,
	                                   ctx2 IN CLOB_agg_type)
	return number
	is
	begin
	    self.total := self.total || ctx2.total;
	    return ODCIConst.Success;
	end;
end;
/
show errors

CREATE or REPLACE FUNCTION CLOBAGG(input clob )
RETURN clob
AUTHID CURRENT_USER
PARALLEL_ENABLE AGGREGATE USING CLOB_agg_type;
/
show errors


CREATE OR REPLACE VIEW V_DELETE_CHECK (R_OWNER, R_TABLE_NAME, SUBQUERY)
 AS
SELECT R_OWNER, R_TABLE_NAME,
	STAT_INTRO || REPLACE(CLOBAGG(SUBQUERY), ', ', chr(10) || '  and not exists') SUBQUERY
FROM (
	SELECT R_OWNER1 R_OWNER,
		R_TABLE_NAME1 R_TABLE_NAME,
		' from ' || case when R_OWNER1 != CURRENT_SCHEMA then DBMS_ASSERT.ENQUOTE_NAME(R_OWNER1) || '.' end
		|| DBMS_ASSERT.ENQUOTE_NAME(R_TABLE_NAME1) || ' A ' || chr(10) || 'where not exists' STAT_INTRO,
		SUBQUERY
	FROM (
			SELECT
				CONNECT_BY_ROOT R_CONSTRAINT_NAME R_CONSTRAINT_NAME1,
				CONNECT_BY_ROOT R_OWNER R_OWNER1,
				CONNECT_BY_ROOT R_TABLE_NAME R_TABLE_NAME1,
				OWNER,
				TABLE_NAME,
				DELETE_RULE,
				CURRENT_SCHEMA,
				SYS_CONNECT_BY_PATH(
					'select 1 from '
					|| case when OWNER != CURRENT_SCHEMA then DBMS_ASSERT.ENQUOTE_NAME(OWNER) || '.' end
					|| DBMS_ASSERT.ENQUOTE_NAME(TABLE_NAME) || ' ' || CHR(65+LEVEL)
					|| case when TABLE_NAME = R_TABLE_NAME and DELETE_RULE = 'CASCADE' then -- Hierarchical Dependence
						' where exists '
				   else
					  ' where '
						|| REPLACE(REPLACE(JOIN_COND, 'X.', CHR(65+LEVEL-1)||'.'), 'Y.', CHR(65+LEVEL)||'.')
						|| case when CONNECT_BY_ISLEAF = 0 then ' and exists ' end
					end,
					' ( '
				)
				|| SYS_CONNECT_BY_PATH(
					case when TABLE_NAME = R_TABLE_NAME and DELETE_RULE = 'CASCADE' then -- Hierarchical Dependence
						RPAD(CHR(10), 19, ' ')
						|| ' connect by nocycle ' || REPLACE(REPLACE(JOIN_COND, 'X.', ' prior ' || CHR(65+LEVEL)||'.'), 'Y.', CHR(65+LEVEL)||'.')
						|| ' start with ' || REPLACE(REPLACE(JOIN_COND, 'X.', CHR(65+LEVEL-1)||'.'), 'Y.', CHR(65+LEVEL)||'.')
					end,
					' ) '
				) SUBQUERY
			FROM (
				SELECT A.CONSTRAINT_NAME, A.OWNER OWNER, A.TABLE_NAME, A.DELETE_RULE,
					C.CONSTRAINT_NAME R_CONSTRAINT_NAME, C.OWNER R_OWNER, C.TABLE_NAME R_TABLE_NAME,
					SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') CURRENT_SCHEMA,
					LISTAGG('Y.' || DBMS_ASSERT.ENQUOTE_NAME(B.COLUMN_NAME) || ' = ' || 'X.' || DBMS_ASSERT.ENQUOTE_NAME(D.COLUMN_NAME), ' and ')
						WITHIN GROUP (ORDER BY B.POSITION) JOIN_COND
				FROM SYS.ALL_CONSTRAINTS A
				JOIN SYS.ALL_CONSTRAINTS C ON A.R_CONSTRAINT_NAME = C.CONSTRAINT_NAME AND C.OWNER = A.OWNER
				JOIN SYS.ALL_CONS_COLUMNS B ON A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.OWNER = B.OWNER
				JOIN SYS.ALL_CONS_COLUMNS D ON C.CONSTRAINT_NAME = D.CONSTRAINT_NAME AND C.OWNER = D.OWNER AND B.POSITION = D.POSITION
				WHERE C.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
				AND A.CONSTRAINT_TYPE = 'R'
				AND A.STATUS = 'ENABLED'
				AND C.CONSTRAINT_TYPE IN ('P', 'U')
				AND C.STATUS = 'ENABLED'
				GROUP BY A.CONSTRAINT_NAME, A.OWNER, A.TABLE_NAME, A.DELETE_RULE, C.CONSTRAINT_NAME, C.OWNER, C.TABLE_NAME
                UNION 
				SELECT 
                    A.CONSTRAINT_NAME, A.OWNER, A.TABLE_NAME, A.DELETE_RULE,
					C.CONSTRAINT_NAME R_CONSTRAINT_NAME, C.OWNER R_OWNER, C.TABLE_NAME R_TABLE_NAME,
					SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') CURRENT_SCHEMA,
					LISTAGG('Y.' || DBMS_ASSERT.ENQUOTE_NAME(B.COLUMN_NAME) || ' = ' || 'X.' || DBMS_ASSERT.ENQUOTE_NAME(D.COLUMN_NAME), ' and ')
						WITHIN GROUP (ORDER BY B.POSITION) JOIN_COND
				FROM SYS.ALL_CONSTRAINTS A
				JOIN SYS.ALL_CONSTRAINTS C ON A.R_CONSTRAINT_NAME = C.CONSTRAINT_NAME AND C.OWNER = A.OWNER
				JOIN SYS.ALL_CONS_COLUMNS B ON A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.OWNER = B.OWNER
				JOIN SYS.ALL_CONS_COLUMNS D ON C.CONSTRAINT_NAME = D.CONSTRAINT_NAME AND C.OWNER = D.OWNER AND B.POSITION = D.POSITION
				JOIN SYS.USER_TAB_PRIVS P ON P.TABLE_NAME = C.TABLE_NAME AND P.OWNER = C.OWNER AND P.PRIVILEGE = 'SELECT'
				WHERE P.GRANTEE = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
				AND A.CONSTRAINT_TYPE = 'R'
				AND A.STATUS = 'ENABLED'
				AND C.CONSTRAINT_TYPE IN ('P', 'U')
				AND C.STATUS = 'ENABLED'
				GROUP BY A.CONSTRAINT_NAME, A.OWNER, A.TABLE_NAME, A.DELETE_RULE, C.CONSTRAINT_NAME, C.OWNER, C.TABLE_NAME
			) A
			WHERE CONNECT_BY_ISLEAF = 1 AND DELETE_RULE = 'NO ACTION'
			CONNECT BY NOCYCLE R_TABLE_NAME = PRIOR TABLE_NAME AND PRIOR DELETE_RULE = 'CASCADE'
	) A
) A
GROUP BY R_OWNER, R_TABLE_NAME, STAT_INTRO
ORDER BY R_OWNER, R_TABLE_NAME;

declare
	v_Count pls_integer;
begin
	SELECT COUNT(*)
	INTO v_Count
	FROM USER_TABLES
	WHERE TABLE_NAME = 'PLUGIN_DELETE_CHECKS';
	if v_Count = 0 then
		EXECUTE IMMEDIATE q'[
			CREATE TABLE PLUGIN_DELETE_CHECKS (
				R_OWNER			VARCHAR2(128 BYTE) DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
				R_TABLE_NAME	VARCHAR2(128 BYTE),
				SUBQUERY		CLOB,
				CONSTRAINT PLUGIN_DELETE_CHECKS_UK PRIMARY KEY (R_OWNER, R_TABLE_NAME) USING INDEX
			)
		]';
	end if;
end;
/

CREATE OR REPLACE PACKAGE delete_check_plugin
AUTHID CURRENT_USER
IS
	g_use_job CONSTANT boolean := TRUE;

	FUNCTION Row_Is_Deletable (
		p_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Table_Name IN VARCHAR2,
		p_PKCol_Name IN VARCHAR2,
		p_PKCol_Value IN VARCHAR2,
		p_PKCol_Name2 IN VARCHAR2 DEFAULT NULL,
		p_PKCol_Value2 IN VARCHAR2 DEFAULT NULL
	)
	RETURN NUMBER;	-- 0 = not deletable, 1 = deletable

	FUNCTION Process_Row_Is_Deletable (
		p_process in apex_plugin.t_process,
		p_plugin  in apex_plugin.t_plugin )
	RETURN apex_plugin.t_process_exec_result;

	PROCEDURE Refresh_After_DDL;

    PROCEDURE Refresh_After_DDL_Job;
END delete_check_plugin;
/
show errors

CREATE OR REPLACE PACKAGE BODY delete_check_plugin
IS
	FUNCTION Row_Is_Deletable (
		p_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Table_Name IN VARCHAR2,
		p_PKCol_Name IN VARCHAR2,
		p_PKCol_Value IN VARCHAR2,
		p_PKCol_Name2 IN VARCHAR2 DEFAULT NULL,
		p_PKCol_Value2 IN VARCHAR2 DEFAULT NULL,
		p_Subquery	IN OUT VARCHAR2,
		p_Message	IN OUT VARCHAR2
	)
	RETURN NUMBER
	IS
		subq_cur    SYS_REFCURSOR;
		cnt_cur     SYS_REFCURSOR;
		v_Result NUMBER := 1;
		v_Primary_Key_Expr VARCHAR2(128);
	BEGIN
		if p_PKCol_Value IS NULL then 
			-- when primary key value is null the row is not deletable
			return 0;
		end if;
		v_Primary_Key_Expr := case 
			when p_PKCol_Name IS NULL or INSTR(p_PKCol_Name, ',') > 0 then 
				'ROWID' 
			else 
				p_PKCol_Name
		end;
		-- load query for drill down to dependent child rows with a foreign key to the main table primary key.
		OPEN subq_cur FOR
			SELECT SUBQUERY
			FROM PLUGIN_DELETE_CHECKS
			WHERE R_OWNER = UPPER(p_Owner)
			AND R_TABLE_NAME = p_Table_Name;
		FETCH subq_cur INTO p_Subquery;
		if subq_cur%FOUND then
			-- when a child query was found, execute it with the given parameters.
			if P_PKCol_Name2 IS NOT NULL then
				p_Subquery := 'SELECT 1 ' || p_Subquery || chr(10) || '  AND ' || p_PKCol_Name || ' = :a AND ' || p_PKCol_Name2 || ' = :b ';
				-- DBMS_OUTPUT.PUT_LINE(p_Subquery || ' using ' || p_PKCol_Value || ', ' || p_PKCol_Value2);
				OPEN cnt_cur FOR p_Subquery USING p_PKCol_Value, p_PKCol_Value2;
			else
				p_Subquery := 'SELECT 1 ' || p_Subquery || chr(10) || '  AND ' || v_Primary_Key_Expr || ' = :a ';
				-- DBMS_OUTPUT.PUT_LINE(p_Subquery || ' using ' || p_PKCol_Value);
				OPEN cnt_cur FOR p_Subquery USING p_PKCol_Value;
			end if;
			FETCH cnt_cur INTO v_Result;
			-- when the execution of the child query delivered a row, then the test passed and the row is deletable.
			if cnt_cur%NOTFOUND then
				p_Message := 'A dependent child row was found, row is not deletable.';
				v_Result := 0;
			else
				p_Message := 'No dependent child row was found, row is deletable.';
			end if;
			CLOSE cnt_cur;
		else
			p_Message := 'No child query was found, row is deletable.';
		end if;
		CLOSE subq_cur;

		RETURN v_Result;
	END Row_Is_Deletable;

	FUNCTION Row_Is_Deletable (
		p_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Table_Name IN VARCHAR2,
		p_PKCol_Name IN VARCHAR2,
		p_PKCol_Value IN VARCHAR2,
		p_PKCol_Name2 IN VARCHAR2 DEFAULT NULL,
		p_PKCol_Value2 IN VARCHAR2 DEFAULT NULL
	)
	RETURN NUMBER
	IS
		v_Result 				NUMBER;
		v_Message 				VARCHAR2(500);
		v_Subquery 				PLUGIN_DELETE_CHECKS.SUBQUERY%TYPE;
	BEGIN
		v_Result := delete_check_plugin.Row_Is_Deletable (
			p_Owner 		=> p_Owner,
			p_Table_Name	=> p_Table_Name,
			p_PKCol_Name	=> p_PKCol_Name,
			p_PKCol_Value	=> p_PKCol_Value,
			p_PKCol_Name2	=> p_PKCol_Name2,
			p_PKCol_Value2	=> p_PKCol_Value2,
			p_Subquery		=> v_Subquery,
			p_Message		=> v_Message
		);
		RETURN v_Result;
	END Row_Is_Deletable;

	FUNCTION Process_Row_Is_Deletable (
		p_process in apex_plugin.t_process,
		p_plugin  in apex_plugin.t_plugin )
	RETURN apex_plugin.t_process_exec_result
	IS
		v_exec_result apex_plugin.t_process_exec_result;
		v_Table_Owner			VARCHAR2(32767);
		v_Table_Name			VARCHAR2(32767);
		v_Primary_Key_Column	VARCHAR2(32767);
		v_Primary_Key_Item		VARCHAR2(32767);
		v_Primary_Key_Value		VARCHAR2(32767);
		v_Secondary_Key_Column	VARCHAR2(32767);
		v_Secondary_Key_Item	VARCHAR2(32767);
		v_Secondary_Key_Value	VARCHAR2(32767);
		v_Is_Deletable_Item		VARCHAR2(32767);
		v_Is_Deletable			VARCHAR2(50);
		v_Result 				NUMBER;
		v_Message 				VARCHAR2(500);
		v_Subquery 				PLUGIN_DELETE_CHECKS.SUBQUERY%TYPE;
	BEGIN
		if apex_application.g_debug then
			apex_plugin_util.debug_process (
				p_plugin => p_plugin,
				p_process => p_process
			);
		end if;
		v_Table_Owner 			:= NVL(p_process.attribute_01, apex_application.g_flow_owner);
		v_Table_Name 			:= p_process.attribute_02;
		v_Primary_Key_Column	:= p_process.attribute_03;
		v_Primary_Key_Item		:= p_process.attribute_04;
		v_Primary_Key_Value		:= APEX_UTIL.GET_SESSION_STATE(v_Primary_Key_Item);
		v_Secondary_Key_Column	:= p_process.attribute_05;
		v_Secondary_Key_Item	:= p_process.attribute_06;
		v_Secondary_Key_Value	:= case when v_Secondary_Key_Item IS NOT NULL then APEX_UTIL.GET_SESSION_STATE(v_Secondary_Key_Item) end;
		v_Is_Deletable_Item		:= p_process.attribute_07;

        if apex_application.g_debug then
            apex_debug.info('Table_Owner          : %s', v_Table_Owner);
            apex_debug.info('Table_Name           : %s', v_Table_Name);
            apex_debug.info('Primary_Key_Column   : %s', v_Primary_Key_Column);
            apex_debug.info('Primary_Key_Item     : %s', v_Primary_Key_Item);
            apex_debug.info('Primary_Key_Value    : %s', v_Primary_Key_Value);
            apex_debug.info('Secondary_Key_Column : %s', v_Secondary_Key_Column);
            apex_debug.info('Secondary_Key_Item   : %s', v_Secondary_Key_Item);
            apex_debug.info('Secondary_Key_Value  : %s', v_Secondary_Key_Value);
        end if;
		v_Result := delete_check_plugin.Row_Is_Deletable (
			p_Owner 		=> v_Table_Owner,
			p_Table_Name	=> v_Table_Name,
			p_PKCol_Name	=> v_Primary_Key_Column,
			p_PKCol_Value	=> v_Primary_Key_Value,
			p_PKCol_Name2	=> v_Secondary_Key_Column,
			p_PKCol_Value2	=> v_Secondary_Key_Value,
			p_Subquery		=> v_Subquery,
			p_Message		=> v_Message
		);
		v_Is_Deletable := case when v_Result = 0 then 'N' else 'Y' end;
        if apex_application.g_debug then
            apex_debug.info('Check Query          : %s', v_Subquery);
            apex_debug.info('Message              : %s', v_Message);
            apex_debug.info('Is_Deletable         : %s', v_Is_Deletable);
        end if;
		apex_util.set_session_state(v_Is_Deletable_Item, v_Is_Deletable);
		RETURN v_exec_result;
	END Process_Row_Is_Deletable;

	PROCEDURE Refresh_After_DDL
	IS
	BEGIN
		MERGE INTO PLUGIN_DELETE_CHECKS D
		USING (SELECT NVL(S.R_OWNER, P.R_OWNER) R_OWNER, 
					NVL(S.R_TABLE_NAME, P.R_TABLE_NAME) R_TABLE_NAME, 
					S.SUBQUERY,
					case when S.R_TABLE_NAME IS NULL then 'D' else 'U' end OPERATION
			FROM V_DELETE_CHECK S
			FULL OUTER JOIN PLUGIN_DELETE_CHECKS P ON P.R_TABLE_NAME = S.R_TABLE_NAME AND P.R_OWNER = S.R_OWNER
		) S
		ON (D.R_TABLE_NAME = S.R_TABLE_NAME AND D.R_OWNER = S.R_OWNER)
		WHEN MATCHED THEN
			UPDATE SET D.SUBQUERY = S.SUBQUERY WHERE S.OPERATION = 'U' 
			DELETE WHERE S.OPERATION = 'D' 
		WHEN NOT MATCHED THEN
			INSERT (D.R_OWNER, D.R_TABLE_NAME, D.SUBQUERY)
			VALUES (S.R_OWNER, S.R_TABLE_NAME, S.SUBQUERY)
		;
		COMMIT;
	END Refresh_After_DDL;

    PROCEDURE Refresh_After_DDL_Job
	IS
	BEGIN
		dbms_scheduler.create_job(
			job_name => 'RF_PLUGIN_DELETE_CHECKS',
			job_type => 'PLSQL_BLOCK',
			job_action => 'begin delete_check_plugin.Refresh_After_DDL; end;',
			comments => 'Refresh PLUGIN_DELETE_CHECKS after DDL operation',
			enabled => true 
		);
		COMMIT;
	END Refresh_After_DDL_Job;

END delete_check_plugin;
/

declare 
	time_limit_exceeded EXCEPTION; 
	PRAGMA EXCEPTION_INIT (time_limit_exceeded, -40); -- ORA-00040: active time limit exceeded - call aborted
	v_count NUMBER;
begin
	select count(*) into v_count
	from USER_SYS_PRIVS where PRIVILEGE = 'CREATE JOB';
	if delete_check_plugin.g_use_job and v_count > 0 then -- launch a background job to speedup the installation.
		delete_check_plugin.Refresh_After_DDL_Job;
	else 
	    delete_check_plugin.Refresh_After_DDL;
	end if;
exception
  when time_limit_exceeded then
	DBMS_OUTPUT.PUT_LINE('-- Warning -- SQL Error :' || SQLCODE || ' ' || SQLERRM);
end;
/

-- Test:
-- SELECT delete_check_plugin.Row_Is_Deletable(p_Owner=>'SH', p_Table_Name=>'CUSTOMERS', P_PKCol_Name=>'CUST_ID', p_PKCol_Value=>'24540') Row_Is_Deletable FROM DUAL;

-- Populate:
-- SELECT /*insert*/ R_TABLE_NAME, SUBQUERY FROM PLUGIN_DELETE_CHECKS WHERE R_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
