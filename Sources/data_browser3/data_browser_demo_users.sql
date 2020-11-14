declare
	v_Count	PLS_INTEGER;
begin
    select count(*) 
    into v_count
    from APEX_APPLICATION_BUILD_OPTIONS
    where APPLICATION_ID = APEX_APPLICATION.G_FLOW_ID
    and BUILD_OPTION_NAME = 'Demo Mode' 
    and BUILD_OPTION_STATUS = 'Include';
	if v_Count = 0 then 
		return;
	end if;
	data_browser_auth.Add_Developers;
	data_browser_auth.Add_User(
		p_Username => 'Demo',
		p_Password => 'Demo/2945',
		p_User_level => 1,
		p_Password_Reset => 'N'
	);
	data_browser_auth.Add_User(
		p_Username => 'Guest',
		p_Password => 'Guess/2945',
		p_User_level => 6,
		p_Password_Reset => 'N'
	);
end;
/
