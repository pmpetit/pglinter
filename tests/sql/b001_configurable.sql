-- Quick test to verify B001 rule detects tables without primary key
DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION pglinter;

\pset pager off

-- Create a table without primary key
CREATE TABLE test_no_pk (
    id INTEGER,
    name TEXT
);

-- Create a table with a primary key
CREATE TABLE test_with_pk (
    id INTEGER PRIMARY KEY,
    name TEXT
);

-- First, disable all rules to isolate B001 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B001 for focused testing
SELECT pglinter.enable_rule('B001') AS b001_enabled;

-- B001 should detect the table without primary key
SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'B001';

SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'B001';

DROP TABLE test_no_pk CASCADE;
DROP TABLE test_with_pk CASCADE;

DROP EXTENSION pglinter CASCADE;
