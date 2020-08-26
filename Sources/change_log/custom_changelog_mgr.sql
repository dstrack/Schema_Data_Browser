CREATE OR REPLACE PACKAGE custom_changelog_mgr
AUTHID DEFINER
IS
    PROCEDURE RelinkLog (
        p_Table_Name IN VARCHAR2,
        p_Old_Object_ID  IN INTEGER,
        p_New_Object_ID  IN INTEGER,
        p_WORKSPACE_ID IN INTEGER DEFAULT NULL
	);

	FUNCTION Get_ChangeLogRelinkFunction (
		p_Table_Name VARCHAR2,
		p_Old_Object_Ref VARCHAR2,
		p_New_Object_Ref VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC;

    PROCEDURE  Synchronize_Changelog (
    	p_Target_Workspace_ID INTEGER,
    	p_Template_Workspace_ID INTEGER
    );

	PROCEDURE Synchronize_Changelog_Job (
		p_Source_Link IN VARCHAR2,
		p_Sync_Start_Date IN TIMESTAMP,
		p_Sync_End_Date IN TIMESTAMP
	);

END custom_changelog_mgr;
/
show errors



CREATE OR REPLACE PACKAGE BODY custom_changelog_mgr IS

	-- when an instead of UPDATE trigger for views with BLOB columns to preserve old BLOB is executed,
	-- then UpdateLog is called to relink the matching changelog rows to the before image rows with a new serial primary key.
    PROCEDURE RelinkLog (
        p_Table_Name IN VARCHAR2,
        p_Old_Object_ID  IN INTEGER,
        p_New_Object_ID  IN INTEGER,
        p_WORKSPACE_ID IN INTEGER DEFAULT NULL
    )
    IS
    	v_Workspace_ID  SIMPLE_INTEGER := NVL(p_WORKSPACE_ID, custom_changelog.Get_Current_Workspace_ID);
    	v_Table_ID		SIMPLE_INTEGER := custom_changelog.Changelog_Table_ID(p_Table_Name);
    BEGIN
    	UPDATE CHANGE_LOG_BT SET OBJECT_ID = p_New_Object_ID
    	WHERE TABLE_ID = v_Table_ID
    	AND OBJECT_ID = p_Old_Object_ID
    	AND WORKSPACE$_ID = v_Workspace_ID;
    END;

	FUNCTION Get_ChangeLogRelinkFunction (
		p_Table_Name VARCHAR2,
		p_Old_Object_Ref VARCHAR2,
		p_New_Object_Ref VARCHAR2
	) RETURN VARCHAR2 DETERMINISTIC
	IS
	BEGIN
		RETURN 'custom_changelog.RelinkLog(' || DBMS_ASSERT.ENQUOTE_LITERAL(p_Table_Name) || ', ' || p_Old_Object_Ref || ', ' || p_New_Object_Ref || ');';
    END;

	-- Synchronize Changelog entries in p_Workspace_ID with entries in p_Template_ID
    PROCEDURE  Synchronize_Changelog (
    	p_Target_Workspace_ID INTEGER,
    	p_Template_Workspace_ID INTEGER
    )
    IS
    BEGIN
    	INSERT INTO CHANGE_LOG_USERS_BT (ID, USER_NAME, WORKSPACE$_ID)
		SELECT ID, USER_NAME, p_Target_Workspace_ID WORKSPACE$_ID
		FROM CHANGE_LOG_USERS_BT S
		WHERE WORKSPACE$_ID = p_Template_Workspace_ID
		AND NOT EXISTS (
			SELECT 1
			FROM CHANGE_LOG_USERS_BT D
			WHERE D.USER_NAME = S.USER_NAME
			AND D.WORKSPACE$_ID = p_Target_Workspace_ID
		);

		MERGE INTO CHANGE_LOG_BT D
		USING (SELECT A.ID, A.TABLE_ID, A.OBJECT_ID, A.ACTION_CODE, A.IS_HIDDEN, D.ID USER_ID, A.LOGGING_DATE,
			CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
			CHANGELOG_ITEMS, p_Target_Workspace_ID WORKSPACE$_ID
		FROM CHANGE_LOG_BT A
		JOIN CHANGE_LOG_USERS_BT S ON S.ID = A.USER_ID AND S.WORKSPACE$_ID = A.WORKSPACE$_ID
		JOIN CHANGE_LOG_USERS_BT D ON D.USER_NAME = S.USER_NAME AND D.WORKSPACE$_ID = p_Target_Workspace_ID
		WHERE A.WORKSPACE$_ID = p_Template_Workspace_ID) S
		ON (D.WORKSPACE$_ID = S.WORKSPACE$_ID AND D.LOGGING_DATE = S.LOGGING_DATE AND D.ID = S.ID)
		WHEN MATCHED THEN
			UPDATE SET D.TABLE_ID = S.TABLE_ID,
			D.OBJECT_ID = S.OBJECT_ID, D.ACTION_CODE = S.ACTION_CODE, D.IS_HIDDEN = S.IS_HIDDEN, D.USER_ID = S.USER_ID,
			D.CUSTOM_REF_ID1 = S.CUSTOM_REF_ID1, D.CUSTOM_REF_ID2 = S.CUSTOM_REF_ID2, D.CUSTOM_REF_ID3 = S.CUSTOM_REF_ID3,
			D.CUSTOM_REF_ID4 = S.CUSTOM_REF_ID4, D.CUSTOM_REF_ID5 = S.CUSTOM_REF_ID5, D.CUSTOM_REF_ID6 = S.CUSTOM_REF_ID6,
			D.CUSTOM_REF_ID7 = S.CUSTOM_REF_ID7, D.CUSTOM_REF_ID8 = S.CUSTOM_REF_ID8, D.CUSTOM_REF_ID9 = S.CUSTOM_REF_ID9,
			D.CHANGELOG_ITEMS = S.CHANGELOG_ITEMS
		WHEN NOT MATCHED THEN
			INSERT (D.ID, D.TABLE_ID, D.OBJECT_ID, D.ACTION_CODE, D.IS_HIDDEN, D.USER_ID, D.LOGGING_DATE,
				D.CUSTOM_REF_ID1, D.CUSTOM_REF_ID2, D.CUSTOM_REF_ID3, D.CUSTOM_REF_ID4, D.CUSTOM_REF_ID5, D.CUSTOM_REF_ID6, D.CUSTOM_REF_ID7, D.CUSTOM_REF_ID8, D.CUSTOM_REF_ID9,
				D.CHANGELOG_ITEMS, D.WORKSPACE$_ID)
			VALUES (S.ID, S.TABLE_ID, S.OBJECT_ID, S.ACTION_CODE, S.IS_HIDDEN, S.USER_ID, S.LOGGING_DATE,
				S.CUSTOM_REF_ID1, S.CUSTOM_REF_ID2, S.CUSTOM_REF_ID3, S.CUSTOM_REF_ID4, S.CUSTOM_REF_ID5, S.CUSTOM_REF_ID6, S.CUSTOM_REF_ID7, S.CUSTOM_REF_ID8, S.CUSTOM_REF_ID9,
				S.CHANGELOG_ITEMS, S.WORKSPACE$_ID)
		;
    END;

    FUNCTION Get_Limit_ID (
        p_Table_Name    IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2
    )
    RETURN NUMBER
    IS
        v_Stat              VARCHAR2(400);
        stat_cur            SYS_REFCURSOR;
        v_ID                NUMBER;
    BEGIN
        v_Stat := 'SELECT NVL(MAX(' || DBMS_ASSERT.ENQUOTE_NAME(p_Primary_Key_Col) || '), 0) ID ' ||
            ' FROM ' || DBMS_ASSERT.ENQUOTE_NAME(p_Table_Name);
        OPEN  stat_cur FOR v_Stat;
        FETCH stat_cur INTO v_ID;
        RETURN v_ID;
    EXCEPTION
    WHEN others THEN
        DBMS_OUTPUT.PUT_LINE('-- Error with : ' || v_Stat);
        DBMS_OUTPUT.PUT_LINE('-- SQL Error  : ' || SQLCODE || ' ' || SQLERRM);
        return NULL;
    END;

    PROCEDURE  Adjust_Table_Sequence (
        p_Table_Name    IN VARCHAR2,
        p_Short_Name    IN VARCHAR2,
        p_Primary_Key_Col IN VARCHAR2,
        p_StartSeq      IN INTEGER
    )
    IS
        v_LimitID               INTEGER := -1;
        v_Stat                  VARCHAR2(4000);
    BEGIN
		v_LimitID := GREATEST(Get_Limit_ID(p_Table_Name, p_Primary_Key_Col), p_StartSeq - 1);
		v_Stat := 'DROP SEQUENCE ' || changelog_conf.Get_Sequence_Name (p_Short_Name);
		EXECUTE IMMEDIATE v_Stat;

		v_Stat := 'CREATE SEQUENCE ' || changelog_conf.Get_Sequence_Name (p_Short_Name) ||
			' START WITH ' || (v_LimitID + 1) || ' INCREMENT BY 1 ' || changelog_conf.Get_SequenceOptions;
		EXECUTE IMMEDIATE v_Stat;
    END;

	PROCEDURE Synchronize_Changelog_Job (
		p_Source_Link IN VARCHAR2,
		p_Sync_Start_Date IN TIMESTAMP,
		p_Sync_End_Date IN TIMESTAMP
	)
	IS
		v_Stat VARCHAR2(4000);
	BEGIN
		v_Stat :=
		'INSERT INTO CHANGE_LOG_USERS_BT ( ID, USER_NAME,  WORKSPACE$_ID )
		SELECT ID, USER_NAME,  WORKSPACE$_ID
		FROM CHANGE_LOG_USERS_BT@' || p_Source_Link || ' S
		WHERE NOT EXISTS (
			SELECT 1
			FROM CHANGE_LOG_USERS_BT T
			WHERE T.ID = S.ID
			AND T.WORKSPACE$_ID = S.WORKSPACE$_ID
		)';
		EXECUTE IMMEDIATE v_Stat;
		if SQL%ROWCOUNT > 0 then
			Adjust_Table_Sequence('CHANGE_LOG_USERS_BT', 'CHANGELOG_USERS', 'ID', 1000);
		end if;
		v_Stat :=
		'INSERT INTO CHANGE_LOG_TABLES ( ID, TABLE_NAME, VIEW_NAME )
		SELECT ID, TABLE_NAME, VIEW_NAME
		FROM CHANGE_LOG_TABLES@' || p_Source_Link || ' S
		WHERE NOT EXISTS (
			SELECT 1
			FROM CHANGE_LOG_TABLES T
			WHERE T.ID = S.ID
		)';
		EXECUTE IMMEDIATE v_Stat;
		if SQL%ROWCOUNT > 0 then
			Adjust_Table_Sequence('CHANGE_LOG_TABLES', 'CHANGE_LOG_TABLES', 'ID', 1000);
		end if;

		v_Stat :=
		'INSERT INTO ' || custom_changelog.Get_ChangeLogTable || ' (WORKSPACE$_ID,  ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
			CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
			CHANGELOG_ITEMS )
		SELECT WORKSPACE$_ID, ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
			CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9,
			CAST(COLLECT(CHANGELOG_ITEM_GTYPE(COLUMN_ID, AFTER_VALUE)) AS CHANGELOG_ITEM_ARRAY_GTYPE) CHANGELOG_ITEMS
		FROM VCHANGELOG_ITEM@' || p_Source_Link || ' A
		WHERE A.LOGGING_DATE > :a AND A.LOGGING_DATE <= :b
		AND NOT EXISTS (
			SELECT 1
			FROM CHANGE_LOG_BT T
			WHERE T.ID = A.ID
			AND T.WORKSPACE$_ID = A.WORKSPACE$_ID
			AND T.LOGGING_DATE = A.LOGGING_DATE
		)
		GROUP BY WORKSPACE$_ID, ID, TABLE_ID, OBJECT_ID, ACTION_CODE, IS_HIDDEN, USER_ID, LOGGING_DATE,
			CUSTOM_REF_ID1, CUSTOM_REF_ID2, CUSTOM_REF_ID3, CUSTOM_REF_ID4, CUSTOM_REF_ID5, CUSTOM_REF_ID6, CUSTOM_REF_ID7, CUSTOM_REF_ID8, CUSTOM_REF_ID9';
		EXECUTE IMMEDIATE v_Stat USING IN p_Sync_Start_Date, p_Sync_End_Date;
		DBMS_OUTPUT.PUT_LINE('-- copy CHANGE_LOG ' || TO_CHAR(SQL%ROWCOUNT) || ' rows');
		if SQL%ROWCOUNT > 0 then
			Adjust_Table_Sequence(custom_changelog.Get_ChangeLogTable, 'CHANGE_LOG', 'ID', 1000000);
		end if;
	END;
END custom_changelog_mgr;
/
show errors
