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

GRANT CREATE MATERIALIZED VIEW TO OWNER;
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO OWNER;
GRANT EXECUTE ON SYS.DBMS_STATS TO OWNER;
GRANT EXECUTE ON SYS.DBMS_MVIEW TO OWNER;
GRANT EXECUTE ON SYS.DBMS_SQL TO OWNER;
GRANT CREATE JOB TO OWNER;
GRANT EXECUTE ON CTXSYS.CTX_DDL TO OWNER;
----

DROP TABLE DATA_BROWSER_CONFIG;
DROP  PACKAGE data_browser_conf;

*/
set scan off
-- ALTER SESSION SET PLSQL_CODE_TYPE = NATIVE;
-- ALTER SESSION SET PLSQL_OPTIMIZE_LEVEL = 3;
-- ALTER SESSION SET PLSQL_WARNINGS='ENABLE:PERFORMANCE';


CREATE OR REPLACE TRIGGER DATA_BROWSER_CONFIG_BU_TR
BEFORE INSERT OR UPDATE OF
DATA_DEDUCTION_PATTERN, FOLDER_PARENT_FIELD_PATTERN, FOLDER_NAME_FIELD_PATTERN, ACTIVE_LOV_FIELDS_PATTERN,
FILE_PRIVILEGE_FLD_PATTERN, ENCRYPTED_COLUMN_PATTERN, OBFUSCATION_COLUMN_PATTERN, UPPER_NAMES_COLUMN_PATTERN, FLIP_STATE_COLUMN_PATTERN,
SOFT_LOCK_FIELD_PATTERN, HTML_FIELDS_PATTERN, HAND_SIGNATUR_PATTERN, CALENDAR_START_DATE_PATTERN, CALENDAR_END_DATE_PATTERN,
SUMMAND_FIELD_PATTERN, MINUEND_FIELD_PATTERN, FACTORS_FIELD_PATTERN, INDEX_FORMAT_FIELD_PATTERN,
FILE_FOLDER_FIELD_PATTERN, EDIT_TABLES_PATTERN, ADMIN_TABLES_PATTERN, INCLUDED_TABLES_PATTERN,
EXCLUDED_TABLES_PATTERN, READONLY_COLUMNS_PATTERN, HIDDEN_COLUMNS_PATTERN, IGNORED_COLUMNS_PATTERN,
DISPLAY_COLUMNS_PATTERN, DATETIME_COLUMNS_PATTERN, PASSWORD_COLUMN_PATTERN, ROW_VERSION_COLUMN_PATTERN,
FILE_NAME_COLUMN_PATTERN, MIME_TYPE_COLUMN_PATTERN, FILE_CREATED_COLUMN_PATTERN, FILE_CONTENT_COLUMN_PATTERN,
YES_NO_COLUMNS_PATTERN, READONLY_TABLES_PATTERN, ROW_LOCK_COLUMN_PATTERN, SOFT_DELETE_COLUMN_PATTERN,
ORDERING_COLUMN_PATTERN, AUDIT_COLUMN_PATTERN, CURRENCY_COLUMN_PATTERN, Thumbnail_Column_Pattern, KEY_COLUMN_EXT, BASE_TABLE_EXT, BASE_VIEW_EXT,
HISTORY_VIEW_EXT, BASE_TABLE_PREFIX, BASE_VIEW_PREFIX
ON DATA_BROWSER_CONFIG FOR EACH ROW
BEGIN
	:new.Edit_Tables_Pattern   		:= UPPER(REPLACE(:new.Edit_Tables_Pattern, ' '));
	:new.ReadOnly_Tables_Pattern   	:= UPPER(REPLACE(:new.ReadOnly_Tables_Pattern, ' '));
	:new.Admin_Tables_Pattern   	:= UPPER(REPLACE(:new.Admin_Tables_Pattern, ' '));
	:new.Included_Tables_Pattern   	:= UPPER(REPLACE(:new.Included_Tables_Pattern, ' '));
	:new.Excluded_Tables_Pattern   	:= UPPER(REPLACE(:new.Excluded_Tables_Pattern, ' '));
	:new.ReadOnly_Columns_Pattern   := UPPER(REPLACE(:new.ReadOnly_Columns_Pattern, ' '));
	:new.Hidden_Columns_Pattern   	:= UPPER(REPLACE(:new.Hidden_Columns_Pattern, ' '));
	:new.Data_Deduction_Pattern   	:= UPPER(REPLACE(:new.Data_Deduction_Pattern, ' '));
	:new.Ignored_Columns_Pattern   	:= UPPER(REPLACE(:new.Ignored_Columns_Pattern, ' '));
	:new.Display_Columns_Pattern   	:= UPPER(REPLACE(:new.Display_Columns_Pattern, ' '));
	:new.DateTime_Columns_Pattern   := UPPER(REPLACE(:new.DateTime_Columns_Pattern, ' '));
	:new.Password_Column_Pattern    := UPPER(REPLACE(:new.Password_Column_Pattern, ' '));
	:new.Row_Version_Column_Pattern := UPPER(REPLACE(:new.Row_Version_Column_Pattern, ' '));
	:new.Row_Lock_Column_Pattern 	:= UPPER(REPLACE(:new.Row_Lock_Column_Pattern, ' '));
	:new.Soft_Delete_Column_Pattern := UPPER(REPLACE(:new.Soft_Delete_Column_Pattern, ' '));
	:new.Ordering_Column_Pattern 	:= UPPER(REPLACE(:new.Ordering_Column_Pattern, ' '));
	:new.Audit_Column_Pattern 		:= UPPER(REPLACE(:new.Audit_Column_Pattern, ' '));
	:new.Currency_Column_Pattern 	:= UPPER(REPLACE(:new.Currency_Column_Pattern, ' '));
	:new.Thumbnail_Column_Pattern 	:= UPPER(REPLACE(:new.Thumbnail_Column_Pattern, ' '));
	:new.File_Name_Column_Pattern 	:= UPPER(REPLACE(:new.File_Name_Column_Pattern, ' '));
	:new.Mime_Type_Column_Pattern 	:= UPPER(REPLACE(:new.Mime_Type_Column_Pattern, ' '));
	:new.File_Created_Column_Pattern := UPPER(REPLACE(:new.File_Created_Column_Pattern, ' '));
	:new.File_Content_Column_Pattern := UPPER(REPLACE(:new.File_Content_Column_Pattern, ' '));
	:new.Index_Format_Field_Pattern := UPPER(REPLACE(:new.Index_Format_Field_Pattern, ' '));
	:new.File_Folder_Field_Pattern 	:= UPPER(REPLACE(:new.File_Folder_Field_Pattern, ' '));
	:new.Folder_Parent_Field_Pattern := UPPER(REPLACE(:new.Folder_Parent_Field_Pattern, ' '));
	:new.Folder_Name_Field_Pattern 	:= UPPER(REPLACE(:new.Folder_Name_Field_Pattern, ' '));
	:new.File_Privilege_Fld_Pattern := UPPER(REPLACE(:new.File_Privilege_Fld_Pattern, ' '));
	:new.Encrypted_Column_Pattern 	:= UPPER(REPLACE(:new.Encrypted_Column_Pattern, ' '));
	:new.Obfuscation_Column_Pattern := UPPER(REPLACE(:new.Obfuscation_Column_Pattern, ' '));
	:new.Upper_Names_Column_Pattern := UPPER(REPLACE(:new.Upper_Names_Column_Pattern, ' '));
	:new.Flip_State_Column_Pattern 	:= UPPER(REPLACE(:new.Flip_State_Column_Pattern, ' '));
	:new.Active_Lov_Fields_Pattern 	:= UPPER(REPLACE(:new.Active_Lov_Fields_Pattern, ' '));
	:new.Soft_Lock_Field_Pattern 	:= UPPER(REPLACE(:new.Soft_Lock_Field_Pattern, ' '));
	:new.Html_Fields_Pattern 		:= UPPER(REPLACE(:new.Html_Fields_Pattern, ' '));
	:new.Hand_Signatur_Pattern 		:= UPPER(REPLACE(:new.Hand_Signatur_Pattern, ' '));
	:new.Calendar_Start_Date_Pattern:= UPPER(REPLACE(:new.Calendar_Start_Date_Pattern, ' '));
	:new.Calendar_End_Date_Pattern  := UPPER(REPLACE(:new.Calendar_End_Date_Pattern, ' '));
	:new.Summand_Field_Pattern 		:= UPPER(REPLACE(:new.Summand_Field_Pattern, ' '));
	:new.Minuend_Field_Pattern 		:= UPPER(REPLACE(:new.Minuend_Field_Pattern, ' '));
	:new.Factors_Field_Pattern 		:= UPPER(REPLACE(:new.Factors_Field_Pattern, ' '));
	:new.Yes_No_Columns_Pattern   	:= UPPER(REPLACE(:new.Yes_No_Columns_Pattern, ' '));
	:new.Key_Column_Ext   			:= UPPER(REPLACE(:new.Key_Column_Ext, ' '));
	:new.Base_Table_Prefix   		:= UPPER(REPLACE(:new.Base_Table_Prefix, ' '));
	:new.Base_Table_Ext   			:= UPPER(REPLACE(:new.Base_Table_Ext, ' '));
	:new.Base_View_Prefix   		:= UPPER(REPLACE(:new.Base_View_Prefix, ' '));
	:new.Base_View_Ext   			:= UPPER(REPLACE(:new.Base_View_Ext, ' '));
	:new.History_View_Ext   		:= UPPER(REPLACE(:new.History_View_Ext, ' '));
	:new.LAST_MODIFIED_BY 			:= NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
	:new.LAST_MODIFIED_AT   		:= LOCALTIMESTAMP;
END;
/


-------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE data_browser_conf
AUTHID DEFINER -- enable jobs to find translations.
IS
	g_App_Version_Number		VARCHAR2(64)	:= '1.9.23'; -- enable version upgrade to determinate required library updates
	g_App_Licence_Number		VARCHAR2(64)	:= '';		-- Licence Number from Software Registration
	g_App_Licence_Owner			VARCHAR2(300)	:= '';		-- Licence Owner from Software Registration
	g_App_Installation_Code		VARCHAR2(300)	:= '';		-- hashed installation date. Expire Demo Version after trial periode
	g_App_Created_At			DATE;
	g_App_Created_By 			VARCHAR2(64)	:= '';
	g_Software_Copyright		CONSTANT VARCHAR2(64) := 'Strack Software Development, Berlin, Germany';

	g_use_exceptions 			CONSTANT BOOLEAN 	:= TRUE;	-- when enabled, errors are handled via exceptions; disable to find proper error line number.
	g_runtime_exceptions		CONSTANT BOOLEAN 	:= FALSE;	-- when enabled, runtime parameter errors are handled via exceptions; disable to tolerate missing parameters
	g_debug 					CONSTANT BOOLEAN 	:= FALSE;
	
	PROCEDURE Save_Config_Defaults;
	PROCEDURE Load_Config;
    FUNCTION Has_Multiple_Workspaces RETURN VARCHAR2; -- YES/NO
    FUNCTION Get_Apex_Version RETURN VARCHAR2;
	PROCEDURE Touch_Configuration;
    FUNCTION Get_App_Library_Version RETURN VARCHAR2;
    PROCEDURE Set_App_Library_Version (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    );
    FUNCTION Get_Data_Browser_Version_Number (
		p_Schema_Name VARCHAR2
	) RETURN VARCHAR2;

    FUNCTION Get_App_Licence_Number RETURN VARCHAR2;
    FUNCTION Get_App_Licence_Owner RETURN VARCHAR2;
    FUNCTION Get_App_Installation_Code RETURN VARCHAR2;
	PROCEDURE Set_App_Installation_Code (p_Code IN VARCHAR2);
	FUNCTION Get_Configuration_ID RETURN NUMBER;
    FUNCTION Get_Configuration_Name RETURN VARCHAR2;
    FUNCTION Get_Email_From_Address RETURN VARCHAR2;
    FUNCTION Get_Schema_Icon RETURN VARCHAR2;
    FUNCTION Get_Reports_Application_ID RETURN NUMBER;
    FUNCTION Get_Reports_App_Page_ID RETURN NUMBER;
    FUNCTION Get_Client_Application_ID RETURN NUMBER;
    FUNCTION Get_Client_App_Page_ID RETURN NUMBER;
	FUNCTION Get_APEX_URL_Element (p_Text VARCHAR2, p_Element NUMBER) RETURN VARCHAR2;
	FUNCTION Match_Pattern (p_Text VARCHAR2, p_Pattern VARCHAR2) RETURN BOOLEAN DETERMINISTIC;
	FUNCTION Normalize_Column_Pattern (p_Pattern VARCHAR2) RETURN VARCHAR2;
	FUNCTION Match_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern VARCHAR2) RETURN VARCHAR2 DETERMINISTIC; -- YES, NO
	FUNCTION Matching_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern VARCHAR2) RETURN VARCHAR2;
	FUNCTION Match_DateTime_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	
    FUNCTION Get_Link_ID_Expression (	-- row reference in select list, produces CAST(A.ROWID AS VARCHAR2(128)) references in case of composite or missing unique keys
    	p_Unique_Key_Column VARCHAR2,
    	p_Table_Alias VARCHAR2 DEFAULT NULL,
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    )
    RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Unique_Key_Expression (	-- row reference in where clause, produces A.ROWID references in case of composite or missing unique keys
    	p_Unique_Key_Column VARCHAR2,
    	p_Table_Alias	VARCHAR2 DEFAULT 'A',
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Foreign_Key_Expression (	-- row reference in where clause, produces FN_Hex_Hash_Key references in case of composite unique keys
    	p_Foreign_Key_Column VARCHAR2,
    	p_Table_Alias 		VARCHAR2 DEFAULT 'A',
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Join_Expression (
    	p_Left_Columns 	VARCHAR2,
    	p_Left_Alias 	VARCHAR2 DEFAULT 'A',
    	p_Right_Columns VARCHAR2,
    	p_Right_Alias 	VARCHAR2 DEFAULT 'B'
    ) RETURN VARCHAR2;

	FUNCTION ChangeLog_Pivot_Query (
		p_Table_Name VARCHAR2,
		p_Convert_Data_Types IN VARCHAR2 DEFAULT 'YES',
		p_Compact_Queries VARCHAR2 DEFAULT 'NO' -- YES, NO
	) RETURN CLOB;
	FUNCTION Check_Developer_Enabled RETURN BOOLEAN;
	FUNCTION Check_Edit_Enabled RETURN BOOLEAN;
    FUNCTION Check_Edit_Enabled(
    	p_Table_Name VARCHAR2
    ) RETURN VARCHAR2; -- YES, NO
    FUNCTION Check_Data_Deduction (
    	p_Column_Name VARCHAR2
    ) RETURN VARCHAR2;
    FUNCTION Check_Admin_Enabled(p_Table_Name VARCHAR2) RETURN BOOLEAN;
    FUNCTION Get_Admin_Enabled RETURN VARCHAR2;
    FUNCTION Get_Install_Sup_Obj_Enabled RETURN VARCHAR2;

    FUNCTION Get_Detect_Yes_No_Static_LOV RETURN VARCHAR2;
    FUNCTION Get_Yes_No_Column_Type (
    	p_Table_Name VARCHAR2,
    	p_Table_Owner VARCHAR2,
    	p_Column_Name VARCHAR2,
		p_Data_Type VARCHAR2,
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Char_Length NUMBER,
		p_Nullable VARCHAR2,
		p_Num_Distinct NUMBER,
		p_Default_Text VARCHAR2,
		p_Check_Condition VARCHAR2,
		p_Explain VARCHAR2 DEFAULT 'NO'
    )
    RETURN VARCHAR2;

    FUNCTION Get_Yes_No_Column_Type (
    	p_Table_Name VARCHAR2,
    	p_Table_Owner VARCHAR2,
    	p_Column_Name VARCHAR2
    )
    RETURN VARCHAR2;
    
    FUNCTION Get_Yes_No_Type_LOV (
    	p_Data_type VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Boolean_Yes_Value (
    	p_Data_type VARCHAR2,
    	p_Expr_Type VARCHAR2 DEFAULT 'VALUE' -- VALUE, ENQUOTE, LABEL, TRANSLATE
    ) RETURN VARCHAR2;

    FUNCTION Get_Boolean_No_Value (
    	p_Data_type VARCHAR2,
    	p_Expr_Type VARCHAR2 DEFAULT 'VALUE' -- VALUE, ENQUOTE, LABEL, TRANSLATE
    ) RETURN VARCHAR2;

    FUNCTION Get_Yes_No_Static_LOV(
    	p_Data_type VARCHAR2
    ) RETURN VARCHAR2;
    
    FUNCTION Get_Yes_No_Check (
    	p_Data_type VARCHAR2,
    	p_Column_Name VARCHAR2 
    ) RETURN VARCHAR2;
    
    FUNCTION Lookup_Yes_No (
    	p_Data_type VARCHAR2,
    	p_Column_Value VARCHAR2 
    ) RETURN VARCHAR2;

    FUNCTION Lookup_Yes_No_Call (
    	p_Data_type VARCHAR2,
    	p_Column_Name VARCHAR2 
    ) RETURN VARCHAR2;

    FUNCTION Get_Yes_No_Static_Function (
    	p_Column_Name VARCHAR2,
    	p_Data_type VARCHAR2
    ) RETURN VARCHAR2;

	FUNCTION Enquote_Literal ( p_Text VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Dequote_Literal ( p_Text VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Enquote_Name_Required (p_Text VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	PROCEDURE Set_Generate_Compact_Queries (
		p_Yes_No VARCHAR2
	);
	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Row_Selector_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Row_Selector_Expr RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Link_ID_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Link_ID_Expr RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Search_Column_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Search_Operator_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Search_Value_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Search_LOV_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Search_Active_Index RETURN PLS_INTEGER DETERMINISTIC;
    FUNCTION Get_Search_Seq_ID_Index RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Joins_Alias_Index RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Joins_Option_Index RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Sys_Guid_Function RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_MD5_Column_Name RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_MD5_Column_Index RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Export_CSV_Mode RETURN VARCHAR2;
    FUNCTION Get_Export_NumChars(p_Enquote VARCHAR2 DEFAULT 'YES') RETURN VARCHAR2;
    FUNCTION Get_Export_NLS_Param RETURN VARCHAR2;
    FUNCTION Get_Export_Number (p_Value VARCHAR2) RETURN NUMBER;
    FUNCTION Get_Number_Decimal_Character RETURN VARCHAR2;
    FUNCTION Get_Number_Group_Separator RETURN VARCHAR2;
    FUNCTION Get_Number_Pattern RETURN VARCHAR2;
	
	FUNCTION Get_NLS_Date_Format RETURN VARCHAR2;
	FUNCTION Get_NLS_NumChars RETURN VARCHAR2;
	FUNCTION Get_NLS_Currency RETURN VARCHAR2;
	FUNCTION Get_NLS_Decimal_Radix_Char RETURN VARCHAR2;
	FUNCTION Get_NLS_Decimal_Grouping_Char RETURN VARCHAR2;
	FUNCTION Get_NLS_Column_Delimiter_Char RETURN VARCHAR2;
	FUNCTION Get_Default_Currency_Precision (
		p_Data_Precision NUMBER,
		p_Is_Currency VARCHAR2,
		p_Data_Type VARCHAR2
	) RETURN NUMBER DETERMINISTIC;
	FUNCTION Get_Default_Currency_Scale (
		p_Data_Scale NUMBER,
		p_Is_Currency VARCHAR2,
		p_Data_Type VARCHAR2
	) RETURN NUMBER DETERMINISTIC;
	FUNCTION Get_Export_Float_Format RETURN VARCHAR2;
	FUNCTION Get_Export_Date_Format RETURN VARCHAR2;
	FUNCTION Get_Export_DateTime_Format RETURN VARCHAR2;
	FUNCTION Get_Timestamp_Format(
		p_Is_DateTime VARCHAR2 DEFAULT 'N'
	) RETURN VARCHAR2;
	PROCEDURE Set_Export_NumChars (
		p_Decimal_Character VARCHAR2,
		p_Group_Separator VARCHAR2
	);
	PROCEDURE Set_Use_App_Date_Time_Format(p_Yes_No VARCHAR2);
	FUNCTION Get_Rec_Desc_Delimiter RETURN VARCHAR2;
	FUNCTION Get_Rec_Desc_Group_Delimiter RETURN VARCHAR2;
	FUNCTION Get_TextArea_Min_Length RETURN NUMBER;
	FUNCTION Get_TextArea_Max_Length RETURN NUMBER;
	FUNCTION Get_Export_Text_Limit RETURN NUMBER;
	FUNCTION Get_Input_Field_Width (
		p_Field_Length NUMBER
	) RETURN NUMBER;
	FUNCTION Get_Button_Size (
		p_Report_Mode VARCHAR2,
		p_Column_Expr_Type VARCHAR2
	) RETURN NUMBER;
	FUNCTION Get_Input_Field_Style (
		p_Field_Length NUMBER,
		p_Button_Size NUMBER DEFAULT 0,
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2;

	FUNCTION Get_Minimum_Field_Width RETURN VARCHAR2;
	FUNCTION Get_Maximum_Field_Width RETURN VARCHAR2;
	FUNCTION Get_Stretch_Form_Fields RETURN VARCHAR2;
	FUNCTION Get_Select_List_Rows_Limit RETURN NUMBER;

	FUNCTION Get_Show_Tree_Num_Rows RETURN VARCHAR2;
	FUNCTION Get_Update_Tree_Num_Rows RETURN VARCHAR2;
	FUNCTION Get_Max_Relations_Levels RETURN NUMBER;

    FUNCTION Get_Base_Table_Ext RETURN VARCHAR2;
    FUNCTION Get_Base_View_Prefix RETURN VARCHAR2;
    FUNCTION Get_Base_View_Ext RETURN VARCHAR2;
    FUNCTION Get_History_View_Name(p_Name VARCHAR2) RETURN VARCHAR2;

	FUNCTION Get_Include_Query_Schema RETURN VARCHAR2;
	PROCEDURE Set_Include_Query_Schema (p_Value VARCHAR2);
	FUNCTION Get_Search_Keys_Unique RETURN VARCHAR2;
	FUNCTION Get_Insert_Foreign_Keys RETURN VARCHAR2;
	PROCEDURE Set_Import_Parameter (
		p_Compare_Case_Insensitive	VARCHAR2 DEFAULT 'NO',
		p_Search_Keys_Unique 	VARCHAR2 DEFAULT 'NO',
		p_Insert_Foreign_Keys 	VARCHAR2 DEFAULT 'NO'
	);

	PROCEDURE Get_Import_Parameter (
		p_Compare_Case_Insensitive	OUT VARCHAR2,
		p_Search_Keys_Unique 	OUT VARCHAR2,
		p_Insert_Foreign_Keys 	OUT VARCHAR2
	);	
	FUNCTION Get_Encrypt_Function RETURN VARCHAR2;
    FUNCTION Get_Encrypt_Function(p_Key_Column VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_Hash_Function(p_Key_Column VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2;

	FUNCTION Display_Schema_Name (p_Schema_Name VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Normalize_Table_Name (p_Table_Name VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Normalize_Column_Name (
    	p_Column_Name VARCHAR2,
    	p_Remove_Extension VARCHAR2 DEFAULT 'YES',
    	p_Remove_Prefix VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Translate_Umlaute(p_Text VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Normalize_Umlaute(p_Text IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Scramble_Umlaute(p_Text IN VARCHAR2) RETURN VARCHAR2;
	FUNCTION Get_Obfuscate_Call(p_Text IN VARCHAR2) RETURN VARCHAR2;
	FUNCTION Get_Formated_User_Name(p_Text IN VARCHAR2) RETURN VARCHAR2;
	FUNCTION Table_Name_To_Header (p_Table_Name VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Compose_Table_Column_Name (
    	p_Table_Name VARCHAR2,
    	p_Column_Name VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION LOV_Initcap (
    	p_Column_Value VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Column_Name_to_Header (
    	p_Column_Name VARCHAR2,
    	p_Remove_Extension VARCHAR2 DEFAULT 'YES',
    	p_Remove_Prefix VARCHAR2 DEFAULT NULL,
    	p_Is_Upper_Name VARCHAR2 DEFAULT 'NO'
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Compose_Column_Name (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Deduplication VARCHAR2 DEFAULT 'NO',
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Compose_3Column_Names (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Third_Name VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Compose_FK_Column_Table_Name (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Table_Name VARCHAR2,
    	p_Remove_Prefix VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Get_Name_Part (
		p_Name IN VARCHAR2,
		p_Part IN NUMBER
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Get_Number_Format_Mask (
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Use_Group_Separator VARCHAR2 DEFAULT 'Y',
		p_Export VARCHAR2 DEFAULT 'Y',		-- use TM9
		p_Use_Trim VARCHAR2 DEFAULT 'N'		-- use FM
	)
	RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Column_Expr_Type (
    	p_Column_Name IN VARCHAR2,
		p_Data_type IN VARCHAR2,
		p_Char_Length IN NUMBER,
        p_Is_Readonly VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_ExportColFunction (
        p_Column_Name VARCHAR2,
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Char_Length NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Use_Trim VARCHAR2 DEFAULT 'Y',	-- trim leading spaces from formated numbers; trim text to limit
        p_Datetime VARCHAR2 DEFAULT NULL, 	-- Y,N
        p_use_NLS_params VARCHAR2 DEFAULT 'Y'
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Field_Length (
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Char_Length NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Datetime VARCHAR2 DEFAULT 'N' -- Y,N
    ) RETURN NUMBER DETERMINISTIC;

    FUNCTION Get_Col_Format_Mask (
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Char_Length NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Datetime VARCHAR2 DEFAULT NULL -- Y,N
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Char_to_Type_Expr (
    	p_Element VARCHAR2,
    	p_Element_Type VARCHAR2 DEFAULT 'C', -- C,N  = CHar/Number
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, COLLECTION, MEMORY, VIEW
        p_Data_Type VARCHAR2,
        p_Data_Scale NUMBER,
        p_Format_Mask VARCHAR2,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_use_NLS_params VARCHAR2 DEFAULT 'Y'
    ) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Build_Condition (
		p_Condition VARCHAR2,
		p_Term VARCHAR2,
		p_Add_NL VARCHAR2 DEFAULT 'YES'
	) return varchar2;

	FUNCTION Build_Parent_Key_Condition (
		p_Condition VARCHAR2,
    	p_Parent_Key_Column VARCHAR2,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2,			-- Page Item Name, Filter Value and default value for foreign key column
    	p_Parent_Key_Visible VARCHAR2,		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Nullable VARCHAR2		-- N, Y
	) return varchar2;

    FUNCTION Get_Display_Format_Mask (
        p_Format_Mask VARCHAR2,
        p_Data_Type VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Do_Compare_Case_Insensitive RETURN VARCHAR2;
    FUNCTION Get_Compare_Case_Insensitive (
        p_Column_Name VARCHAR2,
    	p_Element VARCHAR2,
    	p_Element_Type VARCHAR2 DEFAULT 'C', 	-- C,N  = CHar/Number
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', -- NEW_ROWS, TABLE, COLLECTION, MEMORY
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Format_Mask VARCHAR2,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Compare_Case_Insensitive VARCHAR2 DEFAULT Do_Compare_Case_Insensitive
    ) RETURN VARCHAR2;
	FUNCTION Get_Apex_Item_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Collection_Columns_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Edit_Columns_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Select_Columns_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Errors_Listed_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Edit_Rows_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Automatic_Sorting_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Automatic_Search_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Is_Automatic_Search_Enabled ( p_Table_Name VARCHAR2  ) RETURN VARCHAR2;
	FUNCTION Get_Navigation_Link_Limit RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_New_Rows_Default RETURN PLS_INTEGER DETERMINISTIC;
	FUNCTION Get_Clob_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Import_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Import_Desc_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Import_Error_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Validation_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Lookup_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Constraints_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;	
	FUNCTION Get_Filter_Cond_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Highlight_Search (
		p_Data VARCHAR2,
		p_Search VARCHAR2
	) RETURN VARCHAR2;

    FUNCTION Compare_Data ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Compare_Upper ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Compare_Number ( p_Bevore NUMBER, p_After NUMBER) RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Compare_Date ( p_Bevore DATE, p_After DATE) RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Compare_Timestamp ( p_Bevore TIMESTAMP WITH LOCAL TIME ZONE, p_After TIMESTAMP WITH LOCAL TIME ZONE) RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Compare_Blob ( p_Old_Blob BLOB, p_New_Blob BLOB)  RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Compare_Clob ( p_Old_Blob CLOB, p_New_Blob CLOB) RETURN BOOLEAN DETERMINISTIC;
    FUNCTION Get_CompareFunction( p_DATA_TYPE VARCHAR2, p_Compare_Case_Insensitive VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Data ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Upper ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Number ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore NUMBER, p_After NUMBER) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Date ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore DATE, p_After DATE) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Blob ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore BLOB, p_After BLOB) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Clob ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore CLOB, p_After CLOB) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Markup_Timestamp ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore TIMESTAMP WITH LOCAL TIME ZONE, p_After TIMESTAMP WITH LOCAL TIME ZONE) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Get_Markup_Function( p_Data_Type VARCHAR2, p_Compare_Case_Insensitive VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION First_Element (str VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ', '
	)
    RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Strip_Comments ( p_Text VARCHAR2 ) RETURN VARCHAR2;
	FUNCTION Get_ConstraintText (p_Table_Name VARCHAR2, p_Owner VARCHAR2, p_Constraint_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_ColumnDefaultText (p_Table_Name VARCHAR2, p_Owner VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2;
    FUNCTION Get_TriggerText (p_Table_Name VARCHAR2, p_Trigger_Name VARCHAR2) RETURN CLOB;

	FUNCTION Get_Apex_Item_Row_Count (	-- item count in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER DEFAULT 1,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER DEFAULT 1		-- row offset for item index > 50
	) RETURN NUMBER;

    FUNCTION in_list(
    	p_string in clob,
    	p_delimiter in varchar2 DEFAULT ';'
    )
    RETURN sys.odciVarchar2List PIPELINED DETERMINISTIC PARALLEL_ENABLE;   -- VARCHAR2(4000)

	TYPE rec_replace_list IS RECORD (
		string			VARCHAR2(2048),
		search_str		VARCHAR2(256),
		replace_str		VARCHAR2(256)
	);
	TYPE tab_replace_list IS TABLE OF rec_replace_list;
	TYPE cur_replace_list IS REF CURSOR RETURN rec_replace_list;	

	FUNCTION replace_agg (
		p_cur data_browser_conf.cur_replace_list
	)
    RETURN sys.odciVarchar2List PIPELINED DETERMINISTIC PARALLEL_ENABLE;  -- VARCHAR2(4000)

	FUNCTION Table_Alias_To_Sequence (p_Symbol_Name VARCHAR2) RETURN NUMBER;
	FUNCTION Sequence_To_Table_Alias (p_Sequence NUMBER) RETURN VARCHAR2;

	FUNCTION FN_Query_Cardinality (
		p_Table_Name IN VARCHAR2,
		p_Column_Name IN VARCHAR2 DEFAULT NULL,
		p_Value IN VARCHAR2 DEFAULT NULL
	) RETURN NUMBER;

	PROCEDURE Compile_Invalid_Objects;
	---------------------------------------------------------------------------

	SUBTYPE t_col_value IS VARCHAR2(4000);	-- technical limit for apex_item_ref
	SUBTYPE t_col_html IS VARCHAR2(32767);	
	-- TYPE col_values_list is table of t_col_value; -- use apex_t_varchar2 instead

	TYPE rec_describe_joins IS RECORD (
		COLUMN_NAME 		VARCHAR2(128),
		SQL_TEXT 			VARCHAR2(4000),
		COLUMN_ID 			NUMBER(4),
		POSITION			NUMBER(4),
		MATCHING			NUMBER(4),
		COLUMNS_INCLUDED	VARCHAR2(2),
		TABLE_ALIAS 		VARCHAR2(10),
		R_TABLE_NAME		VARCHAR2(128),
		JOIN_HEADER			VARCHAR2(128),
		SOURCE_INFO			VARCHAR2(10)
	);
	-- output of data_browser_joins.Get_Detail_Table_Joins_Cursor
	TYPE tab_describe_joins IS TABLE OF rec_describe_joins;

	TYPE rec_join_options IS RECORD (
		DESCRIPTION 		VARCHAR2(512),
		COLUMNS_INCLUDED 	VARCHAR2(4000)
	);
	TYPE tab_join_options IS TABLE OF rec_join_options;

	TYPE rec_col_value IS RECORD (
		COLUMN_NAME VARCHAR2(512),
		COLUMN_HEADER VARCHAR2(1024),
		COLUMN_DATA t_col_value
	);
	-- output of data_browser_utl.Column_Value_List, data_browser_utl.Get_Detail_View_Column_Cursor
	TYPE tab_col_value IS TABLE OF rec_col_value;

	TYPE rec_constraint_condition IS RECORD (
		OWNER				VARCHAR2(128),
		TABLE_NAME 			VARCHAR2(128),
		CONSTRAINT_NAME 	VARCHAR2(128),
		SEARCH_CONDITION 	VARCHAR2(4000)
	);
	-- output of data_browser_utl.Constraint_Condition_Cursor
	TYPE tab_constraint_condition IS TABLE OF rec_constraint_condition;

	TYPE rec_constraint_columns IS RECORD (
		OWNER				VARCHAR2(128),
		TABLE_NAME 			VARCHAR2(128),
		COLUMN_NAME			VARCHAR2(128),
		POSITION			NUMBER,
		CONSTRAINT_NAME 	VARCHAR2(128),
		SEARCH_CONDITION 	VARCHAR2(4000)
	);
	-- output of data_browser_utl.Constraint_Condition_Cursor
	TYPE tab_constraint_columns IS TABLE OF rec_constraint_columns;

	TYPE rec_table_columns IS RECORD (
		TABLE_NAME              	VARCHAR2(128), 
		OWNER                 		VARCHAR2(128), 
		COLUMN_ID					NUMBER,
		COLUMN_NAME               	VARCHAR2(128), 
		DATA_TYPE					VARCHAR2(128), 
		NULLABLE					VARCHAR2(1), 
		NUM_DISTINCT				NUMBER,
		DEFAULT_LENGTH				NUMBER,
		DEFAULT_TEXT				VARCHAR2(1000), 
		DATA_PRECISION			  	NUMBER,
		DATA_SCALE					NUMBER,
		CHAR_LENGTH					NUMBER
	);
	TYPE tab_table_columns IS TABLE OF rec_table_columns;

	TYPE rec_table_column_in_list IS RECORD (
		TABLE_NAME              	VARCHAR2(128), 
		TABLE_OWNER                 VARCHAR2(128), 
		COLUMN_NAME               	VARCHAR2(128), 
		DISPLAY_VALUE				VARCHAR2(1024), 
		LIST_VALUE					VARCHAR2(1024), 
		DISP_SEQUENCE				NUMBER
	);
	TYPE tab_table_column_in_list IS TABLE OF rec_table_column_in_list;

	FUNCTION Constraint_Condition_Cursor (
		p_Table_Name IN VARCHAR2 DEFAULT NULL,
		p_Owner IN VARCHAR2 DEFAULT NULL,
		p_Constraint_Name IN VARCHAR2 DEFAULT NULL
	) RETURN data_browser_conf.tab_constraint_condition PIPELINED PARALLEL_ENABLE;

	FUNCTION Constraint_Columns_Cursor (
		p_Table_Name IN VARCHAR2 DEFAULT NULL,
		p_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Constraint_Name IN VARCHAR2 DEFAULT NULL
	) RETURN data_browser_conf.tab_constraint_columns PIPELINED PARALLEL_ENABLE;

	FUNCTION Table_Columns_Cursor(
    	p_Table_Name VARCHAR2 DEFAULT NULL,
    	p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Column_Name VARCHAR2 DEFAULT NULL
    )
	RETURN data_browser_conf.tab_table_columns PIPELINED PARALLEL_ENABLE;

	FUNCTION Is_Simple_IN_List (
		p_Check_Condition VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Get_Static_LOV_Expr (
		p_Check_Condition VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Column_In_List (p_Table_Name VARCHAR2, p_Owner VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2;

	FUNCTION Table_Column_In_List_Cursor (
    	p_Table_Name VARCHAR2 DEFAULT NULL,
    	p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Column_Name VARCHAR2 DEFAULT NULL
    )
	RETURN data_browser_conf.tab_table_column_in_list PIPELINED PARALLEL_ENABLE;

	FUNCTION Has_ChangeLog_History (p_Table_Name VARCHAR2) RETURN VARCHAR2;	-- YES, NO

	-- output of data_browser_select.Describe_Cols_cur and data_browser_select.Describe_Imp_Cols_cur
	TYPE rec_record_view IS RECORD (
		COLUMN_NAME 		VARCHAR2(128),
		TABLE_ALIAS 		VARCHAR2(10),
		COLUMN_ORDER		NUMBER(4),
		COLUMN_ID 			NUMBER(4),
		POSITION			NUMBER(10),
		INPUT_ID			VARCHAR2(4),
		REPORT_COLUMN_ID	NUMBER(4),
		DATA_TYPE 			VARCHAR2(128),
		DATA_PRECISION		NUMBER(4),
		DATA_SCALE			NUMBER(4),
		DATA_DEFAULT		VARCHAR2(1024),
		CHAR_LENGTH			NUMBER,
		NULLABLE			VARCHAR2(1),
		IS_PRIMARY_KEY		VARCHAR2(1),
		IS_SEARCH_KEY		VARCHAR2(1),
		IS_FOREIGN_KEY		VARCHAR2(1),
		IS_DISP_KEY_COLUMN  VARCHAR2(1),
		CHECK_UNIQUE		VARCHAR2(1),		-- Check Column_Data is Unique for base table columns / Lookup Unique for foreign key references columns
		REQUIRED 			VARCHAR2(1),
		HAS_HELP_TEXT		VARCHAR2(1),
		HAS_DEFAULT			VARCHAR2(1),
		IS_BLOB				VARCHAR2(1),
		IS_PASSWORD			VARCHAR2(1),
		IS_AUDIT_COLUMN		VARCHAR2(1),
		IS_OBFUSCATED		VARCHAR2(1),
		IS_UPPER_NAME		VARCHAR2(1),
		IS_NUMBER_YES_NO_COLUMN VARCHAR2(1),
		IS_CHAR_YES_NO_COLUMN VARCHAR2(1),
		YES_NO_COLUMN_TYPE	VARCHAR2(10),
		IS_SIMPLE_IN_LIST	VARCHAR2(1),
		STATIC_LOV_EXPR		VARCHAR2(1024), 
		HAS_AUTOMATIC_CHECK	VARCHAR2(1),
		HAS_RANGE_CHECK		VARCHAR2(1),
		IS_REFERENCE 		VARCHAR2(1),		-- Y,N,C 
		IS_SEARCHABLE_REF	VARCHAR2(1),
		IS_SUMMAND			VARCHAR2(1),
		IS_VIRTUAL_COLUMN   VARCHAR2(1),
		IS_DATETIME			VARCHAR2(1),
		FORMAT_MASK 		VARCHAR2(1024),
		LOV_QUERY			VARCHAR2(32767),
		COLUMN_ALIGN 		VARCHAR2(10),
		COLUMN_HEADER 		VARCHAR2(128),
		COLUMN_EXPR 		VARCHAR2(32767),
		COLUMN_EXPR_TYPE 	VARCHAR2(128),		-- APEX_ITEM type
		FIELD_LENGTH 		NUMBER,
		DISPLAY_IN_REPORT	VARCHAR2(1),
		COLUMN_DATA 		t_col_value,
		R_TABLE_NAME		VARCHAR2(128),
		R_VIEW_NAME			VARCHAR2(128),
		R_COLUMN_NAME		VARCHAR2(128),
		REF_TABLE_NAME		VARCHAR2(128),
		REF_VIEW_NAME		VARCHAR2(128),
		REF_COLUMN_NAME		VARCHAR2(128),
		COMMENTS			VARCHAR2(4000)
	);
	-- output of data_browser_utl.Get_View_Column_Cursor
	TYPE tab_record_view IS TABLE OF rec_record_view;

	TYPE rec_3col_values IS RECORD (
		COLUMN_HEADER1 VARCHAR2(512),
		COLUMN_DATA1 t_col_html,
		COLUMN_HELP1 VARCHAR2(4000),
		COLUMN_HEADER2 VARCHAR2(512),
		COLUMN_DATA2 t_col_html,
		COLUMN_HELP2 VARCHAR2(4000),
		COLUMN_HEADER3 VARCHAR2(512),
		COLUMN_DATA3 t_col_html,
		COLUMN_HELP3 VARCHAR2(4000)
	);
	-- output of data_browser_utl.Get_Record_View_Cursor
	TYPE tab_3col_values IS TABLE OF rec_3col_values;

	TYPE rec_foreign_key_value IS RECORD (
		FIELD_NAME 			VARCHAR2(128),
		FIELD_VALUE 		T_COL_VALUE,
		COLUMN_NAME 		VARCHAR2(128),
		COLUMN_DATA 		T_COL_VALUE,
		R_TABLE_NAME 		VARCHAR2(128),
		R_COLUMN_NAME 		VARCHAR2(128),
		R_UNIQUE_KEY_COLS 	VARCHAR2(128),
		CONSTRAINT_NAME 	VARCHAR2(128),
		ROW_COUNT 			NUMBER,
		POSITION 			NUMBER(4,0)
	);

	-- output of data_browser_utl.foreign_key_cursor, data_browser_utl.detail_key_cursor
	TYPE tab_foreign_key_value IS TABLE OF rec_foreign_key_value;

	TYPE rec_apex_links_list IS RECORD (
		THE_LEVEL 			NUMBER(4,0),
		LABEL 				VARCHAR2(2048),
		TARGET 				VARCHAR2(1024),
		IS_CURRENT_LIST_ENTRY VARCHAR2(10),
		IMAGE 				VARCHAR2(128),
		POSITION 			NUMBER(4,0),
		ATTRIBUTE1			VARCHAR2(128)
	);

	-- output of data_browser_utl.parents_list_cursor
	TYPE tab_apex_links_list IS TABLE OF rec_apex_links_list;

	TYPE rec_record_edit IS RECORD (
		COLUMN_NAME 		VARCHAR2(128),
		TABLE_ALIAS 		VARCHAR2(10),
		COLUMN_ID 			NUMBER(4),
		POSITION			NUMBER(10),
		INPUT_ID			VARCHAR2(4),
		REPORT_COLUMN_ID	NUMBER(4),
		DATA_TYPE 			VARCHAR2(128),
		DATA_PRECISION		NUMBER(4),
		DATA_SCALE			NUMBER,
		CHAR_LENGTH			NUMBER,
		NULLABLE			VARCHAR2(1),
		IS_PRIMARY_KEY		VARCHAR2(1),
		IS_SEARCH_KEY		VARCHAR2(1),
		IS_FOREIGN_KEY		VARCHAR2(1),
		IS_DISP_KEY_COLUMN  VARCHAR2(1),
		REQUIRED 			VARCHAR2(1),
		HAS_HELP_TEXT		VARCHAR2(1),
		HAS_DEFAULT			VARCHAR2(1),
		IS_BLOB				VARCHAR2(1),
		IS_PASSWORD			VARCHAR2(1),
		IS_AUDIT_COLUMN		VARCHAR2(1),
		IS_OBFUSCATED		VARCHAR2(1),
		IS_UPPER_NAME		VARCHAR2(1),
		IS_NUMBER_YES_NO_COLUMN VARCHAR2(1),
		IS_CHAR_YES_NO_COLUMN VARCHAR2(1),
		IS_REFERENCE 		VARCHAR2(1),		-- Y,N,C 
		IS_SEARCHABLE_REF	VARCHAR2(1),
		IS_SUMMAND			VARCHAR2(1),
		IS_VIRTUAL_COLUMN   VARCHAR2(1),
		IS_DATETIME			VARCHAR2(1),
		CHECK_UNIQUE		VARCHAR2(1),		-- Check Column_Data is Unique for base table columns / Lookup Unique for foreign key references columns
		FORMAT_MASK 		VARCHAR2(128),
		LOV_QUERY			VARCHAR2(32767),
		DATA_DEFAULT 		VARCHAR2(1024),		-- Default expression for empty columns on insert of new rows
		COLUMN_ALIGN 		VARCHAR2(10),
		COLUMN_HEADER 		VARCHAR2(128),
		COLUMN_EXPR 		VARCHAR2(32767),
		COLUMN_EXPR_TYPE 	VARCHAR2(128),		-- APEX_ITEM type
		APEX_ITEM_EXPR		VARCHAR2(32767),		-- APEX_ITEM expression
		APEX_ITEM_IDX		NUMBER, 			-- APEX_ITEM index
		APEX_ITEM_REF 		VARCHAR2(128),		-- APEX_ITEM reference (apex_application.g_fXX)
		ROW_FACTOR			NUMBER, 			-- APEX_ITEM row index factor
		ROW_OFFSET			NUMBER,				-- Usage:  ROW_FACTOR * (ROWNUM - 1) + ROW_OFFSET
		APEX_ITEM_CNT		NUMBER,
		FIELD_LENGTH 		NUMBER,
		DISPLAY_IN_REPORT	VARCHAR2(1),
		COLUMN_DATA 		t_col_html,
		R_TABLE_NAME		VARCHAR2(128),
		R_VIEW_NAME			VARCHAR2(128),
		R_COLUMN_NAME		VARCHAR2(128),
		REF_TABLE_NAME		VARCHAR2(128),
		REF_VIEW_NAME		VARCHAR2(128),
		REF_COLUMN_NAME		VARCHAR2(128),
		COMMENTS			VARCHAR2(4000)
	);
	TYPE tab_record_edit IS TABLE OF rec_record_edit;

END data_browser_conf;
/

CREATE OR REPLACE PACKAGE BODY data_browser_conf
IS
	g_Configuration_ID			NUMBER			:= 1;
	g_Configuration_Name       	VARCHAR2(128) 	:= 'Schema & Data Browser'; -- Configuration name of this setting. The name is displayed as the application title.
	g_Schema_Icon				VARCHAR2(2000)	:= 'fa-pyramid-chart';
	g_Description				VARCHAR2(2000);
	g_Edit_Enabled_Query 		VARCHAR2(2000) 	:= 		-- Authorization Scheme to enable editing of table data. Exists-Subquery that returns rows when the login user is permitted.
	'select 1 from V_CONTEXT_USERS ' || chr(10) ||
	'where upper_login_name = sys_context(''APEX$SESSION'',''APP_USER'') ' || chr(10) ||
	'and user_level <= 4';
	g_Data_Deduction_Query 		VARCHAR2(2000) 	:= 		-- Authorization Scheme to enable data deduction of table data. Exists-Subquery that returns rows when the login user is included.
	'select 1 from V_CONTEXT_USERS ' || chr(10) ||
	'where upper_login_name = sys_context(''APEX$SESSION'',''APP_USER'') ' || chr(10) ||
	'and user_level >= 5';
	g_User_Is_Data_Deducted		VARCHAR2(10)    := NULL;
	g_Reports_Application_ID 	NUMBER;						-- Link to Reports application with custom Reports for this Database Schema
	g_Reports_App_Page_ID		NUMBER;
	g_Client_Application_ID		NUMBER;
	g_Client_App_Page_ID		NUMBER;
$IF data_browser_specs.g_use_custom_ctx $THEN
	c_Custom_Edit_Enabled_Query CONSTANT VARCHAR2(2000) :=
	'select 1 from V_CONTEXT_USERS ' || chr(10) ||
	'where upper_login_name = sys_context(''APEX$SESSION'',''APP_USER'') ' || chr(10) ||
	'and user_level <= 4';
	c_Custom_Admin_Enabled_Query CONSTANT VARCHAR2(2000) :=	-- currently not used
	'select 1 from V_CONTEXT_USERS ' || chr(10) ||
	'where upper_login_name = sys_context(''APEX$SESSION'',''APP_USER'') ' || chr(10) ||
	'and user_level <= 2';
$ELSE
	c_Custom_Edit_Enabled_Query CONSTANT VARCHAR2(2000) :=
	'select 1' || chr(10) ||
	'from APEX_WORKSPACE_APEX_USERS U, APEX_APPLICATIONS A' || chr(10) ||
	'where U.WORKSPACE_NAME = A.WORKSPACE' || chr(10) ||
	'and U.IS_APPLICATION_DEVELOPER = ''Yes''' || chr(10) ||
	'and A.APPLICATION_ID = NV(''APP_ID'')' || chr(10) ||
	'and U.USER_NAME = SYS_CONTEXT(''APEX$SESSION'',''APP_USER'')';
	c_Custom_Admin_Enabled_Query CONSTANT VARCHAR2(2000) :=	-- currently not used
	'select 1' || chr(10) ||
	'from APEX_WORKSPACE_APEX_USERS U, APEX_APPLICATIONS A' || chr(10) ||
	'where U.WORKSPACE_NAME = A.WORKSPACE' || chr(10) ||
	'and U.IS_ADMIN = ''Yes''' || chr(10) ||
	'and A.APPLICATION_ID = NV(''APP_ID'')' || chr(10) ||
	'and U.USER_NAME = SYS_CONTEXT(''APEX$SESSION'',''APP_USER'')';
$END
	c_Apex_Developer_Enabled_Query	CONSTANT VARCHAR2(2000) 	:=			-- Authorization Scheme to enable assess to developer information functions. Exists-Subquery that returns rows when the login user is permitted.
	'select 1' || chr(10) ||
	'from APEX_WORKSPACE_APEX_USERS U, APEX_APPLICATIONS A' || chr(10) ||
	'where U.WORKSPACE_NAME = A.WORKSPACE' || chr(10) ||
	'and U.IS_APPLICATION_DEVELOPER = ''Yes''' || chr(10) ||
	'and A.APPLICATION_ID = NV(''APP_ID'')' || chr(10) ||
	'and U.USER_NAME = SYS_CONTEXT(''APEX$SESSION'',''APP_USER'')';
	c_Apex_Admin_Enabled_Query 	CONSTANT VARCHAR2(2000) 	:=			-- Authorization Scheme to enable assess to user administration tables. Exists-Subquery that returns rows when the login user is permitted.
	'select 1' || chr(10) ||
	'from APEX_WORKSPACE_APEX_USERS U, APEX_APPLICATIONS A' || chr(10) ||
	'where U.WORKSPACE_NAME = A.WORKSPACE' || chr(10) ||
	'and U.IS_ADMIN = ''Yes''' || chr(10) ||
	'and A.APPLICATION_ID = NV(''APP_ID'')' || chr(10) ||
	'and U.USER_NAME = SYS_CONTEXT(''APEX$SESSION'',''APP_USER'')';

	g_Developer_Enabled_Query	VARCHAR2(2000) 	:= c_Apex_Developer_Enabled_Query;	-- Authorization Scheme to enable assess to developer information functions. Exists-Subquery that returns rows when the login user is permitted.
	g_Admin_Enabled_Query 		VARCHAR2(2000) 	:= c_Apex_Admin_Enabled_Query;		-- Authorization Scheme to enable assess to user administration tables. Exists-Subquery that returns rows when the login user is permitted.
	g_Admin_Enabled				VARCHAR2(5)		:= NULL;
	-------------------------------------------
	g_Yes_No_Char_Static_LOV	VARCHAR2(64)  	:= 'Yes;Y,No;N'; -- static list of character values for Yes/No columns
	g_Yes_No_Number_Static_LOV	VARCHAR2(64)  	:= 'Yes;1,No;0'; -- static list of number values for Yes/No columns
	g_Detect_Yes_No_Static_LOV  VARCHAR2(5)  	:= 'YES';		 -- Detect Yes/No columns and display as static list of values

    g_Export_NumChars       	VARCHAR2(64)    := ',.';		-- the decimal character and group separator for number formating
    g_Export_Currency			VARCHAR2(64)    := SYS_CONTEXT ('USERENV','NLS_CURRENCY');
    g_Integer_Goup_Separator	VARCHAR2(5)  	:= 'YES';		-- use group separator for large Integer numbers
    g_Decimal_Goup_Separator	VARCHAR2(5)  	:= 'YES';		-- use group separator for large decimal numbers
    g_Default_Currency_Precision CONSTANT PLS_INTEGER := 16;	-- Default Data Precision for Currency columns with unknown precision
    g_Default_Currency_Scale	CONSTANT PLS_INTEGER := 2;		-- Default Data Scale for Currency columns with unknown scale
    g_Export_Float_Format       VARCHAR2(64)    := 'TM9';
    g_Export_Date_Format    	VARCHAR2(64)    := 'DD.MM.YYYY';
    g_Export_DateTime_Format	VARCHAR2(64)    := 'DD.MM.YYYY HH24:MI:SS';
    g_Export_Timestamp_Format   VARCHAR2(64)    := 'YYYY/MM/DD HH24.MI.SS,FF';
    g_Use_App_Date_Time_Format 	VARCHAR2(5)		:= 'NO';	-- Use APP_DATE_TIME_FORMAT, NLS_DATE_FORMAT and  NLS_TIMESTAMP_FORMAT for showing or submitting any page in the application.
    g_Rec_Desc_Delimiter		VARCHAR2(64)    := chr(32)||chr(14844066)||chr(32); -- (bullet) Record description field delimiter
    g_Rec_Desc_Group_Delimiter  VARCHAR2(64)    := chr(32)||chr(14844051)||chr(32); -- (ndash) Record description group delimiter
	g_Generate_Compact_Queries	VARCHAR2(5)		:= 'NO';	-- Generate Compact Queries to avoid overflow errors
	g_TextArea_Min_Length  		PLS_INTEGER 	:= 300;		-- Minimum character length of column before a textarea is used.
	g_TextArea_Max_Length  		CONSTANT PLS_INTEGER := 1300;	-- Maximum character length of column for textarea. 2000 is the technical limit
    g_Export_Text_Limit         PLS_INTEGER     := 30000;	-- Limit for text columns in export reports
    g_Minimum_Field_Width		PLS_INTEGER 	:= 8;		-- Minimum input field width
    g_Maximum_Field_Width		PLS_INTEGER 	:= 50;		-- Maximum input field width
    g_Stretch_Form_Fields		VARCHAR2(5)  	:= 'YES';	-- Stretch input fields to maximum width
    g_Select_List_Rows_Limit	PLS_INTEGER 	:= 30;		-- Maximum rows limit for select list items. When the limit is exceeded a popup lov item is used.
    g_Detect_Column_Prefix		VARCHAR2(5)  	:= 'YES';	-- Detect and remove column prefix in column headers
	g_Translate_Umlaute			VARCHAR2(5)  	:= 'NO';	-- Translate Umlaute for report names and column headers
	-------------------------------------------
	g_Show_Tree_Num_Rows		VARCHAR2(5)  	:= 'YES';	-- Show Tree Row-Nums in the Table Relations Tree 
	g_Update_Tree_Num_Rows		VARCHAR2(5)  	:= 'YES';	-- Update Tree Row-Nums in the Table Relations Tree with background job
	g_Max_Relations_Levels		PLS_INTEGER 	:= 4;		-- Maximum Levels in the Tables Relations Tree 
	-------------------------------------------
    g_Key_Column_Ext			VARCHAR2(2000)    := '_ID,_SID$,_CONTENT';   -- List of Extension of column names. (This extension will be removed from displayed column names)
    g_Base_Table_Prefix			VARCHAR2(2000)    := '';		-- Prefix for base table names. (This prefix will be removed from displayed table names)
    g_Base_Table_Ext  			VARCHAR2(2000)    := '_BT';   -- Extension for base table names. (This extension will be removed from displayed table names)
    g_Base_View_Prefix 			VARCHAR2(2000)    := '';      -- Prefix for base view names
    g_Base_View_Ext  			VARCHAR2(2000)    := '';      -- Extension for base view names
    g_History_View_Ext       	VARCHAR2(2000)    := '_CL';   -- Extension for history views with AS OF TIMESTAMP filter

    g_Compare_Case_Insensitive 	VARCHAR2(5)  	:= 'NO';   	-- compare Case insensitive for loopup of foreign key values
    g_Search_Keys_Unique		VARCHAR2(5)  	:= 'YES';   -- Require search with unique keys for loopup of foreign key values
    g_Insert_Foreign_Keys		VARCHAR2(5)  	:= 'YES';	-- Enable insert of new foreign keys in import views
	g_Include_Query_Schema		VARCHAR2(5)  	:= 'NO';	-- Include Query Schema in from clause to enable usage in  create_collection_from_query_b
	g_Apex_Version				VARCHAR2(64)	:= 'APEX_050000';
	g_Email_From_Address		VARCHAR2(128)    := '';      -- Email From Address for emails from the application. Used to Invite new users via E-mail and Request a new password via E-mail.
	-------------------------------------------
	g_Errors_Listed_Limit		PLS_INTEGER := 100;			-- Limit for the number of rows in the data validation error list.
	g_Edit_Rows_Limit			PLS_INTEGER := 500;			-- Limit for the number of rows for a details-report in edit mode.
	g_Automatic_Sorting_Limit	PLS_INTEGER := 10000;		-- Limit for Automatic Sorting. When the base table row count is greater than the limit Automatic Sorting is disabled.
	g_Automatic_Search_Limit	PLS_INTEGER := 10000;		-- Limit for Automatic Search. When the base table row count is greater than the limit Automatic Search is disabled.
	g_Navigation_Link_Limit		PLS_INTEGER := 10;			-- Limit for the count of Navigation Links in Navigation View report columns.
	-------------------------------------------

	g_DateTime_Columns_Array apex_t_varchar2 := apex_t_varchar2();
	g_ReadOnly_Tables_Array 	apex_t_varchar2 := apex_t_varchar2();
	g_ReadOnly_Columns_Array 	apex_t_varchar2 := apex_t_varchar2();
	g_Base_Table_Prefix_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Base_Table_Ext_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Key_Column_Ext_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Key_Column_Ext_Pat_Array  apex_t_varchar2 := apex_t_varchar2();
	g_Edit_Tables_Array 		apex_t_varchar2 := apex_t_varchar2();
	g_Admin_Tables_Array 		apex_t_varchar2 := apex_t_varchar2();
	g_Data_Deduction_Array 		apex_t_varchar2 := apex_t_varchar2();
	g_Yes_No_Columns_Array 		apex_t_varchar2 := apex_t_varchar2();	

	g_Encrypt_Function 			CONSTANT VARCHAR2(128) 	:= 'data_browser_auth.Hex_Crypt';
	g_Hash_Function 			CONSTANT VARCHAR2(128) 	:= 'data_browser_auth.Hex_Hash';
	g_Sys_Guid_Function 		CONSTANT VARCHAR2(100) := 'TO_NUMBER(SYS_GUID(),''XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'')';
	g_MD5_Column_Name 			CONSTANT VARCHAR2(64) := 'ROW_CHECKSUM_MD5$';
	g_Search_Column_Index 		CONSTANT PLS_INTEGER := 40;
	g_Search_Operator_Index 	CONSTANT PLS_INTEGER := 41;
	g_Search_Value_Index 		CONSTANT PLS_INTEGER := 42;
	g_Search_LOV_Index 			CONSTANT PLS_INTEGER := 43;
	g_Search_Active_Index 		CONSTANT PLS_INTEGER := 44;
	g_Search_Seq_ID_Index 		CONSTANT PLS_INTEGER := 45;
	g_Link_ID_Index				CONSTANT PLS_INTEGER := 46;
	g_Row_Selector_Index		CONSTANT PLS_INTEGER := 47;
	g_Joins_Alias_Index			CONSTANT PLS_INTEGER := 48;
	g_Joins_Option_Index		CONSTANT PLS_INTEGER := 49;
	g_MD5_Column_Index			CONSTANT PLS_INTEGER := 50;
	g_Apex_Item_Limit			CONSTANT PLS_INTEGER := 39;		-- Total limit is 50, but leave space for service items
	g_Collection_Columns_Limit  CONSTANT PLS_INTEGER := 50;		-- Count of character columns in APEX_COLLECTIONS
	g_Edit_Columns_Limit  		CONSTANT PLS_INTEGER := 60;		-- queries get too larger.
	g_Select_Columns_Limit  	CONSTANT PLS_INTEGER := 100;
	g_New_Rows_Default			CONSTANT PLS_INTEGER := 5;
	g_Clob_Collection			CONSTANT VARCHAR2(50) := 'CLOB_CONTENT';
	g_Import_Data_Collection	CONSTANT VARCHAR2(50) := 'IMPORTED_DATA';
	g_Import_Desc_Collection	CONSTANT VARCHAR2(50) := 'IMPORTED_DESC';
	g_Import_Error_Collection	CONSTANT VARCHAR2(50) := 'IMPORTED_ERRORS';
	g_Validation_Collection		CONSTANT VARCHAR2(50) := 'VALIDATON_ERRORS';
	g_Lookup_Collection			CONSTANT VARCHAR2(50) := 'KEY_LOOKUP_ERRORS';
	g_Constraints_Collection 	CONSTANT VARCHAR2(50) := 'CONSTRAINT_CHECKS';
	g_Filter_Cond_Collection	CONSTANT VARCHAR2(50) := 'FILTER_CONDITIONS';
    g_ChangeLogTextLimit        CONSTANT INTEGER        := 400;
	g_Compare_Return_Style  	CONSTANT VARCHAR2(300)  := 'background-color:CadetBlue;box-shadow: 0px 0px 10px 6px CadetBlue;';
	g_Compare_Return_Style2  	CONSTANT VARCHAR2(300)  := 'background-color:MediumSeaGreen;box-shadow: 0px 0px 10px 6px MediumSeaGreen;';
	g_Compare_Return_Style3  	CONSTANT VARCHAR2(300)  := 'background-color:Coral;box-shadow: 0px 0px 10px 6px Coral;';
	g_Errors_Return_Style 		CONSTANT VARCHAR2(300)  := 'background-color:Moccasin;box-shadow: 0px 0px 10px 6px Moccasin;';
	g_Get_ChangLog_Query_Call 	VARCHAR2(2000)  := 'custom_changelog_gen.ChangeLog_Pivot_Query(p_Table_Name => :a, p_Convert_Data_Types => :b, p_Compact_Queries => :c)';
	g_ChangLog_Enabled_Call 	VARCHAR2(2000) 	:= 'custom_changelog_gen.Changelog_Is_Active(p_Table_Name => :a)';
	g_Access_Multiple_Workspaces  VARCHAR2(30) := 'NO';

	g_NLS_Date_Format			VARCHAR2(64)    := '';
	g_NLS_NumChars				VARCHAR2(64)    := '';
	g_NLS_Currency				VARCHAR2(64)    := '';
	g_App_Date_Time_Format		VARCHAR2(64)    := '';		-- dynamic loaded system parameter
	g_NLS_Timestamp_Format		VARCHAR2(64)    := '';		-- dynamic loaded system parameter
	g_fetch_limit				CONSTANT INTEGER:= 200;
	PROCEDURE Save_Config_Defaults
    IS PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
		UPDATE DATA_BROWSER_CONFIG
		SET (Configuration_Name, Schema_Icon, Description, Edit_Enabled_Query, Data_Deduction_Query, 
			Reports_Application_ID, Reports_App_Page_ID, Client_Application_ID, Client_App_Page_ID,
			Developer_Enabled_Query, Admin_Enabled_Query, 
			App_Version_Number, App_Licence_Number, App_Licence_Owner, App_Installation_Code,
			Yes_No_Char_Static_LOV, Yes_No_Number_Static_LOV,
			Detect_Yes_No_Static_LOV, Export_NumChars, Integer_Goup_Separator, Decimal_Goup_Separator,
			Export_Float_Format, Export_Date_Format, Export_Timestamp_Format, Use_App_Date_Time_Format,
			Rec_Desc_Delimiter, Rec_Desc_Group_Delimiter, TextArea_Min_Length, Export_Text_Limit, Minimum_Field_Width, Maximum_Field_Width,
			Stretch_Form_Fields, Select_List_Rows_Limit, Detect_Column_Prefix, Translate_Umlaute, Key_Column_Ext, 
			Show_Tree_Num_Rows, Update_Tree_Num_Rows, Max_Relations_Levels, Base_Table_Prefix, Base_Table_Ext,
			Base_View_Prefix, Base_View_Ext, History_View_Ext, Compare_Case_Insensitive, Search_Keys_Unique, Insert_Foreign_Keys,
			Email_From_Address, Errors_Listed_Limit, Edit_Rows_Limit, Automatic_Sorting_Limit, Automatic_Search_Limit, Navigation_Link_Limit
        ) = (
        	SELECT g_Configuration_Name, g_Schema_Icon, g_Description, c_Custom_Edit_Enabled_Query, g_Data_Deduction_Query, 
        		g_Reports_Application_ID, g_Reports_App_Page_ID, g_Client_Application_ID, g_Client_App_Page_ID,
        		g_Developer_Enabled_Query, g_Admin_Enabled_Query,
        		g_App_Version_Number, g_App_Licence_Number, g_App_Licence_Owner, g_App_Installation_Code,
				g_Yes_No_Char_Static_LOV, g_Yes_No_Number_Static_LOV,
				g_Detect_Yes_No_Static_LOV, g_Export_NumChars, g_Integer_Goup_Separator, g_Decimal_Goup_Separator,
				g_Export_Float_Format, g_Export_Date_Format, g_Export_Timestamp_Format, g_Use_App_Date_Time_Format,
				g_Rec_Desc_Delimiter, g_Rec_Desc_Group_Delimiter, g_TextArea_Min_Length, g_Export_Text_Limit, g_Minimum_Field_Width, g_Maximum_Field_Width,
				g_Stretch_Form_Fields, g_Select_List_Rows_Limit, g_Detect_Column_Prefix, g_Translate_Umlaute, g_Key_Column_Ext,
				g_Show_Tree_Num_Rows, g_Update_Tree_Num_Rows, g_Max_Relations_Levels, g_Base_Table_Prefix, g_Base_Table_Ext,
				g_Base_View_Prefix, g_Base_View_Ext, g_History_View_Ext, g_Compare_Case_Insensitive, g_Search_Keys_Unique, g_Insert_Foreign_Keys,
				g_Email_From_Address, g_Errors_Listed_Limit, g_Edit_Rows_Limit, g_Automatic_Sorting_Limit, g_Automatic_Search_Limit, g_Navigation_Link_Limit
        	FROM DUAL
        ) WHERE ID = g_Configuration_ID;
        if SQL%ROWCOUNT = 0 then
        	INSERT INTO DATA_BROWSER_CONFIG(ID,
        		Configuration_Name, Schema_Icon, Description, Edit_Enabled_Query, Data_Deduction_Query, 
        		Reports_Application_ID, Reports_App_Page_ID, Client_Application_ID, Client_App_Page_ID,
        		Developer_Enabled_Query, Admin_Enabled_Query, 
        		App_Version_Number, App_Licence_Number, App_Licence_Owner, App_Installation_Code,
	       		Yes_No_Char_Static_LOV, Yes_No_Number_Static_LOV,
				Detect_Yes_No_Static_LOV, Export_NumChars, Integer_Goup_Separator, Decimal_Goup_Separator,
				Export_Float_Format, Export_Date_Format, Export_Timestamp_Format, Use_App_Date_Time_Format,
				Rec_Desc_Delimiter, Rec_Desc_Group_Delimiter, TextArea_Min_Length, Export_Text_Limit, Minimum_Field_Width, Maximum_Field_Width,
				Stretch_Form_Fields, Select_List_Rows_Limit, Detect_Column_Prefix, Translate_Umlaute, Key_Column_Ext, 
				Show_Tree_Num_Rows, Update_Tree_Num_Rows, Max_Relations_Levels, Base_Table_Prefix, Base_Table_Ext,
				Base_View_Prefix, Base_View_Ext, History_View_Ext, Compare_Case_Insensitive, Search_Keys_Unique, Insert_Foreign_Keys,
				Email_From_Address, Errors_Listed_Limit, Edit_Rows_Limit, Automatic_Sorting_Limit, Automatic_Search_Limit, Navigation_Link_Limit
			)
			VALUES (g_Configuration_ID,
				g_Configuration_Name, g_Schema_Icon, g_Description, c_Custom_Edit_Enabled_Query, g_Data_Deduction_Query, 
				g_Reports_Application_ID, g_Reports_App_Page_ID, g_Client_Application_ID, g_Client_App_Page_ID,
				g_Developer_Enabled_Query, g_Admin_Enabled_Query,  
        		g_App_Version_Number, g_App_Licence_Number, g_App_Licence_Owner, g_App_Installation_Code,
				g_Yes_No_Char_Static_LOV, g_Yes_No_Number_Static_LOV,
				g_Detect_Yes_No_Static_LOV, g_Export_NumChars, g_Integer_Goup_Separator, g_Decimal_Goup_Separator,
				g_Export_Float_Format, g_Export_Date_Format, g_Export_Timestamp_Format, g_Use_App_Date_Time_Format,
				g_Rec_Desc_Delimiter, g_Rec_Desc_Group_Delimiter, g_TextArea_Min_Length, g_Export_Text_Limit, g_Minimum_Field_Width, g_Maximum_Field_Width,
				g_Stretch_Form_Fields, g_Select_List_Rows_Limit, g_Detect_Column_Prefix, g_Translate_Umlaute, g_Key_Column_Ext, 
				g_Show_Tree_Num_Rows, g_Update_Tree_Num_Rows, g_Max_Relations_Levels, g_Base_Table_Prefix, g_Base_Table_Ext,
				g_Base_View_Prefix, g_Base_View_Ext, g_History_View_Ext, g_Compare_Case_Insensitive, g_Search_Keys_Unique, g_Insert_Foreign_Keys,
				g_Email_From_Address, g_Errors_Listed_Limit, g_Edit_Rows_Limit, g_Automatic_Sorting_Limit, g_Automatic_Search_Limit, g_Navigation_Link_Limit
			);
        end if;
        COMMIT;
    END Save_Config_Defaults;


	PROCEDURE Load_Config
    IS 
    	v_DateTime_Columns_Pattern 	VARCHAR2(2000);	 -- List of column name pattern for date columns with DateTime_Format.
		v_Edit_Tables_Pattern 		VARCHAR2(2000); -- List of table name pattern for tables with editing of table data enabled.
		v_Admin_Tables_Pattern 		VARCHAR2(2000); -- List of table name pattern for user administration tables.
		v_ReadOnly_Tables_Pattern 	VARCHAR2(2000); -- List of table name pattern for tables with editing of table data disabled.
		v_ReadOnly_Columns_Pattern 	VARCHAR2(2000); -- List of read only column name pattern
		v_Yes_No_Columns_Pattern 	VARCHAR2(2000);	-- List of column name pattern for single char encoded Yes/No columns.
		v_Data_Deduction_Pattern  	VARCHAR2(2000);  -- List of column name pattern for columns that are hidden from users with data deduction access.
    BEGIN
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info('data_browser_conf.Load_Config starting');
		$END
        SELECT
        	Configuration_Name, Schema_Icon, Description, Edit_Enabled_Query, Data_Deduction_Query, 
        	Reports_Application_ID, Reports_App_Page_ID, Client_Application_ID, Client_App_Page_ID,
        	Developer_Enabled_Query, Admin_Enabled_Query, 
        	App_Version_Number, App_Licence_Number, App_Licence_Owner, App_Installation_Code,
        	Edit_Tables_Pattern, Admin_Tables_Pattern, ReadOnly_Tables_Pattern, ReadOnly_Columns_Pattern, 
	       	Yes_No_Columns_Pattern, DateTime_Columns_Pattern, Data_Deduction_Pattern,
	       	Yes_No_Char_Static_LOV, Yes_No_Number_Static_LOV,
			Detect_Yes_No_Static_LOV, Export_NumChars, Integer_Goup_Separator, Decimal_Goup_Separator,
			Export_Float_Format, Export_Date_Format, Export_Timestamp_Format, Use_App_Date_Time_Format,
			Rec_Desc_Delimiter, Rec_Desc_Group_Delimiter, TextArea_Min_Length, Export_Text_Limit, Minimum_Field_Width, Maximum_Field_Width,
			Stretch_Form_Fields, Select_List_Rows_Limit, Detect_Column_Prefix, Translate_Umlaute, Key_Column_Ext, 
			Show_Tree_Num_Rows, Update_Tree_Num_Rows, Max_Relations_Levels, Base_Table_Prefix, Base_Table_Ext,
			Base_View_Prefix, Base_View_Ext, History_View_Ext, Compare_Case_Insensitive, Search_Keys_Unique, Insert_Foreign_Keys,
			Email_From_Address, Errors_Listed_Limit, Edit_Rows_Limit, Automatic_Sorting_Limit, Automatic_Search_Limit, Navigation_Link_Limit, 
			Created_At, Created_By
        INTO
        	g_Configuration_Name, g_Schema_Icon, g_Description, g_Edit_Enabled_Query, g_Data_Deduction_Query, 
        	g_Reports_Application_ID, g_Reports_App_Page_ID, g_Client_Application_ID, g_Client_App_Page_ID,
        	g_Developer_Enabled_Query, g_Admin_Enabled_Query, 
       		g_App_Version_Number, g_App_Licence_Number, g_App_Licence_Owner, g_App_Installation_Code,
        	v_Edit_Tables_Pattern, v_Admin_Tables_Pattern, v_ReadOnly_Tables_Pattern, v_ReadOnly_Columns_Pattern, 
        	v_Yes_No_Columns_Pattern, v_DateTime_Columns_Pattern, v_Data_Deduction_Pattern,
        	g_Yes_No_Char_Static_LOV, g_Yes_No_Number_Static_LOV,
			g_Detect_Yes_No_Static_LOV, g_Export_NumChars, g_Integer_Goup_Separator, g_Decimal_Goup_Separator,
			g_Export_Float_Format, g_Export_Date_Format, g_Export_Timestamp_Format, g_Use_App_Date_Time_Format,
			g_Rec_Desc_Delimiter, g_Rec_Desc_Group_Delimiter, g_TextArea_Min_Length, g_Export_Text_Limit, g_Minimum_Field_Width, g_Maximum_Field_Width,
			g_Stretch_Form_Fields, g_Select_List_Rows_Limit, g_Detect_Column_Prefix, g_Translate_Umlaute, g_Key_Column_Ext, 
			g_Show_Tree_Num_Rows, g_Update_Tree_Num_Rows, g_Max_Relations_Levels, g_Base_Table_Prefix, g_Base_Table_Ext,
			g_Base_View_Prefix, g_Base_View_Ext, g_History_View_Ext, g_Compare_Case_Insensitive, g_Search_Keys_Unique, g_Insert_Foreign_Keys,
			g_Email_From_Address, g_Errors_Listed_Limit, g_Edit_Rows_Limit, g_Automatic_Sorting_Limit, g_Automatic_Search_Limit, g_Navigation_Link_Limit, 
			g_App_Created_At, g_App_Created_By
        FROM DATA_BROWSER_CONFIG
        WHERE ID = g_Configuration_ID;
		g_Apex_Version := NULL;

		g_DateTime_Columns_Array := apex_string.split(REPLACE(v_DateTime_Columns_Pattern,'_','\_'), ',');
		g_ReadOnly_Tables_Array := apex_string.split(REPLACE(v_ReadOnly_Tables_Pattern,'_','\_'), ',');
		g_ReadOnly_Columns_Array := apex_string.split(REPLACE(v_ReadOnly_Columns_Pattern,'_','\_'), ',');
		g_Base_Table_Ext_Field_Array := apex_string.split(REPLACE(g_Base_Table_Ext, '$', '\$'), ',');
		g_Base_Table_Prefix_Field_Array := apex_string.split(REPLACE(g_Base_Table_Prefix, '$', '\$'), ',');
		g_Key_Column_Ext_Field_Array := apex_string.split(g_Key_Column_Ext, ',');
		g_Key_Column_Ext_Pat_Array := apex_string.split(g_Key_Column_Ext, ',');
		for c_idx IN 1..g_Key_Column_Ext_Pat_Array.count loop
			g_Key_Column_Ext_Pat_Array(c_idx) := '(.*)' || REPLACE(g_Key_Column_Ext_Pat_Array(c_idx), '$', '\$') || '(\d*)$'; -- remove ending _ID2
		end loop;
		g_Edit_Tables_Array := apex_string.split(REPLACE(v_Edit_Tables_Pattern,'_','\_'), ',');
		g_Admin_Tables_Array := apex_string.split(REPLACE(v_Admin_Tables_Pattern,'_','\_'), ',');
		g_Data_Deduction_Array := apex_string.split(REPLACE(v_Data_Deduction_Pattern,'_','\_'), ',');
		g_Yes_No_Columns_Array := apex_string.split(REPLACE(v_Yes_No_Columns_Pattern,'_','\_'), ',');

    	SELECT CASE WHEN EXISTS (
    		SELECT 1 FROM USER_NAMESPACES T 
    		WHERE T.WORKSPACE_NAME != SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
    	) THEN 'YES' ELSE 'NO' END Has_Multiple_Workspaces
		INTO g_Access_Multiple_Workspaces
    	FROM DUAL;

		$IF data_browser_conf.g_debug $THEN
			apex_debug.info('data_browser_conf.Load_Config done');
		$END
    EXCEPTION WHEN NO_DATA_FOUND THEN
    	NULL;
    END Load_Config;

    FUNCTION Has_Multiple_Workspaces RETURN VARCHAR2 -- YES/NO
    IS 
	PRAGMA UDF;    
    BEGIN
    	RETURN g_Access_Multiple_Workspaces;
    END;

	FUNCTION Enquote_Parameter ( p_Text VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT 1000 )
	RETURN VARCHAR2 DETERMINISTIC
	IS
		v_Quote CONSTANT VARCHAR2(1) := chr(39);
	BEGIN
		RETURN v_Quote || REPLACE(SUBSTR(p_Text, 1, p_value_max_length), v_Quote, v_Quote||v_Quote) || v_Quote ;
	END;
	-- build an expression that captures the parameters of an package procedure for logging.
	-- the procedure or function must be listed in the package header.
	-- when a procedure or function is overloaded then used the p_overload=>1 for the first and p_overload=>2 for the second variant.
	-- invoke with: EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter_Str USING OUT v_char_Result;
	-- the count of the arguments will be checked at runtime.
	FUNCTION Dyn_Log_Call_Parameter(
		p_Use_Apex_Debug BOOLEAN DEFAULT TRUE,
		p_level APEX_DEBUG.T_LOG_LEVEL DEFAULT APEX_DEBUG.C_LOG_LEVEL_INFO,
		p_value_max_length INTEGER DEFAULT 1000,
		p_overload INTEGER DEFAULT 0
	) RETURN VARCHAR2
	IS
		c_calling_subprog constant varchar2(128) := utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2)); -- alternative: OWA_UTIL.WHO_CALLED_ME
		c_newline VARCHAR2(10) := 'chr(10)'||chr(10);
		c_conop VARCHAR2(10) := ' || ';
		v_argument_name VARCHAR2(200);
		v_result_str VARCHAR2(32767);
		v_over  dbms_describe.number_table;
		v_posn  dbms_describe.number_table;
		v_levl  dbms_describe.number_table;
		v_arg_name dbms_describe.varchar2_table;
		v_dtyp  dbms_describe.number_table;
		v_defv  dbms_describe.number_table;
		v_inout dbms_describe.number_table;
		v_len   dbms_describe.number_table;
		v_prec  dbms_describe.number_table;
		v_scal  dbms_describe.number_table;
		v_n     dbms_describe.number_table;
		v_spare dbms_describe.number_table;
		v_idx	INTEGER := 0;
	BEGIN
		dbms_describe.describe_procedure(
			object_name => c_calling_subprog, 
			reserved1 => NULL, 
			reserved2 => NULL,
			overload => v_over, 
			position => v_posn, 
			level => v_levl, 
			argument_name => v_arg_name, 
			datatype => v_dtyp, 
			default_value => v_defv, 
			in_out => v_inout, 
			length => v_len, 
			precision => v_prec, 
			scale => v_scal, 
			radix => v_n, 
			spare => v_spare
		);
		loop 
			v_idx := v_idx + 1;
			exit when v_idx > v_arg_name.count;
			exit when length(v_result_str) > 32000;
			if v_posn(v_idx) != 0  -- Position 0 returns the values for the return type of a function. 
			and v_over(v_idx) = p_overload
			then
				v_argument_name := lower(substr(v_arg_name(v_idx), 1, 2)) || initcap(substr(v_arg_name(v_idx), 3));
				v_result_str := v_result_str 
				|| case when v_result_str IS NOT NULL
					then c_conop || dbms_assert.enquote_literal(', ') || c_conop || c_newline || c_conop 
				end
				|| dbms_assert.enquote_literal( v_argument_name || '=>') 
				|| c_conop
				|| case when v_dtyp(v_idx) IN (2,3) -- number types
					then ':' || v_argument_name
					else 'data_browser_conf.Enquote_Parameter(:' || v_argument_name || ', ' || p_value_max_length || ')'
				end;
			end if;
		end loop;
		if v_result_str IS NOT NULL then 
			v_result_str := dbms_assert.enquote_literal( initcap(c_calling_subprog) || '(') 
			|| c_conop || v_result_str || c_conop || dbms_assert.enquote_literal(')');
		else 
			v_result_str := dbms_assert.enquote_literal( initcap(c_calling_subprog));
		end if;
		if p_Use_Apex_Debug then 
			RETURN 'declare v_log VARCHAR2(32767); begin v_log := ' || v_result_str || '; '
			|| 'apex_debug.message(p_message=>v_log,p_max_length => 3500, p_level => ' || to_char(p_level) || ');'
			|| 'end;';
		else
			RETURN 'begin :x := ' || v_result_str || '; end;';
		end if;
	END Dyn_Log_Call_Parameter;
	
    FUNCTION Get_Apex_Version RETURN VARCHAR2 
    IS 
    BEGIN 
		if g_Apex_Version IS NULL then 
			select table_owner 
			INTO g_Apex_Version
			from all_synonyms 
			where synonym_name = 'APEX'
			and owner = 'PUBLIC';
		end if;
    	RETURN g_Apex_Version; 
    END;

	PROCEDURE Touch_Configuration
	IS 
	BEGIN 
		UPDATE DATA_BROWSER_CONFIG SET ROW_VERSION_NUMBER = ROW_VERSION_NUMBER + 1,
			Last_Modified_At = LOCALTIMESTAMP,
			Last_Modified_BY = NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) 
		WHERE ID = g_Configuration_ID;
		COMMIT;
	END;
	
	FUNCTION Get_App_Library_Version RETURN VARCHAR2 IS BEGIN RETURN g_App_Version_Number; END;
    
    PROCEDURE Set_App_Library_Version (
    	p_Application_ID NUMBER DEFAULT NV('APP_ID')
    )
    IS PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN 
    	SELECT VERSION  INTO g_App_Version_Number
  		FROM APEX_APPLICATIONS
  		WHERE APPLICATION_ID = p_Application_ID;
  		
    	UPDATE DATA_BROWSER_CONFIG SET APP_VERSION_NUMBER = g_App_Version_Number
		WHERE ID = g_Configuration_ID;
		COMMIT;
		DBMS_OUTPUT.PUT_LINE('-- Set library version for App-ID ' || p_Application_ID || ' to : ' || g_App_Version_Number);
	exception when NO_DATA_FOUND then
		NULL;
		ROLLBACK;
    END;

	FUNCTION Get_Data_Browser_Version_Number (
		p_Schema_Name VARCHAR2
	) RETURN VARCHAR2 
	IS
		v_App_Version_Number VARCHAR2(64);
		v_Query	VARCHAR2(1024);
		cv 		SYS_REFCURSOR;
	BEGIN
		v_Query := 'select APP_VERSION_NUMBER from '
		|| DBMS_ASSERT.ENQUOTE_NAME(p_Schema_Name)
		|| '.DATA_BROWSER_CONFIG where ID = 1';
		OPEN cv FOR v_Query;
		FETCH cv INTO v_App_Version_Number;
		CLOSE cv;
		
		return v_App_Version_Number;
	exception
	  when others then
		if SQLCODE IN (-904, -942) then
			RETURN NULL;
		end if;
		raise;
	END Get_Data_Browser_Version_Number;   
    
    FUNCTION Get_App_Licence_Number RETURN VARCHAR2 IS BEGIN RETURN g_App_Licence_Number; END;
    FUNCTION Get_App_Licence_Owner RETURN VARCHAR2 IS BEGIN RETURN g_App_Licence_Owner; END;
    FUNCTION Get_App_Installation_Code RETURN VARCHAR2 IS BEGIN RETURN g_App_Installation_Code; END;
	PROCEDURE Set_App_Installation_Code (p_Code IN VARCHAR2)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
	BEGIN 
		UPDATE DATA_BROWSER_CONFIG SET App_Installation_Code = p_Code
		WHERE ID = g_Configuration_ID;
		COMMIT;
		g_App_Installation_Code := p_Code;
	END;
	
    FUNCTION Get_Configuration_ID RETURN NUMBER IS BEGIN RETURN g_Configuration_ID; END;
    FUNCTION Get_Configuration_Name RETURN VARCHAR2 IS BEGIN RETURN g_Configuration_Name; END;
    FUNCTION Get_Email_From_Address RETURN VARCHAR2 IS BEGIN RETURN g_Email_From_Address; END;
    FUNCTION Get_Schema_Icon RETURN VARCHAR2 IS BEGIN RETURN g_Schema_Icon; END;
    FUNCTION Get_Reports_Application_ID RETURN NUMBER IS BEGIN RETURN g_Reports_Application_ID; END;
    FUNCTION Get_Reports_App_Page_ID RETURN NUMBER IS BEGIN RETURN g_Reports_App_Page_ID; END;
    FUNCTION Get_Client_Application_ID RETURN NUMBER IS BEGIN RETURN g_Client_Application_ID; END;
    FUNCTION Get_Client_App_Page_ID RETURN NUMBER IS BEGIN RETURN g_Client_App_Page_ID; END;

	FUNCTION Get_APEX_URL_Element (p_Text VARCHAR2, p_Element NUMBER) RETURN VARCHAR2
	IS 
	PRAGMA UDF;
		v_URL_Array apex_t_varchar2;
	BEGIN
		v_URL_Array := apex_string.split(p_Text, ':');
		if v_URL_Array.count >= p_Element then
			RETURN v_URL_Array(p_Element);
		else
			RETURN NULL;
		end if;
	END Get_APEX_URL_Element;

	FUNCTION Match_Pattern (p_Text VARCHAR2, p_Pattern VARCHAR2) RETURN BOOLEAN DETERMINISTIC
	IS 
		v_Pattern_Array apex_t_varchar2;
	BEGIN
		v_Pattern_Array := apex_string.split(p_Pattern, ',');
		for c_idx IN 1..v_Pattern_Array.count loop
			if p_Text LIKE v_Pattern_Array(c_idx) ESCAPE '\' then
				RETURN TRUE;
			end if;
		end loop;
		RETURN FALSE;
	END Match_Pattern;

	FUNCTION Normalize_Column_Pattern (p_Pattern VARCHAR2) RETURN VARCHAR2 
	IS 
	BEGIN
		RETURN UPPER(REPLACE(REPLACE(p_Pattern,'_','\_'), ' '));
	END;

	FUNCTION Match_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern VARCHAR2) 
	RETURN VARCHAR2 DETERMINISTIC -- YES / NO
	IS 
	PRAGMA UDF;
		v_Pattern_Array apex_t_varchar2;
	BEGIN
		v_Pattern_Array := apex_string.split(p_Pattern, ',');
		for c_idx IN 1..v_Pattern_Array.count loop
			if p_Column_Name LIKE v_Pattern_Array(c_idx) ESCAPE '\' then
				RETURN 'YES';
			end if;
		end loop;
		RETURN 'NO';
	END Match_Column_Pattern;

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
	END Match_Column_Pattern;

	FUNCTION Matching_Column_Pattern (p_Column_Name VARCHAR2, p_Pattern VARCHAR2) 
	RETURN VARCHAR2 
	IS 
	PRAGMA UDF;
		v_Pattern_Array apex_t_varchar2;
	BEGIN
		v_Pattern_Array := apex_string.split(p_Pattern, ',');
		for c_idx IN 1..v_Pattern_Array.count loop
			if p_Column_Name LIKE v_Pattern_Array(c_idx) ESCAPE '\' then
				RETURN v_Pattern_Array(c_idx);
			end if;
		end loop;
		RETURN NULL;
	END Matching_Column_Pattern;

------------------------------------------------------------------------------------------    
	FUNCTION Match_DateTime_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_DateTime_Columns_Array); END;

	FUNCTION Match_Edit_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Table_Name, g_Edit_Tables_Array); END;

	FUNCTION Match_ReadOnly_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Table_Name, g_ReadOnly_Tables_Array); END;

	FUNCTION Match_Admin_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Table_Name, g_Admin_Tables_Array); END;

	FUNCTION Match_Data_Deduction_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Data_Deduction_Array); END;

	FUNCTION Match_Yes_No_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Yes_No_Columns_Array); END;

	FUNCTION Match_ReadOnly_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_ReadOnly_Columns_Array); END;
------------------------------------------------------------------------------------------    

    FUNCTION Get_Link_ID_Expression (	-- row reference in select list, produces CAST(A.ROWID AS VARCHAR2(128)) references in case of composite or missing unique keys
    	p_Unique_Key_Column VARCHAR2,
    	p_Table_Alias VARCHAR2 DEFAULT NULL,
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    )
    RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Table_Alias	VARCHAR2(20) := case when p_Table_Alias IS NOT NULL then p_Table_Alias || '.' end;
	BEGIN
		RETURN case when p_Unique_Key_Column IS NULL
				then 'CAST(' || v_Table_Alias || 'ROWID AS VARCHAR2(128))'
			when INSTR(p_Unique_Key_Column, ',') = 0
				then v_Table_Alias || p_Unique_Key_Column
			when p_View_Mode IN ('IMPORT_VIEW', 'HISTORY')
				then 'CAST(FN_Hex_Hash_Key( '
				|| v_Table_Alias || REPLACE(p_Unique_Key_Column, ', ', ', ' || v_Table_Alias) || ') AS VARCHAR(128))'
			else
				'CAST(' || v_Table_Alias || 'ROWID AS VARCHAR2(128))'
		end;
	END Get_Link_ID_Expression;

    FUNCTION Get_Unique_Key_Expression (	-- row reference in where clause, produces A.ROWID references in case of composite or missing unique keys
    	p_Unique_Key_Column VARCHAR2,
    	p_Table_Alias	VARCHAR2 DEFAULT 'A',
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    ) RETURN VARCHAR2 DETERMINISTIC
	IS
		v_Table_Alias	VARCHAR2(20) := case when p_Table_Alias IS NOT NULL then p_Table_Alias || '.' end;
		v_Result 		VARCHAR2(2000);
		v_Names_Array apex_t_varchar2;
	BEGIN
		if p_Unique_Key_Column IS NULL then 
			-- when table has no primary key, then p_Search_Value is the value of ROWIDTOCHAR(ROWID)
			return v_Table_Alias || 'ROWID';
		elsif INSTR(p_Unique_Key_Column, ',') = 0 then 
				return v_Table_Alias || p_Unique_Key_Column;
		elsif p_View_Mode IN ('IMPORT_VIEW', 'HISTORY') then 
			v_Names_Array := apex_string.split(p_Unique_Key_Column, ',');
			for c_idx IN 1..v_Names_Array.count loop
				v_Result := v_Result 
				|| case when v_Result IS NOT NULL then ', ' end 
				|| v_Table_Alias 
				|| TRIM(v_Names_Array(c_idx));
			end loop;
			return 'CAST(FN_Hex_Hash_Key( ' || v_Result || ') AS VARCHAR(128))';
		else
			return v_Table_Alias || 'ROWID';
		end if;
	END Get_Unique_Key_Expression;

    FUNCTION Get_Foreign_Key_Expression (	-- row reference in where clause, produces FN_Hex_Hash_Key references in case of composite unique keys
    	p_Foreign_Key_Column VARCHAR2,
    	p_Table_Alias 		VARCHAR2 DEFAULT 'A',
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    ) RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
		v_Table_Alias	VARCHAR2(20) := case when p_Table_Alias IS NOT NULL then p_Table_Alias || '.' end;
		v_Result 		VARCHAR2(2000);
		v_Names_Array apex_t_varchar2;
	BEGIN
		if p_Foreign_Key_Column IS NULL then
			return 'CAST(' || v_Table_Alias || 'ROWID AS VARCHAR2(128))';
		elsif INSTR(p_Foreign_Key_Column, ',') = 0 then 
			return v_Table_Alias || p_Foreign_Key_Column;
		elsif p_View_Mode IN ('IMPORT_VIEW', 'HISTORY') then 
			v_Names_Array := apex_string.split(p_Foreign_Key_Column, ',');
			for c_idx IN 1..v_Names_Array.count loop
				v_Result := v_Result 
				|| case when v_Result IS NOT NULL then ', ' end 
				|| v_Table_Alias 
				|| TRIM(v_Names_Array(c_idx));
			end loop;
			return 'FN_Hex_Hash_Key(' || v_Result || ')';		
		else
			return 'CAST(' || v_Table_Alias || 'ROWID AS VARCHAR2(128))';
		end if;
	END Get_Foreign_Key_Expression;

    FUNCTION Get_Join_Expression (
    	p_Left_Columns 	VARCHAR2,
    	p_Left_Alias 	VARCHAR2 DEFAULT 'A',
    	p_Right_Columns VARCHAR2,
    	p_Right_Alias 	VARCHAR2 DEFAULT 'B'
    ) RETURN VARCHAR2 
	IS
	PRAGMA UDF;
		v_Result 		VARCHAR2(2000);
		v_Left_Names_Array apex_t_varchar2;
		v_Right_Names_Array apex_t_varchar2;
		v_Limit PLS_INTEGER;
	BEGIN
		if p_Left_Columns IS NULL then
			return 'NULL';
		elsif INSTR(p_Left_Columns, ',') = 0 then 
			return p_Left_Alias || '.' || p_Left_Columns
				|| ' = '
				|| p_Right_Alias || '.' || p_Right_Columns;
		else
			v_Left_Names_Array := apex_string.split(p_Left_Columns, ',');
			v_Right_Names_Array := apex_string.split(p_Right_Columns, ',');
			v_Limit := LEAST(v_Left_Names_Array.count, v_Right_Names_Array.count);
			for c_idx IN 1..v_Limit loop
				v_Result := v_Result 
				|| case when v_Result IS NOT NULL then ' AND ' end 
				|| p_Left_Alias || '.' 
				|| TRIM(v_Left_Names_Array(c_idx))
				|| ' = '
				|| p_Right_Alias || '.' 
				|| TRIM(v_Right_Names_Array(c_idx))
				;
			end loop;
			return v_Result;		
		end if;
	END Get_Join_Expression;

	FUNCTION ChangeLog_Pivot_Query (
		p_Table_Name VARCHAR2,
		p_Convert_Data_Types IN VARCHAR2 DEFAULT 'YES',
		p_Compact_Queries VARCHAR2 DEFAULT 'NO' -- YES, NO
	) RETURN CLOB
	IS
		v_Result CLOB;
	BEGIN
		if g_Get_ChangLog_Query_Call IS NOT NULL
		and data_browser_conf.Has_ChangeLog_History(p_Table_Name => p_Table_Name) = 'YES' then
			EXECUTE IMMEDIATE 'begin :result := ' || g_Get_ChangLog_Query_Call || '; end;'
			USING OUT v_Result, IN p_Table_Name, p_Convert_Data_Types, p_Compact_Queries;
		end if;
		return v_Result;
	END ChangeLog_Pivot_Query;

	FUNCTION Check_Developer_Enabled RETURN BOOLEAN
	IS
    	v_Count PLS_INTEGER;
    	v_Query	VARCHAR2(2000);
		v_Developer_Enabled BOOLEAN := FALSE;
		cv 		SYS_REFCURSOR;
	BEGIN
		if g_Developer_Enabled_Query IS NOT NULL then
			-- check that the user is permitted to edit table data.
			v_Query := 'select count(*) from sys.dual where exists (' || g_Developer_Enabled_Query || ')';
			OPEN cv FOR v_Query;
			FETCH cv INTO v_Count;
			CLOSE cv;
			v_Developer_Enabled := (v_Count > 0);
		end if;

		return v_Developer_Enabled;
	exception when others then
		RAISE_APPLICATION_ERROR(-20100, 'Processing for Developer_Enabled_Query failed with ' || SQLERRM);
	END Check_Developer_Enabled;


	FUNCTION Check_Edit_Enabled RETURN BOOLEAN
	IS
    	v_Count PLS_INTEGER;
    	v_Query	VARCHAR2(2000);
		v_Edit_Enabled BOOLEAN := FALSE;
		cv 		SYS_REFCURSOR;
	BEGIN
		if g_Edit_Enabled_Query IS NOT NULL then
			-- check that the user is permitted to edit table data.
			v_Query := 'select count(*) from sys.dual where exists (' || g_Edit_Enabled_Query || ')';
			OPEN cv FOR v_Query;
			FETCH cv INTO v_Count;
			CLOSE cv;
			v_Edit_Enabled := (v_Count > 0);
		end if;

		return v_Edit_Enabled;
	exception when others then
		RAISE_APPLICATION_ERROR(-20100, 'Processing for Check_Edit_Enabled failed with ' || SQLERRM);
	END Check_Edit_Enabled;


    FUNCTION Check_Edit_Enabled(
    	p_Table_Name VARCHAR2
    ) RETURN VARCHAR2 -- YES, NO
    IS
    	v_Count PLS_INTEGER;
    	v_Query	VARCHAR2(2000);
		v_Edit_Enabled VARCHAR2(10) := 'NO';
		cv 		SYS_REFCURSOR;
	BEGIN
		if p_Table_Name IS NOT NULL then 
			if data_browser_conf.Match_Edit_Tables(p_Table_Name) = 'YES' then
				v_Edit_Enabled := 'YES';
			end if;
			if data_browser_conf.Match_ReadOnly_Tables(p_Table_Name) = 'YES' then
				v_Edit_Enabled := 'NO';
			end if;
			if v_Edit_Enabled = 'YES' and g_Edit_Enabled_Query IS NOT NULL then
				-- check that the user is permitted to edit table data.
				v_Query := 'select count(*) from sys.dual where exists (' || g_Edit_Enabled_Query || ')';
				OPEN cv FOR v_Query;
				FETCH cv INTO v_Count;
				CLOSE cv;
				v_Edit_Enabled := case when (v_Count > 0) then 'YES' else 'NO' end;
			end if;
		end if;
		return v_Edit_Enabled;
	exception when others then
		RAISE_APPLICATION_ERROR(-20100, 'Processing for Edit_Enabled_Query failed with ' || SQLERRM);
    END Check_Edit_Enabled;


    FUNCTION Check_Data_Deduction (
    	p_Column_Name VARCHAR2
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Count PLS_INTEGER;
    	v_Query	VARCHAR2(2000);
		v_Data_Deduction_Enabled VARCHAR2(10) := 'NO';
		cv 		SYS_REFCURSOR;
	BEGIN
		if g_User_Is_Data_Deducted IS NULL then
			if g_Data_Deduction_Query IS NOT NULL then
				-- check that the user is permitted to edit table data.
				v_Query := 'select count(*) from sys.dual where exists (' || g_Data_Deduction_Query || ')';
				OPEN cv FOR v_Query;
				FETCH cv INTO v_Count;
				CLOSE cv;
				g_User_Is_Data_Deducted := case when (v_Count > 0) then 'YES' else 'NO' end;
			else
				g_User_Is_Data_Deducted := 'NO';
			end if;
		end if;
		if g_User_Is_Data_Deducted = 'YES' then
			v_Data_Deduction_Enabled := data_browser_conf.Match_Data_Deduction_Columns(p_Column_Name);
		end if;
		return v_Data_Deduction_Enabled;
	exception when others then
		RAISE_APPLICATION_ERROR(-20100, 'Processing for Check_Data_Deduction failed with ' || SQLERRM);
    END Check_Data_Deduction;

    FUNCTION Check_Admin_Enabled (
    	p_Table_Name VARCHAR2
    ) RETURN BOOLEAN
    IS
    	v_Count PLS_INTEGER;
    	v_Query	VARCHAR2(2000);
		v_Admin_Enabled BOOLEAN := FALSE;
		cv 		SYS_REFCURSOR;
	BEGIN
		v_Admin_Enabled := data_browser_conf.Match_Admin_Tables(p_Table_Name) = 'YES';
		if v_Admin_Enabled then
			-- check that the user is permitted to edit table data.
			v_Admin_Enabled := Get_Admin_Enabled = 'Y';
		end if;
		return v_Admin_Enabled;
	exception when others then
		RAISE_APPLICATION_ERROR(-20100, 'Processing for Admin_Enabled_Query failed with ' || SQLERRM);
    END Check_Admin_Enabled;

    FUNCTION Get_Admin_Enabled
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Count PLS_INTEGER;
    	v_Query	VARCHAR2(1024);
		cv 		SYS_REFCURSOR;
	BEGIN
		if g_Admin_Enabled IS NOT NULL then 
			return g_Admin_Enabled;
		end if;
		if g_Admin_Enabled_Query IS NOT NULL then
			-- check that the user is permitted to edit table data.
			v_Query := 'select count(*) from sys.dual where exists (' || g_Admin_Enabled_Query || ')';
			OPEN cv FOR v_Query;
			FETCH cv INTO v_Count;
			CLOSE cv;
			g_Admin_Enabled := case when (v_Count > 0) then 'Y' else 'N' end;
		end if;
		
		return g_Admin_Enabled;
	exception when others then
		RAISE_APPLICATION_ERROR(-20100, 'Processing for Admin_Enabled_Query failed with ' || SQLERRM);
    END Get_Admin_Enabled;

    FUNCTION Get_Install_Sup_Obj_Enabled RETURN VARCHAR2
    IS
	PRAGMA UDF;
	BEGIN
		return case when (data_browser_conf.Get_Admin_Enabled = 'Y'
			and data_browser_specs.g_use_apex_installer)
		then 'Y' else 'N' end;
    END Get_Install_Sup_Obj_Enabled;

    FUNCTION Get_Detect_Yes_No_Static_LOV RETURN VARCHAR2 IS BEGIN RETURN g_Detect_Yes_No_Static_LOV; END;

    FUNCTION Get_Yes_No_Column_Type (
    	p_Table_Name VARCHAR2,
    	p_Table_Owner VARCHAR2,
    	p_Column_Name VARCHAR2,
		p_Data_Type VARCHAR2,
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Char_Length NUMBER,
		p_Nullable VARCHAR2,
		p_Num_Distinct NUMBER,
		p_Default_Text VARCHAR2,
		p_Check_Condition VARCHAR2,
		p_Explain VARCHAR2 DEFAULT 'NO'
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
		v_Is_Number_Yes_No_Default BOOLEAN := NULL;	-- Important! three values logic NULL=UNKNOWN
		v_Is_Char_Yes_No_Default BOOLEAN := NULL;	-- Important! three values logic NULL=UNKNOWN
		v_Is_Number_Yes_No_Check BOOLEAN := NULL;	-- Important! three values logic NULL=UNKNOWN
		v_Is_Char_Yes_No_Check 	BOOLEAN := NULL;	-- Important! three values logic NULL=UNKNOWN
		v_Match_Count 			PLS_INTEGER := 0;
		v_Check_List 			VARCHAR2(32767);
		v_Check_Pattern			VARCHAR2(128);
		v_Check_Condition 		VARCHAR2(32767);
	BEGIN
		if p_Column_Name IS NULL then
			return case when p_Explain = 'YES' then 'FAILED. Reason: Column_Name IS NULL' end;
		end if;
		if p_Data_Type NOT IN ('CHAR', 'VARCHAR', 'VARCHAR2', 'NUMBER') then
			return case when p_Explain = 'YES' then 'FAILED. Reason: datatype contradiction. Datatype ''' || p_Data_Type || ''' is not supported.' end;
		end if;
		if p_Default_Text IS NOT NULL then
			v_Is_Number_Yes_No_Default 	:= p_Default_Text IN (
				data_browser_conf.Get_Boolean_No_Value('NUMBER', 'VALUE'),
				data_browser_conf.Get_Boolean_Yes_Value('NUMBER', 'VALUE'),
				data_browser_conf.Get_Boolean_No_Value('NUMBER', 'ENQUOTE'),
				data_browser_conf.Get_Boolean_Yes_Value('NUMBER', 'ENQUOTE')
			);
			v_Is_Char_Yes_No_Default	:= p_Default_Text IN (
				data_browser_conf.Get_Boolean_No_Value('CHAR', 'ENQUOTE'),
				data_browser_conf.Get_Boolean_Yes_Value('CHAR', 'ENQUOTE')
			);
			if v_Is_Number_Yes_No_Default = FALSE and v_Is_Char_Yes_No_Default = FALSE then
				return case when p_Explain = 'YES' then 'FAILED. Reason: default value contradiction' end;
			end if;
		end if;

		if p_Check_Condition IS NOT NULL then
			-- remove quotes from column name
			v_Check_Condition := REGEXP_REPLACE(TRIM(p_Check_Condition), '"(' || p_Column_Name || ')"', '\1', 1, 0, 'i');
			-- Check pattern: COL IN (0, 1)
			v_Check_Pattern := '^' || p_Column_Name || '\s+IN\s*\((.+)\)\s*$';
			if REGEXP_INSTR(v_Check_Condition, v_Check_Pattern, 1, 1, 1, 'i') > 0 then
				v_Check_List := REGEXP_REPLACE(v_Check_Condition, v_Check_Pattern, '\1', 1, 1, 'i');
			end if;
			if v_Check_List IS NULL then
				-- Check pattern: COL = 0 OR COL = 1
				v_Check_Pattern := '^' || p_Column_Name || '\s*=\s*(.+)\s+OR\s+' || p_Column_Name || '\s*=\s*(.+)$';
				if REGEXP_INSTR(v_Check_Condition, v_Check_Pattern, 1, 1, 1, 'i') > 0 then
					v_Check_List := REGEXP_REPLACE(v_Check_Condition, v_Check_Pattern, '\1,\2', 1, 1, 'i');
				end if;
			end if;
			if v_Check_List IS NOT NULL then
				for c_cur IN (
					SELECT TRIM(COLUMN_VALUE) COL_VALUE
					FROM TABLE( apex_string.split(v_Check_List, ','))
				) loop
					v_Is_Number_Yes_No_Check 	:= c_cur.COL_VALUE IN (
						data_browser_conf.Get_Boolean_No_Value('NUMBER', 'VALUE'),
						data_browser_conf.Get_Boolean_Yes_Value('NUMBER', 'VALUE'),
						data_browser_conf.Get_Boolean_No_Value('NUMBER', 'ENQUOTE'),
						data_browser_conf.Get_Boolean_Yes_Value('NUMBER', 'ENQUOTE')
					);
					v_Is_Char_Yes_No_Check		:= c_cur.COL_VALUE IN (
						data_browser_conf.Get_Boolean_No_Value('CHAR', 'ENQUOTE'),
						data_browser_conf.Get_Boolean_Yes_Value('CHAR', 'ENQUOTE')
					);
					if v_Is_Number_Yes_No_Check = FALSE and v_Is_Char_Yes_No_Check = FALSE then
						return case when p_Explain = 'YES' then 'FAILED. Reason: IN list values contradiction' end;
					end if;
					v_Match_Count := v_Match_Count + 1;
				end loop;
			else
				return case when p_Explain = 'YES' then 'FAILED. Reason: Check is not an IN list and neither an OR expression; contradiction' end;
			end if;
			if v_Match_Count != 2 then
				return case when p_Explain = 'YES' then 'FAILED. Reason: IN list members contradiction' end;
			end if;
		end if;

		if NOT(v_Is_Number_Yes_No_Check or v_Is_Char_Yes_No_Check) and p_Num_Distinct > 2 then
			return case when p_Explain = 'YES' then 'FAILED. Reason: no check condition supports the column and contradition; more than 2 values found' end;
		end if;

		if data_browser_conf.Match_Yes_No_Columns(p_Column_Name) = 'YES' then
			-- column name is matching pattern and no contraditions
			if p_Data_Type IN ('CHAR', 'VARCHAR', 'VARCHAR2')
				and (v_Is_Char_Yes_No_Default or v_Is_Char_Yes_No_Default IS NULL)
				and (v_Is_Char_Yes_No_Check or v_Is_Char_Yes_No_Check IS NULL) then
				return 'CHAR';
			elsif p_Data_Type IN ('CHAR', 'VARCHAR', 'VARCHAR2', 'NUMBER')
			and (v_Is_Number_Yes_No_Default or v_Is_Number_Yes_No_Default IS NULL)
			and (v_Is_Number_Yes_No_Check or v_Is_Number_Yes_No_Check IS NULL) then
				return 'NUMBER';
			end if;
			return case when p_Explain = 'YES' then 'FAILED. Reason: matching name, but no default value or check condition or weak hints (' || p_Default_Text || ')' end;
		elsif Get_Detect_Yes_No_Static_LOV = 'YES' then
			-- column name is not matching pattern and no contraditions
			if (p_Data_Type IN ('CHAR', 'VARCHAR', 'VARCHAR2') AND p_Char_Length <= 3)		-- string length <= 3; is a weak hint
			and (v_Is_Char_Yes_No_Default or v_Is_Char_Yes_No_Check) then	-- require default value or check condition
				return 'CHAR';
			elsif (p_Data_Type IN ('CHAR', 'VARCHAR', 'VARCHAR2') AND p_Char_Length <= 3)	-- string length <= 3; is a weak hint
			and (v_Is_Number_Yes_No_Default 		-- default value Y or N;  is a strong hint
				or v_Is_Number_Yes_No_Check			-- check condition;  is a strong hint
			) then									-- require default value or check condition
				return 'NUMBER';
			elsif (p_Data_Type = 'NUMBER' AND NVL(p_Data_Scale, numbers_utl.g_Default_Data_Scale) = 0 AND NVL(p_Data_Precision, numbers_utl.g_Default_Data_Precision) <= 3) -- number is INTEGER and length <= 3; is a weak hint
			and ((v_Is_Number_Yes_No_Default 		-- has default value 0 or 1; weak hint
					and (NVL(p_Data_Precision, numbers_utl.g_Default_Data_Precision) = 1 -- number is INTEGER and length = 1; still 10 posible values; weak hint
					 or p_Num_Distinct = 2)			-- 2 known value; strong hint
					and p_Nullable = 'N'			-- NOT NULL constraint; weak hint
				 )									-- require 3 weak hints to pass the test
				  or v_Is_Number_Yes_No_Check) then	-- check condition;  is a strong hint
				return 'NUMBER';
			end if;
			return case when p_Explain = 'YES' then 'FAILED. Reason: detection enabled, but no default value or check condition or weak hints' end;
		end if;
		return case when p_Explain = 'YES' then 'FAILED. Reason: mismatching name, detection disabled, no default value or check condition or weak hints' end;
	END Get_Yes_No_Column_Type;

    FUNCTION Get_Yes_No_Column_Type (
    	p_Table_Name VARCHAR2,
    	p_Table_Owner VARCHAR2,
    	p_Column_Name VARCHAR2
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
		v_Result			VARCHAR2(128);
	BEGIN
		if p_Column_Name IS NOT NULL then 
			SELECT DISTINCT
				data_browser_conf.Get_Yes_No_Column_Type (
					p_Table_Name => AC.TABLE_NAME,
					p_Table_Owner => AC.OWNER,
					p_Column_Name => AC.COLUMN_NAME,
					p_Data_Type => AC.DATA_TYPE,
					p_Data_Precision => AC.DATA_PRECISION,
					p_Data_Scale => AC.DATA_SCALE,
					p_Char_Length => AC.CHAR_LENGTH,
					p_Nullable => AC.NULLABLE,
					p_Num_Distinct => AC.NUM_DISTINCT,
					p_Default_Text => AC.DEFAULT_TEXT,
					p_Check_Condition => B.SEARCH_CONDITION
				) Result
			INTO v_Result
			FROM TABLE (data_browser_conf.Table_Columns_Cursor(
				p_Table_Name => p_Table_Name,
				p_Owner => p_Table_Owner,
				p_Column_Name => p_Column_Name
			)) AC
			LEFT OUTER JOIN TABLE (data_browser_conf.Constraint_Columns_Cursor (
				p_Table_Name=>p_Table_Name, 
				p_Owner=>p_Table_Owner
			)) B ON AC.TABLE_NAME = B.TABLE_NAME 
				AND AC.OWNER = B.OWNER
				AND AC.COLUMN_NAME = B.COLUMN_NAME
			; 
		end if;
		return v_Result;
	END Get_Yes_No_Column_Type;

    FUNCTION Get_Yes_No_Type_LOV (
    	p_Data_type VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN case when p_Data_Type = 'NUMBER' then g_Yes_No_Number_Static_LOV else g_Yes_No_Char_Static_LOV end;
    END Get_Yes_No_Type_LOV;

    FUNCTION Get_Boolean_Yes_Value (
    	p_Data_type VARCHAR2,
    	p_Expr_Type VARCHAR2 DEFAULT 'VALUE' -- VALUE, ENQUOTE, LABEL, TRANSLATE
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
		v_Static_LOV	VARCHAR2(64);
		v_Result 		VARCHAR2(64);
		v_Index			PLS_INTEGER;
    BEGIN
    	v_Static_LOV 	:= case when p_Data_Type = 'NUMBER' then g_Yes_No_Number_Static_LOV else g_Yes_No_Char_Static_LOV end;
		v_Index			:= case when p_Expr_Type IN ('VALUE', 'ENQUOTE') then 2 else 1 end;
		v_Result		:= REGEXP_SUBSTR(v_Static_LOV, '(\w+);(\w+),(\w+);(\w+)', 1, 1, 'i', v_Index);
		return case p_Expr_Type
			when 'VALUE' then v_Result
			when 'ENQUOTE' then Enquote_Literal(v_Result)
			when 'LABEL' then v_Result
			when 'TRANSLATE' then 'apex_lang.lang(' || Enquote_Literal(v_Result) || ')'
		end;
    END Get_Boolean_Yes_Value;

    FUNCTION Get_Boolean_No_Value (
    	p_Data_type VARCHAR2,
    	p_Expr_Type VARCHAR2 DEFAULT 'VALUE' -- VALUE, ENQUOTE, LABEL, TRANSLATE
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
		v_Static_LOV	VARCHAR2(64);
		v_Result 		VARCHAR2(64);
		v_Index			PLS_INTEGER;
    BEGIN
    	v_Static_LOV 	:= case when p_Data_Type = 'NUMBER' then g_Yes_No_Number_Static_LOV else g_Yes_No_Char_Static_LOV end;
		v_Index			:= case when p_Expr_Type IN ('VALUE', 'ENQUOTE') then 4 else 3 end;
		v_Result		:= REGEXP_SUBSTR(v_Static_LOV, '(\w+);(\w+),(\w+);(\w+)', 1, 1, 'i', v_Index);
		return case p_Expr_Type
			when 'VALUE' then v_Result
			when 'ENQUOTE' then Enquote_Literal(v_Result)
			when 'LABEL' then v_Result
			when 'TRANSLATE' then 'apex_lang.lang(' || Enquote_Literal(v_Result) || ')'
		end;
    END Get_Boolean_No_Value;
/*
	SELECT DATA_TYPE, EXPR_TYPE,
			data_browser_conf.Get_Boolean_Yes_Value(p_Data_type=>DATA_TYPE, p_Expr_Type=>EXPR_TYPE) Yes_Value, 
			data_browser_conf.Get_Boolean_No_Value(p_Data_type=>DATA_TYPE, p_Expr_Type=>EXPR_TYPE) No_Value
	FROM (SELECT COLUMN_VALUE EXPR_TYPE FROM TABLE( data_browser_conf.in_list('VALUE, ENQUOTE, LABEL, TRANSLATE', ','))) E,
		(SELECT COLUMN_VALUE DATA_TYPE FROM TABLE( data_browser_conf.in_list('CHAR, NUMBER', ','))) D;
*/
    FUNCTION Get_Yes_No_Static_LOV (
    	p_Data_type VARCHAR2
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Result VARCHAR2(1000);
    BEGIN
		SELECT LISTAGG(Apex_Lang.Lang(D_VALUE) || ';' || R_VALUE, ',') WITHIN GROUP (ORDER BY POSITION)
				TRANSLATED_LOV
		INTO v_Result
		FROM (
			select SUBSTR(P.COLUMN_VALUE, 1, OFFSET-1) D_VALUE,
				SUBSTR(P.COLUMN_VALUE, OFFSET+1) R_VALUE,
				POSITION
			from (
				SELECT P.COLUMN_VALUE, INSTR(P.COLUMN_VALUE, ';') OFFSET, ROWNUM POSITION
				FROM TABLE( apex_string.split(data_browser_conf.Get_Yes_No_Type_LOV(p_Data_type), ',') ) P
			) P
		);
    	RETURN v_Result;
    END Get_Yes_No_Static_LOV;

    FUNCTION Get_Yes_No_Check (
    	p_Data_type VARCHAR2,
    	p_Column_Name VARCHAR2 
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Result VARCHAR2(1000);
    BEGIN
		SELECT LISTAGG(Enquote_Literal(D_VALUE) || ',' || Enquote_Literal(Apex_Lang.Lang(D_VALUE)) || ',' || Enquote_Literal(R_VALUE), ',') WITHIN GROUP (ORDER BY POSITION)
				TRANSLATED_LOV
		INTO v_Result
		FROM (
			select SUBSTR(P.COLUMN_VALUE, 1, OFFSET-1) D_VALUE,
				SUBSTR(P.COLUMN_VALUE, OFFSET+1) R_VALUE,
				POSITION
			from (
				SELECT P.COLUMN_VALUE, INSTR(P.COLUMN_VALUE, ';') OFFSET, ROWNUM POSITION
				FROM TABLE( apex_string.split(data_browser_conf.Get_Yes_No_Type_LOV(p_Data_type), ',') ) P
			) P
		);
    	RETURN p_Column_Name || ' IN ( ' || v_Result || ' )';
    END Get_Yes_No_Check;

    FUNCTION Lookup_Yes_No (
    	p_Data_type VARCHAR2,
    	p_Column_Value VARCHAR2 
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Result VARCHAR2(100);
    BEGIN
		SELECT MAX(R_VALUE)
		INTO v_Result
		FROM (
			select SUBSTR(P.COLUMN_VALUE, 1, OFFSET-1) D_VALUE,
				SUBSTR(P.COLUMN_VALUE, OFFSET+1) R_VALUE,
				POSITION
			from (
				SELECT P.COLUMN_VALUE, INSTR(P.COLUMN_VALUE, ';') OFFSET, ROWNUM POSITION
				FROM TABLE( apex_string.split(data_browser_conf.Get_Yes_No_Type_LOV(p_Data_type), ',') ) P
			) P
		) WHERE p_Column_Value IN (D_VALUE, Apex_Lang.Lang(D_VALUE), R_VALUE);
		return v_Result;
    END Lookup_Yes_No;

    FUNCTION Lookup_Yes_No_Call (
    	p_Data_type VARCHAR2,
    	p_Column_Name VARCHAR2 
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN 'data_browser_conf.Lookup_Yes_No ( ' || Enquote_Literal(p_Data_type) || ', ' || p_Column_Name || ' )';
    END Lookup_Yes_No_Call;


    FUNCTION Get_Yes_No_Static_Function (
    	p_Column_Name VARCHAR2,
    	p_Data_type VARCHAR2
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
    	v_Result VARCHAR2(1000);
    BEGIN
    	RETURN 'case to_char(' || p_Column_Name || ') when '
			|| data_browser_conf.Get_Boolean_Yes_Value(p_Data_type, 'ENQUOTE')
    		|| ' then '
    		|| data_browser_conf.Get_Boolean_Yes_Value(p_Data_type, 'TRANSLATE')
    		|| ' when '
			|| data_browser_conf.Get_Boolean_No_Value(p_Data_type, 'ENQUOTE')
    		|| ' then '
    		|| data_browser_conf.Get_Boolean_No_Value(p_Data_type, 'TRANSLATE')
    		|| ' end';
    END;

	PROCEDURE Set_Generate_Compact_Queries (
		p_Yes_No VARCHAR2
	)
	IS
		v_Yes_No VARCHAR2(10) := UPPER(p_Yes_No);
	BEGIN
		g_Generate_Compact_Queries := case
			when v_Yes_No IN ('YES', 'NO') then p_Yes_No
			when v_Yes_No = 'Y' then 'YES'
			when v_Yes_No = 'N' then 'NO'
			else g_Generate_Compact_Queries
		end;
	END;

	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2 DETERMINISTIC
	is
	PRAGMA UDF;
	begin
		return case when g_Generate_Compact_Queries = 'NO'
			then chr(10) || RPAD(' ', p_Indent)
			else chr(10) end;
	end;

	FUNCTION PA(p_Param_Name VARCHAR2) RETURN VARCHAR2	-- remove parameter names for compact code generation
	is
	begin
		return case when g_Generate_Compact_Queries = 'YES'
			then case when INSTR(p_Param_Name, ',') > 0 then ',' else '' end
			else p_Param_Name
		end;
	end;

	FUNCTION Enquote_Literal ( p_Text VARCHAR2 )
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
		v_Quote CONSTANT VARCHAR2(1) := chr(39);
	BEGIN
		RETURN v_Quote || REPLACE(p_Text, v_Quote, v_Quote||v_Quote) || v_Quote ;
	END;

	FUNCTION Dequote_Literal ( p_Text VARCHAR2 ) 
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		if SUBSTR(p_Text,1,1) = chr(39) then 
			return SUBSTR(p_Text, 2, LENGTH(p_Text) - 2);
		else 
			return p_Text;
		end if;
	END;

	FUNCTION Enquote_Name_Required (p_Text VARCHAR2)
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		if REGEXP_SUBSTR(p_Text, '([[:alpha:]][[:alnum:]|_]+)') != p_Text
		then 
			return DBMS_ASSERT.ENQUOTE_NAME (str => p_Text, capitalize => FALSE);
		else
			return p_Text;
		end if;
	END;

    FUNCTION Get_Row_Selector_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Row_Selector_Index; END;
    FUNCTION Get_Row_Selector_Expr RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	RETURN 'apex_application.G_F' || LPAD( g_Row_Selector_Index, 2, '0');
    END;
    FUNCTION Get_Link_ID_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Link_ID_Index; END;
    FUNCTION Get_Link_ID_Expr RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	RETURN 'apex_application.G_F' || LPAD( g_Link_ID_Index, 2, '0');
    END;
    FUNCTION Get_Search_Column_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Search_Column_Index; END;
    FUNCTION Get_Search_Operator_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Search_Operator_Index; END;
    FUNCTION Get_Search_Value_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Search_Value_Index; END;
    FUNCTION Get_Search_LOV_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Search_LOV_Index; END;
    FUNCTION Get_Search_Active_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Search_Active_Index; END;
    FUNCTION Get_Search_Seq_ID_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Search_Seq_ID_Index; END;
    FUNCTION Get_Joins_Alias_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Joins_Alias_Index; END;
    FUNCTION Get_Joins_Option_Index RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Joins_Option_Index; END;
	FUNCTION Get_Sys_Guid_Function RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_Sys_Guid_Function; END;
    FUNCTION Get_MD5_Column_Name RETURN VARCHAR2 DETERMINISTIC IS BEGIN RETURN g_MD5_Column_Name; END;
    FUNCTION Get_MD5_Column_Index RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN RETURN LPAD( g_MD5_Column_Index, 2, '0'); END;

    FUNCTION Get_Export_CSV_Mode RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN -- https://www.talkapex.com/2010/06/how-to-only-display-column-when/
    	return case when APEX_APPLICATION.G_EXCEL_FORMAT 
    			then 'YES'
    		when V('REQUEST') IN ('CSV','HTMLD')
    			then 'YES'
    		else 'NO'
    		end;
    END;

    FUNCTION Get_Export_NumChars(p_Enquote VARCHAR2 DEFAULT 'YES') RETURN VARCHAR2
    IS
    BEGIN
		RETURN case when p_Enquote = 'NO' 
			then 'NLS_NUMERIC_CHARACTERS = ' || Enquote_Literal(g_Export_NumChars) 
			else 'q''[NLS_NUMERIC_CHARACTERS = ' || Enquote_Literal(g_Export_NumChars) || ']''' 
		end;
    END;

    FUNCTION Get_Export_NLS_Param RETURN VARCHAR2
    IS
    BEGIN
		RETURN 'NLS_NUMERIC_CHARACTERS = ' || dbms_assert.enquote_literal(g_Export_NumChars)
		|| ' NLS_CURRENCY = ' || dbms_assert.enquote_literal(g_Export_Currency);
    END Get_Export_NLS_Param;

    FUNCTION Get_Export_Number (p_Value VARCHAR2) RETURN NUMBER
    IS
    BEGIN
		RETURN TO_NUMBER(TRIM(p_Value), numbers_utl.Get_Number_Mask(p_Value, g_Export_NumChars, g_Export_Currency), Get_Export_NLS_Param);
    END Get_Export_Number;

    FUNCTION Get_Number_Decimal_Character RETURN VARCHAR2
    IS
    BEGIN
		RETURN SUBSTR(g_Export_NumChars, 1, 1);
    END Get_Number_Decimal_Character;

    FUNCTION Get_Number_Group_Separator RETURN VARCHAR2
    IS
    BEGIN
		RETURN SUBSTR(g_Export_NumChars, 2, 1);
    END Get_Number_Group_Separator;

    FUNCTION Get_Number_Pattern RETURN VARCHAR2
    IS
    BEGIN
    	RETURN numbers_utl.Get_Number_Pattern(g_Export_NumChars);
    END Get_Number_Pattern;

	FUNCTION Get_Default_Currency_Precision (
		p_Data_Precision NUMBER,
		p_Is_Currency VARCHAR2,
		p_Data_Type VARCHAR2
	) RETURN NUMBER DETERMINISTIC 
	IS 
	PRAGMA UDF;
	BEGIN 
		RETURN case 
		when p_Data_Type = 'NUMBER' and p_Is_Currency = 'Y' then 
			case when p_Data_Precision IS NULL then g_Default_Currency_Precision
			else GREATEST(p_Data_Precision, g_Default_Currency_Precision)
			end
		when p_Data_Type = 'FLOAT' and p_Is_Currency = 'Y' then g_Default_Currency_Precision
		else p_Data_Precision
		end;
	END Get_Default_Currency_Precision;

	FUNCTION Get_Default_Currency_Scale (
		p_Data_Scale NUMBER,
		p_Is_Currency VARCHAR2,
		p_Data_Type VARCHAR2
	) RETURN NUMBER DETERMINISTIC 
	IS 
	PRAGMA UDF;
	BEGIN 
		RETURN case 
			when p_Data_Type = 'NUMBER' and p_Is_Currency = 'Y' then 
				case when p_Data_Scale IS NULL then g_Default_Currency_Scale
				else GREATEST(p_Data_Scale, g_Default_Currency_Scale)
				end
			when p_Data_Type = 'FLOAT' and p_Is_Currency = 'Y' then g_Default_Currency_Scale
			else p_Data_Scale
		end;
	END Get_Default_Currency_Scale;

	FUNCTION Get_Export_Float_Format RETURN VARCHAR2 IS BEGIN RETURN g_Export_Float_Format; END;

	FUNCTION Get_NLS_Date_Format RETURN VARCHAR2
	IS
	BEGIN
		if g_NLS_Date_Format IS NULL then
			SELECT value
			INTO g_NLS_Date_Format
			FROM nls_session_parameters
			WHERE parameter = 'NLS_DATE_FORMAT';
		end if;
		RETURN g_NLS_Date_Format;
	END Get_NLS_Date_Format;

	FUNCTION Get_NLS_NumChars RETURN VARCHAR2
	IS
	BEGIN
		if g_NLS_NumChars IS NULL then
			SELECT value
			INTO g_NLS_NumChars
			FROM nls_session_parameters
			WHERE parameter = 'NLS_NUMERIC_CHARACTERS';
		end if;
		RETURN g_NLS_NumChars;
	END Get_NLS_NumChars;

	FUNCTION Get_NLS_Currency RETURN VARCHAR2
	IS
	BEGIN
		if g_NLS_Currency IS NULL then
			SELECT value
			INTO g_NLS_Currency
			FROM nls_session_parameters
			WHERE parameter = 'NLS_CURRENCY';
		end if;
		RETURN g_NLS_Currency;
	END Get_NLS_Currency;

	FUNCTION Get_NLS_Decimal_Radix_Char RETURN VARCHAR2
	IS BEGIN 
		RETURN SUBSTR(Get_NLS_NumChars, 1, 1);
	END ;
	
	FUNCTION Get_NLS_Decimal_Grouping_Char RETURN VARCHAR2
	IS BEGIN 
		RETURN SUBSTR(Get_NLS_NumChars, 2, 1);
	END;
		
	FUNCTION Get_NLS_Column_Delimiter_Char RETURN VARCHAR2
	IS BEGIN -- column delimiter used by apex in csv download when no value is set in the classic report.
		RETURN case when Get_NLS_Decimal_Radix_Char = ',' then ';' else ',' end;
	END;

	FUNCTION Get_App_Date_Time_Format RETURN VARCHAR2
	IS
	BEGIN
		if g_App_Date_Time_Format IS NULL then
			g_App_Date_Time_Format := NVL(APEX_UTIL.GET_SESSION_STATE('APP_DATE_TIME_FORMAT'), SYS_CONTEXT('USERENV', 'NLS_DATE_FORMAT') );
		end if;
		RETURN g_App_Date_Time_Format;
	END Get_App_Date_Time_Format;

	FUNCTION Get_NLS_Timestamp_Format RETURN VARCHAR2
	IS
	BEGIN
		if g_NLS_Timestamp_Format IS NULL then
			SELECT value
			INTO g_NLS_Timestamp_Format
			FROM nls_session_parameters
			WHERE parameter = 'NLS_TIMESTAMP_FORMAT';
		end if;
		RETURN g_NLS_Timestamp_Format;
	END Get_NLS_Timestamp_Format;

	FUNCTION Get_Export_Date_Format RETURN VARCHAR2
	IS
	BEGIN RETURN case when g_Use_App_Date_Time_Format = 'NO' then g_Export_Date_Format else Get_NLS_Date_Format end;
	END;

	FUNCTION Get_Export_DateTime_Format RETURN VARCHAR2
	IS
	BEGIN RETURN case when g_Use_App_Date_Time_Format = 'NO' then g_Export_DateTime_Format else Get_App_Date_Time_Format end;
	END;

	FUNCTION Get_Timestamp_Format(
		p_Is_DateTime VARCHAR2 DEFAULT 'N'
	) RETURN VARCHAR2
	IS
		v_Format_Mask VARCHAR2(255);
	BEGIN 
		v_Format_Mask := case when g_Use_App_Date_Time_Format = 'NO' then g_Export_Timestamp_Format else Get_NLS_Timestamp_Format end;
		if p_Is_DateTime = 'N' then	
			return v_Format_Mask;
		else
			-- remove milliseconds form format mask, because APEX_ITEM.DATE_POPUP2 does not support it.
			return REGEXP_REPLACE(v_Format_Mask, 'SS[\.|,|X]FF$', 'SS');
		end	if;
	END;

	PROCEDURE Set_Export_NumChars (
		p_Decimal_Character VARCHAR2,
		p_Group_Separator VARCHAR2
	)
	IS
	BEGIN
		g_Export_NumChars := p_Decimal_Character || p_Group_Separator;
	END;

	PROCEDURE Set_Use_App_Date_Time_Format(p_Yes_No VARCHAR2)
	IS
		v_Yes_No VARCHAR2(10) := UPPER(p_Yes_No);
	BEGIN
		g_Use_App_Date_Time_Format := case
			when v_Yes_No IN ('YES', 'NO') then p_Yes_No
			when v_Yes_No = 'Y' then 'YES'
			when v_Yes_No = 'N' then 'NO'
			else g_Use_App_Date_Time_Format
		end;
	END Set_Use_App_Date_Time_Format;

	FUNCTION Get_Rec_Desc_Delimiter RETURN VARCHAR2 IS BEGIN RETURN g_Rec_Desc_Delimiter; END;
	FUNCTION Get_Rec_Desc_Group_Delimiter RETURN VARCHAR2 IS BEGIN RETURN g_Rec_Desc_Group_Delimiter; END;
	FUNCTION Get_TextArea_Min_Length RETURN NUMBER IS BEGIN RETURN g_TextArea_Min_Length; END;
	FUNCTION Get_TextArea_Max_Length RETURN NUMBER
	IS
	PRAGMA UDF;
	BEGIN RETURN g_TextArea_Max_Length; END;

	FUNCTION Get_Export_Text_Limit RETURN NUMBER IS BEGIN RETURN g_Export_Text_Limit; END;

	FUNCTION Get_Input_Field_Width (p_Field_Length NUMBER) RETURN NUMBER
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when g_Stretch_Form_Fields = 'YES' then g_Maximum_Field_Width
				else LEAST(GREATEST(NVL(p_Field_Length, 0), g_Minimum_Field_Width), g_Maximum_Field_Width)
		end;
	END Get_Input_Field_Width;

	FUNCTION Get_Button_Size (
		p_Report_Mode VARCHAR2,
		p_Column_Expr_Type VARCHAR2
	) RETURN NUMBER
	IS
	PRAGMA UDF;
		v_Button_Size 	NUMBER;
	BEGIN
		v_Button_Size := case
			when p_Column_Expr_Type IN ('POPUPKEY_FROM_LOV') and p_Report_Mode = 'NO'
				then 16
			when p_Column_Expr_Type IN ('DATE_POPUP', 'POPUP_FROM_LOV') and p_Report_Mode = 'NO'
				then 7
			when p_Column_Expr_Type IN ('POPUPKEY_FROM_LOV', 'DATE_POPUP', 'POPUP_FROM_LOV') and p_Report_Mode = 'YES'
				then 8
			when p_Column_Expr_Type IN ('POPUPKEY_FROM_LOV', 'DATE_POPUP', 'POPUP_FROM_LOV') and p_Report_Mode = 'YES'
				then 8
			when p_Column_Expr_Type IN ('SELECT_LIST', 'SELECT_LIST_FROM_QUERY') and p_Report_Mode = 'NO'
				then 2
			when p_Report_Mode = 'NO'
				then 2
			else 0		-- space for popup buttons
			end;
			/*+ case when p_Report_Mode = 'NO'
				then 6 else 0 		-- space for field help icon
			end;*/
		return v_Button_Size;
	END Get_Button_Size;

	FUNCTION Get_Input_Field_Style (
		p_Field_Length NUMBER,
		p_Button_Size NUMBER DEFAULT 0,
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2
	IS
		v_Style VARCHAR2(1024);
	BEGIN
		v_Style := case
			when p_Column_Expr_Type = 'ROW_SELECTOR' then 'width: 80px;'
			when g_Stretch_Form_Fields = 'YES' and p_Button_Size > 0 then 
				'width:' || (100 - p_Button_Size/g_Maximum_Field_Width*100 ) || '%;'
			-- || 'min-width:' || g_Minimum_Field_Width || 'ex; '
			-- || 'max-width:' || (g_Maximum_Field_Width - p_Button_Size) || 'ex;'
			end
			|| case when p_Column_Expr_Type = 'NUMBER' then 'text-align:right;' end;
		if v_Style IS NOT NULL then
			v_Style := 'style="' || v_Style || '"';
		end if;
		if p_Column_Expr_Type IN ('SELECT_LIST', 'SELECT_LIST_FROM_QUERY') then
			v_Style := data_browser_conf.Concat_List(v_Style, 'size="1"', ' ');
		end if;
		RETURN v_Style;
	END Get_Input_Field_Style;

	FUNCTION Get_Minimum_Field_Width RETURN VARCHAR2 IS BEGIN RETURN g_Minimum_Field_Width; END;
	FUNCTION Get_Maximum_Field_Width RETURN VARCHAR2 IS BEGIN RETURN g_Maximum_Field_Width; END;
	FUNCTION Get_Stretch_Form_Fields RETURN VARCHAR2 IS BEGIN RETURN g_Stretch_Form_Fields; END;
	FUNCTION Get_Select_List_Rows_Limit RETURN NUMBER
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Select_List_Rows_Limit; END;

	FUNCTION Get_Show_Tree_Num_Rows RETURN VARCHAR2 IS BEGIN RETURN g_Show_Tree_Num_Rows; END;
	FUNCTION Get_Update_Tree_Num_Rows RETURN VARCHAR2 IS BEGIN RETURN g_Update_Tree_Num_Rows; END;
	FUNCTION Get_Max_Relations_Levels RETURN NUMBER IS BEGIN RETURN g_Max_Relations_Levels; END;

    FUNCTION Get_Base_Table_Ext RETURN VARCHAR2 IS BEGIN RETURN g_Base_Table_Ext; END;
    FUNCTION Get_Base_View_Prefix RETURN VARCHAR2 IS BEGIN RETURN g_Base_View_Prefix; END;
    FUNCTION Get_Base_View_Ext RETURN VARCHAR2 IS BEGIN RETURN g_Base_View_Ext; END;
    FUNCTION Get_History_View_Name(p_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN p_Name || g_History_View_Ext; END;

	FUNCTION Get_Apex_Item_Limit RETURN PLS_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Apex_Item_Limit; END;

	FUNCTION Get_Collection_Columns_Limit RETURN PLS_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Collection_Columns_Limit; END;

	FUNCTION Get_Edit_Columns_Limit RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Edit_Columns_Limit; END;
	FUNCTION Get_Select_Columns_Limit RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Select_Columns_Limit; END;
	FUNCTION Get_Errors_Listed_Limit RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Errors_Listed_Limit; END;
	FUNCTION Get_Edit_Rows_Limit RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_Edit_Rows_Limit; END;

	FUNCTION Get_Automatic_Sorting_Limit RETURN PLS_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Automatic_Sorting_Limit; END;


	FUNCTION Get_Automatic_Search_Limit RETURN PLS_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Automatic_Search_Limit; END;

	FUNCTION Is_Automatic_Search_Enabled (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2 
	IS
	PRAGMA UDF;
		v_Row_Count NUMBER;
	BEGIN 
		SELECT NUM_ROWS INTO v_Row_Count
		FROM USER_TABLES
		WHERE TABLE_NAME =  p_Table_Name;
		RETURN case when NVL(v_Row_Count, 0) < g_Automatic_Search_Limit then 'YES' else 'NO' end; 
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return 'NO';
	END Is_Automatic_Search_Enabled;

	FUNCTION Get_Navigation_Link_Limit RETURN PLS_INTEGER DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Navigation_Link_Limit; END;

	FUNCTION Get_New_Rows_Default RETURN PLS_INTEGER DETERMINISTIC IS BEGIN RETURN g_New_Rows_Default; END;

	FUNCTION Get_Clob_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Clob_Collection else Enquote_Literal(g_Clob_Collection) end;
	END;

	FUNCTION Get_Import_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Import_Data_Collection else Enquote_Literal(g_Import_Data_Collection) end;
	END;

	FUNCTION Get_Import_Desc_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Import_Desc_Collection else Enquote_Literal(g_Import_Desc_Collection) end;
	END;

	FUNCTION Get_Import_Error_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Import_Error_Collection else Enquote_Literal(g_Import_Error_Collection) end;
	END;

	FUNCTION Get_Validation_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Validation_Collection else Enquote_Literal(g_Validation_Collection) end;
	END;

	FUNCTION Get_Lookup_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Lookup_Collection else Enquote_Literal(g_Lookup_Collection) end;
	END;

	FUNCTION Get_Constraints_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Constraints_Collection else Enquote_Literal(g_Constraints_Collection) end;
	END;


	FUNCTION Get_Filter_Cond_Collection(p_Enquote VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Enquote = 'NO' then g_Filter_Cond_Collection else Enquote_Literal(g_Filter_Cond_Collection) end;
	END;

	FUNCTION Highlight_Search (
		p_Data VARCHAR2,
		p_Search VARCHAR2
	) RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		RETURN REGEXP_REPLACE(p_Data, '(.*)(' || p_Search || ')(.*)',
				'\1<span style="font-weight: bold; color: red;">\2</span>\3', 1, 1, 'i');
	END Highlight_Search;

	-----------------------------------

    FUNCTION Compare_Data ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
		return NVL(SUBSTR(p_Bevore, 1, g_ChangeLogTextLimit), CHR(1)) != NVL(SUBSTR(p_After, 1, g_ChangeLogTextLimit), CHR(1));
    END Compare_Data;

    FUNCTION Compare_Upper ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
		return NVL(UPPER(SUBSTR(p_Bevore, 1, g_ChangeLogTextLimit)), CHR(1)) != NVL(UPPER(SUBSTR(p_After, 1, g_ChangeLogTextLimit)), CHR(1));
    END Compare_Upper;

    FUNCTION Compare_Number ( p_Bevore NUMBER, p_After NUMBER) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
    	return p_Bevore != p_After
    	or p_Bevore IS NOT NULL and p_After IS NULL
    	or p_Bevore IS NULL and p_After IS NOT NULL;
    END Compare_Number;

    FUNCTION Compare_Date ( p_Bevore DATE, p_After DATE) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
    	return p_Bevore != p_After
    	or p_Bevore IS NOT NULL and p_After IS NULL
    	or p_Bevore IS NULL and p_After IS NOT NULL;
    END Compare_Date;

    FUNCTION Compare_Timestamp ( p_Bevore TIMESTAMP WITH LOCAL TIME ZONE, p_After TIMESTAMP WITH LOCAL TIME ZONE) RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
    	return p_Bevore != p_After
    	or p_Bevore IS NOT NULL and p_After IS NULL
    	or p_Bevore IS NULL and p_After IS NOT NULL;
    END Compare_Timestamp;

    FUNCTION Compare_Blob ( p_Old_Blob BLOB, p_New_Blob BLOB)  RETURN BOOLEAN DETERMINISTIC
    IS
    BEGIN
        RETURN p_Old_Blob IS NOT NULL AND p_New_Blob IS NULL
            OR p_Old_Blob IS NULL AND p_New_Blob IS NOT NULL
            OR p_Old_Blob IS NOT NULL AND p_New_Blob IS NOT NULL
                AND DBMS_LOB.COMPARE (p_Old_Blob, p_New_Blob) != 0;
    END Compare_Blob;

    FUNCTION Compare_Clob ( p_Old_Blob CLOB, p_New_Blob CLOB) RETURN BOOLEAN DETERMINISTIC
	IS
    BEGIN
        RETURN p_Old_Blob IS NOT NULL AND p_New_Blob IS NULL
            OR p_Old_Blob IS NULL AND p_New_Blob IS NOT NULL
            OR p_Old_Blob IS NOT NULL AND p_New_Blob IS NOT NULL AND DBMS_LOB.COMPARE(p_Old_Blob,p_New_Blob) != 0;
    END Compare_Clob;

    FUNCTION Get_CompareFunction( p_DATA_TYPE VARCHAR2, p_Compare_Case_Insensitive VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN CASE
        when p_DATA_TYPE IN ('CHAR', 'VARCHAR', 'VARCHAR2', 'CLOB', 'NCLOB') and p_Compare_Case_Insensitive = 'YES' then
        	'data_browser_conf.Compare_Upper'
        when p_DATA_TYPE = 'NUMBER' then
            'data_browser_conf.Compare_Number'
        when p_DATA_TYPE = 'RAW' then
            'data_browser_conf.Compare_Data'
        when p_DATA_TYPE = 'FLOAT' then
            'data_browser_conf.Compare_Number'
        when p_DATA_TYPE = 'DATE' then
            'data_browser_conf.Compare_Date'
        when p_DATA_TYPE = 'BLOB' then
            'data_browser_conf.Compare_Blob'
        when p_DATA_TYPE IN ('CLOB', 'NCLOB') then
            'data_browser_conf.Compare_Clob'
        when p_DATA_TYPE LIKE 'TIMESTAMP%' then
            'data_browser_conf.Compare_Timestamp'
        else
            'data_browser_conf.Compare_Data'
        end;
    END Get_CompareFunction;
	-----------------------------------
	FUNCTION Style_Data (p_Bevore_Exists BOOLEAN, p_After_Exists BOOLEAN, p_Column_Data VARCHAR2, p_Key VARCHAR2) RETURN VARCHAR2
    IS
    	v_Bevore_Exists BOOLEAN := case when p_Key IS NOT NULL then p_Bevore_Exists else p_After_Exists end;
    	v_After_Exists BOOLEAN := case when p_Key IS NOT NULL then p_After_Exists else p_Bevore_Exists end;
    BEGIN
		return case when v_Bevore_Exists and v_After_Exists then
			'<div style="'
			|| g_Compare_Return_Style || '">'	-- updated 
			|| p_Column_Data  || '</div>'
		when NOT(v_Bevore_Exists) and v_After_Exists then
			'<div style="'
			|| g_Compare_Return_Style2 || '">'	-- inserted
			|| p_Column_Data || '</div>'
		else
			'<div style="'
			|| g_Compare_Return_Style3 || '">'	-- deleted
			|| p_Column_Data  || '</div>'
		end;
    END Style_Data;

    FUNCTION Markup_Data ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Data(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Data;

    FUNCTION Markup_Upper ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Upper(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Upper;

    FUNCTION Markup_Number ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore NUMBER, p_After NUMBER) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Number(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Number;

    FUNCTION Markup_Date ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore DATE, p_After DATE) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Date(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Date;

    FUNCTION Markup_Blob ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore BLOB, p_After BLOB) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Blob(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Blob;

    FUNCTION Markup_Clob ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore CLOB, p_After CLOB) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Clob(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Clob;

    FUNCTION Markup_Timestamp ( p_Data VARCHAR2, p_Key VARCHAR2, p_Bevore TIMESTAMP WITH LOCAL TIME ZONE, p_After TIMESTAMP WITH LOCAL TIME ZONE) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	if Compare_Timestamp(p_Bevore, p_After) then
    		return Style_Data(p_Bevore IS NOT NULL, p_After IS NOT NULL, p_Data, p_Key);
    	end if;
		return p_Data;
    END Markup_Timestamp;

    FUNCTION Get_Markup_Function( p_DATA_TYPE VARCHAR2, p_Compare_Case_Insensitive VARCHAR2 DEFAULT 'NO') RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN CASE
        when p_DATA_TYPE = 'NUMBER' then
            'data_browser_conf.Markup_Number'
        when p_DATA_TYPE = 'RAW' then
            'data_browser_conf.Markup_Data'
        when p_DATA_TYPE = 'FLOAT' then
            'data_browser_conf.Markup_Number'
        when p_DATA_TYPE = 'DATE' then
            'data_browser_conf.Markup_Date'
        when p_DATA_TYPE = 'BLOB' then
            'data_browser_conf.Markup_Blob'
        when p_DATA_TYPE IN ('CLOB', 'NCLOB') then
            'data_browser_conf.Markup_Clob'
        when p_DATA_TYPE LIKE 'TIMESTAMP%' then
            'data_browser_conf.Markup_Timestamp'
        when p_DATA_TYPE IN ('CHAR', 'VARCHAR', 'VARCHAR2', 'CLOB', 'NCLOB') and p_Compare_Case_Insensitive = 'YES' then
        	'data_browser_conf.Markup_Upper'
        else
            'data_browser_conf.Markup_Data'
        end;
    END Get_Markup_Function;

	-----------------------------------
	FUNCTION First_Element (str VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
	IS -- return first element of comma delimited list as native column name
	PRAGMA UDF;
		v_Offset PLS_INTEGER := INSTR(str, ',');
		v_trim_set CONSTANT VARCHAR2(10) := ' _%';
	BEGIN
		return case when v_Offset > 0 then LTRIM(RTRIM(SUBSTR(str, 1, v_Offset-1), v_trim_set), v_trim_set) else str end;
	END First_Element;

	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ', '
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
    END Concat_List;

	FUNCTION Get_Encrypt_Function RETURN VARCHAR2 IS BEGIN RETURN g_Encrypt_Function; END;

    FUNCTION Get_Encrypt_Function(p_Key_Column VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Encrypt_Function || '(' || p_Key_Column || ', ' || p_Column_Name || ')'; END;
    
    FUNCTION Get_Hash_Function(p_Key_Column VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Hash_Function || '(' || p_Key_Column || ', ' || p_Column_Name || ')'; END;

	FUNCTION Display_Schema_Name(p_Schema_Name VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
	IS
	BEGIN
		RETURN case when INSTR(p_Schema_Name, '_') > 0 OR LENGTH(p_Schema_Name) > 4 
			then INITCAP(REPLACE(p_Schema_Name, '_', ' ')) else p_Schema_Name 
		end;
	END Display_Schema_Name;

    FUNCTION Normalize_Table_Name (p_Table_Name VARCHAR2)
    RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Result VARCHAR2(4000) := TRANSLATE(p_Table_Name,'$ ', '__');
    BEGIN
		for c_idx IN 1..g_Base_Table_Ext_Field_Array.count loop
			v_Result := REGEXP_REPLACE(v_Result, g_Base_Table_Ext_Field_Array(c_idx) || '$');
		end loop;
		for c_idx IN 1..g_Base_Table_Prefix_Field_Array.count loop
			v_Result := REGEXP_REPLACE(v_Result, '^' || g_Base_Table_Prefix_Field_Array(c_idx));
		end loop;
    	RETURN TRIM('_' FROM v_Result);
    END Normalize_Table_Name;

    FUNCTION Normalize_Column_Name (
    	p_Column_Name VARCHAR2,
    	p_Remove_Extension VARCHAR2 DEFAULT 'YES',
    	p_Remove_Prefix VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Result VARCHAR2(4000);
		v_Result2 VARCHAR2(4000);
		v_Pos PLS_INTEGER;
	BEGIN
		v_Result := p_Column_Name;
		if g_Detect_Column_Prefix = 'YES' and p_Remove_Prefix IS NOT NULL then
			v_Result := REGEXP_REPLACE(v_Result, p_Remove_Prefix || '(.*)$', '\1');
		end if;
		v_Result := TRIM('_' FROM v_Result);
		if p_Remove_Extension = 'YES' then
			v_Result2 := '_' || v_Result;
			for c_idx IN 1..g_Key_Column_Ext_Field_Array.count loop
				if INSTR(v_Result2, g_Key_Column_Ext_Field_Array(c_idx)) > 1 then
					v_Result2 := REGEXP_REPLACE(v_Result2, g_Key_Column_Ext_Pat_Array(c_idx), '\1\2'); -- remove ending _ID2
				end if;
			end loop;
			v_Result := TRIM('_' FROM v_Result2);
		end if;
		return v_Result;
	END Normalize_Column_Name;

	FUNCTION Translate_Umlaute(p_Text VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
	IS
		v_Result VARCHAR2(32767);
	BEGIN
		if g_Translate_Umlaute = 'YES' 
		-- and NVL(APEX_UTIL.GET_SESSION_LANG, 'de') LIKE 'de%' 
		then
			v_Result :=
				REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p_Text,
				'ae', chr(50084)),
				'ueh', chr(50108)||'h'),
				'uef', chr(50108)||'f'),
				'ueg', chr(50108)||'g'),
				'ueb', chr(50108)||'b'),
				'uec', chr(50108)||'c'),
				'uer', chr(50108)||'r'),
				'oe', chr(50102)),
				'Ae', chr(50052)),
				'Ue', chr(50076)),
				'Oe', chr(50070));
			-- the profiler says that this REGEXP_REPLACE is slow:
			-- v_Result := REGEXP_REPLACE(v_Result, '([b|g|f|h|k|l|r|t])(ue)(\w+)', '\1' || chr(50108) || '\3', 1, 1, 'c');
			v_Result :=
				REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(v_Result,
				'bue', 'b' || chr(50108)),
				'gue', 'g' || chr(50108)),
				'fue', 'f' || chr(50108)),
				'hue', 'h' || chr(50108)),
				'kue', 'k' || chr(50108)),
				'lue', 'l' || chr(50108)),
				'rue', 'r' || chr(50108)),
				'tue', 't' || chr(50108));			
			RETURN v_Result;
		else
			RETURN p_Text;
		end if;
	END Translate_Umlaute;

	FUNCTION Normalize_Umlaute(p_Text IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
	IS
	BEGIN
		RETURN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p_Text,
				chr(50084), 'ae'),
				chr(50108), 'ue'),
				chr(50102), 'oe'),
				chr(50052), 'Ae'),
				chr(50076), 'Ue'),
				chr(50070), 'Oe'),
				chr(50079), 'ss'),
				chr(34), chr(39));
	END Normalize_Umlaute;

	FUNCTION Scramble_Umlaute(p_Text IN VARCHAR2) RETURN VARCHAR2
	IS
	PRAGMA UDF;
		l_ulist1 VARCHAR2(20) := 'AEIOUÄÖÜ';
		l_llist1 VARCHAR2(20) := 'aeiouäöü';
		l_ulist2 VARCHAR2(20) := '';
		l_llist2 VARCHAR2(20) := '';
		l_nlist VARCHAR2(20) := '0123456789';
		l_xlist VARCHAR2(20) := 'XXXXXXXXXX';
		i_index		   INTEGER;
	BEGIN
		FOR i_index IN 1..8
		LOOP
			l_ulist2 := l_ulist2 || SUBSTR(l_ulist1, FLOOR(DBMS_RANDOM.VALUE()*8)+1, 1);
			l_llist2 := l_llist2 || SUBSTR(l_llist1, FLOOR(DBMS_RANDOM.VALUE()*8)+1, 1);
		END LOOP;
		return TRANSLATE(p_Text, l_ulist1||l_llist1||l_nlist, l_ulist2||l_llist2||l_xlist);
	END Scramble_Umlaute;

	FUNCTION Get_Obfuscate_Call(p_Text IN VARCHAR2) RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		return 'Data_Browser_Conf.Scramble_Umlaute(' || p_Text || ')';
	END Get_Obfuscate_Call;

	FUNCTION Get_Formated_User_Name(p_Text IN VARCHAR2) RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		return 'INITCAP(' || p_Text || ')';
	END Get_Formated_User_Name;

    FUNCTION Table_Name_To_Header (p_Table_Name VARCHAR2)
    RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN Translate_Umlaute(INITCAP(REPLACE(Normalize_Table_Name(p_Table_Name), '_', ' ')));
    END Table_Name_To_Header;

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
        RETURN RTRIM(SUBSTR(v_Table_Name, 1, GREATEST(v_Half_Length - 1, p_Max_Length - 1 - LENGTH(v_Column_Name))), '_') || '_'
           ||  RTRIM(SUBSTR(v_Column_Name, 1, GREATEST(v_Half_Length, p_Max_Length - 1 - LENGTH(v_Table_Name))), '_');
    END Compose_Table_Column_Name;

    FUNCTION LOV_Initcap (
    	p_Column_Value VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
	BEGIN
		RETURN INITCAP(REPLACE(p_Column_Value, '_', ' '));
	END LOV_Initcap;

    FUNCTION Column_Name_to_Header (
    	p_Column_Name VARCHAR2,
    	p_Remove_Extension VARCHAR2 DEFAULT 'YES',
    	p_Remove_Prefix VARCHAR2 DEFAULT NULL,
    	p_Is_Upper_Name VARCHAR2 DEFAULT 'NO'
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Column_Name VARCHAR2(256);
	BEGIN
		v_Column_Name := Normalize_Column_Name(
			p_Column_Name => p_Column_Name,
			p_Remove_Extension => p_Remove_Extension,
			p_Remove_Prefix => p_Remove_Prefix
		);
		if p_Is_Upper_Name IN ('YES', 'Y') then
			RETURN Translate_Umlaute(UPPER(REPLACE(v_Column_Name, '_', ' ')));
		else
			RETURN Translate_Umlaute(INITCAP(REPLACE(v_Column_Name, '_', ' ')));
		end if;
	END Column_Name_to_Header;

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
	    RETURN RTRIM(SUBSTR(p_First_Name, 1, GREATEST(v_Half_Length - 1, p_Max_Length - 1 - LENGTH(p_Second_Name))), '_') || '_'
    	   ||  RTRIM(SUBSTR(p_Second_Name, 1, GREATEST(v_Half_Length, p_Max_Length - 1 - LENGTH(p_First_Name))), '_');
    END Compose_Column_Name;

    FUNCTION Compose_3Column_Names (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Third_Name VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
	BEGIN
		return data_browser_conf.Compose_Column_Name(
			p_First_Name => p_First_Name
			, p_Second_Name=> data_browser_conf.Compose_Column_Name(
				p_First_Name => p_Second_Name,
				p_Second_Name => p_Third_Name,
				p_Deduplication => 'YES', p_Max_Length => p_Max_Length)
			, p_Deduplication=>'NO', p_Max_Length=> p_Max_Length);
    END Compose_3Column_Names;

    FUNCTION Compose_FK_Column_Table_Name (
    	p_First_Name VARCHAR2,
    	p_Second_Name VARCHAR2,
    	p_Table_Name VARCHAR2,
    	p_Remove_Prefix VARCHAR2,
    	p_Max_Length NUMBER DEFAULT 30
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
	BEGIN
		return data_browser_conf.Compose_Column_Name (
			p_First_Name => NVL(p_First_Name, data_browser_conf.Normalize_Table_Name(p_Table_Name => p_Table_Name)),
			p_Second_Name => p_Second_Name,
			p_Deduplication => 'YES',
			p_Max_Length => p_Max_Length
		);
    END Compose_FK_Column_Table_Name;

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


	FUNCTION Int_Use_Goup_Separator(
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Use_Group_Separator VARCHAR2 DEFAULT 'Y')
	RETURN VARCHAR2 DETERMINISTIC
	IS
    	v_Data_Precision CONSTANT PLS_INTEGER := NVL(p_Data_Precision, numbers_utl.g_Default_Data_Precision);
    	v_Data_Scale CONSTANT PLS_INTEGER := NVL(p_Data_Scale, numbers_utl.g_Default_Data_Scale);
	BEGIN
		if p_Use_Group_Separator = 'N' then 
			return 'N';
		end if;
		if v_Data_Precision - v_Data_Scale < 4 then -- small number less than 1000 
			return 'N';
		end if;
    	RETURN case when ((v_Data_Scale > 0 and g_Decimal_Goup_Separator = 'YES')
			  or (v_Data_Scale = 0 and g_Integer_Goup_Separator = 'YES'))
				then 'Y' else 'N' 
		end;
    END;


	FUNCTION Get_Number_Format_Mask (
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Use_Group_Separator VARCHAR2 DEFAULT 'Y',
		p_Export VARCHAR2 DEFAULT 'Y',		-- use TM9
		p_Use_Trim VARCHAR2 DEFAULT 'N'		-- use FM
	)
	RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		RETURN numbers_utl.Get_Number_Format_Mask (
			p_Data_Precision => p_Data_Precision,
			p_Data_Scale => p_Data_Scale,
			p_Use_Group_Separator => Int_Use_Goup_Separator(p_Data_Precision, p_Data_Scale, p_Use_Group_Separator),
			p_Export => p_Export,
			p_Use_Trim => p_Use_Trim
		);
    END Get_Number_Format_Mask;

    FUNCTION Get_Column_Expr_Type (
    	p_Column_Name IN VARCHAR2,
		p_Data_type IN VARCHAR2,
		p_Char_Length IN NUMBER,
        p_Is_Readonly VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Is_ReadOnly BOOLEAN := FALSE;
		v_Is_Hidden BOOLEAN := FALSE;
	BEGIN
		if p_Is_Readonly IS NOT NULL then
			v_Is_ReadOnly := p_Is_Readonly IN ('Y', 'YES');
		else
			v_Is_ReadOnly := data_browser_conf.Match_ReadOnly_Columns(p_Column_Name) = 'YES';
		end if;
		RETURN case
			when v_Is_ReadOnly then
				'DISPLAY_AND_SAVE'	-- keep data in hidden field for check constraints
			when p_Data_type = 'DATE' OR p_Data_type LIKE 'TIMESTAMP%' then
				'DATE_POPUP'
			when p_Char_Length > g_TextArea_Max_Length OR p_Data_type IN ('CLOB', 'NCLOB') then
								-- technical limit for apex_item_ref
				'TEXT_EDITOR' 	-- a link to edit the text is rendered in edit mode
			when p_Char_Length > g_TextArea_Min_Length then
				'TEXTAREA'
			when p_Data_type IN ('NUMBER', 'FLOAT') then
				'NUMBER'
			when p_Data_type IN ('VARCHAR2', 'VARCHAR', 'NVARCHAR2', 'CHAR', 'NCHAR', 'RAW') then
				'TEXT'
			when p_Data_type = 'BLOB' then
				'DISPLAY_ONLY'
			else
				'DISPLAY_ONLY'
			end;
	END Get_Column_Expr_Type;

    FUNCTION Get_ExportColFunction (
        p_Column_Name VARCHAR2,
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Char_Length NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Use_Trim VARCHAR2 DEFAULT 'Y',	-- trim leading spaces from formated numbers; trim text to limit
        p_Datetime VARCHAR2 DEFAULT NULL, 	-- Y,N
        p_use_NLS_params VARCHAR2 DEFAULT 'Y'
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Column_Name VARCHAR2(128);
		v_Trimset VARCHAR2(10);
		v_Export_Text_Limit PLS_INTEGER;
		v_Use_Group_Separator VARCHAR2(10);
		v_Format_Mask VARCHAR2(1024);
		v_Result VARCHAR2(1024);
	BEGIN
		v_Use_Group_Separator := Int_Use_Goup_Separator(p_Data_Precision, p_Data_Scale, p_Use_Group_Separator);
		
        case
        when p_Data_Type = 'NUMBER' AND p_Data_Precision IS NULL and p_Data_Scale IS NULL and v_Use_Group_Separator = 'Y' then 
        	v_Result := 'FN_NUMBER_TO_CHAR(' || p_Column_Name || ')';
        when p_Data_Type = 'NUMBER' AND (p_Data_Scale > 0 or v_Use_Group_Separator = 'Y') then
        	v_Format_Mask := Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale, v_Use_Group_Separator, p_Export => 'Y', p_Use_Trim => p_Use_Trim);
            v_Result := 'TO_CHAR(' || p_Column_Name || ', '
            || Enquote_Literal(v_Format_Mask)
            || case when p_use_NLS_params = 'Y' then ', ' || Get_Export_NumChars end
            || ')';
        when p_Data_Type = 'NUMBER' AND NULLIF(p_Data_Scale, 0) IS NULL then
        	if p_Data_Precision < 4 then 
        		v_Result := 'TO_CHAR(' || p_Column_Name || ')';
        	else
				v_Result := 'TO_CHAR(' || p_Column_Name || ', '
				|| Enquote_Literal('TM9')
				|| ')';
            end if;
        when p_Data_Type = 'FLOAT' AND p_Data_Scale IS NOT NULL then
        	v_Format_Mask := Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale, v_Use_Group_Separator, p_Export => 'Y', p_Use_Trim => p_Use_Trim);
            v_Result := 'TO_CHAR(' || p_Column_Name || ', '
            || Enquote_Literal(v_Format_Mask)
            || case when p_use_NLS_params = 'Y' then ', ' || Get_Export_NumChars end
            || ')';
        when p_Data_Type = 'FLOAT' then
            v_Format_Mask := Get_Number_Format_Mask(numbers_utl.g_Default_Data_Precision, null, v_Use_Group_Separator, p_Export => 'Y', p_Use_Trim => p_Use_Trim);
            v_Result := 'TO_CHAR(' || p_Column_Name || ', '
            || Enquote_Literal(v_Format_Mask)
            || case when p_use_NLS_params = 'Y' then ', ' || Get_Export_NumChars end
            || ')';
        when p_Data_Type = 'RAW' then
            v_Result := 'RAWTOHEX(' || p_Column_Name || ')';
        when p_Data_type = 'BLOB' then
            v_Result := 'TO_CHAR(DBMS_LOB.GETLENGTH(' || p_Column_Name || '))';
        when p_Data_Type = 'DATE' AND p_Datetime = 'Y' then
            v_Result := 'TO_CHAR(' 
            || p_Column_Name
            || ', ' || Enquote_Literal(Get_Export_DateTime_Format) 
            || ')';
        when p_Data_Type = 'DATE' then
            v_Result := 'TO_CHAR(' 
            || p_Column_Name
            || case when g_Use_App_Date_Time_Format = 'NO' then ', ' || Enquote_Literal(g_Export_Date_Format) end
            || ')';
        when p_Data_Type LIKE 'TIMESTAMP%' AND p_Datetime = 'Y' then
            v_Result := 'TO_CHAR(' || p_Column_Name 
            || ', ' || Enquote_Literal(Get_Timestamp_Format(p_Is_DateTime => p_Datetime)) || ')';
        when p_Data_Type LIKE 'TIMESTAMP%' then
            v_Result := 'TO_CHAR(' || p_Column_Name 
            || case when g_Use_App_Date_Time_Format = 'NO' then ', ' || Enquote_Literal(g_Export_Timestamp_Format) end
            || ')';
        else 
			v_Result := p_Column_Name;
        	if p_Use_Trim = 'Y' then 
				v_Export_Text_Limit := LEAST(g_Export_Text_Limit, g_TextArea_Max_Length); -- technical limit for apex_item_ref
				if p_Char_Length > v_Export_Text_Limit OR p_Data_Type IN ('CLOB', 'NCLOB') then
					v_Result := 'CAST(' || p_Column_Name || ' AS VARCHAR2(' || v_Export_Text_Limit || '))';
				end if;
			end if;
		end case;
        return v_Result;
    END Get_ExportColFunction;

    FUNCTION Get_Field_Length (
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Char_Length NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Datetime VARCHAR2 DEFAULT 'N' -- Y,N
    ) RETURN NUMBER DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Export_Text_Limit CONSTANT PLS_INTEGER := LEAST(g_Export_Text_Limit, g_TextArea_Max_Length); -- technical limit for apex_item_ref
	BEGIN
        RETURN case
        when p_Data_Type = 'NUMBER' then
            LENGTH(Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale, p_Use_Group_Separator, p_Export => 'N', p_Use_Trim => 'N'))
		when p_Data_Type = 'FLOAT' AND p_Data_Scale IS NOT NULL then
            LENGTH(Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale, p_Use_Group_Separator, p_Export => 'N', p_Use_Trim => 'N'))
        when p_Data_Type = 'FLOAT' then
        	numbers_utl.g_Default_Data_Precision
        when p_Data_type = 'BLOB' then
        	38	-- number length of blob
        when p_Datetime = 'Y' then
            LENGTH(Get_Export_DateTime_Format)
        when p_Data_Type = 'DATE' then
        	LENGTH(Get_Export_Date_Format)
        when p_Data_Type LIKE 'TIMESTAMP%' then
            LENGTH(Get_Timestamp_Format(p_Is_DateTime => p_Datetime))
        when  p_Char_Length > g_Export_Text_Limit OR p_Data_Type IN ('CLOB', 'NCLOB') then
            g_Export_Text_Limit
        else
            NVL(p_Char_Length, 64)
        end;
    END Get_Field_Length;

    FUNCTION Get_Col_Format_Mask (
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Char_Length NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Datetime VARCHAR2 DEFAULT NULL -- Y,N
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
		v_Column_Name VARCHAR2(128);
	BEGIN
        RETURN case
        when p_Data_Type = 'NUMBER' then
            Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale, p_Use_Group_Separator, p_Export => 'N')
        when p_Data_Type = 'FLOAT' and p_Data_Scale IS NOT NULL then -- Currency 
            Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale, p_Use_Group_Separator, p_Export => 'N')
        when p_Data_Type = 'FLOAT' then
        	Get_Number_Format_Mask(numbers_utl.g_Default_Data_Precision, null, p_Use_Group_Separator, p_Export => 'N') -- g_Export_Float_Format
        when p_Data_Type = 'DATE'  and p_Datetime = 'Y' then
            Get_Export_DateTime_Format
        when p_Data_Type = 'DATE' then
        	Get_Export_Date_Format
        when p_Data_Type LIKE 'TIMESTAMP%' then
            Get_Timestamp_Format(p_Is_DateTime => p_Datetime)
        else
            NULL
        end;
    END Get_Col_Format_Mask;

    FUNCTION Get_Display_Format_Mask (	-- used to display the format mask in help text.
        p_Format_Mask VARCHAR2,
        p_Data_Type VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
        v_Format_Mask CONSTANT VARCHAR2(255) := case 
			when p_Format_Mask = 'TM9' 
				then Get_Number_Format_Mask(numbers_utl.g_Default_Data_Precision, null, p_Use_Group_Separator => 'Y', p_Export => 'Y')
				else p_Format_Mask
			end;
	BEGIN
        RETURN case
        when p_Data_Type IN ('NUMBER', 'FLOAT') then
            TRANSLATE(v_Format_Mask, 'DG', g_Export_NumChars)
        else v_Format_Mask
        end;
    END Get_Display_Format_Mask;

    FUNCTION Get_Char_to_Type_Expr (
    	p_Element VARCHAR2,
    	p_Element_Type VARCHAR2 DEFAULT 'C', 				-- C,N  = Char/Number
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, COLLECTION, MEMORY, VIEW
        p_Data_Type VARCHAR2,
        p_Data_Scale NUMBER,
        p_Format_Mask VARCHAR2,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_use_NLS_params VARCHAR2 DEFAULT 'Y'
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
        v_Format_Mask CONSTANT VARCHAR2(255) := 
        	case when p_Format_Mask = 'TM9' 
				then Get_Number_Format_Mask(numbers_utl.g_Default_Data_Precision, null, p_Use_Group_Separator => 'Y', p_Export => 'Y')
				else p_Format_Mask
			end;
		v_FN_Prefix CONSTANT VARCHAR2(255) := case when p_Data_Source != 'VIEW' then 'FN_' end;
    BEGIN
    	if p_Element_Type = 'N' and p_Data_Source = 'COLLECTION' then 
    		RETURN p_Element;
    	else 
			RETURN case
			when p_Data_Type = 'NUMBER' and (p_Data_Scale > 0 or p_Use_Group_Separator = 'Y') and v_Format_Mask IS NOT NULL then
				v_FN_Prefix || 'TO_NUMBER(' || p_Element 
				|| ', ' || Enquote_Literal(v_Format_Mask)
				|| case when p_use_NLS_params = 'Y' then ', ' || Get_Export_NumChars end
				|| ')'
			when p_Data_Type = 'FLOAT' and v_Format_Mask IS NOT NULL then
				v_FN_Prefix || 'TO_NUMBER(' || p_Element
				|| ', ' || Enquote_Literal(v_Format_Mask)
				|| case when p_use_NLS_params = 'Y' then ', ' || Get_Export_NumChars end
				|| ')'
			when p_Data_Type IN ('NUMBER', 'FLOAT') then
				'TO_NUMBER(' || p_Element || ')'
			when p_Data_Type = 'RAW' then
				'HEXTORAW(' || p_Element || ')'
			when p_Data_Type = 'DATE' then
				v_FN_Prefix || 'TO_DATE(' || p_Element
				|| case when v_Format_Mask IS NOT NULL then ', ' || Enquote_Literal(v_Format_Mask) end
				|| ')'
			when p_Data_Type IN ('CLOB', 'NCLOB') then
				'TO_CLOB(' || p_Element || ')'
			when p_Data_Type = 'BLOB' then
				'TO_BLOB(' || p_Element || ')'
			when p_Data_Type LIKE 'TIMESTAMP%' then
				'TO_TIMESTAMP(' || p_Element
				|| case when v_Format_Mask IS NOT NULL then ', ' || Enquote_Literal(v_Format_Mask) end
				|| ')'
			else 
				p_Element
			end;
		end if;
    END Get_Char_to_Type_Expr;

	FUNCTION Build_Condition (
		p_Condition VARCHAR2,
		p_Term VARCHAR2,
		p_Add_NL VARCHAR2 DEFAULT 'YES'
	) return varchar2
	is
	begin
		if p_Term IS NULL then
			return p_Condition;
		end if;
		return p_Condition
		|| case when p_Add_NL = 'YES' then chr(10) else ' ' end
		|| case when p_Condition IS NULL then 'WHERE ' else 'AND ' end
		|| p_Term;
	end Build_Condition;

	FUNCTION Build_Parent_Key_Condition (
		p_Condition VARCHAR2,
    	p_Parent_Key_Column VARCHAR2,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2,			-- Page Item Name, Filter Value and default value for foreign key column
    	p_Parent_Key_Visible VARCHAR2,		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Nullable VARCHAR2		-- N, Y
	) return varchar2
	is
	begin -- restrict to set of rows
		return data_browser_conf.Build_Condition(p_Condition,
			case when p_Parent_Key_Item IS NOT NULL and p_Parent_Key_Nullable = 'Y' and p_Parent_Key_Visible = 'NULLABLE' then
					'(' || p_Parent_Key_Column || ' = V(' || data_browser_conf.Enquote_Literal(p_Parent_Key_Item)
					|| ') or ' || p_Parent_Key_Column || ' IS NULL or V(' || data_browser_conf.Enquote_Literal(p_Parent_Key_Item) || ') IS NULL)'
				when p_Parent_Key_Item IS NOT NULL and V(p_Parent_Key_Item) IS NOT NULL and p_Parent_Key_Nullable = 'N'  then
					p_Parent_Key_Column || ' = V(' || data_browser_conf.Enquote_Literal(p_Parent_Key_Item) || ')' 
				when p_Parent_Key_Item IS NOT NULL then
					p_Parent_Key_Column || ' = NVL(V(' || data_browser_conf.Enquote_Literal(p_Parent_Key_Item) || '), ' || p_Parent_Key_Column || ')'
				when p_Parent_Key_Nullable = 'N' or p_Parent_Key_Visible = 'NULLABLE' then
					null
				else
					p_Parent_Key_Column || ' IS NOT NULL'
			end
		);
	end Build_Parent_Key_Condition;

	FUNCTION Get_Include_Query_Schema RETURN VARCHAR2 IS BEGIN RETURN g_Include_Query_Schema; END;
	PROCEDURE Set_Include_Query_Schema (p_Value VARCHAR2) IS BEGIN g_Include_Query_Schema := p_Value; END;

	FUNCTION Do_Compare_Case_Insensitive RETURN VARCHAR2 IS BEGIN RETURN g_Compare_Case_Insensitive; END;

    FUNCTION Get_Compare_Case_Insensitive (
        p_Column_Name VARCHAR2,
    	p_Element VARCHAR2,
    	p_Element_Type VARCHAR2 DEFAULT 'C', 	-- C,N  = CHar/Number
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', -- NEW_ROWS, TABLE, COLLECTION, MEMORY
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Format_Mask VARCHAR2,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'N',
        p_Compare_Case_Insensitive VARCHAR2 DEFAULT Do_Compare_Case_Insensitive
    ) RETURN VARCHAR2
    IS
		v_use_NLS_params 	CONSTANT VARCHAR2(1) := 'Y'; -- case when p_Data_Source = 'COLLECTION' then 'Y' else 'N' end
    BEGIN
        RETURN case when p_Compare_Case_Insensitive = 'YES' and p_Data_Type IN ('CHAR', 'VARCHAR2', 'NVARCHAR2', 'CLOB', 'NCLOB')
            then 'UPPER(' || p_Column_Name || ') = UPPER(' || p_Element || ')'
            else p_Column_Name
            	|| ' = '
            	|| data_browser_conf.Get_Char_to_Type_Expr (
						p_Element 		=> p_Element,
						p_Data_Type 	=> p_Data_Type,
						p_Element_Type	=> p_Element_Type,
						p_Data_Source	=> p_Data_Source,
						p_Data_Scale 	=> p_Data_Scale,
						p_Format_Mask 	=> p_Format_Mask,
						p_Use_Group_Separator => p_Use_Group_Separator,
						p_use_NLS_params => v_use_NLS_params
					)
            end;
    END Get_Compare_Case_Insensitive;

	FUNCTION Get_Search_Keys_Unique RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN RETURN g_Search_Keys_Unique; END;

	FUNCTION Get_Insert_Foreign_Keys RETURN VARCHAR2 IS BEGIN RETURN g_Insert_Foreign_Keys; END;
	PROCEDURE Set_Import_Parameter (
		p_Compare_Case_Insensitive	VARCHAR2 DEFAULT 'NO',
		p_Search_Keys_Unique 	VARCHAR2 DEFAULT 'NO',
		p_Insert_Foreign_Keys 	VARCHAR2 DEFAULT 'NO'
	)
	IS 
		v_Compare_Case_Insensitive	VARCHAR2(10);
		v_Search_Keys_Unique		VARCHAR2(10);
		v_Insert_Foreign_Keys		VARCHAR2(10);
	BEGIN 
		v_Compare_Case_Insensitive 	:= COALESCE( p_Compare_Case_Insensitive, data_browser_conf.Do_Compare_Case_Insensitive, 'NO');
		v_Search_Keys_Unique		:= COALESCE( p_Search_Keys_Unique, data_browser_conf.Get_Search_Keys_Unique, 'NO');
		v_Insert_Foreign_Keys		:= COALESCE( p_Insert_Foreign_Keys, data_browser_conf.Get_Insert_Foreign_Keys, 'NO');
		
		APEX_UTIL.SET_PREFERENCE(V('OWNER') || ':' || 'IMPORT_PREFS', 
			apex_string.format('%s:%s:%s', v_Compare_Case_Insensitive, v_Search_Keys_Unique, v_Insert_Foreign_Keys));
	END Set_Import_Parameter;

	PROCEDURE Get_Import_Parameter (
		p_Compare_Case_Insensitive	OUT VARCHAR2,
		p_Search_Keys_Unique 	OUT VARCHAR2,
		p_Insert_Foreign_Keys 	OUT VARCHAR2
	)
	IS 
		v_Prefs_Array apex_t_varchar2;
		v_Preferences	VARCHAR2(512);
	BEGIN 
		v_Preferences := APEX_UTIL.GET_PREFERENCE(V('OWNER') || ':' || 'IMPORT_PREFS');
		if v_Preferences IS NOT NULL then 
			v_Prefs_Array := apex_string.split(v_Preferences, ':');
			p_Compare_Case_Insensitive := v_Prefs_Array(1);
			p_Search_Keys_Unique := v_Prefs_Array(2);
			p_Insert_Foreign_Keys := v_Prefs_Array(3);
		else 
			p_Compare_Case_Insensitive := data_browser_conf.Do_Compare_Case_Insensitive;
			p_Search_Keys_Unique := data_browser_conf.Get_Search_Keys_Unique;
			p_Insert_Foreign_Keys := data_browser_conf.Get_Insert_Foreign_Keys;
		end if;
	END Get_Import_Parameter;

	FUNCTION Strip_Comments ( p_Text VARCHAR2 ) RETURN VARCHAR2
	IS
	PRAGMA UDF;
		v_trim_set VARCHAR2(20) := CHR(32)||CHR(10)||CHR(13)||CHR(9);
	BEGIN
		RETURN REGEXP_REPLACE(LTRIM(RTRIM(REGEXP_REPLACE(
								REGEXP_REPLACE(p_Text, '--.*$', NULL, 1, 1, 'm'), '--.*$')
								, v_trim_set)
						, v_trim_set
					), '\s+', ' ');	-- remove newlines and spaces. Important for the usage in expressions and messages
	END Strip_Comments;

	FUNCTION Get_ConstraintText (p_Table_Name VARCHAR2, p_Owner VARCHAR2, p_Constraint_Name VARCHAR2) RETURN VARCHAR2
	IS
		v_Search_Condition VARCHAR2(4000);
	BEGIN
		if p_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
			SELECT C.SEARCH_CONDITION
			INTO v_Search_Condition
			FROM SYS.USER_CONSTRAINTS C
			WHERE C.TABLE_NAME = p_Table_Name
			AND C.OWNER = p_Owner
			AND C.CONSTRAINT_NAME = p_Constraint_Name;
		else
			SELECT C.SEARCH_CONDITION
			INTO v_Search_Condition
			FROM SYS.ALL_CONSTRAINTS C
			WHERE C.TABLE_NAME = p_Table_Name
			AND C.OWNER = p_Owner
			AND C.CONSTRAINT_NAME = p_Constraint_Name;
		end if;
		RETURN data_browser_conf.Strip_Comments (v_Search_Condition);
	EXCEPTION
	WHEN NO_DATA_FOUND THEN
		return NULL;
	END Get_ConstraintText;

	FUNCTION Constraint_Condition_Cursor (
		p_Table_Name IN VARCHAR2 DEFAULT NULL,
		p_Owner IN VARCHAR2 DEFAULT NULL,
		p_Constraint_Name IN VARCHAR2 DEFAULT NULL
	) RETURN data_browser_conf.tab_constraint_condition PIPELINED PARALLEL_ENABLE
	is
		v_out_rec data_browser_conf.rec_constraint_condition;
        v_Schema_Name CONSTANT VARCHAR2(50) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		v_Search_Condition VARCHAR2(4000);
		CURSOR user_cons_cur
		IS
			SELECT /*+ RESULT_CACHE */
				C.OWNER, C.TABLE_NAME, C.CONSTRAINT_NAME, C.SEARCH_CONDITION
			FROM SYS.USER_CONSTRAINTS C
			WHERE C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
			AND C.OWNER = NVL(p_Owner, C.OWNER)
			AND C.CONSTRAINT_NAME = NVL(p_Constraint_Name, C.CONSTRAINT_NAME)
			AND C.CONSTRAINT_TYPE = 'C' -- check constraint
			AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
			;
		CURSOR all_cons_cur
		IS
			SELECT /*+ RESULT_CACHE */
				C.OWNER, C.TABLE_NAME, C.CONSTRAINT_NAME, C.SEARCH_CONDITION
			FROM SYS.ALL_CONSTRAINTS C
			WHERE C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
			AND C.OWNER = NVL(p_Owner, C.OWNER)
			AND C.CONSTRAINT_NAME = NVL(p_Constraint_Name, C.CONSTRAINT_NAME)
			AND C.CONSTRAINT_TYPE = 'C' -- check constraint
			AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
			AND C.OWNER NOT IN ('SYS', 'SYSTEM', 'SYSAUX', 'CTXSYS', 'MDSYS', 'OUTLN')
			;
		TYPE tables_tbl2 IS TABLE OF all_cons_cur%ROWTYPE;
		v_in_rows 	tables_tbl2;
	begin
		if g_App_Installation_Code IS NULL then 
			return; -- not initialised (during create mview)
		end if;
		if p_Owner = v_Schema_Name then 
			OPEN user_cons_cur;
			LOOP
				FETCH user_cons_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					v_Search_Condition			:= SUBSTR(v_in_rows(ind).SEARCH_CONDITION, 1, 4000);
					v_out_rec.OWNER 			:= v_in_rows(ind).OWNER;
					v_out_rec.TABLE_NAME 		:= v_in_rows(ind).TABLE_NAME;
					v_out_rec.CONSTRAINT_NAME 	:= v_in_rows(ind).CONSTRAINT_NAME;
					v_out_rec.SEARCH_CONDITION 	:= data_browser_conf.Strip_Comments (v_Search_Condition);
					if v_out_rec.SEARCH_CONDITION IS NOT NULL then
						pipe row (v_out_rec);
					end if;
				END LOOP;
			END LOOP;
			CLOSE user_cons_cur;
		else
			OPEN all_cons_cur;
			LOOP
				FETCH all_cons_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					v_Search_Condition			:= SUBSTR(v_in_rows(ind).SEARCH_CONDITION, 1, 4000);
					v_out_rec.OWNER 			:= v_in_rows(ind).OWNER;
					v_out_rec.TABLE_NAME 		:= v_in_rows(ind).TABLE_NAME;
					v_out_rec.CONSTRAINT_NAME 	:= v_in_rows(ind).CONSTRAINT_NAME;
					v_out_rec.SEARCH_CONDITION 	:= data_browser_conf.Strip_Comments (v_Search_Condition);
					if v_out_rec.SEARCH_CONDITION IS NOT NULL then
						pipe row (v_out_rec);
					end if;
				END LOOP;
			END LOOP;
			CLOSE all_cons_cur;
		end if;
	end Constraint_Condition_Cursor;

	FUNCTION Constraint_Columns_Cursor (
		p_Table_Name IN VARCHAR2 DEFAULT NULL,
		p_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Constraint_Name IN VARCHAR2 DEFAULT NULL
	) RETURN data_browser_conf.tab_constraint_columns PIPELINED PARALLEL_ENABLE
	is
        v_Schema_Name CONSTANT VARCHAR2(50) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		CURSOR user_cons_cur
		IS
			SELECT /*+ RESULT_CACHE */
				A.OWNER, A.TABLE_NAME, A.COLUMN_NAME, A.POSITION, A.CONSTRAINT_NAME, A.SEARCH_CONDITION
			FROM (
				SELECT /*+ USE_MERGE(B C) */
					C.OWNER, C.TABLE_NAME, B.COLUMN_NAME, B.POSITION, C.CONSTRAINT_NAME, 
					data_browser_conf.Strip_Comments(C.SEARCH_CONDITION_VC) SEARCH_CONDITION
				FROM SYS.USER_CONSTRAINTS C
				JOIN SYS.USER_CONS_COLUMNS B ON C.OWNER = B.OWNER AND C.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND C.TABLE_NAME = B.TABLE_NAME
				WHERE C.CONSTRAINT_TYPE = 'C' -- check constraint
                AND C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
				AND C.OWNER = NVL(p_Owner, C.OWNER)
				AND C.CONSTRAINT_NAME = NVL(p_Constraint_Name, C.CONSTRAINT_NAME)
				AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
				AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
			) A 
			WHERE A.SEARCH_CONDITION NOT IN( DBMS_ASSERT.ENQUOTE_NAME(A.COLUMN_NAME) || ' IS NOT NULL', A.COLUMN_NAME || ' IS NOT NULL') -- filter NOT NULL checks
            ;
        CURSOR all_cons_cur
		IS
			SELECT /*+ RESULT_CACHE */
				A.OWNER, A.TABLE_NAME, A.COLUMN_NAME, A.POSITION, A.CONSTRAINT_NAME, A.SEARCH_CONDITION
			FROM (
				SELECT /*+ USE_MERGE(B C) */
					C.OWNER, C.TABLE_NAME, B.COLUMN_NAME, B.POSITION, C.CONSTRAINT_NAME, 
					data_browser_conf.Strip_Comments(C.SEARCH_CONDITION_VC) SEARCH_CONDITION
				FROM SYS.ALL_CONSTRAINTS C
				JOIN SYS.ALL_CONS_COLUMNS B ON C.OWNER = B.OWNER AND C.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND C.TABLE_NAME = B.TABLE_NAME
				WHERE C.CONSTRAINT_TYPE = 'C' -- check constraint
                AND C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
				AND C.OWNER = NVL(p_Owner, C.OWNER)
				AND C.CONSTRAINT_NAME = NVL(p_Constraint_Name, C.CONSTRAINT_NAME)
				AND C.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
				AND C.TABLE_NAME NOT LIKE 'BIN$%'  -- this table is in the recyclebin
				AND C.OWNER NOT IN ('SYS', 'SYSTEM', 'SYSAUX', 'CTXSYS', 'MDSYS', 'OUTLN')
			) A 
			WHERE A.SEARCH_CONDITION NOT IN( DBMS_ASSERT.ENQUOTE_NAME(A.COLUMN_NAME) || ' IS NOT NULL', A.COLUMN_NAME || ' IS NOT NULL') -- filter NOT NULL checks
            ;
		v_in_rows 	data_browser_conf.tab_constraint_columns;
	begin
		if g_App_Installation_Code IS NULL then 
			return; -- not initialised (during create mview)
		end if;
		if p_Owner = v_Schema_Name then 
			OPEN user_cons_cur;
			LOOP
				FETCH user_cons_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_cons_cur;
		else
			OPEN all_cons_cur;
			LOOP
				FETCH all_cons_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_cons_cur;
		end if;
	end Constraint_Columns_Cursor;

	FUNCTION Table_Columns_Cursor(
    	p_Table_Name VARCHAR2 DEFAULT NULL,
    	p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Column_Name VARCHAR2 DEFAULT NULL
    )
	RETURN data_browser_conf.tab_table_columns PIPELINED PARALLEL_ENABLE
	IS
        CURSOR user_cols_cur
        IS
		SELECT /*+ RESULT_CACHE */
			TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER,
			COLUMN_ID, COLUMN_NAME, DATA_TYPE, NULLABLE, NUM_DISTINCT,
			DEFAULT_LENGTH, DATA_DEFAULT, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH
		FROM SYS.USER_TAB_COLS C
		WHERE C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
		AND C.COLUMN_NAME = NVL(p_Column_Name, C.COLUMN_NAME)
		AND C.HIDDEN_COLUMN = 'NO';

        CURSOR all_cols_cur
        IS
		SELECT /*+ RESULT_CACHE */
			TABLE_NAME, OWNER,
			COLUMN_ID, COLUMN_NAME, DATA_TYPE, NULLABLE, NUM_DISTINCT,
			DEFAULT_LENGTH, DATA_DEFAULT, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH
		FROM SYS.ALL_TAB_COLS C
		WHERE C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME)
		AND C.OWNER = NVL(p_Owner, C.OWNER)
		AND C.COLUMN_NAME = NVL(p_Column_Name, C.COLUMN_NAME)
		AND C.HIDDEN_COLUMN = 'NO';

        TYPE stat_tbl IS TABLE OF user_cols_cur%ROWTYPE;
        v_in_rows stat_tbl;
        v_row rec_table_columns;
	BEGIN
		if p_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then
			OPEN user_cols_cur;
			LOOP
				FETCH user_cols_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit*5;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					v_row.TABLE_NAME 			:= v_in_rows(ind).TABLE_NAME;
					v_row.OWNER 				:= v_in_rows(ind).OWNER;
					v_row.COLUMN_ID 			:= v_in_rows(ind).COLUMN_ID;
					v_row.COLUMN_NAME 			:= v_in_rows(ind).COLUMN_NAME;
					v_row.DATA_TYPE 			:= v_in_rows(ind).DATA_TYPE;
					v_row.NULLABLE 				:= v_in_rows(ind).NULLABLE;
					v_row.NUM_DISTINCT 			:= v_in_rows(ind).NUM_DISTINCT;
					v_row.DEFAULT_LENGTH 		:= v_in_rows(ind).DEFAULT_LENGTH;
					v_row.DEFAULT_TEXT 			:= RTRIM(SUBSTR(TO_CLOB(v_in_rows(ind).DATA_DEFAULT), 1, 800)); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
					v_row.DATA_PRECISION 		:= v_in_rows(ind).DATA_PRECISION;
					v_row.DATA_SCALE 			:= v_in_rows(ind).DATA_SCALE;
					v_row.CHAR_LENGTH 			:= v_in_rows(ind).CHAR_LENGTH;			
					pipe row (v_row);
				END LOOP;
			END LOOP;
			CLOSE user_cols_cur;
		else
			OPEN all_cols_cur;
			LOOP
				FETCH all_cols_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit*5;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					v_row.TABLE_NAME 			:= v_in_rows(ind).TABLE_NAME;
					v_row.OWNER 				:= v_in_rows(ind).OWNER;
					v_row.COLUMN_ID 			:= v_in_rows(ind).COLUMN_ID;
					v_row.COLUMN_NAME 			:= v_in_rows(ind).COLUMN_NAME;
					v_row.DATA_TYPE 			:= v_in_rows(ind).DATA_TYPE;
					v_row.NULLABLE 				:= v_in_rows(ind).NULLABLE;
					v_row.NUM_DISTINCT 			:= v_in_rows(ind).NUM_DISTINCT;
					v_row.DEFAULT_LENGTH 		:= v_in_rows(ind).DEFAULT_LENGTH;
					v_row.DEFAULT_TEXT 			:= RTRIM(SUBSTR(TO_CLOB(v_in_rows(ind).DATA_DEFAULT), 1, 800)); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
					v_row.DATA_PRECISION 		:= v_in_rows(ind).DATA_PRECISION;
					v_row.DATA_SCALE 			:= v_in_rows(ind).DATA_SCALE;
					v_row.CHAR_LENGTH 			:= v_in_rows(ind).CHAR_LENGTH;			
					pipe row (v_row);
				END LOOP;
			END LOOP;
			CLOSE all_cols_cur;
		end if;
	END Table_Columns_Cursor;

	FUNCTION Is_Simple_IN_List (
		p_Check_Condition VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	is
	PRAGMA UDF;
	begin
		return case when REGEXP_INSTR(TRIM(p_Check_Condition), '^' || p_Column_Name || '\s+IN\s*\(.+\)\s*$', 1, 1, 1, 'i') > 0	-- static IN list
			then 'Y' else 'N' end;
	end Is_Simple_IN_List;

	FUNCTION Get_Static_LOV_Expr (
		p_Check_Condition VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	is
	PRAGMA UDF;
		v_Result VARCHAR(4000);
	begin
		SELECT LISTAGG(data_browser_conf.LOV_Initcap(COLUMN_VALUE)
						|| ';' || COLUMN_VALUE, ',') WITHIN GROUP (ORDER BY RN)
		INTO v_Result
		FROM (
			SELECT ROWNUM RN, REGEXP_REPLACE(COLUMN_VALUE, '^''(.*)''$', '\1', 1, 1, 'i') COLUMN_VALUE
			FROM TABLE( data_browser_conf.in_list( -- convert values to rows
					REGEXP_REPLACE(TRIM(p_Check_Condition), p_Column_Name || '\s+IN\s*\((.+)\)\s*$', '\1', 1, 1, 'i')
					, ','
				)
			)
		);
		if v_Result IN ('Y;Y,N;N', 'N;N,Y;Y') then
			return data_browser_conf.Get_Yes_No_Static_LOV('CHAR');
		elsif v_Result IN ('0;0,1;1', '1;1,0;0') then
			return data_browser_conf.Get_Yes_No_Static_LOV('NUMBER');
		else
			return v_Result;
		end if;
	end Get_Static_LOV_Expr;

	FUNCTION Has_ChangeLog_History (p_Table_Name VARCHAR2) RETURN VARCHAR2	-- YES, NO
    IS
    	v_Count PLS_INTEGER;
    	v_Included VARCHAR2(10) := 'NO';
    	v_Query	VARCHAR2(2000);
		cv 		SYS_REFCURSOR;
    BEGIN
    	if g_ChangLog_Enabled_Call IS NOT NULL then
			EXECUTE IMMEDIATE 'begin :result := ' || g_ChangLog_Enabled_Call || '; end;'
			USING OUT v_Included, IN p_Table_Name;
		end if;
		RETURN v_Included;
	exception when others then
		if SQLCODE = -6550 then
			RETURN 'NO';
		end if;
		raise;
    END Has_ChangeLog_History;

    FUNCTION Get_Column_In_List (p_Table_Name VARCHAR2, p_Owner VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Constraint_Text VARCHAR2(32767);
    BEGIN
        if p_Table_Name IS NULL OR p_Column_Name IS NULL then
            return NULL;
        end if;
		SELECT SEARCH_CONDITION
		INTO v_Constraint_Text
		FROM (
			SELECT A.SEARCH_CONDITION,
				COUNT(DISTINCT A.COLUMN_NAME) OVER (PARTITION BY A.TABLE_NAME, A.CONSTRAINT_NAME) CONS_COLS_COUNT,
				COUNT(DISTINCT A.CONSTRAINT_NAME) OVER (PARTITION BY A.TABLE_NAME, A.COLUMN_NAME) CONS_COUNT
			FROM TABLE ( data_browser_conf.Constraint_Columns_Cursor (p_Table_Name, p_Owner) ) A
			WHERE REGEXP_INSTR(SEARCH_CONDITION, COLUMN_NAME || '\s+IN\s*\(.+\)\s*$', 1, 1, 1, 'i') > 0
			AND COLUMN_NAME = p_Column_Name
		)
		WHERE CONS_COLS_COUNT = 1 -- simple constraint references only one column_name
		AND CONS_COUNT = 1;

        RETURN v_Constraint_Text;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return NULL;
    END Get_Column_In_List;

	FUNCTION Table_Column_In_List_Cursor(
    	p_Table_Name VARCHAR2 DEFAULT NULL,
    	p_Owner VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Column_Name VARCHAR2 DEFAULT NULL
    )
	RETURN data_browser_conf.tab_table_column_in_list PIPELINED PARALLEL_ENABLE
	is
        v_Schema_Name CONSTANT VARCHAR2(50) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		CURSOR user_cons_cur
		IS
		SELECT TABLE_NAME, TABLE_OWNER, COLUMN_NAME,
			data_browser_conf.LOV_Initcap(COLUMN_VALUE) DISPLAY_VALUE,
			COLUMN_VALUE,
			ROW_NUMBER() OVER (PARTITION BY TABLE_NAME, COLUMN_NAME ORDER BY RN) DISP_SEQUENCE
		FROM ( -- remove quotes
		   SELECT TABLE_NAME, TABLE_OWNER, COLUMN_NAME, REGEXP_REPLACE(COLUMN_VALUE, '^''(.*)''$', '\1') COLUMN_VALUE,
			ROWNUM RN
			FROM ( -- convert values to rows
				SELECT TABLE_NAME, TABLE_OWNER, COLUMN_NAME, REGEXP_REPLACE(SEARCH_CONDITION_VC, COLUMN_NAME || '\s+IN\s*\((.+)\)\s*$', '\1', 1, 1, 'i') CHECK_IN_LIST
				FROM (
					SELECT B.TABLE_NAME, B.OWNER TABLE_OWNER, B.COLUMN_NAME, B.SEARCH_CONDITION SEARCH_CONDITION_VC
					FROM TABLE ( data_browser_conf.Constraint_Columns_Cursor(p_Table_Name, p_Owner) ) B 
					WHERE B.COLUMN_NAME = NVL(p_Column_Name, B.COLUMN_NAME)
				)
				WHERE REGEXP_INSTR(SEARCH_CONDITION_VC, COLUMN_NAME || '\s+IN\s*\(.+\)\s*$', 1, 1, 1, 'i') > 0
			) S,
			TABLE( data_browser_conf.in_list(S.CHECK_IN_LIST, ',') ) P
		);
		v_in_rows 	data_browser_conf.tab_table_column_in_list;
	begin
		OPEN user_cons_cur;
		LOOP
			FETCH user_cons_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE user_cons_cur;
	end Table_Column_In_List_Cursor;


    FUNCTION Get_ColumnDefaultText (p_Table_Name VARCHAR2, p_Owner VARCHAR2, p_Column_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
        v_Default_Text SYS.ALL_TAB_COLUMNS.DATA_DEFAULT%TYPE;
    BEGIN
        if NOT(p_Table_Name IS NULL OR p_Column_Name IS NULL) then
			if p_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
				SELECT C.DATA_DEFAULT
				INTO v_Default_Text
				FROM SYS.USER_TAB_COLUMNS C
				WHERE C.TABLE_NAME = p_Table_Name
				AND C.COLUMN_NAME = p_Column_Name;
			else
				SELECT C.DATA_DEFAULT
				INTO v_Default_Text
				FROM SYS.ALL_TAB_COLUMNS C
				WHERE C.TABLE_NAME = p_Table_Name
				AND C.OWNER = p_Owner
				AND C.COLUMN_NAME = p_Column_Name;
			end if;
        end if;
        RETURN RTRIM(v_Default_Text, CHR(32)||CHR(10)||CHR(13));
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return NULL;
    END Get_ColumnDefaultText;

    FUNCTION Get_TriggerText (p_Table_Name VARCHAR2, p_Trigger_Name VARCHAR2) RETURN CLOB
    IS
    BEGIN
        FOR C IN (
            SELECT C.TRIGGER_BODY
            FROM USER_TRIGGERS C
            WHERE C.TABLE_NAME = p_Table_Name
            AND C.TRIGGER_NAME = p_Trigger_Name
        )
        LOOP
            RETURN RTRIM(TO_CLOB(C.Trigger_Body), CHR(32)||CHR(10)||CHR(13));
        END LOOP;
        RETURN NULL;
    END Get_TriggerText;

	FUNCTION Get_Apex_Item_Row_Count (	-- item count in apex_application.g_fXX array
		p_Idx 			NUMBER,					-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER DEFAULT 1,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER DEFAULT 1		-- row offset for item index > 50
	) RETURN NUMBER
	is
	$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
		PRAGMA UDF;
	$END
		v_Statement		VARCHAR2(200);
		v_Array_Count	NUMBER;
		v_Row_Count		NUMBER;
	begin
		v_Statement :=
		   'begin :b := apex_application.g_f' || LPAD( p_Idx, 2, '0') ||'.count; end;';
		EXECUTE IMMEDIATE v_Statement USING OUT v_Array_Count;

		v_Row_Count := floor((v_Array_Count + p_Row_Factor - p_Row_Offset) / p_Row_Factor);

		return v_Row_Count;
	end;

    FUNCTION in_list(
    	p_string in clob,
    	p_delimiter in varchar2 DEFAULT ';'
    )
    RETURN sys.odciVarchar2List PIPELINED DETERMINISTIC PARALLEL_ENABLE  -- VARCHAR2(4000)
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
    END in_list;

	FUNCTION replace_agg (
		p_cur data_browser_conf.cur_replace_list
	)
    RETURN sys.odciVarchar2List PIPELINED DETERMINISTIC PARALLEL_ENABLE  -- VARCHAR2(4000)
	IS
		v_row data_browser_conf.rec_replace_list;
		v_result VARCHAR2(4000); -- output row
		v_count PLS_INTEGER := 0;
	BEGIN 
		loop
			FETCH p_cur INTO v_row;
			EXIT WHEN p_cur%NOTFOUND;
			if v_count = 0 then 
				v_result := v_row.string;
			end if;
			v_result := REPLACE(v_result, v_row.search_str, v_row.replace_str);
			v_count := v_count + 1;
		end loop;
		CLOSE p_cur;
		PIPE ROW(v_result);
		RETURN;
	END replace_agg;

	FUNCTION Table_Alias_To_Sequence (p_Symbol_Name VARCHAR2) RETURN NUMBER
	is
	PRAGMA UDF;
	begin
		return CASE WHEN LENGTH(p_Symbol_Name) = 1
			then ASCII(p_Symbol_Name)-64
			else ((ASCII(SUBSTR(p_Symbol_Name, 1, 1))-64) * 26) + (ASCII(SUBSTR(p_Symbol_Name, 2, 1))-64)
		end;
	end Table_Alias_To_Sequence;

	FUNCTION Sequence_To_Table_Alias (p_Sequence NUMBER) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return CHR(NULLIF(TRUNC(p_Sequence / 26), 0) + 64) || CHR(MOD(p_Sequence, 26)+65);
	end Sequence_To_Table_Alias;

	FUNCTION FN_Query_Cardinality (
		p_Table_Name IN VARCHAR2,
		p_Column_Name IN VARCHAR2 DEFAULT NULL,
		p_Value IN VARCHAR2 DEFAULT NULL
	) RETURN NUMBER
	IS
	PRAGMA UDF;
		v_Query		VARCHAR2(32767);
		v_Expr		VARCHAR2(32767);
		v_Result    NUMBER := 0;
   		cv 			SYS_REFCURSOR;
	BEGIN
		if p_Column_Name IS NOT NULL and p_Value IS NOT NULL then
			v_Query := 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) || ' WHERE ' || p_Column_Name || ' = :s ';
			OPEN cv FOR v_Query USING p_Value;
		elsif p_Column_Name IS NOT NULL and p_Value IS NULL then
			v_Expr := case when INSTR(p_Column_Name, ',') > 0
							then 'COALESCE(' || p_Column_Name || ')' 
							else p_Column_Name end;
			v_Query := 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) || ' WHERE ' || v_Expr || ' IS NOT NULL ';
			OPEN cv FOR v_Query;
		else
			v_Query := 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name);
			OPEN cv FOR v_Query;
		end if;
		FETCH cv INTO v_Result;
		CLOSE cv;
		RETURN v_Result;
    EXCEPTION
    WHEN OTHERS THEN
        return NULL;
	END FN_Query_Cardinality;

	PROCEDURE Compile_Invalid_Objects
	is 
		v_Count NUMBER;
	begin -- simple replacement for : SYS.UTL_RECOMP.RECOMP_SERIAL(:OWNER);
		DBMS_OUTPUT.PUT_LINE('-- compile all invalid objects --');
		v_Count := 0;
		for cur in (
			SELECT 
				case when object_type = 'PACKAGE BODY' then 
					'ALTER PACKAGE' || ' ' || object_name || ' COMPILE BODY'
				else 
					'ALTER ' || object_type || ' ' || object_name||' COMPILE'
				end stat,
				object_type, object_name
			FROM USER_OBJECTS T1
			WHERE status = 'INVALID'
			AND object_type in ('FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'VIEW', 'TRIGGER', 'MATERIALIZED VIEW', 'DIMENSION' )
			AND object_name != 'DATA_BROWSER_CONF' -- avoid deadlock
		) loop
			begin
			EXECUTE IMMEDIATE cur.stat;
			EXCEPTION
			WHEN OTHERS THEN
			-- warning ora-24344 success with compilation error
				DBMS_OUTPUT.PUT_LINE('-- SQL Error with ' || cur.object_type || ' ' || cur.object_name || ' :' || SQLCODE || ' ' || SQLERRM);
				if SQLCODE != -24344 then
					RAISE;
				end if;
			END;
			v_Count := v_Count + 1;
		end loop;
		DBMS_OUTPUT.PUT_LINE('-- recompiled ' || v_Count || ' objects --');
	end Compile_Invalid_Objects;
BEGIN
	Load_Config;
END data_browser_conf;
/
