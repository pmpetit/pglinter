-- Test import_rules_from_file function
-- This test validates the file-based YAML import functionality

-- Create a temporary test file with YAML content using echo with proper escaping
\! echo "metadata:" > /tmp/test_rules_import.yaml
\! echo "  export_timestamp: \"2024-01-01T12:00:00Z\"" >> /tmp/test_rules_import.yaml
\! echo "  total_rules: 2" >> /tmp/test_rules_import.yaml
\! echo "  format_version: \"1.0\"" >> /tmp/test_rules_import.yaml
\! echo "rules:" >> /tmp/test_rules_import.yaml
\! echo "  - id: 9010" >> /tmp/test_rules_import.yaml
\! echo "    name: \"Test File Import Rule 1\"" >> /tmp/test_rules_import.yaml
\! echo "    code: \"TEST_FILE_001\"" >> /tmp/test_rules_import.yaml
\! echo "    enable: true" >> /tmp/test_rules_import.yaml
\! echo "    warning_level: 35" >> /tmp/test_rules_import.yaml
\! echo "    error_level: 75" >> /tmp/test_rules_import.yaml
\! echo "    scope: \"FILE_TEST\"" >> /tmp/test_rules_import.yaml
\! echo "    description: \"Test rule imported from file\"" >> /tmp/test_rules_import.yaml
\! echo "    message: \"File import test found {0} issues\"" >> /tmp/test_rules_import.yaml
\! echo "    fixes:" >> /tmp/test_rules_import.yaml
\! echo "      - \"File-based fix suggestion\"" >> /tmp/test_rules_import.yaml
\! echo "    q1: \"SELECT 'file_test' as result\"" >> /tmp/test_rules_import.yaml
\! echo "    q2: null" >> /tmp/test_rules_import.yaml
\! echo "  - id: 9011" >> /tmp/test_rules_import.yaml
\! echo "    name: \"Test File Import Rule 2\"" >> /tmp/test_rules_import.yaml
\! echo "    code: \"TEST_FILE_002\"" >> /tmp/test_rules_import.yaml
\! echo "    enable: false" >> /tmp/test_rules_import.yaml
\! echo "    warning_level: 20" >> /tmp/test_rules_import.yaml
\! echo "    error_level: 60" >> /tmp/test_rules_import.yaml
\! echo "    scope: \"BASE\"" >> /tmp/test_rules_import.yaml
\! echo "    description: \"Second file import test rule\"" >> /tmp/test_rules_import.yaml
\! echo "    message: \"Second file test message\"" >> /tmp/test_rules_import.yaml
\! echo "    fixes:" >> /tmp/test_rules_import.yaml
\! echo "      - \"Another file fix\"" >> /tmp/test_rules_import.yaml
\! echo "      - \"Second file fix\"" >> /tmp/test_rules_import.yaml
\! echo "    q1: \"SELECT 2 as count\"" >> /tmp/test_rules_import.yaml
\! echo "    q2: \"SELECT 1 as problems\"" >> /tmp/test_rules_import.yaml

-- Test 1: Import rules from file
SELECT pglinter.import_rules_from_file('/tmp/test_rules_import.yaml') AS file_import_result;

-- Verify imported rules
SELECT
    code,
    name,
    enable,
    warning_level,
    error_level,
    scope
FROM pglinter.rules
WHERE code LIKE 'TEST_FILE_%'
ORDER BY code;

-- Test 2: Import from non-existent file (should return error)
SELECT pglinter.import_rules_from_file('/tmp/non_existent_file.yaml') AS nonexistent_file_result;

SELECT pglinter.import_rules_from_file('/tmp/invalid_rules.yaml') AS invalid_file_result;

-- Test 4: Test with empty file
\! touch /tmp/empty_rules.yaml

SELECT pglinter.import_rules_from_file('/tmp/empty_rules.yaml') AS empty_file_result;

-- Verify final state - should still have our valid imported rules
SELECT
    COUNT(*) AS imported_rules_count
FROM pglinter.rules
WHERE code LIKE 'TEST_FILE_%';

-- Clean up test data and files
DELETE FROM pglinter.rules WHERE code LIKE 'TEST_FILE_%';

\! rm -f /tmp/test_rules_import.yaml /tmp/invalid_rules.yaml /tmp/empty_rules.yaml

-- Final verification - no test rules should remain
SELECT COUNT(*) AS remaining_file_test_rules
FROM pglinter.rules
WHERE code LIKE 'TEST_FILE_%';
