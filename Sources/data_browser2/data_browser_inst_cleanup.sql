-- data_browser_install_cleanup --
-- select * from USER_DEPENDENCIES where REFERENCED_NAME LIKE 'SYS_PLSQL%' or NAME  LIKE 'SYS_PLSQL%';
set serveroutput on size unlimited

declare
    v_Count NUMBER;
BEGIN
	DBMS_OUTPUT.PUT_LINE('-- remove objects left behind  --');
	LOOP
		v_Count := 0;
		FOR s_cur IN (
			SELECT 'DROP TYPE ' || OBJECT_NAME  STAT
			FROM USER_OBJECTS WHERE OBJECT_TYPE = 'TYPE' AND OBJECT_NAME LIKE 'SYS_PLSQL%'
		) LOOP
			BEGIN
				EXECUTE IMMEDIATE s_cur.STAT;
			EXCEPTION
			  WHEN OTHERS THEN
				IF SQLCODE != -2303 THEN
					RAISE;
				END IF;
			END;
			v_Count := v_Count + 1;
		END LOOP;
		EXIT WHEN v_Count = 0;
    	DBMS_OUTPUT.PUT_LINE('-- removed ' || v_Count || ' objects --');
	END LOOP;
END;
/

declare
    v_Count NUMBER;
begin 
	data_browser_conf.Compile_Invalid_Objects;
end;
/

purge recyclebin;
