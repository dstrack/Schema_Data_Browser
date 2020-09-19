set serveroutput on size unlimited

DECLARE
    PROCEDURE DROP_MVIEW( p_MView_Name VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW ' || p_MView_Name;
        DBMS_OUTPUT.PUT_LINE('DROP MATERIALIZED VIEW ' || p_MView_Name || ';');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN
            RAISE;
        END IF;
    END;
BEGIN
    DROP_MVIEW('MVDATA_BROWSER_SIMPLE_COLS');
    DROP_MVIEW('MVDATA_BROWSER_DESCRIPTIONS');
    DROP_MVIEW('MVDATA_BROWSER_FC_REFS');  -- old name
    DROP_MVIEW('MVDATA_BROWSER_Q_REFS');
    DROP_MVIEW('MVDATA_BROWSER_U_REFS');
    DROP_MVIEW('MVDATA_BROWSER_F_REFS');
    DROP_MVIEW('MVDATA_BROWSER_D_REFS');
    DROP_MVIEW('MVDATA_BROWSER_FKEYS');
    DROP_MVIEW('MVDATA_BROWSER_QC_REFS'); -- old name
    DROP_MVIEW('MVDATA_BROWSER_CHECKS_DEFS');
    DROP_MVIEW('MVDATA_BROWSER_VIEWS');
    DROP_MVIEW('MVDATA_BROWSER_REFERENCES');
    DROP_MVIEW('MVDATA_BROWSER_TREE'); -- old name
    DROP_MVIEW('MVDATA_BROWSER_UNIQUE_KEYS');-- old name

    DROP_MVIEW('MVCHANGELOG_REFERENCES');
    DROP_MVIEW('MVBASE_UNIQUE_KEYS');
    DROP_MVIEW('MVBASE_ALTER_UNIQUEKEYS');
    DROP_MVIEW('MVBASE_FOREIGNKEYS');
    DROP_MVIEW('MVBASE_VIEW_FOREIGN_KEYS');
    DROP_MVIEW('MVBASE_VIEWS');
    DROP_MVIEW('MVBASE_REFERENCES');
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
                IF SQLCODE != -2303 THEN
                    RAISE;
                END IF;
            END;
            v_Count := v_Count + 1;
        END LOOP;
        EXIT WHEN v_Count = 0;
    END LOOP;
END;
/

DECLARE
    v_Schema_Keychain_Exists pls_integer := 0;
    PROCEDURE RUN_STAT( p_Drop_Stat VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_Drop_Stat;
        DBMS_OUTPUT.PUT_LINE(p_Drop_Stat || ';');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE NOT IN( -12003, -4043, -4080, -1434, -942, -2289, -2449 ) THEN
            RAISE;
        END IF;
    END;
    PROCEDURE CHECKED_DROP( p_Object_Type VARCHAR2, p_Object_Name VARCHAR2) 
    IS
        v_Drop_Stat VARCHAR2(200) := 'DROP ' || p_Object_Type || ' ' || p_Object_Name;
        v_Count PLS_INTEGER;
        v_Name VARCHAR2(128);
        v_Type VARCHAR2(128);
    BEGIN
        SELECT COUNT(*), MAX(NAME), MAX(TYPE)
        INTO v_Count, v_Name, v_Type
        FROM USER_DEPENDENCIES
        WHERE REFERENCED_NAME = p_Object_Name
        AND REFERENCED_TYPE = p_Object_Type
        AND NAME NOT LIKE 'BIN$%'  -- this name is in the recyclebin
        AND NOT (p_Object_Type = 'PACKAGE' and TYPE = 'PACKAGE BODY' and REFERENCED_NAME = NAME)
        AND NOT (p_Object_Type = 'TYPE' and TYPE = 'TYPE BODY' and REFERENCED_NAME = NAME)
        AND NOT (p_Object_Type = 'TABLE' and TYPE = 'TRIGGER');
        if v_Count = 0 then 
            EXECUTE IMMEDIATE v_Drop_Stat;
            DBMS_OUTPUT.PUT_LINE(v_Drop_Stat || ';');
        else 
            DBMS_OUTPUT.PUT_LINE('-- skipped used object ' || p_Object_Type || ' ' || p_Object_Name
            || ' used by ' || v_Type || ' ' || v_Name );
        end if;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE NOT IN( -12003, -4043, -4080, -1434, -942, -2289, -2449 ) THEN
            RAISE;
        END IF;
    END;
BEGIN
    SELECT COUNT(*)
    INTO v_Schema_Keychain_Exists
    FROM USER_TAB_PRIVS
    WHERE TABLE_NAME = 'SCHEMA_KEYCHAIN'
    AND PRIVILEGE = 'EXECUTE';
    
    RUN_STAT('DROP TABLE USER_IMPORT_JOBS CASCADE CONSTRAINTS');
    RUN_STAT('DROP SEQUENCE USER_IMPORT_JOBS_SEQ');
    RUN_STAT('DROP PACKAGE IMPORT_UTL');

    RUN_STAT('DROP VIEW VUSER_TABLES_IMP');
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_JOINS');
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_TRIGGER');	-- old name
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_COLUMNS');	-- old name
    RUN_STAT('DROP VIEW VUSER_TABLES_IMP_LINK'); -- old name
    RUN_STAT('DROP VIEW VUSER_TABLES_CHECK_IN_LIST');
    RUN_STAT('DROP VIEW VUSER_FOREIGN_KEY_PARENTS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_IMPORT_COLS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_TABLE_RULES');
    RUN_STAT('DROP VIEW VDATA_BROWSER_JOBS_CACHED'); -- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_DISPLAY_COLS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_SIMPLE_CONS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_VIEWS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_RULES');
    RUN_STAT('DROP VIEW VDATA_BROWSER_SPECIAL_COLS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_COLUMN_RULES');
    RUN_STAT('DROP VIEW VDATA_BROWSER_FILTER_COLS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_FILTER_CONDS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_SEARCH_OPS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_TREE'); 		-- old name
    RUN_STAT('DROP VIEW VDATA_BROWSER_TREE_CACHED'); -- old name
    RUN_STAT('DROP VIEW USER_UI_DEFAULTS_LOV_DATA');
    RUN_STAT('DROP VIEW USER_UI_DEFAULTS_COLUMNS');
    RUN_STAT('DROP VIEW VDATA_BROWSER_CHECKS');
    RUN_STAT('DROP PACKAGE SPRINGY_DIAGRAM_UTL');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_EDIT');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_UTL');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_TREES');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_SELECT');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_JOINS');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_BLOBS');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_DDL');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_PIPES');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_DIAGRAM_UTL');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_DIAGRAM_PIPES');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_PATTERN');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_JOBS');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_CONF');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_CHECK');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_REPORTER');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_UI_DEFAULTS');
    RUN_STAT('DROP PACKAGE DATA_BROWSER_SPECS');
    RUN_STAT('DROP TABLE DATA_BROWSER_CHECKS');
    RUN_STAT('DROP SEQUENCE DATA_BROWSER_CHECKS_SEQ');
    RUN_STAT('DROP PROCEDURE SPRINGY_DIAGRAMM_JS'); -- old name
    -- old names
    RUN_STAT('DROP PROCEDURE OBJECT_DEPENDENCIES_JS');
    RUN_STAT('DROP PROCEDURE USER_OBJECT_DEPENDENCIES_JS');
    RUN_STAT('DROP PROCEDURE DYNAMIC_ACTIONS_DIAGRAM_JS');
    RUN_STAT('DROP PROCEDURE DATABASE_ER_DIAGRAMM_JS');

    RUN_STAT('DROP PROCEDURE DATA_BROWSER_INSTALL_SUP_OBJ');
    RUN_STAT('DROP PROCEDURE DATA_BROWSER_DEINSTALL_SUP_OBJ');
    RUN_STAT('DROP VIEW APP_ALL_OBJECT_DEPENDENCIES_V'); -- old name
    RUN_STAT('DROP VIEW APP_OBJECT_DEPENDENCIES_V');
    RUN_STAT('DROP VIEW APP_OBJECT_DIAGRAM_EDGES_V');
    RUN_STAT('DROP VIEW APP_OBJECT_DIAGRAM_NODES_V');
    RUN_STAT('DROP VIEW APP_USER_OBJECT_DEPENDENCIES_V'); -- old name
    RUN_STAT('DROP VIEW APEX_DYN_ACTIONS_DIAGRAM_V'); -- old name
    RUN_STAT('DROP TABLE DIAGRAM_EDGES');
    RUN_STAT('DROP TABLE DIAGRAM_NODES');
    RUN_STAT('DROP TABLE DIAGRAM_COLORS');
    RUN_STAT('DROP TABLE DIAGRAM_SHAPES');
    RUN_STAT('DROP TABLE SPRINGY_DIAGRAMS');
    RUN_STAT('DROP TABLE DIAGRAM_OBJECT_COORDINATES');-- old name
    RUN_STAT('DROP TABLE APP_REPORT_FILTER'); -- old name
    RUN_STAT('DROP TABLE APP_REPORT_PREFERENCES'); -- old name
    RUN_STAT('DROP TABLE DATA_BROWSER_REPORT_FILTER');
    RUN_STAT('DROP TABLE DATA_BROWSER_REPORT_PREFS');
    RUN_STAT('DROP TABLE DATA_BROWSER_DIAGRAM_COORD');
    RUN_STAT('DROP TABLE DATA_BROWSER_DIAGRAM');
    RUN_STAT('DROP SEQUENCE DIAG_EDGES_SEQ');
    RUN_STAT('DROP SEQUENCE DIAG_NODES_SEQ');
    RUN_STAT('DROP SEQUENCE DIAG_SHAPES_SEQ');
    RUN_STAT('DROP SEQUENCE DIAG_COLORS_SEQ');
    RUN_STAT('DROP SEQUENCE SPRINGY_DIAGRAMS_SEQ');

    RUN_STAT('DROP PACKAGE UPLOAD_TO_COLLECTION_PLUGIN');
    RUN_STAT('DROP PACKAGE DELETE_CHECK_PLUGIN');
    RUN_STAT('DROP TABLE PLUGIN_DELETE_CHECKS');
    RUN_STAT('DROP VIEW V_DELETE_CHECK');
    RUN_STAT('DROP PACKAGE AS_ZIP');
    RUN_STAT('DROP PACKAGE UNZIP_PARALLEL');
    -- if not referenced 
    CHECKED_DROP('FUNCTION', 'FN_NAVIGATION_LINK');
    CHECKED_DROP('FUNCTION', 'FN_NAVIGATION_MORE');
    CHECKED_DROP('FUNCTION', 'FN_NAVIGATION_COUNTER');
    CHECKED_DROP('FUNCTION', 'FN_GET_APEX_ITEM_VALUE');
    CHECKED_DROP('FUNCTION', 'FN_GET_APEX_ITEM_DATE_VALUE');
    CHECKED_DROP('FUNCTION', 'FN_GET_APEX_ITEM_ROW_COUNT');
    CHECKED_DROP('FUNCTION', 'FN_TO_DATE');
    
    CHECKED_DROP('FUNCTION', 'CLOBAGG');
    CHECKED_DROP('FUNCTION', 'FN_NUMBER_TO_CHAR');
    CHECKED_DROP('FUNCTION', 'FN_DETAIL_LINK');
    CHECKED_DROP('FUNCTION', 'FN_HEX_HASH_KEY');
    CHECKED_DROP('FUNCTION', 'FN_NESTED_LINK');
    CHECKED_DROP('FUNCTION', 'FN_PIPE_BASE_UNIQUEKEYS');
    CHECKED_DROP('FUNCTION', 'FN_TO_NUMBER');
    CHECKED_DROP('FUNCTION', 'FN_BOLD_TOTAL');
    CHECKED_DROP('TYPE', 'CLOB_AGG_TYPE');
    
    -- this tables a preserved because is may contain a installation licence key
    -- RUN_STAT('DROP TABLE DATA_BROWSER_CONFIG');
    RUN_STAT('DROP TABLE APP_USERS');
    RUN_STAT('DROP TABLE APP_USER_LEVELS');

    --- conditionally installed packages --
    if v_Schema_Keychain_Exists > 0 then
        -- weco_login --
        RUN_STAT('DROP PACKAGE WECO_LOGIN');
        RUN_STAT('DROP TRIGGER APP_USERS_PWD_TR');
        RUN_STAT('DROP PROCEDURE INIT_APP_PREFERENCES');
        -- weco_mail --
        RUN_STAT('DROP PACKAGE WECO_MAIL');
        -- weco_auth --
        RUN_STAT('DROP TRIGGER SET_CUSTOM_CTX_TRIG');
        RUN_STAT('DROP PACKAGE WECO_AUTH_MGR');
        RUN_STAT('DROP PACKAGE weco_auth');
        RUN_STAT('DROP SYNONYM SCHEMA_KEYCHAIN');
        RUN_STAT('DROP VIEW VCURRENT_WORKSPACE');
        RUN_STAT('DROP VIEW V_CONTEXT_USERS');
        RUN_STAT('DROP VIEW V_ERROR_PROTOCOL');
        RUN_STAT('DROP TABLE APP_PREFERENCES');
        RUN_STAT('DROP TABLE APP_PROTOCOL');
        RUN_STAT('DROP TABLE USER_WORKSPACE_SESSIONS');
        -- schema riser 
        RUN_STAT('DROP VIEW VBASE_VIEWS0');
        RUN_STAT('DROP PACKAGE CUSTOM_CHANGELOG_GEN');
        RUN_STAT('DROP VIEW MVCHANGELOG_REFERENCES');
        RUN_STAT('DROP VIEW VCHANGE_LOG_FIELDS');
        RUN_STAT('DROP VIEW VBASE_UNIQUE_KEYS'); -- old name
        RUN_STAT('DROP VIEW VBASE_ALTER_UNIQUEKEYS');
        RUN_STAT('DROP VIEW VBASE_VIEWS0');
        RUN_STAT('DROP VIEW VBASE_VIEWS'); -- old name

        RUN_STAT('DROP FUNCTION APPVISITOR_REST');
        RUN_STAT('DROP TYPE APPVISITOR_TABLE_T');
        RUN_STAT('DROP TYPE APPVISITOR_ROW_T');
        RUN_STAT('DROP PROCEDURE DATA_BROWSER_VISITORS_LAUNCH_JOB');
        RUN_STAT('DROP PROCEDURE DATA_BROWSER_VIS_UPD');
        RUN_STAT('DROP VIEW DATA_BROWSER_VISITORS_V');
        RUN_STAT('DROP TABLE DATA_BROWSER_VISITORS');
    end if;
    CHECKED_DROP('PACKAGE', 'AS_ZIP_SPECS');
    CHECKED_DROP('TRIGGER', 'VCHANGE_LOG_INS_TR');
    CHECKED_DROP('VIEW', 'VCHANGE_LOG');
    CHECKED_DROP('VIEW', 'VCHANGLOG_EVENTS');

    CHECKED_DROP('VIEW', 'VVIEW_TRIGGER');
    CHECKED_DROP('VIEW', 'VBASE_TRIGGER');

    CHECKED_DROP('VIEW', 'VPROTOCOL_COLUMNS_LIST');
    CHECKED_DROP('VIEW', 'VPROTOCOL_COLUMNS_LIST2');
    CHECKED_DROP('VIEW', 'VPROTOCOL_LIST');
    CHECKED_DROP('VIEW', 'VUSER_TABLE_TIMSTAMPS');
    CHECKED_DROP('FUNCTION', 'FN_PIPE_BASE_UNIQUEKEYS');
    CHECKED_DROP('FUNCTION', 'CHANGELOG_VALUES');
    CHECKED_DROP('PROCEDURE', 'CUSTOM_ADDLOG');
    CHECKED_DROP('PACKAGE', 'CUSTOM_CHANGELOG');
    CHECKED_DROP('PACKAGE', 'CHANGELOG_CONF');

    CHECKED_DROP('TABLE', 'CHANGE_LOG_BT');
    CHECKED_DROP('TABLE', 'CHANGE_LOG_TABLES');
    CHECKED_DROP('TABLE', 'CHANGE_LOG_USERS_BT');
    CHECKED_DROP('TABLE', 'CHANGE_LOG_CONFIG');
    CHECKED_DROP('TABLE', 'USER_NAMESPACES');

    CHECKED_DROP('VIEW', 'CHANGE_LOG');
    CHECKED_DROP('VIEW', 'VCHANGELOG_ITEM');
    CHECKED_DROP('VIEW', 'CHANGE_LOG_USERS');
    CHECKED_DROP('TYPE', 'CHANGELOG_ITEM_ARRAY_GTYPE');
    CHECKED_DROP('TYPE', 'CHANGELOG_ITEM_GTYPE');
    CHECKED_DROP('SEQUENCE', 'CHANGE_LOG_TABLES_SEQ');
    CHECKED_DROP('SEQUENCE', 'CHANGE_LOG_USERS_SEQ');
    CHECKED_DROP('SEQUENCE', 'APP_REPORT_FILTER_SEQ'); -- old name
    CHECKED_DROP('SEQUENCE', 'APP_REPORT_PREFERENCES_SEQ'); -- old name
    CHECKED_DROP('SEQUENCE', 'DATA_BROWSER_REPORT_PREFS_SEQ');
    CHECKED_DROP('SEQUENCE', 'DATA_BROWSER_REPORT_FILTER_SEQ');

    CHECKED_DROP('SEQUENCE', 'APP_USER_LEVELS_SEQ');
    CHECKED_DROP('SEQUENCE', 'CHANGE_LOG_TABLES_SEQ');
    CHECKED_DROP('SEQUENCE', 'CHANGE_LOG_USERS_SEQ');
    CHECKED_DROP('SEQUENCE', 'CHANGELOG_SEQ');
    CHECKED_DROP('SEQUENCE', 'USER_NAMESPACES_SEQ');
END;
/

