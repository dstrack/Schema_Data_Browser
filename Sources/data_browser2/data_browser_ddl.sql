/*
Copyright 2019 Dirk Strack, Strack Software Development

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
 
CREATE OR REPLACE PACKAGE data_browser_ddl 
AUTHID CURRENT_USER
IS
	g_debug 				CONSTANT BOOLEAN 	   := true;
	c_Primary_Key_Col       CONSTANT VARCHAR2(128) := 'ID';
	c_Row_Version_Col       CONSTANT VARCHAR2(128) := 'ROW_VERSION_NUMBER';
	c_Unique_Desc_Col       CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Description')); -- Bezeichnung
	c_Protected_Col			CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Protected')); -- Geschuetzt;
	c_Active_Col			CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Active'));  -- Aktiv;
	c_Ordering_Col			CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Line_No')); -- Zeilen_Nr;
    c_Notes_Base_Name		CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Notes')); -- Notizen;
	c_File_Base_Name		CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('File'));	-- Datei 
	c_Folder_Base_Name		CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Folder'));	-- Ordner
	c_Base_Name				CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Name'));	-- Name
	c_Content_Name			CONSTANT VARCHAR2(128) := UPPER(apex_lang.lang('Content'));	-- Inhalt
	c_File_Content_Col		CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_File_Base_Name, c_Content_Name);
	c_File_Name_Col			CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_File_Base_Name, c_Base_Name);
	c_File_Protected_Col	CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_File_Base_Name, c_Protected_Col);
	c_File_Mimetype_Col		CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_File_Base_Name, 'MIME_TYPE');
	c_File_Date_Col		    CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_File_Base_Name, 'LASTUPD');
	c_Folder_Parent_Col		CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_Folder_Base_Name, 'PARENT_ID');
	c_Folder_Name_Col		CONSTANT VARCHAR2(128) := data_browser_conf.Compose_Column_Name(c_Folder_Base_Name, c_Base_Name);
	c_MView_Refresh_Delay	CONSTANT NUMBER := 0.0;
	PROCEDURE Comment_on_Table_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Comment_Text VARCHAR2 
	);

	PROCEDURE Rename_Table_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2,
		p_New_Column_Name VARCHAR2 
	);

    FUNCTION  Create_Table (
        p_Table_Name    	VARCHAR2,
    	p_Parent_Table 		VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Ref_Type VARCHAR2 DEFAULT 'NO',	-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
        p_Add_WorkspaceID   VARCHAR2 DEFAULT 'NO',
        p_Add_Modify_Date   VARCHAR2 DEFAULT 'YES',
        p_Add_Modify_User   VARCHAR2 DEFAULT 'YES',
        p_Add_Create_Date   VARCHAR2 DEFAULT 'YES',
        p_Add_Create_User   VARCHAR2 DEFAULT 'YES',
        p_Add_File  	    VARCHAR2 DEFAULT 'NO',  -- NO, BINARY, TEXT, HTML
        p_Add_Description   VARCHAR2 DEFAULT 'NO',
        p_Add_Ordering	  	VARCHAR2 DEFAULT 'NO',
        p_Add_Aktive 		VARCHAR2 DEFAULT 'NO',
        p_Add_Locked 		VARCHAR2 DEFAULT 'NO'
    ) RETURN VARCHAR2;		-- Primary Key Constraint_name
    PROCEDURE  Drop_Table (
        p_Table_Name    	VARCHAR2
	);
    FUNCTION Validate_Column_Name (
    	p_Column_Name VARCHAR2
    ) RETURN VARCHAR2 ;
    
	FUNCTION Foreign_Key_Constraint (
        p_Table_Name  VARCHAR2,
		p_Parent_Table VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_Parent_Ref_Type VARCHAR2,	-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Constraint_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2;

    PROCEDURE  Add_Column (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2,
    	p_Reference_Table 	VARCHAR2 DEFAULT NULL,	-- For target of type reference; Parent View or Table name.
    	p_Reference_Type 	VARCHAR2 DEFAULT 'NULLABLE',	-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Reference_Default_ID 	VARCHAR2 DEFAULT NULL,	-- For target of type reference; default reference
    	p_Data_Type 		VARCHAR2 DEFAULT 'CHAR',	-- INTEGER, FLOAT, CURRENCY, CHAR, TEXT, HTML, FILE, DATE, BOOLEAN, REFERENCE, EXPRESSION, ORDINAL, ACTIVE, PROTECTED
        p_Char_Length 		NUMBER DEFAULT 128,			-- For columns of type CHAR range 1 - 32767
    	p_Default 			VARCHAR2 DEFAULT NULL,
    	p_Expression		VARCHAR2 DEFAULT NULL,
    	p_Required			VARCHAR2 DEFAULT 'NO', 		-- YES, NO
    	p_Unique			VARCHAR2 DEFAULT 'NO' 		-- YES, NO, COMPOSED
    );
    
    PROCEDURE  Drop_Column (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2
    );
    
    PROCEDURE  Load_Column_Constraints (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2,
		p_CONSTRAINT_NAME   OUT VARCHAR2,
		p_U_CONSTRAINT_NAME OUT VARCHAR2,
		p_R_CONSTRAINT_NAME OUT VARCHAR2,
    	p_Reference_Table 	OUT VARCHAR2,		-- For target of type reference; Parent View or Table name.
    	p_Reference_Type 	OUT VARCHAR2,		-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Reference_Default_ID 	OUT VARCHAR2,	-- For target of type reference; default reference
		p_Check_Condition	OUT VARCHAR2,
    	p_CHECK_UNIQUE		OUT VARCHAR2,  		-- N,Y
    	p_Required			OUT VARCHAR2, 		-- YES, NO
    	p_Data_Type 		OUT VARCHAR2,		-- INTEGER, FLOAT, CURRENCY, CHAR, TEXT, HTML, FILE, DATE, BOOLEAN, REFERENCE
        p_Char_Length 		OUT VARCHAR2,		-- For columns of type CHAR range 1 - 32767
    	p_Data_Default 		OUT VARCHAR2,
		p_Is_Simple_IN_List OUT VARCHAR2,
		p_Constraint_Options OUT VARCHAR2
    );
    
    PROCEDURE Generate_Column_Constraints (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2,
		p_CONSTRAINT_NAME   IN OUT VARCHAR2,
		p_U_CONSTRAINT_NAME IN OUT VARCHAR2,
		p_R_CONSTRAINT_NAME IN OUT VARCHAR2,
    	p_Reference_Table 	IN VARCHAR2,	    -- For target of type reference; Parent View or Table name.
    	p_Reference_Type 	IN VARCHAR2,		-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Reference_Default_ID IN VARCHAR2,		-- For target of type reference; default reference
		p_Check_Const_Options IN VARCHAR2,
		p_Check_Condition	IN VARCHAR2,
    	p_Check_Unique		IN VARCHAR2,  		-- N,Y
    	p_Check_Unique_Old	IN VARCHAR2,  		-- N,Y
    	p_Check_Unique_Valid OUT VARCHAR2,  	-- YES, NO
    	p_Required			IN VARCHAR2, 		-- YES, NO
     	p_Required_Old  	IN VARCHAR2, 		-- YES, NO
     	p_Required_Valid	OUT VARCHAR2, 		-- YES, NO
       	p_Data_Type 		IN VARCHAR2,	    -- INTEGER, FLOAT, CURRENCY, CHAR, TEXT, HTML, FILE, DATE, BOOLEAN, REFERENCE
        p_Char_Length 		IN VARCHAR2,		-- For columns of type CHAR range 1 - 32767
        p_Char_Length_Old	IN VARCHAR2,
    	p_Data_Default 		IN OUT VARCHAR2,
    	p_Data_Default_Old  IN OUT VARCHAR2,
		p_Is_Simple_IN_List IN VARCHAR2,
		p_Undo_Check_Stat   IN OUT VARCHAR2,
		p_Undo_Unique_Stat  IN OUT VARCHAR2,
		p_Undo_Ref_Stat     IN OUT VARCHAR2,
    	p_STATEMENT         OUT VARCHAR2,
    	p_Start_Step 		OUT BINARY_INTEGER
    );

    PROCEDURE Execute_Column_Constraints (
        p_Table_Name    	IN VARCHAR2,
    	p_STATEMENT         IN OUT VARCHAR2,
		p_Undo_Check_Stat   IN VARCHAR2,
		p_Undo_Unique_Stat  IN VARCHAR2,
		p_Undo_Ref_Stat     IN VARCHAR2,
    	p_Start_Step 		IN BINARY_INTEGER
    );

    PROCEDURE Tables_Add_Serial_Keys(
        p_Table_Names IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE Tables_Add_Natural_Keys(
        p_Table_Names IN VARCHAR2
    );

    PROCEDURE Columns_Add_Required_Constraints(
        p_Column_Names IN VARCHAR2
    );

	FUNCTION FN_Query_Uniqueness (
		p_Table_Name IN VARCHAR2,
		p_Column_Names IN VARCHAR2
	) RETURN VARCHAR2; -- YES / NO / N/A

	PROCEDURE Check_Unique_Constraints (p_Selected_Tables VARCHAR2);
	
	FUNCTION FN_Query_Required (
		p_Table_Name IN VARCHAR2,
		p_Column_Name IN VARCHAR2
	) RETURN VARCHAR2; -- YES / NO / N/A

	PROCEDURE Check_Required_Constraints (p_Selected_Tables VARCHAR2);

end data_browser_ddl;
/
show errors

CREATE OR REPLACE PACKAGE BODY data_browser_ddl IS

    PROCEDURE Run_Stat (
        p_Statement     IN CLOB,
        p_Silent        IN NUMBER DEFAULT 0,
        p_Delimiter     IN VARCHAR2 DEFAULT ';'
    )
    IS
    	v_Delimiter VARCHAR2(10);
    BEGIN
    	v_Delimiter := CASE WHEN p_Delimiter = '/' THEN CHR(10) || p_Delimiter || CHR(10) ELSE p_Delimiter END;
        if p_Silent = 0 then
            DBMS_OUTPUT.PUT_LINE(SUBSTR(p_Statement, 1, 32760) || v_Delimiter);
        end if;
		$IF data_browser_ddl.g_debug $THEN
			apex_debug.info(p_message => 'data_browser_ddl.Run_Stat : %s',
				p0 => p_Statement || v_Delimiter,
				p_max_length => 3500
			);
		$END
		if changelog_conf.g_debug = 0 or p_Silent <> 0 then
            EXECUTE IMMEDIATE p_Statement;
			INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing DDL', SUBSTR(p_Statement, 1, 4000));
			COMMIT;
        end if;
    EXCEPTION
    WHEN OTHERS THEN
    	if p_Silent <> 0 then
            DBMS_OUTPUT.PUT_LINE(SUBSTR(p_Statement, 1, 32760) || v_Delimiter);
        	DBMS_OUTPUT.PUT_LINE('-- SQL Error :' || SQLCODE || ' ' || SQLERRM);
        end if;
        RAISE;
    END Run_Stat;

	FUNCTION fn_Default_Clause RETURN VARCHAR2 
	is 
	begin 
		return case when changelog_conf.Get_Use_On_Null = 'YES' then ' DEFAULT ON NULL ' else ' DEFAULT ' end;
	end fn_Default_Clause;

	FUNCTION Comment_on_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2,
		p_Comment_Text VARCHAR2 
	) RETURN VARCHAR2
	is
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
	begin
		SELECT TABLE_NAME, TABLE_OWNER 
		INTO v_Table_Name, v_Table_Owner
		FROM MVDATA_BROWSER_VIEWS
		WHERE VIEW_NAME = p_Table_Name;

		return 'COMMENT ON COLUMN '
		|| dbms_assert.enquote_name(p_Table_Name) || '.'
		|| dbms_assert.enquote_name(p_Column_Name) || ' IS '
		|| data_browser_conf.enquote_literal(p_Comment_Text);
	end Comment_on_Column;

	FUNCTION Comment_on_Table (
        p_Table_Name  VARCHAR2,
		p_Comment_Text VARCHAR2 
	) RETURN VARCHAR2
	is
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
	begin
		SELECT TABLE_NAME, TABLE_OWNER 
		INTO v_Table_Name, v_Table_Owner
		FROM MVDATA_BROWSER_VIEWS
		WHERE VIEW_NAME = p_Table_Name;

		return 'COMMENT ON TABLE '
		|| dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) || ' IS '
		|| data_browser_conf.enquote_literal(p_Comment_Text);
	end Comment_on_Table;

    PROCEDURE Execute_DDL_Statemnt (
        p_Table_Name    	IN VARCHAR2,
    	p_Statement         IN VARCHAR2,
    	p_Start_Step 		IN BINARY_INTEGER
    )
    is
    begin
		EXECUTE IMMEDIATE p_Statement;
		INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing DDL', SUBSTR(p_Statement, 1, 4000));
		COMMIT;
		data_browser_jobs.Start_Refresh_Mviews_Job ( p_Start_Step => p_Start_Step, p_Delay_Seconds => c_MView_Refresh_Delay );
	end Execute_DDL_Statemnt;
	
	PROCEDURE Comment_on_Table_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Comment_Text VARCHAR2 
	) 
    is
        v_Stat                  VARCHAR2(32767);
    begin
		if p_Column_Name IS NOT NULL then 
			v_Stat := Comment_On_Column(
				p_Table_Name => p_Table_Name,
				p_Column_Name => p_Column_Name,
				p_Comment_Text => p_Comment_Text
			);
		else
			v_Stat := Comment_On_Table(
				p_Table_Name => p_Table_Name,
				p_Comment_Text => p_Comment_Text
			);
		end if;
		if v_Stat IS NOT NULL then 
			data_browser_conf.Touch_Configuration;
			data_browser_ddl.Execute_DDL_Statemnt (
				p_Table_Name        => p_Table_Name,
				p_STATEMENT         => v_Stat,
				p_Start_Step		=> data_browser_jobs.Get_Refresh_Start_Project
			);
		end if;
	end Comment_on_Table_Column;


	FUNCTION Rename_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2,
		p_New_Column_Name VARCHAR2 
	) RETURN VARCHAR2
	is
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
		v_Column_Name 			VARCHAR2(128);
	begin
		SELECT TABLE_NAME, TABLE_OWNER 
		INTO v_Table_Name, v_Table_Owner
		FROM MVDATA_BROWSER_VIEWS
		WHERE VIEW_NAME = p_Table_Name;

        v_Column_Name := UPPER(REPLACE(p_New_Column_Name, ' ', '_'));
		return 'ALTER TABLE '
		|| dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) || ' RENAME COLUMN  '
		|| dbms_assert.enquote_name(p_Column_Name) || ' TO '
		|| dbms_assert.enquote_name(v_Column_Name) ;
	end Rename_Column;



	PROCEDURE Rename_Table_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2,
		p_New_Column_Name VARCHAR2 
	) 
    is
        v_Column_Name 			VARCHAR2(128);
        v_Stat 					VARCHAR2(32767);
    begin
		v_Column_Name := data_browser_conf.Normalize_Umlaute(p_New_Column_Name);
        v_Column_Name := UPPER(REPLACE(v_Column_Name, ' ', '_'));
 		v_Stat := Rename_Column(
			p_Table_Name => p_Table_Name,
			p_Column_Name => p_Column_Name,
			p_New_Column_Name => v_Column_Name
		);
		if v_Stat IS NOT NULL then 
			data_browser_ddl.Execute_DDL_Statemnt (
				p_Table_Name        => p_Table_Name,
				p_STATEMENT         => v_Stat,
				p_Start_Step		=> data_browser_jobs.Get_Refresh_Start_Unique
			);
			data_browser_jobs.Refresh_After_DDL_Job ( p_Table_Name => p_Table_Name );
		end if;
	end Rename_Table_Column;

	FUNCTION Boolean_Column (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2,
		p_Default VARCHAR2 DEFAULT 'N' -- Y, N
	) RETURN VARCHAR2
	is
	begin
		return dbms_assert.enquote_name(p_Column_Name) || ' VARCHAR2(1)' || fn_Default_Clause
		|| dbms_assert.enquote_literal(NVL(SUBSTR(p_Default, 1, 1), 'N')) || ' NOT NULL CONSTRAINT '
		|| dbms_assert.enquote_name( 
			data_browser_conf.Compose_Column_Name(
			data_browser_conf.Compose_Table_Column_Name (p_Table_Name, 
			data_browser_conf.Normalize_Column_Name(p_Column_Name)), 'CK'))
		|| ' CHECK ('
		|| data_browser_conf.Enquote_Name_Required(p_Column_Name)
		|| ' IN (' || data_browser_conf.Get_Boolean_Yes_Value('CHAR', 'ENQUOTE') || ', ' 
		|| data_browser_conf.Get_Boolean_No_Value('CHAR', 'ENQUOTE') || '))';
	end Boolean_Column;

	FUNCTION Currency_Column (
		p_Column_Name VARCHAR2,
		p_Default VARCHAR2 DEFAULT 'N' -- Y, N
	) RETURN VARCHAR2
	is
	begin
		return dbms_assert.enquote_name(p_Column_Name) || ' NUMBER(16,2) ' || fn_Default_Clause || ' '
		|| NVL(p_Default, '0')
		|| ' NOT NULL';
	end Currency_Column;

	FUNCTION Virtual_Column (
		p_Column_Name VARCHAR2,
		p_Expression VARCHAR2 DEFAULT 'N' -- Y, N
	) RETURN VARCHAR2
	is
	begin
		return dbms_assert.enquote_name(p_Column_Name) || ' AS (' 
		|| p_Expression || ') VIRTUAL';
	end Virtual_Column;

	FUNCTION Index_Format_Column (
        p_Table_Name  VARCHAR2
	) RETURN VARCHAR2
	is
		v_Column_Name VARCHAR2(50) := changelog_conf.Get_ColumnIndexFormat;
	begin
		return dbms_assert.enquote_name(v_Column_Name)
		|| ' VARCHAR2(6) '
		|| fn_Default_Clause || dbms_assert.enquote_literal('IGNORE') || ' NOT NULL CONSTRAINT '
		|| dbms_assert.enquote_name( 
			data_browser_conf.Compose_Column_Name(
			data_browser_conf.Compose_Table_Column_Name (p_Table_Name, 
			data_browser_conf.Normalize_Column_Name(v_Column_Name)), 'CK'))
		|| ' CHECK ('
		|| data_browser_conf.Enquote_Name_Required(v_Column_Name)
		|| q'[ in ('BINARY','TEXT','IGNORE'))]';
	end Index_Format_Column;

	FUNCTION File_Columns (
        p_Table_Name  VARCHAR2,
		p_Column_Name VARCHAR2 DEFAULT NULL,
		p_Add_Locked VARCHAR2 DEFAULT 'N', -- Y, N
		p_Required VARCHAR2 DEFAULT 'N'   -- Y, N
	) RETURN VARCHAR2
	is
	begin
		return dbms_assert.enquote_name(data_browser_conf.Compose_Column_Name(p_Column_Name, c_File_Content_Col)) || ' BLOB, ' || chr(10)
		   	|| dbms_assert.enquote_name(data_browser_conf.Compose_Column_Name(p_Column_Name, c_File_Name_Col)) || ' VARCHAR2(512)' 
		   	|| case when p_Required IN ('Y', 'YES') then ' NOT NULL' end || ', ' || chr(10)
			|| dbms_assert.enquote_name(data_browser_conf.Compose_Column_Name(p_Column_Name, c_File_Mimetype_Col)) || ' VARCHAR2(512), ' || chr(10)
			|| dbms_assert.enquote_name(data_browser_conf.Compose_Column_Name(p_Column_Name, c_File_Date_Col)) || ' DATE, ' || chr(10)
			|| Index_Format_Column(p_Table_Name) 
			|| case when p_Add_Locked IN ('Y', 'YES') then
				', ' || chr(10) || 
				Boolean_Column(p_Table_Name, data_browser_conf.Compose_Column_Name(p_Column_Name, c_File_Protected_Col), 'N') 
			end;
	end File_Columns;

	FUNCTION Unique_Desc_Constraint (
        p_Table_Name  VARCHAR2,
		p_Unique_Desc_Column VARCHAR2,
		p_Parent_Key_Column VARCHAR2 DEFAULT NULL,
		p_Folder_Parent_Col VARCHAR2 DEFAULT NULL,
		p_Constraint_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
		v_Constraint_Name VARCHAR2(128);
		v_Count NUMBER;
		v_RunNo NUMBER;
	begin
		if p_Constraint_Name IS NULL then 
			v_Constraint_Name := 
				data_browser_conf.Compose_Column_Name (
					p_Table_Name, 'UN'
				);
			for v_RunNo in 1..9 loop
				SELECT COUNT(*) INTO v_Count
				FROM SYS.USER_CONSTRAINTS 
				WHERE CONSTRAINT_NAME = v_Constraint_Name||NULLIF(v_RunNo, 0);
				exit when v_Count = 0; 
			end loop;
			v_Constraint_Name := v_Constraint_Name || NULLIF(v_RunNo, 0);
		else 
			v_Constraint_Name := p_Constraint_Name;
		end if;
		return 'CONSTRAINT '
			|| dbms_assert.enquote_name(v_Constraint_Name)
			|| ' UNIQUE ('
			|| case when p_Parent_Key_Column IS NOT NULL then
					dbms_assert.enquote_name(p_Parent_Key_Column) || ', '
			end
			|| case when p_Folder_Parent_Col IS NOT NULL then
					dbms_assert.enquote_name(p_Folder_Parent_Col) || ', '
			end
			|| p_Unique_Desc_Column
			|| ') USING INDEX';
	end Unique_Desc_Constraint;

	FUNCTION Foreign_Key_Constraint (
        p_Table_Name  VARCHAR2,
		p_Parent_Table VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_Parent_Ref_Type VARCHAR2,	-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Constraint_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
		v_Constaint_Name VARCHAR2(128);
	begin
		v_Constaint_Name := NVL(p_Constraint_Name,
			data_browser_conf.Compose_Column_Name(
			data_browser_conf.Compose_Table_Column_Name (p_Table_Name,
			data_browser_conf.Normalize_Column_Name(p_Parent_Key_Column)), 'FK'));
		return 'CONSTRAINT '
		|| dbms_assert.enquote_name(v_Constaint_Name)
		|| ' FOREIGN KEY ( ' || dbms_assert.enquote_name(p_Parent_Key_Column) || ' )'
		|| ' REFERENCES ' || dbms_assert.enquote_name(p_Parent_Table)
		|| case when p_Parent_Ref_Type IN ('CONTAINER', 'OPTIONAL_CONTAINER') then ' ON DELETE CASCADE'
			when p_Parent_Ref_Type = 'NULLABLE' then ' ON DELETE SET NULL'
		end;
	end Foreign_Key_Constraint;

	FUNCTION Foreign_Key_Index (
        p_Table_Name  VARCHAR2,
		p_Parent_Table VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_Index_Name VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
		v_Count PLS_INTEGER;
		v_Index_Name 			VARCHAR2(128);
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
	begin
		v_Table_Name := UPPER(p_Table_Name);
		v_Table_Owner := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		v_Index_Name := NVL(p_Index_Name,
				data_browser_conf.Compose_Column_Name(
				data_browser_conf.Compose_Table_Column_Name (v_Table_Name,
				data_browser_conf.Normalize_Column_Name(p_Parent_Key_Column)), 'FKI'));
		SELECT COUNT(*) INTO v_Count
		FROM USER_IND_COLUMNS
		WHERE TABLE_NAME = v_Table_Name
		AND COLUMN_NAME = p_Parent_Key_Column
		AND COLUMN_POSITION = 1;
		if v_Count = 0 then 
			return 'CREATE INDEX '
			|| dbms_assert.enquote_name(v_Index_Name)
			|| ' ON ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) || '( ' || dbms_assert.enquote_name(p_Parent_Key_Column) || ' )'
			|| ' COMPRESS 1';
		else 
			return NULL;
		end if;
	end Foreign_Key_Index;

	FUNCTION Folder_Columns (
        p_Table_Name  VARCHAR2
	) RETURN VARCHAR2
	is
	begin
		return dbms_assert.enquote_name(c_Folder_Parent_Col) || ' NUMBER, ' || chr(10)
		|| dbms_assert.enquote_name(c_Folder_Name_Col) || ' VARCHAR2(512) NOT NULL, ' || chr(10)
		|| Foreign_Key_Constraint (
			p_Table_Name  => p_Table_Name,
			p_Parent_Table => p_Table_Name,
			p_Parent_Key_Column => c_Folder_Parent_Col,
			p_Parent_Ref_Type => 'CONTAINER'
		);
	end Folder_Columns;

    FUNCTION  Create_Table (
        p_Table_Name    	VARCHAR2,
    	p_Parent_Table 		VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
    	p_Parent_Ref_Type 	VARCHAR2 DEFAULT 'NO',	-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
        p_Add_WorkspaceID   VARCHAR2 DEFAULT 'NO',
        p_Add_Modify_Date   VARCHAR2 DEFAULT 'YES',
        p_Add_Modify_User   VARCHAR2 DEFAULT 'YES',
        p_Add_Create_Date   VARCHAR2 DEFAULT 'YES',
        p_Add_Create_User   VARCHAR2 DEFAULT 'YES',
        p_Add_File  	    VARCHAR2 DEFAULT 'NO',  -- NO, BINARY, TEXT, HTML, FOLDER
        p_Add_Description   VARCHAR2 DEFAULT 'NO',
        p_Add_Ordering	  	VARCHAR2 DEFAULT 'NO',
        p_Add_Aktive 		VARCHAR2 DEFAULT 'NO',
        p_Add_Locked 		VARCHAR2 DEFAULT 'NO'
    ) RETURN VARCHAR2		-- Primary Key Constraint_name
    IS
    	v_Parent_Key_Column 	VARCHAR2(128);		-- Column Name with foreign key to Parent Table
    	v_Unique_Desc_Column 	VARCHAR2(128);
        v_Include_Changelog     VARCHAR2(6);
        v_Sequence_Exists 		VARCHAR2(6);
        v_Stat                  VARCHAR2(32767);
        v_Sequence_Name         VARCHAR2(40);
        v_Table_Name            VARCHAR2(32);
        v_Short_Name            VARCHAR2(32);
        v_Schema_Name           VARCHAR2(40) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
		v_Add_Delete_Mark   	VARCHAR2(6);
		v_Count					PLS_INTEGER;
		v_Result_Name 			VARCHAR2(128);
		v_PK_Constraint_Name	VARCHAR2(128);
    BEGIN
        v_Table_Name := UPPER(REPLACE(p_Table_Name, ' ', '_'));
        v_Short_Name := changelog_conf.Get_BaseName(v_Table_Name);
        v_Short_Name := RTRIM(SUBSTR(v_Short_Name, 1, 23), '_');
        v_Result_Name := data_browser_conf.Compose_Table_Column_Name (v_Table_Name, 'PK');
        v_PK_Constraint_Name := dbms_assert.enquote_name(v_Result_Name);
		changelog_conf.Get_Sequence_Name(v_Short_Name, v_Sequence_Name, v_Sequence_Exists);
		v_Parent_Key_Column := case when p_Parent_Table IS NOT NULL then
									data_browser_conf.Compose_Table_Column_Name(p_Parent_Table, c_Primary_Key_Col)
								end;
		v_Unique_Desc_Column := case when p_Add_File = 'BINARY' then c_File_Name_Col
									when p_Add_File = 'FOLDER' then c_Folder_Name_Col
									when p_Add_Description = 'YES' then c_Unique_Desc_Col
								end;
		v_Add_Delete_Mark := case when changelog_conf.Get_Use_Column_Delete_mark = 'YES'
                                   and p_Add_File != 'NO' then 'YES' else 'NO' end;
		v_Stat :=
		'CREATE TABLE ' || v_Schema_Name || '.' || dbms_assert.enquote_name(v_Table_Name) || chr(10)
		|| '( '
		|| dbms_assert.enquote_name(c_Primary_Key_Col) || ' NUMBER NOT NULL, ' || chr(10)
		|| case when p_Add_File != 'NO' then
		    dbms_assert.enquote_name(c_Row_Version_Col) || ' NUMBER DEFAULT 1 NOT NULL, ' || chr(10)
		end
		|| case when v_Parent_Key_Column IS NOT NULL then
			dbms_assert.enquote_name(v_Parent_Key_Column) || ' NUMBER'
			|| case when p_Parent_Ref_Type NOT IN ('OPTIONAL_CONTAINER', 'NULLABLE') then ' NOT NULL' end
			|| ', ' || chr(10)
		end
		|| case when p_Add_File = 'BINARY' then
			File_Columns ( p_Table_Name => v_Table_Name, p_Add_Locked => p_Add_Locked, p_Required => 'Y' ) || ', ' || chr(10)
		when p_Add_File = 'FOLDER' then
			Folder_Columns ( p_Table_Name => v_Table_Name ) || ', ' || chr(10)
		else 
			case when v_Unique_Desc_Column IS NOT NULL then
				dbms_assert.enquote_name(v_Unique_Desc_Column) || ' VARCHAR2(512) NOT NULL, ' || chr(10)
			end
			|| case when p_Add_Locked = 'YES' then
				Boolean_Column(v_Table_Name, c_Protected_Col, 'N') || ', ' || chr(10)
			end
		end
		|| case when p_Add_Ordering = 'YES' then
			 dbms_assert.enquote_name(c_Ordering_Col) || ' NUMBER(10,0), ' || chr(10)
		end
		|| case when p_Add_Aktive = 'YES' then
			Boolean_Column(v_Table_Name, c_Active_Col, 'Y') || ', ' || chr(10)
		end
		|| case when p_Add_File IN ('TEXT', 'HTML') then
			dbms_assert.enquote_name(data_browser_conf.Compose_Column_Name(c_Notes_Base_Name, p_Add_File)) || ' CLOB, ' || chr(10)
			|| dbms_assert.enquote_name(data_browser_conf.Compose_Column_Name(c_Notes_Base_Name, 'DATUM')) || ' DATE' || fn_Default_Clause || 'SYSDATE NOT NULL, ' || chr(10)
		end
		|| case when p_Add_Create_Date = 'YES' then
			dbms_assert.enquote_name(changelog_conf.Get_ColumnCreateDate)
			|| ' ' || changelog_conf.Get_DatatypeModifyDate
			|| fn_Default_Clause || changelog_conf.Get_FunctionModifyDate || ' NOT NULL, ' || chr(10)
		end
		|| case when p_Add_Create_User = 'YES' then
			dbms_assert.enquote_name(changelog_conf.Get_ColumnCreateUser)
			|| ' ' || changelog_conf.Get_ColumnTypeModifyUser || ' '
			|| fn_Default_Clause || changelog_conf.Get_FunctionModifyUser || ' NOT NULL, ' || chr(10)
		end
		|| case when p_Add_Modify_Date = 'YES' then
			dbms_assert.enquote_name(changelog_conf.Get_ColumnModifyDate)
			|| ' ' || changelog_conf.Get_DatatypeModifyDate
			|| fn_Default_Clause || changelog_conf.Get_FunctionModifyDate || ' NOT NULL, ' || chr(10)
		end
		|| case when p_Add_Modify_User = 'YES' then
			dbms_assert.enquote_name(changelog_conf.Get_ColumnModifyUser)
			|| ' ' || changelog_conf.Get_ColumnTypeModifyUser || ' '
			|| fn_Default_Clause || changelog_conf.Get_FunctionModifyUser || ' NOT NULL, ' || chr(10)
		end
		|| case when p_Add_WorkspaceID = 'YES' then
			dbms_assert.enquote_name(changelog_conf.Get_ColumnWorkspace) || ' NUMBER(7,0) '
			|| fn_Default_Clause || changelog_conf.Get_Context_WorkspaceID_Expr 
			|| ' NOT NULL '
			|| 'CONSTRAINT ' || dbms_assert.enquote_name(data_browser_conf.Compose_Table_Column_Name (v_Table_Name, 'WSFK'))
			|| ' FOREIGN KEY(' || changelog_conf.Get_ColumnWorkspace || ')'
			|| ' REFERENCES ' || changelog_conf.Get_TableWorkspaces || '(' || changelog_conf.Get_ColumnWorkspace
			|| ') ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE '
			|| chr(10)
		end
		|| case when v_Add_Delete_Mark = 'YES' then
			dbms_assert.enquote_name(changelog_conf.Get_ColumnDeletedMark) || ' ' || changelog_conf.Get_ColumnTypeDeletedMark || ', ' || chr(10)
		end
		|| case when v_Unique_Desc_Column IS NOT NULL then
			Unique_Desc_Constraint (
				p_Table_Name  => v_Table_Name,
				p_Unique_Desc_Column => v_Unique_Desc_Column,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Folder_Parent_Col => case when p_Add_File = 'FOLDER' then c_Folder_Parent_Col end
			) || ', ' || chr(10)
		end
		|| case when v_Parent_Key_Column IS NOT NULL then
			Foreign_Key_Constraint (
				p_Table_Name  => v_Table_Name,
				p_Parent_Table => p_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column,
				p_Parent_Ref_Type => p_Parent_Ref_Type
			)
			|| ', ' || chr(10)
		end
		|| 'CONSTRAINT ' || v_PK_Constraint_Name
		|| ' PRIMARY KEY (' || dbms_assert.enquote_name(c_Primary_Key_Col) || ')' || chr(10)
		|| ')' || chr(10);
		Run_Stat (v_Stat);

		if v_Sequence_Exists = 'NO' then
			v_Stat := 'CREATE SEQUENCE ' || v_Sequence_Name
			|| ' START WITH 1 INCREMENT BY 1 '
			|| changelog_conf.Get_SequenceOptions;
			Run_Stat (v_Stat);
			v_Sequence_Exists := 'YES';
		end if;
		-- set primary key default value
		if v_Sequence_Exists = 'YES' and changelog_conf.Use_Serial_Default = 'YES'  then
			v_Stat := 'ALTER TABLE ' || v_Table_Name || ' MODIFY ( ' || c_Primary_Key_Col || fn_Default_Clause || v_Sequence_Name || '.NEXTVAL )';
			Run_Stat (v_Stat);
		END IF;
		
		if v_Parent_Key_Column IS NOT NULL and v_Unique_Desc_Column IS NULL  then 
			v_Stat := Foreign_Key_Index(
				p_Table_Name  => v_Table_Name,
				p_Parent_Table => p_Parent_Table,
				p_Parent_Key_Column => v_Parent_Key_Column
			);
			if v_Stat IS NOT NULL then 
				Run_Stat (v_Stat);
			end if;
		end if;
		if p_Add_File = 'FOLDER' then
			v_Stat := Foreign_Key_Index(
				p_Table_Name  => v_Table_Name,
				p_Parent_Table => v_Table_Name,
				p_Parent_Key_Column => c_Folder_Parent_Col
			);
			if v_Stat IS NOT NULL then 
				Run_Stat (v_Stat);
			end if;
		end if;
        ---- Triggers ---------------------------------------------------------
        
        -- in case that audit triggers are needed the funtions Before_Insert_Trigger_body and Before_Update_Trigger_body are used.
		IF changelog_conf.Get_Use_Audit_Info_Trigger = 'YES' THEN
			v_Stat := changelog_conf.Before_Insert_Trigger_body (
				p_Table_Name => v_Table_Name,
				p_Primary_Key_Col => c_Primary_Key_Col, 
				p_Has_Serial_Primary_Key => 'YES', 
				p_Sequence_Name => v_Sequence_Name,
				p_Column_CreDate =>	case when p_Add_Create_Date = 'YES' then changelog_conf.Get_ColumnCreateDate end, 
				p_Column_CreUser => case when p_Add_Create_User = 'YES' then changelog_conf.Get_ColumnCreateUser end, 
				p_Column_ModDate => case when p_Add_Modify_Date = 'YES' then changelog_conf.Get_ColumnModifyDate end, 
				p_Column_ModUser => case when p_Add_Modify_User = 'YES' then changelog_conf.Get_ColumnModifyUser end);
			if v_Stat IS NOT NULL then
				v_Stat := 'CREATE OR REPLACE TRIGGER ' || changelog_conf.Get_BiTrigger_Name(v_Short_Name) || chr(10)
					|| 'BEFORE INSERT ON ' || v_Table_Name || ' FOR EACH ROW '  || chr(10)
					|| 'BEGIN '  || chr(10)
					|| v_Stat
					|| 'END;' || chr(10);
				Run_Stat (v_Stat, 0, '/');
			end if;
			v_Stat := changelog_conf.Before_Update_Trigger_body ( 
				p_Column_ModDate => case when p_Add_Modify_Date = 'YES' then changelog_conf.Get_ColumnModifyDate end, 
				p_Column_ModUser => case when p_Add_Modify_User = 'YES' then changelog_conf.Get_ColumnModifyUser end);
			IF v_Stat IS NOT NULL THEN
				v_Stat := 'CREATE OR REPLACE TRIGGER ' || changelog_conf.Get_BuTrigger_Name(v_Short_Name) || chr(10)
					|| 'BEFORE UPDATE ON ' || v_Table_Name || ' FOR EACH ROW' || chr(10)
					|| 'BEGIN' || chr(10)
					|| v_Stat
					|| 'END;' || chr(10);
				Run_Stat (v_Stat, 0, '/');
			END IF;
		END IF;
		
		IF changelog_conf.Get_Use_Audit_Info_Trigger = 'YES' 
		AND changelog_conf.Match_Column_Pattern(v_Table_Name, changelog_conf.Get_IncludeChangeLogPattern) = 'YES'
		AND changelog_conf.Match_Column_Pattern(v_Table_Name, changelog_conf.Get_ExcludeChangeLogPattern) = 'NO' THEN
			data_browser_jobs.Refresh_After_DDL_Job ( p_Table_Name => v_Table_Name );
		END IF;
		
		data_browser_jobs.Start_Refresh_Mviews_Job (p_Delay_Seconds => c_MView_Refresh_Delay);

		return v_Result_Name;
	end Create_Table;

    PROCEDURE  Drop_Table (
        p_Table_Name    	VARCHAR2
	)
	is
        v_Stat                  VARCHAR2(32767);
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
	begin
		SELECT TABLE_NAME, TABLE_OWNER 
		INTO v_Table_Name, v_Table_Owner
		FROM MVDATA_BROWSER_VIEWS
		WHERE VIEW_NAME = p_Table_Name;

		v_Stat := 'DROP TABLE '
		|| dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
		|| ' CASCADE CONSTRAINTS ';
		Run_Stat (v_Stat);
		-- data_browser_conf.Touch_Configuration;
		data_browser_jobs.Start_Refresh_Mviews_Job(p_Delay_Seconds => c_MView_Refresh_Delay);
	end Drop_Table;

    FUNCTION Validate_Column_Name (
    	p_Column_Name VARCHAR2
    ) RETURN VARCHAR2 
    IS 
    	v_Column_Name VARCHAR2(128) := UPPER(REPLACE(p_Column_Name, ' ', '_'));
	BEGIN
		if REGEXP_SUBSTR(v_Column_Name, '([[:alpha:]][[:alnum:]|_]+)') != v_Column_Name then 
			return 'NO';
		else
			return 'YES';
		end if;
	END Validate_Column_Name;

    PROCEDURE  Add_Column (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2,
    	p_Reference_Table 	VARCHAR2 DEFAULT NULL,	-- For target of type reference; Parent View or Table name.
    	p_Reference_Type 	VARCHAR2 DEFAULT 'NULLABLE',	-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Reference_Default_ID 	VARCHAR2 DEFAULT NULL,	-- For target of type reference; default reference
    	p_Data_Type 		VARCHAR2 DEFAULT 'CHAR',	-- INTEGER, FLOAT, CURRENCY, CHAR, TEXT, HTML, FILE, DATE, BOOLEAN, REFERENCE, EXPRESSION, ORDINAL, ACTIVE, PROTECTED
        p_Char_Length 		NUMBER DEFAULT 128,			-- For columns of type CHAR range 1 - 32767
    	p_Default 			VARCHAR2 DEFAULT NULL,
    	p_Expression		VARCHAR2 DEFAULT NULL,
    	p_Required			VARCHAR2 DEFAULT 'NO', 		-- YES, NO
    	p_Unique			VARCHAR2 DEFAULT 'NO' 		-- YES, NO, COMPOSED
    )
    is
        v_Stat                  VARCHAR2(32767);
        v_Table_Name            VARCHAR2(32);
    	v_Table_Owner			VARCHAR2(128);
        v_Column_Name 			VARCHAR2(128);
        v_Default_Value			VARCHAR2(100);
        v_Unique_Column_Names	MVDATA_BROWSER_DESCRIPTIONS.UNIQUE_COLUMN_NAMES%TYPE;
       	v_U_Constraint_Name		MVDATA_BROWSER_DESCRIPTIONS.U_CONSTRAINT_NAME%TYPE;
       	v_Column_Prefix			MVDATA_BROWSER_VIEWS.COLUMN_PREFIX%TYPE;
    begin
		$IF data_browser_ddl.g_debug $THEN
			apex_debug.info(apex_string.format(
				p_message => 'data_browser_ddl.Add_Column(p_Table_name=> %s, p_Column_Name=> %s, p_Reference_Table=> %s, p_Reference_Type=> %s, , p_Reference_Default_ID=> %s, ' || chr(10)
						|| 'p_Data_Type=> %s, p_Char_Length=> %s, p_Default=> %s, p_Required=>%s, p_Unique=> %s)' || chr(10),
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Column_Name),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Reference_Table),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Reference_Type),
				p4 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Reference_Default_ID),
				p5 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Data_Type),
				p6 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Char_Length),
				p7 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Default),
				p8 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Required),
				p9 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Unique),
				p_max_length => 3500),
				p_max_length => 3500
			);
		$END
		SELECT A.TABLE_NAME, A.TABLE_OWNER, A.UNIQUE_COLUMN_NAMES, A.U_CONSTRAINT_NAME, B.COLUMN_PREFIX
		INTO v_Table_Name, v_Table_Owner, v_Unique_Column_Names, v_U_Constraint_Name, v_Column_Prefix
		FROM MVDATA_BROWSER_DESCRIPTIONS A
		JOIN MVDATA_BROWSER_VIEWS B ON A.VIEW_NAME = B.VIEW_NAME
		WHERE A.VIEW_NAME = p_Table_Name;
		v_Column_Name := data_browser_conf.Normalize_Umlaute(p_Column_Name);
        v_Column_Name := UPPER(REPLACE(v_Column_Name, ' ', '_'));
        v_Column_Name := v_Column_Prefix ||
		        case when p_Data_Type = 'REFERENCE' then
					data_browser_conf.Compose_Column_Name(v_Column_Name, 'ID')
				when p_Data_Type = 'ORDINAL' then
					c_Ordering_Col
				when p_Data_Type = 'ACTIVE' then
					c_Active_Col
				when p_Data_Type = 'PROTECTED' then
					c_Protected_Col
			else v_Column_Name end;
		v_Default_Value := case when p_Data_Type IN ('INTEGER', 'FLOAT', 'CURRENCY') then
									p_Default
								when p_Data_Type = 'REFERENCE' then
									dbms_assert.enquote_literal(p_Reference_Default_ID)
								else dbms_assert.enquote_literal(p_Default)
							end;

		v_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
			|| ' ADD ('
			|| case when p_Data_Type = 'BOOLEAN' then
					Boolean_Column(v_Table_Name, v_Column_Name, p_Default)
				when p_Data_Type = 'ORDINAL' then
					dbms_assert.enquote_name(c_Ordering_Col) || ' NUMBER(10,0)' || chr(10)
				when p_Data_Type = 'EXPRESSION' then
					Virtual_Column(v_Column_Name, p_Expression) || chr(10)
				when p_Data_Type = 'ACTIVE' then
					Boolean_Column(v_Table_Name, c_Active_Col, p_Default) || chr(10)
				when p_Data_Type = 'PROTECTED' then
					Boolean_Column(v_Table_Name, c_Protected_Col, p_Default) || chr(10)
				when p_Data_Type = 'CURRENCY' then
					Currency_Column(v_Column_Name, p_Default)
				when p_Data_Type = 'FILE' then -- add meta data fields 
					File_Columns ( p_Table_Name => v_Table_Name, p_Column_Name => p_Column_Name, 
						p_Add_Locked => 'N', p_Required => p_Required )
				else
					dbms_assert.enquote_name(v_Column_Name) || ' '
					||  case when p_Data_Type IN ('FLOAT', 'DATE') then
								p_Data_Type
						when p_Data_Type = 'INTEGER' then
							'NUMBER(10,0)'
						when p_Data_Type = 'CHAR' then
							'VARCHAR2(' || p_Char_Length || ' CHAR)'
						when p_Data_Type = 'REFERENCE' then
							'NUMBER'
						when p_Data_Type IN ('TEXT', 'HTML') then
							'CLOB'
						else
							p_Data_Type
					end
					|| case when p_Default IS NOT NULL then
						fn_Default_Clause
						|| v_Default_Value
					end
					|| case when p_Data_Type != 'REFERENCE' and p_Required = 'YES'
								or p_Data_Type = 'REFERENCE' and p_Reference_Type NOT IN ('OPTIONAL_CONTAINER', 'NULLABLE')
						then ' NOT NULL'
					end
				end
			|| ')';
		Run_Stat (v_Stat);
		if changelog_conf.Get_Use_On_Null = 'NO'
		and p_Default IS NOT NULL then
			v_Stat :=  'UPDATE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
			|| ' SET ' || dbms_assert.enquote_name(v_Column_Name)
			|| ' = '
			|| v_Default_Value;
			Run_Stat (v_Stat);
			COMMIT;
		end if;
		if p_Data_Type = 'REFERENCE' then
			v_Stat :=  'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
			|| ' ADD '
			|| Foreign_Key_Constraint (
				p_Table_Name  => v_Table_Name,
				p_Parent_Table => p_Reference_Table,
				p_Parent_Key_Column => v_Column_Name,
				p_Parent_Ref_Type => p_Reference_Type
			);
			Run_Stat (v_Stat);
			if p_Unique = 'NO'  then 
				v_Stat := Foreign_Key_Index(
					p_Table_Name  => v_Table_Name,
					p_Parent_Table => p_Reference_Table,
					p_Parent_Key_Column => v_Column_Name
				);
				if v_Stat IS NOT NULL then 
					Run_Stat (v_Stat);
				end if;
			end if;

		end if;
		if p_Unique = 'YES' then
			if v_U_Constraint_Name IS NOT NULL then
				-- extent the unique display constraint
				v_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
					|| ' DROP CONSTRAINT ' || dbms_assert.enquote_name(v_U_Constraint_Name);
				Run_Stat (v_Stat);
			end if;
			if p_Data_Type = 'REFERENCE' then
				v_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
				|| ' ADD ('
				|| Unique_Desc_Constraint (
					p_Table_Name  => v_Table_Name,
					p_Unique_Desc_Column => v_Column_Name,
					p_Parent_Key_Column => v_Unique_Column_Names,
					p_Constraint_Name => v_U_Constraint_Name
				)
				|| ')';
				Run_Stat (v_Stat);
			else
				v_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
				|| ' ADD ('
				|| Unique_Desc_Constraint (
					p_Table_Name  => v_Table_Name,
					p_Unique_Desc_Column => v_Column_Name,
					p_Parent_Key_Column => v_Unique_Column_Names,
					p_Constraint_Name => v_U_Constraint_Name
				)
				|| ')';
				Run_Stat (v_Stat);
			end if;
		end if;
		data_browser_jobs.Refresh_After_DDL_Job ( p_Table_Name => v_Table_Name );
		data_browser_jobs.Start_Refresh_Mviews_Job (p_Start_Step => data_browser_jobs.Get_Refresh_Start_Project, p_Delay_Seconds => c_MView_Refresh_Delay);
    end Add_Column;


    PROCEDURE  Drop_Column (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2
    )
    is
        v_Stat                  VARCHAR2(32767);
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
    begin
		SELECT TABLE_NAME, TABLE_OWNER 
		INTO v_Table_Name, v_Table_Owner
		FROM MVDATA_BROWSER_VIEWS
		WHERE VIEW_NAME = p_Table_Name;

		v_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
			|| ' DROP COLUMN ' || dbms_assert.enquote_name(p_Column_Name) 
			|| ' CASCADE CONSTRAINTS';
		EXECUTE IMMEDIATE v_Stat;
		INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing DDL', SUBSTR(v_Stat, 1, 4000));
		COMMIT;
		data_browser_jobs.Refresh_After_DDL_Job ( p_Table_Name => p_Table_Name );
		data_browser_jobs.Start_Refresh_Mviews_Job (p_Start_Step => data_browser_jobs.Get_Refresh_Start_Project, p_Delay_Seconds => c_MView_Refresh_Delay);
    end Drop_Column;

/*

Load_Column_Constraints (
	p_Table_Name    	=> :P48_TABLE_NAME,
	p_Column_Name 		=> :P48_COLUMN_NAME,
	p_CONSTRAINT_NAME   => :P48_CONSTRAINT_NAME,
	p_U_CONSTRAINT_NAME => :P48_U_CONSTRAINT_NAME,
	p_Reference_Table 	=> :P48_REFERENCE_TABLE,
	p_Reference_Default_ID 	=> :P48_REFERENCE_DEFAULT_ID,
	p_Check_Condition	=> :P48_CHECK_CONDITION,
	p_CHECK_UNIQUE		=> :P48_CHECK_UNIQUE,
	p_Required			=> :P48_REQUIRED,
	p_Data_Type 		=> :P48_DATA_TYPE,
	p_Char_Length 		=> :P48_CHAR_LENGTH,
	p_Data_Default 		=> :P48_DATA_DEFAULT,
	p_Is_Simple_IN_List => :P48_IS_SIMPLE_IN_LIST
	p_Constraint_Options => :P48_CONSTRAINT_OPTIONS
);
:P48_REQUIRED_OLD := :P48_REQUIRED;
:P48_REFERENCE_DEFAULT_ID := :P48_DATA_DEFAULT;
:P48_DATA_DEFAULT_OLD := :P48_DATA_DEFAULT;
:P48_STATEMENT := NULL;
:P48_UNDO_STATEMENT := NULL; 

*/


    PROCEDURE  Load_Column_Constraints (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2,
		p_CONSTRAINT_NAME   OUT VARCHAR2,
		p_U_CONSTRAINT_NAME OUT VARCHAR2,
		p_R_CONSTRAINT_NAME OUT VARCHAR2,
    	p_Reference_Table 	OUT VARCHAR2,		-- For target of type reference; Parent View or Table name.
    	p_Reference_Type 	OUT VARCHAR2,		-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Reference_Default_ID 	OUT VARCHAR2,	-- For target of type reference; default reference
		p_Check_Condition	OUT VARCHAR2,
    	p_CHECK_UNIQUE		OUT VARCHAR2,  		-- N,Y
    	p_Required			OUT VARCHAR2, 		-- YES, NO
    	p_Data_Type 		OUT VARCHAR2,		-- INTEGER, FLOAT, CURRENCY, CHAR, TEXT, HTML, FILE, DATE, BOOLEAN, REFERENCE
        p_Char_Length 		OUT VARCHAR2,		-- For columns of type CHAR range 1 - 32767
    	p_Data_Default 		OUT VARCHAR2,
		p_Is_Simple_IN_List OUT VARCHAR2,
		p_Constraint_Options OUT VARCHAR2
    )
    is
		v_Query VARCHAR2(4000);
		v_Data_Scale PLS_INTEGER;
	begin
		p_CONSTRAINT_NAME := NULL;
		p_U_CONSTRAINT_NAME := NULL;
		p_R_CONSTRAINT_NAME := NULL;
		p_REFERENCE_TABLE := NULL;
		p_REFERENCE_DEFAULT_ID := NULL;
		p_CHECK_CONDITION := NULL;
		p_CHECK_UNIQUE    := 'N';
		p_REQUIRED        := 'N';
		p_DATA_TYPE       := NULL;
		p_CHAR_LENGTH     := NULL;
		p_DATA_DEFAULT    := '';
		p_IS_SIMPLE_IN_LIST := 'N';
	
		-- Items to return : 
		-- P48_CONSTRAINT_NAME,P48_U_CONSTRAINT_NAME,P48_CHECK_CONDITION,P48_CHECK_UNIQUE,P48_REQUIRED,P48_DATA_DEFAULT,P48_IS_SIMPLE_IN_LIST,P48_CONSTRAINT_OPTIONS,P48_REFERENCE_TABLE,P48_REFERENCE_DEFAULT_ID,P48_DATA_TYPE,P48_CHAR_LENGTH
		
		if p_COLUMN_NAME IS NOT NULL then 
			begin
				SELECT CONSTRAINT_NAME, CHECK_CONDITION,
					NVL(CHECK_UNIQUE, 'N') CHECK_UNIQUE, REQUIRED, DATA_DEFAULT,
					IS_SIMPLE_IN_LIST
				INTO p_CONSTRAINT_NAME, p_CHECK_CONDITION, p_CHECK_UNIQUE, p_REQUIRED, p_DATA_DEFAULT, p_IS_SIMPLE_IN_LIST
				FROM MVDATA_BROWSER_CHECKS_DEFS
				WHERE VIEW_NAME = p_TABLE_NAME
				AND COLUMN_NAME = p_COLUMN_NAME
				-- AND CONSTRAINT_NAME != 'AUTOMATICALLY'
				;
			exception when NO_DATA_FOUND then
				NULL;
			end;

			SELECT case when NULLABLE = 'N' then 'Y' else 'N' end REQUIRED,
				DATA_TYPE, CHAR_LENGTH, DATA_SCALE
			INTO p_REQUIRED, p_DATA_TYPE, p_CHAR_LENGTH, v_Data_Scale
			FROM USER_TAB_COLUMNS 
			WHERE TABLE_NAME = p_TABLE_NAME
			AND COLUMN_NAME = p_COLUMN_NAME;
			
			p_DATA_DEFAULT := changelog_conf.Get_ColumnDefaultText (p_Table_Name => p_TABLE_NAME, p_Column_Name => p_COLUMN_NAME);

			begin
				select MIN(U_CONSTRAINT_NAME), case when COUNT(*) > 0 then 'Y' else 'N' end CHECK_UNIQUE
				into p_U_CONSTRAINT_NAME, p_CHECK_UNIQUE 
				from MVDATA_BROWSER_U_REFS 
				where VIEW_NAME =  p_TABLE_NAME
				AND COLUMN_NAME = p_COLUMN_NAME;
			exception when NO_DATA_FOUND then
				NULL;
			end;
			
			begin 
				select CONSTRAINT_NAME, 
					R_VIEW_NAME, 
					case when DELETE_RULE = 'CASCADE' and p_REQUIRED = 'Y' 
						then 'CONTAINER'
					when DELETE_RULE = 'CASCADE' and p_REQUIRED = 'N' 
						then 'OPTIONAL_CONTAINER'
					when p_REQUIRED = 'Y' 
						then 'REQUIRED'
					else 'NULLABLE'
					end REFERENCE_TYPE
				into p_R_CONSTRAINT_NAME, p_REFERENCE_TABLE, p_Reference_Type
				from MVDATA_BROWSER_FKEYS
				where VIEW_NAME = p_TABLE_NAME
				and FOREIGN_KEY_COLS = p_COLUMN_NAME;
				
				p_REFERENCE_DEFAULT_ID := p_DATA_DEFAULT;
				
			exception when NO_DATA_FOUND then
				-- p_Reference_Type is initialised in the case that a column is of type INTEGER
				if p_DATA_TYPE = 'NUMBER' and NVL(v_Data_Scale, 0) = 0 then 
					p_Reference_Type := case when p_REQUIRED = 'Y' 
						then 'REQUIRED' else 'NULLABLE' end;
				end if;
			end;
		end if;
		if p_CONSTRAINT_NAME = p_U_CONSTRAINT_NAME then 
			p_CONSTRAINT_NAME := NULL;
		end if;
		if p_IS_SIMPLE_IN_LIST = 'Y' then
			p_CONSTRAINT_OPTIONS := 'IN';
		elsif p_CONSTRAINT_NAME != 'AUTOMATICALLY' and p_CHECK_CONDITION IS NOT NULL then
			p_CONSTRAINT_OPTIONS := 'RANGE';
		elsif p_R_CONSTRAINT_NAME IS NOT NULL then
			p_CONSTRAINT_OPTIONS := 'REFERENCE';
		else 
			p_CONSTRAINT_OPTIONS := 'NO';
		end if;
		$IF data_browser_ddl.g_debug $THEN
			apex_debug.info(
				p_message => '1. Load_Column_Constraints(p_CONSTRAINT_NAME => %s, p_U_CONSTRAINT_NAME => %s, p_R_CONSTRAINT_NAME => %s,' || chr(10)
				|| 'p_Reference_Table => %s, p_Reference_Type => %s, p_Check_Condition => %s, p_CHECK_UNIQUE => %s, p_Required => %s)', 
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_CONSTRAINT_NAME),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_U_CONSTRAINT_NAME),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_R_CONSTRAINT_NAME),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Reference_Table),
				p4 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Reference_Type),
				p5 => data_browser_conf.ENQUOTE_LITERAL(p_Check_Condition),
				p6 => DBMS_ASSERT.ENQUOTE_LITERAL(p_CHECK_UNIQUE),
				p7 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Required)
			);
		$END
	end Load_Column_Constraints;   

    PROCEDURE Generate_Column_Constraints (
        p_Table_Name    	VARCHAR2,
    	p_Column_Name 		VARCHAR2,
		p_CONSTRAINT_NAME   IN OUT VARCHAR2,
		p_U_CONSTRAINT_NAME IN OUT VARCHAR2,
		p_R_CONSTRAINT_NAME IN OUT VARCHAR2,
    	p_Reference_Table 	IN VARCHAR2,	    -- For target of type reference; Parent View or Table name.
    	p_Reference_Type 	IN VARCHAR2,		-- For target of type reference; STATIC:Container;CONTAINER,Optional Container;OPTIONAL_CONTAINER,Required;REQUIRED,Optional;NULLABLE
		p_Reference_Default_ID IN VARCHAR2,		-- For target of type reference; default reference
		p_Check_Const_Options IN VARCHAR2,
		p_Check_Condition	IN VARCHAR2,
    	p_Check_Unique		IN VARCHAR2,  		-- N,Y
    	p_Check_Unique_Old	IN VARCHAR2,  		-- N,Y
    	p_Check_Unique_Valid OUT VARCHAR2,  	-- YES, NO
    	p_Required			IN VARCHAR2, 		-- YES, NO
     	p_Required_Old  	IN VARCHAR2, 		-- YES, NO
     	p_Required_Valid	OUT VARCHAR2, 		-- YES, NO
       	p_Data_Type 		IN VARCHAR2,	    -- INTEGER, FLOAT, CURRENCY, CHAR, TEXT, HTML, FILE, DATE, BOOLEAN, REFERENCE
        p_Char_Length 		IN VARCHAR2,		-- For columns of type CHAR range 1 - 32767
        p_Char_Length_Old	IN VARCHAR2,
    	p_Data_Default 		IN OUT VARCHAR2,
    	p_Data_Default_Old  IN OUT VARCHAR2,
		p_Is_Simple_IN_List IN VARCHAR2,
		p_Undo_Check_Stat   IN OUT VARCHAR2,
		p_Undo_Unique_Stat  IN OUT VARCHAR2,
		p_Undo_Ref_Stat     IN OUT VARCHAR2,
    	p_STATEMENT         OUT VARCHAR2,
    	p_Start_Step 		OUT BINARY_INTEGER
    )
    is
    	v_Table_Name			VARCHAR2(128);
    	v_Table_Owner			VARCHAR2(128);
        v_Default_Changed       BOOLEAN;
        v_Required_Changed      BOOLEAN;
        v_Length_Changed        BOOLEAN;
        v_Required      		VARCHAR2(10);
        v_Values_List           VARCHAR2(4000);
        v_Unique_Columns_List   VARCHAR2(4000);
        v_Statements	    	VARCHAR2(4000);
        v_Stat			    	VARCHAR2(4000);
        v_Drop_Stat		    	VARCHAR2(4000);
        v_Start_Step			binary_integer := data_browser_jobs.Get_Refresh_Start_Project;
    begin
		SELECT TABLE_NAME, TABLE_OWNER 
		INTO v_Table_Name, v_Table_Owner
		FROM MVDATA_BROWSER_VIEWS
		WHERE VIEW_NAME = p_Table_Name;
		p_Check_Unique_Valid := NULL;
		p_Required_Valid := NULL;
        p_DATA_DEFAULT_OLD := utl_url.unescape(p_DATA_DEFAULT_OLD);
        p_DATA_DEFAULT := case when p_REFERENCE_TABLE IS NOT NULL then 
                p_REFERENCE_DEFAULT_ID
            else 
                utl_url.unescape(p_DATA_DEFAULT)
            end ;
        v_Required := case when p_Reference_Table IS NULL then p_REQUIRED
        				when p_Reference_Type IN ('OPTIONAL_CONTAINER', 'NULLABLE') then 'N'
        				else 'Y'
        				end;
        v_Default_Changed := NVL(p_DATA_DEFAULT_OLD, 'NULL') != NVL(p_DATA_DEFAULT, 'NULL');
        v_Required_Changed := p_REQUIRED_OLD != v_Required;
        v_Length_Changed   := p_CHAR_LENGTH_OLD != p_CHAR_LENGTH;
        p_STATEMENT := NULL;
        if v_Required_Changed or v_Default_Changed or v_Length_Changed then 
            p_STATEMENT := p_STATEMENT || 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) 
            || ' MODIFY ' || dbms_assert.enquote_name(p_COLUMN_NAME) 
            || case when v_Length_Changed then ' ' || p_DATA_TYPE || '(' || p_CHAR_LENGTH || ') ' end
            || case when v_Default_Changed then fn_Default_Clause || NVL(p_DATA_DEFAULT, 'NULL') end
            || case when v_Required_Changed then 
                   case when v_Required = 'Y' then ' NOT NULL ' else ' NULL ' end
            end
            || ';' || chr(10);
            if v_Required = 'Y' then 
            	p_Required_Valid := FN_Query_Required (
					p_Table_Name => v_Table_Name,
					p_Column_Name => p_COLUMN_NAME
				);
            end if;
            v_Start_Step := LEAST(v_Start_Step, data_browser_jobs.Get_Refresh_Start_Project);
        end if;
		----------------------------------------------------------------------------------
		$IF data_browser_ddl.g_debug $THEN
			apex_debug.info(
				p_message => '1. Generate_Column_Constraints(p_Check_Const_Options => %s, p_Check_Condition => %s, p_IS_SIMPLE_IN_LIST => %s, p_CONSTRAINT_NAME => %s)', 
				p0 => data_browser_conf.ENQUOTE_LITERAL(p_Check_Const_Options),
				p1 => data_browser_conf.ENQUOTE_LITERAL(p_Check_Condition),
				p2 => data_browser_conf.ENQUOTE_LITERAL(p_IS_SIMPLE_IN_LIST),
				p3 => data_browser_conf.ENQUOTE_LITERAL(p_CONSTRAINT_NAME)
			);
		$END
        v_Statements := NULL;
        v_Drop_Stat := NULL;
		if p_CONSTRAINT_NAME != 'AUTOMATICALLY' then 
			v_Drop_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) 
			|| ' DROP CONSTRAINT ' || dbms_assert.enquote_name(p_CONSTRAINT_NAME);
		end if;
        if p_IS_SIMPLE_IN_LIST = 'Y' then 
			if p_CONSTRAINT_NAME = 'AUTOMATICALLY' or p_CONSTRAINT_NAME IS NULL then 
				p_CONSTRAINT_NAME := dbms_assert.enquote_name( 
						data_browser_conf.Compose_Column_Name(
						data_browser_conf.Compose_Table_Column_Name (p_TABLE_NAME, 
						data_browser_conf.Normalize_Column_Name(p_COLUMN_NAME)), 'CK')); 
			end if;
            select -- SEQ_ID ID, C001 COLUMN_VALUE, C002 DISP_SEQUENCE 
                LISTAGG(dbms_assert.enquote_literal(C001), ',') WITHIN GROUP (ORDER BY SEQ_ID)
            into v_Values_List
            from APEX_COLLECTIONS WHERE COLLECTION_NAME = 'PERMITTED_VALUES_LIST';
            if v_Values_List IS NOT NULL then 
                v_Statements := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) 
                || ' ADD CONSTRAINT ' || dbms_assert.enquote_name(p_CONSTRAINT_NAME) 
                || ' CHECK ('
                || data_browser_conf.Enquote_Name_Required(p_Column_Name)
                || ' in (' 
                || v_Values_List
                || '))';
            end if;
        elsif p_Check_Condition IS NOT NULL and p_Check_Const_Options NOT IN ('NO', 'REFERENCE') then 
			if p_CONSTRAINT_NAME = 'AUTOMATICALLY' or p_CONSTRAINT_NAME IS NULL then 
				p_CONSTRAINT_NAME := dbms_assert.enquote_name( 
						data_browser_conf.Compose_Column_Name(
						data_browser_conf.Compose_Table_Column_Name (p_TABLE_NAME, 
						data_browser_conf.Normalize_Column_Name(p_COLUMN_NAME)), 'CK')); 
			end if;
			v_Statements := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) 
			|| ' ADD CONSTRAINT ' || dbms_assert.enquote_name(p_CONSTRAINT_NAME) 
			|| ' CHECK ('
			|| p_Check_Condition
			|| ')';        
        end if;
		$IF data_browser_ddl.g_debug $THEN
			apex_debug.info(
				p_message => '2. Generate_Column_Constraints(p_Undo_Check_Stat => %s, v_Statements => %s, p_Check_Condition=> %s, p_CONSTRAINT_NAME => %s)', 
				p0 => data_browser_conf.ENQUOTE_LITERAL(p_Undo_Check_Stat),
				p1 => data_browser_conf.ENQUOTE_LITERAL(v_Statements),
				p2 => data_browser_conf.ENQUOTE_LITERAL(p_Check_Condition),
				p3 => data_browser_conf.ENQUOTE_LITERAL(p_CONSTRAINT_NAME)
			);
		$END
		if v_Statements = p_Undo_Check_Stat then 	-- nothing changed 
			p_Undo_Check_Stat := NULL;				-- nothing to undo 
		elsif v_Statements IS NOT NULL then 
			if v_Drop_Stat IS NOT NULL then
				p_STATEMENT := p_STATEMENT || v_Drop_Stat
				|| ';' || chr(10);
			end if;
			p_STATEMENT := p_STATEMENT || v_Statements
			|| ';' || chr(10);
            v_Start_Step := LEAST(v_Start_Step, data_browser_jobs.Get_Refresh_Start_Project); 
		end if;
		----------------------------------------------------------------------------------
        v_Statements := NULL;
        v_Drop_Stat := NULL;
		if p_U_CONSTRAINT_NAME IS NOT NULL then 
			SELECT case when CONSTRAINT_TYPE = 'I' then
					'DROP INDEX ' || dbms_assert.enquote_name(INDEX_OWNER) || '.'  || dbms_assert.enquote_name(INDEX_NAME) 
				else
					'ALTER TABLE ' || dbms_assert.enquote_name(TABLE_OWNER) || '.'  || dbms_assert.enquote_name(TABLE_NAME) 
					|| ' DROP CONSTRAINT ' || dbms_assert.enquote_name(U_CONSTRAINT_NAME) 
				end STAT
			INTO v_Drop_Stat
			FROM MVDATA_BROWSER_U_REFS 
			WHERE VIEW_NAME = v_Table_Name
			AND U_CONSTRAINT_NAME = p_U_CONSTRAINT_NAME
			AND ROWNUM = 1;
		elsif p_Check_Unique = 'Y' then 
			p_U_CONSTRAINT_NAME := dbms_assert.enquote_name( 
					data_browser_conf.Compose_Column_Name(
					data_browser_conf.Compose_Table_Column_Name (p_TABLE_NAME, 
					data_browser_conf.Normalize_Column_Name(p_COLUMN_NAME)), 'UN'));
		end if;
        if p_Check_Unique = 'Y' then 
            select -- SEQ_ID ID, C001 COLUMN_NAME, C002 POSITION 
                LISTAGG(C001, ',') WITHIN GROUP (ORDER BY SEQ_ID)
            into v_Unique_Columns_List
            from APEX_COLLECTIONS WHERE COLLECTION_NAME = 'UNIQUE_COLUMNS_LIST';
            if v_Unique_Columns_List IS NOT NULL then 
                v_Statements := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) 
				|| ' ADD ' 
				|| Unique_Desc_Constraint (
					p_Table_Name  => v_Table_Name,
					p_Unique_Desc_Column => v_Unique_Columns_List,
					p_Constraint_Name => p_U_CONSTRAINT_NAME
				);
            end if;
			$IF data_browser_ddl.g_debug $THEN
				apex_debug.info(
					p_message => '3. Generate_Column_Constraints(p_Undo_Unique_Stat => %s, v_Statements => %s, p_Check_Unique_Old => %s, p_Check_Unique => %s, p_U_CONSTRAINT_NAME => %s)', 
					p0 => data_browser_conf.ENQUOTE_LITERAL(p_Undo_Unique_Stat),
					p1 => data_browser_conf.ENQUOTE_LITERAL(v_Statements),
					p2 => data_browser_conf.ENQUOTE_LITERAL(p_Check_Unique_Old),
					p3 => data_browser_conf.ENQUOTE_LITERAL(p_Check_Unique),
					p4 => data_browser_conf.ENQUOTE_LITERAL(p_U_CONSTRAINT_NAME)
				);
			$END
			if v_Statements = p_Undo_Unique_Stat then 	-- nothing changed 
				p_Undo_Unique_Stat := NULL;				-- nothing to undo 
			elsif v_Statements IS NOT NULL then
				if v_Drop_Stat IS NOT NULL then
					p_STATEMENT := p_STATEMENT || v_Drop_Stat
					|| ';' || chr(10);
				end if;
				p_STATEMENT := p_STATEMENT || v_Statements
				|| ';' || chr(10);
				p_Check_Unique_Valid := FN_Query_Uniqueness (
					p_Table_Name => v_Table_Name,
					p_Column_Names => v_Unique_Columns_List
				);
			end if;
            v_Start_Step := LEAST(v_Start_Step, data_browser_jobs.Get_Refresh_Start_Unique);
		elsif p_Check_Unique != p_Check_Unique_Old and v_Drop_Stat IS NOT NULL then 
			p_STATEMENT := p_STATEMENT || v_Drop_Stat
			|| ';' || chr(10);
            v_Start_Step := LEAST(v_Start_Step, data_browser_jobs.Get_Refresh_Start_Unique);
        end if;
		----------------------------------------------------------------------------------
        v_Statements := NULL;
        v_Drop_Stat := NULL;
		if p_R_CONSTRAINT_NAME IS NOT NULL then 
			 v_Drop_Stat := 'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name) 
			|| ' DROP CONSTRAINT ' || dbms_assert.enquote_name(p_R_CONSTRAINT_NAME);
		end if;	
		if p_Reference_Table IS NOT NULL then 
			v_Statements :=  'ALTER TABLE ' || dbms_assert.enquote_name(v_Table_Owner) || '.'  || dbms_assert.enquote_name(v_Table_Name)
			|| ' ADD '
			|| Foreign_Key_Constraint (
				p_Table_Name  => p_TABLE_NAME,
				p_Parent_Table => p_Reference_Table,
				p_Parent_Key_Column => p_COLUMN_NAME,
				p_Parent_Ref_Type => p_Reference_Type,
				p_Constraint_Name => p_R_CONSTRAINT_NAME
			);
			$IF data_browser_ddl.g_debug $THEN
				apex_debug.info(
					p_message => '4. Generate_Column_Constraints(p_Undo_Ref_Stat => %s, v_Statements => %s, Match => %s, p_Reference_Table => %s, p_Reference_Type => %s)', 
					p0 => data_browser_conf.ENQUOTE_LITERAL(p_Undo_Ref_Stat),
					p1 => data_browser_conf.ENQUOTE_LITERAL(v_Statements),
					p2 => case when v_Statements = p_Undo_Ref_Stat then 'Yes' else 'No(' || length(v_Statements) || '/' || length(p_Undo_Ref_Stat) || ')' end,
					p3 => data_browser_conf.ENQUOTE_LITERAL(p_Reference_Table),
					p4 => data_browser_conf.ENQUOTE_LITERAL(p_Reference_Type)
				);
			$END

			if v_Statements = p_Undo_Ref_Stat then 	-- nothing changed 
				p_Undo_Ref_Stat := NULL;				-- nothing to undo 
			elsif v_Statements IS NOT NULL then 
				if v_Drop_Stat IS NOT NULL then
					p_STATEMENT := p_STATEMENT || v_Drop_Stat
					|| ';' || chr(10);
				end if;
				p_STATEMENT := p_STATEMENT || v_Statements
				|| ';' || chr(10);
				
				v_Stat := Foreign_Key_Index(
					p_Table_Name  => p_TABLE_NAME,
					p_Parent_Table => p_Reference_Table,
					p_Parent_Key_Column => p_COLUMN_NAME,
					p_Index_Name => p_R_CONSTRAINT_NAME
				);
				if v_Stat IS NOT NULL then 
					p_STATEMENT := p_STATEMENT || v_Stat
					|| ';' || chr(10);
				end if;			
			end if;
            v_Start_Step := LEAST(v_Start_Step, data_browser_jobs.Get_Refresh_Start_Foreign);
		elsif v_Drop_Stat IS NOT NULL then 
			p_STATEMENT := p_STATEMENT || v_Drop_Stat
			|| ';' || chr(10);
            v_Start_Step := LEAST(v_Start_Step, data_browser_jobs.Get_Refresh_Start_Foreign);
		end if;
		p_Start_Step := v_Start_Step;
    end Generate_Column_Constraints;

    PROCEDURE Execute_Column_Constraints (
        p_Table_Name    	IN VARCHAR2,
    	p_STATEMENT         IN OUT VARCHAR2,
		p_Undo_Check_Stat   IN VARCHAR2,
		p_Undo_Unique_Stat  IN VARCHAR2,
		p_Undo_Ref_Stat     IN VARCHAR2,
    	p_Start_Step 		IN BINARY_INTEGER
    )
    is
        v_Statements apex_t_varchar2;
        v_line VARCHAR2(4000);
    begin
        v_Statements := apex_string.split(
            p_str => p_STATEMENT,
            p_Sep => ';'
        );
        p_STATEMENT := NULL;
        begin
            for i in 1..v_Statements.COUNT loop
                v_line := v_Statements(i);
                if LENGTH(v_line) > 3 then 
                    APEX_DEBUG.MESSAGE (
                        p_message => 'Processing DDL : %s',
                        p0 => v_line
                    );
                    EXECUTE IMMEDIATE v_line;
                    INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing DDL', SUBSTR(v_line, 1, 4000));
                    COMMIT;
                end if;
            end loop;
			data_browser_jobs.Refresh_After_DDL_Job ( p_Table_Name => p_Table_Name );
			data_browser_jobs.Start_Refresh_Mviews_Job ( p_Start_Step => p_Start_Step, p_Delay_Seconds => c_MView_Refresh_Delay );
        EXCEPTION
        WHEN OTHERS THEN
            if SQLCODE = -02293 then
            	if p_Undo_Check_Stat IS NOT NULL then
					begin
						APEX_DEBUG.MESSAGE ( p_message => 'Processing Undo DDL : %s', p0 => p_Undo_Check_Stat );
						EXECUTE IMMEDIATE p_Undo_Check_Stat;
						INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing Undo DDL', SUBSTR(p_Undo_Check_Stat, 1, 4000));
						COMMIT;
					EXCEPTION
					WHEN OTHERS THEN
						NULL;
					end;
                end if;
            	if p_Undo_Unique_Stat IS NOT NULL then
					begin
						APEX_DEBUG.MESSAGE ( p_message => 'Processing Undo DDL : %s', p0 => p_Undo_Unique_Stat );
						EXECUTE IMMEDIATE p_Undo_Unique_Stat;
						INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing Undo DDL', SUBSTR(p_Undo_Unique_Stat, 1, 4000));
						COMMIT;
					EXCEPTION
					WHEN OTHERS THEN
						NULL;
					end;
                end if;

            	if p_Undo_Ref_Stat IS NOT NULL then
					begin
						APEX_DEBUG.MESSAGE ( p_message => 'Processing Undo DDL : %s', p0 => p_Undo_Ref_Stat );
						EXECUTE IMMEDIATE p_Undo_Ref_Stat;
						INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Processing Undo DDL', SUBSTR(p_Undo_Ref_Stat, 1, 4000));
						COMMIT;
					EXCEPTION
					WHEN OTHERS THEN
						NULL;
					end;
                end if;

            end if;
            RAISE;
        END;
    end Execute_Column_Constraints;

    PROCEDURE Tables_Add_Serial_Keys(
        p_Table_Names IN VARCHAR2 DEFAULT NULL
    )
    IS
        v_Stat  VARCHAR2(32767);
    	v_Count NUMBER := 0;
    BEGIN
		FOR  stat_cur IN (
			SELECT VIEW_NAME, TABLE_NAME, SEQUENCE_NAME, COLUMN_NAME, 
				CONSTRAINT_NAME, SHORT_NAME,
				CASE WHEN NOT EXISTS (
					SELECT 1 FROM USER_SEQUENCES S
					WHERE S.SEQUENCE_NAME = T.SEQUENCE_NAME
				) THEN
					'CREATE SEQUENCE ' || changelog_conf.Get_Table_Schema || SEQUENCE_NAME ||
					' START WITH ' || TO_CHAR(NUM_ROWS + 1) || ' MINVALUE ' || TO_CHAR(NUM_ROWS + 1) || ' INCREMENT BY 1 ' || changelog_conf.Get_SequenceOptions
				END SEQUENCE_STAT,
				CASE WHEN COLUMN_EXISTS = 'NO' THEN
					'ALTER TABLE ' || TABLE_NAME || ' ADD ( '
					|| COLUMN_NAME || ' NUMBER ' ||
					CASE WHEN changelog_conf.Use_Serial_Default = 'YES' THEN
						' DEFAULT ON NULL ' || SEQUENCE_NAME || '.NEXTVAL NOT NULL'
					END || ')'
				END ADD_COLUMN_STAT,
				CASE WHEN NOT EXISTS (
					SELECT 1
					FROM USER_COL_COMMENTS C
					WHERE C.COLUMN_NAME = T.COLUMN_NAME
					AND C.TABLE_NAME = T.TABLE_NAME
				) THEN
					'COMMENT ON COLUMN ' || TABLE_NAME || '.' || COLUMN_NAME
					|| ' IS ''Unique key with sequence '''
				END COMMENT_STAT,
				CASE WHEN changelog_conf.Use_Serial_Default = 'NO'
				AND COLUMN_EXISTS = 'NO' THEN
					'UPDATE ' || TABLE_NAME || ' SET ' ||  COLUMN_NAME || ' = ROWNUM'
				END INIT_STAT,
				 CASE WHEN COLUMN_EXISTS = 'NO' AND changelog_conf.Use_Serial_Default = 'NO' THEN
					'ALTER TABLE ' || TABLE_NAME || ' MODIFY ' ||  COLUMN_NAME || ' NOT NULL'
				END NN_STAT,
				CASE WHEN NOT EXISTS (
					SELECT 1 FROM USER_CONSTRAINTS S
					WHERE S.CONSTRAINT_NAME = T.CONSTRAINT_NAME
					AND S.TABLE_NAME = T.TABLE_NAME
				) THEN
					'ALTER TABLE ' || TABLE_NAME || ' ADD CONSTRAINT ' || CONSTRAINT_NAME || ' ' 
					|| case when CONSTRAINT_TYPE = 'P' then 'UNIQUE' else 'PRIMARY KEY' end 
					|| ' ('
					|| COLUMN_NAME || ') USING INDEX'
				END ADD_KEY_STAT
			FROM (
				SELECT T.VIEW_NAME, T.TABLE_NAME, T.CONSTRAINT_TYPE, T.SHORT_NAME, T.NUM_ROWS,
					changelog_conf.Get_Sequence_Name(T.SHORT_NAME) SEQUENCE_NAME,
					NVL(S.COLUMN_NAME, changelog_conf.Get_Sequence_Column(T.SHORT_NAME)) COLUMN_NAME,
					changelog_conf.Get_Sequence_Constraint(T.SHORT_NAME) CONSTRAINT_NAME,
					CASE WHEN S.COLUMN_NAME IS NOT NULL THEN 'YES' ELSE 'NO' END COLUMN_EXISTS
				FROM MVDATA_BROWSER_VIEWS T
				LEFT OUTER JOIN SYS.USER_TAB_COLS S 
					ON S.TABLE_NAME = T.TABLE_NAME 
					AND S.DATA_TYPE = 'NUMBER'
					AND S.COLUMN_NAME IN (changelog_conf.Get_Sequence_Column(SHORT_NAME), changelog_conf.Get_Sequence_Column(NULL))
				WHERE T.HAS_SCALAR_KEY = 'NO'
				AND (T.TABLE_NAME IN ( 
					SELECT COLUMN_VALUE FROM TABLE (apex_string.split(p_Table_Names,':') )
				) OR p_Table_Names IS NULL)
			) T
		)
		LOOP
 			DBMS_OUTPUT.PUT_LINE('-- Tables_Add_Serial_Keys ' || stat_cur.TABLE_NAME || '--');
			if stat_cur.SEQUENCE_STAT IS NOT NULL then
				Run_Stat (stat_cur.SEQUENCE_STAT);
			end if;
			if stat_cur.ADD_COLUMN_STAT IS NOT NULL then
				Run_Stat (stat_cur.ADD_COLUMN_STAT);
			end if;
			if stat_cur.COMMENT_STAT IS NOT NULL then
				Run_Stat (stat_cur.COMMENT_STAT);
			end if;
			if stat_cur.INIT_STAT IS NOT NULL then
				Run_Stat (stat_cur.INIT_STAT);
				COMMIT;
			end if;
			if stat_cur.NN_STAT IS NOT NULL then
				Run_Stat (stat_cur.NN_STAT);
			end if;
			if stat_cur.ADD_KEY_STAT IS NOT NULL then
				Run_Stat (stat_cur.ADD_KEY_STAT);
			end if;
			if changelog_conf.Use_Serial_Default = 'NO' then 
				v_Stat := changelog_conf.Before_Insert_Trigger_body (
					p_Table_Name => stat_cur.Table_Name,
					p_Primary_Key_Col => stat_cur.COLUMN_NAME, 
					p_Has_Serial_Primary_Key => 'YES', 
					p_Sequence_Name => stat_cur.SEQUENCE_NAME,
					p_Column_CreDate => null,
					p_Column_CreUser => null,
					p_Column_ModDate => null,
					p_Column_ModUser => null
				);
				if v_Stat IS NOT NULL then
					v_Stat := 'CREATE OR REPLACE TRIGGER ' || changelog_conf.Get_BiTrigger_Name(stat_cur.SHORT_NAME) || chr(10)
						|| 'BEFORE INSERT ON ' || stat_cur.TABLE_NAME || ' FOR EACH ROW '  || chr(10)
						|| 'BEGIN '  || chr(10)
						|| v_Stat
						|| 'END;' || chr(10);
					Run_Stat (v_Stat, 0, '/');
				end if;
			end if;

			v_Count := v_Count + 1;
		END LOOP;
    END Tables_Add_Serial_Keys;

    PROCEDURE Tables_Add_Natural_Keys(
        p_Table_Names IN VARCHAR2
    )
    IS
        v_Stat  VARCHAR2(32767);
    	v_Count NUMBER := 0;
    BEGIN
		FOR  stat_cur IN (
			SELECT A.VIEW_NAME, A.TABLE_OWNER, A.TABLE_NAME, B.UNIQUE_COLUMN_NAMES		
			FROM MVDATA_BROWSER_DESCRIPTIONS A
			join (
				SELECT SUBSTR(COLUMN_VALUE, 1, S_OFFSET - 1) VIEW_NAME, 
					SUBSTR(COLUMN_VALUE, S_OFFSET + 1) UNIQUE_COLUMN_NAMES
				FROM (
					SELECT COLUMN_VALUE, INSTR(COLUMN_VALUE,';') S_OFFSET FROM apex_string.split(p_Table_Names, ':')
				)
			) B ON B.VIEW_NAME = A.VIEW_NAME 
		)
		LOOP
 			DBMS_OUTPUT.PUT_LINE('-- Tables_Add_Natural_Keys ' || stat_cur.TABLE_NAME || '--');
			v_Stat :=	'ALTER TABLE ' || dbms_assert.enquote_name(stat_cur.TABLE_OWNER) || '.'  || dbms_assert.enquote_name(stat_cur.TABLE_NAME) 
				|| ' ADD ' 
				|| Unique_Desc_Constraint (
					p_Table_Name  => stat_cur.TABLE_NAME,
					p_Unique_Desc_Column => stat_cur.UNIQUE_COLUMN_NAMES
				);
			Run_Stat (v_Stat);
			v_Count := v_Count + 1;
		END LOOP;
    END Tables_Add_Natural_Keys;

    PROCEDURE Columns_Add_Required_Constraints(
        p_Column_Names IN VARCHAR2
    )
    IS
        v_Stat  VARCHAR2(32767);
    	v_Count NUMBER := 0;
    BEGIN
		FOR  stat_cur IN (
			SELECT A.VIEW_NAME, A.TABLE_OWNER, A.TABLE_NAME, B.COLUMN_NAME
			FROM MVDATA_BROWSER_DESCRIPTIONS A
			join (
				SELECT SUBSTR(COLUMN_VALUE, 1, S_OFFSET - 1) VIEW_NAME, 
					SUBSTR(COLUMN_VALUE, S_OFFSET + 1) COLUMN_NAME
				FROM (
					SELECT COLUMN_VALUE, INSTR(COLUMN_VALUE,';') S_OFFSET FROM apex_string.split(p_Column_Names, ':')
				)
			) B ON B.VIEW_NAME = A.VIEW_NAME 
		)
		LOOP
 			DBMS_OUTPUT.PUT_LINE('-- Columns_Add_Required_Constraints ' || stat_cur.TABLE_NAME || '--');
			v_Stat :=	'ALTER TABLE ' || dbms_assert.enquote_name(stat_cur.TABLE_OWNER) || '.'  || dbms_assert.enquote_name(stat_cur.TABLE_NAME) 
				|| ' MODIFY ' 
				|| stat_cur.COLUMN_NAME
				|| ' NOT NULL';
			Run_Stat (v_Stat);
			v_Count := v_Count + 1;
		END LOOP;
    END Columns_Add_Required_Constraints;

	FUNCTION FN_Query_Uniqueness (
		p_Table_Name IN VARCHAR2,
		p_Column_Names IN VARCHAR2
	) RETURN VARCHAR2 -- YES / NO / N/A
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
		v_Query		VARCHAR2(32767);
		v_Result    PLS_INTEGER := 0;
   		cv 			SYS_REFCURSOR;
	BEGIN
		if p_Column_Names IS NOT NULL then
			v_Query := 'SELECT 1 FROM DUAL WHERE EXISTS (SELECT ' || p_Column_Names 
			|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) 
			|| ' GROUP BY ' || p_Column_Names 
			|| ' HAVING COUNT(*) > 1)';
			OPEN cv FOR v_Query;
			FETCH cv INTO v_Result;
			CLOSE cv;
			return case when v_Result = 1 then 'NO' else 'YES' end;
		else
			return 'N/A';
		end if;
	exception when NO_DATA_FOUND then
        return 'YES';
    when others then 
        return 'N/A';
	END FN_Query_Uniqueness;

	PROCEDURE Check_Unique_Constraints (p_Selected_Tables VARCHAR2)
	IS
		v_query VARCHAR2(4000);
		e_20104 exception;
		pragma exception_init(e_20104, -20104);
	BEGIN 
		v_query := q'[
		select VIEW_NAME, UNIQUE_COLUMN_NAMES, 
			NUM_ROWS, DATA_LENGTH, CHECK_UNIQUNESS, 
			case when DATA_LENGTH < 6398 then 'YES' else 'NO' end CHECK_DATA_LENGTH, 
			case when CHECK_UNIQUNESS = 'YES' and DATA_LENGTH < 6398 then 'YES' else 'NO' end CHECKS_OK
		from (
			select A.VIEW_NAME, B.UNIQUE_COLUMN_NAMES, A.NUM_ROWS,
				(SELECT SUM(C.DATA_LENGTH) DATA_LENGTH
					FROM TABLE( data_browser_conf.in_list(B.UNIQUE_COLUMN_NAMES, ', ')) D
					JOIN USER_TAB_COLS C ON D.COLUMN_VALUE  = C.COLUMN_NAME
					WHERE C.TABLE_NAME = A.TABLE_NAME
				) DATA_LENGTH, -- avoid ORA-01450: Maximale Schlüssellänge (6398) überschritten
				data_browser_ddl.FN_Query_Uniqueness(
					p_Table_Name=> A.VIEW_NAME, 
					p_Column_Names=> B.UNIQUE_COLUMN_NAMES
				) CHECK_UNIQUNESS
			from MVDATA_BROWSER_DESCRIPTIONS A
			join (
				SELECT SUBSTR(COLUMN_VALUE, 1, S_OFFSET - 1) VIEW_NAME, 
					SUBSTR(COLUMN_VALUE, S_OFFSET + 1) UNIQUE_COLUMN_NAMES
				FROM (
					SELECT COLUMN_VALUE, INSTR(COLUMN_VALUE,';') S_OFFSET FROM apex_string.split(:a, ':')
				)
			) B ON B.VIEW_NAME = A.VIEW_NAME 
		)
		order by VIEW_NAME
		]';
		APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
			p_collection_name => data_browser_conf.Get_Constraints_Collection, 
			p_query => v_query, 
			p_truncate_if_exists => 'YES',
			p_names => apex_util.string_to_table('a', chr(10)), 
			p_values => apex_util.string_to_table(p_Selected_Tables, chr(10))
		);
	exception
		when e_20104 then null;
    END Check_Unique_Constraints;

	FUNCTION FN_Query_Required (
		p_Table_Name IN VARCHAR2,
		p_Column_Name IN VARCHAR2
	) RETURN VARCHAR2 -- YES / NO / N/A
	IS
$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
	PRAGMA UDF;
$END
		v_Query		VARCHAR2(32767);
		v_Result    PLS_INTEGER := 0;
   		cv 			SYS_REFCURSOR;
	BEGIN
		if p_Column_Name IS NOT NULL then
			v_Query := 'SELECT 1 FROM DUAL WHERE EXISTS (SELECT 1' 
			|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) 
			|| ' WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(p_Column_Name)
			|| ' IS NULL)';
			OPEN cv FOR v_Query;
			FETCH cv INTO v_Result;
			CLOSE cv;
			return case when v_Result = 1 then 'NO' else 'YES' end;
		else
			return 'N/A';
		end if;
	exception when NO_DATA_FOUND then
        return 'YES';
    when others then 
        return 'N/A';
	END FN_Query_Required;


	PROCEDURE Check_Required_Constraints (p_Selected_Tables VARCHAR2)
	IS
		v_query VARCHAR2(4000);
		e_20104 exception;
		pragma exception_init(e_20104, -20104);
	BEGIN 
		v_query := q'[
		select VIEW_NAME, COLUMN_NAME, 
			NUM_ROWS, NUM_NULLS, CHECK_REQUIRED
		from (
			select A.VIEW_NAME, B.COLUMN_NAME, A.NUM_ROWS,
				C.NUM_NULLS,
				data_browser_ddl.FN_Query_Required(
					p_Table_Name=> A.VIEW_NAME, 
					p_Column_Name=> B.COLUMN_NAME) CHECK_REQUIRED
			from MVDATA_BROWSER_DESCRIPTIONS A
			join SYS.ALL_TAB_COLS C on C.TABLE_NAME = A.TABLE_NAME and C.OWNER = A.TABLE_OWNER
			join (
				SELECT SUBSTR(COLUMN_VALUE, 1, S_OFFSET - 1) VIEW_NAME, 
					SUBSTR(COLUMN_VALUE, S_OFFSET + 1) COLUMN_NAME
				FROM (
					SELECT COLUMN_VALUE, INSTR(COLUMN_VALUE,';') S_OFFSET FROM apex_string.split(:a, ':')
				)
			) B ON B.VIEW_NAME = A.VIEW_NAME AND B.COLUMN_NAME = C.COLUMN_NAME
			where NVL(C.NUM_NULLS, 0) = 0
			and C.NULLABLE = 'Y'
			and C.VIRTUAL_COLUMN = 'NO'
		)
		order by VIEW_NAME
		]';
		APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY_B (
			p_collection_name => data_browser_conf.Get_Constraints_Collection, 
			p_query => v_query, 
			p_truncate_if_exists => 'YES',
			p_names => apex_util.string_to_table('a', chr(10)), 
			p_values => apex_util.string_to_table(p_Selected_Tables, chr(10))
		);
	exception
		when e_20104 then null;
    END Check_Required_Constraints;

end data_browser_ddl;
/
show errors

