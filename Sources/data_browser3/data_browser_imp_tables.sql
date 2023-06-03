declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_OBJECTS WHERE OBJECT_NAME = 'USER_IMPORT_JOBS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE USER_IMPORT_JOBS (
			IMPORTJOB_ID$ NUMBER NOT NULL,
			TABLE_NAME VARCHAR2(32 CHAR),
			IMPORT_DATUM TIMESTAMP (6) DEFAULT CURRENT_TIMESTAMP NOT NULL,
			LINK_DATUM TIMESTAMP (6),
			EXPORT_TEXT_LIMIT         	INTEGER     	DEFAULT 1000 NOT NULL,
			IMPORT_CURRENCY_FORMAT    	VARCHAR2(64)    DEFAULT '9G999G999G990D99' NOT NULL,
			IMPORT_NUMBER_FORMAT      	VARCHAR2(64)    DEFAULT '9999999999999D9999999999' NOT NULL,
			IMPORT_NUMCHARS       		VARCHAR2(64)    DEFAULT 'NLS_NUMERIC_CHARACTERS = '',.''' NOT NULL,
			IMPORT_FLOAT_FORMAT       	VARCHAR2(64)    DEFAULT 'TM9' NOT NULL,
			EXPORT_DATE_FORMAT    		VARCHAR2(64)    DEFAULT 'DD.MM.YYYY' NOT NULL,
			IMPORT_DATETIME_FORMAT		VARCHAR2(64)    DEFAULT 'DD.MM.YYYY HH24:MI:SS' NOT NULL,
			IMPORT_TIMESTAMP_FORMAT   	VARCHAR2(64)    DEFAULT 'DD.MM.YYYY HH24.MI.SSXFF' NOT NULL,
			INSERT_FOREIGN_KEYS   		VARCHAR2(5)     DEFAULT 'YES' NOT NULL,   -- insert new foreign key values in insert trigger
			SEARCH_KEYS_UNIQUE 			VARCHAR2(5)     DEFAULT 'YES' NOT NULL, 	-- Unique Constraint is required for searching foreign key values
			MERGE_ON_UNIQUE_KEYS 		VARCHAR2(5)     DEFAULT 'YES' NOT NULL, 	-- Enable merge on unique keys in import views
			EXCLUDE_BLOB_COLUMNS  		VARCHAR2(5)     DEFAULT 'YES' NOT NULL,	-- Exclude Blob Columns from the produced projection column list
			COMPARE_CASE_INSENSITIVE 	VARCHAR2(5)  	DEFAULT 'NO' NOT NULL,   -- compare Case insensitive foreign key values in insert trigger
			COMPARE_RETURN_STRING  		VARCHAR2(300)   DEFAULT 'Differenz gefunden.' NOT NULL,
			COMPARE_RETURN_STYLE  		VARCHAR2(300)   DEFAULT 'background-color:PaleTurquoise;' NOT NULL,
			COMPARE_RETURN_STYLE2  		VARCHAR2(300)   DEFAULT 'background-color:PaleGreen;' NOT NULL,
			COMPARE_RETURN_STYLE3  		VARCHAR2(300)   DEFAULT 'background-color:Salmon;' NOT NULL,
			ERRORS_RETURN_STYLE 		VARCHAR2(300)   DEFAULT 'background-color:Moccasin;' NOT NULL,
			ERROR_IS_EMPTY				VARCHAR2(64)    DEFAULT 'ist leer.' NOT NULL,
			ERROR_IS_LONGER_THAN		VARCHAR2(64)    DEFAULT '... Zeichenkette ist länger als' NOT NULL,
			ERROR_IS_NO_CURRENCY		VARCHAR2(64)    DEFAULT 'ist kein Währungsbetrag.' NOT NULL,
			ERROR_IS_NO_FLOAT			VARCHAR2(64)    DEFAULT 'ist keine Gleitkommazahl.' NOT NULL,
			ERROR_IS_NO_INTEGER			VARCHAR2(64)    DEFAULT 'ist keine Integerzahl.' NOT NULL,
			ERROR_IS_NO_DATE			VARCHAR2(64)    DEFAULT 'ist keine gültiges Datum.' NOT NULL,
			ERROR_IS_NO_TIMESTAMP		VARCHAR2(64)    DEFAULT 'ist kein gültiger Timestamp.' NOT NULL,
			CONSTRAINT USER_IMPORT_JOBS_PK PRIMARY KEY (IMPORTJOB_ID$) USING INDEX
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'USER_IMPORT_JOBS_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE USER_IMPORT_JOBS_SEQ START WITH 1000 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'USER_IMPORT_JOBS' AND COLUMN_NAME = 'MERGE_ON_UNIQUE_KEYS';
	if v_count = 0 then 
		v_stat := q'[
		ALTER TABLE USER_IMPORT_JOBS ADD
		(
			MERGE_ON_UNIQUE_KEYS		VARCHAR2(5)     DEFAULT 'YES' NOT NULL
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	
end;
/
show errors
