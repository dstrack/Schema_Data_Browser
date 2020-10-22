declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'APP_USERS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE APP_USERS
		  (
			ID                       NUMBER DEFAULT to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') NOT NULL,
			Login_Name               VARCHAR2 (50 CHAR) NOT NULL,
			First_Name               VARCHAR2 (50 CHAR),
			Last_Name                VARCHAR2 (50 CHAR),
			Password_Hash            VARCHAR2 (64),
			Password_Expiration_Date DATE,
			Password_Reset			 VARCHAR2(1) DEFAULT 'Y' NOT NULL CONSTRAINT APP_USERS_Password_Rese_CK CHECK (PASSWORD_RESET IN ('Y','N')),
			Account_Expiration_Date  DATE,
			Last_Login_Date          DATE,
			EMail_Address            VARCHAR2 (50 CHAR) NULL,
			EMail_Valiation_Token    VARCHAR2 (50 CHAR),
			EMail_Validated          VARCHAR2(1) DEFAULT 'N' NOT NULL CONSTRAINT APP_USERS_EMail_Validat_CK CHECK (EMAIL_VALIDATED IN ('Y','N')),
			Main_Group_Name          VARCHAR2 (50 CHAR),
			Account_Locked           VARCHAR2(1) DEFAULT 'N' NOT NULL CONSTRAINT APP_USERS_Account_Locke_CK CHECK (ACCOUNT_LOCKED IN ('Y','N')),
			User_Level				 NUMBER(3) DEFAULT 3 NOT NULL,
			Language_Code 			 VARCHAR2(10) default 'de' NOT NULL CONSTRAINT APP_USERS_Language_Code_CK CHECK (LANGUAGE_CODE IN ('de','en')),
			CREATED_BY               VARCHAR2 (32) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ,
			CREATED_AT               TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ,
			LAST_MODIFIED_BY         VARCHAR2 (32) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ,
			LAST_MODIFIED_AT         TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ,
			Upper_Login_Name 		 VARCHAR2(50 CHAR) GENERATED ALWAYS AS (TRIM(UPPER("LOGIN_NAME"))) VIRTUAL,
			Send_Mail_Reply_Message  VARCHAR2(1000),
			CONSTRAINT App_Users_PK PRIMARY KEY ( ID ),
			CONSTRAINT App_Users_Login_Name_UN UNIQUE ( UPPER_LOGIN_NAME )
		  ) 
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE OR REPLACE TRIGGER APP_USERS_BU_TR
		BEFORE UPDATE ON APP_USERS FOR EACH ROW
		BEGIN
			:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
			:new.LAST_MODIFIED_AT   := LOCALTIMESTAMP;
		END;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'APP_USER_LEVELS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE APP_USER_LEVELS (
			ID             	NUMBER NOT NULL ,
			Description    	VARCHAR2(128 CHAR) NULL ,
			Remarks      	VARCHAR2(300 CHAR) NULL ,
			CONSTRAINT App_User_Levels_PK PRIMARY KEY(ID),
			CONSTRAINT App_User_Levels_UN UNIQUE ( Description )
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	MERGE INTO APP_USER_LEVELS D
	USING (
		select 0 id, 'Admin' Description, 'Edit Protected Records + Edit Users and Permissions' Remarks from dual union all
		select 1 id, 'Management' Description, 'Edit records + edit user permissions' Remarks from dual union all
		select 2 id, 'Accounting' Description, 'Edit records' Remarks from dual union all
		select 3 id, 'Employees' Description, 'Edit records' Remarks from dual union all
		select 4 id, 'External employee' Description, 'Edit records' Remarks from dual union all
		select 5 id, 'External service provider' Description, 'View records' Remarks from dual union all
		select 6 id, 'Guest' Description, 'View records' Remarks from dual union all
		select 7 id, 'Without permissions' Description, 'Without permissions' Remarks from dual
	) S ON (D.ID = S.ID)
	WHEN MATCHED THEN
		UPDATE SET D.Description = S.Description, D.Remarks = S.Remarks
	WHEN NOT MATCHED THEN
		INSERT (D.ID, D.Description, D.Remarks)
		VALUES (S.ID, S.Description, S.Remarks)
	]';
	EXECUTE IMMEDIATE v_Stat;
	COMMIT;
	SELECT COUNT(*) INTO v_count
	FROM USER_CONSTRAINTS WHERE TABLE_NAME = 'APP_USERS' AND CONSTRAINT_NAME = 'APP_USER_USER_LEVELS_FK';
	if v_count = 0 then 
		v_stat := q'[
		ALTER TABLE APP_USERS ADD CONSTRAINT APP_USER_USER_LEVELS_FK FOREIGN KEY (User_Level) REFERENCES APP_USER_LEVELS (ID)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'APP_USER_LEVELS_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE APP_USER_LEVELS_SEQ START WITH 10 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE OR REPLACE TRIGGER "APP_USER_LEVELS_BI_TR" 
		BEFORE INSERT ON APP_USER_LEVELS FOR EACH ROW 
		BEGIN 
			if :new.ID is null then 
				SELECT APP_USER_LEVELS_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
			end if; 
		END;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
		-- Register APEX_SESSION_ID and WORKSPACE$_ID on Logon of USER_NAME
		-- Enables the filtering of the activity log APEX_WORKSPACE_ACTIVITY_LOG for each WORKSPACE$_ID
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'USER_WORKSPACE_SESSIONS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE USER_WORKSPACE_SESSIONS (
			WORKSPACE$_ID 		NUMBER(7,0) NOT NULL,
			APEX_SESSION_ID		NUMBER NOT NULL,		-- Oracle Application Express session identifier.
			USER_NAME			VARCHAR2(255) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL,
			SESSION_CREATED		DATE DEFAULT SYSTIMESTAMP NOT NULL,
			IP_ADDRESS 			VARCHAR2(255) NULL, 	-- IP address of client.
			CONSTRAINT USER_WORKSPACE_SESSIONS_PK PRIMARY KEY (WORKSPACE$_ID, APEX_SESSION_ID)
		) ORGANIZATION INDEX COMPRESS 1
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	-- used in package set_custom_ctx and data_browser_auth
	v_stat := q'[
	CREATE OR REPLACE VIEW V_CONTEXT_USERS AS
	SELECT ID USER_ID, USER_LEVEL, 
		EMAIL_ADDRESS, EMAIL_VALIDATED, EMAIL_VALIATION_TOKEN, SEND_MAIL_REPLY_MESSAGE,
		LOGIN_NAME, UPPER_LOGIN_NAME, LAST_LOGIN_DATE,
		FIRST_NAME, LAST_NAME, LANGUAGE_CODE,
		PASSWORD_HASH, PASSWORD_RESET, PASSWORD_EXPIRATION_DATE,
		ACCOUNT_EXPIRATION_DATE, ACCOUNT_LOCKED,
		CREATED_BY, CREATED_AT, LAST_MODIFIED_BY, LAST_MODIFIED_AT
	FROM APP_USERS
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/
show errors

