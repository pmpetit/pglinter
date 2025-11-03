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
-- Table Rules (T series)
(
    'TableWithoutPrimaryKey', 'T001', 1, 1, 'TABLE',
    'table without primary key.',
    'no primary key on table(s)',
    ARRAY['create a primary key']
),

(
    'TableWithRedundantIndex', 'T002', 10, 20, 'TABLE',
    'table with duplicated index.',
    'duplicated index',
    ARRAY[
        'remove duplicated index',
        'check for constraints that can create indexes.'
    ]
),

(
    'TableWithFkNotIndexed', 'T003', 1, 1, 'TABLE',
    'When you delete or update a row in the parent table, the database must check the child table to ensure there are no orphaned records. An index on the foreign key allows for a rapid lookup, ensuring that these checks don''t negatively impact performance.',
    'unindexed constraint',
    ARRAY['create an index on the child table fk.']
),
(
    'TableWithUnusedIndex', 'T004', 200, 500, 'TABLE',
    'Table unused index, base on pg_stat_user_indexes, indexes associated to constraints are discard. Warning and error level are in Mo (the table size to consider).',
    'Index (larger than threshold) seems to be unused.',
    ARRAY['remove unused index or change warning/error threshold']
),

(
    'ObjectInUppercase', 'T005', 1, 1, 'TABLE',
    'Object name or column name is in uppercase.',
    'uppercase objects',
    ARRAY['Do not use uppercase for any database objects.']
),

-- (
--     'TableWithPotentialMissingIdx', 'T004', 50, 90, 'TABLE',
--     ' with high level of seq scan, base on pg_stat_user_tables.',
--     'table with potential missing index',
--     ARRAY['ask a dba']
-- ),

(
    'TableWithFkOutsideSchema', 'T007', 1, 1, 'TABLE',
    'table with fk outside its schema. This can be problematic for  maintenance and scalability of the database, refreshing staging/preprod from prod, as well as for understanding the data model.  Migration challenges: Moving or restructuring schemas becomes difficult.',
    'foreign key outside schema',
    ARRAY['consider rewrite your model', 'ask a dba']
),



(
    'TableWithFkMismatch', 'T007', 1, 1, 'TABLE',
    'table with fk mismatch, ex smallint refer to a bigint.',
    'Table with fk type mismatch.',
    ARRAY['consider rewrite your model', 'ask a dba']
),

(
    'TableWithRoleNotGranted', 'T008', 1, 1, 'TABLE',
    'Table has no roles grantee. Meaning that users will need direct access on it (not through a role).',
    'No role grantee on table. it means that except owner, users will need a direct grant on this table, not through a role. Prefer RBAC access if possible.',
    ARRAY[
        'create roles (myschema_ro & myschema_rw) and grant it on table with appropriate privileges'
    ]
),

(
    'ReservedKeyWord', 'T009', 10, 20, 'TABLE',
    'An object use reserved keywords.',
    'Reserved keywords in object.',
    ARRAY['Rename the object to use a non reserved keyword']
),

(
    'TableWithSensibleColumn', 'T010', 50, 80, 'TABLE',
    'Base on the extension anon (https://postgresql-anonymizer.readthedocs.io/en/stable/detection), show sensitive column.',
    '{0} have column {1} (category {2}) that can be consider has sensitive. It should be masked for non data-operator users.',
    ARRAY['Install extension anon, and create some masking rules on']
),
(
    'TableSharingSameTrigger', 'T015', 1, 1, 'TABLE',
    'Table shares the same trigger function with other tables.',
    'Table shares trigger function with other tables.',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
);

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
