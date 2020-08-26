set serveroutput on size unlimited
set verify off feedback on define on

prompt Install Application "Schema Data Browser" 
prompt ============================================
accept WORKSPACE_NAME CHAR prompt "Enter apex workspace name : "
accept SCHEMA_NAME CHAR    prompt "Enter schema name         : "
accept APPLICATION_ID CHAR prompt "Enter application ID      : "

prompt Installing Apex Application "Schema Data Browser" 
EXEC data_browser_schema.install_data_browser_app ('&WORKSPACE_NAME.', '&SCHEMA_NAME.', '&APPLICATION_ID.');

@f2000.sql

set verify off feedback on define on
prompt Installing translations for schema data browser
EXEC data_browser_schema.install_data_browser_publish ('&WORKSPACE_NAME.', '&APPLICATION_ID.');

prompt Installation finished
exit

