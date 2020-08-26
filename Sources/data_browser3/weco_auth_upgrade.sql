


declare
	v_Count PLS_INTEGER;
begin
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_PREFERENCES' and column_name = 'UPDATED';
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PREFERENCES RENAME COLUMN UPDATED TO LAST_MODIFIED_AT';
	end if;
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_PREFERENCES' and column_name = 'UPDATED_BY';
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PREFERENCES RENAME COLUMN UPDATED_BY TO LAST_MODIFIED_BY';
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PREFERENCES MODIFY LAST_MODIFIED_AT TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP';
	end if;
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_PREFERENCES' and column_name = 'CREATED';
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PREFERENCES RENAME COLUMN CREATED TO CREATED_AT';
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PREFERENCES MODIFY CREATED_AT TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP';
	end if;
end;
/


declare
	v_Count PLS_INTEGER;
begin
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_PREFERENCES' and column_name = 'SMTP_HOST_ADDRESS';
	if v_Count = 0 then
		EXECUTE IMMEDIATE q'[ALTER TABLE APP_PREFERENCES add (
			SMTP_HOST_ADDRESS			VARCHAR2(255),
			SMTP_HOST_PORT				NUMBER(6) DEFAULT 465,
			SMTP_USERNAME				VARCHAR2(255),
			SMTP_PASSWORD				VARCHAR2(64),
			SMTP_SSL					VARCHAR2(1) DEFAULT '1' NOT NULL CHECK (SMTP_SSL IN ('0','1','2')),
			SMTP_SSL_CONNECT_PLAIN 		VARCHAR2(1) DEFAULT '0' NOT NULL CHECK (SMTP_SSL_CONNECT_PLAIN IN ('0','1')),
			WALLET_PATH					VARCHAR2(255),
			WALLET_PASSWORD				VARCHAR2(64)
		) ]';
	end if;
end;
/

declare
	v_Count PLS_INTEGER;
begin
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_USERS' and column_name = 'SEND_MAIL_REPLY_MESSAGE';
	if v_Count = 0 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_USERS add SEND_MAIL_REPLY_MESSAGE VARCHAR2(1000)';
	end if;
	
	SELECT COUNT(*) INTO v_Count
	from user_triggers where table_name = 'APP_PREFERENCES' and trigger_name = 'APP_PREFERENCES_PWD_TR';
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'DROP TRIGGER APP_PREFERENCES_PWD_TR';
	end if;
	
	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_USERS' and column_name = 'EMAIL_ADDRESS' and nullable = 'N';
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_USERS MODIFY EMAIL_ADDRESS NULL';
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_PROTOCOL' and column_name = 'REMARKS' and CHAR_LENGTH < 4000;
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PROTOCOL MODIFY REMARKS VARCHAR2(4000)';
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'APP_PROTOCOL' and column_name = 'LAST_MODIFIED_BY';
	if v_Count = 1 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PROTOCOL RENAME COLUMN LAST_MODIFIED_BY TO LOGGING_USER';
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PROTOCOL RENAME COLUMN LAST_MODIFIED_AT TO LOGGING_DATE';
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_constraints where table_name = 'APP_PROTOCOL' and constraint_name = 'APP_PROTOCOL_UK';
	if v_Count = 0 then
		EXECUTE IMMEDIATE 'ALTER TABLE APP_PROTOCOL ADD CONSTRAINT APP_PROTOCOL_UK UNIQUE (LOGGING_DATE, LOGGING_USER) USING INDEX';
	end if;
end;
/




create or replace trigger app_preferences_biu
    before insert or update
    on app_preferences
    for each row
begin
    if :new.id is null then
        :new.ID := 1;
    end if;
    if inserting then
        :new.CREATED_AT := LOCALTIMESTAMP;
        :new.CREATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
    end if;
    :new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
    :new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
end app_preferences_biu;
/
