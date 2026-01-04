-- Regression test for S001: SchemaWithDefaultRoleNotGranted
-- This test creates a schema without a default role privilege and checks that S001 identifies it.

CREATE EXTENSION IF NOT EXISTS pglinter;

\pset pager off

-- Setup: Create test role and schema
CREATE ROLE s001_owner LOGIN;
CREATE SCHEMA s001_schema AUTHORIZATION s001_owner;

SELECT 'Testing S001 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S001') AS S001_only_enabled;
SELECT pglinter.check(); -- Should only run S001

SELECT count(*) AS violation_count from pglinter.get_violations() WHERE rule_code = 'S001';

-- Cleanup
DROP SCHEMA s001_schema CASCADE;
DROP ROLE s001_owner;

DROP EXTENSION pglinter CASCADE;
