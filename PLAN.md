# Dragoboo v2.0 Rewrite Plan

**Advanced precision control with configurable modifiers and drag acceleration**

## 🎯 Current Status: v1.5 Complete ✅ → v2.0 Design Required

**The codebase simplification is complete.** SystemSpeedController eliminated, PrecisionEngine implemented, and technical debt removed. Now implementing v2.0 with enhanced UI and drag acceleration features.

## 📊 Current Architecture State ✅

### ✅ COMPLETED v1.5 Cleanup
- **PrecisionEngine.swift**: 353 lines (clean implementation)
- **ContentView.swift**: 127 lines (simplified UI)  
- **DragobooApp.swift**: 89 lines (streamlined state)
- **SystemSpeedController.swift**: ❌ REMOVED (458 lines eliminated)
- **Total**: Clean, maintainable codebase with cursor warping approach

### ✅ Working Functionality
- fn key detection via `.maskSecondaryFn`
- Cursor scaling with fractional accumulation
- Safe cursor warping without system modifications
- Menu bar integration with real-time feedback
- Settings persistence via UserDefaults

## 🚀 v2.0 New Requirements

### UI Redesign Specifications

**Widget Width**: Designed for 400px sliders to fit perfectly

#### Section 1: Slow Speed Control
- **"Slow speed" slider**: 400px wide, shows percentage (50% = 2x slowdown)
- **Modifier button set**: Choose combination of `fn`, `ctrl`, `opt`, `cmd` for activation
- **Percentage display**: Clear visual feedback of current slowdown

#### Section 2: Drag Acceleration  
- **"Drag acceleration" slider**: 400px wide, controls acceleration radius
- **Behavior**: Start at slow speed, accelerate to normal speed over distance
- **Acceleration curve**: Non-linear (slow increase near start, faster increase with distance)

#### Layout Requirements
- **Compact and minimal**: Clear without clutter
- **Logical structure**: Intuitive grouping and flow
- **Quit button**: Positioned on the right

## 📋 v2.0 Implementation Plan

### Phase 1: UI Architecture Redesign 🔄

**New ContentView Structure**:
```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            if !appState.isAccessibilityGranted {
                AccessibilityRequestView()
            } else {
                // NEW: v2.0 UI Layout
                VStack(spacing: 16) {
                    SlowSpeedSection()
                    Divider()
                    DragAccelerationSection()
                }
            }
            
            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 480) // Adjusted for 400px sliders + padding
    }
}
```

**Section 1: Slow Speed Control**:
```swift
struct SlowSpeedSection: View {
    @EnvironmentObject var appState: AppState
    @State private var slowSpeedPercentage: Double = 50.0 // 50% = 2x slowdown
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Slow Speed")
                .font(.headline)
            
            // Percentage slider (400px wide)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Slowdown:")
                    Spacer()
                    Text("\(Int(slowSpeedPercentage))%")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $slowSpeedPercentage, in: 10...100, step: 5) { _ in
                    // Convert percentage to precision factor: 50% = 2x, 25% = 4x, etc.
                    let factor = 100.0 / slowSpeedPercentage
                    appState.updatePrecisionFactor(factor)
                }
                .frame(width: 400)
            }
            
            // Modifier key selection
            ModifierKeySelector()
        }
    }
}
```

**Modifier Key Selection Component**:
```swift
struct ModifierKeySelector: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activation Keys:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ModifierButton(key: .fn, label: "fn", isSelected: appState.modifierKeys.contains(.fn))
                ModifierButton(key: .control, label: "ctrl", isSelected: appState.modifierKeys.contains(.control))
                ModifierButton(key: .option, label: "opt", isSelected: appState.modifierKeys.contains(.option))
                ModifierButton(key: .command, label: "cmd", isSelected: appState.modifierKeys.contains(.command))
            }
        }
    }
}

struct ModifierButton: View {
    let key: ModifierKey
    let label: String
    let isSelected: Bool
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(label) {
            appState.toggleModifierKey(key)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .background(isSelected ? Color.accentColor : Color.clear)
        .foregroundColor(isSelected ? .white : .primary)
    }
}
```

**Section 2: Drag Acceleration**:
```swift
struct DragAccelerationSection: View {
    @EnvironmentObject var appState: AppState
    @State private var accelerationRadius: Double = 200.0 // pixels
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drag Acceleration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Acceleration Distance:")
                    Spacer()
                    Text("\(Int(accelerationRadius))px")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $accelerationRadius, in: 50...1000, step: 25) { _ in
                    appState.updateAccelerationRadius(accelerationRadius)
                }
                .frame(width: 400)
            }
            
            Text("Speed increases from slow to normal over this distance")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

### Phase 2: AppState Enhancement 🔄

**Extended AppState for v2.0**:
```swift
enum ModifierKey: CaseIterable {
    case fn, control, option, command
    
    var cgEventFlag: CGEventFlags {
        switch self {
        case .fn: return .maskSecondaryFn
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .command: return .maskCommand
        }
    }
}

class AppState: ObservableObject {
    @Published var isPrecisionModeActive = false
    @Published var isAccessibilityGranted = false
    @Published var isDragging = false
    
    // v2.0: Percentage-based precision factor (50% = 2x slowdown)
    @AppStorage("slowSpeedPercentage") var slowSpeedPercentage: Double = 50.0
    
    // v2.0: Configurable modifier keys
    @AppStorage("modifierKeys") private var modifierKeysData: Data = Data()
    
    // v2.0: Drag acceleration settings
    @AppStorage("accelerationRadius") var accelerationRadius: Double = 200.0
    
    var modifierKeys: Set<ModifierKey> {
        get {
            guard let decoded = try? JSONDecoder().decode(Set<ModifierKey>.self, from: modifierKeysData) else {
                return [.fn] // Default to fn key
            }
            return decoded
        }
        set {
            modifierKeysData = (try? JSONEncoder().encode(newValue)) ?? Data()
            precisionEngine?.updateModifierKeys(newValue)
        }
    }
    
    // Computed precision factor from percentage
    var precisionFactor: Double {
        return 100.0 / slowSpeedPercentage
    }
    
    private var precisionEngine: PrecisionEngine?
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "AppState")
    
    func toggleModifierKey(_ key: ModifierKey) {
        var keys = modifierKeys
        if keys.contains(key) {
            keys.remove(key)
        } else {
            keys.insert(key)
        }
        modifierKeys = keys
    }
    
    func updateSlowSpeedPercentage(_ percentage: Double) {
        slowSpeedPercentage = percentage
        precisionEngine?.updatePrecisionFactor(precisionFactor)
    }
    
    func updateAccelerationRadius(_ radius: Double) {
        accelerationRadius = radius
        precisionEngine?.updateAccelerationRadius(radius)
    }
}
```

### Phase 3: PrecisionEngine v2.0 Enhancement 🔄

**Enhanced PrecisionEngine for Drag Acceleration**:
```swift
public class PrecisionEngine {
    // Existing properties...
    private var modifierKeys: Set<ModifierKey> = [.fn]
    private var accelerationRadius: Double = 200.0
    
    // NEW: Drag state tracking
    private var isDragging = false
    private var dragStartPosition: CGPoint = .zero
    private var currentDragDistance: Double = 0.0
    
    public func updateModifierKeys(_ keys: Set<ModifierKey>) {
        modifierKeys = keys
        logger.info("Updated modifier keys: \(keys)")
    }
    
    public func updateAccelerationRadius(_ radius: Double) {
        accelerationRadius = radius
        logger.info("Updated acceleration radius: \(radius)")
    }
    
    // Enhanced event handling for drag detection
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
            
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if isInPrecisionMode {
                startDragTracking(at: getCursorPosition())
            }
            
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if isDragging {
                stopDragTracking()
            }
            
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if isInPrecisionMode {
                return modifyMovementEvent(event: event, isDragEvent: type != .mouseMoved)
            }
            
        // ... rest of existing cases
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // Enhanced movement modification with drag acceleration
    private func modifyMovementEvent(event: CGEvent, isDragEvent: Bool) -> Unmanaged<CGEvent>? {
        // Get movement delta
        let deltaX = getMovementDelta(event: event, axis: .x)
        let deltaY = getMovementDelta(event: event, axis: .y)
        
        guard deltaX != 0 || deltaY != 0 else {
            return Unmanaged.passUnretained(event)
        }
        
        // Calculate effective precision factor
        let effectiveFactor = calculateEffectivePrecisionFactor(isDragging: isDragEvent)
        
        // Apply scaling with accumulation
        accumulatedX += deltaX / effectiveFactor
        accumulatedY += deltaY / effectiveFactor
        
        let scaledX = Int(accumulatedX)
        let scaledY = Int(accumulatedY)
        
        accumulatedX -= Double(scaledX)
        accumulatedY -= Double(scaledY)
        
        // Update drag distance if dragging
        if isDragEvent && isDragging {
            currentDragDistance += sqrt(Double(scaledX * scaledX + scaledY * scaledY))
        }
        
        // Apply cursor warping
        let newPosition = CGPoint(
            x: lastCursorPosition.x + Double(scaledX),
            y: lastCursorPosition.y + Double(scaledY)
        )
        
        if CGWarpMouseCursorPosition(newPosition) == .success {
            lastCursorPosition = newPosition
        } else {
            return Unmanaged.passUnretained(event)
        }
        
        return nil
    }
    
    // NEW: Drag acceleration calculation
    private func calculateEffectivePrecisionFactor(isDragging: Bool) -> Double {
        guard isDragging && self.isDragging else {
            return precisionFactor
        }
        
        // Non-linear acceleration curve
        let progress = min(currentDragDistance / accelerationRadius, 1.0)
        
        // Cubic easing function for non-linear acceleration
        // Slow increase near start, faster increase with distance
        let easedProgress = progress * progress * (3.0 - 2.0 * progress)
        
        // Interpolate between precision factor and 1.0 (normal speed)
        return precisionFactor * (1.0 - easedProgress) + 1.0 * easedProgress
    }
    
    // Enhanced modifier key detection
    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        
        // Check if any configured modifier keys are pressed
        let wasActive = fnKeyPressed
        fnKeyPressed = modifierKeys.contains { key in
            flags.contains(key.cgEventFlag)
        }
        
        if wasActive != fnKeyPressed {
            handleActivationStateChange(isPressed: fnKeyPressed)
        }
    }
    
    private func startDragTracking(at position: CGPoint) {
        isDragging = true
        dragStartPosition = position
        currentDragDistance = 0.0
        logger.debug("Started drag tracking at \(position)")
    }
    
    private func stopDragTracking() {
        isDragging = false
        currentDragDistance = 0.0
        logger.debug("Stopped drag tracking")
    }
}
```

### Phase 4: UI Polish and Integration 🔄

**Enhanced Menu Bar Integration**:
```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            if !appState.isAccessibilityGranted {
                AccessibilityRequestView()
            } else {
                VStack(spacing: 16) {
                    SlowSpeedSection()
                    Divider()
                    DragAccelerationSection()
                    StatusSection()
                }
            }
            
            HStack {
                StatusIndicator()
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .onAppear { appState.refreshPermissions() }
        .padding()
        .frame(width: 480)
    }
}

struct StatusSection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let activeKeys = appState.modifierKeys.map { key in
                switch key {
                case .fn: return "fn"
                case .control: return "ctrl"
                case .option: return "opt"
                case .command: return "cmd"
                }
            }.joined(separator: " + ")
            
            Label("Hold \(activeKeys) to activate precision mode", systemImage: "keyboard")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if appState.isPrecisionModeActive {
                Label("Precision mode active", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                if appState.isDragging {
                    Label("Drag acceleration active", systemImage: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
```

## 🎯 Implementation Schedule

### Week 1: UI Foundation 🔄
- [ ] Design new 400px slider components
- [ ] Implement percentage-based slow speed control
- [ ] Create modifier key selection interface
- [ ] Update ContentView layout for new width requirements

### Week 2: Modifier System 🔄
- [ ] Extend PrecisionEngine for configurable modifier keys
- [ ] Implement modifier key combination detection
- [ ] Add modifier key persistence to AppState
- [ ] Test modifier key functionality across different combinations

### Week 3: Drag Acceleration 🔄
- [ ] Implement drag state detection in PrecisionEngine
- [ ] Create non-linear acceleration algorithm
- [ ] Add drag acceleration slider and controls
- [ ] Integrate drag distance tracking with cursor warping

### Week 4: Polish and Testing 🔄
- [ ] Refine acceleration curve for optimal user experience
- [ ] Add visual feedback for drag acceleration state
- [ ] Comprehensive testing across different use cases
- [ ] Performance optimization and final polish

## ✅ Success Criteria

### Functional Requirements ✅
- [ ] Percentage-based speed control (10%-100% range)
- [ ] Configurable modifier key combinations work reliably
- [ ] Drag acceleration with non-linear speed increase
- [ ] Smooth transition from slow to normal speed during drag
- [ ] 400px sliders fit perfectly in redesigned interface

### User Experience Requirements ✅
- [ ] Intuitive percentage display (50% = half speed)
- [ ] Clear modifier key selection with visual feedback
- [ ] Responsive drag acceleration with immediate feedback
- [ ] Compact, minimal interface without clutter
- [ ] Logical information hierarchy and grouping

### Technical Requirements ✅
- [ ] Maintains all existing safety features (cursor warping)
- [ ] Settings persistence across app restarts
- [ ] Performance equivalent to v1.5 implementation
- [ ] Clean, maintainable code architecture
- [ ] Backward compatibility with existing precision algorithms

---

**v2.0 will transform Dragoboo from a simple fn-key precision tool into a sophisticated cursor control system with customizable activation and intelligent drag acceleration.**