# Dragoboo 🐉🖱️

**Dragoboo is a macOS utility that provides instant precision cursor control through two powerful features: configurable slow speed mode and intelligent drag acceleration. Perfect for pixel-perfect design work, CAD precision, or any task requiring fine cursor control.**

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos) [![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org) [![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-purple.svg)](https://developer.apple.com/xcode/swiftui/) [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Key Features

### 🎯 Slow Speed Mode
- **Configurable Modifier Keys:** Choose any combination of `fn`, `⌃`, `⌥`, `⌘`
- **Percentage-Based Control:** 100% = normal speed, lower = slower (down to 5%)
- **Visual Feedback:** Modifier keys light up green when active
- **Universal Support:** Works with trackpads, mice, and scroll wheels

### 🚀 Drag Acceleration
- **Smart Acceleration:** Start slow, gradually speed up while dragging
- **Distance-Based:** Accelerates from slow to normal speed over configurable radius
- **No Modifiers Needed:** Works automatically when dragging
- **Speed Inheritance:** Starts at the speed set by slow speed slider

### 🎨 Modern UI
- **Compact Design:** Clean 300px wide interface
- **Toggle Controls:** Enable/disable features independently
- **Live Sliders:** Real-time adjustment with visual feedback
- **Menu Bar Integration:** Unobtrusive cursor icon in menu bar

## 🚀 Quick Start

### Requirements
- macOS 13.0 or later
- Accessibility permissions (guided setup on first launch)

### Installation & Usage

1. **Build & Run:**
   ```bash
   git clone https://github.com/twardoch/dragoboo.git
   cd dragoboo
   ./run.sh
   ```

2. **Grant Permissions:** Follow the in-app prompts to enable Accessibility access

3. **Configure & Use:**
   - Click the cursor icon in menu bar
   - Enable desired features with checkboxes
   - Adjust speed percentages with sliders
   - Hold chosen modifier keys for slow speed
   - Just drag for automatic acceleration

## 🛠 How It Works

### Technical Architecture

Dragoboo v2.0 uses a **hybrid approach** combining manual cursor warping and event modification:

#### Slow Speed Mode
1. **Modifier Detection**: Monitors chosen keys (`fn`, `⌃`, `⌥`, `⌘`) via `CGEventFlags`
2. **Precision Scaling**: Applies percentage-based factor (100% = normal, 50% = 2x slower)
3. **Cursor Warping**: Uses `CGWarpMouseCursorPosition` for precise control
4. **Accumulation**: Handles fractional movements for ultra-smooth scaling

#### Drag Acceleration
1. **Drag Detection**: Tracks mouse button down/up events
2. **Distance Calculation**: Measures actual movement from drag origin
3. **Progressive Scaling**: Interpolates from slow to normal over radius
4. **Smooth Curves**: Uses cubic easing for natural acceleration

### Core Formula

```swift
// Slow Speed Mode
precisionFactor = 200.0 / slowSpeedPercentage
// 100% → factor 2.0 (normal), 50% → factor 4.0 (2x slower)

// Drag Acceleration
progress = min(dragDistance / radius, 1.0)
easedProgress = progress³ × (3 - 2 × progress)  // Cubic easing
effectiveFactor = startFactor × (1 - easedProgress) + 2.0 × easedProgress
```

### Safety Features

- **Temporary Effects**: All changes revert when app exits
- **No System Modifications**: Uses cursor warping, not preference changes
- **Automatic Cleanup**: Effects disappear instantly on crash
- **Permission-Based**: Standard Accessibility framework only

## ⚙️ Configuration Guide

### Menu Bar Interface

<img width="300" alt="Dragoboo UI" src="docs/ui-screenshot.png">

#### Slow Speed Settings
- **Toggle**: Enable/disable slow speed functionality
- **Modifier Keys**: Click to select active keys (can use multiple)
- **Speed Slider**: 5-100% (100% = normal, lower = slower)

#### Drag Acceleration Settings
- **Toggle**: Enable/disable drag acceleration
- **Radius Slider**: 50-1000px acceleration distance
- **Info Text**: Explains acceleration behavior

### Usage Patterns

**For Precision Design Work:**
1. Set slow speed to 25-50%
2. Choose comfortable modifier (e.g., `fn`)
3. Hold modifier for pixel-perfect control

**For Variable Speed Tasks:**
1. Enable drag acceleration
2. Set radius based on screen size (200-400px typical)
3. Start dragging slowly, speed increases naturally

**For Maximum Control:**
1. Enable both features
2. Use modifiers for consistent slow speed
3. Drag without modifiers for acceleration

## 🧪 Technical Details

### Event Processing Pipeline

```
System Input → Event Tap → Precision Engine → Modified Output
                   ↓               ↓                ↓
            Modifier Check    Calculate Factor   Warp/Modify
```

### Coordinate System Handling

```swift
// NSEvent coordinates (bottom-left origin)
let nsEventPos = NSEvent.mouseLocation

// Convert to CGWarpMouseCursorPosition (top-left origin)
let cgPos = CGPoint(
    x: nsEventPos.x,
    y: screen.height - nsEventPos.y
)
```

### Performance Characteristics

- **Activation Latency**: <50ms for mode changes
- **CPU Usage**: <1% during active use
- **Memory Footprint**: ~15MB resident
- **Event Processing**: 60-120Hz depending on input device

## 📁 Project Structure

```
dragoboo/
├── Sources/
│   ├── DragobooApp/              # SwiftUI application
│   │   ├── DragobooApp.swift     # App lifecycle & state
│   │   ├── ContentView.swift     # UI components
│   │   └── Assets.xcassets/      # Icons & resources
│   └── DragobooCore/             # Core engine
│       └── PrecisionEngine.swift # Event handling & scaling
├── Tests/                        # Unit tests
├── Scripts/
│   ├── run.sh                    # Build & launch
│   ├── stop.sh                   # Terminate instances
└── Package.swift                 # Swift package config
```

### Key Components

**AppState** (Observable state management):
- Feature toggles (slowSpeedEnabled, dragAccelerationEnabled)
- User preferences (percentage, radius, modifier keys)
- Real-time status (isPrecisionModeActive, isDragging)

**PrecisionEngine** (Core event processor):
- Event tap creation and management
- Modifier key detection and tracking
- Movement scaling algorithms
- Cursor warping implementation
- Drag distance calculation

**ContentView** (SwiftUI interface):
- Toggle controls with state binding
- Slider components with live preview
- Modifier key button group
- Compact responsive layout

## 🔧 Building & Development

### Build Options

```bash
# Development build with auto-launch
./run.sh

# Build only (no launch)
./run.sh --no-launch

# Release build (optimized)
./run.sh --release

# Clean build
swift package clean && swift build
```

### Development Tips

1. **Testing Drag Acceleration**: 
   - Enable Console.app to see distance logs
   - Try different radius values for your screen size
   
2. **Debugging Modifier Keys**:
   - Buttons light up green when active
   - Check Console for "Precision mode activated" logs

3. **Performance Profiling**:
   - Use Instruments to monitor CPU usage
   - Event tap overhead should be minimal

## 🛡️ Troubleshooting

### Common Issues

**Slow speed not working:**
- Ensure at least one modifier key is selected
- Check Accessibility permissions in System Settings
- Verify modifier keys work in other apps

**Drag acceleration not working:**
- Enable the drag acceleration toggle
- Try increasing the radius value
- Ensure you're actually dragging (mouse button held)

**Cursor jumping:**
- Restart the app to reset coordinate tracking
- Check for conflicting cursor utilities
- Verify single display mode if issues persist

### Advanced Debugging

```bash
# View real-time logs
log show --predicate 'subsystem == "com.dragoboo.core"' --info --debug

# Check for permission issues
tccutil reset Accessibility com.dragoboo.app
```

## 🚀 Future Roadmap

### Near Term
- [ ] Application-specific profiles
- [ ] Alternative activation methods (double-tap fn, etc.)
- [ ] Visual overlay showing active zones
- [ ] Export/import settings

### Long Term
- [ ] AI-powered adaptive precision
- [ ] Gesture-based activation
- [ ] Multi-user profiles
- [ ] Integration with design tools

## 🤝 Contributing

We welcome contributions! Please:

1. Read [TODO.md](TODO.md) for current priorities
2. Follow Swift best practices
3. Add tests for new features
4. Update documentation
5. Test on multiple macOS versions

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built with Swift and SwiftUI for native macOS experience
- Inspired by precision needs in creative workflows
- Designed for safety with temporary-only modifications
- Community feedback shaped v2.0 features

---

**Dragoboo v2.0** - Precision when you need it, speed when you don't 🐉🖱️