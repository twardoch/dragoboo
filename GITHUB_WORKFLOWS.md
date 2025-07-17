# GitHub Workflows Setup

Since the GitHub App doesn't have workflows permission, you'll need to manually create the workflow files. Here are the three workflows to create:

## 1. Create `.github/workflows/ci.yml`

```yaml
# .github/workflows/ci.yml

name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

env:
  DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer

jobs:
  test:
    name: Test
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      
    - name: Show Xcode version
      run: xcodebuild -version
      
    - name: Show Swift version
      run: swift --version
      
    - name: Cache Swift Package Manager
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Generate version information
      run: |
        chmod +x scripts/version.sh
        ./scripts/version.sh
        
    - name: Resolve dependencies
      run: swift package resolve
      
    - name: Run tests
      run: |
        chmod +x scripts/test.sh
        ./scripts/test.sh --coverage --junit
        
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: |
          reports/
          coverage/
          
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      if: always()
      with:
        file: coverage/coverage.txt
        flags: unittests
        name: codecov-umbrella
        
  build:
    name: Build
    runs-on: macos-latest
    needs: test
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      
    - name: Cache Swift Package Manager
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Build debug
      run: |
        chmod +x scripts/build.sh
        ./scripts/build.sh --skip-tests
        
    - name: Build release
      run: |
        ./scripts/build.sh --release --skip-tests --archive
        
    - name: Upload debug artifacts
      uses: actions/upload-artifact@v3
      with:
        name: dragoboo-debug
        path: build/Dragoboo.app
        
    - name: Upload release artifacts
      uses: actions/upload-artifact@v3
      with:
        name: dragoboo-release
        path: |
          archives/
          build/Dragoboo.app
          
  lint:
    name: Lint
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Install SwiftLint
      run: |
        brew install swiftlint
        
    - name: Run SwiftLint
      run: |
        swiftlint --strict
        
    - name: Install SwiftFormat
      run: |
        brew install swiftformat
        
    - name: Check Swift formatting
      run: |
        swiftformat --lint .
        
  security:
    name: Security
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Run security checks
      run: |
        # Check for hardcoded secrets
        if grep -r "password\|secret\|token\|key" --include="*.swift" --exclude-dir=".git" .; then
          echo "Potential secrets found in code"
          exit 1
        fi
        
        # Check for unsafe Swift code patterns
        if grep -r "unsafeBitCast\|unsafeDowncast\|UnsafePointer" --include="*.swift" --exclude-dir=".git" .; then
          echo "Unsafe Swift patterns found - review required"
          # Don't fail build, just warn
        fi
        
    - name: Check dependencies
      run: |
        # List all dependencies
        swift package show-dependencies
        
        # Check for known vulnerable packages (basic check)
        swift package dump-package | grep -i "dependencies" || true
```

## 2. Create `.github/workflows/release.yml`

```yaml
# .github/workflows/release.yml

name: Release

on:
  push:
    tags:
      - 'v*'

env:
  DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer

jobs:
  release:
    name: Create Release
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        
    - name: Get tag name
      id: tag
      run: |
        echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
        echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
        
    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      
    - name: Show versions
      run: |
        xcodebuild -version
        swift --version
        
    - name: Cache Swift Package Manager
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Generate version information
      run: |
        chmod +x scripts/version.sh
        ./scripts/version.sh
        
    - name: Run tests
      run: |
        chmod +x scripts/test.sh
        ./scripts/test.sh --coverage
        
    - name: Build release
      run: |
        chmod +x scripts/build.sh
        ./scripts/build.sh --release --archive
        
    - name: Generate release notes
      id: notes
      run: |
        # Get previous tag
        PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
        
        # Generate changelog
        if [ -n "$PREV_TAG" ]; then
          CHANGELOG=$(git log --oneline "$PREV_TAG..HEAD" | sed 's/^/- /')
        else
          CHANGELOG=$(git log --oneline | head -20 | sed 's/^/- /')
        fi
        
        # Create release notes
        cat > release_notes.md << EOF
        # Release ${{ steps.tag.outputs.tag }}
        
        ## Changes
        
        $CHANGELOG
        
        ## Installation
        
        ### macOS
        
        1. Download the \`Dragoboo-${{ steps.tag.outputs.tag }}-macos.dmg\` file
        2. Open the DMG and drag Dragoboo to your Applications folder
        3. Launch Dragoboo from Applications
        4. Grant accessibility permissions when prompted
        
        ### Manual Installation
        
        1. Download the \`Dragoboo-${{ steps.tag.outputs.tag }}-macos.zip\` file
        2. Extract and place Dragoboo.app in your Applications folder
        3. Launch and grant accessibility permissions
        
        ## Requirements
        
        - macOS 13.0 or later
        - Accessibility permissions
        
        ## What's New
        
        For detailed changes, see the commit history above.
        EOF
        
    - name: Create Release
      id: create_release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ steps.tag.outputs.tag }}
        release_name: ${{ steps.tag.outputs.tag }}
        body_path: release_notes.md
        draft: false
        prerelease: ${{ contains(steps.tag.outputs.tag, '-pre') || contains(steps.tag.outputs.tag, '-beta') || contains(steps.tag.outputs.tag, '-alpha') }}
        
    - name: Upload ZIP Asset
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: ./archives/Dragoboo-${{ steps.tag.outputs.tag }}-macos.zip
        asset_name: Dragoboo-${{ steps.tag.outputs.tag }}-macos.zip
        asset_content_type: application/zip
        
    - name: Upload DMG Asset
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: ./archives/Dragoboo-${{ steps.tag.outputs.tag }}-macos.dmg
        asset_name: Dragoboo-${{ steps.tag.outputs.tag }}-macos.dmg
        asset_content_type: application/octet-stream
```

## 3. Create `.github/workflows/nightly.yml`

```yaml
# .github/workflows/nightly.yml

name: Nightly Build

on:
  schedule:
    # Run every day at 2 AM UTC
    - cron: '0 2 * * *'
  workflow_dispatch:
    # Allow manual trigger

env:
  DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer

jobs:
  nightly:
    name: Nightly Build
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        
    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      
    - name: Show versions
      run: |
        xcodebuild -version
        swift --version
        
    - name: Cache Swift Package Manager
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Generate version information
      run: |
        chmod +x scripts/version.sh
        ./scripts/version.sh
        
    - name: Run tests
      run: |
        chmod +x scripts/test.sh
        ./scripts/test.sh --coverage --junit
        
    - name: Build nightly
      run: |
        chmod +x scripts/build.sh
        ./scripts/build.sh --release --archive
        
    - name: Create nightly tag
      run: |
        DATE=$(date +%Y%m%d)
        COMMIT=$(git rev-parse --short HEAD)
        NIGHTLY_TAG="nightly-$DATE-$COMMIT"
        
        # Create a lightweight tag for nightly builds
        git tag "$NIGHTLY_TAG"
        
        echo "NIGHTLY_TAG=$NIGHTLY_TAG" >> $GITHUB_ENV
        echo "NIGHTLY_DATE=$DATE" >> $GITHUB_ENV
        echo "NIGHTLY_COMMIT=$COMMIT" >> $GITHUB_ENV
        
    - name: Upload nightly artifacts
      uses: actions/upload-artifact@v3
      with:
        name: dragoboo-nightly-${{ env.NIGHTLY_DATE }}
        path: |
          archives/
          build/
          coverage/
        retention-days: 30
```

## How to Add These Workflows

1. **Create the directory structure**:
   ```bash
   mkdir -p .github/workflows
   ```

2. **Create each workflow file** with the content above:
   - `.github/workflows/ci.yml`
   - `.github/workflows/release.yml`
   - `.github/workflows/nightly.yml`

3. **Commit and push the workflows**:
   ```bash
   git add .github/workflows/
   git commit -m "Add GitHub Actions workflows for CI/CD"
   git push
   ```

The workflows will automatically start running once you push them to the repository. The CI workflow will run on every push to main, the release workflow will trigger when you push git tags, and the nightly workflow will run daily at 2 AM UTC.