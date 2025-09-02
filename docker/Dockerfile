ARG PG_MAJOR_VERSION=17

FROM postgres:${PG_MAJOR_VERSION}

# Set environment variables
ENV POSTGRES_DB=pglinter_test
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

# Install build dependencies and PostgreSQL development headers
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-${PG_MAJOR_VERSION} \
    git \
    make \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create extension directory
RUN mkdir -p /tmp/pglinter

# Copy pglinter source code
COPY . /tmp/pglinter/

# Build and install pglinter extension
WORKDIR /tmp/pglinter
RUN make install

# Copy initialization script
COPY docker/init_pglinter.sh /docker-entrypoint-initdb.d/

# Make initialization script executable
RUN chmod +x /docker-entrypoint-initdb.d/init_pglinter.sh

# Expose PostgreSQL port
EXPOSE 5432

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} || exit 1

# Add labels for better image management
LABEL maintainer="pmpetit"
LABEL description="PostgreSQL with pglinter extension"
LABEL org.opencontainers.image.source="https://github.com/pmpetit/pglinter"
