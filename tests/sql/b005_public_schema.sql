-- Regression test for B005 rule: Schemas with public CREATE privileges
-- Tests the percentage-based detection of schemas allowing CREATE for public role
-- versus total schemas in the database

BEGIN;

-- Create the extension
DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

SELECT 'B005 Regression Test: Schemas with public CREATE privileges' AS test_header;

-- Setup B005 rule for testing
SELECT pglinter.disable_all_rules();
SELECT pglinter.enable_rule('B005');

-- PART 1: Test with LOW percentage of insecure schemas (should NOT trigger)
SELECT 'PART 1: Testing with LOW percentage of insecure schemas (should NOT trigger)' AS test_part;

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


-- Test B005 with low percentage (should not trigger with default thresholds)
SELECT 'Running B005 check with LOW percentage of insecure schemas (should not trigger with default thresholds):' AS test_1;
SELECT pglinter.perform_base_check();

CREATE SCHEMA test_insecure_schema_2;
GRANT CREATE ON SCHEMA test_insecure_schema_2 TO public;

-- Test B005 with high percentage (should trigger)
SELECT 'Running B005 check with HIGH percentage of insecure schemas (should trigger):' AS test_2;
SELECT pglinter.perform_base_check();
-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_b005_results.sarif');
-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_b005_results.sarif


-- PART 3: Test threshold adjustment
SELECT 'PART 3: Testing B005 threshold adjustments (should not trigger)' AS test_part;

-- Lower the warning threshold to ensure detection
SELECT pglinter.update_rule_levels('B005', 50, 80);

SELECT 'B005 thresholds updated to warning=50%, error=80%' AS threshold_info;

-- Test with adjusted thresholds
SELECT 'Running B005 check with adjusted thresholds (warning=50%):' AS test_3;
SELECT pglinter.perform_base_check();

-- PART 6: Verification of SQL queries used by B005
SELECT 'PART 6: Direct verification of B005 SQL queries' AS sql_verification;

-- Test rule explanation
SELECT 'B005 rule explanation:' AS rule_explanation;
SELECT pglinter.explain_rule('B005');

ROLLBACK;
