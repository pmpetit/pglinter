
-- Schema Rules (S series)
INSERT INTO rules (
    name,
    code,
    warning_level,
    error_level,
    scope,
    description,
    message,
    fixes
) VALUES
(
    'SchemaWithDefaultRoleNotGranted', 'S001', 1, 1, 'SCHEMA',
    'The schema ha no default role. Means that futur table will not be granted through a role. So you will have to re-execute grants on it.',
    'No default role grantee on schema {0}.{1}. It means that each time a table is created, you must grant it to roles.',
    ARRAY[
        'add a default privilege=> ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> for user <schema''s owner>'
    ]
),

(
    'SchemaPrefixedOrSuffixedWithEnvt', 'S002', 1, 1, 'SCHEMA',
    'The schema is prefixed with one of staging,stg,preprod,prod,sandbox,sbox string. Means that when you refresh your preprod, staging environments from production, you have to rename the target schema from prod_ to stg_ or something like. It is possible, but it is never easy.',
    'You should not prefix or suffix the schema name with {0}. You may have difficulties when refreshing environments. Prefer prefix or suffix the database name.',
    ARRAY[
        'Keep the same schema name across environments. Prefer prefix or suffix the database name'
    ]
),
(
    'UnsecuredPublicSchema', 'S003', 20, 80, 'SCHEMA',
    'Only authorized users should be allowed to create objects.',
    '{0}/{1} schemas are unsecured, schemas where all users can create objects in, exceed the {2} threshold: {3}%.',
    ARRAY['REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC']
);

-- =============================================================================
-- S001 - Schema Permission Analysis
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT DISTINCT n.nspname::text AS schema_name
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
    AND n.nspname NOT LIKE 'pg_%'
    AND NOT EXISTS (
        SELECT 1
        FROM pg_default_acl da
        WHERE
            da.defaclnamespace = n.oid
            AND da.defaclrole != n.nspowner
    )
ORDER BY 1
$$
WHERE code = 'S001';

-- =============================================================================
-- S002 - Environment-Named Schemas
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
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
ORDER BY 1
$$
WHERE code = 'S002';

-- =============================================================================
-- S003 - Schema Public Access (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT COUNT(*) AS total_schemas
FROM pg_namespace
WHERE
    nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND HAS_SCHEMA_PRIVILEGE('public', nspname, 'CREATE')
$$
WHERE code = 'S003';
