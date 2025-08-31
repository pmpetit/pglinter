SELECT COUNT(*) as tables_without_fk_index
FROM (
    SELECT DISTINCT
        ccu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND NOT EXISTS (
        SELECT 1 FROM pg_indexes pi
        WHERE pi.schemaname = tc.table_schema
        AND pi.tablename = tc.table_name
    )
) fk_tables
