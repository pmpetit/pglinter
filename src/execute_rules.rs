use pgrx::prelude::*;

use crate::rule_queries::get_rule_queries;

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
pub fn get_violations_for_rule(rule_id: &str) -> Result<Vec<(i32, i32, i32)>, String> {
    pgrx::debug1!("get_violations_for_rule; Starting for rule_id: {}", rule_id);

    let q4_sql = match get_rule_queries(rule_id).q4 {
        Some(q) => q,
        None => {
            pgrx::debug1!(
                "get_violations_for_rule; No q4 query for rule_id '{}', returning empty",
                rule_id
            );
            return Ok(vec![]);
        }
    };

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
                pgrx::debug1!(
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
