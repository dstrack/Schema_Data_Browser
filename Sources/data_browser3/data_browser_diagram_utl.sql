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

CREATE OR REPLACE PACKAGE data_browser_diagram_utl
AUTHID CURRENT_USER
IS
	PROCEDURE Load_Diagam_settings (
		p_SOURCE_TYPE			IN VARCHAR2,
		p_DIAGRAM_OWNER			IN VARCHAR2,
		p_DA_APPLICATION_ID		IN VARCHAR2,
		p_DA_PAGE_ID			IN VARCHAR2,
		p_DIAGRAM_ID			OUT VARCHAR2,
		p_DIAGRAM_FONTSIZE		OUT VARCHAR2,
		p_DIAGRAM_ZOOMFACTOR	OUT VARCHAR2, 
		p_DIAGRAM_X_OFFSET		OUT VARCHAR2, 
		p_DIAGRAM_Y_OFFSET		OUT VARCHAR2,
		p_CANVAS_WIDTH			OUT VARCHAR2, 
		p_EXCLUDE_SINGLES		OUT VARCHAR2, 
		p_DIAGRAM_LABELS		OUT VARCHAR2,
		p_EXCITE_METHOD			OUT VARCHAR2,
		p_STIFFNESS				OUT VARCHAR2, 
		p_REPULSION				OUT VARCHAR2, 
		p_DAMPING				OUT VARCHAR2, 
		p_MINENERGYTHRESHOLD	OUT VARCHAR2, 
		p_MAXSPEED				OUT VARCHAR2,
		p_PINWEIGHT				OUT VARCHAR2
	);

	PROCEDURE Load_Diagam_controls (
		p_STIFFNESS				IN VARCHAR2, 
		p_REPULSION				IN VARCHAR2, 
		p_DAMPING				IN VARCHAR2, 
		p_MINENERGYTHRESHOLD	IN VARCHAR2, 
		p_MAXSPEED				IN VARCHAR2, 
		p_STIFFNESS_D			OUT VARCHAR2,
		p_REPULSION_D 			OUT VARCHAR2,
		p_DAMPING_D				OUT VARCHAR2,
		p_MINENERGYTHRESHOLD_D	OUT VARCHAR2,
		p_MAXSPEED_D			OUT VARCHAR2
	);

	PROCEDURE Save_Diagam_controls (
		p_STIFFNESS_D			IN VARCHAR2, 
		p_REPULSION_D			IN VARCHAR2, 
		p_DAMPING_D				IN VARCHAR2, 
		p_MINENERGYTHRESHOLD_D	IN VARCHAR2, 
		p_MAXSPEED_D			IN VARCHAR2, 
		p_STIFFNESS				OUT VARCHAR2,
		p_REPULSION 			OUT VARCHAR2,
		p_DAMPING				OUT VARCHAR2,
		p_MINENERGYTHRESHOLD	OUT VARCHAR2,
		p_MAXSPEED				OUT VARCHAR2
	);

	PROCEDURE Save_Canvas_Positions (
		p_DIAGRAM_ID			IN VARCHAR2,
		p_DIAGRAM_FONTSIZE		IN VARCHAR2,
		p_DIAGRAM_ZOOMFACTOR	IN VARCHAR2, 
		p_DIAGRAM_X_OFFSET		IN VARCHAR2, 
		p_DIAGRAM_Y_OFFSET		IN VARCHAR2,
		p_CANVAS_WIDTH			IN VARCHAR2, 
		p_EXCLUDE_SINGLES		IN VARCHAR2, 
		p_DIAGRAM_LABELS		IN VARCHAR2,
		p_STIFFNESS				IN VARCHAR2,
		p_REPULSION				IN VARCHAR2,
		p_DAMPING				IN VARCHAR2,
		p_MINENERGYTHRESHOLD	IN VARCHAR2,
		p_MAXSPEED				IN VARCHAR2,
		p_REQUEST				IN VARCHAR2,
		p_PINWEIGHT				IN VARCHAR2,
		p_EXCITE_METHOD			IN VARCHAR2
	);
	
	PROCEDURE Save_Node_Coordinates (
		p_DIAGRAM_ID			IN VARCHAR2,
		p_REQUEST				IN VARCHAR2
	);

	PROCEDURE Database_ER_Diagramm_JS(
		p_Exclude_Singles		IN VARCHAR2 DEFAULT 'YES',
		p_Diagramm_Labels		IN VARCHAR2 DEFAULT 'NO'
	);

    FUNCTION DA_Shape(
    	p_Object_Type VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION DA_Color(
    	p_Object_Type VARCHAR2,
    	p_Color VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    FUNCTION DA_Insulator(
    	p_Object_Type VARCHAR2,
    	p_Source_Node VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

	PROCEDURE Dynamic_Actions_Diagram_JS(
		p_Application_ID IN NUMBER DEFAULT NV('APP_ID'),
		p_Page_ID IN NUMBER DEFAULT NV('APP_PAGE_ID'),
		p_Diagramm_Name IN VARCHAR2 DEFAULT 'APEX_DA',
		p_Diagramm_Labels IN VARCHAR2 DEFAULT 'NO'
	);

    FUNCTION DB_Shape(
    	p_Object_Type VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION DB_Color(
    	p_Object_Type VARCHAR2,
    	p_Color VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

	PROCEDURE Object_Dependencies_JS(
		p_Exclude_Pattern IN VARCHAR2 DEFAULT NULL,
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Diagramm_Labels IN VARCHAR2 DEFAULT 'NO',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Object_Types IN VARCHAR2 DEFAULT 'KEY CONSTRAINT:CHECK CONSTRAINT:NOT NULL CONSTRAINT:FUNCTION:INDEX:MATERIALIZED VIEW:PACKAGE:PACKAGE BODY:PROCEDURE:SEQUENCE:SYNONYM:TABLE:TRIGGER:TYPE:TYPE BODY:VIEW'
	);

	PROCEDURE Save_Object_Dependencies_As (
		p_Exclude_Pattern IN VARCHAR2 DEFAULT NULL,
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Object_Types 			IN VARCHAR2,
		p_DIAGRAM_Name			IN VARCHAR2,
		p_Springy_Diagram_ID 	OUT NUMBER
	);

	PROCEDURE Save_Dynamic_Actions_As (
		p_DA_APPLICATION_ID		IN VARCHAR2,
		p_DA_PAGE_ID			IN VARCHAR2,
		p_DIAGRAM_Name			IN VARCHAR2,
		p_Springy_Diagram_ID 	OUT NUMBER
	);

	PROCEDURE Save_Database_ER_As (
		p_Exclude_Singles		IN VARCHAR2 DEFAULT 'YES',
		p_DIAGRAM_Name			IN VARCHAR2,
		p_App_Developer_Mode 	IN VARCHAR2 DEFAULT V('APP_DEVELOPER_MODE'),
		p_Springy_Diagram_ID 	OUT NUMBER
	);
	
	FUNCTION Object_Dependencies_List(
		p_Exclude_Pattern IN VARCHAR2 DEFAULT NULL,
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Diagramm_Labels IN VARCHAR2 DEFAULT 'NO',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2,
		p_Object_Types IN VARCHAR2,
		p_Search_Type  IN VARCHAR DEFAULT NULL 
	) 
	RETURN data_browser_diagram_pipes.tab_object_list PIPELINED;	
end data_browser_diagram_utl;
/


CREATE OR REPLACE PACKAGE BODY data_browser_diagram_utl
IS 
	g_dg CONSTANT VARCHAR2(50) := q'[NLS_NUMERIC_CHARACTERS = '.,']';
	g_fmt CONSTANT VARCHAR2(50) := '999990D99999999999999999999999999';
	g_Data_Browser_Pattern CONSTANT VARCHAR2(4000) := 
		'%DATA_BROWSER%,AS_ZIP,MVBASE%,VBASE%,%CHANGE%LOG%,WECO%,APP%,USER_NAMESPACE%,USER_WORKSPACE%,USER_IMPORT_JOBS,'
		|| '%DELETE_CHECK%,SCHEMA_KEYCHAIN,CUSTOM_ADDLOG,DIAG%SHAPES%,DIAG%COLORS%,DIAG%NODES%,DIAG%EDGES%,SPRINGY_DIAGRAM%,%TABLES_IMP%,'
		|| 'IMPORT_UTL,UNZIP%,VUSER_TABLES_CHECK_IN_LIST,%USER_UI_DEFAULTS%,UPLOAD_TO_COLLECTION_PLUGIN,CLOB%AGG%,'
		|| 'AS_ZIP_SPECS,FN_HEX_HASH_KEY,FN_NAVIGATION_COUNTER,FN_NAVIGATION_MORE,FN_NAVIGATION_LINK,'
		|| 'FN_GET_APEX_ITEM_VALUE,FN_GET_APEX_ITEM_DATE_VALUE,FN_GET_APEX_ITEM_ROW_COUNT,INIT_APP_PREFERENCES,'	
		|| 'FN_NESTED_LINK,FN_TO_NUMBER,FN_NUMBER_TO_CHAR,FN_TO_DATE,FN_DETAIL_LINK,FN_BOLD_TOTAL,GEN_FOREIGN_KEYS_V,'
		|| 'USER_IMPORT_JOBS_PK,MVDATA_BROWS_TAB_SIMP_COLS_PK,VUNZIP_PARALLEL_PROGRESS,APEX_DYN_ACTIONS_DIAGRAM_V,CLOB_CONCAT%,'
		|| 'VUSER_TABLES_HR,VTABLES_ROOT,VCHANGLOG_EVENTS,V_ERROR_PROTOCOL,VUSER_TABLE_TIMSTAMPS,SET_CUSTOM_CTX_TRIG';

	PROCEDURE Load_Diagam_settings (
		p_SOURCE_TYPE			IN VARCHAR2,
		p_DIAGRAM_OWNER			IN VARCHAR2,
		p_DA_APPLICATION_ID		IN VARCHAR2,
		p_DA_PAGE_ID			IN VARCHAR2,
		p_DIAGRAM_ID			OUT VARCHAR2,
		p_DIAGRAM_FONTSIZE		OUT VARCHAR2,
		p_DIAGRAM_ZOOMFACTOR	OUT VARCHAR2, 
		p_DIAGRAM_X_OFFSET		OUT VARCHAR2, 
		p_DIAGRAM_Y_OFFSET		OUT VARCHAR2,
		p_CANVAS_WIDTH			OUT VARCHAR2, 
		p_EXCLUDE_SINGLES		OUT VARCHAR2, 
		p_DIAGRAM_LABELS		OUT VARCHAR2,
		p_EXCITE_METHOD			OUT VARCHAR2,
		p_STIFFNESS				OUT VARCHAR2, 
		p_REPULSION				OUT VARCHAR2, 
		p_DAMPING				OUT VARCHAR2, 
		p_MINENERGYTHRESHOLD	OUT VARCHAR2, 
		p_MAXSPEED				OUT VARCHAR2,
		p_PINWEIGHT				OUT VARCHAR2
	)
	is 
	begin
		begin
			if p_SOURCE_TYPE = 'TABLES' then
				p_DIAGRAM_ID := 'DB_ER';
			elsif p_SOURCE_TYPE = 'DEPENDENCIES' then
				if p_DIAGRAM_OWNER != SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then
					p_DIAGRAM_ID := 'DB_OBJ_' || p_DIAGRAM_OWNER;
				else
					p_DIAGRAM_ID := 'DB_OBJ';
				end if;
			elsif p_SOURCE_TYPE = 'DYNAMIC_ACTIONS' then
				p_DIAGRAM_ID := 'APEX_DA'|| p_DA_APPLICATION_ID || '_' || p_DA_PAGE_ID;
			end if;
			SELECT 
				LTRIM(TO_CHAR(FONTSIZE, g_fmt, g_dg)), 
				LTRIM(TO_CHAR(ZOOM_FACTOR, g_fmt, g_dg)), 
				LTRIM(TO_CHAR(X_OFFSET, g_fmt, g_dg)), 
				LTRIM(TO_CHAR(Y_OFFSET, g_fmt, g_dg)),
				CANVAS_WIDTH, EXCLUDE_SINGLES, EDGE_LABELS,
				LTRIM(TO_CHAR(STIFFNESS, '999990D9', g_dg)),
				LTRIM(TO_CHAR(REPULSION, '999990D9', g_dg)),
				LTRIM(TO_CHAR(NVL(DAMPING, 0.35), g_fmt, g_dg)),
				LTRIM(TO_CHAR(MINENERGYTHRESHOLD, '999990D9999999999', g_dg)),
				LTRIM(TO_CHAR(MAXSPEED, '999990D9', g_dg)),
				TO_CHAR(PINWEIGHT),
				EXCITE_METHOD
			INTO p_DIAGRAM_FONTSIZE, p_DIAGRAM_ZOOMFACTOR, p_DIAGRAM_X_OFFSET, p_DIAGRAM_Y_OFFSET,
				p_CANVAS_WIDTH, p_EXCLUDE_SINGLES, p_DIAGRAM_LABELS,
				p_STIFFNESS, p_REPULSION, p_DAMPING, p_MINENERGYTHRESHOLD, p_MAXSPEED, 
				p_PINWEIGHT, p_EXCITE_METHOD
			FROM DATA_BROWSER_DIAGRAM
			WHERE DIAGRAM_ID = p_DIAGRAM_ID;
		exception when NO_DATA_FOUND then
			SELECT '0' FONTSIZE, '1.0' ZOOM_FACTOR, 0 X_OFFSET, 0 Y_OFFSET, 
				null CANVAS_WIDTH, 'NO' EXCLUDE_SINGLES, 'YES' EDGE_LABELS,
				-- '400.0' STIFFNESS, '4000.0' REPULSION, '0.36' DAMPING, '0.01' MINENERGYTHRESHOLD, '50.0' MAXSPEED, 
				'1500.0' STIFFNESS, '10000.0' REPULSION, '0.32' DAMPING, '1.0' MINENERGYTHRESHOLD, 
				'50.0' MAXSPEED, '10' PINWEIGHT,
				case when p_SOURCE_TYPE = 'DYNAMIC_ACTIONS' then 'downstream' 
					when p_SOURCE_TYPE = 'TABLES' then 'upstream'
					else 'none' 
				end EXCITE_METHOD
			INTO p_DIAGRAM_FONTSIZE, p_DIAGRAM_ZOOMFACTOR, p_DIAGRAM_X_OFFSET, p_DIAGRAM_Y_OFFSET,
				p_CANVAS_WIDTH, p_EXCLUDE_SINGLES, p_DIAGRAM_LABELS,
				p_STIFFNESS,p_REPULSION,p_DAMPING,p_MINENERGYTHRESHOLD,p_MAXSPEED, 
				p_PINWEIGHT, p_EXCITE_METHOD
			FROM DUAL;
		end;
		p_MAXSPEED      := TO_CHAR(GREATEST(LEAST(NVL(TO_NUMBER(p_MAXSPEED, '999990D9', g_dg), 80), 200), 1), '999990D9', g_dg);

		if apex_application.g_debug then
			apex_debug.message(
				p_message => 
				'data_browser_diagram_utl.Load_Diagam_settings(p_SOURCE_TYPE => %s, p_DIAGRAM_OWNER => %s, p_DA_APPLICATION_ID => %s, p_DA_PAGE_ID => %s,' || chr(10)
				|| 'p_DIAGRAM_ID => %s, p_DIAGRAM_FONTSIZE => %s, p_DIAGRAM_ZOOMFACTOR => %s, ' || chr(10)
				|| 'p_DIAGRAM_X_OFFSET => %s, p_DIAGRAM_Y_OFFSET => %s, p_CANVAS_WIDTH => %s, p_EXCLUDE_SINGLES => %s, ' || chr(10)
				|| 'p_DIAGRAM_LABELS => %s, p_EXCITE_METHOD => %s, p_STIFFNESS => %s, p_REPULSION => %s, p_DAMPING => %s,' || chr(10)
				|| 'p_MINENERGYTHRESHOLD => %s, p_MAXSPEED => %s, p_PINWEIGHT => %s) ',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_SOURCE_TYPE),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_OWNER),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DA_APPLICATION_ID),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DA_PAGE_ID),
				p4 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_ID),
				p5 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_FONTSIZE),
				p6 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_ZOOMFACTOR),
				p7 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_X_OFFSET),
				p8 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_Y_OFFSET),
				p9 => DBMS_ASSERT.ENQUOTE_LITERAL(p_CANVAS_WIDTH),
				p10 => DBMS_ASSERT.ENQUOTE_LITERAL(p_EXCLUDE_SINGLES),
				p11 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_LABELS),
				p12 => DBMS_ASSERT.ENQUOTE_LITERAL(p_EXCITE_METHOD),
				p13 => DBMS_ASSERT.ENQUOTE_LITERAL(p_STIFFNESS),
				p14 => DBMS_ASSERT.ENQUOTE_LITERAL(p_REPULSION),
				p15 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DAMPING),
				p16 => DBMS_ASSERT.ENQUOTE_LITERAL(p_MINENERGYTHRESHOLD),
				p17 => DBMS_ASSERT.ENQUOTE_LITERAL(p_MAXSPEED),
				p18 => DBMS_ASSERT.ENQUOTE_LITERAL(p_PINWEIGHT),
				p_max_length => 3500
				-- , p_level => apex_debug.c_log_level_app_trace
			);
		end if; 

	end Load_Diagam_settings;

	PROCEDURE Load_Diagam_controls (
		p_STIFFNESS				IN VARCHAR2, 
		p_REPULSION				IN VARCHAR2, 
		p_DAMPING				IN VARCHAR2, 
		p_MINENERGYTHRESHOLD	IN VARCHAR2, 
		p_MAXSPEED				IN VARCHAR2, 
		p_STIFFNESS_D			OUT VARCHAR2,
		p_REPULSION_D 			OUT VARCHAR2,
		p_DAMPING_D				OUT VARCHAR2,
		p_MINENERGYTHRESHOLD_D	OUT VARCHAR2,
		p_MAXSPEED_D			OUT VARCHAR2
	)
	is 
	begin
		p_STIFFNESS_D   :=  p_STIFFNESS;
		p_REPULSION_D   := p_REPULSION;
		p_DAMPING_D     := TO_CHAR(100.0 - (TO_NUMBER(p_DAMPING, g_fmt, g_dg ) * (100.0/0.4)), g_fmt, g_dg) ;
		p_MINENERGYTHRESHOLD_D := TO_CHAR(floor(log(10, TO_NUMBER(p_MINENERGYTHRESHOLD, '999990D9999999999', g_dg ))), '999990D9999999999', g_dg ) ;
		p_MAXSPEED_D      := TO_CHAR(GREATEST(LEAST(NVL(TO_NUMBER(p_MAXSPEED, '999990D9', g_dg), 80), 200), 1), '999990D9', g_dg);
	end Load_Diagam_controls;

	PROCEDURE Save_Diagam_controls (
		p_STIFFNESS_D			IN VARCHAR2, 
		p_REPULSION_D			IN VARCHAR2, 
		p_DAMPING_D				IN VARCHAR2, 
		p_MINENERGYTHRESHOLD_D	IN VARCHAR2, 
		p_MAXSPEED_D			IN VARCHAR2, 
		p_STIFFNESS				OUT VARCHAR2,
		p_REPULSION 			OUT VARCHAR2,
		p_DAMPING				OUT VARCHAR2,
		p_MINENERGYTHRESHOLD	OUT VARCHAR2,
		p_MAXSPEED				OUT VARCHAR2
	)
	is 
	begin
		p_STIFFNESS   := p_STIFFNESS_D;
		p_REPULSION   := p_REPULSION_D;
		p_DAMPING     := TO_CHAR((100.0 - TO_NUMBER(p_DAMPING_D, g_fmt, g_dg )) / (100.0/0.4), g_fmt, g_dg );
		p_MINENERGYTHRESHOLD := TO_CHAR(POWER(10, TO_NUMBER(p_MINENERGYTHRESHOLD_D, g_fmt, g_dg )), g_fmt, g_dg );
		p_MAXSPEED    := p_MAXSPEED_D;
	end Save_Diagam_controls;
	
	PROCEDURE Save_Canvas_Positions (
		p_DIAGRAM_ID			IN VARCHAR2,
		p_DIAGRAM_FONTSIZE		IN VARCHAR2,
		p_DIAGRAM_ZOOMFACTOR	IN VARCHAR2, 
		p_DIAGRAM_X_OFFSET		IN VARCHAR2, 
		p_DIAGRAM_Y_OFFSET		IN VARCHAR2,
		p_CANVAS_WIDTH			IN VARCHAR2, 
		p_EXCLUDE_SINGLES		IN VARCHAR2, 
		p_DIAGRAM_LABELS		IN VARCHAR2,
		p_STIFFNESS				IN VARCHAR2,
		p_REPULSION				IN VARCHAR2,
		p_DAMPING				IN VARCHAR2,
		p_MINENERGYTHRESHOLD	IN VARCHAR2,
		p_MAXSPEED				IN VARCHAR2,
		p_REQUEST				IN VARCHAR2,
		p_PINWEIGHT				IN VARCHAR2,
		p_EXCITE_METHOD			IN VARCHAR2
	)
	is 
		v_DIAGRAM_FONTSIZE		VARCHAR2(50) := p_DIAGRAM_FONTSIZE;
		v_DIAGRAM_ZOOMFACTOR	VARCHAR2(50) := p_DIAGRAM_ZOOMFACTOR;
		v_PINWEIGHT				VARCHAR2(50) := p_PINWEIGHT;
		v_EXCITE_METHOD			VARCHAR2(50) := p_EXCITE_METHOD;
	begin
		if apex_application.g_debug then
			apex_debug.message(
				p_message => 
				'data_browser_diagram_utl.Save_Canvas_Positions(p_DIAGRAM_ID => %s, p_DIAGRAM_FONTSIZE => %s, p_DIAGRAM_ZOOMFACTOR => %s, ' || chr(10)
				|| 'p_DIAGRAM_X_OFFSET => %s, p_DIAGRAM_Y_OFFSET => %s, p_CANVAS_WIDTH => %s, p_EXCLUDE_SINGLES => %s, ' || chr(10)
				|| 'p_DIAGRAM_LABELS => %s, p_STIFFNESS => %s, p_REPULSION => %s, p_DAMPING => %s, p_MINENERGYTHRESHOLD => %s,' || chr(10)
				|| 'p_MAXSPEED => %s, p_REQUEST => %s, p_PINWEIGHT => %s, p_EXCITE_METHOD => %s) ',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_ID),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_FONTSIZE),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_ZOOMFACTOR),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_X_OFFSET),
				p4 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_Y_OFFSET),
				p5 => DBMS_ASSERT.ENQUOTE_LITERAL(p_CANVAS_WIDTH),
				p6 => DBMS_ASSERT.ENQUOTE_LITERAL(p_EXCLUDE_SINGLES),
				p7 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_LABELS),
				p8 => DBMS_ASSERT.ENQUOTE_LITERAL(p_STIFFNESS),
				p9 => DBMS_ASSERT.ENQUOTE_LITERAL(p_REPULSION),
				p10 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DAMPING),
				p11 => DBMS_ASSERT.ENQUOTE_LITERAL(p_MINENERGYTHRESHOLD),
				p12 => DBMS_ASSERT.ENQUOTE_LITERAL(p_MAXSPEED),
				p13 => DBMS_ASSERT.ENQUOTE_LITERAL(p_REQUEST),
				p14 => DBMS_ASSERT.ENQUOTE_LITERAL(p_PINWEIGHT),
				p15 => DBMS_ASSERT.ENQUOTE_LITERAL(p_EXCITE_METHOD),
				p_max_length => 3500
				-- , p_level => apex_debug.c_log_level_app_trace
			);
		end if; 

		if p_REQUEST = 'LOCK' then
			v_PINWEIGHT := 10000;
		elsif p_REQUEST = 'UNLOCK' then
			v_PINWEIGHT := 10;
		elsif p_REQUEST = 'EXEMPT' then
			v_EXCITE_METHOD := 'none';
			v_DIAGRAM_FONTSIZE := '0';
		elsif p_REQUEST = 'SHOW_ALL' then
			v_DIAGRAM_FONTSIZE := '0';
		end if;
		UPDATE DATA_BROWSER_DIAGRAM
		SET (FONTSIZE, ZOOM_FACTOR, X_OFFSET, Y_OFFSET, EXCLUDE_SINGLES, EDGE_LABELS, 
			 CANVAS_WIDTH, STIFFNESS, REPULSION, DAMPING, 
			 MINENERGYTHRESHOLD, MAXSPEED, PINWEIGHT, EXCITE_METHOD) = (
			   SELECT NVL(numbers_utl.JS_To_Number(v_DIAGRAM_FONTSIZE ), 4), 
					 numbers_utl.JS_To_Number(v_DIAGRAM_ZOOMFACTOR ), 
					 numbers_utl.JS_To_Number(p_DIAGRAM_X_OFFSET ), 
					 numbers_utl.JS_To_Number(p_DIAGRAM_Y_OFFSET ),
					 NVL(p_EXCLUDE_SINGLES, EXCLUDE_SINGLES),
                     NVL(p_DIAGRAM_LABELS, 'YES'),
					 numbers_utl.JS_To_Number(p_CANVAS_WIDTH ),
					 numbers_utl.JS_To_Number(p_STIFFNESS ), 
					 numbers_utl.JS_To_Number(p_REPULSION ), 
					 numbers_utl.JS_To_Number(p_DAMPING ), 
					 numbers_utl.JS_To_Number(p_MINENERGYTHRESHOLD ), 
					 numbers_utl.JS_To_Number(p_MAXSPEED ), 
					 numbers_utl.JS_To_Number(v_PINWEIGHT ), 
					 v_EXCITE_METHOD
				FROM DUAL
			 )
		WHERE DIAGRAM_ID = p_DIAGRAM_ID;
		if SQL%ROWCOUNT = 0 then
			INSERT INTO DATA_BROWSER_DIAGRAM(
					DIAGRAM_ID, FONTSIZE, ZOOM_FACTOR, X_OFFSET, Y_OFFSET, EXCLUDE_SINGLES, EDGE_LABELS,
					CANVAS_WIDTH, STIFFNESS, REPULSION, DAMPING, MINENERGYTHRESHOLD, 
					MAXSPEED, PINWEIGHT, EXCITE_METHOD) 
			SELECT p_DIAGRAM_ID, 
				   NVL(numbers_utl.JS_To_Number(v_DIAGRAM_FONTSIZE ), 4), 
				   numbers_utl.JS_To_Number(v_DIAGRAM_ZOOMFACTOR ), 
				   numbers_utl.JS_To_Number(p_DIAGRAM_X_OFFSET ), 
				   numbers_utl.JS_To_Number(p_DIAGRAM_Y_OFFSET ),
				   NVL(p_EXCLUDE_SINGLES, 'NO'), 
				   NVL(p_DIAGRAM_LABELS, 'YES'),
				   numbers_utl.JS_To_Number(p_CANVAS_WIDTH ), 
				   numbers_utl.JS_To_Number(p_STIFFNESS ),
				   numbers_utl.JS_To_Number(p_REPULSION ),
				   numbers_utl.JS_To_Number(p_DAMPING ),
				   numbers_utl.JS_To_Number(p_MINENERGYTHRESHOLD ),
				   numbers_utl.JS_To_Number(p_MAXSPEED ),
				   numbers_utl.JS_To_Number(v_PINWEIGHT ), 
				   v_EXCITE_METHOD
			FROM DUAL;
		end if;
        COMMIT;
	end Save_Canvas_Positions;

$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PROCEDURE Save_Node_Coordinates (
		p_DIAGRAM_ID			IN VARCHAR2,
		p_REQUEST				IN VARCHAR2
	)
	is
		l_query VARCHAR2(2000);
	begin
		l_query := 
		q'{SELECT jt.*
		FROM (select CLOB001 CLOB_CONTENT
			from APEX_COLLECTIONS
			where COLLECTION_NAME = 'CLOB_CONTENT'
		), JSON_TABLE(CLOB_CONTENT, '$[*]' COLUMNS (
			id VARCHAR2(64) PATH '$.id', 
			x_coordinate VARCHAR2(32) PATH '$.x', 
			y_coordinate VARCHAR2(32) PATH '$.y',
			mass VARCHAR2(20) PATH '$.mass',
			active VARCHAR2(6) PATH '$.active'
		   )
		) AS jt}'; 
		if APEX_COLLECTION.COLLECTION_EXISTS(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD') then 
			APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD');
		end if;

		declare
			e_20104 exception;
			pragma exception_init(e_20104, -20104);
		begin
			APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
				p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD', 
				p_query => l_query
			);
		exception
			when e_20104 then null;
		end;

		MERGE INTO DATA_BROWSER_DIAGRAM_COORD D
		USING (
			SELECT p_DIAGRAM_ID DIAGRAM_ID, 
				ID OBJECT_ID, 
				TO_NUMBER(X_COORDINATE, '999990D99999999999999999999999999', g_dg) X_COORDINATE,
				TO_NUMBER(Y_COORDINATE, '999990D99999999999999999999999999', g_dg) Y_COORDINATE,
				TO_NUMBER(MASS, '999990D99999999999999999999999999', g_dg) MASS,
				case when p_REQUEST = 'EXEMPT' and ACTIVE = 'false' then 'N' 
				   when p_REQUEST = 'HIDE' and ACTIVE = 'true' then 'N' 
				   else 'Y' 
			   end ACTIVE
			FROM (select DISTINCT C001 ID, C002 X_COORDINATE, C003 Y_COORDINATE, C004 MASS, C005 ACTIVE
				from APEX_COLLECTIONS
				where COLLECTION_NAME = 'DATA_BROWSER_DIAGRAM_COORD'
			)
		) S
		ON (D.DIAGRAM_ID = S.DIAGRAM_ID AND D.OBJECT_ID = S.OBJECT_ID)
		WHEN MATCHED THEN
			UPDATE SET D.X_COORDINATE = S.X_COORDINATE, D.Y_COORDINATE = S.Y_COORDINATE, 
				D.MASS = S.MASS, D.ACTIVE = S.ACTIVE
		WHEN NOT MATCHED THEN
			INSERT (D.DIAGRAM_ID, D.OBJECT_ID, D.X_COORDINATE, D.Y_COORDINATE, 
				D.MASS, D.ACTIVE)
			VALUES (S.DIAGRAM_ID, S.OBJECT_ID, S.X_COORDINATE, S.Y_COORDINATE, 
				S.MASS, S.ACTIVE)
		;
		if p_REQUEST IN ('SHOW_ALL', 'LOCK', 'UNLOCK') then 
			UPDATE DATA_BROWSER_DIAGRAM_COORD 
				SET ACTIVE = case when p_REQUEST = 'SHOW_ALL' then 'Y' else ACTIVE end,
					MASS = case when p_REQUEST = 'LOCK' then 10000 when p_REQUEST = 'UNLOCK' then 1 else MASS end
			WHERE DIAGRAM_ID = p_DIAGRAM_ID;
		end if;
		APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD');
		COMMIT;
	end Save_Node_Coordinates;
$ELSE
	PROCEDURE Save_Node_Coordinates (
		p_DIAGRAM_ID			IN VARCHAR2,
		p_REQUEST				IN VARCHAR2
	)	-- Ora10
	is 
		j APEX_JSON.t_values; 
		r_count number(10);
		p0 number(10);  
		l_elem   wwv_flow_t_varchar2;
		l_json clob;
		l_x_coordinate number;
		l_y_coordinate number;
		l_value_node_id varchar2(64);
		l_value_mass number;
	BEGIN
		if apex_collection.collection_exists(p_collection_name=>'CLOB_CONTENT') then
			SELECT CLOB001 INTO l_json
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = 'CLOB_CONTENT';
		end if;
		if APEX_COLLECTION.COLLECTION_EXISTS(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD') then 
			APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD');
		end if;
		APEX_COLLECTION.CREATE_COLLECTION(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD');
		if l_json is not null then   
			APEX_JSON.parse(j, l_json);
			r_count := APEX_JSON.GET_COUNT(p_path=>'.',p_values=>j);
			dbms_output.put_line('Nr Records: ' || r_count);
			FOR i IN 1 .. r_count LOOP
				 l_value_node_id := apex_json.get_varchar2(p_path=>'[%d].id',p_values=>j, p0=>i); 
				 l_x_coordinate := apex_json.get_number(p_path=>'[%d].x',p_values=>j, p0=>i); 
				 l_y_coordinate := apex_json.get_number(p_path=>'[%d].y',p_values=>j, p0=>i); 
				 l_value_mass := apex_json.get_number(p_path=>'[%d].mass',p_values=>j, p0=>i); 
				 APEX_COLLECTION.ADD_MEMBER(
					p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD',
					p_c001 => l_value_node_id,
					p_n002 => l_x_coordinate,
					p_n003 => l_y_coordinate, 
					p_n004 => l_value_mass 
				);
			END LOOP; 
			MERGE INTO DATA_BROWSER_DIAGRAM_COORD D
			USING (
				SELECT p_DIAGRAM_ID DIAGRAM_ID, OBJECT_ID, X_COORDINATE, Y_COORDINATE, MASS
				FROM (select DISTINCT C001 OBJECT_ID, N002 X_COORDINATE, N003 Y_COORDINATE, N004 MASS
						from APEX_COLLECTIONS
						where COLLECTION_NAME = 'DATA_BROWSER_DIAGRAM_COORD'
				) 
			) S
			ON (D.DIAGRAM_ID = S.DIAGRAM_ID AND D.OBJECT_ID = S.OBJECT_ID)
			WHEN MATCHED THEN
				UPDATE SET D.X_COORDINATE = S.X_COORDINATE, 
					D.Y_COORDINATE = S.Y_COORDINATE, 
					D.MASS = S.MASS
			WHEN NOT MATCHED THEN
				INSERT (D.DIAGRAM_ID, D.OBJECT_ID, D.X_COORDINATE, D.Y_COORDINATE, 
					D.MASS)
				VALUES (S.DIAGRAM_ID, S.OBJECT_ID, S.X_COORDINATE, S.Y_COORDINATE, 
					S.MASS)
			;
			APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DATA_BROWSER_DIAGRAM_COORD');
			COMMIT;
		end if;   
	END Save_Node_Coordinates;
$END

	PROCEDURE Database_ER_Diagramm_JS(
		p_Exclude_Singles		IN VARCHAR2 DEFAULT 'YES',
		p_Diagramm_Labels		IN VARCHAR2 DEFAULT 'NO'
	)
	IS
		lv_RESULT				SYS_REFCURSOR;
		l_TEXTLINE				VARCHAR2(500);
		l_LINENO				VARCHAR2(20);
		v_Stat					CLOB;
		v_seq_id				INTEGER;
	BEGIN
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>'CLOB_CONTENT');
		exception
		  when dup_val_on_index then null;
		end;

		OPEN lv_RESULT FOR
		SELECT DISTINCT DIGRAPH, L
		FROM (
			SELECT 'var graph = new Springy.Graph();' DIGRAPH, 0 L
			FROM DUAL
			UNION
			SELECT DISTINCT
				'var n' || TX.VIEW_NAME || ' = graph.newNode({label: ' || dbms_assert.enquote_literal(TX.NAME) 
				|| ', name: ' || dbms_assert.enquote_literal(TX.VIEW_NAME)
				|| ', shape: ' || dbms_assert.enquote_literal(FIRST_VALUE(TX.SHAPE) OVER (PARTITION BY VIEW_NAME ORDER BY RANG DESC))
				|| case when TC.X_COORDINATE IS NOT NULL then 
						', x: ' || ltrim(to_char(X_COORDINATE, 'TM9', g_dg))
						|| ', y: ' || ltrim(to_char(Y_COORDINATE, 'TM9', g_dg))
						|| ', mass: ' || ltrim(to_char(MASS, 'TM9', g_dg))
				end
				|| '}); ' NODE,
				10	L
			FROM (
				WITH TABLE_SET AS (
					SELECT REPLACE(S.VIEW_NAME, ' ', '_') VIEW_NAME, 
						data_browser_conf.Table_Name_To_Header(VIEW_NAME) NAME,
						S.REFERENCES_COUNT, S.NUM_ROWS, S.IS_ADMIN_TABLE
					FROM MVDATA_BROWSER_VIEWS S
					WHERE (S.IS_ADMIN_TABLE = 'N' or V('APP_DEVELOPER_MODE') = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
					AND (
						S.REFERENCES_COUNT > 0 
						OR EXISTS (
							select 1
							from MVDATA_BROWSER_FKEYS R
							where R.VIEW_NAME != R.R_VIEW_NAME
							and S.TABLE_NAME IN (R.TABLE_NAME, R.R_TABLE_NAME)
							and S.TABLE_OWNER = R.OWNER
						) 
						OR p_Exclude_Singles = 'NO'
					)
				)
				SELECT	VIEW_NAME, NAME, 
					case when REFERENCES_COUNT > 0 
						then 'octagon' else 'ellipse'
					end SHAPE, 
					case when REFERENCES_COUNT > 0 
						then 2 else 3
					end RANG
				FROM TABLE_SET A
				WHERE (IS_ADMIN_TABLE = 'N' OR data_browser_conf.Get_Admin_Enabled = 'Y')
			) TX
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TC 
				ON TX.VIEW_NAME = TC.OBJECT_ID AND TC.DIAGRAM_ID = 'DB_ER'
			WHERE (TC.ACTIVE = 'Y' OR TC.ACTIVE IS NULL)
			UNION 
			SELECT DISTINCT
				'graph.newEdge(n' || TX.VIEW_NAME || ', n' || TX.R_VIEW_NAME || ', {' ||
					case when p_DIAGRAMM_LABELS != 'NO' then
						'label: ' || dbms_assert.enquote_literal(TX.LABEL) || ', '
					end
					|| 'color: ' || dbms_assert.enquote_literal(TX.COLOR)  || ' '
					|| '});' DIGRAPH,
					1000 L
			FROM (
				WITH TABLE_SET AS (
					SELECT REPLACE(S.VIEW_NAME, ' ', '_') VIEW_NAME, 
						   REPLACE(T.R_VIEW_NAME, ' ', '_') R_VIEW_NAME, 
						case when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'N' then 'Container'
								when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'Y' then 'Dependent'
								when T.DELETE_RULE = 'SET NULL' and FK_NULLABLE = 'Y' then 'Nullable'
								when FK_NULLABLE = 'N' then 'Required'
								else 'Optional'
						end LABEL,
						case when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'N' then 'SeaGreen'
								when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'Y' then 'DarkSalmon'
								when T.DELETE_RULE = 'SET NULL' and FK_NULLABLE = 'Y' then 'CornflowerBlue'
								when FK_NULLABLE = 'N' then 'Coral'
								else 'Gray'
						end COLOR, 
						DELETE_RULE
					FROM MVDATA_BROWSER_VIEWS S
					JOIN (
						select VIEW_NAME, R_VIEW_NAME, FOREIGN_KEY_COLS, DELETE_RULE, FK_NULLABLE
						from MVDATA_BROWSER_FKEYS
						where VIEW_NAME != R_VIEW_NAME
					) T on S.VIEW_NAME = T.VIEW_NAME
					JOIN MVDATA_BROWSER_VIEWS E ON E.VIEW_NAME = T.R_VIEW_NAME
					WHERE (S.IS_ADMIN_TABLE = 'N' or V('APP_DEVELOPER_MODE') = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
					AND (E.IS_ADMIN_TABLE = 'N' or V('APP_DEVELOPER_MODE') = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
				)
				-------------------------------------------------------
				SELECT	VIEW_NAME, R_VIEW_NAME, LABEL, COLOR, 1 RANG
					FROM TABLE_SET TX
				LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TS 
					ON TX.VIEW_NAME = TS.OBJECT_ID AND TS.DIAGRAM_ID = 'DB_ER'
				LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TT 
					ON TX.R_VIEW_NAME = TT.OBJECT_ID AND TT.DIAGRAM_ID = 'DB_ER'
				WHERE (TS.ACTIVE = 'Y' OR TS.ACTIVE IS NULL)
				AND (TT.ACTIVE = 'Y' OR TT.ACTIVE IS NULL)
			) TX
		) TX
		ORDER BY L;
		LOOP
			FETCH lv_RESULT INTO l_TEXTLINE, l_LINENO; -- fetch next row
			EXIT WHEN lv_RESULT%NOTFOUND; -- exit loop when last row is fetched
			-- process row
			dbms_lob.writeappend(v_Stat, length(l_TEXTLINE), l_TEXTLINE);
		END LOOP;
		v_seq_id := apex_collection.add_member(p_collection_name => 'CLOB_CONTENT', p_clob001 => v_Stat);
		commit;
	END Database_ER_Diagramm_JS;

    FUNCTION DA_Shape(
    	p_Object_Type VARCHAR2
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
	BEGIN
		return case p_Object_Type 
			when 'D' 	then 'ellipse'
			when 'T' 	then 'house'
			when 'F' 	then 'invhouse'
			when 'J' 	then 'parallelogram'
			when 'C' 	then 'trapezium'
			when 'X' 	then 'trapezium'
			when 'E' 	then 'trapezium' 
			when 'N' 	then 'trapezium' 
			when 'H' 	then 'trapezium' 
			when 'A' 	then 'righttriangle'
			when 'K' 	then 'righttriangle'
			when 'G' 	then 'righttriangle'
			when 'R' 	then 'doubleoctagon'
			when 'M' 	then 'tab'
			when 'B' 	then 'octagon'
			when 'Q' 	then 'octagon'
			when 'I' 	then 'box'
			when 'P'    then 'star'
			when 'L' 	then 'righttriangle'
			else 'box'  
		end;
    END DA_Shape;

    FUNCTION DA_Color(
    	p_Object_Type VARCHAR2,
    	p_Color VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
	BEGIN
		return case when p_Object_Type = 'D' then 'Khaki'
			when p_Object_Type = 'B' then 'Plum'
			when p_Object_Type = 'Q' then 'Orange'
			when p_Object_Type = 'R' then 'BurlyWood'
			when p_Object_Type = 'M' then 'BurlyWood'
			when p_Object_Type = 'J' then 'MediumAquamarine'
			when p_Object_Type IN ('C', 'X', 'E', 'N', 'H') then NVL(p_Color, 'MistyRose')
			when p_Object_Type IN ('T', 'F') then 'PowderBlue'
			when p_Object_Type = 'P' then 'LightCyan'
			when p_Object_Type IN ('A', 'K', 'G') then 'LightSkyBlue'
			when p_Object_Type = 'L' then 'YellowGreen'
			when p_Object_Type = 'I' then 'YellowGreen'
			else 'YellowGreen'
		end;
    END DA_Color;

    FUNCTION DA_Insulator(
    	p_Object_Type VARCHAR2,
    	p_Source_Node VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2
    IS
	PRAGMA UDF;
	BEGIN
		return case when p_Object_Type IN ('C', 'X') and p_Source_Node IN ('Hide', 'Show','Enable','Disable')
		or p_Object_Type IN ('B', 'R') then 'Y' else 'N' end;
    END DA_Insulator;

	PROCEDURE Dynamic_Actions_Diagram_JS(
		p_Application_ID IN NUMBER DEFAULT NV('APP_ID'),
		p_Page_ID IN NUMBER DEFAULT NV('APP_PAGE_ID'),
		p_Diagramm_Name IN VARCHAR2 DEFAULT 'APEX_DA',
		p_Diagramm_Labels IN VARCHAR2 DEFAULT 'NO'
	)
	IS
		lv_RESULT               SYS_REFCURSOR;
		l_TEXTLINE 				VARCHAR2(4000);
		l_LINENO 				VARCHAR2(20);
		v_Stat 					CLOB;
		v_seq_id     			INTEGER;
	BEGIN
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>'CLOB_CONTENT');
		exception
		  when dup_val_on_index then null;
		end;
	/*
		Object Encoding 
		'D','J','F','T'	APEX_APPLICATION_PAGE_DA		DYNAMIC_ACTION_ID
		'C'				APEX_APPLICATION_PAGE_DA_ACTS	ACTION_ID
		'B',			APEX_APPLICATION_PAGE_BUTTONS	BUTTON_ID
		'Q'				APEX_APPLICATION_PAGE_BUTTONS	BUTTON_NAME
		'M'				APEX_APPLICATION_LISTS			LIST_ID			-- Menu
		'R'				APEX_APPLICATION_PAGE_REGIONS	REGION_ID
		'P'				APEX_APPLICATION_PAGE_PROC		PROCESS_POINT_CODE
		'I'				APEX_APPLICATION_PAGE_ITEMS		ITEM_NAME
		'X'				APEX_APPLICATION_PAGE_PROC		PROCESS_ID
		'L'				APEX_APPLICATION_PAGE_BRANCHES	BRANCH_ID
		'A','E'			APEX_APPLICATION_LIST_ENTRIES	LIST_ENTRY_ID	-- Link / Javascript
	*/
		OPEN lv_RESULT FOR
		WITH TABLE_SET AS (
			SELECT SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, EDGE_LABEL, DEST_NODE, DEST_ID, DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT 
			  from data_browser_diagram_pipes.FN_Pipe_apex_dyn_actions(p_Application_ID, p_Page_ID)
		)
		SELECT DISTINCT DIGRAPH, L
		FROM (
			SELECT 'var graph = new Springy.Graph();' DIGRAPH, 0 L
			FROM DUAL 
			UNION
			SELECT DISTINCT
				'var n' || TX.SOURCE_ID 
					|| ' = graph.newNode({label: ' || chr(39)||replace(TX.SOURCE_NODE, chr(39), chr(92)||chr(39))||chr(39)
					|| ', name: ' || chr(39)||replace(TX.SOURCE_ID, chr(39), chr(92)||chr(39))||chr(39)
					|| ', shape: ' || chr(39)||replace(TX.SHAPE, chr(39), chr(92)||chr(39))||chr(39) 
					|| ', color: ' || chr(39)||replace(TX.COLOR, chr(39), chr(92)||chr(39))||chr(39) 
					|| case when TC.X_COORDINATE IS NOT NULL then 
						', x: ' || ltrim(to_char(X_COORDINATE, 'TM9', g_dg))
						|| ', y: ' || ltrim(to_char(Y_COORDINATE, 'TM9', g_dg))
						|| ', mass: ' || ltrim(to_char(MASS, 'TM9', g_dg))
					end
					|| case when TX.INSULATOR = 'Y' then 
						', insulator: true'
					end
					|| '}); ' NODE,
					1 L
			FROM (
				SELECT SOURCE_ID,
					SOURCE_NODE, OBJECT_TYPE,
					data_browser_diagram_utl.DA_Shape(OBJECT_TYPE) SHAPE,
					data_browser_diagram_utl.DA_Color(OBJECT_TYPE, COLOR) COLOR,
					data_browser_diagram_utl.DA_Insulator(OBJECT_TYPE, SOURCE_NODE) INSULATOR
				FROM (
					SELECT  SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, 
						case when EXECUTE_ON_PAGE_INIT = 'Yes' then 'LightPink' end COLOR
					FROM TABLE_SET A
					UNION
					SELECT  DEST_ID, DEST_OBJECT_TYPE, DEST_NODE, 
						case when EXECUTE_ON_PAGE_INIT = 'Yes' then 'LightPink' end COLOR
					FROM TABLE_SET A
				) TX
			) TX
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TC 
				ON TX.SOURCE_ID = TC.OBJECT_ID AND TC.DIAGRAM_ID = p_Diagramm_Name
			WHERE (TC.ACTIVE = 'Y' OR TC.ACTIVE IS NULL)
			UNION ALL -- Verbindungen des Baums
			SELECT DISTINCT
				'graph.newEdge(n' || TX.NODE_NAME || ', n' || TX.TARGET_NODE_NAME || ', {' ||
					CASE WHEN p_Diagramm_Labels != 'NO' THEN
						'label: ' || dbms_assert.enquote_literal(TX.LABEL) || ', '
					ELSE NULL END
					|| 'color: ' || dbms_assert.enquote_literal(TX.COLOR) || ' '
					|| '});' DIGRAPH,
					(L+1000) L
			FROM (
				SELECT  SOURCE_ID NODE_NAME, DEST_ID TARGET_NODE_NAME, replace(EDGE_LABEL, chr(39)) LABEL, 'DarkGrey' COLOR, 2 L
				FROM TABLE_SET A
			) TX
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TS 
				ON TX.NODE_NAME = TS.OBJECT_ID AND TS.DIAGRAM_ID = p_Diagramm_Name
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TT 
				ON TX.TARGET_NODE_NAME = TT.OBJECT_ID AND TT.DIAGRAM_ID = p_Diagramm_Name
			WHERE (TS.ACTIVE = 'Y' OR TS.ACTIVE IS NULL)
			AND (TT.ACTIVE = 'Y' OR TT.ACTIVE IS NULL)
		) TX
		ORDER BY L;
		LOOP
			FETCH lv_RESULT INTO l_TEXTLINE, l_LINENO; -- fetch next row
			EXIT WHEN lv_RESULT%NOTFOUND; -- exit loop when last row is fetched
			-- process row
			dbms_lob.writeappend(v_Stat, length(l_TEXTLINE), l_TEXTLINE);
		END LOOP;
		v_seq_id := apex_collection.add_member(p_collection_name => 'CLOB_CONTENT', p_clob001 => v_Stat);
		commit;
	END Dynamic_Actions_Diagram_JS;

    FUNCTION DB_Shape(
    	p_Object_Type VARCHAR2
    ) RETURN VARCHAR2 
    IS
	PRAGMA UDF;
	BEGIN
		return case p_Object_Type 
			when 'FUNCTION' 			then 'ellipse'
			when 'TYPE' 				then 'house'
			when 'TYPE BODY' 			then 'invhouse'
			when 'PACKAGE' 				then 'house'
			when 'PACKAGE BODY' 		then 'invhouse'
			when 'PROCEDURE' 			then 'trapezium'
			when 'TABLE' 				then 'doubleoctagon'
			when 'VIEW' 				then 'octagon'
			when 'TRIGGER' 				then 'component'
			when 'MATERIALIZED VIEW' 	then 'octagon'
			else 'box'  
		end;
    END DB_Shape;

    FUNCTION DB_Color(
    	p_Object_Type VARCHAR2,
    	p_Color VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 
    IS
	PRAGMA UDF;
	BEGIN
		return case 
			when p_Color IS NOT NULL then p_Color
		else 
			case p_Object_Type
				when 'FUNCTION' 			then 'Aqua'
				when 'TYPE' 				then 'LightSkyBlue'
				when 'TYPE BODY' 			then 'LightSkyBlue'
				when 'PACKAGE' 				then 'LightSeaGreen'
				when 'PACKAGE BODY' 		then 'LightSeaGreen'
				when 'PROCEDURE' 			then 'DarkTurquoise'
				when 'TABLE' 				then 'Khaki'
				when 'VIEW' 				then 'PowderBlue'
				when 'TRIGGER' 				then 'LightSalmon'
				when 'MATERIALIZED VIEW' 	then 'Goldenrod'
				else 'YellowGreen'
			end
		END;
    END DB_Color;

	PROCEDURE Object_Dependencies_JS(
		p_Exclude_Pattern IN VARCHAR2 DEFAULT NULL,
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Diagramm_Labels IN VARCHAR2 DEFAULT 'NO',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Object_Types IN VARCHAR2 DEFAULT 'KEY CONSTRAINT:CHECK CONSTRAINT:NOT NULL CONSTRAINT:FUNCTION:INDEX:MATERIALIZED VIEW:PACKAGE:PACKAGE BODY:PROCEDURE:SEQUENCE:SYNONYM:TABLE:TRIGGER:TYPE:TYPE BODY:VIEW'
	)
	IS
		lv_RESULT               SYS_REFCURSOR;
		l_TEXTLINE 				VARCHAR2(4000);
		l_LINENO 				VARCHAR2(20);
		v_Diagram_ID			DATA_BROWSER_DIAGRAM_COORD.DIAGRAM_ID%TYPE;
		v_Stat 					CLOB;
		v_seq_id     			INTEGER;
		v_Exclude_Pattern		VARCHAR2(4000);
	BEGIN
		if apex_application.g_debug then
			APEX_DEBUG_MESSAGE.info (p_message => 'Object_Dependencies_JS (p_Exclude_Pattern => %s, p_Diagramm_Labels => %s, p_Include_App_Objects => %s, p_Include_External => %s, p_Include_Sys => %s, p_Object_Types => %s)',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Exclude_Pattern),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Diagramm_Labels),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Include_App_Objects),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Include_External),
				p4 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Include_Sys),
				p5 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Object_Types),
				p_max_length => 3500
			);
		end if;
		if p_Object_Owner != SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then
			v_Diagram_ID := 'DB_OBJ_' || p_Object_Owner;
		else
			v_Diagram_ID := 'DB_OBJ';
		end if;
	
		v_Exclude_Pattern := data_browser_conf.Normalize_Column_Pattern(p_Exclude_Pattern);
		if p_Include_App_Objects = 'NO' then 
			v_Exclude_Pattern := data_browser_conf.concat_list(data_browser_conf.Normalize_Column_Pattern(g_Data_Browser_Pattern), v_Exclude_Pattern, ',');
		end if;
	
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>'CLOB_CONTENT');
		exception
		  when dup_val_on_index then null;
		end;
		OPEN lv_RESULT FOR
		WITH DIAGRAM_EDGES AS (
			SELECT NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, 
				TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS,
				LABEL, TABLE_NAME, TARGET_TABLE_NAME 
			FROM data_browser_diagram_pipes.FN_Pipe_object_dependences(
				p_Exclude_Singles => p_Exclude_Singles,
				p_Include_App_Objects => p_Include_App_Objects,
				p_Include_External => p_Include_External,
				p_Include_Sys  => p_Include_Sys,
				p_Object_Owner => p_Object_Owner,
				p_Object_Types => p_Object_Types
			) TX
			WHERE NOT EXISTS (SELECT --+ NO_UNNEST
				1 FROM table(apex_string.split(v_Exclude_Pattern,','))
				WHERE (OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\')
			)
			AND NOT EXISTS (SELECT --+ NO_UNNEST
					1 
				FROM DATA_BROWSER_DIAGRAM_COORD TS
				WHERE TS.DIAGRAM_ID = v_Diagram_ID
				AND TS.ACTIVE = 'N'
				AND (TS.OBJECT_ID = TX.NODE_NAME
				 OR TS.OBJECT_ID = TX.TARGET_NODE_NAME) 
			)
		)
		SELECT DISTINCT DIGRAPH, L
		FROM (
			SELECT 'var graph = new Springy.Graph();' DIGRAPH, 0 L
			FROM DUAL
			-- Knoten
			UNION
			SELECT DISTINCT
				'var n' || TX.NODE_NAME 
					|| ' = graph.newNode({label: ' || dbms_assert.enquote_literal(TX.NAME) 
					|| ', name: ' || dbms_assert.enquote_literal(TX.NODE_NAME) 
					|| ', shape: ' || dbms_assert.enquote_literal(TX.SHAPE) 
					|| ', color: ' || dbms_assert.enquote_literal(TX.COLOR) || ' '
					|| case when TC.X_COORDINATE IS NOT NULL then 
						', x: ' || ltrim(to_char(X_COORDINATE, 'TM9', g_dg))
						|| ', y: ' || ltrim(to_char(Y_COORDINATE, 'TM9', g_dg))
						|| ', mass: ' || ltrim(to_char(MASS, 'TM9', g_dg))
					end
					|| '}); ' NODE,
					1 L
			FROM (
				SELECT NODE_NAME,
					case when OBJECT_OWNER != p_Object_Owner then 
						INITCAP(OBJECT_OWNER) || '.' end 
					|| INITCAP(OBJECT_NAME) NAME,
					data_browser_diagram_utl.DB_Shape(OBJECT_TYPE) SHAPE,
					data_browser_diagram_utl.DB_Color(OBJECT_TYPE, 
						case when OBJECT_OWNER != p_Object_Owner then 'Orchid'
							when STATUS = 'INVALID' then 'Red' end 
					) COLOR
				FROM (
					SELECT  NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, TABLE_NAME
					FROM DIAGRAM_EDGES 
					WHERE OBJECT_NAME IS NOT NULL
					UNION
					SELECT  TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS, TARGET_TABLE_NAME
					FROM DIAGRAM_EDGES 
				) TX
			) TX
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TC 
				ON TX.NODE_NAME = TC.OBJECT_ID AND TC.DIAGRAM_ID = v_Diagram_ID
			WHERE (TC.ACTIVE = 'Y' OR TC.ACTIVE IS NULL)
			UNION -- Verbindungen des Baums
			SELECT DISTINCT
				'graph.newEdge(n' || TX.NODE_NAME || ', n' || TX.TARGET_NODE_NAME || ', {' ||
					CASE WHEN p_Diagramm_Labels != 'NO' THEN
						'label: ' || dbms_assert.enquote_literal(TX.LABEL) || ', '
					ELSE NULL END
					|| 'color: ' || dbms_assert.enquote_literal('DarkGrey') || ' '
					|| '});' DIGRAPH,
					2 L
			FROM DIAGRAM_EDGES TX
			WHERE OBJECT_NAME IS NOT NULL
		) TX
		ORDER BY L;
		LOOP
			FETCH lv_RESULT INTO l_TEXTLINE, l_LINENO; -- fetch next row
			EXIT WHEN lv_RESULT%NOTFOUND; -- exit loop when last row is fetched
			-- process row
			dbms_lob.writeappend(v_Stat, length(l_TEXTLINE), l_TEXTLINE);
		END LOOP;
		v_seq_id := apex_collection.add_member(p_collection_name => 'CLOB_CONTENT', p_clob001 => v_Stat);
		commit;
	END Object_Dependencies_JS;

	PROCEDURE Save_Object_Dependencies_As (
		p_Exclude_Pattern IN VARCHAR2 DEFAULT NULL,
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Object_Types 			IN VARCHAR2,
		p_DIAGRAM_Name			IN VARCHAR2,
		p_Springy_Diagram_ID 	OUT NUMBER
	)
	is
		v_DIAGRAM_ID VARCHAR2(10) := 'DB_OBJ';
		v_Springy_Diagram_Id SPRINGY_DIAGRAMS.ID%TYPE;
		v_Exclude_Pattern		VARCHAR2(4000);
	begin
		v_Exclude_Pattern := data_browser_conf.Normalize_Column_Pattern(p_Exclude_Pattern);
		if p_Include_App_Objects = 'NO' then 
			v_Exclude_Pattern := data_browser_conf.concat_list(data_browser_conf.Normalize_Column_Pattern(g_Data_Browser_Pattern), v_Exclude_Pattern, ',');
		end if;
	
		DELETE FROM SPRINGY_DIAGRAMS WHERE description = p_DIAGRAM_Name;

		SELECT SPRINGY_DIAGRAMS_SEQ.NEXTVAL INTO v_Springy_Diagram_Id FROM DUAL;

		INSERT INTO springy_diagrams (
			id,
			description,
			fontsize,
			zoom_factor,
			x_offset,
			y_offset,
			canvas_width,
			exclude_singles,
			edge_labels,
			stiffness,
			repulsion,
			damping,
			minenergythreshold,
			maxspeed,
			excite_method)
		SELECT
			v_Springy_Diagram_Id id,
			NVL(p_DIAGRAM_Name, diagram_id || ' ' || SYSDATE) description,
			fontsize,
			zoom_factor,
			x_offset,
			y_offset,
			canvas_width,
			exclude_singles,
			edge_labels,
			stiffness,
			repulsion,
			damping,
			minenergythreshold,
			maxspeed,
			excite_method
		FROM
			data_browser_diagram
		WHERE diagram_id = v_DIAGRAM_ID;

		INSERT INTO diagram_nodes (
			springy_diagrams_id,
			description,
			active,
			diagram_shapes_id,
			color,
			x_coordinate,
			y_coordinate,
			mass,
			hex_rgb,
			diagram_color_id
		)
		WITH DIAGRAM_EDGES_Q AS (
			SELECT NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, 
				TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS,
				LABEL, TABLE_NAME, TARGET_TABLE_NAME 
			FROM data_browser_diagram_pipes.FN_Pipe_object_dependences(
				p_Exclude_Singles => p_Exclude_Singles,
				p_Include_App_Objects => p_Include_App_Objects,
				p_Include_External => p_Include_External,
				p_Include_Sys  => p_Include_Sys,
				p_Object_Owner => p_Object_Owner,
				p_Object_Types => p_Object_Types
			) TX
			WHERE NOT EXISTS (SELECT --+ NO_UNNEST
				1 FROM table(apex_string.split(v_Exclude_Pattern,','))
				WHERE (OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\')
			)
			AND NOT EXISTS (SELECT --+ NO_UNNEST
					1 
				FROM DATA_BROWSER_DIAGRAM_COORD TS
				WHERE TS.DIAGRAM_ID = v_Diagram_ID
				AND TS.ACTIVE = 'N'
				AND (TS.OBJECT_ID = TX.NODE_NAME
				 OR TS.OBJECT_ID = TX.TARGET_NODE_NAME) 
			)
		), NODES_Q AS (
            SELECT NODE_NAME, 
            	case when OBJECT_OWNER != p_Object_Owner then 
					INITCAP(OBJECT_OWNER) || '.' end 
				|| UNIQUE_NAME 
				UNIQUE_NAME,
				data_browser_diagram_utl.DB_Shape(OBJECT_TYPE) SHAPE,
				data_browser_diagram_utl.DB_Color(OBJECT_TYPE, 
					case when OBJECT_OWNER != p_Object_Owner then 'Orchid'
						when STATUS = 'INVALID' then 'Red' end 
				) COLOR
            FROM (
            	SELECT NODE_NAME, OBJECT_TYPE, OBJECT_OWNER,
                	INITCAP(OBJECT_NAME)
					|| case when COUNT(*) OVER (PARTITION BY INITCAP(OBJECT_NAME)) > 1 then 
						' #'||DENSE_RANK() OVER (PARTITION BY INITCAP(OBJECT_NAME) ORDER BY INITCAP(OBJECT_NAME), NODE_NAME)
					end UNIQUE_NAME,
            		STATUS, TABLE_NAME
            	FROM (
					SELECT  NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, TABLE_NAME
					FROM DIAGRAM_EDGES_Q A
					WHERE OBJECT_NAME IS NOT NULL
					UNION
					SELECT  TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS, TARGET_TABLE_NAME
					FROM DIAGRAM_EDGES_Q A
				)
            )
        )
		SELECT
			v_Springy_Diagram_Id springy_diagrams_id,
			dn.UNIQUE_NAME description,
			dc.active,
			ds.id diagram_shapes_id,
			dn.COLOR,
			dc.x_coordinate,
			dc.y_coordinate,
			dc.mass,
			c.hex_rgb,
			c.id diagram_color_id
		FROM data_browser_diagram_coord dc 
		JOIN NODES_Q dn ON dn.NODE_NAME = dc.object_id 
		LEFT OUTER JOIN DIAGRAM_SHAPES ds ON ds.DESCRIPTION = dn.SHAPE
		LEFT OUTER JOIN DIAGRAM_COLORS c ON c.COLOR_NAME = dn.COLOR
		WHERE dc.diagram_id = v_DIAGRAM_ID
		and dc.ACTIVE = 'Y';
		
		INSERT INTO diagram_edges (
			source_node_id,
			target_node_id,
			description,
			color,
			springy_diagrams_id
		) 
		WITH DIAGRAM_EDGES_Q AS (
			SELECT NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, 
				TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS,
				LABEL, TABLE_NAME, TARGET_TABLE_NAME 
			FROM data_browser_diagram_pipes.FN_Pipe_object_dependences(
				p_Exclude_Singles => p_Exclude_Singles,
				p_Include_App_Objects => p_Include_App_Objects,
				p_Include_External => p_Include_External,
				p_Include_Sys  => p_Include_Sys,
				p_Object_Owner => p_Object_Owner,
				p_Object_Types => p_Object_Types
			) TX
			WHERE NOT EXISTS (SELECT --+ NO_UNNEST
				1 FROM table(apex_string.split(v_Exclude_Pattern,','))
				WHERE (OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\')
			)
			AND NOT EXISTS (SELECT --+ NO_UNNEST
					1 
				FROM DATA_BROWSER_DIAGRAM_COORD TS
				WHERE TS.DIAGRAM_ID = v_Diagram_ID
				AND TS.ACTIVE = 'N'
				AND (TS.OBJECT_ID = TX.NODE_NAME
				 OR TS.OBJECT_ID = TX.TARGET_NODE_NAME) 
			)
		), NODES_Q AS (
            SELECT NODE_NAME, 
			case when OBJECT_OWNER != p_Object_Owner then 
				INITCAP(OBJECT_OWNER) || '.' end 
			|| UNIQUE_NAME 
            UNIQUE_NAME
            FROM (
            	SELECT NODE_NAME, OBJECT_TYPE, OBJECT_OWNER,
                	INITCAP(OBJECT_NAME)
					|| case when COUNT(*) OVER (PARTITION BY INITCAP(OBJECT_NAME)) > 1 then 
						' #'||DENSE_RANK() OVER (PARTITION BY INITCAP(OBJECT_NAME) ORDER BY INITCAP(OBJECT_NAME), NODE_NAME)
					end UNIQUE_NAME,
            		STATUS, TABLE_NAME
            	FROM (
					SELECT  NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, TABLE_NAME
					FROM DIAGRAM_EDGES_Q A
					WHERE OBJECT_NAME IS NOT NULL
					UNION
					SELECT  TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS, TARGET_TABLE_NAME
					FROM DIAGRAM_EDGES_Q A
				)
            ) dn
            JOIN data_browser_diagram_coord dc ON dn.NODE_NAME = dc.object_id 
            WHERE dc.diagram_id = v_DIAGRAM_ID
			AND dc.ACTIVE = 'Y'
        )
        SELECT DISTINCT sn2.ID source_node_id,
            tn2.ID target_node_id,
			de.label description,
			'DarkGrey' color,
            sn2.SPRINGY_DIAGRAMS_ID
        FROM DIAGRAM_EDGES_Q de
        JOIN NODES_Q sn ON sn.NODE_NAME = de.NODE_NAME
        JOIN NODES_Q tn ON tn.NODE_NAME = de.TARGET_NODE_NAME
        JOIN DIAGRAM_NODES sn2 ON sn2.DESCRIPTION = sn.UNIQUE_NAME AND sn2.SPRINGY_DIAGRAMS_ID = v_Springy_Diagram_Id
        JOIN DIAGRAM_NODES tn2 ON tn2.DESCRIPTION = tn.UNIQUE_NAME AND tn2.SPRINGY_DIAGRAMS_ID = v_Springy_Diagram_Id
        ;
		COMMIT;		
		p_Springy_Diagram_ID := v_Springy_Diagram_Id;
	end Save_Object_Dependencies_As;


	PROCEDURE Save_Dynamic_Actions_As (
		p_DA_APPLICATION_ID		IN VARCHAR2,
		p_DA_PAGE_ID			IN VARCHAR2,
		p_DIAGRAM_Name			IN VARCHAR2,
		p_Springy_Diagram_ID 	OUT NUMBER
	)
	is
		v_Springy_Diagram_Id SPRINGY_DIAGRAMS.ID%TYPE;
		v_Diagram_ID VARCHAR2(128) := 'APEX_DA'|| p_DA_APPLICATION_ID || '_' || p_DA_PAGE_ID;
	begin
		DELETE FROM SPRINGY_DIAGRAMS WHERE description = p_DIAGRAM_Name;

		SELECT SPRINGY_DIAGRAMS_SEQ.NEXTVAL INTO v_Springy_Diagram_Id FROM DUAL;

		INSERT INTO springy_diagrams (
			id,
			description,
			fontsize,
			zoom_factor,
			x_offset,
			y_offset,
			canvas_width,
			exclude_singles,
			edge_labels,
			stiffness,
			repulsion,
			damping,
			minenergythreshold,
			maxspeed,
			excite_method)
		SELECT
			v_Springy_Diagram_Id id,
			NVL(p_DIAGRAM_Name, diagram_id || ' ' || SYSDATE) description,
			fontsize,
			zoom_factor,
			x_offset,
			y_offset,
			canvas_width,
			exclude_singles,
			edge_labels,
			stiffness,
			repulsion,
			damping,
			minenergythreshold,
			maxspeed,
			excite_method
		FROM
			data_browser_diagram
		WHERE diagram_id = v_Diagram_ID;

		INSERT INTO diagram_nodes (
			springy_diagrams_id,
			description,
			active,
			diagram_shapes_id,
			color,
			x_coordinate,
			y_coordinate,
			mass,
			hex_rgb,
			diagram_color_id
		)
		WITH DIAGRAM_EDGES_Q AS (
			SELECT SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, EDGE_LABEL, DEST_NODE, DEST_ID, DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT 
			  from data_browser_diagram_pipes.FN_Pipe_apex_dyn_actions(p_DA_APPLICATION_ID, p_DA_PAGE_ID)
		), DIAGRAM_NODES_Q AS (
			SELECT SOURCE_ID,
				SOURCE_NODE, UNIQUE_NAME, OBJECT_TYPE,
				data_browser_diagram_utl.DA_Shape(OBJECT_TYPE) SHAPE,
				data_browser_diagram_utl.DA_Color(OBJECT_TYPE, COLOR) COLOR,
				-- data_browser_diagram_utl.DA_Insulator(OBJECT_TYPE, SOURCE_NODE) INSULATOR,	-- !! missing in spring diagram.
				ACTIVE, X_COORDINATE, Y_COORDINATE, MASS
			FROM (
				SELECT  dn.SOURCE_ID, dn.OBJECT_TYPE, dn.SOURCE_NODE,
                	dn.SOURCE_NODE
					|| case when COUNT(*) OVER (PARTITION BY dn.SOURCE_NODE) > 1 then 
						' #'||DENSE_RANK() OVER (PARTITION BY dn.SOURCE_NODE ORDER BY dn.SOURCE_NODE, dn.SOURCE_ID)
					end UNIQUE_NAME,
					dn.COLOR,
					dc.ACTIVE,
					dc.X_COORDINATE,
					dc.Y_COORDINATE,
					dc.MASS
				FROM (
                    SELECT SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, MAX(COLOR) COLOR
                    FROM (
                        SELECT SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, 
                            case when EXECUTE_ON_PAGE_INIT = 'Yes' then 'LightPink' end COLOR
                        FROM DIAGRAM_EDGES_Q A
                        UNION
                        SELECT  DEST_ID, DEST_OBJECT_TYPE, DEST_NODE, 
                            case when EXECUTE_ON_PAGE_INIT = 'Yes' then 'LightPink' end COLOR
                        FROM DIAGRAM_EDGES_Q A
                    )
                    GROUP BY SOURCE_ID, OBJECT_TYPE, SOURCE_NODE
				) dn
				JOIN data_browser_diagram_coord dc ON dn.SOURCE_ID = dc.object_id 
				AND dc.diagram_id = v_DIAGRAM_ID
				AND dc.ACTIVE = 'Y'
			) 
		)
		SELECT DISTINCT
			v_Springy_Diagram_Id springy_diagrams_id,
			dn.UNIQUE_NAME description,
			dn.active,
			ds.id diagram_shapes_id,
			dn.COLOR,
			dn.x_coordinate,
			dn.y_coordinate,
			dn.mass,
			c.hex_rgb,
			c.id diagram_color_id
		FROM DIAGRAM_NODES_Q dn 
		LEFT OUTER JOIN DIAGRAM_SHAPES ds ON ds.DESCRIPTION = dn.SHAPE
		LEFT OUTER JOIN DIAGRAM_COLORS c ON c.COLOR_NAME = dn.COLOR;
	
		INSERT INTO diagram_edges (
			source_node_id,
			target_node_id,
			description,
			color,
			springy_diagrams_id
		) 
		WITH DIAGRAM_EDGES_Q AS (
			SELECT SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, EDGE_LABEL, DEST_NODE, DEST_ID, DEST_OBJECT_TYPE
			  from data_browser_diagram_pipes.FN_Pipe_apex_dyn_actions(p_DA_APPLICATION_ID, p_DA_PAGE_ID)
		), NODES_Q AS (
			SELECT 
				SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, UNIQUE_NAME
			FROM (
				SELECT  SOURCE_ID, OBJECT_TYPE, SOURCE_NODE,
                	SOURCE_NODE
					|| case when COUNT(*) OVER (PARTITION BY SOURCE_NODE) > 1 then 
						' #'||DENSE_RANK() OVER (PARTITION BY SOURCE_NODE ORDER BY SOURCE_NODE, SOURCE_ID)
					end UNIQUE_NAME
				FROM (
					SELECT  SOURCE_ID, OBJECT_TYPE, SOURCE_NODE
					FROM DIAGRAM_EDGES_Q A
					UNION
					SELECT  DEST_ID, DEST_OBJECT_TYPE, DEST_NODE
					FROM DIAGRAM_EDGES_Q A
				) dn
				JOIN data_browser_diagram_coord dc ON dn.SOURCE_ID = dc.object_id 
				AND dc.diagram_id = v_DIAGRAM_ID
				AND dc.ACTIVE = 'Y'
			) 
		)
		SELECT DISTINCT
			sn2.ID source_node_id,
			tn2.ID target_node_id,
			replace(de.EDGE_LABEL, chr(39)) description,
			'DarkGrey' color,
			v_Springy_Diagram_Id SPRINGY_DIAGRAMS_ID
		FROM DIAGRAM_EDGES_Q de 
        JOIN NODES_Q sn ON sn.SOURCE_ID = de.SOURCE_ID
        JOIN NODES_Q tn ON tn.SOURCE_ID = de.DEST_ID
		JOIN DIAGRAM_NODES sn2 ON sn2.DESCRIPTION = sn.UNIQUE_NAME AND sn2.SPRINGY_DIAGRAMS_ID = v_Springy_Diagram_Id
		JOIN DIAGRAM_NODES tn2 ON tn2.DESCRIPTION = tn.UNIQUE_NAME AND tn2.SPRINGY_DIAGRAMS_ID = v_Springy_Diagram_Id;
		COMMIT;		
		p_Springy_Diagram_ID := v_Springy_Diagram_Id;
	end Save_Dynamic_Actions_As;

	PROCEDURE Save_Database_ER_As (
		p_Exclude_Singles		IN VARCHAR2 DEFAULT 'YES',
		p_DIAGRAM_Name			IN VARCHAR2,
		p_App_Developer_Mode 	IN VARCHAR2 DEFAULT V('APP_DEVELOPER_MODE'),
		p_Springy_Diagram_ID 	OUT NUMBER
	)
	is
		v_Springy_Diagram_Id SPRINGY_DIAGRAMS.ID%TYPE;
		v_Diagram_ID VARCHAR2(128) := 'DB_ER';
	begin
		DELETE FROM SPRINGY_DIAGRAMS WHERE description = p_DIAGRAM_Name;

		SELECT SPRINGY_DIAGRAMS_SEQ.NEXTVAL INTO v_Springy_Diagram_Id FROM DUAL;
		INSERT INTO SPRINGY_DIAGRAMS (
			id,
			description,
			fontsize,
			zoom_factor,
			x_offset,
			y_offset,
			canvas_width,
			exclude_singles,
			edge_labels,
			stiffness,
			repulsion,
			damping,
			minenergythreshold,
			maxspeed,
			excite_method)
		SELECT
			v_Springy_Diagram_Id id,
			NVL(p_DIAGRAM_Name, diagram_id || ' ' || SYSDATE) description,
			fontsize,
			zoom_factor,
			x_offset,
			y_offset,
			canvas_width,
			exclude_singles,
			edge_labels,
			stiffness,
			repulsion,
			damping,
			minenergythreshold,
			maxspeed,
			excite_method
		FROM
			data_browser_diagram
		WHERE diagram_id = v_Diagram_ID;

		INSERT INTO diagram_nodes (
			springy_diagrams_id,
			description,
			active,
			diagram_shapes_id,
			color,
			x_coordinate,
			y_coordinate,
			mass,
			hex_rgb,
			diagram_color_id
		)
		WITH NODES_Q AS (
			SELECT	VIEW_NAME, 
				NODE_NAME
				|| case when COUNT(*) OVER (PARTITION BY NODE_NAME) > 1 then 
					' #'||DENSE_RANK() OVER (PARTITION BY NODE_NAME ORDER BY VIEW_NAME)
				end NODE_NAME, 
				case when REFERENCES_COUNT > 0 
					then 'octagon' else 'ellipse'
				end SHAPE,
				'PowderBlue' COLOR
			FROM (
				SELECT REPLACE(S.VIEW_NAME, ' ', '_') VIEW_NAME, 
					data_browser_conf.Table_Name_To_Header(VIEW_NAME) NODE_NAME,
					S.REFERENCES_COUNT, S.NUM_ROWS, S.IS_ADMIN_TABLE
				FROM MVDATA_BROWSER_VIEWS S
				WHERE (S.IS_ADMIN_TABLE = 'N' or p_App_Developer_Mode = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
				AND (
					S.REFERENCES_COUNT > 0 
					OR EXISTS (
						select 1
						from MVDATA_BROWSER_FKEYS R
						where R.VIEW_NAME != R.R_VIEW_NAME
						and S.TABLE_NAME IN (R.TABLE_NAME, R.R_TABLE_NAME)
						and S.TABLE_OWNER = R.OWNER
					) 
					OR p_Exclude_Singles = 'NO'
				)
			) A
		)
		SELECT
			v_Springy_Diagram_Id springy_diagrams_id,
			dn.NODE_NAME description,
			dc.active,
			ds.id diagram_shapes_id,
			dn.COLOR,
			dc.x_coordinate,
			dc.y_coordinate,
			dc.mass,
			c.hex_rgb,
			c.id diagram_color_id
		FROM DATA_BROWSER_DIAGRAM_COORD dc 
		JOIN NODES_Q dn ON dn.VIEW_NAME = dc.object_id 
		LEFT OUTER JOIN DIAGRAM_SHAPES ds ON ds.DESCRIPTION = dn.SHAPE
		LEFT OUTER JOIN DIAGRAM_COLORS c ON c.COLOR_NAME = dn.COLOR
		WHERE dc.diagram_id = v_Diagram_ID
		and dc.ACTIVE = 'Y';

		INSERT INTO diagram_edges (
			source_node_id,
			target_node_id,
			description,
			color,
			springy_diagrams_id
		) 
		WITH NODES_Q AS (
			SELECT	VIEW_NAME, 
				NODE_NAME
				|| case when COUNT(*) OVER (PARTITION BY NODE_NAME) > 1 then 
					' #'||DENSE_RANK() OVER (PARTITION BY NODE_NAME ORDER BY VIEW_NAME)
				end NODE_NAME
			FROM (
				SELECT REPLACE(S.VIEW_NAME, ' ', '_') VIEW_NAME, 
					data_browser_conf.Table_Name_To_Header(VIEW_NAME) NODE_NAME,
					S.REFERENCES_COUNT, S.NUM_ROWS, S.IS_ADMIN_TABLE
				FROM MVDATA_BROWSER_VIEWS S
            	-- , (select 'YES' p_App_Developer_Mode, 'NO' v_Exclude_Singles, 'DB_ER' v_Diagram_ID from dual) par
				WHERE (S.IS_ADMIN_TABLE = 'N' or p_App_Developer_Mode = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
				AND (
					S.REFERENCES_COUNT > 0 
					OR EXISTS (
						select 1
						from MVDATA_BROWSER_FKEYS R
						where R.VIEW_NAME != R.R_VIEW_NAME
						and S.TABLE_NAME IN (R.TABLE_NAME, R.R_TABLE_NAME)
						and S.TABLE_OWNER = R.OWNER
					) 
					OR p_Exclude_Singles = 'NO'
				)
			) A
		)
		, TABLE_DEPEND AS (
			SELECT T.VIEW_NAME, 
				T.R_VIEW_NAME, 
				A.NODE_NAME SOURCE_NAME,
				B.NODE_NAME TARGET_NAME,
				case when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'N' then 'Container'
						when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'Y' then 'Dependent'
						when T.DELETE_RULE = 'SET NULL' and FK_NULLABLE = 'Y' then 'Nullable'
						when T.FK_NULLABLE = 'N' then 'Required'
						else 'Optional'
				end LABEL,
				case when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'N' then 'SeaGreen'
						when T.DELETE_RULE = 'CASCADE' and FK_NULLABLE = 'Y' then 'DarkSalmon'
						when T.DELETE_RULE = 'SET NULL' and FK_NULLABLE = 'Y' then 'CornflowerBlue'
						when T.FK_NULLABLE = 'N' then 'Coral'
						else 'Gray'
				end COLOR, 
				DELETE_RULE,
				v_Diagram_ID DIAGRAM_ID
			FROM MVDATA_BROWSER_FKEYS T
			JOIN NODES_Q A ON A.VIEW_NAME = T.VIEW_NAME 
			JOIN NODES_Q B ON B.VIEW_NAME = T.R_VIEW_NAME
			WHERE T.VIEW_NAME != T.R_VIEW_NAME
		), EDGES_Q AS(
			-------------------------------------------------------
			SELECT DISTINCT	TX.SOURCE_NAME, TX.TARGET_NAME, TX.LABEL, TX.COLOR, TX.DIAGRAM_ID
				FROM TABLE_DEPEND TX
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TS 
				ON TX.VIEW_NAME = TS.OBJECT_ID AND TS.DIAGRAM_ID = TX.DIAGRAM_ID
			LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TT 
				ON TX.R_VIEW_NAME = TT.OBJECT_ID AND TT.DIAGRAM_ID = TX.DIAGRAM_ID
			WHERE (TS.ACTIVE = 'Y' OR TS.ACTIVE IS NULL)
			AND (TT.ACTIVE = 'Y' OR TT.ACTIVE IS NULL)
		)
		SELECT
			sn.ID source_node_id,
			tn.ID target_node_id,
			de.LABEL description,
			de.COLOR,		
			sn.SPRINGY_DIAGRAMS_ID
		FROM EDGES_Q de
		JOIN DIAGRAM_NODES sn ON sn.DESCRIPTION = de.SOURCE_NAME AND sn.SPRINGY_DIAGRAMS_ID = v_Springy_Diagram_Id
		JOIN DIAGRAM_NODES tn ON tn.DESCRIPTION = de.TARGET_NAME AND tn.SPRINGY_DIAGRAMS_ID = sn.SPRINGY_DIAGRAMS_ID;
		COMMIT;		
		p_Springy_Diagram_ID := v_Springy_Diagram_Id;
	end Save_Database_ER_As;

	FUNCTION Object_Dependencies_List(
		p_Exclude_Pattern IN VARCHAR2 DEFAULT NULL,
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Diagramm_Labels IN VARCHAR2 DEFAULT 'NO',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2,
		p_Object_Types IN VARCHAR2,
		p_Search_Type  IN VARCHAR 
	) 
	RETURN data_browser_diagram_pipes.tab_object_list PIPELINED
	IS
		lv_RESULT               SYS_REFCURSOR;
		v_Diagram_ID			DATA_BROWSER_DIAGRAM_COORD.DIAGRAM_ID%TYPE;
		v_Exclude_Pattern		VARCHAR2(4000);
		v_limit CONSTANT PLS_INTEGER := 100;
		v_in_rows data_browser_diagram_pipes.tab_object_list;
	BEGIN
		if p_Object_Owner != SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then
			v_Diagram_ID := 'DB_OBJ_' || p_Object_Owner;
		else
			v_Diagram_ID := 'DB_OBJ';
		end if;
	
		v_Exclude_Pattern := data_browser_conf.Normalize_Column_Pattern(p_Exclude_Pattern);
		if p_Include_App_Objects = 'NO' then 
			v_Exclude_Pattern := data_browser_conf.concat_list(data_browser_conf.Normalize_Column_Pattern(g_Data_Browser_Pattern), v_Exclude_Pattern, ',');
		end if;

		OPEN lv_RESULT FOR
		WITH DIAGRAM_EDGES AS (
			SELECT NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, 
				TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS,
				LABEL, TABLE_NAME, TARGET_TABLE_NAME 
			FROM data_browser_diagram_pipes.FN_Pipe_object_dependences(
				p_Exclude_Singles => p_Exclude_Singles,
				p_Include_App_Objects => p_Include_App_Objects,
				p_Include_External => p_Include_External,
				p_Include_Sys  => p_Include_Sys,
				p_Object_Owner => p_Object_Owner,
				p_Object_Types => p_Object_Types
			) TX
			WHERE NOT EXISTS (SELECT --+ NO_UNNEST
				1 FROM table(apex_string.split(v_Exclude_Pattern,','))
				WHERE (OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_OBJECT_NAME LIKE COLUMN_VALUE ESCAPE '\'
				OR TARGET_TABLE_NAME LIKE COLUMN_VALUE ESCAPE '\')
			)
			AND NOT EXISTS (SELECT --+ NO_UNNEST
					1 
				FROM DATA_BROWSER_DIAGRAM_COORD TS
				WHERE TS.DIAGRAM_ID = v_Diagram_ID
				AND TS.ACTIVE = 'N'
				AND (TS.OBJECT_ID = TX.NODE_NAME
				 OR TS.OBJECT_ID = TX.TARGET_NODE_NAME) 
			)
		)
		SELECT NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, TABLE_NAME,
			case when OBJECT_OWNER != p_Object_Owner 
			then INITCAP(OBJECT_OWNER) || '.' end 
			|| INITCAP(OBJECT_NAME) NODE_LABEL
		FROM (
			SELECT  NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER, STATUS, TABLE_NAME
			FROM DIAGRAM_EDGES 
			WHERE OBJECT_NAME IS NOT NULL
			AND (OBJECT_TYPE = p_Search_Type OR p_Search_Type IS NULL)
			UNION
			SELECT  TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, TARGET_OBJECT_OWNER, TARGET_STATUS, TARGET_TABLE_NAME
			FROM DIAGRAM_EDGES 
			WHERE (TARGET_OBJECT_TYPE = p_Search_Type OR p_Search_Type IS NULL)
		) TX
		LEFT OUTER JOIN DATA_BROWSER_DIAGRAM_COORD TC 
			ON TX.NODE_NAME = TC.OBJECT_ID AND TC.DIAGRAM_ID = v_Diagram_ID
		WHERE (TC.ACTIVE = 'Y' OR TC.ACTIVE IS NULL);
		LOOP
			FETCH lv_RESULT BULK COLLECT INTO v_in_rows LIMIT v_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
	END Object_Dependencies_List;

end data_browser_diagram_utl;
/
