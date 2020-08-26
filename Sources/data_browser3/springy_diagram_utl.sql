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

CREATE OR REPLACE PACKAGE springy_diagram_utl
AUTHID CURRENT_USER
IS
	FUNCTION Get_APEX_URL_Element (p_Text VARCHAR2, p_Element NUMBER) RETURN VARCHAR2;

	PROCEDURE Load_Diagam_settings (
		p_DIAGRAM_ID			IN VARCHAR2,
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

	PROCEDURE Springy_Diagramm_JS(
		p_PARENT_KEY_ID         IN SPRINGY_DIAGRAMS.ID%TYPE,
		p_Diagramm_Labels 		IN VARCHAR2 DEFAULT 'NO'
	);
end springy_diagram_utl;
/


CREATE OR REPLACE PACKAGE BODY springy_diagram_utl
IS 
	g_dg CONSTANT VARCHAR2(50) := q'[NLS_NUMERIC_CHARACTERS = '.,']';
	g_fmt CONSTANT VARCHAR2(50) := '999990D99999999999999999999999999';

	FUNCTION Get_APEX_URL_Element (p_Text VARCHAR2, p_Element NUMBER) RETURN VARCHAR2
	IS PRAGMA UDF;
		v_URL_Array apex_t_varchar2;
	BEGIN
		v_URL_Array := apex_string.split(p_Text, ':');
		if v_URL_Array.count >= p_Element then
			RETURN v_URL_Array(p_Element);
		else
			RETURN NULL;
		end if;
	END Get_APEX_URL_Element;

	PROCEDURE Load_Diagam_settings (
		p_DIAGRAM_ID			IN VARCHAR2,
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
			-- p_DIAGRAM_ID := COALESCE(p_DIAGRAM_ID, APEX_UTIL.GET_PREFERENCE(:OWNER || '.P51_DIAGRAM_ID'));
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
				p_STIFFNESS, p_REPULSION, p_DAMPING, p_MINENERGYTHRESHOLD, 
				p_MAXSPEED, p_PINWEIGHT, p_EXCITE_METHOD
			FROM SPRINGY_DIAGRAMS
			WHERE ID = p_DIAGRAM_ID;
		exception when NO_DATA_FOUND then
			SELECT null FONTSIZE, '1.0' ZOOM_FACTOR, 0 X_OFFSET, 0 Y_OFFSET, 
				null CANVAS_WIDTH, 'NO' EXCLUDE_SINGLES, 'YES' EDGE_LABELS,
				'400.0' STIFFNESS, '4000.0' REPULSION, '0.36' DAMPING, '0.01' MINENERGYTHRESHOLD, 
				'50.0' MAXSPEED, '10' PINWEIGHT,
				'none' EXCITE_METHOD
			INTO p_DIAGRAM_FONTSIZE, p_DIAGRAM_ZOOMFACTOR, p_DIAGRAM_X_OFFSET, p_DIAGRAM_Y_OFFSET,
				p_CANVAS_WIDTH, p_EXCLUDE_SINGLES, p_DIAGRAM_LABELS,
				p_STIFFNESS, p_REPULSION, p_DAMPING, p_MINENERGYTHRESHOLD, 
				p_MAXSPEED, p_PINWEIGHT, p_EXCITE_METHOD
			FROM DUAL;
		end;
	    p_MAXSPEED      := TO_CHAR(GREATEST(LEAST(NVL(TO_NUMBER(p_MAXSPEED, '999990D9', g_dg), 80), 200), 1), '999990D9', g_dg);

		if apex_application.g_debug then
			apex_debug.message(
				p_message => 
				'data_browser_diagram_utl.Load_Diagam_settings(' || chr(10)
				|| 'p_DIAGRAM_ID => %s, p_DIAGRAM_FONTSIZE => %s, p_DIAGRAM_ZOOMFACTOR => %s, ' || chr(10)
				|| 'p_DIAGRAM_X_OFFSET => %s, p_DIAGRAM_Y_OFFSET => %s, p_CANVAS_WIDTH => %s, p_EXCLUDE_SINGLES => %s, ' || chr(10)
				|| 'p_DIAGRAM_LABELS => %s, p_EXCITE_METHOD => %s, p_STIFFNESS => %s, p_REPULSION => %s, p_DAMPING => %s,' || chr(10)
				|| 'p_MINENERGYTHRESHOLD => %s, p_MAXSPEED => %s) ',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_ID),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_FONTSIZE),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_ZOOMFACTOR),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_X_OFFSET),
				p4 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_Y_OFFSET),
				p5 => DBMS_ASSERT.ENQUOTE_LITERAL(p_CANVAS_WIDTH),
				p6 => DBMS_ASSERT.ENQUOTE_LITERAL(p_EXCLUDE_SINGLES),
				p7 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DIAGRAM_LABELS),
				p8 => DBMS_ASSERT.ENQUOTE_LITERAL(p_EXCITE_METHOD),
				p9 => DBMS_ASSERT.ENQUOTE_LITERAL(p_STIFFNESS),
				p10 => DBMS_ASSERT.ENQUOTE_LITERAL(p_REPULSION),
				p11 => DBMS_ASSERT.ENQUOTE_LITERAL(p_DAMPING),
				p12 => DBMS_ASSERT.ENQUOTE_LITERAL(p_MINENERGYTHRESHOLD),
				p13 => DBMS_ASSERT.ENQUOTE_LITERAL(p_MAXSPEED),
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

    -- if p_DIAGRAM_ID IS NOT NULL then 
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
        UPDATE SPRINGY_DIAGRAMS
        SET (FONTSIZE, ZOOM_FACTOR, X_OFFSET, Y_OFFSET, EXCLUDE_SINGLES, EDGE_LABELS, 
             CANVAS_WIDTH, STIFFNESS, REPULSION, DAMPING, 
             MINENERGYTHRESHOLD, MAXSPEED, PINWEIGHT, EXCITE_METHOD) = (
			   SELECT NVL(numbers_utl.JS_To_Number(p_DIAGRAM_FONTSIZE ), 4), 
                    numbers_utl.JS_To_Number(p_DIAGRAM_ZOOMFACTOR ), 
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
                    p_EXCITE_METHOD
                FROM DUAL
             )
        WHERE ID = p_DIAGRAM_ID;
        if SQL%ROWCOUNT = 0 then
            INSERT INTO SPRINGY_DIAGRAMS(
            		ID, FONTSIZE, ZOOM_FACTOR, X_OFFSET, Y_OFFSET, EXCLUDE_SINGLES, EDGE_LABELS,
                    CANVAS_WIDTH, STIFFNESS, REPULSION, DAMPING, MINENERGYTHRESHOLD, 
                    MAXSPEED, PINWEIGHT, EXCITE_METHOD) 
            SELECT p_DIAGRAM_ID, 
				   NVL(numbers_utl.JS_To_Number(p_DIAGRAM_FONTSIZE ), 4), 
                   numbers_utl.JS_To_Number(p_DIAGRAM_ZOOMFACTOR ), 
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
                   p_EXCITE_METHOD
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
		if APEX_COLLECTION.COLLECTION_EXISTS(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES') then 
			APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES');
		end if;

		declare
			e_20104 exception;
			pragma exception_init(e_20104, -20104);
		begin
			APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
				p_collection_name => 'DIAGRAM_OBJECT_COORDINATES', 
				p_query => l_query
			);
		exception
			when e_20104 then null;
		end;

		MERGE INTO DIAGRAM_NODES D
		USING (
			SELECT ID, 
				TO_NUMBER(X_COORDINATE, '999990D99999999999999999999999999', g_dg) X_COORDINATE,
				TO_NUMBER(Y_COORDINATE, '999990D99999999999999999999999999', g_dg) Y_COORDINATE,
				TO_NUMBER(MASS, '999990D99999999999999999999999999', g_dg) MASS,
				case when p_REQUEST = 'EXEMPT' and ACTIVE = 'false' then 'N' 
					when p_REQUEST = 'HIDE' and ACTIVE = 'true' then 'N' 
				   else 'Y' 
			   end ACTIVE
			FROM (select DISTINCT C001 ID, C002 X_COORDINATE, C003 Y_COORDINATE, C004 MASS, C005 ACTIVE
					from APEX_COLLECTIONS
					where COLLECTION_NAME = 'DIAGRAM_OBJECT_COORDINATES'
			) 
		) S
		ON (D.ID = S.ID)
		WHEN MATCHED THEN
			UPDATE SET D.X_COORDINATE = S.X_COORDINATE, D.Y_COORDINATE = S.Y_COORDINATE, 
				D.MASS = S.MASS, D.ACTIVE = S.ACTIVE
		WHEN NOT MATCHED THEN
			INSERT (D.ID, D.X_COORDINATE, D.Y_COORDINATE, 
				D.MASS, D.ACTIVE)
			VALUES (S.ID, S.X_COORDINATE, S.Y_COORDINATE, 
				S.MASS, S.ACTIVE)
		;
		if p_REQUEST IN ('SHOW_ALL', 'LOCK', 'UNLOCK') then 
			UPDATE DIAGRAM_NODES 
				SET ACTIVE = case when p_REQUEST = 'SHOW_ALL' then 'Y' else ACTIVE end,
					MASS = case when p_REQUEST = 'LOCK' then 10000 when p_REQUEST = 'UNLOCK' then 1 else MASS end
			WHERE SPRINGY_DIAGRAMS_ID = p_DIAGRAM_ID;
		end if;
		APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES');
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
		l_value_node_id number;
		l_value_mass number;
	BEGIN
		if apex_collection.collection_exists(p_collection_name=>'CLOB_CONTENT') then
			SELECT CLOB001 INTO l_json
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = 'CLOB_CONTENT';
		end if;
		if APEX_COLLECTION.COLLECTION_EXISTS(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES') then 
			APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES');
		end if;
		APEX_COLLECTION.CREATE_COLLECTION(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES');
	  if l_json is not null then   
			APEX_JSON.parse(j, l_json);
			r_count := APEX_JSON.GET_COUNT(p_path=>'.',p_values=>j);
			dbms_output.put_line('Nr Records: ' || r_count);
			FOR i IN 1 .. r_count LOOP
				 l_value_node_id := apex_json.get_number(p_path=>'[%d].id',p_values=>j, p0=>i); 
				 l_x_coordinate := apex_json.get_number(p_path=>'[%d].x',p_values=>j, p0=>i); 
				 l_y_coordinate := apex_json.get_number(p_path=>'[%d].y',p_values=>j, p0=>i); 
				 l_value_mass := apex_json.get_number(p_path=>'[%d].mass',p_values=>j, p0=>i); 
				 APEX_COLLECTION.ADD_MEMBER(
					p_collection_name => 'DIAGRAM_OBJECT_COORDINATES',
					p_n001 => l_value_node_id,
					p_n002 => l_x_coordinate,
					p_n003 => l_y_coordinate, 
					p_n004 => l_value_mass 
				);
			END LOOP; 
			MERGE INTO DIAGRAM_NODES D
			USING (
				SELECT ID, X_COORDINATE, Y_COORDINATE, MASS
				FROM (select DISTINCT N001 ID, N002 X_COORDINATE, N003 Y_COORDINATE, N004 MASS
						from APEX_COLLECTIONS
						where COLLECTION_NAME = 'DIAGRAM_OBJECT_COORDINATES'
				) 
			) S
			ON (D.ID = S.ID)
			WHEN MATCHED THEN
				UPDATE SET D.X_COORDINATE = S.X_COORDINATE, 
					D.Y_COORDINATE = S.Y_COORDINATE, 
					D.MASS = S.MASS
			WHEN NOT MATCHED THEN
				INSERT (D.ID, D.X_COORDINATE, D.Y_COORDINATE, 
					D.MASS)
				VALUES (S.ID, S.X_COORDINATE, S.Y_COORDINATE, 
					S.MASS)
			;
			APEX_COLLECTION.DELETE_COLLECTION(p_collection_name => 'DIAGRAM_OBJECT_COORDINATES');
			COMMIT;
		end if;   
	END Save_Node_Coordinates;
$END

	PROCEDURE Springy_Diagramm_JS(
		p_PARENT_KEY_ID         IN SPRINGY_DIAGRAMS.ID%TYPE,
		p_Diagramm_Labels 		IN VARCHAR2 DEFAULT 'NO'
	)
	IS
		lv_RESULT               SYS_REFCURSOR;
		l_TEXTLINE 				VARCHAR2(500);
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
		OPEN lv_RESULT FOR
		SELECT DISTINCT DIGRAPH, L
		FROM (
			SELECT 'var graph = new Springy.Graph();' DIGRAPH, 0 L
			FROM DUAL
			-- Knoten
			UNION ALL
			SELECT DISTINCT
				'var n' || TX.NODE_NAME || ' = graph.newNode({label: ' || dbms_assert.enquote_literal(TX.NAME) 
					|| ', name: ' || dbms_assert.enquote_literal(TX.NODE_NAME)
					|| ', shape: ' || dbms_assert.enquote_literal(TX.FIGUR) 
					|| ', color: ' || dbms_assert.enquote_literal(TX.COLOR) 
					|| ', x: ' || ltrim(to_char(X_COORDINATE, 'TM9', g_dg))
					|| ', y: ' || ltrim(to_char(Y_COORDINATE, 'TM9', g_dg))
					|| ', mass: ' || ltrim(to_char(MASS, 'TM9', g_dg))
					|| '}); ' NODE,
					1 L
			FROM (
				SELECT A.ID NODE_NAME, 
					RTRIM(A.DESCRIPTION, '_') NAME, 
					(SELECT DESCRIPTION D  FROM DIAGRAM_SHAPES  WHERE ID = A.DIAGRAM_SHAPES_ID)  FIGUR,
					NVL(A.COLOR, 'PowderBlue') COLOR,
					NVL(NULLIF(X_COORDINATE, 0), DBMS_RANDOM.VALUE(-1, 1)) X_COORDINATE, 
					NVL(NULLIF(Y_COORDINATE, 0), DBMS_RANDOM.VALUE(-1, 1)) Y_COORDINATE, 
					MASS
				FROM DIAGRAM_NODES A 
				WHERE A.ACTIVE = 'Y'
				AND A.SPRINGY_DIAGRAMS_ID = p_PARENT_KEY_ID
			) TX
			UNION ALL -- DIAGRAM_EDGES des Baums
			SELECT DISTINCT
				'graph.newEdge(n' || TX.NODE_NAME || ', n' || TX.TARGET_NODE_NAME || ', {' ||
					CASE WHEN p_Diagramm_Labels != 'NO' THEN
						'label: ' || dbms_assert.enquote_literal(TX.LABEL) || ', '
					ELSE NULL END
					|| 'color: ' || dbms_assert.enquote_literal(TX.COLOR) || ' '
					|| '});' DIGRAPH,
					(L+1000) L
			FROM (
				SELECT A.SOURCE_NODE_ID NODE_NAME,
						A.TARGET_NODE_ID TARGET_NODE_NAME,
						A.DESCRIPTION LABEL,
						NVL(A.COLOR, 'DarkGrey') COLOR, 
						2 L
				FROM DIAGRAM_EDGES A 
				WHERE A.SPRINGY_DIAGRAMS_ID = p_PARENT_KEY_ID
				AND EXISTS (
					SELECT 1
					FROM DIAGRAM_NODES K
					WHERE K.ACTIVE = 'Y'
					AND K.ID = A.SOURCE_NODE_ID
				)
				AND EXISTS (
					SELECT 1
					FROM DIAGRAM_NODES K
					WHERE K.ACTIVE = 'Y'
					AND K.ID = A.TARGET_NODE_ID
				)
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
	END Springy_Diagramm_JS;


end springy_diagram_utl;
/


