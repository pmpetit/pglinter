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
                    "Rule '{}' not found in pglinter.rules table",
                    rule_code
                ))
            } else {
                Ok((warning_level, error_level, message))
            }
        }
        Err(e) => Err(format!(
            "Database error while fetching rule '{}': {}",
            rule_code, e
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
        match execute_b001_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B001 failed: {e}")),
        }
    }

    // B002: Redundant indexes
    if is_rule_enabled("B002").unwrap_or(true) {
        match execute_b002_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B002 failed: {e}")),
        }
    }

    // B003: Tables without indexes on foreign keys
    if is_rule_enabled("B003").unwrap_or(true) {
        match execute_b003_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B003 failed: {e}")),
        }
    }

    // B004: Unused indexes
    if is_rule_enabled("B004").unwrap_or(true) {
        match execute_b004_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B004 failed: {e}")),
        }
    }

    // B005: Unsecured public schema
    if is_rule_enabled("B005").unwrap_or(true) {
        match execute_b005_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B005 failed: {e}")),
        }
    }

    // B006: Tables with uppercase names/columns
    if is_rule_enabled("B006").unwrap_or(true) {
        match execute_b006_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("B006 failed: {e}")),
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
        match execute_c002_rule() {
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

    // T002: Tables without any index
    if is_rule_enabled("T002").unwrap_or(true) {
        match execute_t002_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T002 failed: {e}")),
        }
    }

    // T003: Tables with redundant indexes
    if is_rule_enabled("T003").unwrap_or(true) {
        match execute_t003_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T003 failed: {e}")),
        }
    }

    // T004: Tables with foreign keys not indexed
    if is_rule_enabled("T004").unwrap_or(true) {
        match execute_t004_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T004 failed: {e}")),
        }
    }

    // T005: Tables with potential missing indexes (high seq scan)
    if is_rule_enabled("T005").unwrap_or(true) {
        match execute_t005_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T005 failed: {e}")),
        }
    }

    // T006: Tables with foreign keys outside schema
    if is_rule_enabled("T006").unwrap_or(true) {
        match execute_t006_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T006 failed: {e}")),
        }
    }

    // T007: Tables with unused indexes
    if is_rule_enabled("T007").unwrap_or(true) {
        match execute_t007_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T007 failed: {e}")),
        }
    }

    // T008: Tables with foreign key type mismatch
    if is_rule_enabled("T008").unwrap_or(true) {
        match execute_t008_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T008 failed: {e}")),
        }
    }

    // T009: Tables with no roles granted
    if is_rule_enabled("T009").unwrap_or(true) {
        match execute_t009_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T009 failed: {e}")),
        }
    }

    // T010: Tables using reserved keywords
    if is_rule_enabled("T010").unwrap_or(true) {
        match execute_t010_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T010 failed: {e}")),
        }
    }

    // T011: Tables with uppercase names/columns
    if is_rule_enabled("T011").unwrap_or(true) {
        match execute_t011_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T011 failed: {e}")),
        }
    }

    // T012: Tables with sensitive columns (requires anon extension)
    if is_rule_enabled("T012").unwrap_or(true) {
        match execute_t012_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {}
            Err(e) => return Err(format!("T012 failed: {e}")),
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

// Individual rule implementations
fn execute_b001_rule() -> Result<Option<RuleResult>, String> {
    let warning_threshold = 10i64; // 10%

    let total_tables_query = "
        SELECT count(*)
        FROM pg_catalog.pg_tables pt
        WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')";

    let tables_with_pk_query = "
        SELECT count(distinct(pg_class.relname))
        FROM pg_index, pg_class, pg_attribute, pg_namespace
        WHERE indrelid = pg_class.oid AND
        nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema') AND
        pg_class.relnamespace = pg_namespace.oid AND
        pg_attribute.attrelid = pg_class.oid AND
        pg_attribute.attnum = any(pg_index.indkey)
        AND indisprimary";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let total_tables: i64 = client
            .select(total_tables_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        let tables_with_pk: i64 = client
            .select(tables_with_pk_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        let tables_without_pk = total_tables - tables_with_pk;

        if total_tables > 0 {
            let percentage = (tables_without_pk * 100) / total_tables;

            if percentage > warning_threshold {
                return Ok(Some(RuleResult {
                    ruleid: "B001".to_string(),
                    level: "warning".to_string(),
                    message: format!(
                        "{tables_without_pk} tables without primary key exceed the warning threshold: {warning_threshold}%"
                    ),
                    count: Some(tables_without_pk),
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

fn execute_b002_rule() -> Result<Option<RuleResult>, String> {
    let _warning_threshold = 5i64; // 5% - will be used for threshold checking later

    // Simplified redundant index check
    let redundant_check_query = "
        SELECT COUNT(*) as potential_redundant
        FROM pg_index i1, pg_index i2
        WHERE i1.indrelid = i2.indrelid
        AND i1.indexrelid != i2.indexrelid
        AND i1.indkey = i2.indkey";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let redundant_count: i64 = client
            .select(redundant_check_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if redundant_count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "B002".to_string(),
                level: "warning".to_string(),
                message: format!("Found {redundant_count} potentially redundant indexes"),
                count: Some(redundant_count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_b003_rule() -> Result<Option<RuleResult>, String> {
    // B003: Tables without indexes on foreign keys
    let fk_without_index_query = "
        SELECT COUNT(*) as tables_without_fk_index
        FROM (
            SELECT DISTINCT
                ccu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
            AND NOT EXISTS (
                SELECT 1 FROM pg_indexes pi
                WHERE pi.schemaname = tc.table_schema
                AND pi.tablename = tc.table_name
            )
        ) fk_tables";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let count: i64 = client
            .select(fk_without_index_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "B003".to_string(),
                level: "warning".to_string(),
                message: format!("Found {count} foreign key columns without indexes"),
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

fn execute_b004_rule() -> Result<Option<RuleResult>, String> {
    // B004: Unused indexes (simplified check using pg_stat_user_indexes)
    let unused_indexes_query = "
        SELECT COUNT(*) as unused_indexes
        FROM pg_stat_user_indexes
        WHERE idx_scan = 0
        AND schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let count: i64 = client
            .select(unused_indexes_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "B004".to_string(),
                level: "warning".to_string(),
                message: format!("Found {count} potentially unused indexes"),
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

fn execute_b005_rule() -> Result<Option<RuleResult>, String> {
    // B005: Unsecured public schema
    let public_schema_check_query = "
        SELECT has_schema_privilege('public', 'public', 'CREATE') as public_create";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let has_public_create: bool = client
            .select(public_schema_check_query, None, &[])?
            .first()
            .get::<bool>(1)?
            .unwrap_or(false);

        if has_public_create {
            return Ok(Some(RuleResult {
                ruleid: "B005".to_string(),
                level: "error".to_string(),
                message: "Public schema allows CREATE privilege for all users - security risk"
                    .to_string(),
                count: Some(1),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_b006_rule() -> Result<Option<RuleResult>, String> {
    // B006: Tables with uppercase names/columns
    let uppercase_check_query = "
        SELECT COUNT(*) as uppercase_objects
        FROM (
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
            AND table_name != lower(table_name)
            UNION
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
            AND column_name != lower(column_name)
        ) uppercase_objects";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let count: i64 = client
            .select(uppercase_check_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "B006".to_string(),
                level: "warning".to_string(),
                message: format!("Found {count} database objects with uppercase letters"),
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

fn execute_c001_rule() -> Result<Option<RuleResult>, String> {
    let memory_check_query = "
        SELECT
            current_setting('max_connections')::int as max_connections,
            current_setting('work_mem') as work_mem_setting
    ";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        for row in client.select(memory_check_query, None, &[])? {
            let max_connections: i32 = row.get(1)?.unwrap_or(100);
            let _work_mem_str: String = row.get(2)?.unwrap_or("4MB".to_string());

            // Simple check: if max_connections > 1000, flag as potential issue
            if max_connections > 1000 {
                return Ok(Some(RuleResult {
                    ruleid: "C001".to_string(),
                    level: "warning".to_string(),
                    message: format!("High max_connections setting: {max_connections}"),
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

fn execute_c002_rule() -> Result<Option<RuleResult>, String> {
    // C002: Insecure pg_hba.conf entries (simplified check)
    // Note: This is a simplified version as we can't directly read pg_hba.conf from SQL
    let auth_check_query = "
        SELECT COUNT(*) as potential_insecure
        FROM pg_stat_activity
        WHERE state = 'active'
        AND application_name != 'psql'";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let _count: i64 = client
            .select(auth_check_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        // For now, just return a warning about checking pg_hba.conf manually
        Ok(Some(RuleResult {
            ruleid: "C002".to_string(),
            level: "info".to_string(),
            message: "Please manually check pg_hba.conf for insecure trust/password methods"
                .to_string(),
            count: Some(1),
        }))
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t001_rule() -> Result<Option<RuleResult>, String> {
    let tables_without_pk_query = "
        SELECT COUNT(*)
        FROM pg_tables pt
        WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND NOT EXISTS (
            SELECT 1
            FROM pg_constraint pc
            WHERE pc.conrelid = (pt.schemaname||'.'||pt.tablename)::regclass
            AND pc.contype = 'p'
        )";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let count: i64 = client
            .select(tables_without_pk_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T001".to_string(),
                level: "warning".to_string(),
                message: format!("Found {count} tables without primary key"),
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
    // T002: Tables without any index
    let tables_without_index_query = "
        SELECT t.schemaname::text, t.tablename::text
        FROM pg_tables t
        WHERE t.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND NOT EXISTS (
            SELECT 1
            FROM pg_indexes i
            WHERE i.schemaname = t.schemaname
            AND i.tablename = t.tablename
        )";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut tables = Vec::new();

        for row in client.select(tables_without_index_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            tables.push(format!("{schema}.{table}"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T002".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} tables without any index: {}",
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

fn execute_t003_rule() -> Result<Option<RuleResult>, String> {
    // T003: Tables with redundant indexes
    let redundant_indexes_query = "
        SELECT t.schemaname::text, t.tablename::text,
            array_agg(t.indexname) as redundant_indexes
        FROM (
            SELECT DISTINCT i1.schemaname, i1.tablename, i1.indexname
            FROM pg_indexes i1
            JOIN pg_indexes i2 ON i1.schemaname = i2.schemaname
                AND i1.tablename = i2.tablename
                AND i1.indexname != i2.indexname
            WHERE i1.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
            AND EXISTS (
                SELECT 1 FROM pg_index idx1, pg_index idx2, pg_class c1, pg_class c2
                WHERE c1.relname = i1.indexname AND c2.relname = i2.indexname
                AND idx1.indexrelid = c1.oid AND idx2.indexrelid = c2.oid
                AND idx1.indrelid = idx2.indrelid
                AND idx1.indkey = idx2.indkey
            )
        ) t
        GROUP BY t.schemaname, t.tablename";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut details = Vec::new();

        for row in client.select(redundant_indexes_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let indexes: String = row.get(3)?.unwrap_or_default();
            details.push(format!("{schema}.{table} (indexes: {indexes})"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T003".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} tables with redundant indexes: {}",
                    count,
                    details.join(", ")
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
    // T004: Tables with foreign keys not indexed
    let fk_not_indexed_query = "
        SELECT DISTINCT tc.table_schema::text, tc.table_name::text, tc.constraint_name::text
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND NOT EXISTS (
            SELECT 1 FROM pg_indexes pi
            WHERE pi.schemaname = tc.table_schema
            AND pi.tablename = tc.table_name
            AND pi.indexdef LIKE '%' || kcu.column_name || '%'
        )";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut tables = Vec::new();

        for row in client.select(fk_not_indexed_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let constraint: String = row.get(3)?.unwrap_or_default();
            tables.push(format!("{schema}.{table} (FK: {constraint})"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T004".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {} foreign keys without indexes: {}",
                    count,
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

fn execute_t005_rule() -> Result<Option<RuleResult>, String> {
    // T005: Tables with potential missing indexes (high sequential scan usage)

    // Get thresholds from rules table
    let (warning_threshold, error_threshold, _rule_message) = match get_rule_config("T005") {
        Ok(config) => config,
        Err(e) => {
            return Err(format!("Failed to get T005 configuration: {e}"));
        }
    };

    let high_seq_scan_query = "
        SELECT
            schemaname::text,
            relname::text, seq_scan, seq_tup_read,
            CASE
                WHEN (seq_tup_read + idx_tup_fetch) > 0 THEN
                    ROUND((seq_tup_read::numeric / (seq_tup_read + idx_tup_fetch)::numeric) * 100,0)::float8
                ELSE 0.0::float8
            END as seq_scan_percentage
        FROM pg_stat_user_tables
        WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
        AND (CASE
                WHEN (seq_tup_read + idx_tup_fetch) > 0 THEN
                    (seq_tup_read::numeric / (seq_tup_read + idx_tup_fetch)::numeric) * 100
                ELSE 0
            END) > $1";
    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut tables = Vec::new();

        // First check with warning threshold
        for row in client.select(high_seq_scan_query, None, &[warning_threshold.into()])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let seq_percentage: f64 = row.get(5)?.unwrap_or(0.0);
            tables.push(format!(
                "{schema}.{table} (seq scan %: {:.1})",
                seq_percentage
            ));
            count += 1;
        }

        if count > 0 {
            // Determine level based on thresholds
            let mut error_count = 0i64;
            let mut error_tables = Vec::new();

            // Check if any tables exceed error threshold
            for row in client.select(high_seq_scan_query, None, &[error_threshold.into()])? {
                let schema: String = row.get(1)?.unwrap_or_default();
                let table: String = row.get(2)?.unwrap_or_default();
                let seq_percentage: f64 = row.get(5)?.unwrap_or(0.0);
                error_tables.push(format!(
                    "{schema}.{table} (seq scan %: {:.1})",
                    seq_percentage
                ));
                error_count += 1;
            }

            let (level, message) = if error_count > 0 {
                (
                    "error",
                    format!(
                        "Found {} tables with seq scan percentage > {}%: {}",
                        error_count,
                        error_threshold,
                        error_tables.join(", ")
                    ),
                )
            } else {
                (
                    "warning",
                    format!(
                        "Found {} tables with seq scan percentage > {}%: {}",
                        count,
                        warning_threshold,
                        tables.join(", ")
                    ),
                )
            };

            return Ok(Some(RuleResult {
                ruleid: "T005".to_string(),
                level: level.to_string(),
                message,
                count: Some(if error_count > 0 { error_count } else { count }),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}")),
    }
}

fn execute_t006_rule() -> Result<Option<RuleResult>, String> {
    // T006: Tables with foreign keys referencing other schemas
    let fk_outside_schema_query = "
        SELECT tc.table_schema::text, tc.table_name::text, tc.constraint_name::text,
            ccu.table_schema::text as referenced_schema
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu
            ON tc.constraint_name = ccu.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema != ccu.table_schema
        AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut violations = Vec::new();

        for row in client.select(fk_outside_schema_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let constraint: String = row.get(3)?.unwrap_or_default();
            let ref_schema: String = row.get(4)?.unwrap_or_default();
            violations.push(format!(
                "{schema}.{table} -> {ref_schema} (FK: {constraint})"
            ));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T006".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} foreign keys referencing other schemas: {}",
                    violations.join(", ")
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

fn execute_t007_rule() -> Result<Option<RuleResult>, String> {
    // T007: Tables with unused indexes
    let size_threshold_mb = 1i64; // 1MB minimum size to consider
    let size_threshold_bytes = size_threshold_mb * 1024 * 1024;

    let unused_indexes_query = "
        SELECT pi.schemaname::text, pi.tablename::text, pi.indexname::text,
            pg_relation_size(indexrelid) as index_size
        FROM pg_stat_user_indexes psi
        JOIN pg_indexes pi ON psi.indexrelname = pi.indexname
            AND psi.schemaname = pi.schemaname
        WHERE psi.idx_scan = 0
        AND pi.indexdef !~* 'unique'
        AND pi.schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND pg_relation_size(indexrelid) > $1";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut unused_indexes = Vec::new();

        for row in client.select(unused_indexes_query, None, &[size_threshold_bytes.into()])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let index: String = row.get(3)?.unwrap_or_default();
            let size: i64 = row.get(4)?.unwrap_or(0);
            let size_mb = size / 1024 / 1024;
            unused_indexes.push(format!("{schema}.{table}.{index} ({size_mb}MB)"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T007".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} unused indexes larger than {size_threshold_mb}MB: {}",
                    unused_indexes.join(", ")
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
    // T008: Tables with foreign key type mismatches
    let fk_type_mismatch_query = "
        SELECT
            tc.table_schema::text, tc.table_name::text, tc.constraint_name::text,
            kcu.column_name::text, col1.data_type::text as fk_type,
            ccu.table_name::text as ref_table, ccu.column_name::text as ref_column,
            col2.data_type::text as ref_type
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage ccu
            ON tc.constraint_name = ccu.constraint_name
        JOIN information_schema.columns col1
            ON kcu.table_schema = col1.table_schema
            AND kcu.table_name = col1.table_name
            AND kcu.column_name = col1.column_name
        JOIN information_schema.columns col2
            ON ccu.table_schema = col2.table_schema
            AND ccu.table_name = col2.table_name
            AND ccu.column_name = col2.column_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND col1.data_type != col2.data_type";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut mismatches = Vec::new();

        for row in client.select(fk_type_mismatch_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let constraint: String = row.get(3)?.unwrap_or_default();
            let column: String = row.get(4)?.unwrap_or_default();
            let fk_type: String = row.get(5)?.unwrap_or_default();
            let ref_table: String = row.get(6)?.unwrap_or_default();
            let ref_column: String = row.get(7)?.unwrap_or_default();
            let ref_type: String = row.get(8)?.unwrap_or_default();

            mismatches.push(format!("{schema}.{table}.{column} ({fk_type}) -> {ref_table}.{ref_column} ({ref_type}) [FK: {constraint}]"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T008".to_string(),
                level: "error".to_string(),
                message: format!(
                    "Found {count} foreign key type mismatches: {}",
                    mismatches.join(", ")
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

fn execute_t009_rule() -> Result<Option<RuleResult>, String> {
    // T009: Tables with no roles granted (only for non-public schemas)
    let tables_without_roles_query = "
        SELECT t.table_schema::text, t.table_name::text
        FROM information_schema.tables t
        WHERE t.table_schema NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
        AND NOT EXISTS (
            SELECT 1
            FROM information_schema.role_table_grants rtg
            JOIN pg_roles pr ON pr.rolname = rtg.grantee
            WHERE rtg.table_schema = t.table_schema
            AND rtg.table_name = t.table_name
            AND pr.rolcanlogin = false
        )";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut tables = Vec::new();

        for row in client.select(tables_without_roles_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            tables.push(format!("{schema}.{table}"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T009".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} tables without role grants: {}",
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

fn execute_t010_rule() -> Result<Option<RuleResult>, String> {
    // T010: Tables using reserved keywords
    let reserved_keywords = vec![
        "ALL",
        "ANALYSE",
        "ANALYZE",
        "AND",
        "ANY",
        "ARRAY",
        "AS",
        "ASC",
        "ASYMMETRIC",
        "AUTHORIZATION",
        "BINARY",
        "BOTH",
        "CASE",
        "CAST",
        "CHECK",
        "COLLATE",
        "COLLATION",
        "COLUMN",
        "CONCURRENTLY",
        "CONSTRAINT",
        "CREATE",
        "CROSS",
        "CURRENT_CATALOG",
        "CURRENT_DATE",
        "CURRENT_ROLE",
        "CURRENT_SCHEMA",
        "CURRENT_TIME",
        "CURRENT_TIMESTAMP",
        "CURRENT_USER",
        "DEFAULT",
        "DEFERRABLE",
        "DESC",
        "DISTINCT",
        "DO",
        "ELSE",
        "END",
        "EXCEPT",
        "FALSE",
        "FETCH",
        "FOR",
        "FOREIGN",
        "FREEZE",
        "FROM",
        "FULL",
        "GRANT",
        "GROUP",
        "HAVING",
        "ILIKE",
        "IN",
        "INITIALLY",
        "INNER",
        "INTERSECT",
        "INTO",
        "IS",
        "ISNULL",
        "JOIN",
        "LATERAL",
        "LEADING",
        "LEFT",
        "LIKE",
        "LIMIT",
        "LOCALTIME",
        "LOCALTIMESTAMP",
        "NATURAL",
        "NOT",
        "NOTNULL",
        "NULL",
        "OFFSET",
        "ON",
        "ONLY",
        "OR",
        "ORDER",
        "OUTER",
        "OVERLAPS",
        "PLACING",
        "PRIMARY",
        "REFERENCES",
        "RETURNING",
        "RIGHT",
        "SELECT",
        "SESSION_USER",
        "SIMILAR",
        "SOME",
        "SYMMETRIC",
        "TABLE",
        "TABLESAMPLE",
        "THEN",
        "TO",
        "TRAILING",
        "TRUE",
        "UNION",
        "UNIQUE",
        "USER",
        "USING",
        "VARIADIC",
        "VERBOSE",
        "WHEN",
        "WHERE",
        "WINDOW",
        "WITH",
    ];

    // Create keyword check conditions
    let keyword_conditions: Vec<String> = reserved_keywords
        .iter()
        .map(|kw| format!("UPPER(table_name) = '{kw}'"))
        .collect();
    let keyword_clause = keyword_conditions.join(" OR ");

    let reserved_keyword_query = format!(
        "
        SELECT table_schema::text, table_name::text, 'table' as object_type
        FROM information_schema.tables
        WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND ({})
        UNION
        SELECT table_schema, table_name, 'column:' || column_name as object_type
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND ({})",
        keyword_clause,
        reserved_keywords
            .iter()
            .map(|kw| format!("UPPER(column_name) = '{kw}'"))
            .collect::<Vec<_>>()
            .join(" OR ")
    );

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut violations = Vec::new();

        for row in client.select(&reserved_keyword_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let object_type: String = row.get(3)?.unwrap_or_default();
            violations.push(format!("{schema}.{table} ({object_type})"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T010".to_string(),
                level: "error".to_string(),
                message: format!(
                    "Found {count} database objects using reserved keywords: {}",
                    violations.join(", ")
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

fn execute_t011_rule() -> Result<Option<RuleResult>, String> {
    // T011: Tables with uppercase names/columns (similar to B006 but table-specific)
    let uppercase_objects_query = "
        SELECT table_schema::text, table_name::text, 'table'::text as object_type
        FROM information_schema.tables
        WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND table_name != lower(table_name)
        UNION
        SELECT table_schema::text, table_name::text, 'column:' || column_name::text as object_type
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
        AND column_name != lower(column_name)";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut objects = Vec::new();

        for row in client.select(uppercase_objects_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let object_type: String = row.get(3)?.unwrap_or_default();
            objects.push(format!("{schema}.{table} ({object_type})"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T011".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} database objects with uppercase letters: {}",
                    objects.join(", ")
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

fn execute_t012_rule() -> Result<Option<RuleResult>, String> {
    // T012: Tables with sensitive columns (requires anon extension)

    // First check if anon extension is available
    let check_anon_query = "
        SELECT count(*) as ext_count
        FROM pg_extension
        WHERE extname = 'anon'";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let anon_count: i64 = client
            .select(check_anon_query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if anon_count == 0 {
            return Ok(Some(RuleResult {
                ruleid: "T012".to_string(),
                level: "info".to_string(),
                message: "Anon extension not found. Install postgresql-anonymizer to detect sensitive columns".to_string(),
                count: Some(0),
            }));
        }

        // If anon extension is available, try to detect sensitive columns
        let sensitive_columns_query = "
            SELECT table_schema::text, table_name::text, column_name::text, identifiers_category::text
            FROM (
                SELECT table_schema, table_name, column_name, identifiers_category
                FROM anon.detect('en_US')
                WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
                UNION
                SELECT table_schema, table_name, column_name, identifiers_category
                FROM anon.detect('fr_FR')
                WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
            ) detected
            GROUP BY table_schema, table_name, column_name, identifiers_category";

        let mut count = 0i64;
        let mut sensitive_data = Vec::new();

        for row in client.select(sensitive_columns_query, None, &[])? {
            let schema: String = row.get(1)?.unwrap_or_default();
            let table: String = row.get(2)?.unwrap_or_default();
            let column: String = row.get(3)?.unwrap_or_default();
            let category: String = row.get(4)?.unwrap_or_default();
            sensitive_data.push(format!("{schema}.{table}.{column} ({category})"));
            count += 1;
        }

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "T012".to_string(),
                level: "warning".to_string(),
                message: format!(
                    "Found {count} potentially sensitive columns: {}",
                    sensitive_data.join(", ")
                ),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(_e) => {
            // If there's an error, it might be because anon functions don't exist
            // Return an info message instead of failing
            Ok(Some(RuleResult {
                ruleid: "T012".to_string(),
                level: "info".to_string(),
                message: "Could not check for sensitive columns. Ensure anon extension is properly configured".to_string(),
                count: Some(0),
            }))
        }
    }
}

fn execute_s001_rule() -> Result<Option<RuleResult>, String> {
    // S001: Schemas without default role grants
    let schemas_without_default_privileges_query = "
        SELECT DISTINCT n.nspname::text as schema_name
        FROM pg_namespace n
        WHERE n.nspname NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
        AND n.nspname NOT LIKE 'pg_%'
        AND NOT EXISTS (
            SELECT 1
            FROM pg_default_acl da
            WHERE da.defaclnamespace = n.oid
            AND da.defaclrole != n.nspowner
        )";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let mut count = 0i64;
        let mut schemas = Vec::new();

        for row in client.select(schemas_without_default_privileges_query, None, &[])? {
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

    let environment_schema_query = format!(
        "
        SELECT nspname::text as schema_name
        FROM pg_namespace
        WHERE nspname NOT IN ('public', 'pg_toast', 'pg_catalog', 'information_schema')
        AND nspname NOT LIKE 'pg_%'
        AND ({condition_clause})"
    );

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
