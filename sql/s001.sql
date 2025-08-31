SELECT DISTINCT n.nspname::text as schema_name
FROM pg_namespace n
WHERE n.nspname NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
AND n.nspname NOT LIKE 'pg_%'
AND NOT EXISTS (
    SELECT 1
    FROM pg_default_acl da
    WHERE da.defaclnamespace = n.oid
    AND da.defaclrole != n.nspowner
)
