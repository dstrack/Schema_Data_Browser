declare
	v_Count PLS_INTEGER;
begin
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'CHANGE_LOG_TABLES' and column_name = 'INCLUDED';
	if v_Count = 0 then
		EXECUTE IMMEDIATE q'[ALTER TABLE CHANGE_LOG_TABLES ADD (
			INCLUDED VARCHAR2(1) DEFAULT 'Y' NOT NULL CONSTRAINT CHANGE_LOG_TABLES_INCLUDED_CK CHECK (INCLUDED IN ('Y','N'))
		)]';
	end if;	
	SELECT COUNT(*) INTO v_Count
	from user_constraints where table_name = 'CHANGE_LOG_BT' and CONSTRAINT_NAME = 'CHANGELOG_ACTION_CK';
	if v_Count = 1 then
		EXECUTE IMMEDIATE q'[ALTER TABLE CHANGE_LOG_BT DROP CONSTRAINT CHANGELOG_ACTION_CK]';
	end if;	
	EXECUTE IMMEDIATE q'[ALTER TABLE CHANGE_LOG_BT ADD CONSTRAINT CHANGELOG_ACTION_CK CHECK (ACTION_CODE IN ('I', 'U', 'D', 'S'))]';
end;
/
	
declare
	CURSOR keys_cur
	IS
	select TABLE_NAME, COLUMN_NAME,
		'ALTER TABLE ' || TABLE_NAME ||' MODIFY (' || COLUMN_NAME 
		|| ' VARCHAR2(32 BYTE) DEFAULT ' 
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
		|| case when DEFAULT_ON_NULL = 'YES' then 'ON NULL ' end 
$END
		|| q'[NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')))]' ALTER_STAT
	from user_tab_columns 
	where DATA_TYPE = 'VARCHAR2'
	and DEFAULT_LENGTH > 10
	and changelog_conf.Get_ColumnDefaultText(TABLE_NAME, COLUMN_NAME) LIKE q'[%SYS_CONTEXT('CUSTOM_CTX', 'USER_NAME')%]';
	TYPE stat_tbl IS TABLE OF keys_cur%ROWTYPE;
	v_stat_tbl stat_tbl;
begin 
	OPEN keys_cur;
	FETCH keys_cur BULK COLLECT INTO v_stat_tbl;
	CLOSE keys_cur;
	IF v_stat_tbl.FIRST IS NOT NULL THEN
		FOR ind IN 1 .. v_stat_tbl.COUNT
		LOOP
			DBMS_OUTPUT.PUT_LINE(v_stat_tbl(ind).ALTER_STAT || ';');
			EXECUTE IMMEDIATE v_stat_tbl(ind).ALTER_STAT;
		END LOOP;
		DBMS_OUTPUT.PUT_LINE('upgraded column ' || v_stat_tbl.COUNT || ' defaults for current user_name');
	END IF;
    
    update CHANGE_LOG_CONFIG set FUNCTION_MODIFY_USER = q'[NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'))]';
    commit;
end;
/

