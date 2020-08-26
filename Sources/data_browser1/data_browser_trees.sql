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

	g_tab_tables_tree 		tab_tables_tree:= tab_tables_tree();
	g_tables_tree_md5 		VARCHAR2(300) := 'X';

	FUNCTION FN_Pipe_Table_Tree (
		p_App_Developer_Mode VARCHAR2 DEFAULT V('APP_DEVELOPER_MODE')
	)
	RETURN data_browser_trees.tab_tables_tree PIPELINED;

	PROCEDURE Reset_Cache;

END data_browser_trees;
/

-- select status, level_val, title, icon, value, tooltip, link, tree_path, constraint_name from table (data_browser_trees.FN_Pipe_Table_Tree(p_App_Developer_Mode=>V('APP_DEVELOPER_MODE')));


CREATE OR REPLACE PACKAGE BODY data_browser_trees 
IS
	CURSOR tables_tree_cur (v_App_Developer_Mode VARCHAR2)
	IS 	
	with t_list as (
		select T.VIEW_NAME, T.VIEW_NAME A_VIEW_NAME, T.TABLE_NAME, T.CONSTRAINT_NAME, T.COLUMN_PREFIX, 
				NVL(T.NUM_ROWS, 0) NUM_ROWS,
				T.REFERENCES_COUNT,
				T.HTML_FIELD_COLUMN_NAME, T.FILE_FOLDER_COLUMN_NAME, T.FILE_CONTENT_COLUMN_NAME
		from MVDATA_BROWSER_DESCRIPTIONS T
		where (T.IS_ADMIN_TABLE = 'N' or v_App_Developer_Mode = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
		union -- special case self reference --
		select T.VIEW_NAME, T.VIEW_NAME || '_', T.TABLE_NAME A_VIEW_NAME, T.CONSTRAINT_NAME, T.COLUMN_PREFIX, 
				NVL(T.NUM_ROWS, 0) NUM_ROWS,
				T.REFERENCES_COUNT,
				T.HTML_FIELD_COLUMN_NAME, T.FILE_FOLDER_COLUMN_NAME, T.FILE_CONTENT_COLUMN_NAME
		from MVDATA_BROWSER_DESCRIPTIONS T, 
			MVDATA_BROWSER_REFERENCES S
		where S.VIEW_NAME = S.R_VIEW_NAME -- recursion 
		and S.FOLDER_PARENT_COLUMN_NAME IS NULL -- not useful for folders
		and T.VIEW_NAME = S.VIEW_NAME     
		and (T.IS_ADMIN_TABLE = 'N' or v_App_Developer_Mode = 'YES' and data_browser_conf.Get_Admin_Enabled = 'Y')
	), r_list as (
		select R.VIEW_NAME, R.R_VIEW_NAME, 
			R.COLUMN_NAME, R.CONSTRAINT_NAME, R.NUM_ROWS, R.FOLDER_NAME_COLUMN_NAME, R.FOLDER_PARENT_COLUMN_NAME
		from MVDATA_BROWSER_REFERENCES R
		where R.VIEW_NAME != R.R_VIEW_NAME
		union 
		select R.VIEW_NAME || '_' VIEW_NAME, R.R_VIEW_NAME, 
			R.COLUMN_NAME, R.CONSTRAINT_NAME, R.NUM_ROWS, R.FOLDER_NAME_COLUMN_NAME, R.FOLDER_PARENT_COLUMN_NAME
		from MVDATA_BROWSER_REFERENCES R -- recursion 
		where R.VIEW_NAME = R.R_VIEW_NAME
		and R.FOLDER_PARENT_COLUMN_NAME IS NULL -- not useful for folders
	)
	SELECT  /*+ RESULT_CACHE */
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
				|| case when INSTR(TABLE_LABEL, REF_LABEL) = 0 
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
				data_browser_conf.Column_Name_to_Header(p_Column_Name => R.COLUMN_NAME, p_Remove_Extension => 'YES', p_Remove_Prefix => T.COLUMN_PREFIX) REF_LABEL,
				NVL(R.NUM_ROWS, T.NUM_ROWS) NUM_ROWS,
				T.REFERENCES_COUNT,
				D.COMMENTS
			from t_list T
			, MVDATA_BROWSER_DESCRIPTIONS D 
			, r_list R 
			WHERE T.VIEW_NAME = D.VIEW_NAME
			AND T.A_VIEW_NAME = R.VIEW_NAME (+)
		) T
		start with R_VIEW_NAME is null
		connect by NOCYCLE prior A_VIEW_NAME = R_VIEW_NAME AND LEVEL <= 5
		order siblings by sign(REFERENCES_COUNT) desc, VIEW_NAME
	);

	FUNCTION FN_Pipe_Table_Tree (
		p_App_Developer_Mode VARCHAR2 DEFAULT V('APP_DEVELOPER_MODE')
	)
	RETURN data_browser_trees.tab_tables_tree PIPELINED
	IS
		PRAGMA UDF;
    	v_App_Developer_Mode CONSTANT VARCHAR2(10) := NVL(p_App_Developer_Mode, 'NO');
    	v_tables_tree_md5 	 VARCHAR2(300);
        v_is_cached			 VARCHAR2(10);
	BEGIN
    	v_tables_tree_md5 := wwv_flow_item.md5 (v_App_Developer_Mode);
		v_is_cached	:= case when g_tables_tree_md5 = 'X' then 'init'
					when g_tables_tree_md5 != v_tables_tree_md5 then 'load' else 'cached!' end;
		if g_tables_tree_md5 != 'cached!' then
			OPEN data_browser_trees.tables_tree_cur (v_App_Developer_Mode);
			FETCH data_browser_trees.tables_tree_cur BULK COLLECT INTO g_tab_tables_tree;
			CLOSE data_browser_trees.tables_tree_cur;
			g_tables_tree_md5 := v_tables_tree_md5;
		end if;
		FOR ind IN 1 .. g_tab_tables_tree.COUNT LOOP
			pipe row (g_tab_tables_tree(ind));
		END LOOP;
	 exception
	  when no_data_needed then
	    return;
	  when others then
	  	if data_browser_trees.tables_tree_cur%ISOPEN then
			CLOSE data_browser_trees.tables_tree_cur;
		end if;
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
		g_tables_tree_md5 := 'X';
		g_tab_tables_tree := tab_tables_tree();
	END;
	
END data_browser_trees;
/
