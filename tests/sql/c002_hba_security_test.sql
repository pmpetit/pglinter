-- Comprehensive test for pglinter C002 rule: Insecure pg_hba.conf entries
-- This script tests the detection of insecure authentication methods in pg_hba.conf
CREATE EXTENSION pglinter;


\pset pager off

SELECT 'Testing C002 rule - pg_hba.conf security checks...' AS test_info;

-- First, disable all rules to isolate C002 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only C002 for focused testing
SELECT pglinter.enable_rule('C002') AS c002_enabled;

-- Verify C002 is enabled
SELECT pglinter.is_rule_enabled('C002') AS c002_status;

-- Test 1: Run C002 check with current settings
SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'C002';

-- Test if file exists and show checksum


-- Test rule explanation
SELECT 'C002 rule explanation:' AS explanation_info;
SELECT pglinter.explain_rule('C002') AS rule_explanation;


DROP EXTENSION pglinter CASCADE;
