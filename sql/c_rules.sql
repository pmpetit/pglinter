
-- Cluster Rules (C series)
INSERT INTO rules (
    name,
    code,
    warning_level,
    error_level,
    scope,
    description,
    message,
    fixes
) VALUES
(
    'PgHbaEntriesWithMethodTrustShouldNotExists',
    'C001',
    20,
    80,
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust authentication method exceed the warning threshold: {1}.',
    ARRAY['change trust method in pg_hba.conf']
),
(
    'PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists',
    'C002',
    20,
    80,
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust or password authentication method exceed the warning threshold: {1}.',
    ARRAY['change trust or password method in pg_hba.conf']
),

(
    'PasswordEncryptionIsMd5',
    'C003',
    20,
    80,
    'CLUSTER',
    'This configuration is not secure anymore and will prevent an upgrade to Postgres 18. Warning, you will need to reset all passwords after this is changed to scram-sha-256.',
    'Encrypted passwords with MD5.',
    ARRAY['change password_encryption parameter to scram-sha-256 (ALTER SYSTEM SET password_encryption = ''scram-sha-256'' ). Warning, you will need to reset all passwords after this parameter is updated.']
);

-- =============================================================================
-- C002 - Authentication Security (Total)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT count(*) FROM pg_catalog.pg_hba_file_rules
$$
WHERE code = 'C002';

-- =============================================================================
-- C002 - Authentication Security (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT count(*)
FROM pg_catalog.pg_hba_file_rules
WHERE auth_method IN ('trust', 'password')
$$
WHERE code = 'C002';

-- =============================================================================
-- C003 - MD5 encrypted Passwords (Problems)
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT 'password_encryption is ' || setting FROM
pg_catalog.pg_settings
WHERE name='password_encryption' AND setting='md5'
$$
WHERE code = 'C003';
