// Rule queries - moved from sql/rules.sql
// Each rule has q1 (total count or direct query), optionally q2 (violation count),
// q3 (dataset listing), and q4 (violation locations for get_violations).

pub struct RuleQueries {
    pub q1: Option<&'static str>,
    pub q2: Option<&'static str>,
    pub q3: Option<&'static str>,
    pub q4: Option<&'static str>,
}

pub fn get_rule_queries(code: &str) -> RuleQueries {
    match code {
        "B001" => RuleQueries {
            q1: Some(
                r##"SELECT count(*)::BIGINT AS total_tables
FROM pg_catalog.pg_tables
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT
count(1)::BIGINT AS tables_without_primary_key
FROM
    pg_class c
JOIN
    pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN
    pg_index i ON i.indrelid = c.oid AND i.indisprimary
WHERE
    n.nspname NOT IN ('pg_catalog', 'information_schema', 'gp_toolkit','_timescaledb', 'timescaledb') -- Exclude system schemas
    AND c.relkind = 'r' -- Only include regular tables
    AND i.indrelid IS NULL"##,
            ),
            q3: Some(
                r##"SELECT pt.schemaname::text,pt.tablename::text
FROM pg_tables AS pt
WHERE
    pt.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
ORDER BY 1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for tables without a primary key
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
    )"##,
            ),
        },
        "B002" => RuleQueries {
            q1: Some(
                r##"SELECT COUNT(*) AS total_indexes
FROM pg_indexes
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*) AS redundant_indexes
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
                    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
                )
        )
) redundant"##,
            ),
            q3: Some(
                r##"WITH index_info AS (
    -- This CTE gets the column info, plus the boolean flag for Primary Key (indisprimary).
    SELECT
        ind.indrelid AS table_oid,
        ind.indexrelid AS index_oid,
        att.attname AS column_name,
        array_position(ind.indkey, att.attnum) AS column_order,
        ind.indisprimary -- Added Primary Key flag
    FROM pg_index ind
    JOIN pg_attribute att ON att.attrelid = ind.indrelid AND att.attnum = ANY(ind.indkey)
    WHERE NOT ind.indisexclusion
),
indexed_columns AS (
    -- Aggregates columns for each index and propagates PK flag.
    SELECT
        table_oid,
        index_oid,
        string_agg(column_name, ',' ORDER BY column_order) AS indexed_columns_string,
        MAX(indisprimary::int)::bool AS is_primary_key
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
    pg_namespace.nspname::TEXT AS schema_name,
    table_info.tablename::TEXT AS table_name,
    redundant_index.relname::TEXT ||'('|| i1.indexed_columns_string || ') is redundant with '|| superset_index.relname||'('|| i2.indexed_columns_string ||')' AS problematic_object
FROM indexed_columns AS i1 -- The smaller/redundant index
JOIN indexed_columns AS i2 ON i1.table_oid = i2.table_oid -- The larger/superset index
JOIN pg_class redundant_index ON i1.index_oid = redundant_index.oid
JOIN pg_class superset_index ON i2.index_oid = superset_index.oid
JOIN table_info ON i1.table_oid = table_info.table_oid
JOIN pg_namespace ON table_info.relnamespace = pg_namespace.oid
WHERE
    pg_namespace.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND i1.index_oid <> i2.index_oid -- Ensure the indexes are not the same
    -- Checks if the smaller index's column string is a prefix of the larger index's string.
    AND i2.indexed_columns_string LIKE i1.indexed_columns_string || '%'

ORDER BY 1, 2"##,
            ),
            q4: Some(
                r##"WITH index_info AS (
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
    AND i2.indexed_columns_string LIKE i1.indexed_columns_string || '%'"##,
            ),
        },
        "B003" => RuleQueries {
            q1: Some(
                r##"SELECT count(DISTINCT tc.table_name)::BIGINT AS total_tables
FROM
    information_schema.table_constraints AS tc
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT COUNT(DISTINCT c.relname)::INT AS tables_with_unindexed_foreign_keys
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
    AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')"##,
            ),
            q3: Some(
                r##"SELECT DISTINCT
    tc.table_schema::text,
    tc.table_name::text,
    tc.constraint_name::text AS problematic_object
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON
        tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )
    AND NOT EXISTS (
        SELECT 1 FROM pg_indexes AS pi
        WHERE
            pi.schemaname = tc.table_schema
            AND pi.tablename = tc.table_name
            AND pi.indexdef LIKE '%' || kcu.column_name || '%'
    )
ORDER BY 1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for foreign key constraints lacking an index
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
    AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema', 'pglinter','_timescaledb', 'timescaledb')"##,
            ),
        },
        "B004" => RuleQueries {
            q1: Some(
                r##"SELECT COUNT(*) AS total_manual_indexes
FROM pg_stat_user_indexes AS psu
JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
WHERE
    pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
    -- Excludes indexes created for a UNIQUE constraint
    AND pgi.indisunique = FALSE
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*) AS unused_manual_indexes
FROM pg_stat_user_indexes AS psu
JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
WHERE
    psu.idx_scan = 0
    AND pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
    -- Excludes indexes created for a UNIQUE constraint
    AND pgi.indisunique = FALSE
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )"##,
            ),
            q3: Some(
                r##"SELECT
    schemaname::text,
    relname::text || 'has' ||
    LEAST(
        ROUND(
            (
                seq_tup_read::numeric
                / NULLIF((seq_tup_read + idx_tup_fetch)::numeric, 0)
            ) * 100, 0
        ),
        100
    )::text ||' % of seq scan.' AS problematic_object
FROM pg_stat_user_tables
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )
ORDER BY 1, 2"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for unused manual indexes
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
    )"##,
            ),
        },
        "B005" => RuleQueries {
            q1: Some(
                r##"SELECT COUNT(*) AS total_objects
FROM (
    -- All tables
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.tables
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
) all_objects"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*) AS uppercase_objects
FROM (
    -- Tables with uppercase names
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.tables
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND schema_name != LOWER(schema_name)
) uppercase_objects"##,
            ),
            q3: Some(
                r##"SELECT
    object_type::TEXT ||' '||schema_name::TEXT,
    object_name::TEXT AS problematic_object
FROM (
    -- Tables with uppercase names
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.tables
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND table_name != LOWER(table_name)

    UNION ALL

    -- Columns with uppercase names
    SELECT
        'column' AS object_type,
        table_schema AS schema_name,
        table_name || '.' || column_name AS object_name
    FROM information_schema.columns
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND column_name != LOWER(column_name)

    UNION ALL

    -- Indexes with uppercase names
    SELECT
        'index' AS object_type,
        schemaname AS schema_name,
        indexname AS object_name
    FROM pg_indexes
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND indexname != LOWER(indexname)

    UNION ALL

    -- Sequences with uppercase names
    SELECT
        'sequence' AS object_type,
        sequence_schema AS schema_name,
        sequence_name AS object_name
    FROM information_schema.sequences
    WHERE
        sequence_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND sequence_name != LOWER(sequence_name)

    UNION ALL

    -- Views with uppercase names
    SELECT
        'view' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name
    FROM information_schema.views
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND table_name != LOWER(table_name)

    UNION ALL

    -- Functions with uppercase names
    SELECT
        'function' AS object_type,
        routine_schema AS schema_name,
        routine_name AS object_name
    FROM information_schema.routines
    WHERE
        routine_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND routine_type = 'FUNCTION'
        AND routine_name != LOWER(routine_name)

    UNION ALL

    -- Triggers with uppercase names
    SELECT
        'trigger' AS object_type,
        trigger_schema AS schema_name,
        trigger_name AS object_name
    FROM information_schema.triggers
    WHERE
        trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND trigger_name != LOWER(trigger_name)

    UNION ALL

    -- Schemas with uppercase names
    SELECT
        'schema' AS object_type,
        schema_name AS schema_name,
        schema_name AS object_name
    FROM information_schema.schemata
    WHERE
        schema_name NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
        )
        AND schema_name != LOWER(schema_name)
) AS uppercase_objects
ORDER BY
    object_type,
    schema_name,
    object_name"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for objects with uppercase in their name
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
  AND n.nspname != LOWER(n.nspname)"##,
            ),
        },
        "B006" => RuleQueries {
            q1: Some(
                r##"SELECT count(*)::BIGINT
FROM pg_catalog.pg_tables pt
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*) AS unselected_tables
FROM pg_stat_user_tables AS psu
WHERE
    (psu.idx_scan = 0 OR psu.idx_scan IS NULL)
    AND (psu.seq_scan = 0 OR psu.seq_scan IS NULL)
    AND n_tup_ins > 0
    AND (n_tup_upd = 0 OR n_tup_upd IS NULL)
    AND (n_tup_del = 0 OR n_tup_del IS NULL)
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q3: Some(
                r##"SELECT psu.schemaname::text, psu.relname::text
FROM pg_stat_user_tables AS psu
WHERE
    (psu.idx_scan = 0 OR psu.idx_scan IS NULL)
    AND (psu.seq_scan = 0 OR psu.seq_scan IS NULL)
    AND n_tup_ins > 0
    AND (n_tup_upd = 0 OR n_tup_upd IS NULL)
    AND (n_tup_del = 0 OR n_tup_del IS NULL)
    AND psu.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q4: Some(
                r##"SELECT
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
    )"##,
            ),
        },
        "B007" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(DISTINCT conrelid::regclass) AS tables_with_foreign_keys
FROM
    pg_constraint c
JOIN
    pg_class r ON r.oid = c.conrelid
JOIN
    pg_namespace n ON n.oid = r.relnamespace
WHERE
    c.contype = 'f' -- Filter for Foreign Key constraints
    AND n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT
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
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q3: Some(
                r##"SELECT
    tc.table_schema::TEXT,tc.table_name::TEXT,
    'has foreign key '||tc.constraint_name::TEXT||' referencing '||
    ccu.table_schema::TEXT||'.'||ccu.table_name::TEXT AS problematic_object
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema != ccu.table_schema
    AND tc.table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q4: Some(
                r##"SELECT
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
    )"##,
            ),
        },
        "B008" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(DISTINCT conrelid::regclass) AS tables_with_foreign_keys
FROM
    pg_constraint c
JOIN
    pg_class r ON r.oid = c.conrelid
JOIN
    pg_namespace n ON n.oid = r.relnamespace
WHERE
    c.contype = 'f' -- Filter for Foreign Key constraints
    AND n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"SELECT
    count(1)::BIGINT AS fk_type_mismatches
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
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND col1.data_type != col2.data_type"##,
            ),
            q3: Some(
                r##"SELECT
    tc.table_schema::text || '.'
    || tc.table_name::text || ' constraint '
    || tc.constraint_name::text || ' column '
    || kcu.column_name::text || ' type is '
    || col1.data_type::text || ' but '
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
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND col1.data_type != col2.data_type"##,
            ),
            q4: Some(
                r##"SELECT
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
    AND col1.data_type != col2.data_type"##,
            ),
        },
        "B009" => RuleQueries {
            q1: Some(
                r##"SELECT
    COALESCE(COUNT(DISTINCT event_object_table), 0)::BIGINT as table_using_trigger
FROM
    information_schema.triggers t
WHERE
    t.trigger_schema NOT IN (
    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
)"##,
            ),
            q2: Some(
                r##"SELECT
    COALESCE(SUM(shared_table_count), 0)::BIGINT AS table_using_same_trigger
FROM (
    SELECT
        COUNT(DISTINCT t.event_object_table) AS shared_table_count
    FROM (
        SELECT
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
    GROUP BY
        t.trigger_function_name
    HAVING
        COUNT(DISTINCT t.event_object_table) > 1
) shared_triggers"##,
            ),
            q3: Some(
                r##"WITH SharedFunctions AS (
    -- 1. Identify all trigger functions that are used by more than one table
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
    t.event_object_table::TEXT AS table_name,
    t.trigger_name::TEXT || ' uses the same trigger function ' ||
    t.trigger_schema::TEXT,
    s.trigger_function_name::TEXT
FROM
    information_schema.triggers t
JOIN
    SharedFunctions s ON s.trigger_function_name = SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)')
WHERE
    t.trigger_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
ORDER BY
    s.trigger_function_name,
    t.trigger_schema,
    t.event_object_table"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for tables using the same trigger function (B009)
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
    )"##,
            ),
        },
        "B010" => RuleQueries {
            q1: Some(
                r##"SELECT count(*)::BIGINT AS total_tables
FROM pg_catalog.pg_tables
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter','_timescaledb', 'timescaledb'
    )"##,
            ),
            q2: Some(
                r##"WITH reserved_keywords AS (
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
    COUNT(1) AS total_reserved_keyword_objects
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
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
        AND UPPER(table_name) = keyword

    UNION ALL -- Use UNION ALL for counting to avoid redundant DISTINCT check

    -- Columns using reserved keywords
    SELECT
        'column' AS object_type,
        table_schema AS schema_name,
        table_name || '.' || column_name AS object_name
    FROM information_schema.columns
    CROSS JOIN reserved_keywords
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
        AND UPPER(column_name) = keyword

    UNION ALL

    -- Indexes using reserved keywords
    SELECT
        'index' AS object_type,
        schemaname AS schema_name,
        indexname AS object_name
    FROM pg_indexes
    CROSS JOIN reserved_keywords
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
        AND UPPER(indexname) = keyword
) reserved_objects"##,
            ),
            q3: Some(
                r##"WITH reserved_keywords AS (
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
    object_type || ' in ' ||
    schema_name,
    object_name || ' is a reserved keyword: ' ||
    keyword AS reserved_keyword_match
FROM (
    -- Tables using reserved keywords
    SELECT
        'table' AS object_type,
        table_schema AS schema_name,
        table_name AS object_name,
        keyword
    FROM information_schema.tables
    CROSS JOIN reserved_keywords
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
        AND UPPER(table_name) = keyword

    UNION ALL

    -- Columns using reserved keywords
    SELECT
        'column' AS object_type,
        table_schema AS schema_name,
        table_name || '.' || column_name AS object_name,
        keyword
    FROM information_schema.columns
    CROSS JOIN reserved_keywords
    WHERE
        table_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
        AND UPPER(column_name) = keyword

    UNION ALL

    -- Indexes using reserved keywords
    SELECT
        'index' AS object_type,
        schemaname AS schema_name,
        indexname AS object_name,
        keyword
    FROM pg_indexes
    CROSS JOIN reserved_keywords
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
        AND UPPER(indexname) = keyword
) AS reserved_objects
ORDER BY
    object_type,
    schema_name,
    object_name"##,
            ),
            q4: Some(
                r##"WITH reserved_keywords AS (
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
SELECT * FROM obj_trigger"##,
            ),
        },
        "B011" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(*)::BIGINT AS total_schema_count
FROM
    pg_namespace n
WHERE
    n.nspname NOT IN ( 'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')"##,
            ),
            q2: Some(
                r##"WITH C1 AS (
SELECT coalesce(count(DISTINCT tableowner)::BIGINT, 0) AS diff_owners
FROM pg_tables
WHERE
    schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
GROUP BY schemaname)
SELECT COUNT(1) from C1 where diff_owners > 1"##,
            ),
            q3: Some(
                r##"WITH SchemaOwnerTable AS (
    -- Step 1: Find all distinct combinations of (schemaname, tableowner)
    SELECT DISTINCT
        schemaname::TEXT AS schemaname,
        tableowner::TEXT AS tableowner
    FROM
        pg_tables
    WHERE
        schemaname NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
        )
),
OwnerCounts AS (
    -- Step 2: Count the number of distinct owners for each schema
    SELECT
        schemaname,
        COUNT(tableowner) AS distinct_owner_count
    FROM
        SchemaOwnerTable
    GROUP BY
        schemaname
    HAVING
        -- Only keep schemas that have more than one distinct owner
        COUNT(tableowner) > 1
)
SELECT
    t.schemaname::TEXT,
    t.tablename || ' owner is ' || t.tableowner::TEXT AS table_and_owner
FROM
    pg_tables t
JOIN
    OwnerCounts oc ON t.schemaname = oc.schemaname
WHERE
    t.schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
ORDER BY
    1, 2"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for tables in schemas with multiple owners (B011)
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
    )"##,
            ),
        },
        "B012" => RuleQueries {
            q1: Some(
                r##"SELECT COUNT(*)::BIGINT AS total_composite_pk_tables
FROM (
    SELECT tc.table_schema, tc.table_name, COUNT(kcu.column_name) AS pk_col_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
) sub"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*)::BIGINT AS total_composite_pk_tables
FROM (
    SELECT tc.table_schema, tc.table_name, COUNT(kcu.column_name) AS pk_col_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
    HAVING COUNT(kcu.column_name) > 4
) sub"##,
            ),
            q3: Some(
                r##"SELECT
    sub.table_schema || '.' || sub.table_name ||'('||string_agg(sub.column_name, ', ')||')' AS pk_columns
FROM (
    SELECT
        tc.table_schema,
        tc.table_name,
        kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
) sub
GROUP BY sub.table_schema, sub.table_name
HAVING COUNT(sub.column_name) > 4"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for tables with composite primary keys involving more than 4 columns (B012)
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
  AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = sub.table_schema)"##,
            ),
        },
        "B013" => RuleQueries {
            q1: Some(
                r##"SELECT
    COALESCE(COUNT(DISTINCT event_object_table), 0)::BIGINT as table_using_trigger
FROM
    information_schema.triggers t
WHERE
    t.trigger_schema NOT IN (
    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
)"##,
            ),
            q2: Some(
                r##"SELECT
    COUNT(DISTINCT c.oid)::BIGINT AS tables_with_unbounded_cursor_trigger
FROM pg_trigger tg
JOIN pg_class     c  ON c.oid = tg.tgrelid
JOIN pg_namespace n  ON n.oid = c.relnamespace
JOIN pg_proc      p  ON p.oid = tg.tgfoid
WHERE
    NOT tg.tgisinternal
    AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
    AND n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    -- function body has a cursor/FOR-loop SELECT ...
    AND p.prosrc ~* '(?:CURSOR\s+FOR|OPEN\s+\w[\w$]*\s+FOR|FOR\s+\w[\w$]*\s+IN)\s+SELECT'
    -- at least one of those SELECT blocks has no WHERE clause
    AND EXISTS (
        SELECT 1
        FROM regexp_matches(
            p.prosrc,
            '(?:CURSOR\s+FOR|OPEN\s+\w[\w$]*\s+FOR|FOR\s+\w[\w$]*\s+IN)\s+(SELECT\s[^;]+?)(?:;|\mLOOP\M)',
            'gix'
        ) AS m(cursor_select)
        WHERE m.cursor_select[1] !~* '\mWHERE\M'
    )"##,
            ),
            q3: Some(
                r##"SELECT
    n.nspname::TEXT                          AS schema_name,
    c.relname::TEXT                          AS table_name,
    tg.tgname::TEXT || ' -> ' ||
    pn.nspname::TEXT || '.' ||
    p.proname::TEXT                          AS trigger_and_function
FROM pg_trigger    tg
JOIN pg_class      c   ON c.oid  = tg.tgrelid
JOIN pg_namespace  n   ON n.oid  = c.relnamespace
JOIN pg_proc       p   ON p.oid  = tg.tgfoid
JOIN pg_namespace  pn  ON pn.oid = p.pronamespace
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
    )
ORDER BY n.nspname, c.relname, tg.tgname"##,
            ),
            q4: Some(
                r##"SELECT
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
    )"##,
            ),
        },
        "C001" => RuleQueries {
            q1: Some(
                r##"SELECT
    current_setting('max_connections')::int AS max_connections,
    current_setting('work_mem') AS work_mem_setting"##,
            ),
            q2: None,
            q3: None,
            q4: None,
        },
        "C002" => RuleQueries {
            q1: Some(r##"SELECT count(*)::BIGINT FROM pg_catalog.pg_hba_file_rules"##),
            q2: Some(
                r##"SELECT count(*)::BIGINT
FROM pg_catalog.pg_hba_file_rules
WHERE auth_method IN ('trust', 'password')"##,
            ),
            q3: None,
            q4: None,
        },
        "C003" => RuleQueries {
            q1: Some(
                r##"SELECT 'password_encryption is ' || setting FROM
pg_catalog.pg_settings
WHERE name='password_encryption' AND setting='md5'"##,
            ),
            q2: None,
            q3: None,
            q4: None,
        },
        "S001" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(*) AS total_schema_count
FROM
    pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'"##,
            ),
            q2: Some(
                r##"SELECT count(DISTINCT n.nspname::text)::BIGINT AS nb_schema
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
    )
ORDER BY 1"##,
            ),
            q3: Some(
                r##"SELECT DISTINCT n.nspname::text AS schema_name
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
    )
ORDER BY 1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for schemas with no default role (S001)
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
    )"##,
            ),
        },
        "S002" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(*)::BIGINT AS total_schema_count
FROM
    pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'"##,
            ),
            q2: Some(
                r##"SELECT count(n.nspname::text)::BIGINT AS nb_schema_name
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'
    AND (
        n.nspname ILIKE 'staging_%' OR n.nspname ILIKE '%_staging'
        OR n.nspname ILIKE 'stg_%' OR n.nspname ILIKE '%_stg'
        OR n.nspname ILIKE 'preprod_%' OR n.nspname ILIKE '%_preprod'
        OR n.nspname ILIKE 'prod_%' OR n.nspname ILIKE '%_prod'
        OR n.nspname ILIKE 'production_%' OR n.nspname ILIKE '%_production'
        OR n.nspname ILIKE 'dev_%' OR n.nspname ILIKE '%_dev'
        OR n.nspname ILIKE 'development_%' OR n.nspname ILIKE '%_development'
        OR n.nspname ILIKE 'sandbox_%' OR n.nspname ILIKE '%_sandbox'
        OR n.nspname ILIKE 'sbox_%' OR n.nspname ILIKE '%_sbox'
    )"##,
            ),
            q3: Some(
                r##"SELECT n.nspname::text AS nb_schema_name
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'
    AND (
        n.nspname ILIKE 'staging_%' OR n.nspname ILIKE '%_staging'
        OR n.nspname ILIKE 'stg_%' OR n.nspname ILIKE '%_stg'
        OR n.nspname ILIKE 'preprod_%' OR n.nspname ILIKE '%_preprod'
        OR n.nspname ILIKE 'prod_%' OR n.nspname ILIKE '%_prod'
        OR n.nspname ILIKE 'production_%' OR n.nspname ILIKE '%_production'
        OR n.nspname ILIKE 'dev_%' OR n.nspname ILIKE '%_dev'
        OR n.nspname ILIKE 'development_%' OR n.nspname ILIKE '%_development'
        OR n.nspname ILIKE 'sandbox_%' OR n.nspname ILIKE '%_sandbox'
        OR n.nspname ILIKE 'sbox_%' OR n.nspname ILIKE '%_sbox'
    )
ORDER BY 1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for schemas with environment prefixes/suffixes (S002)
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
    )"##,
            ),
        },
        "S003" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(*)::BIGINT AS total_schema_count
FROM
    pg_namespace n
WHERE
    n.nspname NOT IN ( 'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*) AS total_schemas
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND HAS_SCHEMA_PRIVILEGE('public', n.nspname, 'CREATE')"##,
            ),
            q3: Some(
                r##"SELECT n.nspname::text AS schemas
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND HAS_SCHEMA_PRIVILEGE('public', n.nspname, 'CREATE')
ORDER BY 1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for schemas where PUBLIC has CREATE privilege (S003)
SELECT
    'pg_namespace'::regclass::oid AS classid,
    n.oid AS objid,
    0 AS objsubid
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND HAS_SCHEMA_PRIVILEGE('public', n.nspname, 'CREATE')"##,
            ),
        },
        "S004" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(*)::BIGINT AS total_schema_count
FROM
    pg_namespace n
WHERE
    n.nspname NOT IN ( 'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'"##,
            ),
            q2: Some(
                r##"SELECT COUNT(*)::BIGINT AS total_schemas
FROM pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND HAS_SCHEMA_PRIVILEGE('public', n.nspname, 'CREATE')"##,
            ),
            q3: Some(
                r##"SELECT
    r.rolname::TEXT || ' is the owner of the schema ' || n.nspname::TEXT AS owner_info
FROM
    pg_namespace n
JOIN
    pg_roles r ON n.nspowner = r.oid
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND (
        r.rolsuper IS TRUE -- Owned by a Superuser (e.g., 'postgres')
        OR r.rolname LIKE 'pg_%' -- Owned by a reserved PostgreSQL system role
        OR r.rolname = 'postgres' -- Explicitly include the default administrative account
    )
ORDER BY
    1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for schemas owned by internal roles or superuser (S004)
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
    )"##,
            ),
        },
        "S005" => RuleQueries {
            q1: Some(
                r##"SELECT
    COUNT(*)::BIGINT AS total_schema_count
FROM
    pg_namespace n
WHERE
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb')
    AND n.nspname NOT LIKE 'pg_%'"##,
            ),
            q2: Some(
                r##"SELECT
    COUNT(DISTINCT n.nspname) AS schemas_with_mixed_ownership
FROM
    pg_namespace n
JOIN
    pg_class c ON c.relnamespace = n.oid -- Link schema to its relations (tables)
WHERE
    n.nspname NOT IN ( -- Exclude system/technical schemas
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND n.nspname NOT LIKE 'pg_temp%' -- Exclude temp schemas
    AND c.relkind = 'r'               -- Only count regular tables ('r')
    AND n.nspowner <> c.relowner      -- Schema owner does NOT equal Table owner"##,
            ),
            q3: Some(
                r##"SELECT
    'Owner of schema ' || n.nspname::TEXT || ' is ' || r_schema.rolname::TEXT ||' but owner of table '||n.nspname::TEXT ||'.'|| c.relname::TEXT || ' is ' || r_table.rolname::TEXT AS ownership_info
FROM
    pg_namespace n
JOIN
    pg_class c ON c.relnamespace = n.oid -- Link schema to its relations (tables)
JOIN
    pg_roles r_schema ON n.nspowner = r_schema.oid -- Get schema owner name
JOIN
    pg_roles r_table ON c.relowner = r_table.oid    -- Get table owner name
WHERE
    n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter', '_timescaledb', 'timescaledb'
    )
    AND n.nspname NOT LIKE 'pg_temp%'
    AND c.relkind = 'r'               -- Only count regular tables
    AND n.nspowner <> c.relowner      -- The core condition: Owners are different
ORDER BY 1"##,
            ),
            q4: Some(
                r##"-- Returns classid, objid, objsubid for tables where the schema owner and table owner differ (S005)
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
    AND n.nspowner <> c.relowner      -- Schema owner does NOT equal Table owner"##,
            ),
        },
        _ => RuleQueries {
            q1: None,
            q2: None,
            q3: None,
            q4: None,
        },
    }
}
