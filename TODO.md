# TODO.md - Dragoboo Overhaul Plan

## 🚨 CRITICAL ISSUES IDENTIFIED

The app isn't working because of fundamental errors in how mouse events are being modified:

1. **WRONG FIELD TYPE**: Using `getDoubleValueField`/`setDoubleValueField` for mouse deltas, but they are **INTEGER** fields
2. **MISSING FIELDS**: Not setting unaccelerated delta fields (required on macOS Ventura+)
3. **BROKEN FN KEY LOGIC**: Toggle logic is incorrect - it flips state on every event
4. **INCOMPLETE EVENT MODIFICATION**: Not zeroing mouseEventInstantMouser field

## Phase 1: Fix Critical Event Handling Issues 🔴 URGENT

### 1.1 Fix Mouse Delta Field Types
**File:** `Sources/DragobooCore/PointerScaler.swift`

Replace in `scaleMouseMovement`:
```swift
// ❌ WRONG - These are NOT double fields!
let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
let deltaY = event.getDoubleValueField(.mouseEventDeltaY)

// ✅ CORRECT - Use integer fields
let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
let deltaY = event.getIntegerValueField(.mouseEventDeltaY)
```

And for setting:
```swift
// ❌ WRONG
event.setDoubleValueField(.mouseEventDeltaX, value: scaledDeltaX)
event.setDoubleValueField(.mouseEventDeltaY, value: scaledDeltaY)

// ✅ CORRECT
let scaledDeltaX = Int64(Double(deltaX) / precisionFactor)
let scaledDeltaY = Int64(Double(deltaY) / precisionFactor)
event.setIntegerValueField(.mouseEventDeltaX, value: scaledDeltaX)
event.setIntegerValueField(.mouseEventDeltaY, value: scaledDeltaY)
```

### 1.2 Add Required Unaccelerated Delta Fields
**Critical for macOS Ventura/Sonoma compatibility!**

After setting the regular deltas, add:
```swift
// Reset instant mouser to prevent WindowServer corrections
event.setIntegerValueField(.mouseEventInstantMouser, value: 0)

// Set unaccelerated deltas (REQUIRED on modern macOS)
event.setIntegerValueField(.mouseEventUnacceleratedDeltaX, value: scaledDeltaX)
event.setIntegerValueField(.mouseEventUnacceleratedDeltaY, value: scaledDeltaY)
```

### 1.3 Fix Scroll Wheel Fields
Same issue - scroll wheel deltas might also be integers:
```swift
// Check if these should be integer fields too
let deltaAxis1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
let deltaAxis2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
```

## Phase 2: Fix Fn Key Detection Logic 🟡 HIGH PRIORITY

### 2.1 Remove Broken Toggle Logic
**File:** `Sources/DragobooCore/PointerScaler.swift`

Replace in `handleFlagsChanged`:
```swift
// ❌ WRONG - Toggles on every event!
if keyCode == 63 {
    fnKeyPressed = !fnKeyPressed  
    onPrecisionModeChange?(fnKeyPressed)
    return
}

// ✅ CORRECT - Check actual flag state
if keyCode == 63 {
    fnKeyPressed = event.flags.contains(.maskSecondaryFn)
    onPrecisionModeChange?(fnKeyPressed)
    return
}
```

### 2.2 Remove Redundant Key Polling
Remove the OR condition with `CGEventSource.keyState`:
```swift
// ❌ WRONG - Can cause race conditions
let fnDown = flags.contains(.maskSecondaryFn) || CGEventSource.keyState(.combinedSessionState, key: 0x3F)

// ✅ CORRECT - Trust the event flags
fnKeyPressed = event.flags.contains(.maskSecondaryFn)
```

### 2.3 Simplify updateFnKeyState
Since we're trusting event flags, simplify or remove `updateFnKeyState()` polling.

## Phase 3: Verify Event Tap Configuration 🟢 IMPORTANT

### 3.1 Confirm Tap Location
Ensure using `.cgSessionEventTap` (not `.cgHIDEventTap`):
```swift
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,  // ✅ Correct - allows modification
    place: .headInsertEventTap,
    options: .defaultTap,     // ✅ NOT .listenOnly
    eventsOfInterest: eventMask,
    callback: eventCallback,
    userInfo: selfPointer
)
```

### 3.2 Verify Event Mask
Confirm all needed events are in the mask:
```swift
let eventMask: CGEventMask = 
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.leftMouseDragged.rawValue) |
    (1 << CGEventType.rightMouseDragged.rawValue) |
    (1 << CGEventType.otherMouseDragged.rawValue) |
    (1 << CGEventType.scrollWheel.rawValue) |
    (1 << CGEventType.flagsChanged.rawValue)  // ✅ Critical for fn key
```

## Phase 4: Complete Function Implementation 🔵 MEDIUM PRIORITY

### 4.1 Fix Missing Return Statement
Ensure `scaleMouseMovement` returns properly:
```swift
private func scaleMouseMovement(event: CGEvent) -> Bool {
    // ... scaling logic ...
    return scalingWorked  // ✅ Must return
}
```

### 4.2 Return Modified Events Correctly
In the callback, ensure returning the modified event:
```swift
return Unmanaged.passUnretained(event)  // ✅ Return the SAME modified event
```

## Phase 5: Enhanced Debugging 🟣 HELPFUL

### 5.1 Add Detailed Logging
```swift
logger.debug("Pre-scale deltas: X=\(deltaX), Y=\(deltaY)")
logger.debug("Post-scale deltas: X=\(scaledDeltaX), Y=\(scaledDeltaY)")
logger.debug("Verification: X=\(verifyX), Y=\(verifyY)")
logger.debug("Field types used: INTEGER")
```

### 5.2 Test with Simple Values
Test with known values to verify scaling:
```swift
// Temporary test: Always scale by 0.5 when fn pressed
let testScaledX = deltaX / 2
let testScaledY = deltaY / 2
```

## Phase 6: System Compatibility Checks ⚪ GOOD PRACTICE

### 6.1 Check macOS Version
Add version-specific handling if needed:
```swift
if #available(macOS 13.0, *) {
    // Set unaccelerated deltas
}
```

### 6.2 Verify No Conflicting Software
- Check for other mouse utilities
- Verify no secure input mode active
- Test with fresh user account

## Implementation Order

1. **START HERE** → Fix integer/double field types (Phase 1.1)
2. Add unaccelerated delta fields (Phase 1.2)
3. Fix fn key detection logic (Phase 2.1-2.2)
4. Test basic functionality
5. Fix remaining issues if any
6. Add enhanced debugging
7. Clean up code and remove debug prints

## Quick Test Plan

After each fix:
1. Build and run the app
2. Grant accessibility permissions
3. Open TextEdit or any text field
4. Move mouse normally → Should be normal speed
5. Hold fn key and move mouse → Should be SLOW
6. Check Console.app for debug output

## Expected Outcome

With these fixes, holding the fn key should immediately slow down cursor movement by the configured factor (default 4x slower).

## Code Reference

Here's the corrected `scaleMouseMovement` function:

```swift
private func scaleMouseMovement(event: CGEvent) -> Bool {
    // Get INTEGER delta values (not double!)
    let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
    let deltaY = event.getIntegerValueField(.mouseEventDeltaY)
    
    guard deltaX != 0 || deltaY != 0 else {
        logger.debug("No movement to scale")
        return false
    }
    
    logger.debug("Original deltas: X=\(deltaX), Y=\(deltaY)")
    
    // Scale as integers
    let scaledDeltaX = Int64(Double(deltaX) / precisionFactor)
    let scaledDeltaY = Int64(Double(deltaY) / precisionFactor)
    
    // Set all required fields
    event.setIntegerValueField(.mouseEventDeltaX, value: scaledDeltaX)
    event.setIntegerValueField(.mouseEventDeltaY, value: scaledDeltaY)
    event.setIntegerValueField(.mouseEventInstantMouser, value: 0)
    event.setIntegerValueField(.mouseEventUnacceleratedDeltaX, value: scaledDeltaX)
    event.setIntegerValueField(.mouseEventUnacceleratedDeltaY, value: scaledDeltaY)
    
    // Verify
    let verifyX = event.getIntegerValueField(.mouseEventDeltaX)
    let verifyY = event.getIntegerValueField(.mouseEventDeltaY)
    logger.debug("Scaled deltas: X=\(scaledDeltaX)->verified:\(verifyX), Y=\(scaledDeltaY)->verified:\(verifyY)")
    
    return true
}
```