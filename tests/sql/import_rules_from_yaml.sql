-- Test import_rules_from_yaml function
-- This test validates the YAML import functionality
CREATE EXTENSION pglinter;

\pset pager off

-- Clean up any existing test rules
DELETE FROM pglinter.rules WHERE code IN ('TEST_YAML_001', 'TEST_YAML_002');

-- Test 1: Valid YAML import with new rules
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 2
  format_version: "1.0"
rules:
  - id: 9001
    name: "Test YAML Rule 1"
    code: "TEST_YAML_001"
    enable: true
    scope: "TEST"
    message: "Test rule found {0} issues"
    fixes:
      - "Fix suggestion 1"
      - "Fix suggestion 2"
  - id: 9002
    name: "Test YAML Rule 2"
    code: "TEST_YAML_002"
    enable: false
    scope: "BASE"
    description: "Second test rule for YAML import"
    message: "Second test rule message"
    fixes:
      - "Another fix suggestion"
') AS import_result;

-- Verify imported rules exist and have correct values
SELECT
    code,
    name,
    enable,
    scope,
    message,
    fixes
FROM pglinter.rules
WHERE code IN ('TEST_YAML_001', 'TEST_YAML_002')
ORDER BY code;

-- Test 2: Update existing rule via YAML import
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-02T00:00:00Z"
  total_rules: 1
  format_version: "1.0"
rules:
  - id: 9001
    name: "Updated Test YAML Rule 1"
    code: "TEST_YAML_001"
    enable: false
    scope: "UPDATED_TEST"
    message: "Updated test message with {0} items"
    fixes:
      - "Updated fix suggestion"
      - "Additional fix"
      - "Third fix option"
') AS update_result;

-- Verify the rule was updated
SELECT
    code,
    name,
    enable,
    scope,
    message,
    array_length(fixes, 1) as fixes_count
FROM pglinter.rules
WHERE code = 'TEST_YAML_001';

-- Test 3: Import with null values
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-03T00:00:00Z"
  total_rules: 1
  format_version: "1.0"
rules:
  - id: 9003
    name: "Test Null Values"
    code: "TEST_YAML_003"
    enable: true
    scope: "BASE"
    message: "Test message"
    fixes: []
') AS null_values_result;

-- Verify null handling
SELECT
    code,
    name,
    array_length(fixes, 1) as fixes_count
FROM pglinter.rules
WHERE code = 'TEST_YAML_003';

-- Test 4: Invalid YAML should return error
SELECT pglinter.import_rules_from_yaml('
invalid_yaml: [
  this is not valid yaml
  - missing proper structure
') AS invalid_yaml_result;

-- Test 5: Empty rules array
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-04T00:00:00Z"
  total_rules: 0
  format_version: "1.0"
rules: []
') AS empty_rules_result;

-- Test 6: YAML with minimal required fields
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-05T00:00:00Z"
  total_rules: 1
  format_version: "1.0"
rules:
  - id: 9004
    name: "Minimal Rule"
    code: "TEST_YAML_MIN"
    enable: true
    scope: "BASE"
    message: "Simple message"
    fixes: []
') AS minimal_rule_result;

-- Verify minimal rule
SELECT code, name, scope FROM pglinter.rules WHERE code = 'TEST_YAML_MIN';

-- Clean up test data
DELETE FROM pglinter.rules WHERE code IN ('TEST_YAML_001', 'TEST_YAML_002', 'TEST_YAML_003', 'TEST_YAML_MIN');

-- Test count verification
SELECT COUNT(*) as remaining_test_rules
FROM pglinter.rules
WHERE code LIKE 'TEST_YAML_%';

DROP EXTENSION pglinter CASCADE;
