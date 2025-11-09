# GitHub Actions for OCI Extension Images

This directory contains GitHub Actions and workflows for building CloudNative-PG compatible OCI extension images for pglinter.

## Actions

### `build-oci-image`

A reusable action that builds OCI extension images following CloudNative-PG specifications.

**Inputs:**

- `postgresql-version`: PostgreSQL major version (default: '18')
- `distro`: Linux distribution (default: 'bookworm')  
- `registry`: Container registry (default: 'ghcr.io/pmpetit')
- `image-name`: Image name (default: 'pglinter')
- `push`: Whether to push to registry (default: 'false')
- `platforms`: Target platforms (default: 'linux/amd64,linux/arm64')
- `build-local`: Use local .deb packages (default: 'false')

**Outputs:**

- `image-tags`: Generated image tags
- `image-digest`: Image digest

## Workflows

### `build-oci-images.yml`

Main workflow that builds OCI images on:

- Push to `main` branch
- Pull requests  
- Tagged releases
- Manual dispatch

Features:

- Matrix build for multiple PostgreSQL versions
- Local builds for PRs (faster, single arch)
- Multi-arch builds for releases
- Automatic pushing based on trigger type
- Image testing and security scanning

### `release-oci-images.yml`

Release workflow triggered by:

- GitHub releases
- Manual dispatch with version input

Features:

- Multi-arch builds (amd64, arm64)
- Uses published GitHub releases for .deb packages
- Updates release notes with container image info
- Matrix support for multiple PostgreSQL versions

### `test-oci-build.yml`

Manual testing workflow for:

- Testing specific PostgreSQL versions
- Validating builds before releases
- Optional registry pushing

## Usage Examples

### Manual Build Test

```bash
# Trigger via GitHub UI or gh CLI
gh workflow run test-oci-build.yml -f postgresql_version=18 -f push_to_registry=false
```

### Using the Action in Other Workflows

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Build OCI Image
    uses: ./.github/actions/build-oci-image
    with:
      postgresql-version: '18'
      registry: 'ghcr.io/myorg'
      image-name: 'my-extension'
      push: 'true'
      build-local: 'false'
```

### CloudNative-PG Usage

The built images can be used in CloudNative-PG clusters:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-with-pglinter
spec:
  postgresql:
    extensions:
      - name: pglinter
        image:
          reference: ghcr.io/pmpetit/pglinter:1.0.0
```

## Image Tags

Images are tagged with:

- `{version}-{timestamp}-pg{pg_version}-{distro}` (full tag)
- `latest` (latest build)
- `{version}` (version tag)

Example: `ghcr.io/pmpetit/pglinter:1.0.0-20241109195608-pg18-bookworm`

## Security

- Images are scanned with Trivy for vulnerabilities
- Results uploaded to GitHub Security tab
- Minimal scratch-based final images
- Multi-stage builds to reduce attack surface

## Development

To test locally:

```bash
# Build local test image
make oci_build_local

# Test image structure  
make oci_test

# Clean up
make oci_clean
```