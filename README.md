# Dragoboo 🐉🖱️

**Dragoboo is a macOS utility that provides instant precision cursor control. Simply hold the `fn` key to temporarily slow down your cursor movement, enabling fine control for detailed tasks without interrupting your workflow.**

Perfect for designers pixel-peeping in image editors, engineers working with CAD software, or anyone who needs occasional ultra-precise cursor control.

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos) [![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org) [![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-purple.svg)](https://developer.apple.com/xcode/swiftui/) [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Features

- **🎯 Instant Precision Mode:** Hold `fn` key for immediate cursor slowdown
- **⚡ Configurable Scaling:** Adjust slowdown factor from 1x to 10x (default: 5x)
- **🖱️ Universal Input Support:** Works with trackpads, mice, and scroll wheels
- **📊 Smart Accumulation:** Handles fractional movements precisely using advanced algorithms
- **🔒 Crash-Safe Design:** Uses temporary event modification that auto-reverts
- **🎨 Clean Menu Bar UI:** Discreet macOS menu bar integration with SwiftUI
- **🚀 High Performance:** Minimal system impact with efficient event processing

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

Dragoboo uses **direct cursor warping** instead of risky system preference modifications:

1. **Event Interception:** Creates system-wide event tap using `CGEvent.tapCreate`
2. **fn Key Detection:** Monitors `.maskSecondaryFn` flag in `flagsChanged` events  
3. **Precision Scaling:** Applies fractional scaling with accumulation algorithm
4. **Cursor Warping:** Uses `CGWarpMouseCursorPosition` for direct control
5. **Event Consumption:** Blocks original events to prevent double movement

### Core Components

- **`PointerScaler`**: Core event handling and precision control engine
- **`AppState`**: SwiftUI state management and persistence  
- **`ContentView`**: Menu bar interface and settings
- **Movement Accumulator**: Handles fractional pixel movements precisely

```swift
// Key algorithm: Accumulation for smooth precision
accumulatedX += deltaX / precisionFactor
accumulatedY += deltaY / precisionFactor

let scaledX = Int(accumulatedX)
let scaledY = Int(accumulatedY)

accumulatedX -= Double(scaledX)
accumulatedY -= Double(scaledY)
```

## 🔧 Building from Source

### Command Line (Recommended)
```bash
# Build the project
swift build

# Run directly  
swift run

# Build release version
swift build --configuration release
```

### Using Xcode
```bash
# Generate Xcode project
swift package generate-xcodeproj
open Dragoboo.xcodeproj
```

### Helper Scripts
```bash
# Quick run
./run.sh

# Stop running instances  
./stop.sh

# System recovery (if needed)
./recovery_trackpad.sh
```

## ⚙️ Configuration

Access settings via the menu bar icon:

- **📐 Precision Factor**: 1x (no change) to 10x slowdown
- **🎯 Real-time Preview**: Live adjustment while moving cursor
- **💾 Auto-save**: Settings persist across app restarts
- **🔍 Status Indicator**: Visual feedback for active precision mode

## 🛡️ Safety & Recovery

**Dragoboo v2025-05-31+ is completely crash-safe.** Unlike earlier versions that could cause permanent trackpad slowdown, the current implementation:

- ✅ Uses temporary event modification only
- ✅ Auto-reverts on app exit or crash  
- ✅ No permanent system changes
- ✅ Includes recovery script for legacy issues

If you experienced issues with earlier versions:
```bash
./recovery_trackpad.sh  # Fixes any stuck settings
```

## 🔍 Troubleshooting

### Common Issues

**Precision mode not working:**
- Check Accessibility permissions in System Settings
- Restart the app after granting permissions
- Verify fn key isn't disabled in System Settings

**App won't start:**
- Ensure macOS 13.0+ 
- Try rebuilding: `swift package clean && swift build`
- Check Console.app for error messages

**Performance issues:**
- Modern Macs handle event processing efficiently
- If needed, reduce precision factor for less intensive scaling

### Debug Mode
```bash
# Run with verbose logging
swift run 2>&1 | tee dragoboo.log
```

## 📁 Project Structure

```
dragoboo/
├── Sources/
│   ├── DragobooApp/           # SwiftUI interface
│   │   ├── DragobooApp.swift  # Main app & state
│   │   └── ContentView.swift  # Menu bar UI
│   └── DragobooCore/          # Core functionality  
│       └── PointerScaler.swift # Event handling engine
├── Tests/
│   └── DragobooCoreTests/     # Unit tests
├── PLAN.md                    # Development roadmap
├── TODO.md                    # Current tasks
├── recovery_trackpad.sh       # System recovery
└── Package.swift              # Swift package config
```

## 🧪 Development Status

- ✅ **Core precision mode**: Fully functional
- ✅ **fn key detection**: Reliable & responsive  
- ✅ **Event interception**: System-wide coverage
- ✅ **Menu bar UI**: Clean SwiftUI interface
- ✅ **Settings persistence**: Auto-save configuration
- ✅ **Crash safety**: Temporary modifications only
- 🔄 **Scroll wheel scaling**: Basic implementation
- 🔄 **Multi-monitor support**: Needs testing
- 📋 **Drag operation refinement**: Future enhancement

## 🤝 Contributing

Contributions welcome! Please:

1. Check [TODO.md](TODO.md) for current tasks
2. Follow existing code patterns and documentation style
3. Add tests for new functionality
4. Update relevant documentation

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built with Swift and SwiftUI for native macOS integration
- Inspired by the need for on-demand precision in creative workflows
- Uses advanced cursor control algorithms for smooth operation

---

**Made with ❤️ for macOS productivity**
