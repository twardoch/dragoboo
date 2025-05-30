import Foundation
import CoreGraphics
import os

public class PointerScaler {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var precisionFactor: Double
    private var fnKeyPressed = false
    private let logger = Logger(subsystem: "com.dragoboo.core", category: "PointerScaler")
    
    public var onPrecisionModeChange: ((Bool) -> Void)?
    
    private static let fnKeyCode: CGKeyCode = 0x3F
    
    public init(precisionFactor: Double) {
        self.precisionFactor = precisionFactor
    }
    
    public func start() throws {
        let eventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.rightMouseDragged.rawValue) |
                                     (1 << CGEventType.otherMouseDragged.rawValue) |
                                     (1 << CGEventType.scrollWheel.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let scaler = Unmanaged<PointerScaler>.fromOpaque(userInfo).takeUnretainedValue()
                return scaler.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            logger.error("Failed to create event tap")
            throw PointerScalerError.failedToCreateEventTap
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.info("Event tap enabled successfully")
        }
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        logger.info("Event tap stopped")
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
            updateFnKeyState()
            if fnKeyPressed {
                scaleMouseMovement(event: event)
            }
            
        case .scrollWheel:
            updateFnKeyState()
            if fnKeyPressed {
                scaleScrollWheel(event: event)
            }
            
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            logger.warning("Event tap disabled, attempting to re-enable")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let wasFnPressed = fnKeyPressed
        
        fnKeyPressed = flags.contains(.maskSecondaryFn)
        
        if wasFnPressed != fnKeyPressed {
            logger.debug("Fn key state changed: \(self.fnKeyPressed)")
            onPrecisionModeChange?(fnKeyPressed)
        }
    }
    
    private func updateFnKeyState() {
        let keyState = CGEventSource.keyState(.combinedSessionState, key: Self.fnKeyCode)
        let wasFnPressed = fnKeyPressed
        fnKeyPressed = keyState
        
        if wasFnPressed != fnKeyPressed {
            logger.debug("Fn key state updated via polling: \(self.fnKeyPressed)")
            onPrecisionModeChange?(fnKeyPressed)
        }
    }
    
    private func scaleMouseMovement(event: CGEvent) {
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)
        
        let scaledDeltaX = deltaX / precisionFactor
        let scaledDeltaY = deltaY / precisionFactor
        
        event.setDoubleValueField(.mouseEventDeltaX, value: scaledDeltaX)
        event.setDoubleValueField(.mouseEventDeltaY, value: scaledDeltaY)
    }
    
    private func scaleScrollWheel(event: CGEvent) {
        let deltaAxis1 = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let deltaAxis2 = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        
        let scaledDelta1 = deltaAxis1 / precisionFactor
        let scaledDelta2 = deltaAxis2 / precisionFactor
        
        event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: scaledDelta1)
        event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: scaledDelta2)
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