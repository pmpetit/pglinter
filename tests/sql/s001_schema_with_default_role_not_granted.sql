-- Regression test for S001: SchemaWithDefaultRoleNotGranted
-- This test creates a schema without a default role privilege and checks that S001 identifies it.

CREATE EXTENSION IF NOT EXISTS pglinter;

\pset pager off

-- Setup: Create test role and schema
CREATE ROLE s001_owner LOGIN;
CREATE SCHEMA s001_schema AUTHORIZATION s001_owner;

SELECT 'Testing S001 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S001') AS s001_only_enabled;

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'S001';

SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'S001';

-- Cleanup
DROP SCHEMA s001_schema CASCADE;
DROP ROLE s001_owner;

DROP EXTENSION pglinter CASCADE;
