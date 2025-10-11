-- =============================================================================
-- pglinter Rules Configuration
-- =============================================================================
--
-- This file defines the comprehensive rule set for the pglinter PostgreSQL
-- extension. It creates the rules table that stores metadata for all
-- database analysis rules.
--
-- Rule Categories:
--   B-series: Base Database Rules (tables, indexes, primary keys, etc.)
--   C-series: Cluster Rules (configuration, security, performance)
--   S-series: Schema Rules (permissions, ownership, security)
--   T-series: Table Rules (specific table-level analysis)
--
-- Each rule includes:
--   - Rule code (e.g., B001, T003)
--   - Configurable warning/error thresholds
--   - Scope (BASE, CLUSTER, SCHEMA, TABLE)
--   - Descriptive metadata and fix suggestions
--   - SQL queries for analysis (q1/q2 fields)
--
-- Usage:
--   This file is automatically executed during extension installation
--   via pgrx's extension_sql_file! macro.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS pglinter.rules (
    id INT PRIMARY KEY,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    warning_level INT,
    error_level INT,
    scope TEXT,
    description TEXT,
    message TEXT,
    fixes TEXT [],
    q1 TEXT,
    q2 TEXT
);

-- Clear existing data and insert comprehensive rules
DELETE FROM pglinter.rules;

INSERT INTO pglinter.rules (
    id,
    name,
    code,
    warning_level,
    error_level,
    scope,
    description,
    message,
    fixes
) VALUES
-- Base Database Rules (B series)
(
    1, 'HowManyTableWithoutPrimaryKey', 'B001', 20, 80, 'BASE',
    'Count number of tables without primary key.',
    '{0}/{1} table(s) without primary key exceed the {2} threshold: {3}%.',
    ARRAY['create a primary key or change warning/error threshold']
),

(
    2, 'HowManyRedudantIndex', 'B002', 20, 80, 'BASE',
    'Count number of redundant index vs nb index.',
    '{0}/{1} redundant(s) index exceed the {2} threshold: {3}%.',
    ARRAY[
        'remove duplicated index or check if a constraint does not create a redundant index, or change warning/error threshold'
    ]
),

(
    3, 'HowManyTableWithoutIndexOnFk', 'B003', 20, 80, 'BASE',
    'Count number of tables without index on foreign key.',
    '{0}/{1} table(s) without index on foreign key exceed the {2} threshold: {3}%.',
    ARRAY['create a index on foreign key or change warning/error threshold']
),

(
    4, 'HowManyUnusedIndex', 'B004', 20, 80, 'BASE',
    'Count number of unused index vs nb index (base on pg_stat_user_indexes, indexes associated to unique constraints are discard.)',
    '{0}/{1} unused index exceed the {2} threshold: {3}%',
    ARRAY['remove unused index or change warning/error threshold']
),

(
    5, 'UnsecuredPublicSchema', 'B005', 20, 80, 'BASE',
    'Only authorized users should be allowed to create objects.',
    '{0}/{1} schemas are unsecured, schemas where all users can create objects in, exceed the {2} threshold: {3}%.',
    ARRAY['REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC']
),

(
    6, 'HowManyObjectsWithUppercase', 'B006', 20, 80, 'BASE',
    'Count number of objects with uppercase in name or in columns.',
    '{0}/{1} object(s) using uppercase for name or columns exceed the {2} threshold: {3}%.',
    ARRAY['Do not use uppercase for any database objects']
),

(
    7, 'HowManyTablesNeverSelected', 'B007', 20, 80, 'BASE',
    'Count number of table(s) that has never been selected.',
    '{0}/{1} table(s) are never selected the {2} threshold: {3}%.',
    ARRAY[
        'Is it necessary to update/delete/insert rows in table(s) that are never selected ?'
    ]
),

(
    8, 'HowManyTablesWithFkOutsideSchema', 'B008', 20, 80, 'BASE',
    'Count number of tables with foreign keys outside their schema.',
    '{0}/{1} table(s) with foreign keys outside schema exceed the {2} threshold: {3}%.',
    ARRAY[
        'Consider restructuring schema design to keep related tables in same schema',
        'ask a dba'
    ]
),

-- Cluster Rules (C series)

(
    11,
    'PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists',
    'C002',
    20,
    80,
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust or password authentication method exceed the warning threshold: {1}.',
    ARRAY['change trust or password method in pg_hba.conf']
),

(
    12,
    'PasswordEncryptionIsMd5',
    'C003',
    20,
    80,
    'CLUSTER',
    'This configuration is not secure anymore and will prevent an upgrade to Postgres 18. Warning, you will need to reset all passwords after this is changed to scram-sha-256.',
    'Encrypted passwords with MD5.',
    ARRAY['change password_encryption parameter to scram-sha-256 (ALTER SYSTEM SET password_encryption = ''scram-sha-256'' ). Warning, you will need to reset all passwords after this parameter is updated.']
),


-- Table Rules (T series)
(
    20, 'TableWithoutPrimaryKey', 'T001', 1, 1, 'TABLE',
    'table without primary key.',
    'no primary key on table(s)',
    ARRAY['create a primary key']
),

(
    22, 'TableWithRedundantIndex', 'T002', 10, 20, 'TABLE',
    'table with duplicated index.',
    'duplicated index',
    ARRAY[
        'remove duplicated index',
        'check for constraints that can create indexes.'
    ]
),

(
    23, 'TableWithFkNotIndexed', 'T003', 1, 1, 'TABLE',
    'When you delete or update a row in the parent table, the database must check the child table to ensure there are no orphaned records. An index on the foreign key allows for a rapid lookup, ensuring that these checks don''t negatively impact performance.',
    'unindexed constraint',
    ARRAY['create an index on the child table fk.']
),

(
    24, 'TableWithPotentialMissingIdx', 'T004', 50, 90, 'TABLE',
    ' with high level of seq scan, base on pg_stat_user_tables.',
    'table with potential missing index',
    ARRAY['ask a dba']
),

(
    25, 'TableWithFkOutsideSchema', 'T005', 1, 1, 'TABLE',
    'table with fk outside its schema. This can be problematic for  maintenance and scalability of the database, refreshing staging/preprod from prod, as well as for understanding the data model.  Migration challenges: Moving or restructuring schemas becomes difficult.',
    'foreign key outside schema',
    ARRAY['consider rewrite your model', 'ask a dba']
),

(
    26, 'TableWithUnusedIndex', 'T006', 200, 500, 'TABLE',
    'Table unused index, base on pg_stat_user_indexes, indexes associated to constraints are discard. Warning and error level are in Mo (the table size to consider).',
    'Index (larger than threshold) seems to be unused.',
    ARRAY['remove unused index or change warning/error threshold']
),

(
    27, 'TableWithFkMismatch', 'T007', 1, 1, 'TABLE',
    'table with fk mismatch, ex smallint refer to a bigint.',
    'Table with fk type mismatch.',
    ARRAY['consider rewrite your model', 'ask a dba']
),

(
    28, 'TableWithRoleNotGranted', 'T008', 1, 1, 'TABLE',
    'Table has no roles grantee. Meaning that users will need direct access on it (not through a role).',
    'No role grantee on table. it means that except owner, users will need a direct grant on this table, not through a role. Prefer RBAC access if possible.',
    ARRAY[
        'create roles (myschema_ro & myschema_rw) and grant it on table with appropriate privileges'
    ]
),

(
    29, 'ReservedKeyWord', 'T009', 10, 20, 'TABLE',
    'An object use reserved keywords.',
    'Reserved keywords in object.',
    ARRAY['Rename the object to use a non reserved keyword']
),

(
    31, 'TableWithSensibleColumn', 'T010', 50, 80, 'TABLE',
    'Base on the extension anon (https://postgresql-anonymizer.readthedocs.io/en/stable/detection), show sensitive column.',
    '{0} have column {1} (category {2}) that can be consider has sensitive. It should be masked for non data-operator users.',
    ARRAY['Install extension anon, and create some masking rules on']
),
(
    32, 'TableSharingSameTrigger', 'T015', 1, 1, 'TABLE',
    'Table shares the same trigger function with other tables.',
    'Table shares trigger function with other tables.',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
),

-- Schema Rules (S series)
(
    40, 'SchemaWithDefaultRoleNotGranted', 'S001', 1, 1, 'SCHEMA',
    'The schema ha no default role. Means that futur table will not be granted through a role. So you will have to re-execute grants on it.',
    'No default role grantee on schema {0}.{1}. It means that each time a table is created, you must grant it to roles.',
    ARRAY[
        'add a default privilege=> ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> for user <schema''s owner>'
    ]
),

(
    41, 'SchemaPrefixedOrSuffixedWithEnvt', 'S002', 1, 1, 'SCHEMA',
    'The schema is prefixed with one of staging,stg,preprod,prod,sandbox,sbox string. Means that when you refresh your preprod, staging environments from production, you have to rename the target schema from prod_ to stg_ or something like. It is possible, but it is never easy.',
    'You should not prefix or suffix the schema name with {0}. You may have difficulties when refreshing environments. Prefer prefix or suffix the database name.',
    ARRAY[
        'Keep the same schema name across environments. Prefer prefix or suffix the database name'
    ]
),
(
    45, 'HowManyTableSharingSameTrigger', 'B015', 20, 80, 'BASE',
    'Count number of table that use the same trigger vs nb table with their own triggers.',
    '{0}/{1} table(s) using the same trigger function exceed the {2} threshold: {3}%.',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
);

-- =============================================================================
-- RULE QUERY UPDATES - Auto-generated from individual SQL files
-- =============================================================================
-- The following UPDATE statements populate the q1 and q2 columns
-- with SQL queries extracted from individual *q*.sql files.
-- These queries are used by the pglinter engine to execute rule checks.
-- =============================================================================

-- B001 - Tables Without Primary Key
UPDATE pglinter.rules
SET q1 = $$
SELECT count(*) AS total_tables
FROM pg_catalog.pg_tables
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B001';

UPDATE pglinter.rules
SET q2 = $$
SELECT count(DISTINCT pg_class.relname) AS total_indexes
FROM pg_index, pg_class, pg_attribute, pg_namespace
WHERE
    indrelid = pg_class.oid
    AND nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND pg_class.relnamespace = pg_namespace.oid
    AND pg_attribute.attrelid = pg_class.oid
    AND pg_attribute.attnum = any(pg_index.indkey)
    AND indisprimary
$$
WHERE code = 'B001';


-- =============================================================================
-- B002 - Redundant Indexes (Total Index Count Query)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT COUNT(*) AS total_indexes
FROM pg_indexes
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B002';

-- =============================================================================
-- B002 - Redundant Indexes (Problem Query)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT COUNT(*) AS redundant_indexes
FROM (
    SELECT DISTINCT i1.indexrelid
    FROM pg_index i1, pg_index i2
    WHERE
        i1.indrelid = i2.indrelid
        AND i1.indexrelid != i2.indexrelid
        AND i1.indkey = i2.indkey
        AND EXISTS (
            SELECT 1 FROM pg_indexes pi1
            WHERE
                pi1.indexname
                = (
                    SELECT relname FROM pg_class
                    WHERE oid = i1.indexrelid
                )
                AND pi1.schemaname NOT IN (
                    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
                )
        )
) redundant
$$
WHERE code = 'B002';

-- -- =============================================================================
-- -- C001 - Memory Configuration Analysis
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT
--     current_setting('max_connections')::int AS max_connections,
--     current_setting('work_mem') AS work_mem_setting
-- $$
-- WHERE code = 'C001';

-- =============================================================================
-- T001 - Tables Without Primary Keys (Problem Detection Query)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT pt.schemaname::text || '.' || pt.tablename::text AS problematic_object
FROM pg_tables AS pt
WHERE
    pt.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_constraint AS pc
        WHERE
            pc.conrelid = (
                SELECT pg_class.oid
                FROM pg_class
                JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
                WHERE
                    pg_class.relname = pt.tablename
                    AND pg_namespace.nspname = pt.schemaname
            )
            AND pc.contype = 'p'
    )
ORDER BY 1
$$
WHERE code = 'T001';

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
-- T005 - Cross-Schema Foreign Key Constraints
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    tc.table_schema::text || '.'
    || tc.table_name::text || ' fk '
    || tc.constraint_name::text || ' reference '
    || ccu.table_schema::text || '.'
    || ccu.table_name::text AS problematic_object
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema != ccu.table_schema
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND ccu.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
ORDER BY 1
$$
WHERE code = 'T005';

-- =============================================================================
-- B003 - Foreign Key Index Coverage (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT count(DISTINCT tc.table_name)::INT AS total_tables
FROM
    information_schema.table_constraints AS tc
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B003';

-- =============================================================================
-- B003 - Foreign Key Index Coverage (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT COUNT(DISTINCT c.relname)::INT AS tables_with_unindexed_foreign_keys
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN
    pg_index i
    ON i.indrelid = c.oid AND con.conkey::smallint [] <@ i.indkey::smallint []
WHERE
    con.contype = 'f'
    AND c.relkind = 'r'
    AND i.indexrelid IS NULL
    AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema', 'pglinter')
$$
WHERE code = 'B003';

-- =============================================================================
-- C002 - Authentication Security (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT count(*) FROM pg_catalog.pg_hba_file_rules
$$
WHERE code = 'C002';

-- =============================================================================
-- C002 - Authentication Security (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT count(*)
FROM pg_catalog.pg_hba_file_rules
WHERE auth_method IN ('trust', 'password')
$$
WHERE code = 'C002';

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
-- T003 - Foreign Keys Without Index
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT DISTINCT
    tc.table_schema::text || '.'
    || tc.table_name::text || ' constraint name:'
    || tc.constraint_name::text AS problematic_object
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON
        tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND NOT EXISTS (
        SELECT 1 FROM pg_indexes AS pi
        WHERE
            pi.schemaname = tc.table_schema
            AND pi.tablename = tc.table_name
            AND pi.indexdef LIKE '%' || kcu.column_name || '%'
    )
ORDER BY 1
$$
WHERE code = 'T003';

-- =============================================================================
-- T008 - Tables Without Role-Based Access
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT t.table_schema::text || '.' || t.table_name::text||' as no role granted' AS problematic_object
FROM information_schema.tables AS t
WHERE
    t.table_schema NOT IN (
        'public', 'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
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
ORDER BY 1
$$
WHERE code = 'T008';

-- =============================================================================
-- T010 - Tables With Sensitive Columns (requires anon extension)
-- =============================================================================
UPDATE pglinter.rules
SET enable=false,q1 = $$
SELECT
    schemaname::text || '.'
    || tablename::text || '.'
    || attname::text || '.'
    || identifiers_category::text AS problematic_object
FROM (
    SELECT
        schemaname,
        tablename,
        attname,
        identifiers_category
    FROM anon.detect('en_US')
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
    UNION
    SELECT
        schemaname,
        tablename,
        attname,
        identifiers_category
    FROM anon.detect('fr_FR')
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
) sensitive_columns
$$
WHERE code = 'T010';

-- =============================================================================
-- B004 - Manual Index Usage (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT COUNT(*) AS total_manual_indexes
FROM pg_stat_user_indexes AS psu
JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
WHERE
    pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
    -- Excludes indexes created for a UNIQUE constraint
    AND pgi.indisunique = FALSE
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B004';

-- =============================================================================
-- B004 - Manual Index Usage (Problems - Unused)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT COUNT(*) AS unused_manual_indexes
FROM pg_stat_user_indexes AS psu
JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
WHERE
    psu.idx_scan = 0
    AND pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
    -- Excludes indexes created for a UNIQUE constraint
    AND pgi.indisunique = FALSE
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B004';

-- =============================================================================
-- B005 - Schema Public Access (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT COUNT(*) AS total_schemas
FROM pg_namespace
WHERE
    nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
$$
WHERE code = 'B005';

-- =============================================================================
-- B005 - Schema Public Access (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT COUNT(*) AS total_schemas
FROM pg_namespace
WHERE
    nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND HAS_SCHEMA_PRIVILEGE('public', nspname, 'CREATE')
$$
WHERE code = 'B005';

-- =============================================================================
-- T004 - Sequential Scan Ratio
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    schemaname::text || '.'
    || relname::text || ':'
    || LEAST(
        ROUND(
            (
                seq_tup_read::numeric
                / NULLIF((seq_tup_read + idx_tup_fetch)::numeric, 0)
            ) * 100, 0
        ),
        100
    )::text ||' % of seq scan' AS problematic_object
FROM pg_stat_user_tables
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
ORDER BY 1
$$
WHERE code = 'T004';

-- =============================================================================
-- T006 - Large Unused Indexes
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    pi.schemaname::text || '.'
    || pi.tablename::text || ' idx '
    || pi.indexname::text || ' size '
    || pg_size_pretty(pg_relation_size(indexrelid))::text AS problematic_object
FROM pg_stat_user_indexes AS psi
INNER JOIN pg_indexes AS pi
    ON
        psi.indexrelname = pi.indexname
        AND psi.schemaname = pi.schemaname
WHERE
    psi.idx_scan = 0
    AND pi.indexdef !~* 'unique'
    AND pi.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND pg_relation_size(indexrelid) > $1
ORDER BY 1
$$
WHERE code = 'T006';

-- =============================================================================
-- B006 - Objects With Uppercase (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT COUNT(*) AS total_objects
FROM (
    -- All tables
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.tables
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )

    UNION

    -- All columns
    SELECT
        'column' AS object_type,
        table_schema AS schema_name,
        table_name || '.' || column_name AS object_name
    FROM information_schema.columns
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )

    UNION

    -- All indexes
    SELECT
        'index' AS object_type,
        schemaname AS schema_name,
        indexname AS object_name
    FROM pg_indexes
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )

    UNION

    -- All sequences
    SELECT
        'sequence' AS object_type,
        sequence_schema AS schema_name,
        sequence_name AS object_name
    FROM information_schema.sequences
    WHERE
        sequence_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )

    UNION

    -- All views
    SELECT
        'view' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.views
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )

    UNION

    -- All functions
    SELECT
        'function' AS object_type,
        routine_schema AS schema_name,
        routine_name AS object_name
    FROM information_schema.routines
    WHERE
        routine_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND routine_type = 'FUNCTION'

    UNION

    -- All triggers
    SELECT
        'trigger' AS object_type,
        trigger_schema AS schema_name,
        trigger_name AS object_name
    FROM information_schema.triggers
    WHERE
        trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )

    UNION

    -- All schemas
    SELECT
        'schema' AS object_type,
        schema_name AS schema_name,
        schema_name AS object_name
    FROM information_schema.schemata
    WHERE
        schema_name NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
) all_objects
$$
WHERE code = 'B006';

-- =============================================================================
-- B006 - Objects With Uppercase (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT COUNT(*) AS uppercase_objects
FROM (
    -- Tables with uppercase names
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.tables
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND table_name != LOWER(table_name)

    UNION

    -- Columns with uppercase names
    SELECT
        'column' AS object_type,
        table_schema AS schema_name,
        table_name || '.' || column_name AS object_name
    FROM information_schema.columns
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND column_name != LOWER(column_name)

    UNION

    -- Indexes with uppercase names
    SELECT
        'index' AS object_type,
        schemaname AS schema_name,
        indexname AS object_name
    FROM pg_indexes
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND indexname != LOWER(indexname)

    UNION

    -- Sequences with uppercase names
    SELECT
        'sequence' AS object_type,
        sequence_schema AS schema_name,
        sequence_name AS object_name
    FROM information_schema.sequences
    WHERE
        sequence_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND sequence_name != LOWER(sequence_name)

    UNION

    -- Views with uppercase names
    SELECT
        'view' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.views
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND table_name != LOWER(table_name)

    UNION

    -- Functions with uppercase names
    SELECT
        'function' AS object_type,
        routine_schema AS schema_name,
        routine_name AS object_name
    FROM information_schema.routines
    WHERE
        routine_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND routine_type = 'FUNCTION'
        AND routine_name != LOWER(routine_name)

    UNION

    -- Triggers with uppercase names
    SELECT
        'trigger' AS object_type,
        trigger_schema AS schema_name,
        trigger_name AS object_name
    FROM information_schema.triggers
    WHERE
        trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND trigger_name != LOWER(trigger_name)

    UNION

    -- Schemas with uppercase names
    SELECT
        'schema' AS object_type,
        schema_name AS schema_name,
        schema_name AS object_name
    FROM information_schema.schemata
    WHERE
        schema_name NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND schema_name != LOWER(schema_name)
) uppercase_objects
$$
WHERE code = 'B006';

-- =============================================================================
-- B007 - Tables Never Selected (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT count(*)
FROM pg_catalog.pg_tables pt
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B007';

-- =============================================================================
-- B007 - Tables Never Selected (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT COUNT(*) AS unselected_tables
FROM pg_stat_user_tables AS psu
WHERE
    (psu.idx_scan = 0 OR psu.idx_scan IS NULL)
    AND (psu.seq_scan = 0 OR psu.seq_scan IS NULL)
    AND n_tup_ins > 0
    AND (n_tup_upd = 0 OR n_tup_upd IS NULL)
    AND (n_tup_del = 0 OR n_tup_del IS NULL)
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B007';

-- =============================================================================
-- B008 - Tables With FK Outside Schema (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT count(*)
FROM pg_catalog.pg_tables pt
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B008';

-- =============================================================================
-- B008 - Tables With FK Outside Schema (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT
    COUNT(
        DISTINCT tc.table_schema || '.' || tc.table_name
    ) AS tables_with_fk_outside_schema
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema != ccu.table_schema
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
$$
WHERE code = 'B008';

-- =============================================================================
-- T002 - Table With Redundant Index
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
WITH index_info AS (
    -- This CTE gets the name and order of all columns for each index.
    SELECT
        ind.indrelid AS table_oid,
        ind.indexrelid AS index_oid,
        att.attname AS column_name,
        array_position(ind.indkey, att.attnum) AS column_order
    FROM pg_index ind
    JOIN pg_attribute att ON att.attrelid = ind.indrelid AND att.attnum = ANY(ind.indkey)
    WHERE ind.indisprimary = FALSE AND NOT ind.indisexclusion
),
indexed_columns AS (
    -- This CTE aggregates the columns for each index into an ordered string.
    SELECT
        table_oid,
        index_oid,
        string_agg(column_name, ',' ORDER BY column_order) AS indexed_columns_string
    FROM index_info
    GROUP BY table_oid, index_oid
),
table_info AS (
    -- Joins to pg_class and pg_namespace to get table names and schema names.
    SELECT
        oid AS table_oid,
        relname AS tablename,
        relnamespace
    FROM pg_class
)
SELECT
    pg_namespace.nspname::TEXT ||'.'||table_info.tablename::TEXT||
    ' idx '||redundant_index.relname::TEXT||
    ' columns ('||i1.indexed_columns_string||') is a subset of '||
    'idx '||superset_index.relname::TEXT||
    ' columns ('||i2.indexed_columns_string||')' AS problematic_object
FROM indexed_columns AS i1
JOIN indexed_columns AS i2 ON i1.table_oid = i2.table_oid
JOIN pg_class redundant_index ON i1.index_oid = redundant_index.oid
JOIN pg_class superset_index ON i2.index_oid = superset_index.oid
JOIN table_info ON i1.table_oid = table_info.table_oid
JOIN pg_namespace ON table_info.relnamespace = pg_namespace.oid
WHERE
    pg_namespace.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND redundant_index.oid <> superset_index.oid -- Ensure the indexes are not the same
    -- Checks if the smaller index's column string is a prefix of the larger index's string.
    AND i2.indexed_columns_string LIKE i1.indexed_columns_string || '%'
ORDER BY 1
$$
WHERE code = 'T002';

-- =============================================================================
-- T007 - Table With FK Mismatch
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    tc.table_schema::text || '.'
    || tc.table_name::text || ' constraint '
    || tc.constraint_name::text || ' column '
    || kcu.column_name::text || ' type is '
    || col1.data_type::text || ' but'
    || ccu.table_name::text || '.'
    || ccu.column_name::text || ' type is '
    || col2.data_type::text AS problematic_object
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON
        tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
INNER JOIN information_schema.columns AS col1
    ON
        kcu.table_schema = col1.table_schema
        AND kcu.table_name = col1.table_name
        AND kcu.column_name = col1.column_name
INNER JOIN information_schema.columns AS col2
    ON
        ccu.table_schema = col2.table_schema
        AND ccu.table_name = col2.table_name
        AND ccu.column_name = col2.column_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND col1.data_type != col2.data_type
ORDER BY 1
$$
WHERE code = 'T007';

-- =============================================================================
-- T009 - Reserved Keywords
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
WITH reserved_keywords AS (
    SELECT UNNEST(ARRAY[
        'ALL', 'ANALYSE', 'ANALYZE', 'AND', 'ANY', 'ARRAY', 'AS', 'ASC',
        'ASYMMETRIC', 'AUTHORIZATION', 'BINARY', 'BOTH', 'CASE', 'CAST',
        'CHECK', 'COLLATE', 'COLLATION', 'COLUMN', 'CONCURRENTLY',
        'CONSTRAINT', 'CREATE', 'CROSS', 'CURRENT_CATALOG', 'CURRENT_DATE',
        'CURRENT_ROLE', 'CURRENT_SCHEMA', 'CURRENT_TIME', 'CURRENT_TIMESTAMP',
        'CURRENT_USER', 'DEFAULT', 'DEFERRABLE', 'DESC', 'DISTINCT', 'DO',
        'ELSE', 'END', 'EXCEPT', 'FALSE', 'FETCH', 'FOR', 'FOREIGN', 'FROM',
        'FULL', 'GRANT', 'GROUP', 'HAVING', 'IN', 'INITIALLY', 'INNER',
        'INTERSECT', 'INTO', 'IS', 'ISNULL', 'JOIN', 'LATERAL', 'LEADING',
        'LEFT', 'LIKE', 'LIMIT', 'LOCALTIME', 'LOCALTIMESTAMP', 'NATURAL',
        'NOT', 'NOTNULL', 'NULL', 'OFFSET', 'ON', 'ONLY', 'OR', 'ORDER',
        'OUTER', 'OVERLAPS', 'PLACING', 'PRIMARY', 'REFERENCES', 'RETURNING',
        'RIGHT', 'SELECT', 'SESSION_USER', 'SIMILAR', 'SOME', 'SYMMETRIC',
        'TABLE', 'TABLESAMPLE', 'THEN', 'TO', 'TRAILING', 'TRUE', 'UNION',
        'UNIQUE', 'USER', 'USING', 'VARIADIC', 'VERBOSE', 'WHEN', 'WHERE',
        'WINDOW', 'WITH'
    ]) AS keyword
)
SELECT
    object_type || ':' || schema_name || '.' || object_name ||' is a reserved keyword.' AS problematic_object
FROM (
    -- Tables using reserved keywords
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.tables
    CROSS JOIN reserved_keywords
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND UPPER(table_name) = keyword

    UNION

    -- Columns using reserved keywords
    SELECT
        'column' AS object_type,
        table_schema AS schema_name,
        table_name || '.' || column_name AS object_name
    FROM information_schema.columns
    CROSS JOIN reserved_keywords
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND UPPER(column_name) = keyword

    UNION

    -- Indexes using reserved keywords
    SELECT
        'index' AS object_type,
        schemaname AS schema_name,
        indexname AS object_name
    FROM pg_indexes
    CROSS JOIN reserved_keywords
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
        AND UPPER(indexname) = keyword
) reserved_objects
ORDER BY 1
$$
WHERE code = 'T009';

-- =============================================================================
-- C003 - MD5 encrypted Passwords (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT 'password_encryption is ' || setting FROM
pg_catalog.pg_settings
WHERE name='password_encryption' AND setting='md5'
$$
WHERE code = 'C003';

-- =============================================================================
-- B015 - Tables With same trigger
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    COUNT(DISTINCT event_object_table) as table_using_trigger
FROM
    information_schema.triggers t
WHERE
    t.trigger_schema NOT IN (
    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
)
$$
WHERE code = 'B015';

-- =============================================================================
-- B015 - Tables With same trigger
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT
    COUNT(DISTINCT t.event_object_table) AS table_using_same_trigger
FROM (
    SELECT
        t.event_object_table ,
        -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
        SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
    FROM
        information_schema.triggers t
    WHERE
        t.trigger_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
) t
GROUP BY
    t.trigger_function_name
HAVING
    COUNT(DISTINCT t.event_object_table) > 1
$$
WHERE code = 'B015';

-- =============================================================================
-- T015 - Tables Sharing Same Trigger Function
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    t.trigger_schema::text || '.' || t.event_object_table::text ||
    ' shares trigger function ' || t.trigger_function_name::text ||
    ' with other tables' AS problematic_object
FROM (
    SELECT
        t.trigger_schema,
        t.event_object_table,
        -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
        SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
    FROM
        information_schema.triggers t
    WHERE
        t.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
) t
WHERE t.trigger_function_name IN (
    -- Subquery to find trigger functions shared by multiple tables
    SELECT
        SUBSTRING(t2.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS shared_function
    FROM
        information_schema.triggers t2
    WHERE
        t2.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
    GROUP BY
        SUBSTRING(t2.action_statement FROM 'EXECUTE FUNCTION ([^()]+)')
    HAVING
        COUNT(DISTINCT t2.event_object_table) > 1
)
ORDER BY t.trigger_function_name, t.event_object_table
$$
WHERE code = 'T015';
