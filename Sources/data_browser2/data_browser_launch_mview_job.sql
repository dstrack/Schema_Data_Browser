declare
	v_sql USER_SCHEDULER_JOBS.JOB_ACTION%TYPE;
begin
    v_sql :=
    'begin' || chr(10)
    || 'data_browser_jobs.Refresh_MViews(p_context=>0);' || chr(10)
    || 'data_browser_jobs.Refresh_ChangeLog_Job(p_context=>0);' || chr(10) 
    || 'end;';
    dbms_scheduler.create_job(
        job_name => 'DBROW_INIT_MVIEWS',
        job_type => 'PLSQL_BLOCK',
        job_action => v_Sql,
        comments => 'Refresh snapshots for data browser application',
        enabled => true 
    );
	COMMIT;
end;
/
