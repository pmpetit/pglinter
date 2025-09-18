SELECT
    tc.table_schema::text,
    tc.table_name::text,
    tc.constraint_name::text,
    kcu.column_name::text,
    col1.data_type::text AS fk_type,
    ccu.table_name::text AS ref_table,
    ccu.column_name::text AS ref_column,
    col2.data_type::text AS ref_type
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON
        tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
INNER JOIN information_schema.columns AS col1
    ON
        kcu.table_schema = col1.table_schema
        AND kcu.table_name = col1.table_name
        AND kcu.column_name = col1.column_name
INNER JOIN information_schema.columns AS col2
    ON
        ccu.table_schema = col2.table_schema
        AND ccu.table_name = col2.table_name
        AND ccu.column_name = col2.column_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND col1.data_type != col2.data_type
