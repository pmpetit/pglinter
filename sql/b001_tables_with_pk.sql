SELECT count(distinct(pg_class.relname))
FROM pg_index, pg_class, pg_attribute, pg_namespace
WHERE indrelid = pg_class.oid AND
nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter') AND
pg_class.relnamespace = pg_namespace.oid AND
pg_attribute.attrelid = pg_class.oid AND
pg_attribute.attnum = any(pg_index.indkey)
AND indisprimary
