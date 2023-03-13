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

/*
DROP TABLE USER_IMPORT_JOBS CASCADE CONSTRAINTS;
DROP SEQUENCE USER_IMPORT_JOBS_SEQ;
DROP PACKAGE import_utl;
DROP VIEW VUSER_TABLES_IMP;
DROP VIEW VUSER_TABLES_IMP_JOINS;

*/
CREATE OR REPLACE PACKAGE import_utl
IS
	g_linemaxsize			CONSTANT INTEGER	  := 4000;
	g_Importjob_ID				INTEGER;
	g_Export_Text_Limit			INTEGER			:= 1000;
	g_Import_Currency_Format	VARCHAR2(64)	:= '9G999G999G990D99';
	g_Import_Number_Format		VARCHAR2(64)	:= '9999999999999D9999999999';
	g_Import_NumChars			VARCHAR2(64)	:= 'NLS_NUMERIC_CHARACTERS = '',.''';
	g_Import_Float_Format		VARCHAR2(64)	:= 'TM9';
	g_Export_Date_Format		VARCHAR2(64)	:= 'DD.MM.YYYY';
	g_Import_DateTime_Format	VARCHAR2(64)	:= 'DD.MM.YYYY HH24:MI:SS';
	g_Import_Timestamp_Format	VARCHAR2(64)	:= 'DD.MM.YYYY HH24.MI.SSXFF';
	g_Insert_Foreign_Keys		VARCHAR2(5)		:= 'YES';	-- insert new foreign key values in insert trigger
	g_Search_Keys_Unique		VARCHAR2(5)		:= 'YES';	-- Unique Constraint is required for searching foreign key values
	g_Exclude_Blob_Columns		VARCHAR2(5)		:= 'YES';	-- Exclude Blob Columns from the produced projection column list
	g_Compare_Case_Insensitive	VARCHAR2(5)		:= 'NO';   -- compare Case insensitive foreign key values in insert trigger
	g_Compare_Return_String		VARCHAR2(300)	:= 'Differenz gefunden.';
	g_Compare_Return_Style		VARCHAR2(300)	:= 'background-color:PaleTurquoise;';
	g_Compare_Return_Style2		VARCHAR2(300)	:= 'background-color:PaleGreen;';
	g_Compare_Return_Style3		VARCHAR2(300)	:= 'background-color:Salmon;';
	g_Errors_Return_Style		VARCHAR2(300)	:= 'background-color:Moccasin;';
	g_Error_is_empty			VARCHAR2(64)	:= 'ist leer.';
	g_Error_is_longer_than		VARCHAR2(64)	:= '... Zeichenkette ist länger als';
	g_Error_is_no_currency		VARCHAR2(64)	:= 'ist kein Währungsbetrag.';
	g_Error_is_no_float			VARCHAR2(64)	:= 'ist keine Gleitkommazahl.';
	g_Error_is_no_integer		VARCHAR2(64)	:= 'ist keine Integerzahl.';
	g_Error_is_no_date			VARCHAR2(64)	:= 'ist keine gültiges Datum.';
	g_Error_is_no_timestamp		VARCHAR2(64)	:= 'ist kein gültiger Timestamp.';
	g_As_Of_Timestamp			VARCHAR2(5)		:= 'NO';	-- internal: Produces From clause with as of timestamp access

	TYPE rec_table_imp_trigger IS RECORD (
		SQL_TEXT				VARCHAR2(32767),
		SQL_EXISTS				VARCHAR2(32767),
		SQL_EXISTS2				VARCHAR2(32767),
		CHECK_CONSTRAINT_TYPE	CHAR(1),
		DEFAULTS_MISSING		NUMBER,
		TABLE_NAME				VARCHAR2(128), 
		COLUMN_NAME				VARCHAR2(128), 
		POSITION				NUMBER,
		POSITION2				NUMBER,
		R_VIEW_NAME				VARCHAR2(128)
	);
	TYPE tab_table_imp_trigger IS TABLE OF rec_table_imp_trigger;

	FUNCTION FN_Pipe_table_imp_trigger (
		p_Table_Name VARCHAR2,
		p_Data_Format VARCHAR2 DEFAULT 'NATIVE', -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_use_NLS_params VARCHAR2 DEFAULT 'Y',
		p_Use_Group_Separator VARCHAR2 DEFAULT 'Y',
		p_Report_Mode VARCHAR2 DEFAULT 'YES'
	)
	RETURN tab_table_imp_trigger PIPELINED;

	TYPE rec_table_imp_link IS RECORD (
		TABLE_NAME				VARCHAR2(128), 
		U_CONSTRAINT_NAME		VARCHAR2(128), 
		SQL_TEXT				VARCHAR2(32767)
	);
	TYPE tab_table_imp_link IS TABLE OF rec_table_imp_link;

	FUNCTION FN_Pipe_table_imp_link (p_Table_Name VARCHAR2)
	RETURN tab_table_imp_link PIPELINED;

	TYPE rec_table_imp_cols IS RECORD (
		TABLE_NAME				VARCHAR2(128),
		COLUMN_NAME				VARCHAR2(128),
		COLUMN_EXPR				VARCHAR2(32767),
		COLUMN_COMPARE 			VARCHAR2(32767),
		COLUMN_MARKUP			VARCHAR2(32767),
		COLUMN_CHECK_EXPR		VARCHAR2(32767),
		COLUMN_ID				NUMBER,
		POSITION				NUMBER,
		IMP_COLUMN_NAME			VARCHAR2(128),
		COLUMN_ALIGN			VARCHAR2(10),
		COLUMN_EXPR_TYPE		VARCHAR2(128),
		HAS_DEFAULT				VARCHAR2(1),
		IS_VIRTUAL_COLUMN		VARCHAR2(1),
		IS_DATETIME				VARCHAR2(1),
		DATA_TYPE				VARCHAR2(128), 
		DATA_SCALE				NUMBER,
		DATA_PRECISION			NUMBER,
		CHAR_LENGTH				NUMBER,
		NULLABLE				VARCHAR2(1),
		R_VIEW_NAME				VARCHAR2(128), 
		REF_COLUMN_NAME			VARCHAR2(128), 
		TABLE_ALIAS				VARCHAR2(10)
	);
	TYPE tab_table_imp_cols IS TABLE OF rec_table_imp_cols;

	FUNCTION FN_Pipe_table_imp_cols (
		p_Table_Name VARCHAR2, 
		p_Report_Mode VARCHAR2 DEFAULT 'YES',
		p_Data_Format VARCHAR2 DEFAULT 'NATIVE'
	)
	RETURN tab_table_imp_cols PIPELINED;

	PROCEDURE Set_Imp_Formats (
		p_Export_Text_Limit			INTEGER		DEFAULT NULL,	-- length limit for Text in each column
		p_Import_Currency_Format	VARCHAR2	DEFAULT NULL,	-- Import Currency Format Mask
		p_Import_Number_Format		VARCHAR2	DEFAULT NULL,	-- Import Number Format Mask
		p_Import_NumChars			VARCHAR2	DEFAULT NULL,	-- Import NumChars Format Mask
		p_Import_Float_Format		VARCHAR2	DEFAULT NULL,	-- Import Float Format Mask
		p_Export_Date_Format		VARCHAR2	DEFAULT NULL,	-- Export Date Format Mask
		p_Import_DateTime_Format	VARCHAR2	DEFAULT NULL,	-- Import DateTime Format Mask
		p_Import_Timestamp_Format	VARCHAR2	DEFAULT NULL,	-- Import Timestamp Format Mask
		p_Insert_Foreign_Keys		VARCHAR2	DEFAULT NULL,	-- insert new foreign key values in insert trigger
		p_Search_Keys_Unique		VARCHAR2	DEFAULT NULL,	-- Unique Constraint is required for searching foreign key values
		p_Exclude_Blob_Columns		VARCHAR2	DEFAULT NULL,	-- Exclude Blob Columns from generated Views
		p_Compare_Case_Insensitive	VARCHAR2	DEFAULT NULL,	-- compare Case insensitive foreign key values in insert trigger
		p_Compare_Return_String		VARCHAR2	DEFAULT NULL,	-- 'Differenz gefunden.'
		p_Compare_Return_Style		VARCHAR2	DEFAULT NULL,	-- CSS style for marking differences
		p_Compare_Return_Style2		VARCHAR2	DEFAULT NULL,	-- CSS style for marking differences
		p_Compare_Return_Style3		VARCHAR2	DEFAULT NULL,	-- CSS style for marking differences
		p_Errors_Return_Style		VARCHAR2	DEFAULT NULL,	-- CSS style for marking errors
		p_Error_is_empty			VARCHAR2	DEFAULT NULL,	-- 'ist leer.'
		p_Error_is_longer_than		VARCHAR2	DEFAULT NULL,	-- '... Zeichenkette ist länger als'
		p_Error_is_no_currency		VARCHAR2	DEFAULT NULL,	-- 'ist kein Währungsbetrag.'
		p_Error_is_no_float			VARCHAR2	DEFAULT NULL,	-- 'ist keine Gleitkommazahl.'
		p_Error_is_no_integer		VARCHAR2	DEFAULT NULL,	-- 'ist keine Integerzahl.'
		p_Error_is_no_date			VARCHAR2	DEFAULT NULL,	-- 'ist keine gültiges Datum.'
		p_Error_is_no_timestamp		VARCHAR2	DEFAULT NULL	-- 'ist kein gültiger Timestamp.'
	);
	PROCEDURE Load_Imp_Job_Formats (p_Importjob_ID INTEGER);
	FUNCTION Get_ImpTextLimit  RETURN INTEGER;
	FUNCTION Get_Import_Currency_Format RETURN VARCHAR2;
	FUNCTION Get_Import_NumChars RETURN VARCHAR2;
	FUNCTION Get_Import_Float_Format RETURN VARCHAR2;
	FUNCTION Get_Import_Date_Format RETURN VARCHAR2;
	FUNCTION Get_Import_Timestamp_Format RETURN VARCHAR2;
	FUNCTION Get_Insert_Foreign_Keys RETURN VARCHAR2;
	FUNCTION Get_Search_Keys_Unique RETURN VARCHAR2;
	FUNCTION Get_Exclude_Blob_Columns RETURN VARCHAR2;
	PROCEDURE Set_As_Of_Timestamp (p_As_Of_Timestamp VARCHAR2);
	FUNCTION Get_As_Of_Timestamp RETURN VARCHAR2;
	FUNCTION Get_Error_is_empty RETURN VARCHAR2;
	FUNCTION Get_Error_is_longer_than RETURN VARCHAR2;
	FUNCTION Get_Error_is_no_currency RETURN VARCHAR2;
	FUNCTION Get_Error_is_no_float RETURN VARCHAR2;
	FUNCTION Get_Error_is_no_integer RETURN VARCHAR2;
	FUNCTION Get_Error_is_no_date RETURN VARCHAR2;
	FUNCTION Get_Error_is_no_timestamp RETURN VARCHAR2;
	FUNCTION Get_Compare_Case_Insensitive (
		p_Column_Name VARCHAR2,
		p_Search_Name VARCHAR2,
		p_DATA_TYPE VARCHAR2 DEFAULT 'VARCHAR2')
	RETURN VARCHAR2;
	FUNCTION Compare_Data ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Compare_Upper ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Compare_Number ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Compare_Date ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Compare_Timestamp ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_CompareFunction( p_DATA_TYPE VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Markup_Data (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Markup_Upper (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Markup_Number (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Markup_Date (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Markup_Timestamp (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_MarkupFunction( p_DATA_TYPE VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION New_Job_ID	 ( p_Table_Name VARCHAR2 ) RETURN INTEGER;
	FUNCTION Current_Job_ID RETURN INTEGER;
	PROCEDURE Set_Job_ID ( p_Importjob_ID INTEGER);
	FUNCTION GetImpCurrencyCols (p_Value VARCHAR2) RETURN NUMBER;
	FUNCTION GetImpIntegerCols	(p_Value VARCHAR2) RETURN NUMBER;
	FUNCTION GetImpFloatCols  (p_Value VARCHAR2) RETURN NUMBER;
	FUNCTION GetImpDateCols (p_Value VARCHAR2) RETURN DATE;
	FUNCTION GetImpTimestampCols  (p_Value VARCHAR2) RETURN TIMESTAMP;
	FUNCTION Get_ImportColFunction (
		p_DATA_TYPE VARCHAR2,
		p_DATA_SCALE NUMBER,
		p_CHAR_LENGTH NUMBER,
		p_COLUMN_NAME VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION is_Char_Limited(p_Value VARCHAR2, p_Char_Length INTEGER) RETURN VARCHAR2;
	FUNCTION is_Char_Limited_Not_Null(p_Value VARCHAR2, p_Char_Length INTEGER) RETURN VARCHAR2;
	FUNCTION is_Currency(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Currency_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Float(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Float_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Integer(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Integer_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Date(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Date_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Timestamp(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION is_Timestamp_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2;
	FUNCTION Get_ImpColumnCheck (
		p_DATA_TYPE VARCHAR2,
		p_DATA_SCALE NUMBER,
		p_CHAR_LENGTH NUMBER,
		p_NULLABLE VARCHAR2,
		p_COLUMN_NAME VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;
	FUNCTION Get_Table_Column_List (
		p_Table_Name VARCHAR2,
		p_Delimiter VARCHAR2 DEFAULT ', ',
		p_Columns_Limit INTEGER DEFAULT 1000
	) RETURN CLOB;
	FUNCTION Get_Imp_Table_View (
    	p_Table_Name VARCHAR2,
    	p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
    	p_Data_Format VARCHAR2 DEFAULT 'FORM',	-- FORM, CSV, NATIVE. Format of the final projection columns.
    	p_Report_Mode VARCHAR2 DEFAULT 'YES'
    ) RETURN CLOB;
    FUNCTION Get_Imp_Table_View_Comments (
    	p_Table_Name VARCHAR2,
		p_Data_Format VARCHAR2 DEFAULT 'NATIVE', -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Report_Mode VARCHAR2 DEFAULT 'YES'
    ) RETURN CLOB;
	FUNCTION Get_Imp_Table_View_trigger (
    	p_Table_Name VARCHAR2,
		p_Data_Format VARCHAR2 DEFAULT 'NATIVE', -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Report_Mode VARCHAR2 DEFAULT 'YES'
    ) RETURN CLOB;
	PROCEDURE Download_imp_views (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Data_Format VARCHAR2 DEFAULT 'NATIVE',	-- FORM, CSV, NATIVE. Format of the final projection columns.
		p_use_NLS_params VARCHAR2 DEFAULT 'Y',
		p_Use_Group_Separator VARCHAR2 DEFAULT 'Y',
		p_Report_Mode VARCHAR2 DEFAULT 'YES',
		p_Add_Comments VARCHAR2 DEFAULT 'YES'
	);

	FUNCTION Get_Imp_Table_View_Check ( p_Table_Name VARCHAR2 ) RETURN CLOB;
	FUNCTION Get_Imp_Table_View_Msg ( p_Table_Name VARCHAR2 ) RETURN CLOB;
	FUNCTION Get_Imp_Table_Link ( p_Table_Name VARCHAR2, p_Import_Job_ID VARCHAR2 ) RETURN CLOB;
	FUNCTION Get_Imp_Query_Diff (
		p_Table_Name VARCHAR2,
		p_Columns_Limit INTEGER DEFAULT 1000
	) RETURN CLOB;
	FUNCTION Get_Imp_Markup_Column_List ( p_Table_Name VARCHAR2 ) RETURN VARCHAR2;
	FUNCTION Get_Imp_Markup_Query (
		p_Table_Name VARCHAR2,
		p_Import_Job_ID NUMBER DEFAULT 1000,
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_Filter_Errors VARCHAR2 DEFAULT 'NO',
		p_Filter_Differences VARCHAR2 DEFAULT 'NO',
		p_Filter_New_Rows VARCHAR2 DEFAULT 'NO',
		p_Filter_Missing_Rows VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB;
	FUNCTION Get_History_Markup_Query (
		p_Table_Name VARCHAR2,
		p_Import_Job_ID NUMBER DEFAULT 1000,
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_Filter_Differences VARCHAR2 DEFAULT 'NO',
		p_Filter_New_Rows VARCHAR2 DEFAULT 'NO',
		p_Filter_Missing_Rows VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB;
	FUNCTION Get_Imp_Table_View_Diff ( p_Table_Name VARCHAR2 ) RETURN CLOB;
	FUNCTION Get_Imp_Table_Test (
		p_Table_Name VARCHAR2,
		p_Import_Job_ID NUMBER DEFAULT NULL,
		p_Delete_Rows VARCHAR2 DEFAULT 'YES'
	) RETURN CLOB;
	FUNCTION Get_Imp_Check_Query (
		p_Table_Name VARCHAR2,
		p_Import_Job_ID NUMBER DEFAULT 1000,
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_Filter_Errors VARCHAR2 DEFAULT 'NO',
		p_Filter_Differences VARCHAR2 DEFAULT 'NO',
		p_Filter_New_Rows VARCHAR2 DEFAULT 'NO',
		p_Filter_Missing_Rows VARCHAR2 DEFAULT 'NO',
		p_Filter_Combine VARCHAR2 DEFAULT 'UNION'
	) RETURN CLOB;
	PROCEDURE Generate_Imp_Table (
		p_Table_Name VARCHAR2,
		p_Recreate_Import_Table VARCHAR2 DEFAULT 'YES'
	);
	PROCEDURE Generate_Import_Views (
		p_Table_Name VARCHAR2
	);
	PROCEDURE Generate_Updatable_Views (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Data_Format VARCHAR2 DEFAULT 'NATIVE',	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    	p_Report_Mode VARCHAR2 DEFAULT 'YES',
		p_Add_Comments VARCHAR2 DEFAULT 'YES'
	);
	PROCEDURE Link_Import_Table (
		p_Table_Name	IN VARCHAR2,
		p_Import_Job_ID IN NUMBER,
		p_Row_Count		OUT NUMBER
	);
	PROCEDURE Import_From_Imp_Table (
		p_Table_Name	IN VARCHAR2,
		p_Import_Job_ID IN NUMBER,
		p_Row_Count		OUT NUMBER
	);
	PROCEDURE Export_To_Imp_Table (
		p_Table_Name	IN VARCHAR2,
		p_Import_Job_ID IN NUMBER,
		p_Row_Limit		IN NUMBER DEFAULT 1000000,
		p_Row_Count		OUT NUMBER
	);
	FUNCTION Split_Clob(
		p_clob IN CLOB,
		p_delimiter IN VARCHAR2
	) RETURN sys.odciVarchar2List PIPELINED;	-- VARCHAR2(4000)
	FUNCTION Blob_to_Clob(
		p_blob IN BLOB,
		p_blob_charset IN VARCHAR2 DEFAULT NULL
	)  return CLOB;
	PROCEDURE Filter_Csv_File (
		p_File_Name			IN VARCHAR2,
		p_Import_From		IN OUT VARCHAR2, -- UPLOAD or PASTE
		p_Clob_Content		IN CLOB DEFAULT NULL,
		p_Column_Delimiter	IN VARCHAR2 DEFAULT '\t',
		p_Row_Rows_Limit	IN NUMBER DEFAULT 100,
		p_Return_Bad_Rows	OUT CLOB
	);
	PROCEDURE Refresh_MViews (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	);
END import_utl;
/


-- Table Data Interface Descriptions
CREATE OR REPLACE VIEW VUSER_TABLES_IMP (TABLE_NAME, VIEW_NAME, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME,
	IMPORT_TRIGGER_NAME, IMPORT_VIEW_CHECK_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HISTORY_VIEW_NAME,
	IMP_TABLE_EXISTS, HAS_SCALAR_PRIMARY_KEY, HAS_SCALAR_KEY, IS_REFERENCED, SEARCH_KEY_COLS,
	DESCRIPTION_COLUMNS, UNIQUE_COLUMNS, DEFAULTS_MISSING, VIEWS_STATUS)
AS
  WITH TABLES_Q AS (
		SELECT S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME || '_IMP' IMP_TABLE_NAME,
				'V' || S.SHORT_NAME || '_TS' HISTORY_VIEW_NAME,
				case when S.IMP_TABLE_NAME IS NOT NULL then 'YES' else 'NO' end IMP_TABLE_EXISTS,
				S.HAS_SCALAR_PRIMARY_KEY, S.HAS_SCALAR_KEY, S.SEARCH_KEY_COLS,
				CAST(S.DESCRIPTION_COLUMNS AS VARCHAR2(4000)) DESCRIPTION_COLUMNS,
				CAST(LISTAGG(U.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY U.POSITION) AS VARCHAR2(1024)) UNIQUE_COLUMNS
		FROM (
			SELECT S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME, T.TABLE_NAME IMP_TABLE_NAME, 
				S.HAS_SCALAR_PRIMARY_KEY, S.HAS_SCALAR_KEY, S.SEARCH_KEY_COLS,
				LISTAGG(D.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY D.COLUMN_ID) DESCRIPTION_COLUMNS
			FROM MVDATA_BROWSER_VIEWS S
			LEFT OUTER JOIN USER_TABLES T ON T.TABLE_NAME = S.SHORT_NAME || '_IMP'
			LEFT OUTER JOIN MVDATA_BROWSER_D_REFS D ON D.TABLE_NAME = S.VIEW_NAME
			GROUP BY S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME, T.TABLE_NAME, 
				S.HAS_SCALAR_PRIMARY_KEY, S.HAS_SCALAR_KEY, S.SEARCH_KEY_COLS
		) S
		LEFT OUTER JOIN MVDATA_BROWSER_U_REFS U ON U.VIEW_NAME = S.VIEW_NAME AND U.RANK = 1
		GROUP BY S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME, S.IMP_TABLE_NAME, 
			S.HAS_SCALAR_PRIMARY_KEY, S.HAS_SCALAR_KEY, S.SEARCH_KEY_COLS, S.DESCRIPTION_COLUMNS
	), COLUMNS_Q AS (
		SELECT C.TABLE_NAME, C.COLUMN_NAME, C.COLUMN_ID
		FROM USER_TAB_COLUMNS C
		JOIN MVDATA_BROWSER_VIEWS S ON S.TABLE_NAME = C.TABLE_NAME
		WHERE C.NULLABLE = 'N' AND C.DEFAULT_LENGTH IS NULL
		AND C.COLUMN_NAME != S.SEARCH_KEY_COLS
		AND NOT EXISTS (
			SELECT 1
			FROM MVDATA_BROWSER_D_REFS R
			WHERE R.TABLE_NAME = C.TABLE_NAME
			AND R.COLUMN_NAME = C.COLUMN_NAME
			UNION ALL
			SELECT 1
			FROM MVDATA_BROWSER_U_REFS R -- check all unique key columns
			WHERE R.VIEW_NAME = C.TABLE_NAME
			AND R.COLUMN_NAME = C.COLUMN_NAME
			AND R.RANK = 1
		)
	)
  SELECT TABLE_NAME, VIEW_NAME, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME,
	IMPORT_TRIGGER_NAME, IMPORT_VIEW_CHECK_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HISTORY_VIEW_NAME,
	IMP_TABLE_EXISTS, HAS_SCALAR_PRIMARY_KEY, HAS_SCALAR_KEY,
	case when EXISTS (
		SELECT 1 -- key is referenced in a foreign key clause
		FROM MVDATA_BROWSER_FKEYS T
		WHERE T.R_TABLE_NAME = S.TABLE_NAME
	) then 'YES' else 'NO' end	IS_REFERENCED,
	SEARCH_KEY_COLS,
	DESCRIPTION_COLUMNS, UNIQUE_COLUMNS, DEFAULTS_MISSING,
	case when (
		SELECT COUNT(*)
		FROM USER_OBJECTS U
		WHERE STATUS = 'VALID'
		AND OBJECT_TYPE = 'VIEW' AND OBJECT_NAME IN (IMPORT_VIEW_NAME, IMPORT_VIEW_CHECK_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HISTORY_VIEW_NAME)
		) = 5 then 'VALID' else 'INVALID' end VIEWS_STATUS
FROM (
	SELECT S.TABLE_NAME, S.VIEW_NAME,
		S.IMP_TABLE_NAME					IMPORT_TABLE_NAME,
		'V' || S.IMP_TABLE_NAME				IMPORT_VIEW_NAME,
		'V' || S.IMP_TABLE_NAME || '_TR' IMPORT_TRIGGER_NAME,
		'V' || S.IMP_TABLE_NAME || '_CK' IMPORT_VIEW_CHECK_NAME,
		'V' || S.IMP_TABLE_NAME || '_MSG' IMPORT_VIEW_MSG_NAME,
		'V' || S.IMP_TABLE_NAME || '_DIF' IMPORT_VIEW_DIF_NAME,
		HISTORY_VIEW_NAME,
		S.IMP_TABLE_EXISTS,
		S.HAS_SCALAR_PRIMARY_KEY, S.HAS_SCALAR_KEY,
		S.SEARCH_KEY_COLS,
		S.DESCRIPTION_COLUMNS, S.UNIQUE_COLUMNS,
		( SELECT LISTAGG(C.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY C.COLUMN_ID)
		  FROM COLUMNS_Q C WHERE S.TABLE_NAME = C.TABLE_NAME
		) DEFAULTS_MISSING
	FROM TABLES_Q S
) S;

-- generate from clause to access user tables with resolved foreign key connections
CREATE OR REPLACE VIEW VUSER_TABLES_IMP_JOINS (
	TABLE_NAME, COLUMN_NAME, SQL_TEXT, COLUMN_ID, POSITION, MATCHING, TABLE_ALIAS, R_TABLE_NAME) AS
SELECT DISTINCT S.TABLE_NAME, T.COLUMN_NAME, T.SQL_TEXT, T.COLUMN_ID, T.POSITION, T.MATCHING, T.TABLE_ALIAS, T.R_TABLE_NAME
FROM MVDATA_BROWSER_VIEWS S, table(
		data_browser_joins.Get_Detail_Table_Joins_Cursor(
		p_Table_Name =>	 S.VIEW_NAME
	)
) T;


