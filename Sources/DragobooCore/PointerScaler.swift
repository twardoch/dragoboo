import Foundation
import CoreGraphics
import ApplicationServices
import os
import Dispatch
import Carbon

public class PointerScaler {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var precisionFactor: Double
    private var fnKeyPressed = false
    private var isInPrecisionMode = false
    private let logger = Logger(subsystem: "com.dragoboo.core", category: "PointerScaler")
    private var debugTimer: Timer?
    private var systemSpeedController: SystemSpeedController
    
    public var onPrecisionModeChange: ((Bool) -> Void)?
    
    private static let fnKeyCode: CGKeyCode = 0x3F
    
    public init(precisionFactor: Double) {
        self.precisionFactor = precisionFactor
        self.systemSpeedController = SystemSpeedController()
    }
    
    private func addDiagnostics() {
        // Verify tap is actually enabled
        if let tap = eventTap {
            let isEnabled = CGEvent.tapIsEnabled(tap: tap)
            logger.debug("Event tap enabled status: \(isEnabled)")
        }
        
        // Log secure input status
        let secureInput = IsSecureEventInputEnabled()
        logger.debug("Secure input mode: \(secureInput)")
        
        // Test key state detection
        let fnState = CGEventSource.keyState(.combinedSessionState, key: 0x3F)
        logger.debug("FN key polling state: \(fnState)")
    }
    
    public func start() throws {
        print("PointerScaler: Starting pointer scaler...")
        logger.info("Starting pointer scaler...")
        
        // Reset state on start
        fnKeyPressed = false
        isInPrecisionMode = false
        
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            print("PointerScaler: Accessibility permissions not granted")
            logger.error("Accessibility permissions not granted")
            throw PointerScalerError.failedToCreateEventTap
        }
        print("PointerScaler: Accessibility permissions verified")
        logger.info("Accessibility permissions verified")
        
        // Check for secure input mode which can block event modifications
        checkSecureInputMode()
        
        // Only listen for flags changed events (for fn key detection) and tap management events
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                     (1 << CGEventType.tapDisabledByTimeout.rawValue) |
                                     (1 << CGEventType.tapDisabledByUserInput.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Use the main run loop for event tap to ensure proper event capture
        let mainRunLoop = CFRunLoopGetMain()
        
        // Create event tap for fn key detection only
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo = userInfo else { 
                    Logger(subsystem: "com.dragoboo.core", category: "PointerScaler").error("Event callback received nil userInfo")
                    return Unmanaged.passUnretained(event) 
                }
                let scaler = Unmanaged<PointerScaler>.fromOpaque(userInfo).takeUnretainedValue()
                return scaler.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            logger.error("Event tap FAILED ❌ – likely permission or SecureInput.")
            throw PointerScalerError.failedToCreateEventTap
        }
        
        eventTap = tap
        
        logger.info("Event tap created for fn key detection")
        
        // Create run loop source and add to main run loop
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap!, 0) else {
            logger.error("Failed to create run loop source")
            CGEvent.tapEnable(tap: eventTap!, enable: false)
            CFMachPortInvalidate(eventTap!)
            throw PointerScalerError.failedToCreateEventTap
        }
        
        runLoopSource = source
        
        // Add source to main run loop (critical fix)
        CFRunLoopAddSource(mainRunLoop, source, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap!, enable: true)
        
        print("PointerScaler: Event tap enabled successfully")
        logger.info("Event tap enabled successfully")
        
        // Run diagnostics after successful setup
        addDiagnostics()
        
        // Start debug timer
        startDebugTimer()
    }
    
    public func stop() {
        debugTimer?.invalidate()
        debugTimer = nil
        
        // Restore original system speeds if in precision mode
        if isInPrecisionMode {
            do {
                try systemSpeedController.restoreOriginalSpeed()
                isInPrecisionMode = false
                logger.info("Restored original system speeds on stop")
            } catch {
                logger.error("Failed to restore original speeds on stop: \(error)")
            }
        }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        logger.info("Event tap stopped")
    }
    
    public func updatePrecisionFactor(_ factor: Double) {
        precisionFactor = factor
        logger.info("Updated precision factor to \(factor)")
    }
    
    private func checkSecureInputMode() {
        // Check if secure input mode is active, which can block event modifications
        if IsSecureEventInputEnabled() {
            logger.warning("Secure input mode is active. This may prevent event modifications from working.")
        } else {
            logger.info("Secure input mode is not active")
        }
    }
    
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
            // Ignore all other events - we only care about fn key detection
            break
        }
        
        // Always pass events through unmodified - we don't modify any events
        return Unmanaged.passUnretained(event)
    }
    
    private func debugEventType(_ type: CGEventType) -> String {
        switch type {
        case .null: return "null"
        case .leftMouseDown: return "leftMouseDown"
        case .leftMouseUp: return "leftMouseUp"
        case .rightMouseDown: return "rightMouseDown"
        case .rightMouseUp: return "rightMouseUp"
        case .mouseMoved: return "mouseMoved"
        case .leftMouseDragged: return "leftMouseDragged"
        case .rightMouseDragged: return "rightMouseDragged"
        case .keyDown: return "keyDown"
        case .keyUp: return "keyUp"
        case .flagsChanged: return "flagsChanged"
        case .scrollWheel: return "scrollWheel"
        case .tabletPointer: return "tabletPointer"
        case .tabletProximity: return "tabletProximity"
        case .otherMouseDown: return "otherMouseDown"
        case .otherMouseUp: return "otherMouseUp"
        case .otherMouseDragged: return "otherMouseDragged"
        case .tapDisabledByTimeout: return "tapDisabledByTimeout"
        case .tapDisabledByUserInput: return "tapDisabledByUserInput"
        default: return "unknown(\(type.rawValue))"
        }
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        logger.info("🔍 FlagsChanged event: keyCode=\(keyCode), flags=\(flags.rawValue)")
        logger.info("🔍 Current fn state: internal=\(self.fnKeyPressed), flag=\(flags.contains(.maskSecondaryFn))")
        
        // Always use the flag state, regardless of keycode
        let wasFnPressed = fnKeyPressed
        fnKeyPressed = flags.contains(.maskSecondaryFn)
        
        // Only handle state changes
        if wasFnPressed != fnKeyPressed {
            logger.notice("🎯 FN key state changed: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
            print("PointerScaler: 🎯 FN key state changed: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
            handleFnKeyStateChange(isPressed: fnKeyPressed)
        } else {
            logger.debug("FN key state unchanged: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
        }
    }
    
    private func handleFnKeyStateChange(isPressed: Bool) {
        logger.info("🎯 handleFnKeyStateChange called: isPressed=\(isPressed), currentPrecisionMode=\(self.isInPrecisionMode)")
        print("PointerScaler: 🎯 handleFnKeyStateChange: isPressed=\(isPressed), precision=\(self.isInPrecisionMode)")
        
        guard isPressed != isInPrecisionMode else { 
            logger.debug("No state change needed: isPressed=\(isPressed), isInPrecisionMode=\(self.isInPrecisionMode)")
            return 
        }
        
        do {
            if isPressed && !isInPrecisionMode {
                logger.notice("🚀 ACTIVATING precision mode with factor \(self.precisionFactor)")
                print("PointerScaler: 🚀 ACTIVATING precision mode")
                print("PointerScaler: 🔧 About to call systemSpeedController.setSlowSpeed(factor: \(precisionFactor))")
                try systemSpeedController.setSlowSpeed(factor: precisionFactor)
                print("PointerScaler: ✅ systemSpeedController.setSlowSpeed() completed successfully")
                isInPrecisionMode = true
                logger.info("✅ Precision mode activated - system speed slowed by \(self.precisionFactor)x")
            } else if !isPressed && isInPrecisionMode {
                logger.notice("🛑 DEACTIVATING precision mode")
                print("PointerScaler: 🛑 DEACTIVATING precision mode")
                print("PointerScaler: 🔧 About to call systemSpeedController.restoreOriginalSpeed()")
                try systemSpeedController.restoreOriginalSpeed()
                print("PointerScaler: ✅ systemSpeedController.restoreOriginalSpeed() completed successfully")
                isInPrecisionMode = false
                logger.info("✅ Precision mode deactivated - system speed restored")
            }
            
            // Always call the callback to update UI
            DispatchQueue.main.async {
                self.onPrecisionModeChange?(isPressed)
            }
        } catch {
            logger.error("❌ Failed to change system speed: \(error)")
            print("PointerScaler: ❌ Failed to change system speed: \(error)")
            // Still call the callback to update UI with error state
            DispatchQueue.main.async {
                self.onPrecisionModeChange?(isPressed)
            }
        }
    }
    
    
    private func startDebugTimer() {
        debugTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.debugCurrentState()
        }
    }
    
    private func debugCurrentState() {
        let keyState = CGEventSource.keyState(.combinedSessionState, key: Self.fnKeyCode)
        logger.notice("Debug: fn key polling=\(keyState ? "PRESSED" : "RELEASED"), internal=\(self.fnKeyPressed ? "PRESSED" : "RELEASED"), precision mode=\(self.isInPrecisionMode ? "ACTIVE" : "INACTIVE"), factor=\(self.precisionFactor)")
        
        // Check secure input mode periodically
        if IsSecureEventInputEnabled() {
            logger.warning("Secure input mode is active")
        }
        
        // Validate speed change if in precision mode
        if isInPrecisionMode {
            let isValid = systemSpeedController.validateSpeedChange(expectedFactor: precisionFactor)
            logger.notice("System speed validation: \(isValid ? "VALID" : "INVALID")")
        }
    }
}

public enum PointerScalerError: LocalizedError {
    case failedToCreateEventTap
    
    public var errorDescription: String? {
        switch self {
        case .failedToCreateEventTap:
            return "Failed to create event tap. Please ensure accessibility permissions are granted."
        }
    }
}