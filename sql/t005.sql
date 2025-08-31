SELECT
    schemaname::text,
    relname::text, seq_scan, seq_tup_read,
    CASE
        WHEN (seq_tup_read + idx_tup_fetch) > 0 THEN
            ROUND((seq_tup_read::numeric / (seq_tup_read + idx_tup_fetch)::numeric) * 100,0)::float8
        ELSE 0.0::float8
    END as seq_scan_percentage
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND (CASE
        WHEN (seq_tup_read + idx_tup_fetch) > 0 THEN
            (seq_tup_read::numeric / (seq_tup_read + idx_tup_fetch)::numeric) * 100
        ELSE 0
    END) > $1
