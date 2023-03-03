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
					APEX_UTIL.PAUSE(1/2);
					v_count := v_count + 1;
					EXIT WHEN v_count > 10;
				WHEN mview_does_not_exist or table_does_not_exist THEN
					EXIT;
			END;
		END LOOP;
	END;
BEGIN
	DROP_MVIEW('MVBASE_UNIQUE_KEYS');
END;
/


CREATE MATERIALIZED VIEW MVBASE_UNIQUE_KEYS (
	TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, REQUIRED, HAS_NULLABLE,
    KEY_HAS_WORKSPACE_ID, KEY_HAS_DELETE_MARK, KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID, 
    HAS_SCALAR_KEY, HAS_SERIAL_KEY, HAS_SCALAR_VIEW_KEY, HAS_SERIAL_VIEW_KEY,
    TRIGGER_HAS_NEXTVAL, TRIGGER_HAS_SYS_GUID, SEQUENCE_OWNER, SEQUENCE_NAME,
    DEFERRABLE, DEFERRED, STATUS, VALIDATED,
	VIEW_KEY_COLS, UNIQUE_KEY_COLS, KEY_COLS_COUNT, VIEW_KEY_COLS_COUNT, 
	INDEX_OWNER, INDEX_NAME, SHORT_NAME, BASE_NAME, RUN_NO
)
	CACHE
	NOLOGGING
	STORAGE (
	  INITIAL 1024
	  NEXT 1024
	  MINEXTENTS 1
	  MAXEXTENTS UNLIMITED
	  BUFFER_POOL KEEP
	)
	BUILD DEFERRED
    REFRESH COMPLETE
    ON DEMAND
AS
SELECT TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE, REQUIRED, HAS_NULLABLE,
    KEY_HAS_WORKSPACE_ID, KEY_HAS_DELETE_MARK, KEY_HAS_NEXTVAL, KEY_HAS_SYS_GUID, 
    HAS_SCALAR_KEY, HAS_SERIAL_KEY, HAS_SCALAR_VIEW_KEY, HAS_SERIAL_VIEW_KEY,
    TRIGGER_HAS_NEXTVAL, TRIGGER_HAS_SYS_GUID, SEQUENCE_OWNER, SEQUENCE_NAME,
    DEFERRABLE, DEFERRED, STATUS, VALIDATED,
	VIEW_KEY_COLS, UNIQUE_KEY_COLS, KEY_COLS_COUNT, VIEW_KEY_COLS_COUNT, INDEX_OWNER, INDEX_NAME,
	SHORT_NAME, BASE_NAME, RUN_NO
FROM TABLE ( changelog_conf.FN_Pipe_Base_Uniquekeys );


ALTER TABLE MVBASE_UNIQUE_KEYS ADD
 CONSTRAINT MVBASE_UNIQUE_KEYS_PK PRIMARY KEY (TABLE_NAME, TABLE_OWNER, CONSTRAINT_NAME) USING INDEX;

-- exec DBMS_MVIEW.REFRESH(list=>'MVBASE_UNIQUE_KEYS', method=>'c');