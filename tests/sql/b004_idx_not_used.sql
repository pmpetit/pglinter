-- Test for pglinter B004 rule: Unused indexes detection
-- This script creates tables with both used and unused indexes
-- to demonstrate the B004 rule detection of indexes that are never scanned
CREATE EXTENSION pglinter;

-- Table : table_with_mixed_index_usage

DROP TABLE IF EXISTS customer_analytics;

CREATE TABLE customer_analytics (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    page_views INTEGER DEFAULT 0,
    session_duration INTEGER DEFAULT 0,
    last_login TIMESTAMP,
    device_type VARCHAR(50),
    browser VARCHAR(50),
    ip_address INET,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Mix of used and unused indexes
CREATE INDEX idx_analytics_customer_id ON customer_analytics (customer_id);     -- Will be used
CREATE INDEX idx_analytics_last_login ON customer_analytics (last_login);       -- Will be used
CREATE INDEX idx_analytics_device_type ON customer_analytics (device_type);     -- Will NOT be used
CREATE INDEX idx_analytics_browser ON customer_analytics (browser);             -- Will NOT be used
CREATE INDEX idx_analytics_ip_address ON customer_analytics (ip_address);       -- Will NOT be used

-- Insert large amount of analytics data
INSERT INTO customer_analytics (customer_id, page_views, session_duration, last_login, device_type, browser)
SELECT
    (i % 5) + 1,  -- customer_id (1-5)
    i % 100 + 10,  -- page_views (10-109)
    (i % 3600) + 300,  -- session_duration (300-3899 seconds)
    '2024-01-01'::TIMESTAMP + (i || ' seconds')::INTERVAL,  -- varying dates
    CASE (i % 4)
        WHEN 0 THEN 'desktop'
        WHEN 1 THEN 'mobile'
        WHEN 2 THEN 'tablet'
        ELSE 'laptop'
    END,
    CASE (i % 3)
        WHEN 0 THEN 'chrome'
        WHEN 1 THEN 'firefox'
        ELSE 'safari'
    END
FROM GENERATE_SERIES(1, 22000) AS i;

-- Reset statistics to start fresh
SELECT PG_STAT_RESET();

-- Update table statistics
ANALYZE customer_analytics;

-- Use some indexes on customer_analytics (mixed usage)
SELECT COUNT(*) FROM customer_analytics
WHERE customer_id = 1;
SELECT COUNT(*) FROM customer_analytics
WHERE customer_id = 2;
SELECT COUNT(*) FROM customer_analytics
WHERE customer_id IN (1, 2, 3);
SELECT
    id,
    customer_id,
    page_views,
    session_duration
FROM customer_analytics
WHERE customer_id = 1
ORDER BY id LIMIT 10;

-- Do not use indexes
SELECT COUNT(*) FROM customer_analytics
WHERE last_login > '2024-01-01';
SELECT COUNT(*) FROM customer_analytics
WHERE last_login > '2024-01-15';
SELECT COUNT(*) FROM customer_analytics
WHERE last_login BETWEEN '2024-01-01' AND '2024-01-20';
SELECT
    id,
    customer_id,
    page_views,
    session_duration
FROM customer_analytics
WHERE last_login > '2024-01-01'
ORDER BY last_login LIMIT 10;

-- Update statistics after usage
-- Update table statistics
ANALYZE customer_analytics;

-- Give some time....
SELECT PG_SLEEP(2);

SELECT 'Testing B004 rule - Unused indexes detection...' AS test_info;

-- First, disable all rules to isolate B004 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B004 for focused testing
SELECT pglinter.enable_rule('B004') AS b004_enabled;

-- Verify B004 is enabled
SELECT pglinter.is_rule_enabled('B004') AS b004_status;

-- Run base check to detect B004 violations
-- Expected result: Should detect unused indexes with idx_scan = 0
SELECT 'Running base check to detect B004 violations...' AS status;
SELECT pglinter.perform_base_check();

-- Test rule management for B004
SELECT 'Testing B004 rule management...' AS test_section;
SELECT pglinter.explain_rule('B004');

-- Drop some unused indexes to show improvement
DROP INDEX idx_analytics_device_type;

-- Update table statistics
ANALYZE customer_analytics;
-- Give some time....
SELECT PG_SLEEP(2);

-- Run B004 check again (should show fewer violations)
SELECT 'Running B004 check after dropping some unused indexes (should show fewer violations):' AS test_info;
SELECT pglinter.perform_base_check();

-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_b004_results.sarif');
-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_b004_results.sarif


-- Update B004 thresholds to demonstrate message formatting
SELECT pglinter.update_rule_levels('B004', 60, 90);

-- Final demonstration with current state
SELECT 'Final B004 (base check) - Shows percentage-based unused index analysis:' AS b004_demo;
SELECT pglinter.perform_base_check();

DROP TABLE customer_analytics;

DROP EXTENSION pglinter CASCADE;
