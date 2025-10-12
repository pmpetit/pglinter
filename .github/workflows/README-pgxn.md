# PGXN Publishing Workflow

This document explains the dedicated PGXN publishing workflow for pglinter.

## Overview

The `pgxn-publish.yml` workflow publishes pglinter releases to the PostgreSQL Extension Network (PGXN) using the official `pgxn/pgxn-tools:latest` Docker container.

## Triggers

### Automatic Publishing
- **On Release**: Automatically triggers when a GitHub release is published
- **Version Detection**: Uses the release tag as the version number

### Manual Publishing
- **Workflow Dispatch**: Can be triggered manually from GitHub Actions
- **Custom Version**: Specify any version to publish
- **Force Option**: Option to force publish even if version exists

## Prerequisites

### Repository Secrets
Configure these secrets in GitHub repository settings:

- **`PGXN_USERNAME`**: Your PGXN account username
- **`PGXN_PASSWORD`**: Your PGXN account password

### Required Files
The workflow validates these files exist:

- **`META.json`**: Extension metadata (automatically updated if version mismatches)
- **`pglinter.control`**: PostgreSQL extension control file
- **`sql/pglinter--VERSION.sql`**: Main extension SQL file
- **`README.md`**: Documentation

## Workflow Features

### 🔍 Smart Validation
- Validates META.json structure and required fields
- Checks for SQL files matching the version
- Auto-updates META.json version if mismatched
- Ensures control file exists

### 📦 Distribution Creation
- Creates clean PGXN-compliant distribution
- Includes documentation, tests, and license files
- Generates proper directory structure
- Creates compressed archive

### 🚀 PGXN Publishing
- Uses official PGXN tools container
- Configures PGXN client credentials
- Uploads distribution to PGXN
- Verifies publication success

### ✅ Quality Assurance
- Tests distribution before upload
- Validates with pgxn-bundle if available
- Provides detailed logging
- Uploads distribution artifact for debugging

## Usage Examples

### Publish Latest Release
```bash
# Create a GitHub release (triggers automatic PGXN publishing)
gh release create v0.0.18 --title "pglinter v0.0.18" --notes "Bug fixes and improvements"
```

### Manual Publishing
1. Go to **Actions** → **Publish to PGXN** in GitHub
2. Click **Run workflow**
3. Enter version number (e.g., `0.0.18`)
4. Choose force publish option if needed
5. Click **Run workflow**

## File Structure

The workflow creates this distribution structure:
```
pglinter-0.0.18/
├── META.json                 # Extension metadata
├── pglinter.control          # Control file
├── README.md                 # Documentation
├── LICENSE                   # License file
├── CHANGELOG.md              # Change log
├── sql/                      # SQL files
│   ├── pglinter--0.0.18.sql
│   └── *.sql
├── docs/                     # Documentation
└── test/                     # Test files (optional)
```

## Troubleshooting

### Common Issues

**Missing Secrets**
```
❌ PGXN credentials not configured
```
→ Configure `PGXN_USERNAME` and `PGXN_PASSWORD` in repository secrets

**Version Mismatch**
```
WARNING: Version mismatch detected
```
→ The workflow automatically fixes this by updating META.json

**Missing SQL File**
```
ERROR: Required SQL file not found: sql/pglinter--VERSION.sql
```
→ Ensure the SQL file exists with the correct version number

**Invalid META.json**
```
ERROR: META.json is not valid JSON
```
→ Validate and fix META.json syntax

### Manual Debugging

If the workflow fails, you can download the distribution artifact to inspect the generated files:

1. Go to the failed workflow run
2. Download the `pgxn-distribution-VERSION` artifact
3. Extract and examine the contents
4. Test locally with PGXN tools

## PGXN Benefits

### For Users
- **Easy Installation**: `pgxn install pglinter`
- **Version Management**: `pgxn upgrade pglinter`
- **Dependency Resolution**: Automatic dependency handling
- **Documentation**: Integrated docs at pgxn.org

### For Developers
- **Automated Publishing**: No manual uploads needed
- **Quality Control**: Built-in validation
- **Version Consistency**: Ensures releases stay in sync
- **Distribution Standards**: PGXN-compliant packaging

## Security Notes

- PGXN credentials are stored as encrypted GitHub secrets
- Credentials are never logged or exposed in workflow output
- Only repository administrators can configure secrets
- Publishing only occurs with valid credentials

## Post-Publication

After successful publication:

1. **Verify**: Check https://pgxn.org/dist/pglinter/
2. **Test**: Try `pgxn install pglinter` on a test system
3. **Document**: Update release notes with PGXN availability
4. **Announce**: Share with the PostgreSQL community

The extension will be available for installation within minutes of successful publication.
