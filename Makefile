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
#REGRESS_TESTS+= b004_idx_not_used
REGRESS_TESTS+= b005_uppercase_test
#REGRESS_TESTS+= b006_tables_not_selected
REGRESS_TESTS+= b007_fk_outside_schema
REGRESS_TESTS+= b008_fk_type_mismatch
REGRESS_TESTS+= b009_trigger_sharing
REGRESS_TESTS+= b010_reserved_keywords
REGRESS_TESTS+= b011_several_table_owner_in_schema
REGRESS_TESTS+= b012_composite_pk
REGRESS_TESTS+= s001_schema_with_default_role_not_granted
REGRESS_TESTS+= s002_schema_prefixed_or_suffixed_with_envt
REGRESS_TESTS+= s003_public_schema
REGRESS_TESTS+= s003_unsecured_public_schema
REGRESS_TESTS+= s004_owner_schema_is_internal_role
REGRESS_TESTS+= s005_several_table_owner_in_schema
REGRESS_TESTS+= demo_rule_levels
REGRESS_TESTS+= import_rules_from_file
REGRESS_TESTS+= import_rules_from_yaml
#REGRESS_TESTS+= integration_test
REGRESS_TESTS+= quick_demo_levels
#REGRESS_TESTS+= rule_management
REGRESS_TESTS+= schema_rules

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
			--push \
			$(DOCKER_BUILD_ARG) \
			.

docker_image_arm64: docker/Dockerfile #: build the docker image
	#: docker build --tag $(DOCKER_IMAGE):$(DOCKER_TAG) . --file $^  $(DOCKER_BUILD_ARG)
	@echo "Setting up buildx for multi-platform builds..."
	docker buildx create --name pglinter-builder --use --bootstrap 2>/dev/null || \
	docker buildx use pglinter-builder 2>/dev/null || \
	(echo "Creating new buildx instance..." && docker buildx create --name pglinter-builder --use --bootstrap)
	@echo "Building multi-platform image..."
	docker buildx build \
			--platform linux/arm64 \
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
## O C I   I M A G E S
##

# OCI image configuration - CloudNative-PG extension images
OCI_REGISTRY?=ghcr.io/pmpetit
OCI_IMAGE_NAME?=pglinter
OCI_BASE_TAG?=$(PGLINTER_MINOR_VERSION)
DISTRO?=trixie
PG_VERSION_OCI?=18
OCI_TAG?=$(OCI_BASE_TAG)-$(PG_VERSION_OCI)-$(DISTRO)

# Ensure buildx is available for OCI builds
oci_setup:
	@echo "Setting up Docker buildx for multi-platform builds..."
	@docker buildx create --name pglinter-oci-builder --use --bootstrap 2>/dev/null || \
	docker buildx use pglinter-oci-builder 2>/dev/null || \
	(echo "Creating new buildx instance..." && docker buildx create --name pglinter-oci-builder --use --bootstrap)

# Build OCI extension image for PostgreSQL 18
oci_image: oci_setup deb
	@echo "Building OCI image: $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)"
	@echo "  PostgreSQL Version: $(PG_VERSION_OCI)"
	@echo "  Extension Version: $(PGLINTER_MINOR_VERSION)"
	@echo "  Distro: $(DISTRO)"
	@echo "Checking if .deb package exists locally..."
	@if [ -f $(TARGET_DIR)/*.deb ]; then \
		echo "✅ Local .deb package found, will use for build"; \
		DEB_PATH=$$(find $(TARGET_DIR) -name "*.deb" | head -1); \
		echo "Using package: $$DEB_PATH"; \
	else \
		echo "❌ No local .deb package found in $(TARGET_DIR)"; \
		echo "Will attempt to download from GitHub releases"; \
	fi
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg PG_VERSION=$(PG_VERSION_OCI) \
		--build-arg DISTRO=$(DISTRO) \
		--build-arg PGLINTER_VERSION=$(PGLINTER_MINOR_VERSION) \
		--build-arg EXT_VERSION=$(PGLINTER_MINOR_VERSION) \
		--tag $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG) \
		--file docker/oci/Dockerfile.pg-deb \
		--load \
		.
	@echo "✅ OCI image built successfully"

# Build OCI extension image for AMD64 platform only (can be loaded locally)
oci_image_amd64: oci_setup deb
	@echo "Building OCI image for AMD64 only: $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)"
	@echo "  PostgreSQL Version: $(PG_VERSION_OCI)"
	@echo "  Extension Version: $(PGLINTER_MINOR_VERSION)"
	@echo "  Distro: $(DISTRO)"
	@echo "Checking if .deb package exists locally..."
	@if [ -f $(TARGET_DIR)/*.deb ]; then \
		echo "✅ Local .deb package found, will use for build"; \
		DEB_PATH=$$(find $(TARGET_DIR) -name "*.deb" | head -1); \
		echo "Using package: $$DEB_PATH"; \
	else \
		echo "❌ No local .deb package found in $(TARGET_DIR)"; \
		echo "Will attempt to download from GitHub releases"; \
	fi
	docker buildx build \
		--platform linux/amd64 \
		--build-arg PG_VERSION=$(PG_VERSION_OCI) \
		--build-arg DISTRO=$(DISTRO) \
		--build-arg PGLINTER_VERSION=$(PGLINTER_MINOR_VERSION) \
		--build-arg EXT_VERSION=$(PGLINTER_MINOR_VERSION) \
		--tag $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG) \
		--file docker/oci/Dockerfile.pg-deb \
		--load \
		.
	@echo "✅ OCI image built successfully for AMD64"

# Build and push OCI extension image to GitHub Container Registry
oci_push_amd64: oci_image_amd64
	@echo "Pushing OCI images to registry..."
	docker push $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)
	@echo "✅ OCI images pushed successfully"
	@echo "  Main tag: $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)"

# Build OCI image for local testing (AMD64 only)
oci_build_local: oci_setup
	@echo "Building local OCI image for testing..."
	@echo "Ensuring .deb package exists for PostgreSQL $(PG_VERSION_OCI)..."
	@if [ ! -f target/release/pglinter-pg$(PG_VERSION_OCI)/postgresql_pglinter_$(PG_VERSION_OCI)_$(PGLINTER_MINOR_VERSION)_amd64.deb ]; then \
		echo "❌ No .deb package found. Building package first..."; \
		$(MAKE) deb PGVER=pg$(PG_VERSION_OCI) PG_MAJOR_VERSION=$(PG_VERSION_OCI); \
	fi
	@echo "Preparing .deb package for Docker build..."
	@mkdir -p docker/oci/packages
	@cp target/release/pglinter-pg$(PG_VERSION_OCI)/postgresql_pglinter_$(PG_VERSION_OCI)_$(PGLINTER_MINOR_VERSION)_amd64.deb docker/oci/packages/pglinter.deb
	@echo "Using local .deb package for build..."
	cd docker/oci && docker buildx build \
		--platform linux/amd64 \
		--build-arg PG_VERSION=$(PG_VERSION_OCI) \
		--build-arg DISTRO=$(DISTRO) \
		--build-arg PGLINTER_VERSION=$(PGLINTER_MINOR_VERSION) \
		--build-arg EXT_VERSION=$(PGLINTER_MINOR_VERSION) \
		--tag $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local \
		--file Dockerfile.local \
		--load \
		.
	@rm -rf docker/oci/packages
	@echo "✅ Local OCI image built: $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local"

# Test the OCI image locally
oci_test: oci_build_local
	@echo "Testing OCI image locally..."
	@echo "Verifying image was built successfully..."
	docker image inspect $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local --format '{{.Size}}' | \
		awk '{if($$1 > 0) print "✅ Image size: " $$1 " bytes"; else print "❌ Image appears empty"}'
	@echo "Checking image labels..."
	docker image inspect $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local --format '{{range $$k, $$v := .Config.Labels}}{{$$k}}: {{$$v}}{{"\n"}}{{end}}' | \
		grep -E "(extension\.|org\.opencontainers\.image\.)" || echo "❌ Missing expected labels"
	@echo "Extracting and examining image contents..."
	@mkdir -p /tmp/pglinter-test
	@if docker save $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local -o /tmp/pglinter-test/image.tar 2>/dev/null; then \
		cd /tmp/pglinter-test && tar -tf image.tar | head -10 && \
		echo "✅ Image successfully saved and contains layers"; \
	else \
		echo "❌ Failed to save image"; \
	fi
	@rm -rf /tmp/pglinter-test
	@echo "✅ OCI image validation completed"

# Detailed test using crane or direct layer inspection
oci_test_detailed: oci_build_local
	@echo "Running detailed OCI image test..."
	@echo "Using dive to inspect image layers (if available)..."
	@if command -v dive >/dev/null 2>&1; then \
		dive $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local --ci; \
	else \
		echo "Dive not available, using basic inspection..."; \
		echo "Checking image history:"; \
		docker history $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local; \
		echo ""; \
		echo "Image configuration:"; \
		docker image inspect $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local --format '{{json .RootFS}}' | jq '.' 2>/dev/null || docker image inspect $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):local --format '{{.RootFS}}'; \
	fi
	@echo "✅ Detailed OCI image test completed"


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
