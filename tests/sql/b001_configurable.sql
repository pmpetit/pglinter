-- Quick test to verify B001 rule uses configurable thresholds
BEGIN;

-- Create a table without primary key
CREATE TABLE test_no_pk (
    id INTEGER,
    name TEXT
);

CREATE TABLE test_with_pk (
    id INTEGER PRIMARY KEY,
    name TEXT
);

-- Drop extension if exists to reset state
DROP EXTENSION IF EXISTS pglinter;
-- Create extension
CREATE EXTENSION IF NOT EXISTS pglinter;

-- First, disable all rules to isolate B001 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B001 for focused testing
SELECT pglinter.enable_rule('B001') AS b001_enabled;

-- Check current B001 thresholds
SELECT warning_level, error_level FROM pglinter.rules WHERE code = 'B001';

-- Test B001 rule - should show it uses the configured thresholds
SELECT pglinter.perform_base_check();

-- Update B001 thresholds to very large values (60%, 80%) not to trigger on any table without PK
SELECT pglinter.update_rule_levels('B001', 60, 80);

-- Check updated thresholds
SELECT warning_level, error_level FROM pglinter.rules WHERE code = 'B001';

-- Test B001 rule again - should now trigger with new thresholds
SELECT pglinter.perform_base_check();

-- Update B001 thresholds to very low values (1%, 2%) not to trigger on any table without PK
SELECT pglinter.update_rule_levels('B001', 60, 80);

-- Clean up
DROP TABLE test_no_pk;

ROLLBACK;
