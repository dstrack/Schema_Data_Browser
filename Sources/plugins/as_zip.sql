declare 
	v_use_utl_file VARCHAR2(128);
	v_stat VARCHAR2(32767);
begin
	SELECT case when COUNT(*) > 0 then 'TRUE' else 'FALSE' end INTO v_use_utl_file
    FROM ALL_OBJECTS 
    WHERE OBJECT_NAME = 'UTL_FILE'
    AND OWNER = 'SYS' 
    AND OBJECT_TYPE = 'PACKAGE';
	/* generate the package as_zip_spec to enable conditional compilation */

	v_stat := '
	CREATE OR REPLACE PACKAGE as_zip_specs AUTHID DEFINER 
	IS
		c_use_utl_file 			CONSTANT BOOLEAN	:= ' || v_use_utl_file || ';
	END as_zip_specs;
	';
	EXECUTE IMMEDIATE v_Stat;
    dbms_output.put_line(v_Stat);
	v_stat := '
	CREATE OR REPLACE PACKAGE BODY as_zip_specs
	IS
    BEGIN -- package for specifications of the available libraries in the current installation schema
        NULL;
    END as_zip_specs;
    ';
	EXECUTE IMMEDIATE v_Stat;
end;
/

CREATE OR REPLACE package as_zip
AUTHID DEFINER
is
/**********************************************
**
** Author: Anton Scheffer
** Date: 25-01-2012
** Website: http://technology.amis.nl/blog
**
** Changelog:
**   Date: 22-03-2017 by Dirk Strack
**     improve performance by using nocopy compiler hints
**     added subtype t_path_name is varchar2(32767) for Oracle 12
**     added procedure get_file_date_list to return arrays with file names, dates and offsets.
**     added variant of function get_file with parameter p_offset for fast direct access.
**   Date: 12-03-2017 by Dirk Strack
**     added parameter p_date to add1file
**     added check for file size limit to add1file and finish_zip
**   Date: 04-08-2016
**     fixed endless loop for empty/null zip file
**   Date: 28-07-2016
**     added support for defate64 (this only works for zip-files created with 7Zip)
**   Date: 31-01-2014
**     file limit increased to 4GB
**   Date: 29-04-2012
**    fixed bug for large uncompressed files, thanks Morten Braten
**   Date: 21-03-2012
**     Take CRC32, compressed length and uncompressed length from
**     Central file header instead of Local file header
**   Date: 17-02-2012
**     Added more support for non-ascii filenames
**   Date: 25-01-2012
**     Added MIT-license
**     Some minor improvements
******************************************************************************
******************************************************************************
Copyright (C) 2010,2011 by Anton Scheffer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

******************************************************************************
******************************************** */

$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
  subtype t_path_name is varchar2(32767);
$ELSE
  subtype t_path_name is clob;
$END
  type file_list is table of t_path_name;
  type date_list is table of date;
  type foffset_list is table of integer;
  g_size_limit integer := power(2, 32);
  g_size_limit_sqlcode integer := -20200;
  g_size_limit_message varchar2(200) := 'Maximum file size of 4GB exceeded';
  g_access_utl_file_sqlcode integer := -20201;
  g_access_utl_file_message varchar2(200) := 'Function is not enabled. Execute privilege on sys.utl_file to owner is required';
--
  function file2blob
    ( p_dir varchar2
    , p_file_name varchar2
    )
  return blob;
--
  function get_file_list
    ( p_dir varchar2
    , p_zip_file varchar2
    , p_encoding varchar2 := null
    )
  return file_list;
--
  function get_file_list
    ( p_zipped_blob blob
    , p_encoding varchar2 := null
    )
  return file_list;
--
  function get_file
    ( p_dir varchar2
    , p_zip_file varchar2
    , p_file_name varchar2
    , p_encoding varchar2 := null
    )
  return blob;
--
  function get_file
    ( p_zipped_blob blob
    , p_file_name varchar2
    , p_encoding varchar2 := null
    )
  return blob;
--
  procedure add1file
    ( p_zipped_blob in out nocopy blob
    , p_name varchar2
    , p_content blob
	, p_date date default sysdate
    );
--
  procedure finish_zip( p_zipped_blob in out nocopy blob );
--
  procedure save_zip
    ( p_zipped_blob blob
    , p_dir varchar2 := 'MY_DIR'
    , p_filename varchar2 := 'my.zip'
    );
--
  procedure get_file_date_list
    ( p_zipped_blob 	in blob
    , p_encoding 		in varchar2 := null
    , p_file_list		out nocopy file_list
    , p_date_list		out nocopy date_list
    , p_offset_list		out nocopy foffset_list
    );
--
  function get_file
    ( p_zipped_blob blob
    , p_file_name varchar2
    , p_offset integer
    )
  return blob;
end;
/
--
/*
declare
  g_zipped_blob blob;
begin
  as_zip.add1file( g_zipped_blob, 'test4.txt', null ); -- a empty file
  as_zip.add1file( g_zipped_blob, 'dir1/test1.txt', utl_raw.cast_to_raw( q'<A file with some more text, stored in a subfolder which isn't added>' ) );
  as_zip.add1file( g_zipped_blob, 'test1234.txt', utl_raw.cast_to_raw( 'A small file' ) );
  as_zip.add1file( g_zipped_blob, 'dir2/', null ); -- a folder
  as_zip.add1file( g_zipped_blob, 'dir3/', null ); -- a folder
  as_zip.add1file( g_zipped_blob, 'dir3/test2.txt', utl_raw.cast_to_raw( 'A small filein a previous created folder' ) );
  as_zip.finish_zip( g_zipped_blob );
  as_zip.save_zip( g_zipped_blob, 'MY_DIR', 'my.zip' );
  dbms_lob.freetemporary( g_zipped_blob );
end;
--
declare
  zip_files as_zip.file_list;
begin
  zip_files  := as_zip.get_file_list( 'MY_DIR', 'my.zip' );
  for i in zip_files.first() .. zip_files.last
  loop
    dbms_output.put_line( zip_files( i ) );
    dbms_output.put_line( utl_raw.cast_to_varchar2( as_zip.get_file( 'MY_DIR', 'my.zip', zip_files( i ) ) ) );
  end loop;
end;

declare
  g_zipped_blob blob;
  g_file_list		as_zip.file_list;
  g_date_list		as_zip.date_list;
  g_offset_list 	as_zip.foffset_list;
  g_unzipped_file blob;
begin
  as_zip.add1file( g_zipped_blob, 'test4.txt', null ); -- a empty file
  as_zip.add1file( g_zipped_blob, 'dir1/test1.txt', utl_raw.cast_to_raw( q'<A file with some more text, stored in a subfolder which isn't added>' ) );
  as_zip.add1file( g_zipped_blob, 'test1234.txt', utl_raw.cast_to_raw( 'A small file' ) );
  as_zip.add1file( g_zipped_blob, 'dir2/', null ); -- a folder
  as_zip.add1file( g_zipped_blob, 'dir3/', null ); -- a folder
  as_zip.add1file( g_zipped_blob, 'dir3/test2.txt', utl_raw.cast_to_raw( 'A small file in a previous created folder' ) );
  as_zip.finish_zip( g_zipped_blob );

  as_zip.get_file_date_list ( g_zipped_blob, null, g_file_list, g_date_list, g_offset_list);
  for i in 1 .. g_file_list.count loop
  	g_unzipped_file := as_zip.get_file (g_zipped_blob, g_file_list(i), g_offset_list(i));
    dbms_output.put_line('Pathname : ' || g_file_list(i));
    dbms_output.put_line('Date     : ' || g_date_list(i));
    dbms_output.put_line('Offset   : ' || g_offset_list(i));
    dbms_output.put_line(utl_raw.cast_to_varchar2( g_unzipped_file ));
  end loop;
  dbms_lob.freetemporary( g_zipped_blob );
end;

*/

CREATE OR REPLACE package body as_zip
is
--
  c_LOCAL_FILE_HEADER        constant raw(4) := hextoraw( '504B0304' ); -- Local file header signature
  c_END_OF_CENTRAL_DIRECTORY constant raw(4) := hextoraw( '504B0506' ); -- End of central directory signature
--
  function blob2num( p_blob blob, p_len integer, p_pos integer )
  return number
  is
    rv number;
  begin
    rv := utl_raw.cast_to_binary_integer( dbms_lob.substr( p_blob, p_len, p_pos ), utl_raw.little_endian );
    if rv < 0
    then
      rv := rv + 4294967296;
    end if;
    return rv;
  end;
--
  function raw2varchar2( p_raw raw, p_encoding varchar2 )
  return varchar2
  is
  begin
    return coalesce( utl_i18n.raw_to_char( p_raw, p_encoding )
                   , utl_i18n.raw_to_char( p_raw, utl_i18n.map_charset( p_encoding, utl_i18n.GENERIC_CONTEXT, utl_i18n.IANA_TO_ORACLE ) )
                   );
  end;
--
  function little_endian( p_big number, p_bytes pls_integer := 4 )
  return raw
  is
    t_big number := p_big;
  begin
    if t_big > 2147483647
    then
      t_big := t_big - 4294967296;
    end if;
    return utl_raw.substr( utl_raw.cast_from_binary_integer( t_big, utl_raw.little_endian ), 1, p_bytes );
  end;
--
  function file2blob
    ( p_dir varchar2
    , p_file_name varchar2
    )
  return blob
  is
    file_lob bfile;
    file_blob blob;
  begin
    file_lob := bfilename( p_dir, p_file_name );
    dbms_lob.open( file_lob, dbms_lob.file_readonly );
    dbms_lob.createtemporary( file_blob, true );
    dbms_lob.loadfromfile( file_blob, file_lob, dbms_lob.lobmaxsize );
    dbms_lob.close( file_lob );
    return file_blob;
  exception
    when others then
      if dbms_lob.isopen( file_lob ) = 1
      then
        dbms_lob.close( file_lob );
      end if;
      if dbms_lob.istemporary( file_blob ) = 1
      then
        dbms_lob.freetemporary( file_blob );
      end if;
      raise;
  end;
--
  function get_file_list
    ( p_zipped_blob blob
    , p_encoding varchar2 := null
    )
  return file_list
  is
    t_ind integer;
    t_hd_ind integer;
    t_rv file_list;
    t_encoding varchar2(32767);
  begin
    t_ind := nvl( dbms_lob.getlength( p_zipped_blob ), 0 ) - 21;
    loop
      exit when t_ind < 1 or dbms_lob.substr( p_zipped_blob, 4, t_ind ) = c_END_OF_CENTRAL_DIRECTORY;
      t_ind := t_ind - 1;
    end loop;
--
    if t_ind <= 0
    then
      return null;
    end if;
--
    t_hd_ind := blob2num( p_zipped_blob, 4, t_ind + 16 ) + 1;
    t_rv := file_list();
    t_rv.extend( blob2num( p_zipped_blob, 2, t_ind + 10 ) );
    for i in 1 .. blob2num( p_zipped_blob, 2, t_ind + 8 )
    loop
      if p_encoding is null
      then
        if utl_raw.bit_and( dbms_lob.substr( p_zipped_blob, 1, t_hd_ind + 9 ), hextoraw( '08' ) ) = hextoraw( '08' )
        then
          t_encoding := 'AL32UTF8'; -- utf8
        else
          t_encoding := 'US8PC437'; -- IBM codepage 437
        end if;
      else
        t_encoding := p_encoding;
      end if;
      t_rv( i ) := raw2varchar2
                     ( dbms_lob.substr( p_zipped_blob
                                      , blob2num( p_zipped_blob, 2, t_hd_ind + 28 )
                                      , t_hd_ind + 46
                                      )
                     , t_encoding
                     );
      t_hd_ind := t_hd_ind + 46
                + blob2num( p_zipped_blob, 2, t_hd_ind + 28 )  -- File name length
                + blob2num( p_zipped_blob, 2, t_hd_ind + 30 )  -- Extra field length
                + blob2num( p_zipped_blob, 2, t_hd_ind + 32 ); -- File comment length
    end loop;
--
    return t_rv;
  end;
--
  function get_file_list
    ( p_dir varchar2
    , p_zip_file varchar2
    , p_encoding varchar2 := null
    )
  return file_list
  is
  begin
    return get_file_list( file2blob( p_dir, p_zip_file ), p_encoding );
  end;
--
  function get_file
    ( p_zipped_blob blob
    , p_file_name varchar2
    , p_encoding varchar2 := null
    )
  return blob
  is
    t_tmp blob;
    t_ind integer;
    t_hd_ind integer;
    t_fl_ind integer;
    t_encoding varchar2(32767);
    t_len integer;
  begin
    t_ind := nvl( dbms_lob.getlength( p_zipped_blob ), 0 ) - 21;
    loop
      exit when t_ind < 1 or dbms_lob.substr( p_zipped_blob, 4, t_ind ) = c_END_OF_CENTRAL_DIRECTORY;
      t_ind := t_ind - 1;
    end loop;
--
    if t_ind <= 0
    then
      return null;
    end if;
--
    t_hd_ind := blob2num( p_zipped_blob, 4, t_ind + 16 ) + 1;
    for i in 1 .. blob2num( p_zipped_blob, 2, t_ind + 8 )
    loop
      if p_encoding is null
      then
        if utl_raw.bit_and( dbms_lob.substr( p_zipped_blob, 1, t_hd_ind + 9 ), hextoraw( '08' ) ) = hextoraw( '08' )
        then
          t_encoding := 'AL32UTF8'; -- utf8
        else
          t_encoding := 'US8PC437'; -- IBM codepage 437
        end if;
      else
        t_encoding := p_encoding;
      end if;
      if p_file_name = raw2varchar2
                         ( dbms_lob.substr( p_zipped_blob
                                          , blob2num( p_zipped_blob, 2, t_hd_ind + 28 )
                                          , t_hd_ind + 46
                                          )
                         , t_encoding
                         )
      then
        t_len := blob2num( p_zipped_blob, 4, t_hd_ind + 24 ); -- uncompressed length
        if t_len = 0
        then
          if substr( p_file_name, -1 ) in ( '/', '\' )
          then  -- directory/folder
            return null;
          else -- empty file
            return empty_blob();
          end if;
        end if;
--
        if dbms_lob.substr( p_zipped_blob, 2, t_hd_ind + 10 ) in ( hextoraw( '0800' ) -- deflate
                                                                 , hextoraw( '0900' ) -- deflate64
                                                                 )
        then
          t_fl_ind := blob2num( p_zipped_blob, 4, t_hd_ind + 42 );
          t_tmp := hextoraw( '1F8B0800000000000003' ); -- gzip header
          dbms_lob.copy( t_tmp
                       , p_zipped_blob
                       ,  blob2num( p_zipped_blob, 4, t_hd_ind + 20 )
                       , 11
                       , t_fl_ind + 31
                       + blob2num( p_zipped_blob, 2, t_fl_ind + 27 ) -- File name length
                       + blob2num( p_zipped_blob, 2, t_fl_ind + 29 ) -- Extra field length
                       );
          dbms_lob.append( t_tmp, utl_raw.concat( dbms_lob.substr( p_zipped_blob, 4, t_hd_ind + 16 ) -- CRC32
                                                , little_endian( t_len ) -- uncompressed length
                                                )
                         );
          return utl_compress.lz_uncompress( t_tmp );
        end if;
--
        if dbms_lob.substr( p_zipped_blob, 2, t_hd_ind + 10 ) = hextoraw( '0000' ) -- The file is stored (no compression)
        then
          t_fl_ind := blob2num( p_zipped_blob, 4, t_hd_ind + 42 );
          dbms_lob.createtemporary( t_tmp, true );
          dbms_lob.copy( t_tmp
                       , p_zipped_blob
                       , t_len
                       , 1
                       , t_fl_ind + 31
                       + blob2num( p_zipped_blob, 2, t_fl_ind + 27 ) -- File name length
                       + blob2num( p_zipped_blob, 2, t_fl_ind + 29 ) -- Extra field length
                       );
          return t_tmp;
        end if;
      end if;
      t_hd_ind := t_hd_ind + 46
                + blob2num( p_zipped_blob, 2, t_hd_ind + 28 )  -- File name length
                + blob2num( p_zipped_blob, 2, t_hd_ind + 30 )  -- Extra field length
                + blob2num( p_zipped_blob, 2, t_hd_ind + 32 ); -- File comment length
    end loop;
--
    return null;
  end;
--
  function get_file
    ( p_dir varchar2
    , p_zip_file varchar2
    , p_file_name varchar2
    , p_encoding varchar2 := null
    )
  return blob
  is
  begin
    return get_file( file2blob( p_dir, p_zip_file ), p_file_name, p_encoding );
  end;
--
  procedure add1file
    ( p_zipped_blob in out nocopy blob
    , p_name varchar2
    , p_content blob
	, p_date date default sysdate
    )
  is
    t_now timestamp with time zone;
    t_blob blob;
    t_len integer;
    t_clen integer;
    t_crc32 raw(4) := hextoraw( '00000000' );
    t_compressed boolean := false;
    t_name raw(32767);
  begin
    t_now := cast(nvl(p_date, sysdate) as timestamp with local time zone) at time zone 'UTC';
    t_len := nvl( dbms_lob.getlength( p_content ), 0 );
    if t_len > 0
    then
      t_blob := utl_compress.lz_compress( p_content );
      t_clen := dbms_lob.getlength( t_blob ) - 18;
      t_compressed := t_clen < t_len;
      t_crc32 := dbms_lob.substr( t_blob, 4, t_clen + 11 );
    end if;
    if not t_compressed
    then
      t_clen := t_len;
      t_blob := p_content;
    end if;
    if p_zipped_blob is null
    then
      dbms_lob.createtemporary( p_zipped_blob, true );
    end if;
    t_name := utl_i18n.string_to_raw( compose(p_name), 'AL32UTF8' );
    dbms_lob.append( p_zipped_blob
                   , utl_raw.concat( c_LOCAL_FILE_HEADER -- Local file header signature
                                   , hextoraw( '1400' )  -- version 2.0
                                   , case when t_name = utl_i18n.string_to_raw( p_name, 'US8PC437' )
                                       then hextoraw( '0000' ) -- no General purpose bits
                                       else hextoraw( '0008' ) -- set Language encoding flag (EFS)
                                     end
                                   , case when t_compressed
                                        then hextoraw( '0800' ) -- deflate
                                        else hextoraw( '0000' ) -- stored
                                     end
                                   , little_endian( to_number( to_char( t_now, 'ss' ) ) / 2
                                                  + to_number( to_char( t_now, 'mi' ) ) * 32
                                                  + to_number( to_char( t_now, 'hh24' ) ) * 2048
                                                  , 2
                                                  ) -- File last modification time
                                   , little_endian( to_number( to_char( t_now, 'dd' ) )
                                                  + to_number( to_char( t_now, 'mm' ) ) * 32
                                                  + ( greatest(to_number( to_char( t_now, 'yyyy' ) ) - 1980, 0) ) * 512
                                                  , 2
                                                  ) -- File last modification date
                                   , t_crc32 -- CRC-32
                                   , little_endian( t_clen )                      -- compressed size
                                   , little_endian( t_len )                       -- uncompressed size
                                   , little_endian( utl_raw.length( t_name ), 2 ) -- File name length
                                   , hextoraw( '0000' )                           -- Extra field length
                                   , t_name                                       -- File name
                                   )
                   );
    if t_compressed
    then
      dbms_lob.copy( p_zipped_blob, t_blob, t_clen, dbms_lob.getlength( p_zipped_blob ) + 1, 11 ); -- compressed content
    elsif t_clen > 0
    then
      dbms_lob.copy( p_zipped_blob, t_blob, t_clen, dbms_lob.getlength( p_zipped_blob ) + 1, 1 ); --  content
    end if;
    if dbms_lob.istemporary( t_blob ) = 1
    then
      dbms_lob.freetemporary( t_blob );
    end if;
    if g_size_limit < dbms_lob.getlength( p_zipped_blob ) then
    	raise_application_error (g_size_limit_sqlcode, g_size_limit_message || ' in as_zip.add1file');
    end if;
  end;
--
  procedure finish_zip( p_zipped_blob in out nocopy blob )
  is
    t_cnt pls_integer := 0;
    t_offs integer;
    t_offs_dir_header integer;
    t_offs_end_header integer;
    t_comment raw(32767) := utl_raw.cast_to_raw( 'Implementation by Anton Scheffer, improved by Dirk Strack' );
  begin
    t_offs_dir_header := dbms_lob.getlength( p_zipped_blob );
    t_offs := 1;
    while dbms_lob.substr( p_zipped_blob, utl_raw.length( c_LOCAL_FILE_HEADER ), t_offs ) = c_LOCAL_FILE_HEADER
    loop
      t_cnt := t_cnt + 1;
      dbms_lob.append( p_zipped_blob
                     , utl_raw.concat( hextoraw( '504B0102' )      -- Central directory file header signature
                                     , hextoraw( '1400' )          -- version 2.0
                                     , dbms_lob.substr( p_zipped_blob, 26, t_offs + 4 )
                                     , hextoraw( '0000' )          -- File comment length
                                     , hextoraw( '0000' )          -- Disk number where file starts
                                     , hextoraw( '0000' )          -- Internal file attributes =>
                                                                   --     0000 binary file
                                                                   --     0100 (ascii)text file
                                     , case
                                         when dbms_lob.substr( p_zipped_blob
                                                             , 1
                                                             , t_offs + 30 + blob2num( p_zipped_blob, 2, t_offs + 26 ) - 1
                                                             ) in ( hextoraw( '2F' ) -- /
                                                                  , hextoraw( '5C' ) -- \
                                                                  )
                                         then hextoraw( '10000000' ) -- a directory/folder
                                         else hextoraw( '2000B681' ) -- a file
                                       end                         -- External file attributes
                                     , little_endian( t_offs - 1 ) -- Relative offset of local file header
                                     , dbms_lob.substr( p_zipped_blob
                                                      , blob2num( p_zipped_blob, 2, t_offs + 26 )
                                                      , t_offs + 30
                                                      )            -- File name
                                     )
                     );
      t_offs := t_offs + 30 + blob2num( p_zipped_blob, 4, t_offs + 18 )  -- compressed size
                            + blob2num( p_zipped_blob, 2, t_offs + 26 )  -- File name length
                            + blob2num( p_zipped_blob, 2, t_offs + 28 ); -- Extra field length
    end loop;
    t_offs_end_header := dbms_lob.getlength( p_zipped_blob );
    dbms_lob.append( p_zipped_blob
                   , utl_raw.concat( c_END_OF_CENTRAL_DIRECTORY                                -- End of central directory signature
                                   , hextoraw( '0000' )                                        -- Number of this disk
                                   , hextoraw( '0000' )                                        -- Disk where central directory starts
                                   , little_endian( t_cnt, 2 )                                 -- Number of central directory records on this disk
                                   , little_endian( t_cnt, 2 )                                 -- Total number of central directory records
                                   , little_endian( t_offs_end_header - t_offs_dir_header )    -- Size of central directory
                                   , little_endian( t_offs_dir_header )                        -- Offset of start of central directory, relative to start of archive
                                   , little_endian( nvl( utl_raw.length( t_comment ), 0 ), 2 ) -- ZIP file comment length
                                   , t_comment
                                   )
                   );
    if g_size_limit < dbms_lob.getlength( p_zipped_blob ) then
    	raise_application_error (g_size_limit_sqlcode, g_size_limit_message || ' in as_zip.finish_zip');
    end if;
  end;
--
$IF as_zip_specs.c_use_utl_file $THEN
  procedure save_zip
    ( p_zipped_blob blob
    , p_dir varchar2 := 'MY_DIR'
    , p_filename varchar2 := 'my.zip'
    )
  is
    t_fh utl_file.file_type;
    t_len pls_integer := 32767;
  begin
    t_fh := utl_file.fopen( p_dir, p_filename, 'wb' );
    for i in 0 .. trunc( ( dbms_lob.getlength( p_zipped_blob ) - 1 ) / t_len )
    loop
      utl_file.put_raw( t_fh, dbms_lob.substr( p_zipped_blob, t_len, i * t_len + 1 ) );
    end loop;
    utl_file.fclose( t_fh );
  end;
$ELSE
  procedure save_zip
    ( p_zipped_blob blob
    , p_dir varchar2 := 'MY_DIR'
    , p_filename varchar2 := 'my.zip'
    )
  is
  begin
	raise_application_error (g_access_utl_file_sqlcode, g_access_utl_file_message || ' in as_zip.save_zip');
  end;
$END
--
  procedure get_file_date_list
    ( p_zipped_blob 	in blob
    , p_encoding 		in varchar2 := null
    , p_file_list		out nocopy file_list
    , p_date_list		out nocopy date_list
    , p_offset_list		out nocopy foffset_list
    )
  is
    t_ind 		integer := 0;
    t_hd_ind 	integer := 0;
    t_file_list file_list;
    t_date_list date_list;
    t_offset_list foffset_list;
    t_encoding 	varchar2(255);
    t_size		integer := 0;
    t_total 	integer := 0;
    t_date_num 	integer := 0;
    t_time_num 	integer := 0;
    t_date_str	varchar2(50);
  begin
    t_ind := nvl( dbms_lob.getlength( p_zipped_blob ), 0 ) - 21;
    loop
      exit when t_ind < 1 or dbms_lob.substr( p_zipped_blob, 4, t_ind ) = c_END_OF_CENTRAL_DIRECTORY;
      t_ind := t_ind - 1;
    end loop;
--
    if t_ind <= 0
    then
      return;
    end if;
--
    t_hd_ind := blob2num( p_zipped_blob, 4, t_ind + 16 ) + 1;
    t_file_list := file_list();
    t_date_list := date_list();
    t_offset_list := foffset_list();

    t_size := blob2num( p_zipped_blob, 2, t_ind + 10 );
    t_file_list.extend( t_size );
    t_date_list.extend( t_size );
    t_offset_list.extend( t_size );
    -- total number of entries in the central directory
    t_total := blob2num( p_zipped_blob, 2, t_ind + 8 );
    for i in 1 .. t_total
    loop
      if p_encoding is null
      then
        if utl_raw.bit_and( dbms_lob.substr( p_zipped_blob, 1, t_hd_ind + 9 ), hextoraw( '08' ) ) = hextoraw( '08' )
        then
          t_encoding := 'AL32UTF8'; -- utf8
        else
          t_encoding := 'US8PC437'; -- IBM codepage 437
        end if;
      else
        t_encoding := p_encoding;
      end if;
      t_time_num := blob2num( p_zipped_blob, 2, t_hd_ind + 12 );
      t_date_num := blob2num( p_zipped_blob, 2, t_hd_ind + 14 );
      t_date_str := trunc(t_date_num / 512) + 1980 || '/'	-- year
      			|| trunc(mod(t_date_num, 512) / 32) || '/'	-- month
      			|| mod(t_date_num, 32)	|| ' '				-- day
      			|| trunc(t_time_num / 2048) || '.'			-- hour24
      			|| trunc(mod(t_time_num, 2048) / 32) || '.'	-- minutes
      			|| mod(t_time_num, 32) * 2;					-- seconds
      t_file_list( i ) := raw2varchar2	-- path name
                     ( dbms_lob.substr( p_zipped_blob
                                      , blob2num( p_zipped_blob, 2, t_hd_ind + 28 )
                                      , t_hd_ind + 46
                                      )
                     , t_encoding
                     );
      t_date_list( i ) :=  to_date(t_date_str, 'YYYY/MM/DD HH24.MI.SS');
      t_offset_list( i ) := t_hd_ind;

      t_hd_ind := t_hd_ind + 46
                + blob2num( p_zipped_blob, 2, t_hd_ind + 28 )  -- File name length
                + blob2num( p_zipped_blob, 2, t_hd_ind + 30 )  -- Extra field length
                + blob2num( p_zipped_blob, 2, t_hd_ind + 32 ); -- File comment length
    end loop;
--
    p_file_list := t_file_list;
    p_date_list := t_date_list;
    p_offset_list := t_offset_list;
  end;

--
  function get_file
    ( p_zipped_blob blob
    , p_file_name varchar2
    , p_offset integer
    )
  return blob
  is
    t_tmp 		blob;
    t_hd_ind 	integer := p_offset;
    t_fl_ind 	integer;
    t_len 		integer;
  begin
	t_len := blob2num( p_zipped_blob, 4, t_hd_ind + 24 ); -- uncompressed length
	if t_len = 0
	then
	  if substr( p_file_name, -1 ) in ( '/', '\' )
	  then  -- directory/folder
		return null;
	  else -- empty file
		return empty_blob();
	  end if;
	end if;
--
	if dbms_lob.substr( p_zipped_blob, 2, t_hd_ind + 10 ) = hextoraw( '0800' ) -- deflate
	then
	  t_fl_ind := blob2num( p_zipped_blob, 4, t_hd_ind + 42 );
	  t_tmp := hextoraw( '1F8B0800000000000003' ); -- gzip header
	  dbms_lob.copy( t_tmp
				   , p_zipped_blob
				   ,  blob2num( p_zipped_blob, 4, t_hd_ind + 20 )
				   , 11
				   , t_fl_ind + 31
				   + blob2num( p_zipped_blob, 2, t_fl_ind + 27 ) -- File name length
				   + blob2num( p_zipped_blob, 2, t_fl_ind + 29 ) -- Extra field length
				   );
	  dbms_lob.append( t_tmp, utl_raw.concat( dbms_lob.substr( p_zipped_blob, 4, t_hd_ind + 16 ) -- CRC32
											, little_endian( t_len ) -- uncompressed length
											)
					 );
	  return utl_compress.lz_uncompress( t_tmp );
	end if;
--
	if dbms_lob.substr( p_zipped_blob, 2, t_hd_ind + 10 ) = hextoraw( '0000' ) -- The file is stored (no compression)
	then
	  t_fl_ind := blob2num( p_zipped_blob, 4, t_hd_ind + 42 );
	  dbms_lob.createtemporary( t_tmp, true );
	  dbms_lob.copy( t_tmp
				   , p_zipped_blob
				   , t_len
				   , 1
				   , t_fl_ind + 31
				   + blob2num( p_zipped_blob, 2, t_fl_ind + 27 ) -- File name length
				   + blob2num( p_zipped_blob, 2, t_fl_ind + 29 ) -- Extra field length
				   );
	  return t_tmp;
	end if;
--
    return null;
  end;
--
end;
/
show errors
