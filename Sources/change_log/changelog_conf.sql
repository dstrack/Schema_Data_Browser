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
Package zur Konfiguration der Regeln für die Erzeugung von
zusätzlichen Datenbank Objekten zur Aufzeichnung und Auswertung von
Datenänderungen mit Benutzern und Zeitpunkten. Für die Auswertung der
Änderungs-Historie können schnelle Zugriffspfade bestimmt werden.

Optional kann ein eigenen Namespace zur Unterteilung je Mandanten
konfiguriert werden. Dazu wird jeder Tabelle eine neue Spalte namens
WORKSPACE$_ID hinzugefügt, die zusammen mit einem eigenen Application
Kontext die transparente Selektion für den aktuellen Mandanten mithilfe
von Views ermöglicht.

Optional können bestimmte Tabellen so konfiguriert werden, dass die
Daten darin immutable oder unveränderlich werden. Dazu wird den Tabellen
die neue Spalte DELETED_MARK hinzugefügt. Mit Hilfe von INSTEAD OF
Triggern werden DELETE Statements dann so ausgeführt, dass anstatt zu
löschen die Spalte DELETED_MARK auf einen berechneten Wert gesetzt wird.


DROP PACKAGE changelog_conf;
DROP TABLE CHANGE_LOG_CONFIG;

*/

CREATE OR REPLACE TRIGGER CHANGE_LOG_CONFIG_BU_TR
BEFORE INSERT OR UPDATE OF
INCLUDED_CHANGELOG_PATTERN,EXCLUDED_CHANGELOG_PATTERN,
CHANGELOG_FKEY_TABLES,CHANGELOG_FKEY_COLUMNS,
REFERENCE_DESCRIPTION_COLS,EXCLUDED_CHANGELOG_BLOB_COLS,EXCLUDED_CHANGELOG_COLS,
INCLUDED_WORKSPACEID_PATTERN,EXCLUDED_WORKSPACEID_PATTERN,
INCLUDED_DELETE_MARK_PATTERN,EXCLUDED_DELETE_MARK_PATTERN,
INCLUDED_TIMESTAMP_PATTERN,EXCLUDED_TIMESTAMP_PATTERN
ON CHANGE_LOG_CONFIG FOR EACH ROW
BEGIN
	:new.INCLUDED_CHANGELOG_PATTERN   	:= UPPER(REPLACE(:new.INCLUDED_CHANGELOG_PATTERN, ' '));
	:new.EXCLUDED_CHANGELOG_PATTERN   	:= UPPER(REPLACE(:new.EXCLUDED_CHANGELOG_PATTERN, ' '));
	:new.CHANGELOG_FKEY_TABLES   		:= UPPER(REPLACE(:new.CHANGELOG_FKEY_TABLES, ' '));
	:new.CHANGELOG_FKEY_COLUMNS   		:= UPPER(REPLACE(:new.CHANGELOG_FKEY_COLUMNS, ' '));
	:new.REFERENCE_DESCRIPTION_COLS   	:= UPPER(REPLACE(:new.REFERENCE_DESCRIPTION_COLS, ' '));
	:new.EXCLUDED_CHANGELOG_BLOB_COLS   := UPPER(REPLACE(:new.EXCLUDED_CHANGELOG_BLOB_COLS, ' '));
	:new.EXCLUDED_CHANGELOG_COLS   		:= UPPER(REPLACE(:new.EXCLUDED_CHANGELOG_COLS, ' '));
	:new.INCLUDED_WORKSPACEID_PATTERN   := UPPER(REPLACE(:new.INCLUDED_WORKSPACEID_PATTERN, ' '));
	:new.EXCLUDED_WORKSPACEID_PATTERN	:= UPPER(REPLACE(:new.EXCLUDED_WORKSPACEID_PATTERN, ' '));
	:new.INCLUDED_DELETE_MARK_PATTERN   := UPPER(REPLACE(:new.INCLUDED_DELETE_MARK_PATTERN, ' '));
	:new.EXCLUDED_DELETE_MARK_PATTERN   := UPPER(REPLACE(:new.EXCLUDED_DELETE_MARK_PATTERN, ' '));
	:new.INCLUDED_TIMESTAMP_PATTERN   	:= UPPER(REPLACE(:new.INCLUDED_TIMESTAMP_PATTERN, ' '));
	:new.EXCLUDED_TIMESTAMP_PATTERN   	:= UPPER(REPLACE(:new.EXCLUDED_TIMESTAMP_PATTERN, ' '));
	:new.LAST_MODIFIED_BY 			:= NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
	:new.LAST_MODIFIED_AT   		:= LOCALTIMESTAMP;
END;
/


CREATE OR REPLACE PACKAGE changelog_conf
AUTHID CURRENT_USER
IS
    g_Use_ORDIMAGE     CONSTANT BOOLEAN := FALSE;
    g_debug         NUMBER          := 0;

	TYPE rec_references_count IS RECORD (
		R_CONSTRAINT_NAME             VARCHAR2(128),
		R_OWNER                   	  VARCHAR2(128), 
		CNT		                      NUMBER
	);
	TYPE tab_references_count IS TABLE OF rec_references_count;

	TYPE rec_insert_triggers IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		TABLE_OWNER                   VARCHAR2(128), 
		TRIGGER_HAS_NEXTVAL			  NUMBER,
		TRIGGER_HAS_SYS_GUID		  NUMBER,
		TRIGGER_BODY				  VARCHAR(1000),
		SEQUENCE_OWNER				  VARCHAR2(128), 
		SEQUENCE_NAME				  VARCHAR2(128)
	);
	TYPE tab_insert_triggers IS TABLE OF rec_insert_triggers;
	
	TYPE rec_base_triggers IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		TABLE_OWNER                   VARCHAR2(128), 
		TRIGGER_NAME				  VARCHAR2(128),
		TRIGGERING_EVENT		      VARCHAR2(256),
		TRIGGER_TYPE				  VARCHAR2(16),
		TRIGGER_BODY		          VARCHAR(4000),
		IS_CANDIDATE				  VARCHAR2(3)
	);
	TYPE tab_base_triggers IS TABLE OF rec_base_triggers;
	
	TYPE rec_views_triggers IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		VIEW_INSERT_TRIGGER_NAME      VARCHAR2(128), 
		VIEW_UPDATE_TRIGGER_NAME	  VARCHAR2(128),
		VIEW_DELETE_TRIGGER_NAME      VARCHAR2(128)
	);
	TYPE tab_views_triggers IS TABLE OF rec_views_triggers;

	TYPE rec_unique_keys IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		TABLE_OWNER                   VARCHAR2(128), 
		CONSTRAINT_NAME               VARCHAR2(128), 
		CONSTRAINT_TYPE               VARCHAR2(1)  , 
		COLUMN_NAME               	  VARCHAR2(128), 
		POSITION					  NUMBER,
		DEFAULT_TEXT				  VARCHAR2(1000), 
		VIEW_COLUMN_NAME			  VARCHAR2(128), 
		COLUMN_ID					  NUMBER, 
		DATA_TYPE					  VARCHAR2(128), 
		NULLABLE					  VARCHAR2(1), 
		DATA_PRECISION			  	  NUMBER,
		DATA_SCALE					  NUMBER,
		CHAR_LENGTH					  NUMBER,
		DEFAULT_LENGTH				  NUMBER,
		VIRTUAL_COLUMN                VARCHAR2(3)  , 
		INDEX_OWNER                   VARCHAR2(256), 
		INDEX_NAME                    VARCHAR2(128), 
		DEFERRABLE                    VARCHAR2(14) , 
		DEFERRED                      VARCHAR2(9)  , 
		STATUS                        VARCHAR2(8)  , 
		VALIDATED                     VARCHAR2(13)
	);
	TYPE tab_unique_keys IS TABLE OF rec_unique_keys;
	
	TYPE rec_base_unique_keys IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		TABLE_OWNER                   VARCHAR2(128), 
		CONSTRAINT_NAME               VARCHAR2(128), 
		CONSTRAINT_TYPE               VARCHAR2(1)  , 
		REQUIRED					  VARCHAR2(3)  ,  
		HAS_NULLABLE				  NUMBER       ,
		KEY_HAS_WORKSPACE_ID          VARCHAR2(3)  ,  
		KEY_HAS_DELETE_MARK           VARCHAR2(3)  ,  
		KEY_HAS_NEXTVAL               VARCHAR2(3)  ,  
		KEY_HAS_SYS_GUID              VARCHAR2(3)  ,  
		HAS_SCALAR_KEY                VARCHAR2(3)  , 
		HAS_SERIAL_KEY                VARCHAR2(3)  , 
		HAS_SCALAR_VIEW_KEY           VARCHAR2(3)  , 
		HAS_SERIAL_VIEW_KEY           VARCHAR2(3)  , 
		TRIGGER_HAS_NEXTVAL           VARCHAR2(3)  ,  
		TRIGGER_HAS_SYS_GUID          VARCHAR2(3)  ,  
		SEQUENCE_OWNER                VARCHAR2(128), 
		SEQUENCE_NAME                 VARCHAR2(128), 
		DEFERRABLE                    VARCHAR2(14) , 
		DEFERRED                      VARCHAR2(9)  , 
		STATUS                        VARCHAR2(8)  , 
		VALIDATED                     VARCHAR2(13) , 
		VIEW_KEY_COLS                 VARCHAR2(512), 
		UNIQUE_KEY_COLS               VARCHAR2(512), 
		KEY_COLS_COUNT                NUMBER       , 
		VIEW_KEY_COLS_COUNT           NUMBER       , 
		INDEX_OWNER                   VARCHAR2(256), 
		INDEX_NAME                    VARCHAR2(128), 
		SHORT_NAME                    VARCHAR2(128),
		BASE_NAME                     VARCHAR2(128),
		RUN_NO						  NUMBER
	);
	TYPE tab_base_unique_keys IS TABLE OF rec_base_unique_keys;
	TYPE cur_base_unique_keys IS REF CURSOR RETURN rec_base_unique_keys;	
		
	TYPE rec_alter_unique_keys IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		TABLESPACE_NAME				  VARCHAR2(128), 
		CONSTRAINT_NAME               VARCHAR2(128), 
		CONSTRAINT_TYPE               VARCHAR2(1)  , 
		VIEW_KEY_COLS				  VARCHAR2(512),
		UNIQUE_KEY_COLS				  VARCHAR2(512),
		KEY_COLS_COUNT				  NUMBER,
		HAS_NULLABLE				  NUMBER,
		INDEX_OWNER                   VARCHAR2(128), 
		INDEX_NAME                    VARCHAR2(128), 
		PREFIX_LENGTH				  NUMBER       , 
		DEFERRABLE                    VARCHAR2(14) , 
		DEFERRED                      VARCHAR2(9)  , 
		STATUS                        VARCHAR2(8)  , 
		VALIDATED                     VARCHAR2(13) ,
		IOT_TYPE					  VARCHAR2(12) ,
		AVG_ROW_LEN					  NUMBER,
		BASE_NAME               	  VARCHAR2(128), 
		SHORT_NAME               	  VARCHAR2(128), 
		SHORT_NAME2               	  VARCHAR2(128), 
		KEY_CLAUSE					  VARCHAR2(128), 
		CONSTRAINT_EXT                VARCHAR2(128),
		KEY_HAS_WORKSPACE_ID		  VARCHAR2(3),
		KEY_HAS_DELETE_MARK			  VARCHAR2(3),
		KEY_HAS_NEXTVAL				  VARCHAR2(3),
		KEY_HAS_SYS_GUID			  VARCHAR2(3),
		HAS_SCALAR_VIEW_KEY           VARCHAR2(3), 
		HAS_SERIAL_VIEW_KEY           VARCHAR2(3), 
		SEQUENCE_OWNER                VARCHAR2(128), 
		SEQUENCE_NAME                 VARCHAR2(128), 
		READ_ONLY                     VARCHAR2(3),
		REFERENCES_COUNT			  NUMBER
	);
	TYPE tab_alter_unique_keys IS TABLE OF rec_alter_unique_keys;

	TYPE rec_base_views IS RECORD (
		VIEW_NAME                     VARCHAR2(128), 
		TABLE_NAME                    VARCHAR2(128), 
		RUN_NO						  NUMBER,
		SHORT_NAME                    VARCHAR2(128)
	);
	TYPE tab_base_views IS TABLE OF rec_base_views;

	TYPE rec_Changelog_fkeys IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		FOREIGN_KEY_COL               VARCHAR2(128)
	);
	TYPE tab_Changelog_fkeys IS TABLE OF rec_Changelog_fkeys;

	TYPE rec_has_set_null_fkeys IS RECORD (
		TABLE_NAME                    VARCHAR2(128)
	);
	TYPE tab_has_set_null_fkeys IS TABLE OF rec_has_set_null_fkeys;

	TYPE rec_table_columns IS RECORD (
		TABLE_NAME              	VARCHAR2(128), 
		COLUMN_ID					NUMBER,
		COLUMN_NAME               	VARCHAR2(128), 
		DATA_TYPE					VARCHAR2(128), 
		NULLABLE					VARCHAR2(1), 
		DEFAULT_LENGTH				NUMBER,
		DEFAULT_TEXT				VARCHAR2(1000), 
		DATA_PRECISION			  	NUMBER,
		DATA_SCALE					NUMBER,
		CHAR_LENGTH					NUMBER
	);
	TYPE tab_table_columns IS TABLE OF rec_table_columns;

	TYPE rec_foreign_key_columns IS RECORD (
		TABLE_NAME              	VARCHAR2(128), 
		TABLE_OWNER                 VARCHAR2(128), 
		CONSTRAINT_NAME				VARCHAR2(128),
		COLUMN_NAME               	VARCHAR2(128), 
		POSITION					NUMBER,
		COLUMN_ID					NUMBER,
		NULLABLE					VARCHAR2(1),
		DELETE_RULE					VARCHAR2(20),
		DEFERRABLE					VARCHAR2(20), 
		DEFERRED					VARCHAR2(20),
		STATUS						VARCHAR2(20),
		VALIDATED					VARCHAR2(20),
		R_CONSTRAINT_NAME			VARCHAR2(128),
		R_OWNER						VARCHAR2(128)
	);
	TYPE tab_foreign_key_columns IS TABLE OF rec_foreign_key_columns;

	TYPE rec_changelog_references IS RECORD (
		S_TABLE_NAME              	VARCHAR2(128), 
		S_COLUMN_NAME              	VARCHAR2(128), 
		T_TABLE_NAME				VARCHAR2(128), 
		T_COLUMN_NAME              	VARCHAR2(128), 
		T_CHANGELOG_NAME			VARCHAR2(128), 
		CONSTRAINT_TYPE				VARCHAR2(1), 
		DELETE_RULE					VARCHAR2(10)
	);
	TYPE tab_changelog_references IS TABLE OF rec_changelog_references;

	g_fetch_limit CONSTANT PLS_INTEGER := 100;

	PROCEDURE Save_Config_Defaults;
	PROCEDURE Load_Config;

	FUNCTION FN_Pipe_References_Count
	RETURN changelog_conf.tab_references_count PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_insert_triggers
	RETURN changelog_conf.tab_insert_triggers PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_base_triggers (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN changelog_conf.tab_base_triggers PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_views_triggers (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN changelog_conf.tab_views_triggers PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_unique_keys
	RETURN changelog_conf.tab_unique_keys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_unique_indexes 
	RETURN changelog_conf.tab_unique_keys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Base_Uniquekeys	-- result is cached in MVBASE_UNIQUE_KEYS
	RETURN changelog_conf.tab_base_unique_keys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Base_Uniquekeys (
		p_cur changelog_conf.cur_base_unique_keys
	)
	RETURN changelog_conf.tab_base_unique_keys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Table_AlterUniquekeys (
		p_cur_unique_keys changelog_conf.cur_base_unique_keys
	)
	RETURN changelog_conf.tab_alter_unique_keys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Base_Views
	RETURN changelog_conf.tab_base_views PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Changelog_fkeys
	RETURN changelog_conf.tab_Changelog_fkeys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_has_set_null_fkeys (p_Table_Name VARCHAR2 DEFAULT NULL)
	RETURN changelog_conf.tab_has_set_null_fkeys PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Table_Columns
	RETURN changelog_conf.tab_table_columns PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Foreign_Key_Columns
	RETURN changelog_conf.tab_foreign_key_columns PIPELINED PARALLEL_ENABLE;

	FUNCTION FN_Pipe_Changelog_References
	RETURN changelog_conf.tab_changelog_references PIPELINED PARALLEL_ENABLE;

	FUNCTION Enquote_Name (str VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Enquote_Literal ( p_Text VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION First_Element (str VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Compose_Table_Column_Name (
    	p_Table_Name VARCHAR2,
    	p_Column_Name VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Compose_Column_Name (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Deduplication VARCHAR2 DEFAULT 'NO',
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC;

    PROCEDURE Set_Debug(p_Debug NUMBER DEFAULT 0);

    FUNCTION Get_Base_Table_Ext RETURN VARCHAR2;
    FUNCTION Get_Base_Table_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;

    FUNCTION Get_ChangelogTrigger_Name ( p_Name VARCHAR2, p_RunNo VARCHAR2 DEFAULT NULL ) RETURN VARCHAR2;

    FUNCTION Get_BiTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;

    FUNCTION Get_BuTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;

    FUNCTION Get_InsTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION Get_DelTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION Get_UpdTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;

    FUNCTION Get_SequenceExt RETURN VARCHAR2;
    FUNCTION Get_Sequence_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;
    PROCEDURE Get_Sequence_Name ( p_Name VARCHAR2, p_Sequence_Name OUT VARCHAR2, p_Sequence_Exists OUT VARCHAR2 );
    FUNCTION Get_Sequence_ColumnExt RETURN VARCHAR2;
    FUNCTION Get_Sequence_Column ( p_Name VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION Get_Sequence_ConstraintExt RETURN VARCHAR2;
    FUNCTION Get_Sequence_Constraint ( p_Name VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION Get_SequenceOptions RETURN VARCHAR2;
    FUNCTION Get_Use_Sequences RETURN VARCHAR2;
    
    FUNCTION Get_Sequence_Limit_ID (
        p_Table_Name    IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2
    ) RETURN NUMBER;
    
	PROCEDURE Set_Sequence_New_Value (
		p_Sequence_Name VARCHAR2,
		p_Sequence_Owner VARCHAR2,
		p_New_Value NUMBER
	);

    PROCEDURE  Adjust_Table_Sequence (
        p_Table_Name    IN VARCHAR2,
        p_Sequence_Name IN VARCHAR2,
		p_Sequence_Owner IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2,
        p_StartSeq      IN INTEGER DEFAULT 1
    );

	FUNCTION Get_Interrim_Table_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION App_User_Schema RETURN VARCHAR2;

    FUNCTION Get_Use_Change_Log RETURN VARCHAR2;
	FUNCTION Get_Use_Audit_Info_Columns RETURN VARCHAR2;
	FUNCTION Get_Use_Audit_Info_Trigger RETURN VARCHAR2;
	FUNCTION Get_Drop_Audit_Info_Columns RETURN VARCHAR2;
    FUNCTION Get_Use_Column_Workspace RETURN VARCHAR2;
    FUNCTION Get_Use_Column_Delete_mark RETURN VARCHAR2;
    FUNCTION Get_Add_Modify_Date RETURN VARCHAR2;
    FUNCTION Get_Add_Modify_User RETURN VARCHAR2;
    FUNCTION Get_Add_Creation_Date RETURN VARCHAR2;
    FUNCTION Get_Add_Creation_User RETURN VARCHAR2;
    FUNCTION Get_Enforce_Not_Null RETURN VARCHAR2;
    FUNCTION Get_Add_Insert_Trigger RETURN VARCHAR2;
    FUNCTION Get_Add_Delete_Trigger RETURN VARCHAR2;
    FUNCTION Get_Add_Update_Trigger1 RETURN VARCHAR2;
    FUNCTION Get_Add_Update_Trigger2 RETURN VARCHAR2;
    FUNCTION Get_Add_Application_Schema RETURN VARCHAR2;
    FUNCTION Get_Add_ChangeLog_Views RETURN VARCHAR2;
    FUNCTION App_User_Password RETURN VARCHAR2;
    FUNCTION Apex_Workspace_Name RETURN VARCHAR2;
    FUNCTION Get_Use_On_Null RETURN VARCHAR2;
    FUNCTION Get_Include_External_Objects RETURN VARCHAR2;
    FUNCTION Get_Table_Schema RETURN VARCHAR2;
    FUNCTION Get_View_Schema RETURN VARCHAR2;
    PROCEDURE Set_Table_Schema(p_Schema_Name IN VARCHAR2 DEFAULT NULL);
    PROCEDURE Set_View_Schema(p_Schema_Name IN VARCHAR2 DEFAULT NULL);
    PROCEDURE Set_Target_Schema (p_Schema_Name IN VARCHAR2 DEFAULT NULL);

    FUNCTION Get_TableWorkspaces RETURN VARCHAR2;
	FUNCTION Get_Sys_Guid_Function RETURN VARCHAR2;
    FUNCTION Get_ColumnWorkspace RETURN VARCHAR2;
    FUNCTION Get_ColumnWorkspace_List RETURN VARCHAR2;
    FUNCTION Get_Context_WorkspaceID_Expr RETURN VARCHAR2;
    FUNCTION Get_Context_User_Name_Expr RETURN VARCHAR2;
    FUNCTION Get_Context_User_ID_Expr RETURN VARCHAR2;

    FUNCTION Get_Table_App_Users RETURN VARCHAR2;
    FUNCTION Get_ExcludeTablesPattern RETURN VARCHAR2;
    FUNCTION Get_IncludeWorkspaceIDPattern RETURN VARCHAR2;
    FUNCTION Get_ConstantWorkspaceIDPattern RETURN VARCHAR2;
    FUNCTION Get_ExcludeWorkspaceIDPattern RETURN VARCHAR2;
    FUNCTION Get_IncludeDeleteMarkPattern RETURN VARCHAR2;
    FUNCTION Get_ExcludeDeleteMarkPattern RETURN VARCHAR2;
    FUNCTION Get_IncludeTimestampPattern RETURN VARCHAR2;
    FUNCTION Get_ExcludeTimestampPattern RETURN VARCHAR2;
    FUNCTION Get_ColumnCreateUser RETURN VARCHAR2;
    FUNCTION Get_ColumnCreateUser_List RETURN VARCHAR2;
    FUNCTION Get_ColumnCreateDate RETURN VARCHAR2;
    FUNCTION Get_ColumnCreateDate_List RETURN VARCHAR2;
    FUNCTION Get_ColumnModifyUser RETURN VARCHAR2;
    FUNCTION Get_ColumnModifyUser_List RETURN VARCHAR2;
    FUNCTION Get_DatatypeModifyUser RETURN VARCHAR2;
    FUNCTION Get_ColumnTypeModifyUser RETURN VARCHAR2;
    FUNCTION Get_FunctionModifyUser RETURN VARCHAR2;
    FUNCTION Get_DefaultModifyUser RETURN VARCHAR2;
    FUNCTION Get_ForeignKeyModifyUser RETURN VARCHAR2;
    FUNCTION Get_ColumnModifyDate RETURN VARCHAR2;
    FUNCTION Get_ColumnModifyDate_List RETURN VARCHAR2;
    FUNCTION Get_FunctionModifyDate RETURN VARCHAR2;
    FUNCTION Get_DatatypeModifyDate RETURN VARCHAR2;
    FUNCTION Get_AltDatatypeModifyDate RETURN VARCHAR2;

    FUNCTION Get_ColumnDeletedMark RETURN VARCHAR2;
    FUNCTION Get_ColumnDeletedMark_List RETURN VARCHAR2;
    FUNCTION Get_DatatypeDeletedMark RETURN VARCHAR2;
    FUNCTION Get_DefaultDeletedMark RETURN VARCHAR2;
    FUNCTION Get_ColumnTypeDeletedMark RETURN VARCHAR2;
    FUNCTION Get_DeletedMarkFunction (p_Has_Serial_Primary_Key VARCHAR2, p_Primary_Key_Cols VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_ColumnIndexFormat RETURN VARCHAR2;
    FUNCTION Get_Admin_Workspace_Name RETURN VARCHAR2;
    FUNCTION Get_Database_Version RETURN VARCHAR2;
    FUNCTION Use_Serial_Default RETURN VARCHAR2;
    FUNCTION Get_ConstraintText (p_Table_Name VARCHAR2, p_Constraint_Name VARCHAR2, p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')) RETURN VARCHAR2;
    FUNCTION Get_ColumnDefaultText (p_Table_Name VARCHAR2, p_Column_Name VARCHAR2, p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')) RETURN VARCHAR2;
	FUNCTION Get_Name_Part (
		p_Name IN VARCHAR2,
		p_Part IN NUMBER
	) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ColumnCheckCondition (p_Table_Name VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_TriggerText (p_Table_Name VARCHAR2, p_Trigger_Name VARCHAR2) RETURN CLOB;
    FUNCTION Get_BaseName (p_Table_Name VARCHAR2) RETURN VARCHAR2;

	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ','
	)
    RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Match_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern VARCHAR2) RETURN VARCHAR2 DETERMINISTIC; -- YES, NO
	FUNCTION Match_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern_Array apex_t_varchar2) RETURN VARCHAR2 DETERMINISTIC; -- YES / NO

	FUNCTION Strip_Comments ( p_Text VARCHAR2 ) RETURN VARCHAR2;

    FUNCTION IN_LIST( p_string in clob, p_delimiter in varchar2 := ';') RETURN sys.odciVarchar2List PIPELINED PARALLEL_ENABLE;

    FUNCTION F_BASE_KEY_COLS (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION F_BASE_KEY_COND (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2,
        p_Prefix IN VARCHAR2 DEFAULT ':OLD.'
    ) RETURN VARCHAR2;

    FUNCTION F_VIEW_KEY_COND (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2,
        p_Prefix IN VARCHAR2 DEFAULT ':OLD.'
    )
    RETURN VARCHAR2;

    FUNCTION F_VIEW_KEY_COLS (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION F_VIEW_COLUMNS (
        p_TABLE_NAME IN VARCHAR2,
        p_SHORT_NAME IN VARCHAR2,
        p_ALIAS IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    FUNCTION F_INTERSECT_COLUMNS (
        p_Table_Name IN VARCHAR2,
        p_Target_Owner IN VARCHAR2,
        p_Source_Owner IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION F_BASE_TABLE_COLS (
        p_TABLE_NAME IN VARCHAR2,
        p_FILTER IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

	FUNCTION Next_Key_Function (
        p_Table_Name    IN VARCHAR2,
		p_Primary_Key_Col IN VARCHAR2,
		p_Sequence_Name IN VARCHAR2
	) RETURN VARCHAR2;

	FUNCTION Before_Insert_Trigger_body (
		p_Table_Name				VARCHAR2,
		p_Primary_Key_Col			VARCHAR2,
		p_Has_Serial_Primary_Key	VARCHAR2,
		p_Sequence_Name				VARCHAR2,
		p_Column_CreDate			VARCHAR2,
		p_Column_CreUser			VARCHAR2,
		p_Column_ModDate			VARCHAR2,
		p_Column_ModUser			VARCHAR2
	) RETURN VARCHAR2;

	FUNCTION Before_Update_Trigger_body (
		p_Column_ModDate			VARCHAR2,
		p_Column_ModUser			VARCHAR2
	) RETURN VARCHAR2;

	TYPE rec_constraint_condition IS RECORD (
		OWNER				VARCHAR2(128),
		TABLE_NAME 			VARCHAR2(128),
		CONSTRAINT_NAME 	VARCHAR2(128),
		SEARCH_CONDITION 	VARCHAR2(4000)
	);
	-- output of data_browser_utl.Constraint_Condition_Cursor
	TYPE tab_constraint_condition IS TABLE OF rec_constraint_condition;

	FUNCTION Constraint_Condition_Cursor (
		p_Table_Name IN VARCHAR2 DEFAULT NULL,
		p_Constraint_Name IN VARCHAR2 DEFAULT NULL
	) RETURN changelog_conf.tab_constraint_condition PIPELINED PARALLEL_ENABLE;

    FUNCTION Get_ChangeLogTable RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_ChangeLogFKeyTables RETURN VARCHAR2;
    FUNCTION Get_ChangeLog_Custom_Ref(p_Table_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_ChangeLogFKeyColumns RETURN VARCHAR2;
    FUNCTION Get_IncludeChangeLogPattern RETURN VARCHAR2;
    FUNCTION Get_ExcludeChangeLogPattern RETURN VARCHAR2;
    FUNCTION Get_ReferenceDescriptionCols RETURN VARCHAR2;
END changelog_conf;
/

CREATE OR REPLACE PACKAGE BODY changelog_conf 
IS
    g_TableWorkspaces  CONSTANT  VARCHAR2(64) := 'USER_NAMESPACES'; -- Tabelle Name for VPD Workspace
	g_Sys_Guid_Function CONSTANT VARCHAR2(100) := 'TO_NUMBER(SYS_GUID(),''XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'')';
	g_Max_Name_Length CONSTANT INTEGER		:= 30;			-- Maximum LENGTH of database object names (30 is the max length for trigger names in oracle 11g)
    g_ColumnWorkspace VARCHAR2(64)          := 'WORKSPACE$_ID';   -- Column Name for Application Namespace Support
    -- Context Expression for current Namespace
    -- used for column default -- ORA-04044: Prozedur, Funktion, Package oder Typ hier nicht zulässig
    --g_ContextWorkspaceIDExpr VARCHAR2(128)   := q'[custom_changelog.Get_Current_Workspace_ID]';
    g_ContextWorkspaceIDExpr VARCHAR2(128)   := q'[SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_ID')]';
    -- Context Expression for current User default
    g_ContextUserNameExpr CONSTANT VARCHAR2(128)   := q'[SYS_CONTEXT('APEX$SESSION','APP_USER')]';
    g_ContextUserIDExpr   VARCHAR2(128)   	:= q'[SYS_CONTEXT('CUSTOM_CTX', 'USER_ID')]';
    g_SessionUserNameExpr CONSTANT VARCHAR2(128)   := q'[SYS_CONTEXT('USERENV','SESSION_USER')]';
    g_BaseTableExt  VARCHAR2(64)            := '_BT';       -- Extension for Base Table name
    g_ChangelogTriggerPrefix VARCHAR2(64)   := '';  		-- Prefix for Compound Change_Log trigger
    g_ChangelogTriggerExt  VARCHAR2(64)     := '_CHLOG_TR';  -- Extension for Compound Change_Log trigger
    g_BiTriggerPrefix VARCHAR2(64)          := '';    		-- Prefix for Before Insert trigger
    g_BiTriggerExt  VARCHAR2(64)            := '_BI_TR';    -- Extension for Before Insert trigger
    g_BuTriggerPrefix VARCHAR2(64)          := '';    		-- Prefix for Before Update trigger
    g_BuTriggerExt  VARCHAR2(64)            := '_BU_TR';    -- Extension for Before Update trigger
    g_InsTriggerPrefix VARCHAR2(64)         := '';    		-- Prefix for Instead Of Insert trigger
    g_InsTriggerExt VARCHAR2(64)            := '_IN_TR';    -- Extension for Instead Of Insert trigger
    g_DelTriggerPrefix VARCHAR2(64)         := '';    		-- Prefix for Instead Of Delete trigger
    g_DelTriggerExt VARCHAR2(64)            := '_DL_TR';    -- Extension for Instead Of Delete trigger
    g_UpdTriggerPrefix VARCHAR2(64)         := '';    		-- Prefix for Instead Of Update trigger
    g_UpdTriggerExt VARCHAR2(64)            := '_UP_TR';    -- Extension for Instead Of Update trigger
    g_SequenceExt   VARCHAR2(64)            := '_SEQ';      -- Extension for Sequences
    g_SequenceColumnExt VARCHAR2(64)        := '_ID';       -- Extension for generated Sequences Columns
    g_SequenceConstraintExt VARCHAR2(64)    := '_SUN$';     -- Extension for Sequences Column Constraint
    g_SequenceOptions VARCHAR2(64)          := 'NOCACHE NOCYCLE'; -- Options for Sequences
    g_AppUserExt   VARCHAR2(64)             := '_APP_USER';  -- Extension for schema name of application user
	g_Interrim_Table_Ext VARCHAR2(64)		:= '_INT';  	-- #NEW# Extension for Interrim Table name

    g_Use_Audit_Info_Columns VARCHAR2(64)   := 'YES';		-- Enable Audit Info Columns (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT) when table is included.
	g_Drop_Audit_Info_Columns VARCHAR2(64)	:= 'NO';		-- Drop Audit Info Columns (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT) when table is excluded.
	g_Use_Audit_Info_Trigger VARCHAR2(64)   := 'YES';		-- Enable Create and Drop operations for Before Insert Triggers and Before Update trigger
    g_Use_Change_Log VARCHAR2(64)     		:= 'NO';		-- Enable Change Log Support (add triggers to selected tables to store the change history in table CHANGE_LOG)
	g_Add_ChangeLog_Views	 VARCHAR2(64) 	:= 'NO';		-- when this option is 'YES' then Change Log Views are generated. The Change Log Views enable access to historic versions of table rows and as of timestamp views of table rows for the managed tables.
    g_Add_WorkspaceID VARCHAR2(64)     		:= 'NO';       -- Enable Application Namespace Support. When this option is 'YES' then a 'WORKSPACE$_ID' Column is added to each selected table. The current workspace is automatically initialized for each inserted row.
    g_Add_Delete_Mark VARCHAR2(64)    		:= 'NO'; 		-- When this option is 'YES' then a 'DELETED_MARK' Column is added to each selected table. The Deleted_Mark is automatically set for each inserted or Deleted row. Views and triggers are added.
    g_Use_Sequences VARCHAR2(64)            := 'YES';		-- Use new SID Columns and Sequences to manage primary key defaults or triggers
	g_Add_Application_Schema VARCHAR2(64) 	:= 'NO';		-- Add a Schema with the postfix _APP_USER with minimal privileges. Application Schema Objects and Privileges are generated in this schema.

	g_Add_Modify_Date VARCHAR2(64) 			:= 'YES'; 		-- When this option is 'YES' then a 'LAST_MODIFIED_AT' Column is added to each selected table. The current timestamp is automatically initialized for each updated row.
	g_Add_Modify_User VARCHAR2(64) 			:= 'YES';		-- When this option is 'YES' then a 'LAST_MODIFIED_BY' Column is added to each selected table. The current user name is automatically inserted for each updated row.
	g_Add_Creation_Date VARCHAR2(64) 		:= 'YES';		-- When this option is 'YES' then a 'CREATED_AT' Column is added to each selected table. The current timestamp is automatically initialized for each inserted row.
	g_Add_Creation_User VARCHAR2(64) 		:= 'YES';		-- When this option is 'YES' then a 'CREATED_BY' Column is added to each selected table. The current user name is automatically inserted for each inserted row.
	g_Enforce_Not_Null VARCHAR2(64) 		:= 'YES';		-- When this option is 'YES' then a NOT NULL constraint is add to each audit info column (CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT).

	g_Add_Insert_Trigger VARCHAR2(64) 		:= 'YES'; 		-- Create instead of INSERT trigger for views with composite primary keys. A merge statement will reactivate deleted rows with the same primary key values
	g_Add_Delete_Trigger VARCHAR2(64) 		:= 'YES';		-- Create instead of delete trigger for views. Mark rows as deleted instead of deleting them.
	g_Add_Update_Trigger1 VARCHAR2(64) 		:= 'YES';		-- Create instead of UPDATE trigger for views without changelog to preserve old values. The current row is marked as deleted and a new row is inserted with the same primary key
	g_Add_Update_Trigger2 VARCHAR2(64) 		:= 'YES';		-- Create instead of UPDATE trigger for views with BLOB columns to preserve old BLOB. The current row is marked as deleted and a new row is inserted with the same primary key

    g_AppUserPassword     VARCHAR2(64)      := '';   		-- Password of the created application user schema
    g_Apex_Workspace_Name VARCHAR2(64)      := '';    		-- Schema of the APEX Workspace used to register the application user schema
    g_Use_On_Null       VARCHAR2(64)        := 'YES';       -- Use DEFAULT ON NULL in Oracle 12c. This ensures that default values will be used in all case that a null value is inserted in a columns with default.
    g_BaseTableSchema   VARCHAR2(128);                      -- Schema Prefix with dot for Base Table names
    g_BaseViewSchema    VARCHAR2(128);                      -- Schema Prefix with dot for Base View names
	g_Include_External_Objects VARCHAR2(64)    := 'NO';		-- Include external objects from other granted schemas
    g_IncludeWorkspaceIDPattern VARCHAR2(4000) := '%';		-- List of table name pattern that are included for 'Application Namespace Support'.
    g_ExcludeWorkspaceIDPattern VARCHAR2(4000) := 'PLUGIN_DELETE_CHECKS,DATA_BROWSER%';		-- List of table name pattern that are excluded from 'Application Namespace Support'.
	g_CIncludeWorkspaceIDPattern CONSTANT VARCHAR2(4000) :=	-- Internal list of table name pattern that are included from 'Application Namespace Support'.
		'USER_NAMESPACES,USER_WORKSPACE_SESSIONS,CHANGE_LOG_USERS,CHANGE_LOG';
    g_CExcludeWorkspaceIDPattern CONSTANT VARCHAR2(4000) :=	-- Internal list of table name pattern that are excluded from 'Application Namespace Support'.
    	'CHANGE_LOG_CONFIG,CHANGE_LOG_TABLES,%PLAN_TABLE%,CHAINED_ROWS,USER_IMPORT_JOBS,%_IMP,'
    	|| 'APP_USERS,APP_USER_LEVELS,APP_PROTOCOL,USER_IMPORT_JOBS,SPRINGY_DIAGRAMS,DIAGRAM_SHAPES,DIAGRAM_NODES,DIAGRAM_EDGES,'
    	|| 'USER_INDEX_STATS$,USER_PROCESS_OUTPUT$,USER_WORKSPACE$_DIFFERENCES,USER_WORKSPACE$_MASTER_TABLES,CREATE$JAVA$LOB$TABLE,'
    	|| 'T_%,%STATIC%,PAYPAL_%,%PARAMETER%,DATA_BROWSER%';

    g_IncludeDeleteMarkPattern VARCHAR2(4000)    := '%';	-- List of table name pattern that are included for 'Soft Delete Support'.
    g_ExcludeDeleteMarkPattern VARCHAR2(4000)    := 'USER_WORKSPACE_SESSIONS,PLUGIN_DELETE_CHECKS,DATA_BROWSER%';		-- List of table name pattern that are excluded from 'Soft Delete Support'.

    g_IncludeTimestampPattern VARCHAR2(4000)    := '%';		-- List of table name pattern that are included for 'Audit Info Columns'.
    g_ExcludeTimestampPattern VARCHAR2(4000)    := '%PROTOCOL%,USER_IMPORT_JOBS,USER_WORKSPACE_SESSIONS,PLUGIN_DELETE_CHECKS,DATA_BROWSER%.APP_%';		-- List of table name pattern that are excluded from 'Audit Info Columns'.

    g_ExcludedTablesPattern CONSTANT VARCHAR2(4000) :=		-- Internal list of table name pattern that are excluded from 'Audit Info Columns' and 'Soft Delete Support'.
    	'CHANGE_LOG%,CHAINED_ROWS,%PLAN_TABLE,%_IMP,PLUGIN_DELETE_CHECKS,%PROTOCOL%,%HISTORY%';

    g_ColumnCreateUser   VARCHAR2(512) := 'CREATED_BY,ERFASST_VON,ERFASST_KUERZEL'; 					-- Column Name for created by user name. the current user name is automatically inserted for each inserted row.
    g_ColumnCreateDate   VARCHAR2(512) := 'CREATED_AT,CREATED,ERFASST_DATUM';       					-- Column Name for Created at Date. The current timestamp is automatically initialized for each inserted row.
    g_ColumnModifyUser   VARCHAR2(512) := 'LAST_MODIFIED_BY,MODIFIED_BY,UPDATED_BY,AENDERUNG_KUERZEL'; 	-- Column Name for last modified by user name. The current user name is automatically inserted for each updated row.
    g_ColumnModifyDate   VARCHAR2(512) := 'LAST_MODIFIED_AT,MODIFIED,UPDATED,CONFIG_TIME,AENDERUNG_DATUM'; -- Column Name for last modified at date. The current timestamp is automatically initialized for each updated row.

    g_ForeignKeyModifyUser VARCHAR2(64) := 'NO';            -- Column for Create Username is a foreign key
    g_Table_App_Users VARCHAR2(64)    := 'V_CONTEXT_USERS'; -- Table name for application users (used in custom_changelog_gen.ChangeLog_Query)
    g_DatatypeModifyUser VARCHAR2(64) := 'VARCHAR2';        -- Datatype for Modification Username
    g_ColumnTypeModifyUser VARCHAR2(64) := 'VARCHAR2(32 CHAR)';  -- Datatype for Modification Username with size
    g_FunctionModifyDate VARCHAR2(300) := 'LOCALTIMESTAMP';    -- Function for current date
    g_FunctionModifyUser VARCHAR2(300) := 'NVL(' || g_ContextUserNameExpr || ', ' || g_SessionUserNameExpr || ')';				-- Function for current user name
    g_DatatypeModifyDate VARCHAR2(64) := 'TIMESTAMP(6) WITH LOCAL TIME ZONE';   -- Datatype for Modification Date with size
    g_AltDatatypeModifyDate VARCHAR2(64) := 'TIMESTAMP(6)'; -- Alternative Datatype for Modification Date with size

    g_ColumnDeletedMark VARCHAR2(64)    := 'DELETED_MARK';  -- Column Name for Deleted Mark
    g_DatatypeDeletedMark VARCHAR2(64)  := 'CHAR';          -- Datatype for Deleted Mark
    g_ColumnTypeDeletedMark VARCHAR2(64) := 'CHAR(4 BYTE)'; -- Datatype for Deleted Mark with size
    g_DefaultDeletedMark VARCHAR2(64)   := 'NULL';          -- Default for Deleted Mark

    g_ColumnIndexFormat VARCHAR2(64) := 'INDEX_FORMAT';     -- index format column for context index

	-- Table name for change log
    g_ChangeLogTable  CONSTANT VARCHAR2(64)   := 'CHANGE_LOG_BT';
    -----------------------------------------------------------------------------
    -- Table name pattern of tables to be included in the change log.
    g_IncludeChangeLogPattern VARCHAR2(4000);
    -- Table name pattern of tables to be excluded in the change log.
    g_ExcludeChangeLogPattern VARCHAR2(4000);
    c_ExcludeChangeLogPattern CONSTANT VARCHAR2(400)    := 'CHANGE_LOG%,USER_IMPORT_JOBS,USER_WORKSPACE_SESSIONS,%HISTORY%,%PROTOCOL%,%PLUGIN%,DATA_BROWSER%';
    -- Tables of interest with direct access in the CHANGE_LOG table. The Columns CUSTOM_REF_ID1 to CUSTOM_REF_ID9 will be defined as References to this tables.
    g_ChangeLogFKeyTables VARCHAR2(4000);
    -- Column Names of the direct References. The Columns CUSTOM_REF_ID1 to CUSTOM_REF_ID9 will be renamed to this names in the views VPROTOCOL_LIST, VPROTOCOL_COLUMNS_LIST and VPROTOCOL_COLUMNS_LIST2
    g_ChangeLogFKeyColumns VARCHAR2(4000);
    -- Column Names for the description of foreign key references in Changelog Report
    g_ReferenceDescriptionCols VARCHAR2(4000)           := '%NAME,%DESCRIPTION,%DESC,%BESCHREIBUNG,%BEZEICHNUNG';

	PROCEDURE Save_Config_Defaults
    IS
    BEGIN
		UPDATE CHANGE_LOG_CONFIG
		SET (TABLE_APP_USERS, USE_AUDIT_INFO_COLUMNS, DROP_AUDIT_INFO_COLUMNS, USE_AUDIT_INFO_TRIGGER,
			USE_CHANGE_LOG, ADD_COLUMN_WORKSPACE_ID, ADD_COLUMN_DELETE_MARK,
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
            BASE_TABLE_EXT, INTERRIM_TABLE_EXT, CHANGE_LOG_TRIGGER_PREFIX, CHANGE_LOG_TRIGGER_EXT,
            BI_TRIGGER_PREFIX, BI_TRIGGER_EXT, BU_TRIGGER_PREFIX, BU_TRIGGER_EXT,
            INS_TRIGGER_PREFIX, INS_TRIGGER_EXT, DEL_TRIGGER_PREFIX, DEL_TRIGGER_EXT, UPD_TRIGGER_PREFIX, UPD_TRIGGER_EXT
        ) = (
        	SELECT g_Table_App_Users, g_Use_Audit_Info_Columns, g_Drop_Audit_Info_Columns, g_Use_Audit_Info_Trigger,
        	g_Use_Change_Log, g_Add_WorkspaceID, g_Add_Delete_Mark,
        	g_Add_Modify_Date, g_Add_Modify_User, g_Add_Creation_Date, g_Add_Creation_User,
        	g_Enforce_Not_Null, g_Add_Insert_Trigger, g_Add_Delete_Trigger, g_Add_Update_Trigger1, g_Add_Update_Trigger2,
        	g_Add_Application_Schema, g_Add_ChangeLog_Views,
            g_Use_On_Null, g_Use_Sequences, g_Include_External_Objects,
            g_IncludeWorkspaceIDPattern, g_ExcludeWorkspaceIDPattern,
			g_IncludeDeleteMarkPattern, g_ExcludeDeleteMarkPattern,
            g_IncludeTimestampPattern, g_ExcludeTimestampPattern,
            g_ColumnWorkspace, g_ColumnCreateUser, g_ColumnCreateDate, g_ColumnModifyUser, g_ColumnModifyDate,
            g_ColumnDeletedMark, g_ColumnIndexFormat,
            g_DatatypeModifyUser, g_ColumnTypeModifyUser, g_ForeignKeyModifyUser,
            g_FunctionModifyUser, g_FunctionModifyDate, g_DatatypeModifyDate, g_AltDatatypeModifyDate,
            g_DatatypeDeletedMark, g_ColumnTypeDeletedMark, g_DefaultDeletedMark,
            g_SequenceExt, g_SequenceColumnExt, g_SequenceConstraintExt, g_SequenceOptions,
            g_BaseTableExt, g_Interrim_Table_Ext, g_ChangelogTriggerPrefix, g_ChangelogTriggerExt,
            g_BiTriggerPrefix, g_BiTriggerExt, g_BuTriggerPrefix, g_BuTriggerExt,
            g_InsTriggerPrefix, g_InsTriggerExt, g_DelTriggerPrefix, g_DelTriggerExt, g_UpdTriggerPrefix, g_UpdTriggerExt
        	FROM DUAL
        )
        WHERE ID = 1;
        COMMIT;
    END;


	PROCEDURE Load_Config
    IS
    BEGIN
        SELECT TABLE_APP_USERS, USE_AUDIT_INFO_COLUMNS, DROP_AUDIT_INFO_COLUMNS, USE_AUDIT_INFO_TRIGGER,
        	USE_CHANGE_LOG, ADD_COLUMN_WORKSPACE_ID, ADD_COLUMN_DELETE_MARK,
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
            BASE_TABLE_EXT, INTERRIM_TABLE_EXT, CHANGE_LOG_TRIGGER_PREFIX, CHANGE_LOG_TRIGGER_EXT,
            BI_TRIGGER_PREFIX, BI_TRIGGER_EXT, BU_TRIGGER_PREFIX, BU_TRIGGER_EXT,
            INS_TRIGGER_PREFIX, INS_TRIGGER_EXT, DEL_TRIGGER_PREFIX, DEL_TRIGGER_EXT, UPD_TRIGGER_PREFIX, UPD_TRIGGER_EXT,
			INCLUDED_CHANGELOG_PATTERN, EXCLUDED_CHANGELOG_PATTERN, CHANGELOG_FKEY_TABLES, CHANGELOG_FKEY_COLUMNS, REFERENCE_DESCRIPTION_COLS
        INTO g_Table_App_Users, g_Use_Audit_Info_Columns, g_Drop_Audit_Info_Columns, g_Use_Audit_Info_Trigger,
        	g_Use_Change_Log, g_Add_WorkspaceID, g_Add_Delete_Mark,
        	g_Add_Modify_Date, g_Add_Modify_User, g_Add_Creation_Date, g_Add_Creation_User,
        	g_Enforce_Not_Null, g_Add_Insert_Trigger, g_Add_Delete_Trigger, g_Add_Update_Trigger1, g_Add_Update_Trigger2,
        	g_Add_Application_Schema, g_Add_ChangeLog_Views,
            g_Use_On_Null, g_Use_Sequences, g_Include_External_Objects,
            g_IncludeWorkspaceIDPattern, g_ExcludeWorkspaceIDPattern,
            g_IncludeDeleteMarkPattern, g_ExcludeDeleteMarkPattern,
            g_IncludeTimestampPattern, g_ExcludeTimestampPattern,
            g_ColumnWorkspace, g_ColumnCreateUser, g_ColumnCreateDate, g_ColumnModifyUser, g_ColumnModifyDate,
            g_ColumnDeletedMark, g_ColumnIndexFormat,
            g_DatatypeModifyUser, g_ColumnTypeModifyUser, g_ForeignKeyModifyUser,
            g_FunctionModifyUser, g_FunctionModifyDate, g_DatatypeModifyDate, g_AltDatatypeModifyDate,
            g_DatatypeDeletedMark, g_ColumnTypeDeletedMark, g_DefaultDeletedMark,
            g_SequenceExt, g_SequenceColumnExt, g_SequenceConstraintExt, g_SequenceOptions,
            g_BaseTableExt, g_Interrim_Table_Ext, g_ChangelogTriggerPrefix, g_ChangelogTriggerExt,
            g_BiTriggerPrefix, g_BiTriggerExt, g_BuTriggerPrefix, g_BuTriggerExt,
            g_InsTriggerPrefix, g_InsTriggerExt, g_DelTriggerPrefix, g_DelTriggerExt, g_UpdTriggerPrefix, g_UpdTriggerExt,
			g_IncludeChangeLogPattern, g_ExcludeChangeLogPattern, g_ChangeLogFKeyTables, g_ChangeLogFKeyColumns, g_ReferenceDescriptionCols
        FROM CHANGE_LOG_CONFIG
        WHERE ID = 1;
    EXCEPTION WHEN NO_DATA_FOUND THEN
    	NULL;
    END;

	FUNCTION FN_Pipe_References_Count
	RETURN changelog_conf.tab_references_count PIPELINED PARALLEL_ENABLE
	IS
		PRAGMA UDF;
		CURSOR all_refs_cur
		IS 	
			SELECT /*+ RESULT_CACHE */
				A.R_CONSTRAINT_NAME, 
				A.R_OWNER,
				COUNT(*) CNT
			FROM SYS.ALL_CONSTRAINTS A 
			WHERE A.CONSTRAINT_TYPE = 'R' 
			GROUP BY A.R_CONSTRAINT_NAME, A.R_OWNER;

		CURSOR user_refs_cur
		IS 	
			SELECT /*+ RESULT_CACHE */
				A.R_CONSTRAINT_NAME, 
				A.R_OWNER,
				COUNT(*) CNT -- key is referenced in a foreign key clause
			FROM SYS.USER_CONSTRAINTS A 
			WHERE A.CONSTRAINT_TYPE = 'R' 
			AND A.R_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
			GROUP BY A.R_CONSTRAINT_NAME, A.R_OWNER;

		v_in_rows tab_references_count;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		if g_Include_External_Objects = 'YES' then 
			OPEN all_refs_cur;
			LOOP
				FETCH all_refs_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_refs_cur;  
		else
			OPEN user_refs_cur;
			LOOP
				FETCH user_refs_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_refs_cur;  
		end if;
	END FN_Pipe_References_Count;

	FUNCTION FN_Pipe_insert_triggers 
	RETURN changelog_conf.tab_insert_triggers PIPELINED PARALLEL_ENABLE
	IS
        CURSOR trigger_cur
        IS
			SELECT T.TABLE_NAME, T.TABLE_OWNER, T.TRIGGER_BODY, 
				S.REFERENCED_OWNER SEQUENCE_OWNER, 
				S.REFERENCED_NAME SEQUENCE_NAME
			FROM (
				SELECT /*+ USE_MERGE(T S) */
					T.TABLE_NAME, T.TABLE_OWNER, T.TRIGGER_NAME, T.TRIGGER_BODY TRIGGER_BODY
				FROM SYS.USER_TRIGGERS T
				WHERE T.BASE_OBJECT_TYPE = 'TABLE'
				AND T.TRIGGER_TYPE IN ('BEFORE EACH ROW','COMPOUND')
				AND INSTR(T.TRIGGERING_EVENT, 'INSERT') > 0
				AND T.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
				UNION ALL
				SELECT T.TABLE_NAME, T.TABLE_OWNER, T.TRIGGER_NAME, T.TRIGGER_BODY TRIGGER_BODY
				FROM SYS.ALL_TRIGGERS T
        		JOIN SYS.ALL_TAB_PRIVS G ON T.TABLE_NAME = G.TABLE_NAME AND T.TABLE_OWNER = G.GRANTOR 
				WHERE T.BASE_OBJECT_TYPE = 'TABLE'
				AND T.TRIGGER_TYPE IN ('BEFORE EACH ROW','COMPOUND')
				AND INSTR(T.TRIGGERING_EVENT, 'INSERT') > 0
				and G.TYPE = 'TABLE'
				and G.GRANTEE IN ('PUBLIC', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'))
			) T
			, SYS.ALL_DEPENDENCIES S
			WHERE S.REFERENCED_TYPE (+) = 'SEQUENCE'
				AND S.TYPE (+) = 'TRIGGER'
				AND S.NAME (+) = T.TRIGGER_NAME
				AND S.OWNER (+) = T.TABLE_OWNER;
				
        CURSOR user_trigger_cur
        IS
			SELECT /*+ USE_MERGE(T S) */
				T.TABLE_NAME, T.TABLE_OWNER, T.TRIGGER_BODY, 
				S.REFERENCED_OWNER SEQUENCE_OWNER, 
				S.REFERENCED_NAME SEQUENCE_NAME
			FROM (
				SELECT T.TABLE_NAME, T.TABLE_OWNER, T.TRIGGER_NAME, T.TRIGGER_BODY TRIGGER_BODY
				FROM SYS.USER_TRIGGERS T
				WHERE T.BASE_OBJECT_TYPE = 'TABLE'
				AND T.TRIGGER_TYPE IN ('BEFORE EACH ROW','COMPOUND')
				AND INSTR(T.TRIGGERING_EVENT, 'INSERT') > 0
				AND T.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
			) T
			, SYS.USER_DEPENDENCIES S
			WHERE S.REFERENCED_TYPE (+) = 'SEQUENCE'
				AND S.TYPE (+) = 'TRIGGER'
				AND S.NAME (+) = T.TRIGGER_NAME;
        TYPE stat_tbl IS TABLE OF trigger_cur%ROWTYPE;
        v_in_rows stat_tbl;
		v_out_row changelog_conf.rec_insert_triggers; -- output row
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		if g_Include_External_Objects = 'YES' then 
			OPEN trigger_cur;
			FETCH trigger_cur BULK COLLECT INTO v_in_rows;
			CLOSE trigger_cur;
        else 
			OPEN user_trigger_cur;
			FETCH user_trigger_cur BULK COLLECT INTO v_in_rows;
			CLOSE user_trigger_cur;  
        end if;
        IF v_in_rows.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_in_rows.COUNT
			loop
				v_out_row.TRIGGER_HAS_NEXTVAL := REGEXP_INSTR(v_in_rows(ind).TRIGGER_BODY, 'NEXTVAL', 1, 1, 1, 'i');
				v_out_row.TRIGGER_HAS_SYS_GUID := REGEXP_INSTR(v_in_rows(ind).TRIGGER_BODY, 'SYS_GUID', 1, 1, 1, 'i');
				if v_out_row.TRIGGER_HAS_NEXTVAL + v_out_row.TRIGGER_HAS_SYS_GUID > 0 then
					v_out_row.TABLE_NAME := v_in_rows(ind).TABLE_NAME;
					v_out_row.TABLE_OWNER := v_in_rows(ind).TABLE_OWNER;
					v_out_row.TRIGGER_BODY := SUBSTR(TO_CLOB(v_in_rows(ind).TRIGGER_BODY), 1, 800); -- special conversion of LONG type; give a margin of 200 bytes for char expansion 
					v_out_row.SEQUENCE_OWNER := v_in_rows(ind).SEQUENCE_OWNER;
					v_out_row.SEQUENCE_NAME := v_in_rows(ind).SEQUENCE_NAME;
					PIPE ROW(v_out_row);
				end if;
			end loop;
        END IF;
	END FN_Pipe_insert_triggers;

	FUNCTION FN_Pipe_base_triggers (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN changelog_conf.tab_base_triggers PIPELINED PARALLEL_ENABLE
	IS
        CURSOR trigger_cur
        IS
		SELECT T.TABLE_NAME, T.TABLE_OWNER, T.TRIGGER_NAME, T.TRIGGERING_EVENT, T.TRIGGER_TYPE,
			T.TRIGGER_BODY,
			CASE WHEN ((T.TRIGGER_TYPE = 'BEFORE EACH ROW'
				AND ((T.TRIGGERING_EVENT = 'INSERT' AND T.TRIGGER_NAME = changelog_conf.Get_BiTrigger_Name(T.TABLE_NAME))
					OR (T.TRIGGERING_EVENT = 'UPDATE' AND T.TRIGGER_NAME = changelog_conf.Get_BuTrigger_Name(T.TABLE_NAME))
					OR (T.TRIGGERING_EVENT = 'DELETE' AND EXISTS (
						SELECT 'X'
						FROM SYS.ALL_CONSTRAINTS FK
						WHERE T.TRIGGER_NAME = FK.CONSTRAINT_NAME
						AND T.TABLE_OWNER = FK.OWNER
						AND FK.CONSTRAINT_TYPE = 'R')
						)
					)
				)
				OR (T.TRIGGER_TYPE = 'COMPOUND'  AND T.TRIGGER_NAME = changelog_conf.Get_ChangelogTrigger_Name(T.TABLE_NAME)
					AND T.TRIGGERING_EVENT = 'INSERT OR UPDATE OR DELETE')
			)
			AND T.REFERENCING_NAMES = 'REFERENCING NEW AS NEW OLD AS OLD'
			THEN 'YES' ELSE 'NO' END IS_CANDIDATE
		FROM SYS.ALL_TRIGGERS T
		WHERE T.BASE_OBJECT_TYPE = 'TABLE';

        CURSOR user_trigger_cur
        IS
		SELECT T.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') TABLE_OWNER, T.TRIGGER_NAME, T.TRIGGERING_EVENT, T.TRIGGER_TYPE,
			T.TRIGGER_BODY,
			CASE WHEN ((T.TRIGGER_TYPE = 'BEFORE EACH ROW'
				AND ((T.TRIGGERING_EVENT = 'INSERT' AND T.TRIGGER_NAME = changelog_conf.Get_BiTrigger_Name(T.TABLE_NAME))
					OR (T.TRIGGERING_EVENT = 'UPDATE' AND T.TRIGGER_NAME = changelog_conf.Get_BuTrigger_Name(T.TABLE_NAME))
					OR (T.TRIGGERING_EVENT = 'DELETE' AND EXISTS (
						SELECT 'X'
						FROM SYS.USER_CONSTRAINTS FK
						WHERE T.TRIGGER_NAME = FK.CONSTRAINT_NAME
						AND T.TABLE_OWNER = FK.OWNER
						AND FK.CONSTRAINT_TYPE = 'R')
						)
					)
				)
				OR (T.TRIGGER_TYPE = 'COMPOUND'  AND T.TRIGGER_NAME = changelog_conf.Get_ChangelogTrigger_Name(T.TABLE_NAME)
					AND T.TRIGGERING_EVENT = 'INSERT OR UPDATE OR DELETE')
			)
			AND T.REFERENCING_NAMES = 'REFERENCING NEW AS NEW OLD AS OLD'
			THEN 'YES' ELSE 'NO' END IS_CANDIDATE
		FROM SYS.USER_TRIGGERS T
		WHERE T.BASE_OBJECT_TYPE = 'TABLE'
		AND T.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        
        TYPE stat_tbl IS TABLE OF trigger_cur%ROWTYPE;
        v_in_rows stat_tbl;
		v_out_row changelog_conf.rec_base_triggers; -- output row
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		if g_Include_External_Objects = 'YES' then 
			OPEN trigger_cur;
			FETCH trigger_cur BULK COLLECT INTO v_in_rows;
			CLOSE trigger_cur;
        else 
			OPEN user_trigger_cur;
			FETCH user_trigger_cur BULK COLLECT INTO v_in_rows;
			CLOSE user_trigger_cur;  
        end if;
        IF v_in_rows.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_in_rows.COUNT
			loop
				v_out_row.TABLE_NAME := v_in_rows(ind).TABLE_NAME;
				v_out_row.TABLE_OWNER := v_in_rows(ind).TABLE_OWNER;
				v_out_row.TRIGGER_NAME := v_in_rows(ind).TRIGGER_NAME;
				v_out_row.TRIGGERING_EVENT := v_in_rows(ind).TRIGGERING_EVENT;
				v_out_row.TRIGGER_TYPE := v_in_rows(ind).TRIGGER_TYPE;
				v_out_row.TRIGGER_BODY := SUBSTR(TO_CLOB(v_in_rows(ind).TRIGGER_BODY), 1, 3500); -- special conversion of LONG type; give a margin of 200 bytes for char expansion 
				v_out_row.IS_CANDIDATE := v_in_rows(ind).IS_CANDIDATE;
				PIPE ROW(v_out_row);
			end loop;
        END IF;
	END FN_Pipe_base_triggers;


	FUNCTION FN_Pipe_views_triggers (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN changelog_conf.tab_views_triggers PIPELINED PARALLEL_ENABLE
	IS
        CURSOR trigger_cur
        IS
		SELECT R.TABLE_NAME,
			MAX(CASE WHEN R.TRIGGERING_EVENT = 'INSERT'
				AND R.TRIGGER_NAME LIKE changelog_conf.Get_InsTrigger_Name('%')
				THEN  R.TRIGGER_NAME END
			) VIEW_INSERT_TRIGGER_NAME,
			MAX(CASE WHEN R.TRIGGERING_EVENT = 'UPDATE'
				AND R.TRIGGER_NAME LIKE changelog_conf.Get_UpdTrigger_Name('%')
				THEN  R.TRIGGER_NAME END
			) VIEW_UPDATE_TRIGGER_NAME,
			MAX(CASE WHEN R.TRIGGERING_EVENT = 'DELETE'
				AND R.TRIGGER_NAME LIKE changelog_conf.Get_DelTrigger_Name('%')
				THEN  R.TRIGGER_NAME END
			) VIEW_DELETE_TRIGGER_NAME
		FROM SYS.USER_TRIGGERS R
		WHERE R.BASE_OBJECT_TYPE = 'VIEW'
		AND R.TRIGGER_TYPE = 'INSTEAD OF'
		AND R.REFERENCING_NAMES = 'REFERENCING NEW AS NEW OLD AS OLD'
		AND R.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
		GROUP BY R.TABLE_NAME;

        v_in_rows changelog_conf.tab_views_triggers;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN trigger_cur;
		FETCH trigger_cur BULK COLLECT INTO v_in_rows;
		CLOSE trigger_cur;
        IF v_in_rows.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_in_rows.COUNT
			loop
				PIPE ROW(v_in_rows(ind));
			end loop;
        END IF;
	END FN_Pipe_views_triggers;

	FUNCTION FN_Pipe_unique_keys 
	RETURN changelog_conf.tab_unique_keys PIPELINED PARALLEL_ENABLE
	IS
        CURSOR keys_cur
        IS
			SELECT /*+ RESULT_CACHE PARALLEL USE_MERGE(B C D) */
				C.TABLE_NAME, C.OWNER TABLE_OWNER, C.CONSTRAINT_NAME, B.CONSTRAINT_TYPE, C.COLUMN_NAME, C.POSITION,
				D.DATA_DEFAULT DEFAULT_TEXT,
				D.COLUMN_ID, D.DATA_TYPE, D.NULLABLE, D.DATA_PRECISION, D.DATA_SCALE, 
				D.CHAR_LENGTH, D.DEFAULT_LENGTH, D.VIRTUAL_COLUMN,
				B.INDEX_OWNER, B.INDEX_NAME, B.DEFERRABLE, B.DEFERRED, B.STATUS, B.VALIDATED
			FROM SYS.ALL_CONSTRAINTS B
			JOIN SYS.ALL_CONS_COLUMNS C ON C.TABLE_NAME = B.TABLE_NAME AND C.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND C.OWNER = B.OWNER
			JOIN SYS.ALL_TAB_COLS D ON C.TABLE_NAME = D.TABLE_NAME AND C.COLUMN_NAME = D.COLUMN_NAME AND C.OWNER = D.OWNER
			WHERE B.CONSTRAINT_TYPE IN ('P', 'U')
			AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
			AND D.HIDDEN_COLUMN = 'NO'
			AND B.VIEW_RELATED IS NULL
			AND B.OWNER NOT IN ('SYS', 'SYSTEM', 'SYSAUX', 'CTXSYS', 'MDSYS', 'OUTLN');
        CURSOR user_keys_cur
        IS
			SELECT /*+ RESULT_CACHE PARALLEL USE_MERGE(B C D) */
				C.TABLE_NAME, C.OWNER TABLE_OWNER, C.CONSTRAINT_NAME, B.CONSTRAINT_TYPE, C.COLUMN_NAME, C.POSITION,
				D.DATA_DEFAULT DEFAULT_TEXT,
				D.COLUMN_ID, D.DATA_TYPE, D.NULLABLE, D.DATA_PRECISION, D.DATA_SCALE, 
				D.CHAR_LENGTH, D.DEFAULT_LENGTH, D.VIRTUAL_COLUMN,
				B.INDEX_OWNER, B.INDEX_NAME, B.DEFERRABLE, B.DEFERRED, B.STATUS, B.VALIDATED
			FROM SYS.USER_CONSTRAINTS B
			JOIN SYS.USER_CONS_COLUMNS C ON C.TABLE_NAME = B.TABLE_NAME AND C.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND C.OWNER = B.OWNER
			JOIN SYS.USER_TAB_COLS D ON C.TABLE_NAME = D.TABLE_NAME AND C.COLUMN_NAME = D.COLUMN_NAME 
			WHERE B.CONSTRAINT_TYPE IN ('P', 'U')
			AND B.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
			AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
			AND D.HIDDEN_COLUMN = 'NO'
			AND B.VIEW_RELATED IS NULL;

		v_row changelog_conf.rec_unique_keys; -- output row
        TYPE stat_tbl IS TABLE OF keys_cur%ROWTYPE;
        v_in_rows stat_tbl;
        v_exclude_cols_pattern VARCHAR2(4000);
		v_exclude_cols_Array apex_t_varchar2;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		v_exclude_cols_pattern := changelog_conf.Concat_List(changelog_conf.Get_ColumnWorkspace_List, changelog_conf.Get_ColumnDeletedMark_List);
		v_exclude_cols_Array := apex_string.split(REPLACE(v_exclude_cols_pattern,'_','\_'), ',');
		if g_Include_External_Objects = 'YES' then 
			OPEN keys_cur;
			FETCH keys_cur BULK COLLECT INTO v_in_rows;
			CLOSE keys_cur;
        else 
			OPEN user_keys_cur;
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows;
			CLOSE user_keys_cur;  
        end if;
        IF v_in_rows.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_in_rows.COUNT
			loop
				v_row.TABLE_NAME := v_in_rows(ind).TABLE_NAME;
				v_row.TABLE_OWNER := v_in_rows(ind).TABLE_OWNER;
				v_row.CONSTRAINT_NAME := v_in_rows(ind).CONSTRAINT_NAME;
				v_row.CONSTRAINT_TYPE := v_in_rows(ind).CONSTRAINT_TYPE;
				v_row.COLUMN_NAME := v_in_rows(ind).COLUMN_NAME;
				v_row.POSITION := v_in_rows(ind).POSITION;
				v_row.DEFAULT_TEXT := RTRIM(SUBSTR(TO_CLOB(v_in_rows(ind).DEFAULT_TEXT), 1, 800)); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
				v_row.VIEW_COLUMN_NAME := CASE 
					WHEN changelog_conf.Match_Column_Pattern(v_in_rows(ind).COLUMN_NAME, v_exclude_cols_Array) = 'NO'
						THEN v_in_rows(ind).COLUMN_NAME END;
				v_row.COLUMN_ID := v_in_rows(ind).COLUMN_ID;
				v_row.DATA_TYPE := v_in_rows(ind).DATA_TYPE;
				v_row.NULLABLE := v_in_rows(ind).NULLABLE;
				v_row.DATA_PRECISION := v_in_rows(ind).DATA_PRECISION;
				v_row.DATA_SCALE := v_in_rows(ind).DATA_SCALE;
				v_row.CHAR_LENGTH := v_in_rows(ind).CHAR_LENGTH;
				v_row.DEFAULT_LENGTH := v_in_rows(ind).DEFAULT_LENGTH;
				v_row.VIRTUAL_COLUMN := v_in_rows(ind).VIRTUAL_COLUMN;
				v_row.INDEX_OWNER := v_in_rows(ind).INDEX_OWNER;
				v_row.INDEX_NAME := v_in_rows(ind).INDEX_NAME;
				v_row.DEFERRABLE := v_in_rows(ind).DEFERRABLE;
				v_row.DEFERRED := v_in_rows(ind).DEFERRED;
				v_row.STATUS := v_in_rows(ind).STATUS;
				v_row.VALIDATED := v_in_rows(ind).VALIDATED;
				PIPE ROW(v_row);
			end loop;
        END IF;
		RETURN;
	END FN_Pipe_unique_keys;

	FUNCTION FN_Pipe_unique_indexes 
	RETURN changelog_conf.tab_unique_keys PIPELINED PARALLEL_ENABLE
	IS
        CURSOR keys_cur
        IS
			SELECT /*+ RESULT_CACHE USE_MERGE(B C D) */
				B.TABLE_NAME, B.TABLE_OWNER, SUBSTR(C.INDEX_NAME, 1, 27) || '_IC' CONSTRAINT_NAME, 'U' CONSTRAINT_TYPE, C.COLUMN_NAME, C.COLUMN_POSITION POSITION,
				D.DATA_DEFAULT DEFAULT_TEXT,
				D.COLUMN_ID, D.DATA_TYPE, D.NULLABLE, D.DATA_PRECISION, D.DATA_SCALE, 
				D.CHAR_LENGTH, D.DEFAULT_LENGTH, D.VIRTUAL_COLUMN,
				B.OWNER INDEX_OWNER, B.INDEX_NAME, 'NOT DEFERRABLE' DEFERRABLE, 'IMMEDIATE' DEFERRED, 
				case when B.STATUS = 'VALID' then 'ENABLED' else 'DISABLED' end STATUS, 
				case when B.STATUS = 'VALID' then 'VALIDATED' else 'NOT VALIDATED' end VALIDATED
			FROM SYS.ALL_INDEXES B, SYS.ALL_IND_COLUMNS C, SYS.ALL_TAB_COLS D
			WHERE C.TABLE_NAME = B.TABLE_NAME AND C.INDEX_NAME = B.INDEX_NAME AND C.TABLE_OWNER = B.TABLE_OWNER
			AND C.TABLE_NAME = D.TABLE_NAME AND C.COLUMN_NAME = D.COLUMN_NAME AND C.TABLE_OWNER = D.OWNER
			AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND D.HIDDEN_COLUMN = 'NO'
			AND B.UNIQUENESS = 'UNIQUE'
			AND B.INDEX_TYPE IN ('NORMAL', 'FUNCTION-BASED NORMAL')
$IF DBMS_DB_VERSION.VERSION >= 19 $THEN			
			AND B.CONSTRAINT_INDEX = 'NO'
$END
			AND C.TABLE_OWNER NOT IN ('SYS', 'SYSTEM', 'SYSAUX', 'CTXSYS', 'MDSYS', 'OUTLN');
        CURSOR user_keys_cur
        IS
			SELECT  /*+ RESULT_CACHE USE_MERGE(B C D) */
				B.TABLE_NAME, B.TABLE_OWNER, 
				SUBSTR(C.INDEX_NAME, 1, 27) || '_IC' CONSTRAINT_NAME, 'U' CONSTRAINT_TYPE, C.COLUMN_NAME, C.COLUMN_POSITION POSITION,
				D.DATA_DEFAULT DEFAULT_TEXT,
				D.COLUMN_ID, D.DATA_TYPE, D.NULLABLE, D.DATA_PRECISION, D.DATA_SCALE, 
				D.CHAR_LENGTH, D.DEFAULT_LENGTH, D.VIRTUAL_COLUMN,
				SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') INDEX_OWNER, B.INDEX_NAME, 'NOT DEFERRABLE' DEFERRABLE, 'IMMEDIATE' DEFERRED, 
				case when B.STATUS = 'VALID' then 'ENABLED' else 'DISABLED' end STATUS, 
				case when B.STATUS = 'VALID' then 'VALIDATED' else 'NOT VALIDATED' end VALIDATED
			FROM SYS.USER_INDEXES B, SYS.USER_IND_COLUMNS C, SYS.USER_TAB_COLS D
			WHERE C.TABLE_NAME = B.TABLE_NAME AND C.INDEX_NAME = B.INDEX_NAME
			AND C.TABLE_NAME = D.TABLE_NAME AND C.COLUMN_NAME = D.COLUMN_NAME
			AND D.HIDDEN_COLUMN = 'NO'
			AND B.UNIQUENESS = 'UNIQUE'
			AND B.INDEX_TYPE IN ('NORMAL', 'FUNCTION-BASED NORMAL')
$IF DBMS_DB_VERSION.VERSION >= 19 $THEN			
			AND B.CONSTRAINT_INDEX = 'NO'
$END
			;
		v_row changelog_conf.rec_unique_keys; -- output row
        TYPE stat_tbl IS TABLE OF keys_cur%ROWTYPE;
        v_in_rows stat_tbl;
        v_exclude_cols_pattern VARCHAR2(4000);
		v_exclude_cols_Array apex_t_varchar2;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		v_exclude_cols_pattern := changelog_conf.Concat_List(changelog_conf.Get_ColumnWorkspace_List, changelog_conf.Get_ColumnDeletedMark_List);
		v_exclude_cols_Array := apex_string.split(REPLACE(v_exclude_cols_pattern,'_','\_'), ',');
		if g_Include_External_Objects = 'YES' then 
			OPEN keys_cur;
			FETCH keys_cur BULK COLLECT INTO v_in_rows;
			CLOSE keys_cur;
        else 
			OPEN user_keys_cur;
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows;
			CLOSE user_keys_cur;  
        end if;
        IF v_in_rows.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_in_rows.COUNT
			loop
				v_row.TABLE_NAME := v_in_rows(ind).TABLE_NAME;
				v_row.TABLE_OWNER := v_in_rows(ind).TABLE_OWNER;
				v_row.CONSTRAINT_NAME := v_in_rows(ind).CONSTRAINT_NAME;
				v_row.CONSTRAINT_TYPE := v_in_rows(ind).CONSTRAINT_TYPE;
				v_row.COLUMN_NAME := v_in_rows(ind).COLUMN_NAME;
				v_row.POSITION := v_in_rows(ind).POSITION;
				v_row.DEFAULT_TEXT := RTRIM(SUBSTR(TO_CLOB(v_in_rows(ind).DEFAULT_TEXT), 1, 800)); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
				v_row.VIEW_COLUMN_NAME := CASE 
					WHEN changelog_conf.Match_Column_Pattern(v_in_rows(ind).COLUMN_NAME, v_exclude_cols_Array) = 'NO'
						THEN v_in_rows(ind).COLUMN_NAME END;
				v_row.COLUMN_ID := v_in_rows(ind).COLUMN_ID;
				v_row.DATA_TYPE := v_in_rows(ind).DATA_TYPE;
				v_row.NULLABLE := v_in_rows(ind).NULLABLE;
				v_row.DATA_PRECISION := v_in_rows(ind).DATA_PRECISION;
				v_row.DATA_SCALE := v_in_rows(ind).DATA_SCALE;
				v_row.CHAR_LENGTH := v_in_rows(ind).CHAR_LENGTH;
				v_row.DEFAULT_LENGTH := v_in_rows(ind).DEFAULT_LENGTH;
				v_row.VIRTUAL_COLUMN := v_in_rows(ind).VIRTUAL_COLUMN;
				v_row.INDEX_OWNER := v_in_rows(ind).INDEX_OWNER;
				v_row.INDEX_NAME := v_in_rows(ind).INDEX_NAME;
				v_row.DEFERRABLE := v_in_rows(ind).DEFERRABLE;
				v_row.DEFERRED := v_in_rows(ind).DEFERRED;
				v_row.STATUS := v_in_rows(ind).STATUS;
				v_row.VALIDATED := v_in_rows(ind).VALIDATED;
				PIPE ROW(v_row);
			end loop;
        END IF;
		RETURN;
	END FN_Pipe_unique_indexes;


	FUNCTION FN_Pipe_Base_Uniquekeys	-- result is cached in MVBASE_UNIQUE_KEYS
	RETURN changelog_conf.tab_base_unique_keys PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_keys_cur
        IS
		WITH U_CONSTRAINTS AS (
			select * from table ( changelog_conf.FN_Pipe_unique_keys)  where VIEW_COLUMN_NAME IS NOT NULL
		) -------------------------------------------------------------------------------
		SELECT /*+ RESULT_CACHE */
			TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, REQUIRED, HAS_NULLABLE,
			NVL(KEY_HAS_WORKSPACE_ID, 'NO') KEY_HAS_WORKSPACE_ID, 
			NVL(KEY_HAS_DELETE_MARK, 'NO') KEY_HAS_DELETE_MARK, 
			NVL(KEY_HAS_NEXTVAL, 'NO') KEY_HAS_NEXTVAL, 
			NVL(KEY_HAS_SYS_GUID, 'NO') KEY_HAS_SYS_GUID, 
			HAS_SCALAR_KEY, HAS_SERIAL_KEY, HAS_SCALAR_VIEW_KEY, HAS_SERIAL_VIEW_KEY,
			NVL(TRIGGER_HAS_NEXTVAL, 'NO') TRIGGER_HAS_NEXTVAL, 
			NVL(TRIGGER_HAS_SYS_GUID, 'NO') TRIGGER_HAS_SYS_GUID, 
			SEQUENCE_OWNER, SEQUENCE_NAME,
			DEFERRABLE, DEFERRED, STATUS, VALIDATED,
			VIEW_KEY_COLS, UNIQUE_KEY_COLS, KEY_COLS_COUNT, VIEW_KEY_COLS_COUNT, INDEX_OWNER, INDEX_NAME,
			RTRIM(SUBSTR(BASE_NAME, 1, 23), '_' || RUN_NO) || RUN_NO SHORT_NAME,
			BASE_NAME, RUN_NO
		FROM (
			SELECT TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, REQUIRED, HAS_NULLABLE,
				KEY_HAS_WORKSPACE_ID, KEY_HAS_DELETE_MARK,
				KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID,
				case when HAS_SCALAR_KEY = 'YES' and KEY_COLS_COUNT = 1 
					then 'YES' else 'NO' 
				end HAS_SCALAR_KEY,
				case when HAS_SCALAR_KEY = 'YES' and KEY_COLS_COUNT = 1 and COALESCE(KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID, TRIGGER_HAS_ASSIGN_ID) = 'YES'
					then 'YES' else 'NO'
				end HAS_SERIAL_KEY,
				case when HAS_SCALAR_VIEW_KEY = 'YES' and VIEW_KEY_COLS_COUNT = 1
					then 'YES' else 'NO'
				end HAS_SCALAR_VIEW_KEY,
				case when HAS_SCALAR_VIEW_KEY = 'YES' and VIEW_KEY_COLS_COUNT = 1 and COALESCE(KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID, TRIGGER_HAS_ASSIGN_ID) = 'YES'
					then 'YES' else 'NO'
				end HAS_SERIAL_VIEW_KEY,
				TRIGGER_HAS_NEXTVAL, TRIGGER_HAS_SYS_GUID,
				CAST(NVL(DEFAULT_SEQUENCE_OWNER, SEQUENCE_OWNER) AS VARCHAR2(128)) SEQUENCE_OWNER,
				CAST(NVL(DEFAULT_SEQUENCE_NAME, SEQUENCE_NAME) AS VARCHAR2(128)) SEQUENCE_NAME,
				DEFERRABLE, DEFERRED, STATUS, VALIDATED,
				VIEW_KEY_COLS, UNIQUE_KEY_COLS, KEY_COLS_COUNT, VIEW_KEY_COLS_COUNT, INDEX_OWNER, INDEX_NAME,
				changelog_conf.Get_BaseName(TABLE_NAME) BASE_NAME,
				NULLIF(DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(TABLE_NAME, 1, 23), '_') ORDER BY NLSSORT(TABLE_NAME, 'NLS_SORT = WEST_EUROPEAN')), 1) RUN_NO
			FROM (
				SELECT -- The Constraint of interest
					TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE,
					case when CONSTRAINT_TYPE = 'P' then 'Y'
						when COUNT(DISTINCT COLUMN_NAME) = SUM(case when NULLABLE = 'Y' then 0 else 1 end) then 'Y'
						else 'N'
					end REQUIRED,
					SUM(case when NULLABLE = 'Y' then 1 else 0 end) HAS_NULLABLE,
					MAX(KEY_HAS_WORKSPACE_ID)  KEY_HAS_WORKSPACE_ID,
					MAX(KEY_HAS_DELETE_MARK)  KEY_HAS_DELETE_MARK,
					MAX(CASE WHEN DEFAULT_SEQUENCE_NAME IS NOT NULL THEN 'YES' END) KEY_HAS_NEXTVAL,
					MAX(CASE WHEN REGEXP_INSTR(DEFAULT_TEXT, 'SYS_GUID', 1, 1, 1, 'i') > 0 THEN 'YES' END) KEY_HAS_SYS_GUID,
					MAX(HAS_SCALAR_KEY) HAS_SCALAR_KEY,
					MAX(HAS_SCALAR_VIEW_KEY) HAS_SCALAR_VIEW_KEY,
					MAX(TRIGGER_HAS_NEXTVAL) TRIGGER_HAS_NEXTVAL,
					MAX(TRIGGER_HAS_SYS_GUID) TRIGGER_HAS_SYS_GUID,
					MAX(TRIGGER_HAS_ASSIGN_ID) TRIGGER_HAS_ASSIGN_ID,
					MAX(SEQUENCE_OWNER) SEQUENCE_OWNER,
					MAX(SEQUENCE_NAME) SEQUENCE_NAME,
					MAX(DEFAULT_SEQUENCE_OWNER) DEFAULT_SEQUENCE_OWNER,
					MAX(DEFAULT_SEQUENCE_NAME) DEFAULT_SEQUENCE_NAME,
					DEFERRABLE, DEFERRED, STATUS, VALIDATED,
					CAST(LISTAGG(VIEW_COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY POSITION) AS VARCHAR2(512)) VIEW_KEY_COLS,
					CAST(LISTAGG(COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY POSITION) AS VARCHAR2(512)) UNIQUE_KEY_COLS,
					COUNT(DISTINCT COLUMN_NAME) KEY_COLS_COUNT,
					COUNT(DISTINCT VIEW_COLUMN_NAME) VIEW_KEY_COLS_COUNT,
					MAX(INDEX_OWNER) INDEX_OWNER, 
					MAX(INDEX_NAME) INDEX_NAME
				FROM (
					SELECT TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, 
						COLUMN_NAME, VIEW_COLUMN_NAME, POSITION, DEFAULT_TEXT,
						CASE WHEN COLUMN_NAME = changelog_conf.Get_ColumnWorkspace THEN 'YES' END  KEY_HAS_WORKSPACE_ID,
						CASE WHEN COLUMN_NAME = changelog_conf.Get_ColumnDeletedMark THEN 'YES' END  KEY_HAS_DELETE_MARK,
						CASE WHEN DATA_TYPE = 'NUMBER'
							AND NVL(DATA_SCALE, 0 ) = 0
							AND (NULLABLE = 'N' OR CONSTRAINT_TYPE = 'P')
							THEN 'YES' 
						END HAS_SCALAR_KEY,
						CASE WHEN DATA_TYPE = 'NUMBER'
							AND NVL(DATA_SCALE, 0 ) = 0
							AND (NULLABLE = 'N' OR CONSTRAINT_TYPE = 'P')
							AND VIEW_COLUMN_NAME IS NOT NULL 
							THEN 'YES' 
						END HAS_SCALAR_VIEW_KEY,
						NULLABLE, INDEX_OWNER, INDEX_NAME, DEFERRABLE, DEFERRED, STATUS, VALIDATED,
						DEFAULT_SEQUENCE_OWNER, DEFAULT_SEQUENCE_NAME, 
						case when TRIGGER_HAS_NEXTVAL > 0 and TRIGGER_HAS_ASSIGN_ID > 0 then 'YES' end TRIGGER_HAS_NEXTVAL,
						case when TRIGGER_HAS_SYS_GUID > 0 and TRIGGER_HAS_ASSIGN_ID > 0 then 'YES' end TRIGGER_HAS_SYS_GUID,
						case when TRIGGER_HAS_ASSIGN_ID > 0 then 'YES' end TRIGGER_HAS_ASSIGN_ID,
						SEQUENCE_OWNER, SEQUENCE_NAME
					FROM (
						SELECT  /*+ USE_MERGE(T TR) */
							T.TABLE_NAME, T.TABLE_OWNER, T.CONSTRAINT_NAME, T.CONSTRAINT_TYPE, T.COLUMN_NAME, T.POSITION,
							T.DEFAULT_TEXT, T.VIEW_COLUMN_NAME, T.DATA_TYPE, T.NULLABLE, T.DATA_SCALE,
								T.INDEX_OWNER, T.INDEX_NAME, T.DEFERRABLE, T.DEFERRED, T.STATUS, T.VALIDATED,
							CASE WHEN REGEXP_INSTR(T.DEFAULT_TEXT, 'NEXTVAL', 1, 1, 1, 'i') > 0 THEN changelog_conf.Get_Name_Part(T.DEFAULT_TEXT, 1) END DEFAULT_SEQUENCE_OWNER,
							CASE WHEN REGEXP_INSTR(T.DEFAULT_TEXT, 'NEXTVAL', 1, 1, 1, 'i') > 0 THEN changelog_conf.Get_Name_Part(T.DEFAULT_TEXT, 2) END DEFAULT_SEQUENCE_NAME,
							MAX(TR.TRIGGER_HAS_NEXTVAL) TRIGGER_HAS_NEXTVAL,
							MAX(TR.TRIGGER_HAS_SYS_GUID) TRIGGER_HAS_SYS_GUID,
							MAX(REGEXP_INSTR(TR.TRIGGER_BODY, ':new.' || COLUMN_NAME || '\s*:=', 1, 1, 1, 'i') 
							+ REGEXP_INSTR(TR.TRIGGER_BODY, 'into\s*:new.' || COLUMN_NAME, 1, 1, 1, 'i')) TRIGGER_HAS_ASSIGN_ID,
							MAX(TR.SEQUENCE_OWNER) SEQUENCE_OWNER, 
							MAX(TR.SEQUENCE_NAME) SEQUENCE_NAME
						FROM (
							SELECT TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, COLUMN_NAME, POSITION, DEFAULT_TEXT, VIEW_COLUMN_NAME,
								DATA_TYPE, NULLABLE, DATA_SCALE, INDEX_OWNER, INDEX_NAME, DEFERRABLE, DEFERRED, STATUS, VALIDATED
							FROM U_CONSTRAINTS
							UNION ALL
							SELECT TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, COLUMN_NAME, POSITION, DEFAULT_TEXT, VIEW_COLUMN_NAME,
								DATA_TYPE, NULLABLE, DATA_SCALE, INDEX_OWNER, INDEX_NAME, DEFERRABLE, DEFERRED, STATUS, VALIDATED
							FROM table ( changelog_conf.FN_Pipe_unique_indexes ) B
							where NOT EXISTS (
								SELECT 1
								FROM U_CONSTRAINTS E
								WHERE E.TABLE_NAME = B.TABLE_NAME
								AND E.INDEX_NAME = B.INDEX_NAME
								AND E.INDEX_OWNER = B.TABLE_OWNER
							)
						) T
						LEFT OUTER JOIN table ( changelog_conf.FN_Pipe_insert_triggers ) TR
							ON T.TABLE_NAME = TR.TABLE_NAME AND T.TABLE_OWNER = TR.TABLE_OWNER
						WHERE NOT EXISTS (    -- this table is not part of materialized view
							SELECT 
								1
							FROM ALL_OBJECTS MV
							WHERE MV.OBJECT_NAME = T.TABLE_NAME
							AND MV.OWNER = T.TABLE_OWNER
							AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
						)					
						GROUP BY T.TABLE_NAME, T.TABLE_OWNER, T.CONSTRAINT_NAME, T.CONSTRAINT_TYPE, T.COLUMN_NAME, T.POSITION,
							T.DEFAULT_TEXT, T.VIEW_COLUMN_NAME, T.DATA_TYPE, T.NULLABLE, T.DATA_SCALE,
							T.INDEX_OWNER, T.INDEX_NAME, T.DEFERRABLE, T.DEFERRED, T.STATUS, T.VALIDATED
					) T
				) C
				GROUP BY TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, DEFERRABLE, DEFERRED, STATUS, VALIDATED
			)
		);
		v_in_rows tab_base_unique_keys;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN user_keys_cur;
		LOOP
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE user_keys_cur;  
	END FN_Pipe_Base_Uniquekeys;

	FUNCTION FN_Pipe_Base_Uniquekeys (
		p_cur changelog_conf.cur_base_unique_keys
	)
	RETURN changelog_conf.tab_base_unique_keys PIPELINED PARALLEL_ENABLE
	IS
		v_row changelog_conf.rec_base_unique_keys; -- output row
	BEGIN 
		loop
			FETCH p_cur INTO v_row;
			EXIT WHEN p_cur%NOTFOUND;
			PIPE ROW(v_row);
		end loop;
		CLOSE p_cur;
		RETURN;
	END FN_Pipe_Base_Uniquekeys;


	FUNCTION FN_Pipe_Table_AlterUniquekeys (
		p_cur_unique_keys changelog_conf.cur_base_unique_keys
	)
	RETURN changelog_conf.tab_alter_unique_keys PIPELINED PARALLEL_ENABLE
	IS
        CURSOR keys_cur
        IS
            SELECT T.TABLE_NAME, T.TABLESPACE_NAME, T.CONSTRAINT_NAME, T.CONSTRAINT_TYPE, 
                T.VIEW_KEY_COLS, T.UNIQUE_KEY_COLS, T.KEY_COLS_COUNT, T.HAS_NULLABLE, 
                T.INDEX_OWNER, T.INDEX_NAME, I.PREFIX_LENGTH,
                T.DEFERRABLE, T.DEFERRED, T.STATUS, T.VALIDATED, T.IOT_TYPE, T.AVG_ROW_LEN,
                T.BASE_NAME,
                RTRIM(SUBSTR(BASE_NAME, 1, 23), '_' || RUN_NO) || RUN_NO SHORT_NAME,
                RTRIM(SUBSTR(BASE_NAME, 1, 26), '_' || RUN_NO) || RUN_NO SHORT_NAME2,
                case when T.CONSTRAINT_TYPE = 'P' then 'PRIMARY KEY' when T.CONSTRAINT_TYPE =  'U' then 'UNIQUE' else null end KEY_CLAUSE,
                T.CONSTRAINT_TYPE || 'K' || NULLIF(DENSE_RANK() OVER (PARTITION BY T.TABLE_NAME, T.CONSTRAINT_TYPE ORDER BY CONSTRAINT_NAME), 1) CONSTRAINT_EXT,
                T.KEY_HAS_WORKSPACE_ID, T.KEY_HAS_DELETE_MARK, T.KEY_HAS_NEXTVAL, T.KEY_HAS_SYS_GUID, 
                T.HAS_SCALAR_VIEW_KEY, T.HAS_SERIAL_VIEW_KEY, T.SEQUENCE_OWNER, T.SEQUENCE_NAME, 
                T.READ_ONLY,
                NVL(R.CNT, 0) REFERENCES_COUNT
            FROM (
                SELECT DISTINCT
                    A.TABLE_NAME, A.TABLESPACE_NAME, B.CONSTRAINT_NAME, B.CONSTRAINT_TYPE, A.READ_ONLY,
                    B.VIEW_KEY_COLS, B.UNIQUE_KEY_COLS, B.KEY_COLS_COUNT, B.HAS_NULLABLE, 
                    B.INDEX_OWNER, B.INDEX_NAME,
                    B.DEFERRABLE, B.DEFERRED,
                    DECODE(B.STATUS, 'ENABLED', 'ENABLE', 'DISABLED', 'DISABLE') STATUS,
                    DECODE(B.VALIDATED, 'VALIDATED', 'VALIDATE', 'NOT VALIDATED', 'NOVALIDATE') VALIDATED,
                    A.IOT_TYPE, A.AVG_ROW_LEN,
                    changelog_conf.Get_BaseName(A.TABLE_NAME) BASE_NAME,
                    NULLIF(DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(A.TABLE_NAME, 1, 23), '_') ORDER BY NLSSORT(A.TABLE_NAME, 'NLS_SORT = WEST_EUROPEAN')), 1) RUN_NO,
                    NVL(B.KEY_HAS_WORKSPACE_ID, 'NO') KEY_HAS_WORKSPACE_ID, -- constraint has Workspace ID
                    NVL(B.KEY_HAS_DELETE_MARK, 'NO') KEY_HAS_DELETE_MARK, -- Constraint has Delete_Mark
                    COALESCE(B.KEY_HAS_NEXTVAL, B.TRIGGER_HAS_NEXTVAL, 'NO') KEY_HAS_NEXTVAL,
                    COALESCE(B.KEY_HAS_SYS_GUID, B.TRIGGER_HAS_SYS_GUID, 'NO') KEY_HAS_SYS_GUID,
                    CASE WHEN VIEW_KEY_COLS_COUNT = 1 AND HAS_SCALAR_VIEW_KEY = 'YES' THEN 'YES' ELSE 'NO' END HAS_SCALAR_VIEW_KEY,
                    CASE WHEN VIEW_KEY_COLS_COUNT = 1 AND HAS_SERIAL_VIEW_KEY = 'YES' THEN 'YES' ELSE 'NO' END HAS_SERIAL_VIEW_KEY,
                    B.SEQUENCE_OWNER, B.SEQUENCE_NAME
                FROM SYS.USER_TABLES A
                LEFT OUTER JOIN TABLE ( 
                		changelog_conf.FN_Pipe_Base_Uniquekeys (p_cur_unique_keys) 
                	) B ON A.TABLE_NAME = B.TABLE_NAME AND B.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
                WHERE A.TABLE_NAME  != changelog_conf.Get_TableWorkspaces
                AND A.IOT_NAME IS NULL
                AND A.TEMPORARY = 'N'
                AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
                AND A.READ_ONLY IN ('NO', 'N/A')
                AND NOT EXISTS (    -- this table is not part of materialized view
                    SELECT 1
                    FROM SYS.USER_OBJECTS MV
                    WHERE MV.OBJECT_NAME = A.TABLE_NAME
                    AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
                )
            ) T
			LEFT OUTER JOIN SYS.USER_INDEXES I 
				ON T.INDEX_NAME = I.INDEX_NAME 
				AND T.TABLE_NAME = I.TABLE_NAME
			LEFT OUTER JOIN TABLE (changelog_conf.FN_Pipe_References_Count) R 
				ON T.CONSTRAINT_NAME = R.R_CONSTRAINT_NAME AND R.R_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        v_in_rows tab_alter_unique_keys;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN keys_cur;
		LOOP
			FETCH keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE keys_cur;  
	END FN_Pipe_Table_AlterUniquekeys;


	FUNCTION FN_Pipe_Base_Views
	RETURN changelog_conf.tab_base_views PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_keys_cur
        IS
		SELECT /*+ RESULT_CACHE */
			V.VIEW_NAME, V.TABLE_NAME,
			NULLIF(V.RUN_NO, 1) RUN_NO,
			RTRIM(SUBSTR(V.VIEW_NAME, 1, 23), '_') || NULLIF(V.RUN_NO, 1) SHORT_NAME
		FROM (
			SELECT VIEW_NAME, TABLE_NAME,
				DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(VIEW_NAME, 1, 23), '_') ORDER BY NLSSORT(VIEW_NAME, 'NLS_SORT = WEST_EUROPEAN')) RUN_NO
			FROM (
				SELECT D.NAME VIEW_NAME, A.TABLE_NAME TABLE_NAME
				FROM USER_TABLES A
				JOIN USER_DEPENDENCIES D ON A.TABLE_NAME = D.REFERENCED_NAME -- table is used in view
				AND D.REFERENCED_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
				AND D.TYPE = 'VIEW'
				AND D.REFERENCED_TYPE = 'TABLE'
				AND A.TABLE_NAME LIKE '%' || changelog_conf.Get_Base_Table_Ext
				JOIN USER_CONSTRAINTS C ON C.TABLE_NAME = D.NAME
				WHERE INSTR(A.TABLE_NAME, '$') = 0
				AND D.NAME LIKE REGEXP_REPLACE(A.TABLE_NAME, '\d*' || changelog_conf.Get_Base_Table_Ext || '$') || '%'
				AND C.CONSTRAINT_TYPE = 'V' -- view has WITH CHECK OPTION constraint
				AND A.IOT_NAME IS NULL
				AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
				AND A.TEMPORARY = 'N'
				AND A.SECONDARY = 'N'
				AND A.NESTED = 'NO'
				AND A.READ_ONLY = 'NO'		-- skip read only tables
				AND NOT EXISTS (    -- this table is not part of materialized view
					SELECT 1
					FROM USER_OBJECTS MV
					WHERE MV.OBJECT_NAME = A.TABLE_NAME
					AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
				)
			) T
		) V;
        v_in_rows tab_base_views;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN user_keys_cur;
		LOOP
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE user_keys_cur;  
	END FN_Pipe_Base_Views;


	FUNCTION FN_Pipe_Changelog_fkeys
	RETURN changelog_conf.tab_Changelog_fkeys PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_keys_cur
        IS
		SELECT /*+ USE_MERGE(A B C Q) */
			DISTINCT A.TABLE_NAME, 
			FIRST_VALUE(CAST(B.COLUMN_NAME AS VARCHAR2(128)) ) OVER (PARTITION BY A.TABLE_NAME ORDER BY Q.RN, A.DELETE_RULE, A.CONSTRAINT_NAME, B.POSITION DESC) FOREIGN_KEY_COL
		  FROM USER_CONSTRAINTS A,
			USER_CONS_COLUMNS B,     -- column of foreign key source
			USER_CONS_COLUMNS D,    -- column of foreign key target
			(SELECT N.COLUMN_VALUE TABLE_NAME, ROWNUM RN FROM TABLE( changelog_conf.in_list(changelog_conf.Get_ChangeLogFKeyTables, ',') ) N) Q
		  WHERE A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.OWNER = B.OWNER
		  AND A.R_CONSTRAINT_NAME = D.CONSTRAINT_NAME AND A.R_OWNER = D.OWNER
		  AND changelog_conf.Get_BaseName(D.TABLE_NAME) = Q.TABLE_NAME
		  AND A.CONSTRAINT_TYPE = 'R'
		  AND B.COLUMN_NAME <> changelog_conf.Get_ColumnWorkspace
		  AND B.TABLE_NAME <> D.TABLE_NAME; -- not recursive connection

        v_in_rows tab_Changelog_fkeys;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN user_keys_cur;
		LOOP
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE user_keys_cur;  
	END FN_Pipe_Changelog_fkeys;


	FUNCTION FN_Pipe_has_set_null_fkeys (p_Table_Name VARCHAR2 DEFAULT NULL)
	RETURN changelog_conf.tab_has_set_null_fkeys PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_keys_cur
        IS
		SELECT DISTINCT P.TABLE_NAME  -- table is referenced in a foreign key clause with on delete set null clause
		FROM USER_CONSTRAINTS A
		JOIN USER_CONSTRAINTS P ON A.R_CONSTRAINT_NAME = P.CONSTRAINT_NAME AND A.R_OWNER = P.OWNER
		WHERE A.CONSTRAINT_TYPE = 'R'
		AND P.CONSTRAINT_TYPE IN ('P', 'U')
		AND A.DELETE_RULE = 'SET NULL'     -- before migration
		AND P.TABLE_NAME  = NVL(p_Table_Name, P.TABLE_NAME)
		AND A.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
		UNION 
		SELECT DISTINCT P.TABLE_NAME  
		FROM SYS.USER_CONSTRAINTS A
		JOIN SYS.USER_CONSTRAINTS P ON A.R_CONSTRAINT_NAME = P.CONSTRAINT_NAME AND A.R_OWNER = P.OWNER
		JOIN SYS.USER_TRIGGERS TR -- a trigger to support the set null clause exists
			ON      TR.TRIGGER_NAME = A.CONSTRAINT_NAME
			AND     TR.TABLE_NAME = P.TABLE_NAME
			AND     TR.TABLE_OWNER = A.OWNER
		WHERE A.CONSTRAINT_TYPE = 'R'
		AND P.CONSTRAINT_TYPE IN ('P', 'U')
		AND A.DELETE_RULE = 'NO ACTION'  -- after migration
		AND TR.TRIGGERING_EVENT = 'DELETE'
		AND TR.BASE_OBJECT_TYPE = 'TABLE'
		AND TR.TABLE_NAME  = NVL(p_Table_Name, P.TABLE_NAME)
		AND TR.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        v_in_rows tab_has_set_null_fkeys;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN user_keys_cur;
		LOOP
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE user_keys_cur;  
	END FN_Pipe_has_set_null_fkeys;


	FUNCTION FN_Pipe_Table_Columns
	RETURN changelog_conf.tab_table_columns PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_keys_cur
        IS
		SELECT /*+ RESULT_CACHE */
			TABLE_NAME, COLUMN_ID, COLUMN_NAME, DATA_TYPE, NULLABLE, 
			DEFAULT_LENGTH, DATA_DEFAULT, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH
		FROM SYS.USER_TAB_COLUMNS C;

        TYPE stat_tbl IS TABLE OF user_keys_cur%ROWTYPE;
        v_in_rows stat_tbl;
        v_row rec_table_columns;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN user_keys_cur;
		 LOOP
			FETCH user_keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit*5;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				v_row.TABLE_NAME 			:= v_in_rows(ind).TABLE_NAME;
				v_row.COLUMN_ID 			:= v_in_rows(ind).COLUMN_ID;
				v_row.COLUMN_NAME 			:= v_in_rows(ind).COLUMN_NAME;
				v_row.DATA_TYPE 			:= v_in_rows(ind).DATA_TYPE;
				v_row.NULLABLE 				:= v_in_rows(ind).NULLABLE;
				v_row.DEFAULT_LENGTH 		:= v_in_rows(ind).DEFAULT_LENGTH;
				v_row.DEFAULT_TEXT 			:= RTRIM(SUBSTR(TO_CLOB(v_in_rows(ind).DATA_DEFAULT), 1, 800)); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
				v_row.DATA_PRECISION 		:= v_in_rows(ind).DATA_PRECISION;
				v_row.DATA_SCALE 			:= v_in_rows(ind).DATA_SCALE;
				v_row.CHAR_LENGTH 			:= v_in_rows(ind).CHAR_LENGTH;			
				pipe row (v_row);
			END LOOP;
		END LOOP;
		CLOSE user_keys_cur;  
	END FN_Pipe_Table_Columns;


	FUNCTION FN_Pipe_Foreign_Key_Columns
	RETURN changelog_conf.tab_foreign_key_columns PIPELINED PARALLEL_ENABLE
	IS
		PRAGMA UDF;
		CURSOR all_objects_cur
		IS 	
		SELECT /*+ RESULT_CACHE PARALLEL USE_MERGE(F FC SC) */
			F.TABLE_NAME, F.OWNER, F.CONSTRAINT_NAME, FC.COLUMN_NAME, FC.POSITION, 
			SC.COLUMN_ID, SC.NULLABLE, F.DELETE_RULE, F.DEFERRABLE, F.DEFERRED, 
			F.STATUS, F.VALIDATED, F.R_CONSTRAINT_NAME, F.R_OWNER
		FROM SYS.USER_CONSTRAINTS F 
		JOIN SYS.USER_CONS_COLUMNS FC ON F.OWNER = FC.OWNER AND F.CONSTRAINT_NAME = FC.CONSTRAINT_NAME AND F.TABLE_NAME = FC.TABLE_NAME
		JOIN SYS.USER_TAB_COLS SC ON SC.TABLE_NAME = F.TABLE_NAME AND SC.COLUMN_NAME = FC.COLUMN_NAME AND SC.HIDDEN_COLUMN = 'NO' 
		AND F.CONSTRAINT_TYPE = 'R'
		AND F.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
		UNION ALL
		SELECT /*+ RESULT_CACHE PARALLEL USE_MERGE(F FC SC G) */
			F.TABLE_NAME, F.OWNER, F.CONSTRAINT_NAME, FC.COLUMN_NAME, FC.POSITION, 
			SC.COLUMN_ID, SC.NULLABLE, F.DELETE_RULE, F.DEFERRABLE, F.DEFERRED, 
			F.STATUS, F.VALIDATED, F.R_CONSTRAINT_NAME, F.R_OWNER
		FROM SYS.ALL_CONSTRAINTS F 
		JOIN SYS.ALL_CONS_COLUMNS FC ON F.OWNER = FC.OWNER AND F.CONSTRAINT_NAME = FC.CONSTRAINT_NAME AND F.TABLE_NAME = FC.TABLE_NAME
		JOIN SYS.ALL_TAB_COLS SC ON SC.TABLE_NAME = F.TABLE_NAME AND SC.COLUMN_NAME = FC.COLUMN_NAME AND SC.OWNER = F.OWNER AND SC.HIDDEN_COLUMN = 'NO' 
        join SYS.ALL_TAB_PRIVS G on F.TABLE_NAME = G.TABLE_NAME AND F.OWNER = G.GRANTOR 
		where F.CONSTRAINT_TYPE = 'R'
		and G.TYPE = 'TABLE'
		and G.GRANTEE IN ('PUBLIC', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));

		CURSOR user_objects_cur
		IS 	
		SELECT /*+ RESULT_CACHE PARALLEL USE_MERGE(F FC SC) */
			F.TABLE_NAME, F.OWNER, F.CONSTRAINT_NAME, FC.COLUMN_NAME, FC.POSITION, 
			SC.COLUMN_ID, SC.NULLABLE, F.DELETE_RULE, F.DEFERRABLE, F.DEFERRED, 
			F.STATUS, F.VALIDATED, F.R_CONSTRAINT_NAME, F.R_OWNER
		FROM SYS.USER_CONSTRAINTS F 
		JOIN SYS.USER_CONS_COLUMNS FC ON F.OWNER = FC.OWNER AND F.CONSTRAINT_NAME = FC.CONSTRAINT_NAME AND F.TABLE_NAME = FC.TABLE_NAME
		JOIN SYS.USER_TAB_COLS SC ON SC.TABLE_NAME = F.TABLE_NAME AND SC.COLUMN_NAME = FC.COLUMN_NAME AND SC.HIDDEN_COLUMN = 'NO' 
		AND F.CONSTRAINT_TYPE = 'R'
		AND F.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') ;

		v_in_rows tab_foreign_key_columns;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN all_objects_cur;
			LOOP
				FETCH all_objects_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_objects_cur;  
		else
			OPEN user_objects_cur;
			LOOP
				FETCH user_objects_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_objects_cur;  
		end if;
	END FN_Pipe_Foreign_Key_Columns;


	FUNCTION FN_Pipe_Changelog_References
	RETURN changelog_conf.tab_changelog_references PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_keys_cur
        IS
		-- used in packages custom_changelog_gen
		-- Calculate additional parameter for custom_changelog.AddLog. The mapping of table columns
		-- to parameter names of a direct reference column for the function call to custom_changelog.AddLog is calculated
		SELECT S_TABLE_NAME, S_COLUMN_NAME, T_TABLE_NAME, T_COLUMN_NAME, T_CHANGELOG_NAME, CONSTRAINT_TYPE, DELETE_RULE
		FROM (
			SELECT DISTINCT B.TABLE_NAME S_TABLE_NAME, CAST(B.COLUMN_NAME AS VARCHAR2(128)) S_COLUMN_NAME, D.TABLE_NAME T_TABLE_NAME, C.COLUMN_NAME T_COLUMN_NAME,
				'CUSTOM_REF_ID' || T.R T_CHANGELOG_NAME,
				A.CONSTRAINT_TYPE, A.DELETE_RULE,
				DENSE_RANK() OVER (PARTITION BY B.TABLE_NAME, D.TABLE_NAME, C.COLUMN_NAME ORDER BY B.COLUMN_NAME) C_RANK
			FROM SYS.USER_CONSTRAINTS A
			, SYS.USER_CONS_COLUMNS B
			, SYS.USER_CONS_COLUMNS D
			, (SELECT CAST(N.COLUMN_VALUE AS VARCHAR2(128)) TABLE_NAME, ROWNUM R FROM TABLE( changelog_conf.in_list(changelog_conf.Get_ChangeLogFKeyTables, ',') ) N) T
			, (SELECT CAST(N.COLUMN_VALUE AS VARCHAR2(128)) COLUMN_NAME, ROWNUM R  FROM TABLE( changelog_conf.in_list(changelog_conf.Get_ChangeLogFKeyColumns, ',') ) N) C
			WHERE A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.OWNER = B.OWNER     -- column of foreign key source
			AND A.R_CONSTRAINT_NAME = D.CONSTRAINT_NAME AND A.R_OWNER = B.OWNER   -- column of foreign key target
			AND D.TABLE_NAME = T.TABLE_NAME
			AND T.R = C.R -- same position in the list
			AND A.CONSTRAINT_TYPE = 'R'
			AND B.COLUMN_NAME <> changelog_conf.Get_ColumnWorkspace
			AND B.TABLE_NAME <> D.TABLE_NAME -- no recursive connection
			UNION ALL
			SELECT DISTINCT B.TABLE_NAME S_TABLE_NAME, CAST(B.COLUMN_NAME AS VARCHAR2(128)) S_COLUMN_NAME, T.TABLE_NAME T_TABLE_NAME, C.COLUMN_NAME T_COLUMN_NAME,
				'CUSTOM_REF_ID' || T.R T_CHANGELOG_NAME,
				A.CONSTRAINT_TYPE, A.DELETE_RULE,
				1 C_RANK
			FROM SYS.USER_CONSTRAINTS A
			, SYS.USER_CONS_COLUMNS B
			, (SELECT CAST(N.COLUMN_VALUE AS VARCHAR2(128)) TABLE_NAME, ROWNUM R FROM TABLE( changelog_conf.in_list(changelog_conf.Get_ChangeLogFKeyTables, ',') ) N) T
			, (SELECT CAST(N.COLUMN_VALUE AS VARCHAR2(128)) COLUMN_NAME, ROWNUM R  FROM TABLE( changelog_conf.in_list(changelog_conf.Get_ChangeLogFKeyColumns, ',') ) N) C
			WHERE A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.OWNER = B.OWNER     -- column of primary key source
			AND B.TABLE_NAME = T.TABLE_NAME
			AND T.R = C.R -- same position in the list
			AND A.CONSTRAINT_TYPE = 'P'
		) -- only one column for each table reference
		WHERE C_RANK = 1
		;

        v_in_rows tab_changelog_references;
	BEGIN
		if g_Use_Change_Log IS NULL then
			return; -- not initialised (during create mview)
		end if;
		OPEN user_keys_cur;
		FETCH user_keys_cur BULK COLLECT INTO v_in_rows;
		CLOSE user_keys_cur;  
		FOR ind IN 1 .. v_in_rows.COUNT LOOP
			pipe row (v_in_rows(ind));
		END LOOP;
	END FN_Pipe_Changelog_References;

	FUNCTION Enquote_Name (str VARCHAR2)
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		return DBMS_ASSERT.ENQUOTE_NAME (str => str, capitalize => FALSE);
	END;

	FUNCTION Enquote_Literal ( p_Text VARCHAR2 )
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
		v_Quote CONSTANT VARCHAR2(1) := chr(39);
	BEGIN
		RETURN v_Quote || REPLACE(p_Text, v_Quote, v_Quote||v_Quote) || v_Quote ;
	END;

	FUNCTION First_Element (str VARCHAR2)
	RETURN VARCHAR2 DETERMINISTIC
	IS -- return first element of comma delimited list as native column name
	PRAGMA UDF;
		v_Offset PLS_INTEGER := INSTR(str, ',');
		v_trim_set CONSTANT VARCHAR2(10) := ' _%';
	BEGIN
		return case when v_Offset > 0 then LTRIM(RTRIM(SUBSTR(str, 1, v_Offset-1), v_trim_set), v_trim_set) else str end;
	END;

    FUNCTION Normalize_Table_Name (p_Table_Name VARCHAR2)
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	RETURN REGEXP_REPLACE(p_Table_name, g_BaseTableExt || '$');
    END;

    FUNCTION Normalize_Column_Name (
    	p_Column_Name VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	BEGIN
		RETURN REGEXP_REPLACE(p_Column_Name, '(.*)' || g_SequenceColumnExt || '(\d*)$', '\1\2'); -- remove ending _ID2
	END;

    FUNCTION Compose_Table_Column_Name (
    	p_Table_Name VARCHAR2,
    	p_Column_Name VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
        v_Table_Name VARCHAR2(128) := Normalize_Table_Name(p_Table_Name => p_Table_Name); -- remove ending _BT
        v_Column_Name VARCHAR2(128) := Normalize_Column_Name(p_Column_Name => p_Column_Name); -- remove ending _ID2
        v_Half_Length CONSTANT INTEGER := FLOOR(p_Max_Length / 2);
    BEGIN
        RETURN RTRIM(SUBSTR(v_Table_Name, 1, GREATEST(v_Half_Length, p_Max_Length - 1 - LENGTH(v_Column_Name))), '_') || '_'
           ||  RTRIM(SUBSTR(v_Column_Name, 1, GREATEST(v_Half_Length, p_Max_Length - 1 - LENGTH(v_Table_Name))), '_');
    END Compose_Table_Column_Name;

    FUNCTION Compose_Column_Name (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Deduplication VARCHAR2 DEFAULT 'NO',
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
        v_Half_Length CONSTANT INTEGER := FLOOR(p_Max_Length / 2);
    BEGIN
    	if p_Deduplication = 'YES' then
    	    if INSTR(p_First_Name, p_Second_Name) = 1 OR p_Second_Name IS NULL then
    			RETURN RTRIM(SUBSTR(p_First_Name, 1, p_Max_Length), '_');
    		elsif INSTR(p_Second_Name, p_First_Name) = 1  OR p_First_Name IS NULL then
    			RETURN RTRIM(SUBSTR(p_Second_Name, 1, p_Max_Length), '_');
    		end if;
    	else
    	    if p_Second_Name IS NULL then
    			RETURN RTRIM(SUBSTR(p_First_Name, 1, p_Max_Length), '_');
    		elsif p_First_Name IS NULL then
    			RETURN RTRIM(SUBSTR(p_Second_Name, 1, p_Max_Length), '_');
    		end if;
    	end if;
	    RETURN RTRIM(SUBSTR(p_First_Name, 1, GREATEST(v_Half_Length, p_Max_Length - 1 - LENGTH(p_Second_Name))), '_') || '_'
    	   ||  RTRIM(SUBSTR(p_Second_Name, 1, GREATEST(v_Half_Length, p_Max_Length - 1 - LENGTH(p_First_Name))), '_');
    END Compose_Column_Name;


    PROCEDURE  Set_Debug(p_Debug NUMBER DEFAULT 0)
    IS
    BEGIN
        g_debug := p_Debug;
    END;

    FUNCTION Get_Base_Table_Ext RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_BaseTableExt; END;
    
    FUNCTION Get_Base_Table_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
        RETURN p_Name || g_BaseTableExt;
    END;

    FUNCTION Get_Short_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN RTRIM(SUBSTR(p_Name, 1, 23), '_');
    END;

    FUNCTION Get_ChangelogTrigger_Name ( p_Name VARCHAR2, p_RunNo VARCHAR2 DEFAULT NULL ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Max_Length INTEGER := g_Max_Name_Length - NVL(LENGTH(g_ChangelogTriggerPrefix), 0)
    							- NVL(LENGTH(g_ChangelogTriggerExt), 0) - NVL(LENGTH(p_RunNo), 0);
    BEGIN
        RETURN g_ChangelogTriggerPrefix || RTRIM(SUBSTR(Get_Short_Name(p_Name), 1, v_Max_Length), '_') || p_RunNo || g_ChangelogTriggerExt;
    END;

    FUNCTION Get_BiTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Max_Length INTEGER := g_Max_Name_Length - NVL(LENGTH(g_BiTriggerPrefix), 0) - NVL(LENGTH(g_BiTriggerExt), 0);
    BEGIN
        RETURN g_BiTriggerPrefix || RTRIM(SUBSTR(Get_Short_Name(p_Name), 1, v_Max_Length), '_') || g_BiTriggerExt;
    END;

    FUNCTION Get_BuTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Max_Length INTEGER := g_Max_Name_Length - NVL(LENGTH(g_BuTriggerPrefix), 0) - NVL(LENGTH(g_BuTriggerExt), 0);
    BEGIN
        RETURN g_BuTriggerPrefix || RTRIM(SUBSTR(Get_Short_Name(p_Name), 1, v_Max_Length), '_') || g_BuTriggerExt;
    END;

    FUNCTION Get_InsTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Max_Length INTEGER := g_Max_Name_Length - NVL(LENGTH(g_InsTriggerPrefix), 0) - NVL(LENGTH(g_InsTriggerExt), 0);
    BEGIN
        RETURN g_InsTriggerPrefix || RTRIM(SUBSTR(Get_Short_Name(p_Name), 1, v_Max_Length), '_') || g_InsTriggerExt;
    END;

    FUNCTION Get_DelTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Max_Length INTEGER := g_Max_Name_Length - NVL(LENGTH(g_DelTriggerPrefix), 0) - NVL(LENGTH(g_DelTriggerExt), 0);
    BEGIN
        RETURN g_DelTriggerPrefix || RTRIM(SUBSTR(Get_Short_Name(p_Name), 1, v_Max_Length), '_') || g_DelTriggerExt;
    END;

    FUNCTION Get_UpdTrigger_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Max_Length INTEGER := g_Max_Name_Length - NVL(LENGTH(g_UpdTriggerPrefix), 0) - NVL(LENGTH(g_UpdTriggerExt), 0);
    BEGIN
        RETURN g_UpdTriggerPrefix || RTRIM(SUBSTR(Get_Short_Name(p_Name), 1, v_Max_Length), '_') || g_UpdTriggerExt;
    END;

    FUNCTION Get_SequenceExt RETURN VARCHAR2 IS BEGIN RETURN g_SequenceExt; END;
    FUNCTION Get_Sequence_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN p_Name || g_SequenceExt;
    END;

    PROCEDURE Get_Sequence_Name ( p_Name VARCHAR2, p_Sequence_Name OUT VARCHAR2, p_Sequence_Exists OUT VARCHAR2 )
    IS
        v_Sequence_Name         VARCHAR2(128);
		v_Count					PLS_INTEGER;
    BEGIN
        v_Sequence_Name := p_Name || g_SequenceExt;
		SELECT COUNT(*) INTO v_Count
		FROM USER_SEQUENCES
		WHERE SEQUENCE_NAME = v_Sequence_Name;
		p_Sequence_Exists := case when v_Count = 0 then 'NO' else 'YES' end;
		p_Sequence_Name := v_Sequence_Name;
    END;

    FUNCTION Get_Sequence_ColumnExt RETURN VARCHAR2 IS BEGIN RETURN g_SequenceColumnExt; END;
    FUNCTION Get_Sequence_Column ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN TRIM('_' FROM SUBSTR(p_Name, 1, g_Max_Name_Length - LENGTH(g_SequenceColumnExt)) || g_SequenceColumnExt);
    END;
    FUNCTION Get_Sequence_ConstraintExt RETURN VARCHAR2 IS BEGIN RETURN g_SequenceConstraintExt; END;
    FUNCTION Get_Sequence_Constraint ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN SUBSTR(p_Name, 1, g_Max_Name_Length - LENGTH(g_SequenceConstraintExt)) || g_SequenceConstraintExt;
    END;
    FUNCTION Get_SequenceOptions RETURN VARCHAR2 IS BEGIN RETURN g_SequenceOptions; END;
    FUNCTION Get_Use_Sequences RETURN VARCHAR2 IS BEGIN RETURN g_Use_Sequences; END;

    FUNCTION Get_Sequence_Limit_ID (
        p_Table_Name    IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2
    ) RETURN NUMBER
    IS
	PRAGMA UDF;
        v_Stat              VARCHAR2(400);
        stat_cur            SYS_REFCURSOR;
        v_ID                NUMBER;
    BEGIN
        v_Stat := 'SELECT NVL(MAX(' || DBMS_ASSERT.ENQUOTE_NAME(p_Primary_Key_Col) || '), 0) ID ' ||
            ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name);
        OPEN  stat_cur FOR v_Stat;
        FETCH stat_cur INTO v_ID;
        RETURN v_ID;
    END Get_Sequence_Limit_ID;

	PROCEDURE Set_Sequence_New_Value (
		p_Sequence_Name VARCHAR2,
		p_Sequence_Owner VARCHAR2,
		p_New_Value NUMBER
	)
	AS
		v_last_number NUMBER;
		v_increment_by NUMBER;
	BEGIN
		SELECT LAST_NUMBER, INCREMENT_BY
		INTO v_last_number, v_increment_by
		FROM ALL_SEQUENCES
		WHERE SEQUENCE_NAME = UPPER(p_Sequence_Name)
		AND SEQUENCE_OWNER = UPPER(p_Sequence_Owner);
		
		if p_New_Value > v_last_number then
			EXECUTE IMMEDIATE ( 'ALTER SEQUENCE ' || p_Sequence_Name || ' INCREMENT BY ' || (p_New_Value - v_last_number));
			EXECUTE IMMEDIATE 'SELECT ' || p_Sequence_Name || '.NEXTVAL FROM DUAL' INTO v_last_number;
			EXECUTE IMMEDIATE ( 'ALTER SEQUENCE ' || p_Sequence_Name || ' INCREMENT BY ' || v_increment_by);
		end if;
	END Set_Sequence_New_Value;

    PROCEDURE  Adjust_Table_Sequence (
        p_Table_Name    IN VARCHAR2,
        p_Sequence_Name IN VARCHAR2,
		p_Sequence_Owner IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2,
        p_StartSeq      IN INTEGER DEFAULT 1
    )
    IS
        v_LimitID               NUMBER;
        v_Stat                  VARCHAR2(4000);
    BEGIN
		v_LimitID := GREATEST(Get_Sequence_Limit_ID(p_Table_Name, p_Primary_Key_Col), p_StartSeq - 1) + 1;
		Set_Sequence_New_Value (p_Sequence_Name, p_Sequence_Owner, v_LimitID);
    END Adjust_Table_Sequence;

    FUNCTION Get_Interrim_Table_Name ( p_Name VARCHAR2 ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN SUBSTR(p_Name, 1, g_Max_Name_Length - LENGTH(g_Interrim_Table_Ext) - 2) || g_Interrim_Table_Ext;
    END;
    FUNCTION App_User_Schema RETURN VARCHAR2 IS BEGIN RETURN SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || g_AppUserExt; END;
    FUNCTION Get_Use_Change_Log RETURN VARCHAR2 IS BEGIN RETURN g_Use_Change_Log; END;
	FUNCTION Get_Use_Audit_Info_Columns RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Use_Audit_Info_Columns; END;
	FUNCTION Get_Use_Audit_Info_Trigger RETURN VARCHAR2 IS BEGIN RETURN case when g_Use_Audit_Info_Columns = 'YES' and g_Use_Audit_Info_Trigger = 'YES' then 'YES' else 'NO' end; END;
	FUNCTION Get_Drop_Audit_Info_Columns RETURN VARCHAR2 IS BEGIN RETURN case when g_Use_Audit_Info_Columns = 'YES' and g_Drop_Audit_Info_Columns = 'YES' then 'YES' else 'NO' end; END;
    FUNCTION Get_Use_Column_Workspace RETURN VARCHAR2 IS BEGIN RETURN g_Add_WorkspaceID; END;
    FUNCTION Get_Use_Column_Delete_mark RETURN VARCHAR2 IS BEGIN RETURN g_Add_Delete_Mark; END;
    FUNCTION Get_Add_Modify_Date RETURN VARCHAR2 IS BEGIN RETURN g_Add_Modify_Date; END;
    FUNCTION Get_Add_Modify_User RETURN VARCHAR2 IS BEGIN RETURN g_Add_Modify_User; END;
    FUNCTION Get_Add_Creation_Date RETURN VARCHAR2 IS BEGIN RETURN g_Add_Creation_Date; END;
    FUNCTION Get_Add_Creation_User RETURN VARCHAR2 IS BEGIN RETURN g_Add_Creation_User; END;
    FUNCTION Get_Enforce_Not_Null RETURN VARCHAR2 IS BEGIN RETURN g_Enforce_Not_Null; END;
    FUNCTION Get_Add_Insert_Trigger RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_Add_Insert_Trigger; END;
    FUNCTION Get_Add_Delete_Trigger RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_Add_Delete_Trigger; END;
    FUNCTION Get_Add_Update_Trigger1 RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_Add_Update_Trigger1; END;
    FUNCTION Get_Add_Update_Trigger2 RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_Add_Update_Trigger2; END;
    FUNCTION Get_Add_Application_Schema RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_Add_Application_Schema; END;
    FUNCTION Get_Add_ChangeLog_Views RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN case when g_Add_ChangeLog_Views = 'YES' and g_Use_Change_Log = 'YES' then 'YES' else 'NO' end; END;
    FUNCTION App_User_Password RETURN VARCHAR2 IS BEGIN RETURN g_AppUserPassword; END;
    FUNCTION Apex_Workspace_Name RETURN VARCHAR2 IS BEGIN RETURN g_Apex_Workspace_Name; END;

    FUNCTION Get_Use_On_Null RETURN VARCHAR2
    IS
    BEGIN
        RETURN case when g_Use_On_Null = 'YES' and Get_Database_Version >= '12.0' then 'YES' else 'NO' end;
    END;
    
    FUNCTION Get_Include_External_Objects RETURN VARCHAR2
    IS
    BEGIN
        RETURN g_Include_External_Objects;
    END;
    
    FUNCTION Get_Table_Schema RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_BaseTableSchema; END;
    FUNCTION Get_View_Schema RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_BaseViewSchema; END;

    PROCEDURE Set_Table_Schema(p_Schema_Name IN VARCHAR2 DEFAULT NULL)
    IS
    BEGIN
        if p_Schema_Name IS NULL then
            g_BaseTableSchema   := NULL;
        else
            g_BaseTableSchema   := p_Schema_Name || '.';
        end if;
    END;

    PROCEDURE Set_View_Schema(p_Schema_Name IN VARCHAR2 DEFAULT NULL)
    IS
    BEGIN
        if p_SCHEMA_NAME IS NULL then
            g_BaseViewSchema    := NULL;
        else
            g_BaseViewSchema    := p_Schema_Name || '.';
        end if;
    END;

    PROCEDURE Set_Target_Schema (p_Schema_Name IN VARCHAR2 DEFAULT NULL)
    IS
        v_Schema_Name       VARCHAR2(40) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    BEGIN
        if p_Schema_Name IS NULL or p_Schema_Name = v_Schema_Name then
            g_BaseTableSchema   := NULL;
            g_BaseViewSchema    := NULL;
        else
            g_BaseTableSchema   := v_Schema_Name || '.';
            g_BaseViewSchema    := p_Schema_Name || '.';
        end if;
    END;

    FUNCTION Get_TableWorkspaces RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_TableWorkspaces); END;
	FUNCTION Get_Sys_Guid_Function RETURN VARCHAR2 IS BEGIN RETURN g_Sys_Guid_Function; END;

    FUNCTION Get_ColumnWorkspace RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnWorkspace)); END;

    FUNCTION Get_ColumnWorkspace_List RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_ColumnWorkspace); END;

    FUNCTION Get_Context_WorkspaceID_Expr RETURN VARCHAR2 IS BEGIN RETURN g_ContextWorkspaceIDExpr; END;
    FUNCTION Get_Context_User_Name_Expr   RETURN VARCHAR2 IS BEGIN RETURN g_ContextUserNameExpr; END;
    FUNCTION Get_Context_User_ID_Expr RETURN VARCHAR2 IS BEGIN RETURN g_ContextUserIDExpr; END;

    FUNCTION Get_Table_App_Users RETURN VARCHAR2 IS BEGIN RETURN UPPER(g_Table_App_Users); END;
    FUNCTION Get_ExcludeTablesPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_ExcludedTablesPattern; END;
    FUNCTION Get_IncludeWorkspaceIDPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN Concat_List(g_CIncludeWorkspaceIDPattern, g_IncludeWorkspaceIDPattern);
    END;
    FUNCTION Get_ConstantWorkspaceIDPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_CIncludeWorkspaceIDPattern; END;

    FUNCTION Get_ExcludeWorkspaceIDPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN Concat_List(g_CExcludeWorkspaceIDPattern, g_ExcludeWorkspaceIDPattern);
    END;
    FUNCTION Get_IncludeDeleteMarkPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_IncludeDeleteMarkPattern; END;
    FUNCTION Get_ExcludeDeleteMarkPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN Concat_List(g_ExcludedTablesPattern, g_ExcludeDeleteMarkPattern);
    END;
    FUNCTION Get_IncludeTimestampPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_IncludeTimestampPattern; END;
    FUNCTION Get_ExcludeTimestampPattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN Concat_List(g_ExcludedTablesPattern, g_ExcludeTimestampPattern);
    END;

    FUNCTION Get_ColumnCreateUser RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnCreateUser)); END;

    FUNCTION Get_ColumnCreateUser_List RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_ColumnCreateUser); END;

    FUNCTION Get_ColumnCreateDate RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnCreateDate)); END;

    FUNCTION Get_ColumnCreateDate_List RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_ColumnCreateDate); END;

    FUNCTION Get_ColumnModifyUser RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnModifyUser)); END;

    FUNCTION Get_ColumnModifyUser_List RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_ColumnModifyUser); END;

    FUNCTION Get_DatatypeModifyUser RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_DatatypeModifyUser; END;
    FUNCTION Get_ColumnTypeModifyUser RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_ColumnTypeModifyUser; END;
    
    FUNCTION Get_FunctionModifyUser RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN case when g_FunctionModifyUser IS NOT NULL
    		  then g_FunctionModifyUser
    		when g_ForeignKeyModifyUser = 'YES' and g_DatatypeModifyUser = 'NUMBER'
    		  then changelog_conf.Get_Context_User_ID_Expr
    		else changelog_conf.Get_DefaultModifyUser -- Get_Context_User_Name_Expr
    	end;
    END;
    
    FUNCTION Get_DefaultModifyUser RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN 'NVL(' || g_ContextUserNameExpr || ', ' || g_SessionUserNameExpr || ')';
    END;
    	
    FUNCTION Get_ForeignKeyModifyUser RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_ForeignKeyModifyUser; END;

    FUNCTION Get_ColumnModifyDate RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnModifyDate)); END;

    FUNCTION Get_ColumnModifyDate_List RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_ColumnModifyDate); END;

    FUNCTION Get_FunctionModifyDate RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_FunctionModifyDate; END;
    FUNCTION Get_DatatypeModifyDate RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_DatatypeModifyDate; END;
    FUNCTION Get_AltDatatypeModifyDate RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_AltDatatypeModifyDate; END;

    FUNCTION Get_ColumnDeletedMark RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnDeletedMark)); END;

    FUNCTION Get_ColumnDeletedMark_List RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(g_ColumnDeletedMark); END;

    FUNCTION Get_DatatypeDeletedMark RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_DatatypeDeletedMark; END;
    FUNCTION Get_DefaultDeletedMark RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_DefaultDeletedMark; END;
    -- the column DELETED_MARK is added to each table with a primary key.
    -- existing rows have a NULL value in this column.
    FUNCTION Get_ColumnTypeDeletedMark RETURN VARCHAR2
    IS
    BEGIN
        RETURN g_ColumnTypeDeletedMark || ' DEFAULT ' || g_DefaultDeletedMark;
    END;

    -- deleted rows are marked with different values.
    -- when a  unique key is defined on a table then the deleted mark is appended to the unique key.
    -- this happens so that multiple deleted rows can exist with the same unique key values.
    FUNCTION Get_DeletedMarkFunction (p_Has_Serial_Primary_Key VARCHAR2, p_Primary_Key_Cols VARCHAR2)
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN 'CHR(ORA_HASH('
        || CASE WHEN p_Has_Serial_Primary_Key = 'YES' THEN p_Primary_Key_Cols ELSE 'DBMS_UTILITY.GET_TIME' END
        || ')) ';
    END;

    FUNCTION Get_ColumnIndexFormat RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN UPPER(First_Element(g_ColumnIndexFormat)); END;

    FUNCTION Get_Admin_Workspace_Name RETURN VARCHAR2
    IS
    BEGIN
        RETURN REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), g_AppUserExt || '$');
    END;

    FUNCTION Get_Database_Version RETURN VARCHAR2
    IS
        v_Version PRODUCT_COMPONENT_VERSION.VERSION%TYPE;
    BEGIN
        SELECT MAX(VERSION)
        INTO v_Version
        FROM PRODUCT_COMPONENT_VERSION
        WHERE PRODUCT LIKE 'Oracle Database%';

        RETURN v_Version;
    END;

    FUNCTION Use_Serial_Default RETURN VARCHAR2
    IS
    BEGIN
        RETURN case when g_Use_Sequences = 'YES'
        and Get_Database_Version >= '12.0'
        and g_Use_On_Null = 'YES' then 'YES' else 'NO' end;
    END;

    FUNCTION Get_ConstraintText (p_Table_Name VARCHAR2, p_Constraint_Name VARCHAR2, p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')) RETURN VARCHAR2
    IS
        v_Search_Condition VARCHAR2(4000);
    BEGIN
        SELECT C.SEARCH_CONDITION
        INTO v_Search_Condition
        FROM SYS.ALL_CONSTRAINTS C
        WHERE C.TABLE_NAME = p_Table_Name
        AND C.OWNER = p_Owner
        AND C.CONSTRAINT_NAME = p_Constraint_Name;

        RETURN LTRIM(REGEXP_REPLACE(RTRIM(v_Search_Condition, CHR(32)||CHR(10)||CHR(13)||CHR(9)), '--.*$', NULL, 1, 1, 'm'), chr(32)||chr(10)||CHR(9));
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return NULL;
    END;

    FUNCTION Get_ColumnDefaultText (p_Table_Name VARCHAR2, p_Column_Name VARCHAR2, p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')) RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Default_Text SYS.ALL_TAB_COLUMNS.DATA_DEFAULT%TYPE;
    BEGIN
        if p_Table_Name IS NULL OR p_Column_Name IS NULL then
            return NULL;
        end if;
        SELECT C.DATA_DEFAULT
        INTO v_Default_Text
        FROM SYS.ALL_TAB_COLUMNS C
        WHERE C.TABLE_NAME = p_Table_Name
        AND C.OWNER = p_Owner
        AND C.COLUMN_NAME = p_Column_Name;

        RETURN RTRIM(v_Default_Text, CHR(32)||CHR(10)||CHR(13));
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return NULL;
    END;

	FUNCTION Get_Name_Part (
		p_Name IN VARCHAR2,
		p_Part IN NUMBER
	) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_First_Name VARCHAR2(128);
		v_Second_Name VARCHAR2(128);
		v_Third_Name VARCHAR2(128);
		v_Link_Name VARCHAR2(128);
		v_Nextpos BINARY_INTEGER;
    BEGIN
    	if p_Name IS NULL then
    		return NULL;
    	end if;
		DBMS_UTILITY.NAME_TOKENIZE (
			name => p_Name,
			a => v_First_Name,
			b => v_Second_Name,
			c => v_Third_Name,
			dblink => v_Link_Name,
			nextpos => v_Nextpos
		);
		return case p_Part
			when 1 then v_First_Name
			when 2 then v_Second_Name
			when 3 then v_Third_Name
			when 4 then v_Link_Name
		end;
	EXCEPTION
	WHEN OTHERS THEN
		return NULL;
	END Get_Name_Part;

    FUNCTION Get_ColumnCheckCondition (p_Table_Name VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Search_Condition_Vc VARCHAR(4000);
    BEGIN
        if p_Table_Name IS NULL OR p_Column_Name IS NULL then
            return NULL;
        end if;
		SELECT SEARCH_CONDITION_VC
		INTO v_Search_Condition_Vc
		FROM (
            SELECT B.COLUMN_NAME, changelog_conf.Get_ConstraintText(A.TABLE_NAME, A.CONSTRAINT_NAME) SEARCH_CONDITION_VC
            FROM USER_CONSTRAINTS A
            JOIN USER_CONS_COLUMNS B ON A.OWNER = B.OWNER AND A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.TABLE_NAME = B.TABLE_NAME
            WHERE A.OWNER = USER
            AND A.CONSTRAINT_TYPE = 'C' -- check constraint
            AND A.TABLE_NAME = p_Table_Name
            AND B.COLUMN_NAME = p_Column_Name
            AND NOT EXISTS (
                SELECT 1
                FROM USER_CONS_COLUMNS C
                WHERE C.CONSTRAINT_NAME = B.CONSTRAINT_NAME
                AND C.OWNER = B.OWNER
                AND C.TABLE_NAME = B.TABLE_NAME
                AND C.COLUMN_NAME != B.COLUMN_NAME
            )
        ) A
        WHERE SEARCH_CONDITION_VC != DBMS_ASSERT.ENQUOTE_NAME(COLUMN_NAME) || ' IS NOT NULL'; -- filter NOT NULL checks
        RETURN v_Search_Condition_Vc;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return NULL;
    END;


    FUNCTION Get_TriggerText (p_Table_Name VARCHAR2, p_Trigger_Name VARCHAR2) RETURN CLOB
    IS
	PRAGMA UDF;
    BEGIN
        FOR C IN (
            SELECT C.TRIGGER_BODY
            FROM SYS.USER_TRIGGERS C
            WHERE C.TABLE_NAME = p_Table_Name
            AND C.TRIGGER_NAME = p_Trigger_Name
            AND C.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
        )
        LOOP
            RETURN RTRIM(TO_CLOB(C.Trigger_Body), CHR(32)||CHR(10)||CHR(13));
        END LOOP;
        RETURN NULL;
    END;

    FUNCTION Get_BaseName (p_Table_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
        RETURN REGEXP_REPLACE(p_Table_Name, g_BaseTableExt || '$');
    END;

	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ','
	)
    RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN
			case when p_First_Name IS NOT NULL and p_Second_Name IS NOT NULL
			then p_First_Name || p_Delimiter || p_Second_Name
			when p_First_Name IS NOT NULL
			then p_First_Name
			else p_Second_Name
			end;
    END;

	FUNCTION Match_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern VARCHAR2) 
	RETURN VARCHAR2 DETERMINISTIC -- YES / NO
	IS 
	PRAGMA UDF;
		v_Pattern_Array apex_t_varchar2;
	BEGIN
		v_Pattern_Array := apex_string.split(TRANSLATE(p_Pattern, '_ ', '_'), ',');
		for c_idx IN 1..v_Pattern_Array.count loop
			if p_Column_Name LIKE REPLACE(v_Pattern_Array(c_idx),'_','\_') ESCAPE '\' then
				RETURN 'YES';
			end if;
		end loop;
		RETURN 'NO';
	END;

	FUNCTION Match_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern_Array apex_t_varchar2) 
	RETURN VARCHAR2 DETERMINISTIC -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN
		for c_idx IN 1..p_Pattern_Array.count loop
			if p_Column_Name LIKE p_Pattern_Array(c_idx) ESCAPE '\' then
				RETURN 'YES';
			end if;
		end loop;
		RETURN 'NO';
	END;

	FUNCTION Strip_Comments ( p_Text VARCHAR2 ) RETURN VARCHAR2
	IS
		v_trim_set VARCHAR2(20) := CHR(32)||CHR(10)||CHR(13)||CHR(9);
	BEGIN
		RETURN LTRIM(RTRIM(REGEXP_REPLACE(REGEXP_REPLACE(p_Text, '--.*$', NULL, 1, 1, 'm'), '--.*$'), v_trim_set), v_trim_set);
	END;

    FUNCTION in_list( p_string in clob, p_delimiter in varchar2 := ';')
    RETURN sys.odciVarchar2List PIPELINED PARALLEL_ENABLE   -- VARCHAR2(4000)
    IS
	PRAGMA UDF;
        l_string    varchar2(32767);
        n           number          := length(p_string);
        p           number          := 1;
        l_dlen      constant number := length(p_delimiter);
        l_limit     constant number := 4000;
        l_Trim_Set  constant varchar2(50)  := chr(9)||chr(10)||chr(13)||chr(32);
    begin
        if p_string IS NOT NULL then
            loop
                exit when n = 0;
                n := DBMS_LOB.INSTR( p_string, p_delimiter, p );
                l_string := case when n >= p
                    then DBMS_LOB.SUBSTR( p_string, least(n-p, l_limit), p )
                    else DBMS_LOB.SUBSTR( p_string, l_limit, p )
                    end;
                pipe row( ltrim( rtrim( l_string, l_Trim_Set ), l_Trim_Set ) );
                p := n + l_dlen;
            end loop;
        end if;
        return ;
    END;

    FUNCTION F_BASE_KEY_COLS (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Result VARCHAR2(1000) := NULL;
    BEGIN
        FOR c_cur IN (
            SELECT B.COLUMN_NAME, B.POSITION
            FROM USER_CONS_COLUMNS B
            WHERE B.TABLE_NAME = p_TABLE_NAME
            AND B.CONSTRAINT_NAME = p_CONSTRAINT_NAME
            ORDER BY B.POSITION
        )
        LOOP
            v_Result := v_Result || ', ' || c_cur.COLUMN_NAME;
        END LOOP;
        RETURN LTRIM(v_Result, ', ');
    END;

    FUNCTION F_BASE_KEY_COND (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2,
        p_Prefix IN VARCHAR2 DEFAULT ':OLD.'
    )
    RETURN VARCHAR2
    IS
        v_Result VARCHAR2(32000);
    BEGIN
        FOR c_cur IN (
            SELECT B.COLUMN_NAME, B.POSITION,
                CASE WHEN B.POSITION = 1 THEN 'WHERE ' ELSE ' AND ' END
                || CASE WHEN B.COLUMN_NAME = changelog_conf.Get_ColumnWorkspace
                    THEN B.COLUMN_NAME || ' = ' || changelog_conf.Get_Context_WorkspaceID_Expr
                    ELSE B.COLUMN_NAME || ' = ' || p_Prefix || B.COLUMN_NAME
                END CONDITION
            FROM USER_CONS_COLUMNS B
            WHERE B.TABLE_NAME = p_TABLE_NAME
            AND B.CONSTRAINT_NAME = p_CONSTRAINT_NAME
            ORDER BY B.POSITION
        )
        LOOP
            v_Result := v_Result || c_cur.CONDITION;
        END LOOP;
        RETURN v_Result;
    END;

    FUNCTION F_VIEW_KEY_COND (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2,
        p_Prefix IN VARCHAR2 DEFAULT ':OLD.'
    )
    RETURN VARCHAR2
    IS
        v_Result VARCHAR2(32000);
    BEGIN
        FOR c_cur IN (
            SELECT B.COLUMN_NAME, B.POSITION,
                CASE WHEN B.POSITION = 1 THEN 'WHERE ' ELSE ' AND ' END
                || CASE WHEN B.COLUMN_NAME = changelog_conf.Get_ColumnWorkspace
                    THEN B.COLUMN_NAME || ' = ' || changelog_conf.Get_Context_WorkspaceID_Expr
                    ELSE B.COLUMN_NAME || ' = ' || p_Prefix || B.COLUMN_NAME
                END CONDITION
            FROM USER_CONS_COLUMNS B
            WHERE B.TABLE_NAME = p_TABLE_NAME
            AND B.CONSTRAINT_NAME = p_CONSTRAINT_NAME
            AND B.COLUMN_NAME <> changelog_conf.Get_ColumnDeletedMark
            ORDER BY B.POSITION
        )
        LOOP
            v_Result := v_Result || c_cur.CONDITION;
        END LOOP;
        RETURN v_Result;
    END;

    FUNCTION F_VIEW_KEY_COLS (
        p_TABLE_NAME IN VARCHAR2,
        p_CONSTRAINT_NAME IN VARCHAR2
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Result VARCHAR2(1000) := NULL;
    BEGIN
        FOR c_cur IN (
            SELECT B.COLUMN_NAME, B.POSITION
            FROM USER_CONS_COLUMNS B
            WHERE B.TABLE_NAME = p_TABLE_NAME
            AND B.CONSTRAINT_NAME = p_CONSTRAINT_NAME
            AND B.COLUMN_NAME <> changelog_conf.Get_ColumnDeletedMark
            AND B.COLUMN_NAME <> changelog_conf.Get_ColumnWorkspace
            ORDER BY B.POSITION
        )
        LOOP
            v_Result := v_Result || ', ' || c_cur.COLUMN_NAME;
        END LOOP;
        RETURN LTRIM(v_Result, ', ');
    END;

    FUNCTION F_VIEW_COLUMNS (
        p_TABLE_NAME IN VARCHAR2,
        p_SHORT_NAME IN VARCHAR2,
        p_ALIAS IN VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2
    IS
        v_Result VARCHAR2(32000) := NULL;
        v_Alias_Prefix  VARCHAR2(50);
    BEGIN
        v_Alias_Prefix := case when p_ALIAS IS NOT NULL then p_ALIAS || '.' end;
        FOR c_cur IN (
            SELECT COLUMN_NAME, COLUMN_ID
            FROM USER_TAB_COLS
            WHERE TABLE_NAME = p_TABLE_NAME
            AND COLUMN_NAME <> changelog_conf.Get_ColumnDeletedMark
            AND COLUMN_NAME <> changelog_conf.Get_ColumnWorkspace
			AND DATA_TYPE NOT IN ( -- 'BLOB', 'CLOB', 'NCLOB', 
				'ORDIMAGE', 'LONG')
			AND VIRTUAL_COLUMN = 'NO'
			AND HIDDEN_COLUMN = 'NO'
            ORDER BY COLUMN_ID
        )
        LOOP
            v_Result := v_Result || ', ' || v_Alias_Prefix || c_cur.COLUMN_NAME;
        END LOOP;
        RETURN LTRIM(v_Result, ', ');
    END;

    FUNCTION F_INTERSECT_COLUMNS (
        p_Table_Name IN VARCHAR2,
        p_Target_Owner IN VARCHAR2,
        p_Source_Owner IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        v_Result VARCHAR2(32000) := NULL;
    BEGIN
        FOR c_cur IN (
            SELECT B.COLUMN_NAME, B.COLUMN_ID
            FROM ALL_TAB_COLUMNS A
            JOIN ALL_TAB_COLUMNS B ON A.TABLE_NAME = B.TABLE_NAME AND A.COLUMN_NAME = B.COLUMN_NAME
            WHERE B.TABLE_NAME = p_TABLE_NAME
            AND A.OWNER = p_Target_Owner
            AND B.OWNER = p_Source_Owner
            AND B.COLUMN_NAME <> changelog_conf.Get_ColumnDeletedMark
            AND B.COLUMN_NAME <> changelog_conf.Get_ColumnWorkspace
            ORDER BY B.COLUMN_ID
        )
        LOOP
            v_Result := v_Result || ', ' || c_cur.COLUMN_NAME;
        END LOOP;
        RETURN LTRIM(v_Result, ', ');
    END;


    -- Definition of Column list of all tables and views --
    FUNCTION F_BASE_TABLE_COLS (
        p_TABLE_NAME IN VARCHAR2,
        p_FILTER IN VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Column_Name   VARCHAR2(50);
        v_Column_ID     NUMBER;
        v_Result        VARCHAR2(32000) := NULL;
        v_query         VARCHAR2(32000);
        TYPE cur_type IS REF CURSOR;
        col_cur         cur_type;
    BEGIN
        v_query := 'SELECT COLUMN_NAME, COLUMN_ID FROM USER_TAB_COLUMNS WHERE TABLE_NAME = :a '
        || case when p_FILTER IS NOT NULL then ' AND ' || p_FILTER end
        || ' ORDER BY COLUMN_ID';
        OPEN col_cur FOR v_query USING p_TABLE_NAME;
        LOOP
            FETCH col_cur INTO v_Column_Name, v_Column_ID;
            EXIT WHEN col_cur%NOTFOUND;
            v_Result := v_Result || ', ' || v_Column_Name;
        END LOOP;
        RETURN LTRIM(v_Result, ', ');
    END F_BASE_TABLE_COLS;
    

	FUNCTION Next_Key_Function (
        p_Table_Name    IN VARCHAR2,
		p_Primary_Key_Col IN VARCHAR2,
		p_Sequence_Name IN VARCHAR2
	) RETURN VARCHAR2
	IS
		v_Cnt NUMBER;
	BEGIN
		SELECT COUNT(*)
		INTO v_Cnt
		FROM USER_SEQUENCES
		WHERE SEQUENCE_NAME = p_Sequence_Name;
		if v_Cnt > 0 THEN
			RETURN p_Sequence_Name || '.NEXTVAL';
		END IF;
		SELECT COUNT(*)
		INTO v_Cnt
		FROM USER_TAB_COLS
		WHERE TABLE_NAME = p_Table_Name
		AND COLUMN_NAME = p_Primary_Key_Col
		AND DATA_TYPE = 'NUMBER'
		AND DATA_LENGTH >= 22
		AND DATA_PRECISION IS NULL
		AND DATA_SCALE IS NULL
		AND VIRTUAL_COLUMN = 'NO'
		AND HIDDEN_COLUMN = 'NO';
		if v_Cnt > 0 THEN
			RETURN changelog_conf.Get_Sys_Guid_Function;
		END IF;
		RETURN NULL;
	END Next_Key_Function;

	FUNCTION Before_Insert_Trigger_body (
		p_Table_Name				VARCHAR2,
		p_Primary_Key_Col			VARCHAR2,
		p_Has_Serial_Primary_Key	VARCHAR2,
		p_Sequence_Name				VARCHAR2,
		p_Column_CreDate			VARCHAR2,
		p_Column_CreUser			VARCHAR2,
		p_Column_ModDate			VARCHAR2,
		p_Column_ModUser			VARCHAR2
	) RETURN VARCHAR2
	IS
		v_Default				VARCHAR2(4000);
		v_Next_Key_Function		VARCHAR2(4000);
		v_Stat                  VARCHAR2(4000);
		v_Owner 				VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
	BEGIN
		IF p_Has_Serial_Primary_Key = 'YES' THEN
			v_Next_Key_Function	:= Next_Key_Function(p_Table_Name, p_Primary_Key_Col, p_Sequence_Name);
			IF v_Next_Key_Function IS NOT NULL THEN
				v_Stat := v_Stat
				|| '    if :new.' || p_Primary_Key_Col || ' is null then '  || chr(10)
				|| '        SELECT ' || v_Next_Key_Function || ' INTO :new.' || p_Primary_Key_Col || ' FROM DUAL;'  || chr(10)
				|| '    end if; '  || chr(10);
			END IF;
		END IF;
		IF changelog_conf.Get_Use_Audit_Info_Columns = 'YES' THEN
			IF p_Column_CreUser IS NOT NULL THEN
				v_Default := Get_ColumnDefaultText (p_Table_Name, v_Owner, p_Column_CreUser);
				IF v_Default IS NULL OR changelog_conf.Get_Enforce_Not_Null = 'YES' THEN
					v_Stat := v_Stat
					|| '    :new.' || p_Column_CreUser || ' := NVL(:new.' || p_Column_CreUser || ', ' || changelog_conf.Get_FunctionModifyUser || ');' || chr(10);
				END IF;
			END IF;
			IF p_Column_CreDate IS NOT NULL THEN
				v_Default := Get_ColumnDefaultText (p_Table_Name, v_Owner, p_Column_CreDate);
				IF v_Default IS NULL OR changelog_conf.Get_Enforce_Not_Null = 'YES' THEN
					v_Stat := v_Stat
					|| '    :new.' || p_Column_CreDate || ' := NVL(:new.' || p_Column_CreDate || ', ' || changelog_conf.Get_FunctionModifyDate || ');' || chr(10);
				END IF;
			END IF;
			IF p_Column_ModUser IS NOT NULL AND changelog_conf.Get_Enforce_Not_Null = 'YES' THEN
				v_Stat := v_Stat
				|| '    :new.' || p_Column_ModUser || ' := NVL(:new.' || p_Column_ModUser || ', ' || changelog_conf.Get_FunctionModifyUser || ');' || chr(10);
			END IF;
			IF p_Column_ModDate IS NOT NULL AND changelog_conf.Get_Enforce_Not_Null = 'YES' THEN
				v_Stat := v_Stat
				|| '    :new.' || p_Column_ModDate || ' := NVL(:new.' || p_Column_ModDate || ', ' || changelog_conf.Get_FunctionModifyDate || ');' || chr(10);
			END IF;
		END IF;

		return v_Stat;
	END Before_Insert_Trigger_body;

	FUNCTION Before_Update_Trigger_body (
		p_Column_ModDate			VARCHAR2,
		p_Column_ModUser			VARCHAR2
	) RETURN VARCHAR2
	IS
		v_Stat                  VARCHAR2(4000);
		v_check_cur_user		BOOLEAN;
	BEGIN
		IF changelog_conf.Get_Use_Audit_Info_Columns = 'YES'
		AND (p_Column_ModUser IS NOT NULL OR p_Column_ModDate IS NOT NULL) THEN
			v_check_cur_user := (g_ForeignKeyModifyUser = 'YES' and g_DatatypeModifyUser = 'NUMBER' and p_Column_ModUser IS NOT NULL);
			IF v_check_cur_user THEN
				v_Stat := '    if ' || changelog_conf.Get_Context_User_ID_Expr || ' IS NOT NULL then ' || chr(10);
			END IF;
			IF p_Column_ModUser IS NOT NULL THEN
				v_Stat := v_Stat
				|| '        :new.' || p_Column_ModUser || ' := ' || changelog_conf.Get_FunctionModifyUser  || ';' || chr(10);
			END IF;
			IF p_Column_ModDate IS NOT NULL THEN
				v_Stat := v_Stat
				|| '        :new.' || p_Column_ModDate || ' := ' || changelog_conf.Get_FunctionModifyDate || ';' || chr(10);
			END IF;
			IF v_check_cur_user THEN
				v_Stat := v_Stat
				|| '    end if;' || chr(10);
			END IF;
		END IF;
		return v_Stat;
	END Before_Update_Trigger_body;

    

	FUNCTION Constraint_Condition_Cursor (
		p_Table_Name IN VARCHAR2 DEFAULT NULL,
		p_Constraint_Name IN VARCHAR2 DEFAULT NULL
	) RETURN changelog_conf.tab_constraint_condition PIPELINED PARALLEL_ENABLE
	is
		v_out_rec changelog_conf.rec_constraint_condition;
		v_Search_Condition VARCHAR2(4000);
	begin
		for c_cur in (
			SELECT C.OWNER, C.TABLE_NAME, C.CONSTRAINT_NAME, C.SEARCH_CONDITION
			FROM USER_CONSTRAINTS C
			WHERE C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
			AND C.CONSTRAINT_NAME = NVL(p_Constraint_Name, C.CONSTRAINT_NAME)
			AND C.CONSTRAINT_TYPE = 'C' -- check constraint
			AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
		) loop
			v_Search_Condition			:= c_cur.SEARCH_CONDITION;
			v_out_rec.OWNER 			:= c_cur.OWNER;
			v_out_rec.TABLE_NAME 		:= c_cur.TABLE_NAME;
			v_out_rec.CONSTRAINT_NAME 	:= c_cur.CONSTRAINT_NAME;
			v_out_rec.SEARCH_CONDITION 	:= changelog_conf.Strip_Comments (v_Search_Condition);
			if v_out_rec.SEARCH_CONDITION IS NOT NULL then
				pipe row (v_out_rec);
			end if;
		end loop;
	end Constraint_Condition_Cursor;

    FUNCTION Get_ChangeLogTable RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN RETURN g_ChangeLogTable; END;
    
    FUNCTION Get_ChangeLogFKeyTables RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_ChangeLogFKeyTables; END;
    
    FUNCTION Get_ChangeLog_Custom_Ref(p_Table_Name VARCHAR2) RETURN VARCHAR2
    IS
		v_Pattern_Array apex_t_varchar2;
    BEGIN 
		v_Pattern_Array := apex_string.split(g_ChangeLogFKeyTables, ',');
		for c_idx IN 1..v_Pattern_Array.count loop
			if TRIM(v_Pattern_Array(c_idx)) = p_Table_Name then 
				return 'CUSTOM_REF_ID' || c_idx;
			end if;
		end loop;
    	RETURN NULL; 
    END;
        
    FUNCTION Get_ChangeLogFKeyColumns RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_ChangeLogFKeyColumns; END;
    FUNCTION Get_IncludeChangeLogPattern RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_IncludeChangeLogPattern; END;
    FUNCTION Get_ExcludeChangeLogPattern RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN Concat_List(g_ExcludeChangeLogPattern, c_ExcludeChangeLogPattern); END;
    FUNCTION Get_ReferenceDescriptionCols RETURN VARCHAR2 IS
	PRAGMA UDF;
    BEGIN RETURN g_ReferenceDescriptionCols; END;


BEGIN
	Load_Config;
END changelog_conf;
/
show errors

