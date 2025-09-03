##
## pglinter Makefile
##
## This Makefile is based on the PGXS Makefile pattern
##

PGRX?=cargo pgrx
PGVER?=$(shell grep 'default = \[".*\"]' Cargo.toml | sed -e 's/.*\["//' | sed -e 's/"].*//')
PG_MAJOR_VERSION=$(PGVER:pg%=%)
pglinter_VERSION?=$(shell grep '^version *= *' Cargo.toml | sed 's/^version *= *//' | tr -d '\"' | tr -d ' ' )

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
PGDATABASE?=pglinter_test

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
	# Try system-style paths first (for CI), then pgrx-managed paths (for local dev)
	if [ -d "$(TARGET_DIR)usr/share/postgresql/$(PG_MAJOR_VERSION)/extension" ]; then \
		cp -r $(TARGET_DIR)usr/share/postgresql/$(PG_MAJOR_VERSION)/extension/* $(PG_SHAREDIR)/extension/; \
		install $(TARGET_DIR)usr/lib/postgresql/$(PG_MAJOR_VERSION)/lib/$(LIB) $(PG_PKGLIBDIR); \
	else \
		cp -r $(TARGET_DIR)$(PG_SHAREDIR)/extension/* $(PG_SHAREDIR)/extension/; \
		install $(TARGET_DIR)$(PG_PKGLIBDIR)/$(LIB) $(PG_PKGLIBDIR); \
	fi

##
## TESTING
##

# Test a single file (e.g., make test-b001)
test-%: stop start
	@echo "Running test: $*"
	dropdb $(PSQL_OPT) --if-exists $(PGDATABASE) || echo 'Database did not exist'
	createdb $(PSQL_OPT) $(PGDATABASE)
	psql $(PSQL_OPT) $(PGDATABASE) -f tests/sql/$*.sql

# Run all tests
test-all: stop start
	@echo "Running all pglinter tests..."
	dropdb $(PSQL_OPT) --if-exists $(PGDATABASE) || echo 'Database did not exist'
	createdb $(PSQL_OPT) $(PGDATABASE)
	@for test in $(REGRESS_TESTS); do \
		echo "Running test: $$test"; \
		psql $(PSQL_OPT) $(PGDATABASE) -f tests/sql/$$test.sql || exit 1; \
	done
	@echo "All tests completed successfully!"

# Test with output to prompt (no file output)
test-prompt-%: stop start
	@echo "Running test with prompt output: $*"
	dropdb $(PSQL_OPT) --if-exists $(PGDATABASE) || echo 'Database did not exist'
	createdb $(PSQL_OPT) $(PGDATABASE)
	@echo "BEGIN;" > /tmp/test_$*.sql
	@echo "CREATE TABLE IF NOT EXISTS my_table_without_pk (id INT, name TEXT, code TEXT, enable BOOL DEFAULT TRUE, query TEXT, warning_level INT, error_level INT, scope TEXT);" >> /tmp/test_$*.sql
	@echo "CREATE EXTENSION IF NOT EXISTS pglinter;" >> /tmp/test_$*.sql
	@echo "SELECT pglinter.perform_base_check();" >> /tmp/test_$*.sql
	@echo "ROLLBACK;" >> /tmp/test_$*.sql
	psql $(PSQL_OPT) $(PGDATABASE) -f /tmp/test_$*.sql
	@rm -f /tmp/test_$*.sql

# Test convenience functions
test-convenience: stop start
	@echo "Testing convenience functions..."
	dropdb $(PSQL_OPT) --if-exists $(PGDATABASE) || echo 'Database did not exist'
	createdb $(PSQL_OPT) $(PGDATABASE)
	@echo "BEGIN;" > /tmp/test_convenience.sql
	@echo "CREATE TABLE IF NOT EXISTS my_table_without_pk (id INT, name TEXT);" >> /tmp/test_convenience.sql
	@echo "CREATE EXTENSION IF NOT EXISTS pglinter;" >> /tmp/test_convenience.sql
	@echo "SELECT pglinter.check_base();" >> /tmp/test_convenience.sql
	@echo "SELECT pglinter.check_cluster();" >> /tmp/test_convenience.sql
	@echo "SELECT pglinter.check_table();" >> /tmp/test_convenience.sql
	@echo "SELECT pglinter.check_schema();" >> /tmp/test_convenience.sql
	@echo "SELECT pglinter.check_all();" >> /tmp/test_convenience.sql
	@echo "ROLLBACK;" >> /tmp/test_convenience.sql
	psql $(PSQL_OPT) $(PGDATABASE) -f /tmp/test_convenience.sql
	@rm -f /tmp/test_convenience.sql

# PGXS-style installcheck using pg_regress
installcheck: extension install stop start
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
## CLEAN
##

clean:
ifdef EXTRA_CLEAN
	rm -rf $(EXTRA_CLEAN)
endif

##
## Help
##

help:
	@echo "Available targets:"
	@echo "  all              - Build the extension"
	@echo "  extension        - Build the extension package"
	@echo "  install          - Install the extension to PostgreSQL"
	@echo "  test-b001        - Run the b001 test specifically"
	@echo "  test-all         - Run all tests"
	@echo "  test-prompt-b001 - Run b001 test with prompt output (no file)"
	@echo "  test-convenience - Test convenience functions (check_base, etc.)"
	@echo "  installcheck     - Run tests using pg_regress (all tests)"
	@echo "  installcheck REGRESS=testname - Run specific test with pg_regress"
	@echo "                   Example: make installcheck REGRESS=b001"
	@echo "                   Example: make installcheck REGRESS=\"b001 b001_prompt\""
	@echo "  start            - Start PostgreSQL test instance"
	@echo "  stop             - Stop PostgreSQL test instance"
	@echo "  psql             - Connect to test database"
	@echo "  clean            - Clean build artifacts"
	@echo ""
	@echo "🔧 Development targets:"
	@echo "  lint             - Run Rust linting with clippy"
	@echo "  fmt              - Format Rust code with cargo fmt"
	@echo "  fmt-check        - Check if Rust code is properly formatted"
	@echo "  lint-docs        - Lint markdown documentation files"
	@echo "  lint-docs-fix    - Lint and automatically fix markdown files"
	@echo "  spell-check      - Check spelling in documentation"
	@echo "  precommit        - Run all pre-commit checks (fmt, lint, docs, tests)"
	@echo "  precommit-fast   - Run fast pre-commit checks (skip tests)"
	@echo "  install-precommit-hook - Install git pre-commit hook"
	@echo "  help             - Show this help message"

.PHONY: all extension install test-all installcheck installcheck-ci installcheck-ci-only start stop run psql clean help test-% test-prompt-% test-convenience lint fmt fmt-check lint-docs lint-docs-fix spell-check audit precommit precommit-fast install-precommit-hook docker-build-pg13 docker-build-pg14 docker-build-pg15 docker-build-pg16 docker-build-pg17 docker-build-all docker-push docker-run-pg13 docker-run-pg14 docker-run-pg15 docker-run-pg16 docker-run-pg17 docker-test docker-clean docker-compose-up docker-compose-down docker-compose-logs


##
## L I N T  &  P R E C O M M I T
##

lint:
	cargo clippy --no-default-features --features pg13 --release

# Format Rust code
fmt:
	cargo fmt

# Check if code is formatted
fmt-check:
	cargo fmt --check

# Lint markdown files
lint-docs:
	@if command -v rumdl > /dev/null; then \
		echo "Linting markdown files..."; \
		rumdl check --config .rumdl.toml docs/**/*.md *.md || true; \
		echo ""; \
		echo "💡 Tip: Run 'make lint-docs-fix' to automatically fix many issues"; \
	else \
		echo "rumdl not found, skipping markdown lint"; \
	fi

# Lint and automatically fix markdown files
lint-docs-fix:
	@if command -v rumdl > /dev/null; then \
		echo "Linting and fixing markdown files..."; \
		rumdl check --config .rumdl.toml --fix docs/**/*.md *.md; \
		echo "✅ Auto-fixable markdown issues have been resolved!"; \
	else \
		echo "rumdl not found, skipping markdown lint and fix"; \
	fi

# Spell check documentation
spell-check:
	@if command -v aspell > /dev/null; then \
		echo "Checking spelling in documentation..."; \
		find docs/ -name "*.md" -exec aspell --mode=markdown --personal=./.aspell.en.pws list < {} \; | sort -u | head -20; \
	else \
		echo "aspell not found, skipping spell check"; \
	fi

# Install git pre-commit hook
install-precommit-hook:
	@echo "Installing pre-commit hook..."
	@cp pre-commit-hook.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed successfully!"
	@echo "   Now 'git commit' will automatically run pre-commit checks."

# Pre-commit hook that runs all checks
precommit: fmt-check lint lint-docs test
	@echo ""
	@echo "🎉 Pre-commit checks completed successfully!"
	@echo ""
	@echo "Summary of checks performed:"
	@echo "  ✅ Rust code formatting (cargo fmt --check)"
	@echo "  ✅ Rust code linting (cargo clippy)"
	@echo "  ✅ Markdown documentation linting"
	@echo "  ✅ Unit tests (cargo pgrx test)"
	@echo ""
	@echo "Ready to commit! 🚀"

# Fast pre-commit that skips tests
precommit-fast: fmt-check lint lint-docs
	@echo ""
	@echo "⚡ Fast pre-commit checks completed!"
	@echo ""
	@echo "Summary of checks performed:"
	@echo "  ✅ Rust code formatting (cargo fmt --check)"
	@echo "  ✅ Rust code linting (cargo clippy)"
	@echo "  ✅ Markdown documentation linting"
	@echo ""
	@echo "Note: Skipped tests for speed. Run 'make test' before pushing."
