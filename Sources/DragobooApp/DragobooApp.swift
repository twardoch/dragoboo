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
    
    // v2.0: Drag acceleration settings
    @AppStorage("accelerationRadius") var accelerationRadius: Double = 200.0
    
    // Legacy support for existing precision factor
    @AppStorage("precisionFactor") private var legacyPrecisionFactor: Double = 4.0
    
    var modifierKeys: Set<ModifierKey> {
        get {
            guard let decoded = try? JSONDecoder().decode(Set<ModifierKey>.self, from: modifierKeysData) else {
                return [.fn] // Default to fn key
            }
            return decoded
        }
        set {
            modifierKeysData = (try? JSONEncoder().encode(newValue)) ?? Data()
            precisionEngine?.updateModifierKeys(newValue)
        }
    }
    
    // Fixed: 100% = normal speed (factor 1.0), below 100% = slower, above 100% = faster
    var precisionFactor: Double {
        return 100.0 / slowSpeedPercentage
    }
    
    private var precisionEngine: PrecisionEngine?
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "AppState")
    
    init() {
        // Migrate from old percentage system: reset to 100% (normal speed) for consistency
        // This ensures all users start with the intuitive 100% = normal speed baseline
        if slowSpeedPercentage != 100.0 {
            slowSpeedPercentage = 100.0
        }
        
        checkPermissions()
        setupPrecisionEngine()
    }
    
    private func checkPermissions() {
        // Check Accessibility permission (required for fn key detection)
        isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
        
        if isAccessibilityGranted {
            setupPrecisionEngine()
        }
    }
    
    private func setupPrecisionEngine() {
        guard isAccessibilityGranted else { 
            return 
        }
        
        precisionEngine = PrecisionEngine(precisionFactor: precisionFactor)
        precisionEngine?.onPrecisionModeChange = { [weak self] isActive in
            DispatchQueue.main.async {
                self?.isPrecisionModeActive = isActive
            }
        }
        
        // Configure settings
        precisionEngine?.updateModifierKeys(modifierKeys)
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
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityGranted {
            isAccessibilityGranted = trusted
            logger.debug("Accessibility permission changed. trusted = \(trusted)")
            if trusted {
                setupPrecisionEngine()
            } else {
                precisionEngine?.stop()
                precisionEngine = nil
            }
        }
    }
    
    deinit {
        precisionEngine?.stop()
    }
}