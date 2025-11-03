-- Test for pglinter B005 rule: Database objects with uppercase names
-- This script creates various database objects with uppercase names to test
-- the comprehensive B005 rule detection across all PostgreSQL object types
CREATE EXTENSION pglinter;

-- Create a test schema for our objects
CREATE SCHEMA test_B005_schema;

-- Create test objects with UPPERCASE names (should trigger B005)
-- Using quoted identifiers to force case-sensitive storage

-- 1. Table with uppercase name (quoted for case sensitivity)
CREATE TABLE test_B005_schema."CUSTOMERS_TABLE" (
    customer_id SERIAL PRIMARY KEY,
    "FIRST_NAME" VARCHAR(50),  -- Column with uppercase (quoted)
    last_name VARCHAR(50),     -- Column with lowercase (unquoted - should not trigger)
    "EMAIL_ADDRESS" VARCHAR(100), -- Column with uppercase (quoted)
    phone_number VARCHAR(20)   -- Column with lowercase (unquoted)
);

-- 2. View with uppercase name (quoted for case sensitivity)
CREATE VIEW test_B005_schema."ACTIVE_CUSTOMERS" AS
SELECT
    customer_id,
    "FIRST_NAME",
    last_name
FROM test_B005_schema."CUSTOMERS_TABLE"
WHERE customer_id > 0;

-- 3. Index with uppercase name (quoted for case sensitivity)
CREATE INDEX "IDX_CUSTOMERS_EMAIL" ON test_B005_schema."CUSTOMERS_TABLE" ("EMAIL_ADDRESS");
CREATE INDEX idx_customers_phone ON test_B005_schema."CUSTOMERS_TABLE" (phone_number); -- lowercase, should not trigger

-- 4. Sequence with uppercase name (quoted for case sensitivity)
CREATE SEQUENCE test_B005_schema."CUSTOMER_ID_SEQ";

-- 5. Function with uppercase name (quoted for case sensitivity)
CREATE OR REPLACE FUNCTION test_B005_schema."GET_CUSTOMER_COUNT"()
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM test_B005_schema."CUSTOMERS_TABLE");
END;
$$ LANGUAGE plpgsql;

-- 6. Function with lowercase name (should not trigger)
CREATE OR REPLACE FUNCTION test_B005_schema.get_customer_by_id(p_id INTEGER)
RETURNS TEXT AS $$
BEGIN
    RETURN (SELECT "FIRST_NAME" FROM test_B005_schema."CUSTOMERS_TABLE" WHERE customer_id = p_id);
END;
$$ LANGUAGE plpgsql;

-- 7. Trigger with uppercase name
CREATE OR REPLACE FUNCTION test_B005_schema.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add timestamp column for trigger
ALTER TABLE test_B005_schema."CUSTOMERS_TABLE" ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();

CREATE TRIGGER "UPDATE_TIMESTAMP_TRIGGER"
BEFORE UPDATE ON test_B005_schema."CUSTOMERS_TABLE"
FOR EACH ROW EXECUTE FUNCTION test_B005_schema.update_timestamp();

-- 8. Constraint with uppercase name (user-defined, not auto-generated)
ALTER TABLE test_B005_schema."CUSTOMERS_TABLE"
ADD CONSTRAINT "EMAIL_UNIQUE_CONSTRAINT" UNIQUE ("EMAIL_ADDRESS");

-- 9. User-defined type with uppercase name
CREATE TYPE test_B005_schema."CUSTOMER_STATUS" AS ENUM ('active', 'inactive', 'pending');

-- 10. Domain with uppercase name
CREATE DOMAIN test_B005_schema."EMAIL_DOMAIN" AS VARCHAR(100)
CHECK (value ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- 11. Create another schema with uppercase name
CREATE SCHEMA "TEST_UPPERCASE_SCHEMA";

-- Create some data for testing
INSERT INTO test_B005_schema."CUSTOMERS_TABLE" ("FIRST_NAME", last_name, "EMAIL_ADDRESS", phone_number) VALUES
('John', 'Doe', 'john.doe@example.com', '555-1234'),
('Jane', 'Smith', 'jane.smith@example.com', '555-5678'),
('Bob', 'Johnson', 'bob.johnson@example.com', '555-9012');

-- Test B005 rule

SELECT 'Testing B005 rule - Comprehensive uppercase object detection...' AS test_info;

-- First, disable all rules to isolate B005 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B005 for focused testing
SELECT pglinter.enable_rule('B005') AS B005_enabled;

-- Verify B005 is enabled
SELECT pglinter.is_rule_enabled('B005') AS B005_status;

-- Run B005 check to detect uppercase violations
-- Expected result: Should detect multiple uppercase objects we created
SELECT 'Running B005 check to detect comprehensive uppercase violations...' AS status;
SELECT pglinter.perform_base_check();

-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_B005_results.sarif');
-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_B005_results.sarif

-- Test rule management for B005
SELECT 'Testing B005 rule management...' AS test_section;
SELECT pglinter.explain_rule('B005');

DROP SCHEMA test_B005_schema CASCADE;
DROP SCHEMA "TEST_UPPERCASE_SCHEMA" CASCADE;

DROP EXTENSION pglinter CASCADE;
