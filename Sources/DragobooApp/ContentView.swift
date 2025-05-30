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
                
                if appState.isPrecisionModeActive {
                    Label("Precision mode active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct StatusIndicator: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.isPrecisionModeActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(appState.isPrecisionModeActive ? "Active" : "Ready")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}