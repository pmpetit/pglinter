# get_violations()

## Purpose

The `get_violations()` function in pglinter is designed to collect and return all detected violations for enabled rules in the PostgreSQL database. It provides a programmatic way to retrieve which rules have violations and the specific database objects affected, supporting deeper analysis and integration with reporting tools.

## Usage

- **How it works:**
  1. Queries the `pglinter.rules` table for all enabled rules.
  2. For each rule, calls `get_violations_for_rule()` to fetch all violation locations.
  3. Returns a vector of tuples: each tuple contains the rule code and a vector of violation locations.

- **Return Value:**
  - On success: `Ok(Vec<(rule_code, Vec<(classid, objid, objsubid)>)>)`
  - On error: `Err(String)` with a descriptive error message

## Typical Use Cases

- Automated reporting of rule violations
- Integration with SARIF or other static analysis formats
- Custom dashboards or alerting for database health
- Regression testing and rule validation

## Notes

- Only enabled rules are checked.
- Handles errors gracefully and logs issues per rule.
- Designed for extensibility and integration with other pglinter features.
