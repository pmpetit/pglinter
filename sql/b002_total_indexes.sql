SELECT COUNT(*) as total_indexes
FROM pg_indexes
WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
