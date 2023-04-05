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

CREATE OR REPLACE PACKAGE data_browser_joins
AUTHID CURRENT_USER
IS
	FUNCTION Get_Detail_Table_Joins_Cursor (
		p_Table_Name VARCHAR2,
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Include_Schema VARCHAR2 DEFAULT 'YES',
		p_List_Excluded VARCHAR2 DEFAULT 'NO'
	) RETURN data_browser_conf.tab_describe_joins PIPELINED;
    g_detail_joins_tab		data_browser_conf.tab_describe_joins := data_browser_conf.tab_describe_joins();
	g_detail_joins_md5 		VARCHAR2(300) := 'X';

    g_record_joins_tab		data_browser_conf.tab_describe_joins := data_browser_conf.tab_describe_joins();
	g_record_joins_md5 		VARCHAR2(300) := 'X';

	FUNCTION Get_Joins_Options_Cursor (
    	p_Table_Name VARCHAR2,
    	p_Join_Options VARCHAR2
	) RETURN data_browser_conf.tab_join_options PIPELINED;

	FUNCTION Get_Details_Join_Options (
		p_Table_name IN VARCHAR2,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2;

	FUNCTION Get_Default_Join_Options (
		p_Table_Name VARCHAR2,
		p_Option VARCHAR2 DEFAULT 'K'
	) RETURN VARCHAR2;

	FUNCTION Process_Join_Options RETURN VARCHAR2;

	PROCEDURE Reset_Cache;
end data_browser_joins;
/

CREATE OR REPLACE PACKAGE data_browser_select
AUTHID CURRENT_USER
IS
    g_Export_Job_ID          		NUMBER;

	TYPE rec_data_browser_qc_refs IS RECORD (
		VIEW_NAME			VARCHAR2(128),
		TABLE_NAME			VARCHAR2(128),
		COLUMN_NAME			VARCHAR2(128),
		COLUMN_ID			NUMBER,
		NULLABLE			VARCHAR2(1),
		POSITION			NUMBER,
		R_VIEW_NAME			VARCHAR2(128),
		R_TABLE_NAME		VARCHAR2(128),
		R_COLUMN_NAME		VARCHAR2(128),
		R_COLUMN_ID			NUMBER,
		IMP_COLUMN_NAME		VARCHAR2(72),
		COLUMN_PREFIX		VARCHAR2(128),
		IS_UPPER_NAME		VARCHAR2(1),
		COLUMN_HEADER		VARCHAR2(128),
		COLUMN_EXPR			VARCHAR2(4000),
		R_DATA_TYPE			VARCHAR2(128),
		R_DATA_PRECISION	NUMBER,
		R_DATA_SCALE		NUMBER,
		R_DATA_DEFAULT		VARCHAR2(1024),
		R_CHAR_LENGTH		NUMBER,
		COLUMN_ALIGN		VARCHAR2(6),
		FIELD_LENGTH		NUMBER,
		R_NULLABLE			VARCHAR2(1),
		R_IS_READONLY		VARCHAR2(1),
		TABLE_ALIAS			VARCHAR2(10),
		R_TABLE_ALIAS		VARCHAR2(10),
		HAS_HELP_TEXT		VARCHAR2(1),
		HAS_DEFAULT			VARCHAR2(1),
		IS_BLOB				VARCHAR2(1),
		IS_PASSWORD			VARCHAR2(1),
		IS_AUDIT_COLUMN		VARCHAR2(1),
		IS_DATETIME			VARCHAR2(1),
		DISPLAY_IN_REPORT	VARCHAR2(1),
		IS_DISPLAYED_KEY_COLUMN	VARCHAR2(1),
		IS_REFERENCE		VARCHAR2(1),
		COMMENTS			VARCHAR2(4000)
	);
	TYPE tab_data_browser_qc_refs IS TABLE OF rec_data_browser_qc_refs;

	FUNCTION FN_Pipe_browser_qc_refs (
		p_View_Name VARCHAR2, 
		p_Data_Format VARCHAR2 DEFAULT 'FORM',
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL	-- Y,N; use G in number format mask
	)
	RETURN data_browser_select.tab_data_browser_qc_refs PIPELINED;

	TYPE rec_data_browser_fc_refs IS RECORD (
		VIEW_NAME			VARCHAR2(128),
		TABLE_NAME			VARCHAR2(128),
		COLUMN_NAME			VARCHAR2(128),
		COLUMN_ID			NUMBER,
		NULLABLE			VARCHAR2(1),
		R_COLUMN_ID			NUMBER,
		POSITION			NUMBER,
		FOREIGN_KEY_COLS	VARCHAR2(128),
		NORM_COLUMN_NAME	VARCHAR2(128),
		R_PRIMARY_KEY_COLS	VARCHAR2(512),
		R_CONSTRAINT_TYPE	VARCHAR2(1),
		R_VIEW_NAME			VARCHAR2(128),
		R_TABLE_NAME		VARCHAR2(128),
		R_COLUMN_NAME		VARCHAR2(128),
		IMP_COLUMN_NAME		VARCHAR2(72),
		COLUMN_PREFIX		VARCHAR2(128),
		IS_UPPER_NAME		CHAR(1),
		COLUMN_HEADER		VARCHAR2(128),
		COLUMN_ALIGN		VARCHAR2(6),
		FIELD_LENGTH		NUMBER,
		HAS_HELP_TEXT		VARCHAR2(1),
		HAS_DEFAULT			VARCHAR2(1),
		IS_BLOB				VARCHAR2(1),
		IS_PASSWORD			VARCHAR2(1),
		IS_AUDIT_COLUMN		VARCHAR2(1),
		IS_DATETIME			VARCHAR2(1),
		IS_NUMBER_YES_NO_COLUMN	VARCHAR2(1),
		IS_CHAR_YES_NO_COLUMN	VARCHAR2(1),
		YES_NO_COLUMN_TYPE	VARCHAR2(10),
		IS_SIMPLE_IN_LIST	VARCHAR2(1),
		STATIC_LOV_EXPR		VARCHAR2(1024), 
		HAS_AUTOMATIC_CHECK	VARCHAR2(1),
		HAS_RANGE_CHECK		VARCHAR2(1),
		DISPLAY_IN_REPORT	VARCHAR2(1),
		IS_DISPLAYED_KEY_COLUMN	VARCHAR2(1),
		IS_REFERENCE		VARCHAR2(1),
		R_DATA_TYPE			VARCHAR2(128),
		DATA_TYPE_OWNER		VARCHAR2(128),
		R_DATA_PRECISION	NUMBER,
		R_DATA_SCALE		NUMBER,
		R_DATA_DEFAULT		VARCHAR2(1024),
		R_CHAR_LENGTH		NUMBER,
		R_NULLABLE			VARCHAR2(1),
		COMMENTS			VARCHAR2(4000),
		R_CHECK_UNIQUE		VARCHAR2(1),
		R_IS_READONLY		VARCHAR2(1),
		TABLE_ALIAS			VARCHAR2(10)
	);
	TYPE tab_data_browser_fc_refs IS TABLE OF rec_data_browser_fc_refs;

	FUNCTION FN_Pipe_browser_fc_refs (p_View_Name VARCHAR2)
	RETURN data_browser_select.tab_data_browser_fc_refs PIPELINED;

	TYPE rec_data_browser_q_refs IS RECORD (
		VIEW_NAME			VARCHAR2(128),
		TABLE_NAME			VARCHAR2(128),
		IMP_COLUMN_NAME		VARCHAR2(128),
		DEST_COLUMN_NAME	VARCHAR2(128),
		COLUMN_PREFIX		VARCHAR2(128),
		IS_UPPER_NAME		VARCHAR2(1),
		COLUMN_HEADER		VARCHAR2(128),
		WARNING_MSG			VARCHAR2(128),
		PRIMARY_KEY_COLS	VARCHAR2(512),
		SEARCH_KEY_COLS		VARCHAR2(512),
		SHORT_NAME			VARCHAR2(128),
		COLUMN_ID			NUMBER,
		R_COLUMN_ID			NUMBER,
		POSITION			NUMBER,
		R_COLUMN_NAME		VARCHAR2(128),
		NULLABLE			VARCHAR2(1),
		FOREIGN_KEY_COLS	VARCHAR2(128),
		R_PRIMARY_KEY_COLS	VARCHAR2(512),
		R_CONSTRAINT_TYPE	VARCHAR2(1),
		R_VIEW_NAME			VARCHAR2(128),
		R_TABLE_NAME		VARCHAR2(128),
		TABLE_ALIAS			VARCHAR2(10),
		R_TABLE_ALIAS		VARCHAR2(10),
		R_NULLABLE			VARCHAR2(1),
		R_DATA_TYPE			VARCHAR2(128),
		R_DATA_SCALE		NUMBER,
		R_DATA_PRECISION	NUMBER,
		R_DATA_DEFAULT		VARCHAR2(1024),
		R_CHAR_LENGTH		NUMBER,
		COLUMN_ALIGN		VARCHAR2(6),
		FIELD_LENGTH		NUMBER,
		JOIN_VIEW_NAME 		VARCHAR2(128),
		JOIN_CLAUSE			VARCHAR2(1024),
		COLUMN_EXPR			VARCHAR2(1024),
		COLUMN_NAME			VARCHAR2(128),		
		HAS_HELP_TEXT		VARCHAR2(1),
		HAS_DEFAULT			VARCHAR2(1),
		IS_BLOB				VARCHAR2(1),
		IS_PASSWORD			VARCHAR2(1),
		IS_AUDIT_COLUMN		VARCHAR2(1),
		IS_DATETIME			VARCHAR2(1),
		IS_READONLY			VARCHAR2(1),
		DISPLAY_IN_REPORT	VARCHAR2(1),
		IS_DISPLAYED_KEY_COLUMN	VARCHAR2(1),
		IS_REFERENCE		VARCHAR2(1),
		HAS_NULLABLE		NUMBER,
		U_CONSTRAINT_NAME	VARCHAR2(128),
		U_MEMBERS			NUMBER,
		U_MATCHING			NUMBER,
		J_VIEW_NAME			VARCHAR2(128),
		J_COLUMN_NAME		VARCHAR2(128),
		IS_FILE_FOLDER_REF	VARCHAR2(1),
		FILTER_KEY_COLUMN	VARCHAR2(512),
		PARENT_KEY_COLUMN	VARCHAR2(512)
	);
	TYPE tab_data_browser_q_refs IS TABLE OF rec_data_browser_q_refs;

	-- result cache
    g_q_ref_cols_tab		data_browser_select.tab_data_browser_q_refs;
	g_q_ref_cols_md5 		VARCHAR2(300) := 'X';

	FUNCTION FN_Pipe_browser_q_refs (
		p_View_Name VARCHAR2, 
		p_Data_Format VARCHAR2 DEFAULT 'FORM', 
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,	-- Y,N; use G in number format mask
		p_Include_Schema VARCHAR2 DEFAULT data_browser_conf.Get_Include_Query_Schema
	) RETURN data_browser_select.tab_data_browser_q_refs PIPELINED;

	TYPE rec_table_imp_fk IS RECORD (
		VIEW_NAME					VARCHAR2(128),
		TABLE_NAME					VARCHAR2(128),
		SEARCH_KEY_COLS				VARCHAR2(512),
		SHORT_NAME					VARCHAR2(132),
		COLUMN_NAME					VARCHAR2(512),
		S_VIEW_NAME					VARCHAR2(128),
		S_REF						VARCHAR2(128),
		D_VIEW_NAME					VARCHAR2(128),
		D_REF						VARCHAR2(128),
		D_COLUMN_NAME				VARCHAR2(128),
		IS_FILE_FOLDER_REF			VARCHAR2(128),
		FOLDER_PARENT_COLUMN_NAME	VARCHAR2(128),
		FOLDER_NAME_COLUMN_NAME		VARCHAR2(128),
		FOLDER_CONTAINER_COLUMN_NAME VARCHAR2(128),
		FILTER_KEY_COLUMN			VARCHAR2(128),
		PARENT_KEY_COLUMN			VARCHAR2(128),
		R_PRIMARY_KEY_COLS			VARCHAR2(512),
		R_CONSTRAINT_TYPE			VARCHAR2(1),
		R_TABLE_NAME				VARCHAR2(128),
		R_VIEW_NAME					VARCHAR2(128),
		COLUMN_ID					NUMBER,
		NULLABLE					VARCHAR2(1),
		R_COLUMN_ID					NUMBER,
		R_COLUMN_NAME				VARCHAR2(128),
		POSITION					NUMBER,
		R_NULLABLE					VARCHAR2(1),
		R_DATA_TYPE					VARCHAR2(128),
		R_DATA_PRECISION			NUMBER,
		R_DATA_SCALE				NUMBER,
		R_CHAR_LENGTH				NUMBER,
		IS_DATETIME					VARCHAR2(1),
		TABLE_ALIAS					VARCHAR2(10),
		IMP_COLUMN_NAME				VARCHAR2(128),
		JOIN_CLAUSE					VARCHAR2(4000),
		HAS_NULLABLE				NUMBER,
		HAS_SIMPLE_UNIQUE			NUMBER,
		HAS_FOREIGN_KEY				NUMBER,
		U_CONSTRAINT_NAME			VARCHAR2(128),
		U_MEMBERS					NUMBER,
		POSITION2					NUMBER
	);
	TYPE tab_table_imp_fk IS TABLE OF rec_table_imp_fk;

	FUNCTION Date_Time_Required (
        p_Data_Type VARCHAR2,
        p_Data_Format VARCHAR2,
        p_Datetime VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 DETERMINISTIC; -- Y / N

    FUNCTION Reference_Column_Header (
    	p_Column_Name VARCHAR2,
    	p_Remove_Prefix VARCHAR2,
    	p_View_Name VARCHAR2,
    	p_R_View_Name VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_ConversionColFunction (
		p_Column_Name VARCHAR2,
		p_Data_Type VARCHAR2,
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Char_Length NUMBER,
		p_Data_Format VARCHAR2 DEFAULT 'FORM',
		p_Use_Trim VARCHAR2 DEFAULT 'Y',	-- trim leading spaces from formated numbers; trim text to limit
		p_Datetime VARCHAR2 DEFAULT NULL,	-- Y,N
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL	-- Y,N; use G in number format mask
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION FN_Pipe_table_imp_fk1 (p_Table_Name VARCHAR2)
	RETURN data_browser_select.tab_table_imp_fk PIPELINED;

	FUNCTION FN_Pipe_table_imp_fk2 (
		p_Table_Name VARCHAR2,
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Data_Format VARCHAR2 DEFAULT 'FORM'
	)
	RETURN data_browser_select.tab_table_imp_fk PIPELINED;

    FUNCTION Field_Has_HCInput_ID (	-- function returns 1, when the field is an character input field.
    	p_Column_Expr_Type IN VARCHAR2,
        p_Data_Type VARCHAR2,
    	p_Is_Search_Key VARCHAR2 DEFAULT 'N',	-- Y, N
    	p_Is_Foreign_Key VARCHAR2 DEFAULT 'N'	-- Y, N
    )
    RETURN INTEGER DETERMINISTIC;	-- 0, 1

    FUNCTION Field_Has_CInput_ID (	-- function returns 1, when the field is an character input field.
    	p_Column_Expr_Type IN VARCHAR2
    )
    RETURN INTEGER DETERMINISTIC;	-- 0, 1

    FUNCTION Field_Has_NInput_ID (	-- function returns 1, when the field is a hidden serial primary or foreign key
    	p_Column_Expr_Type VARCHAR2,
        p_Data_Type VARCHAR2,
    	p_Is_Search_Key VARCHAR2 DEFAULT 'N',	-- Y, N
    	p_Is_Foreign_Key VARCHAR2 DEFAULT 'N'	-- Y, N
    )
    RETURN INTEGER DETERMINISTIC;	-- 0, 1

	FUNCTION FN_List_Offest(p_Select_Columns VARCHAR2, p_Column_Name VARCHAR2) return NUMBER;

	FUNCTION FN_Apex_Item_Use_Column (
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION FN_Is_Searchable_Column(
		p_Column_Expr_Type VARCHAR2,
		p_Is_Searchable_Ref VARCHAR2 DEFAULT 'N'
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION FN_Is_Sortable_Column(
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION FN_Filter_Parent_Key (
		p_Parent_Key_Visible VARCHAR2,
		p_Parent_Name VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_Ref_View_Name VARCHAR2,
		p_R_Column_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Get_Unique_Key_Expression (	-- row reference in where clause, produces A.ROWID references in case of composite or missing unique keys
    	p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
    	p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
    ) RETURN VARCHAR2;

	FUNCTION Navigation_Counter_HTML(
		p_Data_Format VARCHAR2,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_CounterQuery VARCHAR2,
		p_Target VARCHAR2,
		p_Link_Page_ID PLS_INTEGER,
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	FUNCTION Nested_Link_HTML(
		p_Data_Format VARCHAR2,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_CounterQuery VARCHAR2, -- SQL Expression
		p_Attributes VARCHAR2,	-- SQL Expression
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	FUNCTION Detail_Link_Html (
		p_Data_Format VARCHAR2,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Table_name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Link_Page_ID NUMBER,	-- Page ID of target links
		p_Link_Items VARCHAR2, -- Item names for TABLE_NAME,PARENT_TABLE,ID
		p_Key_Value VARCHAR2,
		p_Parent_Value VARCHAR2 DEFAULT NULL,
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL,
        p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2;

	FUNCTION Get_Form_Required_Html (
		p_Is_Required VARCHAR2 DEFAULT 'N',
		p_Check_Unique VARCHAR2 DEFAULT 'N',
		p_Display_Key_Column VARCHAR2 DEFAULT 'N'
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Get_Form_Help_Link_Html (
		p_Column_Id NUMBER,
		p_R_View_Name VARCHAR2,
		p_R_Column_Name VARCHAR2,
		p_Column_Header VARCHAR2,
		p_Comments VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;


	PROCEDURE Reset_Cache;

    FUNCTION Current_Job_ID RETURN NUMBER;
	FUNCTION FN_Table_Prefix (p_Schema_Name VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
	FUNCTION FN_Current_Data_Format RETURN VARCHAR2;

	FUNCTION Get_Row_Selector_Expr (
		p_Data_Format VARCHAR2,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Column_Expr VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2;

    FUNCTION Key_Values_Query (
        p_Table_Name    VARCHAR2,
        p_Display_Col_Names VARCHAR2,	-- display columns,
        p_Extra_Col_Names VARCHAR2 DEFAULT NULL, -- extra columns,
        p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
        p_Search_Value  VARCHAR2 DEFAULT NULL, -- used to produce only a single output row for known value or reference
        p_View_Mode VARCHAR2,
        p_Filter_Cond VARCHAR2 DEFAULT NULL,
        p_Exclude_Col_Name VARCHAR2 DEFAULT NULL,
		p_Active_Col_Name VARCHAR2 DEFAULT NULL,
		p_Active_Data_Type VARCHAR2 DEFAULT NULL,		-- NUMBER, CHAR
        p_Order_by VARCHAR2 DEFAULT NULL,
        p_Level INTEGER DEFAULT 1,
        p_Indent INTEGER DEFAULT 4
    ) RETURN VARCHAR2;

    FUNCTION Key_Values_Path_Query (
        p_Table_Name    VARCHAR2,
        p_Display_Col_Names VARCHAR2,	-- display columns,
        p_Extra_Col_Names VARCHAR2 DEFAULT NULL, -- extra columns,
        p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
        p_Search_Value  VARCHAR2, -- used to produce only a single output row for known value or reference
        p_View_Mode VARCHAR2,
        p_Filter_Cond VARCHAR2 DEFAULT NULL,
        p_Exclude_Col_Name VARCHAR2,
        p_Folder_Par_Col_Name VARCHAR2,
        p_Folder_Name_Col_Name VARCHAR2,
        p_Folder_Cont_Col_Name VARCHAR2,
        p_Folder_Cont_Alias VARCHAR2 DEFAULT NULL,
		p_Active_Col_Name VARCHAR2,
		p_Active_Data_Type VARCHAR2,		-- NUMBER, CHAR
        p_Order_by VARCHAR2, 
        p_Level INTEGER DEFAULT 1,
        p_Indent INTEGER DEFAULT 4
    ) RETURN VARCHAR2;

    FUNCTION Key_Values_Query (
        p_Table_Name    VARCHAR2
	) RETURN VARCHAR2;

    FUNCTION Key_Path_Query (
        p_Table_Name    VARCHAR2,
        p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
        p_Search_Value  VARCHAR2 DEFAULT NULL, -- used to produce only a single output row for known value or reference
        p_Folder_Par_Col_Name VARCHAR2,
        p_Folder_Name_Col_Name VARCHAR2,
        p_Folder_Cont_Col_Name VARCHAR2,
        p_Folder_Cont_Alias VARCHAR2 DEFAULT NULL,
        p_View_Mode VARCHAR2,
        p_Filter_Cond VARCHAR2,
        p_Order_by VARCHAR2,
        p_Level INTEGER DEFAULT 1
    ) RETURN VARCHAR2;

    FUNCTION Key_Path_Lookup_Query (
        p_Table_Name    VARCHAR2,
        p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
        p_Search_Path  VARCHAR2 DEFAULT NULL, -- used to lookup only a single output row for known path
        p_Search_Value  VARCHAR2 DEFAULT NULL, -- output variable for found identity value.
        p_Folder_Par_Col_Name VARCHAR2,
        p_Folder_Name_Col_Name VARCHAR2,
        p_Folder_Cont_Col_Name VARCHAR2 DEFAULT NULL,
        p_Folder_Cont_Alias VARCHAR2 DEFAULT NULL,
        p_Level INTEGER DEFAULT 1
    ) RETURN VARCHAR2;

    FUNCTION Get_Parent_LOV_Query (
        p_Table_Name    IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
		p_Filter_Used_Values VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2;

    FUNCTION Get_LOV_Query (
        p_Table_Name    IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
    	p_Filter_Cond VARCHAR2 DEFAULT NULL,
		p_Order_by VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

    FUNCTION LOV_CURSOR (
        p_Table_Name    IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
    	p_Filter_Cond VARCHAR2 DEFAULT NULL,
		p_Order_by VARCHAR2 DEFAULT NULL
	) RETURN data_browser_conf.tab_col_value PIPELINED;

    FUNCTION Get_Calendar_Query (
        p_Table_Name    IN VARCHAR2,
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL			-- Page Item Name, Filter Value and default value for foreign key column
	) RETURN VARCHAR2;

    FUNCTION Get_Tree_Query (
        p_Table_Name    IN VARCHAR2,
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL			-- Page Item Name, Filter Value and default value for foreign key column
	) RETURN VARCHAR2;

    FUNCTION Get_Ref_LOV_Query (
        p_Table_Name    IN VARCHAR2,
        p_FK_Column_ID  IN NUMBER,						-- Foreign key column of table name 
        p_Column_Name   IN VARCHAR2,                    -- Foreign key column of table name 
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL			-- Page Item Name, Filter Value and default value for foreign key column
	) RETURN VARCHAR2;

    FUNCTION Child_Link_List_Query (
        p_Table_Name    IN VARCHAR2,
        p_Display_Col_Names IN VARCHAR2,	-- display columns
        p_Search_Key_Col IN VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
        p_Search_Value  IN VARCHAR2 DEFAULT NULL, -- used to produce only a single output row for known value or reference
        p_View_Mode IN VARCHAR2,
    	p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
        p_Key_Column IN VARCHAR2 DEFAULT NULL,
        p_Target1 IN VARCHAR2,
        p_Target2 IN VARCHAR2,
        p_Detail_Page_ID INTEGER,
        p_Link_Page_ID	INTEGER,
        p_Level IN NUMBER DEFAULT 1
    ) RETURN VARCHAR2;

	-- result cache
    g_Describe_Cols_tab			data_browser_conf.tab_record_view;
	g_Describe_Cols_md5 		VARCHAR2(300) := 'X';

	---------------------------------------------------------------------------

    FUNCTION Get_Imp_Table_Column_List (
		p_Table_Name VARCHAR2,
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Delimiter VARCHAR2 DEFAULT ', ',
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',		-- YES, NO
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_Format VARCHAR2 DEFAULT 'NAMES',				-- NAMES, HEADER, ALIGN, ITEM_HELP
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'EXPORT_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,	-- Y,N; use G in number format mask
		p_Report_Mode VARCHAR2 DEFAULT 'NO',			-- YES, NO
		p_Enable_Sort VARCHAR2 DEFAULT 'NO',			-- YES, NO
		p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : 'LAST_NAME, FIRST_NAME'
		p_Order_Direction VARCHAR2 DEFAULT 'ASC',		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB;

    PROCEDURE Get_Collection_Columns (
		p_Map_Column_List 	IN OUT NOCOPY VARCHAR2,
		p_Map_Count 		IN OUT PLS_INTEGER,
		p_Column_Expr_Type 	VARCHAR2,
		p_Data_Type 		VARCHAR2,
		p_Input_ID 			VARCHAR2,
		p_Column_Name 		VARCHAR2,
		p_Default_Value		VARCHAR2 DEFAULT NULL,
		p_indent 			PLS_INTEGER DEFAULT 4,
		p_Convert_Expr		VARCHAR2 DEFAULT NULL,
		p_Is_Virtual_Column VARCHAR2 -- Y/N 
    );

    FUNCTION Get_Collection_Query (
		p_Map_Column_List VARCHAR2,
		p_Map_Unique_Key VARCHAR2 DEFAULT NULL,
		p_indent PLS_INTEGER DEFAULT 4
    ) RETURN VARCHAR2;

    FUNCTION Get_Imp_Table_Query (
		p_Table_Name VARCHAR2,
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Control_Break	 VARCHAR2 DEFAULT NULL,
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'EXPORT_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- TABLE, NEW_ROWS, COLLECTION, QUERY
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,		-- Y,N; use G in number format mask
		p_Report_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links 
		p_Search_Field_Item VARCHAR2 DEFAULT NULL,			-- Example : P30_SEARCH
		p_Search_Column_Name IN VARCHAR2 DEFAULT NULL,
		p_Comments VARCHAR2 DEFAULT NULL,					-- Comments
		p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_File_Page_ID NUMBER DEFAULT 31					-- Page ID of target links to file preview in View_Mode FORM_VIEW
	) RETURN CLOB;

	---------------------------------------------------------------------------

	FUNCTION Get_Form_View_Query (							-- internal
		p_Table_name IN VARCHAR2,							-- Table Name or View Name of master table
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Columns_Limit IN NUMBER DEFAULT 1000,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW', 		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Edit_Mode VARCHAR2 DEFAULT 'NO', 					-- YES, NO
    	p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- TABLE, QUERY
		p_Empty_Row VARCHAR2  DEFAULT 'NO', 				-- YES, NO
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	    -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links 
    	p_File_Page_ID NUMBER DEFAULT 31,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Search_Field_Item VARCHAR2 DEFAULT NULL,			-- Example : P30_SEARCH
    	p_Search_Column_Name VARCHAR2 DEFAULT NULL,			-- table column name for searching
    	p_Calc_Totals VARCHAR2 DEFAULT 'NO',			-- YES, NO
    	p_Nested_Links VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Source_Query CLOB DEFAULT NULL, 					-- Passed query for from clause
    	p_Comments VARCHAR2 DEFAULT NULL					-- Comments
	) RETURN CLOB;

    FUNCTION Get_Query_From_Clause (
    	p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW', 		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Empty_Row VARCHAR2  DEFAULT 'NO', 				-- YES, NO
    	p_Source_Query CLOB DEFAULT NULL, 					-- Passed query for from clause
    	p_Parameter_Columns VARCHAR2 DEFAULT NULL,
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- TABLE, NEW_ROWS, COLLECTION, QUERY
    	p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
    	p_Map_Column_List VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

	FUNCTION Get_Form_View_Column_List (	-- internal
    	p_Table_Name VARCHAR2,								-- Table Name or View Name of master table
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
    	p_Delimiter VARCHAR2 DEFAULT ', ',
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
    	p_Select_Columns VARCHAR2 DEFAULT NULL,
    	p_Columns_Limit INTEGER DEFAULT 1000,
    	p_Format VARCHAR2 DEFAULT 'NAMES', 					-- NAMES, HEADER, ALIGN, ITEM_HELP
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW', 		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Edit_Mode VARCHAR2 DEFAULT 'NO', 					-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
 		p_Enable_Sort VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Order_by VARCHAR2 DEFAULT NULL,					-- Example : 'LAST_NAME, FIRST_NAME'
    	p_Order_Direction VARCHAR2 DEFAULT 'ASC',			-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
	   	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	    -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_File_Page_ID NUMBER DEFAULT 31				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    ) RETURN CLOB;

	FUNCTION Get_View_Column_Cursor (	-- internal
		p_Table_Name VARCHAR2,								-- Table Name or View Name
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,		-- Y,N; use G in number format mask
		p_Report_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO, ALL, If YES, none standard columns are excluded from the generated column list
		p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),		-- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
		p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_File_Page_ID NUMBER DEFAULT 31					-- Page ID of target links to file preview in View_Mode FORM_VIEW
	) RETURN data_browser_conf.tab_record_view PIPELINED;

end data_browser_select;
/

CREATE OR REPLACE PACKAGE data_browser_blobs
AUTHID CURRENT_USER
IS
	g_use_package_as_zip 			CONSTANT BOOLEAN 		:= TRUE;
	
	FUNCTION fn_Blob_To_Clob(p_data IN BLOB, p_charset IN VARCHAR2 DEFAULT NULL)
	RETURN CLOB;

	-- upload files --
	FUNCTION Can_Upload_Files(
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL			-- Parent View or Table name.
	) RETURN VARCHAR2; -- YES/NO

	FUNCTION Can_Upload_Zip_Files(
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL			-- Parent View or Table name.
	) RETURN VARCHAR2; -- YES/NO

	FUNCTION Can_Upload_File_List(
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL			-- Parent View or Table name.
	) RETURN VARCHAR2; -- YES/NO

	PROCEDURE Upload_File_List (
		p_File_Names VARCHAR2,							-- temp file names
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
		p_Unzip_Files VARCHAR2 DEFAULT 'YES',			-- automatically unzip uploaded files
    	p_File_Dates VARCHAR2 DEFAULT NULL,				-- list of dates in format DD.MM.YY HH24:MI:SS delimited by |
    	p_File_Names2 VARCHAR2 DEFAULT NULL,			-- list of file names delimited by |
    	p_Context BINARY_INTEGER DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)
	);

	FUNCTION Get_Zip_Upload_Result (
		p_File_Names VARCHAR2,
		p_App_User VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_Start_Date TIMESTAMP 
	) RETURN VARCHAR2;

	PROCEDURE Upload_Zip_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2);

	PROCEDURE Upload_File (
		p_File_Name 		VARCHAR2,
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_File_Date 		DATE DEFAULT NULL
	);

	PROCEDURE Upload_text_File (
		p_File_Name 	VARCHAR2,
		p_Text_Mode		OUT NOCOPY VARCHAR2,	-- PLAIN / HTML
		p_Text_is_HTML  OUT NOCOPY VARCHAR2,   -- YES / NO
		p_Plain_Text	OUT NOCOPY CLOB,
		p_HTML_Text		OUT NOCOPY CLOB
	);

	-- preview and download --
	FUNCTION File_Type_Name(
		p_Mime_Type		IN VARCHAR2)
	RETURN VARCHAR2;

	FUNCTION File_Type_Name_Call(
		p_Mime_Type_Column_Name	IN VARCHAR2)
	RETURN VARCHAR2;

	FUNCTION Extract_Source_URL(
		p_URL				IN VARCHAR2
	) RETURN VARCHAR2;

	PROCEDURE  FN_File_Meta_Data(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_File_Name 		OUT NOCOPY VARCHAR2,
		p_Mime_Type 		OUT NOCOPY VARCHAR2,
		p_File_Date 		OUT DATE,
		p_File_Size			OUT NUMBER
	);

	PROCEDURE FN_File_Thumbnail(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_MaxHeight 		NUMBER DEFAULT 128
	);

	FUNCTION Prepare_Plain_Url(p_URL VARCHAR2) RETURN VARCHAR2;

	FUNCTION FN_File_Icon(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value		VARCHAR2,
		p_Prepare_Url       VARCHAR2 DEFAULT 'NO',
		p_Icon_Size			NUMBER DEFAULT 64
	) RETURN VARCHAR2;

	FUNCTION FN_File_Icon_Call(
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2
	) RETURN VARCHAR2;

	FUNCTION FN_File_Icon_Link(
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2,
		p_Page_ID           NUMBER DEFAULT 31
	) RETURN VARCHAR2;

	FUNCTION Text_Link_Url (
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2,
		p_Column_Name 		VARCHAR2,
		p_Page_ID 			NUMBER,
		p_Seq_ID			VARCHAR2 DEFAULT NULL,
		p_Selector			VARCHAR DEFAULT 'ACTIONS_GEAR'
	) RETURN VARCHAR2;

	FUNCTION FN_Edit_Text_Link_Html (
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2,
		p_Column_Name 		VARCHAR2,
		p_Data_Type			VARCHAR2,
		p_Page_ID           NUMBER DEFAULT 42,
		p_Seq_ID			VARCHAR2 DEFAULT NULL,
		p_Selector			VARCHAR2 DEFAULT 'ACTIONS_GEAR'
	) RETURN VARCHAR2;

	FUNCTION FN_Text_Tool_Body_Html (
		p_Column_Label 		VARCHAR2,
		p_Column_Expr		VARCHAR2,
		p_CSS_Class			VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	PROCEDURE Init_Clob_Updates;

	PROCEDURE Load_Clob_from_link (
		p_Seq_ID		OUT INTEGER,
		p_Char_length   OUT INTEGER,
		p_Column_Label  OUT NOCOPY VARCHAR2,
		p_Text_Mode		IN OUT NOCOPY VARCHAR2,	-- PLAIN / HTML
		p_Text_is_HTML  OUT NOCOPY VARCHAR2,   -- YES / NO
		p_Plain_Text	OUT NOCOPY CLOB,
		p_HTML_Text		OUT NOCOPY CLOB
	);

	FUNCTION Register_Clob_Updates(
		p_Table_Name 		VARCHAR2 DEFAULT V('APP_PRO_TABLE_NAME'),
    	p_Unique_Key_Column VARCHAR2 DEFAULT V('APP_PRO_KEY_COLUMN'),
		p_Search_Value 		VARCHAR2 DEFAULT V('APP_PRO_KEY_VALUE'),
		p_Column_Name		VARCHAR2 DEFAULT V('APP_PRO_COLUMN_NAME'),
		p_Seq_ID			NUMBER DEFAULT NULL,
		p_Clob 				CLOB DEFAULT NULL
	) RETURN VARCHAR; -- Reference to the text block

	FUNCTION Get_Clob_from_Form (	-- returns the requested clob from text editor field and deletes it from the collection
		p_Field_Value VARCHAR2
	) return CLOB;

	FUNCTION Get_Varchar_from_Form (	-- returns the requested clob from text editor field and deletes it from the collection
		p_Field_Value VARCHAR2
	) return VARCHAR2;

	FUNCTION Get_Clob_from_form_call (
		p_Field_Value VARCHAR2,
		p_Data_Type VARCHAR2
	) return VARCHAR2;

	FUNCTION Process_Clob_Updates RETURN PLS_INTEGER;

	PROCEDURE Clear_Clob_Updates;

	PROCEDURE Register_Download (
		p_Table_Name 		VARCHAR2,
		p_Object_ID			VARCHAR2,
		p_flush_log			BOOLEAN DEFAULT TRUE
	);

	FUNCTION FN_Add_Zip_File (
		p_Table_Name 		VARCHAR2 DEFAULT V('APP_PRO_TABLE_NAME'),
    	p_Unique_Key_Column VARCHAR2 DEFAULT V('APP_PRO_KEY_COLUMN'),
		p_Search_Value 		VARCHAR2 DEFAULT V('APP_PRO_KEY_VALUE'),
		p_Zip_File			IN OUT NOCOPY BLOB
	) RETURN PLS_INTEGER;

	PROCEDURE FN_Zip_File_Download(
		p_Table_Name 		VARCHAR2 DEFAULT V('APP_PRO_TABLE_NAME'),
		p_Zip_File			IN OUT NOCOPY BLOB
	);

	PROCEDURE FN_File_Download(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2
	);

	PROCEDURE  FN_File_Preview(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2
	);

	PROCEDURE  Download_Clob (
		p_clob				NCLOB,
		p_File_Name 		VARCHAR2
	);

end data_browser_blobs;
/

CREATE OR REPLACE PACKAGE data_browser_ctl
AUTHID CURRENT_USER
IS
	PROCEDURE Start_Trial_Modus; 
	FUNCTION App_Trial_Code RETURN VARCHAR2;
	FUNCTION App_Trial_Modus RETURN BOOLEAN;
	FUNCTION App_Paid_Modus RETURN BOOLEAN;
	FUNCTION App_Trial_Modus_vc RETURN VARCHAR2;
	FUNCTION App_Paid_Modus_vc RETURN VARCHAR2;
	PROCEDURE Set_App_Licence_Number (p_Code IN VARCHAR2, p_Owner IN VARCHAR2);
	FUNCTION App_Modus RETURN VARCHAR2;
end data_browser_ctl;
/

CREATE OR REPLACE PACKAGE data_browser_utl
AUTHID CURRENT_USER
IS
	FUNCTION Is_Automatic_Search_Enabled (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2;

	FUNCTION Has_Calendar_Date (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2;

	FUNCTION Has_Tree_View (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2;

    PROCEDURE Get_Foreign_Key_Details (
    	p_Table_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Load_Foreign_Key VARCHAR2 DEFAULT 'YES',
		p_Foreign_Key_Table VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Column IN OUT VARCHAR2,
		p_Foreign_Key_ID IN OUT VARCHAR2,
    	p_Link_ID IN VARCHAR2
    );

    PROCEDURE Get_Form_Prev_Next (
    	p_Table_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Table VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_ID IN VARCHAR2 DEFAULT NULL,
    	p_Link_ID IN VARCHAR2,
    	p_Order_by IN OUT NOCOPY VARCHAR2,
    	p_Next_Link_ID OUT NOCOPY VARCHAR2,
    	p_Prev_Link_ID OUT NOCOPY VARCHAR2,
    	p_First_Link_ID OUT NOCOPY VARCHAR2,
    	p_Last_Link_ID OUT NOCOPY VARCHAR2,
    	p_X_OF_Y OUT NOCOPY VARCHAR2
    );

    PROCEDURE Get_Form_Prev_Next (
    	p_Table_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Table VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_ID IN VARCHAR2 DEFAULT NULL,
    	p_Link_ID IN VARCHAR2,
    	p_Order_by IN OUT NOCOPY VARCHAR2,
    	p_Next_Link_ID OUT NOCOPY VARCHAR2,
    	p_Prev_Link_ID OUT NOCOPY VARCHAR2,
    	p_X_OF_Y OUT NOCOPY VARCHAR2
    );

	FUNCTION Column_Value_List (
		p_Query IN CLOB,
		p_Search_Value IN VARCHAR2 DEFAULT NULL,
		p_Offset IN NUMBER DEFAULT 0,
		p_Exact IN VARCHAR2 DEFAULT 'NO'	-- Load values for exactly one row
	) RETURN data_browser_conf.tab_col_value PIPELINED;

	---------------------------------------------------------------------------
	FUNCTION Get_Detail_View_Column_Cursor (				-- External : used for search column LOV and order by column LOV
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Format IN VARCHAR2 DEFAULT 'SEARCH',				-- ALL, SEARCH, ORDER_BY, PAGINATION
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO', -- YES, NO
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'YES'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN data_browser_conf.tab_col_value PIPELINED;

	FUNCTION Get_Detail_View_Query (						-- External : Readonly Detail View Report Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO - include ROW_SELECTOR
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- TABLE, NEW_ROWS, COLLECTION, QUERY
    	p_Data_Format VARCHAR2 DEFAULT data_browser_select.FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),     -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_File_Page_ID NUMBER DEFAULT 31,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Search_Field_Item VARCHAR2 DEFAULT NULL,			-- Example : P30_SEARCH
    	p_Search_Column_Name IN VARCHAR2 DEFAULT NULL,
    	p_Calc_Totals  VARCHAR2 DEFAULT 'NO',			-- YES, NO
    	p_Nested_Links VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Source_Query CLOB DEFAULT NULL, 					-- Passed query for from clause
    	p_Comments VARCHAR2 DEFAULT NULL					-- Comments
	) RETURN CLOB;

	FUNCTION Get_Detail_View_Column_List (				-- External : column list for classic report headings and alignment
    	p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Delimiter VARCHAR2 DEFAULT ', ',
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
    	p_Select_Columns VARCHAR2 DEFAULT NULL,
    	p_Columns_Limit INTEGER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Format VARCHAR2 DEFAULT 'NAMES', 				-- NAMES, HEADER, ALIGN, ITEM_HELP
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 			-- YES, NO
 		p_Enable_Sort VARCHAR2 DEFAULT 'NO', 			-- YES, NO - generate clickable headers
    	p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : 'LAST_NAME, FIRST_NAME'
    	p_Order_Direction VARCHAR2 DEFAULT 'ASC',		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
    	p_Parent_Name VARCHAR2 DEFAULT NULL,
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    ) RETURN CLOB;

	PROCEDURE Prepare_Detail_View (						-- External : column list for report column alignment and column item help
    	p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Join_Options IN OUT NOCOPY VARCHAR2,
    	p_Alignment OUT NOCOPY VARCHAR2,
    	p_Item_Help OUT NOCOPY VARCHAR2,
    	p_Order_by IN VARCHAR2,
    	p_Order_Direction IN VARCHAR2
    );

    FUNCTION Lookup_Column_Value (
        p_Search_Value  IN VARCHAR2,
        p_Table_Name    IN VARCHAR2,
        p_Column_Exp     IN VARCHAR2,
        p_Search_Key_Col IN VARCHAR2
    )
    RETURN VARCHAR2;

    FUNCTION Lookup_Column_Values (
        p_Table_Name    IN VARCHAR2,
        p_Column_Names  IN VARCHAR2,
        p_Search_Key_Col IN VARCHAR2,
        p_Search_Value  IN VARCHAR2,
        p_View_Mode		IN VARCHAR2
    )
    RETURN VARCHAR2;

	FUNCTION Get_View_Mode_Description (	-- Heading for Report
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2;

	PROCEDURE Get_Default_Order_by (					-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name IN VARCHAR2 DEFAULT NULL,			-- Parent View or Table name
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,	-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible IN VARCHAR2 DEFAULT 'NO',  -- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Order_By OUT VARCHAR2,
    	p_Control_Break OUT VARCHAR2,
		p_Order_By_Hdr OUT VARCHAR2,
		p_Control_Break_Hdr OUT VARCHAR2
	);

	FUNCTION Get_Default_Order_by (						-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2;

	FUNCTION Get_Default_Order_by_Cursor (				-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN data_browser_conf.tab_col_value PIPELINED;

	FUNCTION Get_Default_Control_Break (				-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2;

	FUNCTION Get_Default_Select_Columns (
		p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB;

	FUNCTION Filter_Select_Columns (
		p_Table_Name VARCHAR2,
		p_Select_Columns VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB;

	FUNCTION Get_Report_Description (	-- Heading for Report
		p_Table_name IN VARCHAR2,
		p_Parent_Name IN VARCHAR2 DEFAULT NULL,
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_View_Mode IN VARCHAR2,
		p_Search_Key_Col IN VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	FUNCTION Get_Report_Description (	-- Heading for Report
		p_Table_name IN VARCHAR2,
		p_Parent_Name IN VARCHAR2,
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Search_Value IN VARCHAR2,
		p_Search_Key_Col IN VARCHAR2 DEFAULT NULL,
		p_Report_ID IN VARCHAR2  DEFAULT NULL
	) RETURN VARCHAR2;

    FUNCTION Check_Edit_Enabled(
    	p_Table_Name VARCHAR2,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Search_Value IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2; -- YES, NO

	PROCEDURE Get_Record_Description (
		p_Table_name IN VARCHAR2,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Search_Value IN VARCHAR2,
    	p_Unique_Key_Column IN OUT VARCHAR2, -- primary key column
    	p_Description  OUT VARCHAR2, -- Heading for Record,
    	p_Default_Order_by OUT VARCHAR2,
    	p_View_Mode_Description OUT VARCHAR2,
    	p_Edit_Enabled OUT VARCHAR2
	);

	FUNCTION Get_Record_Label (
		p_Table_name IN VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Search_Key_Col IN VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2;

	PROCEDURE Get_Navigation_Preferences (
		-- independent --
		p_Search_Table IN OUT VARCHAR2,					-- YES, NO
		p_Table_View_Mode IN OUT VARCHAR2,
		p_Table_name IN OUT VARCHAR2,					-- View or Table name
    	p_Constraint_Name IN OUT VARCHAR2				-- Parent key
	);

	PROCEDURE Set_Navigation_Preferences (
		-- independent --
		p_Search_Table IN OUT NOCOPY VARCHAR2,
		p_Table_View_Mode IN VARCHAR2,
    	p_Constraint_Name IN VARCHAR2,					-- Parent key
		p_Table_name IN VARCHAR2						-- View or Table name
	);

	PROCEDURE Get_Report_Preferences (
		-- independent --
		p_Table_name IN VARCHAR2,					-- View or Table name
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,	-- primary keys cols of the table 
		p_Report_ID IN NUMBER DEFAULT NULL, 	
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_PAGE_ID'),
    	p_Parent_Name IN VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,	-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible IN OUT VARCHAR2, 		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Filter IN VARCHAR2 DEFAULT 'NO',  -- YES, NO, when YES, no p_Control_Break for that column is produced by default.
    	p_Table_View_Mode IN VARCHAR2 DEFAULT 'TABLE_DATA_VIEW', -- TABLE_HIERARCHY/TABLE_DATA_VIEW
		p_Edit_Enabled IN OUT VARCHAR2,				-- YES, NO
		p_Edit_Mode IN OUT VARCHAR2,				-- YES, NO
		-- dependent on table name --
		p_Add_Rows IN OUT VARCHAR2,					-- YES, NO
		p_View_Mode IN OUT VARCHAR2,				-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		-- dependent on table name and view mode --
    	p_Order_by IN OUT VARCHAR2,					-- Example : NAME
    	p_Order_Direction IN OUT VARCHAR2,			-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options IN OUT VARCHAR2,				-- Example : B;K:C;K:C_B;K:C_C;K:D;K
		p_Rows IN OUT NUMBER,						-- 10, 20, 30...
		p_Columns_Limit IN OUT NUMBER,
		p_Select_Columns IN OUT VARCHAR2,
		p_Control_Break IN OUT VARCHAR2,
    	p_Calc_Totals IN OUT VARCHAR2,				-- YES, NO
    	p_Nested_Links IN OUT VARCHAR2				-- YES, NO
	);

	PROCEDURE Save_Report_Preferences (
		p_Report_ID 		IN NUMBER, 	
		p_Table_name 		IN VARCHAR2,		-- View or Table name
		p_Unique_Key_Column IN VARCHAR2,		-- primary keys cols of the table 
		p_View_Mode 		IN VARCHAR2,		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Order_by 			IN VARCHAR2,		-- Example : NAME
    	p_Order_Direction 	IN VARCHAR2,		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options 		IN VARCHAR2,		-- Example : B;K:C;K:C_B;K:C_C;K:D;K
		p_Rows 				IN NUMBER,			-- 10, 20, 30...
		p_Select_Columns 	IN VARCHAR2,
		p_Control_Break 	IN VARCHAR2,
    	p_Calc_Totals		IN VARCHAR2,		-- YES, NO
    	p_Nested_Links		IN VARCHAR2,		-- YES, NO
		p_App_Page_ID 		IN VARCHAR2 DEFAULT V('APP_PAGE_ID')
	);
	PROCEDURE Init_Relations_Tree;
	PROCEDURE Init_Search_Filter ( p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID') );
	PROCEDURE Reset_Search_Filter ( p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID') );
	PROCEDURE Add_Search_Filter ( p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID') );
	PROCEDURE Remove_Search_Filter (
		p_SEQ_ID IN NUMBER,
		p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID')
	);
	PROCEDURE Update_Search_Filter (
		p_SEQ_ID IN NUMBER,
		p_Search_Field IN VARCHAR2,
		p_Search_Operator IN VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Search_LOV IN VARCHAR2,
		p_Search_Active IN VARCHAR2,
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_PAGE_ID')
	);

	PROCEDURE Set_Sort_Preferences (
		p_Table_name IN VARCHAR2,					-- View or Table name
		p_View_Mode IN VARCHAR2,					-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
		-- dependent on table name and view mode --
    	p_Order_by IN VARCHAR2,						-- Example : NAME
    	p_Order_Direction IN VARCHAR2,				-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Control_Break IN VARCHAR2
	);

	PROCEDURE Set_Report_Preferences (
		p_Table_name 	IN VARCHAR2,					-- View or Table name
		-- dependent on table name --
    	p_Parent_Name   IN VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
		p_View_Mode 	IN VARCHAR2,					-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		-- dependent on table name and view mode --
    	p_Order_by 		IN VARCHAR2,						-- Example : NAME
    	p_Order_Direction IN VARCHAR2,				-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options IN VARCHAR2,					-- Example : B;K:C;K:C_B;K:C_C;K:D;K
		p_Rows 			IN NUMBER,							-- 10, 20, 30...
		p_Control_Break IN VARCHAR2,
    	p_Calc_Totals	IN VARCHAR2,
    	p_Nested_Links	IN VARCHAR2,
		p_Select_Columns IN VARCHAR2
	);

	PROCEDURE Set_Report_View_Mode_Prefs (
		p_Table_name IN VARCHAR2,					-- View or Table name
		-- dependent on table name --
		p_View_Mode IN VARCHAR2						-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
	);

	PROCEDURE Set_Rows_Preference (p_Rows IN VARCHAR2);
	PROCEDURE Set_Calc_Total_Preference (p_Calc_Totals IN VARCHAR2);
	PROCEDURE Set_Nested_Links_Preference (p_Nested_Links IN VARCHAR2);

	PROCEDURE Set_Columns_Preference (
		p_Table_name IN VARCHAR2,		
		p_View_Mode IN VARCHAR2,
		-- dependent on table name --
		p_Select_Columns IN VARCHAR2,
		p_Join_Options IN VARCHAR2					-- Example : B;K:C;K:C_B;K:C_C;K:D;K
	);

	FUNCTION Hide_Select_Column (
		p_Table_Name VARCHAR2,
		p_Column_Name VARCHAR2,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB;

	PROCEDURE Reset_Columns_Preference (
		p_Table_name IN VARCHAR2,		
    	p_Parent_Name VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
		p_View_Mode IN VARCHAR2
	);

	PROCEDURE Reset_All_Column_Preferences (
		p_Owner VARCHAR2 DEFAULT V('OWNER'),
    	p_Application_ID NUMBER DEFAULT NV('APP_ID'),
		p_Page_ID NUMBER DEFAULT 30
	);
	
	PROCEDURE Set_Parent_Key_Preference (
		p_Table_name IN VARCHAR2,		
		p_View_Mode IN VARCHAR2,
		-- dependent on table name --
		p_Parent_Key_Visible IN VARCHAR2
	);

	FUNCTION Get_Form_Search_Cond (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, QUERY, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,                -- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_RETURN_PAGE'), -- page id of current filter collection
		p_As_Lov_Query_Filter VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2;

	FUNCTION Get_Record_View_Query ( 					-- External : Form Query for tabular forms and reports
		p_Table_name IN VARCHAR2,						-- ===================================================
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value IN VARCHAR2,
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',		-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Compact_Queries VARCHAR2 DEFAULT 'YES', 		-- Generate Compact Queries to avoid overflow errors
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW, CALENDAR, TREE_VIEW
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 			-- YES, NO
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 		-- NEW_ROWS, TABLE, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Data_Format VARCHAR2 DEFAULT data_browser_select.FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Empty_Row VARCHAR2 DEFAULT 'YES',				-- YES, NO. Show one empty row when the result set is empty.
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT NV('APP_PAGE_ID'),	-- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW. Example: P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_DETAIL_TABLE,P32_DETAIL_KEY
    	p_Detail_Page_ID NUMBER DEFAULT 32,				-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,		-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,				-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Form_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_File_Page_ID NUMBER DEFAULT 31,				-- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,		-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_Search_Column_Name VARCHAR2 DEFAULT NULL,		-- Example : NAME
    	p_Search_Operator VARCHAR2 DEFAULT 'CONTAINS',	-- =,!=,IS NULL,IS NOT NULL,LIKE,NOT LIKE,IN,NOT IN,CONTAINS,NOT CONTAINS,REGEXP
    	p_Search_Field_Item VARCHAR2 DEFAULT NULL,		-- Example : P30_SEARCH
    	p_Search_Filter_Page_ID NUMBER DEFAULT NV('APP_PAGE_ID'),
    	p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : NAME
    	p_Order_Direction VARCHAR2 DEFAULT 'ASC',		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
    	p_Calc_Totals  VARCHAR2 DEFAULT 'NO',			-- YES, NO
    	p_Nested_Links VARCHAR2 DEFAULT 'NO',			-- YES, NO use nested table view instead of p_Link_Page_ID, p_Link_Parameter
    	p_Source_Query CLOB DEFAULT NULL 				-- Passed query for from clause
	) RETURN CLOB;

	FUNCTION Get_Record_Data_Cursor (					-- External : View Record Information
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit VARCHAR2 DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
    	p_File_Page_ID NUMBER DEFAULT 31,				-- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,		-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR'
	) RETURN data_browser_conf.tab_record_edit PIPELINED;

	FUNCTION Get_Record_View_Cursor ( 					-- External : View single record in form layout
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit VARCHAR2 DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
		p_Layout_Columns NUMBER DEFAULT 1,				-- 1 or 2 or 3
    	p_Data_Source VARCHAR2 DEFAULT NULL, 			-- NEW_ROWS, TABLE, MEMORY, COLLECTION. 
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,		-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_File_Page_ID NUMBER DEFAULT NULL				-- Page ID of target links to file preview in View_Mode FORM_VIEW
	)
	RETURN data_browser_conf.tab_3col_values PIPELINED;

	FUNCTION foreign_key_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL		-- default value for foreign key column
	)
	RETURN data_browser_conf.tab_foreign_key_value PIPELINED;

	FUNCTION foreign_key_cursor (
		p_Table_name IN VARCHAR2
	)
	RETURN data_browser_conf.tab_foreign_key_value PIPELINED;

	FUNCTION parents_list_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Item name for parent key id
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	-- Page ID of target links
    	p_Link_Items VARCHAR2 -- Item names for Parent_Table, Parent_Key_Column, Parent_Key_ID, Detail_Table, Detail_Key_Column, Detail_Key_ID
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED;

	FUNCTION parents_list_cursor (
		p_Table_name IN VARCHAR2,
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	-- Page ID of target links
    	p_Link_Items VARCHAR2, -- Item names for Parent_Table
    	p_Request VARCHAR2
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED;

	FUNCTION detail_key_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2
	)
	RETURN data_browser_conf.tab_foreign_key_value PIPELINED;
	g_Detail_Key_md5 	VARCHAR2(300) := 'X';
	g_Detail_Key_tab	data_browser_conf.tab_foreign_key_value;

	FUNCTION details_list_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2,
    	p_Detail_Table VARCHAR2 DEFAULT NULL,
    	p_Detail_Key_Col VARCHAR2 DEFAULT NULL,
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	-- Page ID of target links
    	p_Link_Items VARCHAR2 -- Item names for Parent_Table, Parent_Key_Column, Parent_Key_ID, Detail_Table, Detail_Key_Column, Detail_Key_ID
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED;

	FUNCTION Report_View_Modes_List (
		p_Table_name IN VARCHAR2,
    	p_View_Mode_Item VARCHAR2 
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED;

	PROCEDURE Reset_Cache;

	PROCEDURE Search_Table_Node (
		p_Search_Table IN VARCHAR2,
		p_Constraint_Name IN OUT VARCHAR2,
		p_Table_Name  OUT VARCHAR2,	-- NO_COPY can not be used here
    	p_Unique_Key_Column OUT VARCHAR2, 
		p_Parent_Name OUT VARCHAR2,
		p_Parent_Column OUT VARCHAR2,
		p_Parent_Key_Column OUT VARCHAR2,
		p_Tree_Current_Node OUT NUMBER,
		p_Tree_Path OUT VARCHAR2,
		p_Search_Exact IN VARCHAR2 DEFAULT 'YES'
	);

	PROCEDURE Load_Table_Node (	-- special load procedure for links from table tree view
		p_Constraint_Name IN VARCHAR2,
		p_Tree_Current_Node IN OUT NUMBER,
		p_Table_Name  OUT VARCHAR2,
    	p_Unique_Key_Column OUT VARCHAR2, 
		p_Parent_Name OUT VARCHAR2,
		p_Parent_Column OUT VARCHAR2,
		p_Parent_Key_Column OUT VARCHAR2,
		p_Tree_Path OUT VARCHAR2
	);

	PROCEDURE Load_Detail_View (	-- special load procedure for nested links from tabular form view
		p_Table_Name  IN VARCHAR2,
		p_Grand_Parent_Name IN VARCHAR2,
		p_Parent_Name IN VARCHAR2,
		p_Parent_Key_Column IN VARCHAR2,
		p_Constraint_Name OUT VARCHAR2,
		p_Tree_Current_Node OUT NUMBER,
		p_Tree_Path IN OUT VARCHAR2
	);

end data_browser_utl;
/

CREATE OR REPLACE PACKAGE data_browser_UI_Defaults
AUTHID CURRENT_USER
IS
	PROCEDURE UI_Defaults_update_table (
		p_Table_name IN VARCHAR2,
		p_View_Name IN VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	);

	PROCEDURE UI_Defaults_update_all_tables (
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	);

	PROCEDURE UI_Defaults_delete_all_tables (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	);
	
	FUNCTION UI_Defaults_export_table (
		p_Table_name IN VARCHAR2,
		p_View_Name IN VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'	-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
	) RETURN CLOB;

	FUNCTION UI_Defaults_export_all_tables (
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	) RETURN CLOB;

	PROCEDURE UI_Defaults_download_all_tables (
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	);

end data_browser_UI_Defaults;
/

CREATE OR REPLACE PACKAGE data_browser_edit
AUTHID CURRENT_USER
IS
	FUNCTION CM(p_Param_Name VARCHAR2) RETURN VARCHAR2;	-- remove comments for compact code generation

	FUNCTION Get_Current_Data_Source(
		p_Import_Mode VARCHAR2 DEFAULT 'NO',
		p_Add_Rows  VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2;

	FUNCTION FN_Change_Tracked_Column (
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2;
	
	FUNCTION FN_Change_Check_Use_Column (
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2;

	FUNCTION Add_Error_Call (
		p_Column_Name VARCHAR2,
		p_Apex_Item_Cell_Id VARCHAR2,
		p_Message VARCHAR2,
		p_Column_Header VARCHAR2,
		p1 VARCHAR2 DEFAULT NULL,
		p_Class VARCHAR2 DEFAULT 'DATA' -- DATA, UNIQUENESS, LOOKUP
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Get_Apex_Item_Cell_ID (
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number	NUMBER DEFAULT 1,
    	p_Data_Source 	VARCHAR2 DEFAULT 'TABLE',
    	p_Item_Type		VARCHAR2 DEFAULT 'TEXT'
	) RETURN VARCHAR2;

	PROCEDURE Form_Validation_Process (
		p_Table_name VARCHAR2,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE' 			-- TABLE, COLLECTION, NEW_ROWS
	);

	FUNCTION Get_Expression_Columns (p_Expr VARCHAR2) RETURN VARCHAR2;

	FUNCTION Validate_Form_Checks_PL_SQL (
		p_Table_name VARCHAR2,
		p_Key_Column	VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, COLLECTION, MEMORY
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB;

	FUNCTION Validate_Form_Checks (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Key_Value 	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 1000,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode	VARCHAR2 DEFAULT 'NO',
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2;

	PROCEDURE Validate_Imported_Data (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 50,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item IN VARCHAR2 DEFAULT NULL,			-- Name of item with foreign key vale
		p_Rows_Imported_Count NUMBER DEFAULT NULL,
		p_Inject_Defaults VARCHAR2 DEFAULT 'NO'				-- inject default values in empty cells of the collection
	);

	PROCEDURE Set_Import_Description (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 50,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
		p_Rows_Imported_Count NUMBER DEFAULT NULL
	);

	FUNCTION Match_Import_Description (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 50,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column
	) RETURN VARCHAR2; -- YES, NO

	PROCEDURE Get_Import_Description (
		p_Imported_Count OUT NUMBER,
		p_Remaining_Count OUT NUMBER,
		p_Validations_Count OUT NUMBER,
		p_Intersections_Count OUT NUMBER
	);

	FUNCTION Import_Description_cursor RETURN data_browser_conf.tab_apex_links_list PIPELINED;

	PROCEDURE Reset_Import_Description;

	FUNCTION Validate_Form_Field (
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Column_Value VARCHAR2 DEFAULT NULL,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Key_Value 	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

	PROCEDURE Form_Checks_Process (
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Column_Value VARCHAR2 DEFAULT NULL,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Key_Value 	VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'	-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
	);

	PROCEDURE Check_Unique_Key_Process (
		p_Table_name	VARCHAR2,
		p_Column_Name	VARCHAR2,
		p_Column_Value	VARCHAR2,
		p_Key_Column	VARCHAR2,
		p_Key_Value 	VARCHAR2
	);

	FUNCTION Convert_Raw_to_Varchar2 (
		p_Data_Type VARCHAR2,
		p_Raw_Data RAW
	) RETURN VARCHAR2 DETERMINISTIC;


	TYPE rec_table_Help_Text IS RECORD (
		VIEW_NAME					VARCHAR2(128),
		COLUMN_NAME					VARCHAR2(128),
		REF_TABLE_NAME				VARCHAR2(128),
		REF_COLUMN_NAME				VARCHAR2(128),
		HELP_TEXT					VARCHAR2(4000),
		COLUMN_ID					NUMBER
	);
	TYPE tab_table_Help_Text IS TABLE OF rec_table_Help_Text;

	FUNCTION Get_Form_Field_Help_Text ( -- External
		p_Table_name VARCHAR2,
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_View_Mode	VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'ALL', 				-- YES, NO, ALL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Show_Statistics VARCHAR2 DEFAULT 'NO',
		p_Show_Title VARCHAR2 DEFAULT 'YES',
		p_Delimiter VARCHAR2 DEFAULT CHR(10)
	) RETURN data_browser_edit.tab_table_Help_Text PIPELINED;

	PROCEDURE Get_Form_Field_Help_Text ( -- External
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2,
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_View_Mode	VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Show_Statistics VARCHAR2 DEFAULT 'NO',
		p_Show_Title VARCHAR2 DEFAULT 'YES',
		p_Delimiter VARCHAR2 DEFAULT CHR(10),
    	p_Help_Text OUT VARCHAR2,
    	p_Ref_Table_Name OUT VARCHAR2,
    	p_Ref_Column_Name OUT VARCHAR2
	);

	FUNCTION Get_Apex_Item_Rows_Call (	-- item rows count in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
		p_Caller		VARCHAR2 DEFAULT 'PL_SQL' -- PL_SQL / SQL
	) RETURN VARCHAR2;

	FUNCTION Get_Apex_Item_Call (	-- item name in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number	VARCHAR2 DEFAULT 'p_Row'
	) RETURN VARCHAR2;

	FUNCTION Get_Apex_Item_Ref (	-- item name in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number	NUMBER DEFAULT 1
	) RETURN VARCHAR2;

	FUNCTION Check_Item_Ref (
		p_Column_Ref VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2;

	PROCEDURE Clear_Application_Items;
	PROCEDURE Dump_Application_Items;

	FUNCTION Get_Apex_Item_Expr (
		p_Column_Expr_Type VARCHAR2,
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
		p_Column_Alias  VARCHAR2,	-- Column Alias expression
		p_Column_Name	VARCHAR2,	-- Column_Name
		p_Column_Label  VARCHAR2,	-- Column_Name
		p_Column_Expr 	VARCHAR2,	-- Column conversion expression with format mask
		p_Tools_html    VARCHAR2,
		p_Data_Default 	VARCHAR2,
		p_Format_Mask	VARCHAR2,
		p_LOV_Query		VARCHAR2,
		p_Check_Unique	VARCHAR2,
		p_Check_Range	VARCHAR2,
		p_Field_Length 	NUMBER,
		p_Nullable		VARCHAR2,
    	p_Data_Source	VARCHAR2 DEFAULT 'TABLE',	-- NEW_ROWS, TABLE, MEMORY, COLLECTION. if YES or MEMORY then SELECT ... FROM DUAL
    	p_Row_Number	NUMBER DEFAULT 1,
    	p_Report_Mode	VARCHAR2 DEFAULT 'NO',
    	p_Primary_Key_Call VARCHAR2
	) RETURN VARCHAR2;

	FUNCTION Get_Formated_Default (
		p_Column_Expr_Type VARCHAR2,
		p_Column_Alias  VARCHAR2,
		p_Column_Expr 	VARCHAR2,
		p_Data_Default 	VARCHAR2,
		p_Enquote 		VARCHAR2 DEFAULT 'YES'
	) RETURN VARCHAR2;

	-- result cache
    g_Describe_Edit_Cols_tab		data_browser_conf.tab_record_edit;
	g_Describe_Edit_Cols_md5 		VARCHAR2(300) := 'X';

	FUNCTION Get_Form_Edit_Cursor (	-- internal
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit VARCHAR2 DEFAULT 1000,
		p_Exclude_Audit_Columns VARCHAR2 DEFAULT 'NO',
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO, ALL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, MEMORY, COLLECTION. 
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW and not null, columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,			-- default value for foreign key column
		p_Primary_Key_Call VARCHAR2 DEFAULT NULL,
    	p_Ordering_Column_Tool  VARCHAR2 DEFAULT 'NO', 		-- YES, NO. Enable the rendering of row mover tool icons
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,			-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_File_Page_ID NUMBER DEFAULT NULL,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	    -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL				-- Parameter of target links
	)
	RETURN data_browser_conf.tab_record_edit PIPELINED;

	FUNCTION Get_Form_Edit_Query (							-- internal
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',			-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit NUMBER DEFAULT 1000,
		p_Exclude_Audit_Columns VARCHAR2 DEFAULT 'NO',
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
    	p_Ordering_Column_Tool  VARCHAR2 DEFAULT 'NO', 		-- YES, NO. Enable the rendering of row mover tool icons
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,			-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	    -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links 
    	p_File_Page_ID NUMBER DEFAULT NULL,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Source_Query CLOB DEFAULT NULL, 					-- Passed query for from clause
    	p_Comments VARCHAR2 DEFAULT NULL,					-- Comments
		p_Row_Count 	OUT NUMBER,
		p_Apex_Item_Rows_Call OUT NOCOPY VARCHAR2,
		p_Primary_Key_Call IN OUT NOCOPY VARCHAR2
	)
	RETURN CLOB;

    FUNCTION Get_Compare_Case_Insensitive (
        p_Column_Name VARCHAR2,
    	p_Element VARCHAR2,
    	p_Element_Type VARCHAR2 DEFAULT 'C', 	-- C,N  = CHar/Number
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', -- NEW_ROWS, TABLE, COLLECTION, MEMORY
        p_Data_Type VARCHAR2,
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Format_Mask VARCHAR2,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'Y', -- 'N' for HIDDEN items 
        p_Compare_Case_Insensitive VARCHAR2 DEFAULT data_browser_conf.Do_Compare_Case_Insensitive
    ) RETURN VARCHAR2;

    FUNCTION Get_Form_Foreign_Keys_PLSQL (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'IMPORT_VIEW',		-- IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_DML_Command VARCHAR2 DEFAULT 'UPDATE',			-- INSERT, UPDATE, LOOKUP
		p_Row_Number NUMBER DEFAULT 1,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES',
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Exec_Phase NUMBER DEFAULT 0
    ) RETURN CLOB;

	FUNCTION Validate_Form_Foreign_Keys (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'IMPORT_VIEW',		-- IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_DML_Command VARCHAR2 DEFAULT 'UPDATE',			-- INSERT, UPDATE, LOOKUP
		p_Row_Number NUMBER DEFAULT 1,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES',
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Exec_Phase NUMBER DEFAULT 0
	) RETURN VARCHAR2;

	PROCEDURE Get_Form_Changed_Check (						-- internal
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, COLLECTION, MEMORY
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES',
		p_Changed_Check_Condition OUT NOCOPY CLOB,
		p_Changed_Check_Plsql OUT NOCOPY CLOB
	);

	PROCEDURE Reset_Form_DML;

	FUNCTION Get_Form_Edit_DML (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Row_Operation VARCHAR2 DEFAULT 'UPDATE',			-- INSERT, UPDATE, DELETE, DUPLICATE, MOVE_ROWS, COPY_ROWS, MERGE_ROWS
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES'
	) RETURN CLOB;

	FUNCTION Get_Copy_Rows_DML (
		p_View_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Row_Operation VARCHAR2,				-- DUPLICATE, COPY_ROWS, MERGE_ROWS
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER,
		p_View_Mode IN VARCHAR2,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',	-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2, 				-- YES, NO
    	p_Parent_Name VARCHAR2,					-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2,			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2
	) RETURN CLOB;

	PROCEDURE Process_Form_DML (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
    	p_Unique_Key_Value IN OUT VARCHAR2,
    	p_Error_Message OUT VARCHAR2,
    	p_Rows_Affected OUT NUMBER,
		p_New_Row IN VARCHAR2 DEFAULT 'NO',					-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item IN VARCHAR2 DEFAULT NULL,			-- Name of item with foreign key vale
    	p_Copy_Target_Item IN VARCHAR2 DEFAULT NULL, 		-- Name of item with Target ID for MOVE_ROWS, COPY_ROWS
    	p_Request IN VARCHAR2, 								-- SAVE / CREATE / DELETE%, DUPLICATE%, MOVE%, MERGE%, COPY%
    	p_First_Row IN PLS_INTEGER DEFAULT 1,
    	p_Last_Row IN PLS_INTEGER DEFAULT 1,
    	p_Inject_Defaults VARCHAR2 DEFAULT 'NO'
	);

	PROCEDURE Process_Form_DML (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
    	p_Unique_Key_Value IN OUT NOCOPY VARCHAR2,
		p_New_Row IN VARCHAR2 DEFAULT 'NO',					-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item IN VARCHAR2 DEFAULT NULL,			-- Name of item with foreign key vale
    	p_Copy_Target_Item IN VARCHAR2 DEFAULT NULL, 		-- Name of item with Target ID for MOVE_ROWS, COPY_ROWS
    	p_Request IN VARCHAR2, 								-- SAVE / CREATE / DELETE%, DUPLICATE%, MOVE%, MERGE%, COPY%
    	p_First_Row IN PLS_INTEGER DEFAULT 1,
    	p_Last_Row IN PLS_INTEGER DEFAULT 1,
    	p_Inject_Defaults VARCHAR2 DEFAULT 'YES',
		p_Register_Apex_Error VARCHAR2 DEFAULT 'YES'
	);

	FUNCTION Get_Row_Selector RETURN VARCHAR2;

end data_browser_edit;
/
