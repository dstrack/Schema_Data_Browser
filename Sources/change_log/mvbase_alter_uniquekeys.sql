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

DECLARE
	PROCEDURE DROP_MVIEW( p_MView_Name VARCHAR2) IS
		time_limit_exceeded EXCEPTION;
		PRAGMA EXCEPTION_INIT (time_limit_exceeded, -4021); -- ORA-04021: timeout occurred while waiting to lock object 
		mview_does_not_exist EXCEPTION;
		PRAGMA EXCEPTION_INIT (mview_does_not_exist, -12003); -- ORA-12003: materialized view does not exist
		table_does_not_exist EXCEPTION;
		PRAGMA EXCEPTION_INIT (table_does_not_exist, -942); -- ORA-00942: table or view does not exist
		v_count NUMBER := 0;
	BEGIN		
		LOOP 
			BEGIN 
				EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW ' || p_MView_Name;
        		DBMS_OUTPUT.PUT_LINE('DROP MATERIALIZED VIEW ' || p_MView_Name || ';');
        		EXIT;
			EXCEPTION
				WHEN time_limit_exceeded THEN 
					DBMS_SESSION.SLEEP(1/2);
					v_count := v_count + 1;
					EXIT WHEN v_count > 10;
				WHEN mview_does_not_exist or table_does_not_exist THEN
					EXIT;
			END;
		END LOOP;
	END;
BEGIN
	DROP_MVIEW('MVBASE_ALTER_UNIQUEKEYS');
END;
/
execute DBMS_SESSION.SLEEP(1/2);

/* Definition of Primary and Unique Keys for all normal tables, tables without Keys are also listed  */
CREATE MATERIALIZED VIEW MVBASE_ALTER_UNIQUEKEYS
    (TABLE_NAME, TABLESPACE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE, READ_ONLY,
    UNIQUE_KEY_COLS, KEY_COLS_COUNT, PREFIX_LENGTH, VIEW_KEY_COLS, NEW_KEY_COLS,
    IOT_TYPE, AVG_ROW_LEN, SHORT_NAME, SHORT_NAME2,
    KEY_CLAUSE, CONSTRAINT_EXT, MVIEW_LOG_DEFINITION, CREATE_STAT, RENAME_STAT, VIEW_KEY_STAT, IS_CANDIDATE_KEY, IS_REFERENCED_KEY, REFERENCES_COUNT,
    KEY_HAS_WORKSPACE_ID, KEY_HAS_DELETE_MARK, KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID, SEQUENCE_OWNER, SEQUENCE_NAME,
    HAS_SCALAR_VIEW_KEY, HAS_SERIAL_VIEW_KEY, HAS_WORKSPACE_ID, HAS_DELETE_MARK, INCLUDE_TIMESTAMP, INCLUDE_DELETE_MARK, INCLUDE_WORKSPACE_ID,
    KEY_IS_ALTERED, VIEW_IS_CREATED, POSITION)
    BUILD DEFERRED
    REFRESH COMPLETE
    ON DEMAND
    USING TRUSTED CONSTRAINTS 
AS
WITH MVIEW_LOGS AS (
    SELECT U.MASTER, U.LOG_TABLE,
        CAST(LTRIM(DECODE(U.ROWIDS, 'YES', ', ROWID', NULL)
        || DECODE(U.PRIMARY_KEY, 'YES', ', PRIMARY KEY', NULL)
        || DECODE(U.OBJECT_ID, 'YES', ', OBJECT ID', NULL)
        || DECODE(U.SEQUENCE, 'YES', ', SEQUENCE', NULL), ', ')
        || DECODE(U.FILTER_COLUMNS, 'YES', ' (' || changelog_conf.F_BASE_TABLE_COLS(U.LOG_TABLE, 'INSTR(COLUMN_NAME, ''$'') = 0') || ')', NULL)
        || DECODE(U.INCLUDE_NEW_VALUES, 'YES', ' INCLUDING NEW VALUES', NULL)
         AS VARCHAR2(1024)) MVIEW_LOG_DEFINITION
    FROM SYS.USER_MVIEW_LOGS U
), TABLE_STATUS AS (
    SELECT C.TABLE_NAME, 
        MAX(CASE WHEN C.COLUMN_NAME = changelog_conf.Get_ColumnWorkspace THEN
            CASE WHEN C.DATA_TYPE = 'NUMBER'
            AND C.NULLABLE = 'N'
            AND C.DEFAULT_LENGTH > 0
            AND RTRIM(C.DEFAULT_TEXT) = changelog_conf.Get_Context_WorkspaceID_Expr
            THEN 'READY' ELSE 'YES' END
        END) HAS_WORKSPACE_ID, -- Table has Workspace ID
        MAX(CASE WHEN C.COLUMN_NAME = changelog_conf.Get_ColumnDeletedMark THEN
            CASE WHEN C.DATA_TYPE = changelog_conf.Get_DatatypeDeletedMark
            AND C.NULLABLE = 'Y'
            AND C.DEFAULT_LENGTH > 0
            AND RTRIM(C.DEFAULT_TEXT) = changelog_conf.Get_DefaultDeletedMark
            THEN 'READY' ELSE 'YES' END
        END) HAS_DELETE_MARK -- Table has Delete_Mark
    FROM TABLE ( changelog_conf.FN_Pipe_Table_Columns ) C
    WHERE C.COLUMN_NAME IN (changelog_conf.Get_ColumnWorkspace,  changelog_conf.Get_ColumnDeletedMark)
    GROUP BY C.TABLE_NAME
), TABLE_STATUS2 AS (
    SELECT TABLE_NAME,
		CASE WHEN changelog_conf.Get_Use_Audit_Info_Columns = 'YES'
				and changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_IncludeTimestampPattern) = 'YES'
				and changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_ExcludeTimestampPattern) = 'NO'
		THEN 'YES' ELSE 'NO' END INCLUDE_TIMESTAMP,
		CASE WHEN changelog_conf.Get_Use_Column_Delete_mark = 'YES'
				and changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_IncludeDeleteMarkPattern) = 'YES'
				and changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_ExcludeDeleteMarkPattern) = 'NO'
		THEN 'YES' ELSE 'NO' END INCLUDE_DELETE_MARK,
		CASE WHEN (changelog_conf.Get_Use_Column_Workspace = 'YES' 
				or changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_ConstantWorkspaceIDPattern) = 'YES')
				and changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_IncludeWorkspaceIDPattern) = 'YES'
				and changelog_conf.Match_Column_Pattern(T.BASE_NAME, changelog_conf.Get_ExcludeWorkspaceIDPattern) = 'NO'
		THEN 'YES' ELSE 'NO' END INCLUDE_WORKSPACE_ID
	FROM (
		SELECT TABLE_NAME, changelog_conf.Get_BaseName(TABLE_NAME) BASE_NAME
		FROM SYS.USER_TABLES
	) T
)
SELECT T.TABLE_NAME, T.TABLESPACE_NAME, T.CONSTRAINT_NAME, T.CONSTRAINT_TYPE, T.READ_ONLY,
    UNIQUE_KEY_COLS, KEY_COLS_COUNT, PREFIX_LENGTH, VIEW_KEY_COLS, NEW_KEY_COLS,
    IOT_TYPE, AVG_ROW_LEN, SHORT_NAME, SHORT_NAME2,
    KEY_CLAUSE, CONSTRAINT_EXT, L.MVIEW_LOG_DEFINITION,
    CASE WHEN CONSTRAINT_TYPE IS NOT NULL THEN
        'ALTER TABLE ' || T.TABLE_NAME || ' ADD CONSTRAINT ' || changelog_conf.enquote_name(CONSTRAINT_NAME) || ' ' || KEY_CLAUSE
        || ' (' || NEW_KEY_COLS || ') '
        || DEFERRABLE || ' INITIALLY ' || DEFERRED || ' USING INDEX'
        || case when HAS_WORKSPACE_ID != 'NO' AND INCLUDE_WORKSPACE_ID = 'YES' then ' COMPRESS ' || NVL(PREFIX_LENGTH, 1) end
        || ' ' || T.STATUS || ' ' || VALIDATED
    END CREATE_STAT,
    CASE WHEN CONSTRAINT_TYPE IN ('P', 'U') AND CONSTRAINT_NAME != NEW_CONSTRAINT_NAME THEN
        'ALTER TABLE ' || T.TABLE_NAME || ' RENAME CONSTRAINT ' || changelog_conf.enquote_name(CONSTRAINT_NAME)
        || ' TO ' || changelog_conf.enquote_name(NEW_CONSTRAINT_NAME)
    END RENAME_STAT,
    VIEW_KEY_STAT, IS_CANDIDATE_KEY, IS_REFERENCED_KEY, REFERENCES_COUNT,
    KEY_HAS_WORKSPACE_ID, KEY_HAS_DELETE_MARK, KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID,
	CAST(SEQUENCE_OWNER AS VARCHAR2(128)) SEQUENCE_OWNER,
	CAST(SEQUENCE_NAME AS VARCHAR2(128)) SEQUENCE_NAME,
    HAS_SCALAR_VIEW_KEY, HAS_SERIAL_VIEW_KEY, HAS_WORKSPACE_ID, HAS_DELETE_MARK, INCLUDE_TIMESTAMP, INCLUDE_DELETE_MARK, INCLUDE_WORKSPACE_ID,
    CASE WHEN HAS_DELETE_MARK != 'NO' 
    		AND (INCLUDE_DELETE_MARK = 'NO') -- Drop Deleted_Mark
        OR CONSTRAINT_TYPE IS NOT NULL
        AND ( KEY_HAS_WORKSPACE_ID = 'NO' -- Add Workspace ID
            AND HAS_WORKSPACE_ID != 'NO'
        OR KEY_HAS_WORKSPACE_ID != 'NO'
        	AND INCLUDE_WORKSPACE_ID = 'NO'  -- Drop Workspace ID
        OR KEY_HAS_DELETE_MARK = 'NO'
        	AND HAS_DELETE_MARK != 'NO'
            AND CONSTRAINT_TYPE = 'U'
            AND IS_REFERENCED_KEY = 'NO'
            AND KEY_HAS_NEXTVAL = 'NO'
            AND KEY_HAS_SYS_GUID = 'NO'
            AND INCLUDE_DELETE_MARK = 'YES' -- Add Deleted_Mark
        OR KEY_HAS_DELETE_MARK != 'NO'
        	AND CONSTRAINT_TYPE = 'U'
            AND (IS_REFERENCED_KEY = 'YES'
              OR 'YES' IN (KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID)) -- Drop Deleted_Mark
    ) THEN 'YES' ELSE 'NO' END KEY_IS_ALTERED,

    CASE WHEN (HAS_DELETE_MARK != 'NO' AND INCLUDE_DELETE_MARK = 'YES'
              OR HAS_WORKSPACE_ID != 'NO' AND INCLUDE_WORKSPACE_ID = 'YES')
        THEN 'YES' ELSE 'NO' END VIEW_IS_CREATED,
    DENSE_RANK() OVER (PARTITION BY T.TABLE_NAME
    	ORDER BY CASE WHEN 'YES' IN (KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID) THEN 0 ELSE 1 END,
    	IS_CANDIDATE_KEY DESC, CONSTRAINT_TYPE ASC, CONSTRAINT_NAME ASC) POSITION

FROM (
    SELECT TABLE_NAME, TABLESPACE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE, READ_ONLY,
        CAST(RTRIM (
            CASE WHEN HAS_WORKSPACE_ID != 'NO'
            AND INCLUDE_WORKSPACE_ID = 'YES' -- Add Workspace ID
            THEN changelog_conf.Get_ColumnWorkspace || ', '
            END
            || VIEW_KEY_COLS
            || CASE WHEN HAS_DELETE_MARK != 'NO'
                AND CONSTRAINT_TYPE = 'U'
                AND IS_REFERENCED_KEY = 'NO'
                AND KEY_HAS_NEXTVAL = 'NO'
                AND KEY_HAS_SYS_GUID = 'NO'
                AND INCLUDE_DELETE_MARK = 'YES' -- Add Deleted_Mark
                THEN ', ' || changelog_conf.Get_ColumnDeletedMark
            END, ', '
            ) AS VARCHAR2(512)
        ) NEW_KEY_COLS,
        VIEW_KEY_COLS, UNIQUE_KEY_COLS, KEY_COLS_COUNT, PREFIX_LENGTH, INDEX_OWNER, INDEX_NAME,
        IOT_TYPE, AVG_ROW_LEN, SHORT_NAME, SHORT_NAME2, T.STATUS, VALIDATED, DEFERRABLE, DEFERRED,
        KEY_CLAUSE, CONSTRAINT_EXT, NEW_CONSTRAINT_NAME,
        CASE WHEN CONSTRAINT_TYPE IS NOT NULL
        AND VIEW_KEY_COLS IS NOT NULL  -- column workspace$-id can be filtered out
        THEN
            ' CONSTRAINT ' || changelog_conf.enquote_name(VIEW_CONSTRAINT_NAME) || ' ' || KEY_CLAUSE
            || ' (' || VIEW_KEY_COLS || ') RELY DISABLE NOVALIDATE'
        END VIEW_KEY_STAT,
        IS_CANDIDATE_KEY,
        IS_REFERENCED_KEY, REFERENCES_COUNT,
        KEY_HAS_WORKSPACE_ID, KEY_HAS_DELETE_MARK, KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID, 
        HAS_SCALAR_VIEW_KEY, HAS_SERIAL_VIEW_KEY,
        HAS_WORKSPACE_ID,
        HAS_DELETE_MARK,
        INCLUDE_WORKSPACE_ID, 
        INCLUDE_DELETE_MARK, 
        INCLUDE_TIMESTAMP,
        SEQUENCE_OWNER, SEQUENCE_NAME
    FROM (
        SELECT  /*+ USE_MERGE(T D C) */ 
            T.TABLE_NAME, TABLESPACE_NAME, NVL(CONSTRAINT_NAME, '-') CONSTRAINT_NAME,
            CONSTRAINT_TYPE, READ_ONLY,
            VIEW_KEY_COLS, UNIQUE_KEY_COLS, KEY_COLS_COUNT, PREFIX_LENGTH, INDEX_OWNER, INDEX_NAME,
            SHORT_NAME || '_V' || CONSTRAINT_EXT VIEW_CONSTRAINT_NAME,
            SHORT_NAME2 || '_' || CONSTRAINT_EXT NEW_CONSTRAINT_NAME,
            DEFERRABLE, DEFERRED, STATUS, VALIDATED,
            IOT_TYPE, AVG_ROW_LEN, SHORT_NAME, SHORT_NAME2, KEY_CLAUSE,
            '_V' || CONSTRAINT_EXT CONSTRAINT_EXT,
            case when CONSTRAINT_TYPE = 'P' OR (CONSTRAINT_TYPE = 'U' AND HAS_NULLABLE = 0)
                then 'YES' else 'NO' end  IS_CANDIDATE_KEY,
            case when REFERENCES_COUNT > 0 then 'YES' else 'NO' end  IS_REFERENCED_KEY,
            REFERENCES_COUNT,
            NVL(C.HAS_WORKSPACE_ID, 'NO') HAS_WORKSPACE_ID, -- Table has Workspace ID
            NVL(C.HAS_DELETE_MARK, 'NO') HAS_DELETE_MARK, -- Table has Delete_Mark
            D.INCLUDE_TIMESTAMP, 
            case when D.INCLUDE_DELETE_MARK = 'YES' 
			and NOT EXISTS (
				SELECT 1 
				FROM MVBASE_UNIQUE_KEYS PK
				WHERE PK.CONSTRAINT_TYPE = 'P'
				AND PK.KEY_HAS_NEXTVAL = 'NO'
				AND PK.KEY_HAS_SYS_GUID = 'NO'
				AND PK.TABLE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
				AND PK.TABLE_NAME = T.TABLE_NAME
			) then 'YES' else 'NO' end  INCLUDE_DELETE_MARK,
            D.INCLUDE_WORKSPACE_ID,
            T.KEY_HAS_WORKSPACE_ID, T.KEY_HAS_DELETE_MARK, T.KEY_HAS_NEXTVAL, T.KEY_HAS_SYS_GUID, 
            T.HAS_SCALAR_VIEW_KEY, T.HAS_SERIAL_VIEW_KEY,
            T.SEQUENCE_OWNER, T.SEQUENCE_NAME
        FROM TABLE ( changelog_conf.FN_Pipe_Table_AlterUniquekeys(CURSOR (SELECT * FROM MVBASE_UNIQUE_KEYS))) T
        , TABLE_STATUS2 D 
        , TABLE_STATUS C 
        WHERE T.TABLE_NAME = D.TABLE_NAME
        AND T.TABLE_NAME = C.TABLE_NAME (+)
    ) T
	WHERE NOT EXISTS (
		SELECT 1 
		FROM SYS.USER_MVIEW_LOGS M 
		WHERE M.LOG_TABLE = T.TABLE_NAME
	)
) T, MVIEW_LOGS L 
WHERE T.TABLE_NAME = L.MASTER (+);

ALTER  TABLE MVBASE_ALTER_UNIQUEKEYS ADD
 CONSTRAINT MVBASE_ALTER_UNIQUEKEYS_UK UNIQUE (TABLE_NAME, CONSTRAINT_NAME) USING INDEX COMPRESS 1;

