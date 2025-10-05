-- Simple example to demonstrate missing indexes and T004 rule detection
-- This script creates a table, generates data, performs queries that cause sequential scans,
-- and then shows how the T004 rule would detect this issue.
CREATE EXTENSION pglinter;

-- Clean up
DROP TABLE IF EXISTS user_activities CASCADE;

-- Create a table without proper indexes (except primary key)
CREATE TABLE user_activities (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT SETSEED(0.42);

-- Insert a significant amount of test data
INSERT INTO user_activities (
    user_id, activity_type, description, ip_address
)
SELECT
    (RANDOM() * 1000 + 1)::INTEGER,  -- user_id between 1 and 1000
    CASE (RANDOM() * 4)::INTEGER
        WHEN 0 THEN 'login'
        WHEN 1 THEN 'logout'
        WHEN 2 THEN 'view_page'
        ELSE 'purchase'
    END AS activity_type,
    'Activity description ' || i AS description,
    ('192.168.1.' || (RANDOM() * 254 + 1)::INTEGER)::INET AS ip_address
FROM GENERATE_SERIES(1, 100000) AS i;


SELECT 'Performing queries that will cause sequential scans...' AS status;

-- Query 1: Find activities by user_id (no index on user_id)
SELECT 'Query 1: Finding activities for user_id = 500' AS query_info;
DO $$
BEGIN
    FOR i IN 1..100 LOOP
        EXECUTE format('SELECT * FROM user_activities WHERE user_id = %s', i);
    END LOOP;
END$$;

-- Query 2: Find activities by activity_type (no index on activity_type)
SELECT
    'Query 2: Finding activities for activity_type = ''login''' AS query_info;
DO $$
DECLARE
    activity_types TEXT[] := ARRAY['login','logout','view_page','purchase'];
BEGIN
    FOR i IN 1..array_length(activity_types, 1) LOOP
        EXECUTE format('SELECT * FROM user_activities WHERE activity_type = ''%s''', activity_types[i]);
    END LOOP;
END$$;

SELECT COUNT(*) FROM user_activities
WHERE user_id = 500;

-- Query 2: Find activities by activity_type (no index on activity_type)
SELECT 'Query 2: Finding login activities' AS query_info;
SELECT COUNT(*) FROM user_activities
WHERE activity_type = 'login';


-- Query 4: Complex query combining multiple unindexed columns
SELECT 'Query 4: Finding user logins in last month' AS query_info;
SELECT COUNT(*) FROM user_activities
WHERE
    user_id BETWEEN 100 AND 200
    AND activity_type = 'login';

-- Query 5: Pattern matching on description (no index, will be very slow)
SELECT 'Query 5: Searching descriptions (this will be slow!)' AS query_info;
SELECT COUNT(*)
FROM user_activities
WHERE description LIKE '%Activity description 50%';

-- Update statistics after the queries
ANALYZE user_activities;

SELECT PG_SLEEP(5);



-- Disable all rules first
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- enable T004
SELECT pglinter.enable_rule('T004') AS t004_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T004

DROP TABLE IF EXISTS user_activities CASCADE;

-- Create a table without proper indexes (except primary key)
CREATE TABLE indexed_user_activities (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert a significant amount of test data
INSERT INTO indexed_user_activities (
    user_id, activity_type, description, ip_address
)
SELECT
    (RANDOM() * 1000 + 1)::INTEGER,  -- user_id between 1 and 1000
    CASE (RANDOM() * 4)::INTEGER
        WHEN 0 THEN 'login'
        WHEN 1 THEN 'logout'
        WHEN 2 THEN 'view_page'
        ELSE 'purchase'
    END AS activity_type,
    'Activity description ' || i AS description,
    ('192.168.1.' || (RANDOM() * 254 + 1)::INTEGER)::INET AS ip_address
FROM GENERATE_SERIES(1, 100000) AS i;

-- Now let's add the missing indexes
SELECT 'Adding missing indexes to improve performance...' AS status;

CREATE INDEX idx_user_activities_user_id ON indexed_user_activities (user_id);
CREATE INDEX idx_user_activities_activity_type ON indexed_user_activities (
    activity_type
);
CREATE INDEX idx_user_activities_user_activity ON indexed_user_activities (
    user_id, activity_type
);

ANALYZE indexed_user_activities;

SELECT 'Running the same queries again with indexes...' AS status;

-- Query 1: Find activities by user_id (no index on user_id)
SELECT 'Query 1: Finding activities for user_id = 500' AS query_info;
DO $$
BEGIN
    FOR i IN 1..100 LOOP
        EXECUTE format('SELECT * FROM indexed_user_activities WHERE user_id = %s', i);
    END LOOP;
END$$;

-- Query 2: Find activities by activity_type (no index on activity_type)
SELECT
    'Query 2: Finding activities for activity_type = ''login''' AS query_info;
DO $$
DECLARE
    activity_types TEXT[] := ARRAY['login','logout','view_page','purchase'];
BEGIN
    FOR i IN 1..array_length(activity_types, 1) LOOP
        EXECUTE format('SELECT * FROM indexed_user_activities WHERE activity_type = ''%s''', activity_types[i]);
    END LOOP;
END$$;

SELECT COUNT(*) FROM indexed_user_activities
WHERE user_id = 500;

-- Query 2: Find activities by activity_type (no index on activity_type)
SELECT 'Query 2: Finding login activities' AS query_info;
SELECT COUNT(*) FROM indexed_user_activities
WHERE activity_type = 'login';

-- Query 3: Find activities by date range (no index on activity_date)
SELECT 'Query 3: Finding recent activities' AS query_info;
SELECT COUNT(*)
FROM indexed_user_activities
WHERE activity_type = 'login';

-- Query 4: Complex query combining multiple unindexed columns
SELECT 'Query 4: Finding user logins in last month' AS query_info;
SELECT COUNT(*) FROM indexed_user_activities
WHERE
    user_id BETWEEN 100 AND 200
    AND activity_type = 'login';

-- Update statistics after the queries
ANALYZE indexed_user_activities;

SELECT PG_SLEEP(5);

-- Disable all rules first
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Run table check to detect high sequential scan usage
SELECT pglinter.perform_table_check();

-- Test rule management for T004
SELECT pglinter.explain_rule('T004');
SELECT pglinter.is_rule_enabled('T004') AS t004_enabled;

-- enable T004
SELECT pglinter.enable_rule('T004') AS t004_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T004

-- Cleanup
DROP TABLE IF EXISTS indexed_user_activities CASCADE;
DROP TABLE IF EXISTS user_activities CASCADE;

DROP EXTENSION pglinter CASCADE;
