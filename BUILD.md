# Build System Documentation

This document describes the comprehensive build system for Dragoboo, including git-tag-based semversioning, testing, and CI/CD automation.

## Overview

The build system provides:
- **Git-tag-based semversioning** with automatic version generation
- **Comprehensive test suite** with coverage reporting
- **Local build and release scripts** for development
- **GitHub Actions CI/CD pipeline** for automated testing and releases
- **Multiplatform binary distribution** with easy installation

## Quick Start

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.10 or later
- Git

### Basic Commands

```bash
# Development workflow
make dev          # Clean, test, and build
make run          # Build and run the app
make test         # Run tests
make clean        # Clean build directories

# Release workflow
make version      # Generate version info
make archive      # Create distributable archive
make release-patch # Create patch release
```

## Build Scripts

### `scripts/build.sh`

Comprehensive build script that handles:
- Version generation from git tags
- Debug and release builds
- App bundle creation
- Archive generation (ZIP and DMG)

```bash
# Basic usage
./scripts/build.sh                 # Debug build
./scripts/build.sh --release       # Release build
./scripts/build.sh --clean         # Clean build
./scripts/build.sh --archive       # Create archives
./scripts/build.sh --skip-tests    # Skip tests
```

### `scripts/test.sh`

Test runner with advanced features:
- Code coverage reporting
- JUnit XML output
- Parallel test execution
- SwiftLint integration

```bash
# Basic usage
./scripts/test.sh                  # Run tests
./scripts/test.sh --coverage       # Generate coverage
./scripts/test.sh --verbose        # Verbose output
./scripts/test.sh --junit         # JUnit XML output
./scripts/test.sh --parallel      # Parallel execution
```

### `scripts/release.sh`

Release automation script:
- Semantic version management
- Git tag creation
- Release note generation
- Archive creation and organization

```bash
# Basic usage
./scripts/release.sh --patch       # Create patch release
./scripts/release.sh --minor       # Create minor release
./scripts/release.sh --major       # Create major release
./scripts/release.sh 1.2.3         # Specific version
./scripts/release.sh --dry-run     # Preview changes
```

### `scripts/version.sh`

Version generation from git tags:
- Extracts version from latest git tag
- Generates build metadata
- Updates Version.swift file
- Supports development builds

## Makefile Targets

### Development Targets

```bash
make dev          # Clean, test, and build
make build        # Build without running
make run          # Build and run (default)
make clean        # Clean build directories
make stop         # Stop running app
make rebuild      # Clean and rebuild
```

### Testing Targets

```bash
make test         # Run tests
make test-coverage # Run tests with coverage
make test-verbose # Run tests with verbose output
make test-junit   # Run tests with JUnit output
```

### Code Quality

```bash
make lint         # Run SwiftLint
make format       # Format code with SwiftFormat
make format-check # Check code formatting
```

### Release Targets

```bash
make version      # Generate version information
make archive      # Create distributable archive
make release-patch # Create patch release
make release-minor # Create minor release
make release-major # Create major release
```

### CI/CD Targets

```bash
make ci          # Run CI pipeline locally
make pipeline    # Run full build pipeline
```

## Semantic Versioning

### Version Format

The project uses semantic versioning (semver) with the format `MAJOR.MINOR.PATCH`:

- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes

### Git Tags

Version tags follow the format `vX.Y.Z`:

```bash
v1.0.0     # Release version
v1.1.0-pre.1 # Prerelease version
v2.0.0-beta.1 # Beta version
```

### Version Generation

The version system automatically:
1. Extracts the latest git tag
2. Determines if it's a development build
3. Generates build metadata (commit hash, date)
4. Updates `Sources/DragobooCore/Version.swift`

## Test Suite

### Test Organization

```
Tests/
├── DragobooCoreTests/
│   ├── VersionTests.swift
│   └── PrecisionEngineTests.swift
└── DragobooAppTests/
    └── AppStateTests.swift
```

### Test Coverage

The test suite covers:
- Core functionality (PrecisionEngine)
- Version management
- App state management
- Error handling
- Edge cases

### Running Tests

```bash
# Basic test run
swift test

# With coverage
./scripts/test.sh --coverage

# Specific test filter
./scripts/test.sh --filter "VersionTests"
```

## CI/CD Pipeline

### GitHub Actions Workflows

#### `ci.yml` - Continuous Integration
- Triggers on push/PR to main branch
- Runs tests with coverage
- Builds debug and release versions
- Performs security checks
- Runs linting and formatting checks

#### `release.yml` - Release Automation
- Triggers on git tag push
- Runs full test suite
- Builds release artifacts
- Creates GitHub release
- Uploads ZIP and DMG files
- Updates Homebrew formula (if configured)

#### `nightly.yml` - Nightly Builds
- Runs daily at 2 AM UTC
- Creates development builds
- Uploads artifacts with 30-day retention
- Provides early access to latest changes

### Workflow Features

- **Artifact Upload**: Build artifacts are uploaded to GitHub
- **Test Reporting**: JUnit XML and coverage reports
- **Security Scanning**: Checks for secrets and unsafe patterns
- **Notification**: Success/failure notifications
- **Caching**: Swift Package Manager cache for faster builds

## Distribution

### Archive Formats

The build system creates multiple distribution formats:

#### ZIP Archive
- `Dragoboo-vX.Y.Z-macos.zip`
- Simple extraction and installation
- Suitable for direct distribution

#### DMG Image
- `Dragoboo-vX.Y.Z-macos.dmg`
- macOS disk image with drag-to-install
- Professional distribution format

### Installation Methods

#### GitHub Releases
1. Download from GitHub releases page
2. Extract or mount the archive
3. Drag to Applications folder
4. Grant accessibility permissions

#### Manual Build
```bash
git clone <repository>
cd dragoboo
make archive
open archives/
```

## Development Workflow

### Daily Development

```bash
# Start development
make dev

# Make changes...

# Test changes
make test

# Check code quality
make lint
make format-check

# Build and test
make run
```

### Release Process

```bash
# Prepare release
make clean
make test-coverage
make lint

# Create release
make release-patch  # or minor/major

# Verify release
git tag -l
ls archives/
```

### Working with Versions

```bash
# Check current version
make version

# See version info
cat Sources/DragobooCore/Version.swift

# Manual version generation
./scripts/version.sh
```

## Configuration

### Environment Variables

```bash
# Development settings
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# CI/CD settings
export GITHUB_TOKEN=<token>  # For GitHub Actions
```

### Build Configuration

Build configuration is managed through:
- `Package.swift` - Swift Package Manager configuration
- `Info.plist` - macOS application bundle configuration
- `scripts/` - Build script configuration

## Troubleshooting

### Common Issues

#### Build Failures
```bash
# Clean and rebuild
make clean
make deps
make build
```

#### Test Failures
```bash
# Run tests with verbose output
make test-verbose

# Run specific test
./scripts/test.sh --filter "TestName"
```

#### Permission Issues
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Check accessibility permissions
# System Settings > Privacy & Security > Accessibility
```

### Debug Information

```bash
# Show project info
make info

# Show versions
swift --version
xcodebuild -version
git --version
```

## Advanced Usage

### Custom Build Options

```bash
# Custom build with specific options
./scripts/build.sh --release --clean --skip-tests --archive

# Custom test run
./scripts/test.sh --coverage --parallel --filter "Core"

# Custom release
./scripts/release.sh 2.0.0 --skip-tests --dry-run
```

### Integration with IDEs

The build system works with:
- **Xcode**: Open `Package.swift` in Xcode
- **VS Code**: Use Swift extension
- **Command Line**: All scripts work from terminal

### Extending the Build System

To add new build targets:

1. Add script to `scripts/` directory
2. Make it executable: `chmod +x scripts/new-script.sh`
3. Add Makefile target
4. Update documentation

## Contributing

When contributing to the build system:

1. Test changes locally with `make ci`
2. Update documentation
3. Follow existing script patterns
4. Add appropriate error handling
5. Test with both development and release builds

## Support

For build system issues:
1. Check this documentation
2. Review script output for errors
3. Verify prerequisites are installed
4. Check GitHub Actions logs for CI issues
5. Create issue with reproduction steps