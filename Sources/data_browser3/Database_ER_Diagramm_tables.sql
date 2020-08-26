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
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DATA_BROWSER_DIAGRAM';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DATA_BROWSER_DIAGRAM ( 
			DIAGRAM_ID VARCHAR(64) NOT NULL ENABLE, 
			FONTSIZE FLOAT DEFAULT 4,
			ZOOM_FACTOR FLOAT DEFAULT 1 NOT NULL,
			X_OFFSET FLOAT DEFAULT 0 NOT NULL,
			Y_OFFSET FLOAT DEFAULT 0 NOT NULL,
			CANVAS_WIDTH NUMBER,
			EXCLUDE_SINGLES VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT DATA_BROW_DIAG_EXCL_SINGLE_CK CHECK ( Exclude_Singles IN ('YES','NO') ),
			EDGE_LABELS VARCHAR2(5) DEFAULT 'YES' NOT NULL	  CONSTRAINT DATA_BROW_DIAG_EDGE_LABELS_CK CHECK ( Edge_Labels IN ('YES','NO','BOXES') ),
			STIFFNESS FLOAT DEFAULT 400 NOT NULL,
			REPULSION FLOAT DEFAULT 2000 NOT NULL,
			DAMPING FLOAT DEFAULT 0.15 NOT NULL,
			MINENERGYTHRESHOLD FLOAT DEFAULT 0.01 NOT NULL,
			MAXSPEED FLOAT DEFAULT 50 NOT NULL,
			PINWEIGHT FLOAT DEFAULT 10 NOT NULL,
			EXCITE_METHOD VARCHAR2(50) DEFAULT 'none' NOT NULL CONSTRAINT DATA_BROW_DIAG_EXCITE_METHOD_CK 
				CHECK (EXCITE_METHOD IN ('none', 'selected', 'downstream', 'upstream', 'connected')),
			CONSTRAINT DATA_BROWSER_DIAGRAM_PK PRIMARY KEY (DIAGRAM_ID)
		   ) ORGANIZATION INDEX
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'DATA_BROWSER_DIAGRAM' and column_name = 'CANVAS_WIDTH';
	if v_Count = 0 then
		EXECUTE IMMEDIATE 'ALTER TABLE DATA_BROWSER_DIAGRAM ADD (
			CANVAS_WIDTH	NUMBER
		)';
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'DATA_BROWSER_DIAGRAM' and column_name = 'EXCITE_METHOD';
	if v_Count = 0 then
		EXECUTE IMMEDIATE q'[ALTER TABLE DATA_BROWSER_DIAGRAM ADD (
			EXCITE_METHOD VARCHAR2(50) DEFAULT 'none' NOT NULL CONSTRAINT DATA_BROW_DIAG_EXCITE_METHOD_CK CHECK (EXCITE_METHOD IN ('none', 'downstream', 'upstream', 'connected'))
		)]';
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'DATA_BROWSER_DIAGRAM' and column_name = 'PINWEIGHT';
	if v_Count = 0 then
		EXECUTE IMMEDIATE 'ALTER TABLE DATA_BROWSER_DIAGRAM ADD (
			PINWEIGHT FLOAT DEFAULT 10 NOT NULL
		)';
	end if;

	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DATA_BROWSER_DIAGRAM_COORD';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DATA_BROWSER_DIAGRAM_COORD (	
			DIAGRAM_ID VARCHAR2(64) NOT NULL, 
			OBJECT_ID VARCHAR2(64) NOT NULL, 
			X_COORDINATE FLOAT DEFAULT 0 NOT NULL,
			Y_COORDINATE FLOAT DEFAULT 0 NOT NULL,
			MASS  FLOAT DEFAULT 1 NOT NULL,
			ACTIVE VARCHAR2(1) DEFAULT 'Y' NOT NULL CONSTRAINT DATA_BROW_DIAG_COORD_AKTIV_CK CHECK (ACTIVE in ('Y','N')), 
			CONSTRAINT DATA_BROWSER_DIAGRAM_COORD_PK PRIMARY KEY (DIAGRAM_ID, OBJECT_ID) 
		) ORGANIZATION INDEX COMPRESS 1
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	SELECT COUNT(*) INTO v_Count
	from user_tab_cols where table_name = 'DATA_BROWSER_DIAGRAM_COORD' and column_name = 'ACTIVE';
	if v_Count = 0 then
		EXECUTE IMMEDIATE q'[ALTER TABLE DATA_BROWSER_DIAGRAM_COORD ADD (
			ACTIVE VARCHAR2(1) DEFAULT 'Y' NOT NULL CONSTRAINT DATA_BROW_DIAG_COORD_AKTIV_CK CHECK (ACTIVE in ('Y','N'))
		)]';
	end if;

	SELECT COUNT(*) INTO v_count
	from user_constraints 
	where table_name = 'DATA_BROWSER_DIAGRAM_COORD' 
	and constraint_name = 'DATA_BROWSER_DIAGRAM_COORD_FK';
	if v_count = 0 then 
		v_stat := '
		ALTER TABLE DATA_BROWSER_DIAGRAM_COORD ADD 
			CONSTRAINT DATA_BROWSER_DIAGRAM_COORD_FK FOREIGN KEY (DIAGRAM_ID) 
			REFERENCES DATA_BROWSER_DIAGRAM (DIAGRAM_ID)  ON DELETE CASCADE ENABLE
		';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	ALTER TABLE DATA_BROWSER_DIAGRAM MODIFY (
		STIFFNESS FLOAT DEFAULT 400,
		REPULSION FLOAT DEFAULT 2000
	)
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/
show errors
