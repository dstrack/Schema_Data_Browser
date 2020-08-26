begin
    data_browser_conf.Save_Config_Defaults;
    data_browser_pattern.Save_Config_Defaults;
    custom_changelog.Save_Config_Defaults;
end;
/

begin
    data_browser_conf.Set_App_Library_Version(APEX_APPLICATION.G_FLOW_ID );
end;
/
begin
    data_browser_utl.Start_Trial_Modus;
end;
/
