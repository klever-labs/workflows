#!/bin/bash
# Script to prepare dockerfiles and configs for release as tar.gz archives

set -e

echo "Preparing release archives..."

# Create dockerfiles archive
if [ -d "dockerfiles" ]; then
    echo "Creating dockerfiles.tar.gz..."
    tar -czf dockerfiles.tar.gz dockerfiles/
    echo "✓ dockerfiles.tar.gz created"
else
    echo "⚠ dockerfiles/ directory not found"
fi

# Create configs archive
if [ -d "configs" ]; then
    echo "Creating configs.tar.gz..."
    tar -czf configs.tar.gz configs/
    echo "✓ configs.tar.gz created"
else
    echo "⚠ configs/ directory not found"
fi

echo ""
echo "Release archives ready:"
ls -lh ./*.tar.gz 2>/dev/null || echo "No archives created"

echo ""
echo "Example release command:"
echo "gh release create v1.0.0 dockerfiles.tar.gz configs.tar.gz"