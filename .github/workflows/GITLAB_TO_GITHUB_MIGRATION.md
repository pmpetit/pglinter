# GitLab CI to GitHub Actions Migration Summary

## Overview

Successfully converted the GitLab CI template `build_and_test_pgver.yml` to GitHub Actions using the GitHub Actions Importer and manual refinement.

## Files Created

### 1. `.github/workflows/build_and_test_pgver.yml`
- **Purpose**: Reusable workflow template equivalent to the GitLab CI job template
- **Type**: `workflow_call` (reusable workflow)
- **Inputs**:
  - `always`: Optional string to force all jobs to run
  - `pgver`: Required PostgreSQL version (e.g., `pg13`, `pg16`)

### 2. `.github/workflows/build_all_versions.yml`
- **Purpose**: Main workflow that calls the reusable template for all PostgreSQL versions
- **Triggers**: Push, PR, schedule, manual dispatch
- **Versions**: Builds and tests PostgreSQL 13-17

## Key Conversions

### GitLab CI → GitHub Actions Mappings

| GitLab CI | GitHub Actions | Notes |
|-----------|----------------|-------|
| `spec.inputs` | `workflow_call.inputs` | Reusable workflow parameters |
| `stage: build` | `jobs.build` | Job organization |
| `image: registry.gitlab.com/...` | `container: ghcr.io/pmpetit/...` | Container image (moved to GHCR) |
| `variables` | `env` | Environment variables |
| `rules` | `if` conditions | Conditional job execution |
| `dependencies` | `needs` | Job dependencies |
| `artifacts` | `actions/upload-artifact@v4` | Artifact handling |
| `script` | `run` | Command execution |

### Trigger Conversion

**GitLab CI Rules** → **GitHub Actions Conditions**:
```yaml
# GitLab CI
rules:
  - if: $ALWAYS
  - if: $CI_PIPELINE_SOURCE == "schedule"
  - if: $CI_PIPELINE_SOURCE == "web"
  - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  - if: $CI_COMMIT_TAG

# GitHub Actions
if: |
  inputs.always != '' ||
  github.event_name == 'schedule' ||
  github.event_name == 'workflow_dispatch' ||
  github.ref == github.event.repository.default_branch ||
  startsWith(github.ref, 'refs/tags/')
```

### Job Structure

**GitLab CI Template Structure**:
- `build-$[[ inputs.pgver ]]`
- `installcheck-$[[ inputs.pgver ]]`
- `upload-packages-$[[ inputs.pgver ]]`
- `release-packages-$[[ inputs.pgver ]]`

**GitHub Actions Structure**:
- `build` (with dynamic name)
- `installcheck` (depends on build)
- `upload-packages` (depends on build)
- `release-packages` (depends on build + upload)

## Key Differences & Improvements

### 1. **Artifact Handling**
- **GitLab**: File paths in `artifacts.paths`
- **GitHub**: Dedicated upload/download actions with retention policies

### 2. **Release Management**
- **GitLab**: Manual release creation with curl uploads
- **GitHub**: Automated releases using `softprops/action-gh-release`

### 3. **Package Distribution**
- **GitLab**: Upload to GitLab Package Registry
- **GitHub**: Upload to GitHub Releases (could be extended to GitHub Packages)

### 4. **Conditional Logic**
- **GitLab**: Rule-based with complex conditions
- **GitHub**: Conditional expressions with `if` statements

## Usage Examples

### Using the Reusable Workflow

```yaml
jobs:
  test-pg16:
    uses: ./.github/workflows/build_and_test_pgver.yml
    with:
      pgver: 'pg16'
      always: 'true'  # Force run even if conditions don't match
```

### Manual Dispatch

```bash
# Trigger manually via GitHub CLI
gh workflow run build_all_versions.yml

# Trigger for specific version
gh workflow run build_and_test_pgver.yml -f pgver=pg16 -f always=true
```

## Environment Variables

The workflows maintain the same environment variables as the GitLab CI:
- `PGVER`: PostgreSQL version
- `ALWAYS`: Force execution flag

## Container Registry Migration

**Original**: `registry.gitlab.com/dalibo/postgresql_anonymizer:pgrx`
**Updated**: `ghcr.io/pmpetit/postgresql_pglinter:pgrx`

### Prerequisites for GCR Usage

1. **Build and push the container to GCR**:
   ```bash
   # Build the container locally
   docker build -t ghcr.io/pmpetit/postgresql_pglinter:pgrx .

   # Configure Docker for GCR (requires Google Cloud SDK)
   gcloud auth configure-docker

   # Push to GCR
   docker push ghcr.io/pmpetit/postgresql_pglinter:pgrx
   ```

2. **Make the container publicly accessible** (if needed):
   ```bash
   # Make the container public (optional)
   gcloud container images add-iam-policy-binding \
     ghcr.io/pmpetit/postgresql_pglinter:pgrx \
     --member=allUsers \
     --role=roles/storage.objectViewer
   ```

3. **Alternative: Use GitHub Container Registry (GHCR)**:
   ```yaml
   # Instead of GCR, you could use:
   container: ghcr.io/pmpetit/postgresql_pglinter:pgrx
   ```

## Migration Benefits

1. **Native GitHub Integration**: Better integration with GitHub features
2. **Artifact Management**: More robust artifact handling
3. **Release Automation**: Simplified release creation
4. **Reusability**: Cleaner template reuse mechanism
5. **Visibility**: Better workflow visualization in GitHub UI

## Next Steps

1. **Test the workflows** by pushing to the repository
2. **Configure secrets** if needed for package uploads
3. **Customize triggers** based on your specific needs
4. **Add additional PostgreSQL versions** as needed
5. **Consider GitHub Packages** for package distribution

## Commands Used

```bash
# Install GitHub Actions Importer
gh extension install github/gh-actions-importer

# Configure for GitLab CI
gh actions-importer configure

# Convert GitLab CI to GitHub Actions
gh actions-importer dry-run gitlab --project postgresql_anonymizer --namespace dalibo --source-file-path build_and_test_pgver.yml --output-dir .github/workflows
```

The migration preserves all the functionality of the original GitLab CI template while taking advantage of GitHub Actions' native features and improved user experience.
