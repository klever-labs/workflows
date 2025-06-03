#!/bin/bash
# Script to validate all GitHub Actions workflows in the repository

set -e

echo "🔍 Validating GitHub Actions workflows..."

# Check if actionlint is installed
if ! command -v actionlint &> /dev/null; then
    echo "⚠️  actionlint is not installed. Install it with:"
    echo "  brew install actionlint (macOS)"
    echo "  or download from: https://github.com/rhysd/actionlint"
    exit 1
fi

# Find all workflow files
workflow_count=0
error_count=0

echo ""
echo "Checking workflows in .github/workflows/..."

for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
    if [ -f "$workflow" ]; then
        workflow_count=$((workflow_count + 1))
        echo -n "  • $(basename "$workflow")... "
        
        if actionlint "$workflow" > /dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
            echo "    Errors found:"
            actionlint "$workflow" 2>&1 | sed 's/^/    /'
            error_count=$((error_count + 1))
        fi
    fi
done

echo ""
echo "Summary:"
echo "  Total workflows: $workflow_count"
echo "  Passed: $((workflow_count - error_count))"
echo "  Failed: $error_count"

if [ $error_count -gt 0 ]; then
    echo ""
    echo "❌ Validation failed! Please fix the errors above."
    exit 1
else
    echo ""
    echo "✅ All workflows are valid!"
fi