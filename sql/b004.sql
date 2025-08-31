SELECT COUNT(*) as unused_indexes
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
