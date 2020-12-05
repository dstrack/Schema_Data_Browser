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

------------------------------------------------------------------------------
Plugin for uploading data into a APEX_COLLECTION and then edit and save the collection data without programming pl/sql code.

Purpose: Upload CSV data via copy and paste or via file upload.
The optional first line of the input (file) and the currency symbols will be removed from the input.
The plugin process copies the data into new rows in the named apex collection. 
The character columns C001 - C050 of the apex collection will contain the data in the the corresponding rows and columns from the input.

Now you can access and update forms and interactive grids that are based on an APEX_COLLECTION without additional PL/SQL code.
Usage in IG:
Create an IG Region based on a SQL Query :
	select COLLECTION_NAME,
		   SEQ_ID,
		   C001,
		   C002,
		   C003,...
	from V_APEX_COLLECTIONS
	where COLLECTION_NAME = 'IMPORTED_DATA'
	
When the Region is created change some attributes:
1. Column 'COLLECTION_NAME'
	Type : Hidden
	Query Only 	: No 
	Primary Key : No 
	Default 
		Type : Static
		Static Value : IMPORTED_DATA
2. Column 'SEQ_ID' 
	Query Only 	: Yes 
	Primary Key : Yes 
3. Process  - Save Interactive Grid Data
	Prevent Lost Updates : No 
	Lock Row : No 
	Return Primary Key(s) after Insert : No 
4. If you want to allow inserting of new rows in the grid, then because the Primary Key(s) are not returned after Insert,
	the page has to be submitted and reloaded after processing of the SAVE button/request.
	In the following code can be used in the Init Javascript field for the interactive grid.

function(config) {
    config.initActions = function( actions ) {
        actions.lookup("save").action = function(event, focusElement) {
			apex.page.submit( "SAVE" );
		};
        actions.update("save");
    }
    return config;
}	
	
This sample application demonstrates the usage of the plugin and the view v_apex_collections in an updatable interactive grid.
No pl/sql code is required to perform the DML operations.
-------------------------------------------------------------------------

- Plugin Callbacks:
- Execution Function Name: upload_to_collection_plugin.plugin_Upload_to_Collection
	attribute_01 : Import From Item
	attribute_02 : Separator Item
	attribute_03 : File Name Item
	attribute_04 : Character Set Item
	attribute_05 : Rows Loaded Item
	attribute_06 : Collection Name
	attribute_07 : Show Success Message
	attribute_08 : Enclosed By Item
	attribute_09 : FIrst Row Item
	attribute_10 : Currency Symbol Item
	attribute_11 : Column Headers Item
	attribute_12 : Use Apex Data Parser

*/

declare 
	v_has_data_parser VARCHAR2(128);
	v_stat VARCHAR2(32767);
begin 
	SELECT case when TO_NUMBER(SUBSTR(VERSION_NO, 1, INSTR(VERSION_NO, '.') - 1)) >= 18 
		then 'TRUE' else 'FALSE' end 
	INTO v_has_data_parser
	FROM APEX_RELEASE;
	
	v_stat := '
CREATE OR REPLACE PACKAGE upload_to_collection_plugin
AUTHID CURRENT_USER
IS
	g_has_data_parser 		CONSTANT BOOLEAN := ' || v_has_data_parser || q'[;
	g_msg_file_name_empty 	CONSTANT VARCHAR2(100) := 'Filename is empty.';
	g_msg_file_empty 		CONSTANT VARCHAR2(100) := 'File content is empty.';
	g_msg_no_data_parser	CONSTANT VARCHAR2(100) := 'The APEX_DATA_PARSER is not available is this APEX Version.';
	g_msg_no_data_found		CONSTANT VARCHAR2(100) := 'No valid data found in import file.';
	g_msg_line_delimiter 	CONSTANT VARCHAR2(100) := 'Line delimiter not found.';
	g_msg_separator_head	CONSTANT VARCHAR2(100) := 'Separator not found in the first line.';
	g_msg_separator_body	CONSTANT VARCHAR2(100) := 'Separator not found in line ';
	g_msg_process_success 	CONSTANT VARCHAR2(100) := '%0 rows have been loaded.';
	g_linemaxsize     		CONSTANT INTEGER 	  := 4000;
	g_Collection_Cols_Limit CONSTANT PLS_INTEGER := 50;

	FUNCTION Blob_to_Clob(
		p_blob IN BLOB,
		p_blob_charset IN VARCHAR2 DEFAULT NULL
	)  return CLOB;

	FUNCTION Split_Clob (
		p_clob 				IN CLOB,
		p_Enclosed_By 		IN VARCHAR2,
		p_delimiter 		IN VARCHAR2
	) RETURN sys.odciVarchar2List PIPELINED;	-- VARCHAR2(4000)

	PROCEDURE Upload_to_Apex_Collection (
		p_Import_From		IN VARCHAR2, -- UPLOAD or PASTE. UPLOAD will be replaced by PASTE
		p_Column_Delimiter  IN VARCHAR2 DEFAULT NULL,
		p_Enclosed_By       IN VARCHAR2 DEFAULT '"',
		p_Currency_Symbol	IN VARCHAR2,
		p_First_Row			IN VARCHAR2,
		p_File_Name			IN VARCHAR2,
		p_File_Table_Name	IN VARCHAR2,
		p_Character_Set		IN VARCHAR2,
		p_Collection_Name   IN VARCHAR2,
		p_Use_Apex_Data_Parser IN VARCHAR2 DEFAULT 'N',
		p_Column_Headers	OUT VARCHAR2,
		p_Rows_Cnt			OUT INTEGER,
		p_Message			OUT VARCHAR2
	);

	FUNCTION plugin_Upload_to_Collection (
		p_process in apex_plugin.t_process,
		p_plugin  in apex_plugin.t_plugin )
	RETURN apex_plugin.t_process_exec_result;

	FUNCTION Access_Collection_Query(
		p_Query IN CLOB,
		p_Collection_Name IN VARCHAR2,
		p_From_View_Name IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Create_Collection_From_Query (
		p_collection_name		IN VARCHAR2,
		p_query					IN VARCHAR2,
		p_generate_md5 			IN VARCHAR2 DEFAULT 'NO',
		p_truncate_if_exists 	IN VARCHAR2 DEFAULT 'NO',
		p_From_View_Name 		IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Access_Collection_Query2(
		p_Query IN CLOB,
		p_Collection_Name IN VARCHAR2,
		p_From_View_Name IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC;

	FUNCTION Create_Collection_From_Query2 (
		p_collection_name		IN VARCHAR2,
		p_query					IN VARCHAR2,
		p_generate_md5 			IN VARCHAR2 DEFAULT 'NO',
		p_truncate_if_exists 	IN VARCHAR2 DEFAULT 'NO',
		p_From_View_Name 		IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC;

END upload_to_collection_plugin;
]';
	EXECUTE IMMEDIATE v_Stat;
end;
/


CREATE OR REPLACE PACKAGE BODY upload_to_collection_plugin IS
	function Charset_Code (p_Charset_Name VARCHAR2) return varchar2
	is
	begin
		return case lower(p_Charset_Name)
			when 'iso-8859-6' then 'AR8ISO8859P6' -- 'Arabic ISO-8859-6'
			when 'windows-1256' then 'AR8MSWIN1256' -- 'Arabic Windows 1256'
			when 'big5' then 'ZHT16MSWIN950' -- 'Chinese Big5'
			when 'gbk' then 'ZHS16GBK' -- 'Chinese GBK'
			when 'iso-8859-5' then 'CL8ISO8859P5' -- 'Cyrilic ISO-8859-5'
			when 'koi8-r' then 'CL8KOI8R' -- 'Cyrilic KOI8-R'
			when 'koi8-u' then 'CL8KOI8U' -- 'Cyrilic KOI8-U'
			when 'windows-1251' then 'CL8MSWIN1251' -- 'Cyrilic Windows 1251'
			when 'iso-8859-2' then 'EE8ISO8859P2' -- 'Eastern European ISO-8859-2'
			when 'windows-1250' then 'EE8MSWIN1250' -- 'Eastern European Windows 1250'
			when 'iso-8859-7' then 'EL8ISO8859P7' -- 'Greek ISO-8859-7'
			when 'windows-1253' then 'EL8MSWIN1253' -- 'Greek Windows 1253'
			when 'iso-8859-8-i' then 'IW8ISO8859P8' -- 'Hebrew ISO-8859-8-i'
			when 'windows-1255' then 'IW8MSWIN1255' -- 'Hebrew Windows 1255'
			when 'euc-jp' then 'JA16EUC' -- 'Japanese EUC'
			when 'shift_jis' then 'JA16SJIS' -- 'Japanese Shift JIS'
			when 'euc-kr' then 'KO16MSWIN949' -- 'Korean EUC'
			when 'iso-8859-4' then 'NEE8ISO8859P4' -- 'Northern European ISO-8859-4'
			when 'windows-1257' then 'BLT8MSWIN1257' -- 'Northern European Windows 1257'
			when 'iso-8859-3' then 'SE8ISO8859P3' -- 'Southern European ISO-8859-3'
			when 'tis-620' then 'TH8TISASCII' -- 'Thai TIS-620'
			when 'iso-8859-9' then 'WE8ISO8859P9' -- 'Turkish ISO-8859-9'
			when 'windows-1254' then 'TR8MSWIN1254' -- 'Turkish Windows 1254'
			when 'utf-8' then 'AL32UTF8' -- 'Unicode UTF-8'
			when 'utf-16be' then 'AL16UTF16' -- 'Unicode UTF-16 Big Endian'
			when 'utf-16le' then 'AL16UTF16LE' -- 'Unicode UTF-16 Little Endian'
			when 'windows-1258' then 'VN8MSWIN1258' -- 'Vietnamese Windows 1258'
			when 'iso-8859-1' then 'WE8ISO8859P1' -- 'Western European ISO-8859-1'
			when 'iso-8859-15' then 'WE8ISO8859P15' -- 'Western European ISO-8859-15'
			when 'windows-1252' then 'WE8MSWIN1252' -- 'Western European Windows 1252'
			when 'euc-tw' then 'ZHT32EUC' -- 'Chinese EUC'
			when 'us-ascii' then 'US7ASCII' -- 'US-ASCII'
			else p_Charset_Name
		end;
	end Charset_Code;

	FUNCTION Blob_to_Clob(
		p_blob IN BLOB,
		p_blob_charset IN VARCHAR2 DEFAULT NULL
	)  return CLOB
	is
	v_clob	CLOB;
	v_dstoff	INTEGER := 1;
	v_srcoff	INTEGER := 1;
	v_langctx 	INTEGER := 0;
	v_warning 	INTEGER := 1;
	v_blob_csid NUMBER;
	v_utf8_bom  raw(10) := hextoraw('EFBBBF');
	v_utf16le_bom raw(10) := hextoraw('FFFE');
	v_file_head raw(10);
	begin
		if dbms_lob.getlength(p_blob) > 3 then
			if p_blob_charset IS NOT NULL then
				v_blob_csid := nls_charset_id(Charset_Code(p_blob_charset));
			end if;
			if v_blob_csid IS NULL then
				v_blob_csid := DBMS_LOB.DEFAULT_CSID;
			end if;

			v_file_head := dbms_lob.substr(p_blob, 3, 1);
			if UTL_RAW.COMPARE (v_utf8_bom, v_file_head) = 0 then
				v_srcoff := 4;
				v_blob_csid := nls_charset_id('AL32UTF8');
			else 
				v_file_head := dbms_lob.substr(p_blob, 2, 1);
				if UTL_RAW.COMPARE (v_utf16le_bom, v_file_head) = 0 then
					v_srcoff := 3;
					v_blob_csid := nls_charset_id('AL16UTF16LE');
				end if;
			end if;

			dbms_lob.createtemporary(v_clob, true, dbms_lob.call);
			dbms_lob.converttoclob(
				dest_lob   =>	v_clob,
				src_blob   =>	p_blob,
				amount	   =>	dbms_lob.lobmaxsize,
				dest_offset =>	v_dstoff,
				src_offset	=>	v_srcoff,
				blob_csid	=>	v_blob_csid,
				lang_context => v_langctx,
				warning		 => v_warning
			);
		end if;
		return v_clob;
	end Blob_to_Clob;

	FUNCTION Split_Clob (
		p_clob 				IN CLOB,
		p_Enclosed_By 		IN VARCHAR2,
		p_delimiter 		IN VARCHAR2
	) RETURN sys.odciVarchar2List PIPELINED	-- VARCHAR2(4000)
	IS
		v_dellen    PLS_INTEGER;
		v_loblen	PLS_INTEGER			:= dbms_lob.getlength(p_clob);
		v_pos2 		PLS_INTEGER			:= 1;
		v_pos  		PLS_INTEGER			:= 1;
		v_parity1	PLS_INTEGER			:= 1;
		v_parity2	PLS_INTEGER			:= 1;
		v_linelen	PLS_INTEGER;
		v_delimiter VARCHAR2(10);
		v_Line 		VARCHAR2(32767);
		v_Row_Line 	VARCHAR2(32767);
	begin
		v_delimiter	:= p_delimiter;
		v_dellen	:= length(v_delimiter);
		if p_clob IS NOT NULL and v_loblen > 0 and v_dellen > 0 then
			loop
				exit when v_pos2 >= v_loblen;
				v_pos2 := dbms_lob.instr( p_clob, v_delimiter, v_pos );
				if v_pos2 = 0 then -- process last line
					v_pos2 := v_loblen;
					v_linelen := least(v_pos2 - v_pos + v_dellen, g_linemaxsize);
					v_Row_Line := dbms_lob.substr( p_clob, v_linelen, v_pos );
				else
					v_linelen := least(v_pos2 - v_pos, g_linemaxsize);
					if p_Enclosed_By IS NOT NULL then 
						v_Line := dbms_lob.substr( p_clob, v_linelen, v_pos );
						v_parity2 := mod(abs(length(replace(v_Line, p_Enclosed_By))-v_linelen), 2);
						v_parity1 := abs(v_parity2 - v_parity1);
						v_Row_Line := v_Row_Line || v_Line;
						v_linelen := length(v_Row_Line);
					else
						v_Row_Line := dbms_lob.substr( p_clob, v_linelen, v_pos );
					end if;
				end if;
				if v_linelen > 0 and v_parity1 = 1 then 
					pipe row( v_Row_Line );
					v_Row_Line := null;
				end if;
				v_pos := v_pos2 + v_dellen;
			end loop;
		end if;
		return ;
	END;

	FUNCTION Find_Column_Delimiter (
		p_clob 			IN CLOB,
		p_New_Line 		IN VARCHAR2
	) RETURN VARCHAR2
	is
		v_Row_Line 			VARCHAR2(32767);
		v_Row_Line2 		VARCHAR2(32767);
		v_Column_Cnt 		PLS_INTEGER;
		v_Column_Cnt2 		PLS_INTEGER;
		v_Offset	 		PLS_INTEGER;
		v_Offset2	 		PLS_INTEGER;
		v_Column_Delimiter 	VARCHAR2(10);
		v_Nllen PLS_INTEGER := LENGTH(p_New_Line);
	begin 
	
		for c_rows in (
			SELECT S.Column_Value, ROWNUM Line_No
			FROM TABLE( apex_string.split(p_str => chr(9)||':#:|:;:,', p_sep => ':') ) S
		)
		loop
			v_Column_Delimiter := c_rows.Column_Value;
			v_Offset   := dbms_lob.instr(p_Clob, p_New_Line);
			v_Row_Line := RTRIM(dbms_lob.substr(p_clob, v_Offset - 1, 1), v_Column_Delimiter);
			v_Column_Cnt := 1 + LENGTH(v_Row_Line) - LENGTH(REPLACE(v_Row_Line, v_Column_Delimiter));

			v_Offset2   := dbms_lob.instr(p_clob, p_New_Line, v_Offset+v_Nllen);
			v_Row_Line2 := RTRIM(dbms_lob.substr(p_clob, v_Offset2 - v_Offset - v_Nllen, v_Offset+v_Nllen), v_Column_Delimiter);
			if LENGTH(v_Row_Line2) > 0 then 
				v_Column_Cnt2 := 1 + LENGTH(v_Row_Line2) - LENGTH(REPLACE(v_Row_Line2, v_Column_Delimiter));
			else 
				v_Column_Cnt2 := v_Column_Cnt;
			end if;
			if apex_application.g_debug then
				apex_debug.info('Find_Column_Delimiter : %s', v_Column_Delimiter);
				apex_debug.info('v_Column_Cnt : %s. Import_Row_Line : #%s#', v_Column_Cnt, v_Row_Line);
				apex_debug.info('v_Column_Cnt2 : %s. Import_Row_Line2 : #%s#', v_Column_Cnt2, v_Row_Line2);
			end if;
			if v_Column_Cnt > 1 and v_Column_Cnt = v_Column_Cnt2 then 
				return v_Column_Delimiter;
			end if;
		end loop;
		
		return v_Column_Delimiter;
	end;
	
	PROCEDURE Upload_to_Apex_Collection (
		p_Import_From		IN VARCHAR2, -- UPLOAD or PASTE. UPLOAD will be replaced by PASTE
		p_Column_Delimiter  IN VARCHAR2 DEFAULT NULL,
		p_Enclosed_By       IN VARCHAR2 DEFAULT '"',
		p_Currency_Symbol	IN VARCHAR2,
		p_First_Row			IN VARCHAR2,
		p_File_Name			IN VARCHAR2,
		p_File_Table_Name	IN VARCHAR2,
		p_Character_Set		IN VARCHAR2,
		p_Collection_Name   IN VARCHAR2,
		p_Use_Apex_Data_Parser IN VARCHAR2 DEFAULT 'N',
		p_Column_Headers	OUT VARCHAR2,
		p_Rows_Cnt			OUT INTEGER,
		p_Message			OUT VARCHAR2
	)
	is
		v_Clob   			CLOB;
		v_Line_Array 		apex_t_varchar2;
		v_New_Line 			VARCHAR2(10);
		v_Column_Delimiter 	VARCHAR2(10);
		v_Enclosed_By    	VARCHAR2(10);
		v_Row_Line 			VARCHAR2(32767);
		v_Cell_Value		VARCHAR2(32767);
		v_Character_Set		VARCHAR2(100);
		v_Seq_ID 			PLS_INTEGER := 0;
		v_Column_Cnt 		PLS_INTEGER;
		v_Column_Limit		PLS_INTEGER;
		v_Offset	 		PLS_INTEGER;
   		cv 					SYS_REFCURSOR;
   		v_query				VARCHAR2(32767);
   		v_Squote 			CONSTANT VARCHAR2(10) := CHR(39); 	-- single quote
   		v_Prof_Collection_Name VARCHAR2(100) := 'FILE_PROFILE';
   		v_Skip_Rows 		NUMBER;
	begin
$IF upload_to_collection_plugin.g_has_data_parser $THEN 
		if p_Use_Apex_Data_Parser = 'Y' and p_Import_From = 'UPLOAD' then 
			for ind in 1..50 loop
				v_query := v_query 
				|| case when ind > 1 then ', '||chr(10)||chr(9) else 'SELECT'||chr(9) end
				|| 'COL' || TO_CHAR(ind, 'FM099');
			end loop;
			v_Character_Set := Charset_Code(p_Character_Set);
			v_Enclosed_By   := v_Squote||REPLACE(p_Enclosed_By, v_Squote, v_Squote||v_Squote)||v_Squote;
			v_Skip_Rows 	:= case when p_First_Row = 'Y' then 1 else 0 end;
			v_query := v_query || chr(10) || 'FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_File_Table_Name) 
			|| ' T, TABLE(apex_data_parser.parse(
				p_content => T.Blob_Content, 
				p_file_name => T.Name, 
				p_detect_data_types => ' || dbms_assert.enquote_literal('N') || ', ' || '
				p_csv_col_delimiter => ' || dbms_assert.enquote_literal(p_Column_Delimiter) || ', ' || '
				p_csv_enclosed => ' || v_Enclosed_By || ', ' || '
				p_skip_rows => ' || to_char(v_Skip_Rows)  || ', ' || '
				p_file_charset => ' || dbms_assert.enquote_literal(v_Character_Set) || ', ' || '
				p_store_profile_to_collection => ' || dbms_assert.enquote_literal(v_Prof_Collection_Name) || ')) S' || chr(10) 
			|| 'WHERE T.Name = ' || dbms_assert.enquote_literal(p_File_Name);
			if apex_application.g_debug then
				apex_debug.info('v_query : %s', v_query);
			end if;
			
			APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY (
				p_collection_name => p_Collection_Name, 
				p_query => v_query,
				p_truncate_if_exists => 'YES'
			);
			p_Rows_Cnt := APEX_COLLECTION.COLLECTION_MEMBER_COUNT( p_collection_name );
			SELECT LISTAGG(COLUMN_NAME, ':') WITHIN GROUP (ORDER BY COLUMN_POSITION) COLS
			INTO p_Column_Headers
			FROM APEX_COLLECTIONS S, (apex_data_parser.get_columns(S.clob001)) T
			WHERE S.COLLECTION_NAME = v_Prof_Collection_Name;
			p_Message  := 'OK';
			return;
		end if;
$ELSE
		if p_Use_Apex_Data_Parser = 'Y' and p_Import_From = 'UPLOAD' then 
			p_Message := g_msg_no_data_parser;
			return;
		end if;
$END 
		dbms_lob.createtemporary(v_Clob, true, dbms_lob.call);
		begin
		  apex_collection.create_or_truncate_collection (p_collection_name=>p_Collection_Name);
		exception
		  when dup_val_on_index then null;
		end;

		v_Enclosed_By := p_Enclosed_By;

		if p_Import_From = 'UPLOAD' then
			if p_File_Name IS NULL then
				p_Message := g_msg_file_name_empty;
				return;
			end if;

			-- load file content into v_Clob from WWV_FLOW_FILES or APEX_APPLICATION_TEMP_FILES
			OPEN cv FOR 'SELECT upload_to_collection_plugin.Blob_to_Clob(T.Blob_Content, :a)'
					|| ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_File_Table_Name)
					|| ' T WHERE T.Name = :b'
					USING p_Character_Set, p_File_Name;
			FETCH cv INTO v_Clob;
			IF cv%NOTFOUND THEN
				p_Message := g_msg_file_empty;
				return;
			END IF;
			CLOSE cv;
		elsif p_Import_From = 'PASTE' then
			-- load file content into v_Clob from APEX_COLLECTIONS
			SELECT clob001
			INTO v_Clob
			FROM apex_collections
			WHERE collection_name = 'CLOB_CONTENT';
		end if;
		-- try line delimiter \r\n -- crlf
		v_New_Line := chr(13) || chr(10);
		v_Offset   := dbms_lob.instr(v_Clob, v_New_Line);
		if v_Offset = 0 or v_Offset >= g_linemaxsize then
			-- try line delimiter lf
			v_New_Line := chr(10);
			v_Offset   := dbms_lob.instr(v_Clob, v_New_Line);
		end if;
		if v_Offset = 0 or v_Offset >= g_linemaxsize then
			-- try line delimiter cr
			v_New_Line := chr(13);
			v_Offset   := dbms_lob.instr(v_Clob, v_New_Line);
		end if;
		if v_Offset = 0 or v_Offset >= g_linemaxsize  then
			p_Message := g_msg_line_delimiter;
			return;
		end if;
		-- set Column Delimiter
		if p_Column_Delimiter IS NULL then 
			v_Column_Delimiter := Find_Column_Delimiter(v_Clob, v_New_Line);
		else 
			v_Column_Delimiter :=
				case p_Column_Delimiter
				when '\t' then chr(9)
				else p_Column_Delimiter end;
		end if;
		-- probe Column Delimiter
		v_Row_Line := RTRIM(dbms_lob.substr( v_clob, v_Offset - 1, 1 ), v_Column_Delimiter);
		v_Column_Cnt := 1 + LENGTH(v_Row_Line) - LENGTH(REPLACE(v_Row_Line, v_Column_Delimiter));
		if v_Column_Cnt = 1 and p_Column_Delimiter IS NOT NULL then
			p_Message := g_msg_separator_head;
			return;
		end if;
		-- probe optionally enclosed by
		if SUBSTR(v_Row_Line, 1, 1) = v_Enclosed_By
		and SUBSTR(RTRIM(v_Row_Line, v_Column_Delimiter||' '), -1, 1) = v_Enclosed_By
		and LENGTH(v_Row_Line) > 2 then
			v_Column_Delimiter 	:= v_Enclosed_By || v_Column_Delimiter || v_Enclosed_By;
		else
			v_Enclosed_By := NULL;
		end if;
		
		for c_rows in (
			SELECT S.Column_Value, ROWNUM Line_No
			FROM TABLE( upload_to_collection_plugin.Split_Clob(v_Clob, p_Enclosed_By, v_New_Line) ) S
		)
		loop
			if c_rows.Column_Value IS NOT NULL then
				v_Row_Line := case when v_Enclosed_By IS NOT NULL
								then SUBSTR(c_rows.Column_Value, 2, LENGTH(c_rows.Column_Value)-2)
								else c_rows.Column_Value end;
				v_Line_Array := apex_string.split(p_str => v_Row_Line, p_sep => v_Column_Delimiter);
				v_Column_Limit := LEAST(v_Line_Array.count, g_Collection_Cols_Limit);
				if v_Column_Limit < v_Column_Cnt then 
					p_Message := g_msg_separator_body || c_rows.Line_No;
					return;
				end if;
				if apex_application.g_debug then
					apex_debug.info('%s. Import_Row_Line : #%s#', c_rows.Line_No, v_Row_Line);
				end if;
				if c_rows.Line_No = 1 and p_First_Row = 'Y' then
					p_Column_Headers := substr(apex_string.join(v_Line_Array, ':'), 1, 4000);
				elsif c_rows.Line_No > 1 or p_First_Row = 'N' then
					v_Seq_ID := APEX_COLLECTION.ADD_MEMBER ( p_collection_name => p_Collection_Name );
					for c_idx IN 1..v_Column_Limit loop
						if p_Enclosed_By IS NOT NULL then 
							v_Cell_Value := REPLACE(v_Line_Array(c_idx), p_Enclosed_By||p_Enclosed_By, p_Enclosed_By);
							if SUBSTR(v_Cell_Value, 1, 1) = p_Enclosed_By
							and SUBSTR(v_Cell_Value, -1, 1) = p_Enclosed_By then
								v_Cell_Value := SUBSTR(v_Cell_Value, 2, LENGTH(v_Cell_Value)-2);
							end if;
						else 
							v_Cell_Value := v_Line_Array(c_idx);
						end if;
						APEX_COLLECTION.UPDATE_MEMBER_ATTRIBUTE (
							p_collection_name => p_Collection_Name,
							p_seq => v_Seq_ID,
							p_attr_number => c_idx,
							p_attr_value => TRIM(NVL(p_Currency_Symbol,' ') FROM v_Cell_Value)
						);
					end loop;
				end if;
			end if;
		end loop;
		commit;
		p_Rows_Cnt := v_Seq_ID;
		p_Message  := 'OK';
	end Upload_to_Apex_Collection;

	FUNCTION plugin_Upload_to_Collection (
		p_process in apex_plugin.t_process,
		p_plugin  in apex_plugin.t_plugin )
	RETURN apex_plugin.t_process_exec_result
	IS
		v_exec_result apex_plugin.t_process_exec_result;
		v_Import_From		VARCHAR2(32767);
		v_Import_From_Item	VARCHAR2(32767);
		v_Column_Delimiter	VARCHAR2(32767);
		v_File_Name			VARCHAR2(32767);
		v_File_Table_Name	APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_01%TYPE;
		v_File_Name_Item	APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_03%TYPE;
		v_Character_Set		VARCHAR2(32767);
		v_Rows_Item			APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_05%TYPE;
		v_Collection_Name	APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_06%TYPE;
		v_Rows_Cnt			PLS_INTEGER;
		v_Show_Message		APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_07%TYPE;
		v_Enclosed_By_Item	APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_08%TYPE;
		v_Enclosed_By   	VARCHAR2(32767);
		v_First_Row_Item	APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_09%TYPE;
		v_First_Row   		VARCHAR2(32767);
		v_Currency_Symbol	VARCHAR2(32767);
		v_Currency_Item		APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_10%TYPE;
		v_Column_Headers	VARCHAR2(32767);
		v_Col_Headers_Item	APEX_APPLICATION_PAGE_ITEMS.ATTRIBUTE_11%TYPE;
		v_Use_Apex_Data_Parser VARCHAR2(32767);
		v_Message			VARCHAR2(32767);
	BEGIN
		if apex_application.g_debug then
			apex_plugin_util.debug_process (
				p_plugin => p_plugin,
				p_process => p_process
			);
		end if;
		v_Import_From_Item := p_process.attribute_01;
		v_Import_From     := APEX_UTIL.GET_SESSION_STATE(v_Import_From_Item);
		v_Column_Delimiter:= APEX_UTIL.GET_SESSION_STATE(p_process.attribute_02);
		v_File_Name_Item  := p_process.attribute_03;
		v_File_Name       := APEX_UTIL.GET_SESSION_STATE(v_File_Name_Item);
		v_Character_Set   := APEX_UTIL.GET_SESSION_STATE(p_process.attribute_04);
		v_Rows_Item   	  := p_process.attribute_05;
		v_Collection_Name := p_process.attribute_06;
		v_Show_Message    := p_process.attribute_07;
		v_Enclosed_By_Item:= p_process.attribute_08;
		v_Enclosed_By     := APEX_UTIL.GET_SESSION_STATE(v_Enclosed_By_Item);
		v_First_Row_Item  := p_process.attribute_09;
		v_First_Row       := APEX_UTIL.GET_SESSION_STATE(v_First_Row_Item);
		v_Currency_Item   := p_process.attribute_10;
		v_Currency_Symbol := APEX_UTIL.GET_SESSION_STATE(v_Currency_Item);
		v_Col_Headers_Item := p_process.attribute_11;
		v_Use_Apex_Data_Parser := p_process.attribute_12;
		if v_File_Name_Item IS NOT NULL then
			-- determinate file source : WWV_FLOW_FILES or APEX_APPLICATION_TEMP_FILES
			SELECT ATTRIBUTE_01
			INTO v_File_Table_Name
			FROM APEX_APPLICATION_PAGE_ITEMS
			WHERE APPLICATION_ID 	= apex_application.g_flow_id
			AND PAGE_ID 			= apex_application.g_flow_step_id
			AND ITEM_NAME 			= v_File_Name_Item;
		end if;
		if apex_application.g_debug then
			apex_debug.info('Import_From_Item: %s', v_Import_From_Item);
			apex_debug.info('Import_From     : %s', v_Import_From);
			apex_debug.info('Column_Delimiter: %s', v_Column_Delimiter);
			apex_debug.info('Enclosed_By_Item: %s', v_Enclosed_By_Item);
			apex_debug.info('Enclosed_By     : %s', v_Enclosed_By);
			apex_debug.info('Currency_Item   : %s', v_Currency_Item);
			apex_debug.info('Currency_Symbol : %s', v_Currency_Symbol);
			apex_debug.info('First_Row_Item  : %s', v_First_Row_Item);
			apex_debug.info('First_Row       : %s', v_First_Row);
			apex_debug.info('File_Name_Item  : %s', v_File_Name_Item);
			apex_debug.info('File_Name       : %s', v_File_Name);
			apex_debug.info('File_Table_Name : %s', v_File_Table_Name);
			apex_debug.info('Character_Set   : %s', v_Character_Set);
			apex_debug.info('Rows_Item       : %s', v_Rows_Item);
			apex_debug.info('Col_Header_Item : %s', v_Col_Headers_Item);
			apex_debug.info('Collection_Name : %s', v_Collection_Name);
			apex_debug.info('Use_Data_Parser : %s', v_Use_Apex_Data_Parser);
		end if;

		upload_to_collection_plugin.Upload_to_Apex_Collection (
			p_Import_From 		=> v_Import_From,
			p_Column_Delimiter 	=> v_Column_Delimiter,
			p_Enclosed_By 	    => v_Enclosed_By,
			p_Currency_Symbol	=> v_Currency_Symbol,
			p_First_Row 	    => v_First_Row,
			p_File_Name 		=> v_File_Name,
			p_File_Table_Name 	=> v_File_Table_Name,
			p_Character_Set 	=> v_Character_Set,
			p_Collection_Name 	=> v_Collection_Name,
			p_Use_Apex_Data_Parser => v_Use_Apex_Data_Parser,
			p_Column_Headers	=> v_Column_Headers,
			p_Rows_Cnt 			=> v_Rows_Cnt,
			p_Message			=> v_Message
		);
		apex_util.set_session_state(v_Import_From_Item, v_Import_From);
		if v_Rows_Item IS NOT NULL then
			apex_util.set_session_state(v_Rows_Item, v_Rows_Cnt);
		end if;
		if v_Col_Headers_Item IS NOT NULL and v_First_Row = 'Y' then
			apex_util.set_session_state(v_Col_Headers_Item, v_Column_Headers);
		end if;
		if apex_application.g_debug then
			apex_debug.info('Rows_Count      : %s', v_Rows_Cnt);
			apex_debug.info('Error Message   : %s', v_Message);
		end if;
		v_exec_result.execution_skipped := false;
		if v_Show_Message = 'Y' then
			if v_Message = 'OK' and v_Rows_Cnt > 0 then
				v_exec_result.success_message := APEX_LANG.LANG (
					p_primary_text_string => g_msg_process_success,
					p0 => v_Rows_Cnt,
					p_primary_language => 'en'
				);
			elsif v_Message = 'OK' and v_Rows_Cnt = 0 then
				Apex_Error.Add_Error (
					p_message  => Apex_Lang.Lang(g_msg_no_data_found, p_primary_language => 'en'),
					p_display_location => apex_error.c_inline_in_notification
				);				
			elsif v_Message != 'OK' then
				Apex_Error.Add_Error (
					p_message  => Apex_Lang.Lang(v_Message, p_primary_language => 'en'),
					p_display_location => apex_error.c_inline_in_notification
				);				
			end if;
		end if;
		RETURN v_exec_result;
	END plugin_Upload_to_Collection;

	FUNCTION Access_Collection_Query(
		p_Query IN CLOB,
		p_Collection_Name IN VARCHAR2,
		p_From_View_Name IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC
	is
		v_cur INTEGER;
		v_col_cnt INTEGER;
		v_rec_tab DBMS_SQL.DESC_TAB2;
		v_result VARCHAR2(32767);
	begin
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Query, DBMS_SQL.NATIVE);
		dbms_sql.describe_columns2(v_cur, v_col_cnt, v_rec_tab);
		dbms_sql.close_cursor(v_cur);
		if v_col_cnt > 50 then 
			v_col_cnt := 50;
		end if;
		for ind in 1..v_col_cnt loop
			v_result := v_result 
			|| case when ind > 1 then ', '||chr(10)||chr(9) else 'SELECT'||chr(9) end
			|| 'C' || TO_CHAR(ind, 'FM099') 
			|| case when UPPER(v_rec_tab(ind).col_name) != 'NULL' then
				' ' || dbms_assert.enquote_name(v_rec_tab(ind).col_name, FALSE)
			end;
		end loop;
		return v_result || chr(10) 
		|| 'FROM ' || dbms_assert.enquote_name(p_From_View_Name, FALSE) || chr(10) 
		|| 'WHERE COLLECTION_NAME = ' || dbms_assert.enquote_literal(p_Collection_Name);
	end Access_Collection_Query;

	FUNCTION Create_Collection_From_Query (
		p_collection_name		IN VARCHAR2,
		p_query					IN VARCHAR2,
		p_generate_md5 			IN VARCHAR2 DEFAULT 'NO',
		p_truncate_if_exists 	IN VARCHAR2 DEFAULT 'NO',
		p_From_View_Name 		IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC
	is
	begin
		APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY (
			p_collection_name	=> p_collection_name,
			p_query				=> p_query,
			p_generate_md5		=> p_generate_md5,
			p_truncate_if_exists=> p_truncate_if_exists
		);
		return Access_Collection_Query (
			p_Query				=> p_Query,
			p_Collection_Name	=> p_Collection_Name,
			p_From_View_Name	=> p_From_View_Name
		);
	end Create_Collection_From_Query;
	
	FUNCTION Access_Collection_Query2(
		p_Query IN CLOB,
		p_Collection_Name IN VARCHAR2,
		p_From_View_Name IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC
	is
		v_cur INTEGER;
		v_col_cnt INTEGER;
		v_rec_tab DBMS_SQL.DESC_TAB2;
		v_result VARCHAR2(32767);
	begin
		v_cur := dbms_sql.open_cursor;
		dbms_sql.parse(v_cur, p_Query, DBMS_SQL.NATIVE);
		dbms_sql.describe_columns2(v_cur, v_col_cnt, v_rec_tab);
		dbms_sql.close_cursor(v_cur);
		if v_col_cnt > 60 then 
			v_col_cnt := 60;
		end if;
		for ind in 1..v_col_cnt loop
			v_result := v_result 
			|| case when ind > 1 then ', '||chr(10)||chr(9) else 'SELECT'||chr(9) end
			|| case when ind > 10 then 'C' || TO_CHAR(ind-10, 'FM099')
					when ind > 5 then 'D' || TO_CHAR(ind-5, 'FM09')
					else 'N' || TO_CHAR(ind, 'FM09') end 
			|| case when UPPER(v_rec_tab(ind).col_name) != 'NULL' then
				' ' || dbms_assert.enquote_name(v_rec_tab(ind).col_name, FALSE)
			end;
		end loop;
		return v_result || chr(10) 
		|| 'FROM ' || dbms_assert.enquote_name(p_From_View_Name, FALSE) || chr(10) 
		|| 'WHERE COLLECTION_NAME = ' || dbms_assert.enquote_literal(p_Collection_Name);
	end Access_Collection_Query2;

	FUNCTION Create_Collection_From_Query2 (
		p_collection_name		IN VARCHAR2,
		p_query					IN VARCHAR2,
		p_generate_md5 			IN VARCHAR2 DEFAULT 'NO',
		p_truncate_if_exists 	IN VARCHAR2 DEFAULT 'NO',
		p_From_View_Name 		IN VARCHAR2 DEFAULT 'APEX_COLLECTIONS'
	) RETURN VARCHAR2 DETERMINISTIC
	is
	begin
		APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY2 (
			p_collection_name	=> p_collection_name,
			p_query				=> p_query,
			p_generate_md5		=> p_generate_md5,
			p_truncate_if_exists=> p_truncate_if_exists
		);
		return Access_Collection_Query2 (
			p_Query				=> p_Query,
			p_Collection_Name	=> p_Collection_Name,
			p_From_View_Name	=> p_From_View_Name
		);
	end Create_Collection_From_Query2;
	
END upload_to_collection_plugin;
/
show errors

/*
-- usage:
SELECT Access_Apex_Collections.Access_Collection_Query('SELECT * FROM SYS.ALL_TABLES', 'ALL_TABLES') X FROM DUAL;
SELECT Access_Apex_Collections.Access_Collection_Query2(
	p_Query=>'
		SELECT OBJECT_ID,DATA_OBJECT_ID,NAMESPACE,CREATED_APPID,CREATED_VSNID,
			LAST_DDL_TIME,TIMESTAMP,NULL,NULL,NULL,
			OWNER,OBJECT_NAME,SUBOBJECT_NAME,OBJECT_TYPE,STATUS,TEMPORARY,GENERATED,SECONDARY
		FROM SYS.ALL_OBJECTS', 
	p_Collection_Name=>'ALL_OBJECTS',
	p_View_Name=>'V_APEX_COLLECTIONS'
) X FROM DUAL;


*/