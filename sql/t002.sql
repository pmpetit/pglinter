SELECT t.schemaname::text, t.tablename::text
FROM pg_tables t
WHERE t.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND NOT EXISTS (
    SELECT 1
    FROM pg_indexes i
    WHERE i.schemaname = t.schemaname
    AND i.tablename = t.tablename
)
