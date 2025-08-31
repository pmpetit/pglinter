SELECT table_schema::text, table_name::text, column_name::text, identifiers_category::text
FROM (
    SELECT table_schema, table_name, column_name, identifiers_category
    FROM anon.detect('en_US')
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    UNION
    SELECT table_schema, table_name, column_name, identifiers_category
    FROM anon.detect('fr_FR')
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
) detected
GROUP BY table_schema, table_name, column_name, identifiers_category
