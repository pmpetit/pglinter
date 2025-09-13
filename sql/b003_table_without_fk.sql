SELECT
  COUNT(DISTINCT c.relname) AS tables_with_unindexed_foreign_keys
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_index i ON i.indrelid = c.oid AND con.conkey::smallint[] <@ i.indkey::smallint[]
WHERE
  con.contype = 'f'
  AND c.relkind = 'r'
  AND i.indexrelid IS NULL
  AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema', 'pglinter');
