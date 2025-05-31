# Dragoboo 🐉🖱️

**Dragoboo is a macOS utility that provides instant precision cursor control through temporary cursor slowdown. Hold the `fn` key to activate precision mode, which applies configurable scaling (1x-10x slowdown) to cursor movement for detailed work.**

Perfect for designers doing pixel-perfect work in image editors, engineers working with CAD software, digital artists requiring fine brush control, or anyone needing temporary ultra-precise cursor control.

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos) [![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org) [![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-purple.svg)](https://developer.apple.com/xcode/swiftui/) [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Features

- **🎯 Instant Precision Mode:** Hold `fn` key for immediate cursor slowdown
- **⚡ Configurable Scaling:** Adjust slowdown factor from 1x to 10x (default: 4x)
- **🖱️ Universal Input Support:** Works with trackpads, mice, and scroll wheels
- **📊 Fractional Accumulation:** Precise movement scaling with sub-pixel accuracy
- **🔒 Crash-Safe Design:** Safe cursor warping with no permanent system changes
- **🎨 Clean Menu Bar UI:** Native macOS menu bar integration with SwiftUI
- **🚀 High Performance:** Minimal CPU usage with efficient event processing
- **⚡ Instant Response:** Sub-50ms activation latency for immediate precision

## 🚀 Quick Start

### Requirements
- macOS 13.0 or later
- Accessibility permissions (guided setup on first launch)

### Installation & Usage

1. **Build & Run:**
   ```bash
   git clone https://github.com/your-username/dragoboo.git
   cd dragoboo
   swift build
   swift run
   ```

2. **Grant Permissions:** Follow the in-app prompts to enable Accessibility access

3. **Use Precision Mode:** Hold `fn` key anywhere in macOS for slower cursor movement

4. **Adjust Settings:** Click the menu bar icon to customize slowdown factor

## 🛠 How It Works

### Technical Architecture

Dragoboo uses **safe cursor warping** technology to provide precision control without modifying system settings:

1. **Event Interception**: Creates system-wide event tap using `CGEvent.tapCreate(.cgAnnotatedSessionEventTap)`
2. **fn Key Detection**: Monitors `.maskSecondaryFn` flag in real-time through `flagsChanged` events  
3. **Movement Scaling**: Applies configurable precision scaling with fractional accumulation
4. **Cursor Warping**: Uses `CGWarpMouseCursorPosition` for direct, temporary cursor control
5. **Event Consumption**: Blocks original movement events to prevent double movement
6. **Auto-Revert**: All changes revert automatically when app exits or precision mode deactivates

### Core Components

- **`PrecisionEngine`**: Core event handling and cursor control engine
- **`AppState`**: SwiftUI state management with UserDefaults persistence  
- **`ContentView`**: Native menu bar interface with real-time feedback
- **Accumulation Algorithm**: Handles fractional movements for smooth scaling

### Precision Scaling Algorithm

```swift
// Fractional accumulation for smooth precision control
accumulatedX += originalDeltaX / precisionFactor
accumulatedY += originalDeltaY / precisionFactor

// Extract integer movement for this frame
let scaledX = Int(accumulatedX)
let scaledY = Int(accumulatedY)

// Preserve fractional remainders for next frame
accumulatedX -= Double(scaledX)
accumulatedY -= Double(scaledY)

// Apply warped movement
let newPosition = CGPoint(
    x: currentPosition.x + Double(scaledX),
    y: currentPosition.y + Double(scaledY)
)
CGWarpMouseCursorPosition(newPosition)
```

### Safety Architecture

- **No System Modifications**: Uses temporary cursor warping instead of system preference changes
- **Automatic Cleanup**: All effects revert when app terminates or precision mode deactivates
- **Permission-Based**: Requires only standard Accessibility permissions
- **Crash Recovery**: Includes recovery script for users of legacy versions

## 🔧 Building from Source

### Prerequisites
- **macOS 13.0+** (Ventura or later)
- **Xcode 14.1+** or Swift 5.10+ command line tools
- **Accessibility permissions** (guided setup during first launch)

### Quick Start
```bash
# Clone and build
git clone https://github.com/your-username/dragoboo.git
cd dragoboo
swift build

# Run directly
swift run
```

### Development Scripts
```bash
# Quick build and run with hot reload
./run.sh

# Build without launching
./run.sh --no-launch

# Release build
./run.sh --release

# Stop running instances
./stop.sh

# System recovery (for legacy version issues)
./recovery_trackpad.sh
```

### Xcode Development
```bash
# Generate Xcode project (optional)
swift package generate-xcodeproj
open Dragoboo.xcodeproj
```

## ⚙️ Configuration

### Menu Bar Settings
Click the cursor icon in your menu bar to access:

- **📐 Precision Factor**: 1x (no change) to 10x slowdown slider
- **🎯 Real-time Preview**: Live adjustment feedback while moving cursor
- **💾 Auto-save**: Settings automatically persist across app restarts
- **🔍 Status Indicator**: Visual feedback showing precision mode state

### Usage Instructions
1. **Activate**: Hold `fn` key while using trackpad/mouse
2. **Adjust**: Use menu bar slider to find optimal precision level
3. **Deactivate**: Release `fn` key to return to normal cursor speed

### Recommended Settings by Use Case
- **General precision work**: 2x-3x slowdown
- **Pixel-perfect design**: 4x-5x slowdown
- **Fine detail work**: 6x-8x slowdown
- **Ultra-precise tasks**: 9x-10x slowdown

## 🛡️ Safety & Recovery

**Dragoboo v2025+ is completely crash-safe.** The current implementation eliminates all risks present in earlier versions:

### Safety Features
- ✅ **Temporary Changes Only**: Uses cursor warping instead of system preference modification
- ✅ **Auto-Revert**: All effects automatically revert when app exits or crashes
- ✅ **No System Risk**: Cannot permanently modify trackpad/mouse settings
- ✅ **Permission-Controlled**: Uses standard macOS Accessibility framework
- ✅ **Instant Recovery**: Precision mode deactivates immediately when fn key released

### Legacy Version Recovery
If you experienced stuck trackpad/mouse settings from earlier versions:
```bash
./recovery_trackpad.sh  # Restores default macOS cursor settings
```

### Architecture Safety
Unlike system preference modification approaches, cursor warping:
- **Cannot persist after crashes** - system automatically reverts cursor control
- **Requires no cleanup** - effects are inherently temporary
- **Works across all apps** - universal compatibility without app-specific integration
- **Maintains system integrity** - no modification of system configuration files

## 🔍 Troubleshooting

### Common Issues

**Precision mode not working:**
- **Check Accessibility permissions**: System Settings → Privacy & Security → Accessibility → Enable for Dragoboo
- **Restart the app** after granting permissions to reinitialize event tap
- **Verify fn key functionality**: Test fn key in other apps (brightness/volume controls)
- **Check for conflicting apps**: Some utilities may interfere with fn key detection

**App won't start:**
- **System Requirements**: Ensure macOS 13.0+ (check About This Mac)
- **Build Issues**: Try `swift package clean && swift build`
- **Permission Conflicts**: Check Console.app for "accessibility denied" messages
- **Process Conflicts**: Use `./stop.sh` to terminate any stuck instances

**Performance or responsiveness issues:**
- **Reduce precision factor**: Lower values require less CPU for scaling calculations
- **Check system load**: High CPU usage from other apps can affect event processing
- **Monitor memory**: Close unnecessary apps if experiencing memory pressure

### Advanced Troubleshooting

**Event tap debugging:**
```bash
# Run with verbose logging to console
swift run 2>&1 | tee dragoboo.log

# Check for event tap creation issues
grep "Event tap" dragoboo.log
```

**Permission verification:**
```bash
# Check current accessibility permissions
echo "tell application \"System Events\"" | osascript
# Should not prompt if permissions are granted
```

**System compatibility:**
- **Secure Input Mode**: Some apps (e.g., 1Password) may block event modifications
- **Multiple Displays**: Cursor warping works across all connected displays
- **Virtual Machines**: May not work in virtualized macOS environments

## 📁 Project Structure

```
dragoboo/
├── Sources/
│   ├── DragobooApp/              # SwiftUI application layer
│   │   ├── DragobooApp.swift     # Main app entry point & state management
│   │   ├── ContentView.swift     # Menu bar UI components
│   │   └── Assets.xcassets/      # App icons and resources
│   └── DragobooCore/             # Core precision control engine
│       ├── PrecisionEngine.swift # Event handling & cursor warping
│       └── (SystemSpeedController.swift) # Legacy - marked for removal
├── Tests/
│   └── DragobooCoreTests/        # Unit tests for core functionality
│       └── PrecisionEngineTests.swift
├── Documentation/
│   ├── PLAN.md                   # Development roadmap & rewrite plan
│   ├── README.md                 # This comprehensive guide
│   └── ARCHITECTURE.md           # Technical implementation details
├── Scripts/
│   ├── run.sh                    # Build & run automation
│   ├── stop.sh                   # Process management
│   └── recovery_trackpad.sh      # Legacy system recovery
├── Config/
│   ├── Package.swift             # Swift package configuration
│   ├── Info.plist                # App bundle metadata
│   └── Makefile                  # Build system integration
└── Build/                        # Generated app bundles (gitignored)
```

### Core Architecture

**Application Layer** (`DragobooApp/`):
- User interface and system integration
- State management and persistence
- Menu bar interaction and visual feedback

**Engine Layer** (`DragobooCore/`):
- Low-level event interception and processing
- Cursor movement scaling and warping
- fn key state monitoring and precision mode control

**Testing Layer** (`Tests/`):
- Unit tests for precision algorithms
- Integration tests for event processing
- Accessibility permission mock testing

## 🧪 Development Status

### ✅ Production Ready
- **Core Precision Mode**: Fully functional cursor warping with sub-pixel accuracy
- **fn Key Detection**: Reliable real-time monitoring with <50ms response time
- **Event Interception**: System-wide coverage across all applications
- **Menu Bar UI**: Native SwiftUI interface with live status feedback
- **Settings Persistence**: Automatic configuration save/restore via UserDefaults
- **Crash Safety**: Temporary cursor warping with automatic cleanup
- **Universal Compatibility**: Works with trackpads, mice, and external pointing devices

### 🔄 In Progress
- **Scroll Wheel Scaling**: Basic implementation complete, refinement ongoing
- **Multi-Monitor Support**: Core functionality working, edge case testing in progress
- **Performance Optimization**: CPU usage profiling and memory optimization

### 📋 Future Enhancements
- **Variable Precision Zones**: Slower cursor movement near screen edges
- **Application-Specific Profiles**: Different precision factors per application
- **Advanced Key Combinations**: Alternative activation methods beyond fn key
- **Gesture Integration**: Trackpad gesture-based precision mode activation

### 🧹 Codebase Health
- **Current State**: Accumulated technical debt from multiple development iterations
- **Planned Rewrite**: Comprehensive simplification to remove ~750 lines of dead code
- **Target Architecture**: Clean, maintainable implementation focused on working cursor warping approach
- **Expected Benefits**: 50% code reduction, improved maintainability, enhanced reliability

## 🤝 Contributing

Contributions welcome! Please:

1. Check [PLAN.md](PLAN.md) for current development priorities and rewrite plan
2. Follow existing code patterns and Swift/SwiftUI best practices
3. Add unit tests for new functionality
4. Update documentation to reflect changes
5. Test across different macOS versions and hardware configurations

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built with Swift and SwiftUI for native macOS integration
- Inspired by the need for on-demand precision in creative workflows
- Uses advanced cursor control algorithms for smooth, responsive operation
- Designed with safety-first architecture to prevent system modifications

---

**Made with ❤️ for macOS productivity and precision**