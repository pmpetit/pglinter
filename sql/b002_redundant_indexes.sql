SELECT COUNT(*) as redundant_indexes
FROM (
    SELECT DISTINCT i1.indexrelid
    FROM pg_index i1, pg_index i2
    WHERE i1.indrelid = i2.indrelid
    AND i1.indexrelid != i2.indexrelid
    AND i1.indkey = i2.indkey
    AND EXISTS (
        SELECT 1 FROM pg_indexes pi1
        WHERE pi1.indexname = (SELECT relname FROM pg_class WHERE oid = i1.indexrelid)
        AND pi1.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    )
) redundant
