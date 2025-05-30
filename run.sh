#!/bin/bash

# Dragoboo SPM build and run script
# This script builds and runs the Dragoboo app using Swift Package Manager

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if swift is available
if ! command -v swift &>/dev/null; then
    print_error "Swift not found. Please install Xcode or Swift toolchain."
    exit 1
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
APP_NAME="Dragoboo"
BUILD_DIR=".build"
EXECUTABLE_NAME="Dragoboo"

# Parse command line arguments
CLEAN_BUILD=false
RELEASE_BUILD=false
NO_LAUNCH=false

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
    --no-launch)
        NO_LAUNCH=true
        shift
        ;;
    --help | -h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --clean      Clean build directory before building"
        echo "  --release    Build in Release configuration"
        echo "  --no-launch  Build only, don't launch the app"
        echo "  --help       Show this help message"
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
done

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

print_status "Building $APP_NAME with Swift Package Manager..."

# Build the project
if [ "$RELEASE_BUILD" = true ]; then
    print_status "Building in Release mode..."
    swift build --configuration release
    EXECUTABLE_PATH="$BUILD_DIR/release/$EXECUTABLE_NAME"
else
    print_status "Building in Debug mode..."
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

# Exit here if --no-launch was specified
if [ "$NO_LAUNCH" = true ]; then
    print_status "Build complete. Executable location: $EXECUTABLE_PATH"
    exit 0
fi

# Check if app is already running and kill it
APP_PID=$(pgrep -f "$EXECUTABLE_NAME" || true)
if [ -n "$APP_PID" ]; then
    print_warning "Dragoboo is already running (PID: $APP_PID). Terminating..."
    kill "$APP_PID" 2>/dev/null || true
    sleep 1
fi

# Check accessibility permissions
print_warning "Note: Dragoboo requires accessibility permissions to function."
print_warning "You may be prompted to grant permissions in System Settings."

# Launch the executable
print_status "Launching $APP_NAME..."
"$EXECUTABLE_PATH" &

# Wait a moment for the app to start
sleep 2

# Check if app is running
if pgrep -f "$EXECUTABLE_NAME" >/dev/null; then
    print_status "Dragoboo is now running!"
    print_status "Look for the cursor icon in your menu bar"
    print_status "Hold the fn key while moving your trackpad/mouse for precision mode"
    echo ""
    print_warning "To stop Dragoboo: Use ./stop.sh or kill the process"
else
    print_error "Failed to launch Dragoboo"
    exit 1
fi
