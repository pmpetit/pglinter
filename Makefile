##
## dblinter Makefile
##
## This Makefile is based on the PGXS Makefile pattern
##

PGRX?=cargo pgrx
PGVER?=$(shell grep 'default = \[".*\"]' Cargo.toml | sed -e 's/.*\["//' | sed -e 's/"].*//')
PG_MAJOR_VERSION=$(PGVER:pg%=%)
DBLINTER_VERSION?=$(shell grep '^version *= *' Cargo.toml | sed 's/^version *= *//' | tr -d '\"' | tr -d ' ' )

# use `TARGET=debug make run` for more detailed errors
TARGET?=release
TARGET_DIR?=target/$(TARGET)/dblinter-$(PGVER)/
PG_CONFIG?=`$(PGRX) info pg-config $(PGVER) 2> /dev/null || echo pg_config`
PG_SHAREDIR?=$(shell $(PG_CONFIG) --sharedir)
PG_LIBDIR?=$(shell $(PG_CONFIG) --libdir)
PG_PKGLIBDIR?=$(shell $(PG_CONFIG) --pkglibdir)
PG_BINDIR?=$(shell $(PG_CONFIG) --bindir)

# pgrx always creates .so files, even on macOS
LIB_SUFFIX?=so
LIB=pg_linter.$(LIB_SUFFIX)

# The instance
PGDATA_DIR=~/.pgrx/data-$(PG_MAJOR_VERSION)

# Be sure to use the PGRX version (PGVER) of the postgres binaries
PATH:=$(PG_BINDIR):${PATH}

# This is where the package is placed
TARGET_SHAREDIR?=$(TARGET_DIR)$(PG_SHAREDIR)
TARGET_PKGLIBDIR?=$(TARGET_DIR)$(PG_PKGLIBDIR)

PG_REGRESS?=$(PG_PKGLIBDIR)/pgxs/src/test/regress/pg_regress
PG_SOCKET_DIR?=/var/lib/postgresql/.pgrx/
PGHOST?=localhost
PGPORT?=288$(subst pg,,$(PGVER))
PSQL_OPT?=--host $(PGHOST) --port $(PGPORT)
PGDATABASE?=dblinter_test

##
## Test configuration
##

# List of test files (without .sql extension)
REGRESS_TESTS = b001
REGRESS_TESTS+= b001_prompt
REGRESS_TESTS+= rule_management

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
	cp -r $(TARGET_SHAREDIR)/extension/* $(PG_SHAREDIR)/extension/
	install $(TARGET_PKGLIBDIR)/$(LIB) $(PG_PKGLIBDIR)

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
	@echo "Running all dblinter tests..."
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
	@echo "CREATE EXTENSION IF NOT EXISTS dblinter;" >> /tmp/test_$*.sql
	@echo "SELECT pg_linter.perform_base_check();" >> /tmp/test_$*.sql
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
	@echo "CREATE EXTENSION IF NOT EXISTS dblinter;" >> /tmp/test_convenience.sql
	@echo "SELECT pg_linter.check_base();" >> /tmp/test_convenience.sql
	@echo "SELECT pg_linter.check_cluster();" >> /tmp/test_convenience.sql
	@echo "SELECT pg_linter.check_table();" >> /tmp/test_convenience.sql
	@echo "SELECT pg_linter.check_schema();" >> /tmp/test_convenience.sql
	@echo "SELECT pg_linter.check_all();" >> /tmp/test_convenience.sql
	@echo "ROLLBACK;" >> /tmp/test_convenience.sql
	psql $(PSQL_OPT) $(PGDATABASE) -f /tmp/test_convenience.sql
	@rm -f /tmp/test_convenience.sql

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
	@echo "  help             - Show this help message"

.PHONY: all extension install test-all installcheck start stop run psql clean help test-% test-prompt-% test-convenience


##
## L I N T
##

lint:
	cargo clippy --release
