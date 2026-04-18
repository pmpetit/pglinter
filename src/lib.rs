use pgrx::pgrx_macros::extension_sql_file;
use pgrx::prelude::*;

mod execute_rules;
mod manage_rules;

#[cfg(any(test, feature = "pg_test"))]
mod fixtures;

extension_sql_file!("../sql/rules.sql", name = "pglinter", finalize);

::pgrx::pg_module_magic!();

#[pg_extern]
fn hello_pglinter() -> &'static str {
    "Hello, pglinter"
}

#[pg_schema]
mod pglinter {
    use crate::manage_rules;
    use pgrx::prelude::*;

    // Rule management functions
    #[pg_extern(security_definer)]
    fn enable_rule(rule_code: &str) -> Option<bool> {
        match manage_rules::enable_rule(rule_code) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to enable rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn disable_rule(rule_code: &str) -> Option<bool> {
        match manage_rules::disable_rule(rule_code) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to disable rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn show_rules() -> Option<bool> {
        match manage_rules::show_rule_status() {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to show rule status: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn is_rule_enabled(rule_code: &str) -> Option<bool> {
        match manage_rules::is_rule_enabled(rule_code) {
            Ok(enabled) => Some(enabled),
            Err(e) => {
                pgrx::warning!("Failed to check rule status for {}: {}", rule_code, e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn explain_rule(rule_code: &str) -> Option<bool> {
        match manage_rules::explain_rule(rule_code) {
            Ok(explanation) => {
                pgrx::notice!("{}", explanation);
                Some(true)
            }
            Err(e) => {
                pgrx::warning!("Failed to explain rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn enable_all_rules() -> Option<i32> {
        match manage_rules::enable_all_rules() {
            Ok(count) => Some(count as i32),
            Err(e) => {
                pgrx::warning!("Failed to enable all rules: {}", e);
                Some(-1)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn disable_all_rules() -> Option<i32> {
        match manage_rules::disable_all_rules() {
            Ok(count) => Some(count as i32),
            Err(e) => {
                pgrx::warning!("Failed to disable all rules: {}", e);
                Some(-1)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn update_rule_levels(
        rule_code: &str,
        warning_level: Option<i32>,
        error_level: Option<i32>,
    ) -> Option<bool> {
        match manage_rules::update_rule_levels(rule_code, warning_level, error_level) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to update rule levels for {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern(security_definer)]
    fn get_rule_levels(rule_code: &str) -> Option<String> {
        match manage_rules::get_rule_levels(rule_code) {
            Ok((warning, error)) => Some(format!("warning_level={warning}, error_level={error}")),
            Err(e) => {
                pgrx::warning!("Failed to get rule levels for {}: {}", rule_code, e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn show_rule_queries(rule_code: &str) -> Option<String> {
        match manage_rules::show_rule_queries(rule_code) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to show rule queries for {}: {}", rule_code, e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn export_rules_to_yaml() -> Option<String> {
        match manage_rules::export_rules_to_yaml() {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to export: {}", e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn export_rulemessages_to_yaml() -> Option<String> {
        match manage_rules::export_rule_messages_to_yaml() {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to export: {}", e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn export_rules_to_file(file_path: &str) -> Option<String> {
        match manage_rules::export_rules_to_file(file_path) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to export: {}", e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn import_rules_from_yaml(yaml_content: &str) -> Option<String> {
        match manage_rules::import_rules_from_yaml(yaml_content) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to import: {}", e);
                Some(e.to_string())
            }
        }
    }

    #[pg_extern(security_definer)]
    fn import_rules_from_file(file_path: &str) -> Option<String> {
        match manage_rules::import_rules_from_file(file_path) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to import: {}", e);
                Some(e.to_string())
            }
        }
    }

    #[pg_extern(security_definer)]
    fn import_rule_messages_from_yaml(yaml_content: &str) -> Option<String> {
        match manage_rules::import_rule_messages_from_yaml(yaml_content) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to import rule messages: {}", e);
                Some(e.to_string())
            }
        }
    }

    #[pg_extern(security_definer)]
    fn list_rules() -> Option<String> {
        match manage_rules::list_rules() {
            Ok(rules) => {
                if rules.is_empty() {
                    Some("No rules found.".to_string())
                } else {
                    let mut output = String::new();
                    output.push_str("📋 Available Rules:\n");
                    output.push_str(&"=".repeat(60));
                    output.push('\n');

                    for (code, name, enabled) in rules {
                        let status_icon = if enabled { "✅" } else { "❌" };
                        let status_text = if enabled { "ENABLED" } else { "DISABLED" };

                        output.push_str(&format!(
                            "{} [{}] {} - {}\n",
                            status_icon, code, status_text, name
                        ));
                    }

                    output.push_str(&"=".repeat(60));
                    Some(output)
                }
            }
            Err(e) => {
                pgrx::warning!("Failed to list rules: {}", e);
                Some(format!("Error listing rules: {}", e))
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pglinter.get_violations()
        RETURNS TABLE(rule_code TEXT, classid OID, objid OID, objsubid INTEGER, message TEXT)
        AS 'MODULE_PATHNAME', 'get_violations_wrapper'
        LANGUAGE C
        SECURITY DEFINER;
    ")]
    fn get_violations() -> TableIterator<
        'static,
        (
            name!(rule_code, String),
            name!(classid, i32),
            name!(objid, i32),
            name!(objsubid, i32),
            name!(message, String),
        ),
    > {
        use crate::execute_rules::{get_sanitized_message, get_violations};
        let mut rows = Vec::new();
        match get_violations() {
            Ok(violations) => {
                for (rule_code, violations_vec) in violations {
                    for (classid, objid, objsubid) in violations_vec {
                        let message = get_sanitized_message(&rule_code, classid, objid, objsubid);
                        rows.push((rule_code.clone(), classid, objid, objsubid, message));
                    }
                }
            }
            Err(e) => {
                pgrx::warning!("pglinter get_violations failed: {}", e);
            }
        }
        TableIterator::new(rows)
    }
}

//----------------------------------------------------------------------------
// Unit tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixtures;
    use crate::manage_rules;
    use pgrx::prelude::*;

    #[pg_test]
    fn test_hello_pglinter() {
        assert_eq!("Hello, pglinter", crate::hello_pglinter());
    }

    #[pg_test]
    fn test_enable_rule_success() {
        // Test enabling an existing rule
        // Setup disabled test rule using fixture
        fixtures::setup_test_rule("TEST001", 9001, "Test Rule", false, 20, 80);

        // Enable the rule
        let result = manage_rules::enable_rule("TEST001");
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify it's enabled in the database using fixture helper
        let enabled = fixtures::get_rule_bool_property("TEST001", "enable");
        assert_eq!(enabled, Some(true));

        // Cleanup
        fixtures::cleanup_test_rule("TEST001");
    }

    #[pg_test]
    fn test_enable_rule_not_found() {
        // Test enabling a non-existent rule
        let result = manage_rules::enable_rule("NONEXISTENT");
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }

    #[pg_test]
    fn test_disable_rule_success() {
        // Test disabling an existing rule
        // Setup enabled test rule using fixture
        fixtures::setup_test_rule("TEST002", 9002, "Test Rule 2", true, 20, 80);

        // Disable the rule
        let result = manage_rules::disable_rule("TEST002");
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify it's disabled in the database using fixture helper
        let enabled = fixtures::get_rule_bool_property("TEST002", "enable");
        assert_eq!(enabled, Some(false));

        // Cleanup
        fixtures::cleanup_test_rule("TEST002");
    }

    #[pg_test]
    fn test_disable_rule_not_found() {
        // Test disabling a non-existent rule
        let result = manage_rules::disable_rule("NONEXISTENT");
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }

    #[pg_test]
    fn test_is_rule_enabled_true() {
        // Test checking if an enabled rule is enabled
        fixtures::setup_test_rule("TEST003", 9003, "Test Rule 3", true, 20, 80);

        let result = manage_rules::is_rule_enabled("TEST003");
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Cleanup
        fixtures::cleanup_test_rule("TEST003");
    }

    #[pg_test]
    fn test_is_rule_enabled_false() {
        // Test checking if a disabled rule is enabled
        fixtures::setup_test_rule("TEST004", 9004, "Test Rule 4", false, 20, 80);

        let result = manage_rules::is_rule_enabled("TEST004");
        assert!(result.is_ok());
        assert!(!result.unwrap());

        // Cleanup
        fixtures::cleanup_test_rule("TEST004");
    }

    #[pg_test]
    fn test_is_rule_enabled_not_found() {
        // Test checking if a non-existent rule is enabled
        let result = manage_rules::is_rule_enabled("NONEXISTENT");
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }

    #[pg_test]
    fn test_list_rules() {
        // Setup test rules using fixture
        fixtures::setup_test_rule("TEST005", 9005, "Test Rule 5", true, 20, 80);
        fixtures::setup_test_rule("TEST006", 9006, "Test Rule 6", false, 20, 80);

        let result = manage_rules::list_rules();
        assert!(result.is_ok());

        let rules = result.unwrap();
        assert!(!rules.is_empty());

        // Check if our test rules are in the list
        let test005 = rules.iter().find(|(code, _, _)| code == "TEST005");
        assert!(test005.is_some());
        let (_, name, enabled) = test005.unwrap();
        assert_eq!(name, "Test Rule 5");
        assert!(*enabled);

        let test006 = rules.iter().find(|(code, _, _)| code == "TEST006");
        assert!(test006.is_some());
        let (_, name, enabled) = test006.unwrap();
        assert_eq!(name, "Test Rule 6");
        assert!(!(*enabled));

        // Cleanup
        fixtures::cleanup_test_rule("TEST005");
        fixtures::cleanup_test_rule("TEST006");
    }

    #[pg_test]
    fn test_show_rule_status() {
        // Setup test rule using fixture
        fixtures::setup_test_rule("TEST007", 9007, "Test Rule 7", false, 20, 80);

        let result = manage_rules::show_rule_status();
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Cleanup test rule using fixture
        fixtures::cleanup_test_rule("TEST007");
    }

    #[pg_test]
    fn test_explain_rule_success() {
        // Setup test rule with complete information using fixture
        fixtures::setup_test_rule("TEST008", 9008, "Test Rule 8", true, 20, 80);

        let result = manage_rules::explain_rule("TEST008");
        assert!(result.is_ok());

        let explanation = result.unwrap();
        assert!(explanation.contains("TEST008"));
        assert!(explanation.contains("Test Rule 8"));

        // Cleanup
        fixtures::cleanup_test_rule("TEST008");
    }

    #[pg_test]
    fn test_explain_rule_not_found() {
        let result = manage_rules::explain_rule("NONEXISTENT");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[pg_test]
    fn test_explain_rule_with_fixes() {
        // Setup test rule with fixes data to test the fix list formatting (lines 220-226)
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_FIXES'");

        // Insert rule with multiple fixes including Some and None values to test the filtering
        let _ = Spi::run("
            INSERT INTO pglinter.rules (id, code, name, enable, description, scope, message, fixes)
            VALUES (
                9999,
                'TEST_FIXES',
                'Test Rule With Fixes',
                true,
                'This rule tests the fix list formatting',
                'TABLE',
                'Test message for fixes',
                ARRAY['Add a primary key to the table', 'Create an index on frequently queried columns', 'Consider partitioning large tables']
            )
        ");

        // Test the explain_rule function with fixes
        let result = manage_rules::explain_rule("TEST_FIXES");
        assert!(result.is_ok());

        let explanation = result.unwrap();

        // Verify basic rule information is present
        assert!(explanation.contains("TEST_FIXES"));
        assert!(explanation.contains("Test Rule With Fixes"));
        assert!(explanation.contains("This rule tests the fix list formatting"));

        // Test the fix list formatting (lines 220-226 in manage_rules.rs)
        // The fixes should be formatted as a numbered list with proper indentation
        assert!(explanation.contains("🔧 How to Fix:"));
        assert!(explanation.contains("   1. Add a primary key to the table"));
        assert!(explanation.contains("   2. Create an index on frequently queried columns"));
        assert!(explanation.contains("   3. Consider partitioning large tables"));

        // Verify the formatting is correct (numbered list with spaces)
        let fix_section_start = explanation.find("🔧 How to Fix:").unwrap();
        let fix_section = &explanation[fix_section_start..];

        // Check that each fix is on its own line and properly numbered
        assert!(
            fix_section.contains("   1. "),
            "First fix should be numbered as '   1. '"
        );
        assert!(
            fix_section.contains("   2. "),
            "Second fix should be numbered as '   2. '"
        );
        assert!(
            fix_section.contains("   3. "),
            "Third fix should be numbered as '   3. '"
        );

        // Cleanup
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_FIXES'");
    }

    #[pg_test]
    fn test_explain_rule_with_empty_fixes() {
        // Test the case where fixes array is empty (should show "No specific fixes available.")
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_NO_FIXES'");

        let _ = Spi::run(
            "
            INSERT INTO pglinter.rules (id, code, name, enable, description, scope, message, fixes)
            VALUES (
                9998,
                'TEST_NO_FIXES',
                'Test Rule Without Fixes',
                true,
                'This rule has no fixes',
                'BASE',
                'Test message without fixes',
                ARRAY[]::text[]
            )
        ",
        );

        let result = manage_rules::explain_rule("TEST_NO_FIXES");
        assert!(result.is_ok());

        let explanation = result.unwrap();

        // Should contain the default message when no fixes are available
        assert!(explanation.contains("No specific fixes available."));
        assert!(
            !explanation.contains("   1. "),
            "Should not contain numbered fixes"
        );

        // Cleanup
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_NO_FIXES'");
    }

    #[pg_test]
    fn test_explain_rule_with_mixed_fixes() {
        // Test the case where the fixes array has a mix of valid and NULL values
        // This tests the NULL filtering logic in the explain_rule function
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_MIXED_FIXES'");

        // Insert rule and then update with mixed NULL and non-NULL fixes
        let _ = Spi::run(
            "
            INSERT INTO pglinter.rules (id, code, name, enable, description, scope, message)
            VALUES (
                9997,
                'TEST_MIXED_FIXES',
                'Test Rule With Mixed Fixes',
                true,
                'This rule tests NULL filtering in fixes',
                'TABLE',
                'Test message for mixed fixes'
            )
        ",
        );

        // Update with an array that contains NULLs - this simulates real-world data
        let _ = Spi::run("
            UPDATE pglinter.rules
            SET fixes = ARRAY['Add primary key', NULL::text, 'Create indexes', NULL::text, 'Optimize queries']::text[]
            WHERE code = 'TEST_MIXED_FIXES'
        ");

        let result = manage_rules::explain_rule("TEST_MIXED_FIXES");
        assert!(result.is_ok());

        let explanation = result.unwrap();

        // Should show the fixes section
        assert!(explanation.contains("🔧 How to Fix:"));

        // The NULL filtering code should skip NULL entries
        // Based on the current implementation using enumerate(),
        // we expect the original array indices to be used for numbering
        assert!(explanation.contains("   1. Add primary key")); // Index 0 + 1 = 1
        assert!(explanation.contains("   3. Create indexes")); // Index 2 + 1 = 3 (skips NULL at index 1)
        assert!(explanation.contains("   5. Optimize queries")); // Index 4 + 1 = 5 (skips NULL at index 3)

        // Should not have entries for the NULL positions
        assert!(!explanation.contains("   2. ")); // Index 1 was NULL
        assert!(!explanation.contains("   4. ")); // Index 3 was NULL

        // Cleanup
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_MIXED_FIXES'");
    }

    #[pg_test]
    fn test_rule_toggle_workflow() {
        // Test a complete workflow: enable -> check -> disable -> check
        fixtures::setup_test_rule("TEST009", 9009, "Test Rule 9", false, 20, 80);

        // Initially disabled
        let status = manage_rules::is_rule_enabled("TEST009").unwrap();
        assert!(!status);

        // Enable the rule
        let enable_result = manage_rules::enable_rule("TEST009").unwrap();
        assert!(enable_result);

        // Should now be enabled
        let status = manage_rules::is_rule_enabled("TEST009").unwrap();
        assert!(status);

        // Disable the rule
        let disable_result = manage_rules::disable_rule("TEST009").unwrap();
        assert!(disable_result);

        // Should now be disabled again
        let status = manage_rules::is_rule_enabled("TEST009").unwrap();
        assert!(!status);

        // Cleanup
        fixtures::cleanup_test_rule("TEST009");
    }

    #[pg_test]
    fn test_enable_all_rules() {
        // Set up test rules with mixed enabled/disabled states using fixtures
        fixtures::setup_test_rule("TEST010", 9010, "Test Rule 10", false, 20, 80);
        fixtures::setup_test_rule("TEST011", 9011, "Test Rule 11", false, 20, 80);
        fixtures::setup_test_rule("TEST012", 9012, "Test Rule 12", true, 20, 80);

        // Count currently disabled rules before our operation
        let disabled_count_before =
            Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules WHERE enable = false")
                .unwrap()
                .unwrap_or(0);

        // Enable all rules
        let result = manage_rules::enable_all_rules();
        assert!(result.is_ok());
        let count = result.unwrap();
        assert_eq!(count as i64, disabled_count_before); // Should have enabled all previously disabled rules

        // Verify our test rules are now enabled using fixture helpers
        let test010_enabled = fixtures::get_rule_bool_property("TEST010", "enable");
        assert_eq!(test010_enabled, Some(true));

        let test011_enabled = fixtures::get_rule_bool_property("TEST011", "enable");
        assert_eq!(test011_enabled, Some(true));

        let test012_enabled = fixtures::get_rule_bool_property("TEST012", "enable");
        assert_eq!(test012_enabled, Some(true));

        // Test when all rules are already enabled
        let result2 = manage_rules::enable_all_rules();
        assert!(result2.is_ok());
        let count2 = result2.unwrap();
        assert_eq!(count2, 0); // Should have enabled 0 rules

        // Cleanup
        fixtures::cleanup_test_rule("TEST010");
        fixtures::cleanup_test_rule("TEST011");
        fixtures::cleanup_test_rule("TEST012");
    }

    #[pg_test]
    fn test_disable_all_rules() {
        // Set up test rules with mixed enabled/disabled states using fixtures
        fixtures::setup_test_rule("TEST013", 9013, "Test Rule 13", true, 20, 80);
        fixtures::setup_test_rule("TEST014", 9014, "Test Rule 14", true, 20, 80);
        fixtures::setup_test_rule("TEST015", 9015, "Test Rule 15", false, 20, 80);

        // Count currently enabled rules before our operation
        let enabled_count_before =
            Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules WHERE enable = true")
                .unwrap()
                .unwrap_or(0);

        // Disable all rules
        let result = manage_rules::disable_all_rules();
        assert!(result.is_ok());
        let count = result.unwrap();
        assert_eq!(count as i64, enabled_count_before); // Should have disabled all previously enabled rules

        // Verify all test rules are now disabled using fixture helpers
        let test013_enabled = fixtures::get_rule_bool_property("TEST013", "enable");
        assert_eq!(test013_enabled, Some(false));

        let test014_enabled = fixtures::get_rule_bool_property("TEST014", "enable");
        assert_eq!(test014_enabled, Some(false));

        let test015_enabled = fixtures::get_rule_bool_property("TEST015", "enable");
        assert_eq!(test015_enabled, Some(false));

        // Test when all rules are already disabled
        let result2 = manage_rules::disable_all_rules();
        assert!(result2.is_ok());
        let count2 = result2.unwrap();
        assert_eq!(count2, 0); // Should have disabled 0 rules

        // Cleanup
        fixtures::cleanup_test_rule("TEST013");
        fixtures::cleanup_test_rule("TEST014");
        fixtures::cleanup_test_rule("TEST015");
    }

    #[pg_test]
    fn test_enable_disable_all_workflow() {
        // Test the complete workflow of enabling and disabling all rules
        fixtures::setup_test_rule("TEST016", 9016, "Test Rule 16", true, 20, 80);
        fixtures::setup_test_rule("TEST017", 9017, "Test Rule 17", false, 20, 80);

        // Count rules before operations
        let enabled_count_before =
            Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules WHERE enable = true")
                .unwrap()
                .unwrap_or(0);

        // Disable all rules first
        let disable_result = manage_rules::disable_all_rules();
        assert!(disable_result.is_ok());
        assert_eq!(disable_result.unwrap() as i64, enabled_count_before); // Should have disabled all enabled rules

        // Verify both test rules are disabled using fixture helpers
        let test016_enabled = fixtures::get_rule_bool_property("TEST016", "enable");
        assert_eq!(test016_enabled, Some(false));
        let test017_enabled = fixtures::get_rule_bool_property("TEST017", "enable");
        assert_eq!(test017_enabled, Some(false));

        // Count total rules (should all be disabled now)
        let total_rules = Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules")
            .unwrap()
            .unwrap_or(0);

        // Enable all rules
        let enable_result = manage_rules::enable_all_rules();
        assert!(enable_result.is_ok());
        assert_eq!(enable_result.unwrap() as i64, total_rules); // Should have enabled all rules

        // Verify both are enabled using fixture helpers
        let test016_enabled = fixtures::get_rule_bool_property("TEST016", "enable");
        assert_eq!(test016_enabled, Some(true));
        let test017_enabled = fixtures::get_rule_bool_property("TEST017", "enable");
        assert_eq!(test017_enabled, Some(true));

        // Cleanup
        fixtures::cleanup_test_rule("TEST016");
        fixtures::cleanup_test_rule("TEST017");
    }

    #[pg_test]
    fn test_update_rule_levels() {
        // Setup: ensure test rule exists
        fixtures::setup_test_rule("TEST_SQL_LEVELS", 9998, "Test SQL Levels Rule", true, 5, 10);
        // Test SQL interface for getting rule levels
        let levels =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('TEST_SQL_LEVELS')").unwrap();
        assert!(levels.is_some());
        let levels_str = levels.unwrap();
        assert_eq!(levels_str, "warning_level=5, error_level=10");

        // Test SQL interface for updating rule levels (both)
        let result =
            Spi::get_one::<bool>("SELECT pglinter.update_rule_levels('TEST_SQL_LEVELS', 15, 25)")
                .unwrap();
        assert!(result.is_some());
        assert!(result.unwrap());

        // Verify the update via SQL
        let updated_levels =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('TEST_SQL_LEVELS')").unwrap();
        assert!(updated_levels.is_some());
        assert_eq!(updated_levels.unwrap(), "warning_level=15, error_level=25");

        // Test SQL interface for updating only warning level (using NULL for error_level)
        let result2 =
            Spi::get_one::<bool>("SELECT pglinter.update_rule_levels('TEST_SQL_LEVELS', 50, NULL)")
                .unwrap();
        assert!(result2.is_some());
        assert!(result2.unwrap());

        // Verify only warning level changed
        let updated_levels2 =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('TEST_SQL_LEVELS')").unwrap();
        assert!(updated_levels2.is_some());
        assert_eq!(updated_levels2.unwrap(), "warning_level=50, error_level=25");

        // Test SQL interface for updating only error level
        let result3 =
            Spi::get_one::<bool>("SELECT pglinter.update_rule_levels('TEST_SQL_LEVELS', NULL, 75)")
                .unwrap();
        assert!(result3.is_some());
        assert!(result3.unwrap());

        // Verify only error level changed
        let updated_levels3 =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('TEST_SQL_LEVELS')").unwrap();
        assert!(updated_levels3.is_some());
        assert_eq!(updated_levels3.unwrap(), "warning_level=50, error_level=75");

        // Clean up
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_SQL_LEVELS'");
    }

    #[pg_test]
    fn test_update_rule_levels_exceptions() {
        // Test 1: Test with non-existent rule (should return false, not throw exception)
        let result_nonexistent =
            manage_rules::update_rule_levels("NONEXISTENT_RULE", Some(10), Some(20));
        assert!(result_nonexistent.is_ok());
        assert_eq!(result_nonexistent.unwrap(), false); // Should return false for non-existent rule

        // Test 2: Test SQL interface with non-existent rule
        let sql_result_nonexistent =
            Spi::get_one::<bool>("SELECT pglinter.update_rule_levels('NONEXISTENT_RULE', 10, 20)")
                .unwrap();
        assert!(sql_result_nonexistent.is_some());
        assert_eq!(sql_result_nonexistent.unwrap(), false);

        // Test 3: Setup a rule and test valid updates to ensure basic functionality works
        fixtures::setup_test_rule(
            "TEST_EXCEPTION_RULE",
            9997,
            "Test Exception Rule",
            true,
            5,
            10,
        );

        // Test valid update first
        let result_valid =
            manage_rules::update_rule_levels("TEST_EXCEPTION_RULE", Some(20), Some(40));
        assert!(result_valid.is_ok());
        assert_eq!(result_valid.unwrap(), true);

        // Verify the update worked
        let levels = manage_rules::get_rule_levels("TEST_EXCEPTION_RULE");
        assert!(levels.is_ok());
        let (warning, error) = levels.unwrap();
        assert_eq!(warning, 20);
        assert_eq!(error, 40);

        // Test 4: Test with extreme values (PostgreSQL integer limits)
        // This should work within PostgreSQL's integer range (-2147483648 to 2147483647)
        let result_extreme = manage_rules::update_rule_levels(
            "TEST_EXCEPTION_RULE",
            Some(2147483647),
            Some(-2147483648),
        );
        assert!(result_extreme.is_ok());
        assert_eq!(result_extreme.unwrap(), true);

        // Test 5: Test updating with NULL values (should keep current values)
        let result_null_both = manage_rules::update_rule_levels("TEST_EXCEPTION_RULE", None, None);
        assert!(result_null_both.is_ok());
        assert_eq!(result_null_both.unwrap(), true);

        // Verify values remained the same (extreme values from previous test)
        let levels_after_null = manage_rules::get_rule_levels("TEST_EXCEPTION_RULE");
        assert!(levels_after_null.is_ok());
        let (warning_after, error_after) = levels_after_null.unwrap();
        assert_eq!(warning_after, 2147483647);
        assert_eq!(error_after, -2147483648);

        // Test 6: Test with mixed NULL and valid values
        let result_mixed = manage_rules::update_rule_levels("TEST_EXCEPTION_RULE", Some(100), None);
        assert!(result_mixed.is_ok());
        assert_eq!(result_mixed.unwrap(), true);

        // Verify warning changed but error remained
        let levels_mixed = manage_rules::get_rule_levels("TEST_EXCEPTION_RULE");
        assert!(levels_mixed.is_ok());
        let (warning_mixed, error_mixed) = levels_mixed.unwrap();
        assert_eq!(warning_mixed, 100);
        assert_eq!(error_mixed, -2147483648); // Should remain unchanged

        // Test 7: Test the SQL interface with extreme values to ensure it handles the same edge cases
        let sql_result_extreme = Spi::get_one::<bool>(
            "SELECT pglinter.update_rule_levels('TEST_EXCEPTION_RULE', -2147483648, 2147483647)",
        )
        .unwrap();
        assert!(sql_result_extreme.is_some());
        assert_eq!(sql_result_extreme.unwrap(), true);

        // Test 8: Test error handling by attempting to corrupt the rule and then update
        // This simulates scenarios where database constraints or data integrity issues might occur

        // First, let's create a scenario with a rule that has unusual data
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_CORRUPTED_RULE'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable, warning_level, error_level, scope) VALUES (9996, 'TEST_CORRUPTED_RULE', 'Test Corrupted Rule', true, NULL, NULL, 'BASE')");

        // Update rule with NULL current values - function should handle this gracefully
        let result_null_current =
            manage_rules::update_rule_levels("TEST_CORRUPTED_RULE", Some(10), Some(20));
        assert!(result_null_current.is_ok());
        assert_eq!(result_null_current.unwrap(), true);

        // Verify it worked
        let levels_null_current = manage_rules::get_rule_levels("TEST_CORRUPTED_RULE");
        assert!(levels_null_current.is_ok());
        let (warning_null, error_null) = levels_null_current.unwrap();
        assert_eq!(warning_null, 10);
        assert_eq!(error_null, 20);

        // Clean up test rules
        fixtures::cleanup_test_rule("TEST_EXCEPTION_RULE");
        fixtures::cleanup_test_rule("TEST_CORRUPTED_RULE");
    }

    #[pg_test]
    fn test_show_rule_queries() {
        // Setup: create a test rule with queries
        fixtures::cleanup_test_rule("TEST_SHOW_QUERIES");
        let q1 = "SELECT count(*) FROM pg_stat_user_tables";
        let q2 = "SELECT count(*) FROM pg_stat_user_tables WHERE n_tup_ins = 0";

        let _ = Spi::run(&format!(
            "INSERT INTO pglinter.rules (id, code, name, enable, q1, q2) VALUES (9995, 'TEST_SHOW_QUERIES', 'Test Show Queries Rule', true, '{}', '{}')",
            q1, q2
        ));

        // Test showing rule queries for existing rule
        let result = manage_rules::show_rule_queries("TEST_SHOW_QUERIES");
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Test showing rule queries for rule with NULL queries
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_NULL_QUERIES'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable, q1, q2) VALUES (9994, 'TEST_NULL_QUERIES', 'Test Null Queries Rule', true, NULL, NULL)");

        let result_null = manage_rules::show_rule_queries("TEST_NULL_QUERIES");
        assert!(result_null.is_ok());
        assert!(result_null.unwrap());

        // Test showing rule queries for non-existent rule
        let result_not_found = manage_rules::show_rule_queries("NONEXISTENT_RULE");
        assert!(result_not_found.is_ok());
        assert!(!result_not_found.unwrap()); // Should return false

        // Clean up
        fixtures::cleanup_test_rule("TEST_SHOW_QUERIES");
        fixtures::cleanup_test_rule("TEST_NULL_QUERIES");
    }

    #[pg_test]
    fn test_import_rules_from_file() {
        // Test 1: Test with non-existent file
        let result_not_found =
            manage_rules::import_rules_from_file("/nonexistent/path/to/file.yaml");
        assert!(result_not_found.is_err());
        assert!(result_not_found.unwrap_err().contains("File read error"));

        // Test 2: Create a temporary YAML file with test rules
        let temp_yaml_content = fixtures::get_valid_yaml_content();

        // Write test YAML to a temporary file
        let temp_file_path = "/tmp/pglinter_test_rules.yaml";
        std::fs::write(temp_file_path, temp_yaml_content).expect("Failed to write test file");

        // Clean up any existing test rules
        fixtures::cleanup_test_rule("TEST_IMPORT_1");
        fixtures::cleanup_test_rule("TEST_IMPORT_2");

        // Test 3: Import from valid YAML file
        let result_success = manage_rules::import_rules_from_file(temp_file_path);
        assert!(result_success.is_ok());
        let success_msg = result_success.unwrap();
        assert!(success_msg.contains("Import completed"));
        assert!(success_msg.contains("new rules"));

        // Test 4: Verify the imported rules exist in the database
        let rule1_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'TEST_IMPORT_1')",
        )
        .unwrap();
        assert!(rule1_exists.unwrap());

        let rule2_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'TEST_IMPORT_2')",
        )
        .unwrap();
        assert!(rule2_exists.unwrap());

        // Test 5: Verify rule1 properties
        let rule1_name =
            Spi::get_one::<String>("SELECT name FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'")
                .unwrap();
        assert_eq!(rule1_name.unwrap(), "Test Import Rule 1");

        let rule1_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'")
                .unwrap();
        assert!(rule1_enabled.unwrap());

        let rule1_warning = Spi::get_one::<i32>(
            "SELECT warning_level FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'",
        )
        .unwrap();
        assert_eq!(rule1_warning.unwrap(), 30);

        // Test 6: Verify rule2 properties
        let rule2_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'")
                .unwrap();
        assert!(!rule2_enabled.unwrap()); // Should be false

        let rule2_error = Spi::get_one::<i32>(
            "SELECT error_level FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'",
        )
        .unwrap();
        assert_eq!(rule2_error.unwrap(), 80);

        // Test 7: Test updating existing rules (import again)
        let result_update = manage_rules::import_rules_from_file(temp_file_path);
        assert!(result_update.is_ok());
        let update_msg = result_update.unwrap();
        assert!(update_msg.contains("updated rules"));

        // Test 8: Test with invalid YAML content
        let invalid_yaml_content = fixtures::get_invalid_yaml_content();

        let invalid_file_path = "/tmp/pglinter_invalid_test.yaml";
        std::fs::write(invalid_file_path, invalid_yaml_content)
            .expect("Failed to write invalid test file");

        let result_invalid = manage_rules::import_rules_from_file(invalid_file_path);
        assert!(result_invalid.is_err());
        assert!(result_invalid.unwrap_err().contains("YAML parsing error"));

        // Test 9: Test with empty file
        let empty_file_path = "/tmp/pglinter_empty_test.yaml";
        std::fs::write(empty_file_path, "").expect("Failed to write empty test file");

        let result_empty = manage_rules::import_rules_from_file(empty_file_path);
        assert!(result_empty.is_err());
        assert!(result_empty.unwrap_err().contains("YAML parsing error"));

        // Test 10: Test with file that exists but has wrong permissions (if supported on system)
        let protected_file_path = "/tmp/pglinter_protected_test.yaml";
        std::fs::write(protected_file_path, temp_yaml_content)
            .expect("Failed to write protected test file");

        // Try to make file unreadable (this might not work on all systems)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(protected_file_path)
                .unwrap()
                .permissions();
            perms.set_mode(0o000); // No permissions
            let _ = std::fs::set_permissions(protected_file_path, perms);

            // This should fail with permission denied (though behavior may vary)
            let result_protected = manage_rules::import_rules_from_file(protected_file_path);
            // We expect either success (if permissions aren't enforced) or a file read error
            if result_protected.is_err() {
                assert!(result_protected.unwrap_err().contains("File read error"));
            }
        }

        // Clean up test files and database records
        let _ = std::fs::remove_file(temp_file_path);
        let _ = std::fs::remove_file(invalid_file_path);
        let _ = std::fs::remove_file(empty_file_path);
        #[cfg(unix)]
        {
            // Restore permissions before removing
            use std::os::unix::fs::PermissionsExt;
            if let Ok(metadata) = std::fs::metadata(protected_file_path) {
                let mut perms = metadata.permissions();
                perms.set_mode(0o644);
                let _ = std::fs::set_permissions(protected_file_path, perms);
            }
            let _ = std::fs::remove_file(protected_file_path);
        }

        fixtures::cleanup_test_rule("TEST_IMPORT_1");
        fixtures::cleanup_test_rule("TEST_IMPORT_2");
    }

    #[pg_test]
    fn test_import_rules() {
        // Test 1: Test with valid YAML content
        let valid_yaml_content = fixtures::get_valid_yaml_content();

        // Clean up any existing test rules
        fixtures::cleanup_test_rule("TEST_IMPORT_1");
        fixtures::cleanup_test_rule("TEST_IMPORT_2");

        // Test 2: Import from valid YAML content
        let result_success = manage_rules::import_rules_from_yaml(valid_yaml_content);
        assert!(result_success.is_ok());
        let success_msg = result_success.unwrap();
        assert!(success_msg.contains("Import completed"));
        print!("{}", success_msg);
        assert!(success_msg.contains("2 new rules"));

        let yaml_test_3_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'TEST_IMPORT_1')",
        )
        .unwrap();
        assert!(yaml_test_3_exists.unwrap());

        // Test 4: Verify specific rule properties for TEST_IMPORT_1
        let rule1_name =
            Spi::get_one::<String>("SELECT name FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'")
                .unwrap();
        assert_eq!(rule1_name.unwrap(), "Test Import Rule 1");

        let rule1_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'")
                .unwrap();
        assert!(rule1_enabled.unwrap());

        let rule1_warning = Spi::get_one::<i32>(
            "SELECT warning_level FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'",
        )
        .unwrap();
        assert_eq!(rule1_warning.unwrap(), 30);

        let rule1_error = Spi::get_one::<i32>(
            "SELECT error_level FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'",
        )
        .unwrap();
        assert_eq!(rule1_error.unwrap(), 70);

        // Test 5: Verify TEST_IMPORT_2 properties (disabled, null q1)
        let rule2_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'")
                .unwrap();
        assert!(!rule2_enabled.unwrap());

        let rule2_q1_is_null = Spi::get_one::<bool>(
            "SELECT q1 IS NULL FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'",
        )
        .unwrap();
        assert!(rule2_q1_is_null.unwrap());

        let rule2_q2_is_null = Spi::get_one::<bool>(
            "SELECT q2 IS NULL FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'",
        )
        .unwrap();
        assert!(!rule2_q2_is_null.unwrap()); // Should not be null

        // Test 7: Re-import same YAML to test updates
        let result_update = manage_rules::import_rules_from_yaml(valid_yaml_content);
        assert!(result_update.is_ok());
        let update_msg = result_update.unwrap();
        assert!(update_msg.contains("2 updated rules"));
        assert!(update_msg.contains("0 new rules"));

        // Test 8: Test with invalid YAML structure
        let invalid_yaml_content = fixtures::get_invalid_yaml_content();
        let result_invalid = manage_rules::import_rules_from_yaml(invalid_yaml_content);
        assert!(result_invalid.is_err());
        assert!(result_invalid.unwrap_err().contains("YAML parsing error"));

        // Test 9: Test with valid YAML but invalid rule data
        let invalid_rule_yaml = fixtures::get_invalid_rule_yaml_content();

        let result_invalid_rule = manage_rules::import_rules_from_yaml(invalid_rule_yaml);
        // This should succeed from YAML parsing perspective, even if SQL is invalid
        assert!(result_invalid_rule.is_ok());

        // Test 10: Test with empty YAML content
        let empty_yaml = "";
        let result_empty = manage_rules::import_rules_from_yaml(empty_yaml);
        assert!(result_empty.is_err());
        assert!(result_empty.unwrap_err().contains("YAML parsing error"));

        // Test 11: Test with minimal valid YAML
        let minimal_yaml = fixtures::get_minimal_yaml_content();

        let result_minimal = manage_rules::import_rules_from_yaml(minimal_yaml);
        assert!(result_minimal.is_ok());
        let minimal_msg = result_minimal.unwrap();
        assert!(minimal_msg.contains("0 new rules, 0 updated rules"));

        // Test 12: Test with rule containing special characters in strings
        let special_chars_yaml = fixtures::get_special_chars_yaml_content();

        let result_special = manage_rules::import_rules_from_yaml(special_chars_yaml);
        assert!(result_special.is_ok());

        // Verify the special characters are preserved
        let special_name =
            Spi::get_one::<String>("SELECT name FROM pglinter.rules WHERE code = 'SPECIAL_TEST'")
                .unwrap();
        assert!(special_name.unwrap().contains("<>&\"'`"));

        // Clean up all test rules
        fixtures::cleanup_test_rule("TEST_IMPORT_1");
        fixtures::cleanup_test_rule("TEST_IMPORT_2");
        fixtures::cleanup_test_rule("INVALID_TEST");
        fixtures::cleanup_test_rule("SPECIAL_TEST");
    }

    #[pg_test]
    fn test_export_rules_to_yaml() {
        // Setup test rules with different configurations
        fixtures::setup_test_rule("EXPORT_TEST_1", 9993, "Export Test Rule 1", true, 10, 50);
        fixtures::setup_test_rule("EXPORT_TEST_2", 9992, "Export Test Rule 2", false, 20, 60);

        // Test export_rules_to_yaml function
        let result = manage_rules::export_rules_to_yaml();
        assert!(result.is_ok());
        let yaml_output = result.unwrap();

        // Verify YAML output contains our test rules
        assert!(yaml_output.contains("EXPORT_TEST_1"));
        assert!(yaml_output.contains("EXPORT_TEST_2"));
        assert!(yaml_output.contains("Export Test Rule 1"));
        assert!(yaml_output.contains("Export Test Rule 2"));
        assert!(yaml_output.contains("metadata:"));
        assert!(yaml_output.contains("export_timestamp:"));
        assert!(yaml_output.contains("total_rules:"));
        assert!(yaml_output.contains("format_version:"));
        assert!(yaml_output.contains("rules:"));

        // Test via SQL interface
        let sql_result = Spi::get_one::<String>("SELECT pglinter.export_rules_to_yaml()").unwrap();
        assert!(sql_result.is_some());
        let sql_yaml = sql_result.unwrap();
        assert!(sql_yaml.contains("EXPORT_TEST_1"));
        assert!(sql_yaml.contains("EXPORT_TEST_2"));

        // Cleanup
        fixtures::cleanup_test_rule("EXPORT_TEST_1");
        fixtures::cleanup_test_rule("EXPORT_TEST_2");
    }

    #[pg_test]
    fn test_export_rules_to_file() {
        // Setup test rules
        fixtures::setup_test_rule("FILE_EXPORT_1", 9991, "File Export Test Rule", true, 15, 75);

        // Test 1: Export to valid file path
        let export_file_path = "/tmp/pglinter_export_test.yaml";
        let result = manage_rules::export_rules_to_file(export_file_path);
        assert!(result.is_ok());
        let success_msg = result.unwrap();
        assert!(success_msg.contains("Rules exported successfully"));
        assert!(success_msg.contains(export_file_path));

        // Verify file was created and contains expected content
        let file_content =
            std::fs::read_to_string(export_file_path).expect("Failed to read exported file");
        assert!(file_content.contains("FILE_EXPORT_1"));
        assert!(file_content.contains("File Export Test Rule"));
        assert!(file_content.contains("metadata:"));
        assert!(file_content.contains("rules:"));

        // Test 2: Test SQL interface
        let temp_file_path_2 = "/tmp/pglinter_sql_export_test.yaml";
        let sql_result = Spi::get_one::<String>(&format!(
            "SELECT pglinter.export_rules_to_file('{}')",
            temp_file_path_2
        ))
        .unwrap();
        assert!(sql_result.is_some());
        let sql_success_msg = sql_result.unwrap();
        assert!(sql_success_msg.contains("Rules exported successfully"));

        // Verify SQL export file
        let sql_file_content =
            std::fs::read_to_string(temp_file_path_2).expect("Failed to read SQL exported file");
        assert!(sql_file_content.contains("FILE_EXPORT_1"));

        // Test 3: Test with invalid/protected file path (only test if we can create the directory structure)
        let invalid_path = "/tmp/nonexistent_dir/test.yaml";
        let result_invalid = manage_rules::export_rules_to_file(invalid_path);
        assert!(result_invalid.is_err());
        assert!(result_invalid.unwrap_err().contains("File write error"));

        // Test 4: Test with empty filename
        let result_empty = manage_rules::export_rules_to_file("");
        assert!(result_empty.is_err());
        assert!(result_empty.unwrap_err().contains("File write error"));

        // Test 5: Test with directory path (should fail)
        let result_dir = manage_rules::export_rules_to_file("/tmp");
        assert!(result_dir.is_err());
        assert!(result_dir.unwrap_err().contains("File write error"));

        // Cleanup files and test rules
        let _ = std::fs::remove_file(export_file_path);
        let _ = std::fs::remove_file(temp_file_path_2);
        fixtures::cleanup_test_rule("FILE_EXPORT_1");
    }

    #[pg_test]
    fn test_get_rule_levels() {
        // Setup test rule with specific levels
        fixtures::setup_test_rule(
            "GET_LEVELS_TEST",
            9990,
            "Get Levels Test Rule",
            true,
            25,
            85,
        );

        // Test 1: Get levels for existing rule
        let result = manage_rules::get_rule_levels("GET_LEVELS_TEST");
        assert!(result.is_ok());
        let (warning, error) = result.unwrap();
        assert_eq!(warning, 25);
        assert_eq!(error, 85);

        // Test 2: Test via SQL interface
        let sql_result =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('GET_LEVELS_TEST')").unwrap();
        assert!(sql_result.is_some());
        let levels_str = sql_result.unwrap();
        assert_eq!(levels_str, "warning_level=25, error_level=85");

        // Test 3: Get levels for non-existent rule (returns default values, not error)
        let result_nonexistent = manage_rules::get_rule_levels("NONEXISTENT_LEVELS");
        assert!(result_nonexistent.is_ok());
        let (warning_default, error_default) = result_nonexistent.unwrap();
        assert_eq!(warning_default, 50); // Default warning level
        assert_eq!(error_default, 90); // Default error level

        // Test 4: Test SQL interface with non-existent rule
        let sql_result_nonexistent =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('NONEXISTENT_LEVELS')")
                .unwrap();
        assert!(sql_result_nonexistent.is_some()); // Should return default values, not NULL
        let nonexistent_levels_str = sql_result_nonexistent.unwrap();
        assert_eq!(nonexistent_levels_str, "warning_level=50, error_level=90");

        // Test 5: Test with rule that has NULL levels
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'NULL_LEVELS_TEST'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable, warning_level, error_level) VALUES (9989, 'NULL_LEVELS_TEST', 'Null Levels Test', true, NULL, NULL)");

        let result_null = manage_rules::get_rule_levels("NULL_LEVELS_TEST");
        assert!(result_null.is_ok());
        let (warning_null, error_null) = result_null.unwrap();
        assert_eq!(warning_null, 0); // Should default to 0 for NULL values
        assert_eq!(error_null, 0);

        // Test 6: Test SQL interface with NULL levels rule
        let sql_result_null =
            Spi::get_one::<String>("SELECT pglinter.get_rule_levels('NULL_LEVELS_TEST')").unwrap();
        assert!(sql_result_null.is_some());
        let null_levels_str = sql_result_null.unwrap();
        assert_eq!(null_levels_str, "warning_level=0, error_level=0");

        // Cleanup
        fixtures::cleanup_test_rule("GET_LEVELS_TEST");
        fixtures::cleanup_test_rule("NULL_LEVELS_TEST");
    }

    #[pg_test]
    fn test_list_rules_error_handling() {
        // Test list_rules function with database in various states

        // Test 1: Normal operation (covered in existing test_list_rules)
        fixtures::setup_test_rule(
            "LIST_ERROR_TEST",
            9988,
            "List Error Test Rule",
            true,
            10,
            20,
        );

        let result = manage_rules::list_rules();
        assert!(result.is_ok());
        let rules = result.unwrap();
        assert!(!rules.is_empty());

        // Find our test rule in the list
        let test_rule = rules.iter().find(|(code, _, _)| code == "LIST_ERROR_TEST");
        assert!(test_rule.is_some());
        let (_, name, enabled) = test_rule.unwrap();
        assert_eq!(name, "List Error Test Rule");
        assert!(*enabled);

        // Test 2: Test with rule that has unusual data
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'UNUSUAL_DATA_RULE'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9987, 'UNUSUAL_DATA_RULE', '', false)");

        let result_unusual = manage_rules::list_rules();
        assert!(result_unusual.is_ok());
        let rules_unusual = result_unusual.unwrap();

        let unusual_rule = rules_unusual
            .iter()
            .find(|(code, _, _)| code == "UNUSUAL_DATA_RULE");
        assert!(unusual_rule.is_some());
        let (_, name_unusual, enabled_unusual) = unusual_rule.unwrap();
        assert_eq!(name_unusual, ""); // Empty name should be handled
        assert!(!*enabled_unusual);

        // Cleanup
        fixtures::cleanup_test_rule("LIST_ERROR_TEST");
        fixtures::cleanup_test_rule("UNUSUAL_DATA_RULE");
    }

    use crate::execute_rules::get_violations;
    #[pg_test]
    fn test_get_violations() {
        // Setup: create two enabled rules with q4 using fixtures
        fixtures::setup_test_rule("TESTQ4A", 99992, "Test Rule Q4A", true, 20, 80);
        fixtures::setup_test_rule("TESTQ4B", 99993, "Test Rule Q4B", true, 20, 80);
        let _ = Spi::run(
            "UPDATE pglinter.rules SET q4 = 'SELECT 10::oid, 20::oid, 30' WHERE code = 'TESTQ4A'",
        );
        let _ = Spi::run(
            "UPDATE pglinter.rules SET q4 = 'SELECT 11::oid, 21::oid, 31' WHERE code = 'TESTQ4B'",
        );

        let result = get_violations();
        assert!(result.is_ok());
        let all = result.unwrap();
        // Should contain both rules
        let mut found_a = false;
        let mut found_b = false;
        for (code, violations) in all {
            if code == "TESTQ4A" {
                assert_eq!(violations, vec![(10, 20, 30)]);
                found_a = true;
            }
            if code == "TESTQ4B" {
                assert_eq!(violations, vec![(11, 21, 31)]);
                found_b = true;
            }
        }
        assert!(found_a && found_b);
        // Cleanup
        fixtures::cleanup_test_rule("TESTQ4A");
        fixtures::cleanup_test_rule("TESTQ4B");
    }

    use crate::execute_rules::get_violations_for_rule;
    #[pg_test]
    fn test_get_violations_for_rule() {
        // Setup: create a rule with q4 using fixtures
        fixtures::setup_test_rule("TESTQ4C", 99994, "Test Rule Q4C", true, 20, 80);
        let _ = Spi::run(
            "UPDATE pglinter.rules SET q4 = 'SELECT 42::oid, 43::oid, 44' WHERE code = 'TESTQ4C'",
        );

        let result = get_violations_for_rule("TESTQ4C");
        assert!(result.is_ok());
        let violations = result.unwrap();
        assert_eq!(violations, vec![(42, 43, 44)]);

        // Cleanup
        fixtures::cleanup_test_rule("TESTQ4C");
    }
}

/// This module is required by `cargo pgrx test` invocations.
/// It must be visible at the root of your extension crate.
#[cfg(test)]
pub mod pg_test {
    pub fn setup(_options: Vec<&str>) {
        // perform one-off initialization when the pg_test framework starts
    }

    #[must_use]
    pub fn postgresql_conf_options() -> Vec<&'static str> {
        // return any postgresql.conf settings that are required for your tests
        vec![]
    }
}
