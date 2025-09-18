use pgrx::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::fs::File;
use std::io::Write;

// Embed SQL files at compile time
const B001_TOTAL_TABLES_SQL: &str = include_str!("../sql/b001_total_tables.sql");
const B001_TABLES_WITH_PK_SQL: &str = include_str!("../sql/b001_tables_with_pk.sql");
const B002_TOTAL_INDEXES_SQL: &str = include_str!("../sql/b002_total_indexes.sql");
const B002_REDUNDANT_INDEXES_SQL: &str = include_str!("../sql/b002_redundant_indexes.sql");
const B003_TABLE_WITH_FK: &str = include_str!("../sql/b003_table_with_fk.sql");
const B003_TABLE_WITHOUT_FK: &str = include_str!("../sql/b003_table_without_fk.sql");
const B004_TOTAL_MANUAL_IDX_SQL: &str = include_str!("../sql/b004_total_manual_idx.sql");
const B004_TOTAL_MANUAL_UNUSED_IDX_SQL: &str = include_str!("../sql/b004_total_manual_unused_idx.sql");
const B005_SCHEMA_WITH_PUBLIC_CREATE: &str = include_str!("../sql/b005_schema_with_public_create.sql");
const B005_ALL_SCHEMA: &str = include_str!("../sql/b005_all_schema.sql");
const B006_ALL_OBJECTS_SQL: &str = include_str!("../sql/b006_all_objects.sql");
const B006_UPPERCASE_SQL: &str = include_str!("../sql/b006_uppercase.sql");
const B007_ALL_TABLES_SQL: &str = include_str!("../sql/b007_total_tables.sql");
const B007_NOT_SELECTED_SQL: &str = include_str!("../sql/b007_tables_not_selected.sql");
const C001_SQL: &str = include_str!("../sql/c001.sql");
const C002_PG_HBA_ALL: &str = include_str!("../sql/c002_pg_hba_all.sql");
const C002_PG_HBA_TRUST: &str = include_str!("../sql/c002_pg_hba_trust.sql");
const T001_SQL: &str = include_str!("../sql/t001.sql");
const T002_SQL: &str = include_str!("../sql/t002.sql");
const T003_SQL: &str = include_str!("../sql/t003.sql");
const T004_SQL: &str = include_str!("../sql/t004.sql");
const T005_SQL: &str = include_str!("../sql/t005.sql");
const T006_SQL: &str = include_str!("../sql/t006.sql");
const T007_SQL: &str = include_str!("../sql/t007.sql");
const T008_SQL: &str = include_str!("../sql/t008.sql");
// const T009_SQL: &str = include_str!("../sql/t009.sql");
// const T010_SQL: &str = include_str!("../sql/t010.sql");
// const T011_SQL: &str = include_str!("../sql/t011.sql");
// const T012_SQL: &str = include_str!("../sql/t012.sql");
const S001_SQL: &str = include_str!("../sql/s001.sql");
const S002_SQL: &str = include_str!("../sql/s002.sql");

// Import the rule management functions
use crate::manage_rules::is_rule_enabled;

// Helper function to get rule configuration from the rules table
fn get_rule_config(rule_code: &str) -> Result<(i64, i64, String), String> {
    let config_query = "
        SELECT warning_level, error_level, message
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<(i64, i64, String), spi::SpiError> = Spi::connect(|client| {
        let mut rows = client.select(config_query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            let warning_level: i32 = row.get(1)?.unwrap_or(1);
            let error_level: i32 = row.get(2)?.unwrap_or(1);
            let message: String = row.get(3)?.unwrap_or_default();
            Ok((warning_level as i64, error_level as i64, message))
        } else {
            // Rule not found - this will be handled in the match below
            Ok((0i64, 0i64, String::new())) // Placeholder values
        }
    });

    match result {
        Ok((warning_level, error_level, message)) => {
            if warning_level == 0 && error_level == 0 && message.is_empty() {
                // This indicates rule not found
                Err(format!(
                    "Rule '{rule_code}' not found in pglinter.rules table"
                ))
            } else {
                Ok((warning_level, error_level, message))
            }
        }
        Err(e) => Err(format!(
            "Database error while fetching rule '{rule_code}': {e}"
        )),
    }
}

fn get_rule_message(rule_code: &str) -> Result<String,String> {
    let config_query = "
        SELECT message
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<String, spi::SpiError> = Spi::connect(|client| {
        let mut rows = client.select(config_query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            let message: String = row.get(1)?.unwrap_or_default();
            Ok(message)
        } else {
            // Rule not found - this will be handled in the match below
            Ok(String::new()) // Placeholder values
        }
    });

    match result {
        Ok(message) => {
            if message.is_empty() {
                // This indicates rule not found
                Err(format!(
                    "Rule '{rule_code}' not found in pglinter.rules table"
                ))
            } else {
                Ok(message)
            }
        }
        Err(e) => Err(format!(
            "Database error while fetching rule '{rule_code}': {e}"
        )),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RuleScope {
    Base,
    Cluster,
    Table,
    Schema,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleParam {
    pub key: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleResult {
    pub ruleid: String,
    pub level: String,
    pub message: String,
    pub count: Option<i64>,
}

pub fn execute_base_rules() -> Result<Vec<RuleResult>, String> {
    let mut results = Vec::new();

    // B001: Tables without primary key
    if is_rule_enabled("B001").unwrap_or(true) {
        match execute_rule("B001", B001_TOTAL_TABLES_SQL, B001_TABLES_WITH_PK_SQL) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B001 failed: {e}")),
        }
    }

    // B002: Redundant indexes
    if is_rule_enabled("B002").unwrap_or(true) {
        match execute_rule("B002", B002_TOTAL_INDEXES_SQL, B002_REDUNDANT_INDEXES_SQL) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B001 failed: {e}")),
        }
    }

    // B003: Tables without indexes on foreign keys
    if is_rule_enabled("B003").unwrap_or(true) {
        match execute_rule("B003", B003_TABLE_WITH_FK, B003_TABLE_WITHOUT_FK) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B003 failed: {e}")),
        }
    }

    // B004: Unused indexes
    if is_rule_enabled("B004").unwrap_or(true) {
        match execute_rule("B004", B004_TOTAL_MANUAL_IDX_SQL, B004_TOTAL_MANUAL_UNUSED_IDX_SQL) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B003 failed: {e}")),
        }
    }

    // B005: Unsecured public schema
    if is_rule_enabled("B005").unwrap_or(true) {
        match execute_rule("B005", B005_ALL_SCHEMA, B005_SCHEMA_WITH_PUBLIC_CREATE) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B005 failed: {e}")),
        }
    }

    // B006: Tables with uppercase names/columns
    if is_rule_enabled("B006").unwrap_or(true) {
        match execute_rule("B006", B006_ALL_OBJECTS_SQL, B006_UPPERCASE_SQL) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B006 failed: {e}")),
        }
    }

    // B007: Tables not selected
    if is_rule_enabled("B007").unwrap_or(true) {
        match execute_rule("B007", B007_ALL_TABLES_SQL,B007_NOT_SELECTED_SQL) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B007 failed: {e}")),
        }
    }
    Ok(results)
}

pub fn execute_cluster_rules() -> Result<Vec<RuleResult>, String> {
    let mut results = Vec::new();

    // C001: Memory configuration check
    if is_rule_enabled("C001").unwrap_or(true) {
        match execute_c001_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("C001 failed: {e}")),
        }
    }

    // C002: Insecure pg_hba.conf entries
    if is_rule_enabled("C002").unwrap_or(true) {
        match execute_rule("C002", C002_PG_HBA_ALL, C002_PG_HBA_TRUST) {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("C002 failed: {e}")),
        }
    }

    Ok(results)
}

pub fn execute_table_rules() -> Result<Vec<RuleResult>, String> {
    let mut results = Vec::new();

    // T001: Tables without primary key
    if is_rule_enabled("T001").unwrap_or(true) {
        match execute_t001_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T001 failed: {e}")),
        }
    }

    // T002: Tables with redundant indexes
    if is_rule_enabled("T002").unwrap_or(true) {
        match execute_t002_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T002 failed: {e}")),
        }
    }

    // T003: Tables with foreign keys not indexed
    if is_rule_enabled("T003").unwrap_or(true) {
        match execute_t003_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T003 failed: {e}")),
        }
    }

    // T004: Tables with potential missing indexes (high seq scan)
    if is_rule_enabled("T004").unwrap_or(true) {
        match execute_t004_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T004 failed: {e}")),
        }
    }

    // T005: Tables with fk outside its schema.
    if is_rule_enabled("T005").unwrap_or(true) {
        match execute_t005_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T005 failed: {e}")),
        }
    }

    // T006: Tables with unused indexes.
    if is_rule_enabled("T006").unwrap_or(true) {
        match execute_t006_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T006 failed: {e}")),
        }
    }

    // T007: Tables with unused indexes.
    if is_rule_enabled("T007").unwrap_or(true) {
        match execute_t007_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T007 failed: {e}")),
        }
    }

    // T008: Tables with role not granted.
    if is_rule_enabled("T008").unwrap_or(true) {
        match execute_t008_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T008 failed: {e}")),
        }
    }

    Ok(results)
}

pub fn execute_schema_rules() -> Result<Vec<RuleResult>, String> {
    let mut results = Vec::new();

    // S001: Schemas without default role grants
    if is_rule_enabled("S001").unwrap_or(true) {
        match execute_s001_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("S001 failed: {e}")),
        }
    }

    // S002: Schemas prefixed/suffixed with environment names
    if is_rule_enabled("S002").unwrap_or(true) {
        match execute_s002_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("S002 failed: {e}")),
        }
    }

    Ok(results)
}

fn execute_rule(ruleid: &str, all_sql: &str, wrong_sql: &str) -> Result<Option<RuleResult>, String> {
    // Debug: Log function entry
    pgrx::debug1!("execute_rule; Starting execution for rule {}", ruleid);

    let (warning_threshold, error_threshold, rule_message) = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved thresholds for {} - warning: {}, error: {}",
                        ruleid, config.0, config.1);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        pgrx::debug1!("execute_rule; Executing all items for {}", ruleid);
        let all_sql: i64 = client
            .select(all_sql, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        pgrx::debug1!("execute_rule; all items result for {}: {}", ruleid, all_sql);

        pgrx::debug1!("execute_rule; Executing wrong for {}", ruleid);
        let wrong_sql: i64 = client
            .select(wrong_sql, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        pgrx::debug1!("execute_rule; wrong items result for {}: {}", ruleid, wrong_sql);

        if all_sql > 0 {
            let percentage = (wrong_sql * 100) / all_sql;

            pgrx::debug1!("execute_rule; Calculated percentage for {}: {}% (all: {}, wrong: {})",
                        ruleid, percentage, all_sql, wrong_sql);

            // Check error threshold first (higher severity)
            if percentage >= error_threshold {
                pgrx::debug1!("execute_rule; {} triggered ERROR threshold ({}% >= {}%)",
                            ruleid, percentage, error_threshold);

                // Replace placeholders in rule message
                let formatted_message = rule_message
                    .replace("{0}", &wrong_sql.to_string())
                    .replace("{1}", &all_sql.to_string())
                    .replace("{2}", "error")
                    .replace("{3}", &percentage.to_string());

                pgrx::debug1!("execute_rule; {} message template '{}' -> '{}'",
                            ruleid, rule_message, formatted_message);

                return Ok(Some(RuleResult {
                    ruleid: ruleid.to_string(),
                    level: "error".to_string(),
                    message: formatted_message,
                    count: Some(wrong_sql),
                }));
            }
            // Check warning threshold
            else if percentage >= warning_threshold {
                pgrx::debug1!("execute_rule; {} triggered WARNING threshold ({}% >= {}%)",
                            ruleid, percentage, warning_threshold);

                // Replace placeholders in rule message
                let formatted_message = rule_message
                    .replace("{0}", &wrong_sql.to_string())
                    .replace("{1}", &all_sql.to_string())
                    .replace("{2}", "warning")
                    .replace("{3}", &percentage.to_string());

                pgrx::debug1!("execute_rule; {} message template '{}' -> '{}'",
                            ruleid, rule_message, formatted_message);

                return Ok(Some(RuleResult {
                    ruleid: ruleid.to_string(),
                    level: "warning".to_string(),
                    message: formatted_message,
                    count: Some(wrong_sql),
                }));
            } else {
                pgrx::debug1!("execute_rule; {} passed all thresholds ({}% < warning {}%)",
                            ruleid, percentage, warning_threshold);
            }
        } else {
            pgrx::debug1!("execute_rule; {} skipped - no data found (wrong = 0)", ruleid);
        }

        Ok(None)
    });

    match result {
        Ok(res) => {
            pgrx::debug1!("execute_rule; {} completed successfully", ruleid);
            Ok(res)
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; {} failed with database error: {}", ruleid, e);
            Err(format!("Database error: {e}"))
        },
    }
}

fn execute_c001_rule() -> Result<Option<RuleResult>, String> {
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        for row in client.select(C001_SQL, None, &[])? {
            let max_connections: i32 = row.get(1)?.unwrap_or(100);
            let work_mem_str: String = row.get(2)?.unwrap_or("4MB".to_string());

            // Convert work_mem to MB for calculations
            let work_mem_mb = parse_work_mem_to_mb(&work_mem_str);

            // Calculate potential memory usage: max_connections * work_mem * 4 operations
            let potential_memory_mb = max_connections as f64 * work_mem_mb * 4.0;

            // Check for dangerous memory configurations
            if potential_memory_mb > 8192.0 {
                // > 8GB potential usage - CRITICAL
                return Ok(Some(RuleResult {
                    ruleid: "C001".to_string(),
                    level: "error".to_string(),
                    message: format!(
                        "CRITICAL: Potential memory usage > 8GB ({:.0}MB). max_connections({}) * work_mem({}) * 4 operations = {:.0}MB. Risk of out-of-memory errors.",
                        potential_memory_mb, max_connections, work_mem_str, potential_memory_mb
                    ),
                    count: Some(potential_memory_mb as i64),
                }));
            } else if potential_memory_mb > 4096.0 {
                // > 4GB potential usage - WARNING
                return Ok(Some(RuleResult {
                    ruleid: "C001".to_string(),
                    level: "warning".to_string(),
                    message: format!(
                        "HIGH: Potential memory usage > 4GB ({:.0}MB). max_connections({}) * work_mem({}) * 4 operations = {:.0}MB. Monitor memory usage closely.",
                        potential_memory_mb, max_connections, work_mem_str, potential_memory_mb
                    ),
                    count: Some(potential_memory_mb as i64),
                }));
            } else if potential_memory_mb > 2048.0 {
                // > 2GB potential usage - CAUTION
                return Ok(Some(RuleResult {
                    ruleid: "C001".to_string(),
                    level: "warning".to_string(),
                    message: format!(
                        "MODERATE: Potential memory usage > 2GB ({:.0}MB). max_connections({}) * work_mem({}) * 4 operations = {:.0}MB. Consider connection pooling.",
                        potential_memory_mb, max_connections, work_mem_str, potential_memory_mb
                    ),
                    count: Some(potential_memory_mb as i64),
                }));
            } else if max_connections > 500 {
                // High connection count without excessive memory usage
                return Ok(Some(RuleResult {
                    ruleid: "C001".to_string(),
                    level: "info".to_string(),
                    message: format!(
                        "HIGH CONNECTION COUNT: {} connections configured. Memory usage appears safe ({:.0}MB potential), but consider connection pooling for better performance.",
                        max_connections, potential_memory_mb
                    ),
                    count: Some(max_connections as i64),
                }));
            }
        }
        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

// Helper function to parse work_mem string to MB
fn parse_work_mem_to_mb(work_mem_str: &str) -> f64 {
    let work_mem_upper = work_mem_str.to_uppercase();

    if work_mem_upper.ends_with("GB") {
        work_mem_upper
            .trim_end_matches("GB")
            .parse::<f64>()
            .unwrap_or(4.0) * 1024.0
    } else if work_mem_upper.ends_with("MB") {
        work_mem_upper
            .trim_end_matches("MB")
            .parse::<f64>()
            .unwrap_or(4.0)
    } else if work_mem_upper.ends_with("KB") {
        work_mem_upper
            .trim_end_matches("KB")
            .parse::<f64>()
            .unwrap_or(4096.0) / 1024.0
    } else {
        // Assume bytes if no unit
        work_mem_str
            .parse::<f64>()
            .unwrap_or(4194304.0) / 1024.0 / 1024.0
    }
}

fn execute_t001_rule() -> Result<Option<RuleResult>, String> {
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut tables = Vec::new();

        for row in client.select(T001_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            tables.push(format!("{schema}.{table}"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T001".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} tables without primary key: {}",
                    tables.join(", ")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t002_rule() -> Result<Option<RuleResult>, String> {
    // T002: Tables with redundant indexes

    let ruleid = "T002";

    let rule_message = match get_rule_message(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved message for {} - message: {}",
                        ruleid, config);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {ruleid} configuration: {e}"));
        }
    };

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        for row in client.select(T002_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let redundant_index: String = row.get(3)?.unwrap_or_default();
            let superset_index: String = row.get(4)?.unwrap_or_default();
            let redundant_index_def: String = row.get(5)?.unwrap_or_default();
            let superset_index_def: String = row.get(6)?.unwrap_or_default();

            details.push(
                rule_message
                    .replace("{schema}", &schema)
                    .replace("{table}", &table)
                    .replace("{redundant_index}", &redundant_index)
                    .replace("{superset_index}", &superset_index)
                    .replace("{redundant_index_def}", &redundant_index_def)
                    .replace("{superset_index_def}", &superset_index_def)
            );
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} redundant idx in table: \n{} \n",
                    count,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t003_rule() -> Result<Option<RuleResult>, String> {
    // T003: Tables with missing idx on foreign key columns

    let rule_id = "T003";

    let rule_message = match get_rule_message(rule_id) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved message for {} - message: {}",
                        rule_id, config);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", rule_id, e);
            return Err(format!("Failed to get {rule_id} configuration: {e}"));
        }
    };

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        for row in client.select(T003_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let constraint_name: String = row.get(3)?.unwrap_or_default();

            details.push(
                rule_message
                    .replace("{schema}", &schema)
                    .replace("{table}", &table)
                    .replace("{constraint_name}", &constraint_name)
            );
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: rule_id.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} foreign key(s) without index in table: \n{} \n",
                    count,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t004_rule() -> Result<Option<RuleResult>, String> {
    // T004: Tables with potential missing indexes (high seq scan)

    let ruleid = "T004";

    let (warning_threshold, error_threshold, rule_message) = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved thresholds for {} - warning: {}, error: {}",
                        ruleid, config.0, config.1);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };


    pgrx::debug1!("execute_t004_rule; Starting execution for rule {}", ruleid);
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();
        let mut max_level = "info".to_string();
        pgrx::debug1!("execute_t004_rule; Executing SQL: {}", T004_SQL);
        for row in client.select(T004_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let seq_scan_percentage: f64 = row.get(3)?.unwrap_or_default();

            pgrx::debug1!(
                "execute_t004_rule; Row: schema={}, table={}, seq_scan_percentage={}",
                schema, table, seq_scan_percentage
            );

            if seq_scan_percentage >= error_threshold as f64 {
                pgrx::debug1!(
                    "execute_t004_rule; {}.{} triggered ERROR threshold ({} >= {})",
                    schema, table, seq_scan_percentage, error_threshold
                );
                details.push(
                    rule_message
                        .replace("{schema}", &schema)
                        .replace("{table}", &table)
                        .replace("{log_level}", "error")
                        .replace("{seq_scan_percentage}", &seq_scan_percentage.to_string())
                );
                count += 1;
                max_level = "error".to_string();
            } else if seq_scan_percentage >= warning_threshold as f64 && seq_scan_percentage < error_threshold as f64 {
                pgrx::debug1!(
                    "execute_t004_rule; {}.{} triggered WARNING threshold ({} >= {})",
                    schema, table, seq_scan_percentage, warning_threshold
                );
                details.push(
                    rule_message
                        .replace("{schema}", &schema)
                        .replace("{table}", &table)
                        .replace("{log_level}", "warning")
                        .replace("{seq_scan_percentage}", &seq_scan_percentage.to_string())
                );
                count += 1;
                if max_level != "error" {
                    max_level = "warning".to_string();
                }
            } else {
                pgrx::debug1!(
                    "execute_t004_rule; {}.{} passed all thresholds ({} < warning {})",
                    schema, table, seq_scan_percentage, warning_threshold
                );
            }
        }

        if count > 0 {
            pgrx::debug1!(
                "execute_t004_rule; Found {} table(s) with potential missing index.", count
            );
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: max_level,
                message: format!(
                    "Found {} table(s) with potential missing index (seq scan > threshold): \n{} \n",
                    count,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        pgrx::debug1!("execute_t004_rule; No tables found with missing index.");
        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}


fn execute_t005_rule() -> Result<Option<RuleResult>, String> {
    // T005: Tables with fk outside its schema.

    let ruleid = "T005";

    let rule_message = match get_rule_message(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved message for {} - message: {}",
                        ruleid, config);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };


    pgrx::debug1!("execute_t005_rule; Starting execution for rule {}", ruleid);
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();
        pgrx::debug1!("execute_t005_rule; Executing SQL: {}", T005_SQL);
        for row in client.select(T005_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let constraint_name: String = row.get(3)?.unwrap_or_default();
            let referenced_schema: String = row.get(4)?.unwrap_or_default();
            let referenced_table: String = row.get(5)?.unwrap_or_default();

            pgrx::debug1!(
                "execute_t005_rule; Row: schema={}, table={}, referenced_schema={}, referenced_table={}",
                schema, table, referenced_schema, referenced_table
            );
            details.push(
                rule_message
                    .replace("{schema}", &schema)
                    .replace("{table_name}", &table)
                    .replace("{constraint_name}", &constraint_name)
                    .replace("{referenced_schema}", &referenced_schema)
                    .replace("{referenced_table}", &referenced_table)
            );
            count += 1;
        }


        if count > 0 {
            pgrx::debug1!(
                "execute_t005_rule; Found {} table(s) with foreign keys outside their schema.", count
            );
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} table(s) with fk outside its schema : \n{} \n",
                    count,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        pgrx::debug1!("execute_t005_rule; No tables found with foreign keys outside their schema.");
        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t006_rule() -> Result<Option<RuleResult>, String> {
    // T006: Tables with unused indexes.

    let ruleid = "T006";

    let (warning_threshold, error_threshold, rule_message) = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved thresholds for {} - warning: {}, error: {}",
                        ruleid, config.0, config.1);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };

    // Use warning_threshold as minimum index size in bytes (e.g., warning_threshold * 1024 * 1024 for MB)
    let min_index_size_bytes = warning_threshold * 1024 * 1024; // Convert threshold to bytes (assuming threshold is in MB)

    pgrx::debug1!("execute_t006_rule; Starting execution for rule {} with min_index_size: {} bytes", ruleid, min_index_size_bytes);
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();
        let mut max_level = "info".to_string();
        for row in client.select(T006_SQL, None, &[min_index_size_bytes.into()])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let index_name: String = row.get(3)?.unwrap_or_default();
            let index_size: i64 = row.get(4)?.unwrap_or_default();

            pgrx::debug1!(
                "execute_t006_rule; Row: schema={}, table={}, index_name={}, index_size={}",
                schema, table, index_name, index_size
            );

            // Convert index size to MB for threshold comparison
            let index_size_mb = index_size as f64 / (1024.0 * 1024.0);

            if index_size_mb >= error_threshold as f64 {
                pgrx::debug1!(
                    "execute_t006_rule; {}.{}.{} triggered ERROR threshold ({}MB >= {}MB)",
                    schema, table, index_name, index_size_mb, error_threshold
                );
                details.push(
                    rule_message
                        .replace("{schema}", &schema)
                        .replace("{table}", &table)
                        .replace("{index_name}", &index_name)
                        .replace("{index_size_mb}", &format!("{:.2}", index_size_mb))
                        .replace("{log_level}", "error")
                        .replace("{level_size}", &format!("{}", error_threshold))
                );
                count += 1;
                max_level = "error".to_string();
            } else if index_size_mb >= warning_threshold as f64 {
                pgrx::debug1!(
                    "execute_t006_rule; {}.{}.{} triggered WARNING threshold ({}MB >= {}MB)",
                    schema, table, index_name, index_size_mb, warning_threshold
                );
                details.push(
                    rule_message
                        .replace("{schema}", &schema)
                        .replace("{table}", &table)
                        .replace("{index_name}", &index_name)
                        .replace("{index_size_mb}", &format!("{:.2}", index_size_mb))
                        .replace("{log_level}", "warning")
                        .replace("{level_size}", &format!("{}", warning_threshold))
                );
                count += 1;
                if max_level != "error" {
                    max_level = "warning".to_string();
                }
            } else {
                pgrx::debug1!(
                    "execute_t006_rule; {}.{}.{} passed all thresholds ({}MB < warning {}MB)",
                    schema, table, index_name, index_size_mb, warning_threshold
                );
            }
        }

        if count > 0 {
            pgrx::debug1!(
                "execute_t006_rule; Found {} unused index(es).", count
            );
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: max_level,
                message: format!(
                    "Found {} unused index(es) (size >= {}MB threshold): \n{} \n",
                    count,
                    warning_threshold,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        pgrx::debug1!("execute_t006_rule; No unused indexes found.");
        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}


fn execute_t007_rule() -> Result<Option<RuleResult>, String> {
    // T007: Tables with fk mismatch

    let ruleid = "T007";

    let rule_message = match get_rule_message(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved message for {} - message: {}",
                        ruleid, config);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {ruleid} configuration: {e}"));
        }
    };

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        for row in client.select(T007_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let constraint_name: String = row.get(3)?.unwrap_or_default();
            let column_name: String = row.get(4)?.unwrap_or_default();
            let col1_datatype: String = row.get(5)?.unwrap_or_default();
            let ref_table: String = row.get(6)?.unwrap_or_default();
            let ref_column: String = row.get(7)?.unwrap_or_default();
            let ref_type: String = row.get(8)?.unwrap_or_default();
            pgrx::debug1!(
                "execute_t007_rule; Row: schema={}, table={}, constraint_name={}, column_name={}, col1_datatype={}, ref_table={}, ref_column={}, ref_type={}",
                schema, table, constraint_name, column_name, col1_datatype, ref_table, ref_column, ref_type
            );
            details.push(
                rule_message
                    .replace("{schema}", &schema)
                    .replace("{table}", &table)
                    .replace("{constraint_name}", &constraint_name)
                    .replace("{column_name}", &column_name)
                    .replace("{col1_datatype}", &col1_datatype)
                    .replace("{ref_table}", &ref_table)
                    .replace("{ref_column}", &ref_column)
                    .replace("{ref_type}", &ref_type)
            );
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} redundant idx in table: \n{} \n",
                    count,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t008_rule() -> Result<Option<RuleResult>, String> {
    // T008: Tables with role not granted.

    let ruleid = "T008";

    let rule_message = match get_rule_message(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_rule; Retrieved message for {} - message: {}",
                        ruleid, config);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {ruleid} configuration: {e}"));
        }
    };

    pgrx::debug1!("execute_t008_rule; Starting execution for rule {}", ruleid);
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();
        pgrx::debug1!("execute_t008_rule; Executing SQL: {}", T008_SQL);
        for row in client.select(T008_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            pgrx::debug1!(
                "execute_t008_rule; Row: schema={}, table={}",
                schema, table
            );

            details.push(
                rule_message
                    .replace("{schema}", &schema)
                    .replace("{table}", &table)
            );
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} table without role associated: \n{} \n",
                    count,
                    details.join("\n")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => {
            pgrx::debug1!("execute_t008_rule; Rule {} completed successfully with result: {:?}", ruleid, res);
            Ok(res)
        },
        Err(e) => {
            pgrx::debug1!("execute_t008_rule; Rule {} failed with database error: {}", ruleid, e);
            Err(format!("Database error: {e}"))
        },
    }
}


// fn execute_t010_rule() -> Result<Option<RuleResult>, String> {
//     // T010: Tables using reserved keywords
//     let reserved_keywords = vec![
//         "ALL",
//         "ANALYSE",
//         "ANALYZE",
//         "AND",
//         "ANY",
//         "ARRAY",
//         "AS",
//         "ASC",
//         "ASYMMETRIC",
//         "AUTHORIZATION",
//         "BINARY",
//         "BOTH",
//         "CASE",
//         "CAST",
//         "CHECK",
//         "COLLATE",
//         "COLLATION",
//         "COLUMN",
//         "CONCURRENTLY",
//         "CONSTRAINT",
//         "CREATE",
//         "CROSS",
//         "CURRENT_CATALOG",
//         "CURRENT_DATE",
//         "CURRENT_ROLE",
//         "CURRENT_SCHEMA",
//         "CURRENT_TIME",
//         "CURRENT_TIMESTAMP",
//         "CURRENT_USER",
//         "DEFAULT",
//         "DEFERRABLE",
//         "DESC",
//         "DISTINCT",
//         "DO",
//         "ELSE",
//         "END",
//         "EXCEPT",
//         "FALSE",
//         "FETCH",
//         "FOR",
//         "FOREIGN",
//         "FREEZE",
//         "FROM",
//         "FULL",
//         "GRANT",
//         "GROUP",
//         "HAVING",
//         "ILIKE",
//         "IN",
//         "INITIALLY",
//         "INNER",
//         "INTERSECT",
//         "INTO",
//         "IS",
//         "ISNULL",
//         "JOIN",
//         "LATERAL",
//         "LEADING",
//         "LEFT",
//         "LIKE",
//         "LIMIT",
//         "LOCALTIME",
//         "LOCALTIMESTAMP",
//         "NATURAL",
//         "NOT",
//         "NOTNULL",
//         "NULL",
//         "OFFSET",
//         "ON",
//         "ONLY",
//         "OR",
//         "ORDER",
//         "OUTER",
//         "OVERLAPS",
//         "PLACING",
//         "PRIMARY",
//         "REFERENCES",
//         "RETURNING",
//         "RIGHT",
//         "SELECT",
//         "SESSION_USER",
//         "SIMILAR",
//         "SOME",
//         "SYMMETRIC",
//         "TABLE",
//         "TABLESAMPLE",
//         "THEN",
//         "TO",
//         "TRAILING",
//         "TRUE",
//         "UNION",
//         "UNIQUE",
//         "USER",
//         "USING",
//         "VARIADIC",
//         "VERBOSE",
//         "WHEN",
//         "WHERE",
//         "WINDOW",
//         "WITH",
//     ];

//     // Read SQL template from file
//     let sql_template = T010_SQL;

//     // Create keyword check conditions
//     let keyword_conditions_tables: Vec<String> = reserved_keywords
//         .iter()
//         .map(|kw| format!("UPPER(table_name) = '{kw}'"))
//         .collect();
//     let keyword_conditions_columns: Vec<String> = reserved_keywords
//         .iter()
//         .map(|kw| format!("UPPER(column_name) = '{kw}'"))
//         .collect();

//     let keyword_clause_tables = keyword_conditions_tables.join(" OR ");
//     let keyword_clause_columns = keyword_conditions_columns.join(" OR ");

//     let reserved_keyword_query = sql_template
//         .replace("{KEYWORD_CONDITIONS_TABLES}", &keyword_clause_tables)
//         .replace("{KEYWORD_CONDITIONS_COLUMNS}", &keyword_clause_columns);

//     let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
//         let mut count = 0i64;
//         let mut violations = Vec::new();

//         for row in client.select(&reserved_keyword_query, None, &[])? {
//             let schema: String = row.get(1)?.unwrap_or_default();
//             let table: String = row.get(2)?.unwrap_or_default();
//             let object_type: String = row.get(3)?.unwrap_or_default();
//             violations.push(format!("{schema}.{table} ({object_type})"));
//             count += 1;
//         }

//         if count > 0 {
//             return Ok(Some(RuleResult {
//                 ruleid: "T010".to_string(),
//                 level: "error".to_string(),
//                 message: format!(
//                     "Found {count} database objects using reserved keywords: {}",
//                     violations.join(", ")
//                 ),
//                 count: Some(count),
//             }));
//         }

//         Ok(None)
//     });

//     match result {
//         Ok(res) => Ok(res),
//         Err(e) => Err(format!("Database error: {e}")),
//     }
// }

// fn execute_t012_rule() -> Result<Option<RuleResult>, String> {
//     // T012: Tables with sensitive columns (requires anon extension)

//     // First check if anon extension is available
//     let check_anon_query = "
//         SELECT count(*) as ext_count
//         FROM pg_extension
//         WHERE extname = 'anon'";

//     let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
//         let anon_count: i64 = client
//             .select(check_anon_query, None, &[])?
//             .first()
//             .get::<i64>(1)?
//             .unwrap_or(0);

//         if anon_count == 0 {
//             return Ok(Some(RuleResult {
//                 ruleid: "T012".to_string(),
//                 level: "info".to_string(),
//                 message: "Anon extension not found. Install postgresql-anonymizer to detect sensitive columns".to_string(),
//                 count: Some(0),
//             }));
//         }

//         // If anon extension is available, try to detect sensitive columns
//         let mut count = 0i64;
//         let mut sensitive_data = Vec::new();

//         for row in client.select(T012_SQL, None, &[])? {
//             let schema: String = row.get(1)?.unwrap_or_default();
//             let table: String = row.get(2)?.unwrap_or_default();
//             let column: String = row.get(3)?.unwrap_or_default();
//             let category: String = row.get(4)?.unwrap_or_default();
//             sensitive_data.push(format!("{schema}.{table}.{column} ({category})"));
//             count += 1;
//         }

//         if count > 0 {
//             return Ok(Some(RuleResult {
//                 ruleid: "T012".to_string(),
//                 level: "warning".to_string(),
//                 message: format!(
//                     "Found {count} potentially sensitive columns: {}",
//                     sensitive_data.join(", ")
//                 ),
//                 count: Some(count),
//             }));
//         }

//         Ok(None)
//     });

//     match result {
//         Ok(res) => Ok(res),
//         Err(_e) => {
//             // If there's an error, it might be because anon functions don't exist
//             // Return an info message instead of failing
//             Ok(Some(RuleResult {
//                 ruleid: "T012".to_string(),
//                 level: "info".to_string(),
//                 message: "Could not check for sensitive columns. Ensure anon extension is properly configured".to_string(),
//                 count: Some(0),
//             }))
//         }
//     }
// }

fn execute_s001_rule() -> Result<Option<RuleResult>, String> {
    // S001: Schemas without default role grants
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut schemas = Vec::new();

        for row in client.select(S001_SQL, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            schemas.push(schema);
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "S001".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} schemas without default role grants: {}",
                    schemas.join(", ")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_s002_rule() -> Result<Option<RuleResult>, String> {
    // S002: Schemas prefixed/suffixed with environment names
    let environment_keywords = vec![
        "staging",
        "stg",
        "preprod",
        "prod",
        "production",
        "dev",
        "development",
        "test",
        "testing",
        "sandbox",
        "sbox",
        "demo",
        "uat",
        "qa",
    ];

    // Read SQL template from file
    let sql_template = S002_SQL;

    // Build the query conditions for environment patterns
    let prefix_conditions: Vec<String> = environment_keywords
        .iter()
        .map(|env| format!("nspname ILIKE '{env}_%'"))
        .collect();
    let suffix_conditions: Vec<String> = environment_keywords
        .iter()
        .map(|env| format!("nspname ILIKE '%_{env}'"))
        .collect();

    let all_conditions = [prefix_conditions, suffix_conditions].concat();
    let condition_clause = all_conditions.join(" OR ");

    let environment_schema_query =
        sql_template.replace("{ENVIRONMENT_CONDITIONS}", &condition_clause);

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut schemas = Vec::new();

        for row in client.select(&environment_schema_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            schemas.push(schema);
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "S002".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} schemas with environment prefixes/suffixes: {}",
                    schemas.join(", ")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

// Output and SARIF functions
pub fn output_results_to_prompt(results: Vec<RuleResult>) -> Result<bool, String> {
    if results.is_empty() {
        pgrx::notice!("✅ No issues found - database schema looks good!");
        return Ok(true);
    }

    pgrx::notice!("🔍 pglinter found {} issue(s):", results.len());
    pgrx::notice!("{}", "=".repeat(50));

    for result in &results {
        let level_icon = match result.level.as_str() {
            "error" => "❌",
            "warning" => "⚠️ ",
            "info" => "ℹ️ ",
            _ => "📝",
        };

        pgrx::notice!(
            "{} [{}] {}: {}",
            level_icon,
            result.ruleid,
            result.level.to_uppercase(),
            result.message
        );
    }

    pgrx::notice!("{}", "=".repeat(50));

    // Summary by level
    let mut error_count = 0;
    let mut warning_count = 0;
    let mut info_count = 0;

    for result in &results {
        match result.level.as_str() {
            "error" => error_count += 1,
            "warning" => warning_count += 1,
            "info" => info_count += 1,
            _ => {}
        }
    }

    pgrx::notice!(
        "📊 Summary: {} error(s), {} warning(s), {} info",
        error_count,
        warning_count,
        info_count
    );

    if error_count > 0 {
        pgrx::notice!("🔴 Critical issues found - please review and fix errors");
    } else if warning_count > 0 {
        pgrx::notice!("🟡 Some warnings found - consider reviewing for optimization");
    } else {
        pgrx::notice!("🟢 Only informational messages - good job!");
    }

    Ok(true)
}

// Enhanced generate_sarif_output that handles optional file output
pub fn generate_sarif_output_optional(
    results: Vec<RuleResult>,
    output_file: Option<&str>,
) -> Result<bool, String> {
    match output_file {
        Some(file_path) => generate_sarif_output(results, file_path),
        None => output_results_to_prompt(results),
    }
}

pub fn generate_sarif_output(results: Vec<RuleResult>, output_file: &str) -> Result<bool, String> {
    let sarif_results: Vec<serde_json::Value> = results
        .into_iter()
        .map(|result| {
            json!({
                "ruleId": result.ruleid,
                "level": result.level,
                "message": {
                    "text": result.message
                },
                "locations": [{
                    "physicalLocation": {
                        "artifactLocation": {
                            "uri": "database"
                        }
                    }
                }]
            })
        })
        .collect();

    let sarif_doc = json!({
        "version": "2.1.0",
        "runs": [{
            "tool": {
                "driver": {
                    "name": "pglinter",
                    "version": "1.0.0",
                    "informationUri": "https://github.com/decathlon/pglinter"
                }
            },
            "results": sarif_results
        }]
    });

    match File::create(output_file) {
        Ok(mut file) => match file.write_all(sarif_doc.to_string().as_bytes()) {
            Ok(_) => Ok(true),
            Err(e) => Err(format!("Failed to write file: {e}")),
        },
        Err(e) => Err(format!("Failed to create file: {e}")),
    }
}
