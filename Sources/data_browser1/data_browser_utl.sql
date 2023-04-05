/*
Copyright 2019 Dirk Strack, Strack Software Development

All Rights Reserved
Unauthorized copying of this file, via any medium is strictly prohibited
Proprietary and confidential
Written by Dirk Strack <dirk_strack@yahoo.de>, Feb 2019
*/
---------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY data_browser_utl
IS
	g_Date_NLS_Const CONSTANT VARCHAR2(50) := 'NLS_DATE_LANGUAGE=French';
	g_Date_Fmt_Const CONSTANT VARCHAR2(50) := 'DD.Month.YYYY HH24:MI:SS';

	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2
	is begin return data_browser_conf.NL(p_Indent);
	end;

	FUNCTION CM(p_Param_Name VARCHAR2) RETURN VARCHAR2	-- remove comments for compact code generation
	is
	begin
		return case when data_browser_conf.NL(1) = chr(10)
			then NULL
			else ' ' || p_Param_Name || ' '
		end;
	end;

	FUNCTION INDENT(p_Query CLOB) RETURN CLOB
	IS
	BEGIN
		RETURN REPLACE( chr(10) || p_Query, chr(10), data_browser_conf.NL(4)) || chr(10);
	END;

	FUNCTION Is_Automatic_Search_Enabled (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2 
	IS
	PRAGMA UDF;
		v_Row_Count NUMBER;
	BEGIN 
		SELECT NUM_ROWS INTO v_Row_Count
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME =  p_Table_Name;
		RETURN case when v_Row_Count < data_browser_conf.Get_Automatic_Search_Limit then 'YES' else 'NO' end; 
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return 'NO';
	END Is_Automatic_Search_Enabled;
	
	FUNCTION Has_Calendar_Date (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2
	IS
		v_Row_Count NUMBER;
	BEGIN 
		SELECT COUNT(*) INTO v_Row_Count
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME =  p_Table_Name
		AND CALEND_START_DATE_COLUMN_NAME IS NOT NULL;
		RETURN case when v_Row_Count > 0 then 'YES' else 'NO' end; 
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return 'NO';
	END Has_Calendar_Date;

	FUNCTION Has_Tree_View (
		p_Table_Name VARCHAR2 
	)
	RETURN VARCHAR2
	IS
		v_Row_Count NUMBER;
	BEGIN 
		SELECT COUNT(*) INTO v_Row_Count
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME =  p_Table_Name
		AND FOLDER_PARENT_COLUMN_NAME IS NOT NULL
		AND FOLDER_NAME_COLUMN_NAME IS NOT NULL;
		RETURN case when v_Row_Count > 0 then 'YES' else 'NO' end; 
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        return 'NO';
	END Has_Tree_View;

	FUNCTION FN_Terminate_List(p_String VARCHAR2) return VARCHAR2 
	is begin return ':'||p_String||':'; 
	end;

	FUNCTION Get_Order_by_Clause (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',		-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 		-- NEW_ROWS, TABLE, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Data_Format VARCHAR2 DEFAULT data_browser_select.FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'YES',	-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : NAME
    	p_Order_Direction VARCHAR2 DEFAULT 'ASC  NULLS LAST',-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
    	p_Calc_Totals  VARCHAR2 DEFAULT 'NO'		-- YES, NO
	) RETURN VARCHAR2
	is
        v_Select_Columns	VARCHAR2(32767);
		v_Unique_Key_Expr	VARCHAR2(32767);
        v_Order_by 			VARCHAR2(32767);
        v_Order_Expr		VARCHAR2(32767);
        v_Control_Break 	VARCHAR2(32767);
        v_is_Selected_Column BOOLEAN;
	begin
		v_Select_Columns := FN_Terminate_List(p_Select_Columns);
		-- optimize v_Control_Break: if COLUMN_EXPR is used for sorting then sorting is done on Control_Break Expresson
		v_Control_Break := null;
		for c_cur in (
			SELECT A.COLUMN_NAME, A.DATA_TYPE, A.TABLE_ALIAS, A.REF_COLUMN_NAME, A.R_COLUMN_NAME, 
				A.COLUMN_EXPR_TYPE, A.COLUMN_EXPR, A.DISPLAY_IN_REPORT, A.IS_SUMMAND,
				NVL(D.ORDER_DIR, 'ASC NULLS LAST') ORDER_DIR, A.LOV_QUERY, A.IS_REFERENCE
			FROM (
				SELECT COLUMN_NAME, COLUMN_ID, DATA_TYPE, POSITION, TABLE_ALIAS, REF_COLUMN_NAME, R_COLUMN_NAME, 
					COLUMN_EXPR_TYPE, COLUMN_EXPR, DISPLAY_IN_REPORT, IS_SUMMAND, LOV_QUERY, IS_REFERENCE
				FROM TABLE(
					data_browser_select.Get_View_Column_Cursor(
						p_Table_name => p_Table_name,
						p_Unique_Key_Column => p_Unique_Key_Column,
						p_Data_Columns_Only => 'YES',
						p_Columns_Limit => p_Columns_Limit, 
						-- sorting on non-select column of a table may be possible! maybe use: case when p_Data_Source = 'TABLE' then 1000 else p_Columns_Limit end, 
						p_Join_Options => p_Join_Options,
						p_View_Mode => p_View_Mode,
						p_Edit_Mode => 'NO',
						p_Report_Mode => 'ALL',
						p_Parent_Name => p_Parent_Table,
						p_Parent_Key_Column => p_Parent_Key_Column,
						p_Parent_Key_Visible => 'YES'
					)
				)
				WHERE data_browser_select.FN_Is_Sortable_Column(COLUMN_EXPR_TYPE) = 'YES'
			) A
			JOIN (
				SELECT TRIM(P.COLUMN_VALUE) COLUMN_NAME, ROWNUM POSITION
				FROM TABLE( apex_string.split(p_Order_by, ',') ) P
			) B ON A.COLUMN_NAME = B.COLUMN_NAME
			LEFT OUTER JOIN (
				SELECT TRIM(P.COLUMN_VALUE) ORDER_DIR, ROWNUM POSITION
				FROM TABLE( apex_string.split(p_Order_Direction, ',') ) P
			) D ON B.POSITION = D.POSITION
			ORDER BY B.POSITION
		) loop
			-- Handle special cases:
			-- 1. in read_only mode
			-- 1.1 for FORM_VIEW,NAVIGATION_VIEW,NESTED_VIEW foreign key columns use a COLUMN_EXPR to describe the key values.
			-- 		Sorting has to use the COLUMN_EXPR values for proper ordering
			-- 1.2 Date and Number columns use a COLUMN_EXPR to format the data values.
			--		Sorting has to use the native column references for proper ordering
			-- 2. edit mode
			-- 		in edit mode all columns will become apex_item html tags
			-- 2.1 for FORM_VIEW,NAVIGATION_VIEW,NESTED_VIEW foreign key columns use a COLUMN_EXPR to describe the key values.
			-- 		Sorting has to use the COLUMN_EXPR values for proper ordering
			-- 2.2 Sorting has to use the native column references for all other columns
			--
			if p_Select_Columns IS NULL then 
				if p_Parent_Key_Visible = 'NO' and c_cur.R_COLUMN_NAME = p_Parent_Key_Column and c_cur.TABLE_ALIAS = 'A' then 
					v_is_Selected_Column := FALSE;
				else 
					v_is_Selected_Column := c_cur.DISPLAY_IN_REPORT = 'Y';
				end if;
			else 
				v_is_Selected_Column := data_browser_select.FN_List_Offest(v_Select_Columns, c_cur.COLUMN_NAME) > 0;
			end if;
			v_Order_Expr := NULL;
			if p_Data_Source IN ('TABLE' , 'QUERY', 'NEW_ROWS') 
			and p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW', 'HISTORY') and c_cur.TABLE_ALIAS Is NOT NULL then 
			  	v_Order_Expr := c_cur.TABLE_ALIAS || '.' || c_cur.REF_COLUMN_NAME;
			elsif c_cur.COLUMN_EXPR_TYPE IN ('SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV') then
				if (p_Edit_Mode = 'YES' or not v_is_Selected_Column)
				and p_Data_Source IN ('TABLE' , 'QUERY', 'NEW_ROWS') then 
					v_Order_Expr := c_cur.COLUMN_EXPR; 		-- order by result of single row subquery accessing the display columns of the referenced table
				else 
					v_Order_Expr := c_cur.COLUMN_NAME; 	-- order by select list expression
				end if;
				if p_Data_Format IN ('FORM', 'HTML') -- the field name is only available in from queries
				and c_cur.COLUMN_NAME = p_Control_Break and c_cur.ORDER_DIR = 'ASC NULLS LAST' then 
					v_Control_Break := c_cur.COLUMN_NAME;
					v_Order_Expr := NULL;
				end if;
			elsif c_cur.IS_REFERENCE IN ('Y','C') and c_cur.IS_SUMMAND = 'Y' and c_cur.LOV_QUERY IS NOT NULL then
				v_Order_Expr := c_cur.LOV_QUERY; 		-- order by result of single row subquery accessing the count of rows in the referenced table
			elsif p_Data_Source IN ('TABLE' , 'QUERY')
			and c_cur.TABLE_ALIAS IS NOT NULL 
			and (c_cur.DATA_TYPE IN ('NUMBER', 'FLOAT', 'DATE', 'VARCHAR2', 'CHAR') or c_cur.DATA_TYPE LIKE 'TIMESTAMP%' 
			  or p_Edit_Mode = 'YES' or not v_is_Selected_Column) then
				if c_cur.IS_SUMMAND = 'Y' and p_Calc_Totals = 'YES' then 
					v_Order_Expr := 'SUM(' || c_cur.TABLE_ALIAS || '.' || c_cur.REF_COLUMN_NAME || ')';
				else
					v_Order_Expr := c_cur.TABLE_ALIAS || '.' || c_cur.REF_COLUMN_NAME;	-- order by unformatted table column 
				end if;
			else
				v_Order_Expr := c_cur.COLUMN_NAME; 	-- order by select list expression
			end if;
			
			if v_Order_Expr IS NOT NULL then 
				v_Order_by := v_Order_by
				|| case when v_Order_by is not null then ', ' end
				|| v_Order_Expr
				|| ' ' || c_cur.ORDER_DIR;
			end if;
		end loop;
		if v_Control_Break is not null then 
			v_Order_by := data_browser_conf.concat_list('CONTROL_BREAK$ ASC NULLS LAST', v_Order_by);
		end if;
		if p_Calc_Totals = 'YES' and p_Data_Columns_Only = 'NO' and p_Control_Break != '.' then -- ensure that the subtotals and totals are listed last
			v_Unique_Key_Expr := data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> p_Unique_Key_Column, p_Table_Alias=> 'A', p_View_Mode=> p_View_Mode);
			v_Order_by := data_browser_conf.concat_list(v_Order_by, p_Unique_Key_Column || ' ASC NULLS LAST');
		end if;
		v_Order_by := TRIM(v_Order_by);
        RETURN v_Order_by;
    end Get_Order_by_Clause;

	FUNCTION Get_Sub_Totals_Grouping ( 
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
    	p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : NAME
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Data_Format VARCHAR2 DEFAULT data_browser_select.FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Nested_Links VARCHAR2 DEFAULT 'NO'			-- YES, NO use nested table view instead of p_Link_Page_ID, p_Link_Parameter
	) RETURN VARCHAR2
	is
        v_is_Selected_Column BOOLEAN;
        v_Is_Summand_Cnt 	PLS_INTEGER := 0;
        v_Column_Cnt		PLS_INTEGER := 0;
        v_Links_Count		PLS_INTEGER := 0;
        v_Link_Lists_Count	PLS_INTEGER := 0;
        v_Nested_Links		VARCHAR2(10);
        v_Parent_Key_Found	VARCHAR2(10);
        v_Select_Columns	VARCHAR2(32767);
        v_Grouping_Columns	VARCHAR2(32767);
        v_Control_Break		VARCHAR2(32767);
	begin
		$IF data_browser_conf.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_utl.Get_Sub_Totals_Grouping ('
				|| 'p_Table_name=> %s, p_Unique_Key_Column =>%s, p_Select_Columns=> %s, p_Columns_Limit=> %s, p_Control_Break=> %s, p_Order_by=> %s, ' || chr(10)
				|| 'p_View_Mode=> %s, p_Data_Format=> %s, p_Join_Options=> %s, p_Parent_Table=> %s, p_Parent_Key_Column=> %s, p_Nested_Links=> %s)',
				p0 => p_Table_name,
				p1 => p_Unique_Key_Column,
				p2 => p_Select_Columns,
				p3 => p_Columns_Limit,
				p4 => p_Control_Break,
				p5 => p_Order_by,
				p6 => p_View_Mode,
				p7 => p_Data_Format,
				p8 => p_Join_Options,
				p9 => p_Parent_Table,
				p10 => p_Parent_Key_Column,
				p11 => p_Nested_Links,
				p_max_length => 3500
			);
		$END
		v_Nested_Links := NVL(p_Nested_Links, 'NO');
		v_Select_Columns := FN_Terminate_List( p_Select_Columns );
		v_Parent_Key_Found := case when p_Parent_Key_Column IS NOT NULL then 'NO' else 'YES' end;
		for c_cur in (
			SELECT COLUMN_NAME, COLUMN_ID, DATA_TYPE, POSITION, TABLE_ALIAS, 
				REF_COLUMN_NAME, R_COLUMN_NAME, IS_SUMMAND, IS_REFERENCE,
				COLUMN_EXPR_TYPE, DISPLAY_IN_REPORT,
				case when COLUMN_EXPR_TYPE = 'LINK_ID' or IS_BLOB = 'Y' then 
					COLUMN_EXPR 
				else 
					'A.' || REF_COLUMN_NAME
				end COLUMN_EXPR,
				case when TABLE_ALIAS = 'A' and COLUMN_NAME IN (
						SELECT TRIM(COLUMN_VALUE) FROM table(apex_string.split(p_Order_by, ','))
					)
					then 'Y' else 'N' 
				end IS_ORDER_COL,
				case when TABLE_ALIAS = 'A' and R_COLUMN_NAME IN (
						SELECT TRIM(COLUMN_VALUE) FROM table(apex_string.split(p_Parent_Key_Column, ','))
					)
					then 'Y' else 'N' 
				end IS_PARENT_COL
			FROM TABLE(
				data_browser_select.Get_View_Column_Cursor(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Columns_Limit => p_Columns_Limit,
					p_Data_Columns_Only => 'NO', -- include hidden unique keys
					p_Select_Columns => p_Select_Columns,
					p_Join_Options => p_Join_Options,
					p_View_Mode => p_View_Mode,
					p_Edit_Mode => 'NO', 
					p_Report_Mode => 'ALL',
					p_Data_Format => p_Data_Format,
					p_Parent_Name => p_Parent_Table,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => 'YES'
				)
			) 
		) loop
			if c_cur.COLUMN_EXPR_TYPE = 'LINK_ID' then 
				v_is_Selected_Column := TRUE;
			elsif c_cur.IS_PARENT_COL = 'Y' then		-- fk columns is required in the grouping set for references is FN_Detail_Link
				v_Parent_Key_Found := 'YES';
				v_is_Selected_Column := TRUE;
			elsif c_cur.IS_ORDER_COL = 'Y' then	-- columns is required in the grouping set for order by clause
				v_is_Selected_Column := TRUE;
			elsif p_Select_Columns IS NULL then 
				v_is_Selected_Column := c_cur.DISPLAY_IN_REPORT = 'Y';
				-- in case the report is ordered by this column 
			else 
				v_is_Selected_Column := data_browser_select.FN_List_Offest(v_Select_Columns, c_cur.COLUMN_NAME) > 0;
			end if;
			
			if v_is_Selected_Column and c_cur.COLUMN_EXPR_TYPE = 'LINK'  then
				v_Links_Count := v_Links_Count + 1;
				if INSTR(v_Grouping_Columns||',', c_cur.COLUMN_EXPR||',') = 0 then 
					v_Column_Cnt := v_Column_Cnt + 1;
					v_Grouping_Columns := data_browser_conf.concat_list(v_Grouping_Columns, c_cur.COLUMN_EXPR);
				end if;
			end if;
			if v_is_Selected_Column and c_cur.COLUMN_EXPR_TYPE = 'LINK_LIST'  then
				v_Link_Lists_Count := v_Link_Lists_Count + 1;
			else
				if v_is_Selected_Column and c_cur.IS_SUMMAND = 'Y' then
					v_Is_Summand_Cnt := v_Is_Summand_Cnt + 1;
				elsif data_browser_select.FN_List_Offest(p_Control_Break, c_cur.COLUMN_NAME) > 0 then
					v_Control_Break := data_browser_conf.concat_list(v_Control_Break, 'A.' || c_cur.REF_COLUMN_NAME);
				elsif v_is_Selected_Column 
				and INSTR(v_Grouping_Columns||',', c_cur.COLUMN_EXPR||',') = 0 then 
					v_Column_Cnt := v_Column_Cnt + 1;
					v_Grouping_Columns := data_browser_conf.concat_list(v_Grouping_Columns, c_cur.COLUMN_EXPR);
				end if;
			end if;
		end loop;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_utl.Get_Sub_Totals_Grouping (p_Select_Columns=> %s, p_Parent_Key_Column=> %s, v_Grouping_Columns=> %s, ' || chr(10)
				|| 'v_Control_Break=> %s, v_Links_Count=> %s, v_Link_Lists_Count=> %s, v_Is_Summand_Cnt=> %s, p_Nested_Links=> %s)',
				p0 => p_Select_Columns,
				p1 => p_Parent_Key_Column,
				p2 => v_Grouping_Columns,
				p3 => v_Control_Break,
				p4 => v_Links_Count,
				p5 => v_Link_Lists_Count,
				p6 => v_Is_Summand_Cnt,
				p7 => p_Nested_Links,
				p_max_length => 3500
			);
		
		$END
    	if v_Is_Summand_Cnt > 0 then 
    		return NL(0)
    			|| 'GROUP BY GROUPING SETS('
				|| '(' 
				|| case when v_Control_Break IS NOT NULL then v_Control_Break || ', ' end
				|| v_Grouping_Columns 
				|| case when v_Parent_Key_Found = 'NO' then ', ' || p_Parent_Key_Column end
				|| ', ROWNUM'	-- used to render unique ids in html tags - f.e. texttool
				|| case when v_Nested_Links = 'NO' and v_Link_Lists_Count > 0 and p_Data_Format = 'FORM' then ', PAR.TARGET1' end
				|| case when v_Nested_Links = 'NO' and v_Links_Count > 0 and p_Data_Format = 'FORM' then ', PAR.TARGET2' end
				|| ')'
				|| case when v_Control_Break IS NOT NULL then ', (' || v_Control_Break || ')' end
				|| ', ())';
    	else 
    		return null;
    	end if;
    	
    end Get_Sub_Totals_Grouping;


    PROCEDURE Get_Foreign_Key_Details (
    	p_Table_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Load_Foreign_Key VARCHAR2 DEFAULT 'YES',
		p_Foreign_Key_Table VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Column IN OUT VARCHAR2,
		p_Foreign_Key_ID IN OUT VARCHAR2,
    	p_Link_ID IN VARCHAR2
    )
    IS
        stat_cur            SYS_REFCURSOR;
        v_Table_Name 		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Query2			VARCHAR2(32767);
	    v_Foreign_Key_Column VARCHAR2(1024);
        v_Count				INTEGER;
        v_Expr 				VARCHAR2(4000);
        v_Select_List		VARCHAR2(4000);
    BEGIN
        -- Get Key column of p_Foreign_Key_Table
		if p_Foreign_Key_Table IS NOT NULL then
			begin
				SELECT COLUMN_NAME
				INTO v_Foreign_Key_Column
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_Name
				AND R_VIEW_NAME = p_Foreign_Key_Table
				AND COLUMN_NAME = NVL(p_Foreign_Key_Column, COLUMN_NAME)
				AND ROWNUM = 1;

				p_Foreign_Key_Column := v_Foreign_Key_Column;
				-- get the p_Foreign_Key_ID of the current row
				-- used to filter the result set
				if p_Load_Foreign_Key = 'YES' then 
					-- Calculate expression for Link_ID
					v_Expr := data_browser_select.Get_Unique_Key_Expression(
						p_Table_Name => v_Table_Name,
						p_Unique_Key_Column => p_Unique_Key_Column,
						p_View_Mode => p_View_Mode
					);
					v_Query2 := 'SELECT ' || v_Foreign_Key_Column
							|| ' FROM ' || v_Table_Name || ' A '
							|| ' WHERE ' || v_Expr || ' = :a';
					OPEN stat_cur FOR v_Query2 USING p_Link_ID;
					FETCH stat_cur INTO p_Foreign_Key_ID;
					CLOSE stat_cur;
				end if;
				SELECT COUNT(*)
				INTO v_Count
				FROM  TABLE( apex_string.split(v_Select_List, ',') ) P
				WHERE TRIM(P.COLUMN_VALUE) = 'A.' || v_Foreign_Key_Column;
				if v_Count = 0 then
					v_Select_List := v_Select_List || ',' || v_Foreign_Key_Column;
				end if;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_unique_key_column,p_view_mode,p_load_foreign_key,p_foreign_key_table,p_foreign_key_column,p_foreign_key_id,p_link_id;
        $END
	end Get_Foreign_Key_Details;
	
    PROCEDURE Get_Form_Prev_Next (
    	p_Table_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Table VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_ID IN VARCHAR2 DEFAULT NULL,
    	p_Link_ID IN VARCHAR2,
    	p_Order_by IN OUT NOCOPY VARCHAR2,
    	p_Next_Link_ID OUT NOCOPY VARCHAR2,
    	p_Prev_Link_ID OUT NOCOPY VARCHAR2,
    	p_First_Link_ID OUT NOCOPY VARCHAR2,
    	p_Last_Link_ID OUT NOCOPY VARCHAR2,
    	p_X_OF_Y OUT NOCOPY VARCHAR2
    )
    IS
        stat_cur            SYS_REFCURSOR;
        v_Table_Name 		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_From 				VARCHAR2(4000);
		v_Query				VARCHAR2(32767);
	    v_Use_Foreign_Key 	BOOLEAN := FALSE;
		v_Unique_Key_Column VARCHAR2(1024);
        v_Expr 				VARCHAR2(4000);
        v_Select_List		VARCHAR2(4000);
        v_Order_by 			VARCHAR2(1024);
        v_Valid_Order_by 	VARCHAR2(1024);
        v_New_Order_by 		VARCHAR2(1024);
        v_New_Alias_Column	VARCHAR2(1024);
        v_View_Mode 		VARCHAR2(30) := case when p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then p_View_Mode else 'FORM_VIEW' end;
    BEGIN
		p_Next_Link_ID := NULL;
		p_Prev_Link_ID := NULL;
		p_First_Link_ID := NULL;
		p_Last_Link_ID := NULL;
		p_X_OF_Y := NULL;
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(p_overload => 1)
            USING p_table_name,p_unique_key_column,p_view_mode,p_edit_mode,p_join_options,p_foreign_key_table,p_foreign_key_column,p_foreign_key_id,p_link_id,p_order_by,p_next_link_id,p_prev_link_id,p_first_link_id,p_last_link_id,p_x_of_y;
        end if;
        if p_Table_name IS NULL 
		then
			p_Order_by := NULL;
			return;
		end if;
        if p_Unique_Key_Column IS NULL then
        	begin 
				SELECT T.SEARCH_KEY_COLS
				INTO v_Unique_Key_Column
				FROM MVDATA_BROWSER_VIEWS T
				WHERE T.VIEW_NAME = v_Table_Name;
			exception when NO_DATA_FOUND then 
				return;
			end;
		else 
			v_Unique_Key_Column := p_Unique_Key_Column;
		end if;
		-- Calculate expression for Link_ID
		-- in order to return foreign key references for composite keys that can be searched in to current table 
		-- a hash value is produced is that case.
		v_Expr := data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column => v_Unique_Key_Column, p_Table_Alias => 'A', p_View_Mode => p_View_Mode);

		if p_Unique_Key_Column = p_Order_by then
			v_Order_by := v_Unique_Key_Column;
			v_Select_List := 'A.' || v_Unique_Key_Column;
		else
			v_Order_by := data_browser_utl.Get_Order_by_Clause ( 
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_View_Mode => v_View_Mode,
				p_Join_Options => p_Join_Options,
				p_Edit_Mode => 'NO',
				p_Data_Source => 'TABLE',
				p_Parent_Table => p_Foreign_Key_Table,
				p_Parent_Key_Column => p_Foreign_Key_Column,
				p_Order_by => p_Order_by
			);
			SELECT DISTINCT
				LISTAGG(case when B.COLUMN_NAME IS NOT NULL then A.R_COLUMN_NAME end, ', ') WITHIN GROUP (ORDER BY B.POSITION) 
			into v_Select_List
			FROM (
				SELECT v_Table_name VIEW_NAME,
						R_COLUMN_NAME,
						REF_COLUMN_NAME, COLUMN_NAME, COLUMN_ID, POSITION
				FROM TABLE(
					data_browser_select.Get_View_Column_Cursor(
						p_Table_name => v_Table_name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_Data_Columns_Only => 'YES',
						p_Select_Columns => NULL,
						p_Join_Options => p_Join_Options,
						p_View_Mode => v_View_Mode,
						p_Edit_Mode => 'NO',
						p_Report_Mode => 'NO',
						p_Parent_Name => p_Foreign_Key_Table,
						p_Parent_Key_Column => p_Foreign_Key_Column,
						p_Parent_Key_Visible => 'YES'
					)
				)
				WHERE data_browser_select.FN_Is_Sortable_Column(COLUMN_EXPR_TYPE) = 'YES'
			) A
			LEFT OUTER JOIN (
				SELECT TRIM(P.COLUMN_VALUE) COLUMN_NAME, ROWNUM POSITION
				FROM TABLE( apex_string.split(p_Order_by, ',') ) P
			) B ON A.COLUMN_NAME = B.COLUMN_NAME
			GROUP BY A.VIEW_NAME;
			if v_Order_by IS NOT NULL then 
				v_Order_by := v_Order_by || ', A.ROWID';
			else
				--- no order by possible
				p_Order_by := NULL;
				return;
			end if;
		end if;
		-- former call point for Get_Foreign_Key_Details

		-- Get required columns list. Column_Expr resolves table-alias or ROWID and datatype conversions
		SELECT DISTINCT LISTAGG( COLUMN_EXPR || ' ' || COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY COLUMN_ID, POSITION) Q_STAT,
				LISTAGG( COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY COLUMN_ID, POSITION)
		INTO v_Query, v_New_Order_by
		FROM TABLE(
			data_browser_select.Get_View_Column_Cursor(
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Data_Columns_Only => 'YES',
				p_Select_Columns => NULL,
				p_Join_Options => p_Join_Options,
				p_View_Mode => v_View_Mode,
				p_Edit_Mode => 'NO',
				p_Report_Mode => 'NO',
				p_Parent_Name => p_Foreign_Key_Table,
				p_Parent_Key_Column => p_Foreign_Key_Column,
				p_Parent_Key_Visible => 'YES'
			)
		)
		WHERE COLUMN_NAME IN (
			SELECT TRIM(P.COLUMN_VALUE) COLUMN_NAME
			FROM TABLE( apex_string.split(v_Select_List, ',') ) P
		);
		if v_Query IS NULL then
			return;
		end if;
		v_Query := 'SELECT ' || v_Expr || ' LINK_ID$, ' || v_Query;
		if  p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			-- build from clause
			for c_cur in (
				SELECT SQL_TEXT
				FROM TABLE (
					data_browser_joins.Get_Detail_Table_Joins_Cursor(
						p_Table_name => p_Table_name,
						p_As_Of_Timestamp => 'NO',
						p_Join_Options => NULL
					)
				)
			)
			loop
				v_From := v_From || NL(4) || c_cur.SQL_TEXT;
			end loop;
		else
			-- build from clause
			v_From := chr(10) || ' FROM ' || v_Table_Name || ' A ';
		end if;

		if p_Foreign_Key_Column IS NOT NULL then
			if p_Foreign_Key_ID IS NOT NULL then
				v_From := v_From || chr(10) || 'WHERE A.' || p_Foreign_Key_Column || ' = :a';
				v_Use_Foreign_Key := TRUE;
			else
				v_From := v_From || chr(10) || 'WHERE A.' || p_Foreign_Key_Column || ' IS NULL ';
			end if;
		end if;
		-- final query
		if p_Link_ID IS NULL then
			v_Query :=
			'SELECT null NEXT_ID, null PREV_ID, FIRST_ID, LAST_ID, X_OF_Y ' || chr(10)
			|| 'FROM (' || chr(10)
			|| '    SELECT DISTINCT ' || chr(10)
			|| '        FIRST_VALUE(LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ') FIRST_ID, ' || chr(10)
			|| '        LAST_VALUE(LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ' RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) LAST_ID,' || chr(10)
			|| '        COUNT (LINK_ID$) OVER () X_OF_Y ' || chr(10)
			|| '    FROM (' || v_Query || v_From || chr(10)
			|| '    ) A' || chr(10)
			|| ')';
			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'data_browser_utl.Get_Form_Prev_Next (v_Order_by : %s, v_Select_List : %s) - final : %s',
					p0 => v_Order_by,
					p1 => v_Select_List,
					p2 => v_Query,
					p_max_length => 3500
				);
			$END
			if v_Use_Foreign_Key then
				OPEN stat_cur FOR v_Query USING p_Foreign_Key_ID;
			else
				OPEN stat_cur FOR v_Query;
			end if;
		else
			v_Query :=
			'SELECT NEXT_ID, PREV_ID, FIRST_ID, LAST_ID, X_OF_Y ' || chr(10)
			|| 'FROM (' || chr(10)
			|| '    SELECT LINK_ID$ LINK_ID, ' || chr(10)
			|| '        LEAD(LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ') NEXT_ID, ' || chr(10)
			|| '        LAG(LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ') PREV_ID,' || chr(10)
			|| '        FIRST_VALUE(LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ') FIRST_ID, ' || chr(10)
			|| '        LAST_VALUE(LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ' RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) LAST_ID,' || chr(10)
			|| '        COUNT (LINK_ID$) OVER (ORDER BY ' || v_New_Order_by || ') '
			|| ' || '' '' || ' || DBMS_ASSERT.ENQUOTE_LITERAL(APEX_LANG.LANG('of')) || ' || '' '' || '
			|| ' COUNT (LINK_ID$) OVER () X_OF_Y ' || chr(10)
			|| '    FROM (' || v_Query || v_From || chr(10)
			|| '    ) A' || chr(10)
			|| ') WHERE LINK_ID = :b';
			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'data_browser_utl.Get_Form_Prev_Next (v_Order_by : %s, v_Select_List : %s) - final : %s',
					p0 => v_Order_by,
					p1 => v_Select_List,
					p2 => v_Query,
					p_max_length => 3500
				);
			$END
			if v_Use_Foreign_Key then
				OPEN stat_cur FOR v_Query USING p_Foreign_Key_ID, p_Link_ID;
			else
				OPEN stat_cur FOR v_Query USING p_Link_ID;
			end if;
		end if;
		FETCH stat_cur INTO p_Next_Link_ID, p_Prev_Link_ID, p_First_Link_ID, p_Last_Link_ID, p_X_OF_Y;
		CLOSE stat_cur;

		if p_Edit_Mode = 'YES' then
			data_browser_blobs.Init_Clob_Updates;
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_utl.Get_Form_Prev_Next (%s) - done : %s',
				p0 => v_Order_by,
				p1 => v_Query,
				p_max_length => 3500
			);
		$END
	exception when NO_DATA_FOUND then 
	    if stat_cur%ISOPEN then
			CLOSE stat_cur;
		end if;
	  when others then
	    if stat_cur%ISOPEN then
			CLOSE stat_cur;
		end if;
		raise;
	END Get_Form_Prev_Next;

    PROCEDURE Get_Form_Prev_Next (
    	p_Table_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Table VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Foreign_Key_ID IN VARCHAR2 DEFAULT NULL,
    	p_Link_ID IN VARCHAR2,
    	p_Order_by IN OUT NOCOPY VARCHAR2,
    	p_Next_Link_ID OUT NOCOPY VARCHAR2,
    	p_Prev_Link_ID OUT NOCOPY VARCHAR2,
	   	p_X_OF_Y OUT NOCOPY VARCHAR2
    )
    IS
    	v_First_Link_ID VARCHAR2(512);
    	v_Last_Link_ID VARCHAR2(512);
	BEGIN 
		Get_Form_Prev_Next (
			p_Table_Name 			=> p_Table_Name,
   			p_Unique_Key_Column 	=> p_Unique_Key_Column,
			p_View_Mode 		 	=> p_View_Mode,
			p_Edit_Mode  			=> p_Edit_Mode,
			p_Join_Options			=> p_Join_Options,
			p_Foreign_Key_Table 	=> p_Foreign_Key_Table,
			p_Foreign_Key_Column 	=> p_Foreign_Key_Column,
			p_Foreign_Key_ID 		=> p_Foreign_Key_ID,
			p_Link_ID 				=> p_Link_ID,
			p_Next_Link_ID 			=> p_Next_Link_ID,
			p_Prev_Link_ID 			=> p_Prev_Link_ID,
			p_First_Link_ID 		=> v_First_Link_ID,
			p_Last_Link_ID 			=> v_Last_Link_ID,
			p_Order_by 				=> p_Order_by,
    		p_X_OF_Y 				=> p_X_OF_Y
		);
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(p_overload => 2)
            USING p_table_name,p_unique_key_column,p_view_mode,p_edit_mode,p_join_options,p_foreign_key_table,p_foreign_key_column,p_foreign_key_id,p_link_id,p_order_by,p_next_link_id,p_prev_link_id,p_x_of_y;
        $END
	END Get_Form_Prev_Next;


	FUNCTION Column_Value_List(
		p_Query IN CLOB,
		p_Search_Value IN VARCHAR2 DEFAULT NULL,
		p_Offset IN NUMBER DEFAULT 0,
		p_Exact IN VARCHAR2 DEFAULT 'NO'	-- Load values for exactly one row
	)
	RETURN data_browser_conf.tab_col_value PIPELINED
	is
		v_col_values apex_t_varchar2;
		v_cur INTEGER;
		v_rows INTEGER;
		v_col_cnt INTEGER;
		v_rec_tab DBMS_SQL.DESC_TAB2;
		v_out_rec data_browser_conf.rec_col_value;
		v_blob BLOB;
		v_clob CLOB;
		v_Exact BOOLEAN;
	begin
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_query,p_search_value,p_offset,p_exact;
        end if;
		v_Exact	:= (p_Exact = 'YES');
		v_col_values := apex_t_varchar2();
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Query, DBMS_SQL.NATIVE);
		IF p_Search_Value IS NOT NULL then
			dbms_sql.bind_variable(v_cur, ':search_value', p_Search_Value);
		end if;
		dbms_sql.describe_columns2(v_cur, v_col_cnt, v_rec_tab);
		v_col_values.extend( v_col_cnt );
		for j in 1..v_col_cnt loop
			if v_rec_tab(j).col_type = 113 then -- BLOB
				dbms_sql.define_column(v_cur, j, v_blob);
			elsif v_rec_tab(j).col_type = 112 then -- CLOB
				dbms_sql.define_column(v_cur, j, v_clob);
			else
				dbms_sql.define_column(v_cur, j, v_col_values(j), 4000);
			end if;
		end loop;
		v_rows := dbms_sql.execute_and_fetch (c => v_cur, exact => v_Exact);
		if v_rows > 0 then
			for j in 1 + p_Offset..v_col_cnt loop
				if v_rec_tab(j).col_type = 113 then -- BLOB
					dbms_sql.column_value(v_cur, j, v_blob);
					v_out_rec.column_data := null;
				elsif v_rec_tab(j).col_type = 112 then -- CLOB
					dbms_sql.column_value(v_cur, j, v_clob);
					v_out_rec.column_data := SUBSTRB(TO_CHAR(SUBSTR(v_clob, 1, 4000)), 1, 4000);
				else
					dbms_sql.column_value(v_cur, j, v_col_values(j));
					v_out_rec.column_data := v_col_values(j);
				end if;
				v_out_rec.column_name := v_rec_tab(j).col_name;
				v_out_rec.column_header := v_rec_tab(j).col_name;
				pipe row (v_out_rec);
			end loop;
		end if;
		dbms_sql.close_cursor(v_cur);
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_query,p_search_value,p_offset,p_exact,v_col_cnt;
        $END
$IF data_browser_conf.g_use_exceptions $THEN
	 exception
	  when others then
		dbms_sql.close_cursor(v_cur);
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_utl.column_value_list (%s) : %s',
				p0 => p_Search_Value,
				p1 => p_Query,
				p_max_length => 3500
			);
			apex_debug.info(
				p_message => 'failed with : %s',
				p0 => SQLERRM,
				p_max_length => 3500
			);

		$END
		RAISE;
$END 
	end Column_Value_List;

	---------------------------------------------------------------------------

	FUNCTION Get_Form_View_Text_Search (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Search_Field_Item IN VARCHAR2,
		p_Search_LOV_Value VARCHAR2 DEFAULT NULL,
    	p_Search_Column_Name IN VARCHAR2 DEFAULT NULL,
    	p_Search_Operator VARCHAR2 DEFAULT 'CONTAINS',		-- =,!=,IS NULL,IS NOT NULL,LIKE,NOT LIKE,IN,NOT IN,CONTAINS,NOT CONTAINS,REGEXP
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO, ALL
		p_Edit_Mode VARCHAR2 DEFAULT 'NO', 					-- YES, NO
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, QUERY, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,                -- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2
	is
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Count 		NUMBER := 0;
		v_Columns_Limit	PLS_INTEGER := LEAST(data_browser_conf.Get_Select_Columns_Limit, p_Columns_Limit);
        v_Str 			VARCHAR2(32767);
        v_Delimiter     CONSTANT VARCHAR2(50) := NL(4) || 'OR ';
	begin
		FOR c_cur IN (
			select case when p_Data_Source IN ('COLLECTION', 'QUERY')
						then COLUMN_NAME
					when (DATA_TYPE in ('NUMBER', 'FLOAT') and IS_REFERENCE = 'N'
						and p_Search_Operator IN ('=','!=','>','>=','<','<=','LIKE','NOT LIKE','BETWEEN')
					) or (p_Search_Operator IN ('IS NULL', 'NOT IS NULL')) then 
						 TABLE_ALIAS || '.' || REF_COLUMN_NAME
					when p_Search_LOV_Value IS NOT NULL then 
						 TABLE_ALIAS || '.' || REF_COLUMN_NAME
					when COLUMN_EXPR_TYPE IN ('LINK', 'DISPLAY_ONLY') and LOV_QUERY IS NOT NULL then 
						LOV_QUERY
					when COLUMN_EXPR_TYPE IN ('SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV', 'POPUP_FROM_LOV', 
						'NUMBER', 'FLOAT', 'DATE_POPUP', 'SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER', 'DISPLAY_ONLY') 
					and IS_VIRTUAL_COLUMN = 'N' then 
						COLUMN_EXPR
					else
						TABLE_ALIAS || '.' || REF_COLUMN_NAME
					end FILTER_EXP, 
					DATA_TYPE
			from table(data_browser_select.Get_View_Column_Cursor(
					p_Table_Name => v_Table_Name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Data_Columns_Only => p_Data_Columns_Only,
					p_Select_Columns => NULL, -- search all columns
					p_Columns_Limit => p_Columns_Limit,
					p_Join_Options => p_Join_Options,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => case when p_Data_Source IN ('COLLECTION', 'QUERY') 
										then 'YES' else p_Report_Mode end, -- search only visible columns in case of COLLECTION or QUERY.
					p_Edit_Mode => p_Edit_Mode,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible -- important
				)
			)
			WHERE data_browser_select.FN_Is_Searchable_Column(COLUMN_EXPR_TYPE, IS_SEARCHABLE_REF) = 'YES'
			AND (COLUMN_NAME LIKE p_Search_Column_Name OR p_Search_Column_Name IS NULL)
			AND NOT(p_Search_Operator IN ('=','!=','>','>=','<','<=') and DATA_TYPE IN ('CLOB', 'NCLOB'))
			AND (TABLE_ALIAS IS NOT NULL OR IS_SEARCHABLE_REF = 'Y')
			AND NOT(p_Data_Source = 'COLLECTION' AND IS_VIRTUAL_COLUMN = 'Y')
		)
		loop
			v_Count := v_Count + 1;
			v_Str :=  v_Str || case when v_Count > 1 then v_Delimiter end;
			if p_Search_Operator IN ('CONTAINS','NOT CONTAINS') then 
				v_Str :=  v_Str 
				|| 'INSTR(UPPER('
				|| c_cur.FILTER_EXP
				|| '), UPPER(' || p_Search_Field_Item || ')) '
				|| case when p_Search_Operator = 'NOT CONTAINS' then
					 '=' else '>'
				end
				|| ' 0 ';
			elsif p_Search_Operator = 'REGEXP' then 
				v_Str :=  v_Str 
				|| 'REGEXP_INSTR('
				|| c_cur.FILTER_EXP
				|| ', ' || p_Search_Field_Item || ', 1, 1, 1, ''i'') ' 
				|| case when p_Search_Operator = 'NOT CONTAINS' then
					 '=' else '>'
				end
				|| ' 0 ';
			elsif p_Search_Operator IN ('IS NULL','IS NOT NULL') then 
				v_Str :=  v_Str 
				|| c_cur.FILTER_EXP
				|| ' ' || p_Search_Operator;
			elsif p_Search_Operator IN ('IN','NOT IN') then 
				v_Str :=  v_Str 
				|| 'data_browser_conf.Match_Column_Pattern('
				|| c_cur.FILTER_EXP
				|| ', ' || p_Search_Field_Item || ') = ' 
				|| case when p_Search_Operator = 'NOT IN' then
					 	data_browser_conf.ENQUOTE_LITERAL('NO') 
					else data_browser_conf.ENQUOTE_LITERAL('YES')
				end;
			else -- p_Search_Operator IN ('=','!=','>','>=','<','<=', 'LIKE','NOT LIKE') then 
				v_Str :=  v_Str 
				|| c_cur.FILTER_EXP
				|| ' ' || p_Search_Operator
				|| ' ' || p_Search_Field_Item;
			end if;
			EXIT WHEN v_Count >= v_Columns_Limit;	-- avoid search conditons that are larger then 32K
		end loop;
		if v_Count = 0 then
			return null;
		elsif v_Count = 1 then
			return v_Str;
		else
			return '(' || v_Str || ')';
		end if;
	end Get_Form_View_Text_Search;

	FUNCTION Get_Form_Search_Cond (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO, ALL
		p_Edit_Mode VARCHAR2 DEFAULT 'NO', 					-- YES, NO
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, QUERY, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,                -- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_PAGE_ID'),
    	p_Search_Column_Name IN OUT VARCHAR2,
    	p_Search_Field_Item IN OUT VARCHAR2
	) RETURN VARCHAR2
	is
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Search_Condition	VARCHAR2(32767);
        v_Inner_Condition VARCHAR2(32767);
	begin
		FOR c_cur IN (
			select A.SEQ_ID, C001 Field, C002 Operator, NVL(C003, C005) Expresson, C005 LOV_Value
			from APEX_COLLECTIONS A 
			where A.COLLECTION_NAME = data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID
			and C001 IS NOT NULL
			and C004 = 'Y'
			and (NVL(C003, C005) IS NOT NULL or C002 IN ('IS NULL','IS NOT NULL'))
		)
		loop
			v_Search_Condition := data_browser_utl.Get_Form_View_Text_Search(
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Search_LOV_Value => c_cur.LOV_Value,
				p_Search_Field_Item => data_browser_conf.Enquote_Literal(c_cur.Expresson),
				p_Search_Column_Name => c_cur.Field,
				p_Search_Operator => c_cur.Operator,
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => 'ALL',
				p_Edit_Mode => p_Edit_Mode,
				p_Data_Source => p_Data_Source,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			);
			if c_cur.Operator IN ('CONTAINS','=') and c_cur.LOV_Value IS NULL then 
				p_Search_Column_Name := c_cur.Field;
				p_Search_Field_Item := data_browser_conf.Enquote_Literal(c_cur.Expresson);
			end if;
			if v_Inner_Condition IS NOT NULL then
				v_Inner_Condition := data_browser_conf.Build_Condition(v_Inner_Condition, v_Search_Condition);
			else 
				v_Inner_Condition := v_Search_Condition;
			end if;
		end loop;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_utl.Get_Form_Search_Cond : %s',
				p0 => v_Inner_Condition,
				p_max_length => 3500
			);
		$END
		return v_Inner_Condition;
	end Get_Form_Search_Cond;

	FUNCTION Get_Form_Search_Cond (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, QUERY, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,                -- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_RETURN_PAGE'), -- page id of current filter collection
		p_As_Lov_Query_Filter VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2
	is
        v_Search_Column_Name VARCHAR2(128);
        v_Search_Field_Item VARCHAR2(128);
        v_Search_Condition VARCHAR2(32767);
        v_From_Clause		VARCHAR2(32767);
	begin
		v_Search_Condition := data_browser_utl.Get_Form_Search_Cond(
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Data_Columns_Only => 'NO',
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Report_Mode => p_Report_Mode,
			p_Edit_Mode => 'NO',
			p_Data_Source => p_Data_Source,
			p_Join_Options => p_Join_Options,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Search_Field_Item => v_Search_Field_Item,
			p_Search_Column_Name => v_Search_Column_Name,
			p_App_Page_ID => p_App_Page_ID
		);
		if p_As_Lov_Query_Filter = 'NO' then
			return v_Search_Condition;
		elsif v_Search_Condition IS NOT NULL then 
			v_From_Clause := data_browser_select.Get_Query_From_Clause (
				p_Table_Name => p_Table_name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Join_Options => p_Join_Options,
				p_Data_Source => p_Data_Source
			);
			return ' EXISTS (SELECT 1 '
			|| v_From_Clause
			|| ' WHERE ' || v_Search_Condition
			|| ' AND ' || data_browser_conf.Get_Join_Expression(
							p_Left_Columns=>p_Unique_Key_Column, p_Left_Alias=>'L1',
							p_Right_Columns=>p_Unique_Key_Column, p_Right_Alias=>'A')
			|| ')';
		else 
			return NULL;
		end if;
	end Get_Form_Search_Cond;
	
	---------------------------------------------------------------------------
	-- Main functions:

	FUNCTION Get_Detail_View_Column_Cursor (				-- External : used for search column LOV and order by column LOV
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Format IN VARCHAR2 DEFAULT 'SEARCH',				-- ALL, SEARCH, ORDER_BY, PAGINATION
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO', -- YES, NO
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'YES'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN data_browser_conf.tab_col_value PIPELINED -- List of values for SEARCH_FIELD and ORDER_BY
	is
	PRAGMA UDF;
        v_Table_Name 		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Parent_Table		VARCHAR2(128);
        v_Parent_Key_Column VARCHAR2(128);
		v_Unique_Key_Column  MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
        CURSOR form_view_cur
        IS
        	with COLUMNS_SUBQ as (
				select COLUMN_NAME, COLUMN_HEADER, COLUMN_EXPR_TYPE, IS_SEARCHABLE_REF, REF_COLUMN_NAME
				from table(
					data_browser_select.Get_View_Column_Cursor(
						p_Table_name => v_Table_name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_Columns_Limit => p_Columns_Limit,
						p_Data_Columns_Only => 'YES',
						p_Select_Columns => NULL,
						p_Join_Options => p_Join_Options,
						p_View_Mode => p_View_Mode,
						p_Edit_Mode => p_Edit_Mode,
						p_Report_Mode => case when p_Format IN ('ALL', 'SEARCH') then 'ALL' else 'NO' end,
						p_Parent_Name => v_Parent_Table,
						p_Parent_Key_Column => v_Parent_Key_Column,
						p_Parent_Key_Visible => p_Parent_Key_Visible -- when key is used, searching or ordering has no effect
					)
				)
			)
			select COLUMN_NAME, COLUMN_HEADER, COLUMN_EXPR_TYPE AS COLUMN_DATA
			from COLUMNS_SUBQ
			where (data_browser_select.FN_Is_Searchable_Column(COLUMN_EXPR_TYPE, IS_SEARCHABLE_REF) = 'YES' or p_Format != 'SEARCH')
			and  (data_browser_select.FN_Is_Sortable_Column(COLUMN_EXPR_TYPE) = 'YES' or p_Format NOT IN ('ORDER_BY', 'PAGINATION'))
			union 
			select COLUMN_NAME, COLUMN_HEADER, 'TEXT' COLUMN_DATA
			from TABLE(data_browser_utl.Get_Default_Order_by_Cursor(
				p_Table_Name => p_Table_Name, 
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Parent_Name => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			))
			where p_Format = 'PAGINATION';
		v_out_tab data_browser_conf.tab_col_value;
	begin
		if v_Table_Name IS NOT NULL and p_View_Mode IS NOT NULL then
			if p_Unique_Key_Column IS NULL then
				begin 
					SELECT T.SEARCH_KEY_COLS
					INTO v_Unique_Key_Column
					FROM MVDATA_BROWSER_VIEWS T
					WHERE T.VIEW_NAME = v_Table_Name;
				exception when NO_DATA_FOUND then 
					return;
				end;
			else 
				v_Unique_Key_Column := p_Unique_Key_Column;
			end if;

			if p_Parent_Name IS NOT NULL and v_Parent_Key_Column IS NULL then
				begin
					SELECT R_VIEW_NAME, COLUMN_NAME
					INTO v_Parent_Table, v_Parent_Key_Column
					FROM MVDATA_BROWSER_REFERENCES
					WHERE VIEW_NAME = v_Table_name
					AND R_VIEW_NAME = p_Parent_Name
					AND COLUMN_NAME = NVL(p_Parent_Key_Column, COLUMN_NAME)
					AND ROWNUM = 1;
				exception when NO_DATA_FOUND then
					null;
				end;
			end if;

			OPEN form_view_cur;
			FETCH form_view_cur BULK COLLECT INTO v_out_tab;
			CLOSE form_view_cur;
			IF v_out_tab.FIRST IS NOT NULL THEN
				FOR ind IN 1 .. v_out_tab.COUNT
				LOOP
					pipe row (v_out_tab(ind));
				END LOOP;
			END IF;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_columns_limit,p_format,p_join_options,p_view_mode,p_edit_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,v_out_tab.COUNT;
        $END
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_utl.Get_Detail_View_Column_Cursor failed with : %s',
				p0 => DBMS_UTILITY.FORMAT_ERROR_STACK,
				p_max_length => 3500
			);

		$END
	    if form_view_cur%ISOPEN then
			CLOSE form_view_cur;
		end if;
		raise;
$END 
	end Get_Detail_View_Column_Cursor;

	FUNCTION Get_Detail_View_Query (						-- External : Readonly Detail View Report Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO - include ROW_SELECTOR
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- TABLE, NEW_ROWS, COLLECTION, QUERY
    	p_Data_Format VARCHAR2 DEFAULT data_browser_select.FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),     -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_File_Page_ID NUMBER DEFAULT 31,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Search_Field_Item VARCHAR2 DEFAULT NULL,			-- Example : P30_SEARCH
    	p_Search_Column_Name IN VARCHAR2 DEFAULT NULL,
    	p_Calc_Totals  VARCHAR2 DEFAULT 'NO',			-- YES, NO
    	p_Nested_Links VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Source_Query CLOB DEFAULT NULL, 					-- Passed query for from clause
    	p_Comments VARCHAR2 DEFAULT NULL					-- Comments
	) RETURN CLOB
	is
        v_View_Mode 		VARCHAR2(30) := NVL(UPPER(p_View_Mode), 'FORM_VIEW');
        v_Data_Source		VARCHAR2(30) := NVL(p_Data_Source, 'TABLE');
        v_Columns_Limit		PLS_INTEGER  := case when v_Data_Source = 'COLLECTION' then LEAST(data_browser_conf.Get_Collection_Columns_Limit, NVL(p_Columns_Limit, 1000))
        										else NVL(p_Columns_Limit, 1000) end;
        v_Str 				VARCHAR2(32767);
	begin
		if p_Table_name IS NULL then 
			v_Str := 'SELECT ';
			for ind IN 1..50 loop -- prototype columns for report creation
				v_Str := v_Str || chr(39)||chr(39)||' C' || LPAD(ind, 3, '0')
				|| case when ind < 50 then ', ' end;
			end loop;
			v_Str := v_Str || ' FROM DUAL';
			return v_Str;
		end if;

		if v_View_Mode IN ('FORM_VIEW', 'HISTORY', 'RECORD_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW') then
			return data_browser_select.Get_Form_View_Query(
				p_Table_Name => p_Table_Name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Data_Columns_Only => NVL(p_Data_Columns_Only, 'NO'),
				p_Columns_Limit => v_Columns_Limit,
				p_Select_Columns => p_Select_Columns,
				p_Control_Break => p_Control_Break,
				p_View_Mode => v_View_Mode,
				p_Edit_Mode => NVL(p_Edit_Mode, 'NO'),
				p_Data_Source => v_Data_Source,
				p_Data_Format => p_Data_Format,
				p_Empty_Row => case when v_Data_Source = 'NEW_ROWS' then 'YES' else 'NO' end,
				p_Report_Mode => NVL(p_Report_Mode, 'YES'),
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => NVL(p_Parent_Key_Visible, 'NO'),
				p_Link_Page_ID => p_Link_Page_ID,
				p_Link_Parameter => p_Link_Parameter,
				p_Detail_Page_ID => p_Detail_Page_ID,
				p_Detail_Parameter => p_Detail_Parameter,
				p_Form_Page_ID => p_Form_Page_ID,
				p_Form_Parameter => p_Form_Parameter,
				p_File_Page_ID => p_File_Page_ID,
				p_Search_Field_Item => p_Search_Field_Item,
				p_Search_Column_Name => p_Search_Column_Name,
				p_Calc_Totals => p_Calc_Totals,
				p_Nested_Links => p_Nested_Links,
				p_Source_Query => p_Source_Query,
				p_Comments => p_Comments
			);
		elsif v_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			return data_browser_select.Get_Imp_Table_Query (
				p_Table_Name => p_Table_Name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Data_Columns_Only => NVL(p_Data_Columns_Only, 'NO'),
				p_Columns_Limit => v_Columns_Limit,
				p_As_Of_Timestamp => 'NO',
				p_Select_Columns => p_Select_Columns,
				p_Control_Break => p_Control_Break,
				p_Join_Options => p_Join_Options,
				p_View_Mode => v_View_Mode,
				p_Edit_Mode => NVL(p_Edit_Mode, 'NO'),
				p_Data_Source => v_Data_Source,
				p_Data_Format => p_Data_Format,
				p_Report_Mode => NVL(p_Report_Mode, 'YES'),
				p_Form_Page_ID => p_Form_Page_ID,
				p_Form_Parameter => p_Form_Parameter,
				p_Search_Field_Item => p_Search_Field_Item,
				p_Search_Column_Name => p_Search_Column_Name,
				p_Comments => p_Comments,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => NVL(p_Parent_Key_Visible, 'NO'),
				p_File_Page_ID => p_File_Page_ID
			);
		end if;
		return NULL;
	end Get_Detail_View_Query;

	FUNCTION Get_Detail_View_Column_List (				-- External : column list for classic report headings and alignment
    	p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Delimiter VARCHAR2 DEFAULT ', ',
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
    	p_Select_Columns VARCHAR2 DEFAULT NULL,
    	p_Columns_Limit INTEGER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Format VARCHAR2 DEFAULT 'NAMES', 				-- NAMES, HEADER, ALIGN, ITEM_HELP
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 			-- YES, NO
 		p_Enable_Sort VARCHAR2 DEFAULT 'NO', 			-- YES, NO - generate clickable headers
    	p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : 'LAST_NAME, FIRST_NAME'
    	p_Order_Direction VARCHAR2 DEFAULT 'ASC',		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    ) RETURN CLOB
	is
        v_Table_Name 		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Parent_Table		VARCHAR2(128);
        v_Parent_Key_Column VARCHAR2(128);
	begin
		if p_Parent_Name IS NOT NULL then
			begin
				SELECT R_VIEW_NAME, COLUMN_NAME
				INTO v_Parent_Table, v_Parent_Key_Column
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = p_Parent_Name
				AND COLUMN_NAME = NVL(p_Parent_Key_Column, COLUMN_NAME)
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;
		return case
		when p_View_Mode IN ('FORM_VIEW', 'HISTORY', 'RECORD_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW') then
			data_browser_select.Get_Form_View_Column_List(
				p_Table_Name => v_Table_Name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Delimiter => p_Delimiter,
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_Format => p_Format,
				p_View_Mode => p_View_Mode,
				p_Edit_Mode => p_Edit_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Enable_Sort => p_Enable_Sort,
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Parent_Name => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			)
		when p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			data_browser_select.Get_Imp_Table_Column_List (
				p_Table_Name => v_Table_Name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Delimiter => p_Delimiter,
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_Format => p_Format,
				p_Join_Options => p_Join_Options,
				p_View_Mode => p_View_Mode,
				p_Edit_Mode => p_Edit_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Enable_Sort => p_Enable_Sort,
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Parent_Name => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			)
		end;
	end Get_Detail_View_Column_List;

	PROCEDURE Prepare_Detail_View (						-- External : column list for report column alignment and column item help
    	p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Join_Options IN OUT NOCOPY VARCHAR2,
    	p_Alignment OUT NOCOPY VARCHAR2,
    	p_Item_Help OUT NOCOPY VARCHAR2,
    	p_Order_by IN VARCHAR2,
    	p_Order_Direction IN VARCHAR2
    )
	is
		v_Page_Id VARCHAR2(10) := V('APP_PAGE_ID');
	begin
		if p_Table_Name IS NOT NULL then
			if p_Join_Options IS NULL and p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			-- Setup default joins
			-- By default only natural key columns are included.
			-- But all columns of the master table are included in the export view
				p_Join_Options := data_browser_joins.Get_Details_Join_Options(
					p_Table_name => p_Table_Name,
					p_View_Mode => p_View_Mode,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible
				);
			end if;
			p_Alignment := data_browser_utl.Get_Detail_View_Column_List (
				p_Table_Name => p_Table_Name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Delimiter => ':',
				p_Data_Columns_Only => 'NO',
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => 60,
				p_View_Mode => p_View_Mode,
				p_Edit_Mode => p_Edit_Mode,
				p_Report_Mode => 'YES',
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Format => 'ALIGN',
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			);
			p_Item_Help := data_browser_utl.Get_Detail_View_Column_List (
				p_Table_Name => p_Table_Name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Delimiter => '|',
				p_Data_Columns_Only => 'NO',
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => 60,
				p_View_Mode => p_View_Mode,
				p_Edit_Mode => p_Edit_Mode,
				p_Report_Mode => 'YES',
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Format => 'ITEM_HELP',
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			);
		else
			p_Join_Options := NULL;
			p_Alignment := NULL;
			p_Item_Help := NULL;
		end if;
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_unique_key_column,p_select_columns,p_view_mode,p_edit_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,p_join_options,p_alignment,p_item_help,p_order_by,p_order_direction;
        end if;
		if p_Edit_Mode = 'YES' then
			data_browser_blobs.Init_Clob_Updates;
		end if;
	end Prepare_Detail_View;

    FUNCTION Lookup_Column_Value (
        p_Search_Value  IN VARCHAR2,
        p_Table_Name    IN VARCHAR2,
        p_Column_Exp     IN VARCHAR2,
        p_Search_Key_Col IN VARCHAR2
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
        stat_cur            SYS_REFCURSOR;
        v_Stat1             VARCHAR2(4000);
        v_Wert              VARCHAR2(4000);
    BEGIN
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_search_value,p_table_name,p_column_exp,p_search_key_col;
        end if;
    	if p_Column_Exp IS NOT NULL then
			v_Stat1 := 'SELECT ' || p_Column_Exp
			|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) || ' A '
			|| ' WHERE ' || p_Search_Key_Col || ' = :s';
			OPEN  stat_cur FOR v_Stat1 USING p_Search_Value;
			FETCH stat_cur INTO v_Wert;
			CLOSE stat_cur;
			RETURN v_Wert;
        else
        	RETURN p_Search_Value;
        end if;
    END Lookup_Column_Value;


    FUNCTION Lookup_Column_Values (
        p_Table_Name    IN VARCHAR2,
        p_Column_Names  IN VARCHAR2,
        p_Search_Key_Col IN VARCHAR2,
        p_Search_Value  IN VARCHAR2,
        p_View_Mode		IN VARCHAR2
    )
    RETURN VARCHAR2
    IS
	PRAGMA UDF;
        stat_cur            SYS_REFCURSOR;
        v_Wert              VARCHAR2(4000);
        v_Query 			VARCHAR2(32767);
    BEGIN
		SELECT
			data_browser_select.Key_Values_Path_Query(
				p_Table_Name => VIEW_NAME,
				p_Display_Col_Names => NVL(p_Column_Names, DISPLAYED_COLUMN_NAMES),
				p_Extra_Col_Names	=> null,
				p_Search_Key_Col => NVL(p_Search_Key_Col, SEARCH_KEY_COLS),
				p_Search_Value => ':s',
				p_View_Mode => p_View_Mode,
				p_Exclude_Col_Name => NULL,
				p_Active_Col_Name => ACTIVE_LOV_COLUMN_NAME,
				p_Active_Data_Type => ACTIVE_LOV_DATA_TYPE,
				p_Folder_Par_Col_Name	=> FOLDER_PARENT_COLUMN_NAME,
				p_Folder_Name_Col_Name => FOLDER_NAME_COLUMN_NAME,
				p_Folder_Cont_Col_Name => FOLDER_CONTAINER_COLUMN_NAME,
				p_Order_by => NVL(ORDERING_COLUMN_NAME, '1')
                ) LOV_QUERY
		INTO v_query
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME = p_Table_Name;

		OPEN  stat_cur FOR v_Query USING p_Search_Value;
		FETCH stat_cur INTO v_Wert;
		CLOSE stat_cur;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_column_names,p_search_key_col,p_search_value,p_view_mode,v_Wert;
        $END
        RETURN v_Wert;
	EXCEPTION
	  WHEN NO_DATA_FOUND THEN
		RETURN p_Search_Value;
$IF data_browser_conf.g_use_exceptions $THEN
	  WHEN others THEN
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_select.Lookup_Column_Values (p_Table_name=> %s) -- %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_name),
				p1 => 'failed with ' || DBMS_UTILITY.FORMAT_ERROR_STACK,
				p_max_length => 3500
			);
		$END
		RETURN NULL;
$END 
    END Lookup_Column_Values;

	FUNCTION Get_View_Mode_Description (	-- Heading for Report
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2
	is
		v_View_Mode VARCHAR2(255);
	begin
		select APEX_LANG.LANG(D) D
		into v_View_Mode
		from (
			select 'Raw Record' D, 'RECORD_VIEW' R from dual union all
			select 'Form View' D, 'FORM_VIEW' R from dual union all
			select 'Navigation Counter' D, 'NAVIGATION_VIEW' R from dual union all
			select 'Navigation Links' D, 'NESTED_VIEW' R from dual union all
			select 'Import View' D, 'IMPORT_VIEW' R from dual union all
			select 'Export View' D, 'EXPORT_VIEW' R from dual union all
			select 'History' D, 'HISTORY' R from dual
		) where R = p_View_Mode;
		return v_View_Mode;
	exception when no_data_found then
		return data_browser_conf.Table_Name_To_Header(p_View_Mode);
	end Get_View_Mode_Description;

	FUNCTION Get_Report_Description (	-- Heading for Report
		p_Table_name IN VARCHAR2,
		p_Parent_Name IN VARCHAR2 DEFAULT NULL,
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_View_Mode IN VARCHAR2,
		p_Search_Key_Col IN VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	IS
		v_Description VARCHAR2(4000);
	BEGIN
		if p_Table_name IS NULL then
			return NULL;
		end if;
		if p_Parent_Name IS NULL then
			v_Description :=  apex_lang.lang('%0 for %1',
				data_browser_utl.Get_View_Mode_Description(p_View_Mode),
				data_browser_conf.Table_Name_To_Header(p_Table_name)
			);
		else
			v_Description :=  apex_lang.lang('%0 for %1 by %2',
				data_browser_utl.Get_View_Mode_Description(p_View_Mode),
				data_browser_conf.Table_Name_To_Header(p_Table_name),
				data_browser_conf.Table_Name_To_Header(p_Parent_Name)
			);
		end if;
		if p_Parent_Name IS NOT NULL and p_Search_Value IS NOT NULL then
			SELECT apex_lang.lang('%0 for %1 of %2 (%3)',
					data_browser_utl.Get_View_Mode_Description(p_View_Mode),
					data_browser_conf.Table_Name_To_Header(VIEW_NAME),
					data_browser_conf.Table_Name_To_Header(R_VIEW_NAME),
					data_browser_utl.Lookup_Column_Values(
						p_Table_Name => R_VIEW_NAME,
						p_Column_Names => DISPLAYED_COLUMN_NAMES,
						p_Search_Key_Col => NVL(p_Search_Key_Col, R_PRIMARY_KEY_COLS),
						p_Search_Value => p_Search_Value,
						p_View_Mode => p_View_Mode
					)
				) DISPLAY_VALUE
			INTO v_Description
			FROM MVDATA_BROWSER_REFERENCES T
			WHERE R_VIEW_NAME = p_Parent_Name
			AND VIEW_NAME = p_Table_name
			AND COLUMN_NAME = p_Parent_Key_Column;
		end if;
		return v_Description;
	exception when no_data_found then
		return v_Description;
	END Get_Report_Description;


	FUNCTION Get_Report_Description (	-- Heading for Report
		p_Table_name IN VARCHAR2,
		p_Parent_Name IN VARCHAR2,
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Search_Value IN VARCHAR2,
		p_Search_Key_Col IN VARCHAR2 DEFAULT NULL,
		p_Report_ID IN VARCHAR2  DEFAULT NULL
	) RETURN VARCHAR2
	IS
		v_Description VARCHAR2(4000);
		v_Report_Name DATA_BROWSER_REPORT_PREFS.NAME%TYPE;
	BEGIN
		if p_Table_name IS NULL then
			return NULL;
		end if;
		if p_Report_ID IS NOT NULL then 
			v_Description :=  data_browser_conf.Table_Name_To_Header(p_Table_name);

			SELECT NAME INTO v_Report_Name
			FROM DATA_BROWSER_REPORT_PREFS
			WHERE ID = p_Report_ID;
			return v_Description || ' – ' || v_Report_Name;
		end if;
		if p_Parent_Name IS NULL then
			v_Description :=  data_browser_conf.Table_Name_To_Header(p_Table_name);
		else
			v_Description :=  apex_lang.lang('%0 by %1',
				data_browser_conf.Table_Name_To_Header(p_Table_name),
				data_browser_conf.Table_Name_To_Header(p_Parent_Name)
			);
		end if;
		if p_Parent_Name IS NOT NULL and p_Search_Value IS NOT NULL then
			SELECT apex_lang.lang('%0 of %1 (%2)',
					data_browser_conf.Table_Name_To_Header(VIEW_NAME),
					data_browser_conf.Table_Name_To_Header(R_VIEW_NAME),
					data_browser_utl.Lookup_Column_Values(
						p_Table_Name => R_VIEW_NAME,
						p_Column_Names => DISPLAYED_COLUMN_NAMES,
						p_Search_Key_Col => NVL(p_Search_Key_Col, R_PRIMARY_KEY_COLS),
						p_Search_Value => p_Search_Value,
						p_View_Mode => 'FORM_VIEW'
					)
				) DISPLAY_VALUE
			INTO v_Description
			FROM MVDATA_BROWSER_REFERENCES T
			WHERE R_VIEW_NAME = p_Parent_Name
			AND VIEW_NAME = p_Table_name
			AND COLUMN_NAME = p_Parent_Key_Column;
		end if;
		return v_Description;
	exception when no_data_found then
		return v_Description;
	END Get_Report_Description;

	PROCEDURE Get_Default_Order_by (					-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name IN VARCHAR2 DEFAULT NULL,			-- Parent View or Table name
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible IN VARCHAR2 DEFAULT 'NO',     -- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Order_By OUT VARCHAR2,
    	p_Control_Break OUT VARCHAR2,
		p_Order_By_Hdr OUT VARCHAR2,
		p_Control_Break_Hdr OUT VARCHAR2
	)
	is
		v_Order_By VARCHAR(4000);
        v_Parent_Key_Visible VARCHAR2(10);
        v_Ref_Num_Rows PLS_INTEGER;
        v_Tab_Num_Rows PLS_INTEGER;
	begin
		if p_Table_name IS NULL then
			p_Order_By := NULL;
			p_Control_Break := NULL;
			return;
		end if;
		-- when collection is accessed, the parameter has to be used, else the column can be accessed in the table when it is not displayed.
		-- v_Parent_Key_Visible := case when p_View_Mode = 'IMPORT_VIEW' then p_Parent_Key_Visible else 'YES' end;
		v_Parent_Key_Visible := 'YES';
		if p_Parent_Name IS NOT NULL and p_Parent_Key_Column IS NOT NULL then
			SELECT NUM_ROWS 
			INTO v_Ref_Num_Rows
			FROM MVDATA_BROWSER_REFERENCES 
			WHERE VIEW_NAME = p_Table_name
			AND R_VIEW_NAME = p_Parent_Name
			AND COLUMN_NAME = p_Parent_Key_Column;
		end if;
		SELECT 
			case when p_View_Mode = 'HISTORY' then 
				'DML$_LOGGING_DATE'
			when ORDERING_COLUMN_NAME is not null then 
				ORDERING_COLUMN_NAME
			else 
				DISPLAYED_COLUMN_NAMES
			end COLS,
			NUM_ROWS
		INTO v_Order_By, v_Tab_Num_Rows
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME = p_Table_name;

		-- by default - avoid sorting of large tables
		if COALESCE(v_Ref_Num_Rows, v_Tab_Num_Rows, 0) > data_browser_conf.Get_Automatic_Sorting_Limit then 
			p_Order_By :=  NULL;
			p_Order_By_Hdr :=  NULL;
			p_Control_Break :=  NULL;
			p_Control_Break_Hdr :=  NULL;
			return;
		end if;
		-- Map Column names
		SELECT LISTAGG(case when B.POSITION IS NOT NULL 
							and (R_COLUMN_NAME != p_Parent_Key_Column OR p_Parent_Key_Column IS NULL) 
						then A.COLUMN_NAME end, ', ')
					WITHIN GROUP (ORDER BY B.POSITION) VALID_ORDER_BY,
				LISTAGG(case when B.POSITION IS NOT NULL 
							and (R_COLUMN_NAME != p_Parent_Key_Column OR p_Parent_Key_Column IS NULL) 
						then A.COLUMN_HEADER end, ', ')
					WITHIN GROUP (ORDER BY B.POSITION) ORDER_BY_HDR,
				LISTAGG( case when R_COLUMN_NAME = p_Parent_Key_Column 
						then A.COLUMN_NAME end, ', ') 
					WITHIN GROUP (ORDER BY A.POSITION, A.COLUMN_NAME) CONTROL_BREAK,
				LISTAGG( case when R_COLUMN_NAME = p_Parent_Key_Column 
						then A.COLUMN_HEADER end, ', ') 
					WITHIN GROUP (ORDER BY A.POSITION, A.COLUMN_NAME) CONTROL_BREAK_HDR

		INTO p_Order_By, p_Order_By_Hdr, p_Control_Break, p_Control_Break_Hdr
		FROM (
			SELECT COLUMN_NAME, COLUMN_HEADER, R_COLUMN_NAME, REF_COLUMN_NAME, REF_VIEW_NAME, POSITION
			FROM TABLE(
				data_browser_select.Get_View_Column_Cursor(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Columns_Limit => p_Columns_Limit,
					p_Data_Columns_Only => 'YES',
					p_Join_Options => null,		-- only default joins
					p_View_Mode => p_View_Mode,
					p_Edit_Mode => 'NO',		-- exclude hidden columns 
					p_Report_Mode => 'NO',
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible
				)
			)
			WHERE data_browser_select.FN_Is_Sortable_Column(COLUMN_EXPR_TYPE) = 'YES'
		) A
		LEFT OUTER JOIN (
			SELECT TRIM(P.COLUMN_VALUE) COLUMN_NAME, ROWNUM POSITION
			FROM TABLE( apex_string.split(v_Order_By, ',') ) P
		) B ON A.COLUMN_NAME = B.COLUMN_NAME;
		
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(p_overload => 1)
            USING p_table_name,p_unique_key_column,p_columns_limit,p_view_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,p_order_by,p_control_break,p_order_by_hdr,p_control_break_hdr;
        end if;
	exception when no_data_found then
	  	return;
	end Get_Default_Order_by;

	FUNCTION Get_Default_Order_by (						-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Order_By VARCHAR(4000);
		v_Control_Break VARCHAR(4000);
		v_Order_By_Hdr VARCHAR(4000);
		v_Control_Break_Hdr VARCHAR(4000);
        v_Tab_Num_Rows PLS_INTEGER;
        v_result varchar2(32767);
	begin
		if p_Table_name IS NULL then 
			return null;
		end if;
		if p_Parent_Name IS NULL and p_View_Mode NOT IN ('IMPORT_VIEW', 'EXPORT_VIEW') then 
			SELECT 
				case when p_View_Mode = 'HISTORY' then 
					'DML$_LOGGING_DATE'
				when ORDERING_COLUMN_NAME is not null then 
					ORDERING_COLUMN_NAME
				else 
					DISPLAYED_COLUMN_NAMES
				end COLS,
				NUM_ROWS
			INTO v_Order_By, v_Tab_Num_Rows
			FROM MVDATA_BROWSER_DESCRIPTIONS
			WHERE VIEW_NAME = p_Table_name;
			if v_Tab_Num_Rows > data_browser_conf.Get_Automatic_Sorting_Limit then 
				v_Order_By := NULL;
			end if;
		else
			Get_Default_Order_by (
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible,
				p_Order_By => v_Order_By,
				p_Control_Break => v_Control_Break,
				p_Order_By_Hdr => v_Order_By_Hdr,
				p_Control_Break_Hdr => v_Control_Break_Hdr
			);
		end if;
		v_result := data_browser_conf.concat_list(v_Control_Break, v_Order_By, ', ');
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call(p_overload => 2)
            USING p_table_name,p_unique_key_column,p_columns_limit,p_view_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,v_result;
        $END
        return v_result;
	exception when no_data_found then
	  	return null;
	end Get_Default_Order_by;

	FUNCTION Get_Default_Order_by_Cursor (						-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN data_browser_conf.tab_col_value PIPELINED
	is
	PRAGMA UDF;
		v_Order_By VARCHAR(4000);
		v_Control_Break VARCHAR(4000);
		v_Order_By_Hdr VARCHAR(4000);
		v_Control_Break_Hdr VARCHAR(4000);
		v_record 	data_browser_conf.rec_col_value;
	begin
		Get_Default_Order_by (
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Order_By => v_Order_By,
			p_Control_Break => v_Control_Break,
			p_Order_By_Hdr => v_Order_By_Hdr,
			p_Control_Break_Hdr => v_Control_Break_Hdr
		);
		v_record.COLUMN_NAME := data_browser_conf.concat_list(v_Control_Break, v_Order_By, ', ');
		v_record.COLUMN_HEADER := data_browser_conf.concat_list(v_Control_Break_Hdr, v_Order_By_Hdr, ', ');
		v_record.COLUMN_DATA := v_Control_Break;
		pipe row (v_record);
	end Get_Default_Order_by_Cursor;

	FUNCTION Get_Default_Control_Break (				-- External : Default for Get_Record_View_Query
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Order_By VARCHAR(4000);
		v_Control_Break VARCHAR(4000);
		v_Order_By_Hdr VARCHAR(4000);
		v_Control_Break_Hdr VARCHAR(4000);
	begin
		Get_Default_Order_by (
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Order_By => v_Order_By,
			p_Control_Break => v_Control_Break,
			p_Order_By_Hdr => v_Order_By_Hdr,
			p_Control_Break_Hdr => v_Control_Break_Hdr
		);
		return v_Control_Break;
	end Get_Default_Control_Break;

	FUNCTION Get_Default_Select_Columns (
		p_Table_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB
	IS
	BEGIN
		RETURN data_browser_utl.Get_Detail_View_Column_List ( 
			p_Table_Name => p_Table_Name, 
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Delimiter => ':', 
			p_Data_Columns_Only => 'YES',
			p_View_Mode => p_View_Mode, 
			p_Report_Mode => 'YES',
			p_Edit_Mode => p_Edit_Mode,
			p_Format => 'NAMES',
			p_Join_Options => p_Join_Options,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible
		);
	END Get_Default_Select_Columns;

	FUNCTION Filter_Select_Columns (
		p_Table_Name VARCHAR2,
		p_Select_Columns VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB
	IS
        v_Stat 				CLOB;
    	v_Str	 			VARCHAR2(266);
	BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		FOR c_cur IN (
			SELECT B.COLUMN_NAME, B.POSITION
			FROM (
				SELECT COLUMN_NAME, POSITION
				FROM TABLE(
					data_browser_select.Get_View_Column_Cursor(
						p_Table_name => p_Table_Name,
						p_Unique_Key_Column => p_Unique_Key_Column,
						p_Data_Columns_Only => 'YES',
						p_Select_Columns => NULL,
						p_Join_Options => p_Join_Options,
						p_View_Mode => p_View_Mode,
						p_Edit_Mode => p_Edit_Mode,
						p_Report_Mode => 'NO',
						p_Parent_Name => p_Parent_Name,
						p_Parent_Key_Column => p_Parent_Key_Column,
						p_Parent_Key_Visible => p_Parent_Key_Visible
					)
				)
			) A
			JOIN (
				SELECT TRIM(P.COLUMN_VALUE) COLUMN_NAME, ROWNUM POSITION
				FROM TABLE( apex_string.split(p_Select_Columns, ',') ) P
			) B ON A.COLUMN_NAME = B.COLUMN_NAME
			ORDER BY B.POSITION
		) LOOP 
			v_Str := case when c_cur.POSITION > 1 then ', ' || c_cur.COLUMN_NAME else c_cur.COLUMN_NAME end;
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);		
		END LOOP;
		RETURN v_Stat;
	END Filter_Select_Columns;

    FUNCTION Check_Edit_Enabled(
    	p_Table_Name VARCHAR2,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Search_Value IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 -- YES, NO
    IS
		v_Unique_Key_Column  		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Read_Only					MVDATA_BROWSER_VIEWS.READ_ONLY%TYPE;
    	v_Row_Locked_Column_Name 	MVDATA_BROWSER_VIEWS.ROW_LOCKED_COLUMN_NAME%TYPE;
    	v_Is_Number_Yes_No_Column	MVDATA_BROWSER_SIMPLE_COLS.IS_NUMBER_YES_NO_COLUMN%TYPE;
    	v_Is_Char_Yes_No_Column		MVDATA_BROWSER_SIMPLE_COLS.IS_CHAR_YES_NO_COLUMN%TYPE;
    	v_Row_Locked_Column_Value	VARCHAR2(20);
		v_Edit_Enabled VARCHAR2(10);
	BEGIN
		if p_Table_name IS NOT NULL and (data_browser_ctl.App_Trial_Modus or data_browser_ctl.App_Paid_Modus) then
			v_Edit_Enabled := data_browser_conf.Check_Edit_Enabled(p_Table_Name => p_Table_name);
		else
			v_Edit_Enabled := 'NO';
		end if;
		if v_Edit_Enabled = 'YES' then
			SELECT T.SEARCH_KEY_COLS, T.ROW_LOCKED_COLUMN_NAME, C.IS_NUMBER_YES_NO_COLUMN, C.IS_CHAR_YES_NO_COLUMN, T.READ_ONLY
			INTO v_Unique_Key_Column, v_Row_Locked_Column_Name, v_Is_Number_Yes_No_Column, v_Is_Char_Yes_No_Column, v_Read_Only
			FROM MVDATA_BROWSER_VIEWS T
			LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C ON T.VIEW_NAME = C.VIEW_NAME AND T.ROW_LOCKED_COLUMN_NAME = C.COLUMN_NAME
			WHERE T.VIEW_NAME = p_Table_name;
			if v_Read_Only = 'YES' then 
				v_Edit_Enabled := 'NO';
			else 
				-- Disable Edit mode when row is locked.
				if p_Search_Value IS NOT NULL 
				and v_Row_Locked_Column_Name IS NOT NULL 
				and (v_Is_Number_Yes_No_Column = 'Y' or v_Is_Char_Yes_No_Column = 'Y') then
					v_Row_Locked_Column_Value := data_browser_utl.Lookup_Column_Values (
						p_Table_Name => p_Table_name,
						p_Column_Names => v_Row_Locked_Column_Name,
						p_Search_Key_Col => v_Unique_Key_Column,
						p_Search_Value => p_Search_Value,
						p_View_Mode => p_View_Mode
					);
					if v_Is_Number_Yes_No_Column = 'Y' and v_Row_Locked_Column_Value = '1'
					or v_Is_Char_Yes_No_Column = 'Y' and v_Row_Locked_Column_Value = 'Y' then
						v_Edit_Enabled := 'NO';
					end if;
				end if;
			end if;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_view_mode,p_search_value,v_Edit_Enabled;
        $END
		return v_Edit_Enabled;
	EXCEPTION WHEN NO_DATA_FOUND THEN
		return 'NO';
	END Check_Edit_Enabled;
	
	PROCEDURE Get_Record_Description (
		p_Table_name IN VARCHAR2,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Search_Value IN VARCHAR2,
    	p_Unique_Key_Column IN OUT VARCHAR2, -- primary key column
    	p_Description  OUT VARCHAR2, -- Heading for Record,
    	p_Default_Order_by OUT VARCHAR2,
    	p_View_Mode_Description OUT VARCHAR2,
    	p_Edit_Enabled OUT VARCHAR2
	)
	IS
		v_Default_Order_by VARCHAR2(1024);
		v_View_Mode VARCHAR2(1024);
		v_Edit_Enabled VARCHAR2(10);
	BEGIN
		if p_Table_name IS NOT NULL and (data_browser_ctl.App_Trial_Modus or data_browser_ctl.App_Paid_Modus) then
			v_Edit_Enabled := data_browser_utl.Check_Edit_Enabled(
				p_Table_Name => p_Table_name,
				p_View_Mode => p_View_Mode,
				p_Search_Value => p_Search_Value
			);
		else
			v_Edit_Enabled := 'NO';
		end if;
		p_Edit_Enabled := v_Edit_Enabled;
		p_View_Mode_Description    := Get_View_Mode_Description(p_View_Mode);
		if p_Table_name IS NULL or p_Search_Value IS NULL then
			p_Description := data_browser_conf.Table_Name_To_Header(p_Table_name);
		else
			SELECT
				data_browser_conf.Table_Name_To_Header(VIEW_NAME)
				|| ' ( '
				|| data_browser_utl.Lookup_Column_Values(
					p_Table_Name => VIEW_NAME,
					p_Column_Names => DISPLAYED_COLUMN_NAMES,
					p_Search_Key_Col => SEARCH_KEY_COLS,
					p_Search_Value => p_Search_Value,
					p_View_Mode => 'FORM_VIEW'
				)
				|| ' ) '
				DISPLAY_VALUE,
				NVL(p_Unique_Key_Column, T.SEARCH_KEY_COLS) SEARCH_KEY_COLS,
				case when NVL(NUM_ROWS, 0) < data_browser_conf.Get_Automatic_Sorting_Limit	-- avoid sorting of large tables
						then NVL(ORDERING_COLUMN_NAME, DISPLAYED_COLUMN_NAMES)
				end ORDER_BY
			INTO p_Description, p_Unique_Key_Column, v_Default_Order_by
			FROM MVDATA_BROWSER_DESCRIPTIONS T
			WHERE VIEW_NAME = p_Table_name;

			-- p_Default_Order_by := v_Default_Order_by;
			p_Default_Order_by := data_browser_utl.Get_Default_Order_by (
				p_Table_Name => p_Table_Name, 
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_View_Mode => p_View_Mode);
		end if;
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_view_mode,p_search_value,p_unique_key_column,p_description,p_default_order_by,p_view_mode_description,p_edit_enabled;
        end if;
	exception when no_data_found then
		p_Description := data_browser_conf.Table_Name_To_Header(p_Table_name) || ' ( ' || NVL(p_Search_Value, 'new') || ' ) ';
	END Get_Record_Description;

	FUNCTION Get_Record_Label (
		p_Table_name IN VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Search_Key_Col IN VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2 
	IS
		v_Record_Label VARCHAR2(4000);
	BEGIN
		SELECT data_browser_utl.Lookup_Column_Values(
				p_Table_Name => VIEW_NAME,
				p_Column_Names => DISPLAYED_COLUMN_NAMES,
				p_Search_Key_Col => NVL(p_Search_Key_Col, SEARCH_KEY_COLS),
				p_Search_Value => p_Search_Value,
				p_View_Mode => p_View_Mode
			) DISPLAY_VALUE
		INTO v_Record_Label
		FROM MVDATA_BROWSER_DESCRIPTIONS T
		WHERE VIEW_NAME = p_Table_name;
		return v_Record_Label;
	END Get_Record_Label;

/*
data_browser_utl.Get_Report_Preferences(
	p_Search_Table => :P30_SEARCH_TABLE,
	p_Table_View_Mode => :P30_TABLE_VIEW_MODE,
	p_Constraint_Name => :P30_CONSTRAINT_NAME,
	p_Table_name => :P30_TABLE_NAME,
    p_Edit_Enabled => :P30_EDIT_ENABLED,
	p_Edit_Mode => :P30_EDIT_MODE,
	p_Add_Rows => :P30_ADD_ROW,
	p_View_Mode => :P30_VIEW_MODE,
	p_Order_by => :P30_ORDER_BY,
	p_Order_Direction => :P30_ORDER_DIRECTION,
	p_Join_Options => :P30_JOINS,
	p_Parent_Key_Visible => :P30_PARENT_KEY_VISIBLE,
	p_Rows => :P30_ROWS,
	p_Columns_Limit => :P30_COLUMNS_LIMIT
);
*/
	FUNCTION Fn_Pref_Prefix RETURN VARCHAR2 
	IS
	BEGIN
		RETURN NVL(V('OWNER'), SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')) || ':';
	END Fn_Pref_Prefix;

	FUNCTION Fn_Pref_Page_Prefix (
		p_Owner VARCHAR2 DEFAULT V('OWNER'),
    	p_Application_ID NUMBER DEFAULT NV('APP_ID'),
		p_Page_ID NUMBER DEFAULT NV('APP_PAGE_ID')
	) RETURN VARCHAR2 
	IS
	BEGIN
		RETURN p_Owner 
				|| ':' || p_Application_ID 
				|| ':' || p_Page_ID || ':';
	END Fn_Pref_Page_Prefix;
	
	PROCEDURE Get_Sort_Preferences (					-- internal
		p_Table_name IN VARCHAR2,						-- View or Table name
		p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
    	p_Parent_Name IN VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,	-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible IN VARCHAR2 DEFAULT 'NO',  -- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Filter IN VARCHAR2 DEFAULT 'NO',  	-- YES, NO, when YES, no p_Control_Break for that column is produced by default.
		p_View_Mode IN VARCHAR2,						-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Order_by OUT VARCHAR2,						-- Example : NAME
    	p_Order_Direction OUT VARCHAR2,					-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
    	p_Control_Break OUT VARCHAR2
	)
	is
		v_Prefs_Array apex_t_varchar2;
		v_Preferences	VARCHAR2(4000);
		v_Path VARCHAR2(1024) :=   '/' || p_Parent_Name || '/' || p_Table_name || '/' || p_View_Mode;
		v_Prefs_Order_By VARCHAR(4000);
		v_Prefs_Order_Dir VARCHAR(4000);
		v_Prefs_Control_Break VARCHAR(4000);
		v_Order_By VARCHAR(4000);
		v_Order_Dir VARCHAR(4000);
		v_Control_Break VARCHAR(4000);
		v_Order_By_Hdr VARCHAR(4000);
		v_Control_Break_Hdr VARCHAR(4000);
	begin
		v_Preferences := APEX_UTIL.GET_PREFERENCE(FN_Pref_Prefix || 'ORDER_BY' || v_Path);
		if v_Preferences IS NOT NULL then 
			v_Prefs_Array := apex_string.split(v_Preferences, ':');
			v_Prefs_Order_By := v_Prefs_Array(1);
			v_Prefs_Order_Dir := v_Prefs_Array(2);
			v_Prefs_Control_Break := v_Prefs_Array(3);
			p_Order_by := NULLIF(v_Prefs_Order_By, 'NULL');
			p_Order_Direction := COALESCE(v_Prefs_Order_Dir, 'ASC NULLS LAST');
			p_Control_Break := NULLIF(v_Prefs_Control_Break, 'NULL');
		else
			Get_Default_Order_by (
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Parent_Name => case when p_Parent_Key_Filter = 'NO' then p_Parent_Name end,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible,
				p_Order_By => v_Order_By,
				p_Control_Break => v_Control_Break,
				p_Order_By_Hdr => v_Order_By_Hdr,
				p_Control_Break_Hdr => v_Control_Break_Hdr
			);
			v_Order_By := data_browser_conf.concat_list(v_Control_Break, v_Order_By, ', ');
			p_Order_by := v_Order_By;
			p_Order_Direction := 'ASC NULLS LAST';
			p_Control_Break := v_Control_Break;
		end if;
	end Get_Sort_Preferences;

	PROCEDURE Get_Navigation_Preferences (
		-- independent --
		p_Search_Table IN OUT VARCHAR2,					-- YES, NO
		p_Table_View_Mode IN OUT VARCHAR2,
		p_Table_name IN OUT VARCHAR2,					-- View or Table name
    	p_Constraint_Name IN OUT VARCHAR2				-- Parent key
	)
	is
	begin
		p_Search_Table := COALESCE(p_Search_Table, APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'SEARCH_TABLE'));
		p_Table_View_Mode := COALESCE(p_Table_View_Mode, APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'TABLE_VIEW_MODE'), 'TABLE_HIERARCHY');
		p_Table_name := NVL(p_Table_name, APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'TABLE_NAME'));
		if p_Table_name IS NOT NULL then
			p_Constraint_Name := NVL(p_Constraint_Name, APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'CONSTRAINT_NAME' || '/' || p_Table_name));
		end if;
	end Get_Navigation_Preferences;

	PROCEDURE Set_Navigation_Preferences (
		-- independent --
		p_Search_Table IN OUT NOCOPY VARCHAR2,
		p_Table_View_Mode IN VARCHAR2,
    	p_Constraint_Name IN VARCHAR2,					-- Parent key
		p_Table_name IN VARCHAR2						-- View or Table name
	)
	is
		v_View_Mode VARCHAR2(50);
	begin
		APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'SEARCH_TABLE', p_Search_Table);
		APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'TABLE_VIEW_MODE', p_Table_View_Mode);
		APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'TABLE_NAME', p_Table_name);
		if p_Table_name IS NOT NULL and p_Table_View_Mode = 'TABLE_HIERARCHY' then
			-- dependent on table name --
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'CONSTRAINT_NAME' || '/' || p_Table_name, p_Constraint_Name); --- ???
		end if;
	end Set_Navigation_Preferences;

    PROCEDURE Load_Report_Preferences (
		p_Report_ID 		IN NUMBER, 	
		p_App_Page_ID 		IN VARCHAR2 DEFAULT V('APP_PAGE_ID'),
		p_View_Mode 		OUT VARCHAR2,		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Unique_Key_Column OUT VARCHAR2,		-- primary keys cols of the table 
    	p_Order_by 			OUT VARCHAR2,		-- Example : NAME
    	p_Order_Direction 	OUT VARCHAR2,		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options 		OUT VARCHAR2,		-- YES, NO
		p_Rows 				OUT NUMBER,			-- 10, 20, 30...
		p_Select_Columns 	OUT VARCHAR2,
		p_Control_Break 	OUT VARCHAR2,
    	p_Calc_Totals		OUT VARCHAR2,
    	p_Nested_Links		OUT VARCHAR2
	)
	IS
		v_query VARCHAR2(4000);
		e_20104 exception;
		pragma exception_init(e_20104, -20104);
	BEGIN 
		SELECT VIEW_MODE, UNIQUE_KEY_COLUMN, ORDER_BY, 
			ORDER_DIRECTION, JOIN_OPTIONS, ROWS_PER_PAGE, SELECT_COLUMNS, CONTROL_BREAK, 
			case when USE_NESTED_LINKS = 'Y' then 'YES' else 'NO' end USE_NESTED_LINKS, 
			case when CALC_SUBTOTALS = 'Y' then 'YES' else 'NO' end CALC_SUBTOTALS
		INTO p_View_Mode, p_Unique_Key_Column, p_Order_by,
			p_Order_Direction, p_Join_Options, p_Rows, p_Select_Columns, p_Control_Break, 
			p_Calc_Totals, p_Nested_Links
		FROM DATA_BROWSER_REPORT_PREFS
		WHERE ID = p_Report_ID;
		
		v_query := 'SELECT FIELD, OPERATOR, EXPRESSION, ACTIVE, LOV_VALUE '
		|| 'FROM DATA_BROWSER_REPORT_FILTER '
		|| 'WHERE DATA_BROWSER_REPORT_PREFS_ID = :a '
		|| 'ORDER BY LINE_NO';
		APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
			p_collection_name => data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID, 
			p_query => v_query, 
			p_truncate_if_exists => 'YES',
			p_names => apex_util.string_to_table('a'), 
			p_values => apex_util.string_to_table(p_Report_ID)
		);
	exception 
		when no_data_found then null;
		when e_20104 then null;
    END Load_Report_Preferences;
	

	PROCEDURE Get_Report_Preferences (
		-- independent --
		p_Table_name IN VARCHAR2,					-- View or Table name
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,	-- primary keys cols of the table 
		p_Report_ID IN NUMBER DEFAULT NULL, 	
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_PAGE_ID'),
    	p_Parent_Name IN VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
    	p_Parent_Key_Column IN VARCHAR2 DEFAULT NULL,	-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible IN OUT VARCHAR2, 		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Filter IN VARCHAR2 DEFAULT 'NO',  -- YES, NO, when YES, no p_Control_Break for that column is produced by default.
    	p_Table_View_Mode IN VARCHAR2 DEFAULT 'TABLE_DATA_VIEW', -- TABLE_HIERARCHY/TABLE_DATA_VIEW
		p_Edit_Enabled IN OUT VARCHAR2,				-- YES, NO
		p_Edit_Mode IN OUT VARCHAR2,				-- YES, NO
		-- dependent on table name --
		p_Add_Rows IN OUT VARCHAR2,					-- YES, NO
		p_View_Mode IN OUT VARCHAR2,				-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		-- dependent on table name and view mode --
    	p_Order_by IN OUT VARCHAR2,					-- Example : NAME
    	p_Order_Direction IN OUT VARCHAR2,			-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options IN OUT VARCHAR2,				-- Example : B;K:C;K:C_B;K:C_C;K:D;K
		p_Rows IN OUT NUMBER,						-- 10, 20, 30...
		p_Columns_Limit IN OUT NUMBER,
		p_Select_Columns IN OUT VARCHAR2,
		p_Control_Break IN OUT VARCHAR2,
    	p_Calc_Totals IN OUT VARCHAR2,				-- YES, NO
    	p_Nested_Links IN OUT VARCHAR2				-- YES, NO
	)
	is
		v_Join_Options				VARCHAR2(4000);
        v_Table_Name 				MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Unique_Key_Column  		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
        v_Tab_Num_Rows 				PLS_INTEGER;
        v_Calc_Totals_default		VARCHAR2(3);
        v_Preferences_Changed 		BOOLEAN := FALSE;
	begin
		if p_Table_name IS NOT NULL then
			begin
				SELECT NVL(p_Unique_Key_Column, SEARCH_KEY_COLS), NVL(NUM_ROWS, 0) NUM_ROWS
				INTO v_Unique_Key_Column, v_Tab_Num_Rows
				FROM MVDATA_BROWSER_VIEWS
				WHERE VIEW_NAME = v_Table_Name;				
			exception when no_data_found then
				v_Table_Name := NULL;
			end;
		end if;
		if v_Table_Name IS NOT NULL then
			p_Parent_Key_Visible := COALESCE(p_Parent_Key_Visible, 'NO');
			if p_Report_ID IS NOT NULL then 
				-- load selected columns, join condition, filter conditions, ordering and control break from named report.
				Load_Report_Preferences (
					p_Report_ID 		=> p_Report_ID,
					p_App_Page_ID		=> p_App_Page_ID,
					p_View_Mode 		=> p_View_Mode,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Order_by 			=> p_Order_by,
					p_Order_Direction 	=> p_Order_Direction,
					p_Join_Options 		=> p_Join_Options,
					p_Rows 				=> p_Rows,
					p_Select_Columns 	=> p_Select_Columns,
					p_Control_Break 	=> p_Control_Break,
					p_Calc_Totals		=> p_Calc_Totals,
					p_Nested_Links		=> p_Nested_Links
				);
			else 
				p_View_Mode := COALESCE(p_View_Mode,
									APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'VIEW_MODE' || '/' || v_Table_Name),
									'FORM_VIEW' -- default view mode
								);
				p_Select_Columns := APEX_UTIL.GET_PREFERENCE(FN_Pref_Prefix || 'SELECT_COLUMNS' || '/' || v_Table_Name || '/' || p_View_Mode);
				if p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then 
					v_Join_Options := APEX_UTIL.GET_PREFERENCE(FN_Pref_Prefix || 'JOINS' || '/' || v_Table_Name || '/' || p_View_Mode);
					if v_Join_Options IS NULL then 
						v_Join_Options := 
							data_browser_joins.Get_Details_Join_Options (
								p_Table_name => v_Table_Name,
								p_View_Mode => p_View_Mode,
								p_Parent_Key_Column => p_Parent_Key_Column,
								p_Parent_Key_Visible => p_Parent_Key_Visible
							);
					end if;
				end if;
				p_Join_Options := v_Join_Options;
			end if;
			p_Edit_Enabled := data_browser_utl.Check_Edit_Enabled(p_Table_Name => v_Table_Name, p_View_Mode => p_View_Mode);
			p_Edit_Mode := case when p_Edit_Enabled = 'NO' then 'NO' else NVL(p_Edit_Mode, 'NO') end;
			p_Add_Rows := case when p_Edit_Mode = 'NO' then 'NO' else NVL(p_Add_Rows, 'NO') end;

			if p_Report_ID IS NULL 
			or (p_Table_View_Mode = 'TABLE_HIERARCHY' and p_Parent_Name IS NOT NULL) then 
				-- in case for hierarchical navigation, overwrite ordering and control break
				data_browser_utl.Get_Sort_Preferences(
					p_Table_name 		=> v_Table_Name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Parent_Name 		=> p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Filter => p_Parent_Key_Filter,
					p_View_Mode 		=> p_View_Mode,
					p_Order_by 			=> p_Order_by,
					p_Order_Direction 	=> p_Order_Direction,
					p_Control_Break 	=> p_Control_Break
				);
				if p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW', 'RECORD_VIEW') then 
					p_Parent_Key_Visible := 'YES';
				elsif p_Control_Break = p_Parent_Key_Column then 
					p_Parent_Key_Visible := 'NO';
				end if;
			end if;
			if p_Edit_Mode = 'YES' then 
				p_Rows := LEAST(NVL(APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'ROWS'), 15), data_browser_conf.Get_Edit_Rows_Limit);
			else
				p_Rows := NVL(APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'ROWS'), 15);
			end if;
		else
			p_Edit_Enabled := 'NO';
			p_Edit_Mode := 'NO';
			p_Add_Rows := 'NO';
			p_View_Mode := 'FORM_VIEW';
		end if;
		v_Calc_Totals_default := case when v_Tab_Num_Rows <= data_browser_conf.Get_Automatic_Sorting_Limit then 'YES' else 'NO' end;
		p_Calc_Totals := COALESCE(p_Calc_Totals, APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'CALC_TOTALS'), v_Calc_Totals_default);
		p_Nested_Links := COALESCE(p_Nested_Links, APEX_UTIL.GET_PREFERENCE(Fn_Pref_Page_Prefix || 'NESTED_LINKS'), 'YES');

		if v_Table_Name IS NOT NULL
		and p_Report_ID IS NULL then
			data_browser_utl.Set_Report_Preferences(
				p_Table_name => v_Table_Name,
				p_Parent_Name => p_Parent_Name,
				p_View_Mode => p_View_Mode,
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Join_Options => p_Join_Options,
				p_Rows => p_Rows,
				p_Control_Break => p_Control_Break,
				p_Calc_Totals => p_Calc_Totals,
				p_Nested_Links => p_Nested_Links,
				p_Select_Columns => p_Select_Columns
			);
		end if;
			
		if p_View_Mode = 'IMPORT_VIEW' then
			p_Columns_Limit := data_browser_conf.Get_Collection_Columns_Limit;
		elsif p_Edit_Mode = 'YES' then 
			p_Columns_Limit := data_browser_conf.Get_Edit_Columns_Limit;
		else
			p_Columns_Limit := NVL(p_Columns_Limit, data_browser_conf.Get_Select_Columns_Limit);
		end if;

        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_unique_key_column,p_report_id,p_app_page_id,p_parent_name,p_parent_key_column,p_parent_key_visible,p_parent_key_filter,p_table_view_mode,p_edit_enabled,p_edit_mode,p_add_rows,p_view_mode,p_order_by,p_order_direction,p_join_options,p_rows,p_columns_limit,p_select_columns,p_control_break,p_calc_totals,p_nested_links;
        end if;
	end Get_Report_Preferences;


	PROCEDURE Save_Report_Preferences (
		p_Report_ID 		IN NUMBER, 	
		p_Table_name 		IN VARCHAR2,		-- View or Table name
		p_Unique_Key_Column IN VARCHAR2,		-- primary keys cols of the table 
		p_View_Mode 		IN VARCHAR2,		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Order_by 			IN VARCHAR2,		-- Example : NAME
    	p_Order_Direction 	IN VARCHAR2,		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options 		IN VARCHAR2,		-- YES, NO
		p_Rows 				IN NUMBER,			-- 10, 20, 30...
		p_Select_Columns 	IN VARCHAR2,
		p_Control_Break 	IN VARCHAR2,
    	p_Calc_Totals		IN VARCHAR2,		-- YES, NO
    	p_Nested_Links		IN VARCHAR2,		-- YES, NO
		p_App_Page_ID 		IN VARCHAR2 DEFAULT V('APP_PAGE_ID')
	)
	IS
	BEGIN 
		UPDATE DATA_BROWSER_REPORT_PREFS D
		SET D.VIEW_MODE = p_View_Mode, D.REPORT_MODE = 'Y', 
			D.UNIQUE_KEY_COLUMN = p_Unique_Key_Column, D.ORDER_BY = p_Order_by, 
			D.ORDER_DIRECTION = p_Order_Direction, D.JOIN_OPTIONS = p_Join_Options, D.ROWS_PER_PAGE = p_Rows, 
			D.SELECT_COLUMNS = p_Select_Columns, D.CONTROL_BREAK = p_Control_Break,
			D.USE_NESTED_LINKS = case when p_Calc_Totals = 'YES' then 'Y' else 'N' end,
			D.CALC_SUBTOTALS = case when p_Nested_Links = 'YES' then 'Y' else 'N' end
		WHERE ID = p_Report_ID;
		
		DELETE FROM DATA_BROWSER_REPORT_FILTER WHERE DATA_BROWSER_REPORT_PREFS_ID = p_Report_ID;
		INSERT INTO DATA_BROWSER_REPORT_FILTER (DATA_BROWSER_REPORT_PREFS_ID, LINE_NO, FIELD, OPERATOR, EXPRESSION, ACTIVE, LOV_VALUE)
		SELECT p_Report_ID ID, A.SEQ_ID, C001 Field, C002 Operator, C003 Expresson, C004 Enabled, C005 LOV_VALUE
		FROM APEX_COLLECTIONS A 
		WHERE A.COLLECTION_NAME = data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID;

        COMMIT;
    END Save_Report_Preferences;
    
	PROCEDURE Init_Relations_Tree
	IS
	BEGIN 
		data_browser_trees.Reset_Cache;
    END Init_Relations_Tree;

	PROCEDURE Init_Search_Filter ( p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID') )
	is
	begin
		if not(apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID)) then
			Reset_Search_Filter (p_App_Page_ID);
		end if;
	end Init_Search_Filter;	

	PROCEDURE Reset_Search_Filter ( p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID') )
	is
	begin
		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID);
		exception
		  when dup_val_on_index then null;
		end;
		Add_Search_Filter (p_App_Page_ID);
	end Reset_Search_Filter;	
	
	PROCEDURE Add_Search_Filter ( p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID') )
	is
	begin
		APEX_COLLECTION.ADD_MEMBER( 
			p_collection_name => data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID,
			p_c001 => '%',
			p_c002 => 'CONTAINS',
			p_c003 => null,
			p_c004 => 'Y',
			p_c005 => null 
		);
		commit;
	end Add_Search_Filter;

	PROCEDURE Remove_Search_Filter(
		p_SEQ_ID IN NUMBER,
		p_App_Page_ID VARCHAR2 DEFAULT V('APP_PAGE_ID')
	)
	is
	    v_Count PLS_INTEGER;
	begin
		APEX_COLLECTION.DELETE_MEMBER( 
			p_collection_name => data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID,
			p_seq => p_SEQ_ID
		);
		SELECT COUNT(*) INTO v_Count 
		FROM APEX_COLLECTIONS WHERE collection_name = data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID;
		if v_Count = 0 then 
			Add_Search_Filter (p_App_Page_ID);
		end if;
		commit;
	end Remove_Search_Filter;


	PROCEDURE Update_Search_Filter (
		p_SEQ_ID IN NUMBER,
		p_Search_Field IN VARCHAR2,
		p_Search_Operator IN VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Search_LOV IN VARCHAR2,
		p_Search_Active IN VARCHAR2,
		p_App_Page_ID IN VARCHAR2 DEFAULT V('APP_PAGE_ID')
	)
	is
	begin
		APEX_COLLECTION.UPDATE_MEMBER( 
			p_collection_name => data_browser_conf.Get_Filter_Cond_Collection || p_App_Page_ID,
			p_seq => p_SEQ_ID,
			p_c001 => p_SEARCH_FIELD,
			p_c002 => p_SEARCH_OPERATOR,
			p_c003 => p_SEARCH_VALUE,
			p_c004 => p_SEARCH_ACTIVE,
			p_c005 => p_Search_LOV
		);
		COMMIT;
	end Update_Search_Filter;


	PROCEDURE Set_Sort_Preferences (
		p_Table_name IN VARCHAR2,					-- View or Table name
		p_View_Mode IN VARCHAR2,					-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
		-- dependent on table name and view mode --
    	p_Order_by IN VARCHAR2,						-- Example : NAME
    	p_Order_Direction IN VARCHAR2,				-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Control_Break IN VARCHAR2
	)
	is
		v_Path VARCHAR2(1024) :=   '/' || p_Parent_Name || '/' || p_Table_name || '/' || p_View_Mode;
		v_Preferences	VARCHAR2(4000);
	begin
		if p_Table_name IS NOT NULL and p_View_Mode IS NOT NULL then
			v_Preferences := NVL(p_Order_by, 'NULL')||':'||p_Order_Direction||':'||NVL(p_Control_Break, 'NULL');
			APEX_UTIL.SET_PREFERENCE(FN_Pref_Prefix || 'ORDER_BY' || v_Path, v_Preferences);
		end if;
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_view_mode,p_parent_name,p_order_by,p_order_direction,p_control_break;
        end if;
	end Set_Sort_Preferences;

	PROCEDURE Set_Report_Preferences (
		p_Table_name 	IN VARCHAR2,					-- View or Table name
		-- dependent on table name --
    	p_Parent_Name   IN VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
		p_View_Mode 	IN VARCHAR2,					-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		-- dependent on table name and view mode --
    	p_Order_by 		IN VARCHAR2,						-- Example : NAME
    	p_Order_Direction IN VARCHAR2,				-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Join_Options IN VARCHAR2,					-- Example : B;K:C;K:C_B;K:C_C;K:D;K
		p_Rows 			IN NUMBER,							-- 10, 20, 30...
		p_Control_Break IN VARCHAR2,
    	p_Calc_Totals	IN VARCHAR2,
    	p_Nested_Links	IN VARCHAR2,
		p_Select_Columns IN VARCHAR2
	)
	is
	begin
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_parent_name,p_view_mode,p_order_by,p_order_direction,p_join_options,p_rows,p_control_break,p_calc_totals,p_nested_links,p_select_columns;
        end if;
		if p_Table_name IS NOT NULL and p_View_Mode IS NOT NULL then
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'ROWS', NVL(p_Rows, 15));
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'CALC_TOTALS', NVL(p_Calc_Totals, 'YES'));
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'NESTED_LINKS', NVL(p_Nested_Links, 'YES'));
			-- dependent on table name --
			if p_View_Mode NOT IN ('SHOW_HELP', 'ER_DIAGRAM') then 
				APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'VIEW_MODE' || '/' || p_Table_name, p_View_Mode);
			end if;
			-- dependent on table name and view mode --
			if p_Join_Options IS NOT NULL then
				APEX_UTIL.SET_PREFERENCE(FN_Pref_Prefix || 'JOINS' || '/' || p_Table_name || '/' || p_View_Mode, p_Join_Options);
			end if;
			if NULLIF(p_Select_Columns, 'NULL') IS NOT NULL then 
				APEX_UTIL.SET_PREFERENCE(FN_Pref_Prefix || 'SELECT_COLUMNS' || '/' || p_Table_name || '/' || p_View_Mode, NULLIF(p_Select_Columns, 'NULL'));
			else
				APEX_UTIL.REMOVE_PREFERENCE(FN_Pref_Prefix || 'SELECT_COLUMNS' || '/' || p_Table_name || '/' || p_View_Mode);
			end if;
			data_browser_utl.Set_Sort_Preferences(
				p_Table_name => p_Table_name,
				p_Parent_Name => p_Parent_Name,
				p_View_Mode => p_View_Mode,
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Control_Break => p_Control_Break
			);
		end if;
	end Set_Report_Preferences;

	PROCEDURE Set_Report_View_Mode_Prefs (
		p_Table_name IN VARCHAR2,					-- View or Table name
		-- dependent on table name --
		p_View_Mode IN VARCHAR2						-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
	)
	is
		v_View_Mode VARCHAR2(50);
	begin
		if p_Table_name IS NOT NULL and p_View_Mode NOT IN ('SHOW_HELP', 'ER_DIAGRAM') then
			-- dependent on table name --
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'VIEW_MODE' || '/' || p_Table_name, v_View_Mode);
		end if;
	end Set_Report_View_Mode_Prefs;

	PROCEDURE Set_Rows_Preference (p_Rows IN VARCHAR2)
	is
	begin
		if p_Rows IS NOT NULL then
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'ROWS', p_Rows);
		end if;
	end Set_Rows_Preference;

	PROCEDURE Set_Calc_Total_Preference (p_Calc_Totals IN VARCHAR2)
	is
	begin
		if p_Calc_Totals IS NOT NULL then
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'CALC_TOTALS', p_Calc_Totals);
		end if;
	end Set_Calc_Total_Preference;

	PROCEDURE Set_Nested_Links_Preference (p_Nested_Links IN VARCHAR2)
	is
	begin
		if p_Nested_Links IS NOT NULL then
			APEX_UTIL.SET_PREFERENCE(Fn_Pref_Page_Prefix || 'NESTED_LINKS', p_Nested_Links);
		end if;
	end Set_Nested_Links_Preference;

	PROCEDURE Set_Columns_Preference (
		p_Table_name IN VARCHAR2,		
		p_View_Mode IN VARCHAR2,
		-- dependent on table name --
		p_Select_Columns IN VARCHAR2,
		p_Join_Options IN VARCHAR2					-- Example : B;K:C;K:C_B;K:C_C;K:D;K
	)
	is
	begin
		if p_Table_name IS NOT NULL and p_Select_Columns IS NOT NULL then
			-- dependent on table name and view mode --
			APEX_UTIL.SET_PREFERENCE(FN_Pref_Prefix || 'SELECT_COLUMNS' || '/' || p_Table_name || '/' || p_View_Mode, NULLIF(p_Select_Columns, 'NULL'));
			APEX_UTIL.SET_PREFERENCE(FN_Pref_Prefix || 'JOINS' || '/' || p_Table_name || '/' || p_View_Mode, p_Join_Options);
		end if;
	end Set_Columns_Preference;

	FUNCTION Hide_Select_Column (
		p_Table_Name VARCHAR2,
		p_Column_Name VARCHAR2,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Expression		VARCHAR2(256);
		v_Select_Columns 	CLOB;
	BEGIN
		v_Select_Columns := APEX_UTIL.GET_PREFERENCE(FN_Pref_Prefix || 'SELECT_COLUMNS' || '/' || p_Table_name || '/' || p_View_Mode);
		if v_Select_Columns IS NULL then 
			v_Select_Columns := data_browser_utl.Get_Default_Select_Columns ( 
				p_Table_Name => p_Table_Name, 
				p_View_Mode => p_View_Mode, 
				p_Edit_Mode => p_Edit_Mode,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible
			);
		end if;
		v_Select_Columns := FN_Terminate_List(v_Select_Columns);
		v_Expression := FN_Terminate_List(p_Column_Name);
		v_Select_Columns := TRIM(':' FROM REPLACE(v_Select_Columns, v_Expression, ':'));
		data_browser_utl.Set_Columns_Preference (
			p_Table_Name => p_Table_Name, 
			p_View_Mode => p_View_Mode, 
			p_Select_Columns => v_Select_Columns,
			p_Join_Options => p_Join_Options
		);
		COMMIT;
		return v_Select_Columns;
	END Hide_Select_Column;

	PROCEDURE Reset_Columns_Preference (
		p_Table_name IN VARCHAR2,		
    	p_Parent_Name VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
		p_View_Mode IN VARCHAR2
	)
	is
		v_Path VARCHAR2(1024) :=   '/' || p_Parent_Name || '/' || p_Table_name || '/' || p_View_Mode;
	begin
		if p_Table_name IS NOT NULL and p_View_Mode IS NOT NULL then
			-- dependent on table name and view mode --
			APEX_UTIL.REMOVE_PREFERENCE(FN_Pref_Prefix || 'JOINS' || '/' || p_Table_name || '/' || p_View_Mode);
			APEX_UTIL.REMOVE_PREFERENCE(FN_Pref_Prefix || 'SELECT_COLUMNS' || '/' || p_Table_name || '/' || p_View_Mode);
			APEX_UTIL.REMOVE_PREFERENCE(FN_Pref_Prefix || 'ORDER_BY' || v_Path);
		end if;
	end Reset_Columns_Preference;

	PROCEDURE Reset_All_Column_Preferences (
		p_Owner VARCHAR2 DEFAULT V('OWNER'),
    	p_Application_ID NUMBER DEFAULT NV('APP_ID'),
		p_Page_ID NUMBER DEFAULT 30
	)
	is 
		v_View_Modes CONSTANT VARCHAR2(500) := 'FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW, CALENDAR, TREE_VIEW, HISTORY';
		v_Prefs_prefix VARCHAR2(1024);
	begin 
		v_Prefs_prefix := Fn_Pref_Page_Prefix(p_Owner, p_Application_ID, p_Page_ID);
		for p_cur in (
			select VIEW_NAME, R_VIEW_NAME, VIEW_MODE
			from MVDATA_BROWSER_REFERENCES
			, (select column_value VIEW_MODE from apex_string.split(v_View_Modes, ', ')) 
		) loop 
			data_browser_utl.Reset_Columns_Preference (
				p_Table_name => p_cur.VIEW_NAME,		
				p_Parent_Name => p_cur.R_VIEW_NAME,
				p_View_Mode => p_cur.VIEW_MODE
			);
		end loop;
		for p_cur in (
			select VIEW_NAME, VIEW_MODE
			from MVDATA_BROWSER_VIEWS
			, (select column_value VIEW_MODE from apex_string.split(v_View_Modes, ', ')) 
		) loop 
			data_browser_utl.Reset_Columns_Preference (
				p_Table_name => p_cur.VIEW_NAME,		
				p_View_Mode => p_cur.VIEW_MODE
			);
			if p_cur.VIEW_MODE = 'FORM_VIEW' then
				APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'CONSTRAINT_NAME' || '/' || p_cur.VIEW_NAME);
				APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'VIEW_MODE' || '/' || p_cur.VIEW_NAME);
			end if;
			APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'CALC_TOTALS');
			APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'NESTED_LINKS');
			APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'SEARCH_TABLE');
			APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'TABLE_NAME');
			APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'TABLE_VIEW_MODE');
			APEX_UTIL.REMOVE_PREFERENCE(v_Prefs_prefix || 'ROWS');
		end loop;
	end Reset_All_Column_Preferences;

	PROCEDURE Set_Parent_Key_Preference (
		p_Table_name IN VARCHAR2,		
		p_View_Mode IN VARCHAR2,
		-- dependent on table name --
		p_Parent_Key_Visible IN VARCHAR2
	)
	is
	begin
		if p_Table_name IS NOT NULL and p_Parent_Key_Visible IS NOT NULL then
			-- dependent on table name and view mode --
			APEX_UTIL.SET_PREFERENCE(FN_Pref_Prefix || 'PARENT_KEY_VISIBLE' || '/' || p_Table_name, p_Parent_Key_Visible);
		end if;
	end Set_Parent_Key_Preference;

	FUNCTION Get_Record_View_Query ( 					-- External : Form Query for tabular forms and reports
		p_Table_name IN VARCHAR2,						-- ===================================================
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value IN VARCHAR2,
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',		-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
    	p_Control_Break  VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Compact_Queries VARCHAR2 DEFAULT 'YES', 		-- Generate Compact Queries to avoid overflow errors
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW, CALENDAR, TREE_VIEW
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 			-- YES, NO
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 		-- NEW_ROWS, TABLE, MEMORY, COLLECTION. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Data_Format VARCHAR2 DEFAULT data_browser_select.FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Empty_Row VARCHAR2 DEFAULT 'YES',				-- YES, NO. Show one empty row when the result set is empty.
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT NV('APP_PAGE_ID'),	-- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW. Example: P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_DETAIL_TABLE,P32_DETAIL_KEY
    	p_Detail_Page_ID NUMBER DEFAULT 32,				-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,		-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,				-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Form_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_File_Page_ID NUMBER DEFAULT 31,				-- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,		-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_Search_Column_Name VARCHAR2 DEFAULT NULL,		-- Example : NAME
    	p_Search_Operator VARCHAR2 DEFAULT 'CONTAINS',	-- =,!=,IS NULL,IS NOT NULL,LIKE,NOT LIKE,IN,NOT IN,CONTAINS,NOT CONTAINS,REGEXP
    	p_Search_Field_Item VARCHAR2 DEFAULT NULL,		-- Example : P30_SEARCH
    	p_Search_Filter_Page_ID NUMBER DEFAULT NV('APP_PAGE_ID'),
    	p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : NAME
    	p_Order_Direction VARCHAR2 DEFAULT 'ASC',		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
    	p_Calc_Totals  VARCHAR2 DEFAULT 'NO',		-- YES, NO
    	p_Nested_Links VARCHAR2 DEFAULT 'NO',			-- YES, NO use nested table view instead of p_Link_Page_ID, p_Link_Parameter
    	p_Source_Query CLOB DEFAULT NULL 				-- Passed query for from clause
	) RETURN CLOB
	is
        v_Table_Name 				MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
    	v_Row_Locked_Column_Name 	MVDATA_BROWSER_VIEWS.ROW_LOCKED_COLUMN_NAME%TYPE;
    	v_Row_Locked_Column_Type	VARCHAR2(20);
		v_Unique_Key_Column  		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE := p_Unique_Key_Column;
		v_Ordering_Column_Name		MVDATA_BROWSER_VIEWS.ORDERING_COLUMN_NAME%TYPE;
		v_Ordering_Column_Tool		VARCHAR2(10);
		v_Unique_Key_Expr	VARCHAR2(1024);
		v_Search_Item		VARCHAR2(4000) := ':search_value';
        v_Parent_Table		VARCHAR2(128);
        v_Parent_Key_Column VARCHAR2(128);
        v_Parent_Key_Nullable VARCHAR2(128);
        v_Parent_Key_Visible VARCHAR2(10);
        v_Search_Column_Name VARCHAR2(128);
        v_Search_Field_Item VARCHAR2(128);
        v_Search_Condition	VARCHAR2(32767);
        v_Filter_Condition	VARCHAR2(32767);
        v_Inner_Condition	VARCHAR2(32767);
        v_Use_Inner_Order	BOOLEAN;
        v_Order_by 			VARCHAR2(32767);
        v_Calc_Totals		VARCHAR2(10);
        v_Sub_Totals_Groups VARCHAR2(32767);
        v_Inner_Order_by	VARCHAR2(32767);
        v_Outer_Order_by	VARCHAR2(32767);
        v_Outer_Condition	VARCHAR2(32767);
        v_Final_Condition	VARCHAR2(32767);
		v_Record_View_Query	CLOB;
		v_Sub_Query			CLOB;
		v_Array_Row_Count 	PLS_INTEGER := 0;
		v_New_Rows			VARCHAR2(255) := data_browser_conf.Get_New_Rows_Default;
		v_Offset			PLS_INTEGER;
		v_Apex_Item_Rows_Call VARCHAR2(255);
		v_Primary_Key_Call VARCHAR2(1024);
		v_Data_Source		VARCHAR2(50);
		v_Data_Source2		VARCHAR2(50);
		v_Edit_Mode			VARCHAR2(10);
		v_Exclude_Audit_Columns VARCHAR2(10);
		v_has_outer_cond    BOOLEAN; 
		v_has_one_empty_row BOOLEAN; 
		v_has_multi_empty_row BOOLEAN; 
		v_has_locked_rows   BOOLEAN; 
		v_build_subquery	BOOLEAN; 
	begin
		data_browser_conf.Set_Generate_Compact_Queries(p_Compact_Queries);
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_unique_key_column,p_search_value,p_data_columns_only,p_select_columns,p_control_break,p_columns_limit,p_compact_queries,p_view_mode,p_report_mode,p_edit_mode,p_data_source,p_data_format,p_empty_row,p_join_options,p_parent_table,p_parent_key_column,p_parent_key_item,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_form_page_id,p_form_parameter,p_file_page_id,p_text_editor_page_id,p_text_tool_selector,p_search_column_name,p_search_operator,p_search_field_item,p_search_filter_page_id,p_order_by,p_order_direction,p_calc_totals,p_nested_links,p_source_query;
        end if;
		if p_Table_name IS NULL then 
			return 'SELECT NULL X FROM DUAL';
		elsif p_View_Mode = 'CALENDAR' then
			return data_browser_select.Get_Calendar_Query (
				p_Table_Name => p_Table_name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Item => p_Parent_Key_Item
			);
		elsif p_View_Mode = 'TREE_VIEW' then
			return data_browser_select.Get_Tree_Query (
				p_Table_Name => p_Table_name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Item => p_Parent_Key_Item
			);
		elsif p_View_Mode = 'HISTORY' and p_Source_Query IS NULL then
			return 'SELECT NULL X FROM DUAL';
		end if;
		
		v_Edit_Mode := case 
			when p_Data_Format != 'FORM' or p_View_Mode = 'HISTORY'
				then 'NO' 
			when p_Edit_Mode = 'YES' 
				then 'YES'
			else 'NO' end;
		v_Data_Source := case 
			when p_Data_Source = 'NEW_ROWS' and v_Edit_Mode = 'NO' 
				then 'TABLE' else NVL(p_Data_Source, 'TABLE') 
			end;
		v_Exclude_Audit_Columns := case 
			when p_Data_Source = 'NEW_ROWS' 
				and v_Edit_Mode = 'YES' 
				and p_Report_Mode = 'NO' 
			then 'YES' else 'NO' end;
    	SELECT NVL(v_Unique_Key_Column, T.SEARCH_KEY_COLS),
    		T.ROW_LOCKED_COLUMN_NAME,
			C.YES_NO_COLUMN_TYPE,
			ORDERING_COLUMN_NAME
    	INTO v_Unique_Key_Column, v_Row_Locked_Column_Name, v_Row_Locked_Column_Type, v_Ordering_Column_Name
    	FROM MVDATA_BROWSER_VIEWS T
    	LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C ON T.VIEW_NAME = C.VIEW_NAME AND T.ROW_LOCKED_COLUMN_NAME = C.COLUMN_NAME
    	WHERE T.VIEW_NAME = v_Table_Name;
		v_Ordering_Column_Tool := 'YES';
		if p_Parent_Table IS NOT NULL then
			begin
				SELECT R_VIEW_NAME, COLUMN_NAME, FK_NULLABLE
				INTO v_Parent_Table, v_Parent_Key_Column, v_Parent_Key_Nullable
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = p_Parent_Table
				AND COLUMN_NAME = NVL(p_Parent_Key_Column, COLUMN_NAME)
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;
		v_Parent_Key_Visible := case when p_Parent_Key_Visible IN ('YES', 'NO') then p_Parent_Key_Visible else 'NO' end;
		v_Unique_Key_Expr 		:= v_Unique_Key_Column;
		if v_Data_Source NOT IN('MEMORY', 'NEW_ROWS') then
			if v_Data_Source = 'COLLECTION' then 
				v_Unique_Key_Expr := 'SEQ_ID';
			elsif INSTR(v_Unique_Key_Column,',') > 0 then
			-- when table has no primary key, then p_Search_Value is the value of ROWIDTOCHAR(ROWID)
				v_Unique_Key_Expr := 'A.ROWID';
			else
				v_Unique_Key_Expr := data_browser_conf.Get_Link_ID_Expression(
					p_Unique_Key_Column=> v_Unique_Key_Column, p_Table_Alias=> 'A', p_View_Mode=> p_View_Mode);
			end if;
			if v_Unique_Key_Expr IS NOT NULL and p_Search_Value IS NOT NULL then
				-- restrict to single row --
				v_Inner_Condition := data_browser_conf.Build_Condition(v_Inner_Condition, v_Unique_Key_Expr || ' = ' || v_Search_Item);
			end if;
		end if;
		if v_Parent_Key_Column IS NOT NULL 
		and p_Parent_Key_Item IS NOT NULL and V(p_Parent_Key_Item) IS NOT NULL
		and v_Data_Source NOT IN ('NEW_ROWS', 'COLLECTION') and p_Report_Mode = 'YES' then
			if p_View_Mode = 'HISTORY' then
				v_Parent_Key_Nullable := 'N';
			end if;
			v_Inner_Condition := data_browser_conf.Build_Parent_Key_Condition ( -- restrict to set of rows
				p_Condition => v_Inner_Condition,
				p_Parent_Key_Column => data_browser_conf.Get_Foreign_Key_Expression(p_Foreign_Key_Column => v_Parent_Key_Column, p_Table_Alias => 'A'),
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Parent_Key_Visible => p_Parent_Key_Visible,
				p_Parent_Key_Nullable => v_Parent_Key_Nullable
			);
			if p_View_Mode = 'HISTORY' then	-- restrict second data source
				v_Inner_Condition := data_browser_conf.Build_Parent_Key_Condition ( -- restrict to set of rows
					p_Condition => v_Inner_Condition,
					p_Parent_Key_Column => data_browser_conf.Get_Foreign_Key_Expression(p_Foreign_Key_Column => v_Parent_Key_Column, p_Table_Alias => 'B'),
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Nullable => v_Parent_Key_Nullable
				);
				-- prepare for use as outer join condition
				v_Inner_Condition := chr(10) || 'AND' || SUBSTR(v_Inner_Condition, INSTR(v_Inner_Condition, ' ')) || chr(10)
				|| 'WHERE NVL(A.' || v_Parent_Key_Column ||',B.' || v_Parent_Key_Column 
				||') = V(' -- in history views only numeric references are used.
				|| data_browser_conf.Enquote_Literal(p_Parent_Key_Item) || ')';
			end if;
		end if;
		if v_Data_Source NOT IN ('NEW_ROWS') and p_Report_Mode = 'YES' then
			if (APEX_UTIL.GET_SESSION_STATE(p_Search_Field_Item) is not null 
				or (p_Search_Operator IN ('IS NULL','IS NOT NULL') and p_Search_Column_Name IS NOT NULL )) then
				v_Search_Column_Name := p_Search_Column_Name;
				v_Search_Field_Item := 'V(' || data_browser_conf.Enquote_Literal(p_Search_Field_Item) || ')';
				v_Search_Condition :=
					data_browser_utl.Get_Form_View_Text_Search(
						p_Table_name => p_Table_name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_Search_Field_Item => v_Search_Field_Item,
						p_Search_Column_Name => v_Search_Column_Name,
						p_Search_Operator => p_Search_Operator,
						p_Data_Columns_Only => p_Data_Columns_Only,
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => p_Report_Mode,
						p_Edit_Mode => v_Edit_Mode,
						p_Data_Source => v_Data_Source,
						p_Join_Options => p_Join_Options,
						p_Parent_Name => v_Parent_Table,
						p_Parent_Key_Column => v_Parent_Key_Column,
						p_Parent_Key_Visible => v_Parent_Key_Visible
					);
				v_Inner_Condition := data_browser_conf.Build_Condition(v_Inner_Condition, v_Search_Condition);
			end if;

			v_Search_Condition :=
				data_browser_utl.Get_Form_Search_Cond(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Data_Columns_Only => p_Data_Columns_Only,
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => p_Report_Mode,
					p_Edit_Mode => v_Edit_Mode,
					p_Data_Source => v_Data_Source,
					p_Join_Options => p_Join_Options,
					p_Parent_Name => v_Parent_Table,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_App_Page_ID => p_Search_Filter_Page_ID,
					p_Search_Field_Item => v_Search_Field_Item,
					p_Search_Column_Name => v_Search_Column_Name
				);
			v_Inner_Condition := data_browser_conf.Build_Condition(v_Inner_Condition, v_Search_Condition);			
		end if;

		-- preconditions: subquery has to deliver native values, sorting is done on subquery column names.
		v_Calc_Totals := case when p_Calc_Totals IN ('YES', 'NO') then p_Calc_Totals else 'NO'end;
		if v_Calc_Totals = 'YES'
		and v_Edit_Mode = 'NO' 		-- problem: in the totals-lines all form field have to be null values
		and p_Report_Mode = 'YES' 
		and v_Data_Source = 'TABLE'
		and p_View_Mode IN ('FORM_VIEW', 'RECORD_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW') then 
			v_Sub_Totals_Groups := data_browser_utl.Get_Sub_Totals_Grouping(
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_Control_Break => p_Control_Break,
				p_Order_by => p_Order_by,
				p_View_Mode => p_View_Mode,
				p_Data_Format => p_Data_Format,
				p_Join_Options => p_Join_Options,
				p_Parent_Table => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Nested_Links => p_Nested_Links
			);
		end if;
		if v_Sub_Totals_Groups IS NULL then 
			v_Calc_Totals := 'NO';
		end if;

		if p_Order_by IS NOT NULL and p_Report_Mode = 'YES' and v_Data_Source IN ('TABLE', 'NEW_ROWS', 'COLLECTION', 'QUERY') then
			v_Use_Inner_Order := true;
			v_Order_by := data_browser_utl.Get_Order_by_Clause ( 
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Join_Options => p_Join_Options,
				p_Edit_Mode => v_Edit_Mode,
				p_Data_Source => v_Data_Source,
				p_Data_Format => p_Data_Format,
				p_Parent_Table => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Order_by => p_Order_by,
				p_Order_Direction => p_Order_Direction,
				p_Control_Break => p_Control_Break,
				p_Calc_Totals => v_Calc_Totals
			);
			if v_Order_by IS NOT NULL then
				if v_Use_Inner_Order then
					v_Inner_Order_by := chr(10) || 'ORDER BY ' || v_Order_by;
				else -- use outer condition because foreign key columns are subquerys that deliver description text
					v_Outer_Order_by := chr(10) || 'ORDER BY ' || v_Order_by;
				end if;
			end if;
		end if;

		$IF data_browser_conf.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_utl.Get_Record_View_Query (v_Inner_Order_by=> %s, v_Outer_Order_by=> %s, v_Array_Row_Count => %s, p_Data_Source => %s ',
				p0 => v_Inner_Order_by,
				p1 => v_Outer_Order_by,
				p2 => v_Array_Row_Count,
				p3 => v_Data_Source
			);
		$END

		if p_Report_Mode = 'YES' and v_Edit_Mode = 'YES' then
			-- Limit the number for rows for tabular forms, because sorting form fields is slow.
			v_Outer_Condition := data_browser_conf.Build_Condition(v_Outer_Condition, 'ROWNUM <= ' || data_browser_conf.Get_Edit_Rows_Limit);
		end if;

		v_has_one_empty_row := (p_Empty_Row = 'YES' and p_Report_Mode = 'YES' 
								and v_Edit_Mode = 'NO' and v_Data_Source = 'TABLE'
								and p_Data_Columns_Only = 'NO');
		v_has_locked_rows   := (v_Data_Source != 'COLLECTION'
								and v_Row_Locked_Column_Name IS NOT NULL and v_Row_Locked_Column_Type IS NOT NULL
								and v_Edit_Mode = 'YES' and p_Report_Mode = 'YES');
		v_has_multi_empty_row := ((v_Data_Source = 'NEW_ROWS' or p_Empty_Row = 'YES')
								and p_Report_Mode = 'YES' and v_Edit_Mode = 'YES');
		v_has_outer_cond    := (v_Outer_Condition IS NOT NULL or v_Outer_Order_by IS NOT NULL);

		v_build_subquery	:= (v_Data_Source = 'TABLE' and v_Edit_Mode = 'YES' and v_Inner_Order_by IS NOT NULL);
		v_Data_Source2 := v_Data_Source;

		if v_has_locked_rows then
			v_Final_Condition := data_browser_conf.Build_Condition(v_Inner_Condition, 'A.' || v_Row_Locked_Column_Name
			|| ' = ' || data_browser_conf.Get_Boolean_No_Value(v_Row_Locked_Column_Type, 'ENQUOTE') )
			|| CM('/* select unprotected rows in edit mode */');
			v_Filter_Condition := v_Inner_Condition;
		else
			v_Final_Condition := v_Inner_Condition;
		end if;

		if v_Edit_Mode = 'NO' or v_build_subquery then
			v_Record_View_Query := data_browser_utl.Get_Detail_View_Query(
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Control_Break => p_Control_Break,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Edit_Mode => v_Edit_Mode,
				p_Data_Source => case when v_build_subquery then 'QUERY' else v_Data_Source end,
				p_Data_Format => p_Data_Format,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Link_Page_ID => p_Link_Page_ID,
				p_Link_Parameter => p_Link_Parameter,
				p_Detail_Page_ID => p_Detail_Page_ID,
				p_Detail_Parameter => p_Detail_Parameter,
				p_Form_Page_ID => p_Form_Page_ID,
				p_Form_Parameter => p_Form_Parameter,
				p_File_Page_ID => p_File_Page_ID,
				p_Search_Column_Name => v_Search_Column_Name,
				p_Search_Field_Item => v_Search_Field_Item,
				p_Calc_Totals => v_Calc_Totals,
				p_Nested_Links => p_Nested_Links,
				p_Source_Query => p_Source_Query,
				p_Comments => case when v_build_subquery then '/* read from subquery */'  end
			);
		end if;

		if v_Edit_Mode = 'YES' then
			if v_Record_View_Query IS NOT NULL then 
				v_Record_View_Query := INDENT( 
					v_Record_View_Query
					|| v_Final_Condition
					|| v_Sub_Totals_Groups
					|| v_Inner_Order_by 
					|| CM('/* perform early ordering */')
				);
				v_Final_Condition := NULL;
				v_Inner_Condition := NULL;
				v_Sub_Totals_Groups := NULL;
				v_Inner_Order_by := NULL;
			end if;
			if v_Data_Source = 'NEW_ROWS' and p_Report_Mode = 'NO' then 
				v_Data_Source2 := 'NEW_ROWS'; 	-- setup for single empty row with default values
			elsif v_Data_Source = 'NEW_ROWS' and p_Report_Mode = 'YES' then 
				v_Data_Source2 := 'TABLE'; -- load existing rows, new rows will be appended later
			end if;
			v_Record_View_Query := data_browser_edit.Get_Form_Edit_Query(
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Data_Source => v_Data_Source2,
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Exclude_Audit_Columns => v_Exclude_Audit_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Ordering_Column_Tool => v_Ordering_Column_Tool,
				p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
				p_Text_Tool_Selector => p_Text_Tool_Selector,
				p_Link_Page_ID => p_Link_Page_ID,
				p_Link_Parameter => p_Link_Parameter,
				p_Detail_Page_ID => p_Detail_Page_ID,
				p_Detail_Parameter => p_Detail_Parameter,
				p_Form_Page_ID => p_Form_Page_ID,
				p_Form_Parameter => p_Form_Parameter,
				p_File_Page_ID => p_File_Page_ID,
				p_Source_Query => v_Record_View_Query,
				p_Comments => case when v_Data_Source = 'NEW_ROWS' and p_Report_Mode = 'NO'
										then '/* setup for single empty row with default values */'
									when v_Data_Source = 'NEW_ROWS' and p_Report_Mode = 'YES'
										then '/* load existing rows */'
									else '/* load data source ' || v_Data_Source2 || ' */'
								end,
				p_Row_Count => v_Array_Row_Count,
				p_Apex_Item_Rows_Call => v_Apex_Item_Rows_Call,
				p_Primary_Key_Call => v_Primary_Key_Call
			);
			if (v_Data_Source = 'MEMORY' or v_Array_Row_Count > 0)
			and p_Report_Mode = 'YES' and v_Edit_Mode = 'YES' then
				v_Data_Source2 := 'MEMORY';
				-- submitted rows found in apex_application.g_fXX array
				-- the query will access the array instead of blank rows with default values
				v_Record_View_Query := data_browser_edit.Get_Form_Edit_Query(
					p_Table_name => v_Table_name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Data_Source => 'MEMORY',  -- show submitted rows for memory
					p_Data_Columns_Only => p_Data_Columns_Only,
					p_Select_Columns => p_Select_Columns,
					p_Exclude_Audit_Columns => 'NO',
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => p_Report_Mode,
					p_Join_Options => p_Join_Options,
					p_Parent_Name => v_Parent_Table,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_Ordering_Column_Tool => v_Ordering_Column_Tool,
					p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
					p_Text_Tool_Selector => p_Text_Tool_Selector,
					p_Link_Page_ID => p_Link_Page_ID,
					p_Link_Parameter => p_Link_Parameter,
					p_Detail_Page_ID => p_Detail_Page_ID,
					p_Detail_Parameter => p_Detail_Parameter,
					p_Form_Page_ID => p_Form_Page_ID,
					p_Form_Parameter => p_Form_Parameter,
					p_File_Page_ID => p_File_Page_ID,
					p_Comments => '/* load data source ' || v_Data_Source2 || '*/',
					p_Row_Count => v_Array_Row_Count,
					p_Apex_Item_Rows_Call => v_Apex_Item_Rows_Call,
					p_Primary_Key_Call => v_Primary_Key_Call
				)
				|| ' CONNECT BY LEVEL <= ' || NVL(v_Apex_Item_Rows_Call, 1);
				return v_Record_View_Query;
				--------------------------------------------------------
			end if;
		end if; -- p_Edit_Mode = 'YES'

		if v_Inner_Order_by IS NOT NULL 
		and (v_has_one_empty_row or v_has_multi_empty_row or v_has_outer_cond) then
			v_Record_View_Query := 'SELECT * FROM (' || CM('/* perform early ordering */')
				|| INDENT( v_Record_View_Query
				|| v_Final_Condition
				|| v_Sub_Totals_Groups
				|| v_Inner_Order_by)
				|| ') A ';
		elsif v_Final_Condition IS NOT NULL or v_Sub_Totals_Groups IS NOT NULL or v_Inner_Order_by IS NOT NULL then
			v_Record_View_Query := v_Record_View_Query 
				|| v_Final_Condition
				|| v_Sub_Totals_Groups
				|| v_Inner_Order_by;
		end if;

		-- add empty or buffered rows
		if v_has_one_empty_row and v_Record_View_Query IS NOT NULL then
				-- add an empty row to the result when not data was found
			v_Record_View_Query := 'SELECT * FROM ( ' || 
				INDENT(v_Record_View_Query
				|| chr(10)
				|| 'UNION ALL' 
				|| chr(10)
				|| data_browser_utl.Get_Detail_View_Query(
					p_Table_name => v_Table_name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Data_Columns_Only => p_Data_Columns_Only,
					p_Select_Columns => p_Select_Columns,
					p_Control_Break => p_Control_Break,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => p_Report_Mode,
					p_Edit_Mode => v_Edit_Mode,
					p_Data_Source => 'NEW_ROWS',
					p_Data_Format => p_Data_Format,
					p_Join_Options => p_Join_Options,
					p_Parent_Name => v_Parent_Table,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_Link_Page_ID => p_Link_Page_ID,
					p_Link_Parameter => p_Link_Parameter,
					p_Detail_Page_ID => p_Detail_Page_ID,
					p_Detail_Parameter => p_Detail_Parameter,
					p_Form_Page_ID => p_Form_Page_ID,
					p_Form_Parameter => p_Form_Parameter,
					p_File_Page_ID => p_File_Page_ID,
					p_Comments => '/* Show at least one empty row */'
				))
			|| ')' 
			|| case when v_Calc_Totals = 'NO' then 
				data_browser_conf.Build_Condition(NULL, '( LINK_ID$ IS NOT NULL OR ROWNUM = 1 )') 
			end;
		end if;
		if v_has_locked_rows then
			-- select locked rows in read only mode --
			v_Final_Condition := data_browser_conf.Build_Condition(v_Filter_Condition, 'A.' || v_Row_Locked_Column_Name
			|| ' = ' || data_browser_conf.Get_Boolean_Yes_Value(v_Row_Locked_Column_Type, 'ENQUOTE') );
			v_Record_View_Query :=
				'SELECT * FROM (' 
				|| INDENT(v_Record_View_Query
				|| chr(10)
				|| 'UNION ALL'
				|| chr(10)
				|| 'SELECT * FROM (' || CM('/* select protected rows in read only mode */')
				|| INDENT(
					data_browser_utl.Get_Detail_View_Query(
						p_Table_name => v_Table_name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_Data_Columns_Only => p_Data_Columns_Only,
						p_Select_Columns => p_Select_Columns,
						p_Control_Break => p_Control_Break,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => p_Report_Mode,
						p_Edit_Mode => v_Edit_Mode,
						p_Data_Source => 'TABLE',
						p_Data_Format => p_Data_Format,
						p_Join_Options => p_Join_Options,
						p_Parent_Name => v_Parent_Table,
						p_Parent_Key_Column => v_Parent_Key_Column,
						p_Parent_Key_Visible => v_Parent_Key_Visible,
						p_Link_Page_ID => p_Link_Page_ID,
						p_Link_Parameter => p_Link_Parameter,
						p_Detail_Page_ID => p_Detail_Page_ID,
						p_Detail_Parameter => p_Detail_Parameter,
						p_Form_Page_ID => p_Form_Page_ID,
						p_Form_Parameter => p_Form_Parameter,
						p_File_Page_ID => p_File_Page_ID,
						p_Search_Column_Name => v_Search_Column_Name,
						p_Search_Field_Item => v_Search_Field_Item
					)
					|| v_Final_Condition
					|| v_Inner_Order_by
				)
				|| ') A '
				)
				|| ') A ';
		end if;
		if v_has_outer_cond then
			v_Record_View_Query := INDENT('SELECT * FROM (' 
				|| INDENT(v_Record_View_Query)
				|| ') A '
				|| v_Outer_Condition 
				|| v_Outer_Order_by);
		end if;
		if v_has_multi_empty_row then
			v_Sub_Query := data_browser_edit.Get_Form_Edit_Query(
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Data_Source => 'NEW_ROWS', -- setup for multiple blank rows with default values
				p_Data_Columns_Only => p_Data_Columns_Only,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_Exclude_Audit_Columns => 'NO',
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => v_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Ordering_Column_Tool => v_Ordering_Column_Tool,
				p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
				p_Text_Tool_Selector => p_Text_Tool_Selector,
				p_Link_Page_ID => p_Link_Page_ID,
				p_Link_Parameter => p_Link_Parameter,
				p_Detail_Page_ID => p_Detail_Page_ID,
				p_Detail_Parameter => p_Detail_Parameter,
				p_Form_Page_ID => p_Form_Page_ID,
				p_Form_Parameter => p_Form_Parameter,
				p_File_Page_ID => p_File_Page_ID,
				p_Comments => case 
								when v_has_one_empty_row then '/* Show at least one empty row */'
								when v_has_multi_empty_row then '/* multiple blank rows with default values */' 
							end,
				p_Row_Count => v_Array_Row_Count,
				p_Apex_Item_Rows_Call => v_Apex_Item_Rows_Call,
				p_Primary_Key_Call => v_Primary_Key_Call
			);
			if p_Empty_Row = 'YES' and v_Data_Source IN ('TABLE', 'COLLECTION') then
				v_Record_View_Query :=
				'SELECT * FROM ('
				|| INDENT('SELECT * FROM (' 
					|| v_Record_View_Query
					|| ') A '
					|| chr(10)
					|| 'UNION ALL' || chr(10)
					|| v_Sub_Query
					)
				|| ') A '
				|| data_browser_conf.Build_Condition(NULL, '( LINK_ID$ IS NOT NULL OR ROWNUM = 1 )')
				|| chr(10);
			else
				v_Record_View_Query := v_Sub_Query
				|| case when v_Data_Source = 'NEW_ROWS' then
					' CONNECT BY LEVEL <= ' || v_New_Rows 
				end
				|| chr(10)
				|| 'UNION ALL' || chr(10)
				|| 'SELECT * FROM (' 
				|| v_Record_View_Query
				|| ')' || chr(10);
			end if;

		end if;

		$IF data_browser_conf.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_utl.Get_Record_View_Query - Result-Size (%s) : ',
				p0 => DBMS_LOB.GETLENGTH(v_Record_View_Query),
				p_max_length => 3500
			);
			v_Offset := 1;
			if v_Record_View_Query IS NOT NULL then 
				for i IN 1 .. (DBMS_LOB.GETLENGTH(v_Record_View_Query) / 3000) + 1 loop
					apex_debug.info(
						p_message => '%s',
						p0 => DBMS_LOB.SUBSTR(v_Record_View_Query, 3000, v_Offset),
						p_max_length => 4000
					);
					v_Offset := v_Offset + 3000;
				end loop;
			end if;
		$END

		return v_Record_View_Query;
	exception
	  when no_data_found then
	  return 'SELECT NULL X FROM DUAL';
	end Get_Record_View_Query;

	FUNCTION Get_Record_Data_Cursor (					-- External : View Record Information
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit VARCHAR2 DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
    	p_File_Page_ID NUMBER DEFAULT 31,				-- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,		-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR'
	)
	RETURN data_browser_conf.tab_record_edit PIPELINED
	is
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Query 		CLOB;
		v_Search_Value	VARCHAR2(4000) := p_Search_Value;
		v_Unique_Key_Column VARCHAR2(4000);
        v_Data_Source		VARCHAR2(10);
        v_Parent_Key_Column VARCHAR2(128);
        CURSOR form_view_cur
        IS
        	SELECT B.COLUMN_NAME, B.TABLE_ALIAS,
        			B.COLUMN_ID, B.POSITION, B.INPUT_ID, B.REPORT_COLUMN_ID, B.DATA_TYPE,
					B.DATA_PRECISION, B.DATA_SCALE, B.CHAR_LENGTH, B.NULLABLE, 
					B.IS_PRIMARY_KEY, B.IS_SEARCH_KEY, B.IS_FOREIGN_KEY, B.IS_DISP_KEY_COLUMN,
					B.REQUIRED, B.HAS_HELP_TEXT, B.HAS_DEFAULT, B.IS_BLOB, B.IS_PASSWORD, 
					B.IS_AUDIT_COLUMN, B.IS_OBFUSCATED, B.IS_UPPER_NAME,
					B.IS_NUMBER_YES_NO_COLUMN, B.IS_CHAR_YES_NO_COLUMN, B.IS_REFERENCE, 
					B.IS_SEARCHABLE_REF, B.IS_SUMMAND, B.IS_VIRTUAL_COLUMN, B.IS_DATETIME,
					B.CHECK_UNIQUE, B.FORMAT_MASK, B.LOV_QUERY, B.DATA_DEFAULT,
					B.COLUMN_ALIGN, B.COLUMN_HEADER, B.COLUMN_EXPR, B.COLUMN_EXPR_TYPE,
					B.APEX_ITEM_EXPR, B.APEX_ITEM_IDX, B.APEX_ITEM_REF, B.ROW_FACTOR, B.ROW_OFFSET, B.APEX_ITEM_CNT,
					B.FIELD_LENGTH, B.DISPLAY_IN_REPORT, A.COLUMN_DATA, 
					B.R_TABLE_NAME, B.R_VIEW_NAME, B.R_COLUMN_NAME,
					B.REF_TABLE_NAME, B.REF_VIEW_NAME, B.REF_COLUMN_NAME, B.COMMENTS
			FROM
			TABLE ( data_browser_edit.Get_Form_Edit_Cursor (
					p_Table_name => v_Table_Name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Data_Columns_Only => 'YES',
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_Join_Options => p_Join_Options,
					p_View_Mode => p_View_Mode,
					p_Data_Source => v_Data_Source,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_File_Page_ID => p_File_Page_ID,
					p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
					p_Text_Tool_Selector => p_Text_Tool_Selector
				)
			) B
			LEFT OUTER JOIN TABLE (
				data_browser_utl.column_value_list (
						p_Query => v_Query,
						p_Search_Value => v_Search_Value,
						p_Exact => 'NO'
					)
			) A ON A.COLUMN_NAME = B.COLUMN_NAME;
		v_out_tab data_browser_conf.tab_record_edit;
	begin
        v_Data_Source := 'TABLE'; -- case when v_Search_Value IS NULL then 'NEW_ROWS' else 'TABLE' end;
		if p_Unique_Key_Column IS NULL then
			SELECT SEARCH_KEY_COLS
			INTO v_Unique_Key_Column
			FROM MVDATA_BROWSER_VIEWS
			WHERE VIEW_NAME = p_Table_Name;
		else
			v_Unique_Key_Column := p_Unique_Key_Column;
		end if;
		if p_Parent_Table IS NOT NULL and p_Parent_Key_Column IS NULL then
			SELECT COLUMN_NAME
			INTO v_Parent_Key_Column
			FROM MVDATA_BROWSER_REFERENCES
			WHERE VIEW_NAME = v_Table_name
			AND R_VIEW_NAME = p_Parent_Table
			AND ROWNUM = 1;
		else 
			v_Parent_Key_Column := p_Parent_Key_Column;
		end if;
		v_Query := data_browser_utl.Get_Record_View_Query(
			p_Table_name => v_Table_name,
			p_Unique_Key_Column => v_Unique_Key_Column,
			p_Search_Value => p_Search_Value,
			p_Data_Columns_Only => 'YES',
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Edit_Mode => p_Edit_Mode,
			p_Data_Source => v_Data_Source,
			p_Join_Options => p_Join_Options,
			p_Parent_Table => p_Parent_Table,
			p_Parent_Key_Column => v_Parent_Key_Column,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Parent_Key_Visible => 'YES',
			p_File_Page_ID => p_File_Page_ID,
			p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
			p_Text_Tool_Selector => p_Text_Tool_Selector
		);
		OPEN form_view_cur;
		FETCH form_view_cur BULK COLLECT INTO v_out_tab;
		CLOSE form_view_cur;
		IF v_out_tab.FIRST IS NOT NULL THEN
			FOR ind IN 1 .. v_out_tab.COUNT
			LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		END IF;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_search_value,p_select_columns,p_columns_limit,p_view_mode,p_join_options,p_edit_mode,p_parent_table,p_parent_key_column,p_parent_key_item,p_file_page_id,p_text_editor_page_id,p_text_tool_selector,v_out_tab.COUNT;
        $END
	end Get_Record_Data_Cursor;


	FUNCTION Get_Record_View_Cursor ( 					-- External : View single record in form layout
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit VARCHAR2 DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',
		p_Layout_Columns NUMBER DEFAULT 1,				-- 1 or 2 or 3
    	p_Data_Source VARCHAR2 DEFAULT NULL, 			-- NEW_ROWS, TABLE, MEMORY, COLLECTION. 
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,		-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_File_Page_ID NUMBER DEFAULT NULL				-- Page ID of target links to file preview in View_Mode FORM_VIEW
	)
	RETURN data_browser_conf.tab_3col_values PIPELINED
	is
	PRAGMA UDF;
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Query			CLOB;
		v_Search_Value	VARCHAR2(4000) := p_Search_Value;
		v_Unique_Key_Column VARCHAR2(4000) := p_Unique_Key_Column;
        v_Data_Source		VARCHAR2(10);
        v_Parent_Table		VARCHAR2(128);
        v_Parent_Key_Column VARCHAR2(128);
        v_Parent_Key_Visible CONSTANT VARCHAR2(10) := 'YES';
		v_Join_Options		VARCHAR2(4000);
        CURSOR edit_view_cur
        IS
        	SELECT COLUMN_HEADER, COLUMN_DATA, COLUMN_HELP, COLUMN_EXPR_TYPE
        	FROM (
				SELECT A.COLUMN_NAME,
					'<div style="min-width: 160px;">'
					|| B.COLUMN_HEADER
					|| data_browser_select.Get_Form_Required_Html (
						p_Is_Required  => B.REQUIRED,
						p_Check_Unique => B.CHECK_UNIQUE, 
						p_Display_Key_Column => B.IS_DISP_KEY_COLUMN )
					|| '</div>'
					COLUMN_HEADER,
					case when B.COLUMN_EXPR_TYPE != 'HIDDEN'
						then '<div class="t-Form-inputContainer" style="max-width: '
							|| data_browser_conf.Get_Maximum_Field_Width || 'ex;">'
							|| '<div class="t-Form-itemWrapper" style="display: block;">'
							||	A.COLUMN_DATA
							|| '</div>'
							|| '</div>'
						else A.COLUMN_DATA
					end COLUMN_DATA,
					data_browser_select.Get_Form_Help_Link_Html (
						p_COLUMN_ID => B.COLUMN_ID,
						p_R_VIEW_NAME => v_Table_Name,
						p_R_COLUMN_NAME => B.COLUMN_NAME,
						p_COLUMN_HEADER => B.COLUMN_HEADER,
						p_Comments => B.COMMENTS
					) COLUMN_HELP,
					B.COLUMN_EXPR_TYPE
				FROM TABLE (
					data_browser_utl.column_value_list (
						p_Query => v_Query,
						p_Search_Value => case when v_Data_Source NOT IN('MEMORY', 'NEW_ROWS') then p_Search_Value end,
						p_Exact => 'YES'
					)
				) A
				LEFT OUTER JOIN TABLE (data_browser_edit.Get_Form_Edit_Cursor (
						p_Table_name => v_Table_Name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_Data_Columns_Only => 'YES',
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => 'NO',
						p_Join_Options => v_Join_Options,
						p_Data_Source => v_Data_Source,
						p_Parent_Name => v_Parent_Table,
						p_Parent_Key_Column => v_Parent_Key_Column,
						p_Parent_Key_Item => p_Parent_Key_Item,
						p_Parent_Key_Visible => v_Parent_Key_Visible,
						p_File_Page_ID => p_File_Page_ID,
						p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
						p_Text_Tool_Selector => p_Text_Tool_Selector
					)
				) B ON A.COLUMN_NAME = B.COLUMN_NAME
			);

        CURSOR form_view_cur
        IS
        	SELECT COLUMN_HEADER, COLUMN_DATA, COLUMN_HELP, COLUMN_EXPR_TYPE
        	FROM (
				SELECT A.COLUMN_NAME,
					'<div style="min-width: 160px;"><span style="font-weight: bold;">'
					|| B.COLUMN_HEADER
					|| '</span>'
					|| data_browser_select.Get_Form_Required_Html (
						p_Is_Required  => B.REQUIRED,
						p_Check_Unique => B.CHECK_UNIQUE, 
						p_Display_Key_Column => B.IS_DISP_KEY_COLUMN )
					|| '</div>'
					COLUMN_HEADER,
					'<div class="t-Form-itemWrapper" style="text-align: '
					|| lower(B.COLUMN_ALIGN) || '; display: block;">'
					|| A.COLUMN_DATA
					|| '</div>'
					COLUMN_DATA,
					data_browser_select.Get_Form_Help_Link_Html (
						p_COLUMN_ID => B.COLUMN_ID,
						p_R_VIEW_NAME => v_Table_Name,
						p_R_COLUMN_NAME => B.COLUMN_NAME,
						p_COLUMN_HEADER => B.COLUMN_HEADER,
						p_Comments => B.COMMENTS
					) COLUMN_HELP,
					B.COLUMN_EXPR_TYPE
				FROM TABLE (
					data_browser_utl.column_value_list (
						p_Query => v_Query,
						p_Search_Value => p_Search_Value,
						p_Exact => 'YES'
					)
				) A
				JOIN TABLE(
					data_browser_select.Get_View_Column_Cursor(
						p_Table_name => v_Table_name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_Data_Columns_Only => 'YES',
						p_Join_Options => v_Join_Options,
						p_View_Mode => p_View_Mode,
						p_Edit_Mode => p_Edit_Mode,
						p_Report_Mode => 'NO',
						p_Parent_Name => p_Parent_Table,
						p_Parent_Key_Column => v_Parent_Key_Column,
						p_Parent_Key_Visible => v_Parent_Key_Visible,
						p_File_Page_ID => p_File_Page_ID
					)
				) B ON A.COLUMN_NAME = B.COLUMN_NAME
				WHERE B.COLUMN_EXPR_TYPE != 'HIDDEN'
			);

		v_Column_Expr 		data_browser_conf.t_col_html;
		v_Column_Help 		VARCHAR2(4000);
		v_Column_Expr_Type 	VARCHAR2(128);
		v_Column_Header 	VARCHAR2(512);
		v_Index 			NUMBER;
		v_Probe_Cnt 		PLS_INTEGER;
		v_empty_rec 		data_browser_conf.rec_3col_values;
		v_out_rec 			data_browser_conf.rec_3col_values;
	begin
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_unique_key_column,p_search_value,p_select_columns,p_columns_limit,p_view_mode,p_join_options,p_edit_mode,p_layout_columns,p_data_source,p_parent_table,p_parent_key_column,p_parent_key_item,p_text_editor_page_id,p_text_tool_selector,p_file_page_id;
        end if;
        v_Data_Source := p_Data_Source;
		if v_Data_Source IS NULL then 
			v_Probe_Cnt := data_browser_conf.Get_Apex_Item_Row_Count(p_Idx => data_browser_conf.Get_MD5_Column_Index);
			if v_Probe_Cnt = 1 then 
				v_Data_Source := 'MEMORY';
			elsif p_Edit_Mode = 'YES' then 
				if v_Search_Value IS NULL then
					v_Data_Source := 'NEW_ROWS';
				else 
					v_Data_Source := 'TABLE';
				end if;
			elsif v_Search_Value IS NOT NULL then
				v_Data_Source := 'TABLE';
			else 
				return;
			end if;
		end if;

        v_Parent_Table := p_Parent_Table;
        v_Parent_Key_Column := p_Parent_Key_Column;
		if p_Parent_Table IS NOT NULL and v_Parent_Key_Column IS NULL then
			begin
				SELECT R_VIEW_NAME, COLUMN_NAME
				INTO v_Parent_Table, v_Parent_Key_Column
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = p_Parent_Table
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;
		-- Calculate expression for Link_ID
		v_Unique_Key_Column := data_browser_select.Get_Unique_Key_Expression(
			p_Table_Name => v_Table_Name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_View_Mode => p_View_Mode
		);
		v_Join_Options := p_Join_Options;
		if v_Join_Options IS NULL then 
			v_Join_Options := 
				data_browser_joins.Get_Details_Join_Options (
					p_Table_name => v_Table_Name,
					p_View_Mode => p_View_Mode,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible
				);
		end if;
		v_Query := data_browser_utl.Get_Record_View_Query(
			p_Table_name => v_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Search_Value => p_Search_Value,
			p_Data_Columns_Only => 'YES',
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Edit_Mode => p_Edit_Mode,
			p_Data_Source => v_Data_Source,
			p_Join_Options => v_Join_Options,
			p_Parent_Table => v_Parent_Table,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Parent_Key_Column => v_Parent_Key_Column,
			p_Parent_Key_Visible => v_Parent_Key_Visible,
			p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
			p_Text_Tool_Selector => p_Text_Tool_Selector,
			p_File_Page_ID => p_File_Page_ID
		);
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_utl.Get_Record_View_Cursor (v_Unique_Key_Column => %s, p_Search_Value => %s, p_Edit_Mode => %s) : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Unique_Key_Column),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Search_Value),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Edit_Mode),
				p3 => v_Query,
				p_max_length => 3500
			);
		$END
		if p_Edit_Mode = 'YES' then
			OPEN edit_view_cur;
			LOOP
				v_out_rec := v_empty_rec;
				v_Index := 1;
				LOOP
					FETCH edit_view_cur INTO v_Column_Header, v_Column_Expr, v_Column_Help, v_Column_Expr_Type;
					EXIT WHEN edit_view_cur%NOTFOUND;
					if v_Column_Expr_Type = 'HIDDEN' then
						v_out_rec.COLUMN_DATA1   := v_out_rec.COLUMN_DATA1 || v_Column_Expr;
					elsif v_Index = 1 then
						v_out_rec.COLUMN_HEADER1 := v_Column_Header;
						v_out_rec.COLUMN_DATA1   := v_out_rec.COLUMN_DATA1 || v_Column_Expr;
						v_out_rec.COLUMN_HELP1   := v_Column_Help;
						v_Index := 2;
					elsif v_Index = 2 then
						v_out_rec.COLUMN_HEADER2 := v_Column_Header;
						v_out_rec.COLUMN_DATA2   := v_Column_Expr;
						v_out_rec.COLUMN_HELP2   := v_Column_Help;
						v_Index := 3;
					elsif v_Index = 3 then
						v_out_rec.COLUMN_HEADER3 := v_Column_Header;
						v_out_rec.COLUMN_DATA3   := v_Column_Expr;
						v_out_rec.COLUMN_HELP3   := v_Column_Help;
						v_Index := 4;
					end if;
					EXIT WHEN v_Index > p_Layout_Columns;
				END LOOP;
				pipe row (v_out_rec);
				EXIT WHEN edit_view_cur%NOTFOUND;
			END LOOP;
			CLOSE edit_view_cur;
		else
			OPEN form_view_cur;
			LOOP
				v_out_rec := v_empty_rec;
				v_Index := 1;
				LOOP
					FETCH form_view_cur INTO v_Column_Header, v_Column_Expr, v_Column_Help, v_Column_Expr_Type;
					EXIT WHEN form_view_cur%NOTFOUND;
					if v_Index = 1 then
						v_out_rec.COLUMN_HEADER1 := v_Column_Header;
						v_out_rec.COLUMN_DATA1   := v_Column_Expr;
						v_out_rec.COLUMN_HELP1   := v_Column_Help;
						v_Index := 2;
					elsif v_Index = 2 then
						v_out_rec.COLUMN_HEADER2 := v_Column_Header;
						v_out_rec.COLUMN_DATA2   := v_Column_Expr;
						v_out_rec.COLUMN_HELP2   := v_Column_Help;
						v_Index := 3;
					elsif v_Index = 3 then
						v_out_rec.COLUMN_HEADER3 := v_Column_Header;
						v_out_rec.COLUMN_DATA3   := v_Column_Expr;
						v_out_rec.COLUMN_HELP3   := v_Column_Help;
						v_Index := 4;
					end if;
					EXIT WHEN v_Index > p_Layout_Columns;
				END LOOP;
				pipe row (v_out_rec);
				EXIT WHEN form_view_cur%NOTFOUND;
			END LOOP;
			CLOSE form_view_cur;
		end if;
	end Get_Record_View_Cursor;

	FUNCTION foreign_key_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,		-- Parent View or Table name.
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL		-- default value for foreign key column
	)
	RETURN data_browser_conf.tab_foreign_key_value PIPELINED
	is
	PRAGMA UDF;
        v_Table_Name 		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Column_List		VARCHAR2(4000);
        stat_cur            SYS_REFCURSOR;
        v_Search_Value		VARCHAR2(512);
        CURSOR view_cur
        IS
			SELECT
				data_browser_conf.Column_Name_to_Header(p_Column_Name => A.COLUMN_NAME, p_Remove_Extension => 'YES', p_Remove_Prefix => S.COLUMN_PREFIX) FIELD_NAME,
				data_browser_utl.Lookup_Column_Values(
					p_Table_Name => E.R_VIEW_NAME,
					p_Column_Names => E.DISPLAYED_COLUMN_NAMES,
					p_Search_Key_Col => E.R_PRIMARY_KEY_COLS,
					p_Search_Value => A.COLUMN_DATA,
					p_View_Mode => 'FORM_VIEW'
				) FIELD_VALUE,
				A.COLUMN_NAME,
				A.COLUMN_DATA,
				E.R_VIEW_NAME R_TABLE_NAME,
				E.R_PRIMARY_KEY_COLS R_COLUMN_NAME,
				E.R_UNIQUE_KEY_COLS R_UNIQUE_KEY_COLS,
				E.CONSTRAINT_NAME,
				1 ROW_COUNT,
				DENSE_RANK() OVER (PARTITION BY E.VIEW_NAME ORDER BY E.R_VIEW_NAME, E.R_PRIMARY_KEY_COLS) POSITION
			FROM MVDATA_BROWSER_REFERENCES E
			JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = E.VIEW_NAME
			JOIN TABLE ( data_browser_utl.column_value_list (
				p_Query => case when p_Search_Value IS NOT NULL then
					'SELECT ' || v_Column_List
					|| ' FROM ' || E.VIEW_NAME || ' A '
					|| ' WHERE ' 
					|| data_browser_select.Get_Unique_Key_Expression(
						p_Table_Name => v_Table_Name,
						p_Unique_Key_Column => p_Unique_Key_Column,
						p_View_Mode => 'FORM_VIEW'
					)
					|| ' = :search_value'
				else
					'SELECT :search_value ' || v_Column_List || ' FROM DUAL'
				end
				, p_Search_Value => v_Search_Value
				,  p_Exact => 'YES')
			) A  ON E.COLUMN_NAME = A.COLUMN_NAME
			WHERE E.VIEW_NAME = v_Table_name;
		v_out_tab data_browser_conf.tab_foreign_key_value;
		v_Count NUMBER := 0;
	begin
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(p_overload => 1)
            USING p_table_name,p_unique_key_column,p_search_value,p_parent_table,p_parent_key_item;
        end if;
		if p_Search_Value IS NOT NULL then
			SELECT LISTAGG(FOREIGN_KEY_COLS, ', ') WITHIN GROUP (ORDER BY FOREIGN_KEY_COLS) X
			INTO v_Column_List
			FROM (SELECT DISTINCT FOREIGN_KEY_COLS
				FROM MVDATA_BROWSER_FKEYS T
				WHERE T.VIEW_NAME = v_Table_Name
			);
			v_Search_Value := p_Search_Value;
		elsif p_Parent_Table IS NOT NULL and p_Parent_Key_Item IS NOT NULL then
			SELECT FOREIGN_KEY_COLS X
			INTO v_Column_List
			FROM MVDATA_BROWSER_FKEYS T
			WHERE T.VIEW_NAME = v_Table_Name
			AND T.R_VIEW_NAME = p_Parent_Table
			AND ROWNUM = 1;
			v_Search_Value := APEX_UTIL.GET_SESSION_STATE(p_Parent_Key_Item);
		end if;

		if v_Column_List IS NOT NULL and v_Search_Value IS NOT NULL then
			OPEN view_cur;
			FETCH view_cur BULK COLLECT INTO v_out_tab;
			CLOSE view_cur;
			IF v_out_tab.FIRST IS NOT NULL THEN
				v_Count := v_out_tab.COUNT;
				FOR ind IN 1 .. v_out_tab.COUNT
				LOOP
					pipe row (v_out_tab(ind));
				END LOOP;
			END IF;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call(p_overload => 1)
            USING p_table_name,p_unique_key_column,p_search_value,p_parent_table,p_parent_key_item,v_Count;
        $END
	end foreign_key_cursor;

	FUNCTION foreign_key_cursor (
		p_Table_name IN VARCHAR2
	)
	RETURN data_browser_conf.tab_foreign_key_value PIPELINED
	is
	PRAGMA UDF;
        CURSOR view_cur
        IS
			SELECT
				data_browser_conf.Column_Name_to_Header(p_Column_Name => E.COLUMN_NAME, p_Remove_Extension => 'YES', p_Remove_Prefix => S.COLUMN_PREFIX) FIELD_NAME,
				NULL FIELD_VALUE,
				E.COLUMN_NAME,
				NULL COLUMN_DATA,
				E.R_VIEW_NAME R_TABLE_NAME,
				E.R_PRIMARY_KEY_COLS R_COLUMN_NAME,
				E.R_UNIQUE_KEY_COLS R_UNIQUE_KEY_COLS,
				E.CONSTRAINT_NAME,
				1 ROW_COUNT,
				DENSE_RANK() OVER (PARTITION BY E.VIEW_NAME ORDER BY E.R_VIEW_NAME, E.R_PRIMARY_KEY_COLS) POSITION
			FROM MVDATA_BROWSER_REFERENCES E
			JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = E.VIEW_NAME
			WHERE E.VIEW_NAME = p_Table_Name;
		v_out_tab data_browser_conf.tab_foreign_key_value;
		v_Count NUMBER := 0;
	begin
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_out_tab;
		CLOSE view_cur;
		IF v_out_tab.FIRST IS NOT NULL THEN
			v_Count := v_out_tab.COUNT;
			FOR ind IN 1 .. v_out_tab.COUNT
			LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		END IF;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call(p_overload => 2)
            USING p_table_name,v_Count;
        $END
	end foreign_key_cursor;

/*
SELECT the_level, label, target, is_current_list_entry, image
FROM TABLE ( data_browser_utl.parents_list_cursor(
        p_Table_name => :P32_TABLE_NAME,
        p_Search_Value => :P32_LINK_ID,
        p_Parent_Table => :P32_PARENT_NAME,
        p_Parent_Key_Item => 'P32_PARENT_ID',
        p_Link_Page_ID => :APP_PAGE_ID,
        p_Link_Items => 'P32_TABLE_NAME,P32_LINK_KEY,P32_LINK_ID,P32_DETAIL_TABLE,P32_DETAIL_KEY_COL,P32_DETAIL_KEY_ID'
    )
);

if :REQUEST = 'LOAD_PARENT' then
	:P32_DETAIL_ID := :P32_LINK_ID;
	:P32_EDIT_MODE := 'NO';
end if;
*/
	FUNCTION parents_list_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Item name for parent key id
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	-- Page ID of target links
    	p_Link_Items VARCHAR2 -- Item names for Parent_Table, Parent_Key_Column, Parent_Key_ID, Detail_Table, Detail_Key_Column, Detail_Key_ID
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED
	is
	PRAGMA UDF;
        CURSOR view_cur
        IS
			SELECT 1 the_level,
				S.FIELD_NAME
				|| ' ( '|| NVL(S.FIELD_VALUE, apex_lang.lang('-none-')) ||' ) '
				label,
				case when S.FIELD_VALUE IS NOT NULL then
					-- apex_util.prepare_url - is not called here, because this is done by the list plugin
					('f?p='|| V('APP_ID') ||':' || p_Link_Page_ID || ':' || V('APP_SESSION') || ':PARENT_VIEW:' || V('DEBUG')
					   || ':RP,' || p_Link_Page_ID || ':'
					   || p_Link_Items || ':'
					   || S.R_TABLE_NAME || ',' || S.R_COLUMN_NAME || ',' || S.COLUMN_DATA || ','
					   || p_Table_name || ',' || S.COLUMN_NAME
					)
				end target,
				case when p_Parent_Table = S.R_TABLE_NAME
					and (V(p_Parent_Key_Item) = S.COLUMN_DATA OR V(p_Parent_Key_Item) IS NULL)
					then 'YES' else 'NO'
				end is_current_list_entry,
				'fa-arrow-up' image,
				S.POSITION position,
				null attribute1
			FROM TABLE ( data_browser_utl.foreign_key_cursor(
				p_Table_name => p_Table_name,
				p_Search_Value => p_Search_Value,
				p_Parent_Table => p_Parent_Table,
				p_Parent_Key_Item => p_Parent_Key_Item
				)
			) S
			-- Bugfix: DS 20230305 - removed WHERE S.FIELD_VALUE IS NOT NULL, because the list should be displayed with Label -none- for empty foreign key fields.
			ORDER BY S.POSITION;
		v_out_tab data_browser_conf.tab_apex_links_list;
	begin
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(p_overload => 1)
            USING p_table_name,p_unique_key_column,p_search_value,p_parent_table,p_parent_key_item,p_link_page_id,p_link_items;
        end if;
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_out_tab;
		CLOSE view_cur;
		IF v_out_tab.FIRST IS NOT NULL THEN
			FOR ind IN 1 .. v_out_tab.COUNT
			LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		END IF;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call(p_overload => 1)
            USING p_table_name,p_unique_key_column,p_search_value,p_parent_table,p_parent_key_item,p_link_page_id,p_link_items,v_out_tab.COUNT;
        $END
	end parents_list_cursor;

	FUNCTION parents_list_cursor (
		p_Table_name IN VARCHAR2,
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	-- Page ID of target links
    	p_Link_Items VARCHAR2, -- Item names for Parent_Table, Constraint_Name
    	p_Request VARCHAR2
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED
	is
	PRAGMA UDF;
        CURSOR view_cur
        IS
			SELECT 1 the_level,
				S.FIELD_NAME
				label,
				-- apex_util.prepare_url - is not called here, because this is done by the list plugin
				('f?p='|| V('APP_ID') ||':' || p_Link_Page_ID || ':' || V('APP_SESSION') || ':' || p_Request || ':' || V('DEBUG')
				   || ':RP,' || p_Link_Page_ID || ':'
				   || p_Link_Items || ':'
				   || S.R_TABLE_NAME
				) target,
				'NO' is_current_list_entry,
				'fa-arrow-up' image,
				S.POSITION position,
				null attribute1
			FROM TABLE ( data_browser_utl.foreign_key_cursor(
					p_Table_name => p_Table_name
				)
			) S
			ORDER BY S.POSITION;
		v_out_tab data_browser_conf.tab_apex_links_list;
	begin
        if apex_application.g_debug then
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(p_overload => 2)
            USING p_table_name,p_link_page_id,p_link_items,p_request;
        end if;
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_out_tab;
		CLOSE view_cur;
		IF v_out_tab.FIRST IS NOT NULL THEN
			FOR ind IN 1 .. v_out_tab.COUNT
			LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		END IF;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call(p_overload => 2)
            USING p_table_name,p_link_page_id,p_link_items,p_request,v_out_tab.COUNT;
        $END
	end parents_list_cursor;
	

	FUNCTION detail_key_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2
	)
	RETURN data_browser_conf.tab_foreign_key_value PIPELINED
	is
	PRAGMA UDF;
        v_Table_Name 		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Column_List		VARCHAR2(4000);
        CURSOR view_cur
        IS
        	SELECT	
					FIELD_NAME,
        			FIELD_VALUE, 
        			COLUMN_NAME, 
        			COLUMN_DATA,
        			R_TABLE_NAME, 
        			R_COLUMN_NAME, 
        			R_UNIQUE_KEY_COLS, 
        			CONSTRAINT_NAME,
        			data_browser_conf.FN_Query_Cardinality(R_TABLE_NAME, R_COLUMN_NAME, COLUMN_DATA) ROW_COUNT,
        			POSITION
        	FROM (
				SELECT
					data_browser_select.Reference_Column_Header (
						p_Column_Name => E.COLUMN_NAME,
						p_Remove_Prefix => S.COLUMN_PREFIX,
						p_View_Name => E.VIEW_NAME,
						p_R_View_Name => E.R_VIEW_NAME
					) FIELD_NAME,
					S.COLUMN_PREFIX,
					NULL FIELD_VALUE,
					E.R_UNIQUE_KEY_COLS COLUMN_NAME,
					case when E.R_UNIQUE_KEY_COLS != p_Unique_Key_Column then
						data_browser_utl.Lookup_Column_Value (
							p_Search_Value => p_Search_Value, 
							p_Table_Name => E.R_VIEW_NAME, 
							p_Column_Exp => E.R_UNIQUE_KEY_COLS, -- Bugfix DS 20230220: Lookup of prirmary key value failed 
							p_Search_Key_Col => p_Unique_Key_Column)
					else 
						p_Search_Value 
					end COLUMN_DATA,
					E.VIEW_NAME R_TABLE_NAME,
					E.COLUMN_NAME R_COLUMN_NAME,
					E.UNIQUE_KEY_COLS R_UNIQUE_KEY_COLS,
					E.CONSTRAINT_NAME,
					DENSE_RANK() OVER (PARTITION BY E.R_VIEW_NAME ORDER BY E.VIEW_NAME, E.COLUMN_NAME) POSITION
				FROM MVDATA_BROWSER_REFERENCES E
				JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = E.VIEW_NAME
				WHERE E.R_VIEW_NAME = v_Table_Name
			);
    	v_Detail_Key_md5 	VARCHAR2(300);
        v_is_cached			VARCHAR2(10);
	begin
		if p_Table_name IS NOT NULL and p_Search_Value IS NOT NULL then
			v_Detail_Key_md5 := wwv_flow_item.md5 (v_Table_Name, p_Unique_Key_Column, p_Search_Value);
			v_is_cached	:= case when g_Detail_Key_md5 = 'X' then 'init'
					when g_Detail_Key_md5 != v_Detail_Key_md5 then 'load' else 'cached!' end;
			-- get the foreign key values for the current row.
			if v_is_cached != 'cached!' then
				OPEN view_cur;
				FETCH view_cur BULK COLLECT INTO g_Detail_Key_tab;
				CLOSE view_cur;
				g_Detail_Key_md5 := v_Detail_Key_md5;
			end if;
			if g_Detail_Key_tab.FIRST IS NOT NULL THEN
				FOR ind IN 1 .. g_Detail_Key_tab.COUNT LOOP
					pipe row (g_Detail_Key_tab(ind));
				END LOOP;
			end if;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_search_value,g_Detail_Key_tab.COUNT;
        $END
	end detail_key_cursor;


/*
SELECT the_level, label, target, is_current_list_entry, image
FROM TABLE ( data_browser_utl.details_list_cursor(
        p_Table_name => :P32_TABLE_NAME,
        p_Unique_Key_Column => :P32_LINK_KEY,
        p_Search_Value => :P32_LINK_ID,
        p_Detail_Table => :P32_DETAIL_TABLE,
        p_Detail_Key_Col => :P32_DETAIL_KEY_COL,
        p_Link_Page_ID => :APP_PAGE_ID,
        p_Link_Items => 'P32_DETAIL_TABLE,P32_DETAIL_KEY_COL,P32_DETAIL_ID'
    )
);
*/
	FUNCTION details_list_cursor (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Search_Value IN VARCHAR2,
    	p_Detail_Table VARCHAR2 DEFAULT NULL,
    	p_Detail_Key_Col VARCHAR2 DEFAULT NULL,
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	-- Page ID of target links
    	p_Link_Items VARCHAR2 -- Item names for Detail_Table, Detail_Key_Column, Detail_Key_ID
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED
	is
	PRAGMA UDF;
        CURSOR view_cur
        IS
			select 1 the_level,
				   S.FIELD_NAME || ' ( '|| S.ROW_COUNT ||' ) ' label,
				   -- apex_util.prepare_url - is not called here, because this is done by the list plugin
				   ('f?p='|| V('APP_ID') ||':' || p_Link_Page_ID || ':' || V('APP_SESSION') || ':DETAIL_VIEWS:' || V('DEBUG')
					   || ':RP:'
					   || p_Link_Items || ':'
					   ||  S.R_TABLE_NAME || ',' || S.R_COLUMN_NAME || ',' || S.COLUMN_DATA
				   ) target,
				   case when p_Detail_Table = S.R_TABLE_NAME
						and p_Detail_Key_Col = S.R_COLUMN_NAME
						then 'YES' else 'NO'
				   end IS_CURRENT_LIST_ENTRY,
				  'fa-arrow-up' IMAGE,
					S.POSITION POSITION,
					null ATTRIBUTE1
			FROM TABLE ( data_browser_utl.detail_key_cursor(
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => p_Unique_Key_Column,
				p_Search_Value => p_Search_Value)
			) S
			ORDER BY S.POSITION;
		v_out_tab data_browser_conf.tab_apex_links_list;
	begin
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_out_tab;
		CLOSE view_cur;
		IF v_out_tab.FIRST IS NOT NULL THEN
			FOR ind IN 1 .. v_out_tab.COUNT LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		END IF;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_search_value,p_detail_table,p_detail_key_col,p_link_page_id,p_link_items,v_out_tab.COUNT;
        $END
	end details_list_cursor;

	FUNCTION Report_View_Modes_List (
		p_Table_name IN VARCHAR2,
    	p_View_Mode_Item VARCHAR2 
	)
	RETURN data_browser_conf.tab_apex_links_list PIPELINED
	is
        CURSOR view_cur
        IS
			select 1 the_level, 
					apex_lang.lang('Form View') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('FORM_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'FORM_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-list-alt' image,
					1 position,
					'data-item=' || dbms_assert.enquote_name('FORM_VIEW') attribute1
			from dual 
			union all 
			select 1 the_level, 
					apex_lang.lang('Navigation Counter') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('NAVIGATION_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'NAVIGATION_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-compass' image,
					2 position,
					'data-item=' || dbms_assert.enquote_name('NAVIGATION_VIEW') attribute1
			from MVDATA_BROWSER_VIEWS
			where IS_REFERENCED_KEY = 'YES' 
			and VIEW_NAME = p_Table_name
			union all 
			select 1 the_level, 
					apex_lang.lang('Navigation Links') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('NESTED_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'NESTED_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-list' image,
					3 position,
					'data-item=' || dbms_assert.enquote_name('NESTED_VIEW') attribute1
			from MVDATA_BROWSER_VIEWS
			where IS_REFERENCED_KEY = 'YES' 
			and VIEW_NAME = p_Table_name
			union all 
			select 1 the_level, 
					apex_lang.lang('Raw Record') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('RECORD_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'RECORD_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-table' image,
					4 position,
					'data-item=' || dbms_assert.enquote_name('RECORD_VIEW') attribute1
			from dual 
			union all 
			select 1 the_level, 
					apex_lang.lang('Import View') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('IMPORT_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'IMPORT_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-table-arrow-up' image,
					5 position,
					'data-item=' || dbms_assert.enquote_name('IMPORT_VIEW') attribute1
			from dual 
			union all 
			select 1 the_level, 
					apex_lang.lang('Export View') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('EXPORT_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'EXPORT_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-table-arrow-down' image,
					6 position,
					'data-item=' || dbms_assert.enquote_name('EXPORT_VIEW') attribute1
			from dual 
/*			union all -- under construction --
			select 1 the_level, 
					apex_lang.lang('Chart') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('DONUT_CHART') || ');' target,
					case when V(p_View_Mode_Item) = 'DONUT_CHART' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-donut-chart' image,
					7 position,
					'data-item=' || dbms_assert.enquote_name('DONUT_CHART') attribute1
			from MVDATA_BROWSER_VIEWS
			where IS_REFERENCED_KEY = 'YES' 
			and VIEW_NAME = p_Table_name
*/			union all 
			select 1 the_level, 
					apex_lang.lang('History') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('HISTORY') || ');' target,
					case when V(p_View_Mode_Item) = 'HISTORY' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-history' image,
					8 position,
					'data-item=' || dbms_assert.enquote_name('HISTORY') attribute1
			from dual 
			where changelog_conf.Get_Use_Change_Log = 'YES' 
			and data_browser_conf.Has_ChangeLog_History(p_Table_Name => p_Table_name) = 'YES'
			union all 
			select 1 the_level, 
					apex_lang.lang('Calendar') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('CALENDAR') || ');' target,
					case when V(p_View_Mode_Item) = 'CALENDAR' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-calendar' image,
					9 position,
					'data-item=' || dbms_assert.enquote_name('CALENDAR') attribute1
			from dual 
			where data_browser_utl.Has_Calendar_Date(p_Table_Name => p_Table_name) = 'YES'
			union all 
			select 1 the_level, 
					apex_lang.lang('Tree View') label,
					'javascript:$s(' || dbms_assert.enquote_literal(p_View_Mode_Item) || ',' || dbms_assert.enquote_literal('TREE_VIEW') || ');' target,
					case when V(p_View_Mode_Item) = 'TREE_VIEW' 
						then 'YES' else 'NO'
				    end is_current_list_entry,
					'fa-format' image,
					10 position,
					'data-item=' || dbms_assert.enquote_name('TREE_VIEW') attribute1
			from dual 
			where data_browser_utl.Has_Tree_View(p_Table_Name => p_Table_name) = 'YES';

		v_out_tab data_browser_conf.tab_apex_links_list;
	begin
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_out_tab;
		CLOSE view_cur;
		IF v_out_tab.FIRST IS NOT NULL THEN
			FOR ind IN 1 .. v_out_tab.COUNT LOOP
				pipe row (v_out_tab(ind));
			END LOOP;
		END IF;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_view_mode_item,v_out_tab.COUNT;
        $END
	end Report_View_Modes_List;

	PROCEDURE Search_Table_Node (
		p_Search_Table IN VARCHAR2,
		p_Constraint_Name IN OUT VARCHAR2,
		p_Table_Name  OUT VARCHAR2,	-- NO_COPY can not be used here
    	p_Unique_Key_Column OUT VARCHAR2, 
		p_Parent_Name OUT VARCHAR2,
		p_Parent_Column OUT VARCHAR2,
		p_Parent_Key_Column OUT VARCHAR2,
		p_Tree_Current_Node OUT NUMBER,
		p_Tree_Path OUT VARCHAR2,
		p_Search_Exact IN VARCHAR2 DEFAULT 'YES'
	)
	IS
		v_Count 			PLS_INTEGER := 0;
		v_Constraint_Name 	MVDATA_BROWSER_FKEYS.CONSTRAINT_NAME%TYPE;
		v_Table_Name		MVDATA_BROWSER_FKEYS.VIEW_NAME%TYPE;
		v_Unique_Key_Column	MVDATA_BROWSER_FKEYS.UNIQUE_KEY_COLS%TYPE;
		v_Parent_Name		MVDATA_BROWSER_FKEYS.R_VIEW_NAME%TYPE;
		v_Parent_Column		MVDATA_BROWSER_FKEYS.R_PRIMARY_KEY_COLS%TYPE;
		v_Parent_Key_Column	MVDATA_BROWSER_FKEYS.FOREIGN_KEY_COLS%TYPE;
    	v_Search_Path VARCHAR2(2000);
	begin
		v_Constraint_Name := p_Constraint_Name;
		loop
			begin
				SELECT DISTINCT FIRST_VALUE(CONSTRAINT_NAME) OVER (ORDER BY CONSTRAINT_NAME) CONSTRAINT_NAME,
					FIRST_VALUE(VIEW_NAME) OVER (ORDER BY CONSTRAINT_NAME) VIEW_NAME,
					FIRST_VALUE(SEARCH_KEY_COLS) OVER (ORDER BY CONSTRAINT_NAME) UNIQUE_KEY_COLS,
					FIRST_VALUE(R_VIEW_NAME) OVER (ORDER BY CONSTRAINT_NAME) R_VIEW_NAME,
					FIRST_VALUE(R_PRIMARY_KEY_COLS) OVER (ORDER BY CONSTRAINT_NAME) R_PRIMARY_KEY_COLS,
					FIRST_VALUE(COLUMN_NAME) OVER (ORDER BY CONSTRAINT_NAME) COLUMN_NAME
				INTO v_Constraint_Name, v_Table_Name, v_Unique_Key_Column, v_Parent_Name, v_Parent_Column, v_Parent_Key_Column
				FROM (
				   select
						COALESCE(T.CONSTRAINT_NAME, S.CONSTRAINT_NAME, S.VIEW_NAME) CONSTRAINT_NAME,
						S.VIEW_NAME, S.SEARCH_KEY_COLS,
						T.R_VIEW_NAME, T.COLUMN_NAME, T.R_PRIMARY_KEY_COLS
					FROM MVDATA_BROWSER_VIEWS S
					LEFT outer join (
						select VIEW_NAME, R_VIEW_NAME, FOREIGN_KEY_COLS COLUMN_NAME, CONSTRAINT_NAME, R_PRIMARY_KEY_COLS
						from MVDATA_BROWSER_FKEYS
						where VIEW_NAME != R_VIEW_NAME
						and FK_COLUMN_COUNT = 1
					) T on S.VIEW_NAME = T.VIEW_NAME
					where (S.IS_ADMIN_TABLE = 'N' or data_browser_conf.Get_Admin_Enabled = 'Y')
				)
				WHERE ((p_Search_Exact = 'NO' AND REGEXP_INSTR(VIEW_NAME, p_Search_Table, 1, 1, 1, 'i') > 0)
					or (p_Search_Exact = 'YES' AND VIEW_NAME = p_Search_Table))
				AND (v_Constraint_Name IS NULL
					or (p_Search_Exact = 'YES' AND CONSTRAINT_NAME = v_Constraint_Name)
					or (p_Search_Exact = 'NO' AND CONSTRAINT_NAME > v_Constraint_Name))
				AND (VIEW_NAME != R_VIEW_NAME OR R_VIEW_NAME IS NULL)
				;
				p_Constraint_Name 	:= v_Constraint_Name;
				p_Table_Name 		:= v_Table_Name;
				p_Unique_Key_Column := v_Unique_Key_Column;
				p_Parent_Name 		:= v_Parent_Name;
				p_Parent_Column		:= v_Parent_Column;
				p_Parent_Key_Column := v_Parent_Key_Column;
				v_Search_Path := '%/' || data_browser_conf.Concat_List(v_Parent_Name,v_Table_Name,'/') || '%';

				begin 
					select value, tree_path
					into p_Tree_Current_Node, p_Tree_Path
					from table (data_browser_trees.FN_Pipe_Table_Tree) 
					where tree_path LIKE v_Search_Path
					and rownum = 1;
				exception when no_data_found then
					p_Tree_Current_Node := NULL;
					p_Tree_Path := NULL;
				end;
				exit;
			exception when no_data_found then
				$IF data_browser_conf.g_debug $THEN
					apex_debug.info(
						p_message => 'data_browser_utl.Search_Table_Node(p_Search_Table => %s, v_Constraint_Name => %s, pSearch_Exact => %s)  - no_data_found ',
						p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Search_Table),
						p1 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Constraint_Name),
						p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Search_Exact)
					);
				$END
				v_Constraint_Name := NULL;
				p_Constraint_Name := NULL;
				p_Table_Name := NULL;
				p_Unique_Key_Column := NULL;
				p_Parent_Name := NULL;
				p_Parent_Column := NULL;
				p_Parent_Key_Column := NULL;
				p_Tree_Current_Node := NULL;
				p_Tree_Path := NULL;
			end;
			v_Count := v_Count + 1;
			exit when v_Count > 1;
		end loop;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_search_table,p_constraint_name,p_table_name,p_unique_key_column,p_parent_name,p_parent_column,p_parent_key_column,p_tree_current_node,p_tree_path,p_search_exact;
        $END
	end Search_Table_Node;

	PROCEDURE Load_Table_Node (	-- special load procedure for links from table tree view
		p_Constraint_Name IN VARCHAR2,
		p_Tree_Current_Node IN OUT NUMBER,
		p_Table_Name  OUT VARCHAR2,
    	p_Unique_Key_Column OUT VARCHAR2, 
		p_Parent_Name OUT VARCHAR2,
		p_Parent_Column OUT VARCHAR2,
		p_Parent_Key_Column OUT VARCHAR2,
		p_Tree_Path OUT VARCHAR2
	)
	is
		v_Table_Name		MVDATA_BROWSER_FKEYS.VIEW_NAME%TYPE;
		v_Unique_Key_Column	MVDATA_BROWSER_FKEYS.UNIQUE_KEY_COLS%TYPE;
		v_Parent_Name		MVDATA_BROWSER_FKEYS.R_VIEW_NAME%TYPE;
		v_Parent_Key_Column	MVDATA_BROWSER_FKEYS.FOREIGN_KEY_COLS%TYPE;
		v_Parent_Column		MVDATA_BROWSER_FKEYS.R_PRIMARY_KEY_COLS%TYPE;
		v_Tree_Path 		VARCHAR2(2000);
    	v_Search_Path 		VARCHAR2(2000);
	begin
		if p_Tree_Current_Node IS NOT NULL then 
			begin 
			select tree_path
			into p_Tree_Path
			from table (data_browser_trees.FN_Pipe_Table_Tree)  
			where value = p_Tree_Current_Node
			and rownum = 1;
			exception when no_data_found then
				p_Tree_Path := NULL;
			end;
		else
			p_Tree_Path := NULL;
		end if;
	
		if p_Constraint_Name = 'NONE' or p_Constraint_Name IS NULL then 
			p_Parent_Name := NULL;
			p_Parent_Key_Column := NULL;
			return;
		end if;
		
		begin
			SELECT VIEW_NAME, UNIQUE_KEY_COLS, R_VIEW_NAME, FOREIGN_KEY_COLS, R_PRIMARY_KEY_COLS
			INTO v_Table_Name, v_Unique_Key_Column, v_Parent_Name, v_Parent_Key_Column, v_Parent_Column
			FROM MVDATA_BROWSER_FKEYS
			WHERE CONSTRAINT_NAME = p_Constraint_Name;
		exception when no_data_found then
			begin
				SELECT VIEW_NAME, SEARCH_KEY_COLS, NULL R_VIEW_NAME, NULL FOREIGN_KEY_COLS, NULL R_PRIMARY_KEY_COLS
				INTO v_Table_Name, v_Unique_Key_Column, v_Parent_Name, v_Parent_Key_Column, v_Parent_Column
				FROM MVDATA_BROWSER_VIEWS
				WHERE p_Constraint_Name IN (CONSTRAINT_NAME, VIEW_NAME);
			exception when no_data_found then
				NULL;
			end;
		end;
		p_Table_Name 		:= v_Table_Name;
		p_Unique_Key_Column := v_Unique_Key_Column;
		p_Parent_Name 		:= v_Parent_Name;
		p_Parent_Column		:= v_Parent_Column;
		p_Parent_Key_Column := v_Parent_Key_Column;
		if p_Tree_Current_Node IS NULL then 
			v_Search_Path := '%/' || data_browser_conf.Concat_List(v_Parent_Name,v_Table_Name,'/');
			begin
				select value, tree_path
				into p_Tree_Current_Node, v_Tree_Path
				from table (data_browser_trees.FN_Pipe_Table_Tree)  
				where tree_path LIKE v_Search_Path
				and rownum = 1;
			exception when no_data_found then
				p_Tree_Current_Node := NULL;
			end;
			p_Tree_Path := v_Tree_Path;
		end if;
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_constraint_name,p_tree_current_node,p_table_name,p_unique_key_column,p_parent_name,p_parent_column,p_parent_key_column,p_tree_path;
        $END
	end Load_Table_Node;

	PROCEDURE Load_Detail_View (	-- special load procedure for nested links from tabular form view
		p_Table_Name  IN VARCHAR2,
		p_Grand_Parent_Name IN VARCHAR2,
		p_Parent_Name IN VARCHAR2,
		p_Parent_Key_Column IN VARCHAR2,
		p_Constraint_Name OUT VARCHAR2,
		p_Tree_Current_Node OUT NUMBER,
		p_Tree_Path IN OUT VARCHAR2
	)
	is
    	v_Search_Path VARCHAR2(2000);
	begin
        v_Search_Path := case when p_Tree_Path is not null then 
                p_Tree_Path || '/' || p_Table_Name
            else 
                '%/' || data_browser_conf.Concat_List(data_browser_conf.Concat_List(p_Grand_Parent_Name,p_Parent_Name,'/'),p_Table_Name,'/')
        end;
        begin
			select value, tree_path
			into p_Tree_Current_Node, p_Tree_Path
			from table (data_browser_trees.FN_Pipe_Table_Tree)  
			where tree_path LIKE v_Search_Path
			and rownum = 1;
		exception when no_data_found then
			p_Tree_Current_Node := NULL;
			p_Tree_Path := NULL;
		end;
        begin
			SELECT CONSTRAINT_NAME
			INTO p_Constraint_Name
			FROM MVDATA_BROWSER_FKEYS
			WHERE VIEW_NAME = p_Table_Name
			AND R_VIEW_NAME = p_Parent_Name
			AND FOREIGN_KEY_COLS = p_Parent_Key_Column;
		exception when no_data_found then
			p_Constraint_Name := NULL;
		end;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Call
            USING p_table_name,p_grand_parent_name,p_parent_name,p_parent_key_column,p_constraint_name,p_tree_current_node,p_tree_path;
        $END
	end Load_Detail_View;

	PROCEDURE Reset_Cache
	IS
	BEGIN
		g_Detail_Key_md5 := 'X';
	END;
end data_browser_utl;
/
show errors
