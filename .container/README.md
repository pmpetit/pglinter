
Install with Kubernetes
------------------------------------------------------------------------------

limited to pg18 and k8s with option ImageVolume enabled.
This example was run with kind (Kubernetes In Docker), see [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)

_Step 0:_ Create the kind cluster

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

_Step 1:_ Install pcn

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.28.0-rc1.yam
```

_Step 2:_ Create pg cluster

you have the choice between trixie & bookworm

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
        reference: ghcr.io/pmpetit/pglinter:1.0.1-18-trixie
```

_Step 3:_ Create the database

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
 pglinter | 1.0.1   | 1.0.1           | public     | pglinter: PostgreSQL Database Linting and Analysis Extension
 plpgsql  | 1.0     | 1.0             | pg_catalog | PL/pgSQL procedural language
(2 rows)

app=#

```

pglinter extension is installed in the `app` database.
