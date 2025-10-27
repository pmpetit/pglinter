##
## pglinter Makefile
##
## This Makefile is based on the PGXS Makefile pattern
##

PGRX?=cargo pgrx
PGVER?=$(shell grep 'default = \[".*\"]' Cargo.toml | sed -e 's/.*\["//' | sed -e 's/"].*//')
PG_MAJOR_VERSION=$(PGVER:pg%=%)

PGLINTER_MINOR_VERSION = $(shell grep '^version *= *' Cargo.toml | sed 's/^version *= *//' | tr -d '\"' | tr -d ' ' )

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
REGRESS_TESTS = b001
REGRESS_TESTS+= b001_configurable
REGRESS_TESTS+= b001_primary_keys
REGRESS_TESTS+= b002_redundant_idx
REGRESS_TESTS+= b002_non_redundant_idx
REGRESS_TESTS+= b003_fk_not_indexed
REGRESS_TESTS+= b004_idx_not_used
REGRESS_TESTS+= b005_public_schema
REGRESS_TESTS+= b006_uppercase_test
REGRESS_TESTS+= b007_tables_not_selected
REGRESS_TESTS+= b008_fk_outside_schema
REGRESS_TESTS+= c002_hba_security_test
REGRESS_TESTS+= t001_primary_keys
REGRESS_TESTS+= t002_minimal
REGRESS_TESTS+= t002_redundant_idx
REGRESS_TESTS+= t003_table_with_fk_not_indexed
REGRESS_TESTS+= t004_simple_missing_index
REGRESS_TESTS+= t005_fk_outside
REGRESS_TESTS+= t006_unused_indexes
REGRESS_TESTS+= t007_fk_type_mismatch
REGRESS_TESTS+= t008_no_role_grants
REGRESS_TESTS+= t009_reserved_keywords
REGRESS_TESTS+= demo_rule_levels
REGRESS_TESTS+= import_rules_from_file
REGRESS_TESTS+= import_rules_from_yaml
REGRESS_TESTS+= integration_test
REGRESS_TESTS+= quick_demo_levels
REGRESS_TESTS+= rule_management
REGRESS_TESTS+= schema_rules
REGRESS_TESTS+= b015_trigger_sharing

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

REGRESS_TESTS_PG13 = c003_md5_pwd_PG17- c003_scram_PG17-
REGRESS_TESTS_PG14 = c003_md5_pwd_PG17- c003_scram_PG17-
REGRESS_TESTS_PG15 = c003_md5_pwd_PG17- c003_scram_PG17-
REGRESS_TESTS_PG16 = c003_md5_pwd_PG17- c003_scram_PG17-
REGRESS_TESTS_PG17 = c003_md5_pwd_PG17- c003_scram_PG17-

# REGRESS_TESTS_PG13 = elevation_via_rule_PG15- elevation_via_security_definer_function_PG14-
# REGRESS_TESTS_PG14 = elevation_via_rule_PG15- elevation_via_security_definer_function_PG14-
# REGRESS_TESTS_PG15 = elevation_via_rule_PG15-
# REGRESS_TESTS_PG16 =
# REGRESS_TESTS_PG17 =

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
	$(PGRX) test $(PGVER) $(RELEASE_OPT)

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
rpm: package
	export PG_PKGLIBDIR=".$(PG_PKGLIBDIR)" && \
	export PG_SHAREDIR=".$(PG_SHAREDIR)" && \
	export PG_MAJOR_VERSION="$(PG_MAJOR_VERSION)" && \
	export PGLINTER_MINOR_VERSION="$(PGLINTER_MINOR_VERSION)" && \
	export PACKAGE_ARCH="${PACKAGE_ARCH}" && \
	echo "Building RPM package with architecture: ${PACKAGE_ARCH}" && \
	envsubst < nfpm.template.yaml > $(TARGET_DIR)/nfpm.yaml
	cd $(TARGET_DIR) && nfpm package --packager rpm
	@echo "RPM package created: $$(find $(TARGET_DIR) -name '*.rpm' -exec basename {} \;)"

deb: package
	export PG_PKGLIBDIR=".$(PG_PKGLIBDIR)" && \
	export PG_SHAREDIR=".$(PG_SHAREDIR)" && \
	export PG_MAJOR_VERSION="$(PG_MAJOR_VERSION)" && \
	export PGLINTER_MINOR_VERSION="$(PGLINTER_MINOR_VERSION)" && \
	export PACKAGE_ARCH="${PACKAGE_ARCH}" && \
	echo "Building DEB package with architecture: ${PACKAGE_ARCH}" && \
	envsubst < nfpm.template.yaml > $(TARGET_DIR)/nfpm.yaml
	cd $(TARGET_DIR) && nfpm package --packager deb
	@echo "DEB package created: $$(find $(TARGET_DIR) -name '*.deb' -exec basename {} \;)"


# The `package` command needs pg_config from the target version
# https://github.com/pgcentralfoundation/pgrx/issues/288

package:
	$(PGRX) package --pg-config $(PG_CONFIG)

##
## D O C K E R
##

DOCKER_TAG?=latest
DOCKER_IMAGE?=ghcr.io/pmpetit/postgresql_pglinter

ifneq ($(DOCKER_PG_MAJOR_VERSION),)
DOCKER_BUILD_ARG := --build-arg DOCKER_PG_MAJOR_VERSION=$(DOCKER_PG_MAJOR_VERSION)
endif

PGRX_IMAGE?=$(DOCKER_IMAGE):pgrx
PGRX_BUILD_ARGS?=

docker_image: docker/Dockerfile #: build the docker image
	#: docker build --tag $(DOCKER_IMAGE):$(DOCKER_TAG) . --file $^  $(DOCKER_BUILD_ARG)
	@echo "Setting up buildx for multi-platform builds..."
	docker buildx create --name pglinter-builder --use --bootstrap 2>/dev/null || \
	docker buildx use pglinter-builder 2>/dev/null || \
	(echo "Creating new buildx instance..." && docker buildx create --name pglinter-builder --use --bootstrap)
	@echo "Building multi-platform image..."
	docker buildx build \
			--platform linux/amd64,linux/arm64 \
			--tag $(DOCKER_IMAGE):$(DOCKER_TAG) \
			--file $^ \
			$(DOCKER_BUILD_ARG) \
			.

# Build AMD64 pgrx image separately
pgrx_image_amd64_only: docker/pgrx/Dockerfile
	@echo "Building AMD64 pgrx image..."
	docker buildx build \
			--platform linux/amd64 \
			--tag $(PGRX_IMAGE)-amd64 \
			--file $^ \
			--load \
			--no-cache \
			$(PGRX_BUILD_ARGS) \
			.
	@echo "AMD64 pgrx image built: $(PGRX_IMAGE)-amd64"

# Build ARM64 pgrx image separately
pgrx_image_arm64_only: docker/pgrx/Dockerfile
	@echo "Building ARM64 pgrx image..."
	docker buildx build \
			--platform linux/arm64 \
			--tag $(PGRX_IMAGE)-arm64 \
			--file $^ \
			--load \
			--no-cache \
			$(PGRX_BUILD_ARGS) \
			.
	@echo "ARM64 pgrx image built: $(PGRX_IMAGE)-arm64"

# Build both architectures and create multi-arch manifest
pgrx_image: pgrx_image_amd64_only pgrx_image_arm64_only
	@echo "Creating multi-architecture manifest..."
	docker tag $(PGRX_IMAGE)-amd64 $(PGRX_IMAGE):latest-amd64
	docker tag $(PGRX_IMAGE)-arm64 $(PGRX_IMAGE):latest-arm64
	docker push $(PGRX_IMAGE):latest-amd64
	docker push $(PGRX_IMAGE):latest-arm64
	docker manifest create $(PGRX_IMAGE):latest \
		$(PGRX_IMAGE):latest-amd64 \
		$(PGRX_IMAGE):latest-arm64
	docker manifest push $(PGRX_IMAGE):latest
	docker tag $(PGRX_IMAGE):latest $(PGRX_IMAGE)
	@echo "Multi-architecture pgrx image created: $(PGRX_IMAGE)"

docker_push: #: push the docker image to the registry
	docker push $(DOCKER_IMAGE)

pgrx_push: pgrx_image
	@echo "Pushing multi-architecture pgrx image..."
	docker push $(PGRX_IMAGE)

# Push individual architecture images
pgrx_push_amd64:
	docker push $(PGRX_IMAGE)-amd64

pgrx_push_arm64:
	docker push $(PGRX_IMAGE)-arm64

docker_bash: #: enter the docker image (useful for testing)
	docker exec -it docker-PostgreSQL-1 bash

pgrx_bash:
	docker run --rm --interactive --tty --volume  `pwd`:/pgrx $(PGRX_IMAGE)

# Clean up intermediate architecture-specific images
pgrx_clean:
	@echo "Cleaning up intermediate pgrx images..."
	docker rmi $(PGRX_IMAGE)-amd64 2>/dev/null || true
	docker rmi $(PGRX_IMAGE)-arm64 2>/dev/null || true
	docker rmi $(PGRX_IMAGE):latest-amd64 2>/dev/null || true
	docker rmi $(PGRX_IMAGE):latest-arm64 2>/dev/null || true

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
