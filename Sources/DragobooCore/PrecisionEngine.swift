// this_file: Sources/DragobooCore/PrecisionEngine.swift

import Foundation
import CoreGraphics
import ApplicationServices
import AppKit
import os

public enum ModifierKey: String, CaseIterable, Codable {
    case fn, control, option, command
    
    public var cgEventFlag: CGEventFlags {
        switch self {
        case .fn: return .maskSecondaryFn
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .command: return .maskCommand
        }
    }
    
    public var displayName: String {
        switch self {
        case .fn: return "fn"
        case .control: return "⌃"
        case .option: return "⌥"
        case .command: return "⌘"
        }
    }
}

public class PrecisionEngine {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var precisionFactor: Double
    private var fnKeyPressed = false
    private var isInPrecisionMode = false
    private let logger = Logger(subsystem: "com.dragoboo.core", category: "PrecisionEngine")
    
    // Movement accumulator for precise fractional scaling
    private var accumulatedX: Double = 0.0
    private var accumulatedY: Double = 0.0
    
    // Cursor position tracking for manual control in precision mode
    private var lastCursorPosition: CGPoint = .zero
    
    // v2.0: Configurable modifier keys
    private var modifierKeys: Set<ModifierKey> = [.fn]
    
    // v2.0: Feature toggles
    private var slowSpeedEnabled: Bool = true
    private var dragAccelerationEnabled: Bool = true
    
    // v2.0: Drag acceleration settings
    private var accelerationRadius: Double = 200.0
    private var isDragging = false
    private var currentDragDistance: Double = 0.0
    
    public var onPrecisionModeChange: ((Bool) -> Void)?
    
    private static let fnKeyCode: CGKeyCode = 0x3F
    
    public init(precisionFactor: Double) {
        self.precisionFactor = precisionFactor
    }
    
    public func start() throws {
        logger.info("Starting precision engine...")
        
        // Reset state on start
        fnKeyPressed = false
        isInPrecisionMode = false
        
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            logger.error("Accessibility permissions not granted")
            throw PrecisionEngineError.failedToCreateEventTap
        }
        
        // Listen for relevant events: flags changed, mouse movement, scrolling, dragging, and mouse button events
        let flagsChangedMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let mouseMovedMask: CGEventMask = 1 << CGEventType.mouseMoved.rawValue
        let leftMouseDownMask: CGEventMask = 1 << CGEventType.leftMouseDown.rawValue
        let leftMouseUpMask: CGEventMask = 1 << CGEventType.leftMouseUp.rawValue
        let rightMouseDownMask: CGEventMask = 1 << CGEventType.rightMouseDown.rawValue
        let rightMouseUpMask: CGEventMask = 1 << CGEventType.rightMouseUp.rawValue
        let otherMouseDownMask: CGEventMask = 1 << CGEventType.otherMouseDown.rawValue
        let otherMouseUpMask: CGEventMask = 1 << CGEventType.otherMouseUp.rawValue
        let leftMouseDraggedMask: CGEventMask = 1 << CGEventType.leftMouseDragged.rawValue
        let rightMouseDraggedMask: CGEventMask = 1 << CGEventType.rightMouseDragged.rawValue
        let otherMouseDraggedMask: CGEventMask = 1 << CGEventType.otherMouseDragged.rawValue
        let scrollWheelMask: CGEventMask = 1 << CGEventType.scrollWheel.rawValue
        let tapDisabledByTimeoutMask: CGEventMask = 1 << CGEventType.tapDisabledByTimeout.rawValue
        let tapDisabledByUserInputMask: CGEventMask = 1 << CGEventType.tapDisabledByUserInput.rawValue
        
        let eventMask: CGEventMask = flagsChangedMask | mouseMovedMask | leftMouseDownMask | leftMouseUpMask |
                                     rightMouseDownMask | rightMouseUpMask | otherMouseDownMask | otherMouseUpMask |
                                     leftMouseDraggedMask | rightMouseDraggedMask | otherMouseDraggedMask |
                                     scrollWheelMask | tapDisabledByTimeoutMask | tapDisabledByUserInputMask
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Create event tap at annotated session level for reliable event modification
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo = userInfo else { 
                    return Unmanaged.passUnretained(event) 
                }
                let engine = Unmanaged<PrecisionEngine>.fromOpaque(userInfo).takeUnretainedValue()
                return engine.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            logger.error("Failed to create event tap")
            throw PrecisionEngineError.failedToCreateEventTap
        }
        
        eventTap = tap
        
        // Create run loop source and add to main run loop
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap!, 0) else {
            logger.error("Failed to create run loop source")
            CGEvent.tapEnable(tap: eventTap!, enable: false)
            CFMachPortInvalidate(eventTap!)
            throw PrecisionEngineError.failedToCreateEventTap
        }
        
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap!, enable: true)
        
        logger.info("Precision engine started successfully")
    }
    
    public func stop() {
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
        logger.info("Precision engine stopped")
    }
    
    public func updatePrecisionFactor(_ factor: Double) {
        precisionFactor = factor
        logger.info("Updated precision factor to \(factor)")
    }
    
    // v2.0: Update configurable modifier keys
    public func updateModifierKeys(_ keys: Set<ModifierKey>) {
        modifierKeys = keys
        logger.info("Updated modifier keys: \(keys)")
    }
    
    // v2.0: Update drag acceleration radius
    public func updateAccelerationRadius(_ radius: Double) {
        accelerationRadius = radius
        logger.info("Updated acceleration radius: \(radius)")
    }
    
    // v2.0: Update feature toggles
    public func updateSlowSpeedEnabled(_ enabled: Bool) {
        slowSpeedEnabled = enabled
        logger.info("Slow speed enabled: \(enabled)")
        
        // If slow speed is disabled and we're in precision mode, deactivate it
        if !enabled && isInPrecisionMode {
            handleActivationStateChange(isPressed: false)
        }
    }
    
    public func updateDragAccelerationEnabled(_ enabled: Bool) {
        dragAccelerationEnabled = enabled
        logger.info("Drag acceleration enabled: \(enabled)")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
            
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if dragAccelerationEnabled {
                startDragTracking(at: getCursorPosition())
            }
            
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if isDragging {
                stopDragTracking()
            }
            
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let isDragEvent = type != .mouseMoved
            let shouldModify = (isInPrecisionMode && slowSpeedEnabled) || (isDragEvent && isDragging && dragAccelerationEnabled)
            if shouldModify {
                return modifyMovementEvent(event: event, isDragEvent: isDragEvent)
            }
            
        case .scrollWheel:
            if isInPrecisionMode && slowSpeedEnabled {
                return modifyScrollEvent(event: event)
            }
            
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            logger.warning("Event tap disabled, attempting to re-enable")
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// Intercepts mouse movement events and controls cursor movement for precision mode and drag acceleration
    /// Uses accumulation algorithm to handle fractional movements properly
    private func modifyMovementEvent(event: CGEvent, isDragEvent: Bool) -> Unmanaged<CGEvent>? {
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
        
        // Calculate effective precision factor with drag acceleration
        let effectiveFactor = calculateEffectivePrecisionFactor(isDragging: isDragEvent)
        
        // Apply precision scaling with accumulation
        accumulatedX += deltaX / effectiveFactor
        accumulatedY += deltaY / effectiveFactor
        
        // Extract integer parts for the actual movement
        let scaledX = Int(accumulatedX)
        let scaledY = Int(accumulatedY)
        
        // Keep the fractional remainders for next time
        accumulatedX -= Double(scaledX)
        accumulatedY -= Double(scaledY)
        
        // Update drag distance if dragging
        if isDragEvent && isDragging {
            currentDragDistance += sqrt(Double(scaledX * scaledX + scaledY * scaledY))
        }
        
        // For precision mode, use manual cursor warping with proper coordinate handling
        if isInPrecisionMode && slowSpeedEnabled {
            let newPosition = CGPoint(
                x: lastCursorPosition.x + Double(scaledX),
                y: lastCursorPosition.y + Double(scaledY)
            )
            
            // Warp cursor to new position
            let warpResult = CGWarpMouseCursorPosition(newPosition)
            if warpResult == .success {
                lastCursorPosition = newPosition
            } else {
                logger.error("Failed to warp cursor to position: \(newPosition.x), \(newPosition.y)")
                return Unmanaged.passUnretained(event)
            }
            
            // Consume the original event
            return nil
        } else {
            // For drag acceleration without precision mode, modify event deltas
            guard let modifiedEvent = event.copy() else {
                logger.error("Failed to copy movement event")
                return Unmanaged.passUnretained(event)
            }
            
            modifiedEvent.setDoubleValueField(.mouseEventDeltaX, value: Double(scaledX))
            modifiedEvent.setDoubleValueField(.mouseEventDeltaY, value: Double(scaledY))
            
            return Unmanaged.passRetained(modifiedEvent)
        }
    }
    
    /// Modifies scroll wheel events to slow them down when precision mode is active
    private func modifyScrollEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Get the scroll delta
        let scrollDeltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let scrollDeltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        
        // Apply precision scaling (reduce scrolling by precision factor)
        let scaledScrollY = scrollDeltaY / precisionFactor
        let scaledScrollX = scrollDeltaX / precisionFactor
        
        // Create a new event with modified scroll deltas
        guard let modifiedEvent = event.copy() else {
            logger.error("Failed to copy scroll event")
            return Unmanaged.passUnretained(event)
        }
        
        modifiedEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: scaledScrollY)
        modifiedEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: scaledScrollX)
        
        return Unmanaged.passRetained(modifiedEvent)
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        
        // v2.0: Check if any configured modifier keys are pressed (only if slow speed is enabled and modifier keys are configured)
        let wasActive = fnKeyPressed
        fnKeyPressed = slowSpeedEnabled && !modifierKeys.isEmpty && modifierKeys.contains { key in
            flags.contains(key.cgEventFlag)
        }
        
        // Only handle state changes
        if wasActive != fnKeyPressed {
            handleActivationStateChange(isPressed: fnKeyPressed)
        }
    }
    
    private func handleActivationStateChange(isPressed: Bool) {
        guard isPressed != isInPrecisionMode else { 
            return 
        }
        
        if isPressed && !isInPrecisionMode {
            // Reset accumulator when activating precision mode
            accumulatedX = 0.0
            accumulatedY = 0.0
            
            // Start cursor tracking for precision mode
            let currentPosition = NSEvent.mouseLocation
            // Use screen coordinates directly since CGWarpMouseCursorPosition expects them
            lastCursorPosition = currentPosition
            
            isInPrecisionMode = true
            logger.info("Precision mode activated with factor \(self.precisionFactor)")
        } else if !isPressed && isInPrecisionMode {
            // Reset accumulator and stop tracking
            accumulatedX = 0.0
            accumulatedY = 0.0
            
            // Stop any drag tracking
            if isDragging {
                stopDragTracking()
            }
            
            isInPrecisionMode = false
            logger.info("Precision mode deactivated")
        }
        
        // Update UI
        DispatchQueue.main.async {
            self.onPrecisionModeChange?(isPressed)
        }
    }
    
    // v2.0: Helper methods for drag acceleration
    private func calculateEffectivePrecisionFactor(isDragging: Bool) -> Double {
        // If slow speed is active, use configured precision factor
        let baseFactor = (isInPrecisionMode && slowSpeedEnabled) ? precisionFactor : 1.0
        
        // Apply drag acceleration if enabled and dragging
        guard isDragging && self.isDragging && dragAccelerationEnabled else {
            return baseFactor
        }
        
        // Non-linear acceleration curve
        let progress = min(currentDragDistance / accelerationRadius, 1.0)
        
        // Cubic easing function for non-linear acceleration
        // Slow increase near start, faster increase with distance
        let easedProgress = progress * progress * (3.0 - 2.0 * progress)
        
        // For drag acceleration: start slower than base, accelerate to normal speed (factor 1.0)
        // Use at least 2x slower (factor 2.0) as starting point for drag acceleration
        let dragStartFactor = max(baseFactor, 2.0)
        return dragStartFactor * (1.0 - easedProgress) + 1.0 * easedProgress
    }
    
    private func startDragTracking(at position: CGPoint) {
        isDragging = true
        currentDragDistance = 0.0
        logger.debug("Started drag tracking")
    }
    
    private func stopDragTracking() {
        isDragging = false
        currentDragDistance = 0.0
        logger.debug("Stopped drag tracking")
    }
    
    private func getCursorPosition() -> CGPoint {
        return NSEvent.mouseLocation
    }
}

public enum PrecisionEngineError: LocalizedError {
    case failedToCreateEventTap
    
    public var errorDescription: String? {
        switch self {
        case .failedToCreateEventTap:
            return "Failed to create event tap. Please ensure accessibility permissions are granted."
        }
    }
} 