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
    @Published var isHIDAccessAvailable = false
    @Published var lastError: String?
    @AppStorage("precisionFactor") var precisionFactor: Double = 4.0
    
    private var pointerScaler: PointerScaler?
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "AppState")
    
    init() {
        checkPermissions()
        setupPointerScaler()
    }
    
    private func checkPermissions() {
        // Check Accessibility permission (required for fn key detection)
        isAccessibilityGranted = AXIsProcessTrusted()
        
        // Check HID system access (required for speed control)
        checkHIDAccess()
    }
    
    private func checkHIDAccess() {
        // For now, assume system preferences access is available
        // In a real implementation, we might check if the app is sandboxed
        // or test writing to global preferences
        isHIDAccessAvailable = true
        logger.info("Using system preferences approach for speed control")
    }
    
    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
        
        if isAccessibilityGranted {
            checkHIDAccess() // Recheck HID access after getting accessibility
            setupPointerScaler()
        }
    }
    
    private func setupPointerScaler() {
        guard isAccessibilityGranted else { 
            lastError = "Accessibility permission required"
            return 
        }
        
        pointerScaler = PointerScaler(precisionFactor: precisionFactor)
        pointerScaler?.onPrecisionModeChange = { [weak self] isActive in
            DispatchQueue.main.async {
                self?.isPrecisionModeActive = isActive
            }
        }
        
        do {
            try pointerScaler?.start()
            logger.info("Pointer scaler started successfully")
            lastError = nil // Clear any previous errors
        } catch {
            let errorMessage = "Failed to start pointer scaler: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    func updatePrecisionFactor(_ factor: Double) {
        precisionFactor = factor
        pointerScaler?.updatePrecisionFactor(factor)
    }
    
    /// Re-check permissions and restart/stop PointerScaler accordingly.
    func refreshPermissions() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityGranted {
            isAccessibilityGranted = trusted
            logger.debug("Accessibility permission changed. trusted = \(trusted)")
            if trusted {
                checkHIDAccess()
                setupPointerScaler()
            } else {
                pointerScaler?.stop()
                pointerScaler = nil
                lastError = "Accessibility permission was revoked"
            }
        } else if trusted {
            // Refresh HID access check even if accessibility didn't change
            let previousHIDAccess = isHIDAccessAvailable
            checkHIDAccess()
            if previousHIDAccess != isHIDAccessAvailable {
                logger.debug("HID access availability changed: \(self.isHIDAccessAvailable)")
            }
        }
    }
    
    deinit {
        pointerScaler?.stop()
    }
}