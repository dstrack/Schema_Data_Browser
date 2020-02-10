# README for the Schema Data Browser  
Application to analyse your DB and APEX Applications

## Demo
	demo with an custom account
	https://strack-software.oracleapexservices.com/apex/f?p=2000:1

	demo with an APEX account
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

3. Installation OF Sys components for schema management (optional)
	
-- In a shared server environment
	If you use the app with 'APEX Authorization' in a schema, this step may be omitted.

-- in the Oracle ATP cloud
	cd Schema_Browser_Release 
	sqlplus /nolog 
	
	connect admin 

	@custom_keys.sql					-- Protected storage for crypto keys and hash salt
	@custom_ctx.sql						-- Custom context for special session parameters.
	@data_browser_schema_sys_package.sql
	@data_browser_sys_add_schema.sql	-- The script can be executed repeatedly to prepare additional schemas for use. 
										-- The installation of Supporting Objects must then be done 
										-- manually in Apex Workspace for these schemas.
	exit
	
-- in an on premise DB
	cd Schema_Browser_Release 
	sqlplus /nolog 
	
	connect sys as sysdba 

	@custom_keys.sql
	@custom_ctx.sql
	@data_browser_schema_sys_package.sql
	@data_browser_sys_add_schema.sql -- the first schema_name in the Oracle ATP cloud is the workspace_name.
									 -- Later, more can be added by button on the homepage.
	exit

## Import and install the APEX Application.

1. Use of Custom Authorization
	The installer checks during installation whether the additionally required authorizations 
	have been granted, which were set up in step 3.	
	
1.1. Upload file **Data_Browser_Custom_App.sql**.
	Supporting Objects : Yes 
	
	The installation takes about 2 minutes locally, Oracle Cloud about 7 minutes.

1.2. At the first start, there will be a page in which your admin name, password and e-mail address will be queried.
	The most convenient way is to reuse the data stored in the browser as program admin data.
	The password is stored as a salted hash value in the App_Users table.
	Other authorized users are entered in the App_Users table.
	The other fields can remain empty for now.

2. Verwendung der APEX Authorisation
	In shared server environments where no additional permissions are available,
	this functional reduced version must be used.

2.1. Upload file **Data_Browser_Apex_App.sql**.
	Supporting Objects : Yes 
	
	The installation takes about 2 minutes locally, Oracle Cloud about 7 minutes.

3. Trial period / license
	Without a license, the program runs for 3 months in full functionality and then switches to a read only mode.
	The remaining probationary period will be displayed on the homepage at the bottom.
	If you like the program, you can order a license from Strack.Software@t-online.de before the trial expires.

## Configuration
1. Settings menu
	If the homepage is now logged in, it is recommended using the Settings menu
	Enter global rules for naming conventions as search engines in the appropriate cells.
	Often lists of LIKE patterns are available as default values. The fields have help texts which inform you about the meaning.
	Saving the settings triggers jobs that update a data dictionary of the app.
	Then select a typical spreadsheet and see if the rules grab the expected fields.
	The app hides its own tables by default.

2. Manage schema
	The Manage Schema page manages the always-visible columns for labels, navigation links, and LOVs.
	With the definition of field lists of natural unique keys, the automatic key lookup for imports
	but also the uniqueness of all displayed labels guaranteed.

3. Client App
	In some projects, the app can be combined as a backstage for data maintenance and a hard-coded Apex app as a specialized application.
	A client app can be listed in the homepage if this is accessible via the access control settings
	is selected as a customer application. The app can be selected if it is previously installed in the same scheme.

4. Data Reporter App
	After installing the Data Reporter App, the Data Browser Supporting Objects must be reinstalled,
	if a connection is to be established via the Data_Browser_Reporter package.

## Upgrading of the APEX Application and 'Supporting Objects'
	If you are installing a new version, replace the older installation and 
	run the installation with the Supporting Objects option.

## Deinstallation
	When you uninstall the application and Supporting Objects, some configuration tables, packages, and functions are preserved.
	These objects support the functionality of generated triggers and get your settings for upgrading the installation.	

