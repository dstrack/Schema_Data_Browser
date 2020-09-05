set define '^'
set verify off
set serveroutput on size 1000000
set feedback off
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
 
prompt  Set Credentials...
 
begin
 
  -- Assumes you are running the script connected to sqlplus as the schema associated with the UI defaults or as the product schema.
  wwv_flow_api.set_security_group_id(p_security_group_id=>1293931922049787);
 
end;
/

begin wwv_flow.g_import_in_progress := true; end;
/
begin 

select value into wwv_flow_api.g_nls_numeric_chars from nls_session_parameters where parameter='NLS_NUMERIC_CHARACTERS';

end;

/
begin execute immediate 'alter session set nls_numeric_characters=''.,''';

end;

/
begin wwv_flow.g_browser_language := 'en'; end;
/
prompt  Check Compatibility...
 
begin
 
-- This date identifies the minimum version required to install this file.
wwv_flow_api.set_version(p_version_yyyy_mm_dd=>'2019.03.31');
 
end;
/

-- SET SCHEMA
 
begin
 
   wwv_flow_api.g_id_offset := 0;
   wwv_flow_hint.g_schema   := 'HR';
   wwv_flow_hint.check_schema_privs;
 
end;
/

 
--------------------------------------------------------------------
prompt  SCHEMA STRACK_DEV - User Interface Defaults, Table Defaults
--
-- Import using sqlplus as the Oracle user: APEX_190100
-- Exported 14:18 Monday August 31, 2020 by: DIRK
--
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'COUNTRIES');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182273264095620727 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'COUNTRIES',
  p_report_region_title => 'Edit Countries',
  p_form_region_title => 'Countries');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Country Id',
  p_display_seq_form => 1,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 1,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 2,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182273360464620727 + wwv_flow_api.g_id_offset,
  p_table_id => 182273264095620727 + wwv_flow_api.g_id_offset,
  p_column_name => 'COUNTRY_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Country Name',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 40,
  p_max_width => 40,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182273407219620727 + wwv_flow_api.g_id_offset,
  p_table_id => 182273264095620727 + wwv_flow_api.g_id_offset,
  p_column_name => 'COUNTRY_NAME');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Countries Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 4,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182273519475620727 + wwv_flow_api.g_id_offset,
  p_table_id => 182273264095620727 + wwv_flow_api.g_id_offset,
  p_column_name => 'COUNTRIES_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Region',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.REGION_NAME D, '||chr(10)||
'    L1.REGION_ID R '||chr(10)||
' FROM REGIONS L1 ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182273659941620727 + wwv_flow_api.g_id_offset,
  p_table_id => 182273264095620727 + wwv_flow_api.g_id_offset,
  p_column_name => 'REGION_ID');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'DEPARTMENTS');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182273792013620740 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'DEPARTMENTS',
  p_report_region_title => 'Edit Departments',
  p_form_region_title => 'Departments');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Department Id',
  p_mask_form => '99G990',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G990',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 8,
  p_max_width => 6,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182273873796620740 + wwv_flow_api.g_id_offset,
  p_table_id => 182273792013620740 + wwv_flow_api.g_id_offset,
  p_column_name => 'DEPARTMENT_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Department Name',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 30,
  p_max_width => 30,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182273956710620740 + wwv_flow_api.g_id_offset,
  p_table_id => 182273792013620740 + wwv_flow_api.g_id_offset,
  p_column_name => 'DEPARTMENT_NAME');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Location',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT SUBSTR(L1.STREET_ADDRESS||'' • '''||chr(10)||
'    || L1.POSTAL_CODE||'' • '''||chr(10)||
'    || L1.CITY||'' • '''||chr(10)||
'    || L1.STATE_PROVINCE, 1, 1024) D, '||chr(10)||
'    L1.LOCATION_ID R '||chr(10)||
' FROM LOCATIONS L1 ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274048299620740 + wwv_flow_api.g_id_offset,
  p_table_id => 182273792013620740 + wwv_flow_api.g_id_offset,
  p_column_name => 'LOCATION_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Manager',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.EMAIL D, '||chr(10)||
'    L1.EMPLOYEE_ID R '||chr(10)||
' FROM EMPLOYEES L1 ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274143741620740 + wwv_flow_api.g_id_offset,
  p_table_id => 182273792013620740 + wwv_flow_api.g_id_offset,
  p_column_name => 'MANAGER_ID');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'DIAGRAM_COLORS');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'DIAGRAM_COLORS',
  p_report_region_title => 'Edit Colors',
  p_form_region_title => 'Colors');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Active',
  p_display_seq_form => 7,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 7,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 1,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274329729620787 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'ACTIVE');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182274415908620921 + wwv_flow_api.g_id_offset,
  p_column_id => 182274329729620787 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 1,
  p_lov_disp_value => 'Y',
  p_lov_return_value => 'Y');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182274549526620921 + wwv_flow_api.g_id_offset,
  p_column_id => 182274329729620787 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 2,
  p_lov_disp_value => 'N',
  p_lov_return_value => 'N');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Hex Rgb',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 50,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274602401620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'HEX_RGB');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Red Rgb',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274778710620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'RED_RGB');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274826542620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Blü Rgb',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 6,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 6,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182274926009620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'BLUE_RGB');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Last Modified At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 10,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 10,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275017642620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'LAST_MODIFIED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Green Rgb',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 5,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275118595620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'GREEN_RGB');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Color Name',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 128,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275286283620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'COLOR_NAME');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 8,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 8,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275322663620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created By',
  p_display_seq_form => 9,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_display_seq_report => 9,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 32,
  p_max_width => 32,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275432960620921 + wwv_flow_api.g_id_offset,
  p_table_id => 182274242088620787 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_BY');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'DIAGRAM_EDGES');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'DIAGRAM_EDGES',
  p_report_region_title => 'Edit Edges',
  p_form_region_title => 'Edges');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created By',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_display_seq_report => 4,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 32,
  p_max_width => 32,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275631412620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_BY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Last Modified At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 5,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275752401620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'LAST_MODIFIED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Description',
  p_display_seq_form => 8,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 8,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 128,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275898253620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'DESCRIPTION');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Color',
  p_display_seq_form => 9,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 9,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 128,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182275966534620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'COLOR');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Springy Diagrams',
  p_display_seq_form => 12,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 12,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.DESCRIPTION D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM SPRINGY_DIAGRAMS L1 ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276094824620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'SPRINGY_DIAGRAMS_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276148084620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Source Node',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT SUBSTR(L1A.DESCRIPTION||'' • '''||chr(10)||
'    || L1.DESCRIPTION, 1, 1024) D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM DIAGRAM_NODES L1'||chr(10)||
' JOIN SPRINGY_DIAGRAMS L1A ON L1A.ID = L1.SPRINGY_DIAGRAMS_ID'||chr(10)||
' WHERE L1.ACTIVE = ''Y'' ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276224007620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'SOURCE_NODE_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Hex Rgb',
  p_display_seq_form => 10,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 10,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 50,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276382924620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'HEX_RGB');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Target Node',
  p_display_seq_form => 7,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 7,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT SUBSTR(L1A.DESCRIPTION||'' • '''||chr(10)||
'    || L1.DESCRIPTION, 1, 1024) D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM DIAGRAM_NODES L1'||chr(10)||
' JOIN SPRINGY_DIAGRAMS L1A ON L1A.ID = L1.SPRINGY_DIAGRAMS_ID'||chr(10)||
' WHERE L1.ACTIVE = ''Y'' ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276455145620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'TARGET_NODE_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Diagram Color',
  p_display_seq_form => 11,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 11,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.COLOR_NAME D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM DIAGRAM_COLORS L1'||chr(10)||
' WHERE L1.ACTIVE = ''Y'' ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276533872620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'DIAGRAM_COLOR_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 3,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276617892620975 + wwv_flow_api.g_id_offset,
  p_table_id => 182275528004620975 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_AT');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'DIAGRAM_NODES');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'DIAGRAM_NODES',
  p_report_region_title => 'Edit Nodes',
  p_form_region_title => 'Nodes');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Description',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXTAREA',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'TEXT',
  p_form_attribute_04 => 'BOTH',
  p_display_as_tab_form => 'TEXTAREA',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 512,
  p_height => 3,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276897137621013 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'DESCRIPTION');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'X Coordinate',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 11,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 11,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182276948906621013 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'X_COORDINATE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Diagram Shapes',
  p_display_seq_form => 9,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 9,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.DESCRIPTION D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM DIAGRAM_SHAPES L1'||chr(10)||
' WHERE L1.ACTIVE = ''Y'' ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277078198621013 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'DIAGRAM_SHAPES_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277136398621013 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Active',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 1,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277269172621013 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'ACTIVE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Diagram Color',
  p_display_seq_form => 15,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 15,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.COLOR_NAME D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM DIAGRAM_COLORS L1'||chr(10)||
' WHERE L1.ACTIVE = ''Y'' ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277319441621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'DIAGRAM_COLOR_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Last Modified At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 7,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 7,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277487079621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'LAST_MODIFIED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 5,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277562829621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Springy Diagrams',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.DESCRIPTION D, '||chr(10)||
'    L1.ID R '||chr(10)||
' FROM SPRINGY_DIAGRAMS L1 ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277656561621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'SPRINGY_DIAGRAMS_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Color',
  p_display_seq_form => 10,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 10,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 130,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277766151621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'COLOR');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created By',
  p_display_seq_form => 6,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_display_seq_report => 6,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 32,
  p_max_width => 32,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277800492621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_BY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Y Coordinate',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 12,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 12,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182277980361621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'Y_COORDINATE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Mass',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 13,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 13,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278057596621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'MASS');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Hex Rgb',
  p_display_seq_form => 14,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 14,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 50,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278166367621014 + wwv_flow_api.g_id_offset,
  p_table_id => 182276774192621013 + wwv_flow_api.g_id_offset,
  p_column_name => 'HEX_RGB');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'DIAGRAM_SHAPES');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'DIAGRAM_SHAPES',
  p_report_region_title => 'Edit Shapes',
  p_form_region_title => 'Shapes');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278347022621030 + wwv_flow_api.g_id_offset,
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_column_name => 'ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created By',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_display_seq_report => 5,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 32,
  p_max_width => 32,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278484461621030 + wwv_flow_api.g_id_offset,
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_BY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 4,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278599008621030 + wwv_flow_api.g_id_offset,
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Last Modified At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 6,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 6,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278690192621030 + wwv_flow_api.g_id_offset,
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_column_name => 'LAST_MODIFIED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Active',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 1,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182278729363621030 + wwv_flow_api.g_id_offset,
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_column_name => 'ACTIVE');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182278863781621036 + wwv_flow_api.g_id_offset,
  p_column_id => 182278729363621030 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 1,
  p_lov_disp_value => 'Y',
  p_lov_return_value => 'Y');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182278954096621036 + wwv_flow_api.g_id_offset,
  p_column_id => 182278729363621030 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 2,
  p_lov_disp_value => 'N',
  p_lov_return_value => 'N');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Description',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXTAREA',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'TEXT',
  p_form_attribute_04 => 'BOTH',
  p_display_as_tab_form => 'TEXTAREA',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 512,
  p_height => 3,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279031664621036 + wwv_flow_api.g_id_offset,
  p_table_id => 182278227646621030 + wwv_flow_api.g_id_offset,
  p_column_name => 'DESCRIPTION');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'EMPLOYEES');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'EMPLOYEES',
  p_report_region_title => 'Edit Employees',
  p_form_region_title => 'Employees');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Job',
  p_display_seq_form => 7,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 7,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.JOB_TITLE D, '||chr(10)||
'    L1.JOB_ID R '||chr(10)||
' FROM JOBS L1 ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279213424621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'JOB_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Salary',
  p_mask_form => '9G999G990D99',
  p_display_seq_form => 8,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '9G999G990D99',
  p_display_seq_report => 8,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 12,
  p_max_width => 12,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279333813621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'SALARY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Manager',
  p_display_seq_form => 10,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 10,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.EMAIL D, '||chr(10)||
'    L1.EMPLOYEE_ID R '||chr(10)||
' FROM EMPLOYEES L1 ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279493860621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'MANAGER_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Last Name',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 25,
  p_max_width => 25,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279524454621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'LAST_NAME');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Email',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 25,
  p_max_width => 25,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279642414621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'EMAIL');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Department',
  p_display_seq_form => 11,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 11,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT SUBSTR(L1.DEPARTMENT_NAME||'' • '''||chr(10)||
'    || L1B.EMAIL||'' • '''||chr(10)||
'    || L1C.CITY||'' – '''||chr(10)||
'    || L1C.POSTAL_CODE||'' – '''||chr(10)||
'    || L1C.STATE_PROVINCE||'' – '''||chr(10)||
'    || L1C.STREET_ADDRESS, 1, 1024) D, '||chr(10)||
'    L1.DEPARTMENT_ID R '||chr(10)||
' FROM DEPARTMENTS L1'||chr(10)||
' LEFT OUTER JOIN EMPLOYEES L1B ON L1B.EMPLOYEE_ID = L1.MANAGER_ID'||chr(10)||
' LEFT OUTER JOIN LOCATIONS L1C ON L1C.LOCATION_ID = L1.LOCATION_ID ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279753330621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'DEPARTMENT_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Employee Id',
  p_mask_form => '9G999G990',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '9G999G990',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 9,
  p_max_width => 9,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279843054621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'EMPLOYEE_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Hire Date',
  p_mask_form => 'DD.MM.YYYY',
  p_display_seq_form => 6,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DATE_PICKER',
  p_form_attribute_04 => 'button',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'DATE_PICKER',
  p_mask_report => 'DD.MM.YYYY',
  p_display_seq_report => 6,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 10,
  p_max_width => 10,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182279989930621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'HIRE_DATE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'First Name',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 20,
  p_max_width => 20,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280044003621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'FIRST_NAME');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Phone Number',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 5,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 20,
  p_max_width => 20,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280181008621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'PHONE_NUMBER');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Commission Pct',
  p_mask_form => '0D99',
  p_display_seq_form => 9,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '0D99',
  p_display_seq_report => 9,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 8,
  p_max_width => 4,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280245914621064 + wwv_flow_api.g_id_offset,
  p_table_id => 182279172905621064 + wwv_flow_api.g_id_offset,
  p_column_name => 'COMMISSION_PCT');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'JOBS');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182280367996621080 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'JOBS',
  p_report_region_title => 'Edit Jobs',
  p_form_region_title => 'Jobs');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Job Title',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 35,
  p_max_width => 35,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280424749621080 + wwv_flow_api.g_id_offset,
  p_table_id => 182280367996621080 + wwv_flow_api.g_id_offset,
  p_column_name => 'JOB_TITLE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Max Salary',
  p_mask_form => '9G999G990',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '9G999G990',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 9,
  p_max_width => 9,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280542702621080 + wwv_flow_api.g_id_offset,
  p_table_id => 182280367996621080 + wwv_flow_api.g_id_offset,
  p_column_name => 'MAX_SALARY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Jobs Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 5,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280668371621080 + wwv_flow_api.g_id_offset,
  p_table_id => 182280367996621080 + wwv_flow_api.g_id_offset,
  p_column_name => 'JOBS_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Job Id',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 1,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 10,
  p_max_width => 10,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280771507621080 + wwv_flow_api.g_id_offset,
  p_table_id => 182280367996621080 + wwv_flow_api.g_id_offset,
  p_column_name => 'JOB_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Min Salary',
  p_mask_form => '9G999G990',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '9G999G990',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 9,
  p_max_width => 9,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182280830219621080 + wwv_flow_api.g_id_offset,
  p_table_id => 182280367996621080 + wwv_flow_api.g_id_offset,
  p_column_name => 'MIN_SALARY');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'JOB_HISTORY');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182280962820621096 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'JOB_HISTORY',
  p_report_region_title => 'Edit Job History',
  p_form_region_title => 'Job History');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Department',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 5,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT SUBSTR(L1.DEPARTMENT_NAME||'' • '''||chr(10)||
'    || L1B.EMAIL||'' • '''||chr(10)||
'    || L1C.CITY||'' – '''||chr(10)||
'    || L1C.POSTAL_CODE||'' – '''||chr(10)||
'    || L1C.STATE_PROVINCE||'' – '''||chr(10)||
'    || L1C.STREET_ADDRESS, 1, 1024) D, '||chr(10)||
'    L1.DEPARTMENT_ID R '||chr(10)||
' FROM DEPARTMENTS L1'||chr(10)||
' LEFT OUTER JOIN EMPLOYEES L1B ON L1B.EMPLOYEE_ID = L1.MANAGER_ID'||chr(10)||
' LEFT OUTER JOIN LOCATIONS L1C ON L1C.LOCATION_ID = L1.LOCATION_ID ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281041310621096 + wwv_flow_api.g_id_offset,
  p_table_id => 182280962820621096 + wwv_flow_api.g_id_offset,
  p_column_name => 'DEPARTMENT_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Start Date',
  p_mask_form => 'DD.MM.YYYY',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DATE_PICKER',
  p_form_attribute_04 => 'button',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'DATE_PICKER',
  p_mask_report => 'DD.MM.YYYY',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 10,
  p_max_width => 10,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281152805621096 + wwv_flow_api.g_id_offset,
  p_table_id => 182280962820621096 + wwv_flow_api.g_id_offset,
  p_column_name => 'START_DATE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Employee',
  p_display_seq_form => 1,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 1,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.EMAIL D, '||chr(10)||
'    L1.EMPLOYEE_ID R '||chr(10)||
' FROM EMPLOYEES L1 ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281287010621096 + wwv_flow_api.g_id_offset,
  p_table_id => 182280962820621096 + wwv_flow_api.g_id_offset,
  p_column_name => 'EMPLOYEE_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Job',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT L1.JOB_TITLE D, '||chr(10)||
'    L1.JOB_ID R '||chr(10)||
' FROM JOBS L1 ORDER BY 1',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281303001621096 + wwv_flow_api.g_id_offset,
  p_table_id => 182280962820621096 + wwv_flow_api.g_id_offset,
  p_column_name => 'JOB_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'End Date',
  p_mask_form => 'DD.MM.YYYY',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DATE_PICKER',
  p_form_attribute_04 => 'button',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'DATE_PICKER',
  p_mask_report => 'DD.MM.YYYY',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 10,
  p_max_width => 10,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281486050621096 + wwv_flow_api.g_id_offset,
  p_table_id => 182280962820621096 + wwv_flow_api.g_id_offset,
  p_column_name => 'END_DATE');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'LOCATIONS');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'LOCATIONS',
  p_report_region_title => 'Edit Locations',
  p_form_region_title => 'Locations');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Country',
  p_display_seq_form => 6,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_POPUP_LOV',
  p_form_attribute_01 => 'NOT_ENTERABLE',
  p_form_attribute_02 => 'FIRST_ROWSET',
  p_display_as_tab_form => 'POPUP',
  p_display_seq_report => 6,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_lov_query => 'SELECT SUBSTR(L1.COUNTRY_NAME||'' • '''||chr(10)||
'    || L1B.REGION_NAME, 1, 1024) D, '||chr(10)||
'    L1.COUNTRY_ID R '||chr(10)||
' FROM COUNTRIES L1'||chr(10)||
' LEFT OUTER JOIN REGIONS L1B ON L1B.REGION_ID = L1.REGION_ID ORDER BY 1',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 1024,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281620933621114 + wwv_flow_api.g_id_offset,
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_column_name => 'COUNTRY_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'State Province',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 5,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 25,
  p_max_width => 25,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281791455621114 + wwv_flow_api.g_id_offset,
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_column_name => 'STATE_PROVINCE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Street Address',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 40,
  p_max_width => 40,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281864706621114 + wwv_flow_api.g_id_offset,
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_column_name => 'STREET_ADDRESS');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'City',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 30,
  p_max_width => 30,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182281912094621114 + wwv_flow_api.g_id_offset,
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_column_name => 'CITY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Location Id',
  p_mask_form => '99G990',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G990',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 8,
  p_max_width => 6,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282023781621114 + wwv_flow_api.g_id_offset,
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_column_name => 'LOCATION_ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Postal Code',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 12,
  p_max_width => 12,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282108212621114 + wwv_flow_api.g_id_offset,
  p_table_id => 182281591057621114 + wwv_flow_api.g_id_offset,
  p_column_name => 'POSTAL_CODE');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'REGIONS');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182282208251621121 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'REGIONS',
  p_report_region_title => 'Edit Regions',
  p_form_region_title => 'Regions');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Name',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 25,
  p_max_width => 25,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282390401621121 + wwv_flow_api.g_id_offset,
  p_table_id => 182282208251621121 + wwv_flow_api.g_id_offset,
  p_column_name => 'REGION_NAME');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282469207621121 + wwv_flow_api.g_id_offset,
  p_table_id => 182282208251621121 + wwv_flow_api.g_id_offset,
  p_column_name => 'REGION_ID');

end;
/
begin

wwv_flow_hint.remove_hint_priv(wwv_flow_hint.g_schema,'SPRINGY_DIAGRAMS');
wwv_flow_hint.create_table_hint_priv(
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_schema => wwv_flow_hint.g_schema,
  p_table_name  => 'SPRINGY_DIAGRAMS',
  p_report_region_title => 'Edit Springy Diagrams',
  p_form_region_title => 'Springy Diagrams');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Zoom Factor',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 5,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 5,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282608984621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'ZOOM_FACTOR');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Y Offset',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 7,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 7,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282773545621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'Y_OFFSET');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Canvas Width',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 8,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 8,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282825118621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'CANVAS_WIDTH');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 17,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 17,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182282923372621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Id',
  p_mask_form => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_form => 1,
  p_display_in_form => 'N',
  p_display_as_form => 'NATIVE_TEXT_FIELD',
  p_form_attribute_01 => 'N',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',
  p_display_seq_report => 1,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'R',
  p_display_width => 50,
  p_max_width => 63,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283042295621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'ID');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Description',
  p_display_seq_form => 2,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_TEXTAREA',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'N',
  p_form_attribute_03 => 'TEXT',
  p_form_attribute_04 => 'BOTH',
  p_display_as_tab_form => 'TEXTAREA',
  p_display_seq_report => 2,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'Y',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 512,
  p_height => 3,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283147575621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'DESCRIPTION');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Stiffness',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 11,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 11,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283280341621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'STIFFNESS');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Created By',
  p_display_seq_form => 18,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_display_seq_report => 18,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 32,
  p_max_width => 32,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283388672621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'CREATED_BY');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Last Modified At',
  p_mask_form => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_form => 19,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_DISPLAY_ONLY',
  p_form_attribute_01 => 'Y',
  p_form_attribute_02 => 'VALUE',
  p_form_attribute_04 => 'N',
  p_form_attribute_05 => 'N',
  p_form_attribute_07 => 'NONE',
  p_display_as_tab_form => 'ESCAPE_SC',
  p_mask_report => 'DD.MM.YYYY HH24:MI:SS',
  p_display_seq_report => 19,
  p_display_in_report => 'N',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 21,
  p_max_width => 21,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283441889621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'LAST_MODIFIED_AT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'X Offset',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 6,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 6,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283535575621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'X_OFFSET');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Fontsize',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 4,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 4,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283611215621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'FONTSIZE');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Minenergythreshold',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 14,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 14,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283705053621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'MINENERGYTHRESHOLD');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Pinweight',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 21,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 21,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283867953621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'PINWEIGHT');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Repulsion',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 12,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 12,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182283963822621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'REPULSION');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Damping',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 13,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 13,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182284082886621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'DAMPING');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Maxspeed',
  p_mask_form => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_form => 15,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_NUMBER_FIELD',
  p_form_attribute_03 => 'right',
  p_display_as_tab_form => 'TEXT',
  p_mask_report => '99G999G999G999G999G999G999G990D9999999999999999',
  p_display_seq_report => 15,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'R',
  p_display_width => 38,
  p_max_width => 38,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182284137554621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'MAXSPEED');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Excite Method',
  p_display_seq_form => 16,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 16,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 50,
  p_max_width => 50,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182284268120621170 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'EXCITE_METHOD');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182284349767621177 + wwv_flow_api.g_id_offset,
  p_column_id => 182284268120621170 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 1,
  p_lov_disp_value => 'None',
  p_lov_return_value => 'none');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182284474864621177 + wwv_flow_api.g_id_offset,
  p_column_id => 182284268120621170 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 2,
  p_lov_disp_value => 'Downstream',
  p_lov_return_value => 'downstream');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182284514421621177 + wwv_flow_api.g_id_offset,
  p_column_id => 182284268120621170 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 3,
  p_lov_disp_value => 'Upstream',
  p_lov_return_value => 'upstream');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182284644863621177 + wwv_flow_api.g_id_offset,
  p_column_id => 182284268120621170 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 4,
  p_lov_disp_value => 'Connected',
  p_lov_return_value => 'connected');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Exclude Singles',
  p_display_seq_form => 9,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 9,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 5,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182284780038621177 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'EXCLUDE_SINGLES');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182284878998621184 + wwv_flow_api.g_id_offset,
  p_column_id => 182284780038621177 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 1,
  p_lov_disp_value => 'Yes',
  p_lov_return_value => 'YES');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182284974294621184 + wwv_flow_api.g_id_offset,
  p_column_id => 182284780038621177 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 2,
  p_lov_disp_value => 'No',
  p_lov_return_value => 'NO');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Edge Labels',
  p_display_seq_form => 10,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 10,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 5,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182285072682621184 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'EDGE_LABELS');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182285198352621190 + wwv_flow_api.g_id_offset,
  p_column_id => 182285072682621184 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 1,
  p_lov_disp_value => 'Yes',
  p_lov_return_value => 'YES');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182285206085621190 + wwv_flow_api.g_id_offset,
  p_column_id => 182285072682621184 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 2,
  p_lov_disp_value => 'No',
  p_lov_return_value => 'NO');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182285341313621190 + wwv_flow_api.g_id_offset,
  p_column_id => 182285072682621184 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 3,
  p_lov_disp_value => 'Boxes',
  p_lov_return_value => 'BOXES');

end;
/
begin

wwv_flow_hint.create_column_hint_priv(
  p_label => 'Protected',
  p_display_seq_form => 3,
  p_display_in_form => 'Y',
  p_display_as_form => 'NATIVE_SELECT_LIST',
  p_form_attribute_01 => 'NONE',
  p_form_attribute_02 => 'N',
  p_form_attribute_04 => 'TEXT',
  p_form_attribute_05 => 'BOTH',
  p_display_as_tab_form => 'SELECT_LIST_FROM_LOV',
  p_display_seq_report => 3,
  p_display_in_report => 'Y',
  p_display_as_report => 'ESCAPE_SC',
  p_aggregate_by => 'N',
  p_required => 'N',
  p_alignment => 'L',
  p_display_width => 8,
  p_max_width => 1,
  p_height => 1,
  p_group_by => 'N',
  p_searchable => 'Y',
  p_column_id => 182285460198621190 + wwv_flow_api.g_id_offset,
  p_table_id => 182282517074621170 + wwv_flow_api.g_id_offset,
  p_column_name => 'PROTECTED');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182285546127621197 + wwv_flow_api.g_id_offset,
  p_column_id => 182285460198621190 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 1,
  p_lov_disp_value => 'Y',
  p_lov_return_value => 'Y');

end;
/
begin

wwv_flow_hint.create_lov_data_priv(
  p_id => 182285606655621197 + wwv_flow_api.g_id_offset,
  p_column_id => 182285460198621190 + wwv_flow_api.g_id_offset,
  p_lov_disp_sequence  => 2,
  p_lov_disp_value => 'N',
  p_lov_return_value => 'N');

end;
/
commit;
begin 
execute immediate 'alter session set nls_numeric_characters='''||wwv_flow_api.g_nls_numeric_chars||'''';
end;
/
set verify on
set feedback on
prompt  ...done
