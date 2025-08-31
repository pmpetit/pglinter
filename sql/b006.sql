SELECT COUNT(*) as uppercase_objects
FROM (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND table_name != lower(table_name)
    UNION
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND column_name != lower(column_name)
) uppercase_objects
