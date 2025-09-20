-- S002: Schemas prefixed/suffixed with environment names
-- Detects schemas that have environment-specific prefixes or suffixes

SELECT nspname::text AS schema_name
FROM pg_namespace
WHERE
    nspname NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
    AND nspname NOT LIKE 'pg_%'
    AND (
        nspname ILIKE 'staging_%' OR nspname ILIKE '%_staging'
        OR nspname ILIKE 'stg_%' OR nspname ILIKE '%_stg'
        OR nspname ILIKE 'preprod_%' OR nspname ILIKE '%_preprod'
        OR nspname ILIKE 'prod_%' OR nspname ILIKE '%_prod'
        OR nspname ILIKE 'production_%' OR nspname ILIKE '%_production'
        OR nspname ILIKE 'dev_%' OR nspname ILIKE '%_dev'
        OR nspname ILIKE 'development_%' OR nspname ILIKE '%_development'
        OR nspname ILIKE 'sandbox_%' OR nspname ILIKE '%_sandbox'
        OR nspname ILIKE 'sbox_%' OR nspname ILIKE '%_sbox'
    )
