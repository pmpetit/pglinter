-- Regression test for S005: SeveralTableOwnerInSchema
-- This test creates two tables in the same schema with different owners
-- and checks that the rule S005 correctly identifies the schema as problematic.

CREATE EXTENSION pglinter;

\pset pager off

-- Setup: Create test roles and schema
CREATE ROLE s005_owner1 LOGIN;
CREATE ROLE s005_owner2 LOGIN;
CREATE SCHEMA s005_schema AUTHORIZATION s005_owner1;

-- Create tables with different owners in the same schema
CREATE TABLE s005_schema.table1 (id INT);
ALTER TABLE s005_schema.table1 OWNER TO s005_owner1;
CREATE TABLE s005_schema.table2 (id INT);
ALTER TABLE s005_schema.table2 OWNER TO s005_owner2;

SELECT 'Testing S005 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S005') AS s005_only_enabled;

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'S005';

SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'S005';

-- Cleanup
DROP TABLE s005_schema.table1;
DROP TABLE s005_schema.table2;
DROP SCHEMA s005_schema;
DROP ROLE s005_owner1;
DROP ROLE s005_owner2;

DROP EXTENSION pglinter CASCADE;
