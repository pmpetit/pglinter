-- Test for output_file parameter being optional - both file and prompt output
BEGIN;

DROP EXTENSION IF EXISTS pg_linter CASCADE;

-- Create test data that will trigger multiple rules
CREATE TABLE table_without_pk (
    id INT,
    name TEXT
);

-- Create redundant indexes
CREATE INDEX idx_name_1 ON table_without_pk(name);
CREATE INDEX idx_name_2 ON table_without_pk(name);

-- Create table with uppercase (triggers B006 and T011)
CREATE TABLE "UPPERCASE_TABLE" (
    id SERIAL PRIMARY KEY,
    "UPPER_COLUMN" TEXT
);

-- Create schema with environment prefix (triggers S002)
CREATE SCHEMA prod_testing;

CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Test 1: Output to prompt (no file parameter)
SELECT 'Testing output to prompt...' as test_info;
SELECT pg_linter.perform_base_check();
SELECT pg_linter.perform_table_check();
SELECT pg_linter.perform_schema_check();

-- Test 2: Output to prompt (NULL file parameter)
SELECT 'Testing output to prompt with NULL...' as test_info;
SELECT pg_linter.perform_base_check(NULL);
SELECT pg_linter.perform_table_check(NULL);
SELECT pg_linter.perform_schema_check(NULL);

-- Test 3: Output to file
SELECT 'Testing output to file...' as test_info;
SELECT pg_linter.perform_base_check('/tmp/test_base_output.sarif');
SELECT pg_linter.perform_table_check('/tmp/test_table_output.sarif');
SELECT pg_linter.perform_schema_check('/tmp/test_schema_output.sarif');

-- Test 4: Comprehensive check with different output options
SELECT 'Testing comprehensive check - to prompt...' as test_info;
SELECT pg_linter.check_all();

-- Test 5: Individual rule testing
SELECT pg_linter.explain_rule('B001');
SELECT pg_linter.explain_rule('T003');
SELECT pg_linter.explain_rule('S002');

-- Test 6: Rule management
SELECT pg_linter.show_rules();

-- Test 7: Rule enable/disable functionality
SELECT pg_linter.disable_rule('B006');
SELECT pg_linter.perform_base_check(); -- Should skip B006
SELECT pg_linter.enable_rule('B006');
SELECT pg_linter.perform_base_check(); -- Should include B006 again

-- Clean up
DROP SCHEMA prod_testing CASCADE;
DROP TABLE "UPPERCASE_TABLE" CASCADE;
DROP TABLE table_without_pk CASCADE;

ROLLBACK;
