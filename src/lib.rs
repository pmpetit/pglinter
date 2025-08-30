use pgrx::pgrx_macros::extension_sql_file;
use pgrx::prelude::*;

mod rules_engine;

// extension_sql_file!("../sql/rules.sql", name = "pg_linter");
extension_sql_file!("../sql/rules.sql", name = "pg_linter", finalize);

::pgrx::pg_module_magic!();

#[pg_extern]
fn hello_pg_linter() -> &'static str {
    "Hello, pg_linter"
}

#[pg_schema]
mod pg_linter {
    use pgrx::prelude::*;
    use crate::rules_engine::{execute_base_rules, execute_cluster_rules, execute_table_rules, execute_schema_rules, generate_sarif_output_optional};

    #[pg_extern(sql = "
        CREATE FUNCTION pg_linter.perform_base_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_base_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_base_check(output_file: Option<&str>) -> Option<bool> {
        match execute_base_rules().and_then(|results| generate_sarif_output_optional(results, output_file)) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pg_linter base check failed: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pg_linter.perform_cluster_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_cluster_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_cluster_check(output_file: Option<&str>) -> Option<bool> {
        match execute_cluster_rules().and_then(|results| generate_sarif_output_optional(results, output_file)) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pg_linter cluster check failed: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pg_linter.perform_table_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_table_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_table_check(output_file: Option<&str>) -> Option<bool> {
        match execute_table_rules().and_then(|results| generate_sarif_output_optional(results, output_file)) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pg_linter table check failed: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern(sql = "
        CREATE FUNCTION pg_linter.perform_schema_check(output_file TEXT DEFAULT NULL)
        RETURNS BOOLEAN
        AS 'MODULE_PATHNAME', 'perform_schema_check_wrapper'
        LANGUAGE C;
    ")]
    fn perform_schema_check(output_file: Option<&str>) -> Option<bool> {
        match execute_schema_rules().and_then(|results| generate_sarif_output_optional(results, output_file)) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("pg_linter schema check failed: {}", e);
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
        pgrx::notice!("🔍 Running comprehensive pg_linter check...");
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
            pgrx::notice!("🎉 All pg_linter checks completed successfully!");
        } else {
            pgrx::notice!("⚠️  Some pg_linter checks found issues - please review above");
        }

        Some(all_success)
    }

    // Rule management functions
    #[pg_extern]
    fn enable_rule(rule_code: &str) -> Option<bool> {
        match crate::rules_engine::enable_rule(rule_code) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to enable rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern]
    fn disable_rule(rule_code: &str) -> Option<bool> {
        match crate::rules_engine::disable_rule(rule_code) {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to disable rule {}: {}", rule_code, e);
                Some(false)
            }
        }
    }

    #[pg_extern]
    fn show_rules() -> Option<bool> {
        match crate::rules_engine::show_rule_status() {
            Ok(success) => Some(success),
            Err(e) => {
                pgrx::warning!("Failed to show rule status: {}", e);
                Some(false)
            }
        }
    }

    #[pg_extern]
    fn is_rule_enabled(rule_code: &str) -> Option<bool> {
        match crate::rules_engine::is_rule_enabled(rule_code) {
            Ok(enabled) => Some(enabled),
            Err(e) => {
                pgrx::warning!("Failed to check rule status for {}: {}", rule_code, e);
                None
            }
        }
    }

    #[pg_extern]
    fn explain_rule(rule_code: &str) -> Option<bool> {
        match crate::rules_engine::explain_rule(rule_code) {
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
}

//----------------------------------------------------------------------------
// Unit tests
//----------------------------------------------------------------------------


#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use pgrx::prelude::*;

    #[pg_test]
    fn test_hello_pg_linter() {
        assert_eq!("Hello, pg_linter", crate::hello_pg_linter());
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
