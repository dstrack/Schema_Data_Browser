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
-- usage --
declare
	v_Data_Source_ID NUMBER;
begin
	data_browser_Reporter.Reporter_Update_Whitelist;
	data_browser_Reporter.Reporter_Update_Users;
	data_browser_Reporter.Reporter_Data_Source ( 
		p_Table_Name => :P30_TABLE_NAME, 
		p_Unique_Key_Column => :P30_LINK_KEY,
		p_View_Mode => :P30_VIEW_MODE, 
		p_Join_Options => :P30_JOINS,
		p_Parent_Name => :P30_PARENT_NAME,
		p_Parent_Key_Column => :P30_FKEY_COLUMN,
		p_Data_Source_ID => v_Data_Source_ID
	);
end;

Authorization Scheme 
	Access Data Reporter: 
	select 1 from all_tables where table_name = 'EBA_DP_DATA_SOURCES'
*/

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'EBA_DP_DATA_SOURCES';
	if v_count = 1 then 
		v_stat := q'[
		CREATE OR REPLACE PACKAGE data_browser_Reporter
		AUTHID DEFINER -- enable caller to find users (V_CONTEXT_USERS).
		AS

			PROCEDURE Reporter_Update_Whitelist;

			PROCEDURE Reporter_Update_Users;

			PROCEDURE Reporter_Data_Source (
				p_Table_name IN VARCHAR2,
				p_Unique_Key_Column VARCHAR2,
				p_Select_Columns VARCHAR2 DEFAULT NULL,
				p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
				p_Join_Options VARCHAR2 DEFAULT NULL,
				p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
				p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
				p_Data_Source_ID OUT NUMBER
			);

		end data_browser_Reporter;
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE OR REPLACE PACKAGE BODY data_browser_Reporter
		IS
			PROCEDURE Reporter_Update_Whitelist 
			is
			begin 
				MERGE INTO EBA_DP_WHITELIST_OBJECTS D
				USING (SELECT NVL(S.OWNER, P.OWNER) OWNER, 
							NVL(S.OBJECT_NAME, P.OBJECT_NAME) OBJECT_NAME, 
							S.OBJECT_TYPE,
							case when S.OBJECT_NAME IS NULL then 'D' else 'U' end OPERATION
					FROM (SELECT VIEW_NAME OBJECT_NAME, 
								SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, 
								case when VIEW_NAME = TABLE_NAME then 'TABLE' else 'VIEW' end OBJECT_TYPE
						FROM MVDATA_BROWSER_VIEWS
						WHERE IS_ADMIN_TABLE = 'N'
					) S
					FULL OUTER JOIN EBA_DP_WHITELIST_OBJECTS P ON P.OBJECT_NAME = S.OBJECT_NAME AND P.OWNER = S.OWNER
				) S
				ON (D.OBJECT_NAME = S.OBJECT_NAME AND D.OWNER = S.OWNER)
				WHEN MATCHED THEN
					UPDATE SET D.OBJECT_TYPE = S.OBJECT_TYPE WHERE S.OPERATION = 'U' 
					DELETE WHERE S.OPERATION = 'D' 
				WHEN NOT MATCHED THEN
					INSERT (D.OWNER, D.OBJECT_NAME, D.OBJECT_TYPE)
					VALUES (S.OWNER, S.OBJECT_NAME, S.OBJECT_TYPE)
				;
				COMMIT;
			end;
	
			PROCEDURE Reporter_Update_Users
			is
			begin 
				MERGE INTO EBA_DP_USERS D 
				USING (SELECT NVL(S.USERNAME, P.USERNAME) USERNAME, 
							S.ACCESS_LEVEL_ID,
							case when S.USERNAME IS NULL then 'D' else 'U' end OPERATION
					FROM (SELECT UPPER_LOGIN_NAME USERNAME, 
								case when USER_LEVEL between 0 and 1 then 3 -- Administrator
									when USER_LEVEL between 2 and 4 then 2 -- Contributor
									else 1 -- Reader
								end ACCESS_LEVEL_ID
						FROM V_CONTEXT_USERS) S
					FULL OUTER JOIN EBA_DP_USERS P ON P.USERNAME = S.USERNAME
				) S
				ON (D.USERNAME = S.USERNAME)
				WHEN MATCHED THEN
					UPDATE SET D.ACCESS_LEVEL_ID = S.ACCESS_LEVEL_ID WHERE S.OPERATION = 'U' 
					DELETE WHERE S.OPERATION = 'D' 
				WHEN NOT MATCHED THEN
					INSERT (D.USERNAME, D.ACCESS_LEVEL_ID)
					VALUES (S.USERNAME, S.ACCESS_LEVEL_ID)
				;
				COMMIT;
			end;

			PROCEDURE Reporter_Data_Source (
				p_Table_name IN VARCHAR2,
				p_Unique_Key_Column VARCHAR2,
				p_Select_Columns VARCHAR2 DEFAULT NULL,
				p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
				p_Join_Options VARCHAR2 DEFAULT NULL,
				p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
				p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
				p_Data_Source_ID OUT NUMBER
			)
			is
				v_Record_View_Query	EBA_DP_DATA_SOURCES.SQL_SOURCE%TYPE;
				v_Report_Name EBA_DP_DATA_SOURCES.SOURCE_NAME%TYPE;
				v_Owner_Name EBA_DP_DATA_SOURCES.SOURCE_OWNER%TYPE := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
			begin 
				v_Record_View_Query := data_browser_utl.Get_Detail_View_Query(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Data_Columns_Only => 'NO',
					p_Select_Columns => p_Select_Columns,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => 'YES',
					p_Edit_Mode => 'NO',
					p_Data_Source => 'TABLE',
					p_Data_Format => 'NATIVE',
					p_Join_Options => p_Join_Options,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => 'YES'
				);
				v_Report_Name := data_browser_utl.Get_Report_Description (
					p_Table_Name  => p_Table_name,
					p_Parent_Name => p_Parent_Name,
					p_View_Mode => p_View_Mode
				);
				MERGE INTO EBA_DP_DATA_SOURCES D
				USING (SELECT v_Owner_Name SOURCE_OWNER, 
							v_Report_Name SOURCE_NAME, 
							v_Record_View_Query SQL_SOURCE, 
							'SQL_QUERY' SOURCE_TYPE, 
							'N' ACL_ENABLED_YN, 
							'Generated by data_browser_Reporter' DATA_SOURCE_COMMENTS
						FROM DUAL
					) S
				ON (D.SOURCE_OWNER = S.SOURCE_OWNER AND D.SOURCE_NAME = S.SOURCE_NAME)
				WHEN MATCHED THEN 
					UPDATE SET D.SQL_SOURCE = S.SQL_SOURCE
				WHEN NOT MATCHED THEN
					INSERT (D.SOURCE_OWNER, D.SOURCE_NAME, D.SQL_SOURCE, D.SOURCE_TYPE, D.ACL_ENABLED_YN, D.DATA_SOURCE_COMMENTS)
					VALUES (S.SOURCE_OWNER, S.SOURCE_NAME, S.SQL_SOURCE, S.SOURCE_TYPE, S.ACL_ENABLED_YN, S.DATA_SOURCE_COMMENTS)
				;
				COMMIT;
				SELECT ID INTO p_Data_Source_ID
				FROM EBA_DP_DATA_SOURCES
				WHERE SOURCE_OWNER = v_Owner_Name
				AND SOURCE_NAME = v_Report_Name;
			end;
	
		end data_browser_Reporter;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/
show errors

