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

CREATE OR REPLACE PACKAGE weco_auth_mgr
AUTHID CURRENT_USER
IS
	TYPE rec_user_password_columns IS RECORD (
		TABLE_NAME 			VARCHAR2(128),
		COLUMN_NAME			VARCHAR2(128),
		PRIMARY_KEY_COL		VARCHAR2(128),
		DATA_TYPE 			VARCHAR2(128),
		CHAR_LENGTH 		NUMBER,
		IS_PREPARED			VARCHAR2(3),
		ENCRYPTED_COUNT 	NUMBER,
		IS_BASE_TABLE		VARCHAR2(3)
	);
	TYPE tab_user_password_columns IS TABLE OF rec_user_password_columns;

	FUNCTION pipe_user_password_columns (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN tab_user_password_columns PIPELINED;

	-- encrypt all stored passwords current of database schema
    PROCEDURE encrypt_db_passwords(
        p_Workspace IN VARCHAR2 DEFAULT NULL,
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',
        p_Do_Execute  IN NUMBER	  DEFAULT 1);

	-- decrypt all stored passwords for export of database
    PROCEDURE decrypt_db_passwords(
        p_Workspace IN VARCHAR2 DEFAULT NULL,
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',
        p_Do_Execute  IN NUMBER	  DEFAULT 1);

	-- prepare all stored passwords for export of database
    PROCEDURE prepare_db_passwords(
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',
        p_Do_Execute  IN NUMBER	  DEFAULT 1);

	-- add database user account
    PROCEDURE add_db_user(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_dbgroup IN VARCHAR2 DEFAULT NULL,
        p_userlevel IN NUMBER DEFAULT 5);

	-- drop database user account
    PROCEDURE drop_db_user(
    	p_Username IN VARCHAR2);

	-- change password of database account for <p_Username>. New password is <p_Password>
	PROCEDURE change_db_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2);

END weco_auth_mgr;
/
show errors


CREATE OR REPLACE PACKAGE BODY weco_auth_mgr IS
	-- Execute generated statements
	PROCEDURE run_stat (
		p_Statement    	IN CLOB,
		p_Do_Execute  	IN NUMBER	DEFAULT 1,
		p_Delimiter		IN VARCHAR2 DEFAULT ';'
	)
	IS
	BEGIN
		if p_Do_Execute = 1 then
			DBMS_OUTPUT.PUT_LINE(p_Statement || p_Delimiter);
			EXECUTE IMMEDIATE p_Statement;
		else
			DBMS_OUTPUT.PUT_LINE(p_Statement || p_Delimiter);
		end if;
	END;

	FUNCTION pipe_user_password_columns (
		p_Table_Name VARCHAR2 DEFAULT NULL
	) RETURN tab_user_password_columns PIPELINED
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
		c_cur  SYS_REFCURSOR;
		v_row rec_user_password_columns; -- output row
	BEGIN
		OPEN c_cur FOR
			SELECT C.TABLE_NAME, C.COLUMN_NAME, 
				CAST(P.COLUMN_NAME AS VARCHAR2(128)) PRIMARY_KEY_COL, 
				C.DATA_TYPE, C.CHAR_LENGTH,
				CASE WHEN NOT( C.DATA_TYPE = 'VARCHAR2' AND C.CHAR_LENGTH >= 50) THEN 'NO' ELSE 'YES' END IS_PREPARED,
				weco_auth.get_encrypted_count(C.TABLE_NAME, C.COLUMN_NAME) ENCRYPTED_COUNT,
				CASE WHEN V.VIEW_NAME IS NULL THEN 'YES' ELSE 'NO' END IS_BASE_TABLE
			FROM USER_TAB_COLUMNS C
			LEFT OUTER JOIN USER_VIEWS V ON V.VIEW_NAME = C.TABLE_NAME
			JOIN (SELECT /* get last primary key column of type integer */
					DISTINCT B.TABLE_NAME, FIRST_VALUE(B.COLUMN_NAME) OVER (PARTITION BY B.TABLE_NAME ORDER BY B.POSITION DESC) COLUMN_NAME
				FROM USER_CONSTRAINTS A
				JOIN USER_CONS_COLUMNS B ON A.TABLE_NAME = B.TABLE_NAME AND A.CONSTRAINT_NAME = B.CONSTRAINT_NAME
				JOIN USER_TAB_COLUMNS D ON D.TABLE_NAME = B.TABLE_NAME AND D.COLUMN_NAME = B.COLUMN_NAME
				WHERE A.CONSTRAINT_TYPE = 'P'
				AND D.DATA_TYPE = 'NUMBER'
				AND NVL(D.DATA_SCALE, 0 ) = 0
			) P ON P.TABLE_NAME = C.TABLE_NAME
			WHERE C.TABLE_NAME = NVL(p_Table_Name, C.TABLE_NAME);
		loop
			FETCH c_cur INTO v_row;
			EXIT WHEN c_cur%NOTFOUND;
			PIPE ROW(v_row);
		end loop;
		RETURN;
	END;

	-- encrypt, decrypt or prepare all stored passwords after import of database
    PROCEDURE int_crypt_db(
        p_Workspace   IN VARCHAR2 DEFAULT NULL,			/* When NULL access base tables, else access updatable VPD views */
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',	/* Matching substring in COLUMN_NAME */
        p_Method 	  IN VARCHAR2 DEFAULT 'HEX_DCRYPT',	/* Valid values: HEX_CRYPT, HEX_DCRYPT, prepare */
        p_Do_Execute  IN NUMBER	  DEFAULT 1
        )
	IS
		v_Base_Tables VARCHAR2(5) := CASE WHEN p_Workspace IS NULL THEN 'YES' ELSE 'NO' END;
	BEGIN
		FOR stat_cur IN (
			SELECT
				CASE WHEN UPPER(p_Method) IN ('HEX_DCRYPT', 'HEX_CRYPT') THEN
					'UPDATE ' || C.TABLE_NAME
					|| ' SET '|| C.COLUMN_NAME || ' = weco_auth.' || p_Method || '('
					|| C.PRIMARY_KEY_COL
					|| ', ' || C.COLUMN_NAME || ')'
					|| ' WHERE '|| C.COLUMN_NAME || ' IS NOT NULL'
				ELSE
					'ALTER TABLE ' || C.TABLE_NAME
					|| ' MODIFY (' || C.COLUMN_NAME || ' VARCHAR2(50 BYTE))'
				END STAT
			FROM TABLE(pipe_user_password_columns) C
			WHERE INSTR(C.COLUMN_NAME, p_Col_Pattern) > 0
			AND IS_BASE_TABLE = v_Base_Tables
			ORDER BY 1
		)
		LOOP
			run_stat (stat_cur.STAT, p_Do_Execute);
		END LOOP;
	END;

	-- encrypt all stored passwords current of database schema
    PROCEDURE encrypt_db_passwords(
        p_Workspace IN VARCHAR2 DEFAULT NULL,
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',
        p_Do_Execute  IN NUMBER	  DEFAULT 1)
	IS
	BEGIN
		custom_changelog.set_current_workspace(NVL(p_Workspace, weco_auth.Get_App_Schema_Name));
		if weco_auth.authenticate(p_Username, p_Password) = FALSE then
			RAISE_APPLICATION_ERROR (-20010, 'user is not authenticate.');
		end if;
		int_crypt_db(p_Workspace, p_Col_Pattern, 'HEX_CRYPT', p_Do_Execute);
	END;

	-- decrypt all stored passwords for export of database
    PROCEDURE decrypt_db_passwords(
        p_Workspace IN VARCHAR2 DEFAULT NULL,
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',
        p_Do_Execute  IN NUMBER	  DEFAULT 1)
	IS
	BEGIN
		custom_changelog.set_current_workspace(NVL(p_Workspace, weco_auth.Get_App_Schema_Name));
		if weco_auth.authenticate(p_Username, p_Password) = FALSE then
			RAISE_APPLICATION_ERROR (-20010, 'user is not authenticate.');
		end if;
		int_crypt_db(p_Workspace, p_Col_Pattern, 'HEX_DCRYPT', p_Do_Execute);
	END;

	-- prepare all stored passwords for export of database
    PROCEDURE prepare_db_passwords(
        p_Col_Pattern IN VARCHAR2 DEFAULT 'PASSWOR',
        p_Do_Execute  IN NUMBER	  DEFAULT 1)
	IS
	BEGIN
		int_crypt_db(NULL, p_Col_Pattern, 'PREPARE', p_Do_Execute);
	END;

	-- add database user account
    PROCEDURE add_db_user(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2,
        p_dbgroup IN VARCHAR2 DEFAULT NULL,
        p_userlevel IN NUMBER DEFAULT 5)
    IS
		v_KnownUser INTEGER;
		v_UserName VARCHAR2(50);
		v_UserPW VARCHAR2(50);
		v_dbgroup VARCHAR2(50);
	BEGIN
		SELECT COUNT(*) INTO v_KnownUser
		FROM SYS.ALL_USERS
		WHERE UPPER(USERNAME) = UPPER(p_Username);

		v_UserName := DBMS_ASSERT.ENQUOTE_NAME(p_Username);
		v_UserPW :=  DBMS_ASSERT.ENQUOTE_NAME(p_Password, FALSE);
		v_dbgroup := DBMS_ASSERT.ENQUOTE_NAME(p_dbgroup);
		IF p_Password IS NOT NULL THEN
			IF v_KnownUser=0 THEN
				EXECUTE IMMEDIATE 'CREATE USER '||v_UserName||'  IDENTIFIED BY '||v_UserPW;
			ELSE
				EXECUTE IMMEDIATE 'ALTER  USER '||v_UserName||' IDENTIFIED BY '||v_UserPW;
			END IF;
		END IF;
		EXECUTE IMMEDIATE 'ALTER  USER '||v_UserName||' ACCOUNT UNLOCK ';
		EXECUTE IMMEDIATE 'GRANT CONNECT TO  '||v_UserName;
		if v_dbgroup IS NOT NULL then
			EXECUTE IMMEDIATE 'GRANT '||v_dbgroup||' TO '||v_UserName;
		end if;
	END;

	-- drop database user account
    PROCEDURE drop_db_user(
    	p_Username IN VARCHAR2)
    IS
		v_KnownUser INTEGER;
		v_UserName VARCHAR2(50);
		v_UserPW VARCHAR2(50);
		v_dbgroup VARCHAR2(50);
	BEGIN
		SELECT COUNT(*) INTO v_KnownUser
		FROM SYS.ALL_USERS
		WHERE UPPER(USERNAME) = UPPER(p_Username);

		v_UserName := DBMS_ASSERT.ENQUOTE_NAME(p_Username, TRUE);
		IF v_KnownUser=1 THEN
			EXECUTE IMMEDIATE 'DROP USER '||v_UserName;
		END IF;
	END;

	-- change password of database account for <p_Username>. New password is <p_Password>
	PROCEDURE change_db_password(
    	p_Username IN VARCHAR2,
        p_Password IN VARCHAR2)
	IS
		v_UserName VARCHAR2(50);
		v_UserPW VARCHAR2(50);
		v_Stat VARCHAR2(200);
	BEGIN
		v_UserName := DBMS_ASSERT.ENQUOTE_NAME(p_Username);
		v_UserPW   := DBMS_ASSERT.ENQUOTE_NAME(p_Password, FALSE);
		v_Stat     := 'ALTER  USER ' || v_UserName || ' IDENTIFIED BY ' || v_UserPW;
		EXECUTE IMMEDIATE v_Stat;
	END;

END weco_auth_mgr;
/
show errors


/*
-- usage

call weco_auth.change_db_password ('Dirk', 'xxx');


*/
