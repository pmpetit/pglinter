##
## pglinter Makefile
##
## This Makefile is based on the PGXS Makefile pattern
##

PGRX?=cargo pgrx
PGVER?=$(shell grep 'default = \[".*\"]' Cargo.toml | sed -e 's/.*\["//' | sed -e 's/"].*//')
PG_MAJOR_VERSION=$(PGVER:pg%=%)
PGLINTER_VERSION?=$(shell grep '^version *= *' Cargo.toml | sed 's/^version *= *//' | tr -d '\"' | tr -d ' ' )

# use `TARGET=debug make run` for more detailed errors
TARGET?=release
TARGET_DIR?=target/$(TARGET)/pglinter-$(PGVER)/
PG_CONFIG?=`$(PGRX) info pg-config $(PGVER) 2> /dev/null || echo pg_config`
PG_SHAREDIR?=$(shell $(PG_CONFIG) --sharedir)
PG_LIBDIR?=$(shell $(PG_CONFIG) --libdir)
PG_PKGLIBDIR?=$(shell $(PG_CONFIG) --pkglibdir)
PG_BINDIR?=$(shell $(PG_CONFIG) --bindir)

# pgrx always creates .so files, even on macOS
LIB_SUFFIX?=so
LIB=pglinter.$(LIB_SUFFIX)

# The instance
PGDATA_DIR=~/.pgrx/data-$(PG_MAJOR_VERSION)

# Be sure to use the PGRX version (PGVER) of the postgres binaries
PATH:=$(PG_BINDIR):${PATH}

# This is where the package is placed - updated for pgrx 0.16.0 structure
TARGET_SHAREDIR?=$(TARGET_DIR)usr/share/postgresql/$(PG_MAJOR_VERSION)
TARGET_PKGLIBDIR?=$(TARGET_DIR)usr/lib/postgresql/$(PG_MAJOR_VERSION)/lib

PG_REGRESS?=$(PG_PKGLIBDIR)/pgxs/src/test/regress/pg_regress
PG_SOCKET_DIR?=/var/lib/postgresql/.pgrx/
PGHOST?=localhost
PGPORT?=288$(subst pg,,$(PGVER))
PSQL_OPT?=--host $(PGHOST) --port $(PGPORT)
PGDATABASE?=contrib_regression

##
## Test configuration.
##

# List of test files (without .sql extension)
REGRESS_TESTS = t003_minimal
# REGRESS_TESTS+= b001
# REGRESS_TESTS+= cluster_rules
# REGRESS_TESTS+= integration_test
# REGRESS_TESTS+= output_options
# REGRESS_TESTS+= rule_management
# REGRESS_TESTS+= schema_rules
# REGRESS_TESTS+= simple_primary_keys
# REGRESS_TESTS+= t003
# REGRESS_TESTS+= simple_missing_index
# REGRESS_TESTS+= t008
# REGRESS_TESTS+= t010

# We try our best to write tests that produce the same output on all the 5
# current Postgres major versions. But sometimes it's really hard to do and
# we generally prefer simplicity over complex output manipulation tricks.
#
# In these few special cases, we use conditional tests with the following
# naming rules:
# * the _PG15+ suffix means PostgreSQL 15 and all the major versions after
# * the _PG13- suffix means PostgreSQL 13 and all the major versions below

REGRESS_TESTS_PG13 = elevation_via_rule_PG15- elevation_via_security_definer_function_PG14-
REGRESS_TESTS_PG14 = elevation_via_rule_PG15- elevation_via_security_definer_function_PG14-
REGRESS_TESTS_PG15 = elevation_via_rule_PG15-
REGRESS_TESTS_PG16 =
REGRESS_TESTS_PG17 =

REGRESS_TESTS+=${REGRESS_TESTS_PG${PG_MAJOR_VERSION}}

# Use this var to add more tests
#PG_TEST_EXTRA ?= ""
REGRESS_TESTS+=$(PG_TEST_EXTRA)

# This can be overridden by an env variable
REGRESS?=$(REGRESS_TESTS)

EXTRA_CLEAN?=target

##
## BUILD
##

all: extension

extension:
	$(PGRX) package --pg-config $(PG_CONFIG)

##
## INSTALL
##

install:
		cp -r $(TARGET_DIR)$(PG_SHAREDIR)/extension/* $(PG_SHAREDIR)/extension/; \
		install $(TARGET_DIR)$(PG_PKGLIBDIR)/$(LIB) $(PG_PKGLIBDIR); \

##
## INSTALLCHECK
##
## These are the functional tests, the unit tests are run with Cargo
##

# With PGXS: the postgres instance is created on-the-fly to run the test.
# With PGRX: the postgres instance is created previously by `cargo run`. This
# means we have some extra tasks to prepare the instance

# PGXS-style installcheck using pg_regress
installcheck: stop start
	dropdb $(PSQL_OPT) --if-exists $(PGDATABASE) || echo 'Database did not exist'
	createdb $(PSQL_OPT) $(PGDATABASE)
	$(PG_REGRESS) \
		$(PSQL_OPT) \
		--use-existing \
		--inputdir=./tests/ \
		--dbname=$(PGDATABASE) \
		$(REGRESS_OPTS) \
		$(REGRESS)

##
## PGRX commands
##

ifeq ($(TARGET),release)
  RELEASE_OPT=--release
endif

test:
	$(PGRX) test $(PGVER) $(RELEASE_OPT) --verbose

start:
	$(PGRX) start $(PGVER)

stop:
	$(PGRX) stop $(PGVER)

run:
	$(PGRX) run $(PGVER) $(RELEASE_OPT)

psql:
	psql --host localhost --port 288$(PG_MAJOR_VERSION)


##
## Coverage
##

COVERAGE_DIR?=target/$(TARGET)/coverage

clean_profiles:
	rm -fr *.profraw

coverage: clean_profiles coverage_test covergage_report

coverage_test:
	export RUSTFLAGS=-Cinstrument-coverage \
	export LLVM_PROFILE_FILE=$(TARGET)-%p-%m.profraw \
	&& $(PGRX) test $(PGVER) $(RELEASE_OPT) --verbose

coverage_report:
	mkdir -p $(COVERAGE_DIR)
	export LLVM_PROFILE_FILE=$(TARGET)-%p-%m.profraw \
	&& grcov . \
	      --binary-path target/$(TARGET) \
	      --source-dir . \
	      --output-path $(COVERAGE_DIR)\
	      --keep-only 'src/*' \
	      --llvm \
	      --ignore-not-existing \
	      --output-types html,cobertura
	# Terse output
	grep '<p class="heading">Lines</p>' -A2 $(COVERAGE_DIR)/html/index.html \
	  | tail -n 1 \
	  | xargs \
	  | sed 's,%.*,,' \
	  | sed 's/.*>/Coverage: /'

##
## CLEAN
##

clean:
ifdef EXTRA_CLEAN
	rm -rf $(EXTRA_CLEAN)
endif



##
## All targets below are not part of the PGXS Makefile
##

##
## P A C K A G E S
##

# The packages are built from the $(TARGET_DIR) folder.
# So the $(PG_PKGLIBDIR) and $(PG_SHAREDIR) are relative to that folder
rpm deb: package
	export PG_PKGLIBDIR=".$(PG_PKGLIBDIR)" && \
	export PG_SHAREDIR=".$(PG_SHAREDIR)" && \
	export PG_MAJOR_VERSION="$(PG_MAJOR_VERSION)" && \
	export ANON_MINOR_VERSION="$(ANON_MINOR_VERSION)" && \
	envsubst < nfpm.template.yaml > $(TARGET_DIR)/nfpm.yaml
	cd $(TARGET_DIR) && nfpm package --packager $@


# The `package` command needs pg_config from the target version
# https://github.com/pgcentralfoundation/pgrx/issues/288

package:
	$(PGRX) package --pg-config $(PG_CONFIG)

##
## D O C K E R
##

DOCKER_TAG?=latest
DOCKER_IMAGE?=registry.gitlab.com/dalibo/postgresql_anonymizer:$(DOCKER_TAG)

ifneq ($(DOCKER_PG_MAJOR_VERSION),)
DOCKER_BUILD_ARG := --build-arg DOCKER_PG_MAJOR_VERSION=$(DOCKER_PG_MAJOR_VERSION)
endif

PGRX_IMAGE?=$(DOCKER_IMAGE):pgrx
PGRX_BUILD_ARGS?=

docker_image: docker/Dockerfile #: build the docker image
	docker build --tag $(DOCKER_IMAGE) . --file $^  $(DOCKER_BUILD_ARG)

pgrx_image: docker/pgrx/Dockerfile
	docker build --tag $(PGRX_IMAGE) . --file $^ $(PGRX_BUILD_ARGS)

docker_push: #: push the docker image to the registry
	docker push $(DOCKER_IMAGE)

pgrx_push:
	docker push $(PGRX_IMAGE)

docker_bash: #: enter the docker image (useful for testing)
	docker exec -it docker-PostgreSQL-1 bash

pgrx_bash:
	docker run --rm --interactive --tty --volume  `pwd`:/pgrx $(PGRX_IMAGE)

COMPOSE=docker compose --file docker/docker-compose.yml

docker_init: #: start a docker container
	$(COMPOSE) down
	$(COMPOSE) up -d
	@echo "The Postgres server may take a few seconds to start. Please wait."

##
## L I N T
##

lint:
	cargo clippy --release

##
## P R E - C O M M I T
##

# Fast pre-commit checks (used by git hooks)
precommit-fast: lint
	@echo "✅ Fast pre-commit checks completed"

# Full pre-commit checks (more comprehensive)
precommit: lint test
	@echo "✅ Full pre-commit checks completed"

# Check formatting without fixing
format-check:
	cargo fmt --all -- --check

# Fix formatting
format:
	cargo fmt --all
