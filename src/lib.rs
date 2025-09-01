use pgrx::pgrx_macros::extension_sql_file;
use pgrx::prelude::*;

mod execute_rules;
mod manage_rules;

// extension_sql_file!("../sql/rules.sql", name = "pglinter");
extension_sql_file!("../sql/rules.sql", name = "pglinter", finalize);

::pgrx::pg_module_magic!();

#[pg_extern]
fn hello_pglinter() -> &'static str {
    "Hello, pglinter"
}

#[pg_schema]
mod pglinter {
    use crate::execute_rules::{
        execute_base_rules, execute_cluster_rules, execute_schema_rules, execute_table_rules,
        generate_sarif_output_optional,
    };
    use crate::manage_rules;
    use pgrx::prelude::*;

    #[pg_extern(sql = "
        CREATE FUNCTION pglinter.perform_base_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_base_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_base_check(output_file: Option<&str>) -> Option<bool> {
        match execute_base_rules()
            .and_then(|results| generate_sarif_output_optional(results, output_file))
        {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pglinter base check failed: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pglinter.perform_cluster_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_cluster_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_cluster_check(output_file: Option<&str>) -> Option<bool> {
        match execute_cluster_rules()
            .and_then(|results| generate_sarif_output_optional(results, output_file))
        {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pglinter cluster check failed: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pglinter.perform_table_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_table_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_table_check(output_file: Option<&str>) -> Option<bool> {
        match execute_table_rules()
            .and_then(|results| generate_sarif_output_optional(results, output_file))
        {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pglinter table check failed: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pglinter.perform_schema_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_schema_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_schema_check(output_file: Option<&str>) -> Option<bool> {
        match execute_schema_rules()
            .and_then(|results| generate_sarif_output_optional(results, output_file))
        {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pglinter schema check failed: {}", e);
                Some(false)
            }
        }
    }

    // Convenience functions that always output to prompt
    #[pg_extern]
    fn check_base() -> Option<bool> {
        perform_base_check(None)
    }

    #[pg_extern]
    fn check_cluster() -> Option<bool> {
        perform_cluster_check(None)
    }

    #[pg_extern]
    fn check_table() -> Option<bool> {
        perform_table_check(None)
    }

    #[pg_extern]
    fn check_schema() -> Option<bool> {
        perform_schema_check(None)
    }

    #[pg_extern]
    fn check_all() -> Option<bool> {
        pgrx::notice!("🔍 Running comprehensive pglinter check...");
        pgrx::notice!("");

        let mut all_success = true;

        pgrx::notice!("📋 BASE CHECKS:");
        if let Some(false) = perform_base_check(None) {
            all_success = false;
        }

        pgrx::notice!("");
        pgrx::notice!("🖥️  CLUSTER CHECKS:");
        if let Some(false) = perform_cluster_check(None) {
            all_success = false;
        }

        pgrx::notice!("");
        pgrx::notice!("📊 TABLE CHECKS:");
        if let Some(false) = perform_table_check(None) {
            all_success = false;
        }

        pgrx::notice!("");
        pgrx::notice!("🗂️  SCHEMA CHECKS:");
        if let Some(false) = perform_schema_check(None) {
            all_success = false;
        }

        pgrx::notice!("");
        if all_success {
            pgrx::notice!("🎉 All pglinter checks completed successfully!");
        } else {
            pgrx::notice!("⚠️  Some pglinter checks found issues - please review above");
        }

        Some(all_success)
    }

    // Rule management functions
    #[pg_extern]
    fn enable_rule(rule_code: &str) -> Option<bool> {
        match manage_rules::enable_rule(rule_code) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to enable rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern]
    fn disable_rule(rule_code: &str) -> Option<bool> {
        match manage_rules::disable_rule(rule_code) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to disable rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern]
    fn show_rules() -> Option<bool> {
        match manage_rules::show_rule_status() {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to show rule status: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern]
    fn is_rule_enabled(rule_code: &str) -> Option<bool> {
        match manage_rules::is_rule_enabled(rule_code) {
            Ok(enabled) => Some(enabled),
            Err(e) => {
                pgrx::warning!("Failed to check rule status for {}: {}", rule_code, e);
                None
            }
        }
    }

    #[pg_extern]
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

    #[pg_extern]
    fn enable_all_rules() -> Option<i32> {
        match manage_rules::enable_all_rules() {
            Ok(count) => Some(count as i32),
            Err(e) => {
                pgrx::warning!("Failed to enable all rules: {}", e);
                Some(-1)
            }
        }
    }

    #[pg_extern]
    fn disable_all_rules() -> Option<i32> {
        match manage_rules::disable_all_rules() {
            Ok(count) => Some(count as i32),
            Err(e) => {
                pgrx::warning!("Failed to disable all rules: {}", e);
                Some(-1)
            }
        }
    }

    #[pg_extern]
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

    #[pg_extern]
    fn get_rule_levels(rule_code: &str) -> Option<String> {
        match manage_rules::get_rule_levels(rule_code) {
            Ok((warning, error)) => Some(format!("warning_level={warning}, error_level={error}")),
            Err(e) => {
                pgrx::warning!("Failed to get rule levels for {}: {}", rule_code, e);
                None
            }
        }
    }
}

//----------------------------------------------------------------------------
// Unit tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::manage_rules;
    use pgrx::prelude::*;

    #[pg_test]
    fn test_hello_pglinter() {
        assert_eq!("Hello, pglinter", crate::hello_pglinter());
    }

    #[pg_test]
    fn test_enable_rule_success() {
        // Test enabling an existing rule
        // First ensure the rule exists and is disabled by deleting and inserting
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST001'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9001, 'TEST001', 'Test Rule', false)");

        // Enable the rule
        let result = manage_rules::enable_rule("TEST001");
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify it's enabled in the database
        let enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST001'");
        assert!(enabled.is_ok());
        assert_eq!(enabled.unwrap(), Some(true));
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
        // First ensure the rule exists and is enabled
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST002'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9002, 'TEST002', 'Test Rule 2', true)");

        // Disable the rule
        let result = manage_rules::disable_rule("TEST002");
        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify it's disabled in the database
        let enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST002'");
        assert!(enabled.is_ok());
        assert_eq!(enabled.unwrap(), Some(false));
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
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST003'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9003, 'TEST003', 'Test Rule 3', true)");

        let result = manage_rules::is_rule_enabled("TEST003");
        assert!(result.is_ok());
        assert!(result.unwrap());
    }

    #[pg_test]
    fn test_is_rule_enabled_false() {
        // Test checking if a disabled rule is enabled
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST004'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9004, 'TEST004', 'Test Rule 4', false)");

        let result = manage_rules::is_rule_enabled("TEST004");
        assert!(result.is_ok());
        assert!(!result.unwrap());
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
        // Insert test rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST005', 'TEST006')");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9005, 'TEST005', 'Test Rule 5', true)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9006, 'TEST006', 'Test Rule 6', false)");

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
    }

    #[pg_test]
    fn test_show_rule_status() {
        // Insert test rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST007'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9007, 'TEST007', 'Test Rule 7', true)");

        let result = manage_rules::show_rule_status();
        assert!(result.is_ok());
        assert!(result.unwrap());
    }

    #[pg_test]
    fn test_explain_rule_success() {
        // Insert a test rule with complete information
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST008'");
        let _ = Spi::run("
            INSERT INTO pglinter.rules (id, code, name, description, scope, message, fixes, enable)
            VALUES (9008, 'TEST008', 'Test Rule 8', 'Test description', 'base', 'Test message', ARRAY['Fix 1', 'Fix 2'], true)
        ");

        let result = manage_rules::explain_rule("TEST008");
        assert!(result.is_ok());

        let explanation = result.unwrap();
        assert!(explanation.contains("TEST008"));
        assert!(explanation.contains("Test Rule 8"));
        assert!(explanation.contains("Test description"));
        assert!(explanation.contains("base"));
        assert!(explanation.contains("Test message"));
        assert!(explanation.contains("Fix 1"));
        assert!(explanation.contains("Fix 2"));
    }

    #[pg_test]
    fn test_explain_rule_not_found() {
        let result = manage_rules::explain_rule("NONEXISTENT");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[pg_test]
    fn test_rule_toggle_workflow() {
        // Test a complete workflow: enable -> check -> disable -> check
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST009'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9009, 'TEST009', 'Test Rule 9', false)");

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
    }

    #[pg_test]
    fn test_enable_all_rules() {
        // Set up test rules with mixed enabled/disabled states
        let _ =
            Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST010', 'TEST011', 'TEST012')");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9010, 'TEST010', 'Test Rule 10', false)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9011, 'TEST011', 'Test Rule 11', false)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9012, 'TEST012', 'Test Rule 12', true)");

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

        // Verify our test rules are now enabled
        let test010_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST010'")
                .unwrap();
        assert_eq!(test010_enabled, Some(true));

        let test011_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST011'")
                .unwrap();
        assert_eq!(test011_enabled, Some(true));

        let test012_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST012'")
                .unwrap();
        assert_eq!(test012_enabled, Some(true));

        // Test when all rules are already enabled
        let result2 = manage_rules::enable_all_rules();
        assert!(result2.is_ok());
        let count2 = result2.unwrap();
        assert_eq!(count2, 0); // Should have enabled 0 rules
    }

    #[pg_test]
    fn test_disable_all_rules() {
        // Set up test rules with mixed enabled/disabled states
        let _ =
            Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST013', 'TEST014', 'TEST015')");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9013, 'TEST013', 'Test Rule 13', true)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9014, 'TEST014', 'Test Rule 14', true)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9015, 'TEST015', 'Test Rule 15', false)");

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

        // Verify all test rules are now disabled
        let test013_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST013'")
                .unwrap();
        assert_eq!(test013_enabled, Some(false));

        let test014_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST014'")
                .unwrap();
        assert_eq!(test014_enabled, Some(false));

        let test015_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST015'")
                .unwrap();
        assert_eq!(test015_enabled, Some(false));

        // Test when all rules are already disabled
        let result2 = manage_rules::disable_all_rules();
        assert!(result2.is_ok());
        let count2 = result2.unwrap();
        assert_eq!(count2, 0); // Should have disabled 0 rules
    }

    #[pg_test]
    fn test_enable_disable_all_workflow() {
        // Test the complete workflow of enabling and disabling all rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST016', 'TEST017')");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9016, 'TEST016', 'Test Rule 16', true)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9017, 'TEST017', 'Test Rule 17', false)");

        // Count rules before operations
        let enabled_count_before =
            Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules WHERE enable = true")
                .unwrap()
                .unwrap_or(0);

        // Disable all rules first
        let disable_result = manage_rules::disable_all_rules();
        assert!(disable_result.is_ok());
        assert_eq!(disable_result.unwrap() as i64, enabled_count_before); // Should have disabled all enabled rules

        // Verify both test rules are disabled
        let test016_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST016'")
                .unwrap();
        assert_eq!(test016_enabled, Some(false));
        let test017_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST017'")
                .unwrap();
        assert_eq!(test017_enabled, Some(false));

        // Count total rules (should all be disabled now)
        let total_rules = Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules")
            .unwrap()
            .unwrap_or(0);

        // Enable all rules
        let enable_result = manage_rules::enable_all_rules();
        assert!(enable_result.is_ok());
        assert_eq!(enable_result.unwrap() as i64, total_rules); // Should have enabled all rules

        // Verify both are enabled
        let test016_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST016'")
                .unwrap();
        assert_eq!(test016_enabled, Some(true));
        let test017_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST017'")
                .unwrap();
        assert_eq!(test017_enabled, Some(true));
    }

    #[pg_test]
    fn test_sql_enable_disable_all_functions() {
        // Test the SQL interface for enable_all_rules and disable_all_rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST018', 'TEST019')");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9018, 'TEST018', 'Test Rule 18', true)");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable) VALUES (9019, 'TEST019', 'Test Rule 19', false)");

        // Test enable_all_rules SQL function
        let enabled_count_before =
            Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules WHERE enable = false")
                .unwrap()
                .unwrap_or(0);
        let result = Spi::get_one::<i32>("SELECT pglinter.enable_all_rules()").unwrap();
        assert!(result.is_some());
        assert_eq!(result.unwrap() as i64, enabled_count_before);

        // Test disable_all_rules SQL function
        let enabled_count_before_disable =
            Spi::get_one::<i64>("SELECT COUNT(*) FROM pglinter.rules WHERE enable = true")
                .unwrap()
                .unwrap_or(0);
        let result = Spi::get_one::<i32>("SELECT pglinter.disable_all_rules()").unwrap();
        assert!(result.is_some());
        assert_eq!(result.unwrap() as i64, enabled_count_before_disable);

        // Verify both test rules are now disabled
        let test018_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST018'")
                .unwrap();
        assert_eq!(test018_enabled, Some(false));
        let test019_enabled =
            Spi::get_one::<bool>("SELECT enable FROM pglinter.rules WHERE code = 'TEST019'")
                .unwrap();
        assert_eq!(test019_enabled, Some(false));
    }

    #[pg_test]
    fn test_t005_uses_rules_table_thresholds() {
        // Test that T005 rule uses warning_level and error_level from rules table

        // First, check the current T005 configuration
        let warning_level =
            Spi::get_one::<i32>("SELECT warning_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(1);
        let error_level =
            Spi::get_one::<i32>("SELECT error_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(1);

        // The default values should be 50, 90 from rules.sql
        assert_eq!(warning_level, 50);
        assert_eq!(error_level, 90);

        // Update T005 thresholds to test if they're being used
        let _ = Spi::run("UPDATE pglinter.rules SET warning_level = 5000, error_level = 10000 WHERE code = 'T005'");

        // Verify the update worked
        let updated_warning =
            Spi::get_one::<i32>("SELECT warning_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(1);
        let updated_error =
            Spi::get_one::<i32>("SELECT error_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(1);
        assert_eq!(updated_warning, 5000);
        assert_eq!(updated_error, 10000);

        // Create a test table with some data to potentially trigger T005
        let _ = Spi::run("CREATE TABLE test_t005_thresholds (id INT, data TEXT)");
        let _ = Spi::run("INSERT INTO test_t005_thresholds SELECT i, 'data_' || i FROM generate_series(1, 100) i");

        // Run some queries to generate statistics
        let _ = Spi::run("SELECT COUNT(*) FROM test_t005_thresholds WHERE data LIKE '%50%'");
        let _ = Spi::run("ANALYZE test_t005_thresholds");

        // Test that T005 is enabled and can be executed
        let t005_enabled = manage_rules::is_rule_enabled("T005").unwrap_or(false);
        assert!(t005_enabled);

        // The rule should execute without error (whether it finds issues or not depends on actual stats)
        // This test mainly verifies the function can access the updated thresholds
        // We'll test this by running table check which includes T005
        let result = crate::execute_rules::execute_table_rules();
        assert!(result.is_ok());

        // Restore original T005 configuration
        let _ = Spi::run(
            "UPDATE pglinter.rules SET warning_level = 50, error_level = 90 WHERE code = 'T005'",
        );

        // Clean up test table
        let _ = Spi::run("DROP TABLE test_t005_thresholds");
    }

    #[pg_test]
    fn test_update_rule_levels() {
        // Setup: ensure B001 rule exists
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_LEVELS'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable, warning_level, error_level) VALUES (9999, 'TEST_LEVELS', 'Test Levels Rule', true, 10, 20)");

        // Test getting current levels
        let result = manage_rules::get_rule_levels("TEST_LEVELS");
        assert!(result.is_ok());
        let (warning, error) = result.unwrap();
        assert_eq!(warning, 10);
        assert_eq!(error, 20);

        // Test updating both levels
        let update_result = manage_rules::update_rule_levels("TEST_LEVELS", Some(15), Some(25));
        assert!(update_result.is_ok());
        assert!(update_result.unwrap());

        // Verify the update
        let result2 = manage_rules::get_rule_levels("TEST_LEVELS");
        assert!(result2.is_ok());
        let (warning2, error2) = result2.unwrap();
        assert_eq!(warning2, 15);
        assert_eq!(error2, 25);

        // Test updating only warning level
        let update_result2 = manage_rules::update_rule_levels("TEST_LEVELS", Some(30), None);
        assert!(update_result2.is_ok());
        assert!(update_result2.unwrap());

        // Verify only warning level changed
        let result3 = manage_rules::get_rule_levels("TEST_LEVELS");
        assert!(result3.is_ok());
        let (warning3, error3) = result3.unwrap();
        assert_eq!(warning3, 30);
        assert_eq!(error3, 25); // Should remain unchanged

        // Test updating only error level
        let update_result3 = manage_rules::update_rule_levels("TEST_LEVELS", None, Some(35));
        assert!(update_result3.is_ok());
        assert!(update_result3.unwrap());

        // Verify only error level changed
        let result4 = manage_rules::get_rule_levels("TEST_LEVELS");
        assert!(result4.is_ok());
        let (warning4, error4) = result4.unwrap();
        assert_eq!(warning4, 30); // Should remain unchanged
        assert_eq!(error4, 35);

        // Test updating non-existent rule
        let update_result4 = manage_rules::update_rule_levels("NONEXISTENT", Some(10), Some(20));
        assert!(update_result4.is_ok());
        assert!(!update_result4.unwrap()); // Should return false

        // Clean up
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_LEVELS'");
    }

    #[pg_test]
    fn test_sql_update_rule_levels() {
        // Setup: ensure test rule exists
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_SQL_LEVELS'");
        let _ = Spi::run("INSERT INTO pglinter.rules (id, code, name, enable, warning_level, error_level) VALUES (9998, 'TEST_SQL_LEVELS', 'Test SQL Levels Rule', true, 5, 10)");

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
