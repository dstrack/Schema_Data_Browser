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

CREATE OR REPLACE PACKAGE data_browser_jobs
AUTHID DEFINER -- enable jobs to find translations.
IS
	g_Job_Name_Prefix 			CONSTANT VARCHAR2(10) := 'DBROW_';
	g_Refresh_MViews_Start_Unique CONSTANT BINARY_INTEGER := 1;
	g_Refresh_MViews_Start_Foreign CONSTANT BINARY_INTEGER := 5;
	g_Refresh_MViews_Start_Project CONSTANT BINARY_INTEGER := 10;
	g_debug CONSTANT BOOLEAN := FALSE;
	g_Use_App_Preferences CONSTANT BOOLEAN := TRUE;
	
	TYPE rec_user_job_states IS RECORD (
		SID						NUMBER,
		SERIAL#					NUMBER,
		MESSAGE                 VARCHAR2(512), 
		SOFAR                   NUMBER, 
		TOTALWORK              	NUMBER, 
		CONTEXT              	NUMBER, 
		START_TIME              DATE, 
		LAST_UPDATE_TIME        DATE, 
		TIME_REMAINING		    VARCHAR2(50),
		ELAPSED_TIME		    VARCHAR2(50),
		PERCENT                 NUMBER
	);
	TYPE tab_user_job_states IS TABLE OF rec_user_job_states;

	FUNCTION Get_Jobs_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Encrypt_Function RETURN VARCHAR2;
    FUNCTION Get_Encrypt_Function(p_Key_Column VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2;

	FUNCTION Get_Refresh_Start_Unique RETURN BINARY_INTEGER DETERMINISTIC;
	FUNCTION Get_Refresh_Start_Foreign RETURN BINARY_INTEGER DETERMINISTIC;
	FUNCTION Get_Refresh_Start_Project RETURN BINARY_INTEGER DETERMINISTIC;
	FUNCTION Get_Job_Name_Prefix RETURN VARCHAR2;

	FUNCTION Has_Stale_ChangeLog_Views RETURN VARCHAR2;	-- YES, NO

    FUNCTION Save_Column_Pattern (
    	p_Column_Name VARCHAR2, 
    	p_New_Pattern VARCHAR2,
    	p_Old_Pattern VARCHAR2
    ) RETURN BINARY_INTEGER;

	-- Internal
	FUNCTION Get_Last_DDL_Time(
		p_Owner	VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	) RETURN USER_OBJECTS.LAST_DDL_TIME%TYPE;

	FUNCTION Get_MView_Last_Refresh_Date(
		p_MView_Name VARCHAR2,
		p_Owner	VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	RETURN USER_MVIEWS.LAST_REFRESH_DATE%TYPE;

	PROCEDURE MView_Refresh (
		p_MView_Name VARCHAR2,
		p_Owner	VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_LAST_DDL_TIME IN OUT USER_OBJECTS.LAST_DDL_TIME%TYPE
	);

	FUNCTION FN_Scheduler_Context RETURN BINARY_INTEGER;

    PROCEDURE Refresh_MViews (
		p_Owner					IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  				IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_Start_Step 			IN binary_integer DEFAULT g_Refresh_MViews_Start_Unique
    );

	PROCEDURE Wait_for_Scheduler_Job (
		p_Job_Name VARCHAR2 DEFAULT NULL
	);
	
	PROCEDURE Load_Job (
		p_Job_Name VARCHAR2,
		p_Comment VARCHAR2,
		p_Sql VARCHAR2,
		p_Wait VARCHAR2 DEFAULT 'YES',
		p_Delay_Seconds NUMBER DEFAULT 0.5,
		p_Skip_When_Scheduled VARCHAR2 DEFAULT 'NO'
	);

    PROCEDURE Refresh_MViews_job (
		p_Owner					IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Start_Step 			IN binary_integer DEFAULT g_Refresh_MViews_Start_Unique,
		p_Wait  				IN VARCHAR2 DEFAULT 'YES',
		p_Delay_Seconds 		IN NUMBER DEFAULT 0.5,
    	p_Context  				IN binary_integer DEFAULT FN_Scheduler_Context
   	);

	PROCEDURE Touch_Configuration;
	PROCEDURE Set_Publish_Translation_Date (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    );
	FUNCTION Get_Publish_Translation_Date(
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    ) RETURN DATE;
	FUNCTION Get_Publish_Translation_State (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    ) RETURN VARCHAR2; -- VALID/STALE
	PROCEDURE Publish_Translations (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    );

    PROCEDURE Publish_Translations_Job (
    	p_Application_ID IN NUMBER DEFAULT NV('APP_ID'),
    	p_context  		IN binary_integer DEFAULT FN_Scheduler_Context
    );
    PROCEDURE Start_Publish_Translations_Job (
    	p_Application_ID IN NUMBER DEFAULT NV('APP_ID'),
    	p_context  		IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_wait 			IN VARCHAR2 DEFAULT 'YES'
    );
    
    PROCEDURE Refresh_ChangeLog_Job (
    	p_context  	IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_Wait 		IN VARCHAR2 DEFAULT 'NO',
    	p_Delay_Seconds IN BINARY_INTEGER DEFAULT 180
    );

     PROCEDURE Prepare_ChangeLog_Job (
    	p_context  	IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_App_ID	IN NUMBER DEFAULT  NV('APP_ID')
    );

    PROCEDURE Refresh_After_DDL_Job(
		p_Table_Name        IN VARCHAR2 DEFAULT NULL,
		p_Purge_History		IN VARCHAR2 DEFAULT 'NO'
	);

	PROCEDURE Start_Refresh_Mviews_Job (
    	p_Start_Step 			IN binary_integer DEFAULT g_Refresh_MViews_Start_Unique,
    	p_App_ID				IN NUMBER DEFAULT  NV('APP_ID'),
		p_Owner					IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Delay_Seconds 		IN NUMBER DEFAULT 5,
    	p_Context  				IN binary_integer DEFAULT FN_Scheduler_Context
    );

    PROCEDURE Install_Sup_Obj_Job (
		p_App_ID NUMBER DEFAULT NV('APP_ID'),
		p_Dest_Schema VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Admin_User VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_Admin_Password VARCHAR2,	-- encrypted by g_Encrypt_Function
		p_Admin_EMail VARCHAR2		-- encrypted by g_Encrypt_Function
	);
	
    PROCEDURE DeInstall_Sup_Obj_Job (
		p_App_ID NUMBER DEFAULT NV('APP_ID'),
		p_Dest_Schema VARCHAR2,
		p_Revoke_Privs VARCHAR2 DEFAULT 'NO'
	);

    PROCEDURE Duplicate_Schema_Job (
		p_Source_Schema VARCHAR2,
		p_Dest_Schema VARCHAR2,
		p_Dest_Password VARCHAR2,
        p_Application_ID NUMBER DEFAULT NV('APP_ID')
	);

	PROCEDURE Refresh_Schema_Stats (
		p_Schema_Name VARCHAR2,
    	p_context binary_integer DEFAULT FN_Scheduler_Context
	);

	PROCEDURE Schema_Stats_Job (p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));

	PROCEDURE Refresh_Tree_View(
    	p_context binary_integer DEFAULT FN_Scheduler_Context,
		p_Schema_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
    );

    PROCEDURE Refresh_Tree_View_Job;

	/*FUNCTION Get_Running_Job_State RETURN VARCHAR2;*/
	
	FUNCTION Get_User_Job_State_Peek (
		p_Job_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	FUNCTION Get_User_Job_State (
		p_Job_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	FUNCTION FN_Pipe_user_running_jobs
	RETURN data_browser_jobs.tab_user_job_states PIPELINED;

END data_browser_jobs;
/


CREATE OR REPLACE PACKAGE BODY data_browser_jobs
IS
	g_Configuration_ID			NUMBER			:= 1;
	g_ChangLog_Stale_Call 		VARCHAR2(2000) 	:= 'custom_changelog_gen.MViews_Stale_Count';
	g_App_Setting_publish_Date	CONSTANT VARCHAR2(50) := 'TRANSLATIONS_PUBLISHED_DATE';
	g_Jobs_Collection			CONSTANT VARCHAR2(50) := 'SCHEDULER_JOBS';
	g_Encrypt_Function 			CONSTANT VARCHAR2(128) 	:= 'data_browser_auth.Hex_Crypt';
	g_CtxTimestampFormat 		CONSTANT VARCHAR2(64)	:= 'DD.MM.YYYY HH24.MI.SS';

	g_Refresh_MViews_Proc_Name 	CONSTANT	VARCHAR2(128) := 'Refresh snapshots for data browser application';
	g_Publish_Transl_Proc_Name 	CONSTANT	VARCHAR2(128) := 'Publish translations for data browser application';
	g_Ref_Schema_Stats_Proc_Name CONSTANT	VARCHAR2(128) := 'Refresh statistics for data browser application';
	g_Ref_Tree_View_Proc_Name 	CONSTANT VARCHAR2(128) := 'Refresh tree view for data browser application';
	g_Timemark 					NUMBER;

	FUNCTION Enquote_Literal ( p_Text VARCHAR2 )
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
		v_Quote CONSTANT VARCHAR2(1) := chr(39);
	BEGIN
		RETURN v_Quote || REPLACE(p_Text, v_Quote, v_Quote||v_Quote) || v_Quote ;
	END;

	FUNCTION Get_Jobs_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Jobs_Collection else Enquote_Literal(g_Jobs_Collection) end;
	END;

	FUNCTION Get_Encrypt_Function RETURN VARCHAR2 IS BEGIN RETURN g_Encrypt_Function; END;

    FUNCTION Get_Encrypt_Function(p_Key_Column VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Encrypt_Function || '(' || p_Key_Column || ', ' || p_Column_Name || ')'; END;

	FUNCTION Get_Refresh_Start_Unique RETURN BINARY_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN g_Refresh_MViews_Start_Unique;
	END Get_Refresh_Start_Unique;

	FUNCTION Get_Refresh_Start_Foreign RETURN BINARY_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN g_Refresh_MViews_Start_Foreign;
	END Get_Refresh_Start_Foreign;

	FUNCTION Get_Refresh_Start_Project RETURN BINARY_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN g_Refresh_MViews_Start_Project;
	END Get_Refresh_Start_Project;

    FUNCTION Get_Job_Name_Prefix RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN g_Job_Name_Prefix;
    END;

	FUNCTION Has_Stale_ChangeLog_Views RETURN VARCHAR2	-- YES, NO
    IS
    	v_Count PLS_INTEGER;
    	v_Included VARCHAR2(10) := 'NO';
    	v_Query	VARCHAR2(2000);
		cv 		SYS_REFCURSOR;
    BEGIN
    	if g_ChangLog_Stale_Call IS NOT NULL then
			EXECUTE IMMEDIATE 'begin :result := ' || g_ChangLog_Stale_Call || '; end;'
			USING OUT v_Count;
		end if;
		RETURN case when v_Count > 0 then 'YES' else 'NO' end;
	exception when others then
		if SQLCODE = -6550 then
			RETURN 'NO';
		end if;
		raise;
    END Has_Stale_ChangeLog_Views;

    FUNCTION Save_Column_Pattern (
    	p_Column_Name VARCHAR2, 
    	p_New_Pattern VARCHAR2,
    	p_Old_Pattern VARCHAR2
    ) RETURN BINARY_INTEGER
    IS 
    	v_Query VARCHAR2(32767);
    	v_Refresh_Starting_Step BINARY_INTEGER := data_browser_jobs.Get_Refresh_Start_Project;
    BEGIN
    	for p_cur in (
			with old_q as (
				SELECT column_value Pattern_Name 
				from table(apex_string.split(p_Old_Pattern,':'))
			), new_q as (
				SELECT column_value Pattern_Name 
				from table(apex_string.split(p_New_Pattern,':'))
			)
			select old_q.Pattern_Name, 'REMOVE' operation
			from old_q
			where not exists (
				select 1
				from new_q 
				where new_q.Pattern_Name = old_q.Pattern_Name
			)
			union all 
			select new_q.Pattern_Name, 'APPEND' operation
			from new_q
			where not exists (
				select 1
				from old_q 
				where old_q.Pattern_Name = new_q.Pattern_Name
			)
    	) loop 
    		if p_cur.operation = 'REMOVE' then
    			v_Query := 'UPDATE DATA_BROWSER_CONFIG SET ' 
    			|| dbms_assert.enquote_name(p_cur.Pattern_Name) 
    			|| ' = RTRIM(REGEXP_REPLACE('
    			|| dbms_assert.enquote_name(p_cur.Pattern_Name) 
    			|| ', '
    			|| Enquote_Literal('(^|\s|\W+)' || p_Column_Name || '($|\s|\W+)')
    			|| ', '
    			|| Enquote_Literal('\1')
    			|| '), '
    			|| Enquote_Literal(', ')
    			|| ')';
    			EXECUTE IMMEDIATE v_Query;
    		elsif p_cur.operation = 'APPEND' then
    			v_Query := 'UPDATE DATA_BROWSER_CONFIG SET ' 
    			|| dbms_assert.enquote_name(p_cur.Pattern_Name) 
    			|| ' = data_browser_conf.Concat_List('
    			|| dbms_assert.enquote_name(p_cur.Pattern_Name) 
    			|| ', '
    			|| Enquote_Literal(p_Column_Name)
    			|| ')';
    			EXECUTE IMMEDIATE v_Query;
    		end if;
    		v_Refresh_Starting_Step := LEAST(case when p_cur.Pattern_Name IN (
						'DISPLAY_COLUMNS_PATTERN','ROW_VERSION_COLUMN_PATTERN','ROW_LOCK_COLUMN_PATTERN',
						'SOFT_DELETE_COLUMN_PATTERN', 'ORDERING_COLUMN_PATTERN', 'ACTIVE_LOV_FIELDS_PATTERN', 
						'FILE_NAME_COLUMN_PATTERN', 'MIME_TYPE_COLUMN_PATTERN', 'FILE_CREATED_COLUMN_PATTERN',
						'FILE_CONTENT_COLUMN_PATTERN', 'FILE_FOLDER_FIELD_PATTERN', 'FOLDER_NAME_FIELD_PATTERN', 'FOLDER_PARENT_FIELD_PATTERN',
						'FILE_PRIVILEGE_FLD_PATTERN', 'INDEX_FORMAT_FIELD_PATTERN', 'AUDIT_COLUMN_PATTERN'
					) then 
						data_browser_jobs.Get_Refresh_Start_Unique
					when p_cur.Pattern_Name IN ('CALENDAR_START_DATE_PATTERN','CALENDAR_END_DATE_PATTERN') then 
						data_browser_jobs.Get_Refresh_Start_Foreign
					else data_browser_jobs.Get_Refresh_Start_Project
				end, v_Refresh_Starting_Step);
    	end loop;
    	COMMIT;
    	return v_Refresh_Starting_Step;
    END Save_Column_Pattern;

	-- Internal
	FUNCTION Get_Last_DDL_Time(
		p_Owner	VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	RETURN USER_OBJECTS.LAST_DDL_TIME%TYPE
	IS
		v_LAST_DDL_TIME USER_OBJECTS.LAST_DDL_TIME%TYPE;
	BEGIN
		if p_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
			SELECT /*+ RESULT_CACHE */ 
				MAX (LAST_DDL_TIME) LAST_DDL_TIME
			INTO v_LAST_DDL_TIME
			FROM (
				SELECT MAX(LAST_DDL_TIME) LAST_DDL_TIME
				FROM SYS.USER_OBJECTS A
				WHERE A.OBJECT_TYPE IN ('TABLE', 'PACKAGE BODY')
				AND (A.OBJECT_NAME IN ('CHANGELOG_CONF', 'DATA_BROWSER_CONF') OR A.OBJECT_TYPE = 'TABLE')
				UNION ALL
				SELECT MAX(LAST_MODIFIED_AT) LAST_DDL_TIME
				FROM DATA_BROWSER_CONFIG A
				WHERE ID = g_Configuration_ID
			);
		else 
			SELECT /*+ RESULT_CACHE */ 
				MAX (LAST_DDL_TIME) LAST_DDL_TIME
			INTO v_LAST_DDL_TIME
			FROM (
				SELECT MAX(LAST_DDL_TIME) LAST_DDL_TIME
				FROM SYS.ALL_OBJECTS A
				WHERE A.OBJECT_TYPE IN ('TABLE', 'PACKAGE BODY')
				AND (A.OBJECT_NAME IN ('CHANGELOG_CONF', 'DATA_BROWSER_CONF') OR A.OBJECT_TYPE = 'TABLE')
				AND A.OWNER = p_Owner
				UNION ALL
				SELECT MAX(LAST_MODIFIED_AT) LAST_DDL_TIME
				FROM DATA_BROWSER_CONFIG A
				WHERE ID = g_Configuration_ID
			);
		end if;
		RETURN v_LAST_DDL_TIME;
	END Get_Last_DDL_Time;

	FUNCTION Get_MView_Last_Refresh_Date(
		p_MView_Name VARCHAR2,
		p_Owner	VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	RETURN USER_MVIEWS.LAST_REFRESH_DATE%TYPE
	IS
		v_LAST_REFRESH_DATE	USER_MVIEWS.LAST_REFRESH_DATE%TYPE;
	BEGIN
		if p_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
			SELECT MIN(LAST_REFRESH_DATE)
			INTO v_LAST_REFRESH_DATE
			FROM SYS.USER_MVIEWS
			WHERE MVIEW_NAME = p_MView_Name;
		else 
			SELECT MIN(LAST_REFRESH_DATE)
			INTO v_LAST_REFRESH_DATE
			FROM SYS.ALL_MVIEWS
			WHERE MVIEW_NAME = p_MView_Name
			AND OWNER = p_Owner;
		end if;
		RETURN v_LAST_REFRESH_DATE;
	END Get_MView_Last_Refresh_Date;

	PROCEDURE MView_Refresh (
		p_MView_Name VARCHAR2,
		p_Owner	VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_LAST_DDL_TIME IN OUT USER_OBJECTS.LAST_DDL_TIME%TYPE
	)
	IS
		v_LAST_REFRESH_DATE	USER_MVIEWS.LAST_REFRESH_DATE%TYPE;
		v_STALENESS	USER_MVIEWS.STALENESS%TYPE;
		v_REFRESH_METHOD USER_MVIEWS.REFRESH_METHOD%TYPE;
		v_COMPILE_STATE USER_MVIEWS.COMPILE_STATE%TYPE;
		v_Statement VARCHAR2(1000);
	BEGIN
		if p_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
			SELECT LAST_REFRESH_DATE, STALENESS, REFRESH_METHOD, COMPILE_STATE
			INTO v_LAST_REFRESH_DATE, v_STALENESS, v_REFRESH_METHOD, v_COMPILE_STATE
			FROM SYS.USER_MVIEWS
			WHERE MVIEW_NAME = p_MView_Name;
		else
			SELECT LAST_REFRESH_DATE, STALENESS, REFRESH_METHOD, COMPILE_STATE
			INTO v_LAST_REFRESH_DATE, v_STALENESS, v_REFRESH_METHOD, v_COMPILE_STATE
			FROM SYS.ALL_MVIEWS
			WHERE MVIEW_NAME = p_MView_Name
			AND owner = p_Owner;		
		end if;
		/*if v_COMPILE_STATE IN ('NEEDS_COMPILE', 'COMPILATION_ERROR') then 
			v_Statement := 'ALTER MATERIALIZED VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(p_Owner) || '.' || DBMS_ASSERT.ENQUOTE_NAME(p_MView_Name) || ' COMPILE';
			EXECUTE IMMEDIATE v_Statement;
			DBMS_OUTPUT.PUT_LINE('-- compiled ' || p_MView_Name || ' Compile State: ' || v_COMPILE_STATE || ' Staleness: ' || v_STALENESS);
			v_COMPILE_STATE := 'VALID';
		end if;*/
		if p_LAST_DDL_TIME > v_LAST_REFRESH_DATE OR v_LAST_REFRESH_DATE IS NULL 
		or v_STALENESS IN ('NEEDS_COMPILE', 'UNUSABLE') then
			DBMS_MVIEW.REFRESH(p_Owner || '.' || p_MView_Name);
			p_LAST_DDL_TIME := SYSDATE;
			DBMS_OUTPUT.PUT_LINE('-- Refreshed ' || p_MView_Name || ' Compile State: ' || v_COMPILE_STATE || ' Staleness: ' || v_STALENESS);
		else
			DBMS_OUTPUT.PUT_LINE('-- skipped ' || p_MView_Name || ' Compile State: ' || v_COMPILE_STATE || ' Staleness: ' || v_STALENESS);
		end if;
	exception
	  when NO_DATA_FOUND then
		DBMS_OUTPUT.PUT_LINE('-- not existing ' || p_MView_Name);
	END MView_Refresh;

    PROCEDURE Set_Process_Infos (
        p_rindex    in out binary_integer,
        p_slno      in out binary_integer,
        p_opname    in varchar2,
    	p_context   in binary_integer,
        p_totalwork in number,
        p_sofar     in number,
        p_units     in varchar2
    )
    IS
		v_Timemark number;
		v_TimeString VARCHAR2(40);
    BEGIN
		v_Timemark := dbms_utility.get_time;
        dbms_application_info.set_session_longops(
          rindex       => p_rindex,
          slno         => p_slno,
          op_name      => p_opname,
          target       => 0,
          context      => p_context,		-- context is of type BINARY_INTEGER
          sofar        => p_sofar,
          totalwork    => p_totalwork,
          target_desc  => 'Schema ' || SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
          units        => p_units
        );
        -- Problem: on apex.oracle.com the select on V$SESSION_LONGOPS delivers no rows.
        COMMIT;
        if p_sofar > 0 then 
			v_TimeString := TO_CHAR((v_Timemark - g_Timemark)/100.0, '9G990D00');
			DBMS_OUTPUT.PUT_LINE('-- ' || p_sofar || ' ' || p_units || ' ' || v_TimeString);
		end if;
		g_Timemark := v_Timemark;
    END;

	FUNCTION FN_Scheduler_Context RETURN BINARY_INTEGER
	IS 
	BEGIN RETURN NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0);
	END FN_Scheduler_Context;

    PROCEDURE Refresh_MViews (
		p_Owner					IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  				IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_Start_Step 			IN binary_integer DEFAULT g_Refresh_MViews_Start_Unique
    )
    IS
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Start_Step  	constant binary_integer := nvl(p_Start_Step, g_Refresh_MViews_Start_Unique);
        v_Steps  		constant binary_integer := 11;
		v_Statement 	VARCHAR2(1000);
		v_Refreshed_Cnt NUMBER := 0;
    BEGIN
        Set_Process_Infos(v_rindex, v_slno, g_Refresh_MViews_Proc_Name, p_context, v_Steps-v_Start_Step, 0, 'steps');
		-- detect deleted tables 
		if v_Start_Step = g_Refresh_MViews_Start_Unique 
		and data_browser_jobs.Has_Stale_ChangeLog_Views = 'YES' then 
			data_browser_jobs.Touch_Configuration;
		end if;
		for v_cur in (
			SELECT MVIEW_NAME, OWNER, 
					STALENESS, REFRESH_METHOD, COMPILE_STATE, STEP, 
					LAST_REFRESH_DATE, LAST_DDL_TIME
			FROM (
				SELECT A.MVIEW_NAME, A.OWNER, A.LAST_REFRESH_DATE,
					MIN(A.LAST_REFRESH_DATE) OVER () MIN_LAST_REFRESH_DATE, 
					MAX(A.LAST_REFRESH_DATE) OVER () MAX_LAST_REFRESH_DATE, 
					A.STALENESS, A.REFRESH_METHOD, A.COMPILE_STATE, B.STEP + 1 STEP, C.LAST_DDL_TIME
				FROM SYS.USER_MVIEWS A
				, (SELECT COLUMN_VALUE MVIEW_NAME, ROWNUM STEP FROM apex_string.split(
					'MVBASE_UNIQUE_KEYS,MVDATA_BROWSER_VIEWS,MVDATA_BROWSER_D_REFS,MVDATA_BROWSER_FKEYS,'
					||'MVDATA_BROWSER_U_REFS,MVDATA_BROWSER_DESCRIPTIONS,MVDATA_BROWSER_CHECKS_DEFS,'
					||'MVDATA_BROWSER_F_REFS,MVDATA_BROWSER_REFERENCES,MVDATA_BROWSER_SIMPLE_COLS',','
				)) B 
				, (
					SELECT
					MAX (LAST_DDL_TIME) LAST_DDL_TIME
					FROM (
						SELECT MAX(LAST_DDL_TIME) LAST_DDL_TIME
						FROM SYS.USER_OBJECTS A
						WHERE A.OBJECT_TYPE IN ('TABLE', 'PACKAGE BODY')
						AND (A.OBJECT_NAME IN ('CHANGELOG_CONF', 'DATA_BROWSER_CONF') OR A.OBJECT_TYPE = 'TABLE')
						UNION ALL
						SELECT MAX(LAST_MODIFIED_AT) LAST_DDL_TIME
						FROM DATA_BROWSER_CONFIG A
					)
				) C
				WHERE A.MVIEW_NAME = B.MVIEW_NAME
			) WHERE STEP >= v_Start_Step
			ORDER BY STEP 
		) loop 
			if v_cur.LAST_DDL_TIME > v_cur.LAST_REFRESH_DATE 
			OR v_cur.LAST_REFRESH_DATE IS NULL
			or v_cur.STALENESS = 'UNUSABLE'
			or v_Refreshed_Cnt > 0 then
				DBMS_MVIEW.REFRESH(v_cur.Owner || '.' || v_cur.MView_Name);
				v_Refreshed_Cnt := v_Refreshed_Cnt + 1;
				DBMS_OUTPUT.PUT_LINE('-- Refreshed ' || v_cur.Owner || '.' || v_cur.MView_Name || ' Compile State: ' || v_cur.COMPILE_STATE || ' Staleness: ' || v_cur.STALENESS);
			elsif v_cur.COMPILE_STATE IN ('NEEDS_COMPILE', 'COMPILATION_ERROR') then 
				v_Statement := 'ALTER MATERIALIZED VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(v_cur.Owner) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_cur.MView_Name) || ' COMPILE';
				EXECUTE IMMEDIATE v_Statement;
				DBMS_OUTPUT.PUT_LINE('-- Compiled ' || v_cur.MView_Name || ' Compile State: ' || v_cur.COMPILE_STATE || ' Staleness: ' || v_cur.STALENESS);
			else
				DBMS_OUTPUT.PUT_LINE('-- Skipped ' || v_cur.MView_Name || ' Compile State: ' || v_cur.COMPILE_STATE || ' Staleness: ' || v_cur.STALENESS);
			end if;
			Set_Process_Infos(v_rindex, v_slno, g_Refresh_MViews_Proc_Name, p_context, v_Steps-v_Start_Step, v_cur.Step-v_Start_Step, 'steps');
        end loop;
        DBMS_OUTPUT.PUT_LINE('-- Done --');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, g_Refresh_MViews_Proc_Name, p_context, v_Steps-v_Start_Step, v_Steps-v_Start_Step, 'steps');
		raise;
    END Refresh_MViews;

	PROCEDURE Wait_for_Scheduler_Job (
		p_Job_Name VARCHAR2 DEFAULT NULL
	)
	IS
    	v_Loops PLS_INTEGER := 20;
    	v_Job_State USER_SCHEDULER_JOBS.STATE%TYPE;
  		v_http_request   UTL_HTTP.req;
	BEGIN
		loop 
			APEX_UTIL.PAUSE(1/5);
			v_Job_State := Get_User_Job_State_Peek(p_Job_Name => p_Job_Name);
			exit when v_Job_State IN ('RUNNING', 'FINISHED','DONE');
			v_Loops := v_Loops - 1;
			exit when v_Loops < 1;
		end loop;
	END;
	

	PROCEDURE Load_Job (
		p_Job_Name VARCHAR2,
		p_Comment VARCHAR2,
		p_Sql VARCHAR2,
		p_Wait VARCHAR2 DEFAULT 'YES',
		p_Delay_Seconds NUMBER DEFAULT 0.5,
		p_Skip_When_Scheduled VARCHAR2 DEFAULT 'NO'
	)
	IS
		v_Job_Name 			USER_SCHEDULER_JOBS.JOB_NAME%TYPE;
		v_Job_Name_Prefix 	USER_SCHEDULER_JOBS.JOB_NAME%TYPE := SUBSTR(data_browser_jobs.Get_Job_Name_Prefix || p_Job_Name, 1, 17);
    	v_Loops PLS_INTEGER := 10;
	BEGIN
		if p_Skip_When_Scheduled = 'YES' then 
			begin
				SELECT JOB_NAME
				INTO v_Job_Name
				FROM USER_SCHEDULER_JOBS
				WHERE JOB_NAME LIKE v_Job_Name_Prefix || '%'
				-- AND JOB_ACTION = p_Sql 
				AND STATE IN ('SCHEDULED', 'RETRY SCHEDULED')
                AND ROWNUM = 1;
				$IF data_browser_jobs.g_debug $THEN
					apex_debug.message(
						p_message => 'data_browser_jobs.Load_Job (p_Job_Name=> %s, p_Wait=> %s, p_Delay_Seconds=> %s, p_Skip_When_Scheduled=> %s) - skipped.',
						p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Job_Name),
						p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Wait),
						p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Delay_Seconds),
						p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Skip_When_Scheduled)
					);
				$END
				return;
			exception
			  when NO_DATA_FOUND then
				v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
			end;
		else 
			v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
		end if;
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_jobs.Load_Job (p_Job_Name=> %s, p_Wait=> %s, p_Delay_Seconds=> %s, p_Skip_When_Scheduled=> %s) - start. ---- %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Job_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Wait),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Delay_Seconds),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Skip_When_Scheduled),
				p4 => p_Sql
			);
		$END
		dbms_scheduler.create_job(
			job_name => v_Job_Name,
			start_date => SYSDATE + (1/24/60/60*p_Delay_Seconds), -- starte in p_Delay_Seconds
			job_type => 'PLSQL_BLOCK',
			job_action => p_Sql,
			comments => p_Comment,
			enabled => true );
		COMMIT;
		if p_Wait = 'YES' then 
			data_browser_jobs.Wait_for_Scheduler_Job(p_Job_Name => p_Job_Name);
		end if;
	END Load_Job;

    PROCEDURE Refresh_MViews_Job (
		p_Owner					IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Start_Step 			IN binary_integer DEFAULT g_Refresh_MViews_Start_Unique,
		p_Wait  				IN VARCHAR2 DEFAULT 'YES',
		p_Delay_Seconds 		IN NUMBER DEFAULT 0.5,
    	p_Context  				IN binary_integer DEFAULT FN_Scheduler_Context
   	)
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		v_sql :=
		'begin' || chr(10)
		|| ' data_browser_jobs.Refresh_MViews(p_owner=>'
		|| DBMS_ASSERT.ENQUOTE_LITERAL(p_owner)
		|| ',p_context=>'
		|| DBMS_ASSERT.ENQUOTE_LITERAL(p_Context)
		|| ',p_Start_Step=>'
		|| p_Start_Step
		|| ');' || chr(10)
		-- launch refresh job for history mviews with no context.
		|| 'end;';
		data_browser_jobs.Load_Job(
			p_Job_Name => 'RF_MVIEWS',
			p_Comment => g_Refresh_MViews_Proc_Name,
			p_Sql => v_sql,
			p_Wait => p_Wait,
			p_Delay_Seconds => p_Delay_Seconds,
			p_Skip_When_Scheduled => 'YES'
		);
		COMMIT;
		if p_Start_Step = g_Refresh_MViews_Start_Unique then 
			data_browser_jobs.Refresh_ChangeLog_Job(
				p_context=>p_Context,
				p_Wait =>'NO',
				p_Delay_Seconds => 60);
		end if;
	END Refresh_MViews_Job;

	
	PROCEDURE Touch_Configuration
	IS 
	BEGIN 
		UPDATE DATA_BROWSER_CONFIG SET ROW_VERSION_NUMBER = ROW_VERSION_NUMBER + 1,
			Last_Modified_At = LOCALTIMESTAMP,
			Last_Modified_BY = NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER) 
		WHERE ID = g_Configuration_ID;
		COMMIT;
	END;

	PROCEDURE Set_Publish_Translation_Date (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    )
	IS
		v_Owner APEX_APPLICATIONS.OWNER%TYPE;
	BEGIN 
$IF data_browser_jobs.g_Use_App_Preferences $THEN
		select OWNER into v_Owner
		from APEX_APPLICATIONS 
		where APPLICATION_ID = p_Application_ID;
		APEX_UTIL.SET_PREFERENCE(
			p_preference => g_App_Setting_publish_Date||p_Application_ID, 
			p_value => TO_CHAR(SYSDATE, g_CtxTimestampFormat),
			p_user => v_Owner
		);
$ELSE
		UPDATE DATA_BROWSER_CONFIG SET TRANSLATIONS_PUBLISHED_DATE = LOCALTIMESTAMP
		WHERE ID = g_Configuration_ID;
		COMMIT;
$END
	END;
	
	FUNCTION Get_Publish_Translation_Date (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    ) RETURN DATE 
	IS
		v_Published_Date DATA_BROWSER_CONFIG.TRANSLATIONS_PUBLISHED_DATE%TYPE;
		v_Owner APEX_APPLICATIONS.OWNER%TYPE;
	BEGIN 
$IF data_browser_jobs.g_Use_App_Preferences $THEN
		select OWNER into v_Owner
		from APEX_APPLICATIONS 
		where APPLICATION_ID = p_Application_ID;
		v_Published_Date := TO_DATE(APEX_UTIL.GET_PREFERENCE(
				p_preference => g_App_Setting_publish_Date||p_Application_ID, 
				p_user => v_Owner
			), g_CtxTimestampFormat);
$ELSE
		SELECT TRANSLATIONS_PUBLISHED_DATE 
		INTO v_Published_Date
		FROM DATA_BROWSER_CONFIG 
		WHERE ID = g_Configuration_ID;
$END
		RETURN v_Published_Date;
	END;
	
	FUNCTION Get_Publish_Translation_State (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    ) RETURN VARCHAR2 -- VALID/STALE
	IS 
		v_Last_Updated APEX_APPLICATIONS.LAST_UPDATED_ON%TYPE;
	BEGIN
		select LAST_UPDATED_ON
		into v_Last_Updated
  		from APEX_APPLICATIONS
 		where APPLICATION_ID = p_Application_ID;
 		return case when v_Last_Updated <= data_browser_jobs.Get_Publish_Translation_Date (p_Application_ID => p_Application_ID)
 			then 'VALID' else 'STALE' 
 		end;
	END;

	PROCEDURE Publish_Translations (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    )
	IS
	BEGIN 
		apex_application_install.generate_offset;
		for c1 in (
			select PRIMARY_APPLICATION_ID, TRANSLATED_APP_LANGUAGE
			from APEX_APPLICATION_TRANS_MAP
			where PRIMARY_APPLICATION_ID = p_Application_ID
		) loop
			apex_lang.seed_translations(
				p_application_id => c1.PRIMARY_APPLICATION_ID,  
				p_language => c1.TRANSLATED_APP_LANGUAGE
			);
			apex_lang.publish_application(
				p_application_id => c1.PRIMARY_APPLICATION_ID,  
				p_language => c1.TRANSLATED_APP_LANGUAGE
			);
		end loop;
		data_browser_jobs.Set_Publish_Translation_Date (p_Application_ID => p_Application_ID);
	END;
	
    PROCEDURE Publish_Translations_Job (
    	p_Application_ID IN NUMBER DEFAULT NV('APP_ID'),
    	p_context  		IN binary_integer DEFAULT FN_Scheduler_Context
    )
	is
		v_Workspace_Name APEX_APPLICATIONS.WORKSPACE%TYPE;
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Steps  		binary_integer;
		v_workspace_id 	NUMBER;
       	CURSOR lang_cur
        IS
			select PRIMARY_APPLICATION_ID, TRANSLATED_APP_LANGUAGE
			from APEX_APPLICATION_TRANS_MAP
			where PRIMARY_APPLICATION_ID = p_Application_ID;
        TYPE stat_tbl IS TABLE OF lang_cur%ROWTYPE;
        v_stat_tbl      stat_tbl;
	begin
		select workspace
		into v_Workspace_Name
		from apex_applications
		where application_id = p_Application_ID;

		v_workspace_id := apex_util.find_security_group_id (p_workspace => v_Workspace_Name);
		apex_util.set_security_group_id (p_security_group_id => v_workspace_id);

        OPEN lang_cur;
        FETCH lang_cur BULK COLLECT INTO v_stat_tbl;
        CLOSE lang_cur;   
		IF v_stat_tbl.FIRST IS NOT NULL THEN
			v_Steps := v_stat_tbl.COUNT * 2;
        	Set_Process_Infos(v_rindex, v_slno, g_Publish_Transl_Proc_Name, p_context, v_Steps, 0, 'steps');
			apex_application_install.generate_offset;
			FOR ind IN 1 .. v_stat_tbl.COUNT
			loop
				apex_lang.seed_translations(
					p_application_id => v_stat_tbl(ind).PRIMARY_APPLICATION_ID,  
					p_language => v_stat_tbl(ind).TRANSLATED_APP_LANGUAGE
				);
	        	Set_Process_Infos(v_rindex, v_slno, g_Publish_Transl_Proc_Name, p_context, v_Steps, ind*2-1, 'steps');
				apex_lang.publish_application(
					p_application_id => v_stat_tbl(ind).PRIMARY_APPLICATION_ID,  
					p_language => v_stat_tbl(ind).TRANSLATED_APP_LANGUAGE
				);
	        	Set_Process_Infos(v_rindex, v_slno, g_Publish_Transl_Proc_Name, p_context, v_Steps, ind*2, 'steps');
			end loop;
		END IF;
		data_browser_jobs.Set_Publish_Translation_Date (p_Application_ID => p_Application_ID);
	exception
	  when others then
	    if lang_cur%ISOPEN then
			CLOSE lang_cur;
		end if;
		Set_Process_Infos(v_rindex, v_slno, g_Publish_Transl_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
	end Publish_Translations_Job;

    PROCEDURE Start_Publish_Translations_Job (
    	p_Application_ID IN NUMBER DEFAULT NV('APP_ID'),
    	p_context  		IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_wait 			IN VARCHAR2 DEFAULT 'YES'
    )
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		if data_browser_jobs.Get_Publish_Translation_State(p_Application_ID) = 'STALE' then 
			v_sql := 'begin ' || chr(10)
				|| 'data_browser_jobs.Publish_Translations_Job('
				|| 'p_Application_ID=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_Application_ID)
				|| ', p_context=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
				|| ');' || chr(10)
				||' end;';
			data_browser_jobs.Load_Job(
				p_Job_Name => 'PUBLISH_TRANSLATIONS',
				p_Comment => g_Publish_Transl_Proc_Name,
				p_Sql => v_sql,
				p_Wait => p_wait,
				p_Skip_When_Scheduled => 'YES'
			);
		end if;
	END Start_Publish_Translations_Job;
	
    PROCEDURE Refresh_ChangeLog_Job (
    	p_context  	IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_Wait 		IN VARCHAR2 DEFAULT 'NO',
    	p_Delay_Seconds IN BINARY_INTEGER DEFAULT 180
    )
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
		v_Count PLS_INTEGER;
	BEGIN
		select count(*) 
		into v_Count
		from user_objects 
		where OBJECT_TYPE = 'PACKAGE' and OBJECT_NAME = 'CUSTOM_CHANGELOG_GEN';

		if v_Count > 0 then 
			v_sql := 'begin ' || chr(10)
				|| 'custom_changelog_gen.Refresh_MViews('
				|| 'p_context=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
				|| ');' || chr(10)
				|| 'custom_changelog_gen.Refresh_ChangeLog_Trigger('
				|| 'p_context=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
				|| ');' || chr(10)
				||' end;';
			data_browser_jobs.Load_Job(
				p_Job_Name => 'RF_CHANGELOG',
				p_Comment => 'Refresh views and trigger for change log',
				p_Sql => v_sql,
				p_Wait => p_Wait,
				p_Delay_Seconds => p_Delay_Seconds,
				p_Skip_When_Scheduled => 'YES'
			);
			COMMIT;
		end if;
	END Refresh_ChangeLog_Job;

     PROCEDURE Prepare_ChangeLog_Job (
    	p_context  	IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_App_ID	IN NUMBER DEFAULT  NV('APP_ID')
    )
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
		v_Count PLS_INTEGER;
	BEGIN
		select count(*) 
		into v_Count
		from user_objects 
		where OBJECT_TYPE = 'PACKAGE' and OBJECT_NAME = 'CUSTOM_CHANGELOG_GEN';

		if v_Count > 0 then 
			v_sql := 'begin ' || chr(10)
				|| 'custom_changelog_gen.Prepare_Tables('
				|| 'p_context=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
				|| ');' || chr(10)
				|| 'data_browser_jobs.Start_Refresh_Mviews_Job('
				|| 'p_App_ID=>' || p_App_ID 
				|| ', p_context=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
				|| ');' || chr(10)
				||' end;';
			data_browser_jobs.Load_Job(
				p_Job_Name => 'PT_CHANGELOG',
				p_Comment => 'Prepare views and trigger for change log',
				p_Sql => v_sql,
				p_Wait => 'YES'
			);
			COMMIT;
		end if;
	END Prepare_ChangeLog_Job;

   PROCEDURE Refresh_After_DDL_Job(
		p_Table_Name        IN VARCHAR2 DEFAULT NULL,
		p_Purge_History		IN VARCHAR2 DEFAULT 'NO'
	)
	IS
        v_context binary_integer := FN_Scheduler_Context;		-- context is of type BINARY_INTEGER
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
		v_Count PLS_INTEGER;
	BEGIN
		select count(*) 
		into v_Count
		from user_objects 
		where OBJECT_TYPE = 'PACKAGE' and OBJECT_NAME = 'CUSTOM_CHANGELOG_GEN';

		v_sql := 'begin ' ||chr(10)
			|| 'delete_check_plugin.Refresh_After_DDL;' ||chr(10);
			if p_Table_Name IS NOT NULL and v_Count > 0 then 
				v_sql := v_sql
				|| 'custom_changelog_gen.Add_ChangeLog_Table_Trigger('
				|| 'p_Table_Name=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name)
				|| ', p_context=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(v_context)
				|| ');'
				|| chr(10)
				|| case when p_Purge_History = 'YES' then 
					'custom_changelog.Delete_Changelog_Rows('
					|| 'p_View_Name=>'
				|| DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name)
				|| ');'
				end;
			end if;
		v_sql := v_sql ||' end;';
		data_browser_jobs.Load_Job(
			p_Job_Name => 'RF_AFTER_DDL',
			p_Comment => 'Refresh views and trigger after DDL operation',
			p_Sql => v_sql,
			p_Wait => 'YES'
		);
	END Refresh_After_DDL_Job;

	PROCEDURE Start_Refresh_Mviews_Job (
    	p_Start_Step 			IN binary_integer DEFAULT g_Refresh_MViews_Start_Unique,
    	p_App_ID				IN NUMBER DEFAULT  NV('APP_ID'),
		p_Owner					IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Delay_Seconds 		IN NUMBER DEFAULT 5,
    	p_Context  				IN binary_integer DEFAULT FN_Scheduler_Context
    )
	is
	begin
		data_browser_jobs.Refresh_MViews_Job(
			p_Owner => p_Owner,
			p_Start_Step => p_Start_Step,
			p_Wait => 'NO',
			p_Delay_Seconds => p_Delay_Seconds,
			p_Context => p_Context
		);
	end Start_Refresh_Mviews_Job;

	FUNCTION Hex_Crypt (
		p_Value VARCHAR2
	) RETURN VARCHAR2 
	IS
		v_Result VARCHAR2(1024);
		v_Query	VARCHAR2(1024);
		cv 		SYS_REFCURSOR;
	BEGIN
		v_Query := 'begin :a := ' || data_browser_jobs.Get_Encrypt_Function('1', ':b') || '; end;';
		EXECUTE IMMEDIATE v_Query USING OUT v_Result, IN p_Value;
		return v_Result;
	END Hex_Crypt;   
    
    PROCEDURE Install_Sup_Obj_Job (
		p_App_ID NUMBER DEFAULT NV('APP_ID'),
		p_Dest_Schema VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Admin_User VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_Admin_Password VARCHAR2,	-- encrypted by g_Encrypt_Function
		p_Admin_EMail VARCHAR2		-- encrypted by g_Encrypt_Function
	)
	IS
	    v_count_Demo PLS_INTEGER;
	    v_count_Custom PLS_INTEGER;
		v_Add_Demo_Guest VARCHAR2(10);
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		select count(*) into v_count_Custom
		from APEX_APPLICATIONS
		where APPLICATION_ID = p_App_ID
		and AUTHENTICATION_SCHEME_TYPE = 'Custom';

	    select count(*) into v_count_Demo
		from APEX_APPLICATION_BUILD_OPTIONS
		where APPLICATION_ID = p_App_ID
		and BUILD_OPTION_NAME = 'Demo Mode' 
		and BUILD_OPTION_STATUS = 'Include';
		
		v_Add_Demo_Guest := case when v_count_Demo > 0 then 'YES' else 'NO' end;
		v_sql :=
			'begin Data_Browser_Install_Sup_Obj('
			|| 'p_App_ID=>' || dbms_assert.enquote_literal(p_App_ID)
			|| ',p_Dest_Schema =>' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ');' || chr(10)
			-- add admin, guest, demo accounts
			|| 'data_browser_schema.First_Run ('
			|| 'p_Dest_Schema => ' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ',p_Admin_User => ' || dbms_assert.enquote_literal(p_Admin_User)
			|| ',p_Admin_Password => ' || data_browser_jobs.Get_Encrypt_Function || '(' || dbms_assert.enquote_literal(p_Admin_Password) || ')'
			|| ',p_Admin_EMail => ' || data_browser_jobs.Get_Encrypt_Function || '(' || dbms_assert.enquote_literal(p_Admin_EMail) || ')'
			|| ',p_Add_Demo_Guest => ' || dbms_assert.enquote_literal(v_Add_Demo_Guest)
			|| ');' || chr(10)
			||' end;';
			Load_Job(
				p_Job_Name => 'INSTALL_SUP_OBJ',
				p_Comment => 'Install supporting objects for data browser application',
				p_Sql => v_sql,
				p_Wait => 'YES'
			);
	END Install_Sup_Obj_Job;

    PROCEDURE DeInstall_Sup_Obj_Job (
		p_App_ID NUMBER DEFAULT NV('APP_ID'),
		p_Dest_Schema VARCHAR2,
		p_Revoke_Privs VARCHAR2 DEFAULT 'NO'
	)
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN 
		v_sql :=
			'begin' || chr(10)
			|| 'Data_Browser_DeInstall_Sup_Obj('
			|| 'p_App_ID=>' || dbms_assert.enquote_literal(p_App_ID)
			|| ',p_Dest_Schema =>' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ');' || chr(10)
			|| case when p_Revoke_Privs = 'YES' then 
				'data_browser_schema.Revoke_Schema ('
				|| 'p_Schema_Name => ' || dbms_assert.enquote_literal(p_Dest_Schema)
				|| ');' || chr(10)
			end
			||' end;';
			Load_Job(
				p_Job_Name => 'DEINSTALL_SUP_OBJ',
				p_Comment => 'DeInstall supporting objects for data browser application',
				p_Sql => v_sql,
				p_Wait => 'YES'
			);
	END DeInstall_Sup_Obj_Job;

    PROCEDURE Duplicate_Schema_Job (
		p_Source_Schema VARCHAR2,
		p_Dest_Schema VARCHAR2,
		p_Dest_Password VARCHAR2,
        p_Application_ID NUMBER DEFAULT NV('APP_ID')
	)
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN 
		v_sql :=
			'begin' || chr(10)
			|| 'data_browser_schema.Add_Schema ('
			|| 'p_Schema_Name =>' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ',p_Password =>' || dbms_assert.enquote_literal(p_Dest_Password)
			|| ');' || chr(10)
			|| 'data_browser_schema.Copy_Schema ('
			|| 'p_source_user => ' || dbms_assert.enquote_literal(p_Source_Schema)
			|| ',p_dest_user =>' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ');' || chr(10)
			|| 'data_browser_schema.Add_Apex_Workspace_Schema ('
			|| 'p_Schema_Name =>' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ',p_Application_ID =>' || dbms_assert.enquote_literal(p_Application_ID)
			|| ');' || chr(10)
			|| 'schema_keychain.Duplicate_Keys ('
			|| 'p_Source_Schema =>' || dbms_assert.enquote_literal(p_Source_Schema)
			|| ',p_Dest_Schema =>' || dbms_assert.enquote_literal(p_Dest_Schema)
			|| ');' || chr(10)
			||' end;';
			Load_Job(
				p_Job_Name => 'DUPLICATE_SCHEMA',
				p_Comment => 'Duplicate schema for data browser application',
				p_Sql => v_sql,
				p_Wait => 'YES'
			);
	END Duplicate_Schema_Job;


	PROCEDURE Refresh_Schema_Stats (
		p_Schema_Name VARCHAR2,
    	p_context binary_integer DEFAULT FN_Scheduler_Context
	)
	IS
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Steps  		constant binary_integer := 3;
	BEGIN
        Set_Process_Infos(v_rindex, v_slno, g_Ref_Schema_Stats_Proc_Name, p_context, v_Steps, 0, 'steps');
		dbms_stats.gather_schema_stats(ownname => p_Schema_Name);
        Set_Process_Infos(v_rindex, v_slno, g_Ref_Schema_Stats_Proc_Name, p_context, v_Steps, 1, 'steps');
		DBMS_MVIEW.REFRESH('MVDATA_BROWSER_VIEWS');
        Set_Process_Infos(v_rindex, v_slno, g_Ref_Schema_Stats_Proc_Name, p_context, v_Steps, 2, 'steps');
		DBMS_MVIEW.REFRESH('MVDATA_BROWSER_FKEYS');
        Set_Process_Infos(v_rindex, v_slno, g_Ref_Schema_Stats_Proc_Name, p_context, v_Steps, 3, 'steps');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, g_Ref_Schema_Stats_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
	END Refresh_Schema_Stats;
	
    PROCEDURE Schema_Stats_Job (p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'))
	IS
        v_context binary_integer := FN_Scheduler_Context;		-- context is of type BINARY_INTEGER
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE  :=
			'begin data_browser_jobs.Refresh_Schema_Stats(p_Schema_Name =>'
			|| DBMS_ASSERT.ENQUOTE_LITERAL(p_Schema_Name)
			|| ',p_context=>'
			|| DBMS_ASSERT.ENQUOTE_LITERAL(v_context)
			|| ');' 
			||' end;';
	BEGIN
		Load_Job(
			p_Job_Name => 'SCHEMA_STATS',
			p_Comment => g_Ref_Schema_Stats_Proc_Name,
			p_Sql => v_sql,
			p_Wait => 'NO',
			p_Skip_When_Scheduled => 'YES'
		);
	END Schema_Stats_Job;

	PROCEDURE Refresh_Tree_View (
    	p_context binary_integer DEFAULT FN_Scheduler_Context,
		p_Schema_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
    )
	IS
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Steps  		binary_integer := 1;
		CURSOR Tables_cur1
		IS
			SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, TABLE_NAME
			FROM SYS.USER_TAB_STATISTICS T
			WHERE (STALE_STATS = 'YES' OR STALE_STATS IS NULL)
			AND STATTYPE_LOCKED IS NULL
			AND TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND data_browser_pattern.Match_Included_Tables(T.TABLE_NAME) = 'YES'
			AND data_browser_pattern.Match_Excluded_Tables(T.TABLE_NAME) = 'NO'
			AND NOT EXISTS (    -- this table is part of materialized view
				SELECT 1
				FROM SYS.USER_OBJECTS MV
				WHERE MV.OBJECT_NAME = T.TABLE_NAME
				AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
			);
			
		CURSOR Tables_cur2
		IS
			SELECT OWNER, TABLE_NAME
			FROM SYS.ALL_TAB_STATISTICS T
			WHERE (STALE_STATS = 'YES' OR STALE_STATS IS NULL)
			AND STATTYPE_LOCKED IS NULL
			AND OWNER = p_Schema_Name
			AND TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND data_browser_pattern.Match_Included_Tables(T.TABLE_NAME) = 'YES'
			AND data_browser_pattern.Match_Excluded_Tables(T.TABLE_NAME) = 'NO'
			AND NOT EXISTS (    -- this table is part of materialized view
				SELECT 1
				FROM SYS.ALL_OBJECTS MV
				WHERE MV.OBJECT_NAME = T.TABLE_NAME
				AND MV.OWNER = T.OWNER
				AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
			);
		TYPE tables_tbl2 IS TABLE OF Tables_cur2%ROWTYPE;
		v_in_recs 	tables_tbl2;
	BEGIN
		if p_Schema_Name = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
			OPEN Tables_cur1;
			FETCH Tables_cur1 BULK COLLECT INTO v_in_recs;
			CLOSE Tables_cur1;
		else
			OPEN Tables_cur2;
			FETCH Tables_cur2 BULK COLLECT INTO v_in_recs;
			CLOSE Tables_cur2;
		end if;
		IF v_in_recs.FIRST IS NOT NULL THEN
			v_Steps := v_in_recs.COUNT + 2;
	        Set_Process_Infos(v_rindex, v_slno, g_Ref_Tree_View_Proc_Name, p_context, v_Steps, 0, 'tables');
			FOR ind IN 1 .. v_in_recs.COUNT
			LOOP
				DBMS_STATS.GATHER_TABLE_STATS(v_in_recs(ind).OWNER, v_in_recs(ind).TABLE_NAME);
				DBMS_OUTPUT.PUT_LINE('-- Refreshed stats for ' || v_in_recs(ind).TABLE_NAME);
		        Set_Process_Infos(v_rindex, v_slno, g_Ref_Tree_View_Proc_Name, p_context, v_Steps, ind, 'tables');
			END LOOP;
			DBMS_MVIEW.REFRESH('MVDATA_BROWSER_DESCRIPTIONS');
			Set_Process_Infos(v_rindex, v_slno, g_Ref_Tree_View_Proc_Name, p_context, v_Steps, v_Steps - 1, 'tables');
			DBMS_MVIEW.REFRESH('MVDATA_BROWSER_REFERENCES');
		END IF;
        Set_Process_Infos(v_rindex, v_slno, g_Ref_Tree_View_Proc_Name, p_context, v_Steps, v_Steps, 'tables');
	exception
	  when others then
	    if Tables_cur1%ISOPEN then
			CLOSE Tables_cur1;
		end if;
	    if Tables_cur2%ISOPEN then
			CLOSE Tables_cur2;
		end if;
		Set_Process_Infos(v_rindex, v_slno, g_Ref_Tree_View_Proc_Name, p_context, v_Steps, v_Steps, 'tables');
		raise;
	END Refresh_Tree_View;

    PROCEDURE Refresh_Tree_View_Job
	IS
		v_LAST_REFRESH_DATE	USER_MVIEWS.LAST_REFRESH_DATE%TYPE := Get_MView_Last_Refresh_Date('MVDATA_BROWSER_REFERENCES');
		v_Modus VARCHAR2(20);
        v_context binary_integer := FN_Scheduler_Context;		-- context is of type BINARY_INTEGER
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		v_Modus := case when v_LAST_REFRESH_DATE IS NULL 
						then 'IMMEDIATE' 
					when SYSDATE - (1/24/60/60 * 15) > v_LAST_REFRESH_DATE  -- at least 15 seconds old
						then 'SCHEDULED'
					else 
						'SKIPPED'
					end;
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_jobs.Refresh_Tree_View_Job (v_context => %s)',
				p0 => v_context
			);
		$END
		if v_Modus = 'IMMEDIATE' then
			data_browser_jobs.Refresh_Tree_View(p_context=>v_context);
		elsif v_Modus = 'SCHEDULED' then 
			v_sql := 'begin ' ||chr(10)
			|| 'data_browser_jobs.Refresh_Tree_View(p_context=>'
			|| DBMS_ASSERT.ENQUOTE_LITERAL(v_context)
			|| ');' 
			||' end;';
			Load_Job(
				p_Job_Name => 'TREE_STATS',
				p_Comment => g_Ref_Tree_View_Proc_Name,
				p_Sql => v_sql,
				p_Wait => 'NO',
				p_Skip_When_Scheduled => 'YES'
			);
 		end if;
	END Refresh_Tree_View_Job;

	FUNCTION Get_User_Job_State_Peek (
		p_Job_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	IS
		v_Job_Name 	USER_SCHEDULER_JOBS.JOB_NAME%TYPE := SUBSTR(data_browser_jobs.Get_Job_Name_Prefix || p_Job_Name, 1, 17);
		v_Running_Count binary_integer := 0;
		v_Scheduled_Count binary_integer := 0;
		v_Job_State	USER_SCHEDULER_JOBS.STATE%TYPE := 'DONE';
	BEGIN
		COMMIT; -- start a new transaction, to load fresh data.
		SELECT SUM(case when STATE = 'RUNNING' then 1 end) Running_Count,
			SUM(case when STATE = 'SCHEDULED' then 1 end) Scheduled_Count
		INTO v_Running_Count,  v_Scheduled_Count
		FROM SYS.USER_SCHEDULER_JOBS 
		WHERE JOB_NAME LIKE v_Job_Name || '%';
		v_Job_State := case 
			when v_Running_Count > 0 then 'RUNNING'
			when v_Scheduled_Count > 0 then 'SCHEDULED'
			else 'DONE'
		end;
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_jobs.Get_User_Job_State_Peek Job_State : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Job_State)
			);
		$END
		return v_Job_State;
	END Get_User_Job_State_Peek;

	FUNCTION Get_User_Job_State1 (
    	p_context  	IN binary_integer DEFAULT FN_Scheduler_Context
    )
	RETURN VARCHAR2
	IS
		v_Job_State	USER_SCHEDULER_JOBS.STATE%TYPE := 'DONE';
		v_Collections_Name CONSTANT APEX_COLLECTIONS.COLLECTION_NAME%TYPE := data_browser_jobs.Get_Jobs_Collection; 
		v_Sequence_Count binary_integer := 0;
		v_Time_Range CONSTANT NUMBER := (1 / 24 / 60 * 2); --  2 minuteS
		v_Short_Range CONSTANT NUMBER := (1 / 24 / 60 / 60 * 20); --  20 seconds
        CURSOR jobs_cur
        IS
			SELECT	DISTINCT
					S.SID, S.SERIAL#, S.SOFAR, S.TOTALWORK, S.CONTEXT, S.START_TIME, 
					S.LAST_UPDATE_TIME, S.MESSAGE, S.TIME_REMAINING, S.ELAPSED_TIME, S.PERCENT,
					D.SEQ_ID, D.SID_D, D.SERIAL_D, D.SOFAR_D, D.TOTALWORK_D, D.CONTEXT_D,
					D.LAST_UPDATE_TIME_D, D.MESSAGE_D, D.DATA_SOURCE
			FROM (
				SELECT SID, SERIAL#, MESSAGE, 
                    SOFAR, TOTALWORK, CONTEXT, START_TIME, LAST_UPDATE_TIME, 
                    TO_CHAR(TIME_REMAINING, 'HH24:MI.SS') TIME_REMAINING,                     
                    TO_CHAR(ELAPSED_TIME, 'HH24:MI.SS') ELAPSED_TIME,                     
                    PERCENT
				FROM (
					SELECT DISTINCT
						SID, SERIAL#, MESSAGE, 
                        SOFAR, TOTALWORK, CONTEXT, START_TIME, LAST_UPDATE_TIME, 
                        DATE '0001-01-01' + (1 / 24 / 60 / 60 * TIME_REMAINING) TIME_REMAINING,
                        DATE '0001-01-01' + (1 / 24 / 60 / 60 * ELAPSED_SECONDS) ELAPSED_TIME,
						ROUND(NVL(SOFAR / NULLIF(TOTALWORK, 0), 1) * 100) AS PERCENT
					FROM V$SESSION_LONGOPS
					--, (select (1 / 24 / 60 * 2) v_Time_Range, (1 / 24 / 60 / 60 * 10) v_Short_Range, null p_context from dual) P
					WHERE USERNAME = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
					AND (CONTEXT IN (p_context, 0) or p_context IS NULL)		-- context is of type BINARY_INTEGER
					AND LAST_UPDATE_TIME between SYSDATE - v_Time_Range and SYSDATE
					AND (SOFAR < TOTALWORK OR LAST_UPDATE_TIME between SYSDATE - v_Short_Range and SYSDATE)
					ORDER BY LAST_UPDATE_TIME DESC, TOTALWORK-SOFAR DESC
				) WHERE ROWNUM <= 10
			) S 
			FULL OUTER JOIN (
				SELECT  SEQ_ID, N001 SID_D, N002 SERIAL_D, C001 MESSAGE_D, 
						N003 SOFAR_D, N004 TOTALWORK_D, N005 CONTEXT_D,
						D002 LAST_UPDATE_TIME_D, C005 DATA_SOURCE
				FROM APEX_COLLECTIONS 
				where COLLECTION_NAME = v_Collections_Name
			) D ON S.SID = D.SID_D AND (S.SERIAL# = D.SERIAL_D OR S.MESSAGE LIKE D.MESSAGE_D||'%' AND D.DATA_SOURCE = 'USER_SCHEDULER_JOBS' )
			ORDER BY D.SEQ_ID NULLS LAST, S.LAST_UPDATE_TIME;
		TYPE Jobs_Tab IS TABLE OF jobs_cur%ROWTYPE;
		v_jobs 			Jobs_Tab;

 	BEGIN
		if apex_collection.collection_exists(v_Collections_Name) then
			apex_collection.resequence_collection ( p_collection_name=>v_Collections_Name);
		else
			apex_collection.create_or_truncate_collection(p_collection_name=>v_Collections_Name);
		end if;

		OPEN jobs_cur;
		FETCH jobs_cur BULK COLLECT INTO v_jobs;
		CLOSE jobs_cur;
		if v_jobs.COUNT > 0 then
			FOR ind IN 1 .. v_jobs.COUNT LOOP
				begin
					if v_jobs(ind).SID_D IS NULL 									-- new row in V$SESSION_LONGOPS
					and v_jobs(ind).SOFAR < v_jobs(ind).TOTALWORK 
					then 
						APEX_COLLECTION.ADD_MEMBER (
							p_collection_name => v_Collections_Name,
							p_n001 => v_jobs(ind).SID,
							p_n002 => v_jobs(ind).SERIAL#,
							p_n003 => v_jobs(ind).SOFAR,
							p_n004 => v_jobs(ind).TOTALWORK,
							p_n005 => v_jobs(ind).CONTEXT,
							p_d001 => v_jobs(ind).START_TIME,
							p_d002 => v_jobs(ind).LAST_UPDATE_TIME,
							p_c001 => v_jobs(ind).MESSAGE,
							p_c002 => v_jobs(ind).TIME_REMAINING,
							p_c003 => v_jobs(ind).ELAPSED_TIME,
							p_c004 => v_jobs(ind).PERCENT,
							p_c005 => 'V$SESSION_LONGOPS',
							p_c006 => to_char(v_jobs(ind).LAST_UPDATE_TIME, 'HH24:MI:SS')
						);
						v_Sequence_Count := v_Sequence_Count + 1;
					elsif v_jobs(ind).SID = v_jobs(ind).SID_D and (v_jobs(ind).SERIAL# = v_jobs(ind).SERIAL_D
					    or v_jobs(ind).MESSAGE LIKE v_jobs(ind).MESSAGE_D||'%' 
					    	and v_jobs(ind).DATA_SOURCE = 'USER_SCHEDULER_JOBS')
					and v_jobs(ind).SOFAR < v_jobs(ind).TOTALWORK
					then
						APEX_COLLECTION.UPDATE_MEMBER (
							p_collection_name => v_Collections_Name,
							p_seq =>  v_jobs(ind).SEQ_ID,
							p_n001 => v_jobs(ind).SID,
							p_n002 => v_jobs(ind).SERIAL#,
							p_n003 => v_jobs(ind).SOFAR,
							p_n004 => v_jobs(ind).TOTALWORK,
							p_n005 => v_jobs(ind).CONTEXT,
							p_d001 => v_jobs(ind).START_TIME,
							p_d002 => v_jobs(ind).LAST_UPDATE_TIME,
							p_c001 => v_jobs(ind).MESSAGE,
							p_c002 => v_jobs(ind).TIME_REMAINING,
							p_c003 => v_jobs(ind).ELAPSED_TIME,
							p_c004 => v_jobs(ind).PERCENT,
							p_c005 => 'V$SESSION_LONGOPS',
							p_c006 => to_char(v_jobs(ind).LAST_UPDATE_TIME, 'HH24:MI:SS')
						);
						v_Sequence_Count := v_Sequence_Count + 1;
					elsif (v_jobs(ind).SID = v_jobs(ind).SID_D and v_jobs(ind).SERIAL# = v_jobs(ind).SERIAL_D 
						and v_jobs(ind).SOFAR = v_jobs(ind).TOTALWORK) -- job is now updated to completed
						 or (v_jobs(ind).SOFAR_D = v_jobs(ind).TOTALWORK_D)					-- job is recently updated to completed
						 or (v_jobs(ind).LAST_UPDATE_TIME_D not between SYSDATE - v_Short_Range and SYSDATE) -- not updated in the last 5 minute
					then
						APEX_COLLECTION.DELETE_MEMBER ( 
							p_collection_name => v_Collections_Name, 
							p_seq => v_jobs(ind).SEQ_ID
						);
					elsif (v_jobs(ind).SID = v_jobs(ind).SID_D and v_jobs(ind).SERIAL# = v_jobs(ind).SERIAL_D) then
						v_Sequence_Count := v_Sequence_Count + 1;
					end if;
				end;
			end loop;
		end if;
		-- v_Sequence_Count := APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name => v_Collections_Name);
		if v_Sequence_Count > 0 then
			v_Job_State := 'RUNNING';
		end if;
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_jobs.Get_User_Job_State1 Job_State : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Job_State)
			);
		$END
		COMMIT;
		RETURN v_Job_State;
	exception
	  when others then
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_jobs.Get_User_Job_State1 Error : %s',
				p0 => DBMS_UTILITY.FORMAT_ERROR_STACK 
			);
		$END
		rollback;
		RETURN 'DONE';
	END Get_User_Job_State1;

	FUNCTION Get_User_Job_State2 (
		p_Job_Name VARCHAR2 DEFAULT NULL,
    	p_context  	IN binary_integer DEFAULT FN_Scheduler_Context
	) RETURN VARCHAR2
	IS
		v_Job_State	USER_SCHEDULER_JOBS.STATE%TYPE := 'DONE';
		v_Collections_Name CONSTANT APEX_COLLECTIONS.COLLECTION_NAME%TYPE := data_browser_jobs.Get_Jobs_Collection; 
		v_Sequence_Count binary_integer := 0;
		v_Job_Name 	USER_SCHEDULER_JOBS.JOB_NAME%TYPE := SUBSTR(data_browser_jobs.Get_Job_Name_Prefix || p_Job_Name, 1, 17);
		v_Time_Range CONSTANT NUMBER := (1 / 24 / 60 * 2); --  2 minutes
		v_Short_Range CONSTANT NUMBER := (1 / 24 / 60 / 60 * 5); --  5 seconds
        CURSOR jobs_cur2
        IS
        	with job_stats_q as (
				select SUBSTR(JOB_NAME, 1, 17) JOB_NAME, NVL(AVG((((DATE '0001-01-01') + RUN_DURATION)-(DATE '0001-01-01'))), 120) Estimated_Time
				from USER_SCHEDULER_JOB_RUN_DETAILS 
				where STATUS = 'SUCCEEDED'
				and ACTUAL_START_DATE > SYSDATE-2
				GROUP BY SUBSTR(JOB_NAME, 1, 17)
        	)
			SELECT	DISTINCT
					S.SID, S.SERIAL#, S.SOFAR, S.TOTALWORK, S.CONTEXT, S.START_TIME, 
					S.LAST_UPDATE_TIME, S.MESSAGE, S.TIME_REMAINING, S.ELAPSED_TIME, S.PERCENT, S.STATE,
					D.SEQ_ID, D.SID_D, D.SERIAL_D, D.SOFAR_D, D.TOTALWORK_D, D.CONTEXT_D,
					D.LAST_UPDATE_TIME_D, MESSAGE_D, D.DATA_SOURCE
			FROM (
				SELECT SID, SERIAL#, MESSAGE, SOFAR, TOTALWORK, CONTEXT, START_TIME, LAST_UPDATE_TIME, 
					TO_CHAR(TIME_REMAINING, 'HH24:MI.SS') TIME_REMAINING, 
					TO_CHAR(ELAPSED_TIME, 'HH24:MI.SS') ELAPSED_TIME, 
					ROUND(LEAST((ELAPSED_TIME - (DATE '0001-01-01')) / estimated_time * 100, 100), 2) PERCENT,
					STATE, JOB_NAME
				FROM (
					SELECT DISTINCT
							NVL(B.SESSION_ID, 0) SID, 
							NVL(ORA_HASH(A.CLIENT_ID), 0) SERIAL#,
							case when A.STATE = 'FINISHED' then 1 else 0 end SOFAR, 
							1 TOTALWORK, 
							p_context CONTEXT,
							CAST(A.START_DATE AS DATE) START_TIME, 
                            CAST((A.START_DATE + B.ELAPSED_TIME)AS DATE) LAST_UPDATE_TIME, 
							A.COMMENTS MESSAGE, 
							(DATE '0001-01-01'+ NVL(S.Estimated_Time * 1.2, v_Time_Range)) - B.ELAPSED_TIME TIME_REMAINING, 
							DATE '0001-01-01'+B.ELAPSED_TIME ELAPSED_TIME,
							A.STATE, A.JOB_NAME, NVL(S.Estimated_Time * 1.2, v_Time_Range) Estimated_Time
					FROM USER_SCHEDULER_JOBS A
					JOIN USER_SCHEDULER_RUNNING_JOBS B ON A.JOB_NAME = B.JOB_NAME
					LEFT OUTER JOIN job_stats_q S ON S.JOB_NAME = SUBSTR(B.JOB_NAME, 1, 17)
					WHERE A.JOB_NAME LIKE v_Job_Name || '%'
					ORDER BY START_TIME DESC
				) WHERE ROWNUM <= 10
			) S 
			FULL OUTER JOIN (
				SELECT  SEQ_ID, N001 SID_D, N002 SERIAL_D, C001 MESSAGE_D, 
						N003 SOFAR_D, N004 TOTALWORK_D, N005 CONTEXT_D,
						D002 LAST_UPDATE_TIME_D, C005 DATA_SOURCE
				FROM APEX_COLLECTIONS 
				where COLLECTION_NAME = v_Collections_Name
			) D ON S.SID = D.SID_D AND (S.SERIAL# = D.SERIAL_D OR D.MESSAGE_D LIKE S.MESSAGE||'%' AND D.DATA_SOURCE = 'V$SESSION_LONGOPS')
			ORDER BY D.SEQ_ID NULLS LAST, S.LAST_UPDATE_TIME;
		TYPE Jobs_Tab2 IS TABLE OF jobs_cur2%ROWTYPE;
		v_jobs2 			Jobs_Tab2;
	BEGIN
		if apex_collection.collection_exists(v_Collections_Name) then
			apex_collection.resequence_collection ( p_collection_name=>v_Collections_Name);
		else
			apex_collection.create_or_truncate_collection(p_collection_name=>v_Collections_Name);
		end if;
		OPEN jobs_cur2;
		FETCH jobs_cur2 BULK COLLECT INTO v_jobs2;
		CLOSE jobs_cur2;
		if v_jobs2.COUNT > 0 then
			FOR ind IN 1 .. v_jobs2.COUNT LOOP
			begin
				if v_jobs2(ind).SID_D IS NULL 	-- new row in V$SESSION_LONGOPS
				then 
					APEX_COLLECTION.ADD_MEMBER (
						p_collection_name => v_Collections_Name,
						p_n001 => v_jobs2(ind).SID,
						p_n002 => v_jobs2(ind).SERIAL#,
						p_n003 => v_jobs2(ind).SOFAR,
						p_n004 => v_jobs2(ind).TOTALWORK,
						p_n005 => v_jobs2(ind).CONTEXT,
						p_d001 => v_jobs2(ind).START_TIME,
						p_d002 => v_jobs2(ind).LAST_UPDATE_TIME,
						p_c001 => v_jobs2(ind).MESSAGE,
						p_c002 => v_jobs2(ind).TIME_REMAINING,
						p_c003 => v_jobs2(ind).ELAPSED_TIME,
						p_c004 => v_jobs2(ind).PERCENT,
						p_c005 => 'USER_SCHEDULER_JOBS',
						p_c006 => to_char(v_jobs2(ind).LAST_UPDATE_TIME, 'HH24:MI:SS')
					);
					v_Sequence_Count := v_Sequence_Count + 1;
				elsif v_jobs2(ind).SID = v_jobs2(ind).SID_D 
				and v_jobs2(ind).MESSAGE_D LIKE v_jobs2(ind).MESSAGE||'%' 
				and v_jobs2(ind).DATA_SOURCE = 'V$SESSION_LONGOPS' then 
					v_Sequence_Count := v_Sequence_Count + 1;
				elsif v_jobs2(ind).SID = v_jobs2(ind).SID_D and v_jobs2(ind).SERIAL# = v_jobs2(ind).SERIAL_D
				then
					APEX_COLLECTION.UPDATE_MEMBER (
						p_collection_name => v_Collections_Name,
						p_seq =>  v_jobs2(ind).SEQ_ID,
						p_n001 => v_jobs2(ind).SID,
						p_n002 => v_jobs2(ind).SERIAL#,
						p_n003 => v_jobs2(ind).SOFAR,
						p_n004 => v_jobs2(ind).TOTALWORK,
						p_n005 => v_jobs2(ind).CONTEXT,
						p_d001 => v_jobs2(ind).START_TIME,
						p_d002 => v_jobs2(ind).LAST_UPDATE_TIME,
						p_c001 => v_jobs2(ind).MESSAGE,
						p_c002 => v_jobs2(ind).TIME_REMAINING,
						p_c003 => v_jobs2(ind).ELAPSED_TIME,
						p_c004 => v_jobs2(ind).PERCENT,
						p_c005 => 'USER_SCHEDULER_JOBS',
						p_c006 => to_char(v_jobs2(ind).LAST_UPDATE_TIME, 'HH24:MI:SS')
					);
					v_Sequence_Count := v_Sequence_Count + 1;
				elsif v_jobs2(ind).LAST_UPDATE_TIME_D < SYSDATE - v_Short_Range  -- not seen in the last 5 seconds
				  or v_jobs2(ind).DATA_SOURCE = 'USER_SCHEDULER_JOBS'
				then
					APEX_COLLECTION.DELETE_MEMBER ( 
						p_collection_name => v_Collections_Name, 
						p_seq => v_jobs2(ind).SEQ_ID
					);
				elsif (v_jobs2(ind).SID = v_jobs2(ind).SID_D and v_jobs2(ind).SERIAL# = v_jobs2(ind).SERIAL_D) then
					v_Sequence_Count := v_Sequence_Count + 1;
				end if;
			end;
			---------------------------------------------------------------------------
			end loop;
		end if;

		-- v_Sequence_Count := APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name => v_Collections_Name);
		if v_Sequence_Count > 0 then
			v_Job_State := 'RUNNING';
		end if;
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_jobs.Get_User_Job_State2 (p_Job_Name=> %s) v_Job_Name : %s, Job_State : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Job_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Job_Name),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Job_State)
			);
		$END
		COMMIT;
		RETURN v_Job_State;
	exception
	  when others then
		$IF data_browser_jobs.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_jobs.Get_User_Job_State2 Error : %s',
				p0 => DBMS_UTILITY.FORMAT_ERROR_STACK 
			);
		$END
		rollback;
		RETURN 'DONE';
	END Get_User_Job_State2;

	FUNCTION Get_User_Job_State (
		p_Job_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	IS
		v_Job_State	USER_SCHEDULER_JOBS.STATE%TYPE;
	BEGIN
		v_Job_State := data_browser_jobs.Get_User_Job_State1; -- from SESSION_LONGOPS 
		if v_Job_State = 'DONE' then 
			return data_browser_jobs.Get_User_Job_State2(p_Job_Name); -- from RUNNING_JOBS 
		end if;
		RETURN v_Job_State;
	END Get_User_Job_State;

	FUNCTION FN_Pipe_user_running_jobs
	RETURN data_browser_jobs.tab_user_job_states PIPELINED
	IS
		PRAGMA UDF;
		PRAGMA AUTONOMOUS_TRANSACTION;
		v_Job_State	USER_SCHEDULER_JOBS.STATE%TYPE;
		
        CURSOR views_cur
        IS
			SELECT  DISTINCT
					N001 SID, N002 SERIAL#, CAST(C001 AS VARCHAR2(512)) MESSAGE, N003 SOFAR, N004 TOTALWORK, N005 CONTEXT,
					D001 START_TIME, D002 LAST_UPDATE_TIME,
					CAST(C002 AS VARCHAR2(50)) TIME_REMAINING, CAST(C003 AS VARCHAR2(50)) ELAPSED_TIME, TO_NUMBER(C004) PERCENT
			FROM APEX_COLLECTIONS 
			where COLLECTION_NAME = data_browser_jobs.Get_Jobs_Collection
			;
        v_in_rows tab_user_job_states;
	BEGIN
		v_Job_State := data_browser_jobs.Get_User_Job_State;
		OPEN views_cur;
		LOOP
			FETCH views_cur BULK COLLECT INTO v_in_rows LIMIT 100;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE views_cur;
		COMMIT;
	END FN_Pipe_user_running_jobs;

END data_browser_jobs;
/

/*
exec data_browser_jobs.Set_Publish_Translation_Date(2000);

select M.TRANSLATED_APP_LANGUAGE, M.TRANSLATED_APPLICATION_ID,
        data_browser_jobs.Get_Publish_Translation_Date (M.PRIMARY_APPLICATION_ID) LAST_UPDATED_ON,
        data_browser_jobs.Get_Publish_Translation_Date (M.PRIMARY_APPLICATION_ID) SINCE,
        case when A.LAST_UPDATED_ON <= data_browser_jobs.Get_Publish_Translation_Date (M.PRIMARY_APPLICATION_ID) 
            then 'Yes' else 'No' end UP_TO_DATE,
        M.TRANSLATION_COMMENTS
  from APEX_APPLICATION_TRANS_MAP M
  join APEX_APPLICATIONS A on M.PRIMARY_APPLICATION_ID = A.APPLICATION_ID
 where M.PRIMARY_APPLICATION_ID = 2000;
*/
