SELECT
    schemaname::text,
    relname::text,
    LEAST(
        ROUND(
            (
                seq_tup_read::numeric
                / NULLIF((seq_tup_read + idx_tup_fetch)::numeric, 0)
            ) * 100, 0
        ),
        100
    )::float8 AS seq_scan_percentage
FROM pg_stat_user_tables
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
