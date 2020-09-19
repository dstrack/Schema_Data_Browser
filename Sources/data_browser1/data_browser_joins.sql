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

 
CREATE OR REPLACE PACKAGE BODY data_browser_joins
is
	-- generate from clause to access user tables with resolved foreign key connections
	CURSOR Describe_Joins_cur( v_View_Name varchar2, v_As_Of_Timestamp varchar2, v_Join_Options varchar2, v_Include_Schema varchar2)
	IS
		WITH JOIN_OPTIONS AS ( -- decode join options from v_Join_Options. Example : 'B;K:C;K:D;N'
			select /*+ CARDINALITY(10) */ SUBSTR(COLUMN_VALUE, 1, OFFSET1-1) TABLE_ALIAS, -- B, C, D, E ...
				SUBSTR(COLUMN_VALUE, OFFSET1+1) COLUMNS_INCLUDED -- one of: K, A, N
			from (
				select INSTR(COLUMN_VALUE, ';') OFFSET1, COLUMN_VALUE from TABLE( data_browser_conf.in_list(v_Join_Options, ':')) N
			)
		), BROWSER_FC_REFS AS (
			SELECT
				VIEW_NAME, 
				COLUMN_NAME, 
				COLUMN_ID, 
				R_VIEW_NAME, 
				R_TABLE_NAME, R_COLUMN_NAME, 
				COLUMN_PREFIX,
				CAST(TABLE_ALIAS AS VARCHAR2(10)) TABLE_ALIAS
			FROM (
				SELECT VIEW_NAME, FOREIGN_KEY_COLS COLUMN_NAME, COLUMN_ID, 
					R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE,
					R_VIEW_NAME, R_TABLE_NAME, R_COLUMN_NAME, COLUMN_PREFIX,
					data_browser_conf.Sequence_To_Table_Alias(DENSE_RANK() OVER (PARTITION BY TABLE_NAME ORDER BY COLUMN_ID)) TABLE_ALIAS    
				FROM TABLE (data_browser_select.FN_Pipe_browser_fc_refs(v_View_Name) ) 
			) T
		), BROWSER_QC_REFS AS (
			 -- find qualified unique key for target table of foreign key reference
			SELECT VIEW_NAME, 
				COLUMN_NAME, 
				COLUMN_ID, 
				R_TABLE_NAME,
				R_VIEW_NAME,
				J_VIEW_NAME,
				CAST(R_COLUMN_NAME AS VARCHAR2(128)) R_COLUMN_NAME,
				COLUMN_PREFIX,
				CAST(TABLE_ALIAS AS VARCHAR2(10)) TABLE_ALIAS,
				CAST(R_TABLE_ALIAS AS VARCHAR2(10)) R_TABLE_ALIAS,
				JOIN_VIEW_NAME,
				CAST(JOIN_CLAUSE AS VARCHAR2(1024)) JOIN_CLAUSE
			FROM (
				SELECT DISTINCT F.VIEW_NAME,
					F.COLUMN_NAME,
					F.COLUMN_ID,
					NVL(G.R_COLUMN_NAME, G.R_PRIMARY_KEY_COLS) R_COLUMN_NAME,
					F.COLUMN_PREFIX,
					G.R_TABLE_NAME,
					G.R_VIEW_NAME,
					G.VIEW_NAME J_VIEW_NAME,
					F.TABLE_ALIAS,
					data_browser_conf.Concat_List(F.TABLE_ALIAS, G.TABLE_ALIAS, '_') R_TABLE_ALIAS,
					G.R_VIEW_NAME JOIN_VIEW_NAME,
					case when G.FOREIGN_KEY_COLS IS NOT NULL then
						case when G.NULLABLE = 'Y' then 'LEFT OUTER ' end || 'JOIN '
						|| case when v_Include_Schema = 'YES' then 
							SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || '.'
						end 
						|| data_browser_conf.Enquote_Name_Required(G.R_VIEW_NAME)
						|| ' ' || data_browser_conf.Concat_List(F.TABLE_ALIAS, G.TABLE_ALIAS, '_')
						|| ' ON ' 
						|| data_browser_conf.Get_Join_Expression(
							p_Left_Columns=>G.R_PRIMARY_KEY_COLS, p_Left_Alias=> data_browser_conf.Concat_List(F.TABLE_ALIAS, G.TABLE_ALIAS, '_'),
							p_Right_Columns=>G.FOREIGN_KEY_COLS, p_Right_Alias=> F.TABLE_ALIAS) 
					end JOIN_CLAUSE
				FROM BROWSER_FC_REFS F
				JOIN MVDATA_BROWSER_F_REFS G ON G.VIEW_NAME = F.R_VIEW_NAME AND G.FOREIGN_KEY_COLS = F.R_COLUMN_NAME
			)
		)
		----------------------------------------------------------------------------------
		SELECT DISTINCT COLUMN_NAME, SQL_TEXT,
			COLUMN_ID, POSITION, MATCHING, COLUMNS_INCLUDED, TABLE_ALIAS, R_TABLE_NAME,
			TABLE_HEADER
			|| ' as ' || TABLE_ALIAS JOIN_HEADER
		FROM (
		SELECT COLUMN_NAME,
			case when v_As_Of_Timestamp = 'YES'
				then REPLACE (JOIN_CLAUSE, DBMS_ASSERT.ENQUOTE_NAME(JOIN_VIEW_NAME),
						DBMS_ASSERT.ENQUOTE_NAME(data_browser_conf.Get_History_View_Name(JOIN_VIEW_NAME)))
				else JOIN_CLAUSE
			end SQL_TEXT,
			COLUMN_ID, POSITION, MATCHING, COLUMNS_INCLUDED, TABLE_ALIAS, R_TABLE_NAME,
			TABLE_HEADER
		FROM (
			SELECT S.SEARCH_KEY_COLS COLUMN_NAME, S.COLUMN_PREFIX,
				CAST('FROM '
				|| case when v_Include_Schema = 'YES' then 
					SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || '.'
				end
				|| data_browser_conf.Enquote_Name_Required(S.VIEW_NAME)
				|| ' A' AS VARCHAR2(1024)) JOIN_CLAUSE,
				S.VIEW_NAME JOIN_VIEW_NAME,
				0 COLUMN_ID, 1 POSITION, 1 MATCHING, 'A' COLUMNS_INCLUDED, 'A' TABLE_ALIAS,
				NULL R_TABLE_NAME,
				data_browser_conf.Table_Name_To_Header(S.VIEW_NAME) TABLE_HEADER
			FROM MVDATA_BROWSER_VIEWS S
			WHERE S.VIEW_NAME = v_View_Name
			UNION ALL -- foreign keys with description columns
			SELECT COLUMN_NAME, COLUMN_PREFIX,
				CAST(JOIN_CLAUSE || case when MATCHING = 0 then ' -- No description columns found.' end
					AS VARCHAR2(1024)) JOIN_CLAUSE,
				JOIN_VIEW_NAME,
				COLUMN_ID, 1 POSITION, MATCHING, COLUMNS_INCLUDED, TABLE_ALIAS,
				R_TABLE_NAME,
				data_browser_conf.Column_Name_to_Header(p_Column_Name => COLUMN_NAME, p_Remove_Extension => 'YES', p_Remove_Prefix => COLUMN_PREFIX) 
				|| '->' ||
				data_browser_conf.Table_Name_To_Header(R_TABLE_NAME) TABLE_HEADER
			FROM (
				SELECT --+ INDEX(T) USE_NL_WITH_INDEX(S)
					DISTINCT S.COLUMN_NAME, -- foreign key column.
					T.COLUMN_PREFIX,
					CASE WHEN S.FK_NULLABLE = 'Y' THEN 'LEFT OUTER ' END || 'JOIN '
					|| case when v_Include_Schema = 'YES' then 
						SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || '.'
					end
					|| data_browser_conf.Enquote_Name_Required(S.R_VIEW_NAME)
					|| ' ' || S.TABLE_ALIAS
					|| ' ON ' 
					|| data_browser_conf.Get_Join_Expression(
						p_Left_Columns=>S.R_PRIMARY_KEY_COLS, p_Left_Alias=> S.TABLE_ALIAS,
						p_Right_Columns=>S.COLUMN_NAME, p_Right_Alias=> 'A') 
					JOIN_CLAUSE,
					S.R_VIEW_NAME JOIN_VIEW_NAME,
					S.FK_COLUMN_ID COLUMN_ID,
					case when S.DISPLAYED_COLUMN_NAMES IS NULL then 0 else 1 end MATCHING,
					NVL(J.COLUMNS_INCLUDED, 'K') COLUMNS_INCLUDED,
					S.TABLE_ALIAS,
					S.R_TABLE_NAME
				FROM MVDATA_BROWSER_REFERENCES S
				JOIN MVDATA_BROWSER_VIEWS T ON T.VIEW_NAME = S.VIEW_NAME
				LEFT OUTER JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
				WHERE T.VIEW_NAME = v_View_Name
				AND (J.COLUMNS_INCLUDED IN ('A','K') OR J.COLUMNS_INCLUDED IS NULL)
				-- avoid joins for file folder path 
				AND (S.COLUMN_NAME != T.FILE_FOLDER_COLUMN_NAME OR T.FILE_FOLDER_COLUMN_NAME IS NULL)
				AND (S.COLUMN_NAME != T.FOLDER_PARENT_COLUMN_NAME OR T.FOLDER_PARENT_COLUMN_NAME IS NULL)
			)
			UNION ALL -- foreign keys with unique columns and second level foreign keys
			SELECT --+ INDEX(S)
				S.COLUMN_NAME, S.COLUMN_PREFIX,
				case when data_browser_conf.Get_Include_Query_Schema = 'YES' then 
					S.JOIN_CLAUSE_EXPL
				else 
					S.JOIN_CLAUSE
				end JOIN_CLAUSE, 
				S.JOIN_VIEW_NAME,
				S.COLUMN_ID, 2 POSITION, 1 MATCHING,
				NVL(J.COLUMNS_INCLUDED, 'K') COLUMNS_INCLUDED,
				S.R_TABLE_ALIAS TABLE_ALIAS,
				S.R_TABLE_NAME,
				data_browser_conf.Table_Name_To_Header(S.J_VIEW_NAME) || '->' ||
				data_browser_conf.Table_Name_To_Header(S.R_VIEW_NAME) TABLE_HEADER
			FROM  MVDATA_BROWSER_Q_REFS S
			LEFT OUTER JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
			WHERE S.VIEW_NAME = v_View_Name
			AND S.JOIN_CLAUSE IS NOT NULL
			AND S.PARENT_KEY_COLUMN IS NULL -- column is hidden because its content can be deduced from the references FILTER_KEY_COLUMN
			AND S.IS_FILE_FOLDER_REF = 'N'
			AND (J.COLUMNS_INCLUDED IN ('A','K') OR J.COLUMNS_INCLUDED IS NULL)
			UNION ALL
			SELECT --+ INDEX(S)
				S.COLUMN_NAME, S.COLUMN_PREFIX,
				S.JOIN_CLAUSE, S.JOIN_VIEW_NAME,
				S.COLUMN_ID, 2 POSITION, 1 MATCHING,
				J.COLUMNS_INCLUDED,
				S.R_TABLE_ALIAS TABLE_ALIAS,
				S.R_TABLE_NAME,
				data_browser_conf.Table_Name_To_Header(S.J_VIEW_NAME) || '->' ||
				data_browser_conf.Table_Name_To_Header(S.R_VIEW_NAME) TABLE_HEADER
			FROM BROWSER_QC_REFS S
			JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
			WHERE S.VIEW_NAME = v_View_Name
			AND S.JOIN_CLAUSE IS NOT NULL
			AND (J.COLUMNS_INCLUDED = 'A')
		)
	) ORDER BY TABLE_ALIAS;

	FUNCTION Get_Detail_Table_Joins_Cursor (
		p_Table_Name VARCHAR2,
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Include_Schema VARCHAR2 DEFAULT 'YES'
	) RETURN data_browser_conf.tab_describe_joins PIPELINED
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
		v_Table_Name		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_joins_md5			VARCHAR2(300);
		v_is_cached			VARCHAR2(10);
	BEGIN
		v_joins_md5	 := wwv_flow_item.md5 (p_Table_Name, p_As_Of_Timestamp, p_Join_Options, p_Include_Schema);
		if p_Join_Options IS NOT NULL then
			v_is_cached	 := case when g_detail_joins_md5 != v_joins_md5 then 'load' else 'cached!' end;
			if v_is_cached != 'cached!' then
				OPEN Describe_Joins_cur (v_Table_Name, p_As_Of_Timestamp, p_Join_Options, p_Include_Schema);
				FETCH Describe_Joins_cur BULK COLLECT INTO g_detail_joins_tab;
				CLOSE Describe_Joins_cur;
				g_detail_joins_md5 := v_joins_md5;
			end if;
			FOR ind IN 1 .. g_detail_joins_tab.COUNT
			LOOP
				pipe row (g_detail_joins_tab(ind));
			END LOOP;
		else
			v_is_cached	 := case when g_record_joins_md5 != v_joins_md5 then 'load' else 'cached!' end;
			if v_is_cached != 'cached!' then
				OPEN Describe_Joins_cur (v_Table_Name, p_As_Of_Timestamp, p_Join_Options, p_Include_Schema);
				FETCH Describe_Joins_cur BULK COLLECT INTO g_record_joins_tab;
				CLOSE Describe_Joins_cur;
				g_record_joins_md5 := v_joins_md5;
			end if;
			FOR ind IN 1 .. g_record_joins_tab.COUNT
			LOOP
				pipe row (g_record_joins_tab(ind));
			END LOOP;
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_joins.Get_Detail_Table_Joins_Cursor (%s, %s, %s) : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_As_Of_Timestamp),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Join_Options),
				p3 => v_is_cached
			);
		$END
	exception
	  when others then
		if Describe_Joins_cur%ISOPEN then
			CLOSE Describe_Joins_cur;
		end if;
		raise;
	END Get_Detail_Table_Joins_Cursor;

	FUNCTION Get_Joins_Options_Cursor (
		p_Table_Name VARCHAR2,
		p_Join_Options VARCHAR2
	) RETURN data_browser_conf.tab_join_options PIPELINED
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
		CURSOR join_options_cur
		IS
		WITH JOIN_OPTIONS AS (
		   select SUBSTR(COLUMN_VALUE, 1, OFFSET1-1) TABLE_ALIAS, -- B, C, D, E ...
				SUBSTR(COLUMN_VALUE, OFFSET1+1) COLUMNS_INCLUDED -- one of: K, A, N
			from (
				select INSTR(COLUMN_VALUE, ';') OFFSET1, COLUMN_VALUE
				from TABLE( data_browser_conf.in_list(p_Join_Options, ':')) N
			)
		)
		SELECT DISTINCT S.JOIN_HEADER DESCRIPTION,
			APEX_ITEM.HIDDEN(
				p_idx => data_browser_conf.Get_Joins_Alias_Index, 
				p_value => S.TABLE_ALIAS,
				p_item_id => 'f' || LPAD(data_browser_conf.Get_Joins_Alias_Index, 2, '0') || '_' || ROWNUM
			)
			|| APEX_ITEM.SELECT_LIST(
				p_idx => data_browser_conf.Get_Joins_Option_Index,
				p_value => NVL(J.COLUMNS_INCLUDED, 'K'),
				 p_list_values => APEX_LANG.LANG('Natural Keys') ||';K,' ||
								 APEX_LANG.LANG('All') || ';A,' ||
								 APEX_LANG.LANG('None') || ';N',
				p_item_id => 'f' || LPAD(data_browser_conf.Get_Joins_Option_Index, 2, '0') || '_' || ROWNUM,
				p_attributes => q'[onChange="apex.submit('GO')"]',
				p_item_label => 'Join Option'
			) COLUMNS_INCLUDED
		FROM table(data_browser_joins.Get_Detail_Table_Joins_Cursor(
			p_Table_Name =>	 p_Table_Name,
			p_Join_Options => p_Join_Options
		)) S
		LEFT OUTER JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
		WHERE S.TABLE_ALIAS != 'A'
		ORDER BY 2;
		v_out_tab data_browser_conf.tab_join_options;
	begin
		if p_Table_Name IS NOT NULL then
			OPEN join_options_cur;
			FETCH join_options_cur BULK COLLECT INTO v_out_tab;
			CLOSE join_options_cur;
			FOR ind IN 1 .. v_out_tab.COUNT
			LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		end if;
	exception
	  when others then
		if join_options_cur%ISOPEN then
			CLOSE join_options_cur;
		end if;
		raise;
	end Get_Joins_Options_Cursor;

	FUNCTION Get_Default_Join_Options (
		p_Table_Name VARCHAR2,
		p_Option VARCHAR2 DEFAULT 'K'
	) RETURN VARCHAR2
	IS
		v_Join_Options VARCHAR2(4000);
	BEGIN
		SELECT LISTAGG(S.TABLE_ALIAS || ';' || p_Option,':') WITHIN GROUP (ORDER BY S.TABLE_ALIAS)
		INTO v_Join_Options
		FROM table(data_browser_joins.Get_Detail_Table_Joins_Cursor(p_Table_Name)) S
		WHERE S.TABLE_ALIAS != 'A';

		RETURN v_Join_Options;
	END Get_Default_Join_Options;

	FUNCTION Get_Details_Join_Options (
		p_Table_name IN VARCHAR2,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2
	IS
		v_Join_Options VARCHAR2(4000);
	BEGIN
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_joins.Get_Details_Join_Options (p_Table_name=>%s, p_View_Mode=>%s, p_Parent_Key_Column=>%s, p_Parent_Key_Visible=>%s)',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_View_Mode),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Column),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Visible)
			);
		$END
		-- Setup default joins
		-- By default only natural key columns are included.
		-- But all columns of the master table are included in the view mode EXPORT_VIEW
		-- and they are hidden in view mode FORM_VIEW
		SELECT LISTAGG(
			S.TABLE_ALIAS
			|| ';'
			|| case
				when COLUMN_NAME = p_Parent_Key_Column AND p_View_Mode = 'EXPORT_VIEW' then 'A'
				when COLUMN_NAME = p_Parent_Key_Column AND p_Parent_Key_Visible = 'NO' then 'N'
				else 'K'
			end, ':') WITHIN GROUP (ORDER BY S.TABLE_ALIAS)
		INTO v_Join_Options
		FROM table(data_browser_joins.Get_Detail_Table_Joins_Cursor(p_Table_name)) S
		WHERE S.TABLE_ALIAS != 'A';
		RETURN v_Join_Options;
	END Get_Details_Join_Options;

	FUNCTION Process_Join_Options RETURN VARCHAR2
	IS
		v_Join_Options VARCHAR2(4000);
	BEGIN
		FOR i IN 1..APEX_APPLICATION.G_F48.COUNT LOOP
			v_Join_Options := v_Join_Options || APEX_APPLICATION.G_F48(i) || ';' || APEX_APPLICATION.G_F49(i)
			|| case when i < APEX_APPLICATION.G_F48.COUNT then ':' end;
		END LOOP;
		return v_Join_Options;
	END Process_Join_Options;

	PROCEDURE reset_cache
	IS
	BEGIN
		g_detail_joins_md5 := 'X';
		g_record_joins_md5 := 'X';
	END reset_cache;
end data_browser_joins;
/
show errors

