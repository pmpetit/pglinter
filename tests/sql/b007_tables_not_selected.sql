-- Test for pglinter B007 rule: Tables that are never selected from
-- This script creates tables with mixed usage patterns:
-- - Some tables that are regularly queried (both index and sequential scans)
-- - Some tables that are never selected from (neither idx_scan nor seq_scan)
-- to demonstrate the B007 rule detection of unused tables

\pset pager off

SELECT pg_stat_reset();

-- Clean up any existing test tables
DROP TABLE IF EXISTS active_users_table CASCADE;
DROP TABLE IF EXISTS dormant_logs_table CASCADE;
DROP TABLE IF EXISTS unused_config_table CASCADE;
DROP TABLE IF EXISTS frequently_accessed_table CASCADE;
DROP TABLE IF EXISTS completely_unused_table CASCADE;

-- Table 1: Active users table (will be frequently accessed)
CREATE TABLE active_users_table (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add index for performance
CREATE INDEX idx_active_users_username ON active_users_table (username);
CREATE INDEX idx_active_users_last_login ON active_users_table (last_login);

-- Table 2: Dormant logs table (will have some access)
CREATE TABLE dormant_logs_table (
    id SERIAL,
    log_level VARCHAR(20),
    message TEXT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INTEGER
);

-- Table 3: Unused configuration table (NEVER accessed - B007 violation)
CREATE TABLE unused_config_table (
    id SERIAL,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 4: Frequently accessed table (high activity)
CREATE TABLE frequently_accessed_table (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10,2),
    stock_quantity INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add multiple indexes for various query patterns
CREATE INDEX idx_frequently_product_name ON frequently_accessed_table (product_name);
CREATE INDEX idx_frequently_category ON frequently_accessed_table (category);
CREATE INDEX idx_frequently_price ON frequently_accessed_table (price);

-- Table 5: Completely unused table (NEVER accessed - B007 violation)
CREATE TABLE completely_unused_table (
    id SERIAL,
    data_field VARCHAR(200),
    numeric_field INTEGER,
    timestamp_field TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'inactive'
);

-- Insert substantial data into all tables
-- Active users table
INSERT INTO active_users_table (username, email, last_login, is_active)
SELECT
    'user_' || i,
    'user' || i || '@example.com',
    '2024-01-01'::timestamp + (i || ' hours')::interval,
    (i % 2 = 0)
FROM generate_series(1, 8000) i;

-- Dormant logs table
INSERT INTO dormant_logs_table (log_level, message, logged_at, user_id)
SELECT
    CASE (i % 4)
        WHEN 0 THEN 'INFO'
        WHEN 1 THEN 'WARNING'
        WHEN 2 THEN 'ERROR'
        ELSE 'DEBUG'
    END,
    'Log message number ' || i,
    '2024-01-01'::timestamp + (i || ' minutes')::interval,
    (i % 1000) + 1
FROM generate_series(1, 15000) i;

-- Unused configuration table (has data but NEVER queried)
INSERT INTO unused_config_table (config_key, config_value, description)
SELECT
    'config_key_' || i,
    'config_value_' || i,
    'Configuration setting number ' || i
FROM generate_series(1, 2000) i;

-- Frequently accessed table
INSERT INTO frequently_accessed_table (product_name, category, price, stock_quantity)
SELECT
    'Product_' || i,
    CASE (i % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        WHEN 3 THEN 'Home'
        ELSE 'Sports'
    END,
    (i % 1000) + 10.99,
    (i % 100) + 1
FROM generate_series(1, 12000) i;

-- Completely unused table (has data but NEVER queried)
INSERT INTO completely_unused_table (data_field, numeric_field, status)
SELECT
    'data_entry_' || i,
    i * 7,
    CASE (i % 3)
        WHEN 0 THEN 'inactive'
        WHEN 1 THEN 'pending'
        ELSE 'archived'
    END
FROM generate_series(1, 5000) i;

-- Reset PostgreSQL statistics to start with clean slate


-- Update all table statistics
VACUUM ANALYZE active_users_table;
VACUUM ANALYZE dormant_logs_table;
VACUUM ANALYZE unused_config_table;
VACUUM ANALYZE frequently_accessed_table;
VACUUM ANALYZE completely_unused_table;

select pg_sleep(2);

-- Create the extension and test B007 rule
DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

SELECT 'Testing B007 rule - Tables never selected detection...' as test_info;

-- First, disable all rules to isolate B007 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B007 for focused testing
SELECT pglinter.enable_rule('B007') AS b007_enabled;

-- Verify B007 is enabled
SELECT pglinter.is_rule_enabled('B007') AS b007_status;

SELECT pglinter.perform_base_check();

-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_b007_results.sarif');
-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_b007_results.sarif

-- Now simulate realistic usage patterns:

-- 1. Heavy usage of active_users_table (both index and sequential scans)
SELECT COUNT(*) FROM active_users_table WHERE is_active = true;
SELECT COUNT(*) FROM active_users_table WHERE username = 'user_100';
SELECT COUNT(*) FROM active_users_table WHERE username LIKE 'user_1%';
SELECT id, username, email FROM active_users_table WHERE last_login > '2024-01-15' ORDER BY last_login DESC LIMIT 20;
SELECT username, email FROM active_users_table WHERE is_active = true ORDER BY id LIMIT 100;

-- 2. Moderate usage of dormant_logs_table (some scans)
SELECT COUNT(*) FROM dormant_logs_table WHERE log_level = 'ERROR';
SELECT message FROM dormant_logs_table WHERE logged_at > '2024-01-01' LIMIT 50;
SELECT COUNT(*) FROM dormant_logs_table WHERE user_id IS NOT NULL;

-- 3. High usage of frequently_accessed_table (many different query patterns)
SELECT COUNT(*) FROM frequently_accessed_table WHERE category = 'Electronics';
SELECT product_name, price FROM frequently_accessed_table WHERE price > 500 ORDER BY price DESC LIMIT 10;
SELECT category, COUNT(*) FROM frequently_accessed_table GROUP BY category;
SELECT AVG(price) FROM frequently_accessed_table WHERE stock_quantity > 50;
SELECT id,product_name,category,price FROM frequently_accessed_table WHERE product_name = 'Product_1000';
SELECT COUNT(*) FROM frequently_accessed_table WHERE category IN ('Electronics', 'Books');

-- 4. NO usage of unused_config_table (B007 violation - never selected)
-- (Intentionally no queries to simulate unused table)

-- 5. NO usage of completely_unused_table (B007 violation - never selected)
-- (Intentionally no queries to simulate completely unused table)

-- Update statistics after usage simulation
VACUUM ANALYZE active_users_table;
VACUUM ANALYZE dormant_logs_table;
VACUUM ANALYZE unused_config_table;
VACUUM ANALYZE frequently_accessed_table;
VACUUM ANALYZE completely_unused_table;

-- Allow time for statistics to be recorded
SELECT pg_sleep(5);

-- Run base check to detect B007 violations
-- Expected result: Should detect unused_config_table and completely_unused_table
SELECT 'Running base check to detect B007 violations (tables never selected)...' as status;
SELECT pglinter.perform_base_check();


-- Clean up test tables
DROP TABLE IF EXISTS active_users_table CASCADE;
DROP TABLE IF EXISTS dormant_logs_table CASCADE;
DROP TABLE IF EXISTS unused_config_table CASCADE;
DROP TABLE IF EXISTS frequently_accessed_table CASCADE;
DROP TABLE IF EXISTS completely_unused_table CASCADE;

SELECT 'B007 comprehensive test completed successfully!' as test_result;
