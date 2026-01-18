use pgrx::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::fs::File;
use std::io::Write;

// Import the rule management functions
use crate::manage_rules::is_rule_enabled;

/// Executes the q3 SQL query for a given ruleId, formats the result dataset into a string with each row separated by a newline, and returns it.
pub fn execute_and_format_dataset(ruleid: &str) -> Result<String, String> {
    // Fetch q3 from pglinter.rules
    pgrx::debug1!("execute_and_format_dataset; Retrieved q3 for {}", ruleid);
    let q3_query = "SELECT q3 FROM pglinter.rules WHERE code = $1";
    let q3: String = match Spi::connect(|client| {
        let mut rows = client.select(q3_query, None, &[ruleid.into()])?;
        if let Some(row) = rows.next() {
            match row.get::<String>(1)? {
                Some(q) if !q.trim().is_empty() => Ok::<Option<String>, spi::SpiError>(Some(q)),
                _ => Ok::<Option<String>, spi::SpiError>(None),
            }
        } else {
            Ok(None)
        }
    }) {
        Ok(Some(val)) => val,
        _ => return Err(format!("No q3 query found for rule '{}'.", ruleid)),
    };
    // Execute q3 and format dataset
    let result: Result<String, spi::SpiError> = Spi::connect(|client| {
        let mut output = String::new();
        let rows = client.select(&q3, None, &[])?;
        pgrx::debug1!("found {} rows in q3 result set", rows.len());
        for row in rows {
            let ncols = row.columns();
            pgrx::debug1!("found {} cols in q3 result set", ncols);
            let mut row_str = Vec::new();
            for col in 1..=ncols {
                //pgrx::debug1!("column {}", col);
                let val: Option<String> = row.get::<String>(col)?;
                let val_str = val.unwrap_or_default();
                pgrx::debug1!("column {}, value: {:?}", col, val_str);
                row_str.push(val_str.clone());
            }
            output.push_str(&row_str.join("."));
            output.push('\n');
        }
        pgrx::debug1!("output dataset:\n{}", output);
        Ok(output)
    });
    match result {
        Ok(s) => Ok(s),
        Err(e) => Err(format!("Database error executing q3: {e}")),
    }
}

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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleResult {
    pub ruleid: String,
    pub level: String,
    pub message: String,
    pub count: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct RuleData {
    pub code: String,
    //pub name: String,
    pub q1: String,
    pub q2: Option<String>,
    pub scope: String,
}

fn execute_q1_rule_dynamic(
    scope: &str,
    ruleid: &str,
    q1: &str,
) -> Result<Option<RuleResult>, String> {
    let config = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!(
                "get_rule_config; Retrieved rule_message for {}: {}",
                ruleid,
                config.2
            );
            config
        }
        Err(e) => {
            pgrx::debug1!(
                "execute_q1_rule_dynamic; Failed to get configuration for {}: {}",
                ruleid,
                e
            );
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };
    let (warning_level, error_level, rule_message) = config;

    // Check if query contains parameters
    let has_parameters = q1.contains("$1");

    if has_parameters {
        pgrx::debug1!(
            "execute_q1_rule_dynamic; {} query contains parameters, handling special case",
            ruleid
        );
        return execute_q1_rule_with_params(
            scope,
            ruleid,
            q1,
            warning_level,
            error_level,
            &rule_message,
        );
    }

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        for row in client.select(q1, None, &[])? {
            // Try to get the first column as message, fallback to empty string if not available
            let message: String = row
                .get::<&str>(1)
                .unwrap_or(None)
                .map(|s| s.to_string())
                .unwrap_or_else(|| format!("Row {}", count + 1));
            details.push(message);
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "{} {} {} : \n{} \n",
                    scope,
                    rule_message,
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

/// Execute q1 rule with parameters (for rules that need special parameter handling)
fn execute_q1_rule_with_params(
    scope: &str,
    ruleid: &str,
    q1: &str,
    warning_level: i64,
    error_level: i64,
    rule_message: &str,
) -> Result<Option<RuleResult>, String> {
    // Get parameters based on rule type
    let params = get_rule_parameters(ruleid, warning_level, error_level)?;

    pgrx::debug1!(
        "execute_q1_rule_with_params; Executing {} with {} parameters",
        ruleid,
        params.len()
    );

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        // Handle parameterized queries
        let rows = if params.is_empty() {
            client.select(q1, None, &[])?
        } else {
            // For now, handle the most common case of a single i64 parameter
            if params.len() == 1 {
                client.select(q1, None, &[params[0].into()])?
            } else {
                // Return empty iterator for unsupported parameter counts
                return Ok(None);
            }
        };

        for row in rows {
            // Try to get the first column as message, fallback to empty string if not available
            let message: String = row
                .get::<&str>(0)
                .unwrap_or(None)
                .map(|s| s.to_string())
                .unwrap_or_else(|| format!("Row {}", count + 1));
            details.push(message);
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: ruleid.to_string(),
                level: "warning".to_string(),
                message: format!(
                    "{} {} {} : \n{} \n",
                    scope,
                    rule_message,
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

/// Get parameters for specific rules
fn get_rule_parameters(
    ruleid: &str,
    warning_level: i64,
    _error_level: i64,
) -> Result<Vec<i64>, String> {
    match ruleid {
        "T006" => {
            // T006 uses warning/error levels as size thresholds in MB
            // Convert to bytes for pg_relation_size comparison
            Ok(vec![warning_level * 1024 * 1024])
        }
        "T004" => {
            // T004 might use warning_level as percentage threshold
            Ok(vec![warning_level])
        }
        _ => {
            // Default: use warning_level as first parameter
            Ok(vec![warning_level])
        }
    }
}

fn execute_q1_q2_rule_dynamic(
    ruleid: &str,
    q1: &str,
    q2: &str,
) -> Result<Option<RuleResult>, String> {
    // Debug: Log function entry
    pgrx::debug1!(
        "execute_q1_q2_rule_dynamic; Starting execution for rule {}",
        ruleid
    );

    let (warning_threshold, error_threshold, rule_message) = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!(
                "execute_q1_q2_rule_dynamic; Retrieved thresholds for {} - warning: {}, error: {}",
                ruleid,
                config.0,
                config.1
            );
            config
        }
        Err(e) => {
            pgrx::debug1!(
                "execute_q1_q2_rule_dynamic; Failed to get configuration for {}: {}",
                ruleid,
                e
            );
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        pgrx::debug1!(
            "execute_q1_q2_rule_dynamic; Executing total count for {}",
            ruleid
        );
        let q1: i64 = client
            .select(q1, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        pgrx::debug1!(
            "execute_q1_q2_rule_dynamic; total count result for {}: {}",
            ruleid,
            q1
        );

        pgrx::debug1!(
            "execute_q1_q2_rule_dynamic; Executing problem count for {}",
            ruleid
        );
        let q2: i64 = client
            .select(q2, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        pgrx::debug1!(
            "execute_q1_q2_rule_dynamic; problem count result for {}: {}",
            ruleid,
            q2
        );

        if q1 > 0 {
            let percentage = (q2 * 100) / q1;

            pgrx::debug1!("execute_q1_q2_rule_dynamic; Calculated percentage for {}: {}% (total: {}, problem: {})",
                        ruleid, percentage, q1, q2);

            // Replace placeholders in rule message
            let dataset_str = match execute_and_format_dataset(ruleid) {
                Ok(s) => s,
                Err(e) => format!("Error formatting dataset: {}", e),
            };

            // Check error threshold first (higher severity)
            if percentage >= error_threshold {
                pgrx::debug1!(
                    "execute_rule_dynamic; {} triggered ERROR threshold ({}% >= {}%)",
                    ruleid,
                    percentage,
                    error_threshold
                );
                let formatted_message = rule_message
                    .replace("{0}", &q2.to_string())
                    .replace("{1}", &q1.to_string())
                    .replace("{2}", "error")
                    .replace("{3}", &percentage.to_string())
                    .replace("{4}", &dataset_str)
                    .replace("\\n", "\n");

                pgrx::debug1!(
                    "execute_q1_q2_rule_dynamic; {} message template '{}' -> '{}'",
                    ruleid,
                    rule_message,
                    formatted_message
                );

                return Ok(Some(RuleResult {
                    ruleid: ruleid.to_string(),
                    level: "error".to_string(),
                    message: formatted_message,
                    count: Some(q2),
                }));
            }
            // Check warning threshold
            else if percentage >= warning_threshold {
                pgrx::debug1!(
                    "execute_q1_q2_rule_dynamic; {} triggered WARNING threshold ({}% >= {}%)",
                    ruleid,
                    percentage,
                    warning_threshold
                );

                // Replace placeholders in rule message
                let formatted_message = rule_message
                    .replace("{0}", &q2.to_string())
                    .replace("{1}", &q1.to_string())
                    .replace("{2}", "warning")
                    .replace("{3}", &percentage.to_string())
                    .replace("{4}", &dataset_str)
                    .replace("\\n", "\n");

                pgrx::debug1!(
                    "execute_q1_q2_rule_dynamic; {} message template '{}' -> '{}'",
                    ruleid,
                    rule_message,
                    formatted_message
                );

                return Ok(Some(RuleResult {
                    ruleid: ruleid.to_string(),
                    level: "warning".to_string(),
                    message: formatted_message,
                    count: Some(q2),
                }));
            } else {
                pgrx::debug1!(
                    "execute_q1_q2_rule_dynamic; {} passed all thresholds ({}% < warning {}%)",
                    ruleid,
                    percentage,
                    warning_threshold
                );
            }
        } else {
            pgrx::debug1!(
                "execute_q1_q2_rule_dynamic; {} skipped - no data found (total = 0)",
                ruleid
            );
        }

        Ok(None)
    });

    match result {
        Ok(res) => {
            pgrx::debug1!(
                "execute_q1_q2_rule_dynamic; {} completed successfully",
                ruleid
            );
            Ok(res)
        }
        Err(e) => {
            pgrx::debug1!(
                "execute_q1_q2_rule_dynamic; {} failed with database error: {}",
                ruleid,
                e
            );
            Err(format!("Database error: {e}"))
        }
    }
}

/// Execute all BASE scope rules regardless of q2 null status
/// This function combines the logic from execute_q1_q2_rules and execute_q1_rules
/// but filters for BASE scope rules only
pub fn execute_rules(ruleid: Option<&str>) -> Result<Vec<RuleResult>, String> {
    pgrx::debug1!("execute_rule; Starting execution of all rules");
    let filter = ruleid.unwrap_or("");
    let mut results = Vec::new();

    // Query to get all enabled BASE rules with their SQL queries
    let rules_query = "
        SELECT code, q1, q2, scope
        FROM pglinter.rules
        WHERE enable = true
        AND (code = $1 OR $1 = '')
        ORDER BY code";

    let rule_result: Result<Vec<RuleData>, spi::SpiError> = Spi::connect(|client| {
        let mut rules = Vec::new();

        // Fetch all enabled rules for the specified scope
        pgrx::debug1!("execute_rule; Fetching all enabled rules from database",);

        for row in client.select(rules_query, None, &[filter.into()])? {
            let code: String = row.get(1)?.unwrap_or_default();
            let q1: String = row.get(2)?.unwrap_or_default();
            let q2: Option<String> = row.get(3)?;
            let scope: String = row.get(4)?.unwrap_or_default();

            rules.push(RuleData {
                code,
                q1,
                q2,
                scope,
            });
        }

        Ok(rules)
    });

    match rule_result {
        Ok(rules) => {
            pgrx::debug1!("execute_rule; Found {} rules to execute", rules.len());

            for rule in rules {
                // Check if rule is enabled before executing
                if is_rule_enabled(&rule.code)? {
                    pgrx::debug1!("execute_rule; Processing BASE rule: {}", rule.code);

                    // Determine execution pattern based on q2 presence
                    match &rule.q2 {
                        Some(q2) => {
                            // Execute as q1+q2 rule (with thresholds)
                            pgrx::debug1!("execute_rule; Executing {} as Q1+Q2 rule", rule.code);
                            match execute_q1_q2_rule_dynamic(&rule.code, &rule.q1, q2) {
                                Ok(Some(result)) => {
                                    pgrx::debug1!(
                                        "execute_rule; {} produced result: {} - {}",
                                        rule.code,
                                        result.level,
                                        result.message
                                    );
                                    results.push(result);
                                }
                                Ok(None) => {
                                    pgrx::debug1!(
                                        "execute_rule; {} passed thresholds - no issues",
                                        rule.code
                                    );
                                }
                                Err(e) => {
                                    pgrx::debug1!(
                                        "execute_rule; {} failed with error: {}",
                                        rule.code,
                                        e
                                    );
                                    return Err(format!(
                                        "Failed to execute q2 rule {}: {}",
                                        rule.code, e
                                    ));
                                }
                            }
                        }
                        None => {
                            // Execute as q1-only rule (direct warning)
                            pgrx::debug1!("execute_rule; Executing {} as Q1-only rule", rule.code);
                            match execute_q1_rule_dynamic(&rule.scope, &rule.code, &rule.q1) {
                                Ok(Some(result)) => {
                                    pgrx::debug1!(
                                        "execute_rule; {} produced result: {} - {}",
                                        rule.code,
                                        result.level,
                                        result.message
                                    );
                                    results.push(result);
                                }
                                Ok(None) => {
                                    pgrx::debug1!("execute_rule; {} found no issues", rule.code);
                                }
                                Err(e) => {
                                    pgrx::debug1!(
                                        "execute_rule; {} failed with error: {}",
                                        rule.code,
                                        e
                                    );
                                    return Err(format!(
                                        "Failed to execute rule {}: {}",
                                        rule.code, e
                                    ));
                                }
                            }
                        }
                    }
                } else {
                    pgrx::debug1!("execute_rule; Skipping disabled rule: {}", rule.code);
                }
            }
        }
        Err(e) => {
            pgrx::debug1!("execute_rule; Database error while fetching rules: {}", e);
            return Err(format!("Database error: {e}"));
        }
    }

    pgrx::debug1!(
        "execute_rule; Completed execution of rules, found {} issues",
        results.len()
    );

    Ok(results)
}

type ViolationLocation = (i32, i32, i32);
type RuleViolations = (String, Vec<ViolationLocation>);

/// Collects violations for all enabled rules by calling get_violations_for_rule for each rule.
pub fn get_violations() -> Result<Vec<RuleViolations>, String> {
    pgrx::debug1!("get_violations; Starting to collect violations for all enabled rules");
    let rules_query = "SELECT code FROM pglinter.rules WHERE enable = true ORDER BY code";
    let rule_codes: Result<Vec<String>, String> = Spi::connect(|client| {
        let mut codes = Vec::new();
        for row in client.select(rules_query, None, &[])? {
            let code: String = row.get(1)?.unwrap_or_default();
            codes.push(code);
        }
        Ok(codes)
    })
    .map_err(|e: spi::SpiError| format!("Database error fetching rule codes: {e}"));

    let _rule_codes = rule_codes?;

    let mut all_violations = Vec::new();
    for code in _rule_codes {
        match get_violations_for_rule(&code) {
            Ok(violations) => {
                all_violations.push((code.clone(), violations));
            }
            Err(e) => {
                pgrx::debug1!("get_violations; Error for rule {}: {}", code, e);
                // Optionally, you could push an empty vector or skip on error
                all_violations.push((code.clone(), vec![]));
            }
        }
    }
    pgrx::debug1!("get_violations; Completed collecting violations for all rules");
    Ok(all_violations)
}

/// Executes the q4 query for the given rule_id and returns (classid, objid, objsubid) tuples.
/// Returns an error if the rule or q4 is not found, or if the query fails.
pub fn get_violations_for_rule(rule_id: &str) -> Result<Vec<(i32, i32, i32)>, String> {
    pgrx::debug1!("get_violations_for_rule; Starting for rule_id: {}", rule_id);

    // Fetch q4 SQL from the rules table
    let q4_query = "SELECT q4 FROM pglinter.rules WHERE code = $1";

    let q4_sql: Option<String> = match Spi::connect(|client| {
        let mut rows = client.select(q4_query, None, &[rule_id.into()])?;
        if let Some(row) = rows.next() {
            match row.get::<String>(1)? {
                Some(q) if !q.trim().is_empty() => Ok::<Option<String>, spi::SpiError>(Some(q)),
                _ => Ok::<Option<String>, spi::SpiError>(None),
            }
        } else {
            Ok(None)
        }
    }) {
        Ok(Some(val)) => Some(val),
        Ok(None) => None,
        Err(e) => {
            pgrx::debug1!("get_violations_for_rule; SPI error fetching q4: {}", e);
            return Err(format!("SPI error fetching q4: {e}"));
        }
    };

    if q4_sql.is_none() {
        pgrx::debug1!(
            "get_violations_for_rule; No q4 query found for rule_id '{}', returning info message",
            rule_id
        );
        return Ok(vec![]);
    }
    let q4_sql = q4_sql.unwrap();

    // Execute the q4 SQL and collect results
    let result: Result<Vec<(i32, i32, i32)>, String> = Spi::connect(|client| {
        use pgrx::pg_sys::Oid;
        let mut results = Vec::new();
        let query_result = client.select(&q4_sql, None, &[])?;
        for row in query_result {
            let classid_oid = row.get::<Oid>(1)?.unwrap_or(Oid::INVALID);
            let objid_oid = row.get::<Oid>(2)?.unwrap_or(Oid::INVALID);
            let classid = u32::from(classid_oid) as i32;
            let objid = u32::from(objid_oid) as i32;
            let objsubid = row.get::<i32>(3)?.unwrap_or_default();
            results.push((classid, objid, objsubid));
        }
        Ok(results)
    })
    .map_err(|e: spi::SpiError| format!("SPI error executing q4: {e}"));

    match result {
        Ok(res) => {
            pgrx::debug1!(
                "get_violations_for_rule; Completed successfully for rule_id: {} ({} violations)",
                rule_id,
                res.len()
            );
            Ok(res)
        }
        Err(e) => {
            pgrx::debug1!("get_violations_for_rule; Failed with error: {}", e);
            Err(e)
        }
    }
}

pub fn get_sanitized_message(rule_id: &str, classid: i32, objid: i32, objsubid: i32) -> String {
    // Fetch the rule_msg (jsonb) from the rules table as serde_json::Value
    let query = "SELECT rule_msg::TEXT FROM pglinter.rule_messages WHERE code = $1";
    let rule_msg_json: Option<serde_json::Value> = match Spi::connect(|client| {
        let mut rows = client.select(query, None, &[rule_id.into()])?;
        if let Some(row) = rows.next() {
            // Use Option<serde_json::Value> for jsonb
            let val: Option<String> = row.get(1)?;
            let json_val = match val {
                Some(s) => serde_json::from_str(&s).ok(),
                None => None,
            };
            Ok::<Option<serde_json::Value>, spi::SpiError>(json_val)
        } else {
            Ok(None)
        }
    }) {
        Ok(val) => val,
        Err(e) => {
            pgrx::debug1!(
                "get_sanitized_message; Failed to get rule_msg for {}: {}",
                rule_id,
                e
            );
            return format!("[pglinter: error fetching rule message for {}]", rule_id);
        }
    };

    // Optionally, you can fetch a message template from another table if needed
    let message_template = String::new();

    // Helper to resolve object name from classid, objid, objsubid
    fn resolve_object_name(classid: i32, objid: i32, objsubid: i32) -> String {
        // If classid is 1249 (pg_type) and objsubid != 0, treat as 1259 (pg_class) for columns of views/tables
        let (mut classid, objid, objsubid) = (classid, objid, objsubid);
        if classid == 1249 && objsubid != 0 {
            classid = 1259;
        }

        let sql = "SELECT type, schema, name, identity FROM pg_catalog.pg_identify_object($1::oid, $2::oid, $3)";
        let result: Result<Option<(String, String, String, String)>, spi::SpiError> =
            Spi::connect(|client| {
                let try_result = std::panic::catch_unwind(|| {
                    let mut rows = client.select(
                        sql,
                        None,
                        &[classid.into(), objid.into(), objsubid.into()],
                    )?;
                    if let Some(row) = rows.next() {
                        let type_: Option<String> = row.get(1)?;
                        let schema: Option<String> = row.get(2)?;
                        let name: Option<String> = row.get(3)?;
                        let identity: Option<String> = row.get(4)?;
                        Ok(type_
                            .zip(schema)
                            .zip(name)
                            .zip(identity)
                            .map(|(((t, s), n), i)| (t, s, n, i)))
                    } else {
                        Ok(None)
                    }
                });
                match try_result {
                    Ok(inner) => inner,
                    Err(_) => {
                        pgrx::warning!(
                            "pg_identify_object failed for classid={}, objid={}, objsubid={}",
                            classid,
                            objid,
                            objsubid
                        );
                        Ok(None)
                    }
                }
            });
        match result {
            Ok(Some((type_, schema, name, _identity))) => {
                format!("{type_} in schema: {schema} named: {name}")
            }
            _ => {
                pgrx::warning!(
                    "Could not resolve object name for classid={}, objid={}, objsubid={}",
                    classid,
                    objid,
                    objsubid
                );
                format!(
                    "classid={}, objid={}, objsubid={}",
                    classid, objid, objsubid
                )
            }
        }
    }

    let object_name = resolve_object_name(classid, objid, objsubid);

    // Replace placeholders in the message template
    let msg = message_template
        .replace("{object}", &object_name)
        .replace("{0}", &object_name)
        .replace("{classid}", &classid.to_string())
        .replace("{objid}", &objid.to_string())
        .replace("{objsubid}", &objsubid.to_string());

    // Replace placeholders in the rule_msg JSON if present
    let rule_msg_json_replaced = rule_msg_json.map(|mut json_val| {
        // Recursively replace placeholders in all string values
        fn replace_in_json(
            val: &mut serde_json::Value,
            object_name: &str,
            classid: i32,
            objid: i32,
            objsubid: i32,
        ) {
            match val {
                serde_json::Value::String(s) => {
                    let replaced = s
                        .replace("{object}", object_name)
                        .replace("{0}", object_name)
                        .replace("{classid}", &classid.to_string())
                        .replace("{objid}", &objid.to_string())
                        .replace("{objsubid}", &objsubid.to_string());
                    *s = replaced;
                }
                serde_json::Value::Array(arr) => {
                    for v in arr.iter_mut() {
                        replace_in_json(v, object_name, classid, objid, objsubid);
                    }
                }
                serde_json::Value::Object(map) => {
                    for v in map.values_mut() {
                        replace_in_json(v, object_name, classid, objid, objsubid);
                    }
                }
                _ => {}
            }
        }
        replace_in_json(&mut json_val, &object_name, classid, objid, objsubid);
        json_val
    });

    // Return both as a JSON string for now (could be a struct if needed)
    match rule_msg_json_replaced {
        Some(json_val) => serde_json::json!({
            "rule_msg": json_val
        })
        .to_string(),
        None => msg,
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
