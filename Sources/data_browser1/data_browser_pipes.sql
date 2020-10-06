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

CREATE OR REPLACE PACKAGE data_browser_pipes
AUTHID CURRENT_USER
IS
	
	TYPE rec_table_unique_keys IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		TABLE_OWNER                   VARCHAR2(128), 
		TABLESPACE_NAME				  VARCHAR2(128), 
		CONSTRAINT_NAME               VARCHAR2(128), 
		CONSTRAINT_TYPE               VARCHAR2(1)  , 
		HAS_NULLABLE                  VARCHAR2(3)  , 
		UNIQUE_KEY_COLS				  VARCHAR2(512),
		KEY_COLS_COUNT				  NUMBER,
		DEFERRABLE                    VARCHAR2(14) , 
		DEFERRED                      VARCHAR2(9)  , 
		STATUS                        VARCHAR2(8)  , 
		VALIDATED                     VARCHAR2(13) ,
		IOT_TYPE					  VARCHAR2(12) ,
		AVG_ROW_LEN					  NUMBER,
		NUM_ROWS					  NUMBER,
		BASE_NAME               	  VARCHAR2(128), 
		RUN_NO					      NUMBER,
		KEY_HAS_NEXTVAL				  VARCHAR2(3)  ,
		KEY_HAS_SYS_GUID			  VARCHAR2(3)  ,
		SEQUENCE_OWNER                VARCHAR2(128), 
		SEQUENCE_NAME                 VARCHAR2(128), 
		HAS_SCALAR_KEY                VARCHAR2(3)  , 
		HAS_SERIAL_KEY                VARCHAR2(3)  , 
		READ_ONLY                     VARCHAR2(3),
		REFERENCES_COUNT			  NUMBER
	);
	TYPE tab_table_unique_keys IS TABLE OF rec_table_unique_keys;

	TYPE rec_base_mapping_views IS RECORD (
		VIEW_NAME                     VARCHAR2(128), 
		VIEW_OWNER                    VARCHAR2(128), 
		TABLE_NAME                    VARCHAR2(128), 
		TABLE_OWNER                   VARCHAR2(128), 
		RUN_NO					      NUMBER,
		SHORT_NAME                    VARCHAR2(128),
		READ_ONLY                     VARCHAR2(3)
	);
	TYPE tab_base_mapping_views IS TABLE OF rec_base_mapping_views;
	
	TYPE rec_table_cols_prefix IS RECORD (
		TABLE_NAME                    VARCHAR2(128), 
		OWNER                   	  VARCHAR2(128), 
		COLUMN_PREFIX                 VARCHAR2(128)
	);
	TYPE tab_table_cols_prefix IS TABLE OF rec_table_cols_prefix;

	TYPE rec_table_columns IS RECORD (
		TABLE_NAME              	VARCHAR2(128), 
		TABLE_OWNER                 VARCHAR2(128), 
		COLUMN_ID					NUMBER,
		COLUMN_NAME               	VARCHAR2(128), 
		DATA_TYPE					VARCHAR2(128), 
		DATA_TYPE_OWNER				VARCHAR2(128), 
		NULLABLE					VARCHAR2(1), 
		NUM_DISTINCT				NUMBER,
		DEFAULT_LENGTH				NUMBER,
		DATA_DEFAULT				VARCHAR2(1000), 
		DATA_PRECISION			  	NUMBER,
		DATA_SCALE					NUMBER,
		CHAR_LENGTH					NUMBER,
		HIDDEN_COLUMN				VARCHAR2(3),
		VIRTUAL_COLUMN				VARCHAR2(3)
	);
	TYPE tab_table_columns IS TABLE OF rec_table_columns;

	TYPE rec_unique_ref_columns IS RECORD (
		VIEW_NAME              		VARCHAR2(128), 
		TABLE_NAME              	VARCHAR2(128), 
		TABLE_OWNER                 VARCHAR2(128), 
		COLUMN_NAME               	VARCHAR2(128), 
		POSITION					NUMBER,
		NULLABLE					VARCHAR2(1), 
		DATA_TYPE					VARCHAR2(128), 
		DATA_PRECISION			  	NUMBER,
		DATA_SCALE					NUMBER,
		CHAR_LENGTH					NUMBER,
		U_CONSTRAINT_NAME			VARCHAR2(128),
		U_MEMBERS					NUMBER,
		MATCHING					NUMBER,
		HAS_NULLABLE				NUMBER,
		CONSTRAINT_TYPE				VARCHAR2(1),
		INDEX_OWNER					VARCHAR2(256),
		INDEX_NAME					VARCHAR2(128),
		RANK						NUMBER
	);
	TYPE tab_unique_ref_columns IS TABLE OF rec_unique_ref_columns;

	TYPE rec_foreign_key_columns IS RECORD (
		TABLE_NAME              	VARCHAR2(128), 
		TABLE_OWNER                 VARCHAR2(128), 
		CONSTRAINT_NAME				VARCHAR2(128),
		COLUMN_NAME               	VARCHAR2(128), 
		POSITION					NUMBER,
		COLUMN_ID					NUMBER,
		NULLABLE					VARCHAR2(1),
		DELETE_RULE					VARCHAR2(20),
		R_CONSTRAINT_NAME			VARCHAR2(128),
		R_OWNER						VARCHAR2(128)
	);
	TYPE tab_foreign_key_columns IS TABLE OF rec_foreign_key_columns;

	TYPE rec_sys_objects IS RECORD (
		OBJECT_ID                     NUMBER, 
		OBJECT_TYPE                   VARCHAR2(30), 
		OBJECT_NAME                   VARCHAR2(128),
		OWNER                   	  VARCHAR2(128), 
		STATUS                        VARCHAR2(30)
	);
	TYPE tab_sys_objects IS TABLE OF rec_sys_objects;

	TYPE rec_table_numrows IS RECORD (
		TABLE_NAME                    VARCHAR2(128),
		OWNER                   	  VARCHAR2(128), 
		NUM_ROWS                      NUMBER
	);
	TYPE tab_table_numrows IS TABLE OF rec_table_numrows;

	TYPE rec_references_count IS RECORD (
		R_CONSTRAINT_NAME             VARCHAR2(128),
		R_OWNER                   	  VARCHAR2(128), 
		CNT		                      NUMBER
	);
	TYPE tab_references_count IS TABLE OF rec_references_count;

	TYPE rec_special_columns IS RECORD (
		TABLE_NAME							VARCHAR2(128),
		TABLE_OWNER							VARCHAR2(128),
		ROW_VERSION_COLUMN_NAME				VARCHAR2(128),
		ROW_LOCKED_COLUMN_NAME 				VARCHAR2(128),
		SOFT_LOCK_COLUMN_NAME				VARCHAR2(128),
		FLIP_STATE_COLUMN_NAME 				VARCHAR2(128),
		SOFT_DELETED_COLUMN_NAME			VARCHAR2(128),
		ORDERING_COLUMN_NAME				VARCHAR2(128),
		ACTIVE_LOV_COLUMN_NAME 				VARCHAR2(128),
		HTML_FIELD_COLUMN_NAME 				VARCHAR2(128),
		CALEND_START_DATE_COLUMN_NAME		VARCHAR2(128),
		CALENDAR_END_DATE_COLUMN_NAME		VARCHAR2(128),
		FILE_NAME_COLUMN_NAME				VARCHAR2(128),
		MIME_TYPE_COLUMN_NAME				VARCHAR2(128),
		FILE_DATE_COLUMN_NAME				VARCHAR2(128),
		FILE_CONTENT_COLUMN_NAME			VARCHAR2(128),
		FILE_THUMBNAIL_COLUMN_NAME			VARCHAR2(128),
		FILE_FOLDER_COLUMN_NAME				VARCHAR2(128),
		FOLDER_NAME_COLUMN_NAME				VARCHAR2(128),
		FOLDER_PARENT_COLUMN_NAME			VARCHAR2(128),
		FILE_PRIVILEGE_COLUMN_NAME			VARCHAR2(128),
		INDEX_FORMAT_COLUMN_NAME			VARCHAR2(128),
		AUDIT_DATE_COLUMN_NAME 				VARCHAR2(128),
		AUDIT_USER_COLUMN_NAME 				VARCHAR2(128),
		SUMMAND_COLUMN_NAME					VARCHAR2(128),
		MINUEND_COLUMN_NAME					VARCHAR2(128),
		FACTORS_COLUMN_NAME					VARCHAR2(128),
		COLUMN_PREFIX						VARCHAR2(128)
	);
	TYPE tab_special_columns IS TABLE OF rec_special_columns;

	TYPE rec_Accessible_Schema IS RECORD (
		SCHEMA_NAME VARCHAR2(128),
		APP_VERSION_NUMBER VARCHAR2(64),
		USER_ACCESS_LEVEL NUMBER
	);
	TYPE tab_Accessible_Schema IS TABLE OF rec_Accessible_Schema;

	g_fetch_limit CONSTANT PLS_INTEGER := 100;

	FUNCTION FN_Pipe_Table_Uniquekeys 
	RETURN data_browser_pipes.tab_table_unique_keys PIPELINED;

	FUNCTION FN_Pipe_Mapping_Views
	RETURN data_browser_pipes.tab_base_mapping_views PIPELINED;

	FUNCTION FN_Pipe_Table_Cols_Prefix
	RETURN data_browser_pipes.tab_table_cols_prefix PIPELINED;

	FUNCTION FN_Pipe_Table_Columns
	RETURN data_browser_pipes.tab_table_columns PIPELINED;

	FUNCTION FN_Pipe_Unique_Ref_Columns
	RETURN data_browser_pipes.tab_unique_ref_columns PIPELINED;

	FUNCTION FN_Pipe_Foreign_Key_Columns
	RETURN data_browser_pipes.tab_foreign_key_columns PIPELINED;

	FUNCTION FN_Pipe_Sys_Objects(p_Include_External_Objects VARCHAR2 DEFAULT 'NO')
	RETURN data_browser_pipes.tab_sys_objects PIPELINED;

	FUNCTION FN_Pipe_Table_Numrows
	RETURN data_browser_pipes.tab_table_numrows PIPELINED;

	FUNCTION FN_Pipe_References_Count
	RETURN data_browser_pipes.tab_references_count PIPELINED;

	FUNCTION FN_Pipe_Special_Columns
	RETURN data_browser_pipes.tab_special_columns PIPELINED;

	FUNCTION FN_Pipe_Accessible_Schemas (
		p_User_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_application_id IN NUMBER DEFAULT NV('APP_ID')
	) RETURN tab_Accessible_Schema PIPELINED;
END data_browser_pipes;
/

CREATE OR REPLACE PACKAGE BODY data_browser_pipes 
IS
	FUNCTION FN_Pipe_Table_Uniquekeys 
	RETURN data_browser_pipes.tab_table_unique_keys PIPELINED
	IS
        CURSOR keys_cur
        IS
        	SELECT T.TABLE_NAME, T.TABLE_OWNER, T.TABLESPACE_NAME, T.CONSTRAINT_NAME, T.CONSTRAINT_TYPE,
        		T.HAS_NULLABLE, T.UNIQUE_KEY_COLS, T.KEY_COLS_COUNT, T.DEFERRABLE, T.DEFERRED, T.STATUS, T.VALIDATED,
        		T.IOT_TYPE, T.AVG_ROW_LEN, T.NUM_ROWS, T.BASE_NAME, T.RUN_NO, T.KEY_HAS_NEXTVAL, T.KEY_HAS_SYS_GUID,
        		T.SEQUENCE_OWNER, T.SEQUENCE_NAME, T.HAS_SCALAR_KEY, T.HAS_SERIAL_KEY, 
				case when E.TABLE_NAME IS NOT NULL -- is external table
					then 'YES' 
					else T.READ_ONLY 
				end READ_ONLY,
				NVL(R.CNT, 0) REFERENCES_COUNT        	
        	FROM (
				SELECT DISTINCT
					A.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') TABLE_OWNER,
					A.TABLESPACE_NAME, B.CONSTRAINT_NAME, B.CONSTRAINT_TYPE, B.HAS_NULLABLE,
					B.VIEW_KEY_COLS UNIQUE_KEY_COLS, 
					B.VIEW_KEY_COLS_COUNT KEY_COLS_COUNT, 
					B.DEFERRABLE, B.DEFERRED,
					DECODE(B.STATUS, 'ENABLED', 'ENABLE', 'DISABLED', 'DISABLE') STATUS,
					DECODE(B.VALIDATED, 'VALIDATED', 'VALIDATE', 'NOT VALIDATED', 'NOVALIDATE') VALIDATED,
					A.IOT_TYPE, A.AVG_ROW_LEN, 
					A.NUM_ROWS,				
					changelog_conf.Get_BaseName(A.TABLE_NAME) BASE_NAME,
					NULLIF(DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(A.TABLE_NAME, 1, 23), '_') ORDER BY NLSSORT(A.TABLE_NAME, 'NLS_SORT = WEST_EUROPEAN')), 1) RUN_NO,
					COALESCE(B.KEY_HAS_NEXTVAL, B.TRIGGER_HAS_NEXTVAL, 'NO') KEY_HAS_NEXTVAL,
					COALESCE(B.KEY_HAS_SYS_GUID, B.TRIGGER_HAS_SYS_GUID, 'NO') KEY_HAS_SYS_GUID,
					CAST(B.SEQUENCE_OWNER AS VARCHAR2(128)) SEQUENCE_OWNER,
					CAST(B.SEQUENCE_NAME AS VARCHAR2(128)) SEQUENCE_NAME,
					B.HAS_SCALAR_VIEW_KEY HAS_SCALAR_KEY, 
					B.HAS_SERIAL_VIEW_KEY HAS_SERIAL_KEY,
					-- A.READ_ONLY
					case when EXISTS (    -- this table is part of materialized view
							SELECT -- NO_UNNEST
								1
							FROM SYS.USER_OBJECTS MV
							WHERE MV.OBJECT_NAME = A.TABLE_NAME
							AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
						) then 'YES'
						else A.READ_ONLY
					end READ_ONLY
				FROM SYS.USER_TABLES A, MVBASE_UNIQUE_KEYS B
				WHERE A.TABLE_NAME = B.TABLE_NAME (+) AND SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') = B.TABLE_OWNER (+)
				AND A.IOT_NAME IS NULL	-- skip overflow tables of index organized tables
				AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
				AND A.TEMPORARY = 'N'	-- skip temporary tables
				AND A.SECONDARY = 'N'
				AND A.NESTED = 'NO'
				AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
				AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO'
				UNION ALL 
				SELECT DISTINCT
					A.TABLE_NAME, A.TABLE_OWNER,
					A.TABLESPACE_NAME, B.CONSTRAINT_NAME, B.CONSTRAINT_TYPE, B.HAS_NULLABLE,
					B.VIEW_KEY_COLS UNIQUE_KEY_COLS, 
					B.VIEW_KEY_COLS_COUNT KEY_COLS_COUNT, 
					B.DEFERRABLE, B.DEFERRED,
					DECODE(B.STATUS, 'ENABLED', 'ENABLE', 'DISABLED', 'DISABLE') STATUS,
					DECODE(B.VALIDATED, 'VALIDATED', 'VALIDATE', 'NOT VALIDATED', 'NOVALIDATE') VALIDATED,
					A.IOT_TYPE, A.AVG_ROW_LEN, 
					A.NUM_ROWS,				
					changelog_conf.Get_BaseName(A.TABLE_NAME) BASE_NAME,
					NULLIF(DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(A.TABLE_NAME, 1, 23), '_') ORDER BY NLSSORT(A.TABLE_NAME, 'NLS_SORT = WEST_EUROPEAN')), 1) RUN_NO,
					COALESCE(B.KEY_HAS_NEXTVAL, B.TRIGGER_HAS_NEXTVAL, 'NO') KEY_HAS_NEXTVAL,
					COALESCE(B.KEY_HAS_SYS_GUID, B.TRIGGER_HAS_SYS_GUID, 'NO') KEY_HAS_SYS_GUID,
					CAST(B.SEQUENCE_OWNER AS VARCHAR2(128)) SEQUENCE_OWNER,
					CAST(B.SEQUENCE_NAME AS VARCHAR2(128)) SEQUENCE_NAME,
					B.HAS_SCALAR_VIEW_KEY HAS_SCALAR_KEY, 
					B.HAS_SERIAL_VIEW_KEY HAS_SERIAL_KEY,
					-- A.READ_ONLY
					case when EXISTS (    -- this table is part of materialized view
							SELECT -- NO_UNNEST
								1
							FROM SYS.ALL_OBJECTS MV
							WHERE MV.OBJECT_NAME = A.TABLE_NAME
							AND MV.OWNER = A.TABLE_OWNER
							AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
						) then 'YES'
						when PRIVILEGE = 'SELECT' 
							then 'YES' 
						else A.READ_ONLY
					end READ_ONLY
				FROM (
					select A.TABLE_NAME, A.OWNER TABLE_OWNER, A.TABLESPACE_NAME, 
						A.IOT_TYPE, A.AVG_ROW_LEN, A.NUM_ROWS,	A.READ_ONLY,
						G.GRANTOR, LISTAGG(PRIVILEGE, ',') WITHIN GROUP (ORDER BY PRIVILEGE) PRIVILEGE
					from SYS.ALL_TABLES A
					join SYS.ALL_TAB_PRIVS G on A.TABLE_NAME = G.TABLE_NAME AND A.OWNER = G.GRANTOR 
					where G.TYPE = 'TABLE'
					AND A.OWNER NOT IN (SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'SYS', 'SYSTEM', 'SYSAUX', 'CTXSYS', 'MDSYS', 'OUTLN')
					AND A.IOT_NAME IS NULL	-- skip overflow tables of index organized tables
					AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
					AND A.TEMPORARY = 'N'	-- skip temporary tables
					AND A.SECONDARY = 'N'
					AND A.NESTED = 'NO'
					AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
					AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO'
					group by A.TABLE_NAME, A.OWNER, A.TABLESPACE_NAME, 
						A.IOT_TYPE, A.AVG_ROW_LEN, A.NUM_ROWS,	A.READ_ONLY, G.GRANTOR
				) A, MVBASE_UNIQUE_KEYS B
				WHERE A.TABLE_NAME = B.TABLE_NAME (+) AND A.TABLE_OWNER = B.TABLE_OWNER (+)
			) T, SYS.ALL_EXTERNAL_TABLES E, 
			TABLE (data_browser_pipes.FN_Pipe_References_Count) R 
			WHERE T.TABLE_NAME = E.TABLE_NAME (+) AND T.TABLE_OWNER = E.OWNER (+)
			AND T.CONSTRAINT_NAME = R.R_CONSTRAINT_NAME (+) AND T.TABLE_OWNER = R.R_OWNER (+)
			AND NOT EXISTS (    -- this table is not part of materialized view log 
				SELECT --+ NO_UNNEST
					1
				FROM SYS.ALL_MVIEW_LOGS MV
				WHERE MV.LOG_TABLE = T.TABLE_NAME
				AND MV.LOG_OWNER = T.TABLE_OWNER
			);
			
        CURSOR user_keys_cur
        IS
        	SELECT T.TABLE_NAME, T.TABLE_OWNER, T.TABLESPACE_NAME, T.CONSTRAINT_NAME, T.CONSTRAINT_TYPE,
        		T.HAS_NULLABLE, T.UNIQUE_KEY_COLS, T.KEY_COLS_COUNT, T.DEFERRABLE, T.DEFERRED, T.STATUS, T.VALIDATED,
        		T.IOT_TYPE, T.AVG_ROW_LEN, T.NUM_ROWS, T.BASE_NAME, T.RUN_NO, T.KEY_HAS_NEXTVAL, T.KEY_HAS_SYS_GUID,
        		T.SEQUENCE_OWNER, T.SEQUENCE_NAME, T.HAS_SCALAR_KEY, T.HAS_SERIAL_KEY, 
				case when E.TABLE_NAME IS NOT NULL 
					then 'YES' 
					else T.READ_ONLY 
				end READ_ONLY,
				NVL(R.CNT, 0) REFERENCES_COUNT        	
        	FROM (
				SELECT DISTINCT
					A.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') TABLE_OWNER,
					A.TABLESPACE_NAME, B.CONSTRAINT_NAME, B.CONSTRAINT_TYPE, B.HAS_NULLABLE,
					B.VIEW_KEY_COLS UNIQUE_KEY_COLS, 
					B.VIEW_KEY_COLS_COUNT KEY_COLS_COUNT, 
					B.DEFERRABLE, B.DEFERRED,
					DECODE(B.STATUS, 'ENABLED', 'ENABLE', 'DISABLED', 'DISABLE') STATUS,
					DECODE(B.VALIDATED, 'VALIDATED', 'VALIDATE', 'NOT VALIDATED', 'NOVALIDATE') VALIDATED,
					A.IOT_TYPE, A.AVG_ROW_LEN, 
					A.NUM_ROWS,				
					changelog_conf.Get_BaseName(A.TABLE_NAME) BASE_NAME,
					NULLIF(DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(A.TABLE_NAME, 1, 23), '_') ORDER BY NLSSORT(A.TABLE_NAME, 'NLS_SORT = WEST_EUROPEAN')), 1) RUN_NO,
					COALESCE(B.KEY_HAS_NEXTVAL, B.TRIGGER_HAS_NEXTVAL, 'NO') KEY_HAS_NEXTVAL,
					COALESCE(B.KEY_HAS_SYS_GUID, B.TRIGGER_HAS_SYS_GUID, 'NO') KEY_HAS_SYS_GUID,
					CAST(B.SEQUENCE_OWNER AS VARCHAR2(128)) SEQUENCE_OWNER,
					CAST(B.SEQUENCE_NAME AS VARCHAR2(128)) SEQUENCE_NAME,
					B.HAS_SCALAR_VIEW_KEY HAS_SCALAR_KEY, 
					B.HAS_SERIAL_VIEW_KEY HAS_SERIAL_KEY,
					case when EXISTS (    -- this table is part of materialized view
							SELECT -- NO_UNNEST
								1
							FROM SYS.USER_OBJECTS MV
							WHERE MV.OBJECT_NAME = A.TABLE_NAME
							AND MV.OBJECT_TYPE = 'MATERIALIZED VIEW'
						) then 'YES'
						else A.READ_ONLY
					end READ_ONLY
				FROM SYS.USER_TABLES A
				LEFT OUTER JOIN  MVBASE_UNIQUE_KEYS B  ON A.TABLE_NAME = B.TABLE_NAME
				WHERE A.IOT_NAME IS NULL	-- skip overflow tables of index organized tables
				AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
				AND A.TEMPORARY = 'N'	-- skip temporary tables
				AND A.SECONDARY = 'N'
				AND A.NESTED = 'NO'
				AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
				AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO'
			) T, SYS.USER_EXTERNAL_TABLES E, 
			TABLE (data_browser_pipes.FN_Pipe_References_Count) R 
			WHERE T.TABLE_NAME = E.TABLE_NAME (+) 
			AND T.CONSTRAINT_NAME = R.R_CONSTRAINT_NAME (+) AND T.TABLE_OWNER = R.R_OWNER (+)
			AND NOT EXISTS (    -- this table is not part of materialized view log 
				SELECT --+ NO_UNNEST
					1
				FROM SYS.USER_MVIEW_LOGS MV
				WHERE MV.LOG_TABLE = T.TABLE_NAME
			);
        v_in_rows tab_table_unique_keys;
	BEGIN
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN keys_cur;
			LOOP
				FETCH keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE keys_cur;
        else 
			OPEN user_keys_cur;
			LOOP
				FETCH user_keys_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_keys_cur;  
        end if;
	END FN_Pipe_Table_Uniquekeys;


	FUNCTION FN_Pipe_Mapping_Views
	RETURN data_browser_pipes.tab_base_mapping_views PIPELINED
	IS
		PRAGMA UDF;
        CURSOR views_cur
        IS
			SELECT /*+ RESULT_CACHE */
				VIEW_NAME, VIEW_OWNER, TABLE_NAME, TABLE_OWNER,
				NULLIF(RUN_NO, 1) RUN_NO,
				RTRIM(SUBSTR(VIEW_NAME, 1, 23), '_') || NULLIF(RUN_NO, 1) SHORT_NAME, READ_ONLY
			FROM (
				SELECT VIEW_NAME, VIEW_OWNER, TABLE_NAME, TABLE_OWNER, READ_ONLY,
					DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(VIEW_NAME, 1, 23), '_') ORDER BY NLSSORT(VIEW_NAME, 'NLS_SORT = WEST_EUROPEAN')) RUN_NO
				FROM (
					SELECT D.NAME VIEW_NAME, D.OWNER VIEW_OWNER,
						A.TABLE_NAME, A.OWNER TABLE_OWNER,
						A.READ_ONLY,
						COUNT(DISTINCT A.OWNER||'.'||A.TABLE_NAME) OVER (PARTITION BY D.NAME, D.OWNER) TAB_CNT
					FROM SYS.ALL_TABLES A, SYS.ALL_DEPENDENCIES D, SYS.ALL_CONSTRAINTS C
					WHERE A.TABLE_NAME = D.REFERENCED_NAME -- table is used in view
					AND A.OWNER = D.REFERENCED_OWNER
					AND D.TYPE = 'VIEW'
					AND D.REFERENCED_TYPE = 'TABLE'
					AND C.TABLE_NAME = D.NAME
					AND C.OWNER = A.OWNER
					AND D.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
					AND (D.NAME = A.TABLE_NAME
					 OR (A.TABLE_NAME LIKE '%' || data_browser_pattern.Get_Base_Table_Ext
					AND D.NAME LIKE REGEXP_REPLACE(A.TABLE_NAME, '\d*' || data_browser_pattern.Get_Base_Table_Ext || '$') || '%'
					AND D.NAME LIKE data_browser_pattern.Get_Base_View_Prefix || '%' || data_browser_pattern.Get_Base_View_Ext))
					AND C.CONSTRAINT_TYPE = 'V' -- view has WITH CHECK OPTION constraint
					AND A.IOT_NAME IS NULL		-- skip overflow tables of index organized tables
					AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
					AND A.TEMPORARY = 'N'		-- skip temporary tables
					AND A.SECONDARY = 'N'
					AND A.NESTED = 'NO'
					AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
					AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO'
					UNION ALL 
					SELECT D.NAME VIEW_NAME, D.OWNER VIEW_OWNER,
						A.TABLE_NAME, A.OWNER TABLE_OWNER, A.READ_ONLY,
						COUNT(DISTINCT A.TABLE_NAME) OVER (PARTITION BY D.NAME, D.OWNER) TAB_CNT
					FROM SYS.ALL_TABLES A, SYS.ALL_DEPENDENCIES D
					WHERE A.TABLE_NAME = D.REFERENCED_NAME -- table is used in view
					AND A.OWNER = D.REFERENCED_OWNER
					AND A.IOT_NAME IS NULL		-- skip overflow tables of index organized tables
					AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
					AND A.TEMPORARY = 'N'		-- skip temporary tables
					AND A.SECONDARY = 'N'
					AND A.NESTED = 'NO'
					AND D.TYPE = 'VIEW'
					AND D.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
					AND D.REFERENCED_TYPE = 'TABLE'
					AND D.NAME = A.TABLE_NAME -- view_name = table_name
					AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
					AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO'
				) T
				WHERE TAB_CNT = 1 -- view has only one table
			);
        CURSOR user_views_cur
        IS
			SELECT /*+ RESULT_CACHE */
				VIEW_NAME, VIEW_OWNER, TABLE_NAME, TABLE_OWNER,
				NULLIF(RUN_NO, 1) RUN_NO,
				RTRIM(SUBSTR(VIEW_NAME, 1, 23), '_') || NULLIF(RUN_NO, 1) SHORT_NAME, READ_ONLY
			FROM (
				SELECT VIEW_NAME, VIEW_OWNER, TABLE_NAME, TABLE_OWNER, READ_ONLY,
					DENSE_RANK() OVER (PARTITION BY RTRIM(SUBSTR(VIEW_NAME, 1, 23), '_') ORDER BY NLSSORT(VIEW_NAME, 'NLS_SORT = WEST_EUROPEAN')) RUN_NO
				FROM (
					SELECT D.NAME VIEW_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') VIEW_OWNER,
						A.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') TABLE_OWNER,
						A.READ_ONLY,
						COUNT(DISTINCT A.TABLE_NAME) OVER (PARTITION BY D.NAME) TAB_CNT
					FROM SYS.USER_TABLES A, SYS.USER_DEPENDENCIES D, SYS.USER_CONSTRAINTS C
					WHERE A.TABLE_NAME = D.REFERENCED_NAME -- table is used in view
					AND D.TYPE = 'VIEW'
					AND D.REFERENCED_TYPE = 'TABLE'
					AND C.TABLE_NAME = D.NAME
					AND A.TABLE_NAME LIKE '%' || data_browser_pattern.Get_Base_Table_Ext
					AND D.NAME LIKE REGEXP_REPLACE(A.TABLE_NAME, '\d*' || data_browser_pattern.Get_Base_Table_Ext || '$') || '%'
					AND D.NAME LIKE data_browser_pattern.Get_Base_View_Prefix || '%' || data_browser_pattern.Get_Base_View_Ext
					AND C.CONSTRAINT_TYPE = 'V' -- view has WITH CHECK OPTION constraint
					AND A.IOT_NAME IS NULL		-- skip overflow tables of index organized tables
					AND A.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip fulltext index
					AND A.TEMPORARY = 'N'		-- skip temporary tables
					AND A.SECONDARY = 'N'
					AND A.NESTED = 'NO'
					AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
					AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO'
				) T
				WHERE TAB_CNT = 1 -- view has only one table
			);
        v_in_rows tab_base_mapping_views;
	BEGIN
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN views_cur;
			LOOP
				FETCH views_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE views_cur;
        else 
			OPEN user_views_cur;
			LOOP
				FETCH user_views_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_views_cur;  
        end if;
	END FN_Pipe_Mapping_Views;

	FUNCTION FN_Pipe_Table_Cols_Prefix
	RETURN data_browser_pipes.tab_table_cols_prefix PIPELINED
	IS
		PRAGMA UDF;
        CURSOR tables_cur
        IS
			SELECT A.TABLE_NAME, A.OWNER, A.COLUMN_PREFIX
			FROM (
				SELECT
					DISTINCT C.TABLE_NAME, C.OWNER, SUBSTR(C.COLUMN_NAME, 1, INSTR(C.COLUMN_NAME, '_')) COLUMN_PREFIX
				FROM  SYS.ALL_TAB_COLUMNS C
				WHERE C.COLUMN_ID = 1
				AND INSTR(C.COLUMN_NAME, '_') > 0
				AND data_browser_pattern.Match_Included_Tables(C.TABLE_NAME) = 'YES'
				AND data_browser_pattern.Match_Excluded_Tables(C.TABLE_NAME) = 'NO'
			) A
			WHERE NOT EXISTS (
				SELECT 1
				FROM SYS.ALL_TAB_COLUMNS B
				WHERE B.TABLE_NAME = A.TABLE_NAME
				AND B.OWNER = A.OWNER
				AND B.COLUMN_NAME NOT LIKE A.COLUMN_PREFIX || '%'
			);
        CURSOR user_tables_cur
        IS
			SELECT A.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, A.COLUMN_PREFIX
			FROM (
				SELECT
					DISTINCT C.TABLE_NAME, SUBSTR(C.COLUMN_NAME, 1, INSTR(C.COLUMN_NAME, '_')) COLUMN_PREFIX
				FROM  SYS.USER_TAB_COLUMNS C
				WHERE C.COLUMN_ID = 1
				AND INSTR(C.COLUMN_NAME, '_') > 0
				AND data_browser_pattern.Match_Included_Tables(C.TABLE_NAME) = 'YES'
				AND data_browser_pattern.Match_Excluded_Tables(C.TABLE_NAME) = 'NO'
			) A
			WHERE NOT EXISTS (
				SELECT 1
				FROM SYS.USER_TAB_COLUMNS B
				WHERE B.TABLE_NAME = A.TABLE_NAME
				AND B.COLUMN_NAME NOT LIKE A.COLUMN_PREFIX || '%'
			);
        v_in_rows tab_table_cols_prefix;
	BEGIN
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN tables_cur;
			FETCH tables_cur BULK COLLECT INTO v_in_rows;
			CLOSE tables_cur;
        else 
			OPEN user_tables_cur;
			FETCH user_tables_cur BULK COLLECT INTO v_in_rows;
			CLOSE user_tables_cur;  
        end if;
		FOR ind IN 1 .. v_in_rows.COUNT LOOP
			pipe row (v_in_rows(ind));
		END LOOP;
	END FN_Pipe_Table_Cols_Prefix;

	FUNCTION FN_Pipe_Table_Columns
	RETURN data_browser_pipes.tab_table_columns PIPELINED
	IS
	$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
		PRAGMA UDF;
	$END
        CURSOR all_cols_cur
        IS
		SELECT /*+ RESULT_CACHE */
			TABLE_NAME, OWNER TABLE_OWNER, 
			COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_TYPE_OWNER, NULLABLE, NUM_DISTINCT, DEFAULT_LENGTH, 
			DATA_DEFAULT, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, HIDDEN_COLUMN, VIRTUAL_COLUMN
		FROM SYS.ALL_TAB_COLS A
		WHERE OWNER NOT IN ('SYS', 'SYSTEM', 'SYSAUX', 'CTXSYS', 'MDSYS', 'OUTLN')
		AND data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
		AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO';

        CURSOR user_cols_cur
        IS
		SELECT /*+ RESULT_CACHE */ 
			TABLE_NAME, 
			SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') TABLE_OWNER, 
			COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_TYPE_OWNER, NULLABLE, NUM_DISTINCT, DEFAULT_LENGTH, 
			DATA_DEFAULT, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, HIDDEN_COLUMN, VIRTUAL_COLUMN
		FROM SYS.USER_TAB_COLS A
		WHERE data_browser_pattern.Match_Included_Tables(A.TABLE_NAME) = 'YES'
		AND data_browser_pattern.Match_Excluded_Tables(A.TABLE_NAME) = 'NO';

        TYPE stat_tbl IS TABLE OF user_cols_cur%ROWTYPE;
        v_in_rows stat_tbl;
        v_row rec_table_columns;
	BEGIN
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN all_cols_cur;
			LOOP
				FETCH all_cols_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					v_row.TABLE_NAME 			:= v_in_rows(ind).TABLE_NAME;
					v_row.TABLE_OWNER			:= v_in_rows(ind).TABLE_OWNER;
					v_row.COLUMN_ID 			:= v_in_rows(ind).COLUMN_ID;
					v_row.COLUMN_NAME 			:= v_in_rows(ind).COLUMN_NAME;
					v_row.DATA_TYPE 			:= v_in_rows(ind).DATA_TYPE;
					v_row.DATA_TYPE_OWNER 		:= v_in_rows(ind).DATA_TYPE_OWNER;
					v_row.NULLABLE 				:= v_in_rows(ind).NULLABLE;
					v_row.NUM_DISTINCT 			:= v_in_rows(ind).NUM_DISTINCT;
					v_row.DEFAULT_LENGTH 		:= v_in_rows(ind).DEFAULT_LENGTH;
					v_row.DATA_DEFAULT 			:= SUBSTR(TO_CLOB(v_in_rows(ind).DATA_DEFAULT), 1, 800); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
					v_row.DATA_PRECISION 		:= v_in_rows(ind).DATA_PRECISION;
					v_row.DATA_SCALE 			:= v_in_rows(ind).DATA_SCALE;
					v_row.CHAR_LENGTH 			:= v_in_rows(ind).CHAR_LENGTH;
					v_row.HIDDEN_COLUMN			:= v_in_rows(ind).HIDDEN_COLUMN;
					v_row.VIRTUAL_COLUMN		:= v_in_rows(ind).VIRTUAL_COLUMN;
					pipe row (v_row);
				END LOOP;
			END LOOP;
			CLOSE all_cols_cur;  
		else
			OPEN user_cols_cur;
			LOOP
				FETCH user_cols_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					v_row.TABLE_NAME 			:= v_in_rows(ind).TABLE_NAME;
					v_row.TABLE_OWNER			:= v_in_rows(ind).TABLE_OWNER;
					v_row.COLUMN_ID 			:= v_in_rows(ind).COLUMN_ID;
					v_row.COLUMN_NAME 			:= v_in_rows(ind).COLUMN_NAME;
					v_row.DATA_TYPE 			:= v_in_rows(ind).DATA_TYPE;
					v_row.DATA_TYPE_OWNER 		:= v_in_rows(ind).DATA_TYPE_OWNER;
					v_row.NULLABLE 				:= v_in_rows(ind).NULLABLE;
					v_row.NUM_DISTINCT 			:= v_in_rows(ind).NUM_DISTINCT;
					v_row.DEFAULT_LENGTH 		:= v_in_rows(ind).DEFAULT_LENGTH;
					v_row.DATA_DEFAULT 			:= SUBSTR(TO_CLOB(v_in_rows(ind).DATA_DEFAULT), 1, 800); -- special conversion of LONG type; give a margin of 200 bytes for char expansion
					v_row.DATA_PRECISION 		:= v_in_rows(ind).DATA_PRECISION;
					v_row.DATA_SCALE 			:= v_in_rows(ind).DATA_SCALE;
					v_row.CHAR_LENGTH 			:= v_in_rows(ind).CHAR_LENGTH;			
					v_row.HIDDEN_COLUMN			:= v_in_rows(ind).HIDDEN_COLUMN;
					v_row.VIRTUAL_COLUMN		:= v_in_rows(ind).VIRTUAL_COLUMN;
					pipe row (v_row);
				END LOOP;
			END LOOP;
			CLOSE user_cols_cur;  
		end if;
	END FN_Pipe_Table_Columns;

	FUNCTION FN_Pipe_Unique_Ref_Columns
	RETURN data_browser_pipes.tab_unique_ref_columns PIPELINED
	IS
		PRAGMA UDF;
		CURSOR all_cols_cur
		IS 	
		WITH UNIQUE_KEYS AS (
			SELECT 
				TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, COLUMN_NAME, 
				POSITION, DEFAULT_TEXT, VIEW_COLUMN_NAME, DATA_TYPE, NULLABLE, 
				DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, INDEX_OWNER, INDEX_NAME, 
				DEFERRABLE, DEFERRED, STATUS, VALIDATED	
			FROM table (changelog_conf.FN_Pipe_unique_keys) where VIEW_COLUMN_NAME IS NOT NULL
		), COLUMN_PATTERN AS (
			select /*+ CARDINALITY(5) */
				COLUMN_VALUE 
			from TABLE( data_browser_conf.in_list(data_browser_pattern.Get_Display_Columns_Pattern, ','))
		)
		SELECT  /*+ RESULT_CACHE */
			A.* 
		FROM (
			SELECT
				NVL(B.VIEW_NAME, A.TABLE_NAME) VIEW_NAME, 
				A.TABLE_NAME, A.TABLE_OWNER,
				CAST(COLUMN_NAME AS VARCHAR2(128)) COLUMN_NAME,
				POSITION, NULLABLE, DATA_TYPE, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, U_CONSTRAINT_NAME, U_MEMBERS, MATCHING, HAS_NULLABLE,
				CONSTRAINT_TYPE, INDEX_OWNER, INDEX_NAME,
				DENSE_RANK() OVER (PARTITION BY A.TABLE_NAME, A.TABLE_OWNER 
					ORDER BY MATCHING DESC, -- key has name matiching columns
						HAS_SCALAR_KEY ASC, -- key is not a number
						CONSTRAINT_TYPE DESC, -- key is not the primary key
						HAS_NULLABLE ASC,	-- key has fewer nullable columns
						U_MEMBERS DESC, 	-- key has more members
						U_CONSTRAINT_NAME ASC) RANK
			FROM (
				SELECT DISTINCT TABLE_NAME, TABLE_OWNER, COLUMN_NAME, POSITION, NULLABLE, DATA_TYPE, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, 
					U_CONSTRAINT_NAME, U_MEMBERS, MATCHING, HAS_NULLABLE, HAS_SCALAR_KEY, CONSTRAINT_TYPE, INDEX_OWNER, INDEX_NAME
				FROM (
					SELECT S.TABLE_NAME, S.TABLE_OWNER, 
						S.HAS_SCALAR_KEY, 
						B.CONSTRAINT_NAME U_CONSTRAINT_NAME, B.COLUMN_NAME, B.POSITION, B.NULLABLE, 
						B.DATA_TYPE, B.DATA_PRECISION, B.DATA_SCALE, B.CHAR_LENGTH,
						N.COLUMN_VALUE COLUMN_PATTERN, B.CONSTRAINT_TYPE, B.INDEX_OWNER, B.INDEX_NAME, 
						COUNT(DISTINCT B.COLUMN_NAME) OVER (PARTITION BY B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME) U_MEMBERS,
						COUNT(DISTINCT N.COLUMN_VALUE) OVER (PARTITION BY B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME) MATCHING,
						SUM(case when B.NULLABLE = 'Y' then 1 else 0 end) OVER (PARTITION BY B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME) HAS_NULLABLE
					FROM UNIQUE_KEYS B, MVBASE_UNIQUE_KEYS S
						, COLUMN_PATTERN N -- used for ranking multiple choices per table
					WHERE S.TABLE_NAME = B.TABLE_NAME AND S.TABLE_OWNER = B.TABLE_OWNER AND S.CONSTRAINT_NAME = B.CONSTRAINT_NAME
					AND B.COLUMN_NAME LIKE N.COLUMN_VALUE (+) ESCAPE '\'
				) B  -- used columns of the primary key only for composed keys
				-- WHERE (U_MEMBERS > 1 OR CONSTRAINT_TYPE = 'U' AND HAS_SERIAL_KEY = 'NO')
				UNION ALL
				SELECT DISTINCT TABLE_NAME, TABLE_OWNER, COLUMN_NAME, POSITION, NULLABLE, DATA_TYPE, DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, 
					U_CONSTRAINT_NAME, U_MEMBERS, MATCHING, HAS_NULLABLE, 'NO' HAS_SCALAR_KEY, 'I' CONSTRAINT_TYPE, INDEX_OWNER, INDEX_NAME
				FROM (
					SELECT B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME U_CONSTRAINT_NAME, B.COLUMN_NAME, B.POSITION, B.NULLABLE, B.DATA_TYPE, 
						B.DATA_PRECISION, B.DATA_SCALE, B.CHAR_LENGTH,
						N.COLUMN_VALUE COLUMN_PATTERN, B.CONSTRAINT_TYPE, B.INDEX_OWNER, B.INDEX_NAME, 
						COUNT(DISTINCT B.COLUMN_NAME) OVER (PARTITION BY B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME) U_MEMBERS,
						COUNT(DISTINCT N.COLUMN_VALUE) OVER (PARTITION BY B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME) MATCHING,
						SUM(case when B.NULLABLE = 'Y' then 1 else 0 end) OVER (PARTITION BY B.TABLE_NAME, B.TABLE_OWNER, B.CONSTRAINT_NAME) HAS_NULLABLE
					FROM table (changelog_conf.FN_Pipe_unique_indexes) B
						, COLUMN_PATTERN N -- used for ranking multiple choices per table
					WHERE B.COLUMN_NAME LIKE N.COLUMN_VALUE (+) ESCAPE '\'
					AND NOT EXISTS (
						SELECT 1
						FROM UNIQUE_KEYS C
						WHERE C.TABLE_NAME = B.TABLE_NAME
						AND C.TABLE_OWNER = B.TABLE_OWNER
						AND C.INDEX_NAME = B.INDEX_NAME
						AND C.INDEX_OWNER = B.TABLE_OWNER
					)
				) B
			) A, table (data_browser_pipes.FN_Pipe_Mapping_Views) B
			WHERE A.TABLE_NAME = B.TABLE_NAME (+)
			AND A.TABLE_OWNER = B.TABLE_OWNER (+)
		) A 
		WHERE CONSTRAINT_TYPE = 'U' OR RANK = 1;

		v_in_rows tab_unique_ref_columns;
	BEGIN
			OPEN all_cols_cur;
			LOOP
				FETCH all_cols_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_cols_cur;  
	END FN_Pipe_Unique_Ref_Columns;


	FUNCTION FN_Pipe_Foreign_Key_Columns
	RETURN data_browser_pipes.tab_foreign_key_columns PIPELINED
	IS
		PRAGMA UDF;
		CURSOR all_objects_cur
		IS 	
		SELECT /*+ RESULT_CACHE */
			F.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, F.CONSTRAINT_NAME, FC.COLUMN_NAME, FC.POSITION, 
			SC.COLUMN_ID, SC.NULLABLE, F.DELETE_RULE, F.R_CONSTRAINT_NAME, F.R_OWNER
		FROM SYS.USER_CONSTRAINTS F 
		JOIN SYS.USER_CONS_COLUMNS FC ON F.OWNER = FC.OWNER AND F.CONSTRAINT_NAME = FC.CONSTRAINT_NAME AND F.TABLE_NAME = FC.TABLE_NAME
		JOIN SYS.USER_TAB_COLS SC ON SC.TABLE_NAME = F.TABLE_NAME AND SC.COLUMN_NAME = FC.COLUMN_NAME AND SC.HIDDEN_COLUMN = 'NO' 
		AND F.CONSTRAINT_TYPE = 'R'
		UNION  
		SELECT 
			F.TABLE_NAME, F.OWNER, F.CONSTRAINT_NAME, FC.COLUMN_NAME, FC.POSITION, 
			SC.COLUMN_ID, SC.NULLABLE, F.DELETE_RULE, F.R_CONSTRAINT_NAME, F.R_OWNER
		FROM SYS.ALL_CONSTRAINTS F 
		JOIN SYS.ALL_CONSTRAINTS C ON F.R_CONSTRAINT_NAME = C.CONSTRAINT_NAME AND F.R_OWNER = C.OWNER
		JOIN SYS.ALL_CONS_COLUMNS FC ON F.OWNER = FC.OWNER AND F.CONSTRAINT_NAME = FC.CONSTRAINT_NAME AND F.TABLE_NAME = FC.TABLE_NAME
		JOIN SYS.ALL_TAB_COLS SC ON SC.TABLE_NAME = F.TABLE_NAME AND SC.COLUMN_NAME = FC.COLUMN_NAME AND SC.OWNER = F.OWNER AND SC.HIDDEN_COLUMN = 'NO' 
        join SYS.ALL_TAB_PRIVS G on F.TABLE_NAME = G.TABLE_NAME AND F.OWNER = G.GRANTOR 
		where F.CONSTRAINT_TYPE = 'R'
		and C.CONSTRAINT_TYPE IN ('P', 'U')
		and G.TYPE = 'TABLE'
		and G.GRANTEE IN ('PUBLIC', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));

		CURSOR user_objects_cur
		IS 	
		SELECT /*+ RESULT_CACHE */
			F.TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, F.CONSTRAINT_NAME, FC.COLUMN_NAME, FC.POSITION, 
			SC.COLUMN_ID, SC.NULLABLE, F.DELETE_RULE, F.R_CONSTRAINT_NAME, F.R_OWNER
		FROM SYS.USER_CONSTRAINTS F 
		JOIN SYS.USER_CONS_COLUMNS FC ON F.OWNER = FC.OWNER AND F.CONSTRAINT_NAME = FC.CONSTRAINT_NAME AND F.TABLE_NAME = FC.TABLE_NAME
		JOIN SYS.USER_TAB_COLS SC ON SC.TABLE_NAME = F.TABLE_NAME AND SC.COLUMN_NAME = FC.COLUMN_NAME AND SC.HIDDEN_COLUMN = 'NO' 
		AND F.CONSTRAINT_TYPE = 'R';

		v_in_rows tab_foreign_key_columns;
	BEGIN
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN all_objects_cur;
			LOOP
				FETCH all_objects_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_objects_cur;  
		else
			OPEN user_objects_cur;
			LOOP
				FETCH user_objects_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_objects_cur;  
		end if;
	END FN_Pipe_Foreign_Key_Columns;


	FUNCTION FN_Pipe_Sys_Objects(p_Include_External_Objects VARCHAR2 DEFAULT 'NO')
	RETURN data_browser_pipes.tab_sys_objects PIPELINED
	IS
		PRAGMA UDF;
		CURSOR all_objects_cur
		IS 	
		select /*+ RESULT_CACHE */
			OBJECT_ID, OBJECT_TYPE, OBJECT_NAME, OWNER, STATUS
		from SYS.ALL_OBJECTS TA -- exclude god objects
		where (NOT(TA.OWNER = 'SYS' AND TA.OBJECT_NAME IN ('DBMS_STANDARD', 'STANDARD'))
		and NOT(TA.OWNER = 'PUBLIC' AND TA.OBJECT_NAME = 'DUAL'));

		CURSOR user_objects_cur
		IS 	
		select /*+ RESULT_CACHE */
			OBJECT_ID, OBJECT_TYPE, OBJECT_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, STATUS
		from SYS.USER_OBJECTS;

		v_in_rows tab_sys_objects;
	BEGIN
		if p_Include_External_Objects = 'YES' then 
			OPEN all_objects_cur;
			LOOP
				FETCH all_objects_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_objects_cur;  
		else
			OPEN user_objects_cur;
			LOOP
				FETCH user_objects_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_objects_cur;  
		end if;
	END FN_Pipe_Sys_Objects;

	FUNCTION FN_Pipe_Table_Numrows
	RETURN data_browser_pipes.tab_table_numrows PIPELINED
	IS
		PRAGMA UDF;
		CURSOR all_objects_cur
		IS 	
		select /*+ RESULT_CACHE */
			TABLE_NAME, OWNER, NUM_ROWS
		from SYS.ALL_TABLES;

		CURSOR user_objects_cur
		IS 	
		select /*+ RESULT_CACHE */
			TABLE_NAME, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OWNER, NUM_ROWS
		from SYS.USER_TABLES;

		v_in_rows tab_table_numrows;
	BEGIN
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN all_objects_cur;
			LOOP
				FETCH all_objects_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_objects_cur;  
		else
			OPEN user_objects_cur;
			LOOP
				FETCH user_objects_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_objects_cur;  
		end if;
	END FN_Pipe_Table_Numrows;

	FUNCTION FN_Pipe_References_Count
	RETURN data_browser_pipes.tab_references_count PIPELINED
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
		if changelog_conf.Get_Include_External_Objects = 'YES' then 
			OPEN all_refs_cur;
			LOOP
				FETCH all_refs_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_refs_cur;  
		else
			OPEN user_refs_cur;
			LOOP
				FETCH user_refs_cur
				BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_refs_cur;  
		end if;
	END FN_Pipe_References_Count;

	FUNCTION FN_Pipe_Special_Columns
	RETURN data_browser_pipes.tab_special_columns PIPELINED
	IS
		PRAGMA UDF;
		CURSOR user_objects_cur
		IS 	
		SELECT /*+ RESULT_CACHE */
			TABLE_NAME, TABLE_OWNER,
			MAX(ROW_VERSION_COLUMN_NAME) ROW_VERSION_COLUMN_NAME,
			MAX(ROW_LOCKED_COLUMN_NAME) ROW_LOCKED_COLUMN_NAME,
			MAX(SOFT_LOCK_COLUMN_NAME) SOFT_LOCK_COLUMN_NAME,
			MAX(FLIP_STATE_COLUMN_NAME) FLIP_STATE_COLUMN_NAME,
			MAX(SOFT_DELETED_COLUMN_NAME) SOFT_DELETED_COLUMN_NAME,
			MAX(ORDERING_COLUMN_NAME) ORDERING_COLUMN_NAME,
			MAX(ACTIVE_LOV_COLUMN_NAME) ACTIVE_LOV_COLUMN_NAME,
			MAX(HTML_FIELD_COLUMN_NAME) HTML_FIELD_COLUMN_NAME,
			MAX(CALEND_START_DATE_COLUMN_NAME) CALEND_START_DATE_COLUMN_NAME,
			MAX(CALENDAR_END_DATE_COLUMN_NAME) CALENDAR_END_DATE_COLUMN_NAME,
			MAX(FILE_NAME_COLUMN_NAME) FILE_NAME_COLUMN_NAME,
			MAX(MIME_TYPE_COLUMN_NAME) MIME_TYPE_COLUMN_NAME,
			MAX(FILE_DATE_COLUMN_NAME) FILE_DATE_COLUMN_NAME,
			MAX(FILE_CONTENT_COLUMN_NAME) FILE_CONTENT_COLUMN_NAME,
			MAX(FILE_THUMBNAIL_COLUMN_NAME) FILE_THUMBNAIL_COLUMN_NAME,
			MAX(FILE_FOLDER_COLUMN_NAME) FILE_FOLDER_COLUMN_NAME,
			MAX(FOLDER_NAME_COLUMN_NAME) FOLDER_NAME_COLUMN_NAME,
			MAX(FOLDER_PARENT_COLUMN_NAME) FOLDER_PARENT_COLUMN_NAME,
			MAX(FILE_PRIVILEGE_COLUMN_NAME) FILE_PRIVILEGE_COLUMN_NAME,
			MAX(INDEX_FORMAT_COLUMN_NAME) INDEX_FORMAT_COLUMN_NAME,
			MAX(AUDIT_DATE_COLUMN_NAME) AUDIT_DATE_COLUMN_NAME,
			MAX(AUDIT_USER_COLUMN_NAME) AUDIT_USER_COLUMN_NAME,
			MAX(SUMMAND_COLUMN_NAME) SUMMAND_COLUMN_NAME,
			MAX(MINUEND_COLUMN_NAME) MINUEND_COLUMN_NAME,
			MAX(FACTORS_COLUMN_NAME) FACTORS_COLUMN_NAME,
			CASE WHEN MIN(COLUMN_PREFIX) = MAX(COLUMN_PREFIX) THEN MAX(COLUMN_PREFIX) END COLUMN_PREFIX
		FROM (
			SELECT TABLE_NAME, TABLE_OWNER,
				COLUMN_PREFIX,
				FIRST_VALUE(ROW_VERSION_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) ROW_VERSION_COLUMN_NAME,
				FIRST_VALUE(ROW_LOCKED_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) ROW_LOCKED_COLUMN_NAME,
				FIRST_VALUE(SOFT_LOCK_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) SOFT_LOCK_COLUMN_NAME,
				FIRST_VALUE(FLIP_STATE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FLIP_STATE_COLUMN_NAME,
				FIRST_VALUE(SOFT_DELETED_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) SOFT_DELETED_COLUMN_NAME,
				FIRST_VALUE(ORDERING_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) ORDERING_COLUMN_NAME,
				FIRST_VALUE(ACTIVE_LOV_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) ACTIVE_LOV_COLUMN_NAME,
				FIRST_VALUE(HTML_FIELD_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) HTML_FIELD_COLUMN_NAME,
				FIRST_VALUE(CALEND_START_DATE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) CALEND_START_DATE_COLUMN_NAME,
				FIRST_VALUE(CALENDAR_END_DATE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) CALENDAR_END_DATE_COLUMN_NAME,
				FIRST_VALUE(FILE_NAME_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FILE_NAME_COLUMN_NAME,
				FIRST_VALUE(MIME_TYPE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) MIME_TYPE_COLUMN_NAME,
				FIRST_VALUE(FILE_DATE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FILE_DATE_COLUMN_NAME,
				FIRST_VALUE(FILE_CONTENT_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FILE_CONTENT_COLUMN_NAME,
				FIRST_VALUE(FILE_THUMBNAIL_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FILE_THUMBNAIL_COLUMN_NAME,
				FIRST_VALUE(FILE_FOLDER_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FILE_FOLDER_COLUMN_NAME,
				FIRST_VALUE(FOLDER_NAME_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FOLDER_NAME_COLUMN_NAME,
				FIRST_VALUE(FOLDER_PARENT_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FOLDER_PARENT_COLUMN_NAME,
				FIRST_VALUE(FILE_PRIVILEGE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FILE_PRIVILEGE_COLUMN_NAME,
				FIRST_VALUE(INDEX_FORMAT_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) INDEX_FORMAT_COLUMN_NAME,
				FIRST_VALUE(AUDIT_DATE_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) AUDIT_DATE_COLUMN_NAME,
				FIRST_VALUE(AUDIT_USER_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) AUDIT_USER_COLUMN_NAME,
				FIRST_VALUE(SUMMAND_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) SUMMAND_COLUMN_NAME,
				FIRST_VALUE(MINUEND_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) MINUEND_COLUMN_NAME,
				FIRST_VALUE(FACTORS_COLUMN_NAME IGNORE NULLS) OVER (PARTITION BY TABLE_NAME, TABLE_OWNER ORDER BY COLUMN_ID) FACTORS_COLUMN_NAME
			FROM (
				SELECT C.TABLE_NAME, C.TABLE_OWNER, C.COLUMN_ID,
					SUBSTR(C.COLUMN_NAME, 1, INSTR(C.COLUMN_NAME, '_')) COLUMN_PREFIX,
					case when C.DATA_TYPE = 'NUMBER' 
							and data_browser_pattern.Match_Row_Version_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end ROW_VERSION_COLUMN_NAME,
					case when data_browser_pattern.Match_Row_Lock_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end ROW_LOCKED_COLUMN_NAME,
					case when data_browser_pattern.Match_Lock_Field_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end SOFT_LOCK_COLUMN_NAME,
					case when data_browser_pattern.Match_Flip_State_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FLIP_STATE_COLUMN_NAME,
					case when data_browser_pattern.Match_Soft_Delete_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end SOFT_DELETED_COLUMN_NAME,
					case when C.DATA_TYPE = 'NUMBER' 
							and data_browser_pattern.Match_Ordering_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end ORDERING_COLUMN_NAME,
					case when data_browser_pattern.Match_Active_Lov_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end ACTIVE_LOV_COLUMN_NAME,
					case when data_browser_pattern.Match_Html_Fields_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end HTML_FIELD_COLUMN_NAME,
					case when data_browser_pattern.Match_Calendar_Start_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end CALEND_START_DATE_COLUMN_NAME,
					case when data_browser_pattern.Match_Calendar_End_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end CALENDAR_END_DATE_COLUMN_NAME,
					case when data_browser_pattern.Match_File_Name_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FILE_NAME_COLUMN_NAME,
					case when data_browser_pattern.Match_Mime_Type_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end MIME_TYPE_COLUMN_NAME,
					case when data_browser_pattern.Match_File_Created_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FILE_DATE_COLUMN_NAME,
					case when data_browser_pattern.Match_File_Content_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FILE_CONTENT_COLUMN_NAME,
					case when data_browser_pattern.Match_Thumbnail_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FILE_THUMBNAIL_COLUMN_NAME,
					case when data_browser_pattern.Match_File_Folder_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FILE_FOLDER_COLUMN_NAME,
					case when data_browser_pattern.Match_Folder_Parent_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FOLDER_PARENT_COLUMN_NAME,
					case when data_browser_pattern.Match_Folder_Name_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FOLDER_NAME_COLUMN_NAME,		
					case when data_browser_pattern.Match_File_Privilege_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FILE_PRIVILEGE_COLUMN_NAME,				
					case when data_browser_pattern.Match_Index_Format_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end INDEX_FORMAT_COLUMN_NAME,
					case when (C.DATA_TYPE = 'DATE' OR C.DATA_TYPE LIKE 'TIMESTAMP%') 
						and data_browser_pattern.Match_Audit_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end AUDIT_DATE_COLUMN_NAME,
					case when C.DATA_TYPE IN ('VARCHAR2', 'VARCHAR', 'NVARCHAR2', 'CHAR', 'NCHAR') 
						and data_browser_pattern.Match_Audit_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end AUDIT_USER_COLUMN_NAME,
					case when C.DATA_TYPE IN ('NUMBER', 'FLOAT') 
							and data_browser_pattern.Match_Summand_Field_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end SUMMAND_COLUMN_NAME,
					case when C.DATA_TYPE IN ('NUMBER', 'FLOAT') 
							and data_browser_pattern.Match_Minuend_Field_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end MINUEND_COLUMN_NAME,
					case when C.DATA_TYPE IN ('NUMBER', 'FLOAT') 
							and data_browser_pattern.Match_Factors_Field_Columns(C.COLUMN_NAME) = 'YES'
						then C.COLUMN_NAME
					end FACTORS_COLUMN_NAME
				FROM  TABLE ( data_browser_pipes.FN_Pipe_Table_Columns ) C
				WHERE HIDDEN_COLUMN = 'NO'
			)
		) GROUP BY TABLE_NAME, TABLE_OWNER;

		v_in_rows tab_special_columns;
	BEGIN
		OPEN user_objects_cur;
		LOOP
			FETCH user_objects_cur
			BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE user_objects_cur;  
	END FN_Pipe_Special_Columns;

	FUNCTION FN_Pipe_Accessible_Schemas (
		p_User_Name IN VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_application_id IN NUMBER DEFAULT NV('APP_ID')
	) RETURN tab_Accessible_Schema PIPELINED
	IS
		s_cur  SYS_REFCURSOR;
		v_row rec_Accessible_Schema; -- output row
    	v_stat VARCHAR2(32767);
	BEGIN
		for c_cur in (
			select distinct /*+ RESULT_CACHE */ 
				B.owner           
			from APEX_WORKSPACE_SCHEMAS S
			join APEX_APPLICATIONS APP on S.WORKSPACE_NAME = APP.WORKSPACE
			join sys.ALL_TABLES B on S.SCHEMA = B.owner and B.table_name = 'DATA_BROWSER_CONFIG'
			join sys.ALL_TABLES C on S.SCHEMA = C.owner and C.table_name = 'APP_USERS'
			where APP.APPLICATION_ID = p_application_id
			group by B.owner
		) loop 
			v_stat := v_stat 
			|| case when v_stat IS NOT NULL then 
				chr(10)||'union all ' 
			end         
			|| 'select /*+ RESULT_CACHE */ ' || dbms_assert.enquote_literal(c_cur.owner) 
			|| ' SCHEMA_NAME, A.APP_VERSION_NUMBER, B.USER_LEVEL' || chr(10)
			|| 'from ' || c_cur.owner || '.DATA_BROWSER_CONFIG A, ' || c_cur.owner || '.APP_USERS B, param P'|| chr(10)
			|| 'where A.ID = 1 and B.UPPER_LOGIN_NAME = P.LOGIN_NAME';
		end loop;
		if v_stat IS NOT NULL then 
			v_stat := 'with param as (select :a LOGIN_NAME from dual) select * from (' || chr(10) || v_stat || chr(10) || ')';
			open s_cur for v_stat using IN p_User_Name;
			loop
				FETCH s_cur INTO v_row;
				EXIT WHEN s_cur%NOTFOUND;
				if v_row.User_Access_Level <= 6 then
					pipe row ( v_row );
				end if;
			end loop;
		end if;
		return;
	END FN_Pipe_Accessible_Schemas;
END data_browser_pipes;
/
