set define '&' verify off feed off serveroutput on size unlimited
prompt Installing Data Browser App from Strack Software Development 
prompt ============================================================
@~/projekte/strack_software/strack-software-delete-check-plugin/delete_check_plsql_code.sql
@~/projekte/strack_software/strack-software-upload-to-collection-plugin/upload_to_collection_plsql_code.sql
@~/Projekte/strack_software/strack-software-unzip-parallel-plugin/as_zip.sql
@~/projekte/strack_software/strack-software-unzip-parallel-plugin/unzip_parallel.sql

@@data_browser1/data_browser_conf_tables.sql
@@data_browser1/data_browser_conf_upgrade.sql
@@data_browser1/data_browser_specs.sql
@@data_browser1/numbers_utl.sql
@@data_browser1/data_browser_conf.sql
@@data_browser1/data_browser_jobs.sql
@@data_browser1/data_browser_pattern.sql
@@change_log/change_log_conf_table.sql
@@change_log/changelog_conf.sql
@@change_log/user_namespaces_table.sql
@@change_log/custom_changelog_tables.sql
@@change_log/custom_changelog.sql
@@change_log/mvbase_unique_keys.sql
@@change_log/mvbase_alter_uniquekeys.sql
@@change_log/mvbase_views.sql
@@change_log/custom_changelog_gen_head.sql
@@change_log/custom_changelog_gen_body.sql
@@data_browser2/app_protocol_table.sql
@@data_browser1/data_browser_pref_tables.sql
@@data_browser1/data_browser_pipes.sql
@@data_browser1/data_browser_views.sql
@@data_browser1/data_browser_trees.sql
@@data_browser1/data_browser_header.sql
@@data_browser1/data_browser_edit_functions.sql
@@data_browser1/data_browser_edit.sql
@@data_browser1/data_browser_joins.sql
@@data_browser1/data_browser_select_functions.sql
@@data_browser1/data_browser_select.sql
@@data_browser1/data_browser_utl_wrap.sql
@@data_browser1/data_browser_utl_views.sql
@@data_browser1/data_browser_blobs.sql
@@data_browser1/data_browser_ui_defaults.sql
@@data_browser1/data_browser_doc_preview.sql
@@data_browser2/data_browser_ddl.sql
@@data_browser2/data_browser_checks_table.sql
@@data_browser2/data_browser_check.sql

@@data_browser3/app_users_tables.sql
@@data_browser3/data_browser_auth.sql
@@data_browser3/data_browser_login.sql
@@data_browser3/import_utl_tables.sql
@@data_browser3/import_utl_head.sql
@@data_browser3/import_utl_body.sql
@@data_browser3/data_browser_reporter.sql

@@data_browser3/schema_diagramme.sql
@@data_browser3/database_ER_diagramm_tables.sql
@@data_browser3/Object_Dependencies_Export.sql
@@data_browser3/data_browser_diagram_pipes.sql
@@data_browser3/data_browser_diagram_utl.sql
@@data_browser3/springy_diagram_utl.sql

set verify on feed on serveroutput on size unlimited

@@data_browser2/data_browser_inst_defaults.sql
@@data_browser2/data_browser_install_sup_obj.sql
@@data_browser2/data_browser_inst_cleanup.sql
@@data_browser2/data_browser_launch_mview_job.sql

exec data_browser_conf.Set_App_Library_Version(p_Application_ID => 2000);
set verify on feed on serveroutput on size unlimited
