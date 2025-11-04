-- Regression test for S003: UnsecuredPublicSchema
-- This test creates a schema and grants CREATE privilege to PUBLIC, then checks that S003 identifies it.

CREATE EXTENSION IF NOT EXISTS pglinter;

\pset pager off

-- Setup: Create test role and schema
CREATE ROLE s003_owner LOGIN;
CREATE SCHEMA s003_schema AUTHORIZATION s003_owner;

-- Grant CREATE privilege to PUBLIC
GRANT CREATE ON SCHEMA s003_schema TO PUBLIC;

SELECT 'Testing S003 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('S003') AS S003_only_enabled;
SELECT pglinter.perform_schema_check(); -- Should only run S003

-- Cleanup
REVOKE CREATE ON SCHEMA s003_schema FROM PUBLIC;
DROP SCHEMA s003_schema CASCADE;
DROP ROLE s003_owner;
