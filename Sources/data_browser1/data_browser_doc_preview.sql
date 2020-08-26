/*
Blob support for the schema data browser appliation

required privileges:
GRANT EXECUTE ON CTXSYS.CTX_DDL TO ...
*/

-- simple filter for CTX_DOC.POLICY_SNIPPET_CLOB_QUERY
begin 
	begin
		ctx_ddl.drop_policy('search_filter_policy');
	exception
	  when others then
		IF SQLCODE != -20000 THEN
			RAISE;
		END IF;
	end;
	ctx_ddl.create_policy('search_filter_policy', 'CTXSYS.AUTO_FILTER');
end;
/
