/*
Copyright 2019 Dirk Strack, Strack Software Development

All Rights Reserved
Unauthorized copying of this file, via any medium is strictly prohibited
Proprietary and confidential
Written by Dirk Strack <dirk_strack@yahoo.de>, Feb 2019
*/
 

/*
Blob support for the schema data browser application
*/

CREATE OR REPLACE PACKAGE BODY data_browser_blobs
IS
	c_Clob_Field_Collection CONSTANT VARCHAR2(50) := 'DATA_BROWSER_CLOBS';
	c_Clob_Field_Ref_Prefix CONSTANT VARCHAR2(50) := 'DATA_BROWSER_CLOBS_';
	---------------------------------------------------------------------------
	-- internal --
	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ', '
	)
    RETURN VARCHAR2 DETERMINISTIC
    IS
	PRAGMA UDF;
    BEGIN
    	RETURN
			case when p_First_Name IS NOT NULL and p_Second_Name IS NOT NULL
			then p_First_Name || p_Delimiter || p_Second_Name
			when p_First_Name IS NOT NULL
			then p_First_Name
			else p_Second_Name
			end;
    END;

	FUNCTION Enquote_Literal ( p_Text VARCHAR2 )
	RETURN VARCHAR2 DETERMINISTIC
	IS
		v_Quote CONSTANT VARCHAR2(1) := '''';
	BEGIN
		RETURN v_Quote || REPLACE(p_Text, v_Quote, v_Quote||v_Quote) || v_Quote ;
	END;

	FUNCTION fn_Blob_To_Clob(p_data IN BLOB, p_charset IN VARCHAR2 DEFAULT NULL)
	RETURN CLOB
   	IS
		l_clob   		CLOB;
		l_dest_offset  PLS_INTEGER := 1;
		l_src_offset   PLS_INTEGER := 1;
		l_lang_context PLS_INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
		l_warning      PLS_INTEGER;
		l_blob_csid    NUMBER;
		l_utf8_bom     raw(10) := hextoraw('EFBBBF');
		l_utf16_bom    raw(10) := hextoraw('FFFE');
		l_file_head    raw(10);
	 BEGIN
		if p_charset IS NOT NULL then
			l_blob_csid := nls_charset_id(p_charset);
		end if;
		if l_blob_csid IS NULL then
			l_blob_csid := DBMS_LOB.DEFAULT_CSID;
		end if;
		l_file_head := UTL_RAW.SUBSTR(p_data, 1, 3);
		if UTL_RAW.COMPARE (l_utf8_bom, l_file_head) = 0 then
			l_src_offset := 4;
			l_blob_csid := nls_charset_id('AL32UTF8');
		elsif UTL_RAW.COMPARE (l_utf16_bom, l_file_head) = 0 then
			l_src_offset := 3;
			l_blob_csid := nls_charset_id('AL16UTF16LE');
		end if;
		DBMS_LOB.CREATETEMPORARY(LOB_LOC => l_clob, CACHE => TRUE);

		DBMS_LOB.CONVERTTOCLOB(DEST_LOB     => l_clob,
							   SRC_BLOB     => p_data,
							   AMOUNT       => DBMS_LOB.LOBMAXSIZE,
							   DEST_OFFSET  => l_dest_offset,
							   SRC_OFFSET   => l_src_offset,
							   BLOB_CSID    => l_blob_csid,
							   LANG_CONTEXT => l_lang_context,
							   WARNING      => l_warning);

		RETURN l_clob;
  	END fn_Blob_To_Clob;

	PROCEDURE Table_File_Columns (
		p_Table_Name VARCHAR2,					-- Table name of a table with blob column and other file related columns
		p_Parent_Table VARCHAR2 DEFAULT NULL,	-- Parent View or Table name.
		p_Column_List OUT NOCOPY VARCHAR2,				-- FILE_NAME, MIME_TYPE, FILE_DATE, FILE_CONTENT, FOLDER_ID
		p_Values_List OUT NOCOPY VARCHAR2				-- :file_name, :mime_type, :file_date, :file_content, :folder_id
	)
	is
		v_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Parent_Key_Column VARCHAR2(128);
		v_File_Name_Column VARCHAR2(128);
		v_Mime_Type_Column VARCHAR2(128);
		v_File_Date_Column VARCHAR2(128);
		v_File_Content_Column VARCHAR2(128);
		v_Column_List	VARCHAR2(4000);
		v_Values_List	VARCHAR2(4000);
	begin
		SELECT FILE_NAME_COLUMN_NAME, MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME, FILE_CONTENT_COLUMN_NAME,
				(SELECT COLUMN_NAME
				FROM MVDATA_BROWSER_REFERENCES R
				WHERE R.VIEW_NAME = T.VIEW_NAME
				AND R.R_VIEW_NAME = p_Parent_Table
				AND ROWNUM = 1
				) PARENT_KEY_COLUMN
		INTO v_File_Name_Column, v_Mime_Type_Column, v_File_Date_Column, v_File_Content_Column, v_Parent_Key_Column
		FROM MVDATA_BROWSER_VIEWS T
		WHERE VIEW_NAME = v_Table_Name;

		if v_File_Name_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_File_Name_Column);
			v_Values_List := Concat_List(v_Values_List, ':file_name');
		end if;
		if v_Mime_Type_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_Mime_Type_Column);
			v_Values_List := Concat_List(v_Values_List, ':mime_type');
		end if;
		if v_File_Date_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_File_Date_Column);
			v_Values_List := Concat_List(v_Values_List, ':file_date');
		end if;
		if v_File_Content_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_File_Content_Column);
			v_Values_List := Concat_List(v_Values_List, ':file_content');
		end if;
		if v_Parent_Key_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_Parent_Key_Column);
			v_Values_List := Concat_List(v_Values_List, ':folder_id');
		end if;
		p_Column_List := v_Column_List;
		p_Values_List := v_Values_List;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_blobs.Table_File_Columns (p_Table_Name => %s, p_Parent_Table => %s)  p_Column_List : %s, p_Values_List : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Table),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Column_List),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Values_List),
				p_max_length => 3500
			);
		$END
	end Table_File_Columns;

	PROCEDURE Table_Unzip_File_Columns (
		p_Table_Name VARCHAR2,					-- Table name of a table with blob column and other file related columns
		p_Parent_Table VARCHAR2 DEFAULT NULL,	-- Parent View or Table name.
		p_Column_List OUT NOCOPY VARCHAR2,		-- FILE_CONTENT, FILE_NAME, FILE_DATE, MIME_TYPE, FOLDER_ID
		p_Values_List OUT NOCOPY VARCHAR2		-- :unzipped_file, :file_name, :file_date, :mime_type, :folder_id
	)
	is
		v_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Parent_Key_Column VARCHAR2(128);
		v_File_Name_Column VARCHAR2(128);
		v_Mime_Type_Column VARCHAR2(128);
		v_File_Date_Column VARCHAR2(128);
		v_File_Content_Column VARCHAR2(128);
		v_Column_List	VARCHAR2(4000);
		v_Values_List	VARCHAR2(4000);
	begin
		SELECT FILE_NAME_COLUMN_NAME, MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME, FILE_CONTENT_COLUMN_NAME, FILE_FOLDER_COLUMN_NAME
		INTO v_File_Name_Column, v_Mime_Type_Column, v_File_Date_Column, v_File_Content_Column, v_Parent_Key_Column
		FROM MVDATA_BROWSER_VIEWS T
		WHERE VIEW_NAME = v_Table_Name;

		if p_Parent_Table IS NOT NULL and v_Parent_Key_Column IS NULL then
			begin
				SELECT COLUMN_NAME
				INTO v_Parent_Key_Column
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = p_Parent_Table
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;


		if v_File_Content_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_File_Content_Column);
			v_Values_List := Concat_List(v_Values_List, ':unzipped_file');
		end if;
		if v_File_Name_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_File_Name_Column);
			v_Values_List := Concat_List(v_Values_List, ':file_name');
		end if;
		if v_File_Date_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_File_Date_Column);
			v_Values_List := Concat_List(v_Values_List, ':file_date');
		end if;
		if v_Mime_Type_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_Mime_Type_Column);
			v_Values_List := Concat_List(v_Values_List, ':mime_type');
		end if;
		if v_Parent_Key_Column IS NOT NULL then
			v_Column_List := Concat_List(v_Column_List, v_Parent_Key_Column);
			v_Values_List := Concat_List(v_Values_List, ':folder_id');
		end if;
		p_Column_List := v_Column_List;
		p_Values_List := v_Values_List;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_blobs.Table_Unzip_File_Columns (p_Table_Name => %s, p_Parent_Table => %s)  p_Column_List : %s, p_Values_List : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Table),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Column_List),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Values_List),
				p_max_length => 3500
			);
		$END
	end Table_Unzip_File_Columns;

	PROCEDURE Execute_Load_file_query (
		p_Load_file_query 	IN VARCHAR2,		-- SELECT FILE_NAME, MIME_TYPE, FILE_DATE, FILE_CONTENT, FOLDER_ID FROM DEMO_FILES WHERE AND ID = :search_value
		p_Values_List 		IN VARCHAR2,		-- :file_name, :mime_type, :file_date, :file_content, :folder_id
		p_Search_Value 		IN VARCHAR2,
		p_File_Name 		OUT NOCOPY VARCHAR2,
		p_Mime_Type 		OUT NOCOPY VARCHAR2,
		p_File_Date 		OUT DATE,
		p_File_Content		OUT NOCOPY BLOB,
		p_Folder_Id 		OUT NUMBER
	)
	is
		v_cur 		PLS_INTEGER;
		v_rows 		PLS_INTEGER;
		v_col_cnt 	PLS_INTEGER;
		v_col_ind   PLS_INTEGER;
		v_rec_tab 	DBMS_SQL.DESC_TAB2;
	begin
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_blobs.Execute_Load_file_query (p_Load_file_query => %s, p_Values_List => %s, p_Search_Value => %s)',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Load_file_query),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Values_List),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Search_Value),
				p_max_length => 3500
			);
		$END
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Load_file_query, DBMS_SQL.NATIVE);
		IF p_Search_Value IS NOT NULL then
			dbms_sql.bind_variable(v_cur, ':search_value', p_Search_Value);
		end if;
		dbms_sql.describe_columns2(v_cur, v_col_cnt, v_rec_tab);
		$IF data_browser_conf.g_debug $THEN
			for j in 1..v_col_cnt loop
				apex_debug.info(p_message => 'data_browser_blobs.Execute_Load_file_query - col_name : ' || v_rec_tab(j).col_name || ', type: ' || v_rec_tab(j).col_type);
			end loop;
		$END
		--for j in 1..v_col_cnt loop
		--	dbms_output.put_line('col_name : ' || v_rec_tab(j).col_name || ', type: ' || v_rec_tab(j).col_type);
		--end loop;
		v_col_ind := 1;
		if instr(p_Values_List, ':file_name') > 0 then
			dbms_sql.define_column(v_cur, v_col_ind, p_File_Name, 1024);
			v_col_ind := v_col_ind + 1;
		end if;
		if instr(p_Values_List, ':mime_type') > 0 then
			dbms_sql.define_column(v_cur, v_col_ind, p_Mime_Type, 1024);
			v_col_ind := v_col_ind + 1;
		end if;
		if instr(p_Values_List, ':file_date') > 0 then
			dbms_sql.define_column(v_cur, v_col_ind, p_File_Date);
			v_col_ind := v_col_ind + 1;
		end if;
		if instr(p_Values_List, ':file_content') > 0 then
			dbms_sql.define_column(v_cur, v_col_ind, p_File_Content);
			v_col_ind := v_col_ind + 1;
		end if;
		if instr(p_Values_List, ':folder_id') > 0 then
			dbms_sql.define_column(v_cur, v_col_ind, p_Folder_Id);
			v_col_ind := v_col_ind + 1;
		end if;

		v_rows := dbms_sql.execute_and_fetch (v_cur);
		if v_rows > 0 then
			v_col_ind := 1;
			if instr(p_Values_List, ':file_name') > 0 then
				dbms_sql.column_value(v_cur, v_col_ind, p_File_Name);
				v_col_ind := v_col_ind + 1;
			end if;
			if instr(p_Values_List, ':mime_type') > 0 then
				dbms_sql.column_value(v_cur, v_col_ind, p_Mime_Type);
				v_col_ind := v_col_ind + 1;
			end if;
			if instr(p_Values_List, ':file_date') > 0 then
				dbms_sql.column_value(v_cur, v_col_ind, p_File_Date);
				v_col_ind := v_col_ind + 1;
			end if;
			if instr(p_Values_List, ':file_content') > 0 then
				dbms_sql.column_value(v_cur, v_col_ind, p_File_Content);
				v_col_ind := v_col_ind + 1;
			end if;
			if instr(p_Values_List, ':folder_id') > 0 then
				dbms_sql.column_value(v_cur, v_col_ind, p_Folder_Id);
				v_col_ind := v_col_ind + 1;
			end if;
		end if;
		dbms_sql.close_cursor(v_cur);
	exception
	  when others then
		dbms_sql.close_cursor(v_cur);
		raise;
	end Execute_Load_file_query;

	PROCEDURE Save_File_to_Table (
		p_Save_File_Code VARCHAR2,
		p_File_Content BLOB,
		p_File_Name	VARCHAR2,
		p_File_Date DATE,
		p_Mime_Type	VARCHAR2,
		p_File_Size	INTEGER DEFAULT NULL,
		p_Folder_Id	INTEGER DEFAULT NULL
	)
	is
		v_cur INTEGER;
		v_rows INTEGER;
	begin
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_blobs.Save_File_to_Table (p_Save_File_Code => %s, p_File_Name => %s)  p_File_Date : %s, p_Mime_Type : %s, p_File_Size : %s, p_Folder_Id : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Save_File_Code),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_File_Name),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(p_File_Date),
				p3 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Mime_Type),
				p4 => p_File_Size,
				p5 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Folder_Id),
				p_max_length => 3500
			);
		$END
		-- dbms_output.put_line('Save_Unzipped_File: '||p_Folder_Id ||' ,' || p_File_Name || ', ' || p_File_Date);
		-- :folder_id, :unzipped_file, :file_name, :file_date, :file_size, :mime_type
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, 'begin ' || p_Save_File_Code || ' end;', DBMS_SQL.NATIVE);
		if instr(p_Save_File_Code, ':folder_id') > 0 then
			dbms_sql.bind_variable(v_cur, ':folder_id', p_Folder_Id);
		end if;
		if instr(p_Save_File_Code, ':file_content') > 0 then
			dbms_sql.bind_variable(v_cur, ':file_content', p_File_Content);
		end if;
		if instr(p_Save_File_Code, ':file_name') > 0 then
			dbms_sql.bind_variable(v_cur, ':file_name', p_File_Name);
		end if;
		if instr(p_Save_File_Code, ':file_date') > 0 then
			dbms_sql.bind_variable(v_cur, ':file_date', p_File_Date);
		end if;
		if instr(p_Save_File_Code, ':file_size') > 0 then
			dbms_sql.bind_variable(v_cur, ':file_size', p_File_Size);
		end if;
		if instr(p_Save_File_Code, ':mime_type') > 0 then
			dbms_sql.bind_variable(v_cur, ':mime_type', p_Mime_Type);
		end if;
		v_rows := dbms_sql.execute(v_cur);
		dbms_sql.close_cursor(v_cur);
	exception
	when others then
		dbms_sql.close_cursor(v_cur);
		raise;
	end Save_File_to_Table;

	-- upload files --
	FUNCTION Can_Upload_Files(
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL			-- Parent View or Table name.
	)
	RETURN VARCHAR2 -- YES/NO
	is
		v_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_File_Content_Column MVDATA_BROWSER_VIEWS.FILE_CONTENT_COLUMN_NAME%TYPE;
		v_Parent_Key_Column VARCHAR2(128);
		v_Key_Cols_Count pls_integer;
		v_Missing_Count pls_integer;
	begin
		if v_Table_Name IS NULL then
			return 'NO';
		end if;
		if p_Parent_Table IS NOT NULL then
			begin
				SELECT COLUMN_NAME
				INTO v_Parent_Key_Column
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = p_Parent_Table
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				return 'NO';
			end;
		end if;

		begin
			SELECT FILE_CONTENT_COLUMN_NAME, KEY_COLS_COUNT,
				( SELECT COUNT(*)
					FROM SYS.ALL_TAB_COLUMNS C
					WHERE T.TABLE_NAME = C.TABLE_NAME
					AND T.TABLE_OWNER = C.OWNER
					AND (C.NULLABLE = 'N' AND DEFAULT_LENGTH = 0)
					AND C.COLUMN_NAME NOT IN (SEARCH_KEY_COLS, FILE_NAME_COLUMN_NAME, MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME, FILE_CONTENT_COLUMN_NAME)
					AND (C.COLUMN_NAME != v_Parent_Key_Column OR v_Parent_Key_Column IS NULL)
				) MISSING_CNT
			INTO v_File_Content_Column, v_Key_Cols_Count, v_Missing_Count
			FROM MVDATA_BROWSER_VIEWS T
			WHERE T.VIEW_NAME = v_Table_Name;
		exception when NO_DATA_FOUND then
			return 'NO';
		end;

        return case
        	when v_File_Content_Column IS NOT NULL
			and v_Key_Cols_Count = 1
			and v_Missing_Count = 0
				then 'YES'
				else 'NO'
		end;
	end Can_Upload_Files;

	FUNCTION Can_Upload_Zip_Files(
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL			-- Parent View or Table name.
	)
	RETURN VARCHAR2 -- YES/NO
	is
		v_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Parent_Table MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Parent_Table);
		v_Folder_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE;
		v_Files_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE;
		v_Folder_Ref_Column VARCHAR2(128);
		v_Key_Cols_Count pls_integer;
		v_Missing_Count pls_integer;
	begin
		if v_Table_Name IS NULL then
			return 'NO';
		end if;
		if v_Parent_Table IS NOT NULL then	
			begin -- assume v_Parent_Table is a folder table
				SELECT VIEW_NAME, R_VIEW_NAME, COLUMN_NAME
				INTO v_Files_Table_Name, v_Folder_Table_Name, v_Folder_Ref_Column -- the folder reference 
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = v_Parent_Table
				AND FOLDER_NAME_COLUMN_NAME IS NOT NULL
				AND FOLDER_PARENT_COLUMN_NAME IS NOT NULL
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;
		if v_Files_Table_Name IS NULL then 
			begin -- assume v_Table_name is a folder table
				SELECT VIEW_NAME, R_VIEW_NAME, COLUMN_NAME
				INTO v_Files_Table_Name, v_Folder_Table_Name, v_Folder_Ref_Column -- the folder reference 
				FROM MVDATA_BROWSER_REFERENCES
				WHERE R_VIEW_NAME = v_Table_name
				AND FOLDER_NAME_COLUMN_NAME IS NOT NULL
				AND FOLDER_PARENT_COLUMN_NAME IS NOT NULL
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				return 'NO';
			end;
		end if;
		
		begin -- get folder table properties
			SELECT KEY_COLS_COUNT,
				( SELECT COUNT(*)
					FROM SYS.ALL_TAB_COLUMNS C
					WHERE T.TABLE_NAME = C.TABLE_NAME
					AND T.TABLE_OWNER = C.OWNER
					AND (C.NULLABLE = 'N' AND DEFAULT_LENGTH = 0)
					AND C.COLUMN_NAME NOT IN (SEARCH_KEY_COLS, FOLDER_NAME_COLUMN_NAME, FOLDER_PARENT_COLUMN_NAME)
				) MISSING_CNT
			INTO v_Key_Cols_Count, v_Missing_Count
			FROM MVDATA_BROWSER_DESCRIPTIONS T
			WHERE T.VIEW_NAME = v_Folder_Table_Name;
		exception when NO_DATA_FOUND then
			return 'NO';
		end;
		if v_Key_Cols_Count = 1
		and v_Missing_Count = 0 then 		
			begin -- get files table properties
				SELECT KEY_COLS_COUNT,
					( SELECT COUNT(*)
						FROM SYS.ALL_TAB_COLUMNS C
						WHERE T.TABLE_NAME = C.TABLE_NAME
						AND T.TABLE_OWNER = C.OWNER
						AND (C.NULLABLE = 'N' AND DEFAULT_LENGTH = 0)
						AND C.COLUMN_NAME NOT IN (FILE_NAME_COLUMN_NAME, MIME_TYPE_COLUMN_NAME, FILE_DATE_COLUMN_NAME,FILE_CONTENT_COLUMN_NAME,FILE_FOLDER_COLUMN_NAME,v_Folder_Ref_Column)
						AND data_browser_conf.Match_Column_Pattern(C.COLUMN_NAME, REPLACE(SEARCH_KEY_COLS, ' ')) = 'NO'
					) MISSING_CNT
				INTO v_Key_Cols_Count, v_Missing_Count
				FROM MVDATA_BROWSER_VIEWS T 
				WHERE T.VIEW_NAME = v_Files_Table_Name
				AND T.FILE_CONTENT_COLUMN_NAME IS NOT NULL
				AND T.FILE_NAME_COLUMN_NAME IS NOT NULL
				AND (T.FILE_FOLDER_COLUMN_NAME IS NOT NULL or v_Folder_Ref_Column IS NOT NULL)
				AND ROWNUM = 1;
				
				if v_Key_Cols_Count = 1
				and v_Missing_Count = 0 then 		
					return Can_Upload_Files(
						p_Table_Name => v_Files_Table_Name,
						p_Parent_Table => v_Folder_Table_Name
					);
				end if;
			exception when NO_DATA_FOUND then
				return 'NO';
			end;
		end if;
		
        return 'NO';
	end Can_Upload_Zip_Files;

	FUNCTION Can_Upload_File_List(
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL			-- Parent View or Table name.
	)
	RETURN VARCHAR2 -- YES/NO
	is
	begin
        return case when Can_Upload_Files(p_Table_Name, p_Parent_Table) = 'YES' 
        	or Can_Upload_Zip_Files(p_Table_Name, p_Parent_Table) = 'YES' then 'YES' else 'NO' end;
	end Can_Upload_File_List;

	PROCEDURE Upload_Zip_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2)
	is
		v_message		VARCHAR2(4000);
	begin
		if p_SQLCode = 0 then 
			v_message := 'OK';
		else 
			v_message := p_Message;
		end if;
		INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  ('Unzip File', p_Filename || ':' || p_SQLCode || ':' || v_message);
		COMMIT;
	end;

	FUNCTION Get_Zip_Upload_Result (
		p_File_Names VARCHAR2,
		p_App_User VARCHAR2 DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER'),
		p_Start_Date TIMESTAMP 
	) RETURN VARCHAR2 
	is
		v_Message VARCHAR2(32767);
		v_End_Date TIMESTAMP;
		v_Seconds VARCHAR2(30);
	begin
		v_End_Date := p_Start_Date;
		for c_cur in (
			SELECT SUBSTR(A.name, 1, 256) name, 
				SUBSTR(B.filename, 1, 256) filename,
                case when B.result_code = '0' then 'OK' else SUBSTR(B.error_message, 1, 256) end message,
				B.LOGGING_DATE
			from (
				select column_value name from table(apex_string.split(p_File_Names,':'))
			) A 
			LEFT OUTER JOIN (
				SELECT SUBSTR(REMARKS, OFFSET0+1, OFFSET1-OFFSET0-1) filename,
                    SUBSTR(REMARKS, 1, OFFSET1-1) pathname,
					SUBSTR(REMARKS, OFFSET1 +1, OFFSET2 - OFFSET1) result_code,
					SUBSTR(REMARKS, OFFSET2 +1) error_message,
					LOGGING_DATE
				FROM (
					SELECT LOGGING_DATE, REMARKS, 
						INSTR(REMARKS, '/', 1, 1) OFFSET0, 
						INSTR(REMARKS, ':', 1, 1) OFFSET1, 
						INSTR(REMARKS, ':', 1, 2) OFFSET2
					FROM APP_PROTOCOL
					WHERE Description = 'Unzip File'
					AND LOGGING_USER = p_App_User
					AND LOGGING_DATE >= p_Start_Date
				)
			) B ON B.pathname = A.name
		) loop 
			v_Message := v_Message || 
				c_cur.filename || ' - ' || c_cur.message || chr(10);
			if c_cur.LOGGING_DATE > v_End_Date then 
				v_End_Date := c_cur.LOGGING_DATE;
			end if;
		end loop;

		select (extract(hour from diff ) * 60 + extract(minute from diff ))
				|| ':' 
                || round(extract(second from diff), 2)
		into v_Seconds
		from (select v_End_Date - p_Start_Date diff from dual);
		
		return apex_lang.lang('%0. Unzip completed in %1 min:sec. ', p0 => v_Message, p1 =>v_Seconds);
	end Get_Zip_Upload_Result;

	PROCEDURE Upload_Files (
		p_File_Names VARCHAR2,
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
		p_Unzip_Files VARCHAR2 DEFAULT 'YES',			-- unzip uploaded files
    	p_File_Dates VARCHAR2 DEFAULT NULL,				-- list of dates in format DD.MM.YY HH24:MI:SS delimited by |
    	p_File_Names2 VARCHAR2 DEFAULT NULL				-- list of file names delimited by |
	)
	is
		v_Column_List	VARCHAR2(4000);
		v_Values_List	VARCHAR2(4000);
		v_Save_File_Code VARCHAR2(4000);
	begin
		Table_File_Columns (
			p_Table_Name => p_Table_Name,
			p_Parent_Table => p_Parent_Table,
			p_Column_List => v_Column_List,
			p_Values_List => v_Values_List				-- :file_name, :mime_type, :file_date, :file_content, :folder_id
		);

		v_Save_File_Code := 'INSERT INTO ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) || ' (' || v_Column_List || ')'
						|| chr(10) || 'VALUES (' || v_Values_List || ');';
		
		for c_cur in (
			with dates_q as (
				SELECT n.file_name, m.file_date, n.rn
				from (
					SELECT column_value file_name, ROWNUM RN 
					from table(apex_string.split( p_File_Names2,'|'))
				) n join (
					SELECT TO_DATE(column_value, 'DD.MM.YYYY HH24:MI:SS') file_date, ROWNUM RN 
					from table(apex_string.split( p_File_Dates,'|'))
				) m on n.rn = m.rn	
			)
			select name, filename, mime_type, nvl(d.file_date, t.created_on) created_on, blob_content
			from apex_application_temp_files t 
			left outer join dates_q d on t.filename = d.file_name
			where (LOWER(mime_type) != 'application/zip' or p_Unzip_Files = 'NO' )
			and name in (select column_value from table(apex_string.split( p_File_Names,':')))
		)
		loop			
			-- Save_File_to_Table (:file_content, :file_name, :file_date, :file_size, :mime_type, :folder_id));
			data_browser_blobs.Save_File_to_Table(
				p_Save_File_Code => v_Save_File_Code
				, p_Folder_Id => case when p_Parent_Key_Item IS NOT NULL then APEX_UTIL.GET_SESSION_STATE(p_Parent_Key_Item) end
				, p_File_Content => c_cur.blob_content
				, p_File_Name => c_cur.filename
				, p_File_Date => c_cur.created_on
				, p_Mime_Type => c_cur.mime_type
			);
			delete from apex_application_temp_files
			where name = c_cur.name;
		end loop;
	end Upload_Files;

	FUNCTION Get_Folder_Path(
		p_Table_Name VARCHAR2,
		p_Folder_Primary_Key_Col VARCHAR2,
		p_Search_Value VARCHAR2,
		p_Folder_Name_Column_Name VARCHAR2,
		p_Folder_Parent_Column_Name VARCHAR2,
		p_Parent_Key_Column VARCHAR2,
		p_Parent_Key_Value VARCHAR2
	) RETURN VARCHAR2 
	IS
		v_Path_Name VARCHAR2(4000);
		v_Query VARCHAR2(4000);
   		cv 			SYS_REFCURSOR;
	BEGIN
		v_Query := 'SELECT PATH FROM (' ||
		'SELECT ' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Primary_Key_Col) 
		|| ', SYS_CONNECT_BY_PATH(TRANSLATE(' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Name_Column_Name) || q'[, '/', '-'), '/') PATH]' || chr(10) ||
		'FROM (SELECT ' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Primary_Key_Col) || ', ' 
		|| DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Parent_Column_Name) || ', ' 
		|| DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Name_Column_Name) 
		|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) 
		|| case when p_Parent_Key_Column IS NOT NULL and p_Parent_Key_Value IS NOT NULL then 
			'WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(p_Parent_Key_Column) || ' = ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Value)
		end
		|| ') T ' || chr(10) 
		|| 'START WITH  ' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Parent_Column_Name) || ' IS NULL' || chr(10) 
		|| 'CONNECT BY ' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Parent_Column_Name) 
		|| ' = PRIOR ' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Primary_Key_Col) || ')' || chr(10) 
		|| case when p_Search_Value IS NOT NULL then 
			'WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(p_Folder_Primary_Key_Col) || ' = ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Search_Value)
		end;
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_blobs.Get_Folder_Path (p_Table_Name => %s, p_Parent_Key_Value => %s)  v_Query : %s, v_Path_Name : %s, p_Parent_Key_Value : %s',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Value),
				p2 => v_Query,
				p3 => v_Path_Name,
				p4 => p_Parent_Key_Value,
				p_max_length => 3500
			);
		$END
		OPEN cv FOR v_Query;
		FETCH cv INTO v_Path_Name;
		CLOSE cv;
		
		RETURN v_Path_Name;
	END;


	PROCEDURE Upload_Zip_Files (
		p_File_Names VARCHAR2,
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
    	p_File_Dates VARCHAR2 DEFAULT NULL,				-- list of dates in format DD.MM.YY HH24:MI:SS delimited by |
    	p_File_Names2 VARCHAR2 DEFAULT NULL,			-- list of file names delimited by |
    	p_context BINARY_INTEGER 
	)
	is
		v_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Table_Name);
		v_Parent_Table MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE := UPPER(p_Parent_Table);
		v_Folder_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE;
		v_Files_Table_Name MVDATA_BROWSER_VIEWS.VIEW_NAME%TYPE;
		v_Folder_Ref_Column VARCHAR2(128);
		v_Folder_Primary_Key_Col MVDATA_BROWSER_VIEWS.SEARCH_KEY_COLS%TYPE;
		v_Folder_Name_Column_Name MVDATA_BROWSER_VIEWS.FOLDER_NAME_COLUMN_NAME%TYPE;
		v_Folder_Parent_Column_Name MVDATA_BROWSER_VIEWS.FOLDER_PARENT_COLUMN_NAME%TYPE;
		v_Container_Table 		VARCHAR2(128); -- Container table
		v_Container_Key_Column VARCHAR2(128);
		v_Container_Key_Value NUMBER;
		v_Key_Cols_Count pls_integer;
		v_Missing_Count pls_integer;
		v_Zip_File_Count pls_integer;
		v_Search_Value	VARCHAR2(1024);
		v_file_names 	apex_application_global.vc_arr2;
		v_Column_List	VARCHAR2(4000);
		v_Values_List	VARCHAR2(4000);
		v_Init_Session_Code VARCHAR2(4000);
		v_Load_Zip_File_Query VARCHAR2(4000);
		v_Delete_Zip_File_Query  VARCHAR2(4000);
		v_Folder_query  VARCHAR2(4000);
		v_Parent_Folder VARCHAR2(4000) := '/Home';
		v_Filter_Path_Cond VARCHAR2(4000) := 'instr(:path_name, ''__MACOSX/'') != 1 and instr(:path_name, ''/.'') = 0';
		v_Completion_Procedure VARCHAR2(4000) := 'data_browser_blobs.Upload_Zip_Completion';
		v_Save_File_Code VARCHAR2(4000);
		v_Process_Text  VARCHAR2(4000);
		v_message		VARCHAR2(4000);
		v_SQLCode 		INTEGER;
		v_Query 		VARCHAR2(4000);
   		cv 				SYS_REFCURSOR;
	begin
		$IF data_browser_conf.g_debug $THEN
			apex_debug.message(
				p_message => 'data_browser_blobs.Upload_Zip_Files (p_File_Names => %s, p_Table_Name => %s, p_Parent_Table => %s, ' || chr(10) 
					|| 'p_Parent_Key_Item => %s, p_File_Dates => %s, p_File_Names2 => %s, p_context => %s)',
				p0 => p_File_Names,
				p1 => p_Table_Name,
				p2 => p_Parent_Table,
				p3 => p_Parent_Key_Item,
				p4 => p_File_Dates,
				p5 => p_File_Names2, 
				p6 => p_context, 
				p_max_length => 3500
			);
		$END
		SELECT COUNT(*) 
		INTO v_Zip_File_Count
		FROM apex_application_temp_files
		WHERE LOWER(mime_type) = 'application/zip'
		AND name in (select column_value from table(apex_string.split( p_File_Names,':')));
		
		/* possible constellation: 
			1.
				p_Table_Name is a Files_Table_Name
				p_Parent_Table is a Folder_Table_Name
			2. 
				p_Table_Name is a Folder_Table_Name
				p_Parent_Table is Container_Table 
			3. 
				p_Table_Name is a Folder_Table_Name
				p_Parent_Table is null 				
		*/
		if v_Parent_Table IS NOT NULL then	
			begin -- assume v_Parent_Table is a folder table
				SELECT VIEW_NAME, R_VIEW_NAME, COLUMN_NAME
				INTO v_Files_Table_Name, v_Folder_Table_Name, v_Folder_Ref_Column -- the folder reference 
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Table_name
				AND R_VIEW_NAME = v_Parent_Table
				AND FOLDER_NAME_COLUMN_NAME IS NOT NULL
				AND FOLDER_PARENT_COLUMN_NAME IS NOT NULL
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				null;
			end;
		end if;
		if v_Files_Table_Name IS NULL then 
			begin -- assume v_Table_name is a folder table
				SELECT VIEW_NAME, R_VIEW_NAME, COLUMN_NAME
				INTO v_Files_Table_Name, v_Folder_Table_Name, v_Folder_Ref_Column -- the folder reference 
				FROM MVDATA_BROWSER_REFERENCES
				WHERE R_VIEW_NAME = v_Table_name
				AND FOLDER_NAME_COLUMN_NAME IS NOT NULL
				AND FOLDER_PARENT_COLUMN_NAME IS NOT NULL
				AND ROWNUM = 1;
			exception when NO_DATA_FOUND then
				return;
			end;
		end if;

		if v_Zip_File_Count > 0 then 
			begin
				SELECT SEARCH_KEY_COLS, FOLDER_NAME_COLUMN_NAME, FOLDER_PARENT_COLUMN_NAME, KEY_COLS_COUNT
				INTO v_Folder_Primary_Key_Col, v_Folder_Name_Column_Name, v_Folder_Parent_Column_Name, v_Key_Cols_Count
				FROM MVDATA_BROWSER_DESCRIPTIONS T
				WHERE T.VIEW_NAME = v_Folder_Table_Name;
			exception when NO_DATA_FOUND then
				return;
			end;

			if v_Parent_Table = v_Folder_Table_Name then 
				-- Parent_Table is a folder 
				-- lookup reference to container key from current folder 
				begin
					SELECT COLUMN_NAME, R_VIEW_NAME
					INTO v_Container_Key_Column, v_Container_Table
					FROM MVDATA_BROWSER_REFERENCES
					WHERE VIEW_NAME = v_Folder_Table_Name
					AND R_VIEW_NAME != VIEW_NAME
					AND FK_NULLABLE = 'N'
					AND DELETE_RULE = 'CASCADE'
					AND ROWNUM = 1;

					-- lookup Container Ref value
					v_Query := 'select ' || v_Container_Key_Column || ' from ' || v_Parent_Table || ' where '
					|| v_Folder_Primary_Key_Col || ' = V(' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Parent_Key_Item) || ')';

					$IF data_browser_conf.g_debug $THEN
						apex_debug.message(
							p_message => 'data_browser_blobs.Upload_Zip_Files (v_Folder_Table_Name : %s, v_Parent_Table : %s, v_Container_Table : %s, ' || chr(10) 
								|| 'v_Container_Key_Column : %s, v_Folder_Primary_Key_Col : %s, p_Parent_Key_Item : %s, v_Query => %s)',
							p0 => v_Folder_Table_Name,
							p1 => v_Parent_Table,
							p2 => v_Container_Table,
							p3 => v_Container_Key_Column,
							p4 => v_Folder_Primary_Key_Col,
							p5 => p_Parent_Key_Item, 
							p6 => v_Query, 
							p_max_length => 3500
						);
					$END

					OPEN cv FOR v_Query;
					FETCH cv INTO v_Container_Key_Value;	
					CLOSE cv;
					v_Search_Value := V(p_Parent_Key_Item);

				exception when NO_DATA_FOUND then
					null;
				end;
				if v_Container_Key_Value IS NULL then 
					RAISE_APPLICATION_ERROR(-20006, 'Upload of zip files failed because no container for the folder is specified.');
				end if;
				v_Parent_Folder := Get_Folder_Path(
					p_Table_Name => v_Folder_Table_Name,
					p_Folder_Primary_Key_Col => v_Folder_Primary_Key_Col,
					p_Search_Value => v_Search_Value,
					p_Folder_Name_Column_Name => v_Folder_Name_Column_Name,
					p_Folder_Parent_Column_Name => v_Folder_Parent_Column_Name,
					p_Parent_Key_Column => v_Container_Key_Column,
					p_Parent_Key_Value => v_Container_Key_Value
				);
			elsif v_Parent_Table IS NOT NULL then 
				-- Parent_Table is a container
				-- lookup column name of the container key
				SELECT COLUMN_NAME
				INTO v_Container_Key_Column
				FROM MVDATA_BROWSER_REFERENCES
				WHERE VIEW_NAME = v_Folder_Table_Name
				AND R_VIEW_NAME = v_Parent_Table
				AND ROWNUM = 1;
			
				v_Container_Table := v_Parent_Table;
				v_Container_Key_Value := V(p_Parent_Key_Item);
				if v_Container_Key_Value IS NULL then 
					RAISE_APPLICATION_ERROR(-20006, 'Upload of zip files failed because no container for the folder is specified.');
				end if;
			end if;

			SELECT COUNT(*)
			INTO v_Missing_Count
			FROM SYS.ALL_TAB_COLUMNS C
			WHERE C.TABLE_NAME = v_Folder_Table_Name
			AND C.OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
			AND (C.NULLABLE = 'N' AND DEFAULT_LENGTH = 0)
			AND (C.COLUMN_NAME != v_Folder_Primary_Key_Col OR v_Folder_Primary_Key_Col IS NULL)
			AND (C.COLUMN_NAME != v_Folder_Name_Column_Name OR v_Folder_Name_Column_Name IS NULL)
			AND (C.COLUMN_NAME != v_Folder_Parent_Column_Name OR v_Folder_Parent_Column_Name IS NULL)
			AND (C.COLUMN_NAME != v_Container_Key_Column OR v_Container_Key_Column IS NULL);

			$IF data_browser_conf.g_debug $THEN
				apex_debug.message(
					p_message => 'data_browser_blobs.Upload_Zip_Files - v_Table_name : %s, v_Parent_Table : %s, v_Files_Table_Name : %s, v_Folder_Table_Name : %s, ' || chr(10) 
						|| 'v_Folder_Ref_Column : %s, v_Folder_Primary_Key_Col : %s, v_Folder_Name_Column_Name : %s, v_Folder_Parent_Column_Name : %s, v_Key_Cols_Count : %s' || chr(10) 
						|| 'v_Container_Table : %s, v_Container_Key_Column : %s, v_Container_Key_Value : %s, v_Missing_Count : %s',
					p0 => v_Table_name,
					p1 => v_Parent_Table,
					p2 => v_Files_Table_Name,
					p3 => v_Folder_Table_Name,
					p4 => v_Folder_Ref_Column,
					p5 => v_Folder_Primary_Key_Col, 
					p6 => v_Folder_Name_Column_Name, 
					p7 => v_Folder_Parent_Column_Name, 
					p8 => v_Key_Cols_Count,
					p9 => v_Container_Table,
					p10 => v_Container_Key_Column,
					p11 => v_Container_Key_Value,
					p12 => v_Missing_Count,
					p_max_length => 3500
				);
			$END

			if v_Folder_Name_Column_Name IS NOT NULL
			and v_Folder_Parent_Column_Name IS NOT NULL
			and v_Key_Cols_Count = 1
			and v_Missing_Count = 0 then 		
				begin
					if Can_Upload_Files( p_Table_Name => v_Files_Table_Name, p_Parent_Table => v_Folder_Table_Name) = 'YES' then
						Table_Unzip_File_Columns (
							p_Table_Name => v_Files_Table_Name,
							p_Parent_Table => v_Folder_Table_Name,
							p_Column_List => v_Column_List,		-- FILE_CONTENT, FILE_NAME, FILE_DATE, MIME_TYPE, FOLDER_ID
							p_Values_List => v_Values_List		-- :unzipped_file, :file_name, :file_date, :mime_type, :folder_id
						);
						v_Init_Session_Code :=
						'apex_session.attach ('
						|| 'p_app_id=>' || V('APP_ID') || ', ' 
						|| 'p_page_id=>' || V('APP_PAGE_ID') || ', ' 
						|| 'p_session_id=>' || V('APP_SESSION') 
						|| ');';
					
						v_Load_Zip_File_Query :=
						'select BLOB_CONTENT, FILENAME' || chr(10) ||
						'from APEX_APPLICATION_TEMP_FILES' || chr(10) ||
						'where LOWER(MIME_TYPE) = ''application/zip'' ' || chr(10) ||
						'and NAME = :search_value';
						v_Delete_Zip_File_Query := 
						'delete from APEX_APPLICATION_TEMP_FILES' || chr(10) ||
						'where LOWER(MIME_TYPE) = ''application/zip'' ' || chr(10) ||
						'and NAME = :search_value';
						v_Folder_query := 
						'select ' || v_Folder_Primary_Key_Col 
						|| ', ' || v_Folder_Parent_Column_Name 
						|| ', ' || v_Folder_Name_Column_Name 
						|| case when v_Container_Key_Column IS NOT NULL then ', ' || v_Container_Key_Column end
						|| ' from ' || v_Folder_Table_Name;
						-- v_Parent_Folder := case when p_Parent_Key_Item IS NOT NULL then APEX_UTIL.GET_SESSION_STATE(p_Parent_Key_Item) end;
						v_Save_File_Code := 
						'INSERT INTO ' || DBMS_ASSERT.ENQUOTE_NAME(v_Files_Table_Name) || ' (' || v_Column_List ||')' || chr(10) 
						|| 'VALUES (' || v_Values_List || ');';
					
						$IF data_browser_conf.g_debug $THEN
							apex_debug.info(
								p_message => 'data_browser_blobs.Upload_Zip_Files (p_Table_Name => %s, v_Files_Table_Name => %s)  v_Load_Zip_File_Query : %s, v_Folder_query : %s, v_Save_File_Code : %s',
								p0 => DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name),
								p1 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Files_Table_Name),
								p2 => v_Load_Zip_File_Query,
								p3 => v_Folder_query,
								p4 => v_Save_File_Code,
								p_max_length => 3500
							);
						$END
						v_Process_Text :=
							'begin Unzip_Parallel.Expand_Zip_Archive_Job(' || chr(10)
							|| 'p_Init_Session_Code => q''{' || v_Init_Session_Code || '}'',' || chr(10) 
							|| 'p_Load_Zip_Query => q''{' || v_Load_Zip_File_Query || '}'',' || chr(10) 
							|| 'p_Delete_Zip_Query => q''{' || v_Delete_Zip_File_Query || '}'',' || chr(10)
							|| 'p_File_Names => q''{' || p_File_Names || '}'',' || chr(10) 
							|| 'p_Folder_query => q''{' || v_Folder_query || '}'',' || chr(10) 
							|| 'p_Filter_Path_Cond => q''{' || v_Filter_Path_Cond || '}'',' || chr(10) 
							|| 'p_Save_File_Code => q''{' || v_Save_File_Code || '}'',' || chr(10)
							|| 'p_Parent_Folder => q''{' || v_Parent_Folder || '}'',' || chr(10)
							|| case when v_Container_Key_Value IS NOT NULL then 'p_Container_ID =>' || v_Container_Key_Value ||',' || chr(10) end
							|| 'p_Context => ' || p_Context || ',' || chr(10)
							|| 'p_Completion_Procedure => q''{' || v_Completion_Procedure || '}''' || chr(10)
							|| ');' || chr(10)
							|| 'data_browser_jobs.Refresh_Tree_View(p_context => '|| p_Context
							|| ');' || chr(10) || 
							'end;';
						$IF data_browser_conf.g_debug $THEN
							apex_debug.info(
								p_message => 'data_browser_blobs.Upload_Zip_Files v_Process_Text :' || chr(10) || '%s',
								p0 => v_Process_Text,
								p_max_length => 3500
							);
						$END
						data_browser_jobs.Load_Job(
							p_Job_Name => 'UNZIP_'||SYS_CONTEXT('APEX$SESSION','APP_USER'),
							p_Comment => 'Expand Zip Archive',
							p_Sql => v_Process_Text,
							p_Wait => 'YES'
						);
					end if;
				exception when NO_DATA_FOUND then
					null;
				end;
			end if;
		end if;
		-- process remaining normal files
		Upload_Files (
			p_File_Names => p_File_Names,
			p_Table_Name => v_Files_Table_Name,
			p_Parent_Table => v_Folder_Table_Name,
			p_Parent_Key_Item => p_Parent_Key_Item,
			p_Unzip_Files => 'YES',
			p_File_Dates => p_File_Dates,
			p_File_Names2 => p_File_Names2
		);

	end Upload_Zip_Files;

	PROCEDURE Upload_File_List (
		p_File_Names VARCHAR2,							-- temp file names
		p_Table_Name VARCHAR2,
		p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
		p_Parent_Key_Item VARCHAR2 DEFAULT NULL,		-- default value for foreign key column
		p_Unzip_Files VARCHAR2 DEFAULT 'YES',			-- automatically unzip uploaded files
    	p_File_Dates VARCHAR2 DEFAULT NULL,				-- list of dates in format DD.MM.YY HH24:MI:SS delimited by |
    	p_File_Names2 VARCHAR2 DEFAULT NULL,			-- list of file names delimited by |
    	p_Context BINARY_INTEGER DEFAULT NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0)
	)
	is
	begin
		if p_Unzip_Files = 'YES' and Can_Upload_Zip_Files(p_Table_Name, p_Parent_Table) = 'YES' then
			Upload_Zip_Files (
				p_File_Names => p_File_Names, 
				p_Table_Name => p_Table_Name, 
				p_Parent_Table => p_Parent_Table, 
				p_Parent_Key_Item => p_Parent_Key_Item, 
				p_File_Dates => p_File_Dates, 
				p_File_Names2 => p_File_Names2, 
				p_Context => p_Context);
		elsif Can_Upload_Files(p_Table_Name, p_Parent_Table) = 'YES' then 
			Upload_Files (
				p_File_Names => p_File_Names, 
				p_Table_Name => p_Table_Name, 
				p_Parent_Table => p_Parent_Table, 
				p_Parent_Key_Item => p_Parent_Key_Item, 
				p_Unzip_Files => p_Unzip_Files, 
				p_File_Dates => p_File_Dates, 
				p_File_Names2 => p_File_Names2);
		end if;
	end Upload_File_List;

	PROCEDURE Upload_File (
		p_File_Name 		VARCHAR2,
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_File_Date 		DATE DEFAULT NULL
	)
	is
		v_file_names apex_application_global.vc_arr2;
		v_file_name apex_application_temp_files.filename%type;
		v_mime_type apex_application_temp_files.mime_type%type;
		v_created_on apex_application_temp_files.created_on%type;
		v_blob_content apex_application_temp_files.blob_content%type;
		v_Column_List	VARCHAR2(4000);
		v_Values_List	VARCHAR2(4000);
	begin
		Table_File_Columns (
			p_Table_Name => p_Table_Name,
			p_Parent_Table => NULL,
			p_Column_List => v_Column_List,
			p_Values_List => v_Values_List				-- :file_name, :mime_type, :file_date, :file_content, :folder_id
		);
		select filename, mime_type, created_on, blob_content
		  into v_file_name, v_mime_type, v_created_on, v_blob_content
		  from apex_application_temp_files
		 where name = p_File_Name;

		-- Save_File_to_Table (:file_content, :file_name, :file_date, :file_size, :mime_type, :folder_id));
		data_browser_blobs.Save_File_to_Table(
			p_Save_File_Code => 'UPDATE ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name) || ' SET (' || v_Column_List || ')'
								|| chr(10) || '= (SELECT ' || v_Values_List || ' FROM DUAL)'
								|| chr(10) || 'WHERE ' || p_Unique_Key_Column || ' = :folder_id;'
			, p_Folder_Id => p_Search_Value
			, p_File_Content => v_blob_content
			, p_File_Name => v_file_name
			, p_File_Date => NVL(p_File_Date, v_created_on)
			, p_Mime_Type => v_mime_type
		);
		delete from apex_application_temp_files
		where name = p_File_Name;
		commit;
    exception when others then
		delete from apex_application_temp_files
		where name = p_File_Name;
		commit;
		raise;
	end Upload_File;


	PROCEDURE Upload_text_File (
		p_File_Name 	VARCHAR2,
		p_Text_Mode		OUT NOCOPY VARCHAR2,	-- PLAIN / HTML
		p_Text_is_HTML  OUT NOCOPY VARCHAR2,   -- YES / NO
		p_Plain_Text	OUT NOCOPY CLOB,
		p_HTML_Text		OUT NOCOPY CLOB
	)
	is
		v_file_names apex_application_global.vc_arr2;
		v_file_name apex_application_temp_files.filename%type;
		v_mime_type apex_application_temp_files.mime_type%type;
		v_created_on apex_application_temp_files.created_on%type;
		v_blob_content apex_application_temp_files.blob_content%type;
		v_clob CLOB;
		v_char_length INTEGER;
		v_text_probe varchar2(4000);
	begin
		select filename, lower(mime_type), created_on, blob_content
		  into v_file_name, v_mime_type, v_created_on, v_blob_content
		  from apex_application_temp_files
		where name = p_File_Name;

		v_clob := fn_Blob_To_Clob(p_data => v_blob_content);
		v_text_probe := NVL(SUBSTR(v_clob, 1, 1000), 'X');
		p_Text_is_HTML := case when v_text_probe = REGEXP_REPLACE(v_text_probe,'<[^>]+>','') then 'NO' else 'YES' end;
		if p_Text_is_HTML = 'NO' then
			p_Text_Mode := 'PLAIN';
			p_Plain_Text := v_clob;
		else
			p_Text_Mode := 'HTML';
			p_HTML_Text := v_clob;
		end if;
		select CHAR_LENGTH into v_char_length
		from SYS.ALL_TAB_COLUMNS
		where TABLE_NAME = V('APP_PRO_TABLE_NAME')
		and OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
		and COLUMN_NAME = V('APP_PRO_COLUMN_NAME');
		commit;
		if dbms_lob.getlength(v_clob) > v_char_length then
			Apex_Error.Add_Error (
				p_message  => Apex_Lang.Lang('Value too large for column (actual: %0, maximum: %1).', dbms_lob.getlength(v_clob), v_char_length),
				p_display_location => apex_error.c_inline_in_notification
			);
		end if;
	end Upload_text_File;

	---------------------------------------------------------------------------
	-- preview and download --

	FUNCTION Mime_Type_Remap(
		p_Mime_Type	IN VARCHAR2
	)
	RETURN VARCHAR2 DETERMINISTIC
	IS
		l_Mime_Type	VARCHAR(200);
	BEGIN
		SELECT DECODE(LOWER(p_Mime_Type),
			'application/x-pdf',			'application/pdf',
			'application/x-zip-compressed', 'application/zip',
			'application/x-msexcel',		'application/vnd.ms-excel',
			'application/x-mspowerpoint',	'application/vnd.ms-powerpoint',
			'application/x-msword',			'application/vnd.ms-word',
			'application/msexcel',			'application/vnd.ms-excel',
			'application/mspowerpoint',		'application/vnd.ms-powerpoint',
			'application/msword',			'application/vnd.ms-word',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.document',	 'application/vnd.ms-word',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.template',	 'document',
			'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',		 'application/vnd.ms-excel',
			'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'application/vnd.ms-powerpoint',
			'application/vnd.openxmlformats-officedocument.presentationml.template',	 'application/vnd.oasis.opendocument.presentation_template',
			'video/x-flv', 					'video/x-generic',
			LOWER(p_Mime_Type))
		INTO l_Mime_Type
		FROM DUAL;
		return l_Mime_Type;
	END;

	FUNCTION File_Type_Name(
		p_Mime_Type		IN VARCHAR2)
	RETURN VARCHAR2
	IS
		l_Mime_Type VARCHAR2(300);
		l_category 	VARCHAR2(200);
		l_doctype 	VARCHAR2(200);
		l_trans_cat	VARCHAR2(200);
		l_trans_type VARCHAR2(200);
	BEGIN
		l_Mime_Type	:= Mime_Type_Remap(p_Mime_Type);
		l_category  := SUBSTR(l_Mime_Type, 1, INSTR(l_Mime_Type, '/', -1) - 1);
		l_doctype	:= SUBSTR(l_Mime_Type, INSTR(l_Mime_Type, '/', -1)+1);
		l_trans_cat := APEX_LANG.LANG(INITCAP(
						REPLACE(REPLACE(l_category, 'application', 'document'),
													'text', 'text-document')));
		l_trans_type := APEX_LANG.LANG(INITCAP(
						REPLACE(REPLACE(REPLACE(l_doctype, 'x-'), 'vnd.'), 'octet-stream', 'binär')));

		return l_trans_type	|| '-' || l_trans_cat;
	END;

	FUNCTION File_Type_Name_Call(
		p_Mime_Type_Column_Name	IN VARCHAR2)
	RETURN VARCHAR2
	IS
	BEGIN
		return 'data_browser_blobs.File_Type_Name(p_Mime_Type => ' || p_Mime_Type_Column_Name || ')';
	END;

	FUNCTION Extract_Source_URL(
		p_URL				IN VARCHAR2
	) RETURN VARCHAR2
	IS
		v_URL		VARCHAR(2000);
	BEGIN
		v_URL	:= REGEXP_REPLACE(p_URL, '.*''(f\?p=[^'']*)''.*', '\1');
		v_URL	:= REPLACE(v_URL, '\u0026', '&');
		return v_URL;
	END Extract_Source_URL;

	PROCEDURE  FN_File_Meta_Data(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_File_Name 		OUT NOCOPY VARCHAR2,
		p_Mime_Type 		OUT NOCOPY VARCHAR2,
		p_File_Date 		OUT DATE,
		p_File_Size			OUT NUMBER
	)
	AS
		v_File_Content  blob;
		v_Folder_Id		number;
		v_Column_List	varchar2(4000);
		v_Values_List	varchar2(4000);
		v_file_query	varchar2(4000);
	BEGIN
		if p_Search_Value IS NULL then
			return;
		end if;
		Table_File_Columns (
			p_Table_Name => p_Table_Name,
			p_Parent_Table => NULL,
			p_Column_List => v_Column_List,
			p_Values_List => v_Values_List				-- :file_name, :mime_type, :file_date, :file_content, :folder_id
		);
		v_file_query := 'SELECT ' || v_Column_List || ' FROM ' || p_Table_Name || ' WHERE ' || p_Unique_Key_Column || ' = :search_value';
		Execute_Load_file_query (
			p_Load_file_query	=> v_file_query,
			p_Values_List 		=> v_Values_List,
			p_Search_Value 		=> p_Search_Value,
			p_File_Name 		=> p_File_Name,
			p_Mime_Type 		=> p_Mime_Type,
			p_File_Date 		=> p_File_Date,
			p_File_Content		=> v_File_Content,
			p_Folder_Id 		=> v_Folder_Id
		);
		p_File_Size	:= dbms_lob.getlength(v_File_Content);
	end FN_File_Meta_Data;

	PROCEDURE  FN_File_Data(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_File_Name 		OUT NOCOPY VARCHAR2,
		p_Mime_Type 		OUT NOCOPY VARCHAR2,
		p_File_Date 		OUT DATE,
		p_File_Size			OUT NUMBER,
		p_File_Content		OUT NOCOPY BLOB
	)
	AS
		v_File_Content  blob;
		v_Folder_Id		number;
		v_File_Name		varchar2(1024);
		v_File_Ext		varchar2(1024);
		v_Mime_Type 	varchar2(1024);
		v_File_Date		date;
		v_Column_List	varchar2(4000);
		v_Values_List	varchar2(4000);
		v_file_query	varchar2(4000);
	BEGIN
		if p_Search_Value IS NULL then
			return;
		end if;
		Table_File_Columns (
			p_Table_Name => p_Table_Name,
			p_Parent_Table => NULL,
			p_Column_List => v_Column_List,
			p_Values_List => v_Values_List				-- :file_name, :mime_type, :file_date, :file_content, :folder_id
		);
		v_file_query := 'SELECT ' || v_Column_List || ' FROM ' || p_Table_Name || ' WHERE ' || p_Unique_Key_Column || ' = :search_value';
		Execute_Load_file_query (
			p_Load_file_query	=> v_file_query,
			p_Values_List 		=> v_Values_List,
			p_Search_Value 		=> p_Search_Value,
			p_File_Name 		=> v_File_Name,
			p_Mime_Type 		=> v_Mime_Type,
			p_File_Date 		=> v_File_Date,
			p_File_Content		=> v_File_Content,
			p_Folder_Id 		=> v_Folder_Id
		);
		-- produce default values for missing file_name, file_date, mime_type.
		v_File_Date := nvl(v_File_Date, trunc(sysdate, 'MI'));
		v_File_Name := replace(replace(substr(v_File_Name,instr(v_File_Name,'/')+1),chr(10),null),chr(13),null);
		v_File_Ext  := substr(v_Mime_Type, instr(v_Mime_Type, '/')+1);
		v_File_Name := nvl(v_File_Name, 'file' || LPAD(p_Search_Value, 5, '0') || '_' || v_File_Date || '.' || nvl(v_File_Ext, 'bin'));
		
		p_File_Name := v_File_Name;
		p_Mime_Type := v_Mime_Type;
		p_File_Date	:= v_File_Date;
		p_File_Size	:= dbms_lob.getlength(v_File_Content);
		p_File_Content := v_File_Content;
	end FN_File_Data;


	PROCEDURE FN_File_Thumbnail(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2,
		p_MaxHeight 		NUMBER DEFAULT 128
	)
	is
		ctx 			RAW(64) :=NULL;
$IF changelog_conf.g_Use_ORDIMAGE $THEN
		v_Ord_Image 	ordImage := ordImage();
		v_Thumbnail 	ordImage := ordImage();
$END
		v_File_Name		varchar2(1024);
		v_Mime_Type 	varchar2(1024);
		v_File_Date		date;
		v_Image_Content blob;
		v_Folder_Id		number;
		v_File_Size  	pls_integer;
	begin
		FN_File_Data(
			p_Table_Name => p_Table_Name,
    		p_Unique_Key_Column  => p_Unique_Key_Column,
			p_Search_Value 		=> p_Search_Value,
			p_File_Name 		=> v_File_Name,
			p_Mime_Type 		=> v_Mime_Type,
			p_File_Date 		=> v_File_Date,
			p_File_Size			=> v_File_Size,
			p_File_Content		=> v_Image_Content
		);
$IF changelog_conf.g_Use_ORDIMAGE $THEN
		dbms_lob.copy(	-- Bilddaten in das initialisierte ORDIMAGE übertragen
			v_Ord_Image.source.localData,
			v_Image_Content,
			v_File_Size
		);
		v_Ord_Image.setProperties();	-- Bild und Thumbnail Metadaten berechnen
		v_Ord_Image.setLocal();

		if v_Ord_Image.getHeight() > p_MaxHeight
		or v_Ord_Image.getWidth() > p_MaxHeight * 2
		or v_Ord_Image.getMimetype() not in ('image/gif', 'image/jpeg', 'image/pjpeg', 'image/png') then
			v_Ord_Image.processCopy('maxScale=' || p_MaxHeight * 2 || ' ' || p_MaxHeight || ', fileFormat=PNGF', v_Thumbnail);
		else
			v_Ord_Image.copy(v_Thumbnail);
		end if;
		v_Image_Content := v_Thumbnail.getContent();
		htp.init();
		-- Mimetype des Bildes für den Browser setzen
		owa_util.mime_header(nvl(v_Thumbnail.getMimetype(),'application/octet'),false);
		-- Größe des Bildes (in Byte setzen)
		htp.p('Content-length:'|| v_Thumbnail.getContentLength());
		htp.p('Content-Disposition: inline');
		owa_util.http_header_close;
		-- Daten an den Browser senden - dieser stellt das Bild dann dar
		wpg_docload.download_file(v_Image_Content);
$ELSE
		v_File_Size	:= dbms_lob.getlength(v_Image_Content);
		htp.init();
		-- Mimetype des Bildes für den Browser setzen
		owa_util.mime_header(nvl(v_Mime_Type,'application/octet'),false);
		-- Größe des Bildes (in Byte setzen)
		htp.p('Content-length:'|| v_File_Size);
		htp.p('Content-Disposition: inline');
		owa_util.http_header_close;
		-- Daten an den Browser senden - dieser stellt das Bild dann dar
		wpg_docload.download_file(v_Image_Content);

$END
	end FN_File_Thumbnail;

	FUNCTION Prepare_Plain_Url(p_URL VARCHAR2) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return APEX_UTIL.PREPARE_URL(p_URL => p_URL, p_plain_url => true);
		-- v_URL	:= Extract_Source_URL(v_URL);
	end;

	FUNCTION FN_File_Icon(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column	VARCHAR2,
		p_Search_Value		VARCHAR2,
		p_Prepare_Url       VARCHAR2 DEFAULT 'NO',
		p_Icon_Size			NUMBER DEFAULT 64
	) RETURN VARCHAR2
	IS
		v_Extension 	VARCHAR(200);
		v_URL			VARCHAR(2000);

		v_File_Name		varchar2(1024);
		v_Mime_Type 	varchar2(1024);
		v_File_Date		date;
		v_Image_Content blob;
		v_Folder_Id		number;
		v_File_Size  	pls_integer;
	BEGIN
		FN_File_Data(
			p_Table_Name => p_Table_Name,
    		p_Unique_Key_Column => p_Unique_Key_Column,
			p_Search_Value 		=> p_Search_Value,
			p_File_Name 		=> v_File_Name,
			p_Mime_Type 		=> v_Mime_Type,
			p_File_Date 		=> v_File_Date,
			p_File_Size			=> v_File_Size,
			p_File_Content		=> v_Image_Content
		);
		if v_Image_Content IS NULL then
			return '<span></span>';
		end if;
		v_Extension := case when INSTR(v_File_Name,'.', -1) > 0
			then LOWER(SUBSTR(v_File_Name, INSTR(v_File_Name, '.', -1) + 1, 20)) end;
		IF  v_Mime_Type LIKE 'image/%' and v_File_Size < 1024*256 THEN
			v_URL	:=
				  ('f?p='||V('APP_ID')||':'||V('APP_PAGE_ID')||':'||V('APP_SESSION')
				  || ':APPLICATION_PROCESS=FN_File_Thumbnail:'|| 'NO::APP_PRO_TABLE_NAME,APP_PRO_KEY_COLUMN,APP_PRO_KEY_VALUE,APP_PRO_COLUMN_VALUE:'
				  || p_Table_Name || ',' || p_Unique_Key_Column || ',' || p_Search_Value
				  || ',' || v_File_Name || '_' || v_File_Date || '_' || v_File_Size -- produce unique url
				  );
			if p_Prepare_Url = 'YES' then
				v_URL	:= apex_util.prepare_url (p_URL => v_URL, p_plain_url => true );
				-- v_URL	:= Extract_Source_URL(v_URL);
			end if;
		END IF;
		if v_URL IS NOT NULL then
			return
			'<img src="' || v_URL
			 || '" style="height:' || p_Icon_Size || 'px; max-width:' || p_Icon_Size * 3 || 'px; margin: 4px; '
			 || '" alt="Preview" title="' || HTF.ESCAPE_SC(v_File_Name)
			 || ' ' || trim(apex_util.filesize_mask(v_File_Size))
			 || '" height="' || p_Icon_Size
			 || '">';
		else
			return '<span title="' || HTF.ESCAPE_SC(v_File_Name)
			 || ' ' || trim(apex_util.filesize_mask(v_File_Size)) || '"'
			 || ' style="font-size: 32px; margin-right: 6px;"'
			 || ' class="t-Icon fa '
			 || case WHEN v_Mime_Type LIKE 'image/%' THEN 'fa-file-image-o'
				WHEN v_Mime_Type like 'video/%' THEN 'fa-file-video-o'
				WHEN v_Mime_Type like 'audio/%' THEN 'fa-file-audio-o'
				WHEN v_Mime_Type like 'text/%' THEN 'fa-file-text-o'
				WHEN v_Extension = 'pdf' THEN 'fa-file-pdf-o'
				WHEN v_Extension IN ('doc','docx') THEN 'fa-file-word-o'
				WHEN v_Extension IN ('xls', 'xlsx') THEN 'fa-file-excel-o'
				WHEN v_Extension IN ('ppt', 'pptx') THEN 'fa-file-powerpoint-o'
				ELSE 'fa-file-o'
			end
			|| '"></span>';
		end if;
	END FN_File_Icon;

	FUNCTION FN_File_Icon_Call(
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2
	) RETURN VARCHAR2
	IS
	BEGIN
		return 'data_browser_blobs.FN_File_Icon(p_Table_Name => ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name)
			|| ', p_Unique_Key_Column => ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Key_Column)
			|| ', p_Search_Value => ' || p_Value
			|| ')';
	END FN_File_Icon_Call;

	FUNCTION FN_File_Icon_Link(
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2,
		p_Page_ID           NUMBER DEFAULT 31
	) RETURN VARCHAR2
	IS
	PRAGMA UDF;
	BEGIN
		if p_Key_Column IS NULL then
			return 'NULL';
		end if;
		return case when p_Page_ID IS NOT NULL then
			Enquote_Literal('<a href="')
			|| '||apex_util.prepare_url( '
			|| Enquote_Literal('f?p=')
			|| q'[||V('APP_ID')||':]' || p_Page_ID || q'[:']'
			|| q'[||V('APP_SESSION')||'::'||V('DEBUG')||]'
			|| Enquote_Literal('::APP_PRO_TABLE_NAME,APP_PRO_KEY_COLUMN,APP_PRO_KEY_VALUE:'
			|| p_Table_Name || ',' || p_Key_Column || ',')
			|| '||' || p_Value
			|| ')||' || Enquote_Literal('" >') || data_browser_conf.NL(8) || '||'
			end
			|| data_browser_blobs.FN_File_Icon_Call(
				p_Table_Name => p_Table_Name,
				p_Key_Column => p_Key_Column,
				p_Value => p_Value
			)
			|| case when p_Page_ID IS NOT NULL then
				'||' || Enquote_Literal('</a>')
			end;
	END FN_File_Icon_Link;

	FUNCTION Text_Link_Url (
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2,
		p_Column_Name 		VARCHAR2,
		p_Page_ID 			NUMBER,
		p_Seq_ID			VARCHAR2 DEFAULT NULL,
		p_Selector			VARCHAR DEFAULT 'ACTIONS_GEAR'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return '<a href="'
			|| apex_util.prepare_url(p_url=> 'f?p='
				|| V('APP_ID') || ':' || p_Page_ID || ':' || V('APP_SESSION') || '::'
				|| V('DEBUG') || ':' || p_Page_ID
				|| ':APP_PRO_TABLE_NAME,APP_PRO_KEY_COLUMN,APP_PRO_KEY_VALUE,APP_PRO_COLUMN_NAME,APP_PRO_SEQ_ID:'
				||  p_Table_Name || ',' || p_Key_Column || ',' || p_Value || ',' || p_Column_Name || ',' || p_Seq_ID,
				p_triggering_element=> p_Selector
			)
			|| '" class="text_tool_link"><img src="'
			|| V('IMAGE_PREFIX')
			||'app_ui/img/icons/apex-edit-pencil-alt.png" class="apex-edit-pencil-alt" alt=""></a>';
	end Text_Link_Url;

	FUNCTION FN_Edit_Text_Link_Html (
		p_Table_Name 		VARCHAR2,
    	p_Key_Column 		VARCHAR2,
		p_Value 			VARCHAR2,
		p_Column_Name 		VARCHAR2,
		p_Data_Type			VARCHAR2,
		p_Page_ID           NUMBER DEFAULT 42,
		p_Seq_ID			VARCHAR2 DEFAULT NULL,
		p_Selector			VARCHAR2 DEFAULT 'ACTIONS_GEAR'
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
		v_Result VARCHAR2(4000);
	begin
		v_Result := 'data_browser_blobs.Text_Link_Url(p_Table_Name=> '
			|| Enquote_Literal(p_Table_Name) 
			|| ', p_Key_Column=>' || Enquote_Literal(p_Key_Column) 
			|| ', p_Value=>'|| p_Value 
			|| ', p_Column_Name=>' || Enquote_Literal(p_Column_Name) 
			|| ', p_Page_ID=>' || p_Page_ID
			|| ', p_Seq_ID=>' || Enquote_Literal(NULLIF(p_Seq_ID, 'NULL'))
			|| ', p_Selector=>' || Enquote_Literal(NVL(p_Selector,'ACTIONS_GEAR'))
			|| ')';
		if p_Data_Type IN ('CLOB', 'NCLOB') then
        	v_Result := 'TO_CLOB(' || v_Result || ')';
		end if;
		return v_Result;
	end FN_Edit_Text_Link_Html;
	
	
	FUNCTION FN_Text_Tool_Body_Html (
		p_Column_Label 		VARCHAR2,
		p_Column_Expr		VARCHAR2,
		p_CSS_Class			VARCHAR2 DEFAULT NULL
	) RETURN VARCHAR2
	is
	PRAGMA UDF;
	begin
		return case when data_browser_conf.Get_Export_CSV_Mode = 'NO' then
			Enquote_Literal('<div id="' || p_Column_Label || '_') || '||ROWNUM||'
			|| Enquote_Literal('" class="' || data_browser_conf.concat_list('text_tool_body', p_CSS_Class, ' ') || '">')
			|| case when NVL(p_Column_Expr, 'NULL') != 'NULL'
				then '||' || p_Column_Expr
			end
			|| data_browser_conf.NL(4)
			|| '||' || Enquote_Literal('</div>')
		else
			p_Column_Expr
		end;
	end FN_Text_Tool_Body_Html;

	PROCEDURE Init_Clob_Updates
	AS
	BEGIN
		apex_collection.create_or_truncate_collection (p_collection_name=>c_Clob_Field_Collection);
	exception
		when dup_val_on_index then null;
	END Init_Clob_Updates;

	PROCEDURE Load_Clob_from_link (
		p_Seq_ID		OUT INTEGER,
		p_Char_length   OUT INTEGER,
		p_Column_Label  OUT NOCOPY VARCHAR2,
		p_Text_Mode		IN OUT NOCOPY VARCHAR2,	-- PLAIN / HTML
		p_Text_is_HTML  OUT NOCOPY VARCHAR2,   -- YES / NO
		p_Plain_Text	OUT NOCOPY CLOB,
		p_HTML_Text		OUT NOCOPY CLOB
	)
	is
		v_clob 		 CLOB:= empty_clob();
		v_file_query VARCHAR2(4000);
		v_seq_id     INTEGER;
		v_char_length INTEGER;
		v_text_probe varchar2(4000);
	begin
		dbms_lob.createtemporary( v_clob, false, dbms_lob.call );

		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>'CLOB_CONTENT');
		exception
		  when dup_val_on_index then null;
		end;
		select CHAR_LENGTH into v_char_length
		from SYS.ALL_TAB_COLUMNS
		where TABLE_NAME = V('APP_PRO_TABLE_NAME')
		and OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
		and COLUMN_NAME = V('APP_PRO_COLUMN_NAME');

		begin
			if INSTR(V('APP_PRO_SEQ_ID'), c_Clob_Field_Ref_Prefix) = 1 then
				v_Seq_ID := TO_NUMBER(SUBSTR(V('APP_PRO_SEQ_ID'), LENGTH(c_Clob_Field_Ref_Prefix)+1), '999999');

				SELECT CLOB001 INTO v_clob
				FROM APEX_COLLECTIONS
				WHERE COLLECTION_NAME = c_Clob_Field_Collection
				AND SEQ_ID = v_Seq_ID;
			elsif V('APP_PRO_KEY_VALUE') IS NOT NULL then
				SELECT SEQ_ID, CLOB001 INTO v_Seq_ID, v_clob
				FROM APEX_COLLECTIONS
				WHERE COLLECTION_NAME = c_Clob_Field_Collection
				AND C001 = V('APP_PRO_TABLE_NAME')
				AND C002 = V('APP_PRO_KEY_COLUMN')
				AND C003 = V('APP_PRO_KEY_VALUE')
				AND C004 = V('APP_PRO_COLUMN_NAME');
			end if;
		exception when NO_DATA_FOUND then
			null;
		end;
		if v_seq_id IS NULL then
			v_file_query := 'SELECT ' || DBMS_ASSERT.ENQUOTE_NAME(V('APP_PRO_COLUMN_NAME'))
			|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(V('APP_PRO_TABLE_NAME'))
			|| ' WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(V('APP_PRO_KEY_COLUMN')) || ' = :search_value';
			begin
				EXECUTE IMMEDIATE v_file_query INTO v_clob USING V('APP_PRO_KEY_VALUE');
			exception when NO_DATA_FOUND then
				NULL;
			END;
			v_seq_id := apex_collection.add_member(p_collection_name => 'CLOB_CONTENT', p_clob001 => v_clob);
		end if;

		p_Seq_ID := v_seq_id;
		p_Char_length := v_char_length;
    	p_Column_Label := data_browser_conf.Column_Name_to_Header(p_Column_Name => V('APP_PRO_COLUMN_NAME'), p_Remove_Extension => 'YES');
		v_text_probe := NVL(SUBSTR(v_clob, 1, 1000), 'X');
		p_Text_is_HTML := case when v_text_probe = REGEXP_REPLACE(v_text_probe,'<[^>]+>','') then 'NO' else 'YES' end;
		if p_Text_Mode IS NULL then
			if v_clob IS NULL or p_Text_is_HTML = 'NO' then
				p_Text_Mode := 'PLAIN';
			else
				p_Text_Mode := 'HTML';
			end if;
		end if;
		if p_Text_Mode = 'PLAIN' then
			p_Plain_Text := v_clob;
		else
			p_HTML_Text := v_clob;
		end if;
	end Load_Clob_from_link;

	FUNCTION Register_Clob_Updates(
		p_Table_Name 		VARCHAR2 DEFAULT V('APP_PRO_TABLE_NAME'),
    	p_Unique_Key_Column VARCHAR2 DEFAULT V('APP_PRO_KEY_COLUMN'),
		p_Search_Value 		VARCHAR2 DEFAULT V('APP_PRO_KEY_VALUE'),
		p_Column_Name		VARCHAR2 DEFAULT V('APP_PRO_COLUMN_NAME'),
		p_Seq_ID			NUMBER DEFAULT NULL,
		p_Clob 				CLOB DEFAULT NULL
	) RETURN VARCHAR -- Reference to the text block
	AS
	    v_clob 		clob;
    	v_seq_id     number;
	BEGIN
		if apex_collection.collection_exists(p_collection_name=>c_Clob_Field_Collection)
		and apex_collection.collection_exists(p_collection_name=>'CLOB_CONTENT') then
			if p_Clob IS NULL then
			-- load last submitted clob from apex page
				SELECT CLOB001 INTO v_clob
				FROM APEX_COLLECTIONS
				WHERE COLLECTION_NAME = 'CLOB_CONTENT';
			else
				v_clob := p_Clob;
			end if;
			SELECT MAX(SEQ_ID) SEQ_ID
			INTO v_seq_id
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = c_Clob_Field_Collection
			AND C001 = p_Table_Name
			AND C002 = p_Unique_Key_Column
			AND (C003 = p_Search_Value or (C003 is null and p_Search_Value is null))
			AND (SEQ_ID = p_Seq_ID or p_Seq_ID is null)
			AND C004 = p_Column_Name;
			if v_seq_id IS NULL then
				v_seq_id := apex_collection.add_member(p_collection_name => c_Clob_Field_Collection,
					p_c001 => p_Table_Name,
					p_c002 => p_Unique_Key_Column,
					p_c003 => p_Search_Value,
					p_c004 => p_Column_Name,
					p_clob001 => v_clob);
			else
				APEX_COLLECTION.UPDATE_MEMBER_ATTRIBUTE (
					p_collection_name => c_Clob_Field_Collection,
					p_seq => v_seq_id,
					p_clob_number => 1,
					p_clob_value => v_clob
				);
			end if;
			commit;
		end if;
	/*
	// possible states are:
	// 1. the text block is shorter that 2000 chars and no clob processing is needed.
	//    the hidden field is updated with the passed back value from the text editor
	// 2. the larger clob is passed for an existing row with a known primary key.
	//    In this case the text block has been registered from later processing.
	//    The hidden field is tagged with the seq_id and the update process will ignore the text fields.
	// 3. the larger clob is passed for a new row.
	//    In this case the text block has been registered from latet processing
	//    and the returned reference seq_id to the text block is store in the hidden field.
	*/
		return case when v_seq_id is not null
			then c_Clob_Field_Ref_Prefix || ltrim(to_char(v_seq_id, '099999'))
		end;
	exception when no_data_found then
		return null;
	END;

	FUNCTION Get_Clob_from_Form (	-- returns the requested clob from text editor field and deletes it from the collection
		p_Field_Value VARCHAR2
	) return CLOB
	is
	PRAGMA UDF;
		v_Seq_ID NUMBER;
		v_clob CLOB;
	begin
		if INSTR(p_Field_Value, c_Clob_Field_Ref_Prefix) = 1 then
			v_Seq_ID := TO_NUMBER(SUBSTR(p_Field_Value, LENGTH(c_Clob_Field_Ref_Prefix)+1), '999999');

			SELECT CLOB001 INTO v_clob
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = c_Clob_Field_Collection
			AND SEQ_ID = v_Seq_ID;

			return v_clob;
		else
			return to_clob(p_Field_Value);
		end if;
	end Get_Clob_from_Form;

	FUNCTION Get_Varchar_from_Form (	-- returns the requested clob from text editor field and deletes it from the collection
		p_Field_Value VARCHAR2
	) return VARCHAR2
	is
	PRAGMA UDF;
		v_Seq_ID NUMBER;
		v_clob CLOB;
	begin
		if INSTR(p_Field_Value, c_Clob_Field_Ref_Prefix) = 1 then
			v_Seq_ID := TO_NUMBER(SUBSTR(p_Field_Value, LENGTH(c_Clob_Field_Ref_Prefix)+1), '999999');

			SELECT CLOB001 INTO v_clob
			FROM APEX_COLLECTIONS
			WHERE COLLECTION_NAME = c_Clob_Field_Collection
			AND SEQ_ID = v_Seq_ID;

			return TO_CHAR(v_clob);
		else
			return p_Field_Value;
		end if;
	end Get_Varchar_from_Form;

	FUNCTION Get_Clob_from_form_call (
		p_Field_Value VARCHAR2,
		p_Data_Type VARCHAR2
	) return VARCHAR2
	is
	begin
		return case when p_Data_type IN ('CLOB', 'NCLOB')
				then 'data_browser_blobs.Get_Clob_from_Form(' || p_Field_Value || ')'
			when p_Data_type IN ('VARCHAR2', 'VARCHAR', 'NVARCHAR2', 'CHAR', 'NCHAR', 'RAW')
				then 'data_browser_blobs.Get_Varchar_from_Form(' || p_Field_Value || ')'
			else p_Field_Value
		end;
	end Get_Clob_from_form_call;

	FUNCTION Process_Clob_Updates
	RETURN PLS_INTEGER
	AS
		v_file_query	varchar2(4000);
		v_Count 		PLS_INTEGER := 0;
	BEGIN
		if apex_collection.collection_exists(p_collection_name=>c_Clob_Field_Collection) then
			for c_cur in (
				SELECT SEQ_ID,
					C001 Table_Name,
					C002 Unique_Key_Column,
					C003 Search_Value,
					C004 Column_Name,
					CLOB001 Clob_Content
				FROM APEX_COLLECTIONS
				WHERE COLLECTION_NAME = c_Clob_Field_Collection
				AND C003 IS NOT NULL
			) loop
				v_file_query := 'UPDATE ' || DBMS_ASSERT.ENQUOTE_NAME(c_cur.Table_Name)
				|| ' SET ' || DBMS_ASSERT.ENQUOTE_NAME(c_cur.Column_Name) || ' = :value '
				|| ' WHERE ' || DBMS_ASSERT.ENQUOTE_NAME(c_cur.Unique_Key_Column) || ' = :search_value';
				EXECUTE IMMEDIATE v_file_query USING c_cur.Clob_Content, c_cur.Search_Value;
				v_Count := v_Count + 1;
			end loop;
			apex_collection.delete_collection(p_collection_name=>c_Clob_Field_Collection);
		end if;
		return v_Count;
	END Process_Clob_Updates;

	PROCEDURE Register_Download (
		p_Table_Name 		VARCHAR2,
		p_Object_ID			VARCHAR2,
		p_flush_log			BOOLEAN DEFAULT TRUE
	)
	AS
	BEGIN
		custom_changelog.AddLog (
			p_Table_Name    => p_Table_Name,
			p_Object_ID     => p_Object_ID
		);
		custom_changelog.FinishLog;
		if p_flush_log then
			custom_changelog.FlushLog;
			commit;
		end if;
	-- EXCEPTION WHEN VALUE_ERROR THEN
		NULL;
	END Register_Download;

	PROCEDURE Clear_Clob_Updates
	AS
	BEGIN
		if apex_collection.collection_exists(p_collection_name=>c_Clob_Field_Collection) then
			apex_collection.delete_collection(p_collection_name=>c_Clob_Field_Collection);
		end if;
	END;

	FUNCTION FN_Add_Zip_File (
		p_Table_Name 		VARCHAR2 DEFAULT V('APP_PRO_TABLE_NAME'),
    	p_Unique_Key_Column VARCHAR2 DEFAULT V('APP_PRO_KEY_COLUMN'),
		p_Search_Value 		VARCHAR2 DEFAULT V('APP_PRO_KEY_VALUE'),
		p_Zip_File			IN OUT NOCOPY BLOB
	) RETURN PLS_INTEGER
	AS
		v_File_Name		varchar2(1024);
		v_Mime_Type 	varchar2(1024);
		v_File_Date		date;
		v_File_Content  blob;
		v_Folder_Id		number;
		v_File_Size  	pls_integer;
	BEGIN
		if p_Search_Value IS NOT NULL then
			FN_File_Data (
				p_Table_Name => p_Table_Name,
				p_Unique_Key_Column  => p_Unique_Key_Column,
				p_Search_Value 		=> p_Search_Value,
				p_File_Name 		=> v_File_Name,
				p_Mime_Type 		=> v_Mime_Type,
				p_File_Date 		=> v_File_Date,
				p_File_Size			=> v_File_Size,
				p_File_Content		=> v_File_Content
			);
			$IF data_browser_conf.g_debug $THEN
				apex_debug.info(
					p_message => 'data_browser_blobs.FN_Add_Zip_File (p_Zip_File(size)=>%s, v_File_Name=> %s, v_File_Content(size)=> %s, v_File_Date=>%s)',
					p0 => dbms_lob.getlength(p_Zip_File),
					p1 => DBMS_ASSERT.ENQUOTE_LITERAL(v_File_Name),
					p2 => dbms_lob.getlength(v_File_Content),
					p3 => DBMS_ASSERT.ENQUOTE_LITERAL(v_File_Date)
				);
			$END

$IF data_browser_blobs.g_use_package_as_zip $THEN
			as_zip.add1file( 
    			p_zipped_blob => p_Zip_File,
    			p_name => v_File_Name,
    			p_content => v_File_Content,
    			p_date => v_File_Date
    		);
$ELSE
			apex_zip.add_file (
				p_zipped_blob => p_Zip_File,
				p_file_name => v_File_Name,
				p_content => v_File_Content
			);
$END
			data_browser_blobs.Register_Download(p_Table_Name, p_Search_Value, false);
			return 1;
		end if;
		return 0;
	END FN_Add_Zip_File;

	PROCEDURE FN_Zip_File_Download(
		p_Table_Name 		VARCHAR2 DEFAULT V('APP_PRO_TABLE_NAME'),
		p_Zip_File			IN OUT NOCOPY BLOB
	)
	AS
		v_File_Name		varchar2(1024);
		v_File_Size  	pls_integer;
	BEGIN
		if dbms_lob.getlength(p_Zip_File) > 0 then
$IF data_browser_blobs.g_use_package_as_zip $THEN
			as_zip.finish_zip (p_zipped_blob => p_Zip_File);
$ELSE
			apex_zip.finish (p_zipped_blob => p_Zip_File);
$END
			custom_changelog.FlushLog;
			commit;
			v_File_Size := dbms_lob.getlength(p_Zip_File);
			v_File_Name := data_browser_conf.Table_Name_To_Header(p_Table_Name) || '.zip';
			htp.init();
			owa_util.mime_header('application/zip', false);
			htp.p('Content-length: ' || v_File_Size);
			htp.p('Content-Disposition:  attachment; filename="'|| v_File_Name || '"');
			owa_util.http_header_close;
			-- Set Apex page property 'Reload on Submit' to 'always' to enable this download
			wpg_docload.download_file( p_Zip_File );
			-- apex_application.stop_apex_engine; -- causes runtime error 
		end if;
	END;

	PROCEDURE FN_File_Download(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2
	)
	AS
		v_File_Name		varchar2(1024);
		v_Mime_Type 	varchar2(1024);
		v_File_Date		date;
		v_File_Content  blob;
		v_Folder_Id		number;
		v_File_Size  	pls_integer;
	BEGIN
		FN_File_Data(
			p_Table_Name => p_Table_Name,
    		p_Unique_Key_Column  => p_Unique_Key_Column,
			p_Search_Value 		=> p_Search_Value,
			p_File_Name 		=> v_File_Name,
			p_Mime_Type 		=> v_Mime_Type,
			p_File_Date 		=> v_File_Date,
			p_File_Size			=> v_File_Size,
			p_File_Content		=> v_File_Content
		);
		data_browser_blobs.Register_Download(p_Table_Name, p_Search_Value);
		--
		-- set up HTTP header
		--
		htp.init();
		-- use an NVL around the mime type and
		-- if it is a null set it to application/octect
		-- application/octect may launch a download window from windows
		owa_util.mime_header( nvl(v_Mime_Type,'application/octet'), FALSE );

		-- set the size so the browser knows how much to download
		htp.p('Content-length: ' || v_File_Size);
		-- the filename will be used by the browser if the users does a save as
		htp.p('Content-Disposition:  attachment; filename="'|| v_File_Name || '"');
		-- close the headers
		owa_util.http_header_close;
		-- download the BLOB
		wpg_docload.download_file( v_File_Content );
		-- apex_application.stop_apex_engine; -- causes runtime error 
	end FN_File_Download;


	FUNCTION Compute_File_HTML(
		p_document IN BLOB
	) RETURN NCLOB
	is
	  l_data nclob;
	begin
	  dbms_lob.createtemporary(
		lob_loc => l_data,
		cache	=> true,
		dur		=> dbms_lob.call
	  );
	  ctx_doc.policy_filter(
		policy_name => 'search_filter_policy',
		document	=> p_document,
		restab		=> l_data
	  );
	  return l_data;
	end Compute_File_HTML;

	PROCEDURE  Download_Clob (
		p_clob				NCLOB,
		p_File_Name 		VARCHAR2
	)
	AS
		v_blob			blob;
		v_dstoff		pls_integer := 1;
		v_srcoff		pls_integer := 1;
		v_langctx 		pls_integer := 0;
		v_warning 		pls_integer := 1;
		v_blob_csid 	pls_integer := nls_charset_id('AL32UTF8');
		v_LimitMB 		INTEGER		:= 10;
	begin
		dbms_lob.createtemporary(
			lob_loc => v_blob,
			cache	=> true,
			dur		=> dbms_lob.call
		);
		dbms_lob.converttoblob(
			dest_lob   =>	v_blob,
			src_clob   =>	p_clob,
			amount	   =>	dbms_lob.getlength(p_clob),
			dest_offset =>	v_dstoff,
			src_offset	=>	v_srcoff,
			blob_csid	=>	v_blob_csid,
			lang_context => v_langctx,
			warning		 => v_warning
		);
		htp.init();
		owa_util.mime_header('text/html', false);
		htp.p('content-length: '||dbms_lob.getlength(v_blob));
		htp.p('Content-Disposition: attachment; filename="'|| p_File_Name || '"');
		owa_util.http_header_close;
		wpg_docload.download_file(v_blob);
		dbms_lob.freetemporary(v_blob);
	end Download_Clob;

	PROCEDURE  FN_File_Preview(
		p_Table_Name 		VARCHAR2,
    	p_Unique_Key_Column VARCHAR2,
		p_Search_Value 		VARCHAR2
	)
	AS
		v_File_Name		varchar2(1024);
		v_Mime_Type 	varchar2(1024);
		v_File_Date		date;
		v_File_Content  blob;
		v_Folder_Id		number;
		v_File_Size  	pls_integer;

		v_clob			nclob;
		v_blob			blob;
		v_LimitMB 		INTEGER		:= 10;
	BEGIN
		FN_File_Data(
			p_Table_Name => p_Table_Name,
    		p_Unique_Key_Column  => p_Unique_Key_Column,
			p_Search_Value 		=> p_Search_Value,
			p_File_Name 		=> v_File_Name,
			p_Mime_Type 		=> v_Mime_Type,
			p_File_Date 		=> v_File_Date,
			p_File_Size			=> v_File_Size,
			p_File_Content		=> v_File_Content
		);
		data_browser_blobs.Register_Download(p_Table_Name, p_Search_Value);
		$IF data_browser_conf.g_debug $THEN
			apex_debug.info(
				p_message => 'data_browser_blobs.FN_File_Preview (v_File_Name => %s, v_Mime_Type => %s, v_File_Date => %s, v_File_Size => %s)',
				p0 => DBMS_ASSERT.ENQUOTE_LITERAL(v_File_Name),
				p1 => DBMS_ASSERT.ENQUOTE_LITERAL(v_Mime_Type),
				p2 => DBMS_ASSERT.ENQUOTE_LITERAL(v_File_Date),
				p3 => v_File_Size,
				p_max_length => 3500
			);
		$END
		if (v_Mime_Type like 'image/%'
		or (v_Mime_Type like 'video/%' and v_File_Size <= 1024*1024*v_LimitMB)
		or (v_Mime_Type like 'audio/%' and v_File_Size <= 1024*1024*v_LimitMB)
		or v_Mime_Type like 'text/%'
		or v_Mime_Type = 'application/pdf') then
			htp.init();
			owa_util.mime_header(nvl(v_Mime_Type,'application/octet'),false);
			-- Größe des Bildes (in Byte setzen)
			htp.p('Content-length: '|| v_File_Size);
			htp.p('Content-Disposition: inline; filename="' || v_File_Name || '"');
			-- htp.p('Content-Disposition: inline');
			owa_util.http_header_close;
			-- Daten an den Browser senden - dieser stellt das Bild dann dar
			wpg_docload.download_file(v_File_Content);
		else
			begin
				v_clob := Compute_File_HTML(v_File_Content);
				Download_Clob (v_clob, v_File_Name);
			exception
			when others then
				htp.init();
				owa_util.mime_header('application/octet', false);
				htp.p('Content-length:'|| v_File_Size);
				htp.p('Content-Disposition: inline; filename="' || v_File_Name || '"');

				owa_util.http_header_close;
				wpg_docload.download_file(v_File_Content);
			end;
		end if;
	end FN_File_Preview;

end data_browser_blobs;
/
show errors

