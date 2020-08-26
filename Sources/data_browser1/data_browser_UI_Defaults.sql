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

declare
    v_apex_schema VARCHAR2(100);

    procedure Run_Stat( p_Stat VARCHAR2) is
    begin
        EXECUTE IMMEDIATE p_Stat;
    exception
      when others then
        DBMS_OUTPUT.PUT_LINE(p_Stat || ';');
        raise;
    end;
begin
$IF data_browser_specs.g_update_apex_tables $THEN
	select table_owner 
	INTO v_apex_schema
	from all_synonyms where synonym_name = 'APEX'
	and owner = 'PUBLIC';
	-- GRANT SELECT ON WWV_FLOW_HNT_TABLE_INFO, WWV_FLOW_HNT_COLUMN_INFO, WWV_FLOW_HNT_LOV_DATA is required.
    Run_Stat('CREATE OR REPLACE VIEW USER_UI_DEFAULTS_LOV_DATA
        (SCHEMA, TABLE_NAME, COLUMN_NAME, LOV_DISP_SEQUENCE, LOV_DISP_VALUE, LOV_RETURN_VALUE, LAST_UPDATED_BY, LAST_UPDATED_ON)
     AS
      select t.schema,
           t.table_name,
           c.column_name,
           l.lov_disp_sequence,
           l.lov_disp_value,
           l.lov_return_value,
           l.last_updated_by,
           l.last_updated_on
      from ' || v_apex_schema || '.wwv_flow_hnt_lov_data l,
           ' || v_apex_schema || '.wwv_flow_hnt_column_info c,
           ' || v_apex_schema || '.wwv_flow_hnt_table_info t
     where l.column_id = c.column_id
       and c.table_id  = t.table_id
       and t.schema = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'')
    ');
    Run_Stat('CREATE OR REPLACE TRIGGER TGR_USER_UI_DEFAULTS_LOV_DATA
        instead of insert or update or delete on USER_UI_DEFAULTS_LOV_DATA
    for each row
    declare
        l_column_id ' || v_apex_schema || '.wwv_flow_hnt_lov_data.column_id%TYPE;
    begin
        if deleting then
			SELECT c.column_id
			INTO l_column_id
			FROM ' || v_apex_schema || '.wwv_flow_hnt_column_info c,
				 ' || v_apex_schema || '.wwv_flow_hnt_table_info t
			WHERE c.table_id  = t.table_id
			AND t.schema = COALESCE(:old.SCHEMA, SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA''))
			AND t.table_name = :old.TABLE_NAME
			AND c.column_name = :old.COLUMN_NAME;

            delete from ' || v_apex_schema || '.wwv_flow_hnt_lov_data
            where column_id = l_column_id
            and lov_disp_sequence = :old.LOV_DISP_SEQUENCE;
		else
			SELECT c.column_id
			INTO l_column_id
			FROM ' || v_apex_schema || '.wwv_flow_hnt_column_info c,
				 ' || v_apex_schema || '.wwv_flow_hnt_table_info t
			WHERE c.table_id  = t.table_id
			AND t.schema = COALESCE(:new.SCHEMA, SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA''))
			AND t.table_name = :new.TABLE_NAME
			AND c.column_name = :new.COLUMN_NAME;
		end if;
        if inserting then
            merge into ' || v_apex_schema || '.wwv_flow_hnt_lov_data D
            using (select l_column_id COLUMN_ID,
                    :new.LOV_DISP_SEQUENCE LOV_DISP_SEQUENCE,
                    :new.LOV_DISP_VALUE LOV_DISP_VALUE,
                    :new.LOV_RETURN_VALUE LOV_RETURN_VALUE
                from dual) S
            on (D.COLUMN_ID = S.COLUMN_ID and D.LOV_DISP_SEQUENCE = S.LOV_DISP_SEQUENCE)
            when matched then
                update set D.LOV_DISP_VALUE = S.LOV_DISP_VALUE,
                        D.LOV_RETURN_VALUE = S.LOV_RETURN_VALUE
            when not matched then
                insert (D.COLUMN_ID, D.LOV_DISP_SEQUENCE, D.LOV_DISP_VALUE, D.LOV_RETURN_VALUE)
                values (S.COLUMN_ID, S.LOV_DISP_SEQUENCE, S.LOV_DISP_VALUE, S.LOV_RETURN_VALUE)
            ;
        elsif updating then
            update ' || v_apex_schema || '.wwv_flow_hnt_lov_data
            set lov_disp_value = :new.LOV_DISP_VALUE,
                lov_return_value = :new.LOV_RETURN_VALUE
            where column_id = l_column_id
            and lov_disp_sequence = :new.LOV_DISP_SEQUENCE;
        end if;
    end TGR_USER_UI_DEFAULTS_LOV_DATA;
    ');
    Run_Stat('CREATE OR REPLACE VIEW USER_UI_DEFAULTS_COLUMNS
    AS
    select t.schema,
        t.table_name,
        c.column_name,
        c.display_in_form, -- Y/N
        c.display_as_form, -- NATIVE_SELECT_LIST,NATIVE_POPUP_LOV
        c.display_as_tab_form, -- POPUP,TEXT_FROM_LOV
        c.display_in_report, -- Y/N
        c.display_as_report, -- ESCAPE_SC
        c.form_attribute_01, -- NOT_ENTERABLE
        c.form_attribute_02, -- FIRST_ROWSET
        c.form_attribute_03,
        c.lov_query
    from ' || v_apex_schema || '.wwv_flow_hnt_column_info c,
        ' || v_apex_schema || '.wwv_flow_hnt_table_info t
    where c.table_id = t.table_id
    and t.schema = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'')
    ');
    Run_Stat('CREATE OR REPLACE TRIGGER TGR_USER_UI_DEFAULTS_COLUMNS
        instead of update on USER_UI_DEFAULTS_COLUMNS
    for each row
    declare
        l_column_id ' || v_apex_schema || '.wwv_flow_hnt_lov_data.column_id%TYPE;
    begin
        SELECT c.column_id
        INTO l_column_id
        FROM ' || v_apex_schema || '.wwv_flow_hnt_column_info c,
             ' || v_apex_schema || '.wwv_flow_hnt_table_info t
        WHERE c.table_id  = t.table_id
        AND t.schema = COALESCE(:new.SCHEMA, SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA''))
        AND t.table_name = :new.TABLE_NAME
        AND c.column_name = :new.COLUMN_NAME;

        update ' || v_apex_schema || '.wwv_flow_hnt_column_info D
            set D.lov_query = :new.lov_query,
            	D.display_in_form = :new.display_in_form,
                D.display_as_form = :new.display_as_form,
                D.display_as_tab_form = :new.display_as_tab_form,
                D.display_as_report = :new.display_as_report,
                D.form_attribute_01 = :new.form_attribute_01,
                D.form_attribute_02 = :new.form_attribute_02,
                D.form_attribute_03 = :new.form_attribute_03
        where D.COLUMN_ID = l_column_id;
    end;
    ');
$ELSE 
	null;
$END 
end;
/

CREATE OR REPLACE PACKAGE BODY data_browser_UI_Defaults
IS

	PROCEDURE UI_Defaults_update_table (
		p_Table_name IN VARCHAR2,
		p_Workspace_Name VARCHAR2
	)
	IS
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);

        CURSOR form_view_cur
        IS
			SELECT DISTINCT
				T.TABLE_OWNER,
				T.TABLE_NAME,
				R_COLUMN_NAME COLUMN_NAME,
				COLUMN_HEADER LABEL,
				case when HAS_HELP_TEXT = 'Y' then
					data_browser_edit.Get_Form_Field_Help_Text(
						p_Table_name => T.VIEW_NAME,
						p_Column_Name => REF_COLUMN_NAME,
						p_View_Mode => 'FORM_VIEW',
						p_Show_Statistics => 'NO'
					)
				end HELP_TEXT,
				case when IS_AUDIT_COLUMN = 'Y'
					then 'AUDIT_INFO' else 'FORM_FIELDS'
				end GROUP_NAME,
				FORMAT_MASK,
				case when SUBSTR(DATA_DEFAULT, 1, 1) = ''''
                    then SUBSTR(DATA_DEFAULT, 2, LENGTH(DATA_DEFAULT)-2)
                when SUBSTR(DATA_DEFAULT, 1, 1) BETWEEN '0' and '9'
                    then DATA_DEFAULT
				when COLUMN_EXPR_TYPE = 'NUMBER' AND FORMAT_MASK IS NOT NULL
                    then LTRIM(TO_CHAR(0, FORMAT_MASK))
				when COLUMN_EXPR_TYPE = 'NUMBER'
                    then '0'
				end DEFAULT_VALUE,
				case when COLUMN_EXPR_TYPE = 'NUMBER'
					then 'NUMBER'
					when COLUMN_EXPR_TYPE = 'DATE_POPUP'
					then 'DATE'
					else 'TEXT'
				end FORM_DATA_TYPE,
				FIELD_LENGTH MAX_WIDTH,
				LEAST(GREATEST(FIELD_LENGTH, data_browser_conf.Get_Minimum_Field_Width),
						data_browser_conf.Get_Maximum_Field_Width) FORM_DISPLAY_WIDTH,
				case when COLUMN_EXPR_TYPE = 'TEXTAREA'
					then 3 else 1
				end FORM_DISPLAY_HEIGHT,
				UPPER(COLUMN_ALIGN) REPORT_COL_ALIGNMENT,
				case when COLUMN_EXPR_TYPE = 'HIDDEN'
					then 'N' else 'Y'
				end DISPLAY_IN_FORM,
				COLUMN_ID DISPLAY_SEQ_FORM,
				REQUIRED,
				DISPLAY_IN_REPORT,
				IS_PRIMARY_KEY,
				CHECK_UNIQUE, LOV_QUERY, CHECK_CONDITION, COLUMN_EXPR_TYPE,
				IS_CHAR_YES_NO_COLUMN, IS_NUMBER_YES_NO_COLUMN, IS_REFERENCE
			FROM MVDATA_BROWSER_VIEWS T, TABLE ( data_browser_edit.Get_Form_Edit_Cursor (
				p_Table_name => T.VIEW_NAME,
				p_View_Mode => 'FORM_VIEW',
                p_Report_Mode => 'ALL',
				p_Data_Columns_Only => 'YES'
			))
			WHERE T.VIEW_NAME = v_Table_Name
			AND R_COLUMN_NAME IS NOT NULL
			AND TABLE_ALIAS = 'A';
		TYPE form_view_Tab IS TABLE OF form_view_cur%ROWTYPE;
		v_out_tab 	form_view_Tab;
		v_workspace_id 	NUMBER;
	BEGIN
		v_workspace_id := apex_util.find_security_group_id (p_workspace => p_Workspace_Name);
		apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_UI_Defaults.UI_Defaults_update_table (p_Workspace_Name => %s, p_Table_name => %s)',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Workspace_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Table_name)
			);
		$END

$IF data_browser_specs.g_update_apex_tables $THEN
		DELETE FROM USER_UI_DEFAULTS_LOV_DATA D
		WHERE EXISTS (
			SELECT 1
			FROM VUSER_TABLES_CHECK_IN_LIST S
			WHERE S.TABLE_NAME = D.TABLE_NAME
			AND S.COLUMN_NAME = D.COLUMN_NAME
		)
		AND D.TABLE_NAME = v_Table_Name
		AND D.SCHEMA = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') ;
$END
		OPEN form_view_cur;
		FETCH form_view_cur BULK COLLECT INTO v_out_tab;
		CLOSE form_view_cur;
		FOR ind IN 1 .. v_out_tab.COUNT
		LOOP
			DBMS_OUTPUT.PUT_LINE(ind || '.: ' || v_Table_Name || '.' ||  v_out_tab(ind).COLUMN_NAME);
			
			if ind = 1 then 
				$IF data_browser_conf.g_debug $THEN
					apex_debug.info(
						p_message => 'apex_ui_default_update.synch_table (p_table_name => %s)',
						p0 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Table_name)
					);
				$END
				apex_ui_default_update.synch_table (
					p_table_name => v_Table_Name
				);
				apex_ui_default_update.upd_table (
					p_table_name => v_Table_Name,
					p_form_region_title => 'Edit ' || data_browser_conf.Table_Name_To_Header(p_Table_name),
					p_report_region_title => data_browser_conf.Table_Name_To_Header(p_Table_name)
				);
			end if;

			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'apex_ui_default_update.upd_column (Column_Name => %s) – Column %s',
					p0 => DBMS_ASSERT.ENQUOTE_LITERAL(v_out_tab(ind).COLUMN_NAME)
				);
			$END
			apex_ui_default_update.upd_column (
  				p_table_name 		=> v_Table_Name,
  				p_column_name 		=> v_out_tab(ind).COLUMN_NAME,
  				-- p_group_id			=> v_out_tab(ind).GROUP_NAME,
  				p_label 			=> v_out_tab(ind).LABEL,
  				p_help_text			=> v_out_tab(ind).HELP_TEXT,
  				p_display_in_form 	=> v_out_tab(ind).DISPLAY_IN_FORM,
  				p_display_seq_form 	=> v_out_tab(ind).DISPLAY_SEQ_FORM,
  				p_mask_form 		=> v_out_tab(ind).FORMAT_MASK,
  				p_default_value 	=> v_out_tab(ind).DEFAULT_VALUE,
  				p_required 			=> v_out_tab(ind).REQUIRED,
  				p_display_width 	=> v_out_tab(ind).FORM_DISPLAY_WIDTH,
  				p_height 			=> v_out_tab(ind).FORM_DISPLAY_HEIGHT,
  				p_max_width 		=> v_out_tab(ind).MAX_WIDTH,
  				p_display_in_report => v_out_tab(ind).DISPLAY_IN_REPORT,
  				p_display_seq_report=> v_out_tab(ind).DISPLAY_SEQ_FORM,
  				p_mask_report 		=> v_out_tab(ind).FORMAT_MASK,
  				p_alignment 		=> SUBSTR(v_out_tab(ind).REPORT_COL_ALIGNMENT, 1, 1)
  			);
$IF data_browser_specs.g_update_apex_tables $THEN
  			if v_out_tab(ind).COLUMN_EXPR_TYPE = 'POPUPKEY_FROM_LOV' then
				update USER_UI_DEFAULTS_COLUMNS
				set lov_query = v_out_tab(ind).LOV_QUERY,
					display_as_form = 'NATIVE_POPUP_LOV',
					display_as_tab_form = 'POPUP',
					display_as_report = 'ESCAPE_SC',
					form_attribute_01 = 'NOT_ENTERABLE',
					form_attribute_02 = 'FIRST_ROWSET',
					form_attribute_03 = NULL
				where table_name = v_Table_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
  			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'SELECT_LIST_FROM_QUERY'  then
				update USER_UI_DEFAULTS_COLUMNS
				set lov_query = v_out_tab(ind).LOV_QUERY,
					display_as_form = 'NATIVE_SELECT_LIST',
					display_as_tab_form = 'SELECT_LIST_FROM_LOV',
					display_as_report = 'ESCAPE_SC',
					form_attribute_01 = 'NONE',
					form_attribute_02 = 'N',
					form_attribute_03 = NULL
				where table_name = v_Table_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
  			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'SELECT_LIST'  then
				update USER_UI_DEFAULTS_COLUMNS
				set lov_query = NULL,
					display_as_form = 'NATIVE_SELECT_LIST',
					display_as_tab_form = 'SELECT_LIST_FROM_LOV',
					display_as_report = 'ESCAPE_SC',
					form_attribute_01 = 'NONE',
					form_attribute_02 = 'N',
					form_attribute_03 = NULL
				where table_name = v_Table_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
				-- special handling for Yes/No columns
				if (v_out_tab(ind).IS_CHAR_YES_NO_COLUMN = 'Y'
				or v_out_tab(ind).IS_NUMBER_YES_NO_COLUMN = 'Y') then
					INSERT INTO USER_UI_DEFAULTS_LOV_DATA (SCHEMA, TABLE_NAME, COLUMN_NAME, LOV_DISP_SEQUENCE, LOV_DISP_VALUE, LOV_RETURN_VALUE)
					select SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') SCHEMA_NAME,
						v_Table_Name TABLE_NAME,
						v_out_tab(ind).COLUMN_NAME COLUMN_NAME,
						DISP_SEQUENCE,
						SUBSTR(P.COLUMN_VALUE, 1, OFFSET-1) DISPLAY_VALUE,
						SUBSTR(P.COLUMN_VALUE, OFFSET+1) COLUMN_VALUE
					from (
						SELECT P.COLUMN_VALUE, INSTR(P.COLUMN_VALUE, ';') OFFSET, ROWNUM DISP_SEQUENCE
						FROM TABLE( data_browser_conf.in_list(data_browser_conf.Get_Yes_No_Type_LOV(
							case when v_out_tab(ind).IS_NUMBER_YES_NO_COLUMN = 'Y' then 'NUMBER' else 'CHAR' end), ',') ) P
					) P;
				else
					INSERT INTO USER_UI_DEFAULTS_LOV_DATA (SCHEMA, TABLE_NAME, COLUMN_NAME, LOV_DISP_SEQUENCE, LOV_DISP_VALUE, LOV_RETURN_VALUE)
					SELECT  SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') SCHEMA_NAME,
						TABLE_NAME, COLUMN_NAME, DISP_SEQUENCE, DISPLAY_VALUE, COLUMN_VALUE
					FROM VUSER_TABLES_CHECK_IN_LIST
					WHERE TABLE_NAME = v_Table_Name
					AND COLUMN_NAME = v_out_tab(ind).COLUMN_NAME;
				end if;
			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'DISPLAY_ONLY' then
				update USER_UI_DEFAULTS_COLUMNS
				set lov_query = v_out_tab(ind).LOV_QUERY,
					display_as_form = 'NATIVE_DISPLAY_ONLY',
					display_as_tab_form = 'ESCAPE_SC',
					display_as_report = 'ESCAPE_SC',
					form_attribute_01 = 'Y',
					form_attribute_02 = 'VALUE',
					form_attribute_03 = NULL
				where table_name = v_Table_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
  			end if;
$END
		END LOOP;
		COMMIT;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	    if form_view_cur%ISOPEN then
			CLOSE form_view_cur;
		end if;
		raise;
$END 
	END UI_Defaults_update_table;

	PROCEDURE UI_Defaults_update_all_tables (
		p_Workspace_Name VARCHAR2
	)
	IS
	BEGIN
		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME
			FROM MVDATA_BROWSER_VIEWS
			ORDER BY TABLE_NAME
		) loop
			data_browser_UI_Defaults.UI_Defaults_update_table (
				p_Table_name => c_cur.TABLE_NAME,
				p_Workspace_Name => p_Workspace_Name
			);
		end loop;
	END UI_Defaults_update_all_tables;

	PROCEDURE UI_Defaults_delete_all_tables (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	IS
	Begin 
		for t_cur in (
			select SCHEMA,TABLE_NAME,FORM_REGION_TITLE
			  from APEX_UI_DEFAULTS_TABLES
			 where SCHEMA = p_Schema_Name
		 ) loop 
			apex_ui_default_update.del_table (t_cur.TABLE_NAME);
		 end loop;
	END UI_Defaults_delete_all_tables;

END data_browser_UI_Defaults;
/
show errors

/*
set serveroutput on size unlimited
exec data_browser_UI_Defaults.UI_Defaults_update_all_tables('STRACK_DEV');
*/