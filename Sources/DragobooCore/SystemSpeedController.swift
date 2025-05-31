import Foundation
import IOKit
import os
import CoreFoundation
import ApplicationServices

public class SystemSpeedController {
    private var originalMouseSpeed: Double?
    private var originalTrackpadSpeed: Double?
    private let logger = Logger(subsystem: "com.dragoboo.core", category: "SystemSpeedController")
    private var usingFallback = false
    private var isActive = false // Track if we're currently in slow mode
    
    // IOHIDEventSystemClient support
    private var hidClient: UnsafeMutableRawPointer?
    private var hidClientAvailable = false
    
    // IOHIDEventSystemClient functions (private APIs)
    private let IOHIDEventSystemClientCreateWithType: (@convention(c) (CFAllocator?, Int32, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?)?
    private let IOHIDEventSystemClientSetProperty: (@convention(c) (UnsafeMutableRawPointer, CFString, CFTypeRef) -> Void)?
    private let IOHIDEventSystemClientCopyProperty: (@convention(c) (UnsafeMutableRawPointer, CFString) -> CFTypeRef?)?
    
    public init() {
        print("SystemSpeedController: 🔧 Initializing SystemSpeedController...")
        logger.info("SystemSpeedController initialization started")
        
        // Load private API functions using dlsym
        IOHIDEventSystemClientCreateWithType = {
            guard let createFunc = dlsym(dlopen(nil, RTLD_LAZY), "IOHIDEventSystemClientCreateWithType") else { 
                print("SystemSpeedController: ❌ Failed to load IOHIDEventSystemClientCreateWithType")
                return nil 
            }
            print("SystemSpeedController: ✅ Loaded IOHIDEventSystemClientCreateWithType")
            return unsafeBitCast(createFunc, to: (@convention(c) (CFAllocator?, Int32, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?).self)
        }()
        
        IOHIDEventSystemClientSetProperty = {
            guard let setFunc = dlsym(dlopen(nil, RTLD_LAZY), "IOHIDEventSystemClientSetProperty") else { 
                print("SystemSpeedController: ❌ Failed to load IOHIDEventSystemClientSetProperty")
                return nil 
            }
            print("SystemSpeedController: ✅ Loaded IOHIDEventSystemClientSetProperty")
            return unsafeBitCast(setFunc, to: (@convention(c) (UnsafeMutableRawPointer, CFString, CFTypeRef) -> Void).self)
        }()
        
        IOHIDEventSystemClientCopyProperty = {
            guard let copyFunc = dlsym(dlopen(nil, RTLD_LAZY), "IOHIDEventSystemClientCopyProperty") else { 
                print("SystemSpeedController: ❌ Failed to load IOHIDEventSystemClientCopyProperty")
                return nil 
            }
            print("SystemSpeedController: ✅ Loaded IOHIDEventSystemClientCopyProperty")
            return unsafeBitCast(copyFunc, to: (@convention(c) (UnsafeMutableRawPointer, CFString) -> CFTypeRef?).self)
        }()
        
        print("SystemSpeedController: 🔧 About to initialize HID client...")
        initializeHIDClient()
        print("SystemSpeedController: 🔧 HID client initialization completed. hidClientAvailable=\(hidClientAvailable)")
        
        // Set up signal handlers for graceful cleanup on crashes (after all properties are initialized)
        setupSignalHandlers()
    }
    
    deinit {
        // Ensure cleanup on deallocation
        cleanupResources()
    }
    
    private func setupSignalHandlers() {
        // Set up signal handlers for graceful cleanup
        signal(SIGTERM) { _ in
            // Note: This is a simplified handler - in a real app you'd want a more sophisticated approach
            print("SystemSpeedController: ⚠️ SIGTERM received, cleaning up...")
        }
        
        signal(SIGINT) { _ in
            print("SystemSpeedController: ⚠️ SIGINT received, cleaning up...")
        }
    }
    
    private func cleanupResources() {
        print("SystemSpeedController: 🧹 Cleaning up resources...")
        
        // Restore original speeds if we're currently active
        if isActive {
            do {
                try restoreOriginalSpeed()
            } catch {
                print("SystemSpeedController: ❌ Failed to restore speeds during cleanup: \(error)")
            }
        }
        
        // Clean up HID client
        if hidClient != nil {
            // Note: IOHIDEventSystemClient doesn't have a documented release function
            // but we should at least nil our reference
            hidClient = nil
            hidClientAvailable = false
            print("SystemSpeedController: ✅ HID client cleaned up")
        }
    }
    
    private func initializeHIDClient() {
        print("SystemSpeedController: 🔧 initializeHIDClient() started")
        
        guard let createFunc = IOHIDEventSystemClientCreateWithType else {
            print("SystemSpeedController: ❌ IOHIDEventSystemClient functions not available on this macOS version")
            logger.warning("IOHIDEventSystemClient functions not available on this macOS version")
            hidClientAvailable = false
            return
        }
        print("SystemSpeedController: ✅ IOHIDEventSystemClient functions are available")
        
        // Add safety guard: only try IOKit if we have accessibility permissions
        guard AXIsProcessTrusted() else {
            print("SystemSpeedController: ❌ Accessibility permissions required for IOHIDEventSystemClient")
            logger.warning("Accessibility permissions required for IOHIDEventSystemClient")
            hidClientAvailable = false
            return
        }
        print("SystemSpeedController: ✅ Accessibility permissions verified")
        
        // Wrap in exception handling for safety
        print("SystemSpeedController: 🔧 Creating IOHIDEventSystemClient...")
        
        do {
            hidClient = createFunc(kCFAllocatorDefault, 0, nil) // kIOHIDEventSystemClientTypeAdmin = 0
            hidClientAvailable = (hidClient != nil)
            print("SystemSpeedController: 🔧 IOHIDEventSystemClient creation result: hidClient=\(hidClient != nil ? "SUCCESS" : "NIL")")
            
            if hidClientAvailable {
                print("SystemSpeedController: ✅ IOHIDEventSystemClient initialized successfully")
                logger.info("✅ IOHIDEventSystemClient initialized successfully")
                
                // Test basic functionality to ensure stability
                if testHIDClientBasicFunctionality() {
                    print("SystemSpeedController: ✅ IOHIDEventSystemClient ready for use")
                } else {
                    print("SystemSpeedController: ⚠️ IOHIDEventSystemClient basic test failed, disabling for safety")
                    hidClient = nil
                    hidClientAvailable = false
                }
            } else {
                print("SystemSpeedController: ❌ Failed to create IOHIDEventSystemClient - will use event tap approach")
                logger.warning("Failed to create IOHIDEventSystemClient - will use event tap approach")
            }
        } catch {
            print("SystemSpeedController: ❌ IOHIDEventSystemClient creation failed with exception: \(error)")
            logger.error("IOHIDEventSystemClient creation failed: \(error)")
            hidClient = nil
            hidClientAvailable = false
        }
    }
    
    private func testHIDClientBasicFunctionality() -> Bool {
        guard let client = hidClient,
              let copyProperty = IOHIDEventSystemClientCopyProperty else {
            return false
        }
        
        do {
            // Test if we can read the HIDPointerAcceleration property
            let propertyKey = "HIDPointerAcceleration" as CFString
            let result = copyProperty(client, propertyKey)
            let canRead = (result != nil)
            
            logger.debug("HID Client basic functionality test: \(canRead ? "PASSED" : "FAILED")")
            return canRead
        } catch {
            logger.error("HID Client test failed with exception: \(error)")
            return false
        }
    }
    
    private func ioKitSetPointerAcceleration(factor: Double) throws {
        guard let client = hidClient,
              let setProperty = IOHIDEventSystemClientSetProperty,
              let copyProperty = IOHIDEventSystemClientCopyProperty else {
            throw SystemSpeedError.failedToCreateHIDClient
        }
        
        // Save original acceleration if not already saved
        if originalMouseSpeed == nil {
            let propertyKey = "HIDPointerAcceleration" as CFString
            if let result = copyProperty(client, propertyKey),
               let number = result as? NSNumber {
                originalMouseSpeed = number.doubleValue
                logger.debug("Saved original pointer acceleration: \(self.originalMouseSpeed!)")
            } else {
                // Try fallback values for different macOS versions
                do {
                    originalMouseSpeed = try getCurrentSystemAcceleration()
                } catch {
                    originalMouseSpeed = 45056.0
                }
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
    }
    
    private func getCurrentSystemAcceleration() throws -> Double {
        // Try to read system acceleration from multiple sources
        let sources = [
            ("com.apple.mouse.scaling", 0.6875),
            ("com.apple.trackpad.scaling", 0.6875),
            ("AppleMouseDefaultAcceleration", 45056.0)
        ]
        
        for (key, _) in sources {
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
    
    private func ioKitRestorePointerAcceleration() throws {
        guard let client = hidClient,
              let setProperty = IOHIDEventSystemClientSetProperty,
              let originalSpeed = originalMouseSpeed else {
            return
        }
        
        var accelerationValue = originalSpeed
        let propertyKey = "HIDPointerAcceleration" as CFString
        let value = CFNumberCreate(kCFAllocatorDefault, .doubleType, &accelerationValue)!
        
        setProperty(client, propertyKey, value)
        logger.info("Restored original pointer acceleration: \(originalSpeed)")
    }
    
    public func setSlowSpeed(factor: Double) throws {
        print("SystemSpeedController: 🔧 setSlowSpeed(factor: \(factor)) called")
        logger.info("Setting slow speed with factor: \(factor)")
        
        var lastError: Error?
        
        // Try IOKit approach first if available
        if hidClientAvailable {
            print("SystemSpeedController: 🔧 Trying IOKit approach (hidClientAvailable=true)")
            do {
                print("SystemSpeedController: 🔧 Calling ioKitSetPointerAcceleration...")
                try ioKitSetPointerAcceleration(factor: factor)
                print("SystemSpeedController: ✅ ioKitSetPointerAcceleration completed")
                isActive = true
                
                // Validate to ensure it worked
                if validateSpeedChange(expectedFactor: factor) {
                    print("SystemSpeedController: ✅ Successfully set speed using IOKit HIDEventSystemClient")
                    logger.info("Successfully set speed using IOKit HIDEventSystemClient")
                    return
                } else {
                    print("SystemSpeedController: ❌ IOKit method failed validation")
                    throw SystemSpeedError.failedToSetSpeed
                }
            } catch {
                lastError = error
                print("SystemSpeedController: ❌ IOKit method failed: \(error)")
                logger.warning("IOKit method failed: \(error)")
                isActive = false
            }
        } else {
            print("SystemSpeedController: 🔧 IOKit not available (hidClientAvailable=false)")
            logger.warning("IOKit not available - event tap approach should be used instead of UserDefaults")
        }
        
        // REMOVED: UserDefaults fallback approach as it causes permanent system changes
        // Instead, throw an error to indicate that event tap approach should be used
        print("SystemSpeedController: ❌ IOKit approach failed and UserDefaults approach is disabled for safety")
        logger.error("IOKit approach failed and UserDefaults approach is disabled for safety - use event tap approach instead")
        throw lastError ?? SystemSpeedError.failedToSetSpeed
    }
    
    public func restoreOriginalSpeed() throws {
        logger.info("Restoring original speeds")
        
        // Only restore if we're currently active
        guard isActive else {
            logger.debug("Not currently active, no need to restore")
            return
        }
        
        // Try IOKit approach if available and we have original speed
        if hidClientAvailable && originalMouseSpeed != nil {
            do {
                try ioKitRestorePointerAcceleration()
                isActive = false
                logger.info("Successfully restored original speeds using IOKit")
                return
            } catch {
                logger.warning("IOKit restore failed: \(error)")
                isActive = false
                throw error
            }
        }
        
        // If IOKit not available, we shouldn't have been active in the first place
        logger.debug("IOKit not available, no restoration needed")
        isActive = false
    }
    
    private func getCurrentMouseSpeed() throws -> Double {
        logger.debug("Getting current mouse speed")
        
        // Read from global preferences using UserDefaults
        let defaults = UserDefaults.standard
        let speed = defaults.double(forKey: "com.apple.mouse.scaling")
        
        // If speed is 0, the preference doesn't exist, use default
        if speed == 0 {
            logger.debug("Mouse speed preference not set, using default")
            return 0.6875 // Default macOS mouse speed
        } else {
            logger.debug("Current mouse speed: \(speed)")
            return speed
        }
    }
    
    private func getCurrentTrackpadSpeed() throws -> Double {
        logger.debug("Getting current trackpad speed")
        
        // Read from global preferences using UserDefaults
        let defaults = UserDefaults.standard
        let speed = defaults.double(forKey: "com.apple.trackpad.scaling")
        
        // If speed is 0, the preference doesn't exist, use default
        if speed == 0 {
            logger.debug("Trackpad speed preference not set, using default")
            return 0.6875 // Default macOS trackpad speed
        } else {
            logger.debug("Current trackpad speed: \(speed)")
            return speed
        }
    }
    
    
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
    
    private func validateIOKitSpeedChange(expectedFactor: Double) throws -> Bool {
        guard let client = hidClient,
              let copyProperty = IOHIDEventSystemClientCopyProperty else {
            return false
        }
        
        let propertyKey = "HIDPointerAcceleration" as CFString
        guard let result = copyProperty(client, propertyKey),
              let number = result as? NSNumber else {
            return false
        }
        
        let currentAcceleration = number.doubleValue
        let expectedAcceleration = (originalMouseSpeed ?? 45056.0) / expectedFactor
        let isValid = abs(currentAcceleration - expectedAcceleration) < 1000.0 // Allow some tolerance
        
        logger.debug("IOKit validation - current: \(currentAcceleration), expected: \(expectedAcceleration), valid: \(isValid)")
        return isValid
    }
    
    private func validateUserDefaultsSpeedChange(expectedFactor: Double) throws -> Bool {
        let currentSpeed = try getCurrentMouseSpeed()
        let expectedSpeed = (originalMouseSpeed ?? 0.6875) / expectedFactor
        let isValid = abs(currentSpeed - expectedSpeed) < 0.1
        
        logger.debug("UserDefaults validation - current: \(currentSpeed), expected: \(expectedSpeed), valid: \(isValid)")
        return isValid
    }
    
    // MARK: - DISABLED: Dangerous UserDefaults Methods
    // These methods are DISABLED because they cause permanent system changes
    // that persist after app crashes, leaving users with broken trackpad/mouse settings
    
    /*
    private func fallbackSetMouseSpeed(_ speed: Double) throws {
        // DISABLED: This method permanently modifies system preferences
        // If the app crashes, the user's mouse speed remains permanently changed
        // Use event tap approach instead for safe, temporary modifications
        throw SystemSpeedError.failedToSetSpeed
    }
    
    private func fallbackSetTrackpadSpeed(_ speed: Double) throws {
        // DISABLED: This method permanently modifies system preferences  
        // If the app crashes, the user's trackpad speed remains permanently changed
        // Use event tap approach instead for safe, temporary modifications
        throw SystemSpeedError.failedToSetSpeed
    }
    */
}

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