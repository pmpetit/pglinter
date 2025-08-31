SELECT COUNT(*) as potential_insecure
FROM pg_stat_activity
WHERE state = 'active'
AND application_name != 'psql'
