# Rule Level Management Examples

This document provides practical examples of using PG Linter's rule level management functions.

## Overview

PG Linter now supports configurable warning and error thresholds for certain rules, allowing you to customize analysis sensitivity based on your environment's requirements.

## Basic Rule Level Management

### Viewing Current Configuration

```sql
-- Check current thresholds for T005
SELECT pglinter.get_rule_levels('T005');
-- Output: "Rule T005: warning_level=50, error_level=90"

-- Check if other rules support configuration
SELECT pglinter.get_rule_levels('B001');
-- Output: "Rule B001: warning_level=50, error_level=90" (defaults)
```

### Updating Rule Thresholds

```sql
-- Make T005 more sensitive (lower thresholds)
SELECT pglinter.update_rule_levels('T005', 30.0, 70.0);
-- Output: "Updated rule T005: warning_level=30, error_level=70"

-- Make T005 less sensitive (higher thresholds)
SELECT pglinter.update_rule_levels('T005', 70.0, 95.0);
-- Output: "Updated rule T005: warning_level=70, error_level=95"

-- Update only warning level
SELECT pglinter.update_rule_levels('T005', 40.0, NULL);
-- Output: "Updated rule T005: warning_level=40"

-- Update only error level
SELECT pglinter.update_rule_levels('T005', NULL, 85.0);
-- Output: "Updated rule T005: error_level=85"
```

## Bulk Rule Management

### Enable/Disable All Rules

```sql
-- Check current rule status
SELECT enabled, count(*) as rule_count
FROM pglinter.show_rules()
GROUP BY enabled;

-- Disable all rules
SELECT pglinter.disable_all_rules();
-- Output: "Disabled 15 rules"

-- Enable only critical rules
SELECT pglinter.enable_rule('B001'),  -- Tables without primary keys
       pglinter.enable_rule('T001'),  -- Individual table primary keys
       pglinter.enable_rule('T005');  -- Missing indexes

-- Re-enable all rules
SELECT pglinter.enable_all_rules();
-- Output: "Enabled 12 rules"
```

## Advanced Workflows

### Performance Tuning Workflow

```sql
-- 1. Set sensitive thresholds
SELECT pglinter.update_rule_levels('T005', 20.0, 50.0);

-- 2. Run analysis to identify high sequential scan tables
SELECT * FROM pglinter.perform_table_check()
WHERE ruleid = 'T005';

-- 3. After adding indexes, set moderate thresholds for monitoring
SELECT pglinter.update_rule_levels('T005', 40.0, 70.0);

-- 4. Schedule regular monitoring
SELECT * FROM pglinter.perform_table_check()
WHERE ruleid = 'T005';
```

## Best Practices

1. **Start Conservative**: Begin with default thresholds and adjust based on your environment
2. **Environment Consistency**: Document threshold configurations for each environment
3. **Gradual Changes**: Make incremental threshold adjustments rather than dramatic changes
4. **Monitor Impact**: Track rule effectiveness after threshold changes
5. **Version Control**: Store threshold configurations in your database migration scripts

## Troubleshooting

### Common Issues

```sql
-- Issue: Rule doesn't support custom thresholds
SELECT pglinter.update_rule_levels('B001', 40.0, 80.0);
-- Solution: Check which rules support configuration
SELECT pglinter.get_rule_levels('B001');  -- Returns defaults if not configurable

-- Issue: Thresholds seem ineffective
SELECT pglinter.get_rule_levels('T005');  -- Verify current settings
SELECT * FROM pglinter.perform_table_check() WHERE ruleid = 'T005';  -- Check results

-- Issue: Reset to defaults
SELECT pglinter.update_rule_levels('T005', 50.0, 90.0);  -- Reset T005 to defaults
```
