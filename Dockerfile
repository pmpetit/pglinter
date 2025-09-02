# Multi-stage Dockerfile for pglinter PostgreSQL extension
# Supports PostgreSQL 13-18

# Build argument for PostgreSQL version
ARG PG_MAJOR_VERSION=17

##
## First Stage: Rust Build Environment
##
FROM rust:1.89.0-slim as builder

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    libclang-dev \
    pkg-config \
    git \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy source code
COPY Cargo.toml Cargo.lock ./
COPY src/ ./src/
COPY pglinter.control ./
COPY sql/ ./sql/

# Install cargo-pgrx
RUN cargo install --locked cargo-pgrx --version 0.16.0

# Build arguments for PostgreSQL version
ARG PG_MAJOR_VERSION=17

# Install PostgreSQL for the specified version
RUN apt-get update && apt-get install -y \
    postgresql-${PG_MAJOR_VERSION} \
    postgresql-server-dev-${PG_MAJOR_VERSION} \
    postgresql-client-${PG_MAJOR_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Initialize pgrx with system PostgreSQL
RUN cargo pgrx init --pg${PG_MAJOR_VERSION} /usr/lib/postgresql/${PG_MAJOR_VERSION}/bin/pg_config

# Build the extension
RUN cargo pgrx package --pg-config /usr/lib/postgresql/${PG_MAJOR_VERSION}/bin/pg_config

##
## Second Stage: PostgreSQL Runtime
##
ARG PG_MAJOR_VERSION=17
FROM postgres:${PG_MAJOR_VERSION}

# Re-declare the ARG for this stage
ARG PG_MAJOR_VERSION=17

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy the built extension from the builder stage
COPY --from=builder /build/target/release/pglinter-pg${PG_MAJOR_VERSION}/usr/share/postgresql/${PG_MAJOR_VERSION}/extension/* \
    /usr/share/postgresql/${PG_MAJOR_VERSION}/extension/

COPY --from=builder /build/target/release/pglinter-pg${PG_MAJOR_VERSION}/usr/lib/postgresql/${PG_MAJOR_VERSION}/lib/pglinter.so \
    /usr/lib/postgresql/${PG_MAJOR_VERSION}/lib/

# Copy test files for regression testing
COPY tests/ /tests/

# Create initialization script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY docker/init_pglinter.sh /docker-entrypoint-initdb.d/

# Set environment variables
ENV POSTGRES_DB=pglinter_test
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

# Expose PostgreSQL port
EXPOSE 5432

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pg_isready -U postgres -d pglinter_test || exit 1

# Labels for GitHub Container Registry
LABEL org.opencontainers.image.source="https://github.com/pmpetit/pglinter"
LABEL org.opencontainers.image.description="PostgreSQL extension for linting and code quality"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="pglinter"
