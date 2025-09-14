e-- Installation functions for non-superuser pglinter usage
-- This file should be run by a superuser to set up pglinter for regular users

-- Function to install pglinter extension for regular users
CREATE OR REPLACE FUNCTION pglinter_install_for_user(target_user text DEFAULT current_user)
RETURNS text AS $$
DECLARE
    result_msg text;
BEGIN
    -- Check if extension already exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pglinter') THEN
        result_msg := 'pglinter extension already installed';
    ELSE
        -- Install the extension
        CREATE EXTENSION pglinter;
        result_msg := 'pglinter extension installed successfully';
    END IF;

    -- Grant schema usage
    EXECUTE format('GRANT USAGE ON SCHEMA pglinter TO %I', target_user);

    -- Grant table permissions
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA pglinter TO %I', target_user);

    -- Grant function execution permissions
    EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pglinter TO %I', target_user);

    -- Grant permissions for future objects
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA pglinter GRANT SELECT ON TABLES TO %I', target_user);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA pglinter GRANT EXECUTE ON FUNCTIONS TO %I', target_user);

    RETURN result_msg || format(' and permissions granted to user %s', target_user);
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to uninstall pglinter
CREATE OR REPLACE FUNCTION pglinter_uninstall()
RETURNS text AS $$
BEGIN
    DROP EXTENSION IF EXISTS pglinter CASCADE;
    RETURN 'pglinter extension uninstalled successfully';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error uninstalling pglinter: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check pglinter status
CREATE OR REPLACE FUNCTION pglinter_status()
RETURNS TABLE(
    extension_installed boolean,
    extension_version text,
    schema_accessible boolean,
    functions_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pglinter') as extension_installed,
        COALESCE(
            (SELECT extversion FROM pg_extension WHERE extname = 'pglinter'),
            'not installed'
        ) as extension_version,
        has_schema_privilege('pglinter', 'USAGE') as schema_accessible,
        COALESCE(
            (SELECT count(*) FROM information_schema.routines
             WHERE routine_schema = 'pglinter'),
            0
        ) as functions_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to grant pglinter permissions to a user
CREATE OR REPLACE FUNCTION pglinter_grant_to_user(target_user text)
RETURNS text AS $$
BEGIN
    -- Validate user exists
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = target_user) THEN
        RETURN format('Error: User %s does not exist', target_user);
    END IF;

    -- Grant permissions
    EXECUTE format('GRANT USAGE ON SCHEMA pglinter TO %I', target_user);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA pglinter TO %I', target_user);
    EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pglinter TO %I', target_user);

    RETURN format('pglinter permissions granted to user %s', target_user);
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error granting permissions: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to public (or specific roles)
GRANT EXECUTE ON FUNCTION pglinter_install_for_user(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pglinter_uninstall() TO PUBLIC;
GRANT EXECUTE ON FUNCTION pglinter_status() TO PUBLIC;
GRANT EXECUTE ON FUNCTION pglinter_grant_to_user(text) TO PUBLIC;

-- Usage instructions
DO $$
BEGIN
    RAISE NOTICE 'pglinter installation functions created successfully!';
    RAISE NOTICE 'Usage for regular users:';
    RAISE NOTICE '  SELECT pglinter_install_for_user();  -- Install for current user';
    RAISE NOTICE '  SELECT pglinter_install_for_user(''username'');  -- Install for specific user';
    RAISE NOTICE '  SELECT pglinter_status();  -- Check installation status';
    RAISE NOTICE '  SELECT pglinter_grant_to_user(''username'');  -- Grant permissions to user';
    RAISE NOTICE '  SELECT pglinter_uninstall();  -- Uninstall extension';
END;
$$;
