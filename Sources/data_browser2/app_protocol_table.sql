declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'APP_PROTOCOL';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE APP_PROTOCOL (
			ID             	NUMBER DEFAULT to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') NOT NULL ,
			LOGGING_USER VARCHAR2 (32) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL,
			LOGGING_DATE TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ,
			DESCRIPTION    	VARCHAR2(40 CHAR) NULL ,
			REMARKS      	VARCHAR2(4000 CHAR) NULL ,
			CONSTRAINT APP_PROTOCOL_PK PRIMARY KEY(ID),
			CONSTRAINT APP_PROTOCOL_UK UNIQUE (LOGGING_DATE, LOGGING_USER) USING INDEX
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
		-- used in package set_custom_ctx and weco_auth
		v_stat := q'[
		CREATE OR REPLACE VIEW V_ERROR_PROTOCOL (ID, LOGGING_USER, LOGGING_DATE, DESCRIPTION, REMARKS )
		AS
		SELECT ID, LOGGING_USER, LOGGING_DATE, DESCRIPTION, REMARKS
		FROM APP_PROTOCOL
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/
show errors

