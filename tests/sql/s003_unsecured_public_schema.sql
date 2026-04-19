-- Regression test for S003: UnsecuredPublicSchema
-- This test creates a schema and grants CREATE privilege to PUBLIC, then checks that S003 identifies it.

CREATE EXTENSION IF NOT EXISTS pglinter;

\pset pager off

-- Setup: Create test role and schema
CREATE ROLE s003_owner LOGIN;
CREATE SCHEMA s003_schema AUTHORIZATION s003_owner;

-- Grant CREATE privilege to PUBLIC
GRANT CREATE ON SCHEMA s003_schema TO public;

SELECT 'Testing S003 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S003') AS s003_only_enabled;

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'S003';

SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'S003';

-- Cleanup
REVOKE CREATE ON SCHEMA s003_schema FROM public;
DROP SCHEMA s003_schema CASCADE;
DROP ROLE s003_owner;

DROP EXTENSION pglinter CASCADE;
