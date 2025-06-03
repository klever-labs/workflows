#!/bin/bash
# Script to check for outdated action versions in workflows

set -e

echo "🔍 Checking GitHub Actions versions..."

# Common actions to check
declare -A LATEST_VERSIONS=(
    ["actions/checkout"]="v4"
    ["actions/setup-node"]="v4"
    ["actions/upload-artifact"]="v4"
    ["actions/download-artifact"]="v4"
    ["actions/cache"]="v4"
    ["docker/setup-buildx-action"]="v3"
    ["docker/login-action"]="v3"
    ["docker/build-push-action"]="v6"
    ["softprops/action-gh-release"]="v2"
)

outdated_count=0

echo ""
echo "Checking action versions in workflows..."

for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
    if [ -f "$workflow" ]; then
        echo ""
        echo "📄 $(basename "$workflow"):"
        
        for action in "${!LATEST_VERSIONS[@]}"; do
            latest="${LATEST_VERSIONS[$action]}"
            
            # Find all uses of this action in the workflow
            matches=$(grep -n "uses: $action@" "$workflow" 2>/dev/null || true)
            
            if [ -n "$matches" ]; then
                while IFS= read -r line; do
                    line_num=$(echo "$line" | cut -d: -f1)
                    full_line=$(echo "$line" | cut -d: -f2-)
                    version=$(echo "$full_line" | grep -oE "@v[0-9]+" | sed 's/@//')
                    
                    if [ "$version" != "$latest" ]; then
                        echo "  ⚠️  Line $line_num: $action@$version → should be @$latest"
                        outdated_count=$((outdated_count + 1))
                    else
                        echo "  ✅ Line $line_num: $action@$version (latest)"
                    fi
                done <<< "$matches"
            fi
        done
    fi
done

echo ""
echo "Summary:"
if [ $outdated_count -gt 0 ]; then
    echo "  ⚠️  Found $outdated_count outdated action references"
    echo "  Run 'scripts/update-action-versions.sh' to update them automatically"
else
    echo "  ✅ All actions are using the latest versions!"
fi