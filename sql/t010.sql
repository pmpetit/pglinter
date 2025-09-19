SELECT
    schemaname::text,
    tablename::text,
    attname::text,
    identifiers_category::text
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
) AS detected
GROUP BY schemaname, tablename, attname, identifiers_category
