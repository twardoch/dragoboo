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
    private let logger = Logger(subsystem: "com.dragoboo.core", category: "PointerScaler")
    private var debugTimer: Timer?
    private var eventCount = 0
    private var scaledEventCount = 0
    private var totalEventsReceived = 0
    private var fnEventsReceived = 0
    private var scalingEventsApplied = 0
    
    public var onPrecisionModeChange: ((Bool) -> Void)?
    
    private static let fnKeyCode: CGKeyCode = 0x3F
    
    public init(precisionFactor: Double) {
        self.precisionFactor = precisionFactor
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
        
        let eventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.rightMouseDragged.rawValue) |
                                     (1 << CGEventType.otherMouseDragged.rawValue) |
                                     (1 << CGEventType.scrollWheel.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue) |
                                     (1 << CGEventType.tapDisabledByTimeout.rawValue) |
                                     (1 << CGEventType.tapDisabledByUserInput.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Use the main run loop for event tap to ensure proper event capture
        let mainRunLoop = CFRunLoopGetMain()
        
        // Create event tap with session event tap location
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
        
        logger.debug("Event tap created ✅ at location=\(CGEventTapLocation.cgSessionEventTap.rawValue)")
        
        // Create run loop source and add to main run loop
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            logger.error("Failed to create run loop source")
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            throw PointerScalerError.failedToCreateEventTap
        }
        
        eventTap = tap
        runLoopSource = source
        
        // Add source to main run loop (critical fix)
        CFRunLoopAddSource(mainRunLoop, source, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)
        
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
        // Ensure we're processing events consistently (removed strict main thread check as event taps may run on different threads)
        
        totalEventsReceived += 1
        if totalEventsReceived % 100 == 0 {
            logger.debug("Event stats: total=\(self.totalEventsReceived), fn=\(self.fnEventsReceived), scaled=\(self.scalingEventsApplied)")
        }
        
        self.eventCount += 1
        logger.info("Processing event #\(self.eventCount): \(self.debugEventType(type))")
        
        switch type {
        case .flagsChanged:
            print("PointerScaler: Received flagsChanged event")
            logger.debug("flagsChanged received – flags=\(event.flags.rawValue, privacy: .public)")
            fnEventsReceived += 1
            handleFlagsChanged(event: event)
            
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            print("PointerScaler: Received mouse movement event")
            updateFnKeyState()
            if fnKeyPressed {
                print("PointerScaler: fn key is pressed, scaling mouse movement")
                let wasScaled = scaleMouseMovement(event: event)
                if wasScaled {
                    self.scaledEventCount += 1
                    scalingEventsApplied += 1
                    print("PointerScaler: Applied mouse scaling with fn key pressed (total scaled: \(self.scaledEventCount))")
                    logger.info("Applied mouse scaling with fn key pressed (total scaled: \(self.scaledEventCount))")
                }
            }
            
        case .scrollWheel:
            print("PointerScaler: Received scroll wheel event")
            updateFnKeyState()
            if fnKeyPressed {
                let wasScaled = scaleScrollWheel(event: event)
                if wasScaled {
                    self.scaledEventCount += 1
                    scalingEventsApplied += 1
                    logger.info("Applied scroll scaling with fn key pressed (total scaled: \(self.scaledEventCount))")
                }
            }
            
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            logger.warning("Event tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user input"), attempting to re-enable")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil  // Return nil for these events
            
        default:
            logger.debug("Received other event type: \(type.rawValue)")
            break
        }
        
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
        // Method 1: Check keycode directly (FN key is keycode 63/0x3F)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        logger.debug("FlagsChanged event: keyCode=\(keyCode), flags=\(flags.rawValue)")
        logger.debug("Flags breakdown: cmd=\(flags.contains(.maskCommand)), opt=\(flags.contains(.maskAlternate)), ctrl=\(flags.contains(.maskControl)), shift=\(flags.contains(.maskShift)), fn=\(flags.contains(.maskSecondaryFn))")
        
        if keyCode == 63 {
            fnKeyPressed = !fnKeyPressed  // Toggle state
            logger.notice("FN key toggled via keycode 63: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
            onPrecisionModeChange?(fnKeyPressed)
            return
        }
        
        // Method 2: Enhanced fallback with both flags and polling
        let wasFnPressed = fnKeyPressed
        
        // Use combined detection method
        let fnDown = flags.contains(.maskSecondaryFn) || CGEventSource.keyState(.combinedSessionState, key: 0x3F)
        
        fnKeyPressed = fnDown
        
        if wasFnPressed != fnKeyPressed {
            logger.notice("Fn key state changed via flags/polling: \(self.fnKeyPressed ? "PRESSED" : "RELEASED") (flags=\(flags.contains(.maskSecondaryFn)), polling=\(CGEventSource.keyState(.combinedSessionState, key: 0x3F)))")
            onPrecisionModeChange?(fnKeyPressed)
        }
    }
    
    private func updateFnKeyState() {
        let keyState = CGEventSource.keyState(.combinedSessionState, key: Self.fnKeyCode)
        let wasFnPressed = fnKeyPressed
        
        fnKeyPressed = keyState
        
        if wasFnPressed != fnKeyPressed {
            logger.notice("Fn key state updated via polling: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
            onPrecisionModeChange?(fnKeyPressed)
        }
    }
    
    private func scaleMouseMovement(event: CGEvent) -> Bool {
        // Use the correct field constants as suggested by expert analysis
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)
        
        // Only scale if there's actual movement (non-zero deltas)
        guard deltaX != 0.0 || deltaY != 0.0 else {
            logger.debug("Skipping scaling - no movement deltas")
            return false
        }
        
        logger.debug("Original deltas: X=\(deltaX), Y=\(deltaY), Factor=\(self.precisionFactor)")
        
        let scaledDeltaX = deltaX / precisionFactor
        let scaledDeltaY = deltaY / precisionFactor
        
        // Set the scaled values using the correct field constants
        event.setDoubleValueField(.mouseEventDeltaX, value: scaledDeltaX)
        event.setDoubleValueField(.mouseEventDeltaY, value: scaledDeltaY)
        
        // Verify the values were actually set (critical verification step)
        let verifyX = event.getDoubleValueField(.mouseEventDeltaX)
        let verifyY = event.getDoubleValueField(.mouseEventDeltaY)
        logger.debug("Scaled deltas applied: X=\(verifyX), Y=\(verifyY)")
        
        // Additional verification that the scaling actually took effect
        let scalingWorked = abs(verifyX - scaledDeltaX) < 0.001 && abs(verifyY - scaledDeltaY) < 0.001
        if !scalingWorked {
            logger.error("CRITICAL: Delta scaling failed! Expected X=\(scaledDeltaX), Y=\(scaledDeltaY), but got X=\(verifyX), Y=\(verifyY)")
        } else {
            logger.debug("Delta scaling verified successful")
        }
        
        return scalingWorked
    }
    
    private func scaleScrollWheel(event: CGEvent) -> Bool {
        let deltaAxis1 = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let deltaAxis2 = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        
        // Only scale if there's actual scroll movement (non-zero deltas)
        guard deltaAxis1 != 0.0 || deltaAxis2 != 0.0 else {
            return false
        }
        
        let scaledDelta1 = deltaAxis1 / precisionFactor
        let scaledDelta2 = deltaAxis2 / precisionFactor
        
        logger.debug("Scaling scroll: (\(deltaAxis1), \(deltaAxis2)) -> (\(scaledDelta1), \(scaledDelta2)) with factor \(self.precisionFactor)")
        
        event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: scaledDelta1)
        event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: scaledDelta2)
        
        // Verify scroll scaling
        let verifyDelta1 = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let verifyDelta2 = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        let scrollScalingWorked = abs(verifyDelta1 - scaledDelta1) < 0.001 && abs(verifyDelta2 - scaledDelta2) < 0.001
        
        if !scrollScalingWorked {
            logger.error("CRITICAL: Scroll scaling failed!")
        }
        
        return scrollScalingWorked
    }
    
    private func startDebugTimer() {
        debugTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.debugCurrentState()
        }
    }
    
    private func debugCurrentState() {
        let keyState = CGEventSource.keyState(.combinedSessionState, key: Self.fnKeyCode)
        logger.notice("Debug: fn key polling=\(keyState ? "PRESSED" : "RELEASED"), internal=\(self.fnKeyPressed ? "PRESSED" : "RELEASED"), factor=\(self.precisionFactor)")
        logger.notice("Event stats: total=\(self.eventCount), scaled=\(self.scaledEventCount)")
        
        // Check secure input mode periodically
        if IsSecureEventInputEnabled() {
            logger.warning("Secure input mode is active")
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