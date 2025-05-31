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
    @AppStorage("precisionFactor") var precisionFactor: Double = 4.0
    
    private var precisionEngine: PrecisionEngine?
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "AppState")
    
    init() {
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
        
        do {
            try precisionEngine?.start()
            logger.info("Precision engine started successfully")
        } catch {
            logger.error("Failed to start precision engine: \(error.localizedDescription)")
        }
    }
    
    func updatePrecisionFactor(_ factor: Double) {
        precisionFactor = factor
        precisionEngine?.updatePrecisionFactor(factor)
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