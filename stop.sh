#!/bin/bash

# Dragoboo stop script
# This script stops the running Dragoboo app

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

EXECUTABLE_NAME="Dragoboo"

# Find Dragoboo process
APP_PID=$(pgrep -f "$EXECUTABLE_NAME" || true)

if [ -z "$APP_PID" ]; then
    print_warning "Dragoboo is not running"
    exit 0
fi

print_status "Found Dragoboo running (PID: $APP_PID)"
print_status "Stopping Dragoboo..."

# Try graceful termination first
kill "$APP_PID" 2>/dev/null

# Wait for process to terminate
sleep 1

# Check if still running
if pgrep -f "$EXECUTABLE_NAME" >/dev/null; then
    print_warning "Dragoboo didn't stop gracefully, forcing termination..."
    kill -9 "$APP_PID" 2>/dev/null || true
fi

# Final check
if pgrep -f "$EXECUTABLE_NAME" >/dev/null; then
    print_error "Failed to stop Dragoboo"
    exit 1
else
    print_status "Dragoboo stopped successfully"
fi
