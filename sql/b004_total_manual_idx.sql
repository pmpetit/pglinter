SELECT
  COUNT(*) AS total_manual_indexes
FROM pg_stat_user_indexes AS psu
JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
WHERE
  pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
  AND pgi.indisunique = FALSE -- Excludes indexes created for a UNIQUE constraint
  AND psu.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
