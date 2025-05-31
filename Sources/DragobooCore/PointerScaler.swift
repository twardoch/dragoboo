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
    
    // FRACTIONAL MOVEMENT ACCUMULATION
    private var accumulatedX: Double = 0.0
    private var accumulatedY: Double = 0.0
    
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
        
        // TRY DIFFERENT EVENT TAP LOCATION - HID instead of Session
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,  // Back to Session but test double fields
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
        
        logger.debug("Event tap created ✅ at location=Session")
        
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
            self.totalEventsReceived += 1
            logger.notice("🖱️ MOUSE EVENT #\(self.totalEventsReceived): \(self.debugEventType(type))")
            print("PointerScaler: 🖱️ MOUSE EVENT #\(self.totalEventsReceived): \(self.debugEventType(type))")
            
            self.updateFnKeyState()
            logger.notice("🔑 FN KEY STATE: \(self.fnKeyPressed ? "PRESSED ✅" : "NOT PRESSED ❌")")
            print("PointerScaler: 🔑 FN KEY STATE: \(self.fnKeyPressed ? "PRESSED ✅" : "NOT PRESSED ❌")")
            
            if self.fnKeyPressed {
                logger.notice("🎯 ATTEMPTING TO SCALE MOUSE MOVEMENT...")
                print("PointerScaler: 🎯 ATTEMPTING TO SCALE MOUSE MOVEMENT...")
                let wasScaled = self.scaleMouseMovement(event: event)
                if wasScaled {
                    self.scaledEventCount += 1
                    self.scalingEventsApplied += 1
                    logger.notice("✅ SCALING APPLIED! Total scaled: \(self.scalingEventsApplied)")
                    print("PointerScaler: ✅ SCALING APPLIED! Total scaled: \(self.scalingEventsApplied)")
                } else {
                    logger.error("❌ SCALING FAILED!")
                    print("PointerScaler: ❌ SCALING FAILED!")
                }
            } else {
                logger.notice("⭕ FN KEY NOT PRESSED - NO SCALING")
                print("PointerScaler: ⭕ FN KEY NOT PRESSED - NO SCALING")
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
        // Check keycode directly (FN key is keycode 63/0x3F)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        logger.debug("FlagsChanged event: keyCode=\(keyCode), flags=\(flags.rawValue)")
        logger.debug("Flags breakdown: cmd=\(flags.contains(.maskCommand)), opt=\(flags.contains(.maskAlternate)), ctrl=\(flags.contains(.maskControl)), shift=\(flags.contains(.maskShift)), fn=\(flags.contains(.maskSecondaryFn))")
        
        if keyCode == 63 {
            // Fixed: Use actual flag state instead of toggle
            let wasFnPressed = fnKeyPressed
            fnKeyPressed = flags.contains(.maskSecondaryFn)
            
            if wasFnPressed != fnKeyPressed {
                logger.notice("FN key state changed via keycode 63: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
                onPrecisionModeChange?(fnKeyPressed)
                
                // Reset accumulation when switching modes
                accumulatedX = 0.0
                accumulatedY = 0.0
                logger.debug("Cleared fractional accumulation on fn key state change (flags)")
            }
            return
        }
        
        // Fallback: Check flag state directly without polling to avoid race conditions
        let wasFnPressed = fnKeyPressed
        fnKeyPressed = flags.contains(.maskSecondaryFn)
        
        if wasFnPressed != fnKeyPressed {
            logger.notice("Fn key state changed via flags: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
            onPrecisionModeChange?(fnKeyPressed)
            
            // Reset accumulation when switching modes
            accumulatedX = 0.0
            accumulatedY = 0.0
            logger.debug("Cleared fractional accumulation on fn key state change (flags fallback)")
        }
    }
    
    private func updateFnKeyState() {
        let keyState = CGEventSource.keyState(.combinedSessionState, key: Self.fnKeyCode)
        let wasFnPressed = fnKeyPressed
        
        fnKeyPressed = keyState
        
        if wasFnPressed != fnKeyPressed {
            logger.notice("Fn key state updated via polling: \(self.fnKeyPressed ? "PRESSED" : "RELEASED")")
            onPrecisionModeChange?(fnKeyPressed)
            
            // Reset accumulation when switching modes to prevent jumps
            accumulatedX = 0.0
            accumulatedY = 0.0
            logger.debug("Cleared fractional accumulation on fn key state change")
        }
    }
    
    private func scaleMouseMovement(event: CGEvent) -> Bool {
        logger.notice("🔄 ENTERING scaleMouseMovement function")
        print("PointerScaler: 🔄 ENTERING scaleMouseMovement function")
        
        // TEST ALL FIELD ACCESS METHODS (from TODO.md)
        let deltaX_int = event.getIntegerValueField(.mouseEventDeltaX)
        let deltaY_int = event.getIntegerValueField(.mouseEventDeltaY)
        let deltaX_double = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY_double = event.getDoubleValueField(.mouseEventDeltaY)
        
        logger.notice("📊 FIELD COMPARISON:")
        logger.notice("   Integer: X=\(deltaX_int), Y=\(deltaY_int)")
        logger.notice("   Double:  X=\(deltaX_double), Y=\(deltaY_double)")
        print("PointerScaler: 📊 FIELD COMPARISON: Integer(\(deltaX_int),\(deltaY_int)) Double(\(deltaX_double),\(deltaY_double))")
        
        guard deltaX_int != 0 || deltaY_int != 0 else {
            logger.notice("⭕ NO MOVEMENT - SKIPPING")
            print("PointerScaler: ⭕ NO MOVEMENT - SKIPPING")
            return false
        }
        
        // EXTREME SCALING FACTOR (from TODO.md) - Make effect super obvious
        let extremeFactor = 20.0  // 20x slower instead of user factor!
        
        // Try DOUBLE FIELDS approach
        let scaledMovementX_double = deltaX_double / extremeFactor
        let scaledMovementY_double = deltaY_double / extremeFactor
        
        logger.notice("🚨 EXTREME SCALING TEST (20x slower):")
        logger.notice("   Original doubles: (\(deltaX_double),\(deltaY_double))")
        logger.notice("   Scaled doubles: (\(scaledMovementX_double),\(scaledMovementY_double))")
        
        // FIRST: Try setting DOUBLE fields directly
        event.setDoubleValueField(.mouseEventDeltaX, value: scaledMovementX_double)
        event.setDoubleValueField(.mouseEventDeltaY, value: scaledMovementY_double)
        
        // Verify double field setting
        let verifyX_double = event.getDoubleValueField(.mouseEventDeltaX)
        let verifyY_double = event.getDoubleValueField(.mouseEventDeltaY)
        
        logger.notice("🔍 DOUBLE FIELD TEST:")
        logger.notice("   Set: (\(scaledMovementX_double),\(scaledMovementY_double))")
        logger.notice("   Got: (\(verifyX_double),\(verifyY_double))")
        
        let doubleSuccess = abs(verifyX_double - scaledMovementX_double) < 0.001 && abs(verifyY_double - scaledMovementY_double) < 0.001
        
        if doubleSuccess {
            logger.notice("✅ DOUBLE FIELDS WORKED!")
            print("PointerScaler: ✅ DOUBLE FIELDS WORKED! Set(\(scaledMovementX_double),\(scaledMovementY_double)) Got(\(verifyX_double),\(verifyY_double))")
        } else {
            logger.warning("❌ DOUBLE FIELDS FAILED - trying integer fallback")
            print("PointerScaler: ❌ DOUBLE FIELDS FAILED")
            
            // FALLBACK: Try integer fields with extreme scaling
            let scaledX_int = Int64(deltaX_double / extremeFactor)
            let scaledY_int = Int64(deltaY_double / extremeFactor)
            
            logger.notice("🔄 INTEGER FALLBACK:")
            logger.notice("   Scaled integers: (\(scaledX_int),\(scaledY_int))")
            
            event.setIntegerValueField(.mouseEventDeltaX, value: scaledX_int)
            event.setIntegerValueField(.mouseEventDeltaY, value: scaledY_int)
            
            let verifyX_int = event.getIntegerValueField(.mouseEventDeltaX)
            let verifyY_int = event.getIntegerValueField(.mouseEventDeltaY)
            
            logger.notice("   Set: (\(scaledX_int),\(scaledY_int))")
            logger.notice("   Got: (\(verifyX_int),\(verifyY_int))")
            
            let intSuccess = verifyX_int == scaledX_int && verifyY_int == scaledY_int
            logger.notice("🎯 INTEGER SCALING \(intSuccess ? "SUCCESS" : "FAILED")")
            print("PointerScaler: 🎯 INTEGER SCALING \(intSuccess ? "SUCCESS" : "FAILED")")
            
            return intSuccess
        }
        
        // Reset instant mouser to prevent WindowServer corrections
        event.setIntegerValueField(.mouseEventInstantMouser, value: 0)
        
        logger.notice("🎯 EXTREME SCALING COMPLETE - 20x SLOWER!")
        print("PointerScaler: 🎯 EXTREME SCALING COMPLETE - 20x SLOWER!")
        
        return doubleSuccess
    }
    
    private func scaleScrollWheel(event: CGEvent) -> Bool {
        // Try integer fields first for scroll wheel deltas
        let deltaAxis1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let deltaAxis2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        
        // Only scale if there's actual scroll movement (non-zero deltas)
        guard deltaAxis1 != 0 || deltaAxis2 != 0 else {
            return false
        }
        
        let scaledDelta1 = Int64(Double(deltaAxis1) / precisionFactor)
        let scaledDelta2 = Int64(Double(deltaAxis2) / precisionFactor)
        
        logger.debug("Scaling scroll: (\(deltaAxis1), \(deltaAxis2)) -> (\(scaledDelta1), \(scaledDelta2)) with factor \(self.precisionFactor)")
        
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: scaledDelta1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: scaledDelta2)
        
        // Verify scroll scaling
        let verifyDelta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let verifyDelta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let scrollScalingWorked = verifyDelta1 == scaledDelta1 && verifyDelta2 == scaledDelta2
        
        if !scrollScalingWorked {
            logger.error("CRITICAL: Scroll scaling failed! Expected (\(scaledDelta1), \(scaledDelta2)), got (\(verifyDelta1), \(verifyDelta2))")
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