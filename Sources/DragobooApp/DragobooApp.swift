import SwiftUI
import DragobooCore
import os

@main
struct DragobooApp: App {
    @StateObject private var appState = AppState()
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "main")
    
    var body: some Scene {
        MenuBarExtra("Dragoboo", systemImage: appState.isPrecisionModeActive ? "cursorarrow.click.2" : "cursorarrow") {
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
    
    private var pointerScaler: PointerScaler?
    private let logger = Logger(subsystem: "com.dragoboo.app", category: "AppState")
    
    init() {
        checkAccessibility()
        setupPointerScaler()
    }
    
    private func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
        
        if isAccessibilityGranted {
            setupPointerScaler()
        }
    }
    
    private func setupPointerScaler() {
        guard isAccessibilityGranted else { return }
        
        pointerScaler = PointerScaler(precisionFactor: precisionFactor)
        pointerScaler?.onPrecisionModeChange = { [weak self] isActive in
            DispatchQueue.main.async {
                self?.isPrecisionModeActive = isActive
            }
        }
        
        do {
            try pointerScaler?.start()
            logger.info("Pointer scaler started successfully")
        } catch {
            logger.error("Failed to start pointer scaler: \(error.localizedDescription)")
        }
    }
    
    func updatePrecisionFactor(_ factor: Double) {
        precisionFactor = factor
        pointerScaler?.updatePrecisionFactor(factor)
    }
    
    deinit {
        pointerScaler?.stop()
    }
}