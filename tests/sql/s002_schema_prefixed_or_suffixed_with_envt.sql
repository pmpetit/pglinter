-- Regression test for S002: SchemaPrefixedOrSuffixedWithEnvt
-- This test creates schemas with environment prefixes/suffixes and checks that S002 identifies them.

-- Setup: Create test role
CREATE ROLE s002_owner LOGIN;

-- Create schemas with environment prefixes/suffixes
CREATE SCHEMA prod_schema AUTHORIZATION s002_owner;
CREATE SCHEMA dev_schema AUTHORIZATION s002_owner;
CREATE SCHEMA s002_schema AUTHORIZATION s002_owner;

SELECT 'Testing S002 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S002') AS S002_only_enabled;
SELECT pglinter.perform_schema_check(); -- Should only run S002

-- Cleanup
DROP SCHEMA prod_schema CASCADE;
DROP SCHEMA dev_schema CASCADE;
DROP SCHEMA s002_schema CASCADE;
DROP ROLE s002_owner;
