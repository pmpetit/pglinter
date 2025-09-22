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
        execute_rules,
        generate_sarif_output_optional,
    };
    use crate::manage_rules;
    use pgrx::prelude::*;

    #[pg_extern(sql = "
        CREATE FUNCTION pglinter.perform_base_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_base_check_wrapper'
        LANGUAGE C
        SECURITY DEFINER;
    ")]
    fn perform_base_check(output_file: Option<&str>) -> Option<bool> {
        match execute_rules("BASE")
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
        LANGUAGE C
        SECURITY DEFINER;
    ")]
    fn perform_cluster_check(output_file: Option<&str>) -> Option<bool> {
        match execute_rules("CLUSTER")
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
        LANGUAGE C
        SECURITY DEFINER;
    ")]
    fn perform_table_check(output_file: Option<&str>) -> Option<bool> {
        match execute_rules("TABLE")
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
        LANGUAGE C
        SECURITY DEFINER;
    ")]
    fn perform_schema_check(output_file: Option<&str>) -> Option<bool> {
        match execute_rules("SCHEMA")
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
    #[pg_extern(security_definer)]
    fn check_base() -> Option<bool> {
        perform_base_check(None)
    }

    #[pg_extern(security_definer)]
    fn check_cluster() -> Option<bool> {
        perform_cluster_check(None)
    }

    #[pg_extern(security_definer)]
    fn check_table() -> Option<bool> {
        perform_table_check(None)
    }

    #[pg_extern(security_definer)]
    fn check_schema() -> Option<bool> {
        perform_schema_check(None)
    }


    #[pg_extern(security_definer)]
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
    fn export_rules_to_yaml() -> Option<String>  {
        match manage_rules::export_rules_to_yaml() {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to export: {}", e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn export_rules_to_file(file_path: &str) -> Option<String>  {
        match manage_rules::export_rules_to_file(file_path) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to export: {}", e);
                None
            }
        }
    }

    #[pg_extern(security_definer)]
    fn import_rules_from_yaml(yaml_content: &str) -> Option<String>  {
        match manage_rules::import_rules_from_yaml(yaml_content) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to import: {}", e);
                Some(e.to_string())
            }
        }
    }

    #[pg_extern(security_definer)]
    fn import_rules_from_file(file_path: &str) -> Option<String>  {
        match manage_rules::import_rules_from_file(file_path) {
            Ok(result) => Some(result.to_string()),
            Err(e) => {
                pgrx::warning!("Failed to import: {}", e);
                Some(e.to_string())
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
                .unwrap_or(999);
        let error_level =
            Spi::get_one::<i32>("SELECT error_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(999);

        // The default values should be 1, 1 from rules.sql (for T005 specifically)
        assert_eq!(warning_level, 1);
        assert_eq!(error_level, 1);

        // Update T005 thresholds to test if they're being used
        let _ = Spi::run("UPDATE pglinter.rules SET warning_level = 50, error_level = 90 WHERE code = 'T005'");

        // Verify the update worked
        let updated_warning =
            Spi::get_one::<i32>("SELECT warning_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(999);
        let updated_error =
            Spi::get_one::<i32>("SELECT error_level FROM pglinter.rules WHERE code = 'T005'")
                .unwrap()
                .unwrap_or(999);
        assert_eq!(updated_warning, 50);
        assert_eq!(updated_error, 90);

        // Create a test table with some data to potentially trigger T005
        let _ = Spi::run("CREATE SCHEMA IF NOT EXISTS test_schema");
        let _ = Spi::run("CREATE SCHEMA IF NOT EXISTS other_schema");
        let _ = Spi::run("CREATE TABLE IF NOT EXISTS other_schema.parent_table (id INT PRIMARY KEY)");
        let _ = Spi::run("CREATE TABLE IF NOT EXISTS test_schema.child_table (id INT, parent_id INT, CONSTRAINT fk_parent FOREIGN KEY (parent_id) REFERENCES other_schema.parent_table(id))");

        // Test that T005 is enabled and can be executed
        let t005_enabled = manage_rules::is_rule_enabled("T005").unwrap_or(false);
        assert!(t005_enabled);

        // The rule should execute without error (whether it finds issues or not depends on actual schema setup)
        // This test mainly verifies the function can access the updated thresholds
        // We'll test this by running table check which includes T005
        let result = crate::execute_rules::execute_table_rules();
        assert!(result.is_ok());

        // Restore original T005 configuration
        let _ = Spi::run(
            "UPDATE pglinter.rules SET warning_level = 1, error_level = 1 WHERE code = 'T005'",
        );

        // Clean up test tables and schemas
        let _ = Spi::run("DROP TABLE IF EXISTS test_schema.child_table");
        let _ = Spi::run("DROP TABLE IF EXISTS other_schema.parent_table");
        let _ = Spi::run("DROP SCHEMA IF EXISTS test_schema");
        let _ = Spi::run("DROP SCHEMA IF EXISTS other_schema");
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


    #[pg_test]
    fn test_show_rule_queries() {
        // Setup: create a test rule with queries
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'TEST_SHOW_QUERIES'");
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
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST_SHOW_QUERIES', 'TEST_NULL_QUERIES')");
    }

    #[pg_test]
    fn test_import_rules_from_file() {
        // Test 1: Test with non-existent file
        let result_not_found = manage_rules::import_rules_from_file("/nonexistent/path/to/file.yaml");
        assert!(result_not_found.is_err());
        assert!(result_not_found.unwrap_err().contains("File read error"));

        // Test 2: Create a temporary YAML file with test rules
        let temp_yaml_content = r#"
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
"#;

        // Write test YAML to a temporary file
        let temp_file_path = "/tmp/pglinter_test_rules.yaml";
        std::fs::write(temp_file_path, temp_yaml_content).expect("Failed to write test file");

        // Clean up any existing test rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST_IMPORT_1', 'TEST_IMPORT_2')");

        // Test 3: Import from valid YAML file
        let result_success = manage_rules::import_rules_from_file(temp_file_path);
        assert!(result_success.is_ok());
        let success_msg = result_success.unwrap();
        assert!(success_msg.contains("Import completed"));
        assert!(success_msg.contains("new rules"));

        // Test 4: Verify the imported rules exist in the database
        let rule1_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'TEST_IMPORT_1')"
        ).unwrap();
        assert!(rule1_exists.unwrap());

        let rule2_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'TEST_IMPORT_2')"
        ).unwrap();
        assert!(rule2_exists.unwrap());

        // Test 5: Verify rule1 properties
        let rule1_name = Spi::get_one::<String>(
            "SELECT name FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'"
        ).unwrap();
        assert_eq!(rule1_name.unwrap(), "Test Import Rule 1");

        let rule1_enabled = Spi::get_one::<bool>(
            "SELECT enable FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'"
        ).unwrap();
        assert!(rule1_enabled.unwrap());

        let rule1_warning = Spi::get_one::<i32>(
            "SELECT warning_level FROM pglinter.rules WHERE code = 'TEST_IMPORT_1'"
        ).unwrap();
        assert_eq!(rule1_warning.unwrap(), 30);

        // Test 6: Verify rule2 properties
        let rule2_enabled = Spi::get_one::<bool>(
            "SELECT enable FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'"
        ).unwrap();
        assert!(!rule2_enabled.unwrap()); // Should be false

        let rule2_error = Spi::get_one::<i32>(
            "SELECT error_level FROM pglinter.rules WHERE code = 'TEST_IMPORT_2'"
        ).unwrap();
        assert_eq!(rule2_error.unwrap(), 80);

        // Test 7: Test updating existing rules (import again)
        let result_update = manage_rules::import_rules_from_file(temp_file_path);
        assert!(result_update.is_ok());
        let update_msg = result_update.unwrap();
        assert!(update_msg.contains("updated rules"));

        // Test 8: Test with invalid YAML content
        let invalid_yaml_content = r#"
metadata:
  export_timestamp: "invalid-timestamp"
  invalid_yaml_structure: {
rules:
  - id: "not_a_number"
    name: Missing required fields
"#;
        let invalid_file_path = "/tmp/pglinter_invalid_test.yaml";
        std::fs::write(invalid_file_path, invalid_yaml_content).expect("Failed to write invalid test file");

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
        std::fs::write(protected_file_path, temp_yaml_content).expect("Failed to write protected test file");

        // Try to make file unreadable (this might not work on all systems)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(protected_file_path).unwrap().permissions();
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
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('TEST_IMPORT_1', 'TEST_IMPORT_2')");
    }

    #[pg_test]
    fn test_import_rules_from_yaml() {
        // Test 1: Test with valid YAML content
        let valid_yaml_content = r#"
metadata:
  export_timestamp: "2024-01-15T10:30:00Z"
  total_rules: 3
  format_version: "1.0"
rules:
  - id: 9996
    name: "YAML Test Rule 1"
    code: "YAML_TEST_1"
    enable: true
    warning_level: 25
    error_level: 60
    scope: "YAML_TEST"
    description: "First YAML test rule for direct import testing"
    message: "YAML test message for rule 1: {0} out of {1} items failed"
    fixes: ["YAML Fix 1", "YAML Fix 2"]
    q1: "SELECT COUNT(*) FROM yaml_test_table"
    q2: "SELECT COUNT(*) FROM yaml_test_table WHERE condition = true"
  - id: 9997
    name: "YAML Test Rule 2"
    code: "YAML_TEST_2"
    enable: false
    warning_level: 35
    error_level: 75
    scope: "YAML_TEST"
    description: "Second YAML test rule with null queries"
    message: "YAML test message for rule 2"
    fixes: []
    q1: null
    q2: "SELECT COUNT(*) FROM yaml_test_table WHERE error_condition = true"
  - id: 9998
    name: "YAML Test Rule 3"
    code: "YAML_TEST_3"
    enable: true
    warning_level: 45
    error_level: 85
    scope: "YAML_TEST"
    description: "Third YAML test rule with complex fixes"
    message: "Complex YAML test message: {0} issues found in {1} objects"
    fixes: ["Fix A: Update configuration", "Fix B: Restart service", "Fix C: Clear cache", "Fix D: Verify settings"]
    q1: "SELECT COUNT(DISTINCT schema_name) FROM information_schema.schemata"
    q2: "SELECT COUNT(*) FROM pg_stat_user_tables WHERE schemaname = 'test_schema'"
"#;

        // Clean up any existing test rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('YAML_TEST_1', 'YAML_TEST_2', 'YAML_TEST_3')");

        // Test 2: Import from valid YAML content
        let result_success = manage_rules::import_rules_from_yaml(valid_yaml_content);
        assert!(result_success.is_ok());
        let success_msg = result_success.unwrap();
        assert!(success_msg.contains("Import completed"));
        assert!(success_msg.contains("3 new rules"));

        // Test 3: Verify the imported rules exist and have correct properties
        let yaml_test_1_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'YAML_TEST_1')"
        ).unwrap();
        assert!(yaml_test_1_exists.unwrap());

        let yaml_test_2_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'YAML_TEST_2')"
        ).unwrap();
        assert!(yaml_test_2_exists.unwrap());

        let yaml_test_3_exists = Spi::get_one::<bool>(
            "SELECT EXISTS(SELECT 1 FROM pglinter.rules WHERE code = 'YAML_TEST_3')"
        ).unwrap();
        assert!(yaml_test_3_exists.unwrap());

        // Test 4: Verify specific rule properties for YAML_TEST_1
        let rule1_name = Spi::get_one::<String>(
            "SELECT name FROM pglinter.rules WHERE code = 'YAML_TEST_1'"
        ).unwrap();
        assert_eq!(rule1_name.unwrap(), "YAML Test Rule 1");

        let rule1_enabled = Spi::get_one::<bool>(
            "SELECT enable FROM pglinter.rules WHERE code = 'YAML_TEST_1'"
        ).unwrap();
        assert!(rule1_enabled.unwrap());

        let rule1_warning = Spi::get_one::<i32>(
            "SELECT warning_level FROM pglinter.rules WHERE code = 'YAML_TEST_1'"
        ).unwrap();
        assert_eq!(rule1_warning.unwrap(), 25);

        let rule1_error = Spi::get_one::<i32>(
            "SELECT error_level FROM pglinter.rules WHERE code = 'YAML_TEST_1'"
        ).unwrap();
        assert_eq!(rule1_error.unwrap(), 60);

        // Test 5: Verify YAML_TEST_2 properties (disabled, null q1)
        let rule2_enabled = Spi::get_one::<bool>(
            "SELECT enable FROM pglinter.rules WHERE code = 'YAML_TEST_2'"
        ).unwrap();
        assert!(!rule2_enabled.unwrap());

        let rule2_q1_is_null = Spi::get_one::<bool>(
            "SELECT q1 IS NULL FROM pglinter.rules WHERE code = 'YAML_TEST_2'"
        ).unwrap();
        assert!(rule2_q1_is_null.unwrap());

        let rule2_q2_is_null = Spi::get_one::<bool>(
            "SELECT q2 IS NULL FROM pglinter.rules WHERE code = 'YAML_TEST_2'"
        ).unwrap();
        assert!(!rule2_q2_is_null.unwrap()); // Should not be null

        // Test 6: Verify YAML_TEST_3 complex properties
        let rule3_description = Spi::get_one::<String>(
            "SELECT description FROM pglinter.rules WHERE code = 'YAML_TEST_3'"
        ).unwrap();
        assert!(rule3_description.unwrap().contains("Third YAML test rule"));

        let rule3_message = Spi::get_one::<String>(
            "SELECT message FROM pglinter.rules WHERE code = 'YAML_TEST_3'"
        ).unwrap();
        assert!(rule3_message.unwrap().contains("{0} issues found"));

        // Test 7: Re-import same YAML to test updates
        let result_update = manage_rules::import_rules_from_yaml(valid_yaml_content);
        assert!(result_update.is_ok());
        let update_msg = result_update.unwrap();
        assert!(update_msg.contains("3 updated rules"));
        assert!(update_msg.contains("0 new rules"));

        // Test 8: Test with invalid YAML structure
        let invalid_yaml_content = r#"
metadata:
  export_timestamp: "invalid-date
  total_rules: "not-a-number"
  missing_closing_quote:
rules:
  - id: invalid_id_type
    name: Missing required properties
    enable: "not-a-boolean"
"#;

        let result_invalid = manage_rules::import_rules_from_yaml(invalid_yaml_content);
        assert!(result_invalid.is_err());
        assert!(result_invalid.unwrap_err().contains("YAML parsing error"));

        // Test 9: Test with valid YAML but invalid rule data
        let invalid_rule_yaml = r#"
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
"#;

        let result_invalid_rule = manage_rules::import_rules_from_yaml(invalid_rule_yaml);
        // This should succeed from YAML parsing perspective, even if SQL is invalid
        assert!(result_invalid_rule.is_ok());

        // Test 10: Test with empty YAML content
        let empty_yaml = "";
        let result_empty = manage_rules::import_rules_from_yaml(empty_yaml);
        assert!(result_empty.is_err());
        assert!(result_empty.unwrap_err().contains("YAML parsing error"));

        // Test 11: Test with minimal valid YAML
        let minimal_yaml = r#"
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 0
  format_version: "1.0"
rules: []
"#;

        let result_minimal = manage_rules::import_rules_from_yaml(minimal_yaml);
        assert!(result_minimal.is_ok());
        let minimal_msg = result_minimal.unwrap();
        assert!(minimal_msg.contains("0 new rules, 0 updated rules"));

        // Test 12: Test with rule containing special characters in strings
        let special_chars_yaml = r#"
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
"#;

        let result_special = manage_rules::import_rules_from_yaml(special_chars_yaml);
        assert!(result_special.is_ok());

        // Verify the special characters are preserved
        let special_name = Spi::get_one::<String>(
            "SELECT name FROM pglinter.rules WHERE code = 'SPECIAL_TEST'"
        ).unwrap();
        assert!(special_name.unwrap().contains("<>&\"'`"));

        // Clean up all test rules
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code IN ('YAML_TEST_1', 'YAML_TEST_2', 'YAML_TEST_3', 'INVALID_TEST', 'SPECIAL_TEST')");
    }

    #[pg_test]
    fn test_import_consistency() {
        // Test that import_rules_from_file produces the same results as import_rules_from_yaml
        let consistent_yaml_content = r#"
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 1
  format_version: "1.0"
rules:
  - id: 9990
    name: "Consistency Test Rule"
    code: "CONSISTENCY_TEST"
    enable: true
    warning_level: 55
    error_level: 88
    scope: "CONSISTENCY"
    description: "Rule to test consistency between file and YAML import functions"
    message: "Consistency test: {0} items processed"
    fixes: ["Consistency Fix 1"]
    q1: "SELECT COUNT(*) FROM test_consistency"
    q2: "SELECT COUNT(*) FROM test_consistency WHERE issue = true"
"#;

        // Clean up any existing test rule
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'");

        // Test 1: Import directly from YAML string
        let yaml_result = manage_rules::import_rules_from_yaml(consistent_yaml_content);
        assert!(yaml_result.is_ok());

        // Capture the rule properties after YAML import
        let yaml_name = Spi::get_one::<String>(
            "SELECT name FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'"
        ).unwrap().unwrap();

        let yaml_warning = Spi::get_one::<i32>(
            "SELECT warning_level FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'"
        ).unwrap().unwrap();

        // Clean up for next test
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'");

        // Test 2: Import from file with same content
        let consistency_file_path = "/tmp/pglinter_consistency_test.yaml";
        std::fs::write(consistency_file_path, consistent_yaml_content).expect("Failed to write consistency test file");

        let file_result = manage_rules::import_rules_from_file(consistency_file_path);
        assert!(file_result.is_ok());

        // Verify the same properties were imported
        let file_name = Spi::get_one::<String>(
            "SELECT name FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'"
        ).unwrap().unwrap();

        let file_warning = Spi::get_one::<i32>(
            "SELECT warning_level FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'"
        ).unwrap().unwrap();

        // Assert consistency
        assert_eq!(yaml_name, file_name);
        assert_eq!(yaml_warning, file_warning);

        // Both results should indicate 1 new rule
        assert!(yaml_result.unwrap().contains("1 new rules"));
        assert!(file_result.unwrap().contains("1 updated rules")); // Second import updates existing

        // Clean up
        let _ = std::fs::remove_file(consistency_file_path);
        let _ = Spi::run("DELETE FROM pglinter.rules WHERE code = 'CONSISTENCY_TEST'");
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
