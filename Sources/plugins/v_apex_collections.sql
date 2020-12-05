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

------------------------------------------------------------------------------
Purpose: Access and update forms and interactive grids that are based on an APEX_COLLECTION without additional PL/SQL code.

	The View V_APEX_COLLECTIONS is created to provide the support of DML operations via triggers.
	The package Pipe_Apex_Collections is used to cover up the fact, that we access the view APEX_COLLECTIONS.
	This is needed, to enable the creation of the INSTEAD OF INSERT/UPDATE/DELETE trigger.
	The triggers translate the DML operations into calls against the APEX_COLLECTION API

Usage:
	A collection has to be initialised with APEX_COLLECTION.CREATE_COLLECTION('MY_COLLECTION'), 
	CREATE_COLLECTION_FROM_QUERY or similar calls before usage.

	INSERT INTO V_APEX_COLLECTIONS (COLLECTION_NAME, C001, ...)
	VALUES('MY_COLLECTION', 'X', ...);
	
	UPDATE V_APEX_COLLECTIONS SET C001 = 'X', ... WHERE COLLECTION_NAME = 'MY_COLLECTION' AND SEQ_ID = 1;

	DELETE FROM V_APEX_COLLECTIONS WHERE COLLECTION_NAME = 'MY_COLLECTION' AND SEQ_ID = 1;
	
	SELECT C001, C002 FROM V_APEX_COLLECTIONS WHERE COLLECTION_NAME = 'MY_COLLECTION' AND SEQ_ID = 1;
*/

CREATE OR REPLACE PACKAGE Pipe_Apex_Collections
 AUTHID DEFINER
IS
	TYPE tab_apex_collections IS TABLE OF APEX_COLLECTIONS%ROWTYPE;
	FUNCTION pipe_rows ( p_Collection_Name VARCHAR2 DEFAULT NULL ) RETURN tab_apex_collections PIPELINED;
	FUNCTION next_seq_id ( p_Collection_Name VARCHAR2 ) RETURN NUMBER;
END;
/
show errors

CREATE OR REPLACE PACKAGE BODY Pipe_Apex_Collections
IS
	FUNCTION pipe_rows (
		p_Collection_Name VARCHAR2 DEFAULT NULL
	) RETURN tab_apex_collections PIPELINED
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
		c_cur  SYS_REFCURSOR;
		v_row APEX_COLLECTIONS%ROWTYPE; -- output row
	BEGIN
		OPEN c_cur FOR
			SELECT * FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = NVL(p_Collection_Name, COLLECTION_NAME);
		loop
			FETCH c_cur INTO v_row;
			EXIT WHEN c_cur%NOTFOUND;
			PIPE ROW(v_row);
		end loop;
		CLOSE c_cur;
		RETURN;
	END pipe_rows;
	
	FUNCTION next_seq_id ( p_Collection_Name VARCHAR2 ) RETURN NUMBER
	IS
		v_Result NUMBER;
	BEGIN
		select NVL(MAX(SEQ_ID),0) + 1 INTO v_Result
		from APEX_COLLECTIONS where COLLECTION_NAME = p_Collection_Name;
		RETURN v_Result;
	END;
END;
/
show errors

CREATE OR REPLACE VIEW V_APEX_COLLECTIONS ( 
	COLLECTION_NAME, SEQ_ID, C001, C002, C003, C004, C005, C006, C007, C008, C009, C010, C011, C012, C013, C014, C015, C016, C017, C018, C019, C020, 
	C021, C022, C023, C024, C025, C026, C027, C028, C029, C030, C031, C032, C033, C034, C035, C036, C037, C038, C039, C040, C041, C042, C043, C044, C045, 
	C046, C047, C048, C049, C050, CLOB001, BLOB001, XMLTYPE001, N001, N002, N003, N004, N005, D001, D002, D003, D004, D005, MD5_ORIGINAL,
	CONSTRAINT V_APEX_COLLECTIONS_TAB_VPK PRIMARY KEY (COLLECTION_NAME, SEQ_ID) RELY DISABLE)
AS 
SELECT COLLECTION_NAME, SEQ_ID, C001, C002, C003, C004, C005, C006, C007, C008, C009, C010, C011, C012, C013, C014, C015, C016, C017, C018, C019, C020, 
	C021, C022, C023, C024, C025, C026, C027, C028, C029, C030, C031, C032, C033, C034, C035, C036, C037, C038, C039, C040, C041, C042, C043, C044, C045, 
	C046, C047, C048, C049, C050, CLOB001, BLOB001, XMLTYPE001, N001, N002, N003, N004, N005, D001, D002, D003, D004, D005, MD5_ORIGINAL
FROM TABLE(Pipe_apex_collections.pipe_rows)
;

CREATE OR REPLACE TRIGGER V_APEX_COLLECTIONS_DL_TR INSTEAD OF DELETE ON V_APEX_COLLECTIONS FOR EACH ROW 
BEGIN
    APEX_COLLECTION.DELETE_MEMBER ( p_collection_name => :OLD.COLLECTION_NAME, p_seq => :OLD.SEQ_ID);
END;
/
show errors

CREATE OR REPLACE TRIGGER V_APEX_COLLECTIONS_IN_TR INSTEAD OF INSERT ON V_APEX_COLLECTIONS FOR EACH ROW 
BEGIN
    APEX_COLLECTION.ADD_MEMBER(
		p_COLLECTION_NAME => :NEW.COLLECTION_NAME,
		p_C001 => :NEW.C001,
		p_C002 => :NEW.C002,
		p_C003 => :NEW.C003,
		p_C004 => :NEW.C004,
		p_C005 => :NEW.C005,
		p_C006 => :NEW.C006,
		p_C007 => :NEW.C007,
		p_C008 => :NEW.C008,
		p_C009 => :NEW.C009,
		p_C010 => :NEW.C010,
		p_C011 => :NEW.C011,
		p_C012 => :NEW.C012,
		p_C013 => :NEW.C013,
		p_C014 => :NEW.C014,
		p_C015 => :NEW.C015,
		p_C016 => :NEW.C016,
		p_C017 => :NEW.C017,
		p_C018 => :NEW.C018,
		p_C019 => :NEW.C019,
		p_C020 => :NEW.C020,
		p_C021 => :NEW.C021,
		p_C022 => :NEW.C022,
		p_C023 => :NEW.C023,
		p_C024 => :NEW.C024,
		p_C025 => :NEW.C025,
		p_C026 => :NEW.C026,
		p_C027 => :NEW.C027,
		p_C028 => :NEW.C028,
		p_C029 => :NEW.C029,
		p_C030 => :NEW.C030,
		p_C031 => :NEW.C031,
		p_C032 => :NEW.C032,
		p_C033 => :NEW.C033,
		p_C034 => :NEW.C034,
		p_C035 => :NEW.C035,
		p_C036 => :NEW.C036,
		p_C037 => :NEW.C037,
		p_C038 => :NEW.C038,
		p_C039 => :NEW.C039,
		p_C040 => :NEW.C040,
		p_C041 => :NEW.C041,
		p_C042 => :NEW.C042,
		p_C043 => :NEW.C043,
		p_C044 => :NEW.C044,
		p_C045 => :NEW.C045,
		p_C046 => :NEW.C046,
		p_C047 => :NEW.C047,
		p_C048 => :NEW.C048,
		p_C049 => :NEW.C049,
		p_C050 => :NEW.C050,
		p_CLOB001 => :NEW.CLOB001,
		p_BLOB001 => :NEW.BLOB001,
		p_XMLTYPE001 => :NEW.XMLTYPE001,
		p_N001 => :NEW.N001,
		p_N002 => :NEW.N002,
		p_N003 => :NEW.N003,
		p_N004 => :NEW.N004,
		p_N005 => :NEW.N005,
		p_D001 => :NEW.D001,
		p_D002 => :NEW.D002,
		p_D003 => :NEW.D003,
		p_D004 => :NEW.D004,
		p_D005 => :NEW.D005
	);
END;
/
show errors

CREATE OR REPLACE TRIGGER V_APEX_COLLECTIONS_UP_TR INSTEAD OF UPDATE ON V_APEX_COLLECTIONS FOR EACH ROW 
BEGIN
	APEX_COLLECTION.UPDATE_MEMBER (
		p_collection_name => :NEW.COLLECTION_NAME,
		p_seq => :NEW.SEQ_ID,
		p_C001 => :NEW.C001,
		p_C002 => :NEW.C002,
		p_C003 => :NEW.C003,
		p_C004 => :NEW.C004,
		p_C005 => :NEW.C005,
		p_C006 => :NEW.C006,
		p_C007 => :NEW.C007,
		p_C008 => :NEW.C008,
		p_C009 => :NEW.C009,
		p_C010 => :NEW.C010,
		p_C011 => :NEW.C011,
		p_C012 => :NEW.C012,
		p_C013 => :NEW.C013,
		p_C014 => :NEW.C014,
		p_C015 => :NEW.C015,
		p_C016 => :NEW.C016,
		p_C017 => :NEW.C017,
		p_C018 => :NEW.C018,
		p_C019 => :NEW.C019,
		p_C020 => :NEW.C020,
		p_C021 => :NEW.C021,
		p_C022 => :NEW.C022,
		p_C023 => :NEW.C023,
		p_C024 => :NEW.C024,
		p_C025 => :NEW.C025,
		p_C026 => :NEW.C026,
		p_C027 => :NEW.C027,
		p_C028 => :NEW.C028,
		p_C029 => :NEW.C029,
		p_C030 => :NEW.C030,
		p_C031 => :NEW.C031,
		p_C032 => :NEW.C032,
		p_C033 => :NEW.C033,
		p_C034 => :NEW.C034,
		p_C035 => :NEW.C035,
		p_C036 => :NEW.C036,
		p_C037 => :NEW.C037,
		p_C038 => :NEW.C038,
		p_C039 => :NEW.C039,
		p_C040 => :NEW.C040,
		p_C041 => :NEW.C041,
		p_C042 => :NEW.C042,
		p_C043 => :NEW.C043,
		p_C044 => :NEW.C044,
		p_C045 => :NEW.C045,
		p_C046 => :NEW.C046,
		p_C047 => :NEW.C047,
		p_C048 => :NEW.C048,
		p_C049 => :NEW.C049,
		p_C050 => :NEW.C050,
		p_CLOB001 => :NEW.CLOB001,
		p_BLOB001 => :NEW.BLOB001,
		p_XMLTYPE001 => :NEW.XMLTYPE001,
		p_N001 => :NEW.N001,
		p_N002 => :NEW.N002,
		p_N003 => :NEW.N003,
		p_N004 => :NEW.N004,
		p_N005 => :NEW.N005,
		p_D001 => :NEW.D001,
		p_D002 => :NEW.D002,
		p_D003 => :NEW.D003,
		p_D004 => :NEW.D004,
		p_D005 => :NEW.D005
	);
END;
/
