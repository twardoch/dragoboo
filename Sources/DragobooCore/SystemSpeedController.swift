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
    }
    
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
        
        // Wrap in try-catch for safety, though createFunc shouldn't throw
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
        logger.info("Setting slow speed with factor: \(factor)")
        
        var lastError: Error?
        
        // Try IOKit approach first if available
        if hidClientAvailable {
            do {
                try ioKitSetPointerAcceleration(factor: factor)
                
                // Validate the change worked
                if validateSpeedChange(expectedFactor: factor) {
                    logger.info("Successfully set speed using IOKit HIDEventSystemClient")
                    return
                } else {
                    logger.warning("IOKit method failed validation, trying fallback")
                }
            } catch {
                lastError = error
                logger.warning("IOKit method failed: \(error)")
            }
        }
        
        // Fallback to UserDefaults approach
        do {
            // Save original speeds if not already saved
            if originalMouseSpeed == nil {
                originalMouseSpeed = try getCurrentMouseSpeed()
                logger.debug("Saved original mouse speed: \(self.originalMouseSpeed ?? 0)")
            }
            if originalTrackpadSpeed == nil {
                originalTrackpadSpeed = try getCurrentTrackpadSpeed()
                logger.debug("Saved original trackpad speed: \(self.originalTrackpadSpeed ?? 0)")
            }
            
            let slowMouseSpeed = (originalMouseSpeed ?? 0.6875) / factor
            let slowTrackpadSpeed = (originalTrackpadSpeed ?? 0.6875) / factor
            
            try fallbackSetMouseSpeed(slowMouseSpeed)
            try fallbackSetTrackpadSpeed(slowTrackpadSpeed)
            
            // Validate the change worked
            if validateSpeedChange(expectedFactor: factor) {
                usingFallback = true
                logger.info("Successfully set speed using UserDefaults fallback")
                return
            } else {
                logger.error("UserDefaults method failed validation")
            }
        } catch {
            lastError = error
            logger.error("UserDefaults fallback failed: \(error)")
        }
        
        // Both methods failed
        throw lastError ?? SystemSpeedError.failedToSetSpeed
    }
    
    public func restoreOriginalSpeed() throws {
        logger.info("Restoring original speeds")
        
        // Try IOKit approach first if available and we have original speed
        if hidClientAvailable && originalMouseSpeed != nil {
            do {
                try ioKitRestorePointerAcceleration()
                logger.info("Successfully restored original speeds using IOKit")
                return
            } catch {
                logger.warning("IOKit restore failed: \(error), trying fallback")
            }
        }
        
        // Fallback to UserDefaults approach
        guard let mouseSpeed = originalMouseSpeed,
              let trackpadSpeed = originalTrackpadSpeed else {
            logger.debug("No original speeds to restore")
            return // Nothing to restore
        }
        
        try fallbackSetMouseSpeed(mouseSpeed)
        try fallbackSetTrackpadSpeed(trackpadSpeed)
        logger.info("Successfully restored original speeds using UserDefaults fallback")
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
    
    // MARK: - Fallback Methods using UserDefaults
    
    private func fallbackSetMouseSpeed(_ speed: Double) throws {
        logger.debug("Setting mouse speed using enhanced UserDefaults fallback: \(speed)")
        
        // Set in global preferences domain using the correct approach
        CFPreferencesSetValue(
            "com.apple.mouse.scaling" as CFString,
            speed as CFNumber,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        // Also disable acceleration for predictable behavior
        CFPreferencesSetValue(
            "com.apple.mouse.acceleration" as CFString,
            (-1.0) as CFNumber, // -1 disables acceleration
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        // Multiple synchronization attempts
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        
        // Post multiple HID system notifications
        let notifications = [
            "com.apple.hid.preferencesChanged",
            "com.apple.systempreferences.mousesettings.changed",
            "com.apple.controlstrip.mousesettings.changed",
            "com.apple.preference.mouse.changed"
        ]
        
        for notification in notifications {
            DistributedNotificationCenter.default().post(
                name: NSNotification.Name(notification),
                object: nil
            )
        }
        
        logger.debug("Applied enhanced UserDefaults mouse speed setting")
    }
    
    private func fallbackSetTrackpadSpeed(_ speed: Double) throws {
        logger.debug("Setting trackpad speed using enhanced UserDefaults fallback: \(speed)")
        
        // Set in global preferences domain using the correct approach
        CFPreferencesSetValue(
            "com.apple.trackpad.scaling" as CFString,
            speed as CFNumber,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        // Also disable acceleration for predictable behavior
        CFPreferencesSetValue(
            "com.apple.trackpad.acceleration" as CFString,
            (-1.0) as CFNumber, // -1 disables acceleration
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        // Multiple synchronization attempts
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        
        // Post multiple HID system notifications
        let notifications = [
            "com.apple.hid.preferencesChanged",
            "com.apple.systempreferences.trackpadsettings.changed",
            "com.apple.controlstrip.trackpadsettings.changed",
            "com.apple.preference.trackpad.changed"
        ]
        
        for notification in notifications {
            DistributedNotificationCenter.default().post(
                name: NSNotification.Name(notification),
                object: nil
            )
        }
        
        logger.debug("Applied enhanced UserDefaults trackpad speed setting")
    }
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