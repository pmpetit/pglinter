SELECT count(*)
FROM pg_catalog.pg_tables pt
WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
