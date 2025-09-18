SELECT DISTINCT
    tc.table_schema::text,
    tc.table_name::text,
    tc.constraint_name::text
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON
        tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND NOT EXISTS (
        SELECT 1 FROM pg_indexes AS pi
        WHERE
            pi.schemaname = tc.table_schema
            AND pi.tablename = tc.table_name
            AND pi.indexdef LIKE '%' || kcu.column_name || '%'
    )
