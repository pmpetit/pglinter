WITH index_info AS (
    -- This CTE gets the name and order of all columns for each index.
    SELECT
        ind.indrelid AS table_oid,
        ind.indexrelid AS index_oid,
        att.attname AS column_name,
        array_position(ind.indkey, att.attnum) AS column_order
    FROM pg_index AS ind
    INNER JOIN
        pg_attribute AS att
        ON ind.indrelid = att.attrelid AND att.attnum = any(ind.indkey)
    WHERE ind.indisprimary = FALSE AND NOT ind.indisexclusion
),

indexed_columns AS (
    -- This CTE aggregates the columns for each index into an ordered string.
    SELECT
        table_oid,
        index_oid,
        string_agg(
            column_name, ','
            ORDER BY column_order
        ) AS indexed_columns_string
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
    -- Selects the redundant index and the index it is a subset of.
    redundant_index.relname::TEXT AS redundant_index,
    superset_index.relname::TEXT AS superset_index,
    -- Provides the schema and table names.
    pg_namespace.nspname::TEXT AS schema_name,
    table_info.tablename::TEXT
FROM indexed_columns AS i1
INNER JOIN indexed_columns AS i2 ON i1.table_oid = i2.table_oid
INNER JOIN pg_class AS redundant_index ON i1.index_oid = redundant_index.oid
INNER JOIN pg_class AS superset_index ON i2.index_oid = superset_index.oid
INNER JOIN table_info ON i1.table_oid = table_info.table_oid
INNER JOIN pg_namespace ON table_info.relnamespace = pg_namespace.oid
WHERE
    pg_namespace.nspname NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
    -- Ensure the indexes are not the same
    AND redundant_index.oid <> superset_index.oid
    -- Checks if the smaller index's column string is a prefix of the larger index's string.
    AND i2.indexed_columns_string LIKE i1.indexed_columns_string || '%'
ORDER BY
    table_info.tablename,
    redundant_index;
