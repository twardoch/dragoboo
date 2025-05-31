import Foundation
import CoreGraphics
import ApplicationServices
import AppKit
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
    
    // Movement accumulator for precise fractional scaling
    private var accumulatedX: Double = 0.0
    private var accumulatedY: Double = 0.0
    
    // Cursor position tracking for manual control
    private var lastCursorPosition: CGPoint = .zero
    private var isTrackingCursor = false
    
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
        
        // Listen for ALL relevant events: flags changed, mouse movement, scrolling, and dragging
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                     (1 << CGEventType.mouseMoved.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.rightMouseDragged.rawValue) |
                                     (1 << CGEventType.otherMouseDragged.rawValue) |
                                     (1 << CGEventType.scrollWheel.rawValue) |
                                     (1 << CGEventType.tapDisabledByTimeout.rawValue) |
                                     (1 << CGEventType.tapDisabledByUserInput.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Use the main run loop for event tap to ensure proper event capture
        let mainRunLoop = CFRunLoopGetMain()
        
        // Create event tap at annotated session level for reliable event modification
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
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
            logger.error("Event tap FAILED ❌ – annotated session level access. Check permissions.")
            throw PointerScalerError.failedToCreateEventTap
        }
        
        eventTap = tap
        
        logger.info("Event tap created for fn key detection AND event modification")
        
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
        
        print("PointerScaler: Event tap enabled successfully with event modification")
        logger.info("Event tap enabled successfully with event modification")
        
        // Run diagnostics after successful setup
        addDiagnostics()
        
        // Start debug timer
        startDebugTimer()
    }
    
    public func stop() {
        debugTimer?.invalidate()
        debugTimer = nil
        
        // Reset precision mode state
        if isInPrecisionMode {
            isInPrecisionMode = false
            logger.info("Precision mode deactivated on stop")
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
        // DEBUG: Log ALL events being received
        logger.debug("🔍 Event received: \(self.debugEventType(type)), precision mode: \(self.isInPrecisionMode)")
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
            
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            logger.debug("🖱️ Movement event: \(self.debugEventType(type)), precision mode: \(self.isInPrecisionMode)")
            if self.isInPrecisionMode {
                logger.debug("📐 Processing movement event for scaling...")
                return self.modifyMovementEvent(event: event)
            } else {
                logger.debug("⚪ Passing movement event through unmodified (precision mode inactive)")
            }
            
        case .scrollWheel:
            logger.debug("🛞 Scroll event, precision mode: \(self.isInPrecisionMode)")
            if self.isInPrecisionMode {
                logger.debug("📐 Processing scroll event for scaling...")
                return self.modifyScrollEvent(event: event)
            } else {
                logger.debug("⚪ Passing scroll event through unmodified (precision mode inactive)")
            }
            
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            logger.warning("Event tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user input"), attempting to re-enable")
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            
        default:
            // Log other events for debugging
            logger.debug("➖ Other event: \(self.debugEventType(type)) (ignored)")
            break
        }
        
        // Pass events through unmodified by default
        return Unmanaged.passUnretained(event)
    }
    
    /// Intercepts mouse movement events and manually controls cursor position for precision mode
    /// Uses accumulation algorithm to handle fractional movements properly
    private func modifyMovementEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        print("PointerScaler: 📐 modifyMovementEvent() called!")
        logger.info("📐 modifyMovementEvent() called!")
        
        // Get the movement delta - try both integer and double fields
        let deltaXInt = event.getIntegerValueField(.mouseEventDeltaX)
        let deltaYInt = event.getIntegerValueField(.mouseEventDeltaY)
        let deltaXDouble = event.getDoubleValueField(.mouseEventDeltaX) 
        let deltaYDouble = event.getDoubleValueField(.mouseEventDeltaY)
        
        // Use whichever has non-zero values
        let deltaX = deltaXInt != 0 ? Double(deltaXInt) : deltaXDouble
        let deltaY = deltaYInt != 0 ? Double(deltaYInt) : deltaYDouble
        
        // Skip if no movement
        guard deltaX != 0 || deltaY != 0 else {
            return Unmanaged.passUnretained(event)
        }
        
        print("PointerScaler: 🔍 Delta fields - Int: (\(deltaXInt), \(deltaYInt)), Double: (\(deltaXDouble), \(deltaYDouble)), Using: (\(deltaX), \(deltaY))")
        
        print("PointerScaler: 📊 Original deltas: X=\(deltaX), Y=\(deltaY)")
        logger.info("📊 Original deltas: X=\(deltaX), Y=\(deltaY)")
        
        // Apply precision scaling with accumulation (as per algorithms context)
        self.accumulatedX += deltaX / self.precisionFactor
        self.accumulatedY += deltaY / self.precisionFactor
        
        // Extract integer parts for the actual movement
        let scaledX = Int(self.accumulatedX)
        let scaledY = Int(self.accumulatedY)
        
        // Keep the fractional remainders for next time
        self.accumulatedX -= Double(scaledX)
        self.accumulatedY -= Double(scaledY)
        
        print("PointerScaler: 📊 Accumulated: X=\(self.accumulatedX), Y=\(self.accumulatedY)")
        print("PointerScaler: 📊 Applied deltas: X=\(scaledX), Y=\(scaledY), factor=\(self.precisionFactor)")
        logger.info("📊 Applied deltas: X=\(scaledX), Y=\(scaledY), accumulated: X=\(self.accumulatedX), Y=\(self.accumulatedY)")
        
        // NEW APPROACH: Manual cursor warping instead of event modification
        print("PointerScaler: 🔧 APPROACH 4: Manual cursor warping (consuming original event)")
        
        // Calculate new cursor position
        let newPosition = CGPoint(
            x: self.lastCursorPosition.x + Double(scaledX),
            y: self.lastCursorPosition.y + Double(scaledY)
        )
        
        // Warp cursor to new position
        let warpResult = CGWarpMouseCursorPosition(newPosition)
        if warpResult == .success {
            self.lastCursorPosition = newPosition
            print("PointerScaler: ✅ Warped cursor: \(self.lastCursorPosition) -> \(newPosition), delta: (\(scaledX), \(scaledY))")
            logger.info("✅ Cursor warped: original(\(deltaX), \(deltaY)) -> scaled(\(scaledX), \(scaledY)) with factor \(self.precisionFactor)")
        } else {
            print("PointerScaler: ❌ Failed to warp cursor to \(newPosition)")
            logger.error("Failed to warp cursor to position: \(newPosition.x), \(newPosition.y)")
            // Fallback: let the original event through
            return Unmanaged.passUnretained(event)
        }
        
        // Consume the original event (return nil to block it from reaching the system)
        print("PointerScaler: 🚫 Consuming original movement event")
        return nil
    }
    
    /// Modifies scroll wheel events to slow them down when precision mode is active
    private func modifyScrollEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Get the scroll delta
        let scrollDeltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let scrollDeltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        
        // Apply precision scaling (reduce scrolling by precision factor)
        let scaledScrollY = scrollDeltaY / self.precisionFactor
        let scaledScrollX = scrollDeltaX / self.precisionFactor
        
        // Create a new event with modified scroll deltas
        guard let modifiedEvent = event.copy() else {
            logger.error("Failed to copy scroll event")
            return Unmanaged.passUnretained(event)
        }
        
        modifiedEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: scaledScrollY)
        modifiedEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: scaledScrollX)
        
        logger.debug("Modified scroll: original(\(scrollDeltaX), \(scrollDeltaY)) -> scaled(\(scaledScrollX), \(scaledScrollY)) with factor \(self.precisionFactor)")
        
        return Unmanaged.passRetained(modifiedEvent)
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
        
        if isPressed && !isInPrecisionMode {
            logger.notice("🚀 ACTIVATING precision mode with factor \(self.precisionFactor) - using CURSOR WARPING")
            print("PointerScaler: 🚀 ACTIVATING precision mode - using CURSOR WARPING approach")
            
            // Reset accumulator when activating precision mode
            self.accumulatedX = 0.0
            self.accumulatedY = 0.0
            
            // Start cursor tracking - get current position from system
            let currentPosition = NSEvent.mouseLocation
            // Convert from screen coordinates (bottom-left origin) to CG coordinates (top-left origin)
            let screenHeight = NSScreen.main?.frame.height ?? 1440
            self.lastCursorPosition = CGPoint(x: currentPosition.x, y: screenHeight - currentPosition.y)
            self.isTrackingCursor = true
            print("PointerScaler: 🔄 Reset accumulator and started cursor tracking at \(self.lastCursorPosition)")
            
            isInPrecisionMode = true
            logger.info("✅ Precision mode activated - cursor will be manually controlled with \(self.precisionFactor)x scaling")
        } else if !isPressed && isInPrecisionMode {
            logger.notice("🛑 DEACTIVATING precision mode - stopping cursor control")
            print("PointerScaler: 🛑 DEACTIVATING precision mode - stopping cursor control")
            
            // Reset accumulator and stop tracking
            self.accumulatedX = 0.0
            self.accumulatedY = 0.0
            self.isTrackingCursor = false
            print("PointerScaler: 🔄 Reset accumulator and stopped cursor tracking")
            
            isInPrecisionMode = false
            logger.info("✅ Precision mode deactivated - cursor control returned to system")
        }
        
        // Always call the callback to update UI
        DispatchQueue.main.async {
            self.onPrecisionModeChange?(isPressed)
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
        
        // Report method being used
        if isInPrecisionMode {
            logger.notice("Precision control method: SAFE EVENT MODIFICATION (no system changes)")
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