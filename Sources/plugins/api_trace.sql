/*
Copyright 2021 Dirk Strack, Strack Software Development

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
------------------------------------------------------------------------------------------
/*
api_trace enables tracing of call with arguments to prepared packages 
*/

CREATE OR REPLACE PACKAGE api_trace
AUTHID CURRENT_USER 
IS
    c_APEX_Logging_Start_Call  CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API call: '' || %s, p_level=>5);';
    c_APEX_Logging_Exit_Call CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API exit: '' || %s, p_level=>5);';
    c_APEX_Logging_API_Call CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API: '' || %s, p_level=>5);';
    c_APEX_Logging_API_Exception CONSTANT VARCHAR2(1000) := 'apex_debug.log_long_message(p_message=>''API Exception: '' || %s, p_level=>5);';
	c_DBMS_OUTPUT_API_Call 	CONSTANT VARCHAR2(1000) := 'DBMS_OUTPUT.PUT_LINE(''API: '' || %s);';
    -- p_level=>4; -- default level if debugging is enabled (for example, used by apex_application.debug)
    -- p_level=>5; -- application: messages when procedures/functions are entered
    -- p_level=>6; -- application: other messages within procedures/functions
    c_format_max_length 	CONSTANT NUMBER := 32700;
    c_value_max_length  	CONSTANT NUMBER := 1000;
	c_Package_Name          CONSTANT VARCHAR2(128) := lower($$plsql_unit);
	
	g_Logging_Start_Call	VARCHAR2(32767) := c_APEX_Logging_Start_Call;
	g_Logging_Exit_Call 	VARCHAR2(32767) := c_APEX_Logging_Exit_Call;
	g_Logging_API_Call    	VARCHAR2(32767) := c_APEX_Logging_API_Call;
	g_Logging_API_Exception VARCHAR2(32767) := c_APEX_Logging_API_Exception;
	PROCEDURE Init_APEX_Logging;
	PROCEDURE Init_DBMS_OUTPUT;
    FUNCTION Literal ( p_Text VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value BLOB, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value CLOB, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value BOOLEAN, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal ( p_Value NUMBER, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal_RAW ( p_Value RAW, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION Literal_PWD ( p_Value VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC;

    FUNCTION Format_Call_Parameter(
        p_calling_subprog VARCHAR2,             -- name of the called procedure or function in a package format: owner.package_name.procedure_name
        p_synonym_name VARCHAR2 DEFAULT NULL,   -- optional name of the procedure in the log message
        p_value_max_length INTEGER DEFAULT c_value_max_length,-- maximum length of an single procedure argument value in the log message
        p_bind_char VARCHAR2 DEFAULT ':',       -- optional bind char that will help to produce bind variables for use with EXECUTE IMMEDIATE
        p_overload INTEGER DEFAULT 0,           -- identifier of a overloded funtion in order of occurence.
        p_in_out VARCHAR2 DEFAULT 'IN/OUT',     -- IN, OUT, IN/OUT. Used to filter the set of procedure arguments that are logged in the message.
        p_return_variable VARCHAR2 DEFAULT NULL -- optional name of the variable containing the function result. Usually 'lv_result'
    ) RETURN VARCHAR2;

    /* build an pl/sql programm that captures the parameters of an package procedure or function for logging.
       execute with output: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(NULL) USING OUT v_log_message, IN <param...>
       execute with apex_debug: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call USING <param...>
       the count of the arguments will be checked at runtime.
    */

	-- log function or procedure call with all arguments
    FUNCTION Dyn_Log_Call(
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_API_Call,	-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2; 
	-- log function call with all arguments and return value
    FUNCTION Dyn_Log_Function_Call(
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_API_Call, -- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2;
	-- log function or procedure call with all IN or IN/OUT arguments
    FUNCTION Dyn_Log_Start (
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_Start_Call,-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2;
	-- log function or procedure call with all OUT or IN/OUT arguments
    FUNCTION Dyn_Log_Exit (
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_Exit_Call,-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                             -- identifier of a overloded funtion in order of occurence.
    ) RETURN VARCHAR2;
	-- log function exception with all arguments and error stack
    FUNCTION Dyn_Log_Exception (
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_API_Exception,-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0,                             -- identifier of a overloded funtion in order of occurence.
        p_format_error_function IN VARCHAR2 DEFAULT 'DBMS_UTILITY.FORMAT_ERROR_STACK' -- function for formating for the current error. The output is concatinated to the message.
    ) RETURN VARCHAR2;
END api_trace;
/


CREATE OR REPLACE PACKAGE BODY api_trace
IS
    c_Quote CONSTANT VARCHAR2(1) := chr(39);	-- Quote Character

	PROCEDURE Init_APEX_Logging IS
    BEGIN
		g_Logging_Start_Call	:= c_APEX_Logging_Start_Call;
		g_Logging_Exit_Call 	:= c_APEX_Logging_Exit_Call;
		g_Logging_API_Call    	:= c_APEX_Logging_API_Call;
		g_Logging_API_Exception := c_APEX_Logging_API_Exception;
	END Init_APEX_Logging;

	PROCEDURE Init_DBMS_OUTPUT IS
    BEGIN
		g_Logging_Start_Call	:= c_DBMS_OUTPUT_API_Call;
		g_Logging_Exit_Call 	:= c_DBMS_OUTPUT_API_Call;
		g_Logging_API_Call    	:= c_DBMS_OUTPUT_API_Call;
		g_Logging_API_Exception := c_DBMS_OUTPUT_API_Call;
	END Init_DBMS_OUTPUT;
	
    FUNCTION Literal ( p_Text VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN c_Quote || replace(substr(p_Text, 1, p_value_max_length), c_Quote, c_Quote||c_Quote) || c_Quote ;
    END Literal;
    
    FUNCTION Literal ( p_Value BLOB, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
        else c_Quote || dbms_lob.getlength(p_Value) || ' bytes' || c_Quote 
        end;
    END Literal;
    
    FUNCTION Literal ( p_Value CLOB, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
        else c_Quote || dbms_lob.substr(p_Value, p_value_max_length, 1) || c_Quote 
        end;
    END Literal;

    FUNCTION Literal ( p_Value BOOLEAN, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
          when p_Value then 'true' else 'false' end ;
    END Literal;

    FUNCTION Literal ( p_Value NUMBER, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null' 
        else substr(to_char(p_Value), 1, p_value_max_length) 
        end;
    END Literal;

    FUNCTION Literal_RAW ( p_Value RAW, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN case when p_Value IS NULL then 'null'
        else 'HEXTORAW(' || c_Quote || substr(rawtohex(p_Value), 1, p_value_max_length) || c_Quote || ')'
        end;
    END Literal_RAW;

    FUNCTION Literal_PWD ( p_Value VARCHAR2, p_value_max_length PLS_INTEGER DEFAULT c_value_max_length )
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN c_Quote || substr(rpad('X', LENGTH(p_Value), 'X'), 1, p_value_max_length) || c_Quote;
    END Literal_PWD;

    -- build an expression that captures the parameters of an package procedure for logging.
    -- the procedure or function must be listed in the package header.
    -- when a procedure or function is overloaded then used the p_overload=>1 for the first and p_overload=>2 for the second variant.
    -- invoke with: EXECUTE IMMEDIATE api_trace.Format_Call_Parameter USING OUT v_char_Result;
    -- the count of the arguments will be checked at runtime.
    FUNCTION Format_Call_Parameter(
        p_calling_subprog VARCHAR2,             -- name of the called procedure or function in a package format: package_name.procedure_name
        p_synonym_name VARCHAR2 DEFAULT NULL,   -- optional name of the procedure in the log message
        p_value_max_length INTEGER DEFAULT c_value_max_length,-- maximum length of an single procedure argument value in the log message
        p_bind_char VARCHAR2 DEFAULT ':',       -- optional bind char that will help to produce bind variables for use with EXECUTE IMMEDIATE
        p_overload INTEGER DEFAULT 0,           -- identifier of a overloded funtion in order of occurence.
        p_in_out VARCHAR2 DEFAULT 'IN/OUT',     -- IN, OUT, IN/OUT. Used to filter the set of procedure arguments that are logged in the message.
        p_return_variable VARCHAR2 DEFAULT NULL -- optional name of the variable containing the function result. Usually 'lv_result'
    ) RETURN VARCHAR2
    IS
		$IF DBMS_DB_VERSION.VERSION >= 12 $THEN
			PRAGMA UDF;
		$END
        c_newline CONSTANT VARCHAR2(10) := 'chr(10)'||chr(10);
        c_argument_per_line CONSTANT PLS_INTEGER := 7;
        c_conop CONSTANT VARCHAR2(10) := ' || ';
        v_argument_name VARCHAR2(200);
        v_result_str VARCHAR2(32767);
        v_element_str VARCHAR2(32767);
        v_returns_str VARCHAR2(32767);
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
        
		FUNCTION Formatted_Name(p_arg_name VARCHAR2) RETURN VARCHAR2 
		IS 
			v_offset NUMBER;
			v_result VARCHAR2(200);
		BEGIN 
			v_offset := INSTR(v_arg_name(v_idx), '_');
			if v_offset > 0 and v_offset < 4 then 
				v_result := lower(substr(p_arg_name, 1, v_offset)) || initcap(substr(p_arg_name, v_offset+1));
			else 
				v_result := lower(p_arg_name);
			end if;
			RETURN v_result;
		END;
		FUNCTION Literal_Call (
			p_Argument_Name VARCHAR2, 
			p_Formatted_Name VARCHAR2,
			p_Data_Type NUMBER
		) RETURN VARCHAR2 
		IS 
		BEGIN 
			RETURN case 
				when p_Data_Type IN (122, 251, 123) -- Nested table type, Index-by (PL/SQL) table type, Variable array
				then 
					p_bind_char || p_Formatted_Name 
					|| case when p_bind_char IS NULL then '.COUNT' end
					|| c_conop
            		|| Literal(' rows') 
				when p_Data_Type IN (			-- Is_Printable_Type:
					2,3, 1, 8, 11, 12, 23,          -- number, varchar,long,rowid,date, raw
					96, 178,179,180,181,231,252,    -- char,timestamp, time, boolean
					182, 183,						-- interval year to month, interval day to second
					112, 113)                       -- clob, blob
				then 
					c_Package_Name || '.'
					|| case when p_Argument_Name in ('P_PASSWORD', 'P_PASS', 'P_WALLET_PWD', 'P_WEB_PASSWORD', 'P_OLD_PASSWORD', 'P_NEW_PASSWORD')
						then 'Literal_PWD'
					when p_Data_Type = 23 
						then 'Literal_RAW' 
						else 'Literal' 
					end
					|| '(' || p_bind_char || p_Formatted_Name 
					|| case when p_value_max_length != c_value_max_length then ', ' || p_value_max_length end
					|| ')'
				else 
					Literal('<datatype '||p_Data_Type||'>')
			end;
		END;
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
            	v_argument_name := Formatted_Name(v_arg_name(v_idx));
                if v_result_str IS NOT NULL then 
                    v_result_str := v_result_str 
                    || case when mod(v_idx-1, c_argument_per_line) = 0 then c_conop || c_newline else chr(10) end
                    || '    ' || c_conop;
                end if;
                if v_inout(v_idx) != 0 and p_in_out = 'IN' then -- OUT parameters are not converted to a literal for logging at start of procedure
                    v_result_str := v_result_str 
                    || Literal(
                    	case when v_count > 1 then ', ' end
                    	|| v_argument_name || '=>' || v_argument_name);
                else 
                    v_result_str := v_result_str 
                    || Literal(case when v_count > 1 then ', ' end
                    	|| v_argument_name || '=>') 
                    || c_conop
                    || Literal_Call (
						p_Argument_Name => v_arg_name(v_idx), 
						p_Formatted_Name => v_argument_name,
						p_Data_Type => v_dtyp(v_idx)
					);
                end if;
            elsif v_posn(v_idx) = 0
            and v_arg_name(v_idx) IS NULL 
            and p_return_variable IS NOT NULL then 
            	v_returns_str := chr(10)
				|| '    ' || c_conop
				|| Literal(' Returns ') 
				|| c_conop
				|| Literal_Call (
					p_Argument_Name => p_return_variable, 
					p_Formatted_Name => Formatted_Name(p_return_variable),
					p_Data_Type => v_dtyp(v_idx)
				);
            end if;
        end loop;
        v_subprog := NVL( p_Synonym_Name, p_calling_subprog );
        if v_result_str IS NOT NULL then 
            v_result_str := Literal(v_subprog || '(') || chr(10)
            || '    ' || c_conop || v_result_str || c_conop || Literal(')');
        else 
            v_result_str := Literal(v_subprog);
        end if;
        v_result_str := v_result_str || v_returns_str;
        RETURN v_result_str;
    END Format_Call_Parameter;

    /* build an expression that captures the parameters of an package procedure for logging.
       execute with output: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call(NULL) USING OUT v_log_message, IN <param...>
       execute with apex_debug: EXECUTE IMMEDIATE api_trace.Dyn_Log_Call USING <param...>
       the count of the arguments will be checked at runtime.
    */
    FUNCTION Format_Call(p_Logging_Call IN VARCHAR2, p_Call_Parameter IN VARCHAR2) 
    RETURN VARCHAR2
    IS
    BEGIN 
    	RETURN 'begin ' || replace(p_Logging_Call, '%s', p_Call_Parameter) || ' end;';
    END Format_Call;
    
	-- log function or procedure call with all arguments
    FUNCTION Dyn_Log_Call(
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_API_Call,   	 -- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                      -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                                  -- identifier of a overloded funtion in order of occurence.
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
            return Format_Call(p_Logging_Call=>p_Logging_Call, p_Call_Parameter=>v_result_str);
        else
            return v_result_str;
        end if;
    END Dyn_Log_Call; 

	-- log function call with all arguments and return value
    FUNCTION Dyn_Log_Function_Call(
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_API_Call,   	 -- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                      -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0                                  -- identifier of a overloded funtion in order of occurence.
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
            p_in_out => 'IN/OUT',
            p_return_variable => 'v_result'
        );
        if p_Logging_Call IS NOT NULL then 
            return Format_Call(p_Logging_Call=>p_Logging_Call, p_Call_Parameter=>v_result_str);
        else
            return v_result_str;
        end if;
    END Dyn_Log_Function_Call; 

	-- log function or procedure call with all IN or IN/OUT arguments
    FUNCTION Dyn_Log_Start (
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_Start_Call,-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
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
            return Format_Call(p_Logging_Call=>p_Logging_Call, p_Call_Parameter=>v_result_str);
        else
            return v_result_str;
        end if;
    END Dyn_Log_Start; 

	-- log function or procedure call with all OUT or IN/OUT arguments
    FUNCTION Dyn_Log_Exit (
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_Exit_Call,-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,                 -- maximum length of an single procedure argument value in the log message
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
            p_in_out => 'OUT',
            p_return_variable => 'v_result'
        );
        if p_Logging_Call IS NOT NULL then 
            return Format_Call(p_Logging_Call=>p_Logging_Call, p_Call_Parameter=>v_result_str);
        else
            return v_result_str;
        end if;
    END Dyn_Log_Exit; 
    
	-- log function exception with all arguments and error stack
    FUNCTION Dyn_Log_Exception (
        p_Logging_Call IN VARCHAR2 DEFAULT g_Logging_API_Exception,	-- string with a %s placeholder for the call arguments.
        p_value_max_length IN INTEGER DEFAULT c_value_max_length,   -- maximum length of an single procedure argument value in the log message
        p_overload IN INTEGER DEFAULT 0,                            -- identifier of a overloded funtion in order of occurence.
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
            return Format_Call(p_Logging_Call=>p_Logging_Call, p_Call_Parameter=>v_result_str);
        else
            return v_result_str;
        end if;
    END Dyn_Log_Exception; 
END api_trace;
/
