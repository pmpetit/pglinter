SELECT pt.schemaname::text, pt.tablename::text
FROM pg_tables pt
WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND NOT EXISTS (
    SELECT 1
    FROM pg_constraint pc
    WHERE pc.conrelid = (pt.schemaname||'.'||pt.tablename)::regclass
    AND pc.contype = 'p'
)
