# Dragoboo Fix Plan: Re-enable IOKit Pointer Control

## Problem Analysis (UPDATED - Root Cause Identified)

**Current State:** Dragoboo has working UI, accessibility permissions, and perfect `fn` key detection. The SystemSpeedController is being called correctly, but **the IOKit functionality is intentionally DISABLED**.

**Root Cause Found:** 
```swift
// TEMPORARILY DISABLE IOKit approach to prevent crashes  
// TODO: Re-enable with proper safety guards after fixing fn key detection
logger.warning("IOHIDEventSystemClient temporarily disabled - using UserDefaults fallback only")
hidClientAvailable = false
```

**Evidence from Console Logs:**
- ✅ fn key detection: `🎯 FN key state changed` 
- ✅ Precision mode activation: `🚀 ACTIVATING precision mode with factor 4.000000`
- ✅ SystemSpeedController called: Functions are executing
- ❌ Speed validation: `System speed validation: <private>` (likely INVALID)
- ❌ No immediate effect: UserDefaults approach requires logout/restart

**Current Flow:**
1. fn key pressed → ✅ detected correctly
2. `systemSpeedController.setSlowSpeed()` called → ✅ executes  
3. IOKit disabled → ❌ falls back to UserDefaults
4. UserDefaults sets preferences → ✅ but no immediate effect
5. Validation fails → ❌ no actual speed change

## Solution Strategy: Re-enable IOKit with Safety Guards

### Phase 1: Immediate Fix - Re-enable IOKit (PRIORITY 1)

**Objective:** Remove the artificial disable and implement proper safety guards for IOHIDEventSystemClient.

#### Step 1.1: Remove Disable Block and Add Safety Guards

Modify `SystemSpeedController.swift` lines 53-70:

```swift
private func initializeHIDClient() {
    guard let createFunc = IOHIDEventSystemClientCreateWithType else {
        logger.warning("IOHIDEventSystemClient functions not available on this macOS version")
        hidClientAvailable = false
        return
    }
    
    // Add safety guard: only try IOKit if we have accessibility permissions
    guard AXIsProcessTrusted() else {
        logger.warning("Accessibility permissions required for IOHIDEventSystemClient")
        hidClientAvailable = false
        return
    }
    
    do {
        // Wrap in exception handling to prevent crashes
    hidClient = createFunc(kCFAllocatorDefault, 0, nil) // kIOHIDEventSystemClientTypeAdmin = 0
    hidClientAvailable = (hidClient != nil)
    
    if hidClientAvailable {
            logger.info("✅ IOHIDEventSystemClient initialized successfully")
            
            // Test basic functionality immediately
            if !testHIDClientBasicFunctionality() {
                logger.warning("IOHIDEventSystemClient basic test failed, disabling")
                hidClient = nil
                hidClientAvailable = false
            }
    } else {
        logger.warning("Failed to create IOHIDEventSystemClient - falling back to UserDefaults")
    }
    } catch {
        logger.error("IOHIDEventSystemClient initialization crashed: \(error)")
        hidClient = nil
        hidClientAvailable = false
    }
}

private func testHIDClientBasicFunctionality() -> Bool {
    guard let client = hidClient,
          let copyProperty = IOHIDEventSystemClientCopyProperty else {
        return false
    }
    
    // Test if we can read the HIDPointerAcceleration property
    let propertyKey = "HIDPointerAcceleration" as CFString
    let result = copyProperty(client, propertyKey)
    let canRead = (result != nil)
    
    logger.debug("HID Client basic functionality test: \(canRead ? "PASSED" : "FAILED")")
    return canRead
}
```

#### Step 1.2: Add Crash Protection to IOKit Methods

Wrap the IOKit calls in proper exception handling:

```swift
private func ioKitSetPointerAcceleration(factor: Double) throws {
    guard let client = hidClient,
          let setProperty = IOHIDEventSystemClientSetProperty,
          let copyProperty = IOHIDEventSystemClientCopyProperty else {
        throw SystemSpeedError.failedToCreateHIDClient
    }
    
    do {
    // Save original acceleration if not already saved
    if originalMouseSpeed == nil {
        let propertyKey = "HIDPointerAcceleration" as CFString
        if let result = copyProperty(client, propertyKey),
           let number = result as? NSNumber {
            originalMouseSpeed = number.doubleValue
                logger.debug("Saved original pointer acceleration: \(self.originalMouseSpeed!)")
        } else {
                // Try fallback values for different macOS versions
                originalMouseSpeed = try? getCurrentSystemAcceleration() ?? 45056.0
                logger.debug("Using fallback original acceleration: \(self.originalMouseSpeed!)")
        }
    }
    
    // Calculate new acceleration value
    let newAcceleration = (originalMouseSpeed ?? 45056.0) / factor
    var accelerationValue = newAcceleration
    
        // Set the new acceleration with bounds checking
        if newAcceleration < 1.0 || newAcceleration > 100000.0 {
            logger.warning("Calculated acceleration out of bounds: \(newAcceleration), clamping")
            accelerationValue = max(1.0, min(100000.0, newAcceleration))
        }
        
    let propertyKey = "HIDPointerAcceleration" as CFString
    let value = CFNumberCreate(kCFAllocatorDefault, .doubleType, &accelerationValue)!
    
    setProperty(client, propertyKey, value)
        logger.info("✅ Set pointer acceleration to \(accelerationValue) (factor: \(factor))")
        
    } catch {
        logger.error("IOKit acceleration setting failed: \(error)")
        throw SystemSpeedError.failedToSetSpeed
    }
}

private func getCurrentSystemAcceleration() throws -> Double {
    // Try to read system acceleration from multiple sources
    let sources = [
        ("com.apple.mouse.scaling", 0.6875),
        ("com.apple.trackpad.scaling", 0.6875),
        ("AppleMouseDefaultAcceleration", 45056.0)
    ]
    
    for (key, defaultValue) in sources {
        let value = CFPreferencesCopyValue(
            key as CFString,
        kCFPreferencesAnyApplication,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    )
    
        if let number = value as? NSNumber {
            return number.doubleValue
        }
    }
    
    return 45056.0 // Ultimate fallback
}
```

#### Step 1.3: Enhanced Validation with Real-Time Testing

```swift
public func validateSpeedChange(expectedFactor: Double) -> Bool {
    logger.debug("Validating speed change with expected factor: \(expectedFactor)")
    
    // Small delay to allow system to process changes
    usleep(100000) // 100ms - longer delay for more reliable validation
    
    do {
        if hidClientAvailable {
            // Validate IOKit approach with multiple attempts
            for attempt in 1...3 {
                if try validateIOKitSpeedChange(expectedFactor: expectedFactor) {
                    logger.debug("IOKit validation passed on attempt \(attempt)")
                    return true
                }
                if attempt < 3 {
                    usleep(50000) // 50ms between attempts
                }
            }
            logger.warning("IOKit validation failed after 3 attempts")
            return false
        } else {
            // Validate UserDefaults approach
            return try validateUserDefaultsSpeedChange(expectedFactor: expectedFactor)
        }
    } catch {
        logger.error("Speed validation failed: \(error)")
        return false
    }
}
```

### Phase 2: Immediate Testing Plan

1. **Remove the disable block** from lines 53-56
2. **Add safety guards** for accessibility permissions and basic functionality
3. **Test fn key → cursor speed change** immediately 
4. **Check logs** to confirm IOKit initialization and validation success

### Phase 3: Fallback Enhancement (if IOKit still fails)

If IOKit approach fails due to macOS version restrictions:

1. **Enhance UserDefaults approach** with immediate system notification methods
2. **Try alternative APIs** like `CGSSetCursorScale` or `CGSSetMouseAcceleration`
3. **Implement hybrid approach** with multiple system notification methods

## Expected Immediate Result

After removing the disable block and adding safety guards:

✅ **fn key held** → `hidClientAvailable = true` → IOKit sets acceleration → cursor visibly slows  
✅ **fn key released** → IOKit restores acceleration → cursor returns to normal  
✅ **Validation passes** → logs show "VALID" speed validation  
✅ **No crashes** → proper exception handling prevents app crashes  

## Success Criteria (Updated)

1. **IOKit re-enabled safely** - no artificial disabling
2. **Speed change works immediately** - no logout/restart required  
3. **Validation passes** - logs show successful speed validation
4. **Crash protection** - app handles IOKit failures gracefully
5. **Clear logging** - easy to see which method worked and why

The solution is much simpler than originally thought - we just need to **remove the artificial disable** and add proper safety guards to the existing IOKit implementation.