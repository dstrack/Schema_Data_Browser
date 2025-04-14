
CREATE OR REPLACE PACKAGE data_browser_ctl
AUTHID CURRENT_USER
IS
	FUNCTION Gen_Licence (
		p_Owner VARCHAR2 DEFAULT 'Strack Software Entwicklung'
	) RETURN VARCHAR2;
	PROCEDURE Start_Trial_Modus; 
	FUNCTION App_Trial_Code RETURN VARCHAR2;
	FUNCTION App_Trial_Modus RETURN BOOLEAN;
	FUNCTION App_Paid_Modus RETURN BOOLEAN;
	FUNCTION App_Trial_Modus_vc RETURN VARCHAR2;
	FUNCTION App_Paid_Modus_vc RETURN VARCHAR2;
	PROCEDURE Set_App_Licence_Number (p_Code IN VARCHAR2, p_Owner IN VARCHAR2);
	FUNCTION App_Modus RETURN VARCHAR2;
end data_browser_ctl;
/
show errors


CREATE OR REPLACE PACKAGE BODY data_browser_ctl
IS
	g_Date_NLS_Const CONSTANT VARCHAR2(50) := 'NLS_DATE_LANGUAGE=French';
	g_Date_Fmt_Const CONSTANT VARCHAR2(50) := 'DD.Month.YYYY HH24:MI:SS';

	FUNCTION Gen_Licence (
		p_Owner VARCHAR2 DEFAULT 'Strack Software Entwicklung'
	) RETURN VARCHAR2
	IS
		v_rand BINARY_INTEGER := ABS(MOD(DBMS_RANDOM.NORMAL, POWER(10,7)-1));
		v_hash NUMBER; 
		v_CCODE VARCHAR2(4) := 'DB';
		v_Main_Version VARCHAR2(4) := SUBSTR(data_browser_conf.Get_App_Library_Version, 1, 1);
		v_Orgin PLS_INTEGER := ASCII('@') - 9;
		v_CCNR VARCHAR2(10) := RPAD(TO_CHAR(ASCII(SUBSTR(v_CCODE, 1, 1)) - v_Orgin) 
								  || TO_CHAR(ASCII(SUBSTR(v_CCODE, 2, 1)) - v_Orgin), 6, '0');
		v_BKNR VARCHAR2(50);
		v_PRUEFZIFFER VARCHAR2(10);
		v_Licence_Code VARCHAR2(50);
	BEGIN
		select ORA_HASH(p_Owner, POWER(10,8)-1, v_rand) into v_hash from dual;
		v_BKNR := v_Main_Version || LPAD(v_rand, 7, '0') || LPAD(v_hash, 8, '0'); -- 16 digits
		v_PRUEFZIFFER := LPAD(98 - MOD(TO_NUMBER(v_BKNR || v_CCNR), 97), 2, '0');
		v_Licence_Code := v_CCODE || v_PRUEFZIFFER || v_BKNR;
		RETURN REGEXP_REPLACE(v_Licence_Code, '(.{4})(.{4})(.{4})(.{4})(.{4})', '\1-\2-\3-\4-\5');
	END Gen_Licence;

    FUNCTION Lic_hash_code(
    	p_Text IN VARCHAR2,
    	p_Date IN VARCHAR2)
    RETURN VARCHAR2
    IS
    	v_salt VARCHAR2(300);
    	v_length pls_integer;
    	v_length2 pls_integer;
    BEGIN
		v_length := length(data_browser_conf.g_Software_Copyright);
		SELECT ORA_HASH(p_Text, v_length, 7+v_length) x into v_length2 from dual;
		v_salt := SUBSTR(data_browser_conf.g_Software_Copyright || data_browser_conf.g_Software_Copyright, v_length2, v_length);
		RETURN apex_util.get_hash(p_values => apex_t_varchar2 (p_Text, chr(45), p_Date, chr(43), v_salt), p_salted => false);
    END Lic_hash_code;

	PROCEDURE Start_Trial_Modus 
	IS 
	BEGIN
		data_browser_conf.load_config;
		if data_browser_conf.Get_App_Installation_Code IS NULL then 
			data_browser_conf.Set_App_Installation_Code(
				Lic_hash_code(
					p_Text => data_browser_conf.g_App_Created_By, 
					p_Date => to_char(data_browser_conf.g_App_Created_At, g_Date_Fmt_Const, g_Date_NLS_Const)));
    	end if;
	END Start_Trial_Modus;

	FUNCTION App_Trial_Code RETURN VARCHAR2 
	IS
	BEGIN 
		RETURN Lic_hash_code(
				p_Text => data_browser_conf.g_App_Created_By, 
				p_Date => to_char(data_browser_conf.g_App_Created_At, g_Date_Fmt_Const, g_Date_NLS_Const)
			);
	END App_Trial_Code;

	FUNCTION App_Trial_Modus RETURN BOOLEAN 
	IS
	BEGIN 
		RETURN case when 
			Lic_hash_code(
				p_Text => data_browser_conf.g_App_Created_By, 
				p_Date => to_char(data_browser_conf.g_App_Created_At, g_Date_Fmt_Const, g_Date_NLS_Const)
			) = data_browser_conf.Get_App_Installation_Code 
			and MONTHS_BETWEEN(data_browser_conf.g_App_Created_At, sysdate) < 2
			then true else false end;
	END App_Trial_Modus;

	FUNCTION App_Licence_Check(p_Code IN VARCHAR2) RETURN NUMBER 
	IS
		l_CHAR_ORGIN	PLS_INTEGER := ASCII('A') - 10;
		l_CCODE			VARCHAR2(10) := SUBSTR(p_Code, 1, 2);
		l_IBAN 			VARCHAR2(50) := l_CCODE || REGEXP_REPLACE(SUBSTR(p_Code, 3), '\D');
		l_CCNR 			VARCHAR2(10);
		l_BKNR 			VARCHAR2(50);
		l_PRUEFZIFFER 	PLS_INTEGER;
	BEGIN
		if LENGTH(l_IBAN) >= 20 then 
			l_BKNR := RPAD(SUBSTR(l_IBAN, 5), 16, '0');
			
			l_CCNR := RPAD(TO_CHAR(ASCII(SUBSTR(l_CCODE, 1, 1)) - l_CHAR_ORGIN) 
						|| TO_CHAR(ASCII(SUBSTR(l_CCODE, 2, 1)) - l_CHAR_ORGIN)
						|| SUBSTR(l_IBAN, 3, 2), 6, '0');
			l_PRUEFZIFFER := MOD(TO_NUMBER(l_BKNR || l_CCNR), 97);
			return l_PRUEFZIFFER;
		end if;
		return 0;
	END App_Licence_Check;
	
	FUNCTION App_Licence_Check2(p_Code IN VARCHAR2, p_Owner IN VARCHAR2) RETURN NUMBER 
	IS
		v_version VARCHAR2(4) := SUBSTR(data_browser_conf.Get_App_Library_Version, 1, 1);
		v_Licence_Number VARCHAR2(50) := REGEXP_REPLACE(SUBSTR(p_Code, 3), '\D');
		v_rand BINARY_INTEGER := SUBSTR(v_Licence_Number, 4, 7);
		v_hash NUMBER; 
	BEGIN
		select ORA_HASH(p_Owner, POWER(10,8)-1, v_rand) into v_hash from dual;
		if LOWER(SUBSTR(p_Code, 1, 2)) = 'db' 
		and SUBSTR(v_Licence_Number, 3, 1) = v_version 
		and SUBSTR(v_Licence_Number, 11, 8) = LPAD(v_hash, 8, '0') 
		then 
			return 1;
		else 
			return 0;
		end if;
	END App_Licence_Check2;

	FUNCTION App_Licence_Modus(p_Code IN VARCHAR2, p_Owner IN VARCHAR2) RETURN BOOLEAN 
	IS BEGIN
		return App_Licence_Check(p_Code) = 1 and App_Licence_Check2(p_Code, p_Owner) = 1;
	END App_Licence_Modus;


	FUNCTION App_Paid_Modus RETURN BOOLEAN 
	IS
	BEGIN 
		RETURN Lic_hash_code(
				p_Text => data_browser_conf.Get_App_Licence_Number, 
				p_Date => substr(data_browser_conf.Get_App_Library_Version, 1,2)) 
			= data_browser_conf.Get_App_Installation_Code;
	END App_Paid_Modus;

	FUNCTION App_Trial_Modus_vc RETURN VARCHAR2 IS BEGIN RETURN CASE WHEN data_browser_ctl.App_Trial_Modus THEN 'YES' ELSE 'NO' END; END;
	FUNCTION App_Paid_Modus_vc RETURN VARCHAR2 IS BEGIN RETURN CASE WHEN data_browser_ctl.App_Paid_Modus THEN 'YES' ELSE 'NO' END; END;

	PROCEDURE Set_App_Licence_Number (p_Code IN VARCHAR2, p_Owner IN VARCHAR2)
	IS
		v_Cnt PLS_INTEGER;
	BEGIN 
		if App_Licence_Modus(p_Code, p_Owner) then 
			data_browser_conf.g_App_Licence_Number := p_Code;
			data_browser_conf.g_App_Licence_Owner := p_Owner;
			UPDATE DATA_BROWSER_CONFIG 
			SET App_Licence_Number = p_Code
			  , App_Licence_Owner = p_Owner
			WHERE ID = data_browser_conf.Get_Configuration_Id;
			v_Cnt := SQL%ROwCOUNT;
			COMMIT;
			if v_Cnt > 0 then
				data_browser_conf.Set_App_Installation_Code(
					Lic_hash_code(
						p_Text => data_browser_conf.Get_App_Licence_Number, 
						p_Date => substr(data_browser_conf.Get_App_Library_Version, 1,2)));
				DBMS_OUTPUT.PUT_LINE('done');
			else
				DBMS_OUTPUT.PUT_LINE('update failed');
			end if;
		else
			DBMS_OUTPUT.PUT_LINE('validation failed');
		end if;
	END Set_App_Licence_Number;
	
	FUNCTION App_Modus RETURN VARCHAR2 
	IS 
	BEGIN 
		RETURN case 
			when data_browser_ctl.App_Paid_Modus then 
				'Licensed'
			when data_browser_ctl.App_Trial_Modus then 
				'Trial period. ' || (ADD_MONTHS(TRUNC(data_browser_conf.g_App_Created_At), 2) - TRUNC(SYSDATE))
				|| ' days remaining.'
			else 
				'Demo (read-only access)'
			end
			|| ' ' || chr(14848696) || ' ' || TO_CHAR(sysdate, 'YYYY ') || data_browser_conf.g_Software_Copyright;
	END App_Modus;
end data_browser_ctl;
/
show errors

