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

-- stop running or scheduled jobs of this app
begin
    for c in (
        select JOB_NAME from USER_SCHEDULER_JOBS
        where JOB_NAME LIKE 'DBROW_%'
    ) loop 
        dbms_scheduler.drop_job (
            job_name => c.JOB_NAME,
            force => TRUE
        );
    end loop;
    commit;
end;
/

-- hide own materialized views
UPDATE DATA_BROWSER_CONFIG SET EXCLUDED_TABLES_PATTERN = (EXCLUDED_TABLES_PATTERN||','||'MVDATA_BROWSER%')
WHERE INSTR(EXCLUDED_TABLES_PATTERN,'MVDATA_BROWSER%') = 0;
UPDATE DATA_BROWSER_CONFIG SET EXCLUDED_TABLES_PATTERN = (EXCLUDED_TABLES_PATTERN||','||'MVBASE%')
WHERE INSTR(EXCLUDED_TABLES_PATTERN,'MVBASE%') = 0;
UPDATE DATA_BROWSER_CONFIG SET EXCLUDED_TABLES_PATTERN = (EXCLUDED_TABLES_PATTERN||','||'MVCHANGELOG%')
WHERE INSTR(EXCLUDED_TABLES_PATTERN,'MVCHANGELOG%') = 0;
COMMIT;

DECLARE -- remove packages from previous installation
    PROCEDURE RUN_STAT( p_Drop_Stat VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_Drop_Stat;
        -- DBMS_OUTPUT.PUT_LINE(p_Drop_Stat || ';');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE NOT IN( -12003, -4043, -4080, -1434, -942, -2289, -2449 ) THEN
            RAISE;
        END IF;
    END;
BEGIN
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP');
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_JOINS');
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_TRIGGER'); -- old name
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_COLUMNS'); -- old name
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_LINK'); -- old name
    RUN_STAT('DROP VIEW VBASE_VIEWS'); -- old name
    RUN_STAT('DROP MATERIALIZED VIEW MVDATA_BROWSER_FC_REFS'); -- old name
    RUN_STAT('DROP MATERIALIZED VIEW MVDATA_BROWSER_QC_REFS'); -- old name
    RUN_STAT('DROP MATERIALIZED VIEW MVDATA_BROWSER_Q_REFS'); -- old name
    -- Drop packages that define record types
    RUN_STAT('DROP PACKAGE WECO_AUTH_MGR');-- old name
    RUN_STAT('DROP PACKAGE WECO_AUTH'); -- old name
    RUN_STAT('DROP PACKAGE WECO_LOGIN'); -- old name
    RUN_STAT('DROP PACKAGE CUSTOM_CHANGELOG_GEN');
    RUN_STAT('DROP PACKAGE CUSTOM_CHANGELOG');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_CONF');
    RUN_STAT('DROP PACKAGE CHANGELOG_CONF');
    RUN_STAT('DROP FUNCTION FN_PIPE_BASE_UNIQUEKEYS');
    RUN_STAT('DROP VIEW VBASE_UNIQUE_KEYS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_VIEWS'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_JOBS_CACHED'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_TREE_CACHED'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_TREE'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_SIMPLE_CONS'); -- old name
    RUN_STAT('DROP VIEW VBASE_ALTER_UNIQUEKEYS'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_SPECIAL_COLS'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_IMPORT_COLS');-- old name
    RUN_STAT('DROP VIEW VUSER_FOREIGN_KEY_PARENTS'); -- old name
	RUN_STAT('DROP VIEW VUSER_TABLES_CHECK_IN_LIST'); -- old name
    RUN_STAT('DROP VIEW VBASE_TRIGGER');-- old name
    -- Drop old names - now in package data_brwoser_diagram_utl
    RUN_STAT('DROP PROCEDURE OBJECT_DEPENDENCIES_JS');
    RUN_STAT('DROP PROCEDURE USER_OBJECT_DEPENDENCIES_JS');
    RUN_STAT('DROP PROCEDURE SPRINGY_DIAGRAMM_JS'); -- old name
    RUN_STAT('DROP PROCEDURE DYNAMIC_ACTIONS_DIAGRAM_JS');
    RUN_STAT('DROP PROCEDURE DATABASE_ER_DIAGRAMM_JS');
    RUN_STAT('DROP VIEW APP_ALL_OBJECT_DEPENDENCIES_V'); -- old name
    RUN_STAT('DROP VIEW APP_USER_OBJECT_DEPENDENCIES_V'); -- old name

    -- Drop packages that define record types
    RUN_STAT('DROP PACKAGE DATA_BROWSER_DIAGRAM_PIPES');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_JOBS');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_PIPES');
    
    RUN_STAT('DROP PACKAGE WECO_MAIL'); -- old name
    RUN_STAT('DROP PROCEDURE INIT_APP_PREFERENCES');-- old name
    RUN_STAT('DROP TABLE APP_PREFERENCES'); -- old name
END;
/

DECLARE
    v_Count NUMBER;
BEGIN
    LOOP
        v_Count := 0;
        FOR s_cur IN (
            SELECT 'DROP TYPE ' || OBJECT_NAME  STAT
            FROM USER_OBJECTS WHERE OBJECT_TYPE = 'TYPE' AND OBJECT_NAME LIKE 'SYS_PLSQL%'
        ) LOOP
            BEGIN
                EXECUTE IMMEDIATE s_cur.STAT;
                DBMS_OUTPUT.PUT_LINE(s_cur.STAT || ';');
            EXCEPTION
              WHEN OTHERS THEN
                IF SQLCODE != -2303 
                AND SQLCODE != -60 -- deadlock detected while waiting for resource
                THEN
                    RAISE;
                END IF;
            END;
            v_Count := v_Count + 1;
        END LOOP;
        EXIT WHEN v_Count = 0;
    END LOOP;
END;
/

