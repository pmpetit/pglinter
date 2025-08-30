-- Simple example to demonstrate missing indexes and T005 rule detection
-- This script creates a table, generates data, performs queries that cause sequential scans,
-- and then shows how the T005 rule would detect this issue.

-- Clean up
DROP TABLE IF EXISTS user_activities CASCADE;

-- Create a table without proper indexes (except primary key)
CREATE TABLE user_activities (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert a significant amount of test data
INSERT INTO user_activities (user_id, activity_type, activity_date, description, ip_address)
SELECT
    (RANDOM() * 1000 + 1)::INTEGER,  -- user_id between 1 and 1000
    CASE (RANDOM() * 4)::INTEGER
        WHEN 0 THEN 'login'
        WHEN 1 THEN 'logout'
        WHEN 2 THEN 'view_page'
        ELSE 'purchase'
    END,
    CURRENT_DATE - (RANDOM() * 90)::INTEGER,  -- activities from last 90 days
    'Activity description ' || i,
    ('192.168.1.' || (RANDOM() * 254 + 1)::INTEGER)::INET
FROM generate_series(1, 100000) AS i;

-- Update table statistics
ANALYZE user_activities;

-- Show initial state (should have minimal sequential scans)
SELECT 'Initial statistics after data insertion:' as info;
SELECT
    schemaname || '.' || relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    CASE
        WHEN seq_scan > 0 THEN ROUND(seq_tup_read::numeric / seq_scan, 0)
        ELSE 0
    END as avg_seq_tup_read_per_scan
FROM pg_stat_user_tables
WHERE relname = 'user_activities';

-- Now perform queries that will cause sequential scans due to missing indexes

SELECT 'Performing queries that will cause sequential scans...' as status;

-- Query 1: Find activities by user_id (no index on user_id)
SELECT 'Query 1: Finding activities for user_id = 500' as query_info;
SELECT COUNT(*) FROM user_activities WHERE user_id = 500;

-- Query 2: Find activities by activity_type (no index on activity_type)
SELECT 'Query 2: Finding login activities' as query_info;
SELECT COUNT(*) FROM user_activities WHERE activity_type = 'login';

-- Query 3: Find activities by date range (no index on activity_date)
SELECT 'Query 3: Finding recent activities' as query_info;
SELECT COUNT(*) FROM user_activities WHERE activity_date >= CURRENT_DATE - INTERVAL '7 days';

-- Query 4: Complex query combining multiple unindexed columns
SELECT 'Query 4: Finding user logins in last month' as query_info;
SELECT COUNT(*) FROM user_activities
WHERE user_id BETWEEN 100 AND 200
  AND activity_type = 'login'
  AND activity_date >= CURRENT_DATE - INTERVAL '30 days';

-- Query 5: Pattern matching on description (no index, will be very slow)
SELECT 'Query 5: Searching descriptions (this will be slow!)' as query_info;
SELECT COUNT(*) FROM user_activities WHERE description LIKE '%Activity description 50%';

-- give time to pg write its stats
VACUUM FULL;

-- Update statistics after the queries
ANALYZE user_activities;

-- Disable all rules first
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Run table check to detect high sequential scan usage
SELECT pglinter.perform_table_check();

-- Test rule management for T005
SELECT pglinter.explain_rule('T005');
SELECT pglinter.is_rule_enabled('T005') AS t005_enabled;

-- enable T005
SELECT pglinter.enable_rule('T005') AS t005_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T005


-- Now let's add the missing indexes
SELECT 'Adding missing indexes to improve performance...' as status;

CREATE INDEX idx_user_activities_user_id ON user_activities(user_id);
CREATE INDEX idx_user_activities_activity_type ON user_activities(activity_type);
CREATE INDEX idx_user_activities_activity_date ON user_activities(activity_date);
CREATE INDEX idx_user_activities_user_activity ON user_activities(user_id, activity_type);

-- Reset statistics and run the same queries
SELECT pg_stat_reset();
ANALYZE user_activities;

SELECT 'Running the same queries again with indexes...' as status;

-- Run the same queries (should now use indexes)
SELECT COUNT(*) FROM user_activities WHERE user_id = 500;
SELECT COUNT(*) FROM user_activities WHERE activity_type = 'login';
SELECT COUNT(*) FROM user_activities WHERE activity_date >= CURRENT_DATE - INTERVAL '7 days';
SELECT COUNT(*) FROM user_activities
WHERE user_id BETWEEN 100 AND 200
  AND activity_type = 'login'
  AND activity_date >= CURRENT_DATE - INTERVAL '30 days';

ANALYZE user_activities;

-- Update statistics after the queries
ANALYZE user_activities;

-- Disable all rules first
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Run table check to detect high sequential scan usage
SELECT pglinter.perform_table_check();

-- Test rule management for T005
SELECT pglinter.explain_rule('T005');
SELECT pglinter.is_rule_enabled('T005') AS t005_enabled;

-- enable T005
SELECT pglinter.enable_rule('T005') AS t005_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T005


SELECT 'Summary:' as info;
SELECT '
This example demonstrates:
1. How tables without proper indexes cause high sequential scan usage
2. What the T005 rule detects (percentage of tuples accessed via sequential scans vs total)
3. How adding appropriate indexes dramatically reduces sequential scan percentage
4. Why the T005 rule is important for database performance

The T005 rule specifically looks for tables where:
- There have been sequential scans (seq_scan > 0)
- The percentage of tuples accessed via sequential scans exceeds thresholds:
  * Warning level (50%): seq_tup_read / (seq_tup_read + idx_tup_fetch) > 0.50
  * Error level (90%): seq_tup_read / (seq_tup_read + idx_tup_fetch) > 0.90

This percentage-based approach identifies tables where most data access is happening
through sequential scans rather than efficient index scans, indicating missing indexes.
' as explanation;

-- Cleanup
DROP TABLE IF EXISTS user_activities CASCADE;
