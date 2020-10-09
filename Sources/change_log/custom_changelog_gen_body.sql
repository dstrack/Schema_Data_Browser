/*

DROP PACKAGE custom_changelog_gen;
DROP VIEW MVCHANGELOG_REFERENCES;
DROP VIEW VCHANGE_LOG_FIELDS;
DROP FUNCTION Changelog_Values;
*/
--

CREATE OR REPLACE PACKAGE BODY custom_changelog_gen IS
    g_Default_Data_Precision    CONSTANT PLS_INTEGER := 38;     -- Default Data Precision for number columns with unknown precision
    g_Default_Data_Scale        CONSTANT PLS_INTEGER := 16;     -- Default Data Scale for number columns with unknown scale
    g_Format_Max_Length         CONSTANT PLS_INTEGER := 63;     -- maximal length of a format mask 

	PROCEDURE Lookup_custom_ref_Indexes (
		p_fkey_tables OUT VARCHAR2, 
		p_fkey_columns OUT VARCHAR2
	)
	IS
	BEGIN 
		with tab_refs as (
			select TABLE_NAME,
				sum(references_count) ref_count
			from MVBASE_ALTER_UNIQUEKEYS
			group by TABLE_NAME
		), tab_child_fk as ( 
			select R_TABLE_NAME TABLE_NAME, 
				COUNT(*) ref_to_count,
				COUNT(delete_rule_clause) child_count
			from MVBASE_FOREIGNKEYS
			where R_TABLE_NAME != TABLE_NAME
			group by R_TABLE_NAME
		), tab_ranked as (
			select R.TABLE_NAME fkey_tables, 
				changelog_conf.Get_Sequence_Column(T.SHORT_NAME) fkey_columns,
				R.ref_count, C.ref_to_count, C.child_count,
				DENSE_RANK() OVER ( ORDER BY C.child_count DESC, R.ref_count DESC, R.TABLE_NAME) rnk
			from tab_refs R, MVBASE_VIEWS T, tab_child_fk C
			where R.TABLE_NAME = T.TABLE_NAME
			and R.TABLE_NAME = C.TABLE_NAME
			and T.HAS_SCALAR_PRIMARY_KEY = 'YES'
			and T.INCLUDE_CHANGELOG = 'YES'
			and T.owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
		)
		select distinct
			LISTAGG(fkey_tables, ',') WITHIN GROUP (ORDER BY rnk) fkey_tables, 
			LISTAGG(fkey_columns, ',') WITHIN GROUP (ORDER BY rnk) fkey_columns
		into p_fkey_tables, p_fkey_columns
		from tab_ranked
		where rnk <= 9;
		
	END Lookup_custom_ref_Indexes;

	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2 DETERMINISTIC
	is
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
	begin
		return case when g_Generate_Compact_Queries = 'NO'
			then chr(10) || RPAD(' ', p_Indent)
			else chr(10) end;
	end;

    PROCEDURE Set_Process_Infos (
        p_rindex    in out binary_integer,
        p_slno      in out binary_integer,
        p_opname    in varchar2,
    	p_context   in binary_integer,
        p_totalwork in number,
        p_sofar     in number,
        p_units     in varchar2
    )
    IS
		v_Timemark number;
		v_TimeString VARCHAR2(40);
    BEGIN
		v_Timemark := dbms_utility.get_time;
        dbms_application_info.set_session_longops(
          rindex       => p_rindex,
          slno         => p_slno,
          op_name      => p_opname,
          target       => 0,
          context      => p_context,		-- context is of type BINARY_INTEGER
          sofar        => p_sofar,
          totalwork    => p_totalwork,
          target_desc  => 'Schema ' || SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
          units        => p_units
        );
        if p_sofar > 0 then 
			v_TimeString := TO_CHAR((v_Timemark - g_Timemark)/100.0, '9G990D00');
			DBMS_OUTPUT.PUT_LINE('-- ' || p_sofar || ' ' || p_units || ' ' || v_TimeString);
		end if;
		g_Timemark := v_Timemark;
    END Set_Process_Infos;

    PROCEDURE Run_Stat (
        p_Statement     IN CLOB,
        p_Delimiter     IN VARCHAR2 DEFAULT ';'
    )
    IS
    	v_Delimiter VARCHAR2(10);
    BEGIN
    	v_Delimiter := CASE WHEN p_Delimiter = '/' THEN CHR(10) || p_Delimiter || CHR(10) ELSE p_Delimiter END;
        DBMS_OUTPUT.PUT_LINE(SUBSTR(p_Statement, 1, 32760) || v_Delimiter);
        EXECUTE IMMEDIATE p_Statement;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SUBSTR(p_Statement, 1, 32760) || v_Delimiter);
        DBMS_OUTPUT.PUT_LINE('-- SQL Error :' || SQLCODE || ' ' || SQLERRM);
        RAISE;
    END Run_Stat;

    PROCEDURE Try_Run_Stat (
        p_Statement     IN CLOB,
        p_Delimiter     IN VARCHAR2 DEFAULT ';'
    )
    IS
    	v_Delimiter VARCHAR2(10);
    BEGIN
    	v_Delimiter := CASE WHEN p_Delimiter = '/' THEN CHR(10) || p_Delimiter ELSE p_Delimiter END;
        -- DBMS_OUTPUT.PUT(TO_CHAR(SYSDATE,'HH24:MI:SS') || ' : ');
        DBMS_OUTPUT.PUT_LINE(p_Statement || v_Delimiter);
        EXECUTE IMMEDIATE p_Statement;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('-- SQL Warning :' || SQLCODE || ' ' || SQLERRM);
        if SQLCODE not in (
            -1,     -- Unique Constraint violated
            -942,   -- Tabelle oder View nicht vorhanden
            -955,   -- Es gibt bereits ein Objekt mit diesem Namen
            -4080,  -- Trigger ist nicht vorhanden
            -2289,  -- Sequence ist nicht vorhanden.
            -1418,  -- Angegebener Index ist nicht vorhanden
            -1408,  -- Diese Spaltenliste hat bereits einen Index
            -24344, -- success with compilation error
            -23292) -- Das Constraint ist nicht vorhanden
        then
            RAISE;
        end if;
    END Try_Run_Stat;

	-- Internal
	FUNCTION Get_Last_DDL_Time(
		p_Dependent_MViews VARCHAR2 DEFAULT NULL
	)
	RETURN USER_OBJECTS.LAST_DDL_TIME%TYPE
	IS
		v_LAST_DDL_TIME USER_OBJECTS.LAST_DDL_TIME%TYPE;
	BEGIN
		SELECT MAX (LAST_DDL_TIME) LAST_DDL_TIME
		INTO v_LAST_DDL_TIME
		FROM (
			SELECT MAX(LAST_DDL_TIME) LAST_DDL_TIME
			FROM USER_OBJECTS A
			WHERE A.OBJECT_TYPE IN ('TABLE', 'PACKAGE BODY')
			AND (A.OBJECT_NAME IN ('CUSTOM_CHANGELOG', 'CHANGELOG_CONF') OR A.OBJECT_TYPE = 'TABLE')
			UNION ALL
			SELECT MAX(LAST_MODIFIED_AT) LAST_DDL_TIME
			FROM CHANGE_LOG_CONFIG A
			UNION ALL
			SELECT LAST_REFRESH_DATE
			FROM USER_MVIEWS
			WHERE INSTR(p_Dependent_MViews, MVIEW_NAME) > 0
		);

		RETURN v_LAST_DDL_TIME;
	END;

	PROCEDURE MView_Refresh (
		p_MView_Name VARCHAR2,
		p_Dependent_MViews VARCHAR2 DEFAULT NULL,
		p_LAST_DDL_TIME IN OUT USER_OBJECTS.LAST_DDL_TIME%TYPE
	)
	IS
		v_LAST_DDL_TIME USER_OBJECTS.LAST_DDL_TIME%TYPE;
		v_LAST_REFRESH_DATE	USER_MVIEWS.LAST_REFRESH_DATE%TYPE;
		v_STALENESS	USER_MVIEWS.STALENESS%TYPE;
		v_REFRESH_METHOD USER_MVIEWS.REFRESH_METHOD%TYPE;
		v_COMPILE_STATE USER_MVIEWS.COMPILE_STATE%TYPE;
		v_Statement VARCHAR2(256);
	BEGIN
		SELECT LAST_REFRESH_DATE, STALENESS, REFRESH_METHOD, COMPILE_STATE
		INTO v_LAST_REFRESH_DATE, v_STALENESS, v_REFRESH_METHOD, v_COMPILE_STATE
		FROM USER_MVIEWS
		WHERE MVIEW_NAME = p_MView_Name
		;
		if p_LAST_DDL_TIME IS NOT NULL then 
			v_LAST_DDL_TIME := p_LAST_DDL_TIME;
		else
			v_LAST_DDL_TIME := Get_Last_DDL_Time(p_Dependent_MViews);
		end if;
		/*if v_COMPILE_STATE = 'NEEDS_COMPILE' then 
			v_Statement := 'ALTER MATERIALIZED VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(p_MView_Name) || ' COMPILE';
			EXECUTE IMMEDIATE v_Statement;
			DBMS_OUTPUT.PUT_LINE('-- compiled ' || p_MView_Name || ' Compile State: ' || v_COMPILE_STATE || ' Staleness: ' || v_STALENESS);
		end if;*/
		if v_LAST_DDL_TIME > v_LAST_REFRESH_DATE OR v_LAST_REFRESH_DATE IS NULL 
		or v_STALENESS IN ('NEEDS_COMPILE', 'UNUSABLE') then
			DBMS_MVIEW.REFRESH(p_MView_Name);
			p_LAST_DDL_TIME := SYSDATE;
			DBMS_OUTPUT.PUT_LINE('-- Refreshed ' || p_MView_Name || ' Compile State: ' || v_COMPILE_STATE || ' Staleness: ' || v_STALENESS);
		else
			DBMS_OUTPUT.PUT_LINE('-- skipped ' || p_MView_Name || ' Compile State: ' || v_COMPILE_STATE || ' Staleness: ' || v_STALENESS);
		end if;
	END MView_Refresh;

	PROCEDURE MView_Refresh (
		p_MView_Name VARCHAR2,
		p_Dependent_MViews VARCHAR2 DEFAULT NULL
	)
    IS
		v_LAST_DDL_TIME USER_OBJECTS.LAST_DDL_TIME%TYPE;
    BEGIN
		MView_Refresh(p_MView_Name, p_Dependent_MViews, v_LAST_DDL_TIME);
	eND MView_Refresh;
	
    PROCEDURE Refresh_MViews (
    	p_context  				IN binary_integer DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0),
    	p_Start_Step 			IN binary_integer DEFAULT 1
    )
    IS
        v_rindex 		binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno   		binary_integer;
        v_Proc_Name 	VARCHAR2(128) := 'Refresh snapshots for history views';
        v_Steps  		constant binary_integer := 8;
		v_Schema_Name	VARCHAR2(40) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		v_workspace_id 	NUMBER;
		v_LAST_DDL_TIME USER_OBJECTS.LAST_DDL_TIME%TYPE;
    BEGIN
    	if p_Start_Step<=v_Steps then
        	Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 0, 'steps');
        	v_LAST_DDL_TIME := Get_Last_DDL_Time;
		end if;
		for v_Step in p_Start_Step..v_Steps loop
			case v_Step 
				when 1 then MView_Refresh(p_MView_Name => 'MVBASE_UNIQUE_KEYS', p_LAST_DDL_TIME => v_LAST_DDL_TIME); -- used for history views
				when 2 then MView_Refresh(p_MView_Name => 'MVBASE_ALTER_UNIQUEKEYS', p_LAST_DDL_TIME => v_LAST_DDL_TIME); -- used for history views
							-- Dependent MViews: 'MVBASE_UNIQUE_KEYS'
				when 3 then MView_Refresh(p_MView_Name => 'MVBASE_FOREIGNKEYS', p_LAST_DDL_TIME => v_LAST_DDL_TIME);
							-- Dependent MViews: 'MVBASE_ALTER_UNIQUEKEYS'
				when 4 then MView_Refresh(p_MView_Name => 'MVBASE_VIEWS', p_LAST_DDL_TIME => v_LAST_DDL_TIME);
							-- Dependent MViews: 'MVBASE_ALTER_UNIQUEKEYS'
				when 5 then MView_Refresh(p_MView_Name => 'MVBASE_VIEW_FOREIGN_KEYS', p_LAST_DDL_TIME => v_LAST_DDL_TIME);
							-- Dependent MViews: 'MVBASE_FOREIGNKEYS'
				when 6 then MView_Refresh(p_MView_Name => 'MVBASE_REFERENCES', p_LAST_DDL_TIME => v_LAST_DDL_TIME); 
							-- Dependent MViews: 'MVBASE_FOREIGNKEYS,MVBASE_VIEW_FOREIGN_KEYS'
				when 7 then MView_Refresh(p_MView_Name => 'MVCHANGELOG_REFERENCES', p_LAST_DDL_TIME => v_LAST_DDL_TIME); 
				when 8 then custom_changelog.Changelog_Tables_Init('MVBASE_VIEWS');
				-- foreign keys --
				else null;
			end case;
			Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, v_Step, 'steps');
        end loop;
        DBMS_OUTPUT.PUT_LINE('-- Done --');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
    END Refresh_MViews;

	PROCEDURE Load_Job(
		p_Job_Name VARCHAR2,
		p_Comment VARCHAR2,
		p_Sql IN VARCHAR2
	)
	IS
		v_Job_Name 			USER_SCHEDULER_JOBS.JOB_NAME%TYPE;
		v_Job_Name_Prefix 	USER_SCHEDULER_JOBS.JOB_NAME%TYPE := SUBSTR(g_Job_Name_Prefix || p_Job_Name, 1, 18);
	BEGIN
		begin
			SELECT JOB_NAME
			INTO v_Job_Name
			FROM USER_SCHEDULER_JOBS
			WHERE JOB_ACTION = p_Sql
			AND JOB_NAME LIKE v_Job_Name_Prefix || '%'
			AND STATE IN ('SCHEDULED', 'RETRY SCHEDULED', 'RUNNING');
			DBMS_OUTPUT.PUT_LINE('custom_changelog_gen.Load_Job - found ' || v_Job_Name_Prefix || '. stopped.');
			return;
		exception
		  when NO_DATA_FOUND then
			v_Job_Name := dbms_scheduler.generate_job_name (v_Job_Name_Prefix);
		end;
		DBMS_OUTPUT.PUT_LINE('custom_changelog_gen.Load_Job - start ' || v_Job_Name || '; sql: ' || p_Sql);
		dbms_scheduler.create_job(
			job_name => v_Job_Name,
			job_type => 'PLSQL_BLOCK',
			job_action => p_Sql,
			comments => p_Comment,
			enabled => true );
		COMMIT;
	END;

	FUNCTION Get_MView_Last_Refresh_Date(p_MView_Name_Pattern VARCHAR2)
	RETURN USER_MVIEWS.LAST_REFRESH_DATE%TYPE
	IS
		v_LAST_REFRESH_DATE	USER_MVIEWS.LAST_REFRESH_DATE%TYPE;
	BEGIN
		SELECT MIN(LAST_REFRESH_DATE)
		INTO v_LAST_REFRESH_DATE
		FROM USER_MVIEWS
		WHERE MVIEW_NAME LIKE p_MView_Name_Pattern;
		RETURN v_LAST_REFRESH_DATE;
	END;

    PROCEDURE Refresh_MViews_Job (
    	p_Start_Step 	IN binary_integer DEFAULT 1,
        p_context binary_integer DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)		-- context is of type BINARY_INTEGER
   	)
	IS
		v_LAST_DDL_TIME USER_OBJECTS.LAST_DDL_TIME%TYPE;
		v_LAST_REFRESH_DATE	USER_MVIEWS.LAST_REFRESH_DATE%TYPE;
		v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
	BEGIN
		v_LAST_DDL_TIME := Get_Last_DDL_Time;
		v_LAST_REFRESH_DATE := Get_MView_Last_Refresh_Date('MVBASE%');
		if v_LAST_DDL_TIME > v_LAST_REFRESH_DATE OR v_LAST_REFRESH_DATE IS NULL then
			v_sql :=
			'begin' || chr(10)
			|| ' custom_changelog_gen.Refresh_MViews('
			|| 'p_context=>'
			|| DBMS_ASSERT.ENQUOTE_LITERAL(p_context)
			|| ',p_Start_Step=>'
			|| NVL(p_Start_Step, 1)
			|| ');' || chr(10)
			|| 'end;';
			custom_changelog_gen.Load_Job(
				p_Job_Name => 'CHANGELOG_INIT_MVIEWS',
				p_Comment => 'Refresh views and trigger for change log',
				p_Sql => v_sql
			);
		end if;
	END Refresh_MViews_Job;

	FUNCTION MViews_Stale_Count RETURN NUMBER
	IS
        v_Count 		PLS_INTEGER;
	BEGIN
		SELECT COUNT(*) INTO v_Count
		FROM MVBASE_UNIQUE_KEYS S
		WHERE NOT EXISTS (
			SELECT 1
			FROM SYS.ALL_TABLES T
			WHERE T.TABLE_NAME = S.TABLE_NAME
			AND T.OWNER = S.TABLE_OWNER
		);
		return v_Count;
	END;

    PROCEDURE Drop_ChangeLog_Foreign_Keys
    IS
    BEGIN
        FOR  stat_cur IN (
			SELECT 'DROP INDEX ' || D.INDEX_NAME INDEX_STAT
			FROM (
				SELECT 'CUSTOM_REF_ID' || LEVEL CHANGELOG_REF_NAME
				FROM DUAL CONNECT BY LEVEL <= 9
			) A, USER_IND_COLUMNS D
			WHERE D.TABLE_NAME = custom_changelog.Get_ChangeLogTable
			AND D.COLUMN_NAME = A.CHANGELOG_REF_NAME
        )
        LOOP
			Run_Stat (stat_cur.INDEX_STAT);
        END LOOP;
        FOR  stat_cur IN (
			SELECT 'ALTER TABLE ' || custom_changelog.Get_ChangeLogTable || ' DROP CONSTRAINT ' || D.CONSTRAINT_NAME FOREIGN_KEY_STAT
			FROM (
				SELECT 'CUSTOM_REF_ID' || LEVEL CHANGELOG_REF_NAME
				FROM DUAL CONNECT BY LEVEL <= 9
			) A, USER_CONS_COLUMNS D
			WHERE D.TABLE_NAME = custom_changelog.Get_ChangeLogTable
			AND D.COLUMN_NAME = A.CHANGELOG_REF_NAME
        )
        LOOP
			Run_Stat (stat_cur.FOREIGN_KEY_STAT);
        END LOOP;
    END Drop_ChangeLog_Foreign_Keys;

    PROCEDURE Add_ChangeLog_Foreign_Keys
    IS
    BEGIN
        FOR  stat_cur IN (
			SELECT A.TABLE_NAME, A.COLUMN_NAME, A.CHANGELOG_REF_NAME, A.RUN_NO,
				CASE WHEN NOT EXISTS (
					SELECT 1
					FROM USER_INDEXES D
					WHERE D.TABLE_NAME = custom_changelog.Get_ChangeLogTable
					AND D.INDEX_NAME = A.INDEX_NAME
				) THEN
					CASE WHEN HAS_WORKSPACE_ID = 'NO' THEN
						'CREATE INDEX ' || A.INDEX_NAME || ' ON ' || custom_changelog.Get_ChangeLogTable || ' (' || CHANGELOG_REF_NAME || ') COMPRESS 1'
					ELSE
						'CREATE INDEX ' || A.INDEX_NAME || ' ON ' || custom_changelog.Get_ChangeLogTable || ' (' || changelog_conf.Get_ColumnWorkspace || ', ' || CHANGELOG_REF_NAME || ') COMPRESS 2'
					END
				END INDEX_STAT,
				CASE WHEN NOT EXISTS (
					SELECT 1
					FROM USER_CONSTRAINTS D
					WHERE D.TABLE_NAME = custom_changelog.Get_ChangeLogTable
					AND D.CONSTRAINT_NAME = A.CONSTRAINT_NAME
				) THEN
					CASE WHEN HAS_WORKSPACE_ID = 'NO' THEN
						'ALTER TABLE ' || custom_changelog.Get_ChangeLogTable || ' ADD CONSTRAINT ' || CONSTRAINT_NAME
						|| ' FOREIGN KEY ( ' || CHANGELOG_REF_NAME || ' ) REFERENCES '
						|| A.TABLE_NAME || ' ( ' || SCALAR_KEY_COLUMN || ' ) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED'
					END -- in case WHEN HAS_WORKSPACE_ID = 'YES' THEN not foreign key is possible because the SET NULL clause would cause an error when a rows in the target table is deleted.
				END FOREIGN_KEY_STAT
			FROM (
				SELECT B.TABLE_NAME, C.COLUMN_NAME, 'CUSTOM_REF_ID' || T.R CHANGELOG_REF_NAME, T.R RUN_NO,
					HAS_WORKSPACE_ID,
					'CHANGE_LOG_' || SUBSTR(SHORT_NAME, 1, 15) || '_FKI' INDEX_NAME,
					'CHANGE_LOG_' || SUBSTR(SHORT_NAME, 1, 15) || '_FK' CONSTRAINT_NAME,
					SCALAR_KEY_COLUMN
				FROM (SELECT N.COLUMN_VALUE TABLE_NAME, ROWNUM R FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ChangeLogFKeyTables, ',') ) N) T
				JOIN (SELECT N.COLUMN_VALUE COLUMN_NAME, ROWNUM R  FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ChangeLogFKeyColumns, ',') ) N) C ON T.R = C.R -- same position in the list
				JOIN MVBASE_VIEWS B ON B.VIEW_NAME = T.TABLE_NAME
			) A
            ORDER BY RUN_NO
        )
        LOOP
        	if stat_cur.INDEX_STAT IS NOT NULL then
				Run_Stat (stat_cur.INDEX_STAT);
            end if;
        	if stat_cur.FOREIGN_KEY_STAT IS NOT NULL then
				Run_Stat (stat_cur.FOREIGN_KEY_STAT);
            end if;
        END LOOP;
    END Add_ChangeLog_Foreign_Keys;

    PROCEDURE Drop_ChangeLog_Table_Trigger (
        p_Table_Name        IN VARCHAR2 DEFAULT NULL,
        p_Changelog_Only    IN VARCHAR2 DEFAULT 'YES'
    )
    IS
    BEGIN
		-- remove base table trigger with reference to Get_ChangeLogFunction
        FOR  stat_cur IN (
            SELECT 'DROP TRIGGER ' || TRIGGER_NAME STATMENT, TRIGGERING_EVENT, TRIGGER_BODY
            FROM USER_TRIGGERS T
			JOIN MVBASE_VIEWS B ON T.TABLE_NAME = B.TABLE_NAME
            WHERE T.BASE_OBJECT_TYPE = 'TABLE'
            AND T.TRIGGER_TYPE = 'COMPOUND'
            AND T.TRIGGER_NAME LIKE changelog_conf.Get_ChangelogTrigger_Name(B.SHORT_NAME, '%')
        	AND T.TRIGGERING_EVENT = 'INSERT OR UPDATE OR DELETE'
        	AND T.REFERENCING_NAMES = 'REFERENCING NEW AS NEW OLD AS OLD'
            AND (T.TABLE_NAME = p_Table_Name OR p_Table_Name IS NULL)
        )
        LOOP
            if REGEXP_INSTR(stat_cur.TRIGGER_BODY, custom_changelog.Get_ChangeLogFunction, 1, 1, 1, 'i') > 0
            OR REGEXP_INSTR(stat_cur.TRIGGER_BODY, custom_changelog.Get_AltChangeLogFunction, 1, 1, 1, 'i') > 0  then
                Run_Stat (stat_cur.STATMENT);
            end if;
        END LOOP;
		if p_Changelog_Only = 'NO' then
			FOR  stat_cur IN (
				SELECT 'DROP TRIGGER ' || TRIGGER_NAME STATMENT, TRIGGERING_EVENT, TRIGGER_BODY
				FROM TABLE(changelog_conf.FN_Pipe_base_triggers)
				WHERE IS_CANDIDATE = 'YES'
				AND (TRIGGERING_EVENT IN ('INSERT', 'UPDATE') AND TRIGGER_TYPE = 'BEFORE EACH ROW')
				AND (TABLE_NAME = p_Table_Name OR p_Table_Name IS NULL)
			)
			LOOP
				if (stat_cur.TRIGGERING_EVENT = 'INSERT'
					-- AND (REGEXP_INSTR(stat_cur.TRIGGER_BODY, 'if :new\.' || v_Primary_Key_Col || ' is null then', 1, 1, 1, 'i') > 0
					AND ( REGEXP_INSTR(stat_cur.TRIGGER_BODY, changelog_conf.Get_FunctionModifyUser, 1, 1, 1, 'i') > 0
					OR REGEXP_INSTR(stat_cur.TRIGGER_BODY, changelog_conf.Get_ColumnModifyDate, 1, 1, 1, 'i') > 0
					)
				)
				or (stat_cur.TRIGGERING_EVENT = 'UPDATE'
					AND (REGEXP_INSTR(stat_cur.TRIGGER_BODY, changelog_conf.Get_FunctionModifyUser, 1, 1, 1, 'i') > 0
					 OR REGEXP_INSTR(stat_cur.TRIGGER_BODY, changelog_conf.Get_ColumnModifyDate, 1, 1, 1, 'i') > 0)
				) then
					Run_Stat (stat_cur.STATMENT);
				end if;
			END LOOP;
		end if;
    END Drop_ChangeLog_Table_Trigger;

	PROCEDURE Recomp_Invalid_Objects
	is
	begin 
		DBMS_OUTPUT.PUT_LINE('-- compile all invalid objects --');
		for cur in (
			SELECT 
				case when object_type = 'PACKAGE BODY' then 
					'ALTER PACKAGE' || ' ' || object_name || ' COMPILE BODY'
				else 
					'ALTER ' || object_type || ' ' || object_name||' COMPILE'
				end stat
			FROM USER_OBJECTS T1
			WHERE status = 'INVALID'
			AND object_type in ('FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'VIEW', 'TRIGGER', 'MATERIALIZED VIEW' )
			AND object_name != 'CUSTOM_CHANGELOG_GEN' -- avoid deadlock
		) loop
			DBMS_OUTPUT.PUT_LINE(cur.stat || ';');
			begin
			EXECUTE IMMEDIATE cur.stat;
			EXCEPTION
			WHEN OTHERS THEN
			-- warning ora-24344 success with compilation error
				DBMS_OUTPUT.PUT_LINE('-- SQL Error :' || SQLCODE || ' ' || SQLERRM);
				if SQLCODE != -24344 then
					RAISE;
				end if;
			END;
		end loop;
	end Recomp_Invalid_Objects;


    PROCEDURE Tables_Add_Serial_Keys(
        p_Table_Name IN VARCHAR2 DEFAULT NULL,
        p_Changelog_Only IN VARCHAR2 DEFAULT 'YES'
    )
    IS
    	v_Count NUMBER := 0;
    BEGIN
		FOR  stat_cur IN (
			SELECT VIEW_NAME, TABLE_NAME,
				CASE WHEN NOT EXISTS (
					SELECT 1 FROM USER_SEQUENCES S
					WHERE S.SEQUENCE_NAME = T.SEQUENCE_NAME
				) THEN
					'CREATE SEQUENCE ' || changelog_conf.Get_Table_Schema || SEQUENCE_NAME ||
					' START WITH 1 INCREMENT BY 1 ' || changelog_conf.Get_SequenceOptions
				END SEQUENCE_STAT,
				CASE WHEN COLUMN_EXISTS = 'NO' THEN
					'ALTER TABLE ' || TABLE_NAME || ' ADD ( '
					|| COLUMN_NAME || ' NUMBER ' ||
					CASE WHEN changelog_conf.Use_Serial_Default = 'YES' THEN
						' DEFAULT ON NULL ' || SEQUENCE_NAME || '.NEXTVAL NOT NULL'
					END || ')'
				END ADD_COLUMN_STAT,
				CASE WHEN NOT EXISTS (
					SELECT 1
					FROM USER_COL_COMMENTS C
					WHERE C.COLUMN_NAME = T.COLUMN_NAME
					AND C.TABLE_NAME = T.TABLE_NAME
				) THEN
					'COMMENT ON COLUMN ' || TABLE_NAME || '.' || COLUMN_NAME
					|| ' IS ''Unique key with sequence (added by custom_changelog_gen to support auditing functions )'''
				END COMMENT_STAT,
				CASE WHEN changelog_conf.Use_Serial_Default = 'NO'
				AND COLUMN_EXISTS = 'NO' THEN
					'UPDATE ' || TABLE_NAME || ' SET ' ||  COLUMN_NAME || ' = ROWNUM'
				END INIT_STAT,
				 CASE WHEN COLUMN_EXISTS = 'NO' AND changelog_conf.Use_Serial_Default = 'NO' THEN
					'ALTER TABLE ' || TABLE_NAME || ' MODIFY ' ||  COLUMN_NAME || ' NOT NULL'
				END NN_STAT,
				CASE WHEN NOT EXISTS (
					SELECT 1 FROM USER_CONSTRAINTS S
					WHERE S.CONSTRAINT_NAME = T.CONSTRAINT_NAME
					AND S.TABLE_NAME = T.TABLE_NAME
				) THEN
					'ALTER TABLE ' || TABLE_NAME || ' ADD CONSTRAINT ' || CONSTRAINT_NAME || ' ' 
					|| case when CONSTRAINT_TYPE = 'P' then 'UNIQUE' else 'PRIMARY KEY' end 
					|| ' ('
					|| COLUMN_NAME || ') USING INDEX'
				END ADD_KEY_STAT
			FROM (
				SELECT VIEW_NAME, TABLE_NAME, CONSTRAINT_TYPE,
					changelog_conf.Get_Sequence_Name(SHORT_NAME) SEQUENCE_NAME,
					changelog_conf.Get_Sequence_Column(SHORT_NAME) COLUMN_NAME,
					changelog_conf.Get_Sequence_Constraint(SHORT_NAME) CONSTRAINT_NAME,
					CASE WHEN EXISTS (
						SELECT 1 FROM SYS.USER_TAB_COLS S
						WHERE S.COLUMN_NAME = changelog_conf.Get_Sequence_Column(SHORT_NAME)
						AND S.TABLE_NAME = T.TABLE_NAME
					) THEN 'YES' ELSE 'NO' END COLUMN_EXISTS
				FROM MVBASE_VIEWS T
				WHERE HAS_SCALAR_KEY = 'NO'
				AND IS_EXTERNAL_TABLE = 'NO'
				AND (INCLUDE_CHANGELOG = 'YES' OR p_Changelog_Only = 'NO')
				AND (TABLE_NAME = p_Table_Name OR p_Table_Name IS NULL)
			) T
		)
		LOOP
 			DBMS_OUTPUT.PUT_LINE('-- Tables_Add_Serial_Keys ' || stat_cur.TABLE_NAME || '--');
			if stat_cur.SEQUENCE_STAT IS NOT NULL then
				Run_Stat (stat_cur.SEQUENCE_STAT);
			end if;
			if stat_cur.ADD_COLUMN_STAT IS NOT NULL then
				Run_Stat (stat_cur.ADD_COLUMN_STAT);
			end if;
			if stat_cur.COMMENT_STAT IS NOT NULL then
				Run_Stat (stat_cur.COMMENT_STAT);
			end if;
			if stat_cur.INIT_STAT IS NOT NULL then
				Run_Stat (stat_cur.INIT_STAT);
				COMMIT;
			end if;
			if stat_cur.NN_STAT IS NOT NULL then
				Run_Stat (stat_cur.NN_STAT);
			end if;
			if stat_cur.ADD_KEY_STAT IS NOT NULL then
				Run_Stat (stat_cur.ADD_KEY_STAT);
			end if;
			v_Count := v_Count + 1;
		END LOOP;
		if v_Count > 0 then
			Recomp_Invalid_Objects;
			MView_Refresh('MVBASE_UNIQUE_KEYS');
			MView_Refresh('MVBASE_ALTER_UNIQUEKEYS', 'MVBASE_UNIQUE_KEYS');
			MView_Refresh('MVBASE_VIEWS', 'MVBASE_ALTER_UNIQUEKEYS');
        end if;
    END Tables_Add_Serial_Keys;

    FUNCTION  Map_Custom_Ref_Names
    RETURN VARCHAR2
    IS
        stat_cur            SYS_REFCURSOR;
        v_Declare           VARCHAR2(4000) := chr(10);
    BEGIN

        FOR  stat_cur IN (
			SELECT ', ' || CHANGELOG_NAME || ' ' || COLUMN_NAME DECLARE_STAT
			FROM (
				SELECT T.TABLE_NAME, C.COLUMN_NAME, 'CUSTOM_REF_ID' || T.R CHANGELOG_NAME, T.R RUN_NO
				FROM (SELECT N.COLUMN_VALUE TABLE_NAME, ROWNUM R FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ChangeLogFKeyTables, ',') ) N) T
				JOIN (SELECT N.COLUMN_VALUE COLUMN_NAME, ROWNUM R  FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ChangeLogFKeyColumns, ',') ) N) C ON T.R = C.R -- same position in the list
			)
            ORDER BY RUN_NO
        )
        LOOP
            v_Declare := v_Declare  || RPAD(' ', 4) || stat_cur.DECLARE_STAT || chr(10);
        END LOOP;
        RETURN v_Declare;
    END Map_Custom_Ref_Names;

    FUNCTION VPROTOCOL_LIST_Query RETURN VARCHAR2
    IS
    BEGIN
        return 'SELECT ID, TABLE_ID, TABLE_NAME, VIEW_NAME, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_NAME, LOGGING_DATE'
		||	Map_Custom_Ref_Names
		|| 'FROM VCHANGE_LOG' || chr(10)
		;
    END;
    FUNCTION VPROTOCOL_LIST_Cols RETURN VARCHAR2
    IS
    BEGIN
        return 'ID, TABLE_ID, TABLE_NAME, VIEW_NAME, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_NAME, LOGGING_DATE'
		||	case when custom_changelog.Get_ChangeLogFKeyColumns IS NOT NULL then ', ' || custom_changelog.Get_ChangeLogFKeyColumns  end
		;
    END VPROTOCOL_LIST_Cols;

    FUNCTION VPROTOCOL_COLUMNS_LIST_Query RETURN VARCHAR2
    IS
    BEGIN
        return 'SELECT ID, LOGGING_TIMESTAMP, LOGGING_DATE, USER_NAME, ' || NL(4)
		|| 'USER_NAME_INITCAP, ACTION_NAME, ACTION_CODE, ' || NL(4)
		|| 'TABLE_ID, TABLE_NAME, TABLE_NAME_INITCAP, OBJECT_ID, ' || NL(4)
		|| 'IS_HIDDEN, COLUMN_ID, COLUMN_NAME,' || NL(4)
		|| 'R_TABLE_NAME, R_COLUMN_NAME, FIELD_NAME, FIELD_VALUE, AFTER_VALUE'
		||	Map_Custom_Ref_Names
		|| 'FROM VCHANGE_LOG_FIELDS' || chr(10)
		;
    END VPROTOCOL_COLUMNS_LIST_Query;

    FUNCTION VPROTOCOL_COLUMNS_LIST_Cols RETURN VARCHAR2
    IS
    BEGIN
        return 'ID, LOGGING_TIMESTAMP, LOGGING_DATE, USER_NAME, '
		|| 'USER_NAME_INITCAP, ACTION_NAME, ACTION_CODE, '
		|| 'TABLE_ID, TABLE_NAME, TABLE_NAME_INITCAP, OBJECT_ID, '
		|| 'IS_HIDDEN, COLUMN_ID, COLUMN_NAME, '
		|| 'R_TABLE_NAME, R_COLUMN_NAME, FIELD_NAME, FIELD_VALUE, AFTER_VALUE'
		||	case when custom_changelog.Get_ChangeLogFKeyColumns IS NOT NULL then ', ' || custom_changelog.Get_ChangeLogFKeyColumns  end
		;
    END VPROTOCOL_COLUMNS_LIST_Cols;

    FUNCTION VPROTOCOL_COLUMNS_LIST2_Query RETURN VARCHAR2
    IS
    BEGIN
		return 'SELECT ID, LOGGING_DATE LOGGING_TIMESTAMP,' || NL(4)
		|| 'CAST(LOGGING_DATE AS DATE) LOGGING_DATE,' || NL(4)
		|| 'USER_NAME,' || NL(4)
		|| 'USER_NAME_INITCAP,' || NL(4)
		|| 'ACTION_NAME,' || NL(4)
		|| 'ACTION_CODE,' || NL(4)
		|| 'TABLE_ID,' || NL(4)
		|| 'NVL(VIEW_NAME, TABLE_NAME) TABLE_NAME,' || NL(4)
		|| 'TABLE_NAME_INITCAP,' || NL(4)
		|| 'OBJECT_ID, IS_HIDDEN,' || NL(4)
		|| 'Changelog_Values(ID, LOGGING_DATE) FIELD_VALUES'
		||	Map_Custom_Ref_Names
		|| 'FROM VCHANGE_LOG' || chr(10)
		;
    END VPROTOCOL_COLUMNS_LIST2_Query;

    FUNCTION VPROTOCOL_COLUMNS_LIST2_Cols RETURN VARCHAR2
    IS
    BEGIN
        return 'ID, LOGGING_TIMESTAMP, LOGGING_DATE, USER_NAME, '
		|| 'USER_NAME_INITCAP, ACTION_NAME, ACTION_CODE, '
		|| 'TABLE_ID, TABLE_NAME, TABLE_NAME_INITCAP, OBJECT_ID, '
		|| 'IS_HIDDEN, FIELD_VALUES'
		||	case when custom_changelog.Get_ChangeLogFKeyColumns IS NOT NULL then ', ' || custom_changelog.Get_ChangeLogFKeyColumns  end
		;
    END VPROTOCOL_COLUMNS_LIST2_Cols;

    PROCEDURE  Gen_VPROTOCOL_Views
    IS
		v_Stat			VARCHAR2(32767);
    BEGIN
        v_Stat :=
        'CREATE OR REPLACE VIEW VPROTOCOL_LIST (' || VPROTOCOL_LIST_Cols || ') AS ' || chr(10)
		|| VPROTOCOL_LIST_Query;
		Run_Stat (v_Stat);
        v_Stat :=
        'CREATE OR REPLACE VIEW VPROTOCOL_COLUMNS_LIST (' || VPROTOCOL_COLUMNS_LIST_Cols || ') AS ' || chr(10)
        || VPROTOCOL_COLUMNS_LIST_Query;
		Run_Stat (v_Stat);
        v_Stat :=
        'CREATE OR REPLACE VIEW VPROTOCOL_COLUMNS_LIST2 (' || VPROTOCOL_COLUMNS_LIST2_Cols || ') AS ' || chr(10)
		|| VPROTOCOL_COLUMNS_LIST2_Query;
		Run_Stat (v_Stat);
    END Gen_VPROTOCOL_Views;

    FUNCTION User_Table_Timstamps_Query(p_Table_Name VARCHAR2 DEFAULT NULL) 
    RETURN CLOB
    IS
        v_Stat      CLOB;
        v_SQLCODE   INTEGER;
        v_Count		INTEGER := 0;
    BEGIN
   		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
        for v_cur IN (
			SELECT 'SELECT ' || DBMS_ASSERT.ENQUOTE_LITERAL(VIEW_NAME) || ' AS TABLE_NAME, '
				|| CASE WHEN HAS_SCALAR_KEY = 'YES'
					THEN REPLACE(SCALAR_KEY_COLUMN,  changelog_conf.Get_ColumnWorkspace || ', ')
					ELSE 'NULL' END || ' AS ID ' || ', '
				|| 'CAST(ROWID AS VARCHAR2(128)) AS RID ' || ', '
				|| MODFIY_TIMESTAMP_COLUMN_NAME || ', ' || MODFIY_USER_COLUMN_NAME
				|| ', ' || CASE WHEN HAS_WORKSPACE_ID = 'NO' THEN 'TO_NUMBER(' || changelog_conf.Get_Context_WorkspaceID_Expr || ') ' END || changelog_conf.Get_ColumnWorkspace
				|| ', ' 
				|| CASE WHEN HAS_DELETE_MARK IN ('YES', 'READY')
					THEN 'CASE WHEN ' || changelog_conf.Get_ColumnDeletedMark || ' IS NULL THEN '
						|| DBMS_ASSERT.ENQUOTE_LITERAL('U') || ' ELSE ' || DBMS_ASSERT.ENQUOTE_LITERAL('D') || ' END '
					ELSE DBMS_ASSERT.ENQUOTE_LITERAL('U')
					END || ' DML$_ACTION'
				|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(TABLE_NAME) || CHR(10)
				|| CASE WHEN LEAD(VIEW_NAME) OVER (ORDER BY VIEW_NAME) IS NOT NULL THEN ' UNION ALL ' 
				END || CHR(10) STAT
			FROM MVBASE_VIEWS
			WHERE HAS_MODFIY_TIMESTAMP  IN ('YES', 'READY')
			AND HAS_MODFIY_USER IN ('YES', 'READY')
			AND TABLE_NAME = NVL(p_Table_Name, TABLE_NAME)
			ORDER BY 1
        )
        LOOP
	   		 dbms_lob.writeappend(v_Stat, length(v_cur.STAT), v_cur.STAT);
            v_Count := v_Count + 1;
        END LOOP;
        return v_Stat;
    END User_Table_Timstamps_Query;

	FUNCTION Pipe_User_Table_Timstamps (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN tab_user_table_timstamps PIPELINED
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
        v_Stat      CLOB;
		c_cur  SYS_REFCURSOR;
		v_row rec_user_table_timstamps; -- output row
	BEGIN
		v_stat := custom_changelog_gen.User_Table_Timstamps_Query(p_Table_Name);
		if DBMS_LOB.GETLENGTH(v_Stat) > 1 then 
			OPEN c_cur FOR v_stat;
			loop
				FETCH c_cur INTO v_row;
				EXIT WHEN c_cur%NOTFOUND;
				PIPE ROW(v_row);
			end loop;
			CLOSE c_cur;
		end if;
		RETURN;
	END Pipe_User_Table_Timstamps;

    PROCEDURE  Gen_VUSER_TABLE_TIMSTAMPS
    IS
        v_Stat      CLOB;
        v_SQLCODE   INTEGER;
        v_Count		INTEGER := 0;
    BEGIN
		DBMS_OUTPUT.PUT_LINE('-- Gen_VUSER_TABLE_TIMSTAMPS --');
		v_Stat := 'CREATE OR REPLACE VIEW ' || changelog_conf.Get_View_Schema
		|| 'VUSER_TABLE_TIMSTAMPS (TABLE_NAME, ID, RID, LAST_MODIFIED_AT , LAST_MODIFIED_BY, WORKSPACE$_ID, DML$_ACTION) AS '|| CHR(10)
		|| 'SELECT TABLE_NAME, ID, RID, LAST_MODIFIED_AT , LAST_MODIFIED_BY, WORKSPACE$_ID, DML$_ACTION' || CHR(10)
		|| 'FROM TABLE(custom_changelog_gen.Pipe_User_Table_Timstamps)';
        Run_Stat (v_Stat);
    END Gen_VUSER_TABLE_TIMSTAMPS;

    FUNCTION  Gen_Custom_AddLog
    RETURN VARCHAR2
    IS
        stat_cur            SYS_REFCURSOR;
        v_Stat1             VARCHAR2(4000);
        v_Declare           VARCHAR2(4000);
        v_Parameter			VARCHAR2(30000);
    BEGIN

        FOR  stat_cur IN (
			SELECT 'p_' || COLUMN_NAME || ' IN ' || custom_changelog.Get_ChangeLogTable || '.' || CHANGELOG_NAME || '%TYPE DEFAULT NULL' || CONT_STAT DECLARE_STAT,
				'p_' || CHANGELOG_NAME || ' => p_' || COLUMN_NAME || CONT_STAT PARAMETER_STAT
			FROM (
				SELECT T.TABLE_NAME, C.COLUMN_NAME, 'CUSTOM_REF_ID' || T.R CHANGELOG_NAME, T.R RUN_NO,
					CASE WHEN LEAD(C.COLUMN_NAME) OVER (ORDER BY T.R) IS NOT NULL THEN ', ' END CONT_STAT
				FROM (SELECT N.COLUMN_VALUE TABLE_NAME, ROWNUM R FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ChangeLogFKeyTables, ',') ) N) T
				JOIN (SELECT N.COLUMN_VALUE COLUMN_NAME, ROWNUM R  FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ChangeLogFKeyColumns, ',') ) N) C ON T.R = C.R -- same position in the list
			)
            ORDER BY RUN_NO
        )
        LOOP
            v_Declare := v_Declare  || RPAD(' ', 4) || stat_cur.DECLARE_STAT || chr(10);
            v_Parameter := v_Parameter || RPAD(' ', 8) || stat_cur.PARAMETER_STAT || chr(10);
        END LOOP;
        return
        'CREATE OR REPLACE PROCEDURE ' || custom_changelog.Get_ChangeLogFunction || ' (' || NL(4)
		|| 'p_Table_Name 	IN VARCHAR2,' || NL(4)
		|| 'p_Object_ID  	IN ' || custom_changelog.Get_ChangeLogTable || '.OBJECT_ID%TYPE,' || NL(4)
		|| 'p_Deleted_Mark 	IN VARCHAR2 DEFAULT NULL,' || NL(4)
		|| 'p_InsertDate 	IN TIMESTAMP DEFAULT SYSTIMESTAMP,' || NL(4)
		|| 'p_WORKSPACE_ID 	IN ' || custom_changelog.Get_ChangeLogTable || '.WORKSPACE$_ID%TYPE DEFAULT NULL,' || chr(10)
		|| v_Declare
		|| ')' || chr(10)
		|| 'IS' || chr(10)
		|| 'BEGIN' || NL(4)
		|| 'custom_changelog.AddLog (' || NL(8)
		|| 'p_Table_Name    => p_Table_Name,' || NL(8)
		|| 'p_Object_ID     => p_Object_ID,' || NL(8)
		|| 'p_Deleted_Mark  => p_Deleted_Mark,' || NL(8)
		|| 'p_InsertDate    => p_InsertDate,' || NL(8)
		|| 'p_WORKSPACE_ID  => p_WORKSPACE_ID,' || chr(10)
		|| v_Parameter || RPAD(' ', 4)
		|| ');' || chr(10)
		|| 'END;'
		;
    END Gen_Custom_AddLog;

	-- Creates an compound trigger for base_tables
    FUNCTION  ChangeLog_Base_Trigger (
        p_View_Name     IN VARCHAR2,
        p_Table_Name    IN VARCHAR2,
		p_Trigger_Name 	IN VARCHAR2,
        p_Short_Name	IN VARCHAR2,
        p_Primary_Key_Cond IN VARCHAR2,
        p_Rang          IN INTEGER,
        p_Foreign_Key_Col IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2,
        p_Sequence_Name  IN VARCHAR2,
        p_Has_Workspace_Id IN VARCHAR2,
        p_Has_Delete_Mark IN VARCHAR2,
		p_Column_CreDate	IN VARCHAR2,
		p_Column_CreUser	IN VARCHAR2,
		p_Column_ModDate	IN VARCHAR2,
		p_Column_ModUser	IN VARCHAR2
    )
    RETURN CLOB
    IS
        stat_cur            SYS_REFCURSOR;
        v_Stat1             VARCHAR2(4000);
        v_Cols              VARCHAR2(4000);
        v_Values			VARCHAR2(32767);
        v_Stat              CLOB;
        v_Table_Name        VARCHAR2(50);
        v_Short_Name        VARCHAR2(50);
        v_Quoted_Name       VARCHAR2(50);
        v_Trigger_Name      VARCHAR2(50);
        v_Key_Name          VARCHAR2(50);
        v_Insert_Trigger	VARCHAR2(32767);
        v_Update_Trigger	VARCHAR2(32767);
        CURSOR Calls_cur -- tracked columns for custom_changelog
        IS
			SELECT DISTINCT
				T.TABLE_NAME, C.COLUMN_NAME, C.DATA_TYPE,  C.DATA_SCALE, C.COLUMN_ID,
				custom_changelog.Get_ChangeLogAddColFunction(C.DATA_TYPE, C.DATA_SCALE, C.CHAR_LENGTH, C.COLUMN_NAME) || '(' ||
				C.COLUMN_ID || ', ' ||
				':OLD.' || C.COLUMN_NAME || ', ' ||
				':NEW.' || C.COLUMN_NAME || ');' STATMENT
			FROM (
				SELECT T.TABLE_NAME
				FROM USER_TABLES T
				WHERE T.TABLE_NAME NOT LIKE 'DR$%$_'  -- skip  fulltext index
				AND T.IOT_NAME IS NULL	-- skip overflow tables of index organized tables
				AND T.TEMPORARY = 'N'
				AND T.SECONDARY = 'N'
				AND T.NESTED = 'NO'
				AND NOT EXISTS (
					SELECT 'X'
					FROM USER_MVIEWS MV
					WHERE MV.MVIEW_NAME = T.TABLE_NAME
				)
			) T
			JOIN (
				SELECT C.TABLE_NAME, C.DATA_TYPE, C.DATA_SCALE, C.CHAR_LENGTH, C.COLUMN_ID,
					custom_changelog.Enquote_Column_Name(C.COLUMN_NAME) COLUMN_NAME
				FROM SYS.USER_TAB_COLS C
				WHERE changelog_conf.Match_Column_Pattern(COLUMN_NAME, changelog_conf.Get_ColumnWorkspace_List) = 'NO'
				AND changelog_conf.Match_Column_Pattern(COLUMN_NAME, changelog_conf.Get_ColumnCreateUser_List) = 'NO'
				AND changelog_conf.Match_Column_Pattern(COLUMN_NAME, changelog_conf.Get_ColumnCreateDate_List) = 'NO'
				AND changelog_conf.Match_Column_Pattern(COLUMN_NAME, changelog_conf.Get_ColumnModifyUser_List) = 'NO'
				AND changelog_conf.Match_Column_Pattern(COLUMN_NAME, changelog_conf.Get_ColumnModifyDate_List) = 'NO'
				AND NOT EXISTS (
					SELECT 'X'
					FROM TABLE( changelog_conf.in_list(custom_changelog.Get_ExcludeChangeLogCols, ',') ) N
					WHERE C.COLUMN_NAME LIKE N.COLUMN_VALUE ESCAPE '\'
				)
				AND C.DATA_TYPE NOT IN ('BLOB','CLOB', 'NCLOB', 'LONG', 'ORDIMAGE')
				AND C.DATA_TYPE_OWNER IS NULL
				AND C.VIRTUAL_COLUMN = 'NO'
				AND C.HIDDEN_COLUMN = 'NO'
			) C ON T.TABLE_NAME = C.TABLE_NAME
			WHERE T.TABLE_NAME = p_Table_Name
			AND C.COLUMN_NAME <> p_Primary_Key_Col
			ORDER BY C.COLUMN_ID;
        TYPE calls_tbl IS TABLE OF Calls_cur%ROWTYPE;
        v_calls_tbl    calls_tbl;
		CURSOR References_cur
		IS
            SELECT ', p_' || T_COLUMN_NAME || '=>:NEW.' || S_COLUMN_NAME REF_PARAM_NEW,
            	', p_' || T_COLUMN_NAME || '=>:OLD.' || S_COLUMN_NAME REF_PARAM_OLD,
            	CONSTRAINT_TYPE, DELETE_RULE
			FROM MVCHANGELOG_REFERENCES
			WHERE S_TABLE_NAME = p_View_Name
            ORDER BY 1;
        TYPE references_tbl IS TABLE OF References_cur%ROWTYPE;
        v_references_tbl    references_tbl;
    BEGIN
    	MView_Refresh('MVCHANGELOG_REFERENCES');

        v_Key_Name  := p_Foreign_Key_Col;
        v_Short_Name := NVL(p_View_Name, changelog_conf.Get_BaseName(p_Table_Name));
        v_Quoted_Name := DBMS_ASSERT.ENQUOTE_LITERAL(v_Short_Name);
        v_Trigger_Name := NVL(p_Trigger_Name, changelog_conf.Get_ChangelogTrigger_Name(v_Short_Name, p_Rang));
        DBMS_OUTPUT.PUT_LINE('-- Int_Add_ChangeLog_Base_Trigger('|| v_Trigger_Name || ', ' || v_Key_Name || ') --');

        OPEN Calls_cur;
        FETCH Calls_cur BULK COLLECT INTO v_calls_tbl;
        CLOSE Calls_cur;

        OPEN References_cur;
        FETCH References_cur BULK COLLECT INTO v_references_tbl;
        CLOSE References_cur;

        IF v_calls_tbl.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_calls_tbl.COUNT
            LOOP
            	v_Cols := v_Cols || ', ' || v_calls_tbl(ind).COLUMN_NAME || case when MOD(ind, 7) = 0 THEN NL(16) end;
            END LOOP;
        END IF;
        v_Cols := LTRIM(v_Cols, ', ');
		if changelog_conf.Get_Database_Version < '12.0' or changelog_conf.Get_Use_On_Null = 'NO' then
			v_Insert_Trigger := changelog_conf.Before_Insert_Trigger_body (
									p_Table_Name => p_Table_Name, 
									p_Primary_Key_Col => p_Primary_Key_Col, 
									p_Has_Serial_Primary_Key => 'YES', 
									p_Sequence_Name => p_Sequence_Name,
									p_Column_CreDate => p_Column_CreDate, 
									p_Column_CreUser => p_Column_CreUser, 
									p_Column_ModDate => p_Column_ModDate, 
									p_Column_ModUser => p_Column_ModUser);
		end if;
		v_Update_Trigger := changelog_conf.Before_Update_Trigger_body ( p_Column_ModDate, p_Column_ModUser);

        -- UPDATE trigger --
        v_Stat := 'CREATE OR REPLACE TRIGGER ' || v_Trigger_Name || chr(10)
        || 'FOR INSERT OR DELETE OR UPDATE ' || CASE WHEN v_Cols IS NOT NULL THEN ' OF ' || v_Cols END || chr(10)
        || 'ON ' || p_Table_Name || ' COMPOUND TRIGGER' || chr(10);
        if v_Insert_Trigger IS NOT NULL OR v_Update_Trigger IS NOT NULL then
			v_Stat := v_Stat
			|| 'BEFORE EACH ROW IS' || chr(10)
			|| 'BEGIN' || chr(10);
			if v_Insert_Trigger IS NOT NULL then
			v_Stat := v_Stat
				|| '  IF INSERTING THEN' || chr(10)
				|| v_Insert_Trigger
				|| '  END IF;' || chr(10);
			end if;
			if v_Update_Trigger IS NOT NULL then
				v_Stat := v_Stat
				|| '  IF UPDATING THEN' || chr(10)
				|| v_Update_Trigger
				|| '  END IF;' || chr(10);
			end if;
			v_Stat := v_Stat
			|| 'END BEFORE EACH ROW;' || chr(10);
		end if;
        v_Stat := v_Stat
        || 'AFTER EACH ROW IS' || chr(10)
        || 'BEGIN' || chr(10)
        || '    CASE WHEN INSERTING OR UPDATING THEN' || NL(8)
		|| custom_changelog.Get_ChangeLogFunction
		|| '(p_Table_Name=>' || v_Quoted_Name
		|| ', p_Object_ID=>:NEW.' || p_Primary_Key_Col
		|| case when p_Column_ModDate IS NOT NULL then ', p_InsertDate=>:NEW.' || p_Column_ModDate end
		|| case when p_Has_Workspace_Id != 'NO' then ' , p_WORKSPACE_ID=>:NEW.' ||  changelog_conf.Get_ColumnWorkspace end;


        IF v_references_tbl.FIRST IS NOT NULL THEN
        	v_Stat := v_Stat || NL(16);
            FOR ind IN 1 .. v_references_tbl.COUNT
            LOOP
            	v_Stat := v_Stat || v_references_tbl(ind).REF_PARAM_NEW;
            END LOOP;
        END IF;

		--	case when v_Key_Name is not null then ', p_' || v_Key_Name || '=>:NEW.' || v_Key_Name end
		if p_Has_Delete_Mark != 'NO' then
			v_Stat := v_Stat
			|| ', p_Deleted_Mark=> :NEW.' || changelog_conf.Get_ColumnDeletedMark;
		end if;
		v_Stat := v_Stat
		|| ');' || chr(10);

        IF v_calls_tbl.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_calls_tbl.COUNT
            LOOP
            	if v_calls_tbl(ind).COLUMN_NAME <> changelog_conf.Get_ColumnDeletedMark then
            		v_Stat := v_Stat || RPAD(' ', 8) || v_calls_tbl(ind).STATMENT || chr(10);
            	end if;
            END LOOP;
        END IF;
        v_Stat := v_Stat
        || '    WHEN DELETING THEN ' || NL(8)
		|| custom_changelog.Get_ChangeLogFunction || '(p_Table_Name=>' || v_Quoted_Name
		|| ', p_Object_ID=>:OLD.' || p_Primary_Key_Col
        || case when p_Has_Workspace_Id != 'NO' then ' , p_WORKSPACE_ID=>:OLD.' ||  changelog_conf.Get_ColumnWorkspace end;

        IF v_references_tbl.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_references_tbl.COUNT
            LOOP
            	if v_references_tbl(ind).CONSTRAINT_TYPE = 'R'
            	and v_references_tbl(ind).DELETE_RULE = 'NO ACTION' -- avoid storing of reference to the deleted row
            	then
            		v_Stat := v_Stat || v_references_tbl(ind).REF_PARAM_OLD;
            	end if;
            END LOOP;
        END IF;

		-- case when v_Key_Name is not null then ', p_' || v_Key_Name || '=>:OLD.' || v_Key_Name end
		v_Stat := v_Stat
		|| ');' || chr(10)
        || '    END CASE;' || NL(4)
        || custom_changelog.Get_ChangeLogFinishFunction || ';'  || chr(10)
        || 'END AFTER EACH ROW;' || chr(10)
        || 'AFTER STATEMENT IS' || chr(10)
        || 'BEGIN' || NL(4)
        || custom_changelog.Get_ChangeLogFlushFunction || ';' || chr(10)
        || 'END AFTER STATEMENT;' || chr(10) || 'END;';

        return v_Stat;
    END ChangeLog_Base_Trigger;

	PROCEDURE Add_ChangeLog_Table_Trigger (
		p_Table_Name        IN VARCHAR2 DEFAULT NULL,
		p_Trigger_Name 		IN VARCHAR2 DEFAULT NULL,
    	p_context   		IN binary_integer DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)
	)
	IS
		v_rindex            binary_integer := dbms_application_info.set_session_longops_nohint;
		v_slno              binary_integer;
		CURSOR view_cur
		IS
			SELECT DISTINCT B.VIEW_NAME, B.TABLE_NAME, B.SHORT_NAME,
				changelog_conf.F_BASE_KEY_COND(B.TABLE_NAME, B.CONSTRAINT_NAME) PRIMARY_KEY_COND,
				case when COUNT(*) OVER (PARTITION BY RTRIM(SUBSTR(B.TABLE_NAME,1,13),'_')) > 1 THEN
					RANK() OVER (PARTITION BY RTRIM(SUBSTR(B.TABLE_NAME,1,13),'_') ORDER BY B.TABLE_NAME)
				end RUN_NO,
				B.CHANGELOG_KEY_COL, B.SCALAR_KEY_COLUMN, B.HAS_SERIAL_PRIMARY_KEY,
				B.SEQUENCE_OWNER, B.SEQUENCE_NAME,
				B.HAS_WORKSPACE_ID, B.HAS_DELETE_MARK,
				B.HAS_CREATE_TIMESTAMP, B.HAS_CREATE_USER, B.HAS_MODFIY_TIMESTAMP, B.HAS_MODFIY_USER,
				CREATE_TIMESTAMP_COLUMN_NAME, CREATE_USER_COLUMN_NAME, MODFIY_TIMESTAMP_COLUMN_NAME, MODFIY_USER_COLUMN_NAME,
				B.INCLUDE_CHANGELOG, B.HAS_SCALAR_KEY,
				CASE WHEN B.INCLUDE_CHANGELOG = 'YES' AND B.HAS_SCALAR_KEY = 'YES'
					AND BUT.TRIGGER_NAME IS NOT NULL THEN
						'DROP TRIGGER ' || changelog_conf.Get_BuTrigger_Name(B.SHORT_NAME)
				END
				AS DROP_BU_TRIGGER,
				BUT.TRIGGER_NAME BU_TRIGGER_NAME,
				CASE WHEN B.INCLUDE_CHANGELOG = 'YES' AND B.HAS_SCALAR_KEY = 'YES'
					AND BIT.TRIGGER_NAME IS NOT NULL THEN
						'DROP TRIGGER ' || changelog_conf.Get_BiTrigger_Name(B.SHORT_NAME)
				END
				AS DROP_BI_TRIGGER,
				BIT.TRIGGER_NAME BI_TRIGGER_NAME,
				case when B.TABLE_NAME = p_Table_Name 
					then p_Trigger_Name
				end CL_TRIGGER_NAME
			FROM MVBASE_VIEWS B
			LEFT OUTER JOIN (
				SELECT T.TRIGGER_NAME, T.TABLE_NAME
				FROM USER_TRIGGERS T
				WHERE T.BASE_OBJECT_TYPE = 'TABLE'
				AND T.TRIGGER_TYPE = 'BEFORE EACH ROW'
				AND INSTR(T.TRIGGERING_EVENT, 'UPDATE') > 0
			) BUT ON BUT.TABLE_NAME = B.TABLE_NAME AND BUT.TRIGGER_NAME = changelog_conf.Get_BuTrigger_Name(B.SHORT_NAME)
			LEFT OUTER JOIN (
				SELECT T.TRIGGER_NAME, T.TABLE_NAME
				FROM USER_TRIGGERS T
				WHERE T.BASE_OBJECT_TYPE = 'TABLE'
				AND T.TRIGGER_TYPE = 'BEFORE EACH ROW'
				AND INSTR(T.TRIGGERING_EVENT, 'INSERT') > 0
			) BIT ON BIT.TABLE_NAME = B.TABLE_NAME AND BIT.TRIGGER_NAME = changelog_conf.Get_BiTrigger_Name(B.SHORT_NAME)
			WHERE (B.TABLE_NAME = p_Table_Name OR p_Table_Name IS NULL)
			AND B.HAS_SCALAR_KEY = 'YES'
			ORDER BY TABLE_NAME;
		TYPE stat_tbl IS TABLE OF view_cur%ROWTYPE;
		v_stat_tbl      		stat_tbl;
		stat_cur        		SYS_REFCURSOR;
		v_Stat					CLOB;
		v_Delimiter 			VARCHAR2(5) := CHR(10)||'/';
        v_Sequence_Name         VARCHAR2(40);
        v_Sequence_Exists 		VARCHAR2(6);
        v_BI_Trigger_Body 		CLOB;
        v_Steps  				CONSTANT binary_integer := 12;
        v_Proc_Name 			VARCHAR2(128) := 'Add ChangeLog Table Trigger';
	BEGIN
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 0, 'steps');
        custom_changelog.Load_Config;
        changelog_conf.Load_Config;
		DBMS_OUTPUT.PUT_LINE('-- Add_ChangeLog_Table_Trigger started (' || p_Table_Name || ') --');
		if changelog_conf.Get_Use_Change_Log = 'YES'
		AND changelog_conf.Get_Use_Sequences = 'YES' then
			MView_Refresh('MVBASE_UNIQUE_KEYS');
			MView_Refresh('MVBASE_ALTER_UNIQUEKEYS', 'MVBASE_UNIQUE_KEYS');
			MView_Refresh('MVBASE_VIEWS', 'MVBASE_ALTER_UNIQUEKEYS');
			Tables_Add_Serial_Keys(p_Table_Name);
		end if;
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 1, 'steps');
		MView_Refresh('MVBASE_UNIQUE_KEYS');
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 2, 'steps');
		MView_Refresh('MVBASE_ALTER_UNIQUEKEYS', 'MVBASE_UNIQUE_KEYS');
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 3, 'steps');
		MView_Refresh('MVBASE_VIEWS', 'MVBASE_ALTER_UNIQUEKEYS');
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 4, 'steps');
		MView_Refresh('MVCHANGELOG_REFERENCES');
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 5, 'steps');
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_stat_tbl;
		CLOSE view_cur;

		IF v_stat_tbl.FIRST IS NOT NULL THEN
        	-- v_Steps := v_stat_tbl.COUNT;
			if p_Table_Name IS NULL then
				v_Stat := Gen_Custom_AddLog;
				Run_Stat (v_Stat, '/');
			end if;
			FOR ind IN 1 .. v_stat_tbl.COUNT
			LOOP
				DBMS_OUTPUT.PUT_LINE('-- Add_ChangeLog_Table_Trigger (Table_Name : ' || v_stat_tbl(ind).TABLE_NAME
				|| ', Include_Changelog : ' || v_stat_tbl(ind).INCLUDE_CHANGELOG
				|| ', BI_Trigger_Name : ' || v_stat_tbl(ind).BI_TRIGGER_NAME
				|| ', BU_Trigger_Name : ' || v_stat_tbl(ind).BU_TRIGGER_NAME
				|| ') --');
                -- Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, ind, 'trigger');
				changelog_conf.Get_Sequence_Name(v_stat_tbl(ind).SHORT_NAME, v_Sequence_Name, v_Sequence_Exists);
				v_BI_Trigger_Body := changelog_conf.Before_Insert_Trigger_body (
						p_Table_Name => v_stat_tbl(ind).TABLE_NAME,
						p_Primary_Key_Col => v_stat_tbl(ind).SCALAR_KEY_COLUMN,
						p_Has_Serial_Primary_Key => 'YES',
						p_Sequence_Name => NVL(v_stat_tbl(ind).SEQUENCE_NAME, v_Sequence_Name),
						p_Column_CreDate => v_stat_tbl(ind).CREATE_TIMESTAMP_COLUMN_NAME,
						p_Column_CreUser => v_stat_tbl(ind).CREATE_USER_COLUMN_NAME,
						p_Column_ModDate => v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME,
						p_Column_ModUser => v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME
					);

				IF changelog_conf.Get_Use_Change_Log = 'YES'
				AND v_stat_tbl(ind).INCLUDE_CHANGELOG = 'YES' AND v_stat_tbl(ind).HAS_SCALAR_KEY = 'YES' THEN
					-- Compound Trigger for logging DML on base tables
					v_Stat := custom_changelog_gen.ChangeLog_Base_Trigger (
							v_stat_tbl(ind).VIEW_NAME,
							v_stat_tbl(ind).TABLE_NAME,
							v_stat_tbl(ind).CL_TRIGGER_NAME,
							v_stat_tbl(ind).SHORT_NAME,
							v_stat_tbl(ind).PRIMARY_KEY_COND,
							v_stat_tbl(ind).RUN_NO,
							v_stat_tbl(ind).CHANGELOG_KEY_COL,
							v_stat_tbl(ind).SCALAR_KEY_COLUMN,
							NVL(v_stat_tbl(ind).SEQUENCE_NAME, v_Sequence_Name),
							v_stat_tbl(ind).HAS_WORKSPACE_ID,
							v_stat_tbl(ind).HAS_DELETE_MARK,
							v_stat_tbl(ind).CREATE_TIMESTAMP_COLUMN_NAME,
							v_stat_tbl(ind).CREATE_USER_COLUMN_NAME,
							v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME,
							v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME
					);
					Run_Stat (v_Stat, '/');
					IF v_stat_tbl(ind).DROP_BI_TRIGGER IS NOT NULL
					AND INSTR(changelog_conf.Get_TriggerText(v_stat_tbl(ind).TABLE_NAME, v_stat_tbl(ind).BI_TRIGGER_NAME), v_BI_Trigger_Body) > 0 THEN
						Run_Stat (v_stat_tbl(ind).DROP_BI_TRIGGER, '/');
					END IF;
					IF v_stat_tbl(ind).DROP_BU_TRIGGER IS NOT NULL THEN
						Run_Stat (v_stat_tbl(ind).DROP_BU_TRIGGER, '/');
					END IF;
				ELSE
					-- remove base table trigger with reference to Get_ChangeLogFunction
					Drop_ChangeLog_Table_Trigger(v_stat_tbl(ind).TABLE_NAME);
					IF changelog_conf.Get_Use_Audit_Info_Trigger = 'YES' THEN
						if v_stat_tbl(ind).BI_TRIGGER_NAME IS NULL then -- don´t overwrite existing trigger --
							v_Stat := v_BI_Trigger_Body;
							if v_Stat IS NOT NULL then
								v_Stat := 'CREATE OR REPLACE TRIGGER ' || changelog_conf.Get_BiTrigger_Name(v_stat_tbl(ind).SHORT_NAME) || chr(10)
									|| 'BEFORE INSERT ON ' || v_stat_tbl(ind).TABLE_NAME || ' FOR EACH ROW '  || chr(10)
									|| 'BEGIN '  || chr(10)
									|| v_Stat
									|| 'END;' || chr(10);
								Run_Stat (v_Stat, '/');
							end if;
						end if;
						if v_stat_tbl(ind).BU_TRIGGER_NAME IS NULL then -- don´t overwrite existing trigger --
							v_Stat :=  changelog_conf.Before_Update_Trigger_body ( 
								v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME, 
								v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME);
							IF v_Stat IS NOT NULL THEN
								v_Stat := 'CREATE OR REPLACE TRIGGER ' || changelog_conf.Get_BuTrigger_Name(v_stat_tbl(ind).SHORT_NAME) || chr(10)
									|| 'BEFORE UPDATE ON ' || v_stat_tbl(ind).TABLE_NAME || ' FOR EACH ROW' || chr(10)
									|| 'BEGIN' || chr(10)
									|| v_Stat
									|| 'END;' || chr(10);
								Run_Stat (v_Stat, '/');
							END IF;
						end if;
					END IF;
				END IF;
			END LOOP;
			Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 6, 'steps');
			if p_Table_Name IS NULL then
				Drop_ChangeLog_Foreign_Keys;
				Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 7, 'steps');
				custom_changelog.Purge_Changelog_Rows;
				Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 8, 'steps');
				if changelog_conf.Get_Use_Change_Log = 'YES' then
					Add_ChangeLog_Foreign_Keys;
				end if;
				Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 9, 'steps');
				Gen_VPROTOCOL_Views;
				Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 10, 'steps');
				Gen_VUSER_TABLE_TIMSTAMPS;
			end if;
			Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, 11, 'steps');
		END IF;
		custom_changelog.Changelog_Tables_Init;
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
	END Add_ChangeLog_Table_Trigger;

	PROCEDURE Refresh_ChangeLog_Trigger (
		p_Table_Name        IN VARCHAR2 DEFAULT NULL,
    	p_context        	IN  binary_integer DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)
	)
	IS
		v_Name_Pattern VARCHAR2(50) := changelog_conf.Get_ChangelogTrigger_Name('%');
	begin
		for cur in (
			select T.TABLE_NAME, S.LAST_DDL_TIME TABLE_LAST_DDL_TIME,
				T.TRIGGER_NAME, U.LAST_DDL_TIME, U.STATUS
			from USER_OBJECTS S
			join USER_TRIGGERS T on S.OBJECT_NAME = T.TABLE_NAME
			join USER_OBJECTS U on U.OBJECT_NAME = T.TRIGGER_NAME
			where S.OBJECT_TYPE = 'TABLE'
			and U.OBJECT_TYPE = 'TRIGGER'
			and T.BASE_OBJECT_TYPE = 'TABLE'
			and T.ACTION_TYPE = 'PL/SQL'
			and T.TRIGGER_TYPE = 'COMPOUND'
			and T.AFTER_ROW = 'YES'
			and T.TRIGGER_NAME LIKE v_Name_Pattern
			and T.TRIGGERING_EVENT  = 'INSERT OR UPDATE OR DELETE'
			and (S.LAST_DDL_TIME > U.LAST_DDL_TIME or U.STATUS = 'INVALID')
		)
		loop
			Add_ChangeLog_Table_Trigger (
				p_Table_Name => cur.TABLE_NAME, 
				p_Trigger_Name => cur.TRIGGER_NAME,
				p_context => p_context);
		end loop;
	end Refresh_ChangeLog_Trigger;

	FUNCTION Changelog_Is_Active( p_Table_Name VARCHAR2)
	RETURN VARCHAR2 
	IS	v_Result MVBASE_VIEWS.INCLUDE_CHANGELOG%TYPE;
	BEGIN
		SELECT INCLUDE_CHANGELOG
		INTO v_Result
		FROM MVBASE_VIEWS A
		WHERE INCLUDE_CHANGELOG = 'YES' 
    	AND HAS_SCALAR_KEY = 'YES'
    	AND VIEW_NAME = p_Table_Name
    	AND EXISTS (
    		SELECT 1 FROM CHANGE_LOG_TABLES B WHERE B.VIEW_NAME = A.VIEW_NAME AND INCLUDED = 'Y'
    	);
    	RETURN v_Result;
	exception when NO_DATA_FOUND then
		RETURN 'NO';
    END;
    	
	FUNCTION Get_Number_Format_Mask(
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Use_Group_Separator VARCHAR2 DEFAULT 'N')
	RETURN VARCHAR2 DETERMINISTIC
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
        v_Data_Scale CONSTANT PLS_INTEGER := NVL(p_Data_Scale, g_Default_Data_Scale);
        v_Data_Precision CONSTANT PLS_INTEGER := NVL(p_Data_Precision, g_Default_Data_Precision + g_Default_Data_Scale) - v_Data_Scale + 1; -- one char for minus sign
	BEGIN
    	RETURN SUBSTR(
    		case when p_Use_Group_Separator = 'Y' then
				SUBSTR(LPAD('0', CEIL((v_Data_Precision)/3)*4, 'G999'), -(v_Data_Precision+FLOOR((v_Data_Precision-1)/3)) )
			else
				LPAD('0', v_Data_Precision, '9')
			end
			|| case when v_Data_Scale > 0 then RPAD('D', v_Data_Scale+1, '9') end
            , 1, g_Format_Max_Length); -- maximum length 
    END Get_Number_Format_Mask;

    FUNCTION Get_ChangeLogColDataType (
    	p_COLUMN_NAME VARCHAR2,
        p_DATA_TYPE VARCHAR2,
        p_DATA_PRECISION NUMBER,
        p_DATA_SCALE NUMBER,
        p_CHAR_LENGTH NUMBER,
        p_NULLABLE VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    	v_Expression VARCHAR2(400);
    BEGIN
    	v_Expression := CASE WHEN p_NULLABLE = 'Y'
    		THEN 'NULLIF(' || p_COLUMN_NAME || ', chr(1))'
    		ELSE p_COLUMN_NAME
    		END;
        RETURN CASE
		WHEN p_DATA_TYPE = 'RAW' THEN
            'HEXTORAW(' || v_Expression || ')'
        WHEN p_DATA_TYPE = 'FLOAT' THEN
            'FN_TO_NUMBER(' || v_Expression || ', '
            	|| DBMS_ASSERT.ENQUOTE_LITERAL(Get_Number_Format_Mask(g_Default_Data_Precision + g_Default_Data_Scale, g_Default_Data_Scale))
           	    || ', ' || custom_changelog.Get_ChangeLogCurrNumChars
            	|| ')'
        WHEN p_DATA_TYPE = 'NUMBER' and p_Data_Scale > 0 THEN
            'FN_TO_NUMBER(' || v_Expression || ', '
            	|| DBMS_ASSERT.ENQUOTE_LITERAL(Get_Number_Format_Mask(p_Data_Precision, p_Data_Scale))
           	    || ', ' || custom_changelog.Get_ChangeLogCurrNumChars
            	|| ')'
        when p_Data_Type = 'NUMBER' and NULLIF(p_Data_Scale, 0) IS NULL then
            'TO_NUMBER(' || v_Expression || ')'
        WHEN p_DATA_TYPE = 'DATE' THEN
            'TO_DATE(' || v_Expression || ', '
            || DBMS_ASSERT.ENQUOTE_LITERAL(custom_changelog.Get_ChangeLogDateFormat) || ')'
        WHEN p_DATA_TYPE LIKE 'TIMESTAMP%' THEN
            'TO_TIMESTAMP(' || v_Expression || ', '
            || DBMS_ASSERT.ENQUOTE_LITERAL(custom_changelog.Get_ChangeLogTimestampFormat) || ')'
        WHEN p_DATA_TYPE IN ( 'VARCHAR2', 'VARCHAR', 'CHAR' ) THEN
        	'CAST(' || v_Expression || ' AS ' || p_DATA_TYPE || '(' || p_CHAR_LENGTH || '))'
		WHEN p_DATA_TYPE = 'BLOB' THEN 
			'TO_BLOB(' || v_Expression || ')'
		WHEN p_DATA_TYPE IN ('CLOB', 'NCLOB') THEN 
			'TO_CLOB(' || v_Expression || ')'
        ELSE
        	v_Expression
        END;
    END Get_ChangeLogColDataType;

	FUNCTION Int_ChangeLog_Projection (
		p_View_Name IN VARCHAR2,
		p_Primary_Key_Col IN VARCHAR2,
		p_Has_Blob_Columns IN VARCHAR2,
		p_Has_Delete_Mark IN VARCHAR2,
		p_Format IN VARCHAR2 DEFAULT 'CONVERT' -- CONVERT, RAW, HEADER
	) RETURN CLOB
	IS
		v_Result CLOB;
		v_Delimiter VARCHAR2(10) := case when p_Format = 'HEADER' then ':' else ', ' end;
	BEGIN
		FOR stat_cur IN (
			SELECT NL(12)
				|| CASE WHEN B.DATA_TYPE IN ('BLOB', 'CLOB', 'NCLOB', 'ORDIMAGE', 'LONG') THEN 
					case when p_Has_Delete_Mark = 'YES' then 'B.' || B.COLUMN_NAME 
						else custom_changelog_gen.Get_ChangeLogColDataType('NULL', B.DATA_TYPE, NULL, NULL, NULL, 'N')
							|| ' ' || B.COLUMN_NAME 
					end
				WHEN B.COLUMN_NAME IN (
				    CREATE_TIMESTAMP_COLUMN_NAME, CREATE_USER_COLUMN_NAME, MODFIY_TIMESTAMP_COLUMN_NAME, MODFIY_USER_COLUMN_NAME,
					p_Primary_Key_Col, C.S_COLUMN_NAME)
					AND p_Format IN ('CONVERT', 'RAW') THEN
						'A.' || B.COLUMN_NAME
				WHEN p_Format = 'CONVERT' THEN
					-- produce data type and replace surrogate null with real nulls.
					custom_changelog_gen.Get_ChangeLogColDataType(
						'A.' || B.COLUMN_NAME, B.DATA_TYPE, B.DATA_PRECISION, B.DATA_SCALE, B.CHAR_LENGTH, B.NULLABLE)
					|| ' ' || B.COLUMN_NAME
				WHEN p_Format = 'RAW' THEN
					CASE WHEN B.NULLABLE = 'Y'
						THEN 'NULLIF(' || 'A.' || B.COLUMN_NAME || ', chr(1))'
						ELSE 'A.' || B.COLUMN_NAME
					END
				ELSE
					INITCAP(REPLACE(B.COLUMN_NAME, '_', ' '))
				END STAT
			FROM SYS.USER_TAB_COLS B
			JOIN MVBASE_VIEWS T ON T.TABLE_NAME = B.TABLE_NAME
			LEFT OUTER JOIN MVCHANGELOG_REFERENCES C ON B.COLUMN_NAME = C.S_COLUMN_NAME AND B.TABLE_NAME = C.S_TABLE_NAME
			WHERE T.VIEW_NAME = p_View_Name
			AND B.COLUMN_NAME NOT IN (changelog_conf.Get_ColumnWorkspace, changelog_conf.Get_ColumnDeletedMark)
			AND NOT (B.DATA_TYPE IN ('BLOB', 'CLOB', 'NCLOB', 'ORDIMAGE', 'LONG') AND p_Has_Blob_Columns = 'NO')
			AND B.VIRTUAL_COLUMN = 'NO'
			AND B.HIDDEN_COLUMN = 'NO'
			ORDER BY COLUMN_ID
		)
		LOOP
			v_Result := v_Result || stat_cur.STAT || v_Delimiter;
		END LOOP;
		RETURN SUBSTR(v_Result, 1, LENGTH(v_Result) - 2);
	END Int_ChangeLog_Projection;

	FUNCTION ChangeLog_Pivot_Query (
		p_View_Name IN VARCHAR2,
		p_Table_Name IN VARCHAR2,
		p_Primary_Key_Col IN VARCHAR2,
		p_Column_Create_Timestamp  IN VARCHAR2,
		p_Column_Create_User IN VARCHAR2,
		p_Column_Modfiy_Timestamp IN VARCHAR2,
		p_Column_Modfiy_User IN VARCHAR2,
		p_Has_Blob_Columns IN VARCHAR2,
		p_Has_Delete_Mark IN VARCHAR2,
		p_Has_Workspace_ID IN VARCHAR2,
		p_Convert_Data_Types IN VARCHAR2 DEFAULT 'YES'
	) RETURN CLOB
	IS
		v_SelectList CLOB;
		v_SelectList2 CLOB;
		v_Changelog_Key_Col VARCHAR2(4000);
		v_Changelog_Key_Alias VARCHAR2(4000);
		v_Primary_Key_Array apex_t_varchar2;
		v_Primary_Key_Cond VARCHAR2(4000);
	BEGIN
        FOR  stat_cur IN (
            SELECT T_CHANGELOG_NAME KEY_COL,
            	S_COLUMN_NAME KEY_ALIAS
			FROM MVCHANGELOG_REFERENCES
			WHERE S_TABLE_NAME = p_View_Name
			AND S_COLUMN_NAME != p_Primary_Key_Col
        )
        LOOP
            v_Changelog_Key_Col := v_Changelog_Key_Col || ', ' || stat_cur.KEY_COL;
            v_Changelog_Key_Alias := v_Changelog_Key_Alias || ', ' || stat_cur.KEY_ALIAS;
        END LOOP;

        FOR  stat_cur IN (
			SELECT custom_changelog_gen.NL(16)
				|| case when B.COLUMN_NAME = C.S_COLUMN_NAME
					then C.S_COLUMN_NAME
					else 'LAST_VALUE( ' || B.COLUMN_NAME
						|| ' IGNORE NULLS) OVER (PARTITION BY ' || p_Primary_Key_Col
						|| v_Changelog_Key_Alias
						|| ', DML$_GID ORDER BY DML$_LOGGING_DATE'
						|| ' ) ' || B.COLUMN_NAME
					end -- ignore nulls (empty cells) but respect null value surrogates (update t set c = null)
				COL_FUNC
			FROM SYS.USER_TAB_COLS B
			LEFT OUTER JOIN MVCHANGELOG_REFERENCES C ON B.COLUMN_NAME = C.S_COLUMN_NAME AND C.S_TABLE_NAME = B.TABLE_NAME
			WHERE B.TABLE_NAME = p_View_Name
			AND B.COLUMN_NAME NOT IN (changelog_conf.Get_ColumnWorkspace, changelog_conf.Get_ColumnDeletedMark, p_Primary_Key_Col)
			AND B.DATA_TYPE NOT IN ('BLOB', 'CLOB', 'NCLOB', 'ORDIMAGE', 'LONG')
			AND B.VIRTUAL_COLUMN = 'NO'
			AND B.HIDDEN_COLUMN = 'NO'
			ORDER BY B.COLUMN_ID
        )
        LOOP
        	v_SelectList := v_SelectList || case when v_SelectList IS NOT NULL then ', ' end || stat_cur.COL_FUNC;
        END LOOP;
		v_SelectList := v_SelectList || ',' || NL(16)
				|| 'LAST_VALUE( DML$_LOGGING_DATE IGNORE NULLS) OVER (PARTITION BY ' || p_Primary_Key_Col
				|| v_Changelog_Key_Alias || ', DML$_GID ORDER BY DML$_LOGGING_DATE ) DML$_LOGGING_DATE'
				|| ',' || NL(16)
				|| 'LAST_VALUE( DML$_USER_NAME IGNORE NULLS) OVER (PARTITION BY ' || p_Primary_Key_Col
				|| v_Changelog_Key_Alias || ', DML$_GID ORDER BY DML$_LOGGING_DATE ) DML$_USER_NAME';

        FOR  stat_cur IN (
			SELECT custom_changelog_gen.NL(20)
				|| case when B.COLUMN_NAME = C.S_COLUMN_NAME
						then C.T_CHANGELOG_NAME || ' AS ' || C.S_COLUMN_NAME
						else 'MAX('
						|| case when B.NULLABLE = 'N'
								then 'DECODE(COLUMN_ID, ' || B.COLUMN_ID || ', AFTER_VALUE)'
								else 'DECODE(COLUMN_ID, ' || B.COLUMN_ID || ', NVL(AFTER_VALUE, chr(1)))'  -- produce null value surrogates
							end
						|| ') ' || B.COLUMN_NAME
					end
				COL_FUNC
			FROM SYS.USER_TAB_COLS B
			JOIN MVBASE_VIEWS T ON T.TABLE_NAME = B.TABLE_NAME
			LEFT OUTER JOIN MVCHANGELOG_REFERENCES C ON B.COLUMN_NAME = C.S_COLUMN_NAME AND C.S_TABLE_NAME = p_View_Name
			WHERE B.TABLE_NAME = p_Table_Name
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, T.CREATE_TIMESTAMP_COLUMN_NAME) = 'NO'
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, T.CREATE_USER_COLUMN_NAME) = 'NO'
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, T.MODFIY_TIMESTAMP_COLUMN_NAME) = 'NO'
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, T.MODFIY_USER_COLUMN_NAME) = 'NO'
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, changelog_conf.Get_ColumnWorkspace_List) = 'NO'
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, changelog_conf.Get_ColumnDeletedMark_List) = 'NO'
			AND changelog_conf.Match_Column_Pattern(B.COLUMN_NAME, REPLACE(p_Primary_Key_Col, ' ')) = 'NO'
			AND B.DATA_TYPE NOT IN ('BLOB', 'CLOB', 'NCLOB', 'ORDIMAGE', 'LONG')
			AND B.VIRTUAL_COLUMN = 'NO'
			AND B.HIDDEN_COLUMN = 'NO'
			ORDER BY B.COLUMN_ID
        )
        LOOP
        	v_SelectList2 := v_SelectList2 || case when v_SelectList2 IS NOT NULL then ', ' end || stat_cur.COL_FUNC;
        END LOOP;

		if p_Primary_Key_Col IS NOT NULL then
			-- add table alias to ordering columns
			v_Primary_Key_Array := apex_string.split(p_Primary_Key_Col, ', ');
			for c_idx IN 1..v_Primary_Key_Array.count loop
				v_Primary_Key_Cond := v_Primary_Key_Cond
				|| case when c_idx > 1 then ' AND ' end
				|| 'A.' || TRIM(v_Primary_Key_Array(c_idx))
				|| ' = B.' || TRIM(v_Primary_Key_Array(c_idx));
			end loop;
		end if;

		return -- generate projection of all base table columns with datatype conversion and null values
		'SELECT /* convert datatypes */ '
		|| Int_ChangeLog_Projection (
			p_View_Name => p_View_Name,
			p_Primary_Key_Col => p_Primary_Key_Col,
			p_Has_Blob_Columns => p_Has_Blob_Columns,
			p_Has_Delete_Mark => p_Has_Delete_Mark,
			p_Format => case when p_Convert_Data_Types = 'YES' then 'CONVERT' else 'RAW' end
		)
		|| ', ' || NL(12)
		|| 'A.DML$_LOGGING_DATE, A.DML$_USER_NAME, A.DML$_ACTION, A.DML$_IS_HIDDEN' || NL(8)
		|| 'FROM (' || NL(12)
		|| ' SELECT DISTINCT ' || p_Primary_Key_Col || ',' || NL(12)
		|| ' /* Aggregate Updates */'
		|| v_SelectList
		|| ', ' || NL(16)
		|| 'DML$_ACTION, DML$_IS_HIDDEN' || NL(12)
		|| 'FROM (' || NL(16)
		|| 'SELECT X.*, '
		|| 'SUM(CASE WHEN DML$_ACTION = ''I'' THEN 1 ELSE 0 END) OVER (PARTITION BY DML$_TABLE_NAME, ' || p_Primary_Key_Col
		|| v_Changelog_Key_Alias
		|| ' ORDER BY DML$_LOGGING_DATE) DML$_GID ' || NL(16)
		|| '/* Group by last insert */' || NL(12)
		|| '  FROM ( ' || NL(12)
		|| '    SELECT /* pivot of table columns */' || NL(20)
		|| case when p_Column_Create_Timestamp IS NOT NULL then
			'CASE WHEN ACTION_CODE = ''I'' THEN LOGGING_DATE END AS ' || p_Column_Create_Timestamp || ', ' || NL(20)
			end
		|| case when p_Column_Create_User IS NOT NULL then
			'CASE WHEN ACTION_CODE = ''I'' THEN USER_NAME END AS ' || p_Column_Create_User || ', ' || NL(20)
			end
		|| case when p_Column_Modfiy_Timestamp IS NOT NULL then
			case when changelog_conf.Get_Enforce_Not_Null = 'YES' then
				'LOGGING_DATE' else 'CASE WHEN ACTION_CODE = ''U'' THEN LOGGING_DATE END' end
			|| ' AS ' || p_Column_Modfiy_Timestamp || ', ' || NL(20)
			end
		|| case when p_Column_Modfiy_User IS NOT NULL then
			case when changelog_conf.Get_Enforce_Not_Null = 'YES' then
				'USER_NAME' else 'CASE WHEN ACTION_CODE = ''U'' THEN USER_NAME END' end
			|| ' AS ' || p_Column_Modfiy_User || ', ' || NL(20)
			end
		|| 'LOGGING_DATE AS DML$_LOGGING_DATE, ' || NL(20)
		|| 'USER_NAME AS DML$_USER_NAME, ' || NL(20)
		|| 'TABLE_NAME AS DML$_TABLE_NAME,  ' || NL(20)
		|| 'OBJECT_ID AS ' || p_Primary_Key_Col || ', ' || NL(20)
		|| 'ACTION_CODE AS DML$_ACTION' || ', '
		|| 'IS_HIDDEN AS DML$_IS_HIDDEN' || ', '
		|| v_SelectList2
		|| NL(16)
		|| 'FROM VCHANGE_LOG_COLUMNS' || NL(16)
		|| 'WHERE TABLE_NAME = ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_View_Name) || NL(16)
		|| 'GROUP BY LOGGING_DATE, ID, USER_NAME, OBJECT_ID, ACTION_CODE, IS_HIDDEN, TABLE_NAME'
		|| v_Changelog_Key_Col
		|| NL(14)
		|| ') X ' || NL(12)
		|| ')' || NL(8)
		|| ') A'
		|| case when p_Has_Blob_Columns = 'YES' and p_Has_Delete_Mark = 'YES'
		   then
			' JOIN ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name)
			|| ' B ON ' || v_Primary_Key_Cond
			|| case when p_Has_Workspace_ID = 'YES'
				then
				' WHERE B.' || changelog_conf.Get_ColumnWorkspace || ' = ' || changelog_conf.Get_Context_WorkspaceID_Expr
				end
		   end;
	END ChangeLog_Pivot_Query;

	FUNCTION ChangeLog_Query (
		p_View_Name IN VARCHAR2,
		p_Table_Name IN VARCHAR2,
		p_Primary_Key_Col IN VARCHAR2,
		p_Has_Blob_Columns IN VARCHAR2,
		p_Has_Delete_Mark IN VARCHAR2,
		p_Has_Workspace_ID IN VARCHAR2,
		p_Column_Create_Timestamp  IN VARCHAR2,
		p_Column_Create_User IN VARCHAR2,
		p_Column_Modfiy_Timestamp  IN VARCHAR2,
		p_Column_Modfiy_User  IN VARCHAR2,
		p_Tab_Columns IN VARCHAR2,
		p_Source_View_Name IN VARCHAR2
	) RETURN CLOB
	IS
		v_Changelog_Key_Alias VARCHAR2(4000);
	BEGIN
        FOR  stat_cur IN (
            SELECT T_COLUMN_NAME KEY_COL,
            	S_COLUMN_NAME KEY_ALIAS
			FROM MVCHANGELOG_REFERENCES
			WHERE S_TABLE_NAME = p_View_Name
			AND S_COLUMN_NAME != p_Primary_Key_Col
        )
        LOOP
            v_Changelog_Key_Alias := v_Changelog_Key_Alias || ', ' || stat_cur.KEY_ALIAS;
        END LOOP;
		return 'SELECT ' || p_Tab_Columns || ', DML$_ACTION, DML$_IS_HIDDEN' || CHR(10)
		|| 'FROM (' || NL(4)
		|| case when custom_changelog.Get_CopyBeforeImage = 'YES' then
		 	'SELECT '  -- union the current row with the history rows to ensure there will be some output --
			|| case when changelog_conf.Get_ForeignKeyModifyUser = 'YES'
				then
					REPLACE(REPLACE(p_Tab_Columns,
									'B.' || p_Column_Modfiy_User, 'MU.LOGIN_NAME ' || p_Column_Modfiy_User),
									'B.' || p_Column_Create_User, 'CU.LOGIN_NAME ' || p_Column_Create_User)
					|| ', ''U'' DML$_ACTION, ''0'' DML$_IS_HIDDEN' || NL(8)
					|| 'FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_View_Name) || ' B ' || NL(8)
					|| 'LEFT OUTER JOIN ' || changelog_conf.Get_Table_App_Users || ' MU ON B.' || p_Column_Modfiy_User || ' = MU.ID' || NL(8)
					|| case when p_Column_Create_User IS NOT NULL
						then 'LEFT OUTER JOIN ' || changelog_conf.Get_Table_App_Users || ' CU ON B.' || p_Column_Create_User || ' = CU.ID' || NL(8)
						end
				else
					p_Tab_Columns
					|| ', ''U'' DML$_ACTION, ''0'' DML$_IS_HIDDEN, 1 DML$_RANK' || NL(8)
					|| 'FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_View_Name) || ' B ' || NL(8)
				end
			|| 'WHERE NOT EXISTS (' || NL(12)
			|| 'SELECT 1' || NL(12)
			|| 'FROM VCHANGE_LOG C' || NL(12)
			|| 'WHERE C.TABLE_NAME = ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_View_Name) || NL(12)
			|| 'AND C.OBJECT_ID = B.' || p_Primary_Key_Col || NL(12)
			|| ')' || NL(8)
			|| 'UNION ALL '  || NL(8)
		end
		|| 'SELECT '
		|| p_Tab_Columns || ', DML$_ACTION, DML$_IS_HIDDEN' || NL(12)
		|| ', ROW_NUMBER() OVER (PARTITION BY ' || p_Primary_Key_Col
		|| v_Changelog_Key_Alias || ' ORDER BY DML$_LOGGING_DATE DESC) DML$_RANK' || NL(4)
		|| 'FROM '
		|| case when p_Source_View_Name IS NOT NULL
			-- the p_Source_View_Name defines the custom_changelog.ChangeLog_Pivot_Query
			then changelog_conf.Get_View_Schema || DBMS_ASSERT.ENQUOTE_NAME(p_Source_View_Name)
			else
				'(' || ChangeLog_Pivot_Query (
							p_View_Name, p_Table_Name, p_Primary_Key_Col,
							p_Column_Create_Timestamp, p_Column_Create_User,
							p_Column_Modfiy_Timestamp, p_Column_Modfiy_User,
							p_Has_Blob_Columns, p_Has_Delete_Mark, p_Has_Workspace_ID)
				|| NL(6)|| ')'
			end
		|| ' B WHERE DML$_LOGGING_DATE <= custom_changelog.Get_Query_Timestamp' || CHR(10)
		|| ') B WHERE DML$_RANK = 1 ' || chr(10);
	END ChangeLog_Query;

	FUNCTION Get_Record_History_Query (
		p_Table_Name VARCHAR2, 
		p_Key_Item_Name VARCHAR2 DEFAULT 'a'
	) RETURN VARCHAR2	-- LOGGING_DATE, USER_NAME, TABLE_NAME, FIELD_NAME, FIELD_VALUE
	IS 
		v_Query VARCHAR2(32767);
		v_Custom_Ref_Column VARCHAR2(128);
	BEGIN
		if p_Table_Name IS NOT NULL then 
			v_Custom_Ref_Column := changelog_conf.Get_ChangeLog_Custom_Ref(p_Table_Name => p_Table_Name);
			v_Query := 'SELECT LOGGING_DATE, USER_NAME_INITCAP USER_NAME, ACTION_NAME||chr(32)||TABLE_NAME_INITCAP TABLE_NAME, FIELD_NAME, FIELD_VALUE' || chr(10) 
			|| 'FROM VCHANGE_LOG_FIELDS WHERE ';
			if v_Custom_Ref_Column IS NOT NULL then 
				v_Query := v_Query || v_Custom_Ref_Column || ' = :' || p_Key_Item_Name;
			else
				v_Query := v_Query || 'TABLE_NAME = ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name) || ' AND OBJECT_ID = :' || p_Key_Item_Name;
			end if;
			v_Query := v_Query || ' ORDER BY LOGGING_TIMESTAMP DESC, USER_NAME, TABLE_NAME';
		else -- enable APEX the validate the query
			v_Query := q'[SELECT LOCALTIMESTAMP LOGGING_DATE, SYS_CONTEXT('APEX$SESSION','APP_USER') USER_NAME, NULL TABLE_NAME, NULL FIELD_NAME, NULL FIELD_VALUE from dual]';
		end if;
		return v_Query;
	END;
/*
	for all tables with the attribute INCLUDE_CHANGELOG = 'YES'
	a view named (BASE_TABLE)_CL is generated.
	This views will deliver all versions with different modification Date (CHANGED_AT)
*/

	FUNCTION ChangeLog_Pivot_Header (
		p_Table_Name IN VARCHAR2
	) RETURN CLOB
	IS
        CURSOR view_cur IS
		SELECT A.VIEW_NAME, A.TABLE_NAME, A.SCALAR_KEY_COLUMN,
			A.HAS_BLOB_COLUMNS, A.HAS_DELETE_MARK
		FROM MVBASE_VIEWS A
		WHERE INCLUDE_CHANGELOG = 'YES'
		AND HAS_SCALAR_KEY = 'YES'
		AND VIEW_NAME IS NOT NULL
		AND (TABLE_NAME = p_Table_Name)
		ORDER BY TABLE_NAME;
        TYPE stat_tbl IS TABLE OF view_cur%ROWTYPE;
        v_stat_tbl      stat_tbl;
		v_header		CLOB;
	BEGIN
        OPEN view_cur;
        FETCH view_cur BULK COLLECT INTO v_stat_tbl;
        CLOSE view_cur;

        IF v_stat_tbl.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_stat_tbl.COUNT
            LOOP
				v_header := Int_ChangeLog_Projection (
					p_View_Name => v_stat_tbl(ind).VIEW_NAME,
					p_Primary_Key_Col => v_stat_tbl(ind).SCALAR_KEY_COLUMN,
					p_Has_Blob_Columns => v_stat_tbl(ind).HAS_BLOB_COLUMNS,
					p_Has_Delete_Mark => v_stat_tbl(ind).HAS_DELETE_MARK,
					p_Format =>'HEADER'
				)
				|| INITCAP(REPLACE(':DML$_LOGGING_DATE:DML$_USER_NAME:DML$_ACTION:DML$_IS_HIDDEN', '_', ' '))
				;
               	return (v_header);
            END LOOP;
        END IF;
        RETURN NULL;
	END ChangeLog_Pivot_Header;

	FUNCTION ChangeLog_Pivot_Query (	-- External
		p_Table_Name IN VARCHAR2,
		p_Convert_Data_Types IN VARCHAR2 DEFAULT 'YES',
		p_Compact_Queries IN VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB
	IS
        CURSOR view_cur IS
		SELECT VIEW_NAME, TABLE_NAME, SCALAR_KEY_COLUMN,
			HAS_BLOB_COLUMNS, HAS_DELETE_MARK,
			custom_changelog.Get_HistoryViewName(SHORT_NAME) AS VIEW_NAME_HS,
			HAS_CREATE_TIMESTAMP, HAS_CREATE_USER, HAS_MODFIY_TIMESTAMP, HAS_MODFIY_USER, HAS_WORKSPACE_ID,
			CREATE_TIMESTAMP_COLUMN_NAME, CREATE_USER_COLUMN_NAME, MODFIY_TIMESTAMP_COLUMN_NAME, MODFIY_USER_COLUMN_NAME
		FROM MVBASE_VIEWS A
		WHERE INCLUDE_CHANGELOG = 'YES'
		AND HAS_SCALAR_KEY = 'YES'
		AND VIEW_NAME = p_Table_Name
		ORDER BY TABLE_NAME;
        TYPE stat_tbl IS TABLE OF view_cur%ROWTYPE;
        v_stat_tbl      stat_tbl;
		v_query 		CLOB;
	BEGIN
		g_Generate_Compact_Queries := p_Compact_Queries;
		-- MView_Refresh('MVBASE_ALTER_UNIQUEKEYS');
		-- MView_Refresh('MVBASE_VIEWS', 'MVBASE_ALTER_UNIQUEKEYS');

        OPEN view_cur;
        FETCH view_cur BULK COLLECT INTO v_stat_tbl;
        CLOSE view_cur;

        IF v_stat_tbl.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_stat_tbl.COUNT
            LOOP
 		        v_query := ChangeLog_Pivot_Query (
 		        		v_stat_tbl(ind).VIEW_NAME,
 		        		v_stat_tbl(ind).TABLE_NAME,
 		        		v_stat_tbl(ind).SCALAR_KEY_COLUMN,
						v_stat_tbl(ind).CREATE_TIMESTAMP_COLUMN_NAME,
						v_stat_tbl(ind).CREATE_USER_COLUMN_NAME,
						v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME,
						v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME,
						v_stat_tbl(ind).HAS_BLOB_COLUMNS,
						v_stat_tbl(ind).HAS_WORKSPACE_ID,
						p_Convert_Data_Types);
               	return (v_query);
            END LOOP;
        END IF;
        RETURN NULL;
	END ChangeLog_Pivot_Query;

	FUNCTION ChangeLog_Query (
		p_Table_Name IN VARCHAR2,
		p_Compact_Queries IN VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB
	IS
        CURSOR view_cur IS
			SELECT DISTINCT VIEW_NAME, TABLE_NAME, SCALAR_KEY_COLUMN,
				HAS_CREATE_TIMESTAMP, HAS_CREATE_USER, HAS_MODFIY_TIMESTAMP, HAS_MODFIY_USER, HAS_WORKSPACE_ID,
				CREATE_TIMESTAMP_COLUMN_NAME, CREATE_USER_COLUMN_NAME, MODFIY_TIMESTAMP_COLUMN_NAME, MODFIY_USER_COLUMN_NAME,
				HAS_BLOB_COLUMNS, HAS_DELETE_MARK, changelog_conf.F_VIEW_COLUMNS(TABLE_NAME, SHORT_NAME, 'B') TAB_COLUMNS,
				custom_changelog.Get_ChangeLogViewName(SHORT_NAME) AS VIEW_NAME_CL,
				custom_changelog.Get_HistoryViewName(SHORT_NAME) AS VIEW_NAME_HS
			FROM MVBASE_VIEWS A
			WHERE INCLUDE_CHANGELOG = 'YES'
			AND HAS_SCALAR_KEY = 'YES'
			AND IS_CANDIDATE_KEY = 'YES'
			AND VIEW_NAME IS NOT NULL
			AND TABLE_NAME = p_Table_Name;
        TYPE stat_tbl IS TABLE OF view_cur%ROWTYPE;
        v_stat_tbl      stat_tbl;
		v_query 		CLOB;
	BEGIN
		g_Generate_Compact_Queries := p_Compact_Queries;

        OPEN view_cur;
        FETCH view_cur BULK COLLECT INTO v_stat_tbl;
        CLOSE view_cur;

        IF v_stat_tbl.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_stat_tbl.COUNT
            LOOP
 		        v_query := ChangeLog_Query (
 		        		p_View_Name 			=> v_stat_tbl(ind).VIEW_NAME,
 		        		p_Table_Name 			=> v_stat_tbl(ind).TABLE_NAME,
 		        		p_Primary_Key_Col 		=> v_stat_tbl(ind).SCALAR_KEY_COLUMN,
						p_Has_Blob_Columns 		=> v_stat_tbl(ind).HAS_BLOB_COLUMNS,
						p_Has_Delete_Mark 		=> v_stat_tbl(ind).HAS_DELETE_MARK,
						p_Has_Workspace_ID 		=> v_stat_tbl(ind).HAS_WORKSPACE_ID,
						p_Column_Create_Timestamp 	=> v_stat_tbl(ind).CREATE_TIMESTAMP_COLUMN_NAME,
						p_Column_Create_User 		=> v_stat_tbl(ind).CREATE_USER_COLUMN_NAME,
						p_Column_Modfiy_Timestamp 	=> v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME,
						p_Column_Modfiy_User 		=> v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME,
						p_Tab_Columns 			=> v_stat_tbl(ind).TAB_COLUMNS,
						p_Source_View_Name 		=> NULL);

               	return (v_query);
            END LOOP;
        END IF;
        RETURN NULL;
	END ChangeLog_Query;

    PROCEDURE Add_ChangeLog_Views (
        p_Table_Name        IN VARCHAR2 DEFAULT NULL,
    	p_context   		IN binary_integer DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)
    )
    IS
		v_query 			CLOB;
        v_rindex            binary_integer := dbms_application_info.set_session_longops_nohint;
        v_slno              binary_integer;
		-- reconstruct historical versions of a base table row --
        CURSOR view_cur IS
			SELECT DISTINCT VIEW_NAME, TABLE_NAME, SCALAR_KEY_COLUMN,
				HAS_CREATE_TIMESTAMP, HAS_CREATE_USER, HAS_MODFIY_TIMESTAMP, HAS_MODFIY_USER, HAS_WORKSPACE_ID,
				CREATE_TIMESTAMP_COLUMN_NAME, CREATE_USER_COLUMN_NAME, MODFIY_TIMESTAMP_COLUMN_NAME, MODFIY_USER_COLUMN_NAME,
				HAS_BLOB_COLUMNS, HAS_DELETE_MARK, changelog_conf.F_VIEW_COLUMNS(TABLE_NAME, SHORT_NAME, 'B') TAB_COLUMNS,
				custom_changelog.Get_ChangeLogViewName(SHORT_NAME) AS VIEW_NAME_CL,
				custom_changelog.Get_HistoryViewName(SHORT_NAME) AS VIEW_NAME_HS
			FROM MVBASE_VIEWS A
			WHERE INCLUDE_CHANGELOG = 'YES'
			AND HAS_SCALAR_KEY = 'YES'
			AND IS_CANDIDATE_KEY = 'YES'
			AND (TABLE_NAME LIKE p_Table_Name OR p_Table_Name IS NULL)
			ORDER BY VIEW_NAME;
        TYPE stat_tbl IS TABLE OF view_cur%ROWTYPE;
        v_stat_tbl      stat_tbl;
        v_Steps  		binary_integer := 0;
        v_Proc_Name 	VARCHAR2(128) := 'Add ChangeLog Views';
    BEGIN
    	MView_Refresh('MVCHANGELOG_REFERENCES');

        OPEN view_cur;
        FETCH view_cur BULK COLLECT INTO v_stat_tbl;
        CLOSE view_cur;

        IF v_stat_tbl.FIRST IS NOT NULL THEN
        	v_Steps := v_stat_tbl.COUNT;
            FOR ind IN 1 .. v_stat_tbl.COUNT
            LOOP
                Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, ind, 'views');
 		        DBMS_OUTPUT.PUT_LINE('-- Add_ChangeLog_Views ' || v_stat_tbl(ind).VIEW_NAME_CL || '--');

 		        v_query := 'CREATE OR REPLACE VIEW ' || changelog_conf.Get_View_Schema
 		        	|| DBMS_ASSERT.ENQUOTE_NAME(v_stat_tbl(ind).VIEW_NAME_HS) || CHR(10)
 		        	|| 'AS '
 		        	|| ChangeLog_Pivot_Query (
 		        		p_View_Name 			=> v_stat_tbl(ind).VIEW_NAME,
 		        		p_Table_Name 			=> v_stat_tbl(ind).TABLE_NAME,
 		        		p_Primary_Key_Col 		=> v_stat_tbl(ind).SCALAR_KEY_COLUMN,
						p_Column_Create_Timestamp 	=> v_stat_tbl(ind).CREATE_TIMESTAMP_COLUMN_NAME,
						p_Column_Create_User 		=> v_stat_tbl(ind).CREATE_USER_COLUMN_NAME,
						p_Column_Modfiy_Timestamp 	=> v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME,
						p_Column_Modfiy_User 		=> v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME,
						p_Has_Blob_Columns 		=> v_stat_tbl(ind).HAS_BLOB_COLUMNS,
						p_Has_Delete_Mark		=> v_stat_tbl(ind).HAS_DELETE_MARK,
						p_Has_Workspace_ID 		=> v_stat_tbl(ind).HAS_WORKSPACE_ID);
 		        Run_Stat (v_query);

 		        v_query := 'CREATE OR REPLACE VIEW ' || changelog_conf.Get_View_Schema
 		        	|| DBMS_ASSERT.ENQUOTE_NAME(v_stat_tbl(ind).VIEW_NAME_CL) || CHR(10)
 		        	|| 'AS '
 		        	|| ChangeLog_Query (
 		        		p_View_Name 			=> v_stat_tbl(ind).VIEW_NAME,
 		        		p_Table_Name 			=> v_stat_tbl(ind).TABLE_NAME,
 		        		p_Primary_Key_Col 		=> v_stat_tbl(ind).SCALAR_KEY_COLUMN,
						p_Has_Blob_Columns 		=> v_stat_tbl(ind).HAS_BLOB_COLUMNS,
						p_Has_Delete_Mark		=> v_stat_tbl(ind).HAS_DELETE_MARK,
						p_Has_Workspace_ID 		=> v_stat_tbl(ind).HAS_WORKSPACE_ID,
						p_Column_Create_Timestamp 	=> v_stat_tbl(ind).CREATE_TIMESTAMP_COLUMN_NAME,
						p_Column_Create_User 		=> v_stat_tbl(ind).CREATE_USER_COLUMN_NAME,
						p_Column_Modfiy_Timestamp 	=> v_stat_tbl(ind).MODFIY_TIMESTAMP_COLUMN_NAME,
						p_Column_Modfiy_User 		=> v_stat_tbl(ind).MODFIY_USER_COLUMN_NAME,
						p_Tab_Columns 			=> v_stat_tbl(ind).TAB_COLUMNS,
						p_Source_View_Name 		=> v_stat_tbl(ind).VIEW_NAME_HS);
               	Run_Stat (v_query);
            END LOOP;
        END IF;
	exception
	  when others then
		Set_Process_Infos(v_rindex, v_slno, v_Proc_Name, p_context, v_Steps, v_Steps, 'steps');
		raise;
    END Add_ChangeLog_Views;

    PROCEDURE Drop_ChangeLog_Views (
        p_Table_Name        IN VARCHAR2 DEFAULT NULL
    )
    IS
        CURSOR view_cur2 IS
			SELECT DISTINCT A.VIEW_NAME,
				(
					SELECT 'DROP VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(T.OBJECT_NAME) STAT
					FROM USER_OBJECTS T
					WHERE T.OBJECT_TYPE = 'VIEW'
					AND T.OBJECT_NAME LIKE A.SHORT_NAME || '%' || custom_changelog.Get_ChangeLogViewExt
					AND ROWNUM = 1
				) AS DROP_VIEW_CL,
				(
					SELECT 'DROP VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(T.OBJECT_NAME) STAT
					FROM USER_OBJECTS T
					WHERE T.OBJECT_TYPE = 'VIEW'
					AND T.OBJECT_NAME LIKE A.SHORT_NAME || '%' || custom_changelog.Get_HistoryViewExt
					AND ROWNUM = 1
				) AS DROP_VIEW_HS
			FROM MVBASE_VIEWS A
			WHERE EXISTS (
				SELECT 1
				FROM USER_OBJECTS T
				WHERE T.OBJECT_TYPE = 'VIEW'
				AND T.OBJECT_NAME LIKE A.SHORT_NAME || '%' || custom_changelog.Get_ChangeLogViewExt
			)
			AND (TABLE_NAME = p_Table_Name OR p_Table_Name IS NULL)
			ORDER BY VIEW_NAME;
        TYPE stat_tbl2 IS TABLE OF view_cur2%ROWTYPE;
        v_stat_tbl2      stat_tbl2;
    BEGIN
        OPEN view_cur2;
        FETCH view_cur2 BULK COLLECT INTO v_stat_tbl2;
        CLOSE view_cur2;


        IF v_stat_tbl2.FIRST IS NOT NULL THEN
            FOR ind IN 1 .. v_stat_tbl2.COUNT
            LOOP
            	if v_stat_tbl2(ind).DROP_VIEW_CL IS NOT NULL then
               		Try_Run_Stat (v_stat_tbl2(ind).DROP_VIEW_CL);
               	end if;
               	if v_stat_tbl2(ind).DROP_VIEW_HS IS NOT NULL then
               		Try_Run_Stat (v_stat_tbl2(ind).DROP_VIEW_HS);
               	end if;
            END LOOP;
        END IF;

    END Drop_ChangeLog_Views;
    
	PROCEDURE Prepare_Tables (
    	p_context  IN binary_integer DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)
    )
	IS
	BEGIN
		if changelog_conf.Get_Use_Change_Log = 'YES'
		OR changelog_conf.Get_Use_Audit_Info_Columns = 'YES' then
			custom_changelog_gen.Drop_ChangeLog_Table_Trigger;
			custom_changelog_gen.Add_ChangeLog_Table_Trigger(p_context => p_context);
		else
			custom_changelog_gen.Drop_ChangeLog_Table_Trigger;
		end if;
		if changelog_conf.Get_Add_ChangeLog_Views = 'YES' then 
			Add_ChangeLog_Views(p_context => p_context);
		else 
			Drop_ChangeLog_Views;
		end if;
	END Prepare_Tables;
end custom_changelog_gen;
/
show errors
/*
set serveroutput on size unlimited
exec custom_changelog_gen.Prepare_Tables;
*/
