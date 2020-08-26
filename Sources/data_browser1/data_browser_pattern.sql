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

CREATE OR REPLACE PACKAGE data_browser_pattern
AUTHID DEFINER 
IS
	g_debug CONSTANT BOOLEAN := false;

	PROCEDURE Load_Config;
	FUNCTION Find_Tables_Prefix RETURN VARCHAR2;
	PROCEDURE Save_Config_Defaults;

    FUNCTION Get_File_Name_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Mime_Type_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_File_Created_Col_Pattern RETURN VARCHAR2;
    FUNCTION Get_File_Content_Col_Pattern RETURN VARCHAR2;
    FUNCTION Get_Index_Format_Field_Pattern RETURN VARCHAR2;
    FUNCTION Get_File_Folder_Field_Pattern RETURN VARCHAR2;
    FUNCTION Get_Folder_Parent_Fld_Pattern RETURN VARCHAR2;
    FUNCTION Get_Folder_Name_Field_Pattern RETURN VARCHAR2;
    FUNCTION Get_Active_Lov_Fields_Pattern RETURN VARCHAR2;
    
    FUNCTION Get_File_Privilege_Fld_Pattern RETURN VARCHAR2;
    FUNCTION Get_Encrypted_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Obfuscation_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Upper_Names_Column_Pattern RETURN VARCHAR2;
    
    FUNCTION Match_Edit_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_ReadOnly_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Admin_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Included_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Excluded_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Upper_Names_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Obfuscation_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_ReadOnly_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Hidden_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Data_Deduction_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Ignored_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Display_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    FUNCTION Match_Yes_No_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO

	FUNCTION Match_Encrypted_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Flip_State_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Active_Lov_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Lock_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Html_Fields_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Calendar_Start_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Calendar_End_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Summand_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Minuend_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Factors_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_DateTime_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Password_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Row_Version_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Row_Lock_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Soft_Delete_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Ordering_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Audit_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Currency_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Thumbnail_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_File_Name_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Mime_Type_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_File_Created_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_File_Content_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Index_Format_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_File_Folder_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Folder_Parent_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_Folder_Name_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
	FUNCTION Match_File_Privilege_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2; -- YES / NO
    
    FUNCTION Get_Flip_State_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Soft_Lock_Field_Pattern RETURN VARCHAR2;
    FUNCTION Get_Html_Fields_Pattern RETURN VARCHAR2;
    FUNCTION Get_Hand_Signatur_Pattern RETURN VARCHAR2;
    FUNCTION Get_Calend_Start_Date_Pattern RETURN VARCHAR2;
    FUNCTION Get_Calendar_End_Date_Pattern RETURN VARCHAR2;
    FUNCTION Get_Summand_Field_Pattern RETURN VARCHAR2;
    FUNCTION Get_Minuend_Field_Pattern RETURN VARCHAR2;
    FUNCTION Get_Factors_Field_Pattern RETURN VARCHAR2;

	FUNCTION Get_Row_Version_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Row_Lock_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Soft_Delete_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Ordering_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Audit_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Currency_Column_Pattern RETURN VARCHAR2;
    FUNCTION Get_Thumbnail_Column_Pattern RETURN VARCHAR2;
    
	FUNCTION Get_ReadOnly_Columns_Pattern RETURN VARCHAR2;
	FUNCTION Get_Hidden_Columns_Pattern RETURN VARCHAR2;
	FUNCTION Get_Hide_Audit_Columns RETURN VARCHAR2;
	FUNCTION Get_Data_Deduction_Pattern RETURN VARCHAR2;
	FUNCTION Get_Ignored_Columns_Pattern RETURN VARCHAR2;
    FUNCTION Get_Display_Columns_Pattern RETURN VARCHAR2;
    FUNCTION Get_Yes_No_Columns_Pattern RETURN VARCHAR2;
    FUNCTION Get_DateTime_Columns_Pattern RETURN VARCHAR2;
    FUNCTION Get_Password_Column_Pattern RETURN VARCHAR2;
    
    FUNCTION Get_Base_Table_Ext RETURN VARCHAR2;
    FUNCTION Get_Base_View_Prefix RETURN VARCHAR2;
    FUNCTION Get_Base_View_Ext RETURN VARCHAR2;
    FUNCTION Get_History_View_Name(p_Name VARCHAR2) RETURN VARCHAR2;
END data_browser_pattern;
/

CREATE OR REPLACE PACKAGE BODY data_browser_pattern
IS
	g_Configuration_ID			NUMBER			:= 1;
	g_ReadOnly_Tables_Pattern 	VARCHAR2(2000) 	:= 'APP_PROTOCOL'; -- NEW List of table name pattern for tables with editing of table data disabled.
	g_Edit_Tables_Pattern 		VARCHAR2(2000) 	:= '%'; 	-- List of table name pattern for tables with editing of table data enabled.
	g_ReadOnly_Columns_Pattern 	VARCHAR2(2000) 	:=
	'%CREATED%,%MODIFIED%,%UPDATED%,ROW_VERSION_NUMBER,LAST_LOGIN_DATE,EMAIL_VALIATION_TOKEN'; -- List of read only column name pattern
	g_Admin_Tables_Pattern 		VARCHAR2(2000) 	:= 'APP_%,DATA_BROWSER_CHECKS'; 	-- List of table name pattern for user administration tables.
    g_Included_Tables_Pattern 	VARCHAR2(2000) 	:= '%';	-- List of table name pattern that are included in the application.
    g_Excluded_Tables_Pattern 	VARCHAR2(2000) 	:= 
    'PLUGIN_DELETE_CHECKS,DATA_BROWSER%,MVDATA_BROWSER%,MVBASE%,USER%,CHANGE_LOG%,MVCHANGELOG%';	-- List of table name pattern that are excluded from the application.
	g_Hidden_Columns_Pattern 	VARCHAR2(2000) 	:=
	'%CREATED%,%MODIFIED%,%UPDATED%,ROW_VERSION_NUMBER,EMAIL_VALIATION_TOKEN,%PASSWORD%'; 	-- List of hidden column name pattern, Matching columns are excluded from reports.
	g_Ignored_Columns_Pattern 	VARCHAR2(2000) 	:=	'INDEX_FORMAT,DELETED_MARK,WORKSPACE$_ID'; -- List of ignored column name pattern
    -- List of column name pattern for the description of foreign key references (LOV) and record descriptions
	g_Data_Deduction_Pattern  	VARCHAR2(2000)  := ''; 	 -- NEW List of column name pattern for columns that are hidden from users with data deduction access.
    g_Display_Columns_Pattern 	VARCHAR2(2000)  := 'NAME,NAME1,BESCHREIBUNG,BEZEICHNUNG,DESCRIPTION,%_DESC';
    g_DateTime_Columns_Pattern 	VARCHAR2(2000)  := '%CREATED%,%MODIFIED%,%UPDATED%,%LASTUPD,%LAST_UPD,LAST_LOGIN_DATE,ERFASST_DATUM,AENDERUNG_DATUM';	 -- List of column name pattern for date columns with DateTime_Format.
    g_Password_Column_Pattern	VARCHAR2(2000)  := 'PASSWORD_HASH,PASSWORD';	 -- List of column name pattern for password fields
    g_Row_Version_Column_Pattern VARCHAR2(2000) := 'ROW_VERSION_NUMBER'; -- List of column name pattern for row version number (used in update operations)
	g_Row_Lock_Column_Pattern	VARCHAR2(2000) 	:= 'LOCKED_INDICATOR,PROTECTED,%GESCHUETZT'; -- List of column name pattern for logical row lock Indicator Y/N columns.
	g_Soft_Delete_Column_Pattern VARCHAR2(2000) := 'DELETED_INDICATOR'; -- List of column name pattern for soft delete indicator Y/N columns.
	g_Ordering_Column_Pattern	VARCHAR2(2000) 	:= 'LINE_NO,DISPLAY_ORDER,ZEILE,ZEILEN_NR,%SEQUENCE%'; 	-- List of column name pattern for natural ordering of rows in a set.
	g_Audit_Column_Pattern		VARCHAR2(2000) 	:= '%CREATED%,%MODIFIED%,%UPDATED%,%LASTUPD,%LAST_UPD,ERFASST%,AENDERUNG%'; 		-- List of column name pattern for audit info columns. This columns are shown at the bottom of forms
	g_Hide_Audit_Columns		VARCHAR2(5)  	:= 'NO';			-- Hide audit columns in reports
	g_Currency_Column_Pattern	VARCHAR2(2000)  := '';				-- List of column name pattern for currency number fields
	g_Thumbnail_Column_Pattern 	VARCHAR2(2000)  := '';				-- List of column name pattern for thumbnail blob fields
	-------------------------------------------
	g_File_Name_Column_Pattern	VARCHAR2(2000)   := '%FILENAME,%FILE_NAME,%DATEI_NAME';	-- List of column name pattern for file name (used for file upload and download)
	g_Mime_Type_Column_Pattern	VARCHAR2(2000)   := '%MIMETYPE,%MIME_TYPE';	-- List of column name pattern for mime type (used for file upload and download)
	g_File_Created_Column_Pattern VARCHAR2(2000) := '%CREATED_ON,%LASTUPD,%LAST_UPD,DATUM';	-- List of column name pattern for file date (used for file upload and download)
	g_File_Content_Column_Pattern VARCHAR2(2000) := '%BLOB_CONTENT,%FILE_CONTENT,%_BLOB,DATEI,%DATEI_CONTENT,%BILD';	-- List of column name pattern for file content (used for file upload and download)

	g_Index_Format_Field_Pattern VARCHAR2(2000) := '%INDEX_FORMAT'; -- Index Format of Text Index fields
	g_File_Folder_Field_Pattern  VARCHAR2(2000)  := '%FOLDER_ID,%FOLDERS_ID,%ORDNER_ID,%ORDNERID'; 	-- foreign key to folder
	g_Folder_Parent_Field_Pattern VARCHAR2(2000)  := '%PARENT_ID,%PARENTID';	-- folder parent link; enables zip file upload with folder hierarchy
	g_Folder_Name_Field_Pattern  VARCHAR2(2000)  := '%FOLDER_NAME,%ORDNER_NAME,BEZEICHNUNG';	-- folder name; enables zip file upload with folder hierarchy
	g_File_Privilege_Fld_Pattern VARCHAR2(2000)  := '';				-- List of column name pattern for file privileges columns (used for file upload and download)
	g_Encrypted_Column_Pattern	VARCHAR2(2000)  := 'SMTP_PASSWORD,WALLET_PASSWORD';	-- List of column name pattern for encrypted fields.
	g_Obfuscation_Column_Pattern VARCHAR2(2000)  := '';				-- List of column name pattern for obfuscated fields.
	g_Upper_Names_Column_Pattern VARCHAR2(2000)  := '';				-- list of column name pattern for column with UPPER case header names.
	g_Flip_State_Column_Pattern	VARCHAR2(2000)  := '';
	-------------------------------------------
	g_Active_Lov_Fields_Pattern VARCHAR2(2000)  := '%ACTIVE%,%AKTIV%'; 	-- Filter Yes/No field for visibility in LOV like DISPLAY_YN = 'Y'
	g_Soft_Lock_Field_Pattern  	VARCHAR2(2000)  := '%LOCKED%'; 	-- List of column name pattern for logical row lock user and date; for example locked_by, locked_at.
	g_Html_Fields_Pattern  		VARCHAR2(2000)  := '%HTML%';	-- List of column name pattern for Rich Text Editor fields
	g_Hand_Signatur_Pattern  	VARCHAR2(2000)  := '%SIGNATUR%';	-- List of column name pattern for Canvas Editor fields
	g_Calendar_Start_Date_Pattern VARCHAR2(2000)  := 'START_DATE';	-- List of column name pattern for Calendar Events Field
	g_Calendar_End_Date_Pattern VARCHAR2(2000)  := 'END_DATE';	-- List of column name pattern for Calendar Events Field
	g_Summand_Field_Pattern  	VARCHAR2(2000)  := '';	-- List of column name pattern for building sums and totals for number columns
	g_Minuend_Field_Pattern  	VARCHAR2(2000)  := '';	-- List of column name pattern for building differences and totals for number columns
	g_Factors_Field_Pattern  	VARCHAR2(2000)  := '';	-- List of column name pattern for building products for number columns
    g_Yes_No_Columns_Pattern 	VARCHAR2(2000)  := '%ACTIVE%,%AKTIV%,%_YN';	-- List of column name pattern for single char encoded Yes/No columns.
	-------------------------------------------
    g_Key_Column_Ext			VARCHAR2(2000)    := '_ID,_SID$,_CONTENT';   -- List of Extension of column names. (This extension will be removed from displayed column names)
    g_Base_Table_Prefix			VARCHAR2(2000)    := '';		-- Prefix for base table names. (This prefix will be removed from displayed table names)
    g_Base_Table_Ext  			VARCHAR2(2000)    := '_BT';   -- Extension for base table names. (This extension will be removed from displayed table names)
    g_Base_View_Prefix 			VARCHAR2(2000)    := '';      -- Prefix for base view names
    g_Base_View_Ext  			VARCHAR2(2000)    := '';      -- Extension for base view names
    g_History_View_Ext       	VARCHAR2(2000)    := '_CL';   -- Extension for history views with AS OF TIMESTAMP filter

	g_Edit_Tables_Array apex_t_varchar2 := apex_t_varchar2();
	g_ReadOnly_Tables_Array apex_t_varchar2 := apex_t_varchar2();
	g_Admin_Tables_Array apex_t_varchar2 := apex_t_varchar2();
	g_Included_Tables_Array apex_t_varchar2 := apex_t_varchar2();
	g_Excluded_Tables_Array apex_t_varchar2 := apex_t_varchar2();
	g_Upper_Names_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Obfuscation_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_ReadOnly_Columns_Array apex_t_varchar2 := apex_t_varchar2();
	g_Hidden_Columns_Array apex_t_varchar2 := apex_t_varchar2();
	g_Data_Deduction_Array apex_t_varchar2 := apex_t_varchar2();
	g_Ignored_Columns_Array apex_t_varchar2 := apex_t_varchar2();
	g_Display_Columns_Array apex_t_varchar2 := apex_t_varchar2();
	g_Yes_No_Columns_Array apex_t_varchar2 := apex_t_varchar2();	

	g_Encrypted_Column_Array apex_t_varchar2 := apex_t_varchar2();	
	g_Flip_State_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Active_Lov_Fields_Array apex_t_varchar2 := apex_t_varchar2();
	g_Soft_Lock_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Html_Fields_Array apex_t_varchar2 := apex_t_varchar2();
	g_Calendar_Start_Date_Array apex_t_varchar2 := apex_t_varchar2();
	g_Calendar_End_Date_Array apex_t_varchar2 := apex_t_varchar2();
	g_Summand_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Minuend_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Factors_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_DateTime_Columns_Array apex_t_varchar2 := apex_t_varchar2();
	g_Password_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Row_Version_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Row_Lock_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Soft_Delete_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Ordering_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Audit_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Currency_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Thumbnail_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_File_Name_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Mime_Type_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_File_Created_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_File_Content_Column_Array apex_t_varchar2 := apex_t_varchar2();
	g_Index_Format_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_File_Folder_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Folder_Parent_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Folder_Name_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_File_Privilege_Fld_Array apex_t_varchar2 := apex_t_varchar2();
	g_Base_Table_Ext_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Base_Table_Prefix_Field_Array apex_t_varchar2 := apex_t_varchar2();
	g_Key_Column_Ext_Field_Array apex_t_varchar2 := apex_t_varchar2();
	
	FUNCTION Find_Tables_Prefix RETURN VARCHAR2
    IS
    	v_Base_Table_Prefix DATA_BROWSER_CONFIG.Base_Table_Prefix%TYPE;
    BEGIN
    	-- calculate default value for g_Base_Table_Prefix
    	-- find the longest common prefix used in all table names.
		WITH BASE_TABLES AS (
			SELECT A.TABLE_NAME
			FROM SYS.USER_TABLES A
			WHERE A.IOT_NAME IS NULL	-- skip overflow tables of index organized tables
			AND A.TEMPORARY = 'N'	-- skip temporary tables
			AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
			AND NOT EXISTS (    -- this table is not part of materialized view
				SELECT 1
				FROM USER_OBJECTS MV
				WHERE MV.OBJECT_NAME = A.TABLE_NAME
				AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
			)
			AND NOT EXISTS (    -- this table is not part of materialized view log 
				SELECT --+ NO_UNNEST
					1
				FROM SYS.USER_MVIEW_LOGS MV
				WHERE MV.LOG_TABLE = A.TABLE_NAME
			)			
            AND NOT EXISTS (
                SELECT 1
                FROM TABLE( apex_string.split('USER%, DATA_BROWSER%, APP%, CHANGE_LOG%, PLUGIN%', ', ') ) P
                WHERE A.TABLE_NAME LIKE P.COLUMN_VALUE ESCAPE '\'
            )
		), ITERATIONS AS (
			SELECT LEVEL N
			FROM DUAL CONNECT BY LEVEL <= 3
		)
        SELECT DISTINCT 
        	LISTAGG(TABLE_PREFIX, ', ') WITHIN GROUP (ORDER BY CNT DESC)
        INTO v_Base_Table_Prefix
        FROM (
            SELECT S.TABLE_PREFIX, N,  S.CNT, 
                FIRST_VALUE(N) OVER (ORDER BY N*N*CNT DESC) OPT_N
            FROM (
                SELECT TABLE_PREFIX, N, COUNT(DISTINCT TABLE_NAME) CNT
                FROM (
                    SELECT A.TABLE_NAME , B.N, SUBSTR(A.TABLE_NAME, 1, INSTR(A.TABLE_NAME, '_', 1, B.N)) TABLE_PREFIX
                    FROM (SELECT TABLE_NAME FROM BASE_TABLES) A, ITERATIONS B
                ) 
                where TABLE_PREFIX IS NOT NULL
                group by TABLE_PREFIX, N
            ) S
        ) WHERE CNT > 2 and N = OPT_N;
		return v_Base_Table_Prefix;
	exception when NO_DATA_FOUND then
		return null;
	end Find_Tables_Prefix;

	PROCEDURE Save_Config_Defaults
    IS PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
		UPDATE DATA_BROWSER_CONFIG
		SET (Edit_Tables_Pattern, ReadOnly_Tables_Pattern, Admin_Tables_Pattern,
			Included_Tables_Pattern, Excluded_Tables_Pattern, ReadOnly_Columns_Pattern,
			Hidden_Columns_Pattern, Data_Deduction_Pattern, Ignored_Columns_Pattern, Display_Columns_Pattern,
			File_Name_Column_Pattern, Mime_Type_Column_Pattern, File_Created_Column_Pattern, File_Content_Column_Pattern,
			File_Privilege_Fld_Pattern, Encrypted_Column_Pattern, Obfuscation_Column_Pattern, Upper_Names_Column_Pattern, Flip_State_Column_Pattern,
			Index_Format_Field_Pattern, File_Folder_Field_Pattern, Folder_Parent_Field_Pattern, Folder_Name_Field_Pattern,
			Active_Lov_Fields_Pattern, Soft_Lock_Field_Pattern, Html_Fields_Pattern, Hand_Signatur_Pattern,
			Calendar_Start_Date_Pattern, Calendar_End_Date_Pattern, Summand_Field_Pattern, Minuend_Field_Pattern, Factors_Field_Pattern,
	       	DateTime_Columns_Pattern, Password_Column_Pattern, Row_Version_Column_Pattern, Row_Lock_Column_Pattern,
	       	Soft_Delete_Column_Pattern, Ordering_Column_Pattern, Audit_Column_Pattern, 
	       	Currency_Column_Pattern, Thumbnail_Column_Pattern, Yes_No_Columns_Pattern, 
			Key_Column_Ext, Base_Table_Prefix, Base_Table_Ext,
			Base_View_Prefix, Base_View_Ext, History_View_Ext
        ) = (
        	SELECT g_Edit_Tables_Pattern, g_ReadOnly_Tables_Pattern, g_Admin_Tables_Pattern,
        		g_Included_Tables_Pattern, g_Excluded_Tables_Pattern, g_ReadOnly_Columns_Pattern,
        		g_Hidden_Columns_Pattern, g_Data_Deduction_Pattern, g_Ignored_Columns_Pattern, g_Display_Columns_Pattern,
        		g_File_Name_Column_Pattern, g_Mime_Type_Column_Pattern, g_File_Created_Column_Pattern, g_File_Content_Column_Pattern,
				g_File_Privilege_Fld_Pattern, g_Encrypted_Column_Pattern, g_Obfuscation_Column_Pattern, g_Upper_Names_Column_Pattern, g_Flip_State_Column_Pattern,
        		g_Index_Format_Field_Pattern, g_File_Folder_Field_Pattern, g_Folder_Parent_Field_Pattern, g_Folder_Name_Field_Pattern,
        		g_Active_Lov_Fields_Pattern, g_Soft_Lock_Field_Pattern, g_Html_Fields_Pattern, g_Hand_Signatur_Pattern,
        		g_Calendar_Start_Date_Pattern, g_Calendar_End_Date_Pattern, g_Summand_Field_Pattern, g_Minuend_Field_Pattern, g_Factors_Field_Pattern,
         		g_DateTime_Columns_Pattern, g_Password_Column_Pattern, g_Row_Version_Column_Pattern, g_Row_Lock_Column_Pattern,
        		g_Soft_Delete_Column_Pattern, g_Ordering_Column_Pattern, g_Audit_Column_Pattern, 
        		g_Currency_Column_Pattern, g_Thumbnail_Column_Pattern, g_Yes_No_Columns_Pattern, 
        		g_Key_Column_Ext, g_Base_Table_Prefix, g_Base_Table_Ext,
				g_Base_View_Prefix, g_Base_View_Ext, g_History_View_Ext
        	FROM DUAL
        ) WHERE ID = g_Configuration_ID;
        if SQL%ROWCOUNT = 0 then
			if g_Base_Table_Prefix IS NULL then 
				g_Base_Table_Prefix := data_browser_pattern.Find_Tables_Prefix;
			end if;
        	INSERT INTO DATA_BROWSER_CONFIG(ID,
        		Edit_Tables_Pattern, ReadOnly_Tables_Pattern, Admin_Tables_Pattern,
        		Included_Tables_Pattern, Excluded_Tables_Pattern, ReadOnly_Columns_Pattern,
				Hidden_Columns_Pattern, Data_Deduction_Pattern, Ignored_Columns_Pattern, Display_Columns_Pattern,
				File_Name_Column_Pattern, Mime_Type_Column_Pattern, File_Created_Column_Pattern, File_Content_Column_Pattern,
				File_Privilege_Fld_Pattern, Encrypted_Column_Pattern, Obfuscation_Column_Pattern, Upper_Names_Column_Pattern, Flip_State_Column_Pattern,
        		Index_Format_Field_Pattern, File_Folder_Field_Pattern, Folder_Parent_Field_Pattern, Folder_Name_Field_Pattern,
        		Active_Lov_Fields_Pattern, Soft_Lock_Field_Pattern, Html_Fields_Pattern, Hand_Signatur_Pattern,
        		Calendar_Start_Date_Pattern, Calendar_End_Date_Pattern, Summand_Field_Pattern, Minuend_Field_Pattern, Factors_Field_Pattern,
	       		DateTime_Columns_Pattern, Password_Column_Pattern, Row_Version_Column_Pattern, Row_Lock_Column_Pattern,
	       		Soft_Delete_Column_Pattern, Ordering_Column_Pattern, Audit_Column_Pattern, Hide_Audit_Columns, Currency_Column_Pattern, Thumbnail_Column_Pattern,
	       		Yes_No_Columns_Pattern, Key_Column_Ext, Base_Table_Prefix, Base_Table_Ext,
				Base_View_Prefix, Base_View_Ext, History_View_Ext
			)
			VALUES (g_Configuration_ID,
				g_Edit_Tables_Pattern, g_ReadOnly_Tables_Pattern, g_Admin_Tables_Pattern,
				g_Included_Tables_Pattern, g_Excluded_Tables_Pattern, g_ReadOnly_Columns_Pattern,
        		g_Hidden_Columns_Pattern, g_Data_Deduction_Pattern, g_Ignored_Columns_Pattern, g_Display_Columns_Pattern,
        		g_File_Name_Column_Pattern, g_Mime_Type_Column_Pattern, g_File_Created_Column_Pattern, g_File_Content_Column_Pattern,
        		g_File_Privilege_Fld_Pattern, g_Encrypted_Column_Pattern, g_Obfuscation_Column_Pattern, g_Upper_Names_Column_Pattern, g_Flip_State_Column_Pattern,
        		g_Index_Format_Field_Pattern, g_File_Folder_Field_Pattern, g_Folder_Parent_Field_Pattern, g_Folder_Name_Field_Pattern,
        		g_Active_Lov_Fields_Pattern, g_Soft_Lock_Field_Pattern, g_Html_Fields_Pattern, g_Hand_Signatur_Pattern,
        		g_Calendar_Start_Date_Pattern, g_Calendar_End_Date_Pattern, g_Summand_Field_Pattern, g_Minuend_Field_Pattern, g_Factors_Field_Pattern,
        		g_DateTime_Columns_Pattern, g_Password_Column_Pattern, g_Row_Version_Column_Pattern, g_Row_Lock_Column_Pattern,
        		g_Soft_Delete_Column_Pattern, g_Ordering_Column_Pattern, g_Audit_Column_Pattern, g_Hide_Audit_Columns, g_Currency_Column_Pattern, g_Thumbnail_Column_Pattern,
        		g_Yes_No_Columns_Pattern, g_Key_Column_Ext, g_Base_Table_Prefix, g_Base_Table_Ext,
				g_Base_View_Prefix, g_Base_View_Ext, g_History_View_Ext
			);
        end if;
        COMMIT;
    END Save_Config_Defaults;

    FUNCTION Get_File_Name_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_File_Name_Column_Pattern; END;
    FUNCTION Get_Mime_Type_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Mime_Type_Column_Pattern; END;
    FUNCTION Get_File_Created_Col_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_File_Created_Column_Pattern; END;
    FUNCTION Get_File_Content_Col_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_File_Content_Column_Pattern; END;

    FUNCTION Get_Index_Format_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Index_Format_Field_Pattern; END;
    FUNCTION Get_File_Folder_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_File_Folder_Field_Pattern; END;
    FUNCTION Get_Folder_Parent_Fld_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Folder_Parent_Field_Pattern; END;
    FUNCTION Get_Folder_Name_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Folder_Name_Field_Pattern; END;
    FUNCTION Get_Active_Lov_Fields_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Active_Lov_Fields_Pattern; END;

    
    FUNCTION Get_File_Privilege_Fld_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_File_Privilege_Fld_Pattern; END;
    
    FUNCTION Get_Encrypted_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Encrypted_Column_Pattern; END;
    
------------------------------------------------------------------------------------------    
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

	FUNCTION Match_Included_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Table_Name, g_Included_Tables_Array); END;

	FUNCTION Match_Excluded_Tables (p_Table_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Table_Name, g_Excluded_Tables_Array); END;


	FUNCTION Match_Upper_Names_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(UPPER(p_Column_Name), g_Upper_Names_Column_Array); END;


	FUNCTION Match_Obfuscation_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Obfuscation_Column_Array); END;

	FUNCTION Match_ReadOnly_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_ReadOnly_Columns_Array); END;

	FUNCTION Match_Hidden_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Hidden_Columns_Array); END;

	FUNCTION Match_Data_Deduction_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Data_Deduction_Array); END;

	FUNCTION Match_Ignored_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Ignored_Columns_Array); END;

	FUNCTION Match_Display_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Display_Columns_Array); END;

	FUNCTION Match_Yes_No_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Yes_No_Columns_Array); END;

	FUNCTION Match_Encrypted_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Encrypted_Column_Array); END;
	FUNCTION Match_Flip_State_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Flip_State_Column_Array); END;
	FUNCTION Match_Active_Lov_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Active_Lov_Fields_Array); END;
	FUNCTION Match_Lock_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Soft_Lock_Field_Array); END;
	FUNCTION Match_Html_Fields_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Html_Fields_Array); END;
	FUNCTION Match_Calendar_Start_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Calendar_Start_Date_Array); END;
	FUNCTION Match_Calendar_End_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Calendar_End_Date_Array); END;
	FUNCTION Match_Summand_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Summand_Field_Array); END;
	FUNCTION Match_Minuend_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Minuend_Field_Array); END;
	FUNCTION Match_Factors_Field_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Factors_Field_Array); END;
	FUNCTION Match_DateTime_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_DateTime_Columns_Array); END;
	FUNCTION Match_Password_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Password_Column_Array); END;
	FUNCTION Match_Row_Version_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Row_Version_Column_Array); END;
	FUNCTION Match_Row_Lock_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Row_Lock_Column_Array); END;
	FUNCTION Match_Soft_Delete_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Soft_Delete_Column_Array); END;
	FUNCTION Match_Ordering_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Ordering_Column_Array); END;
	FUNCTION Match_Audit_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Audit_Column_Array); END;
	FUNCTION Match_Currency_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Currency_Column_Array); END;
	FUNCTION Match_Thumbnail_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Thumbnail_Column_Array); END;
	FUNCTION Match_File_Name_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_File_Name_Column_Array); END;
	FUNCTION Match_Mime_Type_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Mime_Type_Column_Array); END;
	FUNCTION Match_File_Created_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_File_Created_Column_Array); END;
	FUNCTION Match_File_Content_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_File_Content_Column_Array); END;
	FUNCTION Match_Index_Format_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Index_Format_Field_Array); END;
	FUNCTION Match_File_Folder_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_File_Folder_Field_Array); END;
	FUNCTION Match_Folder_Parent_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Folder_Parent_Field_Array); END;
	FUNCTION Match_Folder_Name_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_Folder_Name_Field_Array); END;
	FUNCTION Match_File_Privilege_Columns (p_Column_Name VARCHAR2) RETURN VARCHAR2 -- YES / NO
	IS 
	PRAGMA UDF;
	BEGIN RETURN Match_Column_Pattern(p_Column_Name, g_File_Privilege_Fld_Array); END;
	
------------------------------------------------------------------------------------------    
    FUNCTION Get_Obfuscation_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Obfuscation_Column_Pattern; END;
    
    FUNCTION Get_Upper_Names_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Upper_Names_Column_Pattern; END;
    

    FUNCTION Get_Flip_State_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Flip_State_Column_Pattern; END;
    
    FUNCTION Get_Soft_Lock_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Soft_Lock_Field_Pattern; END;
    
    FUNCTION Get_Html_Fields_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Html_Fields_Pattern; END;
    
    FUNCTION Get_Hand_Signatur_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Hand_Signatur_Pattern; END;
    
    FUNCTION Get_Calend_Start_Date_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Calendar_Start_Date_Pattern; END;
    
    FUNCTION Get_Calendar_End_Date_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Calendar_End_Date_Pattern; END;
    
    FUNCTION Get_Summand_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Summand_Field_Pattern; END;
    
    FUNCTION Get_Minuend_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Minuend_Field_Pattern; END;
    
    FUNCTION Get_Factors_Field_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Factors_Field_Pattern; END;

    FUNCTION Get_Row_Version_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Row_Version_Column_Pattern; END;
    
    FUNCTION Get_Row_Lock_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Row_Lock_Column_Pattern; END;
    
    FUNCTION Get_Soft_Delete_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Soft_Delete_Column_Pattern; END;
    
    FUNCTION Get_Ordering_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Ordering_Column_Pattern; END;
    
    FUNCTION Get_Audit_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Audit_Column_Pattern; END;

    FUNCTION Get_Currency_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Currency_Column_Pattern; END;

    FUNCTION Get_Thumbnail_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN g_Thumbnail_Column_Pattern; END;

	FUNCTION Get_ReadOnly_Columns_Pattern RETURN VARCHAR2 IS BEGIN RETURN REPLACE(g_ReadOnly_Columns_Pattern,'_','\_'); END;
	FUNCTION Get_Hidden_Columns_Pattern RETURN VARCHAR2 IS BEGIN RETURN REPLACE(g_Hidden_Columns_Pattern,'_','\_'); END;
	FUNCTION Get_Hide_Audit_Columns RETURN VARCHAR2 IS BEGIN RETURN g_Hide_Audit_Columns; END;
	FUNCTION Get_Data_Deduction_Pattern RETURN VARCHAR2 IS BEGIN RETURN REPLACE(g_Data_Deduction_Pattern,'_','\_'); END;
	FUNCTION Get_Ignored_Columns_Pattern RETURN VARCHAR2 IS BEGIN RETURN REPLACE(g_Ignored_Columns_Pattern,'_','\_'); END;
    FUNCTION Get_Display_Columns_Pattern RETURN VARCHAR2 IS BEGIN RETURN REPLACE(g_Display_Columns_Pattern,'_','\_'); END;
    FUNCTION Get_Yes_No_Columns_Pattern RETURN VARCHAR2 IS BEGIN RETURN REPLACE(g_Yes_No_Columns_Pattern,'_','\_'); END;

    FUNCTION Get_DateTime_Columns_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN REPLACE(g_DateTime_Columns_Pattern,'_','\_'); END;
    
    FUNCTION Get_Password_Column_Pattern RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN REPLACE(g_Password_Column_Pattern,'_','\_'); END;

    FUNCTION Get_Base_Table_Ext RETURN VARCHAR2 IS BEGIN RETURN g_Base_Table_Ext; END;
    FUNCTION Get_Base_View_Prefix RETURN VARCHAR2 IS BEGIN RETURN g_Base_View_Prefix; END;
    FUNCTION Get_Base_View_Ext RETURN VARCHAR2 IS BEGIN RETURN g_Base_View_Ext; END;
    FUNCTION Get_History_View_Name(p_Name VARCHAR2) RETURN VARCHAR2
    IS
	PRAGMA UDF;
    BEGIN RETURN p_Name || g_History_View_Ext; END;

	PROCEDURE Load_Pattern_Arrays
    IS 
    BEGIN
		g_Edit_Tables_Array := apex_string.split(REPLACE(g_Edit_Tables_Pattern,'_','\_'), ',');
		g_ReadOnly_Tables_Array := apex_string.split(REPLACE(g_ReadOnly_Tables_Pattern,'_','\_'), ',');
		g_Admin_Tables_Array := apex_string.split(REPLACE(g_Admin_Tables_Pattern,'_','\_'), ',');
		g_Included_Tables_Array := apex_string.split(REPLACE(g_Included_Tables_Pattern,'_','\_'), ',');
		g_Excluded_Tables_Array := apex_string.split(REPLACE(g_Excluded_Tables_Pattern,'_','\_'), ',');
		g_Upper_Names_Column_Array := apex_string.split(REPLACE(g_Upper_Names_Column_Pattern,'_','\_'), ',');
		g_Obfuscation_Column_Array := apex_string.split(REPLACE(g_Obfuscation_Column_Pattern,'_','\_'), ',');
		g_ReadOnly_Columns_Array := apex_string.split(REPLACE(g_ReadOnly_Columns_Pattern,'_','\_'), ',');
		g_Hidden_Columns_Array := apex_string.split(REPLACE(g_Hidden_Columns_Pattern,'_','\_'), ',');
		g_Data_Deduction_Array := apex_string.split(REPLACE(g_Data_Deduction_Pattern,'_','\_'), ',');
		g_Ignored_Columns_Array := apex_string.split(REPLACE(g_Ignored_Columns_Pattern,'_','\_'), ',');
		g_Display_Columns_Array := apex_string.split(REPLACE(g_Display_Columns_Pattern,'_','\_'), ',');
		g_Yes_No_Columns_Array := apex_string.split(REPLACE(g_Yes_No_Columns_Pattern,'_','\_'), ',');

		g_Encrypted_Column_Array := apex_string.split(REPLACE(g_Encrypted_Column_Pattern,'_','\_'), ',');
		g_Flip_State_Column_Array := apex_string.split(REPLACE(g_Flip_State_Column_Pattern,'_','\_'), ',');
		g_Active_Lov_Fields_Array := apex_string.split(REPLACE(g_Active_Lov_Fields_Pattern,'_','\_'), ',');
		g_Soft_Lock_Field_Array := apex_string.split(REPLACE(g_Soft_Lock_Field_Pattern,'_','\_'), ',');
		g_Html_Fields_Array := apex_string.split(REPLACE(g_Html_Fields_Pattern,'_','\_'), ',');
		g_Calendar_Start_Date_Array := apex_string.split(REPLACE(g_Calendar_Start_Date_Pattern,'_','\_'), ',');
		g_Calendar_End_Date_Array := apex_string.split(REPLACE(g_Calendar_End_Date_Pattern,'_','\_'), ',');
		g_Summand_Field_Array := apex_string.split(REPLACE(g_Summand_Field_Pattern,'_','\_'), ',');
		g_Minuend_Field_Array := apex_string.split(REPLACE(g_Minuend_Field_Pattern,'_','\_'), ',');
		g_Factors_Field_Array := apex_string.split(REPLACE(g_Factors_Field_Pattern,'_','\_'), ',');
		g_DateTime_Columns_Array := apex_string.split(REPLACE(g_DateTime_Columns_Pattern,'_','\_'), ',');
		g_Password_Column_Array := apex_string.split(REPLACE(g_Password_Column_Pattern,'_','\_'), ',');
		g_Row_Version_Column_Array := apex_string.split(REPLACE(g_Row_Version_Column_Pattern,'_','\_'), ',');
		g_Row_Lock_Column_Array := apex_string.split(REPLACE(g_Row_Lock_Column_Pattern,'_','\_'), ',');
		g_Soft_Delete_Column_Array := apex_string.split(REPLACE(g_Soft_Delete_Column_Pattern,'_','\_'), ',');
		g_Ordering_Column_Array := apex_string.split(REPLACE(g_Ordering_Column_Pattern,'_','\_'), ',');
		g_Audit_Column_Array := apex_string.split(REPLACE(g_Audit_Column_Pattern,'_','\_'), ',');
		g_Currency_Column_Array := apex_string.split(REPLACE(g_Currency_Column_Pattern,'_','\_'), ',');
		g_Thumbnail_Column_Array := apex_string.split(REPLACE(g_Thumbnail_Column_Pattern,'_','\_'), ',');
		g_File_Name_Column_Array := apex_string.split(REPLACE(g_File_Name_Column_Pattern,'_','\_'), ',');
		g_Mime_Type_Column_Array := apex_string.split(REPLACE(g_Mime_Type_Column_Pattern,'_','\_'), ',');
		g_File_Created_Column_Array := apex_string.split(REPLACE(g_File_Created_Column_Pattern,'_','\_'), ',');
		g_File_Content_Column_Array := apex_string.split(REPLACE(g_File_Content_Column_Pattern,'_','\_'), ',');
		g_Index_Format_Field_Array := apex_string.split(REPLACE(g_Index_Format_Field_Pattern,'_','\_'), ',');
		g_File_Folder_Field_Array := apex_string.split(REPLACE(g_File_Folder_Field_Pattern,'_','\_'), ',');
		g_Folder_Parent_Field_Array := apex_string.split(REPLACE(g_Folder_Parent_Field_Pattern,'_','\_'), ',');
		g_Folder_Name_Field_Array := apex_string.split(REPLACE(g_Folder_Name_Field_Pattern,'_','\_'), ',');
		g_File_Privilege_Fld_Array := apex_string.split(REPLACE(g_File_Privilege_Fld_Pattern,'_','\_'), ',');
		g_Base_Table_Ext_Field_Array := apex_string.split(REPLACE(g_Base_Table_Ext, '$', '\$'), ',');
		g_Base_Table_Prefix_Field_Array := apex_string.split(REPLACE(g_Base_Table_Prefix, '$', '\$'), ',');
		g_Key_Column_Ext_Field_Array := apex_string.split(g_Key_Column_Ext, ',');
		for c_idx IN 1..g_Key_Column_Ext_Field_Array.count loop
			g_Key_Column_Ext_Field_Array(c_idx) := '(.*)' || REPLACE(g_Key_Column_Ext_Field_Array(c_idx), '$', '\$') || '(\d*)$'; -- remove ending _ID2
		end loop;
    END Load_Pattern_Arrays;

	PROCEDURE Load_Config
    IS 
    BEGIN
		$IF data_browser_pattern.g_debug $THEN
			apex_debug.info('data_browser_pattern.Load_Config starting');
		$END
        SELECT
        	Edit_Tables_Pattern, ReadOnly_Tables_Pattern, Admin_Tables_Pattern,
        	Included_Tables_Pattern, Excluded_Tables_Pattern, ReadOnly_Columns_Pattern,
        	Hidden_Columns_Pattern, Data_Deduction_Pattern, Ignored_Columns_Pattern, Display_Columns_Pattern,
			File_Name_Column_Pattern, Mime_Type_Column_Pattern, File_Created_Column_Pattern, File_Content_Column_Pattern,
			File_Privilege_Fld_Pattern, Encrypted_Column_Pattern, Obfuscation_Column_Pattern, Upper_Names_Column_Pattern, Flip_State_Column_Pattern,
			Index_Format_Field_Pattern, File_Folder_Field_Pattern, Folder_Parent_Field_Pattern, Folder_Name_Field_Pattern,
			Active_Lov_Fields_Pattern, Soft_Lock_Field_Pattern, Html_Fields_Pattern, Hand_Signatur_Pattern,
			Calendar_Start_Date_Pattern, Calendar_End_Date_Pattern, Summand_Field_Pattern, Minuend_Field_Pattern, Factors_Field_Pattern,
	       	DateTime_Columns_Pattern, Password_Column_Pattern, Row_Version_Column_Pattern, Row_Lock_Column_Pattern,
	       	Soft_Delete_Column_Pattern, Ordering_Column_Pattern, Audit_Column_Pattern, Currency_Column_Pattern, Thumbnail_Column_Pattern,
	       	Yes_No_Columns_Pattern, 
	       	Key_Column_Ext, Base_Table_Prefix, Base_Table_Ext,
			Base_View_Prefix, Base_View_Ext, History_View_Ext
        INTO
        	g_Edit_Tables_Pattern, g_ReadOnly_Tables_Pattern, g_Admin_Tables_Pattern,
        	g_Included_Tables_Pattern, g_Excluded_Tables_Pattern, g_ReadOnly_Columns_Pattern,
        	g_Hidden_Columns_Pattern, g_Data_Deduction_Pattern, g_Ignored_Columns_Pattern, g_Display_Columns_Pattern,
        	g_File_Name_Column_Pattern, g_Mime_Type_Column_Pattern, g_File_Created_Column_Pattern, g_File_Content_Column_Pattern,
        	g_File_Privilege_Fld_Pattern, g_Encrypted_Column_Pattern, g_Obfuscation_Column_Pattern, g_Upper_Names_Column_Pattern, g_Flip_State_Column_Pattern,
			g_Index_Format_Field_Pattern, g_File_Folder_Field_Pattern, g_Folder_Parent_Field_Pattern, g_Folder_Name_Field_Pattern,
			g_Active_Lov_Fields_Pattern, g_Soft_Lock_Field_Pattern, g_Html_Fields_Pattern, g_Hand_Signatur_Pattern,
			g_Calendar_Start_Date_Pattern, g_Calendar_End_Date_Pattern, g_Summand_Field_Pattern, g_Minuend_Field_Pattern, g_Factors_Field_Pattern,
        	g_DateTime_Columns_Pattern, g_Password_Column_Pattern, g_Row_Version_Column_Pattern, g_Row_Lock_Column_Pattern,
        	g_Soft_Delete_Column_Pattern, g_Ordering_Column_Pattern, g_Audit_Column_Pattern, g_Currency_Column_Pattern, g_Thumbnail_Column_Pattern,
        	g_Yes_No_Columns_Pattern, 
        	g_Key_Column_Ext, g_Base_Table_Prefix, g_Base_Table_Ext,
			g_Base_View_Prefix, g_Base_View_Ext, g_History_View_Ext
        FROM DATA_BROWSER_CONFIG
        WHERE ID = g_Configuration_ID
        AND (Included_Tables_Pattern IS NOT NULL
        OR Excluded_Tables_Pattern IS NOT NULL 
        OR Admin_Tables_Pattern IS NOT NULL);
        
		Load_Pattern_Arrays;
		$IF data_browser_pattern.g_debug $THEN
			apex_debug.info('data_browser_pattern.Load_Config done');
		$END
    EXCEPTION WHEN NO_DATA_FOUND THEN
    	NULL;
    END Load_Config;

BEGIN
	Load_Config;
END data_browser_pattern;
/
show errors
