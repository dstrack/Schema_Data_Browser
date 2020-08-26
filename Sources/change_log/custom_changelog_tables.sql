declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'CHANGE_LOG_TABLES';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE CHANGE_LOG_TABLES
		(
			ID              NUMBER(11,0)    NOT NULL,
			TABLE_NAME      VARCHAR2(32)    NOT NULL,
			VIEW_NAME       VARCHAR2(32)    NOT NULL,
			INCLUDED 		VARCHAR2(1)     DEFAULT 'Y' NOT NULL CONSTRAINT CHANGE_LOG_TABLES_INCLUDED_CK CHECK (INCLUDED IN ('Y','N')),
			CONSTRAINT CHANGE_LOG_TABLES_PK PRIMARY KEY (ID),
			CONSTRAINT CHANGE_LOG_TABLES_UK UNIQUE (VIEW_NAME)
		) ORGANIZATION INDEX
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'CHANGE_LOG_TABLES_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE CHANGE_LOG_TABLES_SEQ START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER CHANGE_LOG_TABLES_BI_TR
	BEFORE INSERT ON CHANGE_LOG_TABLES FOR EACH ROW
	BEGIN
		if :new.ID is null then
			SELECT CHANGE_LOG_TABLES_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;

	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'CHANGE_LOG_USERS_BT';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE CHANGE_LOG_USERS_BT
		(
			ID              NUMBER(11,0)    NOT NULL,
			USER_NAME       VARCHAR2(32)    NOT NULL,
			WORKSPACE$_ID   NUMBER(7,0)     NOT NULL,
			CONSTRAINT CHANGE_LOG_USERS_PK PRIMARY KEY (WORKSPACE$_ID, ID),
			CONSTRAINT CHANGE_LOG_USERS_UK UNIQUE (WORKSPACE$_ID, USER_NAME),
			CONSTRAINT CHANGE_LOG_USERS_WSFK FOREIGN KEY (WORKSPACE$_ID) REFERENCES USER_NAMESPACES (WORKSPACE$_ID) ON DELETE CASCADE ENABLE
		) ORGANIZATION INDEX COMPRESS 1
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'CHANGE_LOG_USERS_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE CHANGE_LOG_USERS_SEQ START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	v_stat := q'[
	CREATE OR REPLACE TRIGGER CHANGE_LOG_USERS_BI_TR
	BEFORE INSERT ON CHANGE_LOG_USERS_BT FOR EACH ROW
	BEGIN
		if :new.ID is null then
			SELECT CHANGE_LOG_USERS_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;

	SELECT COUNT(*) INTO v_count
	FROM USER_OBJECTS WHERE OBJECT_NAME = 'CHANGELOG_ITEM_GTYPE'
	AND OBJECT_TYPE = 'TYPE';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TYPE CHANGELOG_ITEM_GTYPE AS OBJECT (
			COLUMN_ID           NUMBER(3,0),
			AFTER_VALUE         VARCHAR2(400)
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE TYPE CHANGELOG_ITEM_ARRAY_GTYPE AS VARYING ARRAY (1000) OF CHANGELOG_ITEM_GTYPE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'CHANGE_LOG_BT';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE CHANGE_LOG_BT
		(
			ID              NUMBER(11,0)    NOT NULL,
			TABLE_ID        NUMBER(11,0)    NOT NULL,
			OBJECT_ID       NUMBER DEFAULT 0  NOT NULL,
			ACTION_CODE     CHAR(1 BYTE) DEFAULT 'I' CONSTRAINT CHANGELOG_ACTION_CK CHECK (ACTION_CODE IN ('I', 'U', 'D', 'S')) NOT NULL,
			IS_HIDDEN       CHAR(1 BYTE) DEFAULT '0' CONSTRAINT CHANGELOG_IS_HIDDEN_CK CHECK (IS_HIDDEN IN ('0', '1')) NOT NULL,
			USER_ID         NUMBER(11,0)    NOT NULL,
			LOGGING_DATE    TIMESTAMP(6) WITH LOCAL TIME ZONE NOT NULL,
			CUSTOM_REF_ID1  NUMBER(11,0),
			CUSTOM_REF_ID2  NUMBER(11,0),
			CUSTOM_REF_ID3  NUMBER(11,0),
			CUSTOM_REF_ID4  NUMBER(11,0),
			CUSTOM_REF_ID5  NUMBER(11,0),
			CUSTOM_REF_ID6  NUMBER(11,0),
			CUSTOM_REF_ID7  NUMBER(11,0),
			CUSTOM_REF_ID8  NUMBER(11,0),
			CUSTOM_REF_ID9  NUMBER(11,0),
			CHANGELOG_ITEMS  CHANGELOG_ITEM_ARRAY_GTYPE,
			WORKSPACE$_ID   NUMBER(7,0) NOT NULL,
			CONSTRAINT CHANGELOG_PK PRIMARY KEY (WORKSPACE$_ID, LOGGING_DATE, ID) USING INDEX COMPRESS,
			CONSTRAINT CHANGELOG_WSFK FOREIGN KEY (WORKSPACE$_ID) REFERENCES USER_NAMESPACES (WORKSPACE$_ID) ON DELETE CASCADE ENABLE,
			CONSTRAINT CHANGELOG_USER_FK FOREIGN KEY (WORKSPACE$_ID, USER_ID) REFERENCES CHANGE_LOG_USERS_BT (WORKSPACE$_ID, ID) ENABLE,
			CONSTRAINT CHANGELOG_TABLE_FK FOREIGN KEY (TABLE_ID) REFERENCES CHANGE_LOG_TABLES (ID) ENABLE
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		COMMENT ON TABLE CHANGE_LOG_BT IS
		'Base table to store change log entries for details of DML changes with one row for each affected individual table column for tracked tables.'
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE INDEX CHANGELOG_IND ON CHANGE_LOG_BT (WORKSPACE$_ID, TABLE_ID, OBJECT_ID, ACTION_CODE) COMPRESS 4
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'CHANGELOG_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE CHANGELOG_SEQ START WITH 1000000 INCREMENT BY 1 NOCACHE NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER CHANGE_LOG_BI_TR
	BEFORE INSERT ON CHANGE_LOG_BT FOR EACH ROW
	BEGIN
		if :new.ID is null then
			SELECT CHANGELOG_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/
show errors
