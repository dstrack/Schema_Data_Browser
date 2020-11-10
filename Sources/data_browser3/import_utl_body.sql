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


/*
------------------------------------------------------------------------------
	Package mit Views und materialized Views für die Analyse des System
	Katalogs und Prozeduren zur Erzeugung von Views und Triggers mit allen
	Details zum Exportieren und Importieren je Benutzer Tabelle.

	Die Prozedur import_utl.Generate_Imp_Table erzeugt für eine Benutzer
	Tabelle je eine - Import View mit instead of insert trigger mit allen
	einfachen Spalten der Benutzer Tabelle und übersetzen
	Fremdschlüsselwerten. Die seriellen Schlüsselwerte werden durch ihre
	lesbaren eindeutigen Beschreibungen ersetzt. - History View ist eine
	Übersicht mit farblicher Hervorhebung der geänderten Werte zu einem
	bestimmenten Zeitpunkt.

	- Import Table mit allen Spalten als Textfelder für den direkten
	Import aus einer .csv Datei.

	- Import Check View mit Fehler Details je Spalte und als Übersicht
	mit farblicher Hervorhebung der fehlerhaften Werte. Für alle Werte wird
	geprüft, ob eine Konvertierung zu internen Datentypen möglich ist und ob
	alle Check Constraints erfüllt sind. Für alle Fremdschlüssel wird
	geprüft, ob ein Lookup oder ggf. eine Neuanlage möglich ist. - Import
	Differenz View mit farblicher Hervorhebung der unterschiedlichen Werte im
	Vergleich zwischen dem Datenbestand und den Daten eines Import Jobs

	- Import nur der als fehlerfrei geprüften Zeilen aus dem
	Importtabelle in den Datenbestand.

	- komfortable Erzeugung von Ansichten für die Überprüfung und den
	Vergleich von Importdaten und Änderungen mit vielen Optionen wie Filter
	für Errors, Differences, New Rows, Missing Rows und Filter Combine (Union
	oder Intersect).

*/

CREATE OR REPLACE PACKAGE BODY import_utl IS

	FUNCTION FN_Pipe_table_imp_cols (p_Table_Name VARCHAR2)
	RETURN tab_table_imp_cols PIPELINED
	IS
        CURSOR views_cur (v_Table_Name VARCHAR2)
        IS
		SELECT S.VIEW_NAME TABLE_NAME, COLUMN_NAME,
			COLUMN_EXPR,
			import_utl.Get_CompareFunction(DATA_TYPE) COLUMN_COMPARE,
			import_utl.Get_MarkupFunction(DATA_TYPE) COLUMN_MARKUP,
			case when COLUMN_NAME != 'LINK_ID$' then
				import_utl.Get_ImpColumnCheck (DATA_TYPE, DATA_SCALE, CHAR_LENGTH, NULLABLE, COLUMN_NAME)
			end COLUMN_CHECK_EXPR,
			COLUMN_ID, POSITION, COLUMN_NAME IMP_COLUMN_NAME, COLUMN_ALIGN, 
			COLUMN_EXPR_TYPE,
			HAS_DEFAULT, IS_VIRTUAL_COLUMN, IS_DATETIME,
			DATA_TYPE, DATA_SCALE, DATA_PRECISION, CHAR_LENGTH, NULLABLE,
			E.REF_VIEW_NAME R_VIEW_NAME, REF_COLUMN_NAME, TABLE_ALIAS
		FROM MVDATA_BROWSER_VIEWS S, TABLE(
			data_browser_select.Get_View_Column_Cursor(
				p_Table_Name => S.VIEW_NAME,
				p_Unique_Key_Column => S.SEARCH_KEY_COLS,
				p_Data_Columns_Only => 'NO',
				p_Data_Format => 'NATIVE',
				p_View_Mode => 'IMPORT_VIEW',
				p_Edit_Mode => 'YES',
				p_Report_Mode => 'NO'
			)
		) E
		WHERE S.VIEW_NAME = p_Table_Name
		-- AND (import_utl.Get_Exclude_Blob_Columns = 'NO' or data_browser_select.FN_Is_Sortable_Column(COLUMN_EXPR_TYPE) = 'YES')
		;
        v_in_row rec_table_imp_cols;
	BEGIN
		OPEN views_cur(p_Table_Name);
		LOOP
			FETCH views_cur INTO v_in_row;
			EXIT WHEN views_cur%NOTFOUND;
			pipe row (v_in_row);
		END LOOP;
		CLOSE views_cur;
	end FN_Pipe_table_imp_cols;

	FUNCTION FN_Pipe_table_imp_trigger (
		p_Table_Name VARCHAR2,
		p_Data_Format VARCHAR2 DEFAULT 'NATIVE' -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
	)
	RETURN tab_table_imp_trigger PIPELINED
	IS
		v_Use_Group_Separator 	CONSTANT VARCHAR2(1) := 'Y';
		v_use_NLS_params 		CONSTANT VARCHAR2(1) := 'Y'; -- case when v_Data_Format = 'FORM' then 'N' else 'Y' end

        CURSOR views_cur (v_Table_Name VARCHAR2, v_Data_Format VARCHAR2)
        IS
		WITH REFERENCES_Q AS (
			SELECT E.*
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) E
			WHERE (E.TABLE_ALIAS != 'A'  OR E.TABLE_ALIAS IS NULL OR E.COLUMN_EXPR_TYPE = 'HIDDEN')
		)
		, PARENT_LOOKUP_Q AS (
			SELECT /*+ USE_MERGE(S E F) */
				DISTINCT S.COLUMN_NAME, S.IMP_COLUMN_NAME,
				F.COLUMN_NAME D_REF,
				E.COLUMN_NAME S_REF
			FROM (
				SELECT DISTINCT
					--+ INDEX(Q) USE_NL_WITH_INDEX(S)
					Q.TABLE_NAME, Q.VIEW_NAME, Q.SEARCH_KEY_COLS, Q.SHORT_NAME,
					Q.FOREIGN_KEY_COLS 	COLUMN_NAME,
                    Q.VIEW_NAME         S_VIEW_NAME,
                    Q.PARENT_KEY_COLUMN,
					Q.TABLE_ALIAS 		TABLE_ALIAS, 
					S.R_VIEW_NAME 		D_VIEW_NAME,
					S.IMP_COLUMN_NAME
				FROM MVDATA_BROWSER_F_REFS S, TABLE(data_browser_select.FN_Pipe_browser_q_refs(
					p_View_Name => S.VIEW_NAME,
					p_Data_Format => v_Data_Format,
					p_Include_Schema => 'NO'
				)) Q
				where Q.VIEW_NAME = S.VIEW_NAME
					and Q.FOREIGN_KEY_COLS = S.FOREIGN_KEY_COLS
					and Q.TABLE_ALIAS = S.TABLE_ALIAS
					and Q.J_VIEW_NAME = S.R_VIEW_NAME
					and Q.J_COLUMN_NAME = S.R_COLUMN_NAME
				and S.VIEW_NAME = v_Table_Name
			) S
			JOIN REFERENCES_Q E ON E.R_VIEW_NAME = S.S_VIEW_NAME AND E.COLUMN_NAME = S.PARENT_KEY_COLUMN
			JOIN REFERENCES_Q F ON F.R_VIEW_NAME = S.D_VIEW_NAME AND F.COLUMN_NAME = S.IMP_COLUMN_NAME
		)
		, FOREIGN_KEYS_LOOKUP_Q AS (
			SELECT T.VIEW_NAME TABLE_NAME, 
				 ---------------------------
				case when MAX(T.U_CONSTRAINT_NAME) IS NOT NULL or import_utl.Get_Search_Keys_Unique = 'NO' then
					case when IS_FILE_FOLDER_REF = 'N' then 
						RPAD(' ', 4) || 'if '
						|| LISTAGG(S_REF || ' IS NOT NULL',
							case when HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0 then data_browser_conf.NL(4) || 'OR ' else ' AND ' end
						) WITHIN GROUP (ORDER BY R_COLUMN_ID) -- conditions to trigger the search of foreign keys
						|| ' then ' || chr(10)
						|| case when D.DEFAULTS_MISSING = 0  AND import_utl.Get_Insert_Foreign_Keys = 'YES' 
							then RPAD(' ', 6) || 'begin' || chr(10) end
						|| RPAD(' ', 8) -- find foreign key values
						|| 'SELECT ' || T.TABLE_ALIAS || '.' || T.R_PRIMARY_KEY_COLS || ' INTO ' 
						|| D_REF || data_browser_conf.NL(8)
						|| 'FROM ' || T.R_VIEW_NAME || ' ' || T.TABLE_ALIAS || ' ' || data_browser_conf.NL(8)
						|| 'WHERE '
						|| LISTAGG(
								case when (HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0) AND T.U_MEMBERS > 1
								then '('
									|| import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, S_REF, T.R_DATA_TYPE)
									|| ' OR '
									|| case when T.R_NULLABLE = 'Y' then T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME || ' IS NULL AND ' end
									|| S_REF || ' IS NULL)'
								else
									import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, S_REF, T.R_DATA_TYPE)
								end,
							data_browser_conf.NL(8) || 'AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
						|| ';' 
					 ---------------------------
						|| data_browser_conf.NL(4)
						|| case when D.DEFAULTS_MISSING = 0 
						and import_utl.Get_Insert_Foreign_Keys = 'YES' then
							'  exception when NO_DATA_FOUND then' || data_browser_conf.NL(8)
							|| 'INSERT INTO ' || T.R_VIEW_NAME || '('
							|| LISTAGG(T.R_COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
							|| ')' || data_browser_conf.NL(8)
							|| 'VALUES ('
							|| LISTAGG(S_REF, ', ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
							|| ')' || data_browser_conf.NL(8)
							|| 'RETURNING (' || T.R_PRIMARY_KEY_COLS || ') INTO ' || D_REF || ';' || data_browser_conf.NL(4)
							|| '  end;' || data_browser_conf.NL(4)

						end
					else 
						RPAD(' ', 4) 
						|| 'if :new.' || MAX(T.S_COLUMN_NAME) || ' IS NOT NULL then ' || chr(10)
						|| RPAD(' ', 8) -- find path values
						|| data_browser_select.Key_Path_Lookup_Query (
							p_Table_Name  			=> T.R_VIEW_NAME,
							p_Search_Key_Col  		=> T.R_PRIMARY_KEY_COLS,
							p_Search_Path   		=> ':new.' || MAX(T.S_COLUMN_NAME),
							p_Search_Value   		=> T.D_REF,
							p_Folder_Par_Col_Name  	=> T.FOLDER_PARENT_COLUMN_NAME,
							p_Folder_Name_Col_Name  => T.FOLDER_NAME_COLUMN_NAME,
							p_Folder_Cont_Col_Name  => T.FOLDER_CONTAINER_COLUMN_NAME,
							p_Folder_Cont_Alias 	=> T.FOLDER_CONTAINER_REF,
							p_Level 				=> 0
						)
						|| ';' || data_browser_conf.NL(4)
					end 
					|| (
						select LISTAGG(
							RPAD(' ', 2)
							|| 'v_' || P.D_REF 
							|| ' := '
							|| T.D_REF || ';'
							|| data_browser_conf.NL(4)
							, ''
						) WITHIN GROUP (ORDER BY P.IMP_COLUMN_NAME)
						from PARENT_LOOKUP_Q P 
						where P.S_REF = T.D_COLUMN_NAME
						and P.D_REF IS NOT NULL
					)
				 ---------------------------
					|| 'end if;'
				end
				SQL_TEXT,
				---------------------------
				T.COLUMN_NAME,
				DBMS_ASSERT.ENQUOTE_LITERAL(LISTAGG(INITCAP(T.R_COLUMN_NAME), '/') WITHIN GROUP (ORDER BY R_COLUMN_ID)
				|| ' für ' || INITCAP(T.R_VIEW_NAME) || ' ist nicht vorhanden.')
				COLUMN_CHECK_EXPR,
				S.SHORT_NAME || '_IMP' FROM_CHECK_EXPR,
				' (' || LISTAGG('IMP.' || T.IMP_COLUMN_NAME || ' IS NOT NULL',
					case when HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0 then ' OR ' else ' AND ' end
				) WITHIN GROUP (ORDER BY R_COLUMN_ID) -- conditions to trigger the search of foreign keys
				|| ') ' || data_browser_conf.NL(8) || ' AND NOT EXISTS ( SELECT 1 FROM ' || T.R_VIEW_NAME || ' ' || T.TABLE_ALIAS || ' '
				|| data_browser_conf.NL(12)
				|| 'WHERE '
				|| LISTAGG(
						case when (HAS_NULLABLE > 0 OR HAS_SIMPLE_UNIQUE > 0) AND T.U_MEMBERS > 1
						then '(' || import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, 'IMP.' || T.IMP_COLUMN_NAME, T.R_DATA_TYPE)
							|| ' OR '
							|| case when T.R_NULLABLE = 'Y' then T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME || ' IS NULL AND ' end
							|| 'IMP.' || T.IMP_COLUMN_NAME || ' IS NULL)'
						else
							import_utl.Get_Compare_Case_Insensitive(T.TABLE_ALIAS || '.' || T.R_COLUMN_NAME, 'IMP.' || T.IMP_COLUMN_NAME, T.R_DATA_TYPE)
						end,
					data_browser_conf.NL(12) || 'AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
				|| data_browser_conf.NL(8) || ' )'
				WHERE_CHECK_EXPR,
				case when T.NULLABLE = 'N' then
					'''' || LISTAGG(INITCAP(T.R_COLUMN_NAME), '/') WITHIN GROUP (ORDER BY R_COLUMN_ID)
					|| case when T.U_MEMBERS = 1 then ' ist ' else ' sind ' end || 'leer.'''
				end COLUMN_CHECK_EXPR2,
				case when T.NULLABLE = 'N' then
					LISTAGG('IMP.' || T.IMP_COLUMN_NAME || ' IS NULL', ' AND ') WITHIN GROUP (ORDER BY R_COLUMN_ID)
				end WHERE_CHECK_EXPR2,
				'R' CHECK_CONSTRAINT_TYPE,
				---------------------------
				D.DEFAULTS_MISSING + case when MAX(T.U_CONSTRAINT_NAME) IS NOT NULL or import_utl.Get_Search_Keys_Unique = 'NO' then 0 else 1 end DEFAULTS_MISSING,
				T.COLUMN_ID POSITION, POSITION2, T.R_VIEW_NAME,
				SUM(HAS_FOREIGN_KEY) S_HAS_FOREIGN_KEY
			FROM
			(
				SELECT /*+ USE_MERGE(S E F) */
					S.*, 
					E.IMP_COLUMN_NAME S_COLUMN_NAME,
					'v_' || FC.IMP_COLUMN_NAME FOLDER_CONTAINER_REF
				FROM (
					-- 2. level foreign keys
					SELECT 	VIEW_NAME, TABLE_NAME, SEARCH_KEY_COLS, SHORT_NAME, COLUMN_NAME, 
						S_VIEW_NAME, case when HAS_FOREIGN_KEY = 0 then ':new.' else 'v_' end || S_REF S_REF, 
						D_VIEW_NAME, 'v_' || D_REF D_REF, 
						D_COLUMN_NAME, 
						IS_FILE_FOLDER_REF, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME, 
						R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, COLUMN_ID, NULLABLE, 
						R_COLUMN_ID, R_COLUMN_NAME, R_NULLABLE, R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, 
						R_CHAR_LENGTH, TABLE_ALIAS, IMP_COLUMN_NAME, JOIN_CLAUSE, HAS_NULLABLE, HAS_SIMPLE_UNIQUE, 
						HAS_FOREIGN_KEY, U_CONSTRAINT_NAME, U_MEMBERS, POSITION2		
					FROM TABLE(data_browser_select.FN_Pipe_table_imp_fk2 (v_Table_Name, import_utl.Get_As_Of_Timestamp, p_Data_Format))
					UNION ALL
					-- 1. level foreign keys
					SELECT VIEW_NAME, TABLE_NAME, SEARCH_KEY_COLS, SHORT_NAME, COLUMN_NAME, 
						S_VIEW_NAME, 
						case when HAS_FOREIGN_KEY = 0 then ':new.' else 'v_' end || S_REF S_REF,
						D_VIEW_NAME, 'v_row.' || D_REF D_REF, 
						D_COLUMN_NAME, 
						IS_FILE_FOLDER_REF, FOLDER_PARENT_COLUMN_NAME, FOLDER_NAME_COLUMN_NAME, FOLDER_CONTAINER_COLUMN_NAME, 
						R_PRIMARY_KEY_COLS, R_CONSTRAINT_TYPE, R_VIEW_NAME, COLUMN_ID, NULLABLE, 
						R_COLUMN_ID, R_COLUMN_NAME, R_NULLABLE, R_DATA_TYPE, R_DATA_PRECISION, R_DATA_SCALE, 
						R_CHAR_LENGTH, TABLE_ALIAS, IMP_COLUMN_NAME, JOIN_CLAUSE, HAS_NULLABLE, HAS_SIMPLE_UNIQUE, 
						HAS_FOREIGN_KEY, U_CONSTRAINT_NAME, U_MEMBERS, POSITION2
					FROM TABLE(data_browser_select.FN_Pipe_table_imp_fk1 (v_Table_Name)) S
				) S
				JOIN REFERENCES_Q E ON E.R_VIEW_NAME = S.S_VIEW_NAME AND E.REF_COLUMN_NAME = S.R_COLUMN_NAME 
					AND (E.TABLE_ALIAS = S.TABLE_ALIAS OR E.TABLE_ALIAS IS NULL)
					AND (E.REF_COLUMN_NAME != S.FOLDER_CONTAINER_COLUMN_NAME OR S.FOLDER_CONTAINER_COLUMN_NAME IS NULL)
				JOIN REFERENCES_Q F ON F.R_VIEW_NAME = S.D_VIEW_NAME AND F.COLUMN_NAME = S.D_COLUMN_NAME
				LEFT OUTER JOIN REFERENCES_Q FC ON FC.R_VIEW_NAME = S.S_VIEW_NAME AND FC.REF_COLUMN_NAME = S.FOLDER_CONTAINER_COLUMN_NAME
			) T
			JOIN MVDATA_BROWSER_VIEWS S ON S.VIEW_NAME = T.VIEW_NAME
			JOIN ( -- count of missing defaults for foreign key table
				SELECT S.VIEW_NAME, COUNT(DISTINCT C.COLUMN_ID) DEFAULTS_MISSING
				FROM MVDATA_BROWSER_VIEWS S -- foreign key table
				LEFT OUTER JOIN MVDATA_BROWSER_SIMPLE_COLS C 
				ON S.TABLE_NAME = C.TABLE_NAME AND S.TABLE_OWNER = C.TABLE_OWNER
				AND C.NULLABLE = 'N' AND C.HAS_DEFAULT = 'N'
				AND  NOT EXISTS (
					SELECT 'X'
					FROM  TABLE( apex_string.split(S.SEARCH_KEY_COLS, ', ') ) P
					WHERE C.COLUMN_NAME = P.COLUMN_VALUE
				)
				AND NOT EXISTS (
					SELECT 1
					FROM MVDATA_BROWSER_D_REFS R
					WHERE R.TABLE_NAME = S.VIEW_NAME
					AND R.COLUMN_NAME = C.COLUMN_NAME
					UNION ALL
					SELECT 1
					FROM MVDATA_BROWSER_U_REFS R
					WHERE R.VIEW_NAME = S.VIEW_NAME
					AND R.COLUMN_NAME = C.COLUMN_NAME
					AND R.RANK = 1
				)
				GROUP BY S.VIEW_NAME
			) D ON D.VIEW_NAME = T.R_VIEW_NAME
			WHERE R_COLUMN_ID IS NOT NULL
			GROUP BY T.TABLE_NAME, T.VIEW_NAME, 
				D.DEFAULTS_MISSING, T.TABLE_ALIAS, T.R_PRIMARY_KEY_COLS, T.COLUMN_NAME,
				T.R_VIEW_NAME, T.COLUMN_ID, S.SHORT_NAME,
				T.HAS_NULLABLE, T.HAS_SIMPLE_UNIQUE, T.U_MEMBERS, 
				T.NULLABLE, T.D_REF, T.D_COLUMN_NAME, T.POSITION2,
				T.IS_FILE_FOLDER_REF, T.FOLDER_PARENT_COLUMN_NAME, T.FOLDER_NAME_COLUMN_NAME, 
				T.FOLDER_CONTAINER_COLUMN_NAME, T.FOLDER_CONTAINER_REF
			HAVING (MAX(T.U_CONSTRAINT_NAME) IS NOT NULL or import_utl.Get_Search_Keys_Unique = 'NO')
			ORDER BY SUM(HAS_FOREIGN_KEY), T.TABLE_ALIAS DESC, T.U_MEMBERS, T.COLUMN_ID, T.POSITION2, T.D_REF
		) 
		SELECT SQL_TEXT,
			case when B.COLUMN_CHECK_EXPR IS NOT NULL then
				'SELECT IMP.IMPORTJOB_ID$, IMP.LINK_ID$, IMP.LINE_NO$, '
				|| DBMS_ASSERT.ENQUOTE_LITERAL(B.COLUMN_NAME) || ' COLUMN_NAME, '
				|| B.COLUMN_CHECK_EXPR || ' MESSAGE, '
				|| DBMS_ASSERT.ENQUOTE_LITERAL(
					case when CHECK_CONSTRAINT_TYPE = 'R' and DEFAULTS_MISSING = 0
						then 'R+'
						else CHECK_CONSTRAINT_TYPE end) || ' CONSTRAINT_TYPE'
				|| data_browser_conf.NL(4)
				|| 'FROM ' || B.FROM_CHECK_EXPR || ' IMP '
				|| case when B.WHERE_CHECK_EXPR IS NOT NULL
					then data_browser_conf.NL(4)
					|| 'WHERE ' || B.WHERE_CHECK_EXPR end
			end
			|| case when B.COLUMN_CHECK_EXPR2 IS NOT NULL then
				data_browser_conf.NL(4) || 'UNION ALL' || data_browser_conf.NL(4)
				|| 'SELECT IMP.IMPORTJOB_ID$, IMP.LINK_ID$, IMP.LINE_NO$, '
				|| DBMS_ASSERT.ENQUOTE_LITERAL(B.COLUMN_NAME) || ' COLUMN_NAME, '
				|| B.COLUMN_CHECK_EXPR2 || ' MESSAGE, '
				|| DBMS_ASSERT.ENQUOTE_LITERAL('T') || ' CONSTRAINT_TYPE'
				|| data_browser_conf.NL(4)
				|| 'FROM ' || B.FROM_CHECK_EXPR || ' IMP ' || data_browser_conf.NL(4)
				|| 'WHERE ' || B.WHERE_CHECK_EXPR2
			end SQL_EXISTS,
			case when B.CHECK_CONSTRAINT_TYPE = 'T' and B.COLUMN_CHECK_EXPR IS NOT NULL
				then B.COLUMN_CHECK_EXPR
			when B.CHECK_CONSTRAINT_TYPE = 'R' and B.COLUMN_CHECK_EXPR IS NOT NULL
				then '(SELECT ' || B.COLUMN_CHECK_EXPR || ' MESSAGE' || data_browser_conf.NL(8)
				|| ' FROM DUAL ' || data_browser_conf.NL(8)
				|| ' WHERE ' || B.WHERE_CHECK_EXPR || ')'
				|| case when B.COLUMN_CHECK_EXPR2 IS NOT NULL
					then
						' || ' || data_browser_conf.NL(8)
						|| '(SELECT ' || B.COLUMN_CHECK_EXPR2 || ' MESSAGE' || data_browser_conf.NL(8)
						|| ' FROM DUAL ' || data_browser_conf.NL(8)
						|| ' WHERE ' || B.WHERE_CHECK_EXPR2 || data_browser_conf.NL(8) || ' )'
					end
			end
			SQL_EXISTS2,
			B.CHECK_CONSTRAINT_TYPE,
			B.DEFAULTS_MISSING, B.TABLE_NAME, B.COLUMN_NAME, B.POSITION, B.POSITION2, B.R_VIEW_NAME
		FROM ( -- select column list of target table
			SELECT S.VIEW_NAME TABLE_NAME, 
				'    v_row.' || RPAD(T.COLUMN_NAME, 32) || ' := '
				|| case when T.COLUMN_NAME != S.SEARCH_KEY_COLS
						then -- import_utl.Get_ImportColFunction(T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, ':new.' || T.COLUMN_NAME)
							case when v_Data_Format = 'NATIVE' then 
								':new.' || T.COLUMN_NAME
							else 
								data_browser_conf.Get_Char_to_Type_Expr(
									p_Element => ':new.' || T.COLUMN_NAME, 
									p_Data_Type => T.DATA_TYPE, 
									p_Data_Scale => T.DATA_SCALE, 
									p_Format_Mask => data_browser_conf.Get_Col_Format_Mask(
										p_Data_Type 		=> T.DATA_TYPE,
										p_Data_Precision 	=> T.DATA_PRECISION,
										p_Data_Scale 		=> T.DATA_SCALE,
										p_Char_Length 		=> T.CHAR_LENGTH,
										p_Use_Group_Separator => v_Use_Group_Separator,
										p_Datetime  		=> T.IS_DATETIME
									), 
									p_Use_Group_Separator => v_Use_Group_Separator,
									p_use_NLS_params => v_use_NLS_params
								)
							end
						else ':new.' || 'LINK_ID$'
					end
				|| ';' SQL_TEXT,
				---------------------------
				T.COLUMN_NAME,
				case when T.COLUMN_NAME != S.SEARCH_KEY_COLS then
					import_utl.Get_ImpColumnCheck (T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, T.NULLABLE, T.COLUMN_NAME)
				end COLUMN_CHECK_EXPR,
				S.SHORT_NAME || '_IMP' FROM_CHECK_EXPR,
				NULL WHERE_CHECK_EXPR,
				NULL COLUMN_CHECK_EXPR2,
				NULL WHERE_CHECK_EXPR2,
				'T' CHECK_CONSTRAINT_TYPE,
				---------------------------
				0 DEFAULTS_MISSING, T.COLUMN_ID POSITION, 1 POSITION2, NULL R_VIEW_NAME
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) T
			JOIN MVDATA_BROWSER_VIEWS S ON S.TABLE_NAME = T.TABLE_NAME
			WHERE import_utl.Get_ImpColumnCheck (T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, T.NULLABLE, T.COLUMN_NAME) IS NOT NULL
			AND T.IS_VIRTUAL_COLUMN = 'N'
			AND T.TABLE_ALIAS = 'A'
			AND T.COLUMN_EXPR_TYPE != 'LINK_ID'
			AND NOT EXISTS (-- no foreign key columns
				SELECT 1 
				FROM MVDATA_BROWSER_FKEYS FK
				WHERE FK.VIEW_NAME = S.VIEW_NAME
				AND FK.FOREIGN_KEY_COLS = T.COLUMN_NAME
			)
			AND S.TABLE_NAME = v_Table_Name
			UNION ALL -- process foreign_keys of target table
			SELECT TABLE_NAME, SQL_TEXT, COLUMN_NAME, COLUMN_CHECK_EXPR, FROM_CHECK_EXPR, 
				WHERE_CHECK_EXPR, COLUMN_CHECK_EXPR2, WHERE_CHECK_EXPR2, 
				CHECK_CONSTRAINT_TYPE, DEFAULTS_MISSING, POSITION, POSITION2, R_VIEW_NAME
			FROM FOREIGN_KEYS_LOOKUP_Q 
			WHERE S_HAS_FOREIGN_KEY = 0 
			UNION ALL -- process foreign_keys of target table
			SELECT TABLE_NAME, SQL_TEXT, COLUMN_NAME, COLUMN_CHECK_EXPR, FROM_CHECK_EXPR, 
				WHERE_CHECK_EXPR, COLUMN_CHECK_EXPR2, WHERE_CHECK_EXPR2, 
				CHECK_CONSTRAINT_TYPE, DEFAULTS_MISSING, POSITION, POSITION2, R_VIEW_NAME
			FROM FOREIGN_KEYS_LOOKUP_Q 
			WHERE S_HAS_FOREIGN_KEY > 0 
			
			UNION ALL -- process check constraints
			SELECT S.VIEW_NAME TABLE_NAME, 
				NULL SQL_TEXT,
			   ---------------------------
				MIN(B.COLUMN_NAME) COLUMN_NAME,
				DBMS_ASSERT.ENQUOTE_LITERAL('Regelverletzung für ' || REPLACE(A.SEARCH_CONDITION, CHR(39))) COLUMN_CHECK_EXPR,
				'(SELECT IMPORTJOB_ID$, LINE_NO$, LINK_ID$, '
				|| LISTAGG(
					-- import_utl.Get_ImportColFunction(T.DATA_TYPE, T.DATA_SCALE, T.CHAR_LENGTH, T.COLUMN_NAME)
					data_browser_conf.Get_Char_to_Type_Expr(
						p_Element => T.COLUMN_NAME, 
						p_Data_Type => T.DATA_TYPE, 
						p_Data_Scale => T.DATA_SCALE, 
						p_Format_Mask => data_browser_conf.Get_Col_Format_Mask(
							p_Data_Type 		=> T.DATA_TYPE,
							p_Data_Precision 	=> T.DATA_PRECISION,
							p_Data_Scale 		=> T.DATA_SCALE,
							p_Char_Length 		=> T.CHAR_LENGTH,
							p_Use_Group_Separator => v_Use_Group_Separator,
							p_Datetime  		=> T.IS_DATETIME
						), 
						p_Use_Group_Separator => v_Use_Group_Separator,
						p_use_NLS_params => v_use_NLS_params
					)
					|| ' ' || T.COLUMN_NAME, ', ')
					WITHIN GROUP (ORDER BY T.COLUMN_ID) || chr(10)
				|| '    FROM '
				|| S.SHORT_NAME || '_IMP)'  FROM_CHECK_EXPR,
				'NOT (' || A.SEARCH_CONDITION || ')' 			WHERE_CHECK_EXPR,
				NULL COLUMN_CHECK_EXPR2,
				NULL WHERE_CHECK_EXPR2,
				'C' CHECK_CONSTRAINT_TYPE,
				---------------------------
				0 DEFAULTS_MISSING, 1000 POSITION, 1 POSITION2, NULL R_VIEW_NAME
			FROM MVDATA_BROWSER_VIEWS S
			JOIN (
				SELECT TABLE_NAME, OWNER, CONSTRAINT_NAME, SEARCH_CONDITION
				FROM TABLE(data_browser_conf.Constraint_Condition_Cursor(p_Owner => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')))
			) A ON A.TABLE_NAME = S.TABLE_NAME
			JOIN SYS.USER_CONS_COLUMNS B ON A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND A.TABLE_NAME = B.TABLE_NAME AND A.OWNER = B.OWNER
			--JOIN SYS.USER_TAB_COLUMNS T ON A.TABLE_NAME = T.TABLE_NAME AND B.COLUMN_NAME = T.COLUMN_NAME
			JOIN TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) T ON A.TABLE_NAME = T.TABLE_NAME AND B.COLUMN_NAME = T.COLUMN_NAME
			AND NOT EXISTS (-- no foreign key columns
				SELECT 1 
				FROM MVDATA_BROWSER_FKEYS FK
				WHERE FK.VIEW_NAME = S.VIEW_NAME
				AND FK.FOREIGN_KEY_COLS = T.COLUMN_NAME
			)
			AND A.SEARCH_CONDITION NOT IN( DBMS_ASSERT.ENQUOTE_NAME(B.COLUMN_NAME) || ' IS NOT NULL', B.COLUMN_NAME || ' IS NOT NULL') -- filter NOT NULL checks
			AND S.TABLE_NAME = v_Table_Name
			GROUP BY S.VIEW_NAME, A.CONSTRAINT_NAME, A.SEARCH_CONDITION, S.SHORT_NAME
		) B;
        v_in_row rec_table_imp_trigger;
	BEGIN
		OPEN views_cur(p_Table_Name, p_Data_Format);
		LOOP
			FETCH views_cur INTO v_in_row;
			EXIT WHEN views_cur%NOTFOUND;
			pipe row (v_in_row);
		END LOOP;
		CLOSE views_cur;
	end FN_Pipe_table_imp_trigger;

	FUNCTION FN_Pipe_table_imp_link (p_Table_Name VARCHAR2)
	RETURN tab_table_imp_link PIPELINED
	IS
        CURSOR views_cur (v_Table_Name VARCHAR2)
        IS
		-- process unique constraints
		SELECT S.VIEW_NAME TABLE_NAME, 
			U.U_CONSTRAINT_NAME,
			'UPDATE ' || S.SHORT_NAME || '_IMP IMP ' || data_browser_conf.NL(4)
			|| 'SET LINK_ID$ = ( SELECT '
			|| data_browser_conf.Get_Unique_Key_Expression (
				p_Unique_Key_Column => S.SEARCH_KEY_COLS,
				p_Table_Alias => 'A',
				p_View_Mode => 'IMPORT_VIEW'
			)
			|| data_browser_conf.NL(8) || 'FROM ' || S.VIEW_NAME || ' A '
			|| LISTAGG (
					case when F.FOREIGN_KEY_COLS IS NOT NULL then
						case when F.NULLABLE = 'Y' then 'LEFT OUTER ' end || 'JOIN '
						|| F.R_VIEW_NAME || ' ' || F.TABLE_ALIAS
						|| ' ON ' 
						|| data_browser_conf.Get_Join_Expression(
							p_Left_Columns=>F.R_PRIMARY_KEY_COLS, p_Left_Alias=> F.TABLE_ALIAS,
							p_Right_Columns=>F.FOREIGN_KEY_COLS, p_Right_Alias=> 'A')
					end
				, data_browser_conf.NL(8)) WITHIN GROUP (ORDER BY F.R_COLUMN_ID)
			|| data_browser_conf.NL(8) || 'WHERE '
			|| LISTAGG (
				case when F.FOREIGN_KEY_COLS IS NOT NULL then
					import_utl.Get_Compare_Case_Insensitive(F.TABLE_ALIAS || '.' || F.R_COLUMN_NAME, 'IMP.' || F.IMP_COLUMN_NAME, F.R_DATA_TYPE)
				else
					import_utl.Get_Compare_Case_Insensitive('A.' || U.COLUMN_NAME, 'IMP.' || U.COLUMN_NAME, U.DATA_TYPE)
				end,
				data_browser_conf.NL(8) || 'AND ') WITHIN GROUP (ORDER BY U.POSITION, F.R_COLUMN_ID)
			|| data_browser_conf.NL(4) || ' )' || data_browser_conf.NL(4)
			|| 'WHERE ('
			|| LISTAGG ( 'IMP.' || NVL(F.IMP_COLUMN_NAME, U.COLUMN_NAME) || ' IS NOT NULL',
					case when U.HAS_NULLABLE > 0 then ' OR ' else ' AND ' end
				) WITHIN GROUP (ORDER BY U.POSITION, F.R_COLUMN_ID) -- conditions to trigger the search of foreign keys
			|| ') ' || data_browser_conf.NL(4) || 'AND IMP.LINK_ID$ IS NULL '
			SQL_TEXT
		FROM MVDATA_BROWSER_VIEWS S
		JOIN USER_TABLES T ON T.TABLE_NAME = S.SHORT_NAME || '_IMP'
		JOIN MVDATA_BROWSER_U_REFS U ON U.VIEW_NAME = S.VIEW_NAME AND U.RANK = 1 -- check all unique keys
		LEFT OUTER JOIN MVDATA_BROWSER_F_REFS F ON F.TABLE_NAME = S.VIEW_NAME AND F.FOREIGN_KEY_COLS = U.COLUMN_NAME AND F.R_COLUMN_ID IS NOT NULL
		WHERE S.VIEW_NAME = p_Table_Name
		GROUP BY S.VIEW_NAME, S.SHORT_NAME, S.SEARCH_KEY_COLS, S.HAS_SCALAR_PRIMARY_KEY, U.HAS_NULLABLE, U.U_CONSTRAINT_NAME
		;
        v_in_row rec_table_imp_link;
	BEGIN
		OPEN views_cur(p_Table_Name);
		LOOP
			FETCH views_cur INTO v_in_row;
			EXIT WHEN views_cur%NOTFOUND;
			pipe row (v_in_row);
		END LOOP;
		CLOSE views_cur;
	end FN_Pipe_table_imp_link;


    PROCEDURE Set_Imp_Formats (
        p_Export_Text_Limit         INTEGER     DEFAULT NULL,	-- length limit for Text in each column
        p_Import_Currency_Format    VARCHAR2    DEFAULT NULL,	-- Import Currency Format Mask
        p_Import_Number_Format      VARCHAR2    DEFAULT NULL,	-- Import Number Format Mask
        p_Import_NumChars       	VARCHAR2    DEFAULT NULL,	-- Import NumChars Format Mask
        p_Import_Float_Format   	VARCHAR2    DEFAULT NULL,	-- Import Float Format Mask
        p_Export_Date_Format      	VARCHAR2    DEFAULT NULL,	-- Export Date Format Mask
        p_Import_DateTime_Format    VARCHAR2    DEFAULT NULL,	-- Import DateTime Format Mask
        p_Import_Timestamp_Format   VARCHAR2    DEFAULT NULL,	-- Import Timestamp Format Mask
		p_Insert_Foreign_Keys   	VARCHAR2    DEFAULT NULL,   -- insert new foreign key values in insert trigger
		p_Search_Keys_Unique	  	VARCHAR2    DEFAULT NULL,   -- Unique Constraint is required for searching foreign key values
		p_Exclude_Blob_Columns  	VARCHAR2    DEFAULT NULL,	-- Exclude Blob Columns from generated Views
		p_Compare_Case_Insensitive 	VARCHAR2 	DEFAULT NULL,   -- compare Case insensitive foreign key values in insert trigger
		p_Compare_Return_String 	VARCHAR2 	DEFAULT NULL,	-- 'Differenz gefunden.'
		p_Compare_Return_Style  	VARCHAR2    DEFAULT NULL,	-- CSS style for marking differences
		p_Compare_Return_Style2  	VARCHAR2    DEFAULT NULL,	-- CSS style for marking differences
		p_Compare_Return_Style3  	VARCHAR2    DEFAULT NULL,	-- CSS style for marking differences
		p_Errors_Return_Style 		VARCHAR2    DEFAULT NULL,	-- CSS style for marking errors
		p_Error_is_empty			VARCHAR2    DEFAULT NULL,	-- 'ist leer.'
		p_Error_is_longer_than		VARCHAR2    DEFAULT NULL,	-- '... Zeichenkette ist länger als'
		p_Error_is_no_currency		VARCHAR2    DEFAULT NULL,	-- 'ist kein Währungsbetrag.'
		p_Error_is_no_float			VARCHAR2    DEFAULT NULL,	-- 'ist keine Gleitkommazahl.'
		p_Error_is_no_integer		VARCHAR2    DEFAULT NULL,	-- 'ist keine Integerzahl.'
		p_Error_is_no_date			VARCHAR2    DEFAULT NULL,	-- 'ist keine gültiges Datum.'
		p_Error_is_no_timestamp		VARCHAR2    DEFAULT NULL	-- 'ist kein gültiger Timestamp.'
    )
    IS
    BEGIN
        g_Export_Text_Limit      	:= NVL(p_Export_Text_Limit, g_Export_Text_Limit);
        g_Import_Currency_Format 	:= NVL(p_Import_Currency_Format, g_Import_Currency_Format);
        g_Import_Number_Format  	:= NVL(p_Import_Number_Format, g_Import_Number_Format);
        g_Import_NumChars   		:= NVL(p_Import_NumChars, g_Import_NumChars);
        g_Import_Float_Format    	:= NVL(p_Import_Float_Format, g_Import_Float_Format);
        g_Export_Date_Format  		:= NVL(p_Export_Date_Format, g_Export_Date_Format);
        g_Import_DateTime_Format 	:= NVL(p_Import_DateTime_Format, g_Import_DateTime_Format);
        g_Import_Timestamp_Format	:= NVL(p_Import_Timestamp_Format, g_Import_Timestamp_Format);
        g_Insert_Foreign_Keys		:= NVL(p_Insert_Foreign_Keys, g_Insert_Foreign_Keys);
        g_Search_Keys_Unique		:= NVL(p_Search_Keys_Unique, g_Search_Keys_Unique);
        g_Exclude_Blob_Columns		:= NVL(p_Exclude_Blob_Columns, g_Exclude_Blob_Columns);
        g_Compare_Case_Insensitive	:= NVL(p_Compare_Case_Insensitive, g_Compare_Case_Insensitive);
        g_Compare_Return_String		:= NVL(p_Compare_Return_String, g_Compare_Return_String);
        g_Compare_Return_Style		:= NVL(p_Compare_Return_Style, g_Compare_Return_Style);
        g_Compare_Return_Style2		:= NVL(p_Compare_Return_Style2, g_Compare_Return_Style2);
        g_Compare_Return_Style3		:= NVL(p_Compare_Return_Style3, g_Compare_Return_Style3);
        g_Errors_Return_Style		:= NVL(p_Errors_Return_Style, g_Errors_Return_Style);
        g_Error_is_empty			:= NVL(p_Error_is_empty, g_Error_is_empty);
        g_Error_is_longer_than		:= NVL(p_Error_is_longer_than, g_Error_is_longer_than);
        g_Error_is_no_currency		:= NVL(p_Error_is_no_currency, g_Error_is_no_currency);
        g_Error_is_no_float			:= NVL(p_Error_is_no_float, g_Error_is_no_float);
        g_Error_is_no_integer		:= NVL(p_Error_is_no_integer, g_Error_is_no_integer);
        g_Error_is_no_date			:= NVL(p_Error_is_no_date, g_Error_is_no_date);
        g_Error_is_no_timestamp		:= NVL(p_Error_is_no_timestamp, g_Error_is_no_timestamp);
    END;

    PROCEDURE Load_Imp_Job_Formats (p_Importjob_ID INTEGER)
    IS
    BEGIN
        g_Importjob_ID := p_Importjob_ID;

    	SELECT EXPORT_TEXT_LIMIT, IMPORT_CURRENCY_FORMAT, IMPORT_NUMBER_FORMAT, IMPORT_NUMCHARS, IMPORT_FLOAT_FORMAT,
    		EXPORT_DATE_FORMAT, IMPORT_DATETIME_FORMAT, IMPORT_TIMESTAMP_FORMAT, INSERT_FOREIGN_KEYS,
    		SEARCH_KEYS_UNIQUE, EXCLUDE_BLOB_COLUMNS, COMPARE_CASE_INSENSITIVE, COMPARE_RETURN_STRING,
    		COMPARE_RETURN_STYLE, COMPARE_RETURN_STYLE2, COMPARE_RETURN_STYLE3,
    		ERRORS_RETURN_STYLE, ERROR_IS_EMPTY, ERROR_IS_LONGER_THAN, ERROR_IS_NO_CURRENCY, ERROR_IS_NO_FLOAT,
    		ERROR_IS_NO_INTEGER, ERROR_IS_NO_DATE, ERROR_IS_NO_TIMESTAMP
    	INTO g_Export_Text_Limit, g_Import_Currency_Format, g_Import_Number_Format, g_Import_NumChars, g_Import_Float_Format,
    		g_Export_Date_Format, g_Import_DateTime_Format, g_Import_Timestamp_Format, g_Insert_Foreign_Keys,
    		g_Search_Keys_Unique, g_Exclude_Blob_Columns, g_Compare_Case_Insensitive, g_Compare_Return_String,
    		g_Compare_Return_Style, g_Compare_Return_Style2, g_Compare_Return_Style3,
    		g_Errors_Return_Style, g_Error_is_empty, g_Error_is_longer_than, g_Error_is_no_currency, g_Error_is_no_float,
    		g_Error_is_no_integer, g_Error_is_no_date, g_Error_is_no_timestamp
    	FROM USER_IMPORT_JOBS
		WHERE IMPORTJOB_ID$ = p_Importjob_ID;
    END;

    FUNCTION Get_ImpTextLimit  RETURN INTEGER IS BEGIN RETURN g_Export_Text_Limit; END;
    FUNCTION Get_Import_Currency_Format RETURN VARCHAR2 IS BEGIN RETURN g_Import_Currency_Format; END;
    FUNCTION Get_Import_NumChars RETURN VARCHAR2 IS BEGIN RETURN 'q''[' || g_Import_NumChars || ']'''; END;

    FUNCTION Get_Import_Float_Format RETURN VARCHAR2 IS BEGIN RETURN g_Import_Float_Format; END;
    FUNCTION Get_Import_Date_Format RETURN VARCHAR2 IS BEGIN RETURN g_Export_Date_Format; END;
    FUNCTION Get_Import_Timestamp_Format RETURN VARCHAR2 IS BEGIN RETURN g_Import_Timestamp_Format; END;

    FUNCTION Get_Insert_Foreign_Keys RETURN VARCHAR2 IS BEGIN RETURN g_Insert_Foreign_Keys; END;
    FUNCTION Get_Search_Keys_Unique RETURN VARCHAR2 IS BEGIN RETURN g_Search_Keys_Unique; END;
    FUNCTION Get_Exclude_Blob_Columns RETURN VARCHAR2 IS BEGIN RETURN g_Exclude_Blob_Columns; END;
	PROCEDURE Set_As_Of_Timestamp (p_As_Of_Timestamp VARCHAR2) IS BEGIN g_As_Of_Timestamp := p_As_Of_Timestamp; END;
	FUNCTION Get_As_Of_Timestamp RETURN VARCHAR2 IS BEGIN RETURN g_As_Of_Timestamp; END;

	FUNCTION Get_Error_is_empty RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_empty || ' '; END;
	FUNCTION Get_Error_is_longer_than RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_longer_than || ' '; END;
	FUNCTION Get_Error_is_no_currency RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_no_currency || ' '; END;
	FUNCTION Get_Error_is_no_float RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_no_float || ' '; END;
	FUNCTION Get_Error_is_no_integer RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_no_integer || ' '; END;
	FUNCTION Get_Error_is_no_date RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_no_date || ' '; END;
	FUNCTION Get_Error_is_no_timestamp RETURN VARCHAR2 IS BEGIN RETURN ' ' || g_Error_is_no_timestamp || ' '; END;

    FUNCTION Get_Compare_Case_Insensitive (
        p_Column_Name VARCHAR2,
        p_Search_Name VARCHAR2,
        p_DATA_TYPE VARCHAR2 DEFAULT 'VARCHAR2')
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN case when g_Compare_Case_Insensitive = 'YES' and p_DATA_TYPE IN ('CHAR', 'VARCHAR2', 'NVARCHAR2', 'CLOB', 'NCLOB')
            then 'UPPER(' || p_Column_Name || ') = UPPER(' || p_Search_Name || ')'
            else p_Column_Name || ' = ' || p_Search_Name
            end;
    END;

	-----------------------------------

    FUNCTION Compare_Data ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
		if NVL(p_Bevore, CHR(1)) != NVL(p_After, CHR(1)) then
			return g_Compare_Return_String;
		end if;
		return NULL;
    END;

    FUNCTION Compare_Upper ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
		if NVL(UPPER(p_Bevore), CHR(1)) != NVL(UPPER(p_After), CHR(1)) then
			return g_Compare_Return_String;
		end if;
		return NULL;
    END;

    FUNCTION Compare_Number ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if TO_NUMBER(p_Bevore, g_Import_Number_Format, g_Import_NumChars) != TO_NUMBER(p_After, g_Import_Number_Format, g_Import_NumChars)
    	or p_Bevore IS NOT NULL and p_After IS NULL
    	or p_Bevore IS NULL and p_After IS NOT NULL then
			return g_Compare_Return_String;
		end if;
		return NULL;
    EXCEPTION WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR (-20001, 'import_utl.Compare_Number (' || p_Bevore || ', ' || p_After || ') - failed with ' || SQLERRM);
    END;

    FUNCTION Compare_Date ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if TO_DATE(p_Bevore, g_Import_DateTime_Format) != TO_DATE(p_After, g_Import_DateTime_Format)
    	or p_Bevore IS NOT NULL and p_After IS NULL
    	or p_Bevore IS NULL and p_After IS NOT NULL then
			return g_Compare_Return_String;
		end if;
		return NULL;
    END;

    FUNCTION Compare_Timestamp ( p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if TO_TIMESTAMP(p_Bevore, g_Import_Timestamp_Format) != TO_TIMESTAMP(p_After, g_Import_Timestamp_Format)
    	or p_Bevore IS NOT NULL and p_After IS NULL
    	or p_Bevore IS NULL and p_After IS NOT NULL then
			return g_Compare_Return_String;
		end if;
		return NULL;
    END;

    FUNCTION Get_CompareFunction( p_DATA_TYPE VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN CASE
        when p_DATA_TYPE = 'NUMBER' then
            'import_utl.Compare_Number'
        when p_DATA_TYPE = 'RAW' then
            'import_utl.Compare_Data'
        when p_DATA_TYPE = 'FLOAT' then
            'import_utl.Compare_Number'
        when p_DATA_TYPE = 'DATE' then
            'import_utl.Compare_Date'
        when p_DATA_TYPE LIKE 'TIMESTAMP%' then
            'import_utl.Compare_Timestamp'
        when p_DATA_TYPE IN ('CHAR', 'VARCHAR', 'VARCHAR2', 'CLOB', 'NCLOB') and g_Compare_Case_Insensitive = 'YES' then
        	'import_utl.Compare_Upper'
        else
            'import_utl.Compare_Data'
        end;
    END;

	-----------------------------------
	FUNCTION Style_Data (p_Bevore VARCHAR2, p_After VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
		return case when p_Bevore IS NOT NULL and p_After IS NOT NULL then
				'<div style="'
				|| g_Compare_Return_Style || '">'
				|| p_Bevore  || '</div>'
				|| '<div style="'
				|| g_Compare_Return_Style2 || '">'
				|| p_After || '</div>'
			when p_Bevore IS NULL and p_After IS NOT NULL then
				'<div style="'
				|| g_Compare_Return_Style2 || '">'
				|| p_After || '</div>'
			else
				'<div style="'
				|| g_Compare_Return_Style3 || '">'
				|| p_Bevore  || '</div>'
		end;
    END;

    FUNCTION Markup_Data (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if p_Error_Message IS NOT NULL then
    		return '<div style="' || g_Errors_Return_Style || '">'
    			|| p_After || '</div><span style="font-size:smaller;">' || p_Error_Message || '</span>';
    	end if;
    	if Compare_Data(p_Bevore, p_After) IS NOT NULL then
    		return Style_Data(p_Bevore, p_After);
    	end if;
		return NVL(p_After, p_Bevore);
    END;

    FUNCTION Markup_Upper (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if p_Error_Message IS NOT NULL then
    		return '<div style="' || g_Errors_Return_Style || '">'
    			|| p_After || '</div><span style="font-size:smaller;">' || p_Error_Message || '</span>';
    	end if;
    	if Compare_Upper(p_Bevore, p_After) IS NOT NULL then
    		return Style_Data(p_Bevore, p_After);
    	end if;
		return NVL(p_After, p_Bevore);
    END;

    FUNCTION Markup_Number (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if p_Error_Message IS NOT NULL then
    		return '<div style="' || g_Errors_Return_Style || '">'
    			|| p_After || '</div><span style="font-size:smaller;">' || p_Error_Message || '</span>';
    	end if;
    	if Compare_Number(p_Bevore, p_After) IS NOT NULL then
    		return Style_Data(p_Bevore, p_After);
    	end if;
		return NVL(p_After, p_Bevore);
    END;

    FUNCTION Markup_Date (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if p_Error_Message IS NOT NULL then
    		return '<div style="' || g_Errors_Return_Style || '">'
    			|| p_After || '</div><span style="font-size:smaller;">' || p_Error_Message || '</span>';
    	end if;
    	if Compare_Date(p_Bevore, p_After) IS NOT NULL then
    		return Style_Data(p_Bevore, p_After);
    	end if;
		return NVL(p_After, p_Bevore);
    END;

    FUNCTION Markup_Timestamp (p_Bevore VARCHAR2, p_After VARCHAR2, p_Error_Message VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	if p_Error_Message IS NOT NULL then
    		return '<div style="' || g_Errors_Return_Style || '">'
    			|| p_After || '</div><span style="font-size:smaller;">' || p_Error_Message || '</span>';
    	end if;
    	if Compare_Timestamp(p_Bevore, p_After) IS NOT NULL then
    		return Style_Data(p_Bevore, p_After);
    	end if;
		return NVL(p_After, p_Bevore);
    END;

    FUNCTION Get_MarkupFunction( p_DATA_TYPE VARCHAR2 ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN CASE
        when p_DATA_TYPE = 'NUMBER' then
            'import_utl.Markup_Number'
        when p_DATA_TYPE = 'RAW' then
            'import_utl.Markup_Data'
        when p_DATA_TYPE = 'FLOAT' then
            'import_utl.Markup_Number'
        when p_DATA_TYPE = 'DATE' then
            'import_utl.Markup_Date'
        when p_DATA_TYPE LIKE 'TIMESTAMP%' then
            'import_utl.Markup_Timestamp'
        when p_DATA_TYPE IN ('CHAR', 'VARCHAR', 'VARCHAR2', 'CLOB', 'NCLOB') and g_Compare_Case_Insensitive = 'YES' then
        	'import_utl.Markup_Upper'
        else
            'import_utl.Markup_Data'
        end;
    END;

	-----------------------------------

    FUNCTION New_Job_ID ( p_Table_Name VARCHAR2 )
    RETURN INTEGER
    IS PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        SELECT USER_IMPORT_JOBS_SEQ.NEXTVAL INTO g_Importjob_ID FROM DUAL;

        INSERT INTO USER_IMPORT_JOBS (IMPORTJOB_ID$, TABLE_NAME)
        VALUES (g_Importjob_ID, p_Table_Name);
        COMMIT;
        return g_Importjob_ID;
    END;

    FUNCTION Current_Job_ID RETURN INTEGER
    IS
    BEGIN
        return g_Importjob_ID;
    END;

	PROCEDURE Set_Job_ID ( p_Importjob_ID INTEGER)
    IS
    BEGIN
        g_Importjob_ID := p_Importjob_ID;
    END;

    FUNCTION GetImpCurrencyCols (p_Value VARCHAR2)
    RETURN NUMBER
    IS
    BEGIN
        RETURN TO_NUMBER(p_Value, g_Import_Currency_Format, g_Import_NumChars);
    EXCEPTION
    WHEN OTHERS THEN
        if SQLCODE = -6502 then
            RETURN TO_NUMBER(p_Value, g_Import_Number_Format, g_Import_NumChars);
        end if;
        DBMS_OUTPUT.PUT_LINE('import_utl.GetImpCurrencyCols (' || p_Value || ') - failed with ' || SQLERRM);
        RAISE;
    END;

    FUNCTION GetImpFloatCols  (p_Value VARCHAR2)
    RETURN NUMBER
    IS
    BEGIN
        RETURN TO_NUMBER(p_Value, g_Import_Float_Format);
    END;

    FUNCTION GetImpIntegerCols  (p_Value VARCHAR2)
    RETURN NUMBER
    IS
    BEGIN
        RETURN TO_NUMBER(p_Value);
    EXCEPTION WHEN VALUE_ERROR THEN
        -- DBMS_OUTPUT.PUT_LINE('import_utl.GetImpIntegerCols (' || p_Value || ') - failed with ' || SQLERRM);
    	BEGIN
            RETURN TO_NUMBER(p_Value, g_Import_Number_Format, g_Import_NumChars);
        EXCEPTION WHEN VALUE_ERROR THEN
            RETURN TO_NUMBER(p_Value, g_Import_Currency_Format, g_Import_NumChars);
        END;
    END;

    FUNCTION GetImpDateCols (p_Value VARCHAR2)
    RETURN DATE
    IS
    BEGIN
        RETURN TO_DATE(p_Value, g_Import_DateTime_Format);
    END;

    FUNCTION GetImpTimestampCols  (p_Value VARCHAR2)
    RETURN TIMESTAMP
    IS
    BEGIN
        RETURN TO_TIMESTAMP(p_Value, g_Import_Timestamp_Format);
    END;

    FUNCTION Get_ImportColFunction (
        p_DATA_TYPE VARCHAR2,
        p_DATA_SCALE NUMBER,
        p_CHAR_LENGTH NUMBER,
        p_COLUMN_NAME VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN CASE
        when p_DATA_TYPE = 'NUMBER' AND p_DATA_SCALE = 2 then
            'import_utl.GetImpCurrencyCols(' || p_COLUMN_NAME || ')'
        when p_DATA_TYPE = 'NUMBER' AND p_DATA_SCALE > 0 then
            'TO_NUMBER(' || p_COLUMN_NAME || ', '
            || DBMS_ASSERT.ENQUOTE_LITERAL(REPLACE(g_Import_Currency_Format, 'D99', RPAD('D', p_DATA_SCALE+1, '9')))
            || ', ' || Get_Import_NumChars
            || ')'
        when p_DATA_TYPE = 'NUMBER' AND NULLIF(p_DATA_SCALE, 0) IS NULL then
            'TO_NUMBER(' || p_COLUMN_NAME || ')'
        when p_DATA_TYPE = 'RAW' then
            'HEXTORAW(' || p_COLUMN_NAME || ')'
        when p_DATA_TYPE = 'FLOAT' then
            'import_utl.GetImpFloatCols(' || p_COLUMN_NAME || ')'
        when p_DATA_TYPE = 'DATE' then
            'import_utl.GetImpDateCols(' || p_COLUMN_NAME || ')'
        when p_DATA_TYPE LIKE 'TIMESTAMP%' then
            'import_utl.GetImpTimestampCols(' || p_COLUMN_NAME || ')'
        ELSE
            p_COLUMN_NAME
        END;
    END;

    -----------------------------------------------------------------------------------------------
    FUNCTION is_Char_Limited(p_Value VARCHAR2, p_Char_Length INTEGER) RETURN VARCHAR2
    IS
    BEGIN
        if LENGTH(p_Value) > p_Char_Length then
            return SUBSTR(p_Value, 1, LEAST(30, p_Char_Length + 10)) || Get_Error_is_longer_than || p_Char_Length || ' Zeichen.';
        end if;
        return NULL;
    END;

    FUNCTION is_Char_Limited_Not_Null(p_Value VARCHAR2, p_Char_Length INTEGER) RETURN VARCHAR2
    IS
    BEGIN
        if p_Value IS NULL then
            return Get_Error_is_empty;
        else
            return is_Char_Limited (p_Value, p_Char_Length);
        end if;
    END;

    -----------------------------------------------------------------------------------------------
    FUNCTION is_Currency(p_Value VARCHAR2) RETURN VARCHAR2
    IS
        v_Value NUMBER;
    BEGIN
    	v_Value := TO_NUMBER(p_Value, g_Import_Currency_Format, g_Import_NumChars);
        return NULL;
    EXCEPTION WHEN VALUE_ERROR THEN
        BEGIN
        v_Value := TO_NUMBER(p_Value, g_Import_Number_Format, g_Import_NumChars);
        return NULL;
        EXCEPTION WHEN OTHERS THEN
            return p_Value || Get_Error_is_no_currency || ' Fmt:' || g_Import_Currency_Format || ' ' || g_Import_NumChars || ' SqlCode ' || SQLCODE;
        END;
    WHEN OTHERS THEN
    	return p_Value || Get_Error_is_no_currency || SQLCODE;
    END;

    FUNCTION is_Currency_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        if p_Value IS NULL then
            return Get_Error_is_empty;
        else
            return is_Currency (p_Value);
        end if;
    END;
    -----------------------------------------------------------------------------------------------
    FUNCTION is_Float(p_Value VARCHAR2) RETURN VARCHAR2
    IS
        v_Value NUMBER;
    BEGIN
    	v_Value := TO_NUMBER(p_Value, g_Import_Number_Format, g_Import_NumChars);
        return NULL;
    EXCEPTION WHEN VALUE_ERROR THEN
        BEGIN
        v_Value := TO_NUMBER(p_Value, g_Import_Currency_Format, g_Import_NumChars);
        return NULL;
        EXCEPTION WHEN VALUE_ERROR THEN
            return p_Value || Get_Error_is_no_float;
        END;
     WHEN OTHERS THEN
    	return p_Value || Get_Error_is_no_float || SQLCODE;
    END;

    FUNCTION is_Float_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        if p_Value IS NULL then
            return Get_Error_is_empty;
        else
            return is_Float (p_Value);
        end if;
    END;

    -----------------------------------------------------------------------------------------------
    FUNCTION is_Integer(p_Value VARCHAR2) RETURN VARCHAR2
    IS
        v_Value NUMBER;
    BEGIN
    	v_Value := TO_NUMBER(p_Value);
        if REGEXP_INSTR(p_Value, '^\d+$') = 0 then
            return p_Value || Get_Error_is_no_integer;
        else
            return NULL;
        end if;
    EXCEPTION WHEN VALUE_ERROR THEN
            return p_Value || Get_Error_is_no_integer;
    WHEN OTHERS THEN
    	return p_Value || Get_Error_is_no_integer || SQLCODE;
    END;

    FUNCTION is_Integer_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        if p_Value IS NULL then
            return Get_Error_is_empty;
        else
            return is_Integer (p_Value);
        end if;
    END;
    -----------------------------------------------------------------------------------------------
    FUNCTION is_Date(p_Value VARCHAR2) RETURN VARCHAR2
    IS
        v_Value DATE;
    BEGIN
    	v_Value := TO_DATE(p_Value, g_Import_DateTime_Format);
        return NULL;
    EXCEPTION WHEN VALUE_ERROR THEN
            return p_Value || Get_Error_is_no_date;
    WHEN OTHERS THEN
            return p_Value || Get_Error_is_no_date || SQLCODE;
    END;

    FUNCTION is_Date_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        if p_Value IS NULL then
            return Get_Error_is_empty;
        else
            return is_Date (p_Value);
        end if;
    END;

    -----------------------------------------------------------------------------------------------
    FUNCTION is_Timestamp(p_Value VARCHAR2) RETURN VARCHAR2
    IS
        v_Value TIMESTAMP;
    BEGIN
        v_Value := TO_TIMESTAMP(p_Value, g_Import_Timestamp_Format);
        return NULL;
    EXCEPTION WHEN VALUE_ERROR THEN
            return p_Value || Get_Error_is_no_timestamp;
    WHEN OTHERS THEN
            return p_Value || Get_Error_is_no_timestamp || SQLCODE;
    END;

    FUNCTION is_Timestamp_Not_Null(p_Value VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        if p_Value IS NULL then
            return Get_Error_is_empty;
        else
            return is_Timestamp (p_Value);
        end if;
    END;

    FUNCTION Get_ImpColumnCheck (
        p_DATA_TYPE VARCHAR2,
        p_DATA_SCALE NUMBER,
        p_CHAR_LENGTH NUMBER,
        p_NULLABLE VARCHAR2,
        p_COLUMN_NAME VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
        v_COLUMN_NAME VARCHAR2(50) := DBMS_ASSERT.ENQUOTE_NAME(p_COLUMN_NAME);
    BEGIN
        RETURN
        case when p_NULLABLE = 'N' then
            case
            when p_DATA_TYPE = 'NUMBER' AND p_DATA_SCALE = 2 then
                'import_utl.is_Currency_Not_Null(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'NUMBER' AND NULLIF(p_DATA_SCALE, 0) IS NULL then
                'import_utl.is_Integer_Not_Null(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'RAW' then
                'import_utl.is_Char_Limited_Not_Null(' || v_COLUMN_NAME || ', ' || p_CHAR_LENGTH * 2 || ')'
            when p_DATA_TYPE = 'FLOAT' OR p_DATA_TYPE = 'NUMBER' then
                'import_utl.is_Float_Not_Null(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'DATE' then
                'import_utl.is_Date_Not_Null(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE LIKE 'TIMESTAMP%' then
                'import_utl.is_Timestamp_Not_Null(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'VARCHAR2' OR p_DATA_TYPE = 'CHAR' then
                'import_utl.is_Char_Limited_Not_Null(' || v_COLUMN_NAME || ', ' || p_CHAR_LENGTH || ')'
            end
        else
            case
            when p_DATA_TYPE = 'NUMBER' AND p_DATA_SCALE = 2 then
                'import_utl.is_Currency(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'NUMBER' AND NULLIF(p_DATA_SCALE, 0) IS NULL then
                'import_utl.is_Integer(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'RAW' then
                'import_utl.is_Char_Limited(' || v_COLUMN_NAME || ', ' || p_CHAR_LENGTH * 2 || ')'
            when p_DATA_TYPE = 'FLOAT' OR p_DATA_TYPE = 'NUMBER' then
                'import_utl.is_Float(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'DATE' then
                'import_utl.is_Date(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE LIKE 'TIMESTAMP%' then
                'import_utl.is_Timestamp(' || v_COLUMN_NAME || ')'
            when p_DATA_TYPE = 'VARCHAR2' OR p_DATA_TYPE = 'CHAR' then
                'import_utl.is_Char_Limited(' || v_COLUMN_NAME || ', ' || p_CHAR_LENGTH || ')'
            end
        end;
    END Get_ImpColumnCheck;

    PROCEDURE Run_DDL_Stat (
        p_Statement     IN CLOB,
        p_Allowed_Code  IN NUMBER DEFAULT 0,
        p_Allowed_Code2  IN NUMBER DEFAULT 0,
        p_Allowed_Code3  IN NUMBER DEFAULT 0
    )
    IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(p_Statement || case when INSTR(p_Statement, ';', -1) >= LENGTH(p_Statement) - 2 then '/' else ';' end);
        DBMS_OUTPUT.PUT_LINE(' ');
        if changelog_conf.g_debug = 0 then
            EXECUTE IMMEDIATE p_Statement;
        end if;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('-- SQL Code :' || SQLCODE || ' ' || SQLERRM);
        if SQLCODE NOT IN (p_Allowed_Code, p_Allowed_Code2, p_Allowed_Code3) then
            RAISE;
        end if;
    END Run_DDL_Stat;

    FUNCTION Get_Table_Column_List (
    	p_Table_Name VARCHAR2,
    	p_Delimiter VARCHAR2 DEFAULT ', ',
    	p_Columns_Limit INTEGER DEFAULT 1000
    ) RETURN CLOB
    IS
        v_Table_Name 		VARCHAR2(50) := UPPER(p_Table_Name);
        v_Count				INTEGER	:= 0;
        v_Stat 				CLOB := '';
    	v_Str	 			VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

       	for c_cur in ( -- select column list
            SELECT COLUMN_NAME, COLUMN_ID,
            	LEAD(COLUMN_ID) OVER (ORDER BY COLUMN_ID) NEXT_POSITION
            FROM SYS.USER_TAB_COLUMNS
            WHERE TABLE_NAME = v_Table_Name
            ORDER BY COLUMN_ID
        ) loop
            v_Count := v_Count + 1;
			v_Str := case when p_Delimiter = ':'
					then INITCAP(c_cur.COLUMN_NAME)
					else c_cur.COLUMN_NAME end;
            if v_Count < p_Columns_Limit and c_cur.NEXT_POSITION IS NOT NULL then
            	v_Str := v_Str || p_Delimiter;
            end if;

			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
			exit when v_Count >= p_Columns_Limit;
        end loop;
		RETURN v_Stat;
    END Get_Table_Column_List;

    FUNCTION Get_Imp_Table_View (
    	p_Table_Name VARCHAR2,
    	p_As_Of_Timestamp VARCHAR2 DEFAULT 'NO',
    	p_Data_Format VARCHAR2 DEFAULT 'FORM'	-- FORM, CSV, NATIVE. Format of the final projection columns.
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VUSER_TABLES_IMP.SEARCH_KEY_COLS%TYPE;
        v_Import_View_Name 			VARCHAR2(50);
        v_History_View_Name			VARCHAR2(50);
   BEGIN
        SELECT SEARCH_KEY_COLS, IMPORT_VIEW_NAME, HISTORY_VIEW_NAME
        INTO v_Primary_Key_Cols, v_Import_View_Name, v_History_View_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		RETURN 'CREATE OR REPLACE VIEW ' || case when p_As_Of_Timestamp = 'NO' then v_Import_View_Name else v_History_View_Name end
			|| chr(10) || '    ( '
			|| data_browser_select.Get_Imp_Table_Column_List (
					p_Table_Name => v_Table_Name,
					p_Unique_Key_Column => v_Primary_Key_Cols,
					p_Data_Columns_Only => 'NO',
					p_View_Mode => 'IMPORT_VIEW',
					p_Report_Mode => 'NO'
				)
			|| case when p_As_Of_Timestamp = 'NO' then 
				data_browser_conf.NL(4)
				|| ', CONSTRAINT ' || data_browser_conf.Compose_Table_Column_Name(v_Import_View_Name, '_PK')
				|| ' PRIMARY KEY (LINK_ID$) RELY DISABLE'
			end
			|| ' ) ' || chr(10) || ' AS ' || chr(10)
			|| data_browser_select.Get_Imp_Table_Query (
				p_Table_Name => v_Table_Name,
				p_Unique_Key_Column => v_Primary_Key_Cols,
				p_Data_Columns_Only => 'NO',
				p_As_Of_Timestamp => p_As_Of_Timestamp,
				-- p_Exclude_Blob_Columns => import_utl.Get_Exclude_Blob_Columns,
				p_View_Mode => 'IMPORT_VIEW',
				p_Data_Format => p_Data_Format,
				p_Report_Mode => 'NO'
			);
    END Get_Imp_Table_View;

    FUNCTION Get_Imp_Table_View_trigger (
    	p_Table_Name VARCHAR2,
		p_Data_Format VARCHAR2 DEFAULT 'NATIVE' -- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
        v_Import_Trigger_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VUSER_TABLES_IMP.SEARCH_KEY_COLS%TYPE;
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
        v_Stat CLOB;
        v_Default_Stat CLOB;
        v_Update_Values_Stat CLOB;
        v_Str VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Default_Stat, true, dbms_lob.call);
    	dbms_lob.createtemporary(v_Update_Values_Stat, true, dbms_lob.call);

        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_TRIGGER_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_Trigger_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

        v_Stat :=
        'CREATE OR REPLACE TRIGGER ' || v_Import_Trigger_Name  || ' INSTEAD OF INSERT OR UPDATE OR DELETE ON ' || v_Import_View_Name  || ' FOR EACH ROW  ' || chr(10)
        || 'DECLARE ' || data_browser_conf.NL(4)
        || 'v_row ' || v_Table_Name || '%ROWTYPE;' || chr(10);
        for c_cur in (
            SELECT DISTINCT 'v_' || D_REF || ' ' || R_VIEW_NAME || '.' || R_PRIMARY_KEY_COLS || '%TYPE;' SQL_TEXT
            FROM TABLE (data_browser_select.FN_Pipe_table_imp_FK2(v_Table_Name, import_utl.Get_As_Of_Timestamp, p_Data_Format))
            ORDER BY 1
        ) loop
            v_Str := RPAD(' ', 4) || c_cur.SQL_TEXT || chr(10);
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        end loop;

        v_Str := 'BEGIN' || data_browser_conf.NL(4) 
		|| 'if DELETING then ' || data_browser_conf.NL(8)
		|| 'DELETE FROM ' || v_Table_Name || ' A ' || data_browser_conf.NL(8)
		|| 'WHERE ' 
		|| data_browser_conf.Get_Unique_Key_Expression (
			p_Unique_Key_Column => v_Primary_Key_Cols,
			p_Table_Alias => 'A',
			p_View_Mode => 'IMPORT_VIEW'
		)
		|| ' = :new.LINK_ID$;' || data_browser_conf.NL(8)
		|| 'return;' || data_browser_conf.NL(4)
		|| 'end if;' || chr(10);
        dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
       
        for c_cur in (
            SELECT SQL_TEXT, POSITION
            FROM TABLE (import_utl.FN_Pipe_table_imp_trigger(v_Table_Name, p_Data_Format))
            WHERE SQL_TEXT IS NOT NULL
        ) loop
            v_Str := c_cur.SQL_TEXT || chr(10);
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        end loop;

        for c_cur in ( -- fill empty columns with default values
			SELECT S.VIEW_NAME TABLE_NAME, T.COLUMN_NAME, T.HAS_DEFAULT, 
				'    v_row.' || RPAD(T.COLUMN_NAME, 32)
				|| ' := NVL(v_row.' || T.COLUMN_NAME
				|| ', ' || changelog_conf.Get_ColumnDefaultText(T.TABLE_NAME, T.COLUMN_NAME) || ');'
				 SQL_TEXT
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) T
			JOIN MVDATA_BROWSER_VIEWS S ON S.TABLE_NAME = T.TABLE_NAME
            AND data_browser_pattern.Match_Ignored_Columns(T.COLUMN_NAME) = 'NO'
            AND T.TABLE_ALIAS = 'A'
            AND T.IS_VIRTUAL_COLUMN = 'N'
            AND T.COLUMN_NAME != S.SEARCH_KEY_COLS
            AND T.COLUMN_NAME != 'LINK_ID$'
			AND S.VIEW_NAME = v_Table_Name
			ORDER BY T.COLUMN_ID
        ) loop
        	if c_cur.HAS_DEFAULT = 'Y' then
				v_Str := RPAD(' ', 4) || c_cur.SQL_TEXT || chr(10);
				dbms_lob.writeappend(v_Default_Stat, length(v_Str), v_Str);
			end if;
			v_Str := 
			case when dbms_lob.getlength(v_Update_Values_Stat) > 0 then ',' end
			|| data_browser_conf.NL(12) 
			|| c_cur.COLUMN_NAME || ' = v_row.' || c_cur.COLUMN_NAME;
			dbms_lob.writeappend(v_Update_Values_Stat, length(v_Str), v_Str);
        end loop;

		v_Str := data_browser_conf.NL(4)
		|| 'if INSERTING then ' || chr(10)
		|| v_Default_Stat || rpad(' ', 8)
		|| 'INSERT INTO ' || v_Table_Name|| ' VALUES v_row;' || data_browser_conf.NL(4)
		|| 'else ' || data_browser_conf.NL(8)
		|| 'UPDATE ' || v_Table_Name || ' SET ' || v_Update_Values_Stat || data_browser_conf.NL(8)
		|| 'WHERE ' 
		|| data_browser_conf.Get_Unique_Key_Expression (
			p_Unique_Key_Column => v_Primary_Key_Cols,
			p_Table_Alias => NULL,
			p_View_Mode => 'IMPORT_VIEW'
		)
		|| ' = :new.LINK_ID$'
		|| ';' || chr(10)
		|| '    end if;' || chr(10)
		|| 'END ' || v_Import_Trigger_Name  || ';' || chr(10);

		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		RETURN v_Stat;
    END Get_Imp_Table_View_trigger;

	PROCEDURE Download_imp_views (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Data_Format VARCHAR2 DEFAULT 'NATIVE'	-- FORM, CSV, NATIVE. Format of the final projection columns.
	) 
	IS
        v_Stat 			CLOB;
        v_Result		CLOB;
        v_File_Name		VARCHAR2(128);
        v_Footer		VARCHAR2(100);
	BEGIN
		v_File_Name := LOWER(p_Schema_Name) || '_imp_views.sql';
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);
     	dbms_lob.createtemporary(v_Result, true, dbms_lob.call);

		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME
			FROM MVDATA_BROWSER_VIEWS
			WHERE READ_ONLY = 'NO'
			ORDER BY TABLE_NAME
		) loop
			v_Stat := import_utl.Get_Imp_Table_View (
				p_Table_name => c_cur.VIEW_NAME,
				p_Data_Format => p_Data_Format
			);
			dbms_lob.append(v_Result, v_Stat);
			v_Footer := ';' || chr(10) || chr(10);
			dbms_lob.writeappend(v_Result, length(v_Footer), v_Footer);
			v_Stat := import_utl.Get_Imp_Table_View_trigger (
				p_Table_name => c_cur.VIEW_NAME,
				p_Data_Format => p_Data_Format
			);
			dbms_lob.append(v_Result, v_Stat);
			v_Footer := chr(10) || '/' || chr(10) || chr(10);
			dbms_lob.writeappend(v_Result, length(v_Footer), v_Footer);
		end loop;

		data_browser_blobs.Download_Clob (
			p_clob		=> v_Result,
			p_File_Name => v_File_Name
		);
		apex_application.stop_apex_engine;
	END Download_imp_views;



    FUNCTION Get_Imp_Table_View_Check ( p_Table_Name VARCHAR2 ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_View_Check_Name 	VARCHAR2(50);
        v_Stat CLOB := '';
        v_Str VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        SELECT IMPORT_VIEW_CHECK_NAME
        INTO v_Import_View_Check_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

        v_Stat := 'CREATE OR REPLACE VIEW ' || v_Import_View_Check_Name
        	|| ' (IMPORTJOB_ID$, LINK_ID$, LINE_NO$, COLUMN_NAME, MESSAGE, CONSTRAINT_TYPE) AS ' || chr(10)
        	|| 'SELECT IMPORTJOB_ID$, LINK_ID$, LINE_NO$, COLUMN_NAME, MESSAGE, CONSTRAINT_TYPE' || chr(10) || 'FROM (';
        for c_cur in (
            SELECT SQL_EXISTS
            	|| case when LEAD(TABLE_NAME) OVER (ORDER BY POSITION) IS NOT NULL then chr(10) || 'UNION ALL ' end SQL_TEXT,
                POSITION
            FROM TABLE (import_utl.FN_Pipe_table_imp_trigger(v_Table_Name))
            WHERE SQL_EXISTS IS NOT NULL
            ORDER BY POSITION, POSITION2, CHECK_CONSTRAINT_TYPE DESC
        ) loop
            v_Str := chr(10) || '    ' || c_cur.SQL_TEXT;
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        end loop;
        v_Str := chr(10) || ') WHERE MESSAGE IS NOT NULL';
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);

		RETURN v_Stat;
    END Get_Imp_Table_View_Check;

    FUNCTION Get_Imp_Table_View_Msg ( p_Table_Name VARCHAR2 ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name			VARCHAR2(50);
        v_Import_View_Msg_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Stat CLOB := '';
        v_Str VARCHAR2(32000);
        v_Column_List 	CLOB;
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_MSG_NAME
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Msg_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;
		v_Column_List := data_browser_select.Get_Imp_Table_Column_List ( 
			p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' );
        v_Stat := 'CREATE OR REPLACE VIEW ' || v_Import_View_Msg_Name
			|| chr(10) || '    ( ' 
			|| data_browser_select.Get_Imp_Table_Column_List ( 
				p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' ) || ', FIRST_CHECK_MSG$ ) '
			|| chr(10) || 'AS ' || chr(10)
			|| 'SELECT ' 
			|| data_browser_select.Get_Imp_Table_Column_List ( 
				p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' ) || ', ' || chr(10)
			|| case when INSTR(v_Column_List, ',') > 0 then
					'    COALESCE ( ' || v_Column_List || chr(10)
					|| '    ) FIRST_CHECK_MSG$'
				else
					RPAD(' ', 4) || v_Column_List || ' FIRST_CHECK_MSG$'
				end
			|| chr(10)
			|| 'FROM (' || chr(10)
    		|| '    SELECT IMPORTJOB_ID$, LINE_NO$, LINK_ID$';
       	for c_cur in (
			SELECT A.IMP_COLUMN_NAME,
				case when B.SQL_EXISTS2 is not null and A.POSITION = 1 then B.SQL_EXISTS2
				 when A.COLUMN_CHECK_EXPR is not null  and A.POSITION = 0 then A.COLUMN_CHECK_EXPR
				 else 'NULL'
				end COLUMN_CHECK_EXPR
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) A
			LEFT OUTER JOIN (
                SELECT  TABLE_NAME, COLUMN_NAME, LISTAGG( SQL_EXISTS2, ' || ' ) WITHIN GROUP (ORDER BY CHECK_CONSTRAINT_TYPE) SQL_EXISTS2
                FROM TABLE (import_utl.FN_Pipe_table_imp_trigger(v_Table_Name))
                WHERE CHECK_CONSTRAINT_TYPE = 'R'
                GROUP BY TABLE_NAME, COLUMN_NAME
            ) B ON A.TABLE_NAME = B.TABLE_NAME AND A.COLUMN_NAME = B.COLUMN_NAME
			WHERE A.IMP_COLUMN_NAME != 'LINK_ID$'
			ORDER BY A.COLUMN_ID, A.POSITION
        ) loop
            v_Str := ', ' || chr(10) || chr(9) || c_cur.COLUMN_CHECK_EXPR || ' ' || c_cur.IMP_COLUMN_NAME;
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        end loop;
        v_Str := chr(10)
    	|| '    FROM ' || v_Import_Table_Name || ' IMP' || chr(10)
    	|| ')' || chr(10);
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);

		RETURN v_Stat;
    END Get_Imp_Table_View_Msg;

    FUNCTION Get_Imp_Query_Diff (
    	p_Table_Name VARCHAR2,
    	p_Columns_Limit INTEGER DEFAULT 1000
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Count						INTEGER	:= 0;
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name			VARCHAR2(50);
        v_Import_View_Msg_Name 		VARCHAR2(50);
        v_Import_View_Dif_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
        v_Stat 						CLOB := '';
        v_Filter 					VARCHAR2(32000);
        v_Str 						VARCHAR2(32000);
        v_Str2 						VARCHAR2(32000);
        v_Column_List 				VARCHAR(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Msg_Name, v_Import_View_Dif_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;
		v_Column_List := data_browser_select.Get_Imp_Table_Column_List ( p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' );
		v_Str := 'SELECT ' || data_browser_select.Get_Imp_Table_Column_List ( p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'NO', p_Columns_Limit => p_Columns_Limit - 1 ) || ', ' || chr(10)
			|| case when INSTR(v_Column_List, ',') > 0 then
				'    COALESCE ( ' || v_Column_List || chr(10)
				|| '    ) FIRST_CHECK_MSG$'
				else
					RPAD(' ', 4) || v_Column_List || ' FIRST_CHECK_MSG$'
				end
			|| chr(10)
			|| 'FROM (' || chr(10)
			|| '    SELECT B.IMPORTJOB_ID$, B.LINE_NO$, B.ROW_SELECTOR$';
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		v_Count := v_Count + 3;
		v_Str := NULL;
		for c_cur in (
			SELECT A.COLUMN_NAME,
				A.COLUMN_COMPARE || '( A.' || A.IMP_COLUMN_NAME || ', B.' || A.IMP_COLUMN_NAME || ' ) '
				|| A.IMP_COLUMN_NAME
				SQL_STAT
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) A
			WHERE A.TABLE_NAME = v_Table_Name
			AND A.IMP_COLUMN_NAME != 'ROW_SELECTOR$'
			ORDER BY A.COLUMN_ID, A.POSITION
		) loop
			v_Str := v_Str || ', ' || chr(10) || chr(9) || c_cur.SQL_STAT;
			exit when v_Count >= p_Columns_Limit;
		end loop;
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		v_Str := chr(10)
		|| '    FROM ' || v_Import_Table_Name  || ' B' || chr(10)
		|| '    JOIN ' || v_Import_View_Name || ' A ON A.ROW_SELECTOR$ = B.ROW_SELECTOR$ ' || chr(10)
		|| ')' || chr(10);
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);

		RETURN v_Stat;
    END Get_Imp_Query_Diff;

    FUNCTION Get_Imp_Markup_Column_List ( p_Table_Name VARCHAR2 ) RETURN VARCHAR2
	IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Primary_Key_Cols 			VARCHAR2(4000);
	BEGIN
		SELECT SEARCH_KEY_COLS
		INTO v_Primary_Key_Cols
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		return REPLACE('Source:'|| data_browser_select.Get_Imp_Table_Column_List (
										p_Table_name => p_Table_Name,
										p_Unique_Key_Column => v_Primary_Key_Cols,
										p_Delimiter => ':',
										p_Data_Columns_Only => 'NO',
										p_Columns_Limit => 59,
										p_Format => 'HEADER' ),
					'Source:Importjob_Id:Line_No:Link_Id',
					'Line_No:Link_Id:Source:Importjob_Id');
	END Get_Imp_Markup_Column_List;

    FUNCTION Get_Imp_Markup_Query (
    	p_Table_Name VARCHAR2,
    	p_Import_Job_ID NUMBER DEFAULT 1000,
    	p_Columns_Limit INTEGER DEFAULT 1000,
    	p_Filter_Errors VARCHAR2 DEFAULT 'NO',
    	p_Filter_Differences VARCHAR2 DEFAULT 'NO',
    	p_Filter_New_Rows VARCHAR2 DEFAULT 'NO',
    	p_Filter_Missing_Rows VARCHAR2 DEFAULT 'NO'
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Count						INTEGER	:= 0;
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name			VARCHAR2(50);
        v_Import_View_Msg_Name 		VARCHAR2(50);
        v_Import_View_Dif_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
        v_Stat 						CLOB := '';
        v_Filter 					VARCHAR2(32000);
        v_Filter_Count				INTEGER	:= 0;
        v_Str VARCHAR2(32000);
        v_Str2 VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Msg_Name, v_Import_View_Dif_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		if p_Filter_Errors = 'YES' or p_Filter_Differences = 'YES' then
			v_Str := 'SELECT IMP_SOURCE, ' || data_browser_select.Get_Imp_Table_Column_List ( p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' ) || chr(10)
			|| 'FROM ( ';
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;

		v_Count := 4;
		for c_cur in (
			SELECT A.COLUMN_NAME,
				case when p_Filter_Differences = 'YES'
					then A.COLUMN_COMPARE || '( A.' || A.IMP_COLUMN_NAME || ', B.' || A.IMP_COLUMN_NAME || ' )' end
				|| case when p_Filter_Errors = 'YES' and p_Filter_Differences = 'YES'
					then ', ' end
				|| case when p_Filter_Errors = 'YES'
					then 'C.' || A.IMP_COLUMN_NAME end
				 SQL_COMPARE,
				A.COLUMN_MARKUP || '( A.' || A.IMP_COLUMN_NAME || ', B.' || A.IMP_COLUMN_NAME || ', C.' || A.IMP_COLUMN_NAME || ' ) '
				|| A.IMP_COLUMN_NAME SQL_MARK_UP
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) A
			WHERE A.TABLE_NAME = v_Table_Name
			AND A.IMP_COLUMN_NAME != 'LINK_ID$'
			ORDER BY A.COLUMN_ID, A.POSITION
		) loop
			v_Count := v_Count + 1;
			if c_cur.SQL_COMPARE IS NOT NULL then
				v_Filter := v_Filter || ', ' || chr(10) || chr(9) || c_cur.SQL_COMPARE;
				v_Filter_Count := v_Filter_Count + 1;
			end if;
			if v_Count <= p_Columns_Limit then
				v_Str2 := v_Str2 || ', ' || chr(10) || chr(9) || c_cur.SQL_MARK_UP;
			end if;
		end loop;
		v_Filter := SUBSTR(v_Filter, 3);
		v_Filter := case when v_Filter_Count > 1 OR p_Filter_Errors = 'YES' and p_Filter_Differences = 'YES' then
				chr(10) || '    COALESCE ( ' || v_Filter || chr(10) || '    )'
			else
				RPAD(' ', 4) || v_Filter
			end;

		if p_Filter_Missing_Rows = 'YES' then
			v_Str := 'SELECT ''System'' IMP_SOURCE, ' || p_Import_Job_ID || ' IMPORTJOB_ID$, LPAD(NVL(A.LINE_NO$, B.LINE_NO$), 10) LINE_NO$, NVL(A.LINK_ID$, B.LINK_ID$) LINK_ID$' || v_Str2
				|| case when v_Filter IS NOT NULL
					then
						', ' || v_Filter || ' FIRST_CHECK_MSG$'
					end
				|| chr(10)
				|| 'FROM ' || v_Import_View_Name || ' A -- Source System ' || chr(10)
				|| case when p_Filter_New_Rows = 'YES'
					then 'FULL' else 'LEFT' end
				|| ' OUTER JOIN ' || v_Import_Table_Name || ' B ON B.LINK_ID$ = A.LINK_ID$  -- Source Import ' || chr(10)
				|| 'LEFT OUTER JOIN ' || v_Import_View_Msg_Name || ' C ON B.LINE_NO$ = C.LINE_NO$ AND B.IMPORTJOB_ID$ = C.IMPORTJOB_ID$ -- Source Errors ' || chr(10)
				|| 'WHERE A.IMPORTJOB_ID$ = ' || p_Import_Job_ID || chr(10)
				|| 'AND (B.LINE_NO$ IS NULL'
				|| case when p_Filter_New_Rows = 'YES'
					then ' OR A.LINK_ID$ IS NULL' || chr(10) end
				|| ')' || chr(10);
		else
			v_Str := 'SELECT ''Import'' IMP_SOURCE, B.IMPORTJOB_ID$, LPAD(B.LINE_NO$, 10) LINE_NO$, B.LINK_ID$' || v_Str2
				|| case when v_Filter IS NOT NULL
					then
						', ' || v_Filter || ' FIRST_CHECK_MSG$'
					end
				|| chr(10)
				|| 'FROM ' || v_Import_Table_Name || ' B -- Source Import ' || chr(10)
				|| 'JOIN ' || v_Import_View_Msg_Name || ' C ON B.LINE_NO$ = C.LINE_NO$ AND B.IMPORTJOB_ID$ = C.IMPORTJOB_ID$ -- Source Errors ' || chr(10)
				|| 'LEFT OUTER JOIN ' || v_Import_View_Name || ' A ON B.LINK_ID$ = A.LINK_ID$ -- Source System ' || chr(10)
				|| 'WHERE B.IMPORTJOB_ID$ = ' || p_Import_Job_ID || chr(10)
				|| case when p_Filter_New_Rows = 'YES'
					then 'AND A.LINK_ID$ IS NULL' || chr(10)
				end;
		end if;
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);

		if p_Filter_Errors = 'YES' or p_Filter_Differences = 'YES' then
			v_Str := ') WHERE FIRST_CHECK_MSG$ IS NOT NULL' || chr(10);
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;


		RETURN v_Stat;
    END Get_Imp_Markup_Query;

    FUNCTION Get_Imp_Table_View_Diff ( p_Table_Name VARCHAR2) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Import_View_Dif_Name 		VARCHAR2(50);
    BEGIN
    	SELECT SEARCH_KEY_COLS, IMPORT_VIEW_DIF_NAME
    	INTO v_Primary_Key_Cols, v_Import_View_Dif_Name
    	FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		return 'CREATE OR REPLACE VIEW ' || v_Import_View_Dif_Name
			|| chr(10) || '    ( ' || data_browser_select.Get_Imp_Table_Column_List ( p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' ) || ', FIRST_CHECK_MSG$ ) '
			|| chr(10) || 'AS ' || chr(10)
			|| Get_Imp_Query_Diff(p_Table_Name);
	END Get_Imp_Table_View_Diff;

    FUNCTION Get_Imp_Table_Link ( p_Table_Name VARCHAR2, p_Import_Job_ID VARCHAR2 ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Stat CLOB := '';
        v_Str VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        for c_cur in (
            SELECT DISTINCT SQL_TEXT
            FROM TABLE (import_utl.FN_Pipe_table_imp_link(v_Table_Name))
        ) loop
            v_Str := c_cur.SQL_TEXT  || ' AND IMPORTJOB_ID$ = ' || p_Import_Job_ID || ';' || chr(10) || '    ';
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        end loop;

		RETURN v_Stat;
    END Get_Imp_Table_Link;

    FUNCTION Get_Imp_Check_Query (
    	p_Table_Name VARCHAR2,
    	p_Import_Job_ID NUMBER DEFAULT 1000,
    	p_Columns_Limit INTEGER DEFAULT 1000,
    	p_Filter_Errors VARCHAR2 DEFAULT 'NO',
    	p_Filter_Differences VARCHAR2 DEFAULT 'NO',
    	p_Filter_New_Rows VARCHAR2 DEFAULT 'NO',
    	p_Filter_Missing_Rows VARCHAR2 DEFAULT 'NO',
    	p_Filter_Combine VARCHAR2 DEFAULT 'UNION'
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name			VARCHAR2(50);
        v_Import_View_Dif_Name 		VARCHAR2(50);
        v_Import_View_Msg_Name 		VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
        v_Filter_Combine			VARCHAR2(50);
        v_Column_List 				VARCHAR(32000);
        v_Stat CLOB := '';
        v_Str VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_MSG_NAME, IMPORT_VIEW_DIF_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Msg_Name, v_Import_View_Dif_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;
		v_Filter_Combine		:= NULL;
		v_Column_List			:= data_browser_select.Get_Imp_Table_Column_List (
			p_Table_name => v_Table_Name,
			p_Unique_Key_Column => v_Primary_Key_Cols,
			p_Delimiter => ', ',
			p_Data_Columns_Only => 'NO',
			p_Columns_Limit => p_Columns_Limit - 1
		);
		v_Column_List			:= REPLACE(v_Column_List, 'LINE_NO$', 'LPAD(LINE_NO$, 10) LINE_NO$');
        if p_Filter_Errors = 'YES' or p_Filter_Differences = 'YES' or p_Filter_New_Rows = 'YES' then
            v_Str := 'WITH FILTER_Q AS (';
            if p_Filter_Errors = 'YES' then -- List error Messages
                v_Str := v_Str
                    || 'SELECT LINE_NO$ FROM ' || v_Import_View_Msg_Name || chr(10)
                    || '    WHERE FIRST_CHECK_MSG$ IS NOT NULL ' || chr(10)
                    || '    AND IMPORTJOB_ID$ = ' || p_Import_Job_ID || chr(10);
                v_Filter_Combine := p_Filter_Combine;
            end if;
            if p_Filter_Differences = 'YES' then -- List Differences
                v_Str := v_Str
                || '   ' || v_Filter_Combine
                || ' SELECT LINE_NO$ ' || chr(10)
                || '    FROM ' || v_Import_View_Dif_Name || chr(10)
                || '    WHERE FIRST_CHECK_MSG$ IS NOT NULL ' || chr(10)
                || '    AND IMPORTJOB_ID$ = ' || p_Import_Job_ID || chr(10);
                v_Filter_Combine := p_Filter_Combine;
            end if;
            if p_Filter_New_Rows = 'YES' then -- List New_Rows
                v_Str := v_Str
                || '   ' || v_Filter_Combine
                || ' SELECT LINE_NO$ ' || chr(10)
                || '    FROM ' || v_Import_Table_Name || chr(10)
                || '    WHERE LINK_ID$ IS NULL ' || chr(10)
                || '    AND IMPORTJOB_ID$ = ' || p_Import_Job_ID || chr(10);
                v_Filter_Combine := p_Filter_Combine;
            end if;
            v_Str := v_Str || ') ';
            dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
        end if;
        v_Str :=
        'SELECT * FROM (' || chr(10)
        || '    SELECT ''System'' IMP_SOURCE, ' || p_Import_Job_ID || ' ' || v_Column_List || chr(10)
        || '    FROM ' || v_Import_View_Name || ' S ' || chr(10)
        || '    WHERE ' || case when p_Filter_Missing_Rows = 'YES' then 'NOT' end -- List Missing_Rows
        || ' EXISTS (SELECT 1 FROM ' || v_Import_Table_Name || ' I ' || chr(10)
        || '        WHERE I.LINK_ID$ = S.LINK_ID$' || chr(10)
        || '        AND I.IMPORTJOB_ID$ = ' || p_Import_Job_ID || ' )' || chr(10)
        || '    UNION ALL ' || chr(10)
        || '    SELECT ''Import'' IMP_SOURCE, ' || v_Column_List || chr(10)
        || '    FROM ' || v_Import_Table_Name || ' I ' || chr(10)
        || '    UNION ALL ' || chr(10)
        || '    SELECT ''Differenz'' IMP_SOURCE, ' || v_Column_List || chr(10)
        || '    FROM ' || v_Import_View_Dif_Name || ' D ' || chr(10)
        || '    UNION ALL ' || chr(10)
        || '    SELECT ''Fehler'' IMP_SOURCE, ' || v_Column_List || chr(10)
        || '    FROM ' || v_Import_View_Msg_Name || ' E ' || chr(10)
        || ') WHERE IMPORTJOB_ID$ = ' || p_Import_Job_ID || chr(10)
        || case when v_Filter_Combine IS NOT NULL then
            'AND LINE_NO$ IN (SELECT I.LINE_NO$  FROM FILTER_Q I)' || chr(10)
        end;
        dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);


        RETURN v_Stat;
    END Get_Imp_Check_Query;


    FUNCTION Get_History_Markup_Query (
    	p_Table_Name VARCHAR2,
    	p_Import_Job_ID NUMBER DEFAULT 1000,
    	p_Columns_Limit INTEGER DEFAULT 1000,
    	p_Filter_Differences VARCHAR2 DEFAULT 'NO',
    	p_Filter_New_Rows VARCHAR2 DEFAULT 'NO',
    	p_Filter_Missing_Rows VARCHAR2 DEFAULT 'NO'
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Count						INTEGER	:= 0;
        v_Import_View_Name			VARCHAR2(50);
        v_History_View_Name			VARCHAR2(50);
        v_Term						VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Stat 						CLOB := '';
        v_Filter 					VARCHAR2(32000);
        v_Filter_Count				INTEGER	:= 0;
        v_Str VARCHAR2(32000);
        v_Str2 VARCHAR2(32000);
    BEGIN
    	dbms_lob.createtemporary(v_Stat, true, dbms_lob.call);

        SELECT SEARCH_KEY_COLS, IMPORT_VIEW_NAME, HISTORY_VIEW_NAME
        INTO v_Primary_Key_Cols, v_Import_View_Name, v_History_View_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;


		v_Str := 'SELECT IMP_SOURCE, ' || data_browser_select.Get_Imp_Table_Column_List ( p_Table_name => v_Table_Name, p_Unique_Key_Column => v_Primary_Key_Cols, p_Data_Columns_Only => 'YES' ) || chr(10)
		|| 'FROM ( ';
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);

		v_Count := 4;
		for c_cur in (
			SELECT A.COLUMN_NAME,
				case when p_Filter_Differences = 'YES' and A.IMP_COLUMN_NAME != 'LINK_ID$' then
					A.COLUMN_COMPARE || '( A.' || A.IMP_COLUMN_NAME || ', B.' || A.IMP_COLUMN_NAME || ' )'
				end SQL_COMPARE,
				A.COLUMN_MARKUP || '( A.' || A.IMP_COLUMN_NAME || ', B.' || A.IMP_COLUMN_NAME || ' ) '
				|| A.IMP_COLUMN_NAME SQL_MARK_UP
			FROM TABLE (import_utl.FN_Pipe_table_imp_cols(v_Table_Name)) A
			WHERE A.TABLE_NAME = v_Table_Name
			ORDER BY A.COLUMN_ID, A.POSITION
		) loop
			v_Count := v_Count + 1;
			if c_cur.SQL_COMPARE IS NOT NULL then
				v_Filter := v_Filter || ', ' || chr(10) || chr(9) || c_cur.SQL_COMPARE;
				v_Filter_Count := v_Filter_Count + 1;
			end if;
			if v_Count <= p_Columns_Limit then
				v_Str2 := v_Str2 || ', ' || chr(10) || chr(9) || c_cur.SQL_MARK_UP;
			end if;
		end loop;
		v_Filter := SUBSTR(v_Filter, 3);
		v_Filter := case when v_Filter_Count > 1 then
				chr(10) || '    COALESCE ( ' || v_Filter || chr(10) || '    )'
			when v_Filter IS NOT NULL then
				RPAD(' ', 4) || v_Filter
			end;

		v_Str := 'SELECT ''System'' IMP_SOURCE, '
			|| p_Import_Job_ID || ' IMPORTJOB_ID$, ' || chr(10) || chr(9)
			|| 'LPAD(NVL(A.LINE_NO$, B.LINE_NO$), 10) LINE_NO$, ' || chr(10) || chr(9)
			|| 'NVL(A.LINK_ID$, B.LINK_ID$) LINK_ID$ '
			|| v_Str2
			|| ', A.LINK_ID$ SYSTEM_LINK_ID$'
			|| ', B.LINK_ID$ ARCHIVE_LINK_ID$'
			|| case when v_Filter IS NOT NULL then
				', ' || v_Filter || ' FIRST_CHECK_MSG$' end
				|| chr(10)
			|| '    FROM ' || v_Import_View_Name || ' A -- Source System ' || chr(10)
			|| '    FULL OUTER JOIN ' || v_History_View_Name || ' B ON B.LINK_ID$ = A.LINK_ID$  -- Source Import ' || chr(10)
			|| ') ';
		dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);

		if p_Filter_Differences = 'YES' OR p_Filter_New_Rows = 'YES' OR p_Filter_Missing_Rows = 'YES' then
			v_Str  := NULL;
			v_Term := ' WHERE (';
		if p_Filter_Differences = 'YES' then
				v_Str := v_Str || v_Term || '  FIRST_CHECK_MSG$ IS NOT NULL' || chr(10);
				v_Term := ' OR ';
			end if;
			if p_Filter_New_Rows = 'YES' then
				v_Str := v_Str || v_Term || '  ARCHIVE_LINK_ID$ IS NULL' || chr(10);
				v_Term := ' OR ';
			end if;
			if p_Filter_Missing_Rows = 'YES' then
				v_Str := v_Str || v_Term || '  SYSTEM_LINK_ID$ IS NULL' || chr(10);
				v_Term := ' OR ';
			end if;
			v_Str := v_Str || ')';
			dbms_lob.writeappend(v_Stat, length(v_Str), v_Str);
		end if;

		RETURN v_Stat;
    END Get_History_Markup_Query;



    FUNCTION Get_Imp_Table_Test (
    	p_Table_Name VARCHAR2,
    	p_Import_Job_ID NUMBER DEFAULT NULL,
    	p_Delete_Rows VARCHAR2 DEFAULT 'YES'
    ) RETURN CLOB
    IS
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
        v_Import_View_Check_Name 	VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Stat CLOB;
        v_Link_Stat CLOB;
	BEGIN
        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_CHECK_NAME
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Check_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		v_Stat := chr(10)
        || 'declare'|| chr(10)
        || '   v_Job_ID NUMBER'
        || case when p_Import_Job_ID IS NOT NULL then ' := ' || p_Import_Job_ID  end
        || ';' || chr(10)
        || 'begin ' || chr(10)
        || '    if v_Job_ID IS NULL then'  || chr(10)
        || '        SELECT import_utl.New_Job_ID(' || DBMS_ASSERT.ENQUOTE_LITERAL(v_Table_Name) || ') INTO v_Job_ID FROM DUAL;' || chr(10)
        || '    else' || chr(10)
        || '        import_utl.Set_Job_ID(v_Job_ID);' || chr(10)
        || '    end if;' || chr(10)
        || '    DBMS_OUTPUT.PUT_LINE(''Importjob_Id: '' || v_Job_ID);' || chr(10)
        || chr(10)
        || '    -- Export 1000 rows to ' ||v_Import_Table_Name || ': --'  || chr(10)
        || '    INSERT INTO ' || v_Import_Table_Name || ' SELECT * FROM ' || v_Import_View_Name || chr(10)
        || '    WHERE ROWNUM <= 1000;' || chr(10)
        || '    DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT || '' rows inserted into ' || v_Import_Table_Name || ''');'|| chr(10)
        || chr(10)
        || '    DBMS_OUTPUT.PUT_LINE(''checking table data: '');' || chr(10)
        || '    for t_cur in (' || chr(10)
        || '        SELECT IMPORTJOB_ID$, LINK_ID$, LINE_NO$, COLUMN_NAME, MESSAGE, CONSTRAINT_TYPE ' || chr(10)
        || '        FROM ' || v_Import_View_Check_Name || chr(10)
        || '        WHERE IMPORTJOB_ID$ = v_Job_ID' || chr(10)
        || '        AND ROWNUM <= 100'|| chr(10)
        || '    ) loop ' || chr(10)
        || '        DBMS_OUTPUT.PUT_LINE(t_cur.LINE_NO$ || '':'' || t_cur.COLUMN_NAME|| '':'' || t_cur.MESSAGE );' || chr(10)
        || '    end loop;' || chr(10)
        || chr(10);

		-- Link imported rows to base table via unique key columns
		v_Link_Stat := import_utl.Get_Imp_Table_Link ( v_Table_Name, 'v_Job_ID' );
		if LENGTH(v_Link_Stat) > 1 then
			v_Stat := v_Stat
	        || '    UPDATE ' || v_Import_Table_Name || ' SET LINK_ID$ = NULL'|| chr(10)
    	    || '    WHERE IMPORTJOB_ID$ = v_Job_ID;' || chr(10) || chr(10)
			|| RPAD(' ', 4) || v_Link_Stat || chr(10)
	        || '    DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT || '' rows linked to ' || v_Table_Name || ''');'|| chr(10);
		end if;

		v_Stat := v_Stat || chr(10)
        || '    -- Import rows from ' ||v_Import_Table_Name || ': --'  || chr(10)
		|| '    INSERT INTO ' || v_Import_View_Name || chr(10)
		|| '    SELECT * ' || chr(10)
		|| '    FROM ' || v_Import_Table_Name || ' A' || chr(10)
		|| '    WHERE LINE_NO$ NOT IN (SELECT LINE_NO$ FROM ' || v_Import_View_Check_Name || ' B' || chr(10)
		|| '        WHERE CONSTRAINT_TYPE != ' || DBMS_ASSERT.ENQUOTE_LITERAL('R+') || chr(10)
		|| '        AND B.IMPORTJOB_ID$ = v_Job_ID' || chr(10)
		|| '    ) AND IMPORTJOB_ID$ = v_Job_ID;' || chr(10)
        || '    DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT || '' rows inserted to ' || v_Table_Name || ''');'|| chr(10);

		if p_Delete_Rows = 'YES' then
		v_Stat := v_Stat || chr(10)
			|| '    DELETE FROM ' || v_Import_Table_Name || chr(10)
			|| '    WHERE IMPORTJOB_ID$ = v_Job_ID;' || chr(10)
			|| '    DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT || '' rows deleted from ' || v_Import_Table_Name || ''');';
		end if;
		v_Stat := v_Stat || chr(10)
        || '    COMMIT;' || chr(10)
        || 'end;' || chr(10);

		RETURN v_Stat;
   END Get_Imp_Table_Test;


	FUNCTION Get_Base_Table_Name (
		p_View_Name IN VARCHAR2
	) RETURN VARCHAR2
	IS
        v_Table_Name 	VARCHAR2(50);
	BEGIN -- table is used in view
	    SELECT D.REFERENCED_NAME
	    INTO v_Table_Name
        FROM USER_DEPENDENCIES D
        WHERE D.TYPE = 'VIEW'
        AND D.REFERENCED_TYPE = 'TABLE'
		AND D.NAME = p_View_Name;

        return v_Table_Name;
    EXCEPTION
    WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
        return p_View_Name;
	END Get_Base_Table_Name;

    PROCEDURE Generate_Imp_Table (
        p_Table_Name VARCHAR2,
        p_Recreate_Import_Table VARCHAR2 DEFAULT 'YES'
    )
    IS
        v_Stat CLOB;
        v_Count INTEGER;
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
        v_Import_View_Check_Name 	VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
    BEGIN
        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_CHECK_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Check_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

        v_Stat := import_utl.Get_Imp_Table_View ( p_Table_Name => v_Table_Name, p_As_Of_Timestamp => 'NO' );
        Run_DDL_Stat (v_Stat); -- create import view
        if changelog_conf.Get_Add_ChangeLog_Views = 'YES' then
			v_Stat := import_utl.Get_Imp_Table_View ( p_Table_Name => v_Table_Name, p_As_Of_Timestamp => 'YES' );
			Run_DDL_Stat (v_Stat); -- create history view
        end if;
		v_Stat := import_utl.Get_Imp_Table_View_trigger ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import trigger

        SELECT COUNT(*) INTO v_Count
        FROM USER_OBJECTS T
        WHERE T.OBJECT_NAME = v_Import_Table_Name AND T.OBJECT_TYPE = 'TABLE';
        if p_Recreate_Import_Table = 'YES' or v_Count = 0 then
            if v_Count = 1 then
                v_Stat := 'DROP TABLE ' || v_Import_Table_Name;
                Run_DDL_Stat (v_Stat, -942); -- drop import table
            end if;

            v_Stat := 'CREATE TABLE ' || v_Import_Table_Name || ' AS SELECT * FROM ' || v_Import_View_Name || ' WHERE 1!=1';
            Run_DDL_Stat (v_Stat); -- create import table
            v_Stat := 'ALTER TABLE ' || v_Import_Table_Name
            || ' ADD CONSTRAINT ' || v_Import_Table_Name || '_FK FOREIGN KEY (IMPORTJOB_ID$) REFERENCES ' || Get_Base_Table_Name('USER_IMPORT_JOBS') || '(IMPORTJOB_ID$) ON DELETE CASCADE';
            Run_DDL_Stat (v_Stat); -- create foreign key to USER_IMPORT_JOBS

            v_Stat := 'CREATE INDEX ' || v_Import_Table_Name || '_IND ON ' || v_Import_Table_Name || '(IMPORTJOB_ID$, LINK_ID$)';
            Run_DDL_Stat (v_Stat); -- create import table index
        end if;

		v_Stat := import_utl.Get_Imp_Table_View_Check ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import check view
		v_Stat := import_utl.Get_Imp_Table_View_Msg ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import check view
		v_Stat := import_utl.Get_Imp_Table_View_Diff ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import check view


	EXCEPTION WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('Table not found.');
    END Generate_Imp_Table;

    PROCEDURE Generate_Import_Views (
        p_Table_Name VARCHAR2
    )
    IS
        v_Stat CLOB;
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
        v_Import_View_Check_Name 	VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
    BEGIN
        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_CHECK_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Check_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

        v_Stat := import_utl.Get_Imp_Table_View ( p_Table_Name => v_Table_Name, p_As_Of_Timestamp => 'NO' );
        Run_DDL_Stat (v_Stat); -- create import view
        if changelog_conf.Get_Add_ChangeLog_Views = 'YES' then
	        v_Stat := import_utl.Get_Imp_Table_View ( p_Table_Name => v_Table_Name, p_As_Of_Timestamp => 'YES' );
    	    Run_DDL_Stat (v_Stat); -- create history view
    	end if;
		v_Stat := import_utl.Get_Imp_Table_View_trigger ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import trigger
		v_Stat := import_utl.Get_Imp_Table_View_Check ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import check view
		v_Stat := import_utl.Get_Imp_Table_View_Msg ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import check view
		v_Stat := import_utl.Get_Imp_Table_View_Diff ( v_Table_Name );
        Run_DDL_Stat (v_Stat); -- create import check view


	EXCEPTION WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('Table not found.');
    END Generate_Import_Views;

	PROCEDURE Generate_Updatable_Views (
		p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
    	p_Data_Format VARCHAR2 DEFAULT 'NATIVE'	-- FORM, HTML, CSV, NATIVE. Format of the final projection columns.
	) 
	IS
        v_Stat CLOB;
	BEGIN
		for c_cur IN (
			SELECT TABLE_NAME, VIEW_NAME
			FROM MVDATA_BROWSER_VIEWS
			WHERE READ_ONLY = 'NO'
			AND VIEW_OWNER = p_Schema_Name
			ORDER BY TABLE_NAME
		) loop
			v_Stat := import_utl.Get_Imp_Table_View (
				p_Table_name => c_cur.VIEW_NAME,
				p_Data_Format => p_Data_Format
			);
        	Run_DDL_Stat (v_Stat); -- create import view
			v_Stat := import_utl.Get_Imp_Table_View_trigger (
				p_Table_name => c_cur.VIEW_NAME,
				p_Data_Format => p_Data_Format
			);
        	Run_DDL_Stat (v_Stat); -- create import trigger
		end loop;
	END Generate_Updatable_Views;

    PROCEDURE Link_Import_Table (
        p_Table_Name 	IN VARCHAR2,
    	p_Import_Job_ID IN NUMBER,
        p_Row_Count 	OUT NUMBER
    )
    IS
        v_Stat 						CLOB;
        v_Link_Stat 				CLOB;
        v_Str 						VARCHAR2(32000);
        v_Count 					INTEGER := 0;
        v_Row_Count 				INTEGER := 0;
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
    BEGIN
        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME
        INTO v_Primary_Key_Cols, v_Import_Table_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		COMMIT;
		-- Link imported rows to base table via unique key columns
        for c_cur in (
            SELECT DISTINCT SQL_TEXT || ' AND IMPORTJOB_ID$ = :a' SQL_TEXT
            FROM TABLE (import_utl.FN_Pipe_table_imp_link(v_Table_Name))
        ) loop
        	v_Count := v_Count + 1;
        	if v_Count = 1 then
				v_Str :=
				'UPDATE ' || v_Import_Table_Name || ' SET LINK_ID$ = NULL'|| chr(10)
				|| 'WHERE IMPORTJOB_ID$ = :a' ;
				EXECUTE IMMEDIATE v_Str USING IN p_Import_Job_ID;
        	end if;

			EXECUTE IMMEDIATE c_cur.SQL_TEXT USING IN p_Import_Job_ID;
			v_Row_Count := v_Row_Count + SQL%ROWCOUNT;
        end loop;
		p_Row_Count := v_Row_Count;
	END Link_Import_Table;

    PROCEDURE Import_From_Imp_Table (
        p_Table_Name 	IN VARCHAR2,
    	p_Import_Job_ID IN NUMBER,
        p_Row_Count 	OUT NUMBER
    )
    IS
        v_Stat 						CLOB;
        v_Count 					INTEGER;
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
        v_Import_View_Check_Name	VARCHAR2(50);
        v_Primary_Key_Cols 			VARCHAR2(4000);
        v_Has_Scalar_Primary_Key 	VARCHAR2(50);
    BEGIN
        SELECT SEARCH_KEY_COLS, IMPORT_TABLE_NAME, IMPORT_VIEW_NAME, IMPORT_VIEW_CHECK_NAME, HAS_SCALAR_PRIMARY_KEY
        INTO v_Primary_Key_Cols, v_Import_Table_Name, v_Import_View_Name, v_Import_View_Check_Name, v_Has_Scalar_Primary_Key
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		COMMIT;
		v_Stat := 'INSERT INTO ' || v_Import_View_Name || chr(10)
		|| 'SELECT * ' || chr(10)
		|| 'FROM ' || v_Import_Table_Name || ' A' || chr(10)
		|| 'WHERE LINE_NO$ NOT IN (SELECT LINE_NO$ FROM ' || v_Import_View_Check_Name || ' B' || chr(10)
		|| '    WHERE CONSTRAINT_TYPE != ' || DBMS_ASSERT.ENQUOTE_LITERAL('R+') || chr(10)
		|| '    AND B.IMPORTJOB_ID$ = :a' || chr(10)
		|| ')'
		|| 'AND IMPORTJOB_ID$ = :a' || chr(10);
    	DBMS_OUTPUT.PUT_LINE('---');
    	DBMS_OUTPUT.PUT_LINE(v_Stat);

    	import_utl.Set_Job_ID(p_Import_Job_ID);
		EXECUTE IMMEDIATE v_Stat USING IN p_Import_Job_ID, p_Import_Job_ID;
		p_Row_Count := SQL%ROWCOUNT;

		Link_Import_Table(p_Table_Name, p_Import_Job_ID, v_Count);
		COMMIT;
	END Import_From_Imp_Table;

    PROCEDURE Export_To_Imp_Table (
        p_Table_Name 	IN VARCHAR2,
    	p_Import_Job_ID IN NUMBER,
    	p_Row_Limit 	IN NUMBER DEFAULT 1000000,
        p_Row_Count 	OUT NUMBER
    )
    IS
        v_Stat 						VARCHAR2(1000);
        v_Count 					INTEGER;
        v_Table_Name 				VARCHAR2(50) := UPPER(p_Table_Name);
        v_Import_Table_Name 		VARCHAR2(50);
        v_Import_View_Name 			VARCHAR2(50);
    BEGIN
        SELECT IMPORT_TABLE_NAME, IMPORT_VIEW_NAME
        INTO v_Import_Table_Name, v_Import_View_Name
        FROM VUSER_TABLES_IMP
        WHERE VIEW_NAME = v_Table_Name;

		COMMIT;
		v_Stat :=
		'INSERT INTO ' || v_Import_Table_Name
		|| ' SELECT * FROM ' || v_Import_View_Name || chr(10)
        || 'WHERE ROWNUM <= :a';
    	DBMS_OUTPUT.PUT_LINE('---');
    	DBMS_OUTPUT.PUT_LINE(v_Stat);

    	import_utl.Set_Job_ID(p_Import_Job_ID);
        EXECUTE IMMEDIATE v_Stat USING IN p_Row_Limit;
		p_Row_Count := SQL%ROWCOUNT;
		COMMIT;
	END Export_To_Imp_Table;

	FUNCTION Blob_to_Clob(
		p_blob IN BLOB,
		p_blob_charset IN VARCHAR2 DEFAULT NULL
	)  return CLOB
	is
	  v_clob	NCLOB;
	  v_dstoff	PLS_INTEGER := 1;
	  v_srcoff	PLS_INTEGER := 1;
	  v_langctx PLS_INTEGER := 0;
	  v_warning PLS_INTEGER := 1;
	  v_blob_csid NUMBER;
	begin
		v_blob_csid := nvl(nls_charset_id(p_blob_charset), nls_charset_id('AL32UTF8'));

		if dbms_lob.getlength(p_blob) > 0 then
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

	FUNCTION Split_Clob(
		p_clob IN CLOB,
		p_delimiter IN VARCHAR2
	) RETURN sys.odciVarchar2List PIPELINED	-- VARCHAR2(4000)
	IS
		v_dellen    CONSTANT INTEGER := length(p_delimiter);
		v_pos2 		INTEGER			:= dbms_lob.getlength(p_clob);
		v_pos  		INTEGER			:= 1;
		v_linelen	INTEGER;
	begin
		if p_clob IS NOT NULL then
			loop
				exit when v_pos2 = 0;
				v_pos2 := dbms_lob.instr( p_clob, p_delimiter, v_pos );
				v_linelen := case when v_pos2 >= v_pos
					then least(v_pos2 - v_pos, g_linemaxsize)
					else g_linemaxsize end;
				pipe row( dbms_lob.substr( p_clob, v_linelen, v_pos ) );
				v_pos := v_pos2 + v_dellen;
			end loop;
		end if;
		return ;
	END Split_Clob;

	PROCEDURE Filter_Csv_File (
		p_File_Name			IN VARCHAR2,
		p_Import_From		IN OUT VARCHAR2, -- UPLOAD or PASTE
		p_Clob_Content		IN CLOB DEFAULT NULL,
		p_Column_Delimiter  IN VARCHAR2 DEFAULT '\t',
		p_Row_Rows_Limit	IN NUMBER DEFAULT 100,
		p_Return_Bad_Rows 	OUT CLOB
	)
	is
		v_Clob   			CLOB;
		v_Bad_Result 		CLOB;
		v_Good_Result 		CLOB;
		v_Line_Delimiter 	VARCHAR2(10);
		v_Column_Delimiter 	VARCHAR2(10);
		v_Row_Line 			VARCHAR2(32767);
		v_Bad_Rows_Cnt 		NUMBER := 0;
		v_Column_Cnt 		NUMBER;
		v_Offset	 		NUMBER;
		FUNCTION Decode_Delimiter(
			p_delimiter IN VARCHAR2
		)
		RETURN VARCHAR2
		IS
		BEGIN
			return case p_delimiter
				when '\t' then chr(9)
				when '\n' then chr(10)
				when '\r' then chr(13)
				else p_delimiter
			end;
		END Decode_Delimiter;

	begin
		dbms_lob.createtemporary(v_Clob, true, dbms_lob.call);
		dbms_lob.createtemporary(v_Bad_Result, true, dbms_lob.call);
		dbms_lob.createtemporary(v_Good_Result, true, dbms_lob.call);

		v_Column_Delimiter := Decode_Delimiter(p_Column_Delimiter);

		if p_Import_From = 'UPLOAD' then
			if LOWER(p_File_Name) NOT LIKE '%.csv' or  p_File_Name IS NULL then
				return;
			end if;
			SELECT Blob_to_Clob(T.Blob_Content)
			INTO v_Clob
			-- FROM APEX_APPLICATION_TEMP_FILES T
			FROM WWV_FLOW_FILES T
			WHERE T.Name = p_File_Name;
		elsif p_Import_From = 'PASTE' then
			SELECT clob001
			INTO v_clob
			FROM apex_collections
			WHERE collection_name = 'CLOB_CONTENT';
		else
			v_Clob := p_Clob_Content;
		end if;
		-- try line deleimiter \n
		v_Line_Delimiter := Decode_Delimiter('\n');
		v_Offset   := INSTR(v_Clob, v_Line_Delimiter);
		if v_Offset = 0 then
			-- try line deleimiter \r
			v_Line_Delimiter := Decode_Delimiter('\r');
			v_Offset   := INSTR(v_Clob, v_Line_Delimiter);
		end if;
		if v_Offset <= 1 or v_Offset >= 32767  then
			return;
		end if;

		v_Row_Line := SUBSTR(v_Clob, 1, v_Offset - 1);
		v_Column_Cnt := LENGTH(v_Row_Line) - LENGTH(REPLACE(v_Row_Line, v_Column_Delimiter));
		for c_rows in (
			SELECT S.Column_Value, ROWNUM Line_No
			FROM TABLE( import_utl.Split_Clob(v_Clob, v_Line_Delimiter) ) S
		)
		loop
			if c_rows.Column_Value IS NOT NULL then
				v_Row_Line := c_rows.Column_Value || v_Line_Delimiter;
				-- check count of columns
				if INSTR(v_Row_Line, p_Column_Delimiter, 1, v_Column_Cnt) = 0 then
					v_Bad_Rows_Cnt := v_Bad_Rows_Cnt + 1;
					if v_Bad_Rows_Cnt <= p_Row_Rows_Limit then
						v_Row_Line := 'Row ' || c_rows.Line_No || ' : ' || v_Row_Line;
						dbms_lob.writeappend(v_Bad_Result, length(v_Row_Line), v_Row_Line);
					end if;
				else
					dbms_lob.writeappend(v_Good_Result, length(v_Row_Line), v_Row_Line);
				end if;
			end if;
		end loop;
		if p_Import_From = 'PASTE' then
			APEX_COLLECTION.UPDATE_MEMBER (
				p_collection_name => 'CLOB_CONTENT',
				p_seq => '1',
				p_clob001 => v_Good_Result
			);
		elsif p_Import_From = 'UPLOAD' then
			begin
			  APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION (p_collection_name=>'CLOB_CONTENT');
			exception
			  when dup_val_on_index then null;
			end;
			APEX_COLLECTION.ADD_MEMBER (
				p_collection_name => 'CLOB_CONTENT',
				p_clob001 => v_Good_Result
			);
			p_Import_From := 'PASTE';
		end if;
		p_Return_Bad_Rows  := v_Bad_Result;
	end Filter_Csv_File;

    PROCEDURE Refresh_MViews (
    	p_Schema_Name VARCHAR2 DEFAULT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
    )
    IS
        v_context binary_integer := NVL(MOD(NV('APP_SESSION'), POWER(2,31)), 0);		-- context is of type BINARY_INTEGER
    BEGIN
		data_browser_jobs.Refresh_MViews(p_Schema_Name, v_context);
	END Refresh_MViews;
END import_utl;
/
show errors

/*
exec import_utl.Refresh_MViews;
call wema_vpd.VPD_Refresh_Recomp(USER, 0);

@/WeMa/Projekt/WeCoScripts/wema_vpd_import_utl.sql


call set_weco_ctx.set_current_workspace(USER);
call set_weco_ctx.set_current_USER('DIRK');
SELECT * FROM TABLE ( import_utl.column_value_list ('SELECT * FROM CHANGE_LOG_CONFIG WHERE ID = :search_value', 1));

SET SERVEROUTPUT ON
SET LONG 2000000
SET PAGESIZE 0
SET LINESIZE 32767
call compile_invalid();

SELECT import_utl.Get_Imp_Markup_Query('ARECHNUNG', 1020, 59, 'NO', 'YES', 'NO' ) X FROM DUAL;
SELECT data_browser_select.Get_Imp_Table_Query( 'ARECHNUNG' ) X FROM DUAL;
SELECT data_browser_select.Get_Imp_Table_Query( 'ARECHNUNG', 1000, 'ALL' ) X FROM DUAL;

call set_weco_ctx.set_current_workspace(USER);
call set_weco_ctx.set_current_USER('DIRK');
declare
     v_Row_Count INTEGER;
begin
    import_utl.Export_To_Imp_Table (
    p_Table_Name 	=>'KOSTENSTELLEN',
    p_Import_Job_ID =>2000,
    p_Row_Limit 	=> 1000,
    p_Row_Count 	=>v_Row_Count
    );
    DBMS_OUTPUT.PUT_LINE('---');
    DBMS_OUTPUT.PUT_LINE(v_Row_Count || ' rows inserted ');
end;
/

call set_weco_ctx.set_current_workspace('TESTSPACE001');
call set_weco_ctx.set_current_USER('DIRK');

DELETE FROM MANDANTEN;

call import_utl.Set_Job_ID(1323);
declare
     v_Row_Count INTEGER;
begin
    import_utl.Import_From_Imp_Table (
    p_Table_Name 	=>'MANDANTEN',
    p_Import_Job_ID =>1323,
    p_Row_Count 	=>v_Row_Count
    );
    DBMS_OUTPUT.PUT_LINE('---');
    DBMS_OUTPUT.PUT_LINE(v_Row_Count || ' rows inserted ');
end;
/

*/
