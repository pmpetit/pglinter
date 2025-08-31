SELECT pi.schemaname::text, pi.tablename::text, pi.indexname::text,
    pg_relation_size(indexrelid) as index_size
FROM pg_stat_user_indexes psi
JOIN pg_indexes pi ON psi.indexrelname = pi.indexname
    AND psi.schemaname = pi.schemaname
WHERE psi.idx_scan = 0
AND pi.indexdef !~* 'unique'
AND pi.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND pg_relation_size(indexrelid) > $1
