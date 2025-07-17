#!/bin/bash
# this_file: /root/repo/scripts/release.sh

# Release script for Dragoboo
# Handles tagging, building, and creating releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Configuration
VERSION=""
RELEASE_TYPE="patch"
SKIP_TESTS=false
SKIP_BUILD=false
DRY_RUN=false
FORCE=false
PRERELEASE=false

show_help() {
    echo "Usage: $0 [options] [version]"
    echo ""
    echo "Arguments:"
    echo "  version       Specific version to release (e.g., 1.2.3)"
    echo ""
    echo "Options:"
    echo "  --major       Create major release (X.0.0)"
    echo "  --minor       Create minor release (X.Y.0)"
    echo "  --patch       Create patch release (X.Y.Z) [default]"
    echo "  --prerelease  Create prerelease (X.Y.Z-pre.N)"
    echo "  --skip-tests  Skip running tests"
    echo "  --skip-build  Skip building artifacts"
    echo "  --dry-run     Show what would be done without doing it"
    echo "  --force       Force release even if working directory is dirty"
    echo "  --help        Show this help message"
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --major)
        RELEASE_TYPE="major"
        shift
        ;;
    --minor)
        RELEASE_TYPE="minor"
        shift
        ;;
    --patch)
        RELEASE_TYPE="patch"
        shift
        ;;
    --prerelease)
        PRERELEASE=true
        shift
        ;;
    --skip-tests)
        SKIP_TESTS=true
        shift
        ;;
    --skip-build)
        SKIP_BUILD=true
        shift
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --force)
        FORCE=true
        shift
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    --*)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    *)
        if [ -z "$VERSION" ]; then
            VERSION="$1"
        else
            print_error "Too many arguments"
            show_help
            exit 1
        fi
        shift
        ;;
    esac
done

print_info "Starting release process..."

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check if working directory is clean
if [ "$FORCE" = false ] && ! git diff --quiet; then
    print_error "Working directory is not clean. Use --force to override."
    git status --porcelain
    exit 1
fi

# Check if we're on the main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    print_warning "Not on main/master branch (currently on: $CURRENT_BRANCH)"
    if [ "$FORCE" = false ]; then
        print_error "Use --force to release from non-main branch"
        exit 1
    fi
fi

# Function to get current version from git tags
get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0"
}

# Function to increment version
increment_version() {
    local version="$1"
    local type="$2"
    
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local patch=$(echo "$version" | cut -d. -f3)
    
    case "$type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch + 1))"
            ;;
        *)
            print_error "Invalid version type: $type"
            exit 1
            ;;
    esac
}

# Function to validate version format
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: $version (expected: X.Y.Z)"
        exit 1
    fi
}

# Determine version to release
if [ -n "$VERSION" ]; then
    validate_version "$VERSION"
    NEW_VERSION="$VERSION"
else
    CURRENT_VERSION=$(get_current_version)
    NEW_VERSION=$(increment_version "$CURRENT_VERSION" "$RELEASE_TYPE")
    print_info "Current version: $CURRENT_VERSION"
fi

# Handle prerelease
if [ "$PRERELEASE" = true ]; then
    # Check if there's already a prerelease tag
    PRERELEASE_COUNT=$(git tag -l "v$NEW_VERSION-pre.*" | wc -l)
    NEW_VERSION="$NEW_VERSION-pre.$((PRERELEASE_COUNT + 1))"
fi

print_info "New version: $NEW_VERSION"

# Check if tag already exists
if git tag -l | grep -q "^v$NEW_VERSION$"; then
    print_error "Tag v$NEW_VERSION already exists"
    exit 1
fi

# Dry run output
if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN - Would perform the following actions:"
    print_info "  1. Run tests (unless --skip-tests)"
    print_info "  2. Generate version files"
    print_info "  3. Build release artifacts (unless --skip-build)"
    print_info "  4. Create git tag: v$NEW_VERSION"
    print_info "  5. Create release archives"
    print_info "  6. Push tag to remote"
    exit 0
fi

# Run tests unless skipped
if [ "$SKIP_TESTS" = false ]; then
    print_status "Running tests..."
    if [ -f "scripts/test.sh" ]; then
        ./scripts/test.sh
    else
        swift test
    fi
    print_status "Tests passed!"
fi

# Generate version information
print_status "Generating version information..."
if [ -f "scripts/version.sh" ]; then
    ./scripts/version.sh
fi

# Build release artifacts unless skipped
if [ "$SKIP_BUILD" = false ]; then
    print_status "Building release artifacts..."
    if [ -f "scripts/build.sh" ]; then
        ./scripts/build.sh --release --archive
    else
        swift build --configuration release
    fi
    print_status "Build completed!"
fi

# Create git tag
print_status "Creating git tag: v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

# Generate release notes
print_status "Generating release notes..."
RELEASE_NOTES_FILE="release_notes_v$NEW_VERSION.md"

# Get commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
    COMMITS=$(git log --oneline "$LAST_TAG..HEAD" | sed 's/^/- /')
else
    COMMITS=$(git log --oneline | sed 's/^/- /')
fi

# Create release notes
cat > "$RELEASE_NOTES_FILE" << EOF
# Release v$NEW_VERSION

## Changes

$COMMITS

## Installation

### macOS

1. Download the \`Dragoboo-v$NEW_VERSION-macos.dmg\` file
2. Open the DMG and drag Dragoboo to your Applications folder
3. Launch Dragoboo from Applications
4. Grant accessibility permissions when prompted

### Manual Installation

1. Download the \`Dragoboo-v$NEW_VERSION-macos.zip\` file
2. Extract and place Dragoboo.app in your Applications folder
3. Launch and grant accessibility permissions

## Requirements

- macOS 13.0 or later
- Accessibility permissions

## What's New

$(if [ "$PRERELEASE" = true ]; then echo "This is a prerelease version for testing purposes."; fi)

For detailed changes, see the commit history above.
EOF

print_status "Release notes generated: $RELEASE_NOTES_FILE"

# Create archive structure
ARCHIVE_DIR="archives"
mkdir -p "$ARCHIVE_DIR"

# Move built archives to release directory
if [ -d "build" ]; then
    RELEASE_DIR="releases/v$NEW_VERSION"
    mkdir -p "$RELEASE_DIR"
    
    # Copy app bundle
    if [ -d "build/Dragoboo.app" ]; then
        cp -r "build/Dragoboo.app" "$RELEASE_DIR/"
    fi
    
    # Copy archives if they exist
    if [ -f "$ARCHIVE_DIR/Dragoboo-v$NEW_VERSION-macos.zip" ]; then
        cp "$ARCHIVE_DIR/Dragoboo-v$NEW_VERSION-macos.zip" "$RELEASE_DIR/"
    fi
    
    if [ -f "$ARCHIVE_DIR/Dragoboo-v$NEW_VERSION-macos.dmg" ]; then
        cp "$ARCHIVE_DIR/Dragoboo-v$NEW_VERSION-macos.dmg" "$RELEASE_DIR/"
    fi
    
    # Copy release notes
    cp "$RELEASE_NOTES_FILE" "$RELEASE_DIR/"
    
    print_status "Release files organized in: $RELEASE_DIR"
fi

# Push tag to remote
print_status "Pushing tag to remote..."
git push origin "v$NEW_VERSION"

print_status "Release Summary:"
print_info "  Version: v$NEW_VERSION"
print_info "  Type: $RELEASE_TYPE$([ "$PRERELEASE" = true ] && echo " (prerelease)")"
print_info "  Tag: v$NEW_VERSION"
print_info "  Release Notes: $RELEASE_NOTES_FILE"
if [ -d "releases/v$NEW_VERSION" ]; then
    print_info "  Release Directory: releases/v$NEW_VERSION"
fi

print_status "Release completed successfully!"
print_info "Next steps:"
print_info "  1. Check GitHub for the new tag"
print_info "  2. Create GitHub release from tag (if using GitHub)"
print_info "  3. Upload artifacts to release page"
print_info "  4. Announce the release"

print_status "All done! 🎉"