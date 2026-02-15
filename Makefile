
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
# REGRESS_TESTS+= s004_owner_schema_is_internal_role
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
	PG_CONFIG?=`$(PGRX) info pg-config $(PGVER) 2> /dev/null || echo pg_config`
	PG_SHAREDIR?=$(shell $(PG_CONFIG) --sharedir)
	PG_LIBDIR?=$(shell $(PG_CONFIG) --libdir)
	PG_PKGLIBDIR?=$(shell $(PG_CONFIG) --pkglibdir)
	PG_BINDIR?=$(shell $(PG_CONFIG) --bindir)
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
	PG_CONFIG?=`$(PGRX) info pg-config $(PGVER) 2> /dev/null || echo pg_config`
	PG_SHAREDIR?=$(shell $(PG_CONFIG) --sharedir)
	PG_LIBDIR?=$(shell $(PG_CONFIG) --libdir)
	PG_PKGLIBDIR?=$(shell $(PG_CONFIG) --pkglibdir)
	PG_BINDIR?=$(shell $(PG_CONFIG) --bindir)
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

# OCI image configuration - CloudNative-PG extension images
DOCKER_REGISTRY?=ghcr.io/pmpetit
DOCKER_IMAGE_NAME?=pglinter
DOCKER_BASE_TAG?=$(PGLINTER_MINOR_VERSION)
PG_VERSION?=18
DOCKER_TAG?=$(DOCKER_BASE_TAG)-$(PG_VERSION)
DOCKER_IMAGE?=$(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

docker_image_test:
	docker build --tag latest .

docker_setup:
	@echo "Setting up Docker buildx for multi-platform builds..."
	@docker buildx create --name pglinter-docker-builder --use --bootstrap 2>/dev/null || \
	docker buildx use pglinter-docker-builder 2>/dev/null || \
	(echo "Creating new buildx instance..." && docker buildx create --name pglinter-docker-builder --use --bootstrap)

docker_image: docker_setup
	@echo "Building docker image : $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(DOCKER_TAG)"
	@echo "  PostgreSQL Version: $(PG_VERSION)"
	@echo "  Extension Version: $(PGLINTER_MINOR_VERSION)"
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg PG_MAJOR_VERSION=$(PG_VERSION) \
		--build-arg PGLINTER_VERSION=$(PGLINTER_MINOR_VERSION) \
		--tag $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(DOCKER_TAG) \
		--file docker/Dockerfile \
		--push \
		.
	@echo "✅ image built successfully"

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
	@sudo docker buildx create --name pglinter-oci-builder --use --bootstrap 2>/dev/null || \
	sudo docker buildx use pglinter-oci-builder 2>/dev/null || \
	(echo "Creating new buildx instance..." && sudo docker buildx create --name pglinter-oci-builder --use --bootstrap)


# Build OCI extension image for AMD64 platform only (can be loaded locally)
oci_image: oci_setup
	@echo "Building OCI image for AMD64: $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)"
	@echo "  PostgreSQL Version: $(PG_VERSION_OCI)"
	@echo "  Extension Version: $(PGLINTER_MINOR_VERSION)"
	@echo "  Distro: $(DISTRO)"
	sudo docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg PG_VERSION=$(PG_VERSION_OCI) \
		--build-arg DISTRO=$(DISTRO) \
		--build-arg PGLINTER_VERSION=$(PGLINTER_MINOR_VERSION) \
		--build-arg EXT_VERSION=$(PGLINTER_MINOR_VERSION) \
		--tag $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG) \
		--file docker/oci/Dockerfile.pg-deb \
		--push \
		.
	@echo "✅ OCI image built successfully"

# Build and push OCI extension image to GitHub Container Registry
oci_push:
	@echo "Pushing OCI images to registry..."
	docker push $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)
	@echo "✅ OCI images pushed successfully"
	@echo "  Main tag: $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)"

oci_test:
	@echo "Testing OCI image in kind Kubernetes cluster..."
	kind create cluster --name pglinter-test --config docker/oci/kind.yaml
	sudo docker pull $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG)
	sudo docker tag $(OCI_REGISTRY)/$(OCI_IMAGE_NAME):$(OCI_TAG) pglinter:local
	kind load docker-image pglinter:local --name pglinter-test
	kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.1.yaml
	# Wait for CloudNativePG operator pod to be ready
	echo "Waiting for CloudNativePG operator pod to be ready..."
	for i in $$(seq 1 120); do \
		webhook_ip=$$(kubectl get svc -n cnpg-system cnpg-webhook-service -o jsonpath='{.spec.clusterIP}'); \
		if [ -n "$$webhook_ip" ] && \
			kubectl run --rm -i --restart=Never --image=appropriate/curl test-curl --namespace=cnpg-system -- \
			curl -k --connect-timeout 2 https://$$webhook_ip:443/mutate-postgresql-cnpg-io-v1-cluster || true; then \
			echo "Webhook endpoint is reachable."; \
			sleep 10; \
			break; \
		fi; \
		echo "Waiting for webhook endpoint at $$webhook_ip:443 ..."; \
		sleep 5; \
	done
	sleep 10;
	kubectl apply -f docker/oci/cluster.yaml
	kubectl apply -f docker/oci/database.yaml
	# Wait for cluster-pglinter pod to be ready
	echo "Waiting for cluster-pglinter pod to be ready..."
	for i in $$(seq 1 60); do \
		pod_name=$$(kubectl get pods -l cnpg.io/cluster=cluster-pglinter -o jsonpath='{.items[0].metadata.name}'); \
		pod_status=$$(kubectl get pods -l cnpg.io/cluster=cluster-pglinter -o jsonpath='{.items[0].status.phase}'); \
		if [ "$$pod_status" = "Running" ]; then \
			if kubectl exec $$pod_name -- psql -U postgres -d postgres -c "select 1;"; then \
				echo "PostgreSQL is up and accepting connections."; \
				break; \
			else \
				echo "Pod is running but PostgreSQL not ready yet (waiting)"; \
			fi; \
		else \
			echo "Pod status: $$pod_status (waiting)"; \
		fi; \
		sleep 5; \
	done
	pod_name=$$(kubectl get pods -l cnpg.io/cluster=cluster-pglinter -o jsonpath='{.items[0].metadata.name}') && \
	kubectl exec -it $$pod_name -- psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pglinter; SELECT hello_pglinter();"


# Cleanup kind cluster and resources
oci_test_cleanup:
	kubectl delete -f docker/oci/database.yaml || true
	kubectl delete -f docker/oci/cluster.yaml || true
	kind delete cluster --name pglinter-test || true


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
