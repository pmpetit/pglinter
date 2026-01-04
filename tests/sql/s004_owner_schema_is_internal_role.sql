-- Regression test for S004: OwnerSchemaIsInternalRole
-- This test creates a schema owned by a superuser and checks that S004 identifies it.

CREATE EXTENSION IF NOT EXISTS pglinter;

\pset pager off


-- Setup: Create test role and schema
CREATE ROLE s004_owner LOGIN;
CREATE SCHEMA s004_schema AUTHORIZATION postgres;

SELECT 'Testing S004 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S004') AS S004_only_enabled;
SELECT pglinter.check(); -- Should only run S004

-- Cleanup
DROP SCHEMA s004_schema CASCADE;
DROP ROLE s004_owner;

DROP EXTENSION pglinter CASCADE;
