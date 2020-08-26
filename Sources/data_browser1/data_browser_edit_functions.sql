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
 
CREATE or REPLACE
FUNCTION FN_Get_Apex_Item_Value (              -- item value in apex_application.g_fXX array
	p_Idx           PLS_INTEGER,            -- index for apex_application.g_fxx in range 01 to 50
	p_Row_Number    PLS_INTEGER,            -- row number to be converted
	p_Row_Factor    PLS_INTEGER DEFAULT 1,  -- row factor for folding form into limited array
	p_Row_Offset    PLS_INTEGER DEFAULT 1   -- row offset for item index > 50
) RETURN VARCHAR2
is
	PRAGMA UDF;
	v_Array_Offset  CONSTANT PLS_INTEGER := p_Row_Factor * (p_Row_Number - 1) + p_Row_Offset;
	v_Statement     CONSTANT VARCHAR2(256) :=  'begin :b := ' || 'apex_application.g_f' || LPAD( p_Idx, 2, '0') || ' (' || v_Array_Offset || '); end;';
	v_Result        VARCHAR2(4000);
begin
	EXECUTE IMMEDIATE v_Statement USING OUT v_Result;
	return v_Result;
exception
WHEN VALUE_ERROR THEN
    return NULL;
when others then
	if apex_application.g_debug then
		apex_debug.info(
			p_message => 'FN_Get_Apex_Item_Value (%s, %s, %s, %s) : %s : not found : %s',
			p0 => p_Idx,
			p1 => p_Row_Number,
			p2 => p_Row_Factor,
			p3 => p_Row_Offset,
			p4 => v_Statement,
			p5 => SQLERRM,
			p_max_length => 3500
		);
	end if;
	raise;
end FN_Get_Apex_Item_Value;
/
show errors

CREATE or REPLACE
FUNCTION FN_Get_Apex_Item_Date_Value (              -- item value in apex_application.g_fXX array
	p_Idx           PLS_INTEGER,            -- index for apex_application.g_fxx in range 01 to 50
	p_Row_Number    PLS_INTEGER,            -- row number to be converted
	p_Row_Factor    PLS_INTEGER DEFAULT 1,  -- row factor for folding form into limited array
	p_Row_Offset    PLS_INTEGER DEFAULT 1,   -- row offset for item index > 50
	p_Format_Mask	VARCHAR2
) RETURN DATE
is
	PRAGMA UDF;
	v_Array_Offset  CONSTANT PLS_INTEGER := p_Row_Factor * (p_Row_Number - 1) + p_Row_Offset;
	v_Statement     VARCHAR2(512);
	v_Column_Value 	VARCHAR2(512);
	v_Result        DATE;
begin
	v_Column_Value := 'apex_application.g_f' || LPAD( p_Idx, 2, '0') || ' (' || v_Array_Offset || ')';
	v_Statement := 'begin :b := TO_DATE(' || v_Column_Value || ', ' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Format_Mask) || '); end;';
	EXECUTE IMMEDIATE v_Statement USING OUT v_Result;
	return v_Result;
exception
when others then
	return NULL;
end FN_Get_Apex_Item_Date_Value;
/
show errors

CREATE or REPLACE
FUNCTION FN_Get_Apex_Item_Row_Count (	-- item count in apex_application.g_fXX array
	p_Idx 			NUMBER,		-- index for apex_application.g_fxx in range 01 to 50
	p_Row_Factor	NUMBER,		-- row factor for folding form into limited array
	p_Row_Offset	NUMBER		-- row offset for item index > 50
) RETURN NUMBER
is
	PRAGMA UDF;
	v_Statement		VARCHAR2(200);
	v_Array_Count	NUMBER;
	v_Row_Count		NUMBER;
begin
	v_Statement :=
	   'begin :b := apex_application.g_f' || LPAD( p_Idx, 2, '0') ||'.count; end;';
	EXECUTE IMMEDIATE v_Statement USING OUT v_Array_Count;

	v_Row_Count := floor((v_Array_Count + p_Row_Factor - p_Row_Offset) / p_Row_Factor);

	return v_Row_Count;
end FN_Get_Apex_Item_Row_Count;
/
show errors

CREATE or REPLACE
FUNCTION FN_TO_DATE (
	p_Date_String VARCHAR2,
	p_Format_Mask	VARCHAR2 DEFAULT NULL
) RETURN DATE DETERMINISTIC
is
	PRAGMA UDF;
begin
	if p_Date_String IS NULL then 
		RETURN NULL;
	elsif p_Format_Mask IS NULL then 
		RETURN TO_DATE(p_Date_String);
	else 
		return TO_DATE(p_Date_String, p_Format_Mask);
	end if;
end FN_TO_DATE;
/
show errors

CREATE or REPLACE
FUNCTION FN_TO_NUMBER  (
	p_Value VARCHAR2, 
	p_Format VARCHAR2 DEFAULT NULL, 
	p_nlsparam VARCHAR2 DEFAULT data_browser_conf.Get_Export_NLS_Param
) RETURN NUMBER DETERMINISTIC -- return a number from a formated string
IS
BEGIN
	if p_Format IS NULL then 
		RETURN TO_NUMBER(p_Value);
	else
		RETURN TO_NUMBER(p_Value, p_Format, p_nlsparam);
	end if;
EXCEPTION WHEN VALUE_ERROR THEN
	RETURN data_browser_conf.Get_Export_Number (p_Value);
END FN_TO_NUMBER;
/
show errors

CREATE or REPLACE
FUNCTION FN_NUMBER_TO_CHAR (
	p_Number NUMBER
) RETURN VARCHAR2 -- return a formated number with grouping chars and optional decimal char and faction part
is
	PRAGMA UDF;
	v_Result VARCHAR2(64);
begin
	v_Result := RTRIM(REGEXP_SUBSTR(
		TO_CHAR(p_Number, 'FM999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999', data_browser_conf.Get_Export_NLS_Param)
		, data_browser_conf.Get_Number_Pattern, 1, 1, 'c', 1) -- remove leading blanks and trailing 0
		, data_browser_conf.Get_Number_Decimal_Character); -- remove trailing Decimal Character
	return v_Result;
end FN_NUMBER_TO_CHAR;
/
show errors

/*
exec data_browser_conf.Set_Export_NumChars(p_Decimal_Character=>'.', p_Group_Separator=>',');

select data_browser_conf.Get_Export_NLS_Param NLS_Param, 
    numbers_utl.Get_Number_Mask('1,400.0') Number_Mask,
    FN_TO_NUMBER('1,400.0', '9G999D9' ) Number_Val
from dual;
*/