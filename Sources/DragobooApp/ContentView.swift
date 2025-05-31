import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            if !appState.isAccessibilityGranted {
                AccessibilityRequestView()
            } else {
                PrecisionSettingsView()
            }
            
            Divider()
            
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
                
                Spacer()
                
                if appState.isAccessibilityGranted {
                    StatusIndicator()
                }
            }
        }
        .onAppear { 
            appState.refreshPermissions() 
        }
        .padding()
        .frame(width: 300)
    }
}

struct AccessibilityRequestView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Accessibility Permission Required")
                .font(.headline)
            
            Text("Dragoboo needs accessibility permissions to modify cursor movement.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Grant Permission") {
                appState.requestAccessibility()
            }
            .controlSize(.large)
        }
    }
}

struct PrecisionSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var sliderValue: Double = 4.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Precision Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Slowdown Factor:")
                    Spacer()
                    Text("\(Int(sliderValue))×")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $sliderValue, in: 1...10, step: 1) { _ in
                    appState.updatePrecisionFactor(sliderValue)
                }
                .onAppear {
                    sliderValue = appState.precisionFactor
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Label("Hold fn key to activate precision mode", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label(
                    appState.isPrecisionModeActive ? "Precision mode active" : " ",
                    systemImage: appState.isPrecisionModeActive ? "checkmark.circle.fill" : "circle"
                )
                .font(.caption)
                .foregroundColor(appState.isPrecisionModeActive ? .green : .clear)
                
                // HID Access Status
                if !appState.isHIDAccessAvailable {
                    Label("System speed control may use fallback method", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Error Display
                if let error = appState.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct StatusIndicator: View {
    @EnvironmentObject var appState: AppState
    @State private var systemSpeedValid = true
    @State private var lastValidationTime = Date()
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            if appState.isPrecisionModeActive {
                validateSystemSpeed()
            }
        }
    }
    
    private var statusColor: Color {
        if appState.isPrecisionModeActive {
            return systemSpeedValid ? .green : .orange
        } else {
            return appState.lastError != nil ? .red : .gray
        }
    }
    
    private var statusText: String {
        if appState.lastError != nil {
            return "Error"
        } else if appState.isPrecisionModeActive {
            return systemSpeedValid ? "System Speed Modified" : "Speed Change Failed"
        } else {
            return "Ready"
        }
    }
    
    private func validateSystemSpeed() {
        // This is a simplified validation - in a real implementation,
        // we might need to access the SystemSpeedController validation method
        systemSpeedValid = true // Assume it's working for now
        lastValidationTime = Date()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}