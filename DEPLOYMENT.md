# Deployment Guide

This document outlines the complete deployment and distribution system for Dragoboo.

## Overview

The deployment system provides:
- **Git-tag-based semversioning** with automatic version management
- **Comprehensive CI/CD pipeline** with GitHub Actions
- **Multiplatform binary distribution** (ZIP, DMG, GitHub Releases)
- **Automated release process** with version tagging
- **Easy installation methods** for end users

## Release Process

### 1. Development Workflow

```bash
# Daily development
make dev                    # Clean, test, build
make test-coverage         # Run tests with coverage
make lint                  # Check code quality

# Prepare for release
make clean
make ci                    # Run full CI pipeline locally
```

### 2. Creating a Release

#### Automatic Release (Recommended)
```bash
# Patch release (1.0.0 → 1.0.1)
make release-patch

# Minor release (1.0.1 → 1.1.0)
make release-minor

# Major release (1.1.0 → 2.0.0)
make release-major
```

#### Manual Release
```bash
# Specific version
./scripts/release.sh 1.2.3

# Prerelease
./scripts/release.sh --prerelease

# Dry run (preview)
./scripts/release.sh --dry-run
```

### 3. What Happens During Release

1. **Version Generation**
   - Updates `Sources/DragobooCore/Version.swift`
   - Incorporates git commit hash and build date
   - Determines development vs. release build

2. **Testing**
   - Runs complete test suite
   - Generates code coverage reports
   - Performs linting and formatting checks

3. **Building**
   - Creates release build
   - Generates .app bundle
   - Creates ZIP and DMG archives

4. **Git Operations**
   - Creates git tag (e.g., `v1.2.3`)
   - Pushes tag to remote repository
   - Generates release notes

5. **GitHub Actions**
   - Triggers release workflow
   - Uploads artifacts to GitHub Release
   - Creates distributable packages

## Distribution Channels

### 1. GitHub Releases

**Automatic Distribution**
- Triggered by git tag push
- Creates GitHub Release with assets
- Provides download links for ZIP and DMG

**Assets Created:**
- `Dragoboo-vX.Y.Z-macos.zip` - Simple ZIP archive
- `Dragoboo-vX.Y.Z-macos.dmg` - macOS disk image
- Release notes with changelog

### 2. Direct Download

**Files Available:**
```
releases/vX.Y.Z/
├── Dragoboo.app                           # Application bundle
├── Dragoboo-vX.Y.Z-macos.zip             # ZIP archive
├── Dragoboo-vX.Y.Z-macos.dmg             # DMG image
└── release_notes_vX.Y.Z.md               # Release notes
```

### 3. Homebrew (Planned)

**Future Distribution:**
```bash
# Will be available
brew install --cask dragoboo
```

## Installation Methods

### Method 1: GitHub Releases (Recommended)

```bash
# Download latest release
curl -L https://github.com/your-username/dragoboo/releases/latest/download/Dragoboo-latest-macos.dmg -o Dragoboo.dmg

# Install
open Dragoboo.dmg
# Drag to Applications folder
```

### Method 2: Build from Source

```bash
# Clone repository
git clone https://github.com/your-username/dragoboo.git
cd dragoboo

# Build and install
make archive
cp -r build/Dragoboo.app /Applications/
```

### Method 3: Nightly Builds

```bash
# Download nightly build
curl -L https://github.com/your-username/dragoboo/releases/download/nightly-YYYYMMDD-commit/Dragoboo-nightly-YYYYMMDD-macos.zip -o Dragoboo-nightly.zip
```

## CI/CD Pipeline

### GitHub Actions Workflows

#### 1. Continuous Integration (`ci.yml`)

**Triggers:**
- Push to main/develop branch
- Pull requests

**Actions:**
- Run comprehensive test suite
- Generate code coverage reports
- Build debug and release versions
- Perform security checks
- Upload test artifacts

#### 2. Release Automation (`release.yml`)

**Triggers:**
- Git tag push (e.g., `v1.2.3`)

**Actions:**
- Run full test suite
- Build release artifacts
- Create GitHub Release
- Upload ZIP and DMG files
- Generate release notes
- Update Homebrew formula

#### 3. Nightly Builds (`nightly.yml`)

**Triggers:**
- Daily at 2 AM UTC
- Manual workflow dispatch

**Actions:**
- Build latest development version
- Create nightly tag
- Upload artifacts (30-day retention)
- Create prerelease on GitHub

### Workflow Features

**Caching:**
- Swift Package Manager cache
- Xcode build cache
- Dependency caching

**Artifacts:**
- Build outputs (ZIP, DMG)
- Test reports (JUnit XML)
- Coverage reports
- Debug symbols

**Notifications:**
- Success/failure notifications
- Coverage reports
- Release announcements

## Version Management

### Semantic Versioning

**Format:** `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Version Sources

1. **Git Tags**: Primary source for version numbers
2. **Development**: Auto-generated from latest tag + commit
3. **Manual**: Specified version in release scripts

### Version Information

**Generated in `Version.swift`:**
```swift
static let semver = "1.2.3"
static let commit = "abc123d"
static let buildDate = "2025-01-01 00:00:00 UTC"
static let isDevelopment = false
```

## Multiplatform Support

### macOS Architecture Support

**Intel (x86_64):**
- Native Intel builds
- Rosetta 2 compatibility for Apple Silicon

**Apple Silicon (arm64):**
- Native ARM64 builds
- Optimal performance on M1/M2/M3 Macs

**Universal Binary (Future):**
- Single binary for both architectures
- Automatic architecture selection

### Build Configurations

**Debug Build:**
- Development symbols included
- Debug logging enabled
- Faster build times

**Release Build:**
- Optimized for performance
- Symbols stripped
- Smaller binary size

## Security

### Code Signing

**Development:**
- Ad-hoc signing for local builds
- No Apple Developer account required

**Release:**
- Proper code signing (requires Apple Developer account)
- Notarization for macOS Gatekeeper
- Verified authenticity

### Distribution Security

**Checksums:**
- SHA-256 hashes for all downloads
- Verification instructions provided

**Integrity:**
- Git tag verification
- Reproducible builds
- Open source transparency

## Monitoring

### Build Health

**Metrics Tracked:**
- Build success rate
- Test pass rate
- Code coverage trends
- Build duration

**Alerts:**
- Failed builds
- Test failures
- Security vulnerabilities
- Performance regressions

### Usage Analytics

**Privacy-Respecting:**
- No user data collection
- No telemetry in application
- Anonymous download statistics only

## Troubleshooting

### Common Issues

#### Build Failures
```bash
# Check build logs
make ci

# Clean rebuild
make clean
make build
```

#### Release Issues
```bash
# Verify git tags
git tag -l

# Check remote sync
git push --tags

# Manual release
./scripts/release.sh --dry-run
```

#### Distribution Problems
```bash
# Test archives
unzip -t archives/Dragoboo-*.zip
hdiutil verify archives/Dragoboo-*.dmg

# Check permissions
ls -la build/Dragoboo.app/Contents/MacOS/Dragoboo
```

### Debug Information

```bash
# Show project info
make info

# Check versions
./scripts/version.sh

# Verify build system
make pipeline
```

## Best Practices

### Development

1. **Always test locally** before pushing
2. **Use semantic versioning** consistently
3. **Write comprehensive tests** for new features
4. **Document changes** in commit messages
5. **Keep builds fast** and efficient

### Release Management

1. **Test releases** on multiple macOS versions
2. **Verify signatures** and notarization
3. **Update documentation** with each release
4. **Announce releases** to users
5. **Monitor feedback** and issues

### Security

1. **Never commit secrets** to repository
2. **Use secure channels** for sensitive operations
3. **Verify downloads** with checksums
4. **Keep dependencies updated**
5. **Respond quickly** to security issues

## Future Enhancements

### Planned Features

1. **Homebrew Formula** - Automated brew cask
2. **Auto-updater** - In-app update mechanism
3. **Delta Updates** - Smaller update downloads
4. **Rollback Support** - Easy version rollback
5. **Analytics Dashboard** - Usage statistics

### Infrastructure

1. **CDN Distribution** - Faster downloads
2. **Mirror Sites** - Redundant availability
3. **Beta Channel** - Early access program
4. **Crash Reporting** - Automated error collection
5. **Performance Monitoring** - Usage analytics

## Contributing

### Release Process

1. **Follow semver** guidelines
2. **Test thoroughly** before release
3. **Document changes** in release notes
4. **Coordinate** with maintainers
5. **Monitor** post-release feedback

### Infrastructure

1. **Improve build scripts** for efficiency
2. **Enhance CI/CD** pipeline
3. **Add monitoring** and alerting
4. **Optimize** distribution methods
5. **Maintain** documentation

---

**For detailed build instructions, see [BUILD.md](BUILD.md)**
**For installation help, see [INSTALL.md](INSTALL.md)**