use pgrx::prelude::*;

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
