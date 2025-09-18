SELECT
    tc.table_schema::text,
    tc.table_name::text,
    tc.constraint_name::text,
    ccu.table_schema::text AS referenced_schema,
    ccu.table_name::text AS referenced_table
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema != ccu.table_schema
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
