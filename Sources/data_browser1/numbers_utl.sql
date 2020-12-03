/*
Copyright 2017-2020 Dirk Strack

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

/*
Package Numbers_Utl for simple, flexible and functional number conversions and validation.

In an international APEX app, the NLS settings influence the behavior of TO_NUMBER and TO_CHAR calls
and can cause conversion errors.
When the app passes floating-point numbers via (hidden) APEX Items to and from javascript functions
or to web-services, the decimal and grouping characters are constants! 
These constants have to be passed to the function to_char and to_number as the second parameter (nlsparam).
That can be problematic, 
1. because the precision and scale have to be fixed when formats with the grouping characters are needed.
Since there is no combination of the FM9 mask with the G, I had to find a more flexible solution for number conversions.
2. javascript floating-point numbers can be surprisingly long before or after the decimal point.

I found a simple method that forms a fitting format mask on the fly.
The TRANSLATE function call maps the digits and signs to 9 and removes blank and currency characters
The REGEXP_REPLACE function call detects the exponent part and prepares the format string.

I explored and expanded the method into the package numbers_utl

https://livesql.oracle.com/apex/livesql/s/jtvyckdjqlphd0ll7tn2ifcv9
*/

CREATE OR REPLACE PACKAGE numbers_utl
AUTHID DEFINER 
IS
    g_Default_Data_Precision    CONSTANT PLS_INTEGER := 38;     -- Default Data Precision for number columns with unknown precision
    g_Default_Data_Scale        CONSTANT PLS_INTEGER := 16;     -- Default Data Scale for number columns with unknown scale
    g_Default_Currency_Precision CONSTANT PLS_INTEGER := 16;    -- Default Data Precision for Currency columns with unknown precision
    g_Default_Currency_Scale    CONSTANT PLS_INTEGER := 2;      -- Default Data Scale for Currency columns with unknown scale
    g_Format_Max_Length         CONSTANT PLS_INTEGER := 63;     -- maximal length of a format mask 

    FUNCTION Get_NLS_NumChars RETURN VARCHAR2;

    -- produce a format mask for the given p_Data_Precision and p_Data_Scale
    FUNCTION Get_Number_Format_Mask (
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'Y',
        p_Export VARCHAR2 DEFAULT 'Y',      -- use TM9
        p_Use_Trim VARCHAR2 DEFAULT 'N'     -- use FM
    )
    RETURN VARCHAR2 DETERMINISTIC;

    -- produce a format mask for p_Value string using p_NumChars, p_Currency
    FUNCTION Get_Number_Mask (
        p_Value VARCHAR2,                   -- string with formated number
        p_NumChars VARCHAR2 DEFAULT '.,',   -- decimal and group character
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')  -- currency character
    ) RETURN VARCHAR2 DETERMINISTIC;

    -- produce the NLS_Param for the to_number function using p_NumChars, p_Currency
    FUNCTION Get_NLS_Param (
        p_NumChars VARCHAR2 DEFAULT numbers_utl.Get_NLS_NumChars,   -- decimal (radix) and group character
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')  -- current Currency character
    ) RETURN VARCHAR2 DETERMINISTIC;

    -- Convert any javascript floating point number string to sql number
    FUNCTION JS_To_Number ( 
        p_Value VARCHAR2 
    ) RETURN NUMBER DETERMINISTIC;

    -- Convert any to_char(x, 'FM9') string to sql number using p_NumChars, p_Currency
    -- convert string with formated oracle floating point number to oracle number.
    -- the string was produced by function TO_CHAR with format FM9 
    -- or a format that contains G D L or EEEE symbols
    FUNCTION FM9_TO_Number( 
        p_Value VARCHAR2, 
        p_NumChars VARCHAR2 DEFAULT '.,',
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY'),
        p_Default_On_Error NUMBER DEFAULT NULL
    ) RETURN NUMBER DETERMINISTIC;
    
    -- convert string with p_Format formatted oracle number to oracle number.
    -- the format symbols G D L or EEEE will be used optionally with fault tolerance
    FUNCTION FN_TO_NUMBER  (
        p_Value VARCHAR2, 
        p_Format VARCHAR2 DEFAULT NULL, 
        p_nlsparam VARCHAR2 DEFAULT numbers_utl.Get_NLS_Param
    ) RETURN NUMBER DETERMINISTIC; -- return a number from a formated string

    FUNCTION Get_Number_Pattern (
        p_NumChars VARCHAR2 DEFAULT '.,'    
    ) RETURN VARCHAR2 DETERMINISTIC;
    
    FUNCTION FM9_Number_Pattern (
        p_NumChars VARCHAR2 DEFAULT '.,',
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')
    ) RETURN VARCHAR2 DETERMINISTIC;

    function Validate_Conversion (
        p_Value VARCHAR2,
        p_NumChars VARCHAR2 DEFAULT '.,',
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')
    ) RETURN VARCHAR2 DETERMINISTIC;
END numbers_utl;
/

CREATE OR REPLACE PACKAGE BODY numbers_utl
IS
    -- return current session NLS_NUMERIC_CHARACTERS
    FUNCTION Get_NLS_NumChars RETURN VARCHAR2
    IS
        v_NLS_NumChars VARCHAR2(10);
    BEGIN
        SELECT /*+ RESULT_CACHE */ VALUE
        INTO v_NLS_NumChars
        FROM nls_session_parameters
        WHERE parameter = 'NLS_NUMERIC_CHARACTERS';
        RETURN v_NLS_NumChars;
    END Get_NLS_NumChars;

    FUNCTION Get_Number_Format_Mask (
        p_Data_Precision NUMBER,
        p_Data_Scale NUMBER,
        p_Use_Group_Separator VARCHAR2 DEFAULT 'Y',
        p_Export VARCHAR2 DEFAULT 'Y',      -- use TM9
        p_Use_Trim VARCHAR2 DEFAULT 'N'     -- use FM
    )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    PRAGMA UDF;
        v_Data_Scale CONSTANT PLS_INTEGER := NVL(p_Data_Scale, g_Default_Data_Scale);
        v_Data_Precision CONSTANT PLS_INTEGER := NVL(p_Data_Precision, g_Default_Data_Precision + g_Default_Data_Scale) - v_Data_Scale + 1; -- one char for minus sign
        v_fraction_char CONSTANT VARCHAR2(1) := case when p_Data_Scale IS NULL then '9' else '0' end;
    BEGIN
        if p_Data_Scale IS NULL and p_Data_Precision IS NULL and p_Export = 'Y' and p_Use_Group_Separator = 'N' then 
            RETURN 'TM9';
        else 
            RETURN SUBSTR(
                    case when p_Use_Trim = 'Y' then 'FM' end
                    || case when p_Use_Group_Separator = 'Y' 
                        then SUBSTR(LPAD('0', CEIL((v_Data_Precision)/3)*4, 'G999'), -(v_Data_Precision+FLOOR((v_Data_Precision-1)/3)) )
                        else LPAD('0', v_Data_Precision, '9')
                    end
                    || case when v_Data_Scale > 0 then RPAD('D0', v_Data_Scale+1, v_fraction_char) end
                , 1, numbers_utl.g_Format_Max_Length); -- maximum length 
        end if;
    END Get_Number_Format_Mask;

    -- produce a format mask for p_Value string using p_NumChars, p_Currency
    FUNCTION Get_Number_Mask (
        p_Value VARCHAR2,                   -- string with formated number
        p_NumChars VARCHAR2 DEFAULT '.,',   -- decimal and group character
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')  -- currency character
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN REGEXP_REPLACE(TRANSLATE(p_Value, 
                '+-012345678'||p_NumChars||p_Currency||' ', 
                '99999999999DGL'), 
            '[e|E]9+$', -- detect exponent 
            'EEEE');
    END Get_Number_Mask;

    -- produce the NLS_Param for the to_number function using p_NumChars, p_Currency
    FUNCTION Get_NLS_Param (
        p_NumChars VARCHAR2 DEFAULT numbers_utl.Get_NLS_NumChars,   -- decimal (radix) and group character
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')  -- current Currency character
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    PRAGMA UDF;
    BEGIN
        RETURN 'NLS_NUMERIC_CHARACTERS = ' || dbms_assert.enquote_literal(p_NumChars)
        || ' NLS_CURRENCY = ' || dbms_assert.enquote_literal(p_Currency);
    END Get_NLS_Param;

    -- Convert any javascript floating point number string to sql number
    FUNCTION JS_To_Number ( p_Value VARCHAR2 ) RETURN NUMBER DETERMINISTIC
    IS
    PRAGMA UDF;
    BEGIN
        RETURN TO_NUMBER(p_Value, Get_Number_Mask(p_Value), q'[NLS_NUMERIC_CHARACTERS = '.,']');
    END JS_To_Number;

    -- Convert any to_char(x, 'FM9') string to sql number using p_NumChars, p_Currency
    -- convert string with formated oracle floating point number to oracle number.
    -- the string was produced by function TO_CHAR with format FM9 
    -- or a format that contains G D L or EEEE symbols
    FUNCTION FM9_TO_Number( 
        p_Value VARCHAR2, 
        p_NumChars VARCHAR2 DEFAULT '.,',
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY'),
        p_Default_On_Error NUMBER DEFAULT NULL
    ) RETURN NUMBER DETERMINISTIC
    IS
    PRAGMA UDF;
    BEGIN
        RETURN TO_NUMBER(TRIM(p_Value), 
            Get_Number_Mask(p_Value, p_NumChars, p_Currency), 
            Get_NLS_Param (p_NumChars, p_Currency));
    EXCEPTION WHEN VALUE_ERROR THEN
        if p_Default_On_Error IS NOT NULL then 
            return p_Default_On_Error;
        else 
            raise;
        end if;
    END FM9_TO_Number;

    -- try conversion of p_Value number string to sql number using p_Format, p_nlsparam
    -- and when that fails convert using a dynamic matching format.
    FUNCTION FN_TO_NUMBER  (
        p_Value VARCHAR2, 
        p_Format VARCHAR2 DEFAULT NULL, 
        p_nlsparam VARCHAR2 DEFAULT numbers_utl.Get_NLS_Param
    ) RETURN NUMBER DETERMINISTIC -- return a number from a formated string
    IS
        v_NLS_NumChars VARCHAR2(10);
        v_NLS_Currency VARCHAR2(10);
    BEGIN
        if p_Format IS NULL then 
            RETURN TO_NUMBER(p_Value);
        else
            RETURN TO_NUMBER(p_Value, p_Format, p_nlsparam);
        end if;
    EXCEPTION WHEN VALUE_ERROR THEN
        v_NLS_NumChars := SUBSTR(p_nlsparam, INSTR(p_nlsparam, chr(39))+1, 2);
        v_NLS_Currency := SUBSTR(p_nlsparam, INSTR(p_nlsparam, chr(39), 1, 3)+1, 1);
        RETURN TO_NUMBER(TRIM(p_Value), numbers_utl.Get_Number_Mask(p_Value, v_NLS_NumChars, v_NLS_Currency), p_nlsparam);
    END FN_TO_NUMBER;

    -- convert p_NumChars to a regular expression number pattern 
    -- used to trim the leading blanks and trailing zeros from the output of to_char with a format string that is containing groupings chars
    FUNCTION Get_Number_Pattern (
        p_NumChars VARCHAR2 DEFAULT '.,'    
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN '([-+]?[0-9]{1,3}(\' || SUBSTR(p_NumChars, 2, 1) ||'?[0-9]{3})*\' || SUBSTR(p_NumChars, 1, 1) || '?[0-9]*?)(0*$)';
    END Get_Number_Pattern;

    -- convert p_NumChars to a regular expression number pattern 
    -- used to validate the input for acceptable number strings
    FUNCTION FM9_Number_Pattern (
        p_NumChars VARCHAR2 DEFAULT '.,',
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN '(\' || p_Currency || '?[-+]?[0-9]{1,3}(\' || SUBSTR(p_NumChars, 2, 1) ||'?[0-9]{3})*\' || SUBSTR(p_NumChars, 1, 1) || '?[0-9]*?([eE][-+]?[0-9]+)?\' || p_Currency || '?$)';
    END FM9_Number_Pattern;
    
    -- used to validate the input for acceptable number strings
    function Validate_Conversion (
        p_Value VARCHAR2,
        p_NumChars VARCHAR2 DEFAULT '.,',
        p_Currency VARCHAR2 DEFAULT SYS_CONTEXT ('USERENV','NLS_CURRENCY')
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when REGEXP_SUBSTR(p_Value, numbers_utl.FM9_Number_Pattern(p_NumChars, p_Currency), 1, 1, 'c', 1) IS NOT NULL then 1 else 0 end;
    END Validate_Conversion;

END numbers_utl;
/

/*
-- Examples and test cases:
-- conversion of string to number formats TM9, …9G999D99…
begin
EXECUTE IMMEDIATE 'alter session set NLS_NUMERIC_CHARACTERS = ' || dbms_assert.enquote_literal('.,'); -- conflicting american settings in APEX session
end;
/
-- PL/SQL test values with a wide range of decimal point positions, signs -/+, exponential numbers.
select i, n, 
    char_tm,
    numbers_utl.Get_Number_Mask(char_tm, ',.') mask,
    numbers_utl.FM9_TO_Number(char_tm, ',.') tm_imp,
    char_fm,
    numbers_utl.FM9_TO_Number(char_fm, ',.') fm_imp 
    , val
from (
    select i, n, 
        val, 
        to_char(val, '999G999G999G999G999G999G999G999G999G999G999G999G990D99999999999',  numbers_utl.Get_NLS_Param(',.')) char_fm,
        substr(to_char(val, 'TM9',  numbers_utl.Get_NLS_Param(',.')), 1, 63) char_tm
    from (select level i, level * 3 -51 n, EXP(1) * power(10, level * 3 - 51) * (1+(mod(level,2)*-2)) val from dual connect by level < 30)
);


-- javascript test values with a wide range of decimal point positions, signs -/+, end exponential numbers.
var i,num, results = '';
for (i = 0; i < 30; i++) {
  num = Math.E * Math.pow(10, i * 3 - 51) * (1+(i%2)*-2);
  results = results + (i?':':'') + num.toString();
}
console.log(results);

-- test sql conversion 
begin
EXECUTE IMMEDIATE 'alter session set NLS_NUMERIC_CHARACTERS = ' || dbms_assert.enquote_literal(',.'); -- conflicting german settings in APEX session
end;
/

select column_value x,
    to_number(column_value DEFAULT 0 ON CONVERSION ERROR) num,
    numbers_utl.JS_To_Number(column_value) js_num,
    numbers_utl.Validate_Conversion (column_value) Is_Valid
from table(apex_string.split(
'2.718281828459045e-51:-2.718281828459045e-48:2.718281828459045e-45:-2.7182818284590448e-42:2.718281828459045e-39:-2.718281828459045e-36:2.7182818284590448e-33:-2.7182818284590448e-30:2.7182818284590452e-27:-2.7182818284590453e-24:2.7182818284590447e-21:-2.7182818284590453e-18:2.718281828459045e-15:-2.718281828459045e-12:2.718281828459045e-9:-0.000002718281828459045:0.002718281828459045:-2.718281828459045:2718.2818284590453:-2718281.828459045:2718281828.459045:-2718281828459.045:2718281828459045:-2718281828459045000:2.718281828459045e+21:-2.718281828459045e+24:2.7182818284590453e+27:-2.718281828459045e+30:2.7182818284590453e+33:-2.718281828459045e+36'
, ':')
);

-- Example for flexible conversion and validation without a format mask
select column_value x,
    numbers_utl.FM9_TO_Number(column_value, '.,', '€') EUR_PRICE,
    numbers_utl.Validate_Conversion(column_value, '.,', '€') Valid
from table(apex_string.split('2.718281828459045e5:1€:€1,024.80:1084.8:€8e8', ':'));

------------------------------------------------------------------------------------------
-- old code with many format masks and complicated parameters
SELECT NVL(TO_NUMBER('5.049696931191348', g_fmt, g_dg ), 4) DIAGRAM_FONTSIZE, 
     TO_NUMBER('1.0750656167979002', g_fmt, g_dg ) DIAGRAM_ZOOMFACTOR, 
     TO_NUMBER('6.756230216764362e-9', '999990D99999999999999999999999999EEEE', g_dg ) DIAGRAM_X_OFFSET, 
     TO_NUMBER('-0.000023050666555340712', g_fmt, g_dg ) DIAGRAM_Y_OFFSET,
     TO_NUMBER('1024', '999990', g_dg ) CANVAS_WIDTH,
     TO_NUMBER('400.0', '999990D9', g_dg ) STIFFNESS, 
     TO_NUMBER('3600.0', '999990D9', g_dg ) REPULSION, 
     TO_NUMBER('0.35000000000000000000000000', g_fmt, g_dg ) DAMPING, 
     TO_NUMBER('0.01000000000000000000000000', g_fmt, g_dg ) MINENERGYTHRESHOLD, 
     TO_NUMBER('50.0', '999990D9', g_dg ) MAXSPEED, 
     TO_NUMBER('10.00000000000000000000000000', g_fmt, g_dg ) PINWEIGHT
FROM DUAL, (select '999990D99999999999999999999999999' g_fmt, q'[NLS_NUMERIC_CHARACTERS = '.,']' g_dg from dual) par 
;
-- Examples of flexible javascript number conversion
SELECT 
     NVL(numbers_utl.JS_To_Number('5.049696931191348' ), 4) DIAGRAM_FONTSIZE, 
     numbers_utl.JS_To_Number('1.0750656167979002' ) DIAGRAM_ZOOMFACTOR, 
     numbers_utl.Get_Number_Mask('6.756230216764362e-09', '.,') Number_Mask,
     numbers_utl.JS_To_Number('6.756230216764362e-09' ) DIAGRAM_X_OFFSET, 
     numbers_utl.JS_To_Number('-0.000023050666555340712' ) DIAGRAM_Y_OFFSET,
     numbers_utl.JS_To_Number('1024' ) CANVAS_WIDTH,
     numbers_utl.JS_To_Number('400.0' ) STIFFNESS, 
     numbers_utl.JS_To_Number('3600.0' ) REPULSION, 
     numbers_utl.JS_To_Number('0.35000000000000000000000000' ) DAMPING, 
     numbers_utl.JS_To_Number('0.01000000000000000000000000' ) MINENERGYTHRESHOLD, 
     numbers_utl.JS_To_Number('50.0' ) MAXSPEED,
     numbers_utl.JS_To_Number('10.00000000000000000000000000' ) PINWEIGHT
FROM DUAL
;
-- Examples of flexible PL/SQL number conversion with simple parameters
SELECT
     numbers_utl.FM9_TO_Number('€2,050.10', '.,', '€', -1 ) EUR_PRICE,
     numbers_utl.FM9_TO_Number('2,050€', '.,', '€', -1 ) EUR_PRICE2,
     numbers_utl.FM9_TO_Number('¥2,050.10', '.,', '¥', -1 ) YEN_PRICE,
     numbers_utl.FM9_TO_Number('$2.050,10', ',.', '$', -1 ) US_PRICE,
     numbers_utl.Get_Number_Mask('$2.050,10', ',.', '$' ) US_MASK,
     numbers_utl.FN_TO_NUMBER('2050,1', 'L9G999D99', numbers_utl.Get_NLS_Param(',.', '$') ) US_PRICE2,
     numbers_utl.FN_TO_NUMBER('2050.1', 'L9G999D99' ) US_PRICE3,
     SYS_CONTEXT ('USERENV','NLS_CURRENCY') NLS_Currency,
     numbers_utl.Get_NLS_NumChars Get_NLS_NumChars
FROM DUAL;

*/
