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
    // Tracks if the slow speed mode is currently active and scaling mouse movements.
    // This is controlled by handleActivationStateChange.
    private var isInPrecisionMode = false
    private let logger = Logger(subsystem: "com.dragoboo.core", category: "PrecisionEngine")
    
    // --- State Variables ---

    // Movement Accumulators for fractional pixel movements
    private var accumulatedX: Double = 0.0
    private var accumulatedY: Double = 0.0
    
    // Last Known Cursor Position for manual cursor warping
    private var lastCursorPosition: CGPoint = .zero
    
    // Configurable modifier keys for Slow Speed Mode (Precision Mode)
    private var modifierKeys: Set<ModifierKey> = [.fn]
    
    // Configurable modifier keys for Drag Acceleration
    private var dragAccelerationModifierKeys: Set<ModifierKey> = []
    
    // Feature Toggles
    private var slowSpeedEnabled: Bool = true
    private var dragAccelerationEnabled: Bool = true
    // Percentage for slow speed, used to derive startFactor for drag acceleration
    private var slowSpeedPercentage: Double = 100.0
    
    // Drag Acceleration Settings
    private var accelerationRadius: Double = 200.0
    private var isDragging = false // Is a mouse button currently held down
    private var currentDragDistance: Double = 0.0 // Distance dragged since mouse down
    
    // Modifier State Tracking (updated by handleFlagsChanged)
    // True if conditions for slow speed activation (modifiers + feature toggle) are met
    private var isSlowSpeedModifiersActive = false
    // True if conditions for drag acceleration activation (modifiers + feature toggle) are met
    private var isDragAccelerationModifiersActive = false
    
    public var onPrecisionModeChange: ((Bool) -> Void)?
    
    public init(precisionFactor: Double) {
        self.precisionFactor = precisionFactor
        // Note: slowSpeedPercentage is also updated by updatePrecisionFactor
        // It might be more direct if AppState provides both factor and percentage,
        // or if PrecisionEngine always derives factor from a supplied percentage.
        // For now, this reflects the existing logic structure.
        if precisionFactor != 0 {
            self.slowSpeedPercentage = 200.0 / precisionFactor
        } else {
            self.slowSpeedPercentage = 0 // Or handle error
        }
    }
    
    public func start() throws {
        logger.info("Starting precision engine...")
        
        // Reset state on start
        isInPrecisionMode = false
        isSlowSpeedModifiersActive = false // Also reset derived modifier states
        isDragAccelerationModifiersActive = false
        
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
        guard let tap = eventTap else {
            // This should not happen if the first guard let tap passed. Defensive coding.
            logger.error("Event tap became nil unexpectedly before creating run loop source.")
            throw PrecisionEngineError.failedToCreateEventTap
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            logger.error("Failed to create run loop source")
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.eventTap = nil // Nullify the invalidated tap
            throw PrecisionEngineError.failedToCreateRunLoopSource
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
        // Calculate and store the percentage from the factor.
        // The formula is: factor = 200.0 / percentage.
        // Thus, percentage = 200.0 / factor.
        // A factor of 2.0 corresponds to 100% (normal speed).
        // A factor of 4.0 corresponds to 50% (half speed).
        // A factor of 20.0 corresponds to 10% (1/10th speed).
        if factor != 0 { // Avoid division by zero, though factor should typically be > 0
            slowSpeedPercentage = 200.0 / factor
        } else {
            slowSpeedPercentage = 0 // Or some other indicator of an issue
            logger.warning("Attempted to update precision factor with 0. This might lead to issues.")
        }
        logger.info("Updated precision factor to \(self.precisionFactor), calculated percentage: \(self.slowSpeedPercentage)%")
    }
    
    // v2.0: Update configurable modifier keys
    public func updateModifierKeys(_ keys: Set<ModifierKey>) {
        modifierKeys = keys
        logger.info("Updated modifier keys: \(keys)")
    }
    
    // v2.0: Update drag acceleration modifier keys
    public func updateDragAccelerationModifierKeys(_ keys: Set<ModifierKey>) {
        dragAccelerationModifierKeys = keys
        logger.info("Updated drag acceleration modifier keys: \(keys)")
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
    
    /// Core event handling callback for the CGEventTap.
    /// This function receives all subscribed mouse and keyboard flag events.
    /// It dispatches events to specialized handlers or modifies them as needed.
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // For most events, we pass them through unmodified by returning Unmanaged.passUnretained(event).
        // If an event is modified or consumed, specific return values are used (e.g., Unmanaged.passRetained(newEvent) or nil).

        switch type {
        case .flagsChanged:
            // Handles changes in modifier key states (Shift, Ctrl, Alt, Cmd, Fn).
            // This is crucial for activating/deactivating slow speed mode based on configured modifier keys.
            handleFlagsChanged(event: event)
            
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // If drag acceleration is enabled, start tracking drag distance and state upon mouse down.
            if dragAccelerationEnabled {
                logger.debug("Mouse down event detected. Starting drag tracking if not already active.")
                // Using NSEvent.mouseLocation for consistency with other parts of the code that initialize lastCursorPosition.
                // While event.location could be more precise here, it refers to a specific event's location,
                // and drag initiation might need the most current global position.
                startDragTracking(at: NSEvent.mouseLocation)
            }
            
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            // If currently tracking a drag, stop it upon mouse up.
            if isDragging { // `isDragging` is the engine's internal state.
                logger.debug("Mouse up event detected. Stopping drag tracking.")
                stopDragTracking()
            }
            
        // These events represent cursor movement.
        // .mouseMoved: Cursor moved without any mouse buttons pressed.
        // .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: Cursor moved with one or more mouse buttons pressed.
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let isDragEvent = type != .mouseMoved // True if any mouse button is down during movement.

            // Determine if this movement event should be modified (scaled).
            // Modification occurs if:
            // 1. Slow speed mode is active (`isInPrecisionMode` is true and the `slowSpeedEnabled` feature toggle is on).
            //    OR
            // 2. It's a drag event (`isDragEvent` is true), the engine is currently tracking a drag (`self.isDragging` is true),
            //    the `dragAccelerationEnabled` feature toggle is on, and the necessary modifier keys for drag acceleration (if any) are pressed (`isDragAccelerationModifiersActive` is true).
            // Note: `shouldWarpCursor` in `modifyMovementEvent` re-evaluates a similar condition.
            // This initial check here is a broader "should we even look at modifying this movement?"
            let shouldConsiderModifyingMovement = (isInPrecisionMode && slowSpeedEnabled) ||
                                                (isDragEvent && self.isDragging && dragAccelerationEnabled && isDragAccelerationModifiersActive)

            if shouldConsiderModifyingMovement {
                return modifyMovementEvent(event: event, isDragEvent: isDragEvent)
            }
            
        case .scrollWheel:
            // Scroll events are modified only if slow speed mode is active and enabled.
            // Drag acceleration does not apply to scroll events.
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
        
        logger.debug("Original deltas: (X: \(deltaX), Y: \(deltaY)), isDragEvent: \(isDragEvent), isCurrentlyDragging: \(self.isDragging)")

        // Update drag distance if dragging (use actual movement, not scaled)
        if isDragEvent && self.isDragging { // Use self.isDragging to ensure consistency
            let movementMagnitude = sqrt(deltaX * deltaX + deltaY * deltaY)
            currentDragDistance += movementMagnitude
            logger.debug("Drag distance updated by \(movementMagnitude), total: \(self.currentDragDistance), radius: \(self.accelerationRadius)")
        }
        
        // Calculate effective precision factor with drag acceleration
        let effectiveFactor = calculateEffectivePrecisionFactor(isDragging: isDragEvent)
        logger.debug("Calculated effectiveFactor: \(effectiveFactor)")

        guard effectiveFactor != 0 else {
            logger.error("Effective precision factor is zero, cannot scale movement. Passing event through.")
            return Unmanaged.passUnretained(event)
        }
        
        // Apply precision scaling with accumulation
        accumulatedX += deltaX / effectiveFactor
        accumulatedY += deltaY / effectiveFactor
        
        // Extract integer parts for the actual movement
        let scaledX = Int(accumulatedX)
        let scaledY = Int(accumulatedY)
        
        // Keep the fractional remainders for next time
        accumulatedX -= Double(scaledX)
        accumulatedY -= Double(scaledY)

        logger.debug("ScaledXY: (\(scaledX), \(scaledY)), Accumulators: (\(self.accumulatedX), \(self.accumulatedY))")

        // Determine if the cursor's movement should be controlled by warping (manual positioning).
        // This is the core logic deciding when Dragoboo takes over direct cursor positioning.
        // Warping is used if:
        // 1. Slow Speed Mode is fully active:
        //    - `isInPrecisionMode` is true (modifier keys for slow speed are pressed).
        //    - `slowSpeedEnabled` is true (the feature toggle for slow speed is on).
        // OR
        // 2. Drag Acceleration is applicable and active for the current movement event:
        //    - `isDragEvent` is true (the mouse button is down during this movement).
        //    - `self.isDragging` is true (the engine has registered a mouse down and is tracking this drag).
        //    - `dragAccelerationEnabled` is true (the feature toggle for drag acceleration is on).
        //    - `isDragAccelerationModifiersActive` is true (any configured modifier keys for drag acceleration are pressed, or no keys are configured meaning it's always modifier-active if the feature is on).
        //
        // Note on precedence: `calculateEffectivePrecisionFactor` already handles the precedence of slow speed mode
        // over drag acceleration. If slow speed mode is active, it returns the slow speed factor.
        // This `shouldWarpCursor` condition determines if the calculated factor (whatever it may be)
        // is applied via cursor warping or if the event should be passed through (or modified differently if not warping).
        // For Dragoboo, both slow speed and drag acceleration are implemented via warping.
        let shouldWarpCursor = (isInPrecisionMode && slowSpeedEnabled) ||
                               (isDragEvent && self.isDragging && dragAccelerationEnabled && isDragAccelerationModifiersActive)

        if shouldWarpCursor {
            // Use manual cursor warping for precise control
            let newPosition = CGPoint(
                x: lastCursorPosition.x + Double(scaledX),
                y: lastCursorPosition.y + Double(scaledY)
            )
            
            // Warp cursor to new position
            logger.debug("Warping cursor from \(self.lastCursorPosition) to \(newPosition)")
            let warpResult = CGWarpMouseCursorPosition(newPosition)
            if warpResult == .success {
                lastCursorPosition = newPosition
            } else {
                // CGWarpMouseCursorPosition can fail for various reasons (e.g., secure input mode active).
                logger.error("Failed to warp cursor to position: (\(newPosition.x), \(newPosition.y)). Error code: \(warpResult.rawValue)")
                // If warping fails, we should not consume the event, as the cursor hasn't moved as intended.
                // However, the original event still contains the unscaled deltas.
                // This could lead to a jump if we pass it through.
                // For now, log and consume, effectively stopping movement if warp fails.
                // Alternative: pass original event, but this might feel like a jump.
                // Alternative 2: try to create a new event with scaled deltas (but this is what we avoid by warping).
                // Given the complexity, consuming seems the safest if warp fails, preventing unexpected jumps.
                return nil // Consume event if warp fails to prevent large jump from original event
            }
            
            // Consume the original event as we've manually moved the cursor
            return nil
        } else {
            // If not warping (e.g., normal movement, or drag acceleration not active/applicable),
            // pass through the original event unmodified.
            logger.debug("Passing event through without warping.")
            return Unmanaged.passUnretained(event)
        }
    }
    
    /// Modifies scroll wheel events to slow them down when precision mode is active
    private func modifyScrollEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Get the scroll delta
        let scrollDeltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1) // Usually vertical scroll
        let scrollDeltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2) // Usually horizontal scroll
        logger.debug("Original scroll deltas: (X: \(scrollDeltaX), Y: \(scrollDeltaY))")

        guard precisionFactor != 0 else {
            logger.error("Precision factor is zero, cannot scale scroll. Passing event through.")
            return Unmanaged.passUnretained(event)
        }
        
        // Apply precision scaling (reduce scrolling by precision factor)
        let scaledScrollY = scrollDeltaY / precisionFactor
        let scaledScrollX = scrollDeltaX / precisionFactor
        logger.debug("Scaled scroll deltas: (X: \(scaledScrollX), Y: \(scaledScrollY))")
        
        // Create a new event with modified scroll deltas
        guard let modifiedEvent = event.copy() else {
            logger.error("Failed to copy scroll event. Passing original event through.")
            return Unmanaged.passUnretained(event)
        }
        
        modifiedEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: scaledScrollY)
        modifiedEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: scaledScrollX)
        
        return Unmanaged.passRetained(modifiedEvent)
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let previousSlowSpeedModifiersActive = isSlowSpeedModifiersActive
        let previousDragAccelerationModifiersActive = isDragAccelerationModifiersActive
        
        // v2.0: Check slow speed modifier state
        // Active if: slow speed feature is enabled AND at least one modifier key is configured AND all configured modifier keys are currently pressed.
        isSlowSpeedModifiersActive = slowSpeedEnabled &&
                                     !modifierKeys.isEmpty &&
                                     modifierKeys.allSatisfy { key in flags.contains(key.cgEventFlag) }
        
        // v2.0: Check drag acceleration modifier state
        if dragAccelerationModifierKeys.isEmpty {
            // No modifiers configured for drag acceleration = it's active whenever dragAcceleration feature itself is enabled.
            isDragAccelerationModifiersActive = dragAccelerationEnabled
        } else {
            // Modifiers configured for drag acceleration = active if dragAcceleration feature is enabled AND all configured keys are pressed.
            isDragAccelerationModifiersActive = dragAccelerationEnabled &&
                                                dragAccelerationModifierKeys.allSatisfy { key in flags.contains(key.cgEventFlag) }
        }
        
        // Apply precedence: slow speed mode (precision mode) wins over drag acceleration if their activation conditions overlap.
        // This means if both would be active based on current flags, and there's any overlap in the *actual keys*
        // causing their activation, then drag acceleration is suppressed.
        if isSlowSpeedModifiersActive && isDragAccelerationModifiersActive {
            // Determine the set of keys currently held down that are responsible for activating slow speed
            let currentlyActiveSlowSpeedKeys = modifierKeys.filter { flags.contains($0.cgEventFlag) }
            // Determine the set of keys currently held down that are responsible for activating drag acceleration
            let currentlyActiveDragAccelKeys = dragAccelerationModifierKeys.filter { flags.contains($0.cgEventFlag) }

            // If drag acceleration has specific keys AND there's an overlap with active slow speed keys, slow speed takes precedence.
            // If drag acceleration has no specific keys (always on when feature enabled), but slow speed is active, slow speed also takes precedence.
            if !dragAccelerationModifierKeys.isEmpty && !Set(currentlyActiveSlowSpeedKeys).isDisjoint(with: Set(currentlyActiveDragAccelKeys)) {
                logger.debug("Modifier overlap: Slow speed precedence. Disabling drag acceleration modifier effect.")
                isDragAccelerationModifiersActive = false
            } else if dragAccelerationModifierKeys.isEmpty && isSlowSpeedModifiersActive {
                // If drag acceleration is "always on" (no specific keys) but slow speed modifiers are active, slow speed takes precedence.
                logger.debug("Slow speed active, overriding 'always on' drag acceleration modifier effect.")
                isDragAccelerationModifiersActive = false
            }
        }
        
        if previousSlowSpeedModifiersActive != isSlowSpeedModifiersActive || previousDragAccelerationModifiersActive != isDragAccelerationModifiersActive {
            logger.debug("""
                Modifier states changed:
                Slow Speed Modifiers: \(previousSlowSpeedModifiersActive) -> \(isSlowSpeedModifiersActive) (Enabled: \(slowSpeedEnabled), Keys: \(modifierKeys.map(\.displayName)))
                Drag Accel Modifiers: \(previousDragAccelerationModifiersActive) -> \(isDragAccelerationModifiersActive) (Enabled: \(dragAccelerationEnabled), Keys: \(dragAccelerationModifierKeys.map(\.displayName)))
                Current Flags: \(flags.rawValue)
                """)
        }

        // Handle precision mode activation/deactivation based on the new state of isSlowSpeedModifiersActive.
        // Call handleActivationStateChange if the current active state of precision mode (isInPrecisionMode)
        // differs from what it should be based on the latest modifier key check (isSlowSpeedModifiersActive).
        if isSlowSpeedModifiersActive != isInPrecisionMode {
            logger.info("Slow speed activation criteria met (\(isSlowSpeedModifiersActive)) differs from current precision mode state (\(isInPrecisionMode)). Updating precision mode state.")
            handleActivationStateChange(shouldBeActive: isSlowSpeedModifiersActive)
        }
    }
    
    private func handleActivationStateChange(shouldBeActive: Bool) {
        // This function is called when isInPrecisionMode needs to change.
        // The guard is technically redundant if called correctly from handleFlagsChanged,
        // but kept as a safety check.
        guard shouldBeActive != isInPrecisionMode else {
            logger.warning("handleActivationStateChange called but shouldBeActive (\(shouldBeActive)) is already same as isInPrecisionMode (\(isInPrecisionMode)).")
            return 
        }
        
        if shouldBeActive { // Equivalent to (shouldBeActive && !isInPrecisionMode) due to the guard
            // Reset accumulator when activating precision mode
            accumulatedX = 0.0
            accumulatedY = 0.0
            
            // Start cursor tracking for precision mode
            let nsEventPosition = NSEvent.mouseLocation
            // Convert from NSEvent coordinates (bottom-left origin) to CG coordinates (top-left origin)
            lastCursorPosition = convertToGlobalTopLeft(point: nsEventPosition)
            logger.debug("Initialized lastCursorPosition for precision mode: \(self.lastCursorPosition)")
            
            isInPrecisionMode = true
            // Ensure precisionFactor is positive before logging division by it.
            let percentageDisplay = self.precisionFactor != 0 ? "\(200.0/self.precisionFactor)%" : "N/A (zero factor)"
            logger.info("Precision mode activated. Factor: \(self.precisionFactor) (approx. \(percentageDisplay) speed).")
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
    // Made internal for testability
    func calculateEffectivePrecisionFactor(isDragging: Bool) -> Double {
        // The "normal" mouse speed factor used by the system is considered 2.0.
        // This means to achieve normal speed, mouse deltas are divided by 2.0.
        // A higher factor means slower movement (e.g., factor 4.0 is half speed).
        let normalSpeedFactor = 2.0

        // Precedence: Slow speed mode (precision mode) takes priority over drag acceleration.
        // If slow speed mode is active (modifier keys pressed and feature enabled),
        // use its configured precisionFactor directly.
        if isInPrecisionMode && slowSpeedEnabled {
            // `precisionFactor` is derived from `slowSpeedPercentage` (e.g., 50% speed -> factor 4.0).
            // This value is set by `updatePrecisionFactor()`.
            return precisionFactor
        }
        
        // If not in slow speed mode, consider drag acceleration.
        // Drag acceleration applies if:
        // - The current event is a drag event (`isDragging` parameter, which means mouse button is down).
        // - The engine is tracking a drag (`self.isDragging` state).
        // - The drag acceleration feature is enabled (`dragAccelerationEnabled`).
        // - Any configured modifiers for drag acceleration are active (`isDragAccelerationModifiersActive`).
        if isDragging && self.isDragging && dragAccelerationEnabled && isDragAccelerationModifiersActive {
            // Guard against division by zero for critical parameters.
            guard accelerationRadius > 0 else {
                logger.warning("Acceleration radius is zero or negative (\(self.accelerationRadius)), cannot calculate drag acceleration. Using normal speed factor.")
                return normalSpeedFactor
            }
            // slowSpeedPercentage is used to determine the *starting speed* of the drag.
            // It comes from the UI slider (e.g., 5% to 100%).
            guard slowSpeedPercentage > 0 else {
                logger.warning("Slow speed percentage is zero or negative (\(self.slowSpeedPercentage)), cannot calculate start factor for drag. Using normal speed factor.")
                return normalSpeedFactor
            }

            // Calculate progress of the drag from its start point towards the configured radius.
            // Progress is clamped between 0.0 (at drag start) and 1.0 (at or beyond radius).
            let progress = min(currentDragDistance / accelerationRadius, 1.0)
            
            // Apply a cubic easing function (ease-in, ease-out) for smooth acceleration.
            // f(x) = x^2 * (3 - 2x)
            let easedProgress = progress * progress * (3.0 - 2.0 * progress)
            
            // Determine the starting speed factor for the drag. This is based on the `slowSpeedPercentage` slider.
            // Formula: startFactor = 200.0 / slowSpeedPercentage.
            // E.g., if slider is 100% (normal speed), startFactor = 200/100 = 2.0.
            // E.g., if slider is 50% (half speed), startFactor = 200/50 = 4.0.
            // E.g., if slider is 5% (very slow), startFactor = 200/5 = 40.0.
            let startFactor = 200.0 / slowSpeedPercentage
            
            // Interpolate the speed factor:
            // - At the beginning of the drag (easedProgress = 0), factor is `startFactor`.
            // - As drag progresses towards the radius (easedProgress approaches 1), factor moves towards `normalSpeedFactor`.
            // - At or beyond the radius (easedProgress = 1), factor is `normalSpeedFactor`.
            let effectiveDragFactor = startFactor * (1.0 - easedProgress) + normalSpeedFactor * easedProgress

            logger.debug("""
                Drag acceleration calculation: distance=\(self.currentDragDistance), radius=\(self.accelerationRadius), progress=\(progress),
                easedProgress=\(easedProgress), startFactor=\(startFactor), normalFactor=\(normalSpeedFactor), effectiveDragFactor=\(effectiveDragFactor)
                """)
            return effectiveDragFactor
        }
        
        // If neither slow speed mode nor applicable drag acceleration is active, use the normal speed factor.
        return normalSpeedFactor
    }
    
    private func startDragTracking(at position: CGPoint) {
        isDragging = true
        currentDragDistance = 0.0
        
        // Reset accumulators for clean drag tracking
        accumulatedX = 0.0
        accumulatedY = 0.0
        
        // Initialize cursor position for drag acceleration if not already tracking
        if lastCursorPosition == .zero {
            let nsEventPosition = NSEvent.mouseLocation
            // Convert from NSEvent coordinates (bottom-left origin) to CG coordinates (top-left origin)
            // This ensures lastCursorPosition is always in the global top-left system.
            lastCursorPosition = convertToGlobalTopLeft(point: nsEventPosition)
            logger.debug("Initialized lastCursorPosition for drag tracking: \(self.lastCursorPosition)")
        }
        
        logger.info("Started drag tracking. Drag Accel Modifiers Active: \(isDragAccelerationModifiersActive)")
    }
    
    private func stopDragTracking() {
        isDragging = false
        currentDragDistance = 0.0 // Reset distance for the next drag
        
        // Reset cursor position tracking if we are not in precision mode.
        // If in precision mode, lastCursorPosition should remain valid as it's used for slow speed movement.
        if !isInPrecisionMode {
            lastCursorPosition = .zero
        }
        
        logger.info("Stopped drag tracking")
    }
    // Removed getCursorPosition() as it was only used once and can be inlined.
}

// Helper function to convert NSEvent screen coordinates (bottom-left origin on main screen)
// to global CGEvent coordinates (top-left origin on main screen).
private func convertToGlobalTopLeft(point: NSPoint) -> CGPoint {
    // TODO: Verify behavior thoroughly in multi-monitor setups, especially if the cursor
    // can be on a non-main display when this conversion occurs. NSScreen.main refers to the
    // screen with the menu bar. If NSEvent.mouseLocation is global but with a bottom-left origin
    // tied to the main screen's frame, this conversion should still map to the global top-left system.
    // A more robust method might involve `CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.location`
    // but that requires creating a dummy event.
    if let mainScreen = NSScreen.main {
        // Using mainScreen.frame assumes point is relative to mainScreen's coordinate system but needs flipping.
        // NSEvent.mouseLocation is documented as "origin is the bottom-left corner of the main screen".
        return CGPoint(x: point.x, y: mainScreen.frame.height - point.y)
    } else {
        // Fallback if NSScreen.main is somehow nil, though highly unlikely in a running app.
        // This might lead to incorrect positioning.
        logger.error("NSScreen.main is nil during coordinate conversion. Conversion may be incorrect.")
        // Return the point as is, which is likely incorrect but avoids crashing.
        return point
    }
}

public enum PrecisionEngineError: LocalizedError {
    case failedToCreateEventTap
    case failedToCreateRunLoopSource
    // Consider adding more specific error cases if other operations can critically fail.

    public var errorDescription: String? {
        switch self {
        case .failedToCreateEventTap:
            return "Failed to create Core Graphics event tap. This often means accessibility permissions are not granted for the application."
        case .failedToCreateRunLoopSource:
            return "Failed to create Core Foundation run loop source for the event tap. This is an internal setup error."
        }
    }
}