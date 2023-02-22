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

CREATE OR REPLACE VIEW VDATA_BROWSER_SEARCH_OPS (
	display_value, return_value, is_number, operands
)
AS
select apex_lang.lang(search_op) display_value, search_op return_value, '%' is_number, 1 operands
from (
    SELECT column_value search_op 
    from table(apex_string.split('=:!=',':'))
)
union all 
select search_op display_value, search_op return_value, 'Y' is_number, 1 operands
from (
    SELECT column_value search_op 
    from table(apex_string.split('>:>=:<:<=',':'))
)
union all
select apex_lang.lang(search_op) display_value, upper(search_op) return_value, '%' is_number, 0 operands
from (
    SELECT column_value search_op 
    from table(apex_string.split('is null:is not null',':'))
)
union all
select apex_lang.lang(search_op) display_value, upper(search_op) return_value, '%' is_number, 1 operands
from (
    SELECT column_value search_op 
    from table(apex_string.split('like:not like:in:not in:contains',':'))
)
union all
select apex_lang.lang('does not contain') display_value, 'NOT CONTAINS' return_value, 'N' is_number, 1 operands
from dual
union all
select apex_lang.lang('matches regular expression') display_value, 'REGEXP' return_value, 'N' is_number, 1 operands
from dual
;

CREATE OR REPLACE VIEW VDATA_BROWSER_FILTER_COLS (COLUMN_HEADER, COLUMN_NAME)
AS
SELECT COLUMN_HEADER, COLUMN_NAME
FROM TABLE (data_browser_utl.Get_Detail_View_Column_Cursor(
		p_Table_name=> V('P30_TABLE_NAME'), 
	    p_Unique_Key_Column => V('P30_LINK_KEY'),
		p_Format => 'SEARCH',
		p_Join_Options=> V('P30_JOINS'), 
		p_View_Mode=> V('P30_VIEW_MODE'), 
		p_Parent_Name=> V('P30_PARENT_NAME'),
		p_Parent_Key_Column=> V('P30_FKEY_COLUMN'),
		p_Parent_Key_Visible=> 'YES'
	)
);

-- problem: the javascript init code is not executed on refresh of the region
CREATE OR REPLACE VIEW VDATA_BROWSER_FILTER_CONDS (
	SEQ_ID, Field, Operator, Expression, Active, Remove, Add_Filter
)
AS
with col_info_q as (
	select COLUMN_NAME, REF_TABLE_NAME, REF_COLUMN_NAME, TABLE_ALIAS, COLUMN_EXPR, COLUMN_EXPR_TYPE,
		case when B.COLUMN_EXPR_TYPE IN ('SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER', 'TEXT', 'TEXTAREA', 'NUMBER', 'DATE_POPUP', 'POPUP_FROM_LOV') then 
			'select distinct ' || B.COLUMN_EXPR || ' d, ' || B.TABLE_ALIAS || '.' || B.REF_COLUMN_NAME
			|| ' r from ' || B.REF_TABLE_NAME || ' ' || B.TABLE_ALIAS 
			|| ' order by 1'
			|| ' fetch first 200 rows only'
		when COLUMN_EXPR_TYPE IN ('SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV') then
			LOV_QUERY
		end LOV_QUERY
	from TABLE (data_browser_select.Get_View_Column_Cursor (
		p_Table_name=> V('P30_TABLE_NAME'), 
	    p_Unique_Key_Column => V('P30_LINK_KEY'),
		p_Data_Columns_Only=> 'YES', 
		p_Select_Columns=> '', 
		p_Join_Options=> V('P30_JOINS'), 
		p_View_Mode=> V('P30_VIEW_MODE'), 
		p_Report_Mode=>'ALL', 
		p_Parent_Name=> V('P30_PARENT_NAME'),
		p_Parent_Key_Column=> V('P30_FKEY_COLUMN'),
		p_Parent_Key_Visible=> 'YES'
		)
	) B
	where data_browser_select.FN_Is_Searchable_Column(COLUMN_EXPR_TYPE, IS_SEARCHABLE_REF) = 'YES'
)
select 
		A.SEQ_ID,
		'<div class="t-Form-itemWrapper">'
		|| '<span class="t-Icon fa fa-filter" aria-hidden="true" style="margin-top: 4px;margin-right: 4px;"></span>'
		|| APEX_ITEM.SELECT_LIST_FROM_QUERY_XL (p_idx => data_browser_conf.Get_Search_Column_Index, p_value => C001
       					, p_query => 'SELECT COLUMN_HEADER d, COLUMN_NAME r FROM VDATA_BROWSER_FILTER_COLS ORDER BY 1'
						, p_attributes => 'class="popup_lov apex-item-text" style="max-width: 220px"'
						, p_null_value => '%', p_null_text => 'All Columns'
						, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_Column_Index, 2, '0') || '_' || ROWNUM
						, p_item_label => 'Field'
						)
		|| '</div>'
		Field,
        CAST(APEX_ITEM.SELECT_LIST_FROM_QUERY (p_idx => data_browser_conf.Get_Search_Operator_Index, p_value => C002
       					, p_query => 'SELECT display_value d, return_value r FROM VDATA_BROWSER_SEARCH_OPS'
						, p_attributes => 'class="popup_lov apex-item-text" style="max-width: 100px;"'
						, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_Operator_Index, 2, '0') || '_' || ROWNUM
						, p_item_label => 'Operator'
		) AS VARCHAR2(1024)) Operator,
		case when A.C002 IN ('=', '>', '>=', '<', '<=', '!=') and B.LOV_QUERY IS NOT NULL then 
			case when C005 IS  NULL then 
				APEX_ITEM.TEXT (p_idx => data_browser_conf.Get_Search_Value_Index, p_value => C003
							, p_size => 30, p_maxlength => 500, p_attributes => 'class="text_field apex-item-text" '
							, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_Value_Index, 2, '0') || '_' || ROWNUM
							, p_item_label => 'Expression') 
			end ||
       		APEX_ITEM.SELECT_LIST_FROM_QUERY_XL (p_idx => data_browser_conf.Get_Search_LOV_Index, p_value => C005
       					, p_query => B.LOV_QUERY
       					, p_attributes => 'class="popup_lov apex-item-text" style="margin-left: 2px; max-width: ' 
       									|| case when C005 is not null then '220' else '32' end || 'px;"'
       					, p_null_value => NULL, p_null_text => '-'
						, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_LOV_Index, 2, '0') || '_' || ROWNUM
						, p_item_label => 'LOV-Value') 
		else 
			TO_CLOB(APEX_ITEM.TEXT (p_idx => data_browser_conf.Get_Search_Value_Index, p_value => C003
						, p_size => 25, p_maxlength => 100, p_attributes => 'class="text_field apex-item-text" '
						, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_Value_Index, 2, '0') || '_' || ROWNUM
						, p_item_label => 'Expression'))
		end Expression,
       	CAST(APEX_ITEM.HIDDEN (p_idx => data_browser_conf.Get_Search_Seq_ID_Index, p_value => A.SEQ_ID
       					, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_Seq_ID_Index, 2, '0') || '_' || ROWNUM, p_item_label => '') ||
 	      	case when LEAD(A.SEQ_ID) OVER (ORDER BY A.SEQ_ID) IS NULL then
				q'{<button onclick="apex.submit({request:'GO'});" class="t-Button t-Button--success t-Button--noUI" type="button" style="margin-top: 4px;"}'
				|| 'id="SEARCH_GO"><span class="t-Button-label">' || apex_lang.lang('Go') || '</span></button>'
			else 
				APEX_ITEM.CHECKBOX2 (p_idx => data_browser_conf.Get_Search_Active_Index, p_value => C004
								, p_attributes => 'class="js-ignoreChange" style="margin-right: 14px;margin-left: 14px;"'
								, p_checked_values => 'Y'
								, p_item_id => 'f' || LPAD(data_browser_conf.Get_Search_Active_Index, 2, '0') || '_' || ROWNUM
								, p_item_label => 'Active') 
			end
		AS VARCHAR2(2048)) Active,
    	'<button class="t-Button t-Button--noLabel t-Button--icon t-Button--danger t-Button--noUI" style="margin-top: 4px;" onclick="void(0);" type="button" ' ||
    	'id="REMOVE" title="Remove" aria-label="Remove">' ||
    		'<span class="t-Icon fa fa-remove" aria-hidden="true"></span>' ||
		'</button>' Remove,
		case when LEAD(A.SEQ_ID) OVER (ORDER BY A.SEQ_ID) IS NULL then 
			'<button class="t-Button t-Button--noLabel t-Button--icon t-Button--success t-Button--noUI" style="margin-top: 4px;" onclick="void(0);" type="button" ' ||
			'id="ADD_FILTER" title="Add Filter" aria-label="Add Filter">' ||
    			'<span class="t-Icon fa fa-plus" aria-hidden="true"></span>' ||
			'</button>' 
		end Add_Filter
from APEX_COLLECTIONS A 
left outer join col_info_q B on A.C001 = B.COLUMN_NAME
where A.COLLECTION_NAME = data_browser_conf.Get_Filter_Cond_Collection || V('APP_PAGE_ID')
;


CREATE OR REPLACE VIEW VDATA_BROWSER_COLUMN_RULES (
	view_name, Table_Name, Table_Owner, Column_Name, Data_Type, 
	Rule_Name, Return_Value, Rule_Data_Type, Rule_Has_Blob, 
	Match_Column_Pattern, Refresh_Starting_Step, Match_Type
)
AS
select view_name, Table_Name, Table_Owner, Column_Name, Data_Type, 
	Rule_Name, Return_Value, 
	Rule_Data_Type, Rule_Has_Blob,
	case when return_Value = 'YES_NO_COLUMNS_PATTERN' and rule_data_type = 'BOOLEAN' then 
		column_name
	else Match_Column_Pattern
	end Match_Column_Pattern, 
	Refresh_Starting_Step,
	case when return_Value = 'YES_NO_COLUMNS_PATTERN' and rule_data_type = 'BOOLEAN' then 
			'by rules'
		when SUBSTR(Match_Column_Pattern, 1, 1) = '%' then 
			case when SUBSTR(Match_Column_Pattern, -1, 1) = '%' then 
				'contains'
			else 
				'begins with'
			end 
		when SUBSTR(Match_Column_Pattern, -1, 1) = '%' then
			'ends with'
		else 
			'equals'
	end Match_Type
from (
	select c.view_name, c.table_name, C.table_owner, c.column_name, c.data_type
		,apex_lang.lang(b.display_value) rule_name, b.return_Value, b.data_type rule_data_type, b.rule_has_blob
		,data_browser_conf.Matching_Column_Pattern(c.column_name, b.Pattern) Match_Column_Pattern
		,case when b.return_Value IN ('DISPLAY_COLUMNS_PATTERN','ROW_VERSION_COLUMN_PATTERN','ROW_LOCK_COLUMN_PATTERN',
			'SOFT_DELETE_COLUMN_PATTERN', 'ORDERING_COLUMN_PATTERN', 'ACTIVE_LOV_FIELDS_PATTERN', 
			'FILE_NAME_COLUMN_PATTERN', 'MIME_TYPE_COLUMN_PATTERN', 'FILE_CREATED_COLUMN_PATTERN',
			'FILE_CONTENT_COLUMN_PATTERN', 'FILE_FOLDER_FIELD_PATTERN', 'FOLDER_NAME_FIELD_PATTERN', 'FOLDER_PARENT_FIELD_PATTERN',
			'FILE_PRIVILEGE_FLD_PATTERN', 'INDEX_FORMAT_FIELD_PATTERN', 'AUDIT_COLUMN_PATTERN'
		) then 
			data_browser_jobs.Get_Refresh_Start_Unique
		when b.return_Value IN ('CALENDAR_START_DATE_PATTERN','CALENDAR_END_DATE_PATTERN') then 
			data_browser_jobs.Get_Refresh_Start_Foreign
		else data_browser_jobs.Get_Refresh_Start_Project
		end Refresh_Starting_Step
	from (
		select T.TABLE_NAME, T.TABLE_OWNER,
			T.ROW_VERSION_COLUMN_NAME,
			T.ROW_LOCKED_COLUMN_NAME,
			T.SOFT_DELETED_COLUMN_NAME,
			D.ORDERING_COLUMN_NAME,
			D.ACTIVE_LOV_COLUMN_NAME,
			T.HTML_FIELD_COLUMN_NAME,
			D.CALEND_START_DATE_COLUMN_NAME,
			D.CALENDAR_END_DATE_COLUMN_NAME,
			T.FILE_NAME_COLUMN_NAME,
			T.MIME_TYPE_COLUMN_NAME,
			T.FILE_DATE_COLUMN_NAME,
			T.FILE_CONTENT_COLUMN_NAME,
			T.FILE_FOLDER_COLUMN_NAME,
			D.FOLDER_NAME_COLUMN_NAME,
			D.FOLDER_PARENT_COLUMN_NAME,
			T.FILE_PRIVILEGE_COLUMN_NAME,
			T.INDEX_FORMAT_COLUMN_NAME,
			T.AUDIT_DATE_COLUMN_NAME,
			T.AUDIT_USER_COLUMN_NAME,
			case when exists (
				select 1 
				from SYS.ALL_TAB_COLS B
				where B.TABLE_NAME = T.TABLE_NAME 
				AND B.OWNER = T.TABLE_OWNER
				and B.DATA_TYPE = 'BLOB'
				) then 'Y' else 'N' 
			end table_has_blob
		from MVDATA_BROWSER_VIEWS T, MVDATA_BROWSER_DESCRIPTIONS D
		where T.VIEW_NAME = D.VIEW_NAME
	) t join (
		select view_name, table_name, table_owner, column_name, 
		case when IS_NUMBER_YES_NO_COLUMN = 'Y' or IS_CHAR_YES_NO_COLUMN = 'Y' then 
				'BOOLEAN'
			when exists (
				select 1
				from MVDATA_BROWSER_FKEYS
				where view_name = c.table_name
				 AND OWNER = c.table_owner
				and foreign_key_cols = c.column_name			
			) then
				'REFERENCE'
			when data_type = 'FLOAT' then 
				'NUMBER' 
			when data_type IN ('VARCHAR', 'VARCHA2','CHAR') then 
				'VARCHAR2' 
			when data_type LIKE 'TIMESTAMP%' then 
				'DATE' 
			else data_type
		end rule_data_type, data_type, data_scale
		from MVDATA_BROWSER_SIMPLE_COLS c
	) c on t.table_name = c.table_name AND T.table_owner = C.table_owner
	join (
		select 'Read-only Field' display_value, 'READONLY_COLUMNS_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_ReadOnly_Columns_Pattern Pattern
		from dual union all 
		select 'Hidden in Reports' display_value, 'HIDDEN_COLUMNS_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Hidden_Columns_Pattern Pattern
		from dual union all 
		select 'Ignored Column' display_value, 'IGNORED_COLUMNS_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Ignored_Columns_Pattern Pattern
		from dual union all 
		select 'Data Deducted Field' display_value, 'DATA_DEDUCTION_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Data_Deduction_Pattern Pattern
		from dual union all 
		select 'Obfuscated Data' display_value, 'OBFUSCATION_COLUMN_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Obfuscation_Column_Pattern Pattern
		from dual union all 
		select 'Password Field' display_value, 'PASSWORD_COLUMN_PATTERN' return_Value,
				'VARCHAR2' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Password_Column_Pattern Pattern
		from dual union all 
		select 'Encrypted Data' display_value, 'ENCRYPTED_COLUMN_PATTERN' return_Value,
				'VARCHAR2' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Encrypted_Column_Pattern Pattern
		from dual union all 
		select 'Always Displayed' display_value, 'DISPLAY_COLUMNS_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Display_Columns_Pattern Pattern
		from dual union all ------------------------------------------------------------------
		select 'Calendar Start Date' display_value, 'CALENDAR_START_DATE_PATTERN' return_Value,
				'DATE' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Calend_Start_Date_Pattern Pattern
		from dual union all 
		select 'Calendar End Date' display_value, 'CALENDAR_END_DATE_PATTERN' return_Value,
				'DATE' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Calendar_End_Date_Pattern Pattern
		from dual union all 
		select 'Show Date and Time' display_value, 'DATETIME_COLUMNS_PATTERN' return_Value,
				'DATE' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_DateTime_Columns_Pattern Pattern
		from dual union all ------------------------------------------------------------------
		select 'Summand Value' display_value, 'SUMMAND_FIELD_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Summand_Field_Pattern Pattern
		from dual union all 
		select 'Minuend Value' display_value, 'MINUEND_FIELD_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Minuend_Field_Pattern Pattern
		from dual union all 
/*		select 'Factors Value' display_value, 'FACTORS_FIELD_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Factors_Field_Pattern Pattern
		from dual union all */
		select 'Currency Field' display_value, 'CURRENCY_COLUMN_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Currency_Column_Pattern Pattern
		from dual union all 
		select 'Ordering Field' display_value, 'ORDERING_COLUMN_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Ordering_Column_Pattern Pattern
		from dual union all 
		select 'Row Version Field' display_value, 'ROW_VERSION_COLUMN_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Row_Version_Column_Pattern Pattern
		from dual union all ------------------------------------------------------------------
		select 'Row Lock Field' display_value, 'ROW_LOCK_COLUMN_PATTERN' return_Value,
				'BOOLEAN' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Row_Lock_Column_Pattern Pattern
		from dual union all 
		select 'Soft Lock Field' display_value, 'SOFT_LOCK_FIELD_PATTERN' return_Value,
				'BOOLEAN' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Soft_Lock_Field_Pattern Pattern
		from dual union all 
/*		select 'Soft Delete Field' display_value, 'SOFT_DELETE_COLUMN_PATTERN' return_Value,
				'BOOLEAN' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Soft_Delete_Column_Pattern Pattern
		from dual union all 
		select 'Flip State Field' display_value, 'FLIP_STATE_COLUMN_PATTERN' return_Value,
				'BOOLEAN' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Flip_State_Column_Pattern Pattern
		from dual union all */
		select 'Active LOV Entry' display_value, 'ACTIVE_LOV_FIELDS_PATTERN' return_Value,
				'BOOLEAN' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Active_Lov_Fields_Pattern Pattern
		from dual union all ------------------------------------------------------------------
		select 'Html Field' display_value, 'HTML_FIELDS_PATTERN' return_Value,
				'CLOB' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Html_Fields_Pattern Pattern
		from dual union all ------------------------------------------------------------------
		select 'File Name' display_value, 'FILE_NAME_COLUMN_PATTERN' return_Value,
				'VARCHAR2' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_File_Name_Column_Pattern Pattern
		from dual union all 
		select 'File Mime Type' display_value, 'MIME_TYPE_COLUMN_PATTERN' return_Value,
				'VARCHAR2' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_Mime_Type_Column_Pattern Pattern
		from dual union all 
		select 'File Created Date' display_value, 'FILE_CREATED_COLUMN_PATTERN' return_Value,
				'DATE' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_File_Created_Col_Pattern Pattern
		from dual union all 
		select 'File Content' display_value, 'FILE_CONTENT_COLUMN_PATTERN' return_Value,
				'BLOB' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_File_Content_Col_Pattern Pattern
		from dual union all 
/*		select 'Thumbnail Image' display_value, 'THUMBNAIL_COLUMN_PATTERN' return_Value,
				'BLOB' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_Thumbnail_Column_Pattern Pattern
		from dual union all */
		select 'Text Index Format' display_value, 'INDEX_FORMAT_FIELD_PATTERN' return_Value,
				'VARCHAR2' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_Index_Format_Field_Pattern Pattern
		from dual union all 
		select 'File Folder Reference' display_value, 'FILE_FOLDER_FIELD_PATTERN' return_Value,
				'REFERENCE' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_File_Folder_Field_Pattern Pattern
		from dual union all ------------------------------------------------------------------
		select 'Parent Folder' display_value, 'FOLDER_PARENT_FIELD_PATTERN' return_Value,
				'REFERENCE' data_type, 'N' rule_has_blob,
				data_browser_pattern.Get_Folder_Parent_Fld_Pattern Pattern
		from dual union all 
		select 'Folder Name Field' display_value, 'FOLDER_NAME_FIELD_PATTERN' return_Value,
				'VARCHAR2' data_type, 'N' rule_has_blob,
				data_browser_pattern.Get_Folder_Name_Field_Pattern Pattern
/*		from dual union all 
		select 'File Privilege' display_value, 'FILE_PRIVILEGE_FLD_PATTERN' return_Value,
				'VARCHAR2' data_type, 'Y' rule_has_blob,
				data_browser_pattern.Get_File_Privilege_Fld_Pattern Pattern*/
		from dual union all ------------------------------------------------------------------
		select 'Yes/No Field' display_value, 'YES_NO_COLUMNS_PATTERN' return_Value,
				'VARCHAR2' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Yes_No_Columns_Pattern Pattern
		from dual union all 
		select 'Yes/No Field' display_value, 'YES_NO_COLUMNS_PATTERN' return_Value,
				'NUMBER' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Yes_No_Columns_Pattern Pattern
		from dual union all 
		select 'Yes/No Field' display_value, 'YES_NO_COLUMNS_PATTERN' return_Value,
				'BOOLEAN' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Yes_No_Columns_Pattern Pattern
		from dual union all 
		select 'Upper-case Column Header' display_value, 'UPPER_NAMES_COLUMN_PATTERN' return_Value,
				'%' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Upper_Names_Column_Pattern Pattern
		from dual union all 
		select 'Audit Infos - Date' display_value, 'AUDIT_COLUMN_PATTERN' return_Value,
				'DATE' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Audit_Column_Pattern Pattern
		from dual union all 
		select 'Audit Infos - User' display_value, 'AUDIT_COLUMN_PATTERN' return_Value,
				'VARCHAR2' data_type, '%' rule_has_blob,
				data_browser_pattern.Get_Audit_Column_Pattern Pattern
		from dual
	) b on c.rule_data_type LIKE b.data_type
	and t.table_has_blob LIKE b.rule_has_blob
	-- patterns that occur only once per table
	and (return_Value != 'ROW_VERSION_COLUMN_PATTERN' or c.column_name = nvl(ROW_VERSION_COLUMN_NAME, c.column_name)
		and c.data_type = 'NUMBER' and nvl(c.data_scale,0) = 0)
	and (return_Value != 'ROW_LOCK_COLUMN_PATTERN' or c.column_name = nvl(ROW_LOCKED_COLUMN_NAME, c.column_name))
	and (return_Value != 'SOFT_DELETE_COLUMN_PATTERN' or c.column_name = nvl(SOFT_DELETED_COLUMN_NAME, c.column_name))
	and (return_Value != 'ORDERING_COLUMN_PATTERN' or c.column_name = nvl(ORDERING_COLUMN_NAME, c.column_name)
		and c.data_type = 'NUMBER' and nvl(c.data_scale,0) = 0)
	and (return_Value != 'ACTIVE_LOV_FIELDS_PATTERN' or c.column_name = nvl(ACTIVE_LOV_COLUMN_NAME, c.column_name))
	and (return_Value != 'CALENDAR_START_DATE_PATTERN' or c.column_name = nvl(CALEND_START_DATE_COLUMN_NAME, c.column_name))
	and (return_Value != 'CALENDAR_END_DATE_PATTERN' or c.column_name = nvl(CALENDAR_END_DATE_COLUMN_NAME, c.column_name))
	and (return_Value != 'FILE_NAME_COLUMN_PATTERN' or c.column_name = nvl(FILE_NAME_COLUMN_NAME, c.column_name))
	and (return_Value != 'MIME_TYPE_COLUMN_PATTERN' or c.column_name = nvl(MIME_TYPE_COLUMN_NAME, c.column_name))
	and (return_Value != 'FILE_CREATED_COLUMN_PATTERN' or c.column_name = nvl(FILE_DATE_COLUMN_NAME, c.column_name))
	and (return_Value != 'FILE_CONTENT_COLUMN_PATTERN' or c.column_name = nvl(FILE_CONTENT_COLUMN_NAME, c.column_name))
	and (return_Value != 'FILE_FOLDER_FIELD_PATTERN' or c.column_name = nvl(FILE_FOLDER_COLUMN_NAME, c.column_name))
	and (return_Value != 'FOLDER_NAME_FIELD_PATTERN' or c.column_name = nvl(FOLDER_NAME_COLUMN_NAME, c.column_name))
	and (return_Value != 'FOLDER_PARENT_FIELD_PATTERN' or c.column_name = nvl(FOLDER_PARENT_COLUMN_NAME, c.column_name))
	and (return_Value != 'FILE_PRIVILEGE_FLD_PATTERN' or c.column_name = nvl(FILE_PRIVILEGE_COLUMN_NAME, c.column_name))
	and (return_Value != 'INDEX_FORMAT_FIELD_PATTERN' or c.column_name = nvl(INDEX_FORMAT_COLUMN_NAME, c.column_name))
	and (return_Value != 'AUDIT_COLUMN_PATTERN' 
		or (b.data_type = 'DATE' and c.column_name = nvl(AUDIT_DATE_COLUMN_NAME, c.column_name) ) 
		or (b.data_type = 'VARCHAR2' and c.column_name = nvl(AUDIT_USER_COLUMN_NAME, c.column_name) ) 
	)
);


CREATE OR REPLACE VIEW VDATA_BROWSER_TABLE_RULES
AS 
SELECT S.TABLE_NAME, 
        S.SEARCH_KEY_COLS COLUMN_NAME, -- when S.SEARCH_KEY_COLS IS NOT NULL then 'table is updatable' end
		NULL R_VIEW_NAME,
        S.UNIQUE_COLUMN_NAMES COLUMN_LOOKUP_LIST, -- when S.UNIQUE_COLUMN_NAMES IS NOT NULL then 'table us mergeable'
        null DEFAULTS_MISSING,
        S.HAS_SCALAR_KEY, 	-- when S.HAS_SCALAR_KEY = 'YES' then 'table is insertable' end
		'A' TABLE_ALIAS,
		S.COLUMN_CNT,
		S.HAS_NULLABLE, 
		S.HAS_SIMPLE_UNIQUE, 
        case when S.U_CONSTRAINT_NAME IS NOT NULL then 1 else 0 end HAS_U_CONSTRAINT,
		'P' CHECK_CONSTRAINT_TYPE,
		0 POSITION
FROM MVDATA_BROWSER_DESCRIPTIONS S
UNION ALL 
SELECT T.TABLE_NAME, 
        T.COLUMN_NAME,
    	T.R_VIEW_NAME, 
        LISTAGG(INITCAP(T.R_COLUMN_NAME), ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID) COLUMN_LOOKUP_LIST,
    	D.DEFAULTS_MISSING, 
    	D.HAS_SCALAR_KEY,
    	T.TABLE_ALIAS, 
        T.COLUMN_CNT, 
        T.HAS_NULLABLE,  -- when NULLABLE no relieable unique search 
        T.HAS_SIMPLE_UNIQUE, 
        case when MAX(T.U_CONSTRAINT_NAME) IS NOT NULL then 1 else 0 end HAS_U_CONSTRAINT,
		'R' CHECK_CONSTRAINT_TYPE,
        -- D.DEFAULTS_MISSING + case when MAX(T.U_CONSTRAINT_NAME) IS NOT NULL then 0 else 1 end DEFAULTS_MISSING2,
        T.COLUMN_ID POSITION
	FROM
	(
		-- 2. level foreign keys
		SELECT 	VIEW_NAME, TABLE_NAME, SEARCH_KEY_COLS, SHORT_NAME, COLUMN_NAME, 
			S_VIEW_NAME, S_REF, D_VIEW_NAME, D_REF, 
			IS_FILE_FOLDER_REF, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME, 
			FILTER_KEY_COLUMN, PARENT_KEY_COLUMN, 
			R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, COLUMN_ID, NULLABLE, 
			R_COLUMN_ID, R_COLUMN_NAME, POSITION, R_NULLABLE, R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, 
			R_CHAR_LENGTH, TABLE_ALIAS, IMP_COLUMN_NAME, JOIN_CLAUSE, 
			HAS_NULLABLE, HAS_SIMPLE_UNIQUE, 
			HAS_FOREIGN_KEY, U_CONSTRAINT_NAME, U_MEMBERS, POSITION2,	
			COUNT(DISTINCT R_COLUMN_NAME) OVER (PARTITION BY TABLE_NAME, COLUMN_NAME) COLUMN_CNT -- columns used for lookup
		FROM TABLE(data_browser_select.FN_Pipe_table_imp_fk2 (null, 'NO'))
		UNION
		-- 1. level foreign keys
		SELECT 	VIEW_NAME, TABLE_NAME, SEARCH_KEY_COLS, SHORT_NAME, COLUMN_NAME, 
			S_VIEW_NAME, S_REF, D_VIEW_NAME, D_REF, 
			IS_FILE_FOLDER_REF, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME, 
			FILTER_KEY_COLUMN, PARENT_KEY_COLUMN, 
			R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, COLUMN_ID, NULLABLE, 
			R_COLUMN_ID, R_COLUMN_NAME, POSITION, R_NULLABLE, R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, 
			R_CHAR_LENGTH, TABLE_ALIAS, IMP_COLUMN_NAME, JOIN_CLAUSE, 
			HAS_NULLABLE, HAS_SIMPLE_UNIQUE, 
			HAS_FOREIGN_KEY, U_CONSTRAINT_NAME, U_MEMBERS, POSITION2,		
			COUNT(DISTINCT R_COLUMN_NAME) OVER (PARTITION BY TABLE_NAME, COLUMN_NAME) COLUMN_CNT -- columns used for lookup
		FROM TABLE(data_browser_select.FN_Pipe_table_imp_fk1 (null))	
	) T
    JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = T.VIEW_NAME
    JOIN ( -- count of missing defaults for foreign key table
        SELECT S.VIEW_NAME, S.HAS_SCALAR_KEY, COUNT(DISTINCT C.COLUMN_ID) DEFAULTS_MISSING
        FROM MVDATA_BROWSER_VIEWS S -- foreign key table
        LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C ON S.TABLE_NAME = C.TABLE_NAME
        AND C.NULLABLE = 'N' AND C.HAS_DEFAULT = 'N'
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
        GROUP BY S.VIEW_NAME, S.HAS_SCALAR_KEY
    ) D ON D.VIEW_NAME = T.R_VIEW_NAME
    WHERE R_COLUMN_ID IS NOT NULL
    GROUP BY T.TABLE_NAME, T.VIEW_NAME,
    	D.DEFAULTS_MISSING, D.HAS_SCALAR_KEY, T.TABLE_ALIAS, T.R_PRIMARY_KEY_COLS, T.COLUMN_NAME,
    	T.R_VIEW_NAME, T.COLUMN_ID, S.SHORT_NAME,
        T.COLUMN_CNT, T.HAS_NULLABLE, T.HAS_SIMPLE_UNIQUE, T.NULLABLE, T.D_VIEW_NAME, T.D_REF, T.POSITION2
;
