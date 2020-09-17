set serveroutput on size unlimited
set verify off feedback on define on

prompt Install Application "Data Browser" 
prompt ============================================

EXEC data_browser_schema.install_data_browser_app (p_workspace => 'STRACK_DEV', p_schema => 'STRACK_DEV', p_app_id => 2000, p_app_alias =>'DATA_BROWSER_DEMO');
@f2000.sql
set verify off feedback on define on
EXEC data_browser_schema.install_data_browser_publish (p_workspace => 'STRACK_DEV', p_app_id => 2000);


prompt Installation finished
exit

