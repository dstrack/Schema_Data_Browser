set define '&' verify off feed off serveroutput on size unlimited

prompt Installing Relational Data Browser App
prompt ======================================
accept WORKSPACE_NAME CHAR prompt "Enter the apex workspace name "
accept SCHEMA_NAME CHAR prompt "Enter the application schema name "
accept APPLICATION_ID CHAR prompt "Enter the application id " DEFAULT 1003

declare
	l_workspace_id number;
	l_application_id number := &APPLICATION_ID.;
begin
	l_workspace_id := apex_util.find_security_group_id (p_workspace =>'&WORKSPACE_NAME.');
	apex_util.set_security_group_id (p_security_group_id => l_workspace_id);

	apex_application_install.set_workspace_id( l_workspace_id );
	apex_application_install.set_application_id( l_application_id );
	apex_application_install.generate_offset;
	apex_application_install.set_schema( '&SCHEMA_NAME.' );
	apex_application_install.set_application_name( 'Schema_Data_Browser' );
	apex_application_install.set_application_alias( 'SCHEMA_DATA_BROWSER' );
end;
/

@f2000.sql

declare
	l_workspace_id number;
	l_application_id number := &APPLICATION_ID.;
begin
	l_workspace_id := apex_util.find_security_group_id (p_workspace =>'&WORKSPACE_NAME.');
	apex_util.set_security_group_id (p_security_group_id => l_workspace_id);

	dbms_output.put_line('seed and publish translation : de');
	apex_util.set_security_group_id( l_workspace_id );
	apex_lang.seed_translations(
        p_application_id => l_application_id,
        p_language => 'de' );
	apex_lang.publish_application(
        p_application_id => l_application_id,
        p_language => 'de' );
    commit;
	apex_util.cache_purge_by_application(p_application => l_application_id);
end;
/

exit
