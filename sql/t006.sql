SELECT
    pi.schemaname::text,
    pi.tablename::text,
    pi.indexname::text,
    pg_relation_size(indexrelid) AS index_size
FROM pg_stat_user_indexes AS psi
INNER JOIN pg_indexes AS pi
    ON
        psi.indexrelname = pi.indexname
        AND psi.schemaname = pi.schemaname
WHERE
    psi.idx_scan = 0
    AND pi.indexdef !~* 'unique'
    AND pi.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND pg_relation_size(indexrelid) > $1
