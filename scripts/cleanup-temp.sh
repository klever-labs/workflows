#!/usr/bin/env bash
#
# cleanup-temp.sh - Clean up temporary files and artifacts
#
# Usage: ./cleanup-temp.sh [directory]
#
# This script removes temporary files and build artifacts from workflows
# Default directory is current working directory if not specified

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Default to current directory if no argument provided
TARGET_DIR="${1:-.}"

# Validate directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    print_message "$RED" "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

print_message "$YELLOW" "Cleaning temporary files in: $TARGET_DIR"

# Patterns to clean
PATTERNS=(
    "*.tmp"
    "*.temp"
    "*.bak"
    "*.swp"
    ".DS_Store"
    "Thumbs.db"
    "*.log"
    "npm-debug.log*"
    "yarn-debug.log*"
    "yarn-error.log*"
)

# Counter for removed files
removed_count=0

# Remove files matching patterns
for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
        if rm -f "$file" 2>/dev/null; then
            print_message "$GREEN" "Removed: $file"
            ((removed_count++))
        fi
    done < <(find "$TARGET_DIR" -name "$pattern" -type f -print0 2>/dev/null)
done

# Clean empty directories (optional)
if [[ "${CLEAN_EMPTY_DIRS:-false}" == "true" ]]; then
    while IFS= read -r -d '' dir; do
        if rmdir "$dir" 2>/dev/null; then
            print_message "$GREEN" "Removed empty directory: $dir"
            ((removed_count++))
        fi
    done < <(find "$TARGET_DIR" -type d -empty -print0 2>/dev/null)
fi

print_message "$GREEN" "Cleanup complete! Removed $removed_count items."