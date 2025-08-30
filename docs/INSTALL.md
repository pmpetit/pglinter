# Installation Guide

This guide covers the installation of PG Linter on various platforms and configurations.

## Prerequisites

- PostgreSQL 13, 14, 15, or 16
- Rust 1.70+ (for building from source)
- PostgreSQL development headers
- Cargo pgrx

## Installation Methods

### Method 1: From Source (Recommended)

#### 1. Install Rust and pgrx

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Install cargo-pgrx
cargo install cargo-pgrx

# Initialize pgrx
cargo pgrx init
```

#### 2. Clone and Build

```bash
# Clone the repository
git clone https://github.com/yourorg/dblinter.git
cd dblinter

# Build the extension
cargo pgrx package

# Install the extension
sudo cargo pgrx install
```

#### 3. Enable in PostgreSQL

```sql
-- Connect to your database
psql -d your_database

-- Create the extension
CREATE EXTENSION dblinter;

-- Verify installation
SELECT dblinter.show_rules();
```

### Method 2: Pre-built Packages

#### Ubuntu/Debian

```bash
# Add repository
curl -s https://packagecloud.io/install/repositories/yourorg/dblinter/script.deb.sh | sudo bash

# Install
sudo apt-get install postgresql-dblinter
```

#### RHEL/CentOS/Fedora

```bash
# Add repository
curl -s https://packagecloud.io/install/repositories/yourorg/dblinter/script.rpm.sh | sudo bash

# Install
sudo yum install postgresql-dblinter
```

#### Docker

```bash
# Use the official PostgreSQL image with dblinter
docker pull yourorg/postgresql-dblinter:latest

# Or add to existing PostgreSQL container
docker run --rm -v $(pwd):/workspace \
  yourorg/dblinter-installer:latest \
  /workspace/install.sh
```

## Platform-Specific Instructions

### Ubuntu 22.04 LTS

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y postgresql-server-dev-14 build-essential curl

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow Method 1 above
```

### CentOS 8 / RHEL 8

```bash
# Install dependencies
sudo dnf install -y postgresql-devel gcc curl

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow Method 1 above
```

### macOS

```bash
# Install dependencies (using Homebrew)
brew install postgresql rust

# Install pgrx
cargo install cargo-pgrx
cargo pgrx init

# Follow Method 1 above
```

### Windows

DBLinter can be built on Windows using WSL2:

```bash
# Install WSL2 with Ubuntu
wsl --install -d Ubuntu

# Inside WSL2, follow Ubuntu instructions above
```

## Cloud Platforms

### Amazon RDS

DBLinter requires custom extensions which are not supported on Amazon RDS. Consider using:
- Amazon Aurora PostgreSQL (with custom parameter groups)
- Self-managed PostgreSQL on EC2

### Google Cloud SQL

Similar limitations to RDS. Consider:
- Google Cloud SQL with custom flags (limited support)
- Self-managed PostgreSQL on Compute Engine

### Azure Database for PostgreSQL

Check Azure's extension support policy. Consider:
- Azure Database for PostgreSQL Flexible Server
- Self-managed PostgreSQL on Azure VMs

## Verification

After installation, verify that DBLinter is working correctly:

```sql
-- Check extension is installed
\dx dblinter

-- Test basic functionality
SELECT dblinter.perform_base_check();

-- Check rule management
SELECT dblinter.show_rules();
SELECT dblinter.explain_rule('B001');
```

## Troubleshooting

### Common Issues

#### 1. "extension not found"
```sql
-- Check if extension files are in the right location
SELECT * FROM pg_available_extensions WHERE name = 'dblinter';
```

#### 2. Permission denied
```bash
# Ensure PostgreSQL can read extension files
sudo chmod 644 /usr/share/postgresql/*/extension/dblinter*
sudo chown root:root /usr/share/postgresql/*/extension/dblinter*
```

#### 3. Build errors
```bash
# Ensure all dependencies are installed
cargo pgrx install --verbose

# Check PostgreSQL development headers
pg_config --includedir
```

### Getting Help

If you encounter issues:

1. Check the [troubleshooting section](troubleshooting.md)
2. Search [existing issues](https://github.com/yourorg/dblinter/issues)
3. Create a [new issue](https://github.com/yourorg/dblinter/issues/new) with:
   - PostgreSQL version (`SELECT version();`)
   - Operating system
   - Installation method used
   - Complete error messages

## Next Steps

After successful installation:

1. Read the [Configuration Guide](configure.md)
2. Try the [Quick Start Tutorial](tutorials/quickstart.md)
3. Explore the [Rule Reference](rules/)
