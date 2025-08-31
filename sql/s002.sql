-- S002: This query uses dynamically generated conditions for environment keywords
-- The placeholder {ENVIRONMENT_CONDITIONS} will be replaced with environment pattern checks

SELECT nspname::text as schema_name
FROM pg_namespace
WHERE nspname NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
AND nspname NOT LIKE 'pg_%'
AND ({ENVIRONMENT_CONDITIONS})
