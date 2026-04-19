-- Regression test for S003 rule: Schemas with public CREATE privileges
-- Tests the percentage-based detection of schemas allowing CREATE for public role
-- versus total schemas in the database
CREATE EXTENSION pglinter;

SELECT
    'S003 Regression Test: Schemas with public CREATE privileges' AS test_header;

-- Setup S003 rule for testing
SELECT pglinter.disable_all_rules();
SELECT pglinter.enable_rule('S003');

-- PART 1: Test with LOW percentage of insecure schemas (should NOT trigger)
SELECT
    'PART 1: Testing with LOW percentage of insecure schemas (should NOT trigger)' AS test_part;

-- Create one secure schema (no public CREATE)
CREATE SCHEMA test_secure_schema;
REVOKE CREATE ON SCHEMA test_secure_schema FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_1;
REVOKE CREATE ON SCHEMA test_secure_schema_1 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_2;
REVOKE CREATE ON SCHEMA test_secure_schema_2 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_3;
REVOKE CREATE ON SCHEMA test_secure_schema_3 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_4;
REVOKE CREATE ON SCHEMA test_secure_schema_4 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_5;
REVOKE CREATE ON SCHEMA test_secure_schema_5 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_6;
REVOKE CREATE ON SCHEMA test_secure_schema_6 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_7;
REVOKE CREATE ON SCHEMA test_secure_schema_7 FROM public;

-- Create one secure schema
CREATE SCHEMA test_secure_schema_8;
REVOKE CREATE ON SCHEMA test_secure_schema_8 FROM public;


-- Create one insecure schema
CREATE SCHEMA test_insecure_schema_1;
GRANT CREATE ON SCHEMA test_insecure_schema_1 TO public;


-- Test S003 with low percentage (should not trigger with default thresholds)
SELECT
    'Running S003 check with LOW percentage of insecure schemas (should not trigger with default thresholds):' AS test_1;

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'S003';

CREATE SCHEMA test_insecure_schema_2;
GRANT CREATE ON SCHEMA test_insecure_schema_2 TO public;

-- Test S003 with high percentage (should trigger)
SELECT
    'Running S003 check with HIGH percentage of insecure schemas (should trigger):' AS test_2;

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'S003';
-- Test with file output
-- Test if file exists and show checksum


-- PART 3: Test S003 violations

SELECT 'Running S003 check:' AS test_3;

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

-- PART 6: Verification of SQL queries used by S003
SELECT 'PART 6: Direct verification of S003 SQL queries' AS sql_verification;

-- Test rule explanation
SELECT 'S003 rule explanation:' AS rule_explanation;
SELECT pglinter.explain_rule('S003');

DROP SCHEMA test_secure_schema CASCADE;
DROP SCHEMA test_secure_schema_1 CASCADE;
DROP SCHEMA test_secure_schema_2 CASCADE;
DROP SCHEMA test_secure_schema_3 CASCADE;
DROP SCHEMA test_secure_schema_4 CASCADE;
DROP SCHEMA test_secure_schema_5 CASCADE;
DROP SCHEMA test_secure_schema_6 CASCADE;
DROP SCHEMA test_secure_schema_7 CASCADE;
DROP SCHEMA test_secure_schema_8 CASCADE;
DROP SCHEMA test_insecure_schema_1 CASCADE;
DROP SCHEMA test_insecure_schema_2 CASCADE;

DROP EXTENSION pglinter CASCADE;
