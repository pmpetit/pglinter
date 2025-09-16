SELECT
    n.nspname::TEXT AS schema_name,
    c.relname::TEXT AS table_name,
    pg_class.relname::TEXT AS redundant_index,
    useful_index_class.relname::TEXT AS redundant_with,
    regexp_replace(
        pg_get_indexdef(i.indexrelid), '.*\(|;.*', '', 'g'
    )::TEXT AS redundant_definition,
    regexp_replace(
        pg_get_indexdef(useful_i.indexrelid), '.*\(|;.*', '', 'g'
    )::TEXT AS redundant_with_definition
FROM
    pg_index AS i
INNER JOIN
    pg_class AS c ON i.indrelid = c.oid
INNER JOIN
    pg_class ON i.indexrelid = pg_class.oid
INNER JOIN
    pg_namespace AS n ON c.relnamespace = n.oid
INNER JOIN
    pg_index AS useful_i ON i.indrelid = useful_i.indrelid
INNER JOIN
    pg_class AS useful_index_class
    ON useful_i.indexrelid = useful_index_class.oid
WHERE
    i.indisprimary = FALSE
    AND
    useful_i.indisprimary = FALSE
    AND
    i.indisunique = FALSE
    AND
    useful_i.indisunique = FALSE
    AND
    i.indexrelid != useful_i.indexrelid
    AND
    n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
    AND
    i.indkey::TEXT LIKE useful_i.indkey::TEXT || '%'
ORDER BY
    c.relname, pg_class.relname;
