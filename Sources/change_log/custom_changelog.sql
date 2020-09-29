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
Package mit Tabellen, Views zur Aufzeichnung der Änderungs-Historie.
Die Änderungs-Historie wird sehr kompakt mit den Primary Key Werten und den
BEVORE Image Werten in einem VARRAY und sehr schnell mit BULK Operationen aufgezeichnet.

Zugriffspfade für ausgewählte Domains (Primary und Foreign Keys) ermöglichen
schnelle Auswertungen und historische Ansichten der Daten.

Für die Migration von vorher verwendeten Tabellen zur Aufzeichnung der Änderungen
zu dem hier verwendeten Tablellen sind Beispiel Statements vorhanden.

*/


--ALTER SESSION SET PLSQL_CODE_TYPE = NATIVE;
--ALTER SESSION SET PLSQL_OPTIMIZE_LEVEL = 3;

/*
DROP PACKAGE custom_changelog;
DROP TABLE CHANGE_LOG_BT;
DROP SEQUENCE CHANGELOG_SEQ;
DROP VIEW CHANGE_LOG;
DROP VIEW VCHANGELOG_ITEM;
DROP VIEW CHANGE_LOG_USERS;
DROP TYPE CHANGELOG_ITEM_ARRAY_GTYPE;
DROP TYPE CHANGELOG_ITEM_GTYPE;
DROP TABLE CHANGE_LOG_TABLES;
DROP TABLE CHANGE_LOG_USERS_BT;
DROP SEQUENCE CHANGE_LOG_TABLES_SEQ;
DROP SEQUENCE CHANGE_LOG_USERS_SEQ;

DROP VIEW VCHANGE_LOG;
DROP VIEW VCHANGE_LOG_COLUMNS;

-- required privileges
GRANT EXECUTE ON ORDSYS.ORDIMAGE TO ...;
*/

------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE custom_changelog
AUTHID DEFINER
IS
    ----------------------------------------------------------------------------
    PROCEDURE Load_Config;
    PROCEDURE Save_Config_Defaults;
    PROCEDURE Save_Config (
        p_Included_Changelog_Pattern VARCHAR2 DEFAULT NULL,     -- Table name pattern of tables to be included in the change log.
        p_Excluded_Changelog_Pattern VARCHAR2 DEFAULT NULL,     -- Table name pattern of tables to be excluded in the change log.
        p_Changelog_Fkey_Tables     VARCHAR2 DEFAULT NULL,      -- Tables with direct access Columns as References in the CHANGE_LOG table
        p_Changelog_Fkey_Columns    VARCHAR2 DEFAULT NULL,      -- Column Names of the direct References
        p_Excluded_Changelog_Blob_Cols  VARCHAR2 DEFAULT NULL,  -- BLOB Column Names to be excluded from Changelog Trigger
        p_Excluded_Changelog_Cols   VARCHAR2 DEFAULT NULL,      -- Column Names to be excluded from Changelog Trigger
        p_Reference_Description_Cols VARCHAR2 DEFAULT NULL,     -- Column Names for the description of foreign key references in Changelog Report
        p_Copy_Before_Image         VARCHAR2 DEFAULT NULL,      -- when set to YES, update statements will produce a copy of the before image into the change_log
        p_Base_Table_Ext            VARCHAR2 DEFAULT NULL,      -- Extension for Base Table name
        p_Changelog_View_Ext        VARCHAR2 DEFAULT NULL,      -- Extension for History Views with AS OF TIMESTAMP filter
        p_History_View_Ext          VARCHAR2 DEFAULT NULL,      -- Extension for History Views with all modification timestamps

        p_Table_App_Users           VARCHAR2 DEFAULT NULL,      -- Tabelle Name for Application Users
		p_Use_Audit_Info_Columns	VARCHAR2 DEFAULT NULL,		-- Enable Audit Info Columns (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT) when table is included.
		p_Drop_Audit_Info_Columns	VARCHAR2 DEFAULT NULL,		-- Drop Audit Info Columns (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT) when table is excluded.
		p_Use_Audit_Info_Trigger	VARCHAR2 DEFAULT NULL,		-- Enable Create and Drop operations for Before Insert Triggers and Before Update trigger
		p_Use_Change_Log 			VARCHAR2 DEFAULT NULL,		-- Enable Change Log Support (add triggers to selected tables to store the change history in table CHANGE_LOG)
        p_Add_Column_Workspace      VARCHAR2 DEFAULT NULL,     	-- (YES/NO) When this option is 'YES' then a 'Workspace$_ID' Column is added to selected tables. The current workspace is automatically initialized for each inserted row.
        p_Add_Column_Delete_Mark	VARCHAR2 DEFAULT NULL,     	-- (YES/NO) When this option is 'YES' then a 'Deleted_Mark' Column is added to selected tables. The Deleted_Mark is automatically set for each inserted or Deleted row.
		p_Add_Column_Modify_Date	VARCHAR2 DEFAULT NULL,		-- Add Column for Modified by date. The current timestamp is automatically inserted for each updated row.
		p_Add_Column_Modify_User	VARCHAR2 DEFAULT NULL,		-- Add Column for Modified by user. The current user name is automatically inserted for each updated row.
		p_Add_Column_Creation_Date	VARCHAR2 DEFAULT NULL,		-- Add Column for Created by date. The current timestamp is automatically inserted for each inserted row.
		p_Add_Column_Creation_User	VARCHAR2 DEFAULT NULL,		-- Add Column for Created by user. The current user name is automatically inserted for each inserted row.
		p_Enforce_Not_Null			VARCHAR2 DEFAULT NULL,		-- when this option is 'YES' then a NOT NULL constraint is add to each 'Modification_Timestamp', 'Modification_User', 'Created_Timestamp and Created_User column
		p_Add_Insert_Trigger		VARCHAR2 DEFAULT NULL,		-- create instead of INSERT trigger for views with composite primary keys. A merge statement will reactivate deleted rows with the same primary key values
		p_Add_Delete_Trigger		VARCHAR2 DEFAULT NULL,		-- Create instead of delete trigger for views. Mark rows as deleted instead of deleting them.
		p_Add_Update_Trigger1		VARCHAR2 DEFAULT NULL,		-- create instead of UPDATE trigger for views without changelog to preserve old values. The current row is marked as deleted and a new row is inserted with the same primary key
		p_Add_Update_Trigger2		VARCHAR2 DEFAULT NULL,		-- create instead of UPDATE trigger for views without changelog and for tables with BLOB columns to preserve old BLOB. The current row is marked as deleted and a new row is inserted with the same primary key
		p_Add_Application_Schema	VARCHAR2 DEFAULT NULL,		-- when this option is 'YES' then Application Schema Objects and Privileges are generated. The Application Schema limits the access to views that cover the base tables.
		p_Add_ChangeLop_Views		VARCHAR2 DEFAULT NULL,		-- when this option is 'YES' then Change Log Views are generated. The Change Log Views enable access to historic versions of table rows and as of timestamp views of table rows for the managed tables.
        p_Use_On_Null_Defaults      VARCHAR2 DEFAULT NULL,     	-- (YES/NO) use DEFAULT ON NULL in Oracle 12c
        p_Use_Sequences             VARCHAR2 DEFAULT NULL,     	-- (YES/NO) Use Sequences to manage primary key defaults or triggers,
        p_Include_External_Objects  VARCHAR2 DEFAULT NULL, 		-- (YES/NO) Use External Objects
        p_Included_WorkspaceID_Pattern VARCHAR2 DEFAULT NULL,   -- Include 'WORKSPACE$_ID' for LIKE matching tables
        p_Excluded_WorkspaceID_Pattern VARCHAR2 DEFAULT NULL,   -- Exclude 'WORKSPACE$_ID' from LIKE matching tables
        p_Included_Delete_Mark_Pattern VARCHAR2 DEFAULT NULL,	-- Include 'DELETED_MARK' for LIKE matching tables
        p_Excluded_Delete_Mark_Pattern VARCHAR2 DEFAULT NULL,	-- Exclude 'DELETED_MARK' from temporary and cache and snapshot tables
        p_Included_Timestamp_Pattern VARCHAR2 DEFAULT NULL,		-- Include 'LAST_MODIFIED_BY' and 'LAST_MODIFIED_AT' for LIKE matching tables
        p_Excluded_Timestamp_Pattern VARCHAR2 DEFAULT NULL,		-- Exclude 'LAST_MODIFIED_BY' and 'LAST_MODIFIED_AT' from temporary and cache and snapshot tables
        p_Column_Workspace          VARCHAR2 DEFAULT NULL,   	-- Column Name for VPD Workspace
        p_Column_Create_User        VARCHAR2 DEFAULT NULL,      -- Column Name for Create Username
        p_Column_Create_Date        VARCHAR2 DEFAULT NULL,      -- Column Name for Create Date
        p_Column_Modify_User        VARCHAR2 DEFAULT NULL, 		-- Column Name for Modification Username
        p_Column_Modify_Date        VARCHAR2 DEFAULT NULL, 		-- Column Name for Modification Date
        p_Column_Deleted_Mark       VARCHAR2 DEFAULT NULL,    	-- Column Name for Deleted Mark
        p_Column_Index_Format       VARCHAR2 DEFAULT NULL,    	-- index format column for context index
        p_Datatype_Modify_User      VARCHAR2 DEFAULT NULL,      -- Datatype for Modification Username
        p_Columntype_Modify_User    VARCHAR2 DEFAULT NULL,      -- Datatype for Modification Username
        p_Is_Foreign_Key_Modify_User VARCHAR2 DEFAULT NULL,     -- (YES/NO) Column for Create Username is a foreign key
        p_Function_Modify_User      VARCHAR2 DEFAULT NULL,      -- Function for Modification User
        p_Function_Modify_Date      VARCHAR2 DEFAULT NULL,      -- Function for Modification Date
        p_Datatype_Modify_Date      VARCHAR2 DEFAULT NULL,      -- Datatype for Modification Date
        p_Datatype_Modify_Date_Alt  VARCHAR2 DEFAULT NULL,      -- Alternative Datatype for Modification Date
        p_Datatype_Deleted_Mark     VARCHAR2 DEFAULT NULL,      -- Datatype for Deleted Mark
        p_Columntype_Deleted_Mark   VARCHAR2 DEFAULT NULL,      -- Datatype for Deleted Mark
        p_Default_Deleted_Mark      VARCHAR2 DEFAULT NULL,      -- Default for Deleted Mark
        p_Sequence_Ext              VARCHAR2 DEFAULT NULL,      -- Extension for Sequences
        p_Sequence_Column_Ext       VARCHAR2 DEFAULT NULL,      -- Extension for Sequences Column
        p_Sequence_Constraint_Ext   VARCHAR2 DEFAULT NULL,      -- Extension for Sequences Column Constraint
        p_Sequence_Options          VARCHAR2 DEFAULT NULL,      -- Options for Sequences
        p_Interrim_Table_Ext        VARCHAR2 DEFAULT NULL,      -- Extension for interrim tables
        p_Change_Log_Trigger_Prefix	VARCHAR2 DEFAULT NULL,      -- Prefix for Compound Change_Log trigger
        p_Change_Log_Trigger_Ext	VARCHAR2 DEFAULT NULL,      -- Extension for Compound Change_Log trigger
        p_Bi_Trigger_Prefix         VARCHAR2 DEFAULT NULL,      -- Prefix for Before Insert trigger
        p_Bi_Trigger_Ext            VARCHAR2 DEFAULT NULL,      -- Extension for Before Insert trigger
        p_Bu_Trigger_Prefix         VARCHAR2 DEFAULT NULL,      -- Prefix for Before Update trigger
        p_Bu_Trigger_Ext            VARCHAR2 DEFAULT NULL,      -- Extension for Before Update trigger
        p_Ins_Trigger_Prefix        VARCHAR2 DEFAULT NULL,      -- Prefix for Instead Of Delete trigger
        p_Ins_Trigger_Ext           VARCHAR2 DEFAULT NULL,      -- Extension for Instead Of Delete trigger
        p_Del_Trigger_Prefix        VARCHAR2 DEFAULT NULL,      -- Prefix for Instead Of Delete trigger
        p_Del_Trigger_Ext           VARCHAR2 DEFAULT NULL,      -- Extension for Instead Of Delete trigger
        p_Upd_Trigger_Prefix        VARCHAR2 DEFAULT NULL,       -- Prefix for Instead Of Update trigger
        p_Upd_Trigger_Ext           VARCHAR2 DEFAULT NULL       -- Extension for Instead Of Update trigger
    );

    FUNCTION Get_Context_Workspace_Name RETURN VARCHAR2;
    FUNCTION Get_Current_Workspace_ID RETURN  USER_NAMESPACES.WORKSPACE$_ID%TYPE;
	PROCEDURE Set_Current_Workspace (
   		p_Workspace_Name	IN VARCHAR2
   	);
	PROCEDURE Set_New_Workspace (
   		p_Workspace_Name	IN VARCHAR2
   	);
    FUNCTION Get_Current_User_Name RETURN VARCHAR2;
    FUNCTION Get_ChangeLogTable RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogFunction RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogFinishFunction RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogFlushFunction RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_AltChangeLogFunction RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogViewExt RETURN VARCHAR2;
    FUNCTION Get_ChangeLogViewName(p_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_HistoryViewExt RETURN VARCHAR2;
	FUNCTION Get_HistoryViewName(p_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_ChangeLogFKeyTables RETURN VARCHAR2;
    FUNCTION Get_ChangeLogFKeyColumns RETURN VARCHAR2;
    FUNCTION Get_IncludeChangeLogPattern RETURN VARCHAR2;
    FUNCTION Get_ExcludeChangeLogPattern RETURN VARCHAR2;
    FUNCTION Get_ExcludeChangeLogBlobCols RETURN VARCHAR2;
    FUNCTION Get_ReferenceDescriptionCols RETURN VARCHAR2;
    FUNCTION Get_ExcludeChangeLogCols RETURN VARCHAR2;
	FUNCTION Has_ChangeLog_History (p_Table_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Enquote_Column_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_ChangeLogAddColFunction(
        p_DATA_TYPE VARCHAR2,
        p_DATA_SCALE NUMBER,
        p_CHAR_LENGTH NUMBER,
        p_COLUMN_NAME VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

    TYPE change_log_t IS TABLE OF CHANGE_LOG_BT%ROWTYPE INDEX BY PLS_INTEGER;
    ChangeLogA      change_log_t;
    ChangeLogB      change_log_t;
    g_idxa          PLS_INTEGER := 0;
    g_idya          PLS_INTEGER := 0;
    g_idxb          PLS_INTEGER := 0;
    g_idyb          PLS_INTEGER := 0;
    g_ChangeLogInsCnt   PLS_INTEGER := 0;
    g_ChangeLogEnabled BOOLEAN := TRUE;

    PROCEDURE EnableLog;
    PROCEDURE DisableLog;
    PROCEDURE FlushLog;
    PROCEDURE FinishLog;
    PROCEDURE AddLog (
        p_Table_Name     IN VARCHAR2,
        p_Object_ID      IN CHANGE_LOG_BT.OBJECT_ID%TYPE,
        p_InsertDate     IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_Deleted_Mark   IN VARCHAR2 DEFAULT NULL,
        p_WORKSPACE_ID   IN CHANGE_LOG_BT.WORKSPACE$_ID%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID1 IN CHANGE_LOG_BT.CUSTOM_REF_ID1%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID2 IN CHANGE_LOG_BT.CUSTOM_REF_ID2%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID3 IN CHANGE_LOG_BT.CUSTOM_REF_ID3%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID4 IN CHANGE_LOG_BT.CUSTOM_REF_ID4%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID5 IN CHANGE_LOG_BT.CUSTOM_REF_ID5%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID6 IN CHANGE_LOG_BT.CUSTOM_REF_ID6%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID7 IN CHANGE_LOG_BT.CUSTOM_REF_ID7%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID8 IN CHANGE_LOG_BT.CUSTOM_REF_ID8%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID9 IN CHANGE_LOG_BT.CUSTOM_REF_ID9%TYPE DEFAULT NULL
    );
    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN VARCHAR2,
        p_After       IN VARCHAR2
    );
    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN CLOB,
        p_After       IN CLOB
    );
    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN NUMBER,
        p_After       IN NUMBER
    );

    PROCEDURE AddLogRawCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN RAW,
        p_After       IN RAW
    );

    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN DATE,
        p_After       IN DATE
    );
    PROCEDURE AddLogTSCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN TIMESTAMP WITH LOCAL TIME ZONE,
        p_After       IN TIMESTAMP WITH LOCAL TIME ZONE
    );

    FUNCTION Changelog_Key_Value (
        p_After         IN VARCHAR2,
        p_Table_Name    IN VARCHAR2,
        p_Key_Name      IN VARCHAR2,
        p_Primary_Key_Cols IN VARCHAR2
    )
    RETURN VARCHAR2;

    FUNCTION Changelog_Column_Name (
        p_Table_Name    IN VARCHAR2,
        p_Column_ID    IN INTEGER
    )
    RETURN VARCHAR2 DETERMINISTIC;

    PROCEDURE Changelog_Tables_Init (
        p_Source_View_Name IN VARCHAR2 DEFAULT 'MVBASE_VIEWS'
    );

    FUNCTION Changelog_Table_ID (
        p_Table_Name    IN VARCHAR2
    )
    RETURN INTEGER DETERMINISTIC;

    FUNCTION Changelog_User_ID (
        p_User_Name    IN VARCHAR2,
        p_Workspace_Id IN INTEGER
    )
    RETURN CHANGE_LOG_USERS_BT.ID%TYPE DETERMINISTIC;

    FUNCTION Changelog_Column_ID (
        p_Table_Name    IN VARCHAR2,
        p_Column_Name   IN VARCHAR2
    )
    RETURN INTEGER DETERMINISTIC;

    FUNCTION Compare_Blob ( p_Old_Blob BLOB, p_New_Blob BLOB)  RETURN BOOLEAN DETERMINISTIC;

    FUNCTION Compare_Clob ( p_Old_Blob CLOB, p_New_Blob CLOB) RETURN BOOLEAN DETERMINISTIC;

    FUNCTION Compare_Long ( p_Old_Blob LONG, p_New_Blob LONG) RETURN BOOLEAN DETERMINISTIC;

$IF changelog_conf.g_Use_ORDIMAGE $THEN
    FUNCTION Compare_ORDIMAGE (
        p_Old_Blob      IN ORDIMAGE,
        p_New_Blob      IN ORDIMAGE
    )
    RETURN BOOLEAN;
$END

    FUNCTION Get_ChangeLogTextLimit RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogCurrencyFormat RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogCurrNumChars RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogDateFormat RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogTimestampFormat RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_CopyBeforeImage RETURN VARCHAR2 DETERMINISTIC;

    -- remove changelog entries for removed rows
    PROCEDURE  Purge_Changelog_Rows (
        p_View_Name VARCHAR2,
        p_Primary_Key_Col VARCHAR2,
        p_Workspace_ID INTEGER,
        p_First_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    PROCEDURE  Delete_Changelog_Rows ( p_View_Name VARCHAR2 );

    PROCEDURE  Purge_Changelog_Rows;

	PROCEDURE Set_Query_Timestamp (
   		p_Timestamp		IN TIMESTAMP
   	);
	PROCEDURE Set_Query_Date (
   		p_DateTime		IN DATE
   	);
	FUNCTION Get_Query_Timestamp RETURN TIMESTAMP;
END custom_changelog;
/
show errors


CREATE OR REPLACE PACKAGE BODY custom_changelog IS
    -- When this option is set to 'YES', update statements will produce a copy of the before image into the change log table.
    -- Enable this option when the logging is activated for some none empty tables.
    -- This will ensure that the complete change history can be tracked (starting from the point in time when the logging is activited)
    g_ChangeLogCopyBeforeImage  BOOLEAN                 := TRUE;
    g_ChangeLogCurrencyFormat   CONSTANT VARCHAR2(64)   := '9G999G999G990D99';
    g_AltChangeLogCurrFormat    CONSTANT VARCHAR2(64)   := '9999999990D99';
    g_ChangeLogCurrNumChars     CONSTANT VARCHAR2(64)   := 'NLS_NUMERIC_CHARACTERS = '',.''';
    g_ChangeLogFloatFormat      CONSTANT VARCHAR2(64)   := 'TM9';
    g_ChangeLogNumberFormat		CONSTANT VARCHAR2(64)   := 'TM9';
    g_ChangeLogDateFormat       CONSTANT VARCHAR2(64)   := 'DD.MM.YYYY HH24:MI:SS';
    g_ChangeLogTimestampFormat  CONSTANT VARCHAR2(64)   := 'DD.MM.YYYY HH24.MI.SSXFF';
    g_ChangeLogAltTSFormat      CONSTANT VARCHAR2(64)   := 'DD.MM.YYYY HH24.MI.SS,FF';
    g_ChangeLogTextLimit        CONSTANT INTEGER        := 400;
    g_flush_threshhold          CONSTANT INTEGER        := 50;
    g_ChangeLogTable            CONSTANT VARCHAR2(64)   := 'CHANGE_LOG_BT';
    g_ChangeLogFunction         CONSTANT VARCHAR2(64)   := 'Custom_AddLog';
    g_ChangeLogFinishFunction   CONSTANT VARCHAR2(64)   := 'custom_changelog.FinishLog';
    g_ChangeLogFlushFunction    CONSTANT VARCHAR2(64)   := 'custom_changelog.FlushLog';
    g_AltChangeLogFunction      CONSTANT VARCHAR2(64)   := 'custom_changelog.AddLog';
    g_ChangeLogViewExt          VARCHAR2(64)            := '_CL';       -- Extension for History Views with AS OF TIMESTAMP filter
    g_HistoryViewExt            VARCHAR2(64)            := '_HS';       -- Extension for History Views with all modification timestamps
    -----------------------------------------------------------------------------
    -- Table name pattern of tables to be included in the change log.
    g_IncludeChangeLogPattern VARCHAR2(4000)            := '%';
    -- Table name pattern of tables to be excluded in the change log.
    g_ExcludeChangeLogPattern VARCHAR2(4000)            := 'EBA_DP%,CLOUD_VISITORS%';
    c_ExcludeChangeLogPattern CONSTANT VARCHAR2(400)    := 'CHANGE_LOG%,USER_WORKSPACE_SESSIONS,DATA_BROWSER_CHECKS,%HISTORY%,%PROTOCOL%,%PLUGIN%';

    -- Tables of interest with direct access in the CHANGE_LOG table. The Columns CUSTOM_REF_ID1 to CUSTOM_REF_ID9 will be defined as References to this tables.
    g_ChangeLogFKeyTables VARCHAR2(4000)                := 'REGIONS, DEPARTMENTS, EMPLOYEES';
    -- Column Names of the direct References. The Columns CUSTOM_REF_ID1 to CUSTOM_REF_ID9 will be renamed to this names in the views VPROTOCOL_LIST, VPROTOCOL_COLUMNS_LIST and VPROTOCOL_COLUMNS_LIST2
    g_ChangeLogFKeyColumns VARCHAR2(4000)               := 'REGION_ID, DEPARTMENT_ID, EMPLOYEE_ID';
    -- BLOB Column Names to be excluded from Changelog Trigger. An update on this columns will not produce a backup copy of the before image
    g_ExcludeChangeLogBlobCols VARCHAR2(4000)           := '';

    -- Column Names to be excluded from Changelog Trigger
    g_ExcludeChangeLogCols VARCHAR2(4000)               := '';
    -- Column Names for the description of foreign key references in Changelog Report
    g_ReferenceDescriptionCols VARCHAR2(4000)           := '%NAME, %DESCRIPTION, %BESCHREIBUNG, %BEZEICHNUNG';

	g_CtxTimestampFormat CONSTANT VARCHAR2(64)	:= 'DD.MM.YYYY HH24.MI.SS.FF TZH:TZM';
	g_Timestamp_Item 	CONSTANT VARCHAR2(32) := 'APP_QUERY_TIMESTAMP'; -- Apex Item for current query timestamp
	g_Workspace_Item 	CONSTANT VARCHAR2(30) := 'APP_WORKSPACE';	-- Apex Item for current workspace name

    PROCEDURE Save_Config_Defaults
    IS PRAGMA AUTONOMOUS_TRANSACTION;
        v_ChangeLogCopyBeforeImage  VARCHAR2(128) := case when g_ChangeLogCopyBeforeImage then 'YES' else 'NO' end;
    BEGIN
    	INSERT INTO USER_NAMESPACES (WORKSPACE_NAME)
    	SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') WORKSPACE_NAME
    	FROM DUAL S
    	WHERE NOT EXISTS (
    		SELECT 1 FROM USER_NAMESPACES T 
    		WHERE T.WORKSPACE_NAME = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
    	);
    	
		INSERT INTO CHANGE_LOG_CONFIG (ID, INCLUDED_CHANGELOG_PATTERN, EXCLUDED_CHANGELOG_PATTERN,
            CHANGELOG_FKEY_TABLES, CHANGELOG_FKEY_COLUMNS,
            EXCLUDED_CHANGELOG_BLOB_COLS, EXCLUDED_CHANGELOG_COLS, REFERENCE_DESCRIPTION_COLS,
            COPY_BEFORE_IMAGE, CHANGELOG_VIEW_EXT, HISTORY_VIEW_EXT
		) VALUES (1, g_IncludeChangeLogPattern, g_ExcludeChangeLogPattern,
            g_ChangeLogFKeyTables, g_ChangeLogFKeyColumns,
            g_ExcludeChangeLogBlobCols, g_ExcludeChangeLogCols, g_ReferenceDescriptionCols,
            v_ChangeLogCopyBeforeImage, g_ChangeLogViewExt, g_HistoryViewExt
		);

        changelog_conf.Save_Config_Defaults;
        COMMIT;
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
    	NULL;
    	ROLLBACK;
	END;

    PROCEDURE Load_Config
    IS
        v_ChangeLogCopyBeforeImage  VARCHAR2(128);
        v_ColumnWorkspace			VARCHAR2(128);
    BEGIN
    	v_ColumnWorkspace := changelog_conf.Get_ColumnWorkspace; -- init package changelog_conf
        SELECT INCLUDED_CHANGELOG_PATTERN, EXCLUDED_CHANGELOG_PATTERN,
            CHANGELOG_FKEY_TABLES, CHANGELOG_FKEY_COLUMNS,
            EXCLUDED_CHANGELOG_BLOB_COLS, EXCLUDED_CHANGELOG_COLS, REFERENCE_DESCRIPTION_COLS,
            COPY_BEFORE_IMAGE, CHANGELOG_VIEW_EXT, HISTORY_VIEW_EXT
        INTO g_IncludeChangeLogPattern, g_ExcludeChangeLogPattern,
            g_ChangeLogFKeyTables, g_ChangeLogFKeyColumns,
            g_ExcludeChangeLogBlobCols, g_ExcludeChangeLogCols, g_ReferenceDescriptionCols,
            v_ChangeLogCopyBeforeImage, g_ChangeLogViewExt, g_HistoryViewExt
        FROM CHANGE_LOG_CONFIG
        WHERE ID = 1;

        g_ChangeLogCopyBeforeImage := (v_ChangeLogCopyBeforeImage = 'YES');
    EXCEPTION WHEN NO_DATA_FOUND THEN
		NULL;
    END;

    PROCEDURE Save_Config (
        p_Included_Changelog_Pattern VARCHAR2 DEFAULT NULL,     -- Table name pattern of tables to be included in the change log.
        p_Excluded_Changelog_Pattern VARCHAR2 DEFAULT NULL,     -- Table name pattern of tables to be excluded in the change log.
        p_Changelog_Fkey_Tables     VARCHAR2 DEFAULT NULL,      -- Tables with direct access Columns as References in the CHANGE_LOG table
        p_Changelog_Fkey_Columns    VARCHAR2 DEFAULT NULL,      -- Column Names of the direct References
        p_Excluded_Changelog_Blob_Cols  VARCHAR2 DEFAULT NULL,  -- BLOB Column Names to be excluded from Changelog Trigger
        p_Excluded_Changelog_Cols   VARCHAR2 DEFAULT NULL,      -- Column Names to be excluded from Changelog Trigger
        p_Reference_Description_Cols VARCHAR2 DEFAULT NULL,     -- Column Names for the description of foreign key references in Changelog Report
        p_Copy_Before_Image         VARCHAR2 DEFAULT NULL,      -- when set to YES, update statements will produce a copy of the before image into the change_log
        p_Base_Table_Ext            VARCHAR2 DEFAULT NULL,      -- Extension for Base Table name
        p_Changelog_View_Ext        VARCHAR2 DEFAULT NULL,      -- Extension for History Views with AS OF TIMESTAMP filter
        p_History_View_Ext          VARCHAR2 DEFAULT NULL,      -- Extension for History Views with all modification timestamps

        p_Table_App_Users           VARCHAR2 DEFAULT NULL,      -- Tabelle Name for Application Users
		p_Use_Audit_Info_Columns	VARCHAR2 DEFAULT NULL,		-- Enable Audit Info Columns (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT) when table is included.
		p_Drop_Audit_Info_Columns	VARCHAR2 DEFAULT NULL,		-- Drop Audit Info Columns (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT) when table is excluded.
		p_Use_Audit_Info_Trigger	VARCHAR2 DEFAULT NULL,		-- Enable Create and Drop operations for Before Insert Triggers and Before Update trigger
		p_Use_Change_Log 			VARCHAR2 DEFAULT NULL,		-- Enable Change Log Support (add triggers to selected tables to store the change history in table CHANGE_LOG)
        p_Add_Column_Workspace      VARCHAR2 DEFAULT NULL,     	-- (YES/NO) When this option is 'YES' then a 'Workspace$_ID' Column is added to selected tables. The current workspace is automatically initialized for each inserted row.
        p_Add_Column_Delete_Mark	VARCHAR2 DEFAULT NULL,     	-- (YES/NO) When this option is 'YES' then a 'Deleted_Mark' Column is added to selected tables. The Deleted_Mark is automatically set for each inserted or Deleted row.
		p_Add_Column_Modify_Date	VARCHAR2 DEFAULT NULL,		-- Add Column for Modified by date. The current timestamp is automatically inserted for each updated row.
		p_Add_Column_Modify_User	VARCHAR2 DEFAULT NULL,		-- Add Column for Modified by user. The current user name is automatically inserted for each updated row.
		p_Add_Column_Creation_Date	VARCHAR2 DEFAULT NULL,		-- Add Column for Created by date. The current timestamp is automatically inserted for each inserted row.
		p_Add_Column_Creation_User	VARCHAR2 DEFAULT NULL,		-- Add Column for Created by user. The current user name is automatically inserted for each inserted row.
		p_Enforce_Not_Null			VARCHAR2 DEFAULT NULL,		-- when this option is 'YES' then a NOT NULL constraint is add to each 'Modification_Timestamp', 'Modification_User', 'Created_Timestamp and Created_User column
		p_Add_Insert_Trigger		VARCHAR2 DEFAULT NULL,		-- create instead of INSERT trigger for views with composite primary keys. A merge statement will reactivate deleted rows with the same primary key values
		p_Add_Delete_Trigger		VARCHAR2 DEFAULT NULL,		-- Create instead of delete trigger for views. Mark rows as deleted instead of deleting them.
		p_Add_Update_Trigger1		VARCHAR2 DEFAULT NULL,		-- create instead of UPDATE trigger for views without changelog to preserve old values. The current row is marked as deleted and a new row is inserted with the same primary key
		p_Add_Update_Trigger2		VARCHAR2 DEFAULT NULL,		-- create instead of UPDATE trigger for views without changelog and for tables with BLOB columns to preserve old BLOB. The current row is marked as deleted and a new row is inserted with the same primary key
		p_Add_Application_Schema	VARCHAR2 DEFAULT NULL,		-- when this option is 'YES' then Application Schema Objects and Privileges are generated. The Application Schema limits the access to views that cover the base tables.
		p_Add_ChangeLop_Views		VARCHAR2 DEFAULT NULL,		-- when this option is 'YES' then Change Log Views are generated. The Change Log Views enable access to historic versions of table rows and as of timestamp views of table rows for the managed tables.
        p_Use_On_Null_Defaults      VARCHAR2 DEFAULT NULL,     	-- (YES/NO) use DEFAULT ON NULL in Oracle 12c
        p_Use_Sequences             VARCHAR2 DEFAULT NULL,     	-- (YES/NO) Use Sequences to manage primary key defaults or triggers,
        p_Include_External_Objects  VARCHAR2 DEFAULT NULL, 		-- (YES/NO) Use External Objects
        p_Included_WorkspaceID_Pattern VARCHAR2 DEFAULT NULL,   -- Include 'WORKSPACE$_ID' for LIKE matching tables
        p_Excluded_WorkspaceID_Pattern VARCHAR2 DEFAULT NULL,   -- Exclude 'WORKSPACE$_ID' from LIKE matching tables
        p_Included_Delete_Mark_Pattern VARCHAR2 DEFAULT NULL,	-- Include 'DELETED_MARK' for LIKE matching tables
        p_Excluded_Delete_Mark_Pattern VARCHAR2 DEFAULT NULL,	-- Exclude 'DELETED_MARK' from temporary and cache and snapshot tables
        p_Included_Timestamp_Pattern VARCHAR2 DEFAULT NULL,		-- Include 'LAST_MODIFIED_BY' and 'LAST_MODIFIED_AT' for LIKE matching tables
        p_Excluded_Timestamp_Pattern VARCHAR2 DEFAULT NULL,		-- Exclude 'LAST_MODIFIED_BY' and 'LAST_MODIFIED_AT' from temporary and cache and snapshot tables
        p_Column_Workspace          VARCHAR2 DEFAULT NULL,   	-- Column Name for VPD Workspace
        p_Column_Create_User        VARCHAR2 DEFAULT NULL,      -- Column Name for Create Username
        p_Column_Create_Date        VARCHAR2 DEFAULT NULL,      -- Column Name for Create Date
        p_Column_Modify_User        VARCHAR2 DEFAULT NULL, 		-- Column Name for Modification Username
        p_Column_Modify_Date        VARCHAR2 DEFAULT NULL, 		-- Column Name for Modification Date
        p_Column_Deleted_Mark       VARCHAR2 DEFAULT NULL,    	-- Column Name for Deleted Mark
        p_Column_Index_Format       VARCHAR2 DEFAULT NULL,    	-- index format column for context index
        p_Datatype_Modify_User      VARCHAR2 DEFAULT NULL,      -- Datatype for Modification Username
        p_Columntype_Modify_User    VARCHAR2 DEFAULT NULL,      -- Datatype for Modification Username
        p_Is_Foreign_Key_Modify_User VARCHAR2 DEFAULT NULL,     -- (YES/NO) Column for Create Username is a foreign key
        p_Function_Modify_User      VARCHAR2 DEFAULT NULL,      -- Function for Modification User
        p_Function_Modify_Date      VARCHAR2 DEFAULT NULL,      -- Function for Modification Date
        p_Datatype_Modify_Date      VARCHAR2 DEFAULT NULL,      -- Datatype for Modification Date
        p_Datatype_Modify_Date_Alt  VARCHAR2 DEFAULT NULL,      -- Alternative Datatype for Modification Date
        p_Datatype_Deleted_Mark     VARCHAR2 DEFAULT NULL,      -- Datatype for Deleted Mark
        p_Columntype_Deleted_Mark   VARCHAR2 DEFAULT NULL,      -- Datatype for Deleted Mark
        p_Default_Deleted_Mark      VARCHAR2 DEFAULT NULL,      -- Default for Deleted Mark
        p_Sequence_Ext              VARCHAR2 DEFAULT NULL,      -- Extension for Sequences
        p_Sequence_Column_Ext       VARCHAR2 DEFAULT NULL,      -- Extension for Sequences Column
        p_Sequence_Constraint_Ext   VARCHAR2 DEFAULT NULL,      -- Extension for Sequences Column Constraint
        p_Sequence_Options          VARCHAR2 DEFAULT NULL,      -- Options for Sequences
        p_Interrim_Table_Ext        VARCHAR2 DEFAULT NULL,      -- Extension for interrim tables
        p_Change_Log_Trigger_Prefix	VARCHAR2 DEFAULT NULL,      -- Prefix for Compound Change_Log trigger
        p_Change_Log_Trigger_Ext	VARCHAR2 DEFAULT NULL,      -- Extension for Compound Change_Log trigger
        p_Bi_Trigger_Prefix         VARCHAR2 DEFAULT NULL,      -- Prefix for Before Insert trigger
        p_Bi_Trigger_Ext            VARCHAR2 DEFAULT NULL,      -- Extension for Before Insert trigger
        p_Bu_Trigger_Prefix         VARCHAR2 DEFAULT NULL,      -- Prefix for Before Update trigger
        p_Bu_Trigger_Ext            VARCHAR2 DEFAULT NULL,      -- Extension for Before Update trigger
        p_Ins_Trigger_Prefix        VARCHAR2 DEFAULT NULL,      -- Prefix for Instead Of Delete trigger
        p_Ins_Trigger_Ext           VARCHAR2 DEFAULT NULL,      -- Extension for Instead Of Delete trigger
        p_Del_Trigger_Prefix        VARCHAR2 DEFAULT NULL,      -- Prefix for Instead Of Delete trigger
        p_Del_Trigger_Ext           VARCHAR2 DEFAULT NULL,      -- Extension for Instead Of Delete trigger
        p_Upd_Trigger_Prefix        VARCHAR2 DEFAULT NULL,       -- Prefix for Instead Of Update trigger
        p_Upd_Trigger_Ext           VARCHAR2 DEFAULT NULL       -- Extension for Instead Of Update trigger
    )
    IS
    BEGIN
    	custom_changelog.Save_Config_Defaults;

        UPDATE CHANGE_LOG_CONFIG D
        SET (
                INCLUDED_CHANGELOG_PATTERN, EXCLUDED_CHANGELOG_PATTERN, CHANGELOG_FKEY_TABLES, CHANGELOG_FKEY_COLUMNS,
                EXCLUDED_CHANGELOG_BLOB_COLS, EXCLUDED_CHANGELOG_COLS, REFERENCE_DESCRIPTION_COLS, COPY_BEFORE_IMAGE,
                BASE_TABLE_EXT, CHANGELOG_VIEW_EXT, HISTORY_VIEW_EXT,
                TABLE_APP_USERS, USE_AUDIT_INFO_COLUMNS, DROP_AUDIT_INFO_COLUMNS, USE_AUDIT_INFO_TRIGGER, USE_CHANGE_LOG,
                ADD_COLUMN_WORKSPACE_ID, ADD_COLUMN_DELETE_MARK,
				ADD_COLUMN_MODIFY_DATE, ADD_COLUMN_MODIFY_USER, ADD_COLUMN_CREATION_DATE, ADD_COLUMN_CREATION_USER,
				ENFORCE_NOT_NULL, ADD_INSERT_TRIGGER, ADD_DELETE_TRIGGER, ADD_UPDATE_TRIGGER1, ADD_UPDATE_TRIGGER2,
				ADD_APPLICATION_SCHEMA, ADD_CHANGELOG_VIEWS,
                USE_ON_NULL_DEFAULTS, USE_SEQUENCES, INCLUDE_EXTERNAL_OBJECTS,
                INCLUDED_WORKSPACEID_PATTERN, EXCLUDED_WORKSPACEID_PATTERN,
                INCLUDED_DELETE_MARK_PATTERN, EXCLUDED_DELETE_MARK_PATTERN,
                INCLUDED_TIMESTAMP_PATTERN, EXCLUDED_TIMESTAMP_PATTERN,
                COLUMN_WORKSPACE, COLUMN_CREATE_USER, COLUMN_CREATE_DATE, COLUMN_MODIFY_USER, COLUMN_MODIFY_DATE,
                COLUMN_DELETED_MARK, COLUMN_INDEX_FORMAT,
                DATATYPE_MODIFY_USER, COLUMNTYPE_MODIFY_USER, IS_FOREIGN_KEY_MODIFY_USER,
                FUNCTION_MODIFY_USER, FUNCTION_MODIFY_DATE, DATATYPE_MODIFY_DATE, DATATYPE_MODIFY_DATE_ALT,
                DATATYPE_DELETED_MARK, COLUMNTYPE_DELETED_MARK, DEFAULT_DELETED_MARK,
                SEQUENCE_EXT, SEQUENCE_COLUMN_EXT, SEQUENCE_CONSTRAINT_EXT, SEQUENCE_OPTIONS,
                INTERRIM_TABLE_EXT, CHANGE_LOG_TRIGGER_PREFIX, CHANGE_LOG_TRIGGER_EXT,
				BI_TRIGGER_PREFIX, BI_TRIGGER_EXT, BU_TRIGGER_PREFIX, BU_TRIGGER_EXT,
				INS_TRIGGER_PREFIX, INS_TRIGGER_EXT, DEL_TRIGGER_PREFIX, DEL_TRIGGER_EXT, UPD_TRIGGER_PREFIX, UPD_TRIGGER_EXT
            ) = (
            SELECT
				NULLIF(NVL(p_Included_Changelog_Pattern, INCLUDED_CHANGELOG_PATTERN), ' '),
				NULLIF(NVL(p_Excluded_Changelog_Pattern, EXCLUDED_CHANGELOG_PATTERN), ' '),
				NULLIF(NVL(p_Changelog_Fkey_Tables, CHANGELOG_FKEY_TABLES), ' '),
				NULLIF(NVL(p_Changelog_Fkey_Columns, CHANGELOG_FKEY_COLUMNS), ' '),
				NULLIF(NVL(p_Excluded_Changelog_Blob_Cols, EXCLUDED_CHANGELOG_BLOB_COLS), ' '),
				NULLIF(NVL(p_Excluded_Changelog_Cols, EXCLUDED_CHANGELOG_COLS), ' '),
				NULLIF(NVL(p_Reference_Description_Cols, REFERENCE_DESCRIPTION_COLS), ' '),
				NULLIF(NVL(p_Copy_Before_Image, COPY_BEFORE_IMAGE), ' '),
				NULLIF(NVL(p_Base_Table_Ext, BASE_TABLE_EXT), ' '),
				NULLIF(NVL(p_Changelog_View_Ext, CHANGELOG_VIEW_EXT), ' '),
				NULLIF(NVL(p_History_View_Ext, HISTORY_VIEW_EXT), ' '),
				NULLIF(NVL(p_Table_App_Users, TABLE_APP_USERS), ' '),
				NULLIF(NVL(p_Use_Audit_Info_Columns, USE_AUDIT_INFO_COLUMNS), ' '),
				NULLIF(NVL(p_Drop_Audit_Info_Columns, DROP_AUDIT_INFO_COLUMNS), ' '),
				NULLIF(NVL(p_Use_Audit_Info_Trigger, USE_AUDIT_INFO_TRIGGER), ' '),
				NULLIF(NVL(p_Use_Change_Log, USE_CHANGE_LOG), ' '),
				NULLIF(NVL(p_Add_Column_Workspace, ADD_COLUMN_WORKSPACE_ID), ' '),
				NULLIF(NVL(p_Add_Column_Delete_Mark, ADD_COLUMN_DELETE_MARK), ' '),
				NULLIF(NVL(p_Add_Column_Modify_Date, ADD_COLUMN_MODIFY_DATE), ' '),
				NULLIF(NVL(p_Add_Column_Modify_User, ADD_COLUMN_MODIFY_USER), ' '),
				NULLIF(NVL(p_Add_Column_Creation_Date, ADD_COLUMN_CREATION_DATE), ' '),
				NULLIF(NVL(p_Add_Column_Creation_User, ADD_COLUMN_CREATION_USER), ' '),
				NULLIF(NVL(p_Enforce_Not_Null, ENFORCE_NOT_NULL), ' '),
				NULLIF(NVL(p_Add_Insert_Trigger, ADD_INSERT_TRIGGER), ' '),
				NULLIF(NVL(p_Add_Delete_Trigger, ADD_DELETE_TRIGGER), ' '),
				NULLIF(NVL(p_Add_Update_Trigger1, ADD_UPDATE_TRIGGER1), ' '),
				NULLIF(NVL(p_Add_Update_Trigger2, ADD_UPDATE_TRIGGER2), ' '),
				NULLIF(NVL(p_Add_Application_Schema, ADD_APPLICATION_SCHEMA), ' '),
				NULLIF(NVL(p_Add_ChangeLop_Views, ADD_CHANGELOG_VIEWS), ' '),
				NULLIF(NVL(p_Use_On_Null_Defaults, USE_ON_NULL_DEFAULTS), ' '),
				NULLIF(NVL(p_Use_Sequences, USE_SEQUENCES), ' '),
				NULLIF(NVL(p_Include_External_Objects, INCLUDE_EXTERNAL_OBJECTS), ' '),
				NULLIF(NVL(p_Included_WorkspaceID_Pattern, INCLUDED_WORKSPACEID_PATTERN), ' '),
				NULLIF(NVL(p_Excluded_WorkspaceID_Pattern, EXCLUDED_WORKSPACEID_PATTERN), ' '),
				NULLIF(NVL(p_Included_Delete_Mark_Pattern, INCLUDED_DELETE_MARK_PATTERN), ' '),
				NULLIF(NVL(p_EXcluded_Delete_Mark_Pattern, EXCLUDED_DELETE_MARK_PATTERN), ' '),
				NULLIF(NVL(p_Included_Timestamp_Pattern, INCLUDED_TIMESTAMP_PATTERN), ' '),
				NULLIF(NVL(p_Excluded_Timestamp_Pattern, EXCLUDED_TIMESTAMP_PATTERN), ' '),
				NULLIF(NVL(p_Column_Workspace, COLUMN_WORKSPACE), ' '),
				NULLIF(NVL(p_Column_Create_User, COLUMN_CREATE_USER), ' '),
				NULLIF(NVL(p_Column_Create_Date, COLUMN_CREATE_DATE), ' '),
				NULLIF(NVL(p_Column_Modify_User, COLUMN_MODIFY_USER), ' '),
				NULLIF(NVL(p_Column_Modify_Date, COLUMN_MODIFY_DATE), ' '),
				NULLIF(NVL(p_Column_Deleted_Mark, COLUMN_DELETED_MARK), ' '),
				NULLIF(NVL(p_Column_Index_Format, COLUMN_INDEX_FORMAT), ' '),
				NULLIF(NVL(p_Datatype_Modify_User, DATATYPE_MODIFY_USER), ' '),
				NULLIF(NVL(p_Columntype_Modify_User, COLUMNTYPE_MODIFY_USER), ' '),
				NULLIF(NVL(p_Is_Foreign_Key_Modify_User, IS_FOREIGN_KEY_MODIFY_USER), ' '),
				NULLIF(NVL(p_Function_Modify_User, FUNCTION_MODIFY_USER), ' '),
				NULLIF(NVL(p_Function_Modify_Date, FUNCTION_MODIFY_DATE), ' '),
				NULLIF(NVL(p_Datatype_Modify_Date, DATATYPE_MODIFY_DATE), ' '),
				NULLIF(NVL(p_Datatype_Modify_Date_Alt, DATATYPE_MODIFY_DATE_ALT), ' '),
				NULLIF(NVL(p_Datatype_Deleted_Mark, DATATYPE_DELETED_MARK), ' '),
				NULLIF(NVL(p_Columntype_Deleted_Mark, COLUMNTYPE_DELETED_MARK), ' '),
				NULLIF(NVL(p_Default_Deleted_Mark, DEFAULT_DELETED_MARK), ' '),
				NULLIF(NVL(p_Sequence_Ext, SEQUENCE_EXT), ' '),
				NULLIF(NVL(p_Sequence_Column_Ext, SEQUENCE_COLUMN_EXT), ' '),
				NULLIF(NVL(p_Sequence_Constraint_Ext, SEQUENCE_CONSTRAINT_EXT), ' '),
				NULLIF(NVL(p_Sequence_Options, SEQUENCE_OPTIONS), ' '),
				NULLIF(NVL(p_Interrim_Table_Ext, INTERRIM_TABLE_EXT), ' '),
				NULLIF(NVL(p_Change_Log_Trigger_Prefix, CHANGE_LOG_TRIGGER_PREFIX), ' '),
				NULLIF(NVL(p_Change_Log_Trigger_Ext, CHANGE_LOG_TRIGGER_EXT), ' '),
				NULLIF(NVL(p_Bi_Trigger_Prefix, BI_TRIGGER_PREFIX), ' '),
				NULLIF(NVL(p_Bi_Trigger_Ext, BI_TRIGGER_EXT), ' '),
				NULLIF(NVL(p_Bu_Trigger_Prefix, BU_TRIGGER_PREFIX), ' '),
				NULLIF(NVL(p_Bu_Trigger_Ext, BU_TRIGGER_EXT), ' '),
				NULLIF(NVL(p_Ins_Trigger_Prefix, INS_TRIGGER_PREFIX), ' '),
				NULLIF(NVL(p_Ins_Trigger_Ext, INS_TRIGGER_EXT), ' '),
				NULLIF(NVL(p_Del_Trigger_Prefix, DEL_TRIGGER_PREFIX), ' '),
				NULLIF(NVL(p_Del_Trigger_Ext, DEL_TRIGGER_EXT), ' '),
				NULLIF(NVL(p_Upd_Trigger_Prefix, UPD_TRIGGER_PREFIX), ' '),
				NULLIF(NVL(p_Upd_Trigger_Ext, UPD_TRIGGER_EXT), ' ')
            FROM DUAL
        )
        WHERE D.ID = 1;
        IF SQL%NOTFOUND THEN
            INSERT INTO CHANGE_LOG_CONFIG (
                INCLUDED_CHANGELOG_PATTERN, EXCLUDED_CHANGELOG_PATTERN, CHANGELOG_FKEY_TABLES, CHANGELOG_FKEY_COLUMNS,
                EXCLUDED_CHANGELOG_BLOB_COLS, EXCLUDED_CHANGELOG_COLS, REFERENCE_DESCRIPTION_COLS, COPY_BEFORE_IMAGE,
                BASE_TABLE_EXT, CHANGELOG_VIEW_EXT, HISTORY_VIEW_EXT, TABLE_APP_USERS,
                USE_AUDIT_INFO_COLUMNS, DROP_AUDIT_INFO_COLUMNS, USE_AUDIT_INFO_TRIGGER, USE_CHANGE_LOG,
                ADD_COLUMN_WORKSPACE_ID, ADD_COLUMN_DELETE_MARK,
				ADD_COLUMN_MODIFY_DATE, ADD_COLUMN_MODIFY_USER, ADD_COLUMN_CREATION_DATE, ADD_COLUMN_CREATION_USER,
				ENFORCE_NOT_NULL, ADD_INSERT_TRIGGER, ADD_DELETE_TRIGGER, ADD_UPDATE_TRIGGER1, ADD_UPDATE_TRIGGER2,
				ADD_APPLICATION_SCHEMA, ADD_CHANGELOG_VIEWS,
                USE_ON_NULL_DEFAULTS, USE_SEQUENCES, INCLUDE_EXTERNAL_OBJECTS,
                INCLUDED_WORKSPACEID_PATTERN, EXCLUDED_WORKSPACEID_PATTERN,
                INCLUDED_DELETE_MARK_PATTERN, EXCLUDED_DELETE_MARK_PATTERN,
                INCLUDED_TIMESTAMP_PATTERN, EXCLUDED_TIMESTAMP_PATTERN,
                COLUMN_WORKSPACE, COLUMN_CREATE_USER, COLUMN_CREATE_DATE, COLUMN_MODIFY_USER, COLUMN_MODIFY_DATE,
                COLUMN_DELETED_MARK, COLUMN_INDEX_FORMAT,
                DATATYPE_MODIFY_USER, COLUMNTYPE_MODIFY_USER, IS_FOREIGN_KEY_MODIFY_USER,
                FUNCTION_MODIFY_USER, FUNCTION_MODIFY_DATE, DATATYPE_MODIFY_DATE, DATATYPE_MODIFY_DATE_ALT,
                DATATYPE_DELETED_MARK, COLUMNTYPE_DELETED_MARK, DEFAULT_DELETED_MARK,
                SEQUENCE_EXT, SEQUENCE_COLUMN_EXT, SEQUENCE_CONSTRAINT_EXT, SEQUENCE_OPTIONS,
                INTERRIM_TABLE_EXT, CHANGE_LOG_TRIGGER_PREFIX, CHANGE_LOG_TRIGGER_EXT,
            	BI_TRIGGER_PREFIX, BI_TRIGGER_EXT, BU_TRIGGER_PREFIX, BU_TRIGGER_EXT,
            	INS_TRIGGER_PREFIX, INS_TRIGGER_EXT, DEL_TRIGGER_PREFIX, DEL_TRIGGER_EXT, UPD_TRIGGER_PREFIX, UPD_TRIGGER_EXT)
            VALUES (
                p_Included_Changelog_Pattern,
                p_Excluded_Changelog_Pattern,
                p_Changelog_Fkey_Tables,
                p_Changelog_Fkey_Columns,
                p_Excluded_Changelog_Blob_Cols,
                p_Excluded_Changelog_Cols,
                p_Reference_Description_Cols,
                p_Copy_Before_Image,
                p_Base_Table_Ext,
                p_Changelog_View_Ext,
                p_History_View_Ext,
                p_Table_App_Users,
                p_Use_Audit_Info_Columns,
                p_Drop_Audit_Info_Columns,
                p_Use_Audit_Info_Trigger,
                p_Use_Change_Log,
                p_Add_Column_Workspace,
                p_Add_Column_Delete_Mark,

				p_Add_Column_Modify_Date,
				p_Add_Column_Modify_User,
				p_Add_Column_Creation_Date,
				p_Add_Column_Creation_User,
				p_Enforce_Not_Null,
				p_Add_Insert_Trigger,
				p_Add_Delete_Trigger,
				p_Add_Update_Trigger1,
				p_Add_Update_Trigger2,
				p_Add_Application_Schema,
				p_Add_ChangeLop_Views,

                p_Use_On_Null_Defaults,
                p_Use_Sequences,
                p_Include_External_Objects,
                p_Included_WorkspaceID_Pattern,
                p_Excluded_WorkspaceID_Pattern,
				p_Included_Delete_Mark_Pattern,
				p_EXcluded_Delete_Mark_Pattern,
                p_Included_Timestamp_Pattern,
                p_Excluded_Timestamp_Pattern,
                p_Column_Workspace,
                p_Column_Create_User,
                p_Column_Create_Date,
                p_Column_Modify_User,
                p_Column_Modify_Date,
                p_Column_Deleted_Mark,
                p_Column_Index_Format,
                p_Datatype_Modify_User,
                p_Columntype_Modify_User,
                p_Is_Foreign_Key_Modify_User,
                p_Function_Modify_User,
                p_Function_Modify_Date,
                p_Datatype_Modify_Date,
                p_Datatype_Modify_Date_Alt,
                p_Datatype_Deleted_Mark,
                p_Columntype_Deleted_Mark,
                p_Default_Deleted_Mark,
                p_Sequence_Ext,
                p_Sequence_Column_Ext,
                p_Sequence_Constraint_Ext,
                p_Sequence_Options,
                p_Interrim_Table_Ext,
                p_Change_Log_Trigger_Ext,
                p_Change_Log_Trigger_Ext,
                p_Bi_Trigger_Prefix,
                p_Bi_Trigger_Ext,
                p_Bu_Trigger_Prefix,
                p_Bu_Trigger_Ext,
                p_Ins_Trigger_Prefix,
                p_Ins_Trigger_Ext,
                p_Del_Trigger_Prefix,
                p_Del_Trigger_Ext,
                p_Upd_Trigger_Prefix,
                p_Upd_Trigger_Ext
            );
        END IF;
        COMMIT;
        custom_changelog.Load_Config;
        changelog_conf.Load_Config;

    END;

	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ', '
	)
    RETURN VARCHAR2 DETERMINISTIC
    IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
    BEGIN
    	RETURN
			case when p_First_Name IS NOT NULL and p_Second_Name IS NOT NULL
			then p_First_Name || p_Delimiter || p_Second_Name
			when p_First_Name IS NOT NULL
			then p_First_Name
			else p_Second_Name
			end;
    END;

    FUNCTION Get_Context_Workspace_Name RETURN VARCHAR2
	IS
	BEGIN
		RETURN NVL(APEX_UTIL.GET_SESSION_STATE(g_Workspace_Item), SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));
	END;

    FUNCTION Get_Current_Workspace_ID RETURN USER_NAMESPACES.WORKSPACE$_ID%TYPE
    IS
        v_Workspace_ID      NUMBER;
		v_Workspace_Name USER_NAMESPACES.WORKSPACE_NAME%TYPE := Get_Context_Workspace_Name;
    BEGIN
        SELECT WORKSPACE$_ID INTO v_Workspace_ID 
        FROM USER_NAMESPACES 
        WHERE WORKSPACE_NAME = v_Workspace_Name;
        
        RETURN v_Workspace_ID;
    END;
    	
	PROCEDURE Set_Current_Workspace (
   		p_Workspace_Name	IN VARCHAR2
   	)
   	IS 
		v_Workspace_Name USER_NAMESPACES.WORKSPACE_NAME%TYPE := UPPER(p_Workspace_Name);
   	BEGIN
   		APEX_UTIL.SET_SESSION_STATE(g_Workspace_Item, v_Workspace_Name);
   	END;
   	
	PROCEDURE Set_New_Workspace (
   		p_Workspace_Name	IN VARCHAR2
   	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Workspace_Id NUMBER := NULL;
		v_Workspace_Name USER_NAMESPACES.WORKSPACE_NAME%TYPE := UPPER(p_Workspace_Name);
	BEGIN
        SELECT WORKSPACE$_ID INTO v_Workspace_ID 
        FROM USER_NAMESPACES 
        WHERE WORKSPACE_NAME = v_Workspace_Name;
		APEX_UTIL.SET_SESSION_STATE(g_Workspace_Item, v_Workspace_Name);
		COMMIT;
	EXCEPTION
	WHEN NO_DATA_FOUND THEN
		INSERT INTO USER_NAMESPACES (WORKSPACE_NAME) VALUES(v_Workspace_Name);
		APEX_UTIL.SET_SESSION_STATE(g_Workspace_Item, v_Workspace_Name);
		COMMIT;
	END;


    FUNCTION Get_Current_User_Name RETURN VARCHAR2
    IS
    BEGIN
    	RETURN NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
    END;

    FUNCTION Get_ChangeLogTable RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogTable; END;
    FUNCTION Get_ChangeLogFunction RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogFunction; END;
    FUNCTION Get_ChangeLogFinishFunction RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogFinishFunction; END;
    FUNCTION Get_ChangeLogFlushFunction RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogFlushFunction; END;
    FUNCTION Get_AltChangeLogFunction RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_AltChangeLogFunction; END;
    FUNCTION Get_ChangeLogViewExt RETURN VARCHAR2 IS BEGIN RETURN g_ChangeLogViewExt; END;
    FUNCTION Get_ChangeLogViewName(p_Name VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN p_Name || g_ChangeLogViewExt; END;
    FUNCTION Get_HistoryViewExt RETURN VARCHAR2 IS BEGIN RETURN g_HistoryViewExt; END;
    FUNCTION Get_HistoryViewName(p_Name VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN p_Name || g_HistoryViewExt; END;
    FUNCTION Get_ChangeLogFKeyTables RETURN VARCHAR2 IS BEGIN RETURN g_ChangeLogFKeyTables; END;
    FUNCTION Get_ChangeLogFKeyColumns RETURN VARCHAR2 IS BEGIN RETURN g_ChangeLogFKeyColumns; END;
    FUNCTION Get_IncludeChangeLogPattern RETURN VARCHAR2 IS BEGIN RETURN g_IncludeChangeLogPattern; END;
    FUNCTION Get_ExcludeChangeLogPattern RETURN VARCHAR2 IS BEGIN RETURN Concat_List(g_ExcludeChangeLogPattern, c_ExcludeChangeLogPattern); END;
    FUNCTION Get_ExcludeChangeLogBlobCols RETURN VARCHAR2 IS BEGIN RETURN g_ExcludeChangeLogBlobCols; END;
    FUNCTION Get_ReferenceDescriptionCols RETURN VARCHAR2 IS BEGIN RETURN g_ReferenceDescriptionCols; END;
    FUNCTION Get_ExcludeChangeLogCols RETURN VARCHAR2 IS BEGIN RETURN g_ExcludeChangeLogCols; END;

	FUNCTION Has_ChangeLog_History (p_Table_Name VARCHAR2) RETURN VARCHAR2
    IS
    	v_INCLUDED VARCHAR2(10);
    BEGIN
        SELECT INCLUDED INTO v_INCLUDED
        FROM CHANGE_LOG_TABLES
		WHERE p_Table_Name IN (TABLE_NAME, VIEW_NAME);
		RETURN case when v_INCLUDED = 'N' then 'NO' else 'YES' end;
	EXCEPTION
	WHEN NO_DATA_FOUND THEN
		return 'NO';
    END;

    FUNCTION Enquote_Column_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when INSTR(p_Name, ' ') > 0 then DBMS_ASSERT.ENQUOTE_NAME(str => p_Name, capitalize => FALSE) else p_Name end;
    END;

    FUNCTION Get_ChangeLogAddColFunction (
        p_DATA_TYPE VARCHAR2,
        p_DATA_SCALE NUMBER,
        p_CHAR_LENGTH NUMBER,
        p_COLUMN_NAME VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN CASE
        WHEN p_DATA_TYPE = 'RAW' THEN
            'custom_changelog.AddLogRawCols'
        WHEN p_DATA_TYPE LIKE 'TIMESTAMP%' THEN
            'custom_changelog.AddLogTSCols'
        ELSE
            'custom_changelog.AddLogCols'
        END;
    END;

    PROCEDURE ResetLog IS
    BEGIN
        ChangeLogA.delete();
        ChangeLogB.delete();

        g_idxa := 0;
        g_idya := 0;
        g_idxb := 0;
        g_idyb := 0;
    END;

    PROCEDURE EnableLog IS
    BEGIN
        g_ChangeLogEnabled := TRUE;
        ResetLog;
    END;

    PROCEDURE DisableLog IS
    BEGIN
        g_ChangeLogEnabled := FALSE;
        ResetLog;
    END;

    PROCEDURE FlushLog IS
        n CONSTANT PLS_INTEGER := ChangeLogA.count();
        m CONSTANT PLS_INTEGER := ChangeLogB.count();
    BEGIN
        if g_ChangeLogEnabled then
            FORALL i IN 1..m
                INSERT INTO CHANGE_LOG_BT VALUES ChangeLogB(i);

            FORALL i IN 1..n
                INSERT INTO CHANGE_LOG_BT VALUES ChangeLogA(i);
            ResetLog;
        end if;
    END FlushLog;

    PROCEDURE FinishLog IS
    BEGIN
        -- when no changed values have been collected in an update statment ignore the log entry
        if g_idxa > 0 and ChangeLogA(g_idxa).ACTION_CODE = 'U' and ChangeLogA(g_idxa).CHANGELOG_ITEMS.count() = 1 then
            ChangeLogA.delete(g_idxa);
            g_idxa := g_idxa - 1;
        end if;
        -- when limit is reached, flush the collection
        if g_idxa >= g_flush_threshhold then
            FlushLog();
        end if;
    END FinishLog;

    PROCEDURE AddLog (
        p_Table_Name     IN VARCHAR2,
        p_Object_ID      IN CHANGE_LOG_BT.OBJECT_ID%TYPE,
        p_InsertDate     IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_Deleted_Mark   IN VARCHAR2 DEFAULT NULL,
        p_WORKSPACE_ID   IN CHANGE_LOG_BT.WORKSPACE$_ID%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID1 IN CHANGE_LOG_BT.CUSTOM_REF_ID1%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID2 IN CHANGE_LOG_BT.CUSTOM_REF_ID2%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID3 IN CHANGE_LOG_BT.CUSTOM_REF_ID3%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID4 IN CHANGE_LOG_BT.CUSTOM_REF_ID4%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID5 IN CHANGE_LOG_BT.CUSTOM_REF_ID5%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID6 IN CHANGE_LOG_BT.CUSTOM_REF_ID6%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID7 IN CHANGE_LOG_BT.CUSTOM_REF_ID7%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID8 IN CHANGE_LOG_BT.CUSTOM_REF_ID8%TYPE DEFAULT NULL,
        p_CUSTOM_REF_ID9 IN CHANGE_LOG_BT.CUSTOM_REF_ID9%TYPE DEFAULT NULL
    )
    IS
        v_ChangeLogIDA  PLS_INTEGER := 0;
        v_ChangeLogIDB  PLS_INTEGER := 0;
        v_Action        CHANGE_LOG_BT.ACTION_CODE%TYPE;
        v_Workspace_ID  CHANGE_LOG_BT.WORKSPACE$_ID%TYPE := p_WORKSPACE_ID;
        v_User_ID       CHANGE_LOG_BT.USER_ID%TYPE;
        v_Table_ID      CHANGE_LOG_BT.TABLE_ID%TYPE;
    BEGIN -- Head:  ID, OBJECT_ID, TABLE_NAME, ACTION_CODE, USER_ID, LOGGING_DATE, CUSTOM_REF_ID1, ...
        if g_ChangeLogEnabled then
            if v_Workspace_ID IS NULL then
                v_Workspace_ID := custom_changelog.Get_Current_Workspace_ID;
            end if;
            v_Action    := case when DELETING or p_Deleted_Mark IS NOT NULL then 'D'
                                when INSERTING then 'I' 
                                when UPDATING then 'U'
                                else 'S' end;
            v_User_ID   := custom_changelog.Changelog_User_ID(custom_changelog.Get_Current_User_Name, v_Workspace_ID);
            v_Table_ID  := custom_changelog.Changelog_Table_ID(p_Table_Name);
            g_idxa := g_idxa + 1;
            g_idya := 0;
            g_ChangeLogInsCnt := 1;
            SELECT CHANGELOG_SEQ.NEXTVAL INTO v_ChangeLogIDA FROM DUAL;
            ChangeLogA(g_idxa).ID               := v_ChangeLogIDA;
            ChangeLogA(g_idxa).OBJECT_ID        := p_Object_ID;
            ChangeLogA(g_idxa).TABLE_ID         := v_Table_ID;
            ChangeLogA(g_idxa).LOGGING_DATE     := CURRENT_TIMESTAMP;
            ChangeLogA(g_idxa).WORKSPACE$_ID    := v_Workspace_ID;
            ChangeLogA(g_idxa).USER_ID          := v_User_ID;
            ChangeLogA(g_idxa).IS_HIDDEN        := '0';
            ChangeLogA(g_idxa).ACTION_CODE      := v_Action;
            ChangeLogA(g_idxa).CUSTOM_REF_ID1   := p_CUSTOM_REF_ID1;
            ChangeLogA(g_idxa).CUSTOM_REF_ID2   := p_CUSTOM_REF_ID2;
            ChangeLogA(g_idxa).CUSTOM_REF_ID3   := p_CUSTOM_REF_ID3;
            ChangeLogA(g_idxa).CUSTOM_REF_ID4   := p_CUSTOM_REF_ID4;
            ChangeLogA(g_idxa).CUSTOM_REF_ID5   := p_CUSTOM_REF_ID5;
            ChangeLogA(g_idxa).CUSTOM_REF_ID6   := p_CUSTOM_REF_ID6;
            ChangeLogA(g_idxa).CUSTOM_REF_ID7   := p_CUSTOM_REF_ID7;
            ChangeLogA(g_idxa).CUSTOM_REF_ID8   := p_CUSTOM_REF_ID8;
            ChangeLogA(g_idxa).CUSTOM_REF_ID9   := p_CUSTOM_REF_ID9;
            ChangeLogA(g_idxa).CHANGELOG_ITEMS  := CHANGELOG_ITEM_ARRAY_GTYPE(NULL);

            if v_Action = 'U' and g_ChangeLogCopyBeforeImage THEN
                SELECT COUNT(*) INTO g_ChangeLogInsCnt
                FROM CHANGE_LOG_BT
                WHERE WORKSPACE$_ID = v_Workspace_ID
                AND OBJECT_ID = p_Object_ID
                AND TABLE_ID = v_Table_ID
                AND ACTION_CODE = 'I';
                -- Copy before image of row to CHANGE_LOG_BT when no row for insert exists
                if g_ChangeLogInsCnt = 0 THEN
                    g_idxb := g_idxb + 1;
                    g_idyb := 0;
                    SELECT CHANGELOG_SEQ.NEXTVAL INTO v_ChangeLogIDB FROM DUAL;
                    ChangeLogB(g_idxb)              := ChangeLogA(g_idxa);
                    ChangeLogB(g_idxb).ID           := v_ChangeLogIDB;
                    ChangeLogB(g_idxb).LOGGING_DATE := p_InsertDate;
                    ChangeLogB(g_idxb).ACTION_CODE      := 'I';
                end if;
            end if;
        end if;
    END AddLog;

    PROCEDURE Int_AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN VARCHAR2,
        p_After       IN VARCHAR2
    )
    IS
    BEGIN
        if g_ChangeLogEnabled then
            -- column calue is changed
            if NVL(p_Bevore, CHR(1)) <> NVL(p_After, CHR(1)) then
                g_idya := g_idya + 1;
                ChangeLogA(g_idxa).CHANGELOG_ITEMS.EXTEND;
                ChangeLogA(g_idxa).CHANGELOG_ITEMS(g_idya) := CHANGELOG_ITEM_GTYPE(p_Column_ID, p_After);
            end if;
            -- collect non null values of before image for updated rows then no copy exist in the log table
            if p_Bevore IS NOT NULL and ChangeLogA(g_idxa).ACTION_CODE = 'U' and g_ChangeLogInsCnt = 0 then
                g_idyb := g_idyb + 1;
                ChangeLogB(g_idxb).CHANGELOG_ITEMS.EXTEND;
                ChangeLogB(g_idxb).CHANGELOG_ITEMS(g_idyb) := CHANGELOG_ITEM_GTYPE(p_Column_ID, p_Bevore);
            end if;
        end if;
    END Int_AddLogCols;

    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN VARCHAR2,
        p_After       IN VARCHAR2
    )
    IS
    BEGIN
        Int_AddLogCols(p_Column_ID,
            SUBSTRB(p_Bevore, 1, g_ChangeLogTextLimit),
            SUBSTRB(p_After, 1, g_ChangeLogTextLimit));
    END AddLogCols;

    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN CLOB,
        p_After       IN CLOB
    )
    IS
    BEGIN
        Int_AddLogCols(p_Column_ID,
            SUBSTRB(p_Bevore, 1, g_ChangeLogTextLimit),
            SUBSTRB(p_After, 1, g_ChangeLogTextLimit));
    END AddLogCols;

    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN NUMBER,
        p_After       IN NUMBER
    )
    IS
    BEGIN
		Int_AddLogCols(p_Column_ID, LTRIM(TO_CHAR(p_Bevore, g_ChangeLogNumberFormat, g_ChangeLogCurrNumChars)), LTRIM(TO_CHAR(p_After, g_ChangeLogNumberFormat, g_ChangeLogCurrNumChars)));
    END AddLogCols;

    PROCEDURE AddLogRawCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN RAW,
        p_After       IN RAW
    )
    IS
    BEGIN
        Int_AddLogCols(p_Column_ID,
            RAWTOHEX(p_Bevore),
            RAWTOHEX(p_After));
    END AddLogRawCols;

    PROCEDURE AddLogCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN DATE,
        p_After       IN DATE
    )
    IS
    BEGIN
        Int_AddLogCols(p_Column_ID, TO_CHAR(p_Bevore, g_ChangeLogDateFormat), TO_CHAR(p_After, g_ChangeLogDateFormat));
    END AddLogCols;

    PROCEDURE AddLogTSCols (
        p_Column_ID   IN INTEGER,
        p_Bevore      IN TIMESTAMP WITH LOCAL TIME ZONE,
        p_After       IN TIMESTAMP WITH LOCAL TIME ZONE
    )
    IS
    BEGIN
        Int_AddLogCols(p_Column_ID, TO_CHAR(p_Bevore, g_ChangeLogTimestampFormat), TO_CHAR(p_After, g_ChangeLogTimestampFormat));
    END AddLogTSCols;

    FUNCTION Changelog_Key_Value (
        p_After         IN VARCHAR2,
        p_Table_Name    IN VARCHAR2,
        p_Key_Name      IN VARCHAR2,
        p_Primary_Key_Cols IN VARCHAR2
    )
    RETURN VARCHAR2
    IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
        stat_cur            SYS_REFCURSOR;
        v_Stat1             VARCHAR2(400);
        v_Wert              VARCHAR2(4000)  := p_After;
    BEGIN
        IF p_Key_Name IS NOT NULL AND p_After IS NOT NULL THEN
            v_Stat1 := 'SELECT ' ||  REPLACE(p_Key_Name, ',', ' ||''/''|| ')
            || ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name)
            || ' WHERE ' || Enquote_Column_Name(p_Primary_Key_Cols) || ' = :s';
            -- DBMS_OUTPUT.PUT_LINE('Changelog_Key_Value ' || v_Stat1);
            BEGIN
                OPEN  stat_cur FOR v_Stat1 USING v_Wert;
                FETCH stat_cur INTO v_Wert;
                CLOSE stat_cur;
            EXCEPTION
            WHEN others THEN
                NULL;
            END;
        END IF;
        RETURN v_Wert;
    END;


    -- returns the Column_Name of a Changelog entry
    FUNCTION Changelog_Column_Name (
        p_Table_Name    IN VARCHAR2,
        p_Column_ID    IN INTEGER
    )
    RETURN VARCHAR2 DETERMINISTIC
    IS
        v_Column_Name   VARCHAR2(50);
    BEGIN
        SELECT COLUMN_NAME -- wird in schema XXX_APP_USER nicht gefunden
        INTO v_Column_Name
        FROM USER_TAB_COLUMNS
        WHERE TABLE_NAME = p_Table_Name
        AND COLUMN_ID = p_Column_ID;

        RETURN v_Column_Name;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;

    PROCEDURE Changelog_Tables_Init (
        p_Source_View_Name IN VARCHAR2 DEFAULT 'MVBASE_VIEWS'
    )
    IS
        v_Stat VARCHAR2(4000) :=
        q'[MERGE INTO CHANGE_LOG_TABLES D
        USING ( SELECT TABLE_NAME, NVL(VIEW_NAME, TABLE_NAME) VIEW_NAME, 
        			case when INCLUDE_CHANGELOG = 'YES' and HAS_SCALAR_PRIMARY_KEY = 'YES' then 'Y' else 'N' end INCLUDED 
        		FROM ]'
        	|| DBMS_ASSERT.ENQUOTE_NAME(p_Source_View_Name) || ' ) S
            ON (D.VIEW_NAME = S.VIEW_NAME)
        WHEN MATCHED THEN
            UPDATE SET D.TABLE_NAME = S.TABLE_NAME,
            		D.INCLUDED = S.INCLUDED
         WHEN NOT MATCHED THEN
            INSERT (D.TABLE_NAME, D.VIEW_NAME, D.INCLUDED)
            VALUES (S.TABLE_NAME, S.VIEW_NAME, S.INCLUDED)';
    BEGIN
    	-- DBMS_OUTPUT.PUT_LINE(v_Stat);
        EXECUTE IMMEDIATE v_Stat;
        DBMS_OUTPUT.PUT_LINE('-- Changelog_Tables_Init added ' || TO_CHAR(SQL%ROWCOUNT) || ' rows');
        COMMIT;
    END;

    FUNCTION Changelog_Table_ID (
        p_Table_Name    IN VARCHAR2
    )
    RETURN INTEGER DETERMINISTIC
    IS PRAGMA AUTONOMOUS_TRANSACTION;
        v_Table_ID      INTEGER;
        v_Table_Cnt     INTEGER;
        v_Table_Name    VARCHAR2(50) := UPPER(p_Table_Name);
        v_Short_Name 	VARCHAR2(50);
        v_View_Name     VARCHAR2(50);
    BEGIN
        SELECT ID
        INTO v_Table_ID
        FROM CHANGE_LOG_TABLES
        WHERE VIEW_NAME = v_Table_Name;
        COMMIT;

        RETURN v_Table_ID;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        v_View_Name     := v_Table_Name;
        v_Short_Name	:= RTRIM(SUBSTR(v_Table_Name, 1, 26), '_');
        v_Table_Name    := changelog_conf.Get_Base_Table_Name(v_Short_Name);
        SELECT COUNT(*)
        INTO v_Table_Cnt
        FROM USER_TABLES
        WHERE TABLE_NAME = v_Table_Name;

        IF v_Table_Cnt = 0 THEN
            v_Table_Name := v_View_Name;
        END IF;

        INSERT INTO CHANGE_LOG_TABLES (TABLE_NAME, VIEW_NAME)
        VALUES (v_Table_Name, v_View_Name)
        RETURNING (ID) INTO v_Table_ID;
        COMMIT;
        RETURN v_Table_ID;
    END;

    FUNCTION Changelog_User_ID (
        p_User_Name    IN VARCHAR2,
        p_Workspace_Id IN INTEGER
    )
    RETURN CHANGE_LOG_USERS_BT.ID%TYPE DETERMINISTIC
    IS PRAGMA AUTONOMOUS_TRANSACTION;
        v_User_ID    CHANGE_LOG_USERS_BT.ID%TYPE;
    BEGIN
        SELECT ID
        INTO v_User_ID
        FROM CHANGE_LOG_USERS_BT
        WHERE USER_NAME = UPPER(p_User_Name)
        AND WORKSPACE$_ID = p_WORKSPACE_ID;
        COMMIT;

        RETURN v_User_ID;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        INSERT INTO CHANGE_LOG_USERS_BT (USER_NAME, WORKSPACE$_ID)
        VALUES (UPPER(p_User_Name), p_WORKSPACE_ID)
        RETURNING (ID) INTO v_User_ID;
        COMMIT;
        RETURN v_User_ID;
    END;

    -- returns the Column_ID of a Changelog entry
    FUNCTION Changelog_Column_ID (
        p_Table_Name    IN VARCHAR2,
        p_Column_Name   IN VARCHAR2
    )
    RETURN INTEGER DETERMINISTIC
    IS
        v_Column_ID    INTEGER;
    BEGIN
        SELECT COLUMN_ID
        INTO v_Column_ID
        FROM USER_TAB_COLUMNS
        WHERE TABLE_NAME = p_Table_Name
        AND COLUMN_NAME = p_Column_Name;

        RETURN v_Column_ID;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;

    FUNCTION Compare_Blob ( p_Old_Blob BLOB, p_New_Blob BLOB)  RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
        RETURN p_Old_Blob IS NOT NULL AND p_New_Blob IS NULL
            OR p_Old_Blob IS NULL AND p_New_Blob IS NOT NULL
            OR p_Old_Blob IS NOT NULL AND p_New_Blob IS NOT NULL
                AND DBMS_LOB.COMPARE (p_Old_Blob, p_New_Blob) != 0;
    END;

    FUNCTION Compare_Clob ( p_Old_Blob CLOB, p_New_Blob CLOB) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
        RETURN p_Old_Blob IS NOT NULL AND p_New_Blob IS NULL
            OR p_Old_Blob IS NULL AND p_New_Blob IS NOT NULL
            OR p_Old_Blob IS NOT NULL AND p_New_Blob IS NOT NULL
                AND DBMS_LOB.COMPARE (p_Old_Blob, p_New_Blob) != 0;
    END;

    FUNCTION Compare_Long ( p_Old_Blob LONG, p_New_Blob LONG) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
        RETURN p_Old_Blob IS NOT NULL AND p_New_Blob IS NULL
            OR p_Old_Blob IS NULL AND p_New_Blob IS NOT NULL
            OR p_Old_Blob IS NOT NULL AND p_New_Blob IS NOT NULL
            	AND p_Old_Blob != p_New_Blob;
    END;

$IF changelog_conf.g_Use_ORDIMAGE $THEN
    FUNCTION Compare_ORDIMAGE (
        p_Old_Blob      IN ORDIMAGE,
        p_New_Blob      IN ORDIMAGE
    )
    RETURN BOOLEAN
    IS
    BEGIN
        RETURN p_Old_Blob IS NOT NULL AND p_New_Blob IS NULL
            OR p_Old_Blob IS NULL AND p_New_Blob IS NOT NULL
            OR p_Old_Blob IS NOT NULL AND p_New_Blob IS NOT NULL 
                AND DBMS_LOB.COMPARE (p_Old_Blob.GETCONTENT, p_New_Blob.GETCONTENT) != 0;
    END;
$END


    FUNCTION Get_ChangeLogTextLimit RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogTextLimit; END;



    FUNCTION GetLogNumberCols  (p_Value VARCHAR2)
    RETURN NUMBER DETERMINISTIC
    IS
    BEGIN
        RETURN TO_NUMBER(NULLIF(p_Value, chr(1)));
    EXCEPTION WHEN VALUE_ERROR THEN
        -- DBMS_OUTPUT.PUT_LINE('custom_changelog.GetLogIntegerCols (' || NULLIF(p_Value, chr(1)) || ') - failed with ' || SQLERRM);
        BEGIN
            RETURN TO_NUMBER(NULLIF(p_Value, chr(1)), g_ChangeLogCurrencyFormat, g_ChangeLogCurrNumChars);
        EXCEPTION WHEN VALUE_ERROR THEN
            RETURN TO_NUMBER(NULLIF(p_Value, chr(1)), g_AltChangeLogCurrFormat, g_ChangeLogCurrNumChars);
        END;
    WHEN OTHERS THEN
        RAISE;
    END;

    FUNCTION Get_ChangeLogCurrencyFormat RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogCurrencyFormat; END;
    FUNCTION Get_ChangeLogCurrNumChars RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN 'q''[' || g_ChangeLogCurrNumChars || ']'''; END;
    FUNCTION Get_ChangeLogDateFormat RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogDateFormat; END;
    FUNCTION Get_ChangeLogTimestampFormat RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_ChangeLogTimestampFormat; END;

    FUNCTION Get_CopyBeforeImage RETURN VARCHAR2 DETERMINISTIC
    IS BEGIN
        RETURN case when g_ChangeLogCopyBeforeImage then 'YES' else 'NO' end;
    END;

    -- remove changelog entries for removed rows
    PROCEDURE  Purge_Changelog_Rows (
        p_View_Name VARCHAR2,
        p_Primary_Key_Col VARCHAR2,
        p_Workspace_ID INTEGER,
        p_First_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    IS
        v_Stat          VARCHAR2(4000);
        v_Count         INTEGER := 0;
        v_Table_ID      CHANGE_LOG_TABLES.ID%TYPE;
        v_Table_Name    CHANGE_LOG_TABLES.TABLE_NAME%TYPE;
        v_ColumnWorkspace USER_TAB_COLUMNS.COLUMN_NAME%TYPE;
    BEGIN
        SELECT T.ID, T.TABLE_NAME, C.COLUMN_NAME
        INTO v_Table_ID, v_Table_Name, v_ColumnWorkspace
        FROM CHANGE_LOG_TABLES T
        LEFT OUTER JOIN USER_TAB_COLUMNS C ON C.TABLE_NAME = T.TABLE_NAME AND C.COLUMN_NAME = changelog_conf.Get_ColumnWorkspace
        WHERE T.VIEW_NAME = p_View_Name;

        v_Stat := 'DELETE FROM ' || custom_changelog.Get_ChangeLogTable || ' D'
                || ' WHERE TABLE_ID = :a'
                || ' AND LOGGING_DATE < :b'
                || ' AND D.' || changelog_conf.Get_ColumnWorkspace || ' = :c '
                || ' AND NOT EXISTS ( SELECT 1 FROM ' || DBMS_ASSERT.ENQUOTE_NAME(v_Table_Name) || ' S '
                || ' WHERE D.OBJECT_ID = S.' || p_Primary_Key_Col
                || case when v_ColumnWorkspace IS NOT NULL
                    then ' AND D.' || changelog_conf.Get_ColumnWorkspace || ' = S.' || v_ColumnWorkspace end
                || ')';

        EXECUTE IMMEDIATE v_Stat
            USING IN v_Table_ID, p_First_Date, p_Workspace_ID;
        v_Count := SQL%ROWCOUNT;
        COMMIT;
        if v_Count > 0 then
            DBMS_OUTPUT.PUT_LINE('-- Purged ' || v_Count || ' changelog rows from ' || p_View_Name || ' -- ');
        end if;
    END;

    PROCEDURE  Delete_Changelog_Rows ( p_View_Name VARCHAR2 )
    IS
        v_Stat          VARCHAR2(4000);
        v_Count         INTEGER := 0;
        v_Table_ID      INTEGER := custom_changelog.Changelog_Table_ID(p_View_Name);
    BEGIN
        v_Stat := 'DELETE FROM ' || custom_changelog.Get_ChangeLogTable || '  WHERE TABLE_ID = :a';

        EXECUTE IMMEDIATE v_Stat USING IN v_Table_ID;
        v_Count := SQL%ROWCOUNT;
        if v_Count > 0 then
            DBMS_OUTPUT.PUT_LINE('-- Deleted ' || v_Count || ' changelog rows from ' || p_View_Name || ' -- ');
            COMMIT;
        end if;
    END Delete_Changelog_Rows;

	-- delete change log rows for dropped tables
    PROCEDURE  Purge_Changelog_Rows 
    is
	begin
		for t_cur in (
			select * from CHANGE_LOG_TABLES s
			where not exists (
				select 1 
				from user_tables t
				where t.table_name = s.table_name
			)
		) loop 
			DBMS_OUTPUT.PUT_LINE('purging table '||t_cur.view_name||' for change log.');
			custom_changelog.Delete_Changelog_Rows(t_cur.view_name);
        	DELETE FROM CHANGE_LOG_TABLES WHERE ID = t_cur.ID;
		end loop;
	end Purge_Changelog_Rows;

	-- search timestamp used in history views
	PROCEDURE Set_Query_Timestamp (
   		p_Timestamp		IN TIMESTAMP
   	)
	IS
		v_TimestampString VARCHAR2(64);
	BEGIN
		v_TimestampString := TO_CHAR(CAST(p_Timestamp AS TIMESTAMP WITH TIME ZONE), g_CtxTimestampFormat);
		APEX_UTIL.SET_SESSION_STATE(g_Timestamp_Item, v_TimestampString);
	END;

	PROCEDURE Set_Query_Date (
   		p_DateTime		IN DATE
   	)
	IS
		v_TimestampString VARCHAR2(64);
	BEGIN
		v_TimestampString := TO_CHAR(CAST(p_DateTime AS TIMESTAMP WITH TIME ZONE) + NUMTODSINTERVAL(0.999999999, 'SECOND'), g_CtxTimestampFormat);
		APEX_UTIL.SET_SESSION_STATE(g_Timestamp_Item, v_TimestampString);
	END;

	FUNCTION Get_Query_Timestamp RETURN TIMESTAMP
	IS
	BEGIN
		RETURN NVL(TO_TIMESTAMP_TZ(APEX_UTIL.GET_SESSION_STATE(g_Timestamp_Item), g_CtxTimestampFormat), CURRENT_TIMESTAMP);
	END;

BEGIN
    custom_changelog.Load_Config;
END custom_changelog;
/
show errors

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_VIEWS WHERE VIEW_NAME = 'CHANGE_LOG_USERS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE OR REPLACE VIEW CHANGE_LOG_USERS ( ID, USER_NAME, CONSTRAINT CHANGE_LOG_USERS_VPK PRIMARY KEY (ID) RELY DISABLE)
		AS
		SELECT ID, USER_NAME
		FROM CHANGE_LOG_USERS_BT
		WHERE ( WORKSPACE$_ID = custom_changelog.Get_Current_Workspace_ID OR WORKSPACE$_ID IS NULL )
		WITH CHECK OPTION
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/

CREATE OR REPLACE VIEW CHANGE_LOG ( ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
	CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
	CHANGELOG_ITEMS )
AS
SELECT ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
	CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
	CHANGELOG_ITEMS
 FROM CHANGE_LOG_BT
 WHERE ( WORKSPACE$_ID = custom_changelog.Get_Current_Workspace_ID OR WORKSPACE$_ID IS NULL )
 WITH CHECK OPTION;

COMMENT ON TABLE CHANGE_LOG IS
		'Projection of all columns of base table CHANGE_LOG_BT, restricted to rows of the current workspace from the session context CUSTOM_CTX.';

CREATE OR REPLACE VIEW VCHANGELOG_ITEM AS
SELECT WORKSPACE$_ID, ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
	CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
	COLUMN_ID, AFTER_VALUE
FROM CHANGE_LOG_BT A, TABLE(A.CHANGELOG_ITEMS) B;

COMMENT ON TABLE VCHANGELOG_ITEM IS
	'Projection of all columns of base table CHANGE_LOG_BT. The arrav CHANGELOG_ITEMS is decoded.';
COMMENT ON COLUMN VCHANGELOG_ITEM.COLUMN_ID IS
	'The arrav element CHANGELOG_ITEMS.COLUMN_ID is decoded into the column COLUMN_ID';
COMMENT ON COLUMN VCHANGELOG_ITEM.AFTER_VALUE IS
	'The arrav element CHANGELOG_ITEMS.AFTER_VALUE is decoded into the column AFTER_VALUE';


CREATE OR REPLACE VIEW VCHANGLOG_EVENTS (ID, LOGGING_DATE, USER_NAME,
    TABLE_NAME, OBJECT_ID, IS_HIDDEN, INSERTED, UPDATED, DELETED, WORKSPACE_NAME)
AS -- used in application schema-riser
SELECT S.ID, S.LOGGING_DATE, INITCAP(B.USER_NAME) USER_NAME, INITCAP(T.VIEW_NAME) TABLE_NAME,
    S.OBJECT_ID, S.IS_HIDDEN,
    CASE WHEN ACTION_CODE = 'I' THEN 1 ELSE 0 END INSERTED,
    CASE WHEN ACTION_CODE = 'U' THEN 1 ELSE 0 END UPDATED,
    CASE WHEN ACTION_CODE = 'D' THEN 1 ELSE 0 END DELETED,
    W.WORKSPACE_NAME
FROM CHANGE_LOG_BT S
JOIN USER_NAMESPACES W ON S.WORKSPACE$_ID = W.WORKSPACE$_ID
JOIN CHANGE_LOG_TABLES T ON T.ID = S.TABLE_ID
JOIN CHANGE_LOG_USERS_BT B ON B.ID = S.USER_ID AND B.WORKSPACE$_ID = S.WORKSPACE$_ID
;
COMMENT ON TABLE VCHANGLOG_EVENTS IS
'Overview of DML changes with one row for each affected row for tracked tables.';

CREATE OR REPLACE VIEW VCHANGE_LOG ( ID, TABLE_ID, TABLE_NAME, TABLE_NAME_INITCAP, VIEW_NAME, OBJECT_ID,
	ACTION_CODE, ACTION_NAME, IS_HIDDEN, USER_NAME, USER_NAME_INITCAP, LOGGING_DATE,
    CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
    CHANGELOG_ITEMS, WORKSPACE$_ID )
AS -- used in the generated views VPROTOCOL_LIST and VPROTOCOL_COLUMNS_LIST2 and function ChangeLog_Query
SELECT A.ID, A.TABLE_ID, T.TABLE_NAME,
	INITCAP(NVL(T.VIEW_NAME, T.TABLE_NAME)) TABLE_NAME_INITCAP,
	T.VIEW_NAME,
	A.OBJECT_ID,
	A.ACTION_CODE,
	DECODE(A.ACTION_CODE, 'I', 'Insert', 'U', 'Update', 'D', 'Delete', 'S', 'Select') ACTION_NAME,
	A.IS_HIDDEN,
	B.USER_NAME,
	INITCAP(B.USER_NAME) USER_NAME_INITCAP,
	A.LOGGING_DATE,
    A.CUSTOM_REF_ID1, A.CUSTOM_REF_ID2, A.CUSTOM_REF_ID3, A.CUSTOM_REF_ID4, A.CUSTOM_REF_ID5, A.CUSTOM_REF_ID6, A.CUSTOM_REF_ID7, A.CUSTOM_REF_ID8, A.CUSTOM_REF_ID9,
    A.CHANGELOG_ITEMS, A.WORKSPACE$_ID
FROM CHANGE_LOG_BT A
JOIN CHANGE_LOG_TABLES T ON T.ID = A.TABLE_ID
JOIN CHANGE_LOG_USERS_BT B ON B.ID = A.USER_ID AND B.WORKSPACE$_ID = A.WORKSPACE$_ID
WHERE A.WORKSPACE$_ID = custom_changelog.Get_Current_Workspace_ID
;
COMMENT ON TABLE VCHANGE_LOG IS
'Raw details of DML changes with one row for each affected row for tracked tables,
restricted to rows of the current workspace from the session context CUSTOM_CTX.
Table names and user names are decoded. Rows can be inserted with this view.';

CREATE OR REPLACE TRIGGER VCHANGE_LOG_INS_TR
INSTEAD OF INSERT ON VCHANGE_LOG FOR EACH ROW
BEGIN
    INSERT INTO CHANGE_LOG_BT(ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
        CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
        CHANGELOG_ITEMS, WORKSPACE$_ID)
    VALUES(:new.ID,
        custom_changelog.Changelog_Table_ID(:new.TABLE_NAME), :new.OBJECT_ID, :new.ACTION_CODE, :new.IS_HIDDEN,
        custom_changelog.Changelog_User_ID(:new.USER_NAME, :new.WORKSPACE$_ID), :new.LOGGING_DATE,
        :new.CUSTOM_REF_ID1, :new.CUSTOM_REF_ID2, :new.CUSTOM_REF_ID3, :new.CUSTOM_REF_ID4, :new.CUSTOM_REF_ID5,
        :new.CUSTOM_REF_ID6, :new.CUSTOM_REF_ID7, :new.CUSTOM_REF_ID8, :new.CUSTOM_REF_ID9,
        :new.CHANGELOG_ITEMS, :new.WORKSPACE$_ID);
END;
/
show errors


CREATE OR REPLACE VIEW VCHANGE_LOG_COLUMNS (
    ID, LOGGING_DATE, USER_NAME, USER_NAME_INITCAP,
    ACTION_CODE, ACTION_NAME, TABLE_ID, VIEW_NAME, TABLE_NAME,
    COLUMN_NAME, COLUMN_ID,
    CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5,
    CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
    OBJECT_ID, IS_HIDDEN, AFTER_VALUE
) AS -- used in the view VCHANGE_LOG_FIELDS and function ChangeLog_Pivot_Query
SELECT A.ID, A.LOGGING_DATE,
    B.USER_NAME,
    INITCAP(B.USER_NAME) USER_NAME_INITCAP,
    A.ACTION_CODE,
    DECODE(A.ACTION_CODE, 'I', 'Insert', 'U', 'Update', 'D', 'Delete', 'S', 'Select') ACTION_NAME,
    A.TABLE_ID, T.VIEW_NAME, T.TABLE_NAME,
    -- custom_changelog.Changelog_Column_Name(T.TABLE_NAME, A.COLUMN_ID) COLUMN_NAME,
    C.COLUMN_NAME,
    A.COLUMN_ID,
    A.CUSTOM_REF_ID1, A.CUSTOM_REF_ID2, A.CUSTOM_REF_ID3, A.CUSTOM_REF_ID4, A.CUSTOM_REF_ID5,
    A.CUSTOM_REF_ID6, A.CUSTOM_REF_ID7, A.CUSTOM_REF_ID8, A.CUSTOM_REF_ID9,
    A.OBJECT_ID,
    A.IS_HIDDEN, A.AFTER_VALUE
FROM (
    SELECT  A.ID, A.LOGGING_DATE, A.USER_ID, A.ACTION_CODE,
            A.TABLE_ID, B.COLUMN_ID, A.WORKSPACE$_ID,
            A.CUSTOM_REF_ID1, A.CUSTOM_REF_ID2, A.CUSTOM_REF_ID3, A.CUSTOM_REF_ID4, A.CUSTOM_REF_ID5,
            A.CUSTOM_REF_ID6, A.CUSTOM_REF_ID7, A.CUSTOM_REF_ID8, A.CUSTOM_REF_ID9,
            A.OBJECT_ID, A.IS_HIDDEN,
            B.AFTER_VALUE
    FROM    CHANGE_LOG_BT A, TABLE(A.CHANGELOG_ITEMS) B
    WHERE   A.WORKSPACE$_ID = custom_changelog.Get_Current_Workspace_ID
) A
JOIN CHANGE_LOG_TABLES T ON T.ID = A.TABLE_ID
JOIN CHANGE_LOG_USERS_BT B ON B.ID = A.USER_ID AND B.WORKSPACE$_ID = A.WORKSPACE$_ID
LEFT OUTER JOIN SYS.USER_TAB_COLUMNS C ON C.TABLE_NAME = T.TABLE_NAME AND C.COLUMN_ID = A.COLUMN_ID
WHERE (A.COLUMN_ID IS NOT NULL OR A.ACTION_CODE = 'D')
;
COMMENT ON TABLE VCHANGE_LOG_COLUMNS IS
'Raw details of DML changes with one row for each affected individual table column for tracked tables,
restricted to rows of the current workspace from the session context CUSTOM_CTX. The arrav CHANGELOG_ITEMS is decoded.';
COMMENT ON COLUMN VCHANGE_LOG_COLUMNS.COLUMN_ID IS
'The arrav element CHANGELOG_ITEMS.COLUMN_ID is decoded into the column COLUMN_ID';
COMMENT ON COLUMN VCHANGE_LOG_COLUMNS.AFTER_VALUE IS
'The arrav element CHANGELOG_ITEMS.AFTER_VALUE is decoded into the column AFTER_VALUE';


------------------------------------------------------------------------------
begin 
	custom_changelog.Save_Config_Defaults; 
end;
/
