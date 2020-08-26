/*
Copyright 2020 Dirk Strack, Strack Software Development

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


CREATE OR REPLACE
FUNCTION FN_Navigation_Link (
	p_Target	 		VARCHAR2,
	p_Label				VARCHAR2,
	p_Detail_Page_ID	INTEGER,
	p_Request			VARCHAR2 DEFAULT NULL
) RETURN VARCHAR2
IS
	PRAGMA UDF;
	v_TargetPar VARCHAR2(1000);
BEGIN
	v_TargetPar := 'f?p='||V('APP_ID')||':'
		|| p_Detail_Page_ID||':'
		|| V('APP_SESSION')
		|| ':'
		|| p_Request
		|| ':' || V('DEBUG')
		|| ':RP,'||p_Detail_Page_ID||':';

	return '<a href="'
		|| apex_util.prepare_url( v_TargetPar || p_Target)
		|| case when p_Request = 'DETAIL_VIEWS' then
			'">( ' || p_Label || ' )</a>'
		else
			'">' || p_Label || '</a>'
		end ;
END FN_Navigation_Link;
/

CREATE OR REPLACE
FUNCTION FN_Navigation_Counter (
	p_Count				INTEGER,
	p_Target	 		VARCHAR2,
	p_Page_ID			INTEGER,
	p_Is_Total NUMBER DEFAULT 0,
	p_Is_Subtotal NUMBER DEFAULT 0
) RETURN VARCHAR2
IS
	PRAGMA UDF;
	v_TargetPar VARCHAR2(1000);
	v_Label VARCHAR2(1000);
BEGIN
	v_Label := LTRIM(TO_CHAR(p_Count, '999G999G999G999G999G999G999G999G999G999G999G999G990', data_browser_conf.Get_Export_NumChars(p_Enquote=>'NO')));
	if p_Is_Total != 0 then 
		return '<span style="font-weight: bold; font-size: larger;">' || v_Label || '</span>';
	elsif p_Is_Subtotal != 0 then 
		return '<span style="font-weight: bold;">' || v_Label || '</span>';
	else
		v_TargetPar := 'f?p='||V('APP_ID')||':'
			|| p_Page_ID||':'
			|| V('APP_SESSION')
			|| ':DETAIL_VIEWS:' || V('DEBUG')
			|| ':RP,'||p_Page_ID||':';

		return '<a href="'
			|| apex_util.prepare_url( v_TargetPar || p_Target)
			|| '">( ' || v_Label || ' )</a>';
	end if;
END FN_Navigation_Counter;
/

CREATE OR REPLACE
FUNCTION FN_Nested_Link (
	p_Count			INTEGER,
	p_Attributes 	VARCHAR2,	-- SQL Expression
	p_Is_Total NUMBER DEFAULT 0,
	p_Is_Subtotal NUMBER DEFAULT 0
) RETURN VARCHAR2
IS
	PRAGMA UDF;
	v_TargetPar CONSTANT VARCHAR2(128) := '"javascript:void(0);"';
	v_Label VARCHAR2(1000);
BEGIN
	v_Label := LTRIM(TO_CHAR(p_Count, '999G999G999G999G999G999G999G999G999G999G999G999G990', data_browser_conf.Get_Export_NumChars(p_Enquote=>'NO')));
	if p_Is_Total != 0 then 
		return '<span style="font-weight: bold; font-size: larger;">' || v_Label || '</span>';
	elsif p_Is_Subtotal != 0 then 
		return '<span style="font-weight: bold;">' || v_Label || '</span>';
	else
		return
			'<a href='|| v_TargetPar || ' ' || p_Attributes
			|| '>( ' || v_Label || ' )</a>'
			;
	end if;
END FN_Nested_Link;
/

CREATE OR REPLACE
FUNCTION FN_Navigation_More (
	p_Target	 VARCHAR2,
	p_Link_Page_ID	INTEGER
) RETURN VARCHAR2
IS
	PRAGMA UDF;
	v_TargetPar VARCHAR2(128);
BEGIN
	v_TargetPar := 'f?p='||V('APP_ID')||':'
		|| p_Link_Page_ID||':'
		|| V('APP_SESSION')
		|| ':DETAIL_VIEWS:' || V('DEBUG')
		|| ':RP,'||p_Link_Page_ID||':';

	return '<a href="'
		|| apex_util.prepare_url( v_TargetPar || p_Target)
		|| '">'
		|| apex_lang.lang('more')
		|| chr(38)||'hellip;</a>';
END FN_Navigation_More;
/

CREATE OR REPLACE
FUNCTION FN_Detail_Link (
	p_Table_name VARCHAR2,
	p_Parent_Table VARCHAR2 DEFAULT NULL,			-- Parent View or Table name.
	p_Link_Page_ID NUMBER,	-- Page ID of target links
	p_Link_Items VARCHAR2, -- Item names for TABLE_NAME,PARENT_TABLE,ID
	p_Edit_Enabled VARCHAR2 DEFAULT 'NO',
	p_Key_Value VARCHAR2,
	p_Parent_Value VARCHAR2 DEFAULT NULL,
	p_Is_Total NUMBER DEFAULT 0,
	p_Is_Subtotal NUMBER DEFAULT 0
)
return VARCHAR2 
is 
	PRAGMA UDF;
	v_Link_URL VARCHAR2(2000);
	v_Link_Icon VARCHAR2(2000);
begin 
	if p_Is_Total != 0 then 
		return '<span style="font-weight: bold; font-size: larger;">' || apex_lang.lang('Report Total') || '</span>';
	elsif p_Is_Subtotal != 0 then 
		return '<span style="font-weight: bold;">' || apex_lang.lang('Total') || '</span>';
	elsif p_Key_Value IS NOT NULL and not APEX_APPLICATION.G_PRINTER_FRIENDLY then 
		v_Link_URL := apex_util.prepare_url('f?p='|| V('APP_ID') ||':' || p_Link_Page_ID || ':' || V('APP_SESSION') || '::' || V('DEBUG')
		   || ':RP,' || p_Link_Page_ID || ':'
		   || p_Link_Items || ':'
		   || p_Table_name || ','
		   || p_Parent_Table || ','
		   || p_Key_Value || ','
		   || p_Parent_Value
		);
		if p_Edit_Enabled = 'YES' then 
			v_Link_Icon := '<img src="' || V('IMAGE_PREFIX') || 'app_ui/img/icons/apex-edit-page.png" class="apex-edit-page" alt="edit">';
		else 
			v_Link_Icon := '<img src="' || V('IMAGE_PREFIX') || 'app_ui/img/icons/apex-edit-view.png" class="apex-edit-view" alt="view">';
		end if;
		return '<a href="' || v_Link_URL || '">' || v_Link_Icon || '</a>';
	else 
		return ' ';
	end if;
end FN_Detail_Link;
/

CREATE OR REPLACE
FUNCTION FN_Bold_Total (
	p_Value VARCHAR2,
	p_Is_Total NUMBER DEFAULT 0,
	p_Is_Subtotal NUMBER DEFAULT 0
)
return VARCHAR2 
is 
	PRAGMA UDF;
	v_Link_URL VARCHAR2(2000);
	v_Link_Icon VARCHAR2(2000);
begin 
	if p_Is_Total != 0 then 
		return '<span style="font-weight: bold; font-size: larger;">' || p_Value || '</span>';
	elsif p_Is_Subtotal != 0 then 
		return '<span style="font-weight: bold;">' || p_Value || '</span>';
	else
		return p_Value;
	end if;
end FN_Bold_Total;
/


-- produce a unique fingerprint of the provided values as a hex string
CREATE OR REPLACE
FUNCTION FN_Hex_Hash_Key (
	p_Value1	VARCHAR2,
	p_Value2	VARCHAR2 DEFAULT NULL,
	p_Value3	VARCHAR2 DEFAULT NULL,
	p_Value4	VARCHAR2 DEFAULT NULL,
	p_Value5	VARCHAR2 DEFAULT NULL,
	p_Value6	VARCHAR2 DEFAULT NULL,
	p_Value7	VARCHAR2 DEFAULT NULL,
	p_Value8	VARCHAR2 DEFAULT NULL,
	p_Value9	VARCHAR2 DEFAULT NULL
) RETURN VARCHAR2 DETERMINISTIC
IS
	PRAGMA UDF;
	v_Value 	CLOB;
BEGIN
$IF data_browser_specs.g_use_dbms_crypt $THEN
	v_Value := p_Value1 || ':' || p_Value2 || ':' || p_Value3 || ':' || p_Value4 || ':' ||
						p_Value5 || ':' || p_Value6 || ':' || p_Value7 || ':' || p_Value8 || ':' || p_Value9;
	return RAWTOHEX(DBMS_CRYPTO.HASH(v_Value,2));	-- 32 BYTES
$ELSE
	return apex_util.get_hash(p_values => apex_t_varchar2 ( p_Value1, p_Value2, p_Value3, p_Value4, p_Value5, p_Value6, p_Value7, p_Value8, p_Value9 ), p_salted => false);
$END

END FN_Hex_Hash_Key;
/


