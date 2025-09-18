SELECT
    t.table_schema::text,
    t.table_name::text
FROM information_schema.tables AS t
WHERE
    t.table_schema NOT IN (
        'public', 'pg_toast', 'pg_catalog', 'information_schema'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM information_schema.role_table_grants AS rtg
        INNER JOIN pg_roles AS pr ON rtg.grantee = pr.rolname
        WHERE
            rtg.table_schema = t.table_schema
            AND rtg.table_name = t.table_name
            AND pr.rolcanlogin = false
    )
