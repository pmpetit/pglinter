# pglinter Documentation Makefile

# Variables
PANDOC_CONTAINER_ID?=pglinter-pandoc-1
PANDOC=docker exec $(PANDOC_CONTAINER_ID) pandoc

PG_CONTAINER_ID?=pglinter-pg-1

TUTORIALS?=$(sort $(wildcard tutorials/*.md))
EXAMPLES?=$(sort $(wildcard examples/*.md))

# Docker compose commands
up:
	docker compose --project-directory docs up --detach

down:
	docker compose --project-directory docs down

clean:
	docker compose --project-directory docs rm

psql:
	docker exec -it $(PG_CONTAINER_ID) psql

# Documentation generation
.PHONY: tutorials examples html pdf mkdocs-serve mkdocs-build mkdocs-install
tutorials: $(TUTORIALS)
examples: $(EXAMPLES)

tutorials/%.md: tutorials/%.md
	@echo "Processing tutorial: $<"
	@$(PANDOC) $< \
		--to markdown-grid_tables-simple_tables-multiline_tables \
		--filter=pandoc-run-postgres \
		--output=$@
	@grep -vqz '{class="warning"}' $@ || echo '⚠️  Warning(s) in $@'

examples/%.md: examples/%.md
	@echo "Processing example: $<"
	@$(PANDOC) $< \
		--to markdown-grid_tables-simple_tables-multiline_tables \
		--output=$@

# MkDocs commands
mkdocs-install:
	@echo "Installing MkDocs dependencies..."
	pip3 install -r requirements.txt

mkdocs-serve:
	@echo "Starting MkDocs development server..."
	@cd .. && mkdocs serve

mkdocs-build:
	@echo "Building MkDocs documentation..."
	@cd .. && mkdocs build

mkdocs-clean:
	@echo "Cleaning MkDocs build directory..."
	@cd .. && rm -rf site/

# Generate HTML documentation
html:
	@echo "Generating HTML documentation..."
	@mkdir -p build/html
	@for file in *.md */*.md; do \
		if [ -f "$$file" ]; then \
			output="build/html/$$(echo $$file | sed 's/\.md$$/\.html/')"; \
			mkdir -p "$$(dirname $$output)"; \
			pandoc "$$file" -o "$$output" \
				--standalone \
				--css=../assets/style.css \
				--template=assets/template.html \
				--toc \
				--toc-depth=3; \
			echo "Generated $$output"; \
		fi \
	done

# Generate PDF documentation
pdf:
	@echo "Generating PDF documentation..."
	@mkdir -p build/pdf
	@pandoc index.md \
		INSTALL.md \
		configure.md \
		SECURITY.md \
		api/README.md \
		tutorials/README.md \
		how-to/README.md \
		examples/README.md \
		-o build/pdf/pglinter-documentation.pdf \
		--pdf-engine=xelatex \
		--toc \
		--toc-depth=2 \
		--number-sections

# Check documentation links
check-links:
	@echo "Checking documentation links..."
	@find . -name "*.md" -exec grep -l "http" {} \; | \
		xargs -I {} sh -c 'echo "Checking links in {}"; \
		grep -o "https\?://[^)]*" {} | sort -u | \
		while read url; do \
			if ! curl -s --head "$$url" > /dev/null; then \
				echo "❌ Broken link in {}: $$url"; \
			fi; \
		done'

# Validate markdown syntax
lint:
	@echo "Linting markdown files..."
	@if command -v markdownlint > /dev/null; then \
		markdownlint *.md */*.md; \
	else \
		echo "markdownlint not found. Install with: npm install -g markdownlint-cli"; \
	fi

# Spell check
spell-check:
	@echo "Checking spelling..."
	@if command -v aspell > /dev/null; then \
		find . -name "*.md" -exec aspell --mode=markdown check {} \;; \
	else \
		echo "aspell not found. Install with your package manager"; \
	fi

# Generate table of contents
toc:
	@echo "Generating table of contents..."
	@if command -v doctoc > /dev/null; then \
		doctoc *.md */*.md; \
	else \
		echo "doctoc not found. Install with: npm install -g doctoc"; \
	fi

# Development server
serve:
	@echo "Starting development server..."
	@if command -v python3 > /dev/null; then \
		cd build/html && python3 -m http.server 8000; \
	else \
		echo "Python 3 not found"; \
	fi

# Test documentation examples
test-examples:
	@echo "Testing documentation examples..."
	@if [ -f "test_examples.sh" ]; then \
		./test_examples.sh; \
	else \
		echo "test_examples.sh not found"; \
	fi

# Clean build artifacts
clean-build:
	@echo "Cleaning build artifacts..."
	@rm -rf build/

# Install dependencies
install-deps:
	@echo "Installing documentation dependencies..."
	@if command -v npm > /dev/null; then \
		npm install -g markdownlint-cli doctoc; \
	else \
		echo "npm not found. Please install Node.js"; \
	fi

# Setup development environment
setup:
	@echo "Setting up documentation development environment..."
	@make install-deps
	@mkdir -p build/html build/pdf
	@mkdir -p assets
	@echo "Setup complete!"

# Deploy documentation (customize for your deployment)
deploy:
	@echo "Deploying documentation..."
	@make html
	@echo "Documentation built. Deploy build/html/ to your web server."

# Help
help:
	@echo "pglinter Documentation Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  up              - Start documentation containers"
	@echo "  down            - Stop documentation containers"
	@echo "  clean           - Remove documentation containers"
	@echo "  psql            - Connect to PostgreSQL container"
	@echo "  tutorials       - Process tutorial files"
	@echo "  examples        - Process example files"
	@echo "  html            - Generate HTML documentation"
	@echo "  pdf             - Generate PDF documentation"
	@echo "  check-links     - Check for broken links"
	@echo "  lint            - Lint markdown files"
	@echo "  spell-check     - Check spelling"
	@echo "  toc             - Generate table of contents"
	@echo "  serve           - Start development server"
	@echo "  test-examples   - Test documentation examples"
	@echo "  clean-build     - Clean build artifacts"
	@echo "  install-deps    - Install documentation dependencies"
	@echo "  setup           - Setup development environment"
	@echo "  deploy          - Deploy documentation"
	@echo "  help            - Show this help message"

.DEFAULT_GOAL := help
