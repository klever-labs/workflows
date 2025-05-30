# Release Process

This document describes the automated release process for the workflows repository.

## Overview

The repository uses an automated release workflow that triggers when changes are made to:

- `dockerfiles/` directory
- `configs/` directory

## Automatic Releases

### Trigger Conditions

1. **After CI workflow completes successfully** on main branch:
   - Automatically triggered when CI passes
   - Checks if `dockerfiles/` or `configs/` were changed in the commit
   - Only creates release if relevant directories were modified

2. **Manual trigger** via GitHub Actions UI (workflow_dispatch)
   - Does not wait for CI (assumes you've verified quality)
   - Always creates a release regardless of what changed

### Version Bumping

The workflow automatically determines version bumps based on commit messages:

| Commit Message Pattern | Version Bump | Example |
|------------------------|--------------|---------|
| `feat!:` or `feature!:` | Major (x.0.0) | Breaking changes |
| `feat:` or `feature:` | Minor (0.x.0) | New features |
| `fix:`, `chore:`, etc. | Patch (0.0.x) | Bug fixes, updates |

### Manual Version Control

You can manually trigger a release with a specific version bump:

1. Go to Actions → Create Release
2. Click "Run workflow"
3. Select version bump level: patch, minor, or major

## Release Assets

Each release automatically includes:

- **dockerfiles.tar.gz** - Archive of the `dockerfiles/` directory
- **configs.tar.gz** - Archive of the `configs/` directory

## Release Notes

Release notes are automatically generated and include:

1. **Change Summary** - Lists modified files in dockerfiles/ and configs/
2. **Commit History** - All commits since the last release
3. **Asset Description** - Information about the included archives
4. **Usage Instructions** - How to use the release assets

## Example Release Flow

1. Developer updates `configs/nginx.conf`
2. Commits with message: `feat: add gzip compression to nginx config`
3. Pushes to main branch
4. Release workflow automatically:
   - Detects changes in configs/
   - Determines minor version bump (feat:)
   - Creates dockerfiles.tar.gz and configs.tar.gz
   - Tags the commit (e.g., v1.2.0)
   - Creates GitHub release with assets

## CI Protection

The release workflow includes protection to ensure code quality:

- **Automatic releases** are triggered by `workflow_run` event after CI completes
- Only proceeds if CI concluded with 'success'
- **Manual releases** (workflow_dispatch) bypass CI for emergency releases
- Clean implementation using native GitHub Actions features

## Preventing Duplicate Releases

The workflow checks if the current commit is already tagged:

- If tagged: Skip release creation
- If not tagged: Proceed with release

## Best Practices

1. **Use conventional commits** for clear version bumping:

   ```text
   feat: add new Dockerfile for Ruby
   fix: correct nginx cache headers
   feat!: change default Node.js version to 20
   ```

2. **Test changes locally** before pushing:

   ```bash
   ./scripts/prepare-release.sh
   # Verify the archives contain expected files
   ```

3. **Review generated releases** to ensure:

   - Correct version bump
   - All expected files are included
   - Release notes are accurate

## Troubleshooting

### Release not triggered

- Ensure changes are in `dockerfiles/` or `configs/` directories
- Check that you're pushing to the main branch
- Verify GitHub Actions are enabled for the repository

### Wrong version bump

- Check commit message format
- Use `feat!:` for breaking changes requiring major bump
- Manual trigger allows explicit version control

### Missing files in release

- Run `./scripts/prepare-release.sh` locally to test
- Ensure files are committed before pushing
- Check that tar command has necessary permissions
