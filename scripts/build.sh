#!/bin/bash
# this_file: /root/repo/scripts/build.sh

# Comprehensive build script for Dragoboo
# Handles version generation, building, and packaging

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
APP_NAME="Dragoboo"
BUILD_DIR=".build"
EXECUTABLE_NAME="Dragoboo"
APP_BUNDLE_DIR="build"
APP_BUNDLE_NAME="Dragoboo.app"
ARCHIVE_DIR="archives"

# Parse command line arguments
CLEAN_BUILD=false
RELEASE_BUILD=false
SKIP_TESTS=false
SKIP_VERSION=false
VERBOSE=false
ARCHIVE=false

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --clean       Clean build directory before building"
    echo "  --release     Build in Release configuration"
    echo "  --skip-tests  Skip running tests"
    echo "  --skip-version Skip version generation"
    echo "  --verbose     Enable verbose output"
    echo "  --archive     Create distributable archive"
    echo "  --help        Show this help message"
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --clean)
        CLEAN_BUILD=true
        shift
        ;;
    --release)
        RELEASE_BUILD=true
        shift
        ;;
    --skip-tests)
        SKIP_TESTS=true
        shift
        ;;
    --skip-version)
        SKIP_VERSION=true
        shift
        ;;
    --verbose)
        VERBOSE=true
        shift
        ;;
    --archive)
        ARCHIVE=true
        shift
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# Enable verbose output if requested
if [ "$VERBOSE" = true ]; then
    set -x
fi

print_info "Starting build process..."
print_info "Configuration: $([ "$RELEASE_BUILD" = true ] && echo "Release" || echo "Debug")"

# Check if swift is available
if ! command -v swift &>/dev/null; then
    print_error "Swift not found. Please install Xcode or Swift toolchain."
    exit 1
fi

# Generate version information
if [ "$SKIP_VERSION" = false ]; then
    print_status "Generating version information..."
    if [ -f "scripts/version.sh" ]; then
        ./scripts/version.sh
    else
        print_warning "Version script not found, skipping version generation"
    fi
fi

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning build directories..."
    rm -rf "$BUILD_DIR"
    rm -rf "$APP_BUNDLE_DIR"
    rm -rf "$ARCHIVE_DIR"
fi

# Run tests unless skipped
if [ "$SKIP_TESTS" = false ]; then
    print_status "Running tests..."
    swift test
    if [ $? -ne 0 ]; then
        print_error "Tests failed!"
        exit 1
    fi
    print_status "All tests passed!"
fi

# Build the project
print_status "Building $APP_NAME..."
if [ "$RELEASE_BUILD" = true ]; then
    print_info "Building in Release mode..."
    swift build --configuration release
    EXECUTABLE_PATH="$BUILD_DIR/release/$EXECUTABLE_NAME"
else
    print_info "Building in Debug mode..."
    swift build
    EXECUTABLE_PATH="$BUILD_DIR/debug/$EXECUTABLE_NAME"
fi

# Check if build succeeded
if [ $? -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

print_status "Build completed successfully!"

# Check if executable exists
if [ ! -f "$EXECUTABLE_PATH" ]; then
    print_error "Could not find built executable at: $EXECUTABLE_PATH"
    exit 1
fi

print_status "Found executable at: $EXECUTABLE_PATH"

# Create .app bundle
print_status "Creating .app bundle..."
APP_BUNDLE_PATH="$APP_BUNDLE_DIR/$APP_BUNDLE_NAME"
CONTENTS_DIR="$APP_BUNDLE_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Create bundle directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable to bundle
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

# Update Info.plist with version information if version was generated
if [ "$SKIP_VERSION" = false ] && [ -f "Sources/DragobooCore/Version.swift" ]; then
    VERSION=$(grep 'static let semver = ' Sources/DragobooCore/Version.swift | cut -d'"' -f2)
    BUILD_DATE=$(grep 'static let buildDate = ' Sources/DragobooCore/Version.swift | cut -d'"' -f2)
    
    # Create updated Info.plist
    if [ -f "Info.plist" ]; then
        # Use sed to update version strings in Info.plist
        sed -e "s/<string>1.0<\/string>/<string>$VERSION<\/string>/g" \
            -e "s/<string>Copyright © 2025. All rights reserved.<\/string>/<string>Copyright © 2025. All rights reserved. Built: $BUILD_DATE<\/string>/g" \
            Info.plist > "$CONTENTS_DIR/Info.plist"
        print_status "Updated Info.plist with version $VERSION"
    else
        print_error "Info.plist not found! Please ensure Info.plist exists in the project root."
        exit 1
    fi
else
    # Copy Info.plist as-is
    if [ -f "Info.plist" ]; then
        cp "Info.plist" "$CONTENTS_DIR/"
        print_status "Copied Info.plist to bundle"
    else
        print_error "Info.plist not found! Please ensure Info.plist exists in the project root."
        exit 1
    fi
fi

# Copy Assets.xcassets if it exists
if [ -d "Sources/DragobooApp/Assets.xcassets" ]; then
    cp -r "Sources/DragobooApp/Assets.xcassets" "$RESOURCES_DIR/"
    print_status "Copied Assets.xcassets to bundle"
fi

print_status "App bundle created at: $APP_BUNDLE_PATH"

# Create archive if requested
if [ "$ARCHIVE" = true ]; then
    print_status "Creating distributable archive..."
    
    mkdir -p "$ARCHIVE_DIR"
    
    # Get version for archive naming
    VERSION="unknown"
    if [ -f "Sources/DragobooCore/Version.swift" ]; then
        VERSION=$(grep 'static let semver = ' Sources/DragobooCore/Version.swift | cut -d'"' -f2)
    fi
    
    ARCHIVE_NAME="Dragoboo-v$VERSION-macos"
    if [ "$RELEASE_BUILD" = false ]; then
        ARCHIVE_NAME="$ARCHIVE_NAME-debug"
    fi
    
    # Create ZIP archive
    ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME.zip"
    (cd "$APP_BUNDLE_DIR" && zip -r "../$ARCHIVE_PATH" "$APP_BUNDLE_NAME")
    
    print_status "Archive created at: $ARCHIVE_PATH"
    
    # Create DMG if hdiutil is available
    if command -v hdiutil &>/dev/null; then
        print_status "Creating DMG..."
        DMG_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME.dmg"
        
        # Create temporary directory for DMG contents
        DMG_TEMP_DIR="$ARCHIVE_DIR/dmg_temp"
        mkdir -p "$DMG_TEMP_DIR"
        
        # Copy app to DMG temp directory
        cp -r "$APP_BUNDLE_PATH" "$DMG_TEMP_DIR/"
        
        # Create DMG
        hdiutil create -srcfolder "$DMG_TEMP_DIR" -volname "Dragoboo" -format UDZO "$DMG_PATH"
        
        # Clean up temp directory
        rm -rf "$DMG_TEMP_DIR"
        
        print_status "DMG created at: $DMG_PATH"
    else
        print_warning "hdiutil not available, skipping DMG creation"
    fi
fi

# Generate summary
print_status "Build Summary:"
print_info "  Configuration: $([ "$RELEASE_BUILD" = true ] && echo "Release" || echo "Debug")"
print_info "  Bundle Location: $APP_BUNDLE_PATH"
print_info "  Executable: $MACOS_DIR/$EXECUTABLE_NAME"

if [ "$ARCHIVE" = true ]; then
    print_info "  Archive Location: $ARCHIVE_DIR/"
fi

print_status "Build completed successfully!"

# Update llms.txt if repomix is available
if command -v repomix &>/dev/null; then
    print_status "Updating llms.txt..."
    repomix -o llms.txt -i .specstory,_private,.cursorrules,CLAUDE.md,PLAN.md,TODO.md >/dev/null 2>&1 || true
    tree >>llms.txt 2>/dev/null || true
fi

print_status "All done! 🎉"