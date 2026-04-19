-- Regression test for S002: SchemaPrefixedOrSuffixedWithEnvt
-- This test creates schemas with environment prefixes/suffixes and checks that S002 identifies them.

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Setup: Create test role
CREATE ROLE s002_owner LOGIN;

-- Create schemas with environment prefixes/suffixes
CREATE SCHEMA prod_schema AUTHORIZATION s002_owner;
CREATE SCHEMA dev_schema AUTHORIZATION s002_owner;
CREATE SCHEMA s002_schema AUTHORIZATION s002_owner;

SELECT 'Testing S002 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S002') AS s002_only_enabled;

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'S002';

SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'S002';

-- Cleanup
DROP SCHEMA prod_schema CASCADE;
DROP SCHEMA dev_schema CASCADE;
DROP SCHEMA s002_schema CASCADE;
DROP ROLE s002_owner;

DROP EXTENSION pglinter CASCADE;
