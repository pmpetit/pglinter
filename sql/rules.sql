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
--
-- Each rule includes:
--   - Rule code (e.g., B001, T003)
--   - Scope (BASE, CLUSTER, SCHEMA, TABLE)
--   - Descriptive metadata and fix suggestions
--
-- Usage:
--   This file is automatically executed during extension installation
--   via pgrx's extension_sql_file! macro.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS pglinter.rules (
    id SERIAL PRIMARY KEY,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    scope TEXT,
    description TEXT,
    message TEXT,
    fixes TEXT [],
    q4 TEXT
);


-- Clear existing data and insert comprehensive rules
DELETE FROM pglinter.rules;

INSERT INTO pglinter.rules (
    name,
    code,
    scope,
    description,
    message,
    fixes,
    q4
) VALUES
-- Base Database Rules (B series)
(
    'HowManyTableWithoutPrimaryKey', 'B001', 'BASE',
    'Count number of tables without primary key.',
    '{0}/{1} table(s) without primary key. Object list:\n{4}',
    ARRAY['create a primary key'],
    $q$-- Returns classid, objid, objsubid for tables without a primary key
SELECT
    'pg_class'::regclass::oid AS classid,
    c.oid AS objid,
    0 AS objsubid
FROM pg_tables AS pt
JOIN pg_class c
    ON c.relname = pt.tablename
    AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = pt.schemaname)
WHERE
    pt.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_constraint AS pc
        WHERE
            pc.conrelid = c.oid
            AND pc.contype = 'p'
    )$q$
),
(
    'HowManyRedudantIndex', 'B002', 'BASE',
    'Count number of redundant index vs nb index.',
    '{0}/{1} redundant(s) index. Object list:\n{4}',
    ARRAY[
        'remove duplicated index or check if a constraint does not create a redundant index'
    ],
    $q$WITH index_info AS (
    SELECT
        ind.indrelid AS table_oid,
        ind.indexrelid AS index_oid,
        att.attname AS column_name,
        array_position(ind.indkey, att.attnum) AS column_order,
        ind.indisprimary
    FROM pg_index ind
    JOIN pg_attribute att ON att.attrelid = ind.indrelid AND att.attnum = ANY(ind.indkey)
    WHERE NOT ind.indisexclusion
),
indexed_columns AS (
    SELECT
        table_oid,
        index_oid,
        string_agg(column_name, ',' ORDER BY column_order) AS indexed_columns_string,
        MAX(indisprimary::int)::bool AS is_primary_key
    FROM index_info
    GROUP BY table_oid, index_oid
),
table_info AS (
    SELECT
        oid AS table_oid,
        relname AS tablename,
        relnamespace
    FROM pg_class
)
SELECT
    'pg_class'::regclass::oid AS classid,
    i1.index_oid AS objid,
    0 AS objsubid
FROM indexed_columns AS i1
JOIN indexed_columns AS i2 ON i1.table_oid = i2.table_oid
JOIN pg_class redundant_index ON i1.index_oid = redundant_index.oid
JOIN pg_class superset_index ON i2.index_oid = superset_index.oid
JOIN table_info ON i1.table_oid = table_info.table_oid
JOIN pg_namespace ON table_info.relnamespace = pg_namespace.oid
WHERE
    pg_namespace.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND i1.index_oid <> i2.index_oid
    AND i2.indexed_columns_string LIKE i1.indexed_columns_string || '%'$q$
),
(
    'HowManyTableWithoutIndexOnFk', 'B003', 'BASE',
    'Count number of tables without index on foreign key.',
    '{0}/{1} table(s) without index on foreign key. Object list:\n{4}',
    ARRAY['create an index on foreign key columns'],
    $q$-- Returns classid, objid, objsubid for foreign key constraints lacking an index
SELECT
    'pg_constraint'::regclass::oid AS classid,
    con.oid AS objid,
    0 AS objsubid
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_index i ON i.indrelid = c.oid AND con.conkey::smallint [] <@ i.indkey::smallint []
WHERE
    con.contype = 'f'
    AND c.relkind = 'r'
    AND i.indexrelid IS NULL
    AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')$q$
),
(
    'HowManyUnusedIndex', 'B004', 'BASE',
    'Count number of unused index vs nb index (base on pg_stat_user_indexes, indexes associated to unique constraints are discard.)',
    '{0}/{1} unused index. Object list:\n{4}',
    ARRAY['remove unused index'],
    $q$-- Returns classid, objid, objsubid for unused manual indexes
SELECT
    'pg_class'::regclass::oid AS classid,
    psu.indexrelid AS objid,
    0 AS objsubid
FROM pg_stat_user_indexes AS psu
JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
WHERE
    psu.idx_scan = 0
    AND pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
    AND pgi.indisunique = FALSE -- Excludes indexes created for a UNIQUE constraint
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )$q$
),
(
    'HowManyObjectsWithUppercase', 'B005', 'BASE',
    'Count number of objects with uppercase in name or in columns.',
    '{0}/{1} object(s) using uppercase for name or columns. Object list:\n{4}',
    ARRAY['Do not use uppercase for any database objects'],
    $q$-- Returns classid, objid, objsubid for objects with uppercase in their name
SELECT 'pg_class'::regclass::oid AS classid, c.oid AS objid, 0 AS objsubid
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND (
    c.relname != LOWER(c.relname)
  )
UNION ALL
SELECT 'pg_attribute'::regclass::oid AS classid, a.attrelid AS objid, a.attnum AS objsubid
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND a.attnum > 0
  AND a.attname != LOWER(a.attname)
UNION ALL
SELECT 'pg_class'::regclass::oid AS classid, c.oid AS objid, 0 AS objsubid
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND c.relkind = 'i'
  AND c.relname != LOWER(c.relname)
UNION ALL
SELECT 'pg_class'::regclass::oid AS classid, c.oid AS objid, 0 AS objsubid
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND c.relkind = 'S'
  AND c.relname != LOWER(c.relname)
UNION ALL
SELECT 'pg_class'::regclass::oid AS classid, c.oid AS objid, 0 AS objsubid
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND c.relkind = 'v'
  AND c.relname != LOWER(c.relname)
UNION ALL
SELECT 'pg_proc'::regclass::oid AS classid, p.oid AS objid, 0 AS objsubid
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND p.proname != LOWER(p.proname)
UNION ALL
SELECT 'pg_trigger'::regclass::oid AS classid, t.oid AS objid, 0 AS objsubid
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND t.tgname != LOWER(t.tgname)
UNION ALL
SELECT 'pg_namespace'::regclass::oid AS classid, n.oid AS objid, 0 AS objsubid
FROM pg_namespace n
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')
  AND n.nspname != LOWER(n.nspname)$q$
),
(
    'HowManyTablesNeverSelected', 'B006', 'BASE',
    'Count number of table(s) that has never been selected.',
    '{0}/{1} table(s) are never selected. Object list:\n{4}',
    ARRAY[
        'Is it necessary to update/delete/insert rows in table(s) that are never selected ?'
    ],
    $q$SELECT
    'pg_class'::regclass::oid AS classid,
    c.oid AS objid,
    0 AS objsubid
FROM pg_stat_user_tables AS psu
JOIN pg_class c
    ON c.relname = psu.relname
    AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = psu.schemaname)
WHERE
    (psu.idx_scan = 0 OR psu.idx_scan IS NULL)
    AND (psu.seq_scan = 0 OR psu.seq_scan IS NULL)
    AND psu.n_tup_ins > 0
    AND (psu.n_tup_upd = 0 OR psu.n_tup_upd IS NULL)
    AND (psu.n_tup_del = 0 OR psu.n_tup_del IS NULL)
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )$q$
),
(
    'HowManyTablesWithFkOutsideSchema', 'B007', 'BASE',
    'Count number of tables with foreign keys outside their schema.',
    '{0}/{1} table(s) with foreign keys outside schema. Object list:\n{4}',
    ARRAY[
        'Consider restructuring schema design to keep related tables in same schema',
        'ask a dba'
    ],
    $q$SELECT
    'pg_constraint'::regclass::oid AS classid,
    c.oid AS objid,
    0 AS objsubid
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
INNER JOIN pg_constraint c
    ON c.conname = tc.constraint_name
    AND c.conrelid = (
        SELECT oid FROM pg_class WHERE relname = tc.table_name
            AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = tc.table_schema)
    )
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema != ccu.table_schema
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )$q$
),
(
    'HowManyTablesWithFkMismatch', 'B008', 'BASE',
    'Count number of tables with foreign keys that do not match the key reference type.',
    '{0}/{1} table(s) with foreign key mismatch. Object list:\n{4}',
    ARRAY[
        'Consider column type adjustments to ensure foreign key matches referenced key type',
        'ask a dba'
    ],
    $q$SELECT
    'pg_attribute'::regclass::oid AS classid,
    c.oid AS objid,
    a.attnum AS objsubid
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
INNER JOIN information_schema.columns AS col1
    ON kcu.table_schema = col1.table_schema
    AND kcu.table_name = col1.table_name
    AND kcu.column_name = col1.column_name
INNER JOIN information_schema.columns AS col2
    ON ccu.table_schema = col2.table_schema
    AND ccu.table_name = col2.table_name
    AND ccu.column_name = col2.column_name
JOIN pg_class c
    ON c.relname = kcu.table_name
    AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = kcu.table_schema)
JOIN pg_attribute a
    ON a.attrelid = c.oid
    AND a.attname = kcu.column_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND col1.data_type != col2.data_type$q$
),
(
    'HowManyTablesWithSameTrigger', 'B009', 'BASE',
    'Count number of tables using the same trigger vs nb table with their own triggers.',
    '{0}/{1} table(s) using the same trigger function. Object list:\n{4}',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ],
    $q$-- Returns classid, objid, objsubid for tables using the same trigger function (B009)
WITH SharedFunctions AS (
    SELECT
        SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
    FROM
        information_schema.triggers t
    WHERE
        t.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
    GROUP BY
        1
    HAVING
        COUNT(DISTINCT t.event_object_table) > 1
)
SELECT
    'pg_trigger'::regclass::oid AS classid,
    tg.oid AS objid,
    0 AS objsubid
FROM
    pg_trigger tg
JOIN pg_class c ON c.oid = tg.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN information_schema.triggers t
    ON t.trigger_name = tg.tgname
    AND t.event_object_table = c.relname
    AND t.trigger_schema = n.nspname
JOIN SharedFunctions s ON s.trigger_function_name = SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)')
WHERE
    n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )$q$
),
(
    'HowManyTablesWithReservedKeywords', 'B010', 'BASE',
    'Count number of database objects using reserved keywords in their names.',
    '{0}/{1} object(s) using reserved keywords. Object list:\n{4}',
    ARRAY[
        'Rename database objects to avoid using reserved keywords.',
        'Using reserved keywords can lead to SQL syntax errors and maintenance difficulties.'
    ],
    $q$WITH reserved_keywords AS (
    SELECT unnest(ARRAY[
        'SELECT','FROM','WHERE','ORDER','GROUP','HAVING','UNION','JOIN','LIMIT','OFFSET',
        'PRIMARY','UNIQUE','FOREIGN','AND','OR','CASE','WHEN','THEN','ELSE','END','DISTINCT',
        'NULL','TRUE','FALSE','AS','IN','ON','BY','IS','NOT','EXISTS','ALL','ANY','BETWEEN'
    ]) AS keyword
),

-- Tables, Views, Sequences
obj_class AS (
    SELECT
        'pg_class'::regclass::oid AS classid,
        c.oid AS objid,
        0 AS objsubid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN reserved_keywords rk ON c.relname = rk.keyword
    WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
),

-- Columns
obj_column AS (
    SELECT
        'pg_attribute'::regclass::oid AS classid,
        a.attrelid AS objid,
        a.attnum AS objsubid
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN reserved_keywords rk ON a.attname = rk.keyword
    WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
      AND a.attnum > 0 AND NOT a.attisdropped
),

-- Indexes
obj_index AS (
    SELECT
        'pg_class'::regclass::oid AS classid,
        i.oid AS objid,
        0 AS objsubid
    FROM pg_class i
    JOIN pg_namespace n ON n.oid = i.relnamespace
    JOIN reserved_keywords rk ON i.relname = rk.keyword
    WHERE i.relkind = 'i'
      AND n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
),

-- Functions
obj_func AS (
    SELECT
        'pg_proc'::regclass::oid AS classid,
        p.oid AS objid,
        0 AS objsubid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN reserved_keywords rk ON p.proname = rk.keyword
    WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
),

-- Types
obj_type AS (
    SELECT
        'pg_type'::regclass::oid AS classid,
        t.oid AS objid,
        0 AS objsubid
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN reserved_keywords rk ON t.typname = rk.keyword
    WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
),

-- Triggers
obj_trigger AS (
    SELECT
        'pg_trigger'::regclass::oid AS classid,
        tg.oid AS objid,
        0 AS objsubid
    FROM pg_trigger tg
    JOIN pg_class c ON c.oid = tg.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN reserved_keywords rk ON tg.tgname = rk.keyword
    WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
      AND NOT tg.tgisinternal
)
SELECT * FROM obj_class
UNION ALL
SELECT * FROM obj_column
UNION ALL
SELECT * FROM obj_index
UNION ALL
SELECT * FROM obj_func
UNION ALL
SELECT * FROM obj_type
UNION ALL
SELECT * FROM obj_trigger$q$
),
(
    'SeveralTableOwnerInSchema', 'B011', 'BASE',
    'In a schema there are several tables owned by different owners.',
    '{0}/{1} schemas have tables owned by different owners. Object list:\n{4}',
    ARRAY['change table owners to the same functional role'],
    $q$-- Returns classid, objid, objsubid for tables in schemas with multiple owners (B011)
WITH SchemaOwnerTable AS (
    SELECT DISTINCT
        schemaname,
        tableowner
    FROM
        pg_tables
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
),
OwnerCounts AS (
    SELECT
        schemaname,
        COUNT(tableowner) AS distinct_owner_count
    FROM
        SchemaOwnerTable
    GROUP BY
        schemaname
    HAVING
        COUNT(tableowner) > 1
)
SELECT
    'pg_class'::regclass::oid AS classid,
    c.oid AS objid,
    0 AS objsubid
FROM
    pg_tables t
JOIN
    OwnerCounts oc ON t.schemaname = oc.schemaname
JOIN
    pg_class c ON c.relname = t.tablename
    AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = t.schemaname)
WHERE
    t.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )$q$
),
(
    'CompositePrimaryKeyTooManyColumns', 'B012', 'BASE',
    'Detect tables with composite primary keys involving more than 4 columns',
    '{0} table(s) have composite primary keys with more than 4 columns. Object list:\n{4}',
    ARRAY[
        'Consider redesigning the table to avoid composite primary keys with more than 4 columns',
        'Use surrogate keys (e.g., serial, UUID) instead of composite primary keys, and establish unique constraints on necessary column combinations, to enforce uniqueness.'
    ],
    $q$-- Returns classid, objid, objsubid for tables with composite primary keys involving more than 4 columns (B012)
SELECT
    'pg_class'::regclass::oid AS classid,
    c.oid AS objid,
    0 AS objsubid
FROM (
    SELECT
        tc.table_schema,
        tc.table_name,
        COUNT(kcu.column_name) AS pk_col_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
    HAVING COUNT(kcu.column_name) > 4
) sub
JOIN pg_class c
  ON c.relname = sub.table_name
  AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = sub.table_schema)$q$
),
(
    'HowManyTablesWithRowByRowTriggerWithoutWhereClause',
    'B013',
    'BASE',
    'Count number of tables using a row by row processing without any where clause vs nb table with their own triggers.',
    '{0}/{1} table(s) using row by row processing without any where clause. Object list:\n{4}',
    ARRAY[
        'Prefer using set-based operations instead of row by row processing for better performance.',
        'If not possible, consider adding a WHERE clause to limit the rows processed.'
    ],
    $q$SELECT
    'pg_trigger'::regclass::oid AS classid,
    tg.oid                      AS objid,
    0                           AS objsubid
FROM pg_trigger    tg
JOIN pg_class      c  ON c.oid = tg.tgrelid
JOIN pg_namespace  n  ON n.oid = c.relnamespace
JOIN pg_proc       p  ON p.oid = tg.tgfoid
WHERE
    NOT tg.tgisinternal
    AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
    AND n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND p.prosrc ~* '(?:CURSOR\s+FOR|OPEN\s+\w[\w$]*\s+FOR|FOR\s+\w[\w$]*\s+IN)\s+SELECT'
    AND EXISTS (
        SELECT 1
        FROM regexp_matches(
            p.prosrc,
            '(?:CURSOR\s+FOR|OPEN\s+\w[\w$]*\s+FOR|FOR\s+\w[\w$]*\s+IN)\s+(SELECT\s[^;]+?)(?:;|\mLOOP\M)',
            'gix'
        ) AS m(cursor_select)
        WHERE m.cursor_select[1] !~* '\mWHERE\M'
    )$q$
),
(
    'SchemaWithDefaultRoleNotGranted', 'S001', 'SCHEMA',
    'The schema has no default role. Means that futur table will not be granted through a role. So you will have to re-execute grants on it.',
    'No default role grantee on schema {0}.{1}. It means that each time a table is created, you must grant it to roles. Object list:\n{4}',
    ARRAY[
        'add a default privilege=> ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> for user <schema''s owner>'
    ],
    $q$-- Returns classid, objid, objsubid for schemas with no default role (S001)
SELECT
    'pg_namespace'::regclass::oid AS classid,
    n.oid AS objid,
    0 AS objsubid
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'
    AND NOT EXISTS (
        SELECT 1
        FROM pg_default_acl da
        WHERE
            da.defaclnamespace = n.oid
            AND da.defaclrole != n.nspowner
    )$q$
),

(
    'SchemaPrefixedOrSuffixedWithEnvt', 'S002', 'SCHEMA',
    'The schema is prefixed with one of staging,stg,preprod,prod,sandbox,sbox string. Means that when you refresh your preprod, staging environments from production, you have to rename the target schema from prod_ to stg_ or something like. It is possible, but it is never easy.',
    '{0}/{1} schemas are prefixed or suffixed with environment names. Prefer prefix or suffix the database name instead. Object list:\n{4}',
    ARRAY[
        'Keep the same schema name across environments. Prefer prefix or suffix the database name'
    ],
    $q$-- Returns classid, objid, objsubid for schemas with environment prefixes/suffixes (S002)
SELECT
    'pg_namespace'::regclass::oid AS classid,
    n.oid AS objid,
    0 AS objsubid
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND (
        n.nspname ~* '^(dev|prod|test|stage|staging|qa|uat|preprod|sandbox)_'
        OR n.nspname ~* '_(dev|prod|test|stage|staging|qa|uat|preprod|sandbox)$'
    )$q$
),
(
    'UnsecuredPublicSchema', 'S003', 'SCHEMA',
    'Only authorized users should be allowed to create objects.',
    '{0}/{1} schemas are unsecured, schemas where all users can create objects in. Object list:\n{4}',
    ARRAY['REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC'],
    $q$-- Returns classid, objid, objsubid for schemas where PUBLIC has CREATE privilege (S003)
SELECT
    'pg_namespace'::regclass::oid AS classid,
    n.oid AS objid,
    0 AS objsubid
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND HAS_SCHEMA_PRIVILEGE('public', n.nspname, 'CREATE')$q$
),
(
    'OwnerSchemaIsInternalRole', 'S004', 'SCHEMA',
    'Owner of schema should not be any internal pg roles, or owner is a superuser (not sure it is necesary).',
    '{0}/{1} schemas are owned by internal roles or superuser. Object list:\n{4}',
    ARRAY['change schema owner to a functional role'],
    $q$-- Returns classid, objid, objsubid for schemas owned by internal roles or superuser (S004)
SELECT
    'pg_namespace'::regclass::oid AS classid,
    n.oid AS objid,
    0 AS objsubid
FROM
    pg_namespace n
JOIN
    pg_roles r ON n.nspowner = r.oid
WHERE
    n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND (
        r.rolsuper IS TRUE -- Owned by a Superuser (e.g., 'postgres')
        OR r.rolname LIKE 'pg_%' -- Owned by a reserved PostgreSQL system role
        OR r.rolname = 'postgres' -- Explicitly include the default administrative account
    )$q$
),
(
    'SchemaOwnerDoNotMatchTableOwner', 'S005', 'SCHEMA',
    'The schema owner and tables in the schema do not match.',
    '{0}/{1} in the same schema, tables have different owners. They should be the same. Object list:\n{4}',
    ARRAY[
        'For maintenance facilities, schema and tables owners should be the same.'
    ],
    $q$-- Returns classid, objid, objsubid for tables where the schema owner and table owner differ (S005)
SELECT
    'pg_class'::regclass::oid AS classid,
    c.oid AS objid,
    0 AS objsubid
FROM
    pg_namespace n
JOIN
    pg_class c ON c.relnamespace = n.oid
WHERE
    n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND n.nspname NOT LIKE 'pg_temp%'
    AND c.relkind = 'r'               -- Only regular tables
    AND n.nspowner <> c.relowner      -- Schema owner does NOT equal Table owner$q$
),
(
    'PgHbaEntriesWithMethodTrustShouldNotExists',
    'C001',
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust authentication method.',
    ARRAY['change trust method in pg_hba.conf'],
    NULL
),
(
    'PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists',
    'C002',
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust or password authentication method.',
    ARRAY['change trust or password method in pg_hba.conf'],
    NULL
),
(
    'PasswordEncryptionIsMd5',
    'C003',
    'CLUSTER',
    'This configuration is not secure anymore and will prevent an upgrade to Postgres 18. Warning, you will need to reset all passwords after this is changed to scram-sha-256.',
    'Encrypted passwords with MD5.',
    ARRAY[
        'change password_encryption parameter to scram-sha-256 (ALTER SYSTEM SET password_encryption = ''scram-sha-256'' ). Warning, you will need to reset all passwords after this parameter is updated.'
    ],
    NULL
);


-- =============================================================================
-- Rule Messages Table Creation
-- =============================================================================
CREATE TABLE IF NOT EXISTS pglinter.rule_messages (
    id SERIAL PRIMARY KEY,
    code TEXT,
    rule_msg JSONB
);

DELETE FROM pglinter.rule_messages;

INSERT INTO pglinter.rule_messages (code, rule_msg) VALUES
(
    'S001',
    '{"severity": "WARNING", "message": "Schema {object} has no default role.", "advices": "Add a default privilege to the schema so future tables are granted to a role automatically.", "infos": ["How to fix: ALTER DEFAULT PRIVILEGES IN SCHEMA {object} FOR USER <owner> GRANT ...;"]}'
),
(
    'S002',
    '{"severity": "WARNING", "message": "Schema {object} is prefixed or suffixed with an environment name.", "advices": "Keep the same schema name across environments. Prefer prefixing or suffixing the database name instead.", "infos": ["How to fix: Rename schema {object} to a neutral name."]}'
),
(
    'S003',
    '{"severity": "WARNING", "message": "Schema {object} is unsecured: PUBLIC can create objects.", "advices": "REVOKE CREATE ON SCHEMA from PUBLIC to restrict object creation.", "infos": ["How to fix: REVOKE CREATE ON SCHEMA {object} FROM PUBLIC;"]}'
),
(
    'S004',
    '{"severity": "WARNING", "message": "Schema {object} is owned by an internal role or superuser.", "advices": "Change schema owner to a functional role for better security and maintainability.", "infos": ["How to fix: ALTER SCHEMA {object} OWNER TO <role>;"]}'
),
(
    'S005',
    '{"severity": "WARNING", "message": "Schema {object} and its tables have different owners.", "advices": "For easier maintenance, schema and tables should have the same owner.", "infos": ["How to fix: ALTER TABLE {object} OWNER TO <role>;"]}'
);

INSERT INTO pglinter.rule_messages (code, rule_msg) VALUES
(
    'B001',
    '{"severity": "WARNING", "message": "{object} does not have a primary key.", "advices": "Add a primary key to this table to ensure data integrity and better performance.", "infos": ["How to fix: ALTER TABLE {object} ADD PRIMARY KEY (...);"]}'
),
(
    'B002',
    '{"severity": "WARNING", "message": "{object} is a redundant index.", "advices": "Remove redundant or duplicate indexes to optimize performance and storage.", "infos": ["How to fix: DROP INDEX {object}; or review constraints that may create duplicate indexes."]}'
),
(
    'B003',
    '{"severity": "WARNING", "message": "{object} does not have an index on its foreign key.", "advices": "Create an index on the foreign key column to improve join and lookup performance.", "infos": ["How to fix: CREATE INDEX ON {object} (...);"]}'
),
(
    'B004',
    '{"severity": "WARNING", "message": "{object} is an unused index.", "advices": "Remove unused indexes to reduce storage and maintenance overhead.", "infos": ["How to fix: DROP INDEX {object}; or review index usage statistics."]}'
),
(
    'B005',
    '{"severity": "WARNING", "message": "{object} uses uppercase characters.", "advices": "Using uppercase in identifiers requires quoting and can cause case-sensitivity issues.", "infos": ["How to fix: Rename the database object to use only lowercase characters."]}'
),
(
    'B006',
    '{"severity": "WARNING", "message": "{object} has never been selected.", "advices": "Review the necessity of this table. If it is not needed, consider removing it or archiving its data.", "infos": ["How to fix: DROP TABLE {object}; or investigate application usage."]}'
),
(
    'B007',
    '{"severity": "WARNING", "message": "{object} has foreign keys outside its schema.", "advices": "Consider restructuring schema design to keep related tables in the same schema.", "infos": ["How to fix: Move related tables into the same schema or review schema design."]}'
),
(
    'B008',
    '{"severity": "WARNING", "message": "{object} has a foreign key type mismatch.", "advices": "Adjust column types to ensure foreign key matches referenced key type.", "infos": ["How to fix: ALTER TABLE {object} ALTER COLUMN ... TYPE ...;"]}'
),
(
    'B009',
    '{"severity": "WARNING", "message": "{object} shares a trigger function with other tables.", "advices": "Use one trigger function per table for clarity and maintainability.", "infos": ["How to fix: CREATE a dedicated trigger function for {object} and update the trigger."]}'
),
(
    'B010',
    '{"severity": "WARNING", "message": "{object} uses a reserved SQL keyword as its name.", "advices": "Rename database objects to avoid using reserved keywords.", "infos": ["How to fix: ALTER TABLE/INDEX/VIEW/FUNCTION/TYPE {object} RENAME TO ...;"]}'
),
(
    'B011',
    '{"severity": "WARNING", "message": "{object} schema has tables with different owners.", "advices": "Change table owners to the same functional role for easier maintenance.", "infos": ["How to fix: ALTER TABLE {object} OWNER TO ...;"]}'
),
(
    'B012',
    '{"severity": "WARNING", "message": "{object} has a composite primary key with more than 4 columns.", "advices": "Consider redesigning the table to avoid composite primary keys with more than 4 columns. Use surrogate keys if possible.", "infos": ["How to fix: Redesign {object} to use a surrogate key and unique constraints."]}'
),
(
    'B013',
    '{"severity": "WARNING", "message": "{object} uses a trigger function, that uses a cursor and a row by row processing, without any WHERE clause. Fired trigger can cause performance issues.", "advices": "If possible avoid row by row processing. Use base processing instead. If not possible, then add a where clause to limit the number of returned rows.", "infos": ["How to fix: remove the cursor or add a where clause to the cursor. {object}."]}'
);
