# README for the Schema Data Browser  
Application to analyse your DB and APEX Applications

## Demo
	https://apex.oracle.com/pls/apex/f?p=48950:1

## Compatibility:
	at least Application Express 19.1
	at least Oracle Database Express Edition 18c

	The use of the web browser Firefox and Chrome is recommended.
	Safari is a bit slower when displaying the dynamic diagrams.

## Installation:
1. Encoding setting for sqlplus under Windows / DOS

	set NLS_LANG=GERMAN_GERMANY.AL32UTF8 
	
	chcp 65001

2. SQLDEVELOPER Settings

	Environment / Encoding = UTF-8
	Database / Worksheet / Standardpath for Scripts
	
	...Schema_Data_Browser/Sources 
	
3. Installation of SYS components for schema management (optional)
	
-- In a shared server environment
	If you have to use the app with 'APEX Authorization', this step is omitted.

-- in the Oracle ATP cloud
	cd Schema_Data_Browser/Sources 
	sqlplus /nolog 
	
	connect admin 

	@sys_install/custom_keys.sql					-- Protected storage for crypto keys and hash salt
	@sys_install/custom_ctx.sql						-- Custom context for special session parameters.
	@sys_install/data_browser_schema_sys_package.sql
	exec data_browser_schema.Add_Apex_Workspace_Schema(p_Schema_Name=>'&WORKSPACE.', p_Apex_Workspace_Name=>'&WORKSPACE.');
	-- Use the Oracle ATP Cloud Workspace Name.

	-- to prepare additional schemas execute the following steps
	@sys_install/data_browser_sys_add_schema.sql
	exit
	
	sqlplus /nolog 
	-- connect to the new schema 
	-- installation of the Supporting Objects
	@sys_install/data_browser_install_modules	
	exit
	
-- in an on premise DB
	cd Schema_Data_Browser/Sources 
	sqlplus /nolog 
	
	connect sys as sysdba 

	@sys_install/custom_keys.sql
	@sys_install/custom_ctx.sql
	@sys_install/data_browser_schema_sys_package.sql
	@sys_install/data_browser_sys_add_schema.sql 
	-- the first schema_name in the Oracle ATP cloud is the workspace_name.
	-- Later, more can be added by button on the homepage.
	exit

## Import and install the APEX Application.

1. Use of Custom Authorization
	The installer checks during installation whether the additionally required authorizations 
	have been granted, which were set up in step 3.	
	
1.1. Upload file **Data_Browser_Custom_App.sql**.
	
	Install Supporting Objects : Yes 
	
	The installation takes about 2 minutes locally, Oracle Cloud about 3 minutes.

1.2. At the first start, there will be a page in which your admin name, password and e-mail address will be queried.
	The most convenient way is to reuse the data stored in the browser as program admin credentials.
	The password is stored as a salted hash value in the App_Users table.
	Other authorized users can be entered in the App_Users table in the data browser page.
	The other fields can remain empty for now.

2. When using APEX Authorisation
	In shared server environments where no additional permissions are available,
	this functional reduced version must be used.

2.1. Upload file **Data_Browser_Apex_App.sql**.
	
	Install Supporting Objects : Yes 
	
	The installation takes about 2 minutes locally, in the Oracle Cloud about 3 minutes.

3. Trial period / license
	This app is available to everyone completely free of charge for personal, non-commercial use.
	Use the following settings under 'Software Licence' in the First Run Page or under the Settings / Edit Settings menu.
	
	App License Owner: Free for Developer
	
	App License Number: DB84-1870-7987-7003-4222

	Without a license, the program runs for 2 months in full functionality and then switches to a read only mode.
	The remaining probationary period will be displayed on the homepage at the bottom.
	If you like the program, you can order a license for a small fee by sending a mail to Strack.Software@t-online.de before the trial expires.

## Configuration
1. Settings menu

	After login as an APEX Admin or Developer you can use the the Settings menu to configure your schema.
	Enter global rules for naming conventions as search pattern in the appropriate cells.
	Often lists of LIKE patterns are available as default values. The fields have help texts which inform you about the meaning.
	Saving the settings triggers jobs that update a data dictionary of the app.
	The app hides its own tables by default.

2. Manage schema

	The Manage Schema page manages the always-visible displayed columns for labels, navigation links, and LOVs.
	With the definition of field lists for natural unique keys, the automatic key lookup for imports
	but also the uniqueness of all displayed labels can be guaranteed.

3. Client App

	In some projects, the app can be combined as a backstage for data maintenance and a convertional Apex app as a specialized application.
	A client app can be listed in the homepage. In the menu Settings / Edit Settings, region 'Access Control' you can
	select as a customer application. The app can be selected if it is previously installed in the same scheme.

4. Data Reporter App

	After installing the Data Reporter App, the Data Browser Supporting Objects must be reinstalled,
	if a connection is to be established via the Data_Browser_Reporter package.

## Upgrading of the APEX Application and 'Supporting Objects'
	If you are installing a new version, replace the older installation and 
	run the installation with the Supporting Objects option.

## Deinstallation
	When you uninstall the application and Supporting Objects, some configuration tables, packages, and functions are preserved.
	These objects support the functionality of generated triggers and get your settings for upgrading the installation.	

