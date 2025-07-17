# Installation Guide

This guide provides multiple ways to install and set up Dragoboo on your macOS system.

## System Requirements

- **macOS**: 13.0 (Ventura) or later
- **Architecture**: Intel (x86_64) or Apple Silicon (arm64)
- **Permissions**: Accessibility permissions required
- **Storage**: ~10 MB available space

## Installation Methods

### Method 1: GitHub Releases (Recommended)

1. **Download the latest release**
   - Visit the [GitHub releases page](https://github.com/your-username/dragoboo/releases)
   - Download the latest `Dragoboo-vX.Y.Z-macos.dmg` file

2. **Install from DMG**
   - Open the downloaded DMG file
   - Drag **Dragoboo.app** to your **Applications** folder
   - Eject the DMG

3. **Launch and grant permissions**
   - Open **Applications** folder
   - Right-click **Dragoboo.app** and select **Open**
   - Click **Open** in the security dialog
   - Grant **Accessibility permissions** when prompted

### Method 2: ZIP Archive

1. **Download ZIP**
   - Download `Dragoboo-vX.Y.Z-macos.zip` from releases
   - Extract the ZIP file

2. **Install manually**
   - Move **Dragoboo.app** to your **Applications** folder
   - Launch and grant permissions as above

### Method 3: Build from Source

1. **Prerequisites**
   ```bash
   # Install Xcode from App Store
   xcode-select --install
   
   # Verify Swift installation
   swift --version
   ```

2. **Clone and build**
   ```bash
   git clone https://github.com/your-username/dragoboo.git
   cd dragoboo
   make archive
   ```

3. **Install built app**
   ```bash
   # Copy to Applications
   cp -r build/Dragoboo.app /Applications/
   
   # Launch
   open /Applications/Dragoboo.app
   ```

### Method 4: Homebrew (Coming Soon)

```bash
# Will be available in the future
brew install --cask dragoboo
```

## Permissions Setup

### Accessibility Permissions

Dragoboo requires accessibility permissions to monitor and modify cursor movement.

1. **Initial Grant**
   - Launch Dragoboo
   - Click **Grant Permissions** when prompted
   - You'll be redirected to **System Settings**

2. **Manual Grant**
   - Open **System Settings**
   - Navigate to **Privacy & Security** > **Accessibility**
   - Click the **+** button
   - Select **Dragoboo** from Applications
   - Toggle **Dragoboo** to **On**

3. **Verify Permissions**
   - Launch Dragoboo
   - Look for the cursor icon in your menu bar
   - Try holding the `fn` key while moving your cursor

### Troubleshooting Permissions

If permissions aren't working:

1. **Remove and re-add** Dragoboo in Accessibility settings
2. **Restart** Dragoboo after granting permissions
3. **Check** that the toggle is actually **On**
4. **Restart** your Mac if issues persist

## Configuration

### First Launch

1. **Menu Bar Icon**
   - Look for the cursor icon in your menu bar
   - Click to open the settings panel

2. **Test Functionality**
   - Hold the `fn` key
   - Move your cursor or trackpad
   - Cursor should move slower for precision

3. **Adjust Settings**
   - Modify **precision factor** (1x to 10x slowdown)
   - Change **modifier keys** (fn, ⌃, ⌥, ⌘)
   - Configure **drag acceleration** if desired

### Settings Location

Settings are automatically saved to:
```
~/Library/Preferences/com.dragoboo.app.plist
```

### Default Settings

- **Precision Factor**: 4x slowdown (25% speed)
- **Modifier Key**: `fn` key
- **Drag Acceleration**: Enabled
- **Acceleration Radius**: 200 pixels

## Usage

### Basic Usage

1. **Activate Precision Mode**
   - Hold the `fn` key (or configured modifier)
   - Move your cursor or trackpad
   - Release to return to normal speed

2. **Scroll Precision**
   - Hold `fn` key while scrolling
   - Scroll wheel/trackpad scroll becomes precise

3. **Drag Acceleration**
   - Start dragging with mouse/trackpad
   - Drag starts slow, speeds up over distance
   - Reaches normal speed at configured radius

### Advanced Usage

- **Multiple Modifier Keys**: Configure combinations like `fn + ⌃`
- **Custom Precision**: Adjust from 1x to 10x slowdown
- **Drag Radius**: Set distance for acceleration curve
- **Quick Toggle**: Enable/disable features from menu bar

## Uninstallation

### Complete Removal

1. **Quit Dragoboo**
   ```bash
   # From menu bar: Right-click icon > Quit
   # Or force quit:
   pkill -f Dragoboo
   ```

2. **Remove Application**
   ```bash
   rm -rf /Applications/Dragoboo.app
   ```

3. **Remove Preferences**
   ```bash
   rm ~/Library/Preferences/com.dragoboo.app.plist
   ```

4. **Remove from Accessibility**
   - Open **System Settings**
   - Go to **Privacy & Security** > **Accessibility**
   - Remove **Dragoboo** from the list

### Clean Uninstall Script

```bash
#!/bin/bash
# Save as remove-dragoboo.sh and run: bash remove-dragoboo.sh

echo "Removing Dragoboo..."

# Quit the app
pkill -f Dragoboo 2>/dev/null

# Remove application
rm -rf /Applications/Dragoboo.app

# Remove preferences
rm -f ~/Library/Preferences/com.dragoboo.app.plist

echo "Dragoboo removed successfully!"
echo "Don't forget to remove it from Accessibility settings manually."
```

## Updates

### Automatic Updates

Dragoboo will check for updates automatically and notify you when new versions are available.

### Manual Updates

1. **Check Current Version**
   - Click menu bar icon
   - Version shown at bottom of panel

2. **Download New Version**
   - Visit GitHub releases page
   - Download latest version

3. **Replace Installation**
   - Quit current Dragoboo
   - Replace app in Applications folder
   - Launch new version

### Update Notifications

- **Stable releases**: Notify for all releases
- **Beta versions**: Opt-in via settings
- **Nightly builds**: Available on GitHub Actions

## Troubleshooting

### Common Issues

#### App Won't Launch
```bash
# Check permissions
ls -la /Applications/Dragoboo.app

# Try launching from terminal
/Applications/Dragoboo.app/Contents/MacOS/Dragoboo
```

#### Precision Mode Not Working
1. Verify accessibility permissions are granted
2. Check that correct modifier key is configured
3. Ensure app is running (menu bar icon visible)
4. Try different modifier key combinations

#### Performance Issues
1. Close other accessibility apps temporarily
2. Restart Dragoboo
3. Check Activity Monitor for high CPU usage
4. Report issue with system specs

#### Menu Bar Icon Missing
1. Check if app is actually running: `pgrep Dragoboo`
2. Restart the app
3. Check menu bar isn't full (hide other icons)
4. Try logging out and back in

### Debug Information

To gather debug information:

```bash
# Check app version
/Applications/Dragoboo.app/Contents/MacOS/Dragoboo --version

# View system logs
log show --predicate 'subsystem == "com.dragoboo.app"' --last 1h

# Check accessibility permissions
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT * FROM access WHERE service='kTCCServiceAccessibility' AND client='com.dragoboo.app'"
```

### Getting Help

1. **Check Documentation**
   - Read [README.md](README.md)
   - Review [BUILD.md](BUILD.md)
   - Check [PLAN.md](PLAN.md)

2. **Report Issues**
   - Use GitHub issue tracker
   - Include system information
   - Provide reproduction steps
   - Attach relevant logs

3. **Community Support**
   - GitHub Discussions
   - Stack Overflow (tag: dragoboo)

## Security

### Privacy

Dragoboo:
- **Does not** collect personal data
- **Does not** transmit data over network
- **Only** monitors cursor/keyboard events locally
- **Only** requires accessibility permissions

### Code Signing

- All releases are code-signed
- Verify signature: `codesign -dv /Applications/Dragoboo.app`
- Check notarization: `spctl -a -t exec -vv /Applications/Dragoboo.app`

### Open Source

- Full source code available on GitHub
- Build instructions in [BUILD.md](BUILD.md)
- Audit-friendly codebase
- No hidden functionality

## Support

For installation issues:

1. **Check this guide** for your specific problem
2. **Verify system requirements** are met
3. **Try different installation methods**
4. **Report bugs** with detailed information
5. **Ask for help** in GitHub Discussions

## Contributing

To contribute to installation improvements:

1. Test installation on different macOS versions
2. Report compatibility issues
3. Suggest installation method improvements
4. Help with documentation updates
5. Provide user feedback

---

**Need help?** Create an issue on GitHub or check the discussions section.