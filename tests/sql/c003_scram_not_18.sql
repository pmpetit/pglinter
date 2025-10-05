-- Comprehensive test for pglinter C003 rule: SCRAM-SHA-256 encrypted passwords
-- This script tests the C003 rule when password encryption is set to secure SCRAM-SHA-256
-- Note: MD5 password encryption was removed in PostgreSQL 18

-- Check PostgreSQL version and exit if version 18 or higher
\set pg_version_num `psql -t -A -c "SELECT current_setting('server_version_num')::integer;"`

\if :pg_version_num >= 180000
    \echo 'NOTICE: Skipping C003 test - MD5 password encryption is not supported in PostgreSQL 18+'
    \echo 'NOTICE: Current PostgreSQL version:' `psql -t -A -c "SELECT version();"`
    \q
\endif

\echo 'NOTICE: PostgreSQL version supports password encryption changes - proceeding with C003 SCRAM test'

CREATE EXTENSION pglinter;

BEGIN;

\pset pager off

SELECT 'Testing C003 rule with SCRAM-SHA-256 password encryption...' AS test_info;

-- Store original password_encryption setting
CREATE TEMP TABLE original_settings AS
SELECT name, setting as original_value
FROM pg_settings
WHERE name = 'password_encryption';

SELECT 'Original password_encryption setting: ' || setting AS original_setting
FROM pg_settings
WHERE name = 'password_encryption';

-- Change password_encryption to scram-sha-256 (secure setting)
-- Note: This requires superuser privileges and may require session restart in some cases
SELECT 'Attempting to set password_encryption to scram-sha-256...' AS action_info;

-- Try to change the setting (may fail if not superuser or restart required)
DO $$
DECLARE
    current_user_is_superuser boolean;
    can_change_setting boolean := false;
BEGIN
    -- Check if current user is superuser
    SELECT usesuper INTO current_user_is_superuser
    FROM pg_user
    WHERE usename = current_user;

    IF current_user_is_superuser THEN
        BEGIN
            -- Attempt to change password_encryption
            PERFORM set_config('password_encryption', 'scram-sha-256', false);
            can_change_setting := true;
            RAISE NOTICE 'Successfully changed password_encryption to scram-sha-256';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not change password_encryption (may require restart): %', SQLERRM;
            can_change_setting := false;
        END;
    ELSE
        RAISE NOTICE 'Current user is not superuser - cannot change password_encryption setting';
        can_change_setting := false;
    END IF;

    -- Store whether we could change the setting
    CREATE TEMP TABLE setting_change_status AS
    SELECT can_change_setting as was_changed;
END
$$;

-- Check current password_encryption setting after attempted change
SELECT '=== Current Password Encryption Setting ===' AS test_section;
SELECT
    name,
    setting as current_value,
    CASE
        WHEN setting = 'scram-sha-256' THEN '✅ SECURE: Using recommended SCRAM-SHA-256'
        WHEN setting = 'md5' THEN '❌ INSECURE: Using deprecated MD5'
        ELSE '❓ OTHER: Using ' || setting
    END as security_status
FROM pg_settings
WHERE name = 'password_encryption';

-- First, disable all rules to isolate C003 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only C003 for focused testing
SELECT pglinter.enable_rule('C003') AS c003_enabled;

-- Verify C003 is enabled
SELECT pglinter.is_rule_enabled('C003') AS c003_status;

-- Test 1: Check if C003 detects any issues with current setting
SELECT '=== Test 1: C003 Rule Execution with Current Setting ===' AS test_section;
SELECT pglinter.perform_cluster_check();

-- Test 2: Manual execution of C003 query
SELECT '=== Test 2: Manual C003 Query Execution ===' AS test_section;
SELECT
    count(*) as md5_password_count,
    CASE
        WHEN count(*) = 0 THEN '✅ PASS: No MD5 password encryption detected'
        ELSE '❌ FAIL: ' || count(*) || ' MD5 configuration(s) found'
    END as test_result
FROM pg_catalog.pg_settings
WHERE name='password_encryption' AND setting='md5';

-- Test 3: Show what C003 is actually checking
SELECT '=== Test 3: C003 Query and Logic ===' AS test_section;
SELECT
    'C003 checks for: password_encryption = ''md5''' as what_c003_checks,
    'Current setting: ' || setting as current_setting,
    'Expected result: ' || CASE
        WHEN setting = 'md5' THEN 'FAIL (MD5 detected)'
        ELSE 'PASS (No MD5)'
    END as expected_result
FROM pg_settings
WHERE name = 'password_encryption';

-- Test 4: Rule explanation
SELECT '=== Test 4: C003 Rule Details ===' AS test_section;
SELECT pglinter.explain_rule('C003') AS rule_explanation;

-- Test 5: Show rule configuration
SELECT '=== Test 5: C003 Rule Configuration ===' AS test_section;
SELECT code, name, description, warning_level, error_level, fixes
FROM pglinter.rules
WHERE code = 'C003';

-- Test 6: Demonstrate secure configuration benefits
SELECT '=== Test 6: Security Assessment ===' AS test_section;
SELECT
    CASE
        WHEN setting = 'scram-sha-256' THEN
            'SECURE: SCRAM-SHA-256 provides strong password hashing and is PostgreSQL 18+ compatible'
        WHEN setting = 'md5' THEN
            'INSECURE: MD5 is deprecated, weak, and prevents upgrade to PostgreSQL 18+'
        ELSE
            'UNKNOWN: Setting ' || setting || ' - check PostgreSQL documentation'
    END as security_assessment,
    'Recommendation: Use scram-sha-256 for new installations' as recommendation
FROM pg_settings
WHERE name = 'password_encryption';

-- Test 7: Export results to SARIF format
SELECT '=== Test 7: Export to SARIF ===' AS test_section;
SELECT pglinter.perform_base_check('/tmp/pglinter_c003_scram_results.sarif');

-- Show checksum of generated file if it exists
\! test -f /tmp/pglinter_c003_scram_results.sarif && md5sum /tmp/pglinter_c003_scram_results.sarif || echo "SARIF file not generated"

-- Restore original setting if we changed it (attempt)
DO $$
DECLARE
    is_changed boolean;
    original_val text;
BEGIN
    SELECT was_changed INTO is_changed FROM setting_change_status;
    SELECT original_value INTO original_val FROM original_settings WHERE name = 'password_encryption';

    IF is_changed THEN
        BEGIN
            PERFORM set_config('password_encryption', original_val, false);
            RAISE NOTICE 'Restored password_encryption to original value: %', original_val;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not restore password_encryption (may require restart): %', SQLERRM;
        END;
    END IF;
END
$$;

ROLLBACK;

DROP EXTENSION pglinter CASCADE;
