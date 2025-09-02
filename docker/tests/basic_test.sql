-- Test script for pglinter Docker container
-- This script tests basic functionality of the pglinter extension

\echo 'Testing pglinter extension functionality...'

-- Test 1: Check if extension is installed
\echo 'Test 1: Checking extension installation'
SELECT extname, extversion FROM pg_extension WHERE extname = 'pglinter';

-- Test 2: Test show_rules function
\echo 'Test 2: Testing show_rules() function'
SELECT pglinter.show_rules();

-- Test 3: Test check_base function
\echo 'Test 3: Testing check_base() function'
SELECT pglinter.check_base();

-- Test 4: Create a test table and check for issues
\echo 'Test 4: Creating test table and running checks'
CREATE TABLE IF NOT EXISTS test_table (
    id INTEGER,
    name TEXT,
    email TEXT
);

-- Test 5: Run check_all function
\echo 'Test 5: Running check_all() function'
SELECT pglinter.check_all();

-- Clean up
DROP TABLE IF EXISTS test_table;

\echo 'All tests completed successfully! 🎉'
