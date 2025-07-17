#!/bin/bash
# this_file: /root/repo/scripts/test.sh

# Comprehensive test script for Dragoboo
# Runs all tests with proper reporting and coverage

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
COVERAGE=false
VERBOSE=false
PARALLEL=false
FILTER=""
JUNIT_OUTPUT=false

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --coverage    Generate code coverage report"
    echo "  --verbose     Enable verbose test output"
    echo "  --parallel    Run tests in parallel"
    echo "  --filter      Filter tests by name pattern"
    echo "  --junit       Generate JUnit XML output"
    echo "  --help        Show this help message"
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --coverage)
        COVERAGE=true
        shift
        ;;
    --verbose)
        VERBOSE=true
        shift
        ;;
    --parallel)
        PARALLEL=true
        shift
        ;;
    --filter)
        FILTER="$2"
        shift 2
        ;;
    --junit)
        JUNIT_OUTPUT=true
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

print_info "Starting test suite..."

# Check if swift is available
if ! command -v swift &>/dev/null; then
    print_error "Swift not found. Please install Xcode or Swift toolchain."
    exit 1
fi

# Build test flags
TEST_FLAGS=""

if [ "$VERBOSE" = true ]; then
    TEST_FLAGS="$TEST_FLAGS --verbose"
fi

if [ "$PARALLEL" = true ]; then
    TEST_FLAGS="$TEST_FLAGS --parallel"
fi

if [ "$COVERAGE" = true ]; then
    TEST_FLAGS="$TEST_FLAGS --enable-code-coverage"
fi

if [ -n "$FILTER" ]; then
    TEST_FLAGS="$TEST_FLAGS --filter '$FILTER'"
fi

# Run tests
print_status "Running Swift tests..."
print_info "Test flags: $TEST_FLAGS"

if [ "$JUNIT_OUTPUT" = true ]; then
    # Create reports directory
    mkdir -p reports
    
    # Run tests with XCTest format for JUnit conversion
    swift test $TEST_FLAGS 2>&1 | tee reports/test_output.txt
    TEST_EXIT_CODE=${PIPESTATUS[0]}
    
    # Convert to JUnit XML if possible
    if command -v xcpretty &>/dev/null; then
        print_status "Converting test output to JUnit XML..."
        cat reports/test_output.txt | xcpretty --report junit --output reports/junit.xml
    else
        print_warning "xcpretty not available, skipping JUnit XML generation"
    fi
else
    swift test $TEST_FLAGS
    TEST_EXIT_CODE=$?
fi

if [ $TEST_EXIT_CODE -ne 0 ]; then
    print_error "Tests failed!"
    exit $TEST_EXIT_CODE
fi

print_status "All tests passed!"

# Generate coverage report if requested
if [ "$COVERAGE" = true ]; then
    print_status "Generating code coverage report..."
    
    # Create coverage directory
    mkdir -p coverage
    
    # Export coverage data
    if swift test --enable-code-coverage --build-path .build >/dev/null 2>&1; then
        # Find the coverage profdata file
        PROFDATA_FILE=$(find .build -name "*.profdata" | head -1)
        
        if [ -n "$PROFDATA_FILE" ] && [ -f "$PROFDATA_FILE" ]; then
            print_status "Found coverage data: $PROFDATA_FILE"
            
            # Generate coverage report
            EXECUTABLE_PATH=$(find .build -name "DragobooPackageTests.xctest" -o -name "*Tests" | head -1)
            
            if [ -n "$EXECUTABLE_PATH" ] && [ -f "$EXECUTABLE_PATH" ]; then
                print_status "Generating coverage report..."
                
                # Generate text report
                xcrun llvm-cov report "$EXECUTABLE_PATH" -instr-profile="$PROFDATA_FILE" \
                    -use-color=false > coverage/coverage.txt
                
                # Generate HTML report
                xcrun llvm-cov show "$EXECUTABLE_PATH" -instr-profile="$PROFDATA_FILE" \
                    -format=html -output-dir=coverage/html
                
                # Generate summary
                xcrun llvm-cov report "$EXECUTABLE_PATH" -instr-profile="$PROFDATA_FILE" \
                    -use-color=false | grep "TOTAL" | tail -1 > coverage/summary.txt
                
                print_status "Coverage report generated in coverage/"
                
                # Display coverage summary
                if [ -f "coverage/summary.txt" ]; then
                    COVERAGE_SUMMARY=$(cat coverage/summary.txt)
                    print_info "Coverage Summary: $COVERAGE_SUMMARY"
                fi
            else
                print_warning "Could not find test executable for coverage report"
            fi
        else
            print_warning "Could not find coverage data file"
        fi
    else
        print_warning "Failed to generate coverage data"
    fi
fi

# Test specific components
print_status "Running component-specific tests..."

# Test DragobooCore
print_info "Testing DragobooCore..."
swift test --filter DragobooCoreTests

# Test DragobooApp (if tests exist)
if [ -d "Tests/DragobooAppTests" ]; then
    print_info "Testing DragobooApp..."
    swift test --filter DragobooAppTests
fi

# Run linting if available
if command -v swiftlint &>/dev/null; then
    print_status "Running SwiftLint..."
    swiftlint --strict
    if [ $? -ne 0 ]; then
        print_warning "SwiftLint found issues (not failing build)"
    else
        print_status "SwiftLint passed!"
    fi
else
    print_warning "SwiftLint not available, skipping lint check"
fi

# Run format checking if available
if command -v swiftformat &>/dev/null; then
    print_status "Checking Swift formatting..."
    swiftformat --lint .
    if [ $? -ne 0 ]; then
        print_warning "Swift formatting issues found (not failing build)"
    else
        print_status "Swift formatting is correct!"
    fi
else
    print_warning "SwiftFormat not available, skipping format check"
fi

print_status "Test suite completed successfully!"

# Generate test summary
print_status "Test Summary:"
print_info "  All tests: PASSED"
if [ "$COVERAGE" = true ]; then
    print_info "  Coverage report: coverage/"
fi
if [ "$JUNIT_OUTPUT" = true ]; then
    print_info "  JUnit XML: reports/junit.xml"
fi

print_status "All done! 🎉"