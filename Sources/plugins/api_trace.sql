/*
Copyright 2019 Dirk Strack, Strack Software Development

All Rights Reserved
Unauthorized copying of this file, via any medium is strictly prohibited
Proprietary and confidential
Written by Dirk Strack <dirk_strack@yahoo.de>, Feb 2019
*/
/*
api_trace enables tracing of calls to prepared packages 
*/

CREATE OR REPLACE PACKAGE api_trace
AUTHID CURRENT_USER 
IS
    c_APEX_Logging_Start_Call  	CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API call: '' || %s, p_level=>5);';
    c_APEX_Logging_Exit_Call 	CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API exit: '' || %s, p_level=>5);';
    c_APEX_Logging_API_Call    	CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API: '' || %s, p_level=>5);';
    c_APEX_Logging_API_Exception CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API Exception: '' || %s, p_level=>5);';
    -- p_level=>4; -- default level if debugging is enabled (for example, used by apex_application.debug)
    -- p_level=>5; -- application: messages when procedures/functions are entered
    -- p_level=>6; -- application: other messages within procedures/functions
    c_format_max_length	CONSTANT NUMBER := 32700;
	c_Package_Name      CONSTANT VARCHAR2(128) := lower($$plsql_unit);
    FUNCTION Literal ( p_Text VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value BLOB, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value CLOB, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value BOOLEAN, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value NUMBER, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal_RAW ( p_Value RAW, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Format_Call_Parameter (
        p_calling_subprog VARCHAR2,             -- name of the called procedure or function in a package format: package_name.procedure_name
        p_synonym_name VARCHAR2 DEFAULT NULL,   -- optional name of the procedure in the log message
        p_value_max_length INTEGER DEFAULT 1000,-- maximum length of an single procedure argument value in the log message
        p_bind_char VARCHAR2 DEFAULT ':',       -- optional bind char that will help to produce bind variables for use with EXECUTE IMMEDIATE
        p_overload INTEGER DEFAULT 0,           -- identifier of a overloded funtion in order of occurence.
        p_in_out VARCHAR2 DEFAULT 'IN/OUT'      -- IN, OUT, IN/OUT. Used to filter the set of procedure arguments that are logged in the message.
    ) RETURN VARCHAR2;

    /* build an pl/sql programm that captures the parameters of an package procedure or function for logging.
       execute with output: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(NULL) USING OUT v_log_message, IN <param...>
       execute with apex_debug: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call USING <param...>
       the count of the arguments will be checked at runtime.
    */
    FUNCTION Dyn_Log_Call (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_API_Call,	-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2; 
    FUNCTION Dyn_Log_Start (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_Start_Call,-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2;
    FUNCTION Dyn_Log_Exit (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_Exit_Call,-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2;
    FUNCTION Dyn_Log_Exception (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_API_Exception,-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0,                             -- identifier of a overloded funtion in order of occurence.
        p_format_error_function IN VARCHAR2 DEFAULT 'DBMS_UTILITY.FORMAT_ERROR_STACK' -- function for formating for the current error. The output is concatinated to the message.
    ) RETURN VARCHAR2;
END api_trace;
/


CREATE OR REPLACE PACKAGE BODY api_trace
IS
    c_Quote CONSTANT VARCHAR2(1) := chr(39);	-- Quote Character

    FUNCTION Literal ( p_Text VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN c_Quote || REPLACE(SUBSTR(p_Text, 1, p_value_max_length), c_Quote, c_Quote||c_Quote) || c_Quote ;
    END Literal;
    
    FUNCTION Literal ( p_Value BLOB, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
        else c_Quote || dbms_lob.getlength(p_Value) || ' bytes' || c_Quote 
        end;
    END Literal;
    
    FUNCTION Literal ( p_Value CLOB, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
        else c_Quote || dbms_lob.substr(p_Value, p_value_max_length, 1) || c_Quote 
        end;
    END Literal;

    FUNCTION Literal ( p_Value BOOLEAN, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
          when p_Value then 'true' else 'false' end ;
    END Literal;

    FUNCTION Literal_RAW ( p_Value RAW, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
        else 'HEXTORAW(' || c_Quote || SUBSTR(RAWTOHEX(p_Value), 1, p_value_max_length) || c_Quote || ')'
        end;
    END Literal_RAW;

    FUNCTION Literal ( p_Value NUMBER, p_value_max_length PLS_INTEGER DEFAULT 1000 )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null' else to_char(p_Value) end ;
    END Literal;

    -- build an expression that captures the parameters of an package procedure for logging.
    -- the procedure or function must be listed in the package header.
    -- when a procedure or function is overloaded then used the p_overload=>1 for the first and p_overload=>2 for the second variant.
    -- invoke with: EXECUTE IMMEDIATE api_trace.Format_Call_Parameter USING OUT v_char_Result;
    -- the count of the arguments will be checked at runtime.
    FUNCTION Format_Call_Parameter (
        p_calling_subprog VARCHAR2,             -- name of the called procedure or function in a package format: package_name.procedure_name
        p_synonym_name VARCHAR2 DEFAULT NULL,   -- optional name of the procedure in the log message
        p_value_max_length INTEGER DEFAULT 1000,-- maximum length of an single procedure argument value in the log message
        p_bind_char VARCHAR2 DEFAULT ':',       -- optional bind char that will help to produce bind variables for use with EXECUTE IMMEDIATE
        p_overload INTEGER DEFAULT 0,           -- identifier of a overloded funtion in order of occurence.
        p_in_out VARCHAR2 DEFAULT 'IN/OUT'      -- IN, OUT, IN/OUT. Used to filter the set of procedure arguments that are logged in the message.
    ) RETURN VARCHAR2
    IS
        PRAGMA UDF;
        c_newline VARCHAR2(10) := 'chr(10)'||chr(10);
        c_argument_per_line CONSTANT NUMBER := 7;
        c_conop VARCHAR2(10) := ' || ';
        v_argument_name VARCHAR2(200);
        v_offset NUMBER;
        v_result_str VARCHAR2(32767);
        v_subprog VARCHAR2(32767);
        v_over  dbms_describe.number_table;
        v_posn  dbms_describe.number_table;
        v_levl  dbms_describe.number_table;
        v_arg_name dbms_describe.varchar2_table;
        v_dtyp  dbms_describe.number_table;
        v_defv  dbms_describe.number_table;
        v_inout dbms_describe.number_table;
        v_len   dbms_describe.number_table;
        v_prec  dbms_describe.number_table;
        v_scal  dbms_describe.number_table;
        v_n     dbms_describe.number_table;
        v_spare dbms_describe.number_table;
        v_idx   INTEGER := 0;
        v_count INTEGER := 0;
    BEGIN 
        dbms_describe.describe_procedure(
            object_name => p_calling_subprog, 
            reserved1 => NULL, 
            reserved2 => NULL,
            overload => v_over, 
            position => v_posn, 
            level => v_levl, 
            argument_name => v_arg_name, 
            datatype => v_dtyp, 
            default_value => v_defv, 
            in_out => v_inout,      -- 0 IN, 1 OUT, 2 IN/OUT 
            length => v_len, 
            precision => v_prec, 
            scale => v_scal, 
            radix => v_n, 
            spare => v_spare
        );
        loop 
            v_idx := v_idx + 1;
            exit when v_idx > v_arg_name.count;
            exit when length(v_result_str) > 32000; 
            if v_posn(v_idx) != 0  -- Position 0 returns the values for the return type of a function. 
            and v_over(v_idx) = NVL(p_overload, 0)
            and v_arg_name(v_idx) IS NOT NULL 
            and (v_inout(v_idx) != 0 or p_in_out IN ('IN', 'IN/OUT')) then
            	v_count := v_count + 1;
            	v_offset := INSTR(v_arg_name(v_idx), '_');
            	if v_offset > 0 then 
                	v_argument_name := lower(substr(v_arg_name(v_idx), 1, v_offset)) || initcap(substr(v_arg_name(v_idx), v_offset+1));
                else 
                	v_argument_name := lower(v_arg_name(v_idx));
                end if;
                if v_result_str IS NOT NULL then 
                    v_result_str := v_result_str 
                    || case when mod(v_idx-1, c_argument_per_line) = 0 then c_conop || c_newline else chr(10) end
                    || '    ' || c_conop;
                end if;
                if v_inout(v_idx) != 0 and p_in_out = 'IN' then -- OUT parameters are not converted to a literal.
                    v_result_str := v_result_str 
                    || Literal(
                    	case when v_count > 1 then ', ' end
                    	|| v_argument_name || '=>' || v_argument_name);
                else 
                    v_result_str := v_result_str 
                    || Literal(case when v_count > 1 then ', ' end
                    	|| v_argument_name || '=>') 
                    || c_conop
                    || case when v_dtyp(v_idx) IN (			-- Is_Printable_Type:
                            2,3, 1, 8, 11, 12, 23,          -- number, varchar,long,rowid,date, raw
                            96, 178,179,180,181,231,252,    -- char,timestamp, time, boolean
                            112, 113)                       -- clob, blob
                        then 
                            c_Package_Name || '.'
                            || case when v_dtyp(v_idx) = 23 then 'Literal_RAW' else 'Literal' end
                            || '(' || p_bind_char || v_argument_name 
                            || case when p_value_max_length != 1000 then ', ' || p_value_max_length end
                            || ')'
                        else 
                            Literal('<datatype '||v_dtyp(v_idx)||' >')
                    end;
                end if;
            end if;
        end loop;
        v_subprog := NVL( p_Synonym_Name, p_calling_subprog );
        if v_result_str IS NOT NULL then 
            v_result_str := Literal(v_subprog || '(') || chr(10)
            || '    ' || c_conop || v_result_str || c_conop || Literal(')');
        else 
            v_result_str := Literal(v_subprog);
        end if;
        RETURN v_result_str;
    END Format_Call_Parameter;

    /* build an expression that captures the parameters of an package procedure for logging.
       execute with output: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(NULL) USING OUT v_log_message, IN <param...>
       execute with apex_debug: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call USING <param...>
       the count of the arguments will be checked at runtime.
    */
    FUNCTION Dyn_Log_Call (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_API_Call,	-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2
    IS
        c_calling_subprog constant varchar2(512) := lower(utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2))); 
        v_result_str VARCHAR2(32767);
    BEGIN
        v_result_str := Format_Call_Parameter( 
            p_calling_subprog => c_calling_subprog,
            p_value_max_length => p_value_max_length,
            p_bind_char => ':',
            p_overload => p_overload,
            p_in_out => 'IN/OUT'
        );
        if p_Logging_Call IS NOT NULL then 
            return 'begin ' || apex_string.format(p_message=>p_Logging_Call, p0=>v_result_str, p_max_length=>c_format_max_length) || ' end;';
        else
            return v_result_str;
        end if;
    END Dyn_Log_Call; 

    FUNCTION Dyn_Log_Start (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_Start_Call,-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2
    IS
        c_calling_subprog constant varchar2(512) := lower(utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2))); 
        v_result_str VARCHAR2(32767);
    BEGIN
        v_result_str := Format_Call_Parameter( 
            p_calling_subprog => c_calling_subprog,
            p_value_max_length => p_value_max_length,
            p_bind_char => ':',
            p_overload => p_overload,
            p_in_out => 'IN'
        );
        if p_Logging_Call IS NOT NULL then 
            return 'begin ' || apex_string.format(p_message=>p_Logging_Call, p0=>v_result_str, p_max_length=>c_format_max_length) || ' end;';
        else
            return v_result_str;
        end if;
    END Dyn_Log_Start; 

    FUNCTION Dyn_Log_Exit (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_Exit_Call,-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2
    IS
        c_calling_subprog constant varchar2(512) := lower(utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2))); 
        v_result_str VARCHAR2(32767);
    BEGIN
        v_result_str := Format_Call_Parameter( 
            p_calling_subprog => c_calling_subprog,
            p_value_max_length => p_value_max_length,
            p_bind_char => ':',
            p_overload => p_overload,
            p_in_out => 'OUT'
        );
        if p_Logging_Call IS NOT NULL then 
            return 'begin ' || apex_string.format(p_message=>p_Logging_Call, p0=>v_result_str, p_max_length=>c_format_max_length) || ' end;';
        else
            return v_result_str;
        end if;
    END Dyn_Log_Exit; 
    
    FUNCTION Dyn_Log_Exception (
        p_Logging_Call IN VARCHAR2 DEFAULT c_APEX_Logging_API_Exception,-- a format string that is passed to apex_string.format as p_message.
        p_value_max_length IN INTEGER DEFAULT 1000,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0,                             -- identifier of a overloded funtion in order of occurence.
        p_format_error_function IN VARCHAR2 DEFAULT 'DBMS_UTILITY.FORMAT_ERROR_STACK' -- function for formating for the current error. The output is concatinated to the message.
    ) RETURN VARCHAR2
    IS
        c_calling_subprog constant varchar2(512) := lower(utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2))); 
        v_result_str VARCHAR2(32767);
    BEGIN
        v_result_str := Format_Call_Parameter( 
            p_calling_subprog => c_calling_subprog,
            p_value_max_length => p_value_max_length,
            p_bind_char => ':',
            p_overload => p_overload,
            p_in_out => 'IN/OUT'
        )
        || ' || ' || p_format_error_function;
        if p_Logging_Call IS NOT NULL then 
            return 'begin ' || apex_string.format(p_message=>p_Logging_Call, p0=>v_result_str, p_max_length=>c_format_max_length) || ' end;';
        else
            return v_result_str;
        end if;
    END Dyn_Log_Exception; 
END api_trace;
/
