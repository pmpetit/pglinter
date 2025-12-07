INSTALL
===============================================================================

There are multiple ways to install the extension :

- [INSTALL](#install)
  - [Install on RedHat / Rocky Linux / Alma Linux](#install-on-redhat--rocky-linux--alma-linux)
  - [Install on Debian / Ubuntu](#install-on-debian--ubuntu)
  - [Install with Docker](#install-with-docker)
  - [Install with Kubernetes](#install-with-kubernetes)

Install on RedHat / Rocky Linux / Alma Linux
------------------------------------------------------------------------------

You can download the package from the
[Github Package Registry].

`ARCH="x86_64" or "aarch64"`

```console
export PG_MAJOR_VERSION=18
export PGLINTER_VERSION=1.0.1
export ARCH=x86_64
wget https://github.com/pmpetit/pglinter/releases/download/${PGLINTER_VERSION}/postgresql_pglinter_${PG_MAJOR_VERSION}-${PGLINTER_VERSION}-1.aarch64.rpm

sudo rpm -i postgresql_pglinter_${PG_MAJOR_VERSION}_${PGLINTER_VERSION-1}_${ARCH}.rpm
# or
sudo yum localinstall postgresql_pglinter_${PG_MAJOR_VERSION}-${PGLINTER_VERSION}-1.${ARCH}.rpm

```

Create the extension.

```sql
CREATE EXTENSION pglinter;
```

test

```sql
postgres=# select hello_pglinter();
 hello_pglinter
-----------------
 Hello, pglinter
(1 row)
postgres=#
```

Install on Debian / Ubuntu
------------------------------------------------------------------------------

You can download the package from the
[Github Package Registry].

`ARCH="arm64" or "amd64"`

```console
export PG_MAJOR_VERSION=18
export PGLINTER_VERSION=1.0.1
export ARCH=amd64
wget https://github.com/pmpetit/pglinter/releases/download/${PGLINTER_VERSION}/postgresql_pglinter_${PG_MAJOR_VERSION}-${PGLINTER_VERSION}_${ARCH}.deb

sudo dpkg -i postgresql_pglinter_${PG_MAJOR_VERSION}_${PGLINTER_VERSION}_${ARCH}.deb

```

Install with Docker
------------------------------------------------------------------------------

If you can't (or don't want to) install the PostgreSQL pglinter extension
directly inside your instance, then you can use the docker image :

```console
docker pull ghcr.io/pmpetit/postgresql_pglinter:latest
```

The image is available with 1 tag latest:

* `latest` (default) contains the current developments

You can run the docker image like the regular [postgres docker image].

[postgres docker image]: https://hub.docker.com/_/postgres

For example:

Launch a postgres docker container

```console
docker run -d -e POSTGRES_PASSWORD=x -p 6543:5432 ghcr.io/pmpetit/postgresql_pglinter:latest
```

then connect:

```console
export PGPASSWORD=x
psql --host=localhost --port=6543 --user=postgres
```

The extension is already created, you can use it directly:

```sql
postgres=# select hello_pglinter();
 hello_pglinter
-----------------
 Hello, pglinter
(1 row)
postgres=#
```

**Note:** The docker image is based on the latest PostgreSQL version and we do
not plan to provide a docker image for each version of PostgreSQL. However you
can build your own image based on the version you need like this:

```shell
DOCKER_PG_MAJOR_VERSION=16 make docker_image
```

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
