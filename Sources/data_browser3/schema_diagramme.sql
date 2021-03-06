/*
Copyright 2019 Dirk Strack, Strack Software Development

Licensed under the Apache License, Version 2.0 (the License);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an AS IS BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'SPRINGY_DIAGRAMS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE SPRINGY_DIAGRAMS 
		   (	ID NUMBER NOT NULL ENABLE, 
			DESCRIPTION VARCHAR2(512) NOT NULL ENABLE, 
			PROTECTED VARCHAR2(1) DEFAULT 'N' NOT NULL ENABLE, 
			FONTSIZE FLOAT DEFAULT 4 NOT NULL,
			ZOOM_FACTOR FLOAT DEFAULT 1 NOT NULL,
			X_OFFSET FLOAT DEFAULT 0 NOT NULL,
			Y_OFFSET FLOAT DEFAULT 0 NOT NULL,
			CANVAS_WIDTH NUMBER,
			EXCLUDE_SINGLES	VARCHAR2(5) DEFAULT 'NO' NOT NULL CONSTRAINT SPRINGY_DIAG_EXCL_SINGLE_CK CHECK ( Exclude_Singles IN ('YES','NO') ),
			EDGE_LABELS	VARCHAR2(5) DEFAULT 'NO' NOT NULL     CONSTRAINT SPRINGY_DIAG_EDGE_LABELS_CK CHECK ( Edge_Labels IN ('YES','NO','BOXES') ),
			STIFFNESS FLOAT DEFAULT 400 NOT NULL,
			REPULSION FLOAT DEFAULT 2000 NOT NULL,
			DAMPING FLOAT DEFAULT 0.15 NOT NULL,
			MINENERGYTHRESHOLD FLOAT DEFAULT 0.01 NOT NULL,
			MAXSPEED FLOAT DEFAULT 50 NOT NULL,
			PINWEIGHT FLOAT DEFAULT 10 NOT NULL,
			EXCITE_METHOD VARCHAR2(50) DEFAULT 'none' NOT NULL CONSTRAINT SPRINGY_DIAG_EXCITE_METHOD_CK 
				CHECK (EXCITE_METHOD IN ('none', 'selected', 'downstream', 'upstream', 'connected')),
			CREATED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			CREATED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			LAST_MODIFIED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			LAST_MODIFIED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			 CONSTRAINT SPRINGY_DIAGRAMS_PROT_CK CHECK (PROTECTED in ('Y','N')) ENABLE, 
			 CONSTRAINT SPRINGY_DIAGRAMS_PK PRIMARY KEY (ID) USING INDEX  ENABLE, 
			 CONSTRAINT SPRINGY_DIAGRAMS_DESC_UN UNIQUE (DESCRIPTION) USING INDEX  ENABLE
		   )
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SPRINGY_DIAGRAMS_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE SPRINGY_DIAGRAMS_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;

	v_stat := q'[
	CREATE OR REPLACE TRIGGER SPRINGY_DIAGRAMS_BI_TR 
	BEFORE INSERT ON SPRINGY_DIAGRAMS FOR EACH ROW 
	BEGIN 
		if :new.ID is null then 
			SELECT SPRINGY_DIAGRAMS_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if; 
		:new.CREATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.CREATED_AT := LOCALTIMESTAMP;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER SPRINGY_DIAGRAMS_BU_TR 
	BEFORE UPDATE ON SPRINGY_DIAGRAMS FOR EACH ROW
	BEGIN
			:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
			:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/
   
declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DIAGRAM_SHAPES';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DIAGRAM_SHAPES 
		   (	ID NUMBER NOT NULL ENABLE, 
			DESCRIPTION VARCHAR2(512) NOT NULL ENABLE, 
			ACTIVE VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
			CREATED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			CREATED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			LAST_MODIFIED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			LAST_MODIFIED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			 CONSTRAINT DIAG_SHAPES_AKTIV_CK CHECK (ACTIVE in ('Y','N')) ENABLE, 
			 CONSTRAINT DIAG_SHAPES_PK PRIMARY KEY (ID) USING INDEX  ENABLE, 
			 CONSTRAINT DIAG_SHAPES_DESC_UN UNIQUE (DESCRIPTION)
		  USING INDEX  ENABLE
		   )
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'DIAG_EDGES_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE DIAG_SHAPES_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_SHAPES_BI_TR 
	BEFORE INSERT ON DIAGRAM_SHAPES FOR EACH ROW 
	BEGIN 
		if :new.ID is null then 
			SELECT DIAG_SHAPES_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if; 
		:new.CREATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.CREATED_AT := LOCALTIMESTAMP;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_SHAPES_BU_TR 
	BEFORE UPDATE ON DIAGRAM_SHAPES FOR EACH ROW
	BEGIN
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM DIAGRAM_SHAPES;
	if v_count = 0 then 
		v_stat := q'[
		begin
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('box');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('circle');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('diamond');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('doublebox');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('doublecircle');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('doubleoctagon');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('ellipse');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('folder');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('hexagon');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('house');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('invhouse');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('invtrapezium');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('invtriangle');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('none');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('octagon');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('parallelogram');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('pentagon');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('point');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('rectangle');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('septagon');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('star');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('trapezium');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('triangle');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('tripleoctagon');
			commit;
		end;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM DIAGRAM_SHAPES WHERE DESCRIPTION = 'box3d';
	if v_count = 0 then 
		v_stat := q'[
		begin
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('box3d');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('note');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('tab');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('component');
			commit;
		end;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM DIAGRAM_SHAPES WHERE DESCRIPTION = 'righttriangle';
	if v_count = 0 then 
		v_stat := q'[
		begin
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('righttriangle');
			Insert into DIAGRAM_SHAPES (DESCRIPTION) values ('lefttriangle');
			commit;
		end;
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
end;
/

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DIAGRAM_COLORS';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DIAGRAM_COLORS 
		   ( ID NUMBER NOT NULL ENABLE, 
			 COLOR_NAME VARCHAR2(128 CHAR) NOT NULL ENABLE, 
			 HEX_RGB VARCHAR2(50 CHAR), 
			 RED_RGB NUMBER, 
			 GREEN_RGB NUMBER, 
			 BLUE_RGB NUMBER, 
			 ACTIVE VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
			 CREATED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			 CREATED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			 LAST_MODIFIED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			 LAST_MODIFIED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			 CONSTRAINT DIAG_COLORS_AKTIV_CK CHECK (ACTIVE in ('Y','N')) ENABLE, 
			 CONSTRAINT DIAG_COLORS_PK PRIMARY KEY (ID) USING INDEX ENABLE, 
			 CONSTRAINT DIAG_COLORS_UK1 UNIQUE (COLOR_NAME) USING INDEX ENABLE,
			 CONSTRAINT DIAG_COLORS_UK2 UNIQUE (HEX_RGB) USING INDEX ENABLE
		   )
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'DIAG_COLORS_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE DIAG_COLORS_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_COLORS_BI_TR 
	BEFORE INSERT ON DIAGRAM_COLORS FOR EACH ROW 
	BEGIN 
		if :new.ID is null then 
			SELECT DIAG_COLORS_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if; 
		:new.CREATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.CREATED_AT := LOCALTIMESTAMP;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_COLORS_BU_TR 
	BEFORE UPDATE ON DIAGRAM_COLORS FOR EACH ROW
	BEGIN
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/

declare 
	v_count NUMBER;
	v_list VARCHAR2(32767);
	v_stat VARCHAR2(1000);
begin
	SELECT COUNT(*) INTO v_count
	FROM DIAGRAM_COLORS;
	if v_count = 0 then 
		v_list := q'[
('IndianRed', 'CD5C5C', 205, 92, 92)
('LightCoral', 'F08080', 240, 128, 128)
('Salmon', 'FA8072', 250, 128, 114)
('DarkSalmon', 'E9967A', 233, 150, 122)
('LightSalmon', 'FFA07A', 255, 160, 122)
('Crimson', 'DC143C', 220, 20, 60)
('Red', 'FF0000', 255, 0, 0)
('FireBrick', 'B22222', 178, 34, 34)
('DarkRed', '8B0000', 139, 0, 0)
('Pink', 'FFC0CB', 255, 192, 203)
('LightPink', 'FFB6C1', 255, 182, 193)
('HotPink', 'FF69B4', 255, 105, 180)
('DeepPink', 'FF1493', 255, 20, 147)
('MediumVioletRed', 'C71585', 199, 21, 133)
('PaleVioletRed', 'DB7093', 219, 112, 147)
('Coral', 'FF7F50', 255, 127, 80)
('Tomato', 'FF6347', 255, 99, 71)
('OrangeRed', 'FF4500', 255, 69, 0)
('DarkOrange', 'FF8C00', 255, 140, 0)
('Orange', 'FFA500', 255, 165, 0)
('Gold', 'FFD700', 255, 215, 0)
('Yellow', 'FFFF00', 255, 255, 0)
('LightYellow', 'FFFFE0', 255, 255, 224)
('LemonChiffon', 'FFFACD', 255, 250, 205)
('LightGoldenrodYellow', 'FAFAD2', 250, 250, 210)
('PapayaWhip', 'FFEFD5', 255, 239, 213)
('Moccasin', 'FFE4B5', 255, 228, 181)
('PeachPuff', 'FFDAB9', 255, 218, 185)
('PaleGoldenrod', 'EEE8AA', 238, 232, 170)
('Khaki', 'F0E68C', 240, 230, 140)
('DarkKhaki', 'BDB76B', 189, 183, 107)
('Lavender', 'E6E6FA', 230, 230, 250)
('Thistle', 'D8BFD8', 216, 191, 216)
('Plum', 'DDA0DD', 221, 160, 221)
('Violet', 'EE82EE', 238, 130, 238)
('Orchid', 'DA70D6', 218, 112, 214)
('Magenta', 'FF00FF', 255, 0, 255)
('MediumOrchid', 'BA55D3', 186, 85, 211)
('MediumPurple', '9370DB', 147, 112, 219)
('RebeccaPurple', '663399', 102, 51, 153)
('BlueViolet', '8A2BE2', 138, 43, 226)
('DarkViolet', '9400D3', 148, 0, 211)
('DarkOrchid', '9932CC', 153, 50, 204)
('DarkMagenta', '8B008B', 139, 0, 139)
('Purple', '800080', 128, 0, 128)
('Indigo', '4B0082', 75, 0, 130)
('SlateBlue', '6A5ACD', 106, 90, 205)
('DarkSlateBlue', '483D8B', 72, 61, 139)
('MediumSlateBlue', '7B68EE', 123, 104, 238)
('GreenYellow', 'ADFF2F', 173, 255, 47)
('Chartreuse', '7FFF00', 127, 255, 0)
('LawnGreen', '7CFC00', 124, 252, 0)
('Lime', '00FF00', 0, 255, 0)
('LimeGreen', '32CD32', 50, 205, 50)
('PaleGreen', '98FB98', 152, 251, 152)
('LightGreen', '90EE90', 144, 238, 144)
('MediumSpringGreen', '00FA9A', 0, 250, 154)
('SpringGreen', '00FF7F', 0, 255, 127)
('MediumSeaGreen', '3CB371', 60, 179, 113)
('SeaGreen', '2E8B57', 46, 139, 87)
('ForestGreen', '228B22', 34, 139, 34)
('Green', '008000', 0, 128, 0)
('DarkGreen', '006400', 0, 100, 0)
('YellowGreen', '9ACD32', 154, 205, 50)
('OliveDrab', '6B8E23', 107, 142, 35)
('Olive', '808000', 128, 128, 0)
('DarkOliveGreen', '556B2F', 85, 107, 47)
('MediumAquamarine', '66CDAA', 102, 205, 170)
('DarkSeaGreen', '8FBC8B', 143, 188, 139)
('LightSeaGreen', '20B2AA', 32, 178, 170)
('DarkCyan', '008B8B', 0, 139, 139)
('Teal', '008080', 0, 128, 128)
('Cyan', '00FFFF', 0, 255, 255)
('LightCyan', 'E0FFFF', 224, 255, 255)
('PaleTurquoise', 'AFEEEE', 175, 238, 238)
('Aquamarine', '7FFFD4', 127, 255, 212)
('Turquoise', '40E0D0', 64, 224, 208)
('MediumTurquoise', '48D1CC', 72, 209, 204)
('DarkTurquoise', '00CED1', 0, 206, 209)
('CadetBlue', '5F9EA0', 95, 158, 160)
('SteelBlue', '4682B4', 70, 130, 180)
('LightSteelBlue', 'B0C4DE', 176, 196, 222)
('PowderBlue', 'B0E0E6', 176, 224, 230)
('LightBlue', 'ADD8E6', 173, 216, 230)
('SkyBlue', '87CEEB', 135, 206, 235)
('LightSkyBlue', '87CEFA', 135, 206, 250)
('DeepSkyBlue', '00BFFF', 0, 191, 255)
('DodgerBlue', '1E90FF', 30, 144, 255)
('CornflowerBlue', '6495ED', 100, 149, 237)
('RoyalBlue', '4169E1', 65, 105, 225)
('Blue', '0000FF', 0, 0, 255)
('MediumBlue', '0000CD', 0, 0, 205)
('DarkBlue', '00008B', 0, 0, 139)
('Navy', '000080', 0, 0, 128)
('MidnightBlue', '191970', 25, 25, 112)
('Cornsilk', 'FFF8DC', 255, 248, 220)
('BlanchedAlmond', 'FFEBCD', 255, 235, 205)
('Bisque', 'FFE4C4', 255, 228, 196)
('NavajoWhite', 'FFDEAD', 255, 222, 173)
('Wheat', 'F5DEB3', 245, 222, 179)
('BurlyWood', 'DEB887', 222, 184, 135)
('Tan', 'D2B48C', 210, 180, 140)
('RosyBrown', 'BC8F8F', 188, 143, 143)
('SandyBrown', 'F4A460', 244, 164, 96)
('Goldenrod', 'DAA520', 218, 165, 32)
('DarkGoldenrod', 'B8860B', 184, 134, 11)
('Peru', 'CD853F', 205, 133, 63)
('Chocolate', 'D2691E', 210, 105, 30)
('SaddleBrown', '8B4513', 139, 69, 19)
('Sienna', 'A0522D', 160, 82, 45)
('Brown', 'A52A2A', 165, 42, 42)
('Maroon', '800000', 128, 0, 0)
('White', 'FFFFFF', 255, 255, 255)
('Snow', 'FFFAFA', 255, 250, 250)
('HoneyDew', 'F0FFF0', 240, 255, 240)
('MintCream', 'F5FFFA', 245, 255, 250)
('Azure', 'F0FFFF', 240, 255, 255)
('AliceBlue', 'F0F8FF', 240, 248, 255)
('GhostWhite', 'F8F8FF', 248, 248, 255)
('WhiteSmoke', 'F5F5F5', 245, 245, 245)
('SeaShell', 'FFF5EE', 255, 245, 238)
('Beige', 'F5F5DC', 245, 245, 220)
('OldLace', 'FDF5E6', 253, 245, 230)
('FloralWhite', 'FFFAF0', 255, 250, 240)
('Ivory', 'FFFFF0', 255, 255, 240)
('AntiqueWhite', 'FAEBD7', 250, 235, 215)
('Linen', 'FAF0E6', 250, 240, 230)
('LavenderBlush', 'FFF0F5', 255, 240, 245)
('MistyRose', 'FFE4E1', 255, 228, 225)
('Gainsboro', 'DCDCDC', 220, 220, 220)
('LightGray', 'D3D3D3', 211, 211, 211)
('Silver', 'C0C0C0', 192, 192, 192)
('DarkGray', 'A9A9A9', 169, 169, 169)
('Gray', '808080', 128, 128, 128)
('DimGray', '696969', 105, 105, 105)
('LightSlateGray', '778899', 119, 136, 153)
('SlateGray', '708090', 112, 128, 144)
('DarkSlateGray', '2F4F4F', 47, 79, 79)
('Black', '000000', 0, 0, 0)
		]';
		for l_cur in (
			select column_value vals from table (apex_string.split(v_list, chr(10)))
            where length(column_value) > 10
		) loop 
			v_Stat := 'insert into diagram_colors(color_name, hex_rgb, red_rgb, green_rgb, blue_rgb) values' || l_cur.vals;
			EXECUTE IMMEDIATE v_Stat;
		end loop;
		commit;
	end if;
end;
/


declare 
	v_count NUMBER;
	v_Def_Shape_Id DIAGRAM_SHAPES.ID%TYPE;
	v_stat VARCHAR2(32767);
begin
	SELECT ID INTO v_Def_Shape_Id 
	FROM DIAGRAM_SHAPES WHERE DESCRIPTION = 'ellipse';

	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DIAGRAM_NODES';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DIAGRAM_NODES 
		   (	ID NUMBER NOT NULL ENABLE, 
			SPRINGY_DIAGRAMS_ID NUMBER NOT NULL ENABLE, 
			DESCRIPTION VARCHAR2(512) NOT NULL ENABLE, 
			ACTIVE VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
			CREATED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			CREATED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			LAST_MODIFIED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			LAST_MODIFIED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			DIAGRAM_SHAPES_ID NUMBER DEFAULT ]' || v_Def_Shape_Id || q'[ NOT NULL ENABLE, 
			COLOR VARCHAR2(130), 
			X_COORDINATE FLOAT DEFAULT 0 NOT NULL,
			Y_COORDINATE FLOAT DEFAULT 0 NOT NULL,
			MASS  FLOAT DEFAULT 1 NOT NULL,
			HEX_RGB VARCHAR2(50 CHAR), 
			DIAGRAM_COLOR_ID NUMBER,
			 CONSTRAINT DIAG_NODES_AKTIV_CK CHECK (ACTIVE='Y' OR ACTIVE='N') ENABLE, 
			 CONSTRAINT DIAG_NODES_PK PRIMARY KEY (ID) USING INDEX  ENABLE, 
			 CONSTRAINT DIAG_NODES_DESC_UN UNIQUE (SPRINGY_DIAGRAMS_ID, DESCRIPTION) USING INDEX  ENABLE, 
			 CONSTRAINT DIAG_NODES_SPR_DIAG_ID_FK FOREIGN KEY (SPRINGY_DIAGRAMS_ID)
			  REFERENCES SPRINGY_DIAGRAMS (ID) ON DELETE CASCADE ENABLE, 
			 CONSTRAINT DIAG_NODES_DIAG_SHAPES_FK FOREIGN KEY (DIAGRAM_SHAPES_ID)
			  REFERENCES DIAGRAM_SHAPES (ID) ENABLE,
			 CONSTRAINT DIAGRAM_NODES_DIAGRAM_COLOR_FK FOREIGN KEY ( DIAGRAM_COLOR_ID ) 
			  REFERENCES DIAGRAM_COLORS ON DELETE SET NULL
		   )  
		]';
		EXECUTE IMMEDIATE v_Stat;
	else
		EXECUTE IMMEDIATE 'ALTER TABLE DIAGRAM_NODES MODIFY DIAGRAM_SHAPES_ID NUMBER DEFAULT ' || v_Def_Shape_Id;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'DIAG_NODES_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE DIAG_NODES_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER "DIAG_NODES_BI_TR" 
	BEFORE INSERT ON DIAGRAM_NODES FOR EACH ROW 
	BEGIN 
		if :new.ID is null then 
			SELECT DIAG_NODES_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if; 
		if :new.COLOR IS NOT NULL and :new.DIAGRAM_COLOR_ID IS NULL then 
			begin
				select ID, HEX_RGB 
				into :new.DIAGRAM_COLOR_ID, :new.HEX_RGB
				from DIAGRAM_COLORS 
				where COLOR_NAME = :new.COLOR;
			exception  when no_data_found then 
				null;
			end;
		end if;
		if :new.HEX_RGB IS NOT NULL and :new.DIAGRAM_COLOR_ID IS NULL then 
			begin
				select ID, COLOR_NAME
				into :new.DIAGRAM_COLOR_ID, :new.COLOR
				from DIAGRAM_COLORS 
				where HEX_RGB = :new.HEX_RGB;
			exception  when no_data_found then 
				null;
			end;
		end if;
		:new.CREATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.CREATED_AT := LOCALTIMESTAMP;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;	
	]';
	EXECUTE IMMEDIATE v_Stat;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_NODES_BU_TR 
	BEFORE UPDATE ON DIAGRAM_NODES FOR EACH ROW
	BEGIN
		if data_browser_conf.Compare_Data(:new.COLOR, :old.COLOR) then 
			begin
				select ID, HEX_RGB 
				into :new.DIAGRAM_COLOR_ID, :new.HEX_RGB
				from DIAGRAM_COLORS 
				where COLOR_NAME = :new.COLOR;
			exception  when no_data_found then 
				null;
			end;
		elsif  data_browser_conf.Compare_Data(:new.HEX_RGB, :old.HEX_RGB) then
			begin
				select ID, COLOR_NAME
				into :new.DIAGRAM_COLOR_ID, :new.COLOR
				from DIAGRAM_COLORS 
				where HEX_RGB = :new.HEX_RGB;
			exception  when no_data_found then 
				null;
			end;
		end if;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/

declare 
	v_count NUMBER;
	v_stat VARCHAR2(32767);
begin
	SELECT COUNT(*) INTO v_count
	FROM USER_TABLES WHERE TABLE_NAME = 'DIAGRAM_EDGES';
	if v_count = 0 then 
		v_stat := q'[
		CREATE TABLE DIAGRAM_EDGES 
		(	ID NUMBER NOT NULL ENABLE, 
			SOURCE_NODE_ID NUMBER NOT NULL ENABLE, 
			CREATED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			CREATED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			LAST_MODIFIED_AT TIMESTAMP (6) WITH LOCAL TIME ZONE DEFAULT LOCALTIMESTAMP NOT NULL ENABLE, 
			LAST_MODIFIED_BY VARCHAR2(32 CHAR) DEFAULT NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL ENABLE, 
			TARGET_NODE_ID NUMBER NOT NULL ENABLE, 
			DESCRIPTION VARCHAR2(128 CHAR), 
			COLOR VARCHAR2(128 CHAR) DEFAULT 'DarkGrey',
			HEX_RGB VARCHAR2(50 CHAR), 
			DIAGRAM_COLOR_ID NUMBER,
			SPRINGY_DIAGRAMS_ID NUMBER NOT NULL ENABLE, 
			 CONSTRAINT DIAG_EDGES_PK PRIMARY KEY (ID)
			USING INDEX  ENABLE, 
			 CONSTRAINT DIAG_EDGES_NODES_UK UNIQUE (SPRINGY_DIAGRAMS_ID, SOURCE_NODE_ID, TARGET_NODE_ID)
			USING INDEX  ENABLE, 
			 CONSTRAINT DIAG_EDGES_SOURCE_NODE_FK FOREIGN KEY (SOURCE_NODE_ID)
			  REFERENCES DIAGRAM_NODES (ID) ON DELETE CASCADE ENABLE, 
			 CONSTRAINT DIAG_EDGES_TARGET_NODE_FK FOREIGN KEY (TARGET_NODE_ID)
			  REFERENCES DIAGRAM_NODES (ID) ON DELETE CASCADE ENABLE, 
			 CONSTRAINT DIAG_EDGES_SPRINGY_DIAG_FK FOREIGN KEY (SPRINGY_DIAGRAMS_ID)
			  REFERENCES SPRINGY_DIAGRAMS (ID) ON DELETE CASCADE ENABLE,
			 CONSTRAINT DIAGRAM_EDGES_DIAGRAM_COLOR_FK FOREIGN KEY ( DIAGRAM_COLOR_ID ) 
			  REFERENCES DIAGRAM_COLORS ON DELETE SET NULL
		)
		]';
		EXECUTE IMMEDIATE v_Stat;
		v_stat := q'[
		CREATE INDEX DIAG_EDGES_DIAG_NODES_FKI ON DIAGRAM_EDGES (SOURCE_NODE_ID) 
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	
	SELECT COUNT(*) INTO v_count
	FROM USER_INDEXES WHERE TABLE_NAME = 'DIAGRAM_EDGES'
	AND INDEX_NAME = 'DIAG_EDGES_TARGET_NODE_FKI';
	if v_count = 0 then 
		v_stat := q'[
		CREATE INDEX DIAG_EDGES_TARGET_NODE_FKI ON DIAGRAM_EDGES(TARGET_NODE_ID)
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	SELECT COUNT(*) INTO v_count
	FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'DIAG_EDGES_SEQ';
	if v_count = 0 then 
		v_stat := q'[
		CREATE SEQUENCE DIAG_EDGES_SEQ START WITH 1 INCREMENT BY 1 NOCYCLE
		]';
		EXECUTE IMMEDIATE v_Stat;
	end if;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_EDGES_BI_TR 
	BEFORE INSERT ON DIAGRAM_EDGES FOR EACH ROW 
	BEGIN 
		if :new.ID is null then 
			SELECT DIAG_EDGES_SEQ.NEXTVAL INTO :new.ID FROM DUAL;
		end if; 
		if :new.COLOR IS NOT NULL and :new.DIAGRAM_COLOR_ID IS NULL then 
			begin
				select ID, HEX_RGB 
				into :new.DIAGRAM_COLOR_ID, :new.HEX_RGB
				from DIAGRAM_COLORS 
				where COLOR_NAME = :new.COLOR;
			exception  when no_data_found then 
				null;
			end;
		end if;
		if :new.HEX_RGB IS NOT NULL and :new.DIAGRAM_COLOR_ID IS NULL then 
			begin
				select ID, COLOR_NAME
				into :new.DIAGRAM_COLOR_ID, :new.COLOR
				from DIAGRAM_COLORS 
				where HEX_RGB = :new.HEX_RGB;
			exception  when no_data_found then 
				null;
			end;
		end if;
		:new.CREATED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.CREATED_AT := LOCALTIMESTAMP;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
	v_stat := q'[
	CREATE OR REPLACE TRIGGER DIAG_EDGES_BU_TR 
	BEFORE UPDATE ON DIAGRAM_EDGES FOR EACH ROW
	BEGIN
		if data_browser_conf.Compare_Data(:new.COLOR, :old.COLOR) then 
			begin
				select ID, HEX_RGB 
				into :new.DIAGRAM_COLOR_ID, :new.HEX_RGB
				from DIAGRAM_COLORS 
				where COLOR_NAME = :new.COLOR;
			exception  when no_data_found then 
				null;
			end;
		elsif  data_browser_conf.Compare_Data(:new.HEX_RGB, :old.HEX_RGB) then
			begin
				select ID, COLOR_NAME
				into :new.DIAGRAM_COLOR_ID, :new.COLOR
				from DIAGRAM_COLORS 
				where HEX_RGB = :new.HEX_RGB;
			exception  when no_data_found then 
				null;
			end;
		end if;
		:new.LAST_MODIFIED_BY := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), SYS_CONTEXT('USERENV','SESSION_USER'));
		:new.LAST_MODIFIED_AT := LOCALTIMESTAMP;
	END;
	]';
	EXECUTE IMMEDIATE v_Stat;
end;
/
/*
DROP TABLE DIAGRAM_EDGES;
DROP TABLE DIAGRAM_NODES;
DROP TABLE DIAGRAM_SHAPES;
DROP TABLE SPRINGY_DIAGRAMS;
DROP SEQUENCE DIAG_EDGES_SEQ;
DROP SEQUENCE DIAG_NODES_SEQ;
DROP SEQUENCE DIAG_SHAPES_SEQ;
DROP SEQUENCE SPRINGY_DIAGRAMS_SEQ;
*/