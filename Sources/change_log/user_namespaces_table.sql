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

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT count(*)  INTO v_count
	from user_tables where table_name = 'USER_NAMESPACES';
	-- Required Table in each schema
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE USER_NAMESPACES (
			WORKSPACE$_ID 		NUMBER(7,0) NOT NULL,
			WORKSPACE_NAME 		VARCHAR2(50 CHAR) NOT NULL,
			WORKSPACE_STATUS	VARCHAR2(10) DEFAULT 'APPROVED' NOT NULL,
			WORKSPACE_TYPE		VARCHAR2(10) DEFAULT 'FREE' NOT NULL,
			TEMPLATE_NAME 		VARCHAR2(50) NULL,
			APPLICATION_GROUP   VARCHAR2(50) NULL,
			APPLICATION_ID 		NUMBER(11,0) NULL,
			EXPIRATION_DATE 	DATE NULL,
			DESCRIPTION			VARCHAR2(1000),
			CREATED_BY			VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL,
			CREATION_DATE       TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL,
			LAST_MODIFIED_BY    VARCHAR2 (32) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ,
			LAST_MODIFIED_AT    TIMESTAMP(6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ,
			CONSTRAINT USER_NAMESPACES_PK PRIMARY KEY (WORKSPACE$_ID),
			CONSTRAINT USER_NAMESPACES_NAME_CK UNIQUE (WORKSPACE_NAME),
			CONSTRAINT USER_NAMESPACES_NAMEUP_CK CHECK (UPPER(WORKSPACE_NAME) = WORKSPACE_NAME),
			CONSTRAINT USER_NAMESPACES_STATUS_CK CHECK (WORKSPACE_STATUS IN ('REQUESTED','APPROVED','DECLINED','EXPIRED','TERMINATED')),
			CONSTRAINT USER_NAMESPACES_TYPE_CK CHECK (WORKSPACE_TYPE IN ('TEMPLATE','FREE TRIAL','COMMERCIAL','FREE','INTERNAL'))
		) ORGANIZATION INDEX
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT count(*)  INTO v_count
	from user_sequences where sequence_name = 'USER_NAMESPACES_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE USER_NAMESPACES_SEQ START WITH 100 INCREMENT BY 1 NOCACHE NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT count(*)  INTO v_count
	from user_triggers where table_name = 'USER_NAMESPACES' and trigger_name = 'USER_NAMESPACES_BI_TR';
	-- Required Table in each schema
	if v_count = 0 then 
		v_stat := q'[
		CREATE OR REPLACE TRIGGER USER_NAMESPACES_BI_TR
		BEFORE INSERT ON USER_NAMESPACES FOR EACH ROW
		BEGIN
			IF :NEW.WORKSPACE$_ID IS NULL THEN
				SELECT USER_NAMESPACES_SEQ.NEXTVAL INTO :NEW.WORKSPACE$_ID FROM DUAL;
			END IF;
		END;
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE OR REPLACE TRIGGER USER_NAMESPACES_BU_TR
		BEFORE UPDATE ON USER_NAMESPACES FOR EACH ROW
		BEGIN
			:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER);
			:new.LAST_MODIFIED_AT   := LOCALTIMESTAMP;
		END;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/
show errors

