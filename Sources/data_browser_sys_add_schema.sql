----------------------------------------------------------------------
set define '&' verify off feed on 
set scan on
set linesize 32767
accept OWNER CHAR prompt "Enter the application schema name : "
accept PASSWORD CHAR prompt "Enter the application schema password : "
accept WORKSPACE CHAR prompt "Enter the apex workspace name : "

exec data_browser_schema.Add_Schema('&OWNER.','&PASSWORD.');
exec data_browser_schema.Add_Apex_Workspace_Schema('&OWNER.','&WORKSPACE.');
