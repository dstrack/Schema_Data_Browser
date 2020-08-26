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
DROP VIEW VUSER_TABLES_IMP_COLUMNS;
DROP VIEW VUSER_TABLES_IMP_LINK;

DROP MATERIALIZED VIEW MVUSER_TABLES_IMP_TRIGGER;
*/
create or replace PACKAGE import_utl
IS
	g_linemaxsize     		CONSTANT INTEGER 	  := 4000;
    g_Importjob_ID          	INTEGER;
    g_Export_Text_Limit         INTEGER     	:= 1000;
    g_Import_Currency_Format    VARCHAR2(64)    := '9G999G999G990D99';
    g_Import_Number_Format      VARCHAR2(64)    := '9999999999999D9999999999';
    g_Import_NumChars       	VARCHAR2(64)    := 'NLS_NUMERIC_CHARACTERS = '',.''';
    g_Import_Float_Format       VARCHAR2(64)    := 'TM9';
    g_Export_Date_Format    	VARCHAR2(64)    := 'DD.MM.YYYY';
    g_Import_DateTime_Format	VARCHAR2(64)    := 'DD.MM.YYYY HH24:MI:SS';
    g_Import_Timestamp_Format   VARCHAR2(64)    := 'DD.MM.YYYY HH24.MI.SSXFF';
    g_Insert_Foreign_Keys   	VARCHAR2(5)     := 'YES';   -- insert new foreign key values in insert trigger
    g_Search_Keys_Unique 		VARCHAR2(5)     := 'YES'; 	-- Unique Constraint is required for searching foreign key values
	g_Exclude_Blob_Columns  	VARCHAR2(5)     := 'YES';	-- Exclude Blob Columns from the produced projection column list
    g_Compare_Case_Insensitive 	VARCHAR2(5)  	:= 'NO';   -- compare Case insensitive foreign key values in insert trigger
	g_Compare_Return_String  	VARCHAR2(300)   := 'Differenz gefunden.';
	g_Compare_Return_Style  	VARCHAR2(300)   := 'background-color:PaleTurquoise;';
	g_Compare_Return_Style2  	VARCHAR2(300)   := 'background-color:PaleGreen;';
	g_Compare_Return_Style3  	VARCHAR2(300)   := 'background-color:Salmon;';
	g_Errors_Return_Style 		VARCHAR2(300)   := 'background-color:Moccasin;';
	g_Error_is_empty			VARCHAR2(64)    := 'ist leer.';
	g_Error_is_longer_than		VARCHAR2(64)    := '... Zeichenkette ist länger als';
	g_Error_is_no_currency		VARCHAR2(64)    := 'ist kein Währungsbetrag.';
	g_Error_is_no_float			VARCHAR2(64)    := 'ist keine Gleitkommazahl.';
	g_Error_is_no_integer		VARCHAR2(64)    := 'ist keine Integerzahl.';
	g_Error_is_no_date			VARCHAR2(64)    := 'ist keine gültiges Datum.';
	g_Error_is_no_timestamp		VARCHAR2(64)    := 'ist kein gültiger Timestamp.';
    g_As_Of_Timestamp 			VARCHAR2(5)		:= 'NO';	-- internal: Produces From clause with as of timestamp access
    PROCEDURE Set_Imp_Formats (
        p_Export_Text_Limit         INTEGER     DEFAULT NULL,	-- length limit for Text in each column
        p_Import_Currency_Format    VARCHAR2    DEFAULT NULL,	-- Import Currency Format Mask
        p_Import_Number_Format      VARCHAR2    DEFAULT NULL,	-- Import Number Format Mask
        p_Import_NumChars       	VARCHAR2    DEFAULT NULL,	-- Import NumChars Format Mask
        p_Import_Float_Format   	VARCHAR2    DEFAULT NULL,	-- Import Float Format Mask
        p_Export_Date_Format      	VARCHAR2    DEFAULT NULL,	-- Export Date Format Mask
        p_Import_DateTime_Format    VARCHAR2    DEFAULT NULL,	-- Import DateTime Format Mask
        p_Import_Timestamp_Format   VARCHAR2    DEFAULT NULL,	-- Import Timestamp Format Mask
		p_Insert_Foreign_Keys   	VARCHAR2    DEFAULT NULL,   -- insert new foreign key values in insert trigger
		p_Search_Keys_Unique	  	VARCHAR2    DEFAULT NULL,   -- Unique Constraint is required for searching foreign key values
		p_Exclude_Blob_Columns  	VARCHAR2    DEFAULT NULL,	-- Exclude Blob Columns from generated Views
		p_Compare_Case_Insensitive 	VARCHAR2 	DEFAULT NULL,   -- compare Case insensitive foreign key values in insert trigger
		p_Compare_Return_String 	VARCHAR2 	DEFAULT NULL,	-- 'Differenz gefunden.'
		p_Compare_Return_Style  	VARCHAR2    DEFAULT NULL,	-- CSS style for marking differences
		p_Compare_Return_Style2  	VARCHAR2    DEFAULT NULL,	-- CSS style for marking differences
		p_Compare_Return_Style3  	VARCHAR2    DEFAULT NULL,	-- CSS style for marking differences
		p_Errors_Return_Style 		VARCHAR2    DEFAULT NULL,	-- CSS style for marking errors
		p_Error_is_empty			VARCHAR2    DEFAULT NULL,	-- 'ist leer.'
		p_Error_is_longer_than		VARCHAR2    DEFAULT NULL,	-- '... Zeichenkette ist länger als'
		p_Error_is_no_currency		VARCHAR2    DEFAULT NULL,	-- 'ist kein Währungsbetrag.'
		p_Error_is_no_float			VARCHAR2    DEFAULT NULL,	-- 'ist keine Gleitkommazahl.'
		p_Error_is_no_integer		VARCHAR2    DEFAULT NULL,	-- 'ist keine Integerzahl.'
		p_Error_is_no_date			VARCHAR2    DEFAULT NULL,	-- 'ist keine gültiges Datum.'
		p_Error_is_no_timestamp		VARCHAR2    DEFAULT NULL	-- 'ist kein gültiger Timestamp.'
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
    FUNCTION New_Job_ID  ( p_Table_Name VARCHAR2 ) RETURN INTEGER;
    FUNCTION Current_Job_ID RETURN INTEGER;
	PROCEDURE Set_Job_ID ( p_Importjob_ID INTEGER);
    FUNCTION GetImpCurrencyCols (p_Value VARCHAR2) RETURN NUMBER;
    FUNCTION GetImpIntegerCols  (p_Value VARCHAR2) RETURN NUMBER;
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
    	p_Data_Format VARCHAR2 DEFAULT 'FORM',	-- FORM, CSV, NATIVE. Format of the final projection columns.
    	p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO'
    ) RETURN CLOB;
    FUNCTION Get_Imp_Table_View_trigger ( p_Table_Name VARCHAR2 ) RETURN CLOB;
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
    PROCEDURE Link_Import_Table (
        p_Table_Name 	IN VARCHAR2,
    	p_Import_Job_ID IN NUMBER,
        p_Row_Count 	OUT NUMBER
    );
    PROCEDURE Import_From_Imp_Table (
        p_Table_Name 	IN VARCHAR2,
    	p_Import_Job_ID IN NUMBER,
        p_Row_Count 	OUT NUMBER
    );
    PROCEDURE Export_To_Imp_Table (
        p_Table_Name 	IN VARCHAR2,
    	p_Import_Job_ID IN NUMBER,
    	p_Row_Limit 	IN NUMBER DEFAULT 1000000,
        p_Row_Count 	OUT NUMBER
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
		p_Column_Delimiter  IN VARCHAR2 DEFAULT '\t',
		p_Row_Rows_Limit	IN NUMBER DEFAULT 100,
		p_Return_Bad_Rows 	OUT CLOB
	);
    PROCEDURE Refresh_MViews (
    	p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
    );
END import_utl;
/

DECLARE
	PROCEDURE DROP_MVIEW( p_MView_Name VARCHAR2) IS
	BEGIN
		EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW ' || p_MView_Name;
	EXCEPTION
	  WHEN OTHERS THEN
		IF SQLCODE != -12003 THEN
			RAISE;
		END IF;
	END;
BEGIN
	DROP_MVIEW('MVUSER_TABLES_IMP_TRIGGER');
END;
/


-- Table Data Interface Descriptions
CREATE OR REPLACE VIEW VUSER_TABLES_IMP (TABLE_NAME, VIEW_NAME, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME,
	IMPORT_TRIGGER_NAME, IMPORT_VIEW_CHECK_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HISTORY_VIEW_NAME,
	IMP_TABLE_EXISTS, HAS_SCALAR_PRIMARY_KEY, IS_REFERENCED, PRIMARY_KEY_COLS,
	DESCRIPTION_COLUMNS, UNIQUE_COLUMNS, DEFAULTS_MISSING, VIEWS_STATUS)
AS
  WITH TABLES_Q AS (
		SELECT S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME || '_IMP' IMP_TABLE_NAME,
				'V' || S.SHORT_NAME || '_TS' HISTORY_VIEW_NAME,
				case when S.IMP_TABLE_NAME IS NOT NULL then 'YES' else 'NO' end IMP_TABLE_EXISTS,
				S.HAS_SCALAR_PRIMARY_KEY, S.PRIMARY_KEY_COLS,
                CAST(S.DESCRIPTION_COLUMNS AS VARCHAR2(4000)) DESCRIPTION_COLUMNS,
				CAST(LISTAGG(U.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY U.POSITION) AS VARCHAR2(1024)) UNIQUE_COLUMNS
		FROM (
			SELECT S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME, T.TABLE_NAME IMP_TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY,
				S.PRIMARY_KEY_COLS,
				LISTAGG(D.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY D.COLUMN_ID) DESCRIPTION_COLUMNS
			FROM MVDATA_BROWSER_VIEWS S
			LEFT OUTER JOIN USER_TABLES T ON T.TABLE_NAME = S.SHORT_NAME || '_IMP'
			LEFT OUTER JOIN MVDATA_BROWSER_D_REFS D ON D.TABLE_NAME = S.VIEW_NAME
			GROUP BY S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME, T.TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY,
				S.PRIMARY_KEY_COLS
		) S
		LEFT OUTER JOIN MVDATA_BROWSER_U_REFS U ON U.VIEW_NAME = S.VIEW_NAME AND U.RANK = 1
		GROUP BY S.TABLE_NAME, S.VIEW_NAME, S.SHORT_NAME, S.IMP_TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY,
			S.PRIMARY_KEY_COLS, S.DESCRIPTION_COLUMNS
	), COLUMNS_Q AS (
        SELECT C.TABLE_NAME, C.COLUMN_NAME, C.COLUMN_ID
        FROM USER_TAB_COLUMNS C
        JOIN MVDATA_BROWSER_VIEWS S ON S.TABLE_NAME = C.TABLE_NAME
        WHERE C.NULLABLE = 'N' AND C.DEFAULT_LENGTH IS NULL
        AND C.COLUMN_NAME != S.PRIMARY_KEY_COLS
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
	IMP_TABLE_EXISTS, HAS_SCALAR_PRIMARY_KEY,
    case when EXISTS (
        SELECT 1 -- key is referenced in a foreign key clause
        FROM MVDATA_BROWSER_FKEYS T
        WHERE T.R_TABLE_NAME = S.TABLE_NAME
    ) then 'YES' else 'NO' end  IS_REFERENCED,
    PRIMARY_KEY_COLS,
	DESCRIPTION_COLUMNS, UNIQUE_COLUMNS, DEFAULTS_MISSING,
	case when (
		SELECT COUNT(*)
		FROM USER_OBJECTS U
		WHERE STATUS = 'VALID'
		AND OBJECT_TYPE = 'VIEW' AND OBJECT_NAME IN (IMPORT_VIEW_NAME, IMPORT_VIEW_CHECK_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HISTORY_VIEW_NAME)
		) = 5 then 'VALID' else 'INVALID' end VIEWS_STATUS
FROM (
	SELECT S.TABLE_NAME, S.VIEW_NAME,
		S.IMP_TABLE_NAME 					IMPORT_TABLE_NAME,
		'V' || S.IMP_TABLE_NAME 			IMPORT_VIEW_NAME,
		'V' || S.IMP_TABLE_NAME || '_TR' IMPORT_TRIGGER_NAME,
		'V' || S.IMP_TABLE_NAME || '_CK' IMPORT_VIEW_CHECK_NAME,
		'V' || S.IMP_TABLE_NAME || '_MSG' IMPORT_VIEW_MSG_NAME,
		'V' || S.IMP_TABLE_NAME || '_DIF' IMPORT_VIEW_DIF_NAME,
		HISTORY_VIEW_NAME,
		S.IMP_TABLE_EXISTS,
		S.HAS_SCALAR_PRIMARY_KEY,
		S.PRIMARY_KEY_COLS,
		S.DESCRIPTION_COLUMNS, S.UNIQUE_COLUMNS,
		( SELECT LISTAGG(C.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY C.COLUMN_ID)
          FROM COLUMNS_Q C WHERE S.TABLE_NAME = C.TABLE_NAME
        ) DEFAULTS_MISSING
	FROM TABLES_Q S
) S;

CREATE OR REPLACE VIEW VUSER_TABLES_IMP_COLUMNS
 ( TABLE_NAME, COLUMN_NAME, COLUMN_EXPR, COLUMN_COMPARE, COLUMN_MARKUP,
	COLUMN_CHECK_EXPR, COLUMN_ID, POSITION, IMP_COLUMN_NAME, COLUMN_ALIGN )
AS
SELECT S.VIEW_NAME TABLE_NAME, COLUMN_NAME,
	COLUMN_EXPR,
	import_utl.Get_CompareFunction(DATA_TYPE) COLUMN_COMPARE,
	import_utl.Get_MarkupFunction(DATA_TYPE) COLUMN_MARKUP,
	case when COLUMN_NAME != 'LINK_ID$' then
		import_utl.Get_ImpColumnCheck (DATA_TYPE, DATA_SCALE, CHAR_LENGTH, NULLABLE, COLUMN_NAME)
	end COLUMN_CHECK_EXPR,
	COLUMN_ID, POSITION, COLUMN_NAME IMP_COLUMN_NAME, COLUMN_ALIGN
FROM MVDATA_BROWSER_VIEWS S, table(
	data_browser_select.Get_View_Column_Cursor(
		p_Table_Name => S.VIEW_NAME,
		p_Unique_Key_Column => S.PRIMARY_KEY_COLS,
		p_Data_Columns_Only => 'YES',
		p_Select_Columns => NULL,
		p_View_Mode => 'EXPORT_VIEW',
		p_Report_Mode => 'YES'
	)
) WHERE (import_utl.Get_Exclude_Blob_Columns = 'NO' or data_browser_select.FN_Is_Sortable_Column(COLUMN_EXPR_TYPE) = 'YES');

-- generate from clause to access user tables with resolved foreign key connections
CREATE OR REPLACE VIEW VUSER_TABLES_IMP_JOINS (
	TABLE_NAME, COLUMN_NAME, SQL_TEXT, COLUMN_ID, POSITION, MATCHING, TABLE_ALIAS, R_TABLE_NAME) AS
SELECT DISTINCT S.TABLE_NAME, T.COLUMN_NAME, T.SQL_TEXT, T.COLUMN_ID, T.POSITION, T.MATCHING, T.TABLE_ALIAS, T.R_TABLE_NAME
FROM MVDATA_BROWSER_VIEWS S, table(
		data_browser_joins.Get_Detail_Table_Joins_Cursor(
		p_Table_Name =>  S.VIEW_NAME
	)
) T;

CREATE OR REPLACE VIEW VUSER_TABLES_IMP_TRIGGER (
	SQL_TEXT, SQL_EXISTS, SQL_EXISTS2, CHECK_CONSTRAINT_TYPE, DEFAULTS_MISSING,
	TABLE_NAME, COLUMN_NAME, POSITION, POSITION2, R_VIEW_NAME
) AS
SELECT SQL_TEXT,
	case when B.COLUMN_CHECK_EXPR IS NOT NULL then
		'SELECT IMP.IMPORTJOB_ID$, IMP.LINK_ID$, IMP.LINE_NO$, '
		|| DBMS_ASSERT.ENQUOTE_LITERAL(B.COLUMN_NAME) || ' COLUMN_NAME, '
		|| B.COLUMN_CHECK_EXPR || ' MESSAGE, '
		|| DBMS_ASSERT.ENQUOTE_LITERAL(
			case when CHECK_CONSTRAINT_TYPE = 'R' and DEFAULTS_MISSING = 0
				then 'R+'
				else CHECK_CONSTRAINT_TYPE end) || ' CONSTRAINT_TYPE'
		|| chr(10) || RPAD(' ', 4)
		|| 'FROM ' || B.FROM_CHECK_EXPR || ' IMP '
		|| case when B.WHERE_CHECK_EXPR IS NOT NULL
			then chr(10) || RPAD(' ', 4)
			|| 'WHERE ' || B.WHERE_CHECK_EXPR end
	end
	|| case when B.COLUMN_CHECK_EXPR2 IS NOT NULL then
		chr(10) || RPAD(' ', 4) || 'UNION ALL' || chr(10) || RPAD(' ', 4)
		|| 'SELECT IMP.IMPORTJOB_ID$, IMP.LINK_ID$, IMP.LINE_NO$, '
		|| DBMS_ASSERT.ENQUOTE_LITERAL(B.COLUMN_NAME) || ' COLUMN_NAME, '
		|| B.COLUMN_CHECK_EXPR2 || ' MESSAGE, '
		|| DBMS_ASSERT.ENQUOTE_LITERAL('T') || ' CONSTRAINT_TYPE'
		|| chr(10) || RPAD(' ', 4)
		|| 'FROM ' || B.FROM_CHECK_EXPR || ' IMP ' || chr(10) || RPAD(' ', 4)
		|| 'WHERE ' || B.WHERE_CHECK_EXPR2
	end SQL_EXISTS,
	case when B.CHECK_CONSTRAINT_TYPE = 'T' and B.COLUMN_CHECK_EXPR IS NOT NULL
		then B.COLUMN_CHECK_EXPR
	when B.CHECK_CONSTRAINT_TYPE = 'R' and B.COLUMN_CHECK_EXPR IS NOT NULL
		then '(SELECT ' || B.COLUMN_CHECK_EXPR || ' MESSAGE' || chr(10) || RPAD(' ', 8)
		|| ' FROM DUAL ' || chr(10) || RPAD(' ', 8)
		|| ' WHERE ' || B.WHERE_CHECK_EXPR || ')'
		|| case when B.COLUMN_CHECK_EXPR2 IS NOT NULL
			then
				' || ' || chr(10) || RPAD(' ', 8)
				|| '(SELECT ' || B.COLUMN_CHECK_EXPR2 || ' MESSAGE' || chr(10) || RPAD(' ', 8)
				|| ' FROM DUAL ' || chr(10) || RPAD(' ', 8)
				|| ' WHERE ' || B.WHERE_CHECK_EXPR2 || chr(10) || RPAD(' ', 8) || ' )'
			end
	end
	SQL_EXISTS2,
	B.CHECK_CONSTRAINT_TYPE,
	B.DEFAULTS_MISSING, B.TABLE_NAME, B.COLUMN_NAME, B.POSITION, B.POSITION2, B.R_VIEW_NAME
FROM ( -- select column list of target table
    SELECT S.VIEW_NAME TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY, S.PRIMARY_KEY_COLS,
        '    v_row.' || RPAD(T.COLUMN_NAME, 32) || ' := '
        || case when T.COLUMN_NAME != S.PRIMARY_KEY_COLS
        	    then import_utl.Get_ImportColFunction(T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, ':new.' || T.COLUMN_NAME)
        	    else ':new.' || 'LINK_ID$'
        	end
        || ';' SQL_TEXT,
        ---------------------------
		T.COLUMN_NAME,
		case when T.COLUMN_NAME != S.PRIMARY_KEY_COLS then
			import_utl.Get_ImpColumnCheck (T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, T.NULLABLE, T.COLUMN_NAME)
		end COLUMN_CHECK_EXPR,
		S.SHORT_NAME || '_IMP' FROM_CHECK_EXPR,
		NULL WHERE_CHECK_EXPR,
		NULL COLUMN_CHECK_EXPR2,
		NULL WHERE_CHECK_EXPR2,
		'T' CHECK_CONSTRAINT_TYPE,
        ---------------------------
        0 DEFAULTS_MISSING, T.COLUMN_ID POSITION, 1 POSITION2, NULL R_VIEW_NAME
    FROM USER_TAB_COLUMNS T
    JOIN MVDATA_BROWSER_VIEWS S ON S.TABLE_NAME = T.TABLE_NAME
    JOIN USER_TAB_COLUMNS C ON S.VIEW_NAME = C.TABLE_NAME AND C.COLUMN_NAME = T.COLUMN_NAME  -- only columns that appear in the view
    WHERE import_utl.Get_ImpColumnCheck (T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, T.NULLABLE, T.COLUMN_NAME) IS NOT NULL
    AND data_browser_pattern.Match_Ignored_Columns(T.COLUMN_NAME) = 'NO'
    AND data_browser_pattern.Match_Hidden_Columns(T.COLUMN_NAME) = 'NO'
	AND NOT EXISTS (-- no foreign key columns
		SELECT 1
		FROM USER_CONSTRAINTS
		NATURAL JOIN USER_CONS_COLUMNS
		WHERE TABLE_NAME = S.TABLE_NAME
		AND COLUMN_NAME = T.COLUMN_NAME
		AND CONSTRAINT_TYPE = 'R'
	)
    UNION ALL -- process foreign_keys of target table
    SELECT T.VIEW_NAME TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY, S.PRIMARY_KEY_COLS,
         ---------------------------
    	case when MAX(T.U_CONSTRAINT_NAME) IS NOT NULL or import_utl.Get_Search_Keys_Unique = 'NO' then
			RPAD(' ', 4) || 'if ' || D_REF || ' IS NULL AND ('
			|| LISTAGG(S_REF || ' IS NOT NULL',
				case when HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0 then ' OR ' else ' AND ' end
			) WITHIN GROUP (ORDER BY R_COLUMN_ID) -- conditions to trigger the search of foreign keys
			|| ') then ' || chr(10)
			|| case when D.DEFAULTS_MISSING = 0  AND import_utl.Get_Insert_Foreign_Keys = 'YES' then RPAD(' ', 6) || 'begin ' || chr(10) end
			|| RPAD(' ', 8) -- find foreign key values
			|| 'SELECT ' || T.TABLE_ALIAS || '.' || T.R_PRIMARY_KEY_COLS || ' INTO ' || D_REF || chr(10) || RPAD(' ', 8)
			|| 'FROM ' || T.R_VIEW_NAME || ' ' || T.TABLE_ALIAS || ' '
			-- || LISTAGG (T.JOIN_CLAUSE, chr(10) || RPAD(' ', 8)) WITHIN GROUP (ORDER BY T.R_COLUMN_ID)
			|| chr(10) || RPAD(' ', 8)
			|| 'WHERE '
			|| LISTAGG(
					case when (HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0) AND T.U_MEMBERS > 1
					then '('
						|| import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, S_REF, T.R_DATA_TYPE)
						|| ' OR '
						|| case when T.R_NULLABLE = 'Y' then T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME || ' IS NULL AND ' end
						|| S_REF || ' IS NULL)'
					else
						import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, S_REF, T.R_DATA_TYPE)
					end,
				chr(10) || RPAD(' ', 8) || 'AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
			|| ';' || chr(10) || RPAD(' ', 4)
			|| case when D.DEFAULTS_MISSING = 0 AND import_utl.Get_Insert_Foreign_Keys = 'YES' then
				'  exception when NO_DATA_FOUND then' || chr(10) || RPAD(' ', 8)
				|| 'INSERT INTO ' || T.R_VIEW_NAME || '('
				|| LISTAGG(T.R_COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
				|| ') VALUES ('
				|| LISTAGG(S_REF, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
				|| ') RETURNING (' || T.R_PRIMARY_KEY_COLS || ') INTO ' || D_REF || ';' || chr(10) || RPAD(' ', 6)
				|| 'end;' || chr(10) || RPAD(' ', 4)
			end
			|| 'end if;'
		end
        SQL_TEXT,
        ---------------------------
        T.COLUMN_NAME,
        DBMS_ASSERT.ENQUOTE_LITERAL(LISTAGG(INITCAP(T.R_COLUMN_NAME), '/') WITHIN GROUP (ORDER BY R_COLUMN_ID)
        || ' für ' || INITCAP(T.R_VIEW_NAME) || ' ist nicht vorhanden.')
		COLUMN_CHECK_EXPR,
		S.SHORT_NAME || '_IMP' FROM_CHECK_EXPR,
        ' (' || LISTAGG('IMP.' || T.IMP_COLUMN_NAME || ' IS NOT NULL',
            case when HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0 then ' OR ' else ' AND ' end
        ) WITHIN GROUP (ORDER BY R_COLUMN_ID) -- conditions to trigger the search of foreign keys
        || ') ' || chr(10) || RPAD(' ', 8) || ' AND NOT EXISTS ( SELECT 1 FROM ' || T.R_VIEW_NAME || ' ' || T.TABLE_ALIAS || ' '
		-- || LISTAGG (T.JOIN_CLAUSE, chr(10) || RPAD(' ', 12)) WITHIN GROUP (ORDER BY T.R_COLUMN_ID)
		|| chr(10) || RPAD(' ', 12)
        || 'WHERE '
        || LISTAGG(
                case when (HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0) AND T.U_MEMBERS > 1
                then '(' || import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, 'IMP.' || T.IMP_COLUMN_NAME, T.R_DATA_TYPE)
                    || ' OR '
                    || case when T.R_NULLABLE = 'Y' then T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME || ' IS NULL AND ' end
                    || 'IMP.' || T.IMP_COLUMN_NAME || ' IS NULL)'
                else
                    import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, 'IMP.' || T.IMP_COLUMN_NAME, T.R_DATA_TYPE)
                end,
            chr(10) || RPAD(' ', 12) || 'AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
        || chr(10) || RPAD(' ', 8) || ' )'
        WHERE_CHECK_EXPR,
        case when T.NULLABLE = 'N' then
        	'''' || LISTAGG(INITCAP(T.R_COLUMN_NAME), '/') WITHIN GROUP (ORDER BY R_COLUMN_ID)
            || case when T.U_MEMBERS = 1 then ' ist ' else ' sind ' end || 'leer.'''
        end COLUMN_CHECK_EXPR2,
        case when T.NULLABLE = 'N' then
            LISTAGG('IMP.' || T.IMP_COLUMN_NAME || ' IS NULL', ' AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
        end WHERE_CHECK_EXPR2,
		'R' CHECK_CONSTRAINT_TYPE,
        ---------------------------
        D.DEFAULTS_MISSING + case when MAX(T.U_CONSTRAINT_NAME) IS NOT NULL or import_utl.Get_Search_Keys_Unique = 'NO' then 0 else 1 end DEFAULTS_MISSING,
        T.COLUMN_ID POSITION, POSITION2, T.R_VIEW_NAME
	FROM
	(
		-- 2. level foreign keys
		SELECT Q.VIEW_NAME, Q.TABLE_NAME, Q.PRIMARY_KEY_COLS, Q.SHORT_NAME,
			Q.FOREIGN_KEY_COLS COLUMN_NAME,
			':new.' || Q.IMP_COLUMN_NAME S_REF,
			':new.' || S.IMP_COLUMN_NAME D_REF,
			Q.R_PRIMARY_KEY_COLS, Q.R_CONSTRAINT_TYPE,
			Q.R_VIEW_NAME, Q.COLUMN_ID, Q.NULLABLE,
			Q.R_COLUMN_ID, Q.R_COLUMN_NAME, Q.R_NULLABLE, Q.R_DATA_TYPE,
			Q.R_DATA_SCALE, Q.R_CHAR_LENGTH,
			Q.TABLE_ALIAS, Q.IMP_COLUMN_NAME,
			case when import_utl.Get_As_Of_Timestamp = 'YES'
				then REPLACE (Q.JOIN_CLAUSE, Q.JOIN_VIEW_NAME, custom_changelog.Get_ChangeLogViewName(Q.JOIN_VIEW_NAME))
				else Q.JOIN_CLAUSE
			end JOIN_CLAUSE,
			SUM(case when Q.R_NULLABLE = 'Y' then 1 else 0 end) OVER (PARTITION BY Q.TABLE_NAME, Q.FOREIGN_KEY_COLS) HAS_NULLABLE,
			SUM(case when Q.U_MEMBERS = 1 THEN 1 else 0 end ) OVER (PARTITION BY Q.TABLE_NAME, Q.FOREIGN_KEY_COLS) HAS_SIMPLE_UNIQUE,
			Q.U_CONSTRAINT_NAME, Q.U_MEMBERS, 1 POSITION2
		FROM MVDATA_BROWSER_Q_REFS Q
		JOIN MVDATA_BROWSER_F_REFS S ON Q.VIEW_NAME = S.VIEW_NAME
			and Q.FOREIGN_KEY_COLS = S.FOREIGN_KEY_COLS
			and Q.TABLE_ALIAS = S.TABLE_ALIAS
			and Q.J_VIEW_NAME = S.R_VIEW_NAME
			and Q.J_COLUMN_NAME = S.R_COLUMN_NAME
		UNION ALL
		-- 1. level foreign keys
		SELECT S.VIEW_NAME,S.TABLE_NAME, S.PRIMARY_KEY_COLS, S.SHORT_NAME,
			S.FOREIGN_KEY_COLS COLUMN_NAME,
			':new.' || S.IMP_COLUMN_NAME S_REF,
			'v_row.' || S.FOREIGN_KEY_COLS D_REF,
			S.R_PRIMARY_KEY_COLS, S.R_CONSTRAINT_TYPE,
			S.R_VIEW_NAME, S.COLUMN_ID, S.NULLABLE,
			S.R_COLUMN_ID, S.R_COLUMN_NAME, S.R_NULLABLE, S.R_DATA_TYPE,
			S.R_DATA_SCALE, S.R_CHAR_LENGTH,
			S.TABLE_ALIAS, S.IMP_COLUMN_NAME, NULL JOIN_CLAUSE,
					SUM(case when S.R_NULLABLE = 'Y' then 1 else 0 end) OVER (PARTITION BY S.TABLE_NAME, S.FOREIGN_KEY_COLS) HAS_NULLABLE,
					SUM(case when U.U_MEMBERS = 1 THEN 1 else 0 end ) OVER (PARTITION BY S.TABLE_NAME, S.FOREIGN_KEY_COLS) HAS_SIMPLE_UNIQUE,
					U.U_CONSTRAINT_NAME, U.U_MEMBERS, 2 POSITION2
		FROM MVDATA_BROWSER_F_REFS S
		LEFT OUTER JOIN MVDATA_BROWSER_U_REFS U ON U.VIEW_NAME = S.R_VIEW_NAME AND U.COLUMN_NAME = S.R_COLUMN_NAME AND U.RANK = 1  -- unique key columns for each foreign key
		WHERE S.R_COLUMN_ID IS NOT NULL
	) T
    JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = T.VIEW_NAME
    JOIN ( -- count of missing defaults for foreign key table
        SELECT S.VIEW_NAME, COUNT(DISTINCT C.COLUMN_ID) DEFAULTS_MISSING
        FROM MVDATA_BROWSER_VIEWS S -- foreign key table
        LEFT OUTER JOIN USER_TAB_COLUMNS C ON S.TABLE_NAME = C.TABLE_NAME
        AND C.NULLABLE = 'N' AND C.DEFAULT_LENGTH IS NULL
        AND C.COLUMN_NAME != S.PRIMARY_KEY_COLS
        AND NOT EXISTS (
            SELECT 1
            FROM MVDATA_BROWSER_D_REFS R
            WHERE R.TABLE_NAME = S.VIEW_NAME
            AND R.COLUMN_NAME = C.COLUMN_NAME
			UNION ALL
			SELECT 1
			FROM MVDATA_BROWSER_U_REFS R
			WHERE R.VIEW_NAME = S.VIEW_NAME
			AND R.COLUMN_NAME = C.COLUMN_NAME
			AND R.RANK = 1
        )
        GROUP BY S.VIEW_NAME
    ) D ON D.VIEW_NAME = T.R_VIEW_NAME
    WHERE R_COLUMN_ID IS NOT NULL
    GROUP BY T.TABLE_NAME, T.VIEW_NAME, S.HAS_SCALAR_PRIMARY_KEY, S.PRIMARY_KEY_COLS,
    	D.DEFAULTS_MISSING, T.TABLE_ALIAS, T.R_PRIMARY_KEY_COLS, T.COLUMN_NAME,
    	T.R_VIEW_NAME, T.COLUMN_ID, S.SHORT_NAME,
        T.HAS_NULLABLE, T.HAS_SIMPLE_UNIQUE, T.U_MEMBERS, 
        T.NULLABLE, T.D_REF, T.POSITION2
	UNION ALL -- process check constraints
	SELECT S.VIEW_NAME TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY, S.PRIMARY_KEY_COLS,
		NULL SQL_TEXT,
       ---------------------------
        MIN(B.COLUMN_NAME) COLUMN_NAME,
		DBMS_ASSERT.ENQUOTE_LITERAL('Regelverletzung für ' || REPLACE(A.SEARCH_CONDITION, CHR(39))) COLUMN_CHECK_EXPR,
		'(SELECT IMPORTJOB_ID$, LINE_NO$, LINK_ID$, '
		|| LISTAGG(import_utl.Get_ImportColFunction(T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, T.COLUMN_NAME)
				|| ' ' || T.COLUMN_NAME, ', ')
			WITHIN GROUP (ORDER BY T.COLUMN_ID) || chr(10)
		|| '    FROM '
		|| S.SHORT_NAME || '_IMP)'  FROM_CHECK_EXPR,
		'NOT (' || A.SEARCH_CONDITION || ')' 			WHERE_CHECK_EXPR,
		NULL COLUMN_CHECK_EXPR2,
		NULL WHERE_CHECK_EXPR2,
		'C' CHECK_CONSTRAINT_TYPE,
        ---------------------------
		0 DEFAULTS_MISSING, 1000 POSITION, 1 POSITION2, NULL R_VIEW_NAME
	FROM MVDATA_BROWSER_VIEWS S
	JOIN (
		SELECT TABLE_NAME, CONSTRAINT_NAME,
			changelog_conf.Get_ConstraintText(TABLE_NAME, CONSTRAINT_NAME) SEARCH_CONDITION
		FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C'
	) A ON A.TABLE_NAME = S.TABLE_NAME
	JOIN USER_CONS_COLUMNS B ON A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.TABLE_NAME = B.TABLE_NAME
	JOIN USER_TAB_COLUMNS T ON A.TABLE_NAME = T.TABLE_NAME AND B.COLUMN_NAME = T.COLUMN_NAME
	WHERE NOT EXISTS (
		SELECT 1
		FROM USER_CONS_COLUMNS B
		WHERE A.CONSTRAINT_NAME = B.CONSTRAINT_NAME
		AND A.TABLE_NAME = B.TABLE_NAME
		AND B.COLUMN_NAME = S.PRIMARY_KEY_COLS
		AND data_browser_pattern.Match_Ignored_Columns(B.COLUMN_NAME) = 'NO'
		AND data_browser_pattern.Match_Hidden_Columns(B.COLUMN_NAME) = 'NO'
	)
	AND NOT EXISTS (-- no foreign key columns
		SELECT 1
		FROM USER_CONSTRAINTS
		NATURAL JOIN USER_CONS_COLUMNS
		WHERE TABLE_NAME = S.TABLE_NAME
		AND COLUMN_NAME = T.COLUMN_NAME
		AND CONSTRAINT_TYPE = 'R'
	)
	AND A.SEARCH_CONDITION != DBMS_ASSERT.ENQUOTE_NAME(B.COLUMN_NAME) || ' IS NOT NULL'
	GROUP BY S.VIEW_NAME, S.HAS_SCALAR_PRIMARY_KEY, S.PRIMARY_KEY_COLS, A.CONSTRAINT_NAME, A.SEARCH_CONDITION, S.SHORT_NAME
) B
;

-- generate update statements to link the imported rows with existing base table rows
CREATE OR REPLACE VIEW VUSER_TABLES_IMP_LINK (TABLE_NAME, U_CONSTRAINT_NAME, SQL_TEXT) AS
-- process unique constraints
SELECT S.VIEW_NAME TABLE_NAME, U.U_CONSTRAINT_NAME,
    'UPDATE ' || S.SHORT_NAME || '_IMP IMP ' || chr(10) || RPAD(' ', 4)
    || 'SET LINK_ID$ = ( SELECT '
    || case when INSTR(S.PRIMARY_KEY_COLS, ',') = 0
    	then 'A.' || S.PRIMARY_KEY_COLS
    	else 'CAST(data_browser_select.Hex_Hash( A.' || REPLACE(S.PRIMARY_KEY_COLS, ', ', ', A.') || ') AS VARCHAR2(120))'
    	end
    || chr(10) || RPAD(' ', 8) || 'FROM ' || S.VIEW_NAME || ' A '
    || LISTAGG (
    		case when F.FOREIGN_KEY_COLS IS NOT NULL then
				case when F.NULLABLE = 'Y' then 'LEFT OUTER ' end || 'JOIN '
				|| F.R_VIEW_NAME || ' ' || F.TABLE_ALIAS
				|| ' ON ' 
				|| data_browser_conf.Get_Join_Expression(
					p_Left_Columns=>F.R_PRIMARY_KEY_COLS, p_Left_Alias=> F.TABLE_ALIAS,
					p_Right_Columns=>F.FOREIGN_KEY_COLS, p_Right_Alias=> 'A')
				-- || F.TABLE_ALIAS || '.' || F.R_PRIMARY_KEY_COLS || ' = A.' || F.FOREIGN_KEY_COLS
            end
    	, chr(10) || RPAD(' ', 8)) WITHIN GROUP (ORDER BY F.R_COLUMN_ID)
    || chr(10) || RPAD(' ', 8) || 'WHERE '
    || LISTAGG (
    	case when F.FOREIGN_KEY_COLS IS NOT NULL then
    		import_utl.Get_Compare_Case_Insensitive(F.TABLE_ALIAS || '.' || F.R_COLUMN_NAME, 'IMP.' || F.IMP_COLUMN_NAME, F.R_DATA_TYPE)
    	else
    		import_utl.Get_Compare_Case_Insensitive('A.' || U.COLUMN_NAME, 'IMP.' || U.COLUMN_NAME, U.DATA_TYPE)
    	end,
        chr(10) || RPAD(' ', 8) || 'AND ') WITHIN GROUP (ORDER BY U.POSITION, F.R_COLUMN_ID)
    || chr(10) || RPAD(' ', 4) || ' )' || chr(10) || RPAD(' ', 4)
    || 'WHERE ('
    || LISTAGG ( 'IMP.' || NVL(F.IMP_COLUMN_NAME, U.COLUMN_NAME) || ' IS NOT NULL',
            case when U.HAS_NULLABLE > 0 then ' OR ' else ' AND ' end
        ) WITHIN GROUP (ORDER BY U.POSITION, F.R_COLUMN_ID) -- conditions to trigger the search of foreign keys
    || ') ' || chr(10) || RPAD(' ', 4) || 'AND IMP.LINK_ID$ IS NULL '
    SQL_TEXT
FROM MVDATA_BROWSER_VIEWS S
JOIN USER_TABLES T ON T.TABLE_NAME = S.SHORT_NAME || '_IMP'
JOIN MVDATA_BROWSER_U_REFS U ON U.VIEW_NAME = S.VIEW_NAME AND U.RANK = 1 -- check all unique keys
LEFT OUTER JOIN MVDATA_BROWSER_F_REFS F ON F.TABLE_NAME = S.VIEW_NAME AND F.FOREIGN_KEY_COLS = U.COLUMN_NAME AND F.R_COLUMN_ID IS NOT NULL
GROUP BY S.VIEW_NAME, S.SHORT_NAME, S.PRIMARY_KEY_COLS, S.HAS_SCALAR_PRIMARY_KEY, U.HAS_NULLABLE, U.U_CONSTRAINT_NAME
;

