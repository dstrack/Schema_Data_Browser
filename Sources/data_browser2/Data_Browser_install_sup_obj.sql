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
	v_count NUMBER;
	v_count2 NUMBER;
	v_stat VARCHAR2(32767);
	v_apex_schema		VARCHAR2(100);
begin
	SELECT table_owner INTO v_apex_schema
	FROM all_synonyms
	WHERE synonym_name = 'APEX'
	and owner = 'PUBLIC';

	SELECT COUNT(*) INTO v_count
	FROM ALL_OBJECTS WHERE OBJECT_NAME = 'WWV_FLOW_INSTALL_WIZARD' AND OBJECT_TYPE = 'PACKAGE'
	;
	
	SELECT COUNT(*) INTO v_count2
	from ALL_OBJECTS 
	where object_name = 'DATA_BROWSER_INSTALL_SUP_OBJ' 
	and object_type = 'PROCEDURE'
	and STATUS = 'VALID'
	and OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
	;
	
	if v_count > 0 and v_count2 = 0 then 
		v_stat := 'CREATE OR REPLACE SYNONYM WWV_FLOW_INSTALL_WIZARD FOR ' || v_apex_schema || '.WWV_FLOW_INSTALL_WIZARD';
		EXECUTE IMMEDIATE v_Stat;
	
		v_stat := q'[
CREATE OR REPLACE PROCEDURE Data_Browser_Install_Sup_Obj (
	p_App_ID NUMBER DEFAULT NV('APP_ID'),
	p_Dest_Schema VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
)
AUTHID DEFINER
is
	v_Install_ID APEX_APPLICATION_SUPP_OBJECTS.SUPPORTING_OBJECT_ID%TYPE;
	v_workspace_id 		NUMBER;
	v_Workspace_Name 	APEX_APPLICATIONS.WORKSPACE%TYPE;
begin 
	select workspace into v_Workspace_Name
	from APEX_APPLICATIONS
	where application_id = p_App_ID;

    select SUPPORTING_OBJECT_ID into v_Install_ID 
    from APEX_APPLICATION_SUPP_OBJECTS 
    where application_id = p_App_ID;

	wwv_flow_install_wizard.g_cmd_line_install := true; -- produce output in USER_SCHEDULER_JOB_LOG and USER_SCHEDULER_JOB_RUN_DETAILS
	v_workspace_id := apex_util.find_security_group_id (p_workspace => v_Workspace_Name);
	apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
	wwv_flow_install_wizard.install (
		p_flow_id     => p_App_ID,
		p_install_id  => v_Install_ID,
		p_schema      => p_Dest_Schema
	);
end Data_Browser_Install_Sup_Obj;
]';
		EXECUTE IMMEDIATE v_Stat;

		v_stat := q'[
CREATE OR REPLACE PROCEDURE Data_Browser_deInstall_Sup_Obj (
	p_App_ID NUMBER DEFAULT NV('APP_ID'),
	p_Dest_Schema VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
)
AUTHID DEFINER
is
	v_Install_ID APEX_APPLICATION_SUPP_OBJECTS.SUPPORTING_OBJECT_ID%TYPE;
	v_workspace_id 		NUMBER;
	v_Workspace_Name 	APEX_APPLICATIONS.WORKSPACE%TYPE;
begin 
	select workspace into v_Workspace_Name
	from APEX_APPLICATIONS
	where application_id = p_App_ID;

    select SUPPORTING_OBJECT_ID into v_Install_ID 
    from APEX_APPLICATION_SUPP_OBJECTS 
    where application_id = p_App_ID;

	wwv_flow_install_wizard.g_cmd_line_install := true; -- produce output in USER_SCHEDULER_JOB_LOG and USER_SCHEDULER_JOB_RUN_DETAILS
	v_workspace_id := apex_util.find_security_group_id (p_workspace => v_Workspace_Name);
	apex_util.set_security_group_id (p_security_group_id => v_workspace_id);
	wwv_flow_install_wizard.deinstall (
		p_flow_id     => p_App_ID,
		p_install_id  => v_Install_ID,
		p_schema      => p_Dest_Schema
	);
end Data_Browser_deInstall_Sup_Obj;
]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/
show errors
