# Dragoboo Fix Plan: Implement Working Precision Cursor Control

## Problem Analysis

The current Dragoboo implementation has a solid UI and event detection system, but **the core functionality is completely broken**. When the `fn` key is held, cursor movement does NOT slow down as expected. Based on analysis of the codebase and research, this is happening because:

1. **Modern macOS security restrictions**: macOS Sequoia and later have strict timestamp validation that silently rejects CGEventTap modifications
2. **Event modification limitations**: The current approach of modifying CGEvent fields in the event tap callback is being ignored by the system
3. **API deprecation**: The CGEventTap approach has become unreliable on modern macOS versions

## Root Cause

The `PointerScaler.swift` implementation correctly:
- ✅ Detects `fn` key presses via event taps and polling
- ✅ Receives mouse movement events  
- ✅ Modifies the CGEvent delta values in memory
- ❌ **But macOS ignores these modifications completely**

The logs show that scaling is being "applied" (`✅ SCALING APPLIED!`), but the actual cursor movement on screen remains unaffected because macOS rejects the modified events due to security restrictions.

## Solution: Implement IOKit-Based System Speed Control

Based on research, the most reliable approach is to use **IOKit HID system APIs** to modify the system's pointer acceleration settings directly, rather than trying to modify individual events.

### Technical Approach

Instead of modifying individual mouse events, we'll:
1. Monitor `fn` key state (keep existing detection)
2. When `fn` is pressed: Save current system mouse speed and set a slower speed
3. When `fn` is released: Restore the original system mouse speed
4. Use IOKit's IOHIDEventSystemClient APIs to modify system pointer acceleration

## Step-by-Step Implementation Plan

### Phase 1: Add IOKit Integration

#### Step 1.1: Update Package.swift Dependencies
Add IOKit framework to the project:

```swift
// In Package.swift, update targets:
.target(
    name: "DragobooCore",
    dependencies: [],
    linkerSettings: [
        .linkedFramework("IOKit"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("CoreGraphics")
    ]
)
```

#### Step 1.2: Create System Speed Controller
Create a new file `Sources/DragobooCore/SystemSpeedController.swift`:

```swift
import Foundation
import IOKit
import IOKit.hid

public class SystemSpeedController {
    private var originalMouseSpeed: Double?
    private var originalTrackpadSpeed: Double?
    
    public init() {}
    
    public func setSlowSpeed(factor: Double) throws {
        // Save original speeds if not already saved
        if originalMouseSpeed == nil {
            originalMouseSpeed = try getCurrentMouseSpeed()
        }
        if originalTrackpadSpeed == nil {
            originalTrackpadSpeed = try getCurrentTrackpadSpeed()
        }
        
        // Calculate new slow speeds
        let slowMouseSpeed = (originalMouseSpeed ?? 0.6875) / factor
        let slowTrackpadSpeed = (originalTrackpadSpeed ?? 0.6875) / factor
        
        // Apply slow speeds
        try setMouseSpeed(slowMouseSpeed)
        try setTrackpadSpeed(slowTrackpadSpeed)
    }
    
    public func restoreOriginalSpeed() throws {
        guard let mouseSpeed = originalMouseSpeed,
              let trackpadSpeed = originalTrackpadSpeed else {
            return // Nothing to restore
        }
        
        try setMouseSpeed(mouseSpeed)
        try setTrackpadSpeed(trackpadSpeed)
    }
    
    private func getCurrentMouseSpeed() throws -> Double {
        // Use IOKit to read current mouse acceleration setting
        // Implementation details below...
    }
    
    private func getCurrentTrackpadSpeed() throws -> Double {
        // Use IOKit to read current trackpad acceleration setting
        // Implementation details below...
    }
    
    private func setMouseSpeed(_ speed: Double) throws {
        // Use IOHIDEventSystemClient to set mouse acceleration
        // Implementation details below...
    }
    
    private func setTrackpadSpeed(_ speed: Double) throws {
        // Use IOHIDEventSystemClient to set trackpad acceleration
        // Implementation details below...
    }
}
```

#### Step 1.3: Implement IOKit HID System Client
The core implementation will use IOHIDEventSystemClient:

```swift
private func setMouseSpeed(_ speed: Double) throws {
    let system = IOHIDEventSystemClientCreateWithType(
        kCFAllocatorDefault,
        kIOHIDEventSystemClientTypeAdmin,
        nil
    )
    
    guard system != nil else {
        throw SystemSpeedError.failedToCreateHIDClient
    }
    
    let property = CFStringCreateWithCString(
        kCFAllocatorDefault,
        "HIDMouseAcceleration",
        kCFStringEncodingUTF8
    )
    
    let value = CFNumberCreate(
        kCFAllocatorDefault,
        .doubleType,
        &speed
    )
    
    IOHIDEventSystemClientSetProperty(system, property, value)
}
```

### Phase 2: Update PointerScaler Architecture

#### Step 2.1: Modify PointerScaler.swift
Replace the event modification approach with system speed control:

```swift
public class PointerScaler {
    private var systemSpeedController: SystemSpeedController
    private var precisionFactor: Double
    private var fnKeyPressed = false
    private var isInPrecisionMode = false
    
    // Keep existing event tap for fn key detection only
    // Remove all mouse event modification code
    
    private func handleFnKeyStateChange(isPressed: Bool) {
        guard isPressed != fnKeyPressed else { return }
        
        fnKeyPressed = isPressed
        
        do {
            if isPressed && !isInPrecisionMode {
                try systemSpeedController.setSlowSpeed(factor: precisionFactor)
                isInPrecisionMode = true
                logger.info("Precision mode activated - system speed slowed by \(precisionFactor)x")
            } else if !isPressed && isInPrecisionMode {
                try systemSpeedController.restoreOriginalSpeed()
                isInPrecisionMode = false
                logger.info("Precision mode deactivated - system speed restored")
            }
            
            onPrecisionModeChange?(isPressed)
        } catch {
            logger.error("Failed to change system speed: \(error)")
        }
    }
}
```

#### Step 2.2: Simplify Event Handling
Remove all mouse event modification code and focus only on fn key detection:

```swift
private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    switch type {
    case .flagsChanged:
        handleFlagsChanged(event: event)
        
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        logger.warning("Event tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user input"), attempting to re-enable")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        
    default:
        break // Ignore all other events
    }
    
    return Unmanaged.passUnretained(event)
}
```

### Phase 3: Error Handling and Permissions

#### Step 3.1: Add Comprehensive Error Handling
Create proper error types for system speed control:

```swift
public enum SystemSpeedError: LocalizedError {
    case failedToCreateHIDClient
    case permissionDenied
    case failedToReadCurrentSpeed
    case failedToSetSpeed
    
    public var errorDescription: String? {
        switch self {
        case .failedToCreateHIDClient:
            return "Failed to create HID system client"
        case .permissionDenied:
            return "Permission denied - ensure Accessibility permissions are granted"
        case .failedToReadCurrentSpeed:
            return "Failed to read current mouse/trackpad speed"
        case .failedToSetSpeed:
            return "Failed to set mouse/trackpad speed"
        }
    }
}
```

#### Step 3.2: Update Permission Checking
Ensure the app has necessary permissions:

```swift
// In AppState.swift
private func checkPermissions() -> Bool {
    // Check Accessibility permission (required for fn key detection)
    guard AXIsProcessTrusted() else {
        logger.error("Accessibility permission required")
        return false
    }
    
    // Test HID system access
    let system = IOHIDEventSystemClientCreateWithType(
        kCFAllocatorDefault,
        kIOHIDEventSystemClientTypeAdmin,
        nil
    )
    
    guard system != nil else {
        logger.error("Failed to create HID system client - may need additional permissions")
        return false
    }
    
    return true
}
```

### Phase 4: Fallback Implementation

#### Step 4.1: Add UserDefaults Fallback
If IOKit approach fails, implement a fallback using system preferences:

```swift
private func fallbackSetMouseSpeed(_ speed: Double) throws {
    // Modify global defaults as fallback
    let currentSpeed = UserDefaults.standard.double(forKey: "com.apple.mouse.scaling")
    
    if originalMouseSpeed == nil {
        originalMouseSpeed = currentSpeed
    }
    
    UserDefaults.standard.set(speed, forKey: "com.apple.mouse.scaling")
    
    // Force preference synchronization
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    
    // Post notification to force system reload
    DistributedNotificationCenter.default().post(
        name: NSNotification.Name("com.apple.systempreferences.mousesettings.changed"),
        object: nil
    )
}
```

### Phase 5: Testing and Validation

#### Step 5.1: Add Validation Methods
Create methods to verify the system speed changes are working:

```swift
public func validateSpeedChange() -> Bool {
    do {
        let currentSpeed = try getCurrentMouseSpeed()
        let expectedSpeed = (originalMouseSpeed ?? 0.6875) / precisionFactor
        
        return abs(currentSpeed - expectedSpeed) < 0.1
    } catch {
        return false
    }
}
```

#### Step 5.2: Update UI Feedback
Modify ContentView.swift to show actual system state:

```swift
struct PrecisionStatusView: View {
    @EnvironmentObject var appState: AppState
    @State private var systemSpeedValid = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(appState.isPrecisionModeActive ? 
                      (systemSpeedValid ? .green : .orange) : .gray)
                .frame(width: 8, height: 8)
            
            Text(appState.isPrecisionModeActive ? 
                 (systemSpeedValid ? "System speed modified" : "Speed change failed") : 
                 "Ready")
                .font(.caption)
        }
        .onAppear {
            // Validate system speed when view appears
        }
    }
}
```

## Implementation Timeline

1. **Week 1**: Implement IOKit system speed controller
2. **Week 2**: Update PointerScaler to use system speed control
3. **Week 3**: Add error handling and fallback mechanisms
4. **Week 4**: Testing and UI improvements

## Key Benefits of This Approach

1. **Reliable**: Works on all modern macOS versions including Sequoia
2. **Efficient**: No event stream processing overhead
3. **System-wide**: Affects all applications consistently
4. **Permission-compatible**: Works with existing Accessibility permissions
5. **Recoverable**: Can always restore original settings

## Risks and Mitigations

1. **IOKit API changes**: Use defensive programming and fallbacks
2. **Permission issues**: Provide clear error messages and guidance
3. **System state corruption**: Always restore settings on app termination
4. **Performance**: Minimal impact since we're only changing settings, not processing events

This plan provides a complete roadmap to fix Dragoboo's core functionality by replacing the broken CGEventTap modification approach with a reliable IOKit-based system speed control mechanism.