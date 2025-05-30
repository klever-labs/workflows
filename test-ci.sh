#!/bin/bash

# Test CI workflow locally

echo "Testing CI workflow jobs..."

# Test shellcheck
echo "1. Testing ShellCheck..."
if act push --container-architecture linux/amd64 -j shellcheck > /dev/null 2>&1; then
    echo "✓ ShellCheck passed"
else
    echo "✗ ShellCheck failed"
fi

# Test yaml-lint
echo "2. Testing YAML Lint..."
if act push --container-architecture linux/amd64 -j yaml-lint 2>&1 | grep -q "Job succeeded"; then
    echo "✓ YAML Lint passed"
else
    echo "✗ YAML Lint failed"
fi

# Test validate-workflows
echo "3. Testing Workflow Validation..."
if act push --container-architecture linux/amd64 -j validate-workflows > /dev/null 2>&1; then
    echo "✓ Workflow Validation passed"
else
    echo "✗ Workflow Validation failed"
fi

echo "CI tests complete!"