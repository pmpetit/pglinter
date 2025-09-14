SELECT COUNT(*) as total_schemas
FROM pg_namespace
WHERE nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
AND has_schema_privilege('public', nspname, 'CREATE');
