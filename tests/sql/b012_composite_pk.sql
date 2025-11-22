-- Test for B012: Composite primary keys with more than 4 columns
CREATE EXTENSION IF NOT EXISTS pglinter;

-- First, disable all rules to isolate B001 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B012 for focused testing
SELECT pglinter.enable_rule('B012') AS b012_enabled;


CREATE TABLE test_composite_pk (
    a INT,
    b INT,
    c INT,
    d INT,
    e INT,
    f INT,
    PRIMARY KEY (a, b, c, d, e, f)
);

-- Run pglinter check
SELECT pglinter.check();

DROP TABLE test_composite_pk CASCADE;

DROP EXTENSION pglinter CASCADE;
