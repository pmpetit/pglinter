
use pgrx::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Rule {
    pub id: i32,
    pub name: String,
    pub code: String,
    pub enable: bool,
    pub warning_level: i32,
    pub error_level: i32,
    pub scope: String,
    pub description: String,
    pub message: String,
    pub fixes: Vec<String>,
    pub q1: Option<String>,
    pub q2: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ExportMetadata {
    pub export_timestamp: String,
    pub total_rules: usize,
    pub format_version: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct RulesExport {
    pub metadata: ExportMetadata,
    pub rules: Vec<Rule>,
}

// Rule management functions
pub fn enable_rule(rule_code: &str) -> Result<bool, String> {
    // First check if rule exists and get current status
    let check_query = "
        SELECT code, enable
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<bool, spi::SpiError> = Spi::connect_mut(|client| {
        // Check if rule exists
        let check_result = client.select(check_query, None, &[rule_code.into()])?;
        if check_result.is_empty() {
            return Ok(false); // Rule not found
        }

        // Update the rule
        let enable_query = "
            UPDATE pglinter.rules
            SET enable = true
            WHERE code = $1";

        client.update(enable_query, None, &[rule_code.into()])?;
        Ok(true)
    });

    match result {
        Ok(success) => {
            if success {
                pgrx::notice!("✅ Rule {} has been enabled", rule_code);
                Ok(true)
            } else {
                pgrx::warning!("⚠️  Rule {} not found", rule_code);
                Ok(false)
            }
        }
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn disable_rule(rule_code: &str) -> Result<bool, String> {
    // First check if rule exists and get current status
    let check_query = "
        SELECT code, enable
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<bool, spi::SpiError> = Spi::connect_mut(|client| {
        // Check if rule exists
        let check_result = client.select(check_query, None, &[rule_code.into()])?;
        if check_result.is_empty() {
            return Ok(false); // Rule not found
        }

        // Update the rule
        let disable_query = "
            UPDATE pglinter.rules
            SET enable = false
            WHERE code = $1";

        client.update(disable_query, None, &[rule_code.into()])?;
        Ok(true)
    });

    match result {
        Ok(success) => {
            if success {
                pgrx::notice!("🔴 Rule {} has been disabled", rule_code);
                Ok(true)
            } else {
                pgrx::warning!("⚠️  Rule {} not found", rule_code);
                Ok(false)
            }
        }
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn is_rule_enabled(rule_code: &str) -> Result<bool, String> {
    let check_query = "
        SELECT enable
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<bool, spi::SpiError> = Spi::connect(|client| {
        let mut rows = client.select(check_query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            Ok(row.get::<bool>(1)?.unwrap_or(false))
        } else {
            // Rule not found, assume disabled
            Ok(false)
        }
    });

    match result {
        Ok(enabled) => Ok(enabled),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn list_rules() -> Result<Vec<(String, String, bool)>, String> {
    let list_query = "
        SELECT code, name, enable
        FROM pglinter.rules
        ORDER BY code";

    let result: Result<Vec<(String, String, bool)>, spi::SpiError> = Spi::connect(|client| {
        let mut rules = Vec::new();
        for row in client.select(list_query, None, &[])? {
            let code: String = row.get(1)?.unwrap_or_default();
            let name: String = row.get(2)?.unwrap_or_default();
            let enabled: bool = row.get(3)?.unwrap_or(false);
            rules.push((code, name, enabled));
        }
        Ok(rules)
    });

    match result {
        Ok(rules) => Ok(rules),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn show_rule_status() -> Result<bool, String> {
    match list_rules() {
        Ok(rules) => {
            pgrx::notice!("📋 pglinter Rule Status:");
            pgrx::notice!("{}", "=".repeat(60));
            pgrx::notice!("{:<6} {:<8} {:<40}", "Code", "Status", "Name");
            pgrx::notice!("{}", "-".repeat(60));

            let mut enabled_count = 0;
            let mut disabled_count = 0;

            for (code, name, enabled) in rules {
                let status = if enabled { "✅ ON" } else { "🔴 OFF" };
                if enabled {
                    enabled_count += 1;
                } else {
                    disabled_count += 1;
                }
                pgrx::notice!("{:<6} {:<8} {:<40}", code, status, name);
            }

            pgrx::notice!("{}", "=".repeat(60));
            pgrx::notice!(
                "📊 Summary: {} enabled, {} disabled",
                enabled_count,
                disabled_count
            );
            Ok(true)
        }
        Err(e) => {
            pgrx::warning!("Failed to retrieve rule status: {}", e);
            Ok(false)
        }
    }
}

pub fn explain_rule(rule_code: &str) -> Result<String, String> {
    let explain_query = "
        SELECT code, name, description, scope, message, fixes
        FROM pglinter.rules
        WHERE code = $1";

    type RuleExplainRow = (String, String, String, String, String, Vec<Option<String>>);

    let result: Result<Option<RuleExplainRow>, spi::SpiError> = Spi::connect(|client| {
        let mut rows = client.select(explain_query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            let code: String = row.get(1)?.unwrap_or_default();
            let name: String = row.get(2)?.unwrap_or_default();
            let description: String = row.get(3)?.unwrap_or_default();
            let scope: String = row.get(4)?.unwrap_or_default();
            let message: String = row.get(5)?.unwrap_or_default();
            let fixes: Vec<Option<String>> = row.get(6)?.unwrap_or_default();
            Ok(Some((code, name, description, scope, message, fixes)))
        } else {
            Ok(None)
        }
    });

    match result {
        Ok(Some((code, name, description, scope, message, fixes))) => {
            // Format the fixes section
            let fixes_section = if fixes.is_empty() {
                "No specific fixes available.".to_string()
            } else {
                let mut fix_list = String::new();
                for (i, fix) in fixes.iter().enumerate() {
                    if let Some(fix_text) = fix {
                        fix_list.push_str(&format!("   {}. {}\n", i + 1, fix_text));
                    }
                }
                fix_list.trim_end().to_string()
            };

            let explanation = format!(
                "📖 Rule Explanation for {}\n{}\n\n🎯 Rule Name: {}\n📋 Scope: {}\n\n📝 Description:\n{}\n\n⚠️  Message Template:\n{}\n\n🔧 How to Fix:\n{}\n{}",
                code,
                "=".repeat(60),
                name,
                scope,
                description,
                message,
                fixes_section,
                "=".repeat(60)
            );
            Ok(explanation)
        }
        Ok(None) => Err(format!("Rule '{rule_code}' not found")),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn enable_all_rules() -> Result<usize, String> {
    let enable_all_query = "
        UPDATE pglinter.rules
        SET enable = true
        WHERE enable = false";

    let result: Result<usize, spi::SpiError> = Spi::connect_mut(|client| {
        let table = client.update(enable_all_query, None, &[])?;
        Ok(table.len())
    });

    match result {
        Ok(count) => {
            if count > 0 {
                pgrx::notice!("✅ Enabled {} rule(s)", count);
            } else {
                pgrx::notice!("ℹ️  All rules were already enabled");
            }
            Ok(count)
        }
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn disable_all_rules() -> Result<usize, String> {
    let disable_all_query = "
        UPDATE pglinter.rules
        SET enable = false
        WHERE enable = true";

    let result: Result<usize, spi::SpiError> = Spi::connect_mut(|client| {
        let table = client.update(disable_all_query, None, &[])?;
        Ok(table.len())
    });

    match result {
        Ok(count) => {
            if count > 0 {
                pgrx::notice!("🔴 Disabled {} rule(s)", count);
            } else {
                pgrx::notice!("ℹ️  All rules were already disabled");
            }
            Ok(count)
        }
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn update_rule_levels(
    rule_code: &str,
    warning_level: Option<i32>,
    error_level: Option<i32>,
) -> Result<bool, String> {
    // First check if rule exists
    let check_query = "
        SELECT code, warning_level, error_level
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<bool, spi::SpiError> = Spi::connect_mut(|client| {
        // Check if rule exists and get current values
        let mut rows = client.select(check_query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            let current_warning: i32 = row.get(2)?.unwrap_or(0);
            let current_error: i32 = row.get(3)?.unwrap_or(0);

            // Use provided values or keep current ones
            let new_warning = warning_level.unwrap_or(current_warning);
            let new_error = error_level.unwrap_or(current_error);

            // Update the rule levels
            let update_query = "
                UPDATE pglinter.rules
                SET warning_level = $1, error_level = $2
                WHERE code = $3";

            client.update(
                update_query,
                None,
                &[new_warning.into(), new_error.into(), rule_code.into()],
            )?;

            pgrx::notice!(
                "✅ Updated rule {} levels: warning={}, error={}",
                rule_code,
                new_warning,
                new_error
            );
            Ok(true)
        } else {
            pgrx::warning!("⚠️  Rule {} not found", rule_code);
            Ok(false)
        }
    });

    match result {
        Ok(success) => Ok(success),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

pub fn get_rule_levels(rule_code: &str) -> Result<(i32, i32), String> {
    let query = "
        SELECT warning_level, error_level
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<(i32, i32), spi::SpiError> = Spi::connect(|client| {
        let mut rows = client.select(query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            let warning_level: i32 = row.get(1)?.unwrap_or(0);
            let error_level: i32 = row.get(2)?.unwrap_or(0);
            Ok((warning_level, error_level))
        } else {
            // Return default values if rule not found
            Ok((50, 90))
        }
    });

    match result {
        Ok(levels) => Ok(levels),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

/// Show current rule queries for debugging
pub fn show_rule_queries(rule_code: &str) -> Result<bool, String> {
    let query = "
        SELECT code, name, q1, q2
        FROM pglinter.rules
        WHERE code = $1";

    let result: Result<bool, spi::SpiError> = Spi::connect(|client| {
        let mut rows = client.select(query, None, &[rule_code.into()])?;
        if let Some(row) = rows.next() {
            let code: String = row.get(1)?.unwrap_or_default();
            let name: String = row.get(2)?.unwrap_or_default();
            let q1: Option<String> = row.get(3)?;
            let q2: Option<String> = row.get(4)?;

            pgrx::notice!("🔍 Rule {} Queries ('{}'):", code, name);
            pgrx::notice!("{}", "=".repeat(60));

            match q1 {
                Some(query) => {
                    pgrx::notice!("📊 q1 Query:");
                    pgrx::notice!("{}", query);
                }
                None => pgrx::notice!("📊 q1 Query: <NOT SET>"),
            }

            pgrx::notice!("");

            match q2 {
                Some(query) => {
                    pgrx::notice!("⚠️  q2 Query:");
                    pgrx::notice!("{}", query);
                }
                None => pgrx::notice!("⚠️  q2 Query: <NOT SET>"),
            }

            pgrx::notice!("{}", "=".repeat(60));
            Ok(true)
        } else {
            pgrx::warning!("⚠️  Rule {} not found", rule_code);
            Ok(false)
        }
    });

    match result {
        Ok(success) => Ok(success),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

/// Export all rules to YAML format
pub fn export_rules_to_yaml() -> Result<String, String> {
    let query = "
        SELECT id, name, code, enable, warning_level, error_level,
               scope, description, message, fixes, q1, q2
        FROM pglinter.rules
        ORDER BY code";

    let result: Result<Vec<Rule>, spi::SpiError> = Spi::connect(|client| {
        let rows = client.select(query, None, &[])?;
        let mut rules = Vec::new();

        for row in rows {
            let fixes_array: Vec<Option<String>> = row.get(10)?.unwrap_or_default();
            let fixes: Vec<String> = fixes_array.into_iter().flatten().collect();

            let rule = Rule {
                id: row.get(1)?.unwrap_or(0),
                name: row.get(2)?.unwrap_or_default(),
                code: row.get(3)?.unwrap_or_default(),
                enable: row.get(4)?.unwrap_or(true),
                warning_level: row.get(5)?.unwrap_or(50),
                error_level: row.get(6)?.unwrap_or(90),
                scope: row.get(7)?.unwrap_or_default(),
                description: row.get(8)?.unwrap_or_default(),
                message: row.get(9)?.unwrap_or_default(),
                fixes,
                q1: row.get(11)?,
                q2: row.get(12)?,
            };
            rules.push(rule);
        }

        Ok(rules)
    });

    match result {
        Ok(rules) => {
            let export_data = RulesExport {
                metadata: ExportMetadata {
                    export_timestamp: chrono::Utc::now().to_rfc3339(),
                    total_rules: rules.len(),
                    format_version: "1.0".to_string(),
                },
                rules,
            };

            match serde_yaml::to_string(&export_data) {
                Ok(yaml) => Ok(yaml),
                Err(e) => Err(format!("YAML serialization error: {}", e)),
            }
        }
        Err(e) => Err(format!("Database error: {}", e)),
    }
}

/// Export all rule messages to YAML format
pub fn export_rule_messages_to_yaml() -> Result<String, String> {
    use serde_json::Value;
    use std::collections::BTreeMap;

    let query = "
        SELECT code, rule_msg::TEXT
        FROM pglinter.rule_messages
        ORDER BY code";

    let result: Result<BTreeMap<String, Value>, spi::SpiError> = Spi::connect(|client| {
        let rows = client.select(query, None, &[])?;
        let mut messages = BTreeMap::new();
        for row in rows {
            let code: String = row.get(1)?.unwrap_or_default();
            let rule_msg: Option<String> = row.get(2)?;
            let json_val = match rule_msg {
                Some(s) => serde_json::from_str(&s).unwrap_or(Value::Null),
                None => Value::Null,
            };
            messages.insert(code, json_val);
        }
        Ok(messages)
    });

    match result {
        Ok(messages) => match serde_yaml::to_string(&messages) {
            Ok(yaml) => Ok(yaml),
            Err(e) => Err(format!("YAML serialization error: {}", e)),
        },
        Err(e) => Err(format!("Database error: {}", e)),
    }
}

/// Export rules to YAML file
pub fn export_rules_to_file(file_path: &str) -> Result<String, String> {
    let yaml_content = export_rules_to_yaml()?;

    match std::fs::write(file_path, &yaml_content) {
        Ok(_) => Ok(format!("✅ Rules exported successfully to: {}", file_path)),
        Err(e) => Err(format!("File write error: {}", e)),
    }
}

/// Import rules from YAML format
pub fn import_rules_from_yaml(yaml_content: &str) -> Result<String, String> {
    let import_data: RulesExport = match serde_yaml::from_str(yaml_content) {
        Ok(data) => data,
        Err(e) => return Err(format!("YAML parsing error: {}", e)),
    };

    pgrx::notice!(
        "📥 Importing {} rules from YAML (format v{})",
        import_data.metadata.total_rules,
        import_data.metadata.format_version
    );

    let mut imported_count = 0;
    let mut updated_count = 0;
    let mut errors = Vec::new();

    for rule in import_data.rules {
        let fixes_array: Vec<Option<String>> = rule.fixes.into_iter().map(Some).collect();
        let rule_code_for_error = rule.code.clone();

        let upsert_query = "
            INSERT INTO pglinter.rules (id, name, code, enable, warning_level, error_level,
                                      scope, description, message, fixes, q1, q2)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (id)
            DO UPDATE SET
                name = EXCLUDED.name,
                code = EXCLUDED.code,
                enable = EXCLUDED.enable,
                warning_level = EXCLUDED.warning_level,
                error_level = EXCLUDED.error_level,
                scope = EXCLUDED.scope,
                description = EXCLUDED.description,
                message = EXCLUDED.message,
                fixes = EXCLUDED.fixes,
                q1 = EXCLUDED.q1,
                q2 = EXCLUDED.q2
            RETURNING (xmax = 0) as is_new";

        let result: Result<bool, spi::SpiError> = Spi::connect_mut(|client| {
            let mut rows = client.update(
                upsert_query,
                None,
                &[
                    rule.id.into(),
                    rule.name.into(),
                    rule.code.into(),
                    rule.enable.into(),
                    rule.warning_level.into(),
                    rule.error_level.into(),
                    rule.scope.into(),
                    rule.description.into(),
                    rule.message.into(),
                    fixes_array.into(),
                    rule.q1.into(),
                    rule.q2.into(),
                ],
            )?;

            if let Some(row) = rows.next() {
                let is_new: bool = row.get(1)?.unwrap_or(false);
                Ok(is_new)
            } else {
                Ok(false)
            }
        });

        match result {
            Ok(is_new) => {
                if is_new {
                    imported_count += 1;
                } else {
                    updated_count += 1;
                }
            }
            Err(e) => {
                errors.push(format!("Rule {}: {}", rule_code_for_error, e));
            }
        }
    }

    let mut result_msg = format!(
        "✅ Import completed: {} new rules, {} updated rules",
        imported_count, updated_count
    );

    if !errors.is_empty() {
        result_msg.push_str(&format!("\n⚠️  {} errors encountered:", errors.len()));
        for error in errors.iter().take(5) {
            result_msg.push_str(&format!("\n  - {}", error));
        }
        if errors.len() > 5 {
            result_msg.push_str(&format!("\n  ... and {} more errors", errors.len() - 5));
        }
    }

    Ok(result_msg)
}

/// Import rules from YAML file
pub fn import_rules_from_file(file_path: &str) -> Result<String, String> {
    let yaml_content = match std::fs::read_to_string(file_path) {
        Ok(content) => content,
        Err(e) => return Err(format!("File read error: {}", e)),
    };

    pgrx::notice!("📂 Reading rules from: {}", file_path);
    import_rules_from_yaml(&yaml_content)
}

/// Import rule messages from YAML format and replace all entries in pglinter.rule_messages
pub fn import_rule_messages_from_yaml(yaml_content: &str) -> Result<String, String> {
    use serde_json::Value;
    use std::collections::BTreeMap;

    // Parse YAML into BTreeMap<String, Value>
    let messages: BTreeMap<String, Value> = match serde_yaml::from_str(yaml_content) {
        Ok(data) => data,
        Err(e) => return Err(format!("YAML parsing error: {}", e)),
    };

    let mut errors = Vec::new();
    let mut inserted = 0;

    let result: Result<(), spi::SpiError> = Spi::connect_mut(|client| {
        // Remove all existing entries
        client.update("DELETE FROM pglinter.rule_messages", None, &[])?;

        // Insert each rule message
        for (code, rule_msg) in &messages {
            let insert_query =
                "INSERT INTO pglinter.rule_messages (code, rule_msg) VALUES ($1, $2)";
            let rule_msg_json =
                serde_json::to_string(rule_msg).unwrap_or_else(|_| "null".to_string());
            match client.update(insert_query, None, &[code.into(), rule_msg_json.into()]) {
                Ok(_) => inserted += 1,
                Err(e) => errors.push(format!("{}: {}", code, e)),
            }
        }
        Ok(())
    });

    match result {
        Ok(_) => {
            let mut msg = format!("✅ Imported {} rule messages", inserted);
            if !errors.is_empty() {
                msg.push_str(&format!("\n⚠️  {} errors:", errors.len()));
                for error in errors.iter().take(5) {
                    msg.push_str(&format!("\n  - {}", error));
                }
                if errors.len() > 5 {
                    msg.push_str(&format!("\n  ... and {} more errors", errors.len() - 5));
                }
            }
            Ok(msg)
        }
        Err(e) => Err(format!("Database error: {}", e)),
    }
}
