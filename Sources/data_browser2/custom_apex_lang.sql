
/*
DROP PACKAGE APEX_LANG;
DROP SEQUENCE APP_DYNAMIC_TRANSLATIONS_SEQ;
DROP TABLE APP_DYNAMIC_TRANSLATIONS;
*/

/*
-- list dynamic translations for app 2000
select 
    t.id                             message_id,
    t.translate_from_text            from_message,
    t.translate_to_text              to_message,
    t.translate_to_lang_code         language_code,
    t.last_updated_by                last_updated_by,
    t.last_updated_on                last_updated_on 
from apex_190100.wwv_flow_dynamic_translations$ t
where t.flow_id = 2000;

*/

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'APP_DYNAMIC_TRANSLATIONS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE "APP_DYNAMIC_TRANSLATIONS" 
		(
			"ID" NUMBER NOT NULL, 
			"FLOW_ID" NUMBER NOT NULL, 
			"TRANSLATE_TO_LANG_CODE" VARCHAR2(30), 
			"TRANSLATE_FROM_LANG_CODE" VARCHAR2(30), 
			"TRANSLATE_FROM_TEXT" VARCHAR2(4000), 
			"TRANSLATE_TO_TEXT" VARCHAR2(4000), 
			"LAST_UPDATED_BY" VARCHAR2(255) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')), 
			"LAST_UPDATED_ON" DATE DEFAULT SYSDATE,
			CONSTRAINT APP_DYNAMIC_TRANSLATIONS_PK PRIMARY KEY (ID) USING INDEX  ENABLE, 
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SPRINGY_DIAGRAMS_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE APP_DYNAMIC_TRANSLATIONS_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	
	v_stat := q'[
	CREATE OR REPLACE TRIGGER SPRINGY_DIAGRAMS_BI_TR 
	BEFORE INSERT ON SPRINGY_DIAGRAMS FOR EACH ROW 
	BEGIN 
		if :new.ID is null then 
			SELECT APP_DYNAMIC_TRANSLATIONS_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if; 
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER SPRINGY_DIAGRAMS_BU_TR 
	BEFORE UPDATE ON SPRINGY_DIAGRAMS FOR EACH ROW
	BEGIN
		:new.LAST_UPDATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_UPDATED_ON := SYSDATE;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/
show errors

	


CREATE OR REPLACE PACKAGE APEX_LANG
AS
	function message (
		p_name                      in varchar2 default null,
		p0                          in varchar2 default null,
		p1                          in varchar2 default null,
		p2                          in varchar2 default null,
		p3                          in varchar2 default null,
		p4                          in varchar2 default null,
		p5                          in varchar2 default null,
		p6                          in varchar2 default null,
		p7                          in varchar2 default null,
		p8                          in varchar2 default null,
		p9                          in varchar2 default null,
		p_lang                      in varchar2 default null,
		p_application_id            in number default null
	) return varchar2;
	procedure message_p (
		p_name                      in varchar2 default null,
		p0                          in varchar2 default null,
		p1                          in varchar2 default null,
		p2                          in varchar2 default null,
		p3                          in varchar2 default null,
		p4                          in varchar2 default null,
		p5                          in varchar2 default null,
		p6                          in varchar2 default null,
		p7                          in varchar2 default null,
		p8                          in varchar2 default null,
		p9                          in varchar2 default null,
		p_lang                      in varchar2 default null,
		p_application_id            in number   default null
	);
	function lang (
	   p_primary_text_string       in varchar2 default null,
	   p0                          in varchar2 default null,
	   p1                          in varchar2 default null,
	   p2                          in varchar2 default null,
	   p3                          in varchar2 default null,
	   p4                          in varchar2 default null,
	   p5                          in varchar2 default null,
	   p6                          in varchar2 default null,
	   p7                          in varchar2 default null,
	   p8                          in varchar2 default null,
	   p9                          in varchar2 default null,
	   p_primary_language          in varchar2 default null
	) return varchar2;
	procedure create_message(
		p_application_id in number,
		p_name           in varchar2,
		p_language       in varchar2,
		p_message_text   in varchar2 
	);
	procedure update_message(
		p_id           in number,
		p_message_text in varchar2 
	);
	procedure delete_message(
		p_id in number 
	);
	procedure update_translated_string(
		p_id       in number,
		p_language in varchar2,
		p_string   in varchar2
	);
	procedure seed_translations(
		p_application_id in number,
		p_language       in varchar2 
	);
	procedure create_language_mapping(
		p_application_id             in number,
		p_language                   in varchar2,
		p_translation_application_id in number
	);
	procedure update_language_mapping(
		p_application_id             in number,
		p_language                   in varchar2,
		p_new_trans_application_id   in number
	);
	procedure delete_language_mapping(
		p_application_id in number,
		p_language       in varchar2
	);
	procedure publish_application(
		p_application_id           in number,
		p_language                 in varchar2,
		p_new_trans_application_id in number default null 
	);
	procedure emit_language_selector_list;
end APEX_LANG;
/

CREATE OR REPLACE PACKAGE BODY APEX_LANG
AS
	g_primary_language          varchar2(100);
	
	function message (
		p_name                      in varchar2 default null,
		p0                          in varchar2 default null,
		p1                          in varchar2 default null,
		p2                          in varchar2 default null,
		p3                          in varchar2 default null,
		p4                          in varchar2 default null,
		p5                          in varchar2 default null,
		p6                          in varchar2 default null,
		p7                          in varchar2 default null,
		p8                          in varchar2 default null,
		p9                          in varchar2 default null,
		p_lang                      in varchar2 default null,
		p_application_id            in number default null
	) return varchar2
	is 
	begin
		return htmldb_lang.MESSAGE (p_name, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p_lang, p_application_id);
	end;
	
	procedure message_p (
		p_name                      in varchar2 default null,
		p0                          in varchar2 default null,
		p1                          in varchar2 default null,
		p2                          in varchar2 default null,
		p3                          in varchar2 default null,
		p4                          in varchar2 default null,
		p5                          in varchar2 default null,
		p6                          in varchar2 default null,
		p7                          in varchar2 default null,
		p8                          in varchar2 default null,
		p9                          in varchar2 default null,
		p_lang                      in varchar2 default null,
		p_application_id            in number   default null
	)
	is 
	begin
		htmldb_lang.MESSAGE_P (p_name, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p_lang, p_application_id);
	end;

	function lang (
	   p_primary_text_string       in varchar2 default null,
	   p0                          in varchar2 default null,
	   p1                          in varchar2 default null,
	   p2                          in varchar2 default null,
	   p3                          in varchar2 default null,
	   p4                          in varchar2 default null,
	   p5                          in varchar2 default null,
	   p6                          in varchar2 default null,
	   p7                          in varchar2 default null,
	   p8                          in varchar2 default null,
	   p9                          in varchar2 default null,
	   p_primary_language          in varchar2 default null
	) return varchar2
	is 
	   -- Return a translated text string from the
	   -- translatable messages repository within HTMLDB.
	   --
	   -- p_primary_text_string - text string to be translated
	   -- p0 - p9  - substitution parameters that replace text srings
	   --            %0 through %9
	   -- p_primary_text_context
	   -- p_primary_language    
		v_trans_text varchar2(32767);
	begin
		if g_primary_language IS NULL then 
			select APPLICATION_PRIMARY_LANGUAGE
			  into g_primary_language
			  from APEX_APPLICATIONS
			 where APPLICATION_ID = nv('APP_ID');
		end if;
		apex_debug.message(
			q'[APEX_LANG.LANG(p_primary_text_string=>'%s', p_primary_language=>'%s');]', 
			p_primary_text_string, 
			nvl(p_primary_language, g_primary_language)
		);
		INSERT INTO APP_DYNAMIC_TRANSLATIONS (FLOW_ID, TRANSLATE_FROM_TEXT)
		SELECT nv('APP_ID') FLOW_ID,
			p_primary_text_string TRANSLATE_FROM_TEXT
		FROM DUAL S
		WHERE NOT EXISTS (
			SELECT 1
			FROM APP_DYNAMIC_TRANSLATIONS T 
			WHERE T.FLOW_ID = S.FLOW_ID
			AND T.TRANSLATE_FROM_TEXT = S.TRANSLATE_FROM_TEXT
		);
		v_trans_text := htmldb_lang.LANG (p_primary_text_string, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p_primary_language);
		return v_trans_text;
	end;
	
	procedure create_message(
		p_application_id in number,
		p_name           in varchar2,
		p_language       in varchar2,
		p_message_text   in varchar2 
	)
	is
	begin -- not public 
		htmldb_lang.CREATE_MESSAGE ( p_application_id, p_name, p_language, p_message_text);
	end;

	procedure update_message(
		p_id           in number,
		p_message_text in varchar2 
	)
	is
	begin
		htmldb_lang.UPDATE_MESSAGE ( p_id, p_message_text);
	end;
	
	procedure delete_message (
		p_id in number 
	)
	is
	begin -- not public 
		htmldb_lang.DELETE_MESSAGE ( p_id);
	end;
	
	procedure update_translated_string(
		p_id       in number,
		p_language in varchar2,
		p_string   in varchar2
	)
	is 
	begin
		htmldb_lang.UPDATE_TRANSLATED_STRING ( p_id, p_language, p_string);
	end;
	
	procedure seed_translations(
		p_application_id in number,
		p_language       in varchar2 
	)
	is 
	begin 
		htmldb_lang.SEED_TRANSLATIONS ( p_application_id, p_language);
	end;
	
	procedure create_language_mapping(
		p_application_id             in number,
		p_language                   in varchar2,
		p_translation_application_id in number
	)
	is 
	begin 
		htmldb_lang.CREATE_LANGUAGE_MAPPING ( p_application_id, p_language, p_translation_application_id);	
	end;
	
	procedure update_language_mapping(
		p_application_id             in number,
		p_language                   in varchar2,
		p_new_trans_application_id   in number
	)
	is
	begin
		htmldb_lang.UPDATE_LANGUAGE_MAPPING ( p_application_id, p_language, p_new_trans_application_id);
	end;
	
	procedure delete_language_mapping(
		p_application_id in number,
		p_language       in varchar2
	)
	is
	begin
		htmldb_lang.DELETE_LANGUAGE_MAPPING ( p_application_id, p_language);
	end;

	procedure publish_application(
		p_application_id           in number,
		p_language                 in varchar2,
		p_new_trans_application_id in number default null 
	)
	is 
	begin 
		htmldb_lang.PUBLISH_APPLICATION ( p_application_id, p_language, p_new_trans_application_id);
	end;
	
	procedure emit_language_selector_list
	is
	begin
		htmldb_lang.EMIT_LANGUAGE_SELECTOR_LIST;
	end;
end APEX_LANG;
/


