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

SELECT count(*) AS violation_count
FROM pglinter.get_violations()
WHERE rule_code = 'B012';

SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
WHERE rule_code = 'B012';

DROP TABLE test_composite_pk CASCADE;

DROP EXTENSION pglinter CASCADE;
