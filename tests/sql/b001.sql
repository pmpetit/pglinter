-- Test for pg_linter B001 rule with file output
BEGIN;

CREATE TABLE IF NOT EXISTS my_table_without_pk (
    id INT,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    query TEXT,
    warning_level INT,
    error_level INT,
    scope TEXT
);

CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Test with file output
SELECT pg_linter.perform_base_check('/tmp/pg_linter_base_results.sarif');

-- Test if file exists
\! md5sum /tmp/pg_linter_base_results.sarif

-- Test with no output file (should output to prompt)
SELECT pg_linter.perform_base_check();

ROLLBACK;
