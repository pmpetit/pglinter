use pgrx::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::fs::File;
use std::io::Write;

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

#[derive(Debug, Clone)]
pub struct RuleData {
    pub code: String,
    pub name: String,
    pub q1: String,
    pub q2: Option<String>,
    pub scope: String,
}

fn execute_q1_rule_dynamic(scope: &str, ruleid: &str, q1: &str) -> Result<Option<RuleResult>, String> {

    let config = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!("get_rule_config; Retrieved rule_message for {}: {}",
                        ruleid, config.2);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_q1_q2_rule_dynamic; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };
    let (warning_level, error_level, rule_message) = config;

    // Check if query contains parameters
    let has_parameters = q1.contains("$1");

    if has_parameters {
        pgrx::debug1!("execute_q1_rule_dynamic; {} query contains parameters, handling special case", ruleid);
        return execute_q1_rule_with_params(scope, ruleid, q1, warning_level, error_level, &rule_message);
    }

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        for row in client.select(q1, None, &[])? {
            let message: String = row.get(1)?.unwrap_or_default();
            details.push(
                message
            );
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
    rule_message: &str
) -> Result<Option<RuleResult>, String> {

    // Get parameters based on rule type
    let params = get_rule_parameters(ruleid, warning_level, error_level)?;

    pgrx::debug1!("execute_q1_rule_with_params; Executing {} with {} parameters", ruleid, params.len());

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
            let message: String = row.get(1)?.unwrap_or_default();
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
fn get_rule_parameters(ruleid: &str, warning_level: i64, _error_level: i64) -> Result<Vec<i64>, String> {
    match ruleid {
        "T006" => {
            // T006 uses warning/error levels as size thresholds in MB
            // Convert to bytes for pg_relation_size comparison
            Ok(vec![warning_level * 1024 * 1024])
        },
        "T004" => {
            // T004 might use warning_level as percentage threshold
            Ok(vec![warning_level])
        },
        _ => {
            // Default: use warning_level as first parameter
            Ok(vec![warning_level])
        }
    }
}

fn execute_q1_q2_rule_dynamic(ruleid: &str, q1: &str, q2: &str) -> Result<Option<RuleResult>, String> {
    // Debug: Log function entry
    pgrx::debug1!("execute_q1_q2_rule_dynamic; Starting execution for rule {}", ruleid);

    let (warning_threshold, error_threshold, rule_message) = match get_rule_config(ruleid) {
        Ok(config) => {
            pgrx::debug1!("execute_q1_q2_rule_dynamic; Retrieved thresholds for {} - warning: {}, error: {}",
                        ruleid, config.0, config.1);
            config
        },
        Err(e) => {
            pgrx::debug1!("execute_q1_q2_rule_dynamic; Failed to get configuration for {}: {}", ruleid, e);
            return Err(format!("Failed to get {} configuration: {e}", ruleid));
        }
    };

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        pgrx::debug1!("execute_q1_q2_rule_dynamic; Executing total count for {}", ruleid);
        let q1: i64 = client
            .select(q1, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        pgrx::debug1!("execute_q1_q2_rule_dynamic; total count result for {}: {}", ruleid, q1);

        pgrx::debug1!("execute_q1_q2_rule_dynamic; Executing problem count for {}", ruleid);
        let q2: i64 = client
            .select(q2, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        pgrx::debug1!("execute_q1_q2_rule_dynamic; problem count result for {}: {}", ruleid, q2);

        if q1 > 0 {
            let percentage = (q2 * 100) / q1;

            pgrx::debug1!("execute_q1_q2_rule_dynamic; Calculated percentage for {}: {}% (total: {}, problem: {})",
                        ruleid, percentage, q1, q2);

            // Check error threshold first (higher severity)
            if percentage >= error_threshold {
                pgrx::debug1!("execute_rule_dynamic; {} triggered ERROR threshold ({}% >= {}%)",
                            ruleid, percentage, error_threshold);

                // Replace placeholders in rule message
                let formatted_message = rule_message
                    .replace("{0}", &q2.to_string())
                    .replace("{1}", &q1.to_string())
                    .replace("{2}", "error")
                    .replace("{3}", &percentage.to_string());

                pgrx::debug1!("execute_q1_q2_rule_dynamic; {} message template '{}' -> '{}'",
                            ruleid, rule_message, formatted_message);

                return Ok(Some(RuleResult {
                    ruleid: ruleid.to_string(),
                    level: "error".to_string(),
                    message: formatted_message,
                    count: Some(q2),
                }));
            }
            // Check warning threshold
            else if percentage >= warning_threshold {
                pgrx::debug1!("execute_q1_q2_rule_dynamic; {} triggered WARNING threshold ({}% >= {}%)",
                            ruleid, percentage, warning_threshold);

                // Replace placeholders in rule message
                let formatted_message = rule_message
                    .replace("{0}", &q2.to_string())
                    .replace("{1}", &q1.to_string())
                    .replace("{2}", "warning")
                    .replace("{3}", &percentage.to_string());

                pgrx::debug1!("execute_q1_q2_rule_dynamic; {} message template '{}' -> '{}'",
                            ruleid, rule_message, formatted_message);

                return Ok(Some(RuleResult {
                    ruleid: ruleid.to_string(),
                    level: "warning".to_string(),
                    message: formatted_message,
                    count: Some(q2),
                }));
            } else {
                pgrx::debug1!("execute_q1_q2_rule_dynamic; {} passed all thresholds ({}% < warning {}%)",
                            ruleid, percentage, warning_threshold);
            }
        } else {
            pgrx::debug1!("execute_q1_q2_rule_dynamic; {} skipped - no data found (total = 0)", ruleid);
        }

        Ok(None)
    });

    match result {
        Ok(res) => {
            pgrx::debug1!("execute_q1_q2_rule_dynamic; {} completed successfully", ruleid);
            Ok(res)
        },
        Err(e) => {
            pgrx::debug1!("execute_q1_q2_rule_dynamic; {} failed with database error: {}", ruleid, e);
            Err(format!("Database error: {e}"))
        },
    }
}


/// Execute all BASE scope rules regardless of q2 null status
/// This function combines the logic from execute_q1_q2_rules and execute_q1_rules
/// but filters for BASE scope rules only
pub fn execute_rules(scope: &str ) -> Result<Vec<RuleResult>, String> {
    pgrx::debug1!("execute_rule; Starting execution of all {} rules", scope);
    let mut results = Vec::new();

    // Query to get all enabled BASE rules with their SQL queries
    let rules_query = "
        SELECT code, name, q1, q2, scope
        FROM pglinter.rules
        WHERE enable = true
        AND scope = $1
        AND q1 IS NOT NULL
        ORDER BY code";

    let rule_result: Result<Vec<RuleData>, spi::SpiError> = Spi::connect(|client| {
        let mut rules = Vec::new();

        for row in client.select(rules_query, None, &[scope.into()])? {
            let code: String = row.get(1)?.unwrap_or_default();
            let name: String = row.get(2)?.unwrap_or_default();
            let q1: String = row.get(3)?.unwrap_or_default();
            let q2: Option<String> = row.get(4)?;
            let scope: String = row.get(5)?.unwrap_or_default();

            rules.push(RuleData {
                code,
                name,
                q1,
                q2,
                scope,
            });
        }

        Ok(rules)
    });

    match rule_result {
        Ok(rules) => {
            pgrx::debug1!("execute_rule; Found {} {} rules to execute", rules.len(),scope);

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
                                    pgrx::debug1!("execute_rule; {} produced result: {} - {}",
                                                rule.code, result.level, result.message);
                                    results.push(result);
                                },
                                Ok(None) => {
                                    pgrx::debug1!("execute_rule; {} passed thresholds - no issues", rule.code);
                                },
                                Err(e) => {
                                    pgrx::debug1!("execute_rule; {} failed with error: {}", rule.code, e);
                                    return Err(format!("Failed to execute rule {}: {}", rule.code, e));
                                }
                            }
                        },
                        None => {
                            // Execute as q1-only rule (direct warning)
                            pgrx::debug1!("execute_rule; Executing {} as Q1-only rule", rule.code);
                            match execute_q1_rule_dynamic(&rule.scope, &rule.code, &rule.q1) {
                                Ok(Some(result)) => {
                                    pgrx::debug1!("execute_rule; {} produced result: {} - {}",
                                                rule.code, result.level, result.message);
                                    results.push(result);
                                },
                                Ok(None) => {
                                    pgrx::debug1!("execute_rule; {} found no issues", rule.code);
                                },
                                Err(e) => {
                                    pgrx::debug1!("execute_rule; {} failed with error: {}", rule.code, e);
                                    return Err(format!("Failed to execute rule {}: {}", rule.code, e));
                                }
                            }
                        }
                    }
                } else {
                    pgrx::debug1!("execute_rule; Skipping disabled rule: {}", rule.code);
                }
            }
        },
        Err(e) => {
            pgrx::debug1!("execute_rule; Database error while fetching rules: {}", e);
            return Err(format!("Database error: {e}"));
        }
    }

    pgrx::debug1!("execute_rule; Completed execution of rules, found {} issues", results.len());

    Ok(results)
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
