// this_file: Sources/DragobooCore/PrecisionEngine.swift

import Foundation
import CoreGraphics
import ApplicationServices
import AppKit
import os

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
    
    // Cursor position tracking for manual control
    private var lastCursorPosition: CGPoint = .zero
    
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
        
        // Listen for relevant events: flags changed, mouse movement, scrolling, and dragging
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                     (1 << CGEventType.mouseMoved.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.rightMouseDragged.rawValue) |
                                     (1 << CGEventType.otherMouseDragged.rawValue) |
                                     (1 << CGEventType.scrollWheel.rawValue) |
                                     (1 << CGEventType.tapDisabledByTimeout.rawValue) |
                                     (1 << CGEventType.tapDisabledByUserInput.rawValue)
        
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
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
            
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if isInPrecisionMode {
                return modifyMovementEvent(event: event)
            }
            
        case .scrollWheel:
            if isInPrecisionMode {
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
    
    /// Intercepts mouse movement events and manually controls cursor position for precision mode
    /// Uses accumulation algorithm to handle fractional movements properly
    private func modifyMovementEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
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
        
        // Apply precision scaling with accumulation
        accumulatedX += deltaX / precisionFactor
        accumulatedY += deltaY / precisionFactor
        
        // Extract integer parts for the actual movement
        let scaledX = Int(accumulatedX)
        let scaledY = Int(accumulatedY)
        
        // Keep the fractional remainders for next time
        accumulatedX -= Double(scaledX)
        accumulatedY -= Double(scaledY)
        
        // Manual cursor warping instead of event modification
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
        
        // Consume the original event (return nil to block it from reaching the system)
        return nil
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
        
        // Always use the flag state for fn key detection
        let wasFnPressed = fnKeyPressed
        fnKeyPressed = flags.contains(.maskSecondaryFn)
        
        // Only handle state changes
        if wasFnPressed != fnKeyPressed {
            handleFnKeyStateChange(isPressed: fnKeyPressed)
        }
    }
    
    private func handleFnKeyStateChange(isPressed: Bool) {
        guard isPressed != isInPrecisionMode else { 
            return 
        }
        
        if isPressed && !isInPrecisionMode {
            // Reset accumulator when activating precision mode
            accumulatedX = 0.0
            accumulatedY = 0.0
            
            // Start cursor tracking - get current position from system
            let currentPosition = NSEvent.mouseLocation
            // Convert from screen coordinates (bottom-left origin) to CG coordinates (top-left origin)
            let screenHeight = NSScreen.main?.frame.height ?? 1440
            lastCursorPosition = CGPoint(x: currentPosition.x, y: screenHeight - currentPosition.y)
            
            isInPrecisionMode = true
            logger.info("Precision mode activated with factor \(self.precisionFactor)")
        } else if !isPressed && isInPrecisionMode {
            // Reset accumulator and stop tracking
            accumulatedX = 0.0
            accumulatedY = 0.0
            
            isInPrecisionMode = false
            logger.info("Precision mode deactivated")
        }
        
        // Update UI
        DispatchQueue.main.async {
            self.onPrecisionModeChange?(isPressed)
        }
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