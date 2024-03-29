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


CREATE OR REPLACE PACKAGE BODY data_browser_select
is
	CURSOR Describe_Cols_cur (
		v_View_Name VARCHAR2,				-- Table Name or View Name of master table
		v_Unique_Key_Column VARCHAR2,		-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		v_View_Mode VARCHAR2,				-- RECORD_VIEW, FORM_VIEW, HISTORY, NAVIGATION_VIEW, NESTED_VIEW
		v_Edit_Mode VARCHAR2,				-- YES, NO
		v_Data_Format VARCHAR2,				-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		v_Select_Columns VARCHAR2,			-- Select Column names of the final projection, Optional
		v_Parent_Name VARCHAR2,				-- Parent View or Table name. if set columns from the view are included in the Column list in View_Mode NAVIGATION_VIEW
		v_Parent_Key_Column VARCHAR2,		-- Column Name with foreign key to Parent Table
		v_Link_Page_ID NUMBER,				-- Page ID of target links in View_Mode NAVIGATION_VIEW
		v_Detail_Page_ID NUMBER,			-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		v_Calc_Totals VARCHAR2				-- YES, NO, adds a 'SUM(X)' for each summand or counter column
	)
	IS
		WITH BROWSER_VIEW AS (
			SELECT VIEW_NAME, TABLE_NAME, NVL(v_Unique_Key_Column, SEARCH_KEY_COLS) UNIQUE_KEY_COLS,
				ROW_VERSION_COLUMN_NAME, HAS_SCALAR_KEY, ORDERING_COLUMN_NAME,
				FILE_NAME_COLUMN_NAME, MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME, FILE_CONTENT_COLUMN_NAME,
				AUDIT_DATE_COLUMN_NAME, AUDIT_USER_COLUMN_NAME, COLUMN_PREFIX
			FROM MVDATA_BROWSER_VIEWS 
			WHERE VIEW_NAME = v_View_Name
		)
		SELECT COLUMN_NAME, TABLE_ALIAS, 
			ROW_NUMBER() OVER (ORDER BY data_browser_select.FN_List_Offest(v_Select_Columns, COLUMN_NAME)
								, IS_AUDIT_COLUMN, COLUMN_ID, POSITION) COLUMN_ORDER, 
			COLUMN_ID, POSITION,
			NULL INPUT_ID, -- Data Source COLLECTION is not supported
			SUM(case when COLUMN_EXPR_TYPE != 'HIDDEN' and COLUMN_ID > 0 then 1 else 0  end ) 
				OVER (ORDER BY data_browser_select.FN_List_Offest(v_Select_Columns, COLUMN_NAME)
								, case when DISPLAY_IN_REPORT = 'Y' then 0 else 1 end
								, IS_AUDIT_COLUMN, COLUMN_ID
								, case when COLUMN_EXPR_TYPE != 'HIDDEN' and COLUMN_ID > 0 then 0 else 1  end
								, POSITION) REPORT_COLUMN_ID, -- used to calculate the vivible report coöumn id that must be below the p_Column_Limit
			DATA_TYPE, DATA_PRECISION, DATA_SCALE, DATA_DEFAULT, CHAR_LENGTH,
			NULLABLE, IS_PRIMARY_KEY, IS_SEARCH_KEY, IS_FOREIGN_KEY, IS_DISP_KEY_COLUMN, CHECK_UNIQUE,
			case when COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR')
					then 'N'
				when COLUMN_EXPR_TYPE IN ('SELECT_LIST', 'SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV') AND HAS_DEFAULT = 'Y'
					then 'N'
				when NULLABLE = 'Y' OR HAS_DEFAULT = 'Y'
					then 'N'
				else 'Y'
			end REQUIRED,
			HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, 
			IS_AUDIT_COLUMN, IS_OBFUSCATED, IS_UPPER_NAME, 
			IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN, YES_NO_COLUMN_TYPE, 
			IS_SIMPLE_IN_LIST, STATIC_LOV_EXPR, HAS_AUTOMATIC_CHECK, HAS_RANGE_CHECK,
			IS_REFERENCE, IS_SEARCHABLE_REF, IS_SUMMAND, 
			IS_VIRTUAL_COLUMN, IS_DATETIME, 
			FORMAT_MASK, LOV_QUERY,
			COLUMN_ALIGN, COLUMN_HEADER, COLUMN_EXPR, COLUMN_EXPR_TYPE,
			FIELD_LENGTH, DISPLAY_IN_REPORT, '' COLUMN_DATA, R_TABLE_NAME, R_VIEW_NAME, R_COLUMN_NAME,
			REF_TABLE_NAME, REF_VIEW_NAME, REF_COLUMN_NAME, COMMENTS
		FROM (
			SELECT COLUMN_NAME, 'A' TABLE_ALIAS, 
				IS_AUDIT_COLUMN, 
				'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME, 
				'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
				'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
				'N' IS_REFERENCE, IS_SEARCHABLE_REF, 
				'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 'N' IS_DATETIME, 
				-1 COLUMN_ID, POSITION, DATA_TYPE, 0 DATA_PRECISION, 0 DATA_SCALE, '' DATA_DEFAULT, CHAR_LENGTH, NULLABLE, 
				'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, 'N' IS_FOREIGN_KEY, 'N' IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE, 
				HAS_HELP_TEXT, 'N' HAS_DEFAULT, 'N' IS_BLOB, 'N' IS_PASSWORD, FORMAT_MASK, '' LOV_QUERY,
				COLUMN_ALIGN, COLUMN_HEADER, COLUMN_EXPR, COLUMN_EXPR_TYPE, FIELD_LENGTH, 'Y' DISPLAY_IN_REPORT,
				TABLE_NAME R_TABLE_NAME, VIEW_NAME R_VIEW_NAME, R_COLUMN_NAME,
				TABLE_NAME REF_TABLE_NAME, VIEW_NAME REF_VIEW_NAME, R_COLUMN_NAME REF_COLUMN_NAME, '' COMMENTS
			FROM (
				SELECT 'CONTROL_BREAK$' COLUMN_NAME, 'N' IS_AUDIT_COLUMN, 'N' IS_SEARCHABLE_REF,
					1 POSITION, 'VARCHAR2' DATA_TYPE,
					1024 CHAR_LENGTH, 'Y' NULLABLE, 'N' HAS_HELP_TEXT, '' FORMAT_MASK, 
					'LEFT' COLUMN_ALIGN, 'Control Break' COLUMN_HEADER, data_browser_conf.Enquote_Literal('.') COLUMN_EXPR,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 1024 FIELD_LENGTH, 
					'CONTROL_BREAK$' R_COLUMN_NAME
				FROM SYS.DUAL
				UNION ALL
				SELECT 'LINK_ID$' COLUMN_NAME, 'N' IS_AUDIT_COLUMN, 'N' IS_SEARCHABLE_REF,
					2 POSITION, 'VARCHAR2' DATA_TYPE,
					120 CHAR_LENGTH, 'N' NULLABLE, 'Y' HAS_HELP_TEXT, '' FORMAT_MASK, 
					'CENTER' COLUMN_ALIGN, '' COLUMN_HEADER, 
					data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> UNIQUE_KEY_COLS, p_Table_Alias=> 'A', p_View_Mode=> v_View_Mode) COLUMN_EXPR,
					'LINK_ID' COLUMN_EXPR_TYPE, 120 FIELD_LENGTH, 
					'LINK_ID$' R_COLUMN_NAME
				FROM BROWSER_VIEW
				UNION ALL
				SELECT 'ROW_SELECTOR$' COLUMN_NAME, 'N' IS_AUDIT_COLUMN, 'N' IS_SEARCHABLE_REF,
					3 POSITION, 'VARCHAR2' DATA_TYPE,
					120 CHAR_LENGTH, 'Y' NULLABLE, 'Y' HAS_HELP_TEXT, '' FORMAT_MASK, 
					'CENTER' COLUMN_ALIGN, 'Select' COLUMN_HEADER, data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> UNIQUE_KEY_COLS, p_Table_Alias=> 'A', p_View_Mode=> v_View_Mode) COLUMN_EXPR,
					'ROW_SELECTOR' COLUMN_EXPR_TYPE, 120 FIELD_LENGTH, 
					'ROW_SELECTOR$' R_COLUMN_NAME
				FROM BROWSER_VIEW
				UNION ALL
				SELECT 'DML$_LOGGING_DATE' COLUMN_NAME, 'Y' IS_AUDIT_COLUMN, 'Y' IS_SEARCHABLE_REF,
					4 POSITION, 'TIMESTAMP(6) WITH LOCAL TIME ZONE' DATA_TYPE,
					120 CHAR_LENGTH, 'N' NULLABLE, 'N' HAS_HELP_TEXT, 
					data_browser_conf.Get_Timestamp_Format FORMAT_MASK, 
					'CENTER' COLUMN_ALIGN, 'DML Logging Date' COLUMN_HEADER,
					'TO_CHAR(' 
					|| case when AUDIT_DATE_COLUMN_NAME IS NOT NULL then 
							'NVL2(A.' || data_browser_conf.First_Element(UNIQUE_KEY_COLS) || ', A.DML$_LOGGING_DATE, B.' || AUDIT_DATE_COLUMN_NAME || '),'
							-- Bugfix DS 20230227: use First_Element(p_Key_Column) to avoid error with multible key columns
						else 
							'A.DML$_LOGGING_DATE,'
						end
					|| data_browser_conf.enquote_Literal(data_browser_conf.Get_Timestamp_Format)
					|| ')' COLUMN_EXPR,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 120 FIELD_LENGTH, 
					'DML$_LOGGING_DATE' R_COLUMN_NAME
				FROM BROWSER_VIEW
				WHERE v_View_Mode = 'HISTORY'
				UNION ALL
				SELECT 'DML$_USER_NAME' COLUMN_NAME, 'Y' IS_AUDIT_COLUMN, 'Y' IS_SEARCHABLE_REF,
					5 POSITION, 'VARCHAR2' DATA_TYPE,
					120 CHAR_LENGTH, 'N' NULLABLE, 'N' HAS_HELP_TEXT, '' FORMAT_MASK, 
					'LEFT' COLUMN_ALIGN, 'DML User Name' COLUMN_HEADER, 
					'INITCAP(' 
					|| case when AUDIT_USER_COLUMN_NAME IS NOT NULL then 
							'NVL2(A.' || data_browser_conf.First_Element(UNIQUE_KEY_COLS) || ', A.DML$_USER_NAME, B.' || AUDIT_USER_COLUMN_NAME || ')'
							-- Bugfix DS 20230227: use First_Element(p_Key_Column) to avoid error with multible key columns
						else 
							'A.DML$_USER_NAME'
						end
					|| ')' COLUMN_EXPR,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 120 FIELD_LENGTH, 
					'DML$_USER_NAME' R_COLUMN_NAME
				FROM BROWSER_VIEW
				WHERE v_View_Mode = 'HISTORY'
				UNION ALL
				SELECT 'DML$_ACTION' COLUMN_NAME, 'Y' IS_AUDIT_COLUMN, 'Y' IS_SEARCHABLE_REF,
					6 POSITION, 'VARCHAR2' DATA_TYPE,
					120 CHAR_LENGTH, 'N' NULLABLE, 'N' HAS_HELP_TEXT, '' FORMAT_MASK, 
					'LEFT' COLUMN_ALIGN, 'DML Action' COLUMN_HEADER, q'[apex_lang.lang(case A.DML$_ACTION when 'I' then 'Inserted' when 'U' then 'Updated' when 'D' then 'Deleted'	when 'S' then 'Selected' end)]' COLUMN_EXPR,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 120 FIELD_LENGTH, 
					'DML$_ACTION' R_COLUMN_NAME
				FROM SYS.DUAL
				WHERE v_View_Mode = 'HISTORY'
			) HEAD, BROWSER_VIEW
			UNION ALL
			SELECT --+ INDEX(S) USE_NL_WITH_INDEX(T)
				T.COLUMN_NAME,
				'A' TABLE_ALIAS, 
				T.IS_AUDIT_COLUMN, T.IS_OBFUSCATED, T.IS_UPPER_NAME, 
				T.IS_NUMBER_YES_NO_COLUMN, T.IS_CHAR_YES_NO_COLUMN, T.YES_NO_COLUMN_TYPE, 
				T.IS_SIMPLE_IN_LIST, T.STATIC_LOV_EXPR, T.HAS_AUTOMATIC_CHECK, T.HAS_RANGE_CHECK,
				case when E.COLUMN_NAME IS NOT NULL then 
						case when T.NULLABLE = 'N' and E.DELETE_RULE = 'CASCADE' 
							then 'C'	-- Container 
							else 'Y'	-- Yes
							end
					else 'N'			-- No
				end IS_REFERENCE,
				case when T.DATA_TYPE IN ('BLOB', 'LONG')
					then 'N'
				when (NVL(E.U_MEMBERS, E.R_MEMBERS) = 1 and DBMS_DB_VERSION.VERSION >= 12	-- avoid crashing the runtime process
				 or E.COLUMN_NAME IS NULL)
					then 'Y' else 'N' 
				end IS_SEARCHABLE_REF,
				T.IS_SUMMAND, T.IS_VIRTUAL_COLUMN, 
				data_browser_select.Date_Time_Required(T.DATA_TYPE, v_Data_Format, T.IS_DATETIME) IS_DATETIME,
				T.COLUMN_ID, 1 POSITION, T.DATA_TYPE, 
				case when v_Edit_Mode = 'NO' then T.FORM_DATA_PRECISION else T.DATA_PRECISION end DATA_PRECISION, 
				case when v_Edit_Mode = 'NO' then T.FORM_DATA_SCALE else T.DATA_SCALE end DATA_SCALE, 
				T.DATA_DEFAULT, T.CHAR_LENGTH,
				T.NULLABLE, T.IS_PRIMARY_KEY, T.IS_SEARCH_KEY, T.IS_FOREIGN_KEY, 
				T.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, T.CHECK_UNIQUE,
				T.HAS_HELP_TEXT,
				T.HAS_DEFAULT,
				T.IS_BLOB,
				T.IS_PASSWORD,
				case when E.COLUMN_NAME IS NULL
					and T.COLUMN_NAME != NVL(S.ROW_VERSION_COLUMN_NAME, '-')
					and T.IS_ORDERING_COLUMN = 'N'
					and T.IS_SEARCH_KEY = 'N'
					and T.YES_NO_COLUMN_TYPE IS NULL then
						data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type			=> T.DATA_TYPE, 
							p_Data_Precision	=> case when v_Edit_Mode = 'NO' then T.FORM_DATA_PRECISION else T.DATA_PRECISION end , 
							p_Data_Scale		=> case when v_Edit_Mode = 'NO' then T.FORM_DATA_SCALE else T.DATA_SCALE end, 
							p_Char_Length		=> T.CHAR_LENGTH, 
							p_Use_Group_Separator => case when v_Data_Format IN ('FORM', 'HTML', 'QUERY') then 'Y' else 'N' end, 
							p_Datetime			=> data_browser_select.Date_Time_Required(T.DATA_TYPE, v_Data_Format, T.IS_DATETIME)
						)
				end FORMAT_MASK,
				case when T.YES_NO_COLUMN_TYPE IS NOT NULL then
					data_browser_conf.Get_Yes_No_Static_LOV(T.YES_NO_COLUMN_TYPE)
				when T.IS_SIMPLE_IN_LIST = 'Y' then
					T.STATIC_LOV_EXPR
				when E.DISPLAYED_COLUMN_NAMES IS NOT NULL then
					data_browser_select.Key_Values_Path_Query (
						p_Table_Name		=> E.R_VIEW_NAME,
						p_Display_Col_Names => E.DISPLAYED_COLUMN_NAMES,
						p_Extra_Col_Names	=> NULL,
						p_Search_Key_Col	=> E.R_PRIMARY_KEY_COLS,
						p_Search_Value		=> NULL,
						p_View_Mode			=> v_View_Mode,
						p_Exclude_Col_Name	=> case when E.PARENT_KEY_COLUMN = v_Parent_Key_Column then E.FILTER_KEY_COLUMN end,
						p_Active_Col_Name	=> E.ACTIVE_LOV_COLUMN_NAME,
						p_Active_Data_Type	=> E.ACTIVE_LOV_DATA_TYPE,
						p_Folder_Par_Col_Name	=> E.FOLDER_PARENT_COLUMN_NAME,
						p_Folder_Name_Col_Name => E.FOLDER_NAME_COLUMN_NAME,
						p_Folder_Cont_Col_Name => E.FOLDER_CONTAINER_COLUMN_NAME,
						p_Folder_Cont_Alias => case when E.VIEW_NAME = E.R_VIEW_NAME then 'A' end,
						p_Order_by			=> NVL(E.ORDERING_COLUMN_NAME, '1')
					)
				end LOV_QUERY, -- query for popup list of values
				/*case when E.DISPLAYED_COLUMN_NAMES IS NOT NULL or T.YES_NO_COLUMN_TYPE IS NOT NULL
					then 'LEFT'
					else T.COLUMN_ALIGN
				end COLUMN_ALIGN,*/
				T.COLUMN_ALIGN,
				case when v_View_Mode = 'RECORD_VIEW' 
					then data_browser_conf.Column_Name_to_Header(
						p_Column_Name => T.COLUMN_NAME,
						p_Remove_Extension => 'NO', 
						p_Is_Upper_Name => T.IS_UPPER_NAME)
					else T.COLUMN_HEADER
				end COLUMN_HEADER, 
				case when T.IS_IGNORED = 'Y'
						or T.COLUMN_NAME = S.ROW_VERSION_COLUMN_NAME then -- hidden column
							'A.' || T.COLUMN_NAME
					when v_View_Mode != 'RECORD_VIEW' and E.DISPLAYED_COLUMN_NAMES IS NOT NULL then
						'(' || -- Display from List of values
						data_browser_select.Key_Values_Path_Query (
							p_Table_Name		=> E.R_VIEW_NAME,
							p_Display_Col_Names => E.DISPLAYED_COLUMN_NAMES,
							p_Extra_Col_Names	=> null,
							p_Search_Key_Col	=> E.R_PRIMARY_KEY_COLS,
							p_Search_Value		=> null,
							p_View_Mode			=> v_View_Mode,
							p_Filter_Cond		=> data_browser_conf.Get_Join_Expression( -- support for composite keys
								p_Left_Columns=>E.R_PRIMARY_KEY_COLS, p_Left_Alias=> 'L1',
								p_Right_Columns=>E.COLUMN_NAME, p_Right_Alias=> 'A'),
							p_Exclude_Col_Name	=> case when E.PARENT_KEY_COLUMN = v_Parent_Key_Column then E.FILTER_KEY_COLUMN end,
							p_Folder_Par_Col_Name	=> E.FOLDER_PARENT_COLUMN_NAME,
							p_Folder_Name_Col_Name => E.FOLDER_NAME_COLUMN_NAME,
							p_Folder_Cont_Col_Name => E.FOLDER_CONTAINER_COLUMN_NAME,
							p_Folder_Cont_Alias => case when E.VIEW_NAME = E.R_VIEW_NAME then 'A' end,
							p_Active_Col_Name	=> E.ACTIVE_LOV_COLUMN_NAME,
							p_Active_Data_Type	=> E.ACTIVE_LOV_DATA_TYPE,
							p_Order_by			=> null -- not needed
						)
						|| data_browser_conf.NL(4) || ')' -- display single value 
					when T.IS_OBFUSCATED = 'Y' then
						data_browser_conf.Get_Obfuscate_Call('A.' || T.COLUMN_NAME)
					when (v_Data_Format = 'NATIVE' or v_View_Mode = 'RECORD_VIEW')  -- Bugfix DS 20230611: improved display of record views
					and E.COLUMN_NAME IS NULL then -- for fk columns char conversion is required for control_break expr.
						case when T.IS_SUMMAND = 'Y' and v_Calc_Totals = 'YES' then 
							'SUM(A.' || T.COLUMN_NAME || ')'
						else 
							'A.' || T.COLUMN_NAME
						end 
					when T.YES_NO_COLUMN_TYPE IS NOT NULL and E.COLUMN_NAME IS NULL and v_Data_Format != 'QUERY' then
						data_browser_conf.Get_Yes_No_Static_Function('A.' || T.COLUMN_NAME, T.YES_NO_COLUMN_TYPE)
					when T.COLUMN_NAME = S.MIME_TYPE_COLUMN_NAME and v_Data_Format NOT IN ('NATIVE', 'CSV') then
						data_browser_blobs.File_Type_Name_Call(p_Mime_Type_Column_Name => 'A.' || T.COLUMN_NAME)
					when T.IS_AUDIT_COLUMN = 'Y' and T.CHAR_LENGTH > 0 and v_Data_Format NOT IN ('NATIVE', 'CSV') then
						 data_browser_conf.Get_Formated_User_Name('A.' || T.COLUMN_NAME)
					when E.COLUMN_NAME IS NULL
					and T.COLUMN_NAME != NVL(S.ROW_VERSION_COLUMN_NAME, '-')
					and T.IS_ORDERING_COLUMN = 'N'
					and T.IS_SEARCH_KEY = 'N'
					and T.YES_NO_COLUMN_TYPE IS NULL then -- normal columns
						data_browser_select.Get_ConversionColFunction (
							p_COLUMN_NAME => case when T.IS_SUMMAND = 'Y' and v_Calc_Totals = 'YES' then 
												'SUM(A.' || T.COLUMN_NAME || ')'
											else 'A.' || T.COLUMN_NAME end,
							p_DATA_TYPE => T.DATA_TYPE,
							p_DATA_PRECISION => case when v_Edit_Mode = 'NO' then T.FORM_DATA_PRECISION else T.DATA_PRECISION end ,
							p_DATA_SCALE => case when v_Edit_Mode = 'NO' then T.FORM_DATA_SCALE else T.DATA_SCALE end,
							p_CHAR_LENGTH => T.CHAR_LENGTH,
							p_Data_Format => v_Data_Format,
							p_USE_TRIM => 'Y', -- trimming of formated numbers is required for input fields.
							p_DATETIME => T.IS_DATETIME
						)
					else									-- special columns
						data_browser_select.Get_ConversionColFunction (
							p_COLUMN_NAME => 'A.' || T.COLUMN_NAME,
							p_DATA_TYPE => T.DATA_TYPE,
							p_DATA_PRECISION => case when v_Edit_Mode = 'NO' then T.FORM_DATA_PRECISION else T.DATA_PRECISION end ,
							p_DATA_SCALE => case when v_Edit_Mode = 'NO' then T.FORM_DATA_SCALE else T.DATA_SCALE end,
							p_CHAR_LENGTH => T.CHAR_LENGTH,
							p_Data_Format => 'CSV',
							p_USE_TRIM => 'N',
							p_DATETIME => T.IS_DATETIME
						)
				end COLUMN_EXPR, ---------------------------------------------------------
				case when v_View_Mode != 'RECORD_VIEW'
				and T.COLUMN_NAME = S.FILE_CONTENT_COLUMN_NAME
				and T.IS_BLOB = 'Y' then
					'FILE_BROWSER'
				when T.IS_SEARCH_KEY = 'Y'		-- primary key shouldn´t be input field
				and S.HAS_SCALAR_KEY = 'YES'	-- primary key is managed automatically
				and T.IS_DISPLAYED_KEY_COLUMN = 'N' 
				and E.COLUMN_NAME IS NULL then	-- In View Mode FORM_VIEW foreign keys are popup fields
					case when data_browser_select.FN_List_Offest(v_Select_Columns, T.COLUMN_NAME) = 0 then -- not visible
						'HIDDEN' else 'DISPLAY_AND_SAVE'
					end
				when T.IS_IGNORED = 'Y'
				or T.COLUMN_NAME = S.ROW_VERSION_COLUMN_NAME 
					then 'HIDDEN'
				when T.COLUMN_NAME IN (S.MIME_TYPE_COLUMN_NAME, S.FILE_DATE_COLUMN_NAME) -- file meta data
				or T.IS_VIRTUAL_COLUMN = 'Y'
				or T.IS_OBFUSCATED = 'Y'
				or (T.IS_AUDIT_COLUMN = 'Y' and T.HAS_DEFAULT = 'Y')
				or (T.IS_READONLY = 'Y' and T.IS_CHECKED = 'N') then
					'DISPLAY_ONLY'
				when T.IS_READONLY = 'Y' then
					'DISPLAY_AND_SAVE'
				when v_View_Mode = 'RECORD_VIEW' then
					data_browser_conf.Get_Column_Expr_Type(T.COLUMN_NAME, T.DATA_TYPE, T.CHAR_LENGTH, T.IS_READONLY)
				when T.IS_ORDERING_COLUMN = 'Y'
					and T.DATA_TYPE = 'NUMBER' then
					'ORDERING_MOVER'
				when T.IS_SIMPLE_IN_LIST = 'Y' then 
					'SELECT_LIST'
				when T.YES_NO_COLUMN_TYPE IS NOT NULL then
					'SELECT_LIST'
				when E.DISPLAYED_COLUMN_NAMES IS NOT NULL
					and INSTR(E.DISPLAYED_COLUMN_NAMES, ',') = 0 -- only single column display values
					and NVL(E.R_NUM_ROWS, 0) < data_browser_conf.Get_Select_List_Rows_Limit then
					'SELECT_LIST_FROM_QUERY'
				when E.DISPLAYED_COLUMN_NAMES IS NOT NULL then
					'POPUPKEY_FROM_LOV'
				else
					data_browser_conf.Get_Column_Expr_Type(T.COLUMN_NAME, T.DATA_TYPE, T.CHAR_LENGTH, T.IS_READONLY)
				end COLUMN_EXPR_TYPE, ----------------------------------------------------
				case when E.COLUMN_NAME IS NOT NULL then 
					1024
				else 
					T.FIELD_LENGTH -- (including group separator)
				end FIELD_LENGTH,
				case 
					when E.R_VIEW_NAME = v_Parent_Name AND E.COLUMN_NAME = NVL(v_Parent_Key_Column, E.COLUMN_NAME)
							--the fk columns are hidden items by default for NAVIGATION_VIEW, NESTED_VIEW because the rows a grouped by the column 
							--the control-break displays the fk column labels
						then 'Y'
					when (T.IS_DISPLAYED_KEY_COLUMN = 'Y'
							OR T.IS_PRIMARY_KEY = 'Y'
							OR T.COLUMN_NAME = S.ORDERING_COLUMN_NAME
							OR T.IS_SUMMAND = 'Y' 
							OR T.IS_MINUEND = 'Y'
							OR v_View_Mode NOT IN ('NAVIGATION_VIEW', 'NESTED_VIEW')
						) 
						then T.DISPLAY_IN_REPORT
					else 'N'
				end DISPLAY_IN_REPORT, -- is the column visible the the default report column projection
				T.TABLE_NAME R_TABLE_NAME, 
				T.VIEW_NAME R_VIEW_NAME, 
				T.COLUMN_NAME R_COLUMN_NAME,
				NVL(E.R_TABLE_NAME, T.TABLE_NAME) REF_TABLE_NAME, 
				NVL(E.R_VIEW_NAME, T.VIEW_NAME) REF_VIEW_NAME, 
				T.COLUMN_NAME REF_COLUMN_NAME,
				T.COMMENTS
			FROM MVDATA_BROWSER_SIMPLE_COLS T
			JOIN BROWSER_VIEW S ON S.VIEW_NAME = T.VIEW_NAME
			LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES E ON T.VIEW_NAME = E.VIEW_NAME 
				AND E.FK_COLUMN_ID = T.COLUMN_ID -- support for composite keys
				AND T.COLUMN_NAME = E.COLUMN_NAME -- currently this filter is required, special case has to be handled: fk to A and to A,B
			WHERE (T.IS_IGNORED = 'N' OR T.IS_PRIMARY_KEY = 'Y')
			AND (T.IS_DATA_DEDUCTED = 'N' OR data_browser_conf.Check_Data_Deduction(T.COLUMN_NAME) = 'NO')
			AND NOT(v_View_Mode = 'HISTORY' and (T.IS_VIRTUAL_COLUMN = 'Y' or T.DATA_TYPE = 'LONG'))
			AND T.VIEW_NAME = v_View_Name
			UNION ALL --------------------------------------------------------------------
			SELECT -- Navigation View --
				COLUMN_NAME || case when COUNT(*) OVER (PARTITION BY REF_VIEW_NAME, COLUMN_NAME) > 1
					then DENSE_RANK() OVER (PARTITION BY REF_VIEW_NAME, COLUMN_NAME ORDER BY POSITION) -- run_no
				end COLUMN_NAME,
				'' TABLE_ALIAS,
				'N' IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
				'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
				'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
				'Y' IS_REFERENCE, 'Y' IS_SEARCHABLE_REF, 'Y' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 'N' IS_DATETIME,
				POSITION + 1000 COLUMN_ID,
				1 POSITION,
				'VARCHAR2' DATA_TYPE, 0 DATA_PRECISION, 0 DATA_SCALE, DATA_DEFAULT, 0 CHAR_LENGTH, NULLABLE,
				'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, 'N' IS_FOREIGN_KEY, 'N' IS_DISP_KEY_COLUMN,
				'N' CHECK_UNIQUE,
				'Y' HAS_HELP_TEXT,
				'N' HAS_DEFAULT,
				'N' IS_BLOB,
				'N' IS_PASSWORD,
				'' FORMAT_MASK,
				ROW_COUNT_QUERY LOV_QUERY,
				'CENTER' COLUMN_ALIGN,
				data_browser_conf.Concat_List(
					p_First_Name=> COLUMN_HEADER, p_Second_Name => Apex_lang.lang('Count'), p_Delimiter=>' - '
				) COLUMN_HEADER,
				FORMATED_ROW_COUNT_QUERY COLUMN_EXPR,
				'LINK' COLUMN_EXPR_TYPE, 1024 FIELD_LENGTH,
				case when v_View_Mode = 'NAVIGATION_VIEW' then 
					'Y' else 'N'
				end DISPLAY_IN_REPORT,	-- Reference-Counters are shown in NAVIGATION_VIEW by default
				R_TABLE_NAME, R_VIEW_NAME, R_COLUMN_NAME,
				REF_TABLE_NAME, REF_VIEW_NAME, REF_COLUMN_NAME, COMMENTS
			FROM (
				SELECT POSITION,
					S.REF_TABLE_NAME,
					S.REF_VIEW_NAME,
					S.REF_COLUMN_NAME,
					data_browser_conf.Compose_Column_Name(
						p_First_Name=> data_browser_conf.Compose_Column_Name(
							p_First_Name=> data_browser_conf.Normalize_Table_Name(p_Table_Name => S.R_VIEW_NAME)
							, p_Second_Name => data_browser_conf.Normalize_Column_Name(S.R_COLUMN_NAME) 
							, p_Deduplication=>'YES', p_Max_Length=>29)
						, p_Second_Name => 'COUNT', p_Deduplication=>'NO', p_Max_Length=>29
					) COLUMN_NAME,
					COLUMN_HEADER,
					COLUMN_PREFIX,
					NULLABLE,
					case when v_Data_Format = 'NATIVE' then 
						S.ROW_COUNT_QUERY
					else 
						data_browser_select.Get_ConversionColFunction (
							p_Column_Name => S.ROW_COUNT_QUERY,
							p_Data_Type => DATA_TYPE,
							p_Data_Precision => LEAST(DATA_PRECISION + 10, 38),
							p_Data_Scale => DATA_SCALE,
							p_Char_Length => CHAR_LENGTH,
							p_Data_Format => v_Data_Format,
							p_Use_Trim => 'Y',
							p_Datetime => 'N'
						) 
					end FORMATED_ROW_COUNT_QUERY,
					S.R_TABLE_NAME,
					S.R_VIEW_NAME,
					S.R_COLUMN_NAME,
					S.LINK_EXPR, 
					S.ROW_COUNT_QUERY,
					DATA_TYPE, DATA_PRECISION, DATA_SCALE, DATA_DEFAULT, CHAR_LENGTH, COMMENTS
				FROM ( -- counter column for each foreign key referencing the current row.
					SELECT --+ INDEX(S) USE_NL_WITH_INDEX(A)
						DENSE_RANK() OVER (PARTITION BY E.R_VIEW_NAME ORDER BY E.TABLE_NAME, E.COLUMN_NAME) POSITION,
						data_browser_select.Reference_Column_Header (
							p_Column_Name => E.COLUMN_NAME,
							p_Remove_Prefix => S.COLUMN_PREFIX,
							p_View_Name => E.VIEW_NAME,
							p_R_View_Name => E.R_VIEW_NAME
						) COLUMN_HEADER, 
						E.R_VIEW_NAME REF_VIEW_NAME,
						E.R_TABLE_NAME REF_TABLE_NAME,
						E.R_PRIMARY_KEY_COLS REF_COLUMN_NAME,
						A.NULLABLE,
						E.TABLE_NAME R_TABLE_NAME,
						E.VIEW_NAME R_VIEW_NAME,
						E.COLUMN_NAME R_COLUMN_NAME,
						S.COLUMN_PREFIX,
						E.R_UNIQUE_KEY_COLS,
						data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> E.R_UNIQUE_KEY_COLS, p_Table_Alias=> 'A', p_View_Mode=> v_View_Mode) LINK_EXPR,
						case when v_Calc_Totals = 'YES' then 'SUM(' end
						|| '(SELECT COUNT(*) ' || data_browser_conf.NL(4)
						|| ' FROM ' || data_browser_conf.Enquote_Name_Required(E.VIEW_NAME) 
						|| ' B ' || data_browser_conf.NL(4)
						|| ' WHERE '
						|| data_browser_conf.Get_Join_Expression(
							p_Left_Columns=>E.COLUMN_NAME, p_Left_Alias=> 'B',
							p_Right_Columns=>A.COLUMN_NAME, p_Right_Alias=> 'A')
						|| data_browser_conf.NL(4)
						|| ')' 
						|| case when v_Calc_Totals = 'YES' then ')' end
						ROW_COUNT_QUERY,
						DATA_TYPE, 
						case when v_Edit_Mode = 'NO' then A.FORM_DATA_PRECISION else A.DATA_PRECISION end  DATA_PRECISION, 
						case when v_Edit_Mode = 'NO' then A.FORM_DATA_SCALE else A.DATA_SCALE end DATA_SCALE, 
						DATA_DEFAULT, CHAR_LENGTH, A.COMMENTS
					FROM MVDATA_BROWSER_SIMPLE_COLS A
					JOIN BROWSER_VIEW S ON S.VIEW_NAME = A.VIEW_NAME
					JOIN MVDATA_BROWSER_REFERENCES E ON E.R_PRIMARY_KEY_COLS = A.COLUMN_NAME AND E.R_VIEW_NAME = S.VIEW_NAME
					WHERE A.VIEW_NAME =	 v_View_Name
				) S
			) S
			UNION ALL --------------------------------------------------------------------------------------
			SELECT -- totals build from summand or minuend columns.
				COLUMN_NAME || case when COUNT(*) OVER (PARTITION BY VIEW_NAME, COLUMN_NAME) > 1
					then DENSE_RANK() OVER (PARTITION BY VIEW_NAME, COLUMN_NAME ORDER BY POSITION) -- run_no
				end COLUMN_NAME,
				'' TABLE_ALIAS,
				'N' IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
				'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
				'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
				'Y' IS_REFERENCE, 'Y' IS_SEARCHABLE_REF, 'Y' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 'N' IS_DATETIME,
				POSITION + 2000 COLUMN_ID,
				2 POSITION,
				S.DATA_TYPE, S.DATA_PRECISION, S.DATA_SCALE, S.DATA_DEFAULT, S.CHAR_LENGTH, S.NULLABLE,
				'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, 'N' IS_FOREIGN_KEY, 'N' IS_DISP_KEY_COLUMN,
				'N' CHECK_UNIQUE,
				'Y' HAS_HELP_TEXT,
				'N' HAS_DEFAULT,
				'N' IS_BLOB,
				'N' IS_PASSWORD,
				FORMAT_MASK,
				TOTAL_QUERY LOV_QUERY,
				'RIGHT' COLUMN_ALIGN,
				COLUMN_HEADER,
				COLUMN_EXPR,
				'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 40 FIELD_LENGTH,
				case when v_View_Mode IN ('NAVIGATION_VIEW', 'NESTED_VIEW') then 
					'Y' else 'N'
				end DISPLAY_IN_REPORT,	-- Summands are shown in NAVIGATION_VIEW, NESTED_VIEW by default
				R_TABLE_NAME, R_VIEW_NAME, R_COLUMN_NAME,
				R_TABLE_NAME REF_TABLE_NAME, R_VIEW_NAME REF_VIEW_NAME, R_COLUMN_NAME REF_COLUMN_NAME, COMMENTS
			FROM (
				SELECT POSITION,
					S.VIEW_NAME,
					data_browser_conf.Compose_Column_Name(
						p_First_Name=> data_browser_conf.Compose_Column_Name(
							p_First_Name=> data_browser_conf.Normalize_Table_Name(p_Table_Name => S.R_VIEW_NAME)
							, p_Second_Name => data_browser_conf.Normalize_Column_Name(S.COLUMN_NAME)
							, p_Deduplication=>'YES', p_Max_Length=>29)
						, p_Second_Name => 'TOTAL', p_Deduplication=>'NO', p_Max_Length=>29
					) COLUMN_NAME,
					data_browser_conf.Column_Name_to_Header(
						p_Column_Name => data_browser_conf.Compose_Column_Name(
							p_First_Name=> COLUMN_HEADER
							, p_Second_Name => S.COLUMN_NAME
							, p_Deduplication=>'YES', p_Max_Length=>128
						),
						p_Remove_Extension => 'YES', 
						p_Remove_Prefix => S.COLUMN_PREFIX,
						p_Is_Upper_Name => data_browser_pattern.Match_Upper_Names_Columns(S.COLUMN_NAME)
					) COLUMN_HEADER,
					COLUMN_PREFIX, 
					DATA_TYPE, DATA_PRECISION, DATA_SCALE, DATA_DEFAULT, CHAR_LENGTH, IS_DATETIME, NULLABLE, FORMAT_MASK,
					data_browser_select.Get_ConversionColFunction (
						p_COLUMN_NAME => TOTAL_QUERY,
						p_DATA_TYPE => DATA_TYPE,
						p_DATA_PRECISION => LEAST(DATA_PRECISION + 10, 38),
						p_DATA_SCALE => DATA_SCALE,
						p_CHAR_LENGTH => CHAR_LENGTH,
						p_Data_Format => v_Data_Format,
						p_USE_TRIM => 'Y',
						p_DATETIME => 'N'
					) COLUMN_EXPR,
					TOTAL_QUERY,
					R_VIEW_NAME,
					R_TABLE_NAME,
					S.COLUMN_NAME R_COLUMN_NAME,
					COMMENTS
				FROM ( -- counter column for each foreign key referencing the current row.
				   SELECT 
						DENSE_RANK() OVER (PARTITION BY E.R_VIEW_NAME ORDER BY E.TABLE_NAME, E.COLUMN_NAME, E.JOINS, E.R_COLUMN_NAME) POSITION,
						-- POSITION is appended to the column_name to avoiad duplicate names.
						DENSE_RANK() OVER (PARTITION BY E.VIEW_NAME, A.COLUMN_NAME ORDER BY E.TABLE_ALIAS) RANKING,
						data_browser_select.Reference_Column_Header (
							p_Column_Name => E.COLUMN_NAME,
							p_Remove_Prefix => S.COLUMN_PREFIX,
							p_View_Name => E.VIEW_NAME,
							p_R_View_Name => E.R_VIEW_NAME
						) COLUMN_HEADER, 
						E.R_VIEW_NAME VIEW_NAME, A.COLUMN_NAME,
						A.DATA_TYPE, 
						case when v_Edit_Mode = 'NO' then A.FORM_DATA_PRECISION else A.DATA_PRECISION end DATA_PRECISION, 
						case when v_Edit_Mode = 'NO' then A.FORM_DATA_SCALE else A.DATA_SCALE end DATA_SCALE, 
						A.DATA_DEFAULT, 
						A.CHAR_LENGTH, A.IS_DATETIME, A.NULLABLE, A.COMMENTS,
						data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type			=> A.DATA_TYPE, 
							p_Data_Precision	=> case when v_Edit_Mode = 'NO' then A.FORM_DATA_PRECISION else A.DATA_PRECISION end, 
							p_Data_Scale		=> case when v_Edit_Mode = 'NO' then A.FORM_DATA_SCALE else A.DATA_SCALE end, 
							p_Char_Length		=> A.CHAR_LENGTH, 
							p_Use_Group_Separator => case when v_Data_Format IN ('FORM', 'HTML', 'QUERY') then 'Y' else 'N' end, 
							p_Datetime			=> A.IS_DATETIME
						) FORMAT_MASK,
						E.VIEW_NAME R_VIEW_NAME,
						E.TABLE_NAME R_TABLE_NAME,
						E.COLUMN_NAME R_COLUMN_NAME,
						S.COLUMN_PREFIX,
						E.R_UNIQUE_KEY_COLS UNIQUE_KEY_COLS,
						case when v_Calc_Totals = 'YES' then 'SUM(' end
						||'(SELECT ' 
						|| case when A.IS_MINUEND = 'Y' then '-' end
						|| 'SUM(' || E.TABLE_ALIAS || '.' || A.COLUMN_NAME || ')' || data_browser_conf.NL(4)
						|| ' FROM ' || SUBSTR(E.JOINS, 7)  || data_browser_conf.NL(4)
						|| ' WHERE ' 
						|| data_browser_conf.Get_Join_Expression(
							p_Left_Columns=>E.R_COLUMN_NAME, p_Left_Alias=> 'B',
							p_Right_Columns=>E.R_PRIMARY_KEY_COLS , p_Right_Alias=> 'A')
						|| case when E.ACTIVE_LOV_COLUMN_NAME IS NOT NULL then 
							' AND ' || E.TABLE_ALIAS || '.' || E.ACTIVE_LOV_COLUMN_NAME 
							|| ' = ' || data_browser_conf.Get_Boolean_Yes_Value(E.ACTIVE_LOV_DATA_TYPE, 'ENQUOTE')
						end
						|| data_browser_conf.NL(4)
						|| ')' 
						|| case when v_Calc_Totals = 'YES' then ')' end
						TOTAL_QUERY
					FROM (
						SELECT R.*,
							  D.ACTIVE_LOV_COLUMN_NAME, D.ACTIVE_LOV_DATA_TYPE
						FROM (
							SELECT 
								CHR(ASCII('A') + LEVEL) as TABLE_ALIAS, 
								SYS_CONNECT_BY_PATH(
									data_browser_conf.Enquote_Name_Required(VIEW_NAME) || ' ' || CHR(ASCII('A') + LEVEL)
									|| case when level > 1 then
										' ON '	
										|| data_browser_conf.Get_Join_Expression(
											p_Left_Columns=>COLUMN_NAME, p_Left_Alias=> CHR(ASCII('A') + LEVEL),
											p_Right_Columns=>R_PRIMARY_KEY_COLS , p_Right_Alias=> CHR(ASCII('A') + LEVEL -1))
									end, 
									' JOIN '
								) JOINS,
								VIEW_NAME, TABLE_NAME, COLUMN_NAME,
								CONNECT_BY_ROOT COLUMN_NAME as R_COLUMN_NAME, 
								CONNECT_BY_ROOT R_VIEW_NAME as R_VIEW_NAME, 
								CONNECT_BY_ROOT R_PRIMARY_KEY_COLS as R_PRIMARY_KEY_COLS,  
								CONNECT_BY_ROOT R_UNIQUE_KEY_COLS as R_UNIQUE_KEY_COLS
							 FROM MVDATA_BROWSER_REFERENCES 
							 WHERE VIEW_NAME != v_View_Name -- avoid self references. I think that makes no sense.
							START WITH R_VIEW_NAME = v_View_Name
							CONNECT BY NOCYCLE R_VIEW_NAME = PRIOR VIEW_NAME AND LEVEL <= 5
						) R JOIN MVDATA_BROWSER_DESCRIPTIONS D ON R.VIEW_NAME = D.VIEW_NAME
					) E 
					CROSS JOIN BROWSER_VIEW S 
					JOIN MVDATA_BROWSER_SIMPLE_COLS A ON E.VIEW_NAME = A.VIEW_NAME
					WHERE A.DATA_TYPE IN ('NUMBER', 'FLOAT')
					AND A.COLUMN_NAME != E.COLUMN_NAME -- exclude the  foreign key column
					AND (A.IS_SUMMAND = 'Y' OR A.IS_MINUEND = 'Y')
				) S
				WHERE S.RANKING = 1
			) S
			UNION ALL -------------------------------------------------------------------------------------
			SELECT -- nested views with navigations links
				COLUMN_NAME || case when COUNT(*) OVER (PARTITION BY VIEW_NAME, COLUMN_NAME) > 1
					then DENSE_RANK() OVER (PARTITION BY VIEW_NAME, COLUMN_NAME ORDER BY POSITION) -- run_no
				end COLUMN_NAME,
				'' TABLE_ALIAS,
				'N' IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
				'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
				'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
				'Y' IS_REFERENCE, 'N' IS_SEARCHABLE_REF, 'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 'N' IS_DATETIME,
				POSITION + 1000 COLUMN_ID,
				1 POSITION,
				'VARCHAR2' DATA_TYPE, 0 DATA_PRECISION, 0 DATA_SCALE, '' DATA_DEFAULT, 
				0 CHAR_LENGTH, NULLABLE,
				'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, 'N' IS_FOREIGN_KEY, 'N' IS_DISP_KEY_COLUMN,
				'N' CHECK_UNIQUE,
				'Y' HAS_HELP_TEXT,
				'N' HAS_DEFAULT,
				'N' IS_BLOB,
				'N' IS_PASSWORD,
				'' FORMAT_MASK,
				'' LOV_QUERY,
				'LEFT' COLUMN_ALIGN,
				COLUMN_HEADER,
				data_browser_select.Child_Link_List_Query (
					p_Table_Name  => CHILD_VIEW,
					p_Display_Col_Names	 => DISPLAYED_COLUMN_NAMES,
					p_Search_Key_Col => DETAIL_KEY,
					p_Search_Value	=> 'A.' || DETAIL_ID,
					p_View_Mode		=> v_View_Mode,
					p_Data_Format	=> v_Data_Format,
					p_Key_Column	=> KEY_COLUMNS, -- DETAIL_ID, -- bug with EBA_DP_VIEWER_GROUP_REF
					p_Target1		=> TARGET1PAR || '||' || TARGET1VAL,
					p_Target2		=> TARGET2PAR || '||' || TARGET2VAL,
					p_Detail_Page_ID=> v_Detail_Page_ID,
					p_Link_Page_ID	=> v_Link_Page_ID
				) COLUMN_EXPR,
				'LINK_LIST' COLUMN_EXPR_TYPE, 1024 FIELD_LENGTH,
				case when v_View_Mode = 'NESTED_VIEW' then 
					'Y' else 'N'
				end DISPLAY_IN_REPORT,	-- navigations links a shown in NESTED_VIEW by default
				CHILD_TABLE R_TABLE_NAME, CHILD_VIEW R_VIEW_NAME, DETAIL_KEY R_COLUMN_NAME,
				CHILD_TABLE REF_TABLE_NAME, CHILD_VIEW REF_VIEW_NAME, DETAIL_KEY REF_COLUMN_NAME, COMMENTS
			FROM (
				SELECT POSITION,
					S.VIEW_NAME,
					data_browser_conf.Compose_Column_Name(
						p_First_Name=> data_browser_conf.Compose_Column_Name(
							p_First_Name=> data_browser_conf.Normalize_Table_Name(p_Table_Name => S.R_VIEW_NAME)
							, p_Second_Name => data_browser_conf.Normalize_Column_Name(S.R_COLUMN_NAME)
							, p_Deduplication=>'YES', p_Max_Length=>29)
						, p_Second_Name => 'LINK', p_Deduplication=>'NO', p_Max_Length=>29
					) COLUMN_NAME,
					data_browser_conf.Concat_List(
							p_First_Name=> COLUMN_HEADER, p_Second_Name => Apex_lang.lang('Links'), p_Delimiter=>' - '
					) COLUMN_HEADER,
					COLUMN_PREFIX,
					NULLABLE,
					'PAR.TARGET1||'
					|| DBMS_ASSERT.ENQUOTE_LITERAL(':')
					TARGET1PAR,
					DBMS_ASSERT.ENQUOTE_LITERAL(S.R_VIEW_NAME	-- TABLE_NAME
					|| ',' || S.VIEW_NAME || ',')				-- PARENT_NAME
					TARGET1VAL, -- one row of referenced table
					'PAR.TARGET2||'
					|| DBMS_ASSERT.ENQUOTE_LITERAL(':')
					TARGET2PAR,
					DBMS_ASSERT.ENQUOTE_LITERAL(
						S.VIEW_NAME || ','		-- TABLE_NAME
						|| v_Parent_Name || ',' -- PARENT_NAME
					)
					|| '||'
					|| data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> S.UNIQUE_KEY_COLS, p_Table_Alias=> 'A', p_View_Mode=> v_View_Mode) -- LINK_ID
					|| '||'
					|| DBMS_ASSERT.ENQUOTE_LITERAL(','
					|| S.R_VIEW_NAME || ','		-- DETAIL_TABLE
					|| S.R_COLUMN_NAME)			-- DETAIL_KEY
					TARGET2VAL, -- all matching rows of referenced table
					S.CHILD_VIEW,
					S.CHILD_TABLE,
					S.DISPLAYED_COLUMN_NAMES,
					S.R_COLUMN_NAME DETAIL_KEY,
					S.COLUMN_NAME DETAIL_ID,
					S.SEARCH_KEY_COLS KEY_COLUMNS,
					S.COMMENTS
				FROM (
					SELECT --+ INDEX(S) USE_NL_WITH_INDEX(A)
						DENSE_RANK() OVER (PARTITION BY E.R_VIEW_NAME ORDER BY E.TABLE_NAME, E.COLUMN_NAME) POSITION,
						data_browser_select.Reference_Column_Header (
							p_Column_Name => E.COLUMN_NAME,
							p_Remove_Prefix => S.COLUMN_PREFIX,
							p_View_Name => E.VIEW_NAME,
							p_R_View_Name => E.R_VIEW_NAME
						) COLUMN_HEADER, 
						E.R_VIEW_NAME VIEW_NAME,
						E.R_PRIMARY_KEY_COLS COLUMN_NAME,
						A.NULLABLE,
						E.VIEW_NAME R_VIEW_NAME,
						E.TABLE_NAME R_TABLE_NAME,
						E.COLUMN_NAME R_COLUMN_NAME,
						S.COLUMN_PREFIX,
						NVL(S.UNIQUE_KEY_COLS, E.R_UNIQUE_KEY_COLS) UNIQUE_KEY_COLS,
						D.VIEW_NAME CHILD_VIEW,
						D.TABLE_NAME CHILD_TABLE,
						D.DISPLAYED_COLUMN_NAMES,
						D.SEARCH_KEY_COLS,
						A.COMMENTS
					FROM MVDATA_BROWSER_SIMPLE_COLS A
					JOIN BROWSER_VIEW S ON S.VIEW_NAME = A.VIEW_NAME
					JOIN MVDATA_BROWSER_REFERENCES E ON E.R_PRIMARY_KEY_COLS = A.COLUMN_NAME AND E.R_VIEW_NAME = S.VIEW_NAME
					JOIN MVDATA_BROWSER_DESCRIPTIONS D ON D.VIEW_NAME = E.VIEW_NAME
					WHERE A.VIEW_NAME =	 v_View_Name
				) S
			) S
		)
		ORDER BY COLUMN_ORDER;
	--------------------------------------------------------------------------------------
	/*
	simple_cols: all simple col with alias A. 
		FK cols are HIDDEN fields.
	f_refs: all 1. level natural key columns of direct references from table A => alias B. 
		FK cols are HIDDEN fields. (join options A, K)
	q_refs: all 2. level natural key columns of indirect references from frefs => alias B_A. 
		FK cols are excluded fields. (join options A, K)

	fc_refs: all 1. level table columns of direct references from table A => alias B. 
		FK cols are HIDDEN fields. (join options A)
	qc_refs: all 2. level table columns of indirect references from frefs => alias B_A. 
		FK cols are excluded fields. (join options A)
	------------------------------------------------------------------------------------------	
	*/
	CURSOR Describe_Imp_Cols_cur (
		v_View_Name VARCHAR2,				-- Table Name or View Name of master table
		v_Unique_Key_Column VARCHAR2,		-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		v_View_Mode VARCHAR2,				-- IMPORT_VIEW, EXPORT_VIEW. If IMPORT_VIEW and Data_Columns_Only = NO then columns named IMPORTJOB_ID$ and LINE_NO$ are included in the generated Column list
		v_Data_Format VARCHAR2,				-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		v_Use_Group_Separator VARCHAR2,		-- Y,N; use G in number format mask
		v_Select_Columns VARCHAR2,			-- Select Column names of the final projection, Optional
		v_Parent_Name VARCHAR2,				-- Parent View or Table name. if set columns from the view are included in the Column list in View_Mode NAVIGATION_VIEW
		v_Parent_Key_Column VARCHAR2,		-- Column Name with foreign key to Parent Table
		v_Parent_Key_Visible VARCHAR2,
		v_Join_Options VARCHAR2				-- Encoded join options. When empty, only key columns of joined tables are included in the generated Column list
	)
	IS
		WITH JOIN_OPTIONS AS ( -- decode join options from v_Join_Options. Example : 'B;K:C;K:D;N'
			select	--+ CARDINALITY(10)
			SUBSTR(COLUMN_VALUE, 1, OFFSET1-1) TABLE_ALIAS, -- A, B, C, D, E ...
				SUBSTR(COLUMN_VALUE, OFFSET1+1) COLUMNS_INCLUDED -- one of: K, A, N
			from (
				select INSTR(COLUMN_VALUE, ';') OFFSET1, COLUMN_VALUE from TABLE( apex_string.split(v_Join_Options, ':')) N
			)
		), BROWSER_VIEW AS (
			SELECT VIEW_NAME, TABLE_NAME, NVL(v_Unique_Key_Column, SEARCH_KEY_COLS) UNIQUE_KEY_COLS,
				ROW_VERSION_COLUMN_NAME, HAS_SCALAR_KEY, FILE_FOLDER_COLUMN_NAME,
				FILE_NAME_COLUMN_NAME, MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME, FILE_CONTENT_COLUMN_NAME,
				COLUMN_PREFIX
			FROM MVDATA_BROWSER_VIEWS 
			WHERE VIEW_NAME = v_View_Name
		)
		SELECT COLUMN_NAME, TABLE_ALIAS, 
			ROW_NUMBER() OVER (ORDER BY COLUMN_ORDER NULLS LAST					-- ordered from left to right by v_Select_Columns
					, TABLE_ALIAS												-- natural order of joined columns
					, case when IS_DISP_KEY_COLUMN = 'Y' then 0 else 1 end
					, case when DISPLAY_IN_REPORT = 'Y' then 0 else 1 end
					, IS_AUDIT_COLUMN
					, COLUMN_ID, R_COLUMN_ID, POSITION, COLUMN_NAME) COLUMN_ORDER, 
			COLUMN_ID, POSITION,
			case when HAS_COLLECTION_NUM_INDEX = 1 and COLLECTION_NUM_INDEX <= 5 then
					'N' || LPAD(COLLECTION_NUM_INDEX, 3, '0')	-- apex_collections fields for hidden unique key columns
				when HAS_COLLECTION_CHAR_INDEX = 1 then
					'C' || LPAD(
						SUM(case when HAS_COLLECTION_CHAR_INDEX = 1 then 1 else 0 end)
							OVER (ORDER BY COLUMN_ORDER NULLS LAST							-- ordered from left to right by v_Select_Columns
								, TABLE_ALIAS												-- natural order of joined columns
								, case when IS_DISP_KEY_COLUMN = 'Y' then 0 else 1 end
								, case when DISPLAY_IN_REPORT = 'Y' then 0 else 1 end	-- or use default order (visible first)
								, COLUMN_ID, R_COLUMN_ID, POSITION RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
					), 3, '0')	-- collection fields for input columns
				when HAS_COLLECTION_NUM_INDEX = 1 and COLLECTION_NUM_INDEX > 5-- over limit of 5 number fields in apex_collections
					or HAS_COLLECTION_HIDDEN_INDEX = 1 and COLLECTION_HIDDEN_INDEX > 0 then -- find space for hidden char keys 
					'C' || LPAD(
						data_browser_conf.Get_Collection_Columns_Limit + 1 -
						SUM(case when (HAS_COLLECTION_NUM_INDEX = 1 and COLLECTION_NUM_INDEX > 5)
									or HAS_COLLECTION_HIDDEN_INDEX = 1 and COLLECTION_HIDDEN_INDEX > 0 then 1 else 0 end)
							OVER (ORDER BY COLUMN_ORDER NULLS LAST							-- ordered from left to right by v_Select_Columns
								, TABLE_ALIAS												-- natural order of joined columns
								, case when IS_DISP_KEY_COLUMN = 'Y' then 0 else 1 end
								, case when DISPLAY_IN_REPORT = 'Y' then 0 else 1 end	-- or use default order (visible first)
								, COLUMN_ID, R_COLUMN_ID, POSITION RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
					), 3, '0')	-- apex_collections fields for hidden unique key columns, when more than 5 are needed.
			end INPUT_ID,
			SUM(case when COLUMN_EXPR_TYPE != 'HIDDEN' and COLUMN_ID > 0 then 1 else 0  end) 
				OVER (ORDER BY COLUMN_ORDER NULLS LAST							-- ordered from left to right by v_Select_Columns
					, TABLE_ALIAS												-- natural order of joined columns
					, case when IS_DISP_KEY_COLUMN = 'Y' then 0 else 1 end
					, case when DISPLAY_IN_REPORT = 'Y' then 0 else 1 end
					, IS_AUDIT_COLUMN
					, COLUMN_ID
					, case when COLUMN_EXPR_TYPE != 'HIDDEN' and COLUMN_ID > 0 then 0 else 1  end
					-- there are multiple items per COLUMN_ID.
					-- move hidden items to the begin of a group, so that visible items have the same index number as the hidden items
					, R_COLUMN_ID, POSITION, COLUMN_NAME) REPORT_COLUMN_ID,-- used to calculate the vivible report coöumn id that must be below the p_Column_Limit
			DATA_TYPE, DATA_PRECISION, DATA_SCALE, DATA_DEFAULT, CHAR_LENGTH,
			NULLABLE, IS_PRIMARY_KEY, IS_SEARCH_KEY, IS_FOREIGN_KEY, IS_DISP_KEY_COLUMN, CHECK_UNIQUE,
			case when COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR')
					then 'N'
				when COLUMN_EXPR_TYPE IN ('SELECT_LIST', 'SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV') AND HAS_DEFAULT = 'Y'
					then 'N'
				when NULLABLE = 'Y' OR HAS_DEFAULT = 'Y'
					then 'N'
				else 'Y'
			end REQUIRED,
			HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, IS_AUDIT_COLUMN, IS_OBFUSCATED, IS_UPPER_NAME, 
			IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN, YES_NO_COLUMN_TYPE, 
			IS_SIMPLE_IN_LIST, STATIC_LOV_EXPR, HAS_AUTOMATIC_CHECK, HAS_RANGE_CHECK,
			IS_REFERENCE, IS_SEARCHABLE_REF, IS_SUMMAND, IS_VIRTUAL_COLUMN, 
			IS_DATETIME, 
			FORMAT_MASK, LOV_QUERY, COLUMN_ALIGN, COLUMN_HEADER, COLUMN_EXPR, COLUMN_EXPR_TYPE,
			FIELD_LENGTH, DISPLAY_IN_REPORT, '' COLUMN_DATA, R_TABLE_NAME, R_VIEW_NAME, R_COLUMN_NAME,
			REF_TABLE_NAME, REF_VIEW_NAME, REF_COLUMN_NAME, COMMENTS
		FROM (
			SELECT COLUMN_NAME, TABLE_ALIAS, 
				data_browser_select.FN_List_Offest(v_Select_Columns, COLUMN_NAME) COLUMN_ORDER,
				'N' IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME, 
				'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
				'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
				'N' IS_REFERENCE, 'N' IS_SEARCHABLE_REF, 'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 
				'N' IS_DATETIME,
				COLUMN_ID, 1 R_COLUMN_ID, POSITION, DATA_TYPE, -- Header Columns,
				0 HAS_COLLECTION_NUM_INDEX, 0 COLLECTION_NUM_INDEX, 
				0 HAS_COLLECTION_CHAR_INDEX, 0 HAS_COLLECTION_HIDDEN_INDEX, 0 COLLECTION_HIDDEN_INDEX,
				0 DATA_PRECISION, 0 DATA_SCALE, '' DATA_DEFAULT, FIELD_LENGTH CHAR_LENGTH, 
				'N' NULLABLE, 'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, 'N' IS_FOREIGN_KEY, 'N' IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE,
				'Y' HAS_HELP_TEXT, 'N' HAS_DEFAULT, 'N' IS_BLOB, 'N' IS_PASSWORD, '' FORMAT_MASK, '' LOV_QUERY, COLUMN_ALIGN,
				COLUMN_HEADER, COLUMN_EXPR, COLUMN_EXPR_TYPE,
				FIELD_LENGTH, 'Y' DISPLAY_IN_REPORT, 
				TABLE_NAME R_TABLE_NAME, VIEW_NAME R_VIEW_NAME, R_COLUMN_NAME,
				TABLE_NAME REF_TABLE_NAME, VIEW_NAME REF_VIEW_NAME, R_COLUMN_NAME REF_COLUMN_NAME, '' COMMENTS
			FROM (
				SELECT 'CONTROL_BREAK$' COLUMN_NAME, 'A' TABLE_ALIAS, -1 COLUMN_ID, 1 POSITION, 'VARCHAR2' DATA_TYPE, 'LEFT' COLUMN_ALIGN, 'Control Break' COLUMN_HEADER,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, data_browser_conf.Enquote_Literal('.') COLUMN_EXPR, 1024 FIELD_LENGTH,
					'CONTROL_BREAK$' R_COLUMN_NAME
				FROM SYS.DUAL
				UNION ALL
				SELECT 'LINK_ID$' COLUMN_NAME, 'A' TABLE_ALIAS, -1 COLUMN_ID, 2 POSITION, 'VARCHAR2' DATA_TYPE, 'CENTER' COLUMN_ALIGN, '' COLUMN_HEADER,
					'LINK_ID' COLUMN_EXPR_TYPE, 
					data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> UNIQUE_KEY_COLS, p_Table_Alias=> 'A', 
						p_View_Mode=> 'FORM_VIEW'	-- dont pass hash values to 'edit details' page 32
					) COLUMN_EXPR, 120 FIELD_LENGTH,
					'LINK_ID$' R_COLUMN_NAME
				FROM BROWSER_VIEW
				UNION ALL
				SELECT 'ROW_SELECTOR$' COLUMN_NAME, 'A' TABLE_ALIAS, -1 COLUMN_ID, 3 POSITION, 'VARCHAR2' DATA_TYPE, 'CENTER' COLUMN_ALIGN, 'Select' COLUMN_HEADER,
					'ROW_SELECTOR' COLUMN_EXPR_TYPE, data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> UNIQUE_KEY_COLS, p_Table_Alias=> 'A', p_View_Mode=> v_View_Mode) COLUMN_EXPR, 120 FIELD_LENGTH,
					'ROW_SELECTOR$' R_COLUMN_NAME
				FROM BROWSER_VIEW
				UNION ALL
				SELECT 'IMPORTJOB_ID$' COLUMN_NAME, 'A' TABLE_ALIAS, -1 COLUMN_ID, 4 POSITION, 'NUMBER' DATA_TYPE, 'RIGHT' COLUMN_ALIGN, 'Importjob_Id' COLUMN_HEADER,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 'data_browser_select.Current_Job_ID' COLUMN_EXPR, 10 FIELD_LENGTH,
					'' R_COLUMN_NAME
				FROM SYS.DUAL
				WHERE v_View_Mode = 'IMPORT_VIEW'
				UNION ALL
				SELECT 'LINE_NO$' COLUMN_NAME, '' TABLE_ALIAS, -1 COLUMN_ID, 5 POSITION, 'NUMBER' DATA_TYPE, 'RIGHT' COLUMN_ALIGN, 'Line_No' COLUMN_HEADER,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE, 'ROWNUM' COLUMN_EXPR, 10 FIELD_LENGTH,
					'' R_COLUMN_NAME
				FROM SYS.DUAL
				WHERE v_View_Mode = 'IMPORT_VIEW'
			) HEAD, BROWSER_VIEW
			UNION ALL
			SELECT IMP_COLUMN_NAME
				|| case when COUNT(*) OVER (PARTITION BY IMP_COLUMN_NAME) > 1
					then DENSE_RANK() OVER (PARTITION BY IMP_COLUMN_NAME ORDER BY COLUMN_ID, R_COLUMN_ID, POSITION) -- run_no
				end COLUMN_NAME,
				TABLE_ALIAS,
				NULLIF(data_browser_select.FN_List_Offest(v_Select_Columns, IMP_COLUMN_NAME),0) COLUMN_ORDER,
				IS_AUDIT_COLUMN, IS_OBFUSCATED, IS_UPPER_NAME, 
				IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN, YES_NO_COLUMN_TYPE, 
				IS_SIMPLE_IN_LIST, STATIC_LOV_EXPR, HAS_AUTOMATIC_CHECK, HAS_RANGE_CHECK,
				IS_REFERENCE, IS_SEARCHABLE_REF, IS_SUMMAND, IS_VIRTUAL_COLUMN, 
				IS_DATETIME, 
				COLUMN_ID, R_COLUMN_ID, POSITION, DATA_TYPE,
				-----------------------------------------
				data_browser_select.Field_Has_NInput_ID(
						p_Column_Expr_Type => COLUMN_EXPR_TYPE, p_Data_Type => DATA_TYPE,
						p_Is_Search_Key => IS_SEARCH_KEY, p_Is_Foreign_Key => IS_FOREIGN_KEY
				) AS HAS_COLLECTION_NUM_INDEX,
				SUM(data_browser_select.Field_Has_NInput_ID(
						p_Column_Expr_Type => COLUMN_EXPR_TYPE, p_Data_Type => DATA_TYPE,
						p_Is_Search_Key => IS_SEARCH_KEY, p_Is_Foreign_Key => IS_FOREIGN_KEY))
					OVER (ORDER BY NULLIF(data_browser_select.FN_List_Offest(v_Select_Columns, IMP_COLUMN_NAME),0) NULLS LAST, COLUMN_ID, R_COLUMN_ID, POSITION RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
				) AS COLLECTION_NUM_INDEX,
				data_browser_select.Field_Has_CInput_ID(
					p_Column_Expr_Type => COLUMN_EXPR_TYPE
				) AS HAS_COLLECTION_CHAR_INDEX,
				data_browser_select.Field_Has_HCInput_ID(
					p_Column_Expr_Type => COLUMN_EXPR_TYPE, p_Data_Type => DATA_TYPE,
					p_Is_Search_Key => IS_SEARCH_KEY, p_Is_Foreign_Key => IS_FOREIGN_KEY
				) AS HAS_COLLECTION_HIDDEN_INDEX,
				SUM(data_browser_select.Field_Has_HCInput_ID(
						p_Column_Expr_Type => COLUMN_EXPR_TYPE, p_Data_Type => DATA_TYPE,
						p_Is_Search_Key => IS_SEARCH_KEY, p_Is_Foreign_Key => IS_FOREIGN_KEY))
					OVER (ORDER BY NULLIF(data_browser_select.FN_List_Offest(v_Select_Columns, IMP_COLUMN_NAME),0) NULLS LAST, COLUMN_ID, R_COLUMN_ID, POSITION RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
				) AS COLLECTION_HIDDEN_INDEX,
				-----------------------------------------
				DATA_PRECISION, DATA_SCALE, DATA_DEFAULT, 
				CHAR_LENGTH, NULLABLE, IS_PRIMARY_KEY, IS_SEARCH_KEY, IS_FOREIGN_KEY, IS_DISP_KEY_COLUMN, CHECK_UNIQUE,
				HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, FORMAT_MASK, LOV_QUERY, COLUMN_ALIGN,
				COLUMN_HEADER,
				COLUMN_EXPR, COLUMN_EXPR_TYPE, FIELD_LENGTH, DISPLAY_IN_REPORT,
				R_TABLE_NAME, R_VIEW_NAME, R_COLUMN_NAME, 
				REF_TABLE_NAME, REF_VIEW_NAME, REF_COLUMN_NAME, COMMENTS
			FROM ( -- main table - simple_cols: all simple col with alias A. 
				SELECT --+ INDEX(S) USE_NL_WITH_INDEX(T)
					T.VIEW_NAME,
					T.COLUMN_NAME,
					'A' TABLE_ALIAS,
					T.IS_AUDIT_COLUMN, T.IS_OBFUSCATED, T.IS_UPPER_NAME,
					T.IS_NUMBER_YES_NO_COLUMN, T.IS_CHAR_YES_NO_COLUMN, T.YES_NO_COLUMN_TYPE, 
					T.IS_SIMPLE_IN_LIST, T.STATIC_LOV_EXPR, T.HAS_AUTOMATIC_CHECK, T.HAS_RANGE_CHECK,
					T.IS_REFERENCE,
					case when T.DATA_TYPE IN ('BLOB', 'LONG')
						then 'N' else 'Y'
					end IS_SEARCHABLE_REF,
					T.IS_SUMMAND, T.IS_VIRTUAL_COLUMN, 
					data_browser_select.Date_Time_Required(T.DATA_TYPE, v_Data_Format, T.IS_DATETIME) IS_DATETIME,					
					T.COLUMN_ID, 
					T.COLUMN_ID R_COLUMN_ID, 
					T.POSITION,
					T.COLUMN_NAME IMP_COLUMN_NAME,
					T.COLUMN_ALIGN,
					case when T.IS_FOREIGN_KEY = 'Y' then 
						data_browser_conf.Column_Name_to_Header(
							p_Column_Name=> T.COLUMN_NAME, 
							p_Remove_Extension=>'NO', 
							p_Remove_Prefix=>S.COLUMN_PREFIX, 
							p_Is_Upper_Name=>T.IS_UPPER_NAME
						)
					else 
						T.COLUMN_HEADER
					end COLUMN_HEADER,
					S.COLUMN_PREFIX,
					case 
					when T.IS_OBFUSCATED = 'Y' then
						data_browser_conf.Get_Obfuscate_Call('A.' || T.COLUMN_NAME)
					when T.IS_PRIMARY_KEY = 'Y'			-- primary key shouldn´t be a input field
					and T.IS_DISPLAYED_KEY_COLUMN = 'N' -- field is invisible
					and S.HAS_SCALAR_KEY = 'YES' then	-- primary key is managed automatically
						'A.' || T.COLUMN_NAME
					when T.COLUMN_NAME = S.MIME_TYPE_COLUMN_NAME and v_Data_Format NOT IN ('NATIVE', 'CSV') then
						data_browser_blobs.File_Type_Name_Call(p_Mime_Type_Column_Name => 'A.' || T.COLUMN_NAME)
					when T.IS_AUDIT_COLUMN = 'Y' and T.CHAR_LENGTH > 0 and v_Data_Format NOT IN ('NATIVE', 'CSV') then
						data_browser_conf.Get_Formated_User_Name('A.' || T.COLUMN_NAME)
					when T.IS_FOREIGN_KEY = 'N'
					and T.COLUMN_NAME != NVL(S.ROW_VERSION_COLUMN_NAME, '-')
					and T.IS_ORDERING_COLUMN = 'N' 
					and T.IS_SEARCH_KEY = 'N'
					then
						data_browser_select.Get_ConversionColFunction (
							p_Column_Name		=> 'A.' || T.COLUMN_NAME,
							p_Data_Type			=> T.DATA_TYPE,
							p_Data_Precision	=> T.DATA_PRECISION,
							p_Data_Scale		=> T.DATA_SCALE,
							p_Char_Length		=> T.CHAR_LENGTH,
							p_Data_Format		=> v_Data_Format,
							p_Use_Trim			=> 'Y',
							p_Datetime			=> data_browser_select.Date_Time_Required(T.DATA_TYPE, v_Data_Format, T.IS_DATETIME),
							p_Use_Group_Separator => v_Use_Group_Separator
						) 
					else
						'A.' || T.COLUMN_NAME
					end COLUMN_EXPR,
					T.HAS_HELP_TEXT, T.HAS_DEFAULT, T.IS_BLOB, T.IS_PASSWORD,
					case 
					when T.IS_SEARCH_KEY = 'Y'		-- primary key shouldn´t be a input field
					and T.IS_DISPLAYED_KEY_COLUMN = 'N' -- field is invisible
					and S.HAS_SCALAR_KEY = 'YES' then	-- primary key is managed automatically
						null
					when T.IS_FOREIGN_KEY = 'N' then
						data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type			=> T.DATA_TYPE, 
							p_Data_Precision	=> T.DATA_PRECISION, 
							p_Data_Scale		=> T.DATA_SCALE, 
							p_Char_Length		=> T.CHAR_LENGTH, 
							p_Use_Group_Separator => v_Use_Group_Separator, 
							p_Datetime			=> data_browser_select.Date_Time_Required(T.DATA_TYPE, v_Data_Format, T.IS_DATETIME)
						)
					end FORMAT_MASK,
					null LOV_QUERY,
					case
					when T.COLUMN_NAME = S.FILE_CONTENT_COLUMN_NAME
					and T.IS_BLOB = 'Y' then
						'FILE_BROWSER'
					when T.IS_SEARCH_KEY = 'Y'			-- primary key shouldn´t be a input field
					and S.HAS_SCALAR_KEY = 'YES'	-- primary key is managed automatically
					and T.IS_DISPLAYED_KEY_COLUMN = 'N' then -- field is invisible
						case when data_browser_select.FN_List_Offest(v_Select_Columns, T.COLUMN_NAME) = 0 then -- not visible
							'HIDDEN' else 'DISPLAY_AND_SAVE'
						end
					when (T.IS_FOREIGN_KEY = 'Y'	-- In View Mode Import/Export the foreign key columns are hidden.
						and data_browser_select.FN_List_Offest(v_Select_Columns, T.COLUMN_NAME) = 0) -- not visible
					or T.IS_IGNORED = 'Y'
					or T.COLUMN_NAME = S.ROW_VERSION_COLUMN_NAME then
						'HIDDEN'
					when T.COLUMN_NAME IN (MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME)	-- file meta data
					or T.IS_VIRTUAL_COLUMN = 'Y'
					or T.IS_OBFUSCATED = 'Y'
					or (T.IS_AUDIT_COLUMN = 'Y' and T.HAS_DEFAULT = 'Y')
					or (T.IS_READONLY = 'Y' and T.IS_CHECKED = 'N') then
						'DISPLAY_ONLY'
					when T.IS_READONLY = 'Y' then
						'DISPLAY_AND_SAVE'
					else
						data_browser_conf.Get_Column_Expr_Type(T.COLUMN_NAME, T.DATA_TYPE, T.CHAR_LENGTH, T.IS_READONLY)
					end COLUMN_EXPR_TYPE,
					T.FIELD_LENGTH,
					T.DISPLAY_IN_REPORT,
					T.DATA_TYPE,
					T.DATA_TYPE_OWNER,
					T.DATA_PRECISION, T.DATA_SCALE, T.DATA_DEFAULT, 
					T.CHAR_LENGTH, T.NULLABLE, 
					T.IS_PRIMARY_KEY, T.IS_SEARCH_KEY, T.IS_FOREIGN_KEY,
					T.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, 
					T.CHECK_UNIQUE,
					T.TABLE_NAME R_TABLE_NAME, 
					T.VIEW_NAME R_VIEW_NAME, 
					T.COLUMN_NAME R_COLUMN_NAME,
					T.TABLE_NAME REF_TABLE_NAME, 
					T.VIEW_NAME REF_VIEW_NAME,	-- Adress of source and target in foreign key lookup
					T.COLUMN_NAME REF_COLUMN_NAME,
					T.COMMENTS
				FROM MVDATA_BROWSER_SIMPLE_COLS T
				JOIN BROWSER_VIEW S ON S.VIEW_NAME = T.VIEW_NAME
				WHERE T.VIEW_NAME = v_View_Name
				AND (T.IS_IGNORED = 'N' AND T.IS_HIDDEN = 'N' OR T.IS_SEARCH_KEY = 'Y')
				AND (T.IS_DATA_DEDUCTED = 'N' OR data_browser_conf.Check_Data_Deduction(T.COLUMN_NAME) = 'NO')
				---------------------------------------------------------------
				UNION ALL -- Special case: folder path
				SELECT --+ INDEX(S) USE_NL_WITH_INDEX(T)
					S.VIEW_NAME,
					data_browser_conf.Compose_Column_Name(
						p_First_Name=> data_browser_conf.Normalize_Column_Name(
							p_Column_Name => T.COLUMN_NAME, p_Remove_Prefix => S.COLUMN_PREFIX),
						p_Second_Name => 'PATH'
					) COLUMN_NAME,
					'' TABLE_ALIAS,
					S.IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
					'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
					'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
					S.IS_REFERENCE,
					'Y' IS_SEARCHABLE_REF,
					'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 'N' IS_DATETIME,
					S.COLUMN_ID, S.R_COLUMN_ID, S.POSITION,
					data_browser_conf.Compose_Column_Name(
						p_First_Name=> data_browser_conf.Normalize_Column_Name(
							p_Column_Name => T.COLUMN_NAME, p_Remove_Prefix => S.COLUMN_PREFIX),
						p_Second_Name => 'PATH'
					) IMP_COLUMN_NAME,
					S.COLUMN_ALIGN,
					data_browser_conf.Concat_List(
						p_First_Name=> T.COLUMN_HEADER
						, p_Second_Name => Apex_lang.lang('Path'), p_Delimiter=>' - '
					) COLUMN_HEADER,
					S.COLUMN_PREFIX,
					'(' || -- Display folder path
					data_browser_select.Key_Path_Query (
						p_Table_Name		=> F.R_VIEW_NAME,
						p_Search_Key_Col	=> F.R_PRIMARY_KEY_COLS,
						p_Search_Value		=> null,
						p_Folder_Par_Col_Name  => F.FOLDER_PARENT_COLUMN_NAME,
						p_Folder_Name_Col_Name => F.FOLDER_NAME_COLUMN_NAME,
						p_Folder_Cont_Col_Name => F.FOLDER_CONTAINER_COLUMN_NAME,
						p_Folder_Cont_Alias => case when F.VIEW_NAME = F.R_VIEW_NAME then 'A' 
													when exists (select 1 from JOIN_OPTIONS J 
															where F.TABLE_ALIAS = J.TABLE_ALIAS 
															and J.COLUMNS_INCLUDED IN ('A', 'K') ) then	 
														F.TABLE_ALIAS 
												end,
						p_View_Mode			=> v_View_Mode,
						p_Filter_Cond		=> data_browser_conf.Get_Join_Expression( -- support for composite keys
							p_Left_Columns=> F.R_PRIMARY_KEY_COLS, p_Left_Alias=> 'L1',
							p_Right_Columns=> T.COLUMN_NAME, p_Right_Alias=> 'A'),
						p_Order_by			=> null -- not needed
					)
					|| data_browser_conf.NL(4) || ') ' -- display single value					
					COLUMN_EXPR,
					S.HAS_HELP_TEXT,
					S.HAS_DEFAULT,
					S.IS_BLOB,
					S.IS_PASSWORD,
					null FORMAT_MASK,
					'select distinct path d, path r from (' ||
					data_browser_select.Key_Path_Query (
						p_Table_Name		=> F.R_VIEW_NAME,
						p_Search_Key_Col	=> F.R_PRIMARY_KEY_COLS,
						p_Search_Value		=> null,
						p_Folder_Par_Col_Name  => F.FOLDER_PARENT_COLUMN_NAME,
						p_Folder_Name_Col_Name => F.FOLDER_NAME_COLUMN_NAME,
						p_Folder_Cont_Col_Name => F.FOLDER_CONTAINER_COLUMN_NAME,
						p_Folder_Cont_Alias => NULL, -- problem - variable reference 
						p_View_Mode			=> v_View_Mode,
						p_Filter_Cond		=> null,
						p_Order_by			=> NVL(F.ORDERING_COLUMN_NAME, '1')
					) || ')'		
					LOV_QUERY,
					'POPUP_FROM_LOV' -- Display folder path			
					COLUMN_EXPR_TYPE,
					1024 FIELD_LENGTH,
					S.DISPLAY_IN_REPORT,
					S.R_DATA_TYPE, NULL DATA_TYPE_OWNER, S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_DATA_DEFAULT, 
					S.R_CHAR_LENGTH,
					case when S.NULLABLE = 'N' and S.R_NULLABLE = 'N' then 'N' else 'Y' end NULLABLE,
					'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, T.IS_FOREIGN_KEY,
					S.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE,
					S.TABLE_NAME R_TABLE_NAME, 
					S.VIEW_NAME R_VIEW_NAME, 
					S.FOREIGN_KEY_COLS R_COLUMN_NAME,
					S.R_TABLE_NAME REF_TABLE_NAME, 
					S.R_VIEW_NAME REF_VIEW_NAME,		-- Adress of source and target in foreign key lookup
					S.R_COLUMN_NAME REF_COLUMN_NAME,
					'' COMMENTS
				FROM MVDATA_BROWSER_SIMPLE_COLS T
				JOIN MVDATA_BROWSER_F_REFS S ON S.VIEW_NAME = T.VIEW_NAME
				JOIN MVDATA_BROWSER_REFERENCES F ON T.VIEW_NAME = F.VIEW_NAME 
					AND T.COLUMN_NAME = F.COLUMN_NAME
					AND F.FOLDER_NAME_COLUMN_NAME = S.R_COLUMN_NAME
				WHERE S.VIEW_NAME = v_View_Name
				AND F.FOLDER_PARENT_COLUMN_NAME IS NOT NULL 
				AND F.FOLDER_NAME_COLUMN_NAME IS NOT NULL 
				AND S.IS_FILE_FOLDER_REF = 'Y'
				UNION ALL -- f_refs: all 1. level natural key columns of direct references from table A => alias B.
							--------------------------------------------------------------
				SELECT DISTINCT --+ INDEX(S)
					S.VIEW_NAME, S.IMP_COLUMN_NAME COLUMN_NAME, 
					S.TABLE_ALIAS,
					S.IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
					'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
					'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
					S.IS_REFERENCE,
					case when S.R_DATA_TYPE IN ('BLOB', 'LONG')
						then 'N' else 'Y'
					end IS_SEARCHABLE_REF,
					'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 
					data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME) IS_DATETIME,
					S.COLUMN_ID, S.R_COLUMN_ID, S.POSITION, S.IMP_COLUMN_NAME,
					S.COLUMN_ALIGN,
					S.COLUMN_HEADER,
					S.COLUMN_PREFIX,
					data_browser_select.Get_ConversionColFunction (
						p_Column_Name		=> S.TABLE_ALIAS || '.' || S.R_COLUMN_NAME,
						p_Data_Type			=> S.R_DATA_TYPE,
						p_Data_Precision	=> S.R_DATA_PRECISION,
						p_Data_Scale		=> S.R_DATA_SCALE,
						p_Char_Length		=> S.R_CHAR_LENGTH,
						p_Data_Format		=> case when S.IS_REFERENCE = 'N' then v_Data_Format else 'CSV' end,
						p_Use_Trim			=> 'Y',
						p_Datetime			=> data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME),
						p_Use_Group_Separator => v_Use_Group_Separator
					) COLUMN_EXPR,
					S.HAS_HELP_TEXT,
					S.HAS_DEFAULT,
					S.IS_BLOB,
					S.IS_PASSWORD,
					case when S.IS_REFERENCE = 'N' then
						data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type			=> S.R_DATA_TYPE, 
							p_Data_Precision	=> S.R_DATA_PRECISION, 
							p_Data_Scale		=> S.R_DATA_SCALE, 
							p_Char_Length		=> S.R_CHAR_LENGTH, 
							p_Use_Group_Separator => v_Use_Group_Separator,
							p_Datetime			=> data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME)
						)
					end FORMAT_MASK,
					'' LOV_QUERY,
					case when S.IS_REFERENCE != 'N'	 -- In View Mode Import/Export the foreign key columns are hidden.
					and data_browser_select.FN_List_Offest(v_Select_Columns, S.IMP_COLUMN_NAME) = 0 -- not visible
						then 'HIDDEN'
					else
						'POPUP_FROM_LOV' -- text field with popup list
					end COLUMN_EXPR_TYPE,
					S.FIELD_LENGTH,
					case when S.R_VIEW_NAME = v_Parent_Name AND S.FOREIGN_KEY_COLS = NVL(v_Parent_Key_Column, S.FOREIGN_KEY_COLS)
						then 'Y'
						else S.DISPLAY_IN_REPORT
					end DISPLAY_IN_REPORT,
					S.R_DATA_TYPE, NULL DATA_TYPE_OWNER, S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_DATA_DEFAULT,
					S.R_CHAR_LENGTH,
					case when S.NULLABLE = 'N' and S.R_NULLABLE = 'N' then 'N' else 'Y' end NULLABLE,
					'N' IS_PRIMARY_KEY, 'N' IS_SEARCH_KEY, 
					case when S.IS_REFERENCE = 'N' then 'N' else 'Y' end IS_FOREIGN_KEY,
					S.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE,
					S.TABLE_NAME R_TABLE_NAME, 
					S.VIEW_NAME R_VIEW_NAME, 
					S.FOREIGN_KEY_COLS R_COLUMN_NAME,
					S.R_TABLE_NAME REF_TABLE_NAME, 
					S.R_VIEW_NAME REF_VIEW_NAME,		-- Adress of source and target in foreign key lookup
					S.R_COLUMN_NAME REF_COLUMN_NAME,
					'' COMMENTS
				FROM MVDATA_BROWSER_F_REFS S
				LEFT OUTER JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
				WHERE S.VIEW_NAME = v_View_Name
				AND S.R_COLUMN_ID IS NOT NULL	
				AND S.IS_FILE_FOLDER_REF = 'N'
				AND (J.COLUMNS_INCLUDED IN ('A', 'K') OR v_Join_Options IS NULL) 
				AND data_browser_select.FN_Filter_Parent_Key(
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_Parent_Name		=> v_Parent_Name,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Ref_View_Name		=> S.R_VIEW_NAME,
					p_R_Column_Name		=> S.FOREIGN_KEY_COLS
				) = 'NO'
				UNION ALL -- q_refs: all 2. level natural key columns of indirect references from frefs => alias B_A. 
							--------------------------------------------------------------
				SELECT DISTINCT --+ INDEX(S)
					S.VIEW_NAME, S.FOREIGN_KEY_COLS COLUMN_NAME,
					S.R_TABLE_ALIAS TABLE_ALIAS,
					S.IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
					'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
					'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
					S.IS_REFERENCE,
					case when S.R_DATA_TYPE IN ('BLOB', 'LONG')
						then 'N' else 'Y'
					end IS_SEARCHABLE_REF,
					'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 
					data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME) IS_DATETIME,
					S.COLUMN_ID, S.R_COLUMN_ID, S.POSITION, S.IMP_COLUMN_NAME,
					S.COLUMN_ALIGN,
					S.COLUMN_HEADER,
					S.COLUMN_PREFIX,
					S.COLUMN_EXPR,
					S.HAS_HELP_TEXT,
					S.HAS_DEFAULT,
					S.IS_BLOB,
					S.IS_PASSWORD,
					case when S.IS_REFERENCE = 'N' then
						data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type			=> S.R_DATA_TYPE, 
							p_Data_Precision	=> S.R_DATA_PRECISION, 
							p_Data_Scale		=> S.R_DATA_SCALE, 
							p_Char_Length		=> S.R_CHAR_LENGTH, 
							p_Use_Group_Separator => v_Use_Group_Separator,
							p_Datetime			=> data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME)
						)
					end FORMAT_MASK,
					'' LOV_QUERY,
					case when S.IS_REFERENCE != 'N'	 -- In View Mode Import/Export the foreign key columns are hidden.
					and data_browser_select.FN_List_Offest(v_Select_Columns, S.IMP_COLUMN_NAME) = 0 -- not visible
						then 'HIDDEN'
					else
						'POPUP_FROM_LOV' -- text field with popup list
					end COLUMN_EXPR_TYPE,
					--'POPUP_FROM_LOV' COLUMN_EXPR_TYPE,
					S.FIELD_LENGTH,
					S.DISPLAY_IN_REPORT,
					S.R_DATA_TYPE, NULL DATA_TYPE_OWNER, S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_DATA_DEFAULT, 
					S.R_CHAR_LENGTH,
					case when S.NULLABLE = 'N' and S.R_NULLABLE = 'N' then 'N' else 'Y' end NULLABLE,
					'N' IS_PRIMARY_KEY, 
					'N' IS_SEARCH_KEY, 
					case when S.IS_REFERENCE = 'N' then 'N' else 'Y' end IS_FOREIGN_KEY,
					S.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE,
					S.TABLE_NAME R_TABLE_NAME, 
					S.VIEW_NAME R_VIEW_NAME, 
					S.COLUMN_NAME R_COLUMN_NAME,
					S.R_TABLE_NAME REF_TABLE_NAME, 
					S.R_VIEW_NAME REF_VIEW_NAME, 
					S.R_COLUMN_NAME REF_COLUMN_NAME,
					'' COMMENTS
				FROM TABLE(data_browser_select.FN_Pipe_browser_q_refs(
					p_View_Name => v_View_Name, p_Data_Format => v_Data_Format, p_Use_Group_Separator => v_Use_Group_Separator)) S
				LEFT OUTER JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
				WHERE S.VIEW_NAME = v_View_Name
				AND S.PARENT_KEY_COLUMN IS NULL -- column is hidden because its content can be deduced from the references FILTER_KEY_COLUMN
				AND S.IS_FILE_FOLDER_REF = 'N'
				AND (J.COLUMNS_INCLUDED IN ('A', 'K') OR v_Join_Options IS NULL)
				AND data_browser_select.FN_Filter_Parent_Key(
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_Parent_Name		=> v_Parent_Name,
					p_Parent_Key_Column => v_Parent_Key_Column,
					p_Ref_View_Name		=> S.J_VIEW_NAME,
					p_R_Column_Name		=> S.COLUMN_NAME
				) = 'NO'
				---------------------------------------------------------------
				UNION ALL -- fc_refs: all 1. level table columns of direct references from table A => alias B.
							--------------------------------------------------------------
				SELECT DISTINCT S.VIEW_NAME, S.COLUMN_NAME, 
					S.TABLE_ALIAS,
					S.IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
					S.IS_NUMBER_YES_NO_COLUMN, S.IS_CHAR_YES_NO_COLUMN, S.YES_NO_COLUMN_TYPE, 
					S.IS_SIMPLE_IN_LIST, S.STATIC_LOV_EXPR, S.HAS_AUTOMATIC_CHECK, S.HAS_RANGE_CHECK,
					S.IS_REFERENCE,
					case when S.R_DATA_TYPE IN ('BLOB', 'LONG')
						then 'N' else 'Y'
					end IS_SEARCHABLE_REF,
					'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 
					data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME) IS_DATETIME,
					S.COLUMN_ID, S.R_COLUMN_ID, S.POSITION, S.IMP_COLUMN_NAME,
					S.COLUMN_ALIGN,
					S.COLUMN_HEADER,
					S.COLUMN_PREFIX,
					data_browser_select.Get_ConversionColFunction (
						p_Column_Name		=> S.TABLE_ALIAS || '.' || S.R_COLUMN_NAME,
						p_Data_Type			=> S.R_DATA_TYPE,
						p_Data_Precision	=> S.R_DATA_PRECISION,
						p_Data_Scale		=> S.R_DATA_SCALE,
						p_Char_Length		=> S.R_CHAR_LENGTH,
						p_Data_Format		=> case when S.IS_REFERENCE = 'N' then v_Data_Format else 'CSV' end,
						p_Use_Trim			=> 'Y',
						p_Datetime			=> data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME),
						p_Use_Group_Separator => v_Use_Group_Separator
					) COLUMN_EXPR,
					S.HAS_HELP_TEXT,
					s.HAS_DEFAULT,
					S.IS_BLOB,
					S.IS_PASSWORD,
					case when S.IS_REFERENCE = 'N' then
						data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type			=> S.R_DATA_TYPE, 
							p_Data_Precision	=> S.R_DATA_PRECISION, 
							p_Data_Scale		=> S.R_DATA_SCALE, 
							p_Char_Length		=> S.R_CHAR_LENGTH, 
							p_Use_Group_Separator => v_Use_Group_Separator,
							p_Datetime			=> data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME)
						)
					end FORMAT_MASK, 
					'' LOV_QUERY,
					case when S.IS_REFERENCE != 'N' -- In View Mode Import/Export the foreign key columns are hidden.
					and data_browser_select.FN_List_Offest(v_Select_Columns, S.IMP_COLUMN_NAME) = 0 -- not visible
						then 'HIDDEN'
					else 
						'DISPLAY_ONLY'
					end COLUMN_EXPR_TYPE,
					S.FIELD_LENGTH,
					S.DISPLAY_IN_REPORT,
					S.R_DATA_TYPE, S.DATA_TYPE_OWNER, S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_DATA_DEFAULT, 
					S.R_CHAR_LENGTH,
					case when S.NULLABLE = 'N' and S.R_NULLABLE = 'N' then 'N' else 'Y' end NULLABLE,
					'N' IS_PRIMARY_KEY, 
					'N' IS_SEARCH_KEY, 
					case when S.IS_REFERENCE = 'N' then 'N' else 'Y' end IS_FOREIGN_KEY,
					S.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE,
					S.TABLE_NAME R_TABLE_NAME, 
					S.VIEW_NAME R_VIEW_NAME, 
					S.COLUMN_NAME R_COLUMN_NAME,
					S.R_TABLE_NAME REF_TABLE_NAME, 
					S.R_VIEW_NAME REF_VIEW_NAME, 
					S.R_COLUMN_NAME REF_COLUMN_NAME,
					S.COMMENTS
				FROM TABLE(data_browser_select.FN_Pipe_browser_fc_refs(v_View_Name)) S
				JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
				WHERE S.VIEW_NAME = v_View_Name
				AND (J.COLUMNS_INCLUDED = 'A')
				AND data_browser_conf.Check_Data_Deduction(S.R_COLUMN_NAME) = 'NO'
				UNION ALL -- qc_refs: all 2. level table columns of indirect references from frefs => alias B_A. 
							--------------------------------------------------------------
				SELECT DISTINCT S.VIEW_NAME, S.COLUMN_NAME,
					S.R_TABLE_ALIAS TABLE_ALIAS,
					S.IS_AUDIT_COLUMN, 'N' IS_OBFUSCATED, 'N' IS_UPPER_NAME,
					'N' IS_NUMBER_YES_NO_COLUMN, 'N' IS_CHAR_YES_NO_COLUMN, '' YES_NO_COLUMN_TYPE, 
					'N' IS_SIMPLE_IN_LIST, '' STATIC_LOV_EXPR, 'N' HAS_AUTOMATIC_CHECK, 'N' HAS_RANGE_CHECK,
					S.IS_REFERENCE,
					case when S.R_DATA_TYPE IN ('BLOB', 'LONG')
						then 'N' else 'Y'
					end IS_SEARCHABLE_REF,
					'N' IS_SUMMAND, 'N' IS_VIRTUAL_COLUMN, 
					data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME) IS_DATETIME,
					S.COLUMN_ID, S.R_COLUMN_ID, S.POSITION,
					S.IMP_COLUMN_NAME,
					S.COLUMN_ALIGN,
					S.COLUMN_HEADER,
					S.COLUMN_PREFIX,
					S.COLUMN_EXPR,
					S.HAS_HELP_TEXT,
					S.HAS_DEFAULT,
					S.IS_BLOB,
					S.IS_PASSWORD,
					data_browser_conf.Get_Col_Format_Mask(
						p_Data_Type			=> S.R_DATA_TYPE, 
						p_Data_Precision	=> S.R_DATA_PRECISION, 
						p_Data_Scale		=> S.R_DATA_SCALE, 
						p_Char_Length		=> S.R_CHAR_LENGTH, 
						p_Use_Group_Separator => v_Use_Group_Separator,
						p_Datetime			=> data_browser_select.Date_Time_Required(S.R_DATA_TYPE, v_Data_Format, S.IS_DATETIME)
					) FORMAT_MASK, 
					'' LOV_QUERY,
					'DISPLAY_ONLY' COLUMN_EXPR_TYPE,
					S.FIELD_LENGTH,
					S.DISPLAY_IN_REPORT,
					S.R_DATA_TYPE, NULL DATA_TYPE_OWNER, S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_DATA_DEFAULT, 
					S.R_CHAR_LENGTH,
					case when S.NULLABLE = 'N' and S.R_NULLABLE = 'N' then 'N' else 'Y' end NULLABLE,
					'N' IS_PRIMARY_KEY, 
					'N' IS_SEARCH_KEY,
					'N' IS_FOREIGN_KEY,
					S.IS_DISPLAYED_KEY_COLUMN IS_DISP_KEY_COLUMN, 'N' CHECK_UNIQUE,
					S.TABLE_NAME R_TABLE_NAME, 
					S.VIEW_NAME R_VIEW_NAME, 
					S.COLUMN_NAME R_COLUMN_NAME,
					S.R_TABLE_NAME REF_TABLE_NAME, 
					S.R_VIEW_NAME REF_VIEW_NAME, 
					S.R_COLUMN_NAME REF_COLUMN_NAME,
					S.COMMENTS
				FROM TABLE(data_browser_select.FN_Pipe_browser_qc_refs(v_View_Name, v_Data_Format, v_Use_Group_Separator)) S
				JOIN JOIN_OPTIONS J ON S.TABLE_ALIAS = J.TABLE_ALIAS
				WHERE S.VIEW_NAME = v_View_Name
				AND (J.COLUMNS_INCLUDED = 'A')
				AND data_browser_conf.Check_Data_Deduction(S.R_COLUMN_NAME) = 'NO'
			)
			WHERE VIEW_NAME = v_View_Name
		)
		ORDER BY COLUMN_ORDER;

	FUNCTION Date_Time_Required (
		p_Data_Type VARCHAR2,
		p_Data_Format VARCHAR2,
		p_Datetime VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2 DETERMINISTIC -- Y / N
	IS 
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Data_Type LIKE 'TIMESTAMP%' and p_Data_Format IN ('FORM', 'QUERY') then 'Y' else p_Datetime end;
	END Date_Time_Required;

	FUNCTION Reference_Column_Header (
		p_Column_Name VARCHAR2,
		p_Remove_Prefix VARCHAR2,
		p_View_Name VARCHAR2,
		p_R_View_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
		v_Column_Name VARCHAR2(128) := data_browser_conf.Normalize_Column_Name(p_Column_Name => p_Column_Name, p_Remove_Prefix => p_Remove_Prefix);
		v_View_Name VARCHAR2(128) := data_browser_conf.Normalize_Table_Name(p_Table_Name => p_View_Name);
		v_R_View_Name VARCHAR2(128) := data_browser_conf.Normalize_Table_Name(p_Table_Name => p_R_View_Name);
	BEGIN
		RETURN data_browser_conf.Table_Name_To_Header(
			case when INSTR(v_R_View_Name, SUBSTR(v_View_Name, 1, INSTR(v_View_Name, '_') - 1)) > 0 --	Detail table name starts with master table name
				then SUBSTR(v_View_Name, INSTR(v_View_Name, '_') + 1)	-- Remove master table name from detail table name
				else v_View_Name										-- detail table name
			end
		)
		|| case when INSTR(v_R_View_Name, v_Column_Name) = 0
			then ' - ' || data_browser_conf.Column_Name_to_Header(
							p_Column_Name => p_Column_Name, 
							p_Remove_Extension => 'YES', 
							p_Remove_Prefix => p_Remove_Prefix,
							p_Is_Upper_Name => data_browser_pattern.Match_Upper_Names_Columns(p_Column_Name)
						)
		end;
	END Reference_Column_Header;

	FUNCTION Get_ConversionColFunction (
		p_Column_Name VARCHAR2,
		p_Data_Type VARCHAR2,
		p_Data_Precision NUMBER,
		p_Data_Scale NUMBER,
		p_Char_Length NUMBER,
		p_Data_Format VARCHAR2 DEFAULT 'FORM',
		p_Use_Trim VARCHAR2 DEFAULT 'Y',	-- trim leading spaces from formated numbers; trim text to limit
		p_Datetime VARCHAR2 DEFAULT NULL,	-- Y,N
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL	-- Y,N; use G in number format mask
	) RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
		v_use_NLS_params		VARCHAR2(1);
		v_Use_Group_Separator	VARCHAR2(1);
		v_Datetime				VARCHAR2(1);
	BEGIN
		if p_Data_Format != 'NATIVE' then
			v_use_NLS_params		:= case when p_Data_Format IN ('FORM', 'HTML', 'QUERY') 
															then 'N' else 'Y' end;
			v_Use_Group_Separator	:= case when p_Use_Group_Separator IS NOT NULL then p_Use_Group_Separator
										when p_Data_Format IN ('FORM', 'HTML', 'QUERY') then 'Y' else 'N' end;
			v_Datetime				:= data_browser_select.Date_Time_Required(p_Data_Type, p_Data_Format, p_Datetime);
			return data_browser_conf.Get_ExportColFunction (
				p_Column_Name => p_Column_Name,
				p_Data_Type => p_Data_Type,
				p_Data_Precision => p_Data_Precision,
				p_Data_Scale => p_Data_Scale,
				p_Char_Length => p_Char_Length,
				p_Use_Group_Separator => v_Use_Group_Separator,
				p_Use_Trim => p_Use_Trim,
				p_Datetime => v_Datetime,
				p_use_NLS_params => v_use_NLS_params
			);
		else
			return p_Column_Name;
		end if;
	END Get_ConversionColFunction;

	/*
	qc_refs: all 2. level table columns of indirect references from frefs => alias B_A. 
		FK cols are excluded fields. (join options A)
	*/
	FUNCTION FN_Pipe_browser_qc_refs (
		p_View_Name VARCHAR2, 
		p_Data_Format VARCHAR2 DEFAULT 'FORM',
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL	-- Y,N; use G in number format mask
	)
	RETURN data_browser_select.tab_data_browser_qc_refs PIPELINED
	IS
		CURSOR keys_cur (v_View_Name VARCHAR2)
		IS
		-- find qualified unique key for target table of foreign key reference
		WITH q_refs AS (
			select F.VIEW_NAME, F.FOREIGN_KEY_COLS, F.COLUMN_ID, F.R_VIEW_NAME, F.R_COLUMN_NAME, F.TABLE_ALIAS, F.R_TABLE_ALIAS
			from TABLE(data_browser_select.FN_Pipe_browser_q_refs(
				p_View_Name => v_View_Name, p_Data_Format => p_Data_Format, p_Use_Group_Separator => p_Use_Group_Separator)) F
		)
		SELECT VIEW_NAME, TABLE_NAME, COLUMN_NAME, COLUMN_ID, NULLABLE, POSITION,
			R_VIEW_NAME, R_TABLE_NAME,
			R_COLUMN_NAME,
			R_COLUMN_ID,
			IMP_COLUMN_NAME,
			COLUMN_PREFIX, IS_UPPER_NAME,
			data_browser_conf.Column_Name_to_Header(
				p_Column_Name => COLUMN_HEADER, 
				p_Remove_Extension => 'NO', 
				p_Is_Upper_Name => IS_UPPER_NAME
			) COLUMN_HEADER,
			COLUMN_EXPR,
			R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, R_DATA_DEFAULT, 
			R_CHAR_LENGTH, 
			COLUMN_ALIGN, FIELD_LENGTH,
			R_NULLABLE, R_IS_READONLY,
			TABLE_ALIAS,
			R_TABLE_ALIAS,
			HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, IS_AUDIT_COLUMN, IS_DATETIME, 
			DISPLAY_IN_REPORT, IS_DISPLAYED_KEY_COLUMN, IS_REFERENCE,
			COMMENTS
		FROM (
			SELECT DISTINCT F.TABLE_NAME, F.VIEW_NAME,
				F.COLUMN_NAME,
				F.COLUMN_ID,
				F.R_COLUMN_ID,
				F.POSITION+G.R_COLUMN_ID/10000 POSITION,
				NVL(G.R_COLUMN_NAME, G.R_PRIMARY_KEY_COLS) R_COLUMN_NAME,
				data_browser_conf.Compose_3Column_Names(
					p_First_Name => F.NORM_COLUMN_NAME,
					p_Second_Name => G.NORM_COLUMN_NAME,
					p_Third_Name => NVL(G.R_COLUMN_NAME, G.R_PRIMARY_KEY_COLS),
					p_Max_Length => 29)		
				IMP_COLUMN_NAME,
				F.COLUMN_PREFIX, G.IS_UPPER_NAME,
				data_browser_conf.Compose_3Column_Names(
					p_First_Name => F.NORM_COLUMN_NAME,
					p_Second_Name => G.NORM_COLUMN_NAME,
					p_Third_Name => NVL(G.R_COLUMN_NAME, G.R_PRIMARY_KEY_COLS),
					p_Max_Length => 128)		
				COLUMN_HEADER,
				case when G.R_COLUMN_NAME IS NULL then 'No description columns found. (Q)' end WARNING_MSG,
				data_browser_select.Get_ConversionColFunction (
					p_Column_Name => data_browser_conf.Concat_List(F.TABLE_ALIAS, G.TABLE_ALIAS, '_') || '.' || NVL(G.R_COLUMN_NAME, G.R_PRIMARY_KEY_COLS),
					p_Data_Type => G.R_DATA_TYPE,
					p_Data_Precision => G.R_DATA_PRECISION,
					p_Data_Scale => G.R_DATA_SCALE,
					p_Char_Length => G.R_CHAR_LENGTH,
					p_Data_Format => case when G.R_COLUMN_NAME IS NOT NULL then p_Data_Format else 'CSV' end,
					p_Use_Trim => 'Y',
					p_Use_Group_Separator => p_Use_Group_Separator
				) COLUMN_EXPR,
				F.NULLABLE,
				F.COLUMN_NAME FOREIGN_KEY_COLS,
				G.R_VIEW_NAME,
				G.R_TABLE_NAME,
				F.TABLE_ALIAS,
				data_browser_conf.Concat_List(F.TABLE_ALIAS, G.TABLE_ALIAS, '_') R_TABLE_ALIAS,
				case when G.NULLABLE = 'N' and G.R_NULLABLE = 'N' then 'N' else 'Y' end R_NULLABLE,
				G.IS_READONLY R_IS_READONLY,
				G.R_DATA_TYPE,
				G.R_DATA_SCALE,
				G.R_DATA_DEFAULT,
				G.R_DATA_PRECISION,
				G.R_CHAR_LENGTH,
				G.COLUMN_ALIGN,
				G.FIELD_LENGTH,
				G.R_VIEW_NAME JOIN_VIEW_NAME,
				G.HAS_HELP_TEXT, G.HAS_DEFAULT, G.IS_BLOB, G.IS_PASSWORD, G.IS_AUDIT_COLUMN, G.IS_DATETIME, G.DISPLAY_IN_REPORT,
				F.IS_DISPLAYED_KEY_COLUMN,
				F.IS_REFERENCE,
				F.R_VIEW_NAME J_VIEW_NAME,
				F.R_COLUMN_NAME J_COLUMN_NAME,
				F.COMMENTS
			FROM TABLE(data_browser_select.FN_Pipe_browser_fc_refs(v_View_Name)) F
			JOIN MVDATA_BROWSER_F_REFS G ON G.VIEW_NAME = F.R_VIEW_NAME AND G.FOREIGN_KEY_COLS = F.R_COLUMN_NAME
		) FC 
		where not exists (
			select 1 
			from q_refs F
			where F.VIEW_NAME = FC.VIEW_NAME
			and F.FOREIGN_KEY_COLS = FC.COLUMN_NAME 
			and F.COLUMN_ID = FC.COLUMN_ID
			and F.R_VIEW_NAME = FC.R_VIEW_NAME
			and F.R_COLUMN_NAME = FC.R_COLUMN_NAME
			and F.TABLE_ALIAS = FC.TABLE_ALIAS
			and F.R_TABLE_ALIAS = FC.R_TABLE_ALIAS
		)
		AND NOT EXISTS (-- no foreign key columns
			SELECT 1
			FROM MVDATA_BROWSER_REFERENCES E
			WHERE FC.R_VIEW_NAME = E.VIEW_NAME AND FC.R_COLUMN_NAME = E.COLUMN_NAME
		);

		v_in_rows tab_data_browser_qc_refs;
	BEGIN
		OPEN keys_cur(p_View_Name);
		LOOP
			FETCH keys_cur BULK COLLECT INTO v_in_rows LIMIT 100;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
			END LOOP;
		END LOOP;
		CLOSE keys_cur;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_view_name,p_data_format,p_Use_Group_Separator,v_in_rows.COUNT;
        $END
    exception 
      when NO_DATA_NEEDED then
        NULL;
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_view_name,p_data_format,p_Use_Group_Separator;
        RAISE;
	END FN_Pipe_browser_qc_refs;

	/*
		fc_refs: all 1. level table columns of direct references from table A => alias B. 
		FK cols are HIDDEN fields. (join options A)
	*/

	FUNCTION FN_Pipe_browser_fc_refs (p_View_Name VARCHAR2)
	RETURN data_browser_select.tab_data_browser_fc_refs PIPELINED
	IS
		CURSOR keys_cur (v_View_Name VARCHAR2)
		IS
		SELECT
			VIEW_NAME, TABLE_NAME, FK_COLUMN_NAME COLUMN_NAME, COLUMN_ID, NULLABLE, R_COLUMN_ID, POSITION,
			FOREIGN_KEY_COLS, NORM_COLUMN_NAME,
			R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, R_TABLE_NAME, R_COLUMN_NAME, 
			IMP_COLUMN_NAME,
			COLUMN_PREFIX, IS_UPPER_NAME,
			data_browser_conf.Column_Name_to_Header(
				p_Column_Name => COLUMN_HEADER, 
				p_Remove_Extension => 'NO', 
				p_Is_Upper_Name => IS_UPPER_NAME
			) COLUMN_HEADER,
			COLUMN_ALIGN, FIELD_LENGTH, HAS_HELP_TEXT, HAS_DEFAULT,
			IS_BLOB, IS_PASSWORD, IS_AUDIT_COLUMN, IS_DATETIME, 
			IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN, YES_NO_COLUMN_TYPE, 
			IS_SIMPLE_IN_LIST, STATIC_LOV_EXPR, HAS_AUTOMATIC_CHECK, HAS_RANGE_CHECK,
			DISPLAY_IN_REPORT, IS_DISPLAYED_KEY_COLUMN, IS_REFERENCE,
			R_DATA_TYPE, DATA_TYPE_OWNER, R_DATA_PRECISION, R_DATA_SCALE, R_DATA_DEFAULT, R_CHAR_LENGTH, 
			NULLABLE R_NULLABLE, COMMENTS, R_CHECK_UNIQUE, R_IS_READONLY,
			CAST(TABLE_ALIAS AS VARCHAR2(10)) TABLE_ALIAS
		FROM (
			SELECT F.VIEW_NAME, F.TABLE_NAME, F.FOREIGN_KEY_COLS, F.FK_COLUMN_NAME, F.NORM_COLUMN_NAME,
				F.FK_COLUMN_ID COLUMN_ID, F.FK_NULLABLE NULLABLE,
				F.R_PRIMARY_KEY_COLS, F.R_CONSTRAINT_TYPE, -- F.CONSTRAINT_NAME,
				F.R_VIEW_NAME, F.R_TABLE_NAME,
				T.COLUMN_NAME R_COLUMN_NAME,
				T.COLUMN_ID*10000 R_COLUMN_ID, 
				T.COLUMN_ID*10000+NVL(F.FK_COLUMN_ID,0)*100 POSITION,
				data_browser_conf.Compose_FK_Column_Table_Name (
					p_First_Name => F.NORM_COLUMN_NAME,
					p_Second_Name => T.NORM_COLUMN_NAME,
					p_Table_Name => F.R_VIEW_NAME,
					p_Remove_Prefix => S.COLUMN_PREFIX,
					p_Max_Length => 29
				) IMP_COLUMN_NAME,
				S.COLUMN_PREFIX, T.IS_UPPER_NAME,
				data_browser_conf.Compose_FK_Column_Table_Name (
					p_First_Name => F.NORM_COLUMN_NAME,
					p_Second_Name => T.NORM_COLUMN_NAME,
					p_Table_Name => F.R_VIEW_NAME,
					p_Remove_Prefix => S.COLUMN_PREFIX,
					p_Max_Length => 128
				) COLUMN_HEADER,
				T.COLUMN_ALIGN,
				T.FIELD_LENGTH,
				T.HAS_HELP_TEXT,
				T.HAS_DEFAULT,
				T.IS_BLOB,
				T.IS_PASSWORD,
				T.IS_AUDIT_COLUMN,
				T.IS_DATETIME,
				T.IS_NUMBER_YES_NO_COLUMN,
				T.IS_CHAR_YES_NO_COLUMN,
				T.YES_NO_COLUMN_TYPE, 
				T.IS_SIMPLE_IN_LIST, 
				T.STATIC_LOV_EXPR, 
				T.HAS_AUTOMATIC_CHECK,
				T.HAS_RANGE_CHECK,
				T.DISPLAY_IN_REPORT,
				T.IS_DISPLAYED_KEY_COLUMN,
				T.IS_REFERENCE,
				T.DATA_TYPE R_DATA_TYPE,
				T.DATA_TYPE_OWNER,
				T.DATA_PRECISION R_DATA_PRECISION,
				T.DATA_SCALE R_DATA_SCALE,
				T.DATA_DEFAULT R_DATA_DEFAULT,
				T.CHAR_LENGTH R_CHAR_LENGTH,
				T.NULLABLE R_NULLABLE,
				T.COMMENTS,
				T.CHECK_UNIQUE R_CHECK_UNIQUE,
				case when T.IS_DISPLAYED_KEY_COLUMN = 'N' then 'Y' else T.IS_READONLY end R_IS_READONLY,
				data_browser_conf.Sequence_To_Table_Alias(DENSE_RANK() OVER (PARTITION BY F.TABLE_NAME ORDER BY F.FK_COLUMN_ID)) TABLE_ALIAS
			FROM MVDATA_BROWSER_SIMPLE_COLS T
			JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = T.VIEW_NAME
			JOIN MVDATA_BROWSER_FKEYS F ON F.R_VIEW_NAME = T.VIEW_NAME AND S.TABLE_OWNER = F.OWNER
			WHERE ((T.IS_PRIMARY_KEY = 'N' AND T.IS_SEARCH_KEY = 'N') OR T.IS_DISPLAYED_KEY_COLUMN = 'Y') -- Filter Primary Key Column
			AND T.IS_IGNORED = 'N'
			AND F.FK_COLUMN_COUNT = 1
			AND F.VIEW_NAME = v_View_Name
		) FC
		where not exists (
			select 1 
			from MVDATA_BROWSER_F_REFS F
			where F.VIEW_NAME = FC.VIEW_NAME
			and F.FOREIGN_KEY_COLS = FC.FOREIGN_KEY_COLS 
			and F.COLUMN_ID = FC.COLUMN_ID
			and F.R_VIEW_NAME = FC.R_VIEW_NAME
			and F.R_COLUMN_NAME = FC.R_COLUMN_NAME
			and F.TABLE_ALIAS = FC.TABLE_ALIAS
		);

		v_in_rows tab_data_browser_fc_refs;
		v_Count PLS_INTEGER := 0;
	BEGIN
		OPEN keys_cur(p_View_Name);
		LOOP
			FETCH keys_cur BULK COLLECT INTO v_in_rows LIMIT 100;
			EXIT WHEN v_in_rows.COUNT = 0;
			FOR ind IN 1 .. v_in_rows.COUNT LOOP
				pipe row (v_in_rows(ind));
				v_Count := v_Count + 1;
			END LOOP;
		END LOOP;
		CLOSE keys_cur;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_view_name,v_Count;
        $END
	END FN_Pipe_browser_fc_refs;
	
	/*
	List of displayed column names for each user table foreign key target tables.
	The columns names match a pattern in the list of g_Display_Columns_Pattern 
	or the column names are members of unique key definitions
	or the column names are displayed columns of second level foreign keys of composite primary keys.
	*/
	FUNCTION FN_Pipe_browser_q_refs (
		p_View_Name VARCHAR2, 
		p_Data_Format VARCHAR2 DEFAULT 'FORM', 
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,	-- Y,N; use G in number format mask
		p_Include_Schema VARCHAR2 DEFAULT data_browser_conf.Get_Include_Query_Schema
	) RETURN data_browser_select.tab_data_browser_q_refs PIPELINED
	IS
		CURSOR keys_cur (v_View_Name VARCHAR2, v_Data_Format VARCHAR2, v_Include_Schema VARCHAR2)
		IS -- find qualified unique key for target table of foreign key reference
		WITH FOREIGN_KEY_PARENTS AS (
			-- For each foreign key column of a table x a list of candidate parent keys source columns from 
			-- the same table x is calculated. Used to restrict LOV Lists';
			SELECT VIEW_NAME, COLUMN_NAME, R_VIEW_NAME, CONSTRAINT_NAME, DELETE_RULE, FK_NULLABLE,
				R_VIEW_NAME2, FILTER_KEY_COLUMN, R_CONSTRAINT_NAME2, R_DELETE_RULE2, R_NULLABLE2,
				VIEW_NAME2, PARENT_KEY_COLUMN, PARENT_DELETE_RULE, PARENT_NULLABLE
			FROM (
				SELECT E.VIEW_NAME, E.FOREIGN_KEY_COLS COLUMN_NAME, E.R_VIEW_NAME, E.CONSTRAINT_NAME, E.DELETE_RULE, E.FK_NULLABLE,
					F.R_VIEW_NAME2, F.FILTER_KEY_COLUMN, F.R_CONSTRAINT_NAME2, F.R_DELETE_RULE2, F.R_NULLABLE2,
					F.VIEW_NAME2, F.PARENT_KEY_COLUMN, F.PARENT_DELETE_RULE, F.PARENT_NULLABLE
				FROM MVDATA_BROWSER_FKEYS E, (
					SELECT F.VIEW_NAME R_VIEW_NAME, 
						F.FOREIGN_KEY_COLS FILTER_KEY_COLUMN, 
						F.R_VIEW_NAME R_VIEW_NAME2, 
						F.CONSTRAINT_NAME R_CONSTRAINT_NAME2, 
						F.DELETE_RULE R_DELETE_RULE2, 
						F.FK_NULLABLE R_NULLABLE2,
						G.VIEW_NAME VIEW_NAME2, 
						G.FOREIGN_KEY_COLS PARENT_KEY_COLUMN, 
						G.CONSTRAINT_NAME PARENT_CONSTRAINT_NAME, 
						G.DELETE_RULE PARENT_DELETE_RULE, 
						G.FK_NULLABLE PARENT_NULLABLE
					FROM MVDATA_BROWSER_FKEYS F, MVDATA_BROWSER_FKEYS G 
					WHERE G.R_VIEW_NAME = F.R_VIEW_NAME AND G.OWNER = F.OWNER -- back reference to base view 
					AND F.VIEW_NAME != G.VIEW_NAME -- no recursive relations (parent_id)
				) F 
				WHERE E.R_VIEW_NAME = F.R_VIEW_NAME (+) AND E.VIEW_NAME = F.VIEW_NAME2 (+)
			)
			WHERE R_DELETE_RULE2 = 'CASCADE' AND R_NULLABLE2 = 'N' -- referenced table is container 
			AND PARENT_DELETE_RULE = 'CASCADE' AND PARENT_NULLABLE = 'N' -- referenced table is container 
			AND DELETE_RULE = 'CASCADE'
		)
		SELECT /*+ RESULT_CACHE */ 
			F.REF_VIEW_NAME VIEW_NAME,
			F.REF_TABLE_NAME TABLE_NAME,
			F.IMP_COLUMN_NAME,
			F.DEST_COLUMN_NAME,
			COLUMN_PREFIX, IS_UPPER_NAME, 
			data_browser_conf.Column_Name_to_Header(
				p_Column_Name => COLUMN_HEADER, 
				p_Remove_Extension => 'NO', 
				p_Is_Upper_Name => IS_UPPER_NAME
			) COLUMN_HEADER,
			F.WARNING_MSG, F.PRIMARY_KEY_COLS, F.SEARCH_KEY_COLS, F.SHORT_NAME,
			F.COLUMN_ID, F.R_COLUMN_ID, F.POSITION, F.R_COLUMN_NAME,
			F.NULLABLE,
			F.FOREIGN_KEY_COLS, F.R_PRIMARY_KEY_COLS, F.R_CONSTRAINT_TYPE,
			F.R_VIEW_NAME, F.R_TABLE_NAME,
			F.TABLE_ALIAS, F.R_TABLE_ALIAS,
			F.R_NULLABLE, R_DATA_TYPE, R_DATA_SCALE, R_DATA_PRECISION, R_DATA_DEFAULT, 
			R_CHAR_LENGTH,
			COLUMN_ALIGN, FIELD_LENGTH,
			JOIN_VIEW_NAME,
			case when JOIN_COND IS NOT NULL then 
				case when (NULLABLE = 'Y' OR R_NULLABLE = 'Y') then 'LEFT OUTER ' end || 'JOIN '
				|| case when v_Include_Schema = 'YES' then 
					SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || '.'
				end
				|| JOIN_COND
			end JOIN_CLAUSE,
			COLUMN_EXPR,
			F.REF_COLUMN_NAME COLUMN_NAME,			
			HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, 
			IS_AUDIT_COLUMN, IS_DATETIME, IS_READONLY, DISPLAY_IN_REPORT,
			IS_DISPLAYED_KEY_COLUMN, IS_REFERENCE, 
			HAS_NULLABLE, U_CONSTRAINT_NAME, U_MEMBERS, U_MATCHING,
			J_VIEW_NAME, J_COLUMN_NAME, IS_FILE_FOLDER_REF,
			H.FILTER_KEY_COLUMN, -- COLUMN OF TABLE F.R_VIEW_NAME
			H.PARENT_KEY_COLUMN -- COLUMN OF TABLE F.VIEW_NAME
		FROM (
			SELECT DISTINCT 
					CONNECT_BY_ROOT VIEW_NAME Ref_View_Name,
					CONNECT_BY_ROOT TABLE_NAME Ref_Table_Name,
					CONNECT_BY_ROOT FOREIGN_KEY_COLS Ref_Column_Name,
					PRIOR TABLE_NAME TABLE_NAME, 
					PRIOR VIEW_NAME VIEW_NAME,
					PRIOR FOREIGN_KEY_COLS COLUMN_NAME,
					CONNECT_BY_ROOT PRIMARY_KEY_COLS PRIMARY_KEY_COLS,
					CONNECT_BY_ROOT SEARCH_KEY_COLS SEARCH_KEY_COLS,
					CONNECT_BY_ROOT SHORT_NAME SHORT_NAME,
					CONNECT_BY_ROOT COLUMN_ID COLUMN_ID,
					RPAD(REPLACE(SYS_CONNECT_BY_PATH(LPAD(FK_COLUMN_ID, 2, '0'), ' '), ' '), 16, '0') R_COLUMN_ID,
					POSITION*100+R_POSITION POSITION,
					NVL(R_COLUMN_NAME, R_PRIMARY_KEY_COLS) R_COLUMN_NAME,
					case when R_COLUMN_NAME IS NULL then 'No description columns found. (Q)' end WARNING_MSG,
					case when INSTR(SYS_CONNECT_BY_PATH(NULLABLE, '_'), 'Y') > 0 then 'Y' else 'N' end NULLABLE,
					PRIOR FOREIGN_KEY_COLS FOREIGN_KEY_COLS,
					R_PRIMARY_KEY_COLS,
					R_CONSTRAINT_TYPE,
					R_VIEW_NAME,
					R_TABLE_NAME,
					LTRIM(SYS_CONNECT_BY_PATH(PRIOR TABLE_ALIAS, '_'), '_') TABLE_ALIAS,
					LTRIM(SYS_CONNECT_BY_PATH(TABLE_ALIAS, '_'), '_') R_TABLE_ALIAS,
					R_NULLABLE,
					R_DATA_TYPE,
					R_DATA_SCALE,
					R_DATA_PRECISION,
					R_DATA_DEFAULT,
					R_CHAR_LENGTH,
					COLUMN_ALIGN,
					FIELD_LENGTH,
					R_VIEW_NAME JOIN_VIEW_NAME,
					case when FOREIGN_KEY_COLS IS NOT NULL then
						R_VIEW_NAME
						|| ' ' || LTRIM(SYS_CONNECT_BY_PATH(TABLE_ALIAS, '_'), '_')
						|| ' ON ' 
						|| data_browser_conf.Get_Join_Expression(
							p_Left_Columns=>R_PRIMARY_KEY_COLS, p_Left_Alias=> LTRIM(SYS_CONNECT_BY_PATH(TABLE_ALIAS, '_'), '_'),
							p_Right_Columns=>FOREIGN_KEY_COLS, p_Right_Alias=> LTRIM(SYS_CONNECT_BY_PATH(PRIOR TABLE_ALIAS, '_'), '_'))
					end JOIN_COND,
					data_browser_select.Get_ConversionColFunction (
						p_Column_Name => LTRIM(SYS_CONNECT_BY_PATH(TABLE_ALIAS, '_'), '_') || '.' || NVL(R_COLUMN_NAME, R_PRIMARY_KEY_COLS),
						p_Data_Type => R_DATA_TYPE,
						p_Data_Precision => R_DATA_PRECISION,
						p_Data_Scale => R_DATA_SCALE,
						p_Char_Length => R_CHAR_LENGTH,
						p_Data_Format => case when CONNECT_BY_ISLEAF = 1 then v_Data_Format else 'NATIVE' end,
						p_Use_Trim => 'Y',
						p_Use_Group_Separator => p_Use_Group_Separator
					) COLUMN_EXPR,
					data_browser_conf.Compose_Column_Name(
						p_First_Name => REPLACE(LTRIM(SYS_CONNECT_BY_PATH(NORM_COLUMN_NAME, ' ')), ' ', '_'),
						p_Second_Name => NVL(R_COLUMN_NAME, R_PRIMARY_KEY_COLS),
						p_Max_Length => 29
					) IMP_COLUMN_NAME,
					data_browser_conf.Compose_Column_Name(
						p_First_Name => REPLACE(LTRIM(SYS_CONNECT_BY_PATH(PRIOR NORM_COLUMN_NAME, ' ')), ' ', '_'),
						p_Second_Name => FOREIGN_KEY_COLS,
						p_Max_Length => 29
					) DEST_COLUMN_NAME,
					PRIOR COLUMN_PREFIX COLUMN_PREFIX, 
					IS_UPPER_NAME,
					case when U_MEMBERS = 1 and PRIOR VIEW_NAME != R_VIEW_NAME then -- simple column name when only one member is displayed
						data_browser_conf.Compose_Column_Name(
							p_First_Name => REPLACE(LTRIM(SYS_CONNECT_BY_PATH(PRIOR NORM_COLUMN_NAME, ' ')), ' ', '_'),
							p_Second_Name => NORM_COLUMN_NAME,
							p_Deduplication => 'NO', 
							p_Max_Length => 128
						)
					else 
						data_browser_conf.Compose_Column_Name(
							p_First_Name => REPLACE(LTRIM(SYS_CONNECT_BY_PATH(NORM_COLUMN_NAME, ' ')), ' ', '_'),
							p_Second_Name => NVL(R_COLUMN_NAME, R_PRIMARY_KEY_COLS),
							p_Max_Length => 128
						)
					end COLUMN_HEADER,
					HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD,
					IS_AUDIT_COLUMN, IS_DATETIME, IS_READONLY, DISPLAY_IN_REPORT,
					PRIOR IS_DISPLAYED_KEY_COLUMN IS_DISPLAYED_KEY_COLUMN,
					IS_REFERENCE,
					HAS_NULLABLE, U_CONSTRAINT_NAME,
					U_MEMBERS, U_MATCHING,
					PRIOR R_VIEW_NAME J_VIEW_NAME,
					PRIOR R_COLUMN_NAME J_COLUMN_NAME,
					PRIOR IS_FILE_FOLDER_REF IS_FILE_FOLDER_REF
			FROM MVDATA_BROWSER_F_REFS -- , (select 'EMPLOYEES' v_View_Name, 'FORM' v_Data_Format from dual) par
			WHERE LEVEL > 1
			CONNECT BY NOCYCLE VIEW_NAME = PRIOR R_VIEW_NAME AND FOREIGN_KEY_COLS = PRIOR R_COLUMN_NAME 
			START WITH VIEW_NAME = v_View_Name -- Bugfix: DS 20230309 TABLE_NAME was used wrong here.
			AND IS_FILE_FOLDER_REF = 'N'
			-- AND VIEW_NAME != R_VIEW_NAME	-- Bugfix-Canceled DS 20230316 avoid recursion here, folder path is already describing the relation 
			-- I have to rethink recursive relations here!!
			-- In the case that I add a foreign key to the natural key of emps, the manager is not correctly resolved.
		) F, FOREIGN_KEY_PARENTS H 
		WHERE F.J_VIEW_NAME = H.R_VIEW_NAME (+) AND F.VIEW_NAME = H.VIEW_NAME2 (+) AND F.FOREIGN_KEY_COLS = H.COLUMN_NAME (+)
		;

		v_q_ref_cols_md5	VARCHAR2(300);
		v_is_cached			VARCHAR2(10);
	BEGIN
		v_q_ref_cols_md5 := wwv_flow_item.md5 (p_View_Name, p_Data_Format, p_Include_Schema);
		v_is_cached := case when g_q_ref_cols_md5 != v_q_ref_cols_md5 then 'load' else 'cached!' end;
		if v_is_cached != 'cached!' then
			OPEN keys_cur(p_View_Name, p_Data_Format, p_Include_Schema);
			FETCH keys_cur BULK COLLECT INTO g_q_ref_cols_tab;
			CLOSE keys_cur;
			g_q_ref_cols_md5 := v_q_ref_cols_md5;
		end if;
		FOR ind IN 1 .. g_q_ref_cols_tab.COUNT LOOP
			pipe row (g_q_ref_cols_tab(ind));
		END LOOP;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_view_name,p_data_format,p_Use_Group_Separator,p_include_schema,g_q_ref_cols_tab.COUNT;
        $END
    exception 
      when NO_DATA_NEEDED then
        NULL;
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_view_name,p_data_format,p_Use_Group_Separator,p_include_schema;
        RAISE;
	END FN_Pipe_browser_q_refs;


	FUNCTION FN_Pipe_table_imp_fk1 (p_Table_Name VARCHAR2)
	RETURN data_browser_select.tab_table_imp_fk PIPELINED
	IS
		CURSOR views_cur (v_Table_Name VARCHAR2)
		IS
		-- 1. level foreign keys
		SELECT --+ INDEX(S)
			S.VIEW_NAME, S.TABLE_NAME, S.PRIMARY_KEY_COLS, S.SHORT_NAME,
			S.FOREIGN_KEY_COLS COLUMN_NAME,
			S.R_VIEW_NAME		S_VIEW_NAME,
			S.IMP_COLUMN_NAME	S_REF,
			S.VIEW_NAME			D_VIEW_NAME,					-- lookup ids of imported table + related
			S.FOREIGN_KEY_COLS	D_REF,
			S.FOREIGN_KEY_COLS	D_COLUMN_NAME,
			S.IS_FILE_FOLDER_REF,
			G.FOLDER_PARENT_COLUMN_NAME,
			G.FOLDER_NAME_COLUMN_NAME,
			G.FOLDER_CONTAINER_COLUMN_NAME,
			NULL FILTER_KEY_COLUMN, NULL PARENT_KEY_COLUMN, 
			S.R_PRIMARY_KEY_COLS, S.R_CONSTRAINT_TYPE,
			S.R_TABLE_NAME, S.R_VIEW_NAME, S.COLUMN_ID, S.NULLABLE,
			S.R_COLUMN_ID, S.R_COLUMN_NAME, S.POSITION, S.R_NULLABLE, S.R_DATA_TYPE,
			S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_CHAR_LENGTH, S.IS_DATETIME,
			S.TABLE_ALIAS, S.IMP_COLUMN_NAME, NULL JOIN_CLAUSE,
			SUM(case when S.R_NULLABLE = 'Y' then 1 else 0 end) OVER (PARTITION BY S.TABLE_NAME, S.FOREIGN_KEY_COLS) HAS_NULLABLE,
			SUM(case when U.U_MEMBERS = 1 THEN 1 else 0 end ) OVER (PARTITION BY S.TABLE_NAME, S.FOREIGN_KEY_COLS) HAS_SIMPLE_UNIQUE,
			case when S.IS_REFERENCE = 'N' then 0 else 1 end HAS_FOREIGN_KEY,
			U.U_CONSTRAINT_NAME, 
			S.U_MEMBERS, 
			2 POSITION2
		FROM MVDATA_BROWSER_F_REFS S
		LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES G ON S.VIEW_NAME = G.VIEW_NAME AND S.FOREIGN_KEY_COLS = G.COLUMN_NAME AND S.IS_FILE_FOLDER_REF = 'Y'
		LEFT OUTER JOIN MVDATA_BROWSER_U_REFS U ON U.VIEW_NAME = S.R_VIEW_NAME AND U.COLUMN_NAME = S.R_COLUMN_NAME AND U.RANK = 1  -- unique key columns for each foreign key
		-- , (SELECT 'SALES' p_Table_name, 'NO' p_As_Of_Timestamp FROM DUAL ) PAR
		WHERE S.TABLE_NAME = NVL(v_Table_Name, S.TABLE_NAME)
		AND S.R_COLUMN_ID IS NOT NULL;
		v_in_row rec_table_imp_fk;
		v_Count PLS_INTEGER := 0;
	BEGIN
		OPEN views_cur(p_Table_Name);
		LOOP
			FETCH views_cur INTO v_in_row;
			EXIT WHEN views_cur%NOTFOUND;
			pipe row (v_in_row);
			v_Count := v_Count + 1;
		END LOOP;
		CLOSE views_cur;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,v_Count;
        $END
	end FN_Pipe_table_imp_fk1;

	FUNCTION FN_Pipe_table_imp_fk2 (
		p_Table_Name VARCHAR2,
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Data_Format VARCHAR2 DEFAULT 'FORM'
	)
	RETURN data_browser_select.tab_table_imp_fk PIPELINED
	IS
		CURSOR views_cur (v_Table_Name VARCHAR2)
		IS
		-- 2. level foreign keys
		SELECT	--+ INDEX(Q) USE_NL_WITH_INDEX(S)
			Q.VIEW_NAME, Q.TABLE_NAME, Q.SEARCH_KEY_COLS, Q.SHORT_NAME,
			Q.FOREIGN_KEY_COLS	COLUMN_NAME,
			Q.R_VIEW_NAME		S_VIEW_NAME,
			Q.IMP_COLUMN_NAME	S_REF,
			Q.J_VIEW_NAME		D_VIEW_NAME,
			Q.DEST_COLUMN_NAME D_REF,
			Q.DEST_COLUMN_NAME D_COLUMN_NAME,
			Q.IS_FILE_FOLDER_REF,
			null FOLDER_PARENT_COLUMN_NAME,
			null FOLDER_NAME_COLUMN_NAME,
			null FOLDER_CONTAINER_COLUMN_NAME,
			Q.FILTER_KEY_COLUMN, Q.PARENT_KEY_COLUMN, 
			Q.R_PRIMARY_KEY_COLS, Q.R_CONSTRAINT_TYPE,
			Q.R_TABLE_NAME, Q.R_VIEW_NAME, Q.COLUMN_ID, Q.NULLABLE,
			Q.R_COLUMN_ID, Q.R_COLUMN_NAME, Q.POSITION, Q.R_NULLABLE, Q.R_DATA_TYPE,
			Q.R_DATA_PRECISION, Q.R_DATA_SCALE, Q.R_CHAR_LENGTH, Q.IS_DATETIME,
			Q.R_TABLE_ALIAS		TABLE_ALIAS, 
			Q.IMP_COLUMN_NAME,
			case when p_As_Of_Timestamp = 'YES'
				then REPLACE (Q.JOIN_CLAUSE, Q.JOIN_VIEW_NAME, custom_changelog.Get_ChangeLogViewName(Q.JOIN_VIEW_NAME))
				else Q.JOIN_CLAUSE
			end JOIN_CLAUSE,
			SUM(case when Q.R_NULLABLE = 'Y' then 1 else 0 end) OVER (PARTITION BY Q.TABLE_NAME, Q.FOREIGN_KEY_COLS) HAS_NULLABLE,
			SUM(case when Q.U_MEMBERS = 1 THEN 1 else 0 end ) OVER (PARTITION BY Q.TABLE_NAME, Q.FOREIGN_KEY_COLS) HAS_SIMPLE_UNIQUE,
			case when Q.IS_REFERENCE = 'N' then 0 else 1 end HAS_FOREIGN_KEY,
			Q.U_CONSTRAINT_NAME, Q.U_MEMBERS, 1 POSITION2
		FROM MVDATA_BROWSER_VIEWS S, TABLE(data_browser_select.FN_Pipe_browser_q_refs(p_View_Name => S.VIEW_NAME, p_Data_Format => p_Data_Format)) Q 
		where Q.IS_FILE_FOLDER_REF = 'N' 
		and S.TABLE_NAME = v_Table_Name;	-- Bugfix: DS 20230309 TABLE_NAME was used wrong here.
		
		v_in_row rec_table_imp_fk;
		v_Count PLS_INTEGER := 0;
	BEGIN
		OPEN views_cur(p_Table_Name);
		LOOP
			FETCH views_cur INTO v_in_row;
			EXIT WHEN views_cur%NOTFOUND;
			pipe row (v_in_row);
			v_Count := v_Count + 1;
		END LOOP;
		CLOSE views_cur;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_as_of_timestamp,p_data_format,v_Count;
        $END
	end FN_Pipe_table_imp_fk2;

	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2 
	is begin return data_browser_conf.NL(p_Indent);
	end NL;

	FUNCTION CM(p_Param_Name VARCHAR2) RETURN VARCHAR2	-- remove comments for compact code generation
	is
	begin
		return case when data_browser_conf.NL(1) = chr(10)
			then NULL
			else ' ' || p_Param_Name || ' '
		end;
	end CM;

	FUNCTION PA(p_Param_Name VARCHAR2) RETURN VARCHAR2	-- remove parameter names for compact code generation
	is
	begin
		return case when data_browser_conf.NL(1) = chr(10)
			then case when INSTR(p_Param_Name, ',') > 0 then ',' else '' end
			else p_Param_Name
		end;
	end PA;

	FUNCTION FN_Terminate_List(p_String VARCHAR2) return VARCHAR2 DETERMINISTIC
	is begin return ':'||p_String||':'; 
	end FN_Terminate_List;
	
	FUNCTION FN_List_Offest(p_Select_Columns VARCHAR2, p_Column_Name VARCHAR2) return NUMBER 
	is 
	PRAGMA UDF;
	begin 
		return INSTR(FN_Terminate_List(p_Select_Columns), FN_Terminate_List(p_Column_Name));
	end FN_List_Offest;
	
	FUNCTION Field_Has_CInput_ID (	-- function returns 1, when the field is an character input field.
		p_Column_Expr_Type IN VARCHAR2
	)
	RETURN INTEGER DETERMINISTIC	-- 0, 1
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Column_Expr_Type IN ('HIDDEN', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR') 
			then 0 else 1 
		end;
	END Field_Has_CInput_ID;

	FUNCTION Field_Has_HCInput_ID ( -- function returns 1, when the field is an character input field.
		p_Column_Expr_Type IN VARCHAR2,
		p_Data_Type VARCHAR2,
		p_Is_Search_Key VARCHAR2 DEFAULT 'N',	-- Y, N
		p_Is_Foreign_Key VARCHAR2 DEFAULT 'N'	-- Y, N
	)
	RETURN INTEGER DETERMINISTIC	-- 0, 1
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Column_Expr_Type = 'HIDDEN' and p_Data_Type != 'NUMBER'
				and (p_Is_Search_Key = 'Y' or p_Is_Foreign_Key = 'Y')
				then 1 else 0 end;
	END Field_Has_HCInput_ID;

	FUNCTION Field_Has_NInput_ID (	-- function returns 1, when the field is a hidden serial primary or foreign key
		p_Column_Expr_Type VARCHAR2,
		p_Data_Type VARCHAR2,
		p_Is_Search_Key VARCHAR2 DEFAULT 'N',	-- Y, N
		p_Is_Foreign_Key VARCHAR2 DEFAULT 'N'	-- Y, N
	)
	RETURN INTEGER DETERMINISTIC	-- 0, 1
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Column_Expr_Type = 'HIDDEN' and p_Data_Type = 'NUMBER'
				and (p_Is_Search_Key = 'Y' or p_Is_Foreign_Key = 'Y')
				then 1 else 0 end;
	END Field_Has_NInput_ID;

	FUNCTION FN_Has_Collections_Adress (
		p_View_Mode VARCHAR2,
		p_cols_rec data_browser_conf.rec_record_view
	) RETURN BOOLEAN DETERMINISTIC
	is
	begin
		return (
		  NOT(p_View_Mode = 'IMPORT_VIEW'
			and p_cols_rec.INPUT_ID NOT BETWEEN 'C001' AND 'C050'
			and p_cols_rec.INPUT_ID NOT BETWEEN 'N001' AND 'N005'
			and p_cols_rec.COLUMN_ID != -1)
		  or p_cols_rec.IS_VIRTUAL_COLUMN = 'Y');
	end FN_Has_Collections_Adress;

	FUNCTION FN_Show_Parent_Key (
		p_Parent_Key_Visible VARCHAR2,
		p_Parent_Name VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_cols_rec data_browser_conf.rec_record_view
	) RETURN BOOLEAN DETERMINISTIC
	is
	begin
		return (
			p_Parent_Key_Visible != 'NO' 
			or p_Parent_Name IS NULL
			or p_cols_rec.TABLE_ALIAS IS NULL
			or NOT(p_cols_rec.REF_VIEW_NAME = p_Parent_Name and p_cols_rec.R_COLUMN_NAME = NVL(p_Parent_Key_Column, p_cols_rec.R_COLUMN_NAME))
		);
	end FN_Show_Parent_Key;

	FUNCTION FN_Filter_Parent_Key (
		p_Parent_Key_Visible VARCHAR2,
		p_Parent_Name VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_Ref_View_Name VARCHAR2,
		p_R_Column_Name VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	is
	PRAGMA UDF;
		v_Result VARCHAR2(10);
	begin
		v_Result := case when (
			p_Parent_Key_Visible != 'NO' 
			or p_Parent_Name IS NULL
			or NOT(p_Ref_View_Name = p_Parent_Name and p_R_Column_Name = NVL(p_Parent_Key_Column, p_R_Column_Name))
		) then 'NO' else 'YES' end;
		return v_Result;
	end FN_Filter_Parent_Key;

	FUNCTION FN_Table_Prefix (p_Schema_Name VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 
	is 
	begin 
		return case
		when p_Schema_Name != SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') then 
			p_Schema_Name || '.'
		when data_browser_conf.Get_Include_Query_Schema = 'YES' then 
			SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || '.'
		end;
	end FN_Table_Prefix;
	
	FUNCTION FN_Current_Data_Format RETURN VARCHAR2 
	is 
	begin 
		return case 
			when data_browser_conf.Get_Export_CSV_Mode = 'YES' then 'CSV' 
			when APEX_APPLICATION.G_PRINTER_FRIENDLY then 'HTML'
			else data_browser_conf.Get_Current_Data_Format
		end;
	end FN_Current_Data_Format;

	FUNCTION FN_Show_Row_Selector (
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Edit_Mode VARCHAR2,	-- YES, NO
		p_Report_Mode VARCHAR2,-- YES, NO
		p_View_Mode VARCHAR2,
		p_Data_Columns_Only VARCHAR2, -- YES, NO
		p_Column_Name VARCHAR2
	) RETURN BOOLEAN DETERMINISTIC
	is
	begin
		if p_Column_Name = 'ROW_SELECTOR$' then 
			return (p_Edit_Mode = 'YES' and p_Report_Mode = 'YES' and p_Data_Format IN ('FORM', 'CSV', 'NATIVE', 'QUERY') 
				or p_View_Mode = 'HISTORY')	 and p_Data_Columns_Only = 'NO';
		elsif p_Column_Name IN ('CONTROL_BREAK$', 'LINK_ID$') then
			return p_Data_Columns_Only = 'NO';
		elsif p_Column_Name IN ('IMPORTJOB_ID$', 'LINE_NO$') then
			return p_Data_Columns_Only = 'ALL';
		else 
			return true;
		end if;
	end FN_Show_Row_Selector;

	FUNCTION FN_Show_Import_Job (
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Column_Name VARCHAR2
	) RETURN BOOLEAN DETERMINISTIC
	is
	begin
		return (p_Data_Format = 'FORM' or p_Column_Name NOT IN ('LINE_NO$', 'IMPORTJOB_ID$'));
	end FN_Show_Import_Job;

	FUNCTION FN_Display_In_Report (
		p_Data_Format VARCHAR2,
		p_Report_Mode VARCHAR2,		-- YES,NO,ALL
		p_View_Mode VARCHAR2,
		p_cols_rec data_browser_conf.rec_record_view,
		p_Select_Columns VARCHAR2 DEFAULT NULL -- ':'-terminated column list 
	) RETURN BOOLEAN DETERMINISTIC
	is
	begin
		if p_cols_rec.COLUMN_NAME = 'CONTROL_BREAK$' then 
			return (p_Report_Mode = 'YES' and NOT(p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') and p_Data_Format IN ('CSV', 'NATIVE')));
		elsif p_cols_rec.IS_SEARCH_KEY = 'Y' and p_cols_rec.DISPLAY_IN_REPORT = 'N' then
			return (p_Report_Mode IN ('NO', 'ALL') or p_View_Mode IN ('RECORD_VIEW', 'IMPORT_VIEW', 'EXPORT_VIEW'));
		elsif p_cols_rec.COLUMN_NAME IN ('LINK_ID$', 'ROW_SELECTOR$') 
				or p_cols_rec.COLUMN_EXPR_TYPE = 'HIDDEN' then	
			return p_cols_rec.DISPLAY_IN_REPORT = 'Y';				-- show only in reports
		elsif p_Select_Columns = '::' then -- default columns for view mode
			if p_cols_rec.COLUMN_EXPR_TYPE IN ('LINK', 'LINK_LIST') then 
				return (p_Report_Mode = 'ALL'			-- show all columns
					or p_cols_rec.DISPLAY_IN_REPORT = 'Y');
			else
				return ((p_Report_Mode = 'YES' and p_cols_rec.DISPLAY_IN_REPORT = 'Y') 
					or (p_Report_Mode IN ('ALL', 'NO') and p_View_Mode != 'RECORD_VIEW')
					or (p_View_Mode = 'RECORD_VIEW' and p_cols_rec.TABLE_ALIAS = 'A')); -- show audit columns
			end if;
		else 
			return INSTR(p_Select_Columns, FN_Terminate_List(p_cols_rec.COLUMN_NAME)) > 0;
		end if;
	end FN_Display_In_Report;


	FUNCTION FN_Parent_Key_Visible (
		p_Parent_Key_Visible VARCHAR2,
		p_Edit_Mode VARCHAR2,
		p_View_Mode VARCHAR2,
		p_Data_Format VARCHAR2,
		p_Select_Columns VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	is
		v_Parent_Key_Visible VARCHAR2(10);
	begin
		if p_Select_Columns IS NOT NULL or p_Edit_Mode = 'YES' then 
			v_Parent_Key_Visible := 'YES';
		elsif p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			v_Parent_Key_Visible := case when p_Data_Format IN ('CSV', 'NATIVE') then 'YES' else p_Parent_Key_Visible end;
		else 
			v_Parent_Key_Visible := p_Parent_Key_Visible;
		end if;
		return v_Parent_Key_Visible;
	end FN_Parent_Key_Visible;

	FUNCTION FN_Is_Searchable_Column(
		p_Column_Expr_Type VARCHAR2,
		p_Is_Searchable_Ref VARCHAR2 DEFAULT 'N'
	) RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		return case when p_Is_Searchable_Ref = 'Y' 
		and p_Column_Expr_Type IN ('TEXT', 'TEXTAREA', 'TEXT_EDITOR', 'NUMBER', 'DATE_POPUP', 
			'SWITCH_CHAR', 'SWITCH_NUMBER', 'SELECT_LIST', 'ORDERING_MOVER', 'DISPLAY_AND_SAVE', 'DISPLAY_ONLY',
			'POPUPKEY_FROM_LOV', 'POPUP_FROM_LOV', 'SELECT_LIST_FROM_QUERY', 'LINK')
			-- nested subquerys in REGEXP_INSTR clause cause core dump of oracle server process.
				then 'YES' else 'NO'
		end;
	END FN_Is_Searchable_Column;

	FUNCTION FN_Is_Sortable_Column(
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		return case when p_Column_Expr_Type NOT IN ('HIDDEN', 'LINK_ID', 'LINK_LIST', 'ROW_SELECTOR', 'FILE_BROWSER', 'TEXT_EDITOR' )
			then 'YES' else 'NO'
		end;
	END FN_Is_Sortable_Column;

	FUNCTION FN_Apex_Item_Use_Column (
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	is
	begin
		return case when p_Column_Expr_Type IN 
		('DATE_POPUP', 'POPUPKEY_FROM_LOV', 'SELECT_LIST_FROM_QUERY', 'SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER') then 'YES' else 'NO' end;
	end FN_Apex_Item_Use_Column;

	FUNCTION Bold_Total_Html (
		p_Data_Format VARCHAR2, -- FORM, QUERY, CSV, NATIVE. Format of the final projection columns.
		p_Value VARCHAR2,
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
	begin
		return case when p_Data_Format IN ('FORM', 'QUERY', 'HTML') then
			'FN_Bold_Total('
			|| PA('p_Value=>') || NVL(p_Value, 'NULL') || NL(6) || ', ' 
			|| PA('p_Is_Total=>') || NVL(p_Is_Total, '0') || ', '
			|| PA('p_Is_Subtotal=>') || NVL(p_Is_Subtotal, '0') || NL(4)
			|| ')'
		else 
			p_Value
		end;
	end Bold_Total_Html;

	FUNCTION Navigation_Counter_HTML(
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_CounterQuery VARCHAR2,
		p_Target VARCHAR2,
		p_Link_Page_ID PLS_INTEGER,
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return case when p_Data_Format IN ('FORM', 'QUERY') then
			'FN_Navigation_Counter('
			|| PA('p_Count=>') || p_CounterQuery || ', '
			|| PA('p_Target=>') || p_Target || ', ' 
			|| PA('p_Page_ID=>') || p_Link_Page_ID
			|| case when p_Is_Total IS NOT NULL or p_Is_Subtotal IS NOT NULL then 
				', ' || PA('p_Is_Total=>') || NVL(p_Is_Total, '0') 
				|| ', ' || PA('p_Is_Subtotal=>') || NVL(p_Is_Subtotal, '0') 
			end 
			|| NL(4)
			|| ')'
		when p_Data_Format = 'HTML' then 
			Bold_Total_Html (
				p_Data_Format => p_Data_Format,
				p_Value => p_CounterQuery,
				p_Is_Total => p_Is_Total,
				p_Is_Subtotal => p_Is_Subtotal
			)
		else 
			p_CounterQuery
		end;
	end Navigation_Counter_HTML;

	FUNCTION Nested_Link_HTML(
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_CounterQuery VARCHAR2, -- SQL Expression
		p_Attributes VARCHAR2,	-- SQL Expression
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return case when p_Data_Format IN ('FORM', 'QUERY') then
			'FN_Nested_Link('
			|| PA('p_Count=>') || p_CounterQuery || ', ' 
			|| PA('p_Attributes=>') || p_Attributes 
			|| case when p_Is_Total IS NOT NULL or p_Is_Subtotal IS NOT NULL then 
				NL(6) || ', ' || PA('p_Is_Total=>') || NVL(p_Is_Total, '0') 
				|| ', ' || PA('p_Is_Subtotal=>') || NVL(p_Is_Subtotal, '0') 
			end 
			|| NL(4)
			|| ')'
		when p_Data_Format = 'HTML' then 
			Bold_Total_Html (
				p_Data_Format => p_Data_Format,
				p_Value => p_CounterQuery,
				p_Is_Total => p_Is_Total,
				p_Is_Subtotal => p_Is_Subtotal
			)
		else 
			p_CounterQuery
		end;
	end Nested_Link_HTML;


	FUNCTION Detail_Link_Html (
		p_Data_Format VARCHAR2, -- FORM, QUERY, CSV, NATIVE. Format of the final projection columns.
		p_Table_name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Link_Page_ID NUMBER,	-- Page ID of target links
		p_Link_Items VARCHAR2, -- Item names for TABLE_NAME,PARENT_TABLE,ID
		p_Key_Value VARCHAR2,
		p_Parent_Value VARCHAR2 DEFAULT NULL,
		p_Is_Total VARCHAR2 DEFAULT NULL,
		p_Is_Subtotal VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return case when p_Data_Format IN ('FORM', 'QUERY', 'HTML') then
			'FN_Detail_Link('
			|| PA('p_Table_name=>') || DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_name) || ', ' 
			|| PA('p_Parent_Table=>') || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Table) || ', '
			|| PA('p_Link_Page_ID=>') || p_Link_Page_ID || ', ' || NL(8)
			|| PA('p_Link_Items=>') || p_Link_Items || ', ' || NL(8)
			|| PA('p_Edit_Enabled=>') || DBMS_ASSERT.ENQUOTE_LITERAL(data_browser_utl.Check_Edit_Enabled(p_Table_name)) || ', ' 
			|| PA('p_Key_Value=>') || NVL(p_Key_Value, 'NULL') || ', ' 
			|| PA('p_Parent_Value=>') || case when p_Parent_Value IS NOT NULL then 
				data_browser_conf.Get_Foreign_Key_Expression(p_Foreign_Key_Column=>p_Parent_Value, p_Table_Alias=> 'A', p_View_Mode => p_View_Mode)
			else 
				'NULL' 
			end 
			|| case when p_Is_Total IS NOT NULL or p_Is_Subtotal IS NOT NULL then 
				', ' || PA('p_Is_Total=>') || NVL(p_Is_Total, '0') 
				|| ', ' || PA('p_Is_Subtotal=>') || NVL(p_Is_Subtotal, '0') 
			end 
			|| ')'
		else 
			p_Key_Value
		end;
	end Detail_Link_Html;

	FUNCTION Get_Form_Required_Html (
		p_Is_Required VARCHAR2 DEFAULT 'N',
		p_Check_Unique VARCHAR2 DEFAULT 'N',
		p_Display_Key_Column VARCHAR2 DEFAULT 'N'
	) RETURN VARCHAR2 DETERMINISTIC
	is
	PRAGMA UDF;
		v_Result VARCHAR2(512);
	begin
		v_Result := case when p_Is_Required = 'Y'
			then '<span class="a-Icon icon-asterisk"></span>' -- red asterisk symbol
		end
		|| case when p_Check_Unique = 'Y' then 
				'<span style="font-size: 60%; vertical-align: top; margin-left: 2px;">&#x1f511;</span>'		-- key symbol
			when p_Display_Key_Column = 'Y' then 
				'<span style="font-size: 60%; vertical-align: top; margin-left: 2px;">&#x1f5dd;</span>'		-- old key symbol
				--	&#x1f9f2; -- magnet symbol
		end;
		return case when v_Result IS NOT NULL then
			'<span class="t-Form-required">' || v_Result || '</span>'
		end;
	end Get_Form_Required_Html;

	FUNCTION Get_Form_Help_Link_Html (
		p_Column_Id NUMBER,
		p_R_View_Name VARCHAR2,
		p_R_Column_Name VARCHAR2,
		p_Column_Header VARCHAR2,
		p_Comments VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_title VARCHAR2(4000);
	begin
		v_title := apex_lang.lang('Field Infos') || ' ' || htf.escape_sc(p_Column_Header);
		return '<button id="'
		|| p_COLUMN_ID
		|| '" class="t-Button t-Button--noUI t-Button--helpButton"'
		|| ' data-itemhelp="'|| p_R_VIEW_NAME || '.' || p_R_Column_Name || '"'
		|| ' title="' || v_title
		|| case when p_Comments IS NOT NULL then ' : ' || htf.escape_sc(p_Comments) end
		|| '"'
		|| ' aria-label="' || v_title || '"'
		|| ' tabindex="-1" type="button" onclick="void(0);"'
		|| '>'
		|| '<span class="a-Icon icon-help" aria-hidden="true"></span>'
		|| '</button>';
	end Get_Form_Help_Link_Html;


	PROCEDURE Reset_Cache
	IS
	BEGIN
		g_Describe_Cols_md5 := 'X';
	END;

	FUNCTION Current_Job_ID RETURN NUMBER
	IS
	PRAGMA UDF;
	BEGIN return g_Export_Job_ID; END;


	FUNCTION Get_Unique_Key_Expression (	-- row reference in where clause, produces A.ROWID references in case of composite or missing unique keys
		p_Table_Name VARCHAR2,
		p_Unique_Key_Column VARCHAR2,
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW'
	) RETURN VARCHAR2 
	IS
		v_Unique_Key_Column VARCHAR2(1024) := p_Unique_Key_Column;
	BEGIN
		if v_Unique_Key_Column IS NULL then
			SELECT T.SEARCH_KEY_COLS
			INTO v_Unique_Key_Column
			FROM MVDATA_BROWSER_VIEWS T
			WHERE T.VIEW_NAME = p_Table_Name;
		end if;
		return data_browser_conf.Get_Unique_Key_Expression (	
			p_Unique_Key_Column => v_Unique_Key_Column,
			p_View_Mode => p_View_Mode
		);
	END Get_Unique_Key_Expression;

	FUNCTION Highlight_Search_Expr (
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Column_Expr VARCHAR2,
		p_Column_Expr_Type VARCHAR2,
		p_Is_Searchable_Ref VARCHAR2,
		p_Search_Item VARCHAR2
	)  RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Search_Item IS NOT NULL
			and data_browser_select.FN_Is_Searchable_Column(p_Column_Expr_Type, p_Is_Searchable_Ref) = 'YES'
			and p_Data_Format = 'FORM' then
				 'data_browser_conf.Highlight_Search('
				|| p_Column_Expr || ', ' || p_Search_Item || ')'
			else
				p_Column_Expr
			end;
	END Highlight_Search_Expr;

	FUNCTION Get_Apex_Item_Checkbox (
		p_Idx NUMBER,
		p_value VARCHAR2,
		p_attributes VARCHAR2 DEFAULT NULL,
		p_checked_values VARCHAR2 DEFAULT NULL,
		p_checked_values_delimiter VARCHAR2 DEFAULT ':',
		p_item_id VARCHAR2 DEFAULT NULL,
		p_item_label VARCHAR2
	) RETURN VARCHAR2
	IS
	BEGIN
		return 'APEX_ITEM.CHECKBOX2 ('
		|| PA('p_idx => ') || p_Idx
		|| PA(', p_value => ') || p_value
		|| PA(', p_attributes => ') || data_browser_conf.Enquote_Literal('class="js-ignoreChange" ' || p_attributes)
		|| PA(', p_checked_values => ') ||
			case when p_checked_values IS NOT NULL then
				data_browser_conf.Enquote_Literal(p_checked_values) else 'NULL' end
		|| PA(', p_checked_values_delimiter => ') ||
			case when p_checked_values_delimiter IS NOT NULL then
				data_browser_conf.Enquote_Literal(p_checked_values_delimiter) else 'NULL' end
		|| NL(8)
		|| PA(', p_item_id => ') || NVL(p_item_id, data_browser_conf.Enquote_Literal('f' || p_Idx || '_') || '||ROWNUM')
		|| PA(', p_item_label => ') || data_browser_conf.Enquote_Literal(p_item_label)
		|| ') ';
	END Get_Apex_Item_Checkbox;

	FUNCTION Get_Apex_Item_Hidden (
		p_Idx NUMBER,
		p_value VARCHAR2,
		p_item_id VARCHAR2 DEFAULT NULL,
		p_item_label VARCHAR2,
		p_attributes VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	IS
	BEGIN
		return 'APEX_ITEM.HIDDEN ('
		|| PA('p_idx => ') || p_Idx
		|| PA(', p_value => ') || p_value
		|| PA(', p_item_id => ') || NVL(p_item_id, data_browser_conf.Enquote_Literal('f' || p_Idx || '_') || '||ROWNUM')
		|| PA(', p_item_label => ') || data_browser_conf.Enquote_Literal(p_item_label)
		|| ') ';
	END Get_Apex_Item_Hidden;

	FUNCTION Get_Row_Selector_Expr (
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Column_Expr VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		RETURN case when p_Data_Format = 'FORM' then
			data_browser_select.Get_Apex_Item_Hidden (
				p_Idx => data_browser_conf.Get_Link_ID_Index,
				p_value => p_Column_Expr,
				p_item_label => p_Column_Name
			)
			|| '||' || NL(4)
			|| case when p_Column_Expr != 'NULL' then
				data_browser_select.Get_Apex_Item_Checkbox (
					p_Idx => data_browser_conf.Get_Row_Selector_Index,
					p_value => p_Column_Expr,
					p_item_label => p_Column_Name
				)
			else 
				data_browser_select.Get_Apex_Item_Hidden (
					p_Idx => data_browser_conf.Get_Row_Selector_Index,
					p_value => p_Column_Expr,
					p_item_label => p_Column_Name
				)
			end
		else
			p_Column_Expr
		end;
	END Get_Row_Selector_Expr;
	
	FUNCTION Markup_Differences_Expr (
		p_Data_Format VARCHAR2, -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Key_Column VARCHAR2,
		p_Column_Expr VARCHAR2,
		p_Column_Name VARCHAR2,
		p_Data_Type VARCHAR2
	)  RETURN VARCHAR2
	IS
	PRAGMA UDF;
		v_Column_Expr VARCHAR2(4000);
		v_Key_Column VARCHAR2(4000);
		v_Pattern VARCHAR2(400);
	BEGIN
		v_Key_Column  := 'A.'||data_browser_conf.First_Element(p_Key_Column); -- column that is probed by NVL2
		v_Pattern := '(^|\s|\W+)A\.' || p_Column_Name || '($|\s|\W+)';
		v_Column_Expr := REGEXP_REPLACE(p_Column_Expr, v_Pattern, '\1NVL2(' || v_Key_Column || ', A.' || p_Column_Name || ', B.' || p_Column_Name || ')\2', 1, 1);
		-- Bugfix DS 20230227: use First_Element(p_Key_Column) to avoid error with multible key columns, and replace the A.Column_Name at the end of the expression
		RETURN case when p_Data_Format IN ('FORM', 'HTML') then
			 data_browser_conf.Get_Markup_Function(p_Data_Type => p_Data_Type)
			 || '(' || v_Column_Expr
			 || ', ' || v_Key_Column
			 || ', A.' || p_Column_Name
			 || ', B.' || p_Column_Name
			 || ')'
		else
			v_Column_Expr
		end;
	END Markup_Differences_Expr;

	FUNCTION Key_Values_Query (
		p_Table_Name	VARCHAR2,
		p_Display_Col_Names VARCHAR2,	-- display columns,
		p_Extra_Col_Names VARCHAR2 DEFAULT NULL, -- extra columns,
		p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
		p_Search_Value	VARCHAR2 DEFAULT NULL, -- used to produce only a single output row for known value or reference
		p_View_Mode VARCHAR2,
		p_Filter_Cond VARCHAR2 DEFAULT NULL,
		p_Exclude_Col_Name VARCHAR2 DEFAULT NULL,
		p_Active_Col_Name VARCHAR2 DEFAULT NULL,
		p_Active_Data_Type VARCHAR2 DEFAULT NULL,		-- NUMBER, CHAR
		p_Order_by VARCHAR2 DEFAULT NULL,
		p_Level INTEGER DEFAULT 1,
		p_Indent INTEGER DEFAULT 4
	) RETURN VARCHAR2
	IS
	PRAGMA UDF;
		v_Column_List VARCHAR2(32767);
		v_From_Clause VARCHAR2(4000);
		v_Column_Expr VARCHAR2(4000);
		v_Table_Alias	VARCHAR2(20);
		v_Delimiter CONSTANT VARCHAR2(512) :=  '||''' || data_browser_conf.Get_Rec_Desc_Delimiter || '''' || NL(p_Indent+4 + (p_Level-1)*4) || '|| ';
		v_Group_Delimiter CONSTANT VARCHAR2(512) :=	 '||''' || data_browser_conf.Get_Rec_Desc_Group_Delimiter || '''' || NL(p_Indent + 4 + (p_Level-1)*4) || '|| ';
		v_Alias_Prefix CONSTANT VARCHAR2(20) :=	 'L' || p_Level;
		v_Alias_Required VARCHAR2(5) := 
			case when p_Filter_Cond IS NOT NULL
				or p_Active_Data_Type IS NOT NULL
				or p_Order_by IS NOT NULL
			then 'YES' else 'NO' end;
		CURSOR Display_Values_cur
		IS
			SELECT COLUMN_NAME, POSITION, R_POSITION, NULLABLE, C_COLUMN_EXPR, TABLE_ALIAS,
				R_VIEW_NAME, R_PRIMARY_KEY_COLS, R_TABLE_ALIAS, R_COLUMN_NAMES
			FROM (
				SELECT
					VIEW_NAME, COLUMN_NAME, 
					POSITION, 
					MAX(R_POSITION) R_POSITION,
					NULLABLE,
					data_browser_select.Get_ConversionColFunction (
						p_Column_Name => TABLE_ALIAS || COLUMN_NAME,
						p_Data_Type => DATA_TYPE,
						p_Data_Precision => case when p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then DATA_PRECISION else FORM_DATA_PRECISION end,
						p_Data_Scale => case when p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then DATA_SCALE else FORM_DATA_SCALE end,
						p_Char_Length => CHAR_LENGTH,
						p_Data_Format => case when R_VIEW_NAME IS NULL then 'FORM' else 'NATIVE' end,
						p_Use_Trim => 'Y',
						p_Datetime => IS_DATETIME
					) C_COLUMN_EXPR,
					TABLE_ALIAS,
					R_VIEW_NAME, R_PRIMARY_KEY_COLS,
					R_TABLE_ALIAS,
					LISTAGG( case when R_SUB_QUERY IS NOT NULL then 
									R_SUB_QUERY
								  when R_COLUMN_NAME is not null then 
									data_browser_conf.Get_Foreign_Key_Expression(p_Foreign_Key_Column=>R_COLUMN_NAME, p_Table_Alias=> R_TABLE_ALIAS)
								  end
							, Group_Delimiter)
						WITHIN GROUP (ORDER BY POSITION, R_POSITION
					) R_COLUMN_NAMES -- all description columns of one foreign key
				FROM (
					WITH PARAM AS (
					/*	SELECT VIEW_NAME Table_Name,
								DISPLAYED_COLUMN_NAMES Display_Col_Names,
								SEARCH_KEY_COLS Search_Key_Col,
								NULL	Exclude_Col_Name,
								'FORM_VIEW' View_Mode,
								'YES'	Alias_Required,
								'L1'	Alias_Prefix, 
								' - '	Group_Delimiter,
								1		Call_Level,
								4		P_INDENT
						FROM MVDATA_BROWSER_DESCRIPTIONS
						WHERE VIEW_NAME = 'SW_FILES'
					*/
						SELECT p_Table_Name Table_Name,
							p_Display_Col_Names Display_Col_Names,
							p_Search_Key_Col	Search_Key_Col,
							p_Exclude_Col_Name	Exclude_Col_Name,
							p_View_Mode			View_Mode,
							v_Alias_Required	Alias_Required,
							v_Alias_Prefix		Alias_Prefix, 
							v_Group_Delimiter	Group_Delimiter,
							p_Level				Call_Level
						FROM DUAL
					), DISPLAY_COLS_Q AS ( -- ordered display columns list
						SELECT --+ CARDINALITY(2)
							C.COLUMN_VALUE COLUMN_NAME,
							ROWNUM POSITION,
							PA.Alias_Prefix || data_browser_conf.Sequence_To_Table_Alias(ROWNUM-1) R_TABLE_ALIAS
						FROM PARAM PA,
							TABLE( apex_string.split(PA.Display_Col_Names, ', ') ) C
						WHERE (C.COLUMN_VALUE != PA.Search_Key_Col or PA.Display_Col_Names = PA.Search_Key_Col or PA.Search_Key_Col IS NULL ) -- don´t display return column value, unless it is the only column to display	 
						and (C.COLUMN_VALUE != PA.Exclude_Col_Name or PA.Display_Col_Names = PA.Exclude_Col_Name  or PA.Exclude_Col_Name IS NULL)
					)
					SELECT --+ USE_NL_WITH_INDEX(C) USE_NL_WITH_INDEX(F) USE_NL_WITH_INDEX(G)
						C.VIEW_NAME, T.COLUMN_NAME, T.POSITION, F.R_POSITION, C.NULLABLE,
						C.DATA_TYPE, C.DATA_PRECISION, C.DATA_SCALE, C.FORM_DATA_PRECISION, C.FORM_DATA_SCALE,	C.CHAR_LENGTH, C.IS_DATETIME,
						F.R_VIEW_NAME, F.R_PRIMARY_KEY_COLS, F.R_COLUMN_NAME,
						case when COUNT(F.R_VIEW_NAME) OVER (PARTITION BY C.VIEW_NAME) > 0
						or PA.Alias_Required = 'YES'
							then PA.Alias_Prefix || '.' -- use table alias in FROM clause, when foreign keys are contained in the display columns list
						end TABLE_ALIAS,
						T.R_TABLE_ALIAS, -- note: a diffenent method must be implemented to handle cases where IS_FILE_FOLDER_REF cant be resolved!!
						-- info columns
						S.FILE_FOLDER_COLUMN_NAME, R.FOLDER_NAME_COLUMN_NAME, R.FOLDER_PARENT_COLUMN_NAME, F.IS_FILE_FOLDER_REF,
						case 
						when F.IS_FILE_FOLDER_REF = 'Y' AND R.FOLDER_PARENT_COLUMN_NAME = F.R_COLUMN_NAME
						and S.FOLDER_NAME_COLUMN_NAME IS NOT NULL then -- Bugfix DS 20230227: dont call Key_Path_Query without FOLDER_NAME_COLUMN_NAME
							'(' || data_browser_select.Key_Path_Query (
								p_Table_Name		=> S.VIEW_NAME,
								p_Search_Key_Col	=> S.PRIMARY_KEY_COLS,
								p_Search_Value		=> null,
								p_Folder_Par_Col_Name  => R.FOLDER_PARENT_COLUMN_NAME,
								p_Folder_Name_Col_Name => S.FOLDER_NAME_COLUMN_NAME,
								p_Folder_Cont_Col_Name => R.FOLDER_CONTAINER_COLUMN_NAME,
								p_Folder_Cont_Alias => 'L' || PA.Call_Level,
								p_View_Mode			=> PA.View_Mode,
								p_Filter_Cond => data_browser_conf.Get_Join_Expression(
									p_Left_Columns=>F.R_PRIMARY_KEY_COLS, p_Left_Alias=> 'L' || (PA.Call_Level + 1),
									p_Right_Columns=>F.R_PRIMARY_KEY_COLS, p_Right_Alias=> 'L' || PA.Call_Level),
								p_Order_by			=> null,
								p_Level				=> PA.Call_Level + 1
							) || RPAD(' ', p_Indent + PA.Call_Level*4) || ')'
						when G.R_VIEW_NAME IS NOT NULL and PA.Call_Level <= 4 
						and F.IS_FILE_FOLDER_REF = 'N' then
							'(' || data_browser_select.Key_Values_Path_Query (
								p_Table_Name		=> G.R_VIEW_NAME,
								p_Display_Col_Names => G.DISPLAYED_COLUMN_NAMES,
								p_Extra_Col_Names	=> null,
								p_Search_Key_Col	=> G.R_PRIMARY_KEY_COLS,
								p_Search_Value		=> null,
								p_View_Mode			=> PA.View_Mode,
								p_Filter_Cond => data_browser_conf.Get_Join_Expression(
									p_Left_Columns=>G.R_PRIMARY_KEY_COLS, p_Left_Alias=> 'L' || (PA.Call_Level + 1),
									p_Right_Columns=>F.R_COLUMN_NAME, p_Right_Alias=> T.R_TABLE_ALIAS),
								p_Exclude_Col_Name	=> case when G.R_VIEW_NAME = PA.Table_Name then PA.Exclude_Col_Name end,
								p_Folder_Par_Col_Name => G.FOLDER_PARENT_COLUMN_NAME,
								p_Folder_Name_Col_Name => G.FOLDER_NAME_COLUMN_NAME,
								p_Folder_Cont_Col_Name => G.FOLDER_CONTAINER_COLUMN_NAME,
								p_Folder_Cont_Alias => 'L' || PA.Call_Level,
								-- p_Folder_Cont_Alias => case when G.VIEW_NAME = G.R_VIEW_NAME then T.R_TABLE_ALIAS else G.TABLE_ALIAS end,
								p_Active_Col_Name => G.ACTIVE_LOV_COLUMN_NAME,
								p_Active_Data_Type => G.ACTIVE_LOV_DATA_TYPE,
								p_Order_by			=> null,
								p_Level				=> PA.Call_Level + 1
							) || data_browser_conf.NL(p_Indent + PA.Call_Level*4) || ')'
							|| data_browser_conf.NL(p_Indent + PA.Call_Level*4)
						end R_SUB_QUERY,
						PA.Group_Delimiter
					FROM PARAM PA, DISPLAY_COLS_Q T
					JOIN MVDATA_BROWSER_SIMPLE_COLS C ON C.COLUMN_NAME = T.COLUMN_NAME
					JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = C.VIEW_NAME
					LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES R ON R.VIEW_NAME = C.VIEW_NAME AND R.COLUMN_NAME = T.COLUMN_NAME 
					LEFT OUTER JOIN MVDATA_BROWSER_F_REFS F ON F.VIEW_NAME = R.VIEW_NAME AND F.FOREIGN_KEY_COLS = R.COLUMN_NAME 
						AND (F.R_COLUMN_NAME != R.FILTER_KEY_COLUMN OR R.FILTER_KEY_COLUMN IS NULL)
						AND (F.IS_FILE_FOLDER_REF = 'N' OR R.FOLDER_PARENT_COLUMN_NAME = F.R_COLUMN_NAME)
					LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES G ON G.VIEW_NAME = F.R_VIEW_NAME AND G.COLUMN_NAME = F.R_COLUMN_NAME
					WHERE C.VIEW_NAME = PA.Table_Name
					AND (F.R_COLUMN_NAME IS NULL OR PA.Exclude_Col_Name IS NULL OR F.R_COLUMN_NAME != PA.Exclude_Col_Name )
					AND (T.COLUMN_NAME != S.FOLDER_NAME_COLUMN_NAME OR S.FOLDER_NAME_COLUMN_NAME IS NULL 
						OR R.FOLDER_PARENT_COLUMN_NAME IS NULL	-- Bugfix DS 20230220: dont filter FOLDER_NAME_COLUMN_NAME when there is no FOLDER_PARENT_COLUMN_NAME
					)
				)
				GROUP BY VIEW_NAME, TABLE_ALIAS, COLUMN_NAME, POSITION, NULLABLE, -- one line or each foreign key
					DATA_TYPE, DATA_PRECISION, DATA_SCALE, FORM_DATA_PRECISION, FORM_DATA_SCALE, CHAR_LENGTH, IS_DATETIME,
					R_VIEW_NAME, R_PRIMARY_KEY_COLS, R_TABLE_ALIAS, R_SUB_QUERY, Group_Delimiter
			) T
			ORDER BY VIEW_NAME, POSITION, R_POSITION;

		TYPE View_Cols_Tab IS TABLE OF Display_Values_cur%ROWTYPE;
		v_out_tab			View_Cols_Tab;
		v_Inner_Condition	VARCHAR2(32767);
		v_Extra_Col_Names	VARCHAR2(4000);
		v_Order_By			VARCHAR2(4000);
		v_Order_Array		apex_t_varchar2;
        v_result 			varchar2(32767);
	BEGIN
		OPEN Display_Values_cur;
		FETCH Display_Values_cur BULK COLLECT INTO v_out_tab;
		CLOSE Display_Values_cur;
		-- produce and return query for list of values (LOV_QUERY)
		if v_out_tab.COUNT > 0 then
			v_Table_Alias := RTRIM(v_out_tab(1).TABLE_ALIAS, '.');
			v_From_Clause := NL(p_Indent + (p_Level-1)*4) 
			|| 'FROM ' || data_browser_select.FN_Table_Prefix 
			|| data_browser_conf.Enquote_Name_Required(p_Table_Name) || ' ' || v_Table_Alias;
			v_Column_Expr := data_browser_conf.Get_Link_ID_Expression ( -- row reference in select list, produces CAST(A.ROWID AS VARCHAR2(128)) references in case of composite or missing unique keys
				p_Unique_Key_Column => p_Search_Key_Col,
				p_Table_Alias => v_Table_Alias,
				p_View_Mode => p_View_Mode
			);
			if SUBSTR(p_Order_by, 1, 1) = '1' then 
				v_Order_By := p_Order_by;
			elsif p_Order_by IS NOT NULL then
				-- add table alias to ordering columns
				v_Order_Array := apex_string.split(p_Order_by, ',');
				for c_idx IN 1..v_Order_Array.count loop
					v_Order_By := v_Order_By
					|| case when c_idx > 1 then ', ' end
					||	v_Table_Alias || '.' || TRIM(v_Order_Array(c_idx));
				end loop;
			end if;
			if p_Extra_Col_Names IS NOT NULL then
				SELECT ', ' || LISTAGG(NVL(v_Table_Alias, p_Table_name) || '.' || COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY POSITION) EXTRA_COLS
				INTO v_Extra_Col_Names
				FROM ( 
					SELECT --+ CARDINALITY(2)
						TRIM(C.COLUMN_VALUE) COLUMN_NAME,
						ROWNUM POSITION
					FROM TABLE( apex_string.split(p_Extra_Col_Names, ',') ) C
				);
			end if;

			FOR ind IN 1 .. v_out_tab.COUNT LOOP
				if v_out_tab(ind).R_VIEW_NAME IS NOT NULL then
					-- foreign key columns - new group
					v_Column_List := v_Column_List || v_out_tab(ind).R_COLUMN_NAMES;
					if (ind = 1 or v_out_tab(ind).R_TABLE_ALIAS != v_out_tab(ind - 1).R_TABLE_ALIAS) and v_out_tab(ind).R_TABLE_ALIAS IS NOT NULL then
						v_From_Clause := v_From_Clause
						|| NL(p_Indent + (p_Level-1)*4) 
						|| case when v_out_tab(ind).NULLABLE = 'Y' then 'LEFT OUTER ' end
						|| 'JOIN ' || data_browser_select.FN_Table_Prefix
						|| v_out_tab(ind).R_VIEW_NAME || ' ' || v_out_tab(ind).R_TABLE_ALIAS
						|| ' ON ' || v_out_tab(ind).R_TABLE_ALIAS || '.' || v_out_tab(ind).R_PRIMARY_KEY_COLS || ' = ' || v_out_tab(ind).C_COLUMN_EXPR;
					end if;
				else
					v_Column_List := v_Column_List || v_out_tab(ind).C_COLUMN_EXPR;
				end if;
				if ind < v_out_tab.COUNT then
					v_Column_List := v_Column_List
					|| case when v_out_tab(ind).TABLE_ALIAS = v_out_tab(ind+1).TABLE_ALIAS then v_Delimiter else v_Group_Delimiter end;
				end if;
			END LOOP;
			if v_out_tab.COUNT > 1 then
				v_Column_List := 'SUBSTR(' || v_Column_List || ', 1, 1024)';
			end if;
			if p_Search_Value IS NOT NULL then
				v_Inner_Condition := data_browser_conf.Build_Condition(
					p_Condition => v_Inner_Condition,
					p_Term =>  v_Column_Expr || ' = ' || p_Search_Value,
					p_Add_NL => 'NO'
				);						
			else
				if	p_Filter_Cond IS NOT NULL then
					v_Inner_Condition := data_browser_conf.Build_Condition(
						p_Condition => v_Inner_Condition,
						p_Term => p_Filter_Cond,
						p_Add_NL => 'NO'
					);
				end if;
				if p_Active_Col_Name IS NOT NULL and p_Active_Data_Type IS NOT NULL then
					v_Inner_Condition := data_browser_conf.Build_Condition(
						p_Condition => v_Inner_Condition,
						p_Term => v_Table_Alias || '.' || p_Active_Col_Name
							|| ' = ' || data_browser_conf.Get_Boolean_Yes_Value(p_Active_Data_Type, 'ENQUOTE'),
						p_Add_NL => 'NO'
					);
				end if;
			end if;
			if v_Inner_Condition IS NOT NULL then 
				v_Inner_Condition := NL(p_Indent + (p_Level-1)*4) || v_Inner_Condition;
			end if;
			if p_Search_Value IS NOT NULL -- single row subquery
			or (v_Order_By IS NULL and v_Extra_Col_Names IS NULL) then
				v_result := 'SELECT ' || NVL(v_Column_List, v_Column_Expr) || ' D ' 
					|| v_From_Clause
					|| v_Inner_Condition;
			else
				v_result := 'SELECT ' || NVL(v_Column_List, v_Column_Expr) || ' D, ' || NL(p_Indent + 4)
					||	v_Column_Expr || ' R ' || v_Extra_Col_Names
					|| v_From_Clause
					|| v_Inner_Condition
					|| case when v_Order_By IS NOT NULL then 
						NL(p_Indent)
						|| 'ORDER BY ' || v_Order_By
					end;
			end if;
		else
			if p_Search_Value IS NOT NULL then
				v_result := p_Search_Value;
			else
				v_result := 'select null d, null r from dual';
			end if;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call(p_overload => 1)
            USING p_table_name,p_display_col_names,p_extra_col_names,p_search_key_col,p_search_value,p_view_mode,p_filter_cond,p_exclude_col_name,p_active_col_name,p_active_data_type,p_order_by,p_level,p_indent,v_result;
        $END
        return v_result;
	END Key_Values_Query;

	FUNCTION Key_Values_Path_Query (
		p_Table_Name	VARCHAR2,
		p_Display_Col_Names VARCHAR2,	-- display columns,
		p_Extra_Col_Names VARCHAR2 DEFAULT NULL, -- extra columns,
		p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
		p_Search_Value	VARCHAR2, -- used to produce only a single output row for known value or reference
		p_View_Mode VARCHAR2,
		p_Filter_Cond VARCHAR2 DEFAULT NULL,
		p_Exclude_Col_Name VARCHAR2,
		p_Folder_Par_Col_Name VARCHAR2,
		p_Folder_Name_Col_Name VARCHAR2,
		p_Folder_Cont_Col_Name VARCHAR2,
		p_Folder_Cont_Alias VARCHAR2 DEFAULT NULL,
		p_Active_Col_Name VARCHAR2,
		p_Active_Data_Type VARCHAR2,		-- NUMBER, CHAR
		p_Order_by VARCHAR2, 
		p_Level INTEGER DEFAULT 1,
		p_Indent INTEGER DEFAULT 4
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Result VARCHAR2(32767);
	begin
		v_Result :=
		case when p_Folder_Name_Col_Name IS NOT NULL
			and p_Folder_Par_Col_Name IS NOT NULL
			and p_Folder_Cont_Alias IS NOT NULL
		then 
			data_browser_select.Key_Path_Query (
				p_Table_Name		=> p_Table_Name,
				p_Search_Key_Col	=> p_Search_Key_Col,
				p_Search_Value		=> p_Search_Value,
				p_Folder_Par_Col_Name  => p_Folder_Par_Col_Name,
				p_Folder_Name_Col_Name => p_Folder_Name_Col_Name,
				p_Folder_Cont_Col_Name => p_Folder_Cont_Col_Name,
				p_Folder_Cont_Alias => p_Folder_Cont_Alias,
				p_View_Mode			=> p_View_Mode,
				p_Filter_Cond		=> p_Filter_Cond,
				p_Order_by			=> p_Order_by,
				p_Level				=> p_Level
			)
		else
			data_browser_select.Key_Values_Query (
				p_Table_Name		=> p_Table_Name,
				p_Display_Col_Names => p_Display_Col_Names,
				p_Extra_Col_Names	=> p_Extra_Col_Names,
				p_Search_Key_Col	=> p_Search_Key_Col,
				p_Search_Value		=> p_Search_Value,
				p_View_Mode			=> p_View_Mode,
				p_Filter_Cond		=> p_Filter_Cond,
				p_Exclude_Col_Name	=> p_Exclude_Col_Name,
				p_Active_Col_Name	=> p_Active_Col_Name,
				p_Active_Data_Type	=> p_Active_Data_Type,
				p_Order_by			=> p_Order_by,
				p_Level				=> p_Level,
				p_Indent			=> p_Indent
			)
		end;
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_display_col_names,p_extra_col_names,p_search_key_col,p_search_value,p_view_mode,p_filter_cond,p_exclude_col_name,p_folder_par_col_name,p_folder_name_col_name,p_folder_cont_col_name,p_folder_cont_alias,p_active_col_name,p_active_data_type,p_order_by,p_level,p_indent,v_result;
        $END
		return v_Result;
    exception 
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_table_name,p_display_col_names,p_extra_col_names,p_search_key_col,p_search_value,p_view_mode,p_filter_cond,p_exclude_col_name,p_folder_par_col_name,p_folder_name_col_name,p_folder_cont_col_name,p_folder_cont_alias,p_active_col_name,p_active_data_type,p_order_by,p_level,p_indent;
        RAISE;
	end Key_Values_Path_Query;

	FUNCTION Key_Values_Query (
		p_Table_Name	VARCHAR2
	) RETURN VARCHAR2
	is
		v_query			VARCHAR2(32767);
	begin
		SELECT
			data_browser_select.Key_Values_Path_Query(
				p_Table_Name => VIEW_NAME,
				p_Display_Col_Names => DISPLAYED_COLUMN_NAMES,
				p_Extra_Col_Names	=> null,
				p_Search_Key_Col => SEARCH_KEY_COLS,
				p_Search_Value => NULL,
				p_View_Mode => 'FORM_VIEW',
				p_Exclude_Col_Name => NULL,
				p_Active_Col_Name => ACTIVE_LOV_COLUMN_NAME,
				p_Active_Data_Type => ACTIVE_LOV_DATA_TYPE,
				p_Folder_Par_Col_Name	=> FOLDER_PARENT_COLUMN_NAME,
				p_Folder_Name_Col_Name => FOLDER_NAME_COLUMN_NAME,
				p_Folder_Cont_Col_Name => FOLDER_CONTAINER_COLUMN_NAME,
				p_Order_by => NVL(ORDERING_COLUMN_NAME, '1'),
				p_Indent => 1
			) LOV_QUERY
		INTO v_query
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME = p_Table_Name;
		return v_query;
	exception when NO_DATA_FOUND then
$IF data_browser_conf.g_runtime_exceptions $THEN
		RAISE_APPLICATION_ERROR(-20101, 'Bad Parameter for Key_Values_Query detected. Table: ' 
		|| dbms_assert.enquote_name(p_Table_Name));
$END
		return 'select null d, null r from dual';
	end Key_Values_Query;

	FUNCTION INDENT(p_Query VARCHAR2, p_Indent INTEGER) RETURN VARCHAR2
	IS
	BEGIN
		RETURN REPLACE( p_Query, chr(10), data_browser_conf.NL(p_Indent)) || chr(10);
	END;

	FUNCTION Key_Path_Query (
		p_Table_Name	VARCHAR2,
		p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
		p_Search_Value	VARCHAR2 DEFAULT NULL, -- used to produce only a single output row for known value or reference
		p_Folder_Par_Col_Name VARCHAR2,
		p_Folder_Name_Col_Name VARCHAR2,
		p_Folder_Cont_Col_Name VARCHAR2,
		p_Folder_Cont_Alias VARCHAR2 DEFAULT NULL,
		p_View_Mode VARCHAR2,
		p_Filter_Cond VARCHAR2,
		p_Order_by VARCHAR2,
		p_Level INTEGER DEFAULT 1
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Inner_Condition	VARCHAR2(32767);
		v_Query				VARCHAR2(32767);
	begin
		if p_Search_Value IS NOT NULL then
			v_Inner_Condition := data_browser_conf.Build_Condition(
				p_Condition => v_Inner_Condition,
				p_Term =>  p_Search_Key_Col || ' = ' || p_Search_Value,
				p_Add_NL => 'NO'
			);						
		else
			if	p_Filter_Cond IS NOT NULL then
				v_Inner_Condition := data_browser_conf.Build_Condition(
					p_Condition => v_Inner_Condition,
					p_Term => p_Filter_Cond,
					p_Add_NL => 'NO'
				);
			end if;
		end if;

		v_Query := 'SELECT PATH' 
		|| case when p_Search_Value IS NULL and p_Order_by IS NOT NULL then 
			', ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) 
		end
		|| NL(6)
		|| 'FROM (' || NL(8)
		||	'SELECT ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) || ', SYS_CONNECT_BY_PATH(TRANSLATE(' 
		||	data_browser_conf.Enquote_Name_Required(p_Folder_Name_Col_Name) || q'[, '/', '-'), '/') PATH]' || NL(8)
		||	'FROM (SELECT ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) || ', '
		|| case when p_Folder_Cont_Col_Name IS NOT NULL and p_Folder_Cont_Alias IS NULL then 
			data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name) || ', '
		end
		|| data_browser_conf.Enquote_Name_Required(p_Folder_Par_Col_Name) || ', '
		|| data_browser_conf.Enquote_Name_Required(p_Folder_Name_Col_Name) || NL(12)
		||	'FROM ' || data_browser_select.FN_Table_Prefix || data_browser_conf.Enquote_Name_Required(p_Table_Name) 
		|| ' L' || (p_Level+1)
		|| case when p_Folder_Cont_Col_Name IS NOT NULL and p_Folder_Cont_Alias IS NOT NULL then 
			NL(12)
			|| 'WHERE ' || ' L' || (p_Level+1)
			|| '.' || data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
			|| ' = ' || p_Folder_Cont_Alias
			|| '.' || data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
		end
		||	NL(8)
		|| ') START WITH ' || data_browser_conf.Enquote_Name_Required(p_Folder_Par_Col_Name) || ' IS NULL' || NL(8)
		||	'CONNECT BY ' || data_browser_conf.Enquote_Name_Required(p_Folder_Par_Col_Name) 
		|| ' = PRIOR ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) || NL(6)
		|| case when p_Folder_Cont_Col_Name IS NOT NULL and p_Folder_Cont_Alias IS NULL then 
			'  AND ' || data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
			|| ' = PRIOR ' 
			|| data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
			|| NL(6)
		end
		|| case when p_Search_Value IS NULL and p_Order_by IS NOT NULL then 
			'  ORDER SIBLINGS BY ' || data_browser_conf.Enquote_Name_Required(p_Folder_Name_Col_Name) || NL(6)
		end
		|| ') L' || p_Level || ' ' 
		|| case when v_Inner_Condition IS NOT NULL then
			NL(5) || v_Inner_Condition
		end;
		if p_Level > 1 then 
			v_Query := INDENT(v_Query, (p_Level-1)*4);
		end if;
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_search_key_col,p_search_value,p_folder_par_col_name,p_folder_name_col_name,p_folder_cont_col_name,p_folder_cont_alias,p_view_mode,p_filter_cond,p_order_by,p_level,v_Query;
        $END
        return v_Query;
	end Key_Path_Query;

	FUNCTION Key_Path_Lookup_Query (
		p_Table_Name	VARCHAR2,
		p_Search_Key_Col VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
		p_Search_Path  VARCHAR2 DEFAULT NULL, -- used to lookup only a single output row for known path
		p_Search_Value	VARCHAR2 DEFAULT NULL, -- output variable for found identity value.
		p_Folder_Par_Col_Name VARCHAR2,
		p_Folder_Name_Col_Name VARCHAR2,
		p_Folder_Cont_Col_Name VARCHAR2 DEFAULT NULL,
		p_Folder_Cont_Alias VARCHAR2 DEFAULT NULL,
		p_Level INTEGER DEFAULT 1
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Query				VARCHAR2(32767);
	begin
		v_Query := 'SELECT ' || p_Search_Key_Col || ' INTO '
		|| p_Search_Value 
		|| NL(8+p_Level*4)
		|| 'FROM (' || NL(12+p_Level*4)
		||	'SELECT ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) || ', SYS_CONNECT_BY_PATH(TRANSLATE(' 
		||	data_browser_conf.Enquote_Name_Required(p_Folder_Name_Col_Name) || q'[, '/', '-'), '/') PATH]' || NL(12+p_Level*4)
		||	'FROM (SELECT ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) || ', ' 
		|| case when p_Folder_Cont_Col_Name IS NOT NULL and p_Folder_Cont_Alias IS NULL then 
			data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name) || ', '
		end
		||	data_browser_conf.Enquote_Name_Required(p_Folder_Par_Col_Name) || ', '
		||	data_browser_conf.Enquote_Name_Required(p_Folder_Name_Col_Name) || NL(16+p_Level*4)
		||	'FROM ' || data_browser_select.FN_Table_Prefix || data_browser_conf.Enquote_Name_Required(p_Table_Name)
		|| ' L' || (p_Level+1)
		|| case when p_Folder_Cont_Col_Name IS NOT NULL and p_Folder_Cont_Alias IS NOT NULL then 
			NL(16+p_Level*4)
			|| 'WHERE ' || ' L' || (p_Level+1)
			|| '.' || data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
			|| ' = ' || p_Folder_Cont_Alias
		end
		|| NL(12+p_Level*4)
		||	') START WITH ' || data_browser_conf.Enquote_Name_Required(p_Folder_Par_Col_Name) || ' IS NULL' || NL(12+p_Level*4)
		||	'CONNECT BY ' || data_browser_conf.Enquote_Name_Required(p_Folder_Par_Col_Name) 
		|| ' = PRIOR ' || data_browser_conf.Enquote_Name_Required(p_Search_Key_Col) || NL(8+p_Level*4)
		|| case when p_Folder_Cont_Col_Name IS NOT NULL and p_Folder_Cont_Alias IS NULL then 
			'  AND ' || data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
			|| ' = PRIOR ' 
			|| data_browser_conf.Enquote_Name_Required(p_Folder_Cont_Col_Name)
			|| NL(8+p_Level*4)
		end
		|| ') WHERE PATH = ' || p_Search_Path;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_search_key_col,p_search_path,p_search_value,p_folder_par_col_name,p_folder_name_col_name,p_folder_cont_col_name,p_folder_cont_alias,p_level,v_Query;
        $END
		return v_Query;
	end Key_Path_Lookup_Query;


	FUNCTION Get_Parent_LOV_Query (
		p_Table_Name	IN VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
		p_Filter_Used_Values VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2
	is
		v_filter					VARCHAR2(32767);
		v_query						VARCHAR2(32767);
		v_Foreign_Key_Columns		MVDATA_BROWSER_DESCRIPTIONS.SEARCH_KEY_COLS%TYPE;
		v_Displayed_Column_Names	MVDATA_BROWSER_DESCRIPTIONS.DISPLAYED_COLUMN_NAMES%TYPE;
		v_Active_Lov_Column_Name	MVDATA_BROWSER_DESCRIPTIONS.ACTIVE_LOV_COLUMN_NAME%TYPE;
		v_Active_Lov_Data_Type		MVDATA_BROWSER_DESCRIPTIONS.ACTIVE_LOV_DATA_TYPE%TYPE;
		v_Ordering_Column_Name		MVDATA_BROWSER_DESCRIPTIONS.ORDERING_COLUMN_NAME%TYPE;
		v_Folder_Parent_Column_Name MVDATA_BROWSER_DESCRIPTIONS.FOLDER_PARENT_COLUMN_NAME%TYPE;
		v_Folder_Name_Column_Name	MVDATA_BROWSER_DESCRIPTIONS.FOLDER_NAME_COLUMN_NAME%TYPE;
		v_Folder_Cont_Col_Name		MVDATA_BROWSER_DESCRIPTIONS.FOLDER_CONTAINER_COLUMN_NAME%TYPE;
		v_Table_Alias				MVDATA_BROWSER_REFERENCES.TABLE_ALIAS%TYPE;
		v_Parent_Key_Column			MVDATA_BROWSER_REFERENCES.PARENT_KEY_COLUMN%TYPE;
		v_Filter_Key_Column			MVDATA_BROWSER_REFERENCES.FILTER_KEY_COLUMN%TYPE;
	begin
		if p_Table_Name IS NOT NULL and p_Parent_Table IS NOT NULL and p_Parent_Key_Column IS NOT NULL then 
			SELECT E.R_PRIMARY_KEY_COLS, E.DISPLAYED_COLUMN_NAMES, E.ACTIVE_LOV_COLUMN_NAME, E.ACTIVE_LOV_DATA_TYPE, E.ORDERING_COLUMN_NAME,
				S.FOLDER_PARENT_COLUMN_NAME, S.FOLDER_NAME_COLUMN_NAME, S.FOLDER_CONTAINER_COLUMN_NAME, E.TABLE_ALIAS,
				E.PARENT_KEY_COLUMN, E.FILTER_KEY_COLUMN
			INTO v_Foreign_Key_Columns, v_Displayed_Column_Names, v_Active_Lov_Column_Name, v_Active_Lov_Data_Type, v_Ordering_Column_Name,
				v_Folder_Parent_Column_Name, v_Folder_Name_Column_Name, v_Folder_Cont_Col_Name, v_Table_Alias,
				v_Parent_Key_Column, v_Filter_Key_Column
			FROM MVDATA_BROWSER_DESCRIPTIONS S
			JOIN MVDATA_BROWSER_REFERENCES E ON S.VIEW_NAME = E.R_VIEW_NAME 
			WHERE E.VIEW_NAME = p_Table_Name
			AND	  E.R_VIEW_NAME = p_Parent_Table
			AND	  E.COLUMN_NAME = p_Parent_Key_Column;

			if p_Filter_Used_Values = 'YES' then
				v_filter := '(EXISTS (SELECT 1 FROM '
				|| p_Table_Name
				|| ' S WHERE S.' || p_Parent_Key_Column
				|| ' = L1.' || v_Foreign_Key_Columns
				|| ')'
				|| case when p_Parent_Key_Item IS NOT NULL then
					' or L1.' || v_Foreign_Key_Columns || ' = V(' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Item) || ')'
				end
				|| ')';
			end if;
			v_query := data_browser_select.Key_Values_Path_Query(
				p_Table_Name => p_Parent_Table,
				p_Display_Col_Names => v_Displayed_Column_Names,
				p_Search_Key_Col => v_Foreign_Key_Columns,
				p_Search_Value => NULL,
				p_Exclude_Col_Name => case when v_Parent_Key_Column = p_Parent_Key_Column then v_Filter_Key_Column end,
				p_Active_Col_Name	=> v_Active_Lov_Column_Name,
				p_Active_Data_Type	=> v_Active_Lov_Data_Type,
				p_Folder_Par_Col_Name	=> v_Folder_Parent_Column_Name,
				p_Folder_Name_Col_Name => v_Folder_Name_Column_Name,
				p_Folder_Cont_Col_Name => v_Folder_Cont_Col_Name,
				p_Folder_Cont_Alias => null,
				p_View_Mode => 'FORM_VIEW',
				p_Filter_Cond => v_filter,
				p_Order_by => NVL(v_Ordering_Column_Name, '1')
			);
			return v_query;
		else 
			return 'select null d, null r from dual';
		end if;
	exception when NO_DATA_FOUND then
$IF data_browser_conf.g_runtime_exceptions $THEN
		RAISE_APPLICATION_ERROR(-20101, 'Bad Parameter for Get_Parent_LOV_Query detected. Column: ' 
		|| dbms_assert.enquote_name(p_Table_Name) || '.' || dbms_assert.enquote_name(p_Parent_Key_Column));
$END
		return 'select null d, null r from dual';
	end Get_Parent_LOV_Query;

	FUNCTION Get_LOV_Query (
		p_Table_Name	IN VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
		p_Filter_Cond VARCHAR2 DEFAULT NULL,
		p_Order_by VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
		v_filter					VARCHAR2(32767);
		v_query						VARCHAR2(32767);
	begin
		if p_Table_Name IS NOT NULL then 
			if p_Parent_Key_Column IS NOT NULL 
			and p_Parent_Key_Item IS NOT NULL
			and V(p_Parent_Key_Item) IS NOT NULL then
				v_filter := 'L1.' || p_Parent_Key_Column
				|| ' = NVL(V(' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Item) || '), L1.' || p_Parent_Key_Column || ')';
			end if;
			v_filter := data_browser_conf.Concat_List(p_First_Name=> p_Filter_Cond, p_Second_Name => v_filter, p_Delimiter=> ' AND ');
			SELECT
				data_browser_select.Key_Values_Path_Query(
					p_Table_Name => VIEW_NAME,
					p_Display_Col_Names => DISPLAYED_COLUMN_NAMES,
					p_Search_Key_Col => SEARCH_KEY_COLS,
					p_Search_Value => NULL,
					p_Exclude_Col_Name => case when V(p_Parent_Key_Item) IS NOT NULL then p_Parent_Key_Column end, -- only exclude when the value is known
					p_Active_Col_Name	=> ACTIVE_LOV_COLUMN_NAME,
					p_Active_Data_Type	=> ACTIVE_LOV_DATA_TYPE,
					p_Folder_Par_Col_Name	=> FOLDER_PARENT_COLUMN_NAME,
					p_Folder_Name_Col_Name => FOLDER_NAME_COLUMN_NAME,
					p_Folder_Cont_Col_Name => FOLDER_CONTAINER_COLUMN_NAME,
					p_View_Mode => 'FORM_VIEW',
					p_Filter_Cond => v_filter,
					p_Order_by => COALESCE(p_Order_by, ORDERING_COLUMN_NAME, '1')
				) LOV_QUERY
			INTO v_query
			FROM MVDATA_BROWSER_DESCRIPTIONS
			WHERE VIEW_NAME = p_Table_Name;
		else
			v_query := 'select null d, null r from dual';
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_parent_table,p_parent_key_column,p_parent_key_item,p_filter_cond,p_order_by,v_query;
        $END
        return v_query;
	exception when NO_DATA_FOUND then
$IF data_browser_conf.g_runtime_exceptions $THEN
		RAISE_APPLICATION_ERROR(-20101, 'Bad Parameter for Get_LOV_Query detected. Column: ' 
		|| dbms_assert.enquote_name(p_Table_Name) || '.' || dbms_assert.enquote_name(p_Parent_Key_Column));
$END
		return 'select null d, null r from dual';
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_table_name,p_parent_table,p_parent_key_column,p_parent_key_item,p_filter_cond,p_order_by;
        RAISE;
	end Get_LOV_Query;

	FUNCTION LOV_CURSOR (
		p_Table_Name	IN VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- Page Item Name, Filter Value and default value for foreign key column
		p_Filter_Cond VARCHAR2 DEFAULT NULL,
		p_Order_by VARCHAR2 DEFAULT NULL
	) 
	RETURN data_browser_conf.tab_col_value PIPELINED 
	is -- NULL COLUMN_NAME, COLUMN_HEADER, COLUMN_DATA
		stat_cur	SYS_REFCURSOR;
		v_Query		VARCHAR2(32767);
		v_out_rec	data_browser_conf.rec_col_value := data_browser_conf.rec_col_value();
	BEGIN 
		v_Query := Get_LOV_Query (
			p_Table_Name => p_Table_Name,
			p_Parent_Table => p_Parent_Table,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Filter_Cond => p_Filter_Cond,
			p_Order_by => p_Order_by
		);
		OPEN stat_cur FOR v_Query;
		LOOP 
			FETCH stat_cur INTO v_out_rec.COLUMN_HEADER, v_out_rec.COLUMN_DATA;
			EXIT WHEN stat_cur%NOTFOUND;
			pipe row (v_out_rec);
		END LOOP;
		CLOSE stat_cur;
	end LOV_CURSOR;

	FUNCTION Get_Calendar_Query (
		p_Table_Name	IN VARCHAR2,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL			-- Page Item Name, Filter Value and default value for foreign key column
	) RETURN VARCHAR2
	is
		v_filter					VARCHAR2(32767);
		v_Query						VARCHAR2(32767);
		v_Default_Query				VARCHAR2(32767) := 'select 1 ID, sysdate START_DATE, sysdate END_DATE, null CSS_CLASS, null DESCRIPTION, null REMARKS from dual';
		v_Unique_Key_Column			MVDATA_BROWSER_DESCRIPTIONS.SEARCH_KEY_COLS%TYPE;
		v_Displayed_Column_Names	MVDATA_BROWSER_DESCRIPTIONS.DISPLAYED_COLUMN_NAMES%TYPE;
		v_Active_Lov_Column_Name	MVDATA_BROWSER_DESCRIPTIONS.ACTIVE_LOV_COLUMN_NAME%TYPE;
		v_Active_Lov_Data_Type		MVDATA_BROWSER_DESCRIPTIONS.ACTIVE_LOV_DATA_TYPE%TYPE;
		v_Folder_Parent_Column_Name MVDATA_BROWSER_DESCRIPTIONS.FOLDER_PARENT_COLUMN_NAME%TYPE;
		v_Folder_Name_Column_Name	MVDATA_BROWSER_DESCRIPTIONS.FOLDER_NAME_COLUMN_NAME%TYPE;
		v_Folder_Cont_Col_Name		MVDATA_BROWSER_DESCRIPTIONS.FOLDER_CONTAINER_COLUMN_NAME%TYPE;
		v_Calendar_Start_Date_Column MVDATA_BROWSER_DESCRIPTIONS.CALEND_START_DATE_COLUMN_NAME%TYPE;
		v_Calendar_End_Date_Column MVDATA_BROWSER_DESCRIPTIONS.CALENDAR_END_DATE_COLUMN_NAME%TYPE;
	begin
		SELECT SEARCH_KEY_COLS, DISPLAYED_COLUMN_NAMES, ACTIVE_LOV_COLUMN_NAME, ACTIVE_LOV_DATA_TYPE, 
			FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME,
			CALEND_START_DATE_COLUMN_NAME, CALENDAR_END_DATE_COLUMN_NAME
		INTO v_Unique_Key_Column, v_Displayed_Column_Names, v_Active_Lov_Column_Name, v_Active_Lov_Data_Type, 
			v_Folder_Parent_Column_Name, v_Folder_Name_Column_Name, v_Folder_Cont_Col_Name,
			v_Calendar_Start_Date_Column, v_Calendar_End_Date_Column
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME = p_Table_Name;
		if p_Parent_Key_Column IS NOT NULL and p_Parent_Key_Item IS NOT NULL
		and V(p_Parent_Key_Item) IS NOT NULL then
			v_filter := 'L1.' || p_Parent_Key_Column
			|| ' = NVL(V(' || dbms_assert.enquote_literal(p_Parent_Key_Item) || '), L1.' || p_Parent_Key_Column || ')';
		end if;
		if v_Calendar_Start_Date_Column IS NOT NULL then
			v_Query := data_browser_select.Key_Values_Path_Query(
				p_Table_Name => p_Table_Name,
				p_Display_Col_Names => v_Displayed_Column_Names,
				p_Extra_Col_Names => data_browser_conf.Concat_List(v_Calendar_Start_Date_Column, v_Calendar_End_Date_Column),
				p_Search_Key_Col => v_Unique_Key_Column,
				p_Search_Value => NULL,
				p_View_Mode => 'FORM_VIEW',
				p_Filter_Cond => v_filter,
				p_Exclude_Col_Name => case when V(p_Parent_Key_Item) IS NOT NULL then p_Parent_Key_Column end, -- only exclude when the value is known
				p_Folder_Par_Col_Name	=> v_Folder_Parent_Column_Name,
				p_Folder_Name_Col_Name => v_Folder_Name_Column_Name,
				p_Folder_Cont_Col_Name => v_Folder_Cont_Col_Name,
				p_Active_Col_Name	=> v_Active_Lov_Column_Name,
				p_Active_Data_Type	=> v_Active_Lov_Data_Type,
				p_Order_by => null
			);
			v_Query := 'select R ID, ' 
			|| case when v_Calendar_Start_Date_Column is not null then dbms_assert.enquote_name(v_Calendar_Start_Date_Column) else 'NULL' end || ' START_DATE, '
			||	case when v_Calendar_End_Date_Column is not null then dbms_assert.enquote_name(v_Calendar_End_Date_Column) else 'NULL' end || ' END_DATE, '
			|| 'case ORA_HASH(D, 13)+1 '
			|| q'[
			when 1 then 'apex-cal-red'
			when 2 then 'apex-cal-cyan'
			when 3 then 'apex-cal-blue'
			when 4 then 'apex-cal-bluesky'
			when 5 then 'apex-cal-darkblue'
			when 6 then 'apex-cal-green'
			when 7 then 'apex-cal-yellow'
			when 8 then 'apex-cal-silver'
			when 9 then 'apex-cal-brown'
			when 10 then 'apex-cal-lime'
			when 11 then 'apex-cal-white'
			when 12 then 'apex-cal-gray'
			when 13 then 'apex-cal-black'
			when 14 then 'apex-cal-orange'
			end ]'
			|| 'CSS_CLASS, D DESCRIPTION, null REMARKS' || chr(10)
			|| 'from (' || v_Query || ')';
			return v_Query;
		else 
			return v_Default_Query;		
		end if;
	exception when NO_DATA_FOUND then
		return v_Default_Query;
	end Get_Calendar_Query;

	FUNCTION Get_Tree_Query (
		p_Table_Name	IN VARCHAR2,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL			-- Page Item Name, Filter Value and default value for foreign key column
	) RETURN VARCHAR2
	is
		v_filter					VARCHAR2(32767);
		v_Query						VARCHAR2(32767);
		v_Default_Query				VARCHAR2(32767) := 'select 1 FOLDER_ID, null FOLDER_PARENT_ID, null FOLDER_NAME from dual';
		v_Unique_Key_Column			MVDATA_BROWSER_DESCRIPTIONS.SEARCH_KEY_COLS%TYPE;
		v_Folder_Parent_Column_Name MVDATA_BROWSER_DESCRIPTIONS.FOLDER_PARENT_COLUMN_NAME%TYPE;
		v_Folder_Name_Column_Name	MVDATA_BROWSER_DESCRIPTIONS.FOLDER_NAME_COLUMN_NAME%TYPE;
	begin
		SELECT SEARCH_KEY_COLS, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME
		INTO v_Unique_Key_Column, v_Folder_Parent_Column_Name, v_Folder_Name_Column_Name
		FROM MVDATA_BROWSER_DESCRIPTIONS
		WHERE VIEW_NAME = p_Table_Name;
		if p_Parent_Key_Column IS NOT NULL and p_Parent_Key_Item IS NOT NULL
		and V(p_Parent_Key_Item) IS NOT NULL then
			v_filter := 'T.' || p_Parent_Key_Column
			|| ' = NVL(V(' || dbms_assert.enquote_literal(p_Parent_Key_Item) || '), T.' || p_Parent_Key_Column || ')';
		end if;
		if v_Unique_Key_Column IS NOT NULL AND v_Folder_Parent_Column_Name IS NOT NULL AND v_Folder_Name_Column_Name IS NOT NULL then 
			v_Query := 'select '|| dbms_assert.enquote_name(v_Unique_Key_Column) || ' FOLDER_ID, '
			|| dbms_assert.enquote_name(v_Folder_Parent_Column_Name)|| ' FOLDER_PARENT_ID, '
			|| dbms_assert.enquote_name(v_Folder_Name_Column_Name) || ' FOLDER_NAME' || chr(10)
			|| 'from ' 
			|| data_browser_select.FN_Table_Prefix
			|| data_browser_conf.Enquote_Name_Required(p_Table_Name) || ' T'
			|| case when v_filter IS NOT NULL then 
				chr(10) || 'where ' || v_filter
			end;
		else 
			v_Query := v_Default_Query;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_parent_key_column,p_parent_key_item,v_Query;
        $END
		return v_Query;
	exception when NO_DATA_FOUND then
		return v_Default_Query;
	end Get_Tree_Query;

	FUNCTION Get_Ref_LOV_Query (
		p_Table_Name	IN VARCHAR2,
		p_FK_Column_ID	IN NUMBER,						-- Foreign key column of table name 
		p_Column_Name	IN VARCHAR2,					-- Foreign key column of table name 
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL			-- Page Item Name, Filter Value and default value for foreign key column
	) RETURN VARCHAR2
	is
		v_filter					VARCHAR2(32767);
		v_R_View_Name				MVDATA_BROWSER_REFERENCES.R_VIEW_NAME%TYPE;
		v_Unique_Key_Column			MVDATA_BROWSER_REFERENCES.R_PRIMARY_KEY_COLS%TYPE;
		v_Displayed_Column_Names	MVDATA_BROWSER_REFERENCES.DISPLAYED_COLUMN_NAMES%TYPE;
		v_Active_Lov_Column_Name	MVDATA_BROWSER_REFERENCES.ACTIVE_LOV_COLUMN_NAME%TYPE;
		v_Active_Lov_Data_Type		MVDATA_BROWSER_REFERENCES.ACTIVE_LOV_DATA_TYPE%TYPE;
		v_Ordering_Column_Name		MVDATA_BROWSER_REFERENCES.ORDERING_COLUMN_NAME%TYPE;
		v_Parent_Key_Column			MVDATA_BROWSER_REFERENCES.PARENT_KEY_COLUMN%TYPE;
		v_Filter_Key_Column			MVDATA_BROWSER_REFERENCES.FILTER_KEY_COLUMN%TYPE;
		v_Folder_Par_Col_Name		MVDATA_BROWSER_REFERENCES.FOLDER_PARENT_COLUMN_NAME%TYPE;
		v_Folder_Name_Col_Name		MVDATA_BROWSER_REFERENCES.FOLDER_NAME_COLUMN_NAME%TYPE;
		v_Folder_Cont_Col_Name		MVDATA_BROWSER_REFERENCES.FOLDER_CONTAINER_COLUMN_NAME%TYPE;
        v_result varchar2(32767);
	begin
		if p_Table_Name IS NOT NULL then 
			SELECT R_VIEW_NAME, R_PRIMARY_KEY_COLS, DISPLAYED_COLUMN_NAMES, ACTIVE_LOV_COLUMN_NAME, ACTIVE_LOV_DATA_TYPE, 
					ORDERING_COLUMN_NAME, PARENT_KEY_COLUMN, FILTER_KEY_COLUMN, 
					FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME
			INTO v_R_View_Name, v_Unique_Key_Column, v_Displayed_Column_Names, v_Active_Lov_Column_Name, v_Active_Lov_Data_Type, 
					v_Ordering_Column_Name, v_Parent_Key_Column, v_Filter_Key_Column, 
					v_Folder_Par_Col_Name, v_Folder_Name_Col_Name, v_Folder_Cont_Col_Name
			FROM MVDATA_BROWSER_REFERENCES
			WHERE VIEW_NAME = p_Table_Name
			AND COLUMN_NAME = p_Column_Name
			AND FK_COLUMN_ID = p_FK_Column_ID;
			if p_Parent_Key_Column = v_Parent_Key_Column and p_Parent_Key_Item IS NOT NULL then
				v_filter := 'L1.' || v_Filter_Key_Column
				|| ' = NVL(V(' || dbms_assert.enquote_literal(p_Parent_Key_Item) || '), L1.' || v_Filter_Key_Column || ')';
			end if;
			v_result := data_browser_select.Key_Values_Path_Query(
				p_Table_Name => v_R_View_Name,
				p_Display_Col_Names => v_Displayed_Column_Names,
				p_Search_Key_Col => v_Unique_Key_Column,
				p_Search_Value => NULL,
				p_Exclude_Col_Name	=> case when p_Parent_Key_Column = v_Parent_Key_Column then v_Filter_Key_Column end,
				p_Active_Col_Name	=> v_Active_Lov_Column_Name,
				p_Active_Data_Type	=> v_Active_Lov_Data_Type,
				p_Folder_Par_Col_Name  => v_Folder_Par_Col_Name,
				p_Folder_Name_Col_Name => v_Folder_Name_Col_Name,
				p_Folder_Cont_Col_Name => v_Folder_Cont_Col_Name,
				p_Folder_Cont_Alias => NULL,
				p_View_Mode => 'FORM_VIEW',
				p_Filter_Cond => v_filter,
				p_Order_by => NVL(v_Ordering_Column_Name, '1')
			);
		else
			v_result := 'select null d, null r from dual';
		end if;
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_fk_column_id,p_column_name,p_parent_table,p_parent_key_column,p_parent_key_item,v_result;
        $END
        return v_result;
	exception when NO_DATA_FOUND then
$IF data_browser_conf.g_runtime_exceptions $THEN
		RAISE_APPLICATION_ERROR(-20101, 'Bad Parameter for Get_Ref_LOV_Query detected. Column: ' 
		|| dbms_assert.enquote_name(p_Table_Name) || '.' || dbms_assert.enquote_name(p_FK_Column_ID));
$END
		return 'select null d, null r from dual';
      when OTHERS then 
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_table_name,p_fk_column_id,p_column_name,p_parent_table,p_parent_key_column,p_parent_key_item;
        RAISE;
	end Get_Ref_LOV_Query;


	FUNCTION Child_Link_List_Query (
		p_Table_Name	IN VARCHAR2,
		p_Display_Col_Names IN VARCHAR2,	-- display columns
		p_Search_Key_Col IN VARCHAR2,		-- return column (usually the primary key of p_Table_Name)
		p_Search_Value	IN VARCHAR2 DEFAULT NULL, -- used to produce only a single output row for known value or reference
		p_View_Mode IN VARCHAR2,
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Key_Column IN VARCHAR2 DEFAULT NULL,
		p_Target1 IN VARCHAR2,
		p_Target2 IN VARCHAR2,
		p_Detail_Page_ID INTEGER,
		p_Link_Page_ID	INTEGER,
		p_Level IN NUMBER DEFAULT 1
	) RETURN VARCHAR2
	IS
	PRAGMA UDF;
		v_Column_List VARCHAR2(32767);
		v_From_Clause VARCHAR2(4000);
		v_Column_Expr VARCHAR2(4000);
		v_Result	  VARCHAR2(32767);
		v_Table_Alias	VARCHAR2(20);
		v_Delimiter CONSTANT VARCHAR2(20) :=  ' ||''' || data_browser_conf.Get_Rec_Desc_Delimiter || '''|| ';
		v_Group_Delimiter CONSTANT VARCHAR2(20) :=	' ||''' || data_browser_conf.Get_Rec_Desc_Group_Delimiter || '''|| ';
		v_Alias_Prefix CONSTANT VARCHAR2(20) :=	 'L' || p_Level;
		v_Key_Column VARCHAR2(128);
		CURSOR Display_Values_cur
		IS
			SELECT COLUMN_NAME, POSITION, NULLABLE, C_COLUMN_EXPR, TABLE_ALIAS,
				R_VIEW_NAME, R_PRIMARY_KEY_COLS, R_TABLE_ALIAS, R_COLUMN_NAMES
			FROM (
				SELECT
					VIEW_NAME, COLUMN_NAME, POSITION, NULLABLE,
					data_browser_select.Get_ConversionColFunction (
						p_Column_Name => TABLE_ALIAS || COLUMN_NAME,
						p_Data_Type => DATA_TYPE,
						p_Data_Precision => case when p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then DATA_PRECISION else FORM_DATA_PRECISION end,
						p_Data_Scale => case when p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then DATA_SCALE else FORM_DATA_SCALE end,
						p_Char_Length => CHAR_LENGTH,
						p_Data_Format => case when R_VIEW_NAME IS NULL then 'FORM' else 'NATIVE' end,
						p_Use_Trim => 'Y',
						p_Datetime => IS_DATETIME
					) C_COLUMN_EXPR,
					TABLE_ALIAS,
					R_VIEW_NAME, R_PRIMARY_KEY_COLS,
					R_TABLE_ALIAS,
					LISTAGG( case when R_SUB_QUERY IS NOT NULL then R_SUB_QUERY
								  when R_COLUMN_NAME is not null then -- R_TABLE_ALIAS || '.' || R_COLUMN_NAME 
									data_browser_conf.Get_Foreign_Key_Expression(p_Foreign_Key_Column=>R_COLUMN_NAME, p_Table_Alias=> R_TABLE_ALIAS)
								  end
							, v_Group_Delimiter)
						WITHIN GROUP (ORDER BY POSITION
					) R_COLUMN_NAMES -- all description columns of one foreign key
				FROM (
					SELECT --+ USE_NL_WITH_INDEX(C) USE_NL_WITH_INDEX(F) USE_NL_WITH_INDEX(G)
						C.VIEW_NAME, T.COLUMN_NAME, T.POSITION, C.NULLABLE,
						C.DATA_TYPE, C.DATA_PRECISION, C.DATA_SCALE, C.FORM_DATA_PRECISION, C.FORM_DATA_SCALE, C.CHAR_LENGTH, C.IS_DATETIME,
						F.R_VIEW_NAME, F.R_PRIMARY_KEY_COLS, F.R_COLUMN_NAME,
						case when COUNT(F.R_VIEW_NAME) OVER (PARTITION BY C.VIEW_NAME) > 0
							then v_Alias_Prefix || '.' -- use table alias in FROM clause, when foreign keys are contained in the display columns list
						end TABLE_ALIAS,
						v_Alias_Prefix || data_browser_conf.Sequence_To_Table_Alias(T.POSITION-1) R_TABLE_ALIAS,
						-- with levels > 1 error ORA-06502: PL/SQL: numerischer oder Wertefehler: Bulk Bind: Truncated Bind
						case when G.R_VIEW_NAME IS NOT NULL and p_Level = 1 then
							' (' || data_browser_select.Key_Values_Query (
								p_Table_Name		=> G.R_VIEW_NAME,
								p_Display_Col_Names => G.DISPLAYED_COLUMN_NAMES,
								p_Search_Key_Col	=> G.R_PRIMARY_KEY_COLS,
								p_Filter_Cond		=> data_browser_conf.Get_Join_Expression(
									p_Left_Columns=>G.R_PRIMARY_KEY_COLS, p_Left_Alias=> 'L' || (p_Level + 1),
									p_Right_Columns=>F.R_COLUMN_NAME, p_Right_Alias=> v_Alias_Prefix || data_browser_conf.Sequence_To_Table_Alias(T.POSITION-1)
								),
								p_View_Mode			=> p_View_Mode,
								p_Exclude_Col_Name	=> case when p_Search_Key_Col = G.PARENT_KEY_COLUMN then G.FILTER_KEY_COLUMN end,
								p_Level				=> p_Level + 1
							) || ') '
						end R_SUB_QUERY
					FROM ( -- ordered display columns list
						SELECT --+ CARDINALITY(2)
							TRIM(C.COLUMN_VALUE) COLUMN_NAME,
							ROWNUM POSITION
						FROM TABLE( apex_string.split(p_Display_Col_Names, ',') ) C
						WHERE (C.COLUMN_VALUE != p_Search_Key_Col or p_Display_Col_Names = p_Search_Key_Col ) -- don´t display return column value, unless it is the only column to display	 
					) T
					JOIN MVDATA_BROWSER_SIMPLE_COLS C ON C.COLUMN_NAME = T.COLUMN_NAME
					LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES R ON R.VIEW_NAME = C.VIEW_NAME AND R.COLUMN_NAME = T.COLUMN_NAME
					LEFT OUTER JOIN MVDATA_BROWSER_F_REFS F ON F.VIEW_NAME = C.VIEW_NAME AND F.FOREIGN_KEY_COLS = T.COLUMN_NAME
						AND F.R_COLUMN_NAME IS NOT NULL-- foreign key with description columns
					LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES G ON G.VIEW_NAME = F.R_VIEW_NAME AND G.COLUMN_NAME = F.R_COLUMN_NAME
					WHERE C.VIEW_NAME = p_Table_Name
					AND (F.R_COLUMN_NAME IS NULL OR R.FILTER_KEY_COLUMN IS NULL OR F.R_COLUMN_NAME != R.FILTER_KEY_COLUMN)
				)
				GROUP BY VIEW_NAME, TABLE_ALIAS, COLUMN_NAME, POSITION, NULLABLE, -- one line or each foreign key
					DATA_TYPE, DATA_PRECISION, DATA_SCALE, FORM_DATA_PRECISION, FORM_DATA_SCALE, CHAR_LENGTH, IS_DATETIME,
					R_VIEW_NAME, R_PRIMARY_KEY_COLS, R_TABLE_ALIAS, R_SUB_QUERY
			) T
			WHERE VIEW_NAME = p_Table_Name
			ORDER BY VIEW_NAME, POSITION;

		TYPE View_Cols_Tab IS TABLE OF Display_Values_cur%ROWTYPE;
		v_out_tab			View_Cols_Tab;
		v_Max_Link_Count CONSTANT PLS_INTEGER := data_browser_conf.Get_Navigation_Link_Limit;
	BEGIN
		OPEN Display_Values_cur;
		FETCH Display_Values_cur BULK COLLECT INTO v_out_tab;
		CLOSE Display_Values_cur;

        -- produce and return query for list of values (LOV_QUERY)
		if v_out_tab.COUNT > 0 then
			v_Table_Alias := RTRIM(v_out_tab(1).TABLE_ALIAS, '.');
			v_From_Clause := 'FROM ' || data_browser_select.FN_Table_Prefix 
						|| data_browser_conf.Enquote_Name_Required(p_Table_Name) || ' ' || v_Table_Alias;
			v_Column_Expr := data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> p_Search_Key_Col, p_Table_Alias=> v_Table_Alias, p_View_Mode=> p_View_Mode);
			v_Key_Column := data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> p_Key_Column, p_Table_Alias=> v_Table_Alias, p_View_Mode=> p_View_Mode);
			FOR ind IN 1 .. v_out_tab.COUNT LOOP
				if v_out_tab(ind).R_VIEW_NAME IS NOT NULL then
					-- foreign key columns - new group
					v_Column_List := v_Column_List || v_out_tab(ind).R_COLUMN_NAMES;
					if (ind = 1 or v_out_tab(ind).R_TABLE_ALIAS != v_out_tab(ind - 1).R_TABLE_ALIAS) then
						v_From_Clause := v_From_Clause
						|| case when v_out_tab(ind).NULLABLE = 'Y' then ' LEFT OUTER' end
						|| ' JOIN ' || data_browser_select.FN_Table_Prefix
						|| v_out_tab(ind).R_VIEW_NAME || ' ' || v_out_tab(ind).R_TABLE_ALIAS
						|| ' ON ' || v_out_tab(ind).R_TABLE_ALIAS || '.' || v_out_tab(ind).R_PRIMARY_KEY_COLS || ' = ' || v_out_tab(ind).C_COLUMN_EXPR;
					end if;
				else
					v_Column_List := v_Column_List || v_out_tab(ind).C_COLUMN_EXPR;
				end if;
				if ind < v_out_tab.COUNT then
					v_Column_List := v_Column_List
					|| case when v_out_tab(ind).TABLE_ALIAS = v_out_tab(ind+1).TABLE_ALIAS then v_Delimiter else v_Group_Delimiter end;
				end if;
			END LOOP;
			if v_out_tab.COUNT > 1 then
				v_Column_List := q'[' ( '||SUBSTR(]' || v_Column_List || q'[, 1, 1024)||' ) ']';
			end if;
			if p_Data_Format IN ('NATIVE', 'CSV', 'HTML') then
				v_Result := q'[(SELECT CLOBAGG(case when ROWNUM <= ]'
				|| v_Max_Link_Count || q'[ then DESCRIPTION else chr(38)||'hellip;' end) LINK_LIST]' || NL(4)
				|| ' FROM (' || NL(8)
				|| 'SELECT ' || v_Key_Column || ', '
				|| case when v_Column_List IS NOT NULL then v_Column_List else 'TO_CHAR(' || v_Column_Expr || ')' end
				|| ' DESCRIPTION' || NL(8)
				|| v_From_Clause || NL(8)
				|| 'WHERE ' || v_Column_Expr || ' = ' || p_Search_Value
				|| ' AND ROWNUM <= ' || (v_Max_Link_Count + 1) || NL(8)
				|| 'ORDER BY FLOOR(ROWNUM/' || (v_Max_Link_Count + 1) || '), DESCRIPTION ) ' || v_Table_Alias || NL(4)
				|| ')';
				return v_Result;
			else -- In forms, the link to the targets is rendered.
				v_Result := q'[(SELECT CLOBAGG(case when ROWNUM <= ]'
				|| v_Max_Link_Count || q'[ then ]'
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
				|| 'FN_Navigation_Link(' || p_Target1 || '|| KEY_ID '  -- links to first 10 records
					|| q'[||','|| ]' || p_Search_Value
					|| ', DESCRIPTION' 
$ELSE
				|| 'FN_Navigation_Link(' || p_Target1 || '||' || v_Key_Column -- links to first 10 records
					|| q'[||','|| ]' || p_Search_Value
					|| ', ' || NVL(v_Column_List, v_Column_Expr)
$END
					|| ', ' || p_Detail_Page_ID
					|| ')'
				|| NL(8)
				|| q'[else ]'
				|| 'FN_Navigation_More(' || p_Target2 || ', '  || p_Link_Page_ID  || ')' || NL(8)
				|| q'[end)]'
				|| case when data_browser_utl.Check_Edit_Enabled(p_Table_Name => p_Table_Name, p_View_Mode => p_View_Mode) = 'YES' then -- link to add new record
					'||' 
					|| 'FN_Navigation_Link(' || p_Target1 
					|| q'[||','|| ]' || p_Search_Value
					|| q'[, ' + ', ]' 
					|| p_Detail_Page_ID
					|| ')'
				end
				|| ' LINK_LIST'|| NL(8)
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
				|| ' FROM ('  || NL(12)
				|| 'SELECT ' || v_Key_Column || ' KEY_ID, ' || NVL(v_Column_List, v_Column_Expr) || ' DESCRIPTION' || NL(12)
				|| v_From_Clause || NL(12)
				|| 'WHERE ' || v_Column_Expr || ' = ' || p_Search_Value
				|| ' AND ROWNUM <= ' || (v_Max_Link_Count + 1) || NL(12)
				|| 'ORDER BY FLOOR(ROWNUM/' || (v_Max_Link_Count + 1) || q'[), ]' || 'DESCRIPTION ) ' || v_Table_Alias || NL(4)
$ELSE
				|| v_From_Clause || NL(8)
				|| ' WHERE ' || v_Column_Expr || ' = ' || p_Search_Value
				|| ' AND ROWNUM <= ' || (v_Max_Link_Count + 1) || NL(8)
$END
				|| ')';
				v_Result := DBMS_ASSERT.ENQUOTE_LITERAL('<div class="navigation_links">') || '||' || NL(4)
				|| v_Result || '||' || DBMS_ASSERT.ENQUOTE_LITERAL('</div>');
			end if;
		else 
$IF data_browser_conf.g_runtime_exceptions $THEN
		RAISE_APPLICATION_ERROR(-20101, 'Bad Parameter for Child_Link_List_Query detected. Column: ' 
		|| dbms_assert.enquote_name(p_Table_Name) || '.' || dbms_assert.enquote_name(p_Key_Column));
$END
			v_Result := 'null';
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_display_col_names,p_search_key_col,p_search_value,p_view_mode,p_data_format,p_key_column,p_target1,p_target2,p_detail_page_id,p_link_page_id,p_level,v_result;
        $END
        return v_result;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
		if Display_Values_cur%ISOPEN then
			CLOSE Display_Values_cur;
		end if;
		raise;
$END
	END Child_Link_List_Query;

	---------------------------------------------------------------------------

	FUNCTION Get_Sort_Link_Html (						-- internal
		p_Column_Name VARCHAR2,
		p_Column_Header VARCHAR2,
		p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : 'LAST_NAME, FIRST_NAME'
		p_Order_Direction VARCHAR2 DEFAULT 'ASC'		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Order_By VARCHAR2(200);
		v_Order_Dir VARCHAR2(200);
	begin
		v_Order_By := regexp_replace(p_Order_by,'([^,]+).*', '\1'); -- first word
		v_Order_Dir := regexp_replace(p_Order_Direction,'(\w+).*', '\1');	-- first word

		return -- the returned string must not exceed 4 KB to avoid buffer overflow errors
		'<a href="#"'
		|| ' data-item='|| DBMS_ASSERT.ENQUOTE_NAME(p_Column_Name) || '>'
		|| p_Column_Header
		|| '</a>'
		|| case when p_Column_Name = v_Order_By then
			case when v_Order_Dir = 'ASC' then
				'<span class="u-Report-sortIcon a-Icon icon-rpt-sort-asc"></span>'
			else
				'<span class="u-Report-sortIcon a-Icon icon-rpt-sort-desc"></span>'
			end
		end;
	end Get_Sort_Link_Html;

	FUNCTION Get_Imp_Table_Column_List (
		p_Table_Name VARCHAR2,
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Delimiter VARCHAR2 DEFAULT ', ',
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',		-- YES, NO
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_Format VARCHAR2 DEFAULT 'NAMES',				-- NAMES, HEADER, ALIGN, ITEM_HELP
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'EXPORT_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,	-- Y,N; use G in number format mask
		p_Report_Mode VARCHAR2 DEFAULT 'NO',			-- YES, NO
		p_Enable_Sort VARCHAR2 DEFAULT 'NO',			-- YES, NO
		p_Order_by VARCHAR2 DEFAULT NULL,				-- Example : 'LAST_NAME, FIRST_NAME'
		p_Order_Direction VARCHAR2 DEFAULT 'ASC',		-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Parent_Name VARCHAR2 DEFAULT NULL,			-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,		-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'		-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
	) RETURN CLOB
	IS
		v_Table_Name		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_result			CLOB;
		v_Str				VARCHAR2(4000);
		v_Describe_Cols_md5 VARCHAR2(300);
		v_is_cached			VARCHAR2(10);
		v_Delimiter			VARCHAR2(10);
		v_Select_Columns	VARCHAR2(32767);
		v_Parent_Key_Visible VARCHAR2(10);
		v_Column_Limit		PLS_INTEGER := p_Columns_Limit;
	BEGIN
		v_Select_Columns := FN_Terminate_List(p_Select_Columns);
		v_Parent_Key_Visible := FN_Parent_Key_Visible (p_Parent_Key_Visible, p_Edit_Mode, p_View_Mode, p_Data_Format, p_Select_Columns);
		data_browser_conf.Set_Current_Data_Format(p_Data_Format);
		v_Describe_Cols_md5 := wwv_flow_item.md5 (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Data_Format, p_Use_Group_Separator,
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column, v_Parent_Key_Visible, p_Join_Options);
		v_is_cached := case when g_Describe_Cols_md5 != v_Describe_Cols_md5 then 'load' else 'cached!' end;
		if v_is_cached != 'cached!' then
			OPEN data_browser_select.Describe_Imp_Cols_cur (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Data_Format, p_Use_Group_Separator,
															v_Select_Columns, p_Parent_Name, p_Parent_Key_Column, v_Parent_Key_Visible, p_Join_Options);
			FETCH data_browser_select.Describe_Imp_Cols_cur BULK COLLECT INTO g_Describe_Cols_tab;
			CLOSE data_browser_select.Describe_Imp_Cols_cur;
			g_Describe_Cols_md5 := v_Describe_Cols_md5;
		end if;
		dbms_lob.createtemporary(v_result, true, dbms_lob.call);
		v_Column_Limit := case when p_View_Mode = 'IMPORT_VIEW' 
			then LEAST(data_browser_conf.Get_Collection_Columns_Limit, p_Columns_Limit)
			else p_Columns_Limit
		end;
		FOR ind IN 1 .. g_Describe_Cols_tab.COUNT LOOP
			if	(p_Edit_Mode = 'YES'		-- if Edit single record or not hidden
			  and p_Report_Mode = 'NO'		-- in Edit single record mode, hidden (key) columns have no header
			  or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE != 'HIDDEN')
			and FN_Has_Collections_Adress(p_View_Mode, g_Describe_Cols_tab(ind))
			and FN_Show_Row_Selector(p_Data_Format, p_Edit_Mode, p_Report_Mode, p_View_Mode, p_Data_Columns_Only, g_Describe_Cols_tab(ind).COLUMN_NAME)
			and FN_Show_Import_Job(p_Data_Format, g_Describe_Cols_tab(ind).COLUMN_NAME)
			and FN_Display_In_Report(p_Data_Format, p_Report_Mode, p_View_Mode, g_Describe_Cols_tab(ind), v_Select_Columns) 
			and g_Describe_Cols_tab(ind).REPORT_COLUMN_ID <= v_Column_Limit
			then
				v_Str := v_Str
				|| v_Delimiter
				|| case p_Format
						when 'HEADER' then
							case when p_Report_Mode = 'YES'
								and p_Enable_Sort = 'YES'
								and p_Data_Format = 'FORM'
								and g_Describe_Cols_tab(ind).COLUMN_ID > 0
								and dbms_lob.getlength(v_result) < 3000 then
									-- the space for column headers is limited to 4000 bytes
									data_browser_select.Get_Sort_Link_Html(
										p_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME,
										p_Column_Header => g_Describe_Cols_tab(ind).COLUMN_HEADER,
										p_Order_by => p_Order_by,
										p_Order_Direction => p_Order_Direction
									)
								else
									g_Describe_Cols_tab(ind).COLUMN_HEADER
							end
						when 'ITEM_HELP' then
							-- the column headers can not be rendered when the output is too large
							-- the output can contain ':' characters
							data_browser_select.Get_Form_Required_Html (
								p_Is_Required  => g_Describe_Cols_tab(ind).REQUIRED,
								p_Check_Unique => g_Describe_Cols_tab(ind).CHECK_UNIQUE, 
								p_Display_Key_Column => g_Describe_Cols_tab(ind).IS_DISP_KEY_COLUMN )
							|| data_browser_select.Get_Form_Help_Link_Html (
									p_Column_Id => g_Describe_Cols_tab(ind).COLUMN_ID,
									p_R_View_Name => v_Table_Name,
									p_R_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME,
									p_Column_Header => g_Describe_Cols_tab(ind).COLUMN_HEADER,
									p_Comments => g_Describe_Cols_tab(ind).COMMENTS
								)
							|| case when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'ROW_SELECTOR' then
								' <input type="checkbox" onclick="$f_CheckFirstColumn(this)" class="t-Button--helpButton" />'
							end
						when 'NAMES' then g_Describe_Cols_tab(ind).COLUMN_NAME
						when 'ALIGN' then
							case when p_Edit_Mode = 'NO' or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then
								g_Describe_Cols_tab(ind).COLUMN_ALIGN
							else
								'LEFT'
							end
				end;
				if length(v_Str) > 1000 then
					dbms_lob.writeappend(v_result, length(v_Str), v_Str);
					v_Str := NULL;
				end if;
				v_Delimiter := p_Delimiter;
			end if;
		END LOOP;
		if v_Str IS NOT NULL then
			dbms_lob.writeappend(v_result, length(v_Str), v_Str);
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_delimiter,p_data_columns_only,p_select_columns,p_columns_limit,p_format,p_join_options,p_view_mode,p_edit_mode,p_Data_Format,p_Use_Group_Separator,p_report_mode,p_enable_sort,p_order_by,p_order_direction,p_parent_name,p_parent_key_column,p_parent_key_visible,v_result;
        $END
		RETURN v_result;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
		if data_browser_select.Describe_Imp_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Imp_Cols_cur;
		end if;
		raise;
$END
	END Get_Imp_Table_Column_List;


	PROCEDURE Get_Collection_Columns (
		p_Map_Column_List	IN OUT NOCOPY VARCHAR2,
		p_Map_Count			IN OUT PLS_INTEGER,
		p_Column_Expr_Type	VARCHAR2,
		p_Data_Type			VARCHAR2,
		p_Input_ID			VARCHAR2,
		p_Column_Name		VARCHAR2,
		p_Default_Value		VARCHAR2 DEFAULT NULL,
		p_indent			PLS_INTEGER DEFAULT 4,
		p_Convert_Expr		VARCHAR2 DEFAULT NULL,
		p_Is_Virtual_Column VARCHAR2 -- Y/N 
	)
	IS
		v_Delimiter2	VARCHAR2(50);
		v_Expression	VARCHAR2(2000);
		v_Default_Value VARCHAR2(2000);
	BEGIN
		if p_Input_ID IS NOT NULL then
			if SUBSTR(p_Input_ID, 1, 1) = 'C' then
				p_Map_Count := p_Map_Count + 1;
			end if;
			v_Delimiter2 := case when LENGTH(p_Map_Column_List) - INSTR(p_Map_Column_List, chr(10), -1) > 70 then ', ' || NL(p_indent+4)  else ', ' end;
			v_Expression := case when p_Convert_Expr IS NOT NULL then p_Convert_Expr else 'A.' || p_Input_ID end;
			if p_Default_Value IS NOT NULL and p_Is_Virtual_Column = 'N' then 
				v_Expression := 'NVL(' || v_Expression || ', ' || p_Default_Value || ')';
			end if;
			if p_Data_Type IN ('CLOB', 'NCLOB') then 
				v_Expression := 'TO_CLOB(' || v_Expression	|| ')';
			end if;
				
			p_Map_Column_List := p_Map_Column_List
			|| case when p_Map_Column_List IS NOT NULL then v_Delimiter2 end
			|| v_Expression
			|| ' ' || p_Column_Name;
		end if;
	END Get_Collection_Columns;


	FUNCTION Get_Collection_Query (
		p_Map_Column_List VARCHAR2,
		p_Map_Unique_Key VARCHAR2 DEFAULT NULL,
		p_indent PLS_INTEGER DEFAULT 4
	) RETURN VARCHAR2
	IS
	BEGIN
		return '(SELECT A.SEQ_ID LINK_ID$, ' || NVL(p_Map_Unique_Key, 'NULL') || ' ROW_SELECTOR$, ''.'' CONTROL_BREAK$, '
			|| NL(p_indent+4)
			|| p_Map_Column_List || NL(p_indent)
			|| 'FROM APEX_COLLECTIONS A WHERE COLLECTION_NAME = '
			|| data_browser_conf.Get_Import_Collection(p_Enquote=>'YES')
			|| NL(p_indent-4)
			|| ')';
	END Get_Collection_Query;

	FUNCTION Get_Imp_Table_From_Clause (
		p_Table_Name VARCHAR2,
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- TABLE, NEW_ROWS, COLLECTION, QUERY
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Map_Unique_Key VARCHAR2 DEFAULT NULL,
		p_Map_Column_List VARCHAR2 DEFAULT NULL
	) RETURN CLOB
	IS
		v_Count				PLS_INTEGER := 0;
		v_Str				CLOB;
	BEGIN
		if p_Data_Source IN ('TABLE', 'QUERY') then
			for c_cur in (
				SELECT SQL_TEXT
				FROM TABLE (
					data_browser_joins.Get_Detail_Table_Joins_Cursor(
						p_Table_name => p_Table_Name,
						p_As_Of_Timestamp => p_As_Of_Timestamp,
						p_Join_Options => p_Join_Options,
						p_Include_Schema => data_browser_conf.Get_Include_Query_Schema
					)
				)
			)
			loop
				v_Count := v_Count + 1;
				v_Str := v_Str || chr(10) || c_cur.SQL_TEXT;
			end loop;
			if v_Count = 0 then
				v_Str := v_Str || chr(10) || 'FROM DUAL X '
				|| '-- unexpected case, no table found.';
			end if;
		elsif p_Data_Source = 'COLLECTION' then
			v_Str := v_Str || chr(10) || 'FROM '
			|| data_browser_select.Get_Collection_Query (
				p_Map_Column_List => p_Map_Column_List,
				p_Map_Unique_Key => p_Map_Unique_Key,
				p_indent => 4)
			|| ' A ';
		else
			v_Str := v_Str || chr(10) || 'FROM DUAL A '
			|| '-- Data_Source: ' || p_Data_Source;
		end if;
		return v_Str;
	END Get_Imp_Table_From_Clause;

	FUNCTION Get_Imp_Table_Query (
		p_Table_Name VARCHAR2,
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Control_Break	 VARCHAR2 DEFAULT NULL,
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'EXPORT_VIEW',
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- TABLE, NEW_ROWS, COLLECTION, QUERY
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,		-- Y,N; use G in number format mask
		p_Report_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links 
		p_Search_Field_Item VARCHAR2 DEFAULT NULL,			-- Example : P30_SEARCH
		p_Search_Column_Name IN VARCHAR2 DEFAULT NULL,
		p_Comments VARCHAR2 DEFAULT NULL,					-- Comments
		p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_File_Page_ID NUMBER DEFAULT 31					-- Page ID of target links to file preview in View_Mode FORM_VIEW
	) RETURN CLOB
	IS
		v_Table_Name		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Unique_Key_Column MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Stat				CLOB;
		v_From_Clause		CLOB;
		v_Str				VARCHAR2(32767);
		v_Expression		VARCHAR2(32767);
		v_Select_Columns	VARCHAR2(32767);
		v_Parent_Key_Visible VARCHAR2(10);
		v_Ctrl_Break_Expr	VARCHAR2(32767);
		v_Control_Break		VARCHAR2(1024);
		v_Delimiter			CONSTANT VARCHAR2(50) := ',' || NL(4);
		v_Delimiter2		VARCHAR2(50);
		v_Describe_Cols_md5 VARCHAR2(300);
		v_Column_Expr		VARCHAR2(32767);
		v_is_cached			VARCHAR2(10);
		v_Map_Unique_Key	VARCHAR2(32);
		v_Map_Column_List	VARCHAR2(32767);
		v_Map_Count			PLS_INTEGER := 0;
		v_Data_Format		VARCHAR2(20);
		v_Column_Limit		PLS_INTEGER := p_Columns_Limit;
	BEGIN
		v_Data_Format := case when p_Data_Source IN('COLLECTION', 'QUERY') then 'QUERY' else p_Data_Format end;
		v_Select_Columns := FN_Terminate_List(p_Select_Columns);
		v_Parent_Key_Visible := FN_Parent_Key_Visible (p_Parent_Key_Visible, p_Edit_Mode, p_View_Mode, v_Data_Format, p_Select_Columns);
		if p_Unique_Key_Column IS NULL then
			SELECT SEARCH_KEY_COLS
			INTO v_Unique_Key_Column
			FROM MVDATA_BROWSER_VIEWS
			WHERE VIEW_NAME = p_Table_Name;
		else
			v_Unique_Key_Column := p_Unique_Key_Column;
		end if;
		data_browser_conf.Set_Current_Data_Format(v_Data_Format);
		v_Describe_Cols_md5 := wwv_flow_item.md5 (v_Table_Name, v_Unique_Key_Column, p_View_Mode, v_Data_Format, p_Use_Group_Separator,
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column, v_Parent_Key_Visible, p_Join_Options);
		v_is_cached := case when g_Describe_Cols_md5 != v_Describe_Cols_md5 then 'load' else 'cached!' end;
		if v_is_cached != 'cached!' then
			OPEN data_browser_select.Describe_Imp_Cols_cur (v_Table_Name, v_Unique_Key_Column, p_View_Mode, v_Data_Format, p_Use_Group_Separator,
															v_Select_Columns, p_Parent_Name, p_Parent_Key_Column, v_Parent_Key_Visible, p_Join_Options);
			FETCH data_browser_select.Describe_Imp_Cols_cur BULK COLLECT INTO g_Describe_Cols_tab;
			CLOSE data_browser_select.Describe_Imp_Cols_cur;
			g_Describe_Cols_md5 := v_Describe_Cols_md5;
		end if;
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		if p_Control_Break IS NOT NULL then
			if p_Data_Source NOT IN ('NEW_ROWS', 'COLLECTION') then 
				v_Control_Break := FN_Terminate_List(REPLACE(p_Control_Break, ', ', ':'));
				for ind in 1 .. g_Describe_Cols_tab.count loop
					v_Expression := FN_Terminate_List(g_Describe_Cols_tab(ind).COLUMN_NAME);
					if INSTR(v_Control_Break, v_Expression) > 0 then
						v_Ctrl_Break_Expr := data_browser_conf.Concat_List(v_Ctrl_Break_Expr, g_Describe_Cols_tab(ind).COLUMN_EXPR, 
											'||'||data_browser_conf.Enquote_Literal(data_browser_conf.Get_Rec_Desc_Delimiter)||'||');
					end if;
				end loop;
				if v_Ctrl_Break_Expr IS NOT NULL then 
					v_Ctrl_Break_Expr := 'TO_CHAR(' || v_Ctrl_Break_Expr || ')';
				end if;
			else 
				v_Ctrl_Break_Expr := 'NULL';
			end if;
		end if;

		v_Column_Limit := case when p_View_Mode = 'IMPORT_VIEW' 
			then LEAST(data_browser_conf.Get_Collection_Columns_Limit, p_Columns_Limit)
			else p_Columns_Limit
		end;
		v_Str := 'SELECT ' || CM(p_Comments) || NL(4);
		for ind IN 1 .. g_Describe_Cols_tab.COUNT loop
			if (p_Data_Source = 'QUERY' or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE != 'HIDDEN')	-- hidden (key) columns are excluded
			and FN_Has_Collections_Adress(p_View_Mode, g_Describe_Cols_tab(ind))
			and FN_Show_Row_Selector(v_Data_Format, p_Edit_Mode, p_Report_Mode, p_View_Mode, p_Data_Columns_Only, g_Describe_Cols_tab(ind).COLUMN_NAME)
			and FN_Show_Import_Job(v_Data_Format, g_Describe_Cols_tab(ind).COLUMN_NAME)
			and FN_Display_In_Report(v_Data_Format, p_Report_Mode, p_View_Mode, g_Describe_Cols_tab(ind), v_Select_Columns) 
			and g_Describe_Cols_tab(ind).REPORT_COLUMN_ID <= v_Column_Limit
			then
				v_Column_Expr := g_Describe_Cols_tab(ind).COLUMN_EXPR;
				if p_Data_Source = 'TABLE' then
					if p_Data_Format IN ('FORM', 'HTML')
					and g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE IN ('TEXT', 'POPUP_FROM_LOV', 'DISPLAY_AND_SAVE') 
					and g_Describe_Cols_tab(ind).CHAR_LENGTH > 0 -- only text columns
					and p_Edit_Mode = 'NO' then
						v_Column_Expr := 'APEX_ESCAPE.HTML(' || v_Column_Expr || ')';	-- bugfix for XSS vulnerability reported by joel.kallman@oracle.com on 11.06.2020
					end if;

					if p_Search_Field_Item IS NOT NULL
					and (g_Describe_Cols_tab(ind).COLUMN_NAME LIKE p_Search_Column_Name OR p_Search_Column_Name IS NULL) then
						 v_Column_Expr := data_browser_select.Highlight_Search_Expr (
							p_Data_Format => p_Data_Format,
							p_Column_Expr => v_Column_Expr,
							p_Column_Expr_Type => g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE,
							p_Is_Searchable_Ref => g_Describe_Cols_tab(ind).IS_SEARCHABLE_REF,
							p_Search_Item => p_Search_Field_Item
						);
					end if;
				end if;
				v_Expression := case 
					when p_Data_Source = 'COLLECTION' 
						then NULL
					when g_Describe_Cols_tab(ind).COLUMN_NAME = 'CONTROL_BREAK$'
						then NVL(v_Ctrl_Break_Expr, data_browser_conf.Enquote_Literal('.'))
					when p_Data_Source IN ('NEW_ROWS', 'MEMORY')
						then 'NULL'
					when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'LINK_ID' then 
						data_browser_select.Detail_Link_Html(
							p_Data_Format => p_Data_Format,
							p_Table_name => p_Table_name, 
							p_Parent_Table => p_Parent_Name, 
							p_Link_Page_ID => p_Form_Page_ID, 
							p_Link_Items => DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Form_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_PARENT_ID')),
							p_Key_Value => case when p_Data_Source IN ('COLLECTION') then 'LINK_ID$' else g_Describe_Cols_tab(ind).COLUMN_EXPR end,
							p_Parent_Value => case when p_Data_Source IN ('TABLE', 'QUERY') then p_Parent_Key_Column end,
							p_View_Mode => p_View_Mode
						) 
					when g_Describe_Cols_tab(ind).IS_VIRTUAL_COLUMN = 'Y' then
						case when p_Data_Source = 'COLLECTION'
							then g_Describe_Cols_tab(ind).DATA_DEFAULT
						else
							v_Column_Expr
						end
					when p_Data_Source = 'QUERY' then 
						case when data_browser_select.FN_Apex_Item_Use_Column(g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE) = 'YES'
							then g_Describe_Cols_tab(ind).TABLE_ALIAS || '.' || g_Describe_Cols_tab(ind).REF_COLUMN_NAME
						else
							v_Column_Expr
						end
					when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'ROW_SELECTOR'
						then data_browser_select.Get_Row_Selector_Expr(
								p_Data_Format => p_Data_Format, 
								p_Column_Expr => g_Describe_Cols_tab(ind).COLUMN_EXPR, 
								p_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME
							)
					when p_Data_Format IN ('FORM', 'HTML')
					and (g_Describe_Cols_tab(ind).CHAR_LENGTH > data_browser_conf.Get_TextArea_Min_Length
							or g_Describe_Cols_tab(ind).DATA_TYPE IN ('CLOB', 'NCLOB')) then
						 data_browser_blobs.FN_Text_Tool_Body_Html (
							p_Column_Label => g_Describe_Cols_tab(ind).COLUMN_NAME,
							p_Column_Expr => v_Column_Expr
						) -- insert text div for better formating of large text blocks
					when p_Data_Format IN ('FORM', 'HTML')
					and p_View_Mode != 'RECORD_VIEW'
					and g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'FILE_BROWSER' then
						data_browser_blobs.FN_File_Icon_Link(
							p_Table_Name => v_Table_Name,
							p_Key_Column => v_Unique_Key_Column,
							p_Value => data_browser_conf.Get_Link_ID_Expression(
								p_Unique_Key_Column=> v_Unique_Key_Column, 
								p_Table_Alias=> 'A', 
								p_View_Mode=> p_View_Mode),
							p_Page_ID => p_File_Page_ID
						) -- insert file preview icon for blob columns
					else v_Column_Expr
				end;
				v_Str :=  v_Str
				|| v_Delimiter2
				|| v_Expression
				|| case when v_Expression IS NULL or v_Expression != g_Describe_Cols_tab(ind).TABLE_ALIAS || '.' || g_Describe_Cols_tab(ind).COLUMN_NAME then
					' ' || g_Describe_Cols_tab(ind).COLUMN_NAME
				end;
				if length(v_Str) > 1000 then
					dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
					v_Str := NULL;
				end if;
				v_Delimiter2 := v_Delimiter;
				if p_View_Mode = 'IMPORT_VIEW' then 
					if p_Data_Source = 'COLLECTION' then
						data_browser_select.Get_Collection_Columns (
							p_Map_Column_List => v_Map_Column_List,
							p_Map_Count => v_Map_Count,
							p_Column_Expr_Type => g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE,
							p_Data_Type => g_Describe_Cols_tab(ind).DATA_TYPE,
							p_Input_ID => g_Describe_Cols_tab(ind).INPUT_ID,
							p_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME,
							p_indent => 4,
							p_Convert_Expr => case 
								when g_Describe_Cols_tab(ind).YES_NO_COLUMN_TYPE IS NOT NULL
									then data_browser_conf.Lookup_Yes_No_Call(g_Describe_Cols_tab(ind).YES_NO_COLUMN_TYPE, 'A.' || g_Describe_Cols_tab(ind).INPUT_ID)
								end,
							p_Is_Virtual_Column => g_Describe_Cols_tab(ind).IS_VIRTUAL_COLUMN
						);
						if g_Describe_Cols_tab(ind).COLUMN_NAME = v_Unique_Key_Column then 
							v_Map_Unique_Key := g_Describe_Cols_tab(ind).INPUT_ID;
						end if;
					end if;
				end if;
			end if;
		end loop;
		if v_Delimiter2 IS NULL then
			v_Str := v_Str || ' NULL';
		end if;
		if length(v_Str) > 0 then
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
			v_Str := NULL;
		end if;
		v_From_Clause := Get_Imp_Table_From_Clause (
			p_Table_Name => v_Table_Name,
			p_Join_Options => p_Join_Options,
			p_Data_Source => p_Data_Source,
			p_As_Of_Timestamp => p_As_Of_Timestamp,
			p_Map_Unique_Key => v_Map_Unique_Key,
			p_Map_Column_List => v_Map_Column_List
		);
		dbms_lob.append(v_Stat, v_From_Clause);

        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_data_columns_only,p_columns_limit,p_as_of_timestamp,p_select_columns,p_control_break,p_join_options,p_view_mode,p_edit_mode,p_data_source,p_data_format,p_Use_Group_Separator,p_report_mode,p_form_page_id,p_form_parameter,p_search_field_item,p_search_column_name,p_comments,p_parent_name,p_parent_key_column,p_parent_key_visible,p_file_page_id,v_Stat;
        $END
		RETURN v_Stat;
	exception
	  when others then
		if data_browser_select.Describe_Imp_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Imp_Cols_cur;
		end if;
		raise;
	END Get_Imp_Table_Query;

	---------------------------------------------------------------------------

	FUNCTION Get_Form_View_From_Clause (					-- internal
		p_Table_name IN VARCHAR2,							-- Table Name or View Name of master table
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Empty_Row VARCHAR2  DEFAULT 'NO',					-- YES, NO
		p_Source_Query CLOB DEFAULT NULL,					-- Passed query for from clause
		p_Parameter_Columns VARCHAR2 DEFAULT NULL
	) RETURN CLOB
	is
		v_Stat				CLOB;
		v_Str				VARCHAR2(32767);
		v_Primary_Key_Cond	VARCHAR2(4000);
	begin
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		v_Str := v_Str || chr(10) || ' FROM ';

		if p_Parameter_Columns IS NOT NULL then 
			v_Str := v_Str || '(SELECT ' || p_Parameter_Columns || ' FROM DUAL) PAR, ' || NL(4);
		end if;
		if p_View_Mode = 'HISTORY'
		and p_Source_Query IS NOT NULL
		and p_Empty_Row = 'NO' then
			v_Str := v_Str || '(' ;
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
			dbms_lob.append(v_Stat, p_Source_Query);
			v_Str :=  chr(10) || ') A'
				|| chr(10) || 'FULL OUTER JOIN ' 
				|| data_browser_select.FN_Table_Prefix
				|| data_browser_conf.Enquote_Name_Required(p_Table_Name)
				|| ' B ON ' 
				|| data_browser_conf.Get_Join_Expression(
						p_Left_Columns=>p_Unique_Key_Column, p_Left_Alias=>'A',
						p_Right_Columns=>p_Unique_Key_Column, p_Right_Alias=>'B'
				);
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		elsif p_Empty_Row = 'YES' or p_Table_Name IS NULL then
			v_Str := v_Str || 'DUAL A ';
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		else
			v_Str := v_Str 
			|| data_browser_select.FN_Table_Prefix
			|| data_browser_conf.Enquote_Name_Required(p_Table_Name) || ' A ';
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;
		return v_Stat;
	end Get_Form_View_From_Clause;

	FUNCTION Get_Form_View_Query (							-- internal
		p_Table_name IN VARCHAR2,							-- Table Name or View Name of master table
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Control_Break	 VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- TABLE, QUERY
		p_Empty_Row VARCHAR2  DEFAULT 'NO',					-- YES, NO
		p_Report_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),		-- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
		p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links 
		p_File_Page_ID NUMBER DEFAULT 31,					-- Page ID of target links to file preview in View_Mode FORM_VIEW
		p_Search_Field_Item VARCHAR2 DEFAULT NULL,			-- Example : P30_SEARCH
		p_Search_Column_Name VARCHAR2 DEFAULT NULL,			-- table column name for searching
		p_Calc_Totals VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Nested_Links VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Source_Query CLOB DEFAULT NULL,					-- Passed query for from clause
		p_Comments VARCHAR2 DEFAULT NULL					-- Comments
	) RETURN CLOB
	is
		v_Table_Name		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Unique_Key_Column MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Unique_Key_Expr	VARCHAR2(32767);
		v_Stat				CLOB;
		v_From_Clause		CLOB;
		v_Str				VARCHAR2(32767);
		v_Expression		VARCHAR2(32767);
		v_Select_Columns	VARCHAR2(32767);
		v_Parameter_Columns VARCHAR2(32767);
		v_Parent_Key_Visible VARCHAR2(10);
		v_Calc_Totals		VARCHAR2(10);
		v_Nested_Links		VARCHAR2(10);
		v_Ctrl_Break_Expr	VARCHAR2(32767);
		v_Ctrl_Break_List	VARCHAR2(32767);
		v_Ctrl_Break_First	VARCHAR2(1024);
		v_Control_Break		VARCHAR2(1024);
		v_Delimiter			CONSTANT VARCHAR2(50) := ',' || NL(4);
		v_Delimiter2		VARCHAR2(50);
		v_Describe_Cols_md5 VARCHAR2(300);
		v_Column_Expr		VARCHAR2(32767);
		v_is_cached			VARCHAR2(10);
		v_Links_Count		PLS_INTEGER := 0;
		v_Link_List_Count	PLS_INTEGER := 0;
		v_Data_Format		VARCHAR2(20);
		v_Use_Grouping		BOOLEAN;
	begin
		v_Data_Format := case when p_Data_Source = 'QUERY' then 'QUERY' else p_Data_Format end;
		data_browser_conf.Set_Current_Data_Format(v_Data_Format);
		v_Calc_Totals := NVL(p_Calc_Totals, 'NO');
		v_Nested_Links := NVL(p_Nested_Links, 'NO');
		v_Select_Columns := FN_Terminate_List(p_Select_Columns);
		v_Parent_Key_Visible := FN_Parent_Key_Visible (p_Parent_Key_Visible, p_Edit_Mode, p_View_Mode, v_Data_Format, p_Select_Columns);
		v_Use_Grouping := v_Calc_Totals = 'YES';
		if p_Unique_Key_Column IS NULL then
			SELECT SEARCH_KEY_COLS
			INTO v_Unique_Key_Column
			FROM MVDATA_BROWSER_VIEWS
			WHERE VIEW_NAME = p_Table_Name;
		else
			v_Unique_Key_Column := p_Unique_Key_Column;
		end if;
		v_Unique_Key_Expr := data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> v_Unique_Key_Column, p_Table_Alias=> 'A', p_View_Mode=> p_View_Mode);
		v_Describe_Cols_md5 := wwv_flow_item.md5 (v_Table_Name, v_Unique_Key_Column, p_View_Mode, p_Edit_Mode, v_Data_Format, 
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column,
												p_Link_Page_ID, p_Detail_Page_ID, v_Calc_Totals);
		v_is_cached := case when g_Describe_Cols_md5 != v_Describe_Cols_md5 then 'load' else 'cached!' end;
		if v_is_cached != 'cached!' then
			OPEN data_browser_select.Describe_Cols_cur (v_Table_Name, v_Unique_Key_Column, p_View_Mode, p_Edit_Mode, v_Data_Format, 
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column,
												p_Link_Page_ID, p_Detail_Page_ID, v_Calc_Totals);
			FETCH data_browser_select.Describe_Cols_cur BULK COLLECT INTO g_Describe_Cols_tab;
			CLOSE data_browser_select.Describe_Cols_cur;
			g_Describe_Cols_md5 := v_Describe_Cols_md5;
		end if;
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		if p_Control_Break IS NOT NULL then 
			if p_Empty_Row = 'NO' then
				v_Control_Break := FN_Terminate_List(REPLACE(p_Control_Break, ', ', ':'));
				for ind in 1 .. g_Describe_Cols_tab.count loop
					v_Column_Expr := FN_Terminate_List(g_Describe_Cols_tab(ind).COLUMN_NAME);
					if INSTR(v_Control_Break, v_Column_Expr) > 0 and g_Describe_Cols_tab(ind).TABLE_ALIAS = 'A' then
						v_Column_Expr := 'A.' || g_Describe_Cols_tab(ind).R_COLUMN_NAME;
						if v_Ctrl_Break_First IS NULL then 
							v_Ctrl_Break_First := v_Column_Expr;
						end if;
						v_Ctrl_Break_Expr := data_browser_conf.Concat_List(v_Ctrl_Break_Expr, g_Describe_Cols_tab(ind).COLUMN_EXPR, 
											'||'|| data_browser_conf.Enquote_Literal(data_browser_conf.Get_Rec_Desc_Delimiter)||'||');
						v_Ctrl_Break_List := data_browser_conf.Concat_List(v_Ctrl_Break_List, v_Column_Expr);
					end if;
				end loop;
				if v_Ctrl_Break_Expr IS NOT NULL then 
					v_Ctrl_Break_Expr := 'TO_CHAR(' || v_Ctrl_Break_Expr || ')';
				end if;
			else 
				v_Ctrl_Break_Expr := 'NULL';
			end if;
		end if;
		if v_Ctrl_Break_List IS NULL then 
			v_Ctrl_Break_List := v_Unique_Key_Expr;
		end if;
		if v_Ctrl_Break_First IS NULL then 
			v_Ctrl_Break_First := v_Unique_Key_Expr;
		end if;
		v_Str := 'SELECT ' || CM(p_Comments) || NL(4);
		FOR ind IN 1 .. g_Describe_Cols_tab.COUNT LOOP
			if (p_Data_Source = 'QUERY' or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE != 'HIDDEN')	-- hidden (key) columns are excluded from read only views
			and FN_Show_Parent_Key(v_Parent_Key_Visible, p_Parent_Name, p_Parent_Key_Column, g_Describe_Cols_tab(ind))
			and FN_Show_Row_Selector(v_Data_Format, p_Edit_Mode, p_Report_Mode, p_View_Mode, p_Data_Columns_Only, g_Describe_Cols_tab(ind).COLUMN_NAME)
			and FN_Display_In_Report(v_Data_Format, p_Report_Mode, p_View_Mode, g_Describe_Cols_tab(ind), v_Select_Columns) 
			and g_Describe_Cols_tab(ind).REPORT_COLUMN_ID <= p_Columns_Limit
			then
				v_Column_Expr := g_Describe_Cols_tab(ind).COLUMN_EXPR;
				if p_Data_Source = 'TABLE' 
				and p_Data_Format IN ('FORM', 'HTML')
				and g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE IN ('TEXT', 'POPUP_FROM_LOV', 'DISPLAY_AND_SAVE') 
				and g_Describe_Cols_tab(ind).CHAR_LENGTH > 0 -- only text columns
				and p_Edit_Mode = 'NO' then
					v_Column_Expr := 'APEX_ESCAPE.HTML(' || v_Column_Expr || ')';	-- bugfix for XSS vulnerability reported by joel.kallman@oracle.com on 11.06.2020
				end if;
				-- insert highlight search expression in Search mode
				if (p_Search_Field_Item IS NOT NULL
				and p_Data_Source = 'TABLE' or (p_Data_Source = 'QUERY' and g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'DISPLAY_ONLY'))
				and g_Describe_Cols_tab(ind).COLUMN_ID > 0 
				and (g_Describe_Cols_tab(ind).COLUMN_NAME LIKE p_Search_Column_Name OR p_Search_Column_Name IS NULL) then 
					v_Column_Expr := data_browser_select.Highlight_Search_Expr (
						p_Data_Format => p_Data_Format,
						p_Column_Expr => v_Column_Expr,
						p_Column_Expr_Type => g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE,
						p_Is_Searchable_Ref => g_Describe_Cols_tab(ind).IS_SEARCHABLE_REF,
						p_Search_Item => p_Search_Field_Item
					);
				end if;
				if p_View_Mode = 'HISTORY' then 
					if g_Describe_Cols_tab(ind).COLUMN_ID > 0
					and g_Describe_Cols_tab(ind).IS_AUDIT_COLUMN = 'N' then
						v_Column_Expr := data_browser_select.Markup_Differences_Expr (
							p_Data_Format => p_Data_Format,
							p_Key_Column => v_Unique_Key_Column,
							p_Column_Expr => v_Column_Expr,
							p_Column_Name => g_Describe_Cols_tab(ind).REF_COLUMN_NAME,
							p_Data_Type => g_Describe_Cols_tab(ind).DATA_TYPE
						);
					elsif g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE IN ('LINK_ID', 'ROW_SELECTOR') then 
						v_Column_Expr := 'NVL(' || v_Column_Expr || ', ' 
						|| data_browser_conf.Get_Link_ID_Expression(p_Unique_Key_Column=> v_Unique_Key_Column, p_Table_Alias=> 'B', p_View_Mode=> p_View_Mode) || ')';
					end if;
				end if;
				v_Expression := case 
					when g_Describe_Cols_tab(ind).COLUMN_NAME = 'CONTROL_BREAK$'
						then NVL(v_Ctrl_Break_Expr, data_browser_conf.Enquote_Literal('.'))
					when p_Empty_Row = 'YES'
						then 'NULL' -- Source is NULL for empty rows and the ROW_SELECTOR column
					when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'LINK_ID' then 
						data_browser_select.Detail_Link_Html(
							p_Data_Format => v_Data_Format,
							p_Table_name => p_Table_name, 
							p_Parent_Table => p_Parent_Name, 
							p_Link_Page_ID => p_Form_Page_ID, 
							p_Link_Items => DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Form_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_PARENT_ID')),
							p_Key_Value => case when p_Data_Source IN ('COLLECTION') then 'LINK_ID$' else v_Column_Expr end,
							p_Parent_Value => case when p_Data_Source IN ('TABLE', 'QUERY') then 
								p_Parent_Key_Column
							end,
							p_Is_Total => case when v_Use_Grouping then 'GROUPING(' || v_Ctrl_Break_First || ')' end,
							p_Is_Subtotal => case when v_Use_Grouping then 'GROUPING(' || v_Unique_Key_Expr || ')' end,
							p_View_Mode => p_View_Mode
						) 
					----------------------------------------------------------------------------
					when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'LINK' then 
						case when v_Nested_Links = 'YES' then 
							data_browser_select.Nested_Link_HTML(
								p_Data_Format => v_Data_Format,
								p_CounterQuery => g_Describe_Cols_tab(ind).LOV_QUERY,
								p_Attributes => dbms_assert.enquote_literal(
													'class="nested_view" data-table=' || dbms_assert.enquote_name(g_Describe_Cols_tab(ind).R_VIEW_NAME) 
													|| ' data-parent=' || dbms_assert.enquote_name(g_Describe_Cols_tab(ind).REF_VIEW_NAME)
													|| ' data-key-column=' || dbms_assert.enquote_name(g_Describe_Cols_tab(ind).R_COLUMN_NAME)
													|| ' data-key-value="')
												|| '||'
												|| 'A.' || g_Describe_Cols_tab(ind).REF_COLUMN_NAME	 -- LINK_ID
												|| '||'
												|| dbms_assert.enquote_literal('"'),
								p_Is_Total => case when v_Use_Grouping then 'GROUPING(' || v_Ctrl_Break_First || ')' end,
								p_Is_Subtotal => case when v_Use_Grouping then 'GROUPING(' || v_Unique_Key_Expr || ')' end
							)
						else 
							data_browser_select.Navigation_Counter_HTML(
								p_Data_Format => v_Data_Format,
								p_CounterQuery => g_Describe_Cols_tab(ind).LOV_QUERY,
								p_Target => 'PAR.TARGET2||' -- passed Item names from p_Link_Parameter
											|| dbms_assert.enquote_literal(
											   ':' || g_Describe_Cols_tab(ind).REF_VIEW_NAME || ','		-- TABLE_NAME
												|| p_Parent_Name || ','									-- PARENT_NAME
											)
											|| '||'
											|| 'A.' || g_Describe_Cols_tab(ind).REF_COLUMN_NAME -- LINK_ID
											|| '||'
											|| dbms_assert.enquote_literal(
												','
												|| g_Describe_Cols_tab(ind).R_VIEW_NAME || ','		-- DETAIL_TABLE
												|| g_Describe_Cols_tab(ind).R_COLUMN_NAME			-- DETAIL_KEY
											),
								p_Link_Page_ID => p_Link_Page_ID,
								p_Is_Total => case when v_Use_Grouping then 'GROUPING(' || v_Ctrl_Break_First || ')' end,
								p_Is_Subtotal => case when v_Use_Grouping then 'GROUPING(' || v_Unique_Key_Expr || ')' end
							)
						end		
					----------------------------------------------------------------------------
					when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'NUMBER') 
					and g_Describe_Cols_tab(ind).IS_SUMMAND = 'Y' and v_Use_Grouping then 
						data_browser_select.Bold_Total_Html(
							p_Data_Format => v_Data_Format,
							p_Value => v_Column_Expr,
							p_Is_Total => 'GROUPING(' || v_Ctrl_Break_First || ')',
							p_Is_Subtotal => 'GROUPING(' || v_Unique_Key_Expr || ')'
						)
					when p_Data_Source = 'QUERY' then 
						case when data_browser_select.FN_Apex_Item_Use_Column(g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE) = 'YES'
							then data_browser_conf.Get_Link_ID_Expression(
								p_Unique_Key_Column=> g_Describe_Cols_tab(ind).REF_COLUMN_NAME, 
								p_Table_Alias=> g_Describe_Cols_tab(ind).TABLE_ALIAS, 
								p_View_Mode=> p_View_Mode)
						else
							v_Column_Expr
						end
					when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'ROW_SELECTOR'
						then data_browser_select.Get_Row_Selector_Expr(
								p_Data_Format => p_Data_Format, 
								p_Column_Expr => v_Column_Expr, 
								p_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME
							)
					when p_Data_Format IN ('FORM', 'HTML')
					-- and p_View_Mode != 'RECORD_VIEW' -- Bugfix DS 20230611: improved display of record views
					and (g_Describe_Cols_tab(ind).CHAR_LENGTH > data_browser_conf.Get_TextArea_Min_Length
							or g_Describe_Cols_tab(ind).DATA_TYPE IN ('CLOB', 'NCLOB')) then
						 data_browser_blobs.FN_Text_Tool_Body_Html (
							p_Column_Label => g_Describe_Cols_tab(ind).COLUMN_NAME,
							p_Column_Expr => v_Column_Expr
						) -- insert text div for better formating of large text blocks
					when p_Data_Format IN ('FORM', 'HTML')
					and p_View_Mode != 'RECORD_VIEW'
					and g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'FILE_BROWSER' then
						data_browser_blobs.FN_File_Icon_Link(
							p_Table_Name => v_Table_Name,
							p_Key_Column => v_Unique_Key_Column,
							p_Value => data_browser_conf.Get_Link_ID_Expression(
								p_Unique_Key_Column=> v_Unique_Key_Column, 
								p_Table_Alias=> 'A', 
								p_View_Mode=> p_View_Mode),
							p_Page_ID => p_File_Page_ID
						) -- insert file preview icon for blob columns
					else v_Column_Expr
				end;
				v_Str :=  v_Str
				|| v_Delimiter2
				|| v_Expression
				|| case when v_Expression IS NULL or v_Expression != g_Describe_Cols_tab(ind).TABLE_ALIAS || '.' || g_Describe_Cols_tab(ind).COLUMN_NAME then
					' ' || g_Describe_Cols_tab(ind).COLUMN_NAME
				end;
				if g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'LINK'  then
					v_Links_Count := v_Links_Count + 1;
				elsif g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'LINK_LIST' then
					v_Link_List_Count := v_Link_List_Count + 1;
				end if;
				if length(v_Str) > 1000 then
					dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
					v_Str := NULL;
				end if;
				v_Delimiter2 := v_Delimiter;
			end if;
		END LOOP;
		if v_Delimiter2 IS NULL then
			v_Str := v_Str || ' NULL';
		end if;
		if length(v_Str) > 0 then
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
			v_Str := NULL;
		end if;

		if (v_Links_Count > 0 and v_Nested_Links = 'NO'
		 or v_Link_List_Count > 0)
		-- and p_View_Mode IN ('FORM_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW')
		and p_Empty_Row = 'NO' and p_Data_Format IN ('FORM', 'HTML') then
			if v_Link_List_Count > 0 then 
				v_Parameter_Columns := data_browser_conf.concat_list(v_Parameter_Columns, DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Detail_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_PARENT_ID')) || ' TARGET1');
			end if;
			v_Parameter_Columns := data_browser_conf.concat_list(v_Parameter_Columns, DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Link_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_DETAIL_TABLE,P32_DETAIL_KEY')) || ' TARGET2');
		end if;
		v_From_Clause := Get_Form_View_From_Clause (	
			p_Table_name => v_Table_name,
			p_Unique_Key_Column => v_Unique_Key_Column,
			p_View_Mode => p_View_Mode,
			p_Empty_Row => p_Empty_Row,
			p_Source_Query => p_Source_Query,
			p_Parameter_Columns => v_Parameter_Columns
		);
		dbms_lob.append(v_Stat, v_From_Clause);
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_data_columns_only,p_columns_limit,p_select_columns,p_control_break,p_view_mode,p_edit_mode,p_data_format,p_data_source,p_empty_row,p_report_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_form_page_id,p_form_parameter,p_file_page_id,p_search_field_item,p_search_column_name,p_calc_totals,p_nested_links,p_source_query,p_comments,v_Stat;
        $END
		return v_Stat;
    exception 
      when OTHERS then 
		if data_browser_select.Describe_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Cols_cur;
		end if;
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_table_name,p_unique_key_column,p_data_columns_only,p_columns_limit,p_select_columns,p_control_break,p_view_mode,p_edit_mode,p_data_format,p_data_source,p_empty_row,p_report_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_form_page_id,p_form_parameter,p_file_page_id,p_search_field_item,p_search_column_name,p_calc_totals,p_nested_links,p_source_query,p_comments;
        RAISE;
	end Get_Form_View_Query;


	FUNCTION Get_Query_From_Clause (
		p_Table_Name VARCHAR2,
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Empty_Row VARCHAR2  DEFAULT 'NO',					-- YES, NO
		p_Source_Query CLOB DEFAULT NULL,					-- Passed query for from clause
		p_Parameter_Columns VARCHAR2 DEFAULT NULL,
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- TABLE, NEW_ROWS, COLLECTION, QUERY
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Map_Column_List VARCHAR2 DEFAULT NULL
	) RETURN CLOB
	IS
		v_Table_Name	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Unique_Key_Column	 MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
	BEGIN
		if p_Unique_Key_Column IS NULL then
			SELECT SEARCH_KEY_COLS
			INTO v_Unique_Key_Column
			FROM MVDATA_BROWSER_VIEWS
			WHERE VIEW_NAME = p_Table_Name;
		else
			v_Unique_Key_Column := p_Unique_Key_Column;
		end if;
		if p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then 
			return Get_Imp_Table_From_Clause (
				p_Table_Name => v_Table_Name,
				p_Join_Options => p_Join_Options,
				p_Data_Source => p_Data_Source,
				p_As_Of_Timestamp => p_As_Of_Timestamp,
				p_Map_Column_List => p_Map_Column_List
			);
		else
			return Get_Form_View_From_Clause (	
				p_Table_name => v_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Empty_Row => p_Empty_Row,
				p_Source_Query => p_Source_Query,
				p_Parameter_Columns => p_Parameter_Columns
			);
		end if;
	END Get_Query_From_Clause;

	FUNCTION Get_Form_View_Column_List (	-- internal
		p_Table_Name VARCHAR2,								-- Table Name or View Name of master table
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,			-- Unique Key Column or NULL. Used to build a Link_ID_Expression
		p_Delimiter VARCHAR2 DEFAULT ', ',
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit INTEGER DEFAULT 1000,
		p_Format VARCHAR2 DEFAULT 'NAMES',					-- NAMES, HEADER, ALIGN, ITEM_HELP
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, HISTORY
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Report_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Enable_Sort VARCHAR2 DEFAULT 'NO',				-- YES, NO
		p_Order_by VARCHAR2 DEFAULT NULL,					-- Example : 'LAST_NAME, FIRST_NAME'
		p_Order_Direction VARCHAR2 DEFAULT 'ASC',			-- Example : 'ASC' or 'ASC NULLS LAST' or 'DESC' or 'DESC NULLS LAST'
		p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),		-- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
		p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_File_Page_ID NUMBER DEFAULT 31					-- Page ID of target links to file preview in View_Mode FORM_VIEW
	) RETURN CLOB
	IS
		v_Table_Name		MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Stat				CLOB;
		v_Str				VARCHAR2(32767);
		v_Describe_Cols_md5 VARCHAR2(300);
		v_Calc_Totals		VARCHAR2(10) := 'NO';
		v_Nested_Links		VARCHAR2(10) := 'NO';
		v_is_cached			VARCHAR2(10);
		v_Delimiter			VARCHAR2(10);
		v_Select_Columns	VARCHAR2(32767);
		v_Parent_Key_Visible VARCHAR2(10);
	BEGIN
		v_Select_Columns := FN_Terminate_List(p_Select_Columns);
		v_Parent_Key_Visible := FN_Parent_Key_Visible (p_Parent_Key_Visible, p_Edit_Mode, p_View_Mode, p_Data_Format, p_Select_Columns);
		data_browser_conf.Set_Current_Data_Format(p_Data_Format);
		v_Describe_Cols_md5 := wwv_flow_item.md5 (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Edit_Mode, p_Data_Format, 
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column,
												p_Link_Page_ID, p_Detail_Page_ID, v_Calc_Totals);
		v_is_cached := case when g_Describe_Cols_md5 != v_Describe_Cols_md5 then 'load' else 'cached!' end;
		if v_is_cached != 'cached!' then
			OPEN data_browser_select.Describe_Cols_cur (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Edit_Mode, p_Data_Format, 
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column,
												p_Link_Page_ID, p_Detail_Page_ID, v_Calc_Totals);
			FETCH data_browser_select.Describe_Cols_cur BULK COLLECT INTO g_Describe_Cols_tab;
			CLOSE data_browser_select.Describe_Cols_cur;
			g_Describe_Cols_md5 := v_Describe_Cols_md5;
		end if;
		dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		FOR ind IN 1 .. g_Describe_Cols_tab.COUNT LOOP
			if (p_Edit_Mode = 'YES'			-- if Edit single record or not hidden
			  and p_Report_Mode = 'NO'		-- in Edit single record mode, hidden (key) columns have no header
			  or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE != 'HIDDEN')
			and FN_Show_Parent_Key(v_Parent_Key_Visible, p_Parent_Name, p_Parent_Key_Column, g_Describe_Cols_tab(ind))
			and FN_Show_Row_Selector(p_Data_Format, p_Edit_Mode, p_Report_Mode, p_View_Mode, p_Data_Columns_Only, g_Describe_Cols_tab(ind).COLUMN_NAME)
			and FN_Display_In_Report(p_Data_Format, p_Report_Mode, p_View_Mode, g_Describe_Cols_tab(ind), v_Select_Columns) 
			and g_Describe_Cols_tab(ind).REPORT_COLUMN_ID <= p_Columns_Limit
			then
				v_Str := v_Str
				|| v_Delimiter
				|| case p_Format
						when 'HEADER' then
							case when p_Report_Mode = 'YES'
								and p_Enable_Sort = 'YES'
								and p_Data_Format = 'FORM'
								and (g_Describe_Cols_tab(ind).COLUMN_ID > 0 or p_View_Mode = 'HISTORY')
								and dbms_lob.getlength(v_Stat) < 3000 then
									-- the space for column headers is limited to 4000 bytes
									data_browser_select.Get_Sort_Link_Html(
										p_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME,
										p_Column_Header => g_Describe_Cols_tab(ind).COLUMN_HEADER,
										p_Order_by => utl_url.unescape(p_Order_by),
										p_Order_Direction => p_Order_Direction
									)
								else
									g_Describe_Cols_tab(ind).COLUMN_HEADER
							end
						when 'ITEM_HELP' then
							-- the column headers can not be rendered when the output is too large
							data_browser_select.Get_Form_Required_Html (
								p_Is_Required  => g_Describe_Cols_tab(ind).REQUIRED,
								p_Check_Unique => g_Describe_Cols_tab(ind).CHECK_UNIQUE, 
								p_Display_Key_Column => g_Describe_Cols_tab(ind).IS_DISP_KEY_COLUMN )
							|| data_browser_select.Get_Form_Help_Link_Html (
									p_Column_Id => g_Describe_Cols_tab(ind).COLUMN_ID,
									p_R_View_Name => v_Table_Name,
									p_R_Column_Name => g_Describe_Cols_tab(ind).COLUMN_NAME,
									p_Column_Header => g_Describe_Cols_tab(ind).COLUMN_HEADER,
									p_Comments => g_Describe_Cols_tab(ind).COMMENTS
								)
							|| case when g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE = 'ROW_SELECTOR' then
								' <input type="checkbox" onclick="$f_CheckFirstColumn(this)" class="t-Button--helpButton" />'
							end
						when 'NAMES' then g_Describe_Cols_tab(ind).COLUMN_NAME
						when 'ALIGN' then
							case when p_Edit_Mode = 'NO' or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'ORDERING_MOVER', 'FILE_BROWSER') then
								g_Describe_Cols_tab(ind).COLUMN_ALIGN
							else
								'LEFT'
							end
				end;
				if length(v_Str) > 1000 then
					dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
					v_Str := NULL;
				end if;
				v_Delimiter := p_Delimiter;
			end if;
		END LOOP;
		if v_Str IS NOT NULL then
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;

        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_delimiter,p_data_columns_only,p_select_columns,p_columns_limit,p_format,p_view_mode,p_edit_mode,p_Data_Format,p_report_mode,p_enable_sort,p_order_by,p_order_direction,p_parent_name,p_parent_key_column,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_file_page_id,v_Stat;
        $END
        return v_Stat;
    exception 
      when OTHERS then 
		if data_browser_select.Describe_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Cols_cur;
		end if;
        EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
        USING p_table_name,p_unique_key_column,p_delimiter,p_data_columns_only,p_select_columns,p_columns_limit,p_format,p_view_mode,p_edit_mode,p_report_mode,p_enable_sort,p_order_by,p_order_direction,p_parent_name,p_parent_key_column,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_file_page_id;
        RAISE;
	END Get_Form_View_Column_List;

	FUNCTION Get_View_Column_Cursor (	-- internal
		p_Table_Name VARCHAR2,								-- Table Name or View Name
		p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Join_Options VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Edit_Mode VARCHAR2 DEFAULT 'NO',					-- YES, NO
		p_Data_Format VARCHAR2 DEFAULT FN_Current_Data_Format,	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
		p_Use_Group_Separator  VARCHAR2 DEFAULT NULL,		-- Y,N; use G in number format mask
		p_Report_Mode VARCHAR2 DEFAULT 'NO',				-- YES, NO, ALL, If YES, none standard columns are excluded from the generated column list
		p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
		p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
		p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),		-- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
		p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_File_Page_ID NUMBER DEFAULT 31					-- Page ID of target links to file preview in View_Mode FORM_VIEW
	) RETURN data_browser_conf.tab_record_view PIPELINED
	IS
	PRAGMA UDF;
		v_Table_Name	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Describe_Cols_md5 VARCHAR2(300);
		v_is_cached			VARCHAR2(10);
		v_Map_Count			PLS_INTEGER := 0;
		v_Select_Columns	VARCHAR2(32767);
		v_Parent_Key_Visible VARCHAR2(10);
		v_Calc_Totals	VARCHAR2(10) := 'NO';
		v_Nested_Links		VARCHAR2(10) := 'NO';
		v_Column_Limit		PLS_INTEGER := p_Columns_Limit;
	BEGIN
		v_Select_Columns := FN_Terminate_List(p_Select_Columns);
		v_Parent_Key_Visible := FN_Parent_Key_Visible (p_Parent_Key_Visible, p_Edit_Mode, p_View_Mode, p_Data_Format, p_Select_Columns);
		data_browser_conf.Set_Current_Data_Format(p_Data_Format);
		if p_View_Mode IN ('FORM_VIEW', 'HISTORY', 'RECORD_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW') then
			v_Describe_Cols_md5 := wwv_flow_item.md5 (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Edit_Mode, p_Data_Format,
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column,
												p_Link_Page_ID, p_Detail_Page_ID, v_Calc_Totals);
			v_is_cached := case when g_Describe_Cols_md5 != v_Describe_Cols_md5 then 'load' else 'cached!' end;
			if v_is_cached != 'cached!' then
				OPEN data_browser_select.Describe_Cols_cur (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Edit_Mode, p_Data_Format,
												v_Select_Columns, p_Parent_Name, p_Parent_Key_Column,
												p_Link_Page_ID, p_Detail_Page_ID, v_Calc_Totals);
				FETCH data_browser_select.Describe_Cols_cur BULK COLLECT INTO g_Describe_Cols_tab;
				CLOSE data_browser_select.Describe_Cols_cur;
				g_Describe_Cols_md5 := v_Describe_Cols_md5;
			end if;
			FOR ind IN 1 .. g_Describe_Cols_tab.COUNT
			LOOP
				if (p_Edit_Mode = 'YES' or g_Describe_Cols_tab(ind).COLUMN_EXPR_TYPE != 'HIDDEN')	-- in Edit mode hidden (key) columns are included
				and FN_Show_Parent_Key(v_Parent_Key_Visible, p_Parent_Name, p_Parent_Key_Column, g_Describe_Cols_tab(ind))
				and FN_Show_Row_Selector(p_Data_Format, p_Edit_Mode, p_Report_Mode, p_View_Mode, p_Data_Columns_Only, g_Describe_Cols_tab(ind).COLUMN_NAME)
				and FN_Display_In_Report(p_Data_Format, p_Report_Mode, p_View_Mode, g_Describe_Cols_tab(ind), v_Select_Columns) 
				and g_Describe_Cols_tab(ind).REPORT_COLUMN_ID <= v_Column_Limit
				then
					pipe row (g_Describe_Cols_tab(ind));
				end if;
			END LOOP;
		elsif p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			v_Describe_Cols_md5 := wwv_flow_item.md5 (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Data_Format, p_Use_Group_Separator,
													v_Select_Columns, p_Parent_Name, p_Parent_Key_Column, v_Parent_Key_Visible, p_Join_Options);
			v_is_cached := case when g_Describe_Cols_md5 != v_Describe_Cols_md5 then 'load' else 'cached!' end;
			if v_is_cached != 'cached!' then
				OPEN data_browser_select.Describe_Imp_Cols_cur (v_Table_Name, p_Unique_Key_Column, p_View_Mode, p_Data_Format, p_Use_Group_Separator,
																v_Select_Columns, p_Parent_Name, p_Parent_Key_Column, v_Parent_Key_Visible, p_Join_Options);
				FETCH data_browser_select.Describe_Imp_Cols_cur BULK COLLECT INTO g_Describe_Cols_tab;
				CLOSE data_browser_select.Describe_Imp_Cols_cur;
				g_Describe_Cols_md5 := v_Describe_Cols_md5;
			end if;
			v_Column_Limit := case when p_View_Mode = 'IMPORT_VIEW' 
				then LEAST(data_browser_conf.Get_Collection_Columns_Limit, p_Columns_Limit)
				else p_Columns_Limit
			end;
			FOR ind IN 1 .. g_Describe_Cols_tab.COUNT
			LOOP
				if FN_Show_Row_Selector(p_Data_Format, p_Edit_Mode, p_Report_Mode, p_View_Mode, p_Data_Columns_Only, g_Describe_Cols_tab(ind).COLUMN_NAME)
				and FN_Has_Collections_Adress(p_View_Mode, g_Describe_Cols_tab(ind))
				and FN_Display_In_Report(p_Data_Format, p_Report_Mode, p_View_Mode, g_Describe_Cols_tab(ind), v_Select_Columns) 
				and g_Describe_Cols_tab(ind).REPORT_COLUMN_ID <= v_Column_Limit
				then
					pipe row (g_Describe_Cols_tab(ind));
				end if;
			END LOOP;
		else
			return;
		end if;
        ----
        $IF data_browser_conf.g_debug $THEN
            EXECUTE IMMEDIATE api_trace.Dyn_Log_Function_Call
            USING p_table_name,p_unique_key_column,p_columns_limit,p_data_columns_only,p_select_columns,p_join_options,p_view_mode,p_edit_mode,p_data_format,p_Use_Group_Separator,p_report_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_file_page_id,g_Describe_Cols_tab.COUNT;
        $END
	 exception
       when NO_DATA_NEEDED then
		if data_browser_select.Describe_Imp_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Imp_Cols_cur;
		end if;
		if data_browser_select.Describe_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Cols_cur;
		end if;
	  when OTHERS then 
		if data_browser_select.Describe_Imp_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Imp_Cols_cur;
		end if;
		if data_browser_select.Describe_Cols_cur%ISOPEN then
			CLOSE data_browser_select.Describe_Cols_cur;
		end if;
		EXECUTE IMMEDIATE api_trace.Dyn_Log_Exception
		USING p_table_name,p_unique_key_column,p_columns_limit,p_data_columns_only,p_select_columns,p_join_options,p_view_mode,p_edit_mode,p_data_format,p_Use_Group_Separator,p_report_mode,p_parent_name,p_parent_key_column,p_parent_key_visible,p_link_page_id,p_link_parameter,p_detail_page_id,p_detail_parameter,p_file_page_id;
		RAISE;
	END Get_View_Column_Cursor;

end data_browser_select;
/
