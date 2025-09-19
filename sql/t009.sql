-- T010: This query detects reserved keywords used in database object names

WITH reserved_keywords AS (
    SELECT UNNEST(ARRAY[
        'ALL',
        'ANALYSE',
        'ANALYZE',
        'AND',
        'ANY',
        'ARRAY',
        'AS',
        'ASC',
        'ASYMMETRIC',
        'AUTHORIZATION',
        'BINARY',
        'BOTH',
        'CASE',
        'CAST',
        'CHECK',
        'COLLATE',
        'COLLATION',
        'COLUMN',
        'CONCURRENTLY',
        'CONSTRAINT',
        'CREATE',
        'CROSS',
        'CURRENT_CATALOG',
        'CURRENT_DATE',
        'CURRENT_ROLE',
        'CURRENT_SCHEMA',
        'CURRENT_TIME',
        'CURRENT_TIMESTAMP',
        'CURRENT_USER',
        'DEFAULT',
        'DEFERRABLE',
        'DESC',
        'DISTINCT',
        'DO',
        'ELSE',
        'END',
        'EXCEPT',
        'FALSE',
        'FETCH',
        'FOR',
        'FOREIGN',
        'FREEZE',
        'FROM',
        'FULL',
        'GRANT',
        'GROUP',
        'HAVING',
        'ILIKE',
        'IN',
        'INITIALLY',
        'INNER',
        'INTERSECT',
        'INTO',
        'IS',
        'ISNULL',
        'JOIN',
        'LATERAL',
        'LEADING',
        'LEFT',
        'LIKE',
        'LIMIT',
        'LOCALTIME',
        'LOCALTIMESTAMP',
        'NATURAL',
        'NOT',
        'NOTNULL',
        'NULL',
        'OFFSET',
        'ON',
        'ONLY',
        'OR',
        'ORDER',
        'OUTER',
        'OVERLAPS',
        'PLACING',
        'PRIMARY',
        'REFERENCES',
        'RETURNING',
        'RIGHT',
        'SELECT',
        'SESSION_USER',
        'SIMILAR',
        'SOME',
        'SYMMETRIC',
        'TABLE',
        'TABLESAMPLE',
        'THEN',
        'TO',
        'TRAILING',
        'TRUE',
        'UNION',
        'UNIQUE',
        'USER',
        'USING',
        'VARIADIC',
        'VERBOSE',
        'WHEN',
        'WHERE',
        'WINDOW', 'WITH'
    ]) AS keyword
)

-- Check tables using reserved keywords
SELECT
    table_schema::text,
    table_name::text,
    'table' AS object_type
FROM information_schema.tables
WHERE
    table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(table_name) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check columns using reserved keywords
SELECT
    table_schema,
    table_name,
    'column:' || column_name AS object_type
FROM information_schema.columns
WHERE
    table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(column_name) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check views using reserved keywords
SELECT
    table_schema::text,
    table_name::text,
    'view' AS object_type
FROM information_schema.views
WHERE
    table_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(table_name) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check functions/procedures using reserved keywords
SELECT
    routine_schema::text,
    routine_name::text,
    'function' AS object_type
FROM information_schema.routines
WHERE
    routine_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(routine_name) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check indexes using reserved keywords
SELECT
    schemaname::text,
    indexname::text,
    'index' AS object_type
FROM pg_indexes
WHERE
    schemaname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(indexname) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check sequences using reserved keywords
SELECT
    sequence_schema::text,
    sequence_name::text,
    'sequence' AS object_type
FROM information_schema.sequences
WHERE
    sequence_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(sequence_name) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check user-defined types using reserved keywords
SELECT
    n.nspname::text,
    t.typname::text,
    'type' AS object_type
FROM pg_type AS t
INNER JOIN pg_namespace AS n ON t.typnamespace = n.oid
WHERE
    n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND t.typtype IN ('c', 'e', 'd')  -- composite, enum, domain types
    AND UPPER(t.typname) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check triggers using reserved keywords
SELECT
    n.nspname::text,
    t.tgname::text,
    'trigger' AS object_type
FROM pg_trigger AS t
INNER JOIN pg_class AS c ON t.tgrelid = c.oid
INNER JOIN pg_namespace AS n ON c.relnamespace = n.oid
WHERE
    n.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND NOT t.tgisinternal
    AND UPPER(t.tgname) IN (SELECT keyword FROM reserved_keywords)

UNION

-- Check constraints using reserved keywords
SELECT
    constraint_schema::text,
    constraint_name::text,
    'constraint' AS object_type
FROM information_schema.table_constraints
WHERE
    constraint_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    AND UPPER(constraint_name) IN (SELECT keyword FROM reserved_keywords)
