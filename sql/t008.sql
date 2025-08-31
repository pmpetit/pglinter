SELECT
    tc.table_schema::text, tc.table_name::text, tc.constraint_name::text,
    kcu.column_name::text, col1.data_type::text as fk_type,
    ccu.table_name::text as ref_table, ccu.column_name::text as ref_column,
    col2.data_type::text as ref_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
JOIN information_schema.columns col1
    ON kcu.table_schema = col1.table_schema
    AND kcu.table_name = col1.table_name
    AND kcu.column_name = col1.column_name
JOIN information_schema.columns col2
    ON ccu.table_schema = col2.table_schema
    AND ccu.table_name = col2.table_name
    AND ccu.column_name = col2.column_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND col1.data_type != col2.data_type
