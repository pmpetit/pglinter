SELECT t.table_schema::text, t.table_name::text
FROM information_schema.tables t
WHERE t.table_schema NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
AND NOT EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants rtg
    JOIN pg_roles pr ON pr.rolname = rtg.grantee
    WHERE rtg.table_schema = t.table_schema
    AND rtg.table_name = t.table_name
    AND pr.rolcanlogin = false
)
