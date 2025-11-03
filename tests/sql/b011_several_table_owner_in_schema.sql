-- Regression test for B011: SeveralTableOwnerInSchema
-- This test creates two tables in the same schema with different owners
-- and checks that the rule B011 correctly identifies the schema as problematic.

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

SELECT 'Testing B011 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('B011') AS B011_only_enabled;
SELECT pglinter.perform_base_check(); -- Should only run B011

-- Cleanup
DROP TABLE s005_schema.table1;
DROP TABLE s005_schema.table2;
DROP SCHEMA s005_schema;
DROP ROLE s005_owner1;
DROP ROLE s005_owner2;

DROP EXTENSION pglinter;
