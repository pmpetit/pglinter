// Test fixtures for pglinter unit tests
// This module contains common SQL setup and teardown functions for tests

use pgrx::prelude::*;

/// Generic setup function for creating a test rule
pub fn setup_test_rule(code: &str, id: i32, name: &str, enabled: bool) {
    let _ = Spi::run(&format!(
        "DELETE FROM pglinter.rules WHERE code = '{}'",
        code
    ));
    let _ = Spi::run(&format!(
        "INSERT INTO pglinter.rules (id, code, name, enable) VALUES ({}, '{}', '{}', {})",
        id, code, name, enabled
    ));
}

/// Generic cleanup function for removing test rules
pub fn cleanup_test_rule(code: &str) {
    let _ = Spi::run(&format!(
        "DELETE FROM pglinter.rules WHERE code = '{}'",
        code
    ));
}

/// Get rule boolean property from database
pub fn get_rule_bool_property(code: &str, property: &str) -> Option<bool> {
    let query = format!(
        "SELECT {} FROM pglinter.rules WHERE code = '{}'",
        property, code
    );
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
    scope: "TEST"
    description: "First test rule for import testing"
    message: "Test message for rule 1"
    fixes: ["Fix 1", "Fix 2"]
  - id: 9999
    name: "Test Import Rule 2"
    code: "TEST_IMPORT_2"
    enable: false
    scope: "TEST"
    description: "Second test rule for import testing"
    message: "Test message for rule 2"
    fixes: ["Fix A", "Fix B", "Fix C"]
"#
}

pub fn get_invalid_yaml_content() -> &'static str {
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
    scope: "INVALID"
    description: "Test rule with potentially invalid data"
    message: "Test message"
    fixes: []
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
    scope: "SPECIAL"
    description: "Test rule with special characters: àáâãäå çñü €£¥"
    message: "Message with quotes: \"double\" and 'single' and `backticks`"
    fixes: ["Fix with <angle brackets>", "Fix with & ampersand"]
"#
}
