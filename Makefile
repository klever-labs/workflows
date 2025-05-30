.PHONY: act test-ci validate lint shellcheck yaml-lint fix-yaml help

# Default target
help:
	@echo "Available targets:"
	@echo "  make act         - Run full CI workflow with act"
	@echo "  make test-ci     - Test individual CI jobs"
	@echo "  make validate    - Validate all workflows"
	@echo "  make lint        - Run all linting checks"
	@echo "  make shellcheck  - Run ShellCheck only"
	@echo "  make yaml-lint   - Run YAML lint only"
	@echo "  make fix-yaml    - Fix YAML formatting issues"

# Run full CI workflow with act
act:
	@echo "Running full CI workflow..."
	@act push \
		--container-architecture linux/amd64 \
		-P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest \
		-W .github/workflows/ci.yml

# Test individual CI jobs
test-ci:
	@echo "Testing CI jobs individually..."
	@echo "1. Testing ShellCheck..."
	@act push --container-architecture linux/amd64 -j shellcheck || true
	@echo "2. Testing YAML Lint..."
	@act push --container-architecture linux/amd64 -j yaml-lint || true
	@echo "3. Testing Workflow Validation..."
	@act push --container-architecture linux/amd64 -j validate-workflows || true

# Validate workflows only
validate:
	@echo "Validating workflows..."
	@act push --container-architecture linux/amd64 -j validate-workflows

# Run linting checks
lint:
	@echo "Running linting checks..."
	@act push --container-architecture linux/amd64 -j yaml-lint -j shellcheck -j markdown-lint

# Run shellcheck only
shellcheck:
	@echo "Running ShellCheck..."
	@act push --container-architecture linux/amd64 -j shellcheck

# Run yamllint only
yaml-lint:
	@echo "Running YAML lint..."
	@act push --container-architecture linux/amd64 -j yaml-lint

# Fix YAML formatting issues
fix-yaml:
	@echo "Fixing YAML formatting..."
	@find . -name "*.yml" -o -name "*.yaml" | grep -E "(\.github/workflows/|actions/)" | while read file; do \
		sed -i '' -e 's/[[:space:]]*$$//' -e '$$a\' "$$file" 2>/dev/null || sed -i -e 's/[[:space:]]*$$//' -e '$$a\' "$$file"; \
	done
	@echo "YAML files formatted"