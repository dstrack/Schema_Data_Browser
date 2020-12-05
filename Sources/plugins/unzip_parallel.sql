/*
Copyright 2017-2019 Dirk Strack

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

CREATE OR REPLACE package Unzip_Parallel
AUTHID DEFINER
is
/*
	The library procedure Unzip_Parallel.Expand_Zip_Archive provides functionality
	for reading a zip file from a table, storing all expanded files in one table and the folders for the files in a second table.
	The table for the files has a least the two columns for file_name varchar2, file_content blob
	and optionally file_date date, file_size number, mime_type varchar2(300), folder_id number.
	The table for the folders has at least a folder_id number, parent_id number, folder_name varchar2.
	When no folder definition is provided in the Folder Query attribute, full pathnames are stored in the file_name field of the files table.
	Zip file larger than 5MB will be processed in parallel to reduce the processing time when parallel execution is enabled.

	The process calculates an array of offsets to the individual zipped files of the zipped archive.
	The offsets are then used to expand all files without repeated sequential searching within the zipped archive.
	This method causes a dramatic reduction of execution time for larger archives with tousends of files.
	Chunks of the zipped archive can be executed in parallel by DBMS_SCHEDULER job slaves to further reduce execution time.
*/
	TYPE rec_zip_directory IS RECORD (
		path_name		as_zip.t_path_name,
		file_date		DATE,
		file_offest		INTEGER
	);
	TYPE tab_zip_directory IS TABLE OF rec_zip_directory;
	TYPE cur_zip_directory IS REF CURSOR RETURN rec_zip_directory;
	
	TYPE rec_unzip_file_blobs IS RECORD (
		file_path		VARCHAR2(32767),
		file_name		VARCHAR2(1024),
		file_date		DATE,
		mime_type		VARCHAR2(1024),
		file_size		INTEGER,
		file_content	BLOB,
		file_text 		CLOB
	);
	TYPE tab_unzip_file_blobs IS TABLE OF rec_unzip_file_blobs;
	
	c_Process_Name 		CONSTANT VARCHAR2(50) := 'Expand_Zip_Archive';
	c_App_Error_Code	CONSTANT INTEGER := -20200;
	c_msg_file_bad_type CONSTANT VARCHAR2(500) := 'The file is not a zip archive.'; -- 'Datei ist kein Zip-Archiv.'
	c_msg_file_empty 	CONSTANT VARCHAR2(500) := 'The zip archive does not contain any files.'; -- 'Das Zip-Archiv enthält keine Dateien.'
	c_msg_process_fails	CONSTANT VARCHAR2(500) := 'The zip archive could not be processed.'; -- 'Das Zip-Archiv konnte nicht verarbeitet werden.'
	c_debug 			CONSTANT BOOLEAN := FALSE;
	c_rows_lower_limit CONSTANT INTEGER := 16;	-- lower limit of rows processed in one chunk.
	c_size_lower_limit CONSTANT INTEGER := 5 * 1024 * 1024;	-- 5MB - lower limit for parallel processing
	c_parallel_jobs    CONSTANT INTEGER := 4;	-- upper limit of parallel jobs.
  	procedure get_folder_list(
		p_zipped_blob 	BLOB,
		p_only_files 	BOOLEAN DEFAULT TRUE,
		p_encoding 		IN OUT NOCOPY VARCHAR2,
		p_folder_max_count INTEGER DEFAULT NULL,
		p_folder_list	OUT NOCOPY as_zip.file_list,
		p_file_count 	OUT INTEGER
    );
    
	FUNCTION Pipe_Zip_Directory (
		p_zipped_blob 	IN BLOB, 
		p_encoding 		IN VARCHAR2 DEFAULT NULL,
		p_Start_ID 		IN INTEGER DEFAULT NULL,
		p_End_ID 		IN INTEGER DEFAULT NULL
	)
	RETURN Unzip_Parallel.tab_zip_directory PIPELINED DETERMINISTIC PARALLEL_ENABLE;

	FUNCTION Pipe_unzip_files_parallel (
		p_zipped_blob	IN BLOB,
		p_cur			IN Unzip_Parallel.cur_zip_directory
	)
	RETURN Unzip_Parallel.tab_unzip_file_blobs PIPELINED DETERMINISTIC PARALLEL_ENABLE (PARTITION p_cur BY ANY);

	FUNCTION Pipe_unzip_files (
		p_zipped_blob	IN BLOB,
		p_encoding 		IN VARCHAR2 DEFAULT NULL
	)
	RETURN Unzip_Parallel.tab_unzip_file_blobs PIPELINED DETERMINISTIC PARALLEL_ENABLE;

	function Create_Path (
		p_Path_Name		VARCHAR2,
		p_Root_Id 		INTEGER,
		p_Folder_query 	VARCHAR2,
		p_Container_ID 	NUMBER DEFAULT NULL
	) return INTEGER;

	function Mime_Type_from_Extension(
		p_File_Name			VARCHAR2,
		p_Default_Mime_Type	VARCHAR2 := 'application/octet-stream'
	)
	return varchar2 deterministic;

	PROCEDURE Expand_Zip_Parallel (
		p_process_text 	VARCHAR2,
		p_total_count 	INTEGER,
		p_SQLCode 		OUT INTEGER,
		p_Message		OUT NOCOPY VARCHAR2
	);

	PROCEDURE Load_zip_file_query (
		p_Load_Zip_Query IN VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_zip_file	OUT NOCOPY BLOB,
		p_Archive_Name OUT NOCOPY VARCHAR2
	);

	PROCEDURE Delete_Zip_File_Query (
		p_Delete_Zip_Query IN VARCHAR2,
		p_Search_Value IN VARCHAR2
	);

	PROCEDURE Expand_Zip_Range (
		p_Start_ID INTEGER DEFAULT NULL,
		p_End_ID INTEGER DEFAULT NULL,
		p_Init_Session_Code VARCHAR2 DEFAULT NULL,
		p_Load_Zip_Code 	VARCHAR2 DEFAULT NULL,
		p_Load_Zip_Query	VARCHAR2 DEFAULT NULL,
		p_Search_Value		VARCHAR2 DEFAULT NULL,
		p_Create_Path_Code 	VARCHAR2 DEFAULT NULL,
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',
		p_Save_File_Code 	VARCHAR2,
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Only_Files 		BOOLEAN DEFAULT TRUE,
		p_Skip_Empty 		BOOLEAN DEFAULT TRUE,
		p_Skip_Dot 			BOOLEAN DEFAULT TRUE,
		p_Encoding			VARCHAR2 DEFAULT NULL
	);

	PROCEDURE Expand_Zip_Archive (
		p_Init_Session_Code VARCHAR2 DEFAULT NULL,	-- PL/SQL code for initialization of session context.
		p_Load_Zip_Code 	VARCHAR2 DEFAULT NULL,	-- PL/SQL code for loading the zipped blob and filename. The bind variable :search_value can be used to pass the p_Search_Value attribute.
		p_Load_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for loading the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind to the Page Item provided by the Search Item Attribute.
		p_Delete_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for deleting the source of the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind.
		p_Search_Value		VARCHAR2 DEFAULT NULL,	-- Search value for the bind variable in the Load Zip Query code.
		p_Folder_query 		VARCHAR2 DEFAULT NULL,	-- SQL Query for parameters to store the folders in a recursive tree table. When this field is empty, the :file_name will be prefixed with the path in the Save file code.
		p_Create_Path_Code 	VARCHAR2 DEFAULT NULL,	-- PL/SQL code to save the path of the saved files.
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',-- Condition to filter the folders that are extracted from the zip archive. The bind variable :path_name delivers path names like /root/sub1/sub2/ to the expression.
		p_Save_File_Code 	VARCHAR2,				-- PL/SQL code to save an unzipped file from the zip archive. The bind variables :unzipped_file, :file_name, :file_date, :file_size, :mime_type, :folder_id deliver values to be saved.
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,	-- Pathname of the Directory where the unzipped files are saved.
		p_Container_ID		NUMBER  DEFAULT NULL,   -- folder table foreign key reference value to container table
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Only_Files 		BOOLEAN DEFAULT TRUE,	-- If set to Yes, empty directory entries are not created. Otherwise, set to No to include empty directory entries..
		p_Skip_Empty 		BOOLEAN DEFAULT TRUE,	-- If set to Yes, then empty files are skipped and not saved.
		p_Skip_Dot 			BOOLEAN DEFAULT TRUE,	-- If set to Yes, then files with a file name that start with '.' are skipped and not saved.
		p_Execute_Parallel	BOOLEAN DEFAULT TRUE,	-- If set to Yes, then files are processed in parallel jobs.
		p_Encoding			VARCHAR2 DEFAULT NULL, -- This is the encoding used to zip the file. (AL32UTF8 or US8PC437)
		p_SQLCode 			OUT INTEGER,
		p_Message 			OUT NOCOPY VARCHAR2
	);
	PROCEDURE Default_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2);
	PROCEDURE PLSQL_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2);
	PROCEDURE AJAX_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2);
	PROCEDURE Expand_Zip_Archive_Job (
		p_Init_Session_Code VARCHAR2 DEFAULT NULL,	-- PL/SQL code for initialization of session context.
		p_Load_Zip_Query	VARCHAR2,	-- SQL Query for loading the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind to the Page Item provided by the Search Item Attribute.
		p_Delete_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for deleting the source of the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind.
		p_File_Names		VARCHAR2,	-- file names for the bind variable in the Load Zip Query code.
		p_Folder_query 		VARCHAR2,	-- SQL Query for parameters to store the folders in a recursive tree table. When this field is empty, the :file_name will be prefixed with the path in the Save file code.
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',-- Condition to filter the folders that are extracted from the zip archive. The bind variable :path_name delivers path names like /root/sub1/sub2/ to the expression.
		p_Save_File_Code 	VARCHAR2,				-- PL/SQL code to save an unzipped file from the zip archive. The bind variables :unzipped_file, :file_name, :file_date, :file_size, :mime_type, :folder_id deliver values to be saved.
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,	-- Pathname of the Directory where the unzipped files are saved.
		p_Container_ID		NUMBER  DEFAULT NULL,   -- folder table foreign key reference value to container table
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Completion_Procedure VARCHAR2 DEFAULT 'unzip_parallel.Default_Completion' -- Name of a procedure with a call profile like: unzip_Completion(p_SQLCode NUMBER, p_Message VARCHAR2)
		-- when the procedure is called from a Apex PL/SQL process, unzip_parallel.use PLSQL_Completion to display bad results.
		-- when it is called from a AJAX process, use 'unzip_parallel.AJAX_Completion'  to display results.
		-- when it is called from a scheduler job, write the result in a logging table.
	);
	
end Unzip_Parallel;
/
show errors

CREATE OR REPLACE package body Unzip_Parallel
is
	c_END_OF_CENTRAL_DIRECTORY constant raw(4) := hextoraw( '504B0506' ); -- End of central directory signature

	function blob2num( p_blob blob, p_len integer, p_pos integer )
	return number
	is
		rv number;
	begin
		rv := utl_raw.cast_to_binary_integer( dbms_lob.substr( p_blob, p_len, p_pos ), utl_raw.little_endian );
		if rv < 0 then
		  rv := rv + 4294967296;
		end if;
		return rv;
	end;

	function raw2varchar2( p_raw raw, p_encoding varchar2 )
	return varchar2
	is
	begin
		return coalesce( utl_i18n.raw_to_char( p_raw, p_encoding )
	   , utl_i18n.raw_to_char( p_raw, utl_i18n.map_charset( p_encoding, utl_i18n.GENERIC_CONTEXT, utl_i18n.IANA_TO_ORACLE ) )
	   );
	end;

	procedure get_folder_list(
		p_zipped_blob 	BLOB,
		p_only_files 	BOOLEAN DEFAULT TRUE,
		p_encoding 		IN OUT NOCOPY VARCHAR2,
		p_folder_max_count INTEGER DEFAULT NULL,
		p_folder_list	OUT NOCOPY as_zip.file_list,
		p_file_count 	OUT INTEGER
    )
	is
		t_ind integer;
		t_hd_ind integer;
		t_folder_list  as_zip.file_list :=  as_zip.file_list(NULL);
		t_encoding varchar2(255);
		t_size		integer;
		t_total 	integer;
		t_file_name as_zip.t_path_name;
		t_full_path as_zip.t_path_name;
		t_file_path as_zip.t_path_name;
		t_last_path as_zip.t_path_name := ' ';
	begin
		t_ind := nvl( dbms_lob.getlength( p_zipped_blob ), 0 ) - 21;
		loop
		  exit when t_ind < 1 or dbms_lob.substr( p_zipped_blob, 4, t_ind ) = c_END_OF_CENTRAL_DIRECTORY;
		  t_ind := t_ind - 1;
		end loop;
		--
		p_file_count := 0;
		if t_ind <= 0
		then
		  return;
		end if;
		--
		t_hd_ind := blob2num( p_zipped_blob, 4, t_ind + 16 ) + 1;
		t_size := blob2num( p_zipped_blob, 2, t_ind + 10 );
		t_total := blob2num( p_zipped_blob, 2, t_ind + 8 );
		for i in 1 .. t_total
		loop
		  if p_encoding is null
		  then
			if utl_raw.bit_and( dbms_lob.substr( p_zipped_blob, 1, t_hd_ind + 9 ), hextoraw( '08' ) ) = hextoraw( '08' )
			then
			  t_encoding := 'AL32UTF8'; -- utf-8
			else
			  t_encoding := 'US8PC437'; -- ibm437
			end if;
		  else
			t_encoding := p_encoding;
		  end if;
		  t_full_path := raw2varchar2
						 ( dbms_lob.substr( p_zipped_blob
										  , blob2num( p_zipped_blob, 2, t_hd_ind + 28 )
										  , t_hd_ind + 46
										  )
						 , t_encoding
						 );
		  t_file_path := nvl(substr(t_full_path, 1, instr(t_full_path, '/', -1)), ' ');
		  t_file_name := substr(t_full_path, instr(t_full_path, '/', -1) + 1);
		  if t_file_path != t_last_path
		  and (NOT p_only_files or t_file_name IS NOT NULL) then
			  t_folder_list.EXTEND;
			  t_folder_list(t_folder_list.LAST) :=  t_file_path;

			  exit when t_folder_list.LAST >= p_folder_max_count;
			  t_last_path := t_file_path;
		  end if;
		  t_hd_ind := t_hd_ind + 46
					+ blob2num( p_zipped_blob, 2, t_hd_ind + 28 )  -- File name length
					+ blob2num( p_zipped_blob, 2, t_hd_ind + 30 )  -- Extra field length
					+ blob2num( p_zipped_blob, 2, t_hd_ind + 32 ); -- File comment length
		end loop;
		--
		p_encoding := t_encoding;
		p_folder_list := t_folder_list;
		p_file_count := t_size;
	end get_folder_list;

	PROCEDURE Load_Folder_query (
		p_Folder_query IN VARCHAR2,
		p_Folder_ID_Col  	OUT NOCOPY VARCHAR2,	-- Column Name of the Primary Key in the tree table.
		p_Parent_ID_Col  	OUT NOCOPY VARCHAR2,	-- Column Name of the Foreign Key in the tree table.
		p_Folder_Name_Col 	OUT NOCOPY VARCHAR2,	-- Column Name of the Folder Name in the tree table.
		p_Container_ID_Col	OUT NOCOPY VARCHAR2
	)
	is
		v_cur INTEGER;
		v_rows INTEGER;
		v_col_cnt INTEGER;
		v_rec_tab DBMS_SQL.DESC_TAB2;
	begin
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Folder_query, DBMS_SQL.NATIVE);
		dbms_sql.describe_columns2(v_cur, v_col_cnt, v_rec_tab);
$IF Unzip_Parallel.c_debug $THEN
		for j in 1..v_col_cnt loop
			dbms_output.put_line('col_name: ' || v_rec_tab(j).col_name || ', type: ' || v_rec_tab(j).col_type);
		end loop; 
$END
		p_Folder_ID_Col := case when v_col_cnt >= 1 then v_rec_tab(1).col_name end;
		p_Parent_ID_Col := case when v_col_cnt >= 2 then v_rec_tab(2).col_name end;
		p_Folder_Name_Col := case when v_col_cnt >= 3 then v_rec_tab(3).col_name end;
		p_Container_ID_Col := case when v_col_cnt >= 4 then v_rec_tab(4).col_name end;

		dbms_sql.close_cursor(v_cur);
	exception
	  when others then
		dbms_sql.close_cursor(v_cur);
		raise;
	end;

	FUNCTION Pipe_Zip_Directory (
		p_zipped_blob 	IN BLOB, 
		p_encoding 		IN VARCHAR2 DEFAULT NULL,
		p_Start_ID 		IN INTEGER DEFAULT NULL,
		p_End_ID 		IN INTEGER DEFAULT NULL
	)
	RETURN Unzip_Parallel.tab_zip_directory PIPELINED DETERMINISTIC PARALLEL_ENABLE
	is
		v_file_list		as_zip.file_list;
		v_date_list		as_zip.date_list;
		v_offset_list	as_zip.foffset_list;
        v_Start_ID		BINARY_INTEGER;
        v_End_ID		BINARY_INTEGER;
	begin
		as_zip.get_file_date_list ( p_zipped_blob, p_Encoding, v_file_list, v_date_list, v_offset_list);
		v_Start_ID 	:= NVL(p_Start_ID, 1);
		v_End_ID	:= LEAST(NVL(p_End_ID, v_file_list.count), v_file_list.count);
		for i in v_Start_ID .. v_End_ID loop
			pipe row( rec_zip_directory(v_file_list(i), v_date_list(i), v_offset_list(i)));
		end loop;
	end Pipe_Zip_Directory;

	FUNCTION Pipe_unzip_files_parallel (
		p_zipped_blob	IN BLOB,
		p_cur			IN Unzip_Parallel.cur_zip_directory
	)
	RETURN Unzip_Parallel.tab_unzip_file_blobs PIPELINED DETERMINISTIC PARALLEL_ENABLE (PARTITION p_cur BY ANY)
	is
		v_inrow		rec_zip_directory;
		v_outrow 	rec_unzip_file_blobs;
	begin
		loop
			fetch p_cur into v_inrow;
			exit when p_cur%NOTFOUND; 
			v_outrow.file_content := as_zip.get_file (
				p_zipped_blob => p_zipped_blob, 
				p_file_name => v_inrow.path_name, 
				p_offset => v_inrow.file_offest
			);
			v_outrow.File_Path := SUBSTR(v_inrow.path_name, 1, INSTR(v_inrow.path_name, '/', -1));
			v_outrow.File_Name := SUBSTR(v_inrow.path_name,    INSTR(v_inrow.path_name, '/', -1) + 1);
			v_outrow.File_Date := v_inrow.file_date;
			v_outrow.Mime_Type := unzip_parallel.Mime_Type_from_Extension(v_outrow.File_Name);
			v_outrow.File_Size := NVL(dbms_lob.getlength(v_outrow.file_content), 0);
			pipe row(v_outrow);
		end loop;
		close p_cur;
		return;
	end Pipe_unzip_files_parallel;

	FUNCTION Pipe_unzip_files (
		p_zipped_blob	IN BLOB,
		p_encoding 		IN VARCHAR2 DEFAULT NULL
	)
	RETURN Unzip_Parallel.tab_unzip_file_blobs PIPELINED DETERMINISTIC PARALLEL_ENABLE
	is
		cursor files_cur is
		select *
		from table( Unzip_Parallel.Pipe_unzip_files_parallel(
			p_zipped_blob,
			cursor( select * from table(
				Unzip_Parallel.Pipe_Zip_Directory(
					p_zipped_blob, p_encoding))
			)
		));
		v_row Unzip_Parallel.rec_unzip_file_blobs;
	begin
		OPEN files_cur;
		LOOP
			FETCH files_cur INTO v_row;
			EXIT WHEN files_cur%NOTFOUND;
			pipe row (v_row);
		END LOOP;
		CLOSE files_cur;
	end Pipe_unzip_files;

	FUNCTION Create_Path (
		p_Path_Name		VARCHAR2,
		p_Root_Id 		INTEGER,
		p_Folder_query 	VARCHAR2,
		p_Container_ID 	NUMBER DEFAULT NULL
	) return INTEGER
	is
		v_Folder_ID_Col	VARCHAR2(128);
		v_Parent_ID_Col	VARCHAR2(128);
		v_Container_ID_Col	VARCHAR2(128);
		v_Folder_Name_Col	VARCHAR2(128);
		v_statment 	VARCHAR2(4000);
		v_path 		as_zip.t_path_name;
		v_folder_name 	as_zip.t_path_name;
		v_folder_id INTEGER;
		v_root_id	INTEGER;
	begin
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('Create_Path : ' || p_Path_Name || ', Root_Id: ' || p_Root_Id || ', p_Container_ID: ' || p_Container_ID);
$END
		v_folder_id := p_Root_Id;
		v_path := '/' || SUBSTR(p_Path_Name, 1, INSTR(p_Path_Name, '/', -1) - 1);
		if v_path = '/' then
			return v_folder_id;
		end if;
		Load_Folder_query(
			p_Folder_query => p_Folder_query,
			p_Folder_ID_Col => v_Folder_ID_Col,
			p_Parent_ID_Col => v_Parent_ID_Col,
			p_Folder_Name_Col => v_Folder_Name_Col,
			p_Container_ID_Col => v_Container_ID_Col
		);
		v_statment :=
		'SELECT ' || dbms_assert.enquote_name(v_Folder_ID_Col) || chr(10) ||
		'INTO :folder_id' || chr(10) ||
		'FROM (' || chr(10) ||
			'SELECT ' || dbms_assert.enquote_name(v_Folder_ID_Col) || ', SYS_CONNECT_BY_PATH(TRANSLATE(' ||
					dbms_assert.enquote_name(v_Folder_Name_Col) || ', ''/'', ''-''), ''/'') PATH' || chr(10) ||
			'FROM (' || p_Folder_query || ') T ' || chr(10) ||
			case when v_Container_ID_Col IS NOT NULL then 
				'WHERE ' || dbms_assert.enquote_name(v_Container_ID_Col) || ' = ' || dbms_assert.enquote_literal(p_Container_ID) || chr(10) 
			end ||
			'START WITH (' || dbms_assert.enquote_name(v_Parent_ID_Col) || ' = :root_id ' ||
				   ' OR ' || dbms_assert.enquote_name(v_Parent_ID_Col) || ' IS NULL AND :root_id IS NULL )' || chr(10) ||
			'CONNECT BY ' || dbms_assert.enquote_name(v_Parent_ID_Col) || ' = PRIOR ' || dbms_assert.enquote_name(v_Folder_ID_Col) ||
		')' || chr(10) ||
		'WHERE PATH = :path';
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('----------');
		dbms_output.put_line(v_statment);
$END
		execute immediate 'begin ' || v_statment || '; end;'
			using out v_folder_id, p_Root_Id, v_path;
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('found path : ' || v_path || ', folder_id: ' || v_folder_id);
$END
		return v_folder_id;
	exception
	  when NO_DATA_FOUND then
	  	v_path := SUBSTR(v_path, 2) || '/';
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('new path : ' || v_path);
$END
		while INSTR(v_path, '/') > 0
		loop
			v_folder_name := SUBSTR(v_path, 1, INSTR(v_path, '/')-1);
			v_path := SUBSTR(v_path, INSTR(v_path, '/')+1);
			v_root_id := v_folder_id;
			begin
				v_statment :=
				'SELECT ' || dbms_assert.enquote_name(v_Folder_ID_Col) || chr(10) ||
				'INTO :folder_id'|| chr(10) ||
				'FROM (' || p_Folder_query || ') T ' || chr(10) ||
				'WHERE (' || dbms_assert.enquote_name(v_Parent_ID_Col) || ' = :root_id' || chr(10) ||
				   ' OR ' || dbms_assert.enquote_name(v_Parent_ID_Col) || ' IS NULL AND :root_id IS NULL )' || chr(10) ||
				'AND ' || dbms_assert.enquote_name(v_Folder_Name_Col) || ' = :folder_name' || chr(10)
				|| case when v_Container_ID_Col IS NOT NULL then 
					'AND ' || dbms_assert.enquote_name(v_Container_ID_Col) || ' = ' || dbms_assert.enquote_literal(p_Container_ID)  
				end;
$IF Unzip_Parallel.c_debug $THEN
				dbms_output.put_line('----------');
				dbms_output.put_line(v_statment);
$END
				execute immediate 'begin ' || v_statment || '; end;'
					using out v_folder_id, v_root_id, v_folder_name;
			exception
			  when NO_DATA_FOUND then
			  	if v_Container_ID_Col IS NOT NULL then 
					v_statment :=
					'INSERT INTO (' || p_Folder_query || ') T ' ||
					' (' || dbms_assert.enquote_name(v_Folder_Name_Col) ||
					', ' || dbms_assert.enquote_name(v_Parent_ID_Col) || 
					', ' || dbms_assert.enquote_name(v_Container_ID_Col) ||
					')' || chr(10) ||
					'VALUES (:folder_name, :parent_id, :container_id)' || chr(10) ||
					'RETURNING ' || dbms_assert.enquote_name(v_Folder_ID_Col) || ' INTO :folder_id';
$IF Unzip_Parallel.c_debug $THEN
					dbms_output.put_line('----------');
					dbms_output.put_line(v_statment);
$END
					execute immediate 'begin ' || v_statment || '; end;'
						using v_folder_name, v_root_id, p_Container_ID, out v_folder_id;
				else
					v_statment :=
					'INSERT INTO (' || p_Folder_query || ') T ' ||
					' (' || dbms_assert.enquote_name(v_Folder_Name_Col) ||
					', ' || dbms_assert.enquote_name(v_Parent_ID_Col) || 
					')' || chr(10) ||
					'VALUES (:folder_name, :parent_id)' || chr(10) ||
					'RETURNING ' || dbms_assert.enquote_name(v_Folder_ID_Col) || ' INTO :folder_id';
$IF Unzip_Parallel.c_debug $THEN
					dbms_output.put_line('----------');
					dbms_output.put_line(v_statment);
$END
					execute immediate 'begin ' || v_statment || '; end;'
						using v_folder_name, v_root_id, out v_folder_id;
				end if;
			end;
		end loop;
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('new folder_id: ' || v_folder_id);
$END
		return v_folder_id;
	end;

	function Mime_Type_from_Extension(
		p_File_Name			VARCHAR2,
		p_Default_Mime_Type	VARCHAR2 := 'application/octet-stream'
	)
	return varchar2 deterministic
	is
		v_Extension VARCHAR(200) := case when INSTR(p_File_Name,'.', -1) > 0
			then LOWER(SUBSTR(p_File_Name, LEAST(INSTR(p_File_Name, '.', -1) + 1, 200))) end;
	begin
		return case v_Extension
			when 'doc'  then 'application/msword'
			when 'docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
			when 'dotx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.template'
			when 'ico'  then 'image/x-icon'
			when 'potx' then 'application/vnd.openxmlformats-officedocument.presentationml.template'
			when 'pptx' then 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
			when 'xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
			when 'abc'  then 'text/vnd.abc'
			when 'acgi' then 'text/html'
			when 'afm'  then 'application/x-font-type1'
			when 'ai'   then 'application/postscript'
			when 'aif'  then 'audio/x-aiff'
			when 'aifc' then 'audio/x-aiff'
			when 'aiff' then 'audio/x-aiff'
			when 'asf'  then 'video/x-ms-asf'
			when 'asx'  then 'video/x-ms-asf'
			when 'au'   then 'audio/basic'
			when 'avi'  then 'video/x-msvideo'
			when 'bdf'  then 'application/x-font-bdf'
			when 'bm'   then 'image/bmp'
			when 'bmp'  then 'image/bmp'
			when 'bz'   then 'application/x-bzip'
			when 'c'    then 'text/plain'
			when 'c++'  then 'text/plain'
			when 'cc'   then 'text/plain'
			when 'cgm'  then 'image/cgm'
			when 'com'  then 'text/plain'
			when 'conf' then 'text/plain'
			when 'cpio' then 'application/x-cpio'
			when 'css'  then 'text/css'
			when 'csv'  then 'text/csv'
			when 'cxx'  then 'text/plain'
			when 'def'  then 'text/plain'
			when 'eml'  then 'message/rfc822'
			when 'eps'  then 'application/postscript'
			when 'f'    then 'text/plain'
			when 'for'  then 'text/plain'
			when 'f90'  then 'text/plain'
			when 'g'    then 'text/plain'
			when 'gif'  then 'image/gif'
			when 'gz'   then 'application/x-gzip'
			when 'gzip' then 'application/x-gzip'
			when 'h'    then 'text/plain'
			when 'hh'   then 'text/plain'
			when 'hlb'  then 'text/x-script'
			when 'htm'  then 'text/html'
			when 'html' then 'text/html'
			when 'htx'  then 'text/html'
			when 'ics'  then 'text/calendar'
			when 'idc'  then 'text/plain'
			when 'ifb'  then 'text/calendar'
			when 'in'   then 'text/plain'
			when 'jav'  then 'text/plain'
			when 'java' then 'text/plain'
			when 'jfif' then 'image/jpeg'
			when 'jpe'  then 'image/jpeg'
			when 'jpeg' then 'image/jpeg'
			when 'jpg'  then 'image/jpeg'
			when 'js'   then 'application/x-javascript'
			when 'kar'  then 'audio/midi'
			when 'lha'  then 'application/x-lha'
			when 'list' then 'text/plain'
			when 'log'  then 'text/plain'
			when 'lst'  then 'text/plain'
			when 'm'    then 'text/plain'
			when 'man'  then 'text/troff'
			when 'mar'  then 'text/plain'
			when 'me'   then 'text/troff'
			when 'mht'  then 'message/rfc822'
			when 'mid'  then 'audio/midi'
			when 'midi' then 'audio/midi'
			when 'mime' then 'message/rfc822'
			when 'mod'  then 'audio/x-mod'
			when 'moov' then 'video/quicktime'
			when 'mov'  then 'video/quicktime'
			when 'mpa'  then 'audio/mpeg'
			when 'mpe'  then 'video/mpeg'
			when 'mpeg' then 'video/mpeg'
			when 'mpg'  then 'audio/mpeg'
			when 'mpga' then 'audio/mpeg'
			when 'mpg4' then 'video/mp4'
			when 'mp2'  then 'audio/mpeg'
			when 'mp2a' then 'audio/mpeg'
			when 'mp3'  then 'audio/mpeg'
			when 'mp4'  then 'video/mp4'
			when 'mp4a' then 'audio/mp4'
			when 'mp4v' then 'video/mp4'
			when 'ms'   then 'text/troff'
			when 'm1v'  then 'video/mpeg'
			when 'm2a'  then 'audio/mpeg'
			when 'm2v'  then 'video/mpeg'
			when 'm3a'  then 'audio/mpeg'
			when 'm3u'  then 'audio/x-mpegurl'
			when 'm4v'  then 'video/mp4'
			when 'odb'  then 'application/vnd.oasis.opendocument.database'
			when 'odc'  then 'application/vnd.oasis.opendocument.chart'
			when 'odf'  then 'application/vnd.oasis.opendocument.formula'
			when 'odg'  then 'application/vnd.oasis.opendocument.graphics'
			when 'odi'  then 'application/vnd.oasis.opendocument.image'
			when 'odp'  then 'application/vnd.oasis.opendocument.presentation'
			when 'ods'  then 'application/vnd.oasis.opendocument.spreadsheet'
			when 'odt'  then 'application/vnd.oasis.opendocument.text'
			when 'otf'  then 'application/x-font-otf'
			when 'otp'  then 'application/vnd.oasis.opendocument.presentation-template'
			when 'ots'  then 'application/vnd.oasis.opendocument.spreadsheet-template'
			when 'p'    then 'text/x-pascal'
			when 'pas'  then 'text/x-pascal'
			when 'pbm'  then 'image/x-portable-bitmap'
			when 'pcf'  then 'application/x-font-pcf'
			when 'pcx'  then 'image/x-pcx'
			when 'pdf'  then 'application/pdf'
			when 'pfa'  then 'application/x-font-type1'
			when 'pfb'  then 'application/x-font-type1'
			when 'pfm'  then 'application/x-font-type1'
			when 'pgm'  then 'image/x-portable-graymap'
			when 'pgp'  then 'application/pgp-encrypted'
			when 'pl'   then 'text/plain'
			when 'pm'   then 'image/x-xpixmap'
			when 'png'  then 'image/png'
			when 'pot'  then 'application/vnd.ms-powerpoint'
			when 'ppa'  then 'application/vnd.ms-powerpoint'
			when 'ppm'  then 'image/x-portable-pixmap'
			when 'pps'  then 'application/vnd.ms-powerpoint'
			when 'ppt'  then 'application/vnd.ms-powerpoint'
			when 'ps'   then 'application/postscript'
			when 'pwz'  then 'application/vnd.ms-powerpoint'
			when 'p7c'  then 'application/pkcs7-mime'
			when 'p7m'  then 'application/pkcs7-mime'
			when 'qt'   then 'video/quicktime'
			when 'ra'   then 'audio/x-pn-realaudio-plugin'
			when 'rgb'  then 'image/x-rgb'
			when 'rm'   then 'application/vnd.rn-realmedia'
			when 'rmi'  then 'audio/midi'
			when 'rmp'  then 'audio/x-pn-realaudio-plugin'
			when 'roff' then 'text/troff'
			when 'rpm'  then 'audio/x-pn-realaudio-plugin'
			when 'rtf'  then 'application/rtf'
			when 'rtx'  then 'application/rtf'
			when 'sda'  then 'application/vnd.stardivision.draw'
			when 'sdc'  then 'application/vnd.stardivision.calc'
			when 'sdml' then 'text/plain'
			when 'sgm'  then 'text/sgml'
			when 'sgml' then 'text/sgml'
			when 'snd'  then 'audio/basic'
			when 'snf'  then 'application/x-font-snf'
			when 'sql'  then 'text/plain'
			when 'stc'  then 'application/vnd.sun.xml.calc.template'
			when 'std'  then 'application/vnd.sun.xml.draw.template'
			when 'svg'  then 'image/svg+xml'
			when 'svgz' then 'image/svg+xml'
			when 'sxc'  then 'application/vnd.sun.xml.calc'
			when 'sxd'  then 'application/vnd.sun.xml.draw'
			when 't'    then 'text/troff'
			when 'tar'  then 'application/x-tar'
			when 'text' then 'text/plain'
			when 'tif'  then 'image/tiff'
			when 'tiff' then 'image/tiff'
			when 'tr'   then 'text/troff'
			when 'ttc'  then 'application/x-font-ttf'
			when 'ttf'  then 'application/x-font-ttf'
			when 'txt'  then 'text/plain'
			when 'vcf'  then 'text/x-vcard'
			when 'wav'  then 'audio/x-wav'
			when 'wma'  then 'audio/x-ms-wma'
			when 'wml'  then 'text/vnd.wap.wml'
			when 'wmv'  then 'video/x-ms-wmv'
			when 'wri'  then 'application/x-mswrite'
			when 'xbm'  then 'image/x-xbitmap'
			when 'xht'  then 'application/xhtml+xml'
			when 'xla'  then 'application/vnd.ms-excel'
			when 'xlb'  then 'application/vnd.ms-excel'
			when 'xlc'  then 'application/vnd.ms-excel'
			when 'xll'  then 'application/vnd.ms-excel'
			when 'xlm'  then 'application/vnd.ms-excel'
			when 'xls'  then 'application/vnd.ms-excel'
			when 'xlt'  then 'application/vnd.ms-excel'
			when 'xlw'  then 'application/vnd.ms-excel'
			when 'xml'  then 'text/xml'
			when 'xpm'  then 'image/x-xpixmap'
			when 'xsl'  then 'application/xml'
			when 'xslt' then 'application/xslt+xml'
			when 'z'    then 'application/x-compress'
			when 'zip'  then 'application/zip'
			when '7z'   then 'application/x-7z-compressed'

			else lower(p_default_mime_type) end;
	end;

	PROCEDURE Expand_Zip_Parallel (
		p_process_text 	VARCHAR2,
		p_total_count 	INTEGER,
		p_SQLCode 		OUT INTEGER,
		p_Message		OUT NOCOPY VARCHAR2
	)
	is
		v_job_name  	VARCHAR2(255);
		v_piece_size 	INTEGER;
		v_parallel 		INTEGER := c_parallel_jobs;	-- upper limit of parallel jobs.
		v_chunk_sql 	VARCHAR2(1000);
		v_try 			INTEGER;
		v_status 		INTEGER;
        v_Message		VARCHAR2(4000);
        v_SQLCode		INTEGER := 0;
	begin
		-- Create the TASK
		v_job_name := dbms_parallel_execute.generate_task_name(Unzip_Parallel.c_Process_Name);
		dbms_parallel_execute.create_task (v_job_name);

		-- Chunk the task by piece_size
		if p_total_count / c_rows_lower_limit < v_parallel then
			v_parallel := CEIL(p_total_count / c_rows_lower_limit);
		end if;
		v_piece_size := p_total_count / v_parallel;
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('---------' );
		dbms_output.put_line('total_count : ' || p_total_count);
		dbms_output.put_line('parallel    : ' || v_parallel);
		dbms_output.put_line('piece_size  : ' || v_piece_size);
$END
		v_chunk_sql :=
			'WITH PA AS ( SELECT ' || p_total_count || ' CNT, ' || v_piece_size || ' LIMIT FROM DUAL) '
			|| 'SELECT (LEVEL - 1) * LIMIT + 1 start_id, LEAST(LEVEL * LIMIT, PA.CNT)  end_id '
			|| 'FROM DUAL, PA CONNECT BY LEVEL <= CEIL(PA.CNT / PA.LIMIT)';
		dbms_parallel_execute.create_chunks_by_sql(v_job_name, v_chunk_sql, false);

		-- Execute the p_process_text in parallel
		-- the parameter list contains range variables :start_id and :end_id
		dbms_parallel_execute.run_task(v_job_name, p_process_text, DBMS_SQL.NATIVE, parallel_level => NULL);
		-- If there is error, RESUME it for at most 3 times.
		v_try := 0;
		v_status := dbms_parallel_execute.task_status(v_job_name);
		while (v_try < 3 and v_status != DBMS_PARALLEL_EXECUTE.FINISHED)
		loop
			v_try := v_try + 1;
			if v_status = dbms_parallel_execute.finished_with_error then
				SELECT ERROR_CODE, ERROR_MESSAGE
				INTO v_SQLCode, v_Message
				FROM USER_PARALLEL_EXECUTE_CHUNKS
				WHERE TASK_NAME = v_job_name
				AND STATUS = 'PROCESSED_WITH_ERROR'
				AND ROWNUM < 2;
			end if;
			-- stop on raise_application_error and others like ORA-04031 unable to allocate string bytes of shared memory
			exit when v_SQLCode IN (-1, -103, -913, -4031, -1422) or v_SQLCode between -20999 and -20000 ;
			dbms_parallel_execute.resume_task(v_job_name);
			v_status := dbms_parallel_execute.task_status(v_job_name);
		end loop;
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('tries       : ' || v_try);
		dbms_output.put_line('status      : ' || v_status);
		-- Done with processing; drop the task
$END
		dbms_parallel_execute.drop_task(v_job_name);
		if v_status = dbms_parallel_execute.finished then
			p_SQLCode := 0;
			p_Message := NULL;
		else
			p_SQLCode := v_SQLCode;
			p_Message := v_Message;
		end if;
	end Expand_Zip_Parallel;

	PROCEDURE Load_zip_file_query (
		p_Load_Zip_Query IN VARCHAR2,
		p_Search_Value IN VARCHAR2,
		p_zip_file	OUT NOCOPY BLOB,
		p_Archive_Name OUT NOCOPY VARCHAR2
	)
	is
		v_cur INTEGER;
		v_rows INTEGER;
		v_col_cnt INTEGER;
		v_rec_tab DBMS_SQL.DESC_TAB2;
	begin
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Load_Zip_Query, DBMS_SQL.NATIVE);
		IF p_Search_Value IS NOT NULL then
			dbms_sql.bind_variable(v_cur, ':search_value', p_Search_Value);
		end if;
		dbms_sql.describe_columns2(v_cur, v_col_cnt, v_rec_tab);
$IF Unzip_Parallel.c_debug $THEN
		for j in 1..v_col_cnt loop
			dbms_output.put_line('col_name : ' || v_rec_tab(j).col_name || ', type: ' || v_rec_tab(j).col_type);
		end loop; 
$END
		dbms_sql.define_column(v_cur, 1, p_zip_file);
		if v_col_cnt >= 2 then
			dbms_sql.define_column(v_cur, 2, p_Archive_Name, 4000);
		end if;
		v_rows := dbms_sql.execute_and_fetch (v_cur);
		if v_rows > 0 then
			dbms_sql.column_value(v_cur, 1, p_zip_file);
			if v_col_cnt >= 2 then
				dbms_sql.column_value(v_cur, 2, p_Archive_Name);
			end if;
		end if;
		dbms_sql.close_cursor(v_cur);
	exception
	  when others then
		dbms_sql.close_cursor(v_cur);
		raise;
	end Load_zip_file_query;

	PROCEDURE Delete_Zip_File_Query (
		p_Delete_Zip_Query IN VARCHAR2,
		p_Search_Value IN VARCHAR2
	)
	is
		v_cur INTEGER;
		v_rows INTEGER;
	begin
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Delete_Zip_Query, DBMS_SQL.NATIVE);
		IF p_Search_Value IS NOT NULL then
			dbms_sql.bind_variable(v_cur, ':search_value', p_Search_Value);
		end if;
		v_rows := dbms_sql.execute (v_cur);
		dbms_sql.close_cursor(v_cur);
	exception
	  when others then
		dbms_sql.close_cursor(v_cur);
		raise;
	end Delete_Zip_File_Query;

	PROCEDURE Save_Unzipped_File (
		p_Save_File_Code VARCHAR2,
		p_Folder_Id	INTEGER,
		p_unzipped_file BLOB,
		p_File_Name	VARCHAR2,
		p_File_Date DATE,
		p_File_Size	INTEGER,
		p_Mime_Type	VARCHAR2
	)
	is
		v_cur INTEGER;
		v_rows INTEGER;
	begin
$IF Unzip_Parallel.c_debug $THEN
		dbms_output.put_line('Save_Unzipped_File: '||p_Folder_Id ||' ,' || p_File_Name || ', ' || p_File_Date);
$END
		-- :folder_id, :unzipped_file, :file_name, :file_date, :file_size, :mime_type
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, 'begin ' || p_Save_File_Code || ' end;', DBMS_SQL.NATIVE);
		if instr(p_Save_File_Code, ':folder_id') > 0 then
			dbms_sql.bind_variable(v_cur, ':folder_id', p_Folder_Id);
		end if;
		if instr(p_Save_File_Code, ':unzipped_file') > 0 then
			dbms_sql.bind_variable(v_cur, ':unzipped_file', p_unzipped_file);
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
	end;


	FUNCTION Root_Path (
		p_Path_Name		VARCHAR2
	) return VARCHAR2
	is -- no leading dash, one trailing dash
	begin
		return LTRIM(RTRIM(p_Path_Name, '/'), '/') || '/';
	end;

	function Archive_Name (
		p_Path_Name	VARCHAR2
	)
	return VARCHAR2
	is
		v_File_Name as_zip.t_path_name;
	begin
		v_File_Name := SUBSTR(p_Path_Name, INSTR(p_Path_Name, '/', -1) + 1);
		if INSTR(v_File_Name,'.', -1) > 0 then
			v_File_Name := SUBSTR(v_File_Name, 1, INSTR(v_File_Name, '.', -1) - 1);
		end if;
		return v_File_Name;
	end;

	function Prefix_File_Path(
		p_Archive_Name VARCHAR2,
		p_File_Path VARCHAR2
	)
	return VARCHAR2
	is
		v_File_Path as_zip.t_path_name;
	begin
		v_File_Path := p_File_Path;
		if INSTR(v_File_Path, p_Archive_Name || '/') = 1 then
			return p_File_Path;
		elsif p_Archive_Name IS NULL then
			return p_File_Path;
		else
			return p_Archive_Name || '/' || p_File_Path;
		end if;
	end;

	PROCEDURE Expand_Zip_Range (
		p_Start_ID INTEGER DEFAULT NULL,
		p_End_ID INTEGER DEFAULT NULL,
		p_Init_Session_Code VARCHAR2 DEFAULT NULL,
		p_Load_Zip_Code 	VARCHAR2 DEFAULT NULL,
		p_Load_Zip_Query	VARCHAR2 DEFAULT NULL,
		p_Search_Value		VARCHAR2 DEFAULT NULL,
		p_Create_Path_Code 	VARCHAR2 DEFAULT NULL,
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',
		p_Save_File_Code 	VARCHAR2,
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Only_Files 		BOOLEAN DEFAULT TRUE,
		p_Skip_Empty 		BOOLEAN DEFAULT TRUE,
		p_Skip_Dot 			BOOLEAN DEFAULT TRUE,
		p_Encoding			VARCHAR2 DEFAULT NULL
	)
	is
        v_zipped_blob 	blob;
		v_unzipped_file blob;
		v_file_list		as_zip.file_list;
		v_date_list		as_zip.date_list;
	    v_offset_list 	as_zip.foffset_list;
	    v_filter_result	BINARY_INTEGER;
		v_File_Name 	as_zip.t_path_name;
		v_File_Date		DATE;
		v_Archive_Name 	as_zip.t_path_name;
		v_Parent_Folder	as_zip.t_path_name;
		v_Full_Path 	as_zip.t_path_name;
		v_File_Path 	as_zip.t_path_name;
		v_Last_Path 	as_zip.t_path_name := ' ';
		v_Mime_Type		VARCHAR2(4000);
		v_File_Size		INTEGER;
		v_Folder_Id 	INTEGER;
    	v_root_id 		INTEGER;
        v_rindex 		BINARY_INTEGER := dbms_application_info.set_session_longops_nohint;
        v_slno   		BINARY_INTEGER;
        v_Start_ID		BINARY_INTEGER;
        v_End_ID		BINARY_INTEGER;
	begin
		if p_Init_Session_Code IS NOT NULL then
			execute immediate 'begin ' || p_Init_Session_Code || ' end;';
		end if;
		-- Load_zip_file (:zip_file, :target_desc, :root_id)
		if p_Load_Zip_Code IS NOT NULL then
			execute immediate 'begin ' || p_Load_Zip_Code || ' end;'
			using out v_zipped_blob, v_Archive_Name;
		else
			Unzip_Parallel.Load_zip_file_query (p_Load_Zip_Query, p_Search_Value, v_zipped_blob, v_Archive_Name);
		end if;
		commit; -- release lock on zipped file.
		if v_zipped_blob IS NULL then
			raise_application_error (Unzip_Parallel.c_App_Error_Code, c_msg_file_bad_type);
		end if;
		v_Archive_Name := Archive_Name(v_Archive_Name);
		if p_Create_Path_Code IS NOT NULL and p_Parent_Folder IS NOT NULL then -- get Root_id
			v_Parent_Folder := Root_Path(p_Parent_Folder);
			v_Folder_Id := NULL;
			execute immediate 'begin :folder_id := ' || p_Create_Path_Code || '; end;'
				using out v_root_id, v_Parent_Folder, v_Folder_Id;
			v_Folder_Id := v_root_id;
$IF Unzip_Parallel.c_debug $THEN
			dbms_output.put_line('Parent_Folder B: ' || v_Parent_Folder || ', id : ' || v_root_id);
$END
		end if;

		as_zip.get_file_date_list ( v_zipped_blob, p_Encoding, v_file_list, v_date_list, v_offset_list);
		v_Start_ID 	:= NVL(p_Start_ID, 1);
		v_End_ID	:= LEAST(NVL(p_End_ID, v_file_list.count), v_file_list.count);
		for i in v_Start_ID .. v_End_ID loop
			dbms_application_info.set_session_longops(
			  rindex       => v_rindex,
			  slno         => v_slno,
			  op_name      => Unzip_Parallel.c_Process_Name,
			  target       => 0,
			  context      => p_Context,
			  sofar        => i - v_Start_ID + 1,
			  totalwork    => v_End_ID - v_Start_ID + 1,
			  target_desc  => SUBSTR(p_Search_Value, 1, 32),
			  units        => 'files'
			);
			v_Full_Path := v_file_list(i);
			v_File_Date := v_date_list(i);
			-- :filter_result := INSTR(:path_name, '__MACOSX/') != 1;
			execute immediate 'begin :filter_result := case when ' || p_Filter_Path_Cond || ' then 1 else 0 end; end;'
				using out v_filter_result, v_Full_Path;
			if v_filter_result = 1 then
				v_unzipped_file := as_zip.get_file (
					p_zipped_blob => v_zipped_blob, 
					p_file_name => v_Full_Path, 
					p_offset => v_offset_list(i)
				);
				if p_Create_Path_Code IS NOT NULL then
					v_File_Path := NVL(SUBSTR(v_Full_Path, 1, INSTR(v_Full_Path, '/', -1)), ' ');
					v_File_Path := Prefix_File_Path(v_Archive_Name, v_File_Path);
					v_File_Name := SUBSTR(v_Full_Path, INSTR(v_Full_Path, '/', -1) + 1);
$IF Unzip_Parallel.c_debug $THEN
					dbms_output.put_line('Current Path ' || v_File_Path || ' - Full: ' || v_Full_Path );
$END
					if v_File_Path != v_Last_Path
					and (NOT p_Only_Files or v_File_Name IS NOT NULL) then
						-- :folder_id := Unzip_Parallel.Create_Path (:path_name, :root_id);
						execute immediate 'begin :folder_id := ' || p_Create_Path_Code || '; end;'
							using out v_Folder_Id, v_File_Path, v_root_id;
$IF Unzip_Parallel.c_debug $THEN
						dbms_output.put_line('----------');
						dbms_output.put_line('Create_Path ' || v_Folder_Id || ' ' || v_File_Path );
$END
						v_Last_Path := v_File_Path;
					end if;
				else -- when no path is stored, then the file name includes the file path
					v_File_Name := v_Parent_Folder || v_Full_Path;
					v_Folder_Id := NULL;
				end if;
				if v_File_Name IS NOT NULL
				and (NOT p_Skip_Empty or v_unzipped_file IS NOT NULL)
				and (NOT p_Skip_Dot or SUBSTR(v_File_Name, 1, 1) != '.') then
					v_Mime_Type := unzip_parallel.Mime_Type_from_Extension(v_File_Name);
					v_File_Size := NVL(dbms_lob.getlength(v_unzipped_file), 0);
					-- Save_File (:unzipped_file, :file_name, :file_date, :file_size, :mime_type, :folder_id));
					Save_Unzipped_File( p_Save_File_Code,
						v_Folder_Id, v_unzipped_file, v_File_Name, v_File_Date, v_File_Size, v_Mime_Type);
					if p_Start_ID IS NOT NULL then 	-- when not empty this procedure is called by dbms_parallel_execute.
						commit;						-- release locks in parallel mode to avoid contention
					end if;
				end if;
			end if;
		end loop;
	end Expand_Zip_Range;

	PROCEDURE  Create_Folders (
		p_Load_Zip_Code 	VARCHAR2 DEFAULT NULL,	-- PL/SQL code for loading the zipped blob and filename. The bind variable :search_value can be used to pass the p_Search_Value attribute.
		p_Load_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for loading the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind to the Page Item provided by the Search Item Attribute.
		p_Search_Value		VARCHAR2 DEFAULT NULL,	-- Search value for the bind variable in the Load Zip Query code.
		p_Create_Path_Code 	VARCHAR2 DEFAULT NULL,	-- PL/SQL code to save the path of the saved files.
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',-- Condition to filter the folders that are extracted from the zip archive. The bind variable :path_name delivers path names like /root/sub1/sub2/ to the expression.
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,	-- Pathname of the Directory where the unzipped files are saved.
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Only_Files 		BOOLEAN DEFAULT TRUE,	-- If set to Yes, empty directory entries are not created. Otherwise, set to No to include empty directory entries..
		p_Encoding			IN OUT NOCOPY VARCHAR2, -- This is the encoding used to zip the file. (AL32UTF8 or US8PC437)
		p_File_Size			OUT INTEGER,
		p_total_count		OUT INTEGER,
		p_SQLCode 			OUT INTEGER,
		p_Message 			OUT NOCOPY VARCHAR2
	)
	is
    	v_root_id 		INTEGER;
        v_zipped_blob 	BLOB;
		v_total_count 	INTEGER;
		v_Archive_Name 	as_zip.t_path_name;
		v_Parent_Folder	as_zip.t_path_name;
		v_status 		INTEGER;
		v_folders_limit CONSTANT INTEGER := 1000;
		v_folder_list	as_zip.file_list;
		v_Full_Path 	as_zip.t_path_name;
	    v_filter_result	BINARY_INTEGER;
        v_Folder_Id		INTEGER;
        v_rindex 		BINARY_INTEGER := dbms_application_info.set_session_longops_nohint;
        v_slno   		BINARY_INTEGER;
	begin
		p_File_Size := 0;
		p_total_count := 0;
		if p_Load_Zip_Code IS NOT NULL then
			execute immediate 'begin ' || p_Load_Zip_Code || ' end;'
			using out v_zipped_blob, v_Archive_Name;
		else
			Unzip_Parallel.Load_zip_file_query (p_Load_Zip_Query, p_Search_Value, v_zipped_blob, v_Archive_Name);
		end if;
		if v_zipped_blob IS NULL then
			p_Message	:= Unzip_Parallel.c_msg_file_bad_type;
			return;
		end if;
		v_Archive_Name := Archive_Name(v_Archive_Name);
		Unzip_Parallel.get_folder_list( v_zipped_blob, p_only_files, p_Encoding, v_folders_limit, v_folder_list, v_total_count);
		p_File_Size := dbms_lob.getlength(v_zipped_blob);
		p_total_count := v_total_count;
		v_zipped_blob := NULL;
		commit;	-- release lock on zipped file.
		if v_total_count = 0 then
			p_Message	:= Unzip_Parallel.c_msg_file_empty;
			return;
		end if;
		if p_Parent_Folder IS NOT NULL then	-- get v_root_id
			v_Parent_Folder := Root_Path(p_Parent_Folder);
			v_Folder_Id := NULL;
			execute immediate 'begin :folder_id := ' || p_Create_Path_Code || '; end;'
				using out v_root_id, v_Parent_Folder, v_Folder_Id;
		end if;
		-- create up to v_folders_limit folders from the v_folder_list to avoid contention locks on the folder rows.
		for i in 1 .. v_folder_list.count loop
			if mod(i, 30) = 0 or i = v_folder_list.count then
				dbms_application_info.set_session_longops(
				  rindex       => v_rindex,
				  slno         => v_slno,
				  op_name      => Unzip_Parallel.c_Process_Name,
				  target       => 0,
				  context      => p_Context,
				  sofar        => i,
				  totalwork    => v_folder_list.count,
				  target_desc  => SUBSTR(p_Search_Value, 1, 64),
				  units        => 'folders'
				);
			end if;
			v_Full_Path := v_folder_list(i);
			-- :filter_result := INSTR(:path_name, '__MACOSX/') != 1;
			execute immediate 'begin :filter_result := case when ' || p_Filter_Path_Cond || ' then 1 else 0 end; end;'
				using out v_filter_result, v_Full_Path;
			if v_filter_result = 1 then
				-- :folder_id := Unzip_Parallel.Create_Path (:path_name, :root_id);
				v_Full_Path := Prefix_File_Path(v_Archive_Name, v_Full_Path);
				execute immediate 'begin :folder_id := ' || p_Create_Path_Code || '; end;'
					using out v_Folder_Id, v_Full_Path, v_root_id;
			end if;
		end loop;
	end;

	-- create and run a DBMS_PARALLEL_EXECUTE task to execute Expand_Zip_Range in chunks
	PROCEDURE Expand_Zip_Archive (
		p_Init_Session_Code VARCHAR2 DEFAULT NULL,	-- PL/SQL code for initialization of session context.
		p_Load_Zip_Code 	VARCHAR2 DEFAULT NULL,	-- PL/SQL code for loading the zipped blob and filename. The bind variable :search_value can be used to pass the p_Search_Value attribute.
		p_Load_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for loading the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind to the Page Item provided by the Search Item Attribute.
		p_Delete_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for deleting the source of the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind.
		p_Search_Value		VARCHAR2 DEFAULT NULL,	-- Search value for the bind variable in the Load Zip Query code.
		p_Folder_query 		VARCHAR2 DEFAULT NULL,	-- SQL Query for parameters to store the folders in a recursive tree table. When this field is empty, the :file_name will be prefixed with the path in the Save file code.
		p_Create_Path_Code 	VARCHAR2 DEFAULT NULL,	-- PL/SQL code to save the path of the saved files.
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',-- Condition to filter the folders that are extracted from the zip archive. The bind variable :path_name delivers path names like /root/sub1/sub2/ to the expression.
		p_Save_File_Code 	VARCHAR2,				-- PL/SQL code to save an unzipped file from the zip archive. The bind variables :unzipped_file, :file_name, :file_date, :file_size, :mime_type, :folder_id deliver values to be saved.
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,	-- Pathname of the Directory where the unzipped files are saved.
		p_Container_ID		NUMBER  DEFAULT NULL,   -- folder table foreign key reference value to container table
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Only_Files 		BOOLEAN DEFAULT TRUE,	-- If set to Yes, empty directory entries are not created. Otherwise, set to No to include empty directory entries..
		p_Skip_Empty 		BOOLEAN DEFAULT TRUE,	-- If set to Yes, then empty files are skipped and not saved.
		p_Skip_Dot 			BOOLEAN DEFAULT TRUE,	-- If set to Yes, then files with a file name that start with '.' are skipped and not saved.
		p_Execute_Parallel	BOOLEAN DEFAULT TRUE,	-- If set to Yes, then files are processed in parallel jobs.
		p_Encoding			VARCHAR2 DEFAULT NULL, -- This is the encoding used to zip the file. (AL32UTF8 or US8PC437)
		p_SQLCode 			OUT INTEGER,
		p_Message 			OUT NOCOPY VARCHAR2
	)
	is
		v_Create_Path_Code 	VARCHAR2(4000);
		v_process_text 	VARCHAR2(4000);
		v_encoding		VARCHAR2(100) := p_Encoding;
        v_file_size		INTEGER;
		v_total_count 	INTEGER;
        v_Execute_Parallel BOOLEAN;
	begin
		if p_Init_Session_Code IS NOT NULL then
			execute immediate 'begin ' || p_Init_Session_Code || ' end;';
		end if;
		if p_Folder_query IS NOT NULL then
			v_Create_Path_Code := 'Unzip_Parallel.Create_Path(:path_name, :root_id, ' 
			|| 'q''[' || p_Folder_query|| ']'', ' 
			|| dbms_assert.enquote_literal(p_Container_ID) 
			|| ')';
		else
			v_Create_Path_Code := p_Create_Path_Code;
		end if;
		v_Execute_Parallel := p_Execute_Parallel;
		if v_Execute_Parallel then
			if v_Create_Path_Code IS NOT NULL then
				Unzip_Parallel.Create_Folders (
						p_Load_Zip_Code 	=> p_Load_Zip_Code,
						p_Load_Zip_Query	=> p_Load_Zip_Query,
						p_Search_Value		=> p_Search_Value,
						p_Create_Path_Code 	=> v_Create_Path_Code,
						p_Filter_Path_Cond 	=> p_Filter_Path_Cond,
						p_Parent_Folder		=> p_Parent_Folder,
						p_Context			=> p_Context,
						p_Only_Files		=> p_Only_Files,
						p_Encoding			=> v_encoding,
						p_File_Size			=> v_file_size,
						p_total_count		=> v_total_count,
						p_SQLCode 			=> p_SQLCode,
						p_Message 			=> p_Message
				);
				if v_file_size < c_size_lower_limit then
					v_Execute_Parallel := false;
				end if;
			end if;
		end if;
		if v_Execute_Parallel then
			v_process_text :=
				'begin Unzip_Parallel.Expand_Zip_Range(' || chr(10)
				|| 'p_Start_ID => :start_id, ' || chr(10)
				|| 'p_End_ID => :end_id, ' || chr(10)
				|| case when p_Init_Session_Code IS NOT NULL then 'p_Init_Session_Code => q''{' || p_Init_Session_Code || '}'',' || chr(10) end
				|| case when p_Load_Zip_Code IS NOT NULL then 'p_Load_Zip_Code => q''{' || p_Load_Zip_Code || '}'',' || chr(10) end
				|| case when p_Load_Zip_Query IS NOT NULL then 'p_Load_Zip_Query => q''{' || p_Load_Zip_Query || '}'',' || chr(10) end
				|| case when p_Search_Value IS NOT NULL then 'p_Search_Value => q''{' || p_Search_Value || '}'',' || chr(10) end
				|| case when v_Create_Path_Code IS NOT NULL then 'p_Create_Path_Code => q''{' || v_Create_Path_Code || '}'',' || chr(10) end
				|| case when p_Filter_Path_Cond IS NOT NULL then 'p_Filter_Path_Cond => q''{' || p_Filter_Path_Cond || '}'',' || chr(10) end
				|| 'p_Save_File_Code => q''{' || p_Save_File_Code || '}'',' || chr(10)
				|| case when p_Parent_Folder IS NOT NULL then 'p_Parent_Folder => q''{' || p_Parent_Folder || '}'',' || chr(10) end
				|| 'p_Context => ' || p_Context || ',' || chr(10)
				|| 'p_Only_Files => ' || case when p_Only_Files then 'true' else 'false' end || ',' || chr(10)
				|| 'p_Skip_Empty => ' || case when p_Skip_Empty then 'true' else 'false' end || ',' || chr(10)
				|| 'p_Skip_Dot => ' || case when p_Skip_Dot then 'true' else 'false' end || ',' || chr(10)
				|| 'p_Encoding => q''{' || v_encoding || '}''' || chr(10)
				|| ');' || chr(10)
				|| 'end;';
$IF Unzip_Parallel.c_debug $THEN
			dbms_output.put_line('----');
			dbms_output.put_line(v_process_text);
$END
			commit; -- create folders finished
			Unzip_Parallel.Expand_Zip_Parallel (v_process_text, v_total_count, p_SQLCode, p_Message);
		else
			Unzip_Parallel.Expand_Zip_Range(
					p_Init_Session_Code => p_Init_Session_Code,
					p_Load_Zip_Code => p_Load_Zip_Code,
					p_Load_Zip_Query => p_Load_Zip_Query,
					p_Search_Value => p_Search_Value,
					p_Create_Path_Code => v_Create_Path_Code,
					p_Filter_Path_Cond => p_Filter_Path_Cond,
					p_Save_File_Code => p_Save_File_Code,
					p_Parent_Folder => p_Parent_Folder,
					p_Context => p_Context,
					p_Only_Files => p_Only_Files,
					p_Skip_Empty => p_Skip_Empty,
					p_Skip_Dot => p_Skip_Dot,
					p_Encoding => v_encoding
			);
			commit; -- create files and folders finished
			p_SQLCode := 0;
		end if;
		if p_Delete_Zip_Query IS NOT NULL then 
			Unzip_Parallel.Delete_Zip_File_Query (p_Delete_Zip_Query, p_Search_Value);
		end if;
	exception
	  when others then
	  	p_SQLCode := SQLCODE;
	  	p_Message := SQLERRM;
	  	ROLLBACK WORK;
		if p_Delete_Zip_Query IS NOT NULL then 
			Unzip_Parallel.Delete_Zip_File_Query (p_Delete_Zip_Query, p_Search_Value);
		end if;	  	
	end Expand_Zip_Archive;

	PROCEDURE Default_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2)
	is
	begin
		dbms_output.put_line('Expand_Zip_Archive_Job for file ' || p_Filename || ', Result : ' || p_SQLCode || '  ' || p_Message );
	end;

	PROCEDURE PLSQL_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2)
	is
		v_message		VARCHAR2(4000);
	begin
		if p_Message IS NOT NULL then
			v_message := APEX_LANG.LANG (
				p_primary_text_string => p_Message,
				p_primary_language => 'en'
			);
			raise_application_error (Unzip_Parallel.c_App_Error_Code, v_message);
		end if;
	end;

	PROCEDURE AJAX_Completion (p_SQLCode NUMBER, p_Message VARCHAR2, p_Filename VARCHAR2)
	is
	begin
		htp.init();
		if p_SQLCode = 0 then
			htp.p('OK');
		else
			htp.p(p_Message);
		end if;
	exception when value_error then
		dbms_output.put_line(p_Message);
	end;

	PROCEDURE Expand_Zip_Archive_Job (
		p_Init_Session_Code VARCHAR2 DEFAULT NULL,	-- PL/SQL code for initialization of session context.
		p_Load_Zip_Query	VARCHAR2,	-- SQL Query for loading the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind to the Page Item provided by the Search Item Attribute.
		p_Delete_Zip_Query	VARCHAR2 DEFAULT NULL,	-- SQL Query for deleting the source of the zipped blob and filename. The bind variable :search_value or an page item name can be used to bind.
		p_File_Names		VARCHAR2,	-- file names for the bind variable in the Load Zip Query code.
		p_Folder_query 		VARCHAR2,	-- SQL Query for parameters to store the folders in a recursive tree table. When this field is empty, the :file_name will be prefixed with the path in the Save file code.
		p_Filter_Path_Cond 	VARCHAR2 DEFAULT 'true',-- Condition to filter the folders that are extracted from the zip archive. The bind variable :path_name delivers path names like /root/sub1/sub2/ to the expression.
		p_Save_File_Code 	VARCHAR2,				-- PL/SQL code to save an unzipped file from the zip archive. The bind variables :unzipped_file, :file_name, :file_date, :file_size, :mime_type, :folder_id deliver values to be saved.
		p_Parent_Folder 	VARCHAR2 DEFAULT NULL,	-- Pathname of the Directory where the unzipped files are saved.
		p_Container_ID		NUMBER  DEFAULT NULL,   -- folder table foreign key reference value to container table
		p_Context  			BINARY_INTEGER DEFAULT 0,
		p_Completion_Procedure VARCHAR2 DEFAULT 'unzip_parallel.Default_Completion' -- Name of a procedure with a call profile like: unzip_Completion(p_SQLCode NUMBER, p_Message VARCHAR2)
	)
	is
		v_file_names 	apex_application_global.vc_arr2;
		v_message		VARCHAR2(4000);
		v_SQLCode 		INTEGER;
	begin
		v_file_names := apex_util.string_to_table( p_File_Names );
		for i in 1 .. v_file_names.count loop
			Unzip_Parallel.Expand_Zip_Archive (
				p_Init_Session_Code => p_Init_Session_Code,
				p_Load_Zip_Query => p_Load_Zip_Query,
				p_Delete_Zip_Query => p_Delete_Zip_Query,
				p_Search_Value => v_file_names(i),
				p_Folder_query => p_Folder_query,
				p_Filter_Path_Cond => p_Filter_Path_Cond,
				p_Save_File_Code => p_Save_File_Code,
				p_Parent_Folder => p_Parent_Folder,
				p_Container_ID => p_Container_ID,
				p_Context => p_Context,
				p_Execute_Parallel	=> true,
				p_SQLCode => v_SQLCode,
				p_Message => v_Message
			);
			if p_Completion_Procedure IS NOT NULL then 
				execute immediate 'begin ' || p_Completion_Procedure || '(:a, :b, :c); end;'
				using in v_SQLCode, v_Message, v_file_names(i);
			end if;
		end loop;
	end Expand_Zip_Archive_Job;

end unzip_parallel;
/
show errors

