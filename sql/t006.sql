SELECT tc.table_schema::text, tc.table_name::text, tc.constraint_name::text,
    ccu.table_schema::text as referenced_schema
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema != ccu.table_schema
AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
