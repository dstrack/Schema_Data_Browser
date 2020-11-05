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
        c.form_attribute_01, -- POPUP
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
	CURSOR form_view_cur (v_Table_Name VARCHAR2, v_View_Mode VARCHAR2)
	IS
		SELECT DISTINCT
			T.TABLE_OWNER,
			T.TABLE_NAME,
			C.COLUMN_NAME,
			C.COLUMN_HEADER LABEL,
			/*data_browser_edit.Get_Form_Field_Help_Text(
				p_Table_name => T.VIEW_NAME,
				p_Column_Name => REF_COLUMN_NAME,
				p_View_Mode => v_View_Mode,
				p_Show_Statistics => 'NO'
			)*/
			C.COMMENTS HELP_TEXT,
			case when IS_AUDIT_COLUMN = 'Y'
				then 'AUDIT_INFO' else 'FORM_FIELDS'
			end GROUP_NAME,
			FORMAT_MASK,
			case when SUBSTR(DATA_DEFAULT, 1, 1) = ''''
				then SUBSTR(DATA_DEFAULT, 2, LENGTH(DATA_DEFAULT)-2)
			when SUBSTR(DATA_DEFAULT, 1, 1) BETWEEN '0' and '9'
				then DATA_DEFAULT
			when COLUMN_EXPR_TYPE IN ('NUMBER', 'FLOAT') AND FORMAT_MASK IS NOT NULL
				then LTRIM(TO_CHAR(0, FORMAT_MASK))
			when COLUMN_EXPR_TYPE IN ('NUMBER', 'FLOAT')
				then '0'
			end DEFAULT_VALUE,
			case when COLUMN_EXPR_TYPE IN ('NUMBER', 'FLOAT')
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
			ROWNUM + 1 DISPLAY_SEQ_FORM,
			REQUIRED,
			DISPLAY_IN_REPORT,
			IS_PRIMARY_KEY,
			CHECK_UNIQUE, LOV_QUERY, COLUMN_EXPR_TYPE,
			IS_CHAR_YES_NO_COLUMN, IS_NUMBER_YES_NO_COLUMN, 
			case when IS_CHAR_YES_NO_COLUMN = 'Y' then 'CHAR'
				when IS_NUMBER_YES_NO_COLUMN = 'Y' then 'NUMBER' 
			end YES_NO_TYPE,
			IS_REFERENCE,
			FILE_NAME_COLUMN_NAME,
			MIME_TYPE_COLUMN_NAME,
			FILE_DATE_COLUMN_NAME
		FROM MVDATA_BROWSER_VIEWS T, TABLE ( data_browser_edit.Get_Form_Edit_Cursor (
			p_Table_name => T.VIEW_NAME,
			p_Unique_Key_Column => T.SEARCH_KEY_COLS,
			p_View_Mode => v_View_Mode,
			p_Report_Mode => 'ALL',
			p_Data_Columns_Only => 'YES'
		)) C
		WHERE T.VIEW_NAME = v_Table_Name
		AND C.COLUMN_EXPR_TYPE != 'HIDDEN'
		AND C.TABLE_ALIAS IS NOT NULL;
	TYPE form_view_Tab IS TABLE OF form_view_cur%ROWTYPE;

	PROCEDURE UI_Defaults_update_table (
		p_Table_name IN VARCHAR2,
		p_View_Name IN VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW',	-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	IS
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_View_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := NVL(p_View_Name, v_Table_Name);
		v_out_tab 		form_view_Tab;
		v_workspace_id 	NUMBER;
	BEGIN
		v_workspace_id := apex_util.find_security_group_id (p_workspace => p_Workspace_Name);
		apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_UI_Defaults.UI_Defaults_update_table (p_Table_name => %s, p_View_Mode => %s, p_Workspace_Name => %s, p_Schema_Name => %s, )',
				p0 => dbms_assert.enquote_literal(v_Table_name),
				p1 => dbms_assert.enquote_literal(p_View_Mode),
				p2 => dbms_assert.enquote_literal(p_Workspace_Name),
				p3 => dbms_assert.enquote_literal(p_Schema_Name)
			);
		$END

$IF data_browser_specs.g_update_apex_tables $THEN
		DELETE FROM USER_UI_DEFAULTS_LOV_DATA D
		WHERE EXISTS (
			SELECT 1
			FROM TABLE( data_browser_conf.Table_Column_In_List_Cursor ) S
			WHERE S.TABLE_NAME = D.TABLE_NAME
			AND S.COLUMN_NAME = D.COLUMN_NAME
		)
		AND D.TABLE_NAME = v_View_Name
		AND D.SCHEMA = p_Schema_Name ;
$END
		OPEN form_view_cur(v_Table_Name, p_View_Mode);
		FETCH form_view_cur BULK COLLECT INTO v_out_tab;
		CLOSE form_view_cur;
		FOR ind IN 1 .. v_out_tab.COUNT
		LOOP
			$IF data_browser_conf.g_debug $THEN
				DBMS_OUTPUT.PUT_LINE(ind || '.: ' || v_View_Name || '.' ||  v_out_tab(ind).COLUMN_NAME);
			$END
			
			if ind = 1 then 
				$IF data_browser_conf.g_debug $THEN
					apex_debug.info(
						p_message => 'apex_ui_default_update.synch_table (p_table_name => %s)',
						p0 => dbms_assert.enquote_literal(v_View_Name)
					);
				$END
				apex_ui_default_update.synch_table (
					p_table_name => v_View_Name
				);
				apex_ui_default_update.upd_table (
					p_table_name => v_View_Name,
					p_form_region_title => 'Edit ' || data_browser_conf.Table_Name_To_Header(p_Table_name),
					p_report_region_title => data_browser_conf.Table_Name_To_Header(p_Table_name)
				);
			end if;

			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'apex_ui_default_update.upd_column (Column_Name => %s) – Column %s',
					p0 => dbms_assert.enquote_literal(v_out_tab(ind).COLUMN_NAME)
				);
			$END
			apex_ui_default_update.upd_column (
  				p_table_name 		=> v_View_Name,
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
				where table_name = v_View_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
  			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'POPUP_FROM_LOV' then
				update USER_UI_DEFAULTS_COLUMNS
				set lov_query = v_out_tab(ind).LOV_QUERY,
					display_as_form = 'NATIVE_POPUP_LOV',
					display_as_tab_form = 'POPUP',
					display_as_report = 'ESCAPE_SC',
					form_attribute_01 = 'ENTERABLE',
					form_attribute_02 = 'FIRST_ROWSET',
					form_attribute_03 = NULL
				where table_name = v_View_Name
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
				where table_name = v_View_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
  			elsif v_out_tab(ind).COLUMN_EXPR_TYPE IN ('SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER')  then
				update USER_UI_DEFAULTS_COLUMNS
				set lov_query = NULL,
					display_as_form = 'NATIVE_SELECT_LIST',
					display_as_tab_form = 'SELECT_LIST_FROM_LOV',
					display_as_report = 'ESCAPE_SC',
					form_attribute_01 = 'NONE',
					form_attribute_02 = 'N',
					form_attribute_03 = NULL
				where table_name = v_View_Name
				and column_name = v_out_tab(ind).COLUMN_NAME;
				-- special handling for Yes/No columns
				if v_out_tab(ind).YES_NO_TYPE IS NOT NULL then
					INSERT INTO USER_UI_DEFAULTS_LOV_DATA (SCHEMA, TABLE_NAME, COLUMN_NAME, LOV_DISP_SEQUENCE, LOV_DISP_VALUE, LOV_RETURN_VALUE)
					select p_Schema_Name SCHEMA_NAME,
						v_View_Name TABLE_NAME,
						v_out_tab(ind).COLUMN_NAME COLUMN_NAME,
						DISP_SEQUENCE,
						SUBSTR(P.COLUMN_VALUE, 1, OFFSET-1) DISPLAY_VALUE,
						SUBSTR(P.COLUMN_VALUE, OFFSET+1) COLUMN_VALUE
					from (
						SELECT P.COLUMN_VALUE, INSTR(P.COLUMN_VALUE, ';') OFFSET, ROWNUM DISP_SEQUENCE
						FROM TABLE( data_browser_conf.in_list(
							data_browser_conf.Get_Yes_No_Type_LOV(v_out_tab(ind).YES_NO_TYPE), ',') ) P
					) P;
				else
					INSERT INTO USER_UI_DEFAULTS_LOV_DATA (SCHEMA, TABLE_NAME, COLUMN_NAME, LOV_DISP_SEQUENCE, LOV_DISP_VALUE, LOV_RETURN_VALUE)
					SELECT  p_Schema_Name SCHEMA_NAME,
						v_View_Name TABLE_NAME, COLUMN_NAME, DISP_SEQUENCE, DISPLAY_VALUE, LIST_VALUE
					FROM TABLE( data_browser_conf.Table_Column_In_List_Cursor(
						p_Table_Name => v_Table_Name,
						p_Column_Name => v_out_tab(ind).COLUMN_NAME
					));
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
				where table_name = v_View_Name
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
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	IS
	BEGIN
		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME
			FROM MVDATA_BROWSER_VIEWS
			ORDER BY TABLE_NAME
		) loop
			data_browser_UI_Defaults.UI_Defaults_update_table (
				p_Table_name => c_cur.VIEW_NAME,
				p_View_Mode => 'FORM_VIEW',
				p_Workspace_Name => p_Workspace_Name,
				p_Schema_Name => p_Schema_Name
			);
		end loop;
		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME, IMP_VIEW_NAME
			FROM (
				SELECT TABLE_NAME, VIEW_NAME,
					'V' || SHORT_NAME || '_IMP' IMP_VIEW_NAME
				FROM MVDATA_BROWSER_VIEWS
			) A 
			WHERE EXISTS (
				SELECT 1
				FROM SYS.USER_VIEWS B 
				WHERE B.VIEW_NAME = A.IMP_VIEW_NAME
			)
			ORDER BY TABLE_NAME
		) loop
			data_browser_UI_Defaults.UI_Defaults_update_table (
				p_Table_name => c_cur.VIEW_NAME,
				p_View_Mode => 'IMPORT_VIEW',
				p_View_name => c_cur.IMP_VIEW_NAME,
				p_Workspace_Name => p_Workspace_Name,
				p_Schema_Name => p_Schema_Name
			);
		end loop;
		
	END UI_Defaults_update_all_tables;

	PROCEDURE UI_Defaults_delete_all_tables (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	)
	IS
	Begin 
		for t_cur in (
			select TABLE_NAME
			  from APEX_UI_DEFAULTS_TABLES
			 where SCHEMA = p_Schema_Name
		 ) loop 
			apex_ui_default_update.del_table (t_cur.TABLE_NAME);
		 end loop;
	END UI_Defaults_delete_all_tables;


	FUNCTION UI_Defaults_export_header (
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	) RETURN CLOB
	is
        v_Stat 			CLOB;
		v_workspace_id 	NUMBER;
	begin
		v_workspace_id := apex_util.find_security_group_id (p_workspace => p_Workspace_Name);
		apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		v_Stat := apex_string.format (p_message => 
		q'!set define '^'
		  !set verify off
		  !set serveroutput on size 1000000
		  !set feedback off
		  !WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
		  ! 
		  !prompt  Set Credentials...
		  ! 
		  !begin
		  ! 
		  !  -- Assumes you are running the script connected to sqlplus as the schema associated with the UI defaults or as the product schema.
		  !  wwv_flow_api.set_security_group_id(p_security_group_id=>%s);
		  ! 
		  !end;
		  !/
		  !
		  !begin wwv_flow.g_import_in_progress := true; end;
		  !/
		  !begin 
		  !
		  !select value into wwv_flow_api.g_nls_numeric_chars from nls_session_parameters where parameter='NLS_NUMERIC_CHARACTERS';
		  !
		  !end;
		  !
		  !/
		  !begin execute immediate 'alter session set nls_numeric_characters=''.,''';
		  !
		  !end;
		  !
		  !/
		  !begin wwv_flow.g_browser_language := 'en'; end;
		  !/
		  !prompt  Check Compatibility...
		  ! 
		  !begin
		  ! 
		  !-- This date identifies the minimum version required to install this file.
		  !wwv_flow_api.set_version(p_version_yyyy_mm_dd=>'2019.03.31');
		  ! 
		  !end;
		  !/
		  !
		  !-- SET SCHEMA
		  ! 
		  !begin
		  ! 
		  !   wwv_flow_api.g_id_offset := 0;
		  !   wwv_flow_hint.g_schema   := '%s';
		  !   wwv_flow_hint.check_schema_privs;
		  ! 
		  !end;
		  !/
		  !
		  ! 
		  !--------------------------------------------------------------------
		  !prompt  SCHEMA STRACK_DEV - User Interface Defaults, Table Defaults
		  !--
		  !-- Import using sqlplus as the Oracle user: APEX_190100
		  !-- Exported 14:18 Monday August 31, 2020 by: DIRK
		  !--!' || chr(10),
		  	p0 => v_workspace_id,
			p1 => p_Schema_Name,
			p_max_length => 30000,
			p_prefix => '!'
		);
		return v_Stat;
	end UI_Defaults_export_header;

	FUNCTION UI_Defaults_export_footer 
	RETURN CLOB
	is
        v_Stat 			CLOB;
	begin
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
		v_Stat := apex_string.format (p_message => 
		q'!commit;
		  !begin 
		  !execute immediate 'alter session set nls_numeric_characters='''||wwv_flow_api.g_nls_numeric_chars||'''';
		  !end;
		  !/
		  !set verify on
		  !set feedback on
		  !prompt  ...done!' || chr(10),
			p_max_length => 30000,
			p_prefix => '!'
		);
		return v_Stat;
	end UI_Defaults_export_footer;

	FUNCTION UI_Defaults_export_table (
		p_Table_name IN VARCHAR2,
		p_View_Name IN VARCHAR2 DEFAULT NULL,
		p_View_Mode IN VARCHAR2 DEFAULT 'FORM_VIEW'	-- FORM_VIEW, HISTORY, RECORD_VIEW, NAVIGATION_VIEW, NESTED_VIEW, IMPORT_VIEW, EXPORT_VIEW
	) RETURN CLOB
	is
        v_Table_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
        v_View_Name 	MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := NVL(p_View_Name, v_Table_Name);
		v_workspace_id 	NUMBER;
		v_out_tab 		form_view_tab;
        v_Str 			VARCHAR2(32767);
        v_Stat 			CLOB;
        v_table_id 		NUMBER;
        v_column_id 	NUMBER;
        v_lov_data_id	NUMBER;
	begin
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

		OPEN form_view_cur(v_Table_Name, p_View_Mode);
		FETCH form_view_cur BULK COLLECT INTO v_out_tab;
		CLOSE form_view_cur;
		if v_out_tab.COUNT > 0 then 
			v_table_id := wwv_flow_id.next_val;
			v_Str := apex_string.format (
				p_message => 
				'begin' || chr(10) || chr(10) 
				|| 'wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,%s);' || chr(10) 
				|| 'wwv_flow_hint.create_table_hint_priv(' || chr(10) 
				|| '  p_table_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
				|| '  p_schema => wwv_flow_hint.g_schema,' || chr(10) 
				|| '  p_table_name  => %s,' || chr(10) 
				|| '  p_report_region_title => %s,' || chr(10) 
				|| '  p_form_region_title => %s);' || chr(10) || chr(10)
				|| 'end;' || chr(10) || '/' || chr(10),
				p0 => dbms_assert.enquote_literal(v_View_Name),
				p1 => v_table_id,
				p2 => data_browser_conf.Enquote_Literal(v_View_Name),
				p3 => data_browser_conf.Enquote_Literal('Edit ' || data_browser_conf.Table_Name_To_Header(p_Table_name)),
				p4 => data_browser_conf.Enquote_Literal(data_browser_conf.Table_Name_To_Header(p_Table_name)),
				p_max_length => 30000
			);
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;
		FOR ind IN 1 .. v_out_tab.COUNT LOOP
			v_column_id := wwv_flow_id.next_val;
			$IF data_browser_conf.g_debug $THEN
				DBMS_OUTPUT.PUT_LINE(ind || '.: ' || v_View_Name || '.' ||  v_out_tab(ind).COLUMN_NAME || ', id:' || v_column_id);
			$END
			
			v_Str := apex_string.format (
				p_message => 
				'begin' || chr(10) || chr(10) 
				|| 'wwv_flow_hint.create_column_hint_priv(' || chr(10) 
				|| '  p_label => %s,' || chr(10),
				p0 => data_browser_conf.Enquote_Literal(v_out_tab(ind).LABEL)
			);
			if v_out_tab(ind).HELP_TEXT IS NOT NULL then 
				v_Str := v_Str || apex_string.format (
					p_message => '  p_help_text => %s,' || chr(10),
					p0 => data_browser_conf.enquote_literal(v_out_tab(ind).HELP_TEXT)
				);
			end if;

			if v_out_tab(ind).FORMAT_MASK IS NOT NULL then 
				v_Str := v_Str || apex_string.format (
					p_message => '  p_mask_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal(v_out_tab(ind).FORMAT_MASK)
				);
			end if;
			v_Str := v_Str || apex_string.format (
				p_message => 
				   '  p_display_seq_form => %s,' || chr(10) 
				|| '  p_display_in_form => %s,' || chr(10),
				p0 => v_out_tab(ind).DISPLAY_SEQ_FORM,
				p1 => dbms_assert.enquote_literal(v_out_tab(ind).DISPLAY_IN_FORM)
			);
  			if v_out_tab(ind).COLUMN_EXPR_TYPE = 'POPUPKEY_FROM_LOV' then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_01 => %s,' || chr(10) 
					|| '  p_form_attribute_02 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_POPUP_LOV'),
					p1 => dbms_assert.enquote_literal('POPUP'),
					p2 => dbms_assert.enquote_literal('FIRST_ROWSET'),
					p3 => dbms_assert.enquote_literal('POPUP'),
					p_max_length => 30000
				);
  			elsif v_out_tab(ind).COLUMN_EXPR_TYPE IN ('SELECT_LIST_FROM_QUERY', 'SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER' )  then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_01 => %s,' || chr(10) 
					|| '  p_form_attribute_02 => %s,' || chr(10) 
					|| '  p_form_attribute_04 => %s,' || chr(10) 
					|| '  p_form_attribute_05 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_SELECT_LIST'),
					p1 => dbms_assert.enquote_literal('NONE'),
					p2 => dbms_assert.enquote_literal('N'),
					p3 => dbms_assert.enquote_literal('TEXT'),
					p4 => dbms_assert.enquote_literal('BOTH'),
					p5 => dbms_assert.enquote_literal('SELECT_LIST_FROM_LOV'),
					p_max_length => 30000
				);
 			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'TEXTAREA'  then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_01 => %s,' || chr(10) 
					|| '  p_form_attribute_02 => %s,' || chr(10) 
					|| '  p_form_attribute_03 => %s,' || chr(10) 
					|| '  p_form_attribute_04 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_TEXTAREA'),
					p1 => dbms_assert.enquote_literal('Y'),
					p2 => dbms_assert.enquote_literal('N'),
					p3 => dbms_assert.enquote_literal('TEXT'),
					p4 => dbms_assert.enquote_literal('BOTH'),
					p5 => dbms_assert.enquote_literal('TEXTAREA'),
					p_max_length => 30000
				);
 			elsif v_out_tab(ind).COLUMN_EXPR_TYPE IN ('NUMBER', 'FLOAT')  then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_03 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_NUMBER_FIELD'),
					p1 => dbms_assert.enquote_literal('right'),
					p2 => dbms_assert.enquote_literal('TEXT'),
					p_max_length => 30000
				);
 			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'DATE_POPUP'  then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_04 => %s,' || chr(10) 
					|| '  p_form_attribute_05 => %s,' || chr(10) 
					|| '  p_form_attribute_07 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_DATE_PICKER'),
					p1 => dbms_assert.enquote_literal('button'),
					p2 => dbms_assert.enquote_literal('N'),
					p3 => dbms_assert.enquote_literal('NONE'),
					p4 => dbms_assert.enquote_literal('DATE_PICKER'),
					p_max_length => 30000
				);
			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'DISPLAY_ONLY' then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_01 => %s,' || chr(10) 
					|| '  p_form_attribute_02 => %s,' || chr(10) 
					|| '  p_form_attribute_04 => %s,' || chr(10) 
					|| '  p_form_attribute_05 => %s,' || chr(10) 
					|| '  p_form_attribute_07 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_DISPLAY_ONLY'),
					p1 => dbms_assert.enquote_literal('Y'),
					p2 => dbms_assert.enquote_literal('VALUE'),
					p3 => dbms_assert.enquote_literal('N'),
					p4 => dbms_assert.enquote_literal('N'),
					p5 => dbms_assert.enquote_literal('NONE'),
					p6 => dbms_assert.enquote_literal('ESCAPE_SC'),
					p_max_length => 30000
				);
			elsif v_out_tab(ind).COLUMN_EXPR_TYPE = 'FILE_BROWSER' then
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_01 => %s,' || chr(10) 
					|| '  p_form_attribute_02 => %s,' || chr(10) 
					|| '  p_form_attribute_03 => %s,' || chr(10) 
					|| '  p_form_attribute_05 => %s,' || chr(10) 
					|| '  p_form_attribute_06 => %s,' || chr(10) 
					|| '  p_form_attribute_08 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_FILE'),
					p1 => dbms_assert.enquote_literal('DB_COLUMN'),
					p2 => dbms_assert.enquote_literal(v_out_tab(ind).MIME_TYPE_COLUMN_NAME),
					p3 => dbms_assert.enquote_literal(v_out_tab(ind).FILE_NAME_COLUMN_NAME),
					p4 => dbms_assert.enquote_literal(v_out_tab(ind).FILE_DATE_COLUMN_NAME),
					p5 => dbms_assert.enquote_literal('Y'),
					p6 => dbms_assert.enquote_literal('attachment'),
					p7 => dbms_assert.enquote_literal('TEXT'),
					p_max_length => 30000
				);
			else -- TEXT
				v_Str := v_Str || apex_string.format (
					p_message => 
					   '  p_display_as_form => %s,' || chr(10)
					|| '  p_form_attribute_01 => %s,' || chr(10) 
					|| '  p_form_attribute_02 => %s,' || chr(10) 
					|| '  p_form_attribute_03 => %s,' || chr(10) 
					|| '  p_form_attribute_04 => %s,' || chr(10) 
					|| '  p_form_attribute_05 => %s,' || chr(10) 
					|| '  p_display_as_tab_form => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal('NATIVE_TEXT_FIELD'),
					p1 => dbms_assert.enquote_literal('N'),
					p2 => dbms_assert.enquote_literal('N'),
					p3 => dbms_assert.enquote_literal('N'),
					p4 => dbms_assert.enquote_literal('TEXT'),
					p5 => dbms_assert.enquote_literal('BOTH'),
					p6 => dbms_assert.enquote_literal('TEXT'),
					p_max_length => 30000
				);
  			end if;

			if v_out_tab(ind).FORMAT_MASK IS NOT NULL then 
				v_Str := v_Str || apex_string.format (
					p_message => '  p_mask_report => %s,' || chr(10),
					p0 => dbms_assert.enquote_literal(v_out_tab(ind).FORMAT_MASK)
				);
			end if;
			v_Str := v_Str || apex_string.format (
				p_message => 
				   '  p_display_seq_report => %s,' || chr(10) 
				|| '  p_display_in_report => %s,' || chr(10) 
				|| '  p_display_as_report => %s,' || chr(10) 
				|| '  p_aggregate_by => %s,' || chr(10),
				p0 => v_out_tab(ind).DISPLAY_SEQ_FORM,
				p1 => dbms_assert.enquote_literal(v_out_tab(ind).DISPLAY_IN_REPORT),
				p2 => dbms_assert.enquote_literal('ESCAPE_SC'),
				p3 => dbms_assert.enquote_literal('N'),
				p_max_length => 30000
			);
			if v_out_tab(ind).COLUMN_EXPR_TYPE IN ('SELECT_LIST_FROM_QUERY', 'POPUPKEY_FROM_LOV')  then
				v_Str := v_Str || apex_string.format (
					p_message => 
					'  p_lov_query => %s,' || chr(10),
					p0 => REPLACE(data_browser_conf.Enquote_Literal(v_out_tab(ind).LOV_QUERY), RPAD(chr(10), 5, ' '), '''||chr(10)||'||chr(10)||''''),
					p_max_length => 30000
				);
			end if;
			v_Str := v_Str || apex_string.format (
				p_message => 
				   '  p_required => %s,' || chr(10) 
				|| '  p_alignment => %s,' || chr(10) 
				|| '  p_display_width => %s,' || chr(10) 
				|| '  p_max_width => %s,' || chr(10) 
				|| '  p_height => %s,' || chr(10) 
				|| '  p_group_by => %s,' || chr(10) 
				|| '  p_searchable => %s,' || chr(10) 
				|| '  p_column_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
				|| '  p_table_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
				|| '  p_column_name => %s);' || chr(10) || chr(10)
				|| 'end;' || chr(10) || '/' || chr(10),
				p0 => dbms_assert.enquote_literal(v_out_tab(ind).REQUIRED),
				p1 => dbms_assert.enquote_literal(SUBSTR(v_out_tab(ind).REPORT_COL_ALIGNMENT, 1, 1)),
				p2 => v_out_tab(ind).FORM_DISPLAY_WIDTH,
				p3 => v_out_tab(ind).MAX_WIDTH,
				p4 => v_out_tab(ind).FORM_DISPLAY_HEIGHT,
				p5 => dbms_assert.enquote_literal('N'),
				p6 => dbms_assert.enquote_literal('Y'),
				p7 => v_column_id,
				p8 => v_table_id,
				p9 => data_browser_conf.Enquote_Literal(v_out_tab(ind).COLUMN_NAME),
				p_max_length => 30000
			);
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
			if v_out_tab(ind).COLUMN_EXPR_TYPE IN ('SELECT_LIST', 'SWITCH_CHAR', 'SWITCH_NUMBER') then
				if v_out_tab(ind).YES_NO_TYPE IS NOT NULL then
					for lov_cur in (
						select DISP_SEQUENCE,
							SUBSTR(P.COLUMN_VALUE, 1, OFFSET-1) DISPLAY_VALUE,
							SUBSTR(P.COLUMN_VALUE, OFFSET+1) COLUMN_VALUE
						from (
							SELECT P.COLUMN_VALUE, INSTR(P.COLUMN_VALUE, ';') OFFSET, ROWNUM DISP_SEQUENCE
							FROM TABLE( data_browser_conf.in_list(
								data_browser_conf.Get_Yes_No_Type_LOV(v_out_tab(ind).YES_NO_TYPE), ',') ) P
						) P
					) loop 
						v_lov_data_id := wwv_flow_id.next_val;
						v_Str := apex_string.format (
							p_message => 
							'begin' || chr(10) || chr(10) 
							|| 'wwv_flow_hint.create_lov_data_priv(' || chr(10) 
							|| '  p_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
							|| '  p_column_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
							|| '  p_lov_disp_sequence  => %s,' || chr(10) 
							|| '  p_lov_disp_value => %s,' || chr(10) 
							|| '  p_lov_return_value => %s);' || chr(10) || chr(10)
							|| 'end;' || chr(10) || '/' || chr(10),
							p0 => v_lov_data_id,
							p1 => v_column_id,
							p2 => lov_cur.DISP_SEQUENCE,
							p3 => dbms_assert.enquote_literal(lov_cur.DISPLAY_VALUE),
							p4 => dbms_assert.enquote_literal(lov_cur.COLUMN_VALUE),
							p_max_length => 30000
						);
						dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
					end loop;
				else
					for lov_cur in (
						SELECT DISP_SEQUENCE, DISPLAY_VALUE, LIST_VALUE
						FROM TABLE( data_browser_conf.Table_Column_In_List_Cursor(
							p_Table_Name => v_Table_Name,
							p_Column_Name => v_out_tab(ind).COLUMN_NAME
						))
					) loop 
						v_lov_data_id := wwv_flow_id.next_val;
						v_Str := apex_string.format (
							p_message => 
							'begin' || chr(10) || chr(10) 
							|| 'wwv_flow_hint.create_lov_data_priv(' || chr(10) 
							|| '  p_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
							|| '  p_column_id => %s + wwv_flow_api.g_id_offset,' || chr(10) 
							|| '  p_lov_disp_sequence  => %s,' || chr(10) 
							|| '  p_lov_disp_value => %s,' || chr(10) 
							|| '  p_lov_return_value => %s);' || chr(10) || chr(10)
							|| 'end;' || chr(10) || '/' || chr(10),
							p0 => v_lov_data_id,
							p1 => v_column_id,
							p2 => lov_cur.DISP_SEQUENCE,
							p3 => dbms_assert.enquote_literal(lov_cur.DISPLAY_VALUE),
							p4 => dbms_assert.enquote_literal(lov_cur.LIST_VALUE),
							p_max_length => 30000
						);
						dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
					end loop;
				end if;				
			end if;
		END LOOP;
		return v_Stat;
$IF data_browser_conf.g_use_exceptions $THEN
	exception
	  when others then
	    if form_view_cur%ISOPEN then
			CLOSE form_view_cur;
		end if;
		raise;
$END 
	end UI_Defaults_export_table;


	FUNCTION UI_Defaults_export_all_tables (
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	) RETURN CLOB
	IS
        v_Stat 			CLOB;
        v_Result		CLOB;
	BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Result, true, dbms_lob.call);
    	v_Result := data_browser_UI_Defaults.UI_Defaults_export_header (
			p_Workspace_Name => p_Workspace_Name,
			p_Schema_Name => p_Schema_Name
		);
		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME
			FROM MVDATA_BROWSER_VIEWS
			ORDER BY TABLE_NAME
		) loop
			v_Stat := data_browser_UI_Defaults.UI_Defaults_export_table (
				p_Table_name => c_cur.VIEW_NAME,
				p_View_Mode => 'FORM_VIEW'
			);
			dbms_lob.append(v_Result, v_Stat);
		end loop;
		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME, IMP_VIEW_NAME
			FROM (
				SELECT TABLE_NAME, VIEW_NAME,
					'V' || SHORT_NAME || '_IMP' IMP_VIEW_NAME
				FROM MVDATA_BROWSER_VIEWS
			) A 
			WHERE EXISTS (
				SELECT 1
				FROM SYS.USER_VIEWS B 
				WHERE B.VIEW_NAME = A.IMP_VIEW_NAME
			)
			ORDER BY TABLE_NAME
		) loop
			v_Stat := data_browser_UI_Defaults.UI_Defaults_export_table (
				p_Table_name => c_cur.VIEW_NAME,
				p_View_name => c_cur.IMP_VIEW_NAME,
				p_View_Mode => 'IMPORT_VIEW'
			);
			dbms_lob.append(v_Result, v_Stat);
		end loop;
		v_Stat := data_browser_UI_Defaults.UI_Defaults_export_footer;
		dbms_lob.append(v_Result, v_Stat);
		return v_Result;
	END UI_Defaults_export_all_tables;


	PROCEDURE UI_Defaults_download_all_tables (
		p_Workspace_Name VARCHAR2,
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	) 
	IS
        v_Stat 			CLOB;
        v_File_Name		VARCHAR2(128);
	BEGIN
		v_File_Name := LOWER(p_Schema_Name) || '_uidefaults.sql';
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
    	v_Stat := data_browser_UI_Defaults.UI_Defaults_export_all_tables(
    		p_Workspace_Name => p_Workspace_Name,
    		p_Schema_Name => p_Schema_Name
    	);
		data_browser_blobs.Download_Clob (
			p_clob		=> v_Stat,
			p_File_Name => v_File_Name
		);
		apex_application.stop_apex_engine;
	END UI_Defaults_download_all_tables;


END data_browser_UI_Defaults;
/
show errors

/*
set serveroutput on size unlimited
exec data_browser_UI_Defaults.UI_Defaults_update_all_tables('STRACK_DEV');
*/