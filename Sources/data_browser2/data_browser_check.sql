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
*/

/*
-- Required privileges:
GRANT SELECT ON SYS.V_$STATNAME TO OWNER;
GRANT SELECT ON SYS.V_$MYSTAT TO OWNER;
----

DROP TABLE DATA_BROWSER_CHECKS;
DROP PACKAGE data_browser_check;

*/
declare
	v_Count PLS_INTEGER;
begin
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'DATA_BROWSER_CHECKS' and column_name = 'DATA_FORMAT';
	if v_Count = 0 then
		EXECUTE IMMEDIATE 'ALTER TABLE DATA_BROWSER_CHECKS ADD (
			DATA_FORMAT VARCHAR2(10)
		)';
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_sequences where sequence_name = 'DATA_BROWSER_CHECKS_SEQ';
	if v_Count = 0 then
		EXECUTE IMMEDIATE 'CREATE SEQUENCE DATA_BROWSER_CHECKS_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE';
	end if;
end;
/


CREATE OR REPLACE TRIGGER "DATA_BROWSER_CHECKS_BI_TR" 
BEFORE INSERT ON DATA_BROWSER_CHECKS FOR EACH ROW 
BEGIN 
    SELECT DATA_BROWSER_CHECKS_SEQ.NEXTVAL INTO :new.SEQUENCE_ID FROM DUAL;
END;
/


CREATE OR REPLACE PACKAGE data_browser_check
AUTHID DEFINER -- problem - create_collection_from_query ParseErr:ORA-00942: Tabelle oder View nicht vorhanden 
IS
	g_use_exceptions CONSTANT BOOLEAN 		:= TRUE;

	FUNCTION FN_Scheduler_Context RETURN BINARY_INTEGER;

	PROCEDURE Load_Query_Generator (
		p_View_Mode IN VARCHAR2 DEFAULT NULL,
		p_Table_name IN VARCHAR2 DEFAULT NULL,
		p_Schema   IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	);

	FUNCTION Next_GUI_Test_Case_ID (
		p_Report_Mode IN VARCHAR2 DEFAULT 'YES' -- YES, NO
	)
	RETURN NUMBER;

	PROCEDURE Next_GUI_Test_Case_ID (
		p_Report_Mode IN VARCHAR2 DEFAULT 'YES', -- YES, NO
		p_Produce_Requests IN VARCHAR2 DEFAULT 'NO', -- YES, NO
		p_Next_ID OUT NUMBER,
		p_Requests OUT VARCHAR2
	);

	PROCEDURE Mark_GUI_Test_Case (
		p_Sequence_ID IN NUMBER,
		p_Phase IN VARCHAR2 DEFAULT 'GET'		-- GET, PUT
    );

	PROCEDURE Load_Test_Case (
		p_Sequence_ID IN NUMBER,
    	p_Table_Name OUT VARCHAR2,
    	p_Unique_Key_Column OUT VARCHAR2,
    	p_Select_Columns OUT VARCHAR2,
    	p_Columns_Limit OUT INTEGER,
		p_View_Mode OUT VARCHAR2,
    	p_Join_Options OUT VARCHAR2,
		p_Edit_Mode OUT VARCHAR2,
		p_Report_Mode OUT VARCHAR2,
		p_Data_Source OUT VARCHAR2,
		p_Data_Format OUT VARCHAR2,
    	p_Order_by OUT VARCHAR2,
    	p_Order_Direction OUT VARCHAR2,
    	p_Control_Break OUT VARCHAR2,
    	p_Calc_Totals OUT VARCHAR2,
    	p_Nested_Links OUT VARCHAR2,
		p_Constraint_Name OUT VARCHAR2,
    	p_Parent_Name OUT VARCHAR2,
    	p_Parent_Key_Column OUT VARCHAR2,
    	p_Parent_Key_Visible OUT VARCHAR2
    );
	PROCEDURE Set_Cursor_Sharing(p_Modus VARCHAR2 DEFAULT 'EXACT'); -- EXACT / FORCE
    PROCEDURE Clear_Query_Generator;

    PROCEDURE Reset_Query_Checks;
    PROCEDURE Reset_GUI_Checks;
    PROCEDURE Delete_Query_Checks;

	PROCEDURE Test_Query_Generator (
		p_Table_name IN VARCHAR2 DEFAULT '%',
		p_Dump_Text IN VARCHAR2 DEFAULT 'NO',
		p_Show_Loops IN VARCHAR2 DEFAULT 'NO',
		p_Load_Data IN VARCHAR2 DEFAULT 'NO',
		p_Execute_Queries IN VARCHAR2 DEFAULT 'NO',
		p_Max_Errors IN INTEGER DEFAULT 1000,
		p_Max_Loops IN INTEGER DEFAULT NULL,
		p_app_id IN INTEGER DEFAULT NVL(NV('APP_ID'), 2000),
		p_page_id IN INTEGER DEFAULT 30,
		p_username IN VARCHAR2 DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')),
		p_Schema   IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	);

	PROCEDURE Test_Import_Generator (
		p_Table_name IN VARCHAR2 DEFAULT '%',
		p_Dump_Text IN VARCHAR2 DEFAULT 'NO',
		p_Show_Loops IN VARCHAR2 DEFAULT 'NO',
		p_Max_Errors IN INTEGER DEFAULT 1000,
		p_Max_Loops IN INTEGER DEFAULT NULL,
		p_app_id IN INTEGER DEFAULT NVL(NV('APP_ID'), 2000),
		p_page_id IN INTEGER DEFAULT 30,
		p_username IN VARCHAR2 DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')),
		p_Schema   IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	);

    PROCEDURE Load_Query_Generator_Job(
		p_Enabled VARCHAR2 DEFAULT 'YES',
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	);

    PROCEDURE Test_Query_Generator_Job(
		p_Enabled VARCHAR2 DEFAULT 'YES',
		p_app_id IN INTEGER DEFAULT NVL(NV('APP_ID'), 2000),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	);
END data_browser_check;
/
show errors




CREATE OR REPLACE PACKAGE BODY data_browser_check
IS
	g_Load_Query_Gen_Proc_Name CONSTANT VARCHAR2(128) := 'Load Query Generator test cases for data browser application';
	g_Test_Query_Gen_Proc_Name CONSTANT VARCHAR2(128) := 'Test Query Generator for data browser application';
	g_Test_Import_Gen_Proc_Name CONSTANT VARCHAR2(128) := 'Test Import Generator for data browser application';

	FUNCTION FN_Scheduler_Context RETURN BINARY_INTEGER
	IS 
	BEGIN RETURN NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0);
	END FN_Scheduler_Context;

	FUNCTION Get_Stat (p_Stat IN VARCHAR2) RETURN NUMBER
	as
	  	v_result  number;
    	v_Query	VARCHAR2(2000);
		cv 		SYS_REFCURSOR;
	begin -- function will return null, when the access to the views has not been granted
		v_Query := '
		select ms.value from   sys.v_$mystat ms
		  join   sys.v_$statname sn
		  on     ms.statistic# = sn.statistic#
		  and    sn.name = :a';
		OPEN cv FOR v_Query USING p_Stat;
		FETCH cv INTO v_result;
		CLOSE cv;
		
	  	return v_result;
	end get_stat;

	FUNCTION Get_Elapsed_Time (
		p_Timemark IN OUT NUMBER,
		p_Message IN VARCHAR2) RETURN VARCHAR2
	is
		v_Timemark number := dbms_utility.get_time;
		v_TimeString VARCHAR2(40) := TO_CHAR((v_Timemark - p_Timemark)/100.0, '9G990D00');
	begin
		p_Timemark := v_Timemark;
		return p_Message||chr(9)||v_TimeString;
	end;

	PROCEDURE Log_Elapsed_Time (
		p_Timemark IN OUT NUMBER,
		p_Memory IN OUT NUMBER,
		p_Logbook IN OUT NOCOPY VARCHAR2,
		p_Message IN VARCHAR2,
		p_Access_Memory IN VARCHAR2 DEFAULT 'NO'
	)
	is
		v_Timemark number;
		v_Memory number;
		v_TimeString VARCHAR2(40);
		v_MemoryString VARCHAR2(40);
	begin
		v_Timemark := dbms_utility.get_time;
		v_TimeString := TO_CHAR((v_Timemark - p_Timemark)/100.0, '9G990D00');
		if p_Access_Memory = 'YES' then
			v_Memory := data_browser_check.Get_Stat('session pga memory');
			v_MemoryString := TO_CHAR((v_Memory - p_Memory)/1024, '999G999G990') || ' Kb';
		end if;
		p_Logbook := p_Logbook||p_Message||chr(9)||v_TimeString||chr(9)||v_MemoryString||chr(10);
		p_Timemark := v_Timemark;
$IF NOT(data_browser_check.g_use_exceptions) $THEN
		DBMS_OUTPUT.PUT_LINE(p_Message);
$END
	end;

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
    BEGIN
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
    END;

	PROCEDURE Load_Query_Generator (
		p_View_Mode IN VARCHAR2 DEFAULT NULL,
		p_Table_name IN VARCHAR2 DEFAULT NULL,
		p_Schema   IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	)
	is
		CURSOR cur_outer_checks IS 
		SELECT 
			E.EDIT_MODE,
			ER.EMPTY_ROWS,
			PV.PARENT_KEY_VISIBLE,
			CS.CALC_SUBTOTALS,
			NL.NESTED_LINKS,
			ICCI.IMP_COMPARE_CASE_INSENSITIVE,
			ISUN.IMP_SEARCH_KEYS_UNIQUE,
			IIFK.IMP_INSERT_FOREIGN_KEYS,
			CL.COLUMNS_LIMIT,
			ST.SEARCH_TEXT
		FROM (SELECT COLUMN_VALUE EDIT_MODE FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) E
		cross join (SELECT COLUMN_VALUE EMPTY_ROWS FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) ER
		cross join (SELECT COLUMN_VALUE PARENT_KEY_VISIBLE FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) PV
		cross join (SELECT COLUMN_VALUE CALC_SUBTOTALS FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) CS
		cross join (SELECT COLUMN_VALUE NESTED_LINKS FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) NL
		cross join (SELECT COLUMN_VALUE IMP_COMPARE_CASE_INSENSITIVE FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) ICCI
		cross join (SELECT COLUMN_VALUE IMP_SEARCH_KEYS_UNIQUE FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) ISUN
		cross join (SELECT COLUMN_VALUE IMP_INSERT_FOREIGN_KEYS FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) IIFK
		cross join (SELECT COLUMN_VALUE SEARCH_TEXT FROM TABLE( data_browser_conf.in_list('NO, YES', ','))) ST
		cross join (SELECT COLUMN_VALUE COLUMNS_LIMIT FROM TABLE( data_browser_conf.in_list('20, 1000', ','))) CL
		where (CALC_SUBTOTALS = 'NO' OR EDIT_MODE = 'NO' )
		and (IMP_COMPARE_CASE_INSENSITIVE = 'NO' and IMP_SEARCH_KEYS_UNIQUE = 'NO' and IMP_INSERT_FOREIGN_KEYS = 'NO' OR EDIT_MODE = 'YES');
        TYPE outer_checks_tbl IS TABLE OF cur_outer_checks%ROWTYPE;
        v_insert_cnt	binary_integer := 0;
        v_stat_tbl 		outer_checks_tbl;
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Steps  		binary_integer;
	begin
		data_browser_check.Set_Cursor_Sharing(p_Modus => 'FORCE');
        OPEN cur_outer_checks;
        FETCH cur_outer_checks
        BULK COLLECT INTO v_stat_tbl;
        CLOSE cur_outer_checks;
		IF v_stat_tbl.FIRST IS NOT NULL THEN
			v_Steps := v_stat_tbl.COUNT + 4;
			Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, 0, 'steps');
			data_browser_check.Test_Query_Generator_Job(p_Enabled=>'NO');
			Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, 1, 'steps');
			data_browser_jobs.Refresh_Tree_View_Job;	-- statistics 
			Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, 2, 'steps');
			data_browser_jobs.Refresh_MViews;			-- structure
			Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, 3, 'steps');
			data_browser_jobs.Refresh_ChangeLog_Job;	-- history
			Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, 4, 'steps');
			if p_Table_name IS NULL then 
				EXECUTE IMMEDIATE 'TRUNCATE TABLE DATA_BROWSER_CHECKS';
			else 
				DELETE FROM DATA_BROWSER_CHECKS WHERE VIEW_NAME = p_Table_name;
				COMMIT;
			end if;
			FOR ind IN 1 .. v_stat_tbl.COUNT
			LOOP
				Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, ind + 4, 'steps');
		
				insert /*+ APPEND */ into DATA_BROWSER_CHECKS (
					VIEW_NAME, LINK_KEY, ORDER_BY, CONTROL_BREAK, LINK_ID, VIEW_MODE, PARENT_NAME, PARENT_KEY_COLUMN, REPORT_MODE, EDIT_MODE, 
					ROW_OPERATOR, DATA_SOURCE, DATA_FORMAT, EMPTY_ROWS, JOIN_OPTIONS, PARENT_KEY_VISIBLE, CALC_SUBTOTALS, NESTED_LINKS, COLUMNS_LIMIT, SEARCH_TEXT,
					IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS)
				WITH REFS_Q AS (
					SELECT VIEW_NAME, PARENT_NAME, PARENT_KEY_COLUMN
					FROM (
					SELECT FK.VIEW_NAME, FK.R_VIEW_NAME PARENT_NAME,
							FK.FOREIGN_KEY_COLS PARENT_KEY_COLUMN,
							ROW_NUMBER() OVER (PARTITION BY FK.VIEW_NAME ORDER BY FK.FOREIGN_KEY_COLS) RN
					FROM MVDATA_BROWSER_FKEYS FK
					) whERE RN <= 3
					UNION ALL -- test empty PARENT_NAME, PARENT_KEY_COLUMN
					SELECT VIEW_NAME, NULL PARENT_NAME, NULL PARENT_KEY_COLUMN
					FROM MVDATA_BROWSER_DESCRIPTIONS
				),
				COLS_Q AS (
					SELECT VIEW_NAME, COUNT(*) COLUMN_CNT
					FROM MVDATA_BROWSER_SIMPLE_COLS
					GROUP BY VIEW_NAME 
				),
				TABS_Q AS (
					select 
						T.VIEW_NAME,
						T.LINK_KEY, T.NUM_ROWS, 
						T.ORDER_BY, T.CONTROL_BREAK,
						NULLIF(L.LINK_ID, 'NULL') LINK_ID,
						T.VIEW_MODE,
						T.PARENT_NAME,
						T.PARENT_KEY_COLUMN,
						R.REPORT_MODE,
						v_stat_tbl(ind).EDIT_MODE EDIT_MODE,
						NR.ROW_OPERATOR,
						DS.DATA_SOURCE,
						DF.DATA_FORMAT,
						v_stat_tbl(ind).EMPTY_ROWS EMPTY_ROWS,
						J.JOIN_OPTIONS,
						v_stat_tbl(ind).PARENT_KEY_VISIBLE PARENT_KEY_VISIBLE,
						v_stat_tbl(ind).CALC_SUBTOTALS CALC_SUBTOTALS,
						v_stat_tbl(ind).NESTED_LINKS NESTED_LINKS,
						v_stat_tbl(ind).COLUMNS_LIMIT COLUMNS_LIMIT,
						v_stat_tbl(ind).SEARCH_TEXT SEARCH_TEXT,
						v_stat_tbl(ind).IMP_COMPARE_CASE_INSENSITIVE IMP_COMPARE_CASE_INSENSITIVE,
						v_stat_tbl(ind).IMP_SEARCH_KEYS_UNIQUE IMP_SEARCH_KEYS_UNIQUE,
						v_stat_tbl(ind).IMP_INSERT_FOREIGN_KEYS IMP_INSERT_FOREIGN_KEYS
					from (select M.COLUMN_VALUE VIEW_MODE, T.VIEW_NAME, T.SEARCH_KEY_COLS LINK_KEY, T.NUM_ROWS, T.READ_ONLY,
							FK.PARENT_NAME, FK.PARENT_KEY_COLUMN,
							case when T.VIEW_NAME != 'DATA_BROWSER_CHECKS' then -- !! to do : optimize query generator to handle large table in edit mode
								TX.COLUMN_NAME
							end ORDER_BY,
							case when T.VIEW_NAME != 'DATA_BROWSER_CHECKS' then 
								TX.COLUMN_DATA
							end CONTROL_BREAK
						from TABLE ( data_browser_conf.in_list('FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW, CALENDAR, TREE_VIEW, HISTORY', ',')) M
						cross join MVDATA_BROWSER_DESCRIPTIONS T
						left outer join REFS_Q FK ON T.VIEW_NAME = FK.VIEW_NAME 
						, TABLE(data_browser_utl.Get_Default_Order_by_Cursor(
								p_Table_Name => T.VIEW_NAME, 
								p_Unique_Key_Column => T.SEARCH_KEY_COLS,
								p_Columns_Limit => v_stat_tbl(ind).COLUMNS_LIMIT,
								p_View_Mode => M.COLUMN_VALUE,
								p_Parent_Name => FK.PARENT_NAME,
								p_Parent_Key_Column => FK.PARENT_KEY_COLUMN,
								p_Parent_Key_Visible => v_stat_tbl(ind).PARENT_KEY_VISIBLE
							)) TX
                        where NOT(M.COLUMN_VALUE = 'CALENDAR' AND T.CALEND_START_DATE_COLUMN_NAME IS  NULL)
                        and NOT(M.COLUMN_VALUE = 'TREE_VIEW' AND T.FOLDER_PARENT_COLUMN_NAME IS NULL )
                        and NOT(M.COLUMN_VALUE IN ('NAVIGATION_VIEW', 'NESTED_VIEW') AND IS_REFERENCED_KEY = 'NO')
					) T
					cross join (SELECT COLUMN_VALUE DATA_SOURCE FROM TABLE( data_browser_conf.in_list('TABLE, NEW_ROWS, MEMORY, COLLECTION', ','))) DS
					cross join (SELECT COLUMN_VALUE LINK_ID FROM TABLE( data_browser_conf.in_list('1, NULL', ','))) L 
					cross join (SELECT COLUMN_VALUE DATA_FORMAT FROM TABLE( data_browser_conf.in_list('FORM, CSV, NATIVE, HTML', ','))) DF 
					join COLS_Q CC ON T.VIEW_NAME = CC.VIEW_NAME 
					left outer join (SELECT COLUMN_VALUE ROW_OPERATOR
									 FROM TABLE( data_browser_conf.in_list('INSERT, UPDATE, DELETE, DUPLICATE, MOVE_ROWS, COPY_ROWS, MERGE_ROWS', ','))
									) NR ON (T.VIEW_MODE = 'FORM_VIEW' OR NR.ROW_OPERATOR IN ('INSERT', 'UPDATE', 'DELETE', 'MERGE_ROWS'))
					left outer join (SELECT COLUMN_VALUE REPORT_MODE FROM TABLE( data_browser_conf.in_list('NO, YES', ','))
									) R ON T.VIEW_MODE IN ('RECORD_VIEW', 'FORM_VIEW', 'EXPORT_VIEW')
					left outer join (SELECT COLUMN_VALUE JOIN_OPTIONS FROM TABLE( data_browser_conf.in_list('K, A, N', ','))
									) J ON T.VIEW_MODE IN ('EXPORT_VIEW', 'IMPORT_VIEW') 
									AND (T.VIEW_MODE != 'IMPORT_VIEW' OR J.JOIN_OPTIONS IN ('K', 'A'))
					where (v_stat_tbl(ind).COLUMNS_LIMIT < CC.COLUMN_CNT OR v_stat_tbl(ind).COLUMNS_LIMIT = 1000)
					and (v_stat_tbl(ind).CALC_SUBTOTALS = 'NO' OR (v_stat_tbl(ind).EDIT_MODE = 'NO' AND T.VIEW_MODE = 'NAVIGATION_VIEW'))
					and (v_stat_tbl(ind).NESTED_LINKS = 'NO' OR T.VIEW_MODE = 'NAVIGATION_VIEW')
					and (v_stat_tbl(ind).EDIT_MODE = 'YES' OR (NR.ROW_OPERATOR = 'UPDATE' AND DS.DATA_SOURCE = 'TABLE'))
					and (v_stat_tbl(ind).EDIT_MODE = 'NO' OR (DF.DATA_FORMAT = 'FORM'))					
					and (v_stat_tbl(ind).EDIT_MODE = 'NO' OR T.READ_ONLY = 'NO')					
					and T.VIEW_NAME = NVL(p_Table_name, T.VIEW_NAME)
				)
				select VIEW_NAME, LINK_KEY, ORDER_BY, CONTROL_BREAK, LINK_ID, VIEW_MODE, 
					PARENT_NAME, PARENT_KEY_COLUMN, REPORT_MODE, EDIT_MODE, 
					ROW_OPERATOR, DATA_SOURCE, DATA_FORMAT, EMPTY_ROWS, JOIN_OPTIONS, PARENT_KEY_VISIBLE, CALC_SUBTOTALS, NESTED_LINKS, COLUMNS_LIMIT, SEARCH_TEXT,
					IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS
				from (
					select VIEW_NAME, LINK_KEY, LINK_ID, PARENT_NAME, PARENT_KEY_COLUMN, VIEW_MODE,
						NVL(REPORT_MODE, 'YES') REPORT_MODE, EDIT_MODE, ROW_OPERATOR, DATA_SOURCE, DATA_FORMAT, EMPTY_ROWS, ORDER_BY, CONTROL_BREAK,
						case when JOIN_OPTIONS IS NOT NULL then data_browser_joins.Get_Default_Join_Options(VIEW_NAME, JOIN_OPTIONS) end JOIN_OPTIONS,
						PARENT_KEY_VISIBLE, CALC_SUBTOTALS, NESTED_LINKS, COLUMNS_LIMIT, SEARCH_TEXT, 
						IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS, NUM_ROWS
					from tabs_q
				)
				where not (EDIT_MODE = 'NO' and DATA_SOURCE = 'MEMORY')
				and not (VIEW_MODE = 'HISTORY' and (DATA_SOURCE != 'TABLE' or EDIT_MODE = 'YES'
					or data_browser_conf.Has_ChangeLog_History(p_Table_Name => VIEW_NAME) = 'NO'))
				and not (DATA_SOURCE = 'COLLECTION' and VIEW_MODE != 'IMPORT_VIEW')
				and not (VIEW_MODE IN ('CALENDAR', 'TREE_VIEW') and (DATA_SOURCE != 'TABLE' or EDIT_MODE = 'YES' or ROW_OPERATOR != 'UPDATE' or REPORT_MODE = 'NO') )
				and not (PARENT_NAME IS NULL and ROW_OPERATOR IN ('MOVE_ROWS', 'COPY_ROWS'))
				and not ((EDIT_MODE = 'NO' or EMPTY_ROWS = 'YES') and ROW_OPERATOR IN ('DELETE', 'DUPLICATE', 'MOVE_ROWS', 'COPY_ROWS', 'MERGE_ROWS'))
				and not (REPORT_MODE = 'NO' and ROW_OPERATOR IN ('MOVE_ROWS', 'COPY_ROWS', 'MERGE_ROWS'))
				and not ((PARENT_NAME IS NULL and DATA_SOURCE != 'COLLECTION') and ROW_OPERATOR = 'MERGE_ROWS')
				and not (DATA_SOURCE in ('NEW_ROWS', 'MEMORY') and ROW_OPERATOR = 'MERGE_ROWS')
				and not (SEARCH_TEXT = 'YES' and (ROW_OPERATOR != 'UPDATE' or NUM_ROWS > data_browser_conf.Get_Automatic_Search_Limit or VIEW_NAME = 'DATA_BROWSER_CHECKS') )
				and not (LINK_ID IS NOT NULL and (ROW_OPERATOR != 'UPDATE' or REPORT_MODE = 'YES' or DATA_SOURCE in ('NEW_ROWS', 'MEMORY')) ) -- edit single record
				and not (CALC_SUBTOTALS = 'YES' and (ROW_OPERATOR != 'UPDATE' or REPORT_MODE = 'NO' or DATA_SOURCE != 'TABLE'))
				and not ('YES' IN (IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS) 
						and not(VIEW_MODE = 'IMPORT_VIEW' 
						and REPORT_MODE = 'YES'
						and ROW_OPERATOR = 'UPDATE' 
						and DATA_SOURCE = 'COLLECTION' 
						and EMPTY_ROWS = 'NO' 
						and EDIT_MODE = 'YES' 
						and PARENT_KEY_VISIBLE = 'YES'
						and SEARCH_TEXT = 'NO')
				)
				and VIEW_MODE = NVL(p_View_Mode, VIEW_MODE)
				;
				v_insert_cnt := v_insert_cnt + SQL%ROWCOUNT;
				commit;
			END LOOP;
		END IF;
		dbms_output.PUT_LINE( v_insert_cnt || ' test cases have been prepared.');
		data_browser_check.Set_Cursor_Sharing(p_Modus => 'EXACT');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, g_Load_Query_Gen_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
	end Load_Query_Generator;


	FUNCTION Next_GUI_Test_Case_ID (
		p_Report_Mode IN VARCHAR2 DEFAULT 'YES' -- YES, NO
	)
	RETURN NUMBER
	IS 
		v_Next_ID NUMBER;
	BEGIN 
		SELECT SEQUENCE_ID INTO v_Next_ID
		FROM DATA_BROWSER_CHECKS
		WHERE CHECKED_GUI_GET = 'N'
		AND CHECK_GUI_GET_RELEVANT = 'Y'
		AND REPORT_MODE = p_Report_Mode
		AND ROWNUM = 1;
		RETURN v_Next_ID;
	exception
	  when NO_DATA_FOUND then
	  	RETURN NULL;
	END Next_GUI_Test_Case_ID;

	PROCEDURE Next_GUI_Test_Case_ID (
		p_Report_Mode IN VARCHAR2 DEFAULT 'YES', -- YES, NO
		p_Produce_Requests IN VARCHAR2 DEFAULT 'NO', -- YES, NO
		p_Next_ID OUT NUMBER,
		p_Requests OUT VARCHAR2
	)
	IS 
		v_Next_ID NUMBER;
		v_Requests VARCHAR2(250);
		v_Test_Type VARCHAR2(20);
	BEGIN 
		SELECT SEQUENCE_ID, REQUESTS, TEST_TYPE
		INTO v_Next_ID, v_Requests, v_Test_Type
		FROM (
			SELECT SEQUENCE_ID, 
				'COPY_TO_COLLECTION:VALIDATE_CSV_FILE:PROCESS_IMPORT:NEXT_TEST_CASE' REQUESTS,
				'PUT' TEST_TYPE
			FROM DATA_BROWSER_CHECKS A
			WHERE CHECKED_GUI_PUT = 'N' 
			AND CHECK_GUI_IMP_RELEVANT = 'Y'
			AND EXISTS (
				SELECT 1 
				FROM MVDATA_BROWSER_DESCRIPTIONS B
				WHERE B.VIEW_NAME = A.VIEW_NAME 
				AND B.UNIQUE_COLUMN_NAMES IS NOT NULL
				AND B.HAS_NULLABLE = 0
			)
			AND REPORT_MODE = p_Report_Mode
			and p_Produce_Requests = 'YES'
			UNION ALL 
			SELECT SEQUENCE_ID, 
				case when p_Produce_Requests = 'YES' 
					and CHECK_GUI_PUT_RELEVANT = 'Y'
					then 'SAVE_REPORT:NEXT_TEST_CASE' end REQUESTS,
				'GET' TEST_TYPE
			FROM DATA_BROWSER_CHECKS A
			WHERE CHECKED_GUI_GET = 'N'
			AND NOT ( CHECK_GUI_IMP_RELEVANT = 'Y'
			AND EXISTS (
				SELECT 1 
				FROM MVDATA_BROWSER_DESCRIPTIONS B
				WHERE B.VIEW_NAME = A.VIEW_NAME 
				AND B.UNIQUE_COLUMN_NAMES IS NOT NULL
				AND B.HAS_NULLABLE = 0
			))
			AND REPORT_MODE = p_Report_Mode
			AND CHECK_GUI_GET_RELEVANT = 'Y'
			ORDER BY SEQUENCE_ID
		)
		WHERE ROWNUM = 1;
		UPDATE DATA_BROWSER_CHECKS
			SET CHECKED_GUI_GET = 'X',
				CHECKED_GUI_PUT = 'X'
		WHERE SEQUENCE_ID = v_Next_ID;
		COMMIT;
		p_Next_ID := v_Next_ID;
		p_Requests := v_Requests;
	exception
	  when NO_DATA_FOUND then
		p_Next_ID := NULL;
		p_Requests := NULL;
	END Next_GUI_Test_Case_ID;

	PROCEDURE Mark_GUI_Test_Case (
		p_Sequence_ID IN NUMBER,
		p_Phase IN VARCHAR2 DEFAULT 'GET'		-- GET, PUT
    )
    is
    begin
    	if p_Phase = 'GET' then 
			UPDATE DATA_BROWSER_CHECKS
			SET CHECKED_GUI_GET = 'Y'
			WHERE SEQUENCE_ID = p_Sequence_ID;
		else
			UPDATE DATA_BROWSER_CHECKS
			SET CHECKED_GUI_PUT = 'Y'
			WHERE SEQUENCE_ID = p_Sequence_ID;
		end if;
		COMMIT;
	end Mark_GUI_Test_Case;

	PROCEDURE Load_Test_Case (
		p_Sequence_ID IN NUMBER,
    	p_Table_Name OUT VARCHAR2,
    	p_Unique_Key_Column OUT VARCHAR2,
    	p_Select_Columns OUT VARCHAR2,
    	p_Columns_Limit OUT INTEGER,
		p_View_Mode OUT VARCHAR2,
    	p_Join_Options OUT VARCHAR2,
		p_Edit_Mode OUT VARCHAR2,
		p_Report_Mode OUT VARCHAR2,
		p_Data_Source OUT VARCHAR2,
		p_Data_Format OUT VARCHAR2,
    	p_Order_by OUT VARCHAR2,
    	p_Order_Direction OUT VARCHAR2,
    	p_Control_Break OUT VARCHAR2,
    	p_Calc_Totals OUT VARCHAR2,
    	p_Nested_Links OUT VARCHAR2,
		p_Constraint_Name OUT VARCHAR2,
    	p_Parent_Name OUT VARCHAR2,
    	p_Parent_Key_Column OUT VARCHAR2,
    	p_Parent_Key_Visible OUT VARCHAR2
    ) 
    is
    	v_Row_Operator 					DATA_BROWSER_CHECKS.ROW_OPERATOR%TYPE;
    	v_Imp_Compare_Case_Insensitive  DATA_BROWSER_CHECKS.IMP_COMPARE_CASE_INSENSITIVE%TYPE;
    	v_Imp_Search_Keys_Unique		DATA_BROWSER_CHECKS.IMP_SEARCH_KEYS_UNIQUE%TYPE;
    	v_Imp_Insert_Foreign_Keys		DATA_BROWSER_CHECKS.IMP_INSERT_FOREIGN_KEYS%TYPE;
    begin
    	if p_Sequence_ID IS NOT NULL then 
			SELECT VIEW_NAME, LINK_KEY, '' SELECT_COLUMNS, COLUMNS_LIMIT,
				VIEW_MODE, JOIN_OPTIONS, EDIT_MODE, REPORT_MODE, DATA_SOURCE, DATA_FORMAT,
				ORDER_BY, '' ORDER_DIRECTION, CONTROL_BREAK, CALC_SUBTOTALS, NESTED_LINKS,
				PARENT_NAME, PARENT_KEY_COLUMN, PARENT_KEY_VISIBLE, ROW_OPERATOR,
				IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS
			INTO p_Table_Name, p_Unique_Key_Column, p_Select_Columns, p_Columns_Limit, 
				p_View_Mode, p_Join_Options, p_Edit_Mode, p_Report_Mode, p_Data_Source, p_Data_Format,
				p_Order_by, p_Order_Direction, p_Control_Break, p_Calc_Totals, p_Nested_Links,
				p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, v_Row_Operator,
				v_Imp_Compare_Case_Insensitive, v_Imp_Search_Keys_Unique, v_Imp_Insert_Foreign_Keys
			FROM DATA_BROWSER_CHECKS
			WHERE SEQUENCE_ID = p_Sequence_ID;

			SELECT MIN(CONSTRAINT_NAME) INTO p_Constraint_Name
			FROM MVDATA_BROWSER_FKEYS
			WHERE VIEW_NAME = p_Table_Name
			AND R_VIEW_NAME = p_Parent_Name
			AND FOREIGN_KEY_COLS = p_Parent_Key_Column ;
			if p_Constraint_Name IS NULL then 
				SELECT NVL(CONSTRAINT_NAME, VIEW_NAME) into p_Constraint_Name
				FROM MVDATA_BROWSER_VIEWS
				WHERE VIEW_NAME = p_Table_Name;
			end if;
			
			if p_Edit_Mode = 'YES' and p_View_Mode = 'FORM' and v_Row_Operator = 'INSERT' and p_Data_Source IN ('NEW_ROWS', 'TABLE') then
				p_Data_Source := 'NEW_ROWS';
			end if;
			
			data_browser_conf.Set_Import_Parameter (
				p_Compare_Case_Insensitive	=> v_Imp_Compare_Case_Insensitive,
				p_Search_Keys_Unique 	=> v_Imp_Search_Keys_Unique,
				p_Insert_Foreign_Keys 	=> v_Imp_Insert_Foreign_Keys
			);
    	end if;
    exception 
	when no_data_found then
		return;
	end Load_Test_Case;

	PROCEDURE Set_Cursor_Sharing(p_Modus VARCHAR2 DEFAULT 'EXACT') -- EXACT / FORCE
    is
    	v_Stat VARCHAR2(120);
    begin
		v_Stat := 'ALTER SESSION SET CURSOR_SHARING=' || NVL(p_Modus, 'FORCE');
		EXECUTE IMMEDIATE v_Stat;
	end Set_Cursor_Sharing;

    PROCEDURE Clear_Query_Generator
    is
    begin
		update DATA_BROWSER_CHECKS set checked = 'N', checked_import = 'N', 
			VALIDATION_SQL_CODE = null, VALIDATION_SQL_MESSAGE = null, VALIDATION_PARSE_TIME = null, 
			VALIDATION_ROW_COUNT = null, VALIDATION_TEXT = null, 
			LOOKUP_SQL_CODE = null, LOOKUP_SQL_MESSAGE = null, LOOKUP_PARSE_TIME = null,
			DML_SQL_CODE = null, DML_SQL_MESSAGE = null, DML_PARSE_TIME = null, DML_ROW_COUNT = null,
			QUERY_SQL_CODE = null, QUERY_SQL_MESSAGE = null,  QUERY_TEXT = null, QUERY_GENERATION_TIME = null, 
			QUERY_PARSE_TIME = null, QUERY_EXECUTE_TIME = null, QUERY_ROW_COUNT = null, QUERY_COL_COUNT = null,
			ELAPSED_TIME = null
		where coalesce(QUERY_SQL_CODE,VALIDATION_SQL_CODE,LOOKUP_SQL_CODE,DML_SQL_CODE) IS NOT NULL;
		update DATA_BROWSER_CHECKS 
			set CHECKED_GUI_GET = 'N'
		where CHECKED_GUI_GET = 'X'
		and CHECK_GUI_GET_RELEVANT = 'Y'
		;
		update DATA_BROWSER_CHECKS 
			set CHECKED_GUI_PUT = 'N', CHECKED_GUI_GET = 'N'
		where CHECKED_GUI_PUT = 'X'
		and CHECK_GUI_PUT_RELEVANT = 'Y'
		;
		commit;
	end Clear_Query_Generator;

    PROCEDURE Reset_Query_Checks
    is
    begin
		update DATA_BROWSER_CHECKS set checked = 'N', checked_import = 'N', 
			VALIDATION_SQL_CODE = null, VALIDATION_SQL_MESSAGE = null, VALIDATION_PARSE_TIME = null, 
			VALIDATION_ROW_COUNT = null, VALIDATION_TEXT = null, 
			LOOKUP_SQL_CODE = null, LOOKUP_SQL_MESSAGE = null, LOOKUP_PARSE_TIME = null,
			DML_SQL_CODE = null, DML_SQL_MESSAGE = null, DML_PARSE_TIME = null, DML_ROW_COUNT = null,
			QUERY_SQL_CODE = null, QUERY_SQL_MESSAGE = null,  QUERY_TEXT = null, QUERY_GENERATION_TIME = null, 
			QUERY_PARSE_TIME = null, QUERY_EXECUTE_TIME = null, QUERY_ROW_COUNT = null, QUERY_COL_COUNT = null,
			ELAPSED_TIME = null
		;
		commit;
	end Reset_Query_Checks;

    PROCEDURE Reset_GUI_Checks
    is
    begin
		update DATA_BROWSER_CHECKS set CHECKED_GUI_GET = 'N', CHECKED_GUI_PUT = 'N'; 
		commit;
	end Reset_GUI_Checks;

    PROCEDURE Delete_Query_Checks
    is
    begin
		delete from DATA_BROWSER_CHECKS;
		commit;
	end Delete_Query_Checks;

	PROCEDURE Test_Query_Generator (
		p_Table_name IN VARCHAR2 DEFAULT '%',
		p_Dump_Text IN VARCHAR2 DEFAULT 'NO',
		p_Show_Loops IN VARCHAR2 DEFAULT 'NO',
		p_Load_Data IN VARCHAR2 DEFAULT 'NO',
		p_Execute_Queries IN VARCHAR2 DEFAULT 'NO',
		p_Max_Errors IN INTEGER DEFAULT 1000,
		p_Max_Loops IN INTEGER DEFAULT NULL,
		p_app_id IN INTEGER DEFAULT NVL(NV('APP_ID'), 2000),
		p_page_id IN INTEGER DEFAULT 30,
		p_username IN VARCHAR2 DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')),
		p_Schema   IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	)
	IS
		v_Stat CLOB;
    	v_Offset INTEGER;
        v_Row_Count PLS_INTEGER := 1;
        v_Log_Book VARCHAR2(32767);
		v_Timemark NUMBER := dbms_utility.get_time;
		v_Count PLS_INTEGER := 0;
		v_Start_TM NUMBER;
		v_Loop_TM NUMBER;
		v_Loop_Dur NUMBER;
		v_Memory number := data_browser_check.Get_Stat('session pga memory');
		v_Err_Msg VARCHAR2(2048);
		v_Err_Found NUMBER;
		v_Error_Count PLS_INTEGER := 0;
		v_cur INTEGER;
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Steps  		binary_integer;
        v_Query_Row_Count PLS_INTEGER := 0;
        v_Query_Col_Count PLS_INTEGER := 0;
		v_Rows_Inserted PLS_INTEGER := 0;
		v_Rows_Updated 	PLS_INTEGER := 0;
		v_Key_Values 	apex_t_varchar2;
	begin
		v_Start_TM := v_Timemark;
		v_Count := 0;
		apex_session.create_session ( 
			p_app_id => p_app_id,
			p_page_id => p_page_id,
			p_username => p_username
		);
		APEX_UTIL.SET_SESSION_STATE('P30_PARENT_KEY_ID', '1');
		APEX_UTIL.SET_SESSION_STATE('P30_SEARCH', '777');
		APEX_UTIL.SET_SESSION_STATE('APP_PARSING_SCHEMA', p_Schema);
		data_browser_check.Set_Cursor_Sharing(p_Modus => 'FORCE');
		select count(*) into v_Steps
		from DATA_BROWSER_CHECKS
		where (VIEW_NAME LIKE p_Table_name OR p_Table_name IS NULL)
		and (CHECKED = 'N');
		v_Steps := case when v_Steps > p_Max_Loops then p_Max_Loops else v_Steps end;
		for view_cur IN (
			select SEQUENCE_ID, VIEW_NAME, LINK_KEY, ORDER_BY, CONTROL_BREAK, LINK_ID, VIEW_MODE,
				PARENT_NAME, PARENT_KEY_COLUMN, REPORT_MODE, EDIT_MODE, 
				ROW_OPERATOR, DATA_SOURCE, DATA_FORMAT, EMPTY_ROWS, JOIN_OPTIONS,
				PARENT_KEY_VISIBLE, CALC_SUBTOTALS, NESTED_LINKS, COLUMNS_LIMIT, SEARCH_TEXT,
				IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS
			from DATA_BROWSER_CHECKS
			where (VIEW_NAME LIKE p_Table_name OR p_Table_name IS NULL)
			and (CHECKED = 'N')
			order by VIEW_NAME, VIEW_MODE, REPORT_MODE, EDIT_MODE, JOIN_OPTIONS
		)
		LOOP
        	Set_Process_Infos(v_rindex, v_slno, g_Test_Query_Gen_Proc_Name, p_context, v_Steps, v_Count, 'steps');
			v_Count := v_Count +  1;
			v_Loop_TM := dbms_utility.get_time;
			v_Stat := NULL;
			v_Log_Book := NULL;
			v_Err_Msg := NULL;
			v_Err_Found := 0;
			data_browser_check.Log_Elapsed_Time (
				p_Timemark => v_Timemark,
				p_Memory => v_Memory,
				p_Logbook => v_Log_Book,
				p_Message =>
					RPAD('-', 70, '-')
					|| chr(10)
					|| '-- '
					|| v_Count
					|| '. (#' || view_cur.SEQUENCE_ID
					|| ') -- View=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.VIEW_NAME)
					|| ', View_Mode=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.VIEW_MODE)
					|| ', Report_Mode=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.REPORT_MODE)
					|| ', Edit_Mode=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.EDIT_MODE)
					|| ', Row_Operator=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.ROW_OPERATOR)
					|| ', Data_Source=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.DATA_SOURCE)
					|| ', Data_Format=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.DATA_FORMAT)
					|| ', Empty_Rows=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.EMPTY_ROWS)
					|| chr(10)
					|| '--    , Join_Options=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.JOIN_OPTIONS)
					|| ', Parent_Name=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.PARENT_NAME)
					|| ', Parent_Key_Column=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.PARENT_KEY_COLUMN)
					|| ', Link_Key=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.LINK_KEY)
					|| ', Order_by=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.ORDER_BY)
					|| ', Control_Break=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.CONTROL_BREAK)
			);
			if view_cur.ROW_OPERATOR = 'UPDATE' then
				v_Stat := NULL;
				data_browser_conf.Set_Import_Parameter (
					p_Compare_Case_Insensitive	=> view_cur.IMP_COMPARE_CASE_INSENSITIVE,
					p_Search_Keys_Unique 	=> view_cur.IMP_SEARCH_KEYS_UNIQUE,
					p_Insert_Foreign_Keys 	=> view_cur.IMP_INSERT_FOREIGN_KEYS
				);
				data_browser_conf.Set_Include_Query_Schema('YES');
				begin -- generate query
					v_Err_Msg := NULL;
					v_Stat := data_browser_utl.Get_Record_View_Query( 
						p_Table_name => view_cur.VIEW_NAME,
						p_Unique_Key_Column => view_cur.LINK_KEY,
						p_Search_Value => view_cur.LINK_ID,
						p_Data_Columns_Only => 'NO',
						p_Columns_Limit =>  view_cur.COLUMNS_LIMIT,
						p_Compact_Queries => 'YES',
						p_View_Mode => view_cur.VIEW_MODE,
						p_Report_Mode => view_cur.REPORT_MODE,
						p_Edit_Mode => view_cur.EDIT_MODE,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Data_Format => view_cur.DATA_FORMAT,
						p_Empty_Row => view_cur.EMPTY_ROWS,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Parent_Table => view_cur.PARENT_NAME,
						p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Parent_Key_Item => 'P30_PARENT_KEY_ID',
						p_Search_Field_Item=> case when view_cur.SEARCH_TEXT = 'YES' then 'P30_SEARCH' end,
						p_Link_Page_ID => 32,
						p_Link_Parameter => 'P32_TABLE_NAME,P32_LINK_ID,P32_PARENT_NAME,P32_DETAIL_TABLE,P32_DETAIL_KEY,P32_DETAIL_ID',
						p_File_Page_ID => 31,
						p_Text_Editor_Page_ID => 42,
						p_Order_by => view_cur.ORDER_BY,
						p_Order_Direction => 'ASC NULLS LAST',
						p_Calc_Totals => view_cur.CALC_SUBTOTALS,
						p_Nested_Links => view_cur.NESTED_LINKS,
						p_Control_Break => view_cur.CONTROL_BREAK,
						p_Source_Query => case when view_cur.VIEW_MODE = 'HISTORY' then
							data_browser_conf.ChangeLog_Pivot_Query(p_Table_Name => view_cur.VIEW_NAME)
						end
					) ;
$IF data_browser_check.g_use_exceptions $THEN
				exception when others then
					v_Err_Msg := '-- SQL Error :' || SQLCODE || ' ' || SQLERRM || chr(10);
					v_Err_Found := SQLCODE;
					v_Error_Count := v_Error_Count + 1;

					UPDATE DATA_BROWSER_CHECKS
						SET QUERY_TEXT = v_Stat,
							QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
							QUERY_SQL_CODE = v_Err_Found,
							QUERY_SQL_MESSAGE = SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000)
					WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
					COMMIT;
$END
				end;
				UPDATE DATA_BROWSER_CHECKS
					SET QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
						QUERY_GENERATION_TIME = dbms_utility.get_time - v_Timemark
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;

				data_browser_check.Log_Elapsed_Time (
					p_Timemark => v_Timemark,
					p_Memory => v_Memory,
					p_Logbook => v_Log_Book,
					p_Message => '-- Query    : ' || DBMS_LOB.GETLENGTH(v_Stat) || ' '  || v_Err_Msg);
				---------------------------------------------------------
				if v_Stat IS NOT NULL then
					if view_cur.DATA_SOURCE = 'MEMORY'  -- fetching data from apex_application is not possible here
					or p_Execute_Queries = 'NO' then
						begin -- open and parse query
							v_Err_Msg := NULL;
							v_cur := dbms_sql.open_cursor;
							dbms_sql.parse(v_cur, v_Stat, DBMS_SQL.NATIVE);
							dbms_sql.close_cursor(v_cur);
$IF data_browser_check.g_use_exceptions $THEN
						exception when others then
							v_Err_Msg := '-- SQL Error :' || SQLCODE || ' ' || SQLERRM || chr(10);
							v_Err_Found := SQLCODE;
							v_Error_Count := v_Error_Count + 1;
							if dbms_sql.is_open(v_cur) then
								dbms_sql.close_cursor(v_cur);
							end if;
							UPDATE DATA_BROWSER_CHECKS
								SET QUERY_TEXT = v_Stat,
									QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
									QUERY_SQL_CODE = v_Err_Found,
									QUERY_SQL_MESSAGE = SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000)
							WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
							COMMIT;
$END
						end;
						UPDATE DATA_BROWSER_CHECKS
							SET QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
								QUERY_PARSE_TIME = dbms_utility.get_time - v_Timemark
						WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
						COMMIT;
					else
						begin -- open and execute query
							v_Err_Msg := NULL;
							v_Query_Row_Count := 0;
							v_Query_Col_Count := 0;
							SELECT COUNT(*)
							INTO v_Query_Col_Count
							FROM TABLE (
								data_browser_utl.column_value_list (
									p_Query => v_Stat,
									p_Search_Value => view_cur.LINK_ID,
									p_Exact => 'NO'
								)
							);
							if view_cur.REPORT_MODE = 'YES' 
							and p_Load_Data = 'YES'
							and v_Query_Col_Count <= 50 					-- functional limit: maximal 50 columns 
							and DBMS_LOB.GETLENGTH(v_Stat) < 32767 then 	-- functional limit: maximal 32767 bytes
								declare
									e_20104 exception;
									pragma exception_init(e_20104, -20104);
								begin
									APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
										p_collection_name => data_browser_conf.Get_Import_Collection,
										p_query => v_Stat,
										p_truncate_if_exists => 'YES',
										p_max_row_count => 500
									);
								exception
									when e_20104 then null;
								end;

								SELECT COUNT(*) INTO v_Query_Row_Count
								FROM APEX_COLLECTIONS 
								WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Collection;
							else 
								v_Query_Row_Count := 1;
							end if;
$IF data_browser_check.g_use_exceptions $THEN
						exception when others then
							if SQLCODE != -1410 then -- invalid ROWID
								v_Err_Msg := '-- SQL Error :' || SQLCODE || ' ' || SQLERRM || chr(10);
								v_Err_Found := SQLCODE;
								v_Error_Count := v_Error_Count + 1;
								UPDATE DATA_BROWSER_CHECKS
									SET QUERY_TEXT = v_Stat,
										QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
										QUERY_ROW_COUNT = v_Query_Row_Count,
										QUERY_COL_COUNT = v_Query_Col_Count,
										QUERY_SQL_CODE = v_Err_Found,
										QUERY_SQL_MESSAGE = SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000)
								WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
								COMMIT;
							end if;
$END					
						end;
						UPDATE DATA_BROWSER_CHECKS
							SET QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
								QUERY_ROW_COUNT = v_Query_Row_Count,
								QUERY_COL_COUNT = v_Query_Col_Count,
								QUERY_EXECUTE_TIME = dbms_utility.get_time - v_Timemark
						WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
						COMMIT;
					end if;
					data_browser_check.Log_Elapsed_Time (
						p_Timemark => v_Timemark,
						p_Memory => v_Memory,
						p_Logbook => v_Log_Book,
						p_Message => '-- Parse    : ' || NVL(TO_CHAR(v_Query_Col_Count), 'OK') || ' ' || v_Err_Msg);
					if p_Dump_Text = 'YES' or v_Err_Msg IS NOT NULL then
						DBMS_OUTPUT.PUT_LINE(v_Log_Book);
						v_Log_Book := NULL;
						v_Offset := 1;
						for i IN 1 .. (DBMS_LOB.GETLENGTH(v_Stat) / 32767) + 1 loop
							DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_Stat, 32767, v_Offset));
							v_Offset := v_Offset + 32767;
						end loop;
						DBMS_OUTPUT.NEW_LINE;
					end if;
				end if;
			end if;
			---------------------------------------------------------
			if view_cur.VIEW_MODE in ('RECORD_VIEW', 'FORM_VIEW', 'IMPORT_VIEW', 'EXPORT_VIEW')
			and view_cur.ROW_OPERATOR IN ('INSERT', 'UPDATE')
			and view_cur.EMPTY_ROWS = 'NO' and view_cur.EDIT_MODE = 'YES' then
				v_Stat := NULL;
				begin
					v_Err_Msg := NULL;
					v_Stat := data_browser_edit.Validate_Form_Checks_PL_SQL(
						p_Table_name => view_cur.VIEW_NAME,
						p_Key_Column => view_cur.LINK_KEY,
						p_Columns_Limit => view_cur.COLUMNS_LIMIT,
						p_View_Mode => view_cur.VIEW_MODE,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Report_Mode => 'NO',
						p_Parent_Name => view_cur.PARENT_NAME,
						p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Parent_Key_Item => 'P30_PARENT_KEY_ID',
						p_Use_Empty_Columns => 'YES'
					);
					if v_Stat IS NOT NULL then
						v_cur := dbms_sql.open_cursor;
						dbms_sql.parse(v_cur, v_Stat, DBMS_SQL.NATIVE);
						dbms_sql.close_cursor(v_cur);
					end if;
$IF data_browser_check.g_use_exceptions $THEN
				exception when others then
					v_Err_Msg := SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000);
					v_Err_Found := SQLCODE;
					v_Error_Count := v_Error_Count + 1;
					if dbms_sql.is_open(v_cur) then
						dbms_sql.close_cursor(v_cur);
					end if;
					UPDATE DATA_BROWSER_CHECKS
						SET VALIDATION_TEXT = v_Stat,
							VALIDATION_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
							VALIDATION_SQL_CODE = v_Err_Found,
							VALIDATION_SQL_MESSAGE = v_Err_Msg
					WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
					COMMIT;
$END
				end;
				UPDATE DATA_BROWSER_CHECKS
					SET VALIDATION_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
						VALIDATION_PARSE_TIME = dbms_utility.get_time - v_Timemark
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;

				data_browser_check.Log_Elapsed_Time (
					p_Timemark => v_Timemark,
					p_Memory => v_Memory,
					p_Logbook => v_Log_Book,
					p_Message => '-- Validate : ' || DBMS_LOB.GETLENGTH(v_Stat) || ' '  || v_Err_Msg);
				if (p_Dump_Text = 'YES' or v_Err_Msg IS NOT NULL)  and v_Stat IS NOT NULL then
					DBMS_OUTPUT.PUT_LINE(v_Log_Book);
					v_Log_Book := NULL;
					v_Offset := 1;
					for i IN 1 .. (DBMS_LOB.GETLENGTH(v_Stat) / 32767) + 1 loop
						DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_Stat, 32767, v_Offset));
						v_Offset := v_Offset + 32767;
					end loop;
					DBMS_OUTPUT.NEW_LINE;
				end if;
			end if;
			---------------------------------------------------------
			if view_cur.VIEW_MODE IN ('IMPORT_VIEW', 'EXPORT_VIEW')
			and view_cur.ROW_OPERATOR IN ('INSERT', 'UPDATE')
			and view_cur.EMPTY_ROWS = 'NO' and view_cur.EDIT_MODE = 'YES' then
				v_Stat := NULL;
				begin
					v_Err_Msg := NULL;
					v_Stat := data_browser_edit.Get_Form_Foreign_Keys_PLSQL(
						p_Table_Name => view_cur.VIEW_NAME,
						p_Unique_Key_Column => view_cur.LINK_KEY,
						p_Columns_Limit => view_cur.COLUMNS_LIMIT,
						p_View_Mode => view_cur.VIEW_MODE,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Parent_Name => view_cur.PARENT_NAME,
						p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Parent_Key_Item => 'P30_PARENT_KEY_ITEM',
						p_DML_Command => 'UPDATE',
						p_Use_Empty_Columns => 'YES'
					);

					if v_Stat IS NOT NULL then
						v_cur := dbms_sql.open_cursor;
						dbms_sql.parse(v_cur, v_Stat, DBMS_SQL.NATIVE);
						dbms_sql.close_cursor(v_cur);
					end if;

$IF data_browser_check.g_use_exceptions $THEN
				exception when others then
					v_Err_Msg := SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000);
					v_Err_Found := SQLCODE;
					v_Error_Count := v_Error_Count + 1;
					if dbms_sql.is_open(v_cur) then
						dbms_sql.close_cursor(v_cur);
					end if;
					UPDATE DATA_BROWSER_CHECKS
						SET LOOKUP_TEXT = v_Stat,
							LOOKUP_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
							LOOKUP_SQL_CODE = v_Err_Found,
							LOOKUP_SQL_MESSAGE = v_Err_Msg
					WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
					COMMIT;
$END
				end;
				UPDATE DATA_BROWSER_CHECKS
					SET LOOKUP_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
						LOOKUP_PARSE_TIME = dbms_utility.get_time - v_Timemark
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;

				data_browser_check.Log_Elapsed_Time (
					p_Timemark => v_Timemark,
					p_Memory => v_Memory,
					p_Logbook => v_Log_Book,
					p_Message => '-- Lookup FK: ' || DBMS_LOB.GETLENGTH(v_Stat) || ' ' || v_Err_Msg);
				if (p_Dump_Text = 'YES' or v_Err_Msg IS NOT NULL)  and DBMS_LOB.GETLENGTH(v_Stat) > 1 then
					DBMS_OUTPUT.PUT_LINE(v_Log_Book);
					v_Log_Book := NULL;
					v_Offset := 1;
					for i IN 1 .. (DBMS_LOB.GETLENGTH(v_Stat) / 32767) + 1 loop
						DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_Stat, 32767, v_Offset));
						v_Offset := v_Offset + 32767;
					end loop;
					DBMS_OUTPUT.NEW_LINE;
				end if;
			end if;
			---------------------------------------------------------
			if view_cur.EDIT_MODE = 'YES' and view_cur.ROW_OPERATOR IN ('INSERT', 'UPDATE') then
				v_Stat := NULL;
				begin
					v_Err_Msg := NULL;
					v_Stat := data_browser_edit.Get_Form_Edit_DML(
						p_Table_name => view_cur.VIEW_NAME,
						p_Unique_Key_Column => view_cur.LINK_KEY,
						p_Row_Operation => view_cur.ROW_OPERATOR,
						p_Columns_Limit => view_cur.COLUMNS_LIMIT,
						p_View_Mode => view_cur.VIEW_MODE,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Parent_Key_Column => view_cur.PARENT_NAME,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Use_Empty_Columns => 'YES'
					);
					COMMIT;
					if v_Stat IS NOT NULL then
						v_cur := dbms_sql.open_cursor;
						dbms_sql.parse(v_cur, v_Stat, DBMS_SQL.NATIVE);
						dbms_sql.close_cursor(v_cur);
					end if;

$IF data_browser_check.g_use_exceptions $THEN
				exception when others then
					v_Err_Msg := SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000);
					v_Err_Found := SQLCODE;
					v_Error_Count := v_Error_Count + 1;
					if dbms_sql.is_open(v_cur) then
						dbms_sql.close_cursor(v_cur);
					end if;
					UPDATE DATA_BROWSER_CHECKS
						SET DML_TEXT = v_Stat,
							DML_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
							DML_SQL_CODE = v_Err_Found,
							DML_SQL_MESSAGE = v_Err_Msg
					WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
					COMMIT;
$END
				end;
				UPDATE DATA_BROWSER_CHECKS
					SET DML_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
						DML_PARSE_TIME = dbms_utility.get_time - v_Timemark,
						DML_ROW_COUNT = v_Rows_Updated
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;

				data_browser_check.Log_Elapsed_Time (
					p_Timemark => v_Timemark,
					p_Memory => v_Memory,
					p_Logbook => v_Log_Book,
					p_Message => '-- '
								|| view_cur.ROW_OPERATOR
								|| '   : ' || DBMS_LOB.GETLENGTH(v_Stat) || ' '  || v_Err_Msg);
				if (p_Dump_Text = 'YES' or v_Err_Msg IS NOT NULL)  and v_Stat IS NOT NULL then
					DBMS_OUTPUT.PUT_LINE(v_Log_Book);
					v_Log_Book := NULL;
					v_Offset := 1;
					for i IN 1 .. (DBMS_LOB.GETLENGTH(v_Stat) / 32767) + 1 loop
						DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_Stat, 32767, v_Offset));
						v_Offset := v_Offset + 32767;
					end loop;
					DBMS_OUTPUT.NEW_LINE;
				end if;
			end if;
			---------------------------------------------------------
			if view_cur.EDIT_MODE = 'YES'
			and view_cur.ROW_OPERATOR IN ('DELETE', 'DUPLICATE', 'MOVE_ROWS', 'COPY_ROWS', 'MERGE_ROWS')
			-- and view_cur.PARENT_NAME IS NOT NULL 
			then
				v_Stat := NULL;
				begin
					v_Err_Msg := NULL;
					v_Stat := data_browser_edit.Get_Form_Edit_DML(
						p_Table_name => view_cur.VIEW_NAME,
						p_Unique_Key_Column => view_cur.LINK_KEY,
						p_Row_Operation => view_cur.ROW_OPERATOR,
						p_View_Mode => view_cur.VIEW_MODE,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Columns_Limit => view_cur.COLUMNS_LIMIT,
						p_Parent_Name => view_cur.PARENT_NAME,
						p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Parent_Key_Item => 'P30_PARENT_KEY_ITEM',
						p_Use_Empty_Columns => 'YES'
					);
					if v_Stat IS NOT NULL then
						v_cur := dbms_sql.open_cursor;
						dbms_sql.parse(v_cur, v_Stat, DBMS_SQL.NATIVE);
						dbms_sql.close_cursor(v_cur);
					end if;
$IF data_browser_check.g_use_exceptions $THEN
				exception when others then
					v_Err_Msg := SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000);
					v_Err_Found := SQLCODE;
					v_Error_Count := v_Error_Count + 1;
					if dbms_sql.is_open(v_cur) then
						dbms_sql.close_cursor(v_cur);
					end if;
					UPDATE DATA_BROWSER_CHECKS
						SET DML_TEXT = v_Stat,
							DML_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
							DML_SQL_CODE = v_Err_Found,
							DML_SQL_MESSAGE = v_Err_Msg
					WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
					COMMIT;
$END
				end;
				UPDATE DATA_BROWSER_CHECKS
					SET DML_LENGTH = DBMS_LOB.GETLENGTH(v_Stat),
						DML_PARSE_TIME = dbms_utility.get_time - v_Timemark
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;

				data_browser_check.Log_Elapsed_Time (
					p_Timemark => v_Timemark,
					p_Memory => v_Memory,
					p_Logbook => v_Log_Book,
					p_Message => '-- ' || view_cur.ROW_OPERATOR || '   : ' || DBMS_LOB.GETLENGTH(v_Stat) || ' '  || v_Err_Msg);
				if (p_Dump_Text = 'YES' or v_Err_Msg IS NOT NULL) and v_Stat IS NOT NULL then
					DBMS_OUTPUT.PUT_LINE(v_Log_Book);
					v_Log_Book := NULL;
					v_Offset := 1;
					for i IN 1 .. (DBMS_LOB.GETLENGTH(v_Stat) / 32767) + 1 loop
						DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_Stat, 32767, v_Offset));
						v_Offset := v_Offset + 32767;
					end loop;
					DBMS_OUTPUT.NEW_LINE;
				end if;
			end if;
			---------------------------------------------------------
			UPDATE DATA_BROWSER_CHECKS
				SET ELAPSED_TIME = dbms_utility.get_time - v_Loop_TM,
				CHECKED = 'Y'
			WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
			COMMIT;
			v_Loop_Dur := dbms_utility.get_time - v_Loop_TM;
			if v_Err_Found != 0
			or v_Loop_Dur > 300
			or p_Show_Loops = 'YES'
			then
				DBMS_OUTPUT.PUT_LINE(v_Log_Book);
			end if;
			EXIT WHEN v_Error_Count >= p_Max_Errors;
			EXIT WHEN v_Count >= p_Max_Loops;
		END LOOP;
		v_Log_Book := NULL;
		data_browser_check.Log_Elapsed_Time (
			p_Timemark => v_Start_TM,
			p_Memory => v_Memory,
			p_Logbook => v_Log_Book,
			p_Message => '-- finished ' || v_Count || ' loops with ' || v_Error_Count || ' errors.',
			p_Access_Memory => 'YES'
		);
		apex_session.delete_session;
		DBMS_OUTPUT.PUT_LINE(v_Log_Book);
        Set_Process_Infos(v_rindex, v_slno, g_Test_Query_Gen_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
        data_browser_check.Set_Cursor_Sharing(p_Modus => 'EXACT');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, g_Test_Query_Gen_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
	end Test_Query_Generator;

	PROCEDURE Test_Import_Generator (
		p_Table_name IN VARCHAR2 DEFAULT '%',
		p_Dump_Text IN VARCHAR2 DEFAULT 'NO',
		p_Show_Loops IN VARCHAR2 DEFAULT 'NO',
		p_Max_Errors IN INTEGER DEFAULT 1000,
		p_Max_Loops IN INTEGER DEFAULT NULL,
		p_app_id IN INTEGER DEFAULT NVL(NV('APP_ID'), 2000),
		p_page_id IN INTEGER DEFAULT 30,
		p_username IN VARCHAR2 DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')),
		p_Schema   IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	)
	IS
		v_Query_Stat CLOB;
		v_DML_Stat CLOB;
		v_Lookup_Stat CLOB;
		v_Validation_Stat CLOB;
    	v_Offset INTEGER;
        v_Row_Count PLS_INTEGER := 1;
        v_Log_Book VARCHAR2(32767);
		v_Timemark NUMBER := dbms_utility.get_time;
		v_Count PLS_INTEGER := 0;
		v_Start_TM NUMBER;
		v_Loop_TM NUMBER;
		v_Loop_Dur NUMBER;
		v_Memory number := data_browser_check.Get_Stat('session pga memory');
		v_Err_Msg VARCHAR2(2048);
		v_Validation_Msg1 VARCHAR2(32767);
		v_Validation_Msg2 VARCHAR2(32767);
		v_Success_Msg1 VARCHAR2(2048);
		v_Success_Msg2 VARCHAR2(2048);
		v_Success_Msg3 VARCHAR2(2048);
		v_Unique_Key_Value VARCHAR2(2048);
		v_Err_Found NUMBER;
		v_Error_Count PLS_INTEGER := 0;
		v_cur INTEGER;
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Steps  		binary_integer;
        v_Rows_Imported_Count number;
        v_Rows_Affected number;
	begin
		v_Timemark := dbms_utility.get_time;
		v_Start_TM := v_Timemark;
		v_Count := 0;
		apex_session.create_session ( 
			p_app_id => p_app_id,
			p_page_id => p_page_id,
			p_username => p_username
		);
		APEX_UTIL.SET_SESSION_STATE('P30_PARENT_KEY_ID', '1');
		APEX_UTIL.SET_SESSION_STATE('P30_SEARCH', '');
		APEX_UTIL.SET_SESSION_STATE('APP_PARSING_SCHEMA', p_Schema);
		data_browser_check.Set_Cursor_Sharing(p_Modus => 'FORCE');
		select count(*) into v_Steps
		from DATA_BROWSER_CHECKS
			where (VIEW_NAME LIKE p_Table_name OR p_Table_name IS NULL)
			and (CHECKED_IMPORT = 'N')
			and VIEW_MODE = 'IMPORT_VIEW' 
			and REPORT_MODE = 'YES'
			and ROW_OPERATOR = 'UPDATE' 
			and DATA_SOURCE = 'COLLECTION' 
			and DATA_FORMAT = 'FORM'
			and EMPTY_ROWS = 'NO' 
			and EDIT_MODE = 'YES' 
			and PARENT_KEY_VISIBLE = 'YES'
			and SEARCH_TEXT = 'NO'
			and VIEW_NAME != 'DATA_BROWSER_CHECKS';
			
		v_Steps := case when v_Steps > p_Max_Loops then p_Max_Loops else v_Steps end;
		for view_cur IN (
			select distinct SEQUENCE_ID, VIEW_NAME, LINK_KEY, ORDER_BY, LINK_ID, VIEW_MODE,
				PARENT_NAME, PARENT_KEY_COLUMN, REPORT_MODE, EDIT_MODE, 
				ROW_OPERATOR, DATA_SOURCE, EMPTY_ROWS, JOIN_OPTIONS,
				COLUMNS_LIMIT, PARENT_KEY_VISIBLE, CALC_SUBTOTALS,
				IMP_COMPARE_CASE_INSENSITIVE, IMP_SEARCH_KEYS_UNIQUE, IMP_INSERT_FOREIGN_KEYS
			from DATA_BROWSER_CHECKS
			where (VIEW_NAME LIKE p_Table_name OR p_Table_name IS NULL)
			and (CHECKED_IMPORT = 'N')
			and VIEW_MODE = 'IMPORT_VIEW' 
			and REPORT_MODE = 'YES'
			and ROW_OPERATOR = 'UPDATE' 
			and DATA_SOURCE = 'COLLECTION' 
			and DATA_FORMAT = 'FORM'
			and EMPTY_ROWS = 'NO' 
			and EDIT_MODE = 'YES' 
			and PARENT_KEY_VISIBLE = 'YES'
			and SEARCH_TEXT = 'NO'
			and VIEW_NAME != 'DATA_BROWSER_CHECKS'
			and NESTED_LINKS = 'NO'
			and CALC_SUBTOTALS = 'NO'
			and LINK_ID IS NULL
			order by VIEW_NAME, VIEW_MODE, REPORT_MODE, EDIT_MODE, JOIN_OPTIONS
		)
		LOOP
        	Set_Process_Infos(v_rindex, v_slno, g_Test_Import_Gen_Proc_Name, p_context, v_Steps, v_Count, 'steps');
			v_Count := v_Count +  1;
			v_Loop_TM := dbms_utility.get_time;
			v_Query_Stat := NULL;
			v_DML_Stat := NULL;
			v_Lookup_Stat := NULL;
			v_Validation_Stat := NULL;
			v_Log_Book := NULL;
			v_Err_Msg := NULL;
			v_Err_Found := 0;
			data_browser_check.Log_Elapsed_Time (
				p_Timemark => v_Timemark,
				p_Memory => v_Memory,
				p_Logbook => v_Log_Book,
				p_Message =>
					RPAD('-', 70, '-')
					|| chr(10)
					|| '-- '
					|| v_Count
					|| '. (#' || view_cur.SEQUENCE_ID
					|| ') -- View=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.VIEW_NAME)
					|| ', View_Mode=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.VIEW_MODE)
					|| ', Join_Options=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.JOIN_OPTIONS)
					|| ', Parent_Name=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.PARENT_NAME)
					|| ', Parent_Key_Column=> ' || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.PARENT_KEY_COLUMN)
					|| ', Link_Key=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.LINK_KEY)
					|| ', Order_by=> '  || DBMS_ASSERT.ENQUOTE_LITERAL(view_cur.ORDER_BY)
			);
			---------------------------------------------------------
			begin
				data_browser_edit.Reset_Import_Description;
				data_browser_conf.Set_Import_Parameter (
					p_Compare_Case_Insensitive	=> view_cur.IMP_COMPARE_CASE_INSENSITIVE,
					p_Search_Keys_Unique 	=> view_cur.IMP_SEARCH_KEYS_UNIQUE,
					p_Insert_Foreign_Keys 	=> view_cur.IMP_INSERT_FOREIGN_KEYS
				);
				data_browser_conf.Set_Include_Query_Schema('YES');
				v_Err_Msg := NULL;
				-- build query for apex collection
				v_Query_Stat := data_browser_utl.Get_Record_View_Query(
					p_Table_name => view_cur.VIEW_NAME,
					p_Unique_Key_Column => view_cur.LINK_KEY,
					p_Search_Value => NULL,
					p_Data_Columns_Only => 'YES',
					p_Columns_Limit => view_cur.COLUMNS_LIMIT,
					p_Compact_Queries => 'YES',
					p_View_Mode => 'IMPORT_VIEW',
					p_Report_Mode => 'YES',
					p_Edit_Mode => 'NO',
					p_Data_Source => 'TABLE',
					p_Data_Format => 'CSV',
					p_Empty_Row => 'NO',
					p_Join_Options => view_cur.JOIN_OPTIONS,
					p_Parent_Table => view_cur.PARENT_NAME,
					p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
					p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
					p_Parent_Key_Item => 'P30_PARENT_KEY_ID',
					p_Order_by => view_cur.ORDER_BY,
					p_Order_Direction => 'ASC NULLS LAST'
				);
				DBMS_OUTPUT.PUT_LINE('Get_Record_View_Query: '||v_Query_Stat);

				declare
					e_20104 exception;
					pragma exception_init(e_20104, -20104);
				begin
					APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
						p_collection_name => data_browser_conf.Get_Import_Collection,
						p_query => v_Query_Stat,
						p_truncate_if_exists => 'YES',
						p_max_row_count => 500
					);
				exception
					when e_20104 then null;
				end;
				SELECT COUNT(*) INTO v_Rows_Imported_Count
				FROM APEX_COLLECTIONS 
				WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Collection;
				apex_application.g_print_success_message := NULL;
				DBMS_OUTPUT.PUT_LINE('Rows_Imported_Count: '||v_Rows_Imported_Count);
				data_browser_edit.Validate_Imported_Data(
					p_Table_name => view_cur.VIEW_NAME,
					p_Key_Column => view_cur.LINK_KEY,
					p_Columns_Limit => view_cur.COLUMNS_LIMIT,
					p_View_Mode => view_cur.VIEW_MODE,
					p_Join_Options => view_cur.JOIN_OPTIONS,
					p_Parent_Name => view_cur.PARENT_NAME,
					p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
					p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
					p_Rows_Imported_Count => v_Rows_Imported_Count
				);
				v_Success_Msg1 := apex_application.g_print_success_message;
				apex_application.g_print_success_message := NULL;
				if p_Dump_Text = 'YES' then
					DBMS_OUTPUT.PUT_LINE('Validate_Imported_Data: '||v_Success_Msg1);
				end if;
				v_Validation_Msg1 := data_browser_edit.Validate_Form_Foreign_Keys(
					p_Table_name => view_cur.VIEW_NAME,
					p_Unique_Key_Column => view_cur.LINK_KEY,
					p_Columns_Limit => view_cur.COLUMNS_LIMIT,
					p_View_Mode =>  view_cur.VIEW_MODE,
					p_Join_Options => view_cur.JOIN_OPTIONS,
					p_Data_Source => view_cur.DATA_SOURCE,
					p_Parent_Name => view_cur.PARENT_NAME,
					p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
					p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
					p_Parent_Key_Item => 'P30_PARENT_KEY_ITEM',
					p_DML_Command => 'UPDATE',
					p_Use_Empty_Columns => 'YES'
				);
				if INSTR(v_Validation_Msg1, 'ORA-') = 1 then 
					v_Lookup_Stat := data_browser_edit.Get_Form_Foreign_Keys_PLSQL(
						p_Table_Name => view_cur.VIEW_NAME,
						p_Unique_Key_Column => view_cur.LINK_KEY,
						p_Columns_Limit => view_cur.COLUMNS_LIMIT,
						p_View_Mode => view_cur.VIEW_MODE,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Parent_Name => view_cur.PARENT_NAME,
						p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Parent_Key_Item => 'P30_PARENT_KEY_ITEM',
						p_DML_Command => 'UPDATE',
						p_Use_Empty_Columns => 'YES'
					);

				end if;
				if p_Dump_Text = 'YES' then
					DBMS_OUTPUT.PUT_LINE('Validate_Form_Foreign_Keys: '||v_Validation_Msg1);
				end if;
				v_Validation_Msg2 := data_browser_edit.Validate_Form_Checks(
					p_Table_name => view_cur.VIEW_NAME,
					p_Key_Column => view_cur.LINK_KEY,
					p_Key_Value => NULL,
					p_Columns_Limit => view_cur.COLUMNS_LIMIT,
					p_View_Mode => view_cur.VIEW_MODE,
					p_Data_Source => view_cur.DATA_SOURCE,
					p_Report_Mode => 'YES',
					p_Join_Options => view_cur.JOIN_OPTIONS,
					p_Parent_Name => view_cur.PARENT_NAME,
					p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
					p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
					p_Use_Empty_Columns => 'YES'
				);
				if INSTR(v_Validation_Msg2, 'ORA-') = 1 
				or INSTR(v_Success_Msg1, 'validation error') > 0 then 
					v_Validation_Stat := data_browser_edit.Validate_Form_Checks_PL_SQL(
						p_Table_name => view_cur.VIEW_NAME,
						p_Key_Column => view_cur.LINK_KEY,
						p_Columns_Limit => view_cur.COLUMNS_LIMIT,
						p_View_Mode => view_cur.VIEW_MODE,
						p_Join_Options => view_cur.JOIN_OPTIONS,
						p_Data_Source => view_cur.DATA_SOURCE,
						p_Report_Mode => 'YES',
						p_Parent_Name => view_cur.PARENT_NAME,
						p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
						p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
						p_Parent_Key_Item => 'P30_PARENT_KEY_ID',
						p_Use_Empty_Columns => 'YES'
					);
				end if;
				COMMIT;
				if p_Dump_Text = 'YES' then
					DBMS_OUTPUT.PUT_LINE('Validate_Form_Checks: '||v_Validation_Msg2);
				end if;
				v_DML_Stat := data_browser_edit.Get_Copy_Rows_DML(
					p_View_name => view_cur.VIEW_NAME,
					p_Unique_Key_Column => view_cur.LINK_KEY,
					p_Row_Operation => 'MERGE_ROWS',
					p_Join_Options => view_cur.JOIN_OPTIONS,
					p_Columns_Limit => view_cur.COLUMNS_LIMIT,
					p_View_Mode => view_cur.VIEW_MODE,
					p_Data_Source => 'COLLECTION',
					p_Report_Mode => 'YES',
					p_Parent_Name => view_cur.PARENT_NAME,
					p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
					p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
					p_Parent_Key_Item => 'P30_PARENT_KEY_ID'
				);
				if p_Dump_Text = 'YES' then
					DBMS_OUTPUT.PUT_LINE('Get_Copy_Rows_DML: '||v_DML_Stat);
				end if;
				apex_application.g_print_success_message := NULL;
				v_Unique_Key_Value := NULL;
				v_Success_Msg3 := NULL;
				data_browser_edit.Process_Form_DML (
					p_Table_name => view_cur.VIEW_NAME,
					p_Unique_Key_Column => view_cur.LINK_KEY,
					p_Unique_Key_Value => v_Unique_Key_Value,
					p_Error_Message => v_Success_Msg3,
					p_Rows_Affected => v_Rows_Affected,
					p_New_Row => 'YES',
					p_Columns_Limit => view_cur.COLUMNS_LIMIT,
					p_View_Mode =>  view_cur.VIEW_MODE,
					p_Data_Source => view_cur.DATA_SOURCE,
					p_Report_Mode => 'YES',
					p_Join_Options => view_cur.JOIN_OPTIONS,
					p_Parent_Name => view_cur.PARENT_NAME,
					p_Parent_Key_Column => view_cur.PARENT_KEY_COLUMN,
					p_Parent_Key_Visible => view_cur.PARENT_KEY_VISIBLE,
					p_Parent_Key_Item => 'P30_PARENT_KEY_ID',
					p_Request => 'PROCESS_IMPORT_INFOS',
					p_Last_Row => 10
				);
				v_Success_Msg2 := COALESCE(v_Success_Msg3, apex_application.g_print_success_message, 'PROCESS_IMPORT returned empty.');
				if p_Dump_Text = 'YES' then
					DBMS_OUTPUT.PUT_LINE('Process_Form_DML: '||v_Success_Msg2||', Rows_Affected: '||v_Rows_Affected);
				end if;
				apex_application.g_print_success_message := NULL;
				v_Err_Found := 0;
				UPDATE DATA_BROWSER_CHECKS
					SET VALIDATION_TEXT = v_Validation_Stat,
						VALIDATION_LENGTH = DBMS_LOB.GETLENGTH(v_Validation_Stat),
						VALIDATION_ROW_COUNT = v_Rows_Imported_Count,
						VALIDATION_SQL_CODE = case when INSTR(v_Validation_Msg2, 'ORA-') = 1 then -1001 
												when INSTR(v_Success_Msg1, 'validation error') > 0 then -1002
											end,
						VALIDATION_SQL_MESSAGE = SUBSTRB(v_Validation_Msg2, 1, 1000),
						LOOKUP_TEXT = v_Lookup_Stat,
						LOOKUP_LENGTH = DBMS_LOB.GETLENGTH(v_Lookup_Stat),
						LOOKUP_SQL_MESSAGE = SUBSTRB(v_Validation_Msg1, 1, 1000),
						LOOKUP_SQL_CODE = case when INSTR(v_Validation_Msg1, 'ORA-') = 1 then -1001 
												when INSTR(v_Validation_Msg1, 'Error') > 0 then -1002 end,
						QUERY_TEXT = v_Query_Stat,
						QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Query_Stat),
						QUERY_SQL_MESSAGE = SUBSTRB(v_Success_Msg1, 1, 1000),
						DML_TEXT = v_DML_Stat,
						DML_LENGTH = DBMS_LOB.GETLENGTH(v_DML_Stat),
						DML_SQL_MESSAGE = SUBSTRB(v_Success_Msg2, 1, 1000),
						DML_ROW_COUNT = v_Rows_Affected,
						VALIDATION_PARSE_TIME = dbms_utility.get_time - v_Timemark
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;
$IF data_browser_check.g_use_exceptions $THEN
			exception when others then
				v_Err_Msg := SUBSTRB(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 1000);
				v_Err_Found := SQLCODE;
				v_Error_Count := v_Error_Count + 1;
				UPDATE DATA_BROWSER_CHECKS
					SET 
						QUERY_TEXT = v_Query_Stat,
						QUERY_LENGTH = DBMS_LOB.GETLENGTH(v_Query_Stat),
						QUERY_SQL_MESSAGE = SUBSTRB(v_Success_Msg1, 1, 1000),
						DML_TEXT = v_DML_Stat,
						DML_LENGTH = DBMS_LOB.GETLENGTH(v_DML_Stat),
						DML_SQL_MESSAGE = v_Err_Msg,
						DML_SQL_CODE = v_Err_Found,
						DML_ROW_COUNT = v_Rows_Affected,
						VALIDATION_PARSE_TIME = dbms_utility.get_time - v_Timemark
				WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
				COMMIT;
$END
			end;
			data_browser_check.Log_Elapsed_Time (
				p_Timemark => v_Timemark,
				p_Memory => v_Memory,
				p_Logbook => v_Log_Book,
				p_Message => '-- Validate_Imported_Data : ' || DBMS_LOB.GETLENGTH(v_DML_Stat) || ' '  || v_Err_Msg);
			if (p_Dump_Text = 'YES' or v_Err_Msg IS NOT NULL)  and v_DML_Stat IS NOT NULL then
				DBMS_OUTPUT.PUT_LINE(v_Log_Book);
				v_Log_Book := NULL;
				v_Offset := 1;
				for i IN 1 .. (DBMS_LOB.GETLENGTH(v_DML_Stat) / 32767) + 1 loop
					DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_DML_Stat, 32767, v_Offset));
					v_Offset := v_Offset + 32767;
				end loop;
				DBMS_OUTPUT.NEW_LINE;
			end if;
			---------------------------------------------------------
			UPDATE DATA_BROWSER_CHECKS
				SET ELAPSED_TIME = dbms_utility.get_time - v_Loop_TM,
				CHECKED_IMPORT = 'Y'
			WHERE SEQUENCE_ID = view_cur.SEQUENCE_ID;
			COMMIT;
			v_Loop_Dur := dbms_utility.get_time - v_Loop_TM;
			if v_Err_Found != 0
			or v_Loop_Dur > 3000
			or p_Show_Loops = 'YES'
			then
				DBMS_OUTPUT.PUT_LINE(v_Log_Book);
			end if;
			EXIT WHEN v_Error_Count >= p_Max_Errors;
			EXIT WHEN v_Count >= p_Max_Loops;
		END LOOP;
		v_Log_Book := NULL;
		data_browser_check.Log_Elapsed_Time (
			p_Timemark => v_Start_TM,
			p_Memory => v_Memory,
			p_Logbook => v_Log_Book,
			p_Message => '-- finished ' || v_Count || ' loops with ' || v_Error_Count || ' errors.',
			p_Access_Memory => 'YES'
		);
		apex_session.delete_session;
		DBMS_OUTPUT.PUT_LINE(v_Log_Book);
        Set_Process_Infos(v_rindex, v_slno, g_Test_Import_Gen_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
        data_browser_check.Set_Cursor_Sharing(p_Modus => 'EXACT');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, g_Test_Import_Gen_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
	end Test_Import_Generator;

	PROCEDURE Load_Job (
		p_Job_Name VARCHAR2,
		p_Comment VARCHAR2,
		p_Sql VARCHAR2,
		p_Enabled VARCHAR2 DEFAULT 'YES',
		p_Repeat_Interval VARCHAR2 DEFAULT NULL
	)
	IS
		v_Job_Name USER_SCHEDULER_JOBS.JOB_NAME%TYPE;
		v_Job_STATE USER_SCHEDULER_JOBS.STATE%TYPE;
		v_Job_Name_Prefix USER_SCHEDULER_JOBS.JOB_NAME%TYPE := SUBSTR(data_browser_jobs.Get_Job_Name_Prefix || p_Job_Name, 1, 18);
	BEGIN
		begin
			SELECT JOB_NAME, STATE
			INTO v_Job_Name, v_Job_STATE
			FROM USER_SCHEDULER_JOBS
			WHERE JOB_NAME LIKE v_Job_Name_Prefix || '%'
			AND STATE IN ('SCHEDULED', 'RETRY SCHEDULED', 'RUNNING');
			DBMS_OUTPUT.PUT_LINE('Job - found ' || v_Job_Name_Prefix );
			if p_Enabled = 'NO' then
				if v_Job_STATE = 'RUNNING' then 
					dbms_scheduler.stop_job ( job_name => v_Job_Name );
				end if;
				dbms_scheduler.drop_job (
					job_name => v_Job_Name,
					force => TRUE
				);
				commit;
				DBMS_OUTPUT.PUT_LINE('Job - stopped ' || v_Job_Name );
			end if;
			APEX_UTIL.PAUSE(1/10);
		exception
		  when NO_DATA_FOUND then
			v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
		  when others then
			if SQLCODE = -27475 then -- unknown job
				v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
			else 
				raise;
			end if;
		end;
		if p_Enabled = 'YES' then
			DBMS_OUTPUT.PUT_LINE('data_browser_check.Load_Job - start ' || v_Job_Name || '; sql: ' || p_Sql);
			dbms_scheduler.create_job(
				job_name => v_Job_Name,
				job_type => 'PLSQL_BLOCK',
				job_action => p_Sql,
				start_date => SYSDATE,
				end_date => SYSDATE + 1/24*8, -- 8 hours
				repeat_interval => p_Repeat_Interval,
				comments => p_Comment,
				enabled => true );
			COMMIT;
			APEX_UTIL.PAUSE(1/4);
		end if;
	END Load_Job;

    PROCEDURE Load_Query_Generator_Job(
		p_Enabled VARCHAR2 DEFAULT 'YES',
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	)
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		v_sql   := 'begin data_browser_check.Load_Query_Generator('
			|| 'p_context=>' || DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
			|| '); end;';
		data_browser_check.Load_Job(
			p_Job_Name => 'LOAD_QUERY_GEN',
			p_Comment => g_Load_Query_Gen_Proc_Name,
			p_Sql => v_sql,
			p_Enabled => p_Enabled
		);
	END Load_Query_Generator_Job;

    PROCEDURE Test_Query_Generator_Job(
		p_Enabled VARCHAR2 DEFAULT 'YES',
		p_app_id IN INTEGER DEFAULT NVL(NV('APP_ID'), 2000),
    	p_context  IN  binary_integer DEFAULT FN_Scheduler_Context
	)
	IS
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		v_sql   := 'begin data_browser_check.Test_Query_Generator(p_Max_Errors => 1000, p_Max_Loops => 5000'
			|| ',p_Execute_Queries=>' || DBMS_ASSERT.ENQUOTE_LITERAL('NO')
			|| ',p_context=>' || DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
			|| ',p_app_id=>' || p_app_id
			|| '); end;';
		data_browser_check.Load_Job(
			p_Job_Name => 'TEST_QUERY_GEN',
			p_Comment => g_Test_Query_Gen_Proc_Name,
			p_Sql => v_sql,
			p_Enabled => p_Enabled,
			p_Repeat_Interval => 'SYSDATE + 1/24/60/2' -- every 1/2 Minutes
		);
		v_sql  := 'begin data_browser_check.Test_Import_Generator(p_Max_Errors => 1000, p_Max_Loops => 5000'
			|| ',p_context=>' || DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
			|| ',p_app_id=>' || p_app_id
			|| '); end;';
		data_browser_check.Load_Job(
			p_Job_Name => 'TEST_IMPORT_GEN',
			p_Comment => g_Test_Import_Gen_Proc_Name,
			p_Sql => v_sql,
			p_Enabled => p_Enabled
		);
	END Test_Query_Generator_Job;

end data_browser_check;
/
show errors

/*
@data_browser_check.sql

set serveroutput on size unlimited
set long 2000000
set pagesize 0
set linesize 32767

exec data_browser_check.Delete_Query_Checks;
exec data_browser_check.Load_Query_Generator;

exec data_browser_check.Load_Query_Generator(p_Table_name => 'EBA_CUST_CUSTOMERS');
exec data_browser_check.Test_Query_Generator_Job(p_Enabled=>'NO');
exec data_browser_check.Test_Query_Generator_Job(p_Enabled=>'YES', p_app_id => 2000);
select * from USER_SCHEDULER_JOB_RUN_DETAILS order by LOG_DATE DESC;

-- as dba : GRANT ALTER SESSION TO OWNER;
ALTER SESSION SET TIMED_STATISTICS = TRUE;
exec dbms_session.set_sql_trace (true);
exec dbms_profiler.start_profiler(run_comment1=>'TEST4');
set serveroutput on size unlimited

declare 
	v_View_Name VARCHAR2(128) := 'EBA%';
begin
	data_browser_check.Test_Query_Generator(p_Table_name => v_View_Name, p_Dump_Text => 'NO',
		p_Load_Data => 'NO', p_Execute_Queries => 'NO',
		p_Show_Loops => 'NO', p_Max_Errors => 20, p_Max_Loops => 10000);
end;
/

begin
	data_browser_check.Test_Import_Generator(p_Table_name => null, p_Dump_Text => 'NO',
		p_Show_Loops => 'NO', p_Max_Errors => 1, p_Max_Loops => 2);
end;
/

exec dbms_session.set_sql_trace (false);
exec dbms_profiler.stop_profiler;

-------

select sum(QUERY_GENERATION_TIME) sum_query_generation_time,
    round(avg(QUERY_GENERATION_TIME), 3) avg_query_generation_time,
    min(QUERY_GENERATION_TIME) min_query_generation_time,
    max(QUERY_GENERATION_TIME) max_query_generation_time,
    count(*) cnt,
    DATA_SOURCE
from DATA_BROWSER_CHECKS
where CHECKED = 'Y'
and QUERY_GENERATION_TIME > 0
group by DATA_SOURCE
order by 2 desc;

select sum(case when CHECKED = 'Y' then 1 else 0 end) checked,
    sum(case when CHECKED = 'N' then 1 else 0 end) pending,
    sum(case when CHECKED_IMPORT = 'Y' then 1 else 0 end) checked_import,
    sum(ELAPSED_TIME) elapsed_time,
    sum(case when NVL(QUERY_SQL_CODE,0) = 0 then 0 else 1 end) query_sql_errors,
    sum(QUERY_GENERATION_TIME) sum_query_generation_time,
    round(avg(QUERY_GENERATION_TIME), 3) avg_query_generation_time,
    min(QUERY_GENERATION_TIME) min_query_generation_time,
    max(QUERY_GENERATION_TIME) max_query_generation_time,
    sum(QUERY_PARSE_TIME) query_parse_time,
    sum(QUERY_EXECUTE_TIME) query_execute_time,
    count(QUERY_ROW_COUNT) query_row_count,
    count(QUERY_COL_COUNT) query_col_count,
    sum(case when NVL(VALIDATION_SQL_CODE,0) = 0 then 0 else 1 end) validation_sql_errors,
    sum(VALIDATION_PARSE_TIME) validation_parse_time,
    count(VALIDATION_ROW_COUNT) validation_row_count,
    sum(case when NVL(LOOKUP_SQL_CODE,0) = 0 then 0 else 1 end) lookup_sql_errors,
    sum(LOOKUP_PARSE_TIME) lookup_parse_time,
    sum(case when NVL(DML_SQL_CODE,0) = 0 then 0 else 1 end) dml_sql_errors,
    sum(DML_PARSE_TIME) DML_PARSE_TIME,
    count(DML_ROW_COUNT) dml_row_count,
    sum(case when DML_ROW_COUNT > 0 then 1 else 0 end) dml_rows_affected
from DATA_BROWSER_CHECKS;

select * from DATA_BROWSER_CHECKS
where checked = 'Y'
and coalesce(QUERY_SQL_CODE,VALIDATION_SQL_CODE,LOOKUP_SQL_CODE,DML_SQL_CODE) IS NOT NULL
order by VIEW_NAME;

select VIEW_NAME, VIEW_MODE, REPORT_MODE, EDIT_MODE, ROW_OPERATOR, PARENT_KEY_VISIBLE, 
    -- ELAPSED_TIME, QUERY_GENERATION_TIME, VALIDATION_PARSE_TIME, LOOKUP_PARSE_TIME, DML_PARSE_TIME,
    SUBSTR(COALESCE(VALIDATION_SQL_MESSAGE, LOOKUP_SQL_MESSAGE, QUERY_SQL_MESSAGE), 1, 150) MESSAGE, QUERY_TEXT
from DATA_BROWSER_CHECKS
where CHECKED_IMPORT = 'Y'
and (LOOKUP_SQL_MESSAGE IS NOT NULL or VALIDATION_SQL_MESSAGE  IS NOT NULL or INSTR(QUERY_SQL_MESSAGE, 'errors') > 0)
order by VIEW_NAME;

exec data_browser_check.Clear_Query_Generator;
begin
	data_browser_check.Test_Query_Generator(p_Table_name => '%', p_Dump_Text => 'NO',
		p_Show_Loops => 'NO', p_Max_Errors => 1, p_Max_Loops => 500, p_app_id => 2000);
end;
/
begin
	data_browser_check.Test_Query_Generator(p_Table_name => '%', p_Dump_Text => 'NO',
		p_Show_Loops => 'NO', p_Max_Errors => 50, p_Max_Loops => 1000);
end;
/
begin
	data_browser_check.Test_Import_Generator(p_Table_name => '%', p_Dump_Text => 'NO',
		p_Show_Loops => 'YES', p_Max_Errors => 50, p_Max_Loops => 500, p_app_id => 2000);
end;
/

select VIEW_NAME, DML_ROW_COUNT, VALIDATION_ROW_COUNT, VALIDATION_TEXT, VALIDATION_SQL_CODE, VALIDATION_SQL_MESSAGE, LOOKUP_SQL_MESSAGE,
    QUERY_SQL_MESSAGE,  DML_SQL_MESSAGE, VALIDATION_PARSE_TIME, QUERY_TEXT
from DATA_BROWSER_CHECKS
where CHECKED_IMPORT = 'Y';

*/
