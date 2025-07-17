.PHONY: all build run clean stop release help test test-coverage lint format version archive dev-release

# Default target
all: run

# Development targets
dev: clean test build

# Build the app
build:
	@./run.sh --no-launch

# Build and run the app
run:
	@./run.sh

# Clean build
clean:
	@echo "Cleaning build directory..."
	@rm -rf .build
	@rm -rf build
	@rm -rf archives
	@rm -rf coverage
	@rm -rf reports
	@echo "Clean complete"

# Stop the running app
stop:
	@./stop.sh

# Build release version
release:
	@./run.sh --release

# Build clean
rebuild: clean build

# Test targets
test:
	@echo "Running tests..."
	@scripts/test.sh

test-coverage:
	@echo "Running tests with coverage..."
	@scripts/test.sh --coverage

test-verbose:
	@echo "Running tests with verbose output..."
	@scripts/test.sh --verbose

test-junit:
	@echo "Running tests with JUnit output..."
	@scripts/test.sh --junit

# Linting and formatting
lint:
	@echo "Running linting..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --strict; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

format:
	@echo "Formatting code..."
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat .; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

format-check:
	@echo "Checking code formatting..."
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat --lint .; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

# Version management
version:
	@echo "Generating version information..."
	@scripts/version.sh

# Archive and release targets
archive:
	@echo "Creating archive..."
	@scripts/build.sh --release --archive

dev-release:
	@echo "Creating development release..."
	@scripts/release.sh --dry-run

release-patch:
	@echo "Creating patch release..."
	@scripts/release.sh --patch

release-minor:
	@echo "Creating minor release..."
	@scripts/release.sh --minor

release-major:
	@echo "Creating major release..."
	@scripts/release.sh --major

# CI/CD simulation
ci: clean test lint format-check build
	@echo "CI pipeline completed successfully!"

# Full build pipeline
pipeline: clean version test lint format-check build archive
	@echo "Full pipeline completed successfully!"

# Install dependencies (if any)
deps:
	@echo "Resolving dependencies..."
	@swift package resolve

# Update dependencies
update-deps:
	@echo "Updating dependencies..."
	@swift package update

# Show project info
info:
	@echo "Project Information:"
	@echo "==================="
	@echo "Swift version: $(shell swift --version | head -1)"
	@echo "Xcode version: $(shell xcodebuild -version | head -1)"
	@echo "Git branch: $(shell git rev-parse --abbrev-ref HEAD)"
	@echo "Git commit: $(shell git rev-parse --short HEAD)"
	@echo "Build directory: .build"
	@echo "Output directory: build"

# Show help
help:
	@echo "Dragoboo Makefile"
	@echo "================"
	@echo ""
	@echo "Development targets:"
	@echo "  make dev         - Clean, test, and build"
	@echo "  make build       - Build the app without running"
	@echo "  make run         - Build and run the app (default)"
	@echo "  make clean       - Clean build directories"
	@echo "  make stop        - Stop the running app"
	@echo "  make rebuild     - Clean and rebuild"
	@echo ""
	@echo "Testing targets:"
	@echo "  make test        - Run tests"
	@echo "  make test-coverage - Run tests with coverage"
	@echo "  make test-verbose - Run tests with verbose output"
	@echo "  make test-junit  - Run tests with JUnit output"
	@echo ""
	@echo "Code quality:"
	@echo "  make lint        - Run SwiftLint"
	@echo "  make format      - Format code with SwiftFormat"
	@echo "  make format-check - Check code formatting"
	@echo ""
	@echo "Release targets:"
	@echo "  make version     - Generate version information"
	@echo "  make archive     - Create distributable archive"
	@echo "  make release-patch - Create patch release"
	@echo "  make release-minor - Create minor release"
	@echo "  make release-major - Create major release"
	@echo ""
	@echo "CI/CD targets:"
	@echo "  make ci          - Run CI pipeline"
	@echo "  make pipeline    - Run full build pipeline"
	@echo ""
	@echo "Utility targets:"
	@echo "  make deps        - Resolve dependencies"
	@echo "  make update-deps - Update dependencies"
	@echo "  make info        - Show project information"
	@echo "  make help        - Show this help message"