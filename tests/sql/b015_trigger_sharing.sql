-- Regression test for B015 rule - Tables with shared trigger functions
-- This script creates a test scenario with:
-- - 10 tables total
-- - 5 tables with their own unique trigger functions
-- - 3 tables sharing the same trigger function
-- - 2 tables without any triggers

CREATE EXTENSION IF NOT EXISTS pglinter;

\pset pager off


CREATE SCHEMA trigger_test;

-- =============================================================================
-- Create 10 test tables
-- =============================================================================

-- Tables 1-5: Each will have its own unique trigger function
CREATE TABLE trigger_test.table_01 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_02 (
    id SERIAL PRIMARY KEY,
    description TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_03 (
    id SERIAL PRIMARY KEY,
    value INTEGER,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_04 (
    id SERIAL PRIMARY KEY,
    status VARCHAR(20),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_05 (
    id SERIAL PRIMARY KEY,
    category VARCHAR(30),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tables 6-8: Will share the same trigger function
CREATE TABLE trigger_test.table_06 (
    id SERIAL PRIMARY KEY,
    data JSONB,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_07 (
    id SERIAL PRIMARY KEY,
    content TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_08 (
    id SERIAL PRIMARY KEY,
    amount DECIMAL(10,2),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tables 9-10: No triggers
CREATE TABLE trigger_test.table_09 (
    id SERIAL PRIMARY KEY,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trigger_test.table_10 (
    id SERIAL PRIMARY KEY,
    archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- Create unique trigger functions for tables 1-5
-- =============================================================================

-- Trigger function for table_01
CREATE OR REPLACE FUNCTION trigger_test.update_table_01_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RAISE NOTICE 'Table 01 trigger executed for ID %', NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for table_02
CREATE OR REPLACE FUNCTION trigger_test.update_table_02_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RAISE NOTICE 'Table 02 trigger executed for ID %', NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for table_03
CREATE OR REPLACE FUNCTION trigger_test.update_table_03_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RAISE NOTICE 'Table 03 trigger executed for ID %', NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for table_04
CREATE OR REPLACE FUNCTION trigger_test.update_table_04_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RAISE NOTICE 'Table 04 trigger executed for ID %', NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for table_05
CREATE OR REPLACE FUNCTION trigger_test.update_table_05_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RAISE NOTICE 'Table 05 trigger executed for ID %', NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create shared trigger function for tables 6-8
-- =============================================================================

-- Shared trigger function that will be used by tables 6, 7, and 8
CREATE OR REPLACE FUNCTION trigger_test.shared_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RAISE NOTICE 'Shared trigger executed for table % with ID %', TG_TABLE_NAME, NEW.id;

    -- Example of problematic shared logic (like the original issue)
    IF TG_TABLE_NAME = 'table_06' THEN
        -- Special logic for table_06
        RAISE NOTICE 'Special processing for table_06';
    ELSIF TG_TABLE_NAME = 'table_07' THEN
        -- Special logic for table_07
        RAISE NOTICE 'Special processing for table_07';
    ELSIF TG_TABLE_NAME = 'table_08' THEN
        -- Special logic for table_08
        RAISE NOTICE 'Special processing for table_08';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create triggers on tables 1-8
-- =============================================================================

-- Unique triggers for tables 1-5
CREATE TRIGGER trigger_table_01_update
    BEFORE UPDATE ON trigger_test.table_01
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.update_table_01_timestamp();

CREATE TRIGGER trigger_table_02_update
    BEFORE UPDATE ON trigger_test.table_02
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.update_table_02_timestamp();

CREATE TRIGGER trigger_table_03_update
    BEFORE UPDATE ON trigger_test.table_03
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.update_table_03_timestamp();

CREATE TRIGGER trigger_table_04_update
    BEFORE UPDATE ON trigger_test.table_04
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.update_table_04_timestamp();

CREATE TRIGGER trigger_table_05_update
    BEFORE UPDATE ON trigger_test.table_05
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.update_table_05_timestamp();

-- Shared triggers for tables 6-8 (using the same function)
CREATE TRIGGER trigger_table_06_update
    BEFORE UPDATE ON trigger_test.table_06
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.shared_update_timestamp();

CREATE TRIGGER trigger_table_07_update
    BEFORE UPDATE ON trigger_test.table_07
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.shared_update_timestamp();

CREATE TRIGGER trigger_table_08_update
    BEFORE UPDATE ON trigger_test.table_08
    FOR EACH ROW
    EXECUTE FUNCTION trigger_test.shared_update_timestamp();

-- Tables 9 and 10 have NO triggers (as required)

-- =============================================================================
-- Test the scenario
-- =============================================================================

-- Insert test data
INSERT INTO trigger_test.table_01 (name) VALUES ('Test 1');
INSERT INTO trigger_test.table_02 (description) VALUES ('Test 2');
INSERT INTO trigger_test.table_03 (value) VALUES (123);
INSERT INTO trigger_test.table_04 (status) VALUES ('active');
INSERT INTO trigger_test.table_05 (category) VALUES ('sample');
INSERT INTO trigger_test.table_06 (data) VALUES ('{"test": "data"}');
INSERT INTO trigger_test.table_07 (content) VALUES ('Sample content');
INSERT INTO trigger_test.table_08 (amount) VALUES (99.99);
INSERT INTO trigger_test.table_09 (notes) VALUES ('No trigger table');
INSERT INTO trigger_test.table_10 (archived) VALUES (false);

-- Test with only B015 enabled
SELECT 'Testing B015 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('B015') AS b015_only_enabled;
SELECT pglinter.perform_base_check(); -- Should only run B015
SELECT pglinter.enable_rule('T015') AS t015_only_enabled;
SELECT pglinter.perform_table_check(); -- Should only run T015

-- Test with output
SELECT pglinter.perform_base_check('/tmp/pglinter_b015_results.sarif');
-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_b015_results.sarif

-- Cleanup
\echo 'Cleaning up test schema...'
DROP SCHEMA trigger_test CASCADE;

DROP EXTENSION pglinter;
