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

/*
function render_dynamic_actions_legend () {
	jQuery(function(){
		var graph = new Springy.Graph(); 
		var n_R = graph.newNode({label: 'Menu Name', 			name: 'M', shape: 'tab', 			color: 'BurlyWood', 	y: -0.01, x: -1.4, mass: 100.0}); 	// Menu 
		var n_I = graph.newNode({label: 'Page Item Name', 		name: 'I', shape: 'box', 			color: 'YellowGreen', 	y: -0.01, x: -1.2, mass: 100.0}); 
		var n_B = graph.newNode({label: 'Button Name', 			name: 'B', shape: 'octagon', 		color: 'Plum', 			y: -0.01, x: -1.0, mass: 100.0}); 
		var n_R = graph.newNode({label: 'Region Name', 			name: 'R', shape: 'doubleoctagon', 	color: 'BurlyWood', 	y: -0.01, x: -0.8, mass: 100.0}); 	// Region 
		var n_J = graph.newNode({label: 'jQuery Selector', 		name: 'J', shape: 'parallelogram', 	color: 'MediumAquamarine', y: -0.01, x: -0.6, mass: 100.0}); 
		var n_D = graph.newNode({label: 'Dynamic Action', 		name: 'D', shape: 'ellipse', 		color: 'Khaki', 		y: -0.01, x:  -0.4, mass: 100.0}); 	// DA name
		var n_T = graph.newNode({label: 'True', 				name: 'T', shape: 'house', 			color: 'PowderBlue', 	y: -0.01, x:  -0.2, mass: 100.0}); 	// DA true
		var n_F = graph.newNode({label: 'False', 				name: 'F', shape: 'invhouse', 		color: 'PowderBlue', 	y: -0.01, x:  0.0, mass: 100.0}); 	// DA false
		var n_C = graph.newNode({label: 'Performed Code', 		name: 'C', shape: 'trapezium', 		color: 'MistyRose', 	y: -0.01, x:  0.2, mass: 100.0}); 	// DA code step
		var n_X = graph.newNode({label: 'Execute on init', 		name: 'X', shape: 'trapezium', 		color: 'LightPink', 	y: -0.01, x:  0.4, mass: 100.0}); 	// DA code on init 
		var n_Q = graph.newNode({label: 'Request Name', 		name: 'Q', shape: 'octagon', 		color: 'Orange', 		y: -0.01, x:  0.6, mass: 100.0}); 
		var n_L = graph.newNode({label: 'Branch', 				name: 'L', shape: 'righttriangle', 	color: 'YellowGreen', y: -0.01, x:  0.8, mass: 100.0});  	// page branch;
		// List Link 
		var n_A = graph.newNode({label: 'Link', 				name: 'A', shape: 'righttriangle', 	color: 'LightSkyBlue', y: -0.01, x:  1.0, mass: 100.0}); 	// R region list link;  target_id: region_id_list-entry
		var n_E = graph.newNode({label: 'Performed Code', 		name: 'E', shape: 'trapezium', 		color: 'MistyRose', y: -0.01, x:  1.0, mass: 100.0});		// R region list link;  target_id: region_id_list-entry
		// Report Link
		var n_K = graph.newNode({label: 'Link', 				name: 'K', shape: 'righttriangle', 	color: 'LightSkyBlue', y: -0.01, x:  1.0, mass: 100.0}); 	// R region column link;  target_id: region_id_display_sequence
		var n_N = graph.newNode({label: 'Performed Code', 		name: 'N', shape: 'trapezium', 		color: 'MistyRose', y: -0.01, x:  1.0, mass: 100.0});		// R region column link;  target_id: region_id_display_sequence
		// Menu Link 
		var n_G = graph.newNode({label: 'Link', 				name: 'G', shape: 'righttriangle', 	color: 'LightSkyBlue', y: -0.01, x:  1.0, mass: 100.0}); 	// M menu list entry link;  target_id: list_id_list-entry
		var n_H = graph.newNode({label: 'Performed Code', 		name: 'H', shape: 'trapezium', 		color: 'MistyRose', y: -0.01, x:  1.0, mass: 100.0});		// M menu list entry link;  target_id: list_id_list-entry

		var n_P = graph.newNode({label: 'Process Point', 		name: 'P', shape: 'star', 			color: 'LightCyan', y: -0.01, x:  1.2, mass: 100.0}); 		// Processing point
		var springy = jQuery('#legend_diagram').springy({
			graph: graph,
			fontsize: 8.0,
			zoomFactor: 1.0,
			minEnergyThreshold: 5.0,
			stiffness : 400.0,
			repulsion : 800.0
	   });
	});
}

function render_dependencies_legend () {
	jQuery(function(){
		var graph = new Springy.Graph(); 
		var n_Fn = graph.newNode({label: 'Function', 			name: 'Function', 			shape: 'ellipse', 		color: 'Aqua', 			y: -0.01, x: -1.0, mass: 100.0}); 
		var n_Pa = graph.newNode({label: 'Type', 				name: 'Type', 				shape: 'house', 		color: 'Lightskyblue', 	y: -0.01, x: -0.8, mass: 100.0}); 
		var n_Pa = graph.newNode({label: 'Package', 			name: 'Package', 			shape: 'house', 		color: 'Lightseagreen', y: -0.01, x: -0.6, mass: 100.0}); 
		var n_Pr = graph.newNode({label: 'Procedure', 			name: 'Procedure', 			shape: 'trapezium', 	color: 'Darkturquoise', y: -0.01, x: -0.4, mass: 100.0}); 
		var n_Ta = graph.newNode({label: 'Table', 				name: 'Table', 				shape: 'doubleoctagon', color: 'Khaki', 		y: -0.01, x: -0.2, mass: 100.0}); 
		var n_Vw = graph.newNode({label: 'View', 				name: 'View', 				shape: 'octagon', 		color: 'Powderblue', 	y: -0.01, x:  0.0, mass: 100.0}); 
		var n_Tr = graph.newNode({label: 'Trigger', 			name: 'Trigger', 			shape: 'component', 	color: 'LightSalmon', 	y: -0.01, x:  0.2, mass: 100.0}); 
		var n_Mv = graph.newNode({label: 'Materialized View', 	name: 'Materialized View', 	shape: 'octagon', 		color: 'Goldenrod', 	y: -0.01, x:  0.4, mass: 100.0}); 
		var n_Oo = graph.newNode({label: 'Other Objects', 		name: 'User_Objects', 		shape: 'box', 			color: 'Yellowgreen', 	y: -0.01, x:  0.6, mass: 100.0}); 
		var n_Eo = graph.newNode({label: 'External Objects', 	name: 'External_Objects', 	shape: 'octagon', 		color: 'Orchid', 		y: -0.01, x:  0.8, mass: 100.0}); 
		var n_Io = graph.newNode({label: 'Invalid Objects', 	name: 'Invalid_Objects', 	shape: 'octagon', 		color: 'Red', 			y: -0.01, x:  1.0, mass: 100.0}); 
		var springy = jQuery('#legend_diagram').springy({
			graph: graph,
			fontsize: 8.0,
			zoomFactor: 1.0,
			minEnergyThreshold: 5.0,
			stiffness : 400.0,
			repulsion : 800.0
	   });
	});
}


if ($v('P28_SOURCE_TYPE') === 'DYNAMIC_ACTIONS') {
	-- legende: Dynamic Actions
	render_dynamic_actions_legend ()
}
if ($v('P28_SOURCE_TYPE') === 'DEPENDENCIES') {
	-- Legende: Object Dependences
	render_dependencies_legend ();
}

*/

CREATE OR REPLACE PACKAGE data_browser_diagram_pipes
AUTHID CURRENT_USER
IS
	TYPE rec_apex_dyn_actions IS RECORD (
		SOURCE_ID				VARCHAR2(128), 
		OBJECT_TYPE             VARCHAR2(4), 
		SOURCE_NODE             VARCHAR2(128), 
		EDGE_LABEL              VARCHAR2(128), 
		DEST_NODE				VARCHAR2(128),
		DEST_ID                 VARCHAR2(128),
		DEST_OBJECT_TYPE        VARCHAR2(4),
		EXECUTE_ON_PAGE_INIT	VARCHAR2(4),
		APPLICATION_ID			NUMBER,
		PAGE_ID					NUMBER
	);
	TYPE tab_apex_dyn_actions IS TABLE OF rec_apex_dyn_actions;

	FUNCTION FN_Pipe_apex_dyn_actions(p_Application_ID NUMBER, p_App_Page_ID NUMBER)
	RETURN data_browser_diagram_pipes.tab_apex_dyn_actions PIPELINED;

	TYPE rec_object_dependences IS RECORD (
		NODE_NAME				VARCHAR2(512), 
		OBJECT_TYPE             VARCHAR2(30), 
		OBJECT_NAME             VARCHAR2(512), 
		OBJECT_OWNER			VARCHAR2(128), 
		STATUS              	VARCHAR2(30), 
		TARGET_NODE_NAME		VARCHAR2(512),
		TARGET_OBJECT_TYPE      VARCHAR2(30),
		TARGET_OBJECT_NAME      VARCHAR2(512),
		TARGET_OBJECT_OWNER		VARCHAR2(128),
		TARGET_STATUS			VARCHAR2(30),
		LABEL					VARCHAR2(30),
		TABLE_NAME				VARCHAR2(128),
		TARGET_TABLE_NAME		VARCHAR2(128)
	);
	TYPE tab_object_dependences IS TABLE OF rec_object_dependences;

	TYPE rec_object_list IS RECORD (
		NODE_NAME				VARCHAR2(512), 
		OBJECT_TYPE             VARCHAR2(30), 
		OBJECT_NAME             VARCHAR2(512), 
		OBJECT_OWNER			VARCHAR2(128), 
		STATUS              	VARCHAR2(30), 
		TABLE_NAME				VARCHAR2(128),
		NODE_LABEL				VARCHAR2(512)
	);
	TYPE tab_object_list IS TABLE OF rec_object_list;

	FUNCTION FN_Pipe_object_dependences (
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Object_Types IN VARCHAR2 DEFAULT 'KEY CONSTRAINT:CHECK CONSTRAINT:NOT NULL CONSTRAINT:FUNCTION:INDEX:MATERIALIZED VIEW:PACKAGE:PACKAGE BODY:PROCEDURE:SEQUENCE:SYNONYM:TABLE:TRIGGER:TYPE:TYPE BODY:VIEW',
		p_Object_Name IN VARCHAR2 DEFAULT NULL
	)
	RETURN data_browser_diagram_pipes.tab_object_dependences PIPELINED;

END data_browser_diagram_pipes;
/

CREATE OR REPLACE PACKAGE BODY data_browser_diagram_pipes
IS
	FUNCTION FN_Pipe_Apex_Dyn_Actions(p_Application_ID NUMBER, p_App_Page_ID NUMBER)
	RETURN data_browser_diagram_pipes.tab_apex_dyn_actions PIPELINED
	IS
        CURSOR dyn_actions_cur
        IS
		WITH list_q as ( -- list entries; Region -> Branch
			select R.REGION_ID, R.REGION_NAME, R.LIST_ID, L.LIST_NAME,
				E.LIST_ENTRY_ID, E.ENTRY_TEXT, E.ENTRY_TARGET, 
				case when E.ENTRY_TARGET LIKE 'javascript%' then
					case when E.ENTRY_TARGET LIKE '%apex.submit%' 
					or E.ENTRY_TARGET LIKE '%apex.confirm%' 
						then 'Submit'
						else 'Javascript'
					end 
				when E.ENTRY_TARGET LIKE 'f?p=%' 
					then 'Link'
				end TARGET_TYPE, -- Submit / Javascript / Link / NUll
				E.DISPLAY_SEQUENCE,
				R.APPLICATION_ID, R.PAGE_ID
			  from APEX_APPLICATION_PAGE_REGIONS R
			  join APEX_APPLICATION_LISTS L ON L.APPLICATION_ID = R.APPLICATION_ID AND L.LIST_ID = R.LIST_ID
			  join APEX_APPLICATION_LIST_ENTRIES E ON E.APPLICATION_ID = R.APPLICATION_ID AND E.LIST_ID = R.LIST_ID
			 where R.SOURCE_TYPE = 'List'
			   and R.SOURCE_TYPE_PLUGIN_NAME = 'NATIVE_LIST'
			   and L.LIST_TYPE_CODE = 'STATIC'
			   and R.APPLICATION_ID = p_Application_ID 
			   and R.PAGE_ID = p_App_Page_ID
		) , list_q2 as (
			select P.*, P.REGION_ID||'_'||P.LIST_ENTRY_ID TARGET_ID --  used in node type A / E
			from (
				select * 
				from (
					select REGION_ID, REGION_NAME, LIST_ID, LIST_NAME, LIST_ENTRY_ID, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
						REGEXP_SUBSTR(ENTRY_TARGET, '.*'||q.op||'\s*\(.*[''"](\S+)[''"]', 1, 1, 'in', 1) REQUEST, -- extract request 
						APPLICATION_ID, PAGE_ID
					from list_q P, (select COLUMN_VALUE op FROM TABLE(apex_string.split('apex\.confirm:apex\.submit', ':'))) Q
					where TARGET_TYPE = 'Submit'
				) where REQUEST IS NOT NULL
				union  
				select * 
				from (
					select REGION_ID, REGION_NAME, LIST_ID, LIST_NAME, LIST_ENTRY_ID, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
						data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 4)	REQUEST, -- extract request 
						APPLICATION_ID, PAGE_ID
					from list_q P
					where TARGET_TYPE = 'Link'
				) 
				union  
				select REGION_ID, REGION_NAME, LIST_ID, LIST_NAME, LIST_ENTRY_ID, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
					NULL REQUEST, APPLICATION_ID, PAGE_ID
				from list_q P
				where TARGET_TYPE = 'Javascript'
			) P
		), page_procs as (
			select PROCESS_NAME,EXECUTION_SEQUENCE,
				case when PROCESS_TYPE_CODE = 'PLSQL' 
					then 'PL/SQL'
					else PROCESS_TYPE
				end PROCESS_TYPE, PROCESS_ID,
				case when WHEN_BUTTON_PRESSED IS NOT NULL  
					then WHEN_BUTTON_PRESSED
					when CONDITION_TYPE_CODE = 'REQUEST_EQUALS_CONDITION' 
					then CONDITION_EXPRESSION1
				end WHEN_BUTTON_PRESSED,
				case when PROCESS_POINT_CODE  IN ('AFTER_SUBMIT','ON_SUBMIT_BEFORE_COMPUTATION') 
					then 'No' else 'Yes' 
				end EXECUTE_ON_PAGE_INIT,
				PROCESS_POINT_CODE, PROCESS_POINT,
				APPLICATION_ID, PAGE_ID
			  from APEX_APPLICATION_PAGE_PROC
			 where (WHEN_BUTTON_PRESSED IS NOT NULL or CONDITION_TYPE_CODE = 'REQUEST_EQUALS_CONDITION' )
			   and APPLICATION_ID = p_Application_ID 
			   and PAGE_ID = p_App_Page_ID
			union all 
			select PROCESS_NAME,EXECUTION_SEQUENCE,
					case when PROCESS_TYPE_CODE = 'PLSQL' 
						then 'PL/SQL'
						else PROCESS_TYPE
					end PROCESS_TYPE, PROCESS_ID,
					REGEXP_REPLACE(TRIM(COLUMN_VALUE), '^''(.*)''$', '\1') WHEN_BUTTON_PRESSED,
					case when PROCESS_POINT_CODE  IN ('AFTER_SUBMIT','ON_SUBMIT_BEFORE_COMPUTATION') 
						then 'No' else 'Yes' 
					end EXECUTE_ON_PAGE_INIT,
					PROCESS_POINT_CODE, PROCESS_POINT,
					APPLICATION_ID, PAGE_ID
			from (
				select PROCESS_NAME,EXECUTION_SEQUENCE,
					PROCESS_TYPE,PROCESS_TYPE_CODE,PROCESS_ID,
					REGEXP_SUBSTR(CONDITION_EXPRESSION1, ':REQUEST\s+'||q.op||'\s*\((.+)\)', 1, 1, 'in', 1) REQUEST_IN_LIST,
					PROCESS_POINT_CODE, PROCESS_POINT,
					APPLICATION_ID, PAGE_ID
				  from APEX_APPLICATION_PAGE_PROC p
					, (select COLUMN_VALUE op FROM TABLE(apex_string.split('in:not in', ':'))) q
				 where CONDITION_TYPE_CODE = 'PLSQL_EXPRESSION'
				   and REGEXP_INSTR(CONDITION_EXPRESSION1, ':REQUEST', 1, 1, 1, 'i') > 0 
				   and APPLICATION_ID = p_Application_ID 
				   and PAGE_ID = p_App_Page_ID
			) S,
			TABLE( apex_string.split(S.REQUEST_IN_LIST, ',') ) P
			where REQUEST_IN_LIST is not null
			union all 
			select PROCESS_NAME,EXECUTION_SEQUENCE,
				PROCESS_TYPE, PROCESS_ID,
				REQUEST_IN_LIST WHEN_BUTTON_PRESSED,
				case when PROCESS_POINT_CODE  IN ('AFTER_SUBMIT','ON_SUBMIT_BEFORE_COMPUTATION') 
					then 'No' else 'Yes' 
				end EXECUTE_ON_PAGE_INIT,
				PROCESS_POINT_CODE, PROCESS_POINT,
				APPLICATION_ID, PAGE_ID
			from (
				select PROCESS_NAME,EXECUTION_SEQUENCE,
					case when PROCESS_TYPE_CODE = 'PLSQL' 
						then 'PL/SQL'
						else PROCESS_TYPE
					end PROCESS_TYPE, PROCESS_ID, 
					REGEXP_SUBSTR(CONDITION_EXPRESSION1, ':REQUEST\s+'||q.op||'\s*''(\S+)''', 1, 1, 'in', 1) REQUEST_IN_LIST,
					PROCESS_POINT_CODE, PROCESS_POINT,
					APPLICATION_ID, PAGE_ID
				  from APEX_APPLICATION_PAGE_PROC p
					, (select COLUMN_VALUE op FROM TABLE(apex_string.split(',:=:like:not like', ':'))) q
				 where CONDITION_TYPE_CODE = 'PLSQL_EXPRESSION'
				   and REGEXP_INSTR(CONDITION_EXPRESSION1, ':REQUEST', 1, 1, 1, 'i') > 0 
				   and APPLICATION_ID = p_Application_ID 
				   and PAGE_ID = p_App_Page_ID
			) where REQUEST_IN_LIST is not null
		), buttons_q as (
			select -- DA - when Button
				'B'||A.WHEN_BUTTON_ID SOURCE_ID, 'B' OBJECT_TYPE,
				NVL(B.LABEL, A.WHEN_BUTTON) SOURCE_NODE, A.WHEN_EVENT_NAME EDGE_LABEL, A.DYNAMIC_ACTION_NAME DEST_NODE, 
				'D' || A.DYNAMIC_ACTION_ID DEST_ID,
				'D' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
				B.REGION_ID, B.REGION, B.BUTTON_SEQUENCE,
				A.APPLICATION_ID, A.PAGE_ID
			  from APEX_APPLICATION_PAGE_DA A 
			  join APEX_APPLICATION_PAGE_BUTTONS B on A.WHEN_BUTTON_ID = B.BUTTON_ID and A.APPLICATION_ID = B.APPLICATION_ID
			 where A.WHEN_SELECTION_TYPE = 'Button'
			   and A.APPLICATION_ID = p_Application_ID 
			   and A.PAGE_ID = p_App_Page_ID
			union all -- other Buttons BUTTON -> REQUEST
			select 'B'||BUTTON_ID SOURCE_ID, 'B' OBJECT_TYPE,
				NVL(LABEL, BUTTON_NAME) SOURCE_NODE, BUTTON_ACTION EDGE_LABEL, BUTTON_NAME DEST_NODE, 
				'Q' || BUTTON_NAME DEST_ID,
				'Q' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
				REGION_ID, REGION, BUTTON_SEQUENCE,
				APPLICATION_ID, PAGE_ID
			  from APEX_APPLICATION_PAGE_BUTTONS
			 where (BUTTON_ACTION_CODE = 'SUBMIT'
				OR BUTTON_ACTION_CODE = 'REDIRECT_URL'
			   and REDIRECT_URL LIKE 'javascript:%'
			   )
			   and APPLICATION_ID = p_Application_ID 
			   and PAGE_ID = p_App_Page_ID
			union all -- other Buttons  -> BUTTON
			select 'B'||BUTTON_ID SOURCE_ID, 'B' OBJECT_TYPE,
				NVL(LABEL, BUTTON_NAME) SOURCE_NODE, 'Redirect' EDGE_LABEL, BUTTON_ACTION DEST_NODE, 
				'C' || BUTTON_ID DEST_ID,
				'C' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
				REGION_ID, REGION, BUTTON_SEQUENCE,
				APPLICATION_ID, PAGE_ID
			  from APEX_APPLICATION_PAGE_BUTTONS
			 where BUTTON_ACTION_CODE = 'REDIRECT_URL'
			   and REDIRECT_URL NOT LIKE 'javascript:%'
			   and APPLICATION_ID = p_Application_ID 
			   and PAGE_ID = p_App_Page_ID
		),  report_links_q as ( 
			select REGION_NAME, REGION_ID, ENTRY_TEXT, COLUMN_ALIAS, 
				ENTRY_TARGET,
				case when ENTRY_TARGET LIKE 'javascript%' then
					case when ENTRY_TARGET LIKE '%apex.submit%' 
					or ENTRY_TARGET LIKE '%apex.confirm%' 
						then 'Submit'
						else 'Javascript'
					end 
				when ENTRY_TARGET LIKE 'f?p=%' 
					then 'Link'
				end TARGET_TYPE, -- Submit / Javascript / Link / Null			
				DISPLAY_SEQUENCE, APPLICATION_ID, PAGE_ID
			from (
				select REGION_NAME, REGION_ID,	-- classic report.
					HEADING ENTRY_TEXT,
					COLUMN_ALIAS, 
					COLUMN_LINK_URL ENTRY_TARGET,
					DISPLAY_SEQUENCE, APPLICATION_ID, PAGE_ID
				  from APEX_APPLICATION_PAGE_RPT_COLS
				 where APPLICATION_ID = p_Application_ID
				   and PAGE_ID = p_App_Page_ID
				   and COLUMN_LINK_URL IS NOT NULL
				union all 
				select REGION_NAME, REGION_ID, 	-- interactive report.
					REPORT_LABEL ENTRY_TEXT,
					COLUMN_ALIAS,
					COLUMN_LINK ENTRY_TARGET,
					DISPLAY_ORDER, APPLICATION_ID, PAGE_ID
				  from APEX_APPLICATION_PAGE_IR_COL
				 where APPLICATION_ID = p_Application_ID
				   and PAGE_ID = p_App_Page_ID
				   and COLUMN_LINK IS NOT NULL
				union all 
				select REGION_NAME, REGION_ID, -- interactive grid
					NVL(HEADING, NAME) ENTRY_TEXT,
					NAME COLUMN_ALIAS,
					LINK_TARGET ENTRY_TARGET,
					DISPLAY_SEQUENCE, APPLICATION_ID, PAGE_ID
				  from APEX_APPL_PAGE_IG_COLUMNS
				 where APPLICATION_ID = p_Application_ID
				   and PAGE_ID = p_App_Page_ID
				   and LINK_TARGET IS NOT NULL
			)
		), report_links_q2 as (
			select P.*, P.REGION_ID||'_'||P.DISPLAY_SEQUENCE TARGET_ID
			from (
				select * 
				from (
					select REGION_ID, REGION_NAME, COLUMN_ALIAS, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
						REGEXP_SUBSTR(ENTRY_TARGET, '.*'||q.op||'\s*\(.*[''"](\S+)[''"]', 1, 1, 'in', 1) REQUEST, -- extract request 
						APPLICATION_ID, PAGE_ID
					from report_links_q P, (select COLUMN_VALUE op FROM TABLE(apex_string.split('apex\.confirm:apex\.submit', ':'))) Q
					where TARGET_TYPE = 'Submit'
				) where REQUEST IS NOT NULL
				union  
				select * 
				from (
					select REGION_ID, REGION_NAME, COLUMN_ALIAS, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
						data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 4)	REQUEST, -- extract request 
						APPLICATION_ID, PAGE_ID
					from report_links_q P
					where TARGET_TYPE = 'Link'
				) 
				union  
				select REGION_ID, REGION_NAME, COLUMN_ALIAS, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
					NULL REQUEST, APPLICATION_ID, PAGE_ID
				from report_links_q P
				where TARGET_TYPE = 'Javascript'
			) P
		)
		-----------------------------------------------------------------------------------
		-- event sources => action name
		select 'I'||TRIM(N.COLUMN_VALUE) SOURCE_ID, 'I' OBJECT_TYPE,
			TRIM(N.COLUMN_VALUE) SOURCE_NODE, WHEN_EVENT_NAME EDGE_LABEL, DYNAMIC_ACTION_NAME DEST_NODE, 
			'D' || DYNAMIC_ACTION_ID DEST_ID,
			'D' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA A, TABLE( apex_string.split(A.WHEN_ELEMENT, ',')) N
		 where WHEN_SELECTION_TYPE = 'Item'
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all 
		select SOURCE_ID, OBJECT_TYPE, SOURCE_NODE, EDGE_LABEL, 
			DEST_NODE, DEST_ID, DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from buttons_q
		UNION ALL --  region => button
		select 'R'||REGION_ID SOURCE_ID, 'R' OBJECT_TYPE, REGION SOURCE_NODE,
			TO_CHAR(BUTTON_SEQUENCE) EDGE_LABEL, 
			SOURCE_NODE DEST_NODE, 
			SOURCE_ID DEST_ID, 
			OBJECT_TYPE DEST_OBJECT_TYPE, 
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from buttons_q
		union all -- region -> Dynamic_Action
		select 'R'||WHEN_REGION_ID SOURCE_ID, 'R' OBJECT_TYPE,
			WHEN_REGION SOURCE_NODE, WHEN_EVENT_NAME EDGE_LABEL, DYNAMIC_ACTION_NAME DEST_NODE, 
			'D' || DYNAMIC_ACTION_ID DEST_ID,
			'D' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA
		 where WHEN_SELECTION_TYPE = 'Region'
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all -- jquery -> Dynamic_Action
		select 'J'||DYNAMIC_ACTION_ID SOURCE_ID, 'J' OBJECT_TYPE,
			WHEN_ELEMENT SOURCE_NODE, WHEN_EVENT_NAME EDGE_LABEL, DYNAMIC_ACTION_NAME DEST_NODE, 
			'D' || DYNAMIC_ACTION_ID DEST_ID,
			'D' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA
		 where WHEN_SELECTION_TYPE = 'jQuery Selector'
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		-------------------- action name => true / false ---------------------------------------
		union all -- Dynamic Action / TRUE
		select 'D'||DYNAMIC_ACTION_ID SOURCE_ID, 'D' OBJECT_TYPE,
			DYNAMIC_ACTION_NAME SOURCE_NODE, 
			null EDGE_LABEL,
			'True' DEST_NODE, 'T'||DYNAMIC_ACTION_ID DEST_ID,
			'T' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA
		 where APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all  -- Dynamic Action / FALSE
		select 'D'||DYNAMIC_ACTION_ID SOURCE_ID, 'D' OBJECT_TYPE,
			DYNAMIC_ACTION_NAME SOURCE_NODE, 
			null EDGE_LABEL,
			'False' DEST_NODE, 'F'||DYNAMIC_ACTION_ID DEST_ID,
			'F' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA A
		 where WHEN_CONDITION IS NOT NULL
		   and exists (
			select 1 
			from APEX_APPLICATION_PAGE_DA_ACTS B
			where B.DYNAMIC_ACTION_ID = A.DYNAMIC_ACTION_ID
			and B.APPLICATION_ID = A.APPLICATION_ID
			and B.PAGE_ID = A.PAGE_ID
			and DYNAMIC_ACTION_EVENT_RESULT = 'False'
		   )
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		-------------------- true / false => function ---------------------------------------
		union all 
		select distinct substr(DYNAMIC_ACTION_EVENT_RESULT, 1, 1) || DYNAMIC_ACTION_ID SOURCE_ID, 
			substr(DYNAMIC_ACTION_EVENT_RESULT, 1, 1) OBJECT_TYPE,
			DYNAMIC_ACTION_EVENT_RESULT SOURCE_NODE,
			TO_CHAR(ACTION_SEQUENCE) EDGE_LABEL,
			case when ACTION_CODE = 'NATIVE_JAVASCRIPT_CODE' then 'Javascript' 
				when ACTION_CODE = 'NATIVE_EXECUTE_PLSQL_CODE' then 'PL/SQL' 
			else ACTION_NAME end DEST_NODE, 
			'C'||ACTION_ID DEST_ID,
			'C' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS A
		 where APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		----------------- function => affected elements --------------------------------------
		union all  -- Submit or Code => REQUEST  
		select 'C'||ACTION_ID SOURCE_ID, 
			'C' OBJECT_TYPE,
			ACTION_NAME SOURCE_NODE,
			TO_CHAR(ACTION_SEQUENCE) EDGE_LABEL,
			ATTRIBUTE_01 DEST_NODE, 'Q'||ATTRIBUTE_01 DEST_ID,
			'Q' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS A
		 where ACTION_CODE = 'NATIVE_SUBMIT_PAGE'
		   and ATTRIBUTE_01 IS NOT NULL
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all  --  Processing Point => affected REQUEST
		select distinct
			'P'||PROCESS_POINT_CODE SOURCE_ID, 
			'P' OBJECT_TYPE,
			PROCESS_POINT SOURCE_NODE,
			'' EDGE_LABEL,
			WHEN_BUTTON_PRESSED DEST_NODE, 
			'Q'||WHEN_BUTTON_PRESSED DEST_ID, 
			'Q' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from page_procs
		union all  -- affected REQUEST => Submit Page Processing
		select 'Q'||WHEN_BUTTON_PRESSED SOURCE_ID, 
			'Q' OBJECT_TYPE,
			WHEN_BUTTON_PRESSED SOURCE_NODE,
			TO_CHAR(EXECUTION_SEQUENCE) EDGE_LABEL,
			PROCESS_NAME DEST_NODE, 
			'X'||PROCESS_ID DEST_ID, 
			'X' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from page_procs
		------------------------------------------------------------------------------
		union all -- Processing Point => page process
		select
			'P'||PROCESS_POINT_CODE SOURCE_ID, 
			'P' OBJECT_TYPE, 
			PROCESS_POINT SOURCE_NODE,
			TO_CHAR(EXECUTION_SEQUENCE) EDGE_LABEL,
			PROCESS_NAME DEST_NODE,
			'X'||PROCESS_ID DEST_ID, 
			'X' DEST_OBJECT_TYPE,
			case when PROCESS_POINT_CODE  IN ('AFTER_SUBMIT','ON_SUBMIT_BEFORE_COMPUTATION') 
				then 'No' else 'Yes' 
			end EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_PROC S 
		 where not exists ( -- skip already linked processes 
				select 1 from page_procs T 
				where S.PROCESS_ID = T.PROCESS_ID
				and S.APPLICATION_ID = T.APPLICATION_ID
				and S.PAGE_ID = T.PAGE_ID
		   )
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		------------------------------------------------------------------------------
		union all  -- Branches -- affected REQUEST => Submit Page Processing
		select 'Q'||WHEN_BUTTON_PRESSED SOURCE_ID, 
			'Q' OBJECT_TYPE,
			WHEN_BUTTON_PRESSED SOURCE_NODE,
			TO_CHAR(PROCESS_SEQUENCE) EDGE_LABEL,
			NVL(BRANCH_NAME, BRANCH_TYPE) 
			|| case  
			when BRANCH_TYPE = 'Branch to Page' then 
					' ' || BRANCH_ACTION 
			when BRANCH_TYPE = 'Branch to Page or URL' then 
					' ' || data_browser_conf.Get_APEX_URL_Element(BRANCH_ACTION, 2)	-- extract page id 
			end DEST_NODE, 
			'L'||BRANCH_ID DEST_ID, 
			'L' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from (
			select BRANCH_NAME, BRANCH_ACTION, PROCESS_SEQUENCE,
				BRANCH_TYPE, BRANCH_ID,
				case when WHEN_BUTTON_PRESSED IS NOT NULL  
					then WHEN_BUTTON_PRESSED
					when CONDITION_TYPE_CODE = 'REQUEST_EQUALS_CONDITION' 
					then CONDITION_EXPRESSION1
				end WHEN_BUTTON_PRESSED,
				APPLICATION_ID, PAGE_ID
			  from APEX_APPLICATION_PAGE_BRANCHES
			 where (WHEN_BUTTON_PRESSED IS NOT NULL or CONDITION_TYPE_CODE = 'REQUEST_EQUALS_CONDITION' )
			   and APPLICATION_ID = p_Application_ID 
			   and PAGE_ID = p_App_Page_ID
			union all 
			select BRANCH_NAME, BRANCH_ACTION,PROCESS_SEQUENCE,
					BRANCH_TYPE, BRANCH_ID,
					REGEXP_REPLACE(TRIM(COLUMN_VALUE), '^''(.*)''$', '\1') WHEN_BUTTON_PRESSED,
					APPLICATION_ID, PAGE_ID
			from (
				select BRANCH_NAME, BRANCH_ACTION,PROCESS_SEQUENCE,BRANCH_POINT,
					BRANCH_TYPE,BRANCH_ID,
					REGEXP_SUBSTR(CONDITION_EXPRESSION1, ':REQUEST\s+'||q.op||'\s*\((.+)\)', 1, 1, 'in', 1) REQUEST_IN_LIST,
					APPLICATION_ID, PAGE_ID
				  from APEX_APPLICATION_PAGE_BRANCHES p
					, (select COLUMN_VALUE op FROM TABLE(apex_string.split('in:not in', ':'))) q
				 where CONDITION_TYPE_CODE = 'PLSQL_EXPRESSION'
				   and REGEXP_INSTR(CONDITION_EXPRESSION1, ':REQUEST', 1, 1, 1, 'i') > 0 
				   and APPLICATION_ID = p_Application_ID 
				   and PAGE_ID = p_App_Page_ID
			) S,
			TABLE( apex_string.split(S.REQUEST_IN_LIST, ',') ) P
			where REQUEST_IN_LIST is not null
			union all 
			select BRANCH_NAME, BRANCH_ACTION,PROCESS_SEQUENCE,
				BRANCH_TYPE, BRANCH_ID,
				REQUEST_IN_LIST WHEN_BUTTON_PRESSED, 
				APPLICATION_ID, PAGE_ID
			from (
				select BRANCH_NAME, BRANCH_ACTION,PROCESS_SEQUENCE,
					BRANCH_TYPE, BRANCH_ID,
					REGEXP_SUBSTR(CONDITION_EXPRESSION1, ':REQUEST\s+'||q.op||'\s*''(\S+)''', 1, 1, 'in', 1) REQUEST_IN_LIST,
					APPLICATION_ID, PAGE_ID
				  from APEX_APPLICATION_PAGE_BRANCHES p
					, (select COLUMN_VALUE op FROM TABLE(apex_string.split(',:=:like:not like', ':'))) q
				 where CONDITION_TYPE_CODE = 'PLSQL_EXPRESSION'
				   and REGEXP_INSTR(CONDITION_EXPRESSION1, ':REQUEST', 1, 1, 1, 'i') > 0 
				   and APPLICATION_ID = p_Application_ID 
				   and PAGE_ID = p_App_Page_ID
			) where REQUEST_IN_LIST is not null
		)
		------------------------------------------------------------------------------
		union all  -- affected BUTTON elements 
		select 'C'||A.ACTION_ID SOURCE_ID, 
			'C' OBJECT_TYPE,
			A.ACTION_NAME SOURCE_NODE,
			TO_CHAR(A.ACTION_SEQUENCE) EDGE_LABEL,
			NVL(B.LABEL, A.AFFECTED_BUTTON) DEST_NODE, 'B'||A.AFFECTED_BUTTON_ID DEST_ID,
			'B' DEST_OBJECT_TYPE, A.EXECUTE_ON_PAGE_INIT,
			A.APPLICATION_ID, A.PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS A
		  join APEX_APPLICATION_PAGE_BUTTONS B on A.AFFECTED_BUTTON_ID = B.BUTTON_ID and A.APPLICATION_ID = B.APPLICATION_ID
		 where A.AFFECTED_ELEMENTS_TYPE_CODE = 'BUTTON'
		   and A.APPLICATION_ID = p_Application_ID 
		   and A.PAGE_ID = p_App_Page_ID
		union all  -- affected ITEM 
		select 'C'||ACTION_ID SOURCE_ID, 
			'C' OBJECT_TYPE,
			ACTION_NAME SOURCE_NODE,
			TO_CHAR(ACTION_SEQUENCE) EDGE_LABEL,
			TRIM(N.COLUMN_VALUE) DEST_NODE, 'I'||TRIM(N.COLUMN_VALUE) DEST_ID,
			'I' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS A, TABLE( apex_string.split(A.AFFECTED_ELEMENTS, ',')) N
		 where AFFECTED_ELEMENTS_TYPE_CODE = 'ITEM'
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all -- PL/SQL Code input ITEM ------------------------------------
		select 'I'||TRIM(N.COLUMN_VALUE) SOURCE_ID, 'I' OBJECT_TYPE,
			TRIM(N.COLUMN_VALUE) SOURCE_NODE, 
			'Input' EDGE_LABEL,
			case when ACTION_CODE = 'NATIVE_JAVASCRIPT_CODE' then 'Javascript' 
				when ACTION_CODE = 'NATIVE_EXECUTE_PLSQL_CODE' then 'PL/SQL' 
			else ACTION_NAME end DEST_NODE, 
			'C'||ACTION_ID DEST_ID,
			'C' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS A, TABLE( apex_string.split(A.ATTRIBUTE_02, ',')) N
		 where ACTION_CODE = 'NATIVE_EXECUTE_PLSQL_CODE'
		   and ATTRIBUTE_02 IS NOT NULL 
		   and exists (
			select 1 
			from APEX_APPLICATION_PAGE_DA_ACTS B, TABLE( apex_string.split(B.AFFECTED_ELEMENTS, ',')) C
			 where B.APPLICATION_ID = A.APPLICATION_ID
			   and B.PAGE_ID = A.PAGE_ID
			   and B.AFFECTED_ELEMENTS_TYPE_CODE = 'ITEM'
			   AND TRIM(C.COLUMN_VALUE) = TRIM(N.COLUMN_VALUE)
		   )
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all -- affected REGION; code -> region 
		select 'C'||ACTION_ID SOURCE_ID, 
			'C' OBJECT_TYPE,
			case when ACTION_CODE = 'NATIVE_JAVASCRIPT_CODE' then 'Javascript' else ACTION_NAME end SOURCE_NODE,
			TO_CHAR(ACTION_SEQUENCE) EDGE_LABEL,
			AFFECTED_REGION DEST_NODE, 'R'||AFFECTED_REGION_ID DEST_ID,
			'R' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS
		 where ACTION_CODE != 'NATIVE_EXECUTE_PLSQL_CODE' 
		   and AFFECTED_ELEMENTS_TYPE_CODE = 'REGION'
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all -- PL/SQL Code affected ITEM --
		select 'C'||ACTION_ID SOURCE_ID, 
			'C' OBJECT_TYPE,
			'PL/SQL' SOURCE_NODE,
			TO_CHAR(ACTION_SEQUENCE) EDGE_LABEL,
			TRIM(N.COLUMN_VALUE) DEST_NODE, 
			'I'||TRIM(N.COLUMN_VALUE) DEST_ID,
			'I' DEST_OBJECT_TYPE, EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_DA_ACTS A, TABLE( apex_string.split(A.ATTRIBUTE_03, ',')) N
		 where ACTION_CODE = 'NATIVE_EXECUTE_PLSQL_CODE'
		   and ATTRIBUTE_03 IS NOT NULL 
		   and AFFECTED_ELEMENTS_TYPE_CODE IS NULL
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		union all -- Page Items to Submit -> Region
		select 'I'||TRIM(N.COLUMN_VALUE) SOURCE_ID, 
			'I' OBJECT_TYPE,
			TRIM(N.COLUMN_VALUE) SOURCE_NODE,
			'Input' EDGE_LABEL,
			REGION_NAME DEST_NODE, 'R'||REGION_ID DEST_ID,
			'R' DEST_OBJECT_TYPE, 'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		  from APEX_APPLICATION_PAGE_REGIONS R, TABLE( apex_string.split(R.AJAX_ITEMS_TO_SUBMIT, ',')) N
		 where AJAX_ITEMS_TO_SUBMIT IS NOT NULL
		   and APPLICATION_ID = p_Application_ID 
		   and PAGE_ID = p_App_Page_ID
		-----------------------------------------------------------------------------------------
		union all -- List-Regions -> REQUEST (in Submit, Link)
		select 'R'||REGION_ID SOURCE_ID, 
			'R' OBJECT_TYPE,				-- Region
			REGION_NAME SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| ' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			DEST_NODE,
			'A'||TARGET_ID DEST_ID, 
			'A' DEST_OBJECT_TYPE,			-- Link 
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from list_q2 
		where TARGET_TYPE = 'Link'
		union all -- Link => Request 
		select 
			'A'||TARGET_ID SOURCE_ID, 
			'A' OBJECT_TYPE,				-- Link 
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| ' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,		
			REQUEST DEST_NODE,	
			'Q'||REQUEST DEST_ID, 			-- Request 
			'Q' DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from list_q2 
		where REQUEST IS NOT NULL 
		and TARGET_TYPE = 'Link'
		union all -- region -> Code / Link
		select 'R'||REGION_ID SOURCE_ID, 
			'R' OBJECT_TYPE,
			REGION_NAME SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)
			|| case when TARGET_TYPE = 'Link' then
				' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			end DEST_NODE,
			case when TARGET_TYPE = 'Link' then 'A'||TARGET_ID else 'E'||TARGET_ID end DEST_ID, 
			case when TARGET_TYPE = 'Link' then 'A' else 'E' end  DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from list_q2 
		union all -- Code -> Request
		select 'E'||TARGET_ID SOURCE_ID, 
			'E' OBJECT_TYPE,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT) SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			REQUEST DEST_NODE,	
			'Q'||REQUEST DEST_ID, 			-- Request 
			'Q' DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from list_q2 
		where REQUEST IS NOT NULL
		and TARGET_TYPE IN ('Javascript', 'Submit')
		-----------------------------------------------------------------------------------------
		union all	-- report links --
		select 'R'||REGION_ID SOURCE_ID, 
			'R' OBJECT_TYPE,				-- Reqion 
			REGION_NAME SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| ' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			DEST_NODE,
			'K'||TARGET_ID DEST_ID, 
			'K' DEST_OBJECT_TYPE,			-- Link 
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from report_links_q2 
		where TARGET_TYPE = 'Link'
		union all -- Link => Request 
		select 
			'K'||TARGET_ID SOURCE_ID, 
			'K' OBJECT_TYPE,				-- Link 
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| ' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,		
			REQUEST DEST_NODE,	
			'Q'||REQUEST DEST_ID, 			-- Request 
			'Q' DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from report_links_q2 
		where REQUEST IS NOT NULL 
		and TARGET_TYPE = 'Link'
		union all -- region -> Code / Link
		select 'R'||REGION_ID SOURCE_ID, 
			'R' OBJECT_TYPE,
			REGION_NAME SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| case when TARGET_TYPE = 'Link' then
				' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			end DEST_NODE,
			case when TARGET_TYPE = 'Link' then 'K'||TARGET_ID else 'N'||TARGET_ID end DEST_ID, 
			case when TARGET_TYPE = 'Link' then 'K' else 'N' end  DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from report_links_q2 
		union all -- Code -> Request
		select 'N'||TARGET_ID SOURCE_ID, 
			'N' OBJECT_TYPE,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT) SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			REQUEST DEST_NODE,	
			'Q'||REQUEST DEST_ID, 			-- Request 
			'Q' DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from report_links_q2 
		where REQUEST IS NOT NULL
		and TARGET_TYPE IN ('Javascript', 'Submit')
		;

        CURSOR menues_cur
        IS
		with menues_q as (
			select AP.THEME_NUMBER, AT.UI_TYPE_ID,
				UI.UI_TYPE_NAME, Ui.GLOBAL_PAGE_ID,
				UI.NAV_BAR_LIST, UI.NAV_BAR_LIST_ID, 
				UI.NAVIGATION_LIST, UI.NAVIGATION_LIST_ID,
				AP.APPLICATION_ID
			  from APEX_APPLICATIONS AP
			  join APEX_APPLICATION_THEMES AT on AP.APPLICATION_ID = AT.APPLICATION_ID and AP.THEME_NUMBER = AT.THEME_NUMBER
			  join APEX_APPL_USER_INTERFACES UI on AP.APPLICATION_ID = UI.APPLICATION_ID and AT.UI_TYPE_ID = UI.UI_TYPE_ID
			 where AP.APPLICATION_ID = p_Application_ID
		), menu_lists_q as (
			select M.NAVIGATION_LIST_ID LIST_ID, M.NAVIGATION_LIST LIST_NAME,
				E.LIST_ENTRY_ID, E.ENTRY_TEXT, E.ENTRY_TARGET, 
				case when E.ENTRY_TARGET LIKE 'javascript%' then
					case when E.ENTRY_TARGET LIKE '%apex.submit%' 
					or E.ENTRY_TARGET LIKE '%apex.confirm%' 
						then 'Submit'
						else 'Javascript'
					end 
				when E.ENTRY_TARGET LIKE 'f?p=%' 
					then 'Link'
				end TARGET_TYPE, -- Submit / Javascript / Link / Null
				E.DISPLAY_SEQUENCE,
				M.APPLICATION_ID, 
				M.GLOBAL_PAGE_ID PAGE_ID
			from menues_q M 
			join APEX_APPLICATION_LIST_ENTRIES E ON E.APPLICATION_ID = M.APPLICATION_ID AND E.LIST_ID = M.NAVIGATION_LIST_ID
			union all 
			select M.NAV_BAR_LIST_ID LIST_ID, M.NAV_BAR_LIST LIST_NAME,
				E.LIST_ENTRY_ID, E.ENTRY_TEXT, E.ENTRY_TARGET, 
				case when E.ENTRY_TARGET LIKE 'javascript%' then
					case when E.ENTRY_TARGET LIKE '%apex.submit%' 
					or E.ENTRY_TARGET LIKE '%apex.confirm%' 
						then 'Submit'
						else 'Javascript'
					end 
				when E.ENTRY_TARGET LIKE 'f?p=%' 
					then 'Link'
				end TARGET_TYPE, -- Submit / Javascript / Link / Null
				E.DISPLAY_SEQUENCE,
				M.APPLICATION_ID, 
				M.GLOBAL_PAGE_ID PAGE_ID
			from menues_q M 
			join APEX_APPLICATION_LIST_ENTRIES E ON E.APPLICATION_ID = M.APPLICATION_ID AND E.LIST_ID = M.NAV_BAR_LIST_ID
		), menu_lists_q2 as (
			select P.*, P.LIST_ID||'_'||P.LIST_ENTRY_ID TARGET_ID
			from (
				select * 
				from (
					select LIST_ID, LIST_NAME, LIST_ENTRY_ID, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
						REGEXP_SUBSTR(ENTRY_TARGET, '.*'||q.op||'\s*\(.*[''"](\S+)[''"]', 1, 1, 'in', 1) REQUEST, -- extract request 
						APPLICATION_ID, PAGE_ID
					from menu_lists_q P, (select COLUMN_VALUE op FROM TABLE(apex_string.split('apex\.confirm:apex\.submit', ':'))) Q
					where TARGET_TYPE = 'Submit'
				) where REQUEST IS NOT NULL
				union  
				select * 
				from (
					select LIST_ID, LIST_NAME, LIST_ENTRY_ID, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
						data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 4)	REQUEST, -- extract request 
						APPLICATION_ID, PAGE_ID
					from menu_lists_q P
					where TARGET_TYPE = 'Link'
				) 
				union  
				select LIST_ID, LIST_NAME, LIST_ENTRY_ID, ENTRY_TEXT, ENTRY_TARGET, TARGET_TYPE, DISPLAY_SEQUENCE,
					NULL REQUEST, APPLICATION_ID, PAGE_ID
				from menu_lists_q P
				where TARGET_TYPE = 'Javascript'
			) P
		)
		select 'M'||LIST_ID SOURCE_ID, 
			'M' OBJECT_TYPE,				-- Menu 
			LIST_NAME SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| ' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			DEST_NODE,
			'G'||TARGET_ID DEST_ID, 
			'G' DEST_OBJECT_TYPE,			-- Link 
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from menu_lists_q2 
		where TARGET_TYPE = 'Link'
		union all -- Link => Request 
		select 
			'G'||TARGET_ID SOURCE_ID, 
			'G' OBJECT_TYPE,				-- Link 
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| ' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,		
			REQUEST DEST_NODE,	
			'Q'||REQUEST DEST_ID, 			-- Request 
			'Q' DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from menu_lists_q2 
		where REQUEST IS NOT NULL 
		and TARGET_TYPE = 'Link'
		union all -- region -> Code / Link
		select 'M'||LIST_ID SOURCE_ID, 
			'M' OBJECT_TYPE,
			LIST_NAME SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT)  
			|| case when TARGET_TYPE = 'Link' then
				' P ' || data_browser_conf.Get_APEX_URL_Element(ENTRY_TARGET, 2)	-- extract page id 
			end DEST_NODE,
			case when TARGET_TYPE = 'Link' then 'G'||TARGET_ID else 'H'||TARGET_ID end DEST_ID, 
			case when TARGET_TYPE = 'Link' then 'G' else 'H' end  DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from menu_lists_q2 
		union all -- Code -> Request
		select 'H'||TARGET_ID SOURCE_ID, 
			'H' OBJECT_TYPE,
			NVL(apex_plugin_util.replace_substitutions(ENTRY_TEXT), ENTRY_TEXT) SOURCE_NODE,
			TO_CHAR(TARGET_TYPE) EDGE_LABEL,
			REQUEST DEST_NODE,	
			'Q'||REQUEST DEST_ID, 			-- Request 
			'Q' DEST_OBJECT_TYPE,
			'No' EXECUTE_ON_PAGE_INIT,
			APPLICATION_ID, PAGE_ID
		from menu_lists_q2 
		where REQUEST IS NOT NULL
		and TARGET_TYPE = 'Javascript'
		;

		v_limit CONSTANT PLS_INTEGER := 100;
        v_in_rows tab_apex_dyn_actions;
	BEGIN
		OPEN dyn_actions_cur;
		LOOP
			FETCH dyn_actions_cur BULK COLLECT INTO v_in_rows LIMIT v_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE dyn_actions_cur;
		
		if p_App_Page_ID IN (0, 1) then
			OPEN menues_cur;
			LOOP
				FETCH menues_cur BULK COLLECT INTO v_in_rows LIMIT v_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE menues_cur;
		end if;
	END FN_Pipe_Apex_Dyn_Actions;


	FUNCTION FN_Pipe_object_dependences (
		p_Exclude_Singles IN VARCHAR2 DEFAULT 'YES',
		p_Include_App_Objects IN VARCHAR2 DEFAULT 'NO',
		p_Include_External IN VARCHAR2 DEFAULT 'YES',
		p_Include_Sys  IN VARCHAR2 DEFAULT 'NO',
		p_Object_Owner IN VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
		p_Object_Types IN VARCHAR2 DEFAULT 'KEY CONSTRAINT:CHECK CONSTRAINT:NOT NULL CONSTRAINT:FUNCTION:INDEX:MATERIALIZED VIEW:PACKAGE:PACKAGE BODY:PROCEDURE:SEQUENCE:SYNONYM:TABLE:TRIGGER:TYPE:TYPE BODY:VIEW',
		p_Object_Name IN VARCHAR2 DEFAULT NULL
	)
	RETURN data_browser_diagram_pipes.tab_object_dependences PIPELINED
	IS
		CURSOR all_objects_cur
		IS 	
		WITH Sys_Objects as (
			select * from table(data_browser_pipes.FN_Pipe_Sys_Objects(p_Include_External))
		), PARAM AS ( 
			SELECT  p_Object_Types 							Object_Types,
					p_Include_Sys 							Include_Sys,	-- YES/NO
					p_Include_External 						Include_External,	-- YES/NO
					p_Object_Owner 							Current_Schema
			FROM DUAL 
		), Depend_q as (
			SELECT TO_CHAR(SO.OBJECT_ID) NODE_NAME,
				SO.OBJECT_TYPE,
				SO.OBJECT_NAME,
				SO.OWNER OBJECT_OWNER,
				SO.STATUS,
				TO_CHAR(TA.OBJECT_ID) TARGET_NODE_NAME,
				TA.OBJECT_TYPE TARGET_OBJECT_TYPE,
				TA.OBJECT_NAME TARGET_OBJECT_NAME,
				TA.OWNER 	  TARGET_OBJECT_OWNER,
				TA.STATUS 	  TARGET_STATUS,
				INITCAP(TA.OBJECT_TYPE) LABEL,
				case when SO.OBJECT_TYPE = 'TABLE' then SO.OBJECT_NAME end TABLE_NAME,
				case when TA.OBJECT_TYPE = 'TABLE' then TA.OBJECT_NAME end TARGET_TABLE_NAME
			FROM Sys_Objects TA
			LEFT OUTER JOIN SYS.ALL_DEPENDENCIES D ON D.REFERENCED_OWNER = TA.OWNER
			AND D.REFERENCED_NAME = TA.OBJECT_NAME
			AND D.REFERENCED_TYPE = TA.OBJECT_TYPE
			LEFT OUTER JOIN Sys_Objects SO ON D.OWNER = SO.OWNER
			AND D.NAME = SO.OBJECT_NAME
			AND D.TYPE = SO.OBJECT_TYPE
			UNION ALL -- All Indexes -- 
			SELECT TO_CHAR(SO.OBJECT_ID) NODE_NAME,
				SO.OBJECT_TYPE,
				SO.OBJECT_NAME,
				SO.OWNER OBJECT_OWNER,
				SO.STATUS,
				TO_CHAR(TA.OBJECT_ID) TARGET_NODE_NAME,
				TA.OBJECT_TYPE TARGET_OBJECT_TYPE,
				TA.OBJECT_NAME TARGET_OBJECT_NAME,
				TA.OWNER 	  TARGET_OBJECT_OWNER,
				TA.STATUS 	  TARGET_STATUS,
				INITCAP(TA.OBJECT_TYPE) LABEL,
				case when SO.OBJECT_TYPE = 'TABLE' then SO.OBJECT_NAME end TABLE_NAME,
				case when TA.OBJECT_TYPE = 'TABLE' then TA.OBJECT_NAME end TARGET_TABLE_NAME
			FROM Sys_Objects TA, SYS.ALL_INDEXES D, Sys_Objects SO
			WHERE D.TABLE_OWNER = TA.OWNER
			AND D.TABLE_NAME = TA.OBJECT_NAME
			AND D.TABLE_TYPE = TA.OBJECT_TYPE
			AND D.OWNER = SO.OWNER
			AND D.INDEX_NAME = SO.OBJECT_NAME
			AND SO.OBJECT_TYPE = 'INDEX'
			UNION ALL -- All FK Constraints --
			SELECT TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') NODE_NAME,
				'REF CONSTRAINT' OBJECT_TYPE,
				TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') OBJECT_NAME,
				SO.OWNER OBJECT_OWNER,
				SO.STATUS,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_NODE_NAME,
				'KEY CONSTRAINT' TARGET_OBJECT_TYPE,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_OBJECT_NAME,
				TA.OWNER 	  TARGET_OBJECT_OWNER,
				TA.STATUS 	  TARGET_STATUS,
				case SO.CONSTRAINT_TYPE when 'C' then 'Check' when 'P' then 'Primary' when 'R' then 'Reference' when 'U' then 'Unique' else SO.CONSTRAINT_TYPE end LABEL,
				case when SO.VIEW_RELATED IS NULL then SO.TABLE_NAME end TABLE_NAME,
				case when TA.VIEW_RELATED IS NULL then TA.TABLE_NAME end TARGET_TABLE_NAME
			FROM SYS.ALL_CONSTRAINTS SO, SYS.ALL_CONSTRAINTS TA
			WHERE SO.R_OWNER = TA.OWNER
			AND SO.R_CONSTRAINT_NAME = TA.CONSTRAINT_NAME
			UNION ALL -- All_Object Constrants --
			SELECT TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') NODE_NAME,
				case SO.CONSTRAINT_TYPE 
				when 'C' then 
					case when SO.SEARCH_CONDITION_VC LIKE DBMS_ASSERT.ENQUOTE_NAME('%') || ' IS NOT NULL' then 
						'NOT NULL CONSTRAINT' else 'CHECK CONSTRAINT' 
					end
				else 'KEY CONSTRAINT' 
				end OBJECT_TYPE,
				TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') OBJECT_NAME,
				SO.OWNER OBJECT_OWNER,
				SO.STATUS,
				TO_CHAR(TA.OBJECT_ID) TARGET_NODE_NAME,
				TA.OBJECT_TYPE TARGET_OBJECT_TYPE,
				TA.OBJECT_NAME TARGET_OBJECT_NAME,
				TA.OWNER 	  TARGET_OBJECT_OWNER,
				TA.STATUS 	  TARGET_STATUS,
				case SO.CONSTRAINT_TYPE when 'C' then 'Check' when 'P' then 'Primary' when 'R' then 'Reference' when 'U' then 'Unique' else SO.CONSTRAINT_TYPE end LABEL,
				case when SO.VIEW_RELATED IS NULL then SO.TABLE_NAME end TABLE_NAME,
				case when TA.OBJECT_TYPE = 'TABLE' then TA.OBJECT_NAME end TARGET_TABLE_NAME
			FROM SYS.ALL_CONSTRAINTS SO, Sys_Objects TA
			WHERE SO.OWNER = TA.OWNER
			AND SO.TABLE_NAME = TA.OBJECT_NAME
			AND TA.OBJECT_TYPE = case when SO.VIEW_RELATED = 'DEPEND ON VIEW' then 'VIEW' else 'TABLE' end
			AND SO.CONSTRAINT_TYPE != 'R'
			UNION ALL -- All_Object Constrants --
			SELECT 
				TO_CHAR(SO.OBJECT_ID) NODE_NAME,
				SO.OBJECT_TYPE OBJECT_TYPE,
				SO.OBJECT_NAME OBJECT_NAME,
				SO.OWNER OBJECT_OWNER,
				SO.STATUS,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_NODE_NAME,
				'REF CONSTRAINT'  TARGET_OBJECT_TYPE,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_OBJECT_NAME,
				TA.OWNER 	  	TARGET_OBJECT_OWNER,
				TA.STATUS 		TARGET_STATUS,
				'Reference' 	LABEL,
				case when TA.VIEW_RELATED IS NULL then TA.TABLE_NAME end TABLE_NAME,
				case when SO.OBJECT_TYPE = 'TABLE' then SO.OBJECT_NAME end TARGET_TABLE_NAME
			FROM SYS.ALL_CONSTRAINTS TA, Sys_Objects SO
			WHERE SO.OWNER = TA.OWNER
			AND TA.TABLE_NAME = SO.OBJECT_NAME
			AND SO.OBJECT_TYPE = case when TA.VIEW_RELATED = 'DEPEND ON VIEW' then 'VIEW' else 'TABLE' end
			AND TA.CONSTRAINT_TYPE = 'R'
		) 
		SELECT /*+ RESULT_CACHE */ NODE_NAME, OBJECT_TYPE, OBJECT_NAME, OBJECT_OWNER,
			STATUS, TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, 
			TARGET_OBJECT_OWNER, TARGET_STATUS, LABEL, TABLE_NAME, TARGET_TABLE_NAME 
		FROM Depend_q, param
		WHERE ((TARGET_OBJECT_OWNER NOT IN ('PUBLIC', 'SYS') and TARGET_OBJECT_OWNER NOT LIKE 'APEX%') or Include_Sys = 'YES')
		AND (OBJECT_OWNER IS NULL or (OBJECT_OWNER NOT IN ('PUBLIC', 'SYS') and OBJECT_OWNER NOT LIKE 'APEX%') or Include_Sys = 'YES')
		AND (TARGET_OBJECT_OWNER = Current_Schema or Include_External = 'YES')
		AND (OBJECT_OWNER IS NULL or OBJECT_OWNER = Current_Schema or Include_External = 'YES')
		AND (OBJECT_NAME IS NOT NULL or p_Exclude_Singles = 'NO')
		AND Current_Schema IN (TARGET_OBJECT_OWNER, OBJECT_OWNER) 
		AND (p_Object_Name IN (OBJECT_NAME, TARGET_OBJECT_NAME) OR p_Object_Name IS NULL) -- optional search for one object_name
		AND (OBJECT_NAME IS NOT NULL or p_Exclude_Singles = 'NO')
		AND (OBJECT_TYPE IS NULL or OBJECT_TYPE IN (SELECT COLUMN_VALUE FROM table(apex_string.split(Object_Types,':'))))
		AND TARGET_OBJECT_TYPE IN (SELECT COLUMN_VALUE FROM table(apex_string.split(Object_Types,':')))
		AND (case when TABLE_NAME IS NULL then 'VIEW' else 'TABLE' end IN (SELECT COLUMN_VALUE FROM table(apex_string.split(Object_Types,':'))) 
		  or OBJECT_TYPE IS NULL or OBJECT_TYPE NOT IN ('KEY CONSTRAINT', 'CHECK CONSTRAINT', 'NOT NULL CONSTRAINT', 'REF CONSTRAINT'))
		AND (case when TARGET_TABLE_NAME IS NULL then 'VIEW' else 'TABLE' end IN (SELECT COLUMN_VALUE FROM table(apex_string.split(Object_Types,':')))
		  or TARGET_OBJECT_TYPE IS NULL or TARGET_OBJECT_TYPE NOT IN ('KEY CONSTRAINT', 'CHECK CONSTRAINT', 'NOT NULL CONSTRAINT', 'REF CONSTRAINT'))
		;
		
		CURSOR user_objects_cur
		IS 	
		WITH Sys_Objects as (
			select * from table(data_browser_pipes.FN_Pipe_Sys_Objects(p_Include_External))
		), Depend_q as (
			SELECT TO_CHAR(SO.OBJECT_ID) NODE_NAME,
				SO.OBJECT_TYPE,
				SO.OBJECT_NAME,
				SO.STATUS,
				TO_CHAR(TA.OBJECT_ID) TARGET_NODE_NAME,
				TA.OBJECT_TYPE TARGET_OBJECT_TYPE,
				TA.OBJECT_NAME TARGET_OBJECT_NAME,
				TA.STATUS 	  TARGET_STATUS,
				INITCAP(TA.OBJECT_TYPE) LABEL,
				case when SO.OBJECT_TYPE = 'TABLE' then SO.OBJECT_NAME end TABLE_NAME,
				case when TA.OBJECT_TYPE = 'TABLE' then TA.OBJECT_NAME end TARGET_TABLE_NAME
			FROM Sys_Objects TA
			LEFT OUTER JOIN SYS.USER_DEPENDENCIES D ON D.REFERENCED_NAME = TA.OBJECT_NAME
				AND D.REFERENCED_TYPE = TA.OBJECT_TYPE
				AND D.REFERENCED_OWNER = SYS_CONTEXT ('USERENV', 'CURRENT_SCHEMA')
			LEFT OUTER JOIN Sys_Objects SO ON D.NAME = SO.OBJECT_NAME
				AND D.TYPE = SO.OBJECT_TYPE
			UNION ALL -- All Indexes -- 
			SELECT TO_CHAR(SO.OBJECT_ID) NODE_NAME,
				SO.OBJECT_TYPE,
				SO.OBJECT_NAME,
				SO.STATUS,
				TO_CHAR(TA.OBJECT_ID) TARGET_NODE_NAME,
				TA.OBJECT_TYPE TARGET_OBJECT_TYPE,
				TA.OBJECT_NAME TARGET_OBJECT_NAME,
				TA.STATUS 	  TARGET_STATUS,
				INITCAP(TA.OBJECT_TYPE) LABEL,
				case when SO.OBJECT_TYPE = 'TABLE' then SO.OBJECT_NAME end TABLE_NAME,
				case when TA.OBJECT_TYPE = 'TABLE' then TA.OBJECT_NAME end TARGET_TABLE_NAME
			FROM Sys_Objects TA, SYS.USER_INDEXES D, Sys_Objects SO
			WHERE D.TABLE_NAME = TA.OBJECT_NAME
			AND D.TABLE_TYPE = TA.OBJECT_TYPE
			AND D.INDEX_NAME = SO.OBJECT_NAME
			AND SO.OBJECT_TYPE = 'INDEX'
			UNION ALL -- All FK Constraints --
			SELECT TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') NODE_NAME,
				'REF CONSTRAINT' OBJECT_TYPE,
				TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') OBJECT_NAME,
				SO.STATUS,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_NODE_NAME,
				'KEY CONSTRAINT' TARGET_OBJECT_TYPE,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_OBJECT_NAME,
				TA.STATUS 	  TARGET_STATUS,
				case SO.CONSTRAINT_TYPE when 'C' then 'Check' when 'P' then 'Primary' when 'R' then 'Reference' when 'U' then 'Unique' else SO.CONSTRAINT_TYPE end LABEL,
				case when SO.VIEW_RELATED IS NULL then SO.TABLE_NAME end TABLE_NAME,
				case when TA.VIEW_RELATED IS NULL then TA.TABLE_NAME end TARGET_TABLE_NAME
			FROM SYS.USER_CONSTRAINTS SO, SYS.USER_CONSTRAINTS TA
			WHERE SO.R_CONSTRAINT_NAME = TA.CONSTRAINT_NAME
			AND SO.R_OWNER = TA.OWNER
			UNION ALL -- All_Object Constrants --
			SELECT TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') NODE_NAME,
				case SO.CONSTRAINT_TYPE when 'C' then 
					case when SO.SEARCH_CONDITION_VC LIKE DBMS_ASSERT.ENQUOTE_NAME('%') || ' IS NOT NULL' then 
						'NOT NULL CONSTRAINT' else 'CHECK CONSTRAINT' 
					end
				else 'KEY CONSTRAINT' 
				end OBJECT_TYPE,
				TRANSLATE(SO.CONSTRAINT_NAME, ', ', '__') OBJECT_NAME,
				SO.STATUS,
				TO_CHAR(TA.OBJECT_ID) TARGET_NODE_NAME,
				TA.OBJECT_TYPE TARGET_OBJECT_TYPE,
				TA.OBJECT_NAME TARGET_OBJECT_NAME,
				TA.STATUS 	  TARGET_STATUS,
				case SO.CONSTRAINT_TYPE when 'C' then 'Check' when 'P' then 'Primary' when 'R' then 'Reference' when 'U' then 'Unique' else SO.CONSTRAINT_TYPE end LABEL,
				case when SO.VIEW_RELATED IS NULL then SO.TABLE_NAME end TABLE_NAME,
				case when TA.OBJECT_TYPE = 'TABLE' then TA.OBJECT_NAME end TARGET_TABLE_NAME
			FROM SYS.USER_CONSTRAINTS SO, Sys_Objects TA
			WHERE SO.TABLE_NAME = TA.OBJECT_NAME
			AND SO.OWNER = TA.OWNER
			AND TA.OBJECT_TYPE = case when SO.VIEW_RELATED = 'DEPEND ON VIEW' then 'VIEW' else 'TABLE' end
			AND SO.CONSTRAINT_TYPE != 'R'
			UNION ALL -- All_Object Constrants --
			SELECT 
				TO_CHAR(SO.OBJECT_ID) NODE_NAME,
				SO.OBJECT_TYPE OBJECT_TYPE,
				SO.OBJECT_NAME OBJECT_NAME,
				SO.STATUS,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_NODE_NAME,
				'REF CONSTRAINT'  TARGET_OBJECT_TYPE,
				TRANSLATE(TA.CONSTRAINT_NAME, ', ', '__') TARGET_OBJECT_NAME,
				TA.STATUS TARGET_STATUS,
				'Reference' 	LABEL,
				case when TA.VIEW_RELATED IS NULL then TA.TABLE_NAME end TABLE_NAME,
				case when SO.OBJECT_TYPE = 'TABLE' then SO.OBJECT_NAME end TARGET_TABLE_NAME
			FROM SYS.USER_CONSTRAINTS TA, Sys_Objects SO
			WHERE TA.TABLE_NAME = SO.OBJECT_NAME
			AND SO.OWNER = TA.OWNER
			AND SO.OBJECT_TYPE = case when TA.VIEW_RELATED = 'DEPEND ON VIEW' then 'VIEW' else 'TABLE' end
			AND TA.CONSTRAINT_TYPE = 'R'
		) 
		SELECT /*+ RESULT_CACHE */ NODE_NAME, OBJECT_TYPE, OBJECT_NAME, 
			SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') OBJECT_OWNER,
			STATUS, 
			TARGET_NODE_NAME, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, 
			SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') TARGET_OBJECT_OWNER,
			TARGET_STATUS, 
			LABEL, TABLE_NAME, TARGET_TABLE_NAME 
		FROM Depend_q
		WHERE (OBJECT_NAME IS NOT NULL or p_Exclude_Singles = 'NO')
		AND (p_Object_Name IN (OBJECT_NAME, TARGET_OBJECT_NAME) OR p_Object_Name IS NULL) -- optional search for one object_name
		AND (OBJECT_TYPE IS NULL or OBJECT_TYPE IN (SELECT COLUMN_VALUE FROM table(apex_string.split(p_Object_Types,':'))))
		AND TARGET_OBJECT_TYPE IN (SELECT COLUMN_VALUE FROM table(apex_string.split(p_Object_Types,':')))
		AND (case when TABLE_NAME IS NULL then 'VIEW' else 'TABLE' end IN (SELECT COLUMN_VALUE FROM table(apex_string.split(p_Object_Types,':'))) 
		  or OBJECT_TYPE IS NULL or OBJECT_TYPE NOT IN ('KEY CONSTRAINT', 'CHECK CONSTRAINT', 'NOT NULL CONSTRAINT', 'REF CONSTRAINT'))
		AND (case when TARGET_TABLE_NAME IS NULL then 'VIEW' else 'TABLE' end IN (SELECT COLUMN_VALUE FROM table(apex_string.split(p_Object_Types,':')))
		  or TARGET_OBJECT_TYPE IS NULL or TARGET_OBJECT_TYPE NOT IN ('KEY CONSTRAINT', 'CHECK CONSTRAINT', 'NOT NULL CONSTRAINT', 'REF CONSTRAINT'))
		;

		v_limit CONSTANT PLS_INTEGER := 100;
		v_in_rows tab_object_dependences;
	BEGIN
		if p_Include_External = 'YES' then 
			OPEN all_objects_cur;
			LOOP
				FETCH all_objects_cur BULK COLLECT INTO v_in_rows LIMIT v_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE all_objects_cur;  
		else
			OPEN user_objects_cur;
			LOOP
				FETCH user_objects_cur BULK COLLECT INTO v_in_rows LIMIT v_limit;
				EXIT WHEN v_in_rows.COUNT = 0;
				FOR ind IN 1 .. v_in_rows.COUNT LOOP
					pipe row (v_in_rows(ind));
				END LOOP;
			END LOOP;
			CLOSE user_objects_cur;  
		end if;
	END FN_Pipe_object_dependences;

END data_browser_diagram_pipes;
/

