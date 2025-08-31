-- T010: This query uses dynamically generated conditions for reserved keywords
-- The placeholder {KEYWORD_CONDITIONS_TABLES} will be replaced with table keyword checks
-- The placeholder {KEYWORD_CONDITIONS_COLUMNS} will be replaced with column keyword checks

SELECT table_schema::text, table_name::text, 'table' as object_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND ({KEYWORD_CONDITIONS_TABLES})
UNION
SELECT table_schema, table_name, 'column:' || column_name as object_type
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND ({KEYWORD_CONDITIONS_COLUMNS})
