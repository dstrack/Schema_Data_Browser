BEGIN
	EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MVCHANGELOG_REFERENCES';
EXCEPTION
  WHEN OTHERS THEN
	IF SQLCODE != -12003 THEN
		RAISE;
	END IF;
END;
/

CREATE MATERIALIZED VIEW MVCHANGELOG_REFERENCES (S_TABLE_NAME, S_COLUMN_NAME, T_TABLE_NAME, T_COLUMN_NAME, T_CHANGELOG_NAME, CONSTRAINT_TYPE, DELETE_RULE)
    BUILD DEFERRED
    REFRESH COMPLETE
    ON DEMAND
AS
-- used in packages custom_changelog_gen
-- Calculate additional parameter for custom_changelog.AddLog. The mapping of table columns
-- to parameter names of a direct reference column for the function call to custom_changelog.AddLog is calculated
SELECT S_TABLE_NAME, S_COLUMN_NAME, T_TABLE_NAME, T_COLUMN_NAME, T_CHANGELOG_NAME, CONSTRAINT_TYPE, DELETE_RULE
FROM table (changelog_conf.FN_Pipe_Changelog_References)
;

ALTER  TABLE MVCHANGELOG_REFERENCES ADD
 CONSTRAINT MVCHANGELOG_REFERENCES_UK UNIQUE (S_TABLE_NAME, S_COLUMN_NAME) USING INDEX COMPRESS 1;


CREATE OR REPLACE VIEW VCHANGE_LOG_FIELDS (
	ID, LOGGING_TIMESTAMP, LOGGING_DATE,
	USER_NAME, USER_NAME_INITCAP,
	ACTION_NAME, ACTION_CODE,
	TABLE_ID, TABLE_NAME, TABLE_NAME_INITCAP,
	OBJECT_ID, IS_HIDDEN, COLUMN_ID, COLUMN_NAME,
	R_TABLE_NAME, R_COLUMN_NAME, FIELD_NAME, FIELD_VALUE, AFTER_VALUE,
	CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5,
	CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9
)
AS
SELECT A.ID, A.LOGGING_DATE LOGGING_TIMESTAMP,
	CAST(A.LOGGING_DATE AS DATE) LOGGING_DATE,
	A.USER_NAME, A.USER_NAME_INITCAP,
	A.ACTION_NAME, ACTION_CODE,
	A.TABLE_ID, A.TABLE_NAME, INITCAP(A.VIEW_NAME) TABLE_NAME_INITCAP,
	A.OBJECT_ID, A.IS_HIDDEN, A.COLUMN_ID, A.COLUMN_NAME,
	E.R_TABLE_NAME, E.R_COLUMN_NAME,
	INITCAP(REPLACE(CASE WHEN E.COLUMN_NAME IS NOT NULL THEN REGEXP_REPLACE(A.COLUMN_NAME,'ID$') ELSE A.COLUMN_NAME END,'_', ' ')) FIELD_NAME,
	custom_changelog.Changelog_Key_Value(A.AFTER_VALUE, E.R_VIEW_NAME, NVL(E.R_COLUMN_NAMES, E.U_COLUMN_NAMES), E.R_PRIMARY_KEY_COLS) FIELD_VALUE,
	AFTER_VALUE,
	CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5,
	CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9
FROM VCHANGE_LOG_COLUMNS A
LEFT OUTER JOIN MVBASE_REFERENCES E ON A.VIEW_NAME = E.VIEW_NAME AND A.COLUMN_NAME = E.COLUMN_NAME
;
COMMENT ON TABLE VCHANGE_LOG_FIELDS IS
'View is used in view VPROTOCOL_COLUMNS_LIST and function Changelog_Values to display changes to a row-column including decoded foreign key values.';

CREATE OR REPLACE FUNCTION Changelog_Values (
	p_Changelog_ID	IN CHANGE_LOG.ID%TYPE,
	p_Logging_Date  IN CHANGE_LOG.LOGGING_DATE%TYPE
)
RETURN VARCHAR2
IS -- funtion is used in VPROTOCOL_COLUMNS_LIST2 to display all changes to a row including decoded foreign key values.
	PRAGMA UDF;
	v_Result VARCHAR2(32767);
BEGIN
	FOR c_cur IN (
		SELECT
			FIELD_NAME, FIELD_VALUE
		FROM VCHANGE_LOG_FIELDS
		WHERE ID = p_Changelog_ID
		AND LOGGING_TIMESTAMP = p_Logging_Date
	)
	LOOP
		v_Result := v_Result || ', ' || c_cur.FIELD_NAME || ':' || c_cur.FIELD_VALUE;
	END LOOP;
	RETURN LTRIM(v_Result, ', ');
END Changelog_Values;
/
show errors

create or replace PACKAGE custom_changelog_gen IS
	g_Generate_Compact_Queries	VARCHAR2(5)		:= 'NO';	-- Generate Compact Queries to avoid overflow errors
	g_Job_Name_Prefix 			CONSTANT VARCHAR2(10) := 'DBROW_';
	g_Timemark 					NUMBER;

	FUNCTION FN_Scheduler_Context RETURN BINARY_INTEGER;

	PROCEDURE Lookup_custom_ref_Indexes (
		p_fkey_tables OUT VARCHAR2, 
		p_fkey_columns OUT VARCHAR2
	);
	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2 DETERMINISTIC;
	PROCEDURE MView_Refresh (
		p_MView_Name VARCHAR2,
		p_Dependent_MViews VARCHAR2 DEFAULT NULL
	);
    PROCEDURE Refresh_MViews (
    	p_context  				IN binary_integer DEFAULT FN_Scheduler_Context,
    	p_Start_Step 			IN binary_integer DEFAULT 1
    );
    PROCEDURE Refresh_MViews_Job (
    	p_Start_Step 	IN binary_integer DEFAULT 1,
        p_context binary_integer DEFAULT FN_Scheduler_Context		-- context is of type BINARY_INTEGER
   	);
	FUNCTION MViews_Stale_Count RETURN NUMBER;
    
	FUNCTION VPROTOCOL_LIST_Query RETURN VARCHAR2;
	FUNCTION VPROTOCOL_LIST_Cols RETURN VARCHAR2;
	FUNCTION VPROTOCOL_COLUMNS_LIST_Query RETURN VARCHAR2;
	FUNCTION VPROTOCOL_COLUMNS_LIST_Cols RETURN VARCHAR2;
	FUNCTION VPROTOCOL_COLUMNS_LIST2_Query RETURN VARCHAR2;
	FUNCTION VPROTOCOL_COLUMNS_LIST2_Cols RETURN VARCHAR2;
    FUNCTION User_Table_Timstamps_Query(p_Table_Name VARCHAR2 DEFAULT NULL) RETURN CLOB;
	TYPE rec_user_table_timstamps IS RECORD (
		TABLE_NAME 		VARCHAR2(128),
		ID				NUMBER,
		RID				VARCHAR2(128),
		LAST_MODIFIED_AT TIMESTAMP(6) WITH LOCAL TIME ZONE,
		LAST_MODIFIED_BY VARCHAR2(32),
		WORKSPACE$_ID 	NUMBER,
		DML$_ACTION 	CHAR(1)
	);
	TYPE tab_user_table_timstamps IS TABLE OF rec_user_table_timstamps;
	FUNCTION Pipe_User_Table_Timstamps (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN tab_user_table_timstamps PIPELINED;
    PROCEDURE Gen_VUSER_TABLE_TIMSTAMPS;
    PROCEDURE   Add_ChangeLog_Table_Trigger(
		p_Table_Name        IN VARCHAR2 DEFAULT NULL,
		p_Trigger_Name 		IN VARCHAR2 DEFAULT NULL,
    	p_context   		IN binary_integer DEFAULT FN_Scheduler_Context
	);
    PROCEDURE Drop_ChangeLog_Table_Trigger (
        p_Table_Name        IN VARCHAR2 DEFAULT NULL,
        p_Changelog_Only    IN VARCHAR2 DEFAULT 'YES'
    );
    PROCEDURE Tables_Add_Serial_Keys(
        p_Table_Name IN VARCHAR2 DEFAULT NULL,
        p_Changelog_Only IN VARCHAR2 DEFAULT 'YES'
    );
	PROCEDURE Refresh_ChangeLog_Trigger (
		p_Table_Name        IN VARCHAR2 DEFAULT NULL,
    	p_context        	IN  binary_integer DEFAULT FN_Scheduler_Context
	);
	FUNCTION Changelog_Is_Active( p_Table_Name VARCHAR2)
	RETURN VARCHAR2;
    FUNCTION Get_ChangeLogColDataType (
    	p_COLUMN_NAME VARCHAR2,
        p_DATA_TYPE VARCHAR2,
        p_DATA_PRECISION NUMBER,
        p_DATA_SCALE NUMBER,
        p_CHAR_LENGTH NUMBER,
        p_NULLABLE VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION ChangeLog_Pivot_Header (
		p_Table_Name IN VARCHAR2
	) RETURN CLOB;
	FUNCTION ChangeLog_Pivot_Query (
		p_Table_Name IN VARCHAR2,
		p_Convert_Data_Types IN VARCHAR2 DEFAULT 'YES',
		p_Compact_Queries IN VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB;
	FUNCTION ChangeLog_Query (
		p_Table_Name IN VARCHAR2,
		p_Compact_Queries IN VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB;
	FUNCTION Get_Record_History_Query (
		p_Table_Name VARCHAR2, 
		p_Key_Item_Name VARCHAR2 DEFAULT 'a'
	) RETURN VARCHAR2;
    PROCEDURE Add_ChangeLog_Views (
        p_Table_Name        IN VARCHAR2 DEFAULT NULL,
    	p_context   		IN binary_integer DEFAULT FN_Scheduler_Context
    );
    PROCEDURE Drop_ChangeLog_Views (
        p_Table_Name        IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE Prepare_Tables (
    	p_context   IN binary_integer DEFAULT FN_Scheduler_Context
    );
END custom_changelog_gen;
/