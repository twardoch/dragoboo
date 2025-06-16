# TODO.md

## ✅ COMPLETED: v2.0 Features

### Slow Speed Mode ✅
- Configurable modifier keys (`fn`, `⌃`, `⌥`, `⌘`)
- Percentage-based control (100% = normal, below = slower)
- Visual feedback (green button highlighting)
- Can disable by deselecting all modifiers

### Drag Acceleration ✅
- Works independently (no modifiers required by default)
- Configurable modifier keys (optional activation)
- Starts at slow speed slider value
- Accelerates to normal over configurable radius
- Smooth cubic easing curve
- Precedence system: slow speed wins over drag acceleration for overlapping modifiers

### UI Improvements ✅
- Compact 300px width
- Toggle controls for features
- Real-time slider feedback
- Clean, intuitive layout
- Removed "Select modifier keys to activate" warning text
- Unified modifier key button component for both features

## 🔄 IMMEDIATE: Bug Fixes & Polish

### High Priority
- [ ] Test multi-display configurations thoroughly
- [ ] Add error handling for edge cases (display disconnection, etc.)
- [ ] Improve coordinate system handling for external displays
- [ ] Add logging for troubleshooting user issues

### Medium Priority
- [ ] Add haptic feedback when activating/deactivating modes (if trackpad)
- [ ] Optimize accumulator logic for very slow speeds (<10%)
- [ ] Test with various input devices (Magic Mouse, third-party mice)
- [ ] Profile memory usage during long sessions

### Low Priority
- [ ] Add tooltips to UI elements
- [ ] Improve slider visual feedback
- [ ] Add keyboard shortcuts for common actions
- [ ] Create app icon variations for different states

## 🚀 NEXT: v2.1 Features

### Visual Feedback System
- [ ] Optional floating indicator showing active mode
- [ ] Drag acceleration progress visualization
- [ ] Menu bar icon state changes
- [ ] Accessibility announcements

### Advanced Activation
- [ ] Double-tap modifier for toggle mode
- [ ] Long-press activation option
- [ ] Custom modifier combinations (e.g., fn+opt)
- [ ] Quick disable hotkey

### Performance Monitor
- [ ] Debug mode with performance stats
- [ ] Event processing latency display
- [ ] CPU/memory usage tracking
- [ ] Frame rate monitoring

## 📋 FUTURE: v2.5+ Roadmap

### Application Profiles
- [ ] Detect active application
- [ ] Per-app settings storage
- [ ] Profile switching UI
- [ ] Default profile management

### Enhanced Customization
- [ ] Custom acceleration curves editor
- [ ] Import/export settings
- [ ] Preset configurations
- [ ] Advanced user preferences

### Professional Features
- [ ] Pressure sensitivity support
- [ ] Directional speed biasing
- [ ] Zone-based acceleration
- [ ] Gesture triggers

## 🏗️ INFRASTRUCTURE

### Testing
- [ ] Unit tests for PrecisionEngine
- [ ] UI tests for ContentView
- [ ] Integration tests for event handling
- [ ] Performance benchmarks

### Distribution
- [ ] Create DMG installer
- [ ] Homebrew formula
- [ ] Auto-update mechanism
- [ ] Crash reporting

### Documentation
- [ ] Video tutorials
- [ ] User guide
- [ ] API documentation
- [ ] Contributing guide

## 🐛 KNOWN ISSUES

### To Investigate
- [ ] Occasional coordinate drift with multiple displays
- [ ] Potential memory leak after extended use (unconfirmed)
- [ ] Modifier key state can get stuck if app loses focus
- [ ] Drag acceleration may not reset properly on very fast movements

### User Reports
- [ ] Some users report lag with Bluetooth mice
- [ ] Conflict with certain accessibility tools
- [ ] Issues with macOS Sonoma 14.2+ (needs verification)

## 📝 NOTES

### Technical Debt
- PrecisionEngine could use refactoring for clarity
- Event handling logic is complex and needs documentation
- Coordinate system conversions need centralization
- Consider moving to async/await for future features

### User Feedback
- Users love the drag acceleration feature
- Requests for more visual feedback
- Some want per-application settings
- Professional users need pressure sensitivity

---

**Priority Guide**:
- 🔴 Critical (blocks usage)
- 🟡 Important (affects experience)
- 🟢 Nice to have (enhancement)
- 🔵 Future consideration

**Last Updated**: December 2024