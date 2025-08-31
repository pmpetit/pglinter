SELECT
    current_setting('max_connections')::int as max_connections,
    current_setting('work_mem') as work_mem_setting
