import SwiftUI
import DragobooCore
import os

@main
struct DragobooApp: App {
    @StateObject private var appState = AppState()
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "main")
    
    var body: some Scene {
        MenuBarExtra("Dragoboo", systemImage: "cursorarrow") {
            ContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppState: ObservableObject {
    @Published var isPrecisionModeActive = false
    @Published var isAccessibilityGranted = false
    @Published var isDragging = false
    
    // v2.0: Feature toggles
    @AppStorage("slowSpeedEnabled") var slowSpeedEnabled: Bool = true
    @AppStorage("dragAccelerationEnabled") var dragAccelerationEnabled: Bool = true
    
    // v2.0: Percentage-based precision factor (100% = normal speed)
    @AppStorage("slowSpeedPercentage") var slowSpeedPercentage: Double = 100.0
    
    // v2.0: Configurable modifier keys
    @AppStorage("modifierKeysData") private var modifierKeysData: Data = Data()
    
    // v2.0: Drag acceleration modifier keys
    @AppStorage("dragAccelerationModifierKeysData") private var dragAccelerationModifierKeysData: Data = Data()
    
    // v2.0: Drag acceleration settings
    @AppStorage("accelerationRadius") var accelerationRadius: Double = 200.0
    
    // Legacy support for existing precision factor
    @AppStorage("precisionFactor") private var legacyPrecisionFactor: Double = 4.0
    
    var modifierKeys: Set<ModifierKey> {
        get {
            guard !modifierKeysData.isEmpty else {
                logger.debug("modifierKeysData is empty, returning default: [.fn]")
                return [.fn] // Default to fn key
            }
            do {
                let decoded = try JSONDecoder().decode(Set<ModifierKey>.self, from: modifierKeysData)
                logger.debug("Successfully decoded modifierKeys: \(decoded.map(\.displayName))")
                return decoded
            } catch {
                logger.error("Failed to decode modifierKeysData: \(error.localizedDescription). Data: '\(String(data: modifierKeysData, encoding: .utf8) ?? "non-utf8 data")'. Returning default: [.fn]")
                return [.fn] // Default to fn key on error
            }
        }
        set {
            do {
                modifierKeysData = try JSONEncoder().encode(newValue)
                logger.debug("Successfully encoded and stored modifierKeys: \(newValue.map(\.displayName))")
            } catch {
                logger.error("Failed to encode modifierKeys: \(error.localizedDescription). Value: \(newValue.map(\.displayName))")
                // modifierKeysData will retain its old value if encoding fails.
            }
            // Update the engine regardless of AppStorage success for the current session's behavior.
            precisionEngine?.updateModifierKeys(newValue)
        }
    }
    
    var dragAccelerationModifierKeys: Set<ModifierKey> {
        get {
            guard !dragAccelerationModifierKeysData.isEmpty else {
                logger.debug("dragAccelerationModifierKeysData is empty, returning default: []")
                return [] // Default to no modifiers
            }
            do {
                let decoded = try JSONDecoder().decode(Set<ModifierKey>.self, from: dragAccelerationModifierKeysData)
                logger.debug("Successfully decoded dragAccelerationModifierKeys: \(decoded.map(\.displayName))")
                return decoded
            } catch {
                logger.error("Failed to decode dragAccelerationModifierKeysData: \(error.localizedDescription). Data: '\(String(data: dragAccelerationModifierKeysData, encoding: .utf8) ?? "non-utf8 data")'. Returning default: []")
                return [] // Default to no modifiers on error
            }
        }
        set {
            do {
                dragAccelerationModifierKeysData = try JSONEncoder().encode(newValue)
                logger.debug("Successfully encoded and stored dragAccelerationModifierKeys: \(newValue.map(\.displayName))")
            } catch {
                logger.error("Failed to encode dragAccelerationModifierKeys: \(error.localizedDescription). Value: \(newValue.map(\.displayName))")
            }
            precisionEngine?.updateDragAccelerationModifierKeys(newValue)
        }
    }
    
    // Fixed: 100% = normal speed (factor 2.0 baseline), below 100% = slower
    var precisionFactor: Double {
        // The system's "normal" speed is factor 2.0, not 1.0
        return 200.0 / slowSpeedPercentage
    }
    
    private var precisionEngine: PrecisionEngine?
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "AppState")
    
    init() {
        // Log initial @AppStorage values for easier debugging of persistence issues.
        logger.info("""
            AppState initializing. Current @AppStorage values:
            slowSpeedEnabled: \(slowSpeedEnabled), dragAccelerationEnabled: \(dragAccelerationEnabled),
            slowSpeedPercentage: \(slowSpeedPercentage), accelerationRadius: \(accelerationRadius),
            modifierKeysData: \(modifierKeysData.count) bytes, dragAccelerationModifierKeysData: \(dragAccelerationModifierKeysData.count) bytes,
            legacyPrecisionFactor (used for initial calculation if percentage is 100): \(legacyPrecisionFactor)
            """)

        // The original code "Force reset to 100% (normal speed) to fix any legacy values"
        // might be too aggressive if users have already configured a percentage.
        // Let's check if it's the default AppStorage value (100.0) AND legacyPrecisionFactor suggests a different speed.
        // However, `precisionFactor` var already correctly computes based on `slowSpeedPercentage`.
        // The line `slowSpeedPercentage = 100.0` might have been to ensure a clean state from older app versions.
        // For now, respecting its original intent but logging it.
        if slowSpeedPercentage != 100.0 {
            logger.info("Initial slowSpeedPercentage is \(slowSpeedPercentage), not 100.0. User setting preserved.")
        } else {
            // This was the original line:
            // slowSpeedPercentage = 100.0
            // It's redundant if the @AppStorage default is 100.0, but harmless.
            // logger.info("Initial slowSpeedPercentage was 100.0 (default or reset).")
        }
        // The main purpose of `legacyPrecisionFactor` seems to be implicitly handled by `precisionFactor` getter,
        // which uses `slowSpeedPercentage`. If `slowSpeedPercentage` was never changed from 100.0,
        // then `precisionFactor` would be 2.0. A direct migration path for `legacyPrecisionFactor` isn't explicit.
        // Given the "v2.0" status, it's assumed settings have stabilized around percentage.

        checkPermissions() // Sets initial isAccessibilityGranted
        if isAccessibilityGranted {
            logger.info("Accessibility permissions already granted at init.")
            setupPrecisionEngine()
        } else {
            logger.info("Accessibility permissions not granted at init. PrecisionEngine setup deferred.")
        }
    }
    
    private func checkPermissions() {
        let currentPermission = AXIsProcessTrusted()
        if currentPermission != isAccessibilityGranted { // Log if it changed since last check (e.g. @Published default)
            logger.info("Accessibility permission status checked: \(currentPermission) (was \(isAccessibilityGranted))")
        }
        isAccessibilityGranted = currentPermission
    }
    
    func requestAccessibility() {
        logger.info("Requesting accessibility permissions via prompt.")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let previousGrantedState = isAccessibilityGranted
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options) // This call prompts the user
        
        logger.info("Accessibility permission after request: \(isAccessibilityGranted) (was \(previousGrantedState))")

        if isAccessibilityGranted && !previousGrantedState {
            logger.info("Accessibility permission newly granted. Setting up precision engine.")
            setupPrecisionEngine()
        } else if !isAccessibilityGranted && previousGrantedState {
            logger.warning("Accessibility permission was revoked after prompt (or prompt timed out).")
            // Engine should be stopped if it was running
            precisionEngine?.stop()
            precisionEngine = nil
        } else if isAccessibilityGranted && previousGrantedState {
            logger.info("Accessibility permission remains granted. Engine should already be set up if previously successful.")
            // If engine is nil for some reason but permissions are granted, try setting up.
            if precisionEngine == nil {
                logger.info("Permissions granted, but engine is nil. Attempting setup.")
                setupPrecisionEngine()
            }
        }
    }
    
    private func setupPrecisionEngine() {
        guard isAccessibilityGranted else {
            logger.warning("Attempted to setup PrecisionEngine, but accessibility permissions are not granted.")
            return 
        }

        if precisionEngine != nil {
            logger.info("PrecisionEngine already exists. Stopping and re-creating for setup.")
            precisionEngine?.stop()
        }
        
        logger.info("Setting up PrecisionEngine with factor: \(precisionFactor) (from percentage: \(slowSpeedPercentage)%)")
        precisionEngine = PrecisionEngine(precisionFactor: precisionFactor)
        precisionEngine?.onPrecisionModeChange = { [weak self] isActive in
            DispatchQueue.main.async {
                self?.isPrecisionModeActive = isActive
            }
        }
        
        // Configure settings
        precisionEngine?.updateModifierKeys(modifierKeys)
        precisionEngine?.updateDragAccelerationModifierKeys(dragAccelerationModifierKeys)
        precisionEngine?.updateAccelerationRadius(accelerationRadius)
        precisionEngine?.updateSlowSpeedEnabled(slowSpeedEnabled)
        precisionEngine?.updateDragAccelerationEnabled(dragAccelerationEnabled)
        
        do {
            try precisionEngine?.start()
            logger.info("Precision engine started successfully")
        } catch {
            logger.error("Failed to start precision engine: \(error.localizedDescription)")
        }
    }
    
    func toggleModifierKey(_ key: ModifierKey) {
        var keys = modifierKeys
        if keys.contains(key) {
            keys.remove(key) // Allow removing all keys to disable slow speed
        } else {
            keys.insert(key)
        }
        modifierKeys = keys
    }
    
    func toggleDragAccelerationModifierKey(_ key: ModifierKey) {
        var keys = dragAccelerationModifierKeys
        if keys.contains(key) {
            keys.remove(key)
        } else {
            keys.insert(key)
        }
        dragAccelerationModifierKeys = keys
    }
    
    func updateSlowSpeedPercentage(_ percentage: Double) {
        slowSpeedPercentage = percentage
        precisionEngine?.updatePrecisionFactor(precisionFactor)
    }
    
    func updateAccelerationRadius(_ radius: Double) {
        accelerationRadius = radius
        precisionEngine?.updateAccelerationRadius(radius)
    }
    
    func updatePrecisionFactor(_ factor: Double) {
        slowSpeedPercentage = 100.0 / factor
        precisionEngine?.updatePrecisionFactor(factor)
    }
    
    func toggleSlowSpeed() {
        slowSpeedEnabled.toggle()
        precisionEngine?.updateSlowSpeedEnabled(slowSpeedEnabled)
    }
    
    func toggleDragAcceleration() {
        dragAccelerationEnabled.toggle()
        precisionEngine?.updateDragAccelerationEnabled(dragAccelerationEnabled)
    }
    
    /// Re-check permissions and restart/stop PrecisionEngine accordingly.
    func refreshPermissions() {
        let systemTrustedState = AXIsProcessTrusted()
        logger.info("Refreshing permissions. Current app state: \(isAccessibilityGranted), System state: \(systemTrustedState)")

        if systemTrustedState != isAccessibilityGranted {
            logger.info("Accessibility permission mismatch detected. App state was \(isAccessibilityGranted), system is now \(systemTrustedState). Updating internal state and engine setup.")
            isAccessibilityGranted = systemTrustedState

            if isAccessibilityGranted {
                logger.info("Permissions are now granted according to system. Setting up precision engine.")
                setupPrecisionEngine() // This will re-create if necessary
            } else {
                logger.warning("Permissions are now revoked according to system. Stopping precision engine.")
                precisionEngine?.stop()
                precisionEngine = nil
            }
        } else {
            logger.debug("No change in accessibility permission detected by refresh. App: \(isAccessibilityGranted), System: \(systemTrustedState)")
            // If permissions are granted but engine is somehow nil, try to set it up.
            if isAccessibilityGranted && precisionEngine == nil {
                logger.warning("Permissions are granted, but engine is nil on refresh. Attempting setup.")
                setupPrecisionEngine()
            }
        }
    }
    
    deinit {
        logger.info("AppState deinit. Stopping precision engine.")
        precisionEngine?.stop()
    }
}