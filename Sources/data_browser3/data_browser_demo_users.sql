declare
	v_Count	PLS_INTEGER;
	v_workspace VARCHAR2(128);
	v_APP_ID NUMBER;
begin
	v_APP_ID := NVL(APEX_APPLICATION.G_FLOW_ID, 2000);

	SELECT WORKSPACE
	INTO v_workspace
	FROM APEX_APPLICATIONS
	WHERE APPLICATION_ID = v_APP_ID;
	apex_util.set_workspace (p_workspace => v_workspace );
$IF data_browser_specs.g_use_custom_ctx $THEN
	set_custom_ctx.set_current_workspace(p_Workspace_Name=>SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), p_Client_Id=>NULL);
	set_custom_ctx.set_current_user(p_User_Name=>SYS_CONTEXT('USERENV', 'SESSION_USER'), p_Client_Id=>NULL);
$END
	DBMS_OUTPUT.PUT_LINE('-- adding developers for App-ID ' || v_APP_ID || ' ws : ' || v_workspace);
	data_browser_auth.Add_Developers;

    select count(*) 
    into v_count
    from APEX_APPLICATION_BUILD_OPTIONS
    where APPLICATION_ID = v_APP_ID
    and BUILD_OPTION_NAME = 'Demo Mode' 
    and BUILD_OPTION_STATUS = 'Include';
	if v_Count = 0 then 
		return;
	else
		DBMS_OUTPUT.PUT_LINE('-- adding demo users for App-ID ' || v_APP_ID || ' ws : ' || v_workspace);
		data_browser_auth.Add_User(
			p_Username => 'Demo',
			p_Password => 'Demo/2945',
			p_User_level => 1,
			p_Password_Reset => 'N',
			p_Email_Validated => 'Y'
		);
		data_browser_auth.Add_User(
			p_Username => 'Guest',
			p_Password => 'Guess/2945',
			p_User_level => 6,
			p_Password_Reset => 'N',
			p_Email_Validated => 'Y'
		);
	end if;
end;
/
