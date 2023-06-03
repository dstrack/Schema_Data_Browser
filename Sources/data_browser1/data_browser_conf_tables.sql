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

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DATA_BROWSER_CONFIG';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DATA_BROWSER_CONFIG
		(
			ID                          NUMBER(5) DEFAULT 1 NOT NULL CONSTRAINT DATA_BROWSER_CONFIG_PK PRIMARY KEY,
			Configuration_Name          VARCHAR2(128) DEFAULT 'Schema Data Browser' NOT NULL CONSTRAINT DATA_BROWSER_CONFIG_UN UNIQUE,
			Description					VARCHAR2(2000),
			-------------------------------------------
			-- Access Controls --
			Edit_Enabled_Query 		    VARCHAR2(2000),
			Data_Deduction_Query		VARCHAR2(2000),
			Edit_Tables_Pattern 		VARCHAR2(2000),
			ReadOnly_Tables_Pattern 	VARCHAR2(2000),
			Reports_Application_ID		NUMBER,
			Reports_App_Page_ID			NUMBER,
			Schema_Icon        			VARCHAR2(2000) DEFAULT 'fa-database',
			Client_Application_ID		NUMBER,
			Client_App_Page_ID			NUMBER,
			Developer_Enabled_Query 	VARCHAR2(2000),
			Admin_Enabled_Query 		VARCHAR2(2000),
			Admin_Tables_Pattern 		VARCHAR2(2000),
			Included_Tables_Pattern   	VARCHAR2(2000),
			Excluded_Tables_Pattern   	VARCHAR2(2000),
			-------------------------------------------
			-- Column Display Controls --
			ReadOnly_Columns_Pattern   	VARCHAR2(2000),
			Hidden_Columns_Pattern    	VARCHAR2(2000),
			Ignored_Columns_Pattern   	VARCHAR2(2000),
			Data_Deduction_Pattern  	VARCHAR2(2000),
			Display_Columns_Pattern   	VARCHAR2(2000),
			DateTime_Columns_Pattern   	VARCHAR2(2000),
			Password_Column_Pattern		VARCHAR2(2000),
			Row_Version_Column_Pattern	VARCHAR2(2000),
			Row_Lock_Column_Pattern		VARCHAR2(2000),
			Soft_Delete_Column_Pattern	VARCHAR2(2000),
			Ordering_Column_Pattern		VARCHAR2(2000),
			Audit_Column_Pattern		VARCHAR2(2000),
			Hide_Audit_Columns			VARCHAR2(5) DEFAULT 'YES' NOT NULL CONSTRAINT DATA_BRO_CONF_Hide_Audit_CK CHECK ( Hide_Audit_Columns IN ('YES','NO') ),
			Currency_Column_Pattern		VARCHAR2(2000),
			Thumbnail_Column_Pattern 	VARCHAR2(2000),
			-------------------------------------------
			-- File Meta Data Columns --
			File_Name_Column_Pattern	VARCHAR2(2000),
			Mime_Type_Column_Pattern	VARCHAR2(2000),
			File_Created_Column_Pattern	VARCHAR2(2000),
			File_Content_Column_Pattern	VARCHAR2(2000),
			Index_Format_Field_Pattern	VARCHAR2(2000),
			File_Folder_Field_Pattern	VARCHAR2(2000),
			Folder_Parent_Field_Pattern	VARCHAR2(2000),
			Folder_Name_Field_Pattern	VARCHAR2(2000),
			-------------------------------------------
			File_Privilege_Fld_Pattern	VARCHAR2(2000),
			Encrypted_Column_Pattern	VARCHAR2(2000),
			Obfuscation_Column_Pattern	VARCHAR2(2000),
			Upper_Names_Column_Pattern	VARCHAR2(2000),
			Flip_State_Column_Pattern	VARCHAR2(2000),
			-------------------------------------------
			Active_Lov_Fields_Pattern	VARCHAR2(2000),
			Soft_Lock_Field_Pattern		VARCHAR2(2000),
			Html_Fields_Pattern			VARCHAR2(2000),
			Hand_Signatur_Pattern		VARCHAR2(2000),
			Calendar_Start_Date_Pattern VARCHAR2(2000),
			Calendar_End_Date_Pattern   VARCHAR2(2000),
			Summand_Field_Pattern		VARCHAR2(2000),
			Minuend_Field_Pattern		VARCHAR2(2000),
			Factors_Field_Pattern		VARCHAR2(2000),
			App_Version_Number			VARCHAR2(64),
			App_Licence_Number			VARCHAR2(64),
			App_Licence_Owner			VARCHAR2(300),
			App_Installation_Code		VARCHAR2(300),
			-------------------------------------------
			-- Yes/No Columns --
			Yes_No_Columns_Pattern   	VARCHAR2(2000),
			Yes_No_Char_Static_LOV		VARCHAR2(64),
			Yes_No_Number_Static_LOV	VARCHAR2(64),
			Detect_Yes_No_Static_LOV	VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Detect_Yes_No_CK CHECK ( Detect_Yes_No_Static_LOV IN ('YES','NO') ),
			-------------------------------------------
			-- Data Format Controls --
			Export_NumChars   			VARCHAR2(64),
			Integer_Goup_Separator		VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Integer_Goup_CK CHECK ( Integer_Goup_Separator IN ('YES','NO') ),
			Decimal_Goup_Separator		VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Decimal_Goup_CK CHECK ( Decimal_Goup_Separator IN ('YES','NO') ),
			Export_Float_Format   		VARCHAR2(64),
			Export_Date_Format   		VARCHAR2(64),
			Export_DateTime_Format   	VARCHAR2(64),
			Export_Timestamp_Format	   	VARCHAR2(64),
			Use_App_Date_Time_Format	VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Use_App_Date_CK CHECK ( Use_App_Date_Time_Format IN ('YES','NO') ),
			Rec_Desc_Delimiter			VARCHAR2(64),
			Rec_Desc_Group_Delimiter	VARCHAR2(64),
			Export_Text_Limit			NUMBER,
			-------------------------------------------
			-- Form Field Controls --
			Minimum_Field_Width			NUMBER,
			Maximum_Field_Width			NUMBER,
			Stretch_Form_Fields			VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Stretch_Form_CK CHECK ( Stretch_Form_Fields IN ('YES','NO') ),
			Select_List_Rows_Limit		NUMBER,
			TextArea_Min_Length			NUMBER,
			-------------------------------------------
			-- Tables and Column Headers --
			Detect_Column_Prefix		VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Detect_Column_CK CHECK ( Detect_Column_Prefix IN ('YES','NO') ),
			Translate_Umlaute			VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Translate_Uml_CK CHECK ( Translate_Umlaute IN ('YES','NO') ),
			Key_Column_Ext				VARCHAR2(2000),
			Base_Table_Prefix			VARCHAR2(2000),
			Base_Table_Ext				VARCHAR2(2000),
			Base_View_Prefix			VARCHAR2(2000),
			Base_View_Ext				VARCHAR2(2000),
			History_View_Ext       		VARCHAR2(2000),
			-------------------------------------------
			-- Import Controls --
			Compare_Case_Insensitive 	VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Compare_Case_CK CHECK ( Compare_Case_Insensitive IN ('YES','NO') ),
			Search_Keys_Unique 			VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Search_Keys_U_CK CHECK ( Search_Keys_Unique IN ('YES','NO') ),
			Insert_Foreign_Keys 		VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Insert_Foreig_CK CHECK ( Insert_Foreign_Keys IN ('YES','NO') ),
			Merge_On_Unique_Keys		VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Merge_On_Uni_CK CHECK ( Merge_On_Unique_Keys IN ('YES','NO') ),
			-------------------------------------------
			-- Table Relations Tree Controls
			Show_Tree_Num_Rows			VARCHAR2(5) DEFAULT 'YES' NOT NULL CONSTRAINT DATA_BRO_CONF_Show_Tree_Num_Rows_CK CHECK ( Show_Tree_Num_Rows IN ('YES','NO') ),
			Update_Tree_Num_Rows		VARCHAR2(5) DEFAULT 'YES' NOT NULL CONSTRAINT DATA_BRO_CONF_Update_Tree_Num_Rows_CK CHECK ( Update_Tree_Num_Rows IN ('YES','NO') ),
			Max_Relations_Levels		NUMBER DEFAULT 4,
			-------------------------------------------
			Row_Version_Number			NUMBER(10) DEFAULT 0 NOT NULL,
			Translations_Published_Date	TIMESTAMP (6) WITH LOCAL TIME ZONE,
			Bytes_Used					NUMBER,
			Tablespace_Names			VARCHAR2(2000),
			Email_From_Address			VARCHAR2(128),
			Errors_Listed_Limit			NUMBER(10) DEFAULT 100 NOT NULL,
			Edit_Rows_Limit				NUMBER(10) DEFAULT 500 NOT NULL,
			Automatic_Sorting_Limit		NUMBER(10) DEFAULT 10000 NOT NULL,
			Automatic_Search_Limit		NUMBER(10) DEFAULT 10000 NOT NULL,
			Navigation_Link_Limit		NUMBER(10) DEFAULT 10 NOT NULL,
			Created_At              	TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL,
			Created_By              	VARCHAR2 (32) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL,
			Last_Modified_At 			TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL,
			Last_Modified_By 			VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL
		) CACHE
		STORAGE (
		  INITIAL 10240
		  NEXT 10240
		  MINEXTENTS 1
		  MAXEXTENTS UNLIMITED
		  BUFFER_POOL KEEP
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	SELECT COUNT(*) INTO v_count
	FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DATA_BROWSER_CONFIG' AND COLUMN_NAME = 'BYTES_USED';
	if v_count = 0 then 
		v_stat := q'[
		ALTER TABLE DATA_BROWSER_CONFIG ADD
		(
			Bytes_Used					NUMBER,
			Tablespace_Names			VARCHAR2(2000)
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DATA_BROWSER_CONFIG' AND COLUMN_NAME = 'SHOW_TREE_NUM_ROWS';
	if v_count = 0 then 
		v_stat := q'[
		ALTER TABLE DATA_BROWSER_CONFIG ADD
		(
			Show_Tree_Num_Rows			VARCHAR2(5) DEFAULT 'YES' NOT NULL CONSTRAINT DATA_BRO_CONF_Show_Tree_Num_Rows_CK CHECK ( Show_Tree_Num_Rows IN ('YES','NO') ),
			Update_Tree_Num_Rows		VARCHAR2(5) DEFAULT 'YES' NOT NULL CONSTRAINT DATA_BRO_CONF_Update_Tree_Num_Rows_CK CHECK ( Update_Tree_Num_Rows IN ('YES','NO') ),
			Max_Relations_Levels		NUMBER DEFAULT 4,
			Email_From_Address			VARCHAR2(128),
			Errors_Listed_Limit			NUMBER(10) DEFAULT 100 NOT NULL,
			Edit_Rows_Limit				NUMBER(10) DEFAULT 500 NOT NULL,
			Automatic_Sorting_Limit		NUMBER(10) DEFAULT 10000 NOT NULL,
			Automatic_Search_Limit		NUMBER(10) DEFAULT 10000 NOT NULL,
			Navigation_Link_Limit		NUMBER(10) DEFAULT 10 NOT NULL
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	-- column Export_DateTime_Format
	SELECT COUNT(*) INTO v_count
	FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DATA_BROWSER_CONFIG' AND COLUMN_NAME = 'EXPORT_DATETIME_FORMAT';
	if v_count = 0 then 
		v_stat := q'[
		ALTER TABLE DATA_BROWSER_CONFIG ADD Export_DateTime_Format   		VARCHAR2(64)
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		UPDATE DATA_BROWSER_CONFIG SET Export_DateTime_Format = 'DD.MM.YYYY HH24:MI:SS'
		]';
		EXECUTE IMMEDIATE v_Stat;
		COMMIT;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DATA_BROWSER_CONFIG' AND COLUMN_NAME = 'MERGE_ON_UNIQUE_KEYS';
	if v_count = 0 then 
		v_stat := q'[
		ALTER TABLE DATA_BROWSER_CONFIG ADD
		(
			Merge_On_Unique_Keys		VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BRO_CONF_Merge_On_Uni_CK CHECK ( Merge_On_Unique_Keys IN ('YES','NO') )
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/

-- make table visible in view SYS.ALL_TABLES
GRANT SELECT ON DATA_BROWSER_CONFIG TO PUBLIC;
