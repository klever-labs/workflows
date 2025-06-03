#!/bin/bash
# Script to help sync required secrets across repositories using workflows

set -e

echo "🔐 Workflow Secrets Analyzer"
echo ""

# Function to extract required secrets from a workflow
extract_secrets() {
    local workflow=$1
    local workflow_name
    workflow_name=$(basename "$workflow" .yml)
    
    if grep -q "secrets:" "$workflow"; then
        echo "📄 $workflow_name requires:"
        
        # Extract secret names and requirements
        awk '
            /secrets:/ { in_secrets=1; next }
            /jobs:/ { in_secrets=0 }
            /^    [a-zA-Z]/ && in_secrets {
                secret=$1
                gsub(/:/, "", secret)
                print "  - " secret
                current_secret=secret
            }
            /required:/ && in_secrets {
                if ($2 == "true") {
                    print "    ⚠️  Required"
                } else {
                    print "    ℹ️  Optional"
                }
            }
            /description:/ && in_secrets {
                desc=""
                for(i=2; i<=NF; i++) desc=desc" "$i
                gsub(/[\047"]/, "", desc)
                print "    📝" desc
            }
        ' "$workflow" 2>/dev/null || true
        
        echo ""
    fi
}

# Analyze all reusable workflows
echo "Analyzing reusable workflows for required secrets..."
echo ""

REQUIRED_SECRETS=()

for workflow in .github/workflows/*.yml; do
    if [ -f "$workflow" ] && grep -q "workflow_call:" "$workflow"; then
        extract_secrets "$workflow"
        
        # Collect unique secret names
        secrets=$(grep -A20 "secrets:" "$workflow" | grep -E "^      [a-zA-Z]" | awk '{gsub(/:/, "", $1); print $1}' || true)
        for secret in $secrets; do
            found=false
            for existing in "${REQUIRED_SECRETS[@]}"; do
                if [[ "$existing" == "$secret" ]]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                REQUIRED_SECRETS+=("$secret")
            fi
        done
    fi
done

# Generate secret checklist
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Secret Checklist for Consuming Repositories"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To use workflows from this repository, ensure these secrets are configured:"
echo ""

for secret in "${REQUIRED_SECRETS[@]}"; do
    echo "  ☐ $secret"
done

echo ""
echo "💡 Tips:"
echo "  - Use 'gh secret set' to add secrets to a repository"
echo "  - Consider using organization-level secrets for common values"
echo "  - Some secrets may be optional depending on the workflow"
echo ""

# Generate GitHub CLI commands
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Quick Setup Commands"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "# Set secrets for a repository (replace <value> with actual values):"
echo ""

for secret in "${REQUIRED_SECRETS[@]}"; do
    echo "gh secret set $secret --body '<value>' --repo <owner/repo>"
done

echo ""
echo "# Or use environment variables:"
echo ""

for secret in "${REQUIRED_SECRETS[@]}"; do
    echo "gh secret set $secret --body \"\$$secret\" --repo <owner/repo>"
done