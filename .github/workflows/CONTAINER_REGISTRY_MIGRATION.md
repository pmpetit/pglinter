# Container Registry Migration Summary

## Overview
Successfully migrated from GitLab Container Registry to GitHub Container Registry (GHCR) and updated all references to use the correct project name.

## Changes Made

### 1. Container Registry Migration
- **From**: `registry.gitlab.com/dalibo/postgresql_anonymizer:pgrx`
- **To**: `ghcr.io/pmpetit/postgresql_pglinter:pgrx`

### 2. Updated Files

#### `.github/workflows/build_and_test_pgver.yml`
- ✅ Updated container image in `build` job
- ✅ Updated container image in `installcheck` job
- ✅ Updated artifact names from `anon-*` to `pglinter-*`
- ✅ Updated release package names to use `pglinter_*` instead of `postgresql_anonymizer_*`

#### `build_and_push_to_ghcr.sh`
- ✅ Updated image name from `postgresql_anonymizer` to `postgresql_pglinter`
- ✅ Updated script description and echo messages
- ✅ Made script executable

#### `.github/workflows/GITLAB_TO_GITHUB_MIGRATION.md`
- ✅ Updated all container registry references from GCR to GHCR
- ✅ Updated image names throughout documentation
- ✅ Removed GCR-specific instructions

### 3. Removed Files
- ❌ `build_and_push_to_gcr.sh` (GCR script removed as requested)

## Current Container Configuration

### GitHub Actions Workflows
```yaml
container: ghcr.io/pmpetit/postgresql_pglinter:pgrx
```

### Build Script
```bash
IMAGE_NAME="postgresql_pglinter"
FULL_IMAGE_NAME="ghcr.io/pmpetit/postgresql_pglinter:pgrx"
```

## Next Steps

### 1. Build and Push Container to GHCR
```bash
# Login to GitHub Container Registry
echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u pmpetit --password-stdin

# Build and push using the script
./build_and_push_to_ghcr.sh
```

### 2. GitHub Token Requirements
Your GitHub token needs the following scopes:
- `write:packages` - To push containers to GHCR
- `read:packages` - To pull containers from GHCR

### 3. Container Visibility
The container will be:
- 🔒 **Private** by default (only accessible to your account)
- 🌐 **Can be made public** in GitHub Package settings if needed

### 4. Workflow Testing
After pushing the container:
1. Push changes to your repository
2. Trigger workflows manually or via PR
3. Monitor workflow runs in GitHub Actions tab

## Container Registry Comparison

| Feature | GitLab CI (Old) | GitHub Container Registry (New) |
|---------|----------------|----------------------------------|
| **Registry** | `registry.gitlab.com` | `ghcr.io` |
| **Authentication** | GitLab CI tokens | GitHub tokens |
| **Visibility** | Project-based | Package-based |
| **Integration** | GitLab-specific | GitHub ecosystem |
| **Cost** | Free on GitLab.com | Free for public repos |

## Benefits of GHCR Migration

1. **Better GitHub Integration**: Native integration with GitHub Actions
2. **Unified Ecosystem**: All code and containers in one place
3. **Consistent Authentication**: Uses same GitHub tokens
4. **Package Management**: Integrated with GitHub Packages
5. **Visibility Control**: Granular access control per package

## Verification Commands

```bash
# Check if container exists and is accessible
docker pull ghcr.io/pmpetit/postgresql_pglinter:pgrx

# List your GitHub packages
gh api user/packages --jq '.[].name'

# Check container in GitHub web interface
# Visit: https://github.com/pmpetit?tab=packages
```

All GitLab Container Registry references have been successfully migrated to GitHub Container Registry with the correct `postgresql_pglinter` image name! 🎉
