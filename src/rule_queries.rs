// Rule queries - q4 violation location queries for get_violations().

pub struct RuleQueries {
    pub q4: Option<&'static str>,
}

pub fn get_rule_queries(code: &str) -> RuleQueries {
    match code {
        "B001" => RuleQueries {
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
            q4: None,
        },
        "C002" => RuleQueries {
            q4: None,
        },
        "C003" => RuleQueries {
            q4: None,
        },
        "S001" => RuleQueries {
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
            q4: None,
        },
    }
}
