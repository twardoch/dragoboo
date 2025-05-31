import SwiftUI
import DragobooCore

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            if !appState.isAccessibilityGranted {
                AccessibilityRequestView()
            } else {
                VStack(spacing: 12) {
                    SlowSpeedToggleView()
                    DragAccelerationToggleView()
                    BottomSection()
                }
            }
        }
        .onAppear { 
            appState.refreshPermissions() 
        }
        .padding(16)
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

struct SlowSpeedToggleView: View {
    @EnvironmentObject var appState: AppState
    @State private var slowSpeedPercentage: Double = 100.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Slow speed", isOn: Binding(
                    get: { appState.slowSpeedEnabled },
                    set: { _ in appState.toggleSlowSpeed() }
                ))
                .toggleStyle(.checkbox)
                
                Spacer()
                
                if appState.slowSpeedEnabled {
                    ModifierKeyButtons()
                }
            }
            
            // Always show slider since it affects drag acceleration too
            VStack(spacing: 4) {
                Slider(value: $slowSpeedPercentage, in: 1...100, step: 5) { _ in
                    appState.updateSlowSpeedPercentage(slowSpeedPercentage)
                }
                
                Text("\(Int(slowSpeedPercentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if appState.slowSpeedEnabled && appState.modifierKeys.isEmpty {
                    Text("Select modifier keys to activate")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .onAppear {
                slowSpeedPercentage = appState.slowSpeedPercentage
            }
        }
    }
}

struct ModifierKeyButtons: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ModifierKey.allCases, id: \.self) { key in
                Button(key.displayName) {
                    appState.toggleModifierKey(key)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .background(buttonBackground(for: key))
                .foregroundColor(buttonForeground(for: key))
                .cornerRadius(3)
            }
        }
    }
    
    private func buttonBackground(for key: ModifierKey) -> Color {
        let isSelected = appState.modifierKeys.contains(key)
        let isActive = appState.isPrecisionModeActive && isSelected
        
        if isActive {
            return .green
        } else if isSelected {
            return .accentColor
        } else {
            return .clear
        }
    }
    
    private func buttonForeground(for key: ModifierKey) -> Color {
        let isSelected = appState.modifierKeys.contains(key)
        return isSelected ? .white : .primary
    }
}

struct DragAccelerationToggleView: View {
    @EnvironmentObject var appState: AppState
    @State private var accelerationRadius: Double = 200.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Drag acceleration", isOn: Binding(
                    get: { appState.dragAccelerationEnabled },
                    set: { _ in appState.toggleDragAcceleration() }
                ))
                .toggleStyle(.checkbox)
                
                Spacer()
            }
            
            if appState.dragAccelerationEnabled {
                VStack(spacing: 4) {
                    Slider(value: $accelerationRadius, in: 50...1000, step: 50) { _ in
                        appState.updateAccelerationRadius(accelerationRadius)
                    }
                    
                    Text("\(Int(accelerationRadius))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Speed increases from slow to normal over this distance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    accelerationRadius = appState.accelerationRadius
                }
            }
        }
    }
}

struct BottomSection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Text("Dragoboo v2.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}