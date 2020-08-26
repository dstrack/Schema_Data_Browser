/*
Copyright 2016 Dirk Strack

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-- Required Privileges:
GRANT EXECUTE ON SYS.UTL_TCP TO OWNER;
GRANT EXECUTE ON SYS.UTL_SMTP TO OWNER;
GRANT APEX_ADMINISTRATOR_ROLE TO OWNER;

-- uninstall
DROP PACKAGE weco_mail;

*/

CREATE OR REPLACE PACKAGE weco_mail
AUTHID DEFINER
AS
	c_log_message_query CONSTANT VARCHAR2(300)	:= 'INSERT INTO APP_PROTOCOL (Description, Remarks) VALUES  (:a, :b)';
    c_mail_boundary 	CONSTANT VARCHAR2(50) := '----=*#wecomal1234321cba#*=';
    c_term_msg			CONSTANT VARCHAR2(50) := utl_tcp.crlf || utl_tcp.crlf;
	c_use_app_preferences CONSTANT BOOLEAN := TRUE;
    c_debug 			CONSTANT BOOLEAN := FALSE;

   	PROCEDURE log_message (
   		p_Subject	IN VARCHAR2,
   		p_Info	IN VARCHAR2
   	);

	FUNCTION in_list(
		p_string in clob,
		p_delimiter in varchar2 := ';')
	RETURN sys.odciVarchar2List
	PIPELINED;

	PROCEDURE Send_Mail (
		p_to		IN VARCHAR2,
		p_from		IN VARCHAR2,
		p_name		IN VARCHAR2 DEFAULT NULL,
		p_body		IN CLOB DEFAULT NULL,
		p_body_html IN CLOB DEFAULT NULL,
		p_subj		IN VARCHAR2,
		p_cc		IN VARCHAR2 DEFAULT NULL,
		p_bcc		IN VARCHAR2 DEFAULT NULL,
		p_priority	IN VARCHAR2 DEFAULT '3',
		p_replyto	IN VARCHAR2 DEFAULT NULL,
		p_dispo_to	IN VARCHAR2 DEFAULT NULL,
		p_receipt	IN VARCHAR2 DEFAULT NULL,
		p_references IN VARCHAR2 DEFAULT NULL,
		p_dispo_note IN VARCHAR2 DEFAULT NULL,
		p_dispo_header IN CLOB DEFAULT NULL,
		p_attach    IN INTEGER DEFAULT 0,
		p_sentdate  IN TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP,
		p_conn		IN OUT NOCOPY utl_smtp.connection,
		p_Message   OUT VARCHAR2
	);

	PROCEDURE Send_Mail_attachment (
		p_conn		  IN OUT NOCOPY utl_smtp.connection,
		p_attachment IN BLOB,
		p_filename IN VARCHAR2,
		p_mime_type IN VARCHAR2
	);

	PROCEDURE Send_Mail_Close (
		p_conn		  IN OUT NOCOPY utl_smtp.connection
	);
END weco_mail;
/
show errors


-------------------------------------------------------------------------------


CREATE OR REPLACE PACKAGE BODY weco_mail
AS
   	PROCEDURE log_message (
   		p_Subject	IN VARCHAR2,
   		p_Info	IN VARCHAR2
   	)
	IS PRAGMA AUTONOMOUS_TRANSACTION;
		v_Subject VARCHAR2(40) := SUBSTR(p_Subject, 1, 40);
		v_Info	VARCHAR2(300) := SUBSTR(p_Info, 1, 300);
	BEGIN
		dbms_output.put_line('CODE:' || v_Subject);
		dbms_output.put_line('MESSAGE:' || v_Info);
		EXECUTE IMMEDIATE c_log_message_query
		USING IN v_Subject, v_Info;

		COMMIT;
	EXCEPTION
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE(c_log_message_query || ' - failed with ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
		NULL;
	END;

	---------------------------------------------------------------------------
	FUNCTION in_list(
		p_string in clob,
		p_delimiter in varchar2 := ';')
	RETURN sys.odciVarchar2List
	PIPELINED
	as
		l_string	long default p_string || p_delimiter;
		n			number;
		l_dlen		number := length(p_delimiter);
	begin
		loop
			exit when l_string is null;
			n := INSTR( l_string, p_delimiter);
			pipe row( ltrim( rtrim( substr( l_string, 1, n-1 ) ) ) );
			l_string := substr( l_string, n+l_dlen );
		end loop;
		return;
	end;


    PROCEDURE Send_Mail_Adresslist(
		p_conn		  IN OUT NOCOPY utl_smtp.connection,
		p_recipients  IN VARCHAR2
	)
	IS
		l_reply         utl_smtp.reply;
		v_Message		VARCHAR2(4000);
	BEGIN
	    if p_recipients IS NOT NULL then
            for c in (
                SELECT TRIM(T.COLUMN_VALUE) AdressItem
                FROM TABLE( weco_mail.in_list( p_recipients, ',' ) ) T
            ) loop
                utl_smtp.rcpt(p_conn, c.AdressItem);
				if l_reply.code NOT IN ( 250, 251 ) or c_debug then
					v_Message := ' utl_smtp.rcpt(' || c.AdressItem || '): '||l_reply.code||' - '||l_reply.text;
					log_message(
						p_Subject => 'Send_Mail to ' || c.AdressItem,
						p_Info => v_Message
					);
					if l_reply.code NOT IN ( 250, 251 ) then
						return;
					end if;
				end if;
            end loop;
        end if;
	END;

    PROCEDURE Clob_To_Blob(
        p_dest_lob IN OUT NOCOPY BLOB,
        p_src_clob IN CLOB,
		p_charset IN VARCHAR2 DEFAULT 'AL32UTF8' -- 'WE8ISO8859P1'
    )
    IS
        v_dstoff	    pls_integer := 1;
        v_srcoff		pls_integer := 1;
        v_langctx 		pls_integer := dbms_lob.default_lang_ctx;
        v_warning 		pls_integer := 1;
    	v_blob_csid     pls_integer := nls_charset_id(p_charset);
    BEGIN
        dbms_lob.converttoblob(
            dest_lob     =>	p_dest_lob,
            src_clob     =>	p_src_clob,
            amount	     =>	dbms_lob.getlength(p_src_clob),
            dest_offset  =>	v_dstoff,
            src_offset	 =>	v_srcoff,
            blob_csid	 =>	v_blob_csid,
            lang_context => v_langctx,
            warning		 => v_warning
        );
    END;


	FUNCTION Concat_List (
		p_First_Name	VARCHAR2,
		p_Second_Name	VARCHAR2,
		p_Delimiter		VARCHAR2 DEFAULT ', '
	)
    RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
    	RETURN
			case when p_First_Name IS NOT NULL and p_Second_Name IS NOT NULL
			then p_First_Name || p_Delimiter || p_Second_Name
			when p_First_Name IS NOT NULL
			then p_First_Name
			else p_Second_Name
			end;
    END;

	PROCEDURE Send_Mail (
		p_to		IN VARCHAR2,
		p_from		IN VARCHAR2,
		p_name		IN VARCHAR2 DEFAULT NULL,
		p_body		IN CLOB DEFAULT NULL,
		p_body_html IN CLOB DEFAULT NULL,
		p_subj		IN VARCHAR2,
		p_cc		IN VARCHAR2 DEFAULT NULL,
		p_bcc		IN VARCHAR2 DEFAULT NULL,
		p_priority	IN VARCHAR2 DEFAULT '3',
		p_replyto	IN VARCHAR2 DEFAULT NULL,
		p_dispo_to	IN VARCHAR2 DEFAULT NULL,
		p_receipt	IN VARCHAR2 DEFAULT NULL,
		p_references IN VARCHAR2 DEFAULT NULL,
		p_dispo_note IN VARCHAR2 DEFAULT NULL,
		p_dispo_header IN CLOB DEFAULT NULL,
		p_attach    IN INTEGER DEFAULT 0,
		p_sentdate  IN TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP,
		p_conn		IN OUT NOCOPY utl_smtp.connection,
		p_Message   OUT VARCHAR2
	)
	AS
		l_step		    PLS_INTEGER  := 10240; /* 10240 limit 24573... ORA-06502: PL/SQL: numerischer oder Wertefehler: Raw-Variable zu lang; */
		l_from     		VARCHAR2(500);
		l_long_from     VARCHAR2(500);
		l_smtp_host	    VARCHAR2(500);
		l_smtp_port	    NUMBER := 25;
		l_smtp_uname    VARCHAR2(500);
		l_smtp_pwd	    VARCHAR2(500);
		l_smtp_ssl_enabled   VARCHAR2(3);
		l_smtp_ssl_plain VARCHAR2(3);
		l_smtp_starttls VARCHAR2(3);
		l_wallet_path	VARCHAR2(500);
		l_wallet_pw 	VARCHAR2(200);
		l_domain_smtp_uname   VARCHAR2(500);
		l_domain_from_email   VARCHAR2(500);
		l_reply         utl_smtp.reply;
		l_replies		utl_smtp.replies;
		l_reply_str     VARCHAR2(1000);
		l_Label         INTEGER := 0;
		l_Message_UID   VARCHAR2(500);
		l_Subject 		VARCHAR2(500);
        v_blob			blob;
		v_conn 			utl_smtp.connection;
	BEGIN
        dbms_lob.createtemporary(
            lob_loc => v_blob,
            cache	=> true,
            dur		=> dbms_lob.call
        );

		$IF weco_mail.c_use_app_preferences $THEN
			SELECT SMTP_HOST_ADDRESS, SMTP_HOST_PORT,
				SMTP_USERNAME, WECO_AUTH.HEX_DCRYPT(ID, SMTP_PASSWORD),
				WALLET_PATH, WECO_AUTH.HEX_DCRYPT(ID, WALLET_PASSWORD), SMTP_SSL, SMTP_SSL_CONNECT_PLAIN
			INTO l_smtp_host, l_smtp_port, l_smtp_uname,
				l_smtp_pwd, l_wallet_path, l_wallet_pw, l_smtp_ssl_enabled, l_smtp_ssl_plain
			FROM APP_PREFERENCES
			WHERE ID = 1;
		$ELSE
			SELECT
				APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'SMTP_HOST_ADDRESS' ) SMTP_HOST_ADDRESS,
				APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'SMTP_HOST_PORT' ) SMTP_HOST_PORT,
				APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'SMTP_USERNAME' ) SMTP_USERNAME,
				APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'SMTP_PASSWORD' ) SMTP_PASSWORD,
				APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'WALLET_PATH' ) WALLET_PATH,
				APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'WALLET_PWD' ) WALLET_PWD,
				case APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'SMTP_TLS_MODE' ) when 'N' then '0' else '1' end SMTP_TLS_MODE,
				case APEX_INSTANCE_ADMIN.GET_PARAMETER ( 'SMTP_TLS_MODE' ) when 'STARTTLS' then '1' else '0' end SMTP_TLS_PLAIN
			INTO l_smtp_host, l_smtp_port, l_smtp_uname, l_smtp_pwd,
				l_wallet_path, l_wallet_pw, l_smtp_ssl_enabled, l_smtp_ssl_plain
			FROM DUAL;
		$END
		l_domain_smtp_uname := LOWER(TRIM(SUBSTR(l_smtp_uname, INSTR(l_smtp_uname, '@') + 1)));
		l_domain_from_email := LOWER(TRIM(SUBSTR(p_from, INSTR(p_from, '@') + 1)));
		$IF weco_mail.c_debug $THEN
            log_message('Send_Mail Parameter','smtp_host        : ' || l_smtp_host);
            log_message('Send_Mail Parameter','smtp_port        : ' || l_smtp_port);
            log_message('Send_Mail Parameter','smtp_uname       : ' || l_smtp_uname);
            log_message('Send_Mail Parameter','smtp_pwd         : ' || l_smtp_pwd);
            log_message('Send_Mail Parameter','wallet_path      : ' || l_wallet_path);
            log_message('Send_Mail Parameter','wallet_pw        : ' || l_wallet_pw);
            log_message('Send_Mail Parameter','smtp_ssl_enable  : ' || l_smtp_ssl_enabled);
            log_message('Send_Mail Parameter','smtp_ssl_plain   : ' || l_smtp_ssl_plain);
            log_message('Send_Mail Parameter','domains match    : ' || case when l_domain_smtp_uname <> l_domain_from_email then 'No' else 'Yes' end);
		$END
		l_from := case when l_domain_smtp_uname <> l_domain_from_email
						then l_smtp_uname else p_from
					end;
	    l_long_from := case when p_name IS NULL OR l_from IS NULL
	    				then l_from else p_name || ' <' || l_from || '>'
	    			end;
        l_message_uid := '<' || TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS')
        				|| '.' || sys_guid() || '.' || l_from || '>';

		if l_smtp_ssl_enabled = '1' then
			l_smtp_starttls := '0';
			l_Label := 1;

 			l_reply := utl_smtp.open_connection(
				host => l_smtp_host,
				port => l_smtp_port,
				c => p_conn,
				wallet_path => l_wallet_path,
				wallet_password => l_wallet_pw,
				secure_connection_before_smtp => (l_smtp_ssl_plain = '0')
			);
			if l_reply.code <> 220 or c_debug then
				p_Message := 'Label ' || l_Label || ' utl_smtp.open_connection(SSL-Connection) - Host Code : '
							|| l_reply.code || ', SQL Code : ' || SQLERRM;
				log_message(
					p_Subject => 'Send_Mail',
					p_Info => p_Message
				);
				if l_reply.code <> 220 then
					return;
				end if;
			end if;
			-- 1. EHLO --
			l_Label := 2;
			l_replies := utl_smtp.ehlo( p_conn, l_smtp_host);
			l_reply_str := '';
			FOR ri IN 1..l_replies.COUNT loop
				l_reply_str := Concat_List(l_reply_str, l_replies(ri).text);
				if l_replies(ri).text = 'STARTTLS' then
					l_smtp_starttls := '1';
				end if;
			end loop;
			if l_replies(1).code <> 250 or c_debug then
				p_Message := 'Label ' || l_Label || ' utl_smtp.ehlo(' || l_smtp_host || ') : '
					|| l_replies(1).code || ', ' || l_reply_str;
				log_message('Send_Mail', p_Message);
				if l_replies(1).code <> 250 then
					GOTO final_exit;
				end if;
			end if;

			if l_smtp_starttls = '1' or l_smtp_ssl_plain = '1' then
				-- STARTTLS --
				l_Label := 3;
				l_reply := utl_smtp.starttls(p_conn);
				if l_reply.code NOT IN (220, 500) or c_debug then
					p_Message := 'Label ' || l_Label || ' utl_smtp.starttls: '||l_reply.code||' - '||l_reply.text;
					log_message('Send_Mail', p_Message);
					if l_reply.code NOT IN (220, 500) then
						utl_smtp.quit(p_conn);
						GOTO final_exit;
					end if;
				end if;
				-- 2. EHLO --
				l_Label := 4;
				l_replies := utl_smtp.ehlo( p_conn, l_smtp_host);
				l_reply_str := '';
				FOR ri IN 1..l_replies.COUNT loop
					l_reply_str := Concat_List(l_reply_str, l_replies(ri).text);
				end loop;
				if l_replies(1).code <> 250 or c_debug then
					p_Message := 'Label ' || l_Label || ' utl_smtp.ehlo(' || l_smtp_host || ') : '
						|| l_replies(1).code || ', ' || l_reply_str;
					log_message('Send_Mail', p_Message);
					if l_replies(1).code <> 250 then
						GOTO final_exit;
					end if;
				end if;
			end if;

			-- AUTH --
			l_Label := 5;
			l_reply := utl_smtp.auth(p_conn, l_smtp_uname, l_smtp_pwd,
							case when (l_smtp_ssl_plain = '1')
								then 'PLAIN'
								else utl_smtp.ALL_SCHEMES
							end
						);
			if l_reply.code != 235 or c_debug then
    			p_Message := 'Label ' || l_Label || ' utl_smtp.auth: '||l_reply.code||' - '||l_reply.text;
				log_message('Send_Mail', p_Message);
				if l_reply.code != 235 then
					GOTO final_exit;
				end if;
  			end if;
        else
			l_Label := 1;
			l_reply := utl_smtp.open_connection(
				host => l_smtp_host,
				port => l_smtp_port,
				c => p_conn,
				wallet_path => l_wallet_path,
				wallet_password => l_wallet_pw,
				secure_connection_before_smtp => false
			);
			if l_reply.code <> 220 or c_debug then
				p_Message := 'Label ' || l_Label || ' utl_smtp.open_connection - Host Code : '
							|| l_reply.code || ', SQL Code : ' || SQLERRM;
				log_message('Send_Mail', p_Message);
				if l_reply.code <> 220 then
					return;
				end if;
			end if;
			l_Label := 2;
			if l_smtp_uname IS NOT NULL then
				utl_smtp.command(p_conn, 'AUTH LOGIN');
				utl_smtp.command(p_conn, utl_raw.cast_to_varchar2(utl_encode.base64_encode( utl_raw.cast_to_raw(l_smtp_uname))));
				utl_smtp.command(p_conn, utl_raw.cast_to_varchar2(utl_encode.base64_encode( utl_raw.cast_to_raw(l_smtp_pwd))));
			end if;
			l_Label := 3;
			l_reply := utl_smtp.helo(p_conn, l_smtp_host);
			if l_reply.code <> 250 or c_debug then
				p_Message := 'Label ' || l_Label || ' utl_smtp.helo(' || l_smtp_host || ') : '
					|| l_reply.code || ', ' || l_reply.text;
				log_message('Send_Mail', p_Message);
				if l_reply.code <> 250 then
					GOTO final_exit;
				end if;
			end if;
        end if;
		-----------------------------------------------------------------------
        l_Label := 6;
        l_reply := utl_smtp.mail(p_conn, l_from);
		if l_reply.code <> 250 or c_debug then
			p_Message := 'Label ' || l_Label || ' utl_smtp.mail(' || l_from || '): '||l_reply.code||' - '||l_reply.text;
			log_message('Send_Mail', p_Message);
			if l_reply.code <> 250 then
				GOTO final_exit;
			end if;
		end if;

        l_Label := 7;
	    Send_Mail_Adresslist(p_conn, p_to);
        l_Label := 8;
	    Send_Mail_Adresslist(p_conn, p_cc);
        l_Label := 9;
	    Send_Mail_Adresslist(p_conn, p_bcc);
        l_Label := 10;
		l_reply := utl_smtp.open_data(p_conn);
		if l_reply.code  NOT IN (250, 354) or c_debug then
			p_Message := 'Label ' || l_Label || ' utl_smtp.open_data: '||l_reply.code||' - '||l_reply.text;
			log_message('Send_Mail', p_Message);
			if l_reply.code  NOT IN (250, 354) then
				GOTO final_exit;
			end if;
		end if;
		log_message('Send_Mail', 'To :' || p_to ||  ', Subject: ' || p_subj);

		utl_smtp.write_data(p_conn, 'Date: ' || TO_CHAR(p_sentdate, 'Dy, DD Mon YYYY HH24:MI:SS TZHTZM','nls_date_language = American') || utl_tcp.crlf);
		utl_smtp.write_data(p_conn, 'To: ' || p_to || utl_tcp.crlf);
		utl_smtp.write_data(p_conn, 'From: ' || l_long_from || utl_tcp.crlf);
		utl_smtp.write_data(p_conn, 'Subject: '
			|| replace(utl_encode.text_encode(p_subj, NULL, utl_encode.quoted_printable), '='||utl_tcp.crlf)
			|| utl_tcp.crlf
		);
		/* or maybe
		UTL_SMTP.WRITE_DATA(p_conn, 'Subject: =?UTF-8?Q?'||UTL_ENCODE.TEXT_ENCODE(p_subj, NULL, UTL_ENCODE.QUOTED_PRINTABLE)||'?=' ||UTL_TCP.CRLF );
		*/
		if p_replyto IS NOT NULL or l_from <> p_from then
			utl_smtp.write_data(p_conn, 'Reply-To: ' || NVL(p_replyto, p_from) || utl_tcp.crlf);
		end if;
        l_Label := 11;
		if p_cc IS NOT NULL then
			utl_smtp.write_data(p_conn, 'Cc-To: ' || p_cc || utl_tcp.crlf);
		end if;
		if p_priority IS NOT NULL then
			utl_smtp.write_data(p_conn, 'X-Priority: ' || p_priority || utl_tcp.crlf);
		end if;
		if p_dispo_to IS NOT NULL then
			utl_smtp.write_data(p_conn, 'Disposition-Notification-To: ' || p_dispo_to || utl_tcp.crlf);
		end if;
		if p_receipt IS NOT NULL then
			utl_smtp.write_data(p_conn, 'Return-Receipt-To: ' || p_receipt || utl_tcp.crlf);
		end if;
		if p_references IS NOT NULL then
			utl_smtp.write_data(p_conn, 'References: ' || p_references || utl_tcp.crlf);
		end if;
		utl_smtp.write_data(p_conn, 'Message-Id: ' || l_message_uid || utl_tcp.crlf);
		utl_smtp.write_data(p_conn, 'MIME-Version: 1.0' || utl_tcp.crlf);
		if p_attach > 0 then
		    utl_smtp.write_data(p_conn, 'Content-Type: multipart/mixed;' || utl_tcp.crlf || ' boundary="' ||
		                                c_mail_boundary || '"' || c_term_msg);
        elsif p_dispo_note is not null then
    	    utl_smtp.write_data(p_conn, 'Content-Type: multipart/report; report-type=disposition-notification;' || utl_tcp.crlf || ' boundary="' ||
    	                                c_mail_boundary || '"' || c_term_msg);
        else
    	    utl_smtp.write_data(p_conn, 'Content-Type: multipart/alternative;' || utl_tcp.crlf || ' boundary="' ||
    	                                c_mail_boundary || '"' || c_term_msg);
		end if;
        l_Label := 12;

		IF p_body IS NOT NULL AND p_attach <= 0 THEN
		    Clob_To_Blob(v_blob, p_body);
			utl_smtp.write_data(p_conn, '--' || c_mail_boundary || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Type: text/plain; charset=utf-8' || c_term_msg);
			FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(v_blob) - 1 )/l_step) LOOP
			    utl_smtp.write_raw_data(p_conn, DBMS_LOB.substr(v_blob, l_step, i * l_step + 1));
			END LOOP;
			utl_smtp.write_data(p_conn, c_term_msg);
		END IF;
        l_Label := 13;

		IF p_body_html IS NOT NULL THEN
		    Clob_To_Blob(v_blob, p_body_html);
			utl_smtp.write_data(p_conn, '--' || c_mail_boundary || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Type: text/html; charset=utf-8' || c_term_msg);
			FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(v_blob) - 1 )/l_step) LOOP
			    utl_smtp.write_raw_data(p_conn, DBMS_LOB.substr(v_blob, l_step, i * l_step + 1));
			END LOOP;
			utl_smtp.write_data(p_conn, c_term_msg);
		END IF;
        l_Label := 14;

		IF p_dispo_note IS NOT NULL THEN
			utl_smtp.write_data(p_conn, '--' || c_mail_boundary || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Type: message/disposition-notification; name="MDNPart2.txt"' || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Disposition: inline' || c_term_msg);

			utl_smtp.write_data(p_conn, 'Reporting-UA: ' || l_smtp_host || '; WeCo Mail' || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Original-Recipient: rfc822;' || p_from || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Final-Recipient: rfc822;' || p_from || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Original-Message-ID: ' || p_references || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Disposition: manual-action/MDN-sent-manually; displayed' || utl_tcp.crlf);

			utl_smtp.write_data(p_conn, c_term_msg);

			utl_smtp.write_data(p_conn, '--' || c_mail_boundary || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Type: text/rfc822-headers; name="MDNPart3.txt"' || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Disposition: inline' || c_term_msg);

			utl_smtp.write_data(p_conn, p_dispo_header);
			utl_smtp.write_data(p_conn, c_term_msg);
		END IF;
        l_Label := 15;
	    p_Message := NULL;

		-----------------------------------------------------------------------
		if c_debug then
			p_Message := 'Label ' || l_Label || ' Normal exit.';
			log_message('Send_Mail', p_Message);
		end if;

	    IF p_attach > 0 THEN
	    	RETURN;
		end if;
		<<final_exit>>
		Send_Mail_Close(p_conn);
		RETURN;
    EXCEPTION
      WHEN utl_smtp.TRANSIENT_ERROR OR utl_smtp.PERMANENT_ERROR THEN
        p_Message := ('Label ' || l_Label || ', SMTP-EXCEPTION Error ' || SQLERRM);
		log_message('Send_Mail', p_Message);
        COMMIT;
        BEGIN
            utl_smtp.quit(p_conn);
        EXCEPTION
            WHEN utl_smtp.TRANSIENT_ERROR OR utl_smtp.PERMANENT_ERROR THEN
                NULL; -- When the SMTP server is down or unavailable, we don't have -- a connection to the server. The QUIT call raises an
                        -- exception that we can ignore.
        END;
      WHEN OTHERS THEN
        p_Message := ('Label ' || l_Label || ', EXCEPTION Error ' || SQLERRM);
		log_message('Send_Mail', p_Message);
    END;


	PROCEDURE Send_Mail_attachment (
		p_conn		  IN OUT NOCOPY utl_smtp.connection,
		p_attachment IN BLOB,
		p_filename IN VARCHAR2,
		p_mime_type IN VARCHAR2
	)
	AS
	  l_step		PLS_INTEGER	 := 10240; /* 24573... ORA-06502: PL/SQL: numerischer oder Wertefehler: Raw-Variable zu lang; */
	BEGIN
		if p_conn.host IS NOT NULL then
			utl_smtp.write_data(p_conn, '--' || c_mail_boundary || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Type: ' || p_mime_type || '; name="' || p_filename || '"' || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Transfer-Encoding: base64' || utl_tcp.crlf);
			utl_smtp.write_data(p_conn, 'Content-Disposition: attachment; filename="' || p_filename || '"' || utl_tcp.crlf || utl_tcp.crlf);

			FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_attachment) - 1 )/l_step) LOOP
			  utl_smtp.write_data(p_conn, UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(DBMS_LOB.substr(p_attachment, l_step, i * l_step + 1))));
			END LOOP;
			utl_smtp.write_data(p_conn, c_term_msg);
		end if;
	END;

	PROCEDURE Send_Mail_Close (
		p_conn		  IN OUT NOCOPY utl_smtp.connection
	)
	AS
		l_reply         utl_smtp.reply;
	BEGIN
		if p_conn.host IS NOT NULL then
			utl_smtp.write_data(p_conn, '--' || c_mail_boundary || '--' || utl_tcp.crlf);
			if c_debug then
				log_message(
					p_Subject => 'Send_Mail_Close',
					p_Info => ' utl_smtp.write_data(' || p_conn.host || ') : mail_boundary '
				);
			end if;
			utl_smtp.write_data(p_conn, utl_tcp.crlf || '.' || utl_tcp.crlf);

			l_reply := utl_smtp.close_data(p_conn);
			if l_reply.code <> 250 or c_debug then
				log_message(
					p_Subject => 'Send_Mail_Close',
					p_Info => ' utl_smtp.close_data(' || p_conn.host || ') :'  ||l_reply.code||' - '||l_reply.text
				);
			end if;

			l_reply := utl_smtp.quit(p_conn);
			if l_reply.code <> 250 or c_debug then
				log_message(
					p_Subject => 'Send_Mail_Close',
					p_Info => 'utl_smtp.quit NORMAL :'   ||l_reply.code||' - '||l_reply.text
				);
			end if;
		else
			if c_debug then
				log_message(
					p_Subject => 'Send_Mail_Close ',
					p_Info => 'Host IS NULL.'
				);
			end if;
		end if;
    EXCEPTION
      WHEN OTHERS THEN
		log_message(
			p_Subject => 'Send_Mail_Close',
			p_Info => 'EXCEPTION Error ' || SQLERRM
		);
        BEGIN
            utl_smtp.quit(p_conn);
        EXCEPTION
            WHEN utl_smtp.TRANSIENT_ERROR OR utl_smtp.PERMANENT_ERROR THEN
                NULL; -- When the SMTP server is down or unavailable, we don't have -- a connection to the server. The QUIT call raises an
                        -- exception that we can ignore.
        END;
	end;
END weco_mail;
/
show errors

/*

-- test call --

CREATE OR REPLACE PROCEDURE test_mail
IS
	v_conn utl_smtp.CONNECTION;
	v_Message  VARCHAR2(500);
BEGIN
	weco_mail.send_mail(
		p_to => 'dirkstrack@icloud.com',
		p_from => 'dirk_strack@yahoo.de',
		p_body => 'Please confirm the connection via weco_mail.send_mail. – Schönen Tag.',
		p_body_html => '<b>Please</b> confirm the connection via weco_mail.send_mail. – Schönen Tag.',
		p_subj => 'test the connection (ÄÖÜ)',
		p_conn => v_conn,
		p_Message => v_Message
	);
	DBMS_OUTPUT.PUT_LINE('-------------------');
	DBMS_OUTPUT.PUT('send_mail result : ');
	DBMS_OUTPUT.PUT_LINE(v_Message);

END;
/
show errors

set serveroutput on

begin test_mail; end;
/

begin
	weco_login.Load_Job (
		p_Job_Name => 'ACCOUNT_MAIL',
		p_Comment => 'Send account info mail for data browser application',
		p_Sql => 'begin test_mail; end;'
	);
	COMMIT;
end;
/

-------------------------------------------------------------------------------
declare
	v_workspace_id 	NUMBER;
begin
	v_workspace_id := apex_util.find_security_group_id (p_workspace => 'STRACK_DEV');
	apex_util.set_security_group_id (p_security_group_id => v_workspace_id);

	apex_mail.send(
		p_to => 'strackdirk@gmail.com',
		p_from => 'dirk_strack@yahoo.de',
		p_body => 'Please confirm the connection via apex_mail.send. – Schönen Tag.',
		p_body_html => '<b>Please</b> confirm the connection via apex_mail.send. – Schönen Tag.',
		p_subj => 'test the connection (ÄÖÜ)',
		p_cc => NULL,
		p_bcc => NULL,
		p_replyto => NULL
	);
	apex_mail.push_queue;
	commit;
end;
/
*/

