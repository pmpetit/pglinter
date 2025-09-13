SELECT
    count(DISTINCT tc.table_name)
FROM
    information_schema.table_constraints AS tc
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
