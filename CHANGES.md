# pglinter Changes

All notable changes to the pglinter PostgreSQL extension project.

## [1.0.0] - 2024-11-11

### 🚀 Major Features

#### PostgreSQL 18 Support

- **PostgreSQL 18beta2 Compatibility**: Full support for the latest PostgreSQL version using pgrx 0.16.1
- **Multi-Version Support**: Comprehensive compatibility matrix covering PostgreSQL 13-18
- **Beta Testing**: Early adoption of PostgreSQL 18 features for future-proofing

#### CloudNative-PG Integration

- **OCI Extension Images**: Native support for CloudNative-PG extension deployment
- **Kubernetes Ready**: First-class Kubernetes integration with ImageVolume support
- **Container Orchestration**: Seamless deployment in cloud-native PostgreSQL environments

### 🐳 Container & Distribution Enhancements

#### OCI Container Images

- **Multi-Architecture Support**: AMD64 and ARM64 container images
- **CloudNative-PG Compliance**: Following official Image Specifications
- **Lightweight Images**: Optimized scratch-based extension containers
- **Registry Integration**: GitHub Container Registry (ghcr.io) publishing

#### Enhanced Docker Support

- **Multi-Version Containers**: Support for PostgreSQL 13-18 in Docker
- **Development Environment**: Complete Docker Compose setup for testing
- **CI/CD Integration**: Automated container builds and testing
- **Health Checks**: Built-in container health monitoring

### 🛠 Development & Build Improvements

#### Rust Toolchain Updates

- **Rust 1.88.0+**: Updated to latest stable Rust version requirements
- **pgrx 0.16.1**: Latest PostgreSQL extension framework support
- **Performance Optimizations**: Enhanced build configuration with LTO and optimization flags
- **Cross-Platform Builds**: Support for multi-architecture compilation

#### Package Distribution

- **DEB Packages**: Native Debian/Ubuntu package support
- **RPM Packages**: Red Hat/Rocky Linux package distribution
- **Multi-Architecture**: AMD64 and ARM64 package variants
- **Automated Releases**: GitHub Actions-powered package creation

### 📊 Rule Engine & Analysis

#### Enhanced Rule Categories

- **B-Rules (Base/Database)**: Comprehensive database structure analysis
  - Primary key validation (B001)
  - Index optimization checks (B002-B004)
  - Foreign key analysis (B003, B007-B008)
  - Table naming and usage validation (B005-B006, B010-B011)
  - Trigger optimization (B009)

- **C-Rules (Cluster)**: PostgreSQL cluster configuration validation
  - Authentication security checks (C003)
  - Password policy validation
  - Security configuration analysis

- **S-Rules (Schema)**: Schema-level security and organization
  - Role-based access validation (S001, S004-S005)
  - Environment naming conventions (S002)
  - Public schema security (S003)

#### SARIF Output Format

- **Industry Standard**: Static Analysis Results Interchange Format support
- **Tool Integration**: Compatible with modern development tools
- **Structured Results**: Machine-readable analysis output
- **Error Tracking**: Detailed location and severity information

### ⚙️ Configuration Management

#### YAML Configuration Support

- **Export/Import**: Rule configuration as code
- **Version Control**: Configuration versioning and sharing
- **Environment Management**: Different rule sets per environment
- **Batch Operations**: Bulk rule configuration updates

#### Dynamic Rule Management

- **Runtime Configuration**: Enable/disable rules without restart
- **Threshold Management**: Configurable warning and error levels
- **Rule Prioritization**: Custom severity assignments
- **Status Monitoring**: Real-time rule status visibility

### 🔧 Installation & Deployment

#### Multiple Installation Methods

- **Package Managers**: Native DEB/RPM package installation
- **Container Deployment**: Docker and Kubernetes support
- **Source Building**: Development environment setup
- **Extension Registry**: PostgreSQL extension ecosystem integration

#### Kubernetes Integration

- **CloudNative-PG**: First-class operator support
- **ImageVolume Extensions**: Modern extension loading mechanism
- **Cluster Configuration**: Declarative PostgreSQL cluster setup
- **Database Management**: Automated extension deployment

### 🧪 Testing & Quality Assurance

#### Comprehensive Test Suite

- **SQL Regression Tests**: Complete rule validation testing
- **Multi-Version Testing**: PostgreSQL 13-18 compatibility verification
- **Container Testing**: Docker image validation
- **Integration Testing**: End-to-end deployment scenarios

#### Development Tools

- **Pre-commit Hooks**: Code quality enforcement
- **CI/CD Pipeline**: Automated testing and deployment
- **Documentation Generation**: MkDocs-powered documentation
- **Performance Benchmarking**: Rule execution performance monitoring

### 📖 Documentation & Examples

#### Enhanced Documentation

- **Tutorial System**: Step-by-step rule creation guide
- **API Reference**: Complete function documentation
- **Configuration Guide**: Comprehensive setup instructions
- **Integration Examples**: Real-world deployment scenarios

#### Community Resources

- **Contributing Guide**: Developer onboarding documentation
- **Security Policy**: Vulnerability reporting procedures
- **Examples Repository**: Sample configurations and use cases
- **Best Practices**: PostgreSQL linting recommendations

### 🔒 Security & Compliance

#### Security Features

- **SECURITY DEFINER**: Secure function execution model
- **Input Validation**: SQL injection prevention
- **Privilege Separation**: Minimal permission requirements
- **Audit Trail**: Rule execution logging

#### Compliance Standards

- **PostgreSQL Standards**: Official best practices enforcement
- **Industry Guidelines**: Database security recommendations
- **Performance Standards**: Query optimization validation
- **Schema Conventions**: Naming and organization rules

## Infrastructure & Architecture

### Core Components

- **Rule Engine** (`execute_rules.rs`): High-performance rule execution
- **Configuration Manager** (`manage_rules.rs`): Dynamic rule management
- **SARIF Generator**: Standards-compliant output formatting
- **Test Framework**: Comprehensive validation system

### Performance Characteristics

- **Native Performance**: Rust-powered execution speed
- **Memory Efficiency**: Optimized resource usage
- **Scalability**: Large database support
- **Concurrent Execution**: Multi-rule parallel processing

### Extensibility Framework

- **Plugin Architecture**: Future custom rule support
- **API Stability**: Backward-compatible interface
- **Configuration API**: Programmatic rule management
- **Integration Points**: External tool connectivity

## Migration & Compatibility

### From Python dblinter

- **Feature Parity**: Complete Python version functionality
- **Performance Improvement**: Significant speed enhancements
- **Enhanced Integration**: Native PostgreSQL extension benefits
- **Backward Compatibility**: Familiar rule naming and behavior

### Version Compatibility

- **PostgreSQL 13-18**: Full version range support
- **pgrx Framework**: Latest extension development tools
- **Rust Ecosystem**: Modern development stack
- **Container Standards**: OCI and CloudNative-PG compliance

---

For detailed installation instructions, configuration examples, and usage documentation, visit the [pglinter documentation](https://pglinter.readthedocs.io/).

**Repository**: [https://github.com/pmpetit/pglinter](https://github.com/pmpetit/pglinter)
**Container Images**: [ghcr.io/pmpetit/pglinter](https://github.com/pmpetit/pglinter/pkgs/container/pglinter)
**OCI Extensions**: [ghcr.io/pmpetit/pglinter](https://github.com/pmpetit/pglinter/pkgs/container/pglinter) (CloudNative-PG compatible)
