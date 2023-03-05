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


CREATE OR REPLACE PACKAGE data_browser_trees
AUTHID CURRENT_USER
IS

	TYPE rec_tables_tree IS RECORD (
		STATUS								NUMBER,
		LEVEL_VAL							NUMBER,
		TITLE								VARCHAR2(256),
		ICON								VARCHAR2(30),
		VALUE								NUMBER,
		TOOLTIP								VARCHAR2(256),
		LINK								VARCHAR2(256),
		TREE_PATH							VARCHAR2(1024),
		CONSTRAINT_NAME						VARCHAR2(128)
	);
	TYPE tab_tables_tree IS TABLE OF rec_tables_tree;

	g_fetch_limit CONSTANT PLS_INTEGER := 100;

	FUNCTION FN_Pipe_Table_Tree (
		p_App_Developer_Mode VARCHAR2 DEFAULT V('APP_DEVELOPER_MODE'),	-- when YES, additional tables are listed
		p_Calculate_NUM_ROWS VARCHAR2 DEFAULT NULL, -- when YES, the rows count is calculated and displayed in the tree.
		p_Max_Relations_Levels NUMBER DEFAULT NULL -- Maximum Levels in the Tables Relations Tree 
	)
	RETURN data_browser_trees.tab_tables_tree PIPELINED;

	PROCEDURE Reset_Cache;

END data_browser_trees;
/

-- select status, level_val, title, icon, value, tooltip, link, tree_path, constraint_name from table (data_browser_trees.FN_Pipe_Table_Tree(p_App_Developer_Mode=>V('APP_DEVELOPER_MODE')));


CREATE OR REPLACE PACKAGE BODY data_browser_trees 
IS

	FUNCTION FN_Pipe_Table_Tree (
		p_App_Developer_Mode VARCHAR2 DEFAULT V('APP_DEVELOPER_MODE'),	-- when YES, additional tables are listed
		p_Calculate_NUM_ROWS VARCHAR2 DEFAULT NULL, -- when YES, the rows count is calculated and displayed in the tree.
		p_Max_Relations_Levels NUMBER DEFAULT NULL -- Maximum Levels in the Tables Relations Tree 
	)
	RETURN data_browser_trees.tab_tables_tree PIPELINED
	IS
		PRAGMA UDF;
		CURSOR tables_tree_cur (v_App_Developer_Mode VARCHAR2, v_Calculate_NUM_ROWS VARCHAR2, v_Max_Relations_Levels NUMBER)
		IS 	
		with t_list as (
			select T.VIEW_NAME, T.PRIMARY_KEY_COLS COLUMN_NAME,
				T.VIEW_NAME A_VIEW_NAME, 
				T.TABLE_NAME, T.CONSTRAINT_NAME, T.COLUMN_PREFIX, 
				T.NUM_ROWS,
				T.HTML_FIELD_COLUMN_NAME, T.FILE_FOLDER_COLUMN_NAME, T.FILE_CONTENT_COLUMN_NAME
			from MVDATA_BROWSER_DESCRIPTIONS T
			where (T.IS_ADMIN_TABLE = 'N' or v_App_Developer_Mode = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
			union all -- special case self reference --
			select T.VIEW_NAME, S.COLUMN_NAME,
				T.VIEW_NAME || '_' A_VIEW_NAME, 
				T.TABLE_NAME, T.CONSTRAINT_NAME, T.COLUMN_PREFIX, 
				T.NUM_ROWS,
				T.HTML_FIELD_COLUMN_NAME, T.FILE_FOLDER_COLUMN_NAME, T.FILE_CONTENT_COLUMN_NAME
			from MVDATA_BROWSER_DESCRIPTIONS T, 
				MVDATA_BROWSER_REFERENCES S
			where S.VIEW_NAME = S.R_VIEW_NAME -- recursion 
			and T.VIEW_NAME = S.VIEW_NAME     
			and (T.IS_ADMIN_TABLE = 'N' or v_App_Developer_Mode = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
		), r_list as (
			select R.VIEW_NAME, R.COLUMN_NAME, R.R_VIEW_NAME, 
				R.VIEW_NAME A_VIEW_NAME, 
				R.CONSTRAINT_NAME, 
				R.NUM_ROWS, 
				R.FOLDER_NAME_COLUMN_NAME, R.FOLDER_PARENT_COLUMN_NAME
			from MVDATA_BROWSER_REFERENCES R
			where R.VIEW_NAME != R.R_VIEW_NAME
			union all -- special case self reference --
			select R.VIEW_NAME, R.COLUMN_NAME, R.R_VIEW_NAME, 
				R.VIEW_NAME || '_' A_VIEW_NAME, 
				R.CONSTRAINT_NAME, 
				R.NUM_ROWS, 
				R.FOLDER_NAME_COLUMN_NAME, R.FOLDER_PARENT_COLUMN_NAME
			from MVDATA_BROWSER_REFERENCES R -- recursion 
			where R.VIEW_NAME = R.R_VIEW_NAME
		)
		SELECT 
			STATUS, 
			LEVEL_VAL, 
			SUBSTR(TITLE, 1, 256) TITLE, 
			SUBSTR(ICON, 1, 256) ICON, 
			VALUE, 
			SUBSTR(TOOLTIP, 1, 256) TOOLTIP, 
			SUBSTR(LINK, 1, 256) LINK, 
			SUBSTR(TREE_PATH, 1, 1024) TREE_PATH, 
			SUBSTR(CONSTRAINT_NAME, 1, 128)  CONSTRAINT_NAME
		FROM (
			select
				   case when connect_by_isleaf = 1 then 0
						when level = 1             then 1
						else                           -1
				   end as status, 
				   level level_val, 
				   TABLE_LABEL
					|| case when REF_LABEL IS NOT NULL
					and INSTR(prior TABLE_LABEL, REF_LABEL) = 0 and INSTR(REF_LABEL, prior TABLE_LABEL) = 0
						then ' – ' || REF_LABEL
					end
					|| case when NUM_ROWS > 0 then ' ( ' || ltrim(to_char(NUM_ROWS, '999G999G999G999G999G999G990')) || ' )'
					end as title, 
				   TABLE_ICON as icon, 
				   ORA_HASH(SYS_CONNECT_BY_PATH(TRANSLATE(VIEW_NAME, '/\:', '---'), '/')) as value, 
				   COMMENTS as tooltip, 
				   'javascript:Load_Tree_Node(' || DBMS_ASSERT.ENQUOTE_NAME(TRANSLATE(CONSTRAINT_NAME, ', ', '__')) 
				   || ','
				   || ORA_HASH(SYS_CONNECT_BY_PATH(TRANSLATE(VIEW_NAME, '/\:', '---'), '/'))
				   || ');' LINK,
				   SYS_CONNECT_BY_PATH(TRANSLATE(VIEW_NAME, '/\:', '---'), '/') TREE_PATH,
				   CONSTRAINT_NAME
			from (
				select T.VIEW_NAME, 
					  T.TABLE_NAME,
					  T.A_VIEW_NAME,
					  R.R_VIEW_NAME,
					  case when R.FOLDER_NAME_COLUMN_NAME is not null and R.FOLDER_PARENT_COLUMN_NAME  is not null  
						  then 'fa-folder-file'
						when COALESCE(D.SUMMAND_COLUMN_NAME, D.MINUEND_COLUMN_NAME, D.FACTORS_COLUMN_NAME) IS NOT NULL 
						then 'fa-table-new'
						when D.FOLDER_NAME_COLUMN_NAME IS NOT NULL and D.FOLDER_PARENT_COLUMN_NAME IS NOT NULL 
						then 'fa-folders' 
						when T.FILE_CONTENT_COLUMN_NAME IS NOT NULL and T.FILE_FOLDER_COLUMN_NAME IS NOT NULL 
						then 'fa-folder-file'
						when T.FILE_CONTENT_COLUMN_NAME IS NOT NULL and T.FILE_FOLDER_COLUMN_NAME IS NULL 
						then 'fa-table-file'
						when D.CALEND_START_DATE_COLUMN_NAME IS NOT NULL or D.CALENDAR_END_DATE_COLUMN_NAME IS NOT NULL 
						then 'fa-table-clock'
						when T.HTML_FIELD_COLUMN_NAME IS NOT NULL
						then 'fa-table-file'
						when T.VIEW_NAME = 'APP_USERS'
						then 'fa-table-user'
						else 'fa-table' 
						end TABLE_ICON,
					COALESCE(R.CONSTRAINT_NAME, T.CONSTRAINT_NAME, T.VIEW_NAME) CONSTRAINT_NAME,
					data_browser_conf.Table_Name_To_Header(T.VIEW_NAME) TABLE_LABEL,
					data_browser_conf.Column_Name_to_Header(
						p_Column_Name => R.COLUMN_NAME, 
						p_Remove_Extension => 'YES', 
						p_Remove_Prefix => T.COLUMN_PREFIX) REF_LABEL,
					case when v_Calculate_NUM_ROWS = 'NO' then 
						NULL
					when data_browser_conf.Has_Multiple_Workspaces = 'NO' then
						case when R.A_VIEW_NAME IS NOT NULL then 
							R.NUM_ROWS
						else
							T.NUM_ROWS
						end 
					else 
						case when R.A_VIEW_NAME IS NOT NULL then 
							data_browser_conf.FN_Query_Cardinality(R.VIEW_NAME, R.COLUMN_NAME ) 
						else
							data_browser_conf.FN_Query_Cardinality(T.VIEW_NAME, T.COLUMN_NAME ) 
						end 
					end NUM_ROWS, 
					D.COMMENTS
				from t_list T
				, MVDATA_BROWSER_DESCRIPTIONS D 
				, r_list R 
				WHERE T.VIEW_NAME = D.VIEW_NAME
				AND T.A_VIEW_NAME = R.A_VIEW_NAME (+)
			) T
			start with R_VIEW_NAME is null
			connect by NOCYCLE prior A_VIEW_NAME = R_VIEW_NAME AND LEVEL <= v_Max_Relations_Levels
			order siblings by TABLE_LABEL, REF_LABEL
		);
    	v_App_Developer_Mode CONSTANT VARCHAR2(10) := NVL(p_App_Developer_Mode, 'NO');
    	v_Calculate_NUM_ROWS CONSTANT VARCHAR2(10) := NVL(p_Calculate_NUM_ROWS, data_browser_conf.Get_Show_Tree_Num_Rows);
    	v_Max_Relations_Levels CONSTANT NUMBER := NVL(p_Max_Relations_Levels, data_browser_conf.Get_Max_Relations_Levels);
    	v_in_rows tab_tables_tree;
	BEGIN
		OPEN tables_tree_cur (v_App_Developer_Mode, v_Calculate_NUM_ROWS, v_Max_Relations_Levels);
		LOOP 
			FETCH tables_tree_cur BULK COLLECT INTO v_in_rows LIMIT g_fetch_limit;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE tables_tree_cur;
	 exception
	  when no_data_needed then
	    return;
	  when others then
		if apex_application.g_debug then
			apex_debug.info(
				p_message => 'data_browser_trees.FN_Pipe_Table_Tree (p_App_Developer_Mode=> %s) -- %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_App_Developer_Mode),
				p1 => 'failed with ' || DBMS_UTILITY.FORMAT_ERROR_STACK,
				p_max_length => 3500
			);
		end if;
		raise;
	END FN_Pipe_Table_Tree;
	
	PROCEDURE Reset_Cache
	IS 
	BEGIN
	  	null;
	END;

	
END data_browser_trees;
/
