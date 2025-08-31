SELECT table_schema::text, table_name::text, 'table'::text as object_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND table_name != lower(table_name)
UNION
SELECT table_schema::text, table_name::text, 'column:' || column_name::text as object_type
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND column_name != lower(column_name)
