#!/bin/bash
# Script to test a reusable workflow locally using act

set -e

WORKFLOW_NAME=${1:-}
EVENT_TYPE=${2:-workflow_call}

if [ -z "$WORKFLOW_NAME" ]; then
    echo "Usage: $0 <workflow-name> [event-type]"
    echo ""
    echo "Parameters:"
    echo "  workflow-name  Name of the workflow to test (required)"
    echo "  event-type     GitHub event type to simulate (default: workflow_call)"
    echo "                 Common events: push, pull_request, workflow_dispatch"
    echo ""
    echo "Available reusable workflows:"
    for w in .github/workflows/*.yml; do
        if grep -q "workflow_call:" "$w" 2>/dev/null; then
            echo "  - $(basename "$w" .yml)"
        fi
    done
    exit 1
fi

WORKFLOW_FILE=".github/workflows/${WORKFLOW_NAME}.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Workflow not found: $WORKFLOW_FILE"
    exit 1
fi

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo "⚠️  act is not installed. Install it with:"
    echo "  brew install act (macOS)"
    echo "  or see: https://github.com/nektos/act"
    exit 1
fi

# Create a temporary test workflow
TEST_WORKFLOW=$(mktemp -t test-workflow.yml)

# Determine the event to use
if [ "$EVENT_TYPE" = "workflow_call" ]; then
    # For workflow_call, we need to wrap it in another event
    EVENT_CONFIG="push"
else
    EVENT_CONFIG="$EVENT_TYPE"
fi

echo "🧪 Testing workflow: $WORKFLOW_NAME"
echo "📅 Event type: $EVENT_CONFIG (from $EVENT_TYPE)"
echo ""

cat > "$TEST_WORKFLOW" << EOF
name: Test $WORKFLOW_NAME
on: $EVENT_CONFIG

jobs:
  test:
    uses: ./.github/workflows/${WORKFLOW_NAME}.yml
    with:
      # Add test inputs here based on the workflow requirements
      # You'll need to customize this for each workflow
      repository_name: "test-repo"
    secrets: inherit
EOF

echo "Test workflow created:"
cat "$TEST_WORKFLOW"
echo ""

# Run the test
echo "Running test with act..."
act -W "$TEST_WORKFLOW" -j test --verbose

# Cleanup
rm -f "$TEST_WORKFLOW"

echo ""
echo "✅ Test completed!"