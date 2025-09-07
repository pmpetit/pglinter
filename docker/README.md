# 🐳 pglinter Docker Setup

This directory contains Docker configuration for running pglinter PostgreSQL extension in containers.

## 🚀 Quick Start

### Pull Pre-built Images

```bash
# Pull specific PostgreSQL version
docker pull ghcr.io/pmpetit/pglinter:pg17-latest

# Or pull all versions
docker pull ghcr.io/pmpetit/pglinter:pg13-latest
docker pull ghcr.io/pmpetit/pglinter:pg14-latest
docker pull ghcr.io/pmpetit/pglinter:pg15-latest
docker pull ghcr.io/pmpetit/pglinter:pg16-latest
docker pull ghcr.io/pmpetit/pglinter:pg17-latest
```

### Run Container

```bash
# Run PostgreSQL 17 with pglinter
docker run -d \
  --name pglinter-pg17 \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=pglinter_test \
  ghcr.io/pmpetit/pglinter:pg17-latest

# Connect and test
docker exec -it pglinter-pg17 psql -U postgres -d pglinter_test
```

### Test Extension

```sql
-- In psql
SELECT pglinter.hello_pglinter();
SELECT pglinter.list_rules();
SELECT pglinter.check_all();
```

## 🛠️ Build Your Own Images

### Build Single Version

```bash
# Build PostgreSQL 17
make docker-build-pg17

# Or use docker directly
docker build --build-arg PG_MAJOR_VERSION=17 -t pglinter:pg17 .
```

### Build All Versions

```bash
make docker-build-all
```

## 🐙 Docker Compose

### Start All Versions

```bash
cd docker
docker-compose up -d
```

This starts containers for all PostgreSQL versions on different ports:
- PostgreSQL 13: `localhost:5413`
- PostgreSQL 14: `localhost:5414`
- PostgreSQL 15: `localhost:5415`
- PostgreSQL 16: `localhost:5416`
- PostgreSQL 17: `localhost:5417`

### Connect to Specific Version

```bash
# PostgreSQL 17
psql -h localhost -p 5417 -U postgres -d pglinter_test

# PostgreSQL 14
psql -h localhost -p 5414 -U postgres -d pglinter_test
```

### View Logs

```bash
cd docker
docker-compose logs -f pglinter-pg17
```

### Stop All

```bash
cd docker
docker-compose down
```

## 🧪 Running Tests

### Makefile Targets

```bash
# Start container and run tests
make docker-run-pg17
make docker-test
make docker-clean
```

### Manual Testing

```bash
# Start container
docker run -d --name test-pglinter -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  ghcr.io/pmpetit/pglinter:pg17-latest

# Wait for startup
sleep 10

# Run tests
docker exec test-pglinter psql -U postgres -d pglinter_test -c "
  SELECT pglinter.hello_pglinter();
  SELECT pglinter.check_all();
"

# Cleanup
docker stop test-pglinter
docker rm test-pglinter
```

## 📦 Available Images

| PostgreSQL Version | Image Tag | Size | Status |
|-------------------|-----------|------|--------|
| 13 | `ghcr.io/pmpetit/pglinter:pg13-latest` | ~400MB | ✅ |
| 14 | `ghcr.io/pmpetit/pglinter:pg14-latest` | ~400MB | ✅ |
| 15 | `ghcr.io/pmpetit/pglinter:pg15-latest` | ~400MB | ✅ |
| 16 | `ghcr.io/pmpetit/pglinter:pg16-latest` | ~400MB | ✅ |
| 17 | `ghcr.io/pmpetit/pglinter:pg17-latest` | ~400MB | ✅ |

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `pglinter_test` | Database name |
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | `postgres` | Database password |

## 🐛 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs pglinter-pg17

# Check if port is in use
sudo netstat -tulpn | grep 5432
```

### Extension Not Found

```bash
# Verify extension files
docker exec pglinter-pg17 ls -la /usr/share/postgresql/17/extension/pglinter*
docker exec pglinter-pg17 ls -la /usr/lib/postgresql/17/lib/pglinter.so
```

### Connection Issues

```bash
# Test connection
docker exec pglinter-pg17 pg_isready -U postgres

# Check PostgreSQL config
docker exec pglinter-pg17 cat /var/lib/postgresql/data/postgresql.conf | grep listen
```

## 📚 Integration Examples

### GitHub Actions

```yaml
services:
  postgres:
    image: ghcr.io/pmpetit/pglinter:pg17-latest
    env:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: test_db
    ports:
      - 5432:5432
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

### Docker Compose for Development

```yaml
version: '3.8'
services:
  db:
    image: ghcr.io/pmpetit/pglinter:pg17-latest
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: developer
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - ./sql:/docker-entrypoint-initdb.d
```

## 🏗️ Build Process

The images are built using a multi-stage Dockerfile:

1. **Build Stage**: Compile pglinter extension with Rust and cargo-pgrx
2. **Runtime Stage**: Install extension into PostgreSQL official image
3. **Test Stage**: Verify extension functionality

Images are automatically built and pushed to GitHub Container Registry via GitHub Actions.
