// Test fixtures for pglinter unit tests
// This module contains common SQL setup and teardown functions for tests

use pgrx::prelude::*;

/// Generic setup function for creating a test rule
pub fn setup_test_rule(code: &str, id: i32, name: &str, enabled: bool, warning_level: i32, error_level: i32) {
    let _ = Spi::run(&format!("DELETE FROM pglinter.rules WHERE code = '{}'", code));
    let _ = Spi::run(&format!(
        "INSERT INTO pglinter.rules (id, code, name, enable, warning_level, error_level) VALUES ({}, '{}', '{}', {}, {}, {})",
        id, code, name, enabled, warning_level, error_level
    ));
}

/// Generic cleanup function for removing test rules
pub fn cleanup_test_rule(code: &str) {
    let _ = Spi::run(&format!("DELETE FROM pglinter.rules WHERE code = '{}'", code));
}

/// Create test tables for rule testing
pub fn setup_test_tables() {
    // Table without primary key (for B001 testing)
    let _ = Spi::run("DROP TABLE IF EXISTS test_table_no_pk CASCADE");
    let _ = Spi::run("CREATE TABLE test_table_no_pk (id INTEGER, name TEXT)");
    let _ = Spi::run("INSERT INTO test_table_no_pk VALUES (1, 'test')");

    // Table with primary key
    let _ = Spi::run("DROP TABLE IF EXISTS test_table_with_pk CASCADE");
    let _ = Spi::run("CREATE TABLE test_table_with_pk (id INTEGER PRIMARY KEY, name TEXT)");
    let _ = Spi::run("INSERT INTO test_table_with_pk VALUES (1, 'test')");

    // Update statistics
    let _ = Spi::run("ANALYZE test_table_no_pk");
    let _ = Spi::run("ANALYZE test_table_with_pk");
}

/// Cleanup test tables
pub fn cleanup_test_tables() {
    let _ = Spi::run("DROP TABLE IF EXISTS test_table_no_pk CASCADE");
    let _ = Spi::run("DROP TABLE IF EXISTS test_table_with_pk CASCADE");
}

/// Get rule boolean property from database
pub fn get_rule_bool_property(code: &str, property: &str) -> Option<bool> {
    let query = format!("SELECT {} FROM pglinter.rules WHERE code = '{}'", property, code);
    Spi::get_one::<bool>(&query).unwrap_or(Some(false))
}

/// Get test YAML content for import testing
pub fn get_valid_yaml_content() -> &'static str {
    r#"
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 2
  format_version: "1.0"
rules:
  - id: 9998
    name: "Test Import Rule 1"
    code: "TEST_IMPORT_1"
    enable: true
    warning_level: 30
    error_level: 70
    scope: "TEST"
    description: "First test rule for import testing"
    message: "Test message for rule 1"
    fixes: ["Fix 1", "Fix 2"]
    q1: "SELECT 1 as test_query"
    q2: "SELECT 2 as test_q2"
  - id: 9999
    name: "Test Import Rule 2"
    code: "TEST_IMPORT_2"
    enable: false
    warning_level: 40
    error_level: 80
    scope: "TEST"
    description: "Second test rule for import testing"
    message: "Test message for rule 2"
    fixes: ["Fix A", "Fix B", "Fix C"]
    q1: null
    q2: "SELECT 3 as another_test_query"
"#
}

pub fn get_invalid_yaml_content()  -> &'static str {
    r#"
metadata:
  export_timestamp: "invalid-timestamp"
  invalid_yaml_structure: {
rules:
  - id: "not_a_number"
    name: Missing required fields
"#
}

/// Get invalid rule YAML content (valid YAML structure but invalid rule data)
pub fn get_invalid_rule_yaml_content() -> &'static str {
    r#"
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 1
  format_version: "1.0"
rules:
  - id: 9999
    name: "Invalid Rule Test"
    code: "INVALID_TEST"
    enable: true
    warning_level: -10
    error_level: 200
    scope: "INVALID"
    description: "Test rule with potentially invalid data"
    message: "Test message"
    fixes: []
    q1: "SELECT 'invalid sql syntax FROM"
    q2: null
"#
}

/// Get minimal valid YAML content
pub fn get_minimal_yaml_content() -> &'static str {
    r#"
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 0
  format_version: "1.0"
rules: []
"#
}

/// Get special characters YAML content
pub fn get_special_chars_yaml_content() -> &'static str {
    r#"
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 1
  format_version: "1.0"
rules:
  - id: 9993
    name: "Special Characters Test: <>&\"'`"
    code: "SPECIAL_TEST"
    enable: true
    warning_level: 50
    error_level: 90
    scope: "SPECIAL"
    description: "Test rule with special characters: àáâãäå çñü €£¥"
    message: "Message with quotes: \"double\" and 'single' and `backticks`"
    fixes: ["Fix with <angle brackets>", "Fix with & ampersand"]
    q1: "SELECT 'string with '' embedded quotes' as test"
    q2: "SELECT 'another test' WHERE column = 'value with \"quotes\"'"
"#
}
