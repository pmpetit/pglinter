-- Test for T010 rule - Tables using reserved keywords
BEGIN;

DROP EXTENSION IF EXISTS pglinter CASCADE;

-- Create tables and columns using reserved keywords (should trigger T010)
CREATE TABLE "SELECT" (
    id SERIAL PRIMARY KEY,
    name TEXT
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    "FROM" TEXT, -- Reserved keyword as column name
    "WHERE" TEXT, -- Reserved keyword as column name
    username TEXT
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    "ORDER" TEXT, -- Reserved keyword as column name
    price NUMERIC
);

-- Create a table with non-reserved names (should not trigger T010)
CREATE TABLE clean_table (
    id SERIAL PRIMARY KEY,
    description TEXT,
    category_name TEXT,
    status_flag BOOLEAN
);

-- Insert some test data
INSERT INTO "SELECT" (name) VALUES ('test1');
INSERT INTO users ("FROM", "WHERE", username) VALUES ('location1', 'condition1', 'user1');
INSERT INTO products ("ORDER", price) VALUES ('desc', 99.99);
INSERT INTO clean_table (description, category_name, status_flag) VALUES ('Clean test', 'Category A', true);

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Test the T010 rule
SELECT 'Testing T010 rule - Reserved keywords...' as test_info;

-- Run table check to detect reserved keyword usage
SELECT pglinter.perform_table_check();

-- Test rule management
SELECT pglinter.explain_rule('T010');
SELECT pglinter.is_rule_enabled('T010') AS t010_enabled;

-- Test disabling T010
SELECT pglinter.disable_rule('T010') AS t010_disabled;
SELECT pglinter.perform_table_check(); -- Should skip T010

-- Re-enable T010
SELECT pglinter.enable_rule('T010') AS t010_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T010 again

-- Show all rules status
SELECT pglinter.show_rules();

-- Clean up
DROP TABLE clean_table CASCADE;
DROP TABLE products CASCADE;
DROP TABLE users CASCADE;
DROP TABLE "SELECT" CASCADE;

ROLLBACK;
