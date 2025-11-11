# How-To Guides

Practical guides for common pglinter scenarios and use cases.

## Create extension

### download packages

**Debian/Ubuntu Systems:**
```bash
PGVER=17
PGLINTER=0.0.20

wget https://github.com/pmpetit/pglinter/releases/download/${PGVER}/postgresql_pglinter_${PGVER}_${PGLINTER}_amd64.deb
sudo dpkg -i postgresql_pglinter_${PGVER}_${PGLINTER}_amd64.deb

# Fix dependencies if needed
sudo apt-get install -f
```

**RHEL/CentOS/Fedora Systems:**
```bash
PGVER=17
PGLINTER=0.0.20
wget https://github.com/pmpetit/pglinter/releases/download/${PGVER}/postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
sudo rpm -i postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
# or
sudo yum localinstall postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
```

### 💻 Usage

After installation, enable the extension in your PostgreSQL database:

```sql
-- Connect to your database
\c your_database

-- Create the extension
CREATE EXTENSION pglinter;

-- Run a basic check
SELECT pglinter.check();

-- Check specific rules
SELECT pglinter.check_rule('B001');  -- Tables without primary keys
SELECT pglinter.check_rule('B002');  -- Redundant indexes
```

### 📋 Available Rules

- **B00**: Base database rules (primary keys, indexes, schemas, etc.)
- **C00**: Cluster security rules
- **S00**: Schema rules

## kubernetes install from oci image

### example with kind

from this kind-with-imagevolume.yaml

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: imagevolume-cluster
# -----------------------------------------------
# 1. Enable the Feature Gate cluster-wide
# -----------------------------------------------
featureGates:
  ImageVolume: true
# -----------------------------------------------
```

```bash
kind create cluster --config kind-with-imagevolume.yaml
```

### install pcn

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.28.0-rc1.yam
```

### create cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-pglinter
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:18-minimal-trixie
  instances: 1

  storage:
    size: 1Gi

  postgresql:
    extensions:
    - name: pglinter
      image:
        reference: ghcr.io/pmpetit/pglinter:1.0.0-18-trixie
```

and its database

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: cluster-pglinter-app
spec:
  name: app
  owner: app
  cluster:
    name: cluster-pglinter
  extensions:
  - name: pglinter
```

then

```log
postgres=# \dx
                          List of installed extensions
  Name   | Version | Default version |   Schema   |         Description
---------+---------+-----------------+------------+------------------------------
 plpgsql | 1.0     | 1.0             | pg_catalog | PL/pgSQL procedural language
(1 row)

postgres=# \l
                                                List of databases
   Name    |  Owner   | Encoding | Locale Provider | Collate | Ctype | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+---------+-------+--------+-----------+-----------------------
 app       | app      | UTF8     | libc            | C       | C     |        |           |
 postgres  | postgres | UTF8     | libc            | C       | C     |        |           |
 template0 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
(4 rows)

postgres=# \c app
You are now connected to database "app" as user "postgres".
app=# \dx
                                           List of installed extensions
   Name   | Version | Default version |   Schema   |                         Description
----------+---------+-----------------+------------+--------------------------------------------------------------
 pglinter | 1.0.0   | 1.0.0           | public     | pglinter: PostgreSQL Database Linting and Analysis Extension
 plpgsql  | 1.0     | 1.0             | pg_catalog | PL/pgSQL procedural language
(2 rows)

app=#

```

pglinter extension is installed.
