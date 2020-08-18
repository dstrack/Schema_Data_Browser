/*
Copyright 2016 Dirk Strack

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

------------------------------------------------------------------------------
Module for cryptographic encryption of passwords
the so called salt for hashed passwords is stored separated from the app_users.password_hash
in schema CUSTOM_KEYS table SCHEMA_USER_KEYS.
Access to the salt is only possible via the function schema_keychain.Crypto_Key
*/

/*
CONNECT SYS AS SYSDBA
*/

CREATE USER "CUSTOM_KEYS" IDENTIFIED BY "71ck-28jg-X96z"
	PROFILE DEFAULT ACCOUNT LOCK DEFAULT TABLESPACE USERS  TEMPORARY TABLESPACE TEMP;
GRANT RESOURCE TO CUSTOM_KEYS;
GRANT UNLIMITED TABLESPACE TO CUSTOM_KEYS;
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO CUSTOM_KEYS;
-- REVOKE CREATE SESSION FROM CUSTOM_KEYS;
GRANT CREATE PROCEDURE TO CUSTOM_KEYS;
GRANT CREATE PUBLIC SYNONYM TO CUSTOM_KEYS;
GRANT CREATE ANY CONTEXT, CREATE PROCEDURE TO CUSTOM_KEYS;
--ALTER SESSION SET CURRENT_SCHEMA=CUSTOM_KEYS;

/*
DROP TABLE SCHEMA_USER_KEYS;
DROP PACKAGE schema_keychain;
*/

CREATE TABLE CUSTOM_KEYS.SCHEMA_USER_KEYS
(
	SCHEMA_NAME 		VARCHAR2(30) NOT NULL,
	WORKSPACE_NAME		VARCHAR2(30) NOT NULL,
    USER_ID				NUMBER NOT NULL,
	USER_KEY 			RAW(32) NOT NULL,
	CREATED_AT          TIMESTAMP WITH LOCAL TIME ZONE DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT WEMA_USER_KEYS_PK PRIMARY KEY(SCHEMA_NAME, WORKSPACE_NAME, USER_ID)
)
ORGANIZATION INDEX COMPRESS 2;

CREATE OR REPLACE PACKAGE CUSTOM_KEYS.schema_keychain
AUTHID DEFINER -- enable access to SCHEMA_USER_KEYS
IS
	FUNCTION Crypto_Key (
		p_User_Id INTEGER,
		p_Schema_Name VARCHAR2,
		p_Namespace VARCHAR2
	) RETURN RAW;

	PROCEDURE Duplicate_Keys (
		p_Source_Schema VARCHAR2,
		p_Dest_Schema VARCHAR2
	);

	PROCEDURE Synchronize_Keys (
		p_Source_Link VARCHAR2,
		p_Source_Schema VARCHAR2,
		p_Key_Schema VARCHAR2,
		p_Remap_Dest_Schema VARCHAR2 DEFAULT NULL
	);
END schema_keychain;
/
show errors


CREATE OR REPLACE PACKAGE BODY CUSTOM_KEYS.schema_keychain IS
	-- return the crypto_key for the user_id in context of the current Schema and Weco_Ctx.Workspace_Name
	-- negative user_ids can be used for internal communication
	FUNCTION Crypto_Key (
		p_User_Id INTEGER,
		p_Schema_Name VARCHAR2,
		p_Namespace VARCHAR2
	) RETURN RAW
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_User_Key	      RAW(32);
		v_Schema_Name	VARCHAR2(128);
		v_Namespace		VARCHAR2(128);
	BEGIN
		v_Schema_Name := case when p_User_Id >= 0 then p_Schema_Name else 'CUSTOM_KEYS' end;
		v_Namespace := case when p_User_Id >= 0 then p_Namespace else 'SHARED' end;
	
		SELECT USER_KEY
		INTO v_User_Key
		FROM SCHEMA_USER_KEYS
		WHERE SCHEMA_NAME = v_Schema_Name
		AND WORKSPACE_NAME = v_Namespace
		AND USER_ID = p_USER_ID;

		RETURN v_User_Key;
	exception
	when NO_DATA_FOUND then
		INSERT INTO SCHEMA_USER_KEYS (SCHEMA_NAME, WORKSPACE_NAME, USER_ID, USER_KEY)
		VALUES (v_Schema_Name, v_Namespace, p_USER_ID, SYS.DBMS_CRYPTO.RANDOMBYTES(32))
		RETURNING (USER_KEY) INTO v_User_Key;
		COMMIT;
		RETURN v_User_Key;
	END;

	PROCEDURE Duplicate_Keys (
		p_Source_Schema VARCHAR2,
		p_Dest_Schema VARCHAR2
	)
	IS 
	BEGIN 
		MERGE INTO SCHEMA_USER_KEYS D
		USING (
			SELECT p_Dest_Schema SCHEMA_NAME,
		 		WORKSPACE_NAME, USER_ID, USER_KEY
		 	FROM SCHEMA_USER_KEYS
		   WHERE SCHEMA_NAME = p_Source_Schema ) S
		 	ON (D.SCHEMA_NAME = S.SCHEMA_NAME
		 	AND D.WORKSPACE_NAME = S.WORKSPACE_NAME
		 	AND D.USER_ID = S.USER_ID)
		 WHEN MATCHED THEN
		 	UPDATE SET D.USER_KEY = S.USER_KEY
		 WHEN NOT MATCHED THEN
		  	INSERT (D.SCHEMA_NAME, D.WORKSPACE_NAME, D.USER_ID, D.USER_KEY)
		  	VALUES (S.SCHEMA_NAME, S.WORKSPACE_NAME, S.USER_ID, S.USER_KEY);
		COMMIT;
	END;
	
	PROCEDURE Synchronize_Keys (
		p_Source_Link VARCHAR2,
		p_Source_Schema VARCHAR2,
		p_Key_Schema VARCHAR2,
		p_Remap_Dest_Schema VARCHAR2 DEFAULT NULL
	)
	IS
		v_Stat VARCHAR2(1000);
	BEGIN
		v_Stat := 'MERGE INTO ' || p_Key_Schema || '.SCHEMA_USER_KEYS D' || chr(10)
		 || 'USING (' || chr(10)
		 || '	SELECT '
		 || case when p_Remap_Dest_Schema IS NOT NULL then
		 	'REPLACE(SCHEMA_NAME, ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Source_Schema)
		 	|| ', '  || DBMS_ASSERT.ENQUOTE_LITERAL(p_Remap_Dest_Schema) || ')'
		 end
		 || ' SCHEMA_NAME,' || chr(10)
		 || '		WORKSPACE_NAME, USER_ID, USER_KEY' || chr(10)
		 || '	FROM ' || p_Key_Schema || '.SCHEMA_USER_KEYS@' || p_Source_Link || chr(10)
		 || '   WHERE SCHEMA_NAME = :a ) S' || chr(10)
		 || '	ON (D.SCHEMA_NAME = S.SCHEMA_NAME' || chr(10)
		 || '	AND D.WORKSPACE_NAME = S.WORKSPACE_NAME' || chr(10)
		 || '	AND D.USER_ID = S.USER_ID)' || chr(10)
		 || 'WHEN MATCHED THEN' || chr(10)
		 || '	UPDATE SET D.USER_KEY = S.USER_KEY' || chr(10)
		 || ' WHEN NOT MATCHED THEN' || chr(10)
		 || ' 	INSERT (D.SCHEMA_NAME, D.WORKSPACE_NAME, D.USER_ID, D.USER_KEY)' || chr(10)
		 || ' 	VALUES (S.SCHEMA_NAME, S.WORKSPACE_NAME, S.USER_ID, S.USER_KEY)';

		-- DBMS_OUTPUT.PUT_LINE(v_Stat);
		EXECUTE IMMEDIATE v_Stat USING IN p_Source_Schema;
		DBMS_OUTPUT.PUT_LINE('-- copy schema_keychain(' || p_Source_Link || ', ' || p_Source_Schema || ', ' || p_Key_Schema || ') ' || TO_CHAR(SQL%ROWCOUNT) || ' rows');
	END;
END schema_keychain;
/
show errors

/*
-- in each application schema like STRACK_DEV
GRANT EXECUTE ON CUSTOM_KEYS.schema_keychain TO STRACK_DEV;
CREATE OR REPLACE SYNONYM STRACK_DEV.schema_keychain FOR CUSTOM_KEYS.schema_keychain;


DROP DATABASE LINK SCHEMA_SYNC_LINK;

CREATE DATABASE LINK SCHEMA_SYNC_LINK
    CONNECT TO "CUSTOM_KEYS" IDENTIFIED BY "8cxc-Fmf5-63i5"
    USING '(DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.31.4)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = WEMASERV)
    ))';


-- usage:
SELECT CUSTOM_KEYS.schema_keychain.Crypto_Key (16, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), SYS_CONTEXT('CUSTOM_CTX', 'WORKSPACE_NAME')) X FROM DUAL;

EXEC schema_keychain.Synchronize_Keys('SCHEMA_SYNC_LINK', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'CUSTOM_KEYS');
EXEC schema_keychain.Synchronize_Keys('SCHEMA_SYNC_LINK', 'WEMACO', 'CUSTOM_KEYS', 'WEMA_DATA');
*/

