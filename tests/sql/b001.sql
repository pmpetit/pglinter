-- Test for dblinter B001 rule with file output
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

CREATE EXTENSION IF NOT EXISTS dblinter;

-- Test with file output
SELECT dblinter.perform_base_check('/tmp/dblinter_base_results.sarif');

-- Test if file exists
\! md5sum /tmp/dblinter_base_results.sarif

-- Test with no output file (should output to prompt)  
SELECT dblinter.perform_base_check();

ROLLBACK;
