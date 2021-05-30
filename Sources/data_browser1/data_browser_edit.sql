/*
Copyright 2019 Dirk Strack, Strack Software Development

All Rights Reserved
Unauthorized copying of this file, via any medium is strictly prohibited
Proprietary and confidential
Written by Dirk Strack <dirk_strack@yahoo.de>, Feb 2019
*/
 

CREATE OR REPLACE PACKAGE BODY data_browser_edit
is
	FUNCTION NL(p_Indent PLS_INTEGER) RETURN VARCHAR2	-- newline plus indent for code generation
	is begin return data_browser_conf.NL(p_Indent);
	end;

	FUNCTION PA(p_Param_Name VARCHAR2) RETURN VARCHAR2	-- remove parameter names for compact code generation
	is
	begin
		return case when data_browser_conf.NL(1) = chr(10)
			then case when INSTR(p_Param_Name, ',') > 0 then ',' else '' end
			else p_Param_Name
		end;
	end;
	
	FUNCTION CM(p_Param_Name VARCHAR2) RETURN VARCHAR2	-- remove comments for compact code generation
	is
	begin
		return case when data_browser_conf.NL(1) = chr(10)
			then NULL
			else ' ' || p_Param_Name || ' '
		end;
	end;

	---------------------------------------------------------------------------
	-- Edit form --

	FUNCTION Enquote_Literal ( p_Text VARCHAR2 )
	RETURN VARCHAR2 DETERMINISTIC
	IS
		v_Quote CONSTANT VARCHAR2(1) := '''';
	BEGIN
		RETURN v_Quote || REPLACE(p_Text, v_Quote, v_Quote||v_Quote) || v_Quote ;
	END;

	FUNCTION Get_Current_Data_Source(
		p_Import_Mode VARCHAR2 DEFAULT 'NO',
		p_Add_Rows  VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2
	IS
		v_Probe_Cnt PLS_INTEGER;
	BEGIN
		v_Probe_Cnt := FN_Get_Apex_Item_Row_Count(
			p_Idx => data_browser_conf.Get_MD5_Column_Index,
			p_Row_Factor => 1,
			p_Row_Offset => 1
		);
		RETURN case
			when v_Probe_Cnt > 0 then 'MEMORY'
			when p_Import_Mode = 'YES' then 'COLLECTION'
			when p_Add_Rows = 'YES' then 'NEW_ROWS'
			else 'TABLE'
		end;
	END;

	FUNCTION FN_Change_Tracked_Column (
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return case when p_Column_Expr_Type NOT IN 
		('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then 'YES' else 'NO' end;
	end;

	FUNCTION FN_Change_Check_Use_Column (
		p_Column_Expr_Type VARCHAR2
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return case when p_Column_Expr_Type IN 
		('POPUPKEY_FROM_LOV', 'SELECT_LIST_FROM_QUERY', 'SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER') then 'YES' else 'NO' end;
	end;


	FUNCTION Get_Apex_Item_Cell_ID (
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number	NUMBER DEFAULT 1,
    	p_Data_Source 	VARCHAR2 DEFAULT 'TABLE',
    	p_Item_Type		VARCHAR2 DEFAULT 'TEXT'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Item_Char		VARCHAR2(20);
		v_Row_Offset 	NUMBER;
	begin
		v_Row_Offset := p_Row_Factor * (p_Row_Number - 1) + p_Row_Offset;
		-- v_Item_Char  := case when p_Data_Source = 'NEW_ROWS' then 'a' else 'f' end;
		-- return chr(ascii(v_Item_Char) + p_Row_Offset - 1) || LPAD(p_Idx, 2, '0');
		-- problem - function Form_Validation_Process can not reproduce the item char a or f
		v_Item_Char  := case 
			when p_Data_Source = 'NEW_ROWS' then 'a' 
			when p_Item_Type = 'POPUP_FROM_LOV' then null
			else 'f' end;
		return 'f' || LPAD(p_Idx, 2, '0') || chr(ascii(v_Item_Char) + p_Row_Offset - 1);
	end;

	FUNCTION add_error_call (
		p_Column_Name VARCHAR2,
		p_Apex_Item_Cell_Id VARCHAR2,
		p_Message VARCHAR2,
		p_Column_Header VARCHAR2,
		p1 VARCHAR2 DEFAULT NULL,
		p_Class VARCHAR2 DEFAULT 'DATA' -- DATA, UNIQUENESS, LOOKUP
	) RETURN VARCHAR2 DETERMINISTIC
	IS
	PRAGMA UDF;
	BEGIN
		return 'add_error(' || Enquote_Literal(p_Column_Name) ||
			', ' || Enquote_Literal(p_Apex_Item_Cell_Id) ||
			', apex_lang.lang('
		   || Enquote_Literal (p_Message) || ', '
		   || Enquote_Literal (p_Column_Header)
		   || case when p1 IS NOT NULL then ', ' || p1 end
		   || ')' || 
			', ' || Enquote_Literal(p_Class) ||
			');';
	END add_error_call;

	FUNCTION declare_error_call (
		p_Table_Name VARCHAR2,
		p_Key_Column VARCHAR2
	) RETURN VARCHAR2
	is 
	begin 
		return 'procedure add_error (p_Column_Name VARCHAR2, p_Apex_Item_Cell_Id VARCHAR2, p_Message VARCHAR2, p_Class VARCHAR2 )' || NL(8) ||
		'is ' || NL(8) ||
		'begin' || NL(12) ||
			'apex_collection.add_member(p_collection_name => v_Err_Collection' || NL(12) ||
			', p_c001 => ' || Enquote_Literal(p_Table_Name) ||', p_c002 => ' || Enquote_Literal(p_Key_Column) || NL(12) ||
			', p_c003 => v_Key_Value, p_c004 => p_Column_Name, p_c005 => p_Apex_Item_Cell_Id' || NL(12) ||
			', p_c006 => case when length(p_Apex_Item_Cell_Id) = 3 then LPAD(p_Row-1, 4, ''0'') else p_Row end' || NL(12) ||-- special case for POPUP_FROM_QUERY
			', p_c007 => p_Message, p_c008 => p_Class, p_c009 => SQLCODE);' || NL(8) ||
		'end;' || NL(4);
	end declare_error_call;
	
	PROCEDURE Form_Validation_Process (
		p_Table_name VARCHAR2,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE' 			-- TABLE, COLLECTION, NEW_ROWS
	)
	IS
		v_Item_Char		VARCHAR2(20);
		v_Message		VARCHAR2(32767);
		v_Char_Offset	CONSTANT PLS_INTEGER := ascii('f') - ascii('a');
	BEGIN
		owa_util.mime_header('text/plain', FALSE );
		htp.p('Cache-Control: no-cache');
		htp.p('Pragma: no-cache');
		owa_util.http_header_close;
		if p_Data_Source IN ('TABLE', 'NEW_ROWS', 'COLLECTION') then
			for c_cur IN (
					SELECT C005 Item_Cell_Id, C006 line_no ,
							C007 message
					FROM APEX_COLLECTIONS
					WHERE COLLECTION_NAME IN (data_browser_conf.Get_Validation_Collection, data_browser_conf.Get_Lookup_Collection)
					AND C001 = p_Table_name
			) loop
				if p_Data_Source = 'NEW_ROWS' then -- the first x new rows have a postfix base char 'a', table rows postfix base char 'f'
					if c_cur.line_no <= data_browser_conf.Get_New_Rows_Default then 
						v_Item_Char := substr(c_cur.Item_Cell_Id, 1, 3)
							|| chr(ascii(substr(c_cur.Item_Cell_Id, 4, 1)) - v_Char_Offset)
							|| '_' || c_cur.line_no;
					else 
						v_Item_Char := c_cur.Item_Cell_Id || '_' || (to_number(c_cur.line_no) - data_browser_conf.Get_New_Rows_Default);
					end if;
				else -- TABLE
					v_Item_Char := c_cur.Item_Cell_Id || '_' || c_cur.line_no;
				end if;
				v_Message := case when INSTR(c_cur.message,chr(10)) > 0  
					then SUBSTR(c_cur.message,1, INSTR(c_cur.message,chr(10))-1)
					else c_cur.message end;
				htp.prn(v_Item_Char || chr(9) || htf.escape_sc(v_Message) || chr(10));
			end loop;
		end if;
		if p_Data_Source = 'COLLECTION' then
			for c_cur IN (
					SELECT C005 || '_' || C006 Item_Cell_Id,
							C007 message
					FROM APEX_COLLECTIONS
					WHERE COLLECTION_NAME IN (data_browser_conf.Get_Import_Error_Collection)
					AND C001 = p_Table_name
					AND C008 IN ('DATA', 'LOOKUP')
			) loop
				v_Message := case when INSTR(c_cur.message,chr(10)) > 0  
					then SUBSTR(c_cur.message,1, INSTR(c_cur.message,chr(10))-1)
					else c_cur.message end;
				htp.prn(c_cur.Item_Cell_Id || chr(9) || htf.escape_sc(v_Message) || chr(10));
			end loop;
		end if;
	end Form_Validation_Process;

	FUNCTION Get_Expression_Columns (p_Expr VARCHAR2) RETURN VARCHAR2
	is
		v_Cnt PLS_INTEGER := 1;
		v_Name VARCHAR2(128);
		v_Col_Names apex_t_varchar2 := apex_t_varchar2();
	begin
		loop
			v_Name := REGEXP_SUBSTR(p_Expr, '"([^"]+)"', 1, v_Cnt, 'c', 1 );
			exit when v_Name IS NULL;
			v_Col_Names.extend;
			v_Col_Names(v_Col_Names.count) := v_Name;
			v_Cnt := v_Cnt + 1;
		end loop;
		return apex_string.join(v_Col_Names, ':');
	end Get_Expression_Columns;

	FUNCTION Validate_Form_Checks_PL_SQL (
		p_Table_name VARCHAR2,
		p_Key_Column	VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, COLLECTION, MEMORY
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'NO'
	) RETURN CLOB
	IS
		v_Unique_Key_Column  		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Search_Key_Cols  			MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Has_Scalar_Key			MVDATA_BROWSER_VIEWS.HAS_SCALAR_KEY%TYPE;
		v_Key_Cols_Count			MVDATA_BROWSER_VIEWS.KEY_COLS_COUNT%TYPE;
		v_Primary_Key_Col_Type 		VARCHAR2(512);
        v_Changed_Check_Condition	CLOB;
        v_Changed_Check_Plsql		CLOB;
    	v_Build_MD5					CONSTANT BOOLEAN := p_Data_Source IN ('NEW_ROWS', 'TABLE', 'MEMORY');
		v_Init_Key_Stat				VARCHAR2(1024);
		v_Key_Column				VARCHAR2(1024);
		v_Key_Value_call			VARCHAR2(1024);
		v_Key_Input_ID				PLS_INTEGER;
		v_Key_Input_Type			VARCHAR2(10);
        v_Result_PLSQL				CLOB;
        v_Result_Stat				CLOB;
        v_Use_Group_Separator 		CONSTANT VARCHAR2(1) := 'Y';
		v_use_NLS_params 			CONSTANT VARCHAR2(1) := 'Y'; -- case when p_Data_Source = 'COLLECTION' then 'Y' else 'N' end
		v_Apex_Item_Rows_Call 		VARCHAR2(1024);
    	v_Procedure_Name 			VARCHAR2(50);
    	v_Procedure_Name2 			VARCHAR2(50);
	BEGIN
		begin 
			SELECT T.SEARCH_KEY_COLS, HAS_SCALAR_KEY, KEY_COLS_COUNT
			INTO v_Search_Key_Cols, v_Has_Scalar_Key, v_Key_Cols_Count
			FROM MVDATA_BROWSER_VIEWS T
			WHERE T.VIEW_NAME = p_Table_name;
		exception when NO_DATA_FOUND then
			return NULL;
		end;
		
		v_Primary_Key_Col_Type := case when v_Key_Cols_Count = 1 then 
				data_browser_conf.Enquote_Name_Required(p_Table_name) || '.' 
				|| data_browser_conf.Enquote_Name_Required(v_Search_Key_Cols) 
				|| '%TYPE;'
			else 'VARCHAR2(1024);' end;
    	v_Unique_Key_Column := NVL(p_Key_Column, v_Search_Key_Cols);

        if v_Build_MD5 then
			data_browser_edit.Get_Form_Changed_Check (
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => v_Search_Key_Cols,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Data_Source => p_Data_Source,
				p_Report_Mode => p_Report_Mode,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Use_Empty_Columns => p_Use_Empty_Columns,
				p_Changed_Check_Condition => v_Changed_Check_Condition,
				p_Changed_Check_Plsql => v_Changed_Check_Plsql
			);
        end if;
		v_Key_Column	:= data_browser_conf.Get_Link_ID_Expression(
			p_Unique_Key_Column=> v_Search_Key_Cols, p_Table_Alias=> 'A', p_View_Mode=> p_View_Mode);
		v_Init_Key_Stat := case 
			when p_Data_Source = 'COLLECTION' then
				'v_Key_Value := null;' || chr(10)
			when p_Report_Mode = 'YES' then 
				'v_Key_Value := ' || data_browser_conf.Get_Link_ID_Expr || ' (p_Row);' || chr(10)
			else 
				'v_Key_Value := p_Key_Value;' || chr(10)
		end;
		if p_Report_Mode = 'YES' then 
			v_Key_Value_call := data_browser_conf.Get_Link_ID_Expr || ' (p_Row)';
		end if;
    	dbms_lob.createtemporary(v_Result_PLSQL, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Result_Stat, true, dbms_lob.call);
		for c_cur IN ( -- single column checks
			WITH EDIT_Q AS (
				SELECT B.R_VIEW_NAME, B.R_COLUMN_NAME, B.COLUMN_NAME, B.REF_COLUMN_NAME, B.COLUMN_HEADER, D.CHECK_CONDITION,
					B.REQUIRED, B.NULLABLE, B.CHECK_UNIQUE, B.FORMAT_MASK, B.DATA_TYPE, B.DATA_SCALE, B.DATA_DEFAULT, B.TABLE_ALIAS,
					B.IS_PRIMARY_KEY, B.IS_SEARCH_KEY, B.IS_VIRTUAL_COLUMN, B.APEX_ITEM_IDX, B.COLUMN_EXPR_TYPE, B.ROW_FACTOR, B.ROW_OFFSET, 
					APEX_ITEM_REF, INPUT_ID,  SUBSTR(INPUT_ID, 1, 1)  S_REF_TYPE, -- C,N
					IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN,
					case when p_Data_Source = 'COLLECTION' then
						'p_cur.' || INPUT_ID
					else
						data_browser_edit.Get_Apex_Item_Call (
							p_Idx 			=> B.APEX_ITEM_IDX,
							p_Row_Factor	=> B.ROW_FACTOR,
							p_Row_Offset	=> B.ROW_OFFSET,
							p_Row_Number	=> 'p_Row'
						)
					end APEX_ITEM_CALL
				FROM TABLE (data_browser_edit.Get_Form_Edit_Cursor (
						p_Table_Name => p_Table_name,
						p_Unique_Key_Column => v_Search_Key_Cols,
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => p_Report_Mode,
						p_Join_Options => p_Join_Options,
						p_Data_Source => p_Data_Source,
						p_Parent_Name => p_Parent_Name,
						p_Parent_Key_Column => p_Parent_Key_Column,
						p_Parent_Key_Visible => p_Parent_Key_Visible,
						p_Parent_Key_Item => p_Parent_Key_Item
					)) B
					LEFT OUTER JOIN MVDATA_BROWSER_CHECKS_DEFS D ON D.VIEW_NAME = B.REF_VIEW_NAME AND D.COLUMN_NAME = B.REF_COLUMN_NAME AND D.CONS_COLS_COUNT = 1				
			), REFERENCES_Q AS (
				SELECT A.*,
					case when DATA_DEFAULT IS NOT NULL -- unique check on virtual column
						AND IS_VIRTUAL_COLUMN = 'Y'
						AND CHECK_UNIQUE = 'Y' 
						AND TABLE_ALIAS = 'A' then 
						/*
						-- this construct is crashing the server process.
						( SELECT COLUMN_VALUE FROM TABLE (data_browser_conf.replace_agg(
							CURSOR(SELECT A.DATA_DEFAULT, DBMS_ASSERT.ENQUOTE_NAME(B.COLUMN_NAME), B.APEX_ITEM_CALL
								FROM table(apex_string.split(data_browser_edit.Get_Expression_Columns(A.DATA_DEFAULT),':')) A 
								JOIN EDIT_Q B ON A.COLUMN_VALUE = B.REF_COLUMN_NAME
							)
						)))*/
						( SELECT MAX(REPLACE(A.DATA_DEFAULT, DBMS_ASSERT.ENQUOTE_NAME(B.COLUMN_NAME), B.APEX_ITEM_CALL))
							FROM table(apex_string.split(data_browser_edit.Get_Expression_Columns(A.DATA_DEFAULT),':')) A 
							JOIN EDIT_Q B ON A.COLUMN_VALUE = B.REF_COLUMN_NAME
						)
					end APEX_ITEM_COLUMNS 
				FROM EDIT_Q	A
			)
			select R_VIEW_NAME, R_COLUMN_NAME, COLUMN_NAME,
				COLUMN_HEADER, CHECK_CONDITION,
				REQUIRED, NULLABLE, CHECK_UNIQUE, FORMAT_MASK, DATA_TYPE, DATA_SCALE,
				APEX_ITEM_REF, APEX_ITEM_IDX, COLUMN_EXPR_TYPE, ROW_FACTOR, ROW_OFFSET, 
				APEX_ITEM_CALL, APEX_ITEM_COLUMNS, S_REF_TYPE,
				data_browser_edit.Get_Apex_Item_Cell_ID (
					p_Idx 			=> APEX_ITEM_IDX,
					p_Row_Factor	=> ROW_FACTOR,
					p_Row_Offset	=> ROW_OFFSET,
					p_Row_Number 	=> 1,
					p_Data_Source 	=> p_Data_Source,
					p_Item_Type 	=> COLUMN_EXPR_TYPE
				) APEX_ITEM_CELL_ID,
				IS_PRIMARY_KEY, IS_SEARCH_KEY, INPUT_ID,
				case when CHECK_UNIQUE = 'Y' and TABLE_ALIAS = 'A' 
				and NOT(v_Has_Scalar_Key = 'NO' and p_Data_Source = 'COLLECTION') then -- only lookup Scalar Primary Key
					data_browser_conf.Enquote_Name_Required(R_VIEW_NAME)
					|| ' A WHERE '|| DBMS_ASSERT.ENQUOTE_NAME(R_COLUMN_NAME)
					|| ' = '
                    || case when T.APEX_ITEM_COLUMNS IS NOT NULL then 
                    	T.APEX_ITEM_COLUMNS
					else
						data_browser_conf.Get_Char_to_Type_Expr (
							p_Element 		=> APEX_ITEM_CALL,
							p_Element_Type	=> S_REF_TYPE,
							p_Data_Source	=> p_Data_Source,
							p_DATA_TYPE 	=> DATA_TYPE,
							p_DATA_SCALE 	=> DATA_SCALE,
							p_FORMAT_MASK 	=> FORMAT_MASK,
							p_USE_GROUP_SEPARATOR => v_Use_Group_Separator,
							p_use_NLS_params => v_use_NLS_params
						)
					end
				end UNIQUE_QUERY,
				case when CHECK_CONDITION IS NOT NULL -- and CONSTRAINT_NAME != 'AUTOMATICALLY'
					and T.APEX_ITEM_COLUMNS IS NULL then
					'(SELECT '
					|| data_browser_conf.Get_Char_to_Type_Expr (
						p_Element 		=> APEX_ITEM_CALL,
						p_Element_Type	=> S_REF_TYPE,
						p_Data_Source	=> p_Data_Source,
						p_DATA_TYPE 	=> DATA_TYPE,
						p_DATA_SCALE 	=> DATA_SCALE,
						p_FORMAT_MASK 	=> FORMAT_MASK,
						p_USE_GROUP_SEPARATOR => v_Use_Group_Separator,
						p_use_NLS_params => v_use_NLS_params
					)
					|| ' ' || REF_COLUMN_NAME || ' FROM DUAL) WHERE ' 
					|| case when p_Data_Source = 'COLLECTION' and IS_NUMBER_YES_NO_COLUMN = 'Y' then 
							data_browser_conf.Get_Yes_No_Check('NUMBER', R_COLUMN_NAME)
						when p_Data_Source = 'COLLECTION' and IS_CHAR_YES_NO_COLUMN = 'Y' then 
							data_browser_conf.Get_Yes_No_Check('CHAR', R_COLUMN_NAME)
						else CHECK_CONDITION
					end
				end CHECK_QUERY
			FROM REFERENCES_Q T 
			WHERE APEX_ITEM_IDX != data_browser_conf.Get_MD5_Column_Index
			AND (APEX_ITEM_REF IS NOT NULL 
				AND NOT(INPUT_ID IS NULL and p_Data_Source = 'COLLECTION') 
				AND data_browser_edit.FN_Change_Tracked_Column(COLUMN_EXPR_TYPE) = 'YES'
				AND (p_Use_Empty_Columns = 'YES' OR data_browser_edit.Check_Item_Ref (APEX_ITEM_REF, COLUMN_NAME) != 'UNKNOWN' )
			) OR (APEX_ITEM_COLUMNS IS NOT NULL -- unique check on virtual column
			)
		) loop
			if v_Apex_Item_Rows_Call IS NULL then
				v_Apex_Item_Rows_Call := data_browser_edit.Get_Apex_Item_Rows_Call(
						p_Idx 			=> c_cur.APEX_ITEM_IDX,
						p_Row_Factor	=> c_cur.ROW_FACTOR,
						p_Row_Offset	=> c_cur.ROW_OFFSET
				);
			end if;
			if c_cur.IS_SEARCH_KEY = 'Y' and (c_cur.R_COLUMN_NAME = v_Search_Key_Cols OR v_Search_Key_Cols IS NULL) then
				v_Key_Value_call := c_cur.APEX_ITEM_CALL;
				v_Key_Input_ID	 := LTRIM(SUBSTR(c_cur.INPUT_ID, 2), '0');
				v_Key_Input_Type := SUBSTR(c_cur.INPUT_ID, 1, 1);
				v_Init_Key_Stat := 'v_Key_Value := ' 
					-- || c_cur.APEX_ITEM_CALL 
					||  data_browser_conf.Get_Char_to_Type_Expr (
						p_Element 		=>  c_cur.APEX_ITEM_CALL,
						p_Element_Type	=>  c_cur.S_REF_TYPE,
						p_Data_Source	=>  p_Data_Source,
						p_DATA_TYPE 	=>  c_cur.DATA_TYPE,
						p_DATA_SCALE 	=>  c_cur.DATA_SCALE,
						p_FORMAT_MASK 	=>  c_cur.FORMAT_MASK,
						p_USE_GROUP_SEPARATOR => v_Use_Group_Separator,
						p_use_NLS_params => v_use_NLS_params
					)
					|| ';' || chr(10);
			elsif c_cur.UNIQUE_QUERY IS NOT NULL OR c_cur.CHECK_QUERY IS NOT NULL then
				if c_cur.APEX_ITEM_COLUMNS IS NULL then 
					dbms_lob.append (v_Result_Stat,
						NL(8) ||
						'if ' || c_cur.APEX_ITEM_CALL || ' IS NOT NULL then' || NL(12)
						|| 'begin'
						--------------------------------------------------------------------------------------------
					);
				end if;
				if c_cur.UNIQUE_QUERY IS NOT NULL then
					if p_Data_Source IN ('TABLE', 'NEW_ROWS', 'MEMORY' ) then
						dbms_lob.append (v_Result_Stat,
							data_browser_edit.CM(' /* UK-Check ' || c_cur.R_VIEW_NAME || '(' || c_cur.R_COLUMN_NAME || ') */ ') || 
							NL(16) ||
							'SELECT COUNT(*) INTO v_Result FROM ' || c_cur.UNIQUE_QUERY ||
							' AND (' || v_Key_Column || ' != v_Key_Value OR v_Key_Value IS NULL);' || NL(16) ||
							'if v_Result > 0 then' || NL(20) ||
								add_error_call (
									p_Column_Name => c_cur.COLUMN_NAME,
									p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
									p_Message => '"%0" - Value is not unique.',
									p_Column_Header => c_cur.COLUMN_HEADER,
									p_Class => 'UNIQUENESS'
								) || NL(16) ||
							'end if;'
						);
					elsif p_Data_Source = 'COLLECTION' then
						dbms_lob.append (v_Result_Stat,
							data_browser_edit.CM(' /* UK-Lookup ' || c_cur.R_VIEW_NAME || '(' || c_cur.R_COLUMN_NAME || ') */ ') || 
							NL(16) ||
							'SELECT MAX(' || v_Key_Column || ') ' || NL(16) ||
							'INTO v_Key_Value ' || NL(16) ||
							'FROM ' || c_cur.UNIQUE_QUERY || ';' || NL(16) ||
							'if v_Key_Value IS NOT NULL then' || NL(20) ||
								add_error_call (
									p_Column_Name => c_cur.COLUMN_NAME,
									p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
									p_Message => '"%0" - Unique value exists.',
									p_Column_Header => c_cur.COLUMN_HEADER,
									p_Class => 'UNIQUENESS'
								)
								||  -- register the found id as primary key
								case when v_Key_Input_ID IS NOT NULL then
									NL(20) ||
									'apex_collection.update_member_attribute(p_collection_name => v_Data_Collection, p_seq => p_Row, p_attr_number => ' 
									|| v_Key_Input_ID 
									|| case when v_Key_Input_Type = 'N' then 
										', p_number_value => v_Key_Value);'
									else
										', p_attr_value => v_Key_Value);'
									end
								end
								|| NL(16) ||
							'end if;'
						);
					end if;
				end if;
				if c_cur.CHECK_QUERY IS NOT NULL then
					dbms_lob.append (v_Result_Stat,
						NL(16) ||
						'SELECT 1 INTO v_Result FROM ' || c_cur.CHECK_QUERY || ';'
					);
				end if;
				if c_cur.APEX_ITEM_COLUMNS IS NULL then 
					dbms_lob.append (v_Result_Stat,
						case when c_cur.CHECK_QUERY IS NOT NULL
						 or c_cur.FORMAT_MASK IS NOT NULL then
							NL(12) ||
							'exception'
						end ||
						case when c_cur.CHECK_QUERY IS NOT NULL 
						then
							case when c_cur.FORMAT_MASK IS NOT NULL 
								then ' when no_data_found then' 
								else ' when others then'
							end
							|| NL(16) ||
							add_error_call (
								p_Column_Name => c_cur.COLUMN_NAME,
								p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
								p_Message => '"%0" - Value is out of range (%1).',
								p_Column_Header => c_cur.COLUMN_HEADER,
								p1 => Enquote_Literal(c_cur.CHECK_CONDITION)
							) 
						end
						|| case when c_cur.FORMAT_MASK IS NOT NULL then
							NL(12) ||
							' when others then' || NL(16) ||
							add_error_call (
								p_Column_Name => c_cur.COLUMN_NAME,
								p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
								p_Message => '"%0" - Value does not match format : %1.',
								p_Column_Header => c_cur.COLUMN_HEADER,
								p1 => Enquote_Literal(data_browser_conf.Get_Display_Format_Mask(c_cur.FORMAT_MASK, c_cur.DATA_TYPE))
							)
						end
						|| NL(12) || 'end;'
					);
					if c_cur.REQUIRED ='Y' -- empty hidden key values are not validated, because the submit page process can/will insert the new rows.
					and NOT (p_Data_Source = 'COLLECTION' and c_cur.COLUMN_EXPR_TYPE = 'HIDDEN') 
						then dbms_lob.append (v_Result_Stat,
							NL(8) ||
							'else' || NL(12) ||
							add_error_call (
								p_Column_Name => c_cur.COLUMN_NAME,
								p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
								p_Message => '"%0" - Value is required.',
								p_Column_Header => c_cur.COLUMN_HEADER
							)
						);
					end if;
					dbms_lob.append (v_Result_Stat,
						NL(8) ||
						'end if;'
					);
				end if;
			elsif c_cur.REQUIRED ='Y'  -- empty hidden key values are not validated, because the submit page process can/will
			and NOT (p_Data_Source = 'COLLECTION' and c_cur.COLUMN_EXPR_TYPE = 'HIDDEN') 
				then dbms_lob.append (v_Result_Stat,
					NL(8) ||
					'if ' || c_cur.APEX_ITEM_CALL || ' IS NULL then' || NL(12) ||
							add_error_call (
								p_Column_Name => c_cur.COLUMN_NAME,
								p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
								p_Message => '"%0" - Value is required.',
								p_Column_Header => c_cur.COLUMN_HEADER
							)
							|| NL(8) ||
					'end if;'
				);

			end if;
		end loop;

		for c_cur IN ( -- multiple columns checks
			SELECT VIEW_NAME, CONSTRAINT_NAME, CHECK_CONDITION, CHECK_UNIQUE,
				case when CHECK_UNIQUE = 'Y' then
					LISTAGG( '(' || COLUMN_NAME
							|| ' = '
							|| data_browser_conf.Get_Char_to_Type_Expr (
								p_Element 		=> APEX_ITEM_CALL,
								p_Element_Type	=> S_REF_TYPE,
								p_Data_Source	=> p_Data_Source,
								p_DATA_TYPE 	=> DATA_TYPE,
								p_DATA_SCALE 	=> DATA_SCALE,
								p_FORMAT_MASK 	=> FORMAT_MASK,
								p_USE_GROUP_SEPARATOR => v_Use_Group_Separator,
								p_use_NLS_params => v_use_NLS_params
							)
							|| case when T.KEY_REQUIRED = 'N' then
								' OR ' || COLUMN_NAME
								|| ' IS NULL AND  '
								|| APEX_ITEM_CALL
								|| ' IS NULL'
							end
							|| ')'
							, data_browser_conf.NL(12) || 'AND '
					) WITHIN GROUP (ORDER BY COLUMN_ID, POSITION)
				else
					LISTAGG( 
						data_browser_conf.Get_Char_to_Type_Expr (
							p_Element 		=> APEX_ITEM_CALL,
							p_Element_Type	=> S_REF_TYPE,
							p_Data_Source	=> p_Data_Source,
							p_DATA_TYPE 	=> DATA_TYPE,
							p_DATA_SCALE 	=> DATA_SCALE,
							p_FORMAT_MASK 	=> FORMAT_MASK,
							p_USE_GROUP_SEPARATOR => v_Use_Group_Separator,
							p_use_NLS_params => v_use_NLS_params
						)
						|| ' ' || R_COLUMN_NAME
						, ', '
					) WITHIN GROUP (ORDER BY COLUMN_ID, POSITION)
				end STAT,
				LISTAGG(APEX_ITEM_CALL || ' IS NOT NULL', case when T.KEY_REQUIRED = 'Y' then ' AND ' else ' OR ' end )
					WITHIN GROUP (ORDER BY COLUMN_ID, POSITION) COLUMN_COND,
				LISTAGG(COLUMN_HEADER, ', ') WITHIN GROUP (ORDER BY COLUMN_ID, POSITION) COLUMN_NAMES,
				MIN(COLUMN_NAME) COLUMN_NAME,
				MIN(APEX_ITEM_CELL_ID) APEX_ITEM_CELL_ID,
				MIN(APEX_ITEM_ROWS_CALL) APEX_ITEM_ROWS_CALL
			from (
				SELECT B.VIEW_NAME, B.CONSTRAINT_NAME, B.CHECK_CONDITION, B.CHECK_UNIQUE,
					B.COLUMN_NAME, A.R_COLUMN_NAME, A.COLUMN_HEADER, A.COLUMN_ID, A.POSITION,
					A.NULLABLE, A.REQUIRED, A.FORMAT_MASK, A.DATA_TYPE, A.DATA_SCALE, A.TABLE_ALIAS,
					A.APEX_ITEM_REF, B.KEY_REQUIRED, B.CONS_COLS_COUNT,
					case when p_Data_Source = 'COLLECTION' then
						'p_cur.' || A.INPUT_ID
					else
						data_browser_edit.Get_Apex_Item_Call (
							p_Idx 			=> APEX_ITEM_IDX,
							p_Row_Factor	=> ROW_FACTOR,
							p_Row_Offset	=> ROW_OFFSET,
							p_Row_Number	=> 'p_Row'
						)
					end APEX_ITEM_CALL,
					SUBSTR(A.INPUT_ID, 1, 1)  S_REF_TYPE, -- C,N
					data_browser_edit.Get_Apex_Item_Cell_ID(
						p_Idx 			=> APEX_ITEM_IDX,
						p_Row_Factor	=> ROW_FACTOR,
						p_Row_Offset	=> ROW_OFFSET,
						p_Row_Number 	=> 1,
						p_Data_Source 	=> p_Data_Source,
						p_Item_Type 	=> COLUMN_EXPR_TYPE
					) APEX_ITEM_CELL_ID,
					data_browser_edit.Get_Apex_Item_Rows_Call(
						p_Idx 			=> APEX_ITEM_IDX,
						p_Row_Factor	=> ROW_FACTOR,
						p_Row_Offset	=> ROW_OFFSET
					) APEX_ITEM_ROWS_CALL
				FROM TABLE (data_browser_edit.Get_Form_Edit_Cursor (
						p_Table_Name => p_Table_name,
						p_Unique_Key_Column => v_Search_Key_Cols,
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => p_Report_Mode,
						p_Join_Options => p_Join_Options,
						p_Data_Source => p_Data_Source,
						p_Parent_Name => p_Parent_Name,
						p_Parent_Key_Column => p_Parent_Key_Column,
						p_Parent_Key_Visible => p_Parent_Key_Visible,
						p_Parent_Key_Item => p_Parent_Key_Item
					)) A,
					( select S.VIEW_NAME, S.CONSTRAINT_NAME,
							REGEXP_REPLACE(S.CHECK_CONDITION, '\s+', chr(32)) CHECK_CONDITION,
							S.CHECK_UNIQUE, S.REQUIRED KEY_REQUIRED,
							T.COLUMN_VALUE COLUMN_NAME, S.CONS_COLS_COUNT
						FROM MVDATA_BROWSER_CHECKS_DEFS S, TABLE( apex_string.split( S.COLUMN_NAME, ', ') ) T
						where S.VIEW_NAME = p_Table_name
						and S.CONS_COLS_COUNT > 1  -- multiple columns unique constraints
					) B
				WHERE A.COLUMN_NAME = B.COLUMN_NAME
				-- Support for unique constraints with fk columns is required!!
				AND NOT(A.INPUT_ID IS NULL and p_Data_Source = 'COLLECTION')
				-- AND NOT (S.CHECK_UNIQUE = 'Y' and CONSTRAINT_NAME = 'AUTOMATICALLY' and p_DML_Command = 'LOOKUP' 
			) T
			GROUP BY VIEW_NAME, CONSTRAINT_NAME, CHECK_CONDITION, CHECK_UNIQUE, KEY_REQUIRED, CONS_COLS_COUNT
			HAVING SUM( case when p_Use_Empty_Columns = 'YES'
							or data_browser_edit.Check_Item_Ref (APEX_ITEM_REF, COLUMN_NAME) != 'UNKNOWN'
						then 0 else 1 end) = 0
			AND COUNT(DISTINCT COLUMN_NAME) = CONS_COLS_COUNT
		) loop
			if v_Apex_Item_Rows_Call IS NULL then
				v_Apex_Item_Rows_Call := c_cur.APEX_ITEM_ROWS_CALL;
			end if;
			dbms_lob.append (v_Result_Stat,
				NL(8) ||
				'if ' || c_cur.COLUMN_COND || ' then' || NL(10) ||
				  'begin'
			);
			if c_cur.CHECK_UNIQUE ='Y' then
				if p_Data_Source IN ('TABLE', 'NEW_ROWS', 'MEMORY' ) then
					if p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') 
					and v_Key_Value_call IS NOT NULL then
						dbms_lob.append (v_Result_Stat,
						    data_browser_edit.CM(' /* UK-Lookup ' || c_cur.VIEW_NAME || '(' || c_cur.COLUMN_NAMES || ') */ ') ||
							NL(12) ||
							'SELECT MAX(' || v_Key_Column || ')' || NL(12) ||
							'INTO v_Key_Value ' || NL(12) ||
							'FROM ' || data_browser_conf.Enquote_Name_Required(c_cur.VIEW_NAME) || ' A ' || NL(12) ||
							'WHERE ' || c_cur.STAT || ';' || NL(12) ||
							'if v_Key_Value IS NOT NULL then' || NL(16) ||
								v_Key_Value_call || ' := v_Key_Value;' || NL(12) ||
							'end if;'
						);
					else
						dbms_lob.append (v_Result_Stat,
						    data_browser_edit.CM(' /* UK-Check ' || c_cur.VIEW_NAME || '(' || c_cur.COLUMN_NAMES || ') */ ') ||
							NL(12) ||
							'SELECT COUNT(*) INTO v_Result ' ||
							'FROM ' || data_browser_conf.Enquote_Name_Required(c_cur.VIEW_NAME) || ' A ' || NL(12) ||
							'WHERE ' || c_cur.STAT || NL(12) ||
							'AND (' || v_Key_Column || ' != v_Key_Value OR v_Key_Value IS NULL);' || NL(12) ||
							'if v_Result > 0 then' || NL(16) ||
								add_error_call (
									p_Column_Name => c_cur.COLUMN_NAME,
									p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
									p_Message => '"%0" - Value combination must be unique. (Constraint %1).',
									p_Column_Header => c_cur.COLUMN_NAMES,
									p1 => Enquote_Literal (c_cur.CONSTRAINT_NAME),
									p_Class => 'UNIQUENESS'
								)
								|| NL(12) ||
							'end if;'
						);
					end if;
				elsif p_Data_Source = 'COLLECTION' then
					dbms_lob.append (v_Result_Stat,
						data_browser_edit.CM(' /* UK-Lookup ' || c_cur.VIEW_NAME || '(' || c_cur.COLUMN_NAMES || ') */ ') ||
						NL(12) ||
						'SELECT MAX(' || v_Key_Column || ')' || NL(12) ||
						'INTO v_Key_Value ' || NL(12) ||
						'FROM ' ||  data_browser_conf.Enquote_Name_Required(c_cur.VIEW_NAME) || ' A ' || NL(12) ||
						'WHERE ' || c_cur.STAT || ';' || NL(12) ||
						'if v_Key_Value IS NOT NULL then' || NL(16) ||
							add_error_call (
								p_Column_Name => c_cur.COLUMN_NAME,
								p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
								p_Message => '"%0" - Value combination exists. (Constraint %1).',
								p_Column_Header => c_cur.COLUMN_NAMES,
								p1 => Enquote_Literal (c_cur.CONSTRAINT_NAME),
								p_Class => 'UNIQUENESS'
							)
							||
							case when v_Key_Input_ID IS NOT NULL then
								NL(16) ||
								'apex_collection.update_member_attribute(p_collection_name => v_Data_Collection, p_seq => p_Row, p_attr_number => ' 
								|| v_Key_Input_ID 
								|| case when v_Key_Input_Type = 'N' then 
									', p_number_value => v_Key_Value);'
								else
									', p_attr_value => v_Key_Value);'
								end
							end
							|| NL(12) ||
						'end if;'
					);
				end if;
			else
				dbms_lob.append (v_Result_Stat,
					NL(12) ||
					'SELECT 1 INTO v_Result FROM (SELECT ' || c_cur.STAT ||
					' FROM DUAL)' || NL(12) ||
					'WHERE ' || c_cur.CHECK_CONDITION || ';'
				);
			end if;
			dbms_lob.append (v_Result_Stat,
				NL(10) ||
				'exception ' ||
				case when c_cur.CHECK_UNIQUE = 'N' then
					' when no_data_found then' || NL(16) ||
						add_error_call (
							p_Column_Name => c_cur.COLUMN_NAME,
							p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
							p_Message => '"%0" - Value is out of range (%1).',
							p_Column_Header => c_cur.COLUMN_NAMES,
							p1 => Enquote_Literal (c_cur.CHECK_CONDITION)
						)
						|| NL(12)
				end ||
					'when others then' || NL(16) ||
						add_error_call (
							p_Column_Name => c_cur.COLUMN_NAME,
							p_Apex_Item_Cell_Id => c_cur.APEX_ITEM_CELL_ID,
							p_Message => '"%0" - Error : %1.',
							p_Column_Header => c_cur.CONSTRAINT_NAME,
							p1 => 'DBMS_UTILITY.FORMAT_ERROR_STACK'
						)
						|| NL(10) ||
					'end;' || NL(8) ||
				'end if;'
			);
		end loop;
		v_Procedure_Name := INITCAP(data_browser_conf.Compose_Table_Column_Name(p_Table_name, 'Check_Row'));
		v_Procedure_Name2 := INITCAP(data_browser_conf.Compose_Table_Column_Name(p_Table_name, 'Check'));
		if DBMS_LOB.GETLENGTH(v_Result_Stat) > 1 then
			if p_Data_Source = 'COLLECTION' then
				dbms_lob.append (v_Result_PLSQL,
					'declare ' || NL(4) ||
						'v_Data_Collection varchar(100) := ' || data_browser_conf.Get_Import_Collection(p_Enquote=>'YES') || '; ' || NL(4) ||
						'v_Err_Collection varchar(100) := ' || data_browser_conf.Get_Import_Error_Collection(p_Enquote=>'YES') || '; ' || NL(4) ||
						'v_Error_Message varchar2(32767);' || NL(4) ||
					'procedure ' || v_Procedure_Name || ' ( p_cur APEX_COLLECTIONS%ROWTYPE, p_Row number )' || NL(4) ||
					'is' || NL(8) ||
						'v_Key_Value ' || v_Primary_Key_Col_Type || NL(8) ||
						'v_Result number;' || NL(8) ||
						declare_error_call(p_Table_name, v_Search_Key_Cols) || 
					'begin ' || NL(8) || 
					v_Init_Key_Stat
				);
			else
				dbms_lob.append (v_Result_PLSQL,
					'declare ' || NL(4) ||
						'v_Row_Number PLS_INTEGER := 1; ' || NL(4) ||
						'v_Row_Count  PLS_INTEGER := ' || v_Apex_Item_Rows_Call || '; ' || NL(4) ||
						'v_Err_Collection varchar(100) := ' || data_browser_conf.Get_Validation_Collection(p_Enquote=>'YES') || '; ' || NL(4) ||
						'v_Error_Message varchar2(32767);' || NL(4) ||
					'procedure ' || v_Procedure_Name || ' ( p_Key_Value varchar2, p_Row number )' || NL(4) ||
					'is' || NL(8) ||
						'v_Key_Value ' || v_Primary_Key_Col_Type || NL(8) ||
						'v_Result number;' || NL(8) ||
						declare_error_call(p_Table_name, v_Search_Key_Cols) || 
					'begin ' || NL(8) ||
					v_Init_Key_Stat
				);
				if v_Changed_Check_Plsql IS NOT NULL then
					dbms_lob.append (v_Result_PLSQL,
						NL(8) ||
						'if ' || v_Changed_Check_Plsql || ' then ' || NL(12) ||
							'return;' || NL(8) ||
						'end if;');
				end if;
			end if;
			dbms_lob.append (v_Result_PLSQL, v_Result_Stat);
			dbms_lob.append (v_Result_PLSQL,
				NL(4) ||
				'end ' || v_Procedure_Name || ';' || chr(10) || NL(4) ||
				'procedure ' || v_Procedure_Name2 || ' ( p_Key_Value in varchar2, p_Result out varchar2 )' || NL(4) ||
				'is' || NL(4) ||
				'begin' || NL(8)
			);
			if p_Data_Source = 'COLLECTION' then
				dbms_lob.append (v_Result_PLSQL,
					'if not(apex_collection.collection_exists(v_Err_Collection)) then'  || NL(12) ||
				    	'apex_collection.create_collection(v_Err_Collection);' || NL(8) ||
				    'end if;' || NL(8) ||
				    'for c_cur IN (SELECT * FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = v_Data_Collection) loop ' || NL(12) ||
				        v_Procedure_Name || ' ( c_cur, p_Row => c_cur.seq_id );' || NL(8) ||
				    'end loop;' || NL(8)
				);
			else
				dbms_lob.append (v_Result_PLSQL,
				    'apex_collection.create_or_truncate_collection(v_Err_Collection);' || NL(8) ||
				    'for v_Row_Number IN 1 ..v_Row_Count loop '  || NL(12) ||
				        v_Procedure_Name || ' ( p_Key_Value => p_Key_Value, p_Row => v_Row_Number );' || NL(8) ||
				    'end loop;' || NL(8)
				);
			end if;
			dbms_lob.append (v_Result_PLSQL,
				    'commit;' || NL(8) ||
				    'for c_cur IN (SELECT C006 row_num, C007 msg FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = v_Err_Collection AND C008 = ''DATA'' AND ROWNUM <= '
				    || data_browser_conf.Get_Errors_Listed_Limit || ') loop '  || NL(12) ||
				        'v_Error_Message := v_Error_Message || c_cur.row_num  || '':'' || c_cur.msg || chr(10) || ''<br />'';' || NL(8) ||
				    'end loop;' || NL(8) ||
				    'p_Result := v_Error_Message;' || NL(4) ||
				'end ' || v_Procedure_Name2 || ';' ||  chr(10) || 
				'begin' ||  NL(4) ||
				v_Procedure_Name2 || ' ( p_Key_Value => :key, p_Result => :result );' || chr(10) ||
				'end;' || chr(10)
			);

			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'data_browser_edit.Validate_Form_Checks_PL_SQL length=> %s, Result_PLSQL : %s',
					p0 => DBMS_LOB.GETLENGTH(v_Result_PLSQL),
					p1 => DBMS_LOB.SUBSTR (v_Result_PLSQL, 3000, 1),
					p_max_length => 3500
				);
			$END
			RETURN v_Result_PLSQL;
		else
			RETURN NULL;
		end if;
	END Validate_Form_Checks_PL_SQL;

	FUNCTION Validate_Form_Checks (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Key_Value 	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 1000,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode	VARCHAR2 DEFAULT 'NO',
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'NO'
	) RETURN VARCHAR2
	IS
        v_Result_PLSQL		CLOB;
        v_Error_Message VARCHAR2(32767);
	BEGIN
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_name,p_Key_Column,p_Key_Value,p_Select_Columns,p_Columns_Limit,p_View_Mode,p_Data_Source,p_Report_Mode,
				p_Join_Options,p_Parent_Name,p_Parent_Key_Column,p_Parent_Key_Visible,p_Parent_Key_Item,p_Use_Empty_Columns;
			data_browser_edit.Dump_Application_Items;
		$END
    	dbms_lob.createtemporary(v_Result_PLSQL, true, dbms_lob.call);
		v_Result_PLSQL := Validate_Form_Checks_PL_SQL (
			p_Table_name => p_Table_name,
			p_Key_Column => p_Key_Column,
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Data_Source => p_Data_Source,
			p_Report_Mode => p_Report_Mode,
			p_Join_Options => p_Join_Options,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Use_Empty_Columns => p_Use_Empty_Columns
		);
		if DBMS_LOB.GETLENGTH(v_Result_PLSQL) > 1 then
			EXECUTE IMMEDIATE v_Result_PLSQL USING IN p_Key_Value, OUT v_Error_Message;
			if v_Error_Message IS NOT NULL then
				v_Error_Message := v_Error_Message || '<br />' || chr(10);
			end if;
			commit;
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Validate_Form_Checks (p_Table_name => %s, p_Data_Source => %s,' || chr(10)
				|| ' v_Error_Message=> %s, getlength(v_Result_PLSQL) => %s), Import_Collection_Count => %s, Error_Collection_Count => %s',
				p0 => p_Table_name,
				p1 => p_Data_Source,
				p2 => v_Error_Message,
				p3 => DBMS_LOB.GETLENGTH(v_Result_PLSQL),
				p4 => APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name => data_browser_conf.Get_Import_Collection),
				p5 => APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name => data_browser_conf.Get_Import_Error_Collection),
				p_max_length => 3500
			);
		$END
		return v_Error_Message;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	  	v_Error_Message := SQLERRM;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'Exception in data_browser_edit.Validate_Form_Checks (p_Data_Source=>%s, p_Key_Value=> %s, v_Error_Message=> %s)',
				p0 => p_Data_Source,
				p1 => p_Key_Value,
				p2 => v_Error_Message,
				p_max_length => 3500
			);
		$END
	    commit;
		return v_Error_Message;
$END 
	END Validate_Form_Checks;


	PROCEDURE Set_Import_View_Defaults (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER,
		p_View_Mode IN VARCHAR2,
    	p_Join_Options VARCHAR2,
    	p_Parent_Name VARCHAR2,					-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2,			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2
	)
	is
		v_Data_Collection varchar(100) := data_browser_conf.Get_Import_Collection(p_Enquote=>'NO');
		v_num_Result APEX_COLLECTIONS.N001%TYPE;
		v_char_Result APEX_COLLECTIONS.C001%TYPE;
		v_SEQ_ID APEX_COLLECTIONS.SEQ_ID%TYPE;
		v_Query	VARCHAR2(2000);
		TYPE cur_type IS REF CURSOR;
   		c_cur cur_type;
	begin
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_name,p_Unique_Key_Column,p_Select_Columns,p_Columns_Limit,p_View_Mode,p_Join_Options,
				p_Parent_Name,p_Parent_Key_Column,p_Parent_Key_Visible,p_Parent_Key_Item;
		$END

		v_Query := 'SELECT SEQ_ID FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = ' 
				|| data_browser_conf.Get_Import_Collection( p_Enquote=>'YES' );
        FOR d_cur IN (
			SELECT COLUMN_NAME, COLUMN_EXPR_TYPE, COLUMN_EXPR,
				INPUT_ID, DATA_DEFAULT, 
				TABLE_ALIAS, REF_TABLE_NAME, REF_COLUMN_NAME, 
				SUBSTR(INPUT_ID, 1, 1) D_REF_TYPE, -- C,N
				LTRIM(SUBSTR(INPUT_ID, 2), '0') D_REF
			FROM TABLE ( data_browser_edit.Get_Form_Edit_Cursor(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => 'YES',
					p_Join_Options => p_Join_Options,
					p_Data_Source=> 'NEW_ROWS', 
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item
				)
			) S
			WHERE DATA_DEFAULT IS NOT NULL
        )
        loop
			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'data_browser_edit.Set_Import_View_Defaults checking (COLUMN_NAME=>%s, INPUT_ID=> %s, DATA_DEFAULT=> %s)',
					p0 => d_cur.COLUMN_NAME,
					p1 => d_cur.INPUT_ID,
					p2 => d_cur.DATA_DEFAULT,
					p_max_length => 3500
				);
			$END
			if d_cur.D_REF_TYPE = 'N' then 
				v_char_Result := data_browser_edit.Get_Formated_Default (
					p_Column_Expr_Type => d_cur.COLUMN_EXPR_TYPE,
					p_Column_Alias  => d_cur.TABLE_ALIAS || '.' || d_cur.REF_COLUMN_NAME,
					p_Column_Expr 	=> d_cur.COLUMN_EXPR,
					p_Data_Default 	=> d_cur.DATA_DEFAULT,
					p_Enquote		=> 'NO'
				);
				if v_char_Result IS NOT NULL then 
					begin
						v_num_Result := TO_NUMBER(v_char_Result);
					exception when VALUE_ERROR then
						$IF data_browser_conf.g_debug $THEN
							apex_debug.info ( p_message => 'data_browser_edit.Set_Import_View_Defaults VALUE_ERROR (%s)', p0 => v_char_Result );
						$END
						continue;
						-- ORA-06502: PL/SQL: numeric or value error
					end;
					$IF data_browser_conf.g_debug $THEN
						apex_debug.info ( p_message => 'data_browser_edit.Set_Import_View_Defaults setting value (%s)', p0 => v_num_Result );
					$END
					OPEN c_cur FOR v_Query || ' AND ' || d_cur.INPUT_ID || ' IS NULL';
					loop
						FETCH c_cur INTO v_SEQ_ID;
						EXIT WHEN c_cur%NOTFOUND;
						apex_collection.update_member_attribute (
							p_collection_name => v_Data_Collection, p_seq => v_SEQ_ID, 
							p_attr_number => d_cur.D_REF, p_number_value => v_num_Result
						);
					end loop;
					CLOSE c_cur;
				end if;
			elsif d_cur.D_REF_TYPE = 'C' then 
				v_char_Result := data_browser_edit.Get_Formated_Default (
					p_Column_Expr_Type => d_cur.COLUMN_EXPR_TYPE,
					p_Column_Alias  => d_cur.TABLE_ALIAS || '.' || d_cur.REF_COLUMN_NAME,
					p_Column_Expr 	=> d_cur.COLUMN_EXPR,
					p_Data_Default 	=> d_cur.DATA_DEFAULT,
					p_Enquote		=> 'NO'
				);
				if v_char_Result IS NOT NULL then 
					$IF data_browser_conf.g_debug $THEN
						apex_debug.info ( p_message => 'data_browser_edit.Set_Import_View_Defaults setting value (%s)', p0 => v_char_Result );
					$END
					OPEN c_cur FOR v_Query || ' AND ' || d_cur.INPUT_ID || ' IS NULL';
					loop
						FETCH c_cur INTO v_SEQ_ID;
						EXIT WHEN c_cur%NOTFOUND;
						apex_collection.update_member_attribute (
							p_collection_name => v_Data_Collection, p_seq => v_SEQ_ID, 
							p_attr_number => d_cur.D_REF, p_attr_value => v_char_Result
						);
					end loop;
					CLOSE c_cur;
				end if;
			else
				begin
					EXECUTE IMMEDIATE 'begin :x := ' || d_cur.DATA_DEFAULT || '; end;' USING OUT v_char_Result;
				exception when others then
					continue;
				end;
				if v_char_Result IS NOT NULL then 
					$IF data_browser_conf.g_debug $THEN
						apex_debug.info ( p_message => 'data_browser_edit.Set_Import_View_Defaults setting value (%s)', p0 => v_char_Result );
					$END
					OPEN c_cur FOR v_Query;
					loop
						FETCH c_cur INTO v_SEQ_ID;
						EXIT WHEN c_cur%NOTFOUND;
						apex_collection.update_member_attribute (
							p_collection_name => v_Data_Collection, p_seq => v_SEQ_ID, 
							p_attr_number => d_cur.D_REF, p_attr_value => v_char_Result
						); 
					end loop;
					CLOSE c_cur;
				end if;
			end if;
        end loop;
	end Set_Import_View_Defaults;


	PROCEDURE Validate_Imported_Data (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 50,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item IN VARCHAR2 DEFAULT NULL,			-- Name of item with foreign key vale
		p_Rows_Imported_Count NUMBER DEFAULT NULL,
		p_Inject_Defaults VARCHAR2 DEFAULT 'NO'				-- inject default values in empty cells of the collection
	)
	is
		v_Imported_Count PLS_INTEGER;
		v_Remaining_Count PLS_INTEGER;
		v_Error_Count PLS_INTEGER;
		v_Intersections_Count PLS_INTEGER;
		v_Message1 VARCHAR2(32767);
		v_Message2 VARCHAR2(32767);
		v_Message3 VARCHAR2(32767);
	begin
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_name,p_Key_Column,p_Select_Columns,p_Columns_Limit,p_View_Mode,p_Join_Options,
				p_Parent_Name,p_Parent_Key_Column,p_Parent_Key_Visible,p_Parent_Key_Item,p_Rows_Imported_Count,p_Inject_Defaults;
		$END

		if p_View_Mode NOT IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
			v_Message1 := apex_string.format('View Mode %s is not supported for this operation.', p_View_Mode);
			Apex_Error.Add_Error (
				p_message  => Apex_Lang.Lang('Validation of imported data failed with %0 %1 %2.', v_Message1, v_Message2, v_Message3),
				p_display_location => apex_error.c_inline_in_notification
			);
			return;
		end if;
		data_browser_edit.Set_Import_Description(
			p_Table_name => p_Table_name,
			p_Key_Column => p_Key_Column,
			p_View_Mode => p_View_Mode,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Rows_Imported_Count => p_Rows_Imported_Count
		);
		if p_Inject_Defaults = 'YES' then 
			Set_Import_View_Defaults (
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => p_Key_Column,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Parent_Name => p_Parent_Name,
				p_Join_Options => p_Join_Options,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => p_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item
			);
		end if;
		v_Message1 := data_browser_edit.Validate_Form_Foreign_Keys(
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Key_Column,
			p_Data_Source => 'COLLECTION',
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Join_Options => p_Join_Options,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_DML_Command => 'LOOKUP',
			p_Use_Empty_Columns => 'YES',
			p_Exec_Phase => 1
		);
		v_Message2 := data_browser_edit.Validate_Form_Foreign_Keys(
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Key_Column,
			p_Data_Source => 'COLLECTION',
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Join_Options => p_Join_Options,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Use_Empty_Columns => 'YES',
			p_DML_Command => 'LOOKUP',
			p_Exec_Phase => 2
		);
		v_Message3 := data_browser_edit.Validate_Form_Checks(
			p_Table_name => p_Table_name,
			p_Key_Column => p_Key_Column,
			p_Key_Value => NULL,
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Join_Options => p_Join_Options,
			p_Data_Source => 'COLLECTION',
			p_Report_Mode => 'YES',
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Use_Empty_Columns => 'YES'
		);
		data_browser_edit.Get_Import_Description (
			p_Imported_Count => v_Imported_Count,
			p_Remaining_Count => v_Remaining_Count,
			p_Validations_Count => v_Error_Count,
			p_Intersections_Count => v_Intersections_Count
		);
		if v_Error_Count = 0 and (v_Message1 LIKE 'ORA-06550%' or v_Message2 LIKE 'ORA-06550%' or v_Message3 LIKE 'ORA-06550%') then
			Apex_Error.Add_Error (
				p_message  => Apex_Lang.Lang('Validation of imported data failed with %0 %1 %2.', v_Message1, v_Message2, v_Message3),
				p_display_location => apex_error.c_inline_in_notification
			);
		else
			if v_Imported_Count > 0 then 
				apex_application.g_print_success_message := apex_application.g_print_success_message
					|| Apex_Lang.Lang('%0 rows have been loaded.', v_Imported_Count);
			end if;
			if v_Error_Count > 0 then 
				apex_application.g_print_success_message := apex_application.g_print_success_message
					|| Apex_Lang.Lang('%0 validation errors found.', v_Error_Count);
			end if;
		end if;
		commit;
	end Validate_Imported_Data;

	PROCEDURE Set_Import_Description (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 50,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
		p_Rows_Imported_Count NUMBER DEFAULT NULL
	)
	is
	begin
		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>data_browser_conf.Get_Import_Desc_Collection);
		exception
		  when dup_val_on_index then null;
		end;
		apex_collection.add_member (
            p_collection_name => data_browser_conf.Get_Import_Desc_Collection,
            p_c001 => p_Table_name,
            p_c002 => p_Key_Column,
            p_c003 => p_View_Mode,
            p_c004 => p_Parent_Name,
            p_c005 => p_Parent_Key_Column,
            p_c006 => p_Parent_Key_Visible,
            p_c007 => p_Select_Columns,
            p_n001 => p_Columns_Limit,
            p_n002 => p_Rows_Imported_Count
        );
        commit;
	end Set_Import_Description;

	FUNCTION Match_Import_Description (
		p_Table_name    VARCHAR2,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit NUMBER DEFAULT 50,
		p_View_Mode     VARCHAR2 DEFAULT 'FORM_VIEW',		-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Parent_Name   VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO'			-- YES, NO, NULLABLE. Show foreign key column
	) RETURN VARCHAR2 -- YES, NO
	is
		v_Row_Count PLS_INTEGER;
	begin
		if data_browser_utl.Check_Edit_Enabled(p_Table_Name => p_Table_name, p_View_Mode => p_View_Mode) = 'YES' then
			SELECT COUNT(*) INTO v_Row_Count
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Desc_Collection
			AND C001 = p_Table_name
			AND (C002 = p_Key_Column or C002 IS NULL and p_Key_Column IS NULL)
			AND C003 = p_View_Mode
			AND (C004 = p_Parent_Name or C004 IS NULL and p_Parent_Name IS NULL)
			AND (C005 = p_Parent_Key_Column or C005 IS NULL and p_Parent_Key_Column IS NULL)
			AND (C006 = p_Parent_Key_Visible or C006 IS NULL and p_Parent_Key_Visible IS NULL)
			AND (C007 = p_Select_Columns or C007 IS NULL and p_Select_Columns IS NULL)
			AND N001 = p_Columns_Limit;
			return case when v_Row_Count = 0 then 'NO' else 'YES' end;
		else
			return 'NO';
		end if;
	end Match_Import_Description;

	PROCEDURE Get_Import_Description (
		p_Imported_Count OUT NUMBER,
		p_Remaining_Count OUT NUMBER,
		p_Validations_Count OUT NUMBER,
		p_Intersections_Count OUT NUMBER
	)
	is
	begin
		SELECT NVL(MAX(N002), 0) INTO p_Imported_Count
		FROM APEX_COLLECTIONS
		WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Desc_Collection;

		SELECT COUNT(*) INTO p_Remaining_Count
		FROM APEX_COLLECTIONS
		WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Collection;

		SELECT COUNT(*) INTO p_Validations_Count
		FROM APEX_COLLECTIONS
		WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Error_Collection
		AND C008 IN ('DATA', 'LOOKUP');

		SELECT COUNT(*) INTO p_Intersections_Count
		FROM APEX_COLLECTIONS
		WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Error_Collection
		AND C008 = 'UNIQUENESS';
	end Get_Import_Description;

	FUNCTION Import_Description_cursor RETURN data_browser_conf.tab_apex_links_list PIPELINED
	is
	PRAGMA UDF;
        CURSOR view_cur
        IS
		SELECT 1 the_level,
			label,
			null target,
			'NO' is_current_list_entry,
			null image,
			position,
			counter attribute1
		FROM (
			SELECT NVL(N002,0) counter, apex_lang.lang('Import File Rows') label, 1 position
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Desc_Collection
			UNION ALL
			SELECT COUNT(*)  counter,  apex_lang.lang('Validations Errors') label, 2 position
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Error_Collection
			AND C008 IN ('DATA', 'LOOKUP')
			UNION ALL
			SELECT COUNT(*)  counter,  apex_lang.lang('Existing Rows Found') label, 3 position
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Error_Collection
			AND C008 = 'UNIQUENESS'
			UNION ALL
			SELECT NVL(N002,0) -
			( SELECT COUNT(*)
				FROM APEX_COLLECTIONS
				WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Error_Collection
				AND C008 = 'UNIQUENESS'
			) counter, apex_lang.lang('New Rows') label, 1 position
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Desc_Collection
			-- UNION ALL
			-- SELECT COUNT(*)  counter,  apex_lang.lang('Remaining Rows') label, 4 position
			-- FROM APEX_COLLECTIONS
			-- WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Collection
		);
		v_out_rec data_browser_conf.rec_apex_links_list;
		v_out_tab data_browser_conf.tab_apex_links_list;
	begin
		OPEN view_cur;
		FETCH view_cur BULK COLLECT INTO v_out_tab;
		CLOSE view_cur;
		FOR ind IN 1 .. v_out_tab.COUNT LOOP
			v_out_rec := v_out_tab(ind);
			pipe row (v_out_rec);
		END LOOP;
	exception
	  when others then
	    if view_cur%ISOPEN then
			CLOSE view_cur;
		end if;
		raise;
	end Import_Description_cursor;


	PROCEDURE Reset_Import_Description
	is
	begin
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Reset_Import_Description'
			);
		$END
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Import_Desc_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Import_Desc_Collection);
		end if;
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Import_Error_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Import_Error_Collection);
		end if;
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Lookup_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Lookup_Collection);
		end if;
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Import_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Import_Collection);
		end if;
    	if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Validation_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Validation_Collection);
		end if;
		commit;
	end Reset_Import_Description;

	FUNCTION Validate_Form_Field (
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Column_Value VARCHAR2 DEFAULT NULL,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Key_Value 	VARCHAR2 DEFAULT NULL,
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	IS
		v_Error_Message VARCHAR2(4000);
		v_Column_Value	VARCHAR2(32767);
		v_Query			VARCHAR2(4000);
		v_Result		NUMBER;
		cv 				SYS_REFCURSOR;
		v_Use_Group_Separator CONSTANT VARCHAR2(1) := 'Y';
		v_use_NLS_params CONSTANT VARCHAR2(1) := 'Y';
	BEGIN
		v_Column_Value := p_Column_Value;
		for c_cur IN ( -- single column checks
			select R_VIEW_NAME, COLUMN_NAME, COLUMN_HEADER, CHECK_CONDITION,
				REQUIRED, CHECK_UNIQUE, FORMAT_MASK, DATA_TYPE, APEX_ITEM_REF,
				case when CHECK_UNIQUE = 'Y' then
					'SELECT COUNT(*) FROM ' || data_browser_conf.Enquote_Name_Required(R_VIEW_NAME)
					|| ' WHERE '|| DBMS_ASSERT.ENQUOTE_NAME(COLUMN_NAME)
					|| ' = '
					|| data_browser_conf.Get_Char_to_Type_Expr (
						p_Element 		=> ':s',
						p_DATA_TYPE 	=> DATA_TYPE,
						p_DATA_SCALE 	=> DATA_SCALE,
						p_FORMAT_MASK 	=> FORMAT_MASK,
						p_USE_GROUP_SEPARATOR => v_Use_Group_Separator,
						p_use_NLS_params => v_use_NLS_params
					)
				end UNIQUE_QUERY,
				case when CHECK_CONDITION IS NOT NULL then
					'SELECT 1 FROM (SELECT '
					|| data_browser_conf.Get_Char_to_Type_Expr (
						p_Element 		=> ':s',
						p_Data_Type 	=> DATA_TYPE,
						p_Data_Scale 	=> DATA_SCALE,
						p_Format_Mask 	=> FORMAT_MASK,
						p_Use_Group_Separator => v_Use_Group_Separator,
						p_use_NLS_params => v_use_NLS_params
					)
					|| ' ' || R_COLUMN_NAME || ' FROM DUAL) WHERE ' || CHECK_CONDITION
				end CHECK_QUERY
			from (
				SELECT B.R_VIEW_NAME, B.COLUMN_NAME, B.R_COLUMN_NAME, B.COLUMN_HEADER, D.CHECK_CONDITION,
					B.REQUIRED, B.CHECK_UNIQUE, B.FORMAT_MASK, B.DATA_TYPE, B.DATA_SCALE, B.APEX_ITEM_REF
				FROM TABLE (data_browser_edit.Get_Form_Edit_Cursor (
						p_Table_Name => p_Table_name,
						p_Unique_Key_Column => p_Key_Column,
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => 'NO',
						p_Join_Options => p_Join_Options
					)
				) B
				LEFT OUTER JOIN MVDATA_BROWSER_CHECKS_DEFS D ON D.VIEW_NAME = B.REF_VIEW_NAME AND D.COLUMN_NAME = B.REF_COLUMN_NAME AND D.CONS_COLS_COUNT = 1
				WHERE B.COLUMN_NAME = p_Column_Name
				AND B.APEX_ITEM_REF IS NOT NULL
				AND B.IS_SEARCH_KEY = 'N'
			)
		) loop
			$IF data_browser_conf.g_debug $THEN
				APEX_DEBUG_MESSAGE.info (p_message => 'Validate_Form_Checks (Column_Name => %s, Column_Value => %s, Apex_Item_Ref => %s, Query => %s)',
					p0 => c_cur.COLUMN_NAME,
					p1 => v_Column_Value,
					p2 => c_cur.APEX_ITEM_REF,
					p3 => NVL(c_cur.CHECK_QUERY, c_cur.UNIQUE_QUERY),
					p_max_length => 3500
				);
			$END
			begin
				if c_cur.CHECK_UNIQUE ='Y' and v_Column_Value IS NOT NULL then
					if p_Key_Column IS NOT NULL and p_Key_Value IS NOT NULL then
						v_Query := c_cur.UNIQUE_QUERY
						|| ' AND ' || DBMS_ASSERT.ENQUOTE_NAME(p_Key_Column) || ' != :t ';
						OPEN cv FOR v_Query USING v_Column_Value, p_Key_Value;
					else
						OPEN cv FOR c_cur.UNIQUE_QUERY USING v_Column_Value;
					end if;
					FETCH cv INTO v_Result;
					CLOSE cv;
					if v_Result > 0 then
						v_Error_Message := v_Error_Message || chr(10)
						|| APEX_LANG.LANG('Value is not unique.');
					end if;
				end if;
				if c_cur.CHECK_QUERY IS NOT NULL and v_Column_Value IS NOT NULL then
					OPEN cv FOR c_cur.CHECK_QUERY USING v_Column_Value;
					FETCH cv INTO v_Result;
					if cv%NOTFOUND then
						v_Error_Message := v_Error_Message || chr(10)
						|| APEX_LANG.LANG('Value is out of range (%0).', c_cur.CHECK_CONDITION);
					end if;
					CLOSE cv;
				end if;
			exception
			when others then
				v_Error_Message := v_Error_Message || chr(10)
				|| SUBSTR(SQLERRM, INSTR(SQLERRM, ':')+1)
				|| case when c_cur.FORMAT_MASK IS NOT NULL
					then ', ' || APEX_LANG.LANG('Value does not match format %0 .', 
						data_browser_conf.Get_Display_Format_Mask(c_cur.FORMAT_MASK, c_cur.DATA_TYPE))
				end;
			end;
		end loop;

		RETURN v_Error_Message;
	EXCEPTION
	WHEN OTHERS THEN
		return p_Column_Name || ' - ' || SUBSTR(SQLERRM, INSTR(SQLERRM, ':')+1);
	END Validate_Form_Field;

	PROCEDURE Form_Checks_Process (
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Column_Value VARCHAR2 DEFAULT NULL,
		p_Key_Column	VARCHAR2 DEFAULT NULL,
		p_Key_Value 	VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'	-- FORM_VIEW, IMPORT_VIEW, EXPORT_VIEW
	)
	IS
		v_Result		VARCHAR2(4000);
	BEGIN
		v_Result := Validate_Form_Field(
			p_Table_name 		=> p_Table_name,
			p_Column_Name 		=> p_Column_Name,
			p_Column_Value 		=> p_Column_Value,
			p_Key_Column 		=> p_Key_Column,
			p_Key_Value 		=> p_Key_Value,
			p_Columns_Limit 	=> p_Columns_Limit,
			p_View_Mode 		=> p_View_Mode
		);
		owa_util.mime_header('text/xml', FALSE );
		htp.p('Cache-Control: no-cache');
		htp.p('Pragma: no-cache');
		owa_util.http_header_close;

		htp.prn('<record>');
		htp.prn('<item value="message">' || htf.escape_sc(v_Result) || '</item>');
		htp.prn('</record>');
	end Form_Checks_Process;

	PROCEDURE Check_Unique_Key_Process (
		p_Table_name	VARCHAR2,
		p_Column_Name	VARCHAR2,
		p_Column_Value	VARCHAR2,
		p_Key_Column	VARCHAR2,
		p_Key_Value 	VARCHAR2
	)
	IS
		v_Query			VARCHAR2(1000);
		v_Result    	NUMBER := 0;
		cv 				SYS_REFCURSOR;
	BEGIN
		if p_Key_Column IS NOT NULL and p_Key_Value IS NOT NULL then
			v_Query := 'SELECT COUNT(*) FROM ' || data_browser_conf.Enquote_Name_Required(p_Table_Name)
			|| ' WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(p_Column_Name)  || ' = :s '
			|| ' AND ' || DBMS_ASSERT.ENQUOTE_NAME(p_Key_Column) || ' != :t ';
			OPEN cv FOR v_Query USING p_Column_Value, p_Key_Value;
		else
			v_Query := 'SELECT COUNT(*) FROM ' || data_browser_conf.Enquote_Name_Required(p_Table_Name)
			|| ' WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(p_Column_Name)  || ' = :s ';
			OPEN cv FOR v_Query USING p_Column_Value;
		end if;
		FETCH cv INTO v_Result;
		CLOSE cv;
		owa_util.mime_header('text/xml', FALSE );
		htp.p('Cache-Control: no-cache');
		htp.p('Pragma: no-cache');
		owa_util.http_header_close;

		htp.prn('<record>');
		htp.prn('<item value="count">' || v_Result || '</item>');
		htp.prn('</record>');
	end Check_Unique_Key_Process;

	FUNCTION Convert_Raw_to_Varchar2 (
		p_Data_Type VARCHAR2,
		p_Raw_Data RAW
	) RETURN VARCHAR2 DETERMINISTIC
	is 
	    v_num number; 
	    v_char varchar2(2000);
	    v_nchar nvarchar2(2000);
	    v_date date;
	    v_float binary_float;
	    v_double binary_double;
	begin 
		case p_Data_Type 
		when 'NUMBER' then 
			dbms_stats.convert_raw_value(p_Raw_Data, v_num); 
			return v_num;
		when 'VARCHAR2' then 
			dbms_stats.convert_raw_value(p_Raw_Data, v_char); 
			return v_char;
		when 'CHAR' then 
			dbms_stats.convert_raw_value(p_Raw_Data, v_char); 
			return v_char;
		when 'DATE' then 
			dbms_stats.convert_raw_value(p_Raw_Data, v_date); 
			return v_date;
		when 'BINARY_DOUBLE' then 
			dbms_stats.convert_raw_value(p_Raw_Data, v_double); 
			return v_double;
		when 'BINARY_FLOAT' then
			dbms_stats.convert_raw_value(p_Raw_Data, v_float); 
			return v_float;
		when 'NVARCHAR2' then 
			dbms_stats.convert_raw_value_nvarchar(p_Raw_Data, v_nchar);
			return v_nchar;
		else 
			return '-';
		end case;
	exception when others then 
		return '-';
	end;


	FUNCTION Get_Form_Field_Help_Text ( -- External
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2,
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_View_Mode	VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Show_Statistics VARCHAR2 DEFAULT 'NO',
		p_Show_Title VARCHAR2 DEFAULT 'YES'
	) RETURN VARCHAR2
	is
		v_Help_Text			VARCHAR2(32767);
		v_Ref_Table_Name 	VARCHAR2(128);
		v_Ref_Column_Name 	VARCHAR2(128);
	begin
		Get_Form_Field_Help_Text ( -- External
			p_Table_name => p_Table_name,
			p_Column_Name => p_Column_Name,
			p_Parent_Name => p_Parent_Name,
			p_View_Mode	=> p_View_Mode,
			p_Join_Options => p_Join_Options,
			p_Show_Statistics => p_Show_Statistics,
			p_Show_Title => p_Show_Title,
			p_Help_Text => v_Help_Text,
			p_Ref_Table_Name => v_Ref_Table_Name,
			p_Ref_Column_Name => v_Ref_Column_Name
		);
		return v_Help_Text;
	end;

	PROCEDURE Get_Form_Field_Help_Text ( -- External
		p_Table_name VARCHAR2,
		p_Column_Name VARCHAR2,
		p_Parent_Name VARCHAR2 DEFAULT NULL,
		p_View_Mode	VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Show_Statistics VARCHAR2 DEFAULT 'NO',
		p_Show_Title VARCHAR2 DEFAULT 'YES',
    	p_Help_Text OUT VARCHAR2,
    	p_Ref_Table_Name OUT VARCHAR2,
    	p_Ref_Column_Name OUT VARCHAR2
	)
	is
		v_Help_Text		VARCHAR2(32767);
		v_Delimiter		CONSTANT VARCHAR2(10) := chr(10);
	begin
		if p_Column_Name = 'ROW_SELECTOR$' then
			v_Help_Text := 'Select : '  || chr(10)|| chr(10) || APEX_LANG.LANG('Select rows for Actions') || v_Delimiter;
		else 
			v_Help_Text := p_Column_Name || ': ' || APEX_LANG.LANG('No help text found.');
		end if;
		for c_cur IN ( -- single column checks
				select S.R_VIEW_NAME, S.R_TABLE_NAME, S.COLUMN_NAME, S.R_COLUMN_NAME, S.COLUMN_HEADER,
					S.REF_VIEW_NAME, S.REF_TABLE_NAME, S.REF_COLUMN_NAME, 
					D.CHECK_CONDITION, D.CONSTRAINT_NAME, D.CHECK_CONSTRAINT_NAME,
					S.REQUIRED, S.CHECK_UNIQUE, S.FORMAT_MASK, 
					C.DATA_TYPE, C.DATA_PRECISION, C.DATA_SCALE, C.CHAR_LENGTH,
					C.HAS_DEFAULT,  
					C.DATA_DEFAULT,
					S.COLUMN_EXPR_TYPE,
					S.IS_BLOB, S.IS_AUDIT_COLUMN, S.IS_OBFUSCATED, S.IS_UPPER_NAME, S.IS_NUMBER_YES_NO_COLUMN, S.IS_CHAR_YES_NO_COLUMN, 
					S.IS_REFERENCE, S.IS_SEARCHABLE_REF, 
					S.IS_PASSWORD, S.TABLE_ALIAS, 
					C.IS_DATA_DEDUCTED, C.IS_READONLY, C.IS_VIRTUAL_COLUMN, C.IS_ORDERING_COLUMN,
					C.IS_SUMMAND, C.IS_MINUEND, C.IS_FACTOR, C.IS_CURRENCY,
					C.COMMENTS, TC.NUM_DISTINCT, 
					data_browser_edit.Convert_Raw_to_Varchar2 (TC.DATA_TYPE, TC.LOW_VALUE) LOW_VALUE, 
					data_browser_edit.Convert_Raw_to_Varchar2 (TC.DATA_TYPE, TC.HIGH_VALUE) HIGH_VALUE, 
					TC.DENSITY, TC.LAST_ANALYZED,
					case when S.COLUMN_NAME = T.ACTIVE_LOV_COLUMN_NAME then 'Y' else 'N' end IS_ACTIVE_LOV_FILTER,
					case when S.COLUMN_NAME = T.HTML_FIELD_COLUMN_NAME then 'Y' else 'N' end IS_HTML_FIELD,
					case when S.COLUMN_NAME = T.ROW_VERSION_COLUMN_NAME then 'Y' else 'N' end IS_ROW_VERSION_FIELD,
					case when S.COLUMN_NAME = T.ROW_LOCKED_COLUMN_NAME then 'Y' else 'N' end IS_ROW_LOCKED_FIELD,
					case when S.COLUMN_NAME = T.SOFT_DELETED_COLUMN_NAME then 'Y' else 'N' end IS_SOFT_DELETED_FIELD,
					case when S.COLUMN_NAME IN (T.FILE_NAME_COLUMN_NAME, T.MIME_TYPE_COLUMN_NAME, T.FILE_DATE_COLUMN_NAME, T.FILE_CONTENT_COLUMN_NAME)
						then 'Y' else 'N' end IS_FILE_META_FIELD,
					case when S.COLUMN_NAME IN (T.FILE_FOLDER_COLUMN_NAME, T.FOLDER_NAME_COLUMN_NAME, T.FOLDER_PARENT_COLUMN_NAME)
						then 'Y' else 'N' end IS_FOLDER_META_FIELD
				from MVDATA_BROWSER_VIEWS T
				, TABLE (data_browser_select.Get_View_Column_Cursor (
						p_Table_Name => T.VIEW_NAME,
						p_Unique_Key_Column => T.SEARCH_KEY_COLS,
						p_View_Mode => p_View_Mode,
						p_Report_Mode => 'ALL',
						p_Join_Options => p_Join_Options,
						p_Parent_Name => p_Parent_Name,
						p_Parent_Key_Visible => 'YES',
						p_Data_Columns_Only => 'NO'
					)
				) S 
				left outer join MVDATA_BROWSER_SIMPLE_COLS C on S.R_VIEW_NAME = C.VIEW_NAME and S.R_COLUMN_NAME = C.COLUMN_NAME
				left outer join SYS.USER_TAB_COLS TC on S.REF_TABLE_NAME = TC.TABLE_NAME and S.REF_COLUMN_NAME = TC.COLUMN_NAME
				LEFT OUTER JOIN MVDATA_BROWSER_CHECKS_DEFS D ON D.VIEW_NAME = S.REF_VIEW_NAME AND D.COLUMN_NAME = S.REF_COLUMN_NAME AND D.CONS_COLS_COUNT = 1
				where S.COLUMN_NAME = p_Column_Name
				and T.VIEW_NAME = p_Table_name
		) loop
			if p_Show_Title = 'YES' then
				v_Help_Text := data_browser_conf.Table_Name_To_Header(c_cur.R_VIEW_NAME) || ' - ' || c_cur.COLUMN_HEADER || ' :' || chr(10)|| chr(10);
			else 
				v_Help_Text := null;
			end if;
			p_Ref_Table_Name  := c_cur.R_VIEW_NAME;
			p_Ref_Column_Name := c_cur.R_COLUMN_NAME;
			
			if c_cur.COMMENTS IS NOT NULL then
				v_Help_Text := v_Help_Text || APEX_LANG.LANG('Comments') ||' : ' || c_cur.COMMENTS || v_Delimiter;
			end if;
			if p_Column_Name = 'ROW_SELECTOR$' then
				v_Help_Text := v_Help_Text || APEX_LANG.LANG('Select rows for Actions') || v_Delimiter;
			elsif p_Column_Name = 'LINK_ID$' then
				v_Help_Text := v_Help_Text || APEX_LANG.LANG('Show details in form page') || v_Delimiter;
			elsif c_cur.IS_BLOB = 'Y'
			or c_cur.IS_AUDIT_COLUMN = 'Y'
			or c_cur.IS_NUMBER_YES_NO_COLUMN = 'Y'
			or c_cur.IS_CHAR_YES_NO_COLUMN = 'Y' then
				if c_cur.IS_BLOB ='Y' then
					v_Help_Text := v_Help_Text
					|| case when c_cur.DATA_TYPE = 'BLOB'
						then APEX_LANG.LANG('File Preview')
						else APEX_LANG.LANG('Large Text Field')
						end
					|| v_Delimiter;
				end if;
				if c_cur.IS_AUDIT_COLUMN ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Audit Information') || v_Delimiter;
				end if;
				if c_cur.IS_NUMBER_YES_NO_COLUMN ='Y'
				or c_cur.IS_CHAR_YES_NO_COLUMN ='Y'  then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Yes / No - Boolean Value') || v_Delimiter;
				end if;

			else
				if c_cur.COLUMN_EXPR_TYPE = 'LINK' then 
					v_Help_Text := v_Help_Text 
					|| APEX_LANG.LANG('Count of References from table') 
					|| ' '
					|| data_browser_conf.Table_Name_To_Header(c_cur.R_VIEW_NAME) 
					|| v_Delimiter;						
				elsif c_cur.IS_REFERENCE != 'N' then 
					v_Help_Text := v_Help_Text 
					|| APEX_LANG.LANG(case when c_cur.IS_REFERENCE = 'C' then 'Container table' else 'Reference to table' end) 
					|| ' '
					|| data_browser_conf.Table_Name_To_Header(c_cur.REF_VIEW_NAME) 
					|| v_Delimiter;											
				elsif c_cur.TABLE_ALIAS != 'A' then -- foreign key field 
                    v_Help_Text := v_Help_Text 
                    || APEX_LANG.LANG(case when c_cur.CHECK_UNIQUE = 'Y' then 'Lookup field for table' else 'Joined field from table' end) 
					|| ' '
                    || data_browser_conf.Table_Name_To_Header(c_cur.REF_VIEW_NAME) 
                    || v_Delimiter;						
				else
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Datatype') || ' : ' 
					|| case when c_cur.DATA_TYPE = 'NUMBER' then 
						'Number (' || NVL(TO_CHAR(c_cur.DATA_PRECISION), '*') || ',' || NVL(TO_CHAR(c_cur.DATA_SCALE), '*') || ')' 
						when c_cur.DATA_TYPE IN ('CHAR', 'VARCHAR', 'VARCHAR2')  then 
							'Text' 
						else 
							INITCAP(c_cur.DATA_TYPE)
					end
					|| v_Delimiter;
				end if;
				if c_cur.CHECK_UNIQUE ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Value must be unique') || v_Delimiter;
				end if;

				if c_cur.IS_ACTIVE_LOV_FILTER ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Active LOV filter field') || v_Delimiter;
				end if;
				if c_cur.IS_HTML_FIELD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('HTML field') || v_Delimiter;
				end if;
				if c_cur.IS_ROW_VERSION_FIELD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Row version field') || v_Delimiter;
				end if;
				if c_cur.IS_ROW_LOCKED_FIELD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Row locked field') || v_Delimiter;
				end if;
				if c_cur.IS_SOFT_DELETED_FIELD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Soft deleted field') || v_Delimiter;
				end if;
				if c_cur.IS_FILE_META_FIELD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('File meta field') || v_Delimiter;
				end if;
				if c_cur.IS_FOLDER_META_FIELD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Folder meta field') || v_Delimiter;
				end if;

				if c_cur.IS_DATA_DEDUCTED ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Data deducted field') || v_Delimiter;
				end if;
				if c_cur.IS_OBFUSCATED ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Data is obfuscated') || v_Delimiter;
				end if;
				if c_cur.IS_READONLY ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Read only field') || v_Delimiter;
				end if;
				if c_cur.IS_VIRTUAL_COLUMN ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Calculated field') || ' : ' || c_cur.DATA_DEFAULT || v_Delimiter;
				elsif c_cur.HAS_DEFAULT = 'Y' then 
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Default value is') || ' : ' || c_cur.DATA_DEFAULT || v_Delimiter;
				end if;

				if c_cur.IS_SUMMAND ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Summand in calculations') || v_Delimiter;
				end if;
				if c_cur.IS_MINUEND ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Minuend in calculations') || v_Delimiter;
				end if;
				if c_cur.IS_FACTOR ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Factor in calculations') || v_Delimiter;
				end if;
				if c_cur.IS_CURRENCY ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Currency value') || v_Delimiter;
				end if;
				
				if c_cur.IS_ORDERING_COLUMN ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Ordering field. You can use the ordering tool in the form view.') || v_Delimiter;
				end if;

				if c_cur.IS_PASSWORD ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Password Field') || v_Delimiter;
				end if;
				if c_cur.REQUIRED ='Y' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('Value is required') || v_Delimiter;
				end if;
				if c_cur.CHAR_LENGTH > 0 then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('The maximum length is') ||' : ' || c_cur.CHAR_LENGTH || v_Delimiter;
				end if;
				if c_cur.FORMAT_MASK IS NOT NULL then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('The format mask is') || ' : '
						|| data_browser_conf.Get_Display_Format_Mask(c_cur.FORMAT_MASK, c_cur.DATA_TYPE) || ' ' || v_Delimiter;
				end if;
				if p_Show_Statistics = 'YES' and c_cur.NUM_DISTINCT IS NOT NULL then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG(
						p_primary_text_string => 'Statistics – Count: %0, Minimum: %1, Maximum: %2, Density: %3, Last analyzed: %4', 
						p0 => c_cur.NUM_DISTINCT, 
						p1 => NVL(c_cur.LOW_VALUE, '--'), 
						p2 => NVL(c_cur.HIGH_VALUE, '--'), 
						p3 => TO_CHAR(c_cur.DENSITY, '99G990D0000'), 
						p4 => APEX_UTIL.GET_SINCE (c_cur.LAST_ANALYZED) 
					) || v_Delimiter;
				end if;
				if c_cur.CHECK_CONDITION IS NOT NULL
				and c_cur.CHECK_CONSTRAINT_NAME != 'AUTOMATICALLY' then
					v_Help_Text := v_Help_Text || APEX_LANG.LANG('The permitted range is') || ' : ' || c_cur.CHECK_CONDITION || v_Delimiter;
				end if;
			end if;
		end loop;

		for c_cur IN ( -- multiple columns checks
			SELECT B.VIEW_NAME, B.CONSTRAINT_NAME, B.CHECK_CONDITION, B.CHECK_UNIQUE,
				LISTAGG(A.COLUMN_HEADER, ', ') WITHIN GROUP (ORDER BY A.COLUMN_ID, A.POSITION) COLUMN_NAMES
			FROM MVDATA_BROWSER_VIEWS T
				, TABLE (data_browser_select.Get_View_Column_Cursor (
					p_Table_Name => T.VIEW_NAME,
					p_Unique_Key_Column => T.SEARCH_KEY_COLS,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => 'ALL',
					p_Join_Options => p_Join_Options,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Visible => 'YES',
					p_Data_Columns_Only => 'NO'
				)) A,
				( select S.VIEW_NAME, S.CONSTRAINT_NAME,
						REGEXP_REPLACE(S.CHECK_CONDITION, '\s+', chr(32)) CHECK_CONDITION,
						S.CHECK_UNIQUE,
						T.COLUMN_VALUE COLUMN_NAME
					FROM MVDATA_BROWSER_CHECKS_DEFS S, TABLE( apex_string.split( S.COLUMN_NAME, ', ') ) T
					where S.VIEW_NAME = p_Table_name
					and S.CONS_COLS_COUNT > 1  -- multiple columns unique constraints
				) B
			WHERE A.R_COLUMN_NAME = B.COLUMN_NAME
			AND T.VIEW_NAME = p_Table_name
			AND A.COLUMN_EXPR_TYPE != 'HIDDEN'
			GROUP BY B.VIEW_NAME, B.CONSTRAINT_NAME, B.CHECK_CONDITION, B.CHECK_UNIQUE
			HAVING SUM(case when A.COLUMN_NAME = p_Column_Name then 1 else 0 end ) > 0
		) loop
			if c_cur.CHECK_UNIQUE ='Y' then
				v_Help_Text := v_Help_Text || c_cur.COLUMN_NAMES || ' - ' || APEX_LANG.LANG('Value combinations must be unique') || v_Delimiter;
			else
				v_Help_Text := v_Help_Text || APEX_LANG.LANG('The condition must be valid') || ' :'
					|| chr(10) || c_cur.CHECK_CONDITION || v_Delimiter;
			end if;
		end loop;

		p_Help_Text := v_Help_Text;
	end Get_Form_Field_Help_Text;

	FUNCTION Get_Column_Default_Value (
		p_Data_Default VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2
	IS
        v_Statement		VARCHAR2(4000);
		v_Result		VARCHAR2(4000);
	begin
		v_Statement :=
		   'begin :b := ' || p_Data_Default || '; end;';
		EXECUTE IMMEDIATE v_Statement USING OUT v_Result;
		return v_Result;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	when others then
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Get_Column_Default_Value %s for %s : failed with : %s',
				p0 => p_Data_Default,
				p1 => p_Column_Name,
				p2 => SQLERRM,
				p_max_length => 3500
			);
		$END
		raise;
$END
	end;

	FUNCTION Get_Apex_Item_Rows_Call (	-- item rows count in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
		p_Caller		VARCHAR2 DEFAULT 'PL_SQL' -- PL_SQL / SQL
	) RETURN VARCHAR2
	is
	begin
		if p_Caller = 'SQL' then
			return 'FN_Get_Apex_Item_Row_Count ('
			|| p_Idx || ', ' || p_Row_Factor || ', ' || p_Row_Offset || ')';
		elsif p_Row_Factor = 1 and p_Row_Offset = 1 then
			return 'apex_application.g_f' || LPAD( p_Idx, 2, '0') || '.count';
		else
			return 'floor((apex_application.g_f' || LPAD( p_Idx, 2, '0') || '.count + '
					|| p_Row_Factor || ' - ' || p_Row_Offset || ') / ' || p_Row_Factor || ')';
		end if;
	end;


	FUNCTION Get_Apex_Item_Call (	-- item name in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number	VARCHAR2 DEFAULT 'p_Row'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		if p_Row_Factor = 1 and p_Row_Offset = 1 and p_Row_Number != 'ROWNUM' then
			return 'apex_application.g_f' || LPAD( p_Idx, 2, '0') || ' (' || p_Row_Number || ')';
        elsif p_Row_Number = 'ROWNUM' then
			return 'FN_Get_Apex_Item_Value ('
			|| p_Idx || ', ' || p_Row_Number
			|| ', ' || p_Row_Factor || ', ' || p_Row_Offset
			|| ')';
		else
			return 'apex_application.g_f' || LPAD( p_Idx, 2, '0')
			|| ' (' || p_Row_Factor || '*(' || p_Row_Number || '-1)+' || p_Row_Offset || ')';
		end if;
	end;

	FUNCTION Get_Apex_Item_Date_Call (	-- item name in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number	VARCHAR2 DEFAULT 'p_Row',
    	p_Format_Mask	VARCHAR2
	) RETURN VARCHAR2
	is
	begin
		return 'FN_Get_Apex_Item_Date_Value ('
		|| p_Idx || ', ' || p_Row_Number
		|| ', ' || p_Row_Factor || ', ' || p_Row_Offset || ',' || Enquote_Literal( p_Format_Mask )
		|| ')';
	end;

	FUNCTION Get_Apex_Item_Ref (	-- item name in apex_application.g_fXX array
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
    	p_Row_Number		NUMBER DEFAULT 1
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Array_Offset NUMBER;
	begin
		v_Array_Offset := p_Row_Factor * (p_Row_Number - 1) + p_Row_Offset;
		return 'apex_application.g_f' || LPAD( p_Idx, 2, '0') || ' (' || v_Array_Offset || ')';
	end;

	FUNCTION Check_Item_Ref (
		p_Column_Ref VARCHAR2,
		p_Column_Name VARCHAR2
	) RETURN VARCHAR2
	IS
        v_Statement		VARCHAR2(4000);
		v_Result 		VARCHAR2(10);
	begin
		if p_Column_Ref IS NOT NULL then
			v_Statement := 'begin :b := case when ' || p_Column_Ref || ' IS NOT NULL then ''YES'' else ''NO'' end; end;';
			EXECUTE IMMEDIATE v_Statement USING OUT v_Result;
			return v_Result;
		end if;
		return 'UNKNOWN';
	exception
	when no_data_found then
		return 'UNKNOWN';
$IF data_browser_conf.g_use_exceptions $THEN
	when others then
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Check_Item_Ref %s check exists : failed with : %s',
				p0 => p_Column_Name,
				p1 => SQLERRM,
				p_max_length => 3500
			);
		$END
		raise;
$END
	end Check_Item_Ref;


	PROCEDURE Clear_Application_Items
	is
		v_Statement VARCHAR2(200);
	begin
        FOR ind IN 1..data_browser_conf.Get_Apex_Item_Limit LOOP
			v_Statement  := 'begin apex_application.g_f' || LPAD( ind, 2, '0') || '.DELETE; end;';
			EXECUTE IMMEDIATE v_Statement;
		END LOOP;
	end Clear_Application_Items;


	PROCEDURE Get_Application_Item (
		p_Index PLS_INTEGER,
		p_Dump 	OUT VARCHAR2,
		p_Count OUT PLS_INTEGER
	)
	is
		v_Column_Ref	VARCHAR2(64);
        v_Statement		VARCHAR2(4000);
	begin
		v_Column_Ref := 'G_F' || LPAD( p_Index, 2, '0');
		v_Statement  := 'begin :b := APEX_UTIL.TABLE_TO_STRING(APEX_APPLICATION.' || v_Column_Ref || '); end;';
		EXECUTE IMMEDIATE v_Statement USING OUT p_Dump;
		v_Statement  := 'begin :b := APEX_APPLICATION.' || v_Column_Ref || '.COUNT; end;';
		EXECUTE IMMEDIATE v_Statement USING OUT p_Count;
	end Get_Application_Item;

	PROCEDURE Dump_Application_Items
	is
		v_Column_Ref	VARCHAR2(64);
		v_Dump 			VARCHAR2(32767);
		v_Count 		PLS_INTEGER;
	begin
		apex_debug.info( p_message => 'data_browser_edit.Dump_Application_Items :');
		FOR ind IN 1..50 LOOP
			v_Column_Ref := 'G_F' || LPAD( ind, 2, '0');
			Get_Application_Item(p_Index => ind, p_Dump => v_Dump, p_Count => v_Count);
			-- if v_Dump IS NOT NULL  then
			if v_Count > 0 then 
				apex_debug.info(v_Column_Ref || '(%s) : %s', v_Count, v_Dump);
			end if;
		END LOOP;
	end Dump_Application_Items;

	FUNCTION Get_Apex_Item_Expr (
		p_Column_Expr_Type VARCHAR2,
		p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
		p_Row_Factor	NUMBER,
		p_Row_Offset	NUMBER,		-- row offset for item index > 50
		p_Column_Alias  VARCHAR2,	-- Column Alias expression
		p_Column_Name	VARCHAR2,	-- Column_Name
		p_Column_Label  VARCHAR2,	-- Column_Name
		p_Column_Expr 	VARCHAR2,	-- Column conversion expression with format mask
		p_Tools_html    VARCHAR2,
		p_Data_Default 	VARCHAR2,
		p_Format_Mask	VARCHAR2,
		p_LOV_Query		VARCHAR2,
		p_Check_Unique	VARCHAR2,
		p_Check_Range	VARCHAR2,
		p_Field_Length 	NUMBER,
		p_Nullable		VARCHAR2,
    	p_Data_Source	VARCHAR2 DEFAULT 'TABLE',	-- NEW_ROWS, TABLE, MEMORY, COLLECTION. if YES or MEMORY then SELECT ... FROM DUAL
    	p_Row_Number	NUMBER DEFAULT 1,
    	p_Report_Mode	VARCHAR2 DEFAULT 'NO',
    	p_Primary_Key_Call VARCHAR2
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Row_Offset 	NUMBER;
		v_Item_Char		VARCHAR2(20);
		v_Item_Id 		VARCHAR2(20);
		v_Button_Size 	NUMBER;
		v_Field_Size 	NUMBER;
		v_Attibutes 	VARCHAR2(1000);
		v_Classes	 	VARCHAR2(1000);
		v_Column_Expr 	VARCHAR2(32767);	 	-- expression to access the data source value
		v_Column_Ref 	VARCHAR2(128);			-- item name in apex_application.g_fXX array --
		v_Column_Value 	VARCHAR2(32767) := ''; 	-- literal field value
		v_Value_Exists  BOOLEAN := FALSE;
		v_Is_Password BOOLEAN := FALSE;
	begin
		v_Button_Size := data_browser_conf.Get_Button_Size(p_Report_Mode => p_Report_Mode, p_Column_Expr_Type => p_Column_Expr_Type);
		v_Field_Size := data_browser_conf.Get_Input_Field_Width(p_Field_Length) - v_Button_Size;
		v_Item_Char  := data_browser_edit.Get_Apex_Item_Cell_ID(
			p_Idx 			=> p_Idx,
			p_Row_Factor	=> p_Row_Factor,
			p_Row_Offset	=> p_Row_Offset,
			p_Row_Number 	=> p_Row_Number,
			p_Data_Source 	=> p_Data_Source,
			p_Item_Type		=> p_Column_Expr_Type
		);
		v_Item_Id := Enquote_Literal(v_Item_Char || '_') || '||ROWNUM';

		if p_Column_Expr_Type NOT IN ('POPUPKEY_FROM_LOV', 'TEXT_EDITOR', 'DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'FILE_BROWSER')
		and (p_Column_Expr_Type NOT IN ('SELECT_LIST', 'SELECT_LIST_FROM_QUERY') or p_Report_Mode = 'NO' )  then
			v_Attibutes := data_browser_conf.Get_Input_Field_Style(p_Field_Length, v_Button_Size, p_Column_Expr_Type);
			if p_Check_Unique = 'Y' or p_Check_Range = 'Y' then
				v_Classes := 'check_range'; 
			elsif p_Check_Unique = 'Y' then 
				v_Classes := data_browser_conf.Concat_List(v_Classes, 'check_unique', ' ');
			elsif p_Nullable = 'N' then 
				v_Classes := data_browser_conf.Concat_List(v_Classes, 'check_required', ' ');
			end if;
		end if;

		-- expression to access the data source value
		if data_browser_select.FN_Apex_Item_Use_Column(p_Column_Expr_Type) = 'YES' then
			v_Column_Expr := p_Column_Alias;
			v_Column_Value := p_Column_Expr;
		else
			v_Column_Expr := p_Column_Expr;
			v_Column_Value := p_Column_Expr;
		end if;
		if p_Data_Source = 'MEMORY' then
			-- when the application has been submitted and validations failed,
			-- then the last entered field values are loaded into the form for further editing.
			if p_Column_Expr_Type = 'DISPLAY_ONLY' then
				v_Column_Value := 'NULL';	-- there exists not storage in the form
				v_Column_Expr := 'NULL';
			elsif p_Column_Expr_Type IN ('ROW_SELECTOR', 'LINK', 'LINK_LIST', 'LINK_ID') then
				v_Column_Value := NVL(p_Primary_Key_Call, 'NULL');
				v_Column_Expr := v_Column_Value;
			elsif p_Column_Expr_Type = 'DATE_POPUP' then
				v_Column_Value := data_browser_edit.Get_Apex_Item_Date_Call (
					p_Idx 			=> p_Idx,
					p_Row_Factor	=> p_Row_Factor,
					p_Row_Offset	=> p_Row_Offset,
					p_Row_Number	=> 'ROWNUM',
					p_Format_Mask 	=> p_Format_Mask
				);
				v_Column_Expr := v_Column_Value;
			else
				v_Column_Value := data_browser_edit.Get_Apex_Item_Call (
					p_Idx 			=> p_Idx,
					p_Row_Factor	=> p_Row_Factor,
					p_Row_Offset	=> p_Row_Offset,
					p_Row_Number	=> 'ROWNUM'
				);
				if p_Column_Expr_Type = 'TEXT_EDITOR' then
					v_Column_Expr := v_Column_Value;
					v_Column_Value := data_browser_blobs.Get_Clob_from_form_call(
						p_Field_Value => v_Column_Value,
						p_Data_Type => 'CHAR'
					);
				else
					v_Column_Expr := v_Column_Value;
				end if;
			end if;
		elsif p_Data_Source = 'NEW_ROWS' then
			if p_Data_Default is not null and p_Column_Expr_Type = 'DATE_POPUP' then
				v_Column_Expr := 'NULL';
				v_Column_Value := p_Data_Default;
			elsif p_Column_Name = 'CONTROL_BREAK$' then
				v_Column_Value := p_Column_Expr;
				v_Column_Expr := v_Column_Value;
			elsif p_Data_Default is not null and p_Column_Expr_Type NOT IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then
				-- data is loaded from column default values
				v_Column_Value := p_Data_Default;
				v_Column_Expr := v_Column_Value;
			else
				v_Column_Value := 'NULL';
				v_Column_Expr := 'NULL';
			end if;
		elsif p_Data_Source = 'COLLECTION' then
			-- in collections all source data is in character format 
			-- and the columns are adressed by ALias A dot column_label.
			-- column_label 
			if p_Column_Name = p_Primary_Key_Call then
				v_Column_Value := 'A.' || p_Column_Name;
				v_Column_Expr := v_Column_Value;
			elsif p_Column_Expr_Type = 'DATE_POPUP' then
				v_Column_Value := 'A.' || p_Column_Name;
				v_Column_Expr := p_Column_Expr;
				--v_Column_Expr := 'FN_TO_DATE(A.' || p_Column_Name || ', ' || Enquote_Literal(p_Format_Mask) || ')';
			elsif p_Column_Name IN ('IMPORTJOB_ID$', 'LINE_NO$') then
				v_Column_Value := v_Column_Expr;
			else
				v_Column_Value := 'A.' || p_Column_Name;
				v_Column_Expr := v_Column_Value;
			end if;
		elsif p_Data_Source = 'QUERY' then
			v_Column_Value := 'A.' || p_Column_Name;
			v_Column_Expr := v_Column_Value;
		elsif v_Column_Value IS NULL then
			v_Column_Value := v_Column_Expr;
		end if;

		if  p_Column_Expr_Type = 'PASSWORD' then
			v_Column_Value := 'NULL';
			v_Classes := data_browser_conf.Concat_List(v_Classes, 'password', ' ') ;
			v_Attibutes := data_browser_conf.Concat_List(v_Attibutes, 'type="password"', ' ');
		end if;

		-- use v_Column_Expr or v_Column_Value as source for the rendered fields.
		return case
		when p_Column_Expr_Type = 'SWITCH_CHAR'
			and v_Column_Expr != 'NULL'
			and data_browser_conf.Get_Apex_Version >= 'APEX_051000' then
			'APEX_ITEM.SWITCH ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_on_value => ') || data_browser_conf.Get_Boolean_Yes_Value('CHAR', 'ENQUOTE')
			|| PA(', p_on_label => ') || data_browser_conf.Get_Boolean_Yes_Value('CHAR', 'TRANSLATE')
			|| PA(', p_off_value => ') || data_browser_conf.Get_Boolean_No_Value('CHAR', 'ENQUOTE')
			|| PA(', p_off_label => ') || data_browser_conf.Get_Boolean_No_Value('CHAR', 'TRANSLATE')
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
		when p_Column_Expr_Type = 'SWITCH_NUMBER'
			and v_Column_Expr != 'NULL'
			and data_browser_conf.Get_Apex_Version >= 'APEX_051000' then
			'APEX_ITEM.SWITCH ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_on_value => ') || data_browser_conf.Get_Boolean_Yes_Value('NUMBER', 'ENQUOTE')
			|| PA(', p_on_label => ') || data_browser_conf.Get_Boolean_Yes_Value('NUMBER', 'TRANSLATE')
			|| PA(', p_off_value => ') || data_browser_conf.Get_Boolean_No_Value('NUMBER', 'ENQUOTE')
			|| PA(', p_off_label => ') || data_browser_conf.Get_Boolean_No_Value('NUMBER', 'TRANSLATE')
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
			-- problems: item switch is not shown in translated app; item help button position is wrong
		when p_Column_Expr_Type IN ('SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER') then
			'APEX_ITEM.SELECT_LIST ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr -- bug with 0/1 boolean codes -- v_Column_Value
			|| PA(', p_list_values => ') || Enquote_Literal(p_LOV_Query)
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('selectlist apex-item-select', v_Classes, ' ') || '" ' || v_Attibutes))
			|| NL(8)
			|| PA(', p_show_null => ') || Enquote_Literal(case when p_Nullable = 'Y' then 'YES' else 'NO' end)
			|| PA(', p_null_value => ') || 'null'
			|| PA(', p_null_text => ')
			|| case when p_Nullable = 'Y' then Enquote_Literal('--')
					else 'apex_lang.lang(' || Enquote_Literal('-select-') || ')'
			end
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| PA(', p_show_extra => ') || Enquote_Literal('YES')
			|| ')'
		when p_Column_Expr_Type = 'SELECT_LIST_FROM_QUERY' then
		-- the ...XL variante delivers CLOB, that is advantageous in order to avoid overflow conditions when a hidden apex items are concatenated,
		-- but it requires special handling when a union with read only views is needed.
		-- Since columns of type clob can not be sorted in the order by clause, the _XL variante is not used
			'APEX_ITEM.SELECT_LIST_FROM_QUERY ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_query => ') || Enquote_Literal(p_LOV_Query)
			|| NL(8)
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('selectlist apex-item-select', v_Classes, ' ') || '" ' || v_Attibutes))
			|| NL(8)
			|| PA(', p_show_null => ') || Enquote_Literal(case when p_Nullable = 'Y' then 'YES' else 'NO' end)
			|| PA(', p_null_value => ') || 'null'
			|| PA(', p_null_text => ') || case when p_Nullable = 'Y' then Enquote_Literal('--')
					else 'apex_lang.lang(' || Enquote_Literal('-select-') || ')' end
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| PA(', p_show_extra => ') || Enquote_Literal('YES')
			|| ')'
		when p_Column_Expr_Type = 'POPUPKEY_FROM_LOV' then
			'APEX_ITEM.POPUPKEY_FROM_QUERY ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_lov_query => ') || Enquote_Literal(p_LOV_Query)
			|| NL(8)
			|| PA(', p_width => ') || v_Field_Size
			|| PA(', p_max_length => ') || p_Field_Length
			|| PA(', p_form_index => ') || Enquote_Literal('0')
			|| PA(', p_escape_html => ') || 'null'
			|| PA(', p_max_elements => ') || 'null'
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('popup_lov apex-item-text', v_Classes, ' ') || '" ' || v_Attibutes))
			|| PA(', p_ok_to_query => ') || Enquote_Literal('YES')
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
			|| NL(4)
			|| '||'
			|| 'APEX_ITEM.HIDDEN (' -- special hidden item to fill the cap caused by POPUPKEY_FROM_LOV
			|| PA('p_idx => ') || (p_Idx + 1) 
			|| ')'
		when p_Column_Expr_Type = 'POPUP_FROM_LOV' then
			'APEX_ITEM.POPUP_FROM_QUERY (' -- text field with popup list
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_lov_query => ') || Enquote_Literal(p_LOV_Query)
			|| NL(8)
			|| PA(', p_width => ') || v_Field_Size
			|| PA(', p_max_length => ') || p_Field_Length
			|| PA(', p_form_index => ') || Enquote_Literal('0')
			|| PA(', p_escape_html => ') || 'null'
			|| PA(', p_max_elements => ') || 'null'
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('popup_lov apex-item-text', v_Classes, ' ') || '" ' || v_Attibutes))
			|| PA(', p_ok_to_query => ') || Enquote_Literal('YES')
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'

		when p_Column_Expr_Type IN ('TEXT', 'NUMBER', 'PASSWORD')  then
			'APEX_ITEM.TEXT ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Value
			|| PA(', p_size => ') || v_Field_Size
			|| PA(', p_maxlength => ') || p_Field_Length
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('text_field apex-item-text', v_Classes, ' ') || '" ' || v_Attibutes))
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
		when p_Column_Expr_Type = 'TEXTAREA' then
			'APEX_ITEM.TEXTAREA ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Value
			|| PA(', p_rows => ') || 'LEAST(CEIL(NVL(LENGTH(' || v_Column_Value || '), 40) / 40), 5)'
			|| PA(', p_cols => ') || '40'
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('textarea apex-item-textarea', v_Classes, ' ') || '" ' || v_Attibutes))
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
		when p_Column_Expr_Type = 'DATE_POPUP' then
			'APEX_ITEM.DATE_POPUP2 ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_date_format => ') || Enquote_Literal(p_Format_Mask)
			|| NL(8)
			|| PA(', p_size => ') || p_Field_Length
			|| PA(', p_maxlength => ') || p_Field_Length
			|| PA(', p_attributes => ') || Enquote_Literal(rtrim('class="' || data_browser_conf.Concat_List('apex-item-text apex-item-datepicker', v_Classes, ' ') || '" ' || v_Attibutes))
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| PA(', p_default_value => ') || case when p_Data_Source = 'NEW_ROWS' then
												v_Column_Value else 'NULL' end
/*			|| ', p_validation_date => ' || case when p_Data_Source IN ('COLLECTION','MEMORY', 'QUERY') then
												 	v_Column_Value -- convert to char 
												else 'NULL' end
*/			|| ')'
		when p_Column_Expr_Type = 'ORDERING_MOVER' then
			'APEX_ITEM.HIDDEN ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_attributes => ') || Enquote_Literal('class="' || v_Classes || '"')
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')||'
			|| NL(8)
			|| Enquote_Literal('<img style="cursor:pointer;" onclick="html_RowDown(this)" src="')
			|| '||V(''IMAGE_PREFIX'')||' || Enquote_Literal('arrow_down_gray_dark.gif" />' || chr(38) || 'nbsp;')
			|| '||'
			|| NL(8)
			|| Enquote_Literal('<img style="cursor:pointer;" onclick="html_RowUp(this)" src="')
			|| '||V(''IMAGE_PREFIX'')||' || Enquote_Literal('arrow_up_gray_dark.gif" />')
		when p_Column_Expr_Type = 'DISPLAY_AND_SAVE' and v_Column_Expr = v_Column_Value then
			'APEX_ITEM.DISPLAY_AND_SAVE ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
		when p_Column_Expr_Type = 'DISPLAY_AND_SAVE' and v_Column_Expr != v_Column_Value then
			'APEX_ITEM.HIDDEN ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_attributes => ') || Enquote_Literal('class="' || v_Classes || '" ')
			|| NL(8)
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')||'
			|| NL(8)
			|| v_Column_Value
		when p_Column_Expr_Type = 'TEXT_EDITOR' then
			'APEX_ITEM.HIDDEN ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_attributes => ') || Enquote_Literal('')
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
			|| case when p_Tools_html IS NOT NULL then
				NL(8)
				|| '||'
				|| p_Tools_html
			end
			|| NL(8)
			|| '||'
			|| data_browser_blobs.FN_Text_Tool_Body_Html (
				p_Column_Label => p_Column_Label || '_' || v_Item_Char,
				p_Column_Expr => case when p_Data_Source IN ('TABLE', 'COLLECTION','MEMORY', 'QUERY') 
								then v_Column_Expr
								else 'NULL' end,
				p_CSS_Class => 'clickable'
			) -- the total length must not exceed 4K
		when p_Column_Expr_Type = 'LINK_ID' and p_Data_Source = 'TABLE' and p_Tools_html IS NOT NULL then
			p_Tools_html
		when p_Column_Expr_Type = 'DISPLAY_ONLY' and p_Field_Length > data_browser_conf.Get_TextArea_Min_Length
		and  p_Column_Name != 'CONTROL_BREAK$' then 
			data_browser_blobs.FN_Text_Tool_Body_Html (
				p_Column_Label => p_Column_Label || '_' || v_Item_Char,
				p_Column_Expr => v_Column_Expr
			)
		when p_Column_Expr_Type IN ('DISPLAY_ONLY', 'LINK', 'LINK_LIST', 'LINK_ID') then
			v_Column_Expr
		when p_Column_Expr_Type = 'ROW_SELECTOR' then
			data_browser_select.Get_Row_Selector_Expr (
				p_Data_Format => 'FORM',
				p_Column_Expr => v_Column_Value,
				p_Column_Name => p_Column_Label
			)
		when p_Column_Expr_Type = 'FILE_BROWSER' then
			NVL(p_Tools_html, v_Column_Expr)
		else
			'APEX_ITEM.HIDDEN ('
			|| PA('p_idx => ') || p_Idx
			|| PA(', p_value => ') || v_Column_Expr
			|| PA(', p_attributes => ') || Enquote_Literal('')
			|| PA(', p_item_id => ') || v_Item_Id
			|| PA(', p_item_label => ') || Enquote_Literal(p_Column_Label)
			|| ')'
		end;
	end Get_Apex_Item_Expr;

	FUNCTION Get_Formated_Default (
		p_Column_Expr_Type VARCHAR2,
		p_Column_Alias  VARCHAR2,
		p_Column_Expr 	VARCHAR2,
		p_Data_Default 	VARCHAR2,
		p_Enquote 		VARCHAR2 DEFAULT 'YES'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Result VARCHAR2(4000);
		v_Column_Expr 	VARCHAR2(4000);
	begin
		if p_Data_Default IS NULL or INSTR(p_Data_Default, DBMS_ASSERT.ENQUOTE_NAME('NEXTVAL')) > 0 then
			v_Result := NULL;
		elsif SUBSTR(p_Data_Default,1,1) = chr(39) then -- default is enquoted value
			if p_Enquote = 'YES' then 
				v_Result := p_Data_Default;
			else 
				v_Result := SUBSTR(p_Data_Default, 2, LENGTH(p_Data_Default) - 2);
			end if;
		else 
			if p_Column_Expr_Type IN ('POPUPKEY_FROM_LOV', 'POPUP_FROM_LOV', 'SELECT_LIST', 'SELECT_LIST_FROM_QUERY', 'DISPLAY_AND_SAVE') 
			or SUBSTR(p_Column_Expr,1,1) = '(' then 
				v_Column_Expr := p_Data_Default;
			else 
			-- replace column reference by default value expression leafing conversions in place
				v_Column_Expr := REPLACE( p_Column_Expr, p_Column_Alias, p_Data_Default );
			end if;
			if p_Enquote = 'YES' then  
				EXECUTE IMMEDIATE 'begin :b := ' || v_Column_Expr || '; end;' USING OUT v_Result;
				v_Result := Enquote_Literal(v_Result);
			else 
				v_Result := v_Column_Expr;
			end if;
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.message(
				p_message => 'Get_Formated_Default(p_Column_Expr_Type=>%s, p_Column_Alias=>%s, p_Column_Expr=>"%s", p_Data_Default=>"%s", p_Enquote=> %s) returns %s',
				p0 => Enquote_Literal(p_Column_Expr_Type),
				p1 => Enquote_Literal(p_Column_Alias),
				p2 => (p_Column_Expr),
				p3 => (p_Data_Default),
				p4 => Enquote_Literal(p_Enquote),
				p5 => (v_Result)
				, p_level => apex_debug.c_log_level_app_trace
			);
		$END
		RETURN v_Result;
	end Get_Formated_Default;

	FUNCTION Get_Form_Edit_Cursor (	-- internal
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',
		p_Select_Columns VARCHAR2 DEFAULT NULL,
		p_Columns_Limit VARCHAR2 DEFAULT 1000,
		p_Exclude_Audit_Columns VARCHAR2 DEFAULT 'NO',
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO, ALL
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, MEMORY, COLLECTION. 
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW and not null, columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,			-- default value for foreign key column
		p_Primary_Key_Call VARCHAR2 DEFAULT NULL,
    	p_Ordering_Column_Tool  VARCHAR2 DEFAULT 'NO', 		-- YES, NO. Enable the rendering of row mover tool icons
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,			-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_File_Page_ID NUMBER DEFAULT NULL,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	    -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL				-- Parameter of target links 
	)
	RETURN data_browser_conf.tab_record_edit PIPELINED
	is
	PRAGMA UDF;
    	v_Describe_Edit_Cols_md5	VARCHAR2(300);
        v_is_cached					VARCHAR2(10);
        v_Export_CSV_Mode			VARCHAR2(10);
		v_Unique_Key_Column  		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
    	v_Row_Version_Column_Name 	MVDATA_BROWSER_VIEWS.ROW_VERSION_COLUMN_NAME%TYPE;
    	v_Key_Cols_Count 			MVDATA_BROWSER_VIEWS.KEY_COLS_COUNT%TYPE;
    	v_Has_Scalar_Key			MVDATA_BROWSER_VIEWS.HAS_SCALAR_KEY%TYPE;
    	v_Key_Column				VARCHAR2(4000);
    	v_Key_Value_Exp				VARCHAR2(4000);
        CURSOR form_view_cur
        IS
			SELECT COLUMN_NAME, TABLE_ALIAS, COLUMN_ID, POSITION, INPUT_ID, DATA_TYPE,
					DATA_PRECISION, DATA_SCALE, CHAR_LENGTH, NULLABLE, IS_PRIMARY_KEY, IS_SEARCH_KEY, IS_FOREIGN_KEY, IS_DISP_KEY_COLUMN,
					REQUIRED, HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, 
					IS_AUDIT_COLUMN, IS_OBFUSCATED, IS_UPPER_NAME,
					IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN, 
					IS_REFERENCE, IS_SEARCHABLE_REF, IS_SUMMAND, IS_VIRTUAL_COLUMN, IS_DATETIME,
					CHECK_UNIQUE, FORMAT_MASK, LOV_QUERY,
					DATA_DEFAULT,
					COLUMN_ALIGN, COLUMN_HEADER,
					COLUMN_EXPR, COLUMN_EXPR_TYPE,
					case when IS_VIRTUAL_COLUMN = 'Y' then 
				    	case p_Data_Source when 'COLLECTION' then DATA_DEFAULT
				    		when 'NEW_ROWS' then 'NULL'
				    		when 'MEMORY' then 'NULL'
				    		else TABLE_ALIAS || '.' || REF_COLUMN_NAME
				    	end
					else 
						data_browser_edit.Get_Apex_Item_Expr(
							p_Column_Expr_Type => COLUMN_EXPR_TYPE,
							p_Idx 			=> APEX_ITEM_IDX,
							p_Row_Factor	=> ROW_FACTOR,
							p_Row_Offset	=> ROW_OFFSET,
							p_Column_Alias	=> data_browser_conf.Get_Link_ID_Expression(
								p_Unique_Key_Column=> REF_COLUMN_NAME, 
								p_Table_Alias=> TABLE_ALIAS, 
								p_View_Mode=> p_View_Mode),
							p_Column_Name   => COLUMN_NAME,
							p_Column_Label  => COLUMN_NAME, 
							p_Column_Expr 	=> -- COLUMN_EXPR, 
								case when p_Data_Source = 'COLLECTION' and DATA_TYPE = 'DATE' 
									then 'FN_TO_DATE(A.' || COLUMN_NAME || ', ' || DBMS_ASSERT.ENQUOTE_LITERAL(FORMAT_MASK) || ')'
								when p_Data_Source = 'COLLECTION' and DATA_TYPE LIKE 'TIMESTAMP%'
									then 'CAST(TO_TIMESTAMP(A.' || COLUMN_NAME || ', ' || DBMS_ASSERT.ENQUOTE_LITERAL(data_browser_conf.Get_Timestamp_Format) || ') AS DATE)'
									else COLUMN_EXPR
								end,
							p_Tools_html	=>
								case when COLUMN_EXPR_TYPE = 'TEXT_EDITOR'
								and p_Data_Source != 'COLLECTION' -- no reference to primary key exists
								and p_Text_Editor_Page_ID IS NOT NULL
								and v_Export_CSV_Mode = 'NO' then
									data_browser_blobs.FN_Edit_Text_Link_Html (
										p_Table_Name => R_VIEW_NAME,
										p_Key_Column => v_Key_Column,
										p_Value => case when p_Data_Source IN ('TABLE', 'QUERY')
																then v_Key_Value_Exp
															when p_Data_Source = 'MEMORY'
																then NVL(p_Primary_Key_Call, 'NULL')
															else 'NULL' end,
										p_Column_Name => R_COLUMN_NAME,
										p_Data_Type => DATA_TYPE,
										p_Page_ID => p_Text_Editor_Page_ID,
										p_Seq_ID  => case when p_Data_Source = 'MEMORY' then
											data_browser_edit.Get_Apex_Item_Call (
												p_Idx 			=> APEX_ITEM_IDX,
												p_Row_Factor	=> ROW_FACTOR,
												p_Row_Offset	=> ROW_OFFSET,
												p_Row_Number	=> 'ROWNUM'
											)
										else 'NULL'
										end,
										p_Selector => p_Text_Tool_Selector
									)
								when COLUMN_EXPR_TYPE = 'FILE_BROWSER'
								and p_Data_Source != 'COLLECTION' -- no reference to primary key exists
								and v_Export_CSV_Mode = 'NO' then
									data_browser_blobs.FN_File_Icon_Link (
										p_Table_Name => R_VIEW_NAME,
										p_Key_Column => v_Key_Column,
										p_Value => case when p_Data_Source IN ('TABLE', 'QUERY')
																then v_Key_Value_Exp
															when p_Data_Source = 'MEMORY'
																then NVL(p_Primary_Key_Call, 'NULL')
															else 'NULL' end,
										p_Page_ID => p_File_Page_ID
									)
								when COLUMN_EXPR_TYPE = 'LINK_ID' 
								and p_Data_Source = 'TABLE' then 
									data_browser_select.Detail_Link_Html (
										p_Data_Format => 'FORM',
										p_Table_name => p_Table_name, 
										p_Parent_Table => p_Parent_Name, 
										p_Link_Page_ID => p_Form_Page_ID, 
										p_Link_Items => DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Form_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_PARENT_ID')),
										p_Key_Value => COLUMN_EXPR,
										p_Parent_Value => p_Parent_Key_Column,
										p_View_Mode => p_View_Mode
									) 
								end ,
							p_Data_Default 	=> case when COLUMN_EXPR_TYPE = 'DATE_POPUP'
												and DATA_DEFAULT IS NOT NULL
													then data_browser_edit.Get_Formated_Default (
															p_Column_Expr_Type => COLUMN_EXPR_TYPE,
															p_Column_Alias  => TABLE_ALIAS || '.' || REF_COLUMN_NAME,
															p_Column_Expr 	=> COLUMN_EXPR,
															p_Data_Default 	=> DATA_DEFAULT,
															p_Enquote		=> 'NO'
														)
													else DATA_DEFAULT
												end,
							p_Format_Mask	=> FORMAT_MASK,
							p_LOV_Query		=> LOV_QUERY,
							p_Check_Unique	=> CHECK_UNIQUE,
							p_Check_Range	=> HAS_RANGE_CHECK,
							p_Field_Length 	=> FIELD_LENGTH,
							p_Nullable		=> NULLABLE,
							p_Data_Source	=> p_Data_Source,
							p_Report_Mode	=> p_Report_Mode,
							p_Primary_Key_Call => case when p_Data_Source = 'COLLECTION' and INPUT_ID BETWEEN 'N001' AND 'N005'
													then COLUMN_NAME
													else p_Primary_Key_Call end
						) 
					end APEX_ITEM_EXPR,
					APEX_ITEM_IDX,
					case when COLUMN_EXPR_TYPE NOT IN ('TEXT_EDITOR', 'DISPLAY_ONLY', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then
						data_browser_edit.Get_Apex_Item_Ref (
							p_Idx 			=> APEX_ITEM_IDX,
							p_Row_Factor	=> ROW_FACTOR,
							p_Row_Offset	=> ROW_OFFSET,
							p_Row_Number	=> 1
						)
					end APEX_ITEM_REF,
					ROW_FACTOR, ROW_OFFSET, APEX_ITEM_CNT,
					FIELD_LENGTH, DISPLAY_IN_REPORT, COLUMN_DATA,
					R_TABLE_NAME, R_VIEW_NAME, R_COLUMN_NAME,
					REF_TABLE_NAME, REF_VIEW_NAME, REF_COLUMN_NAME, COMMENTS
        	FROM (
				SELECT T.COLUMN_NAME, T.TABLE_ALIAS, T.COLUMN_ID, T.COLUMN_ORDER, T.POSITION, T.INPUT_ID, T.DATA_TYPE,
						T.DATA_PRECISION, T.DATA_SCALE, T.CHAR_LENGTH, T.NULLABLE, 
						T.IS_PRIMARY_KEY, T.IS_SEARCH_KEY, T.IS_FOREIGN_KEY, T.IS_DISP_KEY_COLUMN,
						case when (COLUMN_EXPR_TYPE IN ('SELECT_LIST', 'SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV')
										OR IS_CHAR_YES_NO_COLUMN = 'Y'
										OR IS_NUMBER_YES_NO_COLUMN = 'Y')
									AND HAS_DEFAULT = 'Y' 
								then 'N'
							when COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE')
								then 'N'
							else REQUIRED
						end REQUIRED,
						HAS_HELP_TEXT, HAS_DEFAULT, IS_BLOB, IS_PASSWORD, 
						IS_AUDIT_COLUMN, IS_OBFUSCATED, IS_UPPER_NAME,
						IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN, 
						IS_REFERENCE, IS_SEARCHABLE_REF, IS_SUMMAND, IS_VIRTUAL_COLUMN, IS_DATETIME,
						CHECK_UNIQUE, HAS_RANGE_CHECK, FORMAT_MASK, 
						case when COLUMN_EXPR_TYPE IN ('SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV') then
							data_browser_select.Get_Ref_LOV_Query (	-- inject query with filter condition using p_Parent_Key_Item
								p_Table_Name => T.R_VIEW_NAME,
								p_FK_Column_ID => T.COLUMN_ID, 
								p_Column_Name => T.R_COLUMN_NAME, -- required 
								p_Parent_Table => p_Parent_Name,
								p_Parent_Key_Column => p_Parent_Key_Column,
								p_Parent_Key_Item => p_Parent_Key_Item
							)
						when COLUMN_EXPR_TYPE = 'POPUP_FROM_LOV' and LOV_QUERY IS NULL then 
							'select distinct ' || T.COLUMN_EXPR || ' d, ' || T.COLUMN_EXPR || ' r'
							|| ' from ' 
							|| data_browser_select.FN_Table_Prefix
							|| data_browser_conf.Enquote_Name_Required(T.REF_VIEW_NAME) || ' ' || T.TABLE_ALIAS 
							|| ' order by 1'
						else 
							LOV_QUERY
						end LOV_QUERY,
						case 
							when T.IS_VIRTUAL_COLUMN = 'Y' then 
								T.DATA_DEFAULT
							when p_Data_Source IN ('NEW_ROWS', 'COLLECTION')
							and (T.R_VIEW_NAME = p_Table_name and T.REF_COLUMN_NAME = p_Parent_Key_Column
							   or  T.REF_VIEW_NAME = p_Parent_Name and T.REF_COLUMN_NAME = p_Parent_Key_Column 
							   		and E.FILTER_KEY_COLUMN = T.REF_COLUMN_NAME
							) and p_Parent_Key_Item IS NOT NULL then -- passed in default value for foreign key column from p_Parent_Key_Item.
								case when T.DATA_DEFAULT IS NOT NULL then
									'NVL(V(' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Item) || '), ' || T.DATA_DEFAULT || ')' 
								else 
									'V(' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Item) || ')'
								end
								----------------------------------------------------------
							when COLUMN_EXPR_TYPE = 'SWITCH_CHAR' and DATA_DEFAULT IS NULL then
								data_browser_conf.Get_Boolean_No_Value('CHAR', 'ENQUOTE')
							when COLUMN_EXPR_TYPE = 'SWITCH_NUMBER' and DATA_DEFAULT IS NULL then
								data_browser_conf.Get_Boolean_No_Value('NUMBER', 'ENQUOTE')
							when COLUMN_EXPR_TYPE NOT IN ('TEXT_EDITOR', 'DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER', 
														'DATE_POPUP', 'POPUP_FROM_LOV') then
								data_browser_edit.Get_Formated_Default(
									p_Column_Expr_Type => T.COLUMN_EXPR_TYPE,
									p_Column_Alias  => T.TABLE_ALIAS || '.' || T.REF_COLUMN_NAME,
									p_Column_Expr 	=> T.COLUMN_EXPR,
									p_Data_Default 	=> case when T.DATA_DEFAULT IS NULL and T.COLUMN_EXPR_TYPE = 'NUMBER' and T.NULLABLE = 'N'
																then '0'
															when T.IS_SEARCH_KEY = 'Y'
																then NULL
															else T.DATA_DEFAULT
														end,
									p_Enquote		=> 'YES'
								)
							else
								T.DATA_DEFAULT
						end DATA_DEFAULT,
						T.COLUMN_ALIGN,
						T.COLUMN_HEADER, T.COLUMN_EXPR, T.COLUMN_EXPR_TYPE,
						T.FIELD_LENGTH, T.DISPLAY_IN_REPORT, T.COLUMN_DATA,
						T.R_TABLE_NAME, T.R_VIEW_NAME, T.R_COLUMN_NAME,
						T.REF_TABLE_NAME, T.REF_VIEW_NAME, T.REF_COLUMN_NAME, T.COMMENTS,
						case when COLUMN_EXPR_TYPE = 'ROW_SELECTOR' then
							data_browser_conf.Get_Row_Selector_Index
						 when COLUMN_EXPR_TYPE = 'LINK_ID' then
							data_browser_conf.Get_Link_ID_Index
						else
							MOD ((APEX_ITEM_IDX-1), data_browser_conf.Get_Apex_Item_Limit) + 1
						end APEX_ITEM_IDX,	 -- index for apex_application.g_fxx in range 01 to 50
						TRUNC((APEX_ITEM_CNT-1) / data_browser_conf.Get_Apex_Item_Limit) + 1 -- full blocks
						- case when MOD((APEX_ITEM_IDX-1), data_browser_conf.Get_Apex_Item_Limit) + 1 > MOD((APEX_ITEM_CNT-1), data_browser_conf.Get_Apex_Item_Limit) + 1 -- partial blocks
							then 1 else 0 end ROW_FACTOR,
						TRUNC((APEX_ITEM_IDX-1) / data_browser_conf.Get_Apex_Item_Limit) + 1 ROW_OFFSET, -- Usage:  ROW_FACTOR * (ROWNUM - 1) + ROW_OFFSET
						APEX_ITEM_CNT,
						case  when E.FOLDER_NAME_COLUMN_NAME IS NOT NULL
						and E.FOLDER_PARENT_COLUMN_NAME IS NOT NULL then
							'Y' else 'N' 
						end IS_FILE_FOLDER_REF
				FROM (
					SELECT 
						B.COLUMN_NAME, B.TABLE_ALIAS, B.COLUMN_ID, B.COLUMN_ORDER, B.POSITION, B.INPUT_ID, B.DATA_TYPE,
						B.DATA_PRECISION, B.DATA_SCALE, B.CHAR_LENGTH, B.NULLABLE, 
						B.IS_PRIMARY_KEY, B.IS_SEARCH_KEY, B.IS_FOREIGN_KEY, B.IS_DISP_KEY_COLUMN,
						B.REQUIRED,
						B.HAS_HELP_TEXT,
						B.HAS_DEFAULT,
						B.IS_BLOB,
						B.IS_PASSWORD,
						B.IS_AUDIT_COLUMN, B.IS_OBFUSCATED, B.IS_UPPER_NAME,
						B.IS_NUMBER_YES_NO_COLUMN, B.IS_CHAR_YES_NO_COLUMN, 
						B.IS_REFERENCE, B.IS_SEARCHABLE_REF, B.IS_SUMMAND, B.IS_VIRTUAL_COLUMN, 
						B.IS_DATETIME, 
						B.CHECK_UNIQUE,
						/*case when B.DATA_TYPE LIKE 'TIMESTAMP%' and B.IS_DATETIME = 'N' 
							then data_browser_conf.Get_Timestamp_Format(p_Is_DateTime => 'Y')
							else B.FORMAT_MASK
						end FORMAT_MASK,*/
						B.FORMAT_MASK,
						B.LOV_QUERY,
						case when B.DATA_DEFAULT IS NOT NULL then 
							case when B.R_TABLE_NAME = B.REF_TABLE_NAME
							and B.R_COLUMN_NAME = B.REF_COLUMN_NAME then 
								TRIM(TO_CHAR(B.DATA_DEFAULT))
							when  COLUMN_EXPR_TYPE = 'POPUP_FROM_LOV' then
								data_browser_conf.Enquote_Literal (
									data_browser_utl.Lookup_Column_Values (
										p_Table_Name    => B.REF_VIEW_NAME,
										p_Column_Names  => B.REF_COLUMN_NAME,
										p_Search_Key_Col => null,
										p_Search_Value  => data_browser_conf.Dequote_Literal(B.DATA_DEFAULT),
										p_View_Mode		=> p_View_Mode
									)
								)
							else 
								TO_CHAR(B.DATA_DEFAULT)
							end 
						end DATA_DEFAULT,
						case when NOT(B.HAS_AUTOMATIC_CHECK = 'Y'
							and (B.IS_FOREIGN_KEY = 'Y' -- no numeric range check for fk columns.
							  or p_View_Mode NOT IN ('IMPORT_VIEW', 'EXPORT_VIEW') and B.COLUMN_EXPR_TYPE IN ('TEXT', 'TEXT_EDITOR', 'TEXTAREA')))
							then B.HAS_RANGE_CHECK
						end HAS_RANGE_CHECK,
						LOWER(B.COLUMN_ALIGN) COLUMN_ALIGN,
						B.COLUMN_HEADER,
						B.COLUMN_EXPR,
						case 
							when B.COLUMN_EXPR_TYPE IN ( 'NUMBER', 'TEXT' )
							and B.IS_SIMPLE_IN_LIST = 'Y'
									then 'SELECT_LIST'
							when B.COLUMN_EXPR_TYPE = 'ORDERING_MOVER' and p_Ordering_Column_Tool = 'NO'
								then 'NUMBER' -- Disable the rendering of row mover tool icons
							when B.IS_PASSWORD = 'Y'
								then 'PASSWORD'
							when (COLUMN_EXPR_TYPE = 'SELECT_LIST' OR (B.COLUMN_EXPR_TYPE IN ( 'NUMBER', 'TEXT' ) AND B.IS_SIMPLE_IN_LIST = 'Y'))
								and IS_CHAR_YES_NO_COLUMN = 'Y' then 'SWITCH_CHAR'
							when (COLUMN_EXPR_TYPE = 'SELECT_LIST' OR (B.COLUMN_EXPR_TYPE IN ( 'NUMBER', 'TEXT' ) AND B.IS_SIMPLE_IN_LIST = 'Y'))
								and IS_NUMBER_YES_NO_COLUMN = 'Y' then 'SWITCH_NUMBER'
							else
								B.COLUMN_EXPR_TYPE
						end COLUMN_EXPR_TYPE,
						B.FIELD_LENGTH, B.DISPLAY_IN_REPORT, B.COLUMN_DATA,
						B.R_TABLE_NAME, B.R_VIEW_NAME, B.R_COLUMN_NAME,
						B.REF_TABLE_NAME, B.REF_VIEW_NAME, B.REF_COLUMN_NAME, B.COMMENTS,
						SUM(case when B.COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then 0
								when B.COLUMN_EXPR_TYPE IN ('POPUPKEY_FROM_LOV', 'POPUPKEY_FROM_QUERY') then 2
								else 1 end)
							OVER (ORDER BY COLUMN_ORDER RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
						)
						- case when B.COLUMN_EXPR_TYPE IN ('POPUPKEY_FROM_LOV', 'POPUPKEY_FROM_QUERY') then 1 else 0 end
						APEX_ITEM_IDX,
						SUM(case when B.COLUMN_EXPR_TYPE IN ('DISPLAY_ONLY', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then 0
							when B.COLUMN_EXPR_TYPE IN ('POPUPKEY_FROM_LOV', 'POPUPKEY_FROM_QUERY') then 2
							else 1 end) OVER () APEX_ITEM_CNT
					FROM TABLE(data_browser_select.Get_View_Column_Cursor(
							p_Table_name => p_Table_name,
							p_Unique_Key_Column => v_Unique_Key_Column,
							p_Columns_Limit => p_Columns_Limit,
							p_Data_Columns_Only => p_Data_Columns_Only,
							p_Select_Columns => p_Select_Columns,
							p_Join_Options => p_Join_Options,
							p_View_Mode => p_View_Mode,
							p_Report_Mode => p_Report_Mode,
							p_Edit_Mode => 'YES',
							p_Data_Format => case when p_Data_Source = 'COLLECTION' then 'CSV' else data_browser_select.FN_Current_Data_Format end,
							p_Parent_Name => p_Parent_Name,
							p_Parent_Key_Column => p_Parent_Key_Column,
							p_Parent_Key_Visible => p_Parent_Key_Visible,
							p_Link_Page_ID => p_Link_Page_ID,
							p_Link_Parameter => p_Link_Parameter,
							p_Detail_Page_ID => p_Detail_Page_ID,
							p_Detail_Parameter => p_Detail_Parameter
						)
					) B
					WHERE NOT(IS_AUDIT_COLUMN = 'Y' and p_Exclude_Audit_Columns = 'YES')
				) T
				LEFT OUTER JOIN MVDATA_BROWSER_REFERENCES E ON T.R_VIEW_NAME = E.VIEW_NAME AND T.R_COLUMN_NAME = E.COLUMN_NAME
			)
			ORDER BY COLUMN_ORDER;
    	v_Max_Apex_Item_Idx NUMBER := 1;
    	v_Lag_Apex_Item_Idx NUMBER := 1;
    	v_Lag_Column_ID 	NUMBER := 1;
    	v_Check_Column_Idx 	NUMBER := 1;
    	v_Column_Count		NUMBER := 0;
    	v_Build_MD5			CONSTANT BOOLEAN := TRUE;
    	v_Md5_Row_Factor  	PLS_INTEGER := 1;
		v_out_md5 data_browser_conf.rec_record_edit;
	begin
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_Name, p_Unique_Key_Column, p_Data_Columns_Only, p_Select_Columns, p_Columns_Limit, p_Exclude_Audit_Columns, 
			p_View_Mode, p_Report_Mode, p_Join_Options, p_Data_Source, p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, 
			p_Parent_Key_Item, p_Primary_Key_Call, p_Ordering_Column_Tool, p_Text_Editor_Page_Id, p_Text_Tool_Selector, p_File_Page_Id, 
			p_Link_Page_Id, p_Link_Parameter, p_Detail_Page_Id, p_Detail_Parameter, p_Form_Page_Id, p_Form_Parameter;
		$END
    	SELECT SEARCH_KEY_COLS, ROW_VERSION_COLUMN_NAME, KEY_COLS_COUNT, HAS_SCALAR_PRIMARY_KEY
    	INTO v_Unique_Key_Column, v_Row_Version_Column_Name, v_Key_Cols_Count, v_Has_Scalar_Key
    	FROM MVDATA_BROWSER_VIEWS
    	WHERE VIEW_NAME = p_Table_Name;
		v_Export_CSV_Mode := data_browser_conf.Get_Export_CSV_Mode;
		v_Unique_Key_Column := NVL(p_Unique_Key_Column, v_Unique_Key_Column);
		v_Key_Column := case when v_Key_Cols_Count = 1 then v_Unique_Key_Column else 'ROWID' end;
		v_Key_Value_Exp := case when p_Data_Source = 'TABLE' 
			then data_browser_conf.Get_Link_ID_Expression(
				p_Unique_Key_Column=> v_Unique_Key_Column, p_Table_Alias=> 'A', p_View_Mode=> p_View_Mode) 
			else 'A.ROW_SELECTOR$' end;
		if v_Build_MD5 then
			v_out_md5.COLUMN_ID := 0;
			v_out_md5.POSITION := 1;
			v_out_md5.COLUMN_ALIGN := 'left';
			v_out_md5.DATA_TYPE := 'VARCHAR2';
			v_out_md5.CHAR_LENGTH := 128;
			v_out_md5.NULLABLE := 'N';
			v_out_md5.IS_PRIMARY_KEY := 'N';
			v_out_md5.IS_SEARCH_KEY := 'N';
			v_out_md5.IS_FOREIGN_KEY := 'N';
			v_out_md5.IS_DISP_KEY_COLUMN := 'N';
			v_out_md5.REQUIRED := 'Y';
			v_out_md5.HAS_HELP_TEXT := 'N';
			v_out_md5.HAS_DEFAULT := 'N';
			v_out_md5.IS_BLOB := 'N';
			v_out_md5.IS_PASSWORD := 'N';
			v_out_md5.IS_AUDIT_COLUMN := 'N';
			v_out_md5.IS_OBFUSCATED := 'N';
			v_out_md5.IS_UPPER_NAME := 'N';
			v_out_md5.IS_NUMBER_YES_NO_COLUMN := 'N';
			v_out_md5.IS_CHAR_YES_NO_COLUMN := 'N';
			v_out_md5.IS_REFERENCE := 'N';
			v_out_md5.DISPLAY_IN_REPORT := 'N';
			v_out_md5.CHECK_UNIQUE := 'N';
			v_out_md5.COLUMN_EXPR_TYPE := 'HIDDEN';
			v_out_md5.APEX_ITEM_IDX := data_browser_conf.Get_MD5_Column_Index;
			v_out_md5.ROW_FACTOR := 1;
			v_out_md5.ROW_OFFSET := 1;
			v_out_md5.TABLE_ALIAS := 'A';
		end if;
    	v_Describe_Edit_Cols_md5 := wwv_flow_item.md5 (p_Table_name, p_Unique_Key_Column, p_Data_Columns_Only, p_Select_Columns, p_Columns_Limit,
    											p_Exclude_Audit_Columns, p_View_Mode, p_Report_Mode, p_Join_Options, p_Data_Source,
    											p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, p_Parent_Key_Item, p_Primary_Key_Call,
    											p_Ordering_Column_Tool, p_Text_Editor_Page_ID, p_Text_Tool_Selector, p_File_Page_ID, p_Link_Page_ID, p_Link_Parameter,
    											p_Detail_Page_ID, p_Detail_Parameter, p_Form_Page_ID, p_Form_Parameter);
		v_is_cached	:= case when g_Describe_Edit_Cols_md5 != v_Describe_Edit_Cols_md5 then 'load' else 'cached!' end;
		if v_is_cached != 'cached!' then
			OPEN form_view_cur;
			FETCH form_view_cur BULK COLLECT INTO g_Describe_Edit_Cols_tab;
			CLOSE form_view_cur;
			g_Describe_Edit_Cols_md5 := v_Describe_Edit_Cols_md5;
		end if;
		if g_Describe_Edit_Cols_tab.COUNT > 0 then 
			v_Md5_Row_Factor := TRUNC((g_Describe_Edit_Cols_tab(1).APEX_ITEM_CNT-1) / data_browser_conf.Get_Apex_Item_Limit) + 1;
			$IF data_browser_conf.g_debug $THEN
				apex_debug.message(
					p_message => 'data_browser_edit.Get_Form_Edit_Cursor (v_Md5_Row_Factor =>%s) is_cached : %s',
					p0 => v_Md5_Row_Factor,
					p1 => v_is_cached
				);
			$END
			v_Column_Count := 0;
			FOR ind IN 1 .. g_Describe_Edit_Cols_tab.COUNT
			LOOP
				if v_Build_MD5 and v_Lag_Apex_Item_Idx > g_Describe_Edit_Cols_tab(ind).APEX_ITEM_IDX and g_Describe_Edit_Cols_tab(ind).APEX_ITEM_IDX > 0 then
					v_out_md5.ROW_FACTOR := v_Md5_Row_Factor;
					v_out_md5.ROW_OFFSET := v_Check_Column_Idx;
					v_out_md5.APEX_ITEM_CNT := g_Describe_Edit_Cols_tab(ind).APEX_ITEM_CNT;
					v_out_md5.COLUMN_ID := v_Lag_Column_ID;
					v_out_md5.COLUMN_NAME := data_browser_conf.Get_MD5_Column_Name || v_Check_Column_Idx;
					v_out_md5.COLUMN_HEADER := data_browser_conf.Column_Name_to_Header(p_Column_Name => v_out_md5.COLUMN_NAME);
					v_out_md5.APEX_ITEM_REF := data_browser_edit.Get_Apex_Item_Ref (
						p_Idx 			=> data_browser_conf.Get_MD5_Column_Index,
						p_Row_Factor	=> v_out_md5.ROW_FACTOR,
						p_Row_Offset	=> v_out_md5.ROW_OFFSET,
						p_Row_Number	=> 1
					);
					pipe row (v_out_md5);
					v_Check_Column_Idx := v_Check_Column_Idx + 1;
					v_Column_Count := v_Column_Count + 1;
				end if;

				pipe row (g_Describe_Edit_Cols_tab(ind));
				if  g_Describe_Edit_Cols_tab(ind).COLUMN_EXPR_TYPE NOT IN ('DISPLAY_ONLY', 'LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR', 'FILE_BROWSER') then
					v_Lag_Apex_Item_Idx := g_Describe_Edit_Cols_tab(ind).APEX_ITEM_IDX;
					v_Lag_Column_ID := g_Describe_Edit_Cols_tab(ind).COLUMN_ID;
				end if;
				v_Column_Count := v_Column_Count + 1;
			END LOOP;
			if v_Build_MD5 and v_out_md5.COLUMN_ID != v_Lag_Column_ID then
				v_out_md5.ROW_FACTOR := v_Md5_Row_Factor;
				v_out_md5.ROW_OFFSET := v_Check_Column_Idx;
				v_out_md5.COLUMN_ID := v_Lag_Column_ID;
				v_out_md5.COLUMN_NAME := data_browser_conf.Get_MD5_Column_Name || v_Check_Column_Idx;
				v_out_md5.COLUMN_HEADER := data_browser_conf.Column_Name_to_Header(p_Column_Name => v_out_md5.COLUMN_NAME);
				v_out_md5.APEX_ITEM_REF := data_browser_edit.Get_Apex_Item_Ref (
					p_Idx 			=> data_browser_conf.Get_MD5_Column_Index,
					p_Row_Factor	=> v_out_md5.ROW_FACTOR,
					p_Row_Offset	=> v_out_md5.ROW_OFFSET,
					p_Row_Number	=> 1
				);
				pipe row (v_out_md5);
				v_Check_Column_Idx := v_Check_Column_Idx + 1;
				v_Column_Count := v_Column_Count + 1;
			end if;
		end if;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	    if form_view_cur%ISOPEN then
			CLOSE form_view_cur;
		end if;
		raise;
$END
	end Get_Form_Edit_Cursor;



	FUNCTION Get_MD5_Column_Expr (	-- internal
		p_Check_Column_List	VARCHAR2,
		p_Check_Column_Idx INTEGER,
		p_Memory_Exp VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
		v_MD5_Column_Name VARCHAR2(64) := data_browser_conf.Get_MD5_Column_Name || p_Check_Column_Idx;
	begin
		return 'APEX_ITEM.HIDDEN ('
		|| PA('p_idx => ') || data_browser_conf.Get_MD5_Column_Index
		|| PA(', p_value => ')
		|| case when p_Memory_Exp IS NOT NULL then
				p_Memory_Exp
			when p_Check_Column_List IS NOT NULL then
				'WWV_FLOW_ITEM.MD5 ( ' || p_Check_Column_List || ') '
			else
				'NULL '
		end
		|| NL(16)
		|| PA(', p_item_id => ') ||  Enquote_Literal('f' || data_browser_conf.Get_MD5_Column_Index || '_') || ' || ROWNUM '
		|| PA(', p_item_label => ') ||  Enquote_Literal(v_MD5_Column_Name)
		|| ') ';
	end Get_MD5_Column_Expr;

	FUNCTION Get_Form_Edit_Query (							-- internal
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY. if NEW_ROWS or MEMORY then SELECT ... FROM DUAL
    	p_Data_Columns_Only VARCHAR2 DEFAULT 'NO',			-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit NUMBER DEFAULT 1000,
		p_Exclude_Audit_Columns VARCHAR2 DEFAULT 'NO',
		p_View_Mode VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column in View_Mode FORM_VIEW
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
    	p_Ordering_Column_Tool  VARCHAR2 DEFAULT 'NO', 		-- YES, NO. Enable the rendering of row mover tool icons
    	p_Text_Editor_Page_ID NUMBER DEFAULT NULL,			-- Page ID of target links to Text Editor
		p_Text_Tool_Selector VARCHAR2 DEFAULT 'ACTIONS_GEAR',
    	p_Link_Page_ID NUMBER DEFAULT V('APP_PAGE_ID'),	    -- Page ID of target links in View_Mode NAVIGATION_VIEW
		p_Link_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links in View_Mode NAVIGATION_VIEW
    	p_Detail_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
		p_Detail_Parameter VARCHAR2 DEFAULT NULL,			-- Parameter of target links in View_Mode NAVIGATION_VIEW, NESTED_VIEW
    	p_Form_Page_ID NUMBER DEFAULT 32,					-- Page ID of target links 
		p_Form_Parameter VARCHAR2 DEFAULT NULL,				-- Parameter of target links 
    	p_File_Page_ID NUMBER DEFAULT NULL,				    -- Page ID of target links to file preview in View_Mode FORM_VIEW
    	p_Source_Query CLOB DEFAULT NULL, 					-- Passed query for from clause
    	p_Comments VARCHAR2 DEFAULT NULL,					-- Comments
		p_Row_Count 	OUT NUMBER,
		p_Apex_Item_Rows_Call OUT NOCOPY VARCHAR2,
		p_Primary_Key_Call IN OUT NOCOPY VARCHAR2
	) RETURN CLOB
	is
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_Data_Source	VARCHAR2(30) := case when p_Data_Source = 'TABLE' and p_Source_Query IS NOT NULL 
										then 'QUERY' else p_Data_Source end;
        CURSOR form_view_cur
        IS
			select INPUT_ID, COLUMN_NAME, COLUMN_EXPR, COLUMN_EXPR_TYPE, COLUMN_HEADER, APEX_ITEM_EXPR,
				APEX_ITEM_IDX, ROW_FACTOR, ROW_OFFSET, FORMAT_MASK,
				TABLE_ALIAS, R_COLUMN_NAME, REF_COLUMN_NAME, IS_PRIMARY_KEY, IS_SEARCH_KEY, IS_PASSWORD, 
				DATA_TYPE, DATA_DEFAULT, IS_VIRTUAL_COLUMN,
				IS_NUMBER_YES_NO_COLUMN, IS_CHAR_YES_NO_COLUMN
			from TABLE ( data_browser_edit.Get_Form_Edit_Cursor(
					p_Table_name => v_Table_Name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Data_Columns_Only => p_Data_Columns_Only,
					p_Select_Columns => p_Select_Columns,
					p_Exclude_Audit_Columns => p_Exclude_Audit_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_Join_Options => p_Join_Options,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => p_Report_Mode,
					p_Data_Source => v_Data_Source,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_Primary_Key_Call => p_Primary_Key_Call,
					p_Ordering_Column_Tool => p_Ordering_Column_Tool,
					p_Text_Editor_Page_ID => p_Text_Editor_Page_ID,
					p_Text_Tool_Selector => p_Text_Tool_Selector,
					p_Link_Page_ID => p_Link_Page_ID,
					p_Link_Parameter => p_Link_Parameter,
					p_Detail_Page_ID => p_Detail_Page_ID,
					p_Detail_Parameter => p_Detail_Parameter,
					p_Form_Page_ID => p_Form_Page_ID,
					p_Form_Parameter => p_Form_Parameter,
					p_File_Page_ID => p_File_Page_ID
				)
			);
		TYPE form_view_Tab IS TABLE OF form_view_cur%ROWTYPE;
		v_out_tab 		form_view_Tab;
        v_Stat 					CLOB;
		v_Column_Expr 			VARCHAR2(32767);
		v_Map_Unique_Key    	VARCHAR2(32);
		v_Map_Column_List		VARCHAR2(32767);
        v_Check_Column_List		CLOB;
        v_Hidden_Column_List	CLOB;
        v_Hidden_Count	PLS_INTEGER := 0;
        v_Links_Count	PLS_INTEGER := 0;
    	v_Check_Column_Idx NUMBER := 1;
    	v_Build_MD5			CONSTANT BOOLEAN := TRUE;
        v_Str 			VARCHAR2(32767);
        v_Connector     CONSTANT VARCHAR2(50) := '||' || NL(4);
        v_Delimiter     CONSTANT VARCHAR2(50) := ',' || NL(4);
        v_Delimiter2	VARCHAR2(50);
        v_Count			PLS_INTEGER := 0;
        v_Cols_Count	PLS_INTEGER := 0;
        v_Map_Count		PLS_INTEGER := 0;
		v_Row_Count 	PLS_INTEGER := 0;
		v_Apex_Item_Rows_Call VARCHAR2(1024);
		v_Primary_Key_Call 	VARCHAR2(1024);
	begin
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Check_Column_List, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Hidden_Column_List, true, dbms_lob.call);
		OPEN form_view_cur;
		FETCH form_view_cur BULK COLLECT INTO v_out_tab;
		CLOSE form_view_cur;

		FOR ind IN 1 .. v_out_tab.COUNT
		LOOP
			if v_out_tab(ind).APEX_ITEM_IDX = 1 then
				-- when the application has been submitted and validations failed,
				-- then the last entered field values are loaded into the form for further editing.
				v_Row_Count := FN_Get_Apex_Item_Row_Count(
					p_Idx 			=> v_out_tab(ind).APEX_ITEM_IDX,
					p_Row_Factor	=> v_out_tab(ind).ROW_FACTOR,
					p_Row_Offset	=> v_out_tab(ind).ROW_OFFSET
				);
				v_Apex_Item_Rows_Call := data_browser_edit.Get_Apex_Item_Rows_Call(
						p_Idx 			=> v_out_tab(ind).APEX_ITEM_IDX,
						p_Row_Factor	=> v_out_tab(ind).ROW_FACTOR,
						p_Row_Offset	=> v_out_tab(ind).ROW_OFFSET,
						p_Caller		=> 'SQL'
				);
			end if;
			if v_out_tab(ind).IS_SEARCH_KEY = 'Y' then
				v_Primary_Key_Call := data_browser_edit.Get_Apex_Item_Call (
					p_Idx 			=> v_out_tab(ind).APEX_ITEM_IDX,
					p_Row_Factor	=> v_out_tab(ind).ROW_FACTOR,
					p_Row_Offset	=> v_out_tab(ind).ROW_OFFSET,
					p_Row_Number	=> 'ROWNUM'
				);
			end if;
			if v_Build_MD5 and v_out_tab(ind).COLUMN_NAME = data_browser_conf.Get_MD5_Column_Name || v_Check_Column_Idx then
				if DBMS_LOB.GETLENGTH(v_Check_Column_List) > 1 then
					v_Str :=  v_Str		-- add MD5 checksum column
					|| v_Connector
					|| Get_MD5_Column_Expr (
						p_Check_Column_List => v_Check_Column_List,
						p_Check_Column_Idx => v_Check_Column_Idx,
						p_Memory_Exp => case when v_Data_Source = 'MEMORY' then
							data_browser_edit.Get_Apex_Item_Call (
								p_Idx 			=> v_out_tab(ind).APEX_ITEM_IDX,
								p_Row_Factor	=> v_out_tab(ind).ROW_FACTOR,
								p_Row_Offset	=> v_out_tab(ind).ROW_OFFSET,
								p_Row_Number	=> 'ROWNUM'
							)
						end
					);
					DBMS_LOB.TRIM(v_Check_Column_List, 0);
					v_Check_Column_Idx := v_Check_Column_Idx + 1;
					v_Hidden_Count := v_Hidden_Count + 1;
					v_Count := 0;
				end if;
			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'HIDDEN' and v_out_tab(ind).APEX_ITEM_EXPR IS NOT NULL then
				v_Str :=  v_Str			-- add hidden column
				|| v_Connector
				|| v_out_tab(ind).APEX_ITEM_EXPR;
				v_Hidden_Count := v_Hidden_Count + 1;
			end if;
			if v_out_tab(ind).COLUMN_EXPR_TYPE IN ('LINK', 'LINK_LIST') then
				v_Links_Count := v_Links_Count + 1;
			end if;
            if length(v_Str) > 1000 then
            	dbms_lob.writeappend(v_Hidden_Column_List, length(v_Str), v_Str);
            	v_Str := NULL;
            end if;

			if v_Build_MD5
			and v_out_tab(ind).COLUMN_NAME NOT LIKE data_browser_conf.Get_MD5_Column_Name || '%'
			and data_browser_edit.FN_Change_Tracked_Column(v_out_tab(ind).COLUMN_EXPR_TYPE) = 'YES'
			and v_out_tab(ind).TABLE_ALIAS = 'A'
			and v_out_tab(ind).IS_SEARCH_KEY = 'N' then
				v_Count := v_Count + 1;	-- build MD5 checksum column
				v_Cols_Count := v_Cols_Count + 1;
				if v_Data_Source IN ('MEMORY', 'NEW_ROWS') then
					if v_out_tab(ind).COLUMN_EXPR_TYPE = 'DATE_POPUP' then
						v_Column_Expr := 'NULL';	-- avoid usage of default function like localtimestamp in the form.
					else
						v_Column_Expr := NVL(v_out_tab(ind).DATA_DEFAULT, 'NULL');
					end if;
				elsif v_Data_Source = 'QUERY' then -- for types with format mask conversion to char is required!
					if v_out_tab(ind).COLUMN_EXPR_TYPE = 'DATE_POPUP' then
						v_Column_Expr :=  REPLACE(v_out_tab(ind).COLUMN_EXPR, v_out_tab(ind).TABLE_ALIAS || '.' || v_out_tab(ind).REF_COLUMN_NAME, 'A.' || v_out_tab(ind).COLUMN_NAME) ;	
					else
						v_Column_Expr :=  'A.' || v_out_tab(ind).COLUMN_NAME;	
					end if;
				elsif data_browser_edit.FN_Change_Check_Use_Column(v_out_tab(ind).COLUMN_EXPR_TYPE) = 'YES' then
					v_Column_Expr :=  v_out_tab(ind).TABLE_ALIAS || '.' || v_out_tab(ind).R_COLUMN_NAME;
				--elsif v_out_tab(ind).IS_PASSWORD = 'Y' then -- this is wrong because the source are column refs and not form fields
				--	v_Column_Expr := 'NULL'; -- password fields are rendered empty
				else
					v_Column_Expr := v_out_tab(ind).COLUMN_EXPR;
				end if;
				if v_Data_Source = 'COLLECTION' then
					if v_Count = 1 then
						v_Column_Expr := 'NULL';
						dbms_lob.writeappend(v_Check_Column_List, length(v_Column_Expr), v_Column_Expr);
					end if;
				else
					if v_Count > 1 then
						v_Delimiter2 := case when MOD(v_Count, 5) = 0 then NL(16) || ', ' else ', ' end;
						dbms_lob.writeappend(v_Check_Column_List, length(v_Delimiter2), v_Delimiter2);
					end if;
					dbms_lob.writeappend(v_Check_Column_List, length(v_Column_Expr), v_Column_Expr);
				end if;
			end if;
			if v_Data_Source = 'COLLECTION' then
				data_browser_select.Get_Collection_Columns(
					p_Map_Column_List => v_Map_Column_List,
					p_Map_Count => v_Map_Count,
					p_Column_Expr_Type => v_out_tab(ind).COLUMN_EXPR_TYPE,
					p_Data_Type => v_out_tab(ind).DATA_TYPE,
					p_Input_ID => v_out_tab(ind).INPUT_ID,
					p_Column_Name => v_out_tab(ind).COLUMN_NAME,
					p_Default_Value => null,
					p_indent => 4,
					p_Convert_Expr => case 
						when v_out_tab(ind).IS_NUMBER_YES_NO_COLUMN = 'Y' 
							then data_browser_conf.Lookup_Yes_No_Call('NUMBER', 'A.' || v_out_tab(ind).INPUT_ID)
						when v_out_tab(ind).IS_CHAR_YES_NO_COLUMN = 'Y' 
							then data_browser_conf.Lookup_Yes_No_Call('CHAR', 'A.' || v_out_tab(ind).INPUT_ID)
					end,
					p_Is_Virtual_Column => v_out_tab(ind).IS_VIRTUAL_COLUMN
					
				);
				if v_out_tab(ind).COLUMN_NAME = p_Unique_Key_Column then 
					v_Map_Unique_Key := v_out_tab(ind).INPUT_ID;
				end if;
			end if;
        end loop;

		p_Row_Count := v_Row_Count;
		p_Apex_Item_Rows_Call := v_Apex_Item_Rows_Call;
		p_Primary_Key_Call := v_Primary_Key_Call;
    	v_Count := v_Hidden_Count;
		if v_Build_MD5
		and DBMS_LOB.GETLENGTH(v_Check_Column_List) > 0 then
			v_Str :=  v_Str
			|| v_Connector
			|| Get_MD5_Column_Expr (
					p_Check_Column_List => v_Check_Column_List,
					p_Check_Column_Idx => v_Check_Column_Idx,
					p_Memory_Exp => case when v_Data_Source = 'MEMORY' then
						data_browser_edit.Get_Apex_Item_Call (
							p_Idx 			=> data_browser_conf.Get_MD5_Column_Index,
							p_Row_Factor	=> v_Check_Column_Idx,
							p_Row_Offset	=> 1,
							p_Row_Number	=> 'ROWNUM'
						)
					end
			);
			v_Hidden_Count := v_Hidden_Count + 1;
		end if;
		if length(v_Str) > 0 then
			dbms_lob.writeappend(v_Hidden_Column_List, length(v_Str), v_Str);
		end if;

    	v_Str := 'SELECT ' || CM(p_Comments) || NL(4);
    	v_Cols_Count := 0;
		FOR ind IN 1 .. v_out_tab.COUNT
		LOOP
			if v_out_tab(ind).COLUMN_EXPR_TYPE != 'HIDDEN' then
				v_Count := v_Count + 1;
				v_Cols_Count := v_Cols_Count + 1;
				v_Str :=  v_Str
				|| case when v_Cols_Count > 1 then v_Delimiter end
				|| v_out_tab(ind).APEX_ITEM_EXPR;
				if v_Hidden_Count > 0 and v_out_tab(ind).COLUMN_EXPR_TYPE NOT IN ('TEXT_EDITOR', 'DISPLAY_ONLY', 'LINK', 'LINK_LIST', 'LINK_ID', 'FILE_BROWSER') then
					-- The block of hidden apex items is appended to the first active column.
					-- The 'ROW_SELECTOR' column is a good location to append the hidden columns,
					-- because appending them to column of type SELECT_LIST or SELECT_LOV  can cause overflow conditions for maximal string length or maximum
					-- and the 'ROW_SELECTOR' column is not sortable.
	            	dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
					dbms_lob.append(v_Stat, v_Hidden_Column_List);
					v_Str := NULL;
					v_Hidden_Count := 0;
				end if;
				v_Str :=  v_Str
				|| ' ' || v_out_tab(ind).COLUMN_NAME;
			end if;

            if length(v_Str) > 1000 then
            	dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
            	v_Str := NULL;
            end if;
        end loop;

		if v_Data_Source = 'QUERY' then
        	v_Str := v_Str || chr(10) || ' FROM ' || '(';
        	dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        	dbms_lob.append(v_Stat, p_Source_Query);
        	v_Str := ') A';
        	dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        else
			if v_Data_Source IN ('MEMORY', 'NEW_ROWS') then
				v_Str := v_Str || chr(10) || 'FROM DUAL ';
			elsif v_Data_Source = 'COLLECTION' then
				v_Str := v_Str || chr(10) || 'FROM '
				|| data_browser_select.Get_Collection_Query (
					p_Map_Column_List => v_Map_Column_List,
					p_Map_Unique_Key => v_Map_Unique_Key,
					p_indent => 4
				)
				|| ' A ';
			else
				if p_View_Mode IN ('FORM_VIEW', 'RECORD_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW') then
					v_Str := v_Str || chr(10) || ' FROM ' || data_browser_conf.Enquote_Name_Required(v_Table_Name)
					|| ' A '
					|| case when v_Links_Count > 0 
						--and p_View_Mode IN ('FORM_VIEW', 'NAVIGATION_VIEW', 'NESTED_VIEW') 
						and v_Data_Source IN ('TABLE', 'QUERY') then
						', (SELECT '
						-- P30_TABLE_NAME,P30_PARENT_NAME,P30_PARENT_KEY_ID,P30_PARENT_KEY_COLUMN
						|| DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Detail_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID')) || ' TARGET1, '
						-- P30_PARENT_NAME,P30_GRAND_PARENT_NAME,P30_PARENT_KEY_ID,P30_TABLE_NAME,P30_PARENT_KEY_COLUMN
						|| DBMS_ASSERT.ENQUOTE_LITERAL(NVL(p_Link_Parameter, 'P32_TABLE_NAME,P32_PARENT_NAME,P32_LINK_ID,P32_DETAIL_TABLE,P32_DETAIL_KEY'))
						|| ' TARGET2 FROM DUAL) PAR '
					end;
				elsif p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
					for c_cur in (
						SELECT SQL_TEXT
						FROM TABLE (
							data_browser_joins.Get_Detail_Table_Joins_Cursor(
								p_Table_name => v_Table_Name,
								p_As_Of_Timestamp => 'NO',
								p_Join_Options => p_Join_Options
							)
						)
					) loop
						v_Str := v_Str || chr(10) || c_cur.SQL_TEXT;
					end loop;
				end if;
			end if;
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;

		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Get_Form_Edit_Query (%s %s %s) Array_Count is : %s, Query is : %s',
				p0 => p_Table_name,
				p1 => v_Data_Source,
				p2 => p_Unique_Key_Column,
				p3 => v_Row_Count,
				p4 => v_Stat,
				p_max_length => 3500
			);
		$END
		return v_Stat;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	    if form_view_cur%ISOPEN then
			CLOSE form_view_cur;
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'FAILED - data_browser_edit.Get_Form_Edit_Query %s %s %s : %s',
				p0 => p_Table_name,
				p1 => v_Data_Source,
				p2 => p_Unique_Key_Column,
				p3 => v_Stat,
				p_max_length => 3500
			);
		$END
		raise;
$END
	end Get_Form_Edit_Query;


    FUNCTION Get_Form_Foreign_Keys_PLSQL (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'IMPORT_VIEW',		-- IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_DML_Command VARCHAR2 DEFAULT 'UPDATE',			-- INSERT, UPDATE, LOOKUP
		p_Row_Number NUMBER DEFAULT 1,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES',
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Exec_Phase NUMBER DEFAULT 0
    ) RETURN CLOB
    IS
		v_Row_Number 	PLS_INTEGER := 1;	--	used for form validation
		v_Apex_Item_Rows_Call VARCHAR2(1024);
		v_Init_Key_Stat	VARCHAR2(1024);
		v_Compare_Case_Insensitive	VARCHAR2(10);
		v_Search_Keys_Unique		VARCHAR2(10);
		v_Insert_Foreign_Keys		VARCHAR2(10);
		v_use_NLS_params CONSTANT VARCHAR2(1) := 'Y';

        CURSOR form_view_cur
        IS
		-- process foreign_keys of target table
		WITH REFERENCES_Q AS (
			SELECT E.REF_VIEW_NAME R_VIEW_NAME, E.COLUMN_NAME, E.REF_COLUMN_NAME, E.TABLE_ALIAS, E.COLUMN_HEADER,
				E.APEX_ITEM_IDX, E.COLUMN_EXPR_TYPE, E.ROW_FACTOR, E.ROW_OFFSET, E.INPUT_ID, E.IS_REFERENCE
			FROM TABLE ( data_browser_edit.Get_Form_Edit_Cursor (
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => 'YES',
					p_Join_Options => p_Join_Options,
					p_Data_Source => p_Data_Source,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item
				)
			) E
			WHERE (E.TABLE_ALIAS != 'A' OR E.TABLE_ALIAS IS NULL OR E.COLUMN_EXPR_TYPE = 'HIDDEN')
		)
		, PARENT_LOOKUP_Q AS (
			SELECT DISTINCT S.COLUMN_NAME, IMP_COLUMN_NAME,
				case when p_Data_Source = 'COLLECTION' then
					LTRIM(SUBSTR(F.INPUT_ID, 2), '0')
				else
					data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=> F.APEX_ITEM_IDX,
						p_Row_Factor	=> F.ROW_FACTOR,
						p_Row_Offset	=> F.ROW_OFFSET,
						p_Row_Number	=> 'p_Row'
					)
				end D_REF,
				SUBSTR(F.INPUT_ID, 1, 1) D_REF_TYPE, -- C,N
				case when p_Data_Source = 'COLLECTION' then
					LTRIM(SUBSTR(E.INPUT_ID, 2), '0')
				else
					data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=> E.APEX_ITEM_IDX,
						p_Row_Factor	=> E.ROW_FACTOR,
						p_Row_Offset	=> E.ROW_OFFSET,
						p_Row_Number	=> 'p_Row'
					)
				end S_REF,
				SUBSTR(E.INPUT_ID, 1, 1) S_REF_TYPE -- C,N
			FROM (
				SELECT DISTINCT
					--+ INDEX(Q) USE_NL_WITH_INDEX(S)
					Q.TABLE_NAME, Q.VIEW_NAME, Q.SEARCH_KEY_COLS, Q.SHORT_NAME,
					Q.FOREIGN_KEY_COLS 	COLUMN_NAME,
                    Q.VIEW_NAME         S_VIEW_NAME,
                    Q.PARENT_KEY_COLUMN,
					Q.TABLE_ALIAS 		TABLE_ALIAS, 
					S.R_VIEW_NAME 		D_VIEW_NAME,
					S.IMP_COLUMN_NAME
				FROM MVDATA_BROWSER_F_REFS S
                --, (SELECT 'SW_FILES' v_Table_name, 'NO' p_As_Of_Timestamp, 'FORM' p_Data_Format FROM DUAL ) PAR
				, TABLE(data_browser_select.FN_Pipe_browser_q_refs(
					p_View_Name => S.VIEW_NAME, p_Data_Format => 'FORM')) Q 
				where Q.VIEW_NAME = S.VIEW_NAME
					and Q.FOREIGN_KEY_COLS = S.FOREIGN_KEY_COLS
					and Q.TABLE_ALIAS = S.TABLE_ALIAS
					and Q.J_VIEW_NAME = S.R_VIEW_NAME
					and Q.J_COLUMN_NAME = S.R_COLUMN_NAME
				and S.VIEW_NAME = p_Table_name
			) S
			JOIN REFERENCES_Q E ON E.R_VIEW_NAME = S.S_VIEW_NAME AND E.COLUMN_NAME = S.PARENT_KEY_COLUMN
			JOIN REFERENCES_Q F ON F.R_VIEW_NAME = S.D_VIEW_NAME AND F.COLUMN_NAME = S.IMP_COLUMN_NAME
            -- , (SELECT 1 v_Row_Number, 'COLLECTION' p_Data_Source FROM DUAL) PAR
		)
		SELECT
			TO_CLOB(data_browser_conf.NL(8) || 'if '
			|| case when p_DML_Command IN ('INSERT', 'LOOKUP', 'SAVE') then 
				case when p_Data_Source = 'COLLECTION' then 'p_cur.'||T.INPUT_ID else D_REF end
				|| ' IS NULL ' 
				|| data_browser_conf.NL(8) 
				|| 'AND ' -- is lookup required
			end
			|| '(')					-- are all/some terms known
			|| LISTAGG(S_REF || ' IS NOT NULL',
				data_browser_conf.NL(8) 
				|| case when HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0 then 'OR ' else 'AND ' end
			) WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION) -- conditions to trigger the search of foreign keys
			|| ') then ' || data_browser_conf.NL(10)
			|| 'begin ' 
			--------------------------------------------------------------------------------------------
			|| data_browser_conf.NL(12) -- find foreign key values
			|| 'begin ' || data_browser_conf.NL(14) -- try insert
			|| case when MAX(IS_FILE_FOLDER_REF) = 'N' then 
			   'SELECT ' || T.TABLE_ALIAS || '.' || T.R_PRIMARY_KEY_COLS || ' INTO '
				|| case when p_Data_Source = 'COLLECTION' then 
						case when T.D_REF_TYPE = 'N' then 'v_NResult' else 'v_CResult' end
					else D_REF end
				|| data_browser_edit.CM(' /* FK_Count:' || SUM(S_HAS_FOREIGN_KEY) || ', Cols_Cnt:' || T.U_MEMBERS || ' */ ') 
				|| data_browser_conf.NL(14)
				|| 'FROM ' || data_browser_conf.Enquote_Name_Required(T.R_VIEW_NAME) || ' ' || T.TABLE_ALIAS || ' '
				|| data_browser_conf.NL(14)
				|| 'WHERE '
				|| LISTAGG(
						case when (HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0) AND T.U_MEMBERS > 1
						then '('
							|| data_browser_conf.Get_Compare_Case_Insensitive(
									p_Column_Name 	=> T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME,
									p_Element 		=> T.S_REF,
									p_Element_Type	=> T.S_REF_TYPE,
									p_Data_Source	=> p_Data_Source,
									p_Data_Type 	=> T.R_DATA_TYPE,
									p_Data_Precision=> T.R_DATA_PRECISION,
									p_Data_Scale 	=> T.R_DATA_SCALE,
									p_Format_Mask	=> T.FORMAT_MASK,
									p_Use_Group_Separator => case when COLUMN_EXPR_TYPE = 'HIDDEN' then 'N' else 'Y' end,
									p_Compare_Case_Insensitive => v_Compare_Case_Insensitive
								)
							|| ' OR '
							|| case when T.R_NULLABLE = 'Y' then T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME || ' IS NULL AND ' end
							|| S_REF || ' IS NULL)'
						else
							data_browser_conf.Get_Compare_Case_Insensitive(
								p_Column_Name 	=> T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME,
								p_Element 		=> T.S_REF,
								p_Element_Type	=> T.S_REF_TYPE,
								p_Data_Source	=> p_Data_Source,
								p_Data_Type 	=> T.R_DATA_TYPE,
								p_Data_Precision=> T.R_DATA_PRECISION,
								p_Data_Scale 	=> T.R_DATA_SCALE,
								p_Format_Mask	=> T.FORMAT_MASK,
								p_Use_Group_Separator => case when COLUMN_EXPR_TYPE = 'HIDDEN' then 'N' else 'Y' end,
								p_Compare_Case_Insensitive => v_Compare_Case_Insensitive
							)
						end,
					data_browser_conf.NL(14) || 'AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION)
			else 
				 data_browser_select.Key_Path_Lookup_Query (
					p_Table_Name  			=> T.R_VIEW_NAME,
					p_Search_Key_Col  		=> T.R_PRIMARY_KEY_COLS,
					p_Search_Path   		=> MIN(T.S_REF),
					p_Search_Value   		=> case when p_Data_Source = 'COLLECTION' then 
												case when T.D_REF_TYPE = 'N' then 'v_NResult' else 'v_CResult' end
											else D_REF end,
					p_Folder_Par_Col_Name  	=> MAX(T.FOLDER_PARENT_COLUMN_NAME),
					p_Folder_Name_Col_Name  => MAX(T.FOLDER_NAME_COLUMN_NAME),
					p_Folder_Cont_Col_Name  => MAX(T.FOLDER_CONTAINER_COLUMN_NAME),
					p_Folder_Cont_Alias 	=> MAX(T.FOLDER_CONTAINER_REF),
					p_Level 				=> 2
				)
			end 
			|| ';'
			|| case when p_Data_Source = 'COLLECTION' then
				data_browser_conf.NL(14) 
				|| 'apex_collection.update_member_attribute(p_collection_name => v_Data_Collection, p_seq => p_Row, p_attr_number => ' 
				|| D_REF 
				|| case when T.D_REF_TYPE = 'N' then 
					', p_number_value => v_NResult);'
				else
					', p_attr_value => v_CResult);'
				end 
				|| data_browser_edit.CM(' /* ' || T.COLUMN_NAME || ' */ ')
				|| data_browser_conf.NL(12)
				|| case when D.DEFAULTS_MISSING = 0
				and MAX(IS_FILE_FOLDER_REF) = 'N'
				and v_Insert_Foreign_Keys = 'YES'
				and data_browser_utl.Check_Edit_Enabled(p_Table_Name => T.R_VIEW_NAME, p_View_Mode => p_View_Mode) = 'YES' then
					-- INSERT new values ---------------------------------------------------------------------
					'exception when NO_DATA_FOUND then' || data_browser_conf.NL(14)
					|| 'INSERT INTO ' || T.R_VIEW_NAME || '('
					|| LISTAGG(T.R_COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION)
					|| ')' || data_browser_conf.NL(14)
					|| 'VALUES ('
					|| LISTAGG( 
						data_browser_conf.Get_Char_to_Type_Expr (
							p_Element 		=> S_REF,
							p_Element_Type	=> S_REF_TYPE,
							p_Data_Source	=> p_Data_Source,
							p_Data_Type 	=> T.R_DATA_TYPE,
							p_Data_Scale 	=> T.R_DATA_SCALE,
							p_Format_Mask 	=> T.FORMAT_MASK,
							p_Use_Group_Separator => 'Y',
							p_use_NLS_params => v_use_NLS_params
						)
						, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION)
					|| ')' || data_browser_conf.NL(14)
					|| 'RETURNING (' || T.R_PRIMARY_KEY_COLS || ') INTO ' 
					|| case when T.D_REF_TYPE = 'N' then 'v_NResult' else 'v_CResult' end || ';' 
					|| data_browser_edit.CM(' /* ' || T.COLUMN_NAME || ' */ ')
					|| data_browser_conf.NL(14)
					|| 'apex_collection.update_member_attribute(p_collection_name => v_Data_Collection, p_seq => p_Row, p_attr_number => ' 
					|| D_REF 
					|| case when T.D_REF_TYPE = 'N' then 
						', p_number_value => v_NResult);'
					else
						', p_attr_value => v_CResult);'
					end 
					|| data_browser_edit.CM(' /* ' || T.COLUMN_NAME || ' */ ')
					|| data_browser_conf.NL(12)
					|| 'end;' 
					-- copy the lookup result to other members of the same container
					--------------------------------------------------------------------
					|| (
						select LISTAGG(
							data_browser_conf.NL(12) 
							|| case when P.D_REF_TYPE = 'N' and T.D_REF_TYPE = 'C' then
								'v_NResult := TO_NUMBER(v_CResult);'|| data_browser_conf.NL(12) 
							when P.D_REF_TYPE = 'C' and T.D_REF_TYPE = 'N' then
								'v_CResult := TO_CHAR(v_NResult);'|| data_browser_conf.NL(12) 
							end
							|| 'apex_collection.update_member_attribute(p_collection_name => v_Data_Collection, p_seq => p_Row, p_attr_number => ' 
							|| P.D_REF 
							|| case when P.D_REF_TYPE = 'N' then -- type of first destination has to be used 
								', p_number_value => v_NResult);'
							else
								', p_attr_value => v_CResult);'
							end
							|| data_browser_edit.CM(' /* ' || P.IMP_COLUMN_NAME || ' */ ')
							, ' '
						) WITHIN GROUP (ORDER BY P.IMP_COLUMN_NAME)
						from PARENT_LOOKUP_Q P 
						where P.S_REF = T.D_REF and P.S_REF_TYPE = T.D_REF_TYPE
						and P.D_REF IS NOT NULL
					)
					----------------------------------------------------------------------------------------
					|| data_browser_conf.NL(12)
					|| 'exception when OTHERS then' || data_browser_conf.NL(14)
				when p_DML_Command = 'LOOKUP' 
				and data_browser_utl.Check_Edit_Enabled(p_Table_Name => T.R_VIEW_NAME, p_View_Mode => p_View_Mode) = 'YES' then
					'end;' || data_browser_conf.NL(10)
					|| 'exception when NO_DATA_FOUND or TOO_MANY_ROWS then' || data_browser_conf.NL(12)
					|| 'null;' 
					|| data_browser_conf.NL(10)
					|| 'when OTHERS then' || data_browser_conf.NL(12)
				else
					-- 'exception when NO_DATA_FOUND or TOO_MANY_ROWS then' || data_browser_conf.NL(12)
					'end;' || data_browser_conf.NL(12)
					|| 'exception when OTHERS then' || data_browser_conf.NL(14)
				end
			else ------- p_Data_Source != 'COLLECTION'------------------------------------------------------
				data_browser_conf.NL(12)
					|| case when D.DEFAULTS_MISSING = 0
					and MAX(IS_FILE_FOLDER_REF) = 'N'
					and v_Insert_Foreign_Keys = 'YES'
					and data_browser_utl.Check_Edit_Enabled(p_Table_Name => T.R_VIEW_NAME, p_View_Mode => p_View_Mode) = 'YES'  then
					-- INSERT new values ---------------------------------------------------------------------
					'exception when NO_DATA_FOUND then' || data_browser_conf.NL(14)
					|| 'INSERT INTO ' || T.R_VIEW_NAME || '('
					|| LISTAGG(T.R_COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION)
					|| ')' || data_browser_conf.NL(14)
					|| 'VALUES ('
					|| LISTAGG( data_browser_conf.Get_Char_to_Type_Expr (
									p_Element 		=> T.S_REF,
									p_Data_Type 	=> T.R_DATA_TYPE,
									p_Data_Scale 	=> T.R_DATA_SCALE,
									p_Format_Mask 	=> T.FORMAT_MASK,
									p_use_NLS_params => v_use_NLS_params
								)
						, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION)
					|| ')' || data_browser_conf.NL(14)
					|| 'RETURNING (' || T.R_PRIMARY_KEY_COLS || ') INTO ' || T.D_REF || ';' 
					|| data_browser_edit.CM(' /* ' || T.COLUMN_NAME || ' */ ')
					|| data_browser_conf.NL(12)
					|| 'end;' || data_browser_conf.NL(10)
					|| (
						select LISTAGG(
							'  '
							|| P.D_REF 
							|| ' := '
							|| T.D_REF || ';'
							|| data_browser_edit.CM(' /* ' || P.IMP_COLUMN_NAME || ' */ ')
							|| data_browser_conf.NL(10) 
							, ''
						) WITHIN GROUP (ORDER BY P.IMP_COLUMN_NAME)
						from PARENT_LOOKUP_Q P 
						where P.S_REF = T.D_REF and P.S_REF_TYPE = T.D_REF_TYPE
						and P.D_REF IS NOT NULL
					)
					----------------------------------------------------------------------------------------
					|| 'exception when OTHERS then' || data_browser_conf.NL(12)
				else 
					-- 'exception when NO_DATA_FOUND or TOO_MANY_ROWS then' || data_browser_conf.NL(12)
					'end;' || data_browser_conf.NL(10)
					|| 'exception when OTHERS then' || data_browser_conf.NL(12)
				end -- INSERT --
			end
			|| 
			data_browser_edit.add_error_call (
				p_Column_Name => T.COLUMN_NAME,
				p_Apex_Item_Cell_Id => MIN(T.APEX_ITEM_CELL_ID),
				p_Message => 'Lookup for "%0" failed. - Error : %1.',
				p_Column_Header => LISTAGG(T.COLUMN_HEADER, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID, POSITION),
				p1 => 'DBMS_UTILITY.FORMAT_ERROR_STACK',
				p_Class => case when p_DML_Command = 'LOOKUP' then 'DATA' else 'LOOKUP' end
			)
			|| data_browser_conf.NL(10)
			|| 'end;' || data_browser_conf.NL(8)
			|| case when p_DML_Command = 'UPDATE' and p_Data_Source != 'COLLECTION' then
				'else' || data_browser_conf.NL(12)
				|| D_REF || ' := NULL;' || data_browser_conf.NL(8)
			end
			|| 'end if;'
			|| chr(10)
			SQL_TEXT
		FROM
		(
			SELECT DISTINCT S.TABLE_NAME, S.VIEW_NAME, S.SEARCH_KEY_COLS, S.SHORT_NAME,
				S.COLUMN_NAME, F.INPUT_ID,
				case when p_Data_Source = 'COLLECTION' then
					LTRIM(SUBSTR(F.INPUT_ID, 2), '0')
				else
					data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=> F.APEX_ITEM_IDX,
						p_Row_Factor	=> F.ROW_FACTOR,
						p_Row_Offset	=> F.ROW_OFFSET,
						p_Row_Number	=> 'p_Row'
					)
				end D_REF,
				SUBSTR(F.INPUT_ID, 1, 1) D_REF_TYPE, -- C,N
				case when p_Data_Source = 'COLLECTION' then
					'p_cur.' || E.INPUT_ID
				else
					data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=> E.APEX_ITEM_IDX,
						p_Row_Factor	=> E.ROW_FACTOR,
						p_Row_Offset	=> E.ROW_OFFSET,
						p_Row_Number	=> 'p_Row'
					)
				end S_REF,
				SUBSTR(E.INPUT_ID, 1, 1)  S_REF_TYPE, -- C,N
				S.IS_FILE_FOLDER_REF,
				S.FOLDER_PARENT_COLUMN_NAME,
				S.FOLDER_NAME_COLUMN_NAME,
				S.FOLDER_CONTAINER_COLUMN_NAME,
				case when S.IS_FILE_FOLDER_REF = 'Y' then
					case when p_Data_Source = 'COLLECTION' then
						'p_cur.' || FC.INPUT_ID
					when FC.APEX_ITEM_IDX IS NOT NULL then
						data_browser_edit.Get_Apex_Item_Call (
							p_Idx 			=> FC.APEX_ITEM_IDX,
							p_Row_Factor	=> FC.ROW_FACTOR,
							p_Row_Offset	=> FC.ROW_OFFSET,
							p_Row_Number	=> 'p_Row'
						)
					end 
				end FOLDER_CONTAINER_REF,
				data_browser_edit.Get_Apex_Item_Ref (
					p_Idx 			=> F.APEX_ITEM_IDX,
					p_Row_Factor	=> F.ROW_FACTOR,
					p_Row_Offset	=> F.ROW_OFFSET,
					p_Row_Number	=> v_Row_Number
				) D_ITEM_REF,
				data_browser_edit.Get_Apex_Item_Ref (
					p_Idx 			=> E.APEX_ITEM_IDX,
					p_Row_Factor	=> E.ROW_FACTOR,
					p_Row_Offset	=> E.ROW_OFFSET,
					p_Row_Number	=> v_Row_Number
				) S_ITEM_REF,
				data_browser_edit.Get_Apex_Item_Cell_ID(
					p_Idx 			=> E.APEX_ITEM_IDX,
					p_Row_Factor	=> E.ROW_FACTOR,
					p_Row_Offset	=> E.ROW_OFFSET,
					p_Row_Number 	=> 1,
					p_Data_Source 	=> p_Data_Source,
					p_Item_Type 	=> E.COLUMN_EXPR_TYPE
				) APEX_ITEM_CELL_ID,
				S.R_PRIMARY_KEY_COLS, S.R_CONSTRAINT_TYPE,
				S.R_VIEW_NAME, S.COLUMN_ID, S.NULLABLE,
				S.R_COLUMN_ID, S.POSITION, S.R_COLUMN_NAME, S.R_NULLABLE, S.R_DATA_TYPE,
				S.R_DATA_PRECISION, S.R_DATA_SCALE, S.R_CHAR_LENGTH, S.IS_DATETIME,
				data_browser_conf.Get_Col_Format_Mask(
					p_Data_Type 		=> S.R_DATA_TYPE,
					p_Data_Precision 	=> S.R_DATA_PRECISION,
					p_Data_Scale 		=> S.R_DATA_SCALE,
					p_Char_Length 		=> S.R_CHAR_LENGTH,
					p_Datetime			=> S.IS_DATETIME
				) FORMAT_MASK,
				S.TABLE_ALIAS,
				S.IMP_COLUMN_NAME S_COLUMN_NAME, E.COLUMN_HEADER,
				S.JOIN_CLAUSE,
				S.HAS_NULLABLE, S.HAS_SIMPLE_UNIQUE, S.U_CONSTRAINT_NAME, S.U_MEMBERS,
				E.APEX_ITEM_IDX, E.ROW_FACTOR, E.ROW_OFFSET, E.COLUMN_EXPR_TYPE,
				case when E.IS_REFERENCE = 'N' then 0 else 1 end S_HAS_FOREIGN_KEY
			FROM (
				-- 2. level foreign keys
				SELECT 	VIEW_NAME, TABLE_NAME, SEARCH_KEY_COLS, SHORT_NAME, COLUMN_NAME, 
					S_VIEW_NAME, S_REF, D_VIEW_NAME, D_REF, 
					IS_FILE_FOLDER_REF, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME, 
					FILTER_KEY_COLUMN, PARENT_KEY_COLUMN, 
					R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, COLUMN_ID, NULLABLE, 
					R_COLUMN_ID, R_COLUMN_NAME, POSITION, R_NULLABLE, R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, 
					R_CHAR_LENGTH, IS_DATETIME, TABLE_ALIAS, IMP_COLUMN_NAME, JOIN_CLAUSE, 
					HAS_NULLABLE, HAS_SIMPLE_UNIQUE, 
					HAS_FOREIGN_KEY, U_CONSTRAINT_NAME, U_MEMBERS, POSITION2		
				FROM 
					-- (SELECT 'SW_FILES' p_Table_name, 'NO' p_As_Of_Timestamp FROM DUAL ) PAR,
					TABLE(data_browser_select.FN_Pipe_table_imp_fk2 (p_Table_name, p_As_Of_Timestamp))
				UNION
				-- 1. level foreign keys
				SELECT 	VIEW_NAME, TABLE_NAME, SEARCH_KEY_COLS, SHORT_NAME, COLUMN_NAME, 
					S_VIEW_NAME, S_REF, D_VIEW_NAME, D_REF, 
					IS_FILE_FOLDER_REF, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME, 
					FILTER_KEY_COLUMN, PARENT_KEY_COLUMN, 
					R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, COLUMN_ID, NULLABLE, 
					R_COLUMN_ID, R_COLUMN_NAME, POSITION, R_NULLABLE, R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, 
					R_CHAR_LENGTH, IS_DATETIME, TABLE_ALIAS, IMP_COLUMN_NAME, JOIN_CLAUSE, 
					HAS_NULLABLE, HAS_SIMPLE_UNIQUE, 
					HAS_FOREIGN_KEY, U_CONSTRAINT_NAME, U_MEMBERS, POSITION2		
				FROM 
					-- (SELECT 'SW_FILES' p_Table_name, 'NO' p_As_Of_Timestamp FROM DUAL ) PAR,
					TABLE(data_browser_select.FN_Pipe_table_imp_fk1 (p_Table_name))
			) S
			JOIN REFERENCES_Q E ON E.R_VIEW_NAME = S.S_VIEW_NAME AND E.REF_COLUMN_NAME = S.R_COLUMN_NAME
				AND (E.TABLE_ALIAS = S.TABLE_ALIAS OR E.TABLE_ALIAS IS NULL)
				AND (E.REF_COLUMN_NAME != S.FOLDER_CONTAINER_COLUMN_NAME OR S.FOLDER_CONTAINER_COLUMN_NAME IS NULL)
			JOIN REFERENCES_Q F ON F.R_VIEW_NAME = S.D_VIEW_NAME AND F.COLUMN_NAME = S.D_REF
			LEFT OUTER JOIN REFERENCES_Q FC ON FC.R_VIEW_NAME = S.S_VIEW_NAME AND FC.REF_COLUMN_NAME = S.FOLDER_CONTAINER_COLUMN_NAME
			-- , (SELECT 1 v_Row_Number, 'COLLECTION' p_Data_Source FROM DUAL) PAR
		) T
		JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = T.VIEW_NAME
		JOIN ( -- count of missing defaults for foreign key table
			SELECT --+ INDEX(S) USE_NL_WITH_INDEX(C)
				S.VIEW_NAME, COUNT(DISTINCT C.COLUMN_ID) DEFAULTS_MISSING
			FROM MVDATA_BROWSER_VIEWS S -- foreign key table
			LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C ON S.VIEW_NAME = C.VIEW_NAME
			AND C.NULLABLE = 'N' AND C.HAS_DEFAULT ='N' AND C.IS_READONLY = 'N'
            AND  NOT EXISTS (
                SELECT 'X'
                FROM  TABLE( apex_string.split(S.SEARCH_KEY_COLS, ', ') ) P
                WHERE C.COLUMN_NAME = P.COLUMN_VALUE
            )
			AND NOT EXISTS (
				SELECT 1
				FROM MVDATA_BROWSER_D_REFS R
				WHERE R.TABLE_NAME = S.VIEW_NAME
				AND R.COLUMN_NAME = C.COLUMN_NAME
				UNION ALL
				SELECT 1
				FROM MVDATA_BROWSER_U_REFS R
				WHERE R.VIEW_NAME = S.VIEW_NAME
				AND R.COLUMN_NAME = C.COLUMN_NAME
				AND R.RANK = 1
			)
			GROUP BY S.VIEW_NAME
		) D ON D.VIEW_NAME = T.R_VIEW_NAME
		-- , (SELECT 'SW_FILES' p_Table_name, 'YES' p_Use_Empty_Columns, 0 p_Exec_Phase, 'COLLECTION' p_Data_Source, 'Y' v_use_NLS_params, 'UPDATE' p_DML_Command, 'ID' p_Unique_Key_Column
		-- , 'NO' v_Compare_Case_Insensitive, 'NO' v_Search_Keys_Unique, 'YES' v_Insert_Foreign_Keys, 'IMPORT_VIEW' p_View_Mode FROM DUAL ) PAR
		WHERE R_COLUMN_ID IS NOT NULL
		AND S.VIEW_NAME = p_Table_name
		AND (p_Use_Empty_Columns = 'YES'
		OR (data_browser_edit.Check_Item_Ref (S_ITEM_REF, T.S_COLUMN_NAME) != 'UNKNOWN'
		AND data_browser_edit.Check_Item_Ref (D_ITEM_REF, T.COLUMN_NAME) != 'UNKNOWN'))
		GROUP BY T.TABLE_NAME, S.HAS_SCALAR_PRIMARY_KEY, S.SEARCH_KEY_COLS,
			D.DEFAULTS_MISSING, T.TABLE_ALIAS, T.R_PRIMARY_KEY_COLS,
			T.COLUMN_NAME, T.INPUT_ID, 
			T.R_VIEW_NAME, T.COLUMN_ID, S.SHORT_NAME,
			T.HAS_NULLABLE, T.HAS_SIMPLE_UNIQUE, U_MEMBERS, 
			T.NULLABLE, D_REF, D_REF_TYPE
            -- , p_Table_name, p_Use_Empty_Columns, p_Exec_Phase, p_Data_Source, p_DML_Command, p_Unique_Key_Column
            -- , v_Compare_Case_Insensitive, v_Search_Keys_Unique, v_Insert_Foreign_Keys, p_View_Mode
		HAVING (MAX(T.U_CONSTRAINT_NAME) IS NOT NULL or v_Search_Keys_Unique = 'NO')
		AND NOT(p_Exec_Phase = 1 AND SUM(S_HAS_FOREIGN_KEY) > 0)
		AND NOT(p_Exec_Phase = 2 AND SUM(S_HAS_FOREIGN_KEY) = 0)
		ORDER BY SUM(S_HAS_FOREIGN_KEY), T.TABLE_ALIAS DESC, T.U_MEMBERS, T.COLUMN_ID, T.D_REF;
        v_Stat 				CLOB;
        v_Result_PLSQL		CLOB;
        v_Str 				VARCHAR2(32767);
    	v_Procedure_Name 	VARCHAR2(50);
		v_Unique_Key_Column MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
    begin
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_Name, p_Unique_Key_Column, p_Select_Columns, p_Columns_Limit, p_View_Mode, p_Join_Options, p_Data_Source, 
				p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, p_Parent_Key_Item, p_Dml_Command, p_Row_Number, 
				p_Use_Empty_Columns, p_As_Of_Timestamp, p_Exec_Phase;
		$END
		if p_Unique_Key_Column IS NULL then
			SELECT SEARCH_KEY_COLS
			INTO v_Unique_Key_Column
			FROM MVDATA_BROWSER_VIEWS
			WHERE VIEW_NAME = p_Table_Name;
		else
			v_Unique_Key_Column := p_Unique_Key_Column;
		end if;
		data_browser_conf.Get_Import_Parameter( v_Compare_Case_Insensitive, v_Search_Keys_Unique, v_Insert_Foreign_Keys);
		if p_DML_Command = 'LOOKUP' then 
			v_Insert_Foreign_Keys := 'NO';
			v_Search_Keys_Unique := 'NO';
		end if;
    	if p_View_Mode IN ('IMPORT_VIEW', 'EXPORT_VIEW') then
	    	dbms_lob.createtemporary(v_Result_PLSQL, true, dbms_lob.call);
			dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
			OPEN form_view_cur;
			LOOP
				FETCH form_view_cur INTO v_Str;
				EXIT WHEN form_view_cur%NOTFOUND;
				dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
			END LOOP;
			CLOSE form_view_cur;
		end if;

		if DBMS_LOB.GETLENGTH(v_Stat) > 1 then
			for c_cur IN (
					SELECT R_VIEW_NAME, R_COLUMN_NAME, COLUMN_NAME, COLUMN_HEADER, 
						REQUIRED, CHECK_UNIQUE, FORMAT_MASK, DATA_TYPE, DATA_SCALE, TABLE_ALIAS,
						IS_PRIMARY_KEY, IS_SEARCH_KEY, APEX_ITEM_IDX, ROW_FACTOR, ROW_OFFSET, APEX_ITEM_REF, INPUT_ID,
						case when p_Data_Source = 'COLLECTION' then
							'p_cur.' || INPUT_ID
						else
							data_browser_edit.Get_Apex_Item_Call (
								p_Idx 			=> APEX_ITEM_IDX,
								p_Row_Factor	=> ROW_FACTOR,
								p_Row_Offset	=> ROW_OFFSET,
								p_Row_Number	=> 'p_Row'
							)
						end APEX_ITEM_CALL
					FROM TABLE (data_browser_edit.Get_Form_Edit_Cursor (
							p_Table_Name => p_Table_name,
							p_Unique_Key_Column => v_Unique_Key_Column,
							p_Select_Columns => p_Select_Columns,
							p_Columns_Limit => p_Columns_Limit,
							p_View_Mode => p_View_Mode,
							p_Report_Mode => 'YES',
							p_Join_Options => p_Join_Options,
							p_Data_Source => p_Data_Source,
							p_Parent_Name => p_Parent_Name,
							p_Parent_Key_Column => p_Parent_Key_Column,
							p_Parent_Key_Visible => p_Parent_Key_Visible,
							p_Parent_Key_Item => p_Parent_Key_Item
						)
					)
					WHERE APEX_ITEM_REF IS NOT NULL
					AND NOT(INPUT_ID IS NULL and p_Data_Source = 'COLLECTION')
					AND APEX_ITEM_IDX != data_browser_conf.Get_MD5_Column_Index
			) loop
				if c_cur.APEX_ITEM_IDX = 1 then
					v_Apex_Item_Rows_Call := data_browser_edit.Get_Apex_Item_Rows_Call(
							p_Idx 			=> c_cur.APEX_ITEM_IDX,
							p_Row_Factor	=> c_cur.ROW_FACTOR,
							p_Row_Offset	=> c_cur.ROW_OFFSET
					);
				end if;
				if c_cur.IS_SEARCH_KEY = 'Y' and (c_cur.R_COLUMN_NAME = v_Unique_Key_Column OR v_Unique_Key_Column IS NULL) then
					v_Init_Key_Stat := 'v_Key_Value := ' || c_cur.APEX_ITEM_CALL || ';' || chr(10);
				end if;
			end loop;
			v_Procedure_Name := INITCAP(data_browser_conf.Compose_Table_Column_Name(p_Table_name, 'Lookup_FK'));
			if p_Data_Source = 'COLLECTION' then
				dbms_lob.append (v_Result_PLSQL,
					'declare ' || NL(4) ||
						'v_Data_Collection varchar(100) := ' || data_browser_conf.Get_Import_Collection('YES') || '; ' || NL(4) ||
						'v_Err_Collection varchar(100) := ' || data_browser_conf.Get_Import_Error_Collection('YES') || '; ' || NL(4) ||
						'v_Error_Message varchar2(32767);' || NL(4) ||
					'procedure ' || v_Procedure_Name || ' ( p_cur APEX_COLLECTIONS%ROWTYPE, p_Row number )' || NL(4) ||
					'is' || NL(8) ||
						'v_Key_Value varchar2(4000);' || NL(8) ||
						'v_CResult varchar2(4000);' || NL(8) ||
						'v_NResult number;' || NL(8) ||
						declare_error_call(p_Table_name, p_Unique_Key_Column) || 
					'begin ' || NL(8) ||
					v_Init_Key_Stat
				);
			else
				dbms_lob.append (v_Result_PLSQL,
					'declare ' || NL(4) ||
						'v_Row_Number PLS_INTEGER := 1; ' || NL(4) ||
						'v_Row_Count  PLS_INTEGER := ' || v_Apex_Item_Rows_Call || '; ' || NL(4) ||
						'v_Err_Collection varchar(100) := ' || data_browser_conf.Get_Lookup_Collection(p_Enquote=>'YES') || '; ' || NL(4) ||
						'v_Error_Message varchar2(32767);' || NL(4) ||
					'procedure ' || v_Procedure_Name || ' ( p_Row number )' || NL(4) ||
					'is' || NL(8) ||
						'v_Key_Value varchar2(4000);' || NL(8) ||
						declare_error_call(p_Table_name, p_Unique_Key_Column) || 
					'begin ' || NL(8) ||
					v_Init_Key_Stat
				);
			end if;
			dbms_lob.append (v_Result_PLSQL, v_Stat);

			dbms_lob.append (v_Result_PLSQL,
				RPAD(' ', 4) ||
				'end;' || chr(10) ||
				'begin' || NL(4)
			);
			if p_Data_Source = 'COLLECTION' then
				if p_Exec_Phase < 2 then 
					dbms_lob.append (v_Result_PLSQL,
						'apex_collection.create_or_truncate_collection(v_Err_Collection);' || NL(4)
					);
				end if;
				dbms_lob.append (v_Result_PLSQL,
					'for c_cur IN (SELECT * FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = v_Data_Collection) loop ' || NL(8) ||
						v_Procedure_Name || ' ( c_cur, p_Row => c_cur.seq_id );' || NL(4) ||
					'end loop;' || NL(4)
				);
			else
				dbms_lob.append (v_Result_PLSQL,
					'apex_collection.create_or_truncate_collection(v_Err_Collection);' || NL(4) ||
					'for v_Row_Number IN 1 ..v_Row_Count loop '  || NL(8) ||
						v_Procedure_Name || ' ( p_Row => v_Row_Number );' || NL(4) ||
					'end loop;' || NL(4)
				);
			end if;
			dbms_lob.append (v_Result_PLSQL,
				'commit;' || NL(4) ||
				'for c_cur IN (SELECT C006 row_num, C007 msg FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = v_Err_Collection AND C008 = ''LOOKUP'' AND ROWNUM <= '
				|| data_browser_conf.Get_Errors_Listed_Limit || ') loop '  || NL(8) ||
					'v_Error_Message := v_Error_Message || c_cur.row_num  || '':'' || c_cur.msg || chr(10) || ''<br />'';' || NL(4) ||
				'end loop;' || NL(4) ||
				':t := v_Error_Message;' || chr(10) ||
				'end;' || chr(10)
			);

			$IF data_browser_conf.g_debug $THEN
				apex_debug.message(
					p_message => 'data_browser_edit.Get_Form_Foreign_Keys_PLSQL _result: %s',
					p0 => v_Result_PLSQL,
					p_max_length => 3500
				);
			$END
			RETURN v_Result_PLSQL;
		end if;
		RETURN NULL;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	    if form_view_cur%ISOPEN then
			CLOSE form_view_cur;
		end if;
		raise;
$END
	end Get_Form_Foreign_Keys_PLSQL;

	FUNCTION Validate_Form_Foreign_Keys (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'IMPORT_VIEW',		-- IMPORT_VIEW, EXPORT_VIEW
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_DML_Command VARCHAR2 DEFAULT 'UPDATE',			-- INSERT, UPDATE, LOOKUP
		p_Row_Number NUMBER DEFAULT 1,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES',
		p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
		p_Exec_Phase NUMBER DEFAULT 0
	) RETURN VARCHAR2
	is
		v_Result_PLSQL CLOB;
		v_Error_Message VARCHAR2(32767);
	begin
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_Name, p_Unique_Key_Column, p_Data_Source, p_Select_Columns, p_Columns_Limit, p_View_Mode, p_Join_Options, 
				p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, p_Parent_Key_Item, p_Dml_Command, p_Row_Number, 
				p_Use_Empty_Columns, p_As_Of_Timestamp, p_Exec_Phase;
		$END
    	dbms_lob.createtemporary(v_Result_PLSQL, true, dbms_lob.call);    	
		v_Result_PLSQL := data_browser_edit.Get_Form_Foreign_Keys_PLSQL(
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Join_Options => p_Join_Options,
			p_Data_Source => p_Data_Source,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_DML_Command => p_DML_Command,
			p_Row_Number => p_Row_Number,
			p_Use_Empty_Columns => p_Use_Empty_Columns,
			p_As_Of_Timestamp => p_As_Of_Timestamp,
			p_Exec_Phase => p_Exec_Phase
		);
		if DBMS_LOB.GETLENGTH(v_Result_PLSQL) > 1 then
			EXECUTE IMMEDIATE v_Result_PLSQL USING OUT v_Error_Message;
			if v_Error_Message IS NOT NULL then
				v_Error_Message := v_Error_Message || '<br />' || chr(10);
			end if;
			commit;
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Validate_Form_Foreign_Keys (p_Table_name => %s, p_Data_Source => %s, p_Exec_Phase => %s,' || chr(10)
				|| ' v_Error_Message=> %s, getlength(v_Result_PLSQL) => %s), Import_Collection_Count => %s, Error_Collection_Count => %s',
				p0 => p_Table_name,
				p1 => p_Data_Source,
				p2 => p_Exec_Phase,
				p3 => v_Error_Message,
				p4 => DBMS_LOB.GETLENGTH(v_Result_PLSQL),
				p5 => APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name => data_browser_conf.Get_Import_Collection),
				p6 => APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name => data_browser_conf.Get_Import_Error_Collection),
				p_max_length => 3500
			);
		$END
		return v_Error_Message;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	  	v_Error_Message := SQLERRM;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Validate_Form_Foreign_Keys (p_Table_name => %s, p_Data_Source => %s, v_Error_Message=> %s)',
				p0 => p_Table_name,
				p1 => p_Data_Source,
				p2 => v_Error_Message,
				p_max_length => 3500
			);
		$END
	    commit;
		return v_Error_Message;
		-- return apex_lang.lang('Foreign keys lookup for table %0 failed with %1.', p_Table_name, SQLERRM);
$END
	end Validate_Form_Foreign_Keys;

	PROCEDURE Get_Form_Changed_Check (						-- internal
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
		p_Data_Source VARCHAR2 DEFAULT 'TABLE', 			-- NEW_ROWS, TABLE, COLLECTION, MEMORY
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES',
		p_Changed_Check_Condition OUT NOCOPY CLOB,
		p_Changed_Check_Plsql OUT NOCOPY CLOB
	)
	is
		v_Column_Ref 	VARCHAR2(4000);
		v_Column_Expr 	VARCHAR2(32767);
        v_Check_Column_List	CLOB;
        v_Check_Values_List	CLOB;
        v_Changed_Check_Condition	CLOB;
        v_Changed_Check_Plsql	CLOB;
    	v_Check_Column_Idx NUMBER := 1;
		v_Count 		PLS_INTEGER := 0;
		v_Count_Cols	PLS_INTEGER := 0;
		v_Count_FK 		PLS_INTEGER := 0;
		v_Row_Number 	PLS_INTEGER := 1;	--	used for form validation
    	v_Value_Exists  VARCHAR2(10);
		v_Delimiter2	VARCHAR2(50);
	begin
    	dbms_lob.createtemporary(v_Check_Column_List, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Check_Values_List, true, dbms_lob.call);
        FOR c_cur IN (
			SELECT COLUMN_NAME, COLUMN_EXPR, COLUMN_EXPR_TYPE, IS_PRIMARY_KEY, IS_SEARCH_KEY, APEX_ITEM_IDX,
					ROW_FACTOR, ROW_OFFSET, DATA_TYPE, DATA_SCALE, FORMAT_MASK, IS_PASSWORD,
					TABLE_ALIAS, R_COLUMN_NAME, DATA_DEFAULT,
					data_browser_edit.Get_Apex_Item_Ref (
						p_Idx 			=> APEX_ITEM_IDX,
						p_Row_Factor	=> ROW_FACTOR,
						p_Row_Offset	=> ROW_OFFSET,
						p_Row_Number	=> v_Row_Number
					) APEX_ITEM_REF,
					data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=> APEX_ITEM_IDX,
						p_Row_Factor	=> ROW_FACTOR,
						p_Row_Offset	=> ROW_OFFSET,
						p_Row_Number	=> 'p_Row'
					) APEX_ITEM_CALL
			FROM TABLE ( data_browser_edit.Get_Form_Edit_Cursor(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => p_Report_Mode,
					p_Join_Options => p_Join_Options,
					p_Data_Source => p_Data_Source,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item
				)
			)
			WHERE data_browser_edit.FN_Change_Tracked_Column(COLUMN_EXPR_TYPE) = 'YES'
			AND TABLE_ALIAS = 'A'
        )
        loop
			v_Value_Exists := case when p_Use_Empty_Columns = 'YES' then 'YES'
								else data_browser_edit.Check_Item_Ref (c_cur.APEX_ITEM_REF, c_cur.COLUMN_NAME) end;
			exit when v_Value_Exists = 'UNKNOWN';
            if c_cur.IS_SEARCH_KEY = 'N' 
            then
				if c_cur.COLUMN_NAME = data_browser_conf.Get_MD5_Column_Name || v_Check_Column_Idx then
					if DBMS_LOB.GETLENGTH(v_Check_Column_List) > 0 then
						v_Changed_Check_Condition := v_Changed_Check_Condition
						|| case when v_Changed_Check_Condition IS NOT NULL then NL(12) || ' AND ' end
						|| 'wwv_flow_item.md5 ( ' || v_Check_Column_List || ') = ' || c_cur.APEX_ITEM_CALL;
						v_Changed_Check_Plsql := v_Changed_Check_Plsql
						|| case when v_Changed_Check_Plsql IS NOT NULL then NL(12) || ' AND ' end
						|| 'wwv_flow_item.md5 ( ' || v_Check_Values_List || ') = ' || c_cur.APEX_ITEM_CALL;
					end if;
					DBMS_LOB.TRIM(v_Check_Column_List, 0);
					DBMS_LOB.TRIM(v_Check_Values_List, 0);
					v_Count := 0;
					v_Check_Column_Idx := v_Check_Column_Idx + 1;
				else
					v_Count := v_Count + 1;
					v_Count_Cols := v_Count_Cols + 1;
					if c_cur.R_COLUMN_NAME = p_Parent_Key_Column and c_cur.TABLE_ALIAS = 'A' then
						v_Count_FK := v_Count_FK + 1;
					end if;
					v_Column_Expr := case
						when data_browser_edit.FN_Change_Check_Use_Column(c_cur.COLUMN_EXPR_TYPE) = 'YES' then
							c_cur.TABLE_ALIAS || '.' || c_cur.R_COLUMN_NAME
						else
							c_cur.COLUMN_EXPR
					end;
					
					if v_Count > 1 then
						v_Delimiter2 := case when MOD(v_Count, 5) = 0 then NL(20) || ', ' else ', ' end;
						dbms_lob.writeappend(v_Check_Column_List, length(v_Delimiter2), v_Delimiter2);
						dbms_lob.writeappend(v_Check_Values_List, length(v_Delimiter2), v_Delimiter2);
					end if;
					dbms_lob.writeappend(v_Check_Column_List, length(v_Column_Expr), v_Column_Expr);
					dbms_lob.writeappend(v_Check_Values_List, length(c_cur.APEX_ITEM_CALL), c_cur.APEX_ITEM_CALL);
				end if;
			end if;
        end loop;
        if v_Count > 1 then
			v_Column_Ref  := data_browser_edit.Get_Apex_Item_Call (
				p_Idx 			=> data_browser_conf.Get_MD5_Column_Index,
				p_Row_Factor	=> 1,
				p_Row_Offset	=> 1,
				p_Row_Number	=> 'p_Row'
			);
        	v_Changed_Check_Condition := v_Changed_Check_Condition
			|| case when v_Changed_Check_Condition IS NOT NULL then NL(12) || ' AND ' end
			|| 'wwv_flow_item.md5 ( ' || v_Check_Column_List || ') = ' || v_Column_Ref;
			v_Changed_Check_Plsql := v_Changed_Check_Plsql
			|| case when v_Changed_Check_Plsql IS NOT NULL then NL(12) || ' AND ' end
			|| 'wwv_flow_item.md5 ( ' || v_Check_Values_List || ') = ' || v_Column_Ref;
        end if;
        -- when the check list contains only one column and that is a FK with a default value then
        -- inserts are allowed without any data entry.
        if v_Count_FK = 1 and v_Count_Cols = 1 and p_Report_Mode = 'NO' and p_Parent_Key_Item IS NOT NULL then
        	v_Changed_Check_Plsql := NULL;
        end if;
		p_Changed_Check_Condition := v_Changed_Check_Condition;
		p_Changed_Check_Plsql	  := v_Changed_Check_Plsql;
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_Name, p_Unique_Key_Column, p_Select_Columns, p_Columns_Limit, p_View_Mode, p_Data_Source, p_Report_Mode, 
				p_Join_Options, p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, p_Parent_Key_Item, p_Use_Empty_Columns, 
				p_Changed_Check_Condition, p_Changed_Check_Plsql;
		$END
	end Get_Form_Changed_Check;


	FUNCTION Get_Form_Row_Selector (
		p_Loop_Body VARCHAR2,
		p_Row_Sel VARCHAR2
	) RETURN CLOB
	IS
	BEGIN
		return
		'for v_Row_Idx IN 1 .. ' || p_Row_Sel || '.COUNT loop '  || NL(8) ||
			p_Loop_Body || NL(4) ||
		'end loop;' || NL(4);
	END;

	FUNCTION INDENT(p_Query VARCHAR2, p_Indent INTEGER) RETURN VARCHAR2
	IS
	BEGIN
		RETURN REPLACE( p_Query, chr(10), data_browser_conf.NL(p_Indent)) || chr(10);
	END;

	FUNCTION Get_Form_Delete_Rows (
		p_View_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_View_Mode VARCHAR2,
		p_Report_Mode VARCHAR2,
    	p_Parent_Table VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
    	v_Row_Locked_Column_Name 	MVDATA_BROWSER_VIEWS.ROW_LOCKED_COLUMN_NAME%TYPE;
    	v_Row_Locked_Column_Type	VARCHAR2(20);
        v_Parent_Table		VARCHAR2(128);
        v_Parent_Key_Column VARCHAR2(128);
        v_Parent_Key_Nullable VARCHAR2(128);
        v_Parent_Key_Visible VARCHAR2(10);
        v_Inner_Condition	VARCHAR2(32767);
		v_Row_Sel VARCHAR2(100) :=  data_browser_conf.Get_Row_Selector_Expr;
        v_Result_Stat	VARCHAR2(32767);
	begin
    	SELECT --+ INDEX(T) USE_NL_WITH_INDEX(C)
    		T.ROW_LOCKED_COLUMN_NAME,
			C.YES_NO_COLUMN_TYPE
    	INTO v_Row_Locked_Column_Name, v_Row_Locked_Column_Type
    	FROM MVDATA_BROWSER_VIEWS T
    	LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C ON T.VIEW_NAME = C.VIEW_NAME AND T.ROW_LOCKED_COLUMN_NAME = C.COLUMN_NAME
    	WHERE T.VIEW_NAME = p_View_Name;

		if p_Parent_Table IS NOT NULL then
			begin
				SELECT R_VIEW_NAME, COLUMN_NAME, FK_NULLABLE
				INTO v_Parent_Table, v_Parent_Key_Column, v_Parent_Key_Nullable
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = p_View_Name
				AND R_VIEW_NAME = p_Parent_Table
				AND COLUMN_NAME = NVL(p_Parent_Key_Column, COLUMN_NAME)
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;

		v_Inner_Condition := data_browser_conf.Build_Condition(
			v_Inner_Condition,
			data_browser_select.Get_Unique_Key_Expression(
        		p_Table_Name => p_View_Name,
        		p_Unique_Key_Column => p_Unique_Key_Column,
        		p_View_Mode => p_View_Mode
        	)
        	|| ' = '
			|| case when p_Report_Mode = 'NO' then ':a'
					else v_Row_Sel || '(v_Row_Idx)' end
		);
		if v_Parent_Key_Column IS NOT NULL then
			-- restrict to set of rows
			v_Inner_Condition := data_browser_conf.Build_Parent_Key_Condition (
				p_Condition => v_Inner_Condition,
				p_Parent_Key_Column => data_browser_conf.Get_Foreign_Key_Expression(p_Foreign_Key_Column => v_Parent_Key_Column, p_Table_Alias => 'A'),
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Parent_Key_Visible => p_Parent_Key_Visible,
				p_Parent_Key_Nullable => v_Parent_Key_Nullable
			);
		end if;
		if v_Row_Locked_Column_Name IS NOT NULL and v_Row_Locked_Column_Type IS NOT NULL
		and p_Report_Mode = 'YES' then
			v_Inner_Condition := data_browser_conf.Build_Condition(v_Inner_Condition,
				'A.' || v_Row_Locked_Column_Name
				|| ' = ' || data_browser_conf.Get_Boolean_No_Value(v_Row_Locked_Column_Type, 'ENQUOTE')
			);
		end if;

		v_Result_Stat := 'DELETE FROM ' || data_browser_conf.Enquote_Name_Required(p_View_Name) || ' A ' || INDENT(v_Inner_Condition || ';', 8) ;

		if p_Report_Mode = 'NO' then
			return
			'begin ' || NL(4) ||
				v_Result_Stat || NL(4) ||
				':t := SQL%ROWCOUNT;' || chr(10) ||
			'end;' || chr(10);
		else
			return
			'declare ' || NL(4) ||
				'v_Rows_Deleted  PLS_INTEGER := 0; ' || chr(10) ||
			'begin ' || NL(4) ||
				Get_Form_Row_Selector(p_Loop_Body =>
						v_Result_Stat || NL(8) ||
						'v_Rows_Deleted := v_Rows_Deleted + SQL%ROWCOUNT;',
						p_Row_Sel => v_Row_Sel
				) ||
				':t := v_Rows_Deleted;' || chr(10) ||
			'end;' || chr(10);
		end if;
	end Get_Form_Delete_Rows;

	FUNCTION Get_Zip_File_Download (
		p_View_Name VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_View_Mode VARCHAR2,
		p_Report_Mode VARCHAR2,
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2  DEFAULT NULL,
		p_Row_Operation VARCHAR2, -- DOWNLOAD_FILES, DOWNLOAD_SELECTED
		p_Search_Condition VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
		v_Row_Sel VARCHAR2(100) :=  data_browser_conf.Get_Row_Selector_Expr;
		v_File_Name_Column VARCHAR2(128);
		v_File_Date_Column VARCHAR2(128);
		v_File_Content_Column VARCHAR2(128);
        v_Search_Condition	VARCHAR2(32767);
        v_Search_Term	VARCHAR2(32767);
	begin
		if p_Report_Mode = 'NO' then
			return
			'declare ' || NL(4) ||
				'v_Zip_File blob; ' || NL(4) ||
				'v_Counter  PLS_INTEGER := 0; ' || chr(10) ||
			'begin ' || NL(4) ||
				Get_Form_Row_Selector(p_Loop_Body =>
					'v_Counter := v_Counter + data_browser_blobs.FN_Add_Zip_File (' || NL(12) ||
						'p_Table_Name => ' || dbms_assert.enquote_literal(p_View_Name) || NL(12) ||
						', p_Unique_Key_Column => ' || dbms_assert.enquote_literal(p_Unique_Key_Column) || NL(12) ||
						', p_Search_Value => ' || v_Row_Sel || '(v_Row_Idx)' || NL(12) ||
						', p_Zip_File => v_Zip_File' || NL(8) ||
					');',
					p_Row_Sel => v_Row_Sel
				) ||
				'data_browser_blobs.FN_Zip_File_Download(p_Zip_File => v_Zip_File);' || NL(4) ||
				':t := v_Counter;' || chr(10) ||
			'end;' || chr(10);
		else -- Report mode 
			if p_Row_Operation = 'DOWNLOAD_FILES' then 
				SELECT FILE_CONTENT_COLUMN_NAME, FILE_NAME_COLUMN_NAME, FILE_DATE_COLUMN_NAME
				INTO v_File_Content_Column, v_File_Name_Column, v_File_Date_Column
				FROM MVDATA_BROWSER_VIEWS
				WHERE VIEW_NAME = p_View_Name;

				v_Search_Condition := data_browser_conf.Build_Condition(null, 'A.' || dbms_assert.enquote_name(v_File_Content_Column) || ' IS NOT NULL ');
				if p_Parent_Key_Column IS NOT NULL
				and p_Parent_Key_Item IS NOT NULL 
				and V(p_Parent_Key_Item) IS NOT NULL then 
						v_Search_Term := 
						'A.' || dbms_assert.enquote_name(p_Parent_Key_Column) || 
						' = V(' || dbms_assert.enquote_literal(p_Parent_Key_Item) || ')';
					v_Search_Condition := data_browser_conf.Build_Condition(v_Search_Condition, v_Search_Term);
				end if;
				if p_Search_Condition IS NOT NULL then
					v_Search_Condition := data_browser_conf.Build_Condition(v_Search_Condition, p_Search_Condition);
				end if;
				
				return
				'declare ' || NL(4) ||
					'v_Zip_File blob; ' || NL(4) ||
					'v_Counter  PLS_INTEGER := 0; ' || chr(10) ||
				'begin ' || NL(4) ||
					'for c_cur in (' || NL(8) ||
						'SELECT ' || dbms_assert.enquote_name(p_Unique_Key_Column) || ' ID, ' || NL(12) ||
									dbms_assert.enquote_name(v_File_Name_Column) || ' FILE_NAME, '|| NL(12) ||
									case when v_File_Date_Column is not null then 
										dbms_assert.enquote_name(v_File_Date_Column)
									else 'SYSDATE'
									end || ' FILE_DATE, '|| NL(12) ||
									dbms_assert.enquote_name(v_File_Content_Column) || ' FILE_CONTENT '|| NL(8) ||
						'FROM ' || data_browser_conf.Enquote_Name_Required(p_View_Name) || ' A' 
						-- append filter conditions --
						|| INDENT(v_Search_Condition, 8)
						|| NL(4) ||
					') loop'|| NL(8) ||
						'v_Counter := v_Counter + 1;' || NL(8) ||	
$IF data_browser_blobs.g_use_package_as_zip $THEN
						'as_zip.add1file (' || NL(12) ||
							'p_zipped_blob => v_Zip_File,' || NL(12) ||
							'p_name => c_cur.FILE_NAME,' || NL(12) ||
							'p_content => c_cur.FILE_CONTENT,' || NL(12) ||
							'p_date => c_cur.FILE_DATE' || NL(8) ||
						');' || NL(8) ||
$ELSE
						'apex_zip.add_file (' || NL(12) ||
							'p_zipped_blob => v_Zip_File,' || NL(12) ||
							'p_file_name => c_cur.FILE_NAME,' || NL(12) ||
							'p_content => c_cur.FILE_CONTENT' || NL(8) ||
						');' || NL(8) ||
$END
						'data_browser_blobs.Register_Download('|| dbms_assert.enquote_literal(p_View_Name) ||', c_cur.ID, false);' || NL(4) ||
					'end loop;' || NL(4) ||
					'data_browser_blobs.FN_Zip_File_Download(p_Zip_File => v_Zip_File);' || NL(4) ||
					':t := v_Counter;' || chr(10) ||
				'end;' || chr(10);
			elsif p_Row_Operation = 'DOWNLOAD_SELECTED' then 
				return
				'declare ' || NL(4) ||
					'v_Zip_File blob; ' || NL(4) ||
					'v_Counter  PLS_INTEGER := 0; ' || NL(4)  ||
					'v_Key_Values apex_t_varchar2 := apex_t_varchar2(); ' || chr(10) ||
				'begin ' || NL(4) ||
					'v_Key_Values := apex_string.split(:s, '':'');' || NL(4) ||
					'for v_Row_Idx IN 1 .. v_Key_Values.COUNT loop ' || NL(8) ||
						'v_Counter := v_Counter + data_browser_blobs.FN_Add_Zip_File (' || NL(12) ||
							'p_Table_Name => ' || dbms_assert.enquote_literal(p_View_Name) || NL(12) ||
							', p_Unique_Key_Column => ' || dbms_assert.enquote_literal(p_Unique_Key_Column) || NL(12) ||
							', p_Search_Value => v_Key_Values(v_Row_Idx)' || NL(12) ||
							', p_Zip_File => v_Zip_File' || NL(8) ||
						');' || NL(4) ||
					'end loop;' || NL(4) ||
					'data_browser_blobs.FN_Zip_File_Download(p_Zip_File => v_Zip_File);' || NL(4) ||
					':t := v_Counter;' || chr(10) ||
				'end;' || chr(10) ;
			end if;
		end if;
	end Get_Zip_File_Download;

	FUNCTION Get_Form_Move_Rows (
		p_View_Name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_View_Mode VARCHAR2,
		p_Report_Mode VARCHAR2, 				-- YES, NO
    	p_Parent_Key_Column VARCHAR2,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Item VARCHAR2
	) RETURN VARCHAR2
	is
		v_Row_Sel VARCHAR2(100) :=  data_browser_conf.Get_Row_Selector_Expr;
        v_Result_Stat	VARCHAR2(32767);
	begin
		if p_Parent_Key_Column IS NOT NULL and p_Parent_Key_Item IS NOT NULL then
			if INSTR(p_Parent_Key_Column, ',') > 0 then 
				return NULL;	-- Function not implemented.
			end if;
			v_Result_Stat := 'UPDATE ' || data_browser_conf.Enquote_Name_Required(p_View_Name) || ' A' || NL(12)
			|| 'SET ' || p_Parent_Key_Column || ' = V(' || Enquote_Literal(p_Parent_Key_Item) || ')' || NL(8)
			|| 'WHERE '
			|| data_browser_select.Get_Unique_Key_Expression(
        		p_Table_Name => p_View_Name,
        		p_Unique_Key_Column => p_Unique_Key_Column,
        		p_View_Mode => p_View_Mode
        	)
			|| ' = ';
			if p_Report_Mode = 'NO' then
				return
				'begin ' || NL(4) ||
					v_Result_Stat || ':a;'  || NL(4) ||
					':t := SQL%ROWCOUNT;' || chr(10) ||
				'end;' || chr(10);
			else
				return
				'declare ' || NL(4) ||
					'v_Rows_Updated  PLS_INTEGER := 0; ' || chr(10) ||
				'begin ' || NL(4) ||
					Get_Form_Row_Selector(p_Loop_Body =>
							v_Result_Stat || v_Row_Sel || '(v_Row_Idx);' || NL(8) ||
							'v_Rows_Updated := v_Rows_Updated + SQL%ROWCOUNT;',
							p_Row_Sel => v_Row_Sel
					) ||
					':t := v_Rows_Updated;' || chr(10) ||
				'end;' || chr(10);
			end if;
		end if;
		return NULL;
	end Get_Form_Move_Rows;

    PROCEDURE Get_Merge_Table_Join(
        p_Table_Name    VARCHAR2,
        p_Join_Condition OUT VARCHAR2,
        p_Join_Columns OUT VARCHAR2
    )
    is
		-- join columns
        CURSOR cur_keycol (in_table_name IN MVDATA_BROWSER_DESCRIPTIONS.TABLE_NAME%TYPE)
        IS
        	SELECT --+ INDEX(PT) USE_NL_WITH_INDEX(C)
        		PT.TABLE_NAME, C.COLUMN_NAME, ROWNUM POSITION, C.NULLABLE
        	FROM MVDATA_BROWSER_DESCRIPTIONS PT, TABLE( apex_string.split(PT.DISPLAYED_COLUMN_NAMES, ', ')) PC,
        		MVDATA_BROWSER_SIMPLE_COLS C
        	WHERE PT.TABLE_NAME = C.TABLE_NAME AND PC.COLUMN_VALUE = C.COLUMN_NAME
        	AND PT.TABLE_NAME = in_table_name
        	ORDER BY 3;
        TYPE keycol_tbl IS TABLE OF cur_keycol%ROWTYPE;
        v_keycol_tbl keycol_tbl;
        l_SQLStat   CLOB;
        v_Column_List	VARCHAR2(32767);
    begin
        OPEN cur_keycol (p_Table_Name);
        FETCH cur_keycol
        BULK COLLECT INTO v_keycol_tbl;
        CLOSE cur_keycol;

        if v_keycol_tbl.COUNT = 0 then
        	p_Join_Condition := NULL;
        	p_Join_Columns := NULL;
            return;
        end if;

		FOR i IN 1 .. v_keycol_tbl.COUNT
		LOOP
			if v_keycol_tbl (i).NULLABLE = 'Y' then
				l_SQLStat := l_SQLStat
				|| '(D.' || v_keycol_tbl (i).column_name || ' = S.' || v_keycol_tbl (i).column_name
				|| ' OR D.' || v_keycol_tbl (i).column_name || ' IS NULL AND S.' || v_keycol_tbl (i).column_name ||  ' IS NULL)'
				|| case when i < v_keycol_tbl.COUNT then ' AND ' end;
			else
				l_SQLStat := l_SQLStat
				|| 'D.' || v_keycol_tbl (i).column_name || ' = S.' || v_keycol_tbl (i).column_name
				|| case when i < v_keycol_tbl.COUNT then ' AND ' end;
			end if;
			v_Column_List := v_Column_List
				|| case when v_Column_List IS NOT NULL then ', ' end
				|| v_keycol_tbl (i).column_name;
		END LOOP;
		p_Join_Condition := l_SQLStat;
		p_Join_Columns := v_Column_List;
	end Get_Merge_Table_Join;

	FUNCTION Get_Form_Merge_Match (
		p_Column_List VARCHAR2,
		p_Unique_Key_Column VARCHAR2,
        p_Join_Columns VARCHAR2
	) RETURN CLOB -- internal
	is
        v_Insert_List	CLOB;
        v_Update_List	CLOB;
        v_Values_List	CLOB;
        v_Delimiter VARCHAR2(100);
        v_Count PLS_INTEGER;
	begin
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Get_Form_Merge_Match (p_Column_List=> %s, p_Unique_Key_Column=> %s, p_Join_Columns=>%s)',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Column_List),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Unique_Key_Column),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Join_Columns),
				p_max_length => 3500
			);
		$END
		v_Count := 0;
		for c_cur IN (
			SELECT S.COLUMN_NAME,
				case when EXISTS (
					SELECT 1
					FROM  TABLE( data_browser_conf.in_list(p_Join_Columns, ',') ) P
					WHERE S.COLUMN_NAME = P.COLUMN_VALUE
				) then 'Y' else 'N'
				end IS_JOINED
			FROM (
				SELECT COLUMN_VALUE COLUMN_NAME
				FROM TABLE( data_browser_conf.in_list(p_Column_List, ',') )
			) S
		) loop
			v_Count := v_Count + 1;
			v_Delimiter := case when v_Count > 1 then ', ' end
			|| case when MOD(v_Count, 5) = 0 then NL(16) end;
			v_Insert_List := v_Insert_List || v_Delimiter
			|| 'D.' || c_cur.COLUMN_NAME;
			v_Values_List := v_Values_List || v_Delimiter
			|| 'S.' || c_cur.COLUMN_NAME;

			if c_cur.COLUMN_NAME != p_Unique_Key_Column and c_cur.IS_JOINED = 'N' then
				v_Update_List := v_Update_List
				|| case when v_Update_List IS NOT NULL then v_Delimiter end
				|| 'D.' || c_cur.COLUMN_NAME || ' = ' || 'S.' || c_cur.COLUMN_NAME;
			end if;
		end loop;
		return case when v_Update_list IS NOT NULL then
			'WHEN MATCHED THEN' || NL(12) ||
				'UPDATE SET ' || v_Update_list || NL(8)
			end ||
		'WHEN NOT MATCHED THEN' || NL(12) ||
			'INSERT (' || v_Insert_List || ')' || NL(12) ||
			'VALUES (' || v_Values_List || ')' || NL(8);
	end Get_Form_Merge_Match;

	FUNCTION Get_Copy_Rows_DML (
		p_View_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Row_Operation VARCHAR2,				-- DUPLICATE, COPY_ROWS, MERGE_ROWS
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
    	p_Join_Options VARCHAR2 DEFAULT NULL,
		p_Columns_Limit IN NUMBER,
		p_View_Mode IN VARCHAR2,
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',	-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2, 				-- YES, NO
    	p_Parent_Name VARCHAR2,					-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2,			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2
	) RETURN CLOB
	is
        v_Table_Name 				MVDATA_BROWSER_VIEWS.TABLE_NAME%TYPE;
    	v_Sequence_Owner 			MVDATA_BROWSER_VIEWS.SEQUENCE_OWNER%TYPE;
    	v_Sequence_Name 			MVDATA_BROWSER_VIEWS.SEQUENCE_NAME%TYPE;
    	v_Row_Version_Column_Name 	MVDATA_BROWSER_VIEWS.ROW_VERSION_COLUMN_NAME%TYPE;
    	v_Unique_Key_Column 		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
    	v_Has_Scalar_Key 	MVDATA_BROWSER_VIEWS.HAS_SCALAR_KEY%TYPE;
    	v_Row_Locked_Column_Name 	MVDATA_BROWSER_VIEWS.ROW_LOCKED_COLUMN_NAME%TYPE;
    	v_Row_Locked_Column_Type	VARCHAR2(20);
        v_Column_List	CLOB;
        v_Values_List	CLOB;
        v_Result_Stat	CLOB;
        v_use_NLS_params CONSTANT VARCHAR2(1) := 'Y';
        v_Delimiter     CONSTANT VARCHAR2(50) := ', ' || NL(20);
        v_Delimiter2	VARCHAR2(50);
		v_Indent 		PLS_INTEGER;
		v_Insert_Ref 	VARCHAR2(4000);
		v_Insert_Key_Expr VARCHAR2(4000);
		v_Merge_Cond	VARCHAR2(4000);
		v_Join_Columns	VARCHAR2(4000);
		v_Row_Number 	PLS_INTEGER := 1;	--	used for form validation
		v_Key_Cols_Count PLS_INTEGER;
		v_Count			PLS_INTEGER;
		v_Row_Sel 			VARCHAR2(100) :=  data_browser_conf.Get_Row_Selector_Expr;
		v_Map_Unique_Key    VARCHAR2(32);
		v_Map_Column_List	VARCHAR2(32767);
        v_Map_Count			PLS_INTEGER := 0;
        v_Uni_Count			PLS_INTEGER := 0;
	begin
		begin 
			SELECT T.TABLE_NAME, NVL(p_Unique_Key_Column, T.SEARCH_KEY_COLS), KEY_COLS_COUNT, HAS_SCALAR_KEY,
				T.SEQUENCE_OWNER, T.SEQUENCE_NAME, T.ROW_VERSION_COLUMN_NAME, 
				T.ROW_LOCKED_COLUMN_NAME,
				C.YES_NO_COLUMN_TYPE
			INTO v_Table_Name, v_Unique_Key_Column, v_Key_Cols_Count, v_Has_Scalar_Key,
					v_Sequence_Owner, v_Sequence_Name, v_Row_Version_Column_Name, 
					v_Row_Locked_Column_Name, v_Row_Locked_Column_Type
			FROM MVDATA_BROWSER_VIEWS T
			LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C ON T.VIEW_NAME = C.VIEW_NAME AND T.ROW_LOCKED_COLUMN_NAME = C.COLUMN_NAME
			WHERE T.VIEW_NAME = p_View_name;
		exception when NO_DATA_FOUND then
			return NULL;
		end;
		v_Count := 0;
        FOR c_cur IN (
			SELECT COLUMN_NAME, COLUMN_EXPR_TYPE, DATA_TYPE, DATA_SCALE, FORMAT_MASK, HAS_DEFAULT,
				IS_PRIMARY_KEY, IS_SEARCH_KEY, CHECK_UNIQUE, CHAR_LENGTH, INPUT_ID, IS_VIRTUAL_COLUMN,
				SUBSTR(INPUT_ID, 1, 1)  S_REF_TYPE, -- C,N
				R_COLUMN_NAME, YES_NO_COLUMN_TYPE,
				IS_DISP_KEY_COLUMN
			FROM TABLE ( data_browser_select.Get_View_Column_Cursor(
					p_Table_name => p_View_name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Select_Columns => p_Select_Columns,
					p_Join_Options => p_Join_Options,
					p_Columns_Limit => p_Columns_Limit,
					p_Data_Columns_Only => 'YES',
					p_View_Mode => case when p_Data_Source = 'COLLECTION' then p_View_Mode else 'FORM_VIEW' end,
					p_Edit_Mode => 'YES',
					p_Report_Mode => p_Report_Mode,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible
				)
			) S
			WHERE TABLE_ALIAS = 'A'
			AND COLUMN_EXPR_TYPE NOT IN ('LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR')
			 
        )
        loop
			v_Insert_Ref := NULL;
			if c_cur.IS_SEARCH_KEY = 'Y'
			-- and c_cur.COLUMN_EXPR_TYPE != 'HIDDEN' 
			then
				v_Uni_Count := v_Uni_Count + 1;
			end if;
			-- problem; the Sequence function NEXTVAL can not be used here --
            if c_cur.IS_SEARCH_KEY = 'Y'
			and v_Unique_Key_Column = c_cur.R_COLUMN_NAME then
				v_Insert_Key_Expr := 'NULL';
				if p_Data_Source = 'TABLE' then 
					v_Insert_Ref := v_Insert_Key_Expr || ' ' || c_cur.R_COLUMN_NAME;
				else
					v_Insert_Ref := c_cur.R_COLUMN_NAME;				
				end if; 
			elsif p_Row_Operation IN ('DUPLICATE', 'COPY_ROWS')
			and (c_cur.CHECK_UNIQUE = 'Y' or c_cur.IS_DISP_KEY_COLUMN = 'Y')
			and  p_Data_Source = 'TABLE' 
			and c_cur.CHAR_LENGTH > 10 then
				v_Insert_Ref := 'RTRIM(' || c_cur.R_COLUMN_NAME
							|| ' || apex_lang.lang(' || Enquote_Literal('-Duplicate' )
							|| '), ' || c_cur.CHAR_LENGTH || ') '
							||  c_cur.R_COLUMN_NAME;
			elsif p_Row_Operation IN ('COPY_ROWS', 'MERGE_ROWS') 
			and  p_Data_Source = 'TABLE' 
			and c_cur.R_COLUMN_NAME = p_Parent_Key_Column then
				v_Insert_Ref := 'V(' || Enquote_Literal(p_Parent_Key_Item) || ') ' || c_cur.R_COLUMN_NAME;
			elsif c_cur.R_COLUMN_NAME = v_Row_Version_Column_Name then
				v_Insert_Ref := '1 ' || c_cur.R_COLUMN_NAME;
			elsif c_cur.R_COLUMN_NAME = v_Row_Locked_Column_Name then
				v_Insert_Ref := data_browser_conf.Get_Boolean_No_Value(v_Row_Locked_Column_Type, 'ENQUOTE') || ' ' || c_cur.R_COLUMN_NAME;
			else
				v_Insert_Ref := c_cur.R_COLUMN_NAME;
            end if;
			if (c_cur.IS_SEARCH_KEY = 'N' or v_Insert_Key_Expr IS NOT NULL or v_Key_Cols_Count > 1)
			and NOT(c_cur.IS_VIRTUAL_COLUMN = 'Y' and p_Row_Operation IN ('DUPLICATE', 'COPY_ROWS')) then
				v_Count := v_Count + 1;
				v_Column_List := v_Column_List
				|| case when v_Count > 1 then v_Delimiter end
				|| c_cur.R_COLUMN_NAME;
				v_Values_List := v_Values_List
				|| case when v_Count > 1 then v_Delimiter end
				|| v_Insert_Ref;
			end if;
			if p_Data_Source = 'COLLECTION' then
				data_browser_select.Get_Collection_Columns(
					p_Map_Column_List => v_Map_Column_List,
					p_Map_Count => v_Map_Count,
					p_Column_Expr_Type => c_cur.COLUMN_EXPR_TYPE,
					p_Data_Type => c_cur.DATA_TYPE,
					p_Input_ID => c_cur.INPUT_ID,
					p_Column_Name => c_cur.R_COLUMN_NAME,
					p_Default_Value => case when c_cur.R_COLUMN_NAME = p_Parent_Key_Column then 'V(' || Enquote_Literal(p_Parent_Key_Item) || ') ' end,
					p_indent => 12,
					p_Convert_Expr => case 
						when c_cur.YES_NO_COLUMN_TYPE IS NOT NULL 
							then data_browser_conf.Lookup_Yes_No_Call(c_cur.YES_NO_COLUMN_TYPE, 'A.' || c_cur.INPUT_ID)
						else
							data_browser_conf.Get_Char_to_Type_Expr(
								p_Element => c_cur.INPUT_ID, 
								p_Element_Type	=> c_cur.S_REF_TYPE,
								p_Data_Source	=> p_Data_Source,
								p_Data_Type => c_cur.DATA_TYPE, 
								p_Data_Scale => c_cur.DATA_SCALE, 
								p_Format_Mask => c_cur.FORMAT_MASK, 
								p_Use_Group_Separator => 'Y',
								p_use_NLS_params => v_use_NLS_params
							)
					end,
					p_Is_Virtual_Column => c_cur.IS_VIRTUAL_COLUMN
				);
				if c_cur.COLUMN_NAME = v_Unique_Key_Column then 
					v_Map_Unique_Key := c_cur.INPUT_ID;
				end if;
			end if;
        end loop;
        -- append virtual columns to select list
        if p_Row_Operation IN ('MERGE_ROWS') then
			FOR c_cur IN (
				SELECT TABLE_NAME, COLUMN_NAME, DATA_DEFAULT 
				FROM USER_TAB_COLS 
				WHERE VIRTUAL_COLUMN = 'YES' 
				AND DATA_TYPE NOT IN ('RAW', 'BLOB')
				AND TABLE_NAME = p_View_name
			)
			loop
				v_Count := v_Count + 1;
				v_Values_List := v_Values_List
				|| case when v_Count > 1 then v_Delimiter end
				|| c_cur.DATA_DEFAULT || ' ' || c_cur.COLUMN_NAME;
			end loop;
		end if;
		v_Indent := 8;
		if v_Column_List IS NOT NULL then
			if p_Row_Operation IN ('COPY_ROWS', 'DUPLICATE') then
				-- Data is copied from the source table including large text fields
				v_Result_Stat := v_Result_Stat
				|| 'INSERT INTO ' || p_View_name
				|| ' ( ' ||  v_Column_List || ')' || NL(v_Indent)
				|| 'SELECT ' || v_Values_List || NL(v_Indent)
				|| 'FROM ' || data_browser_conf.Enquote_Name_Required(p_View_name) || ' A' || NL(v_Indent)
				|| 'WHERE '
				|| data_browser_select.Get_Unique_Key_Expression(
						p_Table_Name => p_View_Name,
						p_Unique_Key_Column => v_Unique_Key_Column,
						p_View_Mode => p_View_Mode
					)
				|| ' = ' || case when p_Report_Mode = 'NO' then ':a' else v_Row_Sel || '(v_Row_Idx)' end;
			elsif p_Row_Operation IN ('MERGE_ROWS') then
				if p_Data_Source = 'COLLECTION' and v_Unique_Key_Column IS NOT NULL 
				and v_Uni_Count =  v_Key_Cols_Count then -- a primary key load/lookup has already been performed.
					v_Merge_Cond := data_browser_conf.Get_Join_Expression(
									p_Left_Columns=>v_Unique_Key_Column, p_Left_Alias=> 'S',
									p_Right_Columns=>v_Unique_Key_Column, p_Right_Alias=> 'D');
					v_Join_Columns := v_Unique_Key_Column;
				else
					Get_Merge_Table_Join(v_Table_Name, v_Merge_Cond, v_Join_Columns);
				end if;
				
				if v_Merge_Cond IS NOT NULL then
					v_Result_Stat := v_Result_Stat
					|| 'MERGE INTO ' || data_browser_conf.Enquote_Name_Required(p_View_name) || ' D' || NL(v_Indent)
					|| 'USING (SELECT ' || v_Values_List || NL(v_Indent + 4)
					|| 'FROM '
					|| case when p_Data_Source = 'COLLECTION' then
							data_browser_select.Get_Collection_Query (
								p_Map_Column_List => v_Map_Column_List,
								p_Map_Unique_Key => v_Map_Unique_Key,
								p_indent => 12
							)
						else
							data_browser_conf.Enquote_Name_Required(p_View_name) || ' A' || NL(v_Indent + 4)
							|| 'WHERE '
							|| data_browser_select.Get_Unique_Key_Expression(
								p_Table_Name => p_View_Name,
								p_Unique_Key_Column => v_Unique_Key_Column,
								p_View_Mode => p_View_Mode
							)
							|| ' = '
							|| case when p_Report_Mode = 'NO'
								then ':a' else v_Row_Sel || '(v_Row_Idx)'
							end
					end
					|| ') S' || NL(v_Indent)
					|| 'ON (' || v_Merge_Cond 
					|| case when v_Row_Locked_Column_Name IS NOT NULL then 
						' AND D.' || v_Row_Locked_Column_Name || ' = ' 
						|| data_browser_conf.Get_Boolean_No_Value(v_Row_Locked_Column_Type, 'ENQUOTE') 
					end
					|| ')' || NL(v_Indent)
					|| Get_Form_Merge_Match (
						p_Column_List => v_Column_List, 
						p_Unique_Key_Column => v_Unique_Key_Column, 
						p_Join_Columns => data_browser_conf.Concat_List(v_Join_Columns, v_Row_Locked_Column_Name)
					);
				end if;
			end if;
			if v_Result_Stat IS NOT NULL then
				if p_Report_Mode = 'NO' then
					return
					'begin ' || NL(4) ||
						v_Result_Stat || ';'  || NL(4) ||
						':t := SQL%ROWCOUNT;' || chr(10) ||
					'end;' || chr(10);
				else
					return
					'declare ' || NL(4) ||
						'v_Rows_Inserted pls_integer := 0; ' || NL(4) ||
						'v_Key_Value varchar2(1024);' || chr(10) ||
					'begin ' || NL(4)
					|| case when p_Data_Source = 'COLLECTION' then
							v_Result_Stat || ';' || NL(8) ||
							'v_Rows_Inserted := SQL%ROWCOUNT;'
						else
							Get_Form_Row_Selector(p_Loop_Body =>
									v_Result_Stat || ';' || NL(8) ||
									'v_Rows_Inserted := v_Rows_Inserted + SQL%ROWCOUNT;',
									p_Row_Sel => v_Row_Sel
							)
						end || NL(4) ||
						':t := v_Rows_Inserted;' || chr(10) ||
					'end;' || chr(10);
				end if;
			end if;
		end if;
		return v_Result_Stat;
	end Get_Copy_Rows_DML;


	FUNCTION Get_Form_Edit_DML (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column VARCHAR2 DEFAULT NULL,
		p_Row_Operation VARCHAR2 DEFAULT 'UPDATE',			-- INSERT, UPDATE, DELETE, DUPLICATE, MOVE_ROWS, COPY_ROWS, MERGE_ROWS
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item VARCHAR2 DEFAULT NULL,
		p_Use_Empty_Columns VARCHAR2 DEFAULT 'YES'
	) RETURN CLOB
	is
        v_Table_Name 	MVDATA_BROWSER_VIEWS.TABLE_NAME%TYPE;
        v_View_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE;
    	v_Sequence_Owner MVDATA_BROWSER_VIEWS.SEQUENCE_OWNER%TYPE;
    	v_Sequence_Name MVDATA_BROWSER_VIEWS.SEQUENCE_NAME%TYPE;
    	v_Row_Version_Column_Name MVDATA_BROWSER_VIEWS.ROW_VERSION_COLUMN_NAME%TYPE;
    	v_Unique_Key_Column MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
    	v_Has_Scalar_Key MVDATA_BROWSER_VIEWS.HAS_SCALAR_KEY%TYPE;
    	v_Procedure_Name VARCHAR2(50);
    	v_Value_Exists  VARCHAR2(10);
        v_Column_List	CLOB;
        v_Values_List	CLOB;
        v_Changed_Check_Condition	CLOB;
        v_Changed_Check_Plsql	CLOB;
    	v_Build_MD5		BOOLEAN := TRUE;
        v_Update_List	CLOB;
        v_Update_Where	VARCHAR2(4000);
        v_Result_Stat	CLOB;
        v_Result_PLSQL	CLOB;
        v_Delimiter     CONSTANT VARCHAR2(50) := ', ' || NL(20);
    	v_Check_Column_Idx NUMBER := 1;
		v_Indent 		PLS_INTEGER;
		v_Column_Expr 	VARCHAR2(4000);
		v_Insert_Ref 	VARCHAR2(4000);
		v_Insert_Key_Expr VARCHAR2(4000);
		v_Exists_Key_Expr VARCHAR2(4000);
		v_Result_Key_Expr VARCHAR2(4000);
		v_Result_Key_Hidden BOOLEAN := FALSE;
		v_Search_Key_Expr VARCHAR2(4000);
        v_Search_Condition	VARCHAR2(32767);
		v_Row_Number 	PLS_INTEGER := 1;	--	used for form validation
		v_Delimiter2	VARCHAR2(50);
		v_Use_Group_Separator 	CONSTANT VARCHAR2(1) := 'Y';
		v_use_NLS_params 		CONSTANT VARCHAR2(1) := 'Y'; -- case when p_Data_Source = 'COLLECTION' then 'Y' else 'N' end
		v_Apex_Item_Rows_Call VARCHAR2(1024);
		v_Row_Op        VARCHAR2(50);
		v_Parent_Key_Visible  VARCHAR2(10);
		v_Count			PLS_INTEGER;
	begin
		v_Parent_Key_Visible := case when p_Select_Columns IS NOT NULL then 'YES' else p_Parent_Key_Visible end;
		$IF data_browser_conf.g_debug $THEN
			EXECUTE IMMEDIATE data_browser_conf.Dyn_Log_Call_Parameter
			USING p_Table_Name, p_Unique_Key_Column, p_Row_Operation, p_Select_Columns, p_Columns_Limit, p_View_Mode, 
				p_Data_Source, p_Report_Mode, p_Join_Options, p_Parent_Name, p_Parent_Key_Column, p_Parent_Key_Visible, 
				p_Parent_Key_Item, p_Use_Empty_Columns;
		$END
		v_Row_Op := case
			when p_Row_Operation IN ('INSERT', 'UPDATE', 'DELETE', 'DUPLICATE', 'COPY_ROWS', 'MERGE_ROWS', 'MOVE_ROWS', 'DOWNLOAD_FILES', 'DOWNLOAD_SELECTED')
			then p_Row_Operation
			end;
		if v_Row_Op IS NULL then
			return NULL;
		end if;
		if v_Row_Op IN ('COPY_ROWS', 'MERGE_ROWS', 'MOVE_ROWS')
		and ((p_Parent_Key_Column IS NULL or p_Parent_Key_Item IS NULL)
			and p_Data_Source != 'COLLECTION') then
			return NULL;
		end if;

 		begin 
			SELECT VIEW_NAME, TABLE_NAME, NVL(p_Unique_Key_Column, SEARCH_KEY_COLS), HAS_SCALAR_KEY, SEQUENCE_OWNER, SEQUENCE_NAME, ROW_VERSION_COLUMN_NAME
			INTO v_View_Name, v_Table_Name, v_Unique_Key_Column, v_Has_Scalar_Key, v_Sequence_Owner, v_Sequence_Name, v_Row_Version_Column_Name
			FROM MVDATA_BROWSER_VIEWS
			WHERE VIEW_NAME = UPPER(p_Table_Name);
		exception when NO_DATA_FOUND then
			return NULL;
		end;

    	dbms_lob.createtemporary(v_Result_PLSQL, true, dbms_lob.call);
		if v_Row_Op = 'DELETE' then
			RETURN Get_Form_Delete_Rows (
				p_View_Name => v_View_Name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Parent_Table => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item
			);
		end if;
		if v_Row_Op = 'DOWNLOAD_SELECTED' then
			RETURN Get_Zip_File_Download (
				p_View_Name => v_View_Name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Row_Operation => v_Row_Op
			);
		end if;
		if v_Row_Op = 'DOWNLOAD_FILES' then
			v_Search_Condition := data_browser_utl.Get_Form_Search_Cond (
				p_Table_name => v_View_Name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Data_Source => p_Data_Source,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible
			);
		
			RETURN Get_Zip_File_Download (
				p_View_Name => v_View_Name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Row_Operation => v_Row_Op,
				p_Search_Condition => v_Search_Condition
			);
		end if;

		if v_Row_Op = 'MOVE_ROWS' then
			RETURN Get_Form_Move_Rows (
				p_View_Name => v_View_Name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_View_Mode => p_View_Mode,
				p_Report_Mode => p_Report_Mode,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Item => p_Parent_Key_Item
			);
		end if;
		if v_Row_Op IN ('COPY_ROWS', 'MERGE_ROWS', 'DUPLICATE') then
			return Get_Copy_Rows_DML(
				p_View_name => v_View_Name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Row_Operation => v_Row_Op,
				p_Select_Columns => p_Select_Columns,
				p_Join_Options => p_Join_Options,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Data_Source => p_Data_Source,
				p_Report_Mode => p_Report_Mode,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item
			);
		end if;
		---------------------------------------------------------------------------------
		-- process INSERT / UPDATE --
		v_Count := 0;
        FOR c_cur IN (
			SELECT COLUMN_NAME, REF_COLUMN_NAME, COLUMN_EXPR, COLUMN_EXPR_TYPE, IS_PRIMARY_KEY, IS_SEARCH_KEY, CHECK_UNIQUE,
					APEX_ITEM_IDX, ROW_FACTOR, ROW_OFFSET, DATA_TYPE, DATA_SCALE, FORMAT_MASK,
					TABLE_ALIAS, R_COLUMN_NAME, HAS_DEFAULT, DATA_DEFAULT, CHAR_LENGTH,
					data_browser_edit.Get_Apex_Item_Ref (
						p_Idx 			=> APEX_ITEM_IDX,
						p_Row_Factor	=> ROW_FACTOR,
						p_Row_Offset	=> ROW_OFFSET,
						p_Row_Number	=> v_Row_Number
					) APEX_ITEM_REF,
					data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=> APEX_ITEM_IDX,
						p_Row_Factor	=> ROW_FACTOR,
						p_Row_Offset	=> ROW_OFFSET,
						p_Row_Number	=> 'p_Row'
					) APEX_ITEM_CALL,
					SUBSTR(INPUT_ID, 1, 1)  S_REF_TYPE, -- C,N
					IS_DISP_KEY_COLUMN
			FROM TABLE ( data_browser_edit.Get_Form_Edit_Cursor(
					p_Table_name => v_View_Name,
					p_Unique_Key_Column => v_Unique_Key_Column,
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Report_Mode => p_Report_Mode,
					p_Join_Options => p_Join_Options,
					p_Data_Source => p_Data_Source, 
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item
				)
			) S
			WHERE COLUMN_EXPR_TYPE NOT IN ('LINK', 'LINK_LIST', 'LINK_ID', 'ROW_SELECTOR')
			AND TABLE_ALIAS = 'A'
        )
        loop
			v_Value_Exists := case when p_Use_Empty_Columns = 'YES' then 'YES'
								else data_browser_edit.Check_Item_Ref (c_cur.APEX_ITEM_REF, c_cur.COLUMN_NAME) end;
			v_Column_Expr :=
				case 
					when c_cur.COLUMN_EXPR_TYPE IN ('POPUPKEY_FROM_LOV', 'SELECT_LIST_FROM_QUERY', 'SELECT_LIST', 'DISPLAY_AND_SAVE')
						then c_cur.APEX_ITEM_CALL
					when c_cur.COLUMN_EXPR_TYPE = 'TEXT_EDITOR'
						then data_browser_blobs.Get_Clob_from_form_call(c_cur.APEX_ITEM_CALL, c_cur.DATA_TYPE)
					else 
						data_browser_conf.Get_Char_to_Type_Expr(
							p_Element => c_cur.APEX_ITEM_CALL, 
							p_Data_Type => c_cur.DATA_TYPE, 
							p_Data_Scale => c_cur.DATA_SCALE, 
							p_Format_Mask => c_cur.FORMAT_MASK, 
							p_Use_Group_Separator => v_Use_Group_Separator,
							p_use_NLS_params => v_use_NLS_params
						)
				end;
			v_Insert_Ref := v_Column_Expr;
			if v_Apex_Item_Rows_Call IS NULL 
			and c_cur.APEX_ITEM_IDX >= 1 then
				v_Apex_Item_Rows_Call := data_browser_edit.Get_Apex_Item_Rows_Call(
						p_Idx 			=> c_cur.APEX_ITEM_IDX,
						p_Row_Factor	=> c_cur.ROW_FACTOR,
						p_Row_Offset	=> c_cur.ROW_OFFSET
				);
			end if;
            if c_cur.IS_SEARCH_KEY = 'Y' 
			and v_Value_Exists != 'UNKNOWN' then
				if v_Unique_Key_Column = c_cur.REF_COLUMN_NAME then
					if v_Row_Op IN ('INSERT', 'UPDATE') then
						v_Result_Key_Expr := c_cur.APEX_ITEM_CALL;
						v_Result_Key_Hidden := (c_cur.COLUMN_EXPR_TYPE = 'HIDDEN');
					end if;
					v_Search_Key_Expr := data_browser_edit.Get_Apex_Item_Call (
						p_Idx 			=>  c_cur.APEX_ITEM_IDX,
						p_Row_Factor	=>  c_cur.ROW_FACTOR,
						p_Row_Offset	=>  c_cur.ROW_OFFSET,
						p_Row_Number	=> 'v_Row_Number'
					);
				end if;
				v_Update_Where := v_Update_Where
				|| case when v_Update_Where IS NOT NULL then NL(16) || 'AND ' end
				-- || c_cur.REF_COLUMN_NAME 
				|| data_browser_select.Get_Unique_Key_Expression(
					p_Table_Name=> v_View_Name,
					p_Unique_Key_Column=> c_cur.REF_COLUMN_NAME, 
					p_View_Mode=> p_View_Mode)
				|| ' = ' 
				|| v_Column_Expr;

				if v_Row_Op = 'INSERT'
				and v_Unique_Key_Column = c_cur.REF_COLUMN_NAME 
				-- and p_Data_Source != 'COLLECTION' 
				then -- import ids from collection 
					if v_Sequence_Owner IS NOT NULL and v_Sequence_Name IS NOT NULL then
						-- Get primary key value from column default
						v_Insert_Key_Expr := v_Sequence_Owner || '.' || v_Sequence_Name || '.NEXTVAL';
					else
						if c_cur.HAS_DEFAULT = 'Y' then 
							v_Insert_Key_Expr := c_cur.DATA_DEFAULT; 
						end if;
						if v_Insert_Key_Expr IS NULL and v_Has_Scalar_Key = 'YES' then
							v_Insert_Key_Expr := data_browser_conf.Get_Sys_Guid_Function;
						end if;
					end if;
					if v_Insert_Key_Expr IS NOT NULL then
						v_Insert_Ref := 'v_Key_Value';
					else
						v_Value_Exists := 'UNKNOWN';
					end if;
				end if;
            end if;
			if c_cur.REF_COLUMN_NAME NOT LIKE data_browser_conf.Get_MD5_Column_Name || '%' then
				if v_Row_Op = 'INSERT' and c_cur.COLUMN_EXPR_TYPE NOT IN ('DISPLAY_ONLY', 'FILE_BROWSER') and v_Value_Exists != 'UNKNOWN' then
		        	v_Count := v_Count + 1;
					if c_cur.COLUMN_EXPR_TYPE = 'PASSWORD' then 
						v_Insert_Ref := case when data_browser_pattern.Match_Encrypted_Columns(c_cur.REF_COLUMN_NAME) = 'YES'
							then data_browser_conf.Get_Encrypt_Function(p_Key_Column => 'v_Key_Value', p_Column_Name => c_cur.APEX_ITEM_CALL) 
							else data_browser_conf.Get_Hash_Function(p_Key_Column => 'v_Key_Value', p_Column_Name => c_cur.APEX_ITEM_CALL) 
						end;
		        	end if;
					v_Column_List := v_Column_List
					|| case when v_Count > 1 then v_Delimiter end
					|| c_cur.REF_COLUMN_NAME;
					v_Values_List := v_Values_List
					|| case when v_Count > 1 then v_Delimiter end
					|| v_Insert_Ref;
				end if;
				if c_cur.IS_SEARCH_KEY = 'N' then
					if v_Row_Op IN ('INSERT', 'UPDATE')
					and c_cur.COLUMN_EXPR_TYPE NOT IN ('DISPLAY_ONLY', 'DISPLAY_AND_SAVE', 'FILE_BROWSER') then
						if c_cur.REF_COLUMN_NAME = v_Row_Version_Column_Name then
							v_Update_Where := v_Update_Where
							|| case when v_Update_Where IS NOT NULL then NL(16) || 'AND ' end
							|| c_cur.REF_COLUMN_NAME || ' = ' || v_Column_Expr;
							v_Update_List := v_Update_List
							|| case when v_Update_List IS NOT NULL then v_Delimiter end
							|| c_cur.REF_COLUMN_NAME || ' = ' || v_Column_Expr
							|| ' + 1';
						else
							v_Update_List := v_Update_List
							|| case when v_Update_List IS NOT NULL then v_Delimiter end
							|| c_cur.REF_COLUMN_NAME || ' = ' 
							|| case when c_cur.COLUMN_EXPR_TYPE = 'PASSWORD' 
								then 'NVL(' 
									|| case when data_browser_pattern.Match_Encrypted_Columns(c_cur.REF_COLUMN_NAME) = 'YES'
										then data_browser_conf.Get_Encrypt_Function(p_Key_Column => v_Unique_Key_Column, p_Column_Name => c_cur.APEX_ITEM_CALL) 
										else data_browser_conf.Get_Hash_Function(p_Key_Column => v_Unique_Key_Column, p_Column_Name => c_cur.APEX_ITEM_CALL) 
									end
									|| ', ' || c_cur.REF_COLUMN_NAME || ')'
								else v_Column_Expr 
							end;
						end if;
					end if;
				end if;
            end if;
        end loop;
        if v_Result_Key_Expr IS NULL and p_Report_Mode = 'YES' and INSTR(v_Unique_Key_Column, ',') = 0 then 
        	v_Result_Key_Expr := data_browser_conf.Get_Link_ID_Expr || ' (p_Row)';
			v_Update_Where := v_Update_Where
			|| case when v_Update_Where IS NOT NULL then NL(16) || 'AND ' end
			|| data_browser_conf.Get_Unique_Key_Expression(
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Table_Alias => 'A',
				p_View_Mode => p_View_Mode
			) || ' = ' 
			|| v_Result_Key_Expr;
        end if;
        v_Exists_Key_Expr := case 
        when  p_Report_Mode = 'YES' 
        	and NOT(p_Data_Source = 'COLLECTION' -- and v_Result_Key_Hidden
        		) then 
        		data_browser_conf.Get_Link_ID_Expr || ' (p_Row)'
        	else 
        		v_Result_Key_Expr
        end;
		v_Build_MD5 := v_Update_List IS NOT NULL
					and v_Update_Where IS NOT NULL
					and p_Data_Source IN ('NEW_ROWS', 'TABLE', 'MEMORY')
					and v_Row_Op IN ('INSERT', 'UPDATE');
		if v_Build_MD5 then
			data_browser_edit.Get_Form_Changed_Check (
				p_Table_name => p_Table_name,
				p_Unique_Key_Column => v_Unique_Key_Column,
				p_Select_Columns => p_Select_Columns,
				p_Columns_Limit => p_Columns_Limit,
				p_View_Mode => p_View_Mode,
				p_Data_Source => p_Data_Source,
				p_Report_Mode => p_Report_Mode,
				p_Join_Options => p_Join_Options,
				p_Parent_Name => p_Parent_Name,
				p_Parent_Key_Column => p_Parent_Key_Column,
				p_Parent_Key_Visible => v_Parent_Key_Visible,
				p_Parent_Key_Item => p_Parent_Key_Item,
				p_Use_Empty_Columns => p_Use_Empty_Columns,
				p_Changed_Check_Condition => v_Changed_Check_Condition,
				p_Changed_Check_Plsql => v_Changed_Check_Plsql
			);
		end if;
		v_Indent := 8;
		if v_Changed_Check_Plsql IS NOT NULL then
			v_Result_Stat := v_Result_Stat
				|| NL(v_Indent)
				|| 'if NOT ( ' || v_Changed_Check_Plsql || ' ) then ';
			v_Indent := v_Indent + 4;
		end if;

		if v_Row_Op = 'INSERT' and v_Column_List IS NOT NULL then
			if v_Exists_Key_Expr IS NOT NULL then
				v_Result_Stat := v_Result_Stat
				|| NL(v_Indent)
				|| 'if ' || v_Exists_Key_Expr || ' is null then ';
				v_Indent := v_Indent + 4;
			end if;
			if v_Insert_Key_Expr IS NOT NULL then
				v_Result_Stat := v_Result_Stat
				|| NL(v_Indent)
				|| 'v_Key_Value := ' || v_Insert_Key_Expr || ';';
			end if;
			if v_Row_Op = 'INSERT' then
				v_Result_Stat := v_Result_Stat || NL(v_Indent)
				|| 'INSERT INTO ' || v_View_Name
				|| ' ( ' ||  v_Column_List || ')' || NL(v_Indent)
				|| 'VALUES (' || v_Values_List || ')';

				if v_Insert_Key_Expr IS NULL then
					if v_Table_Name = v_View_Name and INSTR(v_Unique_Key_Column, ',') = 0 and v_Unique_Key_Column IS NOT NULL then
						-- Get primary key value from trigger
						v_Result_Stat := v_Result_Stat || NL(v_Indent)
						|| 'RETURNING ' || v_Unique_Key_Column || ' INTO v_Key_Value;'
						|| NL(v_Indent);
					else
						v_Result_Stat := v_Result_Stat
						|| NL(v_Indent)
						|| 'RETURNING ROWID INTO v_Key_Value;'
						|| NL(v_Indent);
					end if;
				else
					v_Result_Stat := v_Result_Stat || ';' || NL(v_Indent);
				end if;
			end if;
			v_Result_Stat := v_Result_Stat || 'p_Rows_Inserted := p_Rows_Inserted + SQL%ROWCOUNT;';

			if v_Update_List IS NOT NULL and v_Update_Where IS NOT NULL 
			and v_Exists_Key_Expr IS NOT NULL then
				v_Result_Stat := v_Result_Stat
				|| NL(v_Indent - 4)
				|| 'else';
			end if;
		end if;
		if v_Update_List IS NOT NULL and v_Update_Where IS NOT NULL
		and (v_Row_Op = 'UPDATE' or v_Exists_Key_Expr IS NOT NULL) then
			v_Result_Stat := v_Result_Stat
				|| NL(v_Indent)
				|| 'UPDATE ' || data_browser_conf.Enquote_Name_Required(v_View_Name) || ' A ' || NL(v_Indent)
				|| 'SET ' || v_Update_List || NL(v_Indent)
				|| 'WHERE ' || v_Update_Where || NL(v_Indent)
				|| case when v_Changed_Check_Condition IS NOT NULL
						and v_Row_Version_Column_Name IS NULL then
					'AND ' || v_Changed_Check_Condition || NL(v_Indent)
				end;
			if INSTR(v_Unique_Key_Column, ',') > 0 then
				v_Result_Stat := v_Result_Stat
				|| 'RETURNING ROWID INTO v_Key_Value';
			end if;
			v_Result_Stat := v_Result_Stat
			|| ';' || NL(v_Indent)
			|| case when v_Build_MD5 then
				   'if SQL%ROWCOUNT = 0 then' || NL(v_Indent) -- ' Zeile wurde geändert seitdem der Update Vorgang eingeleitet wurde.'
				|| '    RAISE_APPLICATION_ERROR(-20100, '
				|| 'apex_lang.lang(''Record %0 has been changed since the update process was initiated.'', p_Row)'
				|| ');' || NL(v_Indent)
				|| 'else '|| NL(v_Indent + 4)
				|| 		'p_Rows_Updated := p_Rows_Updated + SQL%ROWCOUNT;' || NL(v_Indent)
				|| 'end if; '
			else
				'p_Rows_Updated := p_Rows_Updated + SQL%ROWCOUNT;'
			end;
			if v_Result_Key_Expr IS NOT NULL then
				v_Result_Stat := v_Result_Stat
					|| NL(v_Indent)
					|| 'v_Key_Value := ' || NVL(v_Result_Key_Expr, 'NULL') || ';';
			end if;
		end if;
		if v_Row_Op = 'INSERT'
		and v_Column_List IS NOT NULL and v_Exists_Key_Expr IS NOT NULL then
			v_Indent := v_Indent - 4;
			v_Result_Stat := v_Result_Stat
			|| NL(v_Indent)
			|| 'end if;';
		end if;
		if v_Changed_Check_Plsql IS NOT NULL then
			v_Indent := v_Indent - 4;
			v_Result_Stat := v_Result_Stat
				|| NL(v_Indent)
				|| 'end if; ';
		end if;
		v_Procedure_Name := INITCAP(data_browser_conf.Compose_Table_Column_Name(p_Table_name, REPLACE(v_Row_Op, 'INSERT', 'SAVE')));
		if DBMS_LOB.GETLENGTH(v_Result_Stat) > 1 then
			dbms_lob.append (v_Result_PLSQL,
				'declare ' || NL(4) ||
					'v_Row_Number PLS_INTEGER := 1; ' || NL(4) ||
					'v_Row_Count  PLS_INTEGER; ' || NL(4) ||
					'v_Rows_Inserted PLS_INTEGER := 0; ' || NL(4) ||
					'v_Rows_Updated PLS_INTEGER := 0; ' || NL(4) ||
					'v_Result     varchar2(4000);' || NL(4) ||
					'v_Key_Values apex_t_varchar2 := apex_t_varchar2();' || chr(10) || NL(4) ||
				'procedure ' || v_Procedure_Name || ' ( p_Row in number, p_Result_Key out varchar2, p_Rows_Inserted in out number, p_Rows_Updated in out number)' || NL(4) ||
				'is' || NL(8) ||
				    'v_Key_Value varchar2(1024);' || NL(4) ||
				'begin '
			);
			dbms_lob.append (v_Result_PLSQL, v_Result_Stat);

			v_Result_Stat := -- loop body
				v_Procedure_Name || ' ( p_Row => v_Row_Number, p_Result_Key => v_Result, p_Rows_Inserted => v_Rows_Inserted, p_Rows_Updated => v_Rows_Updated );'
				|| NL(8) ||
				'if v_Result IS NOT NULL then ' || NL(12) ||
					'v_Key_Values.extend;' || NL(12) ||
					'v_Key_Values(v_Key_Values.count) := v_Result;' || NL(8) ||
				'end if;';
			dbms_lob.append (v_Result_PLSQL,
				NL(8) ||
					'p_Result_Key := v_Key_Value;' || NL(4) ||
				'end;' || chr(10) || chr(10) ||
				'begin' || NL(4) ||
					'v_Row_Count := ' || nvl(v_Apex_Item_Rows_Call, '1') || '; ' || NL(4) ||
					'for v_Row_Number IN 1 .. v_Row_Count loop '  || NL(8) ||
						v_Result_Stat || NL(4) ||
					'end loop;' || NL(4) ||
					':b := v_Key_Values;' || NL(4) ||
					':c := v_Rows_Inserted;' || NL(4) ||
					':d := v_Rows_Updated;' || chr(10) ||
				'end;' || chr(10)
			);
		end if;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_edit.Get_Form_Edit_DML p_Table_name => %s, v_Result_PLSQL => %s',
				p0 => p_Table_name,
				p1 => v_Result_PLSQL,
				p_max_length => 3500
			);
		    data_browser_edit.Dump_Application_Items;
		$END
		if DBMS_LOB.GETLENGTH(v_Result_PLSQL) > 1 then
			return v_Result_PLSQL;
		else
			return NULL;
		end if;
	end Get_Form_Edit_DML;

	PROCEDURE Reset_Form_DML
	is
	begin
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Clob_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Clob_Collection);
		end if;
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Validation_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Validation_Collection);
		end if;
		if apex_collection.collection_exists(p_collection_name=>data_browser_conf.Get_Lookup_Collection) then
			apex_collection.delete_collection(p_collection_name=>data_browser_conf.Get_Lookup_Collection);
		end if;
		data_browser_edit.Clear_Application_Items;
		data_browser_blobs.Clear_Clob_Updates;
		data_browser_blobs.Init_Clob_Updates;
		commit;
	end Reset_Form_DML;

	PROCEDURE Process_Form_DML (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
    	p_Unique_Key_Value IN OUT VARCHAR2,
    	p_Error_Message OUT VARCHAR2,
    	p_Rows_Affected OUT NUMBER,
		p_New_Row IN VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item IN VARCHAR2 DEFAULT NULL,			-- Name of item with foreign key vale
    	p_Copy_Target_Item IN VARCHAR2 DEFAULT NULL, 		-- Name of item with Target ID for MOVE_ROWS, COPY_ROWS
    	p_Request IN VARCHAR2, -- SAVE / CREATE / DELETE%, DUPLICATE%, MOVE%, MERGE%, COPY%
    	p_First_Row IN PLS_INTEGER DEFAULT 1,
    	p_Last_Row IN PLS_INTEGER DEFAULT 1,
    	p_Inject_Defaults VARCHAR2 DEFAULT 'NO'
	) 
	is
		v_Unique_Key_Column  		MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Stat CLOB;
		v_Count  		PLS_INTEGER;
		v_Count2  		PLS_INTEGER;
		v_Row_Count  	PLS_INTEGER;
		v_Row_Limit		PLS_INTEGER;
		v_Rows_Inserted PLS_INTEGER := 0;
		v_Rows_Updated 	PLS_INTEGER := 0;
		v_Rows_Deleted 	PLS_INTEGER := 0;
		v_idx			PLS_INTEGER;
		v_Result     	VARCHAR2(4000);
		v_Key_Values 	apex_t_varchar2;
		v_Row_Op 		VARCHAR2(50);
		v_Message		VARCHAR2(32767);
		v_Debug_Message		VARCHAR2(32767);
		v_Parent_Key_Visible  VARCHAR2(10);
	begin
		v_Parent_Key_Visible := case when p_Select_Columns IS NOT NULL then 'YES' else p_Parent_Key_Visible end;
		p_Rows_Affected := 0;
		v_Row_Op := case
			when p_Request LIKE 'DUPLICATE%' then 'DUPLICATE'
			when p_Request LIKE 'COPY%' then 'COPY_ROWS'
			when p_Request LIKE 'MERGE%' then 'MERGE_ROWS'
			when p_Request LIKE 'MOVE%' then 'MOVE_ROWS'
			when p_Request LIKE 'SAVE%' then 'INSERT'
			when p_Request LIKE 'PROCESS_IMPORT%' then 'INSERT'
			when p_Request LIKE 'UPDATE%' then 'UPDATE'
			when p_Request LIKE 'DELETE%' then 'DELETE'
			when p_Request LIKE 'DOWNLOAD_FILES%' then 'DOWNLOAD_FILES'
			when p_Request LIKE 'DOWNLOAD_SELECTED%' then 'DOWNLOAD_SELECTED'
			when p_New_Row = 'YES' then 'INSERT'
			when p_New_Row = 'NO' then 'UPDATE'
			else p_New_Row end;

		v_Stat := data_browser_edit.Get_Form_Edit_DML(
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Row_Operation => v_Row_Op,
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Join_Options => p_Join_Options,
			p_Data_Source => p_Data_Source,
			p_Report_Mode => p_Report_Mode,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => case when v_Row_Op IN ('COPY_ROWS', 'MOVE_ROWS', 'MERGE_ROWS') and p_Data_Source != 'COLLECTION'
									then p_Copy_Target_Item
									else p_Parent_Key_Item end,
			p_Use_Empty_Columns => 'YES'
		);
		if v_Row_Op IN ('INSERT', 'UPDATE') then
			EXECUTE IMMEDIATE 'SET CONSTRAINTS ALL DEFERRED';
			if v_Stat IS NOT NULL then
				EXECUTE IMMEDIATE v_Stat USING OUT v_Key_Values, OUT v_Rows_Inserted, OUT v_Rows_Updated;
			end if;
			$IF data_browser_conf.g_debug $THEN
				v_Debug_Message := apex_string.format(
					p_message => 'data_browser_edit.Process_Form_DML: v_Rows_Inserted => %s, v_Rows_Updated => %s',
					p0 => v_Rows_Inserted,
					p1 => v_Rows_Updated,
					p_max_length => 3500
				);
				DBMS_OUTPUT.PUT_LINE(v_Debug_Message);
				apex_debug.info(v_Debug_Message);
			$END
			if v_Rows_Inserted + v_Rows_Updated > 0 then
				p_Unique_Key_Value := v_Key_Values(1);
			end if;
			v_Row_Count := v_Rows_Inserted + v_Rows_Updated;
			if v_Row_Count > 0 then
				p_Rows_Affected := v_Row_Count;
				apex_application.g_print_success_message := apex_application.g_print_success_message
				|| case when p_Request LIKE 'SAVE%' and p_Report_Mode = 'NO'
						then Apex_Lang.Lang('Record has been saved.')
					when p_Request LIKE 'CREATE%' and p_Report_Mode = 'NO'
						then Apex_Lang.Lang('Record has been created.')
					else
						case when v_Rows_Inserted > 0 then
							Apex_Lang.Lang('%0 rows have been inserted.', v_Rows_Inserted)
						end
						|| case when v_Rows_Updated > 0 then
							' ' || Apex_Lang.Lang('%0 rows have been updated.', v_Rows_Updated)
						end
					end;
			end if;
		elsif v_Row_Op IN ('DUPLICATE', 'COPY_ROWS', 'MERGE_ROWS') then
			if v_Stat IS NOT NULL then
				EXECUTE IMMEDIATE 'SET CONSTRAINTS ALL IMMEDIATE';

				if p_Report_Mode = 'NO' then
					EXECUTE IMMEDIATE v_Stat USING IN p_Unique_Key_Value, OUT v_Rows_Inserted;
					if v_Rows_Inserted > 0 then
						p_Rows_Affected := v_Rows_Inserted;
						apex_application.g_print_success_message := apex_application.g_print_success_message
						|| case when v_Row_Op = 'DUPLICATE'
							then Apex_Lang.Lang('Record has been duplicated.')
						when v_Row_Op = 'COPY_ROWS'
							then Apex_Lang.Lang('Record has been copied.')
						when v_Row_Op = 'MERGE_ROWS'
							then Apex_Lang.Lang('Record has been merged.')
						end;
					end if;
				elsif p_Report_Mode = 'YES' then -- Processed ROW_SELECTOR Column
					EXECUTE IMMEDIATE v_Stat USING OUT v_Rows_Inserted;
					if v_Rows_Inserted > 0 then
						p_Rows_Affected := v_Rows_Inserted;
						apex_application.g_print_success_message := apex_application.g_print_success_message
						|| case when v_Row_Op = 'DUPLICATE'
							then Apex_Lang.Lang('%0 rows have been duplicated.', v_Rows_Inserted)
						when v_Row_Op = 'COPY_ROWS'
							then Apex_Lang.Lang('%0 rows have been copied.', v_Rows_Inserted)
						when v_Row_Op = 'MERGE_ROWS'
							then Apex_Lang.Lang('%0 rows have been merged.', v_Rows_Inserted)
						end;
					end if;
				end if;
			end if;
		elsif v_Row_Op = 'DELETE' then
			if v_Stat IS NOT NULL then
				EXECUTE IMMEDIATE 'SET CONSTRAINTS ALL IMMEDIATE';

				if p_Report_Mode = 'NO' then
					EXECUTE IMMEDIATE v_Stat USING IN p_Unique_Key_Value, OUT v_Rows_Deleted;
					if v_Rows_Deleted > 0 then
						p_Unique_Key_Value := NULL;
						p_Rows_Affected := v_Rows_Deleted;
						apex_application.g_print_success_message := apex_application.g_print_success_message
						|| Apex_Lang.Lang('Record has been deleted.');
					end if;
				elsif p_Report_Mode = 'YES' then -- Processed ROW_SELECTOR Column
					EXECUTE IMMEDIATE v_Stat USING OUT v_Rows_Deleted;
					if v_Rows_Deleted > 0 then
						p_Rows_Affected := v_Rows_Deleted;
						apex_application.g_print_success_message := apex_application.g_print_success_message
						|| Apex_Lang.Lang('%0 rows have been deleted.', v_Rows_Deleted);
					end if;
				end if;
			end if;
		elsif v_Row_Op = 'MOVE_ROWS' then
			if v_Stat IS NOT NULL then
				EXECUTE IMMEDIATE 'SET CONSTRAINTS ALL IMMEDIATE';

				if p_Report_Mode = 'NO' then
					EXECUTE IMMEDIATE v_Stat USING IN p_Unique_Key_Value, OUT v_Rows_Updated;
					if v_Rows_Updated > 0 then
						p_Unique_Key_Value := NULL;
						p_Rows_Affected := v_Rows_Updated;
						apex_application.g_print_success_message := apex_application.g_print_success_message
						|| Apex_Lang.Lang('Record has been moved.');
					end if;
				elsif p_Report_Mode = 'YES' then -- Processed ROW_SELECTOR Column
					EXECUTE IMMEDIATE v_Stat USING OUT v_Rows_Updated;
					if v_Rows_Updated > 0 then
						p_Rows_Affected := v_Rows_Updated;
						apex_application.g_print_success_message := apex_application.g_print_success_message
						|| Apex_Lang.Lang('%0 rows have been moved.', v_Rows_Updated);
					end if;
				end if;
			end if;
		elsif v_Row_Op = 'DOWNLOAD_SELECTED' then
			if p_Report_Mode = 'YES' then
				EXECUTE IMMEDIATE v_Stat USING IN p_Unique_Key_Value, OUT v_Rows_Deleted;
				if v_Rows_Inserted > 0 then
					p_Unique_Key_Value := NULL;
					p_Rows_Affected := v_Rows_Inserted;
					apex_application.g_print_success_message := apex_application.g_print_success_message
					|| Apex_Lang.Lang('File has been downloaded.');
				end if;
			elsif p_Report_Mode = 'NO' then -- Processed ROW_SELECTOR Column
				EXECUTE IMMEDIATE v_Stat USING OUT v_Rows_Inserted;
				if v_Rows_Inserted > 0 then
					p_Rows_Affected := v_Rows_Inserted;
					apex_application.g_print_success_message := apex_application.g_print_success_message
					|| Apex_Lang.Lang('%0 files have been downloaded.', v_Rows_Inserted);
				end if;
			end if;
		elsif v_Row_Op = 'DOWNLOAD_FILES' then
			if p_Report_Mode = 'YES' then -- Processed ROW_SELECTOR Column
				EXECUTE IMMEDIATE v_Stat USING OUT v_Rows_Inserted;
				if v_Rows_Inserted > 0 then
					p_Rows_Affected := v_Rows_Inserted;
					apex_application.g_print_success_message := apex_application.g_print_success_message
					|| Apex_Lang.Lang('%0 files have been downloaded.', v_Rows_Inserted);
				end if;
			end if;
		else 
			v_Message := 'Error unsupported DML request: ' || nvl(p_Request, 'void') || ' - row operation: ' || nvl(v_Row_Op, 'void');
		end if;
		if p_Request LIKE 'PROCESS_IMPORT%'
		and v_Row_Count > 0 then -- form rows have been processed.
		----------------------------------------------------------------------------------------
			-- the collection members that where submitted in the form and that are processed successfully can be removed.
			APEX_COLLECTION.RESEQUENCE_COLLECTION(p_collection_name => data_browser_conf.Get_Import_Collection);
			v_Count := APEX_COLLECTION.COLLECTION_MEMBER_COUNT(p_collection_name => data_browser_conf.Get_Import_Collection);
			v_Row_Limit := LEAST(v_Count, p_Last_Row);
			if v_Row_Limit > 0 and v_Row_Count > 0 then 
				for v_idx IN p_First_Row..p_Last_Row loop
					Apex_Collection.Delete_Member(p_collection_name => data_browser_conf.Get_Import_Collection, p_seq => v_idx);
					v_Count := v_Count - 1;
				end loop;
				COMMIT;
			end if;
			$IF data_browser_conf.g_debug $THEN
				v_Debug_Message := apex_string.format(
					p_message => 'data_browser_edit.Process_Form_DML: PROCESS_IMPORT tabular form rows processed => %s, First_Row => %s, Last_Row => %s, Remaining Collection Rows => %s',
					p0 => v_Key_Values.count,
					p1 => p_First_Row,
					p2 => p_Last_Row,
					p3 => v_Count,
					p_max_length => 3500
				);
				DBMS_OUTPUT.PUT_LINE(v_Debug_Message);
				apex_debug.info(v_Debug_Message);
			$END
			if v_Count > 0 then 
				if p_Inject_Defaults = 'YES' then 
					Set_Import_View_Defaults (
						p_Table_name => p_Table_name,
						p_Unique_Key_Column => p_Unique_Key_Column,
						p_Select_Columns => p_Select_Columns,
						p_Columns_Limit => p_Columns_Limit,
						p_View_Mode => p_View_Mode,
						p_Parent_Name => p_Parent_Name,
						p_Join_Options => p_Join_Options,
						p_Parent_Key_Column => p_Parent_Key_Column,
						p_Parent_Key_Visible => p_Parent_Key_Visible,
						p_Parent_Key_Item => p_Parent_Key_Item
					);
				end if;
				v_Message := data_browser_edit.Validate_Form_Foreign_Keys(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Data_Source => 'COLLECTION',
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Join_Options => p_Join_Options,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_DML_Command => 'INSERT',
					p_Use_Empty_Columns => 'YES',
					p_Exec_Phase => 1
				);
				v_Message := v_Message || data_browser_edit.Validate_Form_Foreign_Keys(
					p_Table_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Data_Source => 'COLLECTION',
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Join_Options => p_Join_Options,
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_Use_Empty_Columns => 'YES',
					p_DML_Command => 'INSERT',
					p_Exec_Phase => 2
				);
				/* lookup PK with natural key columns */
				v_Message := v_Message || data_browser_edit.Validate_Form_Checks(
					p_Table_name => p_Table_name,
					p_Key_Column => p_Unique_Key_Column,
					p_Key_Value => NULL,
					p_Select_Columns => p_Select_Columns,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Join_Options => p_Join_Options,
					p_Data_Source => 'COLLECTION',
					p_Report_Mode => 'YES',
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => p_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item,
					p_Use_Empty_Columns => 'YES'
				);
				$IF data_browser_conf.g_debug $THEN
					v_Debug_Message := apex_string.format(
						p_message => 'data_browser_edit.Process_Form_DML: PROCESS_IMPORT Collection rows prepared; Message => %s',
						p0 => v_Message,
						p_max_length => 3500
					);
					DBMS_OUTPUT.PUT_LINE(v_Debug_Message);
					apex_debug.info(v_Debug_Message);
				$END
				COMMIT;
				-- The form has a limit for the number of displayed rows (data_browser_conf.Get_Edit_Rows_Limit). 
				-- When more than Edit_Rows_Limit rows imported, this rows can be processed by accessing the collection.
				v_Stat := Get_Copy_Rows_DML(
					p_View_name => p_Table_name,
					p_Unique_Key_Column => p_Unique_Key_Column,
					p_Row_Operation => 'MERGE_ROWS',
					p_Select_Columns => p_Select_Columns,
					p_Join_Options => p_Join_Options,
					p_Columns_Limit => p_Columns_Limit,
					p_View_Mode => p_View_Mode,
					p_Data_Source => 'COLLECTION',
					p_Report_Mode => 'YES',
					p_Parent_Name => p_Parent_Name,
					p_Parent_Key_Column => p_Parent_Key_Column,
					p_Parent_Key_Visible => v_Parent_Key_Visible,
					p_Parent_Key_Item => p_Parent_Key_Item
				);
				$IF data_browser_conf.g_debug $THEN
					for c_cur in (
						SELECT COUNT(*)  rows_count,
							COUNT(DISTINCT N001) N1_count,
							COUNT(DISTINCT N002) N2_count,
							COUNT(DISTINCT N003) N3_count,
							COUNT(DISTINCT N004) N4_count,
							COUNT(DISTINCT N005) N5_count
						FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = data_browser_conf.Get_Import_Collection
					) loop 					
					v_Debug_Message := apex_string.format(
						p_message => 'Import-Collection-Cnt : %s, N1:%s, N2:%s, N3:%s, N4:%s, N5:%s Import-MERGE-ROWS statment: %s', 
						p0 => c_cur.rows_count, 
						p1 => c_cur.N1_count,
						p2 => c_cur.N2_count,
						p3 => c_cur.N3_count,
						p4 => c_cur.N4_count,
						p5 => c_cur.N5_count,
						p6 => v_Stat, 
						p_max_length => 3500);
					apex_debug.info(v_Debug_Message);
					end loop;
				$END
				v_Message := null;
				if v_Stat IS NOT NULL then
					begin
						EXECUTE IMMEDIATE 'SET CONSTRAINTS ALL IMMEDIATE';

						EXECUTE IMMEDIATE v_Stat USING OUT v_Rows_Inserted;
						if v_Rows_Inserted > 0 then
							p_Rows_Affected := v_Rows_Inserted;
							apex_application.g_print_success_message := apex_application.g_print_success_message
							|| ' ' || Apex_Lang.Lang('Additional %0 imported rows have been merged.', v_Rows_Inserted);
						end if;
						$IF data_browser_conf.g_debug $THEN	
							apex_debug.info('Copy_Rows_DML completed with %s rows affected.', v_Rows_Inserted);
						$END
					exception
					  when others then
						v_Message := Apex_Lang.Lang('DML processing for %0 failed with %1.', p_Table_name, SQLERRM);
					end;
				end if;
			end if;
			COMMIT;
			if v_Message IS NULL then
				data_browser_edit.Reset_Import_Description;
			end if;
		----------------------------------------------------------------------------------
		end if;
		if v_Rows_Deleted > 0 or v_Rows_Inserted > 0 then 
			data_browser_jobs.Refresh_Tree_View_Job;
		end if;
		$IF data_browser_conf.g_debug $THEN
			v_Debug_Message := apex_string.format(
				p_message => 'data_browser_edit.Process_Form_DML p_Table_name => %s, v_Row_Op => %s, v_Rows_Inserted => %s, v_Rows_Updated => %s, success_message ?> %s. error_msg => %s',
				p0 => p_Table_name,
				p1 => v_Row_Op,
				p2 => v_Rows_Inserted,
				p3 => v_Rows_Updated,
				p4 => apex_application.g_print_success_message,
				p5 => v_Message,
				p_max_length => 3500
			);
			DBMS_OUTPUT.PUT_LINE(v_Debug_Message);
			apex_debug.info(v_Debug_Message);
		    data_browser_edit.Dump_Application_Items;
		$END
		p_Error_Message := v_Message;
		data_browser_edit.Reset_Form_DML;
		----------------------------------------------------------------------------------
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
		p_Error_Message := Apex_Lang.Lang('DML processing for %0 failed with %1.', p_Table_name, SQLERRM);
$END
	end Process_Form_DML;

	PROCEDURE Process_Form_DML (
		p_Table_name IN VARCHAR2,
    	p_Unique_Key_Column IN VARCHAR2 DEFAULT NULL,
    	p_Unique_Key_Value IN OUT NOCOPY VARCHAR2,
		p_New_Row IN VARCHAR2 DEFAULT 'NO',				-- YES, NO
    	p_Select_Columns VARCHAR2 DEFAULT NULL,	
		p_Columns_Limit IN NUMBER DEFAULT 1000,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',
    	p_Data_Source VARCHAR2 DEFAULT 'TABLE',				-- NEW_ROWS, TABLE, COLLECTION, MEMORY.
		p_Report_Mode VARCHAR2 DEFAULT 'NO', 				-- YES, NO
    	p_Join_Options VARCHAR2 DEFAULT NULL,
    	p_Parent_Name VARCHAR2 DEFAULT NULL,				-- Parent View or Table name. In View_Mode NAVIGATION_VIEW if set columns from the view are included in the Column list
    	p_Parent_Key_Column VARCHAR2 DEFAULT NULL,			-- Column Name with foreign key to Parent Table
    	p_Parent_Key_Visible VARCHAR2 DEFAULT 'NO',			-- YES, NO, NULLABLE. Show foreign key column
    	p_Parent_Key_Item IN VARCHAR2 DEFAULT NULL,			-- Name of item with foreign key vale
    	p_Copy_Target_Item IN VARCHAR2 DEFAULT NULL, 		-- Name of item with Target ID for MOVE_ROWS, COPY_ROWS
    	p_Request IN VARCHAR2, -- SAVE / CREATE / DELETE%, DUPLICATE%, MOVE%, MERGE%, COPY%
    	p_First_Row IN PLS_INTEGER DEFAULT 1,
    	p_Last_Row IN PLS_INTEGER DEFAULT 1,
    	p_Inject_Defaults VARCHAR2 DEFAULT 'YES',
		p_Register_Apex_Error VARCHAR2 DEFAULT 'YES'
	)
	is
		v_Error_Message VARCHAR2(32767);
		v_Rows_Affected NUMBER;
	begin
		data_browser_edit.Process_Form_DML(
			p_Table_name => p_Table_name,
			p_Unique_Key_Column => p_Unique_Key_Column,
			p_Unique_Key_Value => p_Unique_Key_Value,
			p_Error_Message => v_Error_Message,
			p_Rows_Affected => v_Rows_Affected,
			p_New_Row => p_New_Row,
			p_Select_Columns => p_Select_Columns,
			p_Columns_Limit => p_Columns_Limit,
			p_View_Mode => p_View_Mode,
			p_Data_Source => p_Data_Source,
			p_Report_Mode => p_Report_Mode,
			p_Join_Options => p_Join_Options,
			p_Parent_Name => p_Parent_Name,
			p_Parent_Key_Column => p_Parent_Key_Column,
			p_Parent_Key_Visible => p_Parent_Key_Visible,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Copy_Target_Item => p_Copy_Target_Item,
			p_Request => p_Request,
			p_First_Row => p_First_Row,
			p_Last_Row => p_Last_Row,
			p_Inject_Defaults => p_Inject_Defaults
		);
		
		if v_Error_Message IS NOT NULL then 
			if p_Register_Apex_Error = 'YES' then 
				Apex_Error.Add_Error (
					p_message  => v_Error_Message,
					p_display_location => apex_error.c_inline_in_notification
				);
			else 
				RAISE_APPLICATION_ERROR(-20006, 'Process_Form_DML failed with error : ' || v_Error_Message);
			end if;
		end if;
	end Process_Form_DML;




	FUNCTION Get_Row_Selector RETURN VARCHAR2
	is
		v_Dump 			VARCHAR2(32767);
		v_Count 		PLS_INTEGER;
	begin
		Get_Application_Item(p_Index => data_browser_conf.Get_Row_Selector_Index, p_Dump => v_Dump, p_Count => v_Count);
		return v_Dump;
	end Get_Row_Selector;


end data_browser_edit;
/
show errors

/*
data_browser_edit.Process_Form_DML (
	p_Table_name => :P30_TABLE_NAME,
	p_Unique_Key_Column => :P30_LINK_KEY,
	p_Unique_Key_Value => :APP_PRO_KEY_VALUE,
	p_New_Row => :P30_ADD_ROW,
	p_View_Mode => :P30_VIEW_MODE,
	p_Report_Mode => 'YES',
	p_Request => :REQUEST
);

data_browser_edit.Process_Form_DML (
	p_Table_name => :P32_TABLE_NAME,
	p_Unique_Key_Column => :P32_LINK_KEY,
	p_Unique_Key_Value => :P32_LINK_ID,
	p_New_Row => :P32_ADD_ROW,
	p_View_Mode => :P32_VIEW_MODE,
	p_Report_Mode => 'NO',
	p_Parent_Key_Column => :P32_PARENT_NAME,
	p_Parent_Key_Item => 'P32_PARENT_ID',
	p_Request => :REQUEST
);

*/
